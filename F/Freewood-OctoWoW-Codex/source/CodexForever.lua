-- Freewood-OctoWoW-Codex: mitgelieferte Startdaten (Addon Freewood-OctoWoW-ForeverData)
--
-- ForeverData enthaelt, was Spieler in Forever bereits erfasst haben: Quests mit Geber, Abgabe, Zielen, Belohnungen und Ketten,
-- Kreaturen, Objekte, Beute, Wegenetz, Verkehrsverbindungen, Ortspunkte. Die Daten bilden die unterste Schicht:
--   eigene Daten > empfangene Daten > ForeverData > Classic-Vorlage (Freewood-OctoWoW-CodexData)
-- Sie liegen nur im Speicher (nichts davon wird gespeichert oder weitergesendet) und gehen durch dieselbe Pruefung
-- (Share.Sanitize) wie empfangene Datensaetze. Abschalten: /fwforever aus

local ADDON, NS = ...

local FW = _G.Freewood
local Codex = NS and NS.Codex
if not FW or not Codex then
    return
end

local Forever = { loaded = false, count = 0 }
Codex.Forever = Forever
NS.Forever = Forever

local DATA_ADDON = "Freewood-OctoWoW-ForeverData"

function Forever.Disabled()
    local db = Codex.db
    return db and db.settings and db.settings.noForever == true or false
end

-- Zusatztabellen (Item-Qualitaet, Item-Werte, Anzeige-IDs, Namen, Rezepte): nur fehlende Eintraege werden ergaenzt,
-- eigene Werte gehen vor. Einmal je Datenstand (db.foreverRev).
local function FillTable(dst, src, check)
    if type(dst) ~= "table" or type(src) ~= "table" then return end
    for k, v in pairs(src) do
        if dst[k] == nil and check(k, v) then dst[k] = v end
    end
end

local function IsId(k) return type(k) == "number" and k >= 1 and k == math.floor(k) and k < 1e9 end

local EXTRAS = {
    iq = function(k, v) return IsId(k) and type(v) == "number" and v >= 0 and v <= 8 end,
    iicon = function(k, v) return IsId(k) and type(v) == "string" and #v <= 120 and string.find(v, "^Interface") ~= nil end,
    disp = function(k, v) return IsId(k) and type(v) == "number" and v > 0 end,
    vfac = function(k, v) return IsId(k) and (v == "A" or v == "H") end,
    wrq = function(k, v) return IsId(k) and type(v) == "table" end,
    names = function(k, v) return IsId(k) and type(v) == "string" and #v <= 80 end,
    istats = function(k, v)
        if not IsId(k) or type(v) ~= "table" then return false end
        for sk, sv in pairs(v) do
            if sk == "_fx" then
                if type(sv) ~= "table" then return false end
            elseif type(sk) ~= "string" or #sk > 60 or (type(sv) ~= "number" and type(sv) ~= "string" and type(sv) ~= "boolean") then return false end
        end
        return true
    end,
}

local function MergeExtras(g)
    local db = Codex.db
    if not db or not g.extra or db.foreverRev == g.rev then return end
    for name, check in pairs(EXTRAS) do
        if type(g.extra[name]) == "table" then
            db[name] = db[name] or {}
            FillTable(db[name], g.extra[name], check)
        end
    end
    if type(g.extra.recipes) == "table" then
        db.recipes = db.recipes or {}
        for prof, list in pairs(g.extra.recipes) do
            if type(prof) == "string" and type(list) == "table" then
                db.recipes[prof] = db.recipes[prof] or {}
                FillTable(db.recipes[prof], list, function(k, v) return type(k) == "string" and #k <= 80 and type(v) == "table" end)
            end
        end
    end
    if type(g.extra.qd) == "table" then
        db.cat = db.cat or {}
        db.cat.qd = db.cat.qd or {}
        FillTable(db.cat.qd, g.extra.qd, function(k, v) return IsId(k) and type(v) == "table" end)
        if Codex.Catalog then Codex.Catalog.rev = (Codex.Catalog.rev or 0) + 1 end
    end
    -- Karten-Scan (Karten, Gebiete, Gebiete je Karte, Trigger, Flugpunkte): nur fehlende Eintraege, eigener Scan geht vor
    if type(g.extra.scan) == "table" then
        db.cat = db.cat or {}
        for _, name in ipairs({ "m", "a", "ma", "t", "x" }) do
            if type(g.extra.scan[name]) == "table" then
                db.cat[name] = db.cat[name] or {}
                FillTable(db.cat[name], g.extra.scan[name], function(k, v)
                    return type(k) == "number" and (type(v) == "string" or type(v) == "table")
                end)
            end
        end
    end
    db.foreverRev = g.rev
end

-- Daten des Addons laden (bei Bedarf wird das Addon geladen). Rueckgabe: true, wenn Daten da sind
function Forever.Load()
    if Forever.loaded then return true end
    if Forever.Disabled() or not Codex.Share or not Codex.Share.SetBuiltin then return false end
    local g = _G.FreewoodForeverData
    if not (g and g.ready) then
        local load = (_G.C_AddOns and _G.C_AddOns.LoadAddOn) or _G.LoadAddOn
        if type(load) == "function" then pcall(load, DATA_ADDON) end
        g = _G.FreewoodForeverData
    end
    if not (g and g.ready and type(g.list) == "table") then
        Forever.missing = true
        return false
    end
    if Forever.loading then return false end
    Forever.loading = true
    local list = g.list
    local total, slice, from = #list, 600, 1
    Codex.Share.BuiltinBegin()
    Forever.count = 0
    local function Finish()
        Codex.Share.BuiltinDone()
        pcall(MergeExtras, g)
        Forever.version, Forever.rev = g.version, g.rev
        Forever.loaded = true
        Forever.loading = false
        Forever.missing = false
        if Codex.chainRev then Codex.chainRev = Codex.chainRev + 1 end
        FW:Fire("CODEX_CHANGED", "forever")
    end
    local function Step()
        if not Forever.loading then return end   -- zwischendurch ausgeschaltet
        local to = math.min(total, from + slice - 1)
        Forever.count = Forever.count + Codex.Share.BuiltinAdd(list, from, to, true)   -- Startdaten sind geprueft
        from = to + 1
        if from > total then
            Finish()
        elseif _G.C_Timer and _G.C_Timer.After then
            _G.C_Timer.After(0.05, Step)
        else
            Step()
        end
    end
    Step()
    return true
end

-- Quellen eines Items aus den Startdaten: { u = { {id, chance} }, o = { ... }, v = { Haendler-IDs } } oder nil
local itemCache = {}
function Forever.Item(id)
    if not Forever.loaded or Forever.Disabled() then return nil end
    local g = _G.FreewoodForeverData
    local s = g and type(g.src) == "table" and g.src[id]
    if type(s) ~= "string" then return nil end
    local c = itemCache[id]
    if c then return c end
    c = { u = {}, o = {}, v = {} }
    for part in s:gmatch("[^;]+") do
        local tag, body = part:sub(1, 1), part:sub(2)
        if tag == "u" or tag == "o" then
            for k, v in body:gmatch("(%d+)=([%d%.]+)") do
                local t = c[tag]
                t[#t + 1] = { id = tonumber(k), chance = tonumber(v) }
            end
        elseif tag == "v" then
            for k in body:gmatch("%d+") do c.v[#c.v + 1] = tonumber(k) end
        end
    end
    itemCache[id] = c
    return c
end

-- Alle Item-IDs mit Quellen in den Startdaten (Tabelle id -> Text; nur lesen)
function Forever.ItemIds()
    if not Forever.loaded or Forever.Disabled() then return {} end
    local g = _G.FreewoodForeverData
    return (g and type(g.src) == "table") and g.src or {}
end

function Forever.ItemHasVendor(id)
    local it = Forever.Item(id)
    return it ~= nil and #it.v > 0
end

-- Schalter: an = Startdaten nutzen (Standard)
function Forever.SetEnabled(on)
    local db = Codex.db
    if not db then return end
    db.settings.noForever = (not on) or nil
    if on then
        Forever.Load()
    elseif Forever.loading then
        Forever.loading = false
        Codex.Share.SetBuiltin({})
        Forever.count = 0
    elseif Forever.loaded then
        Codex.Share.SetBuiltin({})
        Forever.loaded, Forever.count = false, 0
        if Codex.chainRev then Codex.chainRev = Codex.chainRev + 1 end
        FW:Fire("CODEX_CHANGED", "forever")
    end
end

function Forever.Status()
    local L = FW.L
    if Forever.Disabled() then return L.CODEX_FOREVER_OFF end
    if Forever.loaded then return string.format(L.CODEX_FOREVER_ON, Forever.count, tostring(Forever.version or "?")) end
    return L.CODEX_FOREVER_MISSING
end

SLASH_FREEWOODFOREVER1 = "/fwforever"
SlashCmdList["FREEWOODFOREVER"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "aus" or msg == "off" then
        Forever.SetEnabled(false)
    elseif msg == "an" or msg == "on" then
        Forever.SetEnabled(true)
    end
    FW:Print(Forever.Status())
end
