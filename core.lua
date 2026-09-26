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

function ThreatMeter:IsSecret(value)
	if type(_G.issecretvalue) == "function" then return _G.issecretvalue(value) end
	return false
end

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
	local absValue = math.abs(value)
	if absValue >= 1000000 then return format("%.1fm", value / 1000000) end
	if absValue >= 1000 then return format("%.1fk", value / 1000) end
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

function ThreatMeter:GetThreatEntry(unit)
	if not ThreatMeter:SafeUnitExists(unit) then return nil end
	local nameOk, name = pcall(UnitName, unit)
	if not nameOk or not ThreatMeter:IsSafe(name) or type(name) ~= "string" then return nil end
	local classOk, _, classToken = pcall(UnitClass, unit)
	if not classOk or not ThreatMeter:IsSafe(classToken) or type(classToken) ~= "string" then classToken = nil end
	local ok, isTanking, status, scaled, _, rawThreat = pcall(UnitDetailedThreatSituation, unit, "target")
	if not ok then return nil end
	if not ThreatMeter:IsSafe(status) or type(status) ~= "number" then status = nil end
	if not ThreatMeter:IsSafe(scaled) or type(scaled) ~= "number" then scaled = nil end
	if not ThreatMeter:IsSafe(rawThreat) or type(rawThreat) ~= "number" then rawThreat = nil end
	local tanking = ThreatMeter:IsSafe(isTanking) and isTanking == true
	if status == nil then
		local statusOk, fallbackStatus = pcall(UnitThreatSituation, unit, "target")
		if statusOk and ThreatMeter:IsSafe(fallbackStatus) and type(fallbackStatus) == "number" then status = fallbackStatus end
	end
	local targetTarget = ThreatMeter:SafeUnitIsUnit("targettarget", unit)
	if scaled == nil and rawThreat == nil and status == nil and not tanking and not targetTarget then return nil end
	local barValue = 0
	if scaled ~= nil then
		barValue = Clamp(scaled, 0, 100)
	elseif tanking or targetTarget or status and status >= 2 then
		barValue = 100
	elseif status == 1 then
		barValue = 90
	elseif status == 0 then
		barValue = 25
	end
	return {
		unit = unit,
		name = name,
		classToken = classToken,
		isPlayer = ThreatMeter:SafeUnitIsUnit(unit, "player"),
		isTanking = tanking,
		isAggroHolder = targetTarget or tanking or status and status >= 2,
		status = status,
		scaled = scaled,
		rawThreat = rawThreat,
		barValue = barValue
	}
end

function ThreatMeter:GetThreatUnits()
	local units = {}
	local function Add(unit)
		if ThreatMeter:SafeUnitExists(unit) then units[#units + 1] = unit end
	end
	if IsInRaid() then
		for i = 1, GetNumGroupMembers() do Add("raid" .. i) end
	elseif IsInGroup() then
		Add("player")
		for i = 1, GetNumSubgroupMembers() do Add("party" .. i) end
	else
		Add("player")
	end
	return units
end

local function ThreatSort(a, b)
	if a.isAggroHolder ~= b.isAggroHolder then return a.isAggroHolder end
	if a.rawThreat ~= nil or b.rawThreat ~= nil then
		if a.rawThreat == nil then return false end
		if b.rawThreat == nil then return true end
		if a.rawThreat ~= b.rawThreat then return a.rawThreat > b.rawThreat end
	end
	if a.barValue ~= b.barValue then return a.barValue > b.barValue end
	if a.isPlayer ~= b.isPlayer then return a.isPlayer end
	return a.name < b.name
end

function ThreatMeter:GetThreatData()
	if not ThreatMeter:SafeUnitExists("target") then return {} end
	local attackOk, canAttack = pcall(UnitCanAttack, "player", "target")
	if not attackOk or not ThreatMeter:IsSafe(canAttack) or canAttack ~= true then return {} end
	local data = {}
	for _, unit in ipairs(ThreatMeter:GetThreatUnits()) do
		local entry = ThreatMeter:GetThreatEntry(unit)
		if entry and (entry.isPlayer or TMTAB["SHOWHIGHESTTHREAT"]) then data[#data + 1] = entry end
	end
	table.sort(data, ThreatSort)
	return data
end

function ThreatMeter:GetThreatPercentText(entry)
	if entry.scaled ~= nil then return format("%.0f%%", entry.scaled) end
	if entry.isAggroHolder then return ThreatMeter:Trans("LID_TANKING") end
	if entry.status == 1 then return "~90%" end
	if entry.status == 0 then return "~25%" end
	return "—"
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

function ThreatMeter:UpdateThreatRows(data)
	self.currentThreatData = data
	self:EnsureThreatRows(math.min(#data, 40))
	self:RefreshThreatLayout()
	for i, row in ipairs(self.rows) do
		local entry = data[i]
		if entry and i <= self.visibleRowCount then
			local r, g, b = 0.18, 0.55, 0.78
			if ThreatMeter:GV(TMTAB, "DMSHOWCLASSCOLOR", true) then r, g, b = GetClassColor(entry.classToken) end
			row.bar:SetValue(TMTAB["DISPLAYBAR"] == false and 0 or entry.barValue)
			row.bar:SetStatusBarColor(r, g, b, 0.9)
			row.name:SetText(i .. ". " .. entry.name)
			row.name:SetTextColor(1, 1, 1)
			local percentText = ThreatMeter:GetThreatPercentText(entry)
			local numbers = ThreatMeter:GV(TMTAB, "DMNUMBERS", 1)
			if entry.rawThreat ~= nil and numbers == 0 then
				row.value:SetText(FormatThreat(entry.rawThreat))
			elseif entry.rawThreat ~= nil then
				row.value:SetText(FormatThreat(entry.rawThreat) .. " (" .. percentText .. ")")
			else
				row.value:SetText(percentText)
			end
			row.hasIcon = SetClassIcon(row.icon, entry.classToken)
			self:ApplyThreatRowStyle(row)
		end
	end
end

function ThreatMeter:UpdateThreatLogic()
	if not self.frame then return end
	if self.editModeActive then
		self.frame:Show()
		self:UpdateThreatRows({
			{name = "Player", classToken = "WARRIOR", isPlayer = true, isAggroHolder = true, status = 3, scaled = 100, rawThreat = 17521, barValue = 100},
			{name = "Threat", classToken = "MAGE", isPlayer = false, isAggroHolder = false, status = 1, scaled = 76, rawThreat = 13280, barValue = 76}
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
			{name = "Tank", classToken = "WARRIOR", isPlayer = false, isAggroHolder = true, status = 3, scaled = 100, rawThreat = 12500, barValue = 100},
			{name = "Player", classToken = "MAGE", isPlayer = true, isAggroHolder = false, status = 1, scaled = 82, rawThreat = 10250, barValue = 82}
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
		TMTAB["DAMAGEEXPANDEDHEIGHT"] = math.max(MIN_HEIGHT, self.frame:GetHeight() or 200)
		self.frame:SetHeight(HEADER_HEIGHT)
		self.background:Hide()
		for _, row in ipairs(self.rows) do row:Hide() end
	else
		self.frame:SetHeight(ThreatMeter:GV(TMTAB, "DAMAGEEXPANDEDHEIGHT", ThreatMeter:GV(TMTAB, "TMFrameHeight", 200)))
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
		if not ThreatMeter:GV(TMTAB, "lockedText", true) and not InCombatLockdown() then frame:StartMoving() end
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
