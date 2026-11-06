-- =========================
-- QuestShell Core — Events / Automation
-- Turtle/Vanilla (1.12) safe
-- =========================

-- Expect these from other files:
-- QS_GuideData(), QS_GuideState(), QS_CurrentStep(), QS_CurrentChapterIndex(),
-- QS_ChapterCount(), QS_LoadNextGuideIfAny(), QuestShell.SetChapter,
-- QS_UI_IsStepCompleted(i), QS_UI_SetStepCompleted(i, bool),
-- QS_Print(msg), QS_D(msg)
-- + From utils: QS_CountItemInBags, QS_FindItemInBags, QS_IsQuestObjectivesCompleteByIndex

-- ------------------------------------------------------------

-- ------------------------------------------------------------
-- Local helpers / state
-- ------------------------------------------------------------
-- Item usage tracker (for USE_ITEM behavior); survives across events and is reset on advance
local itemTrack = { itemId = nil, prevCount = nil, lastChangeTime = 0 }

local awaitingAcceptTitle = nil
local travelUpdateAccum = 0

-- NEW: suppress passive resync for titles just handled by QUEST_ACCEPTED (one tick)
local _qsSkipOnceTitles = {}   -- set of lowercase quest titles

-- Behavior hook state
local _qsArrivedForStepIdx = nil     -- remember which step we've already "arrived" at (for arrow suppression)
local _qsLastStepIdx = nil           -- last seen step index
local _qsStepState = {}              -- ephemeral per-current-step state (cleared when step changes)

local function Now() return GetTime and GetTime() or 0 end
local function Safe(t) return t or "" end
local function tlen(t) local n=0; if type(t)=="table" then for _ in pairs(t) do n=n+1 end end; return n end

local function _BehaviorFor(step)
    if not step or not step.type or not QS_BehaviorFor then return nil end
    return QS_BehaviorFor(step.type)
end

-- Internal: get per-step state (resets on step change)
local function _StateFor(idx)
    if not idx then return nil end
    _qsStepState[idx] = _qsStepState[idx] or {}
    return _qsStepState[idx]
end


-- --- NPC gating: only act when we're talking to the intended NPC ----------
local function QS_GetCurrentNpcName()
    if UnitName and UnitName("target") then return UnitName("target") end
    if GossipFrame and GossipFrame:IsShown() and GossipFrameNpcNameText and GossipFrameNpcNameText:GetText() then
        return GossipFrameNpcNameText:GetText()
    end
    if QuestFrame and QuestFrame:IsShown() and QuestFrameNpcNameText and QuestFrameNpcNameText:GetText() then
        return QuestFrameNpcNameText:GetText()
    end
    return nil
end

local function QS_ShouldAutoHandleNpcForStep(step)
    if not step or not step.npc or not step.npc.name then return true end
    local need = string.lower(step.npc.name or "")
    local cur  = string.lower(QS_GetCurrentNpcName() or "")
    return (cur ~= "" and need ~= "" and cur == need)
end
-- --------------------------------------------------------------------------

local function QS__LogQuestID(logIndex)
    return nil
end

-- Collect expected labels for an ACCEPT step (used to disambiguate)
local function QS__CollectExpectedLabelsForStep(stepIndex, steps)
    local labels, s = {}, (steps and steps[stepIndex]) or nil
    if not s then return labels end
    local function push(v) if v and v ~= "" then labels[table.getn(labels)+1] = v end end

    if s.acceptLabels and type(s.acceptLabels) == "table" then
        local k = 1
        while s.acceptLabels[k] do push(s.acceptLabels[k]); k = k + 1 end
        return labels
    end

    if s.objectives and type(s.objectives) == "table" then
        local k = 1
        while s.objectives[k] do local o=s.objectives[k]; push(o and (o.label or o.text)); k = k + 1 end
        return labels
    end

    local i, n, lim = stepIndex + 1, table.getn(steps or {}), stepIndex + 8
    if lim > n then lim = n end
    while i <= lim do
        local t = steps[i]
        if t and t.type == "COMPLETE" and t.title == s.title and t.objectives then
            local k = 1
            while t.objectives[k] do local o=t.objectives[k]; push(o and (o.label or o.text)); k = k + 1 end
            break
        end
        i = i + 1
    end
    return labels
end

-- Count how many ELIGIBLE ACCEPT steps share this title (ignore completion state)
local function QS__DupStepsForTitle(title)
    local steps = QS_GuideData and QS_GuideData() or {}
    local dup, i = 0, 1
    while steps[i] do
        local s = steps[i]
        if s and s.type == "ACCEPT" and s.title == title then
            local eligible = (not QS_StepIsEligible) or QS_StepIsEligible(s)
            if eligible then dup = dup + 1 end
        end
        i = i + 1
    end
    return dup
end

-- Count quest log entries with a given title
local function QS__DupLogForTitle(title)
    local n = GetNumQuestLogEntries() or 0
    local dup, i = 0, 1
    while i <= n do
        local t, _, _, _, isHeader = GetQuestLogTitle(i)
        if not isHeader and t == title then dup = dup + 1 end
        i = i + 1
    end
    return dup
end

-- Score a log quest against labels (rough disambiguator for ACCEPT)
local function QS__ScoreLogIndexAgainstLabels(logIndex, labels)
    if not logIndex or not labels or table.getn(labels) == 0 then return 0 end
    local n = GetNumQuestLeaderBoards(logIndex) or 0
    local score, j = 0, 1
    while j <= n do
        local txt = GetQuestLogLeaderBoard(j, logIndex)
        if txt then
            local low = string.lower(txt)
            local k = 1
            while labels[k] do
                local lab = string.lower(labels[k] or "")
                if lab ~= "" and string.find(low, lab, 1, true) then score = score + 1 end
                k = k + 1
            end
        end
        j = j + 1
    end
    return score
end

-- Returns the earliest step index in the current guide where:
--   type == "ACCEPT", titles match, step is eligible, and not completed.
local function QS__FirstUncheckedAcceptStepIndexForTitle(title)
    if not title then return nil end
    local steps = QS_GuideData and QS_GuideData() or {}
    local i = 1
    while steps[i] do
        local s = steps[i]
        if s and s.type == "ACCEPT" and s.title == title then
            local eligible = (not QS_StepIsEligible) or QS_StepIsEligible(s)
            local notDone  = (not QS_UI_IsStepCompleted) or (not QS_UI_IsStepCompleted(i))
            if eligible and notDone then
                return i
            end
        end
        i = i + 1
    end
    return nil
end

-- Given a quest log index (from QUEST_ACCEPTED), pick the step to mark.
local function QS__BestAcceptStepForLogIndex(logIndex)
    if not logIndex then return nil end
    local title, qLevel = GetQuestLogTitle(logIndex)
    if not title then return nil end

    local steps = QS_GuideData() or {}
    local levelMatches = {}
    local firstUnchecked = nil

    local i = 1
    while steps[i] do
        local s = steps[i]
        if s and s.type == "ACCEPT" and s.title == title then
            local eligible = (not QS_StepIsEligible) or QS_StepIsEligible(s)
            local notDone  = (not QS_UI_IsStepCompleted) or (not QS_UI_IsStepCompleted(i))
            if eligible and notDone then
                if not firstUnchecked then firstUnchecked = i end
                if qLevel and s.level and s.level == qLevel then
                    table.insert(levelMatches, i)
                end
            end
        end
        i = i + 1
    end

    -- Unique level match wins
    local lmCount = table.getn(levelMatches) -- 5.0-safe length
    if lmCount == 1 then return levelMatches[1] end
    return firstUnchecked
end

-- For a given ACCEPT step index, return the quest-log index iff THIS step
-- is the earliest unchecked one for that title. Otherwise return nil.
local function QS__BestLogIndexForAcceptStep(stepIndex)
    local steps = QS_GuideData() or {}
    local s = steps[stepIndex]; if not s or not s.title then return nil end

    local title, wantLevel = s.title, s.level

    -- Hard gate: only the earliest unchecked step with this title may bind.
    local firstUncheckedIdx = QS__FirstUncheckedAcceptStepIndexForTitle and QS__FirstUncheckedAcceptStepIndexForTitle(title) or nil
    if firstUncheckedIdx and firstUncheckedIdx ~= stepIndex then
        return nil
    end

    -- Find matching entries in the quest log.
    local n = GetNumQuestLogEntries() or 0
    local firstLogIdx, exactLevelIdx = nil, nil
    local i = 1
    while i <= n do
        local t, qLevel, _, _, isHeader = GetQuestLogTitle(i)
        if not isHeader and t == title then
            if not firstLogIdx then firstLogIdx = i end
            if wantLevel and qLevel and wantLevel == qLevel then
                exactLevelIdx = i
            end
        end
        i = i + 1
    end

    -- Prefer exact level when available; else take the first occurrence.
    if exactLevelIdx then return exactLevelIdx end
    return firstLogIdx
end

local function QS__SelectAvailableIndexForAccept(step)
    if not step or step.type ~= "ACCEPT" or not step.title then return nil end
    local wantTitle  = step.title
    local wantLevel  = step.level
    local n = GetNumAvailableQuests() or 0

    local firstMatch, matchCount, chosen = nil, 0, nil
    local i = 1
    while i <= n do
        local t = GetAvailableTitle(i)
        if t == wantTitle then
            matchCount = matchCount + 1
            if not firstMatch then firstMatch = i end
            if wantLevel then
                local lvl = GetAvailableLevel(i)
                if lvl and lvl == wantLevel then
                    chosen = i; break
                end
            end
        end
        i = i + 1
    end
    if chosen then return chosen end
    if matchCount == 1 then return firstMatch end
    return nil
end

-- Find the next step index > fromIndex that is NOT completed and IS eligible.
local function QS__FindNextEligibleIncomplete(steps, completedSet, fromIndex)
    local n = table.getn(steps or {})
    local i = (fromIndex or 0) + 1
    while i <= n do
        local s = steps[i]
        local eligible = (not QS_StepIsEligible) or QS_StepIsEligible(s)
        if s and eligible and (not completedSet or not completedSet[i]) then
            return i
        end
        i = i + 1
    end
    return n + 1 -- sentinel: past the end
end

-- Find the item we should consider as "use-item" for this step (id and/or name)
-- Find the item we should consider as "use-item" for this step (id and/or name)
local function QS__UseItemSpecForStep(step)
    if not step then return nil, nil end
    local stype = string.upper(step.type or "")

    -- Pure USE_ITEM steps
    if stype == "USE_ITEM" then
        return step.itemId, step.itemName
    end

    -- COMPLETE steps: accept either an objective {kind="use_item", ...} OR a top-level itemId/itemName
    if stype == "COMPLETE" then
        -- objectives path
        if step.objectives and type(step.objectives) == "table" then
            local i = 1
            while step.objectives[i] do
                local o = step.objectives[i]
                if o and string.lower(o.kind or "") == "use_item" then
                    return o.itemId, (o.label or step.itemName)
                end
                i = i + 1
            end
        end
        -- top-level item fallback
        if step.itemId or step.itemName then
            return step.itemId, step.itemName
        end
    end

    return nil, nil
end

-- Lua 5.0-safe bag finder by ID or Name; prefers ID when available
local function QS__FindItemInBags_ByIdOrName(id, name)
    if QS_FindItemInBags and id then
        local b, s = QS_FindItemInBags(id)
        if b and s then return b, s end
    end
    if not name or name == "" then return nil, nil end

    -- fallback name search (Lua 5.0: use string.find with capture)
    if GetContainerNumSlots and GetContainerItemLink then
        for bag = 0, 4 do
            local slots = GetContainerNumSlots(bag)
            if slots and slots > 0 then
                for slot = 1, slots do
                    local link = GetContainerItemLink(bag, slot)
                    if link then
                        local _, _, nm = string.find(link, "%[(.+)%]")  -- capture text between [...]
                        if nm and string.lower(nm) == string.lower(name) then
                            return bag, slot
                        end
                    end
                end
            end
        end
    end
    return nil, nil
end

-- Count items by id or (fallback) name
local function QS__CountItemInBags_ByIdOrName(id, name)
    if QS_CountItemInBags and id then
        return QS_CountItemInBags(id) or 0
    end
    if not name or name == "" then return 0 end
    local total = 0
    if GetContainerNumSlots and GetContainerItemLink and GetContainerItemInfo then
        for bag = 0, 4 do
            local slots = GetContainerNumSlots(bag)
            if slots and slots > 0 then
                for slot = 1, slots do
                    local link = GetContainerItemLink(bag, slot)
                    if link then
                        local _, _, nm = string.find(link, "%[(.+)%]")
                        if nm and string.lower(nm) == string.lower(name) then
                            local tex, itemName, count = GetContainerItemInfo(bag, slot)
                            total = total + (count or 1)
                        end
                    end
                end
            end
        end
    end
    return total
end

-- ------------------------------------------------------------
-- Step advancement that skips steps already checked
-- ------------------------------------------------------------
-- Advance current step; mark current complete unless markCurrentComplete == false
function QS_AdvanceStep(markCurrentComplete)
    local st = QS_GuideState and QS_GuideState() or nil
    if not st then return end

    local chapter = (QS_CurrentChapterIndex and QS_CurrentChapterIndex()) or 1
    st.completedByChapter = st.completedByChapter or {}

    -- build a SET of completed indices from saved ARRAY
    local arr = st.completedByChapter[chapter] or {}
    local set = {}
    local i = 1
    while arr and arr[i] do set[arr[i]] = true; i = i + 1 end

    local steps = (QS_GuideData and QS_GuideData()) or {}
    local n = table.getn(steps or {})
    if n == 0 then return end

    local cur = st.currentStep or 1
    if cur < 1 then cur = 1 elseif cur > n then cur = n end

    -- mark current as completed unless told not to
    if markCurrentComplete ~= false then set[cur] = true end

    -- clear transient trackers
    if QuestShellUI and QuestShellUI.ArrowClear then QuestShellUI.ArrowClear() end
    if itemTrack then
        itemTrack.itemId, itemTrack.itemName, itemTrack.prevCount = nil, nil, nil
        itemTrack.lastChangeTime = 0
    end

    -- find next eligible, incomplete step AFTER current
    local nextIdx = (QS__FindNextEligibleIncomplete and QS__FindNextEligibleIncomplete(steps, set, cur)) or (cur + 1)
    st.currentStep = nextIdx

    -- past end of chapter?
    if nextIdx > n then
        local totalCh = (QS_ChapterCount and QS_ChapterCount()) or 1
        local curCh   = (QS_CurrentChapterIndex and QS_CurrentChapterIndex()) or 1

        -- write back completed array for this chapter
        local out = {}; local k=1; while k<=n do if set[k] then out[table.getn(out)+1] = k end k=k+1 end
        st.completedByChapter[chapter] = out

        if curCh < totalCh then
            if QuestShell and QuestShell.SetChapter then QuestShell.SetChapter(curCh + 1) end
            if QuestShellUI_UpdateAll then QuestShellUI_UpdateAll() end
            return
        else
            -- whole guide done → try nextKey / next guide
            if QS_LoadNextGuideIfAny and QS_LoadNextGuideIfAny() then return end
            st.currentStep = n -- clamp for UI
        end
    end

    -- write back completed array (ascending)
    local out = {}; local j=1; while j<=n do if set[j] then out[table.getn(out)+1] = j end j=j+1 end
    st.completedByChapter[chapter] = out

    if QuestShellUI_UpdateAll then QuestShellUI_UpdateAll() end
end

-- ------------------------------------------------------------
-- Global UI aggregator (called by other modules and on boot)
-- Also primes arrows + item tracking when applicable.
-- ------------------------------------------------------------
local function QS__MaybePrimeTravelAndArrow()
    
    local steps = QS_GuideData and QS_GuideData() or {}
    local st    = QS_GuideState and QS_GuideState() or {}
    local idx   = st and st.currentStep or 1
    local step  = steps[idx]
    if not step then return end

    -- Step change?
    if _qsLastStepIdx ~= idx then
        _qsArrivedForStepIdx = nil
        _qsLastStepIdx = idx
        _qsStepState = {} -- clear per-step state
        local beh = _BehaviorFor(step)
        if beh and beh.onEnter then
            local state = _StateFor(idx)
            pcall(beh.onEnter, step, state)
        end
    end

    -- Ask behavior for waypoint
    local beh = _BehaviorFor(step)
    local wantArrow, c = false, nil
    local suppressOnArrive = false
    if beh and beh.waypoint then
        local wp = beh.waypoint(step) or nil
        if wp and wp.x and wp.y then
            c = wp
            suppressOnArrive = (wp.suppressAfterArrival and true or false)
            wantArrow = true
        end
    elseif step.coords and step.coords.x and step.coords.y then
        c = step.coords; wantArrow = true
    end

    -- Suppress if requested and we've already arrived on this step
    if wantArrow and suppressOnArrive and _qsArrivedForStepIdx == idx then
        wantArrow = false
    end

    if wantArrow and QuestShellUI and QuestShellUI.ArrowSet and (QuestShellDB and QuestShellDB.ui and QuestShellDB.ui.arrowEnabled ~= false) then
        QuestShellUI.ArrowSet(c.map or "", c.x, c.y, step.title or "Waypoint")
    else
        if QuestShellUI and QuestShellUI.ArrowClear then QuestShellUI.ArrowClear() end
    end

end

function QuestShellUI_UpdateAll()
    -- Skip normalization once after a manual click/jump
    local skip = QuestShell and QuestShell._skipNormalizeOnce
    if QuestShell then QuestShell._skipNormalizeOnce = nil end
    if (not skip) and QS_NormalizeCurrentStep then QS_NormalizeCurrentStep() end

    local steps = (QS_GuideData and QS_GuideData()) or {}
    local st = (QS_GuideState and QS_GuideState()) or {}
    local ch = (QS_CurrentChapterIndex and QS_CurrentChapterIndex()) or 1

    -- completed set for current chapter
    local set = {}
    local arr = (st.completedByChapter and st.completedByChapter[ch]) or {}
    local i=1; while arr and arr[i] do set[arr[i]] = true; i=i+1 end

    if QuestShellUI and QuestShellUI.UpdateList then
        QuestShellUI.UpdateList(steps, st.currentStep or 1, set)
    end

    if QuestShellUI and QuestShellUI.Update then
        local step = steps[st.currentStep or 1]
        local title = (step and step.title) or "QuestShell"
        local typ   = (step and step.type)  or ""
        QuestShellUI.Update(title, typ, "")
    end

    QS__MaybePrimeTravelAndArrow()
end

-- ------------------------------------------------------------
-- Helpers: TRAVEL + USE_ITEM + arrival check
-- ------------------------------------------------------------
local function QS__CompleteCurrentStep()
    if QS_AdvanceStep then QS_AdvanceStep() end
end

-- (Vanilla/Turtle + modern) WithinTravelRadius helper
local function _WithinTravelRadius(step)
    if not step or not step.coords or not step.coords.x or not step.coords.y then return false end

    -- Target coords normalized to 0..1
    local tx = (step.coords.x or 0) / 100.0
    local ty = (step.coords.y or 0) / 100.0

    -- Prefer UnitPosition if present (later clients)
    if UnitPosition then
        local px, py = UnitPosition("player")
        if not px or not py then return false end
        local dx, dy = tx - px, ty - py
        local dist = math.sqrt(dx*dx + dy*dy)
        local r = (step.radius or 0.3) / 100.0   -- keep your existing radius semantics
        if r < 0.0005 then r = 0.0005 end
        return dist <= r
    end

    -- Vanilla/Turtle fallback: map-based position
    if SetMapToCurrentZone and GetPlayerMapPosition then
        SetMapToCurrentZone()
        local px, py = GetPlayerMapPosition("player")
        if not px or not py then return false end
        local dx, dy = tx - px, ty - py
        local dist = math.sqrt(dx*dx + dy*dy)
        local r = (step.radius or 0.3) / 100.0   -- radius still in “percent of map”
        if r < 0.0005 then r = 0.0005 end
        return dist <= r
    end

    return false
end

local function QS__UseItemSatisfied(step)
    if not step then return false end

    -- optional target gate
    if step.npc and step.npc.name and step.npc.name ~= "" then
        local tgt = UnitName and UnitName("target") or nil
        if not tgt or string.lower(tgt) ~= string.lower(step.npc.name) then
            return false
        end
    end

    -- Accept both USE_ITEM steps and COMPLETE steps with use_item objectives
    local id, name = QS__UseItemSpecForStep(step)
    if (not id) and (not name) then return false end

    -- (1) detect cooldown starting on the bag slot we found
    local bag, slot = QS__FindItemInBags_ByIdOrName(id, name)
    if bag and slot and GetContainerItemCooldown then
        local start, duration, enable = GetContainerItemCooldown(bag, slot)
        if enable and duration and duration > 1 and start and start > 0 then
            return true
        end
    end

    -- (2) detect a count drop near the last BAG_UPDATE
    if (itemTrack.itemId == id and id) or (itemTrack.itemName and name and string.lower(itemTrack.itemName) == string.lower(name)) then
        if itemTrack.lastChangeTime and (Now() - itemTrack.lastChangeTime) <= 2.0 then
            return true
        end
    end

    return false
end

-- Passive rescan: mark ACCEPT steps that are already in the log.
-- Ensures only the earliest unchecked step per title is marked in a pass.
function QS_PassiveResyncAccepts()
    local steps = QS_GuideData and QS_GuideData() or {}
    local markedPerTitle = {}
    local i = 1
    while steps[i] do
        local s = steps[i]
        if s and s.type == "ACCEPT" and s.title then
            local titleLow = string.lower(s.title)
            local notDone  = (not QS_UI_IsStepCompleted) or (not QS_UI_IsStepCompleted(i))
            local eligible = (not QS_StepIsEligible) or QS_StepIsEligible(s)

            -- Skip this title once if QUEST_ACCEPTED just handled it
            if not _qsSkipOnceTitles[titleLow] and not markedPerTitle[titleLow] and notDone and eligible then
                -- Only consider the earliest unchecked step for this title
                local firstUnchecked = QS__FirstUncheckedAcceptStepIndexForTitle and QS__FirstUncheckedAcceptStepIndexForTitle(s.title) or nil
                if not firstUnchecked or firstUnchecked == i then
                    local logIdx = QS__BestLogIndexForAcceptStep and QS__BestLogIndexForAcceptStep(i) or nil
                    if logIdx then
                        if QS_UI_SetStepCompleted then QS_UI_SetStepCompleted(i, true) end
                        markedPerTitle[titleLow] = true
                    end
                end
            end
        end
        i = i + 1
    end
end

-- NEW: one-shot resync after VARIABLES_LOADED / PLAYER_ENTERING_WORLD
local QS_ResyncFrame = CreateFrame("Frame", "QuestShellResync")
local _qsResyncPending, _qsResyncAccum = false, 0

QS_ResyncFrame:RegisterEvent("VARIABLES_LOADED")
QS_ResyncFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

QS_ResyncFrame:SetScript("OnEvent", function()
    -- defer a bit so the quest log is fully populated
    _qsResyncPending, _qsResyncAccum = true, 0
end)

QS_ResyncFrame:SetScript("OnUpdate", function()
    if not _qsResyncPending then return end
    _qsResyncAccum = _qsResyncAccum + (arg1 or 0)
    if _qsResyncAccum < 0.8 then return end  -- ~800ms after load
    _qsResyncPending = false

    if QS_PassiveResyncAccepts then QS_PassiveResyncAccepts() end
    -- Clear the skip-once titles after this one-shot pass
    _qsSkipOnceTitles = {}

    if QuestShellUI_UpdateAll then QuestShellUI_UpdateAll() end
end)

-- ------------------------------------------------------------
-- Event frame
-- ------------------------------------------------------------
local ev = CreateFrame("Frame", "QuestShellCoreEvents")
ev:RegisterEvent("GOSSIP_SHOW")
ev:RegisterEvent("QUEST_GREETING")
ev:RegisterEvent("QUEST_DETAIL")
ev:RegisterEvent("QUEST_PROGRESS")
ev:RegisterEvent("QUEST_COMPLETE")
ev:RegisterEvent("QUEST_ACCEPTED")
ev:RegisterEvent("QUEST_LOG_UPDATE")
ev:RegisterEvent("VARIABLES_LOADED")
ev:RegisterEvent("BAG_UPDATE")
ev:RegisterEvent("BAG_UPDATE_COOLDOWN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("CONFIRM_BINDER")

-- ------------------------------------------------------------
-- Handlers
-- ------------------------------------------------------------
ev:SetScript("OnEvent", function()
    local event = event -- vanilla arg
    -- Behavior dispatch (early)

    local step = QS_CurrentStep and QS_CurrentStep() or nil
    if step then
        local st = QS_GuideState and QS_GuideState() or {}
        local idx = st and st.currentStep or 1
        local beh = _BehaviorFor(step)
        if beh and beh.onEvent then
            local state = _StateFor(idx)
            local ok, ret = pcall(beh.onEvent, step, event, { arg1=arg1, arg2=arg2, arg3=arg3 }, state)
            if ok and ret then
                if ret.advance then
                    if QS_D then QS_D("Behavior requested advance for "..(step.type or "")) end
                    -- Do NOT pre-mark here; QS_AdvanceStep will mark+advance once.
                    if QS_AdvanceStep then QS_AdvanceStep() end
                    return
                end
                if ret.reprime then
                    if QS__MaybePrimeTravelAndArrow then QS__MaybePrimeTravelAndArrow() end
                end
                if ret.handled then return end
            end
        end
    end

    if event == "VARIABLES_LOADED" or event == "PLAYER_ENTERING_WORLD" then
        -- try to restore last guide
        if QuestShellDB and QuestShellDB.lastActiveGuide
        and QuestShellGuides and QuestShellGuides[QuestShellDB.lastActiveGuide] then
            QuestShell.activeGuide = QuestShellDB.lastActiveGuide
        end

        -- if still nil/invalid, pick race-based default
        if (not QuestShell.activeGuide) or (not QuestShellGuides) or (not QuestShellGuides[QuestShell.activeGuide]) then
            if QS_SelectDefaultGuideIfNeeded then QS_SelectDefaultGuideIfNeeded() end
        end

        if QS_EnsureDB then QS_EnsureDB() end
        if QuestShellUI_UpdateAll then QuestShellUI_UpdateAll() end
        return

    elseif event == "BAG_UPDATE" then
        local step = QS_CurrentStep and QS_CurrentStep() or nil
        if not step then return end

        -- Track if the current step wants a use-item (by id or name)
        local id, name = QS__UseItemSpecForStep(step)
        if id or name then
            local curCount = QS__CountItemInBags_ByIdOrName(id, name)
            if itemTrack.prevCount ~= nil and curCount ~= itemTrack.prevCount then
                itemTrack.lastChangeTime = Now()
            end
            itemTrack.prevCount = curCount
            itemTrack.itemId = id or nil
            itemTrack.itemName = name or nil
        end
        return


    elseif event == "BAG_UPDATE_COOLDOWN" then
        local step = QS_CurrentStep and QS_CurrentStep() or nil
        if not step then return end

        -- Advance if the step’s use-item condition was satisfied
        local id, name = QS__UseItemSpecForStep(step)
        if id or name then
            if QS__UseItemSatisfied(step) then
                if QS_D then QS_D("USE_ITEM satisfied (any step); advancing step.") end
                QS__CompleteCurrentStep()
            end
        end
        return

    elseif event == "GOSSIP_SHOW" then
        local step = QS_CurrentStep and QS_CurrentStep() or nil
        if step and not QS_ShouldAutoHandleNpcForStep(step) then
            if QS_D then QS_D("GOSSIP_SHOW other NPC; ignoring.") end
            return
        end

            -- Auto-select "Make this inn your home" only for SET_HEARTH and correct NPC
        if step and string.upper(step.type or "") == "SET_HEARTH" then
            -- guard: only the intended NPC
            if not QS_ShouldAutoHandleNpcForStep(step) then
                if QS_D then QS_D("SET_HEARTH gossip on other NPC; ignoring.") end
                return
            end

            -- parse gossip options safely (1.12: text,type repeating)
            local opts = { GetGossipOptions() }
            local foundIdx = nil
            for i = 1, table.getn(opts), 2 do
                local txt = string.lower(tostring(opts[i] or ""))
                -- a few robust phrases; you can expand/localize later
                if string.find(txt, "make this inn your home", 1, true)
                or string.find(txt, "set.*hearth", 1)  -- catches "set your hearthstone"
                or string.find(txt, "make .* your home", 1) then
                    foundIdx = (i + 1) / 2
                    break
                end
            end

            if foundIdx then
                -- mark ephemeral state for behavior (read via _StateFor)
                local st  = QS_GuideState and QS_GuideState() or {}
                local idx = st and st.currentStep or 1
                local state = _StateFor(idx)
                state.awaitingBind   = true
                state.selectedAt     = Now()
                state.confirmedAt    = nil
                state.oldBind        = (GetBindLocation and GetBindLocation()) or ""

                if QS_D then QS_D("Selected inn binder gossip option.") end
                SelectGossipOption(foundIdx)
                return
            end
        end

        -- bridge gossip -> greeting when possible
        if step and (step.type == "ACCEPT" or step.type == "TURNIN") then
            if TryOpenGreetingFromGossip and TryOpenGreetingFromGossip() then
                if QS_D then QS_D("Opened QUEST_GREETING from gossip.") end
                return
            end

            -- Fallback: select directly when unambiguous
            if QS_HaveGossip and QS_HaveGossip() then
                if step.type == "ACCEPT" and QS_GossipAvailEntries then
                    local avail = QS_GossipAvailEntries()
                    local idx, count, i = nil, 0, 1
                    while avail[i] do
                        if avail[i].title == step.title then
                            count = count + 1
                            if not idx then idx = avail[i].idx end
                        end
                        i = i + 1
                    end
                    if idx and count == 1 then
                        if QS_D then QS_D("Selecting gossip available quest: "..tostring(step.title)) end
                        SelectGossipAvailableQuest(idx)
                        return
                    elseif QS_D then
                        QS_D("Gossip available ambiguous for "..tostring(step.title).." (matches="..tostring(count)..")")
                    end
                elseif step.type == "TURNIN" and QS_GossipActiveEntries then
                    local active = QS_GossipActiveEntries()
                    local i = 1
                    while active[i] do
                        if active[i].title == step.title then
                            if QS_D then QS_D("Selecting gossip active quest: "..tostring(step.title)) end
                            SelectGossipActiveQuest(active[i].idx)
                            return
                        end
                        i = i + 1
                    end
                end
            end
        end
        return

    elseif event == "QUEST_GREETING" then
        local step = QS_CurrentStep and QS_CurrentStep() or nil
        if not step then return end
        if not QS_ShouldAutoHandleNpcForStep(step) then
            if QS_D then QS_D("QUEST_GREETING other NPC; ignoring.") end
            return
        end

        if step.type == "ACCEPT" then
            local idx = QS__SelectAvailableIndexForAccept(step)
            if idx then
                if QS_D then QS_D("Selecting available quest #"..tostring(idx).." for "..tostring(step.title)) end
                SelectAvailableQuest(idx)
                return
            else
                if QS_D then QS_D("ACCEPT ambiguous for "..(step.title or "").."; add step.level or acceptLabels.") end
                return
            end

        elseif step.type == "TURNIN" then
            local n = GetNumActiveQuests() or 0
            local i = 1
            while i <= n do
                local t = GetActiveTitle(i)
                if t == step.title then
                    if QS_D then QS_D("Selecting active quest #"..tostring(i).." for "..tostring(step.title)) end
                    SelectActiveQuest(i)
                    return
                end
                i = i + 1
            end
        end
        return

    elseif event == "QUEST_DETAIL" then
        local step = QS_CurrentStep and QS_CurrentStep() or nil
        if not step then return end
        if not QS_ShouldAutoHandleNpcForStep(step) then
            if QS_D then QS_D("QUEST_DETAIL other NPC; ignoring.") end
            return
        end

        local title = GetTitleText and GetTitleText() or ""
        if step.type == "ACCEPT" and title == step.title then
            awaitingAcceptTitle = title
            if QS_D then QS_D("Accepting quest: "..tostring(title)) end
            AcceptQuest()
            return
        end
        return

    elseif event == "QUEST_PROGRESS" then
        local step = QS_CurrentStep and QS_CurrentStep() or nil
        if not step then return end
        if not QS_ShouldAutoHandleNpcForStep(step) then
            if QS_D then QS_D("QUEST_PROGRESS other NPC; ignoring.") end
            return
        end

        if step.type == "TURNIN" then
            if IsQuestCompletable and IsQuestCompletable() then
                if QS_D then QS_D("Completing quest (progress).") end
                CompleteQuest()
            end
            return
        end
        return

    elseif event == "QUEST_COMPLETE" then
        local step = QS_CurrentStep and QS_CurrentStep() or nil
        if not step then return end
        if not QS_ShouldAutoHandleNpcForStep(step) then
            if QS_D then QS_D("QUEST_COMPLETE other NPC; ignoring.") end
            return
        end

        if step.type == "TURNIN" then
            local choices = (GetNumQuestChoices and GetNumQuestChoices()) or 0
            if choices > 0 then
                -- Let the player choose; do NOT auto-pick.
                if QS_D then QS_D("TURNIN: multiple rewards; waiting for player selection.") end
                return
            end

            if QS_D then QS_D("Picking first reward and advancing step.") end
            GetQuestReward(1)
            QS_AdvanceStep()
            return
        end
        return

    elseif event == "QUEST_ACCEPTED" then
        local logIndex = arg1
        if QS_D then QS_D("QUEST_ACCEPTED idx="..tostring(logIndex)) end

        local acceptedTitle, acceptedLevel = nil, nil
        if GetQuestLogTitle and logIndex then
            acceptedTitle, acceptedLevel = GetQuestLogTitle(logIndex)
        end

        local st     = QS_GuideState and QS_GuideState() or nil
        local steps  = QS_GuideData and QS_GuideData() or {}
        local cur    = st and st.currentStep or 1
        local curStep= steps[cur]

        -- strict resolver (log → step) first
        local matchIdx = QS__BestAcceptStepForLogIndex and QS__BestAcceptStepForLogIndex(logIndex) or nil

        -- fallback: current step title match only if UNIQUE by title, otherwise require level
        if (not matchIdx) and curStep and string.upper(curStep.type or "")=="ACCEPT" and curStep.title and acceptedTitle then
            if string.lower(curStep.title) == string.lower(acceptedTitle) then
                local dupSteps = QS__DupStepsForTitle(acceptedTitle)
                if dupSteps <= 1 then
                    matchIdx = cur -- unique by title
                elseif curStep.level and acceptedLevel and curStep.level == acceptedLevel then
                    matchIdx = cur -- level also matches
                end
            end
        end

        if matchIdx then
            if matchIdx == cur then
                if QS_Print then QS_Print("Accepted: "..(acceptedTitle or "<title>")) end
                QS_AdvanceStep()
            else
                if QS_UI_SetStepCompleted then QS_UI_SetStepCompleted(matchIdx, true) end
            end
        else
            if QS_D then QS_D("ACCEPT ambiguous for '"..tostring(acceptedTitle or "").."'; add step.level to disambiguate.") end
        end

        -- Suppress very next passive resync for this title (if any queued)
        if acceptedTitle and acceptedTitle ~= "" then
            _qsSkipOnceTitles[string.lower(acceptedTitle)] = true
        end
        awaitingAcceptTitle = nil
        return

    elseif event == "QUEST_LOG_UPDATE" then
        -- Only confirm the just-accepted CURRENT step (legacy path).
        if awaitingAcceptTitle then
            local st = QS_GuideState and QS_GuideState() or nil
            local cur = st and st.currentStep or 1
            local steps = QS_GuideData and QS_GuideData() or {}
            local curStep = steps[cur]

            local entries = GetNumQuestLogEntries() or 0
            local i = 1
            while i <= entries do
                local t, qLevel, _, _, isHeader = GetQuestLogTitle(i)
                if not isHeader and t == awaitingAcceptTitle then
                    local bestForCurrent = QS__BestLogIndexForAcceptStep and QS__BestLogIndexForAcceptStep(cur) or nil
                    if (bestForCurrent and bestForCurrent == i) then
                        awaitingAcceptTitle = nil
                        if QS_D then QS_D("Confirmed accepted (level-aware): "..t) end
                        QS_AdvanceStep()
                        break
                    end
                    if curStep and curStep.level and qLevel and curStep.level == qLevel then
                        awaitingAcceptTitle = nil
                        if QS_D then QS_D("Confirmed accepted (exact level): "..t) end
                        QS_AdvanceStep()
                        break
                    end
                end
                i = i + 1
            end
        end

        -- Auto-advance CURRENT COMPLETE step when all objectives are done.
        do
            local st = QS_GuideState and QS_GuideState() or nil
            local cur = st and st.currentStep or 1
            local steps = QS_GuideData and QS_GuideData() or {}
            local s = steps[cur]
            if s and string.upper(s.type or "") == "COMPLETE" and s.title then
                local idx = QS_FindQuestLogIndexByTitle and QS_FindQuestLogIndexByTitle(s.title) or nil
                if idx and QS_IsQuestObjectivesCompleteByIndex and QS_IsQuestObjectivesCompleteByIndex(idx) then
                    if QS_D then QS_D("Objectives complete for '"..(s.title or "").."'; advancing step.") end
                    QS_AdvanceStep()
                end
            end
        end

        -- IMPORTANT: Do NOT run any passive ACCEPT scan here.
        if QuestShellUI_UpdateAll then QuestShellUI_UpdateAll() end
        return
    
    elseif event == "CONFIRM_BINDER" then
    -- Auto-confirm the hearth bind only for SET_HEARTH steps
    local step = QS_CurrentStep and QS_CurrentStep() or nil
    if step and string.upper(step.type or "") == "SET_HEARTH" then
        if step.autoconfirm == false then
            if QS_D then QS_D("CONFIRM_BINDER: autoconfirm disabled for this step.") end
            return
        end
        if QS_D then QS_D("CONFIRM_BINDER: confirming and advancing.") end
        ConfirmBinder()          -- click “Accept”
        --if QS_AdvanceStep then QS_AdvanceStep() end
    end
    return

    end
end)

-- ------------------------------------------------------------
-- TRAVEL/COMPLETE OnUpdate poller (lightweight; 0.2s)
-- ------------------------------------------------------------

-- ------------------------------------------------------------
-- OnUpdate poller (0.2s): delegate to step behavior
-- ------------------------------------------------------------
local travelPoll = CreateFrame("Frame", "QuestShellTravelPoll")
travelPoll:SetScript("OnUpdate", function()
    travelUpdateAccum = travelUpdateAccum + (arg1 or 0)
    if travelUpdateAccum < 0.2 then return end
    travelUpdateAccum = 0

    local step = QS_CurrentStep and QS_CurrentStep() or nil
    if not step then return end
    local st = QS_GuideState and QS_GuideState() or {}
    local idx = st and st.currentStep or 1
    local beh = _BehaviorFor(step)
    if not beh or not beh.onUpdate then return end

    local state = _StateFor(idx)
    local ok, ret = pcall(beh.onUpdate, step, { dt=0.2, helpers={ WithinRadius=_WithinTravelRadius } }, state)
    if not ok then return end

    if ret and ret.arrived then
        _qsArrivedForStepIdx = idx
        if QuestShellUI and QuestShellUI.ArrowClear then QuestShellUI.ArrowClear() end
        return
    end

    if ret and ret.advance then
        if QS_D then QS_D("Behavior requested advance for "..(step.type or "")) end
        -- Do NOT pre-mark here; QS_AdvanceStep will mark+advance once.
        if QS_AdvanceStep then QS_AdvanceStep() end
        return
    end
end)
