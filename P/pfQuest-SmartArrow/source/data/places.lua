-- pfQuest SmartArrow
-- Copyright (C) 2026 pfQuest SmartArrow contributors
--
-- This program is free software: you can redistribute it and/or modify it
-- under the terms of the GNU General Public License as published by the Free
-- Software Foundation, either version 3 of the License, or (at your option)
-- any later version. It is distributed WITHOUT ANY WARRANTY; see LICENSE.md.

-- pfQuest SmartArrow: well-known special places
--
-- Labels only. An objective within `r` (zone map percent) of a place gets a
-- note like "Objective is down in the mine: Fargodeep Mine". These never move
-- the arrow; the entrance waypoint comes from places you have actually walked
-- into (learned, see places.lua), and once a place is learned its measured
-- extent replaces the circle below.
--
-- Positions are taken from VanillaGuide's step coordinates (Joana's guide),
-- where a step sends you into a cave, mine, crypt or to the top of a tower,
-- checked against each other across the Alliance and Horde guides. Where the
-- guide names the place, `name` is that name (it should match the sub-zone
-- the minimap shows inside, so a shipped entry and a learned one pair up);
-- otherwise the note just says what kind of place it is.
--
-- kind: cave | mine | crypt | building | tower | upstairs

pfQuestSmartArrowData = pfQuestSmartArrowData or {}

local ELWYNN, DUNMOROGH, LOCH, WETLANDS, REDRIDGE, DUSKWOOD = 12, 1, 38, 11, 44, 10
local STV, ARATHI, SEARING, BURNING, WPL, EPL, HINTERLANDS = 33, 45, 51, 46, 28, 139, 47
local TIRISFAL = 85
local TELDRASSIL, DARNASSUS, DARKSHORE, DUROTAR, MULGORE, BARRENS = 141, 1657, 148, 14, 215, 17
local STONETALON, NEEDLES, DUSTWALLOW, TANARIS, FERALAS, UNGORO = 406, 400, 15, 440, 357, 490
local FELWOOD, SILITHUS = 361, 1377

pfQuestSmartArrowData.places = {
  -- Eastern Kingdoms
  { zone = ELWYNN,     x = 39, y = 82, r = 2.0, kind = "mine",  name = "Fargodeep Mine" },
  { zone = ELWYNN,     x = 61, y = 52, r = 2.0, kind = "mine",  name = "Jasperlode Mine" },
  { zone = ELWYNN,     x = 47, y = 32, r = 2.0, kind = "mine",  name = "Echo Ridge Mine" },
  { zone = ELWYNN,     x = 65, y = 69.5, r = 1.2, kind = "tower", name = "Tower of Azora" },
  { zone = DUNMOROGH,  x = 26, y = 79, r = 2.0, kind = "cave" },  -- Coldridge Valley troll cave
  { zone = DUNMOROGH,  x = 24, y = 50, r = 2.0, kind = "cave",  name = "Frostmane Hold" },
  { zone = DUNMOROGH,  x = 42, y = 54, r = 1.5, kind = "cave",  name = "Grizzled Den" },
  { zone = DUNMOROGH,  x = 68, y = 55, r = 2.0, kind = "mine",  name = "Gol'Bolar Quarry" },
  { zone = LOCH,       x = 35, y = 18, r = 2.0, kind = "mine",  name = "Silver Stream Mine" },
  { zone = WETLANDS,   x = 38, y = 52, r = 1.5, kind = "cave" },
  { zone = REDRIDGE,   x = 28, y = 12, r = 1.5, kind = "cave" },
  { zone = DUSKWOOD,   x = 73, y = 73, r = 1.5, kind = "cave" },
  { zone = DUSKWOOD,   x = 33, y = 75, r = 2.0, kind = "cave",  name = "Vul'Gol Ogre Mound" },
  { zone = DUSKWOOD,   x = 23, y = 35, r = 1.5, kind = "crypt" },  -- Raven Hill
  { zone = STV,        x = 45, y = 7,  r = 1.5, kind = "cave" },
  { zone = STV,        x = 35, y = 60, r = 1.5, kind = "cave" },
  { zone = ARATHI,     x = 53, y = 77, r = 1.5, kind = "cave" },
  { zone = HINTERLANDS, x = 11, y = 46, r = 1.5, kind = "cave" },  -- Aerie Peak
  { zone = SEARING,    x = 41, y = 25, r = 1.5, kind = "cave" },
  { zone = SEARING,    x = 65, y = 78, r = 1.5, kind = "cave" },
  { zone = BURNING,    x = 65, y = 24, r = 1.5, kind = "cave" },
  { zone = BURNING,    x = 94, y = 31, r = 1.5, kind = "cave" },
  { zone = WPL,        x = 54, y = 79, r = 1.5, kind = "crypt" },  -- Sorrow Hill
  { zone = WPL,        x = 39, y = 68, r = 1.0, kind = "upstairs" }, -- Chillwind Camp inn, top floor
  { zone = EPL,        x = 27, y = 85, r = 1.5, kind = "crypt",  name = "The Undercroft" },
  { zone = EPL,        x = 15, y = 29, r = 2.0, kind = "cave" },
  { zone = TIRISFAL,   x = 27, y = 59, r = 2.0, kind = "cave",  name = "Night Web's Hollow" },

  -- Kalimdor
  { zone = TELDRASSIL, x = 57, y = 32, r = 2.0, kind = "cave",  name = "Shadowthread Cave" },
  { zone = TELDRASSIL, x = 54, y = 52, r = 1.5, kind = "cave",  name = "Fel Rock" },
  { zone = TELDRASSIL, x = 44, y = 57, r = 2.0, kind = "crypt", name = "Ban'ethil Barrow Den" },
  { zone = TELDRASSIL, x = 36, y = 12, r = 1.0, kind = "tower" },
  { zone = DARNASSUS,  x = 34, y = 8.5, r = 1.0, kind = "tower" },
  { zone = DARKSHORE,  x = 54, y = 24, r = 1.2, kind = "tower", name = "Tower of Althalaxx" },
  { zone = DARKSHORE,  x = 45, y = 85, r = 1.5, kind = "cave" },
  { zone = DUROTAR,    x = 44, y = 56, r = 2.0, kind = "cave",  name = "Burning Blade Coven" },
  { zone = DUROTAR,    x = 54, y = 11, r = 1.5, kind = "cave",  name = "Skull Rock" },
  { zone = MULGORE,    x = 61, y = 47, r = 2.0, kind = "mine",  name = "The Venture Co. Mine" },
  { zone = MULGORE,    x = 58, y = 85, r = 1.5, kind = "cave" },
  { zone = BARRENS,    x = 46, y = 36, r = 2.0, kind = "cave",  name = "Wailing Caverns" },
  { zone = STONETALON, x = 74, y = 97, r = 1.5, kind = "cave" },
  { zone = NEEDLES,    x = 52, y = 43, r = 1.5, kind = "cave" },
  { zone = NEEDLES,    x = 44, y = 37, r = 1.5, kind = "cave" },
  { zone = DUSTWALLOW, x = 32, y = 23, r = 2.0, kind = "cave",  name = "Darkmist Cavern" },
  { zone = DUSTWALLOW, x = 32, y = 67, r = 1.5, kind = "cave",  name = "Bloodfen Burrow" },
  { zone = TANARIS,    x = 68, y = 41, r = 1.5, kind = "cave" },
  { zone = TANARIS,    x = 53, y = 70, r = 1.5, kind = "cave" },
  { zone = FERALAS,    x = 26, y = 66, r = 1.5, kind = "cave" },
  { zone = FERALAS,    x = 56, y = 56, r = 1.5, kind = "cave" },
  { zone = FERALAS,    x = 51, y = 31, r = 1.5, kind = "cave" },
  { zone = UNGORO,     x = 63, y = 15, r = 2.0, kind = "cave" },
  { zone = UNGORO,     x = 51, y = 49, r = 1.5, kind = "cave" },
  { zone = FELWOOD,    x = 55, y = 17, r = 2.0, kind = "cave",  name = "Irontree Cavern" },
  { zone = FELWOOD,    x = 35, y = 58, r = 1.5, kind = "cave",  name = "Shadow Hold" },
  { zone = SILITHUS,   x = 67, y = 69, r = 1.5, kind = "cave" },
  { zone = SILITHUS,   x = 61, y = 52, r = 1.0, kind = "tower" },
}
