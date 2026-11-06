--[[
  TankSuite - Nameplates
  Shows on every enemy nameplate WHO the mob is attacking:

    green   the mob is on you
    <tank>  the mob is on a tank (each tank has his own colour + a shield icon)
    red     the mob is on someone who is not a tank (a loose mob!)
    orange  the mob has no target (resetting / fleeing)
    grey    the mob is on a pet

  The target's name is written above (or below) the plate, in class colour.
  Needs SuperWoW: frame:GetName(1) gives the GUID behind a nameplate and every
  unit function accepts a GUID.

  pfUI / ShaguPlates: they hide the game's plate and draw their own one, so we
  colour THEIR bar (plate.nameplate.health) and write the text on THEIR plate.
]]

local TS = TankSuite
local NP = { plates = {}, known = {}, styleVersion = 1 }
TS.Nameplates = NP

local FONT = "Fonts\\FRIZQT__.TTF"
local SHIELD = "Interface\\Icons\\Ability_Defend"

----------------------------------------------------------------------
-- Decision logic (no frames involved, easy to test)
----------------------------------------------------------------------
-- state: me | tank | other | none | pet
-- entry: roster entry of the mob's target (or nil), controlled: target is a pet/charmed
function NP.Decide(exists, targetGuid, playerGuid, entry, controlled)
  if not exists or not targetGuid then return "none" end
  if targetGuid == playerGuid then return "me" end
  if entry then
    if entry.isPlayer then return "me" end
    if TS.Roster.TankInfo(entry) then return "tank" end
    return "other"
  end
  if controlled then return "pet" end
  return "other"
end

-- bar colour for a state
function NP.ColorFor(state, entry)
  local cfg = TS.db.plates
  if state == "tank" then
    if cfg.perTankColor then
      local _, c = TS.Roster.TankInfo(entry)
      if c then return c end
    end
    return cfg.colors.tank
  end
  return cfg.colors[state]
end

-- everything we need to draw a plate, or nil when the plate should stay untouched
function NP.Evaluate(guid, targetToken)
  local cfg = TS.db.plates
  if UnitIsPlayer(guid) or UnitIsDead(guid) or not UnitCanAttack("player", guid) then return nil end
  if cfg.combatOnly and not UnitAffectingCombat(guid) then return nil end

  local exists, tg = UnitExists(targetToken)
  local entry = tg and TS.Roster.byGuid[tg] or nil
  local controlled = false
  if exists and tg and not entry then controlled = UnitPlayerControlled(tg) and true or false end
  local state = NP.Decide(exists, tg, TS.Roster.playerGuid, entry, controlled)

  local name, class
  if state == "me" then
    name = UnitName("player")
    local _, pc = UnitClass("player")
    class = pc
  elseif entry then
    name, class = entry.name, entry.class
  elseif exists and tg then
    name = UnitName(tg)
  end
  return state, name, class, NP.ColorFor(state, entry), entry, tg
end

----------------------------------------------------------------------
-- Plate discovery and drawing
----------------------------------------------------------------------
local function IsNamePlate(frame)
  if not frame:IsObjectType("Button") then return false end
  local guid = frame:GetName(1)
  if not guid or not string.find(guid, "^0x") or guid == "0x0000000000000000" then return false end
  local child = frame:GetChildren()
  return (child and child:IsObjectType("StatusBar")) and true or false
end

-- Where to draw. pfUI and ShaguPlates hide the game's plate and draw their own one,
-- reachable as plate.nameplate (.health = the bar you see, .name = the name text).
-- Everything else is drawn on the game's own plate.
local function Target(p)
  local pf = p.nameplate
  if pf and pf.health and pf.name and pf.health.SetStatusBarColor then
    return pf, pf.health, pf.name
  end
  return p, p.tsGameHealth, p.tsGameName
end

local function NewOverlay(host)
  local ov = {}
  ov.text = host:CreateFontString(nil, "OVERLAY")
  ov.text:SetFont(FONT, 11, "OUTLINE")
  ov.icon = host:CreateTexture(nil, "OVERLAY")
  ov.icon:SetTexture(SHIELD)
  ov.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  ov.text:Hide()
  ov.icon:Hide()
  return ov
end

local function HideOverlay(ov)
  if ov then
    ov.text:Hide()
    ov.icon:Hide()
  end
end

local function Style(p)
  local cfg = TS.db.plates
  local ov = p.tsOv
  local size = cfg.fontSize
  ov.text:SetFont(FONT, size, "OUTLINE")
  ov.text:ClearAllPoints()
  ov.icon:ClearAllPoints()
  ov.icon:SetWidth(size + 3)
  ov.icon:SetHeight(size + 3)
  if cfg.textPos == "BOTTOM" then
    ov.text:SetPoint("TOP", p.tsBar, "BOTTOM", 0, -2)
  elseif p.tsAnchor then
    ov.text:SetPoint("BOTTOM", p.tsAnchor, "TOP", 0, 2)
  else
    ov.text:SetPoint("BOTTOM", p.tsBar, "TOP", 0, 14)
  end
  ov.icon:SetPoint("RIGHT", ov.text, "LEFT", -3, 0)
  ov.iconAlone = false
  p.tsStyle = NP.styleVersion
end

-- give the bar its original colour back
local function RestoreBar(p)
  if p.tsColored and p.tsBase and p.tsBar then
    p.tsBar:SetStatusBarColor(p.tsBase[1], p.tsBase[2], p.tsBase[3], p.tsBase[4] or 1)
    -- pfUI only repaints its bar when the colour IT computes changes: make it repaint
    local cache = p.tsHost and p.tsHost ~= p and p.tsHost.cache
    if cache then cache.r = nil end
  end
  p.tsColor = nil
  p.tsColored = false
end

local function ClearPlate(p)
  RestoreBar(p)
  HideOverlay(p.tsOv)
end

-- (re)attach to whatever we must draw on: the game's plate, or pfUI's
local function Bind(p)
  local host, bar, anchor = Target(p)
  if p.tsHost == host and p.tsBar == bar then
    p.tsAnchor = anchor
    return
  end
  if p.tsHost then ClearPlate(p) end -- pfUI showed up (or left): forget what was drawn on the old one
  p.tsHost, p.tsBar, p.tsAnchor = host, bar, anchor
  p.tsOvs = p.tsOvs or {}
  if not p.tsOvs[host] then p.tsOvs[host] = NewOverlay(host) end
  p.tsOv = p.tsOvs[host]
  p.tsStyle = nil
  bar.tsPlate = p
  if not bar.tsHooked then
    bar.tsHooked = true
    -- pfUI & co. re-colour the bar all the time: put our colour back every frame
    TS.HookScript(bar, "OnUpdate", function()
      local plate = this.tsPlate
      local c = plate and plate.tsBar == this and plate.tsColor
      if c then this:SetStatusBarColor(c[1], c[2], c[3], c[4] or 1) end
    end)
  end
end

local function InitPlate(p)
  p.tsGameHealth = p:GetChildren()
  for _, region in ipairs({ p:GetRegions() }) do
    if region:IsObjectType("FontString") and region:GetText() then
      local text = region:GetText()
      if not (tonumber(text) ~= nil or text == "??") then p.tsGameName = region end
    end
  end
  TS.HookScript(p, "OnShow", function()
    -- the game reuses plates for other units: forget everything we knew
    this.tsColor = nil
    this.tsColored = false
    this.tsGuid = nil
    HideOverlay(this.tsOv)
  end)
  p.tsInit = true
end

local function Near(a, b)
  return math.abs(a[1] - b[1]) < 0.01 and math.abs(a[2] - b[2]) < 0.01 and math.abs(a[3] - b[3]) < 0.01
end

local function ApplyPlate(p, cfg, state, name, class, color, entry)
  local bar, ov = p.tsBar, p.tsOv
  -- bar colour
  if cfg.colorBar and color then
    if not p.tsColored then
      -- remember the colour the bar has, unless that is still our own colour
      -- (a recycled plate that was not repainted)
      local cur = { bar:GetStatusBarColor() }
      if not (p.tsBase and p.tsLast and Near(cur, p.tsLast)) then p.tsBase = cur end
    end
    p.tsLast = color
    p.tsColor = color
    p.tsColored = true
    bar:SetStatusBarColor(color[1], color[2], color[3], color[4] or 1)
  elseif p.tsColored then
    RestoreBar(p)
  end

  -- name text and shield are independent options
  local wantText = cfg.showText and name and (state ~= "me" or cfg.showOnMe)
  local wantIcon = cfg.showIcon and state == "tank" and name
  if wantText then
    local r, g, b = TS.ClassColor(class)
    if state == "none" or not class then r, g, b = 1, 1, 1 end
    ov.text:SetText(TS.Hex(r, g, b) .. name .. "|r")
    ov.text:Show()
  elseif wantIcon then
    ov.text:SetText("") -- no name: keep the (empty) text as the anchor of the shield
    ov.text:Show()
  else
    ov.text:Hide()
  end
  if wantIcon then
    local c = color or cfg.colors.tank
    ov.icon:SetVertexColor(c[1], c[2], c[3])
    -- shield beside the name, or centred when there is no name
    local alone = not wantText
    if ov.iconAlone ~= alone then
      ov.iconAlone = alone
      ov.icon:ClearAllPoints()
      if alone then
        ov.icon:SetPoint("CENTER", ov.text, "CENTER", 0, 0)
      else
        ov.icon:SetPoint("RIGHT", ov.text, "LEFT", -3, 0)
      end
    end
    ov.icon:Show()
  else
    ov.icon:Hide()
  end
end

function NP.UpdatePlate(p, cfg)
  if not p:IsShown() then return end
  local guid = p:GetName(1)
  if not guid or not string.find(guid, "^0x") then
    ClearPlate(p)
    return
  end
  Bind(p)
  if p.tsGuid ~= guid then
    p.tsGuid = guid
    p.tsToken = guid .. "target"
    if p.tsColored then ClearPlate(p) end
  end
  if p.tsStyle ~= NP.styleVersion then Style(p) end

  local state, name, class, color, entry = NP.Evaluate(guid, p.tsToken)
  if not state then
    ClearPlate(p)
    return
  end
  ApplyPlate(p, cfg, state, name, class, color, entry)
end

function NP.Scan()
  local kids = { WorldFrame:GetChildren() }
  for i = 1, table.getn(kids) do
    local f = kids[i]
    if not NP.known[f] and IsNamePlate(f) then
      NP.known[f] = true
      InitPlate(f)
      table.insert(NP.plates, f)
    end
  end
end

function NP.HideAll()
  for i = 1, table.getn(NP.plates) do
    local p = NP.plates[i]
    if p.tsColored or (p.tsOv and p.tsOv.text:IsShown()) then ClearPlate(p) end
  end
end

-- called by the menu after any plate setting changed
function NP.RefreshStyle()
  NP.styleVersion = NP.styleVersion + 1
end

----------------------------------------------------------------------
-- Ticker
----------------------------------------------------------------------
local scanTick, updTick = 0, 0
local wasEnabled = false
local ticker = CreateFrame("Frame", "TankSuiteNameplateTicker")
ticker:SetScript("OnUpdate", function()
  if not TS.db or not TS.hasSuperWoW then return end
  local cfg = TS.db.plates
  if not cfg.enabled then
    if wasEnabled then
      wasEnabled = false
      NP.HideAll()
    end
    return
  end
  wasEnabled = true
  local dt = arg1 or 0
  scanTick = scanTick + dt
  updTick = updTick + dt
  if scanTick >= 0.5 then
    scanTick = 0
    TS.Safe(NP.Scan)
  end
  if updTick >= 0.1 then
    updTick = 0
    for i = 1, table.getn(NP.plates) do TS.Safe(NP.UpdatePlate, NP.plates[i], cfg) end
  end
end)
