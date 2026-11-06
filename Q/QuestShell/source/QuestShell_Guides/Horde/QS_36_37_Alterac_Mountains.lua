-- =========================
-- QS_Alterac_Mountains_36_37.lua
-- Converted from TourGuide format on 2025-08-17 18:59:06
-- =========================

QuestShellGuides = QuestShellGuides or {}

QuestShellGuides["QS_Alterac_Mountains_36_37"] = {
  title    = "Alterac Mountains (36-37)",
  next     = "Arathi Highlands (37-38)",
  nextKey  = "QS_Arathi_Highlands_37_38",
  faction  = "Horde",
  minLevel = 36,
  maxLevel = 37,
  steps = {
    { type="TRAVEL", coords={ x=61.59, y=20.71 }, note="Travel to Tarren Mill (61.59, 20.71)" },
    { type="ACCEPT", title="Prison Break In", questId=544, coords={ x=61.59, y=20.71 }, npc = { name="Magus Wordeen Voidglare" }, note="Magus Wordeen Voidglare in Tarren Mill (61.59, 20.71)" },
    { type="ACCEPT", title="Stone Tokens", questId=556, coords={ x=61.59, y=20.71 }, npc = { name="Keeper Bel'varil" }, note="Keeper Bel'varil in Tarren Mill (61.59, 20.71)" },
    { type="TRAVEL", coords={ x=37.54, y=67.91 }, note="Travel to Growless Cave (37.54, 67.91)" },
    { type="NOTE", note="Click Item Flame of Uzel in Growless Cave (37.54, 66.38)", coords={ x=37.54, y=66.38 } },
    { type="COMPLETE", title="Frostmaw", questId=1136, coords={ x=37.59, y=65.84 }, note="Kill Frostmaw and collect Frostmaw's Mane in Growless Cave (37.59, 65.84)" },
    { type="TRAVEL", coords={ x=20.33, y=84.79 }, note="Travel to in Dalaran (20.33, 84.79)" },
    { type="COMPLETE", title="Stone Tokens", questId=556, coords={ x=21.0, y=83.0 }, note="Kill Dalaran humanoid enemies and collect 10 Worn Stone Token in Dalaran (21, 83)" },
    { type="COMPLETE", title="Ricter", questId=544, coords={ x=19.69, y=82.48 }, note="Kill Ricter and collect Bloodstone Marble in Lordamere Internment Camp (19.69, 82.48) | Kill Alina and collect Bloodstone Shard in Lordamere Internment Camp (20.22, 86.26) | Kill Dermot and collect Bloodstone Wedge in Lordamere Internment Camp (20.20, 86.24) | Kill Kegan Darkmar and collect Bloodstone Oval in Lordamere Internment Camp (18.19, 83.59)" },
    { type="TURNIN", title="Helcular's Revenge", questId=553, coords={ x=52.74, y=53.26 }, npc = { name="Vile Fin Shredder" }, note="Vile Fin Shredder in Southshore (52.74, 53.26)" },
    { type="TRAVEL", coords={ x=61.59, y=20.71 }, note="Travel to Tarren Mill (61.59, 20.71)" },
    { type="TURNIN", title="Prison Break In", questId=544, coords={ x=61.59, y=20.71 }, npc = { name="Magus Wordeen Voidglare" }, note="Magus Wordeen Voidglare in Tarren Mill (61.59, 20.71)" },
    { type="ACCEPT", title="Dalaran Patrols", questId=545, coords={ x=61.59, y=20.85 }, npc = { name="Magus Wordeen Voidglare" }, note="Magus Wordeen Voidglare in Tarren Mill (61.59, 20.85)" },
    { type="TURNIN", title="Stone Tokens", questId=556, coords={ x=61.59, y=20.71 }, npc = { name="Keeper Bel'varil" }, note="Keeper Bel'varil in Tarren Mill (61.59, 20.71)" },
    { type="ACCEPT", title="Bracers of Binding", questId=557, coords={ x=61.54, y=20.93 }, npc = { name="Keeper Bel'varil" }, note="Keeper Bel'varil in Tarren Mill (61.54, 20.93)" },
    { type="COMPLETE", title="Bracers of Binding", questId=557, coords={ x=11.98, y=79.25 }, note="Kill Elemental Slave and collect 4 Bracers of Earth Binding in Dalaran (11.98, 79.25)" },
    { type="COMPLETE", title="Dalaran Patrols", questId=545, coords={ x=19.94, y=74.0 }, note="Kill 6 Dalaran Summoner and 12 Elemental Slave in Dalaran (19.94, 74.00)" },
    { type="TRAVEL", coords={ x=61.58, y=20.8 }, note="Travel to Tarren Mill. You can die on purpose and ressurect at Tarren Mill (61.58, 20.80)" },
    { type="TURNIN", title="Dalaran Patrols", questId=545, coords={ x=61.58, y=20.8 }, npc = { name="Magus Wordeen Voidglare" }, note="Magus Wordeen Voidglare in Tarren Mill (61.58, 20.80)" },
    { type="TURNIN", title="Bracers of Binding", questId=557, coords={ x=61.51, y=20.86 }, npc = { name="Keeper Bel'varil" }, note="Keeper Bel'varil in Tarren Mill (61.51, 20.86)" },
    { type="NOTE", note="Tick to continue to the next guide" },
  }
}
