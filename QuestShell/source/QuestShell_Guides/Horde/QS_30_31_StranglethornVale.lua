-- =========================
-- QS_Stranglethorn_30_31.lua
-- Converted from TourGuide format on 2025-08-17 18:59:06
-- =========================

QuestShellGuides = QuestShellGuides or {}

QuestShellGuides["QS_Stranglethorn_30_31"] = {
  title    = "Stranglethorn (30-31)",
  next     = "Thousand Needles (31-32)",
  nextKey  = "QS_Thousand_Needles_31_32",
  faction  = "Horde",
  minLevel = 30,
  maxLevel = 31,
  steps = {
    { type="ACCEPT", class="Shaman", race="Tauren", title="Call of Air", questId=1532, coords={ x=25.2, y=20.65 }, npc = { name="Xanis Flameweaver" }, note="Xanis Flameweaver in Spirit Rise (25.20, 20.65)" },
    { type="ACCEPT", class="Shaman", title="Call of Air", questId=1531, coords={ x=38.0, y=37.7 }, npc = { name="Searn Firewarder" }, note="Searn Firewarder in Grommash Hold (38.00, 37.70)" },
    { type="TURNIN", class="Shaman", title="Call of Air", questId=1532, coords={ x=54.62, y=44.97 }, npc = { name="Prate Cloudseer" }, note="Prate Cloudseer in The Weathered Nook (54.62, 44.97) (53.53, 42.66)" },
    { type="TURNIN", class="Shaman", title="Call of Air", questId=1531, coords={ x=54.62, y=44.97 }, npc = { name="Prate Cloudseer" }, note="Prate Cloudseer in The Weathered Nook (54.62, 44.97) (53.53, 42.66)" },
    { type="TRAVEL", coords={ x=32.5, y=29.3 }, note="Travel to Grom'gol Base Camp (32.5, 29.3)" },
    { type="FLIGHTPATH", npc = { name="Thysta" }, coords={ x=32.5, y=29.3 }, note="Speak to Thysta and grab flight path for Grom'gol Base Camp (32.5, 29.3)" },
    { type="TRAVEL", coords={ x=35.0, y=10.0 }, note="Follow the road north, look for a little camp by the river (35, 10)" },
    { type="ACCEPT", title="Welcome to the Jungle", questId=583, coords={ x=35.68, y=10.52 }, npc = { name="Barnil Stonepot" }, note="Barnil Stonepot in Nesingwary's Expedition (35.68, 10.52)" },
    { type="TURNIN", title="Welcome to the Jungle", questId=583, coords={ x=35.65, y=10.75 }, npc = { name="Hemet Nesingwary" }, note="Hemet Nesingwary in Nesingwary's Expedition (35.65, 10.75)" },
    { type="ACCEPT", title="Tiger Mastery", questId=185, coords={ x=35.59, y=10.64 }, npc = { name="Ajeck Rouack" }, note="Ajeck Rouack in Nesingwary's Expedition (35.59, 10.64)" },
    { type="ACCEPT", title="Panther Mastery", questId=190, coords={ x=35.56, y=10.57 }, npc = { name="Erlgadin" }, note="Sir S. J. Erlgadin in Nesingwary's Expedition (35.56, 10.57)" },
    { type="ACCEPT", title="Raptor Mastery", questId=194, coords={ x=35.65, y=10.75 }, npc = { name="Hemet Nesingwary" }, note="Hemet Nesingwary in Nesingwary's Expedition (35.65, 10.75)" },
    { type="COMPLETE", title="Tiger Mastery", questId=185, coords={ x=35.0, y=14.0 }, note="Kill 10 Young Stranglethorn Tiger slightly to the east in Stranglethorn Vale (35, 14)" },
    { type="COMPLETE", title="Panther Mastery", questId=190, coords={ x=41.0, y=9.0 }, note="Kill 10 Young Panther to the north in Stranglethorn Vale (41, 9)" },
    { type="TURNIN", title="Tiger Mastery", questId=185, coords={ x=35.59, y=10.64 }, npc = { name="Ajeck Rouack" }, note="Ajeck Rouack in Nesingwary's Expedition (35.59, 10.64)" },
    { type="ACCEPT", title="Tiger Mastery", questId=186, coords={ x=35.59, y=10.64 }, npc = { name="Ajeck Rouack" }, note="Ajeck Rouack in Nesingwary's Expedition (35.59, 10.64)" },
    { type="TURNIN", title="Panther Mastery", questId=190, coords={ x=35.56, y=10.57 }, npc = { name="Erlgadin" }, note="Sir S. J. Erlgadin in Nesingwary's Expedition (35.56, 10.57)" },
    { type="ACCEPT", title="Panther Mastery", questId=191, coords={ x=35.56, y=10.57 }, npc = { name="Erlgadin" }, note="Sir S. J. Erlgadin in Nesingwary's Expedition (35.56, 10.57)" },
    { type="COMPLETE", title="Tiger Mastery", questId=186, coords={ x=30.0, y=15.0 }, note="Kill 10 Stranglethorn Tiger east of the camp in Stranglethorn Vale (30, 15)" },
    { type="COMPLETE", title="Panther Mastery", questId=191, coords={ x=29.0, y=11.0 }, note="Kill 10 Panther east of the camp in Stranglethorn Vale (29, 11)" },
    { type="COMPLETE", title="Raptor Mastery", questId=194, coords={ x=28.0, y=14.0 }, note="Kill 10 Stranglethorn Raptor east near the ruins in Stranglethorn Vale (28, 14)" },
    { type="TURNIN", title="Tiger Mastery", questId=186, coords={ x=35.59, y=10.64 }, npc = { name="Ajeck Rouack" }, note="Ajeck Rouack in Nesingwary's Expedition (35.59, 10.64)" },
    { type="ACCEPT", title="Tiger Mastery", questId=187, coords={ x=35.59, y=10.64 }, npc = { name="Ajeck Rouack" }, note="Ajeck Rouack in Nesingwary's Expedition (35.59, 10.64)" },
    { type="TURNIN", title="Raptor Mastery", questId=194, coords={ x=35.65, y=10.75 }, npc = { name="Hemet Nesingwary" }, note="Hemet Nesingwary in Nesingwary's Expedition (35.65, 10.75)" },
    { type="ACCEPT", title="Raptor Mastery", questId=195, coords={ x=35.65, y=10.75 }, npc = { name="Hemet Nesingwary" }, note="Hemet Nesingwary in Nesingwary's Expedition (35.65, 10.75)" },
    { type="TURNIN", title="Panther Mastery", questId=191, coords={ x=35.56, y=10.57 }, npc = { name="Erlgadin" }, note="Sir S. J. Erlgadin in Nesingwary's Expedition (35.56, 10.57)" },
    { type="NOTE", note="Tick to continue to the next guide" },
  }
}
