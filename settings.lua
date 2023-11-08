local _, ThreatMeter = ...
function ThreatMeter:ToggleFrame()
	if self.frame then
		D4:SV(TMTAB, "lockedText", not D4:GV(TMTAB, "lockedText", true))
		if D4:GV(TMTAB, "lockedText", true) then
			self.frame:SetMovable(false)
			self.frame:EnableMouse(false)
			D4:MSG("ThreatMeter", 132117, "Text is now locked.")
		else
			self.frame:SetMovable(true)
			self.frame:EnableMouse(true)
			D4:MSG("ThreatMeter", 132117, "Text is now unlocked.")
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
	tm_settings = D4:CreateFrame(
		{
			["name"] = "ThreatMeter",
			["pTab"] = {"CENTER"},
			["sw"] = 520,
			["sh"] = 520,
			["title"] = format("ThreatMeter |T132117:16:16:0:0|t v|cff3FC7EB%s", "0.4.2")
		}
	)

	local y = -30
	if TMTAB["MMBTN"] == nil then
		TMTAB["MMBTN"] = true
	end

	D4:AddCategory(
		{
			["name"] = "LID_GENERAL",
			["parent"] = tm_settings,
			["pTab"] = {"TOPLEFT", 10, y},
		}
	)

	y = y - 15
	D4:CreateCheckbox(
		{
			["name"] = "showMinimapButton",
			["parent"] = tm_settings,
			["pTab"] = {"TOPLEFT", 10, y},
			["value"] = TMTAB["MMBTN"],
			["funcV"] = function(sel, checked)
				TMTAB["MMBTN"] = checked
				if TMTAB["MMBTN"] then
					D4:ShowMMBtn("ThreatMeter")
				else
					D4:HideMMBtn("ThreatMeter")
				end
			end
		}
	)

	y = y - 45
	D4:AddCategory(
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

	D4:CreateCheckbox(
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
	D4:CreateSlider(
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
			D4:AddSlash("tm", ThreatMeter.ToggleSettings)
			D4:AddSlash("threatmeter", ThreatMeter.ToggleSettings)
			local mmbtn = nil
			D4:CreateMinimapButton(
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
						D4:SV(TMTAB, "showMMBtn", false)
						D4:MSG("ThreatMeter", 132117, "Minimap Button is now hidden.")
						D4:HideMMBtn("ThreatMeter")
					end,
				}
			)

			TMTAB["TEXTSCALE"] = TMTAB["TEXTSCALE"] or 1
			ThreatMeter:SetTextScale(TMTAB["TEXTSCALE"])
			if D4:GV(TMTAB, "showMMBtn", true) then
				D4:ShowMMBtn("ThreatMeter")
			else
				D4:HideMMBtn("ThreatMeter")
			end
		end
	end
)