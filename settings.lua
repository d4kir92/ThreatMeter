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
	ThreatMeter:SetVersion(AddonName, 132117, "0.4.39")
	tm_settings = ThreatMeter:CreateFrame(
		{
			["name"] = "ThreatMeter",
			["pTab"] = {"CENTER"},
			["sw"] = 520,
			["sh"] = 520,
			["title"] = format("ThreatMeter |T132117:16:16:0:0|t v|cff3FC7EB%s", "0.4.39")
		}
	)

	tm_settings.SF = CreateFrame("ScrollFrame", "tm_settings_SF", tm_settings, "UIPanelScrollFrameTemplate")
	tm_settings.SF:SetPoint("TOPLEFT", tm_settings, 8, -26)
	tm_settings.SF:SetPoint("BOTTOMRIGHT", tm_settings, -32, 8)
	tm_settings.SC = CreateFrame("Frame", "tm_settings_SC", tm_settings.SF)
	tm_settings.SC:SetSize(tm_settings.SF:GetSize())
	tm_settings.SC:SetPoint("TOPLEFT", tm_settings.SF, "TOPLEFT", 0, 0)
	tm_settings.SF:SetScrollChild(tm_settings.SC)
	local y = 0
	ThreatMeter:SetAppendY(y)
	ThreatMeter:SetAppendParent(tm_settings.SC)
	ThreatMeter:SetAppendTab(TMTAB)
	ThreatMeter:AppendCategory("GENERAL")
	ThreatMeter:AppendCheckbox(
		"MMBTN",
		ThreatMeter:GetWoWBuild() ~= "RETAIL",
		function(sel, checked)
			if checked then
				ThreatMeter:ShowMMBtn("ThreatMeter")
			else
				ThreatMeter:HideMMBtn("ThreatMeter")
			end
		end
	)

	ThreatMeter:AppendCategory("TEXT")
	ThreatMeter:AppendCheckbox("SHOWTEXTOUTSIDEOFCOMBAT", true)
	ThreatMeter:AppendSlider(
		"TEXTSCALE",
		1,
		0.4,
		2,
		0.1,
		1,
		function(sel, val)
			if val then
				TMTAB["TEXTSCALE"] = val
				ThreatMeter:SetTextScale(val)
			end
		end
	)
end

local frame = CreateFrame("FRAME")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript(
	"OnEvent",
	function(self, event, ...)
		if event == "PLAYER_LOGIN" then
			ThreatMeter:InitSettings()
			ThreatMeter:CreateMainFrame()
			ThreatMeter:AddSlash("tm", ThreatMeter.ToggleSettings)
			ThreatMeter:AddSlash("threatmeter", ThreatMeter.ToggleSettings)
			C_Timer.After(
				0,
				function()
					local mmbtn = nil
					ThreatMeter:CreateMinimapButton(
						{
							["name"] = "ThreatMeter",
							["icon"] = 132117,
							["var"] = mmbtn,
							["dbtab"] = TMTAB,
							["vTT"] = {{"ThreatMeter |T132117:16:16:0:0|t", "v|cff3FC7EB0.4.39"}, {"Leftclick", "Open Settings"}, {"Rightclick", "Unlock/lock Text"}, {"Shift + Rightclick", "Hide Minimap Icon"}},
							["funcL"] = function()
								ThreatMeter:ToggleSettings()
							end,
							["funcR"] = function()
								ThreatMeter:ToggleFrame()
							end,
							["funcSR"] = function()
								ThreatMeter:SV(TMTAB, "MMBTN", false)
								ThreatMeter:MSG("Minimap Button is now hidden.")
								ThreatMeter:HideMMBtn("ThreatMeter")
							end,
						}
					)

					if ThreatMeter:GV(TMTAB, "MMBTN", ThreatMeter:GetWoWBuild() ~= "RETAIL") then
						ThreatMeter:ShowMMBtn("ThreatMeter")
					else
						ThreatMeter:HideMMBtn("ThreatMeter")
					end
				end
			)

			TMTAB["TEXTSCALE"] = TMTAB["TEXTSCALE"] or 1
			ThreatMeter:SetTextScale(TMTAB["TEXTSCALE"])
		end
	end
)
