assert(KRU, "Raid Utilities not found!")

-- > start of module declaration and options < --
local L = KRU.L
local mod = KRU:NewModule(L["Raid Menu"], "AceEvent-3.0")

local defaults = {
	enabled = true,
	locked = false,
	point = "TOP",
	xOfs = -400,
	yOfs = 1
}
if not KRU.defaults then
	KRU.defaults = {profile = {}}
end
KRU.defaults.profile.menu = defaults

KRU.options.args.menu = {
	type = "group",
	name = RAID_CONTROL,
	order = 1,
	get = function(i)
		return mod.db[i[#i]]
	end,
	set = function(i, val)
		mod.db[i[#i]] = val
		mod:Toggle()
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
		}
	}
}
-- > end of module declaration and options < --

local InCombatLockdown = InCombatLockdown
local DoReadyCheck = DoReadyCheck
local ToggleFriendsFrame = ToggleFriendsFrame
local GetRaidRosterInfo = GetRaidRosterInfo
local UninviteUnit = UninviteUnit
local IsRaidLeader, IsRaidOfficer, IsPartyLeader = IsRaidLeader, IsRaidOfficer, IsPartyLeader
local GetNumRaidMembers, GetNumPartyMembers = GetNumRaidMembers, GetNumPartyMembers
local IsInInstance = IsInInstance
local CreateFrame = CreateFrame

local RaidUtilityPanel
local showButton

StaticPopupDialogs.DISBAND_RAID = {
	text = L["Are you sure you want to disband the group?"],
	button1 = ACCEPT,
	button2 = CANCEL,
	OnAccept = function()
		if InCombatLockdown() then
			return
		end
		local numRaid = GetNumRaidMembers()
		if numRaid > 0 then
			for i = 1, numRaid do
				local name, _, _, _, _, _, _, online = GetRaidRosterInfo(i)
				if online and name ~= UnitName("player") then
					UninviteUnit(name)
				end
			end
		else
			for i = MAX_PARTY_MEMBERS, 1, -1 do
				if GetPartyMember(i) then
					UninviteUnit(UnitName("party" .. i))
				end
			end
		end
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	preferredIndex = 3
}

local function CheckRaidStatus()
	local inInstance, instanceType = IsInInstance()
	if (((IsRaidLeader() or IsRaidOfficer()) and GetNumRaidMembers() > 0) or (IsPartyLeader() and GetNumPartyMembers() > 0)) and not (inInstance and (instanceType == "pvp" or instanceType == "arena")) then
		return true
	else
		return false
	end
end

local function CreateRaidUtilityPanel()
	if RaidUtilityPanel or not mod.db.enabled then
		return
	end

	RaidUtilityPanel = CreateFrame("Frame", "KRURaidControlPanel", UIParent, "SecureHandlerClickTemplate")
	RaidUtilityPanel:SetBackdrop({
		bgFile = [[Interface\DialogFrame\UI-DialogBox-Background-Dark]],
		edgeFile = [[Interface\DialogFrame\UI-DialogBox-Border]],
		edgeSize = 8,
		insets = {left = 1, right = 1, top = 1, bottom = 1}
	})
	RaidUtilityPanel:SetBackdropColor(0, 0, 1, 0.85)
	RaidUtilityPanel:SetSize(230, 112)
	RaidUtilityPanel:SetPoint("TOP", UIParent, "TOP", -400, 1)
	RaidUtilityPanel:SetFrameLevel(3)
	RaidUtilityPanel:SetFrameStrata("HIGH")

	showButton = CreateFrame("Button", "KRURaidControl_ShowButton", UIParent, "KRUButtonTemplate, SecureHandlerClickTemplate")
	showButton:SetSize(136, 20)
	showButton:SetPoint(mod.db.point or "TOP", UIParent, mod.db.point or "TOP", mod.db.xOfs or -400, mod.db.yOfs or 0)
	showButton:SetText(RAID_CONTROL)
	showButton:SetFrameRef("KRURaidControlPanel", RaidUtilityPanel)
	showButton:SetAttribute("_onclick", [=[
		local raidUtil = self:GetFrameRef("KRURaidControlPanel")
		local closeBtn = raidUtil:GetFrameRef("KRURaidControl_CloseButton")
		self:Hide()
		raidUtil:Show()

		local point = self:GetPoint()
		local raidUtilPoint, closeBtnPoint, yOffset
		if string.find(point, "BOTTOM") then
			raidUtilPoint, closeBtnPoint, yOffset = "BOTTOM", "TOP", 2
		else
			raidUtilPoint, closeBtnPoint, yOffset = "TOP", "BOTTOM", -2
		end

		raidUtil:ClearAllPoints()
		raidUtil:SetPoint(raidUtilPoint, self, raidUtilPoint)

		closeBtn:ClearAllPoints()
		closeBtn:SetPoint(raidUtilPoint, raidUtil, closeBtnPoint, 0, yOffset)
	]=])
	showButton:SetScript("OnMouseUp", function(self) RaidUtilityPanel.toggled = true end)
	showButton:SetMovable(true)
	showButton:SetClampedToScreen(true)
	showButton:SetClampRectInsets(0, 0, -1, 1)
	showButton:RegisterForDrag("RightButton")
	showButton:SetFrameStrata("HIGH")
	showButton:SetScript("OnDragStart", function(self)
		if InCombatLockdown() then
			Print(ERR_NOT_IN_COMBAT)
			return
		elseif mod.db.locked then
			return
		end
		self.moving = true
		self:StartMoving()
	end)

	showButton:SetScript("OnDragStop", function(self)
		if self.moving then
			self.moving = nil
			self:StopMovingOrSizing()
			local point = self:GetPoint()
			local xOffset = self:GetCenter()
			local screenWidth = UIParent:GetWidth() / 2
			xOffset = xOffset - screenWidth
			self:ClearAllPoints()
			if strfind(point, "BOTTOM") then
				self:SetPoint("BOTTOM", UIParent, "BOTTOM", xOffset, -1)
			else
				self:SetPoint("TOP", UIParent, "TOP", xOffset, 1)
			end
			mod.db.point, _, _, mod.db.xOfs, mod.db.yOfs = self:GetPoint(1)
		end
	end)

	local close = CreateFrame("Button", "KRURaidControl_CloseButton", RaidUtilityPanel, "KRUButtonTemplate, SecureHandlerClickTemplate")
	close:SetSize(136, 20)
	close:SetPoint("TOP", RaidUtilityPanel, "BOTTOM", 0, -1)
	close:SetText(CLOSE)
	close:SetFrameRef("KRURaidControl_ShowButton", showButton)
	close:SetAttribute("_onclick", [=[self:GetParent():Hide(); self:GetFrameRef("KRURaidControl_ShowButton"):Show();]=])
	close:SetScript("OnMouseUp", function(self) RaidUtilityPanel.toggled = nil end)
	RaidUtilityPanel:SetFrameRef("KRURaidControl_CloseButton", close)

	local disband = CreateFrame("Button", nil, RaidUtilityPanel, "KRUButtonTemplate, SecureActionButtonTemplate")
	disband:SetSize(200, 20)
	disband:SetPoint("TOP", RaidUtilityPanel, "TOP", 0, -8)
	disband:SetText(L["Disband Group"])
	disband:SetScript("OnMouseUp", function()
		if CheckRaidStatus() then
			StaticPopup_Show("DISBAND_RAID")
		end
	end)

	local maintank = CreateFrame("Button", nil, RaidUtilityPanel, "KRUButtonTemplate, SecureActionButtonTemplate")
	maintank:SetSize(95, 20)
	maintank:SetPoint("TOPLEFT", disband, "BOTTOMLEFT", 0, -5)
	maintank:SetText(MAINTANK)
	maintank:SetAttribute("type", "maintank")
	maintank:SetAttribute("unit", "target")
	maintank:SetAttribute("action", "toggle")

	local offtank = CreateFrame("Button", nil, RaidUtilityPanel, "KRUButtonTemplate, SecureActionButtonTemplate")
	offtank:SetSize(95, 20)
	offtank:SetPoint("TOPRIGHT", disband, "BOTTOMRIGHT", 0, -5)
	offtank:SetText(MAINASSIST)
	offtank:SetAttribute("type", "mainassist")
	offtank:SetAttribute("unit", "target")
	offtank:SetAttribute("action", "toggle")

	local ready = CreateFrame("Button", nil, RaidUtilityPanel, "KRUButtonTemplate, SecureActionButtonTemplate")
	ready:SetSize(200, 20)
	ready:SetPoint("TOPLEFT", maintank, "BOTTOMLEFT", 0, -5)
	ready:SetText(READY_CHECK)
	ready:SetScript("OnMouseUp", function()
		if CheckRaidStatus() then
			DoReadyCheck()
		end
	end)

	local control = CreateFrame("Button", nil, RaidUtilityPanel, "KRUButtonTemplate, SecureActionButtonTemplate")
	control:SetSize(95, 20)
	control:SetPoint("TOPLEFT", ready, "BOTTOMLEFT", 0, -5)
	control:SetText(L["Raid Menu"])
	control:SetScript("OnMouseUp", function()
		if InCombatLockdown() then
			Print(ERR_NOT_IN_COMBAT)
			return
		end
		ToggleFriendsFrame(5)
	end)
	RaidUtilityPanel.control = control

	local convert = CreateFrame("Button", nil, RaidUtilityPanel, "SecureHandlerClickTemplate, KRUButtonTemplate")
	convert:SetSize(95, 20)
	convert:SetPoint("TOPRIGHT", ready, "BOTTOMRIGHT", 0, -5)
	convert:SetText(CONVERT_TO_RAID)
	convert:SetScript("OnMouseUp", function()
		if CheckRaidStatus() then
			ConvertToRaid()
			SetLootMethod("master", "player")
		end
	end)
	RaidUtilityPanel.convert = convert
end

function mod:OnInitialize()
	self.db = KRU.db.profile.menu
end

function mod:OnEnable()
	if _G.ElvUI then
		return
	end

	CreateRaidUtilityPanel()

	self:RegisterEvent("RAID_ROSTER_UPDATE", "Toggle")
	self:RegisterEvent("PARTY_MEMBERS_CHANGED", "Toggle")
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "Toggle")
	self:Toggle()
end

function mod:Toggle()
	if not self.db.enabled then
		if KRURaidControlPanel then
			KRURaidControlPanel:Hide()
			if KRURaidControl_ShowButton then
				KRURaidControl_ShowButton:Hide()
			end
		end
		return
	end

	CreateRaidUtilityPanel()

	if GetNumRaidMembers() == 0 and GetNumPartyMembers() > 0 and IsPartyLeader() then
		RaidUtilityPanel.control:SetWidth(95)
		RaidUtilityPanel.convert:Show()
	else
		RaidUtilityPanel.control:SetWidth(200)
		RaidUtilityPanel.convert:Hide()
	end

	if InCombatLockdown() then
		return
	end

	if CheckRaidStatus() then
		if RaidUtilityPanel.toggled == true then
			RaidUtilityPanel:Show()
			showButton:Hide()
		else
			RaidUtilityPanel:Hide()
			showButton:Show()
		end
	else
		RaidUtilityPanel:Hide()
		showButton:Hide()
	end
end