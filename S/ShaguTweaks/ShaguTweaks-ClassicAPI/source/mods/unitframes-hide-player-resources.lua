local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local API = ShaguTweaks.API
local module = ShaguTweaks:register({
  title = T["Hide Player Frame Resources"],
  description = T["Hides the original player health and power bars, leaving the clean round portrait and name. Hold Ctrl+Shift+Alt to drag the name independently; right-click with those keys held to reset it. Personal Resource Display is independent."],
  expansions = { ["vanilla"] = true }, category = T["Unit Frames"], enabled = nil,
})
local function MoveRegion(region, holder, x, y)
  if not region then return end
  region:SetParent(holder)
  region:ClearAllPoints()
  region:SetPoint("TOPLEFT", holder, "TOPLEFT", x, y)
end
module.enable = function(self)
  if self.scheduled then return end
  self.scheduled = true
  local function Setup()
    if self.installed or not PlayerFrame or not PlayerPortrait or not PlayerFrameTexture then return end
    if not PlayerPortrait:GetLeft() or not PlayerFrame:GetLeft() then return end
    self.installed = true
    local width = PlayerFrameHealthBar:GetWidth()
    local portraitLeft, portraitTop = PlayerPortrait:GetLeft() - 8, PlayerPortrait:GetTop() + 4
    local function Holder(key, w, h, x, y)
      local holder = CreateFrame("Frame", "ShaguTweaksPlayer" .. key, PlayerFrame)
      holder:SetWidth(w); holder:SetHeight(h)
      holder:SetFrameLevel(PlayerFrame:GetFrameLevel() + 3)
      holder:SetPoint("TOPLEFT", PlayerFrame, "TOPLEFT", x - PlayerFrame:GetLeft(), y - PlayerFrame:GetTop())
      return holder
    end
    local portrait = Holder("Portrait", 80, 80, portraitLeft, portraitTop)
    local name = Holder("Name", width + 8, 23, portraitLeft + 85, portraitTop - 14)
    ShaguTweaks.PlayerFrameResourcesLayout = { portrait = portrait, name = name }
    ShaguTweaks_config.PlayerFrameResources = ShaguTweaks_config.PlayerFrameResources or {}
    local positions = ShaguTweaks_config.PlayerFrameResources
    local nameX, nameY = portraitLeft + 85 - PlayerFrame:GetLeft(), portraitTop - 14 - PlayerFrame:GetTop()
    local function PositionName()
      name:ClearAllPoints()
      if positions.Name then
        name:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", positions.Name.x, positions.Name.y)
      else
        name:SetPoint("TOPLEFT", PlayerFrame, "TOPLEFT", nameX, nameY)
      end
    end
    local dragging, dropped
    local function StopName()
      if not dragging then return end
      name:StopMovingOrSizing()
      name:SetUserPlaced(false)
      dragging, dropped = nil, true
      local x, y = name:GetLeft(), name:GetTop()
      if x and y then positions.Name = { x = x, y = y } end
      PositionName()
    end
    name:SetMovable(true)
    name:SetClampedToScreen(true)
    name:EnableMouse(true)
    name:RegisterForDrag("LeftButton")
    name:SetScript("OnDragStart", function()
      if not API.AreMoveModifiersDown() then return end
      dragging, dropped = true, nil
      name:StartMoving()
    end)
    name:SetScript("OnDragStop", StopName)
    name:SetScript("OnHide", StopName)
    name:SetScript("OnMouseUp", function()
      if API.AreMoveModifiersDown() and arg1 == "RightButton" then
        StopName()
        positions.Name, dropped = nil, nil
        PositionName()
      elseif dragging then
        StopName()
        dropped = nil
      elseif dropped then
        dropped = nil
      elseif PlayerFrame_OnClick then
        -- Retain native unit clicks even after the name is moved away.
        local previous = this
        this = PlayerFrame
        PlayerFrame_OnClick(arg1)
        this = previous
      end
    end)
    PositionName()
    -- Split the native artwork before changing its source texture's anchors.
    -- Preserve its UV orientation (the player's stock artwork is mirrored).
    local art = PlayerFrameTexture
    local path = art:GetTexture()
    local u, v, unused, bottom, right = art:GetTexCoord()
    local artWidth, artHeight = PlayerFrame:GetWidth(), PlayerFrame:GetHeight()
    local r, g, b, a = art:GetVertexColor()
    local function Crop(holder, x, y, w, h)
      local texture = holder:CreateTexture(nil, "OVERLAY")
      texture:SetTexture(path)
      texture:SetTexCoord(u + (right-u)*x/artWidth, u + (right-u)*(x+w)/artWidth,
        v + (bottom-v)*y/artHeight, v + (bottom-v)*(y+h)/artHeight)
      texture:SetAllPoints(holder)
      texture:SetVertexColor(r, g, b, a)
      return texture
    end
    -- Keep the native level badge on the left. Complete the right side from
    -- the clean upper-left quadrant, leaving space for the live resting icon
    -- without mirroring a second level badge into the artwork. The native
    -- resting/combat icon shares the original left badge's position.
    portrait.art = Crop(portrait, 34, 8, 40, 72)
    portrait.artRight = Crop(portrait, 74, 8, -40, 36)
    portrait.artBottomRight = Crop(portrait, 74, 44, -40, -36)
    local function Piece(texture, x, y, height)
      texture:ClearAllPoints()
      texture:SetPoint("TOPLEFT", portrait, "TOPLEFT", x, y)
      texture:SetWidth(40)
      texture:SetHeight(height)
    end
    Piece(portrait.art, 0, 0, 72)
    Piece(portrait.artRight, 40, 0, 36)
    Piece(portrait.artBottomRight, 40, -36, 36)

    -- The native lower-left quadrant includes a dark rectangular shadow
    -- beside the level badge. Use the same clean quadrant as the lower right,
    -- then restore only the badge circle, not its surrounding shadow.
    portrait.badge = Crop(portrait, 37, 50, 32, 32)
    portrait.badge:ClearAllPoints()
    portrait.badge:SetPoint("TOPLEFT", portrait, "TOPLEFT", 3, -42)
    portrait.badge:SetWidth(32)
    portrait.badge:SetHeight(32)
    if type(portrait.badge.SetMask) == "function" then
      portrait.art:SetTexCoord(u + (right-u)*34/artWidth, u + (right-u)*74/artWidth,
        v + (bottom-v)*8/artHeight, v + (bottom-v)*44/artHeight)
      Piece(portrait.art, 0, 0, 36)
      portrait.artBottomLeft = Crop(portrait, 34, 44, 40, -36)
      Piece(portrait.artBottomLeft, 0, -36, 36)
      portrait.badge:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask")
      -- Keep the badge above every ring piece but below the number/state icons.
      portrait.badgeOverlay = CreateFrame("Frame", nil, portrait)
      portrait.badgeOverlay:SetAllPoints(portrait)
      portrait.badgeOverlay:SetFrameLevel(portrait:GetFrameLevel() + 1)
      portrait.badge:SetParent(portrait.badgeOverlay)
    else
      -- Older clients retain the original left half and its native badge.
      portrait.badge:Hide()
    end

    -- The combined frame texture has a portrait arc at the left ends of its
    -- bars. Give the separate name strip a rounded Blizzard border.
    local border = {
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      edgeSize = 12, tile = true, tileSize = 8,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    }
    local color = ShaguTweaks.UIBorder
    name:SetBackdrop(border)
    name:SetBackdropBorderColor(color and color.r or 1, color and color.g or 1,
      color and color.b or 1, 1)

    -- Keep status/role indicators with the portrait. Their native event
    -- handlers and parent visibility continue running unchanged.
    local indicators = { "PlayerHitIndicator", "PlayerPVPIcon", "PlayerPVPIconHitArea",
      "PlayerLeaderIcon", "PlayerMasterIcon", "PlayerRestIcon", "PlayerAttackIcon",
      "PlayerAttackBackground", "PlayerStatusGlow", "PlayerFrameGroupIndicator" }
    local indicatorPoints = {}
    for i = 1, table.getn(indicators) do
      local region = _G[indicators[i]]
      if region and region:GetLeft() and region:GetTop() then
        indicatorPoints[i] = { region:GetLeft() - portraitLeft, region:GetTop() - portraitTop }
      end
    end
    -- Snapshot first: some indicators are anchored to other indicators.
    for i = 1, table.getn(indicators) do
      local point = indicatorPoints[i]
      if point then MoveRegion(_G[indicators[i]], portrait, point[1], point[2]) end
    end
    MoveRegion(PlayerPortrait, portrait, 8, -4)
    if _G.PlayerLevelText then
      -- Put the native text above the ring and portrait, centered over the
      -- native left-hand badge. The stock level-update code keeps owning it.
      local levelX, levelY = 19, -58
      if PlayerLevelText.GetCenter then
        local x, y = PlayerLevelText:GetCenter()
        if x and y then levelX, levelY = x - portraitLeft, y - portraitTop end
      end
      portrait.levelOverlay = CreateFrame("Frame", nil, portrait)
      portrait.levelOverlay:SetAllPoints(portrait)
      portrait.levelOverlay:SetFrameLevel(portrait:GetFrameLevel() + 5)
      PlayerLevelText:SetParent(portrait.levelOverlay)
      PlayerLevelText:ClearAllPoints()
      PlayerLevelText:SetPoint("CENTER", portrait.levelOverlay, "TOPLEFT", levelX, levelY)
      PlayerLevelText:SetDrawLayer("BACKGROUND")
      PlayerLevelText:SetAlpha(1)
      PlayerLevelText:SetText(UnitLevel("player"))
      PlayerLevelText:Show()
      -- Keep the level above the ring but BELOW its native state icons.
      -- Their existing Show/Hide logic then covers the number while resting
      -- or in combat and reveals it again without adding another event loop.
      for _, key in ipairs({ "PlayerRestIcon", "PlayerAttackIcon", "PlayerAttackBackground", "PlayerStatusGlow" }) do
        local indicator = _G[key]
        if indicator then indicator:SetParent(portrait.levelOverlay) end
      end
    end
    local playerName = PlayerFrame.name or _G.PlayerName
    if playerName then
      playerName:SetParent(name)
      playerName:ClearAllPoints()
      playerName:SetPoint("CENTER", name, "CENTER", 0, 0)
    end
    if ShaguTweaks_config[T["Player's Name No Class Color"]] ~= 1 then
      -- Big Health deliberately hides the stock name background. Keep its
      -- color source for that module, but draw a separate class strip here.
      name.classBackground = name:CreateTexture(nil, "BACKGROUND")
      name.classBackground:SetPoint("TOPLEFT", name, "TOPLEFT", 4, -3)
      name.classBackground:SetPoint("BOTTOMRIGHT", name, "BOTTOMRIGHT", -4, 3)
      local healthTexture = PlayerFrameHealthBar:GetStatusBarTexture()
      name.classBackground:SetTexture(healthTexture and healthTexture:GetTexture()
        or "Interface\\TargetingFrame\\UI-StatusBar")
      local _, class = UnitClass("player")
      local palette = ShaguTweaks.ModernClassColors or RAID_CLASS_COLORS
      local classColor = palette and palette[class]
      local cr, cg, cb = PlayerFrameHealthBar:GetStatusBarColor()
      name.classBackground:SetVertexColor(classColor and classColor.r or cr,
        classColor and classColor.g or cg, classColor and classColor.b or cb, 1)
    end
    if ShaguTweaks_config[T["Hide Player Name"]] == 1 then name:Hide() end

    -- Keep native bar objects and events alive. Copies may still mirror them.
    local function Suppress(region)
      if not region then return end
      local setAlpha = region.SetAlpha
      setAlpha(region, 0)
      ShaguTweaks.hooksecurefunc(region, "SetAlpha", function(object) setAlpha(object, 0) end)
    end
    Suppress(PlayerFrameTexture)
    Suppress(_G.PlayerFrameBackground)
    Suppress(_G.PlayerFrameNameBackground)
    Suppress(PlayerFrameHealthBar)
    Suppress(PlayerFrameManaBar)
    Suppress(_G.PlayerFrameAlternatePowerBar)
    if PlayerStatusTexture then
      MoveRegion(PlayerStatusTexture, portrait, 1, 0)
      local function CropStatus()
        PlayerStatusTexture:SetTexCoord(0, 72/256, 0, 66/128)
        PlayerStatusTexture:SetWidth(72)
        PlayerStatusTexture:SetHeight(66)
      end
      if type(PlayerStatusTexture.SetMask) == "function" then
        PlayerStatusTexture:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask")
      end
      ShaguTweaks.hooksecurefunc("PlayerFrame_UpdateStatus", CropStatus)
      CropStatus()
    end
  end
  API.AfterWorldReady(Setup, true)
end
