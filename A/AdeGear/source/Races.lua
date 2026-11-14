-- Racial passives that change what a stat is worth: percent boosts to a stat.
-- Weapon skill bonuses (Human swords +3, Dwarf guns +3 ...) are already in the skill numbers the game
-- reports, so the hit caps use them without a table. Plain additions (Night Elf haste and dodge, Human
-- regen while casting) do not change what one more point of a stat is worth, and pet damage (Orc) is not counted.

local AG = AdeGear
local Races = {}
AG.Races = Races

Races.data = {
  Gnome = { { stat = "INT", pct = 5, text = "Gnome: +5% Intellect" } },
  Human = { { stat = "SPI", pct = 5, text = "Human: +5% Spirit" } },
  ["High Elf"] = { { stat = "AGI", pct = 2, text = "High Elf: +2% Agility" } },
  Tauren = {
    { stat = "STA", pct = 5, text = "Tauren: +5% total health" },
    { stat = "HEALTH", pct = 5, text = "Tauren: +5% total health" },
  },
  Troll = {
    { stat = "HP5", pct = 20, text = "Troll: +20% health regeneration" },
  },
}

-- other client spellings of the same races
Races.alias = { Scourge = "Undead", ["Blood Elf"] = "High Elf" }

function Races.Current()
  local ok, name = pcall(UnitRace, "player")
  if not ok or not name then return nil end
  return Races.alias[name] or name
end

-- list of { stat, pct, text } for a race name
function Races.Mods(name)
  return (name and Races.data[name]) or {}
end
