local _, ThreatMeter = ...

local defaults = {
	DMSTYLE = 0, DMNUMBERS = 1, TMFrameWidth = 400, TMFrameHeight = 200,
	DMBARHEIGHT = 25, DMPADDING = 4, DMTRANSPARENCY = 100,
	DAMAGEBACKGROUNDALPHA = 50, DMTEXTSIZE = 100, DMVISIBILITY = 0,
	DMSHOWSPECICON = true, DMSHOWCLASSCOLOR = true
}
local editSettingKeys = {"DMSTYLE", "DMNUMBERS", "TMFrameWidth", "TMFrameHeight", "DMBARHEIGHT", "DMPADDING", "DMTRANSPARENCY", "DAMAGEBACKGROUNDALPHA", "DMTEXTSIZE", "DMVISIBILITY", "DMSHOWSPECICON", "DMSHOWCLASSCOLOR"}

local function GlobalText(key, fallback)
	return _G[key] or fallback
end

local function ApplyEditSetting(key, value)
	ThreatMeter:SV(TMTAB, key, value)
	if not ThreatMeter.frame then return end
	if key == "TMFrameWidth" then
		ThreatMeter.frame:SetWidth(value)
	elseif key == "TMFrameHeight" then
		ThreatMeter.frame:SetHeight(value)
	elseif key == "DMTRANSPARENCY" then
		ThreatMeter.frame:SetAlpha(value / 100)
	elseif key == "DAMAGEBACKGROUNDALPHA" and ThreatMeter.background then
		ThreatMeter.background:SetAlpha(value / 100)
	elseif key == "DMTEXTSIZE" then
		ThreatMeter:SetTextScale(value / 100)
	end
	ThreatMeter:RefreshThreatLayout()
	ThreatMeter:UpdateThreatLogic()
end

local function CreateLabel(panel, text, y)
	local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
	label:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, y)
	label:SetSize(125, 30)
	label:SetJustifyH("LEFT")
	label:SetText(text)
	return label
end

local function CreateDropdown(panel, label, key, options, y)
	local text = CreateLabel(panel, label, y)
	local dropdown = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
	dropdown:SetPoint("LEFT", text, "RIGHT", 5, 0)
	dropdown:SetSize(265, 30)
	dropdown:SetupMenu(function(_, rootDescription)
		for _, option in ipairs(options) do
			rootDescription:CreateRadio(option.text, function(value)
				return ThreatMeter:GV(TMTAB, key, defaults[key]) == value
			end, function(value)
				ApplyEditSetting(key, value)
				panel.RevertChanges:SetEnabled(true)
			end, option.value)
		end
	end)
	dropdown.Refresh = function(control) control:GenerateMenu() end
	panel.Controls[#panel.Controls + 1] = dropdown
end

local function CreateSlider(panel, label, key, minimum, maximum, step, y, formatter, minimumText, maximumText)
	local text = CreateLabel(panel, label, y)
	local slider = CreateFrame("Frame", nil, panel, "MinimalSliderWithSteppersTemplate")
	slider:SetPoint("LEFT", text, "RIGHT", 5, 0)
	slider:SetSize(265, 32)
	local formatters = {[MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right, formatter)}
	slider:Init(ThreatMeter:GV(TMTAB, key, defaults[key]), minimum, maximum, (maximum - minimum) / step, formatters)
	if minimumText then slider.MinText:SetText(minimumText) slider.MinText:Show() else slider.MinText:Hide() end
	if maximumText then slider.MaxText:SetText(maximumText) slider.MaxText:Show() else slider.MaxText:Hide() end
	slider.cbrHandles = EventUtil.CreateCallbackHandleContainer()
	slider.cbrHandles:RegisterCallback(slider, MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(control, value)
		if control.refreshing then return end
		ApplyEditSetting(key, math.floor(value / step + 0.5) * step)
		panel.RevertChanges:SetEnabled(true)
	end, slider)
	slider.Refresh = function(control)
		control.refreshing = true
		control:SetValue(ThreatMeter:GV(TMTAB, key, defaults[key]))
		control.refreshing = nil
	end
	panel.Controls[#panel.Controls + 1] = slider
end

local function CreateCheckbox(panel, label, key, y)
	local button = CreateFrame("CheckButton", nil, panel)
	button:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, y)
	button:SetSize(32, 32)
	button:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
	button:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
	button:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
	button:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
	button:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
	button.Label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
	button.Label:SetPoint("LEFT", button, "RIGHT", 5, 0)
	button.Label:SetText(label)
	button:SetScript("OnClick", function(control)
		ApplyEditSetting(key, control:GetChecked() == true)
		panel.RevertChanges:SetEnabled(true)
	end)
	button.Refresh = function(control) control:SetChecked(ThreatMeter:GV(TMTAB, key, defaults[key])) end
	panel.Controls[#panel.Controls + 1] = button
end

local function CreateEditModeOptions(owner)
	if ThreatMeter.editModeOptions then return ThreatMeter.editModeOptions end
	local panel = CreateFrame("Frame", "ThreatMeterEditModeOptions", UIParent, "ResizeLayoutFrame")
	panel:SetSize(450, 690)
	panel:SetPoint("RIGHT", UIParent, "RIGHT", -80, 0)
	panel:SetFrameStrata("DIALOG")
	panel:SetFrameLevel(200)
	panel:SetClampedToScreen(true)
	panel:EnableMouse(true)
	panel:SetMovable(true)
	panel:SetDontSavePosition(true)
	panel:RegisterForDrag("LeftButton")
	panel:SetScript("OnDragStart", panel.StartMoving)
	panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
	panel.Border = CreateFrame("Frame", nil, panel, "DialogBorderTranslucentTemplate")
	panel.Title = panel:CreateFontString(nil, nil, "GameFontHighlightLarge")
	panel.Title:SetPoint("TOP", 0, -15)
	panel.Title:SetText("Threat")
	panel.Close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
	panel.Close:SetPoint("TOPRIGHT")
	panel.Close:SetScript("OnClick", function() panel:Hide() end)
	panel.Controls = {}
	CreateDropdown(panel, GlobalText("HUD_EDIT_MODE_SETTING_DAMAGE_METER_STYLE", "Style"), "DMSTYLE", {
		{value = 0, text = GlobalText("HUD_EDIT_MODE_SETTING_DAMAGE_METER_STYLE_DEFAULT", "Default")},
		{value = 1, text = GlobalText("HUD_EDIT_MODE_SETTING_DAMAGE_METER_STYLE_BORDERED", "Bordered")},
		{value = 2, text = GlobalText("HUD_EDIT_MODE_SETTING_DAMAGE_METER_STYLE_THIN", "Thin")}
	}, -48)
	CreateDropdown(panel, GlobalText("HUD_EDIT_MODE_SETTING_DAMAGE_METER_NUMBERS", "Numbers"), "DMNUMBERS", {
		{value = 0, text = GlobalText("HUD_EDIT_MODE_SETTING_DAMAGE_METER_NUMBERS_MINIMAL", "Minimal")},
		{value = 1, text = GlobalText("HUD_EDIT_MODE_SETTING_DAMAGE_METER_NUMBERS_COMPACT", "Compact")},
		{value = 2, text = GlobalText("HUD_EDIT_MODE_SETTING_DAMAGE_METER_NUMBERS_COMPLETE", "Complete")}
	}, -91)
	CreateSlider(panel, GlobalText("HUD_EDIT_MODE_SETTING_DAMAGE_METER_FRAME_WIDTH", "Frame Width"), "TMFrameWidth", 200, 600, 1, -134, function() return "" end, NARROW or "Narrow", WIDE or "Wide")
	CreateSlider(panel, GlobalText("HUD_EDIT_MODE_SETTING_DAMAGE_METER_FRAME_HEIGHT", "Frame Height"), "TMFrameHeight", 120, 400, 1, -177, function() return "" end, SHORT or "Short", TALL or "Tall")
	CreateSlider(panel, GlobalText("HUD_EDIT_MODE_SETTING_DAMAGE_METER_BAR_HEIGHT", "Bar Height"), "DMBARHEIGHT", 15, 40, 1, -220, function() return "" end, SHORT or "Short", TALL or "Tall")
	CreateSlider(panel, GlobalText("HUD_EDIT_MODE_SETTING_DAMAGE_METER_PADDING", "Padding"), "DMPADDING", 2, 10, 1, -263, function(value) return tostring(math.floor(value + 0.5)) end)
	CreateSlider(panel, GlobalText("HUD_EDIT_MODE_SETTING_DAMAGE_METER_TRANSPARENCY", "Transparency"), "DMTRANSPARENCY", 50, 100, 1, -306, function(value) return format("%d%%", value) end)
	CreateSlider(panel, GlobalText("HUD_EDIT_MODE_SETTING_DAMAGE_METER_BACKGROUND", "Background"), "DAMAGEBACKGROUNDALPHA", 0, 100, 1, -349, function(value) return format("%d%%", value) end)
	CreateSlider(panel, GlobalText("HUD_EDIT_MODE_SETTING_DAMAGE_METER_TEXT_SIZE", "Text Size"), "DMTEXTSIZE", 50, 150, 10, -392, function(value) return format("%d%%", value) end)
	CreateDropdown(panel, GlobalText("HUD_EDIT_MODE_SETTING_DAMAGE_METER_VISIBILITY", "Visibility"), "DMVISIBILITY", {
		{value = 0, text = GlobalText("HUD_EDIT_MODE_SETTING_DAMAGE_METER_VISIBILITY_ALWAYS", "Always Visible")},
		{value = 1, text = GlobalText("HUD_EDIT_MODE_SETTING_DAMAGE_METER_VISIBILITY_IN_COMBAT", "In Combat")},
		{value = 2, text = GlobalText("HUD_EDIT_MODE_SETTING_DAMAGE_METER_VISIBILITY_HIDDEN", "Hidden")},
		{value = 3, text = GlobalText("HUD_EDIT_MODE_SETTING_DAMAGE_METER_VISIBILITY_IN_GROUP", "In Group")}
	}, -435)
	CreateCheckbox(panel, GlobalText("HUD_EDIT_MODE_SETTING_DAMAGE_METER_SHOW_SPEC_ICON", "Show Spec Icon"), "DMSHOWSPECICON", -478)
	CreateCheckbox(panel, GlobalText("HUD_EDIT_MODE_SETTING_DAMAGE_METER_SHOW_CLASS_COLOR", "Show Class Color"), "DMSHOWCLASSCOLOR", -518)
	panel.RevertChanges = CreateFrame("Button", nil, panel, "EditModeSystemSettingsDialogButtonTemplate")
	panel.RevertChanges:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 24, 22)
	panel.RevertChanges:SetSize(190, 22)
	panel.RevertChanges:SetText(_G.HUD_EDIT_MODE_REVERT_CHANGES or "Revert Changes")
	panel.RevertChanges:SetEnabled(false)
	panel.RevertChanges:SetScript("OnClick", function(control)
		for _, key in ipairs(editSettingKeys) do ApplyEditSetting(key, panel.OriginalSettings[key]) end
		for _, setting in ipairs(panel.Controls) do setting:Refresh() end
		control:SetEnabled(false)
	end)
	panel.Reset = CreateFrame("Button", nil, panel, "EditModeSystemSettingsDialogExtraButtonTemplate")
	panel.Reset:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -24, 22)
	panel.Reset:SetSize(190, 22)
	panel.Reset:SetText(_G.HUD_EDIT_MODE_RESET_POSITION or RESET_POSITION or "Reset Position")
	panel.Reset:SetScript("OnClick", function()
		owner:ClearAllPoints()
		owner:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
		ThreatMeter:SaveThreatWindowPosition()
	end)
	panel:SetScript("OnShow", function()
		panel.OriginalSettings = {}
		for _, key in ipairs(editSettingKeys) do panel.OriginalSettings[key] = ThreatMeter:GV(TMTAB, key, defaults[key]) end
		for _, setting in ipairs(panel.Controls) do setting:Refresh() end
		panel.RevertChanges:SetEnabled(false)
	end)
	panel:SetScript("OnHide", function()
		if ThreatMeter.editModeActive and owner.Selection then owner:HighlightSystem() end
	end)
	panel:Hide()
	ThreatMeter.editModeOptions = panel
	return panel
end

function ThreatMeter:SetDamageMeterEditModeActive(active)
	self.editModeActive = active == true
	if not self.frame or not self.frame.Selection then return end
	if self.editModeActive then
		if TMTAB["DAMAGEMETERCOLLAPSED"] == true then
			self.editModeWasCollapsed = true
			TMTAB["DAMAGEMETERCOLLAPSED"] = false
			self:ApplyDamageMeterCollapsed()
		end
		self.frame:Show()
		self.frame:SetResizable(true)
		if self.resizeGrip then
			self.resizeGrip:SetAlpha(1)
			self.resizeGrip:EnableMouse(true)
		end
		self.frame:HighlightSystem()
	else
		if self.editModeOptions then self.editModeOptions:Hide() end
		self.frame:ClearHighlight()
		self.frame:StopMovingOrSizing()
		if self.editModeWasCollapsed then
			self.editModeWasCollapsed = nil
			TMTAB["DAMAGEMETERCOLLAPSED"] = true
			self:ApplyDamageMeterCollapsed()
		end
		self:ToggleText("EditModeExit", false)
		self:UpdateThreatLogic()
	end
end

function ThreatMeter:SetupDamageMeterEditMode()
	if not self.frame or self.frame.Selection or not EditModeSystemSelectionMixin then return end
	local frame = self.frame
	frame.Selection = CreateFrame("Frame", nil, frame, "EditModeSystemSelectionTemplate")
	frame.Selection:SetAllPoints()
	frame.Selection:SetFrameLevel(frame:GetFrameLevel() + 100)
	frame.Selection:SetSystem(frame)
	frame.Selection:Hide()
	frame.GetSystemName = function() return "Threat" end
	frame.HighlightSystem = function(system)
		system.Selection:ShowHighlighted()
		if system.Selection.Label then system.Selection.Label:Hide() end
		system.isSelected = false
	end
	frame.SelectSystem = function(system)
		system.Selection:ShowSelected()
		if system.Selection.Label then system.Selection.Label:Hide() end
		system.isSelected = true
		CreateEditModeOptions(system):Show()
	end
	frame.ClearHighlight = function(system) system.Selection:Hide() system.isSelected = false end
	frame.OnDragStart = function(system)
		if not ThreatMeter.editModeActive or not system.isSelected then return end
		system:StartMoving()
	end
	frame.OnDragStop = function(system)
		if not ThreatMeter.editModeActive then return end
		system:StopMovingOrSizing()
		ThreatMeter:SaveThreatWindowPosition()
	end
	frame.Selection:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then frame:SelectSystem() end end)
	if EventRegistry and not self.editModeCallbacksRegistered then
		EventRegistry:RegisterCallback("EditMode.Enter", function() ThreatMeter:SetDamageMeterEditModeActive(true) end, self)
		EventRegistry:RegisterCallback("EditMode.Exit", function() ThreatMeter:SetDamageMeterEditModeActive(false) end, self)
		self.editModeCallbacksRegistered = true
	end
end

function ThreatMeter:OpenDamageMeterEditMode()
	if InCombatLockdown() then return end
	if SettingsPanel and SettingsPanel:IsShown() then
		local skipTransitionBackToOpeningPanel = true
		SettingsPanel:Close(skipTransitionBackToOpeningPanel)
	end
	if EditModeManagerFrame then ShowUIPanel(EditModeManagerFrame) end
end
