-- =========================
-- QS_Darkshore_23_24.lua
-- Converted from TourGuide format on 2025-08-16 22:16:16
-- =========================

QuestShellGuides = QuestShellGuides or {}

QuestShellGuides["QS_Darkshore_23_24_A"] = {
  title    = "Darkshore (23-24)",
  next     = "Ashenvale (24-24)",
  nextKey  = "QS_Ashenvale_24_24_A",
  faction  = "Alliance",
  minLevel = 23,
  maxLevel = 24,
  steps = {
    { type="TRAVEL", coords={ x=37.21, y=44.27 }, note="Travel to Auberdine (37.21, 44.27)" },
    { type="SET_HEARTH", title="The Absent Minded Prospector", coords={ x=37.0, y=44.1 }, npc = { name="Innkeeper Shaussiy" }, note="Speak to Innkeeper Shaussiy and set hearth in Auberdine (37, 44.1)" },
    { type="TURNIN", title="WANTED: Murkdeep!", questId=4740, coords={ x=37.7, y=43.44 }, npc = { name="Sentinel Glynda Nal'Shea" }, note="Sentinel Glynda Nal'Shea in Auberdine (37.70, 43.44)" },
    { type="TURNIN", title="The Absent Minded Prospector", questId=731, coords={ x=37.46, y=41.88 }, npc = { name="Archaeologist Hollee" }, note="Archaeologist Hollee in Auberdine (37.46, 41.88)" },
    { type="ACCEPT", title="The Absent Minded Prospector", questId=741, coords={ x=37.46, y=41.88 }, npc = { name="Archaeologist Hollee" }, note="Archaeologist Hollee in Auberdine (37.46, 41.88)" },
    { type="TURNIN", title="How Big a Threat?", questId=985, coords={ x=39.35, y=43.46 }, npc = { name="Terenthis" }, note="Terenthis in Auberdine (39.35, 43.46)" },
    { type="ACCEPT", title="A Lost Master", questId=986, coords={ x=39.32, y=43.45 }, npc = { name="Terenthis" }, note="Terenthis in Auberdine (39.32, 43.45)" },
    { type="TRAVEL", coords={ x=58.5, y=24.31 }, note="Travel to Ruins of Mathystra (58.50, 24.31)" },
    { type="TURNIN", title="Return to Onu", questId=950, coords={ x=43.55, y=76.32 }, npc = { name="Onu" }, note="Onu in Grove of the Ancients (43.55, 76.32)" },
    { type="COMPLETE", title="Mathystra Relics", questId=951, coords={ x=58.5, y=24.31 }, note="Collect 6 Mathystra Relic from the ground in Ruins of Mathystra (58.50, 24.31)" },
    { type="TRAVEL", coords={ x=56.68, y=13.53 }, note="Travel to Mist's Edge (56.68, 13.53)" },
    { type="ACCEPT", title="Gyromast's Retrieval", questId=2098, coords={ x=56.68, y=13.53 }, npc = { name="Gelkak Gyromast" }, note="Gelkak Gyromast in Mist's Edge (56.68, 13.53)" },
    { type="COMPLETE", title="Gyromast's Retrieval", questId=2098, coords={ x=56.36, y=17.22 }, note="Kill Raging Reef Crawler until you collect Bottom of Gelkak's Key in Mist's Edge (56.36, 17.22) | Kill Greymist Tidehunter until you collect Middle of Gelkak's Key in Mist's Edge (55.41, 12.33) | Kill Giant Foreststrider until you collect Top of Gelkak's Key in Mist's Edge (61.71, 11.54)" },
    { type="COMPLETE", title="A Lost Master", questId=986, coords={ x=61.0, y=12.0 }, note="Kill Moonstalker Sire and collect 5 Fine Moonstalker Pelt in Mist's Edge (61, 12)" },
    { type="TURNIN", title="Gyromast's Retrieval", questId=2098, coords={ x=56.67, y=13.49 }, npc = { name="Gelkak Gyromast" }, note="Gelkak Gyromast in Mist's Edge (56.67, 13.49)" },
    { type="ACCEPT", title="Gyromast's Revenge", questId=2078, coords={ x=56.67, y=13.49 }, npc = { name="Gelkak Gyromast" }, note="Gelkak Gyromast in Mist's Edge (56.67, 13.49)" },
    { type="COMPLETE", title="Gyromast's Revenge", questId=2078, coords={ x=55.79, y=18.26 }, note="Speak to The Threshwackonator 4100 and bring it back to the quest giver in Mist's Edge<br/><b>The Threshwackonator 4100 will turn hostile as soon as you reach Gelkak Gyromast, be ready to use all your cooldowns as it can be difficult to solo (55.79, 18.26)" },
    { type="TURNIN", title="Gyromast's Revenge", questId=2078, coords={ x=56.67, y=13.51 }, npc = { name="Gelkak Gyromast" }, note="Gelkak Gyromast in Mist's Edge (56.67, 13.51)" },
    { type="NOTE", note="Destroy Gyromast's Key as it is no longer needed" },
    { type="TRAVEL", coords={ x=37.21, y=44.27 }, note="Travel to Auberdine (37.21, 44.27)" },
    { type="TURNIN", title="A Lost Master", questId=986, coords={ x=39.32, y=43.45 }, npc = { name="Terenthis" }, note="Terenthis in Auberdine (39.32, 43.45)" },
    { type="ACCEPT", title="A Lost Master", questId=993, coords={ x=39.34, y=43.49 }, npc = { name="Terenthis" }, note="Terenthis in Auberdine (39.34, 43.49)" },
    { type="TRAVEL", coords={ x=43.57, y=76.34 }, note="Travel to Grove of the Ancients (43.57, 76.34)" },
    { type="TURNIN", title="Mathystra Relics", questId=951, coords={ x=43.57, y=76.34 }, npc = { name="Onu" }, note="Onu in Grove of the Ancients (43.57, 76.34)" },
    { type="TRAVEL", coords={ x=44.96, y=85.33 }, note="Travel to Blackwood Den (44.96, 85.33)" },
    { type="TURNIN", title="A Lost Master", questId=993, coords={ x=44.96, y=85.33 }, npc = { name="Volcor" }, note="Volcor in Blackwood Den<br/><b>You can use the Enchanted Moonstalker Cloak to stealth pass the mobs (44.96, 85.33)" },
    { type="NOTE", note="Volcor in Blackwood Den. Select either 'Escape Through Force' for Steadfast Cinch (hard) or 'Escape Through Stealth' for Scarab Trousers (easy)" },
    { type="ACCEPT", title="Escape Through Force", questId=994, coords={ x=44.96, y=85.33 }, npc = { name="Volcor" }, note="Volcor in Blackwood Den (44.96, 85.33)" },
    { type="COMPLETE", title="Escape Through Force", questId=994, coords={ x=42.0, y=81.0 }, note="Escort Volcor until he escape in Blackwood Den (42, 81)" },
    { type="ACCEPT", title="Escape Through Stealth", questId=995, coords={ x=45.01, y=85.34 }, npc = { name="Volcor" }, note="Volcor in Blackwood Den (45.01, 85.34)" },
    { type="COMPLETE", title="Escape Through Stealth", questId=995, coords={ x=44.75, y=85.21 }, note="Escape the Furbolg cave and meet Terenthis in Auberdine (44.75, 85.21)" },
    { type="TRAVEL", coords={ x=39.34, y=43.48 }, note="Travel to Auberdine (39.34, 43.48)" },
    { type="TURNIN", title="Escape Through Stealth", questId=995, coords={ x=39.34, y=43.48 }, npc = { name="Terenthis" }, note="Terenthis in Auberdine (39.34, 43.48)" },
    { type="TURNIN", title="Escape Through Force", questId=994, coords={ x=39.34, y=43.48 }, npc = { name="Terenthis" }, note="Terenthis in Auberdine (39.34, 43.48)" },
    { type="TRAVEL", coords={ x=31.37, y=84.14 }, note="Travel to Darnassus (31.37, 84.14)" },
    { type="NOTE", note="Store Elixir of Water Breathing to the bank (39.88, 42.21)", coords={ x=39.88, y=42.21 } },
    { type="NOTE", note="Store Book: The Powers Below to the bank (39.88, 42.21)", coords={ x=39.88, y=42.21 } },
    { type="TURNIN", title="The Absent Minded Prospector", questId=741, coords={ x=31.37, y=84.14 }, npc = { name="Chief Archaeologist Greywhisker" }, note="Chief Archaeologist Greywhisker in Darnassus (31.37, 84.14)" },
    { type="ACCEPT", title="The Absent Minded Prospector", questId=942, coords={ x=31.28, y=83.65 }, npc = { name="Chief Archaeologist Greywhisker" }, note="Chief Archaeologist Greywhisker in Darnassus (31.28, 83.65)" },
    { type="NOTE", note="Tick to continue to the next guide" },
  }
}
