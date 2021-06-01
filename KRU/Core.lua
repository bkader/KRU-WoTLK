local folder, core = ...
local addon = LibStub("AceAddon-3.0"):NewAddon(core, "KRU")
_G.KRU = addon

local L = core.L
addon.ACD = LibStub("AceConfigDialog-3.0")
addon.LSM = LibStub("LibSharedMedia-3.0")

addon.options = {
	type = "group",
	name = "|cfff58cbaKader|r's |cffffff33Raid Utilities|r",
	args = {
		discord = {
			type = "header",
			name = "Discord Server : |c007289d9https://bitly.com/skada-rev|r",
			order = 0
		}
	}
}

function addon:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("KRUDB", self.defaults, "Default")
	LibStub("AceConfig-3.0"):RegisterOptionsTable("KRU", self.options)
	self.optionsFrame = self.ACD:AddToBlizOptions("KRU", "KRU")
end

function addon:Print(...)
	print("|cffffff33K|r|cff33ff99RU|r:", ...)
end

function addon:OnModuleCreated(mod)
	mod.Print = self.Print
end

function addon:OpenConfig(...)
	self.ACD:SetDefaultSize(folder, 635, 500)
	if ... then
		self.ACD:Open(folder)
		self.ACD:SelectGroup(folder, ...)
	elseif not self.ACD:Close(folder) then
		self.ACD:Open(folder)
	end
end

function KRU:CheckUnit(unit)
	return (unit and (UnitInParty(unit) or UnitInRaid(unit)) and UnitIsPlayer(unit) and UnitIsFriend("player", unit))
end

function KRU:InGroup()
	return (GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0)
end

function KRU:IsPromoted(name)
	name = name or "player"
	if UnitInRaid(name) then
		return UnitIsRaidOfficer(name), "raid"
	elseif UnitInParty(name) then
		return UnitIsPartyLeader(name), "party"
	end
end

-------------------------------------------------------------------------------
-- Functions to save and restore frame positions
--

function addon:SavePosition(f, db, withSize)
	if f then
		local x, y = f:GetLeft(), f:GetTop()
		local s = f:GetEffectiveScale()
		db.xOfs, db.yOfs = x * s, y * s

		if withSize then
			if db.width then
				db.width = f:GetWidth()
			end
			if db.height then
				db.height = f:GetHeight()
			end
		end
	end
end

function addon:RestorePosition(f, db, withSize)
	if f then
		local x, y = db.xOfs, db.yOfs
		if not x or not y then
			f:ClearAllPoints()
			f:SetPoint("CENTER", UIParent)
			return false
		end

		local s = f:GetEffectiveScale()
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s, y / s)

		if withSize then
			if db.width then
				f:SetWidth(db.width)
			end
			if db.height then
				f:SetHeight(db.height)
			end
		end
		return true
	end
end

-------------------------------------------------------------------------------
-- C_Timer mimic
--

do
	local setmetatable = setmetatable
	local Timer = {}

	local TickerPrototype = {}
	local TickerMetatable = {
		__index = TickerPrototype,
		__metatable = true
	}

	local waitTable = {}
	local waitFrame = _G.KRUTimerFrame or CreateFrame("Frame", "KRUTimerFrame", UIParent)
	waitFrame:SetScript("OnUpdate", function(self, elapsed)
		local total = #waitTable
		for i = 1, total do
			local ticker = waitTable[i]
			if ticker then
				if ticker._cancelled then
					tremove(waitTable, i)
				elseif ticker._delay > elapsed then
					ticker._delay = ticker._delay - elapsed
					i = i + 1
				else
					ticker._callback(ticker)
					if ticker._remainingIterations == -1 then
						ticker._delay = ticker._duration
						i = i + 1
					elseif ticker._remainingIterations > 1 then
						ticker._remainingIterations = ticker._remainingIterations - 1
						ticker._delay = ticker._duration
						i = i + 1
					elseif ticker._remainingIterations == 1 then
						tremove(waitTable, i)
						total = total - 1
					end
				end
			end
		end

		if #waitTable == 0 then
			self:Hide()
		end
	end)

	local function AddDelayedCall(ticker, oldTicker)
		if oldTicker and type(oldTicker) == "table" then
			ticker = oldTicker
		end
		tinsert(waitTable, ticker)
		waitFrame:Show()
	end

	local function CreateTicker(duration, callback, iterations)
		local ticker = setmetatable({}, TickerMetatable)
		ticker._remainingIterations = iterations or -1
		ticker._duration = duration
		ticker._delay = duration
		ticker._callback = callback

		AddDelayedCall(ticker)
		return ticker
	end

	function Timer.After(duration, callback)
		AddDelayedCall({
			_remainingIterations = 1,
			_delay = duration,
			_callback = callback
		})
	end

	function Timer.NewTimer(duration, callback)
		return CreateTicker(duration, callback, 1)
	end

	function Timer.NewTicker(duration, callback, iterations)
		return CreateTicker(duration, callback, iterations)
	end

	function TickerPrototype:Cancel()
		self._cancelled = true
	end

	addon.After = Timer.After
	addon.NewTimer = Timer.NewTimer
	addon.NewTicker = Timer.NewTicker
end