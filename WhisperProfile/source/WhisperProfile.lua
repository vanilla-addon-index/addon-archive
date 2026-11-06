local _G = getfenv(0);
local numAllFriends = 0;
local numNewFriends = 0;
local namesFriends = {};
local nameNewAdded = "";
local timeNewWhisper = 0;
local timeWhisperThreshold = 3600;
local Whisperers = {};
local FriendsToRemove = {};
local CLASS_COLORS = {
	Druid = {
		r = 1,
		g = 0.49,
		b = 0.04
	},
	Hunter = {
		r = 0.67,
		g = 0.83,
		b = 0.45
	},
	Mage = {
		r = 0.25,
		g = 0.78,
		b = 0.92
	},
	Paladin = {
		r = 0.96,
		g = 0.55,
		b = 0.73
	},
	Priest = {
		r = 1,
		g = 1,
		b = 1
	},
	Rogue = {
		r = 1,
		g = 0.96,
		b = 0.41
	},
	Shaman = {
		r = 0,
		g = 0.44,
		b = 0.87
	},
	Warlock = {
		r = 0.53,
		g = 0.53,
		b = 0.93
	},
	Warrior = {
		r = 0.78,
		g = 0.61,
		b = 0.43
	}
};
local WPFrame = CreateFrame("Frame", "WhisperProfileFrame", WorldFrame);
WPFrame:RegisterEvent("VARIABLES_LOADED");
WPFrame:RegisterEvent("CHAT_MSG_WHISPER");
WPFrame:RegisterEvent("FRIENDLIST_UPDATE");
local function Print(msg)
	if not DEFAULT_CHAT_FRAME then
		return;
	end;
	DEFAULT_CHAT_FRAME:AddMessage(msg);
end;
local function GetClassColor(class)
	local color = CLASS_COLORS[class];
	if color then
		return color.r, color.g, color.b;
	else
		return 1, 1, 1;
	end;
end;
local function UpdateFriendsList()
	Print("UpdateFriendsList() +1 ");
	if not WP_NAMES_FRIENDS then
		WP_NAMES_FRIENDS = {};
	end;
	local tempNumFriends = GetNumFriends();
	if tempNumFriends ~= table.getn(WP_NAMES_FRIENDS) then
		local tempNamesFriends = {};
		for i = 1, tempNumFriends do
			local name, level, class, area, connected, status, note = GetFriendInfo(i);
			if name then
				table.insert(tempNamesFriends, name);
			end;
		end;
		WP_NAMES_FRIENDS = tempNamesFriends;
	end;
end;
local function WhenFriendChanged()
	local temp1 = table.getn(FriendsToRemove);
	local temp2 = table.getn(WP_NAMES_FRIENDS);
	local temp3 = GetNumFriends();
	if temp1 == 0 and temp2 ~= temp3 then
		UpdateFriendsList();
		return;
	end;
	for i = 1, 50 do
		local name, level, class, area, connected, status, note = GetFriendInfo(i);
		if level ~= 0 and nameNewAdded ~= "" and name then
			if nameNewAdded == name then
				local r, g, b = GetClassColor(class);
				local hexColor = string.format("|cFF%02X%02X%02X", r * 255, g * 255, b * 255);
				local msg = name .. "-" .. level .. "-" .. class .. "-" .. area;
				print(hexColor .. msg);
				break;
			end;
		else
			break;
		end;
	end;
	while table.getn(FriendsToRemove) > 0 do
		local removedElement = table.remove(FriendsToRemove);
		RemoveFriend(removedElement);
	end;
	nameNewAdded = "";
end;
local function OnEventFunc()
	if event == "VARIABLES_LOADED" then
		UpdateFriendsList();
	elseif event == "CHAT_MSG_WHISPER" then
		if arg2 then
			timeNewWhisper = GetTime();
			for index, name in ipairs(WP_NAMES_FRIENDS) do
				if arg2 == name then
					return;
				end;
			end;
			if Whisperers[arg2] then
				local tempTimeDiff1 = timeNewWhisper - Whisperers[arg2];
				Whisperers[arg2] = timeNewWhisper;
				if tempTimeDiff1 < timeWhisperThreshold then
					return;
				end;
			end;
			Whisperers[arg2] = timeNewWhisper;
			nameNewAdded = arg2;
			AddFriend(nameNewAdded);
			table.insert(FriendsToRemove, nameNewAdded);
		end;
	elseif event == "FRIENDLIST_UPDATE" then
		WhenFriendChanged();
	end;
end;
WPFrame:SetScript("OnEvent", OnEventFunc);
SLASH_WhisperProfile1 = "/wp";
SlashCmdList.WhisperProfile = function(msg)
	local commandlist = {};
	for command in string.gmatch(msg, "[^ ]+") do
		table.insert(commandlist, string.lower(command));
	end;
	local action = commandlist[1];
	if action == "about" then
		Print("You are running WhisperProfile Ver 0.01");
	end;
end;
