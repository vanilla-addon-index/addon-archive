-- Freewood-OctoWoW-Core: Minimap-Knopf
-- Links: Fenster, Rechts: Einstellungen, Ziehen: um die Minimap verschieben.
-- Annahme: runde Minimap.

local ADDON, FW = ...

local UI = FW.UI
local Minimap_ = _G.Minimap

local M = {}
FW.Minimap = M

local button = CreateFrame("Button", "FreewoodMinimapButton", Minimap_)
button:SetSize(32, 32)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(8)
button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
button:RegisterForDrag("LeftButton")

local overlay = button:CreateTexture(nil, "OVERLAY")
overlay:SetSize(53, 53)
overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
overlay:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)

local background = button:CreateTexture(nil, "BACKGROUND")
background:SetSize(20, 20)
background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
background:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -5)

local icon = button:CreateTexture(nil, "ARTWORK")
icon:SetSize(17, 17)
icon:SetTexture("Interface\\AddOns\\Freewood-OctoWoW-Core\\Media\\FreeWood_Logo.tga")
icon:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -6)

button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local atan2 = math.atan2 or math.atan

local function UpdatePosition()
    local angle = math.rad((FW.settings and FW.settings.minimap.angle) or 215)
    local radius = (Minimap_:GetWidth() / 2) + 5
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap_, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

button:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
        local mx, my = Minimap_:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap_:GetEffectiveScale()
        px, py = px / scale, py / scale
        FW.settings.minimap.angle = math.deg(atan2(py - my, px - mx)) % 360
        UpdatePosition()
    end)
end)

button:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
end)

button:SetScript("OnClick", function(_, mouseButton)
    if mouseButton == "RightButton" then
        UI:Show("settings")
    else
        UI:Toggle()
    end
end)

button:SetScript("OnEnter", function(self)
    local L = FW.L
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Freewood", 0.94, 0.75, 0.36)
    GameTooltip:AddLine(L.MINIMAP_TIP_LEFT, 0.8, 0.8, 0.8)
    GameTooltip:AddLine(L.MINIMAP_TIP_RIGHT, 0.8, 0.8, 0.8)
    GameTooltip:AddLine(L.MINIMAP_TIP_DRAG, 0.6, 0.6, 0.6)
    GameTooltip:Show()
end)
button:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

function M:SetHidden(hidden)
    FW.settings.minimap.hide = hidden and true or false
    if hidden then
        button:Hide()
    else
        button:Show()
    end
end

M.button = button

FW:On("FW_DB_READY", function()
    UpdatePosition()
    if FW.settings.minimap.hide then
        button:Hide()
    else
        button:Show()
    end
end)
