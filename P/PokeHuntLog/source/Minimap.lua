-- PokeHuntLog: minimap button. Left-click opens the log, drag moves it around the minimap.

local HPL = PokeHuntLog

local button

local function UpdatePosition()
  local angle = math.rad(HPL.db.settings.minimapAngle or 215)
  button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * 80, math.sin(angle) * 80)
end

local function DragUpdate()
  local mx, my = Minimap:GetCenter()
  local px, py = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale()
  px, py = px / scale, py / scale
  HPL.db.settings.minimapAngle = math.deg(math.atan2(py - my, px - mx))
  UpdatePosition()
end

function HPL.UpdateMinimapButton()
  if not button then return end
  -- Nothing here is useful to other classes, so the button only shows for hunters.
  if HPL.db.settings.minimapHidden or not HPL.IsHunter() then
    button:Hide()
  else
    UpdatePosition()
    button:Show()
  end
end

function HPL.InitMinimapButton()
  button = CreateFrame("Button", "PokeHuntLogMinimapButton", Minimap)
  button:SetWidth(31)
  button:SetHeight(31)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local icon = button:CreateTexture(nil, "BACKGROUND")
  icon:SetTexture("Interface\\Icons\\Ability_Hunter_BeastTaming")
  icon:SetWidth(20)
  icon:SetHeight(20)
  icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  icon:SetPoint("TOPLEFT", button, "TOPLEFT", 6, -5)

  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetWidth(53)
  border:SetHeight(53)
  border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)

  button:SetScript("OnClick", function()
    if IsShiftKeyDown() then
      HPL.ToggleHelp()
    elseif arg1 == "RightButton" then
      HPL.db.settings.showUncaught = not HPL.db.settings.showUncaught
      HPL.Print("uncaught skins are now " .. (HPL.db.settings.showUncaught and "shown" or "hidden") .. ".")
      HPL.Changed()
    else
      HPL.ToggleWindow()
    end
  end)
  button:SetScript("OnDragStart", function() this:SetScript("OnUpdate", DragUpdate) end)
  button:SetScript("OnDragStop", function() this:SetScript("OnUpdate", nil) end)
  button:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:SetText("PokeHuntLog")
    GameTooltip:AddLine("version " .. HPL.VERSION, 0.6, 0.6, 0.6)
    if HPL.totals then
      GameTooltip:AddLine("Skins: " .. HPL.totals.caught .. " / " .. HPL.totals.skins, 1, 1, 1)
    end
    GameTooltip:AddLine("Left-click: open the log", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Right-click: show/hide uncaught skins", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Shift-click: how to use", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Drag: move this button", 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)

  HPL.UpdateMinimapButton()
  -- Class info can be missing while addons load, so check again once the world is up.
  HPL.After(6, function() HPL.UpdateMinimapButton() end)
end
