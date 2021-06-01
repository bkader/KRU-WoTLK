assert(KRU, "Raid Utilities not found!")

-- > start of module declaration and options < --
local L = KRU.L
local mod = KRU:NewModule(L["Combat Timer"], "AceEvent-3.0")
local LSM = KRU.LSM or LibStub("LibSharedMedia-3.0")

local defaults = {
	enabled = false,
	stopwatch = false,
	locked = false,
	scale = 1,
	font = "Friz Quadrata TT",
	fontFlags = "OUTLINE",
	color = {1, 1, 0}
}

if not KRU.defaults then
	KRU.defaults = {profile = {}}
end
KRU.defaults.profile.combattimer = defaults

KRU.options.args.combattimer = {
	type = "group",
	name = L["Combat Timer"],
	order = 8,
	get = function(i)
		return mod.db[i[#i]]
	end,
	set = function(i, val)
		mod.db[i[#i]] = val
		mod:ApplySettings()
	end,
	args = {
		enabled = {
			type = "toggle",
			name = L["Enable"],
			order = 1
		},
		locked = {
			type = "toggle",
			name = L["Lock"],
			order = 2,
			disabled = function()
				return not mod.db.enabled
			end
		},
		stopwatch = {
			type = "toggle",
			name = STOPWATCH_TITLE,
			desc = L["Trigger the in-game stopwatch on combat."],
			order = 3,
			disabled = function()
				return not mod.db.enabled
			end
		},
		scale = {
			type = "range",
			name = L["Scale"],
			order = 4,
			min = 0.5,
			max = 3,
			step = 0.01,
			bigStep = 0.1,
			disabled = function()
				return not mod.db.enabled
			end
		},
		font = {
			type = "select",
			name = L["Font"],
			order = 5,
			dialogControl = "LSM30_Font",
			values = AceGUIWidgetLSMlists.font,
			disabled = function()
				return not mod.db.enabled
			end
		},
		fontFlags = {
			type = "select",
			name = L["Font Outline"],
			order = 6,
			values = {
				[""] = NONE,
				["OUTLINE"] = L["Outline"],
				["THINOUTLINE"] = L["Thin outline"],
				["THICKOUTLINE"] = L["Thick outline"],
				["MONOCHROME"] = L["Monochrome"],
				["OUTLINEMONOCHROME"] = L["Outlined monochrome"]
			},
			disabled = function()
				return not mod.db.enabled
			end
		},
		color = {
			type = "color",
			name = L["Color"],
			order = 7,
			get = function()
				return unpack(mod.db.color)
			end,
			set = function(_, r, g, b)
				mod.db.color = {r, g, b, 1}
				mod:ApplySettings()
			end
		}
	}
}
-- > end of module declaration and options < --

local floor, GetTime, format = math.floor, GetTime, string.format

local function CreateTimerFrame()
	local frame = CreateFrame("Frame", "KRUCombatTimer")
	frame:SetSize(80, 25)
	frame:SetFrameStrata("LOW")
	frame:SetPoint("TOPLEFT", Minimap, "BOTTOMLEFT", 0, -10)

	-- make the frame movable
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:SetClampedToScreen(true)
	frame:RegisterForDrag("RightButton")
	frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		KRU:SavePosition(self, mod.db)
	end)
	frame:SetScript("OnMouseUp", function(self, button)
		if button == "RightButton" then
			KRU:OpenConfig("combattimer")
		end
	end)

	-- timer text
	local timer = frame:CreateFontString(nil, "OVERLAY")
	timer:SetFont(LSM:Fetch("font", mod.db.font), 12, mod.db.fontFlags)
	timer:SetTextColor(unpack(mod.db.color))
	timer:SetJustifyH("CENTER")
	timer:SetAllPoints(frame)
	timer:SetText("00:00:00")
	frame.timer = timer

	if mod.db.stopwatch then
		frame:Hide()
	else
		frame:Show()
	end

	frame.elapsed = 0
	KRU:RestorePosition(frame, mod.db)
	return frame
end

local function OnUpdate(self, elapsed)
	self.elapsed = self.elapsed + elapsed

	if self.elapsed > 1 then
		local total = GetTime() - self.starttime
		local _hor = floor(total / 3600)
		local _min = floor(total / 60 - (_hor * 60))
		local _sec = floor(total - _hor * 3600 - _min * 60)

		self.timer:SetText(format("%02d:%02d:%02d", _hor, _min, _sec))
		self.elapsed = 0
	end
end

function mod:OnInitialize()
	self.db = KRU.db.profile.combattimer
end

function mod:OnEnable()
	self:ApplySettings()
end

function mod:ApplySettings()
	self.frame = self.frame or CreateTimerFrame()

	if not self.db.enabled then
		self:UnregisterAllEvents()
		if self.frame and self.frame:IsShown() then
			self.frame:Hide()
			self.frame.elapsed = 0
			self.frame:SetScript("OnUpdate", nil)
		end
		return
	end

	self.frame:SetScale(self.db.scale or 1)
	self.frame.timer:SetFont(LSM:Fetch("font", self.db.font), 12, self.db.fontFlags)
	self.frame.timer:SetTextColor(unpack(self.db.color))

	if self.db.locked then
		self.frame:SetBackdrop(nil)
		self.frame:EnableMouse(false)
	else
		self.frame:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
			insets = {left = 1, right = 2, top = 2, bottom = 1}
		})
		self.frame:EnableMouse(true)
	end

	if self.db.stopwatch then
		self.frame:Hide()
	else
		self.frame:Show()
	end

	self:RegisterEvent("PLAYER_REGEN_ENABLED", "StopTimer")
	self:RegisterEvent("PLAYER_REGEN_DISABLED", "StartTimer")
end

function mod:StartTimer()
	if self.db.enabled then
		self.frame = self.frame or CreateTimerFrame()

		if self.db.stopwatch then
			if not StopwatchFrame:IsShown() then
				Stopwatch_Toggle()
			end
			Stopwatch_Clear()
			Stopwatch_Play()
			self.frame:Hide()
			self.frame:SetScript("OnUpdate", nil)
		else
			self.frame.timer:SetTextColor(unpack(self.db.color))
			self.frame.starttime = GetTime() - 1
			self.frame:SetScript("OnUpdate", OnUpdate)
			self.frame:Show()
		end
	end
end

function mod:StopTimer()
	if self.db.enabled then
		self.frame = self.frame or CreateTimerFrame()
		self.frame.elapsed = 0
		self.frame:SetScript("OnUpdate", nil)

		if self.db.stopwatch and StopwatchFrame and StopwatchFrame:IsShown() then
			Stopwatch_Pause()
			if self.frame then
				self.frame:Hide()
			end
		elseif self.frame and not self.frame:IsShown() then
			self.frame:Show()
		end
	end
end