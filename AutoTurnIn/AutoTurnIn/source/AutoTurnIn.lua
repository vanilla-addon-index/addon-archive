-- Auto TurnIn - Turtle / Vanilla

-- Built-in quest names (exactly as shown in game, in your language)
local QUESTS = {
    ["Shard De-Harmonization"] = "ShardDeharm",
    ["Mass Harmonization"]     = "MassHarm",
    ["Shard Harmonization"]    = "ShardHarm",
    ["Sand in Bulk"]           = "SandInBulk",
    ["Corrupted Dream Shards"] = "CorruptedShards"
}

-- Saved variable declared in .toc
AutoTurnInDB = AutoTurnInDB

--------------------------------------------------------
-- Helpers
--------------------------------------------------------

local function EnsureDB()
    if not AutoTurnInDB then
        AutoTurnInDB = {}
    end
    if not AutoTurnInDB.enabled then
        AutoTurnInDB.enabled = {}
    end
    if not AutoTurnInDB.custom then
        AutoTurnInDB.custom = {}
    end

    -- Built-ins: default OFF
    local questName, key
    for questName, key in pairs(QUESTS) do
        if AutoTurnInDB.enabled[key] == nil then
            AutoTurnInDB.enabled[key] = 0
        end
    end

    -- Custom list: just ensure it's a proper table
    local i
    for i = 1, table.getn(AutoTurnInDB.custom) do
        local entry = AutoTurnInDB.custom[i]
        if entry then
            if entry.name == nil then
                entry.name = ""
            end
            if entry.enabled == nil then
                entry.enabled = 0
            end
        end
    end

    -- Debug flag: 0 = off, 1 = on
    if AutoTurnInDB.debug == nil then
        AutoTurnInDB.debug = 0
    end
end

-- Simple debug print
local function DebugPrint(msg)
    if not AutoTurnInDB or AutoTurnInDB.debug ~= 1 then
        return
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cff88ff88[ATI DEBUG]|r " .. tostring(msg))
end

-- Normalize quest names for comparison:
--  - trim spaces
--  - lowercase
--  - strip digits (e.g. [60])
--  - strip punctuation
--  - collapse multiple spaces
local function NormalizeName(name)
    if not name then return "" end

    -- trim
    name = string.gsub(name, "^%s+", "")
    name = string.gsub(name, "%s+$", "")

    -- lowercase
    name = string.lower(name)

    -- remove digits
    name = string.gsub(name, "%d", "")

    -- remove anything that's not a letter or space
    name = string.gsub(name, "[^%a%s]", " ")

    -- collapse multiple spaces
    name = string.gsub(name, "%s+", " ")

    -- trim again
    name = string.gsub(name, "^%s+", "")
    name = string.gsub(name, "%s+$", "")

    return name
end

-- Return true if questTitle is currently the one selected quest
local function IsQuestHandled(questTitle)
    if not questTitle then return false end

    local normTitle = NormalizeName(questTitle)

    -- Built-ins (check which one is enabled and compare normalized names)
    if AutoTurnInDB and AutoTurnInDB.enabled then
        local questName, key
        for questName, key in pairs(QUESTS) do
            if AutoTurnInDB.enabled[key] == 1 then
                if NormalizeName(questName) == normTitle then
                    return true
                end
            end
        end
    end

    -- Custom
    if AutoTurnInDB and AutoTurnInDB.custom then
        local i
        for i = 1, table.getn(AutoTurnInDB.custom) do
            local entry = AutoTurnInDB.custom[i]
            if entry and entry.enabled == 1 and entry.name ~= "" then
                if NormalizeName(entry.name) == normTitle then
                    return true
                end
            end
        end
    end

    return false
end

-- Helper: turn EVERYTHING off (built-ins + custom)
local function DisableAllQuests()
    if AutoTurnInDB then
        if AutoTurnInDB.enabled then
            local qn, k
            for qn, k in pairs(QUESTS) do
                AutoTurnInDB.enabled[k] = 0
            end
        end
        if AutoTurnInDB.custom then
            local i
            for i = 1, table.getn(AutoTurnInDB.custom) do
                if AutoTurnInDB.custom[i] then
                    AutoTurnInDB.custom[i].enabled = 0
                end
            end
        end
    end
end

--------------------------------------------------------
-- UI frame (resizable) with built-in + custom list
--------------------------------------------------------

local ui = CreateFrame("Frame", "AutoTurnInFrame", UIParent)
ui:SetWidth(300)
ui:SetHeight(260)
ui:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
ui:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
ui:SetMovable(true)
ui:EnableMouse(true)
ui:RegisterForDrag("LeftButton")
ui:SetResizable(true)
if ui.SetMinResize then
    ui:SetMinResize(260, 200)
end

ui:SetScript("OnDragStart", function()
    this:StartMoving()
end)
ui:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
end)

ui:Hide()

local title = ui:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", 0, -8)
title:SetText("Auto Turn-in")

-- Resize grip in bottom-right
local resizeBtn = CreateFrame("Button", "AutoTurnInResize", ui)
resizeBtn:SetWidth(16)
resizeBtn:SetHeight(16)
resizeBtn:SetPoint("BOTTOMRIGHT", ui, "BOTTOMRIGHT", -4, 4)
resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
resizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

resizeBtn:SetScript("OnMouseDown", function()
    this:GetParent():StartSizing("BOTTOMRIGHT")
    this:GetParent():SetUserPlaced(true)
end)
resizeBtn:SetScript("OnMouseUp", function()
    this:GetParent():StopMovingOrSizing()
end)

local checkboxes = {}
local customRows = {}   -- { frame=row, editBox=eb, checkBox=cb, deleteButton=del }

--------------------------------------------------------
-- Built-in checkboxes (radio style)
--------------------------------------------------------

local function CreateBuiltInQuestCheckbox(labelText, key, index)
    local name = "AutoTurnInCheck"..index
    local cb = CreateFrame("CheckButton", name, ui, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 12, -20 - (index - 1) * 22)

    local textFS = getglobal(name.."Text")
    if textFS then
        textFS:SetText(labelText)
    end

    cb.key = key

    cb:SetScript("OnClick", function()
        if not (AutoTurnInDB and AutoTurnInDB.enabled and AutoTurnInDB.custom) then
            return
        end

        local clickedKey = this.key
        if this:GetChecked() then
            -- Radio behaviour: turn off everything, then turn this one on
            DisableAllQuests()
            AutoTurnInDB.enabled[clickedKey] = 1

            -- Update all built-in checkboxes
            local qn, k2
            for qn, k2 in pairs(QUESTS) do
                if checkboxes[k2] then
                    if k2 == clickedKey then
                        checkboxes[k2]:SetChecked(1)
                    else
                        checkboxes[k2]:SetChecked(nil)
                    end
                end
            end

            -- Turn off all custom checkboxes in UI
            local i
            for i = 1, table.getn(customRows) do
                if customRows[i].checkBox then
                    customRows[i].checkBox:SetChecked(nil)
                end
            end
        else
            -- Uncheck -> no quest selected
            AutoTurnInDB.enabled[clickedKey] = 0
        end
    end)

    checkboxes[key] = cb
end

do
    local idx = 1
    local questName, key
    for questName, key in pairs(QUESTS) do
        CreateBuiltInQuestCheckbox(questName, key, idx)
        idx = idx + 1
    end
end

--------------------------------------------------------
-- Custom quests: scrollable list + Add button
--------------------------------------------------------

-- Count built-in to know where to place custom section
local builtinCount = 0
local _qn, _k
for _qn, _k in pairs(QUESTS) do
    builtinCount = builtinCount + 1
end

local customLabel = ui:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
local customStartY = -20 - builtinCount * 22 - 10
customLabel:SetPoint("TOPLEFT", 12, customStartY)
customLabel:SetText("Custom quests (exact quest name):")

-- Scroll frame for rows
local scrollFrame = CreateFrame("ScrollFrame", "AutoTurnInScrollFrame", ui, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", ui, "TOPLEFT", 12, customStartY - 16)
scrollFrame:SetPoint("BOTTOMRIGHT", ui, "BOTTOMRIGHT", -32, 40)

local scrollChild = CreateFrame("Frame", "AutoTurnInScrollChild", scrollFrame)
scrollChild:SetWidth(220)
scrollChild:SetHeight(1)
scrollFrame:SetScrollChild(scrollChild)

-- "Add Quest" button
local addButton = CreateFrame("Button", "AutoTurnInAddButton", ui, "UIPanelButtonTemplate")
addButton:SetText("Add Quest")
addButton:SetWidth(90)
addButton:SetHeight(20)
addButton:SetPoint("BOTTOMLEFT", ui, "BOTTOMLEFT", 12, 16)

--------------------------------------------------------
-- Custom rows (dynamic)
--------------------------------------------------------

local function ClearCustomRows()
    local i
    for i = 1, table.getn(customRows) do
        if customRows[i].frame then
            customRows[i].frame:Hide()
        end
    end
    customRows = {}
end

local function CreateCustomRow(index, name, enabled)
    local row = CreateFrame("Frame", "AutoTurnInCustomRow"..index, scrollChild)
    row:SetHeight(20)
    row:SetWidth(220)
    row.index = index

    if index == 1 then
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)
    else
        row:SetPoint("TOPLEFT", customRows[index - 1].frame, "BOTTOMLEFT", 0, -4)
    end

    local eb = CreateFrame("EditBox", "AutoTurnInCustomEdit"..index, row, "InputBoxTemplate")
    eb:SetAutoFocus(false)
    eb:SetHeight(18)
    eb:SetWidth(150)
    eb:SetMaxLetters(80)

    -- Offset right so text is not clipped
    eb:SetPoint("LEFT", row, "LEFT", 4, 0)

    -- Prevent text clipping on the left
    eb:SetTextInsets(4, 4, 2, 2)

    eb.index = index
    eb:SetText(name or "")

    eb:SetScript("OnEscapePressed", function()
        this:ClearFocus()
    end)
    eb:SetScript("OnEnterPressed", function()
        this:ClearFocus()
    end)
    eb:SetScript("OnEditFocusLost", function()
        if AutoTurnInDB and AutoTurnInDB.custom then
            local idx = this.index
            if AutoTurnInDB.custom[idx] then
                AutoTurnInDB.custom[idx].name = this:GetText() or ""
            end
        end
    end)

    local cb = CreateFrame("CheckButton", "AutoTurnInCustomCheck"..index, row, "UICheckButtonTemplate")
    cb:SetWidth(20)
    cb:SetHeight(20)
    cb:SetPoint("LEFT", eb, "RIGHT", 4, 0)
    cb.index = index
    cb:SetChecked(enabled == 1)

    cb:SetScript("OnClick", function()
        if not (AutoTurnInDB and AutoTurnInDB.custom and AutoTurnInDB.enabled) then
            return
        end

        local idx = this.index
        local entry = AutoTurnInDB.custom[idx]
        if not entry then return end

        if this:GetChecked() then
            -- Radio behaviour: everything off, then this ON
            DisableAllQuests()
            entry.enabled = 1

            -- Uncheck all built-ins in UI
            local qn, kk
            for qn, kk in pairs(QUESTS) do
                if checkboxes[kk] then
                    checkboxes[kk]:SetChecked(nil)
                end
            end

            -- Uncheck all OTHER custom rows in UI + DB
            local j
            for j = 1, table.getn(customRows) do
                if j ~= idx then
                    if AutoTurnInDB.custom[j] then
                        AutoTurnInDB.custom[j].enabled = 0
                    end
                    if customRows[j].checkBox then
                        customRows[j].checkBox:SetChecked(nil)
                    end
                end
            end
        else
            -- Uncheck -> none selected
            entry.enabled = 0
        end
    end)

    local del = CreateFrame("Button", "AutoTurnInCustomDel"..index, row, "UIPanelButtonTemplate")
    del:SetText("X")
    del:SetWidth(20)
    del:SetHeight(18)
    del:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    del.index = index

    del:SetScript("OnClick", function()
        if not (AutoTurnInDB and AutoTurnInDB.custom) then
            return
        end
        local idx = this.index

        -- If we're deleting the active quest, just remove it; nothing will be active afterwards
        table.remove(AutoTurnInDB.custom, idx)
        -- Rebuild everything to fix indices
        ClearCustomRows()

        local count = table.getn(AutoTurnInDB.custom)
        local i
        for i = 1, count do
            local entry = AutoTurnInDB.custom[i]
            CreateCustomRow(i, entry.name, entry.enabled)
        end

        -- Adjust scroll child height
        scrollChild:SetHeight(count * 24 + 4)
    end)

    customRows[index] = {
        frame = row,
        editBox = eb,
        checkBox = cb,
        deleteButton = del,
    }
end

local function RebuildCustomRowsFromDB()
    ClearCustomRows()

    if not (AutoTurnInDB and AutoTurnInDB.custom) then
        scrollChild:SetHeight(1)
        return
    end

    local count = table.getn(AutoTurnInDB.custom)
    local i
    for i = 1, count do
        local entry = AutoTurnInDB.custom[i]
        if entry then
            CreateCustomRow(i, entry.name, entry.enabled)
        end
    end

    if count == 0 then
        scrollChild:SetHeight(1)
    else
        scrollChild:SetHeight(count * 24 + 4)
    end
end

addButton:SetScript("OnClick", function()
    if not AutoTurnInDB then return end
    if not AutoTurnInDB.custom then
        AutoTurnInDB.custom = {}
    end

    local newEntry = { name = "", enabled = 0 }
    table.insert(AutoTurnInDB.custom, newEntry)

    RebuildCustomRowsFromDB()
end)

--------------------------------------------------------
-- Slash command
--------------------------------------------------------

SLASH_AUTOTURNIN1 = "/autoturnin"
SlashCmdList["AUTOTURNIN"] = function()
    if ui:IsShown() then
        ui:Hide()
    else
        ui:Show()
    end
end

SLASH_AUTOTURNIN2 = "/ati"
SlashCmdList["AUTOTURNIN"] = SlashCmdList["AUTOTURNIN"]

SLASH_AUTOTURNINDEBUG1 = "/atidebug"
SlashCmdList["AUTOTURNINDEBUG"] = function()
    if not AutoTurnInDB then AutoTurnInDB = {} end
    if AutoTurnInDB.debug == 1 then
        AutoTurnInDB.debug = 0
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00AutoTurnIn debug: |cffff5555OFF|r")
    else
        AutoTurnInDB.debug = 1
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00AutoTurnIn debug: |cff55ff55ON|r")
    end
end

--------------------------------------------------------
-- Core auto-turn-in logic (Vanilla style)
--------------------------------------------------------

local f = CreateFrame("Frame")
f:RegisterEvent("VARIABLES_LOADED")
f:RegisterEvent("GOSSIP_SHOW")
f:RegisterEvent("QUEST_GREETING")
f:RegisterEvent("QUEST_DETAIL")
f:RegisterEvent("QUEST_PROGRESS")
f:RegisterEvent("QUEST_COMPLETE")

f:SetScript("OnEvent", function()
    -- in 1.12, `event` is global; args: arg1, arg2, ...

    if event == "VARIABLES_LOADED" then
        EnsureDB()

        -- sync built-in checkbox states
        local questName, key
        for questName, key in pairs(QUESTS) do
            if checkboxes[key] then
                checkboxes[key]:SetChecked(AutoTurnInDB.enabled[key] == 1)
            end
        end

        -- build custom rows from DB
        RebuildCustomRowsFromDB()

        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00AutoTurnIn loaded.|r Type |cffffff00/ati|r.")

    elseif event == "GOSSIP_SHOW" then
        ------------------------------------------------
        -- Gossip questgivers: auto-select quests
        ------------------------------------------------

        DebugPrint("---- GOSSIP_SHOW ----")

        -- AVAILABLE quests
        local available = { GetGossipAvailableQuests() }
        local totalAvail = table.getn(available)
        local questIndex = 0

        DebugPrint("Available Quests:")

        local i
        for i = 1, totalAvail do
            if type(available[i]) == "string" then
                questIndex = questIndex + 1   -- this is the Nth quest in the list
                DebugPrint("  ["..questIndex.."] " .. available[i])
                local qTitle = available[i]
                if IsQuestHandled(qTitle) then
                    SelectGossipAvailableQuest(questIndex)
                    return
                end
            end
        end

        -- ACTIVE quests (for turn-in)
        local active = { GetGossipActiveQuests() }
        local totalAct = table.getn(active)
        questIndex = 0
        
        DebugPrint("Active Quests:")
        
        for i = 1, totalAct do
            if type(active[i]) == "string" then
                questIndex = questIndex + 1
                DebugPrint("  ["..questIndex.."] " .. active[i])
                local aTitle = active[i]
                if IsQuestHandled(aTitle) then
                    SelectGossipActiveQuest(questIndex)
                    return
                end
            end
        end

    elseif event == "QUEST_GREETING" then
        ------------------------------------------------
        -- Non-gossip questgivers (classic-style)
        ------------------------------------------------

        DebugPrint("---- QUEST_GREETING ----")

        local numAvail = GetNumAvailableQuests()
        DebugPrint("Available ("..numAvail.."):")

        local i
        for i = 1, numAvail do
            local qTitle = GetAvailableTitle(i)
            DebugPrint("  ["..i.."] " .. tostring(qTitle))
            if IsQuestHandled(qTitle) then
                SelectAvailableQuest(i)
                return
            end
        end

        local numAct = GetNumActiveQuests()
        DebugPrint("Active ("..numAct.."):")

        for i = 1, numAct do
            local aTitle, isComplete = GetActiveTitle(i)
            DebugPrint("  ["..i.."] " .. tostring(aTitle) .. "  (complete=" .. tostring(isComplete) .. ")")

            -- IMPORTANT CHANGE: don't require isComplete here, just select if handled.
            if IsQuestHandled(aTitle) then
                SelectActiveQuest(i)
                return
            end
        end

    elseif event == "QUEST_DETAIL" then
        local qTitle = GetTitleText()
        if IsQuestHandled(qTitle) then
            AcceptQuest()
        end

    elseif event == "QUEST_PROGRESS" then
        local qTitle = GetTitleText()
        if IsQuestHandled(qTitle) and IsQuestCompletable() then
            CompleteQuest()
        end

    elseif event == "QUEST_COMPLETE" then
        local qTitle = GetTitleText()
        if IsQuestHandled(qTitle) then
            local numChoices = GetNumQuestChoices()
            if numChoices == 0 then
                GetQuestReward(1)
            else
                -- If there are choices, this still just picks first.
                GetQuestReward(1)
            end
        end
    end
end)
