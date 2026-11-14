-- Mage. Only damage. 1 point = 1 spell power. First estimates, to be tuned in game.
--
-- The style is the school of your main talent tree: arcane, fire or frost (the tree with most points).
-- The spell damage of that school counts almost fully, other schools only a little.
-- Arcane Meditation (mana regen while casting) makes "Mana regen while casting %" from items worth much
-- more, because with that talent the percent adds to what you already get.

local AG = AdeGear
AG.ClassData = AG.ClassData or {}

local function School(main)
  return function(c)
    local t = {
      SP = 1.00, INT = 0.55, SPI = 0.15, STA = 0.2, MP5 = 1.5, SPELLCRIT = 9, SPELLHIT = 12,
      HP5 = 0.05, ARMOR = 0.002, CASTREGEN = 0.5,
      HASTE_CAST = 11, WEAPON_WAND = 0.04, LIFESTEAL = 0.4,
      DMG_ARCANE = 0.1, DMG_FIRE = 0.1, DMG_FROST = 0.1,
    }
    t["DMG_" .. main] = 0.85
    return t
  end
end

AG.ClassData.MAGE = {
  default = "dmg",
  currency = "1 point = 1 spell power",
  order = { "SP", "DMG_ARCANE", "DMG_FIRE", "DMG_FROST", "INT", "SPI", "STA", "MP5", "CASTREGEN",
    "SPELLCRIT", "SPELLHIT", "HASTE_CAST", "WEAPON_WAND", "LIFESTEAL", "HP5", "ARMOR" },

  roles = {
    ["dmg:arcane"] = School("ARCANE"),
    ["dmg:fire"] = School("FIRE"),
    ["dmg:frost"] = School("FROST"),
    dmg = School("FROST"),
  },

  styleTrees = { "arcane", "fire", "frost" },
  styleDefault = "frost",
  styleMin = 3,

  conv = {
    { from = "INT", to = "SPELLCRIT", pct = function(c) return 100 / AG.Weights.IntPerCrit(c, 59.5) - 100 / 59.5 end,
      note = function(c) return "Intellect: 1 spell crit% per " .. string.format("%.0f", AG.Weights.IntPerCrit(c, 59.5)) .. " at your level" end },
  },

  mods = {
    { talent = "Arcane Meditation", kind = "add", stat = "CASTREGEN", value = 0.3, perRank = true, text = "regen while casting counts much more" },
    { talent = "Arcane Meditation", kind = "add", stat = "SPI", value = 0.03, perRank = true, text = "Spirit regen continues while casting" },
    -- crit damage bonus: a crit is worth more
    { talent = "Arcane Potency", kind = "statpct", stat = "SPELLCRIT", num = 1, styles = { arcane = true }, text = "arcane crit damage" },
    { talent = "Ice Shards", kind = "statpct", stat = "SPELLCRIT", num = 1, styles = { frost = true }, text = "frost crit damage" },
  },
}
