local T = ShaguTweaks.T
local hooksecurefunc = hooksecurefunc or ShaguTweaks.hooksecurefunc

local playerModule = ShaguTweaks:register({
  title = T["Unit Frame Big Health for Player"],
  description = T["Enlarges the player health bar and colors it by class. Also applies the class color to the Personal Resource Display health bar when enabled."],
  expansions = { ["vanilla"] = true },
  category = T["Unit Frames"],
  enabled = nil,
})

local targetModule = ShaguTweaks:register({
  title = T["Unit Frame Big Health for Target"],
  description = T["Increases the healthbar of the target unitframe."],
  expansions = { ["vanilla"] = true },
  category = T["Unit Frames"],
  enabled = nil,
})

local addonpath
local tocs = { "", "-master", "-tbc", "-wotlk" }
for i = 1, table.getn(tocs) do
  local current = string.format("ShaguTweaks%s", tocs[i])
  local _, title = GetAddOnInfo(current)
  if title then
    addonpath = "Interface\\AddOns\\" .. current
    break
  end
end
addonpath = addonpath or "Interface\\AddOns\\ShaguTweaks"

local function Enable(player, target)
  local normalTexture = addonpath .. "\\img\\UI-TargetingFrame"
  local eliteTexture = addonpath .. "\\img\\UI-TargetingFrame-Elite"
  local rareTexture = addonpath .. "\\img\\UI-TargetingFrame-Rare"

  -- Darkened UI and Big Health can be enabled in either order because modules
  -- are initialized from an unordered table. If Darkened UI ran first, Big
  -- Health replaces the already-darkened textures with fresh bright ones.
  -- Apply the configured dark tint directly to our replacement textures so the
  -- result is deterministic without adding any permanent OnUpdate work.
  local function ApplyDarkModeTextures()
    -- Darkened UI or Golden UI publish their texture tint here, with the
    -- /st overwrites already applied.
    local color = ShaguTweaks.UITint
    if not color then return end

    local r = tonumber(color.r) or color.r
    local g = tonumber(color.g) or color.g
    local b = tonumber(color.b) or color.b
    local a = tonumber(color.a) or color.a or 1

    if player and PlayerFrameTexture then PlayerFrameTexture:SetVertexColor(r, g, b, a) end
    if player and PlayerStatusTexture then PlayerStatusTexture:SetVertexColor(r, g, b, a) end
    if target and TargetFrameTexture then TargetFrameTexture:SetVertexColor(r, g, b, a) end
  end

  -- Big Health is presentation-only. Numeric health/power values are owned by
  -- the independent Real Health Numbers module.
  if player then
    PlayerFrameTexture:SetTexture(normalTexture)
    PlayerFrameHealthBar:SetPoint("TOPLEFT", 106, -22)
    PlayerFrameHealthBar:SetHeight(30)

    PlayerStatusTexture:SetTexture(addonpath .. "\\img\\UI-Player-Status")

    -- The additive status artwork contains both the portrait ring and bar edge.
    -- Crop only the latter while resting, shrinking the displayed width by the
    -- same ratio so the portrait ring keeps its original size and position.
    -- Native status code continues to own visibility, tint, alpha and pulsing.
    local statusCoords = {PlayerStatusTexture:GetTexCoord()}
    local statusWidth = PlayerStatusTexture:GetWidth()
    local portraitRight = 72 / 256 -- right edge of the portrait in UI-Player-Status
    local restingCrop = false

    local function UpdateRestingGlow()
      local resting = IsResting()
        and not UnitAffectingCombat("player")
      local left, right = statusCoords[1], statusCoords[5]
      if not left or not right or right <= left
        or portraitRight <= left or portraitRight >= right then return end

      if resting and not restingCrop then
        PlayerStatusTexture:SetTexCoord(
          left, portraitRight, statusCoords[2], statusCoords[4])
        PlayerStatusTexture:SetWidth(
          statusWidth * (portraitRight - left) / (right - left))
        restingCrop = true
      elseif not resting and restingCrop then
        PlayerStatusTexture:SetTexCoord(
          left, right, statusCoords[2], statusCoords[4])
        PlayerStatusTexture:SetWidth(statusWidth)
        restingCrop = false
      end
    end

    hooksecurefunc("PlayerFrame_UpdateStatus", UpdateRestingGlow)
    UpdateRestingGlow()
  end


  if target then
    TargetFrameTexture:SetTexture(normalTexture)
    TargetFrameHealthBar:SetPoint("TOPRIGHT", -106, -22)
    TargetFrameHealthBar:SetHeight(30)
  end

  ApplyDarkModeTextures()

  local world = CreateFrame("Frame")
  world:RegisterEvent("PLAYER_ENTERING_WORLD")
  world:SetScript("OnEvent", function()
    ApplyDarkModeTextures()
    this:UnregisterAllEvents()
  end)

  -- Delay hook installation by one frame so all enabled unit-frame modules have
  -- finished their setup first. This keeps hooks attached to final handlers.
  local deferred = CreateFrame("Frame")
  deferred:SetScript("OnUpdate", function()
    this:SetScript("OnUpdate", nil)
    this:Hide()

    local function UpdateTargetClassificationTexture()
      local classification = UnitClassification("target")
      if classification == "worldboss"
        or classification == "rareelite"
        or classification == "elite" then
        TargetFrameTexture:SetTexture(eliteTexture)
      elseif classification == "rare" then
        TargetFrameTexture:SetTexture(rareTexture)
      else
        TargetFrameTexture:SetTexture(normalTexture)
      end

      ApplyDarkModeTextures()
    end

    if target then hooksecurefunc("TargetFrame_CheckClassification", UpdateTargetClassificationTexture) end

    local playerSetStatusBarColor = PlayerFrameHealthBar.SetStatusBarColor
    local targetSetStatusBarColor = TargetFrameHealthBar.SetStatusBarColor

    local function ApplyPlayerHealthColor()
      if not PlayerFrameNameBackground or not playerSetStatusBarColor then return end
      local r, g, b = PlayerFrameNameBackground:GetVertexColor()
      -- Resource hiding sets this color-source texture's alpha to zero. Its
      -- visibility must not propagate to the actual health fill on updates.
      playerSetStatusBarColor(PlayerFrameHealthBar, r, g, b, 1)
    end

    local function ApplyTargetHealthColor()
      if not TargetFrameNameBackground or not targetSetStatusBarColor then return end
      local r, g, b = TargetFrameNameBackground:GetVertexColor()
      targetSetStatusBarColor(TargetFrameHealthBar, r, g, b, 1)
    end

    -- Keep the Big Health colors without replacing SetStatusBarColor with a
    -- no-op. Other addons may still call the original method normally.
    if player and PlayerFrameNameBackground then
      hooksecurefunc(PlayerFrameHealthBar, "SetStatusBarColor", ApplyPlayerHealthColor)
      hooksecurefunc(PlayerFrameNameBackground, "Show", function()
        PlayerFrameNameBackground:Hide()
      end)
      PlayerFrameNameBackground:Hide()
      ApplyPlayerHealthColor()
    end

    if target and TargetFrameNameBackground then
      hooksecurefunc(TargetFrameHealthBar, "SetStatusBarColor", ApplyTargetHealthColor)
      hooksecurefunc(TargetFrameNameBackground, "Show", function()
        TargetFrameNameBackground:Hide()
      end)
      TargetFrameNameBackground:Hide()
      ApplyTargetHealthColor()
    end

    if target then hooksecurefunc("TargetFrame_CheckFaction", ApplyTargetHealthColor) end

    if target then
      UpdateTargetClassificationTexture()
      TargetFrame_CheckFaction()
    end
  end)
end

playerModule.enable = function() Enable(true, false) end
targetModule.enable = function() Enable(false, true) end
