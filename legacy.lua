local _, ThreatMeter = ...
local partyUnits = {"player", "pet"}
local raidUnits = {"player", "pet"}
local groupHighest = {}
local groupLowest = {}
local groupThreat = {}
for i = 1, 4 do
	partyUnits[#partyUnits + 1] = "party" .. i
end

for i = 1, 40 do
	raidUnits[#raidUnits + 1] = "raid" .. i
end

local function RGBToHex(r, g, b)
	return format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
end

local function FormatLegacyThreat(value)
	local absValue = math.abs(value)
	if absValue >= 1000000 then return format("%.1fm", value / 1000000) end
	if absValue >= 1000 then return format("%.1fk", value / 1000) end
	return tostring(math.floor(value + 0.5))
end

function ThreatMeter:GetLegacyUnitThreat(unit, observer)
	observer = observer or "player"
	if not self:SafeUnitExists(unit) or not self:SafeUnitExists(observer) then return nil end
	local ok, isTanking, status, scaled, _, rawThreat = pcall(UnitDetailedThreatSituation, observer, unit)
	if not ok then return nil end
	if not self:IsSafe(rawThreat) or type(rawThreat) ~= "number" then rawThreat = nil end
	if self:IsSafe(scaled) and type(scaled) == "number" then return scaled, rawThreat end
	if self:IsSafe(isTanking) and isTanking == true then return 100, rawThreat end
	if not self:IsSafe(status) or type(status) ~= "number" then
		local statusOk, fallbackStatus = pcall(UnitThreatSituation, observer, unit)
		if statusOk and self:IsSafe(fallbackStatus) and type(fallbackStatus) == "number" then
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

function ThreatMeter:TestLegacyThreat(unit, highest, lowest, observer, highestThreat)
	if not unit or not self:SafeUnitExists(unit) then return highest, lowest, highestThreat end
	local percent, rawThreat = self:GetLegacyUnitThreat(unit, observer)
	if percent then
		if percent > highest then
			highest = percent
			highestThreat = rawThreat
		elseif percent == highest and rawThreat ~= nil and (highestThreat == nil or rawThreat > highestThreat) then
			highestThreat = rawThreat
		end

		lowest = math.min(lowest, percent)
	end
	return highest, lowest, highestThreat
end

function ThreatMeter:UpdateLegacyBar(row, low, high, r, g, b, inCombat, show, threat)
	if not show then
		row:Hide()
		return
	end

	row:Show()
	if inCombat then
		row.bar:SetShown(TMTAB["LEGACYDISPLAYBAR"] ~= false)
		row.border:SetShown(TMTAB["LEGACYDISPLAYBAR"] ~= false)
		local difference = 0.3
		row.low:SetStatusBarColor(math.max(0, r - difference), math.max(0, g - difference), math.max(0, b - difference))
		row.high:SetStatusBarColor(math.min(1, r + difference), math.min(1, g + difference), math.min(1, b + difference))
		row.low:SetValue(low)
		row.high:SetValue(high)
		local threatText = threat ~= nil and " | " .. FormatLegacyThreat(threat) or ""
		if high <= 0 then
			row.text:SetText("|cffffff00" .. self:Trans("LID_INCOMBAT"))
		elseif high == 100 and low == 100 then
			row.text:SetText(RGBToHex(r, g, b) .. self:Trans("LID_TANKING") .. threatText)
		elseif low ~= high then
			row.text:SetText(format("%s%0.1f%% - %0.1f%%%s", RGBToHex(r, g, b), low, high, threatText))
		else
			row.text:SetText(format("%s%0.1f%%%s", RGBToHex(r, g, b), high, threatText))
		end
	else
		row.bar:Hide()
		row.border:Hide()
		row.text:SetText(RGBToHex(r, g, b) .. self:Trans("LID_NOTINCOMBAT"))
	end
end

local function GetThreatColor(value)
	if value >= 100 then return 1, 0, 0 end
	if value >= 67 then return 1, 1, 0 end
	return 0, 1, 0
end

function ThreatMeter:UpdateLegacyThreatLogic()
	if not self.legacyFrame then return end
	if TMTAB["SHOWLEGACYTHREAT"] ~= true then
		self.legacyFrame:Hide()
		return
	end

	local highest = 0
	local lowest = 100
	local highestThreat
	local highestUnit
	local nameplates = C_NamePlate and C_NamePlate.GetNamePlates and C_NamePlate.GetNamePlates() or {}
	for _, nameplate in pairs(nameplates) do
		local unit = nameplate.unitToken or nameplate.UnitFrame and nameplate.UnitFrame.unit
		highest, lowest, highestThreat = self:TestLegacyThreat(unit, highest, lowest, nil, highestThreat)
	end

	for i = 1, 8 do
		highest, lowest, highestThreat = self:TestLegacyThreat("boss" .. i, highest, lowest, nil, highestThreat)
	end

	local inRaid = IsInRaid()
	if inRaid then
		for i = 1, GetNumGroupMembers() do
			highest, lowest, highestThreat = self:TestLegacyThreat("raid" .. i .. "target", highest, lowest, nil, highestThreat)
			highest, lowest, highestThreat = self:TestLegacyThreat("raidpet" .. i .. "target", highest, lowest, nil, highestThreat)
		end
	elseif IsInGroup() then
		for i = 1, 4 do
			highest, lowest, highestThreat = self:TestLegacyThreat("party" .. i .. "target", highest, lowest, nil, highestThreat)
			highest, lowest, highestThreat = self:TestLegacyThreat("partypet" .. i .. "target", highest, lowest, nil, highestThreat)
		end
	end

	for _, unit in ipairs({"target", "targettarget", "pettarget", "focustarget", "mouseover", "mouseovertarget"}) do
		highest, lowest, highestThreat = self:TestLegacyThreat(unit, highest, lowest, nil, highestThreat)
	end

	if TMTAB["LEGACYSHOWHIGHESTTHREAT"] ~= false then
		local units = inRaid and raidUnits or partyUnits
		local highestUnitPercent = 0
		for _, unit in ipairs(units) do
			groupHighest[unit], groupLowest[unit], groupThreat[unit] = 0, 100, nil
			if self:SafeUnitExists(unit) then groupHighest[unit], groupLowest[unit], groupThreat[unit] = self:TestLegacyThreat("target", 0, 100, unit) end
			if groupHighest[unit] > highestUnitPercent then
				highestUnitPercent = groupHighest[unit]
				highestUnit = unit
			end
		end
	end

	local inCombat = self:SafeUnitInCombat("player") or highestUnit and self:SafeUnitInCombat(highestUnit)
	if not inCombat and TMTAB["LEGACYSHOWOUTSIDE"] == false then
		self.legacyFrame:Hide()
		return
	end

	self.legacyFrame:Show()
	if inCombat then
		local r, g, b = GetThreatColor(highest)
		self:UpdateLegacyBar(self.legacyRows[1], lowest, highest, r, g, b, true, true, highestThreat)
		local groupValue = highestUnit and groupHighest[highestUnit] or 0
		r, g, b = GetThreatColor(groupValue)
		self:UpdateLegacyBar(self.legacyRows[2], highestUnit and groupLowest[highestUnit] or 0, groupValue, r, g, b, true, highestUnit ~= nil and TMTAB["LEGACYSHOWHIGHESTTHREAT"] ~= false, highestUnit and groupThreat[highestUnit])
	else
		self:UpdateLegacyBar(self.legacyRows[1], 0, 0, 0, 1, 0, false, true)
		self:UpdateLegacyBar(self.legacyRows[2], 0, 0, 0, 1, 0, false, false)
	end

	if self.legacyRows[2]:IsShown() and (highestUnit == "player" or self.legacyRows[1].text:GetText() == self.legacyRows[2].text:GetText()) then self.legacyRows[2]:Hide() end
	local showSecond = self.legacyRows[2]:IsShown()
	self.legacyRows[1]:SetPoint("CENTER", self.legacyFrame, "CENTER", 0, showSecond and -16 or 0)
	self.legacyRows[2]:SetPoint("CENTER", self.legacyFrame, "CENTER", 0, 16)
	if showSecond and highestUnit then
		local playerOk, playerName = pcall(UnitName, "player")
		local unitOk, unitName = pcall(UnitName, highestUnit)
		if playerOk and self:IsSafe(playerName) and type(playerName) == "string" then self.legacyRows[1].text:SetText(playerName .. ": " .. self.legacyRows[1].text:GetText()) end
		if unitOk and self:IsSafe(unitName) and type(unitName) == "string" then self.legacyRows[2].text:SetText(unitName .. ": " .. self.legacyRows[2].text:GetText()) end
	end
end

function ThreatMeter:CreateLegacyRow(parent)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(300, 32)
	row.bar = CreateFrame("Frame", nil, row)
	row.bar:SetAllPoints()
	row.background = row.bar:CreateTexture(nil, "BACKGROUND")
	row.background:SetAllPoints()
	row.background:SetTexture("Interface\\AddOns\\ThreatMeter\\media\\bar-bg")
	row.low = CreateFrame("StatusBar", nil, row.bar)
	row.low:SetPoint("TOPLEFT", 4, -4)
	row.low:SetPoint("BOTTOMRIGHT", -4, 4)
	row.low:SetMinMaxValues(0, 100)
	row.low:SetStatusBarTexture("Interface\\AddOns\\ThreatMeter\\media\\bar2")
	row.high = CreateFrame("StatusBar", nil, row.bar)
	row.high:SetPoint("TOPLEFT", 4, -4)
	row.high:SetPoint("BOTTOMRIGHT", -4, 4)
	row.high:SetMinMaxValues(0, 100)
	row.high:SetStatusBarTexture("Interface\\AddOns\\ThreatMeter\\media\\bar2")
	row.low:GetStatusBarTexture():SetHorizTile(false)
	row.high:GetStatusBarTexture():SetHorizTile(false)
	row.overlay = CreateFrame("Frame", nil, row)
	row.overlay:SetAllPoints()
	row.overlay:SetFrameLevel(row.bar:GetFrameLevel() + 10)
	row.border = row.overlay:CreateTexture(nil, "BORDER")
	row.border:SetAllPoints()
	row.border:SetTexture("Interface\\AddOns\\ThreatMeter\\media\\bar-border")
	row.text = row.overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.text:SetPoint("CENTER")
	C_Timer.After(0, function() ThreatMeter:SetFontSize(row.text, 24, "OUTLINE") end)
	return row
end

function ThreatMeter:ApplyLegacyLock()
	if not self.legacyFrame then return end
	local locked = TMTAB["LEGACYLOCKED"] == true
	self.legacyFrame:SetMovable(not locked)
	self.legacyFrame:EnableMouse(not locked)
	if self.legacyLock then self.legacyLock:SetShown(not locked) end
end

function ThreatMeter:SetLegacyScale(value)
	if self.legacyFrame and type(value) == "number" then self.legacyFrame:SetScale(value) end
end

function ThreatMeter:CreateLegacyFrame()
	self.legacyFrame = CreateFrame("Frame", "TMLegacyFrame", UIParent)
	self.legacyFrame:SetSize(240, 80)
	self.legacyFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
	self.legacyFrame:SetClampedToScreen(true)
	self.legacyFrame:RegisterForDrag("LeftButton")
	self.legacyFrame:SetScript("OnDragStart", function(frame)
		if TMTAB["LEGACYLOCKED"] == true then return end
		if InCombatLockdown() then
			ThreatMeter:MSG(ThreatMeter:Trans("LID_CANTBEMOVEDINCOMBAT"))
			return
		end

		ThreatMeter:ShowGrid(frame)
		frame:StartMoving()
	end)

	self.legacyFrame:SetScript("OnDragStop", function(frame)
		ThreatMeter:HideGrid(frame)
		frame:StopMovingOrSizing()
		local point, _, relativePoint, x, y = frame:GetPoint()
		x = ThreatMeter:Grid(x)
		y = ThreatMeter:Grid(y)
		ThreatMeter:SV(TMTAB, "TMLegacyFrame", {point, "UIParent", relativePoint, x, y})
		frame:ClearAllPoints()
		frame:SetPoint(point, "UIParent", relativePoint, x, y)
	end)

	local point, relativeTo, relativePoint, x, y = unpack(ThreatMeter:GV(TMTAB, "TMLegacyFrame", {}))
	if point then
		self.legacyFrame:ClearAllPoints()
		self.legacyFrame:SetPoint(point, relativeTo, relativePoint, x, y)
	end

	self.legacyRows = {self:CreateLegacyRow(self.legacyFrame), self:CreateLegacyRow(self.legacyFrame)}
	self.legacyRows[1]:SetPoint("CENTER")
	self.legacyRows[2]:SetPoint("CENTER")
	self.legacyLock = CreateFrame("Button", nil, self.legacyFrame)
	self.legacyLock:SetSize(40, 40)
	self.legacyLock:SetPoint("LEFT", self.legacyFrame, "RIGHT", 30, 0)
	self.legacyLock:SetNormalTexture("Interface\\Buttons\\LockButton-Locked-Up")
	self.legacyLock:SetScript("OnClick", function()
		TMTAB["LEGACYLOCKED"] = true
		ThreatMeter:ApplyLegacyLock()
	end)

	self.legacyLock.text = self.legacyLock:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	self.legacyLock.text:SetPoint("LEFT", self.legacyLock, "RIGHT", 0, 0)
	self.legacyLock.text:SetText(ThreatMeter:Trans("LID_ThreatMeterText"))
	C_Timer.After(0, function() ThreatMeter:SetFontSize(self.legacyLock.text, 14, "OUTLINE") end)
	self:ApplyLegacyLock()
	self:SetLegacyScale(ThreatMeter:GV(TMTAB, "LEGACYSCALE", 1))
	self:UpdateLegacyThreatLogic()
end
