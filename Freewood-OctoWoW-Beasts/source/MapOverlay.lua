-- Freewood-OctoWoW-Beasts: Gebiete auf der Weltkarte
-- Zeichnet weiche grüne Flecken ueber die Kartenflaeche, dort wo Tiere gefunden wurden.
-- (Blizzards blaue Quest-Gebiete kommen aus der Engine und gehen nur fuer Quests; hier wird
-- deshalb auf Blizzards Kartenflaeche mit eigenen Texturen gezeichnet.)

local ADDON, NS = ...

local FW = _G.Freewood
local Beasts = NS.Beasts
if not FW or not Beasts then
    return
end

local UI = FW.UI
local MAX_BLOBS = 1500
local BLOB_SIZE = 0.05
local BIN = 3         -- Zellen je Fleck (3 Zellen = 1,5 % der Karte)   -- Durchmesser eines Flecks als Anteil der Kartenbreite

local Overlay = { ids = nil, label = nil, hooked = false }
NS.MapOverlay = Overlay

local layer, textures, infoButton, lessButton, moreButton, StartHover

-- Fleck: weicher Kreis aus eigener Bilddatei. Neue Dateien kennt das Spiel erst nach einem
-- kompletten Neustart; bis dahin gibt es eckige Kaestchen als Notloesung.
local TEXTURE = "Interface\\AddOns\\Freewood-OctoWoW-Beasts\\Textures\\Blob.tga"
local warned = false

local function TextureAvailable()
    if type(GetFileIDFromPath) == "function" then
        return GetFileIDFromPath(TEXTURE) ~= nil
    end
    return true
end

local function StyleBlob(tex, available)
    if available then
        tex:SetTexture(TEXTURE)
    else
        tex:SetColorTexture(1, 1, 1, 1)
    end
end

local function Canvas()
    local wm = _G.WorldMapFrame
    if not wm then
        return nil
    end
    if wm.GetCanvas then
        local ok, c = pcall(wm.GetCanvas, wm)
        if ok and c then
            return c
        end
    end
    return wm.ScrollContainer and wm.ScrollContainer.Child or nil
end

local function EnsureLayer()
    if layer then
        return layer
    end
    local canvas = Canvas()
    if not canvas then
        return nil
    end
    layer = CreateFrame("Frame", nil, canvas)
    layer:SetAllPoints(canvas)
    layer:SetFrameLevel((canvas:GetFrameLevel() or 1) + 400)
    if _G.WorldMapFrame and _G.WorldMapFrame.GetFrameStrata then
        layer:SetFrameStrata(_G.WorldMapFrame:GetFrameStrata())
    end
    layer:SetScript("OnSizeChanged", function(_, w, h)
        if w and w > 1 and Overlay.ids then
            Overlay:Refresh()
        end
    end)
    textures = {}
    StartHover(layer)
    return layer
end

local function EnsureInfoButton()
    if infoButton then
        return infoButton
    end
    local wm = _G.WorldMapFrame
    if not wm then
        return nil
    end
    infoButton = UI.CreateButton(wm, "", 300, 22, function()
        Overlay:Clear()
    end, "default")
    infoButton:SetFrameStrata("HIGH")
    infoButton:SetFrameLevel((wm:GetFrameLevel() or 1) + 60)
    local anchor = wm.ScrollContainer or wm
    infoButton:SetPoint("TOPLEFT", anchor, "TOPLEFT", 12, -12)
    infoButton:Hide()

    local function change(delta)
        local settings = Beasts.db.settings
        local value = (settings.mapPower or 1.0) + delta
        settings.mapPower = math.max(0.25, math.min(3, value))
        Overlay:Refresh()
    end
    lessButton = UI.CreateButton(wm, "-", 24, 22, function() change(-0.25) end, "default")
    moreButton = UI.CreateButton(wm, "+", 24, 22, function() change(0.25) end, "default")
    for _, b in ipairs({ lessButton, moreButton }) do
        b:SetFrameStrata("HIGH")
        b:SetFrameLevel((wm:GetFrameLevel() or 1) + 60)
        b:Hide()
    end
    lessButton:SetPoint("LEFT", infoButton, "RIGHT", 6, 0)
    moreButton:SetPoint("LEFT", lessButton, "RIGHT", 4, 0)
    return infoButton
end

local function CurrentMapID()
    local wm = _G.WorldMapFrame
    if wm and wm.GetMapID then
        local ok, id = pcall(wm.GetMapID, wm)
        if ok then
            return id
        end
    end
    return nil
end

-- Alles neu zeichnen
function Overlay:Refresh()
    local f = EnsureLayer()
    if not f then
        return
    end
    for _, t in ipairs(textures) do
        t:Hide()
    end
    local btn = EnsureInfoButton()
    if not self.ids or not next(self.ids) then
        if btn then
            btn:Hide()
            lessButton:Hide()
            moreButton:Hide()
        end
        return
    end
    if btn then
        lessButton:Show()
        moreButton:Show()
        btn:SetLabel(string.format(FW.L.BEAST_MAP_LABEL, self.label or ""))
        btn:SetWidth(math.max(200, (btn.label:GetStringWidth() or 200) + 24))
        btn:Show()
    end

    local mapID = CurrentMapID()
    if not mapID then
        return
    end
    local weights = Beasts:MapWeights(self.ids, mapID)
    local canvas = Canvas() or f
    local width, height = canvas:GetWidth() or 1, canvas:GetHeight() or 1
    local grid = Beasts.GRID
    if width < 2 or height < 2 then
        -- Karte noch nicht eingerichtet (Groesse 0): spaeter noch einmal, nie durch 0 teilen
        self.lastDraw = { mapID = mapID, width = width, height = height, waiting = true }
        if _G.C_Timer and not self.retrying then
            self.retrying = true
            _G.C_Timer.After(0.2, function()
                Overlay.retrying = false
                if Overlay.ids then
                    Overlay:Refresh()
                end
            end)
        end
        return
    end

    -- Fundorte zu Feldern zusammenfassen: je BIN x BIN Zellen ein Fleck (Mittelpunkt der Funde),
    -- die Flecken sind gross genug, dass Nachbarn zu einer Flaeche verschmelzen
    local bins, nbins, ncells = {}, 0, 0
    for idx in pairs(weights) do
        ncells = ncells + 1
        local cx = idx % grid
        local cy = math.floor(idx / grid)
        local key = math.floor(cy / BIN) * 1000 + math.floor(cx / BIN)
        local b = bins[key]
        if not b then
            b = { sx = 0, sy = 0, n = 0 }
            bins[key] = b
            nbins = nbins + 1
        end
        b.sx, b.sy, b.n = b.sx + cx + 0.5, b.sy + cy + 0.5, b.n + 1
    end

    -- Mindestgroesse in Bildschirm-Pixeln, umgerechnet auf die Einheiten der Kartenflaeche
    local scale = self:CanvasScale()
    local minSize = (Beasts.db.settings.mapMinSize or 32) / scale
    local size = math.max(minSize * 1.5, width * BLOB_SIZE)
    self.hoverRadius = math.max(1, math.floor(size / 2 / width * grid * 0.8))
    self.lastScale = scale

    local available = TextureAvailable()
    if not available and not warned then
        warned = true
        FW:Print(FW.L.BEAST_MAP_RESTART)
    end
    self.lastDraw = { mapID = mapID, cells = ncells, blobs = nbins, size = size, width = width, height = height, texture = available }
    self.drawnMap = mapID
    local alpha = math.min(1, 0.85 * (Beasts.db.settings.mapPower or 1.0))
    -- Der Rand der Bilddatei laeuft weich aus; damit auch ein einzelner Fundort deutlich zu sehen ist,
    -- wird jeder Fleck zweimal gelegt (aussen gross, innen kleiner = kraeftiger Kern)
    local i = 0
    for _, b in pairs(bins) do
        if i >= MAX_BLOBS then
            break
        end
        i = i + 1
        local x = (b.sx / b.n) / grid * width
        local y = -(b.sy / b.n) / grid * height
        for layerNo = 1, 2 do
            local k = i * 2 - 2 + layerNo
            local tex = textures[k]
            if not tex then
                tex = f:CreateTexture(nil, "OVERLAY")
                StyleBlob(tex, available)
                textures[k] = tex
            elseif tex.available ~= available then
                StyleBlob(tex, available)
            end
            tex.available = available
            local d = layerNo == 1 and size or size * 0.6
            tex:ClearAllPoints()
            tex:SetSize(d, d)
            tex:SetPoint("CENTER", f, "TOPLEFT", x, y)
            tex:SetVertexColor(0.1, 1.0, 0.3, alpha)
            tex:Show()
        end
    end
end

-- Faktor Kartenflaeche -> Bildschirm (aendert sich beim Zoomen)
function Overlay:CanvasScale()
    local canvas = Canvas()
    local s = 1
    if canvas and canvas.GetEffectiveScale and _G.UIParent then
        local a, b = canvas:GetEffectiveScale(), _G.UIParent:GetEffectiveScale()
        if type(a) == "number" and type(b) == "number" and b > 0 and a > 0 then
            s = a / b
        end
    end
    return s
end

-- Mouseover: welche Tiere wurden in der Naehe des Mauszeigers gefunden

local function MouseOverMap()
    local wm = _G.WorldMapFrame
    local sc = wm and wm.ScrollContainer
    if type(sc) ~= "table" or type(sc.GetNormalizedCursorPosition) ~= "function" then
        return nil
    end
    local focus
    if GetMouseFoci then
        focus = GetMouseFoci()
        focus = focus and focus[1]
    elseif GetMouseFocus then
        focus = GetMouseFocus()
    end
    -- nur wenn der Zeiger ueber der Karte (oder einem Kartensymbol) ist, nicht ueber Fenstern davor
    local f, ok = focus, (focus == nil)
    local depth = 0
    while f and depth < 12 do
        if f == sc then
            ok = true
            break
        end
        f = f.GetParent and f:GetParent() or nil
        depth = depth + 1
    end
    if not ok then
        return nil
    end
    local x, y = sc:GetNormalizedCursorPosition()
    if not x or x < 0 or x > 1 or y < 0 or y > 1 then
        return nil
    end
    return x, y
end

function Overlay:UpdateHover()
    if not self.ids or not self.drawnMap then
        return self:HideHover()
    end
    local x, y = MouseOverMap()
    if not x then
        return self:HideHover()
    end
    local grid = Beasts.GRID
    local cx = math.min(grid - 1, math.floor(x * grid))
    local cy = math.min(grid - 1, math.floor(y * grid))
    local key = cy * grid + cx
    if key == self.hoverKey and self.hoverShown ~= nil then
        return
    end
    self.hoverKey = key
    local hits = Beasts:BeastsAt(self.ids, self.drawnMap, cx, cy, self.hoverRadius or 3)
    if #hits == 0 then
        return self:HideHover()
    end
    local tip = _G.GameTooltip
    tip:SetOwner(_G.WorldMapFrame, "ANCHOR_CURSOR")
    tip:AddLine(FW.L.BEAST_HOVER_TITLE, 0.94, 0.75, 0.36)
    local shown = 0
    for _, h in ipairs(hits) do
        if shown >= 12 then
            break
        end
        shown = shown + 1
        local sm = Beasts:Summary(h.id)
        local left = sm.name
        local lvl = sm.lvl1 and (sm.lvl2 and sm.lvl2 ~= sm.lvl1 and (sm.lvl1 .. "-" .. sm.lvl2) or tostring(sm.lvl1)) or nil
        local right = {}
        if sm.family and sm.family ~= "" then right[#right + 1] = sm.family end
        if lvl then right[#right + 1] = string.format(FW.L.BEAST_HOVER_LEVEL, lvl) end
        local counts = {}
        if h.own > 0 then counts[#counts + 1] = string.format(FW.L.BEAST_HOVER_OWN, h.own) end
        if h.imp > 0 then counts[#counts + 1] = string.format(FW.L.BEAST_HOVER_IMPORTED, h.imp) end
        if h.seed > 0 then counts[#counts + 1] = string.format(FW.L.BEAST_HOVER_SEED, h.seed) end
        tip:AddDoubleLine(left, table.concat(right, ", "), 0.42, 0.75, 0.44, 0.8, 0.8, 0.8)
        if #counts > 0 then
            tip:AddLine("   " .. table.concat(counts, "  |  "), 0.65, 0.65, 0.65)
        end
    end
    if #hits > shown then
        tip:AddLine(string.format(FW.L.BEAST_HOVER_MORE, #hits - shown), 0.8, 0.8, 0.8)
    end
    tip:Show()
    self.hoverShown = true
end

function Overlay:HideHover()
    self.hoverKey = nil
    if self.hoverShown then
        self.hoverShown = nil
        local tip = _G.GameTooltip
        if tip:GetOwner() == _G.WorldMapFrame then
            tip:Hide()
        end
    end
end

local hoverElapsed = 0
StartHover = function(f)
    f:SetScript("OnUpdate", function(_, elapsed)
        hoverElapsed = hoverElapsed + elapsed
        if hoverElapsed < 0.08 then
            return
        end
        hoverElapsed = 0
        if Overlay.ids then
            local sc = Overlay:CanvasScale()
            if Overlay.lastScale and math.abs(sc - Overlay.lastScale) > 0.01 then
                Overlay:Refresh()
            end
            Overlay:UpdateHover()
        end
    end)
end

-- Mit den Karten-Ereignissen von Blizzard verbinden (einmalig, spaeter erneut versuchbar)
function Overlay:Hook()
    if self.hooked then
        return true
    end
    local wm = _G.WorldMapFrame
    if not wm or not Canvas() then
        return false
    end
    self.hooked = true
    if wm.OnMapChanged then
        pcall(hooksecurefunc, wm, "OnMapChanged", function()
            Overlay:Refresh()
        end)
    end
    if wm.HookScript then
        wm:HookScript("OnShow", function()
            Overlay:Refresh()
        end)
    end
    return true
end

-- ids: { [npcID] = true } oder nil, label: Text fuers Knopfchen auf der Karte
function Overlay:SetTargets(ids, label)
    self.ids = ids
    self.label = label
    self:Hook()
    self:Refresh()
    FW:Fire("BEASTS_MAP_CHANGED")
end

function Overlay:Clear()
    self:HideHover()
    self.mode = nil
    self.singleID = nil
    self:SetTargets(nil, nil)
end

function Overlay:IsShowing(id)
    return self.mode == "single" and self.singleID == id
end

-- Karten-IDs mit Zellenzahl fuer eine Menge Tiere
function Overlay:MapCounts(ids)
    local counts = {}
    for id in pairs(ids) do
        local own, imp, seed = Beasts.db.beasts[id], Beasts.db.imported[id], Beasts:SeedEntry(id)
        for _, e in ipairs({ own or false, imp or false }) do
            for m, cells in pairs(e and e.grid or {}) do
                for _ in pairs(cells) do
                    counts[m] = (counts[m] or 0) + 1
                end
            end
        end
        if seed and seed.m and seed.p then
            counts[seed.m] = (counts[seed.m] or 0) + math.floor(#seed.p / 2)
        end
    end
    return counts
end

-- Weltkarte oeffnen und auf ein passendes Gebiet stellen: erst das gewuenschte, dann das
-- aktuelle (wenn es Daten hat), sonst das Gebiet mit den meisten Fundorten
function Overlay:Focus(preferMap)
    local wm = _G.WorldMapFrame
    if not wm or not self.ids then
        return
    end
    local counts = self:MapCounts(self.ids)
    local target
    if preferMap and counts[preferMap] then
        target = preferMap
    else
        local current = CurrentMapID()
        if current and counts[current] then
            target = current
        else
            local best = 0
            for m, n in pairs(counts) do
                if n > best or (n == best and target and m < target) then
                    best, target = n, m
                end
            end
        end
    end
    if not wm:IsShown() then
        if type(ToggleWorldMap) == "function" then
            pcall(ToggleWorldMap)
        else
            pcall(wm.Show, wm)
        end
    end
    if target and wm.SetMapID and target ~= CurrentMapID() then
        pcall(wm.SetMapID, wm, target)
    end
    self:Refresh()
    return target
end

-- Ein einzelnes Tier
function Overlay:ShowSingle(id, name)
    self.mode = "single"
    self.singleID = id
    self:SetTargets({ [id] = true }, name)
end

-- Alle Tiere der aktuellen Liste
function Overlay:ShowMany(ids, count)
    self.mode = "many"
    self.singleID = nil
    self:SetTargets(ids, string.format(FW.L.BEAST_MAP_MANY, count))
end

-- Falls die Karte erst spaeter geladen wird
FW:RegisterEvent("ADDON_LOADED", function(_, name)
    if name == "Blizzard_WorldMap" then
        Overlay:Hook()
        Overlay:Refresh()
    end
end, Overlay)

-- Diagnose: /fwbeasts map
function Overlay:Debug()
    local wm = _G.WorldMapFrame
    local canvas = Canvas()
    local d = self.lastDraw
    FW:Print("Karte: " .. tostring(CurrentMapID()) .. ", Flaeche " .. tostring(canvas and canvas:GetWidth()) .. " x "
        .. tostring(canvas and canvas:GetHeight()) .. ", Ebene " .. tostring(canvas and canvas:GetFrameLevel())
        .. ", Overlay-Ebene " .. tostring(layer and layer:GetFrameLevel()))
    if d and d.blobs then
        FW:Print("Flecken " .. tostring(d.blobs) .. ", Groesse " .. string.format("%.1f", d.size or 0) .. ", Flaeche " .. string.format("%.0f x %.0f", d.width or 0, d.height or 0)
            .. ", Zeichenebene " .. tostring(layer and layer:GetFrameLevel()))
    end
    FW:Print("Anzeige: " .. tostring(self.mode) .. ", Tiere " .. tostring(self.ids and (function() local n = 0 for _ in pairs(self.ids) do n = n + 1 end return n end)() or 0)
        .. ", Zellen auf dieser Karte " .. tostring(d and d.cells))
    if layer and textures and textures[1] then
        FW:Print("Erster Fleck: sichtbar " .. tostring(textures[1]:IsVisible()) .. ", Grösse " .. tostring(textures[1]:GetWidth()))
    end
end

-- Test: grosser roter Kasten in der Kartenmitte, zeigt ob ueberhaupt gezeichnet wird
function Overlay:Test()
    local f = EnsureLayer()
    if not f then
        FW:Print("Weltkarte nicht gefunden.")
        return
    end
    if not f.testTex then
        f.testTex = f:CreateTexture(nil, "OVERLAY")
        f.testTex:SetColorTexture(1, 0.1, 0.1, 0.6)
        f.testTex:SetSize(160, 160)
        f.testTex:SetPoint("CENTER", f, "CENTER", 0, 0)
    end
    if f.testTex:IsShown() then
        f.testTex:Hide()
    else
        f.testTex:Show()
    end
end
