-- Shaman. Three roles, and two ways to do damage. First estimates, to be tuned in game (the author has
-- no Shaman to test with, so feedback from Shaman players is welcome).
--
-- heal = Restoration: healing power, Intellect, mp5.
-- tank = Enhancement with a shield: stamina, armor, defense, dodge, parry, block (Shield Specialization,
--        Ancestral Guardian, Spirit Armor point to it).
-- dmg  = Elemental or Enhancement. The style comes from your talents:
--        caster = spell damage (Nature, Fire, Frost), melee = weapon dps, strength, crit, hit.
--
-- Role comes from the talents you picked (/adeg role why), style too. Currency: 1 point = 1 spell power
-- or 1 attack power, whichever the role uses.

local AG = AdeGear
AG.ClassData = AG.ClassData or {}

local function AgiPerCrit(c)
  local l = c.level or 60
  if l < 1 then l = 1 end
  if l > 60 then l = 60 end
  return 2.5 + (20 - 2.5) * (l - 1) / 59
end

local MELEE_SKILL = {
  Axe = "SKILL_AXES", Mace = "SKILL_MACES", Dagger = "SKILL_DAGGERS", Staff = "SKILL_STAVES", Fist = "SKILL_FIST_WEAPONS",
}

local function Melee(c)
  local l = c.level or 60
  local W = c.mainDps
  if not W or W <= 0 then W = l * 0.3 end
  local A = c.ap
  if not A or A <= 0 then A = 2 * l end
  local crit = 0.14 * (W + A / 14)
  local t = {
    WEAPON_MELEE = 10, AP = 1.0, STR = 2.0, AGI = 0.1,
    CRIT = crit, HIT = crit, HASTE_ATTACK = crit, ARMORPEN = 0.01 * crit, LIFESTEAL = 0.8,
    SP = 0.2, DMG_NATURE = 0.2, HEAL = 0,
    STA = 0.4, INT = 0.2, SPI = 0.05, MP5 = 0.8, HP5 = 0.1, ARMOR = 0.012,
  }
  local kind = c.mainItem and c.mainItem.weaponKind
  if kind and MELEE_SKILL[kind] then t[MELEE_SKILL[kind]] = 0.2 * crit end
  return t
end

AG.ClassData.SHAMAN = {
  default = "dmg",
  currency = "1 point = 1 spell power or 1 attack power",
  needsCombat = true,
  order = { "WEAPON_MELEE", "AP", "STR", "AGI", "SP", "HEAL", "DMG_NATURE", "DMG_FIRE", "DMG_FROST",
    "INT", "STA", "SPI", "CRIT", "HIT", "SPELLCRIT", "SPELLHIT", "HASTE_ATTACK", "HASTE_CAST", "ARMORPEN",
    "DEFENSE", "DODGE", "PARRY", "BLOCK", "BLOCKVAL", "ARMOR", "MP5", "CASTREGEN", "LIFESTEAL", "HP5", "HEALTH",
    "SKILL_AXES", "SKILL_MACES", "SKILL_DAGGERS", "SKILL_STAVES", "SKILL_FIST_WEAPONS" },

  -- value of avoidance: points per percent = factor x level-scaled value of one percent of health (Weights.lua)
  armorDR = true,
  avoid = { DEFENSE = 0.2, DODGE = 1, PARRY = 1, BLOCK = 0.5 },

  roles = {
    heal = {
      SP = 1.00, HEAL = 1.00, INT = 0.80, SPI = 0.25, STA = 0.25, MP5 = 2.4, SPELLCRIT = 5, HASTE_CAST = 5,
      CASTREGEN = 0.5, LIFESTEAL = 0.2, HP5 = 0.1, ARMOR = 0.003, DMG_NATURE = 0,
    },
    tank = {
      STA = 1.00, ARMOR = 0.06, DEFENSE = 1, DODGE = 5, PARRY = 5, BLOCK = 3, BLOCKVAL = 0.3,
      STR = 0.8, AGI = 0.7, AP = 0.3, CRIT = 2, HIT = 4, WEAPON_MELEE = 3, HASTE_ATTACK = 2, LIFESTEAL = 1.5,
      SP = 0.2, DMG_NATURE = 0.2, HEAL = 0, INT = 0.2, SPI = 0.05, MP5 = 0.6, HP5 = 0.2, HEALTH = 0.1,
    },
    ["dmg:caster"] = {
      SP = 1.00, DMG_NATURE = 0.45, DMG_FIRE = 0.35, DMG_FROST = 0.1, HEAL = 0,
      INT = 0.50, SPI = 0.12, STA = 0.25, MP5 = 1.2, SPELLCRIT = 8, SPELLHIT = 11, HASTE_CAST = 10,
      CASTREGEN = 0.4, LIFESTEAL = 0.4, HP5 = 0.1, ARMOR = 0.004,
    },
    ["dmg:melee"] = Melee,
    dmg = Melee,
  },

  -- roleTalents[talent] = { role = weight per rank }
  roleMin = 3,
  roleTalents = {
    -- Elemental
    ["Convection"] = { dmg = 1 },
    ["Concussion"] = { dmg = 1 },
    ["Elemental Devastation"] = { dmg = 1 },
    ["Elemental Focus"] = { dmg = 3 },
    ["Reverberation"] = { dmg = 1 },
    ["Call of Thunder"] = { dmg = 2 },
    ["Improved Molten Blast"] = { dmg = 1 },
    ["Improved Fire Totems"] = { dmg = 1 },
    ["Call of Flame"] = { dmg = 2 },
    ["Storm Reach"] = { dmg = 1 },
    ["Elemental Mastery"] = { dmg = 5 },
    ["Elemental Fury"] = { dmg = 3 },
    ["Lightning Mastery"] = { dmg = 3 },
    ["Earthquake"] = { dmg = 12 },
    -- Enhancement
    ["Ancestral Knowledge"] = { dmg = 1, tank = 1 },
    ["Shield Specialization"] = { tank = 2 },
    ["Totemic Alignment"] = { tank = 1 },
    ["Thundering Strikes"] = { dmg = 1.5 },
    ["Improved Ghost Wolf"] = { dmg = 0.5 },
    ["Calming Winds"] = { dmg = 1 },
    ["Lightning Strike"] = { dmg = 4 },
    ["Ancestral Guardian"] = { tank = 2 },
    ["Flurry"] = { dmg = 3 },
    ["Spirit Armor"] = { tank = 2.5 },
    ["Enhancing Totems"] = { dmg = 1.5 },
    ["Elemental Weapons"] = { dmg = 3 },
    ["Stormstrike"] = { dmg = 8 },
    ["Element's Grace"] = { dmg = 3 },
    ["Bloodlust"] = { dmg = 12 },
    -- Restoration
    ["Improved Healing Wave"] = { heal = 1 },
    ["Tidal Focus"] = { heal = 1 },
    ["Ancestral Healing"] = { heal = 1.5 },
    ["Tidal Mastery"] = { heal = 2 },
    ["Healing Way"] = { heal = 2 },
    ["Healing Focus"] = { heal = 1.5 },
    ["Totemic Mastery"] = { heal = 3 },
    ["Restorative Totems"] = { heal = 2 },
    ["Improved Water Shield"] = { heal = 3 },
    ["Tidal Surge"] = { heal = 2 },
    ["Ancestral Swiftness"] = { heal = 3, dmg = 2 },
    ["Undertow"] = { heal = 2 },
    ["Improved Chain Heal"] = { heal = 3 },
    ["Spirit Link"] = { heal = 12 },
  },

  -- which way of damage: spells (Elemental) or weapon (Enhancement). Points per rank.
  styleDefault = "melee",
  styleMin = 3,
  styleTalents = {
    ["Convection"] = { caster = 1 }, ["Concussion"] = { caster = 1 }, ["Call of Thunder"] = { caster = 1 },
    ["Elemental Focus"] = { caster = 2 }, ["Reverberation"] = { caster = 1 }, ["Call of Flame"] = { caster = 1 },
    ["Elemental Mastery"] = { caster = 3 }, ["Elemental Fury"] = { caster = 1 }, ["Lightning Mastery"] = { caster = 1 },
    ["Earthquake"] = { caster = 5 }, ["Elemental Devastation"] = { caster = 0.5, melee = 0.5 },
    ["Thundering Strikes"] = { melee = 1 }, ["Lightning Strike"] = { melee = 4 }, ["Flurry"] = { melee = 1 },
    ["Elemental Weapons"] = { melee = 1 }, ["Stormstrike"] = { melee = 5 }, ["Element's Grace"] = { melee = 1 },
    ["Bloodlust"] = { melee = 5 }, ["Enhancing Totems"] = { melee = 1 }, ["Calming Winds"] = { melee = 1 },
    ["Improved Ghost Wolf"] = { melee = 0.5 }, ["Ancestral Knowledge"] = { melee = 0.5 },
  },

  conv = {
    { from = "INT", to = "SPELLCRIT", pct = function(c) return 100 / AG.Weights.IntPerCrit(c, 59.2) - 100 / 59.2 end,
      note = function(c) return "Intellect: 1 spell crit% per " .. string.format("%.0f", AG.Weights.IntPerCrit(c, 59.2)) .. " at your level" end },
    { from = "AGI", to = "CRIT", pct = function(c) return 100 / AgiPerCrit(c) end,
      note = function(c) return "Agility: 1 crit% per " .. string.format("%.1f", AgiPerCrit(c)) .. " at your level" end },
  },

  mods = {
    -- Ancestral Knowledge: all stats up
    { talent = "Ancestral Knowledge", kind = "statpct", stat = "STR", num = 1, text = "all stats" },
    { talent = "Ancestral Knowledge", kind = "statpct", stat = "AGI", num = 1, text = "all stats" },
    { talent = "Ancestral Knowledge", kind = "statpct", stat = "STA", num = 1, text = "all stats" },
    { talent = "Ancestral Knowledge", kind = "statpct", stat = "INT", num = 1, text = "all stats" },
    { talent = "Ancestral Knowledge", kind = "statpct", stat = "SPI", num = 1, text = "all stats" },
    -- cheaper spells stretch your mana
    { talent = "Convection", kind = "statpct", stat = "INT", num = 1, roles = { dmg = true }, styles = { caster = true }, text = "less mana for offensive spells" },
    { talent = "Convection", kind = "statpct", stat = "MP5", num = 1, roles = { dmg = true }, styles = { caster = true }, text = "less mana for offensive spells" },
    { talent = "Tidal Focus", kind = "statpct", stat = "INT", num = 1, roles = { heal = true }, text = "less mana for healing" },
    { talent = "Tidal Focus", kind = "statpct", stat = "MP5", num = 1, roles = { heal = true }, text = "less mana for healing" },
    { talent = "Ancestral Guardian", kind = "statpct", stat = "ARMOR", num = 1, text = "armor from items" },
    { talent = "Shield Specialization", kind = "statpct", stat = "BLOCKVAL", num = 2, roles = { tank = true }, text = "amount blocked" },
  },
}
