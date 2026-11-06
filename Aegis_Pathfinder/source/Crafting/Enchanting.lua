--[[
	Enchanting recipes, for the crafting route planner (CraftPlanner.lua).

	GENERATED FILE -- do not edit by hand.
	Source:    CraftRoute by Kitymeowmeow (GPLv3), data_enchanting.lua
	Generator: Tools/build/import_recipes.py

	One recipe a line, ordered by the skill it turns orange at:

	  "<recipe> = <reagents> @ <orange>-<yellow>-<green>-<grey> | <learned> [| skip] [| nomake]"

	Reagents are joined by " + ", each with its count in front when that is
	more than one; "#<id>" is an item no database could name, which the game
	names once it has seen it. <learned> is how the recipe is learned:
	"trainer <copper>", "book <item> <copper>" or "book <item> ?", "quest",
	"drop" or "special"; a ~ marks an estimated cost. "skip" keeps a recipe
	out of routes (cooldowns, rare drops); "nomake" stops the planner making
	it to supply another recipe. Tools/build/import_recipes.py documents each.
]]

AegisPathfinder:RegisterRecipeBook("Enchanting", {
	"Runed Copper Rod = Copper Rod + Strange Dust + Lesser Magic Essence @ 1-5-7-10 | trainer ~200",
	"Enchant Bracer - Minor Health = Strange Dust @ 1-70-90-110 | trainer ~200",
	"Enchant Bracer - Minor Deflect = Lesser Magic Essence + Strange Dust @ 1-80-100-120 | trainer ~200",
	"Lesser Magic Wand = Simple Wood + Lesser Magic Essence @ 10-75-95-115 | trainer ~200",
	"Enchant Chest - Minor Health = Strange Dust @ 15-70-90-110 | trainer ~200",
	"Enchant Chest - Minor Mana = Lesser Magic Essence @ 20-80-100-120 | book Formula: Enchant Chest - Minor Mana ~200",
	"Enchant Chest - Minor Absorption = 2 Strange Dust + Lesser Magic Essence @ 40-90-110-130 | trainer ~200",
	"Enchant Cloak - Minor Resistance = Strange Dust + 2 Lesser Magic Essence @ 45-95-115-135 | trainer ~200",
	"Enchant Bracer - Minor Stamina = 3 Strange Dust @ 50-100-120-140 | trainer ~200",
	"Enchant Bracer - Minor Spirit = 2 Lesser Magic Essence @ 60-105-125-145 | book Formula: Enchant Bracer - Minor Spirit ~200",
	"Enchant Chest - Lesser Health = 2 Strange Dust + 2 Lesser Magic Essence @ 60-105-125-145 | trainer ~200",
	"Enchant Cloak - Minor Protection = 3 Strange Dust + Greater Magic Essence @ 70-110-130-150 | trainer ~200",
	"Greater Magic Wand = Simple Wood + Greater Magic Essence @ 70-110-130-150 | trainer ~200",
	"Enchant Bracer - Minor Agility = 2 Strange Dust + Greater Magic Essence @ 80-115-135-155 | trainer ~200",
	"Enchant Bracer - Minor Strength = 5 Strange Dust @ 80-115-135-155 | book Formula: Enchant Bracer - Minor Strength ~200",
	"Enchant Chest - Lesser Mana = Greater Magic Essence + Lesser Magic Essence @ 80-115-135-155 | book Formula: Enchant Chest - Lesser Mana ~200 | skip",
	"Enchant Weapon - Minor Striking = 2 Strange Dust + Greater Magic Essence + Small Glimmering Shard @ 90-120-140-160 | trainer ~200",
	"Enchant 2H Weapon - Lesser Intellect = 3 Greater Magic Essence @ 100-130-150-170 | book Formula: Enchant 2H Weapon - Lesser Intellect ~500",
	"Enchant 2H Weapon - Minor Impact = 4 Strange Dust + Small Glimmering Shard @ 100-130-150-170 | trainer ~200",
	"Runed Silver Rod = Silver Rod + 6 Strange Dust + 3 Greater Magic Essence + Shadowgem @ 100-130-150-170 | trainer ~500",
	"Enchant Shield - Minor Stamina = Lesser Astral Essence + 2 Strange Dust @ 105-130-150-170 | trainer ~500",
	"Enchant Cloak - Minor Agility = Lesser Astral Essence @ 110-135-155-175 | book Formula: Enchant Cloak - Minor Agility ~500",
	"Enchant Cloak - Lesser Protection = 6 Strange Dust + Small Glimmering Shard @ 115-140-160-180 | trainer ~500",
	"Enchant Bracer - Lesser Spirit = 2 Lesser Astral Essence @ 120-145-165-185 | book Formula: Enchant Bracer - Lesser Spirit ~500",
	"Enchant Chest - Health = 4 Strange Dust + Lesser Astral Essence @ 120-145-165-185 | trainer ~500",
	"Enchant Boots - Minor Stamina = 8 Strange Dust @ 125-150-170-190 | book Formula: Enchant Boots - Minor Stamina ~500",
	"Enchant Bracer - Lesser Stamina = 2 Soul Dust @ 130-155-175-195 | trainer ~500",
	"Enchant Bracer - Lesser Strength = 2 Soul Dust @ 140-165-185-205 | book Formula: Enchant Bracer - Lesser Strength ~500",
	"Enchant Bracer - Lesser Intellect = 2 Greater Astral Essence @ 150-175-195-215 | trainer 2500",
	"Runed Golden Rod = Golden Rod + Iridescent Pearl + 2 Greater Astral Essence + 2 Soul Dust @ 150-175-195-215 | trainer ~500",
	"Enchant Shield - Lesser Stamina = Lesser Mystic Essence + Soul Dust @ 155-175-195-215 | trainer ~500",
	"Enchant Chest - Greater Health = 3 Soul Dust @ 160-180-200-220 | trainer ~500",
	"Enchant Bracer - Spirit = Lesser Mystic Essence @ 165-185-205-225 | trainer ~500",
	"Enchant Bracer - Stamina = 6 Soul Dust @ 170-190-210-230 | trainer ~500",
	"Enchant Bracer - Strength = Vision Dust @ 180-200-220-240 | trainer ~500",
	"Enchant Bracer - Agility +5 = Lesser Mystic Essence + Elemental Earth @ 185-185-197-210 | trainer ~500",
	"Enchant Bracer - Vampirism = Greater Mystic Essence + 2 Large Fang @ 185-205-207-210 | book Formula: Enchant Bracer - Vampirism ~500",
	"Enchant Chest - Greater Mana = Greater Mystic Essence @ 185-205-225-245 | trainer ~500",
	"Enchant Weapon - Striking = 2 Greater Mystic Essence + Large Glowing Shard @ 195-215-235-255 | trainer ~500",
	"Runed Truesilver Rod = Truesilver Rod + Black Pearl + 2 Greater Mystic Essence + 2 Vision Dust @ 200-220-240-260 | trainer ~2700",
	"Enchant Cloak - Greater Defense = 3 Vision Dust @ 205-225-245-265 | trainer ~2700",
	"Enchant Bracer - Intellect = 2 Lesser Nether Essence @ 210-230-250-270 | trainer ~2700",
	"Enchant Gloves - Agility = Lesser Nether Essence + Vision Dust @ 210-230-250-270 | trainer ~2700",
	"Enchant Boots - Stamina = 5 Vision Dust @ 215-235-255-275 | trainer ~2700",
	"Enchant Chest - Superior Health = 6 Vision Dust @ 220-240-260-280 | trainer ~2700",
	"Enchant Boots - Agility = 2 Greater Nether Essence @ 235-255-275-295 | trainer ~2700",
	"Enchant Bracer - Greater Strength = 2 Dream Dust + Greater Nether Essence @ 240-260-280-300 | trainer ~2700",
	"Enchant Bracer - Greater Stamina = 5 Dream Dust @ 245-265-285-305 | book Formula: Enchant Bracer - Greater Stamina ~2700",
	"Enchanted Thorium Bar = 3 Dream Dust + Thorium Bar @ 250-250-255-260 | trainer ~2700",
	"Lesser Mana Oil = 3 Dream Dust + 2 Purple Lotus + Crystal Vial @ 250-260-270-280 | book Formula: Lesser Mana Oil ~2700",
	"Enchant Boots - Greater Stamina = 10 Dream Dust @ 260-280-300-320 | book Formula: Enchant Boots - Greater Stamina ~2700",
	"Enchant Shield - Greater Stamina = 10 Dream Dust @ 265-285-305-325 | trainer ~2700",
	"Enchanted Gemstone Oil = Gemstone Oil + Greater Eternal Essence + Greater Nether Essence @ 275-275-277-280 | book Formula: Enchanted Gemstone Oil ~2700",
	"Enchant Chest - Major Health = 6 Illusion Dust + Small Brilliant Shard @ 275-295-315-335 | book Formula: Enchant Chest - Major Health ~2700",
	"Enchant Cloak - Superior Defense = 8 Illusion Dust @ 285-305-325-345 | book Formula: Enchant Cloak - Superior Defense ~2700",
	"Runed Arcanite Rod = Arcanite Rod + Golden Pearl + 10 Illusion Dust + 4 Greater Eternal Essence + 4 Small Brilliant Shard + 2 Large Brilliant Shard @ 290-310-330-350 | book Formula: Runed Arcanite Rod ~2700",
})
