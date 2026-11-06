----------------------------------------------------------------------------------------------------
-- JankyPlates
-- Colors pfUI/ShaguPlates nameplates by aggro state and threat level.
-- /jplates to open options. /jplates trace on|off|clear
--
-- Requires: pfUI or ShaguPlates, SuperWoW. TWThreat recommended for threat percentages.
----------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------
-- Localize frequently-called globals to avoid table lookups in hot paths
----------------------------------------------------------------------------------------------------
local _G           = getfenv(0)
local pairs        = pairs
local tostring     = tostring
local tonumber     = tonumber
local floor        = math.floor
local sfind        = string.find
local sgsub        = string.gsub
local ssub         = string.sub
local slen         = string.len
local slower       = string.lower
local tinsert      = table.insert
local tgetn        = table.getn
local GetTime      = GetTime
local UnitName     = UnitName
local UnitExists   = UnitExists
local UnitGUID     = UnitGUID
local UnitAffectingCombat = UnitAffectingCombat
local UnitCanAssist = UnitCanAssist
local UnitIsUnit   = UnitIsUnit
local pcall        = pcall
local Trace
local TraceStatusSnapshot
local BoolToken
local StartTraceBurst
local TraceEvent

----------------------------------------------------------------------------------------------------
-- Addon namespace
----------------------------------------------------------------------------------------------------

local pfTP = {
    VERSION      = "1.0.40",
    ADDON_NAME   = "JankyPlates",
    TWT_API      = "TWTv4=",
    TWT_AGRO_KEY = "-Pull Aggro at-",

    -- Runtime state
    ready        = false,
    inCombat     = false,
    myName       = nil,
    hasSuperWoW  = (SUPERWOW_VERSION ~= nil) or (SetAutoloot ~= nil),

    -- Threat cache: [mobName] = {perc, highestNonTank, time}
    cache        = {},
    cacheGUID    = {},
    guidState    = {},
    playerGUID   = nil,
    ambiguousNames = {},
    approxTargetFrame = nil,
    approxTargetName = nil,
    autoTankCandidate = nil,
    autoTankCandidateAt = 0,

    -- Nameplate hook registry: [frame] = healthBar
    hooked       = {},

    -- Dirty flag: set when cache changes, cleared after plates recolor
    dirty           = false,
    packetsReceived = 0,
    packetsParsed   = 0,
    tmtPacketsReceived = 0,
    traceEnabled    = false,
    traceLog        = {},
    traceSeq        = 0,
    eventSeq        = 0,
    nextPlateId     = 0,

    -- Options window reference
    ui           = {},
}

----------------------------------------------------------------------------------------------------
-- Config
----------------------------------------------------------------------------------------------------

local DEFAULTS = {
    tankMode     = false,
    autoTankMode = false,
    ccEnabled    = true,
    ccR          = 0.7,
    ccG          = 0.0,
    ccB          = 1.0,
    threshYellow = 85,
    threshRed    = 99,
}

local TRACE_MAX_LINES = 12000

-- cfg is the live alias to JankyPlatesConfig after init
local cfg = {}
local dispatchState

local function IsAddOnLoadedSafe(name)
    local fn = _G.IsAddOnLoaded
    if not fn then return false end
    local ok, loaded = pcall(fn, name)
    return ok and (loaded == true or loaded == 1) or false
end

local function DetectNameplateBackend()
    if _G.pfUI or _G.pfUI_config or IsAddOnLoadedSafe("pfUI") then
        return "pfui"
    end
    if _G.ShaguPlates or _G.shaguplates or _G.ShaguPlates_config or IsAddOnLoadedSafe("ShaguPlates") then
        return "shaguplates"
    end
    return nil
end

local function LoadConfig()
    if not JankyPlatesConfig then JankyPlatesConfig = {} end
    for k, v in pairs(DEFAULTS) do
        if JankyPlatesConfig[k] == nil then
            JankyPlatesConfig[k] = v
        end
    end
    if not JankyPlatesTraceLog or type(JankyPlatesTraceLog) ~= "table" then
        JankyPlatesTraceLog = {}
    end
    if type(JankyPlatesTraceLog.lines) ~= "table" then
        JankyPlatesTraceLog.lines = {}
    end
    if type(JankyPlatesTraceLog.seq) ~= "number" then
        JankyPlatesTraceLog.seq = 0
    end
    cfg = JankyPlatesConfig
    pfTP.traceLog = JankyPlatesTraceLog.lines
    pfTP.traceSeq = JankyPlatesTraceLog.seq
end

----------------------------------------------------------------------------------------------------
-- CC detection
----------------------------------------------------------------------------------------------------

local CC_SPELLS = {
    ["Polymorph"]         = true,
    ["Shackle Undead"]    = true,
    ["Freezing Trap"]     = true,
    ["Sap"]               = true,
    ["Gouge"]             = true,
    ["Cheap Shot"]        = true,
    ["Kidney Shot"]       = true,
    ["Hammer of Justice"] = true,
    ["Intercept"]         = true,
    ["Impact"]            = true,
    ["War Stomp"]         = true,
    ["Bash"]              = true,
}

local function UnitIsCC(unitId)
    if not pfTP.hasSuperWoW then return false end
    if not UnitExists(unitId) then return false end
    for i = 1, 40 do
        local ok, _, _, _, spellId = pcall(UnitDebuff, unitId, i)
        if not ok or not spellId then break end
        local name = SpellInfo and SpellInfo(spellId)
        if name then
            for spell, _ in pairs(CC_SPELLS) do
                if sfind(name, "^" .. spell) then return true end
            end
        end
    end
    return false
end

----------------------------------------------------------------------------------------------------
-- Color logic
----------------------------------------------------------------------------------------------------

-- Returns r, g, b for a given threat percentage.
-- Thresholds read directly from cfg with fallback to defaults.
local function ThreatColor(perc)
    local red    = cfg.threshRed    or DEFAULTS.threshRed
    local yellow = cfg.threshYellow or DEFAULTS.threshYellow
    if perc >= red    then return 1.0, 0.0,  0.0  end  -- red
    if perc >= yellow then return 1.0, 1.0,  0.0  end  -- yellow
    return 0.0, 1.0, 0.0                               -- green
end

----------------------------------------------------------------------------------------------------
-- Threat cache
----------------------------------------------------------------------------------------------------

-- Reuse a single entry table per mob name to avoid per-packet allocation.
local function StoreEntry(mobName, guid, perc, highestNonTank, iAmTank, sourceTag)
    local now = GetTime()
    local entry = nil

    if guid then
        entry = pfTP.cacheGUID[guid]
    end
    if not entry then
        local byName = pfTP.cache[mobName]
        if byName and ((not guid) or (not byName.guid) or byName.guid == guid) then
            entry = byName
        end
    end
    if not entry then
        entry = {}
    end
    entry.guid           = guid
    entry.perc           = perc or 0
    entry.highestNonTank = highestNonTank or 0
    entry.iAmTank        = iAmTank or false
    entry.time           = now
    if sourceTag then
        local currentRank = 0
        local newRank = 0
        if entry.source == "target" then currentRank = 1
        elseif entry.source == "packet" then currentRank = 2
        elseif entry.source == "tmt" then currentRank = 3 end
        if sourceTag == "target" then newRank = 1
        elseif sourceTag == "packet" then newRank = 2
        elseif sourceTag == "tmt" then newRank = 3 end
        if newRank >= currentRank then
            entry.source = sourceTag
        end
    end

    pfTP.cache[mobName] = entry

    if guid then
        pfTP.cacheGUID[guid] = entry
    end

    pfTP.dirty = true
end

local function PruneCache()
    local now    = GetTime()
    local expiry = now - 30   -- CACHE_EXPIRY seconds

    -- Prune name cache.  Also nil out any guid entries pointing to expired entries.
    for k, v in pairs(pfTP.cache) do
        if v.time < expiry then
            pfTP.cache[k] = nil
        end
    end
    for k, v in pairs(pfTP.cacheGUID) do
        if v.time < expiry then
            pfTP.cacheGUID[k] = nil
        end
    end
end

local function GetEntry(name, guid)
    if guid then
        local e = pfTP.cacheGUID[guid]
        if e then return e end
        return nil
    end
    return pfTP.cache[name]
end

----------------------------------------------------------------------------------------------------
-- Packet parsing
-- TWTv4=name:tank:threat:perc:melee;...  [#TMTv1=creature:guid:playerName:perc;...]
--
-- The TMTv1 TankMode packet (appended after #) contains one entry per mob the
-- tank has aggro on, with the highest non-tank threat on each. This gives us
-- complete multi-mob coverage without any target sweeping.
----------------------------------------------------------------------------------------------------

local TWT_TANK_API = "TMTv1="

local function ParseTankModePacket(payload)
    -- TMTv1=creature:guid:playerName:perc;creature:guid:playerName:perc;...
    pfTP.tmtPacketsReceived = (pfTP.tmtPacketsReceived or 0) + 1
    pfTP.tmtLastPayload = payload
    local i   = 1
    local len = slen(payload)
    while i <= len do
        local semi  = sfind(payload, ";", i, true) or (len + 1)
        local entry = ssub(payload, i, semi - 1)
        i = semi + 1

        if slen(entry) > 0 then
            local f1end = sfind(entry, ":", 1,          true)
            local f2end = f1end and sfind(entry, ":", f1end + 1, true)
            local f3end = f2end and sfind(entry, ":", f2end + 1, true)

            if f1end and f2end and f3end then
                local creature = ssub(entry, 1,          f1end - 1)
                local guid     = ssub(entry, f1end + 1,  f2end - 1)
                local perc     = tonumber(ssub(entry, f3end + 1, slen(entry))) or 0
                local existing = nil

                if creature and slen(creature) > 0 then
                    if guid and slen(guid) > 0 then
                        existing = pfTP.cacheGUID[guid]
                    end
                    if not existing then
                        local byName = pfTP.cache[creature]
                        if byName and ((not byName.guid) or byName.guid == guid) then
                            existing = byName
                        end
                    end
                    if not existing then
                        existing = nil
                    end
                    if existing then
                        existing.perc           = existing.perc or 100
                        existing.guid           = guid
                        existing.iAmTank        = true
                        existing.highestNonTank = perc
                        existing.time           = GetTime()
                        if guid and slen(guid) > 0 then
                            pfTP.cacheGUID[guid] = existing
                        end
                        pfTP.dirty = true
                    else
                        StoreEntry(creature, guid, 100, perc, true, "tmt")
                    end
                end
            end
        end
    end
end

local function ParseAndStore(msg, senderMobName, senderMobGUID)
    local apiStart = sfind(msg, pfTP.TWT_API, 1, true)
    if not apiStart then return end
    local payload = ssub(msg, apiStart + slen(pfTP.TWT_API))

    -- Split off TankMode packet — parse it AFTER the regular store so TMT data wins
    local tmtPayloadStr = nil
    local hash = sfind(payload, "#", 1, true)
    if hash then
        tmtPayloadStr = ssub(payload, hash + 1)
        payload       = ssub(payload, 1, hash - 1)
    end

    local myPerc         = nil
    local myIsTank       = false
    local highestNonTank = 0
    local tankFound      = false
    local myName         = pfTP.myName

    -- Parse each semicolon-separated entry
    local i   = 1
    local len = slen(payload)
    while i <= len do
        local semi  = sfind(payload, ";", i, true) or (len + 1)
        local entry = ssub(payload, i, semi - 1)
        i = semi + 1

        if slen(entry) > 0 then
            local f1end  = sfind(entry, ":", 1,       true)
            local f2end  = f1end  and sfind(entry, ":", f1end  + 1, true)
            local f3end  = f2end  and sfind(entry, ":", f2end  + 1, true)
            local f4end  = f3end  and sfind(entry, ":", f3end  + 1, true)

            if f1end and f2end and f3end then
                local name   = ssub(entry, 1,          f1end - 1)
                local isTank = ssub(entry, f1end + 1,  f2end - 1) == "1"
                local perc   = tonumber(ssub(entry, f3end + 1, f4end and (f4end - 1) or slen(entry))) or 0

                if myName and name == myName then
                    myPerc   = perc
                    myIsTank = isTank
                end
                if not isTank and perc > highestNonTank then
                    highestNonTank = perc
                end
                if isTank then tankFound = true end
            end
        end
    end

    if not tankFound then highestNonTank = nil end

    -- Store for the mob this packet is about
    local mobName = senderMobName or UnitName("target")
    if mobName and myPerc then
        local guid = senderMobGUID
        if not guid and mobName == UnitName("target") then
            guid = UnitGUID and UnitGUID("target")
        end
        StoreEntry(mobName, guid, myPerc, highestNonTank, myIsTank, "packet")
    end

    -- Parse TMT after regular store so TMT highestNonTank overrides per-target data
    if tmtPayloadStr then
        local tmtStart = sfind(tmtPayloadStr, TWT_TANK_API, 1, true)
        if tmtStart then
            ParseTankModePacket(ssub(tmtPayloadStr, tmtStart + slen(TWT_TANK_API)))
        end
    end

    return myPerc, highestNonTank, myIsTank
end

local function ResolveGroupUnit(name)
    if not name then return nil end

    local numRaid = GetNumRaidMembers()
    if numRaid and numRaid > 0 then
        for i = 1, numRaid do
            if UnitName("raid" .. i) == name then
                return "raid" .. i
            end
        end
    else
        for i = 1, GetNumPartyMembers() do
            if UnitName("party" .. i) == name then
                return "party" .. i
            end
        end
    end
end

----------------------------------------------------------------------------------------------------
-- Auto tank detection
----------------------------------------------------------------------------------------------------
-- Detects tanking stances/forms by class and active form index.
-- Warrior: Defensive Stance is always form 2 (Battle=1, Defensive=2, Berserker=3)
-- Druid:   Bear Form is form 1, Dire Bear Form is form 1 (replaces Bear at 40)
--          Aquatic=2, Cat=3, Travel=4, Moonkin=5 (if talented)
-- Turtle's documented macros use GetShapeshiftFormInfo(index), so use the
-- active flag from that API directly.

local function PlayerIsInTankStance()
    local _, class = UnitClass("player")
    if not class then return false end

    if class == "WARRIOR" then
        local _, _, active = GetShapeshiftFormInfo(2)
        return active == true or active == 1

    elseif class == "DRUID" then
        local _, _, active = GetShapeshiftFormInfo(1)
        return active == true or active == 1
    end

    return false
end

-- When our tank mode is enabled, set TWT_CONFIG.tankMode = true so TWThreat
-- broadcasts TMTv1= packets containing threat on all tanked mobs.
-- We save the previous value and restore it on every exit path (combat end,
-- zone change, form change) so we don't permanently alter TWThreat's settings.
local twtTankModeWasEnabled = false
local twtTankModeSynced     = false   -- true while we have overridden TWT_CONFIG

local function SyncTWTTankMode(enable)
    if not TWT_CONFIG then return end
    if enable then
        if not twtTankModeSynced then
            -- Only save the original value on the FIRST enable call
            twtTankModeWasEnabled = TWT_CONFIG.tankMode and true or false
            twtTankModeSynced     = true
        end
        TWT_CONFIG.tankMode = true
    else
        TWT_CONFIG.tankMode   = twtTankModeWasEnabled
        twtTankModeSynced     = false
    end
end

local function UpdateAutoTank()
    if not cfg.autoTankMode then return end
    local should = PlayerIsInTankStance()
    local now = GetTime()
    if cfg.tankMode == should then
        pfTP.autoTankCandidate = nil
        pfTP.autoTankCandidateAt = 0
        return
    end
    if pfTP.autoTankCandidate ~= should then
        pfTP.autoTankCandidate = should
        pfTP.autoTankCandidateAt = now
        return
    end
    local confirmDelay = should and 1.1 or 0.2
    if (now - (pfTP.autoTankCandidateAt or 0)) < confirmDelay then
        return
    end
    cfg.tankMode = should
    pfTP.autoTankCandidate = nil
    pfTP.autoTankCandidateAt = 0
    SyncTWTTankMode(should)
    local _, playerClass = UnitClass("player")
    local _, _, form1Active = GetShapeshiftFormInfo(1)
    Trace("auto tank update tankMode=" .. tostring(should) ..
        " class=" .. tostring(playerClass) ..
        " form1Active=" .. tostring(form1Active))
    if pfTP.ui.cbTank then
        pfTP.ui.cbTank:SetChecked(should and 1 or 0)
        pfTP.ui.cbTank:Disable()
    end
    if pfTP.ui.cbTankLbl then
        pfTP.ui.cbTankLbl:SetTextColor(0.5, 0.5, 0.5)
    end
    if pfTP.inCombat then
        pfTP.dirty = true
    end
end

----------------------------------------------------------------------------------------------------
-- Nameplate detection and hooking
----------------------------------------------------------------------------------------------------
-- pfUI/ShaguPlates nameplate structure:
--   WorldFrame > Blizzard frame (Button)
--     .nameplate   overlay (set after the backend skins it)
--       .name      FontString with mob name
--     :GetChildren()  first StatusBar = health bar
--     :GetRegions()   FontStrings include mob name and level

local function FindHealthBar(frame)
    if frame.nameplate and frame.nameplate.health then
        return frame.nameplate.health
    end
    local c = { frame:GetChildren() }
    for i = 1, tgetn(c) do
        if c[i] and c[i].GetObjectType and c[i]:GetObjectType() == "StatusBar" then
            return c[i]
        end
    end
    return nil
end

local function RestoreDefaultBarColor(bar)
    local dr = bar._tpt_defR or 0.9
    local dg = bar._tpt_defG or 0.2
    local db = bar._tpt_defB or 0.3
    if bar._tpt_r ~= dr or bar._tpt_g ~= dg or bar._tpt_b ~= db then
        pfTP.colorWriteContext = "jplates:default"
        bar:SetStatusBarColor(dr, dg, db, 1)
        pfTP.colorWriteContext = nil
        bar._tpt_r = dr
        bar._tpt_g = dg
        bar._tpt_b = db
    end
    bar._tpt_source = "default"
end

local function SetResolvedBarColor(bar, r, g, b, source)
    if r and (bar._tpt_r ~= r or bar._tpt_g ~= g or bar._tpt_b ~= b) then
        pfTP.colorWriteContext = "jplates:" .. tostring(source or "resolved")
        bar:SetStatusBarColor(r, g, b, 1)
        pfTP.colorWriteContext = nil
        bar._tpt_r = r
        bar._tpt_g = g
        bar._tpt_b = b
    end
    bar._tpt_source = source
end

local function SetThreatText(bar, text)
    if not bar._tpt_text then
        return
    end
    if text then
        bar._tpt_text:SetText(text)
        if bar._tpt_text.Show then bar._tpt_text:Show() end
    else
        bar._tpt_text:SetText("")
        if bar._tpt_text.Hide then bar._tpt_text:Hide() end
    end
end

local function NextPlateDebugId()
    pfTP.nextPlateId = (pfTP.nextPlateId or 0) + 1
    return pfTP.nextPlateId
end

local ClearPlateRuntimeFields
local NON_ELITE_FALLBACK_GRACE = 0.4

local function ClearPlateIdentityFields(bar)
    if not bar then return end
    bar._tpt_lastGuid = nil
    bar._tpt_lastThreatName = nil
    bar._tpt_lockedThreatName = nil
    bar._tpt_recentFallbackAt = nil
    bar._tpt_recentFallbackName = nil
    bar._tpt_recentFallbackGuid = nil
    bar._tpt_recentFallbackR = nil
    bar._tpt_recentFallbackG = nil
    bar._tpt_recentFallbackB = nil
end

local function RememberRecentFallback(bar, name, guid, r, g, b)
    if not bar or not name or r == nil or g == nil or b == nil then return end
    bar._tpt_recentFallbackAt = GetTime()
    bar._tpt_recentFallbackName = name
    bar._tpt_recentFallbackGuid = guid
    bar._tpt_recentFallbackR = r
    bar._tpt_recentFallbackG = g
    bar._tpt_recentFallbackB = b
end

local function ShouldKeepRecentFallback(bar, name, guid)
    if not bar or not name then return false end
    local recentAt = bar._tpt_recentFallbackAt
    if not recentAt or (GetTime() - recentAt) > NON_ELITE_FALLBACK_GRACE then
        return false
    end
    if bar._tpt_recentFallbackName ~= name then
        return false
    end
    if (not guid) and bar._tpt_recentFallbackGuid then
        return false
    end
    if guid and bar._tpt_recentFallbackGuid and guid ~= bar._tpt_recentFallbackGuid then
        return false
    end
    return bar._tpt_recentFallbackR ~= nil and bar._tpt_recentFallbackG ~= nil and bar._tpt_recentFallbackB ~= nil
end

local function ApplyRecentFallback(bar)
    if not bar then return nil end
    return bar._tpt_recentFallbackR, bar._tpt_recentFallbackG, bar._tpt_recentFallbackB
end

local function ResetPlateToDefaultState(bar, clearIdentity)
    if not bar then return end
    RestoreDefaultBarColor(bar)
    SetThreatText(bar, nil)
    ClearPlateRuntimeFields(bar)
    if clearIdentity then
        ClearPlateIdentityFields(bar)
    end
end

local function ResetCombatRuntimeState()
    pfTP.inCombat = false
    dispatchState.pruneAt = GetTime() + 30
    SyncTWTTankMode(false)
    pfTP.cache     = {}
    pfTP.cacheGUID = {}
    pfTP.guidState = {}
    pfTP.ambiguousNames = {}
    pfTP.approxTargetFrame = nil
    pfTP.approxTargetName = nil
    pfTP.autoTankCandidate = nil
    pfTP.autoTankCandidateAt = 0
    dispatchState.burstReason = nil
    dispatchState.burstUntil = 0
    dispatchState.burstNextAt = 0
    for frame, bar in pairs(pfTP.hooked) do
        if bar then
            bar._tpt_r = -1
            bar._tpt_g = -1
            bar._tpt_b = -1
            ResetPlateToDefaultState(bar, true)
        end
    end
    pfTP.dirty = true
end

local function GetThreatDisplayPercent(entry)
    if not entry then return nil end
    if cfg.tankMode then
        return entry.highestNonTank or 0
    end
    return entry.perc or 0
end

local function GetThreatColorPercent(entry)
    if not entry then return nil end
    if cfg.tankMode then
        if entry.iAmTank == false then
            return nil
        end
        return entry.highestNonTank or 0
    end
    return entry.perc or 0
end

local function FormatThreatPercentText(perc)
    if perc == nil then return nil end
    local rounded = floor((perc or 0) + 0.5)
    if rounded < 0 then rounded = 0 end
    return tostring(rounded) .. "%"
end

local function SafeUnitName(unit)
    if not unit then return nil end
    local ok, name = pcall(UnitName, unit)
    if ok then return name end
    return nil
end

local function SafeUnitExists(unit)
    if not unit then return false end
    local ok, exists = pcall(UnitExists, unit)
    return ok and exists or false
end

local function CountHookedPlatesByName(name)
    local count = 0
    for frame, _ in pairs(pfTP.hooked) do
        if frame and frame.IsVisible and frame:IsVisible() and FindNameText(frame) == name then
            count = count + 1
        end
    end
    return count
end

local function MarkVisibleAmbiguousNames()
    local counts = {}
    for frame, _ in pairs(pfTP.hooked) do
        if frame and frame.IsVisible and frame:IsVisible() then
            local name = FindNameText(frame)
            if name then
                counts[name] = (counts[name] or 0) + 1
            end
        end
    end
    for name, count in pairs(counts) do
        if count > 1 then
            pfTP.ambiguousNames[name] = true
        end
    end
end

local function SafeUnitGuid(unit)
    if not unit then return nil end
    if UnitGUID then
        local ok, guid = pcall(UnitGUID, unit)
        if ok and guid then return guid end
    end
    local ok, _, guid = pcall(UnitExists, unit)
    if ok and guid and guid ~= "" then
        return guid
    end
    return nil
end

local function SafeUnitAffectingCombat(unit)
    if not unit then return false end
    local ok, active = pcall(UnitAffectingCombat, unit)
    return ok and (active == true or active == 1) or false
end

local function SafeUnitCanAssistUnit(a, b)
    if not a or not b then return false end
    local ok, result = pcall(UnitCanAssist, a, b)
    return ok and result or false
end

local function SafeUnitIsUnit(a, b)
    if not a or not b then return false end
    local ok, result = pcall(UnitIsUnit, a, b)
    return ok and result or false
end

local function GetGuidState(guid, create)
    if not guid then return nil end
    local state = pfTP.guidState[guid]
    if not state and create then
        state = {
            current_target = nil,
            current_target_name = nil,
            previous_target = nil,
            previous_target_name = nil,
            tick = 0,
            cc = false,
            casting = false,
            casting_at = nil,
            casting_at_name = nil,
        }
        pfTP.guidState[guid] = state
    end
    return state
end

local function UpdateGuidTargetState(guid, targetArg)
    local state = GetGuidState(guid, true)
    if not state then return end
    local targetGuid = targetArg or SafeUnitGuid(guid .. "target")
    local targetName = SafeUnitName(guid .. "target")
    if targetGuid ~= state.current_target or targetName ~= state.current_target_name then
        if state.current_target or state.current_target_name then
            state.previous_target = state.current_target
            state.previous_target_name = state.current_target_name
        end
        state.current_target = targetGuid
        state.current_target_name = targetName
    end
end

local function UnitMatchesPlayer(guid, name)
    if guid and pfTP.playerGUID and guid == pfTP.playerGUID then
        return true
    end
    if name and pfTP.myName and name == pfTP.myName then
        return true
    end
    return false
end

local function IsGuidCastingAtPlayer(state)
    if not state or not state.casting then return false end
    return UnitMatchesPlayer(state.casting_at, state.casting_at_name)
        or UnitMatchesPlayer(state.previous_target, state.previous_target_name)
end

local function FallbackAttackingPlayerColor()
    if cfg.tankMode then
        return 0.0, 1.0, 0.0
    end
    return 1.0, 0.0, 0.0
end

local function FallbackNotAttackingPlayerColor()
    if cfg.tankMode then
        return 1.0, 0.0, 0.0
    end
    return 0.0, 1.0, 0.0
end

local function IsThreatEntryFresh(entry)
    if not entry or not entry.time then return false end
    return (GetTime() - entry.time) <= 10
end

local function IsPacketBackedEntry(entry)
    if not entry or not entry.source then return false end
    return entry.source == "packet" or entry.source == "tmt"
end

local function IsNameCurrentlyAmbiguous(name)
    if pfTP.ambiguousNames[name] then
        return true
    end
    local count = 0
    for frame, _ in pairs(pfTP.hooked) do
        if frame and frame.IsVisible and frame:IsVisible() and FindNameText(frame) == name then
            count = count + 1
            if count > 1 then
                return true
            end
        end
    end
    return false
end

local function GetPlateThreatEntry(name, guid, isCurrentTarget, isApproxCurrentTarget)
    if guid then
        local guidEntry = pfTP.cacheGUID[guid]
        if guidEntry then return guidEntry end
    end

    local entry = pfTP.cache[name]
    if not entry then
        return nil
    end

    -- Fresh packet-backed threat should beat fallback for unique mobs even when
    -- they are no longer the current target. For ambiguous same-name elites,
    -- only the currently targeted copy gets the threat-path exception.
    if IsPacketBackedEntry(entry) and IsThreatEntryFresh(entry) then
        if IsNameCurrentlyAmbiguous(name) then
            if isCurrentTarget or isApproxCurrentTarget then
                return entry
            end
            return nil
        end
        return entry
    end

    if IsNameCurrentlyAmbiguous(name) then
        return nil
    end

    if isCurrentTarget then
        return entry
    end
    if isApproxCurrentTarget and entry.source and entry.source ~= "target" then
        return entry
    end

    return nil
end

local function IsResolvedCurrentTarget(name, unitId)
    local targetName = UnitName("target")
    if targetName ~= name then
        return nil
    end

    local targetGuid = SafeUnitGuid("target")
    if targetGuid and unitId and targetGuid == unitId then
        return true
    end

    if unitId and SafeUnitIsUnit("target", unitId) then
        return true
    end

    return false
end

local function IsNameOnlyCurrentTarget(name)
    if UnitName("target") ~= name then
        return false
    end
    local targetGuid = SafeUnitGuid("target")
    return not targetGuid
end

local function NameOnlyCurrentTargetAttackingPlayer(name)
    if not IsNameOnlyCurrentTarget(name) then return false end
    if UnitIsPlayer and UnitIsPlayer("target") then return false end
    if SafeUnitCanAssistUnit("player", "target") then return false end
    if not SafeUnitAffectingCombat("player") then return false end
    if not SafeUnitAffectingCombat("target") then return false end
    return UnitMatchesPlayer(SafeUnitGuid("targettarget"), SafeUnitName("targettarget"))
end

local function GetApproximatePlayerAnchor()
    local parent = WorldFrame or UIParent
    if not parent or not parent.GetWidth or not parent.GetHeight then
        return nil, nil
    end

    local width = parent.GetWidth and parent:GetWidth() or nil
    local height = parent.GetHeight and parent:GetHeight() or nil
    if not width or not height then
        return nil, nil
    end

    -- In the default WoW camera, the player character is usually near bottom-center.
    return width * 0.5, height * 0.30
end

local function GetFrameCenter(frame)
    if not frame or not frame.GetCenter then return nil, nil end
    local ok, x, y = pcall(frame.GetCenter, frame)
    if not ok then return nil, nil end
    return x, y
end

local function GetApproximateCurrentTargetFrame(name)
    if not IsNameOnlyCurrentTarget(name) then
        pfTP.approxTargetFrame = nil
        pfTP.approxTargetName = nil
        return nil
    end

    for candidate, bar in pairs(pfTP.hooked) do
        if candidate and bar and bar._tpt_lockedThreatName == name and candidate.IsVisible and candidate:IsVisible() and FindNameText(candidate) == name then
            pfTP.approxTargetFrame = candidate
            pfTP.approxTargetName = name
            return candidate
        end
    end

    local anchorX, anchorY = GetApproximatePlayerAnchor()
    local bestFrame = nil
    local bestScore = nil

    for candidate, _ in pairs(pfTP.hooked) do
        if candidate and candidate.IsVisible and candidate:IsVisible() and FindNameText(candidate) == name then
            local x, y = GetFrameCenter(candidate)
            local score = nil
            if anchorX and anchorY and x and y then
                local dx = x - anchorX
                local dy = y - anchorY
                score = (dx * dx) + (dy * dy)
            elseif y then
                -- Lower on screen usually means closer to the player avatar.
                score = -y
            else
                score = 999999999
            end

            if not bestScore or score < bestScore then
                bestScore = score
                bestFrame = candidate
            end
        end
    end

    pfTP.approxTargetFrame = bestFrame
    pfTP.approxTargetName = bestFrame and name or nil
    return bestFrame
end

local function CurrentTargetAttackingPlayer(name, unitId)
    if not IsResolvedCurrentTarget(name, unitId) then return false end
    if UnitIsPlayer and UnitIsPlayer("target") then return false end
    if SafeUnitCanAssistUnit("player", "target") then return false end
    if not SafeUnitAffectingCombat("player") then return false end
    if not SafeUnitAffectingCombat("target") then return false end
    return UnitMatchesPlayer(SafeUnitGuid("targettarget"), SafeUnitName("targettarget"))
end

local function CountFallbackEligiblePlatesByName(name)
    local count = 0
    for frame, _ in pairs(pfTP.hooked) do
        if frame and frame.IsVisible and frame:IsVisible() and FindNameText(frame) == name then
            local ok, guid = pcall(frame.GetName, frame, 1)
            if ok and guid and slen(tostring(guid)) > 4 and guid ~= "0x0000000000000000" then
                if SafeUnitAffectingCombat("player") and SafeUnitAffectingCombat(guid) and not SafeUnitCanAssistUnit("player", guid) then
                    count = count + 1
                end
            end
        end
    end
    return count
end

local function CountVisiblePlatesByName(name)
    local count = 0
    for frame, _ in pairs(pfTP.hooked) do
        if frame and frame.IsVisible and frame:IsVisible() and FindNameText(frame) == name then
            count = count + 1
        end
    end
    return count
end

local function ReleaseStalePlateClaims()
    for frame, bar in pairs(pfTP.hooked) do
        local visible = frame and frame.IsVisible and frame:IsVisible()
        if not visible and bar then
            ResetPlateToDefaultState(bar, true)
        end
    end
end

local function TracePlateLifecycle(frame, bar)
    if not pfTP.traceEnabled or not frame or not bar then return end
    local visible = frame.IsVisible and frame:IsVisible() or false
    local name = FindNameText(frame)
    local guid = nil
    local ok, frameGuid = pcall(frame.GetName, frame, 1)
    if ok and frameGuid and slen(tostring(frameGuid)) > 4 and frameGuid ~= "0x0000000000000000" then
        guid = frameGuid
    end

    if bar._tpt_prevVisible == nil then
        bar._tpt_prevVisible = visible
        bar._tpt_prevSeenGuid = guid
        bar._tpt_prevSeenName = name
        return
    end

    if bar._tpt_prevVisible ~= visible then
        Trace("plate-life plateId=" .. tostring(bar._tpt_plateId) ..
            " action=" .. (visible and "shown" or "hidden") ..
            " guid=" .. tostring(guid) ..
            " name=" .. tostring(name))
        bar._tpt_prevVisible = visible
        if not visible then
            ResetPlateToDefaultState(bar, true)
        elseif not pfTP.inCombat then
            ResetPlateToDefaultState(bar, false)
        else
            bar._tpt_r = -1
            bar._tpt_g = -1
            bar._tpt_b = -1
            ClearPlateIdentityFields(bar)
            ClearPlateRuntimeFields(bar)
            SetThreatText(bar, nil)
        end
        pfTP.dirty = true
    end

    if bar._tpt_prevSeenGuid ~= guid or bar._tpt_prevSeenName ~= name then
        Trace("plate-life plateId=" .. tostring(bar._tpt_plateId) ..
            " action=reused" ..
            " oldGuid=" .. tostring(bar._tpt_prevSeenGuid) ..
            " oldName=" .. tostring(bar._tpt_prevSeenName) ..
            " newGuid=" .. tostring(guid) ..
            " newName=" .. tostring(name))
        bar._tpt_prevSeenGuid = guid
        bar._tpt_prevSeenName = name
        if not pfTP.inCombat then
            ResetPlateToDefaultState(bar, true)
        else
            bar._tpt_r = -1
            bar._tpt_g = -1
            bar._tpt_b = -1
            ClearPlateIdentityFields(bar)
            ClearPlateRuntimeFields(bar)
            SetThreatText(bar, nil)
        end
        pfTP.dirty = true
    end
end

FindNameText = function(frame)
    if frame.nameplate and frame.nameplate.name then
        local n = frame.nameplate.name:GetText()
        if n then return n end
    end
    local r = { frame:GetRegions() }
    for i = 1, tgetn(r) do
        local region = r[i]
        if region and region.GetObjectType and region:GetObjectType() == "FontString" then
            local t = region:GetText()
            if t and slen(t) > 2 and not tonumber(t) then return t end
        end
    end
    return nil
end

local PLATE_CTX = {
    FindNameText = FindNameText,
    RestoreDefaultBarColor = RestoreDefaultBarColor,
    SetThreatText = SetThreatText,
    GetGuidState = GetGuidState,
    UpdateGuidTargetState = UpdateGuidTargetState,
    UnitIsCC = UnitIsCC,
    IsResolvedCurrentTarget = IsResolvedCurrentTarget,
    GetApproximateCurrentTargetFrame = GetApproximateCurrentTargetFrame,
    NameOnlyCurrentTargetAttackingPlayer = NameOnlyCurrentTargetAttackingPlayer,
    CurrentTargetAttackingPlayer = CurrentTargetAttackingPlayer,
    CountVisiblePlatesByName = CountVisiblePlatesByName,
    GetPlateThreatEntry = GetPlateThreatEntry,
    IsNameCurrentlyAmbiguous = IsNameCurrentlyAmbiguous,
    IsPacketBackedEntry = IsPacketBackedEntry,
    IsThreatEntryFresh = IsThreatEntryFresh,
    SafeUnitAffectingCombat = SafeUnitAffectingCombat,
    SafeUnitCanAssistUnit = SafeUnitCanAssistUnit,
    IsGuidCastingAtPlayer = IsGuidCastingAtPlayer,
    UnitMatchesPlayer = UnitMatchesPlayer,
    FallbackAttackingPlayerColor = FallbackAttackingPlayerColor,
    FallbackNotAttackingPlayerColor = FallbackNotAttackingPlayerColor,
    CountFallbackEligiblePlatesByName = CountFallbackEligiblePlatesByName,
    GetThreatDisplayPercent = GetThreatDisplayPercent,
    GetThreatColorPercent = GetThreatColorPercent,
    SetResolvedBarColor = SetResolvedBarColor,
    SafeUnitExists = SafeUnitExists,
    SafeUnitName = SafeUnitName,
}

local function SetPlateDebugFields(bar, unitId, isCurrentTarget, approxCurrentTarget, visibleCount, guidState, entry, entryAge)
    bar._tpt_entrySource = entry and entry.source or nil
    bar._tpt_entryAge = entryAge
    bar._tpt_entryGuidBacked = entry and entry.guid and "1" or "0"
    bar._tpt_debugGuid = unitId
    bar._tpt_debugExists = BoolToken(unitId and PLATE_CTX.SafeUnitExists(unitId) or nil)
    bar._tpt_debugCombat = BoolToken(unitId and PLATE_CTX.SafeUnitAffectingCombat(unitId) or nil)
    bar._tpt_debugRawName = unitId and PLATE_CTX.SafeUnitName(unitId) or nil
    bar._tpt_debugCurrent = isCurrentTarget and "1" or "0"
    bar._tpt_debugApprox = approxCurrentTarget and "1" or "0"
    bar._tpt_debugVisible = tostring(visibleCount)
    bar._tpt_stateCur = guidState and (tostring(guidState.current_target_name or guidState.current_target)) or nil
    bar._tpt_statePrev = guidState and (tostring(guidState.previous_target_name or guidState.previous_target)) or nil
    bar._tpt_stateCasting = guidState and BoolToken(guidState.casting) or nil
    bar._tpt_stateCastAt = guidState and (tostring(guidState.casting_at_name or guidState.casting_at)) or nil
end

ClearPlateRuntimeFields = function(bar)
    if not bar then return end
    bar._tpt_lastThreatName = nil
    bar._tpt_lockedThreatName = nil
    bar._tpt_reason = nil
    bar._tpt_entrySource = nil
    bar._tpt_entryAge = nil
    bar._tpt_entryGuidBacked = nil
    bar._tpt_debugGuid = nil
    bar._tpt_debugExists = nil
    bar._tpt_debugCombat = nil
    bar._tpt_debugRawName = nil
    bar._tpt_debugCurrent = nil
    bar._tpt_debugApprox = nil
    bar._tpt_debugVisible = nil
    bar._tpt_stateCur = nil
    bar._tpt_statePrev = nil
    bar._tpt_stateCasting = nil
    bar._tpt_stateCastAt = nil
    bar._tpt_lastWriter = nil
    bar._tpt_lastWriteAt = nil
    bar._tpt_lastWriteBefore = nil
    bar._tpt_lastWriteAfter = nil
end

local function UpdateHookedPlate(frame, elapsed, skipOrigUpdate)
    if frame._tpt_inUpdate then return end
    frame._tpt_inUpdate = true
    local origUpdate = frame._tpt_origUpdate
    local currentUpdate = frame.GetScript and frame:GetScript("OnUpdate") or nil
    if (not skipOrigUpdate) and origUpdate and origUpdate ~= currentUpdate then
        origUpdate()
    end
    if not pfTP.dirty then
        frame._tpt_inUpdate = nil
        return
    end

    local P = PLATE_CTX
    local name = P.FindNameText(frame)
    if not name then
        frame._tpt_inUpdate = nil
        return
    end

    local bar = pfTP.hooked[frame]
    if not bar then
        frame._tpt_inUpdate = nil
        return
    end
    if not pfTP.inCombat then
        ResetPlateToDefaultState(bar, true)
        frame._tpt_inUpdate = nil
        return
    end

    local unitId = nil
    if pfTP.hasSuperWoW then
        local ok, guid = pcall(frame.GetName, frame, 1)
        if ok and guid and slen(tostring(guid)) > 4 and guid ~= "0x0000000000000000" then
            unitId = guid
        end
    end
    if bar._tpt_lastGuid ~= unitId then
        bar._tpt_lastGuid = unitId
        bar._tpt_lastThreatName = nil
        bar._tpt_lockedThreatName = nil
        P.SetThreatText(bar, nil)
    end

    local isCurrentTarget = P.IsResolvedCurrentTarget(name, unitId, nil)
    local guidState = unitId and P.GetGuidState(unitId, true) or nil
    if guidState then
        P.UpdateGuidTargetState(unitId)
        guidState.tick = (guidState.tick or 0) + elapsed
        if guidState.tick >= 0.1 then
            guidState.tick = 0
            guidState.cc = P.UnitIsCC(unitId)
        end
    end

    local r, g, b, colorSource
    local decisionReason = "unknown"
    local targetName = UnitName("target")
    local approxCurrentTargetFrame = P.GetApproximateCurrentTargetFrame(name)
    local nameOnlyCurrentTarget = P.NameOnlyCurrentTargetAttackingPlayer(name)
    local approxCurrentTarget = nameOnlyCurrentTarget and approxCurrentTargetFrame == frame
    local currentTargetAttackingPlayer = P.CurrentTargetAttackingPlayer(name, unitId)
    local visibleCount = P.CountVisiblePlatesByName(name)
    local threatEntry = P.GetPlateThreatEntry(name, unitId, isCurrentTarget, approxCurrentTarget)
    local entryAge = nil
    if (not threatEntry) and (not P.IsNameCurrentlyAmbiguous(name)) and bar._tpt_lockedThreatName and targetName and name == targetName and bar._tpt_lockedThreatName == targetName then
        local lockedEntry = pfTP.cache[name]
        if lockedEntry and P.IsPacketBackedEntry(lockedEntry) and P.IsThreatEntryFresh(lockedEntry) then
            threatEntry = lockedEntry
            decisionReason = "locked-threat"
        end
    end
    if threatEntry and threatEntry.time then
        entryAge = floor(((GetTime() - threatEntry.time) * 100) + 0.5) / 100
    end
    local preferThreat = threatEntry and P.IsThreatEntryFresh(threatEntry)

    if cfg.ccEnabled and unitId and P.UnitIsCC(unitId) then
        r = cfg.ccR or 0.7
        g = cfg.ccG or 0.0
        b = cfg.ccB or 1.0
        colorSource = "cc"
        decisionReason = "cc"
    elseif pfTP.hasSuperWoW and pfTP.inCombat then
        local shouldFallbackColor = false
        if P.SafeUnitAffectingCombat("player") and unitId and guidState and P.SafeUnitAffectingCombat(unitId) and not P.SafeUnitCanAssistUnit("player", unitId) then
            shouldFallbackColor = true
            if guidState.cc then
                r = cfg.ccR or 0.7
                g = cfg.ccG or 0.0
                b = cfg.ccB or 1.0
                colorSource = "cc"
                decisionReason = "cc"
            elseif P.IsGuidCastingAtPlayer(guidState) then
                r, g, b = P.FallbackAttackingPlayerColor()
                colorSource = "fallback"
                decisionReason = "fallback-casting"
            elseif P.UnitMatchesPlayer(guidState.current_target, guidState.current_target_name) then
                r, g, b = P.FallbackAttackingPlayerColor()
                colorSource = "fallback"
                decisionReason = "fallback-guid-target"
            elseif (not guidState.casting) and (not guidState.current_target) and (not guidState.current_target_name)
                and P.UnitMatchesPlayer(guidState.previous_target, guidState.previous_target_name) then
                r, g, b = P.FallbackAttackingPlayerColor()
                colorSource = "fallback"
                decisionReason = "fallback-previous-target"
            elseif currentTargetAttackingPlayer then
                r, g, b = P.FallbackAttackingPlayerColor()
                colorSource = "fallback"
                decisionReason = "fallback-current-target"
            elseif approxCurrentTarget then
                r, g, b = P.FallbackAttackingPlayerColor()
                colorSource = "fallback"
                decisionReason = "fallback-approx-target"
            else
                r, g, b = P.FallbackNotAttackingPlayerColor()
                colorSource = "fallback"
                decisionReason = "fallback-not-attacking"
            end
        elseif currentTargetAttackingPlayer then
            shouldFallbackColor = true
            r, g, b = P.FallbackAttackingPlayerColor()
            colorSource = "fallback"
            decisionReason = "fallback-current-target"
        elseif approxCurrentTarget then
            shouldFallbackColor = true
            r, g, b = P.FallbackAttackingPlayerColor()
            colorSource = "fallback"
            decisionReason = "fallback-approx-target"
        end

        if (not threatEntry) and (not P.IsNameCurrentlyAmbiguous(name)) and targetName and name == targetName then
            local targetEntry = pfTP.cache[name]
            if targetEntry and P.IsPacketBackedEntry(targetEntry) and P.IsThreatEntryFresh(targetEntry) then
                if isCurrentTarget or approxCurrentTarget then
                    threatEntry = targetEntry
                    decisionReason = isCurrentTarget and "threat-current-target-packet" or "threat-approx-target-packet"
                elseif shouldFallbackColor and P.CountFallbackEligiblePlatesByName(name) == 1 then
                    threatEntry = targetEntry
                    decisionReason = "threat-unique-visible-packet"
                end
                preferThreat = threatEntry and true or false
            end
        end

        local entry = threatEntry
        if entry and preferThreat then
            local perc = P.GetThreatColorPercent(entry)
            if perc == nil and cfg.tankMode and entry.iAmTank == false then
                r, g, b = 1.0, 0.0, 0.0
                colorSource = "threat"
                decisionReason = "threat-lost-aggro"
                if targetName and name == targetName and P.IsPacketBackedEntry(entry) then
                    bar._tpt_lockedThreatName = name
                end
            elseif perc ~= nil then
                r, g, b = ThreatColor(perc)
                colorSource = "threat"
                if unitId and entry.guid and entry.guid == unitId then
                    decisionReason = "threat-guid-match"
                elseif isCurrentTarget then
                    decisionReason = "threat-current-target"
                elseif approxCurrentTarget then
                    decisionReason = "threat-approx-target"
                else
                    decisionReason = "threat-sticky-unique"
                end
                if targetName and name == targetName and P.IsPacketBackedEntry(entry) then
                    bar._tpt_lockedThreatName = name
                end
            elseif not shouldFallbackColor then
                if ShouldKeepRecentFallback(bar, name, unitId) then
                    r, g, b = ApplyRecentFallback(bar)
                    colorSource = "fallback"
                    decisionReason = "fallback-grace"
                else
                    P.RestoreDefaultBarColor(bar)
                    P.SetThreatText(bar, nil)
                    bar._tpt_reason = "default-no-fallback"
                    SetPlateDebugFields(bar, unitId, isCurrentTarget, approxCurrentTarget, visibleCount, guidState, entry, entryAge)
                    frame._tpt_inUpdate = nil
                    return
                end
            end
        elseif not shouldFallbackColor then
            if ShouldKeepRecentFallback(bar, name, unitId) then
                r, g, b = ApplyRecentFallback(bar)
                colorSource = "fallback"
                decisionReason = "fallback-grace"
            else
                P.RestoreDefaultBarColor(bar)
                P.SetThreatText(bar, nil)
                bar._tpt_reason = "default-no-fallback"
                SetPlateDebugFields(bar, unitId, isCurrentTarget, approxCurrentTarget, visibleCount, guidState, nil, nil)
                frame._tpt_inUpdate = nil
                return
            end
        end
    else
        local entry = threatEntry
        if not entry then
            if approxCurrentTarget then
                r, g, b = P.FallbackAttackingPlayerColor()
                colorSource = "fallback"
                decisionReason = "fallback-approx-target"
                P.SetResolvedBarColor(bar, r, g, b, colorSource)
                P.SetThreatText(bar, nil)
                bar._tpt_reason = decisionReason
                SetPlateDebugFields(bar, unitId, isCurrentTarget, approxCurrentTarget, visibleCount, guidState, nil, nil)
                frame._tpt_inUpdate = nil
                return
            end
            bar._tpt_source = "pfui"
            bar._tpt_reason = "pfui-no-threat"
            SetPlateDebugFields(bar, unitId, isCurrentTarget, approxCurrentTarget, visibleCount, guidState, nil, nil)
            P.SetThreatText(bar, nil)
            frame._tpt_inUpdate = nil
            return
        end
        local perc = P.GetThreatColorPercent(entry)
        if perc == nil and cfg.tankMode and entry.iAmTank == false then
            r, g, b = 1.0, 0.0, 0.0
            colorSource = "threat"
            decisionReason = "threat-lost-aggro"
        end
        if colorSource ~= "threat" then
            r, g, b = ThreatColor(perc)
            colorSource = "threat"
            if unitId and entry.guid and entry.guid == unitId then
                decisionReason = "threat-guid-match"
            elseif isCurrentTarget then
                decisionReason = "threat-current-target"
            elseif approxCurrentTarget then
                decisionReason = "threat-approx-target"
            else
                decisionReason = "threat-sticky-unique"
            end
            if targetName and name == targetName and P.IsPacketBackedEntry(entry) then
                bar._tpt_lockedThreatName = name
            end
        end
    end

    if bar._tpt_lockedThreatName and (not targetName or bar._tpt_lockedThreatName ~= targetName) then
        bar._tpt_lockedThreatName = nil
    end

    P.SetResolvedBarColor(bar, r, g, b, colorSource)
    if colorSource == "fallback" then
        RememberRecentFallback(bar, name, unitId, r, g, b)
    end
    bar._tpt_lastThreatName = nil
    bar._tpt_reason = decisionReason
    SetPlateDebugFields(bar, unitId, isCurrentTarget, approxCurrentTarget, visibleCount, guidState, threatEntry, entryAge)
    P.SetThreatText(bar, nil)
    frame._tpt_inUpdate = nil
end

local function RefreshVisiblePlateTraceState()
    if not pfTP.traceEnabled then return end
    local wasDirty = pfTP.dirty
    pfTP.dirty = true
    for frame, _ in pairs(pfTP.hooked) do
        if frame and frame.IsVisible and frame:IsVisible() then
            UpdateHookedPlate(frame, 0, true)
        end
    end
    pfTP.dirty = wasDirty
end

-- HookPlate attaches our OnUpdate to the nameplate frame, overriding the
-- backend's color logic while preserving the original OnUpdate via chaining.
local function HookPlate(frame, healthBar)
    if pfTP.hooked[frame] then return end
    pfTP.hooked[frame] = healthBar
    healthBar._tpt_plateId = NextPlateDebugId()

    -- Save the backend's current bar color at hook time so we can restore it after combat.
    -- This respects whatever color the player has configured in their plate addon.
    local savedR, savedG, savedB = healthBar:GetStatusBarColor()
    if not savedR then savedR = 0.9; savedG = 0.2; savedB = 0.3 end
    healthBar._tpt_defR = savedR
    healthBar._tpt_defG = savedG
    healthBar._tpt_defB = savedB

    -- Track the last color we set to avoid redundant SetStatusBarColor calls
    healthBar._tpt_r = -1
    healthBar._tpt_g = -1
    healthBar._tpt_b = -1
    healthBar._tpt_lockedThreatName = nil
    healthBar._tpt_reason = nil
    healthBar._tpt_entrySource = nil
    healthBar._tpt_debugGuid = nil
    healthBar._tpt_debugExists = nil
    healthBar._tpt_debugCombat = nil
    healthBar._tpt_debugRawName = nil
    healthBar._tpt_debugCurrent = nil
    healthBar._tpt_debugApprox = nil
    healthBar._tpt_debugVisible = nil
    healthBar._tpt_entryAge = nil
    healthBar._tpt_entryGuidBacked = nil
    healthBar._tpt_stateCur = nil
    healthBar._tpt_statePrev = nil
    healthBar._tpt_stateCasting = nil
    healthBar._tpt_stateCastAt = nil
    healthBar._tpt_lastWriter = nil
    healthBar._tpt_lastWriteAt = nil
    healthBar._tpt_lastWriteBefore = nil
    healthBar._tpt_lastWriteAfter = nil
    healthBar._tpt_prevVisible = nil
    healthBar._tpt_prevSeenGuid = nil
    healthBar._tpt_prevSeenName = nil
    SetThreatText(healthBar, nil)

    if not healthBar._tpt_origSetStatusBarColor then
        healthBar._tpt_origSetStatusBarColor = healthBar.SetStatusBarColor
        healthBar.SetStatusBarColor = function(self, nr, ng, nb, na)
            local beforeR, beforeG, beforeB = nil, nil, nil
            if self.GetStatusBarColor then
                beforeR, beforeG, beforeB = self:GetStatusBarColor()
            end
            local writer = pfTP.colorWriteContext or "external"
            self:_tpt_origSetStatusBarColor(nr, ng, nb, na)
            local afterR, afterG, afterB = nil, nil, nil
            if self.GetStatusBarColor then
                afterR, afterG, afterB = self:GetStatusBarColor()
            end
            self._tpt_lastWriter = writer
            self._tpt_lastWriteAt = GetTime()
            self._tpt_lastWriteBefore = string.format("%.2f/%.2f/%.2f", beforeR or 0, beforeG or 0, beforeB or 0)
            self._tpt_lastWriteAfter = string.format("%.2f/%.2f/%.2f", afterR or 0, afterG or 0, afterB or 0)
            if pfTP.traceEnabled then
                Trace("color-write plateId=" .. tostring(self._tpt_plateId) ..
                    " writer=" .. tostring(writer) ..
                    " before=" .. tostring(self._tpt_lastWriteBefore) ..
                    " req=" .. string.format("%.2f/%.2f/%.2f", nr or 0, ng or 0, nb or 0) ..
                    " after=" .. tostring(self._tpt_lastWriteAfter) ..
                    " source=" .. tostring(self._tpt_source or "unknown"))
            end
        end
    end

    frame._tpt_origUpdate = frame:GetScript("OnUpdate")
    frame:SetScript("OnUpdate", function()
        UpdateHookedPlate(this, arg1 or 0)
    end)
end

----------------------------------------------------------------------------------------------------
-- Main update dispatcher
-- Handles: tank mode server query, nameplate scanner, dirty flag, cache prune
----------------------------------------------------------------------------------------------------

local dispatcher = CreateFrame("Frame")
dispatcher:Hide()

-- TW_UDTS_TANK: Experimental server query for multi-mob tank threat data.
-- This is the tank mode variant of TWThreat's UDTS query string.
-- If the server supports it, it responds with TMTv1= data for all tanked mobs.
-- Sent via pcall so it fails silently if the API is not available.
local TW_UDTS_TANK = "TWT_UDTSv4_TM"
local TW_QUERY_RATE = 0.5

dispatchState = {
    scanTimer     = 0,
    scanChildren  = -1,
    pruneAt       = nil,
    dirtyTimer    = 0,
    queryTimer    = 0,
    attackingTimer = 0,  -- separate timer for priority-2 periodic dirty
    autoTankTimer = 0,
    traceSnapshotTimer = 0,
    burstReason = nil,
    burstUntil = 0,
    burstNextAt = 0,
}

dispatcher:SetScript("OnUpdate", function()
    local now = GetTime()
    local ds  = dispatchState

    -- Tank mode server query: attempt to get multi-mob threat from server.
    -- Sends "TWT_UDTSv4_TM" which is the tank mode variant of TWThreat's query.
    -- Server responds with TMTv1= data if supported. Harmless if not supported.
    if pfTP.inCombat and cfg.tankMode then
        if (now - ds.queryTimer) >= TW_QUERY_RATE then
            ds.queryTimer = now
            local numRaid  = GetNumRaidMembers()
            local numParty = GetNumPartyMembers()
            local channel  = (numRaid > 0) and "RAID" or "PARTY"
            local limit    = (numRaid > 0) and numRaid or numParty
            if limit > 0 then
                pcall(SendAddonMessage, TW_UDTS_TANK, "limit=" .. limit, channel)
            end
        end
    end

    -- Priority 2 (attacking me) changes every frame based on mob targets.
    -- Keep dirty set periodically during combat so plates re-evaluate.
    if pfTP.inCombat and pfTP.hasSuperWoW then
        if (now - ds.attackingTimer) >= 0.1 then
            ds.attackingTimer = now
            pfTP.dirty = true
        end
    end

    -- Some Turtle/SuperWoW form changes do not reliably fire UPDATE_SHAPESHIFT_FORMS
    -- during combat, so keep auto tank mode synced with the player's active form.
    if cfg.autoTankMode and pfTP.inCombat then
        if (now - ds.autoTankTimer) >= 0.1 then
            ds.autoTankTimer = now
            UpdateAutoTank()
        end
    end

    if pfTP.traceEnabled and pfTP.inCombat then
        if (now - ds.traceSnapshotTimer) >= 5.0 then
            ds.traceSnapshotTimer = now
            TraceStatusSnapshot("5s")
        end
        if ds.burstUntil and now <= ds.burstUntil and now >= (ds.burstNextAt or 0) then
            ds.burstNextAt = now + 0.25
            TraceStatusSnapshot("burst:" .. tostring(ds.burstReason or "unknown"))
        end
    end

    -- Scanner: detect new nameplate frames
    if (now - ds.scanTimer) >= 0.5 then
        ds.scanTimer = now
        ReleaseStalePlateClaims()
        local n = WorldFrame:GetNumChildren()
        ds.scanChildren = n
        local children = { WorldFrame:GetChildren() }
        for i = 1, tgetn(children) do
            local child = children[i]
                if child then
                    if not pfTP.hooked[child] then
                        local name = FindNameText(child)
                        local bar  = FindHealthBar(child)
                        if name and bar then
                            HookPlate(child, bar)
                        end
                    end
                    if pfTP.hooked[child] then
                        TracePlateLifecycle(child, pfTP.hooked[child])
                    end
                    if pfTP.hasSuperWoW then
                        local ok, guid = pcall(child.GetName, child, 1)
                    if ok and guid and slen(tostring(guid)) > 4 and guid ~= "0x0000000000000000" then
                        local state = GetGuidState(guid, true)
                        if state then
                            state.cc = UnitIsCC(guid)
                        end
                    end
                end
            end
        end
        MarkVisibleAmbiguousNames()
    end

    -- Clear dirty flag after all plates have had a chance to update
    -- (plates update on OnUpdate, so clearing dirty one frame later is safe)
    if pfTP.dirty then
        if (now - ds.dirtyTimer) >= 0.05 then
            ds.dirtyTimer = now
            pfTP.dirty    = false
        end
    end

    -- Scheduled cache prune
    if ds.pruneAt and now >= ds.pruneAt then
        ds.pruneAt = nil
        PruneCache()
    end
end)

----------------------------------------------------------------------------------------------------
-- Event handling
----------------------------------------------------------------------------------------------------

local EVENT_CTX = {
    LoadConfig = LoadConfig,
    SafeUnitGuid = SafeUnitGuid,
    TraceEvent = function(name, extra) return TraceEvent(name, extra) end,
    UpdateAutoTank = UpdateAutoTank,
    Trace = function(msg) return Trace(msg) end,
    TraceStatusSnapshot = function(reason) return TraceStatusSnapshot(reason) end,
    SyncTWTTankMode = SyncTWTTankMode,
    StartTraceBurst = function(reason) return StartTraceBurst(reason) end,
    ResetCombatRuntimeState = ResetCombatRuntimeState,
    PlayerIsInTankStance = PlayerIsInTankStance,
    GetGuidState = GetGuidState,
    ResolveGroupUnit = ResolveGroupUnit,
    BoolToken = function(value) return BoolToken(value) end,
    GetEntry = GetEntry,
    ParseAndStore = ParseAndStore,
    StoreEntry = StoreEntry,
    SafeUnitAffectingCombat = SafeUnitAffectingCombat,
    UpdateGuidTargetState = UpdateGuidTargetState,
    RefreshVisiblePlateTraceState = RefreshVisiblePlateTraceState,
}

local function HandleAddonEvent()
    local E = EVENT_CTX
    if event ~= "VARIABLES_LOADED" and not pfTP.ready then return end

    if event == "VARIABLES_LOADED" then
        E.LoadConfig()
        pfTP.myName = UnitName("player")
        pfTP.playerGUID = E.SafeUnitGuid("player")
        pfTP.ready = true
        E.TraceEvent("VARIABLES_LOADED", "playerGuid=" .. tostring(pfTP.playerGUID))
        E.UpdateAutoTank()
        E.Trace("variables loaded version=" .. tostring(pfTP.VERSION) ..
            " myName=" .. tostring(pfTP.myName) ..
            " yellow=" .. tostring(cfg.threshYellow or DEFAULTS.threshYellow) ..
            " red=" .. tostring(cfg.threshRed or DEFAULTS.threshRed))

        pfTP.backend = DetectNameplateBackend()
        if not pfTP.backend then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[JankyPlates]|r neither pfUI nor ShaguPlates was found - disabled.")
            return
        end

        if pfTP.backend == "pfui" and pfUI_config and pfUI_config.nameplates then
            local np = pfUI_config.nameplates
            np.sw_healthcolor      = "1"
            np.sw_attackingyou     = "1"
            np.sw_attackingofftank = "1"
            np.sw_attackingothers  = "1"
            np.sw_attackingnoone   = "1"
        end

        if not TWT then
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cffffff00[JankyPlates]|r TWThreat not found. " ..
                "Install TWThreat for threat coloring."
            )
        else
            if cfg.tankMode then E.SyncTWTTankMode(true) end
        end

        local swMsg = pfTP.hasSuperWoW
            and "|cff88ff44SuperWoW detected."
            or  "|cffffff00No SuperWoW - CC detection disabled."
        local backendLabel = (pfTP.backend == "shaguplates") and "ShaguPlates" or "pfUI"
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cff88ff44[JankyPlates]|r v" .. pfTP.VERSION ..
            " loaded on " .. backendLabel .. ". " .. swMsg .. " |cffffffff/jplates for options."
        )
        dispatcher:Show()

    elseif event == "PLAYER_REGEN_DISABLED" then
        E.TraceEvent("PLAYER_REGEN_DISABLED", "target=" .. tostring(UnitName("target")) .. " guid=" .. tostring(UnitGUID and UnitGUID("target")))
        pfTP.inCombat = true
        pfTP.dirty = true
        E.UpdateAutoTank()
        E.StartTraceBurst("combat-start")
        dispatchState.traceSnapshotTimer = GetTime()
        E.Trace("combat start target=" .. tostring(UnitName("target")) ..
            " guid=" .. tostring(UnitGUID and UnitGUID("target")) ..
            " tankMode=" .. tostring(cfg.tankMode) ..
            " stance=" .. tostring(E.PlayerIsInTankStance()))
        E.TraceStatusSnapshot("combat-start")
        if cfg.tankMode then
            E.SyncTWTTankMode(true)
            if TWT and TWT.combatStart then TWT.combatStart(true) end
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        E.TraceEvent("PLAYER_REGEN_ENABLED", "target=" .. tostring(UnitName("target")))
        local hadCache = next(pfTP.cache) ~= nil
        local packetCount = pfTP.packetsReceived
        E.ResetCombatRuntimeState()
        E.TraceStatusSnapshot("combat-end")
        E.Trace("combat end cache=" .. tostring(hadCache) ..
            " packets=" .. tostring(packetCount))

    elseif event == "PLAYER_DEAD" then
        E.TraceEvent("PLAYER_DEAD", "target=" .. tostring(UnitName("target")))
        E.Trace("player dead")
        E.ResetCombatRuntimeState()

    elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
        E.TraceEvent(event, "target=" .. tostring(UnitName("target")))
        E.Trace("player revived event=" .. tostring(event))
        E.ResetCombatRuntimeState()

    elseif event == "UPDATE_SHAPESHIFT_FORMS" then
        E.TraceEvent("UPDATE_SHAPESHIFT_FORMS", "current=" .. tostring(GetShapeshiftForm and GetShapeshiftForm() or nil))
        E.UpdateAutoTank()
        E.StartTraceBurst("shapeshift")
        E.SyncTWTTankMode(cfg.tankMode)
        E.Trace("form update tankMode=" .. tostring(cfg.tankMode) ..
            " stance=" .. tostring(E.PlayerIsInTankStance()))

    elseif event == "UNIT_MODEL_CHANGED" then
        E.TraceEvent("UNIT_MODEL_CHANGED", "unit=" .. tostring(arg1))
        E.StartTraceBurst("model:" .. tostring(arg1))
        if arg1 and sfind(arg1, "^nameplate") then
            dispatchState.scanChildren = -1
        end

    elseif event == "UNIT_CASTEVENT" then
        E.TraceEvent("UNIT_CASTEVENT", "source=" .. tostring(arg1) .. " target=" .. tostring(arg2) .. " state=" .. tostring(arg3))
        E.StartTraceBurst("cast:" .. tostring(arg3))
        local sourceGuid = E.SafeUnitGuid(arg1)
        local targetGuid = E.SafeUnitGuid(arg2)
        local targetName = SafeUnitName(arg2)
        local state = E.GetGuidState(sourceGuid, false)
        if state then
            if arg3 == "START" then
                state.casting = true
                state.casting_at = targetGuid
                state.casting_at_name = targetName
            elseif arg3 == "FAIL" or arg3 == "CAST" then
                state.casting = false
                state.casting_at = nil
                state.casting_at_name = nil
            end
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        E.TraceEvent("PLAYER_ENTERING_WORLD", "target=" .. tostring(UnitName("target")))
        E.Trace("entering world")
        E.SyncTWTTankMode(false)
        E.UpdateAutoTank()
        pfTP.playerGUID = E.SafeUnitGuid("player")
        for frame, bar in pairs(pfTP.hooked) do
            if bar then
                bar._tpt_r = -1
                bar._tpt_g = -1
                bar._tpt_b = -1
                ResetPlateToDefaultState(bar, true)
            end
        end
        pfTP.cache = {}
        pfTP.cacheGUID = {}
        pfTP.guidState = {}
        pfTP.ambiguousNames = {}
        pfTP.approxTargetFrame = nil
        pfTP.approxTargetName = nil
        pfTP.hooked = {}
        pfTP.inCombat = false
        dispatchState.scanChildren = -1
        dispatchState.scanTimer = GetTime() + 2.0
        if cfg.tankMode then E.SyncTWTTankMode(true) end

    elseif event == "PLAYER_TARGET_CHANGED" then
        E.TraceEvent("PLAYER_TARGET_CHANGED", "target=" .. tostring(UnitName("target")) .. " guid=" .. tostring(UnitGUID and UnitGUID("target")))
        E.StartTraceBurst("target-change")
        pfTP.dirty = true
        pfTP.approxTargetFrame = nil
        pfTP.approxTargetName = nil
        for frame, bar in pairs(pfTP.hooked) do
            if bar then
                bar._tpt_lockedThreatName = nil
            end
        end
        E.Trace("target changed target=" .. tostring(UnitName("target")) ..
            " guid=" .. tostring(UnitGUID and UnitGUID("target")) ..
            " inCombat=" .. tostring(pfTP.inCombat))
        E.RefreshVisiblePlateTraceState()
        E.TraceStatusSnapshot("target-change")
        if pfTP.inCombat then
            local targetGuid = E.SafeUnitGuid("target")
            if targetGuid then
                E.UpdateGuidTargetState(targetGuid, E.SafeUnitGuid("targettarget"))
            end
        end
        if pfTP.inCombat and TWT and TWT.threats and pfTP.myName then
            local tname = UnitName("target")
            local guid = UnitGUID and UnitGUID("target")
            if tname and not UnitIsPlayer("target") and E.SafeUnitAffectingCombat("target") then
                local me = TWT.threats[pfTP.myName]
                if me then
                    local highest = 0
                    local agro = TWT.AGRO or pfTP.TWT_AGRO_KEY
                    for name, data in pairs(TWT.threats) do
                        if not data.tank and name ~= agro then
                            local p = data.perc or 0
                            if p > highest then highest = p end
                        end
                    end
                    E.StoreEntry(tname, guid, me.perc, highest, me.tank, "target")
                    E.Trace("target store mob=" .. tostring(tname) ..
                        " guid=" .. tostring(guid) ..
                        " perc=" .. tostring(me.perc) ..
                        " nt=" .. tostring(highest) ..
                        " tank=" .. tostring(me.tank))
                end
            end
        end

    elseif event == "CHAT_MSG_ADDON" then
        if not arg2 then return end
        if not sfind(arg2, pfTP.TWT_API, 1, true) then return end

        pfTP.packetsReceived = pfTP.packetsReceived + 1

        local sender = arg4
        local mobName = nil
        local guid = nil
        local senderUnit = nil
        local targetUnit = nil
        local senderTargetName = nil
        local senderTargetGuid = nil
        local senderTargetCombat = nil
        local attributionReason = nil
        local existingBefore = nil

        if sender and sender ~= pfTP.myName then
            senderUnit = E.ResolveGroupUnit(sender)
            if senderUnit then
                targetUnit = senderUnit .. "target"
                local tgt = UnitName(targetUnit)
                senderTargetName = tgt
                senderTargetGuid = UnitGUID and UnitGUID(targetUnit)
                senderTargetCombat = E.SafeUnitAffectingCombat(targetUnit)
                if tgt and not UnitIsPlayer(targetUnit) and E.SafeUnitAffectingCombat(targetUnit) then
                    mobName = tgt
                    guid = senderTargetGuid
                    attributionReason = "party-target"
                else
                    E.Trace("packet-attrib sender=" .. tostring(sender) ..
                        " senderUnit=" .. tostring(senderUnit) ..
                        " target=" .. tostring(senderTargetName) ..
                        " targetGuid=" .. tostring(senderTargetGuid) ..
                        " targetCombat=" .. E.BoolToken(senderTargetCombat) ..
                        " reason=no-attributable-target")
                end
            else
                E.Trace("packet-attrib sender=" .. tostring(sender) .. " reason=unresolved-sender-unit")
            end
        else
            if UnitName("target") and not UnitIsPlayer("target") and E.SafeUnitAffectingCombat("target") then
                mobName = UnitName("target")
                guid = UnitGUID and UnitGUID("target")
                senderTargetName = mobName
                senderTargetGuid = guid
                senderTargetCombat = E.SafeUnitAffectingCombat("target")
                attributionReason = "self-target"
            end
        end

        local hasTankModePayload = sfind(arg2, "#" .. TWT_TANK_API, 1, true) ~= nil
        if not mobName and not hasTankModePayload then
            E.Trace("packet-attrib sender=" .. tostring(sender) ..
                " senderUnit=" .. tostring(senderUnit) ..
                " target=" .. tostring(senderTargetName) ..
                " targetGuid=" .. tostring(senderTargetGuid) ..
                " targetCombat=" .. E.BoolToken(senderTargetCombat) ..
                " reason=ignored-no-attributable-mob")
            return
        end

        if mobName then
            existingBefore = E.GetEntry(mobName, guid)
        end
        local myPerc, highestNT, myIsTank = E.ParseAndStore(arg2, mobName, guid)
        pfTP.lastPacketSender = sender
        pfTP.lastPacketMob = mobName
        pfTP.lastPacketGUID = guid
        pfTP.lastPacketMyPerc = myPerc
        pfTP.lastPacketNT = highestNT
        if mobName then
            E.Trace("packet sender=" .. tostring(sender) ..
                " mob=" .. tostring(mobName) ..
                " guid=" .. tostring(guid) ..
                " myPerc=" .. tostring(myPerc) ..
                " nt=" .. tostring(highestNT) ..
                " attr=" .. tostring(attributionReason) ..
                " senderUnit=" .. tostring(senderUnit) ..
                " senderTarget=" .. tostring(senderTargetName) ..
                " senderTargetGuid=" .. tostring(senderTargetGuid) ..
                " senderTargetCombat=" .. E.BoolToken(senderTargetCombat))
        elseif hasTankModePayload then
            E.Trace("tmt sender=" .. tostring(sender) .. " parsed-without-direct-mob-attribution")
        end
        if myPerc and mobName then pfTP.packetsParsed = pfTP.packetsParsed + 1 end
        if myPerc and guid and mobName then
            local entry = pfTP.cache[mobName]
            if entry then pfTP.cacheGUID[guid] = entry end
        end
        if mobName and myPerc and (not existingBefore or not existingBefore.time or (GetTime() - existingBefore.time) > 10) then
            E.StartTraceBurst("first-packet:" .. tostring(mobName))
        end
        if mobName and myPerc and myIsTank == false then
            E.StartTraceBurst("aggro-loss:" .. tostring(mobName))
        end
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("VARIABLES_LOADED")
events:RegisterEvent("CHAT_MSG_ADDON")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_DEAD")
events:RegisterEvent("PLAYER_ALIVE")
events:RegisterEvent("PLAYER_UNGHOST")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
if (SUPERWOW_VERSION ~= nil) or (SetAutoloot ~= nil) then
    events:RegisterEvent("UNIT_MODEL_CHANGED")
    events:RegisterEvent("UNIT_CASTEVENT")
end

events:SetScript("OnEvent", HandleAddonEvent)

----------------------------------------------------------------------------------------------------
-- Options window
----------------------------------------------------------------------------------------------------

local function CreateOptionsWindow()
    local f = CreateFrame("Frame", "JankyPlates_Options", UIParent)
    f:SetWidth(320)
    f:SetHeight(485)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left=11, right=12, top=12, bottom=11 },
    })
    f:SetBackdropColor(0, 0, 0, 0.9)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop",  function() this:StopMovingOrSizing() end)
    f:SetFrameStrata("DIALOG")
    f:Hide()

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -16)
    title:SetText("JankyPlates")

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Helpers
    local function Checkbox(label, y, getV, setV)
        local cb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", f, "TOPLEFT", 20, y)
        cb:SetWidth(24); cb:SetHeight(24)
        cb:SetChecked(getV())
        cb:SetScript("OnClick", function() setV(this:GetChecked() == 1) end)
        local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lbl:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        lbl:SetText(label)
        return cb, lbl
    end

    local function Note(text, y)
        local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", f, "TOPLEFT", 46, y)
        fs:SetTextColor(0.6, 0.6, 0.6)
        fs:SetText(text)
        return fs
    end

    local function SectionLabel(text, y)
        local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", f, "TOPLEFT", 20, y)
        fs:SetTextColor(0.7, 0.7, 0.7)
        fs:SetText(text)
        return fs
    end

    local function Divider(y)
        local d = f:CreateTexture(nil, "ARTWORK")
        d:SetHeight(1); d:SetWidth(280)
        d:SetPoint("TOPLEFT", f, "TOPLEFT", 20, y)
        d:SetTexture(0.3, 0.3, 0.3, 1)
    end

    local function Slider(label, y, lo, hi, getV, setV, cr, cg, cb_)
        local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lbl:SetPoint("TOPLEFT", f, "TOPLEFT", 20, y)
        lbl:SetTextColor(cr, cg, cb_)
        lbl:SetText(label)

        local val = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        val:SetPoint("TOPRIGHT", f, "TOPRIGHT", -20, y)
        val:SetText(tostring(getV()) .. "%")

        local track = CreateFrame("Frame", nil, f)
        track:SetPoint("TOPLEFT", f, "TOPLEFT", 20, y - 22)
        track:SetWidth(278); track:SetHeight(8)
        track:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "", tile = false, tileSize = 0, edgeSize = 0,
            insets = { left=0, right=0, top=0, bottom=0 },
        })
        track:SetBackdropColor(0.15, 0.15, 0.15, 1)

        local sl = CreateFrame("Slider", nil, f)
        sl:SetOrientation("HORIZONTAL")
        sl:SetPoint("TOPLEFT", f, "TOPLEFT", 20, y - 18)
        sl:SetWidth(278); sl:SetHeight(16)
        sl:SetMinMaxValues(lo, hi)
        sl:SetValueStep(1)
        sl:SetValue(getV())
        sl:EnableMouse(true)
        sl:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")

        local mn = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        mn:SetPoint("TOPLEFT", track, "BOTTOMLEFT", 0, -3)
        mn:SetTextColor(0.5, 0.5, 0.5); mn:SetText(lo .. "%")

        local mx = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        mx:SetPoint("TOPRIGHT", track, "BOTTOMRIGHT", 0, -3)
        mx:SetTextColor(0.5, 0.5, 0.5); mx:SetText(hi .. "%")

        sl:SetScript("OnValueChanged", function()
            local v = floor(this:GetValue())
            setV(v)
            val:SetText(v .. "%")
        end)
    end

    -- Layout
    local y = -46

    SectionLabel("TANK MODE", y); y = y - 20

    local cbAutoTank = Checkbox("Auto-Detect Tank Role", y,
        function() return cfg.autoTankMode end,
        function(v)
            cfg.autoTankMode = v
            if v then
                if pfTP.ui.cbTank    then pfTP.ui.cbTank:Disable() end
                if pfTP.ui.cbTankLbl then pfTP.ui.cbTankLbl:SetTextColor(0.5, 0.5, 0.5) end
                UpdateAutoTank()
            else
                if pfTP.ui.cbTank    then pfTP.ui.cbTank:Enable() end
                if pfTP.ui.cbTankLbl then pfTP.ui.cbTankLbl:SetTextColor(1, 1, 1) end
            end
        end)
    y = y - 20
    Note("Warrior (Defensive Stance) / Druid (Bear Form).", y)
    y = y - 26

    local cbTank, cbTankLbl = Checkbox("Tank Mode", y,
        function() return cfg.tankMode end,
        function(v) if not cfg.autoTankMode then cfg.tankMode = v; SyncTWTTankMode(v); pfTP.dirty = true end end)
    pfTP.ui.cbTank    = cbTank
    pfTP.ui.cbTankLbl = cbTankLbl
    y = y - 20
    Note("Colors by highest non-tank threat on each mob.", y)
    y = y - 28

    Divider(y); y = y - 12
    SectionLabel("CC DETECTION", y); y = y - 20

    -- Checkbox left-justified, color swatch right-justified on same row
    Checkbox("Show CC as Purple (requires SuperWoW)", y,
        function() return cfg.ccEnabled end,
        function(v) cfg.ccEnabled = v; pfTP.dirty = true end)

    -- Color swatch button: clicking opens the game's native ColorPickerFrame
    local swatch = CreateFrame("Button", nil, f)
    swatch:SetWidth(24); swatch:SetHeight(24)
    swatch:SetPoint("TOPRIGHT", f, "TOPRIGHT", -20, y)

    -- Solid color fill — no overlay texture so the whole square shows the color
    local swatchTex = swatch:CreateTexture(nil, "BACKGROUND")
    swatchTex:SetPoint("TOPLEFT",     swatch, "TOPLEFT",     1,  -1)
    swatchTex:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", -1,  1)
    swatchTex:SetTexture(cfg.ccR or 0.7, cfg.ccG or 0.0, cfg.ccB or 1.0)
    pfTP.ui.swatchTex = swatchTex  -- stored so OnShow can refresh it

    -- Thin 1px dark border via a backdrop frame behind the button
    local swatchBG = CreateFrame("Frame", nil, f)
    swatchBG:SetWidth(26); swatchBG:SetHeight(26)
    swatchBG:SetPoint("CENTER", swatch, "CENTER", 0, 0)
    swatchBG:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "", tile = false, tileSize = 0, edgeSize = 0,
        insets = { left=0, right=0, top=0, bottom=0 },
    })
    swatchBG:SetBackdropColor(0.1, 0.1, 0.1, 1)

    local function UpdateSwatch()
        swatchTex:SetTexture(cfg.ccR or 0.7, cfg.ccG or 0.0, cfg.ccB or 1.0)
        pfTP.dirty = true
    end

    swatch:SetScript("OnClick", function()
        local prevR = cfg.ccR or 0.7
        local prevG = cfg.ccG or 0.0
        local prevB = cfg.ccB or 1.0

        ColorPickerFrame:SetColorRGB(prevR, prevG, prevB)
        ColorPickerFrame.previousValues = { prevR, prevG, prevB }

        ColorPickerFrame.func = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            cfg.ccR = r; cfg.ccG = g; cfg.ccB = b
            UpdateSwatch()
        end
        ColorPickerFrame.cancelFunc = function(prev)
            cfg.ccR = prev[1]; cfg.ccG = prev[2]; cfg.ccB = prev[3]
            UpdateSwatch()
        end

        -- Raise color picker above the options window
        ShowUIPanel(ColorPickerFrame)
        ColorPickerFrame:SetFrameStrata("TOOLTIP")
        ColorPickerFrame:Raise()
    end)

    y = y - 20
    Note("Nameplate color for CC'd mobs (Sheeped, Sapped, etc).", y)
    y = y - 28

    Divider(y); y = y - 12
    SectionLabel("THREAT THRESHOLDS", y); y = y - 16
    Note("Green = below Yellow.  Red = at or above Red.", y); y = y - 18

    Slider("Yellow at:", y, 0, 100,
        function() return cfg.threshYellow end,
        function(v)
            cfg.threshYellow = v
            if cfg.threshRed < v then cfg.threshRed = v end
            pfTP.dirty = true
        end, 1.0, 0.85, 0.0)
    y = y - 46

    Slider("Red at:", y, 0, 100,
        function() return cfg.threshRed end,
        function(v)
            cfg.threshRed = v
            if cfg.threshYellow > v then cfg.threshYellow = v end
            pfTP.dirty = true
        end, 1.0, 0.0, 0.0)

    pfTP.ui.frame = f

    f:SetScript("OnShow", function()
        if pfTP.ui.cbTank     then pfTP.ui.cbTank:SetChecked(cfg.tankMode and 1 or 0) end
        if pfTP.ui.cbAutoTank then pfTP.ui.cbAutoTank:SetChecked(cfg.autoTankMode and 1 or 0) end
        if cfg.autoTankMode then
            if pfTP.ui.cbTank    then pfTP.ui.cbTank:Disable() end
            if pfTP.ui.cbTankLbl then pfTP.ui.cbTankLbl:SetTextColor(0.5, 0.5, 0.5) end
        else
            if pfTP.ui.cbTank    then pfTP.ui.cbTank:Enable() end
            if pfTP.ui.cbTankLbl then pfTP.ui.cbTankLbl:SetTextColor(1, 1, 1) end
        end
        if pfTP.ui.swatchTex then
            pfTP.ui.swatchTex:SetTexture(cfg.ccR or 0.7, cfg.ccG or 0.0, cfg.ccB or 1.0)
        end
    end)

    pfTP.ui.cbAutoTank = cbAutoTank
end

local function ToggleOptions()
    if not pfTP.ui.frame then CreateOptionsWindow() end
    if pfTP.ui.frame:IsVisible() then pfTP.ui.frame:Hide()
    else pfTP.ui.frame:Show() end
end

local function FormatThreatEntry(entry)
    if not entry then return "nil" end
    return "perc=" .. tostring(entry.perc) ..
        " nt=" .. tostring(entry.highestNonTank) ..
        " tank=" .. tostring(entry.iAmTank) ..
        " guid=" .. tostring(entry.guid)
end

local function ReportUnitStatus(chat, label, unit)
    local uname = UnitName(unit)
    local uguid = UnitGUID and UnitGUID(unit)
    if not uname then
        chat:AddMessage("  " .. label .. " = nil")
        return
    end

    local entry = GetEntry(uname, uguid)
    local targetName = nil
    if pfTP.hasSuperWoW and UnitExists(unit .. "target") then
        targetName = UnitName(unit .. "target")
    end

    chat:AddMessage("  " .. label .. " = " .. uname ..
        " guid=" .. tostring(uguid) ..
        " target=" .. tostring(targetName) ..
        " entry={" .. FormatThreatEntry(entry) .. "}")
end

BoolToken = function(value)
    if value == nil then return "nil" end
    if value == true or value == 1 then return "1" end
    return "0"
end

StartTraceBurst = function(reason)
    if not pfTP.traceEnabled then return end
    local now = GetTime()
    dispatchState.burstReason = reason
    dispatchState.burstUntil = now + 2.0
    dispatchState.burstNextAt = now
end

TraceEvent = function(name, extra)
    if not pfTP.traceEnabled then return end
    pfTP.eventSeq = (pfTP.eventSeq or 0) + 1
    local line = "event#" .. tostring(pfTP.eventSeq) .. " name=" .. tostring(name)
    if extra and extra ~= "" then
        line = line .. " " .. extra
    end
    Trace(line)
end

local function RawFormSnapshot()
    local _, class = UnitClass("player")
    local numForms = GetNumShapeshiftForms() or 0
    local currentForm = GetShapeshiftForm and GetShapeshiftForm() or nil
    local parts = {
        "api forms",
        "class=" .. tostring(class),
        "count=" .. tostring(numForms),
        "current=" .. tostring(currentForm),
    }
    for i = 1, numForms do
        local _, _, active = GetShapeshiftFormInfo(i)
        tinsert(parts, "f" .. tostring(i) .. "=" .. BoolToken(active))
    end
    return table.concat(parts, " ")
end

local function RawUnitReadLine(label, unit)
    local exists = SafeUnitExists(unit)
    local name = SafeUnitName(unit)
    local guid = SafeUnitGuid(unit)
    local combat = SafeUnitAffectingCombat(unit)
    local assist = SafeUnitCanAssistUnit("player", unit)
    local isPlayer = nil
    if unit then
        local ok, result = pcall(UnitIsPlayer, unit)
        if ok then isPlayer = result end
    end
    return "api " .. tostring(label) ..
        " unit=" .. tostring(unit) ..
        " exists=" .. BoolToken(exists) ..
        " name=" .. tostring(name) ..
        " guid=" .. tostring(guid) ..
        " combat=" .. BoolToken(combat) ..
        " assist=" .. BoolToken(assist) ..
        " player=" .. BoolToken(isPlayer)
end

local function UnitSnapshot(unit)
    local uname = UnitName(unit)
    if not uname then
        return unit .. "=nil"
    end

    local uguid = UnitGUID and UnitGUID(unit)
    local entry = GetEntry(uname, uguid)
    local targetName = nil
    if pfTP.hasSuperWoW and UnitExists(unit .. "target") then
        targetName = UnitName(unit .. "target")
    end

    return unit .. "=" .. uname ..
        " guid=" .. tostring(uguid) ..
        " target=" .. tostring(targetName) ..
        " entry={" .. FormatThreatEntry(entry) .. "}"
end

local function PlateSnapshot(frame, bar)
    if frame and frame.IsVisible and not frame:IsVisible() then
        return nil
    end
    local name = FindNameText(frame)
    if not name or not bar then return nil end
    local actualR, actualG, actualB = bar:GetStatusBarColor()
    local wantR = bar._tpt_r
    local wantG = bar._tpt_g
    local wantB = bar._tpt_b
    local r = actualR
    local g = actualG
    local b = actualB
    if r == nil or g == nil or b == nil then
        r, g, b = wantR, wantG, wantB
    end
    return "plate=" .. tostring(name) ..
        " color=" .. string.format("%.2f/%.2f/%.2f", r or 0, g or 0, b or 0) ..
        " want=" .. string.format("%.2f/%.2f/%.2f", wantR or 0, wantG or 0, wantB or 0) ..
        " source=" .. tostring(bar._tpt_source or "unknown") ..
        " plateId=" .. tostring(bar._tpt_plateId) ..
        " guid=" .. tostring(bar._tpt_debugGuid) ..
        " exists=" .. tostring(bar._tpt_debugExists) ..
        " combat=" .. tostring(bar._tpt_debugCombat) ..
        " rawname=" .. tostring(bar._tpt_debugRawName) ..
        " current=" .. tostring(bar._tpt_debugCurrent) ..
        " approx=" .. tostring(bar._tpt_debugApprox) ..
        " visible=" .. tostring(bar._tpt_debugVisible) ..
        " entry=" .. tostring(bar._tpt_entrySource or "nil") ..
        " entryAge=" .. tostring(bar._tpt_entryAge or "nil") ..
        " entryGuidBacked=" .. tostring(bar._tpt_entryGuidBacked or "nil") ..
        " locked=" .. tostring(bar._tpt_lockedThreatName or nil) ..
        " curTgt=" .. tostring(bar._tpt_stateCur or "nil") ..
        " prevTgt=" .. tostring(bar._tpt_statePrev or "nil") ..
        " cast=" .. tostring(bar._tpt_stateCasting or "nil") ..
        " castAt=" .. tostring(bar._tpt_stateCastAt or "nil") ..
        " writer=" .. tostring(bar._tpt_lastWriter or "nil") ..
        " wroteAt=" .. tostring(bar._tpt_lastWriteAt or "nil") ..
        " before=" .. tostring(bar._tpt_lastWriteBefore or "nil") ..
        " after=" .. tostring(bar._tpt_lastWriteAfter or "nil") ..
        " reason=" .. tostring(bar._tpt_reason or "unknown")
end

TraceStatusSnapshot = function(reason)
    if not pfTP.traceEnabled then return end

    local cacheCount = 0
    for _, _ in pairs(pfTP.cache) do cacheCount = cacheCount + 1 end

    local threatCount = 0
    if TWT and TWT.threats then
        for _, _ in pairs(TWT.threats) do threatCount = threatCount + 1 end
    end

    Trace("snapshot[" .. tostring(reason) .. "]" ..
        " version=" .. tostring(pfTP.VERSION) ..
        " inCombat=" .. tostring(pfTP.inCombat) ..
        " tankMode=" .. tostring(cfg.tankMode) ..
        " auto=" .. tostring(cfg.autoTankMode) ..
        " stance=" .. tostring(PlayerIsInTankStance()) ..
        " yellow=" .. tostring(cfg.threshYellow or DEFAULTS.threshYellow) ..
        " red=" .. tostring(cfg.threshRed or DEFAULTS.threshRed) ..
        " target=" .. tostring(UnitName("target")) ..
        " cache=" .. tostring(cacheCount) ..
        " packets=" .. tostring(pfTP.packetsReceived) ..
        " twt=" .. tostring(threatCount))
    Trace(RawFormSnapshot())
    Trace(RawUnitReadLine("player", "player"))
    Trace(UnitSnapshot("target"))
    Trace(RawUnitReadLine("target", "target"))
    Trace(RawUnitReadLine("targettarget", "targettarget"))
    Trace(RawUnitReadLine("party1target", "party1target"))

    local plateCount = 0
    for frame, bar in pairs(pfTP.hooked) do
        local line = PlateSnapshot(frame, bar)
        if line then
            Trace(line)
            plateCount = plateCount + 1
            if plateCount >= 6 then break end
        end
    end
end

Trace = function(msg)
    if not pfTP.traceEnabled then return end
    if pfTP.traceLast == msg and sfind(msg, "^packet sender=") then
        return
    end
    pfTP.traceSeq = (pfTP.traceSeq or 0) + 1
    local line = string.format("#%d t=%.1f %s", pfTP.traceSeq, GetTime(), msg)
    local log = pfTP.traceLog
    tinsert(log, line)
    pfTP.traceLast = msg
    if tgetn(log) > TRACE_MAX_LINES then
        table.remove(log, 1)
    end
    if JankyPlatesTraceLog then
        JankyPlatesTraceLog.seq = pfTP.traceSeq
    end
end

----------------------------------------------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------------------------------------------

SLASH_JANKYPLATES1 = "/jplates"
SlashCmdList["JANKYPLATES"] = function(cmd)
    if not cmd or cmd == "" then
        ToggleOptions()
        return
    end

    if sfind(cmd, "^trace") then
        local arg = slower(sgsub(cmd, "^trace%s*", ""))
        if arg == "" then
            pfTP.traceEnabled = not pfTP.traceEnabled
        elseif arg == "on" then
            pfTP.traceEnabled = true
        elseif arg == "off" then
            pfTP.traceEnabled = false
        elseif arg == "clear" then
            pfTP.traceLog = {}
            pfTP.traceSeq = 0
            pfTP.traceLast = nil
            JankyPlatesTraceLog = { lines = pfTP.traceLog, seq = 0 }
            DEFAULT_CHAT_FRAME:AddMessage("|cff88ff44[JankyPlates]|r trace log cleared.")
            return
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff88ff44[JankyPlates]|r usage: /jplates trace [on|off|clear]")
            return
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff88ff44[JankyPlates]|r trace " ..
            (pfTP.traceEnabled and "enabled" or "disabled") ..
            " (saved to SavedVariables on reload/logout).")
        if pfTP.traceEnabled then
            TraceStatusSnapshot("trace-on")
        end
        return
    end

    ToggleOptions()
end
