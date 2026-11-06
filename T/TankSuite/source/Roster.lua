--[[
  TankSuite - Roster
  Who is in the group, and who counts as a tank.

  A player is a tank when (in this order):
    manual - added by you (menu, /tks add, or the "add target" button)
    mt     - has the Main Tank role in the raid frame
    auto   - seen doing something only tanks do: casting Taunt / Growl / Righteous
             Fury / Defensive Stance / Shield Block..., or standing in Bear Form or
             with Righteous Fury on. The flag fades after a few minutes.
]]

local TS = TankSuite
local R = { byGuid = {}, byName = {}, signals = {}, playerGuid = nil }
TS.Roster = R

local TANK_CLASS = { WARRIOR = true, DRUID = true, PALADIN = true, SHAMAN = true }
R.TANK_CLASS = TANK_CLASS

local SIGNAL_TTL = 300 -- seconds a tank signal stays valid without being seen again

-- spells that (almost) only tanks cast: ids are resolved to the client language
-- with SpellInfo, English names stay as a fallback (custom Turtle WoW spells)
local SIGNAL_SPELLS = {
  { ids = { 71 }, en = "Defensive Stance" },
  { ids = { 5487 }, en = "Bear Form" },
  { ids = { 9634 }, en = "Dire Bear Form" },
  { ids = { 25780 }, en = "Righteous Fury" },
  { ids = { 355 }, en = "Taunt" },
  { ids = { 6795 }, en = "Growl" },
  { ids = { 694, 7400, 7402, 20559, 20560 }, en = "Mocking Blow" },
  { ids = { 1161 }, en = "Challenging Shout" },
  { ids = { 5209 }, en = "Challenging Roar" },
  { ids = { 2565 }, en = "Shield Block" },
  { ids = { 871 }, en = "Shield Wall" },
  { ids = { 12975 }, en = "Last Stand" },
  { ids = { 20925, 20927, 20928 }, en = "Holy Shield" },
  { ids = { 22842 }, en = "Frenzied Regeneration" },
  { ids = {}, en = "Hand of Reckoning" },
  { ids = {}, en = "Earthshaker Slam" },
}

-- buff icons that only tanks wear
local TANK_BUFF_TEX = {
  ["interface\\icons\\ability_racial_bearform"] = true,
  ["interface\\icons\\spell_holy_sealoffury"] = true,
  ["interface\\icons\\ability_warrior_defensivestance"] = true,
}

local signalNames = nil
local function BuildSignalNames()
  signalNames = {}
  for i = 1, table.getn(SIGNAL_SPELLS) do
    local s = SIGNAL_SPELLS[i]
    signalNames[s.en] = true
    for j = 1, table.getn(s.ids) do
      local n = TS.SpellName(s.ids[j])
      if n then signalNames[n] = true end
    end
  end
end

----------------------------------------------------------------------
-- Roster snapshot
----------------------------------------------------------------------
local function AddUnit(byGuid, byName, unit, index)
  local exists, guid = UnitExists(unit)
  if not exists then return end
  local name = UnitName(unit)
  if not name then return end
  local isMainTank = false
  if index then
    local _, _, _, _, _, _, _, _, _, role = GetRaidRosterInfo(index)
    isMainTank = role and string.lower(role) == "maintank" or false
  end
  -- in a raid the player is also "raidN": keep the single "player" entry
  if unit ~= "player" and UnitIsUnit(unit, "player") then
    if byName[name] and isMainTank then byName[name].mt = true end
    return
  end
  local _, class = UnitClass(unit)
  local entry = {
    name = name, class = class, unit = unit, guid = guid,
    isPlayer = (unit == "player"), mt = isMainTank,
  }
  if guid then byGuid[guid] = entry end
  byName[name] = entry
end

function R.Rebuild()
  local byGuid, byName = {}, {}
  AddUnit(byGuid, byName, "player", nil)
  local raid = GetNumRaidMembers()
  if raid > 0 then
    for i = 1, raid do AddUnit(byGuid, byName, "raid" .. i, i) end
  else
    for i = 1, GetNumPartyMembers() do AddUnit(byGuid, byName, "party" .. i, nil) end
  end
  R.byGuid, R.byName = byGuid, byName
  local _, pg = UnitExists("player")
  R.playerGuid = pg
end

function R.InGroup()
  return GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0
end

----------------------------------------------------------------------
-- Tank status
----------------------------------------------------------------------
-- stable colour per name, so an auto-detected tank keeps the same colour
local function HashName(name)
  local h = 0
  for i = 1, string.len(name) do
    h = h * 31 + string.byte(name, i)
    h = math.mod(h, 1000003)
  end
  return h
end

function R.AutoColor(name)
  local idx = math.mod(HashName(name), table.getn(TS.palette)) + 1
  return TS.palette[idx]
end

function R.NextFreeColor()
  local used = {}
  for _, t in pairs(TS.db.tanks) do
    if t.color then used[t.color[1] .. "," .. t.color[2] .. "," .. t.color[3]] = true end
  end
  for i = 1, table.getn(TS.palette) do
    local c = TS.palette[i]
    if not used[c[1] .. "," .. c[2] .. "," .. c[3]] then return TS.DeepCopy(c) end
  end
  return TS.DeepCopy(TS.palette[1])
end

-- returns source ("manual" | "mt" | "auto") and colour, or nil when not a tank
function R.TankInfo(entry)
  if not entry or not TS.db then return nil end
  local m = TS.db.tanks[entry.name]
  if m then return "manual", m.color or R.AutoColor(entry.name) end
  if TS.db.tankOpts.useRaidRole and entry.mt then return "mt", R.AutoColor(entry.name) end
  if TS.db.tankOpts.autoDetect and R.signals[entry.name] then
    return "auto", R.AutoColor(entry.name)
  end
  return nil
end

function R.IsTankName(name)
  local e = R.byName[name]
  if e then return R.TankInfo(e) ~= nil end
  return TS.db.tanks[name] ~= nil
end

function R.Signal(name)
  R.signals[name] = GetTime()
end

-- a group member cast something (UNIT_CASTEVENT)
function R.OnCast(casterGuid, spellName)
  if not spellName or not casterGuid then return end
  local e = R.byGuid[casterGuid]
  if not e or e.isPlayer or not TANK_CLASS[e.class] then return end
  if not signalNames then BuildSignalNames() end
  if signalNames[spellName] then R.Signal(e.name) end
end

-- look at the buffs of the group (bear form, righteous fury, defensive stance)
function R.ScanBuffs()
  for _, e in pairs(R.byName) do
    if not e.isPlayer and TANK_CLASS[e.class] then
      for i = 1, 16 do
        local tex = UnitBuff(e.unit, i)
        if not tex then break end
        if TANK_BUFF_TEX[string.lower(tex)] then
          R.Signal(e.name)
          break
        end
      end
    end
  end
end

function R.Prune()
  local now = GetTime()
  for name, t in pairs(R.signals) do
    if not R.byName[name] or (now - t) > SIGNAL_TTL then R.signals[name] = nil end
  end
end

----------------------------------------------------------------------
-- Manual list
----------------------------------------------------------------------
-- add by name, or the current target when no name is given
function R.AddManual(name)
  local class
  if not name or name == "" then
    if not UnitExists("target") or not UnitIsPlayer("target") or UnitIsEnemy("player", "target") then
      return false
    end
    name = UnitName("target")
    local _, c = UnitClass("target")
    class = c
  else
    name = TS.Trim(name)
    name = string.upper(string.sub(name, 1, 1)) .. string.lower(string.sub(name, 2))
    local e = R.byName[name]
    if e then class = e.class end
  end
  if not name or name == "" then return false end
  local existing = TS.db.tanks[name]
  if existing then
    existing.class = class or existing.class
  else
    TS.db.tanks[name] = { color = R.NextFreeColor(), class = class }
  end
  return true, name
end

function R.RemoveManual(name)
  if not name then return false end
  name = TS.Trim(name)
  if TS.db.tanks[name] then
    TS.db.tanks[name] = nil
    return true
  end
  -- case-insensitive fallback
  for n, _ in pairs(TS.db.tanks) do
    if string.lower(n) == string.lower(name) then
      TS.db.tanks[n] = nil
      return true
    end
  end
  return false
end

-- everything that currently counts as a tank, manual ones first
function R.ListTanks()
  local out, seen = {}, {}
  for name, t in pairs(TS.db.tanks) do
    local e = R.byName[name]
    table.insert(out, {
      name = name, class = (e and e.class) or t.class, source = "manual",
      color = t.color or R.AutoColor(name), inGroup = e ~= nil,
    })
    seen[name] = true
  end
  for name, e in pairs(R.byName) do
    if not seen[name] then
      local src, color = R.TankInfo(e)
      if src then
        table.insert(out, { name = name, class = e.class, source = src, color = color, inGroup = true })
      end
    end
  end
  table.sort(out, function(a, b)
    if a.source ~= b.source then
      if a.source == "manual" then return true end
      if b.source == "manual" then return false end
    end
    return a.name < b.name
  end)
  return out
end

-- turn an auto / raid-role tank into a permanent manual one
function R.Promote(name)
  local e = R.byName[name]
  if TS.db.tanks[name] then return end
  local _, color = R.TankInfo(e)
  TS.db.tanks[name] = { color = color and TS.DeepCopy(color) or R.NextFreeColor(), class = e and e.class }
end

----------------------------------------------------------------------
-- Wiring
----------------------------------------------------------------------
TS.On("PLAYER_ENTERING_WORLD", function()
  if TS.db then R.Rebuild() end
end)
TS.On("PARTY_MEMBERS_CHANGED", function()
  if TS.db then R.Rebuild() end
end)
TS.On("RAID_ROSTER_UPDATE", function()
  if TS.db then R.Rebuild() end
end)

local tick = 0
local scanTick = 0
local rebuildTick = 0
local ticker = CreateFrame("Frame", "TankSuiteRosterTicker")
ticker:SetScript("OnUpdate", function()
  if not TS.db then return end
  local dt = arg1 or 0
  tick = tick + dt
  scanTick = scanTick + dt
  rebuildTick = rebuildTick + dt
  if rebuildTick >= 10 then
    rebuildTick = 0
    R.Rebuild()
  end
  if scanTick >= 3 then
    scanTick = 0
    if TS.db.tankOpts.autoDetect and R.InGroup() then TS.Safe(R.ScanBuffs) end
  end
  if tick >= 5 then
    tick = 0
    R.Prune()
  end
end)
