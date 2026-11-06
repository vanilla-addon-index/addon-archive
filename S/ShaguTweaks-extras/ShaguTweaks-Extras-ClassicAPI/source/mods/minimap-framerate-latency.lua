-- Adapted from TokensWorth/ShaguTweaks-mods (MIT, original copyright GryllsAddons).

local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local floor = math.floor

local module = ShaguTweaks:register({
  title = T["MiniMap Framerate & Latency"],
  description = T["Adds a small framerate & latency display to the mini map."],
  expansions = { ["vanilla"] = true, ["tbc"] = nil },
  category = T["Minimap & World Map"],
  enabled = nil,
})

local TARGET_FPS = 60
local LOW_LATENCY = tonumber(_G.PERFORMANCEBAR_LOW_LATENCY) or 300
local MEDIUM_LATENCY = tonumber(_G.PERFORMANCEBAR_MEDIUM_LATENCY) or 600

local function CreateStatusFrame(width)
  local frame = CreateFrame("Frame", nil, Minimap)
  frame:SetFrameLevel(64)
  frame:SetWidth(width)
  frame:SetHeight(23)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 8,
    edgeSize = 16,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  frame:SetBackdropBorderColor(.9, .8, .5, 1)
  frame:SetBackdropColor(.4, .4, .4, 1)

  frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.text:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
  frame.text:SetAllPoints(frame)
  frame.text:SetFontObject(GameFontWhite)

  return frame
end

local function SetFPSColor(text, fps)
  local perc = fps / TARGET_FPS
  if perc < 0 then perc = 0 elseif perc > 1 then perc = 1 end

  local r, g
  if perc <= .5 then
    r = 1
    g = perc * 2
  else
    r = (1 - perc) * 2
    g = 1
  end

  text:SetTextColor(r, g, 0, 1)
end

local function SetLatencyColor(text, latency)
  if latency > MEDIUM_LATENCY then
    text:SetTextColor(1, 0, 0, 1)
  elseif latency > LOW_LATENCY then
    text:SetTextColor(1, 1, 0, 1)
  else
    text:SetTextColor(0, 1, 0, 1)
  end
end

module.enable = function(self)
  if self.ticker then
    self.ticker:Cancel()
    self.ticker = nil
  end

  -- Extras is ClassicAPI-first. Do not restore the original permanent
  -- OnUpdate implementation when the native scheduler is unavailable.
  if type(_G.C_Timer) ~= "table" or type(_G.C_Timer.NewTicker) ~= "function" then
    return
  end

  if not self.fpsFrame then
    self.fpsFrame = CreateStatusFrame(49)
    self.latencyFrame = CreateStatusFrame(51)
  end

  local fpsFrame = self.fpsFrame
  local latencyFrame = self.latencyFrame
  local lowFPS, highFPS
  local lowMS, highMS

  -- Follow the existing ShaguTweaks MiniMap Clock instead of independently
  -- anchoring to MinimapCluster. MiniMap Square and mover integrations already
  -- reposition that clock, so these counters follow automatically regardless
  -- of module initialization order.
  fpsFrame:ClearAllPoints()
  latencyFrame:ClearAllPoints()

  if _G.MinimapClock then
    fpsFrame:SetPoint("RIGHT", _G.MinimapClock, "LEFT", 2, 0)
    latencyFrame:SetPoint("LEFT", _G.MinimapClock, "RIGHT", -2, 0)
  else
    fpsFrame:SetPoint("BOTTOM", Minimap, "BOTTOM", -28, -25)
    latencyFrame:SetPoint("BOTTOM", Minimap, "BOTTOM", 28, -25)
  end

  local function Update()
    local fps = floor(GetFramerate() or 0)
    local _, _, latency = GetNetStats()
    latency = floor(latency or 0)

    if fps > 0 and (not lowFPS or fps < lowFPS) then lowFPS = fps end
    if not highFPS or fps > highFPS then highFPS = fps end
    if latency > 0 and (not lowMS or latency < lowMS) then lowMS = latency end
    if not highMS or latency > highMS then highMS = latency end

    fpsFrame.text:SetText(tostring(fps))
    latencyFrame.text:SetText(tostring(latency))
    SetFPSColor(fpsFrame.text, fps)
    SetLatencyColor(latencyFrame.text, latency)
  end

  fpsFrame:SetScript("OnEnter", function()
    GameTooltip:ClearLines()
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
    GameTooltip:AddLine(T["Framerate"])
    GameTooltip:AddDoubleLine(T["High"], tostring(highFPS or 0) .. " " .. T["fps"], 1,1,1,1,1,1)
    GameTooltip:AddDoubleLine(T["Low"], tostring(lowFPS or 0) .. " " .. T["fps"], 1,1,1,1,1,1)
    GameTooltip:Show()
  end)

  latencyFrame:SetScript("OnEnter", function()
    GameTooltip:ClearLines()
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
    GameTooltip:AddLine(T["Latency"])
    GameTooltip:AddDoubleLine(T["High"], tostring(highMS or 0) .. " " .. T["ms"], 1,1,1,1,1,1)
    GameTooltip:AddDoubleLine(T["Low"], tostring(lowMS or 0) .. " " .. T["ms"], 1,1,1,1,1,1)
    GameTooltip:Show()
  end)

  fpsFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
  latencyFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

  fpsFrame:Show()
  latencyFrame:Show()
  Update()

  -- One native ClassicAPI ticker services both displays. Lua only wakes once
  -- per second instead of running two permanent OnUpdate handlers every frame.
  self.ticker = _G.C_Timer.NewTicker(1, Update)
end

module.disable = function(self)
  if self.ticker then
    self.ticker:Cancel()
    self.ticker = nil
  end

  if self.fpsFrame then self.fpsFrame:Hide() end
  if self.latencyFrame then self.latencyFrame:Hide() end
end
