local MAX_ENTRIES = 40;
local MAX_ENTRIES_SHOWN = 20;
-- Raid Roster: table of raid players:		{ Name, DKP, Class, Rank, Online }
local DKPList_RaidRosterTable			= { }
-- Guild Roster: table of guild players:	{ Name, DKP, Class, Rank, Online, Zone }
local DKPList_GuildRosterTable			= { }
local DKPList_CheckForInRaid = 0;
local DKPList_ScrollCounter = 0;
local DKPList_AllianceMode = 0;

local CLASS_COLORS = {
	{ "Druid",			{ 255,125, 10 } },	--255 	125 	10		1.00 	0.49 	0.04 	#FF7D0A
	{ "Hunter",			{ 171,212,115 } },	--171 	212 	115 	0.67 	0.83 	0.45 	#ABD473 
	{ "Mage",			{ 105,204,240 } },	--105 	204 	240 	0.41 	0.80 	0.94 	#69CCF0 
	{ "Paladin",		{ 245,140,186 } },	--245 	140 	186 	0.96 	0.55 	0.73 	#F58CBA
	{ "Priest",			{ 255,255,255 } },	--255 	255 	255 	1.00 	1.00 	1.00 	#FFFFFF
	{ "Rogue",			{ 255,245,105 } },	--255 	245 	105 	1.00 	0.96 	0.41 	#FFF569
	{ "Shaman",			{   0,112,222 } },	--0 	112 	222 	0.00 	0.44 	0.87 	#0070DE
	{ "Warlock",		{ 148,130,201 } },	--148 	130 	201 	0.58 	0.51 	0.79 	#9482C9
	{ "Warrior",		{ 199,156,110 } }	--199 	156 	110 	0.78 	0.61 	0.43 	#C79C6E
}

local CLASS_FILTER = {
	{ "Druid",		1},
	{ "Hunter",		1},
	{ "Mage",		1},
	{ "Paladin",	1},
	{ "Priest",		1},
	{ "Rogue",		1},
	{ "Shaman",		1},
	{ "Warlock",	1},
	{ "Warrior",	1},
}

function DKPList_OnLoad()
	--message("DKPList Version 0.1");
	this:RegisterEvent("ADDON_LOADED");
    this:RegisterEvent("GUILD_ROSTER_UPDATE");
	this:RegisterEvent("RAID_ROSTER_UPDATE");
	this:RegisterEvent("PLAYER_ENTERING_WORLD");
	DKPList_RefreshRoster();
	DKPList_InitializeTableElements();
	DKPList_MinimapButtonFrame:Show();
end

function SOTA_OnEvent(event, arg1, arg2, arg3, arg4, arg5)
	if (event == "GUILD_ROSTER_UPDATE") then
		DKPList_RefreshRoster()
		DKPList_UpdateDKPElements()
    end
end

function DKPList_OnClickMinimapButton()
	DKPListUIFrame:Show();
	DKPList_ShowClassButtons();
    DKPList_RefreshRoster();
	DKPList_ScrollBarUpdate();
end

--
--	Guild and Raid Roster Event Handling
--
--	RaidRoster will update internal raid roster table.
--	GuildRoster will update guild roster table
--

--[[
	Update the guild roster status cache: members and DKP.
	Used to display DKP values for non-raiding members
]]
function DKPList_RefreshGuildRoster()
	DKPList_GuildRosterTable = { }

	local memberCount = GetNumGuildMembers();
	local note
	for n=1,memberCount,1 do
		local name, rank, _, _, class, zone, publicnote, officernote, online = GetGuildRosterInfo(n)
		local skip = 0;

		for m=1,getn(CLASS_FILTER),1 do
			if class == CLASS_FILTER[m][1] and CLASS_FILTER[m][2] == 0 then
				skip = 1;
			end
		end

		if not zone then
			zone = "";
		end

		note = publicnote

		if not note or note == "" then
			note = "<0>";
		end
		
		if not online then
			online = 0;
		end
		
		local _, _, dkp = string.find(note, "<(-?%d*)>")
		if not dkp then
			dkp = 0;
		end

		if skip == 1 then
			name = "";
			rank = "";
			class = "";
			publicnote = "";
			dkp = "";
		else
			DKPList_GuildRosterTable[getn(DKPList_GuildRosterTable) + 1] = { name, (1*dkp), class, rank, online, zone }
		end
	end
	table.sort(DKPList_GuildRosterTable, DKPList_compare);
end

--[[
--	Return raid info for specific player.
--	{ Name, DKP, Class, Rank, Online }
--]]
function DKPList_GetRaidInfoForPlayer(playername)
	if DKPList_IsInRaid(true) and playername then
		playername = SOTA_UCFirst(playername);
		
		local raid = DKPList_GetRaidRoster();		
		for n=1, table.getn(raid), 1 do
			if raid[n][1] == playername then
				return raid[n];
			end			
		end	
	end
	return nil;
end

--[[
	Re-read the raid status and namely the DKP values.
	Should be called after each roster update.
]]
function DKPList_RefreshRaidRoster()
	local playerCount = GetNumRaidMembers()
	
	if playerCount then
		DKPList_RaidRosterTable = { }
		local index = 1
		local memberCount = table.getn(DKPList_GuildRosterTable);
		for n=1,playerCount,1 do
			local name, _, _, _, class = GetRaidRosterInfo(n);

			for m=1,memberCount,1 do
				local info = DKPList_GuildRosterTable[m]
				if name == info[1] then
					DKPList_RaidRosterTable[index] = info;
					index = index + 1
				end
			end
		end
	end
	table.sort(DKPList_RaidRosterTable, DKPList_compare);
end

--	Show top <n> in DKP window
function DKPList_UpdateDKPElements()
	local name, dkp, playerclass, rank, numnber;
	local dkplist = {}

	if DKPList_CheckForInRaid == 0 then dkplist = DKPList_GuildRosterTable
	else dkplist = DKPList_RaidRosterTable end

	for n=1, MAX_ENTRIES_SHOWN, 1 do
		if table.getn(dkplist) < n then
			name = "";
			dkp = "";
			bidcolor = { 64, 255, 64 };
			playerclass = "";
			rank = "";
			number = "";
		else
			local cbid = dkplist[n];
			name = cbid[1];
			bidcolor = { 64, 255, 64 };
			dkp = string.format("%d", cbid[2]);
			playerclass = cbid[3];
			rank = cbid[4];
			number = n;
		end

		local color = DKPList_GetClassColorCodes(playerclass);

		local frame = getglobal("DKPListUIFrameTableListScrollFrameEntry"..n);

		getglobal(frame:GetName().."Number"):SetText(number);		
		getglobal(frame:GetName().."Name"):SetText(name);
		getglobal(frame:GetName().."Name"):SetTextColor((color[1]/255), (color[2]/255), (color[3]/255), 255);
		getglobal(frame:GetName().."DKP"):SetTextColor((bidcolor[1]/255), (bidcolor[2]/255), (bidcolor[3]/255), 255);
		getglobal(frame:GetName().."DKP"):SetText(dkp);
		getglobal(frame:GetName().."Rank"):SetText(rank);

		frame:Show();
	end
	DKPList_FiltersShownButtonOnLoad();
end

function DKPList_GetClassColorCodes(classname)
    local colors = { 128,128,128 }
    classname = DKPList_UCFirst(classname);
   
    local cc;
    for n=1, table.getn(CLASS_COLORS), 1 do
        cc = CLASS_COLORS[n];
        if cc[1] == classname then
            return cc[2];
        end
    end
    
    return colors;
end

function DKPList_RefreshRoster()
	local ShowOffline = GetGuildRosterShowOffline()
	SetGuildRosterShowOffline(true)
	if DKPList_CheckForInRaid == 0 then 
		DKPList_RefreshGuildRoster()
	else 
		DKPList_RefreshGuildRoster()
		DKPList_RefreshRaidRoster() 
	end
	if ShowOffline == 1 then
		SetGuildRosterShowOffline(true)
	else SetGuildRosterShowOffline(false) end
end

function DKPList_DruidButtonOnClick()
	if arg1 == "LeftButton" then
		if CLASS_FILTER[1][2] == 0 then CLASS_FILTER[1][2] = 1
		else CLASS_FILTER[1][2] = 0 end
	else
		DKPList_FilterAllClasses();
		CLASS_FILTER[1][2] = 1;
	end
	DKPList_RefreshRoster();
	DKPList_UpdateDKPElements();
end

function DKPList_HunterButtonOnClick()
	if arg1 == "LeftButton" then
		if CLASS_FILTER[2][2] == 0 then CLASS_FILTER[2][2] = 1
		else CLASS_FILTER[2][2] = 0 end
	else
		DKPList_FilterAllClasses();
		CLASS_FILTER[2][2] = 1;
	end
	DKPList_RefreshRoster();
	DKPList_UpdateDKPElements();
end

function DKPList_MageButtonOnClick(arg1)
	if arg1 == "LeftButton" then
		if CLASS_FILTER[3][2] == 0 then CLASS_FILTER[3][2] = 1
		else CLASS_FILTER[3][2] = 0 end
	else
		DKPList_FilterAllClasses();
		CLASS_FILTER[3][2] = 1;
	end
	DKPList_RefreshRoster();
	DKPList_UpdateDKPElements();
end

function DKPList_PaladinButtonOnClick()
	if DKPList_AllianceMode == 0 then return end
	if arg1 == "LeftButton" then
		if CLASS_FILTER[4][2] == 0 then CLASS_FILTER[4][2] = 1
		else CLASS_FILTER[4][2] = 0 end
	else
		DKPList_FilterAllClasses();
		CLASS_FILTER[4][2] = 1;
	end
	DKPList_RefreshRoster();
	DKPList_UpdateDKPElements();
end

function DKPList_PriestButtonOnClick()
	if arg1 == "LeftButton" then
		if CLASS_FILTER[5][2] == 0 then CLASS_FILTER[5][2] = 1
		else CLASS_FILTER[5][2] = 0 end
	else
		DKPList_FilterAllClasses();
		CLASS_FILTER[5][2] = 1;
	end
	DKPList_RefreshRoster();
	DKPList_UpdateDKPElements();
end

function DKPList_RogueButtonOnClick()
	if arg1 == "LeftButton" then
		if CLASS_FILTER[6][2] == 0 then CLASS_FILTER[6][2] = 1
		else CLASS_FILTER[6][2] = 0 end
	else
		DKPList_FilterAllClasses();
		CLASS_FILTER[6][2] = 1;
	end
	DKPList_RefreshRoster();
	DKPList_UpdateDKPElements();
end

function DKPList_ShamanButtonOnClick()
	if DKPList_AllianceMode == 1 then return end
	if arg1 == "LeftButton" then
		if CLASS_FILTER[7][2] == 0 then CLASS_FILTER[7][2] = 1
		else CLASS_FILTER[7][2] = 0 end
	else
		DKPList_FilterAllClasses();
		CLASS_FILTER[7][2] = 1;
	end
	DKPList_RefreshRoster();
	DKPList_UpdateDKPElements();
end

function DKPList_WarlockButtonOnClick()
	if arg1 == "LeftButton" then
		if CLASS_FILTER[8][2] == 0 then CLASS_FILTER[8][2] = 1
		else CLASS_FILTER[8][2] = 0 end
	else
		DKPList_FilterAllClasses();
		CLASS_FILTER[8][2] = 1;
	end
	DKPList_RefreshRoster();
	DKPList_UpdateDKPElements();
end

function DKPList_WarriorButtonOnClick()
	if arg1 == "LeftButton" then
		if CLASS_FILTER[9][2] == 0 then CLASS_FILTER[9][2] = 1
		else CLASS_FILTER[9][2] = 0 end
	else
		DKPList_FilterAllClasses();
		CLASS_FILTER[9][2] = 1;
	end
	DKPList_RefreshRoster();
	DKPList_UpdateDKPElements();
end

function DKPList_ShowClassButtons()
	DKPList_DruidButton:Show();
	DKPList_HunterButton:Show();
	DKPList_MageButton:Show();
	if DKPList_AllianceMode == 1 then DKPList_PaladinButton:Show()
	else DKPList_PaladinButton:Disable() end
	DKPList_PriestButton:Show();
	DKPList_RogueButton:Show();
	if DKPList_AllianceMode == 1 then DKPList_ShamanButton:Disable()
	else DKPList_ShamanButton:Show() end
	DKPList_WarlockButton:Show();
	DKPList_WarriorButton:Show();
end

function DKPList_IsInRaidButtonOnClick()
	if DKPList_CheckForInRaid == 0 then DKPList_CheckForInRaid = 1
	else DKPList_CheckForInRaid = 0 end
	DKPList_RefreshRoster();
	DKPList_UpdateDKPElements();
end

function DKPList_ResetButtonOnClick()
	for n=1,getn(CLASS_FILTER),1 do
		CLASS_FILTER[n][2] = 1;
	end
	DKPList_CheckForInRaid = 0;
	DKPList_RefreshRoster();
	DKPList_UpdateDKPElements();
end

function DKPList_FilterAllClasses()
	for n=1,getn(CLASS_FILTER),1 do
		CLASS_FILTER[n][2] = 0;
	end
end

function DKPList_FiltersShownButtonOnLoad()
	if DKPList_AllianceMode == 1 then CLASS_FILTER[7][2] = 0
	else CLASS_FILTER[4][2] = 0 end

	local frame = getglobal("DKPList_FiltersShownButton");

	getglobal(frame:GetName().."Text"):SetText("Showing: ");
	local text = getglobal(frame:GetName().."Text"):GetText()
	local numClassesShown = 0;
	for n=1,getn(CLASS_FILTER),1 do
		if CLASS_FILTER[n][2] == 1 then
			text = text ..CLASS_FILTER[n][1] ..", "
			numClassesShown = numClassesShown + 1;
		end
	end
	text = string.sub(text, 1, string.len(text) - 2)

	if DKPList_AllianceMode == 1 then
		if numClassesShown == getn(CLASS_FILTER) - 1 and CLASS_FILTER[7][2] == 0 then
			text = getglobal(frame:GetName().."Text"):GetText() .."All Classes"
		end
	else
		if numClassesShown == getn(CLASS_FILTER) - 1 and CLASS_FILTER[4][2] == 0 then
			text = getglobal(frame:GetName().."Text"):GetText() .."All Classes"
		end
	end
	
	if DKPList_CheckForInRaid == 1 then
		text = text .." - In Raid only"
	else
		text = text .." - In Guild"
	end
	getglobal(frame:GetName().."Text"):SetText(text);
end

function DKPList_CloseUI()
	DKPListUIFrame:Hide();
end

--[[
     Convert a msg so first letter is uppercase, and rest as lower case.
]]
function DKPList_UCFirst(msg)
    if not msg then
        return ""
    end	
    
    local f = string.sub(msg, 1, 1)
    local r = string.sub(msg, 2)
    return string.upper(f) .. string.lower(r)
end

function DKPList_InitializeTableElements()
	--	Initialize top <n> bids
	for n=1, MAX_ENTRIES_SHOWN, 1 do
		local entry = CreateFrame("Button", "$parentEntry"..n, DKPListUIFrameTableListScrollFrame, "DKPList_EntryTemplate");
		entry:SetID(n);
		if n == 1 then
			entry:SetPoint("TOPLEFT", 4, 2);
		else
			entry:SetPoint("TOP", "$parentEntry"..(n-1), "BOTTOM");
		end
	end
end

function DKPList_compare(a,b)
	return a[2] > b[2]
end

function DKPList_ScrollBarUpdate()
	FauxScrollFrame_Update(DKPListUIFrameTableListScrollFrame,MAX_ENTRIES,MAX_ENTRIES_SHOWN,16,
	nil, nil, nil,                  -- button, smallWidth, bigWidth
	nil,                            -- highlightFrame
	0, 0);                          -- smallHighlightWidth, bigHighlightWidth
	  -- 50 is max entries, 5 is number of lines, 16 is pixel height of each line
	local name, dkp, playerclass, rank, number;
	local dkplist = {}
	local nplusoffset;

	if DKPList_CheckForInRaid == 0 then dkplist = DKPList_GuildRosterTable
	else dkplist = DKPList_RaidRosterTable end
	for n=1,MAX_ENTRIES_SHOWN,1 do
		nplusoffset = n + FauxScrollFrame_GetOffset(DKPListUIFrameTableListScrollFrame);
		local frame = getglobal("DKPListUIFrameTableListScrollFrameEntry"..n);
		if nplusoffset <= MAX_ENTRIES then
			if table.getn(dkplist) <= nplusoffset then
				name = "";
				dkp = "";
				bidcolor = { 64, 255, 64 };
				playerclass = "";
				rank = "";
				number = "";
			else
				local cbid = dkplist[nplusoffset];
				name = cbid[1];
				bidcolor = { 64, 255, 64 };
				dkp = string.format("%d", cbid[2]);
				playerclass = cbid[3];
				rank = cbid[4];
				number = nplusoffset
			end
		
			local color = DKPList_GetClassColorCodes(playerclass);
			
			getglobal(frame:GetName().."Number"):SetText(number);
			getglobal(frame:GetName().."Name"):SetText(name);
			getglobal(frame:GetName().."Name"):SetTextColor((color[1]/255), (color[2]/255), (color[3]/255), 255);
			getglobal(frame:GetName().."DKP"):SetTextColor((bidcolor[1]/255), (bidcolor[2]/255), (bidcolor[3]/255), 255);
			getglobal(frame:GetName().."DKP"):SetText(dkp);
			getglobal(frame:GetName().."Rank"):SetText(rank);
		
			frame:Show();
		else			
			frame:Hide();
		end
	end
end