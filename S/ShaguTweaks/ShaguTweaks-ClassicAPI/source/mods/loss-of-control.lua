-- Loss of Control Alert
--
-- Shows what is stopping you (stun, fear, silence, school lockout, ...) as a
-- large icon with a countdown in the middle of the screen, like retail.
-- Everything comes from ClassicAPI's C_LossOfControl, which collects the
-- crowd-control debuffs on the player and the school lockout after an
-- interrupt, so nothing here reads the combat log or scans buffs.

local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local API = ShaguTweaks.API

local module = ShaguTweaks:register({
  title = T["Loss of Control Alert"],
  description = T["Shows a large icon and countdown when you are stunned, feared, silenced, rooted, disarmed or locked out of a spell school. Hold <Ctrl>, <Shift> and <Alt> to move it; right-click to reset."],
  expansions = { ["vanilla"] = true },
  category = T["Interface"],
  enabled = false,
})

local ICON = 56
local WIDTH = 300
local BAR_WIDTH = WIDTH - ICON - 30
local THROTTLE = .05
local FALLBACK_ICON = "Interface\\Icons\\Ability_Kick"
local POSITION_KEY = "LossOfControlPosition"

-- Most disabling first. Anything not listed ranks below the list.
local PRIORITY = {
  "STUN", "FEAR", "CONFUSE", "CHARM", "POSSESS", "PACIFYSILENCE",
  "SILENCE", "PACIFY", "DISARM", "ROOT", "SCHOOL_INTERRUPT",
}

local LABELS = {
  STUN = T["Stunned"], FEAR = T["Feared"], CONFUSE = T["Confused"],
  CHARM = T["Charmed"], POSSESS = T["Possessed"], SILENCE = T["Silenced"],
  PACIFY = T["Pacified"], PACIFYSILENCE = T["Pacified and Silenced"],
  DISARM = T["Disarmed"], ROOT = T["Rooted"], SCHOOL_INTERRUPT = T["Interrupted"],
}

local RANK = {}
for i = 1, table.getn(PRIORITY) do RANK[PRIORITY[i]] = i end

-- Border/bar color per kind of effect: hard control red, silences purple,
-- the rest orange, school lockouts blue.
local COLORS = {
  STUN = { 1, .2, .2 }, FEAR = { 1, .2, .2 }, CONFUSE = { 1, .2, .2 },
  CHARM = { 1, .2, .2 }, POSSESS = { 1, .2, .2 },
  SILENCE = { .7, .4, 1 }, PACIFYSILENCE = { .7, .4, 1 }, PACIFY = { .7, .4, 1 },
  DISARM = { 1, .6, .1 }, ROOT = { 1, .6, .1 },
  SCHOOL_INTERRUPT = { .3, .6, 1 },
}
local DEFAULT_COLOR = COLORS.STUN

-- One table for state: Lua 5.0 allows only 32 upvalues per function.
local S = { unlocked = false, elapsed = 0 }
local Refresh

local function StopTiming()
  if S.expiry then S.expiry:Cancel(); S.expiry = nil end
  if S.schoolWake then S.schoolWake:Cancel(); S.schoolWake = nil end
  if S.binding then S.binding:Disable(); S.frame.bar:SetMinMaxValues(0, 1) end
end

local function Supported()
  local c = _G.C_LossOfControl
  return type(c) == "table"
    and type(c.GetActiveLossOfControlDataCount) == "function"
    and type(c.GetActiveLossOfControlData) == "function"
end

local function FormatTime(seconds)
  if seconds >= 10 then return string.format("%d", math.floor(seconds + .5)) end
  return string.format("%.1f", seconds)
end

-- The effect to show: highest priority, the longest one among equals.
-- Returns nil when nothing is active.
local function PickEffect()
  local best, bestRank, bestLeft
  local count = _G.C_LossOfControl.GetActiveLossOfControlDataCount() or 0
  for i = 1, count do
    local data = _G.C_LossOfControl.GetActiveLossOfControlData(i)
    if data and not (data.duration and data.duration > 0
      and data.timeRemaining and data.timeRemaining <= 0) then
      local rank = RANK[data.locType] or (table.getn(PRIORITY) + 1)
      local left = data.timeRemaining or 0
      if not best or rank < bestRank or (rank == bestRank and left > bestLeft) then
        best, bestRank, bestLeft = data, rank, left
      end
    end
  end
  return best
end

local function SchoolName(data)
  if data.locType ~= "SCHOOL_INTERRUPT" then return nil end
  local spell = _G.C_Spell
  if type(spell) == "table" and type(spell.GetSchoolString) == "function" and data.lockoutSchool and data.lockoutSchool ~= 0 then
    return spell.GetSchoolString(data.lockoutSchool)
  end
end

local function ApplyTheme()
  local f = S.frame
  local color = ShaguTweaks.UIBorder
  local r, g, b = color and color.r or .6, color and color.g or .6, color and color.b or .6
  local a = color and color.a or 1
  if S.themeR ~= r or S.themeG ~= g or S.themeB ~= b or S.themeA ~= a then
    S.themeR, S.themeG, S.themeB, S.themeA = r, g, b, a
    f:SetBackdropBorderColor(r, g, b, a)
    f.border:SetBackdropBorderColor(r, g, b, a)
    f.icon:SetVertexColor(1, 1, 1, 1)
  end
end

local function SetBarColor(r, g, b)
  if S.native then S.frame.bar:SetStatusBarColor(r, g, b)
  else S.frame.bar:SetVertexColor(r, g, b) end
end

local function Apply(data)
  local f = S.frame
  local color = COLORS[data.locType] or DEFAULT_COLOR

  local icon = (data.iconTexture and data.iconTexture ~= "") and data.iconTexture or FALLBACK_ICON
  if S.icon ~= icon then S.icon = icon; f.icon:SetTexture(icon) end
  ApplyTheme()
  if S.effectColor ~= color then S.effectColor = color; SetBarColor(color[1], color[2], color[3]) end
  local title = LABELS[data.locType] or data.displayText or ""
  if S.title ~= title then S.title = title; f.title:SetText(title) end

  -- spell name under the label; school lockouts name the locked school
  local detail = SchoolName(data)
  if not detail and data.locType ~= "SCHOOL_INTERRUPT" then detail = data.displayText end
  detail = detail or ""
  if S.detail ~= detail then S.detail = detail; f.detail:SetText(detail) end

  f.data = data
end

local function UpdateTime()
  local f = S.frame
  local data = f.data
  if not data then return end

  local left = data.timeRemaining
  if left and left > 0 then
    f.time:SetText(FormatTime(left))
    local duration = data.duration
    if duration and duration > 0 then
      f.bar:SetWidth(math.max(1, BAR_WIDTH * math.min(left / duration, 1)))
      f.bar:Show()
    else
      f.bar:Hide()
    end
  else
    f.time:SetText("")
    f.bar:Hide()
  end
end

-- Re-select on lifecycle events and timed expiry. Native school lockouts also
-- check scalar state for silent extensions; older builds retain their poller.
Refresh = function()
  local f = S.frame
  if S.unlocked then return end

  local data = PickEffect()
  if data then
    Apply(data)
    if S.native then
      StopTiming()
      local left, total = data.timeRemaining, data.duration
      if left and left > 0 then
        S.duration:SetTimeFromEnd(GetTime() + left, total and total > 0 and total or left)
        S.binding:SetDuration(S.duration)
        S.binding:Enable()
        S.expiry = _G.C_Timer.NewTimer(left, S.expire)
        if total and total > 0 then
          f.bar:SetTimerDuration(S.duration, _G.Enum.StatusBarInterpolation.Immediate,
            _G.Enum.StatusBarTimerDirection.RemainingTime)
          f.bar:Show()
        else f.bar:Hide() end
      else
        f.time:SetText("")
        f.bar:Hide()
      end
      if data.locType == "SCHOOL_INTERRUPT" then
        if type(_G.C_LossOfControl.GetSchoolLockout) == "function" then
          local mask, remaining = _G.C_LossOfControl.GetSchoolLockout()
          S.schoolMask, S.schoolEnd = mask, GetTime() + (remaining or 0)
        end
        S.schoolWake = _G.C_Timer.NewTimer(.2, S.checkSchool)
      end
    else UpdateTime() end
    if not f:IsShown() then f:Show() end
  else
    StopTiming()
    f.data = nil
    f:Hide()
  end
end

local function OnUpdate()
  S.elapsed = S.elapsed + (arg1 or 0)
  if S.elapsed < THROTTLE then return end
  S.elapsed = 0
  Refresh()
end

local function RestorePosition()
  local pos = ShaguTweaks_config and ShaguTweaks_config[POSITION_KEY]
  S.frame:ClearAllPoints()
  if pos and pos[1] and pos[2] then
    S.frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", pos[1], pos[2])
  else
    S.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
  end
end

local ModifiersDown = ShaguTweaks.API.AreMoveModifiersDown

-- Hold Ctrl+Shift+Alt to show a preview and drag the alert.
local function SetUnlocked(on)
  if S.unlocked == on then return end
  local f = S.frame
  S.unlocked = on
  f:EnableMouse(on)

  if on then
    StopTiming()
    S.icon, S.effectColor, S.title, S.detail = nil, nil, nil, nil
    f.data = nil
    f.icon:SetTexture(FALLBACK_ICON)
    ApplyTheme()
    SetBarColor(1, .2, .2)
    if S.native then f.bar:SetValue(1) end
    f.bar:SetWidth(BAR_WIDTH)
    f.bar:Show()
    f.title:SetText(T["Stunned"])
    f.detail:SetText(T["Drag to move, right-click to reset"])
    f.time:SetText("8.0")
    f:Show()
  else
    f:StopMovingOrSizing()
    f:Hide()
    Refresh()
  end
end

local function CreateAlert()
  if S.frame then return end

  local f = CreateFrame("Frame", "ShaguTweaksLossOfControl", UIParent)
  f:SetWidth(WIDTH)
  f:SetHeight(ICON + 24)
  f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16,
    edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
  f:SetBackdropColor(0, 0, 0, .9)
  f:SetFrameStrata("HIGH")
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:EnableMouse(false)
  f:Hide()
  S.frame = f

  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetWidth(ICON)
  f.icon:SetHeight(ICON)
  f.icon:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -10)
  f.icon:SetTexCoord(.08, .92, .08, .92)

  -- Classic tooltip rim, kept separate from the effect-colored timer fill.
  f.border = CreateFrame("Frame", nil, f)
  f.border:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
  f.border:SetPoint("TOPLEFT", f.icon, "TOPLEFT", -3, 3)
  f.border:SetPoint("BOTTOMRIGHT", f.icon, "BOTTOMRIGHT", 3, -3)

  f.title = f:CreateFontString(nil, "OVERLAY")
  f.title:SetFontObject(GameFontNormalLarge)
  f.title:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 10, -2)
  f.title:SetJustifyH("LEFT")
  f.title:SetWidth(WIDTH - ICON - 80)

  f.detail = f:CreateFontString(nil, "OVERLAY")
  f.detail:SetFontObject(GameFontHighlightSmall)
  f.detail:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -2)
  f.detail:SetJustifyH("LEFT")
  f.detail:SetTextColor(.85, .85, .85)
  f.detail:SetWidth(BAR_WIDTH)
  f.detail:SetHeight(28)

  f.time = f:CreateFontString(nil, "OVERLAY")
  f.time:SetFont("Fonts\\FRIZQT__.TTF", 22, "")
  f.time:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -10)
  f.time:SetJustifyH("RIGHT")
  f.time:SetTextColor(1, 1, 1)

  -- remaining time as a bar under the text
  S.native = API.durationtimers and _G.Enum.StatusBarTimerDirection.RemainingTime ~= nil
  if S.native then
    f.bar = CreateFrame("StatusBar", nil, f)
    if type(f.bar.SetTimerDuration) ~= "function" then S.native = false; f.bar:Hide() end
  end
  if S.native then
    f.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    f.bar:SetWidth(BAR_WIDTH)
    S.duration = _G.C_DurationUtil.CreateDuration()
    local formatter = _G.C_StringUtil.CreateNumericRuleFormatter()
    formatter:SetBreakpoints({{ threshold = 0, format = "%.1f" },
      { threshold = 10, step = 1, format = "%d" }})
    S.binding = _G.C_DurationUtil.CreateDurationTextBinding()
    S.binding:SetFontString(f.time)
    S.binding:SetFormatter(formatter)
    S.binding:SetExpiredText("")
    S.binding:SetUpdateInterval(.05)
    S.expire = function() S.expiry = nil; Refresh() end
    -- Re-locking an active school can extend it without any native event.
    -- Check cheap scalar state only while a school lockout is displayed.
    S.checkSchool = function()
      S.schoolWake = nil
      if S.unlocked or not f.data then return end
      local query = _G.C_LossOfControl.GetSchoolLockout
      if type(query) ~= "function" then Refresh(); return end
      local mask, remaining = query()
      local finish = GetTime() + (remaining or 0)
      if mask ~= S.schoolMask or math.abs(finish - S.schoolEnd) > .05 then
        Refresh()
      else S.schoolWake = _G.C_Timer.NewTimer(.2, S.checkSchool) end
    end
  else
    f.bar = f:CreateTexture(nil, "ARTWORK")
    f.bar:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
  end
  f.bar:SetHeight(4)
  f.bar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", ICON + 20, 10)

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

  -- Only older builds need a Lua animation/selection loop while shown.
  if not S.native then f:SetScript("OnUpdate", OnUpdate) end

  S.events = CreateFrame("Frame")
  S.events:SetScript("OnEvent", function()
    if event == "MODIFIER_STATE_CHANGED" then
      SetUnlocked(ModifiersDown())
    else
      Refresh()
    end
  end)

  ApplyTheme()
  RestorePosition()
end

module.enable = function(self)
  if not Supported() then return end

  CreateAlert()

  S.events:RegisterEvent("LOSS_OF_CONTROL_ADDED")
  S.events:RegisterEvent("LOSS_OF_CONTROL_UPDATE")
  S.events:RegisterEvent("PLAYER_ENTERING_WORLD")
  S.events:RegisterEvent("MODIFIER_STATE_CHANGED")

  SLASH_SHAGULOSSOFCONTROL1 = "/lossofcontrol"
  SlashCmdList["SHAGULOSSOFCONTROL"] = function(msg)
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
  StopTiming()
  S.frame:Hide()
end
