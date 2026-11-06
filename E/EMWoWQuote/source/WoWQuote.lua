-- Misc. Constants
WQ_MOD_NAME = "WoWQuote";
WQ_VERSION = "0.8.5";
WQ_MEDIA_PATH = "Interface\\AddOns\\"..WQ_MOD_NAME.."\\media\\";
WQ_DEFAULT_MEDIA_TYPE = ".mp3";
WQ_MIN_SOUND_DELAY = 3;
WQ_MAX_ALIAS_LEN = 20;
WQ_MIN_SEARCH_LEN = 3;

-- Private Vars
local playerName = UnitName("player");

-- Public Vars
WQSoundTimer = time();

-- Variables to save
WQ_SETTINGS = {};
WQ_SETTINGS.broadcast = {
        ["CHAT_MSG_SAY"] = true,
        ["CHAT_MSG_PARTY"] = true,
        ["CHAT_MSG_RAID"] = true,
        ["CHAT_MSG_RAID_LEADER"] = true,
        ["CHAT_MSG_GUILD"] = true,
        ["CHAT_MSG_OFFICER"] = true
    };
WQ_SETTINGS.aliases = {};

function WQ_Init()
    WQ_Print(string.format(WQ_MSG["msg_loaded"],WQ_MOD_NAME,WQ_VERSION)); 

    SlashCmdList["WQ"] = WQ_ShowUI;
    SLASH_WQ1 = "/wq";

    SlashCmdList["WQHELP"] = WQ_Help;
    SLASH_WQHELP1 = "/wqh";
    SLASH_WQHELP2 = "/wqh";

    SlashCmdList["WQBROADCAST"] = WQ_SetChannel;
    SLASH_WQBROADCAST1 = "/wqb";
    SLASH_WQBROADCAST2 = "/wqbroadcast";

    SlashCmdList["WQSAY"] = WQ_Say;
    SLASH_WQSAY1 = "/wqs";
    SLASH_WQSAY2 = "/wqsay";

    SlashCmdList["WQPARTY"] = WQ_Party;
    SLASH_WQPARTY1 = "/wqp";
    SLASH_WQPARTY2 = "/wqparty";

    SlashCmdList["WQRAID"] = WQ_Raid;
    SLASH_WQRAID1 = "/wqr";
    SLASH_WQRAID2 = "/wqraid";

    SlashCmdList["WQGUILD"] = WQ_Guild;
    SLASH_WQGUILD1 = "/wqg";
    SLASH_WQGUILD2 = "/wqguild";

    SlashCmdList["WQOFFICER"] = WQ_Officer;
    SLASH_WQOFFICER1 = "/wqo";
    SLASH_WQOFFICER2 = "/wqofficer";

    SlashCmdList["WQLIST"] = WQ_List;
    SLASH_WQLIST1 = "/wql";
    SLASH_WQLIST2 = "/wqlist";

    SlashCmdList["WQCATEGORY"] = WQ_CatList;
    SLASH_WQCATEGORY1 = "/wqc";
    SLASH_WQCATEGORY2 = "/wqcategory";

    SlashCmdList["WQALIAS"] = WQ_Alias;
    SLASH_WQALIAS1 = "/wqa";
    SLASH_WQALIAS2 = "/wqalias";

    SlashCmdList["WQFIND"] = WQ_Find;
    SLASH_WQFIND1 = "/wqf";
    SLASH_WQFIND2 = "/wqfind";

    WQ_HandleSettings();
end

function WQ_MsgSort(a,b)
	return WQmedia[a].msg < WQmedia[b].msg;
end

function WQ_IndexByMsg(category)
	local indexlist = {};
	local nr = {};
	for k,v in pairs(WQmedia) do
		if (v.cat == category) then
			table.insert(indexlist,k);
		end
	end
	table.sort(indexlist,WQ_MsgSort);
	return indexlist;
end

function WQ_HandleSettings()
	if (WQ_SETTINGS.broadcast["CHAT_MSG_RAID"] == true) then
		WQ_SETTINGS.broadcast["CHAT_MSG_RAID_LEADER"] = true;
	else
		WQ_SETTINGS.broadcast["CHAT_MSG_RAID_LEADER"] = false;
	end
    for k,v in pairs(WQ_SETTINGS.broadcast) do
        if v == true then
            WQ:RegisterEvent(k);
        else
            WQ:UnregisterEvent(k);
        end
    end
end

function WQ_OnEvent(event, arg1, arg2, arg3)
    if (event == "ADDON_LOADED" and arg1 == WQ_MOD_NAME) then
        WQ_Init();
    end
    if (arg1~=nil and arg2~=nil and arg2~=playerName) then
        local i,v = WQ_CatchMedia(event,arg1);
        if ( i ~= nil and type(v)=="table" ) then
            WQ_Play(i);
        end
    end
end

function WQ_SetChannel(cmd)
    if (tostring(cmd) == "") then
        WQ_Print(string.format(WQ_MSG["msg_conf_title"],WQ_MOD_NAME));
        WQ_PrintTable(WQ_ShowSettings("broadcast"),true);
        return;
    end
    local arg1,arg2 = WQ_GetCmd(cmd);
    local chan = string.find(arg1,"[sprgo]");
    if (chan == nil) then
		WQ_Msg("err_miss_channel");
        return;
    end
    if (strlower(tostring(arg2))~="on" and strlower(tostring(arg2))~="off") then
        WQ_Msg("err_miss_switch");
        return;
    end
    if (arg2=="off") then
        WQ_SETTINGS.broadcast[WQChannels[arg1].event] = false;
		WQ_Msg("msg_chan_off",WQChannels[arg1].name);
        WQ:UnregisterEvent(WQChannels[arg1].event);
		if (arg1 == "r") then
			WQ_SETTINGS.broadcast["CHAT_MSG_RAID_LEADER"] = false;
        	WQ:UnregisterEvent("CHAT_MSG_RAID_LEADER");
		end
    else
        WQ_SETTINGS.broadcast[WQChannels[arg1].event] = true;
		WQ_Msg("msg_chan_on",WQChannels[arg1].name);
		if (arg1 == "r") then
			WQ_SETTINGS.broadcast["CHAT_MSG_RAID_LEADER"] = true;
        	WQ:RegisterEvent("CHAT_MSG_RAID_LEADER");
		end
        WQ:RegisterEvent(WQChannels[arg1].event);
    end
end

function WQ_ShowSettings(s)
    local tab = {};
    if (s == "broadcast") then
        local chans = {"s","p","r","g","o"};
        local sw;
        for k,v in pairs(chans) do
            if (WQ_SETTINGS.broadcast[WQChannels[v]["event"]] == true) then
                sw = "on";
            else
                sw = "off";
            end
            tab[WQChannels[v]["name"]] = sw;
        end
    end
    return tab;
end

function WQ_CatchMedia(event,str)
    local pattern = WQ_get_pattern(str,"%(~[%w]*~%)");     
    if pattern ~= nil then
        return WQ_GetMedia(pattern);
    end
    return nil;
end

function WQ_get_pattern(text,pattern)
    local i, j = string.find(text,pattern);
    if (i~=nil and j~=nil) then
        local s = string.sub(text,i,j);
        return string.gsub(s,"[~%(%)]","");
    else
        return nil;
    end    
end

function WQ_GetMedia(key)
    if ( type(WQmedia[tonumber(key)]) == "table" ) then
        return tonumber(key),WQmedia[tonumber(key)];
    end
    for i,v in pairs(WQmedia) do
        if (v.id == key) then
            return i,v;
        end
    end
    return nil,nil;
end

function WQ_Play(id)
    local delay = WQ_MIN_SOUND_DELAY;
    if (type(WQmedia[id].len)=="number") then 
        delay = WQmedia[id].len;
    end       
    if (time() >= WQSoundTimer) then
    	WQSoundTimer = time()+delay;
        local file = WQ_MEDIA_PATH .. WQmedia[id].file;
        PlaySoundFile(file);
    end
end

function WQ_Send(id,system)
	local i;
    if (id == nil or WQ_trim(id) == "" ) then
        return;
    end
    i = WQ_GetIDbyAlias(id);
    if (i == nil) then
    	i = (WQ_GetMedia(id));
	end;
    if (i == nil) then
        WQ_NotFound(id);
        return;
    end 
    local msg = "[ " .. WQmedia[i].msg .. " ] (~" .. i .. "~)";
    SendChatMessage(msg,system);
    WQ_Play(i);
end

function WQ_Say(id) WQ_Send(id,"SAY"); end
function WQ_Guild(id) WQ_Send(id,"GUILD"); end
function WQ_Officer(id) WQ_Send(id,"OFFICER"); end
function WQ_Party(id) WQ_Send(id,"PARTY"); end
function WQ_Raid(id) WQ_Send(id,"RAID"); end

function WQ_NotFound(id)
    WQ_Msg("err_quote_not_found",id);
    PlaySound("TellMessage");
end

function WQ_Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(msg,0.5,0.5,0.9);
end

function WQ_Msg(msg,p1,p2,p3)
	WQ_Print(WQ_MOD_NAME .. ": " .. string.format(WQ_MSG[msg],p1,p2,p3));
end

function WQ_Find(str)
    if str ~= nil then
    	str = WQ_trim(string.lower(str));
    end;
    if string.len(str) < WQ_MIN_SEARCH_LEN then
    	WQ_Msg("err_search_len",WQ_MIN_SEARCH_LEN);
    	return;
    end;
    local found=0;
    for k,v in pairs(WQcategories) do
    	found = found + WQ_List(k,str);
    end;
	WQ_Msg("msg_search_count",found);
end;

function WQ_Alias(cmd)
    local id,alias = WQ_GetCmd(cmd);
	if (id == nil or WQ_trim(id) == "") then
		WQ_Msg("err_no_alias_id");
		return;
	end
    local i = (WQ_GetMedia(id));
    if (i == nil) then
        WQ_NotFound(id);
        return;
    end 
    if (alias == nil or WQ_trim(alias) == "") then
    	if (type(WQ_SETTINGS.aliases[i])=="string") then
    		WQ_SETTINGS.aliases[i] = nil;
    		WQ_Msg("msg_alias_disabled",id);
		else
    		WQ_Msg("err_alias_not_found",id);
    	end;
    	return;
    end 
	if alias ~= nil and alias ~= "" and string.len(alias)<WQ_MAX_ALIAS_LEN and string.find(alias,'^[%a]+[%w]*$') ~= nil then
		alias = string.lower(alias);
		WQ_SETTINGS.aliases[i] = alias;
		WQ_Msg("msg_alias_set",id,alias);
		return;
 	else
 		WQ_Msg("err_wrong_alias");
	end
end

function WQ_GetIDbyAlias(alias)
	for k,v in pairs(WQ_SETTINGS.aliases) do
		if (v == alias) then
			return k;
		end;
	end;
	return nil;
end

function WQ_Help()
    WQ_PrintTable(WQ_HELP);
end

function WQ_PrintTable(t,show)
    for i,v in pairs(t) do
        local msg = "|cff7090ff" .. v;
        if (show) then
            msg = "|cffffffff" .. i .. " : " .. msg;
        end
        DEFAULT_CHAT_FRAME:AddMessage(msg,0.5,0.5,0.9);
    end
end

function WQ_CatList()
	WQ_Print(string.format(WQ_MSG["msg_cat_title"],WQ_MOD_NAME));
    WQ_PrintTable(WQcategories,true);
end

function WQ_List(cmd,search)
    local cat = tonumber(cmd);
    local alias = "";
    local found = 0;
    if (WQcategories[cat] == nil) then
        WQ_Msg("err_cat_id");
        return;
    end
	if (search == nil) then
    	WQ_Print(string.format(WQ_MSG["msg_qlist_title"],WQ_MOD_NAME,WQcategories[cat]));
	end;
    for k,v in pairs(WQ_IndexByMsg(cat)) do
    	if (type(WQ_SETTINGS.aliases[v])=="string") then
    		alias = ", " .. WQ_SETTINGS.aliases[v] .. " ";
		else
			alias = "";
    	end;
    	if (search ~= nil) then
    		local f = (string.find(string.lower(WQmedia[v].msg), search));
    		if f ~= nil then
				DEFAULT_CHAT_FRAME:AddMessage("|cffffffff" .. WQmedia[v].id .. alias .. " : |cff7090ff" .. WQmedia[v].msg,0.5,0.5,0.9);
    			found = found + 1;
    		end;
		else
			DEFAULT_CHAT_FRAME:AddMessage("|cffffffff" .. WQmedia[v].id .. alias .. " : |cff7090ff" .. WQmedia[v].msg,0.5,0.5,0.9);
    	end;
    end
	return found;
end

function WQ_GetCmd(msg)
 	if (msg) then
 		local a,b=string.find(msg, "[^%s]+");
 		if (not ((a==nil) and (b==nil))) then
 			local cmd=string.lower(string.sub(msg,a,b));
 			return cmd, string.sub(msg,string.find(cmd,"$")+1);
 		else	
 			return "";
 		end;
 	end;
 end;
 
 function WQ_GetArgument(msg)
 	if (msg) then
 		local a,b=string.find(msg, "[^=]+");
 		if (not ((a==nil) and (b==nil))) then
 			local cmd=string.lower(string.sub(msg,a,b)); 
 			return cmd, string.sub(msg, string.find(cmd,"$")+1);
 		else	
 			return "";
 		end;
 	end;
 end;
 
function WQ_trim(s)
	return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

function WQ_ShowUI()
	WQUI:Toggle();
end
