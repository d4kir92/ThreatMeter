local AddOnName, ThreatMeter = ...
local DEBUG = false
local COLR = "|cffff0000"
local COLY = "|cffffff00"
local COLG = "|cff00ff00"
local COLADDON = "|cffff6060"

function ThreatMeter:MSG(...)
	print(format("[%s" .. AddOnName .. "|r] %s", COLADDON, COLG), ...)
end

function ThreatMeter:DEB(...)
	print(format("[%s" .. AddOnName .. "|r] [%sDEBUG|r] %s", COLADDON, COLY, COLY), ...)
end

function ThreatMeter:ERR(...)
	print(format("[%s" .. AddOnName .. "|r] %s", COLADDON, COLR), ...)
end

if DEBUG then
	ThreatMeter:DEB("> DEBUG IS ON")
end

local frame = CreateFrame("Frame", "ThreatMeterFrame", UIParent)
frame:RegisterEvent("PLAYER_LOGIN")

function ThreatMeter:UnitThreat(unit)
	if UnitExists(unit) then return select(3, UnitDetailedThreatSituation("player", unit)) end

	return 0
end

function ThreatMeter:TestThreat(unit, highestThreatPercentage)
	local threatPercentage = ThreatMeter:UnitThreat(unit)

	if threatPercentage and threatPercentage > highestThreatPercentage then
		highestThreatPercentage = threatPercentage
	end

	return highestThreatPercentage
end

function ThreatMeter:UpdateHighestThreatPercentage()
	local highestThreatPercentage = 0

	for i, nameplate in pairs(C_NamePlate.GetNamePlates()) do
		highestThreatPercentage = ThreatMeter:TestThreat(nameplate.UnitFrame.unit, highestThreatPercentage)
	end

	for i = 1, 5 do
		highestThreatPercentage = ThreatMeter:TestThreat("arena" .. i, highestThreatPercentage)
	end

	for i = 1, 8 do
		highestThreatPercentage = ThreatMeter:TestThreat("boss" .. i, highestThreatPercentage)
	end

	for i = 1, 4 do
		highestThreatPercentage = ThreatMeter:TestThreat("party" .. i, highestThreatPercentage)
		highestThreatPercentage = ThreatMeter:TestThreat("partypet" .. i, highestThreatPercentage)
	end

	for i = 1, 40 do
		highestThreatPercentage = ThreatMeter:TestThreat("raid" .. i, highestThreatPercentage)
		highestThreatPercentage = ThreatMeter:TestThreat("raidpet" .. i, highestThreatPercentage)
	end

	highestThreatPercentage = ThreatMeter:TestThreat("target", highestThreatPercentage)
	highestThreatPercentage = ThreatMeter:TestThreat("pet", highestThreatPercentage)
	highestThreatPercentage = ThreatMeter:TestThreat("focus", highestThreatPercentage)
	highestThreatPercentage = ThreatMeter:TestThreat("mouseover", highestThreatPercentage)

	if InCombatLockdown() then
		local col = "|cff00ff00"

		if highestThreatPercentage >= 100 then
			col = "|cffff0000"
		elseif highestThreatPercentage >= 67 then
			col = "|cffffff00"
		end

		if highestThreatPercentage <= 0 then
			self.text:SetText("|cffffff00IN COMBAT")
		else
			self.text:SetText(format("%s%0.1f%%", col, highestThreatPercentage))
		end
	elseif not InCombatLockdown() then
		self.text:SetText("|cff00ff00NOT IN COMBAT")
	end
end

function ThreatMeter:CreateFrame()
	self.frame = CreateFrame("Frame", nil, UIParent)
	self.frame:SetSize(200, 20)
	self.frame:SetPoint("CENTER", 0, 200)
	self.text = self.frame:CreateFontString(nil, "OVERLAY")
	self.text:SetFont("Fonts\\FRIZQT__.TTF", 24, "OUTLINE")
	self.text:SetPoint("CENTER", 0, 0)
	self.frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
	self.frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
	self.frame:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
	self.frame:RegisterEvent("PLAYER_REGEN_ENABLED")

	self.frame:SetScript("OnEvent", function(sel, event, ...)
		ThreatMeter:UpdateHighestThreatPercentage()
	end)

	ThreatMeter:UpdateHighestThreatPercentage()
end

frame:SetScript("OnEvent", function(self, event, ...)
	if event == "PLAYER_LOGIN" then
		ThreatMeter:CreateFrame()
	end
end)