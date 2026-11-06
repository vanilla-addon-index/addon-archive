-- =========================
-- QS_Desolace_43_43.lua
-- Converted from TourGuide format on 2025-08-16 22:16:22
-- =========================

QuestShellGuides = QuestShellGuides or {}

QuestShellGuides["QS_Desolace_43_43_A"] = {
  title    = "Desolace (43-43)",
  next     = "Tanaris (43-44)",
  nextKey  = "QS_Tanaris_43_44_A",
  faction  = "Alliance",
  minLevel = 43,
  maxLevel = 43,
  steps = {
    { type="TRAVEL", coords={ x=66.4, y=9.74 }, note="Travel to Nijel's Point (66.40, 9.74)" },
    { type="TURNIN", title="Reagents for Reclaimers Inc.", questId=1459, coords={ x=66.2, y=9.64 }, npc = { name="Kreldig Ungor" }, note="Kreldig Ungor, in Nijel's Point (66.20, 9.64)" },
    { type="ACCEPT", title="Reagents for Reclaimers Inc.", questId=1466, coords={ x=66.4, y=9.74 }, npc = { name="Kreldig Ungor" }, note="Kreldig Ungor in Nijel's Point (66.40, 9.74)" },
    { type="TURNIN", title="Brother Anton", questId=6141, coords={ x=66.51, y=7.89 }, npc = { name="Brother Anton" }, note="Brother Anton in Nijel's Point (66.51, 7.89)" },
    { type="ACCEPT", title="Down the Scarlet Path", questId=261, coords={ x=66.51, y=7.89 }, npc = { name="Brother Anton" }, note="Brother Anton in Nijel's Point (66.51, 7.89)" },
    { type="SET_HEARTH", title="Ghost-o-plasm Round Up", coords={ x=66.3, y=6.6 }, npc = { name="Innkeeper Lyshaerya" }, note="Speak to Innkeeper Lyshaerya and set hearth at Nijel's Point (66.30, 6.60)" },
    { type="TRAVEL", coords={ x=47.86, y=61.79 }, note="Travel to Kodo Graveyard (47.86, 61.79)" },
    { type="ACCEPT", title="Ghost-o-plasm Round Up", questId=6134, coords={ x=47.86, y=61.79 }, npc = { name="Hornizz Brimbuzzle" }, note="Hornizz Brimbuzzle in Kodo Graveyard (47.86, 61.79)" },
    { type="TRAVEL", coords={ x=45.05, y=60.86 }, note="Travel to Gelkis Village (45.05, 60.86) (42.04, 65.96) (36.21, 79.27)" },
    { type="TURNIN", title="Ongeku", questId=1373, coords={ x=36.21, y=79.27 }, npc = { name="Uthek" }, note="Uthek the Wise in Gelkis Village (36.21, 79.27)" },
    { type="ACCEPT", title="Khan Jehn", questId=1374, coords={ x=36.21, y=79.27 }, npc = { name="Uthek" }, note="Uthek the Wise in Gelkis Village (36.21, 79.27)" },
    { type="COMPLETE", title="Reagents for Reclaimers Inc.", questId=1466, coords={ x=56.0, y=75.0 }, note="Make a start with this quest, tick the step if you can't find much and you can complete later. Kill Ley Hunter, Nether Sister and Doomwarder Captain to collect the materials required in Mannoroc Coven (56.0, 75.0) (51.0, 82.0)" },
    { type="TRAVEL", coords={ x=66.43, y=79.93 }, note="Travel to Magram Village (66.43, 79.93)" },
    { type="COMPLETE", title="Khan Jehn", questId=1374, coords={ x=66.43, y=79.93 }, note="Kill Khan Jehn and collect Khan Jehn's Head in Magram Village (66.43, 79.93)" },
    { type="TRAVEL", coords={ x=63.91, y=90.74 }, note="Travel to Valley of Bones (63.91, 90.74)" },
    { type="COMPLETE", title="Ghost-o-plasm Round Up", questId=6134, itemId=15848, coords={ x=63.87, y=91.71 }, note="Clear the area and use Crate of Ghost Magnets, kill the Magrami Spectre that appear and collect 8 Ghost-o-plasm (63.87, 91.71)" },
    { type="COMPLETE", title="Down the Scarlet Path", questId=261, coords={ x=63.91, y=90.74 }, note="Kill 30 Undead Ravager in Valley of Bones (63.91, 90.74)" },
    { type="COMPLETE", title="Reagents for Reclaimers Inc.", questId=1466, coords={ x=56.0, y=75.0 }, note="Kill Ley Hunter, Nether Sister and Doomwarder Captain to collect the materials required in Mannoroc Coven (56.0, 75.0) (51.0, 82.0)" },
    { type="TRAVEL", coords={ x=47.83, y=61.83 }, note="Travel to Kodo Graveyard (47.83, 61.83)" },
    { type="TURNIN", title="Ghost-o-plasm Round Up", questId=6134, coords={ x=47.83, y=61.83 }, npc = { name="Hornizz Brimbuzzle" }, note="Hornizz Brimbuzzle in Kodo Graveyard (47.83, 61.83)" },
    { type="TRAVEL", coords={ x=36.25, y=79.27 }, note="Travel to Gelkis Village (36.25, 79.27)" },
    { type="TURNIN", title="Khan Jehn", questId=1374, coords={ x=36.25, y=79.27 }, npc = { name="Uthek" }, note="Uthek the Wise in Gelkis Village (36.25, 79.27)" },
    { type="TRAVEL", coords={ x=66.2, y=9.64 }, note="Travel or Hearthstone to Nijel's Point (66.20, 9.64)" },
    { type="TURNIN", title="Reagents for Reclaimers Inc.", questId=1466, coords={ x=66.2, y=9.64 }, npc = { name="Kreldig Ungor" }, note="Kreldig Ungor in Nijel's Point (66.20, 9.64)" },
    { type="ACCEPT", title="Reagents for Reclaimers Inc.", questId=1467, coords={ x=66.2, y=9.64 }, npc = { name="Kreldig Ungor" }, note="Kreldig Ungor in Nijel's Point (66.20, 9.64)" },
    { type="TURNIN", title="Down the Scarlet Path", questId=261, coords={ x=66.51, y=7.95 }, npc = { name="Brother Anton" }, note="Brother Anton in Nijel's Point (66.51, 7.95)" },
    { type="ACCEPT", title="Down the Scarlet Path", questId=1052, coords={ x=66.51, y=7.95 }, npc = { name="Brother Anton" }, note="Brother Anton in Nijel's Point (66.51, 7.95)" },
    { type="NOTE", note="Tick to continue to the next guide" },
  }
}
