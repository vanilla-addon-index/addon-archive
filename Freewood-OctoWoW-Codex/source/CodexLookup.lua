-- Freewood-OctoWoW-Codex: Kreaturen ueber ihre ID nachschlagen (OctoWoW)
--
-- C_CreatureInfo.GetCreatureInfoByID liefert zu einer Kreatur-ID: creatureID, displayID, name (englisch), type (Nummer),
-- family, rank, subName. Ist die Kreatur dem Client noch unbekannt, laedt RequestLoadCreatureByID sie nach
-- (Antwort: Ereignis CREATURE_DATA_LOAD_RESULT).
-- Im Hintergrund werden bei allen Kreaturen, die wir schon kennen, fehlende Angaben ergaenzt:
--   ct  Typ (sprachunabhaengig, aus der Typ-Nummer)
--   c   Klasse (elite, selten, Boss ...) falls noch keine bekannt
--   ne  englischer Name (Ersatz, wenn kein gesehener Name da ist)
-- Es werden nur bestehende Datensaetze ergaenzt, keine neuen angelegt.

local ADDON, NS = ...

local FW = _G.Freewood
local Codex = NS and NS.Codex
if not FW or not Codex then
    return
end

local Lookup = { started = false }
NS.Lookup = Lookup
Codex.Lookup = Lookup

local TYPE_CODE = {
    [1] = "beast", [2] = "dragonkin", [3] = "demon", [4] = "elemental", [5] = "giant", [6] = "undead",
    [7] = "humanoid", [8] = "critter", [9] = "mechanical", [10] = "other", [11] = "totem", [12] = "pet", [13] = "gascloud",
}
local RANK_CODE = { [1] = "elite", [2] = "rareelite", [3] = "worldboss", [4] = "rare" }

local TICK = 0.4              -- Abstand zwischen zwei Schritten (Sekunden)
local WAIT = 1.6              -- so lange auf die Antwort einer Anfrage warten
local PER_TICK = 25           -- bereits bekannte Kreaturen je Schritt (nur lesen, kostet fast nichts)
local RETRY_AFTER = 7 * 86400 -- erfolglose IDs nach einer Woche wieder versuchen
local FIRE_EVERY = 40         -- Oberflaeche hoechstens alle so viele Aenderungen auffrischen

local state = {
    queue = {}, first = 1, last = 0,
    pending = nil, pendingAt = 0,
    changed = 0, lastFire = 0, generation = 0,
    stats = { read = 0, requested = 0, filled = 0, failed = 0 },
}
Lookup.state = state

local function Now()
    return GetTime and GetTime() or 0
end

local function Store()
    local db = Codex.db
    db.lookup = db.lookup or {}
    db.lookup.fail = db.lookup.fail or {}
    return db.lookup
end

local function Enabled()
    return Codex.db ~= nil and Codex.db.settings ~= nil and Codex.db.settings.lookup ~= false
        and _G.C_CreatureInfo ~= nil and _G.C_CreatureInfo.GetCreatureInfoByID ~= nil
end

local function ReadInfo(id)
    local ok, info = pcall(_G.C_CreatureInfo.GetCreatureInfoByID, id)
    if ok and type(info) == "table" and info.creatureID == id then
        return info
    end
    return nil
end

local function NeedsInfo(u)
    return type(u) == "table" and (not u.ct or not u.ne)
end

-- Schreibt die Antwort in den bestehenden Datensatz. Rueckgabe: true, wenn sich etwas geaendert hat
function Lookup.Apply(id, info)
    local u = Codex.db.units[id]
    if type(u) ~= "table" or type(info) ~= "table" then
        return false
    end
    local changed = false
    local code = TYPE_CODE[info.type]
    if code and u.ct ~= code then
        u.ct = code
        changed = true
    end
    local rc = RANK_CODE[info.rank]
    if rc and not u.c then
        u.c = rc
        changed = true
    end
    local name = info.name
    if type(name) == "string" and name ~= "" and not u.ne then
        u.ne = name:sub(1, 60)
        changed = true
    end
    return changed
end

local function Changed(id)
    state.changed = state.changed + 1
    state.stats.filled = state.stats.filled + 1
    if state.changed - state.lastFire >= FIRE_EVERY then
        state.lastFire = state.changed
        FW:Fire("CODEX_CHANGED", "unit", id)
    end
end

-- Warteschlange (mit Zaehlern, nicht table.remove)
local function Push(id)
    state.last = state.last + 1
    state.queue[state.last] = id
end

local function Pop()
    if state.first > state.last then
        return nil
    end
    local id = state.queue[state.first]
    state.queue[state.first] = nil
    state.first = state.first + 1
    if state.first > state.last then
        state.first, state.last = 1, 0
    end
    return id
end

function Lookup.QueueSize()
    return state.last - state.first + 1
end

-- Alle bekannten Kreaturen, denen etwas fehlt, in die Schlange stellen
function Lookup.Scan()
    if not Enabled() then
        return 0
    end
    local fail = Store().fail
    local now = time and time() or 0
    local queued = {}
    for i = state.first, state.last do
        queued[state.queue[i]] = true
    end
    local ids = {}
    for id, u in pairs(Codex.db.units) do
        if type(id) == "number" and NeedsInfo(u) and not queued[id] then
            local f = fail[id]
            if not f or now - f > RETRY_AFTER then
                ids[#ids + 1] = id
            end
        end
    end
    table.sort(ids)
    for i = 1, #ids do
        Push(ids[i])
    end
    return #ids
end

local function Finish(id, info)
    state.pending = nil
    if info then
        if Lookup.Apply(id, info) then
            Changed(id)
        end
    else
        state.stats.failed = state.stats.failed + 1
        Store().fail[id] = time and time() or 1
    end
end

function Lookup.OnLoadResult(_, id, ok)
    id = tonumber(id)
    if state.pending and id == state.pending then
        Finish(id, ReadInfo(id))
    end
end

function Lookup.Step()
    if not Enabled() then
        return
    end
    local now = Now()
    if state.pending then
        if now - state.pendingAt < WAIT then
            return
        end
        -- keine Antwort: noch einmal lesen, sonst als erfolglos merken
        Finish(state.pending, ReadInfo(state.pending))
    end
    local n = 0
    while n < PER_TICK do
        local id = Pop()
        if not id then
            return
        end
        local u = Codex.db.units[id]
        if NeedsInfo(u) then
            local info = ReadInfo(id)
            if info then
                state.stats.read = state.stats.read + 1
                if Lookup.Apply(id, info) then
                    Changed(id)
                end
                n = n + 1
            else
                -- dem Client unbekannt: nachladen lassen und auf die Antwort warten
                state.pending, state.pendingAt = id, now
                state.stats.requested = state.stats.requested + 1
                local ok = pcall(_G.C_CreatureInfo.RequestLoadCreatureByID, id)
                if not ok then
                    Finish(id, nil)
                end
                return
            end
        end
    end
end

function Lookup:Start()
    if self.started then
        return
    end
    self.started = true
    state.generation = state.generation + 1
    local gen = state.generation
    FW:RegisterEvent("CREATURE_DATA_LOAD_RESULT", Lookup.OnLoadResult, Lookup)
    local function Loop(delay, fn)
        C_Timer.After(delay, function()
            if not Lookup.started or gen ~= state.generation then
                return
            end
            fn()
            Loop(delay, fn)
        end)
    end
    Loop(TICK, Lookup.Step)
    -- erste Runde kurz nach dem Einloggen, danach alle 10 Minuten fuer neu gesehene Kreaturen
    C_Timer.After(20, function()
        if Lookup.started and gen == state.generation then
            Lookup.Scan()
        end
    end)
    Loop(600, Lookup.Scan)
end

function Lookup:Stop()
    self.started = false
    state.generation = state.generation + 1
    FW:UnregisterEvent("CREATURE_DATA_LOAD_RESULT", Lookup)
end

-- /fwlookup        Stand anzeigen
-- /fwlookup run    sofort neu durchsuchen
-- /fwlookup retry  auch fruehere Fehlschlaege noch einmal versuchen
-- /fwlookup id <N> eine einzelne Kreatur nachschlagen und anzeigen
-- /fwlookup clean Reste ohne Daten anzeigen; "clean yes" entfernt sie
function Lookup.Command(msg)
    msg = (msg or ""):lower()
    if msg == "retry" then
        Store().fail = {}
        msg = "run"
    end
    if msg == "run" then
        local n = Lookup.Scan()
        FW:Print(string.format("Nachschlagen: %d Kreaturen vorgemerkt", n))
        return
    end
    if msg == "clean" or msg == "clean yes" then
        -- Reste ohne Beobachtungen: Kreaturen, die der Client nicht kennt (Nachschlagen erfolglos), ohne Kills, Positionen,
        -- Rollen, Beute oder sonstige Daten. Erst anzeigen, nur mit "clean yes" loeschen.
        local Share = Codex.Share
        local list = {}
        for id in pairs(Store().fail) do
            local u = Codex.db.units[id]
            if type(u) == "table" and not (Share and Share.IsShareable and Share.IsShareable("u", u)) and not u.ed and not u.cde and not u.cen
                and not u.ro and not u.d and not u.cells and (u.k or 0) == 0 then
                list[#list + 1] = id
            end
        end
        table.sort(list)
        if #list == 0 then
            FW:Print("Aufraeumen: keine Reste gefunden")
            return
        end
        for _, id in ipairs(list) do
            local u = Codex.db.units[id]
            FW:Print(string.format("  %d  %s", id, tostring(u.n or u.ne or "?")))
        end
        if msg == "clean yes" then
            for _, id in ipairs(list) do
                Codex.db.units[id] = nil
                Store().fail[id] = nil
            end
            FW:Fire("CODEX_CHANGED", "unit", list[1])
            FW:Print(string.format("Aufraeumen: %d Kreaturen entfernt", #list))
        else
            FW:Print(string.format("Aufraeumen: %d Kreaturen ohne Daten. Zum Entfernen: /fwlookup clean yes", #list))
        end
        return
    end
    local want = msg:match("^id%s+(%d+)$")
    if want then
        local id = tonumber(want)
        local info = ReadInfo(id)
        if info then
            FW:Print(string.format("Kreatur %d: %s, Typ %s, Rang %s, Familie %s, Anzeige %s", id, tostring(info.name),
                tostring(info.type), tostring(info.rank), tostring(info.family), tostring(info.displayID)))
        else
            FW:Print("Kreatur " .. id .. " ist dem Client noch unbekannt (/fwnpc " .. id .. " laedt sie nach)")
        end
        return
    end
    local total, withType, withName = 0, 0, 0
    for id, u in pairs(Codex.db.units) do
        if type(id) == "number" then
            total = total + 1
            if u.ct then withType = withType + 1 end
            if u.ne or u.n then withName = withName + 1 end
        end
    end
    local failed = 0
    for _ in pairs(Store().fail) do failed = failed + 1 end
    local s = state.stats
    FW:Print(string.format("Nachschlagen: %s | Kreaturen %d, mit Typ %d, mit Namen %d | gelesen %d, angefragt %d, ergaenzt %d, erfolglos %d (gemerkt %d) | Schlange %d",
        Enabled() and "an" or "aus", total, withType, withName, s.read, s.requested, s.filled, s.failed, failed, Lookup.QueueSize()))
end

if _G.SlashCmdList then
    _G.SLASH_FWLOOKUP1 = "/fwlookup"
    _G.SlashCmdList["FWLOOKUP"] = function(msg) Lookup.Command(msg) end
end
