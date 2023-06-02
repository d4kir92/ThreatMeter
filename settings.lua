local _, ThreatMeter = ...
local frame = CreateFrame("FRAME")
frame:RegisterEvent("PLAYER_LOGIN")

function ThreatMeter:ToggleSettings()
	ThreatMeter:MSG("Settings Soon")
	ThreatMeter:MSG("/tm mm - toggles minimap")
end

function ThreatMeter:ToggleFrame()
	if self.frame then
		ThreatMeter:SetValue("lockedText", not ThreatMeter:GetValue("lockedText", true))

		if ThreatMeter:GetValue("lockedText", true) then
			self.frame:SetMovable(false)
			ThreatMeter:MSG("Text is now locked.")
		else
			self.frame:SetMovable(true)
			ThreatMeter:MSG("Text is now unlocked.")
		end
	else
		C_Timer.After(1, function()
			ThreatMeter:ToggleFrame()
		end)
	end
end

function ThreatMeter:SetPositon(x, y)
	if self.frame then
		self.frame:SetPoint("CENTER", UIParent, "CENTER", x, y)
	else
		C_Timer.After(1, function()
			ThreatMeter:SetPositon(x, y)
		end)
	end
end

frame:SetScript("OnEvent", function(self, event, ...)
	if event == "PLAYER_LOGIN" then
		TMTAB = TMTAB or {}
		ThreatMeter:SetDBTable("TMTAB")

		ThreatMeter:AddSlash("tm", function()
			ThreatMeter:ToggleSettings()
		end)

		ThreatMeter:AddSlash("threatmeter", function()
			ThreatMeter:ToggleSettings()
		end)

		ThreatMeter:AddSlash("tm mm", function()
			ThreatMeter:SetValue("showMMBtn", not ThreatMeter:GetValue("showMMBtn", true))

			if ThreatMeter:GetValue("showMMBtn", true) then
				ThreatMeter:ShowMMBtn()
			else
				ThreatMeter:HideMMBtn()
			end
		end)

		ThreatMeter:CreateMinimapButton(TMTAB, "ThreatMeterMMBTN", 132117, {"ThreatMeter", "Leftclick - Open Settings (Soon)", "Rightclick - Unlock/lock Text", "Shift + Rightclick - Hide Minimap Icon"}, function()
			ThreatMeter:ToggleSettings()
		end, function()
			ThreatMeter:ToggleFrame()
		end, function() end, function()
			ThreatMeter:SetValue("showMMBtn", false)
		end)

		--ThreatMeter:SetValue("showMMBtn", false)
		if ThreatMeter:GetValue("showMMBtn", true) then
			ThreatMeter:ShowMMBtn()
		else
			ThreatMeter:HideMMBtn()
		end
	end
end)