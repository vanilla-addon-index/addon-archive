-- =========================
-- QS_The_Hinterlands_50_51.lua
-- Converted from TourGuide format on 2025-08-17 18:59:07
-- =========================

QuestShellGuides = QuestShellGuides or {}

QuestShellGuides["QS_The_Hinterlands_50_51"] = {
  title    = "The Hinterlands (50-51)",
  next     = "Blasted Lands (51-51)",
  nextKey  = "QS_Blasted_Lands_51_51",
  faction  = "Horde",
  minLevel = 50,
  maxLevel = 51,
  steps = {
    { type="TRAVEL", coords={ x=80.34, y=81.48 }, note="Travel to Revantusk Village in The Hinterlands (80.34, 81.48)" },
    { type="ACCEPT", title="Snapjaws, Mon!", questId=7815, coords={ x=80.34, y=81.48 }, npc = { name="Katoom" }, note="Katoom the Angler in Revantusk Village (80.34, 81.48)" },
    { type="ACCEPT", title="Gammerita, Mon!", questId=7816, coords={ x=79.85, y=58.48 }, note="in The Overlook Cliffs (79.85, 58.48)" },
    { type="TURNIN", title="Another Message to the Wildhammer", questId=7842, coords={ x=79.34, y=79.09 }, npc = { name="Otho Moji'ko" }, note="Otho Moji'ko in Revantusk Village (79.34, 79.09)" },
    { type="ACCEPT", title="The Final Message to the Wildhammer", questId=7843, coords={ x=79.36, y=79.07 }, npc = { name="Otho Moji'ko" }, note="Otho Moji'ko in Revantusk Village (79.36, 79.07)" },
    { type="ACCEPT", title="Lard Lost His Lunch", questId=7840, coords={ x=78.12, y=81.41 }, npc = { name="Lard" }, note="Lard in Revantusk Village (78.12, 81.41)" },
    { type="COMPLETE", title="Snapjaws, Mon!", questId=7815, coords={ x=77.32, y=68.36 }, note="Kill 15 Saltwater Snapjaw in The Overlook Cliffs (77.32, 68.36)" },
    { type="COMPLETE", title="Whiskey Slim's Lost Grog", questId=580, coords={ x=79.1, y=71.61 }, note="Collect 12 Pupellyverbos Port from the ground near the water around The Overlook Cliffs (79.10, 71.61) (79.14, 64.09) (80.79, 58.88) (82.01, 49.85)" },
    { type="COMPLETE", title="Gammerita, Mon!", questId=7816, coords={ x=80.17, y=58.42 }, note="Kill Gammerita and collect Katoom's Best Lure in The Overlook Cliffs (80.17, 58.42)" },
    { type="TURNIN", title="Cortello's Riddle", questId=626, coords={ x=80.82, y=46.79 }, npc = { name="Cortello's Treasure" }, note="Cortello's Treasure in The Overlook Cliffs (80.82, 46.79)" },
    { type="COMPLETE", title="Lard Lost His Lunch", questId=7840, coords={ x=84.35, y=41.08 }, note="Click on Lard's Picnic Basket in the small island and three level 49 Vilebranch Kidnapper will appear, kill them to collect Lard's Lunch (84.35, 41.08)" },
    { type="TRAVEL", coords={ x=76.36, y=60.93 }, note="Travel to Valorwind Lake (76.36, 60.93) (71.74, 65.36) (40.04, 59.93)" },
    { type="NOTE", note="Collect Violet Tragan from the mushroom underwater in the middle of Valorwind Lake (40.05, 59.89)", coords={ x=40.05, y=59.89 } },
    { type="TRAVEL", coords={ x=14.0, y=48.0 }, note="Travel to Aerie Peak (14, 48)" },
    { type="COMPLETE", title="The Final Message to the Wildhammer", questId=7843, coords={ x=14.0, y=48.0 }, note="Click on the well in Aerie Peak (14, 48)" },
    { type="TURNIN", title="Find OOX-09/HL!", questId=485, coords={ x=49.35, y=37.68 }, npc = { name="HL" }, note="Homing Robot OOX-09/HL in The Hinterlands (49.35, 37.68)" },
    { type="ACCEPT", title="Rescue OOX-09/HL!", questId=836, coords={ x=49.35, y=37.68 }, npc = { name="HL" }, note="Homing Robot OOX-09/HL in The Hinterlands (49.35, 37.68)" },
    { type="COMPLETE", title="Rescue OOX-09/HL!", questId=836, coords={ x=48.27, y=41.23 }, note="Escort Homing Robot OOX-09/HL to the shoreline beyond The Overlook Cliffs. You will be ambushed by 3 level 47 Savage Owlbeast and 3 Trolls, and 1 Wolf on seperate occassions (48.27, 41.23) (48.09, 44.86) (53.37, 44.67) (57.82, 50.14) (61.93, 54.05) (63.18, 56.18) (66.00, 61.13) (72.31, 66.22) (78.99, 61.33)" },
    { type="TRAVEL", coords={ x=79.38, y=79.08 }, note="Travel to Revantusk Village (79.38, 79.08)" },
    { type="TURNIN", title="The Final Message to the Wildhammer", questId=7843, coords={ x=79.38, y=79.08 }, npc = { name="Otho Moji'ko" }, note="Otho Moji'ko in Revantusk Village (79.38, 79.08)" },
    { type="TURNIN", title="Snapjaws, Mon!", questId=7815, coords={ x=80.36, y=81.52 }, npc = { name="Katoom" }, note="Katoom the Angler in Revantusk Village (80.36, 81.52)" },
    { type="TURNIN", title="Gammerita, Mon!", questId=7816, coords={ x=80.36, y=81.52 }, npc = { name="Katoom" }, note="Katoom the Angler in Revantusk Village (80.36, 81.52)" },
    { type="TURNIN", title="Lard Lost His Lunch", questId=7840, coords={ x=78.15, y=81.38 }, npc = { name="Lard" }, note="Lard in Revantusk Village (78.15, 81.38)" },
    { type="TRAVEL", coords={ x=22.56, y=51.41 }, note="Travel to Valormok in Azshara (22.56, 51.41)" },
    { type="TURNIN", title="Magatha's Payment to Jediga", questId=3562, coords={ x=22.56, y=51.41 }, npc = { name="Jediga" }, note="Jediga in Valormok (22.56, 51.41)" },
    { type="TURNIN", title="Jes'rimon's Payment to Jediga", questId=3563, coords={ x=22.56, y=51.41 }, npc = { name="Jediga" }, note="Jediga in Valormok (22.56, 51.41)" },
    { type="TURNIN", title="Andron's Payment to Jediga", questId=3564, coords={ x=22.56, y=51.41 }, npc = { name="Jediga" }, note="Jediga in Valormok (22.56, 51.41)" },
    { type="TRAVEL", coords={ x=62.54, y=38.5 }, note="Travel to Ratchet (62.54, 38.50)" },
    { type="COMPLETE", title="The Stone Circle", questId=3444, coords={ x=62.51, y=38.54 }, note="Collect Stone Circle from Marvon's chest in Ratchet (62.51, 38.54)" },
    { type="ACCEPT", title="Volcanic Activity", questId=4502, coords={ x=62.45, y=38.72 }, npc = { name="Liv Rizzlefix" }, note="Liv Rizzlefix in Ratchet (62.45, 38.72)" },
    { type="NOTE", note="Store Violet Tragan in the bank . Tick this step (62.6, 37.4)", coords={ x=62.6, y=37.4 } },
    { type="NOTE", note="Store Stone Circle in the bank . Tick this step (62.6, 37.4)", coords={ x=62.6, y=37.4 } },
    { type="TRAVEL", coords={ x=28.35, y=76.35 }, note="Travel to Booty Bay (28.35, 76.35)" },
    { type="TURNIN", title="Rescue OOX-09/HL!", questId=836, coords={ x=28.35, y=76.35 }, npc = { name="Gryphon Master Talonaxe" }, note="Gryphon Master Talonaxe in Booty Bay (28.35, 76.35)" },
    { type="TURNIN", title="Rescue OOX-22/FE!", questId=2767, coords={ x=28.35, y=76.35 }, npc = { name="Oglethorpe Obnoticus" }, note="Oglethorpe Obnoticus in Booty Bay (28.35, 76.35)" },
    { type="TURNIN", title="Rescue OOX-17/TN!", questId=648, coords={ x=28.36, y=76.35 }, npc = { name="Oglethorpe Obnoticus" }, note="Oglethorpe Obnoticus in Booty Bay (28.36, 76.35)" },
    { type="TURNIN", title="An OOX of Your Own", questId=3721, coords={ x=28.36, y=76.35 }, npc = { name="Liv Rizzlefix" }, note="Liv Rizzlefix in Booty Bay (28.36, 76.35)" },
    { type="TURNIN", title="Whiskey Slim's Lost Grog", questId=580, coords={ x=27.13, y=77.45 }, npc = { name="Whiskey Slim" }, note="Whiskey Slim in The Salty Sailor Tavern (27.13, 77.45)" },
    { type="NOTE", note="Tick to continue to the next guide" },
  }
}
