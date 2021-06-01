assert(KRU, "Raid Utilities not found!")

-- > start of module declaration and options < --
local L = KRU.L
local mod = KRU:NewModule(LOOT_METHOD, "AceEvent-3.0")

local defaults = {
	enabled = false,
	party = {
		enabled = true,
		method = "group",
		threshold = 2,
		master = ""
	},
	raid = {
		enabled = true,
		method = "master",
		threshold = 2,
		master = ""
	}
}

if not KRU.defaults then
	KRU.defaults = {profile = {}}
end
KRU.defaults.profile.loot = defaults

KRU.options.args.loot = {
	type = "group",
	name = LOOT_METHOD,
	order = 2,
	args = {
		enabled = {
			type = "toggle",
			name = L["Enable"],
			order = 1,
			get = function()
				return mod.db.enabled
			end,
			set = function(_, val)
				mod.db.enabled = val
				mod:HandleLootMethod()
			end
		},
		party = {
			type = "group",
			name = PARTY,
			order = 2,
			inline = true,
			disabled = function()
				return not mod.db.enabled
			end,
			get = function(i)
				return mod.db.party[i[#i]]
			end,
			set = function(i, val)
				mod.db.party[i[#i]] = val
			end,
			args = {
				enabled = {
					type = "toggle",
					name = L["Enable"],
					order = 1,
					width = "double"
				},
				method = {
					type = "select",
					name = LOOT_METHOD,
					order = 2,
					disabled = function()
						return not (mod.db.enabled and mod.db.party.enabled)
					end,
					values = {
						needbeforegreed = LOOT_NEED_BEFORE_GREED,
						freeforall = LOOT_FREE_FOR_ALL,
						roundrobin = LOOT_ROUND_ROBIN,
						master = LOOT_MASTER_LOOTER,
						group = LOOT_GROUP_LOOT
					}
				},
				threshold = {
					type = "select",
					name = LOOT_THRESHOLD,
					order = 3,
					disabled = function()
						return not (mod.db.enabled and mod.db.party.enabled)
					end,
					values = {
						[2] = "|cff1eff00" .. ITEM_QUALITY2_DESC .. "|r",
						[3] = "|cff0070dd" .. ITEM_QUALITY3_DESC .. "|r",
						[4] = "|cffa335ee" .. ITEM_QUALITY4_DESC .. "|r",
						[5] = "|cffff8000" .. ITEM_QUALITY5_DESC .. "|r",
						[6] = "|cffe6cc80" .. ITEM_QUALITY6_DESC .. "|r"
					}
				}
			}
		},
		raid = {
			type = "group",
			name = RAID,
			order = 3,
			inline = true,
			disabled = function()
				return not mod.db.enabled
			end,
			get = function(i)
				return mod.db.raid[i[#i]]
			end,
			set = function(i, val)
				mod.db.raid[i[#i]] = val
			end,
			args = {
				enabled = {
					type = "toggle",
					name = L["Enable"],
					order = 1,
					width = "double"
				},
				method = {
					type = "select",
					name = LOOT_METHOD,
					order = 2,
					disabled = function()
						return not mod.db.raid.enabled
					end,
					values = {
						needbeforegreed = LOOT_NEED_BEFORE_GREED,
						freeforall = LOOT_FREE_FOR_ALL,
						roundrobin = LOOT_ROUND_ROBIN,
						master = LOOT_MASTER_LOOTER,
						group = LOOT_GROUP_LOOT
					}
				},
				threshold = {
					type = "select",
					name = LOOT_THRESHOLD,
					order = 3,
					disabled = function()
						return not mod.db.raid.enabled
					end,
					values = {
						[2] = "|cff1eff00" .. ITEM_QUALITY2_DESC .. "|r",
						[3] = "|cff0070dd" .. ITEM_QUALITY3_DESC .. "|r",
						[4] = "|cffa335ee" .. ITEM_QUALITY4_DESC .. "|r",
						[5] = "|cffff8000" .. ITEM_QUALITY5_DESC .. "|r",
						[6] = "|cffe6cc80" .. ITEM_QUALITY6_DESC .. "|r"
					}
				}
			}
		},
		reset = {
			type = "execute",
			name = RESET,
			order = 99,
			width = "double",
			confirm = function()
				return L:F("Are you sure you want to reset %s to default?", LOOT_METHOD)
			end,
			func = function()
				KRU.db.profile.loot = defaults
				mod.db = KRU.db.profile.loot
			end
		}
	}
}

local IsRaidLeader, IsPartyLeader = IsRaidLeader, IsPartyLeader
local GetLootMethod, SetLootMethod = GetLootMethod, SetLootMethod
local GetLootThreshold, SetLootThreshold = GetLootThreshold, SetLootThreshold
local UnitName = UnitName

local frame = CreateFrame("Frame")
frame:Hide()
frame:SetScript("OnUpdate", function(self, elapsed)
	self.elapsed = (self.elapsed or 0) + elapsed
	if self.elapsed >= 3 then
		SetLootThreshold(self.threshold)
		self:Hide()
	end
end)
-- > end of module declaration and options < --

function mod:HandleLootMethod()
	if not self.db.enabled then
		return
	end
	local ranked, key = KRU:IsPromoted()
	if not ranked or not key then
		return
	end
	if not self.db[key].enabled then
		return
	end

	if IsRaidLeader() or IsPartyLeader() then
		local method = self.db[key].method
		local threshold = self.db[key].threshold

		local current = GetLootMethod()
		if current and current == method then
			-- the threshold was changed, so we make sure to change it.
			if threshold ~= GetLootThreshold() then
				frame.threshold = threshold
				frame.elapsed = 0
				frame:Show()
			end
			return
		end
		SetLootMethod(method, UnitName("player"), threshold)

		if method == "master" or method == "group" then
			frame.threshold = threshold
			frame.elapsed = 0
			frame:Show()
		end
	end
end

function mod:OnInitialize()
	self.db = KRU.db.profile.loot
end

function mod:OnEnable()
	self:HandleLootMethod()
	if self.db.enabled then
		self:RegisterEvent("PARTY_CONVERTED_TO_RAID", "HandleLootMethod")
	else
		self:UnregisterAllEvents()
	end

	SLASH_KRULOOTMETHOD1 = "/loot"
	SlashCmdList.KRULOOTMETHOD = function()
		KRU:OpenConfig("loot")
	end
end