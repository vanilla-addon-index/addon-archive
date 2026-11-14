-- Damage models for the classes whose special attacks use weapon damage (Rogue, Warrior, Hunter).
-- Each model is a small steady-state "damage per second" calculation at your attack power and weapon.
-- Weights are then taken as slopes: how much damage per second one more point of each thing gives,
-- compared to one more attack power. So the currency stays 1 point = 1 attack power.
--
-- Why: your special attacks do a percent of WEAPON DAMAGE (not dps), and they are limited by energy,
-- rage or cooldown, not by weapon speed. So at the same dps a slower weapon with bigger hits is better
-- for them (Backstab, Mortal Strike, Whirlwind, Slam, Mongoose Bite). The attack power part of an
-- ability uses a fixed speed (dagger 1.7, other one-hand 2.4, two-hand 3.3, ranged 2.8, patch 1.8).
--
-- Numbers are level 60 values scaled down for lower levels. They are estimates, not game data.

local AG = AdeGear
local Model = {}
AG.Model = Model

function Model.Rank(name)
  if AdeTalents and AdeTalents.GetRank then
    local r = AdeTalents.GetRank(name)
    if r then return r end
  end
  return 0
end

local function Scale(p)
  local k = (p.lvl or 60) / 60
  if k > 1 then k = 1 end
  if k < 0.2 then k = 0.2 end
  return k
end

----------------------------------------------------------------------
-- Rogue: energy 10/s, Backstab (dagger) or Sinister Strike, Eviscerate at 5 combo points.
-- Blade Rush shortens the energy tick by your Agility (read as milliseconds), Vigor gives energy.
----------------------------------------------------------------------
function Model.rogue(p)
  local k = Scale(p)
  local h = p.haste or 0
  local t = p.t or {}
  local white = (p.d + p.AP / 14) * (1 + h)
  if p.dual then white = white + 0.5 * ((p.dOff or 0) + p.AP / 14) * (1 + h) end
  local energy = 10 * (1 + 0.03 * (t.vigor or 0))
  if (t.bladeRush or 0) > 0 then
    local cut = (p.agi or 0) / 1000
    if cut > 0.8 then cut = 0.8 end
    energy = energy * 2 / (2 - cut)
  end
  local a = p.d * p.s
  local ev = 1100 * k + 0.15 * p.AP
  local dps = white
  if p.dagger then
    local cycle = (5 * 60 + 35) / energy
    local bs = 1.5 * (a + p.AP / 14 * 1.7) + 210 * k
    dps = dps + (5 / cycle) * bs + ev / cycle
  else
    local cycle = (5 * 45 + 35) / energy
    local ss = a + p.AP / 14 * 2.4 + 68 * k
    dps = dps + (5 / cycle) * ss + ev / cycle
  end
  return dps
end

----------------------------------------------------------------------
-- Warrior: rage comes from white damage. Mortal Strike / Bloodthirst, Whirlwind, Overpower, then Slam
-- (two-hander) or Heroic Strike (one-hander) with what is left.
----------------------------------------------------------------------
function Model.warrior(p)
  local k = Scale(p)
  local h = p.haste or 0
  local t = p.t or {}
  local L = p.lvl or 60
  local white = (p.d + p.AP / 14) * (1 + h)
  local conv = 0.0091107836 * L * L + 3.225598133 * L + 4.2652911
  local rage = 7.5 * white / conv
  local ns = 2.4
  if p.two then ns = 3.3 end
  local a = p.d * p.s
  local apn = p.AP / 14 * ns
  local total = white
  local r

  if (t.ms or 0) > 0 then
    r = rage / 30
    if r > 1 / 6 then r = 1 / 6 end
    total = total + r * (a + apn + 160 * k)
    rage = rage - r * 30
  end
  if (t.bt or 0) > 0 then
    r = rage / 30
    if r > 1 / 6 then r = 1 / 6 end
    total = total + r * (200 * k + 0.45 * p.AP)
    rage = rage - r * 30
  end
  if L >= 36 then
    r = rage / 25
    if r > 1 / 10 then r = 1 / 10 end
    total = total + r * (a + apn)
    rage = rage - r * 25
  end
  if L >= 12 then
    r = rage / 5
    if r > 0.08 then r = 0.08 end
    total = total + r * (a + apn + 35 * k)
    rage = rage - r * 5
  end
  if rage < 0 then rage = 0 end
  if p.two then
    if L >= 30 then total = total + (rage / 15) * (a + apn + 87 * k) end
  else
    r = rage / 15
    if r > 1 / p.s then r = 1 / p.s end
    total = total + r * 157 * k
  end
  return total
end

----------------------------------------------------------------------
-- Hunter melee: Raptor Strike replaces a white swing (only its flat damage counts), Mongoose Bite is an
-- instant 60% weapon damage hit every 5 s and hits with both weapons when dual wielding.
----------------------------------------------------------------------
function Model.hunterMelee(p)
  local k = Scale(p)
  local h = p.haste or 0
  local white = (p.d + p.AP / 14) * (1 + h)
  local a = p.d * p.s
  local ns = 2.4
  if p.two then ns = 3.3 elseif p.dagger then ns = 1.7 end
  -- Raptor Strike is a "next melee" attack like Heroic Strike: it takes the place of a swing, so only its
  -- flat damage is extra
  local rs = 140 * k
  local mb = 0.6 * (a + p.AP / 14 * ns) + 70 * k
  if p.dual then mb = mb + 0.6 * 0.5 * ((p.dOff or 0) * (p.sOff or 2) + p.AP / 14 * ns) end
  return white + rs / 6 + mb / 5
end

----------------------------------------------------------------------
-- Hunter ranged: Auto Shot, Aimed Shot (26 s), Multi-Shot (10 s), Arcane Shot (flat). AP here is ranged AP.
----------------------------------------------------------------------
function Model.hunterRanged(p)
  local k = Scale(p)
  local h = p.haste or 0
  local am = p.ammo or 0
  local a = p.d * p.s
  local shot = a + am * p.s + p.AP / 14 * p.s
  local auto = shot / p.s * (1 + h)
  local aim = a + am * p.s + p.AP / 14 * 2.8 + 70 * k
  local multi = a + am * p.s + p.AP / 14 * 2.8 + 150 * k
  local arcane = 273 * k + 0.15 * p.AP
  return auto + aim / 26 + multi / 10 + arcane / 6
end

----------------------------------------------------------------------
-- Slopes
----------------------------------------------------------------------
local function With(p, key, delta)
  local q = {}
  for kk, v in pairs(p) do q[kk] = v end
  q[key] = (q[key] or 0) + delta
  return q
end

-- returns { a = points per weapon dps, b = points per point of average hit, ammo, agi, crit, haste, dps }
function Model.Derive(fn, p)
  local base = fn(p)
  local dAP = (fn(With(p, "AP", 10)) - fn(With(p, "AP", -10))) / 20
  if dAP <= 0.0001 then return nil end
  local dd = fn(With(p, "d", 0.5)) - fn(With(p, "d", -0.5))
  local ds = (fn(With(p, "s", 0.05)) - fn(With(p, "s", -0.05))) / 0.1
  local b = ds / (p.d * dAP)
  if b < 0 then b = 0 end
  local a = dd / dAP - b * p.s
  if a < 0 then a = 0 end
  local m = { a = a, b = b, dps = base, dAP = dAP }
  m.crit = 0.01 * base / dAP
  m.haste = (fn(With(p, "haste", 0.01)) - base) / dAP
  m.ammo = (fn(With(p, "ammo", 0.5)) - fn(With(p, "ammo", -0.5))) / dAP
  m.agi = (fn(With(p, "agi", 10)) - fn(With(p, "agi", -10))) / 20 / dAP
  if m.ammo < 0 then m.ammo = 0 end
  if m.agi < 0 then m.agi = 0 end
  return m
end

-- model parameters from the character (Char.Combat fills these fields)
function Model.Params(c, ranged)
  local L = c.level or 60
  local p = { lvl = L, haste = 0 }
  if ranged then
    p.AP = c.rap
    if not p.AP or p.AP <= 0 then p.AP = 2 * L end
    p.d = c.rangedWeaponDps
    if not p.d or p.d <= 0 then p.d = L * 0.35 end
    p.s = c.rangedSpeed
    if not p.s or p.s <= 0 then p.s = 2.8 end
    p.ammo = c.ammoDps
    if not p.ammo or p.ammo <= 0 then p.ammo = L * 0.1 end
    return p
  end
  p.AP = c.ap
  if not p.AP or p.AP <= 0 then p.AP = 2 * L end
  p.d = c.mainDps
  if not p.d or p.d <= 0 then p.d = L * 0.3 end
  p.s = c.mainSpeed
  if not p.s or p.s <= 0 then p.s = 2.0 end
  p.two = c.mainItem and c.mainItem.slot == "TWOHAND" or false
  p.dagger = c.mainItem and c.mainItem.weaponKind == "Dagger" or false
  p.dual = c.offItem and c.offItem.weapon and c.offItem.weapon.dps and true or false
  p.dOff = c.offDps
  p.sOff = c.offSpeed
  p.agi = c.agility or 0
  p.t = {
    vigor = Model.Rank("Vigor"), bladeRush = Model.Rank("Blade Rush"),
    ms = Model.Rank("Mortal Strike"), bt = Model.Rank("Bloodthirst"),
  }
  return p
end
