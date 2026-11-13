local T = ShaguTweaks.T
local P = ShaguTweaks.libpredict
local module = ShaguTweaks:register({
  title = T["Healing Predictions"],
  description = T["Shows estimated direct heals and upcoming HoT ticks on player and target health bars. Reuses compatible Puppeteer prediction data when available; otherwise uses ClassicAPI events, observed heal amounts and vanilla HealComm. Unknown amounts are not shown."],
  expansions = { ["vanilla"] = true }, category = T["Unit Frames"], enabled = nil,
})
local states, events, enabled
local function Refresh(state)
  local bar, unit, fill = state.bar, state.unit, state.fill
  if not enabled or not bar:IsVisible() or not UnitExists(unit) or UnitIsDeadOrGhost(unit)
    or not UnitCanAssist("player", unit) then fill:Hide(); return end
  local current, maximum = UnitHealth(unit), UnitHealthMax(unit)
  -- A percentage-only target cannot be combined with an absolute heal amount.
  if not current or not maximum or maximum <= 0 or current >= maximum
    or (unit == "target" and maximum == 100 and not UnitIsUnit(unit, "player")) then fill:Hide(); return end
  local amount = math.min(P:UnitGetIncomingHeals(unit), maximum-current)
  local width, height = bar:GetWidth(), bar:GetHeight()
  if amount <= 0 or width <= 0 or height <= 0 then fill:Hide(); return end
  local texture = bar:GetStatusBarTexture()
  if bar.personalResourceDisplay then
    -- Native status bars may crop transparent texture padding themselves;
    -- a plain texture region does not inherit that rendering behavior.
    fill:SetTexture(1, 1, 1, 1)
  else
    fill:SetTexture(texture and texture:GetTexture() or "Interface\\TargetingFrame\\UI-StatusBar")
  end
  fill:SetVertexColor(0, .85, .4, .6)
  fill:ClearAllPoints()
  fill:SetPoint("TOPLEFT", bar, "TOPLEFT", width * current/maximum, 0)
  fill:SetWidth(width * amount/maximum)
  fill:SetHeight(height)
  if bar.personalResourceDisplay then fill:SetTexCoord(0, 1, 0, 1)
  else fill:SetTexCoord(current/maximum, (current+amount)/maximum, 0, 1) end
  fill:Show()
end
local function RefreshAll()
  for _, state in ipairs(states) do Refresh(state) end
end
local function AttachBar(unit, bar)
  if not bar then return end
  for _, state in ipairs(states) do if state.bar == bar then return end end
  local state = { unit = unit, bar = bar, fill = bar:CreateTexture(nil,"ARTWORK") }
  table.insert(states,state)
  state.fill:Hide()
  local function Changed() Refresh(state) end
  ShaguTweaks.hooksecurefunc(bar,"SetValue",Changed)
  ShaguTweaks.hooksecurefunc(bar,"SetMinMaxValues",Changed)
  ShaguTweaks.hooksecurefunc(bar,"SetStatusBarTexture",Changed)
  ShaguTweaks.hooksecurefunc(bar,"SetWidth",Changed)
  ShaguTweaks.hooksecurefunc(bar,"SetHeight",Changed)
  ShaguTweaks.HookScript(bar,"OnShow",Changed)
  ShaguTweaks.HookScript(bar,"OnSizeChanged",Changed)
  ShaguTweaks.HookScript(bar,"OnHide",function() state.fill:Hide() end)
  Refresh(state)
end
-- Additional displays share the existing estimator and event driver.
ShaguTweaks.RegisterHealingPredictionBar = function(unit, bar)
  if enabled then AttachBar(unit, bar) end
end
module.enable = function()
  if enabled then return end
  enabled = true
  if not states then
    states = {}
    AttachBar("player", PlayerFrameHealthBar)
    AttachBar("target", TargetFrameHealthBar)
    P.changed = function(name)
      for _, state in ipairs(states) do if UnitName(state.unit)==name then Refresh(state) end end
    end
    events = CreateFrame("Frame")
    events:SetScript("OnEvent",RefreshAll)
  end
  local display = ShaguTweaks.PersonalResourceDisplay
  if display then AttachBar("player", display.health.bar) end
  P:Enable()
  ShaguTweaks.API.RegisterUnitEvent(events,"UNIT_HEALTH","player","target")
  ShaguTweaks.API.RegisterUnitEvent(events,"UNIT_MAXHEALTH","player","target")
  events:RegisterEvent("PLAYER_TARGET_CHANGED")
  events:RegisterEvent("PLAYER_ENTERING_WORLD")
  RefreshAll()
end
module.disable = function()
  if not enabled then return end
  enabled = false
  events:UnregisterAllEvents()
  P:Disable()
  RefreshAll()
end
