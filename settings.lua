local _, ThreatMeter = ...
function ThreatMeter:ToggleSettings()
	D4:MSG("ThreatMeter", 132117, "Settings Soon")
	D4:MSG("ThreatMeter", 132117, "/tm mm - toggles minimap")
end

function ThreatMeter:ToggleFrame()
	if self.frame then
		D4:SV(TMTAB, "lockedText", not D4:GV(TMTAB, "lockedText", true))
		if D4:GV(TMTAB, "lockedText", true) then
			self.frame:SetMovable(false)
			D4:MSG("ThreatMeter", 132117, "Text is now locked.")
		else
			self.frame:SetMovable(true)
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

local frame = CreateFrame("FRAME")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript(
	"OnEvent",
	function(self, event, ...)
		if event == "PLAYER_LOGIN" then
			TMTAB = TMTAB or {}
			D4:AddSlash("tm", ThreatMeter.ToggleSettings)
			D4:AddSlash("threatmeter", ThreatMeter.ToggleSettings)
			D4:AddSlash(
				"tm mm",
				function()
					D4:SV(TMTAB, "showMMBtn", not D4:GV(TMTAB, "showMMBtn", true))
					if D4:GV(TMTAB, "showMMBtn", true) then
						D4:ShowMMBtn("ThreatMeter")
						D4:MSG("ThreatMeter", 132117, "Minimap Button is now shown.")
					else
						D4:HideMMBtn("ThreatMeter")
						D4:MSG("ThreatMeter", 132117, "Minimap Button is now hidden.")
					end
				end
			)

			local mmbtn = nil
			D4:CreateMinimapButton(
				{
					["name"] = "ThreatMeter",
					["icon"] = 132117,
					["var"] = mmbtn,
					["dbtab"] = TMTAB,
					["vTT"] = {"ThreatMeter", "Leftclick: Open Settings (Soon)", "Rightclick - Unlock/lock Text", "Shift + Rightclick - Hide Minimap Icon"},
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

			if D4:GV(TMTAB, "showMMBtn", true) then
				D4:ShowMMBtn("ThreatMeter")
			else
				D4:HideMMBtn("ThreatMeter")
			end
		end
	end
)