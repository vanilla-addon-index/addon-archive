-- =========================
-- QS_Stonetalon_Mountains_22_23.lua
-- Converted from TourGuide format on 2025-08-16 22:16:16
-- =========================

QuestShellGuides = QuestShellGuides or {}

QuestShellGuides["QS_Stonetalon_Mountains_22_23_A"] = {
  title    = "Stonetalon Mountains (22-23)",
  next     = "Darkshore (23-24)",
  nextKey  = "QS_Darkshore_23_24_A",
  faction  = "Alliance",
  minLevel = 22,
  maxLevel = 23,
  steps = {
    { type="TRAVEL", coords={ x=62.95, y=37.23 }, note="Travel to Ratchet only if you have flight point or want to make the run(62.95, 37.23)" },
    { type="ACCEPT", title="Ziz Fizziks", questId=1483, coords={ x=62.95, y=37.23 }, npc = { name="Sputtervalve" }, note="Sputtervalve in Ratchet (62.95, 37.23)" },
    { type="TRAVEL", coords={ x=34.5, y=48.0 }, note="Travel to Astranaar (34.5, 48)" },
    { type="ACCEPT", title="On Guard in Stonetalon", questId=1070, coords={ x=34.92, y=49.77 }, npc = { name="Sentinel Thenysil" }, note="Sentinel Thenysil in Astranaar (34.92, 49.77)" },
    { type="ACCEPT", title="Journey to Stonetalon Peak", questId=1056, coords={ x=35.78, y=49.16 }, npc = { name="Faldreas Goeth'Shael" }, note="Faldreas Goeth'Shael in Astranaar (35.78, 49.16)" },
    { type="TRAVEL", coords={ x=42.08, y=57.83 }, note="Travel to The Talondeep Path (42.08, 57.83) (41.72, 65.95) (42.38, 70.90)" },
    { type="TRAVEL", coords={ x=59.0, y=62.5 }, note="Travel to Windshear Crag (59.00, 62.50)" },
    { type="TURNIN", title="Ziz Fizziks", questId=1483, coords={ x=59.0, y=62.5 }, npc = { name="Ziz Fizziks" }, note="Ziz Fizziks in Windshear Crag (59.00, 62.50)" },
    { type="ACCEPT", title="Super Reaper 6000", questId=1093, coords={ x=59.0, y=62.5 }, npc = { name="Ziz Fizziks" }, note="Ziz Fizziks in Windshear Crag (59.00, 62.50)" },
    { type="TURNIN", title="On Guard in Stonetalon", questId=1070, coords={ x=59.87, y=66.86 }, npc = { name="Kaela Shadowspear" }, note="Kaela Shadowspear in Webwinder Path (59.87, 66.86)" },
    { type="ACCEPT", title="On Guard in Stonetalon", questId=1085, coords={ x=59.87, y=66.86 }, npc = { name="Kaela Shadowspear" }, note="Kaela Shadowspear in Webwinder Path (59.87, 66.86)" },
    { type="TURNIN", title="On Guard in Stonetalon", questId=1085, coords={ x=59.49, y=67.1 }, npc = { name="Gaxim Rustfizzle" }, note="Gaxim Rustfizzle in Webwinder Path (59.49, 67.10)" },
    { type="ACCEPT", title="A Gnome's Respite", questId=1071, coords={ x=59.49, y=67.1 }, npc = { name="Gaxim Rustfizzle" }, note="Gaxim Rustfizzle in Webwinder Path (59.49, 67.10)" },
    { type="COMPLETE", title="Super Reaper 6000", questId=1093, coords={ x=62.63, y=52.07 }, note="Kill Venture Co. Operator until you find Super Reaper 6000 Blueprints for Ziz Fizziks in Windshear Crag (62.63, 52.07)" },
    { type="COMPLETE", title="A Gnome's Respite", questId=1071, coords={ x=67.9, y=51.44 }, note="Kill 10 Venture Co. Deforester and 10 Venture Co. Logger in Windshear Crag (67.90, 51.44) (68.99, 56.77)" },
    { type="TURNIN", title="Super Reaper 6000", questId=1093, coords={ x=58.99, y=62.56 }, npc = { name="Ziz Fizziks" }, note="Ziz Fizziks in Windshear Crag (58.99, 62.56)" },
    { type="TRAVEL", coords={ x=60.0, y=69.98 }, note="Travel to Webwinder Path (60.00, 69.98)" },
    { type="TURNIN", title="A Gnome's Respite", questId=1071, coords={ x=59.5, y=67.16 }, npc = { name="Gaxim Rustfizzle" }, note="Gaxim Rustfizzle in Webwinder Path (59.50, 67.16)" },
    { type="ACCEPT", title="An Old Colleague", questId=1072, coords={ x=59.5, y=67.16 }, npc = { name="Gaxim Rustfizzle" }, note="Gaxim Rustfizzle in Webwinder Path (59.50, 67.16)" },
    { type="TRAVEL", coords={ x=51.84, y=51.84 }, note="Travel to Mirkfallon Lake (51.84, 51.84) (51.54, 48.63)" },
    { type="COMPLETE", title="Pridewings of Stonetalon", questId=1134, coords={ x=54.63, y=43.35 }, note="Kill Pridewing Wyvern and collect 12 Pridewing Venom Sac in Mirkfallon Lake (54.63, 43.35)" },
    { type="TRAVEL", coords={ x=37.1, y=8.1 }, note="Travel to Stonetalon Peak (37.10, 8.10)" },
    { type="TURNIN", title="Journey to Stonetalon Peak", questId=1056, coords={ x=37.1, y=8.1 }, npc = { name="Keeper Albagorm" }, note="Keeper Albagorm in Stonetalon Peak (37.10, 8.10)" },
    { type="FLIGHTPATH", npc = { name="Teloren" }, coords={ x=36.46, y=7.2 }, note="Speak to Teloren and grab flight path for Stonetalon Peak (36.46, 7.20)" },
    { type="NOTE", note="Tick to continue to the next guide" },
  }
}
