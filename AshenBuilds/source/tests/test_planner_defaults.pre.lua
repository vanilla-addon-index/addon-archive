-- A level 0 (not yet known) Gnome Mage logging in, on an account whose shared
-- planner build belongs to a Warrior.
LEVEL = 0
function UnitClass() return "Mage", "MAGE" end
function UnitRace() return "Gnome", "Gnome" end
function UnitLevel() return LEVEL end
AshenBuildsDB = {builds = {}, current = {name = "Old", class = "Warrior", race = "Human", level = 60, spec = "Arms", items = {HEAD = 1}, enchants = {}}}
