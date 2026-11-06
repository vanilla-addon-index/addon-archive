local UPDATE_INTERVAL = 0.15
local BASE_RUN_SPEED_YDS = 7

local state = {
  elapsed = 0,
  lastX = nil,
  lastY = nil,
  fallbackSpeed = 0,
}

local frame = CreateFrame("Frame", "SpeedOMeterFrame", UIParent)
frame:SetWidth(160)
frame:SetHeight(58)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 170)
frame:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true,
  tileSize = 16,
  edgeSize = 12,
  insets = { left = 3, right = 3, top = 3, bottom = 3 }
})
frame:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
frame:EnableMouse(true)
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function()
  this:StartMoving()
end)
frame:SetScript("OnDragStop", function()
  this:StopMovingOrSizing()
end)

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", frame, "TOP", 0, -8)
title:SetText("Speed-o-meter")

local speedText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
speedText:SetPoint("CENTER", frame, "CENTER", 0, -6)
speedText:SetText("0.00 yd/s")

local hintText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
hintText:SetPoint("BOTTOM", frame, "BOTTOM", 0, 6)
hintText:SetText("/speed to toggle")

local function estimateSpeedFromMapPosition(elapsed)
  if type(GetPlayerMapPosition) ~= "function" then
    state.lastX = nil
    state.lastY = nil
    state.fallbackSpeed = 0
    return 0
  end

  local x, y = GetPlayerMapPosition("player")
  if not x or not y or (x == 0 and y == 0) then
    state.lastX = nil
    state.lastY = nil
    state.fallbackSpeed = 0
    return 0
  end

  if not state.lastX or not state.lastY or elapsed <= 0 then
    state.lastX = x
    state.lastY = y
    state.fallbackSpeed = 0
    return 0
  end

  local dx = x - state.lastX
  local dy = y - state.lastY
  state.lastX = x
  state.lastY = y

  local normalizedDistance = math.sqrt(dx * dx + dy * dy)
  local roughYards = normalizedDistance * 1000
  state.fallbackSpeed = roughYards / elapsed

  if state.fallbackSpeed < 0 then
    state.fallbackSpeed = 0
  end

  return state.fallbackSpeed
end

local function getCurrentSpeed(elapsed)
  if type(GetUnitSpeed) == "function" then
    local speed = GetUnitSpeed("player") or 0
    if speed < 0 then
      speed = 0
    end
    return speed
  end

  return estimateSpeedFromMapPosition(elapsed)
end

local function updateText(elapsed)
  local speed = getCurrentSpeed(elapsed)
  local percent = 0

  if BASE_RUN_SPEED_YDS > 0 then
    percent = (speed / BASE_RUN_SPEED_YDS) * 100
  end

  speedText:SetText(string.format("%.2f yd/s (%.0f%%)", speed, percent))
end

frame:SetScript("OnUpdate", function(self, elapsed)
  state.elapsed = state.elapsed + (elapsed or arg1 or 0)
  if state.elapsed < UPDATE_INTERVAL then
    return
  end

  updateText(state.elapsed)
  state.elapsed = 0
end)

SLASH_SPEEDOMETER1 = "/speed"
SlashCmdList["SPEEDOMETER"] = function()
  if frame:IsShown() then
    frame:Hide()
  else
    frame:Show()
  end
end

frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function()
  updateText(UPDATE_INTERVAL)
end)
