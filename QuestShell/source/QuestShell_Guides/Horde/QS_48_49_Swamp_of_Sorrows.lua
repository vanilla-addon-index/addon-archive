-- =========================
-- QS_Swamp_of_Sorrows_48_49.lua
-- Converted from TourGuide format on 2025-08-17 18:59:07
-- =========================

QuestShellGuides = QuestShellGuides or {}

QuestShellGuides["QS_Swamp_of_Sorrows_48_49"] = {
  title    = "Swamp of Sorrows (48-49)",
  next     = "Dustwallow Marsh (49-49)",
  nextKey  = "QS_Dustwallow_Marsh_49_49",
  faction  = "Horde",
  minLevel = 48,
  maxLevel = 49,
  steps = {
    { type="TRAVEL", coords={ x=45.13, y=56.64 }, note="Travel to Stonard (45.13, 56.64)" },
    { type="SET_HEARTH", title="Stonard", coords={ x=45.13, y=56.64 }, npc = { name="Innkeeper Karakul" }, note="Speak to Innkeeper Karakul and set hearth to Stonard (45.13, 56.64)" },
    { type="ACCEPT", title="Fall From Grace", questId=2784, coords={ x=36.66, y=60.01 }, npc = { name="Fallen Hero" }, note="Fallen Hero of the Horde in Stonard (36.66, 60.01) (34.2, 66.0)" },
    { type="COMPLETE", title="Fall From Grace", questId=2784, coords={ x=34.32, y=66.09 }, note="Speak to Fallen Hero of the Horde to complete the quest (34.32, 66.09)" },
    { type="TURNIN", title="Fall From Grace", questId=2784, coords={ x=34.2, y=66.0 }, npc = { name="Fallen Hero" }, note="Fallen Hero of the Horde in Stonard (34.2, 66.0)" },
    { type="ACCEPT", title="The Disgraced One", questId=2621, coords={ x=34.2, y=66.0 }, note="Fallen Hero of the Horde (34.2, 66.0)" },
    { type="TURNIN", title="Cortello's Riddle", questId=624, coords={ x=22.9, y=48.2 }, note="A Soggy Scroll - under the bridge (22.9, 48.2)" },
    { type="ACCEPT", title="Cortello's Riddle", questId=625, coords={ x=22.9, y=48.2 }, note="A Soggy Scroll (22.9, 48.2)" },
    { type="TRAVEL", coords={ x=47.85, y=54.97 }, note="Travel to Stonard (47.85, 54.97)" },
    { type="TURNIN", title="The Disgraced One", questId=2621, coords={ x=47.85, y=54.97 }, npc = { name="Dispatch Commander Ruag" }, note="Dispatch Commander Ruag in Stonard (47.85, 54.97)" },
    { type="ACCEPT", title="The Missing Orders", questId=2622, coords={ x=47.85, y=54.97 }, npc = { name="Dispatch Commander Ruag" }, note="Dispatch Commander Ruag in Stonard (47.85, 54.97)" },
    { type="TURNIN", title="The Missing Orders", questId=2622, coords={ x=44.96, y=57.31 }, npc = { name="Bengor" }, note="Bengor in Stonard (44.96, 57.31)" },
    { type="ACCEPT", title="The Swamp Talker", questId=2623, coords={ x=44.96, y=57.31 }, npc = { name="Bengor" }, note="Bengor in Stonard (44.96, 57.31)" },
    { type="TRAVEL", coords={ x=83.75, y=80.44 }, note="Travel to Misty Reed Strand (83.75, 80.44)" },
    { type="ACCEPT", title="Continued Threat", questId=1428, coords={ x=83.75, y=80.44 }, npc = { name="Katar" }, note="Katar in Misty Reed Strand (83.75, 80.44)" },
    { type="TRAVEL", coords={ x=66.52, y=76.36 }, note="Travel to Stagalbog Cave (66.52, 76.36)" },
    { type="COMPLETE", title="The Swamp Talker", questId=2623, coords={ x=66.0, y=75.0 }, note="Kill Swamp Talker at the back of the Murloc cave and loot the Warchief's Orders (66, 75)" },
    { type="COMPLETE", title="Continued Threat", questId=1428, coords={ x=66.52, y=76.36 }, note="Kill the required Marsh murlocs in Stagalbog Cave (66.52, 76.36)" },
    { type="COMPLETE", title="Jarquia", questId=4450, coords={ x=94.81, y=52.06 }, note="Kill Jarquia and collect Goodsteel's Balanced Flameberge in Misty Reed Strand (94.81, 52.06)" },
    { type="TURNIN", title="The Swamp Talker", questId=2623, coords={ x=36.66, y=60.01 }, npc = { name="Fallen Hero" }, note="Fallen Hero of the Horde in Swamp of Sorrows (36.66, 60.01) (34.2, 66.0)" },
    { type="ACCEPT", title="A Tale of Sorrow", questId=2801, coords={ x=34.24, y=66.11 }, npc = { name="Thadius Grimshade" }, note="Thadius Grimshade in Swamp of Sorrows (34.24, 66.11)" },
    { type="COMPLETE", title="A Tale of Sorrow", questId=2801, coords={ x=34.24, y=66.11 }, note="Speak to Thadius Grimshade until the quest is complete (34.24, 66.11)" },
    { type="TURNIN", title="A Tale of Sorrow", questId=2801, coords={ x=34.24, y=66.11 }, npc = { name="Thadius Grimshade" }, note="Thadius Grimshade in Swamp of Sorrows (34.24, 66.11)" },
    { type="TRAVEL", coords={ x=27.13, y=77.44 }, note="Travel to The Salty Sailor Tavern in Booty Bay (27.13, 77.44)" },
    { type="ACCEPT", title="Whiskey Slim's Lost Grog", questId=580, coords={ x=27.13, y=77.44 }, npc = { name="Whiskey Slim" }, note="Whiskey Slim in The Salty Sailor Tavern (27.13, 77.44)" },
    { type="NOTE", note="Store Goodsteel Ledger in the bank. Tick this step (26.6, 76.4)", coords={ x=26.6, y=76.4 } },
    { type="NOTE", note="Store Solid Crystal Leg Shaft in the bank. Tick this step (26.6, 76.4)", coords={ x=26.6, y=76.4 } },
    { type="NOTE", note="Store Goodsteel's Balanced Flameberge in the bank. Tick this step (26.6, 76.4)", coords={ x=26.6, y=76.4 } },
    { type="NOTE", note="Store Torch of Retribution in the bank. Tick this step (26.6, 76.4)", coords={ x=26.6, y=76.4 } },
    { type="NOTE", note="Store Black Dragonflight Molt in the bank. Tick this step (26.6, 76.4)", coords={ x=26.6, y=76.4 } },
    { type="NOTE", note="Store Dark Iron Scraps in the bank. Tick this step (26.6, 76.4)", coords={ x=26.6, y=76.4 } },
    { type="NOTE", note="Store Core of Elements in the bank. Tick this step (26.6, 76.4)", coords={ x=26.6, y=76.4 } },
    { type="NOTE", note="Withdraw Wildkin Muisek from the bank. Tick this step (26.6, 76.4)", coords={ x=26.6, y=76.4 } },
    { type="NOTE", note="Withdraw Wildkin Muisek Vessel from the bank. Tick this step (26.6, 76.4)", coords={ x=26.6, y=76.4 } },
    { type="NOTE", note="Withdraw Long Elegant Feather from the bank. Tick this step (26.6, 76.4)", coords={ x=26.6, y=76.4 } },
    { type="NOTE", note="Tick to continue to the next guide" },
  }
}
