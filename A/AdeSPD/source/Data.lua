-- AdeSPD: known spell power coefficients (English spell names).
--
-- Source: Turtle WoW wiki "Spell-Coefficients" (TheoryCraft based) and the Turtle class pages.
-- Spells that are NOT listed here are learned from combat (see Learn.lua).
--
-- Entry fields:
--   school = "Fire" | "Frost" | "Shadow" | "Nature" | "Arcane" | "Holy"   (damage spells)
--   heal   = true                 uses bonus healing instead of bonus damage
--   d      = coefficient of the direct part (or the absorb of a shield)
--   o      = coefficient of the over-time part, TOTAL for the whole duration
--   ct     = cast time (sec) that 'd' is valid for. Ranks that cast faster get d * cast / ct.
--   mult   = extra multiplier on every coefficient of the entry (Turtle balance changes)
--   drank  = { [rank] = coefficient } overrides 'd' for specific ranks
--
-- A part with no coefficient is left untouched (e.g. Fireball's DoT) unless a learned value exists.

AdeSPD_Data = {
  ---------------------------------------------------------------- Mage
  ["Frostbolt"]          = { school = "Frost",  d = 0.814, ct = 3.0 },
  ["Frost Nova"]         = { school = "Frost",  d = 0.1357 },
  ["Cone of Cold"]       = { school = "Frost",  d = 0.1357 },
  ["Blizzard"]           = { school = "Frost",  o = 0.33 },
  ["Arcane Explosion"]   = { school = "Arcane", d = 0.1428 },
  ["Arcane Rupture"]     = { school = "Arcane", d = 1.0 },              -- wiki (patch 1.17.2), unverified
  ["Fireball"]           = { school = "Fire",   d = 1.0, o = 0, ct = 3.5 },   -- DoT part is 0
  ["Fire Blast"]         = { school = "Fire",   d = 0.4285 },           -- 1.5/3.5
  ["Pyroblast"]          = { school = "Fire",   d = 1.0, o = 0.70 },
  ["Scorch"]             = { school = "Fire",   d = 0.4285 },
  ["Flamestrike"]        = { school = "Fire",   o = 0.0681 },

  ---------------------------------------------------------------- Warlock
  ["Shadow Bolt"]        = { school = "Shadow", d = 0.8571, ct = 3.0 },
  ["Soul Fire"]          = { school = "Fire",   d = 1.0 },
  ["Searing Pain"]       = { school = "Fire",   d = 0.4285 },
  ["Immolate"]           = { school = "Fire",   d = 0.1865, o = 0.6363 },
  ["Conflagrate"]        = { school = "Fire",   d = 0.4285 },
  ["Rain of Fire"]       = { school = "Fire",   o = 0.33 },
  ["Corruption"]         = { school = "Shadow", o = 1.0 },
  ["Curse of Agony"]     = { school = "Shadow", o = 1.0 },
  ["Drain Soul"]         = { school = "Shadow", o = 1.0 },
  ["Death Coil"]         = { school = "Shadow", d = 0.2142 },

  ---------------------------------------------------------------- Priest
  -- Turtle: Mind Blast 60%, Mind Flay 75%, Holy Fire 100%, Power Word: Shield 35% (ranks 1-3: 10%).
  -- Turtle: healing spells -15% scaling (mult = 0.85), unverified.
  ["Smite"]              = { school = "Holy",   d = 0.7142, ct = 2.5 },
  ["Holy Fire"]          = { school = "Holy",   d = 1.0, ct = 3.5 },
  ["Mind Blast"]         = { school = "Shadow", d = 0.60 },
  ["Mind Flay"]          = { school = "Shadow", o = 0.75 },
  ["Shadow Word: Pain"]  = { school = "Shadow", o = 1.0 },
  ["Devouring Plague"]   = { school = "Shadow", o = 0.5 },
  ["Flash Heal"]         = { heal = true, d = 0.4285, mult = 0.85 },
  ["Greater Heal"]       = { heal = true, d = 0.8571, ct = 3.0, mult = 0.85 },
  ["Heal"]               = { heal = true, d = 0.8571, ct = 3.0, mult = 0.85 },
  ["Prayer of Healing"]  = { heal = true, d = 0.2857, mult = 0.85 },
  ["Renew"]              = { heal = true, o = 1.0, mult = 0.85 },
  ["Power Word: Shield"] = { heal = true, d = 0.35, drank = { [1] = 0.10, [2] = 0.10, [3] = 0.10 } },

  ---------------------------------------------------------------- Druid
  -- Turtle: Wrath +5% (57.14% -> 60%).
  ["Wrath"]              = { school = "Nature", d = 0.60, ct = 2.0 },
  ["Starfire"]           = { school = "Arcane", d = 1.0 },
  ["Moonfire"]           = { school = "Arcane", d = 0.1495, o = 0.5209 },
  ["Insect Swarm"]       = { school = "Nature", o = 0.76 },
  ["Entangling Roots"]   = { school = "Nature", o = 0.4071 },
  ["Healing Touch"]      = { heal = true, d = 1.0, ct = 3.5 },
  ["Regrowth"]           = { heal = true, d = 0.1865, o = 0.6363 },
  ["Rejuvenation"]       = { heal = true, o = 0.80 },
  ["Tranquility"]        = { heal = true, o = 0.33 },

  ---------------------------------------------------------------- Paladin
  ["Holy Light"]         = { heal = true, d = 0.71, ct = 2.5 },
  ["Flash of Light"]     = { heal = true, d = 0.4285 },
  ["Exorcism"]           = { school = "Holy", d = 0.4285 },
  ["Holy Wrath"]         = { school = "Holy", d = 0.19 },
  ["Hammer of Wrath"]    = { school = "Holy", d = 0.2857 },
  ["Consecration"]       = { school = "Holy", o = 0.33 },

  ---------------------------------------------------------------- Shaman
  ["Lightning Bolt"]     = { school = "Nature", d = 0.8571, ct = 3.0 },
  ["Chain Lightning"]    = { school = "Nature", d = 0.7142, ct = 2.5 },
  ["Healing Wave"]       = { heal = true, d = 0.8571, ct = 3.0 },
  ["Lesser Healing Wave"]= { heal = true, d = 0.4285 },
  ["Chain Heal"]         = { heal = true, d = 0.6142 },
}
