-- Freewood-OctoWoW-Codex: Kartenschnittstelle fuer die Weltkarte des 1.12-Clients (OctoWoW).
-- Die alte Karte kennt weder SetMapID noch GetMapID noch eine Kartenflaeche mit Zoom. Stattdessen:
--   Kartenflaeche = WorldMapDetailFrame (Anteile 0..1 von links oben), Zone umschalten per SetMapZoom(Kontinent, Zone).
-- Die Zuordnung Karten-ID (AreaTable) -> Kontinent/Zone laeuft ueber den Zonennamen (C_Map.GetMapInfo gegen GetMapZones)
-- und wird zusaetzlich beim Spielen gelernt (stehst du in einer Zone, merkt sich Codex ihre Nummer).
-- Auf Clients mit Retail-Karte (SetMapID/GetMapID) werden diese Funktionen direkt benutzt.

local ADDON, NS = ...

local FW = _G.Freewood
local Codex = NS and NS.Codex
if not FW or not Codex then
    return
end

local API = {}
Codex.MapAPI = API

local resolved = {}    -- [mapID] = "c:z" oder false (nicht gefunden)
local zoneToID = {}    -- ["c:z"] = mapID

local function Learned()
    local st = Codex.db and Codex.db.settings
    if not st then return {} end
    st.mapZones = st.mapZones or {}
    return st.mapZones
end

local function Norm(s)
    if type(s) ~= "string" then return nil end
    s = string.gsub(string.lower(s), "[^%w]", "")
    if s == "" then return nil end
    return s
end

function API.Classic()
    local wm = _G.WorldMapFrame
    return not (wm and wm.GetMapID and wm.SetMapID)
end

function API.Canvas()
    local wm = _G.WorldMapFrame
    if not wm then return nil end
    if not API.Classic() then
        if wm.GetCanvas then
            local ok, c = pcall(wm.GetCanvas, wm)
            if ok and c then return c end
        end
        return wm.ScrollContainer and wm.ScrollContainer.Child or nil
    end
    return _G.WorldMapDetailFrame or _G.WorldMapButton
end

-- Kontinent/Zone der angezeigten Karte
function API.Current()
    if not (_G.GetCurrentMapContinent and _G.GetCurrentMapZone) then return nil end
    local c, z = _G.GetCurrentMapContinent(), _G.GetCurrentMapZone()
    if type(c) ~= "number" or type(z) ~= "number" then return nil end
    return c, z
end

function API.Signature()
    local c, z = API.Current()
    return c and (c .. ":" .. z) or "?"
end

local function MapName(id)
    local CM = _G.C_Map
    if CM and CM.GetMapInfo then
        local ok, info = pcall(CM.GetMapInfo, id)
        if ok and type(info) == "table" and type(info.name) == "string" then return info.name end
    end
    if _G.C_Map and _G.C_Map.GetAreaInfo then
        local ok, name = pcall(_G.C_Map.GetAreaInfo, id)
        if ok and type(name) == "string" then return name end
    end
    return nil
end

-- Karten-ID -> Kontinent, Zone (Zone 0 = Kontinentkarte)
function API.Resolve(id)
    if type(id) ~= "number" then return nil end
    local key = Learned()[id] or resolved[id]
    if key == nil then
        key = false
        local want = Norm(MapName(id))
        if want and _G.GetMapContinents and _G.GetMapZones then
            local conts = { _G.GetMapContinents() }
            for c = 1, #conts do
                if Norm(conts[c]) == want then key = c .. ":0" break end
                local zones = { _G.GetMapZones(c) }
                for z = 1, #zones do
                    if Norm(zones[z]) == want then key = c .. ":" .. z break end
                end
                if key then break end
            end
        end
        resolved[id] = key
    end
    if not key then return nil end
    local _, _, c, z = string.find(key, "^(%d+):(%d+)$")
    return tonumber(c), tonumber(z)
end

-- Karten-ID der angezeigten Karte. cands: Liste oder Funktion, die Karten-IDs liefert, unter denen gesucht wird.
function API.CurrentMapID(cands)
    local wm = _G.WorldMapFrame
    if not API.Classic() then
        if wm and wm.GetMapID then
            local ok, id = pcall(wm.GetMapID, wm)
            if ok then return id end
        end
        return nil
    end
    local c, z = API.Current()
    if not c then return nil end
    local key = c .. ":" .. z
    if zoneToID[key] then return zoneToID[key] end
    for id, k in pairs(Learned()) do
        if k == key then zoneToID[key] = id return id end
    end
    if type(cands) == "function" then cands = cands() end
    local list = cands or {}
    local bm = _G.C_Map and _G.C_Map.GetBestMapForUnit and select(2, pcall(_G.C_Map.GetBestMapForUnit, "player"))
    if type(bm) == "number" then list[#list + 1] = bm end
    for i = 1, #list do
        local id = list[i]
        local rc, rz = API.Resolve(id)
        if rc == c and rz == z then
            zoneToID[key] = id
            return id
        end
    end
    -- Zone ohne bekannte Daten (und noch nie betreten): Karten-ID ueber den Zonennamen suchen.
    -- Quelle: zuerst der Karten-Scan (db.cat.m), dann alle Nummern 1..8000 durchprobieren. Ergebnis wird gemerkt (auch dauerhaft),
    -- ein Fehlschlag fuer 60 Sekunden.
    local now = _G.GetTime and _G.GetTime() or 0
    if API.noMatch and API.noMatch[key] and now - API.noMatch[key] < 60 then return nil end
    local zname
    if _G.GetMapContinents and _G.GetMapZones then
        if z == 0 then zname = ({ _G.GetMapContinents() })[c] else zname = ({ _G.GetMapZones(c) })[z] end
    end
    local target = Norm(zname)
    if target then
        local ids = {}
        local m = Codex.db and Codex.db.cat and Codex.db.cat.m
        -- erst die Karten aus dem Scan (schnell), dann der ganze Bereich: der Scan kennt nicht jede Karte (z. B. Blackstone Island)
        local seen = {}
        if type(m) == "table" then
            for id in pairs(m) do if type(id) == "number" then ids[#ids + 1] = id; seen[id] = true end end
            table.sort(ids)
        end
        for id = 1, 8000 do if not seen[id] then ids[#ids + 1] = id end end
        for i = 1, #ids do
            local id = ids[i]
            if Norm(MapName(id)) == target then
                zoneToID[key] = id
                resolved[id] = key
                Learned()[id] = key
                return id
            end
        end
    end
    API.noMatch = API.noMatch or {}
    API.noMatch[key] = now
    return nil
end

-- Blizzards Kartenfenster (Titel, Auswahlfelder) nachziehen, falls es die Umschaltung nicht selbst tut
function API.RefreshWindow(c, z)
    local names = { "WorldMapFrame_Update", "WorldMapContinentDropDown_Update", "WorldMapZoneDropDown_Update", "WorldMapZoomOutButton_Update" }
    for i = 1, #names do
        local f = _G[names[i]]
        if type(f) == "function" then pcall(f) end
    end
    local title = _G.WorldMapFrameTitle or _G.WorldMapFrameTitleText
    if title and title.SetText and _G.GetMapZones and _G.GetMapContinents then
        local name
        if z == 0 then
            local conts = { _G.GetMapContinents() }
            name = conts[c]
        else
            local zones = { _G.GetMapZones(c) }
            name = zones[z]
        end
        if name then pcall(title.SetText, title, name) end
    end
end

function API.SetMap(id)
    local wm = _G.WorldMapFrame
    if not API.Classic() then
        if wm and wm.SetMapID then pcall(wm.SetMapID, wm, id) return true end
        return false
    end
    local c, z = API.Resolve(id)
    if not c or not _G.SetMapZoom then return false end
    if z == 0 then pcall(_G.SetMapZoom, c) else pcall(_G.SetMapZoom, c, z) end
    API.RefreshWindow(c, z)
    if _G.C_Timer and _G.C_Timer.After then
        _G.C_Timer.After(0.2, function() API.RefreshWindow(c, z) end)
    end
    return true
end

-- Mauszeiger auf der Kartenflaeche als Anteil 0..1 (links oben), sonst nil
function API.CursorNorm()
    local canvas = API.Canvas()
    if not (canvas and canvas.IsVisible and canvas:IsVisible()) then return nil end
    local l, t, w, h = canvas:GetLeft(), canvas:GetTop(), canvas:GetWidth(), canvas:GetHeight()
    if not (l and t and w and h and w > 1 and h > 1) then return nil end
    local cx, cy = _G.GetCursorPosition()
    local s = canvas:GetEffectiveScale()
    if not (cx and s and s > 0) then return nil end
    local x, y = (cx / s - l) / w, (t - cy / s) / h
    if x < 0 or x > 1 or y < 0 or y > 1 then return nil end
    return x, y
end

-- Zonen-Nummern lernen: Karte kurz auf die aktuelle Zone stellen, solange das Kartenfenster zu ist
local function LearnHere()
    local wm = _G.WorldMapFrame
    if not API.Classic() or (wm and wm:IsShown()) then return end
    if not (_G.SetMapToCurrentZone and _G.C_Map and _G.C_Map.GetBestMapForUnit) then return end
    local ok, id = pcall(_G.C_Map.GetBestMapForUnit, "player")
    if not ok or type(id) ~= "number" then return end
    pcall(_G.SetMapToCurrentZone)
    local c, z = API.Current()
    if c and z and z > 0 then
        local L = Learned()
        L[id] = c .. ":" .. z
        zoneToID[c .. ":" .. z] = id
    end
end

local function LearnLater()
    if _G.C_Timer and _G.C_Timer.After then
        _G.C_Timer.After(1.5, LearnHere)
    else
        LearnHere()
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:SetScript("OnEvent", LearnLater)

-- /fwcodex mapzones: zeigt die Zuordnung fuer die angezeigte Karte
function API.Debug()
    local c, z = API.Current()
    FW:Print("Karte: Kontinent " .. tostring(c) .. ", Zone " .. tostring(z) .. ", Flaeche "
        .. tostring(API.Canvas() and API.Canvas():GetName()) .. ", klassisch: " .. tostring(API.Classic()))
    local n = 0
    for id, k in pairs(Learned()) do n = n + 1 end
    FW:Print("Gelernte Zonen: " .. n)
end
