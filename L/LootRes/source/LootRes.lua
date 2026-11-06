local LootRes = CreateFrame("Frame", "LootRes", GameTooltip)
LootRes:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
LootRes:RegisterEvent("CHAT_MSG_WHISPER")
LootRes:RegisterEvent("CHAT_MSG_SYSTEM")
LootRes:RegisterEvent("ADDON_LOADED")
LootRes:RegisterEvent("CHAT_MSG_LOOT")

local rollsOpen = false
local rollers = {}
local maxRoll = 0
local reservedNames = ""

local secondsToRoll = 12
local T = 1
local C = secondsToRoll
local lastRolledItem = ""
local offspecRoll = false

local raids = 'The Molten Core Blackwing Lair Ahn\'Qiraj Zul\'Gurub Ruins of Ahn\'Qiraj'

function lrprint(a)
    if a == nil then
        DEFAULT_CHAT_FRAME:AddMessage('|cff69ccf0[LR]|cff0070de:' .. time() .. '|cffffffff attempt to print a nil value.')
        return false
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cff69ccf0[LR] |cffffffff" .. a)
end

LootRes.Player = ''
LootRes.Item = ''
LootRes.Name = ''

LootRes:SetScript("OnEvent", function()
    if event then
        if event == 'CHAT_MSG_WHISPER' then
            if arg1 == '-mcres' then
                LootRes:CheckMCRes(arg1, arg2)
            elseif string.find(arg1, '-mcres ', 1, true) then
                LootRes:ReserveItem(arg1, arg2)
            end
        end
        if event == 'CHAT_MSG_SYSTEM' and rollsOpen then
            LootRes:CheckRolls(arg1)
        end
        if event == 'ADDON_LOADED' then
            if not LOOT_RES_LOOT_HISTORY then
                LOOT_RES_LOOT_HISTORY = {}
            end
            if not LOOTRES_RESERVES then
                LOOTRES_RESERVES ={}
            end
        end
        if event == 'CHAT_MSG_LOOT' then
            if UnitInRaid('player') and string.find(raids, GetZoneText(), 1, true) then
                local lootEx = string.split(arg1, " loot: ")
                if not lootEx[1] or not lootEx[2] then
                    return false
                end

                local realPlayer = string.split(lootEx[1], ' ')

                if not realPlayer[1] then
                    lrprint('cant save for ' .. lootEx[1])
                    return false
                end

                local player = realPlayer[1] -- lootEx[1]
                local item = string.sub(lootEx[2], 1, string.len(lootEx[2]) - 1)

                if string.sub(arg1, 1, 4) == "You " then
                    player = UnitName('player')
                end

                local _, _, itemLink = string.find(item, "(item:%d+:%d+:%d+:%d+)");

                GameTooltip:SetHyperlink(itemLink)
                GameTooltip:Hide()

                local name, _, quality, _, _, _, _, _, tex = GetItemInfo(itemLink)

                if not name or not quality then
                    lrprint('looted item info not found')
                    return false
                end

                local minT = GetZoneText() == 'Ruins of Ahn\'Qiraj' and 3 or 4

                if quality >= minT then
                    --4 for epic

                    for _, boe_item in next, LootRes.BOES do
                        if name == boe_item then
                            --lrprint('not saved boe item');
                            return false
                        end
                    end

                    if not LootRes:IsRL() then
                        return false
                    end

                    getglobal('LootResWindowItem'):SetText('Save ' .. item .. ' for ' .. player .. ' ?')
                    if LOOT_RES_LOOT_HISTORY[player] then
                        getglobal('LootResWindowHistory'):SetText(LOOT_RES_LOOT_HISTORY[player])
                    else
                        getglobal('LootResWindowHistory'):SetText('-no loot history-')
                    end

                    LootRes.Player = player
                    LootRes.Item = item
                    LootRes.Name = name

                    getglobal('LootResWindow'):Show()

                end
            end
        end
    end
end)

--when player is too far away & loot received is not visible
function saveLast(cmd)

    local name = string.split(cmd, ' ')
    if not name[2] then
        lrprint('Syntax: /lootres savelast [name]')
        return false
    end
    local player = name[2]
    if LOOT_RES_LOOT_HISTORY[player] == nil then
        LOOT_RES_LOOT_HISTORY[player] = LootRes.Item
    else
        LOOT_RES_LOOT_HISTORY[player] = LOOT_RES_LOOT_HISTORY[player] .. ' ' .. LootRes.Item
    end
    SendChatMessage("LootRes: Saved " .. LootRes.Item .. " for " .. player .. " as Reserved or Mainspec.", "RAID")

    if TWLC_LOOT_HISTORY then
        TWLC_LOOT_HISTORY[time()] = {
            ['player'] = player,
            ['item'] = LootRes.Item
        }
    end

    LOOTRES_RESERVES[player] = nil

    getglobal('LootResWindow'):Hide()
end

function saveMS()

    if not LOOT_RES_LOOT_HISTORY[LootRes.Player] then
        LOOT_RES_LOOT_HISTORY[LootRes.Player] = nil
    end
    if LOOTRES_RESERVES[LootRes.Player] == LootRes.Name or not offspecRoll then
        if LOOT_RES_LOOT_HISTORY[LootRes.Player] == nil then
            LOOT_RES_LOOT_HISTORY[LootRes.Player] = LootRes.Item
        else
            LOOT_RES_LOOT_HISTORY[LootRes.Player] = LOOT_RES_LOOT_HISTORY[LootRes.Player] .. ' ' .. LootRes.Item
        end
        SendChatMessage("LootRes: Saved " .. LootRes.Item .. " for " .. LootRes.Player .. " as Reserved or Mainspec.", "RAID")

        if TWLC_LOOT_HISTORY then
            TWLC_LOOT_HISTORY[time()] = {
                ['player'] = LootRes.Player,
                ['item'] = LootRes.Item
            }
        end

        LOOTRES_RESERVES[LootRes.Player] = nil

        getglobal('LootResWindow'):Hide()
    end
end

function LootRes:ReserveItem(text, player)
    local newItem = LootResReplace(text, "-mcres ", "")
    local itemName, _, itemRarity, _, _, _, _, itemSlot, _ = GetItemInfo(newItem)
    lrprint(itemName)
end

function LootRes:CheckMCRes(arg1, arg2)

    local foundRes = false

    for playerName, item in next, LOOTRES_RESERVES do
        if (playerName == arg2) then
            SendChatMessage("LootRes: Your MC Res : [" .. item .. "]", "WHISPER", "Common", arg2);
            foundRes = true
        end
    end

    if not foundRes then
        SendChatMessage("LootRes: Your MC Res : -Nothing Reserved-", "WHISPER", "Common", arg2);
    end
end

LootRes:SetScript("OnShow", function()

    local reservedNumber = 0
    if GameTooltip.itemLink then
        local _, _, itemLink = string.find(GameTooltip.itemLink, "(item:%d+:%d+:%d+:%d+)");

        if not itemLink then
            return false
        end

        local itemName, _, itemRarity = GetItemInfo(itemLink)

        for _, item in next, LOOTRES_RESERVES do
            if string.lower(itemName) == string.lower(item) then
                reservedNumber = reservedNumber + 1
            end
        end

        if itemRarity >= 4 then

            GameTooltip:AddLine("Soft-Reserved List (" .. reservedNumber .. ")")

            if (reservedNumber > 0) then
                for playerName, item in next, LOOTRES_RESERVES do
                    if (string.lower(itemName) == string.lower(item)) then
                        GameTooltip:AddLine(playerName, 1, 1, 1)
                    end
                end
            end
        end

        GameTooltip:Show()
    end
end)

LootRes:SetScript("OnHide", function()
    GameTooltip.itemLink = nil
end)

function LootRes:ScanUnit(target)
    if not UnitIsPlayer(target) then
        return nil
    end
    return 0, 0, 0, 0
end

local LootResHookSetBagItem = GameTooltip.SetBagItem
function GameTooltip.SetBagItem(self, container, slot)
    GameTooltip.itemLink = GetContainerItemLink(container, slot)
    _, GameTooltip.itemCount = GetContainerItemInfo(container, slot)
    return LootResHookSetBagItem(self, container, slot)
end

local LootResHookSetLootItem = GameTooltip.SetLootItem
function GameTooltip.SetLootItem(self, slot)
    GameTooltip.itemLink = GetLootSlotLink(slot)
    LootResHookSetLootItem(self, slot)
end

SLASH_LOOTRES1 = "/lootres"
SlashCmdList["LOOTRES"] = function(cmd)
    if cmd then
        if string.find(cmd, 'savelast', 1, true) then
            saveLast(cmd)
        end
        if cmd == 'print' then
            LootRes:PrintReserves()
        end
        if cmd == 'load' then
            getglobal('LootResLoadFromTextTextBox'):SetText("")
            getglobal('LootResLoadFromText'):Show()
        end
        if cmd == 'loadold' then
            LOOTRES_RESERVES = LootRes.RESERVES
            lrprint("Loaded from old way")
            for player, item in LOOTRES_RESERVES do
                lrprint("Player: " ..player .. ", item: " .. item)
            end
        end
        if cmd == 'check' then
            LootRes:CheckReserves()
        end
        if cmd == 'reset' then
            LOOT_RES_LOOT_HISTORY = {}
            lrprint('Looted History Reset.')
        end
        if string.find(cmd, 'view', 1, true) then
            local W = string.split(cmd, ' ')
            local player = W[2]
            if LOOTRES_RESERVES[player] then
                lrprint(player .. ' reserved ' .. LOOTRES_RESERVES[player])
            end
            if not LOOT_RES_LOOT_HISTORY[player] then
                lrprint(player .. ' - nothing looted ')
            else
                lrprint(player .. ' - looted ' .. LOOT_RES_LOOT_HISTORY[player])
            end
        end
        if string.find(cmd, 'clear', 1, true) then
            local W = string.split(cmd, ' ')
            local player = W[2]
            LOOT_RES_LOOT_HISTORY[player] = nil
            lrprint('Cleared ' .. player .. ' ')
        end
        if string.find(cmd, "search", 1, true) then
            LootRes:SearchPlayerOrItem(cmd)
        end
    end
end

function LootResLoadText()
    local data = getglobal('LootResLoadFromTextTextBox'):GetText()

    getglobal('LootResLoadFromText'):Hide()

    if data == '' then
        return false
    end

    data = LootResReplace(data, "Formula:", "Formula*dd*")
    data = LootResReplace(data, "Plans:", "Plans*dd*")
    data = LootResReplace(data, "Recipe:", "Recipe*dd*")
    data = LootResReplace(data, "Guide:", "Guide*dd*")

    LOOTRES_RESERVES = {}

    data = LootRes.explode(data, "[")

    for i, d in data do
        if string.find(d, ']', 1, true) then
            local pl = LootRes.explode(d, ']')
            local pl2 = LootRes.explode(pl[2], ':')
            local playerData = LootRes.explode(pl2[2], '-')
            local player = nil
            local item = nil
            for k, da in playerData do
                if k == 1 then
                    player = LootRes.trim(da)
                end
                if k == 2 then
                    item = LootRes.trim(da)

                    item = LootResReplace(item, "Formula*dd*", "Formula:")
                    item = LootResReplace(item, "Plans*dd*", "Plans:")
                    item = LootResReplace(item, "Recipe*dd*", "Recipe:")
                    item = LootResReplace(item, "Guide*dd*", "Guide:")
                end
                if k == 3 then
                    item = LootRes.trim(playerData[2] .. "-" .. playerData[3])

                    item = LootResReplace(item, "Formula*dd*", "Formula:")
                    item = LootResReplace(item, "Plans*dd*", "Plans:")
                    item = LootResReplace(item, "Recipe*dd*", "Recipe:")
                    item = LootResReplace(item, "Guide*dd*", "Guide:")
                end
                if player and item then
                    LOOTRES_RESERVES[player] = item
                end

            end
        end
    end

    lrprint("Loaded reserves:")

    for player, item in LOOTRES_RESERVES do
        lrprint("Player: " ..player .. ", item: " .. item)
    end
end

function LootRes:PrintReserves()

    for playerName, item in next, LOOTRES_RESERVES do
        lrprint(playerName .. ":" .. item)
    end
end

function LootRes:SearchPlayerOrItem(search)
    lrprint("*" .. LootResReplace(search, "search ", "") .. "*")
end

function LootResReplace(text, search, replace)
    if search == replace then
        return text
    end
    local searchedtext = ""
    local textleft = text
    while string.find(textleft, search, 1, true) do
        searchedtext = searchedtext .. string.sub(textleft, 1, string.find(textleft, search, 1, true) - 1) .. replace
        textleft = string.sub(textleft, string.find(textleft, search, 1, true) + string.len(search))
    end
    if string.len(textleft) > 0 then
        searchedtext = searchedtext .. textleft
    end
    return searchedtext
end

local timerChannel = "RAID_WARNING"
-- GUILD RAID_WARNING SAY



local rollTimer = CreateFrame("Frame")
rollTimer:Hide()
rollTimer:SetScript("OnShow", function()
    this.startTime = math.floor(GetTime());
end)

rollTimer:SetScript("OnUpdate", function()
    if (math.floor(GetTime()) == math.floor(this.startTime) + 1) then
        if (T ~= secondsToRoll + 1) then
            SendChatMessage("LootRes: " .. (C - T + 1) .. "", "RAID")
        end
        rollTimer:Hide()
        if (T < C + 1) then
            T = T + 1
            rollTimer:Show()
        elseif (T == secondsToRoll + 1) then
            SendChatMessage("LootRes: Closed", timerChannel)
            rollTimer:Hide()
            T = 1
            rollsOpen = false

            if (maxRoll ~= 0) then
                local winners = {}
                local winnersNo = 0;

                for index, pr in rollers do
                    if (tonumber(pr) == tonumber(maxRoll)) then
                        winners[index] = pr
                        winnersNo = winnersNo + 1
                    end
                end
                if (winnersNo == 1) then
                    for index, pr in winners do
                        local nice = ""
                        if (pr == 69) then
                            nice = "(nice)"
                        end
                        if (pr == 1) then
                            nice = "(oof)"
                        end
                        if (pr == 100) then
                            nice = "(yeet)"
                        end
                        if (reservedNames ~= "") then
                            SendChatMessage("LootRes: Highest roll by " .. index .. " with " .. pr .. nice .. " (" .. reservedNames .. " reserved this item)", timerChannel)
                        else
                            SendChatMessage("LootRes: Highest roll by " .. index .. " with " .. pr .. nice, timerChannel)
                        end
                    end

                    if string.find(raids, GetZoneText(), 1, true) then
                        SendChatMessage("LootRes: Listing recorded rolls - ", "RAID")
                    end
                    for roller, roll in next, rollers do
                        local resOrMsText = '0/1 (nothing reserved)'
                        if LOOTRES_RESERVES[roller] then
                            resOrMsText = '0/1 ' .. LOOTRES_RESERVES[roller] .. ' (reserved)'
                        end

                        if LOOT_RES_LOOT_HISTORY[roller] ~= nil then
                            local itemSplit = string.split(LOOT_RES_LOOT_HISTORY[roller], 'item:')
                            resOrMsText = (table.getn(itemSplit) - 1) .. '/1 ' .. LOOT_RES_LOOT_HISTORY[roller]
                        end

                        if string.find(raids, GetZoneText(), 1, true) then
                            ChatThrottleLib:SendChatMessage("BULK", "LOOTRES", roller .. " rolled " .. roll .. ". Won " .. resOrMsText .. "", "RAID")
                        end
                    end
                else
                    --tie
                    local tieRollers = ""
                    local tieRoll = 0
                    for index, pr in winners do
                        tieRollers = tieRollers .. " " .. index
                        tieRoll = pr
                    end
                    local nice = ""
                    if (tieRoll == 69) then
                        nice = "(nice)"
                    end
                    if (tieRoll == 1) then
                        nice = "(oof)"
                    end
                    if (tieRoll == 100) then
                        nice = "(yeet)"
                    end
                    if (reservedNames ~= "") then
                        SendChatMessage("LootRes: Highest roll by " .. tieRollers .. " with " .. tieRoll .. nice .. " TIE (" .. reservedNames .. " reserved this item)", timerChannel)
                    else
                        SendChatMessage("LootRes: Highest roll by " .. tieRollers .. " with " .. tieRoll .. nice .. " TIE", timerChannel)
                    end
                end
            else
                --                lrprint('LootRes: No rolls recorded')
                SendChatMessage("LootRes: No rolls recorded.", timerChannel)
            end

            -- reset stuff
            maxRoll = 0
            rollers = {}

        else
            lrprint(T)
        end
    else
        --        lrprint(math.floor(GetTime()) .. " == " .. (math.floor(this.startTime) + 1) .. " check failed");
        --        rollTimer:Hide()
    end
end)

function LootRes:CheckRolls(arg)
    if string.find(arg, "rolls", 1, true) and string.find(arg, "(1-100)", 1, true) then
        local r = string.split(arg, " ")

        if not rollers[r[1]] then
            rollers[r[1]] = tonumber(r[3])
            if tonumber(r[3]) > tonumber(maxRoll) then
                maxRoll = tonumber(r[3])
            end
        end
    end
end

function string:split(delimiter)
    local result = {}
    local from = 1
    local delim_from, delim_to = string.find(self, delimiter, from)
    while delim_from do
        table.insert(result, string.sub(self, from, delim_from - 1))
        from = delim_to + 1
        delim_from, delim_to = string.find(self, delimiter, from)
    end
    table.insert(result, string.sub(self, from))
    return result
end

function PrintFromTooltip()
    lrprint('PrintFromTooltip Deprecated, use MC_Loot() instead.')
    MC_Loot()
end

function MC_Loot()
    if rollsOpen then
        SendChatMessage("ROLLS Canceled ! Restarting.", timerChannel);
    end

    if GameTooltip.itemLink then

        local _, _, itemLink = string.find(GameTooltip.itemLink, "(item:%d+:%d+:%d+:%d+)");
        local itemName = GetItemInfo(itemLink)

        local boe = false
        for _, boe_item in next, LootRes.BOES do
            if itemName == boe_item then
                boe = true
                break
            end
        end

        local reservedNumber = 0;

        for _, item in next, LOOTRES_RESERVES do
            if string.lower(itemName) == string.lower(item) then
                reservedNumber = reservedNumber + 1
            end
        end
        reservedNames = "";
        rollTimer:Hide()

        T = 1 --start
        C = secondsToRoll --count to

        rollers = {}
        maxRoll = 0

        offspecRoll = lastRolledItem == itemName

        lastRolledItem = itemName

        LootRes.Item = GameTooltip.itemLink

        if reservedNumber > 0 then
            -- RESERVED

            for playerName, item in next, LOOTRES_RESERVES do
                if string.lower(itemName) == string.lower(item) then
                    reservedNames = reservedNames .. " " .. playerName;
                end
            end

            if reservedNumber == 1 then
                -- if only one person reserved it
                -- check if he's in raid and online
                local isInRaid = false
                local isOnline = false
                for i = 0, GetNumRaidMembers() do
                    if GetRaidRosterInfo(i) then
                        local n, _, _, _, _, _, z = GetRaidRosterInfo(i);
                        if n == LootRes.trim(reservedNames) then
                            isInRaid = true
                            isOnline = z ~= "Offline"
                        end
                    end
                end
                if isInRaid then
                    if isOnline then
                        SendChatMessage(LootRes.trim(reservedNames) .. " (in raid) is the only one who reserved " .. GameTooltip.itemLink .. " ", timerChannel);
                        if LOOT_RES_LOOT_HISTORY[LootRes.trim(reservedNames)] then
                            if LOOT_RES_LOOT_HISTORY[LootRes.trim(reservedNames)] ~= '' then
                                SendChatMessage(LootRes.trim(reservedName) .. " got " .. LOOT_RES_LOOT_HISTORY[LootRes.trim(reservedNames)] .. " this run.")
                            end
                        end
                    else
                        SendChatMessage(LootRes.trim(reservedNames) .. " (offline) reserved " .. GameTooltip.itemLink .. ". Anyone can roll !", timerChannel);
                        rollTimer:Show()
                        rollsOpen = true
                    end
                else
                    SendChatMessage(LootRes.trim(reservedNames) .. " (not in raid) is the only one who reserved " .. GameTooltip.itemLink .. ". Anyone can roll as MAIN SPEC ! " .. secondsToRoll .. " Seconds", timerChannel);
                    rollTimer:Show()
                    rollsOpen = true
                end
            else
                --if more than one reserved it, check who's online and offline, and inraid
                local peopleWhoReserved = {}
                for playerName, item in next, LOOTRES_RESERVES do
                    if string.lower(itemName) == string.lower(item) then
                        peopleWhoReserved[playerName] = {
                            online = false,
                            inraid = false
                        };
                    end
                end

                for i = 0, GetNumRaidMembers() do
                    if GetRaidRosterInfo(i) then
                        local n, _, _, _, _, _, z = GetRaidRosterInfo(i);

                        for player, data in next, peopleWhoReserved do
                            if player == n then
                                peopleWhoReserved[player]['inraid'] = true
                                if z ~= "Offline" then
                                    peopleWhoReserved[player]['online'] = true
                                end
                            end
                        end
                    end
                end

                SendChatMessage(reservedNames .. " ROLL FOR " .. GameTooltip.itemLink .. " " .. secondsToRoll .. " Seconds", timerChannel);
                rollTimer:Show()
                rollsOpen = true
            end

        else
            -- NOT RESERVED

            if boe then
                local class = ''
                if string.find(GameTooltip.itemLink, 'Felheart', 1, true) then
                    class = 'WARLOCKS'
                end
                if string.find(GameTooltip.itemLink, 'Cenarion', 1, true) then
                    class = 'DRUIDS'
                end
                if string.find(GameTooltip.itemLink, 'Nightslayer', 1, true) then
                    class = 'ROGUES'
                end
                if string.find(GameTooltip.itemLink, 'Giantstalker', 1, true) then
                    class = 'HUNTERS'
                end
                if string.find(GameTooltip.itemLink, 'Arcanist', 1, true) then
                    class = 'MAGES'
                end
                if string.find(GameTooltip.itemLink, 'Prophecy', 1, true) then
                    class = 'PRIESTS'
                end
                if string.find(GameTooltip.itemLink, 'Might', 1, true) then
                    class = 'WARRIORS'
                end
                if string.find(GameTooltip.itemLink, 'Lawbringer', 1, true) then
                    class = 'PALADINS'
                end
                if string.find(GameTooltip.itemLink, 'Earthfury', 1, true) then
                    class = 'SHAMANS'
                end
                SendChatMessage(class .. " ONLY - ROLL " .. GameTooltip.itemLink .. "(BOE) " .. secondsToRoll .. " Seconds", timerChannel);
            else

                if offspecRoll then
                    SendChatMessage("OFF SPEC ROLL " .. GameTooltip.itemLink .. " " .. secondsToRoll .. " Seconds", timerChannel);
                    lastRolledItem = ""
                else
                    SendChatMessage("MAIN SPEC ROLL " .. GameTooltip.itemLink .. " " .. secondsToRoll .. " Seconds (not reserved)", timerChannel);
                end
            end

            rollTimer:Show()
            rollsOpen = true
        end
    end
end

function LootRes:IsRL()
    if not UnitInRaid('player') then
        return false
    end
    for i = 0, GetNumRaidMembers() do
        if GetRaidRosterInfo(i) then
            local n, r = GetRaidRosterInfo(i);
            if n == UnitName('player') and r == 2 then
                return true
            end
        end
    end
    return false
end

function LootRes:CheckReserves()
    for n, i in next, LOOTRES_RESERVES do
        lrprint(" checking " .. i)
        local itemName = GetItemInfo(i)
        lrprint(itemName)
    end
end

function pairsByKeys(t, f)
    local a = {}
    for n in pairs(t) do
        table.insert(a, n)
    end
    table.sort(a, function(a, b)
        return a < b
    end)
    local i = 0 -- iterator variable
    local iter = function()
        -- iterator function
        i = i + 1
        if a[i] == nil then
            return nil
        else
            return a[i], t[a[i]]
        end
    end
    return iter
end

LootRes.RESERVES = {
    ['Er'] = 'test'
}

LootRes.BOES = {
    "Felheart Bracers",
    "Felheart Belt",
    "Cenarion Bracers",
    "Cenarion Belt",
    "Nightslayer Belt",
    "Nightslayer Bracelets",
    "Giantstalker's Bracers",
    "Giantstalker's Belt",
    "Arcanist Belt",
    "Arcanist Bindings",
    "Girdle of Prophecy",
    "Vambraces of Prophecy",
    "Bracers of Might",
    "Belt of Might",
    "Lawbringer Belt",
    "Lawbringer Bracers",
    "Earthfury Belt",
    "Earthfury Bracers",
    "Sulfuron Ingot",
}

function LootRes.trim(s)
    if not s then
        return false
    end
    return string.gsub(s, "^%s*(.-)%s*$", "%1")
end

function LootRes.explode(str, delimiter)
    local result = {}
    local from = 1
    local delim_from, delim_to = string.find(str, delimiter, from, 1, true)
    while delim_from do
        table.insert(result, string.sub(str, from, delim_from - 1))
        from = delim_to + 1
        delim_from, delim_to = string.find(str, delimiter, from, true)
    end
    table.insert(result, string.sub(str, from))
    return result
end
