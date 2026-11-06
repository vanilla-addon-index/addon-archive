
local dbg = ChatFrame7;
HordeIronfoe = AceLibrary("AceAddon-2.0"):new("AceEvent-2.0", "AceDebug-2.0", "AceModuleCore-2.0", "AceConsole-2.0", "AceDB-2.0", "AceHook-2.1")
-- Utility variables

IronfoeSpeech = {}
IronfoeChannel = {}
IronfoeChannelIndex = {}
LastSpeech = ""


-- Start register event



local HordeIronfoe_Loaded = false;

function HordeIronfoe_OnLoad()
	if HordeIronfoe_Loaded == false then
		HordeIronfoe:RegisterEvent("ADDON_LOADED");
	end
end


function HordeIronfoe:ADDON_LOADED()
	if(HordeIronfoe_Loaded == false) then
		dbg:AddMessage("HordeIronfoe loaded")
		HordeIronfoe_Loaded = true;
		
		
		dbg:AddMessage("Registering events");
		HordeIronfoe:RegisterEvent("CHAT_MSG_CHANNEL")
		HordeIronfoe:RegisterEvent("COMBAT_TEXT_UPDATE")
		
		HordeIronfoe:RegisterEvent("CHAT_MSG_RAID")
		HordeIronfoe:RegisterEvent("CHAT_MSG_PARTY")
		HordeIronfoe:RegisterEvent("CHAT_MSG_SAY")
		HordeIronfoe:RegisterEvent("CHAT_MSG_YELL")
		
		
		dbg:AddMessage("HordeIronfoe events registered")
		
	end
end

-- Hook for all IF related chat
function HordeIronfoe_catchIfSpeech(chat, sender, lang, channel, channelname)
	if sender == UnitName("player") then
		if lang == "Dwarvish" then -- change to dwarvish
			IronfoeSpeech[getn(IronfoeSpeech) + 1] = LastSpeech
			IronfoeChannel[getn(IronfoeChannel) + 1] = channel
			IronfoeChannelIndex[getn(IronfoeChannelIndex) + 1] = channelname
			dbg:AddMessage("Size: "..getn(IronfoeSpeech))
			LastSpeech = ""
			return true
		end
	end
end

-- Event catch for ALL chat messages
function HordeIronfoe:CHAT_MSG_SAY(chat, sender, lang)
	if HordeIronfoe_catchIfSpeech(chat,sender,lang,"SAY","") then
		dbg:AddMessage("Say Message Received: "..chat)
	end
end

function HordeIronfoe:CHAT_MSG_YELL(chat, sender, lang)
	if HordeIronfoe_catchIfSpeech(chat,sender,lang,"YELL","") then
		dbg:AddMessage("Yell Message Received: "..chat)
	end
end

function HordeIronfoe:CHAT_MSG_PARTY(chat, sender, lang)
	if HordeIronfoe_catchIfSpeech(chat,sender,lang,"PARTY","") then
		dbg:AddMessage("Party Message Received: "..chat)
	end
end

function HordeIronfoe:CHAT_MSG_RAID(chat, sender, lang)
	if HordeIronfoe_catchIfSpeech(chat,sender,lang,"RAID","") then
		dbg:AddMessage("Raid Message Received: "..chat)
	end
end

-- Event catch for all chat messages
function HordeIronfoe:CHAT_MSG_CHANNEL(chat, sender, lang, channel, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12)
	--Respond using chat channel
	if HordeIronfoe_catchIfSpeech(chat,sender,lang,"CHANNEL",channel) then
		dbg:AddMessage("Channel Message Received: "..channel)
	end
end

function HordeIronfoe:COMBAT_TEXT_UPDATE(arg1,arg2,arg3)
	if not arg1 then
		arg1 = "";
	end
	if not arg2 then
		arg2 = ""
	end
	if not arg3 then
		arg3 = ""
	end
	
	if arg2 == "Fury of Forgewright" then
		if arg1 == "AURA_START" then
			ChatFrameEditBox:SetScript("OnEnterPressed", function(self)
				LastSpeech = ChatFrameEditBox:GetText()
				dbg:AddMessage("Sending Chat: "..LastSpeech)
				ChatEdit_OnEnterPressed()
			end);
		end
		if arg1 == "AURA_END" then
			dbg:AddMessage("Combat Text Update: "..arg1.." "..arg2.." "..arg3)
			
			ChatFrameEditBox:SetScript("OnEnterPressed", function(self)
				ChatEdit_OnEnterPressed()
			end);
			
			for i=1,getn(IronfoeSpeech) do
				if IronfoeChannel[i] == "CHANNEL" then
					dbg:AddMessage("Channel: "..IronfoeSpeech[i].." on "..IronfoeChannel[i].." index "..IronfoeChannelIndex[i])
					SendChatMessage("Ironfoe: "..IronfoeSpeech[i],IronfoeChannel[i],nil,IronfoeChannelIndex[i])
				else
					SendChatMessage("Ironfoe: "..IronfoeSpeech[i],IronfoeChannel[i],nil,nil)
					dbg:AddMessage("Non Channel: "..IronfoeSpeech[i].." on "..IronfoeChannel[i])
				end
			end
			table.setn(IronfoeSpeech,0)
			table.setn(IronfoeChannel,0)
			table.setn(IronfoeChannelIndex,0)
			IronfoeSpeech = {}
			IronfoeChannel = {}
			IronfoeChannelIndex = {}
			dbg:AddMessage("Reset indecies")
		end	
	end
end
-- End register event

HordeIronfoe_OnLoad();