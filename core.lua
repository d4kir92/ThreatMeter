local _, ThreatMeter = ...
local enemyGuids = {}
function ThreatMeter:UnitGUID(unit, target)
	if target == nil then
		target = "player"
	end

	if UnitExists(unit) and UnitIsEnemy(target, unit) then return UnitGUID(unit) end

	return nil
end

function ThreatMeter:UnitThreat(unit, target)
	if target == nil then
		target = "player"
	end

	if UnitExists(unit) then return select(3, UnitDetailedThreatSituation(target, unit)) end

	return nil
end

function ThreatMeter:TestThreat(unit, highestTP, lowestTP, enemyCount, target)
	if target == nil then
		target = "player"
	end

	local threatPercentage = ThreatMeter:UnitThreat(unit, target)
	local enemyGuid = ThreatMeter:UnitGUID(unit, target)
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

local otherUnits = {}
tinsert(otherUnits, "player")
tinsert(otherUnits, "pet")
for i = 1, 4 do
	tinsert(otherUnits, "party" .. i)
end

for i = 1, 40 do
	tinsert(otherUnits, "raid" .. i)
end

local targetUnits = {}
for i = 1, 8 do
	tinsert(targetUnits, "boss" .. i)
end

for i = 1, 4 do
	tinsert(targetUnits, "party" .. i .. "target")
	tinsert(targetUnits, "partypet" .. i .. "target")
end

for i = 1, 40 do
	tinsert(targetUnits, "raid" .. i .. "target")
	tinsert(targetUnits, "raidpet" .. i .. "target")
end

tinsert(targetUnits, "target")
tinsert(targetUnits, "targettarget")
tinsert(targetUnits, "pettarget")
tinsert(targetUnits, "focustarget")
tinsert(targetUnits, "mouseover")
tinsert(targetUnits, "mouseovertarget")
local tabHighestTP = {}
local tabLowestTP = {}
local tabEnemyCount = {}
function ThreatMeter:UpdateThreat()
	wipe(enemyGuids)
	local highestTP = 0
	local lowestTP = 100
	local enemyCount = 0
	local highestUnit = ""
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
	local c = 0
	for i, nameplate in pairs(C_NamePlate.GetNamePlates()) do
		if "player" ~= nameplate.UnitFrame.unit and UnitIsUnit(nameplate.UnitFrame.unit, "player") then
			c = c + 1
		end
	end

	for i, targetUnit in pairs(targetUnits) do
		if "player" ~= targetUnit and UnitIsUnit(targetUnit, "player") then
			c = c + 1
		end
	end

	if enemyCount == 0 then
		enemyCount = c
	end

	if TMTAB["SHOWHIGHESTTHREAT"] then
		for x, unit in pairs(otherUnits) do
			tabHighestTP[unit] = 0
			tabLowestTP[unit] = 100
			tabEnemyCount[unit] = 0
			if UnitExists(unit) then
				for i, nameplate in pairs(C_NamePlate.GetNamePlates()) do
					tabHighestTP[unit], tabLowestTP[unit], tabEnemyCount[unit] = ThreatMeter:TestThreat(nameplate.UnitFrame.unit, tabHighestTP[unit], tabLowestTP[unit], tabEnemyCount[unit], unit)
				end

				for i = 1, 8 do
					tabHighestTP[unit], tabLowestTP[unit], tabEnemyCount[unit] = ThreatMeter:TestThreat("boss" .. i, tabHighestTP[unit], tabLowestTP[unit], tabEnemyCount[unit], unit)
				end

				for i = 1, 4 do
					tabHighestTP[unit], tabLowestTP[unit], tabEnemyCount[unit] = ThreatMeter:TestThreat("party" .. i .. "target", tabHighestTP[unit], tabLowestTP[unit], tabEnemyCount[unit], unit)
					tabHighestTP[unit], tabLowestTP[unit], tabEnemyCount[unit] = ThreatMeter:TestThreat("partypet" .. i .. "target", tabHighestTP[unit], tabLowestTP[unit], tabEnemyCount[unit], unit)
				end

				for i = 1, 40 do
					tabHighestTP[unit], tabLowestTP[unit], tabEnemyCount[unit] = ThreatMeter:TestThreat("raid" .. i .. "target", tabHighestTP[unit], tabLowestTP[unit], tabEnemyCount[unit], unit)
					tabHighestTP[unit], tabLowestTP[unit], tabEnemyCount[unit] = ThreatMeter:TestThreat("raidpet" .. i .. "target", tabHighestTP[unit], tabLowestTP[unit], tabEnemyCount[unit], unit)
				end

				tabHighestTP[unit], tabLowestTP[unit], tabEnemyCount[unit] = ThreatMeter:TestThreat("target", tabHighestTP[unit], tabLowestTP[unit], tabEnemyCount[unit], unit)
				tabHighestTP[unit], tabLowestTP[unit], tabEnemyCount[unit] = ThreatMeter:TestThreat("targettarget", tabHighestTP[unit], tabLowestTP[unit], tabEnemyCount[unit], unit)
				tabHighestTP[unit], tabLowestTP[unit], tabEnemyCount[unit] = ThreatMeter:TestThreat("pettarget", tabHighestTP[unit], tabLowestTP[unit], tabEnemyCount[unit], unit)
				tabHighestTP[unit], tabLowestTP[unit], tabEnemyCount[unit] = ThreatMeter:TestThreat("focustarget", tabHighestTP[unit], tabLowestTP[unit], tabEnemyCount[unit], unit)
				tabHighestTP[unit], tabLowestTP[unit], tabEnemyCount[unit] = ThreatMeter:TestThreat("mouseover", tabHighestTP[unit], tabLowestTP[unit], tabEnemyCount[unit], unit)
				tabHighestTP[unit], tabLowestTP[unit], tabEnemyCount[unit] = ThreatMeter:TestThreat("mouseovertarget", tabHighestTP[unit], tabLowestTP[unit], tabEnemyCount[unit], unit)
			end
		end

		local highestUnitTP = 0
		local foundHighest = false
		for i, unit in pairs(otherUnits) do
			if UnitExists(unit) and highestUnitTP < tabHighestTP[unit] then
				highestUnitTP = tabHighestTP[unit]
				highestUnit = unit
				foundHighest = true
			end
		end

		for x, unit in pairs(otherUnits) do
			c = 0
			for i, nameplate in pairs(C_NamePlate.GetNamePlates()) do
				if unit ~= nameplate.UnitFrame.unit and UnitIsUnit(nameplate.UnitFrame.unit, unit) then
					c = c + 1
				end
			end

			for i, targetUnit in pairs(targetUnits) do
				if unit ~= targetUnit and UnitIsUnit(targetUnit, unit) then
					c = c + 1
				end
			end

			if tabEnemyCount[unit] == 0 then
				tabEnemyCount[unit] = c
			end

			if c > highestUnitTP and not foundHighest then
				highestUnit = unit
			end
		end
	end

	if TMTAB and TMTAB["SHOWTEXTOUTSIDEOFCOMBAT"] == nil then
		TMTAB["SHOWTEXTOUTSIDEOFCOMBAT"] = true
	end

	if UnitAffectingCombat("player") or highestUnit ~= "" and UnitAffectingCombat(highestUnit) then
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
			self.text:SetText("|cffffff00" .. ThreatMeter:Trans("INCOMBAT") .. enemyText)
		elseif highestTP == 100 and lowestTP == 100 then
			self.text:SetText(format("%s%s", col, ThreatMeter:Trans("TANKING")) .. enemyText)
		elseif lowestTP ~= highestTP then
			self.text:SetText(format("%s%0.1f%% - %0.1f%%", col, lowestTP, highestTP) .. enemyText)
		else
			self.text:SetText(format("%s%0.1f%%", col, highestTP) .. enemyText)
		end

		if TMTAB["SHOWHIGHESTTHREAT"] and UnitExists(highestUnit) then
			local enemyTextOther = ""
			if tabEnemyCount[highestUnit] > 0 then
				enemyTextOther = " (" .. tabEnemyCount[highestUnit] .. ")"
			end

			if tabHighestTP[highestUnit] <= 0 then
				self.text2:SetText("|cffffff00" .. ThreatMeter:Trans("INCOMBAT") .. enemyTextOther)
			elseif tabHighestTP[highestUnit] == 100 and tabLowestTP[highestUnit] == 100 then
				self.text2:SetText(format("%s%s", col, ThreatMeter:Trans("TANKING")) .. enemyTextOther)
			elseif tabLowestTP[highestUnit] ~= tabHighestTP[highestUnit] then
				self.text2:SetText(format("%s%0.1f%% - %0.1f%%", col, tabLowestTP[highestUnit], tabHighestTP[highestUnit]) .. enemyTextOther)
			else
				self.text2:SetText(format("%s%0.1f%%", col, tabHighestTP[highestUnit]) .. enemyTextOther)
			end
		else
			self.text2:SetText("")
		end
	elseif not InCombatLockdown() and TMTAB["SHOWTEXTOUTSIDEOFCOMBAT"] then
		self.text:SetText("|cff00ff00" .. ThreatMeter:Trans("NOTINCOMBAT"))
		if TMTAB["SHOWHIGHESTTHREAT"] then
			self.text2:SetText("|cff00ff00" .. ThreatMeter:Trans("NOTINCOMBAT"))
		else
			self.text2:SetText("")
		end
	else
		self.text:SetText("")
		self.text2:SetText("")
	end

	if TMTAB["SHOWHIGHESTTHREAT"] and self.text:GetText() and self.text2:GetText() and self.text:GetText() ~= self.text2:GetText() then
		self.text:SetPoint("CENTER", 0, -14)
		self.text2:SetPoint("CENTER", 0, 14)
		local playerName = UnitName("PLAYER")
		local unitName = UnitName(highestUnit)
		if playerName then
			self.text:SetText(playerName .. ": " .. self.text:GetText())
		end

		if unitName then
			self.text2:SetText(unitName .. ": " .. self.text2:GetText())
		end
	else
		self.text:SetPoint("CENTER", 0, 0)
		self.text2:SetText("")
	end

	C_Timer.After(
		0.3,
		function()
			ThreatMeter:UpdateThreat()
		end
	)
end

function ThreatMeter:CreateMainFrame()
	self.frame = CreateFrame("Frame", "TMFrame", UIParent)
	self.frame:SetSize(200, 20)
	self.frame:SetPoint("CENTER", 0, 200)
	self.frame:SetClampedToScreen(true)
	self.frame:RegisterForDrag("LeftButton")
	if ThreatMeter:GV(TMTAB, "lockedText", true) then
		self.frame:SetMovable(false)
		self.frame:EnableMouse(false)
	else
		self.frame:SetMovable(true)
		self.frame:EnableMouse(true)
	end

	self.frame:SetScript(
		"OnDragStart",
		function(sel)
			if not ThreatMeter:GV(TMTAB, "lockedText", true) and not InCombatLockdown() and sel:IsMovable() then
				ThreatMeter:ShowGrid(sel)
				sel:StartMoving()
			else
				if InCombatLockdown() then
					ThreatMeter:MSG("Can't be moved in Combat.")
				elseif not sel:IsMovable() then
					ThreatMeter:MSG("Text is locked. Unlock it at Minimap-Button.")
				end
			end
		end
	)

	self.frame:SetScript(
		"OnDragStop",
		function(sel)
			ThreatMeter:HideGrid(sel)
			self.frame:StopMovingOrSizing()
			local p1, _, p3, p4, p5 = self.frame:GetPoint()
			p4 = ThreatMeter:Grid(p4)
			p5 = ThreatMeter:Grid(p5)
			ThreatMeter:SV(TMTAB, "TMFrame", {p1, "UIParent", p3, p4, p5})
			ThreatMeter:MSG("Saved new Text Position.")
			self.frame:ClearAllPoints()
			self.frame:SetPoint(p1, "UIParent", p3, p4, p5)
		end
	)

	local p1, p2, p3, p4, p5 = unpack(ThreatMeter:GV(TMTAB, "TMFrame", {}))
	if p1 then
		self.frame:ClearAllPoints()
		self.frame:SetPoint(p1, p2, p3, p4, p5)
	end

	self.text = self.frame:CreateFontString(nil, "OVERLAY")
	self.text:SetFont("Fonts\\FRIZQT__.TTF", 24, "OUTLINE")
	self.text:SetPoint("CENTER", 0, 0)
	self.text2 = self.frame:CreateFontString(nil, "OVERLAY")
	self.text2:SetFont("Fonts\\FRIZQT__.TTF", 24, "OUTLINE")
	self.text2:SetPoint("CENTER", 0, 0)
	ThreatMeter:UpdateThreat()
end
