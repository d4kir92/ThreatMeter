local _, ThreatMeter = ...
local TMDebug = false
function ThreatMeter:UnitGUID(unit, target)
	target = target or "player"
	if UnitExists(unit) and UnitIsEnemy(target, unit) then return UnitGUID(unit) end

	return nil
end

function ThreatMeter:UnitThreat(unit, target)
	target = target or "player"
	if UnitExists(unit) then return select(3, UnitDetailedThreatSituation(target, unit)) end

	return nil
end

function ThreatMeter:TestThreat(unit, highestTP, lowestTP, target)
	if not UnitExists(unit) then return highestTP, lowestTP end
	target = target or "player"
	local threatPercentage = ThreatMeter:UnitThreat(unit, target)
	if threatPercentage then
		highestTP = math.max(highestTP, threatPercentage)
		lowestTP = math.min(lowestTP, threatPercentage)
	end

	return highestTP, lowestTP
end

local otherUnits = {"player", "pet"}
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
local function RGBToHex(r, g, b)
	return format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
end

function ThreatMeter:UpdateBar(text, barContainer, barLow, barHigh, barBr, low, high, r, g, b, inCombat, show)
	if TMTAB["DISPLAYBAR"] == nil then
		TMTAB["DISPLAYBAR"] = true
	end

	if show then
		if inCombat then
			if TMTAB["DISPLAYBAR"] then
				barContainer:Show()
				barBr:Show()
				local dif = 0.3
				barLow:SetStatusBarColor(math.max(0, r - dif), math.max(0, g - dif), math.max(0, b - dif))
				barHigh:SetStatusBarColor(math.min(1, r + dif), math.min(1, g + dif), math.min(1, b + dif))
				barLow:SetValue(low)
				barHigh:SetValue(high)
			else
				barContainer:Hide()
				barBr:Hide()
			end

			if high <= 0 then
				text:SetText("|cffffff00" .. ThreatMeter:Trans("LID_INCOMBAT"))
			elseif high == 100 and low == 100 then
				text:SetText(format("%s%s", RGBToHex(r, g, b), ThreatMeter:Trans("LID_TANKING")))
			elseif low ~= high then
				text:SetText(format("%s%0.1f%% - %0.1f%%", RGBToHex(r, g, b), low, high))
			else
				text:SetText(format("%s%0.1f%%", RGBToHex(r, g, b), high))
			end
		else
			barContainer:Hide()
			barBr:Hide()
			text:SetText(RGBToHex(r, g, b) .. ThreatMeter:Trans("LID_NOTINCOMBAT"))
		end
	else
		barContainer:Hide()
		barBr:Hide()
		text:SetText("")
	end
end

function ThreatMeter:UpdateThreat()
	local highestTP = 0
	local lowestTP = 100
	local highestUnit = ""
	for i, nameplate in pairs(C_NamePlate.GetNamePlates()) do
		highestTP, lowestTP = ThreatMeter:TestThreat(nameplate.UnitFrame.unit, highestTP, lowestTP)
	end

	for i = 1, 8 do
		highestTP, lowestTP = ThreatMeter:TestThreat("boss" .. i, highestTP, lowestTP)
	end

	for i = 1, 4 do
		highestTP, lowestTP = ThreatMeter:TestThreat("party" .. i .. "target", highestTP, lowestTP)
		highestTP, lowestTP = ThreatMeter:TestThreat("partypet" .. i .. "target", highestTP, lowestTP)
	end

	for i = 1, 40 do
		highestTP, lowestTP = ThreatMeter:TestThreat("raid" .. i .. "target", highestTP, lowestTP)
		highestTP, lowestTP = ThreatMeter:TestThreat("raidpet" .. i .. "target", highestTP, lowestTP)
	end

	highestTP, lowestTP = ThreatMeter:TestThreat("target", highestTP, lowestTP)
	highestTP, lowestTP = ThreatMeter:TestThreat("targettarget", highestTP, lowestTP)
	highestTP, lowestTP = ThreatMeter:TestThreat("pettarget", highestTP, lowestTP)
	highestTP, lowestTP = ThreatMeter:TestThreat("focustarget", highestTP, lowestTP)
	highestTP, lowestTP = ThreatMeter:TestThreat("mouseover", highestTP, lowestTP)
	highestTP, lowestTP = ThreatMeter:TestThreat("mouseovertarget", highestTP, lowestTP)
	if TMTAB["SHOWHIGHESTTHREAT"] then
		for x, unit in pairs(otherUnits) do
			tabHighestTP[unit] = 0
			tabLowestTP[unit] = 100
			if UnitExists(unit) then
				tabHighestTP[unit], tabLowestTP[unit] = ThreatMeter:TestThreat("target", tabHighestTP[unit], tabLowestTP[unit], unit)
			end
		end

		local highestUnitTP = 0
		for x, unit in pairs(otherUnits) do
			if UnitExists(unit) and highestUnitTP < tabHighestTP[unit] then
				highestUnitTP = tabHighestTP[unit]
				highestUnit = unit
				foundHighest = true
			end
		end
	end

	if TMTAB["SHOWTEXTOUTSIDEOFCOMBAT"] == nil then
		TMTAB["SHOWTEXTOUTSIDEOFCOMBAT"] = true
	end

	if UnitAffectingCombat("player") or highestUnit ~= "" and UnitAffectingCombat(highestUnit) then
		local r = 0
		local g = 1
		local b = 0
		if highestTP >= 100 then
			r = 1
			g = 0
			b = 0
		elseif highestTP >= 67 then
			r = 1
			g = 1
			b = 0
		end

		ThreatMeter:UpdateBar(self.text1, self.bar1Container, self.bar1, self.bar1_2, self.bar1Br, lowestTP, highestTP, r, g, b, true, true)
		if tabHighestTP and tabHighestTP[highestUnit] then
			r = 0
			g = 1
			b = 0
			if tabHighestTP[highestUnit] >= 100 then
				r = 1
				g = 0
				b = 0
			elseif tabHighestTP[highestUnit] >= 67 then
				r = 1
				g = 1
				b = 0
			end
		else
			r = 0
			g = 1
			b = 0
		end

		ThreatMeter:UpdateBar(self.text2, self.bar2Container, self.bar2, self.bar2_2, self.bar2Br, tabLowestTP[highestUnit], tabHighestTP[highestUnit], r, g, b, true, TMTAB["SHOWHIGHESTTHREAT"] and UnitExists(highestUnit))
	elseif not InCombatLockdown() and TMTAB["SHOWTEXTOUTSIDEOFCOMBAT"] then
		ThreatMeter:UpdateBar(self.text1, self.bar1Container, self.bar1, self.bar1_2, self.bar1Br, 0, 0, 0, 1, 0, false, true)
		ThreatMeter:UpdateBar(self.text2, self.bar2Container, self.bar2, self.bar2_2, self.bar2Br, 0, 0, 0, 1, 0, false, false)
	else
		ThreatMeter:UpdateBar(self.text1, self.bar1Container, self.bar1, self.bar1_2, self.bar1Br, 0, 0, 0, 0, 0, false, false)
		ThreatMeter:UpdateBar(self.text2, self.bar2Container, self.bar2, self.bar2_2, self.bar2Br, 0, 0, 0, 0, 0, false, false)
	end

	if TMDebug then
		ThreatMeter:UpdateBar(self.text1, self.bar1Container, self.bar1, self.bar1_2, self.bar1Br, 30, 60, 0, 1, 0, true, true)
		ThreatMeter:UpdateBar(self.text2, self.bar2Container, self.bar2, self.bar2_2, self.bar2Br, 20, 80, 0, 1, 0, true, true)
	end

	if TMTAB["SHOWHIGHESTTHREAT"] and self.text1:GetText() and self.text2:GetText() and self.text2:GetText() ~= "" and self.text1:GetText() ~= self.text2:GetText() then
		self.bar1Container:SetPoint("CENTER", 0, -16)
		self.text1Container:SetPoint("CENTER", 0, -16)
		self.bar2Container:SetPoint("CENTER", 0, 16)
		self.text2Container:SetPoint("CENTER", 0, 16)
		local playerName = UnitName("player")
		local unitName = UnitName(highestUnit)
		if playerName then
			self.text1:SetText(playerName .. ": " .. self.text1:GetText())
		end

		if unitName then
			self.text2:SetText(unitName .. ": " .. self.text2:GetText())
		end
	else
		self.bar1Container:SetPoint("CENTER", 0, 0)
		self.text1Container:SetPoint("CENTER", 0, 0)
		self.bar2Container:SetPoint("CENTER", 0, 0)
		self.text2Container:SetPoint("CENTER", 0, 0)
	end

	C_Timer.After(
		0.3,
		function()
			ThreatMeter:UpdateThreat()
		end
	)
end

function ThreatMeter:ToggleText(from, showMsg)
	if showMsg == nil then
		showMsg = false
	end

	if ThreatMeter:GV(TMTAB, "lockedText", true) then
		self.lockText:Hide()
		self.frame:SetMovable(false)
		self.frame:EnableMouse(false)
		if showMsg then
			ThreatMeter:MSG(ThreatMeter:Trans("LID_TEXTISNOWLOCKED"))
		end
	else
		self.lockText:Show()
		self.frame:SetMovable(true)
		self.frame:EnableMouse(true)
		if showMsg then
			ThreatMeter:MSG(ThreatMeter:Trans("LID_TEXTISNOWUNLOCKED"))
		end
	end
end

function ThreatMeter:CreateMainFrame()
	self.frame = CreateFrame("Frame", "TMFrame", UIParent)
	self.frame:SetSize(240, 80)
	self.frame:SetPoint("CENTER", 0, 200)
	ThreatMeter:SetClampedToScreen(self.frame, true)
	self.frame:RegisterForDrag("LeftButton")
	self.frame:SetScript(
		"OnDragStart",
		function(sel)
			if not ThreatMeter:GV(TMTAB, "lockedText", true) and not InCombatLockdown() and sel:IsMovable() then
				ThreatMeter:ShowGrid(sel)
				sel:StartMoving()
			else
				if InCombatLockdown() then
					ThreatMeter:MSG(ThreatMeter:Trans("LID_CANTBEMOVEDINCOMBAT"))
				elseif not sel:IsMovable() then
					ThreatMeter:MSG(ThreatMeter:Trans("LID_TEXTISLOCKEDHELPTEXT"))
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
			ThreatMeter:MSG(ThreatMeter:Trans("LID_SAVEDNEWTEXTPOSITION"))
			self.frame:ClearAllPoints()
			self.frame:SetPoint(p1, "UIParent", p3, p4, p5)
		end
	)

	local p1, p2, p3, p4, p5 = unpack(ThreatMeter:GV(TMTAB, "TMFrame", {}))
	if p1 then
		self.frame:ClearAllPoints()
		self.frame:SetPoint(p1, p2, p3, p4, p5)
	end

	self.bar1Container = CreateFrame("Frame", "bar1Container", self.frame)
	self.bar1Container:SetSize(300, 32)
	self.bar1Container:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
	self.bar1Bg = self.bar1Container:CreateTexture("bar1Bg", "BACKGROUND")
	self.bar1Bg:SetAllPoints(self.bar1Container)
	self.bar1Bg:SetTexture("Interface\\AddOns\\ThreatMeter\\media\\bar-bg")
	self.bar1Bg:SetVertexColor(1, 1, 1, 1)
	self.bar1 = CreateFrame("StatusBar", "TMbar1", self.bar1Container)
	self.bar1:SetFrameLevel(self.bar1Container:GetFrameLevel())
	self.bar1:SetPoint("TOPLEFT", 4, -4)
	self.bar1:SetPoint("BOTTOMRIGHT", -4, 4)
	self.bar1:SetMinMaxValues(0, 100)
	self.bar1:SetValue(50)
	self.bar1:SetStatusBarTexture("Interface\\AddOns\\ThreatMeter\\media\\bar2")
	self.bar1:GetStatusBarTexture():SetHorizTile(false)
	self.bar1:GetStatusBarTexture():SetVertTile(false)
	self.bar1:SetStatusBarColor(1, 1, 1)
	self.bar1_2 = CreateFrame("StatusBar", "TMbar1_2", self.bar1Container)
	self.bar1_2:SetFrameLevel(self.bar1Container:GetFrameLevel())
	self.bar1_2:SetPoint("TOPLEFT", 4, -4)
	self.bar1_2:SetPoint("BOTTOMRIGHT", -4, 4)
	self.bar1_2:SetMinMaxValues(0, 100)
	self.bar1_2:SetValue(75)
	self.bar1_2:SetStatusBarTexture("Interface\\AddOns\\ThreatMeter\\media\\bar2")
	self.bar1_2:GetStatusBarTexture():SetHorizTile(false)
	self.bar1_2:GetStatusBarTexture():SetVertTile(false)
	self.bar1_2:SetStatusBarColor(1, 1, 1)
	self.bar2Container = CreateFrame("Frame", "bar2Container", self.frame)
	self.bar2Container:SetSize(300, 32)
	self.bar2Container:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
	self.bar2Bg = self.bar2Container:CreateTexture("bar2Bg", "BACKGROUND")
	self.bar2Bg:SetAllPoints(self.bar2Container)
	self.bar2Bg:SetTexture("Interface\\AddOns\\ThreatMeter\\media\\bar-bg")
	self.bar2Bg:SetVertexColor(1, 1, 1, 1)
	self.bar2 = CreateFrame("StatusBar", "TMbar2", self.bar2Container)
	self.bar2:SetFrameLevel(self.bar2Container:GetFrameLevel())
	self.bar2:SetPoint("TOPLEFT", 4, -4)
	self.bar2:SetPoint("BOTTOMRIGHT", -4, 4)
	self.bar2:SetMinMaxValues(0, 100)
	self.bar2:SetValue(50)
	self.bar2:SetStatusBarTexture("Interface\\AddOns\\ThreatMeter\\media\\bar2")
	self.bar2:GetStatusBarTexture():SetHorizTile(false)
	self.bar2:GetStatusBarTexture():SetVertTile(false)
	self.bar2:SetStatusBarColor(1, 1, 1)
	self.bar2_2 = CreateFrame("StatusBar", "TMbar2_2", self.bar2Container)
	self.bar2_2:SetFrameLevel(self.bar2Container:GetFrameLevel())
	self.bar2_2:SetPoint("TOPLEFT", 4, -4)
	self.bar2_2:SetPoint("BOTTOMRIGHT", -4, 4)
	self.bar2_2:SetMinMaxValues(0, 100)
	self.bar2_2:SetValue(75)
	self.bar2_2:SetStatusBarTexture("Interface\\AddOns\\ThreatMeter\\media\\bar2")
	self.bar2_2:GetStatusBarTexture():SetHorizTile(false)
	self.bar2_2:GetStatusBarTexture():SetVertTile(false)
	self.bar2_2:SetStatusBarColor(1, 1, 1)
	self.text1Container = CreateFrame("Frame", "text1Container", self.frame)
	self.text1Container:SetSize(300, 32)
	self.text1Container:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
	self.text1Container:SetFrameLevel(self.bar1Container:GetFrameLevel() + 10)
	self.bar1Br = self.text1Container:CreateTexture("bar1Br", "BORDER")
	self.bar1Br:SetAllPoints(self.text1Container)
	self.bar1Br:SetTexture("Interface\\AddOns\\ThreatMeter\\media\\bar-border")
	self.text1 = self.text1Container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	self.text1:SetPoint("CENTER", 0, 0)
	self.text2Container = CreateFrame("Frame", "text2Container", self.frame)
	self.text2Container:SetSize(300, 32)
	self.text2Container:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
	self.text2Container:SetFrameLevel(self.bar2Container:GetFrameLevel() + 10)
	self.bar2Br = self.text2Container:CreateTexture("bar2Br", "BORDER")
	self.bar2Br:SetAllPoints(self.text2Container)
	self.bar2Br:SetTexture("Interface\\AddOns\\ThreatMeter\\media\\bar-border")
	self.text2 = self.text2Container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	self.text2:SetPoint("CENTER", 0, 0)
	self.lockText = CreateFrame("Button", "lockText", self.frame)
	self.lockText:SetText("")
	self.lockText:SetSize(40, 40)
	self.lockText:SetPoint("LEFT", self.frame, "RIGHT", 0, 0)
	self.lockText:SetScript(
		"OnClick",
		function()
			ThreatMeter:SV(TMTAB, "lockedText", true)
			ThreatMeter:ToggleText("lock", true)
		end
	)

	self.lockText.lock = self.lockText:CreateTexture("lockText.lock", "ARTWORK")
	self.lockText.lock:SetTexture("Interface\\Buttons\\LockButton-Locked-Up")
	self.lockText.lock:SetAllPoints(self.lockText)
	self.lockText.text1 = self.lockText:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	self.lockText.text1:SetPoint("LEFT", self.lockText, "RIGHT", 0, 0)
	self.lockText.text1:SetText(ThreatMeter:Trans("LID_ThreatMeterText"))
	C_Timer.After(
		0,
		function()
			ThreatMeter:SetFontSize(self.lockText.text1, 14, "OUTLINE")
			ThreatMeter:SetFontSize(self.text1, 24, "OUTLINE")
			ThreatMeter:SetFontSize(self.text2, 24, "OUTLINE")
		end
	)

	function ThreatMeter:UpdateLockButton()
		if ThreatMeter:GV(TMTAB, "lockedText", true) then
			self.lockText:Hide()
		else
			self.lockText:Show()
		end

		C_Timer.After(
			0.4,
			function()
				ThreatMeter:UpdateLockButton()
			end
		)
	end

	ThreatMeter:ToggleText("CreateMainFrame", false)
	ThreatMeter:UpdateLockButton()
	ThreatMeter:UpdateThreat()
end
