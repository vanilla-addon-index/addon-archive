-- =========================
-- QS_Desolace_44_44.lua
-- Converted from TourGuide format on 2025-08-17 18:59:06
-- =========================

QuestShellGuides = QuestShellGuides or {}

QuestShellGuides["QS_Desolace_44_44"] = {
  title    = "Desolace (44-44)",
  next     = "Tanaris (44-45)",
  nextKey  = "QS_Tanaris_44_45",
  faction  = "Horde",
  minLevel = 44,
  maxLevel = 44,
  steps = {
    { type="TRAVEL", coords={ x=25.78, y=68.2 }, note="Travel to Shadowprey Village (25.78, 68.20)" },
    { type="ACCEPT", title="Hand of Iruxos", questId=5381, coords={ x=25.79, y=68.28 }, npc = { name="Taiga Wisemane" }, note="Taiga Wisemane in Shadowprey Village (25.79, 68.28)" },
    { type="TRAVEL", coords={ x=54.0, y=29.0 }, note="Travel to Thunder Axe Fortress (54, 29)" },
    { type="COMPLETE", title="Hand of Iruxos", questId=5381, itemId=14523, coords={ x=56.0, y=29.0 }, note="Head into the biggest building in Thunder Axe Fortress. Clear the mainroom, use the Demon Pick on the Crystal in the center of the room. Kill the Demon Spirit that appears and collect the Demon Box (56, 29)" },
    { type="TRAVEL", coords={ x=25.78, y=68.2 }, note="Travel to Shadowprey Village (25.78, 68.20)" },
    { type="TURNIN", title="Hand of Iruxos", questId=5381, coords={ x=25.79, y=68.28 }, npc = { name="Taiga Wisemane" }, note="Taiga Wisemane in Shadowprey Village (25.79, 68.28)" },
    { type="ACCEPT", title="Portals of the Legion", questId=5581, coords={ x=25.78, y=68.2 }, npc = { name="Taiga Wisemane" }, note="Taiga Wisemane in Shadowprey Village (25.78, 68.20)" },
    { type="TRAVEL", coords={ x=36.26, y=79.24 }, note="Travel to Gelkis Village (36.26, 79.24)" },
    { type="TURNIN", title="Ongeku", questId=1373, coords={ x=36.26, y=79.24 }, npc = { name="Uthek" }, note="Uthek the Wise in Gelkis Village (36.26, 79.24)" },
    { type="ACCEPT", title="Khan Jehn", questId=1374, coords={ x=36.26, y=79.24 }, npc = { name="Uthek" }, note="Uthek the Wise in Gelkis Village (36.26, 79.24)" },
    { type="TRAVEL", coords={ x=47.83, y=61.74 }, note="Travel to Kodo Graveyard (47.83, 61.74)" },
    { type="ACCEPT", title="Ghost-o-plasm Round Up", questId=6134, coords={ x=47.83, y=61.74 }, npc = { name="Hornizz Brimbuzzle" }, note="Hornizz Brimbuzzle in Kodo Graveyard (47.83, 61.74)" },
    { type="TRAVEL", coords={ x=52.57, y=54.37 }, note="Travel to Ghost Walker Post (52.57, 54.37)" },
    { type="TURNIN", title="The Corrupter", questId=1484, coords={ x=52.57, y=54.37 }, npc = { name="Maurin Bonesplitter" }, note="Maurin Bonesplitter, in Ghost Walker Post (52.57, 54.37)" },
    { type="ACCEPT", title="The Corrupter", questId=1488, coords={ x=52.57, y=54.37 }, npc = { name="Takata Steelblade" }, note="Takata Steelblade in Ghost Walker Post (52.57, 54.37)" },
    { type="TRAVEL", coords={ x=66.24, y=80.28 }, note="Travel to Magram Village (66.24, 80.28)" },
    { type="COMPLETE", title="Khan Jehn", questId=1374, coords={ x=66.24, y=80.28 }, note="Kill Khan Jehn in Magram Village (66.24, 80.28)" },
    { type="TRAVEL", coords={ x=63.91, y=90.74 }, note="Travel to Valley of Bones (63.91, 90.74)" },
    { type="COMPLETE", title="Ghost-o-plasm Round Up", questId=6134, coords={ x=63.87, y=91.71 }, note="Clear the area, use Crate of Ghost Magnets and kill the Magrami Spectre that appear and collect 8 Ghost-o-plasm (63.87, 91.71)" },
    { type="TRAVEL", coords={ x=55.85, y=77.73 }, note="Travel to Mannoroc Coven (55.85, 77.73)" },
    { type="COMPLETE", title="Lord Azrethoc", questId=1488, coords={ x=57.19, y=79.17 }, note="Kill Lord Azrethoc in Mannoroc Coven, he's an elite but you should be able to solo him (57.19, 79.17) | Kill Jugkar Grim'rod in Mannoroc Coven (55.85, 77.73)" },
    { type="COMPLETE", title="Portals of the Legion", questId=5581, coords={ x=53.85, y=79.21 }, note="Use Hand of Iruxos on the Demon Portal and kill the Demon Portal Guardian that it summon to close 6 Demon portal in Mannoroc Coven (53.85, 79.21)" },
    { type="TRAVEL", coords={ x=52.57, y=54.34 }, note="Travel to Ghost Walker Post (52.57, 54.34)" },
    { type="TURNIN", title="The Corrupter", questId=1488, coords={ x=52.57, y=54.34 }, npc = { name="Takata Steelblade" }, note="Takata Steelblade in Ghost Walker Post (52.57, 54.34)" },
    { type="TRAVEL", coords={ x=47.83, y=61.74 }, note="Travel to Kodo Graveyard (47.83, 61.74)" },
    { type="TURNIN", title="Ghost-o-plasm Round Up", questId=6134, coords={ x=47.83, y=61.74 }, npc = { name="Hornizz Brimbuzzle" }, note="Hornizz Brimbuzzle in Kodo Graveyard (47.83, 61.74)" },
    { type="TRAVEL", coords={ x=36.23, y=79.22 }, note="Travel to Gelkis Village (36.23, 79.22)" },
    { type="TURNIN", title="Khan Jehn", questId=1374, coords={ x=36.23, y=79.22 }, npc = { name="Uthek" }, note="Uthek the Wise in Gelkis Village (36.23, 79.22)" },
    { type="TRAVEL", coords={ x=25.81, y=68.21 }, note="Travel to Shadowprey Village (25.81, 68.21)" },
    { type="TURNIN", title="Portals of the Legion", questId=5581, coords={ x=25.81, y=68.21 }, npc = { name="Taiga Wisemane" }, note="Taiga Wisemane in Shadowprey Village (25.81, 68.21)" },
    { type="NOTE", note="Tick to continue to the next guide" },
  }
}
