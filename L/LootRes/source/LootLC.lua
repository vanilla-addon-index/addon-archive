local LootLCTooltip = CreateFrame("Frame", "LootLC", GameTooltip)

local linkTimer = CreateFrame("Frame")

local comms = CreateFrame("Frame")

local PeoplWhoVotedFrame = CreateFrame("Frame", "PeoplWhoVotedFrame")

local whoResponderTimer = CreateFrame("Frame", "whoResponderTimer")
whoResponderTimer:Hide()
whoResponderTimer:SetScript("OnShow", function()
    this.startTime = math.floor(GetTime());
end)

local LootLC = CreateFrame("Frame")
LootLC:Hide()

LOOT_HISTORY = {} --saved
TIME_TO_VOTE = 30 --saved
TIME_TO_LINK = 10 --saved
local lootHistoryMinRarity = 4

local me = UnitName('player')

local WAITING_FOR_VOTES = "Waiting for votes..."
local WAITING_FOR_ROLLS_FROM = 'Waiting for rolls from'
local WAITING_FOR_ROLLS_AGAIN_FROM = 'Waiting for rolls again from'

function lcprint(a)
    DEFAULT_CHAT_FRAME:AddMessage("|cff69ccf0[LC] |cffffffff" .. a)
end

function LCDebug(a)
    if (me == 'Er2' or
            me == 'Xerrbear' or
            me == 'Testwarr' or
            me == 'Kzktst' or
            me == 'Tabc') then
        lcprint('|cff0070de[LCDebug :' .. time() .. '] |cffffffff[' .. a .. ']')
    end
end

local addonVer = "1.1.7" --dont use letters!

linkTimer:Hide()
linkTimer:SetScript("OnShow", function()
    this.startTime = math.floor(GetTime());
end)


local LCRoster = {};

LootLC.voted = {}

function resetRoster()
    LCRoster = {
        ["Smultron"] = false,
        ["Ilmane"] = false,
        ["Tyrelys"] = false,
        ["Babagiega"] = false,
        ["Faralynn"] = false,
        ["Momo"] = false,
        ["Trepp"] = false,
        ["Chlo"] = false,
        ["Er"] = false,
        ["Chlothar"] = false,
        ["Aurelian"] = false,
        --["Cosmort"] = false, --dev
        --["Xerrbear"] = false --dev
    }
    for name, v in LCRoster do
        LootLC.voted[name] = 0
    end
end

resetRoster()

local classColors = {
    ["warrior"] = { r = 0.78, g = 0.61, b = 0.43, c = "|cffc79c6e" },
    ["mage"] = { r = 0.41, g = 0.8, b = 0.94, c = "|cff69ccf0" },
    ["rogue"] = { r = 1, g = 0.96, b = 0.41, c = "|cfffff569" },
    ["druid"] = { r = 1, g = 0.49, b = 0.04, c = "|cffff7d0a" },
    ["hunter"] = { r = 0.67, g = 0.83, b = 0.45, c = "|cffabd473" },
    ["shaman"] = { r = 0.14, g = 0.35, b = 1.0, c = "|cff0070de" },
    ["priest"] = { r = 1, g = 1, b = 1, c = "|cffffffff" },
    ["warlock"] = { r = 0.58, g = 0.51, b = 0.79, c = "|cff9482c9" },
    ["paladin"] = { r = 0.96, g = 0.55, b = 0.73, c = "|cfff58cba" },
    ["krieger"] = { r = 0.78, g = 0.61, b = 0.43, c = "|cffc79c6e" },
    ["magier"] = { r = 0.41, g = 0.8, b = 0.94, c = "|cff69ccf0" },
    ["schurke"] = { r = 1, g = 0.96, b = 0.41, c = "|cfffff569" },
    ["druide"] = { r = 1, g = 0.49, b = 0.04, c = "|cffff7d0a" },
    ["jäger"] = { r = 0.67, g = 0.83, b = 0.45, c = "|cffabd473" },
    ["schamane"] = { r = 0.14, g = 0.35, b = 1.0, c = "|cff0070de" },
    ["priester"] = { r = 1, g = 1, b = 1, c = "|cffffffff" },
    ["hexenmeister"] = { r = 0.58, g = 0.51, b = 0.79, c = "|cff9482c9" },
}

function getColor(p) --for roster only
    if (string.find(p, "*", 1, true)) then
        p = string.sub(p, 2, string.len(p))
    end
    if p == "Smultron" then return classColors["warrior"].c end
    if p == "Ilmane" then return classColors["shaman"].c end
    if p == "Tyrelys" then return classColors["rogue"].c end
    if p == "Babagiega" then return classColors["warlock"].c end
    if p == "Faralynn" then return classColors["druid"].c end
    if (p == "Momo" or p == "Trepp") then return classColors["mage"].c end
    if p == "Chlo" then return classColors["hunter"].c end
    if p == "Er" then return classColors["priest"].c end
    if (p == "Chlothar" or p == "Aurelian") then return classColors["paladin"].c end
    if p == "Cosmort" then return classColors["warlock"].c end
    if p == "Xerrbear" then return classColors["druid"].c end
    return "|cffffffff"
end

function colorPlayer(p)
    return getColor(p) .. p .. "|cffffffff"
end

function getRGBColor(p)
    if p == "Smultron" then return classColors["warrior"] end
    if p == "Ilmane" then return classColors["shaman"] end
    if p == "Tyrelys" then return classColors["rogue"] end
    if p == "Babagiega" then return classColors["warlock"] end
    if p == "Faralynn" then return classColors["druid"] end
    if p == "Momo" or p == "Trepp" then return classColors["mage"] end
    if p == "Chlo" then return classColors["hunter"] end
    if p == "Er" then return classColors["priest"] end
    if p == "Chlothar" or p == "Aurelian" then return classColors["paladin"] end
    if p == "Cosmort" then return classColors["warlock"] end
    if p == "Xerrbear" then return classColors["druid"] end
    return classColors["priest"]
end

function getRaiderClass(name)
    local i = 0
    for i = 0, GetNumRaidMembers() do
        if (GetRaidRosterInfo(i)) then
            local n, r, s, l, c, f, zone = GetRaidRosterInfo(i);
            if (name == n) then
                return string.lower(c)
            end
        end
    end
    return 'priest'
end

function getRaiderColor(name)
    return classColors[getRaiderClass(trim(name))].c
end

LootLC:SetScript("OnShow", function()
    this.startTime = math.floor(GetTime());
    this.timePassed = 0
    this.timeToVote = TIME_TO_VOTE
end)

--LootLCTooltip:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
LootLCTooltip:RegisterEvent("CHAT_MSG_RAID")
LootLCTooltip:RegisterEvent("CHAT_MSG_SYSTEM") --rolls
LootLCTooltip:RegisterEvent("CHAT_MSG_RAID_LEADER")
LootLCTooltip:RegisterEvent("ADDON_LOADED")

LootLCTooltip:RegisterEvent("LOOT_OPENED")
LootLCTooltip:RegisterEvent("LOOT_SLOT_CLEARED")
LootLCTooltip:RegisterEvent("LOOT_CLOSED")
comms:RegisterEvent("CHAT_MSG_ADDON")

local secondsToLink = TIME_TO_LINK
local T = 1 --start
local C = secondsToLink --count to

local timerChannel = "RAID_WARNING"
local lcItem = ""
local linksOpen = false

PeoplWhoVotedFrame.voters = {}

LootLC.waitingForVotes = false
LootLC.totalVotes = 0
LootLC.timeLeft = 0
LootLC.selectedSlot = 0

LootLC.playerFrames = {}
LootLC.votes = {}
LootLC.currentItem = {} --local list of items
LootLC.recItems = {} --remote list of items
LootLC.myVote = ""
LootLC.myVotes = {}
LootLC.itemName = ""
LootLC.itemLink = ""
LootLC.itemSlotID = 0
LootLC.voteTie = false
LootLC.voteTieRollers = ""

LootLC.waitingForRolls = false
LootLC.tieRollers = {}
LootLC.rollWinner = ""
LootLC.rollTie = false
LootLC.rollTieWinners = ""

LootLC.onlyOnePersonLinked = false

SLASH_LC1 = "/lc"
SlashCmdList["LC"] = function(cmd)
    if (cmd) then
        if (string.find(cmd, 'set', 1, true)) then
            local setEx = string.split(cmd, ' ')
            if (setEx[2] and setEx[3]) then
                if (setEx[2] == 'ttv') then TIME_TO_VOTE = tonumber(setEx[3])
                    lcprint('TIME_TO_VOTE set to ' .. setEx[3])
                end
                if (setEx[2] == 'ttl') then TIME_TO_LINK = tonumber(setEx[3])
                    lcprint('TIME_TO_LINK set to ' .. setEx[3])
                    secondsToLink = TIME_TO_LINK
                    C = secondsToLink
                end
            else
                lcprint('TIME_TO_VOTE (ttv) = ' .. TIME_TO_VOTE)
                lcprint('TIME_TO_LINK (ttl) = ' .. TIME_TO_LINK)
            end
        end
        if (cmd == 'show') then
            LootLC.waitingForVotes = false
            getglobal("LootLCWindow"):Show()
        end
        if (cmd == 'who') then
            lcprint("Listing people with the addon (* = can vote):")
            resetRoster()
            if isAssistOrRL(me) then
                lcprint("*" .. colorPlayer(me) .. " version " .. addonVer .. ")")
            else
                lcprint("" .. colorPlayer(me) .. " version " .. addonVer .. ")")
            end
            if (LCRoster[me] ~= nil) then
                LCRoster[me] = true
            end
            lcWho()
        end
    end
end

LootLC:SetScript("OnUpdate", function()

    if (not this.waitingForVotes) then
        return
    end

    if (math.floor(GetTime()) == math.floor(this.startTime) + 1) then
        if (this.timePassed >= this.timeToVote) then
            LootLC:AddPeopleWhoVoted()
            getglobal('MLToWinnerButton'):Enable()
        else
            this.timePassed = this.timePassed + 1
            this.startTime = math.floor(GetTime())
            LootLC.timeLeft = this.timeToVote - this.timePassed
            LootLC:UpdatePleaseVote()
            if not LootLC.onlyOnePersonLinked then
                getglobal('MLToWinnerButton'):Disable()
            end
        end
    end
end)

function LootLC:AddPeopleWhoVoted()
    local voters = ""
    local i = 0
    for name, t in next, LootLC.voted do
        if (LootLC.voted[name] > 0) then
            i = i + 1
            voters = voters .. getColor(name) .. name .. " "
            if i > 5 then voters = voters .. "\n" i = 0 end
        end
    end
    --voters = "Smultron Ilmane Babagiega Faralynn Tyrelys Momo\nTrepp Chlo  Er Chlothar Aurelian"
    getglobal('PeopleWhoVotedNames'):SetText(voters)
end

function testLB()
    --pfLootButtonX
    if (getglobal("LootButton1Text"):IsVisible()) then
        lcprint("default LB1 is visible")
        if (getglobal("LootButton1Text")) then -- default UI
            getglobal("LootButton1Text"):SetText('[LC] ' .. getglobal("LootButton1Text"):GetText());
            getglobal("LootButton1Text"):SetVertexColor(1, 1, 1);
        end
    end

    if (getglobal("pfLootButton1"):IsVisible()) then

        for index = 0, GetNumLootItems() do
            if GetLootSlotInfo(index) then
                lcprint('lootframenubbutton ' .. index)
            end
        end

        lcprint("pfui LB1 is visible id : " .. getglobal("pfLootButton1"):GetID())
    end

    --        LootFrame_Update()
end

LootLCTooltip:SetScript("OnEvent", function()

    if (event) then

        if (event == 'LOOT_OPENED') then
            -- re circle loot id ?
            --            lcprint('loot opened')
        end
        if (event == 'LOOT_SLOT_CLEARED') then
            --??
        end
        if (event == 'LOOT_CLOSED') then
            --
        end

        if (event == 'ADDON_LOADED' and arg1 == "LootRes") then
            getglobal("TWRaidersFrameTitleText"):SetText("TW Loot Council Vote (v" .. addonVer .. ")")
            secondsToLink = TIME_TO_LINK
            T = 1 --start
            C = secondsToLink --count to
        end
        if ((event == 'CHAT_MSG_RAID' or event == 'CHAT_MSG_RAID_LEADER') and linksOpen) then
            LootLC:CheckLinks(arg1, arg2)
        end
        if (event == 'CHAT_MSG_RAID' or event == 'CHAT_MSG_RAID_LEADER') then
            if (isRealRaidLeader(me)) then
                getglobal('LCResetVoteButton'):Show()
                getglobal('MLToWinnerButtonFrame'):Show()
            else
                getglobal('LCResetVoteButton'):Hide()
                getglobal('MLToWinnerButtonFrame'):Hide()
            end
        end
        if (event == 'CHAT_MSG_SYSTEM') then
            if (LootLC.waitingForRolls) then
                CheckRolls(arg1)
            end
        end
    end
end)

function CheckRolls(arg)

    if (string.find(arg, "rolls", 1, true) and string.find(arg, "(1-100)", 1, true)) then --dev
        local r = string.split(arg, " ")
        local shouldRoll = false
        for k, n in next, LootLC.tieRollers do
            LCDebug('r[1] = *' .. r[1] .. '* vs  LootLC.tieRollers ' .. k .. ' = *' .. n .. '*');
            if (r[1] == k) then
                LCDebug('should roll:' .. k)
                shouldRoll = true
            end
        end
        if (shouldRoll) then
            LCDebug('|cffabd473' .. r[1] .. ' |cffffffffis in rollers list')
            -- double roll protection
            if (LootLC.tieRollers[r[1]] > 0) then
                LCDebug('double roll by ' .. r[1] .. ' found, ignoring')
            else
                LootLC.tieRollers[r[1]] = tonumber(r[3])
            end

            -- detect max
            LootLC.rollWinner = ""
            local max = 0
            for n, r in next, LootLC.tieRollers do
                if (r > max) then
                    max = r
                    LootLC.rollWinner = n
                end
            end

            -- detect ties again
            LootLC.rollTie = false
            LootLC.rollTieWinners = ""
            local coloredRollTieWinners = ""
            if (max > 0) then
                for n, r in next, LootLC.tieRollers do
                    if (n ~= LootLC.rollWinner and r == max) then
                        LootLC.rollTie = true
                    end
                    if (r == max) then
                        LootLC.rollTieWinners = LootLC.rollTieWinners .. n .. " "
                        coloredRollTieWinners = coloredRollTieWinners .. getRaiderColor(n) .. n .. " "
                    end
                end
            end
            LootLC.rollTieWinners = trim(LootLC.rollTieWinners)
            if (LootLC.rollTie) then
                LootLC.rollWinner = "" --because winnerS
                LCDebug('tie detected : ' .. LootLC.rollTieWinners)
                getglobal("MLToWinnerButton"):SetText("TIE Rolls (" .. max .. ") ! Roll again " ..
                        coloredRollTieWinners .. " " .. classColors['priest'].c .. "?")
                SendAddonMessage("TWLC", "command:tieRoll:" .. LootLC.rollTieWinners .. ":" .. max, "RAID")
                getglobal('MLToWinnerButton'):Enable()
            else
                getglobal("MLToWinnerButton"):SetText("Roll Winner : " ..
                        getRaiderColor(LootLC.rollWinner) .. LootLC.rollWinner .. classColors['priest'].c ..
                        " with a " .. classColors['hunter'].c .. max .. classColors['priest'].c .. "!\n Give "
                        .. LootLC.itemLink)
                SendAddonMessage("TWLC", "command:rollWinner:" .. LootLC.rollWinner .. ":" .. max, "RAID")
                getglobal('MLToWinnerButton'):Enable()
            end

        else
            LCDebug('should not have rolled, ignoring')
        end
    end
end

function LootLC:LockVoteButtons(whoShouldRoll)

    if (whoShouldRoll) then
        LCDebug('in lc.lock')
        LCDebug(whoShouldRoll)
        local whoShouldRollColored = ""
        if (string.find(whoShouldRoll, WAITING_FOR_ROLLS_FROM, 1, true)) then
            if (string.find(whoShouldRoll, '...', 1, true)) then -- ... found
                local s1, f1 = string.find(whoShouldRoll, WAITING_FOR_ROLLS_FROM, 1, true)
                local s2, f2 = string.find(whoShouldRoll, '...', 1, true)
                local withoutText = string.sub(whoShouldRoll, f1 + 2, s2 - 2)
                if (withoutText) then
                    LCDebug(withoutText)
                    whoShouldRollColored = classColors['priest'].c .. WAITING_FOR_ROLLS_FROM .. "\n "
                    local whoExploded = string.split(withoutText, " ")
                    for index, w in next, whoExploded do
                        whoShouldRollColored = whoShouldRollColored ..
                                getRaiderColor(w) .. w .. " "
                    end
                    whoShouldRollColored = whoShouldRollColored .. classColors['priest'].c .. " ..."
                    getglobal("VotingOpenTimerText"):SetText(whoShouldRollColored)
                end
            end
        end
        if (string.find(whoShouldRoll, WAITING_FOR_ROLLS_AGAIN_FROM, 1, true)) then
            if (string.find(whoShouldRoll, '...', 1, true)) then -- ... found
                local s1, f1 = string.find(whoShouldRoll, WAITING_FOR_ROLLS_AGAIN_FROM, 1, true)
                local s2, f2 = string.find(whoShouldRoll, '...', 1, true)
                local withoutText = string.sub(whoShouldRoll, f1 + 2, s2 - 2)
                if (withoutText) then
                    LCDebug(withoutText)
                    whoShouldRollColored = classColors['priest'].c .. WAITING_FOR_ROLLS_AGAIN_FROM .. "\n "
                    local whoExploded = string.split(withoutText, " ")
                    for index, w in next, whoExploded do
                        whoShouldRollColored = whoShouldRollColored ..
                                getRaiderColor(w) .. w .. " "
                    end
                    whoShouldRollColored = whoShouldRollColored .. classColors['priest'].c .. " ..."
                    getglobal("VotingOpenTimerText"):SetText(whoShouldRollColored)
                end
            end
        end
    end
    local i = 0
    for name, votes in next, LootLC.votes do
        i = i + 1
        getglobal("PlayerWantsFrame" .. i .. "VoteButton"):Disable()
        getglobal("PlayerWantsFrame" .. i .. "VoteButton"):SetBackdropColor(0.4, 0.4, 0.4, 1)
    end
end

function LootLC:CheckLinks(message, author)
    if (not string.find(message, 'LC:', 1, true)) then
        if (string.find(message, "Hitem", 1, true)) then
            -- item
            local ex = string.split(message, "|")
            local iColor = ""
            if (string.find(ex[2], "c", 1, true) and string.sub(ex[2], 1, 1) == "c") then
                iColor = ex[2]
            end
            local iHitem = ""
            if (string.find(ex[3], "Hitem", 1, true)) then
                iHitem = ex[3]
            end
            local iName = ""
            if (string.sub(ex[4], 1, 2) == "h[") then
                iName = string.sub(ex[4], 2, string.len(ex[4]))
            end
            if (iColor ~= "" and iHitem ~= "" and iName ~= "") then
                --found item

                local exists = false
                for name, votes in next, LootLC.votes do
                    if (name == author) then
                        exists = true
                    end
                end

                if (not exists) then
                    LootLC.votes[author] = 0
                    LootLC.currentItem[author] = iColor .. "=" .. iHitem .. "=" .. iName
                end
            end

        else
            -- random shit chat in raid
        end
    end
end

LootLCTooltip:SetScript("OnHide", function()
    GameTooltip.itemLink = nil
end)

local LootLCHookSetBagItem = GameTooltip.SetBagItem
function GameTooltip.SetBagItem(self, container, slot)
    GameTooltip.itemLink = GetContainerItemLink(container, slot)
    _, GameTooltip.itemCount = GetContainerItemInfo(container, slot)
    return LootLCHookSetBagItem(self, container, slot)
end

local LootLCHookSetLootItem = GameTooltip.SetLootItem
function GameTooltip.SetLootItem(self, slot)
    GameTooltip.itemLink = GetLootSlotLink(slot)
    LootLCHookSetLootItem(self, slot)
end

whoResponderTimer:SetScript("OnUpdate", function()
    -- wait for 5 seconds before outputting who responded to who command
    if (math.floor(GetTime()) == math.floor(this.startTime) + 5) then
        local missingAddonList = ""
        for player, response in next, LCRoster do
            if (not response) then
                missingAddonList = missingAddonList .. " " .. colorPlayer(player)
            end
        end
        lcprint("People without addon: " .. missingAddonList)
        this:Hide()
    end
end)

linkTimer:SetScript("OnUpdate", function()
    if (math.floor(GetTime()) == math.floor(this.startTime) + 1) then
        if (T ~= secondsToLink + 1) then
            SendChatMessage("LC: " .. (C - T + 1) .. "", "RAID")
        end
        linkTimer:Hide()
        if (T < C + 1) then
            T = T + 1
            linkTimer:Show()
        elseif (T == secondsToLink + 1) then
            SendChatMessage("LC: Closed", timerChannel)
            linkTimer:Hide()
            T = 1
            linksOpen = false

            local j = 0
            for n, v in next, LootLC.votes do
                j = j + 1
            end

            if (j == 0) then
                lcprint("Nobody linked")
            else
                LootLC:AddPlayers() -- ML/RL View
                getglobal("LootLCWindow"):SetHeight(170 + j * 40)
            end

        else
            --
        end
    else
        --
    end
end)

function hideLCWindow()
    lcprint("Window closed. Type |cfffff569/lc show |cffffffffto reopen it.")
    LootLCWindow:Hide();
end

function LootWindowCheck()
    if (LootLC.itemName == "") then
        lcprint("Error: no itemname set.")
        return false
    end

    if (LootLC.itemSlotID == 0) then
        lcprint("Error: no item ID (Open Loot Window).")
        return false
    end
    return true
end

function assignBWLLoot()

    -- case where only one person linked
    if (LootLC.onlyOnePersonLinked) then

        local onlyWinnerName = getglobal("PlayerWantsFrame1Name"):GetText();

        LCDebug(" onlyWinnerName = " .. onlyWinnerName)

        local RaiderWinerIndex = 0
        for i = 1, 40 do
            if GetMasterLootCandidate(i) == onlyWinnerName then
                RaiderWinerIndex = i
                break
            end
        end

        if (RaiderWinerIndex == 0) then
            lcprint("Something went wrong, winner name is not on loot list.")
        else
            --        lcprint("should give " .. LootLC.itemSlotID .. "(" .. LootLC.itemName .. ") to raider index : " .. RaiderWinerIndex .. " " .. GetMasterLootCandidate(RaiderWinerIndex))
            if not LootWindowCheck() then return end
            GiveMasterLoot(LootLC.itemSlotID, RaiderWinerIndex);
            SendChatMessage("LC: Giving " .. LootLC.itemLink .. " to " .. onlyWinnerName, "RAID")
            saveLoot(LootLC.itemLink, onlyWinnerName)
            LootLC.itemName = ""
            LootLC.itemSlotID = 0
            LootLC:SendReset()
        end
        return
    end
    -- end case where only one person linked

    if (LootLC.voteTie) then
        SendChatMessage(LootLC.voteTieRollers .. " ROLL for " .. LootLC.itemLink, timerChannel)
        LCDebug(LootLC.voteTieRollers)
        local coloredTieRollers = ""
        local splitVoteTieRollers = string.split(LootLC.voteTieRollers, ' ')
        for index, w in next, splitVoteTieRollers do
            coloredTieRollers = coloredTieRollers .. getRaiderColor(w) .. w .. " "
        end
        coloredTieRollers = coloredTieRollers .. classColors['priest'].c
        getglobal("MLToWinnerButton"):SetText(WAITING_FOR_ROLLS_FROM .. "\n " .. coloredTieRollers .. " ...")
        LootLC.waitingForRolls = true
        local voteTieRollersSplit = string.split(LootLC.voteTieRollers, " ")
        LootLC.tieRollers = {}
        for k, n in next, voteTieRollersSplit do
            LootLC.tieRollers[n] = 0
        end
        LootLC.voteTie = false -- not sure

        comms:SendLockVoteButtons(WAITING_FOR_ROLLS_FROM .. "\n " .. LootLC.voteTieRollers .. " ...")

        getglobal('MLToWinnerButton'):Disable()

        return
    else
        --LootLC.waitingForRolls = false
    end

    if (LootLC.rollTie) then
        local rollTieWinnersSplit = string.split(LootLC.rollTieWinners, " ")
        -- reset
        LootLC.tieRollers = {}
        for k, n in next, rollTieWinnersSplit do
            --reset
            LootLC.tieRollers[n] = 0
        end
        SendChatMessage(LootLC.rollTieWinners .. " ROLL again for " .. LootLC.itemLink, timerChannel)
        getglobal("MLToWinnerButton"):SetText(WAITING_FOR_ROLLS_AGAIN_FROM .. " " .. LootLC.rollTieWinners .. " ...")
        LootLC.waitingForRolls = true
        LootLC.rollTie = false -- not sure

        comms:SendLockVoteButtons(WAITING_FOR_ROLLS_AGAIN_FROM .. " " .. LootLC.rollTieWinners .. " ...")

        getglobal('MLToWinnerButton'):Disable()

        return
    else
        --LootLC.waitingForRolls = false
    end

    if not LootWindowCheck() then return end

    local winnerName = ""
    if (LootLC.waitingForRolls) then
        LCDebug('waiting for rolls')
        -- find winner from rolls cause there was a vote tie
        winnerName = ""
        if (LootLC.rollWinner ~= "") then
            winnerName = LootLC.rollWinner
        end
    else
        -- find winner from votes cause no rolls were rolled
        LCDebug('not waiting for rolls errrrrr')
        winnerName = ""
        local maxVotes = -1
        for name, votes in next, LootLC.votes do
            --        lcprint(name .. " votes: " .. votes)
            if (votes > maxVotes) then
                maxVotes = votes
                winnerName = name
            end
        end
    end

    LCDebug(" winnerName = " .. winnerName)

    local RaiderWinerIndex = 0
    for i = 1, 40 do
        if GetMasterLootCandidate(i) == winnerName then
            RaiderWinerIndex = i
            break
        end
    end

    if (RaiderWinerIndex == 0) then
        lcprint("Something went wrong, winner name is not on loot list.")
    else
        --        lcprint("should give " .. LootLC.itemSlotID .. "(" .. LootLC.itemName .. ") to raider index : " .. RaiderWinerIndex .. " " .. GetMasterLootCandidate(RaiderWinerIndex))
        GiveMasterLoot(LootLC.itemSlotID, RaiderWinerIndex);
        saveLoot(LootLC.itemLink, winnerName)
        SendChatMessage("LC: Giving " .. LootLC.itemLink .. " to " .. winnerName, "RAID")
        LootLC.itemName = ""
        LootLC.itemSlotID = 0
        LootLC:SendReset()
    end
end

function BWLLoot()

    if (not UnitInRaid('player')) then
        lcprint("You are not in a raid.")
        return
    end

    if (not isRealRaidLeader(me)) then
        lcprint("You're not Raid Leader.")
        return
    end

    if GameTooltip.itemLink then

        LootLC:SendReset()

        local _, _, itemLink = string.find(GameTooltip.itemLink, "(item:%d+:%d+:%d+:%d+)");

        local itemName, _, itemRarity, _, _, _, _, itemSlot, _ = GetItemInfo(itemLink)
        local r, g, b = GetItemQualityColor(itemRarity)

        LootLC.itemLink = GameTooltip.itemLink
        LootLC.itemName = itemName
        for id = 0, GetNumLootItems() do
            if GetLootSlotInfo(id) then
                local texture, item = GetLootSlotInfo(id)
                if (item == LootLC.itemName) then
                    LootLC.itemSlotID = id
                else
                end
            end
        end

        linkTimer:Hide()

        T = 1 --start
        C = secondsToLink --count to / to link

        SendChatMessage(" " .. GameTooltip.itemLink .. " LINK (" .. secondsToLink .. " Seconds)", timerChannel);
        getglobal("itemLinkButton"):SetText(GameTooltip.itemLink)

        addOnEnterTooltip(itemLinkButton, itemLink)

        lcItem = itemLink .. "~" .. GameTooltip.itemLink

        linkTimer:Show()
        linksOpen = true
    else
        lcprint("No item found at cursor. Hover over loot.")
    end
end

function ResetVoteButton_OnClick()
    LootLC:SendReset()
end

function LootLC:AddPlayers()

    local i = 0;
    local names = ""
    local currentItems = "" --for sending over
    local ci = {} -- for sending, new
    for name, votes in next, LootLC.votes do
        i = i + 1
        if (not LootLC.playerFrames[i]) then
            LootLC.playerFrames[i] = CreateFrame("Frame", "PlayerWantsFrame" .. i, getglobal("LootLCWindow"), "PlayerWantsFrameTemplate")
        end


        LootLC.playerFrames[i]:SetPoint("TOP", getglobal("VotedItemFrame"), "TOP", 0, -5 - (40 * i))

        getglobal("PlayerWantsFrame" .. i .. "Name"):SetText(name);

        getglobal("PlayerWantsFrame" .. i .. "NameContainerName"):SetText(name)
        getglobal("PlayerWantsFrame" .. i .. "NameContainer"):SetID(i)

        if (LootLC.currentItem[name]) then --local
            currentItems = currentItems .. LootLC.currentItem[name] .. "~"

            ci[name] = LootLC.currentItem[name]

            local ll = LootLC.currentItem[name]
            local iItem = string.split(ll, "=")
            local reformatedItem = "|" .. iItem[1] .. "|" .. iItem[2] .. "|h" .. iItem[3] .. "|h|r"

            getglobal("PlayerWantsFrame" .. i .. "Item"):SetText("");
            getglobal("PlayerWantsFrame" .. i .. "ItemLinkButton"):SetText(reformatedItem);

            addOnEnterTooltip(getglobal("PlayerWantsFrame" .. i .. "ItemLinkButton"), string.sub(iItem[2], 2, string.len(iItem[2])))
        else
            if (LootLC.recItems[name]) then --remote
                local ll = LootLC.recItems[name]
                local iItem = string.split(ll, "=")
                local reformatedItem = "|" .. iItem[1] .. "|" .. iItem[2] .. "|h" .. iItem[3] .. "|h|r"

                getglobal("PlayerWantsFrame" .. i .. "Item"):SetText("");
                getglobal("PlayerWantsFrame" .. i .. "ItemLinkButton"):SetText(reformatedItem);

                addOnEnterTooltip(getglobal("PlayerWantsFrame" .. i .. "ItemLinkButton"), string.sub(iItem[2], 2, string.len(iItem[2])))
            end
        end

        getglobal("PlayerWantsFrame" .. i .. "Votes"):SetText(0);
        getglobal("PlayerWantsFrame" .. i .. "VoteButton"):Enable()
        getglobal("PlayerWantsFrame" .. i .. "VoteButton"):SetBackdropColor(0.05, 0.5, 0, 1)

        local cc = classColors["priest"]

        getglobal("PlayerWantsFrame" .. i .. "Guild"):SetText("")
        local j = 0
        for j = 1, GetNumRaidMembers() do
            local guildName = GetGuildInfo('raid' .. j)
            if (guildName and UnitName('raid' .. j) == name) then
                getglobal("PlayerWantsFrame" .. i .. "Guild"):SetText("<" .. guildName .. ">")
                break
            end
        end

        for j = 0, GetNumRaidMembers() do

            if (GetRaidRosterInfo(j)) then
                local n, r, s, l, c = GetRaidRosterInfo(j);
                if (n == name) then
                    if classColors[string.lower(c)] then
                        cc = classColors[string.lower(c)]
                    end
                    break
                end
            end
        end

        LootLC.playerFrames[i]:SetBackdropColor(cc.r, cc.g, cc.b, 0.8);

        getglobal("PlayerWantsFrame" .. i .. "VoteButton"):SetID(i)
        getglobal("PlayerWantsFrame" .. i .. "VoteButtonCheck"):Hide()
        getglobal("PlayerWantsFrame" .. i .. "VoteButton"):SetText("VOTE")
        getglobal("PlayerWantsFrame" .. i):Show()

        names = names .. " " .. name
    end

    if (isRealRaidLeader(me) and names ~= "") then
        names = trim(names)
        SendAddonMessage("TWLC", "item~" .. lcItem, "RAID")
        -- send curent items and players
        for candidate, item in next, ci do
            SendAddonMessage("TWLC", "ci~" .. candidate .. "~" .. item, "RAID")
            LCDebug("ci~" .. candidate .. "~" .. item)
        end
        SendAddonMessage("TWLC", "currentItems~end", "RAID")
        LCDebug("ci~end")
    end

    if (i == 1) then --only one person linked, he should get the item
        lcprint(classColors['priest'].c .. 'Only ' .. getRaiderColor(names) .. names
                .. classColors['priest'].c .. ' linked ! '
                .. getRaiderColor(names) .. names .. classColors['priest'].c
                .. ' will get ' .. itemLinkButton:GetText() .. '.')
        --        SendChatMessage("LC: Grats " .. names, "RAID")
        getglobal("MLToWinnerButton"):Enable()
        getglobal("MLToWinnerButton"):SetText("Give " .. LootLC.itemLink .. " to " .. getRaiderColor(names) .. names)
        LootLC.onlyOnePersonLinked = true
    else
        LootLC.onlyOnePersonLinked = false
    end

    if (isAssistOrRL(me)) then

        if (isRealRaidAssist(me) and LootLC.onlyOnePersonLinked) then
            --Assist & only one -- no ui/vote needed
            return
        end

        --Leader & Assist & !onlyOneLinked
        LootLC.waitingForVotes = true
        getglobal("LootLCWindow"):Show()
        LootLC:Show() -- start voting timer
    end
end

function PlayerVoteButton_OnClick(voteButtonID)
    local i = 0
    local found = false
    for index, frame in next, LootLC.playerFrames do
        i = i + 1
        if getglobal("PlayerWantsFrame" .. i .. "VoteButton"):GetID(i) == voteButtonID then
            found = true
            LootLC:Vote(getglobal("PlayerWantsFrame" .. i .. "Name"):GetText())
            break
        end
    end
    if (not found) then
        lcprint("Error @ PlayerVoteButton_OnClick, please report this to Er.")
    end
end

function LootLC:Vote(voteName)
    --    lcprint("vote cast : " .. voteName)
    local i = 0
    for name, votes in next, LootLC.votes do
        i = i + 1
        if (name == voteName) then
            if (not LootLC.myVotes[name] or LootLC.myVotes[name] == "-") then
                LootLC.votes[name] = LootLC.votes[name] + 1
                LootLC.myVotes[name] = "+"
                SendAddonMessage("TWLC", "myVote:+:" .. voteName, "RAID")
                getglobal("PlayerWantsFrame" .. i .. "VoteButton"):SetText("")
                getglobal("PlayerWantsFrame" .. i .. "VoteButtonCheck"):Show()
                getglobal("PlayerWantsFrame" .. i .. "VoteButton"):SetBackdropColor(0, 0.88, 0.06, 1)

                if (LootLC.voted[me] ~= nil) then
                    LootLC.voted[me] = LootLC.voted[me] + 1
                else
                    LootLC.voted[me] = 1
                end
            else
                LootLC.votes[name] = LootLC.votes[name] - 1
                SendAddonMessage("TWLC", "myVote:-:" .. voteName, "RAID")
                LootLC.myVotes[name] = "-"
                getglobal("PlayerWantsFrame" .. i .. "VoteButtonCheck"):Hide()
                getglobal("PlayerWantsFrame" .. i .. "VoteButton"):SetText("VOTE")

                getglobal("PlayerWantsFrame" .. i .. "VoteButton"):SetBackdropColor(0.05, 0.5, 0, 1)


                if (LootLC.voted[me] ~= nil) then
                    LootLC.voted[me] = LootLC.voted[me] - 1
                else
                    lcprint('[debug] nu ar trebui sa ajunga aici')
                end
            end
        else
            -- lock all others
            --            getglobal("PlayerWantsFrame" .. i .. "VoteButton"):Disable()
        end
    end

    LootLC:UpdateView()
end

function LootLC:UpdateView()
    local i = 0
    local maxVotes = 0
    local winner = ""
    local winners = ""
    LootLC.voteTieRollers = ""
    LootLC.voteTie = false
    LootLC.totalVotes = 0

    for name, votes in next, LootLC.votes do
        i = i + 1
        --        LootLC.totalVotes = LootLC.totalVotes + votes
        getglobal("PlayerWantsFrame" .. i .. "Votes"):SetText(votes)

        -- tie check
        if votes > maxVotes then
            maxVotes = votes
            winner = name
        end
    end

    -- tie check
    if (maxVotes > 0) then
        for name, votes in next, LootLC.votes do
            if (name ~= winner and votes == maxVotes) then
                LootLC.voteTie = true
            end
            if (votes == maxVotes) then
                winners = winners .. name .. " "
            end
        end
    end

    winners = trim(winners)

    if not LootLC.onlyOnePersonLinked then
        getglobal('MLToWinnerButton'):Disable()
    end
    getglobal("MLToWinnerButton"):SetText(WAITING_FOR_VOTES)
    getglobal('PeopleWhoVotedNames'):SetText(WAITING_FOR_VOTES)

    if (LootLC.voteTie) then
        LootLC.voteTieRollers = winners
        local coloredWinners = ""
        local splitWinners = string.split(winners, ' ')
        for index, w in next, splitWinners do
            coloredWinners = coloredWinners .. getRaiderColor(w) .. w .. " "
        end
        coloredWinners = coloredWinners .. classColors['priest'].c
        getglobal("MLToWinnerButton"):Enable()
        getglobal("MLToWinnerButton"):SetText("VOTE TIE (" .. maxVotes .. " votes) ! \nROLL " .. coloredWinners .. " ?")
    else
        if (winner ~= "") then
            getglobal("MLToWinnerButton"):Enable()
            getglobal("MLToWinnerButton"):SetText("Give " .. LootLC.itemLink .. " to " .. getRaiderColor(winner) .. winner)
        else
            getglobal("MLToWinnerButton"):Disable()
            getglobal("MLToWinnerButton"):SetText(WAITING_FOR_VOTES)
        end
    end

    if (LootLC.timeLeft == 0) then
        LootLC:AddPeopleWhoVoted()
    end

    LootLC:UpdatePleaseVote()
end

function LootLC:UpdatePleaseVote()

    --    LCDebug('update pleasevote trigger')

    local text = ""
    local totalV = ""
    local tl = ""

    if (LootLC.myVote == "") then
        text = "Please vote"
    else
        text = "You voted" -- for " .. LootLC.myVote;
    end

    if (LootLC.timeLeft > 0) then
        tl = LootLC.timeLeft .. "s left..."
    else
        tl = ""
    end

    local onlineRoster = 0

    for i = 0, GetNumRaidMembers() do
        if (GetRaidRosterInfo(i)) then
            local n, r, s, l, c, f, zone = GetRaidRosterInfo(i);
            if (r == 1 or r == 2) then
                for name, v in next, LCRoster do
                    if (name == n and zone ~= "Offline") then
                        onlineRoster = onlineRoster + 1
                        break
                    end
                end
            end
        end
    end

    LootLC.totalVotes = 0

    for name, t in next, LootLC.voted do
        if (LootLC.voted[name]) > 0 then
            LootLC.totalVotes = LootLC.totalVotes + 1
        end
    end

    totalV = "(" .. LootLC.totalVotes .. "/" .. onlineRoster .. " votes)"

    getglobal("VotingOpenTimerText"):SetText(text .. " " .. totalV .. " " .. tl)
end

function LootLC:SendReset()
    LootLC:ResetVars()
    SendAddonMessage("TWLC", "command:reset", "RAID")
end

function LootLC:ResetVars()
    if (isAssistOrRL(me)) then
        lcprint("Voting reset.")
    end
    local i = 0
    for name, votes in next, LootLC.votes do
        i = i + 1
        LootLC.playerFrames[i]:Hide()
    end
    getglobal("LootLCWindow"):Hide()
    --    LootLC.playerFrames = {}
    LootLC.votes = {}
    LootLC.currentItem = {}
    LootLC.recItems = {}
    LootLC.myVote = ""
    LootLC.myVotes = {}
    LootLC.totalVotes = 0
    LootLC.timeLeft = 0

    LootLC.itemName = ""
    LootLC.itemLink = ""
    LootLC.itemSlotID = 0

    LootLC.onlyOnePersonLinked = false
    LootLC.waitingForRolls = false

    getglobal("PeopleWhoVotedNames"):SetText(WAITING_FOR_VOTES)

    PeoplWhoVotedFrame.voters = {}
    PeoplWhoVotedFrame.waitingForVotes = false

    getglobal("MLToWinnerButton"):Disable()
    getglobal("MLToWinnerButton"):SetText(WAITING_FOR_VOTES)

    for name, t in next, LootLC.voted do
        LootLC.voted[name] = 0
    end

    LootLC:UpdatePleaseVote()

    LootLC:Hide()
end

-- comms

function comms:SendLockVoteButtons(who)
    LootLC:LockVoteButtons() -- RL/CL
    if (who) then
        LCDebug('in comms send')
        LCDebug(who)
        SendAddonMessage("TWLC", "command:lock:" .. who, "RAID")
    else
        SendAddonMessage("TWLC", "command:lock:" .. who, "RAID")
    end
end

comms:SetScript("OnEvent", function()
    if (event) then
        if (event == 'CHAT_MSG_ADDON') then

            if (arg1 == "TWLC" and arg4 ~= me) then
                if (not isAssistOrRL(arg4)) then
                    --                    LCDebug("[Error] Got CHAT_MSG_ADDON from a non assist or raid leader. Ignoring.")
                    return
                end
                comms:recSync(arg1, arg2, arg3, arg4)
            end
            -- vote counter
            if (arg1 == "TWLC") then

                if (isRealRaidLeader(me)) then
                    getglobal('LCResetVoteButton'):Show()
                    getglobal('MLToWinnerButtonFrame'):Show()
                else
                    getglobal('LCResetVoteButton'):Hide()
                    getglobal('MLToWinnerButtonFrame'):Hide()
                end

                if (string.find(arg2, 'myVote:', 1, true)) then
                    local vote = string.split(arg2, ':')
                    -- myVote:+:Tyrelys
                    if (vote[2] == '+') then
                        PeoplWhoVotedFrame.voters[arg4] = true
                    else
                        PeoplWhoVotedFrame.voters[arg4] = false
                    end
                    LootLC:UpdatePleaseVote()
                end
            end
        end
    end
end)


function comms:recSync(p, t, c, s) -- prefix, text, channel, sender
    LCDebug(s .. " -> " .. t)
    if (string.find(t, 'item~', 1, true)) then
        local i = string.split(t, "~")
        itemLinkButton:SetText(i[3])
        addOnEnterTooltip(itemLinkButton, i[2])
    end
    if (string.find(t, 'withAddon:', 1, true)) then
        local i = string.split(t, ":")
        local star = ""
        if (string.find(i[3], "*", 1, true)) then
            i[3] = string.sub(i[3], 2, string.len(i[3]))
            star = "*"
        end
        if (i[2] == me) then --i[2] = who requested the who
            if (LCRoster[i[3]] ~= nil) then
                LCRoster[i[3]] = true --i[3] = responder's name
            end
            if (i[4]) then
                LCDebug(i[4])
                local verColor = ""
                if (verNumber(i[4]) == verNumber(addonVer)) then verColor = classColors['hunter'].c end
                if (verNumber(i[4]) < verNumber(addonVer)) then verColor = '|cffff222a' end
                lcprint(star .. colorPlayer(i[3]) .. " version " .. verColor .. i[4])
            else
                lcprint(star .. colorPlayer(i[3]) .. " version unknown)")
            end
        end
    end
    if (string.find(t, 'saveloot~', 1, true)) then
        local com = string.split(t, '~')
        if (com[1] == 'saveloot' and com[2] and com[3]) then
            LOOT_HISTORY[time()] = {
                ['player'] = com[3],
                ['item'] = com[2]
            }
        else
            LCDebug('loot not saved, data: ' .. t)
        end
    end
    if (string.find(t, 'command:', 1, true)) then
        local com = string.split(t, ":")
        if (com[2] == "reset") then
            LootLC:ResetVars()
        end
        if (com[2] == "lock") then
            if (com[3]) then
                LCDebug(com[3]);
                LootLC:LockVoteButtons(com[3])
            else
                LootLC:LockVoteButtons()
            end
        end
        if (com[2] == "rollWinner") then
            if (com[3]) then
                LCDebug(com[3]);
                getglobal("VotingOpenTimerText"):SetText("Roll Winner : " ..
                        getRaiderColor(com[3]) .. com[3] .. classColors['priest'].c ..
                        " with a " .. classColors['hunter'].c .. com[4] .. classColors['priest'].c .. "!")
            else
            end
        end
        if (com[2] == "tieRoll") then
            if (com[3]) then
                LCDebug(com[3]);
                local comTieRollersColored = ''
                local comTieRollersEx = string.split(com[3], " ")
                for index, name in next, comTieRollersEx do
                    comTieRollersColored = comTieRollersColored .. getRaiderColor(name) .. name .. " "
                end
                getglobal("VotingOpenTimerText"):SetText("TIE Rolls : (" .. com[4] .. ") " .. comTieRollersColored)
            else
            end
        end
        if (com[2] == "who") then
            if isAssistOrRL(me) then
                SendAddonMessage("TWLC", "withAddon:" .. s .. ":*" .. me .. ":" .. addonVer, "RAID")
            else
                SendAddonMessage("TWLC", "withAddon:" .. s .. ":" .. me .. ":" .. addonVer, "RAID")
            end
            if (com[3]) then --version number
                if (verNumber(com[3]) > verNumber(addonVer)) then
                    lcprint("New version available |cfffff569" .. com[3] .. "|cffffffff, please update.")
                end
            end
        end
    end
    if (string.find(t, 'ci~', 1, true)) then --new
        local ciCandidateItem = string.split(t, "~")
        if (ciCandidateItem[2] and ciCandidateItem[3]) then
            LootLC.recItems[ciCandidateItem[2]] = ciCandidateItem[3]
            LootLC.votes[ciCandidateItem[2]] = 0
        end
    end
    if (string.find(t, 'currentItems~end', 1, true)) then --new
        local k = 0
        for index, player in LootLC.recItems do
            k = k + 1
        end
        getglobal("LootLCWindow"):SetHeight(170 + k * 40)
        LootLC:AddPlayers()
    end
    if (string.find(t, 'myVote:', 1, true)) then
        local vote = string.split(t, ':')
        local i = 0
        for name, votes in next, LootLC.votes do
            if (name == vote[3]) then
                if (vote[2] == '+') then
                    LootLC.votes[name] = LootLC.votes[name] + 1
                    if (LootLC.voted[s] ~= nil) then
                        LootLC.voted[s] = LootLC.voted[s] + 1
                    else
                        LootLC.voted[s] = 1
                    end
                else
                    LootLC.votes[name] = LootLC.votes[name] - 1
                    if (LootLC.voted[s] ~= nil) then
                        LootLC.voted[s] = LootLC.voted[s] - 1
                    else
                        lcprint('[DEBUG] nu ar trebui sa ajunga aici, report this to ER, myvote in recSync')
                    end
                end
            end
        end

        if (LootLC.timeLeft == 0) then
            LootLC:AddPeopleWhoVoted()
        end

        LootLC:UpdateView()
    end
end

function lcWho()
    SendAddonMessage("TWLC", "command:who:" .. addonVer, "RAID")
    whoResponderTimer:Show()
end


------------------------------------------ utils
function NameContainer_OnEnter(id)
    local totalItems = 0
    local itemHistory = ""

    local historyPlayerName = getglobal("PlayerWantsFrame" .. id .. "NameContainerName"):GetText()
    for lootTime, item in next, LOOT_HISTORY do
        if (historyPlayerName == item['player']) then
            local _, _, itemLink = string.find(item['item'], "(item:%d+:%d+:%d+:%d+)");
            local itemName, _, itemRarity, _, _, _, _, itemSlot, _ = GetItemInfo(itemLink)
            if (itemRarity >= 4) then
                totalItems = totalItems + 1
            end
        end
    end
    GameTooltip:AddLine("Loot history (" .. totalItems .. ")")

    for lootTime, item in pairsByKeys(LOOT_HISTORY) do
        if (historyPlayerName == item['player']) then

            local _, _, itemLink = string.find(item['item'], "(item:%d+:%d+:%d+:%d+)");
            local itemName, _, itemRarity, _, _, _, _, itemSlot, _ = GetItemInfo(itemLink)

            if (itemRarity >= lootHistoryMinRarity) then
                itemHistory = itemHistory .. item['item'] .. " - " .. date("%d/%m %X", lootTime) .. "\n"
            end
        end
    end

    getglobal('LootHistoryFrameTitle'):SetText(historyPlayerName .. "'s Loot History (" .. totalItems .. ")")

    getglobal("LootHistoryFrameItems"):SetText(itemHistory)

    getglobal('LootHistoryFrame'):Show()
end

function NameContainer_OnLeave()
    getglobal('LootHistoryFrame'):Hide()
end

function addOnEnterTooltip(frame, itemLink)
    frame:SetScript("OnEnter", function(self)
        LCTooltip:SetOwner(this, "ANCHOR_RIGHT", -(this:GetWidth() / 2), -(this:GetHeight() / 2));
        LCTooltip:SetHyperlink(itemLink);
        LCTooltip:Show();
    end)
    frame:SetScript("OnLeave", function(self)
        LCTooltip:Hide();
    end)
end

function saveLoot(loot, player)
    --    LOOT_HISTORY = {} --debug reset
    LOOT_HISTORY[time()] = {
        ['player'] = player,
        ['item'] = loot
    }
    SendAddonMessage("TWLC", "saveloot~" .. loot .. "~" .. player, "RAID")
end


function trim(s)
    return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
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


function pairsByKeys(t, f)
    local a = {}
    for n in pairs(t) do table.insert(a, n) end
    table.sort(a, function(a, b) return a > b end)
    local i = 0 -- iterator variable
    local iter = function() -- iterator function
        i = i + 1
        if a[i] == nil then return nil
        else return a[i], t[a[i]]
        end
    end
    return iter
end

function isRealRaidLeader(name)
    for i = 0, GetNumRaidMembers() do
        if (GetRaidRosterInfo(i)) then
            local n, r = GetRaidRosterInfo(i);
            if (n == name and r == 2) then
                return true
            end
        end
    end
    return false
end

function isRealRaidAssist(name)
    for i = 0, GetNumRaidMembers() do
        if (GetRaidRosterInfo(i)) then
            local n, r = GetRaidRosterInfo(i);
            if (n == name and r == 1) then
                return true
            end
        end
    end
    return false
end


function isAssistOrRL(name)
    return isRealRaidAssist(name) or isRealRaidLeader(name)
end

function verNumber(ver)
    return tonumber(string.sub(ver, 1, 1)) * 100 +
            tonumber(string.sub(ver, 3, 3)) * 10 +
            tonumber(string.sub(ver, 5, 5)) * 1
end

--function GameTooltip_OnLoad()
--    this:SetBackdropBorderColor(TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b);
--    this:SetBackdropColor(TOOLTIP_DEFAULT_BACKGROUND_COLOR.r, TOOLTIP_DEFAULT_BACKGROUND_COLOR.g, TOOLTIP_DEFAULT_BACKGROUND_COLOR.b);
--    GameTooltip:AddLine('test')
--end

--function TargetFrame_OnClick(button)
--    if ( SpellIsTargeting() and button == "RightButton" ) then
--        SpellStopTargeting();
--        return;
--    end
--    if ( button == "LeftButton" ) then
--        if ( SpellIsTargeting() ) then
--            SpellTargetUnit("target");
--        elseif ( CursorHasItem() ) then
--            DropItemOnUnit("target");
--        end
--    else
--        TargetRightClickLCMenu:Show()
--        ToggleDropDownMenu(1, nil, TargetFrameDropDown, "TargetFrame", 120, 10);
--    end
--end
