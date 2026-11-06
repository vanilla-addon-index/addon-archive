function CChut_OnLoad()
	this:RegisterEvent("VARIABLES_LOADED")
	this:RegisterEvent("CHAT_MSG_YELL")
	this:RegisterEvent("CHAT_MSG_CHANNEL")
	this:RegisterEvent("CHAT_MSG_WHISPER")
	this:RegisterEvent("PLAYER_LOGOUT")
	
	SLASH_CARINACHUT1 = "/chut"
	SlashCmdList["CARINACHUT"] = function(msg)
		CChut_Handler(msg)
	end

	CCHUT_COLOR_SYSTEM_MESSAGE = "|cffFF4500"
	CCHUT_BUBBLE_DISABLE = false
	CCHUT_TIMER = 0
	CCHUT_IGNORE_LIST = {}
	CCHUT_DEBUG_MODE = false
	
	CCHUT_COMS_STATE = 0
	-- 0 : Nothing to see here.
	-- 1 : Waiting for a check
	-- 2 : Checked
	
	DEFAULT_CHAT_FRAME:AddMessage(CCHUT_COLOR_SYSTEM_MESSAGE.."<CChut>|r Carina Chut loaded. Ready to shoot.") -- Annonce que le chargement de l'addon est terminé --
end

function CChut_IsABotMessage(msg)
-- Detect bot messages
	for i, filter in ipairs(CCHUT_FILTER_BANNED.list) do
		if (string.find(msg, filter) ~= nil) then
			return true
		end
	end
	
	return false
end

function CChut_OnEvent(event, arg1, arg2)
	if(event == "VARIABLES_LOADED") then
		
		if(CChut_DebugLog == nil) then
			CChut_DebugLog = {}
		end
		
	elseif (event == "CHAT_MSG_YELL" or event == "CHAT_MSG_CHANNEL" or event == "CHAT_MSG_WHISPER") then
		if (GetChannelName("CarinaAddon") == 0) then
			--DEFAULT_CHAT_FRAME:AddMessage("Bite join CarinaAddon")
			JoinChannelByName("CarinaAddon")
			AddChatWindowChannel(1, "CarinaAddon")
		elseif (CCHUT_COMS_STATE == 0 and string.find(arg1, "<CCHUT>") == nil) then
			--DEFAULT_CHAT_FRAME:AddMessage("Bite check CarinaAddon")
			CChut_CheckNewDBFilter(CCHUT_FILTER_BANNED.version)
			CCHUT_COMS_STATE = 1
		end
		
		-- Addon Coms --
		if(string.find(arg1, "<CCHUT>") ~= nil) then
			-- CheckDB
			if(string.find(arg1, "CheckNewDB") ~= nil) then
				local startIndex, endIndex, version = string.find(arg1, "CheckNewDB:(%d*)")
				local checkedVersion = tonumber(version)
				if(CCHUT_FILTER_BANNED.version > checkedVersion) then
					CChut_ConfirmNewDBFilter(arg2, CCHUT_FILTER_BANNED.version)
				end
				
			-- Received confirmation new DB
			elseif(string.find(arg1, "ConfirmNewDB") ~= nil	and CCHUT_COMS_STATE == 1) then
				local startIndex, endIndex, target = string.find(arg1, "Target:(%w*)")
				if(target == UnitName("player")) then
					local version
					startIndex, endIndex, version = string.find(arg1, "ConfirmNewDB:(%d*)")
					DEFAULT_CHAT_FRAME:AddMessage(CCHUT_COLOR_SYSTEM_MESSAGE.."<CChut>|r New filter list available, version : "..version)
					CCHUT_COMS_STATE = 2
				end
			end
			
		-- Normal messages
		else
			--DEFAULT_CHAT_FRAME:AddMessage("Yell : "..arg1)
			if (CChut_IsABotMessage(arg1)) then
				--DEFAULT_CHAT_FRAME:AddMessage(arg2.." est ignoré.")
				table.insert(CCHUT_IGNORE_LIST, arg2)
			else
				if(CCHUT_DEBUG_MODE and event == "CHAT_MSG_WHISPER") then
					table.insert(CChut_DebugLog, arg1)
				end
			end
		end
		
	elseif(event == "PLAYER_LOGOUT") then
		LeaveChannelByName("CarinaAddon")
	end
end

function CChut_OnUpdate(elapsed)
	if CCHUT_BUBBLE_DISABLE == true then
		CCHUT_BUBBLE_DISABLE = false
		SetCVar("chatBubbles", 1)
	end
end

local origAddMessage = ChatFrame1.AddMessage
function ChatFrame1.AddMessage(self, text, r, g, b, a)
-- Hide yell/emote from bots
	
	local bool = false
	
	for i, bot in ipairs(CCHUT_IGNORE_LIST) do
		if (string.find(text, bot) ~= nil) then
			bool = true
		end
	end
	
	if (CChut_IsABotMessage(text)) then
		bool = true
	end
	
	if (bool == true) then
		CCHUT_BUBBLE_DISABLE = true
		SetCVar("chatBubbles", 0)
	else
		return origAddMessage(self, text, r, g, b, a)
    end
end

function CChut_CheckNewDBFilter(version)
	id, name = GetChannelName("CarinaAddon")
	--DEFAULT_CHAT_FRAME:AddMessage("Bite test version = "..version)
	SendChatMessage("<CCHUT> CheckNewDB:"..version, "CHANNEL", nil, id)
end

function CChut_ConfirmNewDBFilter(target, version)
	id, name = GetChannelName("CarinaAddon")
	SendChatMessage("<CCHUT> ConfirmNewDB:"..version.. " Target:"..target, "CHANNEL", nil, id)
end

function CChut_Handler(msg)
-- Commands /chut --
	
	if (msg == "help") then
	
		DEFAULT_CHAT_FRAME:AddMessage(CCHUT_COLOR_SYSTEM_MESSAGE.."<CChut>|r I can't help you !")
		
	elseif (msg == "debug") then
	
		CCHUT_DEBUG_MODE = not CCHUT_DEBUG_MODE
		if (CCHUT_DEBUG_MODE) then
			DEFAULT_CHAT_FRAME:AddMessage(CCHUT_COLOR_SYSTEM_MESSAGE.."<CChut>|r Debug mode activé !")
		else
			DEFAULT_CHAT_FRAME:AddMessage(CCHUT_COLOR_SYSTEM_MESSAGE.."<CChut>|r Debug mode désactivé !")
		end
	
	elseif (msg == "" or msg == nil) then
		
		DEFAULT_CHAT_FRAME:AddMessage("###############################")
		DEFAULT_CHAT_FRAME:AddMessage("## Commandes |cffff0000/chut|r :")
		DEFAULT_CHAT_FRAME:AddMessage("# |cffff0000info |r: |cff00E5EEGive addon infos.|r")
		
	elseif (msg == "info") then
		
		DEFAULT_CHAT_FRAME:AddMessage("#######################")
		DEFAULT_CHAT_FRAME:AddMessage("###      |cffFF6500Carina Chut|r        ###")
		DEFAULT_CHAT_FRAME:AddMessage("###    |cffff0000Version |r: |cff00E5EE0.0.5|r      ###")
		DEFAULT_CHAT_FRAME:AddMessage("###    |cffff0000Auteurs |r: |cff00E5EEAlizia|r     ###")
		DEFAULT_CHAT_FRAME:AddMessage("#######################")
	end
end