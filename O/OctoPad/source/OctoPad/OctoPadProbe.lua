--[[----------------------------------------------------------------------
OctoPad Probe  -  what this client actually allows

  /opad probe        passive report: client add-ons (SuperWoW, UnitXP SP3, Interact.dll), GUID features,
                     and every protected function the client has blocked so far
  /opad probe test   also calls a few protected functions in harmless ways and reports which were blocked:
                     MouselookStart / MouselookStop, TargetUnit on your current target, ClearTarget with no target

Results are kept in OP.caps for the other modules.  Lua 5.0.
------------------------------------------------------------------------]]

local OP = OctoPad
local Print = OP.Print
OP.caps = {}

local function Yes(v) return v and "|cff66ff66yes|r" or "|cffff6655no|r" end
local function Line(name, v, note)
  Print(string.format("  %-28s %s%s", name, (type(v) == "string") and v or Yes(v), note and ("  |cff888888" .. note .. "|r") or ""))
end

local function PlateGUID()
  local kids = { WorldFrame:GetChildren() }
  local i
  for i = 1, table.getn(kids) do
    local p = kids[i]
    if p:IsVisible() and not p:GetName() then
      local ok, g = pcall(p.GetName, p, 1)
      if ok and type(g) == "string" and g ~= "" then return g end
    end
  end
  return nil
end

function OP.ProbePassive()
  local c = OP.caps
  c.superwow = SUPERWOW_VERSION ~= nil
  local _, pguid = UnitExists("player")
  c.guid = type(pguid) == "string"
  c.guidUnit = c.guid and UnitName(pguid) == UnitName("player")
  c.mouseover = SetMouseoverUnit ~= nil
  c.plateGuid = PlateGUID()
  c.unitxp = (UnitXP ~= nil) and pcall(UnitXP, "nop", "nop") and true or false
  c.interact = InteractNearest ~= nil
  c.mouselook = MouselookStart ~= nil

  if UnitExists("target") then
    local _, tguid = UnitExists("target")
    if c.guid and tguid then
      local ok, same = pcall(function()
        return (UnitExists(tguid .. "target") and true or false) == (UnitExists("targettarget") and true or false)
      end)
      c.guidSuffix = ok and same
    end
    if c.unitxp then
      local ok1, d1 = pcall(UnitXP, "distanceBetween", "player", "target")
      c.xpDistTarget = ok1 and type(d1) == "number" and d1 or nil
      if tguid then
        local ok2, d2 = pcall(UnitXP, "distanceBetween", "player", tguid)
        c.xpDistGuid = ok2 and type(d2) == "number" and d2 or nil
      end
    end
  end

  Print("Probe (passive)  -  OctoPad v" .. OP.VERSION)
  Line("SuperWoW", c.superwow, SUPERWOW_VERSION and ("v" .. tostring(SUPERWOW_VERSION)) or nil)
  Line("GUIDs (UnitExists 2nd value)", c.guid)
  Line("GUID usable as a unit", c.guidUnit)
  Line("SetMouseoverUnit", c.mouseover)
  Line("Nameplate GUIDs", c.plateGuid ~= nil, c.plateGuid and "seen on a visible plate" or "no visible plate right now")
  if UnitExists("target") then
    Line("GUID .. \"target\" tokens", c.guidSuffix == true, c.guidSuffix == nil and "needs SuperWoW" or nil)
  else
    Line("GUID .. \"target\" tokens", "|cffaaaaaauntested|r", "target something and probe again")
  end
  Line("UnitXP SP3", c.unitxp)
  if c.unitxp and UnitExists("target") then
    Line("  distance to target", c.xpDistTarget and string.format("%.1f yd", c.xpDistTarget) or "|cffff6655no|r")
    Line("  distance by GUID", c.xpDistGuid and string.format("%.1f yd", c.xpDistGuid) or "|cffff6655no|r")
  end
  Line("Interact.dll (InteractNearest)", c.interact)
  Line("MouselookStart exists", c.mouselook)
  Line("ConsoleExperience", OP.CEDetected and OP.CEDetected() or false)
  Line("pfUI", pfUI ~= nil)
  local blocked, k, v = "", nil, nil
  for k, v in pairs(OP.cfg.blocked or {}) do blocked = blocked .. k .. " x" .. v .. "  " end
  Line("Blocked so far", blocked ~= "" and ("|cffff9900" .. blocked .. "|r") or "|cff66ff66none|r")
end

-- active tests: harmless calls, then see which ones the client blocked
local tester = CreateFrame("Frame")
function OP.ProbeActive()
  local before = {}
  local k, v
  for k, v in pairs(OP.cfg.blocked) do before[k] = v end
  local tried = {}
  if MouselookStart then
    pcall(MouselookStart)
    if MouselookStop then pcall(MouselookStop) end
    table.insert(tried, "MouselookStart")
  end
  if TargetUnit and UnitExists("target") then
    pcall(TargetUnit, "target")                -- re-targets the same unit
    table.insert(tried, "TargetUnit")
  end
  if ClearTarget and not UnitExists("target") then
    pcall(ClearTarget)                         -- nothing to clear
    table.insert(tried, "ClearTarget")
  end
  local wait = 0
  tester:SetScript("OnUpdate", function()
    wait = wait + arg1
    if wait < 0.5 then return end
    this:SetScript("OnUpdate", nil)
    Print("Probe (test calls)")
    local i
    for i = 1, table.getn(tried) do
      local fn = tried[i]
      local b = (OP.cfg.blocked[fn] or 0) > (before[fn] or 0)
      OP.caps["blocked_" .. fn] = b
      Line(fn, b and "|cffff6655blocked|r" or "|cff66ff66allowed|r")
    end
    if not UnitExists("target") then Line("TargetUnit", "|cffaaaaaauntested|r", "target something and test again") end
    Line("CastSpellByName(spell, unit)", "|cffaaaaaauntested|r", "would cast a spell; watch /opad debug while using smart target")
  end)
end

function OP.Probe(arg)
  OP.ProbePassive()
  if arg == "test" then OP.ProbeActive() end
end
