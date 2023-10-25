local _, ThreatMeter = ...
local DEBUG = false
local enemyGuids = {}
if DEBUG then
	ThreatMeter:DEB("> DEBUG IS ON")
end

function ThreatMeter:UnitGUID(unit)
	if UnitExists(unit) and UnitIsEnemy("player", unit) then return UnitGUID(unit) end

	return nil
end

function ThreatMeter:UnitThreat(unit)
	if UnitExists(unit) then return select(3, UnitDetailedThreatSituation("player", unit)) end

	return nil
end

function ThreatMeter:TestThreat(unit, highestTP, lowestTP, enemyCount)
	local threatPercentage = ThreatMeter:UnitThreat(unit)
	local enemyGuid = ThreatMeter:UnitGUID(unit, threatPercentage)
	if threatPercentage then
		if threatPercentage > highestTP then
			highestTP = threatPercentage
		end

		if threatPercentage < lowestTP then
			lowestTP = threatPercentage
		end

		if enemyGuid ~= nil and not tContains(enemyGuids, enemyGuid) then
			tinsert(enemyGuids, enemyGuid)
			enemyCount = enemyCount + 1
		end
	end

	return highestTP, lowestTP, enemyCount
end

function ThreatMeter:UpdateThreat()
	wipe(enemyGuids)
	local highestTP = 0
	local lowestTP = 100
	local enemyCount = 0
	for i, nameplate in pairs(C_NamePlate.GetNamePlates()) do
		highestTP, lowestTP, enemyCount = ThreatMeter:TestThreat(nameplate.UnitFrame.unit, highestTP, lowestTP, enemyCount)
	end

	for i = 1, 8 do
		highestTP, lowestTP, enemyCount = ThreatMeter:TestThreat("boss" .. i, highestTP, lowestTP, enemyCount)
	end

	for i = 1, 4 do
		highestTP, lowestTP, enemyCount = ThreatMeter:TestThreat("party" .. i .. "target", highestTP, lowestTP, enemyCount)
		highestTP, lowestTP, enemyCount = ThreatMeter:TestThreat("partypet" .. i .. "target", highestTP, lowestTP, enemyCount)
	end

	for i = 1, 40 do
		highestTP, lowestTP, enemyCount = ThreatMeter:TestThreat("raid" .. i .. "target", highestTP, lowestTP, enemyCount)
		highestTP, lowestTP, enemyCount = ThreatMeter:TestThreat("raidpet" .. i .. "target", highestTP, lowestTP, enemyCount)
	end

	highestTP, lowestTP, enemyCount = ThreatMeter:TestThreat("target", highestTP, lowestTP, enemyCount)
	highestTP, lowestTP, enemyCount = ThreatMeter:TestThreat("targettarget", highestTP, lowestTP, enemyCount)
	highestTP, lowestTP, enemyCount = ThreatMeter:TestThreat("pettarget", highestTP, lowestTP, enemyCount)
	highestTP, lowestTP, enemyCount = ThreatMeter:TestThreat("focustarget", highestTP, lowestTP, enemyCount)
	highestTP, lowestTP, enemyCount = ThreatMeter:TestThreat("mouseover", highestTP, lowestTP, enemyCount)
	highestTP, lowestTP, enemyCount = ThreatMeter:TestThreat("mouseovertarget", highestTP, lowestTP, enemyCount)
	if TMTAB and TMTAB["SHOWTEXTOUTSIDEOFCOMBAT"] == nil then
		TMTAB["SHOWTEXTOUTSIDEOFCOMBAT"] = true
	end

	if InCombatLockdown() then
		local col = "|cff00ff00"
		if highestTP >= 100 then
			col = "|cffff0000"
		elseif highestTP >= 67 then
			col = "|cffffff00"
		end

		local enemyText = ""
		if enemyCount > 0 then
			enemyText = " (" .. enemyCount .. ")"
		end

		if highestTP <= 0 then
			self.text:SetText("|cffffff00IN COMBAT" .. enemyText)
		elseif highestTP == 100 and lowestTP == 100 then
			self.text:SetText(format("%s%s", col, "TANKING") .. enemyText)
		elseif lowestTP ~= highestTP then
			self.text:SetText(format("%s%0.1f%% - %0.1f%%", col, lowestTP, highestTP) .. enemyText)
		else
			self.text:SetText(format("%s%0.1f%%", col, highestTP) .. enemyText)
		end
	elseif not InCombatLockdown() and TMTAB["SHOWTEXTOUTSIDEOFCOMBAT"] then
		self.text:SetText("|cff00ff00NOT IN COMBAT")
	else
		self.text:SetText("")
	end
end

function ThreatMeter:CreateFrame()
	self.frame = CreateFrame("Frame", "TMFrame", UIParent)
	self.frame:SetSize(200, 20)
	self.frame:SetPoint("CENTER", 0, 200)
	self.frame:SetClampedToScreen(true)
	self.frame:RegisterForDrag("LeftButton")
	if D4:GV(TMTAB, "lockedText", true) then
		self.frame:SetMovable(false)
		self.frame:EnableMouse(false)
	else
		self.frame:SetMovable(true)
		self.frame:EnableMouse(true)
	end

	self.frame:SetScript(
		"OnDragStart",
		function(sel)
			if not D4:GV(TMTAB, "lockedText", true) and not InCombatLockdown() and sel:IsMovable() then
				D4:ShowGrid(sel)
				sel:StartMoving()
			else
				if InCombatLockdown() then
					D4:MSG("ThreatMeter", 132117, "Can't be moved in Combat.")
				elseif not sel:IsMovable() then
					D4:MSG("ThreatMeter", 132117, "Text is locked. Unlock it at Minimap-Button.")
				end
			end
		end
	)

	self.frame:SetScript(
		"OnDragStop",
		function(sel)
			D4:HideGrid(sel)
			self.frame:StopMovingOrSizing()
			local p1, _, p3, p4, p5 = self.frame:GetPoint()
			p4 = D4:Grid(p4)
			p5 = D4:Grid(p5)
			D4:SV(TMTAB, "TMFrame", {p1, "UIParent", p3, p4, p5})
			D4:MSG("ThreatMeter", 132117, "Saved new Text Position.")
			self.frame:ClearAllPoints()
			self.frame:SetPoint(p1, "UIParent", p3, p4, p5)
		end
	)

	local p1, p2, p3, p4, p5 = unpack(D4:GV(TMTAB, "TMFrame", {}))
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
	self.frame:RegisterEvent("PLAYER_REGEN_DISABLED")
	self.frame:SetScript(
		"OnEvent",
		function(sel, event, ...)
			ThreatMeter:UpdateThreat()
		end
	)

	ThreatMeter:UpdateThreat()
end