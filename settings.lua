local AddonName, ThreatMeter = ...
ThreatMeter:SetAddonOutput("ThreatMeter", 132117)
function ThreatMeter:ToggleFrame()
	if self.frame then
		ThreatMeter:SV(TMTAB, "lockedText", not ThreatMeter:GV(TMTAB, "lockedText", true))
		if ThreatMeter:GV(TMTAB, "lockedText", true) then
			self.frame:SetMovable(false)
			self.frame:EnableMouse(false)
			ThreatMeter:MSG("Text is now locked.")
		else
			self.frame:SetMovable(true)
			self.frame:EnableMouse(true)
			ThreatMeter:MSG("Text is now unlocked.")
		end
	else
		C_Timer.After(
			1,
			function()
				ThreatMeter:ToggleFrame()
			end
		)
	end
end

function ThreatMeter:SetPositon(x, y)
	if self.frame then
		self.frame:SetPoint("CENTER", UIParent, "CENTER", x, y)
	else
		C_Timer.After(
			1,
			function()
				ThreatMeter:SetPositon(x, y)
			end
		)
	end
end

function ThreatMeter:SetTextScale(val)
	if val then
		self.frame:SetScale(val)
	end
end

local tm_settings = nil
function ThreatMeter:ToggleSettings()
	if tm_settings then
		if tm_settings:IsShown() then
			tm_settings:Hide()
		else
			tm_settings:Show()
		end
	end
end

function ThreatMeter:InitSettings()
	TMTAB = TMTAB or {}
	ThreatMeter:SetVersion(AddonName, 132117, "0.4.31")
	tm_settings = ThreatMeter:CreateFrame(
		{
			["name"] = "ThreatMeter",
			["pTab"] = {"CENTER"},
			["sw"] = 520,
			["sh"] = 520,
			["title"] = format("ThreatMeter |T132117:16:16:0:0|t v|cff3FC7EB%s", "0.4.31")
		}
	)

	local y = -30
	if TMTAB["MMBTN"] == nil then
		TMTAB["MMBTN"] = true
	end

	ThreatMeter:AddCategory(
		{
			["name"] = "LID_GENERAL",
			["parent"] = tm_settings,
			["pTab"] = {"TOPLEFT", 10, y},
		}
	)

	y = y - 15
	ThreatMeter:CreateCheckbox(
		{
			["name"] = "showMinimapButton",
			["parent"] = tm_settings,
			["pTab"] = {"TOPLEFT", 10, y},
			["value"] = TMTAB["MMBTN"],
			["funcV"] = function(sel, checked)
				TMTAB["MMBTN"] = checked
				if TMTAB["MMBTN"] then
					ThreatMeter:ShowMMBtn("ThreatMeter")
				else
					ThreatMeter:HideMMBtn("ThreatMeter")
				end
			end
		}
	)

	y = y - 45
	ThreatMeter:AddCategory(
		{
			["name"] = "LID_TEXT",
			["parent"] = tm_settings,
			["pTab"] = {"TOPLEFT", 10, y},
		}
	)

	y = y - 15
	if TMTAB["SHOWTEXTOUTSIDEOFCOMBAT"] == nil then
		TMTAB["SHOWTEXTOUTSIDEOFCOMBAT"] = true
	end

	ThreatMeter:CreateCheckbox(
		{
			["name"] = "LID_SHOWTEXTOUTSIDEOFCOMBAT",
			["parent"] = tm_settings,
			["pTab"] = {"TOPLEFT", 10, y},
			["value"] = TMTAB["SHOWTEXTOUTSIDEOFCOMBAT"],
			["funcV"] = function(sel, checked)
				TMTAB["SHOWTEXTOUTSIDEOFCOMBAT"] = checked
			end
		}
	)

	y = y - 45
	TMTAB["TEXTSCALE"] = TMTAB["TEXTSCALE"] or 1
	ThreatMeter:CreateSlider(
		{
			["name"] = "LID_TEXTSCALE",
			["parent"] = tm_settings,
			["sw"] = 400,
			["pTab"] = {"TOPLEFT", 15, y},
			["vmin"] = 0.4,
			["vmax"] = 2.0,
			["value"] = TMTAB["TEXTSCALE"],
			["steps"] = 0.1,
			["funcV"] = function(sel, val)
				if val then
					TMTAB["TEXTSCALE"] = val
					ThreatMeter:SetTextScale(val)
				end
			end,
		}
	)
end

local frame = CreateFrame("FRAME")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript(
	"OnEvent",
	function(self, event, ...)
		if event == "PLAYER_LOGIN" then
			ThreatMeter:InitSettings()
			ThreatMeter:CreateFrame()
			ThreatMeter:AddSlash("tm", ThreatMeter.ToggleSettings)
			ThreatMeter:AddSlash("threatmeter", ThreatMeter.ToggleSettings)
			local mmbtn = nil
			ThreatMeter:CreateMinimapButton(
				{
					["name"] = "ThreatMeter",
					["icon"] = 132117,
					["var"] = mmbtn,
					["dbtab"] = TMTAB,
					["vTT"] = {"ThreatMeter", "Leftclick: Open Settings", "Rightclick - Unlock/lock Text", "Shift + Rightclick - Hide Minimap Icon"},
					["funcL"] = function()
						ThreatMeter:ToggleSettings()
					end,
					["funcR"] = function()
						ThreatMeter:ToggleFrame()
					end,
					["funcSR"] = function()
						ThreatMeter:SV(TMTAB, "showMMBtn", false)
						ThreatMeter:MSG("Minimap Button is now hidden.")
						ThreatMeter:HideMMBtn("ThreatMeter")
					end,
				}
			)

			TMTAB["TEXTSCALE"] = TMTAB["TEXTSCALE"] or 1
			ThreatMeter:SetTextScale(TMTAB["TEXTSCALE"])
			if ThreatMeter:GV(TMTAB, "showMMBtn", true) then
				ThreatMeter:ShowMMBtn("ThreatMeter")
			else
				ThreatMeter:HideMMBtn("ThreatMeter")
			end
		end
	end
)
