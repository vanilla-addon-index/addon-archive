-- Paladin. Base weights per role. First estimates, to be tuned in game.
--
-- heal = Holy: healing and spell power, Intellect and mp5 for mana. Armor is worth nothing by itself,
--        but the talent Ironclad turns armor into healing (see mods), so plate gets points from it.
-- tank = Protection: stamina, armor, defense, dodge, parry, block, strength (block value and threat).
-- dmg  = Retribution: weapon dps, strength (2 attack power each), crit and hit. A function of your
--        character (weapon dps, attack power, level) like the Hunter, so values follow your gear.
--
-- Currency: one point of spell power, healing power or attack power, whichever the role uses.
-- Hit and crit are worth 1% of your damage each (hit cap comes in step 4e).

local AG = AdeGear
AG.ClassData = AG.ClassData or {}

-- Agility needed for 1% crit (estimate, about 20 at level 60)
local function AgiPerCrit(c)
  local l = c.level or 60
  if l < 1 then l = 1 end
  if l > 60 then l = 60 end
  return 2.5 + (20 - 2.5) * (l - 1) / 59
end

local MELEE_SKILL = {
  Sword = "SKILL_SWORDS", Axe = "SKILL_AXES", Mace = "SKILL_MACES",
  Polearm = "SKILL_POLEARMS",
}

local function Ret(c)
  local l = c.level or 60
  local W = c.mainDps
  if not W or W <= 0 then W = l * 0.3 end
  local A = c.ap
  if not A or A <= 0 then A = 2 * l end
  local crit = 0.14 * (W + A / 14)
  local t = {
    WEAPON_MELEE = 10, AP = 1.0, STR = 2.0, AGI = 0.1,
    CRIT = crit, HIT = crit, HASTE_ATTACK = crit, ARMORPEN = 0.01 * crit, LIFESTEAL = 0.8,
    SP = 0.25, DMG_HOLY = 0.15, HEAL = 0,
    STA = 0.4, INT = 0.15, SPI = 0.05, MP5 = 0.6, HP5 = 0.1, ARMOR = 0.01,
  }
  local kind = c.mainItem and c.mainItem.weaponKind
  if kind and MELEE_SKILL[kind] then t[MELEE_SKILL[kind]] = 0.2 * crit end
  return t
end

AG.ClassData.PALADIN = {
  default = "dmg",
  currency = "1 point = 1 spell power or 1 attack power",
  needsCombat = true,
  order = { "WEAPON_MELEE", "AP", "STR", "AGI", "STA", "INT", "SPI", "SP", "HEAL", "DMG_HOLY", "CRIT", "HIT",
    "SPELLCRIT", "HASTE_ATTACK", "HASTE_CAST", "ARMORPEN", "LIFESTEAL", "DEFENSE", "DODGE", "PARRY", "BLOCK", "BLOCKVAL", "ARMOR", "MP5", "HP5", "HEALTH",
    "SKILL_SWORDS", "SKILL_AXES", "SKILL_MACES", "SKILL_POLEARMS" },

  -- value of avoidance: points per percent = factor x level-scaled value of one percent of health (Weights.lua)
  armorDR = true,
  avoid = { DEFENSE = 0.2, DODGE = 1, PARRY = 1, BLOCK = 0.5 },

  roles = {
    heal = {
      SP = 1.00, HEAL = 1.00, INT = 0.90, SPI = 0.25, STA = 0.25, MP5 = 2.2, SPELLCRIT = 5, HASTE_CAST = 5, LIFESTEAL = 0.2,
      ARMOR = 0, STR = 0, AGI = 0.05, HP5 = 0.1, DMG_HOLY = 0,
    },
    tank = {
      STA = 1.00, ARMOR = 0.06, DEFENSE = 1, DODGE = 5, PARRY = 5, BLOCK = 3, BLOCKVAL = 0.3,
      STR = 0.55, AGI = 0.45, AP = 0.3, CRIT = 2, HIT = 4, WEAPON_MELEE = 3, HASTE_ATTACK = 2, LIFESTEAL = 1.5,
      SP = 0.2, DMG_HOLY = 0.2, HEAL = 0, INT = 0.2, SPI = 0.05, MP5 = 0.6, HP5 = 0.2, HEALTH = 0.1,
    },
    dmg = Ret,
  },

  -- like the Priest: talents that point to a role, weight per rank. Deeper, role-only talents weigh more,
  -- capstones most. Talents that every role wants are left out.
  roleMin = 3,
  -- roleTalents[talent] = { role = weight per rank }. Deeper role-only talents weigh more, capstones most.
  -- Talents that two or three roles use carry a weight for each of them.
  roleMin = 3,
  roleTalents = {
    -- Holy
    ["Divine Strength"] = { dmg = 1, tank = 0.5 },
    ["Divine Intellect"] = { heal = 1 },
    ["Holy Judgement"] = { heal = 1 },
    ["Spiritual Focus"] = { heal = 1, dmg = 1, tank = 1 },
    ["Improved Seal of Righteousness"] = { dmg = 0.5, tank = 1 },
    ["Healing Light"] = { heal = 2 },
    ["Sanctity Aura"] = { dmg = 2, tank = 1.5 },
    ["Improved Lay on Hands"] = { heal = 1 },
    ["Improved Concentration Aura"] = { heal = 1 },
    ["Illumination"] = { heal = 2 },
    ["Ironclad"] = { heal = 3 },
    ["Divine Favor"] = { heal = 2 },
    ["Holy Shock"] = { heal = 5 },
    ["Holy Power"] = { heal = 2.5 },
    ["Daybreak"] = { heal = 15 },
    -- Protection
    ["Improved Devotion Aura"] = { tank = 1 },
    ["Redoubt"] = { tank = 1 },
    ["Guardian's Favor"] = { tank = 1 },
    ["Toughness"] = { tank = 2 },
    ["Improved Righteous Fury"] = { tank = 2 },
    ["Blessing of Sanctuary"] = { tank = 5 },
    ["Shield Specialization"] = { tank = 2 },
    ["Anticipation"] = { tank = 2 },
    ["Improved Hand of Reckoning"] = { tank = 1 },
    ["Improved Hammer of Justice"] = { tank = 1 },
    ["Righteous Defense"] = { tank = 2 },
    ["Holy Shield"] = { tank = 8 },
    ["Reckoning"] = { tank = 2 },
    ["Righteous Strikes"] = { tank = 2 },
    ["Bulwark of the Righteous"] = { tank = 20 },
    -- Retribution
    ["Improved Blessings"] = { heal = 1.5, dmg = 1 },
    ["Benediction"] = { dmg = 1 },
    ["Improved Judgement"] = { heal = 1.5, dmg = 1 },
    ["Improved Seal of the Crusader"] = { dmg = 1 },
    ["Deflection"] = { dmg = 1, tank = 1 },
    ["Improved Retribution Aura"] = { dmg = 1, tank = 2 },
    ["Conviction"] = { dmg = 2 },
    ["Pursuit of Justice"] = { dmg = 0.5 },
    ["Two-Handed Weapon Specialization"] = { dmg = 2 },
    ["Vindication"] = { dmg = 2 },
    ["Eye for an Eye"] = { dmg = 1 },
    ["Vengeance"] = { dmg = 3 },
    ["Seal of Command"] = { dmg = 5 },
    ["Vengeful Strikes"] = { dmg = 3 },
    ["Repentance"] = { dmg = 12 },
  },

  -- built-in: Agility gives crit
  conv = {
    { from = "INT", to = "SPELLCRIT", pct = function(c) return 100 / AG.Weights.IntPerCrit(c, 54) - 100 / 54 end,
      note = function(c) return "Intellect: 1 spell crit% per " .. string.format("%.0f", AG.Weights.IntPerCrit(c, 54)) .. " at your level" end },
    { from = "AGI", to = "CRIT", pct = function(c) return 100 / AgiPerCrit(c) end,
      note = function(c) return "Agility: 1 crit% per " .. string.format("%.1f", AgiPerCrit(c)) .. " at your level" end },
  },

  mods = {
    { talent = "Divine Strength", kind = "statpct", stat = "STR", num = 1, text = "total Strength" },
    { talent = "Divine Intellect", kind = "statpct", stat = "INT", num = 1, text = "total Intellect" },
    { talent = "Toughness", kind = "statpct", stat = "ARMOR", num = 1, text = "armor from items" },
    { talent = "Healing Light", kind = "statpct", stat = "SP", num = 1, roles = { heal = true }, text = "healing of Holy Light, Flash of Light, Holy Shock" },
    { talent = "Healing Light", kind = "statpct", stat = "HEAL", num = 1, roles = { heal = true }, text = "healing of Holy Light, Flash of Light, Holy Shock" },
    -- blocking does more than absorb for a paladin: Holy Shield and Reckoning turn blocks into threat and extra attacks
    { talent = "Holy Shield", kind = "add", stat = "BLOCK", value = 0.6, roles = { tank = true }, text = "each block hits back with holy damage and threat" },
    { talent = "Reckoning", kind = "add", stat = "BLOCK", value = 0.15, perRank = true, roles = { tank = true }, text = "a block can give an extra attack" },
    { talent = "Righteous Strikes", kind = "add", stat = "BLOCK", value = 0.1, perRank = true, roles = { tank = true }, text = "blocks stop more damage" },
    { talent = "Shield Specialization", kind = "statpct", stat = "BLOCKVAL", num = 1, roles = { tank = true }, text = "damage absorbed by shield" },
    -- Seal of Command and Judgements are holy damage: spell power becomes the second stat of a Retribution paladin
    { talent = "Seal of Command", kind = "add", stat = "SP", value = 0.75, roles = { dmg = true }, text = "holy damage from your seals counts: spell power matters" },
    { talent = "Seal of Command", kind = "add", stat = "DMG_HOLY", value = 0.25, roles = { dmg = true }, text = "holy damage from your seals counts" },
    { talent = "Ironclad", kind = "convert", from = "ARMOR", to = "HEAL", num = 1, roles = { heal = true }, text = "of Armor from items as healing" },
  },
}

