-- Priest. Base weights per role, 1 point = 1 spell power. First estimates, to be tuned in game.
--
-- dmg  = spell damage priest (Discipline, Shadow, Smite): spell power, then Intellect for crit and mana
-- heal = healing priest (Holy): healing power, Intellect and Spirit for mana
-- Healing-only power (HEAL) is worth nothing to a damage priest, school power (DMG_*) only half
-- (about half of the spells are of that school).
--
-- Talent rules: talent = English talent name, num = which number of the talent text (as {num} in
-- AdeTalents), text = what is shown after the percent.

local AG = AdeGear
AG.ClassData = AG.ClassData or {}

AG.ClassData.PRIEST = {
  default = "dmg",
  currency = "1 point = 1 spell power",
  order = { "SP", "HEAL", "DMG_HOLY", "DMG_SHADOW", "INT", "SPI", "STA", "MP5", "SPELLCRIT", "SPELLHIT", "HASTE_CAST", "WEAPON_WAND", "LIFESTEAL", "HP5", "ARMOR" },
  roles = {
    dmg = {
      SP = 1.00, HEAL = 0, DMG_HOLY = 0.5, DMG_SHADOW = 0.5,
      INT = 0.50, SPI = 0.12, STA = 0.25, MP5 = 1.2,
      SPELLCRIT = 7, SPELLHIT = 9, HP5 = 0.1, ARMOR = 0.004,
      HASTE_CAST = 8, WEAPON_WAND = 0.08, LIFESTEAL = 0.4,
    },
    heal = {
      SP = 1.00, HEAL = 1.00, DMG_HOLY = 0, DMG_SHADOW = 0,
      INT = 0.70, SPI = 0.40, STA = 0.20, MP5 = 2.5,
      SPELLCRIT = 5, SPELLHIT = 0, HP5 = 0.1, ARMOR = 0.004,
      HASTE_CAST = 5, WEAPON_WAND = 0.03, LIFESTEAL = 0.2,
    },
  },
  -- Role from the talents you picked. Weight per rank, heal / dmg.
  -- roleMin: fewer points than this and the class default role is used (start of leveling).
  roleMin = 3,
  roleTalents = {
    -- healing and shielding (deeper = heavier; first-row talents anyone takes as a path stay light)
    ["Improved Renew"] = { heal = 1 },
    ["Improved Power Word: Shield"] = { heal = 1 },
    ["Inspiration"] = { heal = 1 },
    ["Reservoir of Light"] = { heal = 1 },
    ["Improved Healing"] = { heal = 2 },
    ["Empowered Recovery"] = { heal = 2 },
    ["Book of Prayer"] = { heal = 2 },
    ["Spiritual Healing"] = { heal = 2 },
    ["Resurgent Shield"] = { heal = 3 },
    -- Holy capstone: about 30% of all the other healing talents together (they add up to 39)
    ["Ascendance"] = { heal = 12 },
    -- damage
    ["Piercing Light"] = { dmg = 1 },
    ["Spirit Tap"] = { dmg = 0.5 },
    ["Improved Mind Blast"] = { dmg = 1 },
    ["Shadow Focus"] = { dmg = 1 },
    ["Blackout"] = { dmg = 0.5 },
    ["Improved Shadow Word: Pain"] = { dmg = 1 },
    ["Shadow Weaving"] = { dmg = 1 },
    ["Shadow Reach"] = { dmg = 0.3 },
    ["Searing Light"] = { dmg = 2 },
    ["Purifying Flames"] = { dmg = 2 },
    ["Darkness"] = { dmg = 1.5 },
    ["Mind Flay"] = { dmg = 2 },
    ["Shadowform"] = { dmg = 3 },
    -- Discipline talents that serve more than one role
    ["Enlighten"] = { heal = 1.5, dmg = 1.5 },       -- buff for you or a teammate, both roles
    ["Force of Will"] = { dmg = 2.5, heal = 0.5 },   -- spell damage and crit, plus stronger shield
    ["Chastise"] = { dmg = 4.5, heal = 1.5 },        -- Discipline capstone; also a casting speed buff on an ally
    -- left out on purpose (neutral): Wand Specialization (healers use it for mana), Divine Fury,
    -- Meditation, Spiritual Guidance, Mental Strength, Spirit of Redemption, Divinity ...
  },
  conv = {
    { from = "INT", to = "SPELLCRIT", pct = function(c) return 100 / AG.Weights.IntPerCrit(c, 59.2) - 100 / 59.2 end,
      note = function(c) return "Intellect: 1 spell crit% per " .. string.format("%.0f", AG.Weights.IntPerCrit(c, 59.2)) .. " at your level" end },
  },

  mods = {
    { talent = "Mental Strength", kind = "statpct", stat = "INT", num = 1, text = "total Intellect" },
    { talent = "Spirit of Redemption", kind = "statpct", stat = "SPI", num = 1, text = "total Spirit" },
    { talent = "Spiritual Guidance", kind = "convert", from = "SPI", to = "SP", num = 1, text = "of total Spirit as spell power" },
  },
}
