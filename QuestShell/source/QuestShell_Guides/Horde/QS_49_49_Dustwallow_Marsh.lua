-- =========================
-- QS_Dustwallow_Marsh_49_49.lua
-- Converted from TourGuide format on 2025-08-17 18:59:07
-- =========================

QuestShellGuides = QuestShellGuides or {}

QuestShellGuides["QS_Dustwallow_Marsh_49_49"] = {
  title    = "Dustwallow Marsh (49-49)",
  next     = "Feralas (49-50)",
  nextKey  = "QS_Feralas_49_50",
  faction  = "Horde",
  minLevel = 49,
  maxLevel = 49,
  steps = {
    { type="TRAVEL", coords={ x=36.33, y=31.48 }, note="Travel to Brackenwall Village (36.33, 31.48)" },
    { type="ACCEPT", title="The Brood of Onyxia", questId=1171, coords={ x=36.33, y=31.48 }, npc = { name="Overlord Mok'Morokk" }, note="Overlord Mok'Morokk in Brackenwall Village (36.33, 31.48)" },
    { type="TURNIN", title="The Brood of Onyxia", questId=1171, coords={ x=37.04, y=32.93 }, npc = { name="Draz'Zilb" }, note="Draz'Zilb in Brackenwall Village (37.04, 32.93)" },
    { type="ACCEPT", title="The Brood of Onyxia", questId=1172, coords={ x=37.04, y=32.93 }, npc = { name="Draz'Zilb" }, note="Draz'Zilb in Brackenwall Village (37.04, 32.93)" },
    { type="TRAVEL", coords={ x=54.11, y=55.9 }, note="Travel to Beezil's Wreck (54.11, 55.90)" },
    { type="COMPLETE", title="Ledger from Tanaris", questId=4450, coords={ x=54.11, y=55.9 }, note="Collect Overdue Package from the Damaged Crate in Beezil's Wreck (54.11, 55.90)" },
    { type="TRAVEL", coords={ x=48.43, y=75.91 }, note="Travel to Wyrmbog (48.43, 75.91)" },
    { type="COMPLETE", title="The Brood of Onyxia", questId=1172, coords={ x=48.43, y=75.91 }, note="Destroy 5 Egg of Onyxia in Wyrmbog (48.43, 75.91)" },
    { type="TRAVEL", coords={ x=31.87, y=65.64 }, note="Travel to Bloodfen Burrow (31.87, 65.64)" },
    { type="TURNIN", title="Cortello's Riddle", questId=625, coords={ x=31.87, y=65.64 }, npc = { name="Musty Scroll" }, note="Musty Scroll in Bloodfen Burrow (31.87, 65.64) (31.11, 66.12)" },
    { type="ACCEPT", title="Cortello's Riddle", questId=626, coords={ x=31.11, y=66.12 }, note="in Bloodfen Burrow (31.11, 66.12)" },
    { type="TURNIN", title="The Brood of Onyxia", questId=1172, coords={ x=37.14, y=33.06 }, npc = { name="Draz'Zilb" }, note="Draz'Zilb in Brackenwall Village (37.14, 33.06)" },
    { type="ACCEPT", title="Challenge Overlord Mok'Morokk", questId=1173, coords={ x=36.31, y=31.41 }, npc = { name="Overlord Mok'Morokk" }, note="Overlord Mok'Morokk in Brackenwall Village (36.31, 31.41)" },
    { type="COMPLETE", title="Challenge Overlord Mok'Morokk", questId=1173, coords={ x=36.42, y=31.28 }, note="Defeat Overlord Mok'Morokk in Brackenwall Village, he will run away at about 1/3 HP left (36.42, 31.28)" },
    { type="TURNIN", title="Challenge Overlord Mok'Morokk", questId=1173, coords={ x=37.14, y=33.07 }, npc = { name="Draz'Zilb" }, note="Draz'Zilb in Brackenwall Village (37.14, 33.07)" },
    { type="NOTE", note="Tick to continue to the next guide" },
  }
}
