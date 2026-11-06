-- Freewood-OctoWoW-Core: Aufbau des Hauptfensters (OctoWoW)
--
-- Ersetzt MainWindow.xml. OctoWoW (1.12.1) bricht beim Laden ab, sobald ein <Size> nur x ODER y hat
-- ("No x or y attributes in element: Size"); dann entstehen keine Unterframes und das ganze Fenster fehlt.
-- Der Aufbau in Lua ist unabhaengig vom XML-Parser des Clients. Die Struktur ist dieselbe wie vorher:
--   FreewoodMainFrame.Header (Bg, Accent, Logo, Title, Subtitle)
--   FreewoodMainFrame.TabBar (Bg, Line)
--   FreewoodMainFrame.Footer (Bg, Left)
--   FreewoodMainFrame.Content
-- Farben: Hintergrund #0f131f, Kopfzeile #0c0e14, Leiste #141824, Gold #c89b3c, Bronze #9d7826.

local ADDON, FW = ...

if _G.FreewoodMainFrame then
    return
end

local function Solid(tex, r, g, b, a)
    tex:SetTexture(r, g, b, a)
end

local function NewTexture(parent, layer, r, g, b, a)
    local t = parent:CreateTexture(nil, layer)
    Solid(t, r, g, b, a)
    return t
end

local frame = CreateFrame("Frame", "FreewoodMainFrame", UIParent)
frame:SetFrameStrata("HIGH")
frame:SetToplevel(true)
frame:SetMovable(true)
frame:SetClampedToScreen(true)
frame:EnableMouse(true)
frame:SetWidth(960)
frame:SetHeight(760)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:Hide()

-- Hintergrund und Rahmen
frame.Bg = NewTexture(frame, "BACKGROUND", 0.059, 0.075, 0.122, 0.97)
frame.Bg:SetAllPoints(frame)

local gold = { 0.616, 0.471, 0.149, 1 }

frame.BorderTop = NewTexture(frame, "BORDER", gold[1], gold[2], gold[3], gold[4])
frame.BorderTop:SetHeight(1)
frame.BorderTop:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
frame.BorderTop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)

frame.BorderBottom = NewTexture(frame, "BORDER", gold[1], gold[2], gold[3], gold[4])
frame.BorderBottom:SetHeight(1)
frame.BorderBottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
frame.BorderBottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

frame.BorderLeft = NewTexture(frame, "BORDER", gold[1], gold[2], gold[3], gold[4])
frame.BorderLeft:SetWidth(1)
frame.BorderLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
frame.BorderLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)

frame.BorderRight = NewTexture(frame, "BORDER", gold[1], gold[2], gold[3], gold[4])
frame.BorderRight:SetWidth(1)
frame.BorderRight:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
frame.BorderRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

-- Kopfzeile mit Titel
local header = CreateFrame("Frame", nil, frame)
header:SetHeight(48)
header:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
frame.Header = header

header.Bg = NewTexture(header, "BACKGROUND", 0.047, 0.055, 0.078, 1)
header.Bg:SetAllPoints(header)

header.Accent = NewTexture(header, "ARTWORK", 0.784, 0.608, 0.235, 0.55)
header.Accent:SetHeight(1)
header.Accent:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
header.Accent:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)

header.Logo = header:CreateTexture(nil, "ARTWORK")
header.Logo:SetTexture("Interface\\AddOns\\Freewood-OctoWoW-Core\\Media\\FreeWood_Logo")
header.Logo:SetWidth(40)
header.Logo:SetHeight(40)
header.Logo:SetPoint("LEFT", header, "LEFT", 14, 0)

header.Title = header:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
header.Title:SetJustifyH("LEFT")
header.Title:SetPoint("LEFT", header.Logo, "RIGHT", 10, 0)

header.Subtitle = header:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
header.Subtitle:SetJustifyH("LEFT")
header.Subtitle:SetPoint("LEFT", header.Title, "RIGHT", 12, -2)

-- Leiste fuer die Tabs
local tabBar = CreateFrame("Frame", nil, frame)
tabBar:SetHeight(36)
tabBar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
tabBar:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, 0)
frame.TabBar = tabBar

tabBar.Bg = NewTexture(tabBar, "BACKGROUND", 0.078, 0.094, 0.141, 1)
tabBar.Bg:SetAllPoints(tabBar)

tabBar.Line = NewTexture(tabBar, "ARTWORK", 0.616, 0.471, 0.149, 0.5)
tabBar.Line:SetHeight(1)
tabBar.Line:SetPoint("BOTTOMLEFT", tabBar, "BOTTOMLEFT", 0, 0)
tabBar.Line:SetPoint("BOTTOMRIGHT", tabBar, "BOTTOMRIGHT", 0, 0)

-- Fusszeile
local footer = CreateFrame("Frame", nil, frame)
footer:SetHeight(26)
footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
frame.Footer = footer

footer.Bg = NewTexture(footer, "BACKGROUND", 0.047, 0.055, 0.078, 1)
footer.Bg:SetAllPoints(footer)

footer.Left = footer:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
footer.Left:SetJustifyH("LEFT")
footer.Left:SetPoint("LEFT", footer, "LEFT", 16, 0)

-- Inhaltsbereich (hier setzen die Tabs ihre Frames ein)
local content = CreateFrame("Frame", nil, frame)
content:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 20, -18)
content:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", -20, 12)
frame.Content = content
