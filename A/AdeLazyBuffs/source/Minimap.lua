-- AdeLazyBuffs minimap button (Blessing of Wisdom icon). Click = settings window, drag = move around the minimap.
-- Written for the Lua 5.0 client: no '#', no '%', no select(), no string.match.

local A = AdeLazyBuffs
local btn

local function Place()
  local vx = A.DB.miniX or -0.7071
  local vy = A.DB.miniY or -0.7071
  local r = (Minimap:GetWidth() / 2) + 6
  btn:ClearAllPoints()
  btn:SetPoint("CENTER", Minimap, "CENTER", vx * r, vy * r)
end

local function Dragging()
  local mx, my = Minimap:GetCenter()
  local px, py = GetCursorPosition()
  local s = Minimap:GetEffectiveScale()
  px, py = px / s, py / s
  local dx, dy = px - mx, py - my
  local len = math.sqrt(dx * dx + dy * dy)
  if len < 1 then return end
  A.DB.miniX = dx / len
  A.DB.miniY = dy / len
  Place()
end

function A.RefreshMinimap()
  if not btn then return end
  if A.DB and A.DB.miniHide then btn:Hide() else btn:Show() end
end

function A.InitMinimap()
  if btn or not A.DB then return end
  btn = CreateFrame("Button", "AdeLazyBuffsMinimapButton", Minimap)
  btn:SetWidth(31)
  btn:SetHeight(31)
  btn:SetFrameStrata("MEDIUM")
  btn:SetFrameLevel(8)
  btn:RegisterForClicks("LeftButtonUp")
  btn:RegisterForDrag("LeftButton")
  btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local icon = btn:CreateTexture(nil, "BACKGROUND")
  icon:SetTexture("Interface\\Icons\\Spell_Holy_SealOfWisdom")
  icon:SetWidth(20)
  icon:SetHeight(20)
  icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 6, -5)
  icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  local border = btn:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetWidth(53)
  border:SetHeight(53)
  border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)

  btn:SetScript("OnClick", function() A.ToggleWindow() end)
  btn:SetScript("OnDragStart", function()
    this:SetScript("OnUpdate", Dragging)
  end)
  btn:SetScript("OnDragStop", function()
    this:SetScript("OnUpdate", nil)
  end)
  btn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:SetText("AdeLazyBuffs")
    GameTooltip:AddLine(A.T("Click: settings. Drag: move the button."), 1, 1, 1)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

  Place()
  A.RefreshMinimap()
end
