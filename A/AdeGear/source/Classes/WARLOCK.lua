-- Warlock. Only damage. 1 point = 1 spell power. First estimates, to be tuned in game.
--
-- The style is the talent tree with most points: affliction (shadow damage over time), demonology (demon
-- and mixed damage), destruction (shadow bolt and fire). It decides which school counts most.
-- Stamina is worth more than for other casters: Life Tap turns health into mana, and Demonic Embrace
-- trades Spirit for Stamina, so Spirit is worth little.

local AG = AdeGear
AG.ClassData = AG.ClassData or {}

local function Style(shadow, fire)
  return function(c)
    return {
      SP = 1.00, DMG_SHADOW = shadow, DMG_FIRE = fire, DMG_ARCANE = 0, DMG_FROST = 0,
      INT = 0.50, SPI = 0.08, STA = 0.45, MP5 = 1.0, SPELLCRIT = 8, SPELLHIT = 12,
      HASTE_CAST = 10, WEAPON_WAND = 0.06, LIFESTEAL = 0.5, HP5 = 0.1, ARMOR = 0.002,
    }
  end
end

AG.ClassData.WARLOCK = {
  default = "dmg",
  currency = "1 point = 1 spell power",
  order = { "SP", "DMG_SHADOW", "DMG_FIRE", "INT", "STA", "SPI", "MP5", "SPELLCRIT", "SPELLHIT",
    "HASTE_CAST", "WEAPON_WAND", "LIFESTEAL", "HP5", "ARMOR" },

  roles = {
    ["dmg:affliction"] = Style(0.85, 0.15),
    ["dmg:demonology"] = Style(0.5, 0.35),
    ["dmg:destruction"] = Style(0.5, 0.5),
    dmg = Style(0.85, 0.15),
  },

  styleTrees = { "affliction", "demonology", "destruction" },
  styleDefault = "affliction",
  styleMin = 3,

  conv = {
    { from = "INT", to = "SPELLCRIT", pct = function(c) return 100 / AG.Weights.IntPerCrit(c, 60.6) - 100 / 60.6 end,
      note = function(c) return "Intellect: 1 spell crit% per " .. string.format("%.0f", AG.Weights.IntPerCrit(c, 60.6)) .. " at your level" end },
  },

  mods = {
    -- Demonic Embrace: more Stamina, less Spirit
    { talent = "Demonic Embrace", kind = "statpct", stat = "STA", num = 1, text = "total Stamina" },
    { talent = "Demonic Embrace", kind = "statpct", stat = "SPI", num = 2, sign = -1, text = "total Spirit" },
    -- cheaper destruction spells stretch your mana
    { talent = "Cataclysm", kind = "statpct", stat = "INT", num = 1, styles = { destruction = true }, text = "less mana for Destruction spells" },
    { talent = "Cataclysm", kind = "statpct", stat = "MP5", num = 1, styles = { destruction = true }, text = "less mana for Destruction spells" },
    -- Ruin: crits of Destruction spells hit much harder
    { talent = "Ruin", kind = "statpct", stat = "SPELLCRIT", num = 1, styles = { destruction = true }, text = "Destruction crit damage" },
  },
}
