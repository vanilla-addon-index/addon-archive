-- Freewood-OctoWoW-Codex: Flugrouten (Taxi)
--
-- Erfasst beim Flug: Start- und Zielpunkt, die Strecke (Punkte alle paar Sekunden), die Flugdauer und den bezahlten Preis.
-- Je Charakter: welche Flugpunkte er kennt, wie viel Gold er fuer Fluege ausgegeben hat und wie oft er geflogen ist.
--
--   db.taxi.nodes[id]  = { n = Name, w = Welt, tx, ty = Position auf der Flugkarte, a, b = Weltposition (erster, zweiter Wert von UnitPosition) }
--   db.taxi.routes[id] = { a = Start-ID, b = Ziel-ID, t = Sekunden, c = Preis in Kupfer, n = Anzahl, p = { a1, b1, a2, b2, ... }, upd = Stand }
--   db.taxiChar[Charakter] = { known = { [id] = true }, spent = Kupfer, trips = Anzahl, log = { { t, a, b, c, d }, ... } }
-- Die Flugpunkt-ID kommt aus der Position auf der Flugkarte (sprachunabhaengig), sonst aus dem Namen.
-- Zwischenlandungen: aufgezeichnet wird die Gesamtstrecke bis zum gewaehlten Ziel.

local ADDON, NS = ...

local FW = _G.Freewood
local Codex = NS and NS.Codex
if not FW or not Codex then
    return
end

local Taxi = { state = {} }
Codex.Taxi = Taxi
NS.Taxi = Taxi
local state = Taxi.state

local SAMPLE = 3          -- Sekunden zwischen zwei Streckenpunkten
local MAX_POINTS = 120    -- Punkte je Route (je 2 Zahlen)
local MAX_ROUTES = 600
local MAX_NODES = 300
local MAX_LOG = 30
local PRICE_WINDOW = 6    -- Sekunden nach dem Start, in denen der abgezogene Betrag nachgemessen wird

local function Clock() return _G.GetTime and _G.GetTime() or 0 end
local function Now() return _G.time and _G.time() or 0 end
local function Round(v) return math.floor((v or 0) + 0.5) end

local function DB()
    local db = Codex.db
    if not db then return nil end
    local t = db.taxi
    if type(t) ~= "table" then t = {}; db.taxi = t end
    t.nodes = t.nodes or {}
    t.routes = t.routes or {}
    return t
end

local function CharRec(create)
    local db = Codex.db
    local key = Codex.Trust and Codex.Trust.SelfKey and Codex.Trust.SelfKey() or nil
    if not db or not key then return nil end
    db.taxiChar = db.taxiChar or {}
    local r = db.taxiChar[key]
    if not r and create ~= false then
        r = { known = {}, spent = 0, trips = 0, log = {} }
        db.taxiChar[key] = r
    end
    return r
end

function Taxi.Money(c)
    c = math.floor(tonumber(c) or 0)
    local g, s, k = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
    local out = {}
    if g > 0 then out[#out + 1] = g .. "g" end
    if s > 0 then out[#out + 1] = s .. "s" end
    if k > 0 or #out == 0 then out[#out + 1] = k .. "c" end
    return table.concat(out, " ")
end

function Taxi.Duration(sec)
    sec = math.floor(tonumber(sec) or 0)
    return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

------------------------------------------------------------------------
-- Abfragen (fuer Karte und Planer)
------------------------------------------------------------------------

Taxi.rev = 0
local merged

-- Eigene und empfangene Routen zusammen (eigene haben Vorrang)
function Taxi.Routes()
    local t = DB()
    if not t then return {} end
    local rem = Codex.db.taxir
    if not rem or next(rem) == nil then return t.routes end
    if merged and merged.rev == Taxi.rev then return merged.routes end
    local out = {}
    for k, r in pairs(rem) do out[k] = r end
    for k, r in pairs(t.routes) do out[k] = r end
    merged = { rev = Taxi.rev, routes = out }
    return out
end

function Taxi.Node(id)
    local t = DB()
    if not t then return nil end
    local n = t.nodes[id]
    if n then return n end
    local rn = Codex.db.taxin
    return rn and rn[id] or nil
end

-- Kennt dieser Charakter den Flugpunkt?
function Taxi.Known(id)
    local c = CharRec(false)
    return c and c.known and c.known[id] and true or false
end

function Taxi.CharStats()
    local c = CharRec(false)
    if not c then return nil end
    local n = 0
    for _ in pairs(c.known or {}) do n = n + 1 end
    return { known = n, spent = c.spent or 0, trips = c.trips or 0, secs = c.secs or 0, log = c.log, routes = c.rt }
end

-- Wie oft dieser Charakter die Route geflogen ist und wie lange insgesamt: n, Sekunden
function Taxi.RouteStat(a, b)
    local c = CharRec(false)
    local r = c and c.rt and c.rt[a .. ">" .. b]
    if not r then return 0, 0 end
    return r.n or 0, r.sec or 0
end

------------------------------------------------------------------------
-- Flugkarte lesen
------------------------------------------------------------------------

local function NodeId(i, world)
    if _G.TaxiNodePosition then
        local ok, x, y = pcall(_G.TaxiNodePosition, i)
        if ok and type(x) == "number" and type(y) == "number" then
            return string.format("%d:%d:%d", world or 0, Round(x * 1000), Round(y * 1000)), x, y
        end
    end
    local name = _G.TaxiNodeName and _G.TaxiNodeName(i)
    if type(name) == "string" and name ~= "" then return "n:" .. name, nil, nil end
    return nil
end

-- Kartenposition des Flugpunkts (Karte, x, y), solange der Spieler dort steht; fuer den Levelplaner
local function SetMapPos(n)
    local loc = FW.Util and FW.Util.GetPlayerLocation and FW.Util.GetPlayerLocation()
    if loc and loc.mapID and loc.x and loc.y and loc.x > 0 and loc.y > 0 then
        if n.m ~= loc.mapID or not n.x then
            n.m, n.x, n.y = loc.mapID, loc.x, loc.y
            return true
        end
    end
    return false
end

function Taxi.Scan()
    local count = _G.NumTaxiNodes and _G.NumTaxiNodes() or 0
    if type(count) ~= "number" or count <= 0 then return end
    local T, C = DB(), CharRec(true)
    if not T or not C then return end
    local P = Codex.Path and Codex.Path.Read and Codex.Path.Read()
    local world = P and P.world or 0
    local nodes = 0
    for _ in pairs(T.nodes) do nodes = nodes + 1 end
    state.slot, state.cur = {}, nil
    local changed = false
    for i = 1, math.min(count, 120) do
        local kind = _G.TaxiNodeGetType and _G.TaxiNodeGetType(i)
        local name = _G.TaxiNodeName and _G.TaxiNodeName(i)
        local id, tx, ty = NodeId(i, world)
        if id then
            local n = T.nodes[id]
            if not n and nodes < MAX_NODES then
                n = {}
                T.nodes[id] = n
                nodes = nodes + 1
            end
            if n then
                if type(name) == "string" and name ~= "" then n.n = name:sub(1, 60) end
                n.w, n.tx, n.ty = world, tx, ty
            end
            if kind ~= "NONE" and not C.known[id] then C.known[id] = true; changed = true end
            if kind == "CURRENT" then
                state.cur = id
                if n and P then n.a, n.b = Round(P.y), Round(P.x) end
                if n and SetMapPos(n) then changed = true end
            end
            local cost = _G.TaxiNodeCost and tonumber(_G.TaxiNodeCost(i)) or nil
            state.slot[i] = { id = id, cost = cost and math.floor(cost) or nil, kind = kind }
        end
    end
    if changed then
        Taxi.rev = Taxi.rev + 1
        FW:Fire("CODEX_TAXI_CHANGED")
    end
    if Taxi.OnOpen then pcall(Taxi.OnOpen) end
end

------------------------------------------------------------------------
-- Teilen (Share/Sync, Datensatzart "f", je Route ein Datensatz)
------------------------------------------------------------------------
-- Zahl zur Route: Flugpunkt-Zahl (Welt, x, y) * 10^7 + Flugpunkt-Zahl des Ziels. Nur Flugpunkte mit Positions-ID sind teilbar.

local NODE_W = 1002001
local SHARE_POINTS = 40

local function NodeNum(id)
    local w, x, y = tostring(id):match("^(%d+):(%d+):(%d+)$")
    w, x, y = tonumber(w), tonumber(x), tonumber(y)
    if not w or w > 8 or x > 1000 or y > 1000 then return nil end
    return w * NODE_W + x * 1001 + y
end

local function NodeFromNum(n)
    if type(n) ~= "number" or n < 0 or n >= 9 * NODE_W then return nil end
    local w, r = math.floor(n / NODE_W), n % NODE_W
    return string.format("%d:%d:%d", w, math.floor(r / 1001), r % 1001)
end

local function RouteNum(a, b)
    local na, nb = NodeNum(a), NodeNum(b)
    if not na or not nb then return nil end
    return na * 10000000 + nb
end

local function RouteIds(num)
    local a, b = NodeFromNum(math.floor(num / 10000000)), NodeFromNum(num % 10000000)
    if not a or not b then return nil end
    return a, b
end

function Taxi.SyncList()
    local out = {}
    local t = DB()
    if not t then return out end
    for _, r in pairs(t.routes) do
        local num = r.upd and RouteNum(r.a, r.b)
        if num then out[#out + 1] = { key = "f" .. string.format("%.0f", num), upd = r.upd } end
    end
    return out
end

local function NodeShare(id)
    local n = Taxi.Node(id) or {}
    return { n = n.n, a = n.a, b = n.b, m = n.m, x = n.x, y = n.y }
end

-- Eigene Route als Datensatz (Strecke auf hoechstens SHARE_POINTS Punkte verkleinert)
function Taxi.RouteRecord(num)
    local a, b = RouteIds(num)
    local t = DB()
    local r = a and t and t.routes[a .. ">" .. b]
    if not r or not r.upd or type(r.p) ~= "table" then return nil end
    local pts, m = {}, math.floor(#r.p / 2)
    if m < 2 then return nil end
    local take = math.min(m, SHARE_POINTS)
    for i = 1, take do
        local j = (take == 1) and 1 or (1 + math.floor((i - 1) * (m - 1) / (take - 1) + 0.5))
        pts[#pts + 1] = r.p[j * 2 - 1]
        pts[#pts + 1] = r.p[j * 2]
    end
    return { t = r.t, c = r.c, n = r.n or 1, p = pts, A = NodeShare(a), B = NodeShare(b) }, r.upd
end

local function NodeFromRecord(id, rn)
    local w, x, y = tostring(id):match("^(%d+):(%d+):(%d+)$")
    return { n = rn.n, w = tonumber(w), tx = tonumber(x) / 1000, ty = tonumber(y) / 1000, a = rn.a, b = rn.b, m = rn.m, x = rn.x, y = rn.y }
end

-- Empfangene Route einmischen. Rueckgabe: true, wenn gespeichert
function Taxi.StoreRemote(rec)
    local db = Codex.db
    if not db or type(rec) ~= "table" then return false end
    local a, b = RouteIds(rec.id)
    if not a then return false end
    db.taxir = db.taxir or {}
    db.taxin = db.taxin or {}
    local rid = a .. ">" .. b
    local old = db.taxir[rid]
    if old and (old.upd or 0) >= rec.upd then return false end
    if not old then
        local count = 0
        for _ in pairs(db.taxir) do count = count + 1 end
        if count >= MAX_ROUTES then return false end
    end
    db.taxir[rid] = { a = a, b = b, t = rec.t, c = rec.c, n = rec.n, p = rec.p, upd = rec.upd }
    local own = DB()
    for id, rn in pairs({ [a] = rec.A, [b] = rec.B }) do
        if not (own and own.nodes[id]) and not db.taxin[id] then
            local nodes = 0
            for _ in pairs(db.taxin) do nodes = nodes + 1 end
            if nodes < MAX_NODES then db.taxin[id] = NodeFromRecord(id, rn) end
        end
    end
    Taxi.rev = Taxi.rev + 1
    return true
end

-- Levelplaner: Fluege als Kanten { id, k, t, wait, from = { m, x, y }, to = { m, x, y } }, nur zwischen Flugpunkten,
-- die dieser Charakter kennt und deren Kartenposition bekannt ist
function Taxi.PlannerOn()
    local db = Codex.db
    return not (db and db.settings and db.settings.taxiPlan == false)
end

-- Namen der Flugpunkte, die dieser Charakter kennt: { [Name] = true }
function Taxi.KnownNames()
    local out = {}
    local c = CharRec(false)
    for id in pairs(c and c.known or {}) do
        local nd = Taxi.Node(id)
        if nd and nd.n then out[nd.n] = true end
    end
    return out
end

local edgeCache

local function PlayerFac()
    local f = _G.UnitFactionGroup and _G.UnitFactionGroup("player")
    return f == "Horde" and "H" or f == "Alliance" and "A" or nil
end

-- Ort eines Flugpunkts fuer den Levelplan: Karte (m, x, y) und/oder Zellraum cs = { Welt, x, y } (Yards)
local function EndPoint(nd, seed)
    local p = {}
    if nd.m and nd.x and nd.y then p.m, p.x, p.y = nd.m, nd.x, nd.y end
    if nd.a and nd.b and nd.w then
        p.cs = { nd.w, nd.b, nd.a }
    elseif seed then
        p.cs = { seed[2], seed[3], seed[4] }
    end
    if not p.m and not p.cs then return nil end
    return p
end

-- Fluege als Kanten { id, k, t, wait, est, from, to }, nur zwischen Flugpunkten, die dieser Charakter kennt.
-- Gemessene Fluege gelten auch rueckwaerts (est = geschaetzt, bis selbst geflogen); dazu das mitgelieferte Flugnetz (Taxi.Seed)
-- fuer Strecken, die noch nie geflogen wurden. Wege ueber mehrere Flugpunkte findet der Levelplan selbst.
function Taxi.Edges()
    if not Taxi.PlannerOn() then return {} end
    local key = Codex.Trust and Codex.Trust.SelfKey and Codex.Trust.SelfKey() or "?"
    if edgeCache and edgeCache.rev == Taxi.rev and edgeCache.key == key then return edgeCache.list end
    local list, have = {}, {}
    local seed = Taxi.Seed
    local fac = PlayerFac()
    local function Add(a, b, t, est)
        local na, nb = Taxi.Node(a), Taxi.Node(b)
        if not (na and nb and t) then return end
        local pa = EndPoint(na, seed and seed.n[na.n])
        local pb = EndPoint(nb, seed and seed.n[nb.n])
        if not (pa and pb) then return end
        have[a .. ">" .. b] = true
        list[#list + 1] = { id = (est and "s" or "f") .. a .. ">" .. b, k = "flight", t = t, wait = 20, est = est or nil, name = nb.n, fn = na.n,
            fa = a, fb = b, from = pa, to = pb }
    end
    for rid, r in pairs(Taxi.Routes()) do
        if r.t and Taxi.Known(r.a) and Taxi.Known(r.b) then Add(r.a, r.b, r.t) end
    end
    for rid, r in pairs(Taxi.Routes()) do
        if r.t and Taxi.Known(r.a) and Taxi.Known(r.b) and not have[r.b .. ">" .. r.a] then Add(r.b, r.a, r.t, true) end
    end
    if seed then
        local c = CharRec(false)
        local byName = {}
        for id in pairs(c and c.known or {}) do
            local nd = Taxi.Node(id)
            if nd and nd.n then byName[nd.n] = id end
        end
        for _, e in ipairs(seed.e) do
            local a, b = byName[e[1]], byName[e[2]]
            if a and b and not have[a .. ">" .. b] then
                local fa, fb = seed.n[e[1]], seed.n[e[2]]
                if not (fac and ((fa and fa[1] and fa[1] ~= fac) or (fb and fb[1] and fb[1] ~= fac))) then Add(a, b, e[3], true) end
            end
        end
    end
    edgeCache = { rev = Taxi.rev, key = key, list = list }
    return list
end

-- Ort eines Flugpunkts (m, x, y und/oder cs) fuer die Wegrechnung; nil, wenn unbekannt
function Taxi.Point(id)
    local nd = Taxi.Node(id)
    if not nd then return nil end
    local seed = Taxi.Seed
    return EndPoint(nd, seed and seed.n[nd.n])
end

-- Geschaetzte Flugzeit (Sekunden) von Flugpunkt a nach b (ids): gemessen, sonst kuerzester Weg im mitgelieferten Netz
-- (ueber Zwischenstationen; das Spiel fliegt sie ohne Halt). nil, wenn nichts bekannt.
local estCache = {}
function Taxi.EstimateSecs(a, b)
    if a == b then return 0 end
    local routes = Taxi.Routes()
    local r = routes[a .. ">" .. b] or routes[b .. ">" .. a]
    if r and r.t then return r.t end
    local na, nb = Taxi.Node(a), Taxi.Node(b)
    local seed = Taxi.Seed
    if not (na and nb and na.n and nb.n and seed) then return nil end
    local c = estCache[na.n]
    if not c or c.rev ~= Taxi.rev then
        local adj = {}
        for _, e in ipairs(seed.e) do
            adj[e[1]] = adj[e[1]] or {}
            adj[e[1]][#adj[e[1]] + 1] = { e[2], e[3] }
        end
        local dist, done = { [na.n] = 0 }, {}
        while true do
            local cur, cd
            for k, d in pairs(dist) do
                if not done[k] and (not cd or d < cd) then cur, cd = k, d end
            end
            if not cur then break end
            done[cur] = true
            for _, e in ipairs(adj[cur] or {}) do
                local nd = cd + e[2]
                if not dist[e[1]] or nd < dist[e[1]] then dist[e[1]] = nd end
            end
        end
        c = { rev = Taxi.rev, dist = dist }
        estCache[na.n] = c
    end
    return c.dist[nb.n]
end

function Taxi.ClearRemote()
    local db = Codex.db
    if db then db.taxir, db.taxin = nil, nil end
    Taxi.rev = Taxi.rev + 1
end

------------------------------------------------------------------------
-- Flug erfassen
------------------------------------------------------------------------

local function OnTake(slot)
    local s = state.slot and state.slot[slot]
    if not s or not state.cur then return end
    state.pending = { from = state.cur, to = s.id, quote = s.cost or 0, money0 = _G.GetMoney and _G.GetMoney() or 0,
        asked = Clock(), started = false }
end

local function Finish(p, now)
    state.pending = nil
    Taxi.flight = nil
    local T, C = DB(), CharRec(true)
    if not T or not C then return end
    local dur = now - p.t0
    if dur < 5 then return end
    -- Endpunkt: Position der Landung
    local P = Codex.Path and Codex.Path.Read and Codex.Path.Read()
    if P then
        p.pts[#p.pts + 1] = Round(P.y)
        p.pts[#p.pts + 1] = Round(P.x)
        local n = T.nodes[p.to]
        if n and not n.a then n.a, n.b = Round(P.y), Round(P.x) end
        if n and not n.m then SetMapPos(n) end
    end
    local paid = p.paid or 0
    if paid <= 0 or paid > p.quote * 3 + 100 then paid = p.quote or 0 end
    local rid = p.from .. ">" .. p.to
    local r = T.routes[rid]
    local isNew = false
    if not r then
        local count = 0
        for _ in pairs(T.routes) do count = count + 1 end
        if count >= MAX_ROUTES then return end
        r = { a = p.from, b = p.to, t = Round(dur), c = paid, n = 1, p = p.pts, upd = Now() }
        T.routes[rid] = r
        isNew = true
    else
        r.n = (r.n or 1) + 1
        r.t = Round((r.t * (r.n - 1) + dur) / r.n)
        r.c = paid
        if #p.pts > #(r.p or {}) then r.p = p.pts end
        r.upd = Now()
    end
    C.known[p.to] = true
    C.spent = (C.spent or 0) + paid
    C.trips = (C.trips or 0) + 1
    C.secs = (C.secs or 0) + Round(dur)
    C.rt = C.rt or {}
    local rs = C.rt[rid]
    if not rs then rs = { n = 0, sec = 0, gold = 0 }; C.rt[rid] = rs end
    rs.n, rs.sec, rs.gold = rs.n + 1, rs.sec + Round(dur), (rs.gold or 0) + paid
    C.log = C.log or {}
    C.log[#C.log + 1] = { t = Now(), a = p.from, b = p.to, c = paid, d = Round(dur) }
    while #C.log > MAX_LOG do table.remove(C.log, 1) end
    if isNew then
        local na, nb = T.nodes[p.from], T.nodes[p.to]
        FW:Print(string.format("Codex: Flugroute %s -> %s gespeichert (%s, %s, %d Punkte)",
            na and na.n or p.from, nb and nb.n or p.to, Taxi.Duration(dur), Taxi.Money(paid), math.floor(#p.pts / 2)))
    end
    Taxi.rev = Taxi.rev + 1
    FW:Fire("CODEX_TAXI_CHANGED")
    FW:Fire("CODEX_CHANGED", "taxi")
end

local function Tick()
    local p = state.pending
    if not p then return end
    local now = Clock()
    local on = _G.UnitOnTaxi and _G.UnitOnTaxi("player") and true or false
    if on and not p.started then
        p.started, p.t0, p.nextAt, p.pts = true, now, now, {}
        local r = Taxi.Routes()[p.from .. ">" .. p.to]
        local nd = Taxi.Node(p.to)
        Taxi.flight = { t0 = now, exp = r and r.t or nil, name = nd and nd.n or "?" }
    end
    if p.started then
        if on then
            if now - p.t0 <= PRICE_WINDOW then
                local d = p.money0 - (_G.GetMoney and _G.GetMoney() or 0)
                if d > (p.paid or 0) then p.paid = d end
            end
            if now >= p.nextAt and #p.pts < MAX_POINTS * 2 then
                local P = Codex.Path and Codex.Path.Read and Codex.Path.Read()
                if P then
                    p.pts[#p.pts + 1] = Round(P.y)
                    p.pts[#p.pts + 1] = Round(P.x)
                end
                p.nextAt = now + SAMPLE
            end
        else
            Finish(p, now)
        end
    elseif now - p.asked > 15 then
        state.pending = nil      -- Flug nicht angetreten
        Taxi.flight = nil
    end
end

local acc = 0
local frame = _G.CreateFrame and _G.CreateFrame("Frame")
if frame then
    frame:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + (elapsed or 0)
        if acc < 1 then return end
        acc = 0
        pcall(Tick)
    end)
end

-- Tooltip am Flugziel auf der Flugkarte: Reisedauer (und wie oft schon geflogen)
function Taxi.ButtonTip(button)
    if not (button and button.GetID and state.cur and state.slot) then return end
    local s = state.slot[button:GetID()]
    local tt = _G.GameTooltip
    if not s or not tt or s.id == state.cur then return end
    local r = Taxi.Routes()[state.cur .. ">" .. s.id]
    local L = FW.L
    if r and r.t then
        tt:AddLine(string.format(L.CODEX_TAXI_TIP_TIME, Taxi.Duration(r.t)), 0.94, 0.75, 0.36)
    else
        tt:AddLine(L.CODEX_TAXI_TIP_NONE, 0.6, 0.59, 0.55)
    end
    local n, sec = Taxi.RouteStat(state.cur, s.id)
    if n > 0 then
        tt:AddLine(string.format(L.CODEX_TAXI_TIP_COUNT, n, Taxi.Duration(sec)), 0.6, 0.59, 0.55)
    end
    tt:Show()
end

local function Install()
    if Taxi.hooked then return end
    Taxi.hooked = true
    if _G.hooksecurefunc and _G.TaxiNodeOnButtonEnter then
        pcall(_G.hooksecurefunc, "TaxiNodeOnButtonEnter", function(button) pcall(Taxi.ButtonTip, button) end)
    end
    if _G.hooksecurefunc and _G.TakeTaxiNode then
        pcall(_G.hooksecurefunc, "TakeTaxiNode", function(slot) pcall(OnTake, slot) end)
    end
    FW:RegisterEvent("TAXIMAP_OPENED", function() pcall(Taxi.Scan) end, Taxi)
end
Install()

------------------------------------------------------------------------
-- /fwtaxi
------------------------------------------------------------------------

SLASH_FREEWOODTAXI1 = "/fwtaxi"
SlashCmdList["FREEWOODTAXI"] = function(arg)
    local T = DB()
    if not T then return end
    local nodes, routes = 0, 0
    for _ in pairs(T.nodes) do nodes = nodes + 1 end
    for _ in pairs(T.routes) do routes = routes + 1 end
    if arg == "diag" then
        FW:Print(string.format("Taxi: TakeTaxiNode=%s TaxiNodePosition=%s TaxiNodeCost=%s TaxiNodeGetType=%s UnitOnTaxi=%s Hook=%s",
            tostring(_G.TakeTaxiNode ~= nil), tostring(_G.TaxiNodePosition ~= nil), tostring(_G.TaxiNodeCost ~= nil),
            tostring(_G.TaxiNodeGetType ~= nil), tostring(_G.UnitOnTaxi ~= nil), tostring(Taxi.hooked)))
        FW:Print(string.format("Taxi: aktueller Punkt=%s, Plaetze=%d, Flug laeuft=%s", tostring(state.cur), state.slot and #state.slot or 0,
            tostring(state.pending and state.pending.started or false)))
        return
    end
    local c = Taxi.CharStats()
    FW:Print(string.format("Taxi: %d Flugpunkte, %d Routen gespeichert.", nodes, routes))
    if c then
        FW:Print(string.format("Taxi: dieser Charakter kennt %d Flugpunkte, %d Fluege, %s ausgegeben, %s in der Luft.", c.known, c.trips, Taxi.Money(c.spent), Taxi.Duration(c.secs)))
    end
    local list = {}
    for _, r in pairs(T.routes) do list[#list + 1] = r end
    table.sort(list, function(x, y) return (x.upd or 0) > (y.upd or 0) end)
    for i = 1, math.min(#list, 5) do
        local r = list[i]
        local na, nb = T.nodes[r.a], T.nodes[r.b]
        FW:Print(string.format("  %s -> %s: %s, %s, %d Punkte, %dx", na and na.n or r.a, nb and nb.n or r.b, Taxi.Duration(r.t), Taxi.Money(r.c),
            math.floor(#(r.p or {}) / 2), r.n or 1))
    end
end
