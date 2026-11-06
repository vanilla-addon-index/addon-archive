-- =========================
-- QS_Felwood_54_54.lua
-- Converted from TourGuide format on 2025-08-17 18:59:07
-- =========================

QuestShellGuides = QuestShellGuides or {}

QuestShellGuides["QS_Felwood_54_54"] = {
  title    = "Felwood (54-54)",
  next     = "Winterspring (54-55)",
  nextKey  = "QS_Winterspring_54_55",
  faction  = "Horde",
  minLevel = 54,
  maxLevel = 54,
  steps = {
    { type="TRAVEL", coords={ x=51.06, y=81.91 }, note="Travel to Emerald Sanctuary (51.06, 81.91)" },
    { type="ACCEPT", title="Forces of Jaedenar", questId=5155, coords={ x=51.06, y=81.91 }, npc = { name="Greta Mosshoof" }, note="Greta Mosshoof in Emerald Sanctuary (51.06, 81.91)" },
    { type="ACCEPT", title="Verifying the Corruption", questId=5156, coords={ x=50.94, y=81.62 }, npc = { name="Taronn Redfeather" }, note="Taronn Redfeather in Emerald Sanctuary (50.94, 81.62)" },
    { type="ACCEPT", title="Cleansing Felwood", questId=4102, coords={ x=46.76, y=83.12 }, npc = { name="Maybess Riverbreeze" }, note="Maybess Riverbreeze in Felwood (46.76, 83.12)" },
    { type="ACCEPT", title="Timbermaw Ally", questId=8460, coords={ x=50.94, y=85.0 }, npc = { name="Grazle" }, note="Grazle in Emerald Sanctuary (50.94, 85.00)" },
    { type="COMPLETE", title="Timbermaw Ally", questId=8460, coords={ x=48.69, y=92.08 }, note="Kill the required Deadwood furbolg mobs in Deadwood Village (48.69, 92.08)" },
    { type="TURNIN", title="Timbermaw Ally", questId=8460, coords={ x=50.93, y=85.03 }, npc = { name="Grazle" }, note="Grazle in Emerald Sanctuary (50.93, 85.03)" },
    { type="ACCEPT", title="Speak to Nafien", questId=8462, coords={ x=50.93, y=85.03 }, npc = { name="Grazle" }, note="Grazle in Emerald Sanctuary (50.93, 85.03)" },
    { type="TRAVEL", coords={ x=40.41, y=71.54 }, note="Travel to Ruins of Constellas (40.41, 71.54)" },
    { type="COMPLETE", title="Cursed Ooze", questId=4293, coords={ x=40.41, y=71.54 }, note="Kill Cursed Ooze and start collecting Felwood Slime Sample, you will need about 35 total. Clear both pool area and collect 20 Felwood Slime Sample for now (40.41, 71.54) (40.67, 66.91)" },
    { type="TRAVEL", coords={ x=39.36, y=58.17 }, note="Travel to Jaedenar (39.36, 58.17)" },
    { type="COMPLETE", title="Forces of Jaedenar", questId=5155, coords={ x=38.87, y=58.76 }, note="Kill the required Jaedenar Satrys in Jaedenar (38.87, 58.76) (37.66, 61.12) (35.40, 60.27)" },
    { type="COMPLETE", title="Tainted Ooze", questId=4293, coords={ x=40.0, y=55.02 }, note="Kill Tainted Ooze and finish collecting 35 Felwood Slime Sample in Jaedenar (40.00, 55.02) (40.57, 59.06)" },
    { type="TRAVEL", coords={ x=39.95, y=50.72 }, note="Travel to Bloodvenom Post (39.95, 50.72) (34.97, 50.46)" },
    { type="TURNIN", title="A Strange One", questId=4505, coords={ x=34.21, y=52.34 }, npc = { name="Winna Hazzard" }, note="Winna Hazzard in Bloodvenom Post (34.21, 52.34)" },
    { type="ACCEPT", title="Well of Corruption", questId=4505, coords={ x=34.21, y=52.34 }, npc = { name="Winna Hazzard" }, note="Winna Hazzard in Bloodvenom Post (34.21, 52.34)" },
    { type="ACCEPT", title="A Husband's Last Battle", questId=6162, coords={ x=34.71, y=52.77 }, npc = { name="Dreka'Sur" }, note="Dreka'Sur in Bloodvenom Post (34.71, 52.77)" },
    { type="ACCEPT", title="Wild Guardians", questId=4521, coords={ x=34.68, y=52.79 }, npc = { name="Trull Failbane" }, note="Trull Failbane in Bloodvenom Post (34.68, 52.79)" },
    { type="FLIGHTPATH", npc = { name="Brakkar" }, coords={ x=34.44, y=53.96 }, note="Speak to Brakkar grab flight path for Bloodvenom Post (34.44, 53.96)" },
    { type="TRAVEL", coords={ x=43.32, y=74.51 }, note="Travel to Shatter Scar Vale (43.32, 74.51) (40.55, 42.80)" },
    { type="COMPLETE", title="Verifying the Corruption", questId=5156, coords={ x=40.55, y=42.8 }, note="Kill 2 Maeva Snowbraid and 2 Entropic Beast in Shatter Scar Vale (40.55, 42.80)" },
    { type="NOTE", note="Kill 12 Angerclaw Grizzly and 12 Felpaw Ravager" },
    { type="TRAVEL", coords={ x=39.97, y=34.23 }, note="Travel to Irontree Woods (39.97, 34.23) (41.17, 24.88) (50.17, 14.10) (55.07, 17.71)" },
    { type="COMPLETE", title="Cleansing Felwood", questId=4102, coords={ x=55.19, y=17.72 }, note="Kill Warpwood Moss Flayer, Warpwood Shredder and collect 15 Blood Amber in Irontree Woods, (low drop rate) (55.19, 17.72)" },
    { type="TRAVEL", coords={ x=55.07, y=17.71 }, note="Travel to Irontree Woods (55.07, 17.71)" },
    { type="COMPLETE", title="The Strength of Corruption", questId=4120, coords={ x=51.3, y=12.29 }, note="Kill 12 Angerclaw Grizzly and 12 Felpaw Ravager in Irontree Woods (51.30, 12.29) (55.76, 22.00) (56.76, 24.96)" },
    { type="TRAVEL", coords={ x=64.75, y=8.14 }, note="Travel to Timbermaw Hold (64.75, 8.14)" },
    { type="ACCEPT", title="Deadwood of the North", questId=8461, coords={ x=64.75, y=8.14 }, npc = { name="Nafien" }, note="Nafien in Timbermaw Hold (64.75, 8.14)" },
    { type="COMPLETE", title="Deadwood of the North", questId=8461, coords={ x=62.89, y=11.29 }, note="Kill the required Deadwood Timbermaw in Felpaw Village (62.89, 11.29) (62.69, 7.86) (61.37, 7.42)" },
    { type="NOTE", note="Keep killing furbolgs until you are 150 points from unfriendly reputation with Timbermaw Hold (2850/3000)" },
    { type="TURNIN", title="Deadwood of the North", questId=8461, coords={ x=64.77, y=8.17 }, npc = { name="Nafien" }, note="Nafien in Timbermaw Hold (64.77, 8.17)" },
    { type="ACCEPT", title="Speak to Salfa", questId=8465, coords={ x=64.76, y=8.19 }, npc = { name="Nafien" }, note="Nafien in Timbermaw Hold (64.76, 8.19)" },
    { type="TRAVEL", coords={ x=35.76, y=72.41 }, note="Travel north via the tunnel to Moonglade (35.76, 72.41)" },
    { type="FLIGHTPATH", npc = { name="Faustron" }, coords={ x=32.14, y=66.54 }, note="Speak to Faustron and grab flight path for Moonglade (32.14, 66.54)" },
    { type="NOTE", note="Tick to continue to the next guide" },
  }
}
