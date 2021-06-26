assert(KRU, "Raid Utilities not found!")
local KRU = KRU

-- > start of module declaration and options < --
local L = KRU.L
local mod = KRU:NewModule(L["Healers Mana"], "AceEvent-3.0")
local LGT = LibStub("LibGroupTalents-1.0", true)
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
	showIcon = true,
	iconSize = 24,
	align = "LEFT",
	width = 180,
	spacing = 2
}
if not KRU.defaults then
	KRU.defaults = {profile = {}}
end
KRU.defaults.profile.mana = defaults

local display, CreateDisplay
local ShowDisplay, HideDisplay
local LockDisplay, UnlockDisplay
local UpdateDisplay, firstrun
local RenderDisplay, rendered
local UpdateMana, ResetFrames
local healers, healerFrames = {}, {}
local testHealers = {
	raid1 = {
		name = "RestoDruid",
		class = "DRUID",
		curmana = 25000,
		maxmana = 44000,
		icon = "Interface\\Icons\\spell_nature_healingtouch",
		offline = true
	},
	raid2 = {
		name = "RestoShaman",
		class = "SHAMAN",
		curmana = 18000,
		maxmana = 36000,
		icon = "Interface\\Icons\\spell_nature_magicimmunity"
	},
	raid3 = {
		name = "HolyPriest",
		class = "PRIEST",
		curmana = 24000,
		maxmana = 32000,
		icon = "Interface\\Icons\\spell_holy_guardianspirit"
	},
	raid4 = {
		name = "DiscPriest",
		class = "PRIEST",
		curmana = 17000,
		maxmana = 32000,
		icon = "Interface\\Icons\\spell_holy_powerwordshield"
	},
	raid5 = {
		name = "HolyPaladin",
		class = "PALADIN",
		curmana = 17000,
		maxmana = 45000,
		icon = "Interface\\Icons\\spell_holy_holybolt",
		dead = true
	}
}

local colorsTable = {
	DRUID = {1, 0.49, 0.04},
	PALADIN = {0.96, 0.55, 0.73},
	PRIEST = {1, 1, 1},
	SHAMAN = {0, 0.44, 0.87}
}

KRU.options.args.mana = {
	type = "group",
	name = L["Healers Mana"],
	order = 5,
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
					display:RegisterEvent("PARTY_MEMBERS_CHANGED")
					display:RegisterEvent("RAID_ROSTER_UPDATE")
					display:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
					display:RegisterEvent("UNIT_MANA")
					display:RegisterEvent("UNIT_AURA")
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
				return L:F("Are you sure you want to reset %s to default?", L["Healers Mana"])
			end,
			func = function()
				KRU.db.profile.mana = defaults
				mod.db = KRU.db.profile.mana
				UpdateDisplay()
			end
		}
	}
}
-- > end of module declaration and options < --

local pairs, select = pairs, select
local strfmt, strlen, tostring = string.format, string.len, tostring
local UnitExists, UnitGUID, UnitName, UnitClass = UnitExists, UnitGUID, UnitName, UnitClass
local UnitPower, UnitPowerMax = UnitPower, UnitPowerMax
local UnitIsConnected, UnitIsDeadOrGhost = UnitIsConnected, UnitIsDeadOrGhost
local GetNumRaidMembers, GetNumPartyMembers = GetNumRaidMembers, GetNumPartyMembers

local function GetHealerIcon(unit, class)
	class = class or select(2, UnitClass(unit))
	if class == "SHAMAN" then
		return "Interface\\Icons\\spell_nature_magicimmunity"
	elseif class == "PALADIN" then
		return "Interface\\Icons\\spell_holy_holybolt"
	elseif class == "DRUID" then
		return "Interface\\Icons\\spell_nature_healingtouch"
	elseif class == "PRIEST" then
		local tree = LGT.roster[UnitGUID(unit)].talents[LGT:GetActiveTalentGroup(unit)]
		if strlen(tree[1]) > strlen(tree[2]) then
			return "Interface\\Icons\\spell_holy_powerwordshield"
		else
			return "Interface\\Icons\\spell_holy_guardianspirit"
		end
	end
	return "Interface\\Icons\\INV_Misc_QuestionMark"
end

function ResetFrames()
	for k, v in pairs(healerFrames) do
		if _G[k] then
			_G[k]:Hide()
			_G[k] = nil
		end
	end
end

local function CacheHealers()
	if testMode then
		return
	end

	if not firstrun then
		firstrun = true
	end

	local prefix, min, max = "raid", 1, GetNumRaidMembers()
	if max == 0 then
		prefix, min, max = "party", 0, GetNumPartyMembers()
	end

	healers = {}

	for i = min, max do
		local unit = (i == 0) and "player" or prefix .. tostring(i)
		if UnitExists(unit) and LGT:GetUnitRole(unit) == "healer" then
			local class = select(2, UnitClass(unit))
			healers[unit] = {
				name = UnitName(unit),
				class = class,
				icon = GetHealerIcon(unit, class),
				curmana = UnitPower(unit, 0),
				maxmana = UnitPowerMax(unit, 0)
			}
		elseif healers[unit] then
			healers[unit] = nil
		end
	end

	rendered = nil
end

function UpdateMana(unit, curmana, maxmana)
	if unit and healers[unit] then
		healers[unit].curmana = curmana
		healers[unit].maxmana = maxmana
		healers[unit].dead = UnitIsDeadOrGhost(unit)
		healers[unit].offline = not UnitIsConnected(unit)
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

	display:SetWidth(mod.db.width or 180)
	display:SetScale(mod.db.scale or 1)

	display.header:SetFont(LSM:Fetch("font", mod.db.font), mod.db.fontSize, mod.db.fontFlags)
	display.header:SetJustifyH(mod.db.align or "LEFT")
	if display.locked and mod.db.hideTitle then
		display.header:Hide()
	elseif not display.locked then
		display.header:Show()
	end

	if testMode then
		healers = testHealers
	else
		CacheHealers()
	end

	local changeside
	if display.align ~= mod.db.align then
		display.align = mod.db.align
		changeside = display.align
	end

	for unit, data in pairs(healers) do
		local f = _G["KPackHealersMana" .. data.name]
		if f then
			f.icon:SetSize(mod.db.iconSize, mod.db.iconSize)
			f.name:SetFont(LSM:Fetch("font", mod.db.font), mod.db.fontSize, mod.db.fontFlags)
			f.mana:SetFont(LSM:Fetch("font", mod.db.font), mod.db.fontSize, mod.db.fontFlags)

			if changeside == "RIGHT" then
				f.icon:ClearAllPoints()
				f.icon:SetPoint("RIGHT", f, "RIGHT", 0, 0)
				f.mana:ClearAllPoints()
				f.mana:SetPoint("LEFT", f, "LEFT", 0, 0)
				f.mana:SetJustifyH("LEFT")
				f.name:ClearAllPoints()
				f.name:SetPoint("LEFT", f.mana, "RIGHT", 1, 0)
				f.name:SetPoint("RIGHT", f.icon, "LEFT", -3, 0)
				f.name:SetJustifyH("RIGHT")
			elseif changeside == "LEFT" then
				f.icon:ClearAllPoints()
				f.icon:SetPoint("LEFT", f, "LEFT", 0, 0)
				f.mana:ClearAllPoints()
				f.mana:SetPoint("RIGHT", f, "RIGHT", 0, 0)
				f.mana:SetJustifyH("RIGHT")
				f.name:ClearAllPoints()
				f.name:SetPoint("LEFT", f.icon, "RIGHT", 3, 0)
				f.name:SetPoint("RIGHT", f.mana, "LEFT", 1, 0)
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
			KRU:OpenConfig("mana")
		end
	end

	function CreateDisplay()
		if display then
			return
		end
		display = CreateFrame("Frame", "KPackHealersMana", UIParent)
		display:SetSize(mod.db.width or 180, mod.db.iconSize or 24)
		display:SetClampedToScreen(true)
		display:SetScale(mod.db.scale or 1)
		KRU:RestorePosition(display, mod.db)

		local t = display:CreateTexture(nil, "BACKGROUND")
		t:SetPoint("TOPLEFT", -2, 2)
		t:SetPoint("BOTTOMRIGHT", 2, -2)
		t:SetTexture(0, 0, 0, 0.5)
		display.bg = t

		t = display:CreateFontString(nil, "OVERLAY")
		t:SetFont(LSM:Fetch("font", mod.db.font), mod.db.fontSize, mod.db.fontFlags)
		t:SetText(L["Healers Mana"])
		t:SetJustifyH(mod.db.align or "LEFT")
		t:SetPoint("BOTTOMLEFT", display, "TOPLEFT", 0, 5)
		t:SetPoint("BOTTOMRIGHT", display, "TOPRIGHT", 0, 5)
		display.header = t
		display.align = mod.db.align or "LEFT"
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
			if not rendered then
				RenderDisplay()
			end
			for _, data in pairs(healers) do
				local f = _G["KPackHealersMana" .. data.name]
				if f then
					if data.dead then
						f.mana:SetText(DEAD)
						f:SetAlpha(0.35)
					elseif data.offline then
						f.mana:SetText(FRIENDS_LIST_OFFLINE)
						f:SetAlpha(0.35)
					else
						f.mana:SetText(strfmt("%.f%%", 100 * data.curmana / data.maxmana))
						f:SetAlpha(1)
					end
				end
			end
			self.lastUpdate = 0
		end
	end

	local cacheEvents = {
		ACTIVE_TALENT_GROUP_CHANGED = true,
		PARTY_MEMBERS_CHANGED = true,
		RAID_ROSTER_UPDATE = true,
		PLAYER_REGEN_DISABLED = true
	}

	local function OnEvent(self, event, unit)
		if not firstrun then
			CacheHealers()
			firstrun = true
		end

		if not self or self ~= display then
			return
		elseif cacheEvents[event] then
			CacheHealers()
		elseif unit and KRU:CheckUnit(unit) and healers[unit] then
			if event == "UNIT_MANA" then
				UpdateMana(unit, UnitPower(unit, 0), UnitPowerMax(unit, 0))
			elseif event == "UNIT_AURA" then
				local f = _G["KPackHealersMana" .. UnitName(unit)]
				if not f then
					return
				end

				local _, _, icon, _, _, duration, _, _, _, _, _ = UnitBuff(unit, TUTORIAL_TITLE12)
				if icon then
					f._icon = f._icon or f.icon:GetTexture()
					f.icon:SetTexture(icon)
					if not f.drinking then
						f.drinking = true
						CooldownFrame_SetTimer(f.cooldown, GetTime(), duration, 1)
					end
				else
					if f._icon then
						f.icon:SetTexture(f._icon)
						f._icon = nil
					end
					if f.drinking then
						f.drinking = nil
						f.cooldown:Hide()
					end
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
		display:RegisterEvent("PARTY_MEMBERS_CHANGED")
		display:RegisterEvent("RAID_ROSTER_UPDATE")
		display:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
		display:RegisterEvent("UNIT_MANA")
		display:RegisterEvent("UNIT_AURA")
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

function RenderDisplay()
	if rendered then
		return
	end
	ResetFrames()
	local size = mod.db.iconSize or 24
	local height = size
	local i = 1
	for unit, data in pairs(healers) do
		local fname = "KPackHealersMana" .. data.name
		local f = _G[fname]
		if not f then
			f = CreateFrame("Frame", fname, display)

			local t = f:CreateTexture(nil, "BACKGROUND")
			t:SetSize(size, size)
			t:SetTexCoord(0.1, 0.9, 0.1, 0.9)
			f.icon = t

			t = CreateFrame("Cooldown", nil, display, "CooldownFrameTemplate")
			t:SetAllPoints(f.icon)
			f.cooldown = t

			t = f:CreateFontString(nil, "ARTWORK")
			t:SetFont(LSM:Fetch("font", mod.db.font), mod.db.fontSize, mod.db.fontFlags)
			t:SetJustifyV("MIDDLE")
			t:SetText(data.name)
			t:SetTextColor(unpack(colorsTable[data.class]))
			f.name = t

			t = f:CreateFontString(nil, "ARTWORK")
			t:SetFont(LSM:Fetch("font", mod.db.font), mod.db.fontSize, mod.db.fontFlags)
			t:SetJustifyV("MIDDLE")
			f.mana = t
		end

		f:SetHeight(size)
		f:SetPoint("TOPLEFT", display, "TOPLEFT", 0, -((size + (mod.db.spacing or 0)) * (i - 1)))
		f:SetPoint("RIGHT", display, "RIGHT", 0, 0)
		f.icon:SetTexture(data.icon)
		f.mana:SetText(strfmt("%.f%%", 100 * data.curmana / data.maxmana))
		f:Show()

		if display.align == "RIGHT" then
			f.icon:SetPoint("RIGHT", f, "RIGHT", 0, 0)
			f.mana:SetPoint("LEFT", f, "LEFT", 0, 0)
			f.mana:SetJustifyH("LEFT")
			f.name:SetPoint("LEFT", f.mana, "RIGHT", 1, 0)
			f.name:SetPoint("RIGHT", f.icon, "LEFT", -3, 0)
			f.name:SetJustifyH("RIGHT")
		else
			f.icon:SetPoint("LEFT", f, "LEFT", 0, 0)
			f.mana:SetPoint("RIGHT", f, "RIGHT", 0, 0)
			f.mana:SetJustifyH("RIGHT")
			f.name:SetPoint("LEFT", f.icon, "RIGHT", 3, 0)
			f.name:SetPoint("RIGHT", f.mana, "LEFT", 1, 0)
			f.name:SetJustifyH("LEFT")
		end
		if i > 1 then
			height = height + size + (mod.db.spacing or 0)
		end
		i = i + 1
		healerFrames[fname] = true
	end

	display:SetHeight(height)
	rendered = true
end

function mod:OnInitialize()
	self.db = KRU.db.profile.mana
end

function mod:OnEnable()
	if not LGT then
		return
	end

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

	KRU.After(5, function() CacheHealers() end)

	SLASH_KRUMANA1 = "/mana"
	SlashCmdList.KRUMANA = function()
		KRU:OpenConfig("mana")
	end
end