-- =========================
-- QuestShell core_guides.lua
-- Guide metadata/data access, chapter helpers, loader, jump/advance
-- Compatibility: Vanilla/Turtle (Lua 5.0)
-- =========================
-- Public surface:
--   QS_GuideMeta(name?)                -> {title, steps}|{title, chapters}
--   QS_GuideHasChapters(name?)         -> boolean
--   QS_ChapterCount(name?)             -> number
--   QS_GuideState()                    -> saved-state table for active guide (PER-CHAR)
--   QS_CurrentChapterIndex()           -> number
--   QS_ChapterMeta(idx)                -> chapter meta for current guide
--   QS_GuideData()                     -> steps[] for current chapter
--   QS_CurrentStep()                   -> step table for current step
--   QuestShell.SetChapter(idx)         -> switches chapter, finds next uncompleted step
--   QS_AllGuidesOrdered()              -> array of guide keys sorted by level/title
--   QuestShell.LoadGuide(name)         -> set active guide, reset chapter/step if first time
--   QS_LoadNextGuideIfAny()            -> bool; loads next ordered guide (prefers nextKey)
--   QuestShell.JumpToStep(idx)         -> set currentStep within chapter
-- =========================

-- Safe UI refresher (works even if QuestShellUI_UpdateAll isn't defined yet)
local function QS_UI_RefreshAll()
    if QuestShellUI_UpdateAll then
        QuestShellUI_UpdateAll()
        return
    end
    -- minimal fallback: refresh list + tracker directly
    if QuestShellUI and QuestShellUI.UpdateList then
        local steps = QS_GuideData and QS_GuideData() or {}
        local st = QS_GuideState and QS_GuideState() or {}
        local ch = QS_CurrentChapterIndex and QS_CurrentChapterIndex() or 1
        local arr = (st.completedByChapter and st.completedByChapter[ch]) or {}
        local set = {}; local i=1; while arr and arr[i] do set[arr[i]] = true; i=i+1 end
        QuestShellUI.UpdateList(steps, st.currentStep or 1, set)
    end
    if QuestShellUI and QuestShellUI.Update then
        local step = QS_CurrentStep and QS_CurrentStep() or nil
        local title = step and step.title or "QuestShell"
        local typ   = step and step.type  or ""
        QuestShellUI.Update(title, typ, "")
    end
end

-- --- Guide meta resolution ---
-- Accepts: old single-zone (array or {steps=...}) OR new campaign ({chapters=...})
function QS_GuideMeta(name)
    local key = name or QuestShell.activeGuide
    local g = QuestShellGuides and QuestShellGuides[key]
    if type(g) == "table" then
        if not g.steps and not g.chapters then
            return { title = key, steps = g } -- legacy array → synthesize
        end
        return g
    end
    return { title = key, steps = {} }
end

function QS_GuideHasChapters(name)
    local m = QS_GuideMeta(name)
    return (m.chapters and type(m.chapters) == "table")
end

function QS_ChapterCount(name)
    local m = QS_GuideMeta(name)
    if m.chapters then return table.getn(m.chapters or {}) end
    return 1
end

-- Return true if every eligible step across all chapters is completed
function QS_GuideIsFullyComplete()
    local st = QS_GuideState and QS_GuideState() or nil
    if not st then return false end

    local chCount = (QS_ChapterCount and QS_ChapterCount()) or 1
    local ch = 1
    while ch <= chCount do
        local meta = QS_ChapterMeta and QS_ChapterMeta(ch) or nil
        local steps = (meta and meta.steps) or {}
        local doneArr = (st.completedByChapter and st.completedByChapter[ch]) or {}
        local doneSet = {}
        local i = 1
        while doneArr[i] do doneSet[doneArr[i]] = true; i = i + 1 end

        local n = table.getn(steps or {})
        local s = 1
        while s <= n do
            local step = steps[s]
            local eligible = (not QS_StepIsEligible) and true or QS_StepIsEligible(step)
            if eligible and (not doneSet[s]) then
                return false
            end
            s = s + 1
        end
        ch = ch + 1
    end
    return true
end

-- If fully complete, try to chain to next guide (returns true if chained)
function QS_GuideTryAutoChain()
    if QS_GuideIsFullyComplete and QS_GuideIsFullyComplete() then
        if QS_LoadNextGuideIfAny and QS_LoadNextGuideIfAny() then
            return true
        end
    end
    return false
end

-- ----- Saved state accessors (PER-CHAR) -----
-- Uses QuestShellCDB (SavedVariablesPerCharacter) for:
--   - guides[guideKey] = { currentChapter, currentStep, completedByChapter }
--   - lastActiveGuide
-- Falls back to QuestShellDB for legacy migration if needed.
function QS_GuideState()
    -- Ensure top-level DB tables exist
    if QS_EnsureDB then QS_EnsureDB() end

    -- If no active guide yet, select one (by startingRace or fallback)
    if (not QuestShell.activeGuide) or (not QuestShellGuides) or (not QuestShellGuides[QuestShell.activeGuide]) then
        if QS_SelectDefaultGuideIfNeeded then QS_SelectDefaultGuideIfNeeded() end
        if QS_EnsureDB then QS_EnsureDB() end
    end

    -- Final safeguard: if still missing, return a dummy table to avoid nil indexing
    if not QuestShell.activeGuide then
        return { currentChapter = 1, currentStep = 1, completedByChapter = { [1] = {} } }
    end

    -- Prefer per-character DB
    if QuestShellCDB and QuestShellCDB.guides then
        return QuestShellCDB.guides[QuestShell.activeGuide]
    end

    -- Legacy fallback (very old installs)
    if QuestShellDB and QuestShellDB.guides then
        return QuestShellDB.guides[QuestShell.activeGuide]
    end

    -- Last-ditch dummy
    return { currentChapter = 1, currentStep = 1, completedByChapter = { [1] = {} } }
end

function QS_CurrentChapterIndex()
    local st = QS_GuideState()
    return (st and st.currentChapter) or 1
end

-- Chapter meta (synthesizes a single chapter for legacy format)
function QS_ChapterMeta(idx)
    local m = QS_GuideMeta()
    if m.chapters then
        return m.chapters[idx]
    else
        local steps = (m.steps and m.steps) or {}
        return {
            id       = "chapter1",
            title    = (m.title or QuestShell.activeGuide),
            zone     = m.zone,
            minLevel = m.minLevel,
            maxLevel = m.maxLevel,
            steps    = steps
        }
    end
end

-- Steps for the *current* chapter
function QS_GuideData()
    local chMeta = QS_ChapterMeta(QS_CurrentChapterIndex())
    return chMeta and chMeta.steps
end

-- Current step object (within current chapter)
function QS_CurrentStep()
    local d, s = QS_GuideData(), QS_GuideState()
    if not d or not s then return nil end
    return d[s.currentStep]
end

-- Normalize st.currentStep to the first eligible & incomplete step in the current chapter
function QS_NormalizeCurrentStep()
    local st = QS_GuideState and QS_GuideState() or nil
    local steps = QS_GuideData and QS_GuideData() or {}
    if not st or not steps then return end

    st.completedByChapter = st.completedByChapter or {}
    local ch = (QS_CurrentChapterIndex and QS_CurrentChapterIndex()) or 1
    local arr = st.completedByChapter[ch] or {}

    -- build a set of completed indices (your saved shape uses an array of indices)
    local done = {}
    local i = 1
    while arr and arr[i] do
        done[arr[i]] = true
        i = i + 1
    end

    local n = table.getn(steps or {})
    local cur = st.currentStep or 1
    if cur < 1 then cur = 1 end
    if cur > n then cur = n end

    local function isEligible(iidx)
        local s = steps[iidx]
        if not s then return false end
        if done[iidx] then return false end
        if QS_StepIsEligible and not QS_StepIsEligible(s) then return false end
        return true
    end

    if not isEligible(cur) then
        cur = 1
        while cur <= n and not isEligible(cur) do
            cur = cur + 1
        end
    end

    st.currentStep = cur
end

-- ----- Chapter switching -----
function QuestShell.SetChapter(idx)
    local n = QS_ChapterCount()
    if idx < 1 then idx = 1 end
    if idx > n then idx = n end
    local st = QS_GuideState()
    st.currentChapter = idx

    st.completedByChapter = st.completedByChapter or {}
    local doneSet = {}
    local arr = st.completedByChapter[idx] or {}
    local i = 1
    while i <= table.getn(arr) do doneSet[arr[i]] = true; i = i + 1 end

    local steps = QS_GuideData() or {}
    local total = table.getn(steps)
    local cur = 1
    while cur <= total and (doneSet[cur] or (QS_StepIsEligible and not QS_StepIsEligible(steps[cur]))) do
        cur = cur + 1
    end
    st.currentStep = cur

    QS_Print("Switched to chapter "..idx.."/"..n..": "..(QS_ChapterMeta(idx).title or ""))
    QS_UI_RefreshAll()
end

-- Ordered list of guide keys: level (min,max), then title
function QS_AllGuidesOrdered()
    local names = {}
    for k,_ in pairs(QuestShellGuides or {}) do names[table.getn(names)+1] = k end
    table.sort(names, function(a,b)
        local ga, gb = QS_GuideMeta(a), QS_GuideMeta(b)
        local amin, bmin = ga.minLevel or 0, gb.minLevel or 0
        if amin ~= bmin then return amin < bmin end
        local amax, bmax = ga.maxLevel or 0, gb.maxLevel or 0
        if amax ~= bmax then return amax < bmax end
        return (ga.title or a) < (gb.title or b)
    end)
    return names
end

-- Load a guide (keeps progress if it exists; initializes only first time)
function QuestShell.LoadGuide(name)
    if not (QuestShellGuides and QuestShellGuides[name]) then
        QS_Warn("Guide not found: "..tostring(name))
        return
    end

    QuestShell.activeGuide = name
    QS_EnsureDB()

    -- PER-CHAR: remember across /reload (legacy: also keep QuestShellDB.lastActiveGuide for old installs)
    QuestShellCDB = QuestShellCDB or {}
    QuestShellCDB.lastActiveGuide = name
    QuestShellDB  = QuestShellDB  or {}
    QuestShellDB.lastActiveGuide  = name  -- harmless legacy slot

    -- Per-character state table
    local st = (QuestShellCDB and QuestShellCDB.guides and QuestShellCDB.guides[name])
              or (QuestShellDB and QuestShellDB.guides and QuestShellDB.guides[name]) -- legacy fallback
    if not st then
        -- Ensure per-char container exists
        QuestShellCDB = QuestShellCDB or {}; QuestShellCDB.guides = QuestShellCDB.guides or {}
        st = { currentChapter = 1, currentStep = 1, completedByChapter = {} }
        QuestShellCDB.guides[name] = st
    else
        -- Only initialize if fields missing
        if not st.currentChapter then st.currentChapter = 1 end
        if not st.currentStep    then st.currentStep    = 1 end
        st.completedByChapter = st.completedByChapter or {}
        -- Migrate old shape if needed
        if st.completedSteps and not st.completedByChapter then
            st.completedByChapter = {}; st.completedByChapter[1] = st.completedSteps; st.completedSteps = nil
        end
        -- If state came from old account-wide DB, move it into per-char slot
        if QuestShellDB and QuestShellDB.guides and QuestShellDB.guides[name] == st then
            QuestShellCDB.guides = QuestShellCDB.guides or {}
            QuestShellCDB.guides[name] = st
            -- do not nil out old table here; QS_EnsureDB handles global migration safely
        end
    end

    if QS_NormalizeCurrentStep then QS_NormalizeCurrentStep() end

    local meta = QS_GuideMeta(name)
    local lv = ""
    if meta and (meta.minLevel or meta.maxLevel) then
        lv = " ("..tostring(meta.minLevel or "?").."-"..tostring(meta.maxLevel or "?")..")"
    end
    QS_Print("Loaded guide: "..((meta and meta.title) or name)..lv)

    QS_UI_RefreshAll()
end

-- Advance to next guide in ordered list, if any (prefers nextKey)
function QS_LoadNextGuideIfAny()
    local cur  = QuestShell.activeGuide
    local meta = (QS_GuideMeta and QS_GuideMeta(cur)) or (QuestShellGuides and QuestShellGuides[cur]) or nil

    -- Prefer explicit nextKey if it exists
    local nk = meta and meta.nextKey
    if nk and QuestShellGuides and QuestShellGuides[nk] and nk ~= cur then
        QS_Print("Guide complete. Loading next (nextKey): "..tostring(nk))
        QuestShell.LoadGuide(nk)
        return true
    end

    -- Fallback: ordered progression
    local names = QS_AllGuidesOrdered and QS_AllGuidesOrdered() or {}
    local idx, n = nil, table.getn(names)
    local i = 1
    while i <= n do if names[i] == cur then idx = i; break end i = i + 1 end
    if idx and idx < n then
        local nextName = names[idx + 1]
        QS_Print("Guide complete. Loading next: "..tostring(nextName))
        QuestShell.LoadGuide(nextName)
        return true
    end

    QS_Print("Guide complete. No next guide found.")
    return false
end

-- Jump to step within current chapter
function QuestShell.JumpToStep(idx)
    local steps = QS_GuideData(); if not steps then return end
    if idx < 1 then idx = 1 end
    local n = table.getn(steps); if idx > n then idx = n end

    local st = QS_GuideState and QS_GuideState() or {}
    st.currentStep = idx

    -- Tell next UI refresh to keep this exact selection (even if completed)
    QuestShell = QuestShell or {}
    QuestShell._skipNormalizeOnce = true

    QS_Print("Jumped to step "..tostring(idx)..": "..tostring(steps[idx].type or "?").." "..tostring(steps[idx].title or ""))
    -- Use your safe refresh wrapper
    if QS_UI_RefreshAll then QS_UI_RefreshAll() elseif QuestShellUI_UpdateAll then QuestShellUI_UpdateAll() end
end

-- Restore last active guide (runs on VARIABLES_LOADED)
do
    local boot = CreateFrame("Frame")
    boot:RegisterEvent("VARIABLES_LOADED")
    boot:SetScript("OnEvent", function()
        -- Ensure saved vars tables exist (also lets core_utils handle migration)
        if QS_EnsureDB then QS_EnsureDB() end

        -- 1) Restore per-character lastActiveGuide if valid
        if QuestShellCDB and QuestShellCDB.lastActiveGuide
           and QuestShellGuides and QuestShellGuides[QuestShellCDB.lastActiveGuide] then
            QuestShell.activeGuide = QuestShellCDB.lastActiveGuide
        -- 1b) Legacy fallback: old account-wide slot (first run after update)
        elseif QuestShellDB and QuestShellDB.lastActiveGuide
           and QuestShellGuides and QuestShellGuides[QuestShellDB.lastActiveGuide] then
            QuestShell.activeGuide = QuestShellDB.lastActiveGuide
            -- copy into per-char memory for next time
            QuestShellCDB = QuestShellCDB or {}
            QuestShellCDB.lastActiveGuide = QuestShellDB.lastActiveGuide
        end

        -- 2) If still no/invalid active guide, fall back to race-based picker.
        if (not QuestShell.activeGuide) or (not QuestShellGuides) or (not QuestShellGuides[QuestShell.activeGuide]) then
            if QS_SelectDefaultGuideIfNeeded then QS_SelectDefaultGuideIfNeeded() end
        end

        -- 3) Make sure the per-guide state exists, then refresh UI
        if QS_EnsureDB then QS_EnsureDB() end
        if QuestShellUI_UpdateAll then QuestShellUI_UpdateAll() end
    end)
end
