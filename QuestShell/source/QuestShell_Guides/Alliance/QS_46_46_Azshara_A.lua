-- =========================
-- QS_Azshara_46_46.lua
-- Converted from TourGuide format on 2025-08-16 22:16:23
-- =========================

QuestShellGuides = QuestShellGuides or {}

QuestShellGuides["QS_Azshara_46_46_A"] = {
  title    = "Azshara (46-46)",
  next     = "The Hinterlands (46-46)",
  nextKey  = "QS_The_Hinterlands_46_46_A",
  faction  = "Alliance",
  minLevel = 46,
  maxLevel = 46,
  steps = {
    { type="TRAVEL", coords={ x=11.4, y=78.13 }, note="Travel to Talrendis Point in Azshara (11.40, 78.13)" },
    { type="FLIGHTPATH", npc = { name="Jarrodenus" }, coords={ x=11.9, y=77.57 }, note="Speak to Jarrodenus and grab flight path for Talrendis Point (11.90, 77.57)" },
    { type="ACCEPT", title="Spiritual Unrest", questId=5535, coords={ x=11.4, y=78.13 }, npc = { name="Loh'atu" }, note="Loh'atu in Talrendis Point (11.40, 78.13)" },
    { type="ACCEPT", title="A Land Filled with Hatred", questId=5536, coords={ x=11.4, y=78.13 }, npc = { name="Loh'atu" }, note="Loh'atu in Talrendis Point (11.40, 78.13)" },
    { type="COMPLETE", title="Spiritual Unrest", questId=5535, coords={ x=16.4, y=68.21 }, note="Kill 6 Highborne Lichling and 6 Highborne Apparition in Shadowsong Shrine (16.40, 68.21)" },
    { type="TRAVEL", coords={ x=20.58, y=61.67 }, note="Travel to Haldarr Encampment (20.58, 61.67)" },
    { type="COMPLETE", title="A Land Filled with Hatred", questId=5536, coords={ x=20.58, y=61.67 }, note="Kill 2 Haldarr Trickster, 2 Haldarr Felsworn and 6 Haldarr Satyr in Haldarr Encampment (20.58, 61.67)" },
    { type="TRAVEL", coords={ x=11.37, y=78.15 }, note="Travel to Talrendis Point (11.37, 78.15)" },
    { type="TURNIN", title="Spiritual Unrest", questId=5535, coords={ x=11.37, y=78.15 }, npc = { name="Loh'atu" }, note="Loh'atu in Talrendis Point (11.37, 78.15)" },
    { type="TURNIN", title="A Land Filled with Hatred", questId=5536, coords={ x=11.37, y=78.15 }, npc = { name="Loh'atu" }, note="Loh'atu in Talrendis Point (11.37, 78.15)" },
    { type="TRAVEL", coords={ x=52.35, y=26.91 }, note="Travel to Gadgetzan (52.35, 26.91)" },
    { type="TURNIN", title="The Borrower", questId=2941, coords={ x=52.35, y=26.91 }, npc = { name="Curgle Cranklehop" }, note="Curgle Cranklehop in Gadgetzan (52.35, 26.91)" },
    { type="ACCEPT", title="The Super Snapper FX", questId=2944, coords={ x=52.35, y=26.91 }, npc = { name="Curgle Cranklehop" }, note="Curgle Cranklehop in Gadgetzan (52.35, 26.91)" },
    { type="NOTE", note="Withdraw Bag of Water Elemental Bracers from the bank. Tick this step (52.30, 28.89)", coords={ x=52.3, y=28.89 } },
    { type="NOTE", note="Withdraw Seahorn's Sealed Letter from the bank. Tick this step (52.30, 28.89)", coords={ x=52.3, y=28.89 } },
    { type="NOTE", note="Withdraw Letter of Commendation from the bank. Tick this step (52.30, 28.89)", coords={ x=52.3, y=28.89 } },
    { type="NOTE", note="Tick to continue to the next guide" },
  }
}
