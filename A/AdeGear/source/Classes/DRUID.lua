-- Druid. Four ways to play, from your picked talents. First estimates, to be tuned in game.
--
-- heal = Restoration (caster form): healing power, Intellect, Spirit and mana regen.
-- dmg, style caster = Balance (Moonkin/caster form): spell damage, Intellect, crit, hit.
-- dmg, style cat    = Feral Cat: attack power, Strength, Agility, crit, hit.
-- tank = Feral Bear: stamina, armor (bear form multiplies armor from items), dodge, defense.
-- Bear armor from items is multiplied by the form, so armor counts a lot for the tank. Role (heal/dmg/tank) and style (caster/cat) come from the talents you picked (/adeg role why). Hybrid
-- gear for several forms is not blended: you are valued as your main way of playing.
--
-- In cat and bear form your weapon damage does not matter (only the stats on it, and "feral attack
-- power" on staves and maces), so weapon dps is worth nothing there.
-- Currency: 1 point = 1 spell power, healing power or attack power, whichever the form uses.

local AG = AdeGear
AG.ClassData = AG.ClassData or {}

local function AgiPerCrit(c)
  local l = c.level or 60
  if l < 1 then l = 1 end
  if l > 60 then l = 60 end
  return 2.5 + (20 - 2.5) * (l - 1) / 59
end

-- cat damage does not come from a weapon: about 0.8 per level plus attack power / 14
local function CatCrit(c)
  local l = c.level or 60
  local ap = c.ap
  if not ap or ap < 12 * l then ap = 12 * l end
  return 0.14 * (0.8 * l + ap / 14)
end

local function Cat(c)
  local crit = CatCrit(c)
  return {
    AP = 1.0, FERAL_AP = 1.0, STR = 2.0, AGI = 1.0,
    CRIT = crit, HIT = crit, HASTE_ATTACK = crit * 0.6, LIFESTEAL = 0.5,
    STA = 0.45, INT = 0.15, SPI = 0.05, ARMOR = 0.012, DODGE = 2, HP5 = 0.1, HEALTH = 0.05, MP5 = 0.3,
  }
end

AG.ClassData.DRUID = {
  default = "dmg",
  currency = "1 point = 1 spell power, healing power or attack power",
  needsCombat = true,
  order = { "SP", "HEAL", "DMG_ARCANE", "DMG_NATURE", "AP", "FERAL_AP", "STR", "AGI", "INT", "SPI", "STA",
    "CRIT", "HIT", "SPELLCRIT", "SPELLHIT", "HASTE_ATTACK", "HASTE_CAST", "DEFENSE", "DODGE", "ARMOR",
    "MP5", "CASTREGEN", "LIFESTEAL", "HP5", "HEALTH" },

  -- value of avoidance: points per percent = factor x level-scaled value of one percent of health (Weights.lua)
  avoid = { DEFENSE = 0.2, DODGE = 1 },

  roles = {
    heal = {
      SP = 1.00, HEAL = 1.00, INT = 0.80, SPI = 0.45, STA = 0.20, MP5 = 2.4, SPELLCRIT = 5, HASTE_CAST = 5,
      CASTREGEN = 0.6, LIFESTEAL = 0.2, HP5 = 0.1, ARMOR = 0.003, DMG_ARCANE = 0, DMG_NATURE = 0,
      AP = 0, FERAL_AP = 0,
    },
    tank = {
      STA = 1.25, ARMOR = 0.3, DEFENSE = 1, DODGE = 5, STR = 0.3, AGI = 0.35, AP = 0.15, FERAL_AP = 0.2,
      CRIT = 2, HIT = 4, HASTE_ATTACK = 1, LIFESTEAL = 1.5, INT = 0.1, SPI = 0.05, HP5 = 0.2, HEALTH = 0.1, MP5 = 0.3,
    },
    ["dmg:caster"] = function(c)
      return {
        SP = 1.00, DMG_ARCANE = 0.45, DMG_NATURE = 0.45, HEAL = 0,
        INT = 0.50, SPI = 0.20, STA = 0.25, MP5 = 1.2, SPELLCRIT = 8, SPELLHIT = 11, HASTE_CAST = 10,
        CASTREGEN = 0.4, LIFESTEAL = 0.4, HP5 = 0.1, ARMOR = 0.004, AP = 0, FERAL_AP = 0,
      }
    end,
    ["dmg:cat"] = Cat,
    dmg = function(c)
      return {
        SP = 1.00, DMG_ARCANE = 0.45, DMG_NATURE = 0.45, HEAL = 0,
        INT = 0.50, SPI = 0.20, STA = 0.25, MP5 = 1.2, SPELLCRIT = 8, SPELLHIT = 11, HASTE_CAST = 10,
        CASTREGEN = 0.4, LIFESTEAL = 0.4, HP5 = 0.1, ARMOR = 0.004, AP = 0, FERAL_AP = 0,
      }
    end,
  },

  -- roleTalents[talent] = { role = weight per rank }
  -- Feral talents that work in both cat and bear count for damage and tank equally. Only bear: Thick Hide,
  -- Feral Charge, Feral Instinct, Feral Swiftness (its dodge only matters when you tank). Only cat: Open
  -- Wounds, Improved Shred. Natural Weapons, Omen of Clarity and Furor are for every feral druid.
  roleMin = 3,
  roleTalents = {
    -- Feral Combat, bear only
    ["Thick Hide"] = { tank = 4 }, ["Feral Charge"] = { tank = 3 }, ["Feral Instinct"] = { tank = 2 },
    ["Feral Swiftness"] = { tank = 2 },
    -- Feral Combat, cat only
    ["Open Wounds"] = { dmg = 2 }, ["Improved Shred"] = { dmg = 2 },
    -- Feral Combat, cat and bear
    ["Ferocity"] = { dmg = 1, tank = 1 }, ["Feral Aggression"] = { dmg = 1, tank = 1 },
    ["Brutal Impact"] = { dmg = 1, tank = 1 }, ["Sharpened Claws"] = { dmg = 1, tank = 1 },
    ["Primal Fury"] = { dmg = 1, tank = 1 }, ["Predatory Strikes"] = { dmg = 1, tank = 1 },
    ["Blood Frenzy"] = { dmg = 1, tank = 1 }, ["Ancient Brutality"] = { dmg = 1, tank = 1 },
    ["Berserk"] = { dmg = 1, tank = 1 }, ["Heart of the Wild"] = { dmg = 1, tank = 1 },
    ["Carnage"] = { dmg = 1, tank = 1 }, ["Leader of the Pack"] = { dmg = 1, tank = 1 },
    -- other trees, feral only
    ["Natural Weapons"] = { dmg = 1, tank = 1 }, ["Furor"] = { dmg = 1, tank = 1 },
    -- Omen of Clarity: everyone except healers
    ["Omen of Clarity"] = { dmg = 1, tank = 1 },
    -- Balance (caster damage)
    ["Improved Wrath"] = { dmg = 1 }, ["Nature's Grasp"] = { dmg = 0.5 }, ["Improved Nature's Grasp"] = { dmg = 0.5 },
    ["Sylvan Blessing"] = { dmg = 1 }, ["Guidance of the Dream"] = { dmg = 1 }, ["Improved Moonfire"] = { dmg = 1 },
    ["Moonfury"] = { dmg = 2 }, ["Nature's Reach"] = { dmg = 0.5 }, ["Vengeance"] = { dmg = 2 },
    ["Moonglow"] = { dmg = 1, heal = 1 }, ["Owlkin Frenzy"] = { dmg = 2 }, ["Moonkin Form"] = { dmg = 5 },
    ["Nature's Grace"] = { dmg = 4 }, ["Improved Starfire"] = { dmg = 2 }, ["Balance of All Things"] = { dmg = 3 },
    ["Gale Winds"] = { dmg = 2 }, ["Eclipse"] = { dmg = 12 },
    -- Restoration
    ["Improved Healing Touch"] = { heal = 1 }, ["Nature's Focus"] = { heal = 1.5 },
    ["Subtlety"] = { heal = 1 }, ["Swiftmend"] = { heal = 5 }, ["Genesis"] = { heal = 2 }, ["Reflection"] = { heal = 2 },
    ["Gift of Nature"] = { heal = 2 }, ["Tranquil Spirit"] = { heal = 2 }, ["Aessina's Bloom"] = { heal = 3 },
    ["Nature's Swiftness"] = { heal = 4, dmg = 2 }, ["Preservation"] = { heal = 2 }, ["Improved Regrowth"] = { heal = 2.5 },
    ["Improved Tranquility"] = { heal = 1.5 }, ["Tree of Life Form"] = { heal = 14 },
  },

  -- damage in caster form (Balance) or in cat form. Points per rank. Talents that only a bear uses are not here.
  styleDefault = "caster",
  styleMin = 3,
  styleTalents = {
    ["Improved Wrath"] = { caster = 1 }, ["Improved Moonfire"] = { caster = 1 }, ["Moonfury"] = { caster = 2 },
    ["Vengeance"] = { caster = 2 }, ["Owlkin Frenzy"] = { caster = 1 }, ["Moonkin Form"] = { caster = 4 },
    ["Nature's Grace"] = { caster = 3 }, ["Improved Starfire"] = { caster = 2 }, ["Balance of All Things"] = { caster = 2 },
    ["Eclipse"] = { caster = 8 }, ["Guidance of the Dream"] = { caster = 1 },
    ["Open Wounds"] = { cat = 2 }, ["Improved Shred"] = { cat = 2 },
    ["Ferocity"] = { cat = 1 }, ["Feral Aggression"] = { cat = 1 }, ["Brutal Impact"] = { cat = 1 },
    ["Sharpened Claws"] = { cat = 1 }, ["Primal Fury"] = { cat = 1 }, ["Predatory Strikes"] = { cat = 1 },
    ["Blood Frenzy"] = { cat = 1 }, ["Ancient Brutality"] = { cat = 1 }, ["Berserk"] = { cat = 1 },
    ["Heart of the Wild"] = { cat = 1 }, ["Leader of the Pack"] = { cat = 3 }, ["Natural Weapons"] = { cat = 1 },
    ["Furor"] = { cat = 1 },
  },

  conv = {
    { from = "INT", to = "SPELLCRIT", pct = function(c) return 100 / AG.Weights.IntPerCrit(c, 60) - 100 / 60 end,
      note = function(c) return "Intellect: 1 spell crit% per " .. string.format("%.0f", AG.Weights.IntPerCrit(c, 60)) .. " at your level" end },
    { from = "AGI", to = "CRIT", pct = function(c) return 100 / AgiPerCrit(c) end,
      note = function(c) return "Agility: 1 crit% per " .. string.format("%.1f", AgiPerCrit(c)) .. " at your level" end },
  },

  mods = {
    -- Heart of the Wild: Intellect always, Stamina in bear form, Strength in cat form
    { talent = "Heart of the Wild", kind = "statpct", stat = "INT", num = 1, text = "total Intellect" },
    { talent = "Heart of the Wild", kind = "statpct", stat = "STA", num = 2, roles = { tank = true }, text = "Stamina in bear form" },
    { talent = "Heart of the Wild", kind = "statpct", stat = "STR", num = 3, roles = { dmg = true }, styles = { cat = true }, text = "Strength in cat form" },
    { talent = "Thick Hide", kind = "statpct", stat = "ARMOR", num = 1, text = "armor from items" },
    -- Predatory Strikes: melee attack power in forms
    { talent = "Predatory Strikes", kind = "statpct", stat = "AP", num = 1, roles = { dmg = true, tank = true }, text = "attack power in forms" },
    { talent = "Predatory Strikes", kind = "statpct", stat = "FERAL_AP", num = 1, roles = { dmg = true, tank = true }, text = "attack power in forms" },
    { talent = "Predatory Strikes", kind = "statpct", stat = "STR", num = 1, roles = { dmg = true, tank = true }, text = "attack power in forms" },
    { talent = "Predatory Strikes", kind = "statpct", stat = "AGI", num = 1, roles = { dmg = true, tank = true }, text = "attack power in forms" },
    -- Restoration
    { talent = "Gift of Nature", kind = "statpct", stat = "SP", num = 1, roles = { heal = true }, text = "healing" },
    { talent = "Gift of Nature", kind = "statpct", stat = "HEAL", num = 1, roles = { heal = true }, text = "healing" },
    { talent = "Tranquil Spirit", kind = "statpct", stat = "INT", num = 1, roles = { heal = true }, text = "less mana for healing" },
    { talent = "Tranquil Spirit", kind = "statpct", stat = "MP5", num = 1, roles = { heal = true }, text = "less mana for healing" },
    { talent = "Moonglow", kind = "statpct", stat = "INT", num = 1, roles = { heal = true }, text = "less mana for spells" },
    { talent = "Moonglow", kind = "statpct", stat = "MP5", num = 1, roles = { heal = true }, text = "less mana for spells" },
    { talent = "Moonglow", kind = "statpct", stat = "INT", num = 1, roles = { dmg = true }, styles = { caster = true }, text = "less mana for spells" },
    { talent = "Moonglow", kind = "statpct", stat = "MP5", num = 1, roles = { dmg = true }, styles = { caster = true }, text = "less mana for spells" },
    { talent = "Reflection", kind = "add", stat = "CASTREGEN", value = 0.2, perRank = true, roles = { heal = true }, text = "regen while casting counts more" },
    { talent = "Reflection", kind = "add", stat = "SPI", value = 0.03, perRank = true, roles = { heal = true }, text = "Spirit regen continues while casting" },
    -- Balance: crit damage
    { talent = "Vengeance", kind = "statpct", stat = "SPELLCRIT", num = 1, roles = { dmg = true }, styles = { caster = true }, text = "crit damage of Starfire, Moonfire, Wrath" },
  },
}
