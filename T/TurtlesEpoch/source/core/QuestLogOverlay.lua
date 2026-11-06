-- TurtlesEpoch QuestLogOverlay.lua
-- Places a play button next to each quest title in the Quest Log.
-- Click queues the quest_detail voice line via the manifest hash resolver.
--
-- 1.12 notes:
--   - Button:SetNormalTexture(path_string) does not fill the button in 1.12.
--     Must create a Texture manually, call SetAllPoints(), then use it.
--   - FauxScrollFrame stores a direct .update pointer set at FrameXML init.
--     After replacing QuestLog_Update we must update that pointer too.
--   - Buttons MUST be reparented to titleFrame:GetParent() each update and
--     have SetFrameLevel(titleFrame:GetFrameLevel() + 2) applied.
--     Without this they are children of QuestLogFrame at a lower absolute
--     frame level than the QuestLogTitle buttons and render behind them.

local TT = TurtlesEpoch
local PLAY_TEX = "Interface\\AddOns\\TurtlesEpoch\\textures\\tticon"

-- Gap (px) between the end of the quest title text and the replay icon. The icon
-- sits just after the title, in the open space before the right-aligned
-- "(Complete)"/level, so it stays inside the frame and never covers the [1][2]
-- party-share numbers on the far left of the row.
local ICON_TEXT_GAP = 6

-- Pool of buttons indexed by visible slot. Sized on demand to however many quest
-- rows the (possibly expanded) quest log shows -- do NOT assume a fixed maximum,
-- or orphan icons are left behind past the cap when the quest count shrinks.
local slotButtons = {}

local function GetOrCreateButton(i)
    if not slotButtons[i] then
        -- Initial parent is QuestLogFrame; will be reparented on first update.
        local btn = CreateFrame("Button", nil, QuestLogFrame)
        btn:SetWidth(16)
        btn:SetHeight(16)

        -- 1.12-safe texture: create manually, fill the button, then assign.
        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetTexture(PLAY_TEX)
        tex:SetAllPoints(btn)

        -- Click: resolve quest_detail sound via manifest hash index and queue it.
        -- Fetch the quest description from the log so ResolveQuestSoundPath
        -- can disambiguate same-title quest chains via text-signature lookup.
        btn:SetScript("OnClick", function()
            local title = this.questTitle
            local qIndex = this.questIndex
            if not title or not TT then return end

            local descriptionText = ""
            if qIndex and SelectQuestLogEntry and GetQuestLogQuestText then
                local prevSelected = GetQuestLogSelection and GetQuestLogSelection() or 0
                SelectQuestLogEntry(qIndex)
                descriptionText = GetQuestLogQuestText() or ""
                -- Restore previous selection so we don't disturb the UI.
                if prevSelected and prevSelected > 0 then
                    SelectQuestLogEntry(prevSelected)
                end
            end

            local soundPath, race, npcName = TT:ResolveQuestSoundPath(title, 0, descriptionText)
            if not soundPath then
                TT:Debug("QuestLog: no voice for: " .. title)
                return
            end
            TT:QueueEntryFromDialog(npcName, title, "", "quest_detail", race, soundPath)
        end)

        btn:Hide()
        slotButtons[i] = btn
    end
    return slotButtons[i]
end

local function UpdateQuestLogButtons()
    -- Hide every pooled button first. Iterate the WHOLE pool (not a fixed count):
    -- expanded quest logs show well past the default ~6 rows, so a fixed cap would
    -- leave orphan icons at the bottom when the quest count shrinks.
    for _, btn in pairs(slotButtons) do
        btn:Hide()
    end

    -- Guard: quest log window must be visible.
    if not QuestLogFrame:IsVisible() then return end

    local numEntries = GetNumQuestLogEntries()
    if not numEntries or numEntries == 0 then return end

    local numDisplayed = QUESTS_DISPLAYED or 6
    local offset = FauxScrollFrame_GetOffset(QuestLogListScrollFrame) or 0

    for i = 1, numDisplayed do
        local questIndex = i + offset
        if questIndex > numEntries then break end

        local title, level, suggestedGroup, isHeader = GetQuestLogTitle(questIndex)
        if title and not isHeader then
            local titleFrame = _G["QuestLogTitle" .. i]
            local normalText  = _G["QuestLogTitle" .. i .. "NormalText"]
            if titleFrame and normalText then
                local btn = GetOrCreateButton(i)
                -- Store quest title and log index so OnClick can resolve the
                -- path and fetch the description text for disambiguation.
                btn.questTitle = title
                btn.questIndex = questIndex
                -- Reparent to same level as title buttons and raise frame level
                -- above them so the icon is not rendered behind the scroll frame.
                btn:SetParent(titleFrame:GetParent())
                btn:SetFrameLevel(titleFrame:GetFrameLevel() + 2)
                btn:ClearAllPoints()
                -- Place the icon just after the quest title text, in the open
                -- gap before the right-aligned "(Complete)"/level. This keeps it
                -- inside the quest log frame and clear of the [1][2] party-share
                -- numbers, which sit at the far left of the row. Position by the
                -- rendered text width so it tracks each title's length.
                local textWidth = normalText:GetStringWidth() or 0
                btn:SetPoint("LEFT", normalText, "LEFT", textWidth + ICON_TEXT_GAP, 0)
                btn:Show()
            end
        end
    end
end

-- Replace the global QuestLog_Update function (standard 1.12 hook pattern
-- used by pfQuest and others - hooksecurefunc does not exist in 1.12).
local _origQuestLogUpdate = QuestLog_Update
QuestLog_Update = function()
    _origQuestLogUpdate()
    UpdateQuestLogButtons()
end

-- The FauxScrollFrame keeps a direct pointer to the update function.
-- It was set at FrameXML load time to the original QuestLog_Update.
-- After our replacement we must update both possible scroll frame names.
if QuestLogListScrollFrame then
    QuestLogListScrollFrame.update = QuestLog_Update
end
if QuestLogScrollFrame then
    QuestLogScrollFrame.update = QuestLog_Update
end

-- Turtle's customised quest log repaints the quest list through its own path, so
-- neither replacing QuestLog_Update nor hooking a QUEST_LOG_UPDATE event reliably
-- re-runs our overlay -- a turned-in quest's icon lingers after reopening the log.
-- A throttled ticker re-syncs the icons whenever the quest log is visible, which
-- is bulletproof regardless of how or when the underlying log repaints: since
-- UpdateQuestLogButtons hides every pooled button before reshowing only the
-- current quests, continuously re-running it makes a stale icon impossible. It
-- only runs while the log is open, so the cost is negligible.
local REFRESH_INTERVAL = 0.1
local sinceRefresh = 0
local refreshDriver = CreateFrame("Frame")
refreshDriver:SetScript("OnUpdate", function()
    if not (QuestLogFrame and QuestLogFrame:IsVisible()) then return end
    sinceRefresh = sinceRefresh + (arg1 or 0)
    if sinceRefresh < REFRESH_INTERVAL then return end
    sinceRefresh = 0
    UpdateQuestLogButtons()
end)
