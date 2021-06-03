assert(KRU, "Raid Utilities not found!")

-- > start of module declaration and options < --
local L = KRU.L
local mod = KRU:NewModule(L["Auto Invites"], "AceEvent-3.0")

local defaults = {keyword = "", guildkeyword = ""}

if not KRU.defaults then
	KRU.defaults = {profile = {}}
end
KRU.defaults.profile.invites = defaults
-- > end of module declaration and options < --

local inGuild
local guildRanks, GetGuildRanks = {}
local options, GetOptions

local DoActualInvites, DoGuildInvites
local inviteFrame, inviteQueue = CreateFrame("Frame"), {}

local function CanInvite()
	return (KRU:InGroup() and KRU:IsPromoted()) or not KRU:InGroup()
end

local function InviteGuild()
	if CanInvite() then
		GuildRoster()
		SendChatMessage(L["All max level characters will be invited to raid in 10 seconds. Please leave your groups."], "GUILD")
		KRU.After(10, function() DoGuildInvites(MAX_PLAYER_LEVEL) end)
	end
end

local function InviteZone()
	if CanInvite() then
		GuildRoster()
		local zone = GetRealZoneText()
		SendChatMessage(L:F("All characters in %s will be invited to raid in 10 seconds. Please leave your groups.", zone), "GUILD")
		KRU.After(10, function() DoGuildInvites(nil, zone) end)
	end
end

local function InviteRank(rank, name)
	if CanInvite() then
		GuildRoster()
		GuildControlSetRank(rank)

		local ochat = select(3, GuildControlGetRankFlags())
		local channel = ochat and "OFFICER" or "GUILD"
		SendChatMessage(L:F("All characters of rank %s or higher will be invited to raid in 10 seconds. Please leave your groups.", name), "GUILD")
		KRU.After(10, function() DoGuildInvites(nil, nil, rank) end)
	end
end

local function _convertToRaid(self, elapsed)
	self.elapsed = (self.elapsed or 0) + elapsed
	if self.elapsed > 1 then
		self.elapsed = 0
		if UnitInRaid("player") then
			DoActualInvites()
			self:SetScript("OnUpdate", nil)
		end
	end
end

local function _waitForParty(self, elapsed)
	self.elapsed = (self.elapsed or 0) + elapsed
	if self.elapsed > 1 then
		self.elapsed = 0
		if GetNumPartyMembers() > 0 then
			ConvertToRaid()
			self:SetScript("OnUpdate", _convertToRaid)
		end
	end
end

function DoActualInvites()
	if not UnitInRaid("player") then
		local num = GetNumPartyMembers() + 1
		if num == 5 then
			if #inviteQueue > 0 then
				ConvertToRaid()
				inviteFrame:SetScript("OnUpdate", _convertToRaid)
			end
		else
			local tmp = {}
			for i = 1, (5 - num) do
				local u = tremove(inviteQueue)
				if u then
					tmp[u] = true
				end
			end
			if #inviteQueue > 0 then
				inviteFrame:SetScript("OnUpdate", _waitForParty)
			end
			for k in pairs(tmp) do
				InviteUnit(k)
			end
		end
		return
	end
	for _, v in next, inviteQueue do
		InviteUnit(v)
	end
	inviteQueue = {}
end

function DoGuildInvites(level, zone, rank)
	for i = 1, GetNumGuildMembers() do
		local name, _, rankindex, unitlevel, _, unitzone, _, _, online = GetGuildRosterInfo(i)
		if name and online and not UnitInParty(name) and not UnitInRaid(name) then
			if (level and level <= unitlevel) or (zone and zone == unitzone) or (rank and (rankindex + 1) <= rank) then
				inviteQueue[#inviteQueue + 1] = name
			end
		end
	end
	DoActualInvites()
end

function ListGuildRanks()
	if inGuild and not next(guildRanks) then
		for i = 1, GuildControlGetNumRanks() do
			local rankname = GuildControlGetRankName(i)
			tinsert(guildRanks, i, rankname)
		end
		return guildRanks
	end
	return guildRanks
end

function GetOptions()
	if not options then
		inGuild = inGuild or IsInGuild()

		options = {
			type = "group",
			name = L["Auto Invites"],
			order = 3,
			args = {
				quickinvite = {
					type = "group",
					inline = true,
					name = L["Quick Invites"],
					order = 1,
					disabled = function()
						return not inGuild
					end,
					hidden = function()
						return not inGuild
					end,
					args = {
						guild = {
							type = "execute",
							name = L["Invite guild"],
							desc = L["Invite everyone in your guild at the maximum level."],
							order = 2,
							disabled = function()
								return not CanInvite()
							end,
							func = InviteGuild
						},
						zone = {
							type = "execute",
							name = L["Invite zone"],
							desc = L["Invite everyone in your guild who are in the same zone as you."],
							order = 3,
							disabled = function()
								return not CanInvite()
							end,
							func = InviteZone
						}
					}
				},
				keywordinvite = {
					type = "group",
					inline = true,
					name = L["Keyword Invites"],
					order = 2,
					args = {
						keyword = {
							type = "input",
							name = L["Keyword"],
							desc = L["Anyone who whispers you this keyword will automatically and immediately be invited to your group."],
							order = 1,
							get = function()
								return mod.db.keyword
							end,
							set = function(_, val)
								mod.db.keyword = val:trim()
								keyword = (mod.db.keyword ~= "") and mod.db.keyword or nil
							end
						},
						guildkeyword = {
							type = "input",
							name = L["Guild Keyword"],
							desc = L["Any guild member who whispers you this keyword will automatically and immediately be invited to your group."],
							order = 2,
							disabled = function()
								return not inGuild
							end,
							get = function()
								return mod.db.guildkeyword
							end,
							set = function(_, val)
								mod.db.guildkeyword = val:trim()
								guildkeyword = (mod.db.guildkeyword ~= "") and mod.db.guildkeyword or nil
							end
						}
					}
				},
				rankinvite = {
					type = "group",
					inline = true,
					name = L["Rank Invites"],
					descStyle = "inline",
					order = 3,
					disabled = function()
						return not inGuild
					end,
					hidden = function()
						return not inGuild
					end,
					args = {
						desc = {
							type = "description",
							name = L["Clicking any of the buttons below will invite anyone of the selected rank AND HIGHER to your group. So clicking the 3rd button will invite anyone of rank 1, 2 or 3, for example. It will first post a message in either guild or officer chat and give your guild members 10 seconds to leave their groups before doing the actual invites."],
							width = "double",
							order = 0
						}
					}
				}
			}
		}
	end
	return options
end

local function IsGuildMember(name)
	inGuild = inGuild or IsInGuild()
	if inGuild then
		for i = 1, GetNumGuildMembers() do
			local n = GetGuildRosterInfo(i)
			if n == name then
				return true
			end
		end
	end
	return false
end

inviteFrame:SetScript("OnEvent", function(self, event, msg, sender)
	if (mod.db.keyword and msg == mod.db.keyword) or (mod.db.guildkeyword and msg == mod.db.guildkeyword and IsGuildMember(sender) and CanInvite()) then
		local inInstance, instanceType = IsInInstance()
		local numparty, numraid = GetNumPartyMembers(), GetNumRaidMembers()
		if inInstance and instanceType == "party" and party == 4 then
			SendChatMessage(L["Sorry, the group is full."], "WHISPER", nil, sender)
		elseif party == 4 and raid == 0 then
			inviteQueue[#inviteQueue + 1] = sender
			DoActualInvites()
		elseif raid == 40 then
			SendChatMessage(L["Sorry, the group is full."], "WHISPER", nil, sender)
		else
			InviteUnit(sender)
		end
	end
end)

function mod:OnInitialize()
	self.db = KRU.db.profile.invites
	options = options or GetOptions()
	if inGuild then
		local ranks, numorder = ListGuildRanks(), 1
		for i, name in ipairs(ranks) do
			options.args.rankinvite.args[name .. i] = {
				type = "execute",
				name = name,
				desc = L:F("Invite all guild members of rank %s or higher.", name),
				order = numorder,
				func = function()
					InviteRank(i, name)
				end,
				disabled = function()
					return not CanInvite()
				end
			}
			numorder = numorder + 1
		end
	end
	KRU.options.args.invites = options
end

function mod:OnEnable()
	GuildRoster()
	inGuild = IsInGuild()

	if self.db.keyword or self.db.guildkeyword then
		inviteFrame:RegisterEvent("CHAT_MSG_BN_WHISPER")
		inviteFrame:RegisterEvent("CHAT_MSG_WHISPER")
		self:RegisterEvent("GUILD_ROSTER_UPDATE")
	else
		inviteFrame:UnregisterAllEvents()
	end

	SLASH_KRUINVITES1 = "/invites"
	SlashCmdList.KRUINVITES = function(cmd)
		cmd = cmd and cmd:lower():trim()
		if cmd == "guild" then
			InviteGuild()
		elseif cmd == "zone" then
			InviteZone()
		else
			KRU:OpenConfig("invites")
		end
	end
end

function mod:GUILD_ROSTER_UPDATE()
	inGuild = IsInGuild()
	wipe(guildRanks)
	guildRanks = inGuild and ListGuildRanks() or {}
end