-- =========================
-- QS_Stonetalon_Mountains_23_25.lua
-- Converted from TourGuide format on 2025-08-17 18:59:05
-- =========================

QuestShellGuides = QuestShellGuides or {}

QuestShellGuides["QS_Stonetalon_Mountains_23_25"] = {
  title    = "Stonetalon Mountains (23-25)",
  next     = "The Barrens (25-25)",
  nextKey  = "QS_The_Barrens_25_25",
  faction  = "Horde",
  minLevel = 23,
  maxLevel = 25,
  steps = {
    { type="TRAVEL", coords={ x=82.98, y=98.58 }, note="Travel to Malaka'jin (82.98, 98.58) (78.28, 98.43) (74.55, 97.84)" },
    { type="TURNIN", title="Letter to Jin'Zil", questId=1060, coords={ x=74.55, y=97.84 }, npc = { name="Witch Doctor Jin'Zil" }, note="Witch Doctor Jin'Zil in Malaka'jin (74.55, 97.84)" },
    { type="ACCEPT", title="Jin'Zil's Forest Magic", questId=1058, coords={ x=74.55, y=97.84 }, npc = { name="Witch Doctor Jin'Zil" }, note="Witch Doctor Jin'Zil in Malaka'jin (74.55, 97.84)" },
    { type="TRAVEL", coords={ x=45.96, y=60.36 }, note="Travel to Sun Rock Retreat (45.96, 60.36)" },
    { type="ACCEPT", title="Cenarius' Legacy", questId=1087, coords={ x=45.96, y=60.36 }, npc = { name="Braelyn Firehand" }, note="Braelyn Firehand in Sun Rock Retreat (45.96, 60.36)" },
    { type="ACCEPT", title="Harpies Threaten", questId=6282, coords={ x=47.26, y=61.11 }, npc = { name="Maggran Earthbinder" }, note="Maggran Earthbinder in Sun Rock Retreat (47.26, 61.11)" },
    { type="TURNIN", title="Boulderslide Ravine", questId=6421, coords={ x=49.0, y=61.7 }, npc = { name="Mor'rogal" }, note="Mor'rogal in Sun Rock Retreat (49.0, 61.7) (47.12, 64.14)" },
    { type="ACCEPT", title="Elemental War", questId=6393, coords={ x=47.27, y=64.27 }, npc = { name="Tsunaman" }, note="Tsunaman in Sun Rock Retreat (47.27, 64.27)" },
    { type="SET_HEARTH", title="Sun Rock Retreat", coords={ x=47.5, y=62.1 }, npc = { name="Innkeeper Jayka" }, note="Speak to Innkeeper Jayka and set hearth for Sun Rock Retreat (47.5, 62.1)" },
    { type="TURNIN", title="Kaya's Alive", questId=6401, coords={ x=47.45, y=58.46 }, npc = { name="Tammra Windfield" }, note="Tammra Windfield in Sun Rock Retreat (47.45, 58.46)" },
    { type="ACCEPT", title="Cycle of Rebirth", questId=6301, coords={ x=47.45, y=58.46 }, npc = { name="Tammra Windfield" }, note="Tammra Windfield in Sun Rock Retreat (47.45, 58.46)" },
    { type="TRAVEL", coords={ x=48.0, y=41.0 }, note="Travel to Mirkfallon Lake (48, 41)" },
    { type="COMPLETE", title="Cycle of Rebirth", questId=6301, coords={ x=48.0, y=41.0 }, note="Pick up the Gaea Seed around Mirkfallon Lake (48, 41)" },
    { type="TRAVEL", coords={ x=32.0, y=10.0 }, note="Travel to Stonetalon Peak (32, 10)" },
    { type="COMPLETE", title="Jin'Zil's Forest Magic", questId=1058, coords={ x=32.0, y=10.0 }, note="These mobs can be found in Stonetalon Peak. Kill Sap Beast for the 5 Stonetalon Sap, Twilight Runner for the 5 Twilight Whisker, Antlered Courser for the 30 Courser Eye and Fey Dragon for the Fey Dragon Scale (32, 10)" },
    { type="COMPLETE", title="Cenarius' Legacy", questId=1087, coords={ x=37.0, y=15.0 }, note="Kill 4 Son of Cenarius, 4 Daughter of Cenarius and 4 Cenarion Botanist in the center of Stonetalon Peak (37, 15)" },
    { type="TURNIN", title="Cycle of Rebirth", questId=6301, coords={ x=47.45, y=58.46 }, npc = { name="Tammra Windfield" }, note="Tammra Windfield in Sun Rock Retreat (47.45, 58.46)" },
    { type="ACCEPT", title="New Life", questId=6381, coords={ x=47.45, y=58.46 }, npc = { name="Tammra Windfield" }, note="Tammra Windfield in Sun Rock Retreat (47.45, 58.46)" },
    { type="TURNIN", title="Cenarius' Legacy", questId=1087, coords={ x=45.96, y=60.36 }, npc = { name="Braelyn Firehand" }, note="Braelyn Firehand in Sun Rock Retreat (45.96, 60.36)" },
    { type="ACCEPT", title="Ordanus", questId=1088, coords={ x=45.96, y=60.36 }, npc = { name="Braelyn Firehand" }, note="Braelyn Firehand in Sun Rock Retreat (45.96, 60.36)" },
    { type="TURNIN", title="Further Instructions", questId=1095, coords={ x=58.99, y=62.52 }, npc = { name="Ziz Fizziks" }, note="Ziz Fizziks in Windshear Crag (58.99, 62.52)" },
    { type="ACCEPT", title="Gerenzo Wrenchwhistle", questId=1096, coords={ x=58.99, y=62.52 }, npc = { name="Ziz Fizziks" }, note="Ziz Fizziks in Windshear Crag (58.99, 62.52)" },
    { type="COMPLETE", title="Gerenzo Wrenchwhistle", questId=1096, coords={ x=69.0, y=40.1 }, note="Kill Gerenzo Wrenchwhistle at the Cragpool Lake in the Water Wheel and take Gerenzo's Mechanical Arm (69.0, 40.1) (67.9, 37.7) (64, 39)" },
    { type="COMPLETE", title="Shredding Machines", questId=1068, coords={ x=67.0, y=50.0 }, note="Kill the shredders XT:4 and XT:9 that roam around in the Windshear Crag (67, 50)" },
    { type="TURNIN", title="Gerenzo Wrenchwhistle", questId=1096, coords={ x=58.99, y=62.52 }, npc = { name="Ziz Fizziks" }, note="Ziz Fizziks in Windshear Crag (58.99, 62.52)" },
    { type="TURNIN", title="Jin'Zil's Forest Magic", questId=1058, coords={ x=74.55, y=97.84 }, npc = { name="Witch Doctor Jin'Zil" }, note="Witch Doctor Jin'Zil in Malaka'jin (74.55, 97.84)" },
    { type="TURNIN", title="Shredding Machines", questId=1068, coords={ x=35.29, y=27.87 }, npc = { name="Seereth Stonebreak" }, note="Seereth Stonebreak in The Barrens (35.29, 27.87)" },
    { type="TRAVEL", coords={ x=44.5, y=63.4 }, note="Travel to The Charred Vale (44.5, 63.4) (32, 67)" },
    { type="COMPLETE", title="New Life", questId=6381, coords={ x=32.0, y=67.0 }, note="Plant 10 Enchanted Gaea Seeds in Gaea Dirt Mounds west in The Charred Vale (32, 67)" },
    { type="COMPLETE", title="Elemental War", questId=6393, coords={ x=32.0, y=67.0 }, note="Kill Rogue Flame Spirit, Burning Ravager or Burning Destroyer in The Charred Vale for 10 Incendrites (32, 67)" },
    { type="COMPLETE", title="Harpies Threaten", questId=6282, coords={ x=32.3, y=63.0 }, note="Kill the required Bloodfury Harpies in the The Charred Vale (32.3, 63.0)" },
    { type="TRAVEL", coords={ x=47.26, y=61.11 }, note="Travel to Sun Rock Retreat (47.26, 61.11)" },
    { type="TURNIN", title="Harpies Threaten", questId=6282, coords={ x=47.26, y=61.11 }, npc = { name="Maggran Earthbinder" }, note="Maggran Earthbinder in Sun Rock Retreat (47.26, 61.11)" },
    { type="TURNIN", title="New Life", questId=6381, coords={ x=47.45, y=58.46 }, npc = { name="Tammra Windfield" }, note="Tammra Windfield in Sun Rock Retreat (47.45, 58.46)" },
    { type="TURNIN", title="Elemental War", questId=6393, coords={ x=47.27, y=64.27 }, npc = { name="Tsunaman" }, note="Tsunaman in Sun Rock Retreat (47.27, 64.27)" },
    { type="ACCEPT", title="Calling in the Reserves", questId=5881, coords={ x=47.26, y=61.11 }, npc = { name="Maggran Earthbinder" }, note="Maggran Earthbinder in Sun Rock Retreat (47.26, 61.11)" },
    { type="NOTE", note="Tick to continue to the next guide" },
  }
}
