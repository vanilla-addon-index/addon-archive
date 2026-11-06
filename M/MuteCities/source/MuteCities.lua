local MuteCities = CreateFrame("Frame")
if not OLDMusicVolume then OLDMusicVolume = GetCVar("MusicVolume") end

MuteCities:RegisterEvent("ZONE_CHANGED_NEW_AREA")
MuteCities:RegisterEvent("VARIABLES_LOADED")

MuteCities:SetScript("OnEvent", function()
	if event == "ZONE_CHANGED_NEW_AREA" or event == "VARIABLES_LOADED" then
	
		local CurrentZone = GetZoneText();
		if CurrentZone == "Stormwind City" or CurrentZone == "Orgrimmar" then
			if GetCVar("EnableMusic") ~= 0 then
				SetCVar("EnableMusic", 0)
			end
		else
			SetCVar("EnableMusic", 1)
		end
	end
end)
