-- Warrior. Base weights per role. First estimates, to be tuned in game.
--
-- dmg  = Arms and Fury: weapon dps and average hit (Mortal Strike, Whirlwind, Slam use weapon damage,
--        see Model.lua), strength (2 attack power each), crit, hit. A function of your character.
-- tank = Protection: stamina, armor, defense, dodge, parry, block, strength (block value and threat).
-- Role comes from the talents you picked (/adeg role why). A tank that solos still counts some damage,
-- see "Leveling" in the options.
-- Currency: 1 point = 1 attack power.

local AG = AdeGear
AG.ClassData = AG.ClassData or {}

local function AgiPerCrit(c)
  local l = c.level or 60
  if l < 1 then l = 1 end
  if l > 60 then l = 60 end
  return 2.5 + (20 - 2.5) * (l - 1) / 59
end

local MELEE_SKILL = {
  Sword = "SKILL_SWORDS", Axe = "SKILL_AXES", Mace = "SKILL_MACES", Dagger = "SKILL_DAGGERS",
  Polearm = "SKILL_POLEARMS", Staff = "SKILL_STAVES", Fist = "SKILL_FIST_WEAPONS",
}

local function Dmg(c)
  local M = AG.Model
  local m = M.Derive(M.warrior, M.Params(c))
  local t = {
    WEAPON_MELEE = m.a, WEAPON_HIT = m.b, AP = 1.0, STR = 2.0, AGI = 0.1,
    CRIT = m.crit, HIT = m.crit, HASTE_ATTACK = m.haste, ARMORPEN = 0.01 * m.crit, LIFESTEAL = 0.8,
    STA = 0.4, ARMOR = 0.015, HP5 = 0.1, HEALTH = 0.05,
  }
  local kind = c.mainItem and c.mainItem.weaponKind
  if kind and MELEE_SKILL[kind] then t[MELEE_SKILL[kind]] = 0.2 * m.crit end
  return t
end

AG.ClassData.WARRIOR = {
  default = "dmg",
  currency = "1 point = 1 attack power",
  needsCombat = true,
  offHandHit = true,
  order = { "WEAPON_MELEE", "WEAPON_HIT", "AP", "STR", "AGI", "CRIT", "HIT", "HASTE_ATTACK", "ARMORPEN", "STA", "ARMOR",
    "DEFENSE", "DODGE", "PARRY", "BLOCK", "BLOCKVAL", "LIFESTEAL", "HP5", "HEALTH",
    "SKILL_SWORDS", "SKILL_AXES", "SKILL_MACES", "SKILL_DAGGERS", "SKILL_POLEARMS", "SKILL_STAVES", "SKILL_FIST_WEAPONS" },

  -- value of avoidance: points per percent = factor x level-scaled value of one percent of health (Weights.lua)
  armorDR = true,
  avoid = { DEFENSE = 0.2, DODGE = 1, PARRY = 1, BLOCK = 0.5 },

  roles = {
    dmg = Dmg,
    tank = {
      STA = 1.00, ARMOR = 0.06, DEFENSE = 1, DODGE = 5, PARRY = 5, BLOCK = 3, BLOCKVAL = 0.3,
      STR = 0.55, AGI = 0.45, AP = 0.3, CRIT = 2, HIT = 4, WEAPON_MELEE = 3, HASTE_ATTACK = 2,
      LIFESTEAL = 1.5, HP5 = 0.2, HEALTH = 0.1,
    },
  },

  -- roleTalents[talent] = { role = weight per rank }. Deeper role-only talents weigh more, capstones most.
  roleMin = 3,
  roleTalents = {
    -- Arms
    ["Improved Heroic Strike"] = { dmg = 1 },
    ["Tactical Mastery"] = { dmg = 1, tank = 0.5 },
    ["Improved Rend"] = { dmg = 1 },
    ["Improved Charge"] = { dmg = 1 },
    ["Deflection"] = { dmg = 1, tank = 1 },
    ["Improved Thunder Clap"] = { dmg = 1, tank = 1 },
    ["Master Strike"] = { dmg = 4 },
    ["Improved Overpower"] = { dmg = 2 },
    ["Deep Wounds"] = { dmg = 2 },
    ["Two-Handed Weapon Specialization"] = { dmg = 3 },
    ["Impale"] = { dmg = 2 },
    ["Master of Arms"] = { dmg = 2 },
    ["Sweeping Strikes"] = { dmg = 5 },
    ["Boundless Anger"] = { dmg = 1 },
    ["Improved Disciplines"] = { dmg = 0.5, tank = 1.5 },
    ["Improved Slam"] = { dmg = 2 },
    ["Precision Cut"] = { dmg = 2 },
    ["Mortal Strike"] = { dmg = 15 },
    -- Fury
    ["Booming Voice"] = { dmg = 0.5 },
    ["Cruelty"] = { dmg = 2 },
    ["Dual Wield Specialization"] = { dmg = 3 },
    ["Unbridled Wrath"] = { dmg = 2 },
    ["Improved Shouts"] = { dmg = 1 },
    ["Blood Craze"] = { dmg = 1 },
    ["Enrage"] = { dmg = 3 },
    ["Ravager"] = { dmg = 2 },
    ["Death Wish"] = { dmg = 5 },
    ["Improved Execute"] = { dmg = 1 },
    ["Improved Berserker Rage"] = { dmg = 1 },
    ["Flurry"] = { dmg = 3 },
    ["Blood Drinker"] = { dmg = 2 },
    ["Bloodthirst"] = { dmg = 15 },
    -- Protection
    ["Improved Bloodrage"] = { tank = 1 },
    ["Shield Specialization"] = { tank = 2 },
    ["Anticipation"] = { tank = 2 },
    ["Iron Will"] = { tank = 1 },
    ["Toughness"] = { tank = 2 },
    ["Last Stand"] = { tank = 5 },
    ["Improved Intervene"] = { tank = 0.5 },
    ["Improved Taunt"] = { tank = 1 },
    ["Improved Revenge"] = { tank = 2 },
    ["Gag Order"] = { tank = 1 },
    ["Improved Disarm"] = { tank = 0.5 },
    ["Defiance"] = { tank = 3 },
    ["One-Handed Weapon Specialization"] = { tank = 2, dmg = 1 },
    ["Shield Slam"] = { tank = 8 },
    ["Improved Shield Slam"] = { tank = 2 },
    ["Reprisal"] = { tank = 2 },
    ["Improved Shield Wall"] = { tank = 1 },
    ["Defensive Tactics"] = { tank = 3 },
    ["Concussion Blow"] = { tank = 15 },
  },

  conv = {
    { from = "AGI", to = "CRIT", pct = function(c) return 100 / AgiPerCrit(c) end,
      note = function(c) return "Agility: 1 crit% per " .. string.format("%.1f", AgiPerCrit(c)) .. " at your level" end },
  },

  mods = {
    { talent = "Toughness", kind = "statpct", stat = "ARMOR", num = 1, text = "armor from items" },
    { talent = "Toughness", kind = "statpct", stat = "BLOCKVAL", num = 2, roles = { tank = true }, text = "damage absorbed by shield" },
    -- blocks give a warrior rage (Shield Specialization) and Revenge; Shield Slam hits harder with block value
    { talent = "Shield Specialization", kind = "add", stat = "BLOCK", value = 0.12, perRank = true, roles = { tank = true }, text = "each block gives rage" },
    { talent = "Improved Shield Slam", kind = "add", stat = "BLOCK", value = 0.1, perRank = true, roles = { tank = true }, text = "Shield Slam gives extra block chance" },
    { talent = "Shield Slam", kind = "add", stat = "BLOCKVAL", value = 0.15, roles = { tank = true }, text = "Shield Slam damage uses block value" },
    { talent = "Impale", kind = "statpct", stat = "CRIT", num = 1, roles = { dmg = true }, text = "crit damage" },
  },
}
