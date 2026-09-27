local _, ThreatMeter = ...
local TMDebug = false
local DEFAULT_BAR_HEIGHT = 25
local DEFAULT_BAR_SPACING = 4
local HEADER_HEIGHT = 32
local BOTTOM_PADDING = 6
local MIN_WIDTH = 200
local MIN_HEIGHT = 120
local MAX_WIDTH = 600
local MAX_HEIGHT = 400

function ThreatMeter:IsSafe(value)
	if ThreatMeter:IsSecret(value) then return false end
	return value ~= nil
end

function ThreatMeter:SetFontStringScale(fontString, value)
	if type(fontString.SetTextScale) == "function" then
		fontString:SetTextScale(value)
	elseif type(fontString.SetScale) == "function" then
		fontString:SetScale(value)
	end
end

function ThreatMeter:SafeUnitExists(unit)
	local ok, exists = pcall(UnitExists, unit)
	return ok and ThreatMeter:IsSafe(exists) and exists == true
end

function ThreatMeter:SafeUnitIsUnit(unitA, unitB)
	local ok, same = pcall(UnitIsUnit, unitA, unitB)
	return ok and ThreatMeter:IsSafe(same) and same == true
end

function ThreatMeter:SafeUnitInCombat(unit)
	local ok, inCombat = pcall(UnitAffectingCombat, unit)
	return ok and ThreatMeter:IsSafe(inCombat) and inCombat == true
end

function ThreatMeter:UnitGUID(unit, target)
	target = target or "player"
	if not ThreatMeter:SafeUnitExists(unit) then return nil end
	local enemyOk, isEnemy = pcall(UnitIsEnemy, target, unit)
	if not enemyOk or not ThreatMeter:IsSafe(isEnemy) or isEnemy ~= true then return nil end
	local guidOk, guid = pcall(UnitGUID, unit)
	if guidOk and ThreatMeter:IsSafe(guid) then return guid end
	return nil
end

local function Clamp(value, low, high)
	if value < low then return low end
	if value > high then return high end
	return value
end

local function GetBarHeight()
	return Clamp(ThreatMeter:GV(TMTAB, "DMBARHEIGHT", DEFAULT_BAR_HEIGHT), 15, 40)
end

local function GetBarSpacing()
	return Clamp(ThreatMeter:GV(TMTAB, "DMPADDING", DEFAULT_BAR_SPACING), 2, 10)
end

local function FormatThreat(value)
	local numbers = ThreatMeter:GV(TMTAB, "DMNUMBERS", 1)
	if numbers == 2 then
		local rounded = math.floor(value + 0.5)
		if type(BreakUpLargeNumbers) == "function" then return BreakUpLargeNumbers(rounded) end
		return tostring(rounded)
	end
	local pattern = numbers == 0 and "%.0f" or "%.1f"
	local absValue = math.abs(value)
	if absValue >= 1000000 then return format(pattern .. "m", value / 1000000) end
	if absValue >= 1000 then return format(pattern .. "k", value / 1000) end
	return tostring(math.floor(value + 0.5))
end

local function GetClassColor(classToken)
	local color = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
	if color then return color.r, color.g, color.b end
	return 0.25, 0.55, 0.85
end

local function TrySetAtlas(region, method, atlas, useAtlasSize)
	if not region or type(region[method]) ~= "function" then return false end
	return pcall(region[method], region, atlas, useAtlasSize)
end

local function PublicCall(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, value = pcall(fn, ...)
	if ok and not ThreatMeter:IsSecret(value) then return value end
	return nil
end

local function PublicNumber(value)
	if ThreatMeter:IsSecret(value) or type(value) ~= "number" then return nil end
	if value ~= value or value == math.huge or value == -math.huge then return nil end
	return value
end

local function PetOwnerToken(unit)
	if unit == "pet" then return "player" end
	local party = unit:match("^partypet(%d+)$")
	if party then return "party" .. party end
	local raid = unit:match("^raidpet(%d+)$")
	if raid then return "raid" .. raid end
	return nil
end

local function PlayerClass(unit)
	if not unit or PublicCall(UnitExists, unit) ~= true then return nil end
	local ok, _, classToken = pcall(UnitClass, unit)
	if ok and not ThreatMeter:IsSecret(classToken) and type(classToken) == "string" then return classToken end
	return nil
end

function ThreatMeter:GetThreatAppearance(unit, roster)
	local owner = PetOwnerToken(unit)
	if owner then return PlayerClass(owner), true end
	if unit == "player" or unit:match("^party%d+$") or unit:match("^raid%d+$") or PublicCall(UnitIsPlayer, unit) == true then return PlayerClass(unit), false end
	for _, token in ipairs(roster or {}) do
		owner = PetOwnerToken(token)
		if owner and PublicCall(UnitIsUnit, unit, token) == true then return PlayerClass(owner), true end
	end
	if PublicCall(UnitIsPlayer, unit) == false and PublicCall(UnitPlayerControlled, unit) == true then return nil, true end
	return nil, false
end

function ThreatMeter:ResolveThreatSource(unit)
	if PublicCall(UnitExists, unit) ~= true then return nil end
	if PublicCall(UnitCanAttack, "player", unit) == true then return unit end
	local nextTarget = unit .. "target"
	if PublicCall(UnitCanAssist, "player", unit) == true and PublicCall(UnitExists, nextTarget) == true and PublicCall(UnitCanAttack, "player", nextTarget) == true then return nextTarget end
	return nil
end

local function AddGroupUnit(result, pets, token, pet)
	if PublicCall(UnitExists, token) == true then result[#result + 1] = token end
	if pets and PublicCall(UnitExists, pet) == true then result[#result + 1] = pet end
end

function ThreatMeter:GetThreatGroupTokens(pets, result)
	result = result or {}
	for i = #result, 1, -1 do result[i] = nil end
	if IsInRaid() then
		for i = 1, GetNumGroupMembers() do AddGroupUnit(result, pets, "raid" .. i, "raidpet" .. i) end
	else
		AddGroupUnit(result, pets, "player", "pet")
		for i = 1, GetNumSubgroupMembers() do AddGroupUnit(result, pets, "party" .. i, "partypet" .. i) end
	end
	return result
end

local function AddThreatCandidate(result, pets, token)
	if not token or PublicCall(UnitExists, token) ~= true then return end
	local isPlayer = PublicCall(UnitIsPlayer, token)
	if isPlayer == nil then return end
	if not isPlayer and (not pets or PublicCall(UnitPlayerControlled, token) ~= true) then return end
	if PublicCall(UnitPlayerOrPetInRaid, token) == true or PublicCall(UnitPlayerOrPetInParty, token) == true then return end
	for _, existing in ipairs(result) do
		if existing == token then return end
		local same = PublicCall(UnitIsUnit, existing, token)
		if same == nil or same then return end
	end
	result[#result + 1] = token
end

function ThreatMeter:GetThreatTokens(pets, source)
	local result = self:GetThreatGroupTokens(pets, self.threatTokens)
	self.threatTokens = result
	AddThreatCandidate(result, pets, source .. "target")
	AddThreatCandidate(result, pets, "mouseover")
	if C_NamePlate and type(C_NamePlate.GetNamePlates) == "function" then
		local candidates = self.threatCandidates or {}
		self.threatCandidates = candidates
		for i = #candidates, 1, -1 do candidates[i] = nil end
		local ok, plates = pcall(C_NamePlate.GetNamePlates)
		if ok and type(plates) == "table" then
			for _, plate in ipairs(plates) do
				local token = plate.namePlateUnitToken
				if type(token) == "string" and not self:IsSecret(token) then candidates[#candidates + 1] = token end
			end
		end
		table.sort(candidates)
		for _, token in ipairs(candidates) do
			AddThreatCandidate(result, pets, token)
			AddThreatCandidate(result, pets, token .. "target")
		end
	end
	return result
end

local function CompareThreat(a, b)
	if a.priority ~= b.priority then return a.priority > b.priority end
	if a.sortTier ~= b.sortTier then return a.sortTier > b.sortTier end
	if a.sortValue ~= b.sortValue then return a.sortValue > b.sortValue end
	return a.order < b.order
end

function ThreatMeter:ReadThreat(tokens, source)
	local rows = self.threatRows or {}
	local pool = self.threatPool or {}
	self.threatRows, self.threatPool = rows, pool
	for i = #rows, 1, -1 do rows[i] = nil end
	local allRaw, allRelative, allScaled = true, true, true
	for _, token in ipairs(tokens) do
		local ok, tank, status, scaled, relative, raw = pcall(UnitDetailedThreatSituation, token, source)
		if not ok then tank, status, scaled, relative, raw = nil, nil, nil, nil, nil end
		local publicStatus = PublicNumber(status)
		if not publicStatus then publicStatus = PublicNumber(PublicCall(UnitThreatSituation, token, source)) end
		local victim = PublicCall(UnitIsUnit, token, source .. "target") == true
		local tanking = not self:IsSecret(tank) and tank == true
		local priority = victim and 3 or (tanking and 2 or (publicStatus and publicStatus >= 2 and 1 or 0))
		local hasPercent = type(scaled) == "number" or type(relative) == "number"
		local hasData = hasPercent or type(raw) == "number" or publicStatus ~= nil
		if hasData or priority > 0 then
			local slot = #rows + 1
			local row = pool[slot] or {}
			pool[slot] = row
			for key in pairs(row) do row[key] = nil end
			row.unit, row.publicStatus = token, publicStatus
			row.percent, row.relative, row.threat = scaled, relative, raw
			row.order, row.priority, row.holdsAggro = slot, priority, priority > 0
			row.aggroOnly = not hasPercent and type(raw) ~= "number" and priority > 0
			row.rawKey, row.relativeKey, row.scaledKey = PublicNumber(raw), PublicNumber(relative), PublicNumber(scaled)
			if not row.aggroOnly then
				allRaw = allRaw and row.rawKey ~= nil
				allRelative = allRelative and row.relativeKey ~= nil
				allScaled = allScaled and row.scaledKey ~= nil
			end
			if row.holdsAggro then
				row.displayPercent = 100
			elseif type(relative) == "number" then
				row.displayPercent = relative
			elseif type(scaled) == "number" then
				row.displayPercent = scaled
				row.pullPercent = true
			end
			rows[#rows + 1] = row
		end
	end
	for i = #rows + 1, #pool do
		for key in pairs(pool[i]) do pool[i][key] = nil end
	end
	local metric = allRaw and "rawKey" or (allRelative and "relativeKey" or (allScaled and "scaledKey" or nil))
	for _, row in ipairs(rows) do
		if metric then
			row.sortTier, row.sortValue = 1, row[metric] or 0
		elseif row.rawKey ~= nil then
			row.sortTier, row.sortValue = 3, row.rawKey
		elseif row.relativeKey ~= nil then
			row.sortTier, row.sortValue = 2, row.relativeKey
		elseif row.scaledKey ~= nil then
			row.sortTier, row.sortValue = 1, row.scaledKey
		else
			row.sortTier, row.sortValue = 0, row.publicStatus or -1
		end
	end
	table.sort(rows, CompareThreat)
	local baseline = rows[1] and rows[1].holdsAggro and rows[1].rawKey
	if baseline and baseline > 0 then
		for _, row in ipairs(rows) do
			if type(row.displayPercent) ~= "number" and row.rawKey and row.rawKey >= 0 then
				row.displayPercent = PublicNumber(row.rawKey / baseline * 100)
			end
		end
	end
	return rows
end

function ThreatMeter:GetPullEntry(me)
	if not me or me.holdsAggro then return nil end
	local raw, scaled = PublicNumber(me.rawKey), PublicNumber(me.scaledKey)
	if not raw or not scaled or raw <= 0 or scaled <= 0 then return nil end
	local threshold = PublicNumber(raw * 100 / scaled)
	if not threshold then return nil end
	local entry = self.pullEntry or {}
	self.pullEntry = entry
	for key in pairs(entry) do entry[key] = nil end
	entry.pull = true
	entry.name = ThreatMeter:Trans("LID_PULLAGGRO")
	entry.threat, entry.rawKey = threshold, threshold
	entry.displayPercent, entry.percent, entry.scaledKey, entry.pullPercent = 100, 100, 100, true
	return entry
end

function ThreatMeter:GetThreatData()
	if type(UnitDetailedThreatSituation) ~= "function" then return {} end
	local source = self:ResolveThreatSource("target")
	if not source then return {} end
	local pets = ThreatMeter:GV(TMTAB, "DMPETS", false) == true
	local data = self:ReadThreat(self:GetThreatTokens(pets, source), source)
	local me
	for _, entry in ipairs(data) do
		local ok, name = pcall(UnitName, entry.unit)
		if not ok or not self:IsSecret(name) and type(name) ~= "string" then name = _G.UNKNOWNOBJECT or entry.unit end
		entry.name = name
		entry.classToken, entry.isPet = self:GetThreatAppearance(entry.unit, self.threatTokens)
		entry.isPlayer = PublicCall(UnitIsUnit, entry.unit, "player") == true
		if entry.isPlayer and not me then me = entry end
	end
	if ThreatMeter:GV(TMTAB, "DMPULLBAR", false) == true then
		local pull = self:GetPullEntry(me)
		if pull then data[#data + 1] = pull end
	end
	return data
end

local function SetClassIcon(texture, classToken)
	if type(GetClassAtlas) == "function" and classToken then
		local ok, atlas = pcall(GetClassAtlas, classToken)
		if ok and atlas and TrySetAtlas(texture, "SetAtlas", atlas) then
			texture:SetTexCoord(0.0625, 0.9, 0.0626, 0.9)
			return true
		end
	end
	local coords = classToken and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classToken]
	if coords then
		texture:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
		texture:SetTexCoord(coords[1] + 0.006, coords[2] - 0.006, coords[3] + 0.006, coords[4] - 0.006)
		return true
	end
	texture:SetTexture(nil)
	return false
end

function ThreatMeter:CreateThreatRow(index)
	local row = CreateFrame("Button", nil, self.frame)
	row:SetHeight(GetBarHeight())
	row.iconFrame = CreateFrame("Frame", nil, row)
	row.iconFrame:SetSize(24, 24)
	row.iconFrame:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.icon = row.iconFrame:CreateTexture(nil, "ARTWORK")
	row.icon:SetAllPoints()
	row.bar = CreateFrame("StatusBar", nil, row)
	row.bar:SetPoint("LEFT", row.iconFrame, "RIGHT", 0, 0)
	row.bar:SetPoint("TOP", row, "TOP", 0, -1)
	row.bar:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -4, 1)
	row.bar:SetMinMaxValues(0, 100)
	row.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	local barTexture = row.bar:GetStatusBarTexture()
	if barTexture then TrySetAtlas(barTexture, "SetAtlas", "UI-HUD-CoolDownManager-Bar") end
	row.bg = row.bar:CreateTexture(nil, "BACKGROUND")
	row.bg:SetPoint("TOPLEFT", row.bar, "TOPLEFT", -2, 2)
	row.bg:SetPoint("BOTTOMRIGHT", row.bar, "BOTTOMRIGHT", 2, -2)
	if not TrySetAtlas(row.bg, "SetAtlas", "ui-damagemeters-bar-shadowbg") then
		row.bg:SetColorTexture(0.035, 0.035, 0.035, 0.9)
	end
	row.edge = row.bar:CreateTexture(nil, "OVERLAY")
	row.edge:SetPoint("TOPLEFT", row.bar, "TOPLEFT", -2, 2)
	row.edge:SetPoint("BOTTOMRIGHT", row.bar, "BOTTOMRIGHT", 2, -2)
	if not TrySetAtlas(row.edge, "SetAtlas", "ui-damagemeters-bar-shadowedge") then
		row.edge:SetColorTexture(0.3, 0.3, 0.3, 0.35)
	end
	row.name = row.bar:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	row.name:SetPoint("LEFT", row.bar, "LEFT", 2, 0)
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)
	row.value = row.bar:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	row.value:SetPoint("RIGHT", row.bar, "RIGHT", -3, 0)
	row.value:SetJustifyH("LEFT")
	row.name:SetPoint("RIGHT", row.value, "LEFT", -25, 0)
	row.index = index
	self.rows[index] = row
	if self.textScale then
		self:SetFontStringScale(row.name, self.textScale)
		self:SetFontStringScale(row.value, self.textScale)
	end
	return row
end

function ThreatMeter:ApplyThreatRowStyle(row)
	local style = ThreatMeter:GV(TMTAB, "DMSTYLE", 0)
	local showIcon = ThreatMeter:GV(TMTAB, "DMSHOWSPECICON", true)
	row.iconFrame:SetShown(showIcon and row.hasIcon == true)
	row.bar:ClearAllPoints()
	if showIcon and row.hasIcon == true then
		row.bar:SetPoint("LEFT", row.iconFrame, "RIGHT", 0, 0)
	else
		row.bar:SetPoint("LEFT", row, "LEFT", 0, 0)
	end
	row.name:ClearAllPoints()
	row.value:ClearAllPoints()
	if style == 2 then
		row.bar:SetPoint("TOP", row, "TOP", 0, -math.floor(GetBarHeight() * 0.55))
		row.bar:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -4, 1)
		row.name:SetPoint("TOPLEFT", row.bar, "TOPLEFT", 2, GetBarHeight() * 0.55 - 1)
		row.value:SetPoint("TOPRIGHT", row.bar, "TOPRIGHT", -3, GetBarHeight() * 0.55 - 1)
	else
		row.bar:SetPoint("TOP", row, "TOP", 0, -1)
		row.bar:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -4, 1)
		row.name:SetPoint("LEFT", row.bar, "LEFT", 2, 0)
		row.value:SetPoint("RIGHT", row.bar, "RIGHT", -3, 0)
	end
	row.name:SetPoint("RIGHT", row.value, "LEFT", -25, 0)
	if style == 1 and TrySetAtlas(row.bg, "SetAtlas", "UI-HUD-CoolDownManager-Bar-BG") then
		row.edge:Hide()
	else
		TrySetAtlas(row.bg, "SetAtlas", "ui-damagemeters-bar-shadowbg")
		row.edge:Show()
	end
end

function ThreatMeter:EnsureThreatRows(count)
	for i = #self.rows + 1, count do self:CreateThreatRow(i) end
end

function ThreatMeter:RefreshThreatLayout()
	if not self.frame or not self.rows then return end
	if TMTAB["DAMAGEMETERCOLLAPSED"] == true then
		for _, row in ipairs(self.rows) do row:Hide() end
		return
	end
	local height = self.frame:GetHeight() or MIN_HEIGHT
	local barHeight = GetBarHeight()
	local barSpacing = GetBarSpacing()
	local rowStep = barHeight + barSpacing
	self.visibleRowCount = math.max(1, math.floor((height - HEADER_HEIGHT - BOTTOM_PADDING + barSpacing) / rowStep))
	for i, row in ipairs(self.rows) do
		row:SetHeight(barHeight)
		self:ApplyThreatRowStyle(row)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 5, -HEADER_HEIGHT - 2 - ((i - 1) * rowStep))
		row:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -1, -HEADER_HEIGHT - 2 - ((i - 1) * rowStep))
		if i <= self.visibleRowCount and i <= #(self.currentThreatData or {}) then row:Show() else row:Hide() end
	end
end

local function SetRowIcon(texture, entry)
	if entry.pull then
		texture:SetTexture(nil)
		return false
	end
	if entry.isPet then
		texture:SetTexture(132161)
		texture:SetTexCoord(0.06, 0.94, 0.06, 0.94)
		return true
	end
	return SetClassIcon(texture, entry.classToken)
end

local function SetBarValue(bar, value)
	if TMTAB["DISPLAYBAR"] == false or type(value) ~= "number" or not pcall(bar.SetValue, bar, value) then bar:SetValue(0) end
end

function ThreatMeter:SetThreatRowValue(row, entry)
	local mode = ThreatMeter:GV(TMTAB, "DMDISPLAYVALUE", "value_relative")
	local showValue = mode == "value" or mode == "value_relative" or mode == "value_pull"
	local showPercent = mode == "relative" or mode == "pull" or mode == "value_relative" or mode == "value_pull"
	local value = entry.displayPercent
	local percent = value
	if mode == "pull" or mode == "value_pull" then
		percent = entry.percent
	elseif entry.pullPercent then
		percent = nil
	end
	if entry.pull then value, percent = 100, 100 end
	if entry.aggroOnly then
		SetBarValue(row.bar, 100)
		row.value:SetText((showValue or showPercent) and ThreatMeter:Trans("LID_TANKING") or "")
		return
	end
	SetBarValue(row.bar, value)
	local raw
	if showValue then raw = entry.threat end
	local rawFormat, rawText
	if type(raw) == "number" then
		if self:IsSecret(raw) then
			rawFormat, rawText = "%.0f", raw
		elseif PublicNumber(raw) then
			rawFormat, rawText = "%s", FormatThreat(raw)
		end
	end
	if not showPercent or entry.pull and rawFormat then percent = nil end
	local ok = true
	if rawFormat and type(percent) == "number" then
		ok = pcall(row.value.SetFormattedText, row.value, rawFormat .. " (%.0f%%)", rawText, percent)
	elseif rawFormat then
		ok = pcall(row.value.SetFormattedText, row.value, rawFormat, rawText)
	elseif type(percent) == "number" then
		ok = pcall(row.value.SetFormattedText, row.value, "%.0f%%", percent)
	else
		row.value:SetText((showValue or showPercent) and "?" or "")
	end
	if not ok then row.value:SetText("?") end
end

function ThreatMeter:UpdateThreatRows(data)
	self.currentThreatData = data
	self:EnsureThreatRows(math.min(#data, 40))
	self:RefreshThreatLayout()
	for i, row in ipairs(self.rows) do
		local entry = data[i]
		if entry and i <= self.visibleRowCount then
			local r, g, b = 0.18, 0.55, 0.78
			if entry.pull then
				r, g, b = 0, 0.55, 0
			elseif ThreatMeter:GV(TMTAB, "DMSHOWCLASSCOLOR", true) then
				r, g, b = GetClassColor(entry.classToken)
			end
			row.bar:SetStatusBarColor(r, g, b, 0.9)
			if not pcall(row.name.SetFormattedText, row.name, "%d. %s", i, entry.name) then row.name:SetText(i .. ". ?") end
			row.name:SetTextColor(1, 1, 1)
			self:SetThreatRowValue(row, entry)
			row.hasIcon = SetRowIcon(row.icon, entry)
			self:ApplyThreatRowStyle(row)
		end
	end
end

function ThreatMeter:UpdateThreatLogic()
	if not self.frame then return end
	if self.editModeActive then
		self.frame:Show()
		self:UpdateThreatRows({
			{name = "Player", classToken = "WARRIOR", isPlayer = true, holdsAggro = true, percent = 100, relative = 100, threat = 17521, displayPercent = 100},
			{name = "Threat", classToken = "MAGE", isPlayer = false, holdsAggro = false, percent = 69, relative = 76, threat = 13280, displayPercent = 76}
		})
		return
	end
	if TMTAB["SHOWDAMAGEMETERTHREAT"] == false then
		self.frame:Hide()
		return
	end
	local visibility = ThreatMeter:GV(TMTAB, "DMVISIBILITY", 0)
	if visibility == 2 or visibility == 1 and not ThreatMeter:SafeUnitInCombat("player") or visibility == 3 and not IsInGroup() then
		self.frame:Hide()
		return
	end
	if TMTAB["SHOWTEXTOUTSIDEOFCOMBAT"] == nil then TMTAB["SHOWTEXTOUTSIDEOFCOMBAT"] = true end
	local inCombat = ThreatMeter:SafeUnitInCombat("player")
	if visibility == nil and not inCombat and not TMTAB["SHOWTEXTOUTSIDEOFCOMBAT"] then
		self.frame:Hide()
		return
	end
	self.frame:Show()
	local data = ThreatMeter:GetThreatData()
	if TMDebug then
		data = {
			{name = "Tank", classToken = "WARRIOR", isPlayer = false, holdsAggro = true, percent = 100, relative = 100, threat = 12500, displayPercent = 100},
			{name = "Player", classToken = "MAGE", isPlayer = true, holdsAggro = false, percent = 75, relative = 82, threat = 10250, displayPercent = 82}
		}
	end
	ThreatMeter:UpdateThreatRows(data)
end

function ThreatMeter:StartThreatTicker()
	if self.ticker then self.ticker:Cancel() end
	self.ticker = C_Timer.NewTicker(0.3, function()
		local ok, err = pcall(ThreatMeter.UpdateThreatLogic, ThreatMeter)
		if not ok then ThreatMeter:ERR(err) end
		if ThreatMeter.UpdateLegacyThreatLogic then
			ok, err = pcall(ThreatMeter.UpdateLegacyThreatLogic, ThreatMeter)
			if not ok then ThreatMeter:ERR(err) end
		end
	end)
end

function ThreatMeter:SaveThreatWindowPosition()
	if not self.frame then return end
	local point, _, relativePoint, x, y = self.frame:GetPoint()
	ThreatMeter:SV(TMTAB, "TMFrame", {point, "UIParent", relativePoint, x, y})
end

function ThreatMeter:SaveThreatWindowSize()
	if not self.frame then return end
	ThreatMeter:SV(TMTAB, "TMFrameWidth", math.floor(self.frame:GetWidth() + 0.5))
	ThreatMeter:SV(TMTAB, "TMFrameHeight", math.floor(self.frame:GetHeight() + 0.5))
end

function ThreatMeter:ToggleText(from, showMsg)
	if showMsg == nil then showMsg = false end
	if not self.frame then return end
	local locked = ThreatMeter:GV(TMTAB, "lockedText", true)
	self.frame:SetMovable(not locked)
	self.frame:SetResizable(not locked and TMTAB["DAMAGEMETERCOLLAPSED"] ~= true)
	self.frame:EnableMouse(true)
	if self.resizeGrip then
		local enabled = ThreatMeter.editModeActive == true and TMTAB["DAMAGEMETERCOLLAPSED"] ~= true
		self.resizeGrip:SetAlpha(enabled and 1 or 0)
		self.resizeGrip:EnableMouse(enabled)
	end
	if self.lockButton then
		self.lockButton:SetNormalTexture(locked and "Interface\\Buttons\\LockButton-Locked-Up" or "Interface\\Buttons\\LockButton-Unlocked-Up")
	end
	if showMsg then ThreatMeter:MSG(ThreatMeter:Trans(locked and "LID_TEXTISNOWLOCKED" or "LID_TEXTISNOWUNLOCKED")) end
end

function ThreatMeter:ApplyDamageMeterCollapsed()
	if not self.frame then return end
	local collapsed = TMTAB["DAMAGEMETERCOLLAPSED"] == true
	if collapsed then
		TMTAB["DAMAGEEXPANDEDHEIGHT"] = nil
		self.frame:SetHeight(HEADER_HEIGHT)
		self.background:Hide()
		for _, row in ipairs(self.rows) do row:Hide() end
	else
		self.frame:SetHeight(math.max(MIN_HEIGHT, ThreatMeter:GV(TMTAB, "TMFrameHeight", 200)))
		self.background:Show()
		self:RefreshThreatLayout()
	end
	self.frame:SetResizable(not collapsed and not ThreatMeter:GV(TMTAB, "lockedText", true))
	local resizeEnabled = not collapsed and ThreatMeter.editModeActive == true
	self.resizeGrip:SetAlpha(resizeEnabled and 1 or 0)
	self.resizeGrip:EnableMouse(resizeEnabled)
	self:UpdateDamageMeterMinimizeButton()
end

function ThreatMeter:ToggleDamageMeterCollapsed()
	ThreatMeter:SV(TMTAB, "DAMAGEMETERCOLLAPSED", TMTAB["DAMAGEMETERCOLLAPSED"] ~= true)
	self:ApplyDamageMeterCollapsed()
end

function ThreatMeter:ResetDamageMeterData()
	self.currentThreatData = {}
	for _, row in ipairs(self.rows or {}) do row:Hide() end
end

function ThreatMeter:EnterDamageMeterEditMode()
	if self.OpenDamageMeterEditMode then self:OpenDamageMeterEditMode() end
end

local function SetButtonAtlas(button, atlas, fallback)
	if not TrySetAtlas(button, "SetNormalAtlas", atlas, true) then
		button:SetNormalTexture(fallback)
	end
end

function ThreatMeter:UpdateDamageMeterMinimizeButton()
	if not self.minimizeButton then return end
	local collapsed = TMTAB["DAMAGEMETERCOLLAPSED"] == true
	local normalAtlas = collapsed and "ui-questtrackerbutton-expand-all" or "ui-questtrackerbutton-collapse-all"
	local pushedAtlas = collapsed and "ui-questtrackerbutton-expand-all-pressed" or "ui-questtrackerbutton-collapse-all-pressed"
	local normalFallback = collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up"
	local pushedFallback = collapsed and "Interface\\Buttons\\UI-PlusButton-Down" or "Interface\\Buttons\\UI-MinusButton-Down"
	SetButtonAtlas(self.minimizeButton, normalAtlas, normalFallback)
	if not TrySetAtlas(self.minimizeButton, "SetPushedAtlas", pushedAtlas, true) then
		self.minimizeButton:SetPushedTexture(pushedFallback)
	end
end

function ThreatMeter:CreateDamageMeterMenuButton(textKey, onClick, index)
	local button = CreateFrame("Button", nil, self.damageMeterMenu)
	button:SetPoint("TOPLEFT", self.damageMeterMenu, "TOPLEFT", 8, -7 - ((index - 1) * 24))
	button:SetPoint("TOPRIGHT", self.damageMeterMenu, "TOPRIGHT", -8, -7 - ((index - 1) * 24))
	button:SetHeight(24)
	button.highlight = button:CreateTexture(nil, "BACKGROUND")
	button.highlight:SetAllPoints()
	button.highlight:SetColorTexture(1, 0.82, 0, 0.15)
	button.highlight:Hide()
	button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	button.text:SetPoint("LEFT", button, "LEFT", 4, 0)
	button.text:SetJustifyH("LEFT")
	button.text:SetText(self:Trans(textKey))
	button.text:SetTextColor(1, 1, 1)
	button:SetScript("OnEnter", function(menuButton) menuButton.highlight:Show() end)
	button:SetScript("OnLeave", function(menuButton) menuButton.highlight:Hide() end)
	button:SetScript("OnClick", function()
		ThreatMeter.damageMeterMenu:Hide()
		onClick()
	end)
	return button
end

function ThreatMeter:CreateDamageMeterMenu()
	local template = BackdropTemplateMixin and "BackdropTemplate" or nil
	self.damageMeterMenu = CreateFrame("Frame", "ThreatMeterDamageMeterMenu", UIParent, template)
	self.damageMeterMenu:SetSize(170, 86)
	self.damageMeterMenu:SetFrameStrata("DIALOG")
	self.damageMeterMenu:SetPoint("TOPRIGHT", self.settingsButton, "BOTTOMRIGHT", 4, -4)
	if self.damageMeterMenu.SetBackdrop then
		self.damageMeterMenu:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = {left = 3, right = 3, top = 3, bottom = 3}})
		self.damageMeterMenu:SetBackdropColor(0.02, 0.02, 0.02, 0.98)
		self.damageMeterMenu:SetBackdropBorderColor(0.78, 0.55, 0.08, 1)
	end
	self:CreateDamageMeterMenuButton("LID_MENU_SETTINGS", function() ThreatMeter:ToggleSettings() end, 1)
	self:CreateDamageMeterMenuButton("LID_MENU_EDITMODE", function() ThreatMeter:EnterDamageMeterEditMode() end, 2)
	self:CreateDamageMeterMenuButton("LID_MENU_RESETDATA", function() ThreatMeter:ResetDamageMeterData() end, 3)
	self.damageMeterMenu:Hide()
	if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = "ThreatMeterDamageMeterMenu" end
end

function ThreatMeter:ToggleDamageMeterMenu()
	if MenuUtil and type(MenuUtil.CreateContextMenu) == "function" then
		MenuUtil.CreateContextMenu(self.settingsButton, function(_, rootDescription)
			rootDescription:CreateButton(ThreatMeter:Trans("LID_MENU_SETTINGS"), function() ThreatMeter:ToggleSettings() end)
			rootDescription:CreateButton(ThreatMeter:Trans("LID_MENU_EDITMODE"), function() ThreatMeter:EnterDamageMeterEditMode() end)
			if type(rootDescription.CreateSpacer) == "function" then rootDescription:CreateSpacer() end
			rootDescription:CreateButton(ThreatMeter:Trans("LID_MENU_RESETDATA"), function() ThreatMeter:ResetDamageMeterData() end)
		end)
		return
	end
	if self.damageMeterMenu then self.damageMeterMenu:SetShown(not self.damageMeterMenu:IsShown()) end
end

function ThreatMeter:CreateMainFrame()
	local template = BackdropTemplateMixin and "BackdropTemplate" or nil
	self.frame = CreateFrame("Frame", "TMFrame", UIParent, template)
	self.frame:SetSize(ThreatMeter:GV(TMTAB, "TMFrameWidth", 400), ThreatMeter:GV(TMTAB, "TMFrameHeight", 200))
	self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
	self.frame:SetClampedToScreen(true)
	self.frame:SetFrameStrata("MEDIUM")
	self.frame:SetMovable(true)
	self.frame:SetResizable(true)
	self.frame:RegisterForDrag("LeftButton")
	if self.frame.SetResizeBounds then
		self.frame:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, MAX_HEIGHT)
	else
		self.frame:SetMinResize(MIN_WIDTH, MIN_HEIGHT)
		self.frame:SetMaxResize(MAX_WIDTH, MAX_HEIGHT)
	end
	self.background = self.frame:CreateTexture(nil, "BACKGROUND")
	self.background:SetAllPoints()
	if TrySetAtlas(self.background, "SetAtlas", "damagemeters-background") then
		self.background:SetAlpha(ThreatMeter:GV(TMTAB, "DAMAGEBACKGROUNDALPHA", 50) / 100)
	else
		self.background:ClearAllPoints()
		self.background:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 3, -3)
		self.background:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -3, 3)
		self.background:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background-Dark")
		self.background:SetVertexColor(0.34, 0.34, 0.34, 0.96)
		if self.frame.SetBackdrop then
			self.frame:SetBackdrop({edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12})
			self.frame:SetBackdropBorderColor(0.22, 0.22, 0.22, 1)
		end
	end
	self.header = CreateFrame("Frame", nil, self.frame)
	self.header:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
	self.header:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, 0)
	self.header:SetHeight(HEADER_HEIGHT)
	self.header.bg = self.header:CreateTexture(nil, "BACKGROUND")
	self.header.bg:SetAllPoints()
	if not TrySetAtlas(self.header.bg, "SetAtlas", "ui-damagemeters-header-bar") then
		self.header.bg:SetColorTexture(0.055, 0.055, 0.055, 0.98)
	end
	local dropdownOk, staticType = pcall(CreateFrame, "DropdownButton", nil, self.header, "WowStyle1ArrowDropdownTemplate")
	if dropdownOk and staticType then
		self.staticType = staticType
		self.staticType:SetPoint("TOPLEFT", self.header, "TOPLEFT", 1, -3)
		self.staticType:EnableMouse(false)
	end
	self.header.title = self.header:CreateFontString(nil, "OVERLAY", "GameFontNormalMed1")
	if self.staticType and self.staticType.Arrow then
		self.header.title:SetPoint("LEFT", self.staticType.Arrow, "RIGHT", 0, 3)
	else
		self.header.title:SetPoint("TOPLEFT", self.header, "TOPLEFT", 1, -9)
	end
	self.header.title:SetText("Threat")
	self.header.title:SetTextColor(1, 0.82, 0)
	self.minimizeButton = CreateFrame("Button", nil, self.header)
	self.minimizeButton:SetSize(18, 19)
	self.minimizeButton:SetPoint("TOPRIGHT", self.header, "TOPRIGHT", -3, -5)
	SetButtonAtlas(self.minimizeButton, "ui-questtrackerbutton-collapse-all", "Interface\\Buttons\\UI-MinusButton-Up")
	TrySetAtlas(self.minimizeButton, "SetPushedAtlas", "ui-questtrackerbutton-collapse-all-pressed", true)
	TrySetAtlas(self.minimizeButton, "SetHighlightAtlas", "ui-questtrackerbutton-red-highlight")
	self.minimizeButton:SetScript("OnClick", function() ThreatMeter:ToggleDamageMeterCollapsed() end)
	self.settingsButton = CreateFrame("Button", nil, self.header)
	self.settingsButton:SetSize(27, 27)
	self.settingsButton:SetPoint("RIGHT", self.minimizeButton, "LEFT", -2, -2)
	SetButtonAtlas(self.settingsButton, "common-dropdown-a-button-settings-shadowless", "Interface\\Buttons\\UI-OptionsButton")
	TrySetAtlas(self.settingsButton, "SetPushedAtlas", "common-dropdown-a-button-settings-pressed-shadowless", true)
	TrySetAtlas(self.settingsButton, "SetHighlightAtlas", "common-dropdown-a-button-settings-hover-shadowless")
	self.settingsButton:SetScript("OnClick", function() ThreatMeter:ToggleDamageMeterMenu() end)
	self:CreateDamageMeterMenu()
	self.rows = {}
	self.currentThreatData = {}
	self.resizeGrip = CreateFrame("Button", nil, self.frame)
	self.resizeGrip:SetSize(60, 60)
	self.resizeGrip:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 9, -8)
	self.resizeGrip:SetFrameStrata("HIGH")
	if type(self.resizeGrip.SetToplevel) == "function" then self.resizeGrip:SetToplevel(true) end
	if TrySetAtlas(self.resizeGrip, "SetNormalAtlas", "damagemeters-scalehandle") then
		TrySetAtlas(self.resizeGrip, "SetHighlightAtlas", "damagemeters-scalehandle-hover")
		TrySetAtlas(self.resizeGrip, "SetPushedAtlas", "damagemeters-scalehandle-pressed")
	else
		self.resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
		self.resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
		self.resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	end
	self.resizeGrip:SetScript("OnMouseDown", function(_, button)
		if button == "LeftButton" and TMTAB["DAMAGEMETERCOLLAPSED"] ~= true and (ThreatMeter.editModeActive or not ThreatMeter:GV(TMTAB, "lockedText", true)) and not InCombatLockdown() then ThreatMeter.frame:StartSizing("BOTTOMRIGHT") end
	end)
	self.resizeGrip:SetScript("OnMouseUp", function()
		ThreatMeter.frame:StopMovingOrSizing()
		ThreatMeter:SaveThreatWindowSize()
		ThreatMeter:RefreshThreatLayout()
		if ThreatMeter.editModeOptions and ThreatMeter.editModeOptions:IsShown() then
			for _, control in ipairs(ThreatMeter.editModeOptions.Controls or {}) do control:Refresh() end
			ThreatMeter.editModeOptions.RevertChanges:SetEnabled(true)
		end
	end)
	self.frame:SetScript("OnDragStart", function(frame)
		if ThreatMeter.editModeActive and not InCombatLockdown() then frame:StartMoving() end
	end)
	self.frame:SetScript("OnDragStop", function(frame)
		frame:StopMovingOrSizing()
		ThreatMeter:SaveThreatWindowPosition()
	end)
	self.frame:SetScript("OnSizeChanged", function() ThreatMeter:RefreshThreatLayout() end)
	local point, relativeTo, relativePoint, x, y = unpack(ThreatMeter:GV(TMTAB, "TMFrame", {}))
	if point then
		self.frame:ClearAllPoints()
		self.frame:SetPoint(point, relativeTo, relativePoint, x, y)
	end
	ThreatMeter:ToggleText("CreateMainFrame", false)
	self.frame:SetAlpha(ThreatMeter:GV(TMTAB, "DMTRANSPARENCY", 100) / 100)
	ThreatMeter:SetTextScale(ThreatMeter:GV(TMTAB, "DMTEXTSIZE", 100) / 100)
	ThreatMeter:ApplyDamageMeterCollapsed()
	if ThreatMeter.SetupDamageMeterEditMode then ThreatMeter:SetupDamageMeterEditMode() end
	ThreatMeter:RefreshThreatLayout()
	C_Timer.After(3, function() ThreatMeter:StartThreatTicker() end)
	local ok, err = pcall(ThreatMeter.UpdateThreatLogic, ThreatMeter)
	if not ok then print(err) end
end
