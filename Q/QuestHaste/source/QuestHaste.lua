QuestHaste_EventHandler = CreateFrame("FRAME")
QuestHaste_EventHandler:RegisterEvent("ADDON_LOADED")

local QuestHaste_EventList = {
    "QUEST_PROGRESS",
    "QUEST_COMPLETE",
    "QUEST_DETAIL",
    "GOSSIP_SHOW",
    "QUEST_GREETING"
}

local QuestHaste_Usage = [[
|cffffff00## QuestHaste Usage:

QuestHaste automatically accepts available quests and advances completed quests.
When a quest reaches the final reward pane, QuestHaste stops only if there is a reward choice.
Hold |cffff0000Shift|r|cffffff00 while opening or selecting a quest to pause automatic quest actions.

* NPC quest selection priority:
    * Completed active quest
    * First available quest
    * First active quest
* Command line options (/qhaste, /questhaste):
    * usage   display usage instructions
    * pause   disable QuestHaste
    * resume   activate QuestHaste
    * complete   advance the current quest dialog|r
]]

function QuestHaste_RegisterEvents()
    for k = 1, table.getn(QuestHaste_EventList) do
        local e = QuestHaste_EventList[k]
        QuestHaste_EventHandler:RegisterEvent(e)
    end
end

function QuestHaste_UnregisterEvents()
    for k = 1, table.getn(QuestHaste_EventList) do
        local e = QuestHaste_EventList[k]
        QuestHaste_EventHandler:UnregisterEvent(e)
    end
end

local function filterEvens(t)
    local r = {}
    for k = 1, table.getn(t) do
        local v = t[k]
        if math.mod(k,2) ~= 0 then
            r[(k+1)/2] = v
        end
    end
    return r
end

local function getCompletedQuestLogTitles()
    local completed = {}
    for k = 1,GetNumQuestLogEntries() do
        local title, level, tag, group, header, isComplete = GetQuestLogTitle(k)
        if title and isComplete then
            completed[title] = true
        end
    end
    return completed
end

local function canAutomate()
    if IsShiftKeyDown() then
        return false
    end
    return true
end

local function completeRewardIfNoChoice()
    local choices = GetNumQuestChoices()
    if choices == 0 then
        GetQuestReward()
        return true
    elseif choices == 1 then
        GetQuestReward(1)
        return true
    end
    return false
end

local function menuHandler(available, active, accept, complete)
    local completed = getCompletedQuestLogTitles()

    for k = 1, table.getn(active) do
        local v = active[k]
        if completed[v] then
            complete(k)
            return
        end
    end

    if table.getn(available) > 0 then
        accept(1)
        return
    end

    if table.getn(active) > 0 then
        complete(1)
        return
    end
end

function QuestHaste_EventHandler.GOSSIP_SHOW()
    local available = filterEvens({GetGossipAvailableQuests()})
    local active = filterEvens({GetGossipActiveQuests()})
    if not canAutomate() then
        return
    end
    menuHandler(available, active, SelectGossipAvailableQuest, SelectGossipActiveQuest)
end

function QuestHaste_EventHandler.QUEST_GREETING()
    local available = {}
    local active = {}
    for k = 1, GetNumAvailableQuests() do
        table.insert(available, GetAvailableTitle(k))
    end
    for k = 1, GetNumActiveQuests() do
        table.insert(active, GetActiveTitle(k))
    end
    if not canAutomate() then
        return
    end
    menuHandler(available, active, SelectAvailableQuest, SelectActiveQuest)
end

function QuestHaste_EventHandler.QUEST_PROGRESS()
    if not canAutomate() then
        return
    end

    if IsQuestCompletable() then
        CompleteQuest()
    end
end

function QuestHaste_EventHandler.QUEST_COMPLETE()
    if not canAutomate() then
        return
    end
    completeRewardIfNoChoice()
end

function QuestHaste_EventHandler.QUEST_DETAIL()
    if not canAutomate() then
        return
    end

    AcceptQuest()
end

function QuestHaste_EventHandler.ADDON_LOADED()
    if arg1 == "QuestHaste" then
        QuestHaste_RegisterEvents()
        QuestHaste_EventHandler:UnregisterEvent("ADDON_LOADED")
        DEFAULT_CHAT_FRAME:AddMessage("|cffffff88QuestHaste|r loaded. See /qhaste usage")
    end
end

QuestHaste_EventHandler:SetScript("OnEvent",
    function ()
        if QuestHaste_EventHandler[event]
        then QuestHaste_EventHandler[event]()
        end
    end
)

function QuestHaste_Proceed()
    if GossipFrame:IsShown() then
        local available = filterEvens({GetGossipAvailableQuests()})
        local active = filterEvens({GetGossipActiveQuests()})
        menuHandler(available, active, SelectGossipAvailableQuest, SelectGossipActiveQuest)
    elseif QuestFrame:IsShown() then
        if QuestFrameAcceptButton:IsShown() then
            AcceptQuest()
        elseif QuestFrameCompleteButton:IsShown() and IsQuestCompletable() then
            CompleteQuest()
        elseif QuestFrameCompleteQuestButton:IsShown() then
            completeRewardIfNoChoice()
        end
    end
end

local function CommandParser(msg, editbox)
    local _,_,command, rest = string.find(msg,"^(%S*)%s*(.-)$")
    if command == "usage" then
        DEFAULT_CHAT_FRAME:AddMessage(QuestHaste_Usage)
    elseif command == "pause" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffff88QuestHaste|r: |cffff0000paused|r.")
        QuestHaste_UnregisterEvents()
    elseif command == "resume" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffff88QuestHaste|r: |cff00ff00active|r.")
        QuestHaste_RegisterEvents()
    elseif command == "complete" then
        QuestHaste_Proceed()
    else
        DEFAULT_CHAT_FRAME:AddMessage("Syntax:\n/qhaste usage\n/qhaste complete\n/qhaste pause\n/qhaste resume");
    end
end
SLASH_QUESTHASTE1 = "/questhaste"
SLASH_QUESTHASTE2 = "/qhaste"
SlashCmdList["QUESTHASTE"] = CommandParser
