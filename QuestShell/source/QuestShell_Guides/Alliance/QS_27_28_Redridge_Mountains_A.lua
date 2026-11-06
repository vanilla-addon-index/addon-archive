-- =========================
-- QS_Redridge_Mountains_27_28.lua
-- Converted from TourGuide format on 2025-08-16 22:16:17
-- =========================

QuestShellGuides = QuestShellGuides or {}

QuestShellGuides["QS_Redridge_Mountains_27_28_A"] = {
  title    = "Redridge Mountains (27-28)",
  next     = "Duskwood (28-29)",
  nextKey  = "QS_Duskwood_28_29_A",
  faction  = "Alliance",
  minLevel = 27,
  maxLevel = 28,
  steps = {
    { type="TRAVEL", coords={ x=31.52, y=57.9 }, note="Travel to in Lakeshire (31.52, 57.90)" },
    { type="ACCEPT", title="Blackrock Bounty", questId=128, coords={ x=31.52, y=57.9 }, npc = { name="Guard Howe" }, note="Guard Howe in Lakeshire (31.52, 57.90)" },
    { type="ACCEPT", title="Blackrock Menace", questId=20, coords={ x=33.4, y=48.9 }, npc = { name="Marshal Marris" }, note="Marshal Marris in Lakeshire (33.4, 48.9)" },
    { type="ACCEPT", title="Wanted: Gath'Ilzogg", questId=169, coords={ x=29.54, y=46.03 }, npc = { name="Wanted Sign" }, note="Wanted Sign in Lakeshire (29.54, 46.03)" },
    { type="TURNIN", title="Messenger to Stormwind", questId=121, coords={ x=30.0, y=44.0 }, npc = { name="Magistrate Solomon" }, note="Magistrate Solomon in Lakeshire (30, 44)" },
    { type="ACCEPT", title="Solomon's Law", questId=91, coords={ x=29.64, y=44.35 }, npc = { name="Bailiff Conacher" }, note="Bailiff Conacher in Lakeshire (29.64, 44.35)" },
    { type="ACCEPT", title="Wanted: Lieutenant Fangore", questId=180, coords={ x=26.7, y=46.5 }, npc = { name="Wanted Sign" }, note="Wanted Sign in Lakeshire (26.7, 46.5)" },
    { type="SET_HEARTH", title="An Unwelcome Guest", coords={ x=27.0, y=45.0 }, npc = { name="Innkeeper Brianna" }, note="Speak to Innkeeper Brianna and set hearth in Lakeshire (27, 45)" },
    { type="ACCEPT", title="An Unwelcome Guest", questId=34, coords={ x=21.9, y=46.27 }, npc = { name="Martie Jainrose" }, note="Martie Jainrose in Lakeshire (21.90, 46.27)" },
    { type="COMPLETE", title="An Unwelcome Guest", questId=34, coords={ x=17.0, y=48.0 }, note="Kill Bellygrub and collect Bellygrub's Tusk west of Lakeshire (17, 48)" },
    { type="TURNIN", title="An Unwelcome Guest", questId=34, coords={ x=21.9, y=46.27 }, npc = { name="Martie Jainrose" }, note="Martie Jainrose in Lakeshire (21.90, 46.27)" },
    { type="TURNIN", title="A Baying of Gnolls", questId=124, coords={ x=31.03, y=47.42 }, npc = { name="Verner Osgood" }, note="Verner Osgood, in Lakeshire (31.03, 47.42)" },
    { type="ACCEPT", title="Howling in the Hills", questId=126, coords={ x=31.03, y=47.42 }, npc = { name="Verner Osgood" }, note="Verner Osgood, in Lakeshire (31.03, 47.42)" },
    { type="COMPLETE", title="Howling in the Hills", questId=126, coords={ x=39.2, y=33.8 }, note="Kill Yowler and collect Yowler's Paw in Redridge Canyons, he patrol's around use the target button or /tar Yowler (39.2, 33.8) (32.4, 25) (27.8, 23.0) (23.8, 29)" },
    { type="COMPLETE", title="Blackrock Menace", questId=20, coords={ x=29.2, y=11.6 }, note="Collect 10 Battleworn Axe which drop from Blackrock Grunt, Blackrock Summoner, Blackrock Tracker and Blackrock Outrunner found along the Northern road or at their encampment at (29.2, 11.6)" },
    { type="COMPLETE", title="Blackrock Bounty", questId=128, coords={ x=31.0, y=14.0 }, note="Kill 15 Blackrock Champion which are found in Render's Rock (31, 14)" },
    { type="ACCEPT", title="Missing In Action", questId=219, coords={ x=28.36, y=12.74 }, npc = { name="Corporal Keeshan" }, note="Corporal Keeshan in Render's Rock (28.36, 12.74)" },
    { type="COMPLETE", title="Missing In Action", questId=219, coords={ x=31.22, y=15.04 }, note="This is an escort quest where you must protect Corporal Keeshan through the cave. He is a strong NPC who you should let tank but also be sure to pull the mobs to him instead of him charging into them to prevent any unwanted adds. He is an elite warrior so will help taunt any mobs off you, skip this quest if its too hard (31.22, 15.04) (33.41, 48.52)" },
    { type="TURNIN", title="Missing In Action", questId=219, coords={ x=33.4, y=48.9 }, npc = { name="Marshal Marris" }, note="Marshal Marris in Lakeshire (33.4, 48.9)" },
    { type="TURNIN", title="Blackrock Menace", questId=20, coords={ x=33.4, y=48.9 }, npc = { name="Marshal Marris" }, note="Marshal Marris in Lakeshire (33.4, 48.9)" },
    { type="TURNIN", title="Blackrock Bounty", questId=128, coords={ x=31.52, y=57.9 }, npc = { name="Guard Howe" }, note="Guard Howe in Lakeshire (31.52, 57.90)" },
    { type="TURNIN", title="Howling in the Hills", questId=126, coords={ x=31.03, y=47.42 }, npc = { name="Verner Osgood" }, note="Verner Osgood, in Lakeshire (31.03, 47.42)" },
    { type="TRAVEL", coords={ x=79.1, y=37.19 }, note="Travel to Galardell Valley (79.10, 37.19)" },
    { type="COMPLETE", title="Wanted: Lieutenant Fangore", questId=180, coords={ x=80.0, y=40.0 }, note="Kill Lieutenant Fangore and collect Fangore's Paw in Galardell Valley. Lieutenant Fangore is a level 26 non-elite but is surrounded by other mobs. Clear any mobs first before attacking him and then loot Fangore's Paw (80, 40)" },
    { type="COMPLETE", title="Solomon's Law", questId=91, coords={ x=74.0, y=47.0 }, note="Collect 10 Shadowhide Pendant from Shadowhide Warrior, Shadowhide Gnoll, Rabid Shadowhide Gnoll and Shadowhide Brute in Galardell Valley (74, 47)" },
    { type="NOTE", note="Collect Glowing Shadowhide Pendant from Shadowhide Warrior in Galardell Valley (74, 47)", coords={ x=74.0, y=47.0 } },
    { type="ACCEPT", title="Theocritus' Retrieval", questId=178, note="Use Glowing Shadowhide Pendant to accept quest" },
    { type="TRAVEL", coords={ x=29.64, y=44.35 }, note="Travel to Lakeshire (29.64, 44.35)" },
    { type="TURNIN", title="Solomon's Law", questId=91, coords={ x=29.64, y=44.35 }, npc = { name="Bailiff Conacher" }, note="Bailiff Conacher in Lakeshire (29.64, 44.35)" },
    { type="TURNIN", title="Wanted: Lieutenant Fangore", questId=180, coords={ x=30.0, y=44.0 }, npc = { name="Magistrate Solomon" }, note="Magistrate Solomon in Lakeshire (30, 44)" },
    { type="TRAVEL", coords={ x=65.2, y=69.72 }, note="Travel to Tower of Azora (65.20, 69.72)" },
    { type="TURNIN", title="Theocritus' Retrieval", questId=178, coords={ x=65.2, y=69.72 }, npc = { name="Theocritus" }, note="Theocritus in Tower of Azora, inside on the top floor (65.20, 69.72)" },
    { type="NOTE", note="Tick to continue to the next guide" },
  }
}
