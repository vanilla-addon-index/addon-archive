function EPGPexport_OnLoad()
	SLASH_EPGPEXPORT1 = "/epgpexport" 
	SLASH_EPGPEXPORT2 = "/epgpex" 
	SlashCmdList["EPGPEXPORT"] = EPGPexport_exportData
end

function EPGPexport_exportData()
	EPGPexportData = {}	
	EPGPexportDataDB  = {}	
	epgpextract = "^(%d+)/(%d+)"

	for i = 1, GetNumGuildMembers(true) do
		local name, _, _, _, class, _, _, officernote, _, _ = GetGuildRosterInfo(i)
		local _, _, ep, gp = string.find(officernote, epgpextract)
		ratio = ep / gp
		EPGPexportData[name] = "EP: " .. ep.. " - GP: " .. gp .. " - Ratio: " .. ratio
		
		EPGPexportDataDB[i] = {}	
		EPGPexportDataDB[i].name = name
		EPGPexportDataDB[i].ep = ep
		EPGPexportDataDB[i].gp = gp
		EPGPexportDataDB[i].ratio = ratio
	end
	
	guild = GetGuildInfo("player")
	EPGPexportDataFrame = "EPGP export for " .. guild .. " at " .. date("%y-%m-%d %H:%M:%S") .. "\r\n"  .. "\r\n"
	
	for i in EPGPexportDataDB do
		EPGPexportDataFrame = EPGPexportDataFrame .. EPGPexportDataDB[i].name .. ": " .. EPGPexportDataDB[i].ep .. "/" .. EPGPexportDataDB[i].gp .. " - " .. EPGPexportDataDB[i].ratio .. "\r\n"
	end
	
	EPGPexport_ExportRaidFrameEditBox1:SetFont("Fonts\\FRIZQT__.TTF", "8")
	EPGPexport_ExportRaidFrameEditBox1Left:Hide()
	EPGPexport_ExportRaidFrameEditBox1Middle:Hide()
	EPGPexport_ExportRaidFrameEditBox1Right:Hide()
	EPGPexport_ExportRaidFrameEditBox1:SetText(EPGPexportDataFrame)
		
	ShowUIPanel(EPGPexport_ExportRaidFrame, 1)
	
	DEFAULT_CHAT_FRAME:AddMessage("EP GP exported to WTF\\Account\\ACCOUNTNAME\\SavedVariables\\EPGPexportData.lua", 1, 1, 0)
	DEFAULT_CHAT_FRAME:AddMessage("Reload UI or Logout to save the file", 1, 1, 0)
end
