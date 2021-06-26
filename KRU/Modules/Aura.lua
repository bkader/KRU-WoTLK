assert(KRU, "Raid Utilities not found!")
local KRU = KRU

-- > start of module declaration and options < --
local L = KRU.L
local mod = KRU:NewModule(L["Paladin Auras"])
local LSM = KRU.LSM or LibStub("LibSharedMedia-3.0")

local defaults = {
	enabled = true,
	locked = false,
	updateInterval = 0.25,
	hideTitle = false,
	scale = 1,
	font = "Friz Quadrata TT",
	fontSize = 14,
	fontFlags = "OUTLINE",
	iconSize = 24,
	width = 140,
	align = "LEFT",
	spacing = 2
}
if not KRU.defaults then
	KRU.defaults = {profile = {}}
end
KRU.defaults.profile.auras = defaults

local playername = UnitName("player")
local display, CreateDisplay
local ShowDisplay, HideDisplay
local LockDisplay, UnlockDisplay
local UpdateDisplay

local auras, auraFrames = {}, {}
local AddAura, RemoveAura
local FetchDisplay, fetched
local RenderDisplay, rendered
local ResetFrames

local aurasOrder, spellIcons
local testAuras, testMode

KRU.options.args.auras = {
	type = "group",
	name = L["Paladin Auras"],
	order = 4,
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
					display:RegisterEvent("PARTY_MEMBERS_CHANGED")
					display:RegisterEvent("RAID_ROSTER_UPDATE")
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
					name = L["Orientation"],
					order = 4,
					values = {LEFT = L["Left to right"], RIGHT = L["Right to left"]}
				},
				iconSize = {
					type = "range",
					name = L["Icon Size"],
					order = 5,
					min = 8,
					max = 30,
					step = 1
				},
				spacing = {
					type = "range",
					name = L["Spacing"],
					order = 6,
					min = 0,
					max = 30,
					step = 1
				},
				width = {
					type = "range",
					name = L["Width"],
					order = 7,
					min = 120,
					max = 240,
					step = 1
				},
				scale = {
					type = "range",
					name = L["Scale"],
					order = 8,
					min = 0.5,
					max = 3,
					step = 0.01,
					bigStep = 0.1
				},
				hideTitle = {
					type = "toggle",
					name = L["Hide Title"],
					desc = L["Enable this if you want to hide the title text when locked."],
					order = 9
				}
			}
		},
		reset = {
			type = "execute",
			name = RESET,
			order = 99,
			width = "double",
			confirm = function()
				return L:F("Are you sure you want to reset %s to default?", L["Paladin Auras"])
			end,
			func = function()
				KRU.db.profile.auras = defaults
				mod.db = KRU.db.profile.auras
				UpdateDisplay()
			end
		}
	}
}
-- > end of module declaration and options < --

local pairs, select = pairs, select
local UnitName, UnitBuff = UnitName, UnitBuff
local tinsert, tsort = table.insert, table.sort
local GetSpellInfo = GetSpellInfo
local CreateFrame = CreateFrame

local auraMastery = GetSpellInfo(31821)

do
	local auraDevotion = GetSpellInfo(48942)
	local auraRetribution = GetSpellInfo(54043)
	local auraConcentration = GetSpellInfo(19746)
	local auraShadow = GetSpellInfo(48943)
	local auraFrost = GetSpellInfo(48945)
	local auraFire = GetSpellInfo(48947)
	local auraCrusader = GetSpellInfo(32223)

	aurasOrder = {
		[auraDevotion] = 1,
		[auraRetribution] = 2,
		[auraConcentration] = 3,
		[auraShadow] = 4,
		[auraFrost] = 5,
		[auraFire] = 6,
		[auraCrusader] = 7
	}

	spellIcons = {
		[auraDevotion] = "Interface\\Icons\\Spell_Holy_DevotionAura",
		[auraRetribution] = "Interface\\Icons\\Spell_Holy_AuraOfLight",
		[auraConcentration] = "Interface\\Icons\\Spell_Holy_MindSooth",
		[auraShadow] = "Interface\\Icons\\Spell_Shadow_SealOfKings",
		[auraFrost] = "Interface\\Icons\\Spell_Frost_WizardMark",
		[auraFire] = "Interface\\Icons\\Spell_Fire_SealOfFire",
		[auraCrusader] = "Interface\\Icons\\Spell_Holy_CrusaderAura"
	}

	testAuras = {
		[auraDevotion] = auraDevotion,
		[auraRetribution] = auraRetribution,
		[auraConcentration] = auraConcentration,
		[auraShadow] = auraShadow,
		[auraFrost] = auraFrost,
		[auraFire] = auraFire,
		[auraCrusader] = auraCrusader
	}
end

function AddAura(auraname, playername)
	auras[auraname] = playername
	rendered = nil
end

function RemoveAura(auraname, playername)
	auras[auraname] = nil
	local f = _G["KRUPaladinAuras" .. playername]
	if f then
		f.cooldown:Hide()
		f:Hide()
		f = nil
	end
	rendered = nil
end

function FetchDisplay()
	if not fetched then
		auras = {}
		for name in pairs(aurasOrder) do
			local unit = select(8, UnitBuff("player", name))
			if unit then
				AddAura(name, select(1, UnitName(unit)) or UNKNOWN)
			end
		end
		fetched = true
	end
end

do
	local function SortAuras(a, b)
		if not aurasOrder[a[1]] then
			return true
		elseif not aurasOrder[b[1]] then
			return false
		else
			return aurasOrder[a[1]] < aurasOrder[b[1]]
		end
	end

	function ResetFrames()
		for k, v in pairs(auraFrames) do
			if _G[k] then
				_G[k]:Hide()
				_G[k] = nil
			end
		end
	end

	function RenderDisplay()
		if not mod.db.enabled then
			rendered = true
		end
		if rendered then
			return
		end
		ResetFrames()

		local list = {}
		for auraname, playername in pairs(auras) do
			tinsert(list, {auraname, playername})
		end
		tsort(list, SortAuras)

		local size = mod.db.iconSize or 24

		for i = 1, #list do
			local aura = list[i]
			local fname = "KRUPaladinAuras" .. aura[2]

			local f = _G[fname]
			if not f then
				f = CreateFrame("Frame", fname, display)

				local t = f:CreateTexture(nil, "BACKGROUND")
				t:SetSize(size, size)
				t:SetTexCoord(0.1, 0.9, 0.1, 0.9)
				f.icon = t

				t = f:CreateTexture(nil, "BACKGROUND")
				t:SetSize(size, size)
				t:SetTexture([[Interface\Icons\Spell_Holy_AuraMastery]])
				t:SetTexCoord(0.1, 0.9, 0.1, 0.9)
				if testMode then
					t:Show()
				else
					t:Hide()
				end
				f.am = t

				t = CreateFrame("Cooldown", nil, display, "CooldownFrameTemplate")
				t:SetAllPoints(f.am)
				f.cooldown = t

				t = f:CreateFontString(nil, "ARTWORK")
				t:SetFont(LSM:Fetch("font", mod.db.font), mod.db.fontSize, mod.db.fontFlags)
				t:SetSize(110, size)
				t:SetJustifyV("MIDDLE")
				f.name = t
			end

			f:SetSize(mod.db.width or 140, size)
			f:SetPoint("TOPLEFT", display, "TOPLEFT", 0, -((size + (mod.db.spacing or 0)) * (i - 1)))
			f.icon:SetTexture(spellIcons[aura[1]])
			f.name:SetText(aura[2])
			f:Show()

			if display.align == "RIGHT" then
				f.icon:SetPoint("RIGHT", f, "RIGHT", 0, 0)
				f.am:SetPoint("LEFT", f.icon, "RIGHT", 3, 0)
				f.name:SetPoint("RIGHT", f.icon, "LEFT", -3, 0)
				f.name:SetPoint("LEFT", f, "LEFT", 0, 0)
				f.name:SetJustifyH("RIGHT")
			else
				f.icon:SetPoint("LEFT", f, "LEFT", 0, 0)
				f.am:SetPoint("RIGHT", f.icon, "LEFT", -3, 0)
				f.name:SetPoint("LEFT", f.icon, "RIGHT", 3, 0)
				f.name:SetPoint("RIGHT", f, "RIGHT", 0, 0)
				f.name:SetJustifyH("LEFT")
			end
			auraFrames[fname] = true
		end

		rendered = true
	end
end

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

	local iconSize = mod.db.iconSize or 24
	display:SetHeight(iconSize * 7 + (mod.db.spacing or 0) * 6)
	if display.locked and mod.db.hideTitle then
		display.header:Hide()
	else
		display.header:Show()
	end

	display.header:SetFont(LSM:Fetch("font", mod.db.font), mod.db.fontSize, mod.db.fontFlags)

	local changeside
	if display.align ~= mod.db.align then
		display.align = mod.db.align
		changeside = display.align
	end

	if changeside then
		display.header:SetJustifyH(changeside)
		if changeside == "RIGHT" then
			display.header:ClearAllPoints()
			display.header:SetPoint("BOTTOMRIGHT", display, "TOPRIGHT", 0, 5)
			display.header:SetJustifyH("RIGHT")
		else
			display.header:ClearAllPoints()
			display.header:SetPoint("BOTTOMLEFT", display, "TOPLEFT", 0, 5)
			display.header:SetJustifyH("LEFT")
		end
	end

	if testMode then
		auras = testAuras
	else
		auras, fetched = {}, nil
		FetchDisplay()
	end

	for _, name in pairs(auras) do
		local f = _G["KRUPaladinAuras" .. name]
		if f then
			f:SetHeight(iconSize + 2)
			f.name:SetFont(LSM:Fetch("font", mod.db.font), mod.db.fontSize, mod.db.fontFlags)
			f.icon:SetSize(iconSize, iconSize)

			if changeside == "RIGHT" then
				f.icon:ClearAllPoints()
				f.icon:SetPoint("RIGHT", f, "RIGHT", 0, 0)
				f.am:ClearAllPoints()
				f.am:SetPoint("LEFT", f.icon, "RIGHT", 3, 0)
				f.name:ClearAllPoints()
				f.name:SetPoint("RIGHT", f.icon, "LEFT", -3, 0)
				f.name:SetPoint("LEFT", f, "LEFT", 0, 0)
				f.name:SetJustifyH("RIGHT")
			elseif changeside == "LEFT" then
				f.icon:ClearAllPoints()
				f.icon:SetPoint("LEFT", f, "LEFT", 0, 0)
				f.am:ClearAllPoints()
				f.am:SetPoint("RIGHT", f.icon, "LEFT", -3, 0)
				f.name:ClearAllPoints()
				f.name:SetPoint("LEFT", f.icon, "RIGHT", 3, 0)
				f.name:SetPoint("RIGHT", f, "RIGHT", 0, 0)
				f.name:SetJustifyH("LEFT")
			end
		end
	end

	rendered = nil
end

do
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
			KRU:OpenConfig("auras")
		end
	end

	function CreateDisplay()
		if display then
			return
		end
		display = CreateFrame("Frame", "KRUPaladinAuras", UIParent)
		display:SetSize(mod.db.width or 140, (mod.db.iconSize or 24) * 7 + (mod.db.spacing or 0) * 6)
		display:SetClampedToScreen(true)
		display:SetScale(mod.db.scale or 1)
		display.align = mod.db.align or "LEFT"
		KRU:RestorePosition(display, mod.db)

		local t = display:CreateTexture(nil, "BACKGROUND")
		t:SetPoint("TOPLEFT", -2, 2)
		t:SetPoint("BOTTOMRIGHT", 2, -2)
		t:SetTexture(0, 0, 0, 0.5)
		display.bg = t

		t = display:CreateFontString(nil, "OVERLAY")
		t:SetFont(LSM:Fetch("font", mod.db.font), mod.db.fontSize, mod.db.fontFlags)
		t:SetText(L["Paladin Auras"])
		t:SetTextColor(0.96, 0.55, 0.73)
		if display.align == "RIGHT" then
			t:SetPoint("BOTTOMRIGHT", display, "TOPRIGHT", 0, 5)
			t:SetJustifyH("RIGHT")
		else
			t:SetPoint("BOTTOMLEFT", display, "TOPLEFT", 0, 5)
			t:SetJustifyH("LEFT")
		end
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

do
	local function OnUpdate(self, elapsed)
		self.lastUpdate = (self.lastUpdate or 0) + elapsed
		if self.lastUpdate > (mod.db.updateInterval or 0.25) then
			FetchDisplay()
			RenderDisplay()
			self.lastUpdate = 0
		end
	end

	local cacheEvents = {
		PARTY_MEMBERS_CHANGED = true,
		RAID_ROSTER_UPDATE = true
	}

	local function OnEvent(self, event, _, eventtype, _, srcName, _, _, dstName, _, spellid, spellname)
		if not self or self ~= display or not (event == "COMBAT_LOG_EVENT_UNFILTERED" or cacheEvents[event]) then
			return
		elseif cacheEvents[event] then
			ResetFrames()
			fetched, rendered = nil, nil
		elseif eventtype == "SPELL_AURA_APPLIED" and srcName and KRU:CheckUnit(srcName) then
			if spellIcons[spellname] and dstName and dstName == playername then
				AddAura(spellname, srcName)
			elseif spellname == auraMastery then
				local f = _G["KRUPaladinAuras" .. srcName]
				if f then
					f.am:Show()
					CooldownFrame_SetTimer(f.cooldown, GetTime(), 6, 1)
				end
			end
		elseif eventtype == "SPELL_AURA_REMOVED" and srcName and KRU:CheckUnit(srcName) then
			if spellIcons[spellname] and dstName and dstName == playername then
				RemoveAura(spellname, srcName)
			elseif spellname == auraMastery then
				local f = _G["KRUPaladinAuras" .. srcName]
				if f then
					rendered = nil
					f.am:Hide()
					f.cooldown:Hide()
				end
			end
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
		display:RegisterEvent("PARTY_MEMBERS_CHANGED")
		display:RegisterEvent("RAID_ROSTER_UPDATE")
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

function mod:OnInitialize()
	self.db = KRU.db.profile.auras
end

function mod:OnEnable()
	if self.db.locked then
		LockDisplay()
	else
		UnlockDisplay()
	end

	if self.db.enabled then
		ShowDisplay()
	else
		HideDisplay()
	end

	SLASH_KRUAURAS1 = "/auras"
	SlashCmdList.KRUAURAS = function()
		KRU:OpenConfig("auras")
	end
end