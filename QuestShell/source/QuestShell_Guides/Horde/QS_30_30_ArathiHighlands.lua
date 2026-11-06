-- =========================
-- QS_Arathi_Highlands_30_30.lua
-- Converted from TourGuide format on 2025-08-17 18:59:06
-- =========================

QuestShellGuides = QuestShellGuides or {}

QuestShellGuides["QS_Arathi_Highlands_30_30"] = {
  title    = "Arathi Highlands (30-30)",
  next     = "Stranglethorn (30-31)",
  nextKey  = "QS_Stranglethorn_30_31",
  faction  = "Horde",
  minLevel = 30,
  maxLevel = 30,
  steps = {
    { type="ACCEPT", class="Shaman", race="Tauren", title="Call of Air", questId=1532, coords={ x=25.2, y=20.65 }, npc = { name="Xanis Flameweaver" }, note="Xanis Flameweaver in Spirit Rise (25.20, 20.65)" },
    { type="ACCEPT", class="Shaman", title="Call of Air", questId=1531, coords={ x=38.0, y=37.7 }, npc = { name="Searn Firewarder" }, note="Searn Firewarder in Grommash Hold (38.00, 37.70)" },
    { type="TURNIN", class="Shaman", title="Call of Air", questId=1532, coords={ x=54.62, y=44.97 }, npc = { name="Prate Cloudseer" }, note="Prate Cloudseer in The Weathered Nook (54.62, 44.97) (53.53, 42.66)" },
    { type="TURNIN", class="Shaman", title="Call of Air", questId=1531, coords={ x=54.62, y=44.97 }, npc = { name="Prate Cloudseer" }, note="Prate Cloudseer in The Weathered Nook (54.62, 44.97) (53.53, 42.66)" },
    { type="TRAVEL", class="Warrior", coords={ x=80.2, y=32.4 }, note="Travel to Orgrimmar (80.2, 32.4)" },
    { type="ACCEPT", class="Warrior", title="The Islander", questId=1718, coords={ x=80.2, y=32.4 }, npc = { name="Sorek" }, note="Sorek in Orgrimmar, This is a Level 30 quest for (spell:2458) (80.2, 32.4)" },
    { type="TRAVEL", class="Warrior", coords={ x=68.6, y=49.1 }, note="Travel to Fray Island (68.6, 49.1)" },
    { type="TURNIN", class="Warrior", title="The Islander", questId=1718, coords={ x=68.6, y=49.1 }, npc = { name="Klannoc Macleod" }, note="Klannoc Macleod in Fray Island (68.6, 49.1)" },
    { type="ACCEPT", class="Warrior", title="The Affray", questId=1719, coords={ x=68.6, y=49.1 }, npc = { name="Klannoc Macleod" }, note="Klannoc Macleod in Fray Island (68.6, 49.1)" },
    { type="COMPLETE", class="Warrior", title="The Affray", questId=1719, coords={ x=68.6, y=48.7 }, note="Kill the series of Mobs, bandage and eat in between Mobs. As for Big Will, you're given the privilege to attack him first because he's neutral, so just run back and (spell:100) then use your (spell:20230) for Big Will (68.6, 48.7)" },
    { type="TURNIN", class="Warrior", title="The Affray", questId=1719, coords={ x=68.6, y=49.1 }, npc = { name="Klannoc Macleod" }, note="Klannoc Macleod in Fray Island (68.6, 49.1)" },
    { type="TRAVEL", class="Warlock", coords={ x=62.6, y=35.5 }, note="Travel to Ratchet (62.6, 35.5)" },
    { type="ACCEPT", class="Warlock", title="Tome of Cabal", questId=1801, coords={ x=62.6, y=35.5 }, npc = { name="Strahad Farsan" }, note="Strahad Farsan in Ratchet, this is a Level 30 quest to summon Summoned Felhunter make sure you get this (62.6, 35.5)" },
    { type="TRAVEL", class="Warlock", coords={ x=77.0, y=35.6 }, note="Travel to Undercity (77, 35.6)" },
    { type="TURNIN", class="Warlock", title="Tome of Cabal", questId=1801, coords={ x=77.0, y=35.6 }, npc = { name="Jorah Annison" }, note="Jorah Annison in Undercity (77, 35.6)" },
    { type="ACCEPT", class="Warlock", title="Tome of Cabal", questId=1803, coords={ x=77.0, y=35.6 }, npc = { name="Jorah Annison" }, note="Jorah Annison in Undercity (77, 35.6)" },
    { type="NOTE", class="Warlock", note="Pick up the Moldy Tome from Tome of the Cabal (27.7, 72.8)", coords={ x=27.7, y=72.8 } },
    { type="COMPLETE", class="Warlock", title="Tome of Cabal", questId=1803, coords={ x=43.5, y=32.7 }, note="Get the Tattered Manuscript from the Damaged Chest inside the centaur cave (43.5, 32.7)" },
    { type="TRAVEL", class="Warlock", coords={ x=77.0, y=35.6 }, note="Travel to Undercity (77, 35.6)" },
    { type="TURNIN", class="Warlock", title="Tome of Cabal", questId=1803, coords={ x=77.0, y=35.6 }, npc = { name="Jorah Annison" }, note="Jorah Annison in Undercity (77, 35.6)" },
    { type="ACCEPT", class="Warlock", title="Tome of Cabal", questId=1805, coords={ x=77.0, y=35.6 }, npc = { name="Jorah Annison" }, note="Jorah Annison in Undercity (77, 35.6)" },
    { type="COMPLETE", class="Warlock", title="Tome of Cabal", questId=1805, note="Kill Dragonmaw Bonewarder and Dragonmaw Shadowwarder to collect 3 Rod of Channeling (49.7.4, 46.6)" },
    { type="TRAVEL", class="Warlock", coords={ x=62.6, y=35.5 }, note="Travel to Ratchet (62.6, 35.5)" },
    { type="TURNIN", class="Warlock", title="Tome of Cabal", questId=1805, coords={ x=62.6, y=35.5 }, npc = { name="Strahad Farsan" }, note="Strahad Farsan in Ratchet (62.6, 35.5)" },
    { type="ACCEPT", class="Warlock", title="The Binding", questId=1795, coords={ x=62.6, y=35.5 }, npc = { name="Strahad Farsan" }, note="Strahad Farsan in Ratchet (62.6, 35.5)" },
    { type="COMPLETE", class="Warlock", title="The Binding", questId=1795, itemId=6999, coords={ x=62.6, y=35.5 }, note="Use Tome of the Cabal to summon the Summoned Felhunter and kill it (62.6, 35.5)" },
    { type="TURNIN", class="Warlock", title="The Binding", questId=1795, coords={ x=62.6, y=35.5 }, npc = { name="Strahad Farsan" }, note="Strahad Farsan in Ratchet (62.6, 35.5)" },
    { type="TRAVEL", coords={ x=30.77, y=51.66 }, note="Travel to Hammerfall in Arathi Highlands (30.77, 51.66) (45.49, 59.00) (51.73, 57.86) (72.98, 43.35)" },
    { type="ACCEPT", title="Hammerfall", questId=655, coords={ x=72.68, y=34.04 }, npc = { name="Gor'mul" }, note="Gor'mul in Hammerfall (72.68, 34.04)" },
    { type="TURNIN", title="Hammerfall", questId=655, coords={ x=74.65, y=36.32 }, npc = { name="Tor'gan" }, note="Tor'gan in Hammerfall (74.65, 36.32)" },
    { type="ACCEPT", title="Raising Spirits", questId=672, coords={ x=74.65, y=36.32 }, npc = { name="Tor'gan" }, note="Tor'gan in Hammerfall (74.65, 36.32)" },
    { type="FLIGHTPATH", npc = { name="Urda" }, coords={ x=73.1, y=32.7 }, note="Speak to Urda and grab flight path for (Hammerfall (73.1, 32.7)" },
    { type="COMPLETE", title="Raising Spirits", questId=672, coords={ x=53.36, y=44.56 }, note="Kill Highland Strider and collect 10 Highland Raptor Eye west of Hammerfall (53.36, 44.56) (64, 37)" },
    { type="TURNIN", title="Raising Spirits", questId=672, coords={ x=74.65, y=36.32 }, npc = { name="Tor'gan" }, note="Tor'gan in Hammerfall (74.65, 36.32)" },
    { type="ACCEPT", title="Raising Spirits", questId=674, coords={ x=74.65, y=36.32 }, npc = { name="Tor'gan" }, note="Tor'gan in Hammerfall (74.65, 36.32)" },
    { type="TURNIN", title="Raising Spirits", questId=674, coords={ x=72.68, y=34.04 }, npc = { name="Gor'mul" }, note="Gor'mul in Hammerfall (72.68, 34.04)" },
    { type="ACCEPT", title="Raising Spirits", questId=675, coords={ x=72.68, y=34.04 }, npc = { name="Gor'mul" }, note="Gor'mul in Hammerfall (72.68, 34.04)" },
    { type="TURNIN", title="Raising Spirits", questId=675, coords={ x=74.65, y=36.34 }, npc = { name="Tor'gan" }, note="Tor'gan in Hammerfall, skip follow (74.65, 36.34)" },
    { type="NOTE", note="Tick to continue to the next guide" },
  }
}
