local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local hooksecurefunc = hooksecurefunc or ShaguTweaks.hooksecurefunc

local FALLBACK_CLASS_COLOR = { r = .5, g = .5, b = .5, a = 1 }
local MODERN_HEALTH_TEXTURE = "Interface\\AddOns\\ShaguTweaks\\img\\BlizzardRetailBar"

local module = ShaguTweaks:register({
  title = T["Unit Frame Class Colors"],
  description = T["Adds class colors to the player, target and party unit frames."],
  expansions = { ["vanilla"] = true },
  category = T["Unit Frames"],
  enabled = nil,
})

local function GetUnitClassColor(unit)
  local _, class = UnitClass(unit)
  local palette = ShaguTweaks.ModernClassColors or RAID_CLASS_COLORS
  return palette[class] or FALLBACK_CLASS_COLOR
end

local playerNameOption = ShaguTweaks:register({
  title = T["Player's Name No Class Color"],
  description = T["Removes the class-colored strip behind your player name, including the separate name frame."],
  expansions = { ["vanilla"] = true },
  category = T["Unit Frames"],
  enable = function() end, -- Read by both player name layouts at startup.
})

local petColors = ShaguTweaks:register({
  title = T["Pets Use Owner Class Color"],
  description = T["Colors pet health bars by their owners' classes, including targeted pets whose owners can be identified."],
  expansions = { ["vanilla"] = true },
  category = T["Unit Frames"],
})

petColors.enable = function()
  local refresh = {}
  local function AddPetBar(bar, pet, owner)
    if not bar then return end
    local setColor = bar.SetStatusBarColor
    local function Apply()
      if not UnitExists(pet) or not UnitExists(owner) then return end
      local color = GetUnitClassColor(owner)
      setColor(bar, color.r, color.g, color.b, 1)
    end
    refresh[owner] = Apply
    ShaguTweaks.hooksecurefunc(bar, "SetStatusBarColor", Apply)
    Apply()
  end
  AddPetBar(PetFrameHealthBar, "pet", "player")
  for id = 1, MAX_PARTY_MEMBERS do
    AddPetBar(_G["PartyMemberFrame" .. id .. "PetFrameHealthBar"], "partypet" .. id, "party" .. id)
  end

  local function GetTargetOwner()
    if not UnitExists("target") then return end
    if UnitIsUnit("target", "pet") then return "player" end
    for id = 1, MAX_PARTY_MEMBERS do
      if UnitIsUnit("target", "partypet" .. id) then return "party" .. id end
    end
    local api = ShaguTweaks.API
    if api and api.UnitTokenFromGUID and _G.UnitIsPet and _G.UnitOwnerGUID and _G.UnitIsPet("target") then
      local guid = _G.UnitOwnerGUID("target")
      local owner = guid and api.UnitTokenFromGUID(guid)
      if owner and UnitIsPlayer(owner) then return owner end
    end
  end

  local function RefreshTarget() end
  if TargetFrameHealthBar then
    local bar = TargetFrameHealthBar
    local setColor = bar.SetStatusBarColor
    local r, g, b, a = bar:GetStatusBarColor()
    local targetColor
    RefreshTarget = function()
      local owner = GetTargetOwner()
      local previous = targetColor
      targetColor = owner and GetUnitClassColor(owner)
      if targetColor then
        setColor(bar, targetColor.r, targetColor.g, targetColor.b, 1)
      elseif previous then
        setColor(bar, r, g, b, a or 1)
      end
    end
    -- Big Health installs its setter hook later. Calls through the captured
    -- setter still reach this hook, so the owner color wins over reaction blue.
    ShaguTweaks.hooksecurefunc(bar, "SetStatusBarColor", function(_, red, green, blue, alpha)
      r, g, b, a = red, green, blue, alpha
      if targetColor then setColor(bar, targetColor.r, targetColor.g, targetColor.b, 1) end
    end)
    ShaguTweaks.hooksecurefunc("TargetFrame_CheckFaction", RefreshTarget)
    RefreshTarget()
  end

  local events = CreateFrame("Frame")
  events:RegisterEvent("UNIT_PET")
  events:RegisterEvent("PARTY_MEMBERS_CHANGED")
  events:RegisterEvent("PLAYER_ENTERING_WORLD")
  events:SetScript("OnEvent", function()
    if event == "UNIT_PET" then
      local apply = refresh[arg1]
      if apply then apply() end
    else
      for _, apply in pairs(refresh) do apply() end
    end
    RefreshTarget()
  end)
end

local function SetTextColorIfChanged(fontString, r, g, b, a)
  local cr, cg, cb, ca = fontString:GetTextColor()
  if cr ~= r or cg ~= g or cb ~= b or ca ~= a then
    fontString:SetTextColor(r, g, b, a)
  end
end

local function SetVertexColorIfChanged(texture, r, g, b, a)
  local cr, cg, cb, ca = texture:GetVertexColor()
  if cr ~= r or cg ~= g or cb ~= b or ca ~= a then
    texture:SetVertexColor(r, g, b, a)
  end
end

local function UpdatePartyColors()
  for id = 1, MAX_PARTY_MEMBERS do
    local name = _G["PartyMemberFrame" .. id .. "Name"]
    if name then
      local color = GetUnitClassColor("party" .. id)
      SetTextColorIfChanged(name, color.r, color.g, color.b, 1)
    end
  end
end

module.enable = function(self)
  local function UpdateTargetClassColor()
    if not TargetFrameNameBackground then return end

    local reaction = UnitReaction("target", "player")
    if UnitIsPlayer("target") then
      local color = GetUnitClassColor("target")
      SetVertexColorIfChanged(TargetFrameNameBackground,
        color.r, color.g, color.b, 1)
      TargetFrameNameBackground:Show()
    elseif reaction and reaction > 4 then
      TargetFrameNameBackground:Hide()
    else
      TargetFrameNameBackground:Show()
    end
  end

  -- Let Blizzard and other addons finish their target-faction handling first,
  -- then apply the class-color background instead of replacing the global.
  hooksecurefunc("TargetFrame_CheckFaction", UpdateTargetClassColor)

  local playerColor = GetUnitClassColor("player")

  -- add name background to player frame
  PlayerFrameNameBackground = PlayerFrame:CreateTexture(nil, "BACKGROUND")
  PlayerFrameNameBackground:SetTexture(ShaguTweaks.ModernClassColors and MODERN_HEALTH_TEXTURE
    or "Interface\\TargetingFrame\\UI-TargetingFrame-LevelBackground")
  PlayerFrameNameBackground:SetWidth(119)
  PlayerFrameNameBackground:SetHeight(19)
  PlayerFrameNameBackground:SetPoint("TOPLEFT", 106, -22)
  PlayerFrameNameBackground:SetVertexColor(playerColor.r, playerColor.g, playerColor.b, 1)
  -- Big Health still reads this texture's class tint when its artwork is hidden.
  if ShaguTweaks_config and ShaguTweaks_config[playerNameOption.title] == 1 then
    PlayerFrameNameBackground:Hide()
  end

  local wait = CreateFrame("Frame")
  wait:RegisterEvent("PLAYER_ENTERING_WORLD")
  wait:SetScript("OnEvent", function()
    local color = GetUnitClassColor("player")
    SetVertexColorIfChanged(PlayerFrameNameBackground,
      color.r, color.g, color.b, 1)
    this:UnregisterAllEvents()

    -- make sure to keep name background above frame shadow
    PlayerFrameNameBackground:SetDrawLayer("BORDER")
    TargetFrameNameBackground:SetDrawLayer("BORDER")
  end)

  -- add font outline
  local font, size = PlayerFrame.name:GetFont()
  PlayerFrame.name:SetFont(font, size, "NONE")
  TargetFrame.name:SetFont(font, size, "NONE")

  -- Update party name colors after the stock member refresh instead of
  -- replacing PartyMemberFrame_UpdateMember. Cached color writes avoid doing
  -- extra rendering work when the class did not change.
  hooksecurefunc("PartyMemberFrame_UpdateMember", UpdatePartyColors)

  UpdateTargetClassColor()
  UpdatePartyColors()
end


-- Retail resource artwork contains its own colors, including light-blue mana.
-- A white tint preserves those native colors and gradients.
local MODERN_POWER_TEXTURES = {
  [0] = "Interface\\AddOns\\ShaguTweaks\\img\\ModernPowerMana",
  [1] = "Interface\\AddOns\\ShaguTweaks\\img\\ModernPowerRage",
  [2] = "Interface\\AddOns\\ShaguTweaks\\img\\ModernPowerFocus",
  [3] = "Interface\\AddOns\\ShaguTweaks\\img\\ModernPowerEnergy",
}
local DEFAULT_BAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"

local function SetupModernPowerBars()
  local bars = {}

  local function ApplyPowerStyle(bar)
    local state = bars[bar]
    if not state then return end
    local unit = bar.unit or state.unit
    if not ShaguTweaks.ModernClassColors or not UnitExists(unit) then
      if state.background:IsShown() then state.background:Hide() end
      return
    end
    -- The druid's secondary bar stays mana while the primary bar is rage/energy.
    local powerType = state.powerType
    if powerType == nil then powerType = UnitPowerType(unit) end
    local texture = MODERN_POWER_TEXTURES[powerType]
    if texture then
      local suffix = state.family
      if suffix == "Player" then
        suffix = ""
        -- Keep the retail energy variant for combo-point users.
        if powerType == 3 then
          local _, class = UnitClass(unit)
          if class == "ROGUE" or class == "DRUID" then suffix = "Class" end
        end
      end
      -- Vanilla mana slots are rectangular. Retail target/small-frame fills
      -- have cut-out corners that leave a visible wedge inside those slots.
      -- Use the native rectangular mana artwork for every mana frame.
      if powerType == 0 then suffix = "Class" end
      if state.styleTexture ~= texture or state.styleSuffix ~= suffix then
        state.styleTexture, state.styleSuffix = texture, suffix
        state.wantedTexture = texture .. suffix
      end
      local wanted = state.wantedTexture
      local current = bar:GetStatusBarTexture()
      if not current or current:GetTexture() ~= wanted then bar:SetStatusBarTexture(wanted) end
      if not state.background:IsShown() then state.background:Show() end
      -- Call the method captured before our hook to avoid recursive updates.
      local r, g, b, a = bar:GetStatusBarColor()
      if not r or math.abs(r - 1) > .0001 or math.abs(g - 1) > .0001
        or math.abs(b - 1) > .0001 or not a or math.abs(a - 1) > .0001 then
        state.setColor(bar, 1, 1, 1, 1)
      end
    else
      -- Unknown/custom power types retain their original texture and tint.
      local current = bar:GetStatusBarTexture()
      if not current or current:GetTexture() ~= state.originalTexture then
        bar:SetStatusBarTexture(state.originalTexture)
      end
      if state.background:IsShown() then state.background:Hide() end
    end
  end

  local definitions = {
    {"PlayerFrameManaBar", "player", "Player"},
    {"PlayerFrameAlternatePowerBar", "player", "Player", 0},
    {"TargetFrameManaBar", "target", "Target"},
    {"PetFrameManaBar", "pet", "Small"},
    {"TargetofTargetManaBar", "targettarget", "Small"},
  }
  for id = 1, MAX_PARTY_MEMBERS do
    table.insert(definitions, {"PartyMemberFrame" .. id .. "ManaBar", "party" .. id, "Party"})
  end
  for _, definition in ipairs(definitions) do
    local bar = _G[definition[1]]
    if bar then
      local texture = bar:GetStatusBarTexture()
      -- Opaque black behind the native alpha edges prevents the old frame's
      -- colored backing from changing the retail gradient's apparent color.
      local background = bar:CreateTexture(nil, "BACKGROUND")
      background:SetAllPoints(bar)
      background:SetTexture(0, 0, 0)
      background:Hide()
      bars[bar] = {
        unit = definition[2],
        family = definition[3],
        powerType = definition[4],
        background = background,
        setColor = bar.SetStatusBarColor,
        originalTexture = (texture and texture:GetTexture()) or DEFAULT_BAR_TEXTURE,
      }
      hooksecurefunc(bar, "SetStatusBarColor", function() ApplyPowerStyle(bar) end)
    end
  end

  local function RefreshPowerBars()
    for bar in pairs(bars) do ApplyPowerStyle(bar) end
  end
  -- Vanilla refreshes power type here. Appending preserves the normal frame
  -- updates, including shapeshifts and targets with a different power type.
  hooksecurefunc("UnitFrame_UpdateManaType", function(frame)
    -- Clients use either an explicit unit frame or the legacy `this` context.
    if type(frame) ~= "table" then frame = this end
    if not frame then return end
    if bars[frame] then ApplyPowerStyle(frame); return end
    if frame.manabar and bars[frame.manabar] then ApplyPowerStyle(frame.manabar); return end
    if not frame.unit then return end
    for bar, state in pairs(bars) do
      if (bar.unit or state.unit) == frame.unit then ApplyPowerStyle(bar) end
    end
  end)
  RefreshPowerBars()
  return RefreshPowerBars
end

local modern = ShaguTweaks:register({
  title = "Modern Class Colors",
  description = "Use modern class colors and retail health/power textures. Enable Unit Frame Class Colors for class-colored unit frames.",
  expansions = { ["vanilla"] = true },
  category = T["Unit Frames"],
  enabled = nil,
})

modern.enable = function(self)
  if self.installed then return end
  self.installed = true
  ShaguTweaks.ModernClassColors = {
    DRUID = {r=1, g=0.49, b=0.04},
    HUNTER = {r=0.67, g=0.83, b=0.45},
    MAGE = {r=0.25, g=0.78, b=0.92},
    PALADIN = {r=0.96, g=0.55, b=0.73},
    PRIEST = {r=1, g=1, b=1},
    ROGUE = {r=1, g=0.96, b=0.41},
    SHAMAN = {r=0, g=0.44, b=0.87},
    WARLOCK = {r=0.53, g=0.53, b=0.93},
    WARRIOR = {r=0.78, g=0.61, b=0.43},
  }
  local RefreshPowerBars = SetupModernPowerBars()
  -- Refresh after every module has initialized, regardless of enable order.
  local deferred = CreateFrame("Frame")
  deferred:SetScript("OnUpdate", function()
    this:SetScript("OnUpdate", nil)
    this:Hide()
    RefreshPowerBars()
    for _, prefix in ipairs({"PlayerFrame", "TargetFrame", "PetFrame", "TargetofTarget", "PartyMemberFrame1", "PartyMemberFrame2", "PartyMemberFrame3", "PartyMemberFrame4"}) do
      local bar = _G[prefix .. "HealthBar"]
      if bar then bar:SetStatusBarTexture(MODERN_HEALTH_TEXTURE) end
    end
    if not PlayerFrameNameBackground then return end
    PlayerFrameNameBackground:SetTexture(MODERN_HEALTH_TEXTURE)
    if TargetFrameNameBackground then TargetFrameNameBackground:SetTexture(MODERN_HEALTH_TEXTURE) end
    local color = GetUnitClassColor("player")
    PlayerFrameNameBackground:SetVertexColor(color.r, color.g, color.b, 1)
    if TargetFrame_CheckFaction then TargetFrame_CheckFaction() end
    UpdatePartyColors()
    -- Big Health reads its tint from the name background.
    if PlayerFrameHealthBar then
      local r, g, b, a = PlayerFrameHealthBar:GetStatusBarColor()
      PlayerFrameHealthBar:SetStatusBarColor(r, g, b, a)
    end
  end)
end
