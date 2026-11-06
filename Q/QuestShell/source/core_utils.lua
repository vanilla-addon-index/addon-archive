-- =========================
-- QuestShell core_utils.lua
-- Utils, DB, logging, quest-log helpers
-- (Lua 5.0 / Turtle safe; no '#' and no 'self')
-- =========================

QuestShell = QuestShell or {}
-- default guide on startup
if QuestShell and type(QuestShell.debug) == "nil" then QuestShell.debug = false end

local function QS_IsDebug()
    -- primary
    if QuestShell and type(QuestShell.debug) ~= "nil" then return QuestShell.debug end
    -- legacy fallback
    if type(QuestShell_Debug) ~= "nil" then return QuestShell_Debug end
    return false
end

function QS_D(m)
    if QS_IsDebug() and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[QuestShell:DBG]|r "..tostring(m))
    end
end

function QS_Print(m) if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[QuestShell]|r "..tostring(m)) end end
function QS_Warn(m)  if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffff8800[QuestShell]|r "..tostring(m)) end end
function QS_D(m)     if QuestShell.debug then QS_Print(m) end end

-- DB shape supports chapters:
-- QuestShellDB.guides[guideName] = {
--   currentChapter = 1,
--   currentStep    = 1,
--   completedByChapter = { [chapterIndex] = { stepIdx, stepIdx, ... } }
-- }
function QS_EnsureDB()
    -- Account-wide
    if not QuestShellDB then QuestShellDB = { ui = {} } end
    if not QuestShellDB.ui then QuestShellDB.ui = {} end

    -- Per-character
    if not QuestShellCDB then QuestShellCDB = { guides = {}, lastActiveGuide = nil } end
    if not QuestShellCDB.guides then QuestShellCDB.guides = {} end
    if QuestShellCDB.lastActiveGuide == nil then QuestShellCDB.lastActiveGuide = nil end

    -- --- one-time migration from old account-wide guides to per-character ---
    if QuestShellDB.guides then
        -- Move the whole table into character DB and drop the old reference
        if not QuestShellCDB.guides or (next(QuestShellCDB.guides) == nil) then
            QuestShellCDB.guides = QuestShellDB.guides
        end
        QuestShellDB.guides = nil
    end

    -- No active guide yet? just ensure top-level tables
    if not QuestShell.activeGuide then return end

    -- Ensure per-character state for the active guide
    if not QuestShellCDB.guides[QuestShell.activeGuide] then
        QuestShellCDB.guides[QuestShell.activeGuide] = {
            currentChapter = 1,
            currentStep    = 1,
            completedByChapter = {},
        }
    else
        local st = QuestShellCDB.guides[QuestShell.activeGuide]
        if not st.currentChapter then st.currentChapter = 1 end
        if st.completedSteps and not st.completedByChapter then
            st.completedByChapter = {}; st.completedByChapter[1] = st.completedSteps; st.completedSteps = nil
        end
        if not st.currentStep then st.currentStep = 1 end
    end
end

local function QS__PlayerClass()
  local _, c = UnitClass("player"); return string.upper(c or "")
end

function QS_StepIsEligible(step)
  if not step then return true end
  local me = QS__PlayerClass()

  -- single string: class = "WARRIOR"
  if step.class and type(step.class) == "string" then
    return string.upper(step.class) == me
  end

  -- list: classes = {"WARRIOR","PALADIN"}
  if step.classes and type(step.classes) == "table" then
    local i=1; while step.classes[i] do
      if string.upper(step.classes[i]) == me then return true end
      i=i+1
    end
    return false
  end

  return true
end

-- Normalize player race -> "NIGHTELF", "DWARF", etc. (spaces removed)
local function QS__PlayerRaceKey()
    local r = UnitRace and UnitRace("player") or ""
    r = string.upper(r or "")
    r = string.gsub(r, "%s+", "")  -- "Night Elf" -> "NIGHTELF"
    return r
end

-- Find first guide whose startingRace contains the player's race
function QS_PickDefaultGuideForPlayer()
    local want = QS__PlayerRaceKey()
    local best = nil
    for key, g in pairs(QuestShellGuides or {}) do
        local sr = g and g.startingRace
        if type(sr) == "string" then
            local v = string.upper(string.gsub(sr, "%s+", ""))
            if v == want then best = key; break end
        elseif type(sr) == "table" then
            local i=1
            while sr[i] do
                local v = string.upper(string.gsub(sr[i] or "", "%s+", ""))
                if v == want then best = key; break end
                i=i+1
            end
            if best then break end
        end
    end
    return best
end

-- Select a default guide if current is missing/invalid
function QS_SelectDefaultGuideIfNeeded()
    if QuestShell.activeGuide and QuestShellGuides and QuestShellGuides[QuestShell.activeGuide] then
        return -- already valid
    end
    local def = QS_PickDefaultGuideForPlayer and QS_PickDefaultGuideForPlayer() or nil
    if not def then
        -- Fallback: lowest-level guide
        local names = QS_AllGuidesOrdered and QS_AllGuidesOrdered() or {}
        def = names[1]
    end
    if def then
        QuestShell.activeGuide = def
        QS_EnsureDB()
        QS_Print("Default guide set to: "..tostring(def))
    end
end

-- --- Bag / Item helpers (Lua 5.0 safe) --------------------
local function QS__ItemIdFromLink(link)
    if not link then return nil end
    local _,_,id = string.find(link, "item:(%d+)")
    if id then return tonumber(id) end
    return nil
end

-- Count total copies of itemId in all bags
function QS_CountItemInBags(itemId)
    if not itemId then return 0 end
    local total = 0
    local bag = 0
    while bag <= 4 do
        local slots = GetContainerNumSlots(bag) or 0
        local s = 1
        while s <= slots do
            local link = GetContainerItemLink(bag, s)
            if link then
                local id = QS__ItemIdFromLink(link)
                if id and id == itemId then
                    local _, count = GetContainerItemInfo(bag, s)
                    if count then total = total + count else total = total + 1 end
                end
            end
            s = s + 1
        end
        bag = bag + 1
    end
    return total
end

-- Find first bag/slot for itemId
function QS_FindItemInBags(itemId)
    if not itemId then return nil,nil end
    local bag = 0
    while bag <= 4 do
        local slots = GetContainerNumSlots(bag) or 0
        local s = 1
        while s <= slots do
            local link = GetContainerItemLink(bag, s)
            if link then
                local id = QS__ItemIdFromLink(link)
                if id and id == itemId then return bag, s end
            end
            s = s + 1
        end
        bag = bag + 1
    end
    return nil, nil
end

-- Quest log helpers
function QS_FindQuestLogIndexByTitle(title)
    if not title then return nil end
    local n = GetNumQuestLogEntries() or 0
    local i = 1
    while i <= n do
        local t, _, _, _, isHeader = GetQuestLogTitle(i)
        if not isHeader and t == title then return i end
        i = i + 1
    end
    return nil
end

function QS_IsQuestObjectivesCompleteByIndex(idx)
    if not idx then return false end
    local n = GetNumQuestLeaderBoards(idx) or 0
    if n == 0 then return false end
    local i = 1
    while i <= n do
        local _, _, done = GetQuestLogLeaderBoard(i, idx)
        if not done then return false end
        i = i + 1
    end
    return true
end

-- =====================================================================
-- Objective plumbing
--  * Fix: match labels against quest-log subjects by equality (not substring).
--  * We normalize strings first (lowercase, strip counts/punctuation/keywords).
-- =====================================================================

-- Normalize helper (Lua 5.0 safe)
local function QS__trim(s)
    if not s then return "" end
    s = string.gsub(s, "^%s+", "")
    s = string.gsub(s, "%s+$", "")
    return s
end

-- Extract the "subject" part from a quest-log objective line.
-- Examples:
--   "Young Thistle Boar slain: 1/4" -> "young thistle boar"
--   "Crawler Legs: 0/4"             -> "crawler legs"
local function QS__ObjectiveSubject(txt)
    if not txt then return "" end
    local s = string.lower(txt)

    -- drop any "x/y" or "x of y"
    s = string.gsub(s, "%d+%s*/%s*%d+", "")
    s = string.gsub(s, "%d+%s+of%s+%d+", "")
    -- cut off after a colon if present (common pattern "Thing: x/y")
    local a, b = string.find(s, ":")
    if a then s = string.sub(s, 1, a - 1) end
    -- strip trailing keywords like "slain"
    s = string.gsub(s, "%s+slain%s*$", "")
    -- collapse whitespace
    s = string.gsub(s, "%s+", " ")
    return QS__trim(s)
end

-- Normalize a guide label to compare with quest-log subject
local function QS__NormLabel(lbl)
    if not lbl then return "" end
    local s = string.lower(lbl)
    s = string.gsub(s, "%s+slain%s*$", "")
    s = string.gsub(s, "%s+", " ")
    return QS__trim(s)
end

-- Optional questID helpers (use if server exposes them)
local function QS__LogQuestID(logIndex)
    if GetQuestLogQuestID then return GetQuestLogQuestID(logIndex) end
    if C_QuestLog and C_QuestLog.GetQuestIDForLogIndex then
        return C_QuestLog.GetQuestIDForLogIndex(logIndex)
    end
    return nil
end

-- Try to resolve quest-log index using questId (best) or title (fallback).
-- Works even when the guide step has NO objectives.
local function QS__FindQuestLogIndexForStep(step)
    if not step then return nil end
    local wantId   = step.questId
    local wantTitle= step.title

    local entries = GetNumQuestLogEntries() or 0
    local bestIdx, bestScore = nil, -1

    local function logQuestId(i)
        if GetQuestLogQuestID then
            return GetQuestLogQuestID(i)
        end
        if C_QuestLog and C_QuestLog.GetQuestIDForLogIndex then
            return C_QuestLog.GetQuestIDForLogIndex(i)
        end
        return nil
    end

    -- (1) Exact questId match wins immediately if available on this client.
    if wantId then
        local i = 1
        while i <= entries do
            local t, _, _, _, isHeader = GetQuestLogTitle(i)
            if not isHeader then
                local qid = logQuestId(i)
                if qid and qid == wantId then
                    return i
                end
            end
            i = i + 1
        end
    end

    -- (2) Fallback: title match. If the step has objectives, prefer the log entry
    --     whose objective subjects match the guide labels; otherwise take the first.
    if not wantTitle or wantTitle == "" then return nil end

    local i = 1
    while i <= entries do
        local t, _, _, _, isHeader = GetQuestLogTitle(i)
        if not isHeader and t == wantTitle then
            local score = 0
            if step.objectives and type(step.objectives) == "table" and table.getn(step.objectives) > 0 then
                local n = GetNumQuestLeaderBoards(i) or 0
                local j = 1
                while j <= n do
                    local txt = GetQuestLogLeaderBoard(j, i)
                    local subj = QS__ObjectiveSubject(txt)
                    local k = 1
                    while step.objectives[k] do
                        local o = step.objectives[k]
                        local lab = QS__NormLabel(o and (o.label or o.text))
                        if lab ~= "" and subj ~= "" and lab == subj then
                            score = score + 1
                            break
                        end
                        k = k + 1
                    end
                    j = j + 1
                end
            else
                -- No guide objectives supplied → neutral score (0), first title match wins.
                score = 0
            end
            if score > bestScore then bestScore = score; bestIdx = i end
        end
        i = i + 1
    end
    return bestIdx
end

-- Parse "x/y" or "x of y" — Lua 5.0 safe
local function QS__ParseCounts(s)
    if not s then return nil, nil end
    local _, _, a, b = string.find(s, "(%d+)%s*/%s*(%d+)")
    if a and b then return tonumber(a), tonumber(b) end
    _, _, a, b = string.find(s, "(%d+)%s+of%s+(%d+)")
    if a and b then return tonumber(a), tonumber(b) end
    return nil, nil
end

-- Public: build objective rows. If forceComplete==true, format as x/x and mark done.
-- Public: build objective rows. If forceComplete==true, format as x/x and mark done.
function QS_BuildObjectiveRows(step, forceComplete)
    local rows = {}
    if not step then return rows end

    local idx = QS__FindQuestLogIndexForStep(step)

    -- If we have a quest-log index, mirror it (preferred path).
    if idx then
        -- Prefer guide-defined objectives; overlay counts from log when we can match.
        if step.objectives and type(step.objectives) == "table" and table.getn(step.objectives) > 0 then
            local k = 1
            while step.objectives[k] do
                local O = step.objectives[k] or {}
                local labelRaw = O.label or O.text or ""
                local label = QS__NormLabel(labelRaw)
                local target = O.target or 0
                local cur, done = 0, false

                local n = GetNumQuestLeaderBoards(idx) or 0
                local j = 1
                while j <= n do
                    local txt, _, qdone = GetQuestLogLeaderBoard(j, idx)
                    local subj = QS__ObjectiveSubject(txt)
                    if label ~= "" and subj ~= "" and label == subj then
                        local c, t = QS__ParseCounts(txt)
                        if c then cur = c end
                        if t then target = t end
                        if qdone then done = true end
                        break
                    end
                    j = j + 1
                end

                if forceComplete and target and target > 0 then
                    cur, done = target, true
                end

                local out
                if labelRaw ~= "" and target and target > 0 then
                    out = labelRaw..": "..tostring(cur or 0).."/"..tostring(target)
                else
                    out = (labelRaw ~= "" and labelRaw) or ""
                end

                rows[table.getn(rows)+1] = {
                    text   = out,
                    done   = done,
                    kind   = O.kind or "other",
                    cur    = cur,
                    target = target,
                    label  = labelRaw
                }
                k = k + 1
            end
            return rows
        end

        -- Fallback: no guide objectives → mirror quest log lines directly.
        local n = GetNumQuestLeaderBoards(idx) or 0
        local j = 1
        while j <= n do
            local txt, _, qdone = GetQuestLogLeaderBoard(j, idx)
            local out, done = txt or "", (qdone and true or false)
            if forceComplete then
                local c, t = QS__ParseCounts(txt)
                if t then
                    out = string.gsub(txt, "(%d+)%s*/%s*(%d+)", tostring(t).."/"..t, 1)
                    done = true
                else
                    done = true
                end
            end
            rows[table.getn(rows)+1] = { text = out, done = done, kind = "other", cur = nil, target = nil, label = nil }
            j = j + 1
        end
        return rows
    end

    -- === No quest-log entry yet (quest not accepted) → placeholders ===

    -- (1) If guide has objectives → show ?/target or plain labels, greyed (dim).
    if step.objectives and type(step.objectives) == "table" and table.getn(step.objectives) > 0 then
        local k = 1
        while step.objectives[k] do
            local O = step.objectives[k] or {}
            local labelRaw = O.label or O.text or ""
            local target = O.target or nil
            local out = labelRaw
            if target and target > 0 then out = labelRaw..": ?/"..tostring(target) end
            rows[table.getn(rows)+1] = {
                text = out, done = false, kind = O.kind or "other",
                cur = nil, target = target, label = labelRaw,
                dim = true
            }
            k = k + 1
        end
        return rows
    end

    -- (2) If there is a top-level item → synthesize "Use: <name>", greyed.
    if step.itemId or step.itemName then
        local nameTxt = step.itemName or (step.itemId and ("Item ID "..tostring(step.itemId)) or "item")
        rows[table.getn(rows)+1] = {
            text = "Use: "..nameTxt, kind = "use_item", done = false, dim = true
        }
        return rows
    end

    -- (3) Otherwise → single generic placeholder, greyed.
    local qname = step.title or "this quest"
    rows[1] = { text = "Objectives will appear after you accept \""..qname.."\".", done = false, kind = "other", dim = true }
    return rows
end