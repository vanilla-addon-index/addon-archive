-- QuestTracker Zone Data
-- Maps WorldMapFrame zone names to pfDB zone IDs

QuestTracker_ZoneData = {}

-- Main zone mappings: WorldMapFrame zone name -> pfDB zone ID (the primary zone ID)
-- These are the main outdoor zones that appear on the world map
QuestTracker_ZoneData.ZoneNameToID = {
    -- Eastern Kingdoms
    ["Alterac Mountains"] = 36,
    ["Arathi Highlands"] = 45,
    ["Badlands"] = 3,
    ["Blasted Lands"] = 4,
    ["Burning Steppes"] = 46,
    ["Deadwind Pass"] = 41,
    ["Dun Morogh"] = 1,
    ["Duskwood"] = 10,
    ["Eastern Plaguelands"] = 139,
    ["Elwynn Forest"] = 12,
    ["Hillsbrad Foothills"] = 267,
    ["Loch Modan"] = 38,
    ["Redridge Mountains"] = 44,
    ["Searing Gorge"] = 51,
    ["Silverpine Forest"] = 130,
    ["Stranglethorn Vale"] = 33,
    ["Swamp of Sorrows"] = 8,
    ["The Hinterlands"] = 47,
    ["Tirisfal Glades"] = 85,
    ["Western Plaguelands"] = 28,
    ["Westfall"] = 40,
    ["Wetlands"] = 11,

    -- Kalimdor
    ["Ashenvale"] = 331,
    ["Azshara"] = 16,
    ["Darkshore"] = 148,
    ["Desolace"] = 405,
    ["Durotar"] = 14,
    ["Dustwallow Marsh"] = 15,
    ["Felwood"] = 361,
    ["Feralas"] = 357,
    ["Moonglade"] = 493,
    ["Mulgore"] = 215,
    ["Silithus"] = 1377,
    ["Stonetalon Mountains"] = 406,
    ["Tanaris"] = 440,
    ["Teldrassil"] = 141,
    ["The Barrens"] = 17,
    ["Thousand Needles"] = 400,
    ["Un'Goro Crater"] = 490,
    ["Winterspring"] = 618,

    -- Capital Cities
    ["Stormwind City"] = 1519,
    ["Ironforge"] = 1537,
    ["Darnassus"] = 1657,
    ["Orgrimmar"] = 1637,
    ["Thunder Bluff"] = 1638,
    ["Undercity"] = 1497,

    -- TurtleWoW Custom Cities
    ["Alah'Thalas"] = 2040,

    -- TurtleWoW Custom Zones
    ["Hyjal"] = 616,
    ["Gilneas"] = 5179,
    ["Thalassian Highlands"] = 5225,
    ["Northwind"] = 5581,
    ["Tel'Abim"] = 5121,
    ["Lapidis Isle"] = 409,
    ["Balor"] = 5561,
    ["Grim Reaches"] = 5602,
    ["Blackstone Island"] = 5536,
    ["Icepoint Rock"] = 5024,
    ["The Rock of Desolation"] = 5557,
}

-- Sub-zones that belong to each main zone (for quest location tracking)
-- Maps main zone ID to list of sub-zone IDs that belong to it
QuestTracker_ZoneData.SubZones = {
    -- Elwynn Forest sub-zones
    [12] = {9, 18, 57, 60, 62, 86, 87, 88, 91},
    -- Dun Morogh sub-zones
    [1] = {131, 132, 133, 134, 135, 136, 137, 138, 211, 212},
    -- Tirisfal Glades sub-zones
    [85] = {152, 154, 156, 157, 159, 160, 162, 164, 165, 166, 167},
    -- Stranglethorn Vale sub-zones
    [33] = {19, 35, 37, 43, 99, 100, 101, 102, 103, 104, 105, 117, 122, 123, 125, 127, 128, 129, 297, 310, 311},
    -- Westfall sub-zones
    [40] = {20, 107, 108, 109, 111, 113, 115, 219},
    -- Redridge Mountains sub-zones
    [44] = {68, 69, 70, 71, 95, 97},
    -- Duskwood sub-zones
    [10] = {42, 93, 94, 121, 241, 242, 245, 492},
    -- Loch Modan sub-zones
    [38] = {142, 143, 144, 146, 147, 149, 556},
    -- Wetlands sub-zones
    [11] = {118, 150, 205, 309},
    -- Hillsbrad Foothills sub-zones
    [267] = {271, 272, 275, 285, 286, 288, 289, 290, 294, 295},
    -- Alterac Mountains sub-zones
    [36] = {278, 279, 280, 281, 282, 284},
    -- Arathi Highlands sub-zones
    [45] = {313, 314, 315, 316, 317, 320, 321, 324, 327, 333, 334, 335, 336},
    -- Western Plaguelands sub-zones
    [28] = {190, 192, 193, 197, 198, 199, 200, 201, 202},
    -- Silverpine Forest sub-zones
    [130] = {172, 204, 213, 226, 228, 229, 230, 231, 233, 236, 237, 238, 240},
    -- The Barrens sub-zones
    [17] = {359, 378, 379, 380, 381, 382, 383, 384, 385, 386, 387, 388, 390, 391},
    -- Mulgore sub-zones
    [215] = {220, 222, 224, 225, 360},
    -- Durotar sub-zones
    [14] = {362, 363, 366, 367, 368, 369, 370, 372},
    -- Teldrassil sub-zones
    [141] = {186, 188, 259, 260, 261, 264, 266},
    -- Darkshore sub-zones
    [148] = {442, 443, 444, 445, 446, 447, 448, 449, 450, 452, 453, 454, 455, 456},
    -- Ashenvale sub-zones
    [331] = {411, 412, 413, 414, 415, 416, 417, 418, 419, 420, 421, 422, 424, 425, 426, 427, 428, 429, 430, 431, 432, 433, 434, 435, 436, 437, 438, 441},
    -- Stonetalon Mountains sub-zones
    [406] = {460, 461, 463, 464, 465, 466, 467, 468, 469},
    -- Desolace sub-zones
    [405] = {596, 597, 598, 599, 600, 602, 603, 604, 606, 607, 608, 609},
    -- Thousand Needles sub-zones
    [400] = {439, 479, 480, 481, 482, 483, 484, 485, 486, 487, 488, 489},
    -- Tanaris sub-zones
    [440] = {976, 977, 978, 979, 980, 981, 982, 983, 984, 985, 986, 987, 988, 989, 990, 991, 992},
    -- Un'Goro Crater sub-zones
    [490] = {536, 537, 538, 539, 540, 541, 542, 543},
    -- Feralas sub-zones
    [357] = {},
    -- Dustwallow Marsh sub-zones
    [15] = {496, 497, 498, 499, 500, 501, 502, 503, 504, 505, 506, 507, 508, 509, 510, 511, 513, 514, 515, 516, 517, 518},
    -- The Hinterlands sub-zones
    [47] = {307, 348, 350, 351, 353, 354, 355, 356},
    -- Burning Steppes sub-zones
    [46] = {249, 250, 252, 253, 254, 255},
    -- Searing Gorge sub-zones
    [51] = {246, 247},
    -- Badlands sub-zones
    [3] = {337, 338, 339, 340, 341, 342, 344, 345, 346},
    -- Swamp of Sorrows sub-zones
    [8] = {74, 75, 76, 116, 300},
    -- Blasted Lands sub-zones
    [4] = {72, 73},
}

-- Continent data for world map
QuestTracker_ZoneData.Continents = {
    [1] = "Kalimdor",
    [2] = "Eastern Kingdoms",
}

-- Cities/towns mapped to their parent zones
-- When hovering these, show the parent zone's quest count
QuestTracker_ZoneData.CityToZone = {
    -- Eastern Kingdoms
    ["Darkshire"] = "Duskwood",
    ["Sentinel Hill"] = "Westfall",
    ["Lakeshire"] = "Redridge Mountains",
    ["Goldshire"] = "Elwynn Forest",
    ["Northshire Valley"] = "Elwynn Forest",
    ["Northshire Abbey"] = "Elwynn Forest",
    ["Kharanos"] = "Dun Morogh",
    ["Anvilmar"] = "Dun Morogh",
    ["Thelsamar"] = "Loch Modan",
    ["Menethil Harbor"] = "Wetlands",
    ["Southshore"] = "Hillsbrad Foothills",
    ["Tarren Mill"] = "Hillsbrad Foothills",
    ["Refuge Pointe"] = "Arathi Highlands",
    ["Hammerfall"] = "Arathi Highlands",
    ["Aerie Peak"] = "The Hinterlands",
    ["Revantusk Village"] = "The Hinterlands",
    ["Booty Bay"] = "Stranglethorn Vale",
    ["Grom'gol Base Camp"] = "Stranglethorn Vale",
    ["Rebel Camp"] = "Stranglethorn Vale",
    ["Nesingwary's Expedition"] = "Stranglethorn Vale",
    ["Brill"] = "Tirisfal Glades",
    ["Deathknell"] = "Tirisfal Glades",
    ["The Sepulcher"] = "Silverpine Forest",
    ["Light's Hope Chapel"] = "Eastern Plaguelands",
    ["Chillwind Camp"] = "Western Plaguelands",
    ["The Bulwark"] = "Western Plaguelands",
    ["Thorium Point"] = "Searing Gorge",
    ["Kargath"] = "Badlands",
    ["Nethergarde Keep"] = "Blasted Lands",
    ["Stonard"] = "Swamp of Sorrows",
    ["Morgan's Vigil"] = "Burning Steppes",
    ["Flame Crest"] = "Burning Steppes",

    -- Kalimdor
    ["Dolanaar"] = "Teldrassil",
    ["Shadowglen"] = "Teldrassil",
    ["Auberdine"] = "Darkshore",
    ["Astranaar"] = "Ashenvale",
    ["Splintertree Post"] = "Ashenvale",
    ["Stonetalon Peak"] = "Stonetalon Mountains",
    ["Sun Rock Retreat"] = "Stonetalon Mountains",
    ["Nijel's Point"] = "Desolace",
    ["Shadowprey Village"] = "Desolace",
    ["Feathermoon Stronghold"] = "Feralas",
    ["Camp Mojache"] = "Feralas",
    ["Theramore Isle"] = "Dustwallow Marsh",
    ["Brackenwall Village"] = "Dustwallow Marsh",
    ["Gadgetzan"] = "Tanaris",
    ["Marshal's Refuge"] = "Un'Goro Crater",
    ["Everlook"] = "Winterspring",
    ["Cenarion Hold"] = "Silithus",
    ["Razor Hill"] = "Durotar",
    ["Sen'jin Village"] = "Durotar",
    ["Valley of Trials"] = "Durotar",
    ["Bloodhoof Village"] = "Mulgore",
    ["Camp Narache"] = "Mulgore",
    ["The Crossroads"] = "The Barrens",
    ["Camp Taurajo"] = "The Barrens",
    ["Ratchet"] = "The Barrens",
    ["Freewind Post"] = "Thousand Needles",
    ["Thalanaar"] = "Thousand Needles",
}

-- Zone level ranges for display purposes
QuestTracker_ZoneData.ZoneLevels = {
    -- Eastern Kingdoms
    ["Elwynn Forest"] = {1, 10},
    ["Dun Morogh"] = {1, 10},
    ["Tirisfal Glades"] = {1, 10},
    ["Westfall"] = {10, 20},
    ["Loch Modan"] = {10, 20},
    ["Silverpine Forest"] = {10, 20},
    ["Redridge Mountains"] = {15, 25},
    ["Duskwood"] = {18, 30},
    ["Wetlands"] = {20, 30},
    ["Hillsbrad Foothills"] = {20, 30},
    ["Alterac Mountains"] = {30, 40},
    ["Arathi Highlands"] = {30, 40},
    ["Stranglethorn Vale"] = {30, 45},
    ["Badlands"] = {35, 45},
    ["Swamp of Sorrows"] = {35, 45},
    ["The Hinterlands"] = {40, 50},
    ["Searing Gorge"] = {43, 50},
    ["Blasted Lands"] = {45, 55},
    ["Burning Steppes"] = {50, 58},
    ["Western Plaguelands"] = {51, 58},
    ["Eastern Plaguelands"] = {53, 60},
    ["Deadwind Pass"] = {55, 60},

    -- Kalimdor
    ["Teldrassil"] = {1, 10},
    ["Durotar"] = {1, 10},
    ["Mulgore"] = {1, 10},
    ["Darkshore"] = {10, 20},
    ["The Barrens"] = {10, 25},
    ["Stonetalon Mountains"] = {15, 27},
    ["Ashenvale"] = {18, 30},
    ["Thousand Needles"] = {25, 35},
    ["Desolace"] = {30, 40},
    ["Dustwallow Marsh"] = {35, 45},
    ["Feralas"] = {40, 50},
    ["Tanaris"] = {40, 50},
    ["Azshara"] = {45, 55},
    ["Felwood"] = {48, 55},
    ["Un'Goro Crater"] = {48, 55},
    ["Winterspring"] = {53, 60},
    ["Silithus"] = {55, 60},
    ["Moonglade"] = {55, 60},

    -- Capital Cities
    ["Stormwind City"] = {1, 60},
    ["Ironforge"] = {1, 60},
    ["Darnassus"] = {1, 60},
    ["Orgrimmar"] = {1, 60},
    ["Thunder Bluff"] = {1, 60},
    ["Undercity"] = {1, 60},

    -- TurtleWoW Custom Cities
    ["Alah'Thalas"] = {1, 60},

    -- TurtleWoW Custom Zones
    ["Hyjal"] = {55, 60},
    ["Gilneas"] = {1, 20},
    ["Thalassian Highlands"] = {20, 40},
    ["Northwind"] = {40, 55},
    ["Tel'Abim"] = {35, 50},
    ["Lapidis Isle"] = {45, 55},
    ["Balor"] = {50, 60},
    ["Grim Reaches"] = {55, 60},
    ["Blackstone Island"] = {50, 60},
    ["Icepoint Rock"] = {55, 60},
    ["The Rock of Desolation"] = {55, 60},
}
