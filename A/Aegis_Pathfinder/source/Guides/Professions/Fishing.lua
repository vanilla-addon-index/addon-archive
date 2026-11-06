-- Fishing (1-300)
--
-- GENERATED FILE -- do not edit by hand.
-- Source:    Tools/data/gathering.json -- pfQuest's gathering nodes (with
--            pfQuest-turtle) and CMaNGOS classic-db's creatures, fishing
--            skill, trainers, book and quest, extracted by
--            Tools/build/build_gathering.py; zone sides and levels from this
--            addon's own zone guides
-- Generator: Tools/build/convert_professions.py, via Tools/build/gathering_guides.py
--
-- Regenerate with:  python3 Tools/build/convert_professions.py


AegisPathfinder:RegisterQuestShellPlusGuide("Fishing (1-300)", {
	faction = "Both",
	category = "Profession",
	steps = {
		{
			type = "NOTE",
			title = "Fishing (1-300)",
			note = "Where to fish at each skill band. Every catch can raise your skill wherever you fish; these zones are the ones where nothing gets away at your skill.",
		},
		{
			type = "NOTE",
			title = "Buy a Fishing Pole",
			note = "Fishing trainers and fishing suppliers sell one. Equip it and cast from the spell book.",
		},
		{
			type = "GRIND",
			title = "Reach level 5",
			note = "Apprentice Fishing needs character level 5. This step clears itself when you get there.",
			level = 5,
		},
		{
			type = "TRAIN",
			title = "Learn Fishing (Apprentice)",
			note = "Needs level 5; costs 1 silver. Trainers: Arnold Leland (Stormwind City), Grimnur Stonebrand (Ironforge), Androl Oakhand (Teldrassil), Astaia (Teldrassil), Brannock (Feralas), Donald Rabonne (Hillsbrad Foothills), Harold Riggs (Wetlands), Lee Brown (Elwynn Forest), Matthew Hooper (Redridge Mountains), Myizz Luckycatch (Stranglethorn Vale), Paxton Ganter (Dun Morogh), Warg Deepwater (Loch Modan).",
			faction = "Alliance",
			rank = { profession = "Fishing", cap = 75 },
			npcs = { "Arnold Leland", "Grimnur Stonebrand", "Androl Oakhand", "Astaia", "Brannock", "Donald Rabonne", "Harold Riggs", "Lee Brown", "Matthew Hooper", "Myizz Luckycatch", "Paxton Ganter", "Warg Deepwater" },
		},
		{
			type = "TRAIN",
			title = "Learn Fishing (Apprentice)",
			note = "Needs level 5; costs 1 silver. Trainers: Armand Cromwell (Undercity), Lumak (Orgrimmar), Clyde Kellen (Tirisfal Glades), Kah Mistrunner (Mulgore), Katoom the Angler (The Hinterlands), Kil'Hiwana (Ashenvale), Lau'Tiki (Durotar), Lui'Mala (Desolace), Myizz Luckycatch (Stranglethorn Vale), Uthan Stillwater (Mulgore).",
			faction = "Horde",
			rank = { profession = "Fishing", cap = 75 },
			npcs = { "Armand Cromwell", "Lumak", "Clyde Kellen", "Kah Mistrunner", "Katoom the Angler", "Kil'Hiwana", "Lau'Tiki", "Lui'Mala", "Myizz Luckycatch", "Uthan Stillwater" },
		},
		{
			type = "GRIND",
			title = "Fish to 75",
			note = "Takes you from 1 to 75. Fish anywhere with water in Dun Morogh (1-12), Elwynn Forest (1-12) and Teldrassil (1-12): nothing gets away there at your skill. Every catch can raise it, wherever you fish.",
			faction = "Alliance",
			skill = { profession = "Fishing", from = 1, to = 75 },
		},
		{
			type = "GRIND",
			title = "Fish to 75",
			note = "Takes you from 1 to 75. Fish anywhere with water in Durotar (1-12), Mulgore (1-12) and Tirisfal Glades (1-12): nothing gets away there at your skill. Every catch can raise it, wherever you fish.",
			faction = "Horde",
			skill = { profession = "Fishing", from = 1, to = 75 },
		},
		{
			type = "TRAIN",
			title = "Train Journeyman Fishing (Cap 150)",
			note = "Needs skill 50; costs 5 silver. Trainers: Arnold Leland (Stormwind City), Grimnur Stonebrand (Ironforge), Androl Oakhand (Teldrassil), Astaia (Teldrassil), Brannock (Feralas), Donald Rabonne (Hillsbrad Foothills), Harold Riggs (Wetlands), Lee Brown (Elwynn Forest), Matthew Hooper (Redridge Mountains), Myizz Luckycatch (Stranglethorn Vale), Paxton Ganter (Dun Morogh), Warg Deepwater (Loch Modan).",
			faction = "Alliance",
			rank = { profession = "Fishing", cap = 150 },
			npcs = { "Arnold Leland", "Grimnur Stonebrand", "Androl Oakhand", "Astaia", "Brannock", "Donald Rabonne", "Harold Riggs", "Lee Brown", "Matthew Hooper", "Myizz Luckycatch", "Paxton Ganter", "Warg Deepwater" },
		},
		{
			type = "TRAIN",
			title = "Train Journeyman Fishing (Cap 150)",
			note = "Needs skill 50; costs 5 silver. Trainers: Armand Cromwell (Undercity), Lumak (Orgrimmar), Clyde Kellen (Tirisfal Glades), Kah Mistrunner (Mulgore), Katoom the Angler (The Hinterlands), Kil'Hiwana (Ashenvale), Lau'Tiki (Durotar), Lui'Mala (Desolace), Myizz Luckycatch (Stranglethorn Vale), Uthan Stillwater (Mulgore).",
			faction = "Horde",
			rank = { profession = "Fishing", cap = 150 },
			npcs = { "Armand Cromwell", "Lumak", "Clyde Kellen", "Kah Mistrunner", "Katoom the Angler", "Kil'Hiwana", "Lau'Tiki", "Lui'Mala", "Myizz Luckycatch", "Uthan Stillwater" },
		},
		{
			type = "GRIND",
			title = "Fish to 150",
			note = "Takes you from 75 to 150. Fish anywhere with water in Darkshore (12-24), Westfall (12-17), Loch Modan (17-18), Darnassus and Ironforge: nothing gets away there at your skill. Every catch can raise it, wherever you fish.",
			faction = "Alliance",
			skill = { profession = "Fishing", from = 75, to = 150 },
		},
		{
			type = "GRIND",
			title = "Fish to 150",
			note = "Takes you from 75 to 150. Fish anywhere with water in Silverpine Forest (12-20), The Barrens (12-25), Orgrimmar, Thunder Bluff and Undercity: nothing gets away there at your skill. Every catch can raise it, wherever you fish.",
			faction = "Horde",
			skill = { profession = "Fishing", from = 75, to = 150 },
		},
		{
			type = "BUY",
			title = "Buy Expert Fishing - The Bass and You",
			note = "Old Man Heming (Stranglethorn Vale) sells it for 1 gold. Read it to raise your Fishing cap to 225; it needs skill 125.",
			faction = "Alliance",
			rank = { profession = "Fishing", cap = 225 },
			npcs = { "Old Man Heming" },
		},
		{
			type = "BUY",
			title = "Buy Expert Fishing - The Bass and You",
			note = "Old Man Heming (Stranglethorn Vale) sells it for 1 gold. Read it to raise your Fishing cap to 225; it needs skill 125.",
			faction = "Horde",
			rank = { profession = "Fishing", cap = 225 },
			npcs = { "Old Man Heming" },
		},
		{
			type = "GRIND",
			title = "Fish to 225",
			note = "Takes you from 150 to 225. Fish anywhere with water in Redridge Mountains (18-28), Ashenvale (21-30), Stonetalon Mountains (22-23), Wetlands (24-31) and Duskwood (28-29): nothing gets away there at your skill. Every catch can raise it, wherever you fish.",
			faction = "Alliance",
			skill = { profession = "Fishing", from = 150, to = 225 },
		},
		{
			type = "GRIND",
			title = "Fish to 225",
			note = "Takes you from 150 to 225. Fish anywhere with water in Stonetalon Mountains (20-27), Ashenvale (26-27) and Hillsbrad Foothills (29-30): nothing gets away there at your skill. Every catch can raise it, wherever you fish.",
			faction = "Horde",
			skill = { profession = "Fishing", from = 150, to = 225 },
		},
		{
			type = "GRIND",
			title = "Reach level 35",
			note = "Artisan Fishing needs character level 35. This step clears itself when you get there.",
			level = 35,
		},
		{
			type = "TRAIN",
			title = "Train Artisan Fishing (Cap 300)",
			note = "Needs skill 200 and level 35; costs 1 gold. Trainer: Katoom the Angler (The Hinterlands). Or do Nat Pagle's quest, as the Alliance does.",
			faction = "Horde",
			rank = { profession = "Fishing", cap = 300 },
			npcs = { "Katoom the Angler" },
		},
		{
			type = "NOTE",
			title = "Start Nat Pagle, Angler Extreme",
			note = "Nat Pagle in Dustwallow Marsh starts it. Needs level 35 and Fishing 225.",
			faction = "Alliance",
			npcs = { "Nat Pagle" },
		},
		{
			type = "NOTE",
			title = "Catch the four fish",
			note = "One each: Feralas Ahi at Verdantis River (Feralas); Misty Reed Mahi Mahi at Misty Reed Strand (Swamp of Sorrows); Sar'theris Striker at Sar'theris Strand (Desolace); Savage Coast Blue Sailfin at Southern Savage Coast and The Savage Coast (Stranglethorn Vale).",
			faction = "Alliance",
			reagents = { { item = "Feralas Ahi", qty = 1 }, { item = "Misty Reed Mahi Mahi", qty = 1 }, { item = "Sar'theris Striker", qty = 1 }, { item = "Savage Coast Blue Sailfin", qty = 1 } },
		},
		{
			type = "NOTE",
			title = "Hand in to Nat Pagle",
			note = "Nat Pagle, Dustwallow Marsh. Handing in raises your Fishing cap to 300.",
			rank = { profession = "Fishing", cap = 300 },
			npcs = { "Nat Pagle" },
		},
		{
			type = "GRIND",
			title = "Fish to 300",
			note = "Takes you from 225 to 300. Fish anywhere with water in Stranglethorn Vale (32-47), Thousand Needles (33-34), Desolace (34-43), Alterac Mountains (36-37) and Arathi Highlands (37-38): nothing gets away there at your skill. Every catch can raise it, wherever you fish.",
			faction = "Alliance",
			skill = { profession = "Fishing", from = 225, to = 300 },
		},
		{
			type = "GRIND",
			title = "Fish to 300",
			note = "Takes you from 225 to 300. Fish anywhere with water in Thousand Needles (25-38), Arathi Highlands (30-38), Stranglethorn Vale (30-47), Desolace (32-44) and Alterac Mountains (36-37): nothing gets away there at your skill. Every catch can raise it, wherever you fish.",
			faction = "Horde",
			skill = { profession = "Fishing", from = 225, to = 300 },
		},
		{
			type = "NOTE",
			title = "Guide Complete",
			note = "Fishing is maxed at 300.",
		},
	},
})
