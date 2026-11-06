-- =========================
-- QS_Thousand_Needles_31_32.lua
-- Converted from TourGuide format on 2025-08-17 18:59:06
-- =========================

QuestShellGuides = QuestShellGuides or {}

QuestShellGuides["QS_Thousand_Needles_31_32"] = {
  title    = "Thousand Needles (31-32)",
  next     = "Desolace (32-34)",
  nextKey  = "QS_Desolace_32_34",
  faction  = "Horde",
  minLevel = 31,
  maxLevel = 32,
  steps = {
    { type="TRAVEL", coords={ x=51.09, y=29.59 }, note="Travel to The Crossroads (51.09, 29.59)" },
    { type="ACCEPT", title="The Swarm Grows", questId=1145, coords={ x=51.09, y=29.59 }, npc = { name="Korran" }, note="Korran in The Crossroads (51.09, 29.59)" },
    { type="TURNIN", title="Regthar Deathgate", questId=1361, coords={ x=45.34, y=28.43 }, npc = { name="Regthar Deathgate" }, note="Regthar Deathgate in the bunkers west of The Crossroads (45.34, 28.43)" },
    { type="ACCEPT", title="The Kolkar of Desolace", questId=1362, coords={ x=45.34, y=28.43 }, npc = { name="Regthar Deathgate" }, note="Regthar Deathgate in the bunkers west of The Crossroads (45.34, 28.43)" },
    { type="TRAVEL", coords={ x=77.82, y=77.18 }, note="Travel to Mirage Raceway (77.82, 77.18)" },
    { type="ACCEPT", title="A Bump in the Road", questId=1175, coords={ x=81.59, y=77.86 }, npc = { name="Trackmaster Zherin" }, note="Trackmaster Zherin in Mirage Raceway (81.59, 77.86)" },
    { type="ACCEPT", title="Hardened Shells", questId=1105, coords={ x=78.14, y=77.07 }, npc = { name="Wizzle Brassbolts" }, note="Wizzle Brassbolts in Mirage Raceway (78.14, 77.07)" },
    { type="ACCEPT", title="Load Lightening", questId=1176, coords={ x=80.14, y=75.86 }, npc = { name="Pozzik" }, note="Pozzik in Mirage Raceway (80.14, 75.86)" },
    { type="ACCEPT", title="Rocket Car Parts", questId=1110, coords={ x=77.82, y=77.18 }, npc = { name="Kravel Koalbeard" }, note="Kravel Koalbeard in Mirage Raceway (77.82, 77.18)" },
    { type="ACCEPT", title="Salt Flat Venom", questId=1104, coords={ x=78.04, y=77.08 }, npc = { name="Fizzle Brassbolts" }, note="Fizzle Brassbolts in Mirage Raceway (78.04, 77.08)" },
    { type="NOTE", note="Collect 30 Rocket Car Parts through out The Shimmering Flats. You can complete the quests below in any order, click on the green button to switch quest waypoints and targets" },
    { type="COMPLETE", title="Salt Flat Venom", questId=1104, coords={ x=72.0, y=75.0 }, note="Kill Scorpid Reaver and Scorpid Terror in The Shimmering Flats for 6 Salty Scorpid Venom (72, 75)" },
    { type="COMPLETE", title="Hardened Shells", questId=1105, coords={ x=82.0, y=54.0 }, note="Kill Sparkleshell Tortoise, Sparkleshell Snapper and Sparkleshell Borer in The Shimmering Flats for 9 Hardened Tortoise Shell (82, 54)" },
    { type="COMPLETE", title="Load Lightening", questId=1176, coords={ x=87.0, y=66.0 }, note="Kill Salt Flats Scavenger and Salt Flats Vulture for 10 Hollow Vulture Bone in The Shimmering Flats (87, 66)" },
    { type="COMPLETE", title="A Bump in the Road", questId=1175, coords={ x=76.0, y=87.0 }, note="Kill the required Saltstone crocs, Saltstone Gazer are found bottom part of the map and Saltstone Basilisk are found top of the map (76, 87) (86.4, 60.1) (73, 59)" },
    { type="TRAVEL", coords={ x=88.0, y=75.0 }, note="Travel to The Shimmering Flats (88, 75)" },
    { type="COMPLETE", title="Rocket Car Parts", questId=1110, coords={ x=87.0, y=77.0 }, note="Collect 30 Rocket Car Parts through out The Shimmering Flats (87, 77) (86, 60) (77.5, 54) (70, 62) (72, 78) (78, 85)" },
    { type="TURNIN", title="Rocket Car Parts", questId=1110, coords={ x=77.85, y=77.22 }, npc = { name="Kravel Koalbeard" }, note="Kravel Koalbeard in Mirage Raceway (77.85, 77.22)" },
    { type="ACCEPT", title="Wharfmaster Dizzywig", questId=1111, coords={ x=77.85, y=77.22 }, npc = { name="Kravel Koalbeard" }, note="Kravel Koalbeard in Mirage Raceway (77.85, 77.22)" },
    { type="ACCEPT", title="Hemet Nesingwary", questId=5762, coords={ x=77.85, y=77.22 }, npc = { name="Kravel Koalbeard" }, note="Kravel Koalbeard in Mirage Raceway (77.85, 77.22)" },
    { type="TURNIN", title="Salt Flat Venom", questId=1104, coords={ x=78.01, y=77.04 }, npc = { name="Fizzle Brassbolts" }, note="Fizzle Brassbolts in Mirage Raceway (78.01, 77.04)" },
    { type="TURNIN", title="Hardened Shells", questId=1105, coords={ x=78.12, y=77.01 }, npc = { name="Wizzle Brassbolts" }, note="Wizzle Brassbolts in Mirage Raceway (78.12, 77.01)" },
    { type="TURNIN", title="Load Lightening", questId=1176, coords={ x=80.13, y=75.87 }, npc = { name="Pozzik" }, note="Pozzik in Mirage Raceway (80.13, 75.87)" },
    { type="ACCEPT", title="Goblin Sponsorship", questId=1178, coords={ x=80.13, y=75.87 }, npc = { name="Pozzik" }, note="Pozzik in Mirage Raceway (80.13, 75.87)" },
    { type="TURNIN", title="A Bump in the Road", questId=1175, coords={ x=81.59, y=77.93 }, npc = { name="Trackmaster Zherin" }, note="Trackmaster Zherin in Mirage Raceway (81.59, 77.93)" },
    { type="ACCEPT", title="Martek the Exiled", questId=1106, coords={ x=78.04, y=77.08 }, npc = { name="Fizzle Brassbolts" }, note="Fizzle Brassbolts in Mirage Raceway (78.04, 77.08)" },
    { type="ACCEPT", title="Encrusted Tail Fins", questId=1107, coords={ x=78.14, y=77.07 }, npc = { name="Wizzle Brassbolts" }, note="Wizzle Brassbolts in Mirage Raceway (78.14, 77.07)" },
    { type="NOTE", note="Make sure you are at least level 32, otherwise keep grinding in The Shimmering Flats (88, 75)", coords={ x=88.0, y=75.0 } },
    { type="TRAVEL", coords={ x=51.6, y=25.5 }, note="Run South to Gadgetzan (51.6, 25.5)" },
    { type="FLIGHTPATH", npc = { name="Bulkrek Ragefist" }, coords={ x=51.6, y=25.5 }, note="Speak to Bulkrek Ragefist and grab flight path for Bulkrek Ragefist (51.6, 25.5)" },
    { type="NOTE", note="Store Rod of Helcular in the bank . Tick this step (54.2, 28.8)", coords={ x=54.2, y=28.8 } },
    { type="NOTE", note="Store Kravel's Parts Order in the bank . Tick this step (54.2, 28.8)", coords={ x=54.2, y=28.8 } },
    { type="NOTE", note="Store Kravel's Crate in the bank . Tick this step (54.2, 28.8)", coords={ x=54.2, y=28.8 } },
    { type="NOTE", note="Tick to continue to the next guide" },
  }
}
