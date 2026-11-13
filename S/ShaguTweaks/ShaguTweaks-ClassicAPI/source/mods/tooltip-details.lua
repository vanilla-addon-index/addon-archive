local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local round = ShaguTweaks.round
local rgbhex = ShaguTweaks.rgbhex
local Abbreviate = ShaguTweaks.Abbreviate
local API = ShaguTweaks.API

local DEFAULT_HEALTH_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local MODERN_HEALTH_TEXTURE = "Interface\\AddOns\\ShaguTweaks\\img\\BlizzardRetailBar"

local function SetTooltipHealthTexture(texture)
  GameTooltipStatusBar:SetStatusBarTexture(texture)
  if GameTooltipStatusBar.bg then
    GameTooltipStatusBar.bg:SetTexture(texture)
  end
end

local tooltipSetStatusBarColor

local function GetUnit()
  local guid = API.GetTooltipUnitGUID(GameTooltip)
  if not guid then return end
  local unit = API.UnitTokenFromGUID(guid)
  -- Positional tokens can be recycled between tooltip and unit queries.
  if unit and API.UnitGUID and API.UnitGUID(unit) ~= guid then return end
  return unit
end

local function GetTargetUnit(unit)
  -- The interaction-only NPC token has no valid "npctarget" derivative.
  if unit == "npc" then return end
  local targetUnit = unit .. "target"
  -- A valid base token need not support target suffixes. Probe defensively
  -- before passing a derived token to the rest of the unit API.
  local ok, exists = pcall(UnitExists, targetUnit)
  if ok and exists then return targetUnit end
end

local function ClearTooltipBarColor()
  GameTooltipStatusBar.ShaguTweaksColorR = nil
  GameTooltipStatusBar.ShaguTweaksColorG = nil
  GameTooltipStatusBar.ShaguTweaksColorB = nil
  GameTooltipStatusBar.ShaguTweaksColorA = nil
end

local function SetTooltipBarColor(r, g, b, a)
  if not r or not g or not b then return end

  GameTooltipStatusBar.ShaguTweaksColorR = r
  GameTooltipStatusBar.ShaguTweaksColorG = g
  GameTooltipStatusBar.ShaguTweaksColorB = b
  GameTooltipStatusBar.ShaguTweaksColorA = a or 1

  if tooltipSetStatusBarColor then
    tooltipSetStatusBarColor(GameTooltipStatusBar, r, g, b, a or 1)
  end
end

local function UpdateHealthText()
  local backdrop = GameTooltipStatusBar.backdrop
  if not backdrop or not backdrop.health then return end

  local hp = GameTooltipStatusBar:GetValue()
  local _, hpmax = GameTooltipStatusBar:GetMinMaxValues()

  local hasRealHealth = hpmax > 100
    or (hpmax > 0 and round(hpmax / 100 * hp) ~= hp)

  if hasRealHealth then
    backdrop.health:SetText(string.format("%s / %s",
      Abbreviate(hp, true), Abbreviate(hpmax, true)))
  elseif hpmax > 0 then
    backdrop.health:SetText(string.format("%s%%", ceil(hp / hpmax * 100)))
  else
    backdrop.health:SetText("")
  end
end

local function ResetTooltipState()
  ClearTooltipBarColor()
  SetTooltipHealthTexture(DEFAULT_HEALTH_TEXTURE)

  if GameTooltipStatusBar.bg then
    GameTooltipStatusBar.bg:SetVertexColor(.1, .1, 0, .8)
  end

  if GameTooltipStatusBar.backdrop
    and GameTooltipStatusBar.backdrop.health then
    GameTooltipStatusBar.backdrop.health:SetText("")
  end
end

local updating = false

local function UpdateTooltipContents()

  -- ClassicAPI keeps the exact tooltip GUID and resolves it back to a live
  -- unit token natively. No party/raid scans or display-name fallback.
  local unit = GetUnit()
  if not unit then
    ResetTooltipState()
    return
  end

  -- Resolve at display time because module initialization order is unspecified.
  SetTooltipHealthTexture(ShaguTweaks.ModernClassColors
    and MODERN_HEALTH_TEXTURE or DEFAULT_HEALTH_TEXTURE)

  -- A newly resolved unit chooses its own class/reaction color below. Clear the
  -- previous enforcement first so a stale color cannot leak between tooltips.
  ClearTooltipBarColor()

  local pvpname = UnitPVPName(unit)
  local name = UnitName(unit)
  local targetUnit = GetTargetUnit(unit)
  local target, targetClass, targetReaction
  if targetUnit then
    target = UnitName(targetUnit)
    local ignored
    ignored, targetClass = UnitClass(targetUnit)
    targetReaction = UnitReaction("player", targetUnit)
  end
  local _, class = UnitClass(unit)
  local guild, rankstr, rankid = GetGuildInfo(unit)
  local reaction = UnitReaction(unit, "player")
  local pvptitle = name and gsub(pvpname or name, " " .. name, "", 1) or nil

  if name then
    if UnitIsPlayer(unit) and class then
      local color = RAID_CLASS_COLORS[class]
      if color then
        -- Match the optional unit-frame palette without changing name text
        -- or NPC reaction colors. The health-bar background follows its tint.
        local modern = ShaguTweaks.ModernClassColors
        local barColor = (modern and modern[class]) or color
        SetTooltipBarColor(barColor.r, barColor.g, barColor.b, 1)
        GameTooltipStatusBar.bg:SetVertexColor(
          barColor.r * 0.15, barColor.g * 0.15, barColor.b * 0.15, 0.8)
        GameTooltipTextLeft1:SetText(
          rgbhex(color.r, color.g, color.b, color.a) .. name)
      else
        GameTooltipTextLeft1:SetText("|cff999999" .. name)
      end
    elseif reaction then
      local color = UnitReactionColor[reaction]
      if color then
        SetTooltipBarColor(color.r, color.g, color.b, 1)
        GameTooltipStatusBar.bg:SetVertexColor(
          color.r * 0.15, color.g * 0.15, color.b * 0.15, 0.8)
      end
    end

    if pvptitle and pvptitle ~= name then
      GameTooltip:AppendText(" |cff666666[" .. pvptitle .. "]|r")
    end
  end

  -- Restore the original guild rank and guild-leader marker. Replace the
  -- native/existing guild line so repeated refreshes do not duplicate it.
  if guild and guild ~= "" then
    local guildName = "<" .. guild .. ">"
    local guildText = guildName
    if rankid == 0 then guildText = guildText .. "|cffffcc00*|r" end
    if rankstr and rankstr ~= "" then
      guildText = guildText .. " |cffaaaaaa(" .. rankstr .. ")|r"
    end

    local guildLine
    for i = 2, GameTooltip:NumLines() do
      local left = _G["GameTooltipTextLeft" .. i]
      local text = left and left:GetText()
      if text then
        local plain = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
        plain = string.gsub(plain, "|r", "")
        if plain == guild or string.sub(plain, 1, string.len(guildName)) == guildName then
          guildLine = left
          break
        end
      end
    end

    if guildLine then
      guildLine:SetText(guildText)
      guildLine:SetTextColor(0.3, 1, 0.5)
    else
      GameTooltip:AddLine(guildText, 0.3, 1, 0.5)
    end
  end

  -- Current target, colored by class or reaction
  local alreadyAdded = false
  if target then
    for i = 2, GameTooltip:NumLines() do
      local left = _G["GameTooltipTextLeft" .. i]
      if left and left:GetText() == target then
        alreadyAdded = true
        break
      end
    end
  end

  if target and not alreadyAdded then
    if UnitIsPlayer(targetUnit) and targetClass then
      local color = RAID_CLASS_COLORS[targetClass]
      if color then
        GameTooltip:AddLine(target, color.r, color.g, color.b)
      else
        GameTooltip:AddLine(target, .5, .5, .5)
      end
    elseif targetReaction then
      local color = UnitReactionColor[targetReaction]
      if color then
        GameTooltip:AddLine(target, color.r, color.g, color.b)
      else
        GameTooltip:AddLine(target, .5, .5, .5)
      end
    end
  end

  UpdateHealthText()
  GameTooltip:Show()
end

local function UpdateTooltip()
  if updating then return end
  updating = true
  local ok, err = pcall(UpdateTooltipContents)
  -- Always release the guard before cleanup/error reporting. One bad unit or
  -- addon hook must not disable tooltip updates for the rest of the session.
  updating = false
  if not ok then
    ResetTooltipState()
    local handler = geterrorhandler and geterrorhandler()
    if type(handler) == "function" then
      handler(err)
    else
      error(err)
    end
  end
end

local module = ShaguTweaks:register({
  title = T["Tooltip Details"],
  description = T["Enriches unit tooltips with health, class color, guild name, rank, and current target."],
  expansions = { ["vanilla"] = true },
  category = T["Tooltip & Items"],
  enabled = true,
  order = 50,
})

local backdrop = {
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 8, edgeSize = 12,
  insets = { left = 3, right = 3, top = 3, bottom = 3 }
}

module.enable = function(self)
  -- Tooltip Details intentionally requires the native ClassicAPI tooltip
  -- identity + OnTooltipSetUnit path. Do not fall back to Vanilla name scans.
  if not API.tooltipsetunit then return end

  GameTooltipStatusBar:SetHeight(10)
  GameTooltipStatusBar:ClearAllPoints()
  GameTooltipStatusBar:SetPoint("BOTTOMLEFT", GameTooltip, "TOPLEFT", 4, 2)
  GameTooltipStatusBar:SetPoint("BOTTOMRIGHT", GameTooltip, "TOPRIGHT", -4, 2)

  GameTooltipStatusBar.bg = GameTooltipStatusBar:CreateTexture(nil, "BACKGROUND")
  GameTooltipStatusBar.bg:SetTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
  GameTooltipStatusBar.bg:SetVertexColor(.1, .1, 0, .8)
  GameTooltipStatusBar.bg:SetAllPoints(true)

  GameTooltipStatusBar.backdrop =
    CreateFrame("Frame", "GameTooltipStatusBarBackdrop", GameTooltipStatusBar)
  GameTooltipStatusBar.backdrop:SetPoint(
    "TOPLEFT", GameTooltipStatusBar, "TOPLEFT", -3, 3)
  GameTooltipStatusBar.backdrop:SetPoint(
    "BOTTOMRIGHT", GameTooltipStatusBar, "BOTTOMRIGHT", 3, -3)
  GameTooltipStatusBar.backdrop:SetBackdrop(backdrop)
  GameTooltipStatusBar.backdrop:SetBackdropBorderColor(.8,.8,.8,1)

  GameTooltipStatusBar.backdrop.health =
    GameTooltipStatusBar.backdrop:CreateFontString(
      "Status", "DIALOG", "GameFontWhite")
  GameTooltipStatusBar.backdrop.health:SetFont(
    STANDARD_TEXT_FONT, 12, "OUTLINE")
  -- centered on the bar: anchored to the top it stuck out over the border
  GameTooltipStatusBar.backdrop.health:SetPoint("CENTER", GameTooltipStatusBar, "CENTER", 0, 1)
  GameTooltipStatusBar.backdrop.health:SetNonSpaceWrap(false)

  -- Preserve the real statusbar method for Blizzard and other addons. A
  -- post-hook reapplies ShaguTweaks' class/reaction color only while a unit
  -- tooltip has an active desired color.
  tooltipSetStatusBarColor =
    tooltipSetStatusBarColor or GameTooltipStatusBar.SetStatusBarColor
  if not self.statusColorHooked then
    self.statusColorHooked = true
    ShaguTweaks.hooksecurefunc(
      GameTooltipStatusBar, "SetStatusBarColor", function()
        local r = GameTooltipStatusBar.ShaguTweaksColorR
        local g = GameTooltipStatusBar.ShaguTweaksColorG
        local b = GameTooltipStatusBar.ShaguTweaksColorB
        local a = GameTooltipStatusBar.ShaguTweaksColorA
        if r and g and b then
          tooltipSetStatusBarColor(
            GameTooltipStatusBar, r, g, b, a or 1)
        end
      end)
  end

  -- ClassicAPI fires this after the native unit-tooltip builder completes.
  -- This replaces OnShow + UPDATE_MOUSEOVER_UNIT identity refreshes.
  GameTooltip:HookScript("OnTooltipSetUnit", UpdateTooltip)
  -- OnTooltipCleared fires for every new Set* path, not only when the frame
  -- hides, so unit-only state cannot leak into a following item/spell tooltip.
  GameTooltip:HookScript("OnTooltipCleared", ResetTooltipState)

  -- StatusBar already has a native value-change script, so health text can be
  -- event-driven too. No permanent OnUpdate is needed.
  GameTooltipStatusBar:HookScript("OnValueChanged", UpdateHealthText)
end
