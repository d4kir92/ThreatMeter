local _, ThreatMeter = ...
ThreatMeter:SetAddonOutput("ThreatMeter", 132117)
local tmset = nil
local DEFAULT_WIDTH = 420
local DEFAULT_HEIGHT = 520
function ThreatMeter:ToggleFrame()
	if self.frame then
		ThreatMeter:SV(TMTAB, "lockedText", not ThreatMeter:GV(TMTAB, "lockedText", true))
		ThreatMeter:ToggleText("ToggleFrame", true)
	else
		C_Timer.After(1, function() ThreatMeter:ToggleFrame() end)
	end
end

function ThreatMeter:SetPosition(x, y)
	if self.frame then
		self.frame:SetPoint("CENTER", UIParent, "CENTER", x, y)
	else
		C_Timer.After(1, function() ThreatMeter:SetPosition(x, y) end)
	end
end

function ThreatMeter:SetTextScale(val)
	if self.frame == nil then return end
	if val and type(val) == "number" then
		self.textScale = val
		if self.header and self.header.title then self:SetFontStringScale(self.header.title, val) end
		for _, row in ipairs(self.rows or {}) do
			self:SetFontStringScale(row.name, val)
			self:SetFontStringScale(row.value, val)
		end
	end
end

function ThreatMeter:ApplyDamageMeterEnabled()
	if self.UpdateThreatLogic then self:UpdateThreatLogic() end
end

function ThreatMeter:ApplyLegacyEnabled()
	if self.UpdateLegacyThreatLogic then self:UpdateLegacyThreatLogic() end
end

function ThreatMeter:ToggleSettings()
	if tmset == nil then return end
	tmset:Toggle()
end

local function GetCollapsed(key)
	if key == nil then return nil end
	if type(TMTAB) ~= "table" then return nil end
	if type(TMTAB["COLLAPSED"]) ~= "table" then return nil end
	return TMTAB["COLLAPSED"][key]
end

local function SetCollapsed(key, collapsed)
	if key == nil then return end
	if type(TMTAB) ~= "table" then return end
	if type(TMTAB["COLLAPSED"]) ~= "table" then TMTAB["COLLAPSED"] = {} end
	if collapsed then
		TMTAB["COLLAPSED"][key] = true
	else
		TMTAB["COLLAPSED"][key] = nil
	end
end

local function GetConfig(key, default)
	local value = ThreatMeter:GV(TMTAB, key, default)
	ThreatMeter:SV(TMTAB, key, value)
	return value
end

local function AddCategory(key, level)
	tmset:AddCategory({
		["label"] = "LID_" .. key,
		["key"] = key,
		["search"] = key,
		["level"] = level
	})
end

local function AddCheckbox(key, default, func)
	tmset:AddCheckbox({
		["label"] = "LID_" .. key,
		["search"] = key,
		["value"] = GetConfig(key, default),
		["func"] = function(value)
			ThreatMeter:SV(TMTAB, key, value)
			if func then func(value) end
		end
	})
end

local function AddSlider(key, default, min, max, step, decimals, func)
	tmset:AddSlider({
		["label"] = "LID_" .. key,
		["search"] = key,
		["value"] = GetConfig(key, default),
		["min"] = min,
		["max"] = max,
		["step"] = step,
		["decimals"] = decimals,
		["func"] = function(value)
			ThreatMeter:SV(TMTAB, key, value)
			if func then func(value) end
		end
	})
end

function ThreatMeter:InitSettings()
	tmset = ThreatMeter:CreateUIWindow({
		["name"] = "ThreatMeterSettings",
		["pTab"] = {"CENTER"},
		["width"] = GetConfig("WINDOWWIDTH", DEFAULT_WIDTH),
		["height"] = GetConfig("WINDOWHEIGHT", DEFAULT_HEIGHT),
		["minWidth"] = 360,
		["minHeight"] = 240,
		["onResize"] = function(width, height)
			ThreatMeter:SV(TMTAB, "WINDOWWIDTH", width)
			ThreatMeter:SV(TMTAB, "WINDOWHEIGHT", height)
		end,
		["getCollapsed"] = function(key) return GetCollapsed(key) end,
		["setCollapsed"] = function(key, collapsed) SetCollapsed(key, collapsed) end,
		["title"] = format("|T132117:16:16:0:0|t ThreatMeter v%s", ThreatMeter:GetVersion())
	})

	tmset:SuspendLayout()
	tmset:AddSearch()
	AddCategory("GENERAL")
	AddCheckbox("MMBTN", ThreatMeter:GetWoWBuild() ~= "RETAIL", function(value)
		if value then
			ThreatMeter:ShowMMBtn("ThreatMeter")
		else
			ThreatMeter:HideMMBtn("ThreatMeter")
		end
	end)

	AddCategory("DAMAGEMETERTHREAT")
	AddCheckbox("SHOWDAMAGEMETERTHREAT", true, function() ThreatMeter:ApplyDamageMeterEnabled() end)
	AddCategory("LEGACYTHREAT")
	AddCheckbox("SHOWLEGACYTHREAT", false, function() ThreatMeter:ApplyLegacyEnabled() end)
	AddCheckbox("LEGACYSHOWOUTSIDE", true, function() ThreatMeter:ApplyLegacyEnabled() end)
	AddCheckbox("LEGACYSHOWHIGHESTTHREAT", true)
	AddCategory("LEGACYWINDOW", 2)
	AddCheckbox("LEGACYLOCKED", false, function() ThreatMeter:ApplyLegacyLock() end)
	AddSlider("LEGACYSCALE", 1, 0.4, 2, 0.1, 1, function(value) ThreatMeter:SetLegacyScale(value) end)
	AddCheckbox("LEGACYDISPLAYBAR", true)
	tmset:ResumeLayout()
end

local eventFrame = CreateFrame("FRAME")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event, ...)
	if event == "PLAYER_LOGIN" then
		TMTAB = TMTAB or {}
		local meterWindowVersion = ThreatMeter:GV(TMTAB, "METERWINDOWVERSION", 0)
		if meterWindowVersion < 5 then
			TMTAB["DISPLAYBAR"] = true
			TMTAB["lockedText"] = false
			if TMTAB["SHOWDAMAGEMETERTHREAT"] == nil then TMTAB["SHOWDAMAGEMETERTHREAT"] = true end
			if TMTAB["SHOWLEGACYTHREAT"] == nil then TMTAB["SHOWLEGACYTHREAT"] = false end
			if TMTAB["LEGACYDISPLAYBAR"] == nil then TMTAB["LEGACYDISPLAYBAR"] = true end
			if TMTAB["LEGACYSHOWOUTSIDE"] == nil then TMTAB["LEGACYSHOWOUTSIDE"] = true end
			if TMTAB["LEGACYSHOWHIGHESTTHREAT"] == nil then TMTAB["LEGACYSHOWHIGHESTTHREAT"] = true end
			if TMTAB["LEGACYLOCKED"] == nil then TMTAB["LEGACYLOCKED"] = false end
			if TMTAB["DMSTYLE"] == nil then TMTAB["DMSTYLE"] = 0 end
			if TMTAB["DMNUMBERS"] == nil then TMTAB["DMNUMBERS"] = 1 end
			if TMTAB["DMBARHEIGHT"] == nil then TMTAB["DMBARHEIGHT"] = 25 end
			if TMTAB["DMPADDING"] == nil then TMTAB["DMPADDING"] = 4 end
			if TMTAB["DMTRANSPARENCY"] == nil then TMTAB["DMTRANSPARENCY"] = 100 end
			if meterWindowVersion < 5 then TMTAB["DAMAGEBACKGROUNDALPHA"] = 50 end
			if TMTAB["DMTEXTSIZE"] == nil then TMTAB["DMTEXTSIZE"] = math.floor(ThreatMeter:GV(TMTAB, "TEXTSCALE", 1) * 100 + 0.5) end
			if TMTAB["DMVISIBILITY"] == nil then TMTAB["DMVISIBILITY"] = TMTAB["SHOWTEXTOUTSIDEOFCOMBAT"] == false and 1 or 0 end
			if TMTAB["DMSHOWSPECICON"] == nil then TMTAB["DMSHOWSPECICON"] = true end
			if TMTAB["DMSHOWCLASSCOLOR"] == nil then TMTAB["DMSHOWCLASSCOLOR"] = true end
			TMTAB["METERWINDOWVERSION"] = 5
		end
		ThreatMeter:SetVersion(132117, "0.9.0")
		ThreatMeter:InitSettings()
		ThreatMeter:CreateMainFrame()
		ThreatMeter:CreateLegacyFrame()
		ThreatMeter:AddSlash("threatmeter", ThreatMeter.ToggleSettings)
		ThreatMeter:CreateMinimapButton({
			["name"] = "ThreatMeter",
			["icon"] = 132117,
			["var"] = nil,
			["dbtab"] = TMTAB,
			["vTT"] = {{"|T132117:16:16:0:0|t ThreatMeter", "v" .. ThreatMeter:GetVersion()}, {ThreatMeter:Trans("LID_LEFTCLICK"), ThreatMeter:Trans("LID_OPENSETTINGS")}, {ThreatMeter:Trans("LID_RIGHTCLICK"), ThreatMeter:Trans("LID_UNLOCKLOCKTEXT")}, {ThreatMeter:Trans("LID_SHIFTRIGHTCLICK"), ThreatMeter:Trans("LID_HIDEMINIMAPBUTTON")}},
			["funcL"] = function() ThreatMeter:ToggleSettings() end,
			["funcR"] = function() ThreatMeter:ToggleFrame() end,
			["funcSR"] = function()
				ThreatMeter:SV(TMTAB, "MMBTN", false)
				ThreatMeter:MSG(ThreatMeter:Trans("LID_MINIMAPBUTTONISNOWHIDDEN"))
				ThreatMeter:HideMMBtn("ThreatMeter")
			end,
			["dbkey"] = "MMBTN"
		})

		ThreatMeter:SetTextScale(ThreatMeter:GV(TMTAB, "DMTEXTSIZE", 100) / 100)
		ThreatMeter:SetLegacyScale(ThreatMeter:GV(TMTAB, "LEGACYSCALE", 1))
	end
end)
