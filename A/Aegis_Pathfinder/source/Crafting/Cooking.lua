--[[
	Cooking recipes, for the crafting route planner (CraftPlanner.lua).

	GENERATED FILE -- do not edit by hand.
	Source:    CraftRoute by Kitymeowmeow (GPLv3), data_cooking.lua
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

AegisPathfinder:RegisterRecipeBook("Cooking", {
	"Brilliant Smallfish = Raw Brilliant Smallfish @ 1-45-65-85 | book Recipe: Brilliant Smallfish ~200",
	"Charred Wolf Meat = Stringy Wolf Meat @ 1-45-65-85 | trainer ~200 | skip | nomake",
	"Crispy Bat Wing = Meaty Bat Wing + Mild Spices @ 1-45-65-85 | trainer ~200 | skip | nomake",
	"Gingerbread Cookie = Holiday Spices + Small Egg @ 1-45-65-85 | trainer ~200 | skip | nomake",
	"Herb Baked Egg = Small Egg + Mild Spices @ 1-45-65-85 | trainer ~200 | skip | nomake",
	"Roasted Boar Meat = Chunk of Boar Meat @ 1-45-65-85 | trainer ~200",
	"Slitherskin Mackerel = Raw Slitherskin Mackerel @ 1-45-65-85 | book Recipe: Slitherskin Mackerel ~200",
	"Kaldorei Spider Kabob = Small Spider Leg @ 10-50-70-90 | trainer ~200 | skip | nomake",
	"Spiced Wolf Meat = Stringy Wolf Meat + Mild Spices @ 10-50-70-90 | trainer ~200 | skip | nomake",
	"Scorpid Surprise = Scorpid Stinger @ 20-60-80-100 | trainer ~200 | skip | nomake",
	"Beer Basted Boar Ribs = Crag Boar Rib + Rhapsody Malt @ 25-60-80-100 | trainer ~200 | skip | nomake",
	"Egg Nog = Holiday Spices + Small Egg + Holiday Spirits + Ice Cold Milk @ 35-75-95-115 | trainer ~200 | skip | nomake",
	"Maritime Gumbo = Crawler Meat + Refreshing Spring Water @ 35-75-95-115 | trainer ~200 | skip | nomake",
	"Roasted Kodo Meat = Mild Spices + Kodo Meat @ 35-75-95-115 | trainer ~200 | skip | nomake",
	"Smoked Bear Meat = Bear Meat @ 40-80-100-120 | book Recipe: Smoked Bear Meat ~200",
	"Boiled Clams = Clam Meat + Refreshing Spring Water @ 50-90-110-130 | trainer ~200",
	"Coyote Steak = Coyote Meat @ 50-90-110-130 | trainer ~200",
	"Fillet of Frenzy = Soft Frenzy Flesh + Mild Spices @ 50-90-110-130 | trainer ~200 | skip | nomake",
	"Goretusk Liver Pie = Goretusk Liver + Mild Spices @ 50-90-110-130 | trainer ~200 | skip | nomake",
	"Loch Frenzy Delight = Raw Loch Frenzy + Mild Spices @ 50-90-110-130 | trainer ~200 | skip | nomake",
	"Longjaw Mud Snapper = Raw Longjaw Mud Snapper @ 50-90-110-130 | book Recipe: Longjaw Mud Snapper ~200",
	"Rainbow Fin Albacore = Raw Rainbow Fin Albacore @ 50-90-110-130 | book Recipe: Rainbow Fin Albacore ~200",
	"Strider Stew = Strider Meat + Shiny Red Apple @ 50-90-110-130 | trainer ~200 | skip | nomake",
	"Blood Sausage = Spider Ichor + Bear Meat + Boar Intestines @ 60-100-120-140 | trainer ~200 | skip | nomake",
	"Thistle Tea = Swiftthistle + Refreshing Spring Water @ 60-100-120-140 | book Recipe: Thistle Tea ~200",
	"Crab Cake = Crawler Meat + Mild Spices @ 75-115-135-155 | trainer ~200 | skip | nomake",
	"Westfall Stew = Murloc Eye + Goretusk Snout + Stringy Vulture Meat @ 75-115-135-155 | trainer ~200 | skip | nomake",
	"Crocolisk Steak = Crocolisk Meat + Mild Spices @ 80-120-140-160 | trainer ~200 | skip | nomake",
	"Dry Pork Ribs = Boar Ribs + Mild Spices @ 80-120-140-160 | trainer ~200",
	"Smoked Sagefish = Raw Sagefish + Mild Spices @ 80-120-140-160 | book Recipe: Smoked Sagefish ~200",
	"Cooked Crab Claw = Crawler Claw + Mild Spices @ 85-125-145-165 | book Recipe: Cooked Crab Claw ?",
	"Savory Deviate Delight = Deviate Fish + Mild Spices @ 85-125-145-165 | trainer ~200",
	"Clam Chowder = Clam Meat + Ice Cold Milk + Mild Spices @ 90-130-150-170 | trainer ~200",
	"Dig Rat Stew = Dig Rat @ 90-130-150-170 | trainer ~200 | skip | nomake",
	"Murloc Fin Soup = 2 Murloc Fin + Hot Spices @ 90-130-150-170 | trainer ~200 | skip | nomake",
	"Redridge Goulash = Tough Condor Meat + Crisp Spider Meat @ 100-135-155-175 | trainer ~500 | skip | nomake",
	"Bristle Whisker Catfish = Raw Bristle Whisker Catfish @ 100-140-160-180 | book Recipe: Bristle Whisker Catfish ~500",
	"Crispy Lizard Tail = Hot Spices + Thunder Lizard Tail @ 100-140-160-180 | trainer ~500 | skip | nomake",
	"Seasoned Wolf Kabob = 2 Lean Wolf Flank + Stormwind Seasoning Herbs @ 100-140-160-180 | trainer ~500 | skip | nomake",
	"Succulent Pork Ribs = Hot Spices + 2 Boar Ribs @ 110-130-150-170 | book Recipe: Succulent Pork Ribs ?",
	"Big Bear Steak = Big Bear Meat + Hot Spices @ 110-150-170-190 | book Recipe: Big Bear Steak ~500",
	"Gooey Spider Cake = Hot Spices + 2 Gooey Spider Leg @ 110-150-170-190 | trainer ~500 | skip | nomake",
	"Lean Venison = Stag Meat + 4 Mild Spices @ 110-150-170-190 | book Recipe: Lean Venison ~500",
	"Crocolisk Gumbo = Tender Crocolisk Meat + Hot Spices @ 120-160-180-200 | trainer ~500 | skip | nomake",
	"Goblin Deviled Clams = Hot Spices + Tangy Clam Meat @ 125-165-185-205 | trainer ~500",
	"Lean Wolf Steak = Lean Wolf Flank + Mild Spices @ 125-165-185-205 | trainer ~500 | skip | nomake",
	"Hot Lion Chops = Hot Spices + Lion Meat @ 125-175-195-215 | book Recipe: Hot Lion Chops ~500",
	"Curiously Tasty Omelet = Hot Spices + Raptor Egg @ 130-170-190-210 | book Recipe: Curiously Tasty Omelet ~500",
	"Heavy Crocolisk Stew = 2 Tender Crocolisk Meat + Soothing Spices @ 150-160-180-200 | trainer ~500 | skip | nomake",
	"Tasty Lion Steak = Soothing Spices + 2 Lion Meat @ 150-190-210-230 | trainer ~500 | skip | nomake",
	"Rockscale Cod = Raw Rockscale Cod @ 175-190-210-230 | book Recipe: Rockscale Cod ~500",
	"Ambersap Glazed Boar Ribs = Ambersap + Boar Ribs + Hot Spices @ 175-215-235-255 | book Recipe: Ambersap Glazed Boar Ribs ~500",
	"Barbecued Buzzard Wing = Hot Spices + Buzzard Wing @ 175-215-235-255 | book Recipe: Barbecued Buzzard Wing ~500",
	"Carrion Surprise = Hot Spices + Mystery Meat @ 175-215-235-255 | book Recipe: Carrion Surprise ~500",
	"Crawford Apple Tarte = Goldenbark Apple + Northwind Flour + Ice Cold Milk @ 175-215-235-255 | trainer ~500",
	"Giant Clam Scorcho = Hot Spices + Giant Clam Meat @ 175-215-235-255 | book Recipe: Giant Clam Scorcho ~500",
	"Goldthorn Tea = Goldthorn + Refreshing Spring Water @ 175-215-235-255 | trainer ~500 | skip | nomake",
	"Hot Wolf Ribs = Hot Spices + Red Wolf Meat @ 175-215-235-255 | book Recipe: Hot Wolf Ribs ~500",
	"Jungle Stew = 2 Shiny Red Apple + Tiger Meat + Refreshing Spring Water @ 175-215-235-255 | book Recipe: Jungle Stew ~500",
	"Mithril Head Trout = Raw Mithril Head Trout @ 175-215-235-255 | book Recipe: Mithril Head Trout ~500",
	"Mystery Stew = Mystery Meat + Skin of Dwarven Stout @ 175-215-235-255 | trainer ~500 | skip | nomake",
	"Roast Raptor = Raptor Flesh + Hot Spices @ 175-215-235-255 | book Recipe: Roast Raptor ~500",
	"Sagefish Delight = Raw Greater Sagefish + Hot Spices @ 175-215-235-255 | book Recipe: Sagefish Delight ~500",
	"Soothing Turtle Bisque = Soothing Spices + Turtle Meat @ 175-215-235-255 | book Recipe: Soothing Turtle Bisque ?",
	"Gilneas Hot Stew = Red Wolf Meat + White Spider Meat + Refreshing Spring Water @ 200-225-245-265 | book Recipe: Gilneas Hot Stew ~2700",
	"Dragonbreath Chili = Hot Spices + Small Flame Sac + Mystery Meat @ 200-240-260-280 | book Recipe: Dragonbreath Chili ~2700",
	"Heavy Kodo Stew = Soothing Spices + 2 Heavy Kodo Meat + Refreshing Spring Water @ 200-240-260-280 | book Recipe: Heavy Kodo Stew ~2700",
	"Spider Sausage = 2 White Spider Meat @ 200-240-260-280 | trainer ~2700",
	"Cooked Glossy Mightfish = Soothing Spices + Raw Glossy Mightfish @ 225-265-285-305 | book Recipe: Cooked Glossy Mightfish ~2700",
	"Filet of Redgill = Raw Redgill @ 225-265-285-305 | book Recipe: Filet of Redgill ~2700",
	"Monster Omelet = 2 Soothing Spices + Giant Egg @ 225-265-285-305 | book Recipe: Monster Omelet ~2700",
	"Spiced Chili Crab = 2 Hot Spices + Tender Crab Meat @ 225-265-285-305 | book Recipe: Spiced Chili Crab ~2700",
	"Spotted Yellowtail = Raw Spotted Yellowtail @ 225-265-285-305 | book Recipe: Spotted Yellowtail ~2700",
	"Tender Wolf Steak = Soothing Spices + Tender Wolf Meat @ 225-265-285-305 | book Recipe: Tender Wolf Steak ~2700",
	"Undermine Clam Chowder = Hot Spices + Ice Cold Milk + 2 Zesty Clam Meat @ 225-265-285-305 | book Recipe: Undermine Clam Chowder ~2700",
	"Grilled Squid = Soothing Spices + Winter Squid @ 240-280-300-320 | book Recipe: Grilled Squid ~2700",
	"Hot Smoked Bass = 2 Hot Spices + Raw Summer Bass @ 240-280-300-320 | book Recipe: Hot Smoked Bass ~2700",
	"Nightfin Soup = Raw Nightfin Snapper + Refreshing Spring Water @ 250-290-310-330 | book Recipe: Nightfin Soup ~2700",
	"Poached Sunscale Salmon = Raw Sunscale Salmon @ 250-290-310-330 | book Recipe: Poached Sunscale Salmon ~2700",
	"Fried Strider with a Side of Berries = Meaty Strider Leg + Moonwhisper Berry + 2 Hot Spices @ 275-275-285-305 | trainer ~2700 | skip | nomake",
	"Baked Salmon = Soothing Spices + Raw Whitescale Salmon @ 275-315-335-355 | book Recipe: Baked Salmon ~2700",
	"Lobster Stew = Darkclaw Lobster + Refreshing Spring Water @ 275-315-335-355 | book Recipe: Lobster Stew ~2700",
	"Mightfish Steak = Hot Spices + Soothing Spices + Large Raw Mightfish @ 275-315-335-355 | book Recipe: Mightfish Steak ~2700",
	"Runn Tum Tuber Surprise = Runn Tum Tuber + Soothing Spices @ 275-315-335-355 | trainer ~2700 | skip | nomake",
})
