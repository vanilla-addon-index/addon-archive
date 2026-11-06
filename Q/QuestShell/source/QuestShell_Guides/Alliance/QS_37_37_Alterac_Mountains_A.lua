-- =========================
-- QS_Alterac_Mountains_36_37.lua
-- Converted from TourGuide format on 2025-08-16 22:16:20
-- =========================

QuestShellGuides = QuestShellGuides or {}

QuestShellGuides["QS_Alterac_Mountains_36_37_A"] = {
  title    = "Alterac Mountains (36-37)",
  next     = "Arathi Highlands (37-38)",
  nextKey  = "QS_Arathi_Highlands_37_38_A",
  faction  = "Alliance",
  minLevel = 36,
  maxLevel = 37,
  steps = {
    { type="TRAVEL", coords={ x=48.12, y=59.06 }, note="Travel to Southshore (48.12, 59.06)" },
    { type="ACCEPT", title="Crushridge Bounty", questId=500, coords={ x=49.67, y=58.73 }, npc = { name="Marshal Redpath" }, note="Marshal Redpath in Southshore (49.67, 58.73)" },
    { type="TURNIN", title="Further Mysteries", questId=525, coords={ x=48.12, y=59.06 }, npc = { name="Magistrate Henry Maleb" }, note="Magistrate Henry Maleb in Southshore (48.12, 59.06)" },
    { type="ACCEPT", title="Dark Council", questId=537, coords={ x=48.17, y=59.17 }, npc = { name="Magistrate Henry Maleb" }, note="Magistrate Henry Maleb in Southshore (48.17, 59.17)" },
    { type="ACCEPT", title="Noble Deaths", questId=512, coords={ x=48.14, y=59.13 }, npc = { name="Magistrate Henry Maleb" }, note="Magistrate Henry Maleb in Southshore (48.14, 59.13)" },
    { type="SET_HEARTH", title="Noble Deaths", coords={ x=51.16, y=58.95 }, npc = { name="Innkeeper Anderson" }, note="Speak to Innkeeper Anderson and set hearth at Southshore (51.16, 58.95)" },
    { type="TRAVEL", coords={ x=48.82, y=54.87 }, note="Travel to Gallows' Corner (48.82, 54.87)" },
    { type="COMPLETE", title="Crushridge Bounty", questId=500, coords={ x=48.82, y=54.87 }, note="Kill Crushridge Ogre and collect 9 Dirty Knucklebones in Gallows' Corner (48.82, 54.87)" },
    { type="TRAVEL", coords={ x=47.67, y=18.58 }, note="Travel to The Uplands (47.67, 18.58)" },
    { type="NOTE", note="Collect 7 Alterac Signet Ring from any Syndicate enemies" },
    { type="COMPLETE", title="Noble Deaths", questId=512, coords={ x=58.43, y=30.95 }, note="Kill 4 Argus Shadow Mage in The Uplands, you will only find one in each camp in The Uplands (58.43, 30.95) (55.43, 27.03) (52.97, 20.91) (47.67, 18.58)" },
    { type="COMPLETE", title="Dark Council", questId=537, coords={ x=39.34, y=15.01 }, note="Kill Nagaz inside the house and collect Head of Nagaz in Dandred's Fold (39.34, 15.01)" },
    { type="NOTE", note="Collect Ensorcelled Parchment from the chest in Dandred's Fold (39.21, 14.66)", coords={ x=39.21, y=14.66 } },
    { type="ACCEPT", title="The Ensorcelled Parchment", questId=551, note="Use Ensorcelled Parchment to accept quest" },
    { type="COMPLETE", title="Noble Deaths", questId=512, coords={ x=47.67, y=18.58 }, note="Collect 7 Alterac Signet Ring from any Syndicate enemies (47.67, 18.58)" },
    { type="TRAVEL", coords={ x=49.67, y=58.73 }, note="Travel or Hearthstone to Southshore (49.67, 58.73)" },
    { type="TURNIN", title="The Ensorcelled Parchment", questId=551, coords={ x=50.56, y=57.13 }, npc = { name="Loremaster Dibbs" }, note="Loremaster Dibbs in Southshore (50.56, 57.13)" },
    { type="ACCEPT", title="Stormpike's Deciphering", questId=554, coords={ x=50.56, y=57.13 }, npc = { name="Loremaster Dibbs" }, note="Loremaster Dibbs in Southshore (50.56, 57.13)" },
    { type="TURNIN", title="Crushridge Bounty", questId=500, coords={ x=49.67, y=58.73 }, npc = { name="Marshal Redpath" }, note="Marshal Redpath in Southshore (49.67, 58.73)" },
    { type="TURNIN", title="Noble Deaths", questId=512, coords={ x=48.15, y=59.12 }, npc = { name="Magistrate Henry Maleb" }, note="Magistrate Henry Maleb in Southshore (48.15, 59.12)" },
    { type="TURNIN", title="Dark Council", questId=537, coords={ x=48.15, y=59.12 }, npc = { name="Magistrate Henry Maleb" }, note="Magistrate Henry Maleb in Southshore (48.15, 59.12)" },
    { type="NOTE", note="Tick to continue to the next guide" },
  }
}
