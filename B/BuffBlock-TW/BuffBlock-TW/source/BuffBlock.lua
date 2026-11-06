local BB_PlayerName = nil;
local BB_default = {};
local BuffBlockMenuObjects = {}
local BuffBlockMenuStrings = {
	[00]= "Battle Shout",
	[01]= "Blessing of Salvation",
	[02]= "Greater Blessing of Salvation",
	[03]= "Divine Spirit",
	[04]= "Prayer of Spirit",
	[05]= "Arcane Intellect",
	[06]= "Arcane Brilliance",
	[07]= "Blessing of Protection",
	[08]= "Divine Shield",
	[09]= "Smart Tank Buff Blocking"
}

function BuffBlock_OnLoad()
	this:RegisterEvent("PLAYER_AURAS_CHANGED");
	this:RegisterEvent("VARIABLES_LOADED");
	this:RegisterEvent("UNIT_INVENTORY_CHANGED");
	DEFAULT_CHAT_FRAME:AddMessage("Smart Buff Block, by Zeitung - forked from Armilus. /buffblock or /sbb for options.", 0.8, 0.8, 0.5);
	SLASH_BB1 = "/SBB";
	SLASH_BB2 = "/BUFFBLOCK";
	SlashCmdList["BB"] = BuffBlock_Command;
end

function BuffBlock_Init()
    BB_PlayerName = UnitName("player").." of "..GetCVar("realmName");
	
    if (BUFF_CONFIG == nil) then
		BUFF_CONFIG = {};
    end
	
	if (BUFF_CONFIG[BB_PlayerName] == nil) then
		BUFF_CONFIG[BB_PlayerName] = BB_default;
    end
end

function BuffBlock_OnEvent()
	if (event == "PLAYER_AURAS_CHANGED" or event == "UPDATE_BONUS_ACTIONBAR" and LazyPig_PlayerClass("Druid", "player") or event == "UNIT_INVENTORY_CHANGED") then
		Kill_Buffs();
	elseif (event == "VARIABLES_LOADED") then
		BuffBlock_Init();
	end
end

function BuffBlock_Command()
	if BuffBlockOptions:IsShown() then
		BuffBlockOptions:Hide();
	else
		BuffBlockOptions:Show();
	end
end

function BuffBlock_GetOption(num)
	local labelString = getglobal(this:GetName().."Text");
	local label = BuffBlockMenuStrings[num] or "";
	BuffBlockMenuObjects[num] = this
	
	if num == 00 and BUFF_CONFIG[BB_PlayerName].BATTLESHOUT
	or num == 01 and BUFF_CONFIG[BB_PlayerName].SALVATION
	or num == 02 and BUFF_CONFIG[BB_PlayerName].GREATERSALVATION
	or num == 03 and BUFF_CONFIG[BB_PlayerName].DIVINESPIRIT
	or num == 04 and BUFF_CONFIG[BB_PlayerName].PRAYEROFSPIRIT
	or num == 05 and BUFF_CONFIG[BB_PlayerName].ARCANEINTELLECT
	or num == 06 and BUFF_CONFIG[BB_PlayerName].ARCANEBRILLIANCE
	or num == 07 and BUFF_CONFIG[BB_PlayerName].BLESSINGOFPROTECTION
	or num == 08 and BUFF_CONFIG[BB_PlayerName].DIVINESHIELD
	or num == 09 and BUFF_CONFIG[BB_PlayerName].SMARTTANKINGBUFF
	or nil then
		this:SetChecked(true);
	else
		this:SetChecked(nil);
	end
	labelString:SetText(label);
end

function BuffBlock_SetOption(num)
	local checked = this:GetChecked()
	if num == 00 then
		if checked then
			BUFF_CONFIG[BB_PlayerName].BATTLESHOUT = 1
			DEFAULT_CHAT_FRAME:AddMessage("Blocking "..BuffBlockMenuStrings[num]);
		else
			BUFF_CONFIG[BB_PlayerName].BATTLESHOUT = nil
			DEFAULT_CHAT_FRAME:AddMessage("Stopped blocking "..BuffBlockMenuStrings[num]);
		end
	elseif num == 01 then
		if checked then
			BUFF_CONFIG[BB_PlayerName].SALVATION = 1
			DEFAULT_CHAT_FRAME:AddMessage("Blocking "..BuffBlockMenuStrings[num]);
		else
			BUFF_CONFIG[BB_PlayerName].SALVATION = nil
			DEFAULT_CHAT_FRAME:AddMessage("Stopped blocking "..BuffBlockMenuStrings[num]);
		end
	elseif num == 02 then
		if checked then
			BUFF_CONFIG[BB_PlayerName].GREATERSALVATION = 1
			DEFAULT_CHAT_FRAME:AddMessage("Blocking "..BuffBlockMenuStrings[num]);
		else
			BUFF_CONFIG[BB_PlayerName].GREATERSALVATION = nil
			DEFAULT_CHAT_FRAME:AddMessage("Stopped blocking "..BuffBlockMenuStrings[num]);
		end
	elseif num == 03 then
		if checked then
			BUFF_CONFIG[BB_PlayerName].DIVINESPIRIT = 1
			DEFAULT_CHAT_FRAME:AddMessage("Blocking "..BuffBlockMenuStrings[num]);
		else
			BUFF_CONFIG[BB_PlayerName].DIVINESPIRIT = nil
			DEFAULT_CHAT_FRAME:AddMessage("Stopped blocking "..BuffBlockMenuStrings[num]);
		end
	elseif num == 04 then
		if checked then
			BUFF_CONFIG[BB_PlayerName].PRAYEROFSPIRIT = 1
			DEFAULT_CHAT_FRAME:AddMessage("Blocking "..BuffBlockMenuStrings[num]);
		else
			BUFF_CONFIG[BB_PlayerName].PRAYEROFSPIRIT = nil
			DEFAULT_CHAT_FRAME:AddMessage("Stopped blocking "..BuffBlockMenuStrings[num]);
		end
	elseif num == 05 then
		if checked then
			BUFF_CONFIG[BB_PlayerName].ARCANEINTELLECT = 1
			DEFAULT_CHAT_FRAME:AddMessage("Blocking "..BuffBlockMenuStrings[num]);
		else
			BUFF_CONFIG[BB_PlayerName].ARCANEINTELLECT = nil
			DEFAULT_CHAT_FRAME:AddMessage("Stopped blocking "..BuffBlockMenuStrings[num]);
		end
	elseif num == 06 then
		if checked then
			BUFF_CONFIG[BB_PlayerName].ARCANEBRILLIANCE = 1
			DEFAULT_CHAT_FRAME:AddMessage("Blocking "..BuffBlockMenuStrings[num]);
		else
			BUFF_CONFIG[BB_PlayerName].ARCANEBRILLIANCE = nil
			DEFAULT_CHAT_FRAME:AddMessage("Stopped blocking "..BuffBlockMenuStrings[num]);
		end
	elseif num == 07 then
		if checked then
			BUFF_CONFIG[BB_PlayerName].BLESSINGOFPROTECTION = 1
			DEFAULT_CHAT_FRAME:AddMessage("Blocking "..BuffBlockMenuStrings[num]);
		else
			BUFF_CONFIG[BB_PlayerName].BLESSINGOFPROTECTION = nil
			DEFAULT_CHAT_FRAME:AddMessage("Stopped blocking "..BuffBlockMenuStrings[num]);
		end
	elseif num == 08 then
		if checked then
			BUFF_CONFIG[BB_PlayerName].DIVINESHIELD = 1
			DEFAULT_CHAT_FRAME:AddMessage("Blocking "..BuffBlockMenuStrings[num]);
		else
			BUFF_CONFIG[BB_PlayerName].DIVINESHIELD = nil
			DEFAULT_CHAT_FRAME:AddMessage("Stopped blocking "..BuffBlockMenuStrings[num]);
		end
	elseif num == 09 then
		if checked then
			BUFF_CONFIG[BB_PlayerName].SMARTTANKINGBUFF = 1
			DEFAULT_CHAT_FRAME:AddMessage("Started "..BuffBlockMenuStrings[num]);
		else
			BUFF_CONFIG[BB_PlayerName].SMARTTANKINGBUFF = nil
			DEFAULT_CHAT_FRAME:AddMessage("Stopped "..BuffBlockMenuStrings[num]);
		end
	end
end

function IsShieldEquipped()
	local slot = GetInventorySlotInfo("SecondaryHandSlot")
	local link = GetInventoryItemLink("player", slot)
	if link  then
		local found, _, id, name = string.find(link, "item:(%d+):.*%[(.*)%]")
		if found then
			local _,_,_,_,_,itemType = GetItemInfo(tonumber(id))
			if(itemType == "Shields") then
				return true
			end
		end
	end
	return false
end

function Kill_Buffs()
	local i = 0;
	while not (GetPlayerBuff(i, "HELPFUL") == -1) do
		local buffIndex, untilCancelled = GetPlayerBuff(i, "HELPFUL")
		local texture = GetPlayerBuffTexture(buffIndex);
		
		--DEFAULT_CHAT_FRAME:AddMessage("DEBUG: "..texture, 1, 1, 0.5);
		
		if BUFF_CONFIG[BB_PlayerName].BATTLESHOUT then
			if (string.find(texture,"BattleShout")) then
				CancelPlayerBuff(buffIndex);
				DEFAULT_CHAT_FRAME:AddMessage("Blocked "..BuffBlockMenuStrings[00], 1, 1, 0.5);
			end
		end
		if BUFF_CONFIG[BB_PlayerName].SALVATION then
			if (string.lower(UnitClass("player")) ~= "warrior" or (IsShieldEquipped() and GetShapeshiftFormInfo(2))) then
				if (string.find(texture,"SealOfSalvation")) then
					CancelPlayerBuff(buffIndex);
					DEFAULT_CHAT_FRAME:AddMessage("Blocked "..BuffBlockMenuStrings[01], 1, 1, 0.5);
				end
			end
		end
		if BUFF_CONFIG[BB_PlayerName].GREATERSALVATION then
			if (string.lower(UnitClass("player")) ~= "warrior" or (IsShieldEquipped() and GetShapeshiftFormInfo(2))) then
				if (string.find(texture,"GreaterBlessingofSalvation")) then
					CancelPlayerBuff(buffIndex);
					DEFAULT_CHAT_FRAME:AddMessage("Blocked "..BuffBlockMenuStrings[02], 1, 1, 0.5);
				end
			end
		end
		if BUFF_CONFIG[BB_PlayerName].DIVINESPIRIT then
			if (string.find(texture,"DivineSpirit")) then
				CancelPlayerBuff(buffIndex);
				DEFAULT_CHAT_FRAME:AddMessage("Blocked "..BuffBlockMenuStrings[03], 1, 1, 0.5);
			end
		end
		if BUFF_CONFIG[BB_PlayerName].PRAYEROFSPIRIT then
			if (string.find(texture,"PrayerofSpirit")) then
				CancelPlayerBuff(buffIndex);
				DEFAULT_CHAT_FRAME:AddMessage("Blocked "..BuffBlockMenuStrings[04], 1, 1, 0.5);
			end
		end
		if BUFF_CONFIG[BB_PlayerName].ARCANEINTELLECT then
			if (string.find(texture,"MagicalSentry")) then
				CancelPlayerBuff(buffIndex);
				DEFAULT_CHAT_FRAME:AddMessage("Blocked "..BuffBlockMenuStrings[05], 1, 1, 0.5);
			end
		end
		if BUFF_CONFIG[BB_PlayerName].ARCANEBRILLIANCE then
			if (string.find(texture,"ArcaneIntellect")) then
				CancelPlayerBuff(buffIndex);
				DEFAULT_CHAT_FRAME:AddMessage("Blocked "..BuffBlockMenuStrings[06], 1, 1, 0.5);
			end
		end
		if BUFF_CONFIG[BB_PlayerName].BLESSINGOFPROTECTION then
			if (string.find(texture,"SealOfProtection")) then
				CancelPlayerBuff(buffIndex);
				DEFAULT_CHAT_FRAME:AddMessage("Blocked "..BuffBlockMenuStrings[07], 1, 1, 0.5);
			end
		end
		if BUFF_CONFIG[BB_PlayerName].DIVINESHIELD then
			if (string.find(texture,"Spell_Holy_DivineIntervention")) then
				CancelPlayerBuff(buffIndex);
				DEFAULT_CHAT_FRAME:AddMessage("Blocked "..BuffBlockMenuStrings[07], 1, 1, 0.5);
			end
		end
		if BUFF_CONFIG[BB_PlayerName].SMARTTANKINGBUFF then
			CheckSalvation();
		end
		
		i = i + 1;
	end
end


function CancelSalvationBuff()
    local buff = {"Spell_Holy_SealOfSalvation", "Spell_Holy_GreaterBlessingofSalvation"}
    local counter = 0
    while GetPlayerBuff(counter) >= 0 do
        local index, untilCancelled = GetPlayerBuff(counter)
        if untilCancelled ~= 1 then
            local texture = GetPlayerBuffTexture(index)
            if texture then  -- Check if texture is not nil
                local i = 1
                while buff[i] do
                    if string.find(texture, buff[i]) then
                        CancelPlayerBuff(index);
                        UIErrorsFrame:Clear();
                        UIErrorsFrame:AddMessage("Salvation Removed");
                        return
                    end
                    i = i + 1
                end
            end
        end
        counter = counter + 1
    end
    return nil
end

function CancelBOP()
    local buff = {"Spell_Holy_SealOfProtection"}
    local counter = 0
    while GetPlayerBuff(counter) >= 0 do
        local index, untilCancelled = GetPlayerBuff(counter)
        if untilCancelled ~= 1 then
            local texture = GetPlayerBuffTexture(index)
            if texture then  -- Check if texture is not nil
                local i = 1
                while buff[i] do
                    if string.find(texture, buff[i]) then
                        CancelPlayerBuff(index);
                        UIErrorsFrame:Clear();
                        UIErrorsFrame:AddMessage("BOP Removed");
                        return
                    end
                    i = i + 1
                end
            end
        end
        counter = counter + 1
    end
    return nil
end

function PlayerClass(class, unit)
	if class then
		local unit = unit or "player"
		local _, c = UnitClass(unit)
		if c then
			if string.lower(c) == string.lower(class) then
				return true
			end
		end
	end
	return false
end

function IsRighteousFuryOn()
    local buff = {"Spell_Holy_SealOfFury"}
    local counter = 0
    while GetPlayerBuff(counter) >= 0 do
        local index, FindRF = GetPlayerBuff(counter)
        if FindRF == 1 then
            local texture = GetPlayerBuffTexture(index)
            if texture then  -- Check if texture is not nil
                local i = 1
                while buff[i] do
                    if string.find(texture, buff[i]) then
                        return true
                    end
                    i = i + 1
                end
            end
        end
        counter = counter + 1
    end
    return false
end

function IsBearForm()
	local i;
	local max = GetNumShapeshiftForms();
	for i = 1 , max do
		local _, name, isActive = GetShapeshiftFormInfo(i);
		if(isActive and PlayerClass("Druid", "player") and (name == "Bear Form" or name == "Dire Bear Form")) then
			return true
		end
	end
	return false
end

function IsDefensiveStanceOn()
    local buff = {"Ability_Warrior_DefensiveStance"}
    local counter = 0
    while GetPlayerBuff(counter) >= 0 do
        local index, FindDS = GetPlayerBuff(counter)
        if FindDS == 1 then
            local texture = GetPlayerBuffTexture(index)
            if texture then  -- Check if texture is not nil
                local i = 1
                while buff[i] do
                    if string.find(texture, buff[i]) then
                        return true
                    end
                    i = i + 1
                end
            end
        end
        counter = counter + 1
    end
    return false
end

SBBFrame = CreateFrame("Frame", nil, UIParent)
SBBFrame.Tooltip = CreateFrame("GameTooltip", "LazyPigTooltip", nil, "GameTooltipTemplate")
SBBFrame.Tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

function HasTemporaryWeaponEnchanment(enchantmentName)
    LazyPigTooltip:ClearLines()
    local hasItem,_,_ = LazyPigTooltip:SetInventoryItem("player", 16)
    if (not hasItem) then
        return false
    end

    for lineNum = 6, 15 do
        local line = getglobal("LazyPigTooltipTextLeft"..lineNum)
        if (line:IsShown()) then
                local text = line:GetText()
                if (string.find(string.lower(text), string.lower(enchantmentName))) then
                        return true
                end
        else
                return false
        end
    end
end

function CheckSalvation()
	if( IsShieldEquipped() and PlayerClass("Warrior", "player") or IsDefensiveStanceOn() or IsBearForm() or IsRighteousFuryOn() or HasTemporaryWeaponEnchanment("Rockbiter") ) then
        CancelSalvationBuff();
		CancelBOP();
	end
end



