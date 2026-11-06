-- Freewood-OctoWoW-Codex: Karten-Scan (ClassicAPI C_Map, C_TaxiMap)
-- Liest lokal (ohne Serveranfragen) alle Karten, Gebiete, Gebiets-Trigger und Flugpunkte aus dem Client.
-- Ablage in db.cat: m = Karten, a = Gebiete, ma = Gebiete je Karte, t = Trigger je Karte, x = Flugpunkte, shape = Aufbau der Antworten (zur Pruefung)
--   m[id] = "Feld=Wert;...|Name"   a[id] = "Name" (oder "Feld=Wert;...|Name")   t[mapID] = { "Feld=Wert;...", ... }   x[nodeID] = "Feld=Wert;...|Name"

local ADDON, NS = ...

local FW = _G.Freewood
local Codex = NS and NS.Codex
if not FW or not Codex then
    return
end

local Scan = { }
Codex.MapScan = Scan
NS.MapScan = Scan

local MAX_MAP = 2500
local MAX_AREA = 6000
local SLICE = 150          -- Eintraege je Schritt
local TICK = 0.05

local function Say(text) FW:Print("Karten-Scan: " .. text) end

local function Store()
    local db = Codex.db
    if not db then return nil end
    db.cat = db.cat or {}
    local c = db.cat
    c.m = c.m or {}
    c.a = c.a or {}
    c.ma = c.ma or {}
    c.t = c.t or {}
    c.x = c.x or {}
    c.shape = c.shape or {}
    return c
end

local function Clean(t)
    t = tostring(t):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|", "/"):gsub(";", ",")
    return t
end

-- Aufbau einer Antwort als Text (nur die erste Antwort je Funktion), damit man die Felder pruefen kann
local function Describe(v, depth)
    depth = depth or 0
    local tv = type(v)
    if tv ~= "table" then return tv .. (tv == "number" and ("=" .. tostring(v)) or (tv == "string" and ("=" .. v:sub(1, 20)) or "")) end
    if depth >= 2 then return "table" end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for i, k in ipairs(keys) do
        if i > 24 then parts[#parts + 1] = "..." break end
        parts[#parts + 1] = tostring(k) .. ":" .. Describe(v[k], depth + 1)
    end
    return "{" .. table.concat(parts, ", ") .. "}"
end

local function Shape(name, v)
    local c = Store()
    if c and c.shape[name] == nil then c.shape[name] = Describe(v):sub(1, 700) end
end

-- einfache Felder als "Feld=Wert;..." (Zahlen, Wahrheitswerte, Zahlenlisten, x/y-Paare)
local function Pack(info, skip)
    local keys = {}
    for k, v in pairs(info) do
        local tv = type(v)
        if type(k) == "string" and k ~= skip and (tv == "number" or tv == "boolean" or tv == "table") then keys[#keys + 1] = k end
    end
    table.sort(keys)
    local parts = {}
    for _, k in ipairs(keys) do
        local v = info[k]
        if type(v) == "number" then
            parts[#parts + 1] = k .. "=" .. (v == math.floor(v) and string.format("%d", v) or string.format("%.4f", v))
        elseif type(v) == "boolean" then
            parts[#parts + 1] = k .. "=" .. (v and "1" or "0")
        else
            if type(v.x) == "number" and type(v.y) == "number" then
                parts[#parts + 1] = k .. "=" .. string.format("%.4f:%.4f", v.x, v.y)
            else
                local list = {}
                for i = 1, 40 do
                    if type(v[i]) == "number" then list[#list + 1] = tostring(v[i]) else break end
                end
                if #list > 0 then parts[#parts + 1] = k .. "=" .. table.concat(list, ",") end
            end
        end
    end
    return table.concat(parts, ";")
end

local function Name(info)
    if type(info) ~= "table" then return nil end
    local n = info.name or info.areaName or info.mapName
    return type(n) == "string" and n ~= "" and n or nil
end

local function Count(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end

-- Phasen: jede holt Eintraege in Scheiben
local phases = {}

phases[1] = { label = "Karten", total = function() return MAX_MAP end, step = function(c, id)
    local CM = _G.C_Map
    if not (CM and CM.GetMapInfo) then return end
    local ok, info = pcall(CM.GetMapInfo, id)
    if ok and type(info) == "table" then
        local nm = Name(info)
        if nm then
            Shape("GetMapInfo", info)
            c.m[id] = Pack(info, "name") .. "|" .. Clean(nm)
        end
    end
end }

phases[2] = { label = "Gebiete", total = function() return MAX_AREA end, step = function(c, id)
    local CM = _G.C_Map
    if not (CM and CM.GetAreaInfo) then return end
    local ok, r = pcall(CM.GetAreaInfo, id)
    if not ok then return end
    if type(r) == "string" and r ~= "" then
        Shape("GetAreaInfo", r)
        c.a[id] = Clean(r)
    elseif type(r) == "table" and Name(r) then
        Shape("GetAreaInfo", r)
        c.a[id] = Pack(r, "name") .. "|" .. Clean(Name(r))
    end
end }

-- Karten-IDs fuer die Phasen 3 und 4
local mapIDs
local function MapIDs(c)
    if not mapIDs then
        -- Karten aus der Kartenliste plus die Welt-/Instanzkarten (0 bis 700): Trigger und Flugpunkte haengen an der Welt-Karten-ID
        local seen = {}
        mapIDs = {}
        for id = 0, 700 do seen[id] = true mapIDs[#mapIDs + 1] = id end
        for id in pairs(c.m) do
            if type(id) == "number" and not seen[id] then seen[id] = true mapIDs[#mapIDs + 1] = id end
        end
        table.sort(mapIDs)
    end
    return mapIDs
end

phases[3] = { label = "Trigger", total = function() local c = Store() return #MapIDs(c) end, step = function(c, i)
    local CM = _G.C_Map
    local id = MapIDs(c)[i]
    if not (CM and id) then return end
    if CM.GetAreaTriggers then
        local ok, list = pcall(CM.GetAreaTriggers, id)
        if ok and type(list) == "table" and next(list) then
            Shape("GetAreaTriggers", list)
            local rows = {}
            for _, t in pairs(list) do
                if type(t) == "table" then
                    rows[#rows + 1] = Pack(t)
                elseif type(t) == "number" then
                    rows[#rows + 1] = "id=" .. t
                end
            end
            if #rows > 0 then c.t[id] = rows end
        end
    end
    -- Gebiete je Karte (zwei moegliche Funktionen)
    for _, fname in ipairs({ "GetMapAreaIDs", "GetAreas" }) do
        local f = CM[fname]
        if f and not Scan.maDone then
            local ok, list = pcall(f, id)
            if ok and type(list) == "table" and next(list) then
                Shape(fname, list)
                local ids = {}
                for k, v in pairs(list) do
                    if type(v) == "number" then ids[#ids + 1] = v
                    elseif type(v) == "table" then
                        local a = v.areaID or v.id
                        if type(a) == "number" then ids[#ids + 1] = a end
                    elseif type(k) == "number" and type(v) == "string" then ids[#ids + 1] = k end
                end
                table.sort(ids)
                if #ids > 0 then c.ma[0] = table.concat(ids, ",") Scan.maDone = true end
            end
        end
    end
end }

local function TakeNodes(c, list)
    if type(list) ~= "table" then return end
    for _, n in pairs(list) do
        if type(n) == "table" and type(n.nodeID) == "number" then
            Shape("TaxiNode", n)
            c.x[n.nodeID] = Pack(n, "name") .. "|" .. Clean(Name(n) or "")
        end
    end
end

phases[4] = { label = "Flugpunkte", total = function() local c = Store() return #MapIDs(c) + 1 end, step = function(c, i)
    local T = _G.C_TaxiMap
    if not T then return end
    local ids = MapIDs(c)
    if i == 1 and T.GetAllTaxiNodes then
        local ok, list = pcall(T.GetAllTaxiNodes)
        if ok then TakeNodes(c, list) end
    end
    local id = ids[i - 1]
    if id and T.GetAllTaxiNodes then
        local ok, list = pcall(T.GetAllTaxiNodes, id)
        if ok then TakeNodes(c, list) end
    end
    if id and T.GetTaxiNodesForMap then
        local ok, list = pcall(T.GetTaxiNodesForMap, id)
        if ok then TakeNodes(c, list) end
    end
end }

Scan.state = nil

function Scan.Counts()
    local c = Codex.db and Codex.db.cat
    if not c then return 0, 0, 0, 0 end
    return Count(c.m), Count(c.a), Count(c.t), Count(c.x)
end

function Scan.Running() return Scan.state ~= nil and not Scan.state.stop end

local function Tick(st)
    if Scan.state ~= st then return end
    if st.stop then Scan.state = nil return end
    local c = Store()
    local ph = phases[st.phase]
    if not (c and ph) then Scan.state = nil return end
    local total = ph.total()
    local last = math.min(st.i + SLICE - 1, total)
    for i = st.i, last do
        local ok = pcall(ph.step, c, i)
        if not ok then st.errors = (st.errors or 0) + 1 end
    end
    st.i = last + 1
    st.total = total
    if st.i > total then
        Say(string.format("%s fertig.", ph.label))
        if st.phase == 1 then mapIDs = nil end
        st.phase = st.phase + 1
        st.i = 1
        if not phases[st.phase] then
            local m, a, t, x = Scan.Counts()
            Say(string.format("fertig: %d Karten, %d Gebiete, Trigger auf %d Karten, %d Flugpunkte%s.", m, a, t, x,
                st.errors and (" (" .. st.errors .. " Fehler)") or ""))
            Scan.state = nil
            if FW.Fire then FW:Fire("CODEX_CHANGED", "mapscan") end
            return
        end
    end
    _G.C_Timer.After(TICK, function() Tick(st) end)
end

-- Rueckgabe: true | false, Grund
function Scan.Start()
    if Scan.state then return false, "busy" end
    local CM = _G.C_Map
    if not (CM and CM.GetMapInfo) or not _G.C_Timer then return false, "api" end
    if not Store() then return false, "db" end
    mapIDs = nil
    Scan.maDone = false
    local st = { phase = 1, i = 1, total = MAX_MAP }
    Scan.state = st
    Tick(st)
    return true
end

function Scan.Stop()
    if Scan.state then Scan.state.stop = true end
end

function Scan.Label()
    local st = Scan.state
    if not st then return nil end
    return phases[st.phase] and phases[st.phase].label or "", math.min(st.i, st.total or 1), st.total or 1
end

SLASH_FREEWOODMAPSCAN1 = "/fwkarte"
SlashCmdList["FREEWOODMAPSCAN"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "stop" then
        if Scan.Running() then Scan.Stop() Say("wird angehalten.") else Say("es laeuft nichts.") end
        return
    elseif msg == "status" then
        local m, a, t, x = Scan.Counts()
        Say(string.format("%d Karten, %d Gebiete, Trigger auf %d Karten, %d Flugpunkte.", m, a, t, x))
        return
    end
    local ok, why = Scan.Start()
    if ok then
        Say("gestartet (Karten, Gebiete, Trigger, Flugpunkte; lokal, ohne Serveranfragen). Anhalten: /fwkarte stop.")
    elseif why == "busy" then
        Say("es laeuft schon ein Scan.")
    else
        Say("nicht moeglich: " .. tostring(why))
    end
end
