-- =========================
-- QS_Thousand_Needles_25_26.lua
-- Converted from TourGuide format on 2025-08-17 18:59:05
-- =========================

QuestShellGuides = QuestShellGuides or {}

QuestShellGuides["QS_Thousand_Needles_25_26"] = {
  title    = "Thousand Needles (25-26)",
  next     = "Ashenvale (26-27)",
  nextKey  = "QS_Ashenvale_26_27",
  faction  = "Horde",
  minLevel = 25,
  maxLevel = 26,
  steps = {
    { type="TURNIN", title="Weapons of Choice", questId=893, coords={ x=45.12, y=57.69 }, npc = { name="Tatternack Steelforge" }, note="Tatternack Steelforge in Camp Taurajo (45.12, 57.69)" },
    { type="ACCEPT", title="A New Ore Sample", questId=1153, coords={ x=45.09, y=57.72 }, npc = { name="Tatternack Steelforge" }, note="Tatternack Steelforge in Camp Taurajo (45.09, 57.72)" },
    { type="COMPLETE", title="Galak Messenger", questId=4881, coords={ x=38.6, y=31.5 }, note="Find and kill the patroling Galak Messenger to start new quest in Darkcloud Pinnacle (38.6, 31.5) (29.5, 34.6) (18.9, 27.1)" },
    { type="ACCEPT", title="Assassination Plot", questId=4881, note="Use Assassination Note to accept quest" },
    { type="TRAVEL", coords={ x=47.0, y=48.2 }, note="Run to Freewind Post use the Elevator at (47, 48.2)" },
    { type="TURNIN", title="Message to Freewind Post", questId=4542, coords={ x=45.69, y=50.66 }, npc = { name="Cliffwatcher Longhorn" }, note="Cliffwatcher Longhorn in Freewind Post (45.69, 50.66)" },
    { type="ACCEPT", title="Pacify the Centaur", questId=4841, coords={ x=45.69, y=50.66 }, npc = { name="Cliffwatcher Longhorn" }, note="Cliffwatcher Longhorn in Freewind Post (45.69, 50.66)" },
    { type="ACCEPT", title="Wanted - Arnak Grimtotem", questId=5147, coords={ x=46.0, y=50.8 }, note="Wanted Poster - Arnak Grimtotem (46.0, 50.8)" },
    { type="ACCEPT", title="Alien Egg", questId=4821, coords={ x=44.71, y=50.26 }, npc = { name="Hagar Lightninghoof" }, note="Hagar Lightninghoof in Freewind Post (44.71, 50.26)" },
    { type="ACCEPT", title="Wind Rider", questId=4767, coords={ x=44.85, y=49.04 }, npc = { name="Elu" }, note="Elu in Freewind Post (44.85, 49.04)" },
    { type="FLIGHTPATH", npc = { name="Nyse" }, coords={ x=45.1, y=49.2 }, note="Speak to Nyse and grab flight path for Freewind Post (45.1, 49.2)" },
    { type="COMPLETE", title="Pacify the Centaur", questId=4841, coords={ x=48.0, y=43.0 }, note="Kill 12 Galak Scout, 10 Galak Wrangler and 6 Galak Windchaser just north of Freewind (48, 43)" },
    { type="ACCEPT", title="Test of Faith", questId=1149, coords={ x=54.6, y=44.5 }, npc = { name="Dorn Plainstalker" }, note="Dorn Plainstalker in The Weathered Nook (54.6, 44.5) (53.88, 41.49)" },
    { type="COMPLETE", title="Test of Faith", questId=1149, coords={ x=26.4, y=32.4 }, note="Run off the platform, Make sure you only jump off of the wooden plank! If you jump off of anywhere else you will fall to your death (26.4, 32.4)" },
    { type="TURNIN", title="Test of Faith", questId=1149, coords={ x=53.88, y=41.49 }, npc = { name="Dorn Plainstalker" }, note="Dorn Plainstalker in The Weathered Nook (53.88, 41.49)" },
    { type="COMPLETE", title="A New Ore Sample", questId=1153, coords={ x=63.8, y=46.4 }, note="KIll Gravelsnout Digger or Gravelsnout Surveyor and collect Unrefined Ore Sample (63.8, 46.4) (66.3, 49.3) (67.4, 60.3) (60.1, 57.5) (55.2, 50.3)" },
    { type="COMPLETE", title="Alien Egg", questId=4821, coords={ x=56.3, y=50.4 }, note="The Alien Egg can spawn around 3 possible spots (56.3, 50.4) (52.4, 55.2) (37.7, 56.2)" },
    { type="TRAVEL", coords={ x=47.0, y=48.2 }, note="Run to Freewind Post use the Elevator at (47, 48.2)" },
    { type="TURNIN", title="Pacify the Centaur", questId=4841, coords={ x=45.69, y=50.66 }, npc = { name="Cliffwatcher Longhorn" }, note="Cliffwatcher Longhorn in Freewind Post (45.69, 50.66)" },
    { type="ACCEPT", title="Grimtotem Spying", questId=5064, coords={ x=45.69, y=50.66 }, npc = { name="Cliffwatcher Longhorn" }, note="Cliffwatcher Longhorn in Freewind Post (45.69, 50.66)" },
    { type="TURNIN", title="Alien Egg", questId=4821, coords={ x=44.71, y=50.26 }, npc = { name="Hagar Lightninghoof" }, note="Hagar Lightninghoof in Freewind Post (44.71, 50.26)" },
    { type="ACCEPT", title="Serpent Wild", questId=4865, coords={ x=44.71, y=50.26 }, npc = { name="Hagar Lightninghoof" }, note="Hagar Lightninghoof in Freewind Post (44.71, 50.26)" },
    { type="TRAVEL", coords={ x=44.86, y=59.13 }, note="Travel to Camp Taurajo (44.86, 59.13)" },
    { type="ACCEPT", title="Washte Pawne", questId=885, note="Use Washte Pawne's Feather to accept quest" },
    { type="TURNIN", title="Washte Pawne", questId=885, coords={ x=44.86, y=59.13 }, npc = { name="Jorn Skyseer" }, note="Jorn Skyseer in Camp Taurajo (44.86, 59.13)" },
    { type="TURNIN", title="Enraged Thunder Lizards", questId=907, coords={ x=44.86, y=59.13 }, npc = { name="Jorn Skyseer" }, note="Jorn Skyseer in Camp Taurajo (44.86, 59.13)" },
    { type="ACCEPT", title="Cry of the Thunderhawk", questId=913, coords={ x=44.86, y=59.13 }, npc = { name="Jorn Skyseer" }, note="Jorn Skyseer in Camp Taurajo (44.86, 59.13)" },
    { type="TURNIN", title="A New Ore Sample", questId=1153, coords={ x=45.11, y=57.73 }, npc = { name="Tatternack Steelforge" }, note="Tatternack Steelforge in Camp Taurajo (45.11, 57.73)" },
    { type="COMPLETE", title="Cry of the Thunderhawk", questId=913, coords={ x=44.0, y=55.0 }, note="Kill Thunderhawk Cloudscraper to collect Thunderhawk Wings (44.0, 55.0) (48.3, 56.9) (48.1, 60.0) (48.7, 62.1) (44.9, 63.0) (44.5, 61.6)" },
    { type="TURNIN", title="Cry of the Thunderhawk", questId=913, coords={ x=44.89, y=59.15 }, npc = { name="Jorn Skyseer" }, note="Jorn Skyseer in Camp Taurajo (44.89, 59.15)" },
    { type="NOTE", note="Tick to continue to the next guide" },
  }
}
