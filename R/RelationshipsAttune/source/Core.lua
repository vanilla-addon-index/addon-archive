-- RelationshipsAttune: Core.lua
-- Event handling, scanning, throttled auto-scan, faction-aware evaluation.
-- Lua 5.0 / WoW 1.12 safe (Turtle/Octo compatible).

RelationshipsAttune = RelationshipsAttune or {}
local RA = RelationshipsAttune
local L  = RelationshipsAttune_L

RA.VERSION      = "1.4.4"
RA.COMM_PREFIX  = "RATTUNE"

RA.playerName    = nil
RA.playerRealm   = nil
RA.playerKey     = nil
RA.playerFaction = nil
RA.initialized   = false

-- ---------------------------------------------------------------
-- Utilities
-- ---------------------------------------------------------------
local function tsize(t)
    if not t then return 0 end
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end
RA.tsize = tsize

local function print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff[RAttune]|r " .. tostring(msg))
    end
end
RA.print = print

local STANDING = {
    Hated = 1, Hostile = 2, Unfriendly = 3, Neutral = 4,
    Friendly = 5, Honored = 6, Revered = 7, Exalted = 8,
}
local DATA_STANDING_MAP = { [1]=2, [2]=3, [3]=4, [4]=5, [5]=6, [6]=7, [7]=8 }

-- Return true if this step is applicable to the current player faction.
function RA:StepApplies(step)
    if step.faction and step.faction ~= "Both" and step.faction ~= RA.playerFaction then
        return false
    end
    return true
end

-- ---------------------------------------------------------------
-- Saved-variables init
-- ---------------------------------------------------------------
function RA:InitDB()
    if not RelationshipsAttuneDB then RelationshipsAttuneDB = {} end
    if not RelationshipsAttuneDB.players then RelationshipsAttuneDB.players = {} end
    if not RelationshipsAttuneDB.options then
        RelationshipsAttuneDB.options = {}
    end
    local o = RelationshipsAttuneDB.options
    if o.autoShare       == nil     then o.autoShare       = true end
    if o.autoScanSeconds == nil     then o.autoScanSeconds = 10   end
    if type(o.minimapAngle)  ~= "number" then o.minimapAngle  = 200 end
    if type(o.minimapRadius) ~= "number" then o.minimapRadius = 80  end
    if o.minimapHide == nil then o.minimapHide = false end

    if not RelationshipsAttuneCharDB then RelationshipsAttuneCharDB = {} end
    if not RelationshipsAttuneCharDB.quests then RelationshipsAttuneCharDB.quests = {} end
    if not RelationshipsAttuneCharDB.items  then RelationshipsAttuneCharDB.items  = {} end
    if not RelationshipsAttuneCharDB.completedAttunements then RelationshipsAttuneCharDB.completedAttunements = {} end
    if not RelationshipsAttuneCharDB.announced then RelationshipsAttuneCharDB.announced = {} end
    if not RelationshipsAttuneCharDB.progress then RelationshipsAttuneCharDB.progress = {} end
    if not RelationshipsAttuneCharDB.expanded then RelationshipsAttuneCharDB.expanded = {} end
    if not RelationshipsAttuneCharDB.forcedSteps then RelationshipsAttuneCharDB.forcedSteps = {} end
    if not RelationshipsAttuneCharDB.forcedAtt   then RelationshipsAttuneCharDB.forcedAtt   = {} end
end

-- ---------------------------------------------------------------
-- Force-complete (manual override) helpers
-- ---------------------------------------------------------------
function RA:IsStepForced(attId, i)
    local t = RelationshipsAttuneCharDB.forcedSteps
    return t and t[attId] and t[attId][i] == true
end

function RA:SetStepForced(attId, i, v)
    if not attId or not i then return end
    local t = RelationshipsAttuneCharDB.forcedSteps
    if not t then RelationshipsAttuneCharDB.forcedSteps = {}; t = RelationshipsAttuneCharDB.forcedSteps end
    if not t[attId] then t[attId] = {} end
    if v then t[attId][i] = true else t[attId][i] = nil end
    self:RecomputeAll()
    if RA.UI and RA.UI.Refresh then RA.UI:Refresh() end
end

function RA:IsAttForced(attId)
    local t = RelationshipsAttuneCharDB.forcedAtt
    return t and t[attId] == true
end

function RA:SetAttForced(attId, v)
    if not attId then return end
    if not RelationshipsAttuneCharDB.forcedAtt then
        RelationshipsAttuneCharDB.forcedAtt = {}
    end
    if not RelationshipsAttuneCharDB.completedAttunements then
        RelationshipsAttuneCharDB.completedAttunements = {}
    end
    if v then
        RelationshipsAttuneCharDB.forcedAtt[attId] = true
        RelationshipsAttuneCharDB.completedAttunements[attId] = true
    else
        RelationshipsAttuneCharDB.forcedAtt[attId] = nil
        RelationshipsAttuneCharDB.completedAttunements[attId] = nil
        if RelationshipsAttuneCharDB.forcedSteps then
            RelationshipsAttuneCharDB.forcedSteps[attId] = nil
        end
        if RelationshipsAttuneCharDB.announced then
            RelationshipsAttuneCharDB.announced[attId] = nil
        end
    end
    self:RecomputeAll()
    if RA.UI and RA.UI.Refresh then RA.UI:Refresh() end
end

-- ---------------------------------------------------------------
-- Quest log scan (vanilla API)
--
-- Note: vanilla 1.12's GetQuestLogTitle returns 6 values without a questId.
-- Turtle/Octo backported questId as the 8th return. We pcall + accept both
-- shapes so the addon degrades gracefully on stock 1.12.
-- ---------------------------------------------------------------
function RA:ScanQuestLog()
    if not GetNumQuestLogEntries then return end
    -- Snapshot previous transient states so we can detect a turn-in on clients
    -- that don't fire QUEST_TURNED_IN (stock 1.12). A quest that was
    -- "complete" (ready to hand in) and is now missing from the log is
    -- almost certainly turned in -- abandoning a quest requires it to be
    -- accepted-but-not-complete. This is what actually credits MC's
    -- "Attunement to the Core" (7487), BWL, Naxx, and any other
    -- quest-only final step.
    local prev = RelationshipsAttuneCharDB.quests or {}
    local kept = {}
    for qid, st in pairs(prev) do
        if st == "turnedin" then kept[qid] = "turnedin" end
    end
    RelationshipsAttuneCharDB.quests = kept

    RA:BuildNameIndex()
    local qNameMap = RA._questNameToId or {}

    local seenThisScan = {}
    local numEntries = GetNumQuestLogEntries()
    for i = 1, numEntries do
        local ok, title, level, tag, isHeader, _, isComplete, _, questId =
            pcall(GetQuestLogTitle, i)
        if ok and (not isHeader) then
            -- Prefer the Turtle/Octo backported questId; fall back to matching
            -- the quest title against our data so stock 1.12 (no questId return)
            -- and any titles the client failed to tag still get credited.
            local qid = questId
            if (not qid) and title then
                qid = qNameMap[string.lower(title)]
            end
            if qid then
                seenThisScan[qid] = true
                if RelationshipsAttuneCharDB.quests[qid] ~= "turnedin" then
                    if isComplete and isComplete == 1 then
                        RelationshipsAttuneCharDB.quests[qid] = "complete"
                    else
                        RelationshipsAttuneCharDB.quests[qid] = "inlog"
                    end
                end
            end
        end
    end

    -- Retroactive turn-in detection: any quest we tracked as "complete" last
    -- scan that isn't in the log any more got handed in.
    for qid, st in pairs(prev) do
        if st == "complete" and not seenThisScan[qid] then
            RelationshipsAttuneCharDB.quests[qid] = "turnedin"
        end
    end
end

-- ---------------------------------------------------------------
-- Completed-quest scan (server-side completed quest cache).
--
-- Turtle WoW / OctoWoW backport QueryQuestsCompleted() +
-- GetQuestsCompleted(t), which return every quest the character has
-- ever turned in -- including quests completed BEFORE the addon was
-- installed. Without this, the addon can only see quests that are
-- currently in the log (or that were "complete" in a previous scan
-- and then vanished), so a player who is already half-way through a
-- chain shows no progress until they accept the next quest.
--
-- We pcall everything so stock 1.12 clients that don't expose these
-- APIs simply skip the scan and keep the existing behaviour.
-- ---------------------------------------------------------------
function RA:ScanCompletedQuests()
    -- Build the set of quest ids we actually care about so we don't
    -- pollute the DB with thousands of unrelated turn-ins.
    if not RelationshipsAttune_Data then return end
    local wanted = {}
    for i = 1, table.getn(RelationshipsAttune_Data) do
        local att = RelationshipsAttune_Data[i]
        if att and att.steps then
            for j = 1, table.getn(att.steps) do
                local s = att.steps[j]
                if s and s.type == "quest" and s.id then
                    wanted[s.id] = true
                end
            end
        end
    end

    local completed = {}
    local haveAny = false

    -- Preferred: bulk table fill.
    if type(GetQuestsCompleted) == "function" then
        local ok = pcall(GetQuestsCompleted, completed)
        if ok then
            for _ in pairs(completed) do haveAny = true break end
        end
    end

    -- Fallback: per-id check (Turtle exposes IsQuestCompleted on some builds).
    if not haveAny and type(IsQuestCompleted) == "function" then
        for qid in pairs(wanted) do
            local ok, res = pcall(IsQuestCompleted, qid)
            if ok and res then
                completed[qid] = true
                haveAny = true
            end
        end
    end

    if not haveAny then
        -- Kick the server to populate the cache; the QUEST_QUERY_COMPLETE
        -- event handler will re-run this scan when the reply arrives.
        if type(QueryQuestsCompleted) == "function" then
            pcall(QueryQuestsCompleted)
        end
        return
    end

    for qid in pairs(wanted) do
        if completed[qid] and RelationshipsAttuneCharDB.quests[qid] ~= "turnedin" then
            RelationshipsAttuneCharDB.quests[qid] = "turnedin"
        end
    end
end


function RA:MarkQuestTurnedIn(questId)
    if not questId then return end
    RelationshipsAttuneCharDB.quests[questId] = "turnedin"
    self:RecomputeAll()
    if RA.UI and RA.UI.Refresh then RA.UI:Refresh() end
end

-- ---------------------------------------------------------------
-- Item scan: bags, equipped slots, and keyring
-- ---------------------------------------------------------------
local function rememberItemLink(link)
    if not link then return end
    local _, _, idStr = string.find(link, "item:(%d+)")
    local linkId
    if idStr then
        linkId = tonumber(idStr)
        if linkId then RelationshipsAttuneCharDB.items[linkId] = true end
    end
    -- Resolve by name so a custom Turtle/Octo item whose live client id
    -- differs from the id declared in Data.lua still gets credited.
    local resolvedName
    if GetItemInfo then
        local ok, n = pcall(GetItemInfo, link)
        if ok and n then resolvedName = n end
    end
    if not resolvedName then
        local _, _, bracket = string.find(link, "%[(.-)%]")
        if bracket and bracket ~= "" then resolvedName = bracket end
    end
    if resolvedName then
        RA:BuildNameIndex()
        if RA._nameToId then
            local mapped = RA._nameToId[string.lower(resolvedName)]
            if mapped and mapped ~= linkId then
                RelationshipsAttuneCharDB.items[mapped] = true
            end
        end
    end
end

local function rememberItemId(id)
    if not id then return end
    id = tonumber(id)
    if id then RelationshipsAttuneCharDB.items[id] = true end
end

-- Build (and cache) a name -> item id map from RelationshipsAttune_Data so we
-- can identify keyring items even when the client refuses to return a link
-- for them (a known 1.12 / Turtle / Octo quirk for keyring slots).
RA._nameToId = nil
function RA:BuildNameIndex()
    if RA._nameToId and RA._questNameToId then return RA._nameToId end
    local map, qmap = {}, {}
    if RelationshipsAttune_Data then
        for i = 1, table.getn(RelationshipsAttune_Data) do
            local att = RelationshipsAttune_Data[i]
            if att and att.steps then
                for j = 1, table.getn(att.steps) do
                    local s = att.steps[j]
                    if s and s.name and s.id then
                        local nlow = string.lower(s.name)
                        if s.type == "item" then
                            map[nlow] = s.id
                        elseif s.type == "quest" then
                            qmap[nlow] = s.id
                            -- Data.lua disambiguates faction-specific quests
                            -- with a "(Alliance)" / "(Horde)" suffix that
                            -- the in-game quest log does NOT include. Index
                            -- the stripped variant so the name fallback in
                            -- ScanQuestLog matches on stock 1.12 clients
                            -- that don't return a questId.
                            local _, _, stripped = string.find(nlow, "^(.-)%s*%(alliance%)%s*$")
                            if not stripped then
                                _, _, stripped = string.find(nlow, "^(.-)%s*%(horde%)%s*$")
                            end
                            if stripped and stripped ~= "" and not qmap[stripped] then
                                qmap[stripped] = s.id
                            end
                        end
                    end
                end
            end
        end
    end
    RA._nameToId = map
    RA._questNameToId = qmap
    return map
end

-- Hidden tooltip used to force item info to resolve for keyring slots.
local _raTip
local _raTipName = "RelationshipsAttuneScanTip"
local function ensureTip()
    if _raTip then return _raTip end
    _raTip = CreateFrame("GameTooltip", _raTipName, nil, "GameTooltipTemplate")
    _raTip:SetOwner(UIParent, "ANCHOR_NONE")
    return _raTip
end

-- Read the first tooltip line (item name) after a SetBagItem call.
-- 1.12 exposes frame globals via getglobal(), not _G.
local function tipItemName()
    local fs
    if getglobal then fs = getglobal(_raTipName .. "TextLeft1") end
    if (not fs) and _G then fs = _G[_raTipName .. "TextLeft1"] end
    if fs and fs.GetText then
        local t = fs:GetText()
        if t and t ~= "" then return t end
    end
    return nil
end

local function scanContainer(containerId)
    if not GetContainerNumSlots then return end
    local ok, slots = pcall(GetContainerNumSlots, containerId)
    if not ok or not slots or slots < 1 then return end
    for slot = 1, slots do
        local ok2, link = pcall(GetContainerItemLink, containerId, slot)
        if ok2 then rememberItemLink(link) end
    end
end

local function scanKeyringContainer(bag)
    if not GetContainerNumSlots then return end
    local ok, slots = pcall(GetContainerNumSlots, bag)
    if not ok or not slots then slots = 0 end
    local probe = slots
    if probe < 1 then probe = 32 end

    local tip = ensureTip()
    local nameMap = RA:BuildNameIndex()

    for slot = 1, probe do
        pcall(function() tip:ClearLines() end)
        local setOk = false
        pcall(function() tip:SetBagItem(bag, slot); setOk = true end)

        local link
        local okL, l = pcall(GetContainerItemLink, bag, slot)
        if okL then link = l end
        if link then rememberItemLink(link) end

        if setOk then
            local name = tipItemName()
            if name and nameMap then
                local id = nameMap[string.lower(name)]
                if id then rememberItemId(id) end
            end
        end

        if GetContainerItemInfo then
            pcall(GetContainerItemInfo, bag, slot)
        end
    end
    pcall(function() tip:Hide() end)
end

function RA:WarmItemCache()
    if not GetItemInfo or not RelationshipsAttune_Data then return end
    for i = 1, table.getn(RelationshipsAttune_Data) do
        local att = RelationshipsAttune_Data[i]
        if att and att.steps then
            for j = 1, table.getn(att.steps) do
                local s = att.steps[j]
                if s and s.type == "item" and s.id then
                    pcall(GetItemInfo, s.id)
                end
            end
        end
    end
end

function RA:ScanBags()
    if not GetContainerNumSlots then return end
    RA:BuildNameIndex()
    for bag = 0, 4 do
        scanContainer(bag)
    end

    local seen = {}
    local function tryBag(b)
        if b == nil or seen[b] then return end
        seen[b] = true
        scanKeyringContainer(b)
    end
    tryBag(-2)
    tryBag(-1)
    tryBag(-3)
    tryBag(KEYRING_CONTAINER)

    if GetInventoryItemLink then
        for slot = 1, 19 do
            local ok, link = pcall(GetInventoryItemLink, "player", slot)
            if ok then rememberItemLink(link) end
        end
    end
end

function RA:ForceKeyringResolve()
    scanKeyringContainer(-2)
end

-- ---------------------------------------------------------------
-- Reputation lookup
-- ---------------------------------------------------------------
function RA:GetReputationStanding(factionName)
    if not GetNumFactions then return 0 end
    local numFactions = GetNumFactions()
    for i = 1, numFactions do
        local name, _, standingId, _, _, _, _, _, isHeader = GetFactionInfo(i)
        if name == factionName and not isHeader then
            return standingId or 0
        end
    end
    return 0
end

-- ---------------------------------------------------------------
-- Compute attunement progress
-- ---------------------------------------------------------------
function RA:EvaluateStep(step)
    -- Returns two values: done (boolean), inProgress (boolean).
    -- inProgress = the player is actively working on this step but has not
    -- yet finished it (e.g. quest accepted but not complete).
    if step.type == "level" then
        return (UnitLevel("player") or 0) >= (step.level or 0), false
    elseif step.type == "quest" then
        local st = RelationshipsAttuneCharDB.quests[step.id]
        if st == "turnedin" then
            return true, false
        elseif st == "complete" or st == "inlog" then
            -- Quest is in the log (either accepted or ready to turn in).
            -- Treat both as "on this step" (orange) until it is actually
            -- turned in. Retroactive completion will still mark this
            -- step green once the player advances to a later step.
            return false, true
        end
        return false, false
    elseif step.type == "item" then
        return RelationshipsAttuneCharDB.items[step.id] == true, false
    elseif step.type == "rep" then
        local need = DATA_STANDING_MAP[step.standing] or step.standing or 5
        local have = self:GetReputationStanding(step.faction)
        if have >= need then return true, false end
        -- Any positive rep with the faction below the required standing counts
        -- as in-progress so the player sees they are working on it.
        if have and have >= 4 then return false, true end
        return false, false
    end
    return false, false
end

function RA:EvaluateAttunement(att)
    if att.faction and att.faction ~= "Both" and att.faction ~= RA.playerFaction then
        return { applicable = false, done = false, steps = {}, doneCount = 0, total = 0 }
    end
    local steps, stepsInProgress, doneCount, total = {}, {}, 0, 0
    local numSteps = table.getn(att.steps)
    for i = 1, numSteps do
        local step = att.steps[i]
        if self:StepApplies(step) then
            local doneVal, ipVal = self:EvaluateStep(step)
            local ok = doneVal and true or false
            steps[i] = ok
            stepsInProgress[i] = (not ok) and (ipVal and true or false) or false
            total = total + 1
            if ok then doneCount = doneCount + 1 end
        else
            steps[i] = nil
            stepsInProgress[i] = nil
        end
    end
    -- Apply per-step forced completions (manual overrides from the UI).
    -- These are treated exactly like a real completion for tracking purposes.
    local forced = RelationshipsAttuneCharDB.forcedSteps and RelationshipsAttuneCharDB.forcedSteps[att.id]
    if forced then
        for i = 1, numSteps do
            local step = att.steps[i]
            if step and self:StepApplies(step) and forced[i] and steps[i] == false then
                steps[i] = true
                stepsInProgress[i] = false
                doneCount = doneCount + 1
            end
        end
    end

    -- Short-circuit: if the "final" step is complete, treat the whole
    -- attunement as done. Prefer an explicit final=true step; fall back to
    -- the last item step (key), then the last applicable step.
    local finalIdx = nil
    for i = numSteps, 1, -1 do
        local step = att.steps[i]
        if step.final and self:StepApplies(step) then
            finalIdx = i
            break
        end
    end
    if not finalIdx then
        for i = numSteps, 1, -1 do
            local step = att.steps[i]
            if step.type == "item" and self:StepApplies(step) then
                finalIdx = i
                break
            end
        end
    end
    if not finalIdx then
        for i = numSteps, 1, -1 do
            local step = att.steps[i]
            if self:StepApplies(step) then
                finalIdx = i
                break
            end
        end
    end
    -- Retroactive completion: if the player is on a later step (done or in
    -- progress), any earlier quest/item steps must already be done. Quests
    -- get turned in and key items get consumed, so their live state can
    -- flip back to "not done" even though the player clearly finished
    -- them. Level and reputation steps have their own live truth and are
    -- left alone.
    local laterActive = false
    for i = numSteps, 1, -1 do
        local step = att.steps[i]
        if step and self:StepApplies(step) then
            if laterActive and steps[i] == false then
                local t = step.type
                if t == "quest" or t == "item" then
                    steps[i] = true
                    stepsInProgress[i] = false
                    doneCount = doneCount + 1
                    if t == "quest" then
                        RelationshipsAttuneCharDB.quests[step.id] = "turnedin"
                    elseif t == "item" then
                        RelationshipsAttuneCharDB.items[step.id] = true
                    end
                end
            end
            if steps[i] == true or stepsInProgress[i] == true then
                laterActive = true
            end
        end
    end
    local persistedDone = RelationshipsAttuneCharDB.completedAttunements and RelationshipsAttuneCharDB.completedAttunements[att.id]
    if persistedDone or (finalIdx and steps[finalIdx] == true) then
        for i = 1, numSteps do
            if steps[i] == false then
                steps[i] = true
                doneCount = doneCount + 1
            end
        end
    end
    if total > 0 and doneCount == total then
        RelationshipsAttuneCharDB.completedAttunements[att.id] = true
    end
    return {
        applicable     = true,
        done           = (total > 0 and doneCount == total),
        steps          = steps,
        stepsInProgress= stepsInProgress,
        doneCount      = doneCount,
        total          = total,
    }
end

function RA:AnnounceCompletion(att)
    if not att or not att.name then return end
    if not RelationshipsAttuneCharDB.announced then
        RelationshipsAttuneCharDB.announced = {}
    end
    if RelationshipsAttuneCharDB.announced[att.id] then return end
    RelationshipsAttuneCharDB.announced[att.id] = true

    local inGuild = false
    if IsInGuild then
        local ok, res = pcall(IsInGuild)
        if ok and res then inGuild = true end
    end
    if not inGuild and GetGuildInfo then
        local ok, gname = pcall(GetGuildInfo, "player")
        if ok and gname and gname ~= "" then inGuild = true end
    end
    local msg = "Attunement Complete: " .. (RA.playerName or "I")
        .. " has fully completed the " .. att.name .. " attunement!"
    if inGuild and SendChatMessage then
        pcall(SendChatMessage, msg, "GUILD")
    end
    RA.print(msg)
end

function RA:RecomputeAll()
    for i = 1, table.getn(RelationshipsAttune_Data) do
        local att = RelationshipsAttune_Data[i]
        local prev = RelationshipsAttuneCharDB.progress[att.id]
        local wasDone = prev and prev.done
        local prog = self:EvaluateAttunement(att)
        RelationshipsAttuneCharDB.progress[att.id] = prog
        if prog.applicable and prog.done and not wasDone then
            self:AnnounceCompletion(att)
        end
    end
    RelationshipsAttuneDB.players[RA.playerKey] = {
        name     = RA.playerName,
        realm    = RA.playerRealm,
        faction  = RA.playerFaction,
        level    = UnitLevel("player") or 0,
        class    = UnitClass("player"),
        version  = RA.VERSION,
        updated  = time and time() or 0,
        progress = RelationshipsAttuneCharDB.progress,
    }
end

-- ---------------------------------------------------------------
-- Throttled auto-scan
-- ---------------------------------------------------------------
RA._throttle    = 0
RA._periodic    = 0
RA._dirty       = false
RA._minRescan   = 1.5

function RA:MarkDirty() RA._dirty = true end

-- Full periodic rescan (quest log + bags + recompute + UI refresh).
function RA:AutoScan()
    RA:ScanQuestLog()
    RA:ScanCompletedQuests()
    RA:ScanBags()
    RA:RecomputeAll()
    if RA.UI and RA.UI.Refresh then RA.UI:Refresh() end
end

function RA:_OnUpdate(elapsed)
    -- Elapsed can arrive as a function argument, as the global arg1, or
    -- (on some 1.12 builds) not at all. Fall back to GetTime() deltas so
    -- the periodic auto-scan always advances.
    if type(elapsed) ~= "number" then elapsed = nil end
    if not elapsed and type(arg1) == "number" then elapsed = arg1 end
    if not elapsed and GetTime then
        local now = GetTime()
        if RA._lastUpdate then
            elapsed = now - RA._lastUpdate
        else
            elapsed = 0
        end
        RA._lastUpdate = now
    end
    elapsed = elapsed or 0
    RA._throttle = RA._throttle + elapsed
    RA._periodic = RA._periodic + elapsed
    local interval = (RelationshipsAttuneDB and RelationshipsAttuneDB.options
                      and RelationshipsAttuneDB.options.autoScanSeconds) or 10
    if interval < 3 then interval = 3 end

    if RA._retryAt and GetTime then
        local now = GetTime()
        local pending = {}
        local fired = false
        for i = 1, table.getn(RA._retryAt) do
            local t = RA._retryAt[i]
            if now >= t then
                fired = true
            else
                table.insert(pending, t)
            end
        end
        if fired then
            RA:WarmItemCache()
            RA:ScanCompletedQuests()
            RA:ScanBags()
            RA:RecomputeAll()
            if RA.UI and RA.UI.Refresh then RA.UI:Refresh() end
        end
        if table.getn(pending) == 0 then
            RA._retryAt = nil
        else
            RA._retryAt = pending
        end
    end

    -- Event-driven rescan: something changed, catch up quickly.
    if RA._dirty and RA._throttle >= RA._minRescan then
        RA._dirty = false
        RA._throttle = 0
        RA._periodic = 0
        RA:AutoScan()
        return
    end

    -- Unconditional periodic rescan so state stays fresh even if no events fire
    -- (e.g. reputation ticks from mob kills, quest turn-ins on stock 1.12
    -- without QUEST_TURNED_IN, background item pickups by other addons).
    if RA._periodic >= interval then
        RA._periodic = 0
        RA._throttle = 0
        RA:AutoScan()
    end
end

-- ---------------------------------------------------------------
-- Slash commands
-- ---------------------------------------------------------------
local function slashHandler(msg)
    msg = string.lower(msg or "")
    msg = string.gsub(msg, "^%s+", "")
    msg = string.gsub(msg, "%s+$", "")

    if msg == "show" then
        if RA.UI then RA.UI:Show() end
    elseif msg == "hide" then
        if RA.UI and RA.UI:IsShown() then
            RA.UI:Hide()
        elseif RA.Minimap then
            RA.Minimap:Hide()
            print("Minimap button hidden. Type /attune minimap to show it again.")
        end
    elseif msg == "minimap" or msg == "mm" then
        if RA.Minimap then
            RA.Minimap:Toggle()
            local o = RelationshipsAttuneDB.options
            if o.minimapHide then
                print("Minimap button hidden. /attune minimap to show it.")
            else
                print("Minimap button shown. Drag to reposition around the minimap.")
            end
        end
    elseif string.find(msg, "^pos") then
        -- /attune pos <x> <y>  -- set exact offset from UIParent CENTER.
        -- Values may be off-screen (e.g. -9999) to park the button out of
        -- the way while still letting MinimapButtonBag collect it.
        local _, _, sx, sy = string.find(msg, "pos%s+(%-?%d+%.?%d*)%s+(%-?%d+%.?%d*)")
        local x, y = tonumber(sx), tonumber(sy)
        if x and y and RA.Minimap then
            local o = RelationshipsAttuneDB.options
            o.minimapX, o.minimapY = x, y
            RA.Minimap:Refresh()
            print("Minimap button moved to " .. x .. ", " .. y .. ".")
        else
            print("Usage: /attune pos <x> <y>   (offsets from screen center; can be off-screen)")
        end
    elseif msg == "offscreen" or msg == "park" then
        if RA.Minimap then
            local o = RelationshipsAttuneDB.options
            o.minimapX, o.minimapY = -10000, -10000
            RA.Minimap:Refresh()
            print("Minimap button parked off-screen. MinimapButtonBag (if installed) can still collect it. Use /attune resetpos to bring it back.")
        end
    elseif msg == "resetpos" then
        if RA.Minimap then
            local o = RelationshipsAttuneDB.options
            o.minimapX, o.minimapY = 0, -140
            RA.Minimap:Refresh()
            print("Minimap button position reset.")
        end
    elseif msg == "sync" then
        if RA.Comm then RA.Comm:RequestSync() end
        print(L.MSG_SYNC_SENT)
    elseif msg == "scan" then
        RA:ScanQuestLog(); RA:ScanCompletedQuests(); RA:ScanBags(); RA:RecomputeAll()
        if RA.UI and RA.UI.Refresh then RA.UI:Refresh() end
        print(L.MSG_SCANNED)
    elseif msg == "reset" then
        RelationshipsAttuneCharDB = nil
        RA:InitDB()
        RA:ScanQuestLog(); RA:ScanCompletedQuests(); RA:ScanBags(); RA:RecomputeAll()
        if RA.UI and RA.UI.Refresh then RA.UI:Refresh() end
        print(L.MSG_RESET)
    elseif msg == "debug" or string.find(msg, "^find") then
        local _, _, arg = string.find(msg, "find%s+(%d+)")
        RA:ScanBags()
        if arg then
            local id = tonumber(arg)
            print("Item " .. id .. " owned: " .. tostring(RelationshipsAttuneCharDB.items[id] == true))
        end
        print("Keyring dump:")
        local probeBags = { -2, -1 }
        if KEYRING_CONTAINER and KEYRING_CONTAINER ~= -2 and KEYRING_CONTAINER ~= -1 then
            table.insert(probeBags, KEYRING_CONTAINER)
        end
        local tip = ensureTip()
        for _, bag in ipairs(probeBags) do
            local ok, slots = pcall(GetContainerNumSlots, bag)
            if not ok or not slots then slots = 0 end
            local probe = slots > 0 and slots or 32
            print("  bag " .. bag .. " GetContainerNumSlots=" .. tostring(slots) .. " probing=" .. probe)
            for s = 1, probe do
                pcall(function() tip:ClearLines() end)
                pcall(function() tip:SetBagItem(bag, s) end)
                local ok2, link = pcall(GetContainerItemLink, bag, s)
                local name = tipItemName()
                if (ok2 and link) or name then
                    print("    [" .. s .. "] link=" .. tostring(link) .. " name=" .. tostring(name))
                end
            end
        end
        pcall(function() tip:Hide() end)
    elseif msg == "help" or msg == "?" then
        print("Relationships Attune - commands:")
        print("  /attune          - toggle the window")
        print("  /attune show     - open the window")
        print("  /attune hide     - close the window (or hide the minimap button)")
        print("  /attune minimap  - toggle the minimap button")
        print("  /attune pos x y  - place the minimap button at exact offset (can be off-screen)")
        print("  /attune offscreen- park the minimap button off-screen (MBB can still collect it)")
        print("  /attune resetpos - restore the minimap button to a visible default position")
        print("  /attune scan     - force a rescan of quests + bags")
        print("  /attune sync     - request sync from your group")
        print("  /attune debug    - dump keyring + item detection")
        print("  /attune find <id>- check if a specific item is detected")
        print("  /attune reset    - wipe this character's data and rescan")
    else
        if RA.UI then RA.UI:Toggle() end
    end
end

SLASH_RELATIONSHIPSATTUNE1 = "/rattune"
SLASH_RELATIONSHIPSATTUNE2 = "/relationshipsattune"
SLASH_RELATIONSHIPSATTUNE3 = "/attune"
SlashCmdList["RELATIONSHIPSATTUNE"] = slashHandler

-- ---------------------------------------------------------------
-- Event frame
-- ---------------------------------------------------------------
local ef = CreateFrame("Frame", "RelationshipsAttuneEventFrame")
ef:RegisterEvent("PLAYER_LOGIN")
ef:RegisterEvent("PLAYER_ENTERING_WORLD")
ef:RegisterEvent("QUEST_LOG_UPDATE")
ef:RegisterEvent("BAG_UPDATE")
ef:RegisterEvent("PLAYER_LEVEL_UP")
ef:RegisterEvent("UPDATE_FACTION")
ef:RegisterEvent("CHAT_MSG_ADDON")
-- These events don't exist on stock 1.12 but Turtle/Octo backports them.
-- pcall prevents a hard failure on builds that don't recognise them.
pcall(function() ef:RegisterEvent("QUEST_TURNED_IN") end)
pcall(function() ef:RegisterEvent("KEYRING_UPDATE") end)
pcall(function() ef:RegisterEvent("UNIT_INVENTORY_CHANGED") end)
pcall(function() ef:RegisterEvent("ITEM_PUSH") end)
pcall(function() ef:RegisterEvent("PLAYER_XP_UPDATE") end)
pcall(function() ef:RegisterEvent("ZONE_CHANGED_NEW_AREA") end)
pcall(function() ef:RegisterEvent("SKILL_LINES_CHANGED") end)
pcall(function() ef:RegisterEvent("QUEST_QUERY_COMPLETE") end)

ef:SetScript("OnEvent", function()
    local e = event
    if e == "PLAYER_LOGIN" then
        RA:InitDB()
        RA.playerName    = UnitName("player")
        RA.playerRealm   = GetRealmName() or "Unknown"
        RA.playerKey     = RA.playerName .. "-" .. RA.playerRealm
        RA.playerFaction = UnitFactionGroup("player") or "Neutral"
        RA:BuildNameIndex()
        RA:WarmItemCache()
        -- ScanCompletedQuests seeds the "already turned-in" state from the
        -- server's completed-quest cache so mid-chain attunements show the
        -- player's actual current step immediately at load, instead of
        -- waiting until the next quest in the chain is accepted.
        RA:ScanQuestLog(); RA:ScanCompletedQuests(); RA:ScanBags(); RA:RecomputeAll()
        -- The completed-quest cache is often empty on first login until
        -- QueryQuestsCompleted() round-trips to the server. Schedule extra
        -- rescans so the UI catches up as soon as the cache is populated.
        RA._retryAt = { GetTime() + 2, GetTime() + 5, GetTime() + 10 }
        if RA.Comm    and RA.Comm.Init    then RA.Comm:Init()    end
        if RA.UI      and RA.UI.Init      then RA.UI:Init()      end
        if RA.Minimap and RA.Minimap.Init then RA.Minimap:Init() end
        RA.initialized = true
        print(L.ADDON_NAME .. " v" .. RA.VERSION .. " " .. L.MSG_LOADED
              .. " (" .. tostring(RA.playerFaction) .. "). Type /attune for options.")

    elseif e == "PLAYER_ENTERING_WORLD" then
        if RA.initialized then
            RA.playerFaction = UnitFactionGroup("player") or RA.playerFaction or "Neutral"
            RA:MarkDirty()
        end

    elseif e == "QUEST_LOG_UPDATE"
        or e == "BAG_UPDATE"
        or e == "KEYRING_UPDATE"
        or e == "PLAYER_LEVEL_UP"
        or e == "UPDATE_FACTION"
        or e == "UNIT_INVENTORY_CHANGED"
        or e == "ITEM_PUSH"
        or e == "PLAYER_XP_UPDATE"
        or e == "ZONE_CHANGED_NEW_AREA"
        or e == "SKILL_LINES_CHANGED" then
        if RA.initialized then RA:MarkDirty() end

    elseif e == "QUEST_TURNED_IN" then
        if arg1 then RA:MarkQuestTurnedIn(arg1) end

    elseif e == "QUEST_QUERY_COMPLETE" then
        if RA.initialized then
            RA:ScanCompletedQuests()
            RA:RecomputeAll()
            if RA.UI and RA.UI.Refresh then RA.UI:Refresh() end
        end

    elseif e == "CHAT_MSG_ADDON" then
        if arg1 == RA.COMM_PREFIX and RA.Comm and RA.Comm.OnMessage then
            RA.Comm:OnMessage(arg2, arg3, arg4)
        end
    end
end)

ef:SetScript("OnUpdate", function(_self, _elapsed)
    if not RA.initialized then return end
    -- Vanilla 1.12 delivers elapsed via the global arg1; some private-server
    -- builds pass it as a positional parameter instead. Try both.
    local e = arg1
    if type(e) ~= "number" then e = _elapsed end
    if type(e) ~= "number" then e = _self end
    RA:_OnUpdate(e)
end)
