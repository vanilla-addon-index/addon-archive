-- EGM minimap button (pattern: Vampify gui/minimap.lua; pfUI-safe: parent Minimap, name contains "Minimap", strata HIGH).
EGM = EGM or {}
EGM.Minimap = EGM.Minimap or {}
local M = EGM.Minimap

local button = nil

local function char() return (EGM.DB and EGM.DB.char) or {} end

local function place(angleDeg)
  if not button then return end
  local radius = (Minimap:GetWidth() / 2) + 5
  local rad = (angleDeg or 200) * math.pi / 180
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * radius, math.sin(rad) * radius)
end

local function build()
  if button then return end
  local btn = CreateFrame("Button", "EGMMinimapButton", Minimap)
  btn:SetWidth(33); btn:SetHeight(33)
  btn:SetFrameStrata("HIGH"); btn:SetFrameLevel(9)

  local icon = btn:CreateTexture("EGMMinimapIcon", "ARTWORK")
  icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_02")
  icon:SetWidth(20); icon:SetHeight(20)
  icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  local border = btn:CreateTexture("EGMMinimapBorder", "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetWidth(54); border:SetHeight(54)
  border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)

  btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  btn:RegisterForDrag("LeftButton")

  btn:SetScript("OnDragStart", function() this.isDragging = true end)
  btn:SetScript("OnDragStop", function() this.isDragging = false end)
  btn:SetScript("OnUpdate", function()
    if not this.isDragging then return end
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale
    local angle = math.atan2(cy - my, cx - mx) * 180 / math.pi
    char().mmAngle = angle
    place(angle)
  end)
  btn:SetScript("OnClick", function()
    if arg1 == "RightButton" then
      if EGM.Options and EGM.Options.toggle then EGM.Options.toggle() end
    elseif EGM.UI and EGM.UI.toggle then
      EGM.UI.toggle()
    end
  end)
  btn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:SetText("EGM - ERROR Guild Market", 1, 1, 1)
    GameTooltip:AddLine("Left click: open / close", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Right click: options", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Drag: move around the minimap", 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  button = btn
  place(char().mmAngle)
end

-- honours the "Show minimap button" setting (EGM.DB.char.minimap)
function M.update()
  if not CreateFrame then return end
  if char().minimap == false then
    if button then button:Hide() end
    return
  end
  build()
  place(char().mmAngle)
  button:Show()
end
