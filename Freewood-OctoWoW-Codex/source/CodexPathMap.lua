-- Freewood-OctoWoW-Codex: Wegenetz auf der Weltkarte anzeigen (Dev-Reiter, /fwwege).
-- Ebenen: Wege (gruen), Faelle (rot), Gebietsuebergaenge (je Art eine Farbe), Luecken (gelb: bekannte Quest-Geber/-Abgaben und
-- Dienst-NPCs, bei denen noch kein Weg aufgezeichnet ist). Die Welt-Koordinaten des Wegenetzes werden mit drei Messpunkten
-- aus der Kartenschnittstelle in Kartenanteile umgerechnet (die Abbildung ist je Karte linear).

local ADDON, NS = ...

local FW = _G.Freewood
local Codex = NS and NS.Codex
if not FW or not Codex or not Codex.Path then
    return
end

local Path = Codex.Path
local PM = { on = false }
Codex.PathMap = PM

local GRID = Codex.GRID or 200
local CELL = Path.CELL or 10
local BIN = 1 / 300          -- Karten-Anteil je Punkt (Raster der Anzeige)
local MAX_DOTS = 5000
local GAP_RADIUS = 0.012     -- so nah muss ein Weg an einem bekannten Ort liegen, damit er nicht als Luecke zaehlt
local MAX_GAPS = 250
local LAYER_LEVEL = 1400
local PROBE = 100            -- Yards Abstand der Messpunkte fuer die Umrechnung

local COLORS = {
    w = { 0.30, 0.90, 0.40 },   -- Weg
    f = { 0.75, 0.45, 1.00 },   -- Flugroute
    r = { 0.10, 0.35, 1.00 },   -- fremder Weg (empfangen oder aus Startdaten): Blau, auf dem Pergament gut sichtbar
    d = { 1.00, 0.25, 0.20 },   -- Fall
    g = { 1.00, 0.85, 0.10 },   -- Luecke
    lw = { 0.20, 0.80, 1.00 },  -- Grenzuebergang
    lt = { 0.90, 0.30, 0.90 },  -- Sprung (Zeppelin, Portal)
    lf = { 0.60, 0.60, 1.00 },  -- Flugpunkt
    li = { 1.00, 0.60, 0.10 },  -- Instanz
    s = { 1.00, 1.00, 1.00 },   -- Ortspunkt (nur fuer Berechtigte)
}

local function View()
    local db = Codex.db
    db.settings.pathView = db.settings.pathView or {}
    return db.settings.pathView
end

function PM.LayerOn(k)
    local v = View()[k]
    return v ~= false
end

function PM.SetLayer(k, on)
    View()[k] = on and true or false
    PM.Refresh()
end

------------------------------------------------------------------------
-- Umrechnung Welt -> Karte
------------------------------------------------------------------------

local function Vec(a, b)
    return _G.CreateVector2D and _G.CreateVector2D(a, b) or { x = a, y = b, GetXY = function(self) return self.x, self.y end }
end

-- Kartenanteil zu einer Weltposition; first/second wie UnitPosition (erster, zweiter Rueckgabewert)
local function MapPosOf(world, first, second, mapID, swap)
    local CM = _G.C_Map
    if not (CM and CM.GetMapPosFromWorldPos) then return nil end
    local vec = swap and Vec(second, first) or Vec(first, second)
    local ok, id, pos = pcall(CM.GetMapPosFromWorldPos, world, vec, mapID)
    if not ok or not pos or not pos.GetXY then return nil end
    local ok2, x, y = pcall(pos.GetXY, pos)
    if not ok2 or type(x) ~= "number" or type(y) ~= "number" then return nil end
    return x, y
end

local function WorldOfMap(mapID)
    local CM = _G.C_Map
    if not (CM and CM.GetWorldPosFromMapPos) then return nil end
    local ok, cont = pcall(CM.GetWorldPosFromMapPos, mapID, Vec(0.5, 0.5))
    if ok and type(cont) == "number" then return cont end
    return nil
end

local function CellCentre(cx, cy)
    -- Zellen wurden aus x = zweiter, y = erster Rueckgabewert von UnitPosition gebildet
    return (cy + 0.5) * CELL, (cx + 0.5) * CELL   -- first, second
end

local function InMap(x, y)
    return x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1
end

-- Erste Zellen einer Welt (fuer die Messpunkte)
local function SampleCells(cells, n)
    local out = {}
    for key in pairs(cells) do
        out[#out + 1] = key
        if #out >= n then break end
    end
    return out
end

-- Orientierung bestimmen: erst am Spieler (falls er auf der Karte steht), sonst nach der Zahl der Zellen, die auf die Karte fallen
local function DetectSwap(world, cells, mapID)
    local db = Codex.db
    local saved = db.settings.pathSwap
    if type(saved) == "boolean" then return saved end
    local CM = _G.C_Map
    local pos = Path.Read and Path.Read()
    if pos and pos.world == world and CM and CM.GetPlayerMapPosition then
        local ok, mp = pcall(CM.GetPlayerMapPosition, mapID, "player")
        if ok and mp and mp.GetXY then
            local px, py = mp:GetXY()
            local best, bestErr
            for _, swap in ipairs({ false, true }) do
                local x, y = MapPosOf(world, pos.y, pos.x, mapID, swap)
                if x then
                    local err = math.abs(x - px) + math.abs(y - py)
                    if not bestErr or err < bestErr then best, bestErr = swap, err end
                end
            end
            if best ~= nil and bestErr < 0.05 then
                db.settings.pathSwap = best
                return best
            end
        end
    end
    local score = { [false] = 0, [true] = 0 }
    for _, key in ipairs(SampleCells(cells, 40)) do
        local cx, cy = Path.KeyToCell(key)
        local f, s = CellCentre(cx, cy)
        for _, swap in ipairs({ false, true }) do
            local x, y = MapPosOf(world, f, s, mapID, swap)
            if InMap(x, y) then score[swap] = score[swap] + 1 end
        end
    end
    return score[true] > score[false]
end

-- Lineare Abbildung (first, second) -> (x, y) der Karte, aus drei Messpunkten
local function Fit(world, cells, mapID, swap)
    for _, key in ipairs(SampleCells(cells, 60)) do
        local cx, cy = Path.KeyToCell(key)
        local f0, s0 = CellCentre(cx, cy)
        local x0, y0 = MapPosOf(world, f0, s0, mapID, swap)
        if InMap(x0, y0) then
            local x1, y1 = MapPosOf(world, f0 + PROBE, s0, mapID, swap)
            local x2, y2 = MapPosOf(world, f0, s0 + PROBE, mapID, swap)
            if x1 and x2 then
                local a, b, c, d = (x1 - x0) / PROBE, (x2 - x0) / PROBE, (y1 - y0) / PROBE, (y2 - y0) / PROBE
                if a ~= 0 or b ~= 0 or c ~= 0 or d ~= 0 then
                    return function(f, s)
                        return x0 + (f - f0) * a + (s - s0) * b, y0 + (f - f0) * c + (s - s0) * d
                    end
                end
            end
        end
    end
    return nil
end

-- Ersatz, wenn keine der Stichprobenzellen auf der Karte liegt (kleine Karten wie Staedte): Mittelpunkt der Karte
-- in Weltkoordinaten erfragen und die Abbildung dort messen
local function FitFromMap(world, mapID, swap)
    local CM = _G.C_Map
    if not (CM and CM.GetWorldPosFromMapPos) then return nil end
    local ok, cont, wp = pcall(CM.GetWorldPosFromMapPos, mapID, Vec(0.5, 0.5))
    if not ok or cont ~= world or not wp or not wp.GetXY then return nil end
    local ok2, vx, vy = pcall(wp.GetXY, wp)
    if not ok2 or type(vx) ~= "number" or type(vy) ~= "number" then return nil end
    local f0, s0
    if swap then f0, s0 = vy, vx else f0, s0 = vx, vy end
    local x0, y0 = MapPosOf(world, f0, s0, mapID, swap)
    local x1, y1 = MapPosOf(world, f0 + PROBE, s0, mapID, swap)
    local x2, y2 = MapPosOf(world, f0, s0 + PROBE, mapID, swap)
    if not (x0 and x1 and x2) then return nil end
    local a, b, c, d = (x1 - x0) / PROBE, (x2 - x0) / PROBE, (y1 - y0) / PROBE, (y2 - y0) / PROBE
    if a == 0 and b == 0 and c == 0 and d == 0 then return nil end
    return function(f, s)
        return x0 + (f - f0) * a + (s - s0) * b, y0 + (f - f0) * c + (s - s0) * d
    end
end

------------------------------------------------------------------------
-- Daten einer Karte
------------------------------------------------------------------------

-- Rueckgabe: { dots = { { x, y, kind, w } }, counts = { w, d, x, g }, swap }, oder nil, wenn nichts umgerechnet werden kann
function PM.Compute(mapID)
    local db = Codex.db
    if not (db and mapID) then return nil end
    local res = { dots = {}, counts = { w = 0, d = 0, x = 0, g = 0 }, mapID = mapID }
    local world = WorldOfMap(mapID)
    local cells = world and Path.Cells(world)
    local map
    res.world, res.fit, res.ncells = world, "none", 0
    if cells and next(cells) then
        for _ in pairs(cells) do res.ncells = res.ncells + 1 end
        res.swap = DetectSwap(world, cells, mapID)
        map = Fit(world, cells, mapID, res.swap)
        if map then
            res.fit = "cells"
        else
            map = FitFromMap(world, mapID, res.swap)
            if map then res.fit = "map" end
        end
    end
    local bins = {}
    local function Bin(x, y, kind, w)
        local bx, by = math.floor(x / BIN), math.floor(y / BIN)
        local key = by * 100000 + bx
        local b = bins[key]
        if not b then b = { x = x, y = y, kind = kind, w = w }; bins[key] = b
        elseif kind == "d" then b.kind = "d" end
        return b
    end
    local pathHash = {}
    local own = (db.path and db.path[world]) or {}
    if map then
        for key, mask in pairs(cells) do
            local cx, cy = Path.KeyToCell(key)
            local f, s = CellCentre(cx, cy)
            local x, y = map(f, s)
            if InMap(x, y) then
                local isDrop = math.floor(mask / 256) % 256 > 0
                local mine = own[key] ~= nil
                local b = Bin(x, y, isDrop and "d" or (mine and "w" or "r"), 1)
                if b.kind == "r" and mine then b.kind = "w" end      -- eigener Weg geht vor
                if isDrop then res.counts.d = res.counts.d + 1
                elseif mine then res.counts.w = res.counts.w + 1
                else res.counts.r = (res.counts.r or 0) + 1 end
                local hx, hy = math.floor(x / GAP_RADIUS), math.floor(y / GAP_RADIUS)
                pathHash[hy * 100000 + hx] = true
            end
        end
    end
    -- Flugrouten dieser Karte: Strecke als Punktreihe, Beschriftung in der Mitte
    local flights, tags = {}, {}
    local TX = Codex.Taxi
    if map and TX and TX.Routes then
        for _, r in pairs(TX.Routes()) do
            local na, nb = TX.Node(r.a), TX.Node(r.b)
            if na and nb and na.w == world and r.p and #r.p >= 4 then
                local pts = {}
                if na.a then pts[#pts + 1] = { na.a, na.b } end
                for i = 1, #r.p - 1, 2 do pts[#pts + 1] = { r.p[i], r.p[i + 1] } end
                if nb.a then pts[#pts + 1] = { nb.a, nb.b } end
                local xs, ys = {}, {}
                for i, q in ipairs(pts) do xs[i], ys[i] = map(q[1], q[2]) end
                local any = false
                for i = 1, #pts - 1 do
                    local x1, y1, x2, y2 = xs[i], ys[i], xs[i + 1], ys[i + 1]
                    if x1 and x2 and (InMap(x1, y1) or InMap(x2, y2)) then
                        any = true
                        local steps = math.max(1, math.min(40, math.ceil(math.max(math.abs(x2 - x1), math.abs(y2 - y1)) / 0.004)))
                        for k = 0, steps - 1 do
                            local fx, fy = x1 + (x2 - x1) * k / steps, y1 + (y2 - y1) * k / steps
                            if InMap(fx, fy) then flights[#flights + 1] = { x = fx, y = fy, kind = "f", w = 4 } end
                        end
                    end
                end
                if any then
                    local mid = math.max(1, math.floor(#pts / 2))
                    if xs[mid] and InMap(xs[mid], ys[mid]) then
                        tags[#tags + 1] = { x = xs[mid], y = ys[mid],
                            text = string.format("%s > %s  %s  %s", na.n or "?", nb.n or "?", TX.Duration(r.t), TX.Money(r.c)) }
                    end
                end
            end
        end
    end
    res.counts.f = #tags
    res.tags = tags
    -- Luecken: bekannte Orte ohne Weg in der Naehe
    local function NearPath(x, y)
        local hx, hy = math.floor(x / GAP_RADIUS), math.floor(y / GAP_RADIUS)
        for dy = -1, 1 do
            for dx = -1, 1 do
                if pathHash[(hy + dy) * 100000 + hx + dx] then return true end
            end
        end
        return false
    end
    local gaps, seen = {}, {}
    local function Gap(x, y)
        if not x or #gaps >= MAX_GAPS or not InMap(x, y) or NearPath(x, y) then return end
        local k = math.floor(x / GAP_RADIUS) * 100000 + math.floor(y / GAP_RADIUS)
        if seen[k] then return end
        seen[k] = true
        gaps[#gaps + 1] = { x = x, y = y, kind = "g", w = 2 }
    end
    local V = Codex.V and Codex.V()
    for _, q in pairs(V and V.quests or {}) do
        for _, p in ipairs({ q.give, q.turn }) do
            if type(p) == "table" and p.m == mapID then Gap(p.x, p.y) end
        end
    end
    for _, u in pairs(V and V.units or {}) do
        if u.ro and next(u.ro) and u.cells then
            for key in pairs(u.cells) do
                local m = math.floor(key / (GRID * GRID))
                if m == mapID then
                    local idx = key % (GRID * GRID)
                    Gap(((idx % GRID) + 0.5) / GRID, (math.floor(idx / GRID) + 0.5) / GRID)
                    break
                end
            end
        end
    end
    res.counts.g = #gaps
    -- Gebietsuebergaenge dieser Karte
    local crossings = {}
    local function AddLink(a, b, kinds)
        for kind, e in pairs(kinds) do
            for _, p in ipairs(e.p or {}) do
                local key, w
                if a == mapID then key, w = p.fk, p.fw elseif b == mapID then key, w = p.tk, p.tw end
                if key and w == world and map then
                    local cx, cy = Path.KeyToCell(key)
                    local f, s = CellCentre(cx, cy)
                    local x, y = map(f, s)
                    if InMap(x, y) then crossings[#crossings + 1] = { x = x, y = y, kind = "l" .. kind, w = 3, to = a == mapID and b or a } end
                end
            end
        end
    end
    for a, row in pairs(Path.Links()) do
        for b, kinds in pairs(row) do
            if a == mapID or b == mapID then AddLink(a, b, kinds) end
        end
    end
    res.counts.x = #crossings
    -- Ortspunkte dieser Karte (Instanz-Eingaenge, Aufstiege): nur fuer Berechtigte
    local spotDots = {}
    local SP = Codex.Spots
    if SP and Codex.Trust and Codex.Trust.CanEdit() then
        for _, r in ipairs(SP.All()) do
            if r.p.m == mapID and InMap(r.p.x, r.p.y) then
                spotDots[#spotDots + 1] = { x = r.p.x, y = r.p.y, kind = "s", w = 3, name = r.n, sk = r.k }
            end
        end
    end
    res.counts.s = #spotDots
    -- Reihenfolge: Wege unten, dann Faelle, Luecken, Uebergaenge oben
    local list = {}
    for _, b in pairs(bins) do list[#list + 1] = b end
    table.sort(list, function(p, q)
        if p.kind ~= q.kind then
            local rank = { r = 0, w = 1 }
            local a, b2 = rank[p.kind] or 2, rank[q.kind] or 2
            return a < b2
        end
        if p.y ~= q.y then return p.y < q.y end
        return p.x < q.x
    end)
    for _, b in ipairs(list) do res.dots[#res.dots + 1] = b end
    for _, g in ipairs(flights) do res.dots[#res.dots + 1] = g end
    for _, g in ipairs(gaps) do res.dots[#res.dots + 1] = g end
    for _, c in ipairs(crossings) do res.dots[#res.dots + 1] = c end
    for _, c in ipairs(spotDots) do res.dots[#res.dots + 1] = c end
    return res
end

-- Karten, die Daten haben (fuer die Auswahl): { { map, n } } nach Zahl der Uebergaenge
function PM.Maps()
    local db = Codex.db
    local count = {}
    for a, row in pairs(Path.Links()) do
        for b, kinds in pairs(row) do
            local n = 0
            for _, e in pairs(kinds) do n = n + e.n end
            if a > 0 then count[a] = (count[a] or 0) + n end
            if b > 0 then count[b] = (count[b] or 0) + n end
        end
    end
    local cur = _G.C_Map and _G.C_Map.GetBestMapForUnit and select(2, pcall(_G.C_Map.GetBestMapForUnit, "player"))
    if type(cur) == "number" then count[cur] = count[cur] or 0 end
    local out = {}
    for m, n in pairs(count) do out[#out + 1] = { map = m, n = n } end
    table.sort(out, function(x, y)
        if x.n ~= y.n then return x.n > y.n end
        return x.map < y.map
    end)
    return out
end

------------------------------------------------------------------------
-- Anzeige auf der Weltkarte
------------------------------------------------------------------------

local layer, pool, label

local API = Codex.MapAPI

local function Canvas()
    return API.Canvas()
end

local function CurrentMapID()
    return API.CurrentMapID(function()
        local list = {}
        for _, e in ipairs(PM.Maps()) do list[#list + 1] = e.map end
        return list
    end)
end

local function Scale(frame)
    local s = 1
    if frame and frame.GetEffectiveScale and _G.UIParent then
        local a, b = frame:GetEffectiveScale(), _G.UIParent:GetEffectiveScale()
        if type(a) == "number" and type(b) == "number" and a > 0 and b > 0 then s = a / b end
    end
    return s
end

local function EnsureLayer()
    if layer then return layer end
    local wm = _G.WorldMapFrame
    if not (wm and Canvas()) then return nil end
    if API.Classic() then
        local canvas = Canvas()
        layer = CreateFrame("Frame", nil, canvas)
        layer:SetAllPoints(canvas)
        layer:SetFrameLevel((canvas:GetFrameLevel() or 1) + 15)
    else
        layer = CreateFrame("Frame", nil, wm)
        layer:SetAllPoints(wm.ScrollContainer or wm)
        layer:SetFrameLevel((wm:GetFrameLevel() or 1) + LAYER_LEVEL)
    end
    if wm.GetFrameStrata then layer:SetFrameStrata(wm:GetFrameStrata()) end
    if layer.SetClipsChildren then layer:SetClipsChildren(true) end
    pool = {}
    label = layer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", layer, "TOPLEFT", 12, API.Classic() and -42 or -12)
    label:SetJustifyH("LEFT")
    local acc, lastScale, lastMap = 0, nil, nil
    layer:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + (elapsed or 0)
        if acc < 0.3 then return end
        acc = 0
        if not PM.on then return end
        local sc, m = Scale(Canvas()), API.Signature()
        if sc ~= lastScale or m ~= lastMap then
            lastScale, lastMap = sc, m
            PM.Refresh()
        end
    end)
    return layer
end

local function Dot(i)
    local t = pool[i]
    if not t then
        t = layer:CreateTexture(nil, "OVERLAY")
        pool[i] = t
    end
    return t
end

function PM.Refresh()
    if not layer then
        if not PM.on then return end
        EnsureLayer()
    end
    if not layer then return end
    for _, t in ipairs(pool) do t:Hide() end
    for _, t in ipairs(PM.tagPool or {}) do t:Hide() end
    if not PM.on then
        label:SetText("")
        layer:Hide()
        return
    end
    layer:Show()
    local mapID = CurrentMapID()
    local canvas = Canvas()
    if not (mapID and canvas) then
        label:SetText(FW.L.CODEX_PATHMAP_NONE)   -- nicht die Zeile der vorherigen Karte stehen lassen
        return
    end
    local width, height = canvas:GetWidth() or 1, canvas:GetHeight() or 1
    if width < 2 or height < 2 then return end
    local res = PM.Compute(mapID)
    PM.last = res
    local L = FW.L
    if not res or (res.counts.w + (res.counts.f or 0) + (res.counts.r or 0) + res.counts.d + res.counts.x + res.counts.g + (res.counts.s or 0)) == 0 then
        label:SetText(L.CODEX_PATHMAP_NONE)
        return
    end
    label:SetText(string.format(L.CODEX_PATHMAP_LABEL, res.counts.w, res.counts.d, res.counts.x, res.counts.g))
    local scale, layerScale = Scale(canvas), Scale(layer)
    local ratio = scale / layerScale
    PM.drawInfo = { w = width, h = height, scale = scale, layerScale = layerScale, total = #res.dots, drawn = 0, shown = layer:IsShown() and true or false }
    local n = 0
    for _, d in ipairs(res.dots) do
        local show
        if d.kind == "w" then show = PM.LayerOn("w")
        elseif d.kind == "r" then show = PM.LayerOn("r")
        elseif d.kind == "f" then show = PM.LayerOn("f")
        elseif d.kind == "d" then show = PM.LayerOn("d")
        elseif d.kind == "g" then show = PM.LayerOn("g")
        elseif d.kind == "s" then show = PM.LayerOn("s")
        else show = PM.LayerOn("x") end
        if show then
            n = n + 1
            if n > MAX_DOTS then break end
            PM.drawInfo.drawn = n
            local t = Dot(n)
            local px = (d.w == 1 and 3 or (d.w == 4 and 4 or d.w == 2 and 8 or (d.kind == "s" and 14 or 10))) / layerScale
            local c = COLORS[d.kind] or COLORS.w
            t:ClearAllPoints()
            t:SetSize(px, px)
            t:SetPoint("CENTER", canvas, "TOPLEFT", d.x * width * ratio, -d.y * height * ratio)
            t:SetColorTexture(c[1], c[2], c[3], (d.kind == "w" or d.kind == "r") and 0.85 or 1)
            t:Show()
        end
    end
    -- Beschriftung der Flugrouten
    if PM.LayerOn("f") and res.tags then
        PM.tagPool = PM.tagPool or {}
        for i, tg in ipairs(res.tags) do
            if i > 20 then break end
            local fs = PM.tagPool[i]
            if not fs then
                fs = layer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                PM.tagPool[i] = fs
            end
            fs:ClearAllPoints()
            fs:SetPoint("BOTTOM", canvas, "TOPLEFT", tg.x * width * ratio, -tg.y * height * ratio + 4)
            fs:SetText(tg.text)
            fs:SetTextColor(COLORS.f[1], COLORS.f[2], COLORS.f[3])
            fs:Show()
        end
    end
end

-- Weltkarte oeffnen, auf eine Karte stellen (optional) und die Ebenen einblenden
function PM.Show(mapID)
    PM.on = true
    local wm = _G.WorldMapFrame
    if wm then
        if not wm:IsShown() then
            if type(_G.ToggleWorldMap) == "function" then pcall(_G.ToggleWorldMap) elseif wm.Show then pcall(wm.Show, wm) end
        end
        if mapID then API.SetMap(mapID) end
        if not PM.hooked then
            PM.hooked = true
            if wm.OnMapChanged then pcall(_G.hooksecurefunc, wm, "OnMapChanged", function() PM.Refresh() end) end
            if wm.HookScript then wm:HookScript("OnShow", function() PM.Refresh() end) end
            if API.Classic() and _G.hooksecurefunc and _G.SetMapZoom then
                pcall(_G.hooksecurefunc, "SetMapZoom", function() PM.Refresh() end)
            end
        end
    end
    PM.Refresh()
    FW:Fire("CODEX_PATHMAP_CHANGED")
end

function PM.Hide()
    PM.on = false
    PM.Refresh()
    FW:Fire("CODEX_PATHMAP_CHANGED")
end

function PM.Toggle(mapID)
    if PM.on then PM.Hide() else PM.Show(mapID) end
end

-- /fwwege diag: Diagnose fuer die Karte, die gerade angezeigt wird (warum ist das Wegenetz leer?)
function PM.Diag()
    local CM = _G.C_Map
    local mapID = CurrentMapID()
    FW:Print("Wegenetz-Diagnose: Karte " .. tostring(mapID))
    if not mapID then return end
    local info = CM and CM.GetMapInfo and select(2, pcall(CM.GetMapInfo, mapID))
    FW:Print("Name: " .. tostring(type(info) == "table" and info.name or "?") .. ", Eltern-Karte: " .. tostring(type(info) == "table" and info.parentMapID or "?"))
    local ok, cont, wp = false, nil, nil
    if CM and CM.GetWorldPosFromMapPos then ok, cont, wp = pcall(CM.GetWorldPosFromMapPos, mapID, Vec(0.5, 0.5)) end
    local vx, vy
    if ok and wp and wp.GetXY then vx, vy = wp:GetXY() end
    FW:Print(string.format("Kartenmitte in Weltkoordinaten: ok=%s, Welt=%s, x=%s, y=%s", tostring(ok), tostring(cont), tostring(vx), tostring(vy)))
    local res = PM.Compute(mapID)
    if not res then FW:Print("Compute: nil") return end
    FW:Print(string.format("Welt %s, Zellen der Welt: %d, gespeicherte Achsen-Vertauschung: %s, benutzt: %s",
        tostring(res.world), res.ncells or 0, tostring(Codex.db.settings.pathSwap), tostring(res.swap)))
    FW:Print(string.format("Umrechnung: %s (cells = aus Zellen, map = aus Kartenmitte, none = keine)", tostring(res.fit)))
    local di = PM.drawInfo
    if di then
        FW:Print(string.format("Zeichnen: Punkte %d, gezeichnet %d, Flaeche %.0fx%.0f, Skalierung %.2f / Ebene %.2f, Ebene sichtbar %s, an: %s",
            di.total, di.drawn, di.w, di.h, di.scale, di.layerScale, tostring(di.shown), tostring(PM.on)))
    else
        FW:Print("Zeichnen: noch nicht gezeichnet (Wegenetz einschalten mit /fwwege)")
    end
    local flags = {}
    for _, k in ipairs({ "w", "r", "f", "d", "g", "s", "x" }) do flags[#flags + 1] = k .. "=" .. (PM.LayerOn(k) and "an" or "AUS") end
    FW:Print("Ebenen: " .. table.concat(flags, " "))
    local c = res.counts
    FW:Print(string.format("Punkte auf dieser Karte: eigene %d, fremde %d, Beute %d, Uebergaenge %d, Luecken %d, Orte %d",
        c.w or 0, c.r or 0, c.d or 0, c.x or 0, c.g or 0, c.s or 0))
end

SLASH_FREEWOODPATHMAP1 = "/fwwege"
SlashCmdList["FREEWOODPATHMAP"] = function(msg)
    if type(msg) == "string" and msg:lower():match("^%s*diag") then PM.Diag() else PM.Toggle() end
end
