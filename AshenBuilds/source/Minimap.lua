local AB = AshenBuilds

-- Minimap button: left-click toggles the planner, right-click toggles Community
-- Builds, drag to move it around the minimap edge (the angle is saved).

local RADIUS = 80

local function Settings()
  AshenBuildsDB.settings = AshenBuildsDB.settings or {}
  local s = AshenBuildsDB.settings
  if s.minimapAngle == nil then s.minimapAngle = 200 end
  return s
end

local function Place(button)
  local a = math.rad(Settings().minimapAngle)
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", RADIUS * math.cos(a), RADIUS * math.sin(a))
end

-- While dragging, follow the cursor's angle around the minimap centre.
local function Drag()
  local mx, my = Minimap:GetCenter()
  local px, py = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale()
  px, py = px / scale, py / scale
  Settings().minimapAngle = math.deg(math.atan2(py - my, px - mx))
  Place(this)
end

function AB:CreateMinimapButton()
  if self.minimapButton or not Minimap then return end
  local b = CreateFrame("Button", "AshenBuildsMinimapButton", Minimap)
  b:SetWidth(31); b:SetHeight(31); b:SetFrameStrata("MEDIUM"); b:SetFrameLevel(8)
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background"); bg:SetWidth(20); bg:SetHeight(20); bg:SetPoint("TOPLEFT", b, "TOPLEFT", 7, -5)
  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetTexture("Interface\\Icons\\Spell_Fire_Incinerate"); icon:SetWidth(20); icon:SetHeight(20); icon:SetPoint("TOPLEFT", b, "TOPLEFT", 7, -5)
  icon:SetTexCoord(0.07, 0.93, 0.07, 0.93); b.icon = icon
  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder"); border:SetWidth(53); border:SetHeight(53); border:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)

  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  b:SetScript("OnClick", function()
    if arg1 == "RightButton" then
      if not AB.frame:IsShown() then AB:ToggleUI() end
      local i
      for i = 1, table.getn(AB.tabs or {}) do if AB.tabs[i].frame == AB.communityFrame then AB:ToggleTab(AB.tabs[i]) end end
    else
      AB:ToggleUI()
      PlaySound(AB.frame:IsShown() and "igCharacterInfoOpen" or "igCharacterInfoClose")
    end
  end)
  -- Pressed-in look like the stock minimap buttons.
  b:SetScript("OnMouseDown", function() this.icon:SetPoint("TOPLEFT", this, "TOPLEFT", 8, -6) end)
  b:SetScript("OnMouseUp", function() this.icon:SetPoint("TOPLEFT", this, "TOPLEFT", 7, -5) end)
  b:SetScript("OnDragStart", function() this:LockHighlight(); this:SetScript("OnUpdate", Drag) end)
  b:SetScript("OnDragStop", function() this:UnlockHighlight(); this:SetScript("OnUpdate", nil); this.icon:SetPoint("TOPLEFT", this, "TOPLEFT", 7, -5) end)
  b:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:SetText("Ashen Builds", 1, 0.45, 0.16)
    GameTooltip:AddLine("Left-click: open or close the planner", 1, 1, 1)
    GameTooltip:AddLine("Right-click: community builds", 1, 1, 1)
    GameTooltip:AddLine("Drag: move this button", 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)

  self.minimapButton = b
  Place(b)
  if Settings().minimapHidden then b:Hide() end
end

function AB:ToggleMinimapButton()
  local s = Settings()
  s.minimapHidden = not s.minimapHidden
  if s.minimapHidden then self.minimapButton:Hide(); self.Print("Minimap button hidden. Type |cffffffff/ab minimap|r to show it again.")
  else self.minimapButton:Show() end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function() AB:CreateMinimapButton() end)
