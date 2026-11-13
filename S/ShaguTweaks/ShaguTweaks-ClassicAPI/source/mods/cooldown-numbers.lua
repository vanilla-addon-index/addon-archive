local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local hooksecurefunc = hooksecurefunc or ShaguTweaks.hooksecurefunc
local GetExpansion = ShaguTweaks.GetExpansion
local TimeConvert = ShaguTweaks.TimeConvert

local module = ShaguTweaks:register({
  title = T["Cooldown Numbers"],
  description = T["Display  the remaining duration as text on every cooldown."],
  expansions = { ["vanilla"] = true },
  category = T["Action Bar"],
  enabled = true,
  color = { r = .3, g = .3, b = .3, a = .9}
})

-- GetTime() wraps after 2^32 milliseconds on affected clients. Cooldown start
-- values keep that wrapped clock representation, so normalize negative deltas
-- by one complete clock cycle.
local TIMER_WRAP_SECONDS = (2 ^ 32) / 1000

local formatter
local nativeCooldowns = setmetatable({}, { __mode = "k" })
local cvarWatcher
local SetCooldown

local function FontSize(parent)
  local size = parent:GetHeight() or 0
  size = size > 0 and size * .64 or 12
  return size > 14 and 14 or size
end

local function NativeNumbersEnabled()
  return type(_G.GetCVar) == "function" and _G.GetCVar("countdownForCooldowns") == "1"
end

local function CanUseNative(cooldown)
  return type(cooldown.GetCountdownFontString) == "function"
    and type(cooldown.SetCountdownFormatter) == "function"
    and type(cooldown.SetMinimumCountdownDuration) == "function"
    and type(cooldown.SetHideCountdownNumbers) == "function"
    and _G.C_StringUtil and type(_G.C_StringUtil.CreateNumericRuleFormatter) == "function"
    and _G.Enum and _G.Enum.NumericRuleFormatRounding
end

local function NativeTarget(cooldown, parent)
  if CanUseNative(cooldown) then return cooldown end
  if cooldown.stCountdownNativeFrame ~= nil then return cooldown.stCountdownNativeFrame or nil end
  if not ShaguTweaks.API.nativecooldowns or not _G.C_StringUtil
    or type(_G.C_StringUtil.CreateNumericRuleFormatter) ~= "function" then return end
  -- Stock Vanilla indicators can still be Models. Keep their sweep untouched
  -- and use an engine-driven child solely for numbers, as the old overlay did.
  local ok, child = pcall(CreateFrame, "Cooldown", nil, cooldown)
  if not ok or not child then
    cooldown.stCountdownNativeFrame = false
    return
  end
  if not CanUseNative(child) then
    child:Hide()
    cooldown.stCountdownNativeFrame = false
    return
  end
  child.stCountdownHelper = true
  child:SetAllPoints(cooldown)
  child:SetFrameLevel(parent:GetFrameLevel() + 1)
  child:SetDrawSwipe(false)
  child:SetDrawEdge(false)
  child:SetDrawBling(false)
  cooldown.stCountdownNativeFrame = child
  return child
end

local function GetFormatter()
  if formatter then return formatter end
  local up = _G.Enum.NumericRuleFormatRounding.Up
  formatter = _G.C_StringUtil.CreateNumericRuleFormatter()
  -- Match TimeConvert, including its colors before rounding at 5/10 seconds.
  formatter:SetBreakpoints({
    { threshold = 0, step = 1, rounding = up, format = "|cffff5555%d" },
    { threshold = 5, step = 1, rounding = up, format = "|cffffff55%d" },
    { threshold = 10, step = 1, rounding = up, format = "|cffffffff%d" },
    { threshold = 60, format = "|cffffffff%dm", components = { { div = 60, step = 1, rounding = up } } },
    { threshold = 3600, format = "|cffffffff%dh", components = { { div = 3600, step = 1, rounding = up } } },
    { threshold = 86400, format = "|cffffffff%dd", components = { { div = 86400, step = 1, rounding = up } } },
  })
  return formatter
end

local function RememberNative(cooldown, start, duration, enable)
  nativeCooldowns[cooldown] = true
  cooldown.stCountdownStart, cooldown.stCountdownDuration, cooldown.stCountdownEnable = start, duration, enable
  if cvarWatcher then return end
  cvarWatcher = CreateFrame("Frame")
  cvarWatcher.enabled = NativeNumbersEnabled()
  cvarWatcher:RegisterEvent("CVAR_UPDATE")
  cvarWatcher:SetScript("OnEvent", function()
    local enabled = NativeNumbersEnabled()
    if enabled == cvarWatcher.enabled then return end
    cvarWatcher.enabled = enabled
    for frame in pairs(nativeCooldowns) do
      SetCooldown(frame, frame.stCountdownStart, frame.stCountdownDuration, frame.stCountdownEnable)
    end
  end)
end

local function CooldownOnUpdate()
  -- hide frames without parent
  local parent = this:GetParent()
  if not parent then
    this:Hide()
    return
  end

  -- Text only needs tenth-of-a-second precision. Accumulate the frame elapsed
  -- time instead of calling GetTime() several times on every rendered frame.
  this.elapsed = (this.elapsed or 0) + arg1
  if this.elapsed < .1 then return end
  this.elapsed = 0

  local now = GetTime()

  -- fix own alpha value (should be inherited, but somehow isn't always)
  local alpha = parent:GetAlpha()
  if this:GetAlpha() ~= alpha then
    this:SetAlpha(alpha)
  end

  local elapsed = now - this.start
  if elapsed < 0 then
    elapsed = elapsed + TIMER_WRAP_SECONDS
  end

  local remaining = this.duration - elapsed
  if remaining > 0 then
    local text = TimeConvert(remaining)
    if this.lastText ~= text then
      this.lastText = text
      this.text:SetText(text)
    end
  else
    this:Hide()
  end
end

local function CreateCoolDown(cooldown)
  local parent = cooldown:GetParent()
  if not parent then return end

  -- skip already set debuff timers
  if cooldown.readable then return end

  -- These helpers are owned directly by their cooldown and never need global
  -- names. Anonymous objects avoid collisions for cooldowns with anonymous
  -- parents while preserving the exact same visual hierarchy.
  cooldown.cooldowntext = CreateFrame("Frame", nil, cooldown)
  cooldown.cooldowntext:SetAllPoints(cooldown)
  cooldown.cooldowntext:SetFrameLevel(parent:GetFrameLevel() + 1)
  cooldown.cooldowntext.text = cooldown.cooldowntext:CreateFontString(nil, "OVERLAY")

  -- detect dynamic font size
  local size = FontSize(parent)

  -- set fonts
  cooldown.cooldowntext.text:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE")
  cooldown.cooldowntext.text:SetPoint("CENTER", cooldown.cooldowntext, "CENTER", 0, 0)
  cooldown.cooldowntext:SetScript("OnUpdate", CooldownOnUpdate)
end

SetCooldown = function(this, start, duration, enable)
  if this.stCountdownHelper then return end
  -- Let OmniCC and ShaguPlates own their cooldown text. Also hide an overlay
  -- that may have been created before either compatibility flag was applied.
  if this.noCooldownCount or this.pfCooldownType or this.readable then
    if this.cooldowntext then
      this.cooldowntext:Hide()
    end
    if this.stCountdownNativeFrame then this.stCountdownNativeFrame:Hide() end
    if (this.stNativeCountdown or this.noCooldownCount)
      and type(this.SetHideCountdownNumbers) == "function" then
      this:SetHideCountdownNumbers(true)
    end
    return
  end

  local parent = this:GetParent()
  if parent and (CanUseNative(this) or (ShaguTweaks.API.nativecooldowns
    and _G.C_StringUtil and type(_G.C_StringUtil.CreateNumericRuleFormatter) == "function")) then
    RememberNative(this, start, duration, enable)
    if NativeNumbersEnabled() then
      local target = NativeTarget(this, parent)
      local text = target and target:GetCountdownFontString()
      if text then
        if this.cooldowntext then this.cooldowntext:Hide() end
        if target == this then this.stNativeCountdown = true end
        target:SetCountdownFormatter(GetFormatter())
        -- Native threshold is strictly greater-than; retain duration >= 2s.
        target:SetMinimumCountdownDuration(1999)
        local active = start and start > 0 and duration
          and duration >= 2 and (not enable or enable > 0)
        target:SetHideCountdownNumbers(not active)
        if target ~= this then
          if active then target:SetCooldown(start, duration) else target:Hide() end
        end
        text:SetFont(STANDARD_TEXT_FONT, FontSize(parent), "OUTLINE")
        text:ClearAllPoints()
        text:SetPoint("CENTER", target, "CENTER", 0, 0)
        text:SetTextColor(1, 1, 1, 1)
        return
      end
    end
  end

  -- Never switch on the global CVar: it also controls unrelated addons.
  -- Older builds and CVar-off clients keep the Lua renderer.
  if this.stCountdownNativeFrame then this.stCountdownNativeFrame:Hide() end
  if type(this.SetHideCountdownNumbers) == "function" then this:SetHideCountdownNumbers(true) end

  -- don't draw global cooldowns
  if not duration or duration < 2 then
    -- hide if already existing
    if this.cooldowntext then
      this.cooldowntext:Hide()
    end

    return
  end

  if not this.cooldowntext then
    CreateCoolDown(this)
  end

  if this.cooldowntext then
    if start and start > 0 and duration > 0 and (not enable or enable > 0) then
      this.cooldowntext.elapsed = 0
      this.cooldowntext:Show()
    else
      this.cooldowntext:Hide()
    end

    this.cooldowntext.start = start
    this.cooldowntext.duration = duration
  end
end

module.enable = function(self)
  if GetExpansion() == "vanilla" then
    -- vanilla does not have a cooldown frame type, so we hook the
    -- regular SetTimer function that each one is calling.
    hooksecurefunc("CooldownFrame_SetTimer", SetCooldown)
  else
    -- tbc and later expansion have a cooldown frametype, so we can
    -- hook directly into the frame creation and add our function there.
    local methods = getmetatable(CreateFrame('Cooldown', nil, nil, 'CooldownFrameTemplate')).__index
    hooksecurefunc(methods, 'SetCooldown', SetCooldown)
  end
end
