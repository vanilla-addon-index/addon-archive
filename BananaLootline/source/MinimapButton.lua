--[[----------------------------------------------------------------------
  BananaLootline - MinimapButton.lua

  Knopf am Kartenrand: Linksklick oeffnet und schliesst das Fenster,
  Ziehen mit gedrueckter Maustaste verschiebt ihn um die Karte. Die
  Position liegt als Winkel in BananaLootlineDB.minimap.angle.

  /bll minimap blendet ihn aus und wieder ein.

  Bis 0.22.11 gab es keinen. Die offene Frage aus 0.22.6 ("Es gibt kein
  Minimap-Symbol. Nicht ein defektes, sondern keines.") ist damit
  erledigt.
------------------------------------------------------------------------]]

local BLL = BananaLootline
BLL.Minimap = {}
local MB = BLL.Minimap

local ICON = "Interface\\AddOns\\BananaLootline\\Images\\Minimap"
local RADIUS = 80
MB.DEFAULT_ANGLE = 200

local function Settings()
  BananaLootlineDB.minimap = BananaLootlineDB.minimap or {}
  return BananaLootlineDB.minimap
end

function MB:Place()
  if not self.button then return end
  local a = math.rad(Settings().angle or MB.DEFAULT_ANGLE)
  self.button:ClearAllPoints()
  self.button:SetPoint("CENTER", Minimap, "CENTER",
    math.cos(a) * RADIUS, math.sin(a) * RADIUS)
end

-- Winkel aus der Mausposition relativ zur Kartenmitte.
local function AngleFromCursor()
  local mx, my = Minimap:GetCenter()
  local scale = Minimap:GetEffectiveScale()
  local cx, cy = GetCursorPosition()
  cx, cy = cx / scale, cy / scale
  return math.deg(math.atan2(cy - my, cx - mx))
end

function MB:Init()
  if self.button or not Minimap then return end

  local b = CreateFrame("Button", "BananaLootlineMinimapButton", Minimap)
  b:SetWidth(33); b:SetHeight(33)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")

  local icon = b:CreateTexture(nil, "BACKGROUND")
  icon:SetTexture(ICON)
  icon:SetWidth(24); icon:SetHeight(24)
  icon:SetPoint("CENTER", b, "CENTER", 0, 1)
  b.icon = icon

  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetWidth(56); border:SetHeight(56)
  border:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)

  b:SetScript("OnClick", function()
    if BLL.UI then BLL.UI:Toggle() end
  end)
  b:SetScript("OnDragStart", function()
    this:SetScript("OnUpdate", function()
      Settings().angle = AngleFromCursor()
      MB:Place()
    end)
  end)
  b:SetScript("OnDragStop", function()
    this:SetScript("OnUpdate", nil)
  end)
  b:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:SetText("|cffffcc33Banana|cffffffffLootline|r "
      .. ((BLL.Version and BLL:Version()) or ""))
    GameTooltip:AddLine(BLL.L["MINIMAP_TIP"], 0.8, 0.8, 0.8, 1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)

  self.button = b
  self:Place()
  self:Apply()
end

function MB:Apply()
  if not self.button then return end
  if Settings().hide then self.button:Hide() else self.button:Show() end
end

function MB:Toggle()
  local s = Settings()
  s.hide = not s.hide
  self:Apply()
  return not s.hide
end
