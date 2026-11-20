--[[
pfUI_CombatLedgerExt  v1.3.0
Threat glow + threat % badge on the pfUI target frame, plus an aggro warning
(sound + screen-edge flash), all driven by CombatLedger's threat data.
Aggro ring on hostile nameplates and off-screen edge dots: see pfUI_CombatLedgerExt_Ring.lua.

Data source: CombatLedger.Threat.GetSnapshot()
  -> [guid] = { name, threat, perc, melee, tank, estimated? }
  perc is relative to the current tank (100 = you hold aggro).

Written for the 1.12 client (Lua 5.0): no '#', no '%', no varargs.
]]

local defaults = {
  glow     = true,          -- colored glow around pfTarget
  perc     = "top",         -- "top" | "bottom" | "off"  (percentage badge)
  side     = "auto",        -- "auto" | "left" | "right" (auto dodges the elite dragon)
  badge    = true,          -- dark box + colored border behind the % text
  poll     = true,          -- force CombatLedger to poll threat without a Threat window
  glowmin  = 1,             -- don't glow below this percentage
  warn     = 85,            -- aggro warning threshold (%)
  sound    = "RaidWarning", -- sound name, file path, or "off"
  flash    = "pulse",       -- "pulse" | "once" | "off"  (screen-edge flash)
  strength = 0.6,           -- screen-edge flash intensity 0.1 - 1.0
  flip     = false,         -- flip top/bottom gradient direction if the edges look inverted
  ring     = true,          -- aggro ring on hostile nameplates (needs SuperWoW, UnitXP SP3 for exact distance)
  ringwarn = 15,            -- ring starts this many yards before the estimated aggro edge
}

local cfg
local glow, badge, text, glowParent
local changedAt, accum, testUntil = 0, 0, 0
local playerName
local pollHooked = false

-- alert state
local alerted, lastSound = false, 0
local edge, edgeOn, edgeUntil, edgeStrength = nil, false, 0, 0
local EDGE_ONCE_DURATION = 1.5

local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc[CL-pfUI]|r " .. msg)
end

local function Clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

----------------------------------------------------------------------
-- pfUI helpers
----------------------------------------------------------------------
local function GetTargetFrame()
  if pfUI and pfUI.uf and pfUI.uf.target then return pfUI.uf.target end
  return getglobal("pfTarget")
end

local function GetFontInfo()
  local font, size = STANDARD_TEXT_FONT, 12
  if pfUI then
    if pfUI.font_unit then font = pfUI.font_unit end
    if pfUI_config and pfUI_config.global and pfUI_config.global.font_unit_size then
      size = tonumber(pfUI_config.global.font_unit_size) or size
    end
  end
  return font, size
end

local function Build(parent)
  if glow and glowParent == parent then return end

  local edgeTex = "Interface\\Tooltips\\UI-Tooltip-Border"
  if pfUI and pfUI.media and pfUI.media["img:glow2"] then edgeTex = pfUI.media["img:glow2"] end

  glow = CreateFrame("Frame", nil, parent)
  glow:SetFrameStrata("BACKGROUND")
  glow:SetFrameLevel(0)
  glow:SetPoint("TOPLEFT", parent, "TOPLEFT", -8, 8)
  glow:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 8, -8)
  glow:SetBackdrop({
    edgeFile = edgeTex, edgeSize = 8,
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
  })
  glow:Hide()

  -- badge sits well above pfUI-eliteoverlay's dragon (frame level 8)
  badge = CreateFrame("Frame", nil, parent)
  badge:SetFrameLevel(math.max(parent:GetFrameLevel() + 20, 30))
  badge:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  badge:Hide()

  text = badge:CreateFontString(nil, "OVERLAY")
  local font, size = GetFontInfo()
  text:SetFont(font, size + 2, "OUTLINE")
  text:SetPoint("CENTER", badge, "CENTER", 0, 0)
  text:SetText("")

  glowParent = parent
end

-- put the badge on the side of the frame the elite dragon is NOT on
local function PlaceBadge(parent)
  local side = cfg.side
  if side == "auto" then
    side = "right"
    local pos = pfUI_config and pfUI_config.EliteOverlay and pfUI_config.EliteOverlay.position
    if (pos == "right" or pos == "left") and parent.dragon and parent.dragon:IsShown() then
      side = (pos == "right") and "left" or "right"
    end
  end
  local S = string.upper(side)
  badge:ClearAllPoints()
  if cfg.perc == "bottom" then
    badge:SetPoint("TOP" .. S, parent, "BOTTOM" .. S, 0, -3)
  else
    badge:SetPoint("BOTTOM" .. S, parent, "TOP" .. S, 0, 3)
  end
end

----------------------------------------------------------------------
-- Threat colour: green->yellow 0-49%, yellow->red 50-100% (as TWThreat)
----------------------------------------------------------------------
local function ThreatColor(p)
  p = Clamp(p, 0, 100)
  if p < 50 then return p / 50, 1, 0 end
  return 1, 1 - (p - 50) / 50, 0
end

----------------------------------------------------------------------
-- CombatLedger access
----------------------------------------------------------------------
local function GetPlayerEntry()
  local CL = CombatLedger
  if not CL or not CL.Threat or not CL.Threat.GetSnapshot then return nil end
  local snap = CL.Threat.GetSnapshot()
  if not snap then return nil end
  local guid, e
  for guid, e in pairs(snap) do
    if e.name == playerName then return e end
  end
  return nil
end

-- CombatLedger only polls the server while a Threat window is visible.
-- Wrap IsModeVisible so "threat" counts as visible while we're enabled.
local function HookPoll()
  if pollHooked then return end
  local CL = CombatLedger
  if not CL or not CL.UI or not CL.UI.IsModeVisible then return end
  local orig = CL.UI.IsModeVisible
  CL.UI.IsModeVisible = function(mode)
    if cfg and cfg.poll and mode == "threat" then return true end
    return orig(mode)
  end
  pollHooked = true
end

-- returns perc, entry  (nil when there is nothing valid to show)
local function GetThreat()
  if testUntil > GetTime() then
    return 95, { tank = false }
  end
  if not UnitExists("target") or UnitIsDead("target") or not UnitCanAttack("player", "target") then
    return nil
  end
  local e = GetPlayerEntry()
  if not e or not e.perc then return nil end

  -- ignore the previous target's snapshot until fresh data lands
  local CL = CombatLedger
  local fresh = CL.Threat.GetLastUpdate and CL.Threat.GetLastUpdate() >= changedAt
  if not fresh and not (e.estimated and GetTime() - changedAt > 2.5) then
    return nil
  end
  return e.perc, e
end

----------------------------------------------------------------------
-- Target frame display
----------------------------------------------------------------------
local function HideAll()
  if glow then glow:Hide() end
  if badge then badge:Hide() end
  if text then text:SetText("") end
end

local function Display(perc)
  local parent = GetTargetFrame()
  if not parent then return end
  Build(parent)

  if not perc then return HideAll() end
  local r, g, b = ThreatColor(perc)

  if cfg.glow and perc >= cfg.glowmin then
    glow:SetBackdropBorderColor(r, g, b, 0.35 + 0.55 * (math.min(perc, 100) / 100))
    glow:Show()
  else
    glow:Hide()
  end

  if cfg.perc ~= "off" then
    PlaceBadge(parent)
    text:SetTextColor(r, g, b)
    text:SetText(string.format("%d%%", math.floor(perc + 0.5)))
    local _, size = GetFontInfo()
    badge:SetWidth(text:GetStringWidth() + 10)
    badge:SetHeight(size + 8)
    if cfg.badge then
      badge:SetBackdropColor(0, 0, 0, 0.8)
      badge:SetBackdropBorderColor(r, g, b, 1)
    else
      badge:SetBackdropColor(0, 0, 0, 0)
      badge:SetBackdropBorderColor(0, 0, 0, 0)
    end
    badge:Show()
  else
    badge:Hide()
    text:SetText("")
  end
end

----------------------------------------------------------------------
-- Aggro warning: sound + screen-edge flash
----------------------------------------------------------------------
local function PlayAlert()
  local s = cfg.sound
  if not s or s == "" or s == "off" then return end
  if string.find(s, "[\\/]") or string.find(s, "%.%a%a%a$") then
    PlaySoundFile(s)
  else
    PlaySound(s)
  end
end

local function SetStrip(tex, orient, r, g, b, a, solidFirst)
  if tex.SetGradientAlpha then
    if solidFirst then
      tex:SetGradientAlpha(orient, r, g, b, a, r, g, b, 0)
    else
      tex:SetGradientAlpha(orient, r, g, b, 0, r, g, b, a)
    end
  else
    tex:SetTexture(r, g, b, a * 0.5)
  end
end

local function BuildEdge()
  edge = CreateFrame("Frame", "CLpfUIThreatEdge", UIParent)
  edge:SetAllPoints(UIParent)
  edge:SetFrameStrata("FULLSCREEN")
  edge:EnableMouse(false)
  local w, h = UIParent:GetWidth(), UIParent:GetHeight()
  local thick = math.floor(h * 0.14)

  local function Strip()
    local t = edge:CreateTexture(nil, "OVERLAY")
    t:SetTexture("Interface\\Buttons\\WHITE8X8")
    return t
  end
  edge.top, edge.bottom, edge.left, edge.right = Strip(), Strip(), Strip(), Strip()

  edge.top:SetPoint("TOPLEFT", edge, "TOPLEFT", 0, 0)
  edge.top:SetPoint("TOPRIGHT", edge, "TOPRIGHT", 0, 0)
  edge.top:SetHeight(thick)

  edge.bottom:SetPoint("BOTTOMLEFT", edge, "BOTTOMLEFT", 0, 0)
  edge.bottom:SetPoint("BOTTOMRIGHT", edge, "BOTTOMRIGHT", 0, 0)
  edge.bottom:SetHeight(thick)

  edge.left:SetPoint("TOPLEFT", edge, "TOPLEFT", 0, 0)
  edge.left:SetPoint("BOTTOMLEFT", edge, "BOTTOMLEFT", 0, 0)
  edge.left:SetWidth(thick)

  edge.right:SetPoint("TOPRIGHT", edge, "TOPRIGHT", 0, 0)
  edge.right:SetPoint("BOTTOMRIGHT", edge, "BOTTOMRIGHT", 0, 0)
  edge.right:SetWidth(thick)
  edge:Hide()
end

local function UpdateEdge()
  if not edgeOn then
    if edge and edge:IsShown() then edge:Hide() end
    return
  end
  if not edge then BuildEdge() end
  local now = GetTime()
  local a = edgeStrength * (0.55 + 0.45 * math.sin(now * 7))
  if cfg.flash == "once" and edgeUntil > 0 then
    a = a * Clamp((edgeUntil - now) / EDGE_ONCE_DURATION, 0, 1)
  end
  -- VERTICAL gradient: first colour = bottom, second = top; HORIZONTAL: left -> right
  local fv = cfg.flip and true or false
  SetStrip(edge.top,    "VERTICAL",   1, 0.05, 0.05, a, fv)
  SetStrip(edge.bottom, "VERTICAL",   1, 0.05, 0.05, a, not fv)
  SetStrip(edge.left,   "HORIZONTAL", 1, 0.05, 0.05, a, true)
  SetStrip(edge.right,  "HORIZONTAL", 1, 0.05, 0.05, a, false)
  edge:Show()
end

local function ResetAlerts()
  alerted = false
  edgeOn = false
  edgeUntil = 0
end

local function Alerts(perc, e)
  local now = GetTime()
  local inZone = perc and e and not e.tank
  local danger = inZone and perc >= cfg.warn

  -- re-arm once threat has dropped clearly below the threshold
  if alerted and not (inZone and perc >= cfg.warn - 10) then alerted = false end

  if danger and not alerted then
    alerted = true
    if now - lastSound >= 2 then
      lastSound = now
      PlayAlert()
    end
    if cfg.flash == "once" then edgeUntil = now + EDGE_ONCE_DURATION end
  end

  if alerted and cfg.flash ~= "off" and (cfg.flash == "pulse" or now < edgeUntil) then
    local over = Clamp((perc - cfg.warn) / math.max(100 - cfg.warn, 1), 0, 1)
    edgeStrength = cfg.strength * (0.6 + 0.4 * over)
    edgeOn = true
  else
    edgeOn = false
  end
end

----------------------------------------------------------------------
-- Main tick
----------------------------------------------------------------------
local function Update()
  local perc, e = GetThreat()
  Alerts(perc, e)
  Display(perc)
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")

f:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" and arg1 == "pfUI_CombatLedgerExt" then
    if not CLpfUIThreatDB then CLpfUIThreatDB = {} end
    local k, v
    for k, v in pairs(defaults) do
      if CLpfUIThreatDB[k] == nil then CLpfUIThreatDB[k] = v end
    end
    cfg = CLpfUIThreatDB
    playerName = UnitName("player")
    HookPoll()
  elseif event == "PLAYER_ENTERING_WORLD" then
    playerName = UnitName("player")
    HookPoll()
  elseif event == "PLAYER_TARGET_CHANGED" then
    changedAt = GetTime()
    ResetAlerts()
    HideAll()
  elseif event == "PLAYER_REGEN_ENABLED" then
    ResetAlerts()
    accum = 1
  end
end)

f:SetScript("OnUpdate", function()
  if not cfg then return end
  UpdateEdge()                 -- every frame (smooth pulse)
  accum = accum + arg1
  if accum < 0.2 then return end
  accum = 0
  Update()                     -- 5x per second
end)

----------------------------------------------------------------------
-- Slash: /clpf
----------------------------------------------------------------------
SLASH_CLPFUITHREAT1 = "/clpf"
SlashCmdList["CLPFUITHREAT"] = function(msg)
  if not cfg then
    Print("config not loaded (ADDON_LOADED never matched). Folder must be named pfUI_CombatLedgerExt.")
    return
  end
  local _, _, cmd, rest = string.find(msg or "", "^(%S*)%s*(.*)$")
  cmd = string.lower(cmd or "")
  local arg = string.lower(rest or "")

  if cmd == "glow" then
    cfg.glow = not cfg.glow
    Print("Glow " .. (cfg.glow and "on" or "off"))

  elseif cmd == "top" or cmd == "bottom" or cmd == "off" then
    cfg.perc = cmd
    Print("Percentage: " .. cmd)

  elseif cmd == "side" then
    if arg == "auto" or arg == "left" or arg == "right" then
      cfg.side = arg
      Print("Badge side: " .. arg)
    else
      Print("/clpf side auto | left | right")
    end

  elseif cmd == "badge" then
    cfg.badge = not cfg.badge
    Print("Badge background " .. (cfg.badge and "on" or "off"))

  elseif cmd == "poll" then
    cfg.poll = not cfg.poll
    Print("Force threat polling " .. (cfg.poll and "on" or "off") ..
      (cfg.poll and "" or " (needs a CombatLedger Threat window open)"))

  elseif cmd == "warn" then
    local n = tonumber(arg)
    if n then
      cfg.warn = Clamp(math.floor(n), 20, 99)
      Print("Warning threshold: " .. cfg.warn .. "%")
    else
      Print("/clpf warn <20-99>   (now " .. cfg.warn .. ")")
    end

  elseif cmd == "sound" then
    if rest ~= "" then cfg.sound = rest end   -- keep original case for file paths
    Print("Sound: " .. tostring(cfg.sound) .. (rest == "" and " (playing)" or ""))
    PlayAlert()

  elseif cmd == "flash" then
    if arg == "pulse" or arg == "once" or arg == "off" then
      cfg.flash = arg
      Print("Screen-edge flash: " .. arg)
    else
      Print("/clpf flash pulse | once | off")
    end

  elseif cmd == "flip" then
    cfg.flip = not cfg.flip
    Print("Edge gradient flipped: " .. tostring(cfg.flip) .. " (use if the flash fades at the screen border instead of the center)")

  elseif cmd == "strength" then
    local n = tonumber(arg)
    if n then
      cfg.strength = Clamp(n, 0.1, 1)
      Print("Flash strength: " .. cfg.strength)
    else
      Print("/clpf strength <0.1-1.0>   (now " .. cfg.strength .. ")")
    end

  elseif cmd == "ring" then
    if CLpfUIThreatRing then CLpfUIThreatRing.Slash(arg, Print) end

  elseif cmd == "test" then
    testUntil = GetTime() + 8
    ResetAlerts()
    if not UnitExists("target") then
      Print("Edge flash + sound will fire, but TARGET SOMETHING to see the glow/% (pfUI hides the target frame otherwise).")
    else
      Print("Simulating 95% threat for 8s")
    end

  elseif cmd == "debug" then
    local parent = GetTargetFrame()
    Print("player=" .. tostring(playerName) .. " pollHooked=" .. tostring(pollHooked))
    Print("pfUI=" .. tostring(pfUI ~= nil) .. " pfTarget=" .. tostring(parent ~= nil) ..
      " shown=" .. tostring(parent and parent:IsShown() or false) ..
      " glowBuilt=" .. tostring(glow ~= nil))
    local eo = pfUI_config and pfUI_config.EliteOverlay
    Print("eliteoverlay=" .. tostring(eo ~= nil) .. " pos=" .. tostring(eo and eo.position) ..
      " dragonShown=" .. tostring(parent and parent.dragon and parent.dragon:IsShown() or false))
    Print("alerted=" .. tostring(alerted) .. " edgeOn=" .. tostring(edgeOn) ..
      " warn=" .. cfg.warn .. " flash=" .. cfg.flash .. " sound=" .. tostring(cfg.sound))
    if CLpfUIThreatRing then CLpfUIThreatRing.Debug(Print) end
    local CL = CombatLedger
    Print("CombatLedger=" .. tostring(CL ~= nil) .. " Threat=" .. tostring(CL and CL.Threat ~= nil) ..
      " UI.IsModeVisible=" .. tostring(CL and CL.UI and CL.UI.IsModeVisible ~= nil))
    if CL and CL.Threat then
      local snap = CL.Threat.GetSnapshot()
      local n, guid, e = 0
      for guid, e in pairs(snap) do
        n = n + 1
        Print("  " .. tostring(e.name) .. " perc=" .. tostring(e.perc) .. " tank=" .. tostring(e.tank) .. " est=" .. tostring(e.estimated))
      end
      Print("snapshot entries=" .. n .. " lastUpdate=" .. string.format("%.1f", CL.Threat.GetLastUpdate()) ..
        " changedAt=" .. string.format("%.1f", changedAt) .. " now=" .. string.format("%.1f", GetTime()))
      Print("playerEntry=" .. tostring(GetPlayerEntry() ~= nil))
    end

  else
    Print("/clpf glow | top | bottom | off | side | badge | poll | warn | sound | flash | strength | flip | ring | test | debug")
    Print("glow=" .. tostring(cfg.glow) .. " perc=" .. cfg.perc .. " side=" .. cfg.side ..
      " warn=" .. cfg.warn .. " flash=" .. cfg.flash .. " sound=" .. tostring(cfg.sound))
  end
end
