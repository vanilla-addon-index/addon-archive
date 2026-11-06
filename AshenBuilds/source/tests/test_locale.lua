-- Non-English clients: race and class are stored with their English names.
local AB = AshenBuilds
UnitRace = function() return "Mensch", "Human" end
UnitClass = function() return "Krieger", "WARRIOR" end
local b = AB.NewBuildData("German")
check("German client: race stored as Human", b.race == "Human")
check("German client: class stored as Warrior", b.class == "Warrior")
UnitRace = function() return "Nachtelf", "NightElf" end
check("Night Elf token maps to the race list name", AB.PlayerRace() == "Night Elf")
UnitRace = function() return "Untoter", "Scourge" end
check("Scourge token maps to Undead", AB.PlayerRace() == "Undead")
UnitRace = function() return "Hochelf", "BloodElf" end
check("Turtle High Elf token maps to High Elf", AB.PlayerRace() == "High Elf")

-- Builds saved on a German client before 1.0 are fixed up when loaded.
UnitRace = function() return "Mensch", "Human" end
UnitClass = function() return "Magier", "MAGE" end
local old = {class = "Magier", race = "Mensch", level = 60, items = {}, enchants = {}}
AB:MigrateBuild(old)
check("old German build: class becomes Mage (not reset to Warrior)", old.class == "Mage")
check("old German build: race becomes Human", old.race == "Human")
local other = {class = "Warrior", race = "Night Elf", level = 60}
AB:MigrateBuild(other)
check("English builds are left alone", other.class == "Warrior" and other.race == "Night Elf")
