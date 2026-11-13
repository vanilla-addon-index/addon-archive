local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local API = ShaguTweaks.API
local module = ShaguTweaks:register({
  title = T["Unit Frame Energy & Mana Tick"],
  description = T["Adds an energy & mana tick to the player frame and Personal Resource Display."],
  expansions = { ["vanilla"] = true }, category = T["Unit Frames"], enabled = nil,
})
module.enable = function(self)
  if self.tick then return end
  local tick = CreateFrame("StatusBar", nil, PlayerFrameManaBar)
  self.tick = tick
  tick:SetAllPoints(PlayerFrameManaBar)
  tick:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  tick:SetStatusBarColor(1, 1, 1, 0)
  tick:SetMinMaxValues(0, 1)
  tick:Hide()
  tick.spark = tick:CreateTexture(nil, "OVERLAY")
  tick.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
  tick.spark:SetBlendMode("ADD")
  tick.spark:SetPoint("CENTER", tick:GetStatusBarTexture(), "RIGHT", 0, 0)
  tick.spark:Hide()
  local native = API.durationtimers and type(tick.SetTimerDuration) == "function"
  if native then tick.duration = _G.C_DurationUtil.CreateDuration() end
  local function CancelWake()
    if tick.wake then tick.wake:Cancel(); tick.wake = nil end
  end
  local function SizeSpark()
    local height = PlayerFrameManaBar:GetHeight()
    tick.spark:SetHeight(height + 10)
    tick.spark:SetWidth(height + 4)
  end
  -- Observe the regen phase separately from the five-second-rule display.
  -- Mid-period gains (potions/procs) do not move an established clock.
  local function LockTick(now)
    if tick.phase then
      local error = math.mod(now - tick.phase, 2)
      if error > 1 then error = error - 2 end
      if math.abs(error) <= .25 then
        if error > .08 then tick.phase = tick.phase + error - .08
        elseif error < -.08 then tick.phase = tick.phase + error + .08 end
        tick.rejected = nil
        return
      end
      if not tick.rejected or math.abs(now - tick.rejected - 2) > .25 then
        tick.rejected = now
        return
      end
    end
    tick.phase, tick.rejected = now, nil
  end
  local Sweep
  local function Wrap() tick.wake = nil; Sweep() end
  function Sweep()
    CancelWake()
    if not tick:IsShown() then return end
    local now = GetTime()
    local start, duration
    if tick.mode == 0 and tick.ruleEnd and tick.ruleEnd > now then
      -- Retain the five-second spark appearance for mana-costing casts.
      start, duration = tick.ruleEnd - 5, 5
    elseif tick.phase then
      start = tick.phase + math.floor((now - tick.phase) / 2) * 2
      duration = 2
    end
    if not start then tick.start = nil; tick.spark:Hide(); return end
    tick.start, tick.period = start, duration
    tick.spark:Show()
    if native then
      tick.duration:SetTimeFromStart(start, duration)
      tick:SetTimerDuration(tick.duration, _G.Enum.StatusBarInterpolation.Immediate,
        _G.Enum.StatusBarTimerDirection.ElapsedTime)
      tick.wake = _G.C_Timer.NewTimer(math.max(.001, start + duration - now), Wrap)
    end
  end
  local function Visible()
    if tick.mode == 3 or (tick.mode == 0 and
      (UnitMana("player") < UnitManaMax("player") or UnitAffectingCombat("player"))) then
      tick:Show()
      Sweep()
    else tick:Hide() end
  end
  tick:SetScript("OnHide", CancelWake)
  if not native then
    tick:SetScript("OnUpdate", function()
      if not tick.start then return end
      local now = GetTime()
      if now >= tick.start + tick.period then Sweep() end
      if tick.start and tick.spark:IsShown() then
        tick:SetValue(math.max(0, math.min(1, (now - tick.start) / tick.period)))
      end
    end)
  end
  ShaguTweaks.HookScript(PlayerFrameManaBar, "OnSizeChanged", SizeSpark)
  ShaguTweaks.HookScript(tick, "OnShow", Sweep)
  local function ArmRule(spellID)
    if not spellID then return end
    if API.GetSpellInfo then
      local name, rank, icon, cost, funnel, powerType = API.GetSpellInfo(spellID)
      if name then
        if powerType == 0 and cost and cost > 0 then
          tick.ruleSpell, tick.ruleEnd = spellID, GetTime() + 5
        end
        return
      end
    end
    local spells = _G.C_Spell
    if not spells or type(spells.GetSpellPowerCost) ~= "function" then return end
    local costs = spells.GetSpellPowerCost(spellID)
    local cost = costs and costs[1]
    if cost and cost.type == 0 and cost.cost and cost.cost > 0 then
      tick.ruleSpell, tick.ruleEnd = spellID, GetTime() + 5
    end
  end
  tick:SetScript("OnEvent", function()
    local world = event == "PLAYER_ENTERING_WORLD"
    local display = event == "UNIT_DISPLAYPOWER"
    -- ClassicAPI world-entry payloads are booleans, not unit tokens.
    if not world and string.find(event, "^UNIT_") and arg1 ~= "player" then return end
    local mode = UnitPowerType("player")
    if world or display or mode ~= tick.mode then
      tick.mode, tick.lastPower = mode, UnitMana("player")
      tick.phase, tick.rejected, tick.start = nil, nil, nil
      tick.spark:Hide()
    end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then ArmRule(arg3)
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
      if tick.ruleSpell == arg3 then tick.ruleEnd = GetTime() + 5 end
    elseif (event == "UNIT_MANA" and mode == 0) or (event == "UNIT_ENERGY" and mode == 3) then
      local power = UnitMana("player")
      if tick.lastPower and power > tick.lastPower then LockTick(GetTime()) end
      tick.lastPower = power
    end
    Visible()
    if self.RefreshDruidManaTick then self.RefreshDruidManaTick() end
  end)
  tick:RegisterEvent("PLAYER_ENTERING_WORLD")
  tick:RegisterEvent("PLAYER_REGEN_DISABLED")
  tick:RegisterEvent("PLAYER_REGEN_ENABLED")
  local events = { "UNIT_DISPLAYPOWER", "UNIT_MANA", "UNIT_ENERGY",
    "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_CHANNEL_STOP" }
  for _, name in ipairs(events) do API.RegisterUnitEvent(tick, name, "player") end
  SizeSpark()
  -- Mirror the existing sweep; do not create another clock or event listener.
  ShaguTweaks.RegisterResourceTickBar = function(parent)
    if self.resourceTick then return end
    local copy = CreateFrame("StatusBar", nil, parent)
    self.resourceTick = copy
    copy:SetAllPoints(parent)
    copy:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    copy:SetStatusBarColor(1, 1, 1, 0)
    copy:SetMinMaxValues(0, 1)
    copy.spark = copy:CreateTexture(nil, "OVERLAY")
    copy.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    copy.spark:SetBlendMode("ADD")
    copy.spark:SetPoint("CENTER", copy:GetStatusBarTexture(), "RIGHT", 0, 0)
    local function Resize()
      copy.spark:SetHeight(parent:GetHeight() + 10)
      copy.spark:SetWidth(parent:GetHeight() + 4)
    end
    local function Visibility()
      if tick:IsShown() then copy:Show() else copy:Hide() end
      if tick.spark:IsShown() then copy.spark:Show() else copy.spark:Hide() end
    end
    ShaguTweaks.HookScript(parent, "OnSizeChanged", Resize)
    ShaguTweaks.HookScript(tick, "OnShow", Visibility)
    ShaguTweaks.HookScript(tick, "OnHide", Visibility)
    ShaguTweaks.hooksecurefunc(tick.spark, "Show", Visibility)
    ShaguTweaks.hooksecurefunc(tick.spark, "Hide", Visibility)
    if native then
      ShaguTweaks.hooksecurefunc(tick, "SetTimerDuration", function(bar, duration, interpolation, direction)
        copy:SetTimerDuration(duration, interpolation, direction)
      end)
      if tick.start then copy:SetTimerDuration(tick.duration, _G.Enum.StatusBarInterpolation.Immediate,
        _G.Enum.StatusBarTimerDirection.ElapsedTime) end
    else
      ShaguTweaks.hooksecurefunc(tick, "SetValue", function(bar, value) copy:SetValue(value) end)
      copy:SetValue(tick:GetValue() or 0)
    end
    Resize(); Visibility()
  end
  local display = ShaguTweaks.PersonalResourceDisplay
  if display then ShaguTweaks.RegisterResourceTickBar(display.power.bar) end
  ShaguTweaks.RegisterDruidManaTickBar = function(parent, source)
    if self.druidTick then return end
    local bar = CreateFrame("StatusBar", nil, parent)
    self.druidTick = bar
    bar:SetAllPoints(parent)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(1, 1, 1, 0)
    bar:SetMinMaxValues(0, 1)
    local spark = bar:CreateTexture(nil, "OVERLAY")
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    spark:SetBlendMode("ADD")
    spark:SetPoint("CENTER", bar:GetStatusBarTexture(), "RIGHT", 0, 0)
    local function Resize()
      spark:SetHeight(parent:GetHeight() + 10); spark:SetWidth(parent:GetHeight() + 4)
    end
    ShaguTweaks.HookScript(parent, "OnSizeChanged", Resize)
    Resize()
    local duration = native and _G.C_DurationUtil.CreateDuration()
    local phase, last, start, period, wake
    local Refresh, Animate
    local function Cancel()
      if wake then wake:Cancel(); wake = nil end
    end
    local function Wrap() wake = nil; Refresh() end
    Refresh = function()
      Cancel()
      local now = GetTime()
      if not parent:IsVisible() then spark:Hide(); bar:SetScript("OnUpdate", nil); return end
      if tick.ruleEnd and tick.ruleEnd > now then start, period = tick.ruleEnd - 5, 5
      elseif phase then start, period = phase + math.floor((now-phase)/2)*2, 2
      else spark:Hide(); bar:SetScript("OnUpdate", nil); return end
      spark:Show()
      if native then
        duration:SetTimeFromStart(start, period)
        bar:SetTimerDuration(duration, _G.Enum.StatusBarInterpolation.Immediate, _G.Enum.StatusBarTimerDirection.ElapsedTime)
        wake = _G.C_Timer.NewTimer(math.max(.001, start+period-now), Wrap)
      else bar:SetScript("OnUpdate", Animate)
      end
    end
    local function Sample()
      local value = source:GetValue()
      if last and value > last then phase = GetTime() end
      last = value
      Refresh()
    end
    if not native then
      Animate = function()
        if spark:IsShown() and start then
          if GetTime() >= start+period then Refresh() end
          bar:SetValue(math.max(0, math.min(1, (GetTime()-start)/period)))
        end
      end
    end
    ShaguTweaks.hooksecurefunc(source, "SetValue", Sample)
    ShaguTweaks.HookScript(parent, "OnShow", Refresh)
    ShaguTweaks.HookScript(parent, "OnHide", function() Cancel(); phase, last = nil, nil; spark:Hide(); bar:SetScript("OnUpdate", nil) end)
    self.RefreshDruidManaTick = Refresh
    Sample()
  end
  if display and display.mana then
    ShaguTweaks.RegisterDruidManaTickBar(display.mana.bar, PlayerFrameAlternatePowerBar)
  end
end
