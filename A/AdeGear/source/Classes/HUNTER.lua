-- Hunter. Base weights per style, 1 point = 1 attack power. First estimates, to be tuned in game.
--
-- dmg:ranged  = bow, gun or crossbow hunter (Marksmanship, Beast Mastery): ranged attack power, the
--               weapon and the ammo dps. 1 dps of weapon or ammo is worth 14 attack power (an attack
--               power point adds 1/14 dps), so a better bow or arrow is worth a lot.
-- dmg:melee   = Survival melee hunter: strength and agility give attack power. Weapon dps AND the size of
--               one hit count: Mongoose Bite does a percent of weapon damage, so a slower weapon with
--               bigger hits is better at the same dps (see Model.lua).
-- The tables are functions of your character (attack power, weapon dps, level), so values follow your gear.
-- Crit and hit are worth 1% of your total damage each, here in attack power (hit cap comes in step 4e).
--
-- Style (ranged or melee) comes from the talents you picked, see styleTalents. Tanks and healers do not
-- exist for hunters, every role mix ends up in the damage tables.

local AG = AdeGear
AG.ClassData = AG.ClassData or {}

-- Agility needed for 1% crit (estimate, grows with level)
local function AgiPerCrit(c)
  local l = c.level or 60
  if l < 1 then l = 1 end
  if l > 60 then l = 60 end
  return 4.5 + (53 - 4.5) * (l - 1) / 59
end

local SKILL_KEY = { Bow = "SKILL_BOWS", Gun = "SKILL_GUNS", Crossbow = "SKILL_CROSSBOWS" }
local MELEE_SKILL = {
  Sword = "SKILL_SWORDS", Axe = "SKILL_AXES", Mace = "SKILL_MACES", Dagger = "SKILL_DAGGERS",
  Polearm = "SKILL_POLEARMS", Staff = "SKILL_STAVES", Fist = "SKILL_FIST_WEAPONS",
}

local function Ranged(c)
  local M = AG.Model
  local p = M.Params(c, true)
  local m = M.Derive(M.hunterRanged, p)
  -- for a ranged Hunter the size of one shot hardly matters (about 1.6% at equal dps), so it is folded
  -- into the dps weight instead of being its own row
  local t = {
    WEAPON_RANGED = m.a + m.b * p.s, AMMO_DPS = m.ammo, WEAPON_MELEE = 1.5,
    RAP = 1.0, AP = 1.0, AGI = 2.0, STR = 0,   -- 1 Agility = 2 ranged attack power (and 1 melee)
    CRIT = m.crit, HIT = m.crit, HASTE_ATTACK = m.haste, ARMORPEN = 0.01 * m.crit, LIFESTEAL = 0.8,
    STA = 0.3, INT = 0.35, SPI = 0.1, MP5 = 1.0, HP5 = 0.1, ARMOR = 0.005,
  }
  local kind = c.rangedItem and c.rangedItem.weaponKind
  if kind and SKILL_KEY[kind] then t[SKILL_KEY[kind]] = 0.2 * m.crit end
  return t
end

local function Melee(c)
  local M = AG.Model
  local m = M.Derive(M.hunterMelee, M.Params(c))
  local t = {
    WEAPON_MELEE = m.a, WEAPON_HIT = m.b, WEAPON_RANGED = 1.5, AMMO_DPS = 1.5,
    AP = 1.0, RAP = 0.3, AGI = 1.6, STR = 1.0,   -- 1 Agility = 1 melee + 2 ranged attack power (ranged counts 0.3)
    CRIT = m.crit, HIT = m.crit, HASTE_ATTACK = m.haste, ARMORPEN = 0.01 * m.crit, LIFESTEAL = 0.8,
    STA = 0.35, INT = 0.25, SPI = 0.1, MP5 = 0.8, HP5 = 0.1, ARMOR = 0.01,
  }
  local kind = c.mainItem and c.mainItem.weaponKind
  if kind and MELEE_SKILL[kind] then t[MELEE_SKILL[kind]] = 0.2 * m.crit end
  return t
end

AG.ClassData.HUNTER = {
  default = "dmg",
  currency = "1 point = 1 attack power",
  needsCombat = true,
  offHandHit = true,
  order = { "WEAPON_RANGED", "AMMO_DPS", "WEAPON_MELEE", "WEAPON_HIT", "RAP", "AP", "STR", "AGI", "CRIT", "HIT",
    "HASTE_ATTACK", "ARMORPEN", "LIFESTEAL", "STA", "INT", "SPI", "MP5", "HP5", "ARMOR", "SKILL_BOWS", "SKILL_GUNS", "SKILL_CROSSBOWS" },

  roles = {
    ["dmg:ranged"] = Ranged,
    ["dmg:melee"] = Melee,
    dmg = Ranged,
  },

  -- which style your talents point to (points per rank), ranged or melee
  styleDefault = "ranged",
  styleMin = 3,
  styleTalents = {
    ["Lethal Shots"] = { ranged = 1 },
    ["Mortal Shots"] = { ranged = 1 },
    ["Ranged Weapon Specialization"] = { ranged = 1 },
    ["Improved Marksmanship"] = { ranged = 1 },
    ["Barrage"] = { ranged = 1 },
    ["Aimed Shot"] = { ranged = 2 },
    ["Endless Quiver"] = { ranged = 1 },
    ["Piercing Shots"] = { ranged = 1 },
    ["Efficiency"] = { ranged = 0.5 },
    ["Lock and Load"] = { ranged = 2 },
    ["Experimental Ammunition"] = { ranged = 2 },
    ["Swiftshot"] = { ranged = 1 },
    ["Hawk Eye"] = { ranged = 0.5 },
    ["Savage Strikes"] = { melee = 1 },
    ["Vicious Strikes"] = { melee = 1 },
    ["Lightning Reflexes"] = { melee = 1.5 },
    ["Carve"] = { melee = 2 },
    ["Lacerate"] = { melee = 2 },
    ["Swift Reflexes"] = { melee = 1 },
    ["Improved Wing Clip"] = { melee = 0.5 },
    ["Stinging Nettle"] = { melee = 0.5 },
  },

  -- built-in: Agility gives crit chance (a point of Agility is worth a part of the crit weight)
  conv = {
    { from = "AGI", to = "CRIT", pct = function(c) return 100 / AgiPerCrit(c) end,
      note = function(c) return "Agility: 1 crit% per " .. string.format("%.1f", AgiPerCrit(c)) .. " at your level" end },
  },

  mods = {
    { talent = "Mortal Shots", kind = "statpct", stat = "CRIT", num = 1, styles = { ranged = true }, text = "ranged crit damage" },
    { talent = "Killer Instinct", kind = "statpct", stat = "CRIT", num = 2, styles = { melee = true }, text = "melee crit damage" },
    { talent = "Lightning Reflexes", kind = "statpct", stat = "AGI", num = 1, text = "total Agility" },
    { talent = "Lightning Reflexes", kind = "convert", from = "AGI", to = "AP", num = 2, styles = { melee = true }, text = "of Agility as melee attack power" },
    { talent = "Survivalist", kind = "statpct", stat = "STA", num = 1, text = "total health" },
    { talent = "Efficiency", kind = "statpct", stat = "INT", num = 1, text = "less mana for shots" },
    { talent = "Efficiency", kind = "statpct", stat = "MP5", num = 1, text = "less mana for shots" },
  },
}
