local _, ThreatMeter = ...
local TMDebug = false
function ThreatMeter:IsSecret(value)
	if type(_G.issecretvalue) == "function" then return _G.issecretvalue(value) end
	return false
end

function ThreatMeter:IsSafe(value)
	if ThreatMeter:IsSecret(value) then return false end
	return value ~= nil
end

function ThreatMeter:SafeUnitExists(unit)
	local ok, exists = pcall(UnitExists, unit)
	return ok and ThreatMeter:IsSafe(exists) and exists == true
end

function ThreatMeter:UnitGUID(unit, target)
	target = target or "player"
	if not ThreatMeter:SafeUnitExists(unit) then return nil end
	if UnitIsEnemy(target, unit) then return UnitGUID(unit) end
	return nil
end

function ThreatMeter:UnitThreat(unit, target)
	target = target or "player"
	if not ThreatMeter:SafeUnitExists(unit) then return nil end
	local ok, isTanking, status, scaled, _, rawThreat = pcall(UnitDetailedThreatSituation, target, unit)
	if not ok then return nil end
	if not ThreatMeter:IsSafe(rawThreat) or type(rawThreat) ~= "number" then rawThreat = nil end
	if ThreatMeter:IsSafe(scaled) and type(scaled) == "number" then return scaled, rawThreat end
	if ThreatMeter:IsSafe(isTanking) and isTanking == true then return 100, rawThreat end
	if not ThreatMeter:IsSafe(status) or type(status) ~= "number" then
		local statusOk, fallbackStatus = pcall(UnitThreatSituation, target, unit)
		if statusOk and ThreatMeter:IsSafe(fallbackStatus) and type(fallbackStatus) == "number" then
			status = fallbackStatus
		else
			status = nil
		end
	end
	if status == nil then return nil end
	if status >= 2 then return 100, rawThreat end
	if status == 1 then return 90, rawThreat end
	if status == 0 then return 25, rawThreat end
	return nil
end

function ThreatMeter:TestThreat(unit, highestTP, lowestTP, target, highestThreat)
	if not unit or not ThreatMeter:SafeUnitExists(unit) then return highestTP, lowestTP, highestThreat end
	target = target or "player"
	local threatPercentage, rawThreat = ThreatMeter:UnitThreat(unit, target)
	if threatPercentage then
		if threatPercentage > highestTP then
			highestTP = threatPercentage
			highestThreat = rawThreat
		elseif threatPercentage == highestTP and rawThreat ~= nil and (highestThreat == nil or rawThreat > highestThreat) then
			highestThreat = rawThreat
		end
		lowestTP = math.min(lowestTP, threatPercentage)
	end
	return highestTP, lowestTP, highestThreat
end

local otherUnitsParty = {"player", "pet"}
for i = 1, 4 do
	tinsert(otherUnitsParty, "party" .. i)
end

local otherUnitsRaid = {"player", "pet"}
for i = 1, 40 do
	tinsert(otherUnitsRaid, "raid" .. i)
end

local tabHighestTP = {}
local tabLowestTP = {}
local tabHighestThreat = {}
local function RGBToHex(r, g, b)
	return format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
end

local function FormatThreat(value)
	local absValue = math.abs(value)
	if absValue >= 1000000 then return format("%.1fm", value / 1000000) end
	if absValue >= 1000 then return format("%.1fk", value / 1000) end
	return tostring(math.floor(value + 0.5))
end

function ThreatMeter:UpdateBar(text, barContainer, barLow, barHigh, barBr, low, high, r, g, b, inCombat, show, threat)
	if TMTAB["DISPLAYBAR"] == nil then TMTAB["DISPLAYBAR"] = true end
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

			local threatText = threat ~= nil and " | " .. FormatThreat(threat) or ""
			if high <= 0 then
				text:SetText("|cffffff00" .. ThreatMeter:Trans("LID_INCOMBAT"))
			elseif high == 100 and low == 100 then
				text:SetText(format("%s%s%s", RGBToHex(r, g, b), ThreatMeter:Trans("LID_TANKING"), threatText))
			elseif low ~= high then
				text:SetText(format("%s%0.1f%% - %0.1f%%%s", RGBToHex(r, g, b), low, high, threatText))
			else
				text:SetText(format("%s%0.1f%%%s", RGBToHex(r, g, b), high, threatText))
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

function ThreatMeter:UpdateThreatLogic()
	local highestTP = 0
	local lowestTP = 100
	local highestThreat = nil
	local highestUnit = ""
	for i, nameplate in pairs(C_NamePlate.GetNamePlates()) do
		local unit = nameplate.unitToken
		if unit == nil and nameplate.UnitFrame then unit = nameplate.UnitFrame.unit end
		if unit ~= nil then highestTP, lowestTP, highestThreat = ThreatMeter:TestThreat(nameplate.unitToken or nameplate.UnitFrame.unit, highestTP, lowestTP, nil, highestThreat) end
	end

	for i = 1, 8 do
		highestTP, lowestTP, highestThreat = ThreatMeter:TestThreat("boss" .. i, highestTP, lowestTP, nil, highestThreat)
	end

	local inRaid = IsInRaid()
	if inRaid then
		for i = 1, GetNumGroupMembers() do
			highestTP, lowestTP, highestThreat = ThreatMeter:TestThreat("raid" .. i .. "target", highestTP, lowestTP, nil, highestThreat)
			highestTP, lowestTP, highestThreat = ThreatMeter:TestThreat("raidpet" .. i .. "target", highestTP, lowestTP, nil, highestThreat)
		end
	elseif IsInGroup() then
		for i = 1, 4 do
			highestTP, lowestTP, highestThreat = ThreatMeter:TestThreat("party" .. i .. "target", highestTP, lowestTP, nil, highestThreat)
			highestTP, lowestTP, highestThreat = ThreatMeter:TestThreat("partypet" .. i .. "target", highestTP, lowestTP, nil, highestThreat)
		end
	end

	highestTP, lowestTP, highestThreat = ThreatMeter:TestThreat("target", highestTP, lowestTP, nil, highestThreat)
	highestTP, lowestTP, highestThreat = ThreatMeter:TestThreat("targettarget", highestTP, lowestTP, nil, highestThreat)
	highestTP, lowestTP, highestThreat = ThreatMeter:TestThreat("pettarget", highestTP, lowestTP, nil, highestThreat)
	highestTP, lowestTP, highestThreat = ThreatMeter:TestThreat("focustarget", highestTP, lowestTP, nil, highestThreat)
	highestTP, lowestTP, highestThreat = ThreatMeter:TestThreat("mouseover", highestTP, lowestTP, nil, highestThreat)
	highestTP, lowestTP, highestThreat = ThreatMeter:TestThreat("mouseovertarget", highestTP, lowestTP, nil, highestThreat)
	if TMTAB["SHOWHIGHESTTHREAT"] then
		local otherUnits = inRaid and otherUnitsRaid or otherUnitsParty
		for x, unit in pairs(otherUnits) do
			tabHighestTP[unit] = 0
			tabLowestTP[unit] = 100
			tabHighestThreat[unit] = nil
			if ThreatMeter:SafeUnitExists(unit) then tabHighestTP[unit], tabLowestTP[unit], tabHighestThreat[unit] = ThreatMeter:TestThreat("target", tabHighestTP[unit], tabLowestTP[unit], unit) end
		end

		local highestUnitTP = 0
		for x, unit in pairs(otherUnits) do
			if ThreatMeter:SafeUnitExists(unit) and highestUnitTP < tabHighestTP[unit] then
				highestUnitTP = tabHighestTP[unit]
				highestUnit = unit
			end
		end
	end

	if TMTAB["SHOWTEXTOUTSIDEOFCOMBAT"] == nil then TMTAB["SHOWTEXTOUTSIDEOFCOMBAT"] = true end
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

		ThreatMeter:UpdateBar(self.text1, self.bar1Container, self.bar1, self.bar1_2, self.bar1Br, lowestTP, highestTP, r, g, b, true, true, highestThreat)
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

		ThreatMeter:UpdateBar(self.text2, self.bar2Container, self.bar2, self.bar2_2, self.bar2Br, tabLowestTP[highestUnit], tabHighestTP[highestUnit], r, g, b, true, TMTAB["SHOWHIGHESTTHREAT"] and ThreatMeter:SafeUnitExists(highestUnit), tabHighestThreat[highestUnit])
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
		if playerName then self.text1:SetText(playerName .. ": " .. self.text1:GetText()) end
		if unitName then self.text2:SetText(unitName .. ": " .. self.text2:GetText()) end
	else
		self.bar1Container:SetPoint("CENTER", 0, 0)
		self.text1Container:SetPoint("CENTER", 0, 0)
		self.bar2Container:SetPoint("CENTER", 0, 0)
		self.text2Container:SetPoint("CENTER", 0, 0)
	end
end

function ThreatMeter:StartThreatTicker()
	if self.ticker then self.ticker:Cancel() end
	self.ticker = C_Timer.NewTicker(0.3, function()
		local ok, err = pcall(ThreatMeter.UpdateThreatLogic, ThreatMeter)
		if not ok then ThreatMeter:ERR(err) end
	end)
end

function ThreatMeter:ToggleText(from, showMsg)
	if showMsg == nil then showMsg = false end
	if ThreatMeter:GV(TMTAB, "lockedText", true) then
		self.lockText:Hide()
		self.frame:SetMovable(false)
		self.frame:EnableMouse(false)
		if showMsg then ThreatMeter:MSG(ThreatMeter:Trans("LID_TEXTISNOWLOCKED")) end
	else
		self.lockText:Show()
		self.frame:SetMovable(true)
		self.frame:EnableMouse(true)
		if showMsg then ThreatMeter:MSG(ThreatMeter:Trans("LID_TEXTISNOWUNLOCKED")) end
	end
end

function ThreatMeter:CreateMainFrame()
	self.frame = CreateFrame("Frame", "TMFrame", UIParent)
	self.frame:SetSize(240, 80)
	self.frame:SetPoint("CENTER", 0, 200)
	ThreatMeter:SetClampedToScreen(self.frame, true)
	self.frame:RegisterForDrag("LeftButton")
	self.frame:SetScript("OnDragStart", function(sel)
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
	end)

	self.frame:SetScript("OnDragStop", function(sel)
		ThreatMeter:HideGrid(sel)
		self.frame:StopMovingOrSizing()
		local p1, _, p3, p4, p5 = self.frame:GetPoint()
		p4 = ThreatMeter:Grid(p4)
		p5 = ThreatMeter:Grid(p5)
		ThreatMeter:SV(TMTAB, "TMFrame", {p1, "UIParent", p3, p4, p5})
		ThreatMeter:MSG(ThreatMeter:Trans("LID_SAVEDNEWTEXTPOSITION"))
		self.frame:ClearAllPoints()
		self.frame:SetPoint(p1, "UIParent", p3, p4, p5)
	end)

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
	self.lockText:SetScript("OnClick", function()
		ThreatMeter:SV(TMTAB, "lockedText", true)
		ThreatMeter:ToggleText("lock", true)
	end)

	self.lockText.lock = self.lockText:CreateTexture("lockText.lock", "ARTWORK")
	self.lockText.lock:SetTexture("Interface\\Buttons\\LockButton-Locked-Up")
	self.lockText.lock:SetAllPoints(self.lockText)
	self.lockText.text1 = self.lockText:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	self.lockText.text1:SetPoint("LEFT", self.lockText, "RIGHT", 0, 0)
	self.lockText.text1:SetText(ThreatMeter:Trans("LID_ThreatMeterText"))
	C_Timer.After(0, function()
		ThreatMeter:SetFontSize(self.lockText.text1, 14, "OUTLINE")
		ThreatMeter:SetFontSize(self.text1, 24, "OUTLINE")
		ThreatMeter:SetFontSize(self.text2, 24, "OUTLINE")
	end)

	ThreatMeter:ToggleText("CreateMainFrame", false)
	C_Timer.After(3, function() ThreatMeter:StartThreatTicker() end)
	local ok, err = pcall(ThreatMeter.UpdateThreatLogic, ThreatMeter)
	if not ok then print(err) end
end
