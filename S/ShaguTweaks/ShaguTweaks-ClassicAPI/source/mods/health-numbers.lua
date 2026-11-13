local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local Abbreviate = ShaguTweaks.Abbreviate
local hooksecurefunc = hooksecurefunc or ShaguTweaks.hooksecurefunc

local module = ShaguTweaks:register({
  title = T["Real Health Numbers"],
  description = T["Shows health and power numbers on player, pet and target unit frames. On Vanilla servers, target health may be estimated when exact values are unavailable."],
  expansions = { ["vanilla"] = true },
  category = T["Unit Frames"],
  enabled = nil,
})

local function SetNumberColor(text)
  if ShaguTweaks.WhiteUnitFrameNumbers then
    text:SetTextColor(1, 1, 1, 1)
  else
    text:SetTextColor(1, 0.82, 0, 1)
  end
end

module.enable = function(self)
  if ShaguTweaks.RealHealthNumbersInstalled then return end
  ShaguTweaks.RealHealthNumbersInstalled = true

  if ShaguTweaks.libhealth and ShaguTweaks.libhealth.Enable then
    ShaguTweaks.libhealth:Enable()
  end

  local function HideNativeText(text)
    if text and text.SetAlpha then
      text:SetAlpha(0)
    end
  end

  local nativeTexts = {
    PlayerFrameHealthBar and PlayerFrameHealthBar.TextString,
    PlayerFrameManaBar and PlayerFrameManaBar.TextString,
    TargetFrameHealthBar and TargetFrameHealthBar.TextString,
    TargetFrameManaBar and TargetFrameManaBar.TextString,
    PetFrameHealthBar and PetFrameHealthBar.TextString,
    PetFrameManaBar and PetFrameManaBar.TextString,
    _G.PlayerFrameAlternatePowerBarText,
    _G.TargetHPText,
    _G.TargetHPPercText,
  }

  for _, text in pairs(nativeTexts) do
    HideNativeText(text)
  end

  self.valueTexts = self.valueTexts or {}

  local function CreateValueText(parent, fontSize)
    if not parent then return end

    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontWhite")
    -- Match the character name: plain glyphs instead of a heavy black outline.
    text:SetFont(STANDARD_TEXT_FONT, fontSize or 10, "")
    text:SetHeight(32)
    text:SetJustifyH("CENTER")
    SetNumberColor(text)
    return text
  end

  local function AnchorText(text, bar, y)
    if not text or not bar then return end

    text:ClearAllPoints()
    text:SetPoint("CENTER", bar, "CENTER", 0, y or 0)
  end

  if not self.valueTexts.playerHealth then
    self.valueTexts.playerHealth = CreateValueText(PlayerFrameHealthBar, 10)
    self.valueTexts.playerMana = CreateValueText(PlayerFrameManaBar, 10)
    self.valueTexts.targetHealth = CreateValueText(TargetFrameHealthBar, 10)
    self.valueTexts.targetMana = CreateValueText(TargetFrameManaBar, 10)

    local petTextParent
    if PetFrame and (PetFrameHealthBar or PetFrameManaBar) then
      self.petTextOverlay = CreateFrame("Frame", nil, PetFrame)
      self.petTextOverlay:SetAllPoints(PetFrame)

      local petTextLevel = PetFrame:GetFrameLevel()
      if PetFrameHealthBar then
        petTextLevel = math.max(petTextLevel, PetFrameHealthBar:GetFrameLevel())
      end
      if PetFrameManaBar then
        petTextLevel = math.max(petTextLevel, PetFrameManaBar:GetFrameLevel())
      end

      -- Keep the text on PetFrame's strata while rendering it above the
      -- nested pet artwork and status bars.
      self.petTextOverlay:SetFrameLevel(petTextLevel + 5)
      petTextParent = self.petTextOverlay
    end

    if PetFrameHealthBar then
      self.valueTexts.petHealth = CreateValueText(petTextParent or PetFrameHealthBar, 9)
    end

    if PetFrameManaBar then
      self.valueTexts.petMana = CreateValueText(petTextParent or PetFrameManaBar, 9)
    end

    if _G.PlayerFrameAlternatePowerBar then
      self.valueTexts.playerAlternatePower =
        CreateValueText(_G.PlayerFrameAlternatePowerBar, 10)
    end
  end

  local function AnchorHealth(text, bar, y)
    if not text or not bar then return end
    if not text.percentText then
      text.percentText = CreateValueText(text:GetParent(), select(2, text:GetFont()))
    end
    text:ClearAllPoints()
    text:SetJustifyH("RIGHT")
    text:SetPoint("RIGHT", bar, "RIGHT", -4, y or 0)
    text.percentText:ClearAllPoints()
    text.percentText:SetJustifyH("LEFT")
    text.percentText:SetPoint("LEFT", bar, "LEFT", 4, y or 0)
  end

  local function MatchNameStyle(text, name)
    if not text or not name or not name.GetFont then return end
    local font, size, flags = name:GetFont()
    if font and size then text:SetFont(font, size, flags or "") end
    if name.GetShadowColor then
      text:SetShadowColor(name:GetShadowColor())
    end
    if name.GetShadowOffset then
      text:SetShadowOffset(name:GetShadowOffset())
    end
    if text.percentText then MatchNameStyle(text.percentText, name) end
  end

  local function PositionTexts()
    -- Keep the stock/modern texture choice with the numeric frame overlays.
    local texture = (ShaguTweaks.ModernClassColors and "Interface\\AddOns\\ShaguTweaks\\img\\BlizzardRetailBar" or "Interface\\TargetingFrame\\UI-StatusBar")
    for _, name in ipairs({"PlayerFrameHealthBar", "TargetFrameHealthBar", "PetFrameHealthBar"}) do
      local bar = _G[name]
      if bar then bar:SetStatusBarTexture(texture) end
    end
    local playerHealthY = PlayerFrameHealthBar:GetHeight() >= 20 and -7 or 0.5
    -- The native Big Health frame reserves the top for the player's name.
    local targetHealthY = TargetFrameHealthBar:GetHeight() >= 20 and -7 or 0.5

    AnchorHealth(self.valueTexts.playerHealth, PlayerFrameHealthBar, playerHealthY)
    AnchorText(self.valueTexts.playerMana, PlayerFrameManaBar, 0.5)
    AnchorHealth(self.valueTexts.targetHealth, TargetFrameHealthBar, targetHealthY)
    AnchorText(self.valueTexts.targetMana, TargetFrameManaBar, 0.5)
    AnchorHealth(self.valueTexts.petHealth, PetFrameHealthBar, 0)
    AnchorText(self.valueTexts.petMana, PetFrameManaBar, -2)

    if _G.PlayerFrameAlternatePowerBar then
      AnchorText(
        self.valueTexts.playerAlternatePower,
        _G.PlayerFrameAlternatePowerBar,
        0
      )
    end
    -- Read final name styling after other unit-frame modules initialize.
    local playerName = (PlayerFrame and PlayerFrame.name) or _G.PlayerName
    local targetName = (TargetFrame and TargetFrame.name) or _G.TargetFrameName
    local petName = (PetFrame and PetFrame.name) or _G.PetName or playerName
    MatchNameStyle(self.valueTexts.playerHealth, playerName)
    MatchNameStyle(self.valueTexts.playerMana, playerName)
    MatchNameStyle(self.valueTexts.playerAlternatePower, playerName)
    MatchNameStyle(self.valueTexts.targetHealth, targetName)
    MatchNameStyle(self.valueTexts.targetMana, targetName)
    MatchNameStyle(self.valueTexts.petHealth, petName)
    MatchNameStyle(self.valueTexts.petMana, petName)
  end

  local function SetValue(text, value)
    if not text then return end

    if value == nil then
      text:SetText("")
      text:Hide()
      return
    end

    SetNumberColor(text)
    text:SetText(tostring(Abbreviate(value)))
    text:Show()
  end

  local function UpdateHealth(text, unit, useEstimator)
    if not text then return end
    local percentText = text.percentText
    if percentText then percentText:SetText(""); percentText:Hide() end

    if not UnitExists(unit) then
      text:SetText("")
      text:Hide()
      return
    end

    if unit == "target" and (UnitIsDead("target") or UnitIsGhost("target")) then
      text:SetText("")
      text:Hide()
      return
    end

    local cur = UnitHealth(unit)
    local max = UnitHealthMax(unit)
    local known = true

    if useEstimator and ShaguTweaks.libhealth
      and ShaguTweaks.libhealth.GetUnitHealth then
      cur, max, known = ShaguTweaks.libhealth:GetUnitHealth(unit)
    end

    if not max or max <= 0 then
      text:SetText("")
      text:Hide()
      return
    end

    if useEstimator and not known and max == 100 then
      text:SetText("")
      text:Hide()
      if percentText then
        percentText:SetText(tostring(cur or 0) .. "%")
        percentText:Show()
      end
      return
    end

    local percent = math.floor(math.max(0, math.min(1, (cur or 0) / max)) * 100 + 0.5)
    SetNumberColor(text)
    text:SetText(tostring(Abbreviate(cur or 0)))
    if percentText then
      SetNumberColor(percentText)
      percentText:SetText(percent .. "%")
      percentText:Show()
    end
    text:Show()
  end

  local function UpdatePower(text, unit)
    if not text then return end

    if not UnitExists(unit) then
      text:SetText("")
      text:Hide()
      return
    end

    local max = UnitManaMax(unit)
    if not max or max <= 0 then
      text:SetText("")
      text:Hide()
      return
    end

    SetValue(text, UnitMana(unit) or 0)
  end

  local function UpdatePlayer()
    UpdateHealth(self.valueTexts.playerHealth, "player", false)
    UpdatePower(self.valueTexts.playerMana, "player")
  end

  local function UpdateTarget()
    UpdateHealth(self.valueTexts.targetHealth, "target", true)
    UpdatePower(self.valueTexts.targetMana, "target")
  end

  local function UpdatePet()
    UpdateHealth(self.valueTexts.petHealth, "pet", false)
    UpdatePower(self.valueTexts.petMana, "pet")
  end

  local function UpdateAlternatePower()
    local bar = _G.PlayerFrameAlternatePowerBar
    local text = self.valueTexts.playerAlternatePower
    if not bar or not text then return end

    if not bar:IsShown() then
      text:SetText("")
      text:Hide()
      return
    end

    local _, max = bar:GetMinMaxValues()
    if not max or max <= 0 then
      text:SetText("")
      text:Hide()
      return
    end

    local value = bar:GetValue() or 0
    SetValue(text, math.floor(value + 0.5))
  end

  self.valueEvents = self.valueEvents or CreateFrame("Frame")
  local events = self.valueEvents
  local healthTexts = { player = self.valueTexts.playerHealth,
    target = self.valueTexts.targetHealth, pet = self.valueTexts.petHealth }
  local powerTexts = { player = self.valueTexts.playerMana,
    target = self.valueTexts.targetMana, pet = self.valueTexts.petMana }

  events:RegisterEvent("PLAYER_ENTERING_WORLD")
  events:RegisterEvent("PLAYER_TARGET_CHANGED")
  events:RegisterEvent("PET_UI_UPDATE")
  ShaguTweaks.API.RegisterUnitEvent(events, "UNIT_HEALTH", "player", "target", "pet")
  ShaguTweaks.API.RegisterUnitEvent(events, "UNIT_MAXHEALTH", "player", "target", "pet")
  ShaguTweaks.API.RegisterUnitEvent(events, "UNIT_MANA", "player", "target", "pet")
  ShaguTweaks.API.RegisterUnitEvent(events, "UNIT_MAXMANA", "player", "target", "pet")
  ShaguTweaks.API.RegisterUnitEvent(events, "UNIT_RAGE", "player", "target", "pet")
  ShaguTweaks.API.RegisterUnitEvent(events, "UNIT_MAXRAGE", "player", "target", "pet")
  ShaguTweaks.API.RegisterUnitEvent(events, "UNIT_ENERGY", "player", "target", "pet")
  ShaguTweaks.API.RegisterUnitEvent(events, "UNIT_MAXENERGY", "player", "target", "pet")
  ShaguTweaks.API.RegisterUnitEvent(events, "UNIT_FOCUS", "player", "target", "pet")
  ShaguTweaks.API.RegisterUnitEvent(events, "UNIT_MAXFOCUS", "player", "target", "pet")
  ShaguTweaks.API.RegisterUnitEvent(events, "UNIT_HAPPINESS", "player", "target", "pet")
  ShaguTweaks.API.RegisterUnitEvent(events, "UNIT_MAXHAPPINESS", "player", "target", "pet")
  ShaguTweaks.API.RegisterUnitEvent(events, "UNIT_DISPLAYPOWER", "player", "target", "pet")

  events:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" then
      PositionTexts()
      UpdatePlayer()
      UpdateTarget()
      UpdatePet()
      UpdateAlternatePower()
    elseif event == "PLAYER_TARGET_CHANGED" then
      UpdateTarget()
    elseif event == "PET_UI_UPDATE" then
      UpdatePet()
    elseif arg1 == "player" or arg1 == "target" or arg1 == "pet" then
      local unit = arg1
      if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        UpdateHealth(healthTexts[unit], unit, unit == "target")
      else
        UpdatePower(powerTexts[unit], unit)
        if unit == "player" then UpdateAlternatePower() end
      end
    end
  end)

  local alternatePowerBar = _G.PlayerFrameAlternatePowerBar
  if alternatePowerBar and self.valueTexts.playerAlternatePower then
    hooksecurefunc(alternatePowerBar, "SetValue", UpdateAlternatePower)
    hooksecurefunc(alternatePowerBar, "Show", UpdateAlternatePower)
    hooksecurefunc(alternatePowerBar, "Hide", UpdateAlternatePower)
  end

  -- All enabled modules are initialized during VARIABLES_LOADED in an
  -- unspecified table order. Reposition once on the next frame so this module
  -- automatically fits either the stock bars or Unit Frame Big Health.
  local deferred = CreateFrame("Frame")
  deferred:SetScript("OnUpdate", function()
    this:SetScript("OnUpdate", nil)
    this:Hide()

    PositionTexts()

    for _, text in pairs(nativeTexts) do
      HideNativeText(text)
    end

    UpdatePlayer()
    UpdateTarget()
    UpdatePet()
    UpdateAlternatePower()
  end)
end

-- Kept separate from Modern Class Colors so either texture style can use white.
local whiteNumbers = ShaguTweaks:register({
  title = T["White Unit Frame Numbers"],
  description = T["Use white instead of the default gold for health, percentage and power numbers. Requires Real Health Numbers."],
  expansions = { ["vanilla"] = true },
  category = T["Unit Frames"],
  enabled = nil,
})

whiteNumbers.enable = function(self)
  ShaguTweaks.WhiteUnitFrameNumbers = true
  -- Module initialization order is unspecified. Existing texts are recolored
  -- here; texts created later read the flag through SetNumberColor.
  for _, text in pairs(module.valueTexts or {}) do
    SetNumberColor(text)
    if text.percentText then SetNumberColor(text.percentText) end
  end
end
