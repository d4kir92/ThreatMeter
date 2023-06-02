local _, ThreatMeter = ...
local DEBUG = false

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

	for i = 1, 8 do
		highestThreatPercentage = ThreatMeter:TestThreat("boss" .. i, highestThreatPercentage)
	end

	for i = 1, 4 do
		highestThreatPercentage = ThreatMeter:TestThreat("party" .. i .. "target", highestThreatPercentage)
		highestThreatPercentage = ThreatMeter:TestThreat("partypet" .. i .. "target", highestThreatPercentage)
	end

	for i = 1, 40 do
		highestThreatPercentage = ThreatMeter:TestThreat("raid" .. i .. "target", highestThreatPercentage)
		highestThreatPercentage = ThreatMeter:TestThreat("raidpet" .. i .. "target", highestThreatPercentage)
	end

	highestThreatPercentage = ThreatMeter:TestThreat("target", highestThreatPercentage)
	highestThreatPercentage = ThreatMeter:TestThreat("targettarget", highestThreatPercentage)
	highestThreatPercentage = ThreatMeter:TestThreat("pettarget", highestThreatPercentage)
	highestThreatPercentage = ThreatMeter:TestThreat("focustarget", highestThreatPercentage)
	highestThreatPercentage = ThreatMeter:TestThreat("mouseover", highestThreatPercentage)
	highestThreatPercentage = ThreatMeter:TestThreat("mouseovertarget", highestThreatPercentage)

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
	self.frame = CreateFrame("Frame", "TMFrame", UIParent)
	self.frame:SetSize(200, 20)
	self.frame:SetPoint("CENTER", 0, 200)
	self.frame:SetClampedToScreen(true)
	self.frame:EnableMouse(true)
	self.frame:RegisterForDrag("LeftButton")

	if ThreatMeter:GetValue("lockedText", true) then
		self.frame:SetMovable(false)
	else
		self.frame:SetMovable(true)
	end

	self.frame:SetScript("OnDragStart", function(sel)
		if not InCombatLockdown() and sel:IsMovable() then
			ThreatMeter:ShowGrid(sel)
			sel:StartMoving()
		else
			if InCombatLockdown() then
				ThreatMeter:MSG("Can't be moved in Combat.")
			elseif not sel:IsMovable() then
				ThreatMeter:MSG("Text is locked. Unlock it at Minimap-Button.")
			end
		end
	end)

	self.frame:SetScript("OnDragStop", function(sel)
		ThreatMeter:HideGrid(sel)
		self.frame:StopMovingOrSizing()
		local p1, _, p3, p4, p5 = self.frame:GetPoint()
		p4 = ThreatMeter:Grid(p4)
		p5 = ThreatMeter:Grid(p5)
		ThreatMeter:SetPoint("TMFrame", p1, "UIParent", p3, p4, p5)
		self.frame:ClearAllPoints()
		self.frame:SetPoint(p1, "UIParent", p3, p4, p5)
	end)

	local p1, p2, p3, p4, p5 = ThreatMeter:GetPoint("TMFrame")

	if p1 then
		self.frame:ClearAllPoints()
		self.frame:SetPoint(p1, p2, p3, p4, p5)
	end

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

frame:SetScript("OnEvent", function(sel, event, ...)
	if event == "PLAYER_LOGIN" then
		ThreatMeter:CreateFrame()
	end
end)