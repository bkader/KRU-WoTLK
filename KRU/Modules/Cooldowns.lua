assert(KRU, "Raid Utilities not found!")

-- > start of module declaration and options < --
local L = KRU.L
local mod = KRU:NewModule(L["Raid Cooldowns"], "AceEvent-3.0", "LibBars-1.0")
local LSM = KRU.LSM or LibStub("LibSharedMedia-3.0")

local classcolors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
local heroism = (select(1, UnitFactionGroup("player")) == "Alliance") and 32182 or 2825
local defaults = {
	enabled = true,
	locked = false,
	width = 180,
	height = 18,
	scale = 1.0,
	growUp = false,
	showIcon = true,
	showDuration = true,
	classColor = true,
	color = {0.25, 0.33, 0.68, 1},
	texture = "Blizzard",
	font = "Friz Quadrata TT",
	fontSize = 11,
	fontFlags = "",
	maxbars = 30,
	orientation = 1,
	spells = {
		[10278] = true,
		[12323] = true,
		[20608] = true,
		[27239] = true,
		[29166] = true,
		[31821] = true,
		[33206] = true,
		[34477] = true,
		[47788] = true,
		[48477] = true,
		[48788] = true,
		[57934] = true,
		[6203] = true,
		[64205] = true,
		[64843] = true,
		[64901] = true,
		[6940] = true,
		[heroism] = true
	}
}
if not KRU.defaults then
	KRU.defaults = {profile = {}}
end
KRU.defaults.profile.cooldowns = defaults

local CreateDisplay, UpdateDisplay, display
local ShowDisplay, HideDisplay
local LockDisplay, UnlockDisplay
local GetOptions, options
local barGroups, inGroup
local playername = UnitName("player")
-- > end of module declaration and options < --

local strformat = string.format

local pairs, select, unpack = pairs, select, unpack
local type, strformat = type, string.format
local UnitClass, GetSpellInfo = UnitClass, GetSpellInfo

-- > start of cooldowns < --
local cooldowns = {
	DEATHKNIGHT = {
		[42650] = 600, -- Army of the Dead
		[45529] = 60, -- Blood Tap
		[47476] = 120, -- Strangulate
		[47528] = 10, -- Mind Freeze
		[47568] = 300, -- ERW
		[48707] = 45, -- Anti-Magic Shell
		[48792] = 120, -- Icebound Fortitude
		[48982] = 30, -- Rune Tap
		[49005] = 180, -- Mark of Blood
		[49016] = 180, -- Hysteria
		[49028] = 90, -- Dancing Rune Weapon
		[49039] = 120, -- Lichborne
		[49206] = 180, -- Summon Gargoyle
		[49222] = 60, -- Bone Shield
		[49576] = 35, -- Death Grip
		[51052] = 120, -- Anti-magic Zone
		[51271] = 60, -- Unbreakable Armor
		[55233] = 60, -- Vampiric Blood
		[56222] = 8, -- Dark Command
		[61999] = 600, -- Raise Ally
		[70654] = 60 -- Blood Armor
	},
	DRUID = {
		[16857] = 6, -- Faerie Fire (Feral)
		[17116] = 180, -- Nature's Swiftness
		[18562] = 15, -- Swiftmend
		[22812] = 60, -- Barkskin
		[22842] = 180, -- Frenzied Regeneration
		[29166] = 180, -- Innervate
		[33357] = 180, -- Dash
		[33831] = 180, -- Force of Nature
		[48447] = 480, -- Tranquility
		[48477] = 600, -- Rebirth
		[50334] = 180, -- Berserk
		[5209] = 180, -- Challenging Roar
		[5229] = 60, -- Enrage
		[53201] = 60, -- Starfall
		[53227] = 20, -- Typhoon
		[61336] = 180, -- Survival Instincts
		[6795] = 8, -- Growl
		[8983] = 30 -- Bash
	},
	HUNTER = {
		[13809] = 30, -- Frost Trap
		[19263] = 90, -- Deterrence
		[19574] = 120, -- Bestial Wrath
		[19801] = 8, -- Tranquilizing Shot
		[23989] = 180, -- Readiness
		[3045] = 180, -- Rapid Fire
		[34477] = 30, -- Misdirection
		[34490] = 30, -- Silencing Shot
		[34600] = 30, -- Snake Trap
		[49067] = 30, -- Explosive Trap
		[60192] = 30, -- Freezing Arrow
		[781] = 25 -- Disengage
	},
	MAGE = {
		[11958] = 480, -- Cold Snap
		[12051] = 240, -- Evocation
		[1953] = 15, -- Blink
		[2139] = 24, -- Counterspell
		[31687] = 180, -- Summon Water Elemental
		[45438] = 300, -- Ice Block
		[55342] = 180, -- Mirror Image
		[66] = 180 -- Invisibility
	},
	PALADIN = {
		[10278] = 300, -- Hand of Protection
		[10308] = 60, -- Hammer of Justice
		[1038] = 120, -- Hand of Salvation
		[1044] = 25, -- Hand of Freedom
		[19752] = 600, -- Divine Intervention
		[20066] = 60, -- Repentance
		[20216] = 120, -- Divine Favor
		[31789] = 8, -- Righteous Defense
		[31821] = 120, -- Aura Mastery
		[31842] = 180, -- Divine Illumination
		[31850] = 180, -- Ardent Defender
		[31884] = 120, -- Avenging Wrath
		[48788] = 1200, -- Lay on Hands
		[48817] = 30, -- Holy Wrath
		[498] = 60, -- Divine Protection
		[53601] = 60, -- Sacred Shield
		[54428] = 60, -- Divine Plea
		[62124] = 8, -- Hand of Reckoning
		[64205] = 120, -- Divine Sacrifice
		[642] = 300, -- Divine Shield
		[66233] = 120, -- Ardent Defender
		[6940] = 120, -- Hand of Sacrifice
		[70940] = 120 -- Divine Guardian
	},
	PRIEST = {
		[10060] = 96, -- Powers Infusion
		[10890] = 30, -- Psychic Scream
		[15487] = 45, -- Silence
		[33206] = 180, -- Pain Suppression
		[34433] = 300, -- Shadowfiend
		[47585] = 120, -- Dispersion
		[47788] = 180, -- Guardian Spirit
		[48113] = 10, -- Prayer of Mending
		[586] = 30, -- Fade
		[6346] = 180, -- Fear Ward
		[64044] = 120, -- Psychic Horror
		[64843] = 480, -- Divine Hymn
		[64901] = 360, -- Hymn of Hope
		[724] = 180, -- Lightwell
		[8122] = 30 -- Psychic Scream
	},
	ROGUE = {
		[11305] = 40, -- Sprint
		[13750] = 80, -- Adrenaline Rush
		[13877] = 20, -- Blade Flurry
		[14185] = 300, -- Preparation
		[1725] = 30, -- Distract
		[1766] = 10, -- Kick
		[1856] = 180, -- Vanish
		[2094] = 180, -- Blind
		[26669] = 50, -- Evasion
		[26889] = 20, -- Vanish
		[31224] = 90, -- Cloak of Shadows
		[48659] = 10, -- Feint
		[51690] = 20, -- Killing Spree
		[51722] = 60, -- Dismantle
		[5277] = 180, -- Evasion
		[57934] = 30, -- Tricks of the Trade
		[8643] = 20 -- Kidney Shot
	},
	SHAMAN = {
		[16166] = 180, -- Elemental Mastery
		[16188] = 120, -- Nature's Swiftness
		[16190] = 180, -- Mana Tide Totem
		[20608] = 1800, -- Reincarnation
		[2062] = 600, -- Earth Elemental Totem
		[21169] = 1800, -- Reincarnation
		[2894] = 600, -- Fire Elemental Totem
		[51514] = 45, -- Hex
		[51533] = 180, -- Feral Spirit
		[57994] = 6, -- Wind Shear
		[59159] = 35, -- Thunderstorm
		[heroism] = 300 -- Bloodlust/Heroism
	},
	WARLOCK = {
		[1122] = 600, -- Summon Infernal
		[18540] = 600, -- Summon Doomguard
		[29858] = 180, -- Soulshatter
		[29893] = 300, -- Ritual of Souls
		[47241] = 126, -- Metamorphosis
		[47883] = 900, -- Soulstone Resurrection
		[48020] = 30, -- Demonic Circle: Teleport
		[59672] = 180, -- Metamorphosis
		[6203] = 1800, -- Soulstone, XXX needs testing
		[698] = 120 -- Ritual of Summoning
	},
	WARRIOR = {
		[1161] = 180, -- Challenging Shout
		[12292] = 121, -- Death Wish
		[12323] = 5, -- Piercing Howl
		[12809] = 30, -- Concussion Blow
		[12975] = 180, -- Last Stand
		[1680] = 8, -- Whirlwind
		[1719] = 200, -- Recklessness
		[23881] = 4, -- Bloodthirst
		[2565] = 60, -- Shield Block
		[3411] = 30, -- Intervene
		[355] = 8, -- Taunt
		[46924] = 75, -- Bladestorm
		[5246] = 120, -- Intimidating Shout
		[55694] = 180, -- Enraged Regeneration
		[60970] = 45, -- Heroic Fury
		[64382] = 300, -- Shattering Throw
		[6552] = 10, -- Pummel
		[676] = 60, -- Disarm
		[70845] = 60, -- Stoicism
		[72] = 12, -- Shield Bash
		[871] = 300 -- Shield Wall
	}
}

local allSpells, classLookup = {}, {}
for class, spells in pairs(cooldowns) do
	for id, cd in pairs(spells) do
		allSpells[id] = cd
		classLookup[id] = class
	end
end

local classes = {}
do
	local hexColors = {}
	for k, v in pairs(classcolors) do
		hexColors[k] = "|cff" .. strformat("%02x%02x%02x", v.r * 255, v.g * 255, v.b * 255)
	end
	for class in pairs(cooldowns) do
		classes[class] = hexColors[class] .. LOCALIZED_CLASS_NAMES_MALE[class] .. "|r"
	end
	wipe(hexColors)
	hexColors = nil
end

function GetOptions()
	if not options then
		local disabled = function()
			return not (mod.db and mod.db.enabled)
		end
		options = {
			type = "group",
			name = L["Raid Cooldowns"],
			order = 7,
			get = function(i)
				return mod.db[i[#i]]
			end,
			set = function(i, val)
				mod.db[i[#i]] = val
				UpdateDisplay()
			end,
			args = {
				reset = {
					type = "execute",
					name = RESET,
					order = 99,
					width = "double",
					confirm = function()
						return L:F("Are you sure you want to reset %s to default?", L["Raid Cooldowns"])
					end,
					func = function()
						KRU.db.profile.cooldowns = defaults
						mod.db = KRU.db.profile.cooldowns
						UpdateDisplay()
					end
				},
				general = {
					type = "group",
					name = L["Options"],
					order = 1,
					args = {
						enabled = {
							type = "toggle",
							name = L["Enable"],
							order = 1,
							get = function()
								return mod.db.enabled
							end,
							set = function()
								if mod.db.enabled then
									mod.db.enabled = false
									HideDisplay()
								else
									mod.db.enabled = true
									ShowDisplay()
									UpdateDisplay()
								end
							end
						},
						locked = {
							type = "toggle",
							name = L["Lock"],
							order = 2,
							disabled = disabled
						},
						sep1 = {
							type = "description",
							name = " ",
							order = 3,
							width = "double"
						},
						showTest = {
							type = "execute",
							name = L["Spawn Test bars"],
							order = 4,
							disabled = disabled,
							func = function()
								mod:SpawnTestBar()
							end
						},
						reset = {
							type = "execute",
							name = RESET,
							order = 5,
							confirm = function()
								return L:F("Are you sure you want to reset %s to default?", L["Raid Cooldowns"])
							end,
							func = function()
								KRU.db.profile.cooldowns = defaults
								mod.db = KRU.db.profile.cooldowns
								UpdateDisplay()
							end
						},
						sep2 = {
							type = "description",
							name = " ",
							order = 6,
							width = "double"
						},
						appearance = {
							type = "group",
							name = L["Appearance"],
							order = 7,
							inline = true,
							disabled = disabled,
							args = {
								classColor = {
									type = "toggle",
									name = L["Class color"],
									order = 1
								},
								color = {
									type = "color",
									name = L["Custom color"],
									order = 2,
									get = function()
										return unpack(mod.db.color)
									end,
									set = function(_, r, g, b)
										mod.db.color = {r, g, b, 1}
										UpdateDisplay()
									end
								},
								width = {
									type = "range",
									name = L["Width"],
									order = 3,
									min = 50,
									max = 500,
									step = 5,
									bigStep = 10
								},
								height = {
									type = "range",
									name = L["Height"],
									order = 4,
									min = 6,
									max = 30,
									step = 1,
									bigStep = 1
								},
								spacing = {
									type = "range",
									name = L["Spacing"],
									order = 5,
									min = 0,
									max = 30,
									step = 0.01,
									bigStep = 1
								},
								scale = {
									type = "range",
									name = L["Scale"],
									order = 6,
									min = 1,
									max = 2,
									step = 0.01,
									bigStep = 0.1
								},
								orientation = {
									type = "select",
									name = L["Orientation"],
									order = 7,
									values = {L["Right to left"], L["Left to right"]},
									get = function()
										return (mod.db.orientation == 3) and 2 or 1
									end,
									set = function(_, val)
										mod.db.orientation = (val == 2) and 3 or 1
										UpdateDisplay()
									end
								},
								texture = {
									type = "select",
									name = L["Texture"],
									order = 8,
									dialogControl = "LSM30_Statusbar",
									values = AceGUIWidgetLSMlists.statusbar
								},
								font = {
									type = "select",
									name = L["Font"],
									dialogControl = "LSM30_Font",
									order = 9,
									values = AceGUIWidgetLSMlists.font
								},
								fontSize = {
									type = "range",
									name = L["Font Size"],
									order = 10,
									min = 5,
									max = 30,
									step = 1
								},
								fontFlags = {
									type = "select",
									name = L["Font Outline"],
									order = 11,
									values = {
										[""] = NONE,
										["OUTLINE"] = L["Outline"],
										["THINOUTLINE"] = L["Thin outline"],
										["THICKOUTLINE"] = L["Thick outline"],
										["MONOCHROME"] = L["Monochrome"],
										["OUTLINEMONOCHROME"] = L["Outlined monochrome"]
									}
								},
								sep1 = {
									type = "description",
									name = " ",
									order = 12,
									width = "double"
								},
								maxbars = {
									type = "range",
									name = L["Max Bars"],
									order = 13,
									min = 1,
									max = 60,
									step = 1,
									bigStep = 1
								},
								growUp = {
									type = "toggle",
									name = L["Grow Upwards"],
									order = 15
								}
							}
						},
						show = {
							type = "group",
							name = L["Show"],
							order = 8,
							inline = true,
							disabled = disabled,
							args = {
								onlySelf = {
									type = "toggle",
									name = L["Only show my spells"],
									order = 1
								},
								neverSelf = {
									type = "toggle",
									name = L["Never show my spells"],
									order = 2
								},
								showIcon = {
									type = "toggle",
									name = L["Icon"],
									order = 3
								},
								showDuration = {
									type = "toggle",
									name = L["Duration"],
									order = 4
								}
							}
						}
					}
				},
				spells = {
					type = "group",
					name = SPELLS,
					childGroups = "select",
					order = 2,
					disabled = disabled,
					get = function(i)
						return mod.db.spells[i.arg]
					end,
					set = function(i, val)
						if val then
							mod.db.spells[i.arg] = true
						else
							mod.db.spells[i.arg] = nil
						end
						UpdateDisplay()
					end,
					args = {}
				}
			}
		}

		local _order = 1
		for class, spells in pairs(cooldowns) do
			local opt = {
				type = "group",
				name = classes[class],
				order = _order,
				args = {}
			}
			for spellid in pairs(spells) do
				local spellname = GetSpellInfo(spellid)
				if spellname then
					opt.args[spellname] = {
						type = "toggle",
						name = spellname,
						arg = spellid
					}
				end
			end
			options.args.spells.args[class] = opt
			_order = _order + 1
		end
	end

	return options
end

function CreateDisplay()
	if display then
		if mod.db.enabled then
			ShowDisplay()
		end
		return
	end

	display = mod:GetBarGroup(L["Raid Cooldowns"])
	if not display then
		display = mod:NewBarGroup(L["Raid Cooldowns"], nil, mod.db.width, mod.db.height, "KRURaidCooldownsFrame")
	end
	display:SetFlashPeriod(0)
	display:RegisterCallback("AnchorClicked", mod.AnchorClicked)
	display:RegisterCallback("AnchorMoved", mod.AnchorMoved)
	display:SetClampedToScreen(true)
	display:SetFont(LSM:Fetch("font", mod.db.font), mod.db.fontSize, mod.db.fontFlags)
	display:SetTexture(LSM:Fetch("statusbar", mod.db.texture))
	display:SetScale(mod.db.scale)
	display:SetOrientation(mod.db.orientation)
	display:ReverseGrowth(mod.db.growUp)
	display:SetWidth(mod.db.width or 150)
	display:SetHeight(mod.db.height or 14)
	display:SetSpacing(mod.db.spacing or 0)
	display:SetMaxBars(mod.db.maxbars)
	KRU:RestorePosition(display, mod.db)

	if mod.db.locked then
		display:HideAnchor()
	else
		display:ShowAnchor()
	end

	if mod.db.showIcon then
		display:ShowIcon()
	else
		display:HideIcon()
	end
end

function mod:AnchorClicked(_, btn)
	if btn == "RightButton" then
		KRU:OpenConfig("cooldowns", "general")
	end
end

function mod:AnchorMoved()
	KRU:SavePosition(display, mod.db)
end

function ShowDisplay()
	if not display then
		CreateDisplay()
	end
	display:Show()
	mod:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end

function HideDisplay()
	if display then
		mod:UnregisterAllEvents()
		display:Hide()
		display = nil
	end
end

function LockDisplay()
	if not display then
		CreateDisplay()
	end
	display:HideAnchor()
	display:Lock()
end

function UnlockDisplay()
	if not display then
		CreateDisplay()
	end
	display:ShowAnchor()
	display:Unlock()
end

function UpdateDisplay()
	if not display then
		CreateDisplay()
	end
	display:SetFont(LSM:Fetch("font", mod.db.font), mod.db.fontSize, mod.db.fontFlags)
	display:SetTexture(LSM:Fetch("statusbar", mod.db.texture))
	display:SetScale(mod.db.scale)
	display:ReverseGrowth(mod.db.growUp)
	display:SetOrientation(mod.db.orientation)
	display:SetWidth(mod.db.width or 150)
	display:SetHeight(mod.db.height)
	display:SetHeight(mod.db.height)
	display:SetSpacing(mod.db.spacing or 0)
	display:SetMaxBars(mod.db.maxbars)
	KRU:RestorePosition(display, mod.db)

	if mod.db.locked then
		display:HideAnchor()
	else
		display:ShowAnchor()
	end

	if mod.db.showIcon then
		display:ShowIcon()
	else
		display:HideIcon()
	end
end

do
	local spellList, reverseClass
	local _testUnits = {
		Priest1 = "PRIEST",
		Mage1 = "MAGE",
		Warrior1 = "WARRIOR",
		Priest2 = "PRIEST",
		Priest3 = "PRIEST",
		DeathKnight1 = "DEATHKNIGHT",
		Hunter1 = "HUNTER",
		Rogue1 = "ROGUE",
		DeathKnight2 = "DEATHKNIGHT",
		Druid1 = "DRUID",
		Paladin1 = "PALADIN",
		Warlock1 = "WARLOCK",
		Shaman1 = "SHAMAN",
		Rogue2 = "ROGUE",
		Warrior2 = "WARRIOR",
		Paladin2 = "PALADIN",
		Druid2 = "DRUID"
	}

	function mod:SpawnTestBar()
		if not spellList then
			spellList, reverseClass = {}, {}
			for k in pairs(allSpells) do
				spellList[#spellList + 1] = k
			end
			for name, class in pairs(_testUnits) do
				reverseClass[class] = name
			end
		end
		local spell = spellList[math.random(1, #spellList)]
		local name = GetSpellInfo(spell)
		if name then
			local unit = reverseClass[classLookup[spell]]
			local duration = (allSpells[spell] / 30) + math.random(1, 120)
			mod:StartCooldown(unit, spell, duration, nil)
		end
	end
end

function mod:StartCooldown(unit, spell, duration, target, class)
	if mod.db.neverSelf and unit == playername then
		return
	end
	if mod.db.onlySelf and unit ~= playername then
		return
	end

	local bar = display:GetBar(unit .. "_" .. spell)
	if not bar then
		if target and target ~= unit then
			bar = display:NewTimerBar(unit .. "_" .. spell, unit .. " > " .. target, duration, duration, spell)
		else
			bar = display:NewTimerBar(unit .. "_" .. spell, unit, duration, duration, spell)
		end
	end

	if not mod.db.showDuration then
		bar:HideTimerLabel()
	end

	bar.caster = unit
	bar.spellId = spell
	bar.target = target

	if mod.db.classColor then
		class = class or select(2, UnitClass(unit))
		if not class then
			for k, v in pairs(classLookup) do
				if k == spell then
					class = v
					break
				end
			end
		end

		if class then
			local color = classcolors[class]
			if type(color) == "table" then
				bar:SetColorAt(1.00, color.r, color.g, color.b, 1)
				bar:SetColorAt(0.00, color.r, color.g, color.b, 1)
			end
		end
	else
		local r, g, b, a = unpack(mod.db.color)
		bar:SetColorAt(1.00, r, g, b, a)
		bar:SetColorAt(0.00, r, g, b, a)
	end

	display:SortBars()
end

do
	local events = {
		SPELL_AURA_APPLIED = true,
		SPELL_CAST_SUCCESS = true,
		SPELL_CREATE = true,
		SPELL_RESURRECT = true
	}

	local band = bit.band
	local group = 0x7
	if COMBATLOG_OBJECT_AFFILIATION_MINE then
		group =
			COMBATLOG_OBJECT_AFFILIATION_MINE + COMBATLOG_OBJECT_AFFILIATION_PARTY + COMBATLOG_OBJECT_AFFILIATION_RAID
	end

	function inGroup(flags)
		return flags and (band(flags, group) ~= 0) or nil
	end

	function mod:COMBAT_LOG_EVENT_UNFILTERED(...)
		if arg2 and events[arg2] and inGroup(arg5) and arg9 then
			if (arg9 == 35079 or arg9 == 34477) and self.db.spells[34477] then
				self:StartCooldown(arg4, 34477, allSpells[34477], arg7)
			elseif (arg9 == 59628 or arg9 == 57934) and self.db.spells[57934] then
				self:StartCooldown(arg4, 57934, allSpells[57934], arg7)
			elseif self.db.spells[arg9] then
				self:StartCooldown(arg4, arg9, allSpells[arg9], arg7)
			end
		end
	end
end

function mod:OnInitialize()
	self.db = KRU.db.profile.cooldowns
	KRU.options.args.cooldowns = GetOptions()
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

	SLASH_KRUCOOLDOWNS1 = "/rcd"
	SlashCmdList.KRUCOOLDOWNS = function()
		KRU:OpenConfig("cooldowns", "general")
	end
end