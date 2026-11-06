-- Freewood-OctoWoW-Codex: Quest-Katalog (Titel und Stufe aller Quest-IDs, die der Server kennt)
--
-- Der Server liefert zu jeder Quest-ID auf Anfrage (C_QuestLog.RequestLoadQuestByID) den Titel und die Stufe
-- (GetTitleForQuestID, GetQuestDifficultyLevel), auch fuer Quests, die man nie gesehen hat. Der Katalog fragt die IDs
-- gedrosselt ab und merkt sich nur "ID gibt es" mit Titel und Stufe. Geber, Ort, Ziele und Vorquests liefert er nicht;
-- die lernt der Codex weiter beim Spielen.
--
--   /fwquestkatalog              setzt den Lauf dort fort, wo er aufgehoert hat (Quest-IDs 1 bis 120000)
--   /fwquestkatalog <von> <bis>  nur diesen Bereich
--   /fwquestkatalog stop|status|neu
--   /fwkatalog <q|i|n> [von bis | stop | status | neu | test <id>]   dasselbe fuer Quests (q), Items (i) und NPCs (n)
--
-- Items: C_Item.RequestLoadItemDataByID, danach GetItemInfo (Qualitaet, Stufe, Mindeststufe, Verkaufspreis, Name).
-- NPCs: es gibt keine Abfrage nur mit ID; der Name kommt aus dem Tooltip eines Kreatur-Links (C_TooltipInfo.GetHyperlink).
--
-- Quest-Einzelheiten (0.1.57): C_QuestLog.GetQuestDetails liefert aus derselben Antwort Ziele (Kreatur/Objekt/Item mit ID
-- und Anzahl), feste und Wahl-Belohnungen, Geld, Startitem, gelehrten Zauber, Typ, Flags und die Texte. Ablage in
-- db.cat.qd[id]. Nicht dabei (schickt der Server nicht): Geber, Abgabe, Vorquests, Rasse, Klasse, Zeitlimit.
--   /fwquestkatalog details   holt die Einzelheiten fuer alle bekannten Quest-IDs nach
--
-- Ablage: db.cat = { loc = Sprache, pos/posi/posn = naechste ID, q = { [id] = "Stufe|Titel" }, i = { [id] = "Qualitaet|Stufe|Mindeststufe|Preis|Name" }, n = { [id] = "Name" } }. Die Startdaten (Freewood-OctoWoW-ForeverData)
-- bringen einen fertigen Katalog mit (extra.cat); der eigene geht vor.

local ADDON, NS = ...

local FW = _G.Freewood
local Codex = NS and NS.Codex
if not FW or not Codex then
    return
end

local Cat = { rev = 0 }
Codex.Catalog = Cat
NS.Catalog = Cat

local MAX_ID = 250000   -- Quests (Standard, wenn kein Bereich angegeben ist)
local BATCH = 10        -- Anfragen je Schub
local PAUSE = 1.0       -- Sekunden zwischen den Schueben (ca. 10 Anfragen/s)
local HARVEST = 4       -- Sekunden bis zum Einsammeln der Antworten eines Schubs

local function Now() return _G.GetTime and _G.GetTime() or 0 end

local function Store()
    local db = Codex.db
    if not db then return nil end
    db.cat = db.cat or {}
    local c = db.cat
    c.q = c.q or {}
    c.i = c.i or {}
    c.n = c.n or {}
    c.qd = c.qd or {}
    c.c = c.c or {}
    c.o = c.o or {}
    if not c.loc then c.loc = _G.GetLocale and _G.GetLocale() or nil end
    return c
end

local function Parse(s)
    if type(s) ~= "string" then return nil end
    local lv, t = s:match("^(%d+)|(.+)$")
    if not t then return nil end
    lv = tonumber(lv)
    return t, (lv and lv > 0) and lv or nil
end

-- Mitgelieferter Katalog (Startdaten)
local function Builtin()
    local f = Codex.Forever
    if f and f.Disabled and f.Disabled() then return nil end
    local g = _G.FreewoodForeverData
    local ex = g and g.ready and type(g.extra) == "table" and g.extra.cat
    if type(ex) == "table" and type(ex.q) == "table" then return ex end
    return nil
end

-- Titel, Stufe der Quest aus dem Katalog (eigener zuerst, dann die Startdaten)
function Cat.Get(id)
    if type(id) ~= "number" then return nil end
    local db = Codex.db
    local own = db and db.cat and db.cat.q and db.cat.q[id]
    local t, lv = Parse(own)
    if t then return t, lv or (Codex.WdbLevel and Codex.WdbLevel[id]) end
    local b = Builtin()
    if b then
        t, lv = Parse(b.q[id])
        if t then return t, lv or (Codex.WdbLevel and Codex.WdbLevel[id]) end
    end
    return nil
end

-- Einzelheiten einer Quest (entpackt) oder nil:
--   { req = { { kind = "monster"|"object"|"item", id, count } }, rew = { { id, count } }, choice = { ... },
--     money, src, spell, flags, qtype, poi = { map, x, y }, desc, obj, done, objText = { [Nr] = Text } }
local detCache = setmetatable({}, { __mode = "k" })
local function Unpack(list)
    local out = {}
    if type(list) ~= "string" then return out end
    for id, n in list:gmatch("(%d+)x(%d+)") do out[#out + 1] = { id = tonumber(id), count = tonumber(n) } end
    return out
end

function Cat.Details(id)
    local db = Codex.db
    local r = db and db.cat and db.cat.qd and db.cat.qd[id]
    if type(r) ~= "table" then return nil end
    local hit = detCache[r]
    if hit then return hit end
    local d = { req = {}, rew = Unpack(r.w), choice = Unpack(r.c), money = r.m, src = r.s, spell = r.sp, flags = r.f,
        qtype = r.t, desc = r.d, obj = r.o, done = r.e, objText = {} }
    if type(r.r) == "string" then
        for code, rid, n in r.r:gmatch("(%a)(%d+)x(%d+)") do
            rid = tonumber(rid)
            -- Objekte kommen als negative Zahl (32 Bit) an: 2147483648 - ID
            if code == "o" and rid > 1073741824 then rid = 2147483648 - rid end
            d.req[#d.req + 1] = { kind = code == "m" and "monster" or (code == "o" and "object" or "item"), id = rid, count = tonumber(n) }
        end
    end
    if type(r.ot) == "string" then
        for nr, t in r.ot:gmatch("(%d+)=([^;]*)") do d.objText[tonumber(nr)] = t end
    end
    if type(r.p) == "string" then
        local m, x, y = r.p:match("^(%d+):([%d%.]+):([%d%.]+)$")
        if m then d.poi = { map = tonumber(m), x = tonumber(x), y = tonumber(y) } end
    end
    detCache[r] = d
    return d
end

function Cat.DetailCount()
    local n = 0
    local db = Codex.db
    for _ in pairs(db and db.cat and db.cat.qd or {}) do n = n + 1 end
    return n
end

-- Rueckverweise aus den Einzelheiten: { monster = { [id] = { questID, ... } }, object = ..., item = ... (Ziel-Item),
--   reward = ... (feste Belohnung oder Wahl), src = ... (Startitem) } - gebaut je Stand des Katalogs
local revIdx, revIdxRev
function Cat.Reverse()
    if revIdx and revIdxRev == Cat.rev then return revIdx end
    local idx = { monster = {}, object = {}, item = {}, reward = {}, src = {} }
    local db = Codex.db
    local function Add(group, id, qid)
        local t = idx[group][id]
        if not t then t = {} idx[group][id] = t end
        if t[#t] ~= qid then t[#t + 1] = qid end
    end
    local ids = {}
    for qid in pairs(db and db.cat and db.cat.qd or {}) do
        if type(qid) == "number" then ids[#ids + 1] = qid end
    end
    table.sort(ids)
    for _, qid in ipairs(ids) do
        local d = Cat.Details(qid)
        if d then
            for _, r in ipairs(d.req) do Add(r.kind, r.id, qid) end
            for _, it in ipairs(d.rew) do Add("reward", it.id, qid) end
            for _, it in ipairs(d.choice) do Add("reward", it.id, qid) end
            if d.src then Add("src", d.src, qid) end
        end
    end
    revIdx, revIdxRev = idx, Cat.rev
    return idx
end

-- Stand des Katalogs (aendert sich mit neuen eigenen Titeln und mit dem Laden oder Abschalten der Startdaten)
function Cat.Rev()
    local b = Builtin()
    return Cat.rev .. ":" .. (b and tostring(b) or "-")
end

-- Alle IDs des Katalogs (eigene und mitgelieferte), sortiert
local idCache, idRev
function Cat.IDs()
    local rev = Cat.Rev()
    if idCache and idRev == rev then return idCache end
    local seen, out = {}, {}
    local db = Codex.db
    for id in pairs(db and db.cat and db.cat.q or {}) do
        if type(id) == "number" then seen[id] = true out[#out + 1] = id end
    end
    local b = Builtin()
    if b then
        for id in pairs(b.q) do
            if type(id) == "number" and not seen[id] then seen[id] = true out[#out + 1] = id end
        end
    end
    table.sort(out)
    idCache, idRev = out, rev
    return out
end

function Cat.Count()
    local db = Codex.db
    local own = 0
    for _ in pairs(db and db.cat and db.cat.q or {}) do own = own + 1 end
    return own, #Cat.IDs()
end

------------------------------------------------------------------------
-- Arten: q = Quests, i = Items, n = NPCs
------------------------------------------------------------------------

local function CleanName(t)
    t = tostring(t):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|", "/")
    return t
end

local function ReqQuest(id)
    local QL = _G.C_QuestLog
    pcall(QL.RequestLoadQuestByID, id)
end

local function ReadQuest(id)
    local QL = _G.C_QuestLog
    local ok, t = pcall(QL.GetTitleForQuestID, id)
    if not (ok and type(t) == "string" and t ~= "") then return nil end
    local lv = 0
    if QL.GetQuestDifficultyLevel then
        local ok2, v = pcall(QL.GetQuestDifficultyLevel, id)
        if ok2 and type(v) == "number" and v > 0 and v < 200 then lv = math.floor(v) end
    end
    return lv .. "|" .. CleanName(t)
end

-- Einzelheiten einer Quest aus der Server-Antwort (nil, wenn nicht geladen). Kurze Schluessel, Listen als Text:
--   r = Ziele "m6x10;o1617x1;i182x1" (m Kreatur, o Objekt, i Item), w = feste Belohnung "60x1", c = Wahl "6076x1;60x1"
--   m = Geld, s = Startitem, sp = gelehrter Zauber, f = Flags, t = Typ, p = Kartenpunkt "Karte:x:y"
--   d = Beschreibung, o = Zieltext, e = Abschlusstext, ot = Zieltexte je Ziel "1=Text;2=Text" (nur wenn vorhanden)
local function Txt(v)
    if type(v) ~= "string" or v == "" then return nil end
    return (v:gsub("|", "/"))
end

local function PairsText(list)
    if type(list) ~= "table" then return nil end
    local out = {}
    for i = 1, #list do
        local it = list[i]
        if type(it) == "table" and tonumber(it.id) and it.id > 0 then
            out[#out + 1] = math.floor(it.id) .. "x" .. math.floor(tonumber(it.count) or 1)
        end
    end
    if #out == 0 then return nil end
    return table.concat(out, ";")
end

local KIND_CODE = { monster = "m", object = "o", item = "i" }

local function ReadDetails(id)
    local QL = _G.C_QuestLog
    if not (QL and QL.GetQuestDetails) then return nil end
    local ok, d = pcall(QL.GetQuestDetails, id)
    if not (ok and type(d) == "table") then return nil end
    local rec = {}
    local req, ot = {}, {}
    for i = 1, #(d.requirements or {}) do
        local r = d.requirements[i]
        local code = r and KIND_CODE[r.kind]
        if code and tonumber(r.id) then
            req[#req + 1] = code .. math.floor(r.id) .. "x" .. math.floor(tonumber(r.count) or 1)
            local t = Txt(r.text)
            if t then ot[#ot + 1] = #req .. "=" .. t:gsub(";", ",") end
        end
    end
    if #req > 0 then rec.r = table.concat(req, ";") end
    if #ot > 0 then rec.ot = table.concat(ot, ";") end
    rec.w = PairsText(d.rewardItems)
    rec.c = PairsText(d.choiceItems)
    local function N(v) v = tonumber(v) return (v and v > 0) and math.floor(v) or nil end
    rec.m = N(d.rewardMoney)
    rec.s = N(d.srcItemID)
    rec.sp = N(d.rewardSpellID)
    rec.f = N(d.questFlags)
    rec.t = Txt(d.questType)
    if type(d.poi) == "table" and N(d.poi.mapID) then
        rec.p = math.floor(d.poi.mapID) .. ":" .. string.format("%.3f", tonumber(d.poi.x) or 0) .. ":" .. string.format("%.3f", tonumber(d.poi.y) or 0)
    end
    rec.d = Txt(d.description)
    rec.o = Txt(d.objectives)
    rec.e = Txt(d.completionText)
    return rec
end

local function ItemInfo(id)
    local CI = _G.C_Item
    local get = (CI and CI.GetItemInfo) or _G.GetItemInfo
    if not get then return nil end
    return get(id)
end

local function ReqItem(id)
    local CI = _G.C_Item
    if CI and CI.RequestLoadItemDataByID then pcall(CI.RequestLoadItemDataByID, id)
    else pcall(ItemInfo, id) end
end

local function ReadItem(id)
    local ok, name, _, quality, ilvl, minLvl, _, _, _, _, _, sell = pcall(ItemInfo, id)
    if not (ok and type(name) == "string" and name ~= "") then return nil end
    local function N(v) return math.floor(tonumber(v) or 0) end
    return string.format("%d|%d|%d|%d|%s", N(quality), N(ilvl), N(minLvl), N(sell), CleanName(name))
end

local function UnitLink(id)
    return "unit:Creature-0-0-0-0-" .. id .. "-0000000000"
end

local function NpcData(id)
    local TI = _G.C_TooltipInfo
    if not (TI and TI.GetHyperlink) then return nil end
    local ok, data = pcall(TI.GetHyperlink, UnitLink(id))
    if ok and type(data) == "table" then return data end
    return nil
end

local function ReqNpc(id) NpcData(id) end

local function ReadNpc(id)
    local data = NpcData(id)
    local line = data and data.lines and data.lines[1]
    local name = line and line.leftText
    if type(name) ~= "string" or name == "" then return nil end
    return CleanName(name)
end

-- Kreaturen und Objekte ueber die Server-Abfrage (ClassicAPI: C_CreatureInfo, C_GameObjectInfo).
-- Ablage: "Feld=Wert;Feld=Wert|Name|Untertitel" - alle einfachen Felder der Antwort werden mitgenommen
local function Pack(info)
    local keys = {}
    for k, v in pairs(info) do
        local tv = type(v)
        if k ~= "name" and k ~= "subName" and type(k) == "string" and (tv == "number" or tv == "boolean" or tv == "table") then
            keys[#keys + 1] = k
        end
    end
    table.sort(keys)
    local parts = {}
    for _, k in ipairs(keys) do
        local v = info[k]
        if type(v) == "number" then
            parts[#parts + 1] = k .. "=" .. (v == math.floor(v) and string.format("%d", v) or string.format("%.3f", v))
        elseif type(v) == "boolean" then
            parts[#parts + 1] = k .. "=" .. (v and "1" or "0")
        else
            local list = {}
            for i = 1, 24 do
                if type(v[i]) == "number" then list[#list + 1] = string.format("%d", math.floor(v[i])) else break end
            end
            if #list > 0 then parts[#parts + 1] = k .. "=" .. table.concat(list, ",") end
        end
    end
    local sub = type(info.subName) == "string" and info.subName ~= "" and info.subName or ""
    return table.concat(parts, ";") .. "|" .. CleanName(info.name) .. "|" .. CleanName(sub)
end

local function Entity(kind, id)
    local C = kind == "c" and _G.C_CreatureInfo or _G.C_GameObjectInfo
    local get = C and (kind == "c" and C.GetCreatureInfoByID or C.GetGameObjectInfoByID)
    if not get then return nil end
    local ok, info = pcall(get, id)
    if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then return info end
    return nil
end

local function ReqEntity(kind, id)
    local C = kind == "c" and _G.C_CreatureInfo or _G.C_GameObjectInfo
    local req = C and (kind == "c" and C.RequestLoadCreatureByID or C.RequestLoadGameObjectByID)
    if req then pcall(req, id) end
end

local function ReadEntity(kind, id)
    local info = Entity(kind, id)
    return info and Pack(info) or nil
end

local KINDS = {
    q = { store = "q", pos = "pos", max = MAX_ID, req = ReqQuest, read = ReadQuest, label = "Quests",
        ready = function() local QL = _G.C_QuestLog return QL and QL.RequestLoadQuestByID and QL.GetTitleForQuestID end },
    i = { store = "i", pos = "posi", max = 250000, req = ReqItem, read = ReadItem, label = "Items",
        ready = function() return (_G.C_Item and (_G.C_Item.GetItemInfo or _G.C_Item.RequestLoadItemDataByID)) or _G.GetItemInfo end },
    n = { store = "n", pos = "posn", max = 250000, req = ReqNpc, read = ReadNpc, label = "NPCs",
        ready = function() return _G.C_TooltipInfo and _G.C_TooltipInfo.GetHyperlink end },
    c = { store = "c", pos = "posc", max = 150000, req = function(id) ReqEntity("c", id) end, read = function(id) return ReadEntity("c", id) end,
        label = "Kreaturen", ready = function() local C = _G.C_CreatureInfo return C and C.RequestLoadCreatureByID and C.GetCreatureInfoByID end },
    o = { store = "o", pos = "poso", max = 250000, req = function(id) ReqEntity("o", id) end, read = function(id) return ReadEntity("o", id) end,
        label = "Objekte", ready = function() local C = _G.C_GameObjectInfo return C and C.RequestLoadGameObjectByID and C.GetGameObjectInfoByID end },
}
Cat.KINDS = KINDS

-- Item aus dem Katalog: Qualitaet, Stufe, Mindeststufe, Verkaufspreis, Name
function Cat.GetItem(id)
    local function P(s)
        if type(s) ~= "string" then return nil end
        local q, il, ml, sp, nm = s:match("^(%d+)|(%d+)|(%d+)|(%d+)|(.+)$")
        if not nm then return nil end
        return nm, tonumber(q), tonumber(il), tonumber(ml), tonumber(sp)
    end
    local db = Codex.db
    local r = { P(db and db.cat and db.cat.i and db.cat.i[id]) }
    if r[1] then return unpack(r) end
    local b = Builtin()
    return P(b and b.i and b.i[id])
end

-- NPC-Name aus dem Katalog
function Cat.GetNpc(id)
    local db = Codex.db
    local own = db and db.cat and db.cat.n and db.cat.n[id]
    if type(own) == "string" then return own end
    local b = Builtin()
    local v = b and b.n and b.n[id]
    return type(v) == "string" and v or nil
end

------------------------------------------------------------------------
-- Lauf
------------------------------------------------------------------------

local function Say(text) FW:Print("Katalog: " .. text) end

local function CountOf(kind)
    local c = Codex.db and Codex.db.cat
    local n = 0
    for _ in pairs(c and c[KINDS[kind].store] or {}) do n = n + 1 end
    return n
end

local function Harvest(job, a, b)
    local K = KINDS[job.kind]
    local c = Store()
    if c then
        local tbl = c[K.store]
        for i = a, b do
            local id = job.ids and job.ids[i] or i
            local entry = K.read(id)
            if entry and tbl[id] ~= entry then
                if not tbl[id] then job.found = job.found + 1 end
                tbl[id] = entry
                Cat.rev = Cat.rev + 1
            end
            if job.kind == "q" and entry and not (c.qd and c.qd[id]) then
                local det = ReadDetails(id)
                if det then
                    c.qd[id] = det
                    job.details = (job.details or 0) + 1
                    Cat.rev = Cat.rev + 1
                end
            end
        end
    end
    job.pending = job.pending - 1
    if job.nextID > job.hi and job.pending <= 0 and Cat.job == job then
        Cat.job = nil
        Say(string.format("%s fertig mit %d-%d: %d neue Eintraege, insgesamt %d eigene%s (%d Sekunden).", K.label, job.lo, job.hi, job.found, CountOf(job.kind),
            job.kind == "q" and string.format(", %d neue Einzelheiten", job.details or 0) or "", math.floor(Now() - job.t0)))
        FW:Fire("CODEX_CHANGED", "catalog")
        if job.onDone then job.onDone() end
    end
end

local function Step(job)
    if Cat.job ~= job then return end
    if job.stop then
        if job.pending <= 0 then Cat.job = nil end
        return
    end
    if _G.InCombatLockdown and _G.InCombatLockdown() then
        C_Timer.After(2, function() Step(job) end)
        return
    end
    -- Bremse: bei niedriger Framerate, hoher Latenz oder zu vielen offenen
    -- Schueben nicht nachlegen, sondern warten (der Client bleibt bedienbar)
    local fps = _G.GetFramerate and _G.GetFramerate() or 60
    local lat = 0
    if _G.GetNetStats then
        local _, _, home, world = _G.GetNetStats()
        lat = math.max(tonumber(home) or 0, tonumber(world) or 0)
    end
    if fps < 15 or lat > 600 or job.pending >= 5 then
        job.waits = (job.waits or 0) + 1
        C_Timer.After(fps < 15 and 4 or 2, function() Step(job) end)
        return
    end
    local K = KINDS[job.kind]
    local a = job.nextID
    local b = math.min(a + BATCH - 1, job.hi)
    for i = a, b do K.req(job.ids and job.ids[i] or i) end
    job.nextID = b + 1
    job.pending = job.pending + 1
    local c = Store()
    if job.resume and c then c[K.pos] = job.nextID end
    C_Timer.After(HARVEST, function() Harvest(job, a, b) end)
    -- Fortschritt alle 10000 IDs
    if math.floor(a / 10000) ~= math.floor(b / 10000) then
        Say(string.format("%s: ID %d von %d ...", K.label, b, job.hi))
    end
    if job.nextID <= job.hi then
        C_Timer.After(PAUSE, function() Step(job) end)
    end
end

-- Rueckgabe: true oder false, Grund ("api", "busy", "range")
function Cat.Start(lo, hi, resume, kind, ids)
    kind = kind or "q"
    local K = KINDS[kind]
    if not K then return false, "kind" end
    if not K.ready() then return false, "api" end
    if Cat.job then return false, "busy" end
    if not Store() then return false, "db" end
    lo = math.max(1, math.floor(tonumber(lo) or 1))
    hi = math.min(ids and #ids or K.max, math.floor(tonumber(hi) or K.max))
    if hi < lo then return false, "range" end
    local job = { kind = kind, lo = lo, hi = hi, nextID = lo, found = 0, pending = 0, t0 = Now(), resume = resume, ids = ids }
    Cat.job = job
    Step(job)
    return true, lo, hi
end

function Cat.Stop()
    if Cat.job then Cat.job.stop = true end
end

-- Lauf dort fortsetzen, wo er aufgehoert hat (fuer Befehl und Dev-Knopf). Rueckgabe wie Start; "done", wenn alles durch ist
function Cat.Resume(restart, kind)
    kind = kind or "q"
    local K = KINDS[kind]
    local c = Store()
    if restart and c then c[K.pos] = 1 end
    local pos = c and c[K.pos] or 1
    if pos > K.max then return false, "done" end
    return Cat.Start(pos, K.max, true, kind)
end

-- Kreatur / Objekt aus dem Katalog: Name, Untertitel, Felder (Tabelle) - oder nil
local entCache = setmetatable({}, { __mode = "v" })
function Cat.GetEntity(kind, id)
    local db = Codex.db
    local s = db and db.cat and db.cat[kind] and db.cat[kind][id]
    if type(s) ~= "string" then return nil end
    local hit = entCache[s]
    if hit then return hit.name, hit.sub, hit.f end
    local f, name, sub = s:match("^([^|]*)|([^|]*)|?(.*)$")
    if not name then return nil end
    local fields = {}
    for k, v in f:gmatch("(%w+)=([^;]+)") do fields[k] = tonumber(v) or v end
    entCache[s] = { name = name, sub = sub ~= "" and sub or nil, f = fields }
    return name, sub ~= "" and sub or nil, fields
end
function Cat.GetCreature(id) return Cat.GetEntity("c", id) end
function Cat.GetObject(id) return Cat.GetEntity("o", id) end

-- Ziele aus den Quest-Einzelheiten, die noch nicht im Katalog stehen
function Cat.TargetIDs(kind)
    local rev = Cat.Reverse()[kind == "c" and "monster" or "object"]
    local have = Codex.db and Codex.db.cat and Codex.db.cat[kind] or {}
    local ids = {}
    for id in pairs(rev) do
        if not have[id] then ids[#ids + 1] = id end
    end
    table.sort(ids)
    return ids
end

-- Holt Kreaturen, danach Objekte, die in Quests als Ziel vorkommen. Rueckgabe wie Start
function Cat.StartTargets()
    local cs, os = Cat.TargetIDs("c"), Cat.TargetIDs("o")
    local function Objects()
        if #os > 0 then Cat.Start(1, #os, false, "o", os) end
    end
    if #cs > 0 then
        local ok, a = Cat.Start(1, #cs, false, "c", cs)
        if ok then Cat.job.onDone = Objects return true, #cs + #os end
        return false, a
    end
    if #os > 0 then
        local ok, a = Cat.Start(1, #os, false, "o", os)
        if ok then return true, #os end
        return false, a
    end
    return false, "none"
end

------------------------------------------------------------------------
-- Aus dem Quest-Cache des Clients (CodexWdbChain.lua): Zone, Ruf-Ziel, Art
------------------------------------------------------------------------
local SORTS = {
    [-1] = { "Epic", "Episch" }, [-22] = { "Seasonal", "Saisonal" }, [-24] = { "Herbalism", "Kräuterkunde" },
    [-61] = { "Warlock", "Hexenmeister" }, [-81] = { "Warrior", "Krieger" }, [-82] = { "Shaman", "Schamane" },
    [-101] = { "Fishing", "Angeln" }, [-121] = { "Blacksmithing", "Schmiedekunst" }, [-141] = { "Paladin", "Paladin" },
    [-161] = { "Mage", "Magier" }, [-162] = { "Rogue", "Schurke" }, [-181] = { "Alchemy", "Alchemie" },
    [-182] = { "Leatherworking", "Lederverarbeitung" }, [-201] = { "Engineering", "Ingenieurskunst" },
    [-221] = { "Treasure map", "Schatzkarte" }, [-241] = { "Tournament", "Turnier" }, [-261] = { "Hunter", "Jäger" },
    [-262] = { "Priest", "Priester" }, [-263] = { "Druid", "Druide" }, [-264] = { "Tailoring", "Schneiderei" },
    [-284] = { "Special", "Besonderes" }, [-304] = { "Cooking", "Kochkunst" }, [-324] = { "First Aid", "Erste Hilfe" },
    [-344] = { "Legendary", "Legendär" }, [-364] = { "Darkmoon Faire", "Dunkelmond-Jahrmarkt" },
    [-365] = { "Ahn'Qiraj War", "Ahn'Qiraj-Krieg" }, [-366] = { "Lunar Festival", "Mondfest" },
    [-367] = { "Reputation", "Ruf" }, [-368] = { "Invasion", "Invasion" }, [-369] = { "Midsummer", "Sonnenwendfest" },
}
local FACTIONS = {
    [21] = "Booty Bay", [47] = "Ironforge", [54] = "Gnomeregan Exiles", [59] = "Thorium Brotherhood", [67] = "Horde",
    [68] = "Undercity", [69] = "Darnassus", [70] = "Syndicate", [72] = "Stormwind", [76] = "Orgrimmar",
    [81] = "Thunder Bluff", [87] = "Bloodsail Buccaneers", [92] = "Gelkis Clan Centaur", [93] = "Magram Clan Centaur",
    [270] = "Zandalar Tribe", [349] = "Ravenholdt", [369] = "Gadgetzan", [470] = "Ratchet", [509] = "League of Arathor",
    [510] = "The Defilers", [529] = "Argent Dawn", [530] = "Darkspear Trolls", [576] = "Timbermaw Hold",
    [577] = "Everlook", [609] = "Cenarion Circle", [729] = "Frostwolf Clan", [730] = "Stormpike Guard",
    [749] = "Hydraxian Waterlords", [809] = "Shen'dralar", [889] = "Warsong Outriders", [890] = "Silverwing Sentinels",
    [910] = "Brood of Nozdormu",
}
local STANDINGS = { { 42000, "Exalted", "Ehrfürchtig" }, { 21000, "Revered", "Respektvoll" }, { 9000, "Honored", "Wohlwollend" },
    { 3000, "Friendly", "Freundlich" } }
local INFOS = { [1] = { "Group", "Gruppe" }, [41] = { "PvP", "PvP" }, [62] = { "Raid", "Schlachtzug" },
    [81] = { "Dungeon", "Dungeon" }, [82] = { "World event", "Weltereignis" } }

local function Pick(t) if not t then return nil end return Codex.Lang() == "en" and t[1] or t[2] end

local zoneNames = {}
function Cat.ZoneName(z)
    if type(z) ~= "number" or z == 0 then return nil end
    if z < 0 then return Pick(SORTS[z]) end
    local n = zoneNames[z]
    if n == nil then
        n = false
        local own = Codex.db and Codex.db.cat and Codex.db.cat.a and Codex.db.cat.a[z]
        if type(own) == "string" then
            n = own:match("|(.+)$") or own
        end
        local CM = _G.C_Map
        if not n and CM and CM.GetAreaInfo then
            local ok, name = pcall(CM.GetAreaInfo, z)
            if ok and type(name) == "string" and name ~= "" then n = name end
        end
        if not n and CM and CM.GetMapInfo then
            local ok, info = pcall(CM.GetMapInfo, z)
            if ok and type(info) == "table" and type(info.name) == "string" then n = info.name end
        end
        zoneNames[z] = n
    end
    return n or nil
end

-- Fraktionsname: erst die Spielfunktion (Spielsprache), sonst die feste Liste
local factionNames = {}
function Cat.FactionName(id)
    local n = factionNames[id]
    if n == nil then
        n = false
        local f = _G.GetFactionInfoByID or (_G.C_Reputation and _G.C_Reputation.GetFactionInfoByID)
        if f then
            local ok, name = pcall(f, id)
            if ok and type(name) == "string" and name ~= "" then n = name end
        end
        if not n then
            local ok, d = pcall(function() return _G.C_Reputation.GetFactionDataByID(id) end)
            if ok and type(d) == "table" and type(d.name) == "string" then n = d.name end
        end
        factionNames[id] = n
    end
    return n or FACTIONS[id]
end

-- { zone = Zonenname/Kategorie, zoneID, rep = "Name: Stufe", info = "Gruppe"/"Dungeon"/... } (nur was bekannt ist)
function Cat.QuestMeta(id)
    local z = Codex.WdbZone and Codex.WdbZone[id]
    local r = Codex.WdbRep and Codex.WdbRep[id]
    local i = Codex.WdbInfo and Codex.WdbInfo[id]
    if not (z or r or i) then return nil end
    local m = { zoneID = z, zone = z and Cat.ZoneName(z) or nil, info = i and Pick(INFOS[i]) or nil }
    if r then
        local st
        for _, s in ipairs(STANDINGS) do if r[2] >= s[1] then st = Codex.Lang() == "en" and s[2] or s[3] break end end
        m.rep = (Cat.FactionName(r[1]) or ("#" .. r[1])) .. ": " .. (st or tostring(r[2]))
    end
    return m
end

-- Quest-IDs des Katalogs, zu denen noch keine Einzelheiten gespeichert sind
function Cat.MissingDetails()
    local have = Codex.db and Codex.db.cat and Codex.db.cat.qd or {}
    local ids = {}
    for _, id in ipairs(Cat.IDs()) do
        if not have[id] then ids[#ids + 1] = id end
    end
    return ids
end

-- Holt die Einzelheiten (Ziele, Belohnungen, Texte) nach. Rueckgabe: true, Anzahl | false, Grund ("none", "busy", "api" ...)
function Cat.StartDetails()
    local ids = Cat.MissingDetails()
    if #ids == 0 then return false, "none" end
    local ok, a = Cat.Start(1, #ids, false, "q", ids)
    if ok then return true, #ids end
    return false, a
end

-- Stand fuer die Anzeige: laeuft, naechste ID, letzte ID, eigene Eintraege, gesamt (nur Quests mit Startdaten)
function Cat.Progress(kind)
    kind = kind or "q"
    local K = KINDS[kind]
    local c = Codex.db and Codex.db.cat
    local own, all = CountOf(kind), CountOf(kind)
    if kind == "q" then own, all = Cat.Count() end
    local running = Cat.job ~= nil and not Cat.job.stop and Cat.job.kind == kind
    return running, (Cat.job and Cat.job.kind == kind and Cat.job.nextID) or (c and c[K.pos]) or 1, K.max, own, all
end

local function Status(kind)
    local K = KINDS[kind]
    local c = Codex.db and Codex.db.cat
    local pos = c and c[K.pos] or 1
    local own, all = CountOf(kind), nil
    if kind == "q" then own, all = Cat.Count() end
    local line = string.format("%s: %d eigene Eintraege%s. Lauf bis ID %d von %d.", K.label, own, all and (", " .. all .. " im Katalog (mit Startdaten)") or "", math.min(pos, K.max), K.max)
    if kind == "q" then line = line .. string.format(" Einzelheiten (Ziele, Belohnungen, Texte): %d.", Cat.DetailCount()) end
    if Cat.job then line = line .. " Laeuft: " .. KINDS[Cat.job.kind].label .. " (ID " .. Cat.job.nextID .. ")." end
    Say(line)
end

-- Einzelne ID pruefen (zeigt die Rohantwort, speichert nichts)
local function Test(kind, id)
    local K = KINDS[kind]
    if not K.ready() then Say(K.label .. ": diese Abfrage bietet das Spiel nicht an.") return end
    K.req(id)
    C_Timer.After(2, function()
        local entry = K.read(id)
        Say(string.format("%s-Test ID %d: %s", K.label, id, entry or "keine Antwort (unbekannt oder noch nicht geladen)"))
    end)
    Say(string.format("%s-Test ID %d: Antwort in 2 Sekunden ...", K.label, id))
end

local function Handle(kind, msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local K = KINDS[kind]
    if msg == "stop" then
        if Cat.job then Cat.Stop() Say("wird angehalten (der Stand bleibt erhalten).") else Say("es laeuft nichts.") end
        return
    elseif msg == "status" then
        Status(kind)
        return
    end
    if kind == "q" and msg == "details" then
        local ok, n = Cat.StartDetails()
        if ok then
            Say(string.format("Einzelheiten fuer %d Quests werden geholt (ca. %d Sekunden). Anhalten: stop.", n, math.ceil(n / (BATCH / PAUSE))))
        elseif n == "none" then
            Say("alle bekannten Quests haben schon Einzelheiten (" .. Cat.DetailCount() .. ").")
        elseif n == "busy" then
            Say("es laeuft schon ein Lauf (stop zum Anhalten).")
        else
            Say("nicht moeglich: " .. tostring(n))
        end
        return
    end
    if (kind == "c" or kind == "o") and msg == "ziele" then
        local ok, n = Cat.StartTargets()
        if ok then
            Say(string.format("%d Ziele aus Quests (Kreaturen, dann Objekte) werden geholt. Anhalten: stop.", n))
        elseif n == "none" then
            Say("alle Ziele aus den Quests sind schon im Katalog.")
        else
            Say("nicht moeglich: " .. tostring(n))
        end
        return
    end
    local tid = msg:match("^test%s+(%d+)$")
    if tid then Test(kind, tonumber(tid)) return end
    local lo, hi = msg:match("^(%d+)%D+(%d+)$")
    local ok, a, b
    if lo then
        ok, a, b = Cat.Start(tonumber(lo), tonumber(hi), false, kind)
    else
        ok, a, b = Cat.Resume(msg == "neu", kind)
        if a == "done" then
            Say(K.label .. ": bis ID " .. K.max .. " durchgelaufen. Mit neu beginnt ein neuer Lauf von vorn (vorhandene Eintraege bleiben).")
            return
        end
    end
    if ok then
        Say(string.format("%s: Lauf %d-%d gestartet (gedrosselt, ca. %d Anfragen pro Sekunde). Anhalten: stop. Du kannst weiterspielen.",
            K.label, a, b, math.floor(BATCH / PAUSE)))
    elseif a == "busy" then
        Say("es laeuft schon ein Lauf (stop zum Anhalten).")
    elseif a == "api" then
        Say(K.label .. ": diese Abfrage bietet diese Version von Forever nicht an.")
    else
        Say("Bereich nicht moeglich.")
    end
end

SLASH_FREEWOODQUESTCAT1 = "/fwquestkatalog"
SlashCmdList["FREEWOODQUESTCAT"] = function(msg) Handle("q", msg) end

SLASH_FREEWOODCAT1 = "/fwkatalog"
SlashCmdList["FREEWOODCAT"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", "")
    local k, rest = msg:match("^(%a)%s*(.*)$")
    if k == "q" or k == "i" or k == "n" or k == "c" or k == "o" then Handle(k, rest) return end
    Say("benutze /fwkatalog q|i|n [von bis | stop | status | neu | test <id>]  (q = Quests, i = Items, n = NPC-Namen, c = Kreaturen, o = Objekte); q details holt Ziele, Belohnungen und Texte nach; c/o ziele holt nur die Ziele aus den Quests")
end
