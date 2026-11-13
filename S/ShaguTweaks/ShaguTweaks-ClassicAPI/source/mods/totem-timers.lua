-- Totem Timers (Shaman)
--
-- One icon per active totem (Fire, Earth, Water, Air) with the time left.
-- Left-click targets the totem, hovering shows its tooltip. The data comes
-- from ClassicAPI's totem APIs. Native duration timers animate where available;
-- older builds use a light update only while a totem is up.

local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local API = ShaguTweaks.API

local module = ShaguTweaks:register({
  title = T["Totem Timers"],
  description = T["Shamans: shows the totems you have out as icons with the time left. Left-click targets a totem. Hold <Ctrl>, <Shift> and <Alt> to move them; right-click to reset."],
  expansions = { ["vanilla"] = true },
  category = T["Interface"],
  enabled = false,
})

local SIZE = 34
local GAP = 4
local THROTTLE = .1
local POSITION_KEY = "TotemTimersPosition"

-- slot 1 Fire, 2 Earth, 3 Water, 4 Air
local SLOT_COLORS = {
  { 1, .45, .1 },  -- fire
  { .7, .55, .3 }, -- earth
  { .3, .6, 1 },   -- water
  { .8, .85, 1 },  -- air
}

local PREVIEW_ICONS = {
  "Interface\\Icons\\Spell_Fire_SearingTotem",
  "Interface\\Icons\\Spell_Nature_StrengthOfEarthTotem02",
  "Interface\\Icons\\Spell_Nature_ManaRegenTotem",
  "Interface\\Icons\\Spell_Nature_InvisibilityTotem",
}

-- One table for state: Lua 5.0 allows only 32 upvalues per function.
local S = { unlocked = false, elapsed = 0, buttons = {} }

local function Supported()
  return type(_G.GetTotemInfo) == "function" and type(_G.GetTotemTimeLeft) == "function"
end

local function FormatTime(seconds)
  if seconds >= 60 then
    return string.format("%d:%02d", math.floor(seconds / 60), math.floor(seconds - math.floor(seconds / 60) * 60))
  end
  return string.format("%d", seconds)
end

local function StopButton(b)
  if b.expiry then b.expiry:Cancel(); b.expiry = nil end
  if b.binding then b.binding:Disable(); b.bar:SetMinMaxValues(0, 1); b.bar:SetValue(1) end
  b.active = nil
end

local function Layout()
  local shown = 0
  for slot = 1, 4 do
    local b = S.buttons[slot]
    if b:IsShown() then
      b:ClearAllPoints()
      b:SetPoint("LEFT", S.frame, "LEFT", (slot - 1) * (SIZE + GAP), 0)
      shown = shown + 1
    end
  end
  return shown
end

-- Redraw the time and bar of the visible buttons; returns how many are up.
local function UpdateTimes()
  local active = 0
  for slot = 1, 4 do
    local b = S.buttons[slot]
    if b:IsShown() and not S.unlocked then
      local left = _G.GetTotemTimeLeft(slot) or 0
      if left > 0 then
        active = active + 1
        b.time:SetText(FormatTime(left))
        if left <= 5 then
          b.time:SetTextColor(1, .2, .2)
        elseif left <= 10 then
          b.time:SetTextColor(1, .9, .2)
        else
          b.time:SetTextColor(1, 1, 1)
        end
        if b.duration and b.duration > 0 then
          b.bar:SetWidth(math.max(1, SIZE * math.min(left / b.duration, 1)))
        end
      else
        -- duration ran out, the creature is about to go
        b.time:SetText("")
        b.bar:SetWidth(1)
      end
    end
  end
  return active
end

-- Re-read the four slots. Active totem = start time above 0; "have a totem"
-- is also true when you only carry the totem tool.
local function Refresh()
  if S.unlocked then return end

  local any = false
  for slot = 1, 4 do
    local b = S.buttons[slot]
    local have, name, start, duration, icon = _G.GetTotemInfo(slot)
    local nativeDuration = S.native and _G.GetTotemDuration(slot)
    if start and start > 0 and (not nativeDuration or nativeDuration:GetRemainingDuration() > 0) then
      any = true
      b.duration = duration
      if icon and icon ~= "" then b.icon:SetTexture(icon) end
      b:Show()
      if S.native then
        StopButton(b)
        b.active = true
        b.bar:SetWidth(SIZE)
        b.bar:SetTimerDuration(nativeDuration, _G.Enum.StatusBarInterpolation.Immediate,
          _G.Enum.StatusBarTimerDirection.RemainingTime)
        b.binding:SetDuration(nativeDuration)
        b.binding:Enable()
        b.expiry = _G.C_Timer.NewTimer(nativeDuration:GetRemainingDuration(), b.expire)
      end
    else
      StopButton(b)
      b.duration = nil
      b:Hide()
    end
  end

  if any then
    Layout()
    if not S.native then UpdateTimes() end
    if not S.frame:IsShown() then S.frame:Show() end
  else
    S.frame:Hide()
  end
end

local function OnUpdate()
  S.elapsed = S.elapsed + (arg1 or 0)
  if S.elapsed < THROTTLE then return end
  S.elapsed = 0
  UpdateTimes()
end

local function RestorePosition()
  local pos = ShaguTweaks_config and ShaguTweaks_config[POSITION_KEY]
  S.frame:ClearAllPoints()
  if pos and pos[1] and pos[2] then
    S.frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", pos[1], pos[2])
  else
    S.frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 200)
  end
end

local ModifiersDown = ShaguTweaks.API.AreMoveModifiersDown

-- Hold Ctrl+Shift+Alt to show four preview icons and drag them.
local function SetUnlocked(on)
  if S.unlocked == on then return end
  S.unlocked = on
  S.frame:EnableMouse(on)

  if on then
    for slot = 1, 4 do
      local b = S.buttons[slot]
      StopButton(b)
      b:EnableMouse(false) -- let the drag reach the container
      b.icon:SetTexture(PREVIEW_ICONS[slot])
      b.time:SetText(FormatTime(60 - slot * 10))
      b.time:SetTextColor(1, 1, 1)
      b.bar:SetWidth(SIZE)
      b:Show()
    end
    Layout()
    S.frame:Show()
  else
    S.frame:StopMovingOrSizing()
    for slot = 1, 4 do S.buttons[slot]:EnableMouse(true); S.buttons[slot]:Hide() end
    S.frame:Hide()
    Refresh()
  end
end

local function CreateButton(slot)
  local b = CreateFrame("Button", "ShaguTweaksTotem" .. slot, S.frame)
  b:SetWidth(SIZE)
  b:SetHeight(SIZE)
  b:Hide()

  b.border = b:CreateTexture(nil, "BACKGROUND")
  b.border:SetTexture("Interface\\Buttons\\WHITE8X8")
  b.border:SetPoint("TOPLEFT", b, "TOPLEFT", -1, 1)
  b.border:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
  b.border:SetVertexColor(SLOT_COLORS[slot][1], SLOT_COLORS[slot][2], SLOT_COLORS[slot][3])

  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetAllPoints(b)
  b.icon:SetTexCoord(.08, .92, .08, .92)

  b.time = b:CreateFontString(nil, "OVERLAY")
  b.time:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
  b.time:SetPoint("CENTER", b, "CENTER", 0, 0)
  b.time:SetTextColor(1, 1, 1)

  -- remaining time as a thin bar under the icon
  b.bar = CreateFrame("StatusBar", nil, b)
  b.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
  b.bar:SetMinMaxValues(0, 1)
  b.bar:SetValue(1)
  b.bar:SetWidth(SIZE)
  b.bar:SetHeight(3)
  b.bar:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -2)
  b.bar:SetStatusBarColor(SLOT_COLORS[slot][1], SLOT_COLORS[slot][2], SLOT_COLORS[slot][3])
  if S.native and type(b.bar.SetTimerDuration) ~= "function" then S.native = false end
  if S.native then
    b.binding = _G.C_DurationUtil.CreateDurationTextBinding()
    b.binding:SetFontString(b.time)
    b.binding:SetFormatter(S.formatter)
    b.binding:SetExpiredText("")
    b.binding:SetUpdateInterval(.1)
    b.expire = function()
      b.expiry = nil
      StopButton(b)
      b:Hide()
      for i = 1, 4 do if S.buttons[i].active then return end end
      if not S.unlocked then S.frame:Hide() end
    end
  end

  b:RegisterForClicks("LeftButtonUp")
  b:SetScript("OnClick", function()
    if S.unlocked then return end
    if type(_G.TargetTotem) == "function" then _G.TargetTotem(slot) end
  end)
  b:SetScript("OnEnter", function()
    if S.unlocked then return end
    if GameTooltip.SetTotem then
      -- shows itself, no :Show() needed
      GameTooltip:SetOwner(this, "ANCHOR_TOP")
      GameTooltip:SetTotem(slot)
    end
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)

  S.buttons[slot] = b
end

local function CreateTimers()
  if S.frame then return end

  local f = CreateFrame("Frame", "ShaguTweaksTotemTimers", UIParent)
  f:SetWidth(4 * SIZE + 3 * GAP)
  f:SetHeight(SIZE)
  f:SetFrameStrata("MEDIUM")
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:EnableMouse(false)
  f:Hide()
  S.frame = f

  S.native = API.durationtimers and type(_G.GetTotemDuration) == "function"
    and _G.Enum.StatusBarTimerDirection.RemainingTime ~= nil
  if S.native then
    local down = _G.Enum.NumericRuleFormatRounding.Down
    S.formatter = _G.C_StringUtil.CreateNumericRuleFormatter()
    S.formatter:SetBreakpoints({
      { threshold = 0, step = 1, rounding = down, format = "|cffff3333%d" },
      { threshold = 5.000001, step = 1, rounding = down, format = "|cffffe633%d" },
      { threshold = 10.000001, step = 1, rounding = down, format = "|cffffffff%d" },
      { threshold = 60, format = "|cffffffff%d:%02d", components = {
        { div = 60, step = 1, rounding = down }, { mod = 60, step = 1, rounding = down } } },
    })
  end

  for slot = 1, 4 do CreateButton(slot) end

  f:SetScript("OnMouseDown", function()
    if arg1 == "LeftButton" then this:StartMoving() end
  end)
  f:SetScript("OnMouseUp", function()
    this:StopMovingOrSizing()
    ShaguTweaks_config = ShaguTweaks_config or {}
    if arg1 == "RightButton" then
      ShaguTweaks_config[POSITION_KEY] = nil
    else
      ShaguTweaks_config[POSITION_KEY] = { this:GetLeft(), this:GetBottom() }
    end
    RestorePosition()
  end)

  -- Only older builds need a Lua animation loop while a totem is out.
  if not S.native then f:SetScript("OnUpdate", OnUpdate) end

  S.events = CreateFrame("Frame")
  S.events:SetScript("OnEvent", function()
    if event == "MODIFIER_STATE_CHANGED" then
      SetUnlocked(ModifiersDown())
    else
      Refresh()
    end
  end)

  RestorePosition()
end

module.enable = function(self)
  local _, class = UnitClass("player")
  if class ~= "SHAMAN" or not Supported() then return end

  CreateTimers()

  S.events:RegisterEvent("PLAYER_TOTEM_UPDATE")
  S.events:RegisterEvent("PLAYER_ENTERING_WORLD")
  S.events:RegisterEvent("MODIFIER_STATE_CHANGED")

  SLASH_SHAGUTOTEMTIMERS1 = "/totemtimers"
  SlashCmdList["SHAGUTOTEMTIMERS"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "reset" then
      ShaguTweaks_config = ShaguTweaks_config or {}
      ShaguTweaks_config[POSITION_KEY] = nil
      RestorePosition()
    end
  end

  Refresh()
end

module.disable = function(self)
  if not S.frame then return end
  if S.unlocked then SetUnlocked(false) end
  S.events:UnregisterAllEvents()
  for slot = 1, 4 do StopButton(S.buttons[slot]) end
  S.frame:Hide()
end
