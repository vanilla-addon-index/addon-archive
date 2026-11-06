-- AnySCT core.lua -- targetSCT list, event sources, dispatch, saved variables, slash commands.
--
-- Everything that needs a frame lives at the bottom behind "if CreateFrame then", so the logic
-- above (targetSCT list, per-mob hit counters, dispatch) runs offline under Lua 5.0 with stubbed unit
-- functions (tools/luatests).
--
-- SOURCE LIST
--   An ordered list of targetSCTs, each an entry { name, src, unit, targetUnit, guid, ... }.
--   src "manual": /asct add <name>, saved per character.
--   src "main":   CT_RA_MainTanks / oRA_MainTanks entries (option importMain), shown as "import".
--   Events of any listed targetSCT are shown over THAT targetSCT's target. The player's own events are never
--   shown (the player's own SCT addon stays the only one that shows their damage).
--
-- This addon never touches Blizzard's CombatText, SHOW_COMBAT_TEXT or any other SCT addon.

AnySCT_Core = {}
local C = AnySCT_Core

AnySCT_DEFAULTS = {
    enabled = true,
    direction = "up",        -- "up" | "down"
    sizeFactor = 1.0,        -- text size = 0.018333 x screen diagonal x this (crits 0.0275)
    wordFactor = 1.0,        -- same for Miss / Dodge / Parry / ...
    font = "CLIENT",         -- "CLIENT" (DAMAGE_TEXT_FONT) | "FRIZQT" | "SKURRI" | "ARIALN"
    riseHeight = 120,        -- px a normal text rises (crits stay in place); the style table is authoritative
    jitter = 0,              -- random horizontal px per line
    maxLines = 60,
    maxLinesPerTarget = 16,
    onlyWhileSourceFights = false, -- true: hide text while the listed source itself is not in combat (renamed from showOnlyInCombat, which gated on the PLAYER)
    colourize = false,       -- false: everything orange like the pet text; true: crit yellow, miss red, block blue, ...
    mergeHits = true,        -- identical attacks (same source, victim, attack, hit/crit) within a short window become ONE line with the running sum
    mergeWindow = 0.4,       -- seconds a line keeps absorbing identical hits
    mergeCount = false,      -- append " x5" to a merged line
    markGlancing = false,    -- true: add "glancing" / "crushing" after the number
    guessTotemOwner = false, -- unknown totem owner = the only listed shaman (can misattribute enemy / own totems)
    classColours = false,    -- numbers / words take the source's class colour (pets: the owner's)
    showHeals = true,        -- heals received by a listed targetSCT float over it (green, "+N" and the healer)
    showHots = false,        -- also heal-over-time ticks (chat only, can be noisy)
    showOwnHeals = true,     -- include the player's own heals on the targetSCTs (the engine never floats heals)
    healShowHealer = true,   -- healer name under the number
    showSpells = true,       -- listen to special attack rows (Heroic Strike, ...); off unregisters the spell channels
    includeTotems = true,    -- also show totem damage whose owner is a listed targetSCT (needs an owner lookup)
    showSpellName = false,
    mobNameMode = "never",  -- "never" | "anchor" (only at the fixed anchor) | "always"; renamed key so the old "anchor" default is not inherited
    sourceNameMode = "multi", -- "never" | "multi" (only with more than one listed) | "always": the listed source's name in the suffix line
    colorPerTarget = false,  -- true: every listed source gets its own text colour (auto-picked, changeable in the list)
    showLabel = false,       -- "targetSCTs: ..." line above the anchor
    threatGo = false,        -- experimental GO / WAIT label from server threat data (TWThreat protocol)
    threatTrace = false,     -- record the received threat data to <WoW>\imports\anysct_threat.txt (bug reports; needs SuperWoW)
    threatGoLead = 1500,     -- threat buffer (points) the targetSCT needs over you before the label says GO
    extendRange = true,      -- combat log range 200: raid targetSCTs outside the party are silent otherwise
    minimap = true,
    mmAngle = 200,
    importMain = true,
    placement = "clamp",     -- "clamp" | "anchorOff" | "anchor" | "both"
    noPlate = "anchor",      -- "anchor" | "hide"
    edgeMargin = 40,
    xOffset = 40,            -- plate modes: shift right so targetSCT numbers sit beside the player's own
    yOffset = 0,
    plateRange = 0,          -- 0 = leave the nameplate range CVars alone
    pos = { point = "CENTER", x = 0, y = 120 },
}

local state = {
    order = {},              -- targetSCT names in list order
    byName = {},             -- name -> entry
    byGuid = {},             -- normalised guid -> entry
    petByName = {},          -- pet name -> owner entry
    petByGuid = {},          -- normalised pet guid -> owner entry
    roster = {},             -- name -> unit token
    nampower = false,
    npSpells = false,
    npHeals = false,
    needCode = 0,
    loaded = false,
}
C.state = state

function C.Now()
    if GetTime then return GetTime() end
    return 0
end

-- ---- saved variables -------------------------------------------------------------------------

local function copyValue(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = x end
    return t
end

-- One-time migration of saved variables written before the "tank" -> "targetSCT" rename: every
-- key whose name contains "tank" (any case) moves to the new spelling, in the root table, in the
-- options and in each character table. A value already present under the new key wins.
local RENAMED = { importMainTanks = "importMain" }

local function newKey(k)
    if RENAMED[k] then return RENAMED[k] end
    local n = string.gsub(k, "Tank", "Source")
    n = string.gsub(n, "tank", "source")
    return n
end

local function migrateKeys(t)
    if type(t) ~= "table" then return end
    local moves
    for k in pairs(t) do
        if type(k) == "string" and string.find(string.lower(k), "tank", 1, true) then
            moves = moves or {}
            table.insert(moves, k)
        end
    end
    if not moves then return end
    for i = 1, table.getn(moves) do
        local k = moves[i]
        local nk = newKey(k)
        if t[nk] == nil then t[nk] = t[k] end
        t[k] = nil
    end
end

function C.MigrateDB()
    local db = AnySCTDB
    if type(db) ~= "table" or (db.dbVersion or 0) >= 4 then return end
    if (db.dbVersion or 0) < 2 then
        migrateKeys(db)
        migrateKeys(db.opt)
        if type(db.chars) == "table" then
            for _, c in pairs(db.chars) do migrateKeys(c) end
        end
    end
    -- v3: the hit-count GO / WAIT indicator is gone (threat based now)
    if type(db.opt) == "table" then db.opt.goAfterHits = nil end
    -- v4: line limits raised (16 / 4 -> 60 / 16); only values still equal to the old defaults are reset,
    -- a limit the user chose deliberately stays
    if type(db.opt) == "table" then
        if db.opt.maxLines == 16 then db.opt.maxLines = nil end
        if db.opt.maxLinesPerTarget == 4 then db.opt.maxLinesPerTarget = nil end
    end
    db.dbVersion = 4
end

function C.InitDB()
    if type(AnySCTDB) ~= "table" then AnySCTDB = {} end
    C.MigrateDB()
    if type(AnySCTDB.opt) ~= "table" then AnySCTDB.opt = {} end
    if type(AnySCTDB.chars) ~= "table" then AnySCTDB.chars = {} end
    local o = AnySCTDB.opt
    for k, v in pairs(AnySCT_DEFAULTS) do
        if o[k] == nil then o[k] = copyValue(v) end
    end
    return o
end

function C.Opt(key)
    if not AnySCTDB or not AnySCTDB.opt then C.InitDB() end
    return AnySCTDB.opt[key]
end

-- The whole option table (for the display code).
function C.Opts()
    if not AnySCTDB or not AnySCTDB.opt then C.InitDB() end
    return AnySCTDB.opt
end

function C.SetOpt(key, value)
    if not AnySCTDB or not AnySCTDB.opt then C.InitDB() end
    AnySCTDB.opt[key] = value
    if key == "extendRange" and value then C.ExtendRange() end
    if key == "plateRange" then C.ApplyPlateRange() end
    if key == "showSpells" or key == "showHeals" or key == "showHots" or key == "showOwnHeals" then C.UpdateEvents() end
    if key == "enabled" then
        C.UpdateEvents()
        if value then
            if UnitAffectingCombat("player") and C.StartTick then C.StartTick() end
        elseif C.StopTick then
            C.StopTick()
        end
    end
    if key == "importMain" then C.SyncMain() end
    if key == "threatGo" or key == "threatGoLead" then
        C.UpdateEvents()
        C.ThreatRefresh()
    end
    if AnySCT_SCT and AnySCT_SCT.OptionChanged then AnySCT_SCT.OptionChanged(key) end
    if key == "minimap" and AnySCT_Minimap and AnySCT_Minimap.Update then AnySCT_Minimap.Update() end
end

function C.CharKey()
    local realm = "?"
    if GetRealmName then realm = GetRealmName() or "?" end
    return realm .. "-" .. (UnitName("player") or "?")
end

-- Per-character table: { list = { names }, colours = { name = "RRGGBB" }, threat = { name = true|false } }.
function C.Char()
    if not AnySCTDB or not AnySCTDB.chars then C.InitDB() end
    local k = C.CharKey()
    local c = AnySCTDB.chars[k]
    if not c then
        c = { list = {} }
        AnySCTDB.chars[k] = c
    end
    if type(c.list) ~= "table" then c.list = {} end
    if type(c.colours) ~= "table" then c.colours = {} end
    if type(c.threat) ~= "table" then c.threat = {} end
    return c
end

function C.Print(msg)
    if C.out then C.out(msg) return end
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff55ccffAnySCT|r: " .. msg)
    end
end

-- Debug trace (/asct debug). Callers test C.debug BEFORE building any string, so it costs nothing off.
C.debug = false
function C.Dbg(msg)
    if C.debug then C.Print("|cff888888dbg|r " .. msg) end
end

-- ---- GUIDs -----------------------------------------------------------------------------------

-- SuperWoW: UnitExists returns (exists, guid). Without it the second value is nil -> no GUID.
function C.ResolveGuid(unit)
    if not unit then return nil end
    local ok, _, g = pcall(UnitExists, unit)
    if ok and type(g) == "string" then return g end
    if GetUnitGUID then
        local ok2, g2 = pcall(GetUnitGUID, unit)
        if ok2 and type(g2) == "string" then return g2 end
    end
    return nil
end

local normCache, normCount = {}, 0

-- Canonical form of a GUID so "0x000000000000ABCD", "0xabcd" and the number 43981 compare equal.
-- Memoised (events come in at raid rate); the memo is dropped when it grows past 300 entries.
function C.NormGuid(g)
    if g == nil then return nil end
    local hit = normCache[g]
    if hit then return hit end
    local s
    if type(g) == "number" then
        s = string.format("%x", g)
    else
        s = string.lower(tostring(g))
        s = string.gsub(s, "^0x", "")
        s = string.gsub(s, "^0+", "")
    end
    if s == "" then s = "0" end
    if normCount >= 300 then normCache = {}; normCount = 0 end
    normCache[g] = s
    normCount = normCount + 1
    return s
end

-- ---- roster ----------------------------------------------------------------------------------

-- Pet token of a group unit: pet, raidpetN, partypetN.
local function petToken(u)
    if not u then return nil end
    if u == "player" then return "pet" end
    local _, _, n = string.find(u, "^raid(%d+)$")
    if n then return "raidpet" .. n end
    _, _, n = string.find(u, "^party(%d+)$")
    if n then return "partypet" .. n end
    return nil
end

function C.DropPet(e)
    if e.petName and state.petByName[e.petName] == e then state.petByName[e.petName] = nil end
    if e.petNorm and state.petByGuid[e.petNorm] == e then state.petByGuid[e.petNorm] = nil end
    e.petName, e.petNorm = nil, nil
end

-- Cache the targetSCT's pet (name + GUID). Tokens are range limited, so the name cache keeps what it saw.
function C.RefreshPet(e)
    C.ClearOwnerCache()
    C.DropPet(e)
    if not e.petUnit then return end
    local ok, ex = pcall(UnitExists, e.petUnit)
    if not (ok and ex) then return end
    e.petName = UnitName(e.petUnit)
    local g = C.ResolveGuid(e.petUnit)
    e.petNorm = g and C.NormGuid(g) or nil
    if e.petName then state.petByName[e.petName] = e end
    if e.petNorm then state.petByGuid[e.petNorm] = e end
end

function C.RefreshEntry(e)
    local u = state.roster[e.name]
    e.unit = u
    e.targetUnit = u and (u .. "target") or nil
    e.petUnit = petToken(u)
    e.class = nil
    if u and UnitClass then
        local _, cls = UnitClass(u)
        e.class = cls
    end
    if u then
        if e.guidNorm and state.byGuid[e.guidNorm] == e then state.byGuid[e.guidNorm] = nil end
        local g = C.ResolveGuid(u)
        e.guid = g
        e.guidNorm = g and C.NormGuid(g) or nil
    end
    -- a source outside the group keeps the GUID it was last seen with
    if e.guidNorm then state.byGuid[e.guidNorm] = e end
    C.RefreshPet(e)
end

-- A listed source outside the group (hostile player, mob): learn its GUID when we see the unit.
function C.SeeUnit(name, unit)
    local e = state.byName[name]
    if not e or e.unit or UnitName(unit) ~= name then return end
    local g = C.ResolveGuid(unit)
    if not g then return end
    if e.guidNorm and state.byGuid[e.guidNorm] == e then state.byGuid[e.guidNorm] = nil end
    e.guid = g
    e.guidNorm = C.NormGuid(g)
    state.byGuid[e.guidNorm] = e
    if UnitIsPlayer(unit) and UnitClass then
        local _, cls = UnitClass(unit)
        e.class = cls
    end
end

function C.SeeLoose(unit)
    local n = UnitName(unit)
    if n and state.byName[n] and not state.byName[n].unit then C.SeeUnit(n, unit) end
end

local PROBE_UNITS = { "target", "targettarget", "mouseover" }

-- True when some listed source outside the group still has no GUID.
local function anyLooseWithoutGuid()
    for i = 1, table.getn(state.order) do
        local e = state.byName[state.order[i]]
        if not e.unit and not e.guidNorm then return true end
    end
    return false
end

-- Look at the units we can name (target, its target, mouseover) for listed sources without a GUID.
function C.ProbeLoose()
    if not anyLooseWithoutGuid() then return false end
    for i = 1, table.getn(PROBE_UNITS) do C.SeeLoose(PROBE_UNITS[i]) end
    return not anyLooseWithoutGuid()
end

local lastRetry = -10
-- On-demand GUID retry when an event of a GUID-less source arrives: group sources via their token,
-- loose ones via ProbeLoose. Rate limited to 2 per second; no cost while every source has a GUID.
function C.RetryGuids()
    local t = C.Now()
    if t - lastRetry < 0.5 then return false end
    lastRetry = t
    local changed = C.FillGuids()
    if C.ProbeLoose() then changed = true end
    if changed and C.CheckCreature then C.CheckCreature() end
    return changed
end
function C.ResetRetry() lastRetry = -10 end

function C.RebuildRoster()
    local r = state.roster
    for k in pairs(r) do r[k] = nil end
    local nr = GetNumRaidMembers()
    if nr > 0 then
        for i = 1, nr do
            local u = "raid" .. i
            local n = UnitName(u)
            if n then r[n] = u end
        end
    else
        local np = GetNumPartyMembers()
        for i = 1, np do
            local u = "party" .. i
            local n = UnitName(u)
            if n then r[n] = u end
        end
    end
    local pn = UnitName("player")
    if pn then r[pn] = "player" end
    -- every entry gets a fresh token
    for i = 1, table.getn(state.order) do C.RefreshEntry(state.byName[state.order[i]]) end
    C.SyncMain()
    C.NotifyChanged()
end

-- ---- colours -----------------------------------------------------------------------------------

-- Auto palette: bright, saturated colours that read on game backgrounds. The first one is Blizzard's
-- pet orange, so a single listed unit looks as before. None is close to the heal green 19FF19.
C.PALETTE = { "FF8400", "00E5FF", "FF00FF", "FFFF00", "4D8DFF", "A6FF00", "FF6EB4", "9A4DFF",
              "FF3030", "FFFFFF", "00C8A0" }

function C.HexToRgb(hex)
    local r = tonumber(string.sub(hex, 1, 2), 16) or 255
    local g = tonumber(string.sub(hex, 3, 4), 16) or 255
    local b = tonumber(string.sub(hex, 5, 6), 16) or 255
    return r / 255, g / 255, b / 255
end

function C.RgbToHex(r, g, b)
    local function c(x)
        x = math.floor(x * 255 + 0.5)
        if x < 0 then x = 0 elseif x > 255 then x = 255 end
        return x
    end
    return string.format("%02X%02X%02X", c(r), c(g), c(b))
end

-- Squared "redmean" colour distance of two hex colours (a cheap perceptual weighting of RGB).
function C.ColourDistance(h1, h2)
    local r1, g1, b1 = C.HexToRgb(h1)
    local r2, g2, b2 = C.HexToRgb(h2)
    local rm = (r1 + r2) / 2
    local dr, dg, db = r1 - r2, g1 - g2, b1 - b2
    return (2 + rm) * dr * dr + 4 * dg * dg + (3 - rm) * db * db
end

-- Palette colour whose smallest distance to the colours in `used` (array of hex) is the largest.
-- Nothing used: the first palette colour. Ties go to the earlier palette entry (deterministic).
function C.PickAutoColour(used)
    local pal = C.PALETTE
    if not used or table.getn(used) == 0 then return pal[1] end
    local best, bestD = pal[1], -1
    for i = 1, table.getn(pal) do
        local m = 1e9
        for j = 1, table.getn(used) do
            local d = C.ColourDistance(pal[i], used[j])
            if d < m then m = d end
        end
        if m > bestD + 1e-9 then best, bestD = pal[i], m end
    end
    return best
end

local usedBuf = {}
local function usedColours(skip)
    -- cleared from the end: table.getn on a table with leading holes is unreliable in Lua 5.0
    for i = table.getn(usedBuf), 1, -1 do table.remove(usedBuf, i) end
    for i = 1, table.getn(state.order) do
        local o = state.byName[state.order[i]]
        if o ~= skip and o.hex then table.insert(usedBuf, o.hex) end
    end
    return usedBuf
end

local function applyColour(e, hex)
    e.hex = hex
    local r, g, b = C.HexToRgb(hex)
    e.rgb = { r, g, b }
    C.Char().colours[e.name] = hex
end

-- Give a new entry its saved colour, else the best-separated palette colour.
function C.AssignColour(e)
    local saved = C.Char().colours[e.name]
    if type(saved) == "string" and string.len(saved) == 6 and tonumber(saved, 16) then
        applyColour(e, string.upper(saved))
    else
        applyColour(e, C.PickAutoColour(usedColours(e)))
    end
end

-- Manual colour (kept until AutoColours). hex "RRGGBB".
function C.SetColour(name, hex)
    local e = state.byName[name]
    if not e then return false end
    applyColour(e, hex)
    return true
end

-- Re-assign every colour by the auto rule, in list order.
function C.AutoColours()
    for i = 1, table.getn(state.order) do state.byName[state.order[i]].hex = nil end
    for i = 1, table.getn(state.order) do
        local e = state.byName[state.order[i]]
        applyColour(e, C.PickAutoColour(usedColours(e)))
    end
    C.NotifyChanged()
end

-- ---- targetSCT list -------------------------------------------------------------------------------

function C.NotifyChanged()
    C.CheckCreature()
    C.ThreatRefresh()
    if AnySCT_SCT and AnySCT_SCT.UpdateLabel then AnySCT_SCT.UpdateLabel() end
    if AnySCT_Options and AnySCT_Options.refresh then AnySCT_Options.refresh() end
end

local function indexOf(list, name)
    for i = 1, table.getn(list) do
        if list[i] == name then return i end
    end
    return nil
end

function C.Count(src)
    local n = 0
    for i = 1, table.getn(state.order) do
        if not src or state.byName[state.order[i]].src == src then n = n + 1 end
    end
    return n
end

-- Add (or upgrade) a targetSCT. src: "manual" | "main". Manual entries are saved per character
-- unless noPersist (used when loading the saved list).
-- Default of the per-targetSCT "Threat" switch: on for friendly players (group members, imported main
-- tanks, names typed in blind), off for pets, totems, mobs and hostile players. info (optional, from the
-- right-click menu): { player = bool, friendly = bool } for a unit we could look at.
function C.DefaultThreatOn(name, src, info)
    if src == "main" then return true end
    if state.roster[name] then return true end
    if string.find(name, "Totem", 1, true) then return false end
    if info then
        if info.player == false then return false end
        if info.friendly == false then return false end
    end
    return true
end

function C.AssignThreat(e, info)
    local saved = C.Char().threat[e.name]
    if type(saved) == "boolean" then
        e.threatOn = saved
    else
        e.threatOn = C.DefaultThreatOn(e.name, e.src, info)
        C.Char().threat[e.name] = e.threatOn
    end
end

function C.SetThreatOn(name, on)
    local e = state.byName[name]
    if not e then return false end
    e.threatOn = on and true or false
    C.Char().threat[name] = e.threatOn
    C.ThreatRefresh()
    return true
end

function C.AddSource(name, src, noPersist, info)
    local e = state.byName[name]
    if e then
        if src == "manual" and e.src ~= "manual" then e.src = "manual" end
    else
        e = { name = name, src = src, paren = "(" .. name .. ")" }
        state.byName[name] = e
        table.insert(state.order, name)
        C.AssignColour(e)
        C.AssignThreat(e, info)
        C.RefreshEntry(e)
    end
    if src == "manual" and not noPersist then
        local list = C.Char().list
        if not indexOf(list, name) then table.insert(list, name) end
    end
    C.NotifyChanged()
    return e
end

function C.RemoveSource(name, noNotify)
    local e = state.byName[name]
    if not e then return false end
    if e.guidNorm and state.byGuid[e.guidNorm] == e then state.byGuid[e.guidNorm] = nil end
    C.DropPet(e)
    state.byName[name] = nil
    local i = indexOf(state.order, name)
    if i then table.remove(state.order, i) end
    local list = C.Char().list
    local j = indexOf(list, name)
    if j then table.remove(list, j) end
    C.Char().colours[name] = nil    -- the colour is free again
    C.Char().threat[name] = nil
    if not noNotify then C.NotifyChanged() end
    return true
end

function C.ClearSources()
    while table.getn(state.order) > 0 do C.RemoveSource(state.order[1], true) end
    C.Char().list = {}
    C.Char().colours = {}
    C.Char().threat = {}
    C.NotifyChanged()
end

-- ---- main tank lists (CT_RaidAssist / oRA) --------------------------------------------------------

local mainBuf, mainN = {}, 0

local function collectMain(t)
    if type(t) ~= "table" then return end
    for i = 1, 12 do
        local n = t[i]
        if type(n) == "string" and n ~= "" and not indexOf(mainBuf, n) then
            mainN = mainN + 1
            mainBuf[mainN] = n
        end
    end
end

function C.SyncMain()
    for i = 1, mainN do mainBuf[i] = nil end
    mainN = 0
    if C.Opt("importMain") then
        collectMain(CT_RA_MainTanks)
        collectMain(oRA_MainTanks)
    end
    for i = 1, mainN do
        local n = mainBuf[i]
        if state.roster[n] then C.AddSource(n, "main", true) end
    end
    local i = 1
    while i <= table.getn(state.order) do
        local e = state.byName[state.order[i]]
        if e.src == "main" and not indexOf(mainBuf, e.name) then
            C.RemoveSource(e.name, true)
        else
            i = i + 1
        end
    end
end

-- ---- targets of the listed sources -----------------------------------------------------------

-- Refresh every targetSCT's current target (used to place chat rows, which carry only a victim name).
function C.UpdateSourceTargets()
    for i = 1, table.getn(state.order) do
        local e = state.byName[state.order[i]]
        local tt = e.targetUnit
        e.targetKey, e.targetName, e.targetGuid, e.targetHostile = nil, nil, nil, false
        if tt then
            local ok, ex, g = pcall(UnitExists, tt)
            if ok and ex then
                e.targetGuid = (type(g) == "string") and g or nil
                e.targetName = UnitName(tt)
                e.targetKey = e.targetGuid or e.targetName
                e.targetHostile = (UnitCanAttack("player", tt) and not UnitIsDead(tt)) and true or false
            end
        end
    end
end

-- ---- owner resolution (pets, totems) -------------------------------------------------------------

local ownerCache, ownerCount, cacheClearAt = {}, 0, nil

function C.ClearOwnerCache()
    for k in pairs(ownerCache) do ownerCache[k] = nil end
    ownerCount, cacheClearAt = 0, nil
end

-- After leaving combat the owner cache is dropped 60 s later (checked lazily, no timer).
function C.ScheduleCacheClear() cacheClearAt = C.Now() + 60 end

local function onlyShaman()
    local found
    for i = 1, table.getn(state.order) do
        local e = state.byName[state.order[i]]
        if e.class == "SHAMAN" then
            if found then return nil end
            found = e
        end
    end
    return found and found.name or nil
end

local function isGuid(x)
    return type(x) == "number" or (type(x) == "string" and string.find(x, "^0x") ~= nil)
end

-- Owner name of a pet or totem given its GUID or its name, or nil. Pluggable: replace the global
-- to change the lookup. Cascade: cache -> SuperWoW owner suffix -> pet caches -> class fallback (a
-- "Totem" belongs to the only shaman among the listed targetSCTs) -> unknown. Cached per key.
function AnySCT_OwnerOf(x)
    if x == nil then return nil end
    if cacheClearAt and C.Now() >= cacheClearAt then C.ClearOwnerCache() end
    local guid = isGuid(x)
    local key = guid and C.NormGuid(x) or x
    local hit = ownerCache[key]
    if hit ~= nil then return hit or nil end
    local owner
    if guid then
        local ok, n = pcall(UnitName, x .. "owner")      -- SuperWoW; unverified for foreign totems
        if ok and type(n) == "string" and state.byName[n] then owner = n end
        local pe = state.petByGuid[key]
        if not owner and pe then owner = pe.name end
        if not owner and C.Opt("guessTotemOwner") then
            local ok2, nm = pcall(UnitName, x)
            if ok2 and type(nm) == "string" and string.find(nm, "Totem", 1, true) then owner = onlyShaman() end
        end
    else
        local pe = state.petByName[x]
        if pe then owner = pe.name end
        if not owner and C.Opt("guessTotemOwner") and string.find(x, "Totem", 1, true) then owner = onlyShaman() end
    end
    if ownerCount >= 400 then C.ClearOwnerCache() end
    ownerCache[key] = owner or false
    ownerCount = ownerCount + 1
    return owner
end

-- Entry (the listed targetSCT) that an event's attacker belongs to, by name or by GUID.
local function sourceFromName(name)
    if not name then return nil end
    local e = state.byName[name]
    if e then return e end
    local _, _, base, owner = string.find(name, "^(.-)%((.-)%)$")   -- SuperWoW: "Petname(Owner)"
    if owner then
        e = state.byName[owner]
        if e then return e end
        name = base
    end
    if string.find(name, "Totem", 1, true) and not C.Opt("includeTotems") then return nil end
    local o = AnySCT_OwnerOf(name)
    return o and state.byName[o] or nil
end

local function sourceFromGuid(g)
    if g == nil then return nil end
    local n = C.NormGuid(g)
    local e = state.byGuid[n] or state.petByGuid[n]
    if e then return e end
    local o = AnySCT_OwnerOf(g)
    return o and state.byName[o] or nil
end

-- ---- dispatch --------------------------------------------------------------------------------

function C.IsSelf(e)
    if e.unit == "player" then return true end
    local pn = UnitName("player")
    return pn ~= nil and e.name == pn
end

-- Combat state of a unit token or GUID: true / false, or nil when the unit cannot be looked up.
local function unitCombat(u)
    local ok, ex = pcall(UnitExists, u)
    if not (ok and ex) then return nil end
    local ok2, r = pcall(UnitAffectingCombat, u)
    if not ok2 then return nil end
    return r and true or false
end

-- Is the listed source (or its pet) in combat? Unknown (no token, GUID not resolvable) counts as
-- yes: the option may only hide text it can prove the source is idle for.
function C.SourceFights(e)
    local u = e.unit or e.guid
    if not u then return true end
    local r = unitCombat(u)
    if r == nil then return true end
    if r then return true end
    if e.petUnit and unitCombat(e.petUnit) then return true end
    return false
end

-- Show one result for a listed source e, over the VICTIM of the event (never over the targetSCT's
-- target as such: AoE and untargeted damage hits other mobs). vGuid: victim GUID when known.
function C.Emit(res, e, vGuid)
    if not res or not e or not C.Opt("enabled") then return end
    if C.IsSelf(e) then
        if C.debug then C.Dbg("drop: " .. e.name .. " is the player (own events are never shown)") end
        C.Ledger(res, "dropped:self")
        return
    end
    C.UpdateSourceTargets()
    local vName = res.victim
    if vName == "you" then
        vName = UnitName("player")
        res.mobUnit = "player"
        res.mobGuid = C.ResolveGuid("player")
    elseif vGuid then
        res.mobGuid = vGuid
        if not vName then
            local ok, n = pcall(UnitName, vGuid)
            if ok then vName = n end
        end
        if e.targetGuid and C.NormGuid(e.targetGuid) == C.NormGuid(vGuid) then res.mobUnit = e.targetUnit end
    elseif vName and vName == e.targetName then
        -- chat rows carry only a name: if it is the targetSCT's target we know the GUID and the unit token
        res.mobGuid, res.mobUnit = e.targetGuid, e.targetUnit
    end
    res.mobName = vName
    res.source = e.name
    res.srcRgb = e.rgb    -- the listed source's own colour (used when colorPerTarget is on)
    res.srcMulti = table.getn(state.order) > 1
    res.class = e.class   -- owner's class for pets and totems; nil for mobs
    if C.Opt("onlyWhileSourceFights") and not C.SourceFights(e) then
        if C.debug then C.Dbg("drop: " .. e.name .. " is not in combat (option: only while the source fights)") end
        C.Ledger(res, "dropped:combat")
        return
    end
    if AnySCT_SCT and AnySCT_SCT.Show then AnySCT_SCT.Show(res) end
end

-- nampower AUTO_ATTACK_OTHER (arg order unverified in-game, see README).
function C.OnAutoAttack(attackerGuid, targetGuid, damage, hitInfo, victimState, subCount, blocked, absorbed, resisted)
    local e = sourceFromGuid(attackerGuid)
    if not e then
        if C.debug then C.Dbg("drop: AUTO_ATTACK_OTHER caster " .. tostring(attackerGuid) .. " not listed") end
        return
    end
    local res = AnySCT_DecodeAutoAttack(damage, hitInfo, victimState, blocked, absorbed, resisted)
    if res then
        res.path = "np"
        C.Emit(res, e, targetGuid)
    end
end

local function spellName(spellId)
    if not (C.Opt("showSpellName") and SpellInfo) then return nil end
    local ok, n = pcall(SpellInfo, spellId)
    if ok and type(n) == "string" then return n end
    return nil
end

-- nampower SPELL_DAMAGE_EVENT_OTHER: target, caster, spellId, amount, mitigation, hitInfo, school, aura.
function C.OnSpellDamage(targetGuid, casterGuid, spellId, amount, mitigation, hitInfo)
    local e = sourceFromGuid(casterGuid)
    if not e then
        if C.debug then C.Dbg("drop: SPELL_DAMAGE_EVENT_OTHER caster " .. tostring(casterGuid) .. " not listed") end
        return
    end
    local res = AnySCT_DecodeSpellDamage(amount, mitigation, hitInfo)
    res.spell = spellName(spellId)
    res.spellId = spellId
    res.path = "npspell"
    C.Emit(res, e, targetGuid)
end

-- nampower SPELL_MISS_OTHER: caster, target, spellId, missType.
function C.OnSpellMiss(casterGuid, targetGuid, spellId, missType)
    local e = sourceFromGuid(casterGuid)
    if not e then
        if C.debug then C.Dbg("drop: SPELL_MISS_OTHER caster " .. tostring(casterGuid) .. " not listed") end
        return
    end
    local res = AnySCT_DecodeSpellMiss(missType)
    if not res then return end
    res.spell = spellName(spellId)
    res.spellId = spellId
    res.path = "npspell"
    C.Emit(res, e, targetGuid)
end

local MELEE_EVENTS = {
    CHAT_MSG_COMBAT_FRIENDLYPLAYER_HITS = true,
    CHAT_MSG_COMBAT_FRIENDLYPLAYER_MISSES = true,
    CHAT_MSG_COMBAT_PARTY_HITS = true,
    CHAT_MSG_COMBAT_PARTY_MISSES = true,
}
local SPELL_EVENTS = {
    CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE = true,
    CHAT_MSG_SPELL_PARTY_DAMAGE = true,
}
-- foreign pets and totems; registered only while a listed targetSCT has a pet or is a shaman
local CREATURE_MELEE = {
    CHAT_MSG_COMBAT_CREATURE_VS_CREATURE_HITS = true,
    CHAT_MSG_COMBAT_CREATURE_VS_CREATURE_MISSES = true,
}
local CREATURE_SPELL = { CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE = true }
-- sources outside the group (hostile players, mobs): registered only while such a source is listed
local HOSTILE_MELEE = {
    CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS = true,
    CHAT_MSG_COMBAT_HOSTILEPLAYER_MISSES = true,
    CHAT_MSG_COMBAT_CREATURE_VS_PARTY_HITS = true,
    CHAT_MSG_COMBAT_CREATURE_VS_PARTY_MISSES = true,
    CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS = true,
    CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES = true,
}
local HOSTILE_SPELL = {
    CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE = true,
    CHAT_MSG_SPELL_CREATURE_VS_PARTY_DAMAGE = true,
    CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE = true,
}
C.HOSTILE_MELEE, C.HOSTILE_SPELL = HOSTILE_MELEE, HOSTILE_SPELL
C.MELEE_EVENTS, C.SPELL_EVENTS = MELEE_EVENTS, SPELL_EVENTS
C.CREATURE_MELEE, C.CREATURE_SPELL = CREATURE_MELEE, CREATURE_SPELL

-- heal rows: direct heals (own heals come on SELF_BUFF) and heal-over-time ticks
local HEAL_EVENTS = {
    CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF = true,
    CHAT_MSG_SPELL_PARTY_BUFF = true,
    CHAT_MSG_SPELL_SELF_BUFF = true,
}
local HOT_EVENTS = {
    CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_BUFFS = true,
    CHAT_MSG_SPELL_PERIODIC_PARTY_BUFFS = true,
    CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS = true,
}
C.HEAL_EVENTS, C.HOT_EVENTS = HEAL_EVENTS, HOT_EVENTS

-- Show a heal over the listed targetSCT e (the VICTIM of the heal). healer: name or nil.
function C.EmitHeal(res, e, healer)
    if not res or not e or not C.Opt("enabled") or not C.Opt("showHeals") then return end
    if C.IsSelf(e) then
        if C.debug then C.Dbg("drop: heal on the player") end
        return
    end
    if res.periodic and not C.Opt("showHots") then
        if C.debug then C.Dbg("drop: HoT tick (option off)") end
        return
    end
    local pn = UnitName("player")
    if (healer == "you" or (healer ~= nil and healer == pn)) and not C.Opt("showOwnHeals") then
        if C.debug then C.Dbg("drop: own heal (option off)") end
        return
    end
    if healer == "you" then healer = pn end
    if C.Opt("onlyWhileSourceFights") and not C.SourceFights(e) then
        if C.debug then C.Dbg("drop: " .. e.name .. " is not in combat (option: only while the source fights)") end
        return
    end
    res.healer = healer
    res.mobGuid, res.mobUnit, res.mobName = e.guid, e.unit, e.name
    res.source = e.name
    res.class = e.class
    if AnySCT_SCT and AnySCT_SCT.Show then AnySCT_SCT.Show(res) end
end

-- nampower SPELL_HEAL_BY_OTHER: target, caster, spellId, amount (a crit flag is not known).
function C.OnHealEvent(targetGuid, casterGuid, spellId, amount, crit)
    local e = state.byGuid[C.NormGuid(targetGuid)]
    if not e then
        local ok, n = pcall(UnitName, targetGuid)
        if ok and type(n) == "string" then e = state.byName[n] end
    end
    if not e then
        if C.debug then C.Dbg("drop: heal target " .. tostring(targetGuid) .. " not listed") end
        return
    end
    local healer
    if casterGuid then
        local ok, n = pcall(UnitName, casterGuid)
        if ok and type(n) == "string" then healer = n end
    end
    local res = AnySCT_DecodeHeal(amount, crit)
    res.spell = spellName(spellId)
    C.EmitHeal(res, e, healer)
end

-- Chat rows of the heal channels: the VICTIM must be a listed source.
function C.OnHealChat(ev, msg)
    if type(msg) ~= "string" or table.getn(state.order) == 0 then return end
    local named = false
    for i = 1, table.getn(state.order) do
        if string.find(msg, state.order[i], 1, true) then named = true break end
    end
    if not named then return end
    local res = AnySCT_ParseHeal(msg)
    if not res then
        if C.debug then C.Dbg("drop: heal row not parsed: " .. string.sub(msg, 1, 60)) end
        return
    end
    local e = state.byName[res.victim]
    if not e then
        if C.debug then C.Dbg("drop: heal victim '" .. tostring(res.victim) .. "' not listed") end
        return
    end
    if not e.guidNorm then C.RetryGuids() end
    local healer = res.attacker
    local own = (healer == "you") or healer == UnitName("player")
    if e.guidNorm and state.npHeals and not res.periodic and not own then
        if C.debug then C.Dbg("drop: " .. e.name .. " has a GUID, the nampower heal event handles it") end
        return
    end
    C.EmitHeal(res, e, healer)
end

-- Cheap prefilter before any pattern work: the row must START with a targetSCT or pet name (attackers
-- come first in every row shape we parse), or mention a totem when totems are on.
local function mentionsSource(msg)
    for i = 1, table.getn(state.order) do
        local nm = state.order[i]
        if string.find(msg, nm, 1, true) == 1 then return true end
        if string.find(msg, state.byName[nm].paren, 1, true) then return true end   -- "Petname(Owner)"
    end
    for name in pairs(state.petByName) do
        if string.find(msg, name, 1, true) == 1 then return true end
    end
    if C.Opt("includeTotems") and string.find(msg, "Totem", 1, true) then return true end
    return false
end

function C.OnChat(ev, msg)
    if type(msg) ~= "string" or table.getn(state.order) == 0 then return end
    if not mentionsSource(msg) then
        if C.debug then C.Dbg("drop: no listed source at the start of: " .. string.sub(msg, 1, 60)) end
        return
    end
    local res, spell
    if MELEE_EVENTS[ev] or CREATURE_MELEE[ev] or HOSTILE_MELEE[ev] then
        res = AnySCT_ParseMelee(msg)
        -- a "Name's Spell hits ..." row that arrived on a melee channel is a spell row
        if not res and C.Opt("showSpells") and string.find(msg, "'s ", 1, true) then
            res = AnySCT_ParseSpell(msg)
            spell = res and true or nil
        end
    elseif SPELL_EVENTS[ev] or CREATURE_SPELL[ev] or HOSTILE_SPELL[ev] then
        spell = true
        res = AnySCT_ParseSpell(msg)
    end
    if not res then
        if C.debug then C.Dbg("drop: row not parsed: " .. string.sub(msg, 1, 60)) end
        return
    end
    local e = sourceFromName(res.attacker)
    if not e then
        if C.debug then C.Dbg("drop: attacker '" .. tostring(res.attacker) .. "' not listed") end
        return
    end
    -- a source without a GUID: try to learn it now (rate limited), outside the combat tick
    if not e.guidNorm then C.RetryGuids() end
    -- a nampower source with a known GUID already arrives through its own event; a source without
    -- a GUID can never match those events, so its rows always come from chat
    if e.guidNorm and ((spell and state.npSpells) or (not spell and state.nampower)) then
        if C.debug then C.Dbg("drop: " .. e.name .. " has a GUID, the nampower event path handles it") end
        return
    end
    -- a pet (or totem) of a listed source: remember its name for the optional "Owner (Pet)" suffix
    if res.attacker and res.attacker ~= e.name then
        local _, _, base = string.find(res.attacker, "^(.-)%(.-%)$")
        res.srcPet = base or res.attacker
    end
    res.path = "chat"
    C.Emit(res, e)
end

-- ---- tick ------------------------------------------------------------------------------------

-- Runs every 0.25 s, and only while the player is in combat (see the REGEN events below): idle cost
-- is zero.
-- Group sources whose GUID could not be read yet (range, nampower without SuperWoW): retry.
function C.FillGuids()
    local changed = false
    for i = 1, table.getn(state.order) do
        local e = state.byName[state.order[i]]
        if e.unit and not e.guidNorm then
            local g = C.ResolveGuid(e.unit)
            if g then
                e.guid = g
                e.guidNorm = C.NormGuid(g)
                state.byGuid[e.guidNorm] = e
                changed = true
            end
        end
    end
    return changed
end

function C.Tick()
    if C.FillGuids() then C.CheckCreature() end
    C.UpdateSourceTargets()
end

-- ---- sources & cvars -------------------------------------------------------------------------

function C.ExtendRange()
    pcall(SetCVar, "CombatLogRangeFriendlyPlayers", "200")
    pcall(SetCVar, "CombatLogRangeParty", "200")
end

function C.ApplyPlateRange()
    local r = C.Opt("plateRange") or 0
    if r > 0 then
        pcall(SetCVar, "NameplateRange", tostring(r))
        pcall(SetCVar, "NP_NameplateDistance", tostring(r))
    end
end

local hinted = false
function C.PlateHint()
    if hinted then return end
    hinted = true
    local ok, v = pcall(GetCVar, "nameplateShowEnemies")
    if ok and v == "0" then
        C.Print("enemy nameplates are off; turn them on (V key) to see the text float over the mob.")
    end
end

local function setEv(f, ev, on)
    if on then f:RegisterEvent(ev) else f:UnregisterEvent(ev) end
end

-- What the list needs: creature channels (a listed targetSCT, not the player, has a pet or is a
-- shaman / hunter / warlock), hostile channels (a listed source outside the group), and whether
-- any such source lacks a GUID (then its melee / spells must come from chat even with nampower).
function C.Needs()
    local creature, loose, noGuid, friendly = false, false, false, false
    for i = 1, table.getn(state.order) do
        local e = state.byName[state.order[i]]
        if not C.IsSelf(e) then
            if not e.unit then loose = true end
            if not e.guidNorm then noGuid = true end
            -- a heal target: a group member, or an outside unit not known to be hostile
            if e.unit or not (e.guid and UnitCanAttack("player", e.guid)) then friendly = true end
            if e.petName or e.class == "HUNTER" or e.class == "WARLOCK" then creature = true end
            if e.class == "SHAMAN" and C.Opt("includeTotems") then creature = true end
        end
    end
    return creature, loose, noGuid, friendly
end

-- Register exactly the events the active sources need and unregister the rest.
function C.UpdateEvents()
    local f = C.frame
    if not f then return end
    local on = C.Opt("enabled") and true or false
    local np, nps, spells = state.nampower, state.npSpells, C.Opt("showSpells")
    local creature, loose, noGuid, friendly = C.Needs()
    state.needCode = (creature and 1 or 0) + (loose and 2 or 0) + (noGuid and 4 or 0) + (friendly and 8 or 0)
    local heals = on and C.Opt("showHeals") and friendly
    local viaChat = heals and ((not state.npHeals) or noGuid)
    local chatMelee = on and ((not np) or noGuid)
    local chatSpell = on and spells and ((not nps) or noGuid)
    setEv(f, "SPELL_HEAL_BY_OTHER", heals and state.npHeals)
    for ev in pairs(HEAL_EVENTS) do
        -- the player's own heals are not nampower "other" events: SELF_BUFF always comes from chat
        if ev == "CHAT_MSG_SPELL_SELF_BUFF" then
            setEv(f, ev, heals and C.Opt("showOwnHeals"))
        else
            setEv(f, ev, viaChat)
        end
    end
    for ev in pairs(HOT_EVENTS) do setEv(f, ev, heals and C.Opt("showHots")) end
    setEv(f, "AUTO_ATTACK_OTHER", on and np)
    setEv(f, "SPELL_DAMAGE_EVENT_OTHER", on and spells and nps)
    setEv(f, "SPELL_MISS_OTHER", on and spells and nps)
    setEv(f, "UPDATE_MOUSEOVER_UNIT", on and loose)
    setEv(f, "CHAT_MSG_ADDON", on and C.Opt("threatGo"))
    setEv(f, "UNIT_TARGET", on and loose and noGuid)   -- target-of-target changes carry no PLAYER_TARGET_CHANGED
    for ev in pairs(MELEE_EVENTS) do setEv(f, ev, chatMelee) end
    for ev in pairs(CREATURE_MELEE) do setEv(f, ev, chatMelee and (creature or loose)) end
    for ev in pairs(HOSTILE_MELEE) do setEv(f, ev, chatMelee and loose) end
    for ev in pairs(SPELL_EVENTS) do setEv(f, ev, chatSpell) end
    for ev in pairs(CREATURE_SPELL) do setEv(f, ev, chatSpell and (creature or loose)) end
    for ev in pairs(HOSTILE_SPELL) do setEv(f, ev, chatSpell and loose) end
end

function C.CheckCreature()
    if not C.frame then return end
    local creature, loose, noGuid, friendly = C.Needs()
    local code = (creature and 1 or 0) + (loose and 2 or 0) + (noGuid and 4 or 0) + (friendly and 8 or 0)
    if code ~= state.needCode then C.UpdateEvents() end
end

-- Detect nampower (CVars present). Auto attacks and spells each fall back to chat on their own.
function C.SetupSources()
    local ok, v = pcall(GetCVar, "NP_EnableAutoAttackEvents")
    state.nampower = (ok and v ~= nil) and true or false
    if state.nampower then pcall(SetCVar, "NP_EnableAutoAttackEvents", "1") end
    local ok2, v2 = pcall(GetCVar, "NP_EnableSpellDamageEvents")
    state.npSpells = (ok2 and v2 ~= nil) and true or false
    -- newer nampower builds (4.x) deliver SPELL_DAMAGE_EVENT_OTHER / SPELL_MISS_OTHER ungated: no CVar
    -- exists to find, but the version call proves the events do
    local hasVer = type(GetNampowerVersion) == "function"
    if not state.npSpells and state.nampower and hasVer then state.npSpells = true end
    if ok2 and v2 ~= nil then
        pcall(SetCVar, "NP_EnableSpellDamageEvents", "1")
        pcall(SetCVar, "NP_EnableSpellMissEvents", "1")
    end
    local ok3, v3 = pcall(GetCVar, "NP_EnableSpellHealEvents")
    state.npHeals = (ok3 and v3 ~= nil) and true or false
    if state.npHeals then pcall(SetCVar, "NP_EnableSpellHealEvents", "1") end
    C.UpdateEvents()
    return state.nampower
end

-- ---- threat based GO / WAIT (experimental) -------------------------------------------------------
-- Protocol of the server's threat answers (as used by TWThreat v1.2.3, unverified in this addon):
--   request  SendAddonMessage("TWT_UDTSv4", "limit=10", "RAID" | "PARTY")
--   answer   CHAT_MSG_ADDON arg1 "TWT" (maybe with a trailing space), arg2
--            "TWTv4=Name:tank:threat:pct:melee;Name:...[hash-separated TMTv1 tail]"
-- The server pulls aggro at > 110 % (melee) / > 130 % (ranged) of the tank's threat, so the buffer
-- before the player takes the mob is  threat(targetSCT) * f - threat(player).

local TH = { lastPkt = -100, lastReq = -100, shown = false, status = nil, buffer = 0, name = nil, packets = 0, requests = 0 }
C.threat = TH
local pk = { n = 0, name = {}, tank = {}, threat = {}, melee = {} }
C.threatPk = pk

-- Parse one answer into pk (arrays are reused). True when it is a TWT v4 answer, even an empty one.
function C.ParseThreat(prefix, msg, out)
    out = out or pk
    out.n = 0
    if type(prefix) ~= "string" or string.sub(prefix, 1, 3) ~= "TWT" then return false end
    if type(msg) ~= "string" then return false end
    local _, e = string.find(msg, "^TWTv4=")
    if not e then return false end
    local hash = string.find(msg, "#", 1, true)
    local body
    if hash then body = string.sub(msg, e + 1, hash - 1) else body = string.sub(msg, e + 1) end
    local pos = 1
    while true do
        local _, f, name, tank, threat, _, melee = string.find(body, "^([^:;]+):(%d+):(%-?%d+):([%-%d%.]+):(%d+)", pos)
        if not f then break end
        local n = out.n + 1
        out.n = n
        out.name[n], out.tank[n] = name, (tank == "1")
        out.threat[n], out.melee[n] = tonumber(threat), (melee == "1")
        pos = f + 1
        if string.sub(body, pos, pos) == ";" then pos = pos + 1 else break end
    end
    return true
end

-- status ("GO" | "WAIT"), buffer, targetSCT name for a parsed packet; nil when no enabled targetSCT
-- is in it. need = required buffer. Several enabled targetSCTs: the one holding aggro; if none does,
-- WAIT for the first one. A player missing from the packet has threat 0 and counts as melee (f 1.1).
function C.ThreatDecide(out, myName, need)
    out = out or pk
    local myT, myMelee = 0, nil
    for i = 1, out.n do
        if out.name[i] == myName then myT, myMelee = out.threat[i], out.melee[i] end
    end
    local f = 1.1
    if myMelee == false then f = 1.3 end
    local first, best
    for i = 1, out.n do
        local nm = out.name[i]
        local e = state.byName[nm]
        if e and e.threatOn and nm ~= myName then
            if not first then first = i end
            if out.tank[i] and not best then best = i end
        end
    end
    if not first then return nil end
    local i = best or first
    local buffer = out.threat[i] * f - myT
    if best and buffer >= (need or 0) then return "GO", buffer, out.name[i] end
    return "WAIT", buffer, out.name[i]
end

-- Slider positions 0..75 <-> required buffer 0..7500 in steps of 100.
local LEAD_MAXPOS = 75
function C.LeadFromPos(p)
    p = math.floor((p or 0) + 0.5)
    if p < 0 then p = 0 elseif p > LEAD_MAXPOS then p = LEAD_MAXPOS end
    return p * 100
end

-- Fixed-anchor geometry. Frame rects (GetCenter/GetLeft/...) and SetPoint offsets live in one
-- coordinate system; UIParent:GetWidth()/GetHeight() do NOT (1834x768 against a 2580x1080 rect on a
-- UI scale of 0.711), so the screen centre must come from UIParent's own rect, never from its size.
function C.AnchorPosFromCenter(cx, cy, ux, uy)
    return { point = "CENTER", x = math.floor(cx - ux + 0.5), y = math.floor(cy - uy + 0.5) }
end

-- Half extents of the screen as slider limits: rounded up to a multiple of 5, at least 100.
function C.ScreenHalfRange(left, right, bottom, top)
    local function half(a, b)
        local h = math.ceil(((b or 0) - (a or 0)) / 2 / 5) * 5
        if h < 100 then h = 100 end
        return h
    end
    return half(left, right), half(bottom, top)
end

function C.PosFromLead(v)
    v = v or 0
    if v < 0 then v = 0 end
    local p = math.floor(v / 100 + 0.5)
    if p > LEAD_MAXPOS then p = LEAD_MAXPOS end
    return p
end

-- Does the situation call for threat data at all?
function C.ThreatWanted()
    if not (C.Opt("enabled") and C.Opt("threatGo")) then return false end
    if GetNumRaidMembers() == 0 and GetNumPartyMembers() == 0 then return false end
    local any = false
    for i = 1, table.getn(state.order) do
        local e = state.byName[state.order[i]]
        if e.threatOn and e.unit and not C.IsSelf(e) then any = true break end
    end
    if not any then return false end
    if not UnitExists("target") or not UnitCanAttack("player", "target") or UnitIsDead("target") then return false end
    local cl = UnitClassification and UnitClassification("target")
    if cl ~= "elite" and cl ~= "worldboss" and cl ~= "rareelite" then return false end
    return UnitAffectingCombat("target") and true or false
end

-- Send our own request only when TWThreat (or an earlier request of ours) has not fed us lately.
function C.ThreatShouldRequest(now)
    if now - TH.lastPkt < 0.9 then return false end
    if now - TH.lastReq < 1.0 then return false end
    return true
end

-- Ring buffer of trace lines, flushed to <WoW>\imports\anysct_threat.txt (SuperWoW's ExportFile appends
-- .txt) at most every 2 s. Recorded only while /asct debug is on or the option "Record threat trace"
-- (threatTrace, default off) is set; callers test C.ThreatTracing() first. Nothing goes to chat, and
-- without ExportFile nothing is written.
function C.ThreatTracing() return C.debug or C.Opt("threatTrace") end
local RING = 200
local ring, ringN, ringHead, ringDirty, lastFlush = {}, 0, 0, false, -10
function C.ThreatFlush(force)
    if not ringDirty or not ExportFile then return end
    local now = C.Now()
    if not force and now - lastFlush < 2 then return end
    lastFlush, ringDirty = now, false
    local parts, k = {}, 0
    local start = (ringN < RING) and 1 or (math.mod(ringHead, RING) + 1)
    for i = 0, ringN - 1 do
        k = k + 1
        parts[k] = ring[math.mod(start - 1 + i, RING) + 1]
    end
    pcall(ExportFile, "anysct_threat", table.concat(parts, "\n") .. "\n")
end

function C.ThreatLog(line)
    ringHead = math.mod(ringHead, RING) + 1
    ring[ringHead] = string.format("%.2f", C.Now()) .. " " .. line
    if ringN < RING then ringN = ringN + 1 end
    ringDirty = true
    C.ThreatFlush(false)
end

-- Event ledger (same switch as the trace): one line per event of a listed source with the path it came
-- through (np / npspell / chat), what it was and what became of it (shown / shown+recycled /
-- dropped:<reason>), flushed to the WoW imports folder as anysct_events.txt. First line = outcome counters.
local LRING = 600
local lring, lN, lHead, lDirty, lLast = {}, 0, 0, false, -10
C.led = {}
function C.LedgerFlush(force)
    if not lDirty or not ExportFile then return end
    local now = C.Now()
    if not force and now - lLast < 2 then return end
    lLast, lDirty = now, false
    local parts, k = {}, 1
    local head = {}
    for key, n in pairs(C.led) do head[table.getn(head) + 1] = key .. "=" .. n end
    table.sort(head)
    parts[1] = "# " .. table.concat(head, " ")
    local start = (lN < LRING) and 1 or (math.mod(lHead, LRING) + 1)
    for i = 0, lN - 1 do
        k = k + 1
        parts[k] = lring[math.mod(start - 1 + i, LRING) + 1]
    end
    pcall(ExportFile, "anysct_events", table.concat(parts, "\n") .. "\n")
end

function C.Ledger(res, outcome)
    if not C.ThreatTracing() then return end
    C.led[outcome] = (C.led[outcome] or 0) + 1
    lHead = math.mod(lHead, LRING) + 1
    lring[lHead] = string.format("%.2f", C.Now()) .. " " .. tostring(res.path or "?") .. " "
        .. tostring(res.kind) .. " " .. tostring(res.amount or 0) .. " "
        .. tostring(res.spell or res.spellId or "-") .. " " .. tostring(res.mobName or "?")
        .. " " .. outcome
    if lN < LRING then lN = lN + 1 end
    lDirty = true
    C.LedgerFlush(false)
end

-- Name prefix on the label: same never / multi / always rule as the number's suffix line.
local function threatSrcName(name)
    local m = C.Opt("sourceNameMode")
    if m == "always" or (m == "multi" and table.getn(state.order) > 1) then return name end
    return nil
end

C.ThreatSrcName = threatSrcName

local function threatHide()
    if TH.shown then
        TH.shown = false
        TH.status = nil
        if AnySCT_SCT and AnySCT_SCT.SetThreat then AnySCT_SCT.SetThreat(nil) end
    end
end

-- CHAT_MSG_ADDON: TWThreat's answers (and ours) arrive here.
function C.OnAddon(prefix, msg, channel, sender)
    if not C.Opt("threatGo") then return end
    local isTwt = type(prefix) == "string" and string.sub(prefix, 1, 3) == "TWT"
    if isTwt and C.ThreatTracing() then
        C.ThreatLog("pkt [" .. prefix .. "] " .. tostring(msg) .. " | " .. tostring(channel) .. " | " .. tostring(sender))
    end
    if not C.ParseThreat(prefix, msg, pk) then return end
    local need = C.Opt("threatGoLead") or 1500
    local status, buffer, name = C.ThreatDecide(pk, UnitName("player"), need)
    if C.ThreatTracing() then
        C.ThreatLog("decide " .. tostring(status) .. " buffer=" .. tostring(buffer) .. " need=" .. need
            .. " by=" .. tostring(name) .. " n=" .. pk.n)
    end
    if not status then return end          -- nobody of ours in it: not usable
    TH.packets = TH.packets + 1
    TH.lastPkt = C.Now()
    TH.status, TH.buffer, TH.name = status, buffer, name
    TH.shown = true
    if AnySCT_SCT and AnySCT_SCT.SetThreat then AnySCT_SCT.SetThreat(status, buffer, need, threatSrcName(name)) end
end

function C.ThreatSend(now)
    TH.lastReq = now
    TH.requests = TH.requests + 1
    local ch = (GetNumRaidMembers() > 0) and "RAID" or "PARTY"
    local ok = pcall(SendAddonMessage, "TWT_UDTSv4", "limit=10", ch)
    if C.ThreatTracing() then C.ThreatLog("req " .. ch .. " ok=" .. tostring(ok)) end
end

-- One step of the ticker (every ~0.2 s while threat data is wanted).
function C.ThreatTick()
    if not C.ThreatWanted() then
        threatHide()
        if C.ThreatStop then C.ThreatStop() end
        C.ThreatFlush(true)              -- last lines of the fight reach the file
        return
    end
    local now = C.Now()
    if TH.shown and now - TH.lastPkt > 3 then threatHide() end
    if C.ThreatShouldRequest(now) then C.ThreatSend(now) end
    if C.ThreatTracing() then C.ThreatFlush(false) end
end

-- Start / stop the ticker to match the situation (zero idle OnUpdate otherwise).
function C.ThreatRefresh()
    if C.ThreatWanted() then
        if C.ThreatStart then C.ThreatStart() end
    else
        threatHide()
        if C.ThreatStop then C.ThreatStop() end
    end
end

function C.ThreatStatusLine()
    local age = C.Now() - TH.lastPkt
    return "threat: " .. (C.Opt("threatGo") and "on" or "off") .. ", wanted " .. tostring(C.ThreatWanted())
        .. ", " .. TH.packets .. " usable packets, " .. TH.requests .. " requests, last "
        .. (TH.lastPkt < 0 and "never" or string.format("%.1f s ago", age))
        .. ", " .. tostring(TH.status) .. " " .. string.format("%d", TH.buffer or 0)
        .. " (" .. tostring(TH.name) .. "), need " .. tostring(C.Opt("threatGoLead"))
end

-- ---- slash commands --------------------------------------------------------------------------

local HELP = {
    "/anysct (or /asct) commands:",
    "  add <name>     add a targetSCT (no name: use your target)",
    "  remove <name>  remove a targetSCT",
    "  list           show the targetSCT list",
    "  clear          remove every targetSCT",
    "  colours        re-assign the targetSCT colours automatically",
    "  threat         state of the experimental threat GO / WAIT label",
    "  place clamp|anchoroff|anchor|both   where the text appears",
    "  unlock | lock  move the fixed anchor",
    "  demo           show sample text",
    "  mem            measure memory use (10 s idle, then a demo burst)",
    "  debug          toggle the event / drop trace in the chat frame",
    "  options        open the options window",
    "  reset          reset all options to defaults",
}

-- The spelling an existing list entry or group member has for a typed name (compared lower case
-- only), or nil. Typed case is kept for names we do not know.
function C.Canon(n)
    local ln = string.lower(n)
    for i = 1, table.getn(state.order) do
        if string.lower(state.order[i]) == ln then return state.order[i] end
    end
    for name in pairs(state.roster) do
        if string.lower(name) == ln then return name end
    end
    return nil
end

local PLACE = { clamp = "clamp", anchoroff = "anchorOff", anchor = "anchor", both = "both" }

function C.Slash(msg)
    msg = msg or ""
    local _, _, cmd, rest = string.find(msg, "^%s*(%S*)%s*(.-)%s*$")
    cmd = string.lower(cmd or "")
    rest = rest or ""
    if cmd == "add" or cmd == "tank" then   -- "tank" is the old spelling, kept as a silent alias
        local n = rest
        if n == "" and UnitExists("target") and UnitIsPlayer("target") then n = UnitName("target") or "" end
        if n == "" then C.Print("usage: /anysct add <name>") return end
        n = C.Canon(n) or n
        C.AddSource(n, "manual")
        C.Print("targetSCT added: " .. n)
    elseif cmd == "remove" or cmd == "rm" then
        local n = C.Canon(rest) or rest
        if rest ~= "" and C.RemoveSource(n) then C.Print("targetSCT removed: " .. n) else C.Print("not in the list: " .. rest) end
    elseif cmd == "list" then
        if table.getn(state.order) == 0 then C.Print("no targetSCTs") end
        for i = 1, table.getn(state.order) do
            local e = state.byName[state.order[i]]
            C.Print(e.name .. " (" .. (e.src == "main" and "import" or e.src) .. ")")
        end
    elseif cmd == "clear" then
        C.ClearSources()
        C.Print("targetSCT list cleared")
    elseif cmd == "threat" then
        C.Print(C.ThreatStatusLine())
    elseif cmd == "colours" or cmd == "colors" then
        C.AutoColours()
        C.Print("targetSCT colours re-assigned")
    elseif cmd == "place" then
        local p = PLACE[string.lower(rest)]
        if p then C.SetOpt("placement", p) C.Print("placement: " .. p) else C.Print("usage: /anysct place clamp|anchoroff|anchor|both") end
    elseif cmd == "unlock" or cmd == "lock" then
        if AnySCT_SCT and AnySCT_SCT.SetMoveMode then AnySCT_SCT.SetMoveMode(cmd == "unlock") end
    elseif cmd == "demo" then
        if AnySCT_SCT and AnySCT_SCT.Demo then AnySCT_SCT.Demo() end
    elseif cmd == "debug" then
        C.debug = not C.debug
        if not C.debug then C.ThreatFlush(true) end
        C.Print("debug trace " .. (C.debug and "on" or "off"))
    elseif cmd == "mem" then
        if AnySCT_SCT and AnySCT_SCT.Mem then AnySCT_SCT.Mem() end
    elseif cmd == "options" or cmd == "config" then
        if AnySCT_Options and AnySCT_Options.toggle then AnySCT_Options.toggle() end
    elseif cmd == "reset" then
        AnySCTDB.opt = nil
        C.InitDB()
        if AnySCT_SCT and AnySCT_SCT.OptionChanged then AnySCT_SCT.OptionChanged("all") end
        if AnySCT_Minimap and AnySCT_Minimap.Update then AnySCT_Minimap.Update() end
        C.NotifyChanged()
        C.Print("options reset")
    else
        for i = 1, table.getn(HELP) do C.Print(HELP[i]) end
    end
end

-- ---- WoW wiring --------------------------------------------------------------------------------

if CreateFrame then
    local f = CreateFrame("Frame", "AnySCTCoreFrame", UIParent)
    C.frame = f
    f:RegisterEvent("ADDON_LOADED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("PLAYER_TARGET_CHANGED")
    f:RegisterEvent("RAID_ROSTER_UPDATE")
    f:RegisterEvent("PARTY_MEMBERS_CHANGED")
    f:RegisterEvent("PLAYER_REGEN_DISABLED")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:RegisterEvent("UNIT_PET")
    f:RegisterEvent("UNIT_FLAGS")

    -- combat tick: attached on entering combat, detached on leaving it
    local acc, tickOn = 0, false
    local function tickFn()
        acc = acc + arg1
        if acc < 0.25 then return end
        acc = 0
        C.Tick()
    end
    function C.StartTick()
        if tickOn then return end
        tickOn = true
        acc = 0
        f:SetScript("OnUpdate", tickFn)
    end
    function C.StopTick()
        tickOn = false
        f:SetScript("OnUpdate", nil)
        C.LedgerFlush(true)
    end

    -- threat ticker: attached only while threat data is wanted (see C.ThreatRefresh)
    local tf = CreateFrame("Frame", "AnySCTThreatFrame", UIParent)
    local tacc, tOn = 0, false
    local function threatFn()
        tacc = tacc + arg1
        if tacc < 0.2 then return end
        tacc = 0
        C.ThreatTick()
    end
    function C.ThreatStart()
        if tOn then return end
        tOn, tacc = true, 0
        tf:SetScript("OnUpdate", threatFn)
    end
    function C.ThreatStop()
        if not tOn then return end
        tOn = false
        tf:SetScript("OnUpdate", nil)
    end

    local function enterWorld()
        C.RebuildRoster()
        if not state.loaded then
            state.loaded = true
            local list = C.Char().list
            for i = 1, table.getn(list) do C.AddSource(list[i], "manual", true) end
            C.PlateHint()
            if AnySCT_Menu then AnySCT_Menu.Install() end
        end
        C.SetupSources()
        if C.Opt("extendRange") then C.ExtendRange() end
        C.ApplyPlateRange()
        if AnySCT_SCT and AnySCT_SCT.Build then AnySCT_SCT.Build() end
        if AnySCT_Minimap and AnySCT_Minimap.Update then AnySCT_Minimap.Update() end
        if UnitAffectingCombat("player") then C.StartTick() end
        C.NotifyChanged()
    end

    f:SetScript("OnEvent", function()
        local ev = event
        if C.debug and ev ~= "UNIT_TARGET" and ev ~= "ADDON_LOADED" then
            local a = arg1
            if type(a) == "string" then a = string.sub(a, 1, 80) end
            if arg2 ~= nil and (ev == "AUTO_ATTACK_OTHER" or ev == "SPELL_DAMAGE_EVENT_OTHER" or ev == "SPELL_MISS_OTHER") then
                a = tostring(a) .. " / " .. tostring(arg2)
            end
            C.Dbg("event " .. tostring(ev) .. " " .. tostring(a))
        end
        if ev == "AUTO_ATTACK_OTHER" then
            C.OnAutoAttack(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
        elseif ev == "SPELL_DAMAGE_EVENT_OTHER" then
            C.OnSpellDamage(arg1, arg2, arg3, arg4, arg5, arg6)
        elseif ev == "SPELL_MISS_OTHER" then
            C.OnSpellMiss(arg1, arg2, arg3, arg4)
        elseif ev == "SPELL_HEAL_BY_OTHER" then
            C.OnHealEvent(arg1, arg2, arg3, arg4, arg5)
        elseif HEAL_EVENTS[ev] or HOT_EVENTS[ev] then
            C.OnHealChat(ev, arg1)
        elseif MELEE_EVENTS[ev] or SPELL_EVENTS[ev] or CREATURE_MELEE[ev] or CREATURE_SPELL[ev]
            or HOSTILE_MELEE[ev] or HOSTILE_SPELL[ev] then
            C.OnChat(ev, arg1)
        elseif ev == "CHAT_MSG_ADDON" then
            C.OnAddon(arg1, arg2, arg3, arg4)
        elseif ev == "UNIT_FLAGS" then
            if arg1 == "target" and state.loaded then C.ThreatRefresh() end
        elseif ev == "PLAYER_TARGET_CHANGED" then
            if state.loaded then
                C.ProbeLoose()
                C.ThreatRefresh()
            end
        elseif ev == "UPDATE_MOUSEOVER_UNIT" then
            C.SeeLoose("mouseover")
        elseif ev == "UNIT_TARGET" then
            -- only our own target's target matters, and only while a source still lacks a GUID
            if arg1 == "target" and state.loaded then C.ProbeLoose() end
        elseif ev == "PLAYER_REGEN_DISABLED" then
            if state.loaded and C.Opt("enabled") then C.StartTick() end
            if state.loaded then C.ThreatRefresh() end
        elseif ev == "PLAYER_REGEN_ENABLED" then
            C.StopTick()
            if state.loaded then C.ThreatRefresh() end
            C.ScheduleCacheClear()
        elseif ev == "UNIT_PET" then
            for i = 1, table.getn(state.order) do C.RefreshPet(state.byName[state.order[i]]) end
            C.CheckCreature()
        elseif ev == "RAID_ROSTER_UPDATE" or ev == "PARTY_MEMBERS_CHANGED" then
            if state.loaded then C.RebuildRoster() end
        elseif ev == "PLAYER_ENTERING_WORLD" then
            enterWorld()
        elseif ev == "ADDON_LOADED" and arg1 == "AnySCT" then
            C.InitDB()
            SLASH_ANYSCT1 = "/anysct"
            SLASH_ANYSCT2 = "/asct"
            SlashCmdList["ANYSCT"] = function(m) C.Slash(m) end
        end
    end)
end
