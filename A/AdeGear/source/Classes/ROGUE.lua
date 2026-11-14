-- Rogue. Only damage (melee). Base weights as a function of your character, 1 point = 1 attack power.
-- First estimates, to be tuned in game.
--
-- Agility gives attack power AND crit, Strength gives attack power. The weapon counts twice: its dps
-- (white hits) and the average size of one hit (Backstab and Sinister Strike use weapon damage, so a
-- slower dagger with bigger hits is better at the same dps). See Model.lua. Blade Rush makes Agility
-- worth more (it speeds up energy).
-- Lethality (crit damage of combo point abilities) makes crit worth more.

local AG = AdeGear
AG.ClassData = AG.ClassData or {}

-- Agility needed for 1% crit (estimate, about 29 at level 60)
local function AgiPerCrit(c)
  local l = c.level or 60
  if l < 1 then l = 1 end
  if l > 60 then l = 60 end
  return 4 + (29 - 4) * (l - 1) / 59
end

local MELEE_SKILL = {
  Sword = "SKILL_SWORDS", Axe = "SKILL_AXES", Mace = "SKILL_MACES", Dagger = "SKILL_DAGGERS", Fist = "SKILL_FIST_WEAPONS",
}

local function Dmg(c)
  local M = AG.Model
  local p = M.Params(c)
  local m = M.Derive(M.rogue, p)
  -- the size of one hit matters only with a dagger (Backstab, Ambush); with other weapons it is folded
  -- into the dps weight
  local a, b = m.a, m.b
  if not p.dagger then a = a + b * p.s; b = 0 end
  local t = {
    WEAPON_MELEE = a, WEAPON_HIT = b, AP = 1.0, STR = 1.0, AGI = 1.0 + m.agi,
    CRIT = m.crit, HIT = m.crit, HASTE_ATTACK = m.haste, ARMORPEN = 0.01 * m.crit, LIFESTEAL = 0.8,
    STA = 0.35, ARMOR = 0.008, DODGE = 2, PARRY = 1, HP5 = 0.1, HEALTH = 0.05,
  }
  local kind = c.mainItem and c.mainItem.weaponKind
  if kind and MELEE_SKILL[kind] then t[MELEE_SKILL[kind]] = 0.2 * m.crit end
  return t
end

AG.ClassData.ROGUE = {
  default = "dmg",
  currency = "1 point = 1 attack power",
  needsCombat = true,
  order = { "WEAPON_MELEE", "WEAPON_HIT", "AP", "STR", "AGI", "CRIT", "HIT", "HASTE_ATTACK", "ARMORPEN", "STA", "ARMOR",
    "DODGE", "PARRY", "LIFESTEAL", "HP5", "HEALTH",
    "SKILL_SWORDS", "SKILL_AXES", "SKILL_MACES", "SKILL_DAGGERS", "SKILL_FIST_WEAPONS" },

  roles = { dmg = Dmg },

  conv = {
    { from = "AGI", to = "CRIT", pct = function(c) return 100 / AgiPerCrit(c) end,
      note = function(c) return "Agility: 1 crit% per " .. string.format("%.1f", AgiPerCrit(c)) .. " at your level" end },
  },

  mods = {
    { talent = "Lethality", kind = "statpct", stat = "CRIT", num = 1, text = "crit damage of combo point abilities" },
  },
}
