-- Freewood-OctoWoW-Core: Verhalten des Hauptfensters
-- Aufbau und Farben stehen in MainWindow.xml. Hier: Ziehen, Position merken,
-- Tabs registrieren und umschalten, Oeffnen/Schliessen.

local ADDON, FW = ...

local UI = FW.UI
local frame = _G.FreewoodMainFrame
if not frame then
    return
end

UI.window = frame
table.insert(UISpecialFrames, "FreewoodMainFrame") -- Escape schliesst das Fenster

local tabs = {}      -- Reihenfolge der Tabs
local tabsById = {}
local activeId
local built = false

------------------------------------------------------------------------
-- Kopf, Ziehen, Position
------------------------------------------------------------------------

local header = frame.Header

UI.SetFont(header.Title, "heading", 20)
header.Title:SetTextColor(UI.Color("goldLight"))
header.Title:SetText("Freewood")

UI.SetFont(header.Subtitle, "body", 11)
header.Subtitle:SetTextColor(UI.Color("textDim"))

UI.SetFont(frame.Footer.Left, "body", 11)
frame.Footer.Left:SetTextColor(UI.Color("textDim"))

local closeButton = UI.CreateButton(header, "X", 30, 30, function()
    frame:Hide()
end, "ghost")
closeButton:SetPoint("RIGHT", header, "RIGHT", -10, 0)

-- Regler fuer die Fenstergroesse (50 bis 150 Prozent) in der Kopfzeile
local scaleText = UI.CreateLabel(header, "100%", { size = 11, color = "textDim", justify = "RIGHT" })
scaleText:SetWidth(40)
scaleText:SetPoint("RIGHT", closeButton, "LEFT", -12, 0)
local scaleSlider = UI.CreateSlider(header, 150, {
    min = 50, max = 150, step = 5,
    get = function() return math.floor(UI:GetScale() * 100 + 0.5) end,
    set = function(v) UI:SetScale(v / 100) end,
})
scaleSlider:SetPoint("RIGHT", scaleText, "LEFT", -8, 0)
scaleSlider.onText = function(v) scaleText:SetText(string.format("%d%%", v)) end
UI.AttachTooltip(scaleSlider, function() return FW.L.WINDOW_SCALE end, function() return FW.L.WINDOW_SCALE_TIP end)
UI.scaleSlider = scaleSlider

local scaleListeners = {}
-- Andere Bedienelemente (Einstellungen: - / +) melden sich an, um bei einer Aenderung nachzuziehen
function UI:OnScaleChanged(fn)
    scaleListeners[#scaleListeners + 1] = fn
end

header:EnableMouse(true)
header:RegisterForDrag("LeftButton")
header:SetScript("OnDragStart", function()
    frame:StartMoving()
end)
header:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    if point and FW.settings then
        FW.settings.windowPos = { point = point, relativePoint = relativePoint, x = x, y = y }
    end
end)

function UI:ApplyPosition()
    local pos = FW.settings and FW.settings.windowPos
    frame:ClearAllPoints()
    if type(pos) == "table" and pos.point then
        frame:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.x or 0, pos.y or 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

------------------------------------------------------------------------
-- Groesse: Standard, Grenzen, Ziehgriff unten rechts
------------------------------------------------------------------------

local DEFAULT_W, DEFAULT_H = 1240, 840
local MIN_W, MIN_H = 1240, 840   -- so gross, dass die Einstellungen komplett passen
local MAX_W, MAX_H = 1500, 1100

-- Grenzen passend zum Bildschirm (Fenster soll nicht groesser als der Bildschirm werden)
local function SizeLimits()
    local scale = frame:GetScale() or 1
    local sw = ((UIParent and UIParent:GetWidth()) or 1920) / scale
    local sh = ((UIParent and UIParent:GetHeight()) or 1080) / scale
    local maxW = math.max(MIN_W, math.min(MAX_W, sw - 20))
    local maxH = math.max(MIN_H, math.min(MAX_H, sh - 20))
    return maxW, maxH
end

local function ClampSize(w, h)
    local maxW, maxH = SizeLimits()
    w = math.min(math.max(tonumber(w) or DEFAULT_W, MIN_W), maxW)
    h = math.min(math.max(tonumber(h) or DEFAULT_H, MIN_H), maxH)
    return w, h
end

function UI:ApplySize()
    local saved = FW.settings and FW.settings.windowSize
    local w, h = DEFAULT_W, DEFAULT_H
    if type(saved) == "table" then
        w, h = saved.w or w, saved.h or h
    end
    frame:SetSize(ClampSize(w, h))
end

local function SetupResize()
    if frame.SetResizable then
        frame:SetResizable(true)
    end
    local maxW, maxH = SizeLimits()
    if frame.SetResizeBounds then
        frame:SetResizeBounds(MIN_W, MIN_H, maxW, maxH)
    else
        if frame.SetMinResize then frame:SetMinResize(MIN_W, MIN_H) end
        if frame.SetMaxResize then frame:SetMaxResize(maxW, maxH) end
    end

    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(18, 18)
    grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
    grip:SetFrameLevel((frame:GetFrameLevel() or 1) + 30)
    -- Sichtbarer Griff: sechs Punkte als Dreieck in der Ecke (die Chat-Grafik gibt es auf Octo nicht)
    local dots = {}
    local spots = { { 0, 0 }, { 5, 0 }, { 10, 0 }, { 0, 5 }, { 5, 5 }, { 0, 10 } }
    for i, p in ipairs(spots) do
        local t = grip:CreateTexture(nil, "OVERLAY")
        t:SetSize(3, 3)
        t:SetPoint("BOTTOMRIGHT", grip, "BOTTOMRIGHT", -2 - p[1], 2 + p[2])
        t:SetColorTexture(UI.Color("gold"))
        t:SetAlpha(0.75)
        dots[i] = t
    end
    local function Tint(key, alpha)
        for _, t in ipairs(dots) do
            t:SetColorTexture(UI.Color(key))
            t:SetAlpha(alpha)
        end
    end
    grip:SetScript("OnEnter", function() Tint("goldLight", 1) end)
    grip:SetScript("OnLeave", function() Tint("gold", 0.75) end)
    grip:SetScript("OnMouseDown", function()
        local mw, mh = SizeLimits()
        if frame.SetResizeBounds then
            frame:SetResizeBounds(MIN_W, MIN_H, mw, mh)
        end
        frame:StartSizing("BOTTOMRIGHT")
    end)
    grip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        local w, h = ClampSize(frame:GetWidth(), frame:GetHeight())
        frame:SetSize(w, h)
        if FW.settings then
            FW.settings.windowSize = { w = math.floor(w + 0.5), h = math.floor(h + 0.5) }
        end
        local point, _, relativePoint, x, y = frame:GetPoint(1)
        if point and FW.settings then
            FW.settings.windowPos = { point = point, relativePoint = relativePoint, x = x, y = y }
        end
    end)
    UI.AttachTooltip(grip, function() return FW.L.WINDOW_RESIZE end, function() return FW.L.WINDOW_RESIZE_TIP end)
    frame.resizeGrip = grip
end

function UI:ResetPosition()
    if FW.settings then
        FW.settings.windowPos = false
        FW.settings.windowSize = false
    end
    self:ApplySize()
    self:ApplyPosition()
end

function UI:SetScale(scale)
    scale = FW.Util.Clamp(math.floor(scale * 20 + 0.5) / 20, 0.5, 1.5)
    if FW.settings then
        FW.settings.scale = scale
    end
    frame:SetScale(scale)
    self:ApplySize()
    scaleSlider:Refresh()
    for _, fn in ipairs(scaleListeners) do
        pcall(fn, scale)
    end
end

function UI:GetScale()
    return (FW.settings and FW.settings.scale) or 1
end

FW:On("FW_DB_READY", function()
    frame:SetScale(UI:GetScale())
    scaleSlider:Refresh()
    SetupResize()
    UI:ApplySize()
    UI:ApplyPosition()
    header.Subtitle:SetText("v" .. FW.version)
end)

------------------------------------------------------------------------
-- Tabs
-- def.label   Text oder Funktion, die den Text liefert
-- def.order   Reihenfolge (kleiner = weiter links)
-- def.build   function(content) -> Frame   (wird beim ersten Anzeigen aufgerufen)
-- def.onShow  function(tabFrame)           (bei jedem Anzeigen)
------------------------------------------------------------------------

local function ResolveLabel(def)
    local label = def.label
    if type(label) == "function" then
        label = label()
    end
    return label or "?"
end

local TAB_ROW_H = 34

-- Tabs in Zeilen umbrechen, wenn sie nicht in eine Zeile passen; die Leiste waechst mit,
-- der Inhaltsbereich haengt an ihrem unteren Rand und rutscht mit.
local function LayoutTabs()
    table.sort(tabs, function(a, b)
        if a.order ~= b.order then
            return a.order < b.order
        end
        return a.seq < b.seq
    end)
    local barW = frame.TabBar:GetWidth()
    if not barW or barW < 100 then
        barW = (frame:GetWidth() or 1000) - 2
    end
    local limit = barW - 12
    local x, row = 12, 0
    local rowOf = {}
    for _, tab in ipairs(tabs) do
        if tab.button then
            local w = tab.button:GetWidth()
            if x + w > limit and x > 12 then
                row = row + 1
                x = 12
            end
            rowOf[tab] = { row = row, x = x }
            x = x + w + 4
        end
    end
    local rows = row + 1
    frame.TabBar:SetHeight(rows * TAB_ROW_H + 2)
    for _, tab in ipairs(tabs) do
        local at = rowOf[tab]
        if at then
            tab.button:ClearAllPoints()
            tab.button:SetPoint("BOTTOMLEFT", frame.TabBar, "BOTTOMLEFT", at.x, 1 + (rows - 1 - at.row) * TAB_ROW_H)
        end
    end
end

local function CreateTabButton(tab)
    local button = UI.CreateTabButton(frame.TabBar, ResolveLabel(tab.def))
    button:SetScript("OnClick", function()
        UI:SelectTab(tab.id)
    end)
    tab.button = button
end

function UI:RegisterTab(id, def)
    if tabsById[id] then
        return tabsById[id]
    end
    local tab = { id = id, def = def, order = def.order or 100, seq = #tabs + 1 }
    tabsById[id] = tab
    tabs[#tabs + 1] = tab
    if built then
        CreateTabButton(tab)
        LayoutTabs()
    end
    return tab
end

function UI:SelectTab(id)
    local tab = tabsById[id]
    if not tab then
        return
    end

    for _, other in ipairs(tabs) do
        if other.frame then
            other.frame:Hide()
        end
        if other.button then
            other.button:SetActive(other == tab)
        end
    end

    if not tab.frame and tab.def.build then
        tab.frame = tab.def.build(frame.Content)
        if tab.frame then
            tab.frame:SetAllPoints(frame.Content)
        end
    end
    if tab.frame then
        tab.frame:Show()
        if tab.def.onShow then
            FW.SafeCall(tab.def.onShow, tab.frame)
        end
    end
    activeId = id
end

local function BuildOnce()
    if built then
        return
    end
    built = true
    for _, tab in ipairs(tabs) do
        CreateTabButton(tab)
    end
    LayoutTabs()
    frame:HookScript("OnSizeChanged", function()
        LayoutTabs()
    end)
end

frame:SetScript("OnShow", function()
    BuildOnce()
    local _, _, _, toc = GetBuildInfo()
    local left = FW.L.TITLE .. "  |  " .. string.format(FW.L.SLASH_VERSION, FW.version, FW.API_VERSION, tostring(toc or "?"))
    frame.Footer.Left:SetText(left)
    UI:SelectTab(activeId or (tabs[1] and tabs[1].id))
end)

------------------------------------------------------------------------
-- Oeffnen und Schliessen
------------------------------------------------------------------------

function UI:Show(tabId)
    if tabId then
        activeId = tabId
    end
    if frame:IsShown() then
        if tabId then
            self:SelectTab(tabId)
        end
    else
        frame:Show() -- OnShow waehlt den Tab
    end
end

function UI:Hide()
    frame:Hide()
end

function UI:Toggle(tabId)
    if frame:IsShown() then
        frame:Hide()
    else
        self:Show(tabId)
    end
end
