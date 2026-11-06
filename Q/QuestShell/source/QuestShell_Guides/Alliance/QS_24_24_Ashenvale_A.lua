-- =========================
-- QS_Ashenvale_24_24.lua
-- Converted from TourGuide format on 2025-08-16 22:16:16
-- =========================

QuestShellGuides = QuestShellGuides or {}

QuestShellGuides["QS_Ashenvale_24_24_A"] = {
  title    = "Ashenvale (24-24)",
  next     = "Wetlands (24-27)",
  nextKey  = "QS_Wetlands_24_27_A",
  faction  = "Alliance",
  minLevel = 24,
  maxLevel = 24,
  steps = {
    { type="TRAVEL", coords={ x=34.65, y=48.84 }, note="Travel to Astranaar (34.65, 48.84)" },
    { type="TURNIN", title="Pridewings of Stonetalon", questId=1134, coords={ x=34.65, y=48.84 }, npc = { name="Shindrell Swiftfire" }, note="Shindrell Swiftfire in Astranaar (34.65, 48.84)" },
    { type="TURNIN", title="The Ruins of Stardust", questId=1034, coords={ x=37.33, y=51.8 }, npc = { name="Pelturas Whitemoon" }, note="Pelturas Whitemoon in Astranaar (37.33, 51.80)" },
    { type="ACCEPT", title="Culling the Threat", questId=1054, coords={ x=36.59, y=49.59 }, npc = { name="Raene Wolfrunner" }, note="Raene Wolfrunner in Astranaar (36.59, 49.59)" },
    { type="TRAVEL", coords={ x=36.8, y=56.93 }, note="Travel to Fire Scar Shrine (36.80, 56.93) (33.76, 59.11) (28.54, 60.57)" },
    { type="COMPLETE", title="The Tower of Althalaxx", questId=973, coords={ x=28.54, y=60.57 }, note="Kill Ilkrud Magthrull and collect Ilkrud Magthrull's Tome in Fire Scar Shrine<br/>This is hard to solo but give it a try otherwise you can safely skip this and all 'The Tower of Althalaxx' follow up (28.54, 60.57) (25.95, 63.13) (25.24, 60.63)" },
    { type="TRAVEL", coords={ x=31.25, y=46.18 }, note="Travel to Thistlefur Village (31.25, 46.18) (34.11, 35.38)" },
    { type="COMPLETE", title="Culling the Threat", questId=1054, coords={ x=34.11, y=35.38 }, note="Find and kill Dal Bloodclaw and collect Dal Bloodclaw's Skull. He patrols around this area. If you can pull him solo it will be an easy quest (34.11, 35.38)" },
    { type="TRAVEL", coords={ x=26.2, y=38.66 }, note="Travel to Maestra's Post (26.20, 38.66)" },
    { type="TURNIN", title="The Tower of Althalaxx", questId=973, coords={ x=26.2, y=38.66 }, npc = { name="Delgren" }, note="Delgren the Purifier in Maestra's Post (26.20, 38.66)" },
    { type="ACCEPT", title="The Tower of Althalaxx", questId=1140, coords={ x=26.2, y=38.66 }, npc = { name="Delgren" }, note="Delgren the Purifier in Maestra's Post (26.20, 38.66)" },
    { type="TRAVEL", coords={ x=36.59, y=49.59 }, note="Travel to Astranaar (36.59, 49.59)" },
    { type="TURNIN", title="Culling the Threat", questId=1054, coords={ x=36.59, y=49.59 }, npc = { name="Raene Wolfrunner" }, note="Raene Wolfrunner in Astranaar (36.59, 49.59)" },
    { type="TRAVEL", coords={ x=49.81, y=67.2 }, note="Travel to Silverwind Refuge (49.81, 67.20)" },
    { type="ACCEPT", title="Elemental Bracers", questId=1016, coords={ x=49.81, y=67.2 }, npc = { name="Sentinel Velene Starstrike" }, note="Sentinel Velene Starstrike in Silverwind Refuge (49.81, 67.20)" },
    { type="COMPLETE", title="Elemental Bracers", questId=1016, itemId=5456, coords={ x=49.4, y=71.1 }, note="Kill Befouled Water Elemental until you collect 5 Intact Elemental Bracer in Mystral Lake (49.4, 71.1) | Use the Divining Scroll after collect 5 Intact Elemental Bracer from Befouled Water Elemental in Mystral Lake (49, 70)" },
    { type="TURNIN", title="Elemental Bracers", questId=1016, coords={ x=49.81, y=67.2 }, npc = { name="Sentinel Velene Starstrike" }, note="Sentinel Velene Starstrike in Silverwind Refuge (49.81, 67.20)" },
    { type="NOTE", note="Tick to continue to the next guide" },
  }
}
