-- pfQuest SmartArrow
-- Copyright (C) 2026 pfQuest SmartArrow contributors
--
-- This program is free software: you can redistribute it and/or modify it
-- under the terms of the GNU General Public License as published by the Free
-- Software Foundation, either version 3 of the License, or (at your option)
-- any later version. It is distributed WITHOUT ANY WARRANTY; see LICENSE.md.

-- pfQuest SmartArrow travel data
--
-- Everything here is expressed as zone-map percent coordinates on a pfQuest /
-- AreaTable zone id and is turned into world coordinates at runtime through
-- pfMap:GetWorldPos, so the numbers stay readable and easy to fix by hand.
--
-- connectors: places where you can walk from one zone into another (roads,
--   passes, tunnels, city gates). `zone` is the map the x/y are measured on,
--   `links` the two zones the connector joins. The route planner only lets you
--   walk "freely" between points that share a zone, so connectors are what
--   keep the arrow from pointing straight through a mountain range.
--   Coordinates are approximate on purpose: the arrow treats a connector as
--   reached within ~60 yards. Borders you actually walk through are learned
--   automatically and stored in pfQuestSmartArrow_config.learned, so the data
--   tightens up as you play. Every connector was checked to lie inside the
--   world rectangles (WorldMapArea.dbc) of both zones it joins.
--
-- transports: boats, zeppelins, the tram and portals. `time` is a rough
--   door-to-door cost in seconds including the average wait. `faction` is
--   "A", "H" or nil for everyone. Each end has a `name` (where you board) and
--   an optional `town` (what you call it when you arrive there).

pfQuestSmartArrowData = pfQuestSmartArrowData or {}

-- zone ids used below (AreaTable)
local ELWYNN, WESTFALL, DUSKWOOD, REDRIDGE, STV = 12, 40, 10, 44, 33
local DEADWIND, SWAMP, BLASTED, BURNING, SEARING = 41, 8, 4, 46, 51
local DUNMOROGH, LOCH, WETLANDS, ARATHI, HILLSBRAD = 1, 38, 11, 45, 267
local ALTERAC, SILVERPINE, TIRISFAL, WPL, EPL = 36, 130, 85, 28, 139
local HINTERLANDS, BADLANDS = 47, 3
local STORMWIND, IRONFORGE, UNDERCITY = 1519, 1537, 1497

local DUROTAR, BARRENS, MULGORE, ASHENVALE, STONETALON = 14, 17, 215, 331, 406
local DESOLACE, FERALAS, NEEDLES, TANARIS, UNGORO = 405, 357, 400, 440, 490
local SILITHUS, DUSTWALLOW, AZSHARA, FELWOOD, WINTERSPRING = 1377, 15, 16, 361, 618
local MOONGLADE, DARKSHORE, TELDRASSIL = 493, 148, 141
local ORGRIMMAR, THUNDERBLUFF, DARNASSUS = 1637, 1638, 1657

pfQuestSmartArrowData.connectors = {
  -- Eastern Kingdoms -------------------------------------------------------
  { name = "Stormwind Gates",        zone = ELWYNN,     x = 32.0, y = 49.5, links = { ELWYNN, STORMWIND } },
  { name = "Westfall Bridge",        zone = ELWYNN,     x = 21.0, y = 79.0, links = { ELWYNN, WESTFALL } },
  { name = "Three Corners",          zone = REDRIDGE,   x = 16.0, y = 71.0, links = { ELWYNN, REDRIDGE } },
  { name = "Three Corners",          zone = DUSKWOOD,   x = 96.0, y = 5.0,  links = { DUSKWOOD, REDRIDGE } },
  { name = "Elwynn Road",            zone = DUSKWOOD,   x = 78.0, y = 20.0, links = { ELWYNN, DUSKWOOD } },
  { name = "Westfall Road",          zone = DUSKWOOD,   x = 8.0,  y = 66.0, links = { WESTFALL, DUSKWOOD } },
  { name = "Rebel Camp Road",        zone = DUSKWOOD,   x = 44.6, y = 87.6, links = { DUSKWOOD, STV } },
  { name = "Deadwind Pass",          zone = DUSKWOOD,   x = 90.0, y = 40.0, links = { DUSKWOOD, DEADWIND } },
  { name = "Deadwind Road",          zone = SWAMP,      x = 4.0,  y = 60.0, links = { DEADWIND, SWAMP } },
  { name = "Nethergarde Road",       zone = BLASTED,    x = 60.0, y = 12.0, links = { SWAMP, BLASTED } },
  { name = "Morgan's Vigil Pass",    zone = REDRIDGE,   x = 47.0, y = 3.0,  links = { REDRIDGE, BURNING } },
  { name = "Blackrock Mountain",     zone = BURNING,    x = 24.0, y = 30.0, links = { BURNING, SEARING } },
  { name = "Ironforge Gates",        zone = DUNMOROGH,  x = 53.0, y = 35.0, links = { DUNMOROGH, IRONFORGE } },
  { name = "South Gate Pass",        zone = DUNMOROGH,  x = 84.5, y = 50.0, links = { DUNMOROGH, LOCH } },
  { name = "Badlands Road",          zone = BADLANDS,   x = 46.0, y = 10.0, links = { LOCH, BADLANDS } },
  { name = "Dun Algaz",              zone = LOCH,       x = 25.5, y = 11.0, links = { LOCH, WETLANDS } },
  { name = "Thandol Span",           zone = ARATHI,     x = 44.0, y = 90.0, links = { WETLANDS, ARATHI } },
  { name = "Arathi Road",            zone = ARATHI,     x = 17.0, y = 34.0, links = { ARATHI, HILLSBRAD } },
  { name = "Hinterlands Road",       zone = HINTERLANDS, x = 8.0, y = 59.0, links = { HILLSBRAD, HINTERLANDS } },
  { name = "Alterac Road",           zone = HILLSBRAD,  x = 55.0, y = 24.0, links = { HILLSBRAD, ALTERAC } },
  { name = "Greymane Wall Road",     zone = SILVERPINE, x = 61.0, y = 78.0, links = { SILVERPINE, HILLSBRAD } },
  { name = "Tirisfal Road",          zone = SILVERPINE, x = 67.0, y = 6.0,  links = { SILVERPINE, TIRISFAL } },
  { name = "Ruins of Lordaeron",     zone = TIRISFAL,   x = 61.8, y = 65.0, links = { TIRISFAL, UNDERCITY } },
  { name = "The Bulwark",            zone = TIRISFAL,   x = 85.0, y = 70.0, links = { TIRISFAL, WPL } },
  { name = "Thondroril River",       zone = WPL,        x = 70.0, y = 50.0, links = { WPL, EPL } },

  -- Kalimdor ---------------------------------------------------------------
  { name = "Orgrimmar Gates",        zone = DUROTAR,    x = 45.5, y = 12.0, links = { DUROTAR, ORGRIMMAR } },
  { name = "Orgrimmar West Gate",    zone = ORGRIMMAR,  x = 15.7, y = 63.3, links = { ORGRIMMAR, BARRENS } },
  { name = "Southfury Bridge",       zone = DUROTAR,    x = 35.0, y = 42.0, links = { DUROTAR, BARRENS } },
  { name = "Golden Plains",          zone = MULGORE,    x = 69.6, y = 60.4, links = { BARRENS, MULGORE } },
  { name = "Thunder Bluff Lifts",    zone = MULGORE,    x = 37.0, y = 31.0, links = { MULGORE, THUNDERBLUFF } },
  { name = "Mor'shan Rampart",       zone = BARRENS,    x = 47.0, y = 6.0,  links = { BARRENS, ASHENVALE } },
  { name = "Stonetalon Road",        zone = BARRENS,    x = 34.0, y = 27.0, links = { BARRENS, STONETALON } },
  { name = "The Great Lift",         zone = BARRENS,    x = 44.5, y = 92.0, links = { BARRENS, NEEDLES } },
  { name = "Shady Rest Road",        zone = DUSTWALLOW, x = 29.0, y = 47.0, links = { BARRENS, DUSTWALLOW } },
  { name = "Darkshore Road",         zone = DARKSHORE,  x = 43.0, y = 92.0, links = { ASHENVALE, DARKSHORE } },
  { name = "Stonetalon Pass",        zone = ASHENVALE,  x = 42.0, y = 71.0, links = { ASHENVALE, STONETALON } },
  { name = "Felwood Road",           zone = ASHENVALE,  x = 55.0, y = 29.0, links = { ASHENVALE, FELWOOD } },
  { name = "Azshara Road",           zone = AZSHARA,    x = 11.0, y = 77.0, links = { ASHENVALE, AZSHARA } },
  { name = "Timbermaw Hold",         zone = FELWOOD,    x = 65.0, y = 5.0,  links = { FELWOOD, WINTERSPRING } },
  { name = "Timbermaw Hold (north)", zone = FELWOOD,    x = 63.0, y = 3.0,  links = { FELWOOD, MOONGLADE } },
  { name = "Desolace Road",          zone = STONETALON, x = 29.3, y = 79.7, links = { STONETALON, DESOLACE } },
  { name = "Feralas Road",           zone = DESOLACE,   x = 40.0, y = 94.0, links = { DESOLACE, FERALAS } },
  { name = "Thousand Needles Road",  zone = NEEDLES,    x = 10.0, y = 37.0, links = { FERALAS, NEEDLES } },
  { name = "Shimmering Flats Road",  zone = NEEDLES,    x = 73.0, y = 95.0, links = { NEEDLES, TANARIS } },
  { name = "Un'Goro Slope",          zone = TANARIS,    x = 27.0, y = 57.0, links = { TANARIS, UNGORO } },
  { name = "Silithus Pass",          zone = UNGORO,     x = 27.0, y = 13.0, links = { UNGORO, SILITHUS } },
  { name = "Darnassus Gates",        zone = TELDRASSIL, x = 34.0, y = 51.0, links = { TELDRASSIL, DARNASSUS } },
}

pfQuestSmartArrowData.transports = {
  { kind = "boat", faction = "A", time = 150,
    a = { zone = WETLANDS,   x = 4.5,  y = 57.0, name = "Menethil Harbor" },
    b = { zone = DUSTWALLOW, x = 71.5, y = 56.5, name = "Theramore" } },
  { kind = "boat", faction = "A", time = 150,
    a = { zone = WETLANDS,   x = 4.5,  y = 62.0, name = "Menethil Harbor" },
    b = { zone = DARKSHORE,  x = 32.5, y = 46.0, name = "Auberdine" } },
  { kind = "boat", faction = "A", time = 110,
    a = { zone = DARKSHORE,  x = 33.0, y = 40.0, name = "Auberdine" },
    b = { zone = TELDRASSIL, x = 55.0, y = 97.0, name = "Rut'theran Village" } },
  { kind = "boat", faction = nil, time = 150,
    a = { zone = STV,        x = 26.0, y = 73.0, name = "Booty Bay" },
    b = { zone = BARRENS,    x = 63.5, y = 38.5, name = "Ratchet" } },
  { kind = "zeppelin", faction = "H", time = 150,
    a = { zone = DUROTAR,    x = 50.5, y = 12.5, name = "Orgrimmar zeppelin tower", town = "Orgrimmar" },
    b = { zone = TIRISFAL,   x = 60.5, y = 58.5, name = "Undercity zeppelin tower", town = "Undercity" } },
  { kind = "zeppelin", faction = "H", time = 150,
    a = { zone = DUROTAR,    x = 50.5, y = 13.5, name = "Orgrimmar zeppelin tower", town = "Orgrimmar" },
    b = { zone = STV,        x = 31.5, y = 29.5, name = "Grom'gol" } },
  { kind = "zeppelin", faction = "H", time = 150,
    a = { zone = TIRISFAL,   x = 61.5, y = 59.0, name = "Undercity zeppelin tower", town = "Undercity" },
    b = { zone = STV,        x = 31.5, y = 30.0, name = "Grom'gol" } },
  { kind = "tram", faction = "A", time = 90,
    a = { zone = STORMWIND,  x = 63.7, y = 8.4,  name = "Deeprun Tram", town = "Stormwind" },
    b = { zone = IRONFORGE,  x = 76.0, y = 51.0, name = "Deeprun Tram", town = "Ironforge" } },
  { kind = "portal", faction = nil, time = 10,
    a = { zone = TELDRASSIL, x = 56.0, y = 89.5, name = "portal to Darnassus", town = "Rut'theran Village" },
    b = { zone = DARNASSUS,  x = 29.5, y = 41.4, name = "portal to Rut'theran", town = "Darnassus" } },
}
