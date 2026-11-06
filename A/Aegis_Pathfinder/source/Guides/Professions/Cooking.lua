-- Cooking (1-300)
--
-- GENERATED FILE -- do not edit by hand.
-- Source:    CraftRoute's Cooking route (GPLv3, Kitymeowmeow), planned by its
--            own planner and saved in Tools/data/craftroute_routes.json by
--            Tools/build/import_routes.py; reagents and recipe sources from
--            Crafting/Cooking.lua; trainers from
--            Tools/data/Professions_Reference.docx and
--            Tools/data/profession_training.json
-- Generator: Tools/build/convert_professions.py
--
-- Regenerate with:  python3 Tools/build/convert_professions.py


AegisPathfinder:RegisterQuestShellPlusGuide("Cooking (1-300)", {
	faction = "Both",
	category = "Profession",
	steps = {
		{
			type = "NOTE",
			title = "Cooking (1-300)",
			note = "CraftRoute's cheapest 1-300 route, planned from auction prices of 30 July 2026. Craft counts are the average it takes, rounded up (about 524 crafts in total). Nobody was selling Raw Brilliant Smallfish, Raw Longjaw Mud Snapper, Raw Bristle Whisker Catfish, Raw Mithril Head Trout and Raw Sunscale Salmon then, so they were costed at 3 times what a merchant pays. For a route planned from today's prices, open Cheapest route on the shopping list.",
		},
		{
			type = "TRAIN",
			title = "Learn Cooking (Apprentice)",
			note = "Costs 5 copper. Trainers: Cook Ghilm (Dun Morogh), Gremlock Pilsnor (Dun Morogh), Tomas (Elwynn Forest), Verrus Trueshine (Alah'Thalas).",
			faction = "Alliance",
			rank = { profession = "Cooking", cap = 75 },
			npcs = { "Cook Ghilm", "Gremlock Pilsnor", "Tomas", "Verrus Trueshine" },
		},
		{
			type = "TRAIN",
			title = "Learn Cooking (Apprentice)",
			note = "Costs 5 copper. Trainers: Cook Torka (Durotar), Pyall Silentstride (Mulgore), Duhng (The Barrens), Shazzlan (Blackstone Island).",
			faction = "Horde",
			rank = { profession = "Cooking", cap = 75 },
			npcs = { "Cook Torka", "Pyall Silentstride", "Duhng", "Shazzlan" },
		},
		{
			type = "USE",
			title = "Craft 65x Brilliant Smallfish",
			note = "Takes you from 1 to 50.",
			skill = { profession = "Cooking", from = 1, to = 50 },
			craft = { item = "Brilliant Smallfish", count = 65 },
			reagents = { { item = "Raw Brilliant Smallfish", qty = 1 } },
			source = "Recipe: Brilliant Smallfish",
		},
		{
			type = "TRAIN",
			title = "Train Journeyman Cooking (Cap 150)",
			note = "Needs skill 50; costs 5 silver. Trainers: Verrus Trueshine (Alah'Thalas), Cook Ghilm (Dun Morogh), Gremlock Pilsnor (Dun Morogh), Tomas (Elwynn Forest).",
			faction = "Alliance",
			rank = { profession = "Cooking", cap = 150 },
			npcs = { "Verrus Trueshine", "Cook Ghilm", "Gremlock Pilsnor", "Tomas" },
		},
		{
			type = "TRAIN",
			title = "Train Journeyman Cooking (Cap 150)",
			note = "Needs skill 50; costs 5 silver. Trainers: Cook Torka (Durotar), Pyall Silentstride (Mulgore), Duhng (The Barrens), Shazzlan (Blackstone Island).",
			faction = "Horde",
			rank = { profession = "Cooking", cap = 150 },
			npcs = { "Cook Torka", "Pyall Silentstride", "Duhng", "Shazzlan" },
		},
		{
			type = "USE",
			title = "Craft 33x Brilliant Smallfish",
			note = "Takes you from 50 to 75.",
			skill = { profession = "Cooking", from = 50, to = 75 },
			craft = { item = "Brilliant Smallfish", count = 33 },
			reagents = { { item = "Raw Brilliant Smallfish", qty = 1 } },
			source = "Recipe: Brilliant Smallfish",
		},
		{
			type = "USE",
			title = "Craft 109x Longjaw Mud Snapper",
			note = "Takes you from 75 to 125.",
			skill = { profession = "Cooking", from = 75, to = 125 },
			craft = { item = "Longjaw Mud Snapper", count = 109 },
			reagents = { { item = "Raw Longjaw Mud Snapper", qty = 1 } },
			source = "Recipe: Longjaw Mud Snapper",
		},
		{
			type = "BUY",
			title = "Buy Expert Cookbook",
			note = "Shandrina (Ashenvale, Silverwind Refuge) sells it for 1 gold. Read it to raise your Cooking cap to 225; it needs skill 125.",
			faction = "Alliance",
			rank = { profession = "Cooking", cap = 225 },
			npcs = { "Shandrina" },
		},
		{
			type = "BUY",
			title = "Buy Expert Cookbook",
			note = "Wulan (Desolace, Shadowprey Village) sells it for 1 gold. Read it to raise your Cooking cap to 225; it needs skill 125.",
			faction = "Horde",
			rank = { profession = "Cooking", cap = 225 },
			npcs = { "Wulan" },
		},
		{
			type = "USE",
			title = "Craft 4x Longjaw Mud Snapper",
			note = "Takes you from 125 to 127.",
			skill = { profession = "Cooking", from = 125, to = 127 },
			craft = { item = "Longjaw Mud Snapper", count = 4 },
			reagents = { { item = "Raw Longjaw Mud Snapper", qty = 1 } },
			source = "Recipe: Longjaw Mud Snapper",
		},
		{
			type = "USE",
			title = "Craft 93x Bristle Whisker Catfish",
			note = "Takes you from 127 to 175.",
			skill = { profession = "Cooking", from = 127, to = 175 },
			craft = { item = "Bristle Whisker Catfish", count = 93 },
			reagents = { { item = "Raw Bristle Whisker Catfish", qty = 1 } },
			source = "Recipe: Bristle Whisker Catfish",
		},
		{
			type = "USE",
			title = "Craft 109x Mithril Head Trout",
			note = "Takes you from 175 to 225.",
			skill = { profession = "Cooking", from = 175, to = 225 },
			craft = { item = "Mithril Head Trout", count = 109 },
			reagents = { { item = "Raw Mithril Head Trout", qty = 1 } },
			source = "Recipe: Mithril Head Trout",
		},
		{
			type = "GRIND",
			title = "Reach level 40",
			note = "The Artisan Cooking quest needs character level 40. This step clears itself when you get there.",
			level = 40,
		},
		{
			type = "NOTE",
			title = "Start the Artisan Cooking quest",
			note = "Daryl Riknussun in Ironforge, near the gryphon platform at the forge, starts it. Needs level 40 and skill 225. You can skip this and go straight to Dirge Quikcleave.",
			faction = "Alliance",
			optional = true,
			npcs = { "Daryl Riknussun" },
		},
		{
			type = "NOTE",
			title = "Start the Artisan Cooking quest",
			note = "Zamja in Orgrimmar, the third house on the right near the Valley of Strength, in the Drag, starts it. Needs level 40 and skill 225. You can skip this and go straight to Dirge Quikcleave.",
			faction = "Horde",
			optional = true,
			npcs = { "Zamja" },
		},
		{
			type = "NOTE",
			title = "Gather for Dirge Quikcleave",
			note = "Giant Eggs drop from level 40+ rocs in Tanaris (plenty near Gadgetzan) or owlbeasts in The Hinterlands. Zesty Clam Meat comes out of Big-mouth Clams, dropped by Muckshells and Threshers in Dustwallow Marsh, Naga Explorers in Stranglethorn Vale and Hatecrests in Feralas. Alterac Swiss is 40 silver per stack of 5 from Ben Trias in Stormwind City (Alliance) or Innkeeper Sikewa in Desolace, Shadowprey Village (Horde).",
			reagents = { { item = "Giant Egg", qty = 12 }, { item = "Zesty Clam Meat", qty = 10 }, { item = "Alterac Swiss", qty = 20 } },
		},
		{
			type = "NOTE",
			title = "Hand in to Dirge Quikcleave",
			note = "Tanaris, Gadgetzan. The big bonfire around the corner behind the inn does for cooking.",
			rank = { profession = "Cooking", cap = 300 },
			npcs = { "Dirge Quikcleave" },
		},
		{
			type = "USE",
			title = "Craft 63x Mithril Head Trout",
			note = "Takes you from 225 to 254.",
			skill = { profession = "Cooking", from = 225, to = 254 },
			craft = { item = "Mithril Head Trout", count = 63 },
			reagents = { { item = "Raw Mithril Head Trout", qty = 1 } },
			source = "Recipe: Mithril Head Trout",
		},
		{
			type = "USE",
			title = "Craft 48x Poached Sunscale Salmon",
			note = "Takes you from 254 to 300.",
			skill = { profession = "Cooking", from = 254, to = 300 },
			craft = { item = "Poached Sunscale Salmon", count = 48 },
			reagents = { { item = "Raw Sunscale Salmon", qty = 1 } },
			source = "Recipe: Poached Sunscale Salmon",
		},
		{
			type = "NOTE",
			title = "Guide Complete",
			note = "Cooking is maxed at 300.",
		},
	},
})
