-- =====================================================
-- FineZoom
-- Minimal fine camera zoom control for Vanilla / Turtle
-- =====================================================

-- Default values
FineZoomStep   = FineZoomStep   or 0.2
FineZoomSilent = FineZoomSilent ~= false  -- default = true

local MIN_STEP = 0.05
local MAX_STEP = 5.0

-- Clamp zoom step to safe limits
local function Clamp(v)
  if v < MIN_STEP then return MIN_STEP end
  if v > MAX_STEP then return MAX_STEP end
  return v
end

-- Conditional chat output (silent by default)
local function Print(msg)
  if not FineZoomSilent then
    DEFAULT_CHAT_FRAME:AddMessage(msg)
  end
end

-- Normalize decimal separator (supports 0.3 and 0,3)
local function ParseNumber(msg)
  if not msg or msg == "" then return nil end
  msg = string.gsub(msg, ",", ".")
  return tonumber(msg)
end

-- Slash command: /finezoom <value>
SLASH_FINEZOOM1 = "/finezoom"
SlashCmdList.FINEZOOM = function(msg)
  local v = ParseNumber(msg)
  if v then
    FineZoomStep = Clamp(v)
    DEFAULT_CHAT_FRAME:AddMessage(
      string.format("FineZoom: zoom step set to %.2f", FineZoomStep)
    )
  else
    DEFAULT_CHAT_FRAME:AddMessage(
      "Usage: /finezoom <step>  (example: /finezoom 0.2)"
    )
  end
end

-- Optional helper to bind mouse wheel automatically
SLASH_FINEZOOMBIND1 = "/fzbind"
SlashCmdList.FINEZOOMBIND = function()
  SetBinding("MOUSEWHEELUP",   "FINEZOOMIN")
  SetBinding("MOUSEWHEELDOWN", "FINEZOOMOUT")
  SaveBindings(GetCurrentBindingSet())
  DEFAULT_CHAT_FRAME:AddMessage("FineZoom: mouse wheel bindings applied.")
end

-- Apply settings on player login
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
  Print(string.format("FineZoom loaded (zoom step %.2f)", FineZoomStep))
end)
