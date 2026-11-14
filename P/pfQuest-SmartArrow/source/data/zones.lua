-- pfQuest SmartArrow
-- Copyright (C) 2026 pfQuest SmartArrow contributors
--
-- This program is free software: you can redistribute it and/or modify it
-- under the terms of the GNU General Public License as published by the Free
-- Software Foundation, either version 3 of the License, or (at your option)
-- any later version. It is distributed WITHOUT ANY WARRANTY; see LICENSE.md.

-- pfQuest SmartArrow: where each zone map lies in the world
--
-- For pfQuest builds and clients without world coordinates (a plain 1.12
-- client: no UnitPosition, no C_Map). A zone map position x, y (percent) is
--   west  = l - x / 100 * w
--   north = t - y / 100 * h
-- in the same yards and continent ids the rest of the addon uses.
--
-- w, h are pfQuest's own zone sizes (db/minimap.lua). l, t were fitted from
-- places whose map position and world position are both known: the walking
-- network's points (see data/walknet.lua, Waypoint Tracker, MIT), exact to
-- under a yard. In the five maps WoW: Forever reshaped (Mulgore, Redridge
-- Mountains, the Eastern Plaguelands, Stonetalon Mountains, Stormwind) they
-- come from innkeepers and flight masters instead, which can be off by up to
-- ~150 yards; those are marked approx, and the addon corrects them itself the
-- first time you walk into the zone from a neighbouring one.

pfQuestSmartArrowData = pfQuestSmartArrowData or {}

pfQuestSmartArrowData.zones = {
  [1] = { c = 0, l = 1802.08, t = -3877.08, w = 4925, h = 3283.34 }, -- Dun Morogh
  [3] = { c = 0, l = -2079.17, t = -5889.58, w = 2487.5, h = 1658.34 }, -- Badlands
  [4] = { c = 0, l = -1241.67, t = -10566.60, w = 3350, h = 2233.3 }, -- Blasted Lands
  [8] = { c = 0, l = -2222.92, t = -9620.83, w = 2293.75, h = 1529.17 }, -- Swamp of Sorrows
  [10] = { c = 0, l = 833.33, t = -9716.65, w = 2700, h = 1800.03 }, -- Duskwood
  [11] = { c = 0, l = -389.60, t = -2147.92, w = 4135.42, h = 2756.25 }, -- Wetlands
  [12] = { c = 0, l = 1535.42, t = -7939.56, w = 3470.84, h = 2314.62 }, -- Elwynn Forest
  [14] = { c = 1, l = -1962.50, t = 1808.33, w = 5287.5, h = 3525 }, -- Durotar
  [15] = { c = 1, l = -974.95, t = -2033.35, w = 5250, h = 3500 }, -- Dustwallow Marsh
  [16] = { c = 1, l = -3277.17, t = 5341.64, w = 5070.84, h = 3381.25 }, -- Azshara
  [17] = { c = 1, l = 2622.92, t = 1612.50, w = 10133.3, h = 6756.25 }, -- The Barrens
  [28] = { c = 0, l = 416.70, t = 3366.65, w = 4300, h = 2866.67 }, -- Western Plaguelands
  [33] = { c = 0, l = 2220.84, t = -11168.80, w = 6381.25, h = 4254.1 }, -- Stranglethorn Vale
  [36] = { c = 0, l = 783.34, t = 1500.00, w = 2800, h = 1866.67 }, -- Alterac Mountains
  [38] = { c = 0, l = -1993.75, t = -4487.50, w = 2758.33, h = 1839.58 }, -- Loch Modan
  [40] = { c = 0, l = 3016.67, t = -9399.98, w = 3500, h = 2333.3 }, -- Westfall
  [41] = { c = 0, l = -833.33, t = -9866.68, w = 2500, h = 1666.63 }, -- Deadwind Pass
  [44] = { c = 0, l = -1676.87, t = -8570.64, w = 2170.84, h = 1447.9, approx = true }, -- Redridge Mountains
  [45] = { c = 0, l = -866.70, t = -133.38, w = 3600, h = 2400 }, -- Arathi Highlands
  [46] = { c = 0, l = -266.63, t = -7031.25, w = 2929.16, h = 1952.08 }, -- Burning Steppes
  [47] = { c = 0, l = -1575.00, t = 1466.67, w = 3850, h = 2566.67 }, -- The Hinterlands
  [51] = { c = 0, l = -322.91, t = -6100.00, w = 2231.25, h = 1487.5 }, -- Searing Gorge
  [85] = { c = 0, l = 3033.35, t = 3837.49, w = 4518.75, h = 3012.5 }, -- Tirisfal Glades
  [130] = { c = 0, l = 3450.00, t = 1666.67, w = 4200, h = 2800 }, -- Silverpine Forest
  [139] = { c = 0, l = -2182.49, t = 3798.71, w = 3870.83, h = 2581.25, approx = true }, -- Eastern Plaguelands
  [141] = { c = 1, l = 3814.58, t = 11831.23, w = 5091.66, h = 3393.7 }, -- Teldrassil
  [148] = { c = 1, l = 2941.67, t = 8333.33, w = 6550, h = 4366.66 }, -- Darkshore
  [215] = { c = 1, l = 2005.38, t = -142.92, w = 5137.5, h = 3425, approx = true }, -- Mulgore
  [267] = { c = 0, l = 1066.67, t = 400.00, w = 3200, h = 2133.33 }, -- Hillsbrad Foothills
  [331] = { c = 1, l = 1700.00, t = 4672.92, w = 5766.67, h = 3843.75 }, -- Ashenvale
  [357] = { c = 1, l = 5441.64, t = -2366.66, w = 6950, h = 4633.33 }, -- Feralas
  [361] = { c = 1, l = 1641.65, t = 7133.35, w = 5750, h = 3833.33 }, -- Felwood
  [400] = { c = 1, l = -433.33, t = -3966.67, w = 4400, h = 2933.33 }, -- Thousand Needles
  [405] = { c = 1, l = 4233.33, t = 452.08, w = 4495.83, h = 2997.91 }, -- Desolace
  [406] = { c = 1, l = 3242.68, t = 2913.84, w = 4883.33, h = 3256.25, approx = true }, -- Stonetalon Mountains
  [440] = { c = 1, l = -218.75, t = -5875.00, w = 6900, h = 4600 }, -- Tanaris
  [490] = { c = 1, l = 533.34, t = -5966.67, w = 3700, h = 2466.66 }, -- Un\'Goro Crater
  [493] = { c = 1, l = -1381.27, t = 8491.67, w = 2308.33, h = 1539.59 }, -- Moonglade
  [618] = { c = 1, l = -316.66, t = 8533.33, w = 7100, h = 4733.33 }, -- Winterspring
  [1377] = { c = 1, l = 2537.47, t = -5958.32, w = 3483.33, h = 2322.92 }, -- Silithus
  [1497] = { c = 0, l = 873.21, t = 1877.94, w = 959.375, h = 640.11 }, -- Undercity
  [1519] = { c = 0, l = 1369.85, t = -8279.39, w = 1344.27, h = 896.36, approx = true }, -- Stormwind City
  [1537] = { c = 0, l = -713.59, t = -4569.24, w = 790.629, h = 527.61 }, -- Ironforge
  [1637] = { c = 1, l = -3680.59, t = 2273.92, w = 1402.61, h = 935.42 }, -- Orgrimmar
  [1638] = { c = 1, l = 516.65, t = -850.02, w = 1043.75, h = 695.83 }, -- Thunder Bluff
  [1657] = { c = 1, l = 2938.36, t = 10238.33, w = 1058.33, h = 705.71 }, -- Darnassus
}
