-- =========================
-- QS_Blasted_Lands_51_51.lua
-- Converted from TourGuide format on 2025-08-17 18:59:07
-- =========================

QuestShellGuides = QuestShellGuides or {}

QuestShellGuides["QS_Blasted_Lands_51_51"] = {
  title    = "Blasted Lands (51-51)",
  next     = "Un'goro (51-53)",
  nextKey  = "QS_Ungoro_51_53",
  faction  = "Horde",
  minLevel = 51,
  maxLevel = 51,
  steps = {
    { type="TRAVEL", coords={ x=50.65, y=14.27 }, note="Travel to Blasted Lands (50.65, 14.27)" },
    { type="NOTE", note="Kill creatures found all around Blasted Lands and collect the required materials below. The quest items will drop without needing to accept the quests, you can complete in any order" },
    { type="COMPLETE", title="Black Slayer", questId=2603, coords={ x=53.0, y=38.0 }, note="Collect 14 Vulture Gizzard from Black Slayer, East of the road (53, 38) (59, 27)" },
    { type="COMPLETE", title="Redstone Basilisk", questId=2601, coords={ x=60.0, y=40.0 }, note="Collect 11 Basilisk Brain from Redstone Basilisk or Redstone Crystalhide, East of the road (60, 40) (57, 31)" },
    { type="COMPLETE", title="Helboar", questId=2583, coords={ x=52.5, y=54.0 }, note="Collect 6 Blasted Boar Lung from Helboar or Ashmane Boar, East of the road (52.5, 54) (57, 31)" },
    { type="COMPLETE", title="Scorpok Stinger", questId=2585, coords={ x=47.0, y=20.0 }, note="Collect 6 Scorpok Pincer from Scorpok Stinger, West of the road (47, 20)" },
    { type="COMPLETE", title="Snickerfang Hyena", questId=2581, coords={ x=47.0, y=20.0 }, note="Collect 5 Snickerfang Jowl from Snickerfang Hyena or Starving Snickerfang West of the road (47, 20) (50, 38)" },
    { type="ACCEPT", title="The Basilisk's Bite", questId=2601, coords={ x=50.65, y=14.27 }, npc = { name="Bloodmage Lynnore" }, note="Bloodmage Lynnore in Dreadmaul Hold (50.65, 14.27)" },
    { type="ACCEPT", title="Vulture's Vigor", questId=2603, coords={ x=50.59, y=14.23 }, npc = { name="Bloodmage Lynnore" }, note="Bloodmage Lynnore in Dreadmaul Hold (50.59, 14.23)" },
    { type="ACCEPT", title="Snickerfang Jowls", questId=2581, coords={ x=50.55, y=14.21 }, npc = { name="Bloodmage Drazial" }, note="Bloodmage Drazial in Dreadmaul Hold (50.55, 14.21)" },
    { type="ACCEPT", title="A Boar's Vitality", questId=2583, coords={ x=50.55, y=14.21 }, npc = { name="Bloodmage Drazial" }, note="Bloodmage Drazial in Dreadmaul Hold (50.55, 14.21)" },
    { type="ACCEPT", title="The Decisive Striker", questId=2585, coords={ x=50.55, y=14.21 }, npc = { name="Bloodmage Drazial" }, note="Bloodmage Drazial in Dreadmaul Hold (50.55, 14.21)" },
    { type="TURNIN", title="The Basilisk's Bite", questId=2601, coords={ x=50.65, y=14.27 }, npc = { name="Bloodmage Lynnore" }, note="Bloodmage Lynnore in Dreadmaul Hold (50.65, 14.27)" },
    { type="TURNIN", title="Vulture's Vigor", questId=2603, coords={ x=50.59, y=14.23 }, npc = { name="Bloodmage Lynnore" }, note="Bloodmage Lynnore in Dreadmaul Hold (50.59, 14.23)" },
    { type="TURNIN", title="Snickerfang Jowls", questId=2581, coords={ x=50.55, y=14.21 }, npc = { name="Bloodmage Drazial" }, note="Bloodmage Drazial in Dreadmaul Hold (50.55, 14.21)" },
    { type="TURNIN", title="A Boar's Vitality", questId=2583, coords={ x=50.55, y=14.21 }, npc = { name="Bloodmage Drazial" }, note="Bloodmage Drazial in Dreadmaul Hold (50.55, 14.21)" },
    { type="TURNIN", title="The Decisive Striker", questId=2585, coords={ x=50.55, y=14.21 }, npc = { name="Bloodmage Drazial" }, note="Bloodmage Drazial in Dreadmaul Hold (50.55, 14.21)" },
    { type="ACCEPT", title="Everything Counts In Large Amounts", questId=3501, coords={ x=51.99, y=35.65 }, npc = { name="Kum'isha" }, note="Kum'isha the Collector in Rise of the Defiler (51.99, 35.65)" },
    { type="TURNIN", title="Everything Counts In Large Amounts", questId=3501, coords={ x=51.99, y=35.65 }, npc = { name="Kum'isha" }, note="Kum'isha the Collector in Rise of the Defiler (51.99, 35.65)" },
    { type="ACCEPT", title="To Serve Kum'isha", questId=2521, coords={ x=51.99, y=35.65 }, npc = { name="Kum'isha" }, note="Kum'isha the Collector in Rise of the Defiler (51.99, 35.65)" },
    { type="TURNIN", title="To Serve Kum'isha", questId=2521, coords={ x=51.99, y=35.65 }, npc = { name="Kum'isha" }, note="Kum'isha the Collector in Rise of the Defiler (51.99, 35.65)" },
    { type="NOTE", note="Tick to continue to the next guide" },
  }
}
