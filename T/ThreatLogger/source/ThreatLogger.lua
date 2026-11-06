local _G, _ = _G or getfenv();
local __lower = string.lower;
local __repeat = string.rep;
local __strlen = string.len;
local __find = string.find;
local __substr = string.sub;
local __parseint = tonumber;
local __parsestring = tostring;
local __getn = table.getn;
local __tinsert = table.insert;
local __tsort = table.sort;
local __pairs = pairs;
local __floor = math.floor;
local __abs = abs;
local __char = string.char;
local versionTWT = 'TWTv4=';
local namePlayer = nil;
local flagCombat = false;
local flagSelfName = false;
local textLogs = {};
local threatPrev = 0;
local threatGap = 0;
local eventlist1 = {
	"ADDON_LOADED",
	"PLAYER_REGEN_DISABLED",
	"PLAYER_REGEN_ENABLED",
	"PLAYER_TARGET_CHANGED",
	"PLAYER_ENTERING_WORLD",
	"PARTY_MEMBERS_CHANGED"
};
local eventlist2 = {
	--"CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS",
	--"CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES",
	--"CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS",
	--"CHAT_MSG_COMBAT_HOSTILEPLAYER_MISSES",
	--"CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE",
	"CHAT_MSG_ADDON",
	"CHAT_MSG_COMBAT_SELF_HITS",
	"CHAT_MSG_COMBAT_SELF_MISSES",
	"CHAT_MSG_SPELL_CREATURE_VS_SELF_BUFF",
	"CHAT_MSG_SPELL_DAMAGESHIELDS_ON_OTHERS",
	"CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF",
	"CHAT_MSG_SPELL_HOSTILEPLAYER_BUFF",
	"CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE",
	"CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE",
	"CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_BUFFS",
	"CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE",
	"CHAT_MSG_SPELL_PERIODIC_PARTY_BUFFS",
	"CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS",
	"CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE",
	"CHAT_MSG_SPELL_SELF_BUFF",
	"CHAT_MSG_SPELL_SELF_DAMAGE",
	"CHAT_MSG_COMBAT_HOSTILE_DEATH",
	"CHAT_MSG_COMBAT_PARTY_HITS",
	"CHAT_MSG_SPELL_AURA_GONE_PARTY",
	"CHAT_MSG_SPELL_AURA_GONE_SELF"
};
local TL = CreateFrame("Frame");

local function Print(msg)
	if not DEFAULT_CHAT_FRAME then
		return;
	end;
	DEFAULT_CHAT_FRAME:AddMessage(msg);
end;
local function PrintColor(msg)
	local r, g, b = 0.2, 0.8, 0.2;
	local hexColor = string.format("|cFF%02X%02X%02X", r * 255, g * 255, b * 255);
	Print(hexColor .. msg);
end;
local function TLRegister(events, flag)
	if flag then
		for _, event in pairs(events) do
			TL:RegisterEvent(event);
		end;
	else
		for _, event in pairs(events) do
			TL:UnregisterEvent(event);
		end;
	end;
end;

TLRegister(eventlist1, true);

local function init()
	if TL_ON == nil then
		TL_ON = true;
	end;

	if TL_PLAYER == nil then
		TL_PLAYER = UnitName('Player');
	end;

	namePlayer = TL_PLAYER

	if TL_LOGS == nil then
		TL_LOGS = {};
	end;

	if TL_ON then
		TLRegister(eventlist2, true);
	end;

	if TL_PLAYER == UnitName('Player') then
		flagSelfName = true
	else
		flagSelfName = false
	end
end;

local function SaveDataIntoFile()
	if TL_ON and textLogs ~= {} and flagCombat then
		flagCombat = false
		TL_LOGS = textLogs
		textLogs = {}
		PrintColor("\nThreat Logger v1.0")
		PrintColor("a '/reload' is required to save the data into the file:")
		Print("Twow folder/../SavedVariables/ThreatLogger.lua")
	end
end

local function __explode(str, delimiter)
    local result = {}
    local from = 1
    local delim_from, delim_to = __find(str, delimiter, from, 1, true)
    while delim_from do
        __tinsert(result, __substr(str, from, delim_from - 1))
        from = delim_to + 1
        delim_from, delim_to = __find(str, delimiter, from, true)
    end
    __tinsert(result, __substr(str, from))
    return result
end

local function TLHandleThreatPacket(packet)
		local playersString = __substr(packet, __find(packet, versionTWT) + __strlen(versionTWT), __strlen(packet))
	
		local players = __explode(playersString, ';')
	
		for _, tData in players do
	
			local msgEx = __explode(tData, ':')
			
			if msgEx[1] and msgEx[3] then
				local player = msgEx[1]
				local threat = __parseint(msgEx[3])
				if player == namePlayer then 
					threatGap = threat - threatPrev
					if threatGap > 0 then 
						Print("threat: " .. threatGap)
						Print(" ")
						table.insert(textLogs, threatGap);
					end
					threatPrev = threat
				end
			end
		end

end

local function containsWords(str, plr)
	if flagSelfName then
		if __find(str, "afflicted") or __find(str, "You") or __find(str, "you") then
			return true
		else
			return false
		end
	else
		if __find(str, plr) or __find(str, "afflicted") then
			return true
		else
			return false
		end
	end 
end

local function OnEvent()
	if event == "PLAYER_ENTERING_WORLD" then
		init()
		Print("PLAYER_ENTERING_WORLD");
	elseif event == "PLAYER_REGEN_DISABLED" then
		flagCombat = true
	elseif event == "PLAYER_REGEN_ENABLED" then
		SaveDataIntoFile()
	elseif flagCombat and event == 'CHAT_MSG_ADDON' and __find(arg2, versionTWT, 1, true) then
		TLHandleThreatPacket(arg2)
	elseif flagCombat and arg1 and containsWords(arg1, namePlayer) then
		table.insert(textLogs, arg1);
		--Print(arg1.." - "..event)
		Print(arg1)
	end;
end;
TL:SetScript("OnEvent", OnEvent);
SLASH_THREATLOGGER1 = "/tlg";
SlashCmdList.THREATLOGGER = function(msg)
	local commandlist = {};
	for command in gfind(msg, "[^ ]+") do
		table.insert(commandlist, string.lower(command));
	end;
	local action = commandlist[1];
	if action == "about" then
		Print("Threat Logger assists players in tracking the threat generated by each of their abilities. It accurately records threat by utilizing the Turtle Threat API via the 'TWThreat' addon.");
	elseif action == "on" then
		TLRegister(eventlist2, true);
		TL_ON = true;
		PrintColor("Threat Logger is Enabled.");
	elseif action == "off" then
		TLRegister(eventlist2, false);
		TL_ON = false;
		PrintColor("Threat Logger is Disabled.");
	elseif action == "save" then
		SaveDataIntoFile()
	elseif action == "name" then
		local name = commandlist[2];
		if name then
			local lowerName = string.lower(name)
			local formatedName = string.upper(string.sub(lowerName, 1, 1)) .. string.sub(lowerName, 2)

			Print("Start monitoring player: "..formatedName);

			namePlayer = formatedName
			TL_PLAYER = formatedName

			if formatedName == UnitName('Player') then
				flagSelfName = true
			else
				flagSelfName = false
			end
		else
			Print("Please input a name. Current name is: "..namePlayer);
		end
	else
		if TL_ON then
			Print("Threat Logger is now ENABLED.")
			Print("To turn it off, use '/tlg off'");
		else
			Print("Threat Logger is now DISABLE.")
			Print("To turn it on, use '/tlg on'");
		end
	end;
end;
