-- =========================
-- QS_Azshara_46_47.lua
-- Converted from TourGuide format on 2025-08-17 18:59:07
-- =========================

QuestShellGuides = QuestShellGuides or {}

QuestShellGuides["QS_Azshara_46_47"] = {
  title    = "Azshara (46-47)",
  next     = "The Hinterlands (47-47)",
  nextKey  = "QS_The_Hinterlands_47_47",
  faction  = "Horde",
  minLevel = 46,
  maxLevel = 47,
  steps = {
    { type="TRAVEL", coords={ x=11.37, y=78.14 }, note="Travel to Talrendis Point in Azshara (11.37, 78.14)" },
    { type="ACCEPT", title="Spiritual Unrest", questId=5535, coords={ x=11.37, y=78.14 }, npc = { name="Loh'atu" }, note="Loh'atu in Talrendis Point (11.37, 78.14)" },
    { type="ACCEPT", title="A Land Filled with Hatred", questId=5536, coords={ x=11.37, y=78.14 }, npc = { name="Loh'atu" }, note="Loh'atu in Talrendis Point (11.37, 78.14)" },
    { type="COMPLETE", title="Spiritual Unrest", questId=5535, coords={ x=17.0, y=66.0 }, note="Kill 6 Highborne Apparition and 6 Highborne Lichling at the Shadowsong Shrine (17, 66)" },
    { type="COMPLETE", title="A Land Filled with Hatred", questId=5536, coords={ x=20.0, y=65.0 }, note="Kill 6 Haldarr Satyr, 2 Haldarr Trickster and 2 Haldarr Felsworn found a bit more north in Haldarr Encampment (20, 65)" },
    { type="TRAVEL", coords={ x=11.37, y=78.14 }, note="Travel to Talrendis Point (11.37, 78.14)" },
    { type="TURNIN", title="Spiritual Unrest", questId=5535, coords={ x=11.37, y=78.14 }, npc = { name="Loh'atu" }, note="Loh'atu in Talrendis Point (11.37, 78.14)" },
    { type="TURNIN", title="A Land Filled with Hatred", questId=5536, coords={ x=11.37, y=78.14 }, npc = { name="Loh'atu" }, note="Loh'atu in Talrendis Point (11.37, 78.14)" },
    { type="TRAVEL", coords={ x=21.0, y=52.0 }, note="North of the road, on the mountain's edge (21,52)" },
    { type="TURNIN", title="Betrayed", questId=3504, coords={ x=22.28, y=51.48 }, npc = { name="Ag'tor Bloodfist" }, note="Ag'tor Bloodfist in Valormok (22.28, 51.48)" },
    { type="FLIGHTPATH", npc = { name="Kroum" }, coords={ x=21.97, y=49.65 }, note="Speak to Kroum grab flight path for Valormok (21.97, 49.65)" },
    { type="ACCEPT", title="Stealing Knowledge", questId=3517, coords={ x=22.54, y=51.38 }, npc = { name="Jediga" }, note="Jediga in Valormok (22.54, 51.38)" },
    { type="TRAVEL", coords={ x=51.86, y=80.41 }, note="Travel to Undercity (51.86, 80.41)" },
    { type="TURNIN", title="A Donation of Wool", questId=7813, coords={ x=71.83, y=29.15 }, npc = { name="Ralston Farnsley" }, note="Ralston Farnsley in Magic Quarter (71.83, 29.15)" },
    { type="TURNIN", title="A Donation of Mageweave", questId=7817, coords={ x=71.83, y=29.15 }, npc = { name="Ralston Farnsley" }, note="Ralston Farnsley in Magic Quarter (71.83, 29.15)" },
    { type="TURNIN", title="A Donation of Silk", questId=7814, coords={ x=71.83, y=29.15 }, npc = { name="Ralston Farnsley" }, note="Ralston Farnsley in Magic Quarter (71.83, 29.15)" },
    { type="ACCEPT", title="Seeping Corruption", questId=3568, coords={ x=51.86, y=80.41 }, npc = { name="Chemist Cuely" }, note="Chemist Cuely in The Apothecarium (51.86, 80.41) (49.90, 69.72)" },
    { type="ACCEPT", title="Errand for Apothecary Zinge", questId=232, coords={ x=50.14, y=68.24 }, npc = { name="Apothecary Zinge" }, note="Apothecary Zinge in The Apothecarium (50.14, 68.24)" },
    { type="TURNIN", title="Errand for Apothecary Zinge", questId=232, coords={ x=58.59, y=54.7 }, npc = { name="Alessandro Luca" }, note="Alessandro Luca in The Apothecarium (58.59, 54.70)" },
    { type="ACCEPT", title="Errand for Apothecary Zinge", questId=238, coords={ x=58.59, y=54.7 }, npc = { name="Alessandro Luca" }, note="Alessandro Luca in The Apothecarium (58.59, 54.70)" },
    { type="TURNIN", title="Errand for Apothecary Zinge", questId=238, coords={ x=51.86, y=80.41 }, npc = { name="Apothecary Zinge" }, note="Apothecary Zinge in The Apothecarium (51.86, 80.41) (50.12, 68.31)" },
    { type="ACCEPT", title="Into the Field", questId=243, coords={ x=50.12, y=68.31 }, npc = { name="Apothecary Zinge" }, note="Apothecary Zinge in The Apothecarium (50.12, 68.31)" },
    { type="NOTE", note="Store Hippogryph Egg at the bank. Tick this step (66.0, 45.2)", coords={ x=66.0, y=45.2 } },
    { type="NOTE", note="Store Field Testing Kit at the bank. Tick this step (66.0, 45.2)", coords={ x=66.0, y=45.2 } },
    { type="NOTE", note="Store Box of Empty Vials at the bank. Tick this step (66.0, 45.2)", coords={ x=66.0, y=45.2 } },
    { type="NOTE", note="Withdraw Bundle of Atal'ai Artifacts at the bank. Tick this step (66.0, 45.2)", coords={ x=66.0, y=45.2 } },
    { type="NOTE", note="Withdraw Nimboya's Pike at the bank. Tick this step (66.0, 45.2)", coords={ x=66.0, y=45.2 } },
    { type="NOTE", note="Tick to continue to the next guide" },
  }
}
