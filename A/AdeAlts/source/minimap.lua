-- Ade Alts: minimap
local AA = AdeAlts

----------------------------------------------------------------------
-- minimap button (pfUI docks it automatically into its addon panel)
----------------------------------------------------------------------
AA.btn = CreateFrame("Button", "AdeAltsMinimapButton", Minimap)
AA.btn:SetWidth(31)
AA.btn:SetHeight(31)
AA.btn:SetFrameStrata("MEDIUM")
AA.btn:SetFrameLevel(8)
AA.btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
AA.btn:RegisterForDrag("LeftButton")

-- classic round minimap button (gold ring); pfUI keeps this look for docked buttons
local bg = AA.btn:CreateTexture(nil, "BACKGROUND")
bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
bg:SetWidth(20)
bg:SetHeight(20)
bg:SetPoint("TOPLEFT", AA.btn, "TOPLEFT", 7, -5)
local icon = AA.btn:CreateTexture(nil, "ARTWORK")
icon:SetTexture("Interface\\Icons\\Trade_Alchemy")
icon:SetWidth(20)
icon:SetHeight(20)
icon:SetPoint("TOPLEFT", AA.btn, "TOPLEFT", 7, -5)
icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
local border = AA.btn:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetWidth(53)
border:SetHeight(53)
border:SetPoint("TOPLEFT", AA.btn, "TOPLEFT", 0, 0)
AA.btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
AA.StyleButton = function() end

function AA.PlaceButton()
  if AA.btn:GetParent() ~= Minimap then return end -- docked by pfUI
  local angle = (AA.db and AA.db.angle) or 200
  local r = Minimap:GetWidth() / 2 + 6
  local rad = math.rad(angle)
  AA.btn:ClearAllPoints()
  AA.btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * r, math.sin(rad) * r)
end
AA.PlaceButton()

AA.btn:SetScript("OnDragStart", function()
  if this:GetParent() ~= Minimap then return end
  this:SetScript("OnUpdate", function()
    local mx, my = GetCursorPosition()
    local sc = Minimap:GetEffectiveScale()
    local cx, cy = Minimap:GetCenter()
    AA.db.angle = math.deg(math.atan2(my / sc - cy, mx / sc - cx))
    AA.PlaceButton()
  end)
end)
AA.btn:SetScript("OnDragStop", function() this:SetScript("OnUpdate", nil) end)

AA.btn:SetScript("OnClick", function()
  if arg1 == "RightButton" then
    AA.Send("R")
    AA.Broadcast()
    AA.FileSync()
    AA.Print("synced.")
  else
    AA.ToggleManager()
  end
end)

AA.btn:SetScript("OnEnter", function()
  GameTooltip:SetOwner(this, "ANCHOR_LEFT")
  GameTooltip:AddLine("Ade Alts - cooldowns")
  if AA.db then
    local list = AA.Entries(true)
    if table.getn(list) == 0 then
      GameTooltip:AddLine("|cff808080No cooldowns recorded yet|r")
    end
    for _, e in ipairs(list) do
      GameTooltip:AddDoubleLine(e.l, e.r, 1, 1, 1, 1, 1, 1)
    end
  end
  GameTooltip:AddLine("|cff808080Left: window   Right: sync   Drag: move|r")
  GameTooltip:Show()
end)
AA.btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

function AA.DockInPfUI()
  if pfUI and pfUI.addonbuttons and pfUI.addonbuttons.ProcessButtons then
    pcall(function() pfUI.addonbuttons:ProcessButtons() end)
  end
end

