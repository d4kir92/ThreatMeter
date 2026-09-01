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
	if val and type(val) == "number" then self.frame:SetScale(val) end
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

	AddCategory("DISPLAY")
	AddCheckbox("SHOWTEXTOUTSIDEOFCOMBAT", true)
	AddCheckbox("SHOWHIGHESTTHREAT", true)
	AddCategory("TEXT", 2)
	AddCheckbox("lockedText", true, function() ThreatMeter:ToggleText("lockedText CheckBox", true) end)
	AddSlider("TEXTSCALE", 1, 0.4, 2, 0.1, 1, function(value) ThreatMeter:SetTextScale(value) end)
	AddCategory("BAR", 2)
	AddCheckbox("DISPLAYBAR", false)
	tmset:ResumeLayout()
end

local eventFrame = CreateFrame("FRAME")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event, ...)
	if event == "PLAYER_LOGIN" then
		TMTAB = TMTAB or {}
		ThreatMeter:SetVersion(132117, "0.6.0")
		ThreatMeter:InitSettings()
		ThreatMeter:CreateMainFrame()
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

		ThreatMeter:SetTextScale(ThreatMeter:GV(TMTAB, "TEXTSCALE", 1))
	end
end)
