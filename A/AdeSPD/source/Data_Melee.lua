-- AdeSPD: attack power coefficients for melee / ranged abilities (English spell names).
--
-- Arcane Shot is listed only to mark it as ranged: its extra damage scales with spell power.
-- Physical school spells that deal "school damage" (bleeds, Gouge-like strikes, ...) use attack power
-- automatically. Other schools that scale with attack power (Arcane Shot) need ap = true here.
-- Abilities that hit for weapon damage (Sinister Strike, Heroic Strike, ...) already contain the attack
-- power in the weapon hit and are left alone. When they have an extra damage number (Steady Shot:
-- "an additional 50 damage") that number gets the attack power bonus, learned from combat.
--
-- Entry fields (same meaning as in Data.lua):
--   ap     = true     use attack power even when the spell school is not physical
--   ranged = true     use ranged attack power
--   d / o  = coefficient of attack power for the direct / over-time part (1.0 = 100% of AP)
-- Spells that scale with attack power but are not listed here are learned from combat like spells.
-- Combo point abilities (Eviscerate, Ferocious Bite, Rupture) are not learned, list them here if you know the values.
-- Only values I am sure about are listed: add more from the Turtle wiki.

AdeSPD_Melee = {
  ["Arcane Shot"]    = { ranged = true, school = "Arcane" },                 -- spell power, learned from combat
  ["Serpent Sting"]  = { ap = true, ranged = true, school = "Nature" },     -- learned from combat
  ["Kick"]           = { school = "Physical", d = 0 },                      -- flat damage, nothing scales
  ["Gouge"]          = { school = "Physical", d = 0 },
  ["Hamstring"]      = { school = "Physical", d = 0 },
  ["Thunder Clap"]   = { school = "Physical", d = 0 },
  ["Revenge"]        = { school = "Physical", d = 0 },
  ["Shield Bash"]    = { school = "Physical", d = 0 },
  ["Execute"]        = { school = "Physical", d = 0 },
  ["Steady Shot"]    = { ap = true, ranged = true, school = "Physical" },   -- learned from combat
  ["Aimed Shot"]     = { ap = true, ranged = true, school = "Physical" },
  ["Multi-Shot"]     = { ap = true, ranged = true, school = "Physical" },
}
