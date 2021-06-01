assert(KRU, "Raid Utilities not found!")

-- > start of module declaration and options < --
local L = KRU.L
local sunder = GetSpellInfo(11597)
local mod = KRU:NewModule(sunder)
local LSM = KRU.LSM or LibStub("LibSharedMedia-3.0")

local defaults = {
	enabled = true,
	locked = false,
	updateInterval = 0.25,
	hideTitle = false,
	font = "Friz Quadrata TT",
	fontSize = 14,
	fontFlags = "OUTLINE",
	align = "RIGHT",
	spacing = 2,
	width = 140,
	scale = 1,
	sunders = {}
}
if not KRU.defaults then
	KRU.defaults = {profile = {}}
end
KRU.defaults.profile.sunders = defaults

local display, CreateDisplay
local ShowDisplay, HideDisplay
local LockDisplay, UnlockDisplay
local UpdateDisplay
local RenderDisplay, rendered
local ResetFrames

local AddSunder, ResetSunders, ReportSunders
local sunders, sunderFrames = {}, {}
local testSunders, testMode = {Name1 = 20, Name2 = 32, Name3 = 6, Name4 = 12}

KRU.options.args.sunders = {
	type = "group",
	name = sunder,
	order = 6,
	get = function(i)
		return mod.db[i[#i]]
	end,
	set = function(i, val)
		mod.db[i[#i]] = val
		UpdateDisplay()
	end,
	args = {
		enabled = {
			type = "toggle",
			name = L["Enable"],
			order = 1
		},
		testMode = {
			type = "toggle",
			name = L["Configuration Mode"],
			desc = L["Toggle configuration mode to allow moving frames and setting appearance options."],
			order = 2,
			get = function()
				return testMode
			end,
			set = function(_, val)
				testMode = val
				if testMode then
					display:UnregisterAllEvents()
				else
					display:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
				end
				ResetFrames()
				UpdateDisplay()
			end
		},
		locked = {
			type = "toggle",
			name = L["Lock"],
			order = 3,
			disabled = function()
				return not mod.db.enabled
			end
		},
		updateInterval = {
			type = "range",
			name = L["Update Frequency"],
			order = 4,
			disabled = function()
				return not mod.db.enabled
			end,
			min = 0.1,
			max = 1,
			step = 0.05,
			bigStep = 0.1
		},
		appearance = {
			type = "group",
			name = L["Appearance"],
			order = 5,
			inline = true,
			disabled = function()
				return not mod.db.enabled
			end,
			args = {
				font = {
					type = "select",
					name = L["Font"],
					order = 1,
					dialogControl = "LSM30_Font",
					values = AceGUIWidgetLSMlists.font
				},
				fontFlags = {
					type = "select",
					name = L["Font Outline"],
					order = 2,
					values = {
						[""] = NONE,
						["OUTLINE"] = L["Outline"],
						["THINOUTLINE"] = L["Thin outline"],
						["THICKOUTLINE"] = L["Thick outline"],
						["MONOCHROME"] = L["Monochrome"],
						["OUTLINEMONOCHROME"] = L["Outlined monochrome"]
					}
				},
				fontSize = {
					type = "range",
					name = L["Font Size"],
					order = 3,
					min = 8,
					max = 30,
					step = 1
				},
				align = {
					type = "select",
					name = L["Text Alignment"],
					order = 4,
					values = {LEFT = L["Left"], RIGHT = L["Right"]}
				},
				spacing = {
					type = "range",
					name = L["Spacing"],
					order = 5,
					min = 0,
					max = 30,
					step = 1
				},
				width = {
					type = "range",
					name = L["Width"],
					order = 6,
					min = 120,
					max = 240,
					step = 1
				},
				scale = {
					type = "range",
					name = L["Scale"],
					order = 7,
					min = 0.5,
					max = 3,
					step = 0.01,
					bigStep = 0.1
				},
				hideTitle = {
					type = "toggle",
					name = L["Hide Title"],
					desc = L["Enable this if you want to hide the title text when locked."],
					order = 8
				}
			}
		},
		reset = {
			type = "execute",
			name = RESET,
			order = 99,
			width = "double",
			confirm = function()
				return L:F("Are you sure you want to reset %s to default?", sunder)
			end,
			func = function()
				KRU.db.profile.sunders = defaults
				mod.db = KRU.db.profile.sunders
				UpdateDisplay()
			end
		}
	}
}

-- > end of module declaration and options < --

local pairs, ipairs = pairs, ipairs
local tinsert, tsort = table.insert, table.sort
local strformat, strlower = string.format, string.lower
local CreateFrame = CreateFrame
local GetNumRaidMembers, GetNumPartyMembers = GetNumRaidMembers, GetNumPartyMembers
local SendChatMessage = SendChatMessage

function UpdateDisplay()
	if not display then
		return
	end

	if mod.db.enabled then
		ShowDisplay()
	else
		HideDisplay()
	end

	if mod.db.locked then
		LockDisplay()
	else
		UnlockDisplay()
	end

	KRU:RestorePosition(display, mod.db)

	display:SetWidth(mod.db.width or 140)
	display:SetScale(mod.db.scale or 1)

	display.header.text:SetFont(LSM:Fetch("font", mod.db.font), mod.db.fontSize, mod.db.fontFlags)
	display.header.text:SetJustifyH(mod.db.align or "LEFT")
	if display.locked and mod.db.hideTitle then
		display.header:Hide()
	else
		display.header:Show()
	end

	sunders = testMode and testSunders or mod.db.sunders

	for name, _ in pairs(sunders) do
		local f = _G["KRUSunderCounter" .. name]
		if f then
			f.text:SetFont(LSM:Fetch("font", mod.db.font), mod.db.fontSize, mod.db.fontFlags)
			f.text:SetJustifyH(mod.db.align or "RIGHT")
		end
	end

	rendered = nil
end

do
	local menuFrame
	local menu = {
		{
			text = L["Report"],
			func = function()
				ReportSunders()
			end,
			notCheckable = 1
		},
		{
			text = RESET,
			func = function()
				ResetSunders()
			end,
			notCheckable = 1
		}
	}

	local function StartMoving(self)
		self.moving = true
		self:StartMoving()
	end

	local function StopMoving(self)
		if self.moving then
			self:StopMovingOrSizing()
			self.moving = nil
			KRU:SavePosition(self, mod.db)
		end
	end

	local function OnMouseDown(self, button)
		if button == "RightButton" then
			KRU:OpenConfig("sunders")
		end
	end

	function CreateDisplay()
		if display then
			return
		end
		display = CreateFrame("Frame", "KRUSunderCounter", UIParent)
		display:SetSize(mod.db.width or 140, 20)
		display:SetClampedToScreen(true)
		display:SetScale(mod.db.scale or 1)
		KRU:RestorePosition(display, mod.db)

		local t = display:CreateTexture(nil, "BACKGROUND")
		t:SetPoint("TOPLEFT", -2, 2)
		t:SetPoint("BOTTOMRIGHT", 2, -2)
		t:SetTexture(0, 0, 0, 0.5)
		display.bg = t

		t = CreateFrame("Button", nil, display)
		t:SetHeight(mod.db.fontSize + 4)

		t.text = t:CreateFontString(nil, "OVERLAY")
		t.text:SetFont(LSM:Fetch("font", mod.db.font), mod.db.fontSize, mod.db.fontFlags)
		t.text:SetText(sunder)
		t.text:SetAllPoints(t)
		t.text:SetJustifyH(mod.db.align or "LEFT")
		t.text:SetJustifyV("BOTTOM")
		t.text:SetTextColor(0.78, 0.61, 0.43)
		t:SetPoint("BOTTOMLEFT", display, "TOPLEFT", 0, 5)
		t:SetPoint("BOTTOMRIGHT", display, "TOPRIGHT", 0, 5)
		t:RegisterForClicks("RightButtonUp")
		t:SetScript("OnMouseUp", function(self, button)
			if not testMode and next(sunders) and button == "RightButton" then
				menuFrame =
					menuFrame or CreateFrame("Frame", "KRUSunderCounterMenu", display, "UIDropDownMenuTemplate")
				EasyMenu(menu, menuFrame, "cursor", 0, 0, "MENU")
			end
		end)
		display.header = t
	end

	function LockDisplay()
		if not display then
			CreateDisplay()
		end
		display:EnableMouse(false)
		display:SetMovable(false)
		display:RegisterForDrag(nil)
		display:SetScript("OnDragStart", nil)
		display:SetScript("OnDragStop", nil)
		display:SetScript("OnMouseDown", nil)
		display.bg:SetTexture(0, 0, 0, 0)
		if mod.db.hideTitle then
			display.header:Hide()
		end
		display.locked = true
	end

	function UnlockDisplay()
		if not display then
			CreateDisplay()
		end
		display:EnableMouse(true)
		display:SetMovable(true)
		display:RegisterForDrag("LeftButton")
		display:SetScript("OnDragStart", StartMoving)
		display:SetScript("OnDragStop", StopMoving)
		display:SetScript("OnMouseDown", OnMouseDown)
		display.bg:SetTexture(0, 0, 0, 0.5)
		display.header:Show()
		display.locked = nil
	end
end

function AddSunder(name)
	sunders[name] = (sunders[name] or 0) + 1
	rendered = nil
end

function ResetSunders()
	ResetFrames()
	mod.db.sunders = {}
	rendered = nil
	UpdateDisplay()
end

function ReportSunders()
	if testMode then
		return
	end

	local list = {}
	for name, count in pairs(sunders) do
		tinsert(list, {name, count})
	end
	if #list == 0 then
		return
	end
	tsort(list, function(a, b) return (a[2] or 0) > (b[2] or 0) end)

	local channel = "SAY"
	if GetNumRaidMembers() > 0 then
		channel = "RAID"
	elseif GetNumPartyMembers() > 0 then
		channel = "PARTY"
	end

	SendChatMessage(sunder, channel)
	for i, sun in ipairs(list) do
		SendChatMessage(strformat("%2u. %s   %s", i, sun[1], sun[2]), channel)
	end
end

do
	local function OnUpdate(self, elapsed)
		self.lastUpdate = (self.lastUpdate or 0) + elapsed
		if self.lastUpdate > (mod.db.updateInterval or 0.25) then
			if not rendered then
				RenderDisplay()
			end
			self.lastUpdate = 0
		end
	end

	local function OnEvent(self, event, ...)
		if not self or self ~= display or event ~= "COMBAT_LOG_EVENT_UNFILTERED" then
			return
		elseif arg4 and KRU:CheckUnit(arg4) and arg2 == "SPELL_CAST_SUCCESS" and arg10 and arg10 == sunder then
			AddSunder(arg4)
		end
	end

	function ShowDisplay()
		if not display then
			CreateDisplay()
		end
		display:Show()
		display:SetScript("OnUpdate", OnUpdate)
		display:SetScript("OnEvent", OnEvent)
		display:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	end

	function HideDisplay()
		if display then
			display:Hide()
			display:SetScript("OnUpdate", nil)
			display:SetScript("OnEvent", nil)
			display:UnregisterAllEvents()
		end
	end
end

function ResetFrames()
	for k, v in pairs(sunderFrames) do
		if _G[k] then
			_G[k]:Hide()
			_G[k] = nil
		end
	end
end

function RenderDisplay()
	if rendered then
		return
	end
	ResetFrames()

	local list = {}
	for name, count in pairs(sunders or {}) do
		tinsert(list, {name, count})
	end
	tsort(list, function(a, b) return (a[2] or 0) > (b[2] or 0) end)

	local height = 20

	for i = 1, #list do
		local entry = list[i]
		if entry then
			local fname = "KRUSunderCounter" .. entry[1]

			local f = _G[fname]
			if not f then
				f = CreateFrame("Frame", fname, display)

				local t = f:CreateFontString(nil, "OVERLAY")
				t:SetFont(LSM:Fetch("font", mod.db.font), mod.db.fontSize, mod.db.fontFlags)
				t:SetPoint("TOPLEFT", f, "TOPLEFT")
				t:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT")
				t:SetJustifyH(mod.db.align or "RIGHT")
				t:SetJustifyV("MIDDLE")
				f.text = t
			end

			f:SetHeight(20)
			f.text:SetText(strformat("%s: %d", entry[1], entry[2]))
			f:SetPoint("TOPLEFT", display, "TOPLEFT", 0, -((21 + (mod.db.spacing or 0)) * (i - 1)))
			f:SetPoint("RIGHT", display)
			f:Show()
			if i > 1 then
				height = height + 21 + (mod.db.spacing or 0)
			end
			sunderFrames[fname] = true
		end
	end

	display:SetHeight(height)
	rendered = true
end

function mod:OnInitialize()
	self.db = KRU.db.profile.sunders
end

function mod:OnEnable()
	if self.db.locked then
		LockDisplay()
	else
		UnlockDisplay()
	end

	if self.db.enabled then
		sunders = self.db.sunders
		ShowDisplay()
	else
		HideDisplay()
	end

	SLASH_KRUSUNDER1 = "/sunder"
	SlashCmdList.KRUSUNDER = function(cmd)
		cmd = strlower(cmd:trim())
		if cmd == "reset" then
			ResetSunders()
		elseif cmd == "report" then
			ReportSunders()
		elseif cmd == "lock" then
			LockDisplay()
		elseif cmd == "unlock" then
			UnlockDisplay()
		else
			KRU:OpenConfig("sunders")
		end
	end
end