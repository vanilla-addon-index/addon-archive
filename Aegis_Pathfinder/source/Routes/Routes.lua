-- Routes.lua
-- Race-based leveling routes for AegisPathfinder
-- Defines the zone progression for each race from 1-60

local AegisPathfinder = AegisPathfinder

-- Shared Alliance progression after level 12 (all races merge into this path)
local AllianceSharedPath = {
    -- Level 12-20 progression
    { zone = "Darkshore",            levels = "12-14", guide = "Optimized/Darkshore (12-14)" },
    { zone = "Darkshore",            levels = "14-17", guide = "Optimized/Darkshore (14-17)" },
    { zone = "Loch Modan",           levels = "17-18", guide = "Optimized/Loch Modan (17-18)" },
    { zone = "Redridge Mountains",   levels = "18-20", guide = "Optimized/Redridge (18-20)" },
    -- Level 20-30 progression
    { zone = "Darkshore",            levels = "20-21", guide = "Optimized/Darkshore (20-21)" },
    { zone = "Ashenvale",            levels = "21-22", guide = "Optimized/Ashenvale (21-22)" },
    { zone = "Stonetalon Mountains", levels = "22-23", guide = "Optimized/Stonetalon (22-23)" },
    { zone = "Darkshore",            levels = "23-24", guide = "Optimized/Darkshore (23-24)" },
    { zone = "Ashenvale",            levels = "24-25", guide = "Optimized/Ashenvale (24-25)" },
    { zone = "Wetlands",             levels = "25-27", guide = "Optimized/Wetlands (25-27)" },
    { zone = "Redridge Mountains",   levels = "27-28", guide = "Optimized/Redridge (27-28)" },
    { zone = "Duskwood",             levels = "28-29", guide = "Optimized/Duskwood (28-29)" },
    { zone = "Ashenvale",            levels = "29-30", guide = "Optimized/Ashenvale (29-30)" },
    { zone = "Wetlands",             levels = "30-30", guide = "Optimized/Wetlands (30-30)" },
    -- Level 30-40 progression
    { zone = "Hillsbrad Foothills",  levels = "30-31", guide = "Optimized/Hillsbrad (30-31)" },
    { zone = "Alterac Mountains",    levels = "31-31", guide = "Optimized/Alterac (31-31)" },
    { zone = "Arathi Highlands",     levels = "31-32", guide = "Optimized/Arathi (31-32)" },
    { zone = "Stranglethorn Vale",   levels = "32-32", guide = "Optimized/Stranglethorn (32-32)" },
    { zone = "Thousand Needles",     levels = "32-33", guide = "Optimized/Thousand Needles (32-33)" },
    { zone = "Stonetalon Mountains", levels = "33-33", guide = "Optimized/Stonetalon (33-33)" },
    { zone = "Desolace",             levels = "33-35", guide = "Optimized/Desolace (33-35)" },
    { zone = "Stranglethorn Vale",   levels = "35-36", guide = "Optimized/Stranglethorn (35-36)" },
    { zone = "Alterac Mountains",    levels = "36-37", guide = "Optimized/Alterac (36-37)" },
    { zone = "Arathi Highlands",     levels = "37-38", guide = "Optimized/Arathi (37-38)" },
    { zone = "Dustwallow Marsh",     levels = "38-38", guide = "Optimized/Dustwallow (38-38)" },
    { zone = "Stranglethorn Vale",   levels = "38-40", guide = "Optimized/Stranglethorn (38-40)" },
    -- Level 40-50 progression
    { zone = "Badlands",             levels = "40-41", guide = "Optimized/Badlands (40-41)" },
    { zone = "Swamp of Sorrows",     levels = "41-41", guide = "Optimized/Swamp of Sorrows (41-41)" },
    { zone = "Desolace",             levels = "41-42", guide = "Optimized/Desolace (41-42)" },
    { zone = "Stranglethorn Vale",   levels = "42-43", guide = "Optimized/Stranglethorn (42-43)" },
    { zone = "Tanaris",              levels = "43-43", guide = "Optimized/Tanaris (43-43)" },
    { zone = "Feralas",              levels = "43-45", guide = "Optimized/Feralas (43-45)" },
    { zone = "Uldaman",              levels = "45-46", guide = "Optimized/Uldaman (45-46)" },
    { zone = "The Hinterlands",      levels = "46-47", guide = "Optimized/Hinterlands (46-47)" },
    { zone = "Feralas",              levels = "47-47", guide = "Optimized/Feralas (47-47)" },
    { zone = "Tanaris",              levels = "47-48", guide = "Optimized/Tanaris (47-48)" },
    { zone = "The Hinterlands",      levels = "48-48", guide = "Optimized/Hinterlands (48-48)" },
    { zone = "Stranglethorn Vale",   levels = "48-49", guide = "Optimized/Stranglethorn (48-49)" },
    { zone = "Blasted Lands",        levels = "49-50", guide = "Optimized/Blasted Lands (49-50)" },
    -- Level 50-60 progression
    { zone = "Searing Gorge",        levels = "50-51", guide = "Optimized/Searing Gorge (50-51)" },
    { zone = "Un'Goro Crater",       levels = "51-52", guide = "Optimized/Un'Goro (51-52)" },
    { zone = "Azshara",              levels = "52-53", guide = "Optimized/Azshara (52-53)" },
    { zone = "Felwood",              levels = "53-54", guide = "Optimized/Felwood (53-54)" },
    { zone = "Winterspring",         levels = "54-55", guide = "Optimized/Winterspring (54-55)" },
    { zone = "Burning Steppes",      levels = "55-56", guide = "Optimized/Burning Steppes (55-56)" },
    { zone = "Sunken Temple",        levels = "56-56", guide = "Optimized/Sunken Temple (56-56)" },
    { zone = "Silithus",             levels = "56-57", guide = "Optimized/Silithus (56-57)" },
    { zone = "Western Plaguelands",  levels = "57-58", guide = "Optimized/Western Plaguelands (57-58)" },
    { zone = "Eastern Plaguelands",  levels = "58-59", guide = "Optimized/Eastern Plaguelands (58-59)" },
    { zone = "Winterspring",         levels = "59-60", guide = "Optimized/Winterspring (59-60)" },
}

-- Shared Horde progression after level 12 (all races merge into this path after Barrens)
local HordeSharedPath = {
    -- Level 12-20 progression
    { zone = "The Barrens",          levels = "12-15", guide = "Optimized/The Barrens (12-15)" },
    { zone = "Stonetalon Mountains", levels = "15-16", guide = "Optimized/Stonetalon (15-16)" },
    { zone = "The Barrens",          levels = "16-18", guide = "Optimized/The Barrens (16-18)" },
    { zone = "The Barrens",          levels = "18-20", guide = "Optimized/The Barrens (18-20)" },
    -- Level 20-30 progression
    { zone = "Stonetalon Mountains", levels = "20-21", guide = "Optimized/Stonetalon (20-21)" },
    { zone = "Ashenvale",            levels = "21-21", guide = "Optimized/Ashenvale (21-21)" },
    { zone = "Southern Barrens",     levels = "22-23", guide = "Optimized/The Barrens (22-23)" },
    { zone = "Stonetalon Mountains", levels = "23-25", guide = "Optimized/Stonetalon (23-25)" },
    { zone = "Southern Barrens",     levels = "25-25", guide = "Optimized/The Barrens (25-25)" },
    { zone = "Thousand Needles",     levels = "25-26", guide = "Optimized/Thousand Needles (25-26)" },
    { zone = "Ashenvale",            levels = "26-27", guide = "Optimized/Ashenvale (26-27)" },
    { zone = "Stonetalon Mountains", levels = "27-27", guide = "Optimized/Stonetalon (27-27)" },
    { zone = "Thousand Needles",     levels = "27-29", guide = "Optimized/Thousand Needles (27-29)" },
    { zone = "Hillsbrad Foothills",  levels = "29-30", guide = "Optimized/Hillsbrad Foothills (29-30)" },
    -- Level 30-40 progression
    { zone = "Alterac Mountains",    levels = "30-30", guide = "Optimized/Alterac Mountains (30-30)" },
    { zone = "Arathi Highlands",     levels = "30-30", guide = "Optimized/Arathi Highlands (30-30)" },
    { zone = "Stranglethorn Vale",   levels = "30-31", guide = "Optimized/Stranglethorn Vale (30-31)" },
    { zone = "Thousand Needles",     levels = "31-32", guide = "Optimized/Thousand Needles (31-32)" },
    { zone = "Desolace",             levels = "32-34", guide = "Optimized/Desolace (32-34)" },
    { zone = "Stranglethorn Vale",   levels = "34-36", guide = "Optimized/Stranglethorn Vale (34-36)" },
    { zone = "Arathi Highlands",     levels = "36-37", guide = "Optimized/Arathi Highlands (36-37)" },
    { zone = "Alterac Mountains",    levels = "37-37", guide = "Optimized/Alterac Mountains (37-37)" },
    { zone = "Thousand Needles",     levels = "37-38", guide = "Optimized/Thousand Needles (37-38)" },
    { zone = "Dustwallow Marsh",     levels = "38-38", guide = "Optimized/Dustwallow Marsh (38-38)" },
    { zone = "Stranglethorn Vale",   levels = "38-40", guide = "Optimized/Stranglethorn Vale (38-40)" },
    -- Level 40-50 progression
    { zone = "Badlands",             levels = "40-41", guide = "Optimized/Badlands (40-41)" },
    { zone = "Swamp of Sorrows",     levels = "41-42", guide = "Optimized/Swamp of Sorrows (41-42)" },
    { zone = "Stranglethorn Vale",   levels = "42-43", guide = "Optimized/Stranglethorn Vale (42-43)" },
    { zone = "Desolace",             levels = "43-43", guide = "Optimized/Desolace (43-43)" },
    { zone = "Dustwallow Marsh",     levels = "43-44", guide = "Optimized/Dustwallow Marsh (43-44)" },
    { zone = "Tanaris",              levels = "44-45", guide = "Optimized/Tanaris (44-45)" },
    { zone = "Feralas",              levels = "45-46", guide = "Optimized/Feralas (45-46)" },
    { zone = "Uldaman",              levels = "46-46", guide = "Optimized/Uldaman (46-46)" },
    { zone = "Azshara",              levels = "46-46", guide = "Optimized/Azshara (46-46)" },
    { zone = "The Hinterlands",      levels = "46-47", guide = "Optimized/Hinterlands (46-47)" },
    { zone = "Stranglethorn Vale",   levels = "47-47", guide = "Optimized/Stranglethorn Vale (47-47)" },
    { zone = "Searing Gorge",        levels = "47-48", guide = "Optimized/Searing Gorge (47-48)" },
    { zone = "Swamp of Sorrows",     levels = "48-48", guide = "Optimized/Swamp of Sorrows (48-48)" },
    { zone = "Feralas",              levels = "48-49", guide = "Optimized/Feralas (48-49)" },
    { zone = "Tanaris",              levels = "49-50", guide = "Optimized/Tanaris (49-50)" },
    -- Level 50-60 progression
    { zone = "Azshara",              levels = "50-50", guide = "Optimized/Azshara (50-50)" },
    { zone = "The Hinterlands",      levels = "50-51", guide = "Optimized/Hinterlands (50-51)" },
    { zone = "Blasted Lands",        levels = "51-51", guide = "Optimized/Blasted Lands (51-51)" },
    { zone = "Un'Goro Crater",       levels = "51-52", guide = "Optimized/Un'Goro Crater (51-52)" },
    { zone = "Burning Steppes",      levels = "52-53", guide = "Optimized/Burning Steppes (52-53)" },
    { zone = "Sunken Temple",        levels = "53-53", guide = "Optimized/Sunken Temple (53-53)" },
    { zone = "Azshara",              levels = "53-54", guide = "Optimized/Azshara (53-54)" },
    { zone = "Felwood",              levels = "54-54", guide = "Optimized/Felwood (54-54)" },
    { zone = "Winterspring",         levels = "54-55", guide = "Optimized/Winterspring (54-55)" },
    { zone = "Felwood",              levels = "55-55", guide = "Optimized/Felwood (55-55)" },
    { zone = "Silithus",             levels = "55-55", guide = "Optimized/Silithus (55-55)" },
    { zone = "Western Plaguelands",  levels = "55-56", guide = "Optimized/Western Plaguelands (55-56)" },
    { zone = "Eastern Plaguelands",  levels = "56-57", guide = "Optimized/Eastern Plaguelands (56-57)" },
    { zone = "Western Plaguelands",  levels = "57-58", guide = "Optimized/Western Plaguelands (57-58)" },
    { zone = "Winterspring",         levels = "58-60", guide = "Optimized/Winterspring (58-60)" },
}

-- Helper function to merge starting zone with shared path
local function MergeRoutes(startingZones, sharedPath)
    local route = {}
    for _, zone in ipairs(startingZones) do
        table.insert(route, zone)
    end
    for _, zone in ipairs(sharedPath) do
        table.insert(route, zone)
    end
    return route
end

-- ============================================================================
-- Alliance Routes
-- ============================================================================

-- Human route - Elwynn Forest 1-10 → Westfall 10-12 → shared path
AegisPathfinder:RegisterRoute("Human", MergeRoutes({
    { zone = "Elwynn Forest", levels = "1-10",  guide = "Optimized/Elwynn Forest (1-10)" },
    { zone = "Westfall",      levels = "10-12", guide = "Optimized/Westfall (10-12)" },
}, AllianceSharedPath))

-- Dwarf route - Dun Morogh 1-12 → shared path
AegisPathfinder:RegisterRoute("Dwarf", MergeRoutes({
    { zone = "Dun Morogh", levels = "1-12", guide = "Optimized/Dun Morogh (1-12)" },
}, AllianceSharedPath))

-- Gnome route - Dun Morogh 1-12 → shared path (same as Dwarf)
AegisPathfinder:RegisterRoute("Gnome", MergeRoutes({
    { zone = "Dun Morogh", levels = "1-12", guide = "Optimized/Dun Morogh (1-12)" },
}, AllianceSharedPath))

-- Night Elf route - Teldrassil 1-12 → shared path
AegisPathfinder:RegisterRoute("NightElf", MergeRoutes({
    { zone = "Teldrassil", levels = "1-12", guide = "Optimized/Teldrassil (1-12)" },
}, AllianceSharedPath))

-- High Elf (Turtle WoW) - Thalassian Highlands 1-10 → shared path
AegisPathfinder:RegisterRoute("HighElf", MergeRoutes({
    { zone = "Thalassian Highlands", levels = "1-10", guide = "Thalassian Highlands (1-10)" },
}, AllianceSharedPath))

-- ============================================================================
-- Horde Routes
-- ============================================================================

-- Orc route - Durotar 1-12 → shared path
AegisPathfinder:RegisterRoute("Orc", MergeRoutes({
    { zone = "Durotar", levels = "1-12", guide = "Optimized/Durotar (1-12)" },
}, HordeSharedPath))

-- Troll route - Durotar 1-12 → shared path (same as Orc)
AegisPathfinder:RegisterRoute("Troll", MergeRoutes({
    { zone = "Durotar", levels = "1-12", guide = "Optimized/Durotar (1-12)" },
}, HordeSharedPath))

-- Tauren route - Mulgore 1-12 → shared path
AegisPathfinder:RegisterRoute("Tauren", MergeRoutes({
    { zone = "Mulgore", levels = "1-12", guide = "Optimized/Mulgore (1-12)" },
}, HordeSharedPath))

-- Undead route - Tirisfal Glades 1-12 → shared path
AegisPathfinder:RegisterRoute("Undead", MergeRoutes({
    { zone = "Tirisfal Glades", levels = "1-12", guide = "Optimized/Tirisfal Glades (1-12)" },
}, HordeSharedPath))

-- Goblin (Turtle WoW) - Blackstone Island 1-10 → shared path
AegisPathfinder:RegisterRoute("Goblin", MergeRoutes({
    { zone = "Blackstone Island", levels = "1-10", guide = "Blackstone Island (1-10)" },
}, HordeSharedPath))

-- ============================================================================
-- Route Packs
-- ============================================================================

-- The Optimized route pack (default)
AegisPathfinder:RegisterRoutePack("VanillaGuide", {
    -- Shown as "Optimized". The key keeps its old name, "VanillaGuide",
    -- because every existing character has it saved in its routepack field:
    -- renamed, they would all lose their route.
    displayName = "Optimized",
    description = "Quest-optimized 1-60 leveling",
    routes = {
        Human = MergeRoutes({
            { zone = "Elwynn Forest", levels = "1-10",  guide = "Optimized/Elwynn Forest (1-10)" },
            { zone = "Westfall",      levels = "10-12", guide = "Optimized/Westfall (10-12)" },
        }, AllianceSharedPath),
        Dwarf = MergeRoutes({
            { zone = "Dun Morogh", levels = "1-12", guide = "Optimized/Dun Morogh (1-12)" },
        }, AllianceSharedPath),
        Gnome = MergeRoutes({
            { zone = "Dun Morogh", levels = "1-12", guide = "Optimized/Dun Morogh (1-12)" },
        }, AllianceSharedPath),
        NightElf = MergeRoutes({
            { zone = "Teldrassil", levels = "1-12", guide = "Optimized/Teldrassil (1-12)" },
        }, AllianceSharedPath),
        HighElf = MergeRoutes({
            { zone = "Thalassian Highlands", levels = "1-10", guide = "Thalassian Highlands (1-10)" },
        }, AllianceSharedPath),
        Orc = MergeRoutes({
            { zone = "Durotar", levels = "1-12", guide = "Optimized/Durotar (1-12)" },
        }, HordeSharedPath),
        Troll = MergeRoutes({
            { zone = "Durotar", levels = "1-12", guide = "Optimized/Durotar (1-12)" },
        }, HordeSharedPath),
        Tauren = MergeRoutes({
            { zone = "Mulgore", levels = "1-12", guide = "Optimized/Mulgore (1-12)" },
        }, HordeSharedPath),
        Undead = MergeRoutes({
            { zone = "Tirisfal Glades", levels = "1-12", guide = "Optimized/Tirisfal Glades (1-12)" },
        }, HordeSharedPath),
        Goblin = MergeRoutes({
            { zone = "Blackstone Island", levels = "1-10", guide = "Blackstone Island (1-10)" },
        }, HordeSharedPath),
    },
})

-- RestedXP Route Pack - Speedrun routes (Full 1-60), in the order the
-- guides' own next links run. Where RestedXP's paths part, the route says
-- which is yours -- a guide's next link names only one: at 19 the Eastern
-- Kingdoms races go through Redridge (and the Deadmines) and on to Darkshore
-- at 20, Night Elves stay in Darkshore and Ashenvale; they meet again in the
-- Wetlands at 23. Dwarves and Gnomes take their own Elwynn and Loch Modan
-- guides (there is no Dun Morogh 6-11 but the Hunter's).
local RXPAllianceSharedPath = {
    { zone = "Wetlands",                      levels = "23-24", guide = "RXP/23-24 Wetlands" },
    { zone = "Duskwood/Redridge",             levels = "24-27", guide = "RXP/24-27 Duskwood/Redridge" },
    { zone = "Wetlands/Hillsbrad",            levels = "27-29", guide = "RXP/27-29 Wetlands/Hillsbrad" },
    { zone = "Ashenvale",                     levels = "29-30", guide = "RXP/29-30 Ashenvale" },
    { zone = "Duskwood",                      levels = "29-32", guide = "RXP/29-32 Duskwood" },
    { zone = "Hillsbrad/Arathi",              levels = "32-33", guide = "RXP/32-33 Hillsbrad/Arathi" },
    { zone = "Thousand Needles",              levels = "33-34", guide = "RXP/33-34 Thousand Needles" },
    { zone = "Stranglethorn Vale",            levels = "34-35", guide = "RXP/34-35 Stranglethorn Vale I" },
    { zone = "Desolace",                      levels = "35-37", guide = "RXP/35-37 Desolace" },
    { zone = "Stranglethorn Vale",            levels = "36-38", guide = "RXP/36-38 Stranglethorn Vale II" },
    { zone = "Swamp of Sorrows",              levels = "38-39", guide = "RXP/38-39 Swamp of Sorrows" },
    { zone = "Alterac/Arathi",                levels = "39-40", guide = "RXP/39-40 Alterac/Arathi" },
    { zone = "Dustwallow Marsh",              levels = "40-40", guide = "RXP/40-40 Dustwallow Marsh2" },
    { zone = "Desolace",                      levels = "40-41", guide = "RXP/40-41 Desolace" },
    { zone = "Badlands",                      levels = "41-41", guide = "RXP/41-41 Badlands" },
    { zone = "STV/Swamp of Sorrows",          levels = "41-43", guide = "RXP/41-43 STV/Swamp of Sorrows" },
    { zone = "Tanaris/Dustwallow",            levels = "43-44", guide = "RXP/43-44 Tanaris/Dustwallow" },
    { zone = "Feralas",                       levels = "44-48", guide = "RXP/44-48 Feralas" },
    { zone = "Tanaris/Hinterlands",           levels = "48-49", guide = "RXP/48-49 Tanaris/Hinterlands" },
    { zone = "Tanaris/Un'Goro",               levels = "49-50", guide = "RXP/49-50 Tanaris/Un'Goro" },
    { zone = "Stranglethorn Vale",            levels = "50-50", guide = "RXP/50-50 Stranglethorn Vale" },
    { zone = "Searing Gorge",                 levels = "50-51", guide = "RXP/50-51 Searing Gorge" },
    { zone = "Blasted Lands",                 levels = "51-51", guide = "RXP/51-51 Blasted Lands" },
    { zone = "WPL",                           levels = "51-52", guide = "RXP/51-52 WPL" },
    { zone = "Felwood",                       levels = "52-52", guide = "RXP/52-52 Felwood" },
    { zone = "Feralas",                       levels = "52-53", guide = "RXP/52-53 Feralas" },
    { zone = "Azshara",                       levels = "53-53", guide = "RXP/53-53 Azshara" },
    { zone = "UnGoro Crater",                 levels = "53-54", guide = "RXP/53-54 UnGoro Crater" },
    { zone = "Felwood/Winterspring",          levels = "54-55", guide = "RXP/54-55 Felwood/Winterspring" },
    { zone = "Winterspring",                  levels = "55-56", guide = "RXP/55-56 Winterspring" },
    { zone = "Burning Steppes",               levels = "56-57", guide = "RXP/56-57 Burning Steppes" },
    { zone = "Western/Eastern Plaguelands",   levels = "57-59", guide = "RXP/57-59 Western/Eastern Plaguelands" },
    { zone = "Winterspring/Silithus",         levels = "59-59", guide = "RXP/59-59 Winterspring/Silithus part 1" },
    { zone = "Winterspring/Silithus",         levels = "59-60", guide = "RXP/59-60 Winterspring/Silithus part 2" },
}

local RXPHordeSharedPath = {
    { zone = "The Barrens",                   levels = "12-17", guide = "RXP/12-17 The Barrens" },
    { zone = "Stonetalon/Barrens/Ashenvale",  levels = "17-22", guide = "RXP/17-22 Stonetalon/Barrens/Ashenvale" },
    { zone = "Hillsbrad",                     levels = "22-24", guide = "RXP/22-24 Hillsbrad" },
    { zone = "Southern Barrens/Stonetalon",   levels = "24-26", guide = "RXP/24-26 Southern Barrens/Stonetalon" },
    { zone = "Ashenvale",                     levels = "26-28", guide = "RXP/26-28 Ashenvale" },
    { zone = "Thousand Needles",              levels = "28-30", guide = "RXP/28-30 Thousand Needles" },
    { zone = "Hillsbrad/Arathi",              levels = "30-33", guide = "RXP/30-33 Hillsbrad/Arathi" },
    { zone = "Shimmering Flats",              levels = "33-34", guide = "RXP/33-34 Shimmering Flats" },
    { zone = "Desolace",                      levels = "34-35", guide = "RXP/34-35 Desolace" },
    { zone = "Northern Stranglethorn",        levels = "35-37", guide = "RXP/35-37 Northern Stranglethorn" },
    { zone = "Dustwallow Marsh",              levels = "37-38", guide = "RXP/37-38 Dustwallow Marsh" },
    { zone = "Alterac/Arathi",                levels = "38-39", guide = "RXP/38-39 Alterac/Arathi" },
    { zone = "Badlands",                      levels = "39-40", guide = "RXP/39-40 Badlands" },
    { zone = "Stranglethorn Vale",            levels = "40-41", guide = "RXP/40-41 Stranglethorn Vale" },
    { zone = "Swamp of Sorrows",              levels = "41-41", guide = "RXP/41-400_41-41 Swamp of Sorrows" },
    { zone = "Desolace",                      levels = "41-41", guide = "RXP/41-41 Desolace II" },
    { zone = "Tanaris/Dustwallow",            levels = "41-43", guide = "RXP/41-43 Tanaris/Dustwallow" },
    { zone = "Feralas",                       levels = "43-44", guide = "RXP/43-44 Feralas" },
    { zone = "Southern Stranglethorn",        levels = "44-45", guide = "RXP/44-45 Southern Stranglethorn" },
    { zone = "Swamp of Sorrows",              levels = "45-46", guide = "RXP/45-46 Swamp of Sorrows" },
    { zone = "Tanaris",                       levels = "46-48", guide = "RXP/46-48 Tanaris" },
    { zone = "The Hinterlands",               levels = "48-49", guide = "RXP/48-49 The Hinterlands" },
    { zone = "Feralas",                       levels = "49-50", guide = "RXP/49-50 Feralas" },
    { zone = "Stranglethorn/Blasted Lands",   levels = "50-51", guide = "RXP/50-51 Stranglethorn/Blasted Lands" },
    { zone = "Searing Gorge/Burning Steppes", levels = "51-52", guide = "RXP/51-52 Searing Gorge/Burning Steppes" },
    { zone = "Azshara",                       levels = "52-53", guide = "RXP/52-53 Azshara" },
    { zone = "Felwood",                       levels = "53-54", guide = "RXP/53-54 Felwood" },
    { zone = "Un'Goro Crater",                levels = "54-55", guide = "RXP/54-55 Un'Goro Crater" },
    { zone = "Felwood/Winterspring",          levels = "55-56", guide = "RXP/55-56 Felwood/Winterspring" },
    { zone = "Western PL/Eastern PL",         levels = "56-58", guide = "RXP/56-58 Western PL/Eastern PL" },
    { zone = "Winterspring/Silithus",         levels = "58-59", guide = "RXP/58-59 Winterspring/Silithus I" },
    { zone = "Winterspring/Silithus",         levels = "59-60", guide = "RXP/59-60 Winterspring/Silithus II" },
}


-- RXP Hardcore Shared Paths
-- ============================================================================
-- From 42 the Alliance's hardcore guides are their own, in the order their
-- next links give; the Horde's have no 41-42 Badlands or 45-46 Feralas.
local RXPHardcoreAllianceSharedPath = {
    { zone = "Westfall",              levels = "13-15", guide = "RXP_Hardcore/13-15 Westfall" },
    { zone = "Darkshore",             levels = "15-18", guide = "RXP_Hardcore/15-18 Darkshore" },
    { zone = "Loch Modan",            levels = "18-19", guide = "RXP_Hardcore/18-19 Loch Modan" },
    { zone = "Redridge Mountains",    levels = "19-20", guide = "RXP_Hardcore/19-20 Redridge" },
    { zone = "Darkshore/Ashenvale",   levels = "20-21", guide = "RXP_Hardcore/20-21 Darkshore/Ashenvale" },
    { zone = "Stonetalon/Ashenvale",  levels = "21-23", guide = "RXP_Hardcore/21-23 Stonetalon/Ashenvale" },
    { zone = "Wetlands",              levels = "23-24", guide = "RXP_Hardcore/23-24 Wetlands" },
    { zone = "Duskwood/Redridge",     levels = "24-27", guide = "RXP_Hardcore/24-27 Duskwood/Redridge" },
    { zone = "Wetlands",              levels = "27-27", guide = "RXP_Hardcore/27-27 Wetlands" },
    { zone = "Ashenvale",             levels = "27-30", guide = "RXP_Hardcore/27-30 Ashenvale" },
    { zone = "Wetlands/Hillsbrad",    levels = "30-30", guide = "RXP_Hardcore/30-30 Wetlands/Hillsbrad" },
    { zone = "Duskwood",              levels = "30-32", guide = "RXP_Hardcore/30-32 Duskwood" },
    { zone = "Hillsbrad/Arathi",      levels = "32-33", guide = "RXP_Hardcore/32-33 Hillsbrad/Arathi I" },
    { zone = "Thousand Needles",      levels = "33-34", guide = "RXP_Hardcore/33-34 Thousand Needles" },
    { zone = "Stranglethorn Vale",    levels = "34-35", guide = "RXP_Hardcore/34-35 Stranglethorn Vale I" },
    { zone = "Hillsbrad/Arathi",      levels = "35-36", guide = "RXP_Hardcore/35-36 Hillsbrad/Arathi II" },
    { zone = "Desolace",              levels = "36-37", guide = "RXP_Hardcore/36-37 Desolace" },
    { zone = "Stranglethorn Vale",    levels = "37-38", guide = "RXP_Hardcore/37-38 Stranglethorn Vale II" },
    { zone = "Swamp of Sorrows",      levels = "38-39", guide = "RXP_Hardcore/38-39 Swamp of Sorrows" },
    { zone = "Dustwallow Marsh",      levels = "39-39", guide = "RXP_Hardcore/39-39 Dustwallow Marsh" },
    { zone = "Desolace",              levels = "39-40", guide = "RXP_Hardcore/39-40 Desolace" },
    { zone = "Alterac/Arathi",        levels = "40-41", guide = "RXP_Hardcore/40-41 Alterac/Arathi" },
    { zone = "Badlands",              levels = "41-42", guide = "RXP_Hardcore/41-42 Badlands" },
    { zone = "Stranglethorn Vale",    levels = "42-43", guide = "RXP_Hardcore/42-43 Stranglethorn Vale III" },
    { zone = "Swamp of Sorrows",      levels = "43-44", guide = "RXP_Hardcore/43-44 Swamp of Sorrows II" },
    { zone = "Tanaris",               levels = "44-45", guide = "RXP_Hardcore/44-45 Tanaris" },
    { zone = "Feralas",               levels = "45-46", guide = "RXP_Hardcore/45-46 Feralas" },
    { zone = "Hinterlands/Badlands",  levels = "46-47", guide = "RXP_Hardcore/46-47 Hinterlands/Badlands" },
    { zone = "Tanaris",               levels = "47-48", guide = "RXP_Hardcore/47-48 Tanaris" },
    { zone = "STV/Hinterlands",       levels = "48-49", guide = "RXP_Hardcore/48-49 STV/Hinterlands II" },
    { zone = "Searing Gorge",         levels = "49-50", guide = "RXP_Hardcore/49-50 Searing Gorge" },
    { zone = "Tanaris/Un'Goro",       levels = "50-51", guide = "RXP_Hardcore/50-51 Tanaris/Un'goro" },
    { zone = "Blasted Lands",         levels = "51-52", guide = "RXP_Hardcore/51-52 Blasted Lands" },
    { zone = "Searing Gorge/WPL",     levels = "52-52", guide = "RXP_Hardcore/52-52 Searing Gorge/WPL" },
    { zone = "Felwood",               levels = "52-53", guide = "RXP_Hardcore/52-53 Felwood" },
    { zone = "Feralas/Azshara",       levels = "53-54", guide = "RXP_Hardcore/53-54 Feralas/Azshara" },
    { zone = "Un'Goro Crater",        levels = "54-55", guide = "RXP_Hardcore/54-55 Un'Goro" },
    { zone = "Felwood",               levels = "55-56", guide = "RXP_Hardcore/55-56 Felwood II" },
    { zone = "Burning Steppes",       levels = "56-57", guide = "RXP_Hardcore/56-57 Burning Steppes" },
    { zone = "Plaguelands",           levels = "57-58", guide = "RXP_Hardcore/57-58 Western/Eastern Plaguelands" },
    { zone = "Felwood/Winterspring",  levels = "58-59", guide = "RXP_Hardcore/58-59 Felwood/Winterspring" },
    { zone = "Winterspring/Silithus", levels = "59-60", guide = "RXP_Hardcore/59-60 Winterspring/Silithus part 1" },
    { zone = "Winterspring/Silithus", levels = "59-60", guide = "RXP_Hardcore/59-60 Winterspring/Silithus part 2" },
}

local RXPHardcoreHordeSharedPath = {
    { zone = "Silverpine Forest",            levels = "13-15", guide = "RXP_Hardcore/13-15 Silverpine Forest" },
    { zone = "The Barrens",                  levels = "15-19", guide = "RXP_Hardcore/15-19 The Barrens" },
    { zone = "Stonetalon/Barrens/Ashenvale", levels = "19-23", guide = "RXP_Hardcore/19-23 Stonetalon/Barrens/Ashenvale" },
    { zone = "Hillsbrad",                    levels = "23-25", guide = "RXP_Hardcore/23-25 Hillsbrad" },
    { zone = "Southern Barrens/Stonetalon",  levels = "25-27", guide = "RXP_Hardcore/25-27 Southern Barrens/Stonetalon" },
    { zone = "Ashenvale",                    levels = "27-29", guide = "RXP_Hardcore/27-29 Ashenvale" },
    { zone = "Thousand Needles",             levels = "29-31", guide = "RXP_Hardcore/29-31 Thousand Needles" },
    { zone = "Hillsbrad/Arathi",             levels = "31-34", guide = "RXP_Hardcore/31-34 Hillsbrad/Arathi" },
    { zone = "Shimmering Flats",             levels = "34-35", guide = "RXP_Hardcore/34-35 Shimmering Flats" },
    { zone = "Desolace",                     levels = "35-37", guide = "RXP_Hardcore/35-37 Desolace Horde" },
    { zone = "Northern STV",                 levels = "37-38", guide = "RXP_Hardcore/37-38 Northern Stranglethorn" },
    { zone = "Dustwallow Marsh",             levels = "38-39", guide = "RXP_Hardcore/38-39 Dustwallow Marsh" },
    { zone = "Alterac/Arathi",               levels = "39-41", guide = "RXP_Hardcore/39-41 Alterac/Arathi" },
    { zone = "Stranglethorn Vale",           levels = "42-43", guide = "RXP_Hardcore/42-43 Stranglethorn Vale" },
    { zone = "Desolace",                     levels = "43-43", guide = "RXP_Hardcore/43-43 Desolace II" },
    { zone = "Tanaris/Dustwallow",           levels = "43-45", guide = "RXP_Hardcore/43-45 Tanaris/Dustwallow" },
    { zone = "Southern STV",                 levels = "46-47", guide = "RXP_Hardcore/46-47 Southern Stranglethorn" },
    { zone = "Swamp of Sorrows",             levels = "47-48", guide = "RXP_Hardcore/47-48 Swamp of Sorrows" },
    { zone = "Tanaris",                      levels = "47-49", guide = "RXP_Hardcore/47-49 Tanaris" },
    { zone = "The Hinterlands",              levels = "49-50", guide = "RXP_Hardcore/49-50 The Hinterlands" },
    { zone = "Feralas",                      levels = "50-51", guide = "RXP_Hardcore/50-51 Feralas" },
    { zone = "Stranglethorn/Blasted",        levels = "51-52", guide = "RXP_Hardcore/51-52 Stranglethorn/Blasted Lands" },
    { zone = "Searing Gorge/Burning",        levels = "52-53", guide = "RXP_Hardcore/52-53 Searing Gorge/Burning Steppes" },
    { zone = "Azshara",                      levels = "53-54", guide = "RXP_Hardcore/53-54 Azshara" },
    { zone = "Felwood",                      levels = "54-54", guide = "RXP_Hardcore/54-54 Felwood" },
    { zone = "Un'Goro Crater",               levels = "54-56", guide = "RXP_Hardcore/54-56 Un'Goro Crater" },
    { zone = "Felwood/Winterspring",         levels = "56-57", guide = "RXP_Hardcore/56-57 Felwood/Winterspring" },
    { zone = "Plaguelands",                  levels = "57-59", guide = "RXP_Hardcore/57-59 Western PL/Eastern PL" },
    { zone = "Winterspring/Silithus",        levels = "59-59", guide = "RXP_Hardcore/59-59 Winterspring/Silithus I" },
    { zone = "Winterspring/Silithus",        levels = "59-60", guide = "RXP_Hardcore/59-60 Winterspring/Silithus II" },
}

AegisPathfinder:RegisterRoutePack("RestedXP", {
    displayName = "RestedXP",
    description = "Speedrun-optimized leveling routes (Original RXP Era)",
    routes = {
        Human = MergeRoutes({
            { zone = "Northshire",                    levels = "1-6", guide = "RXP/1-6 Northshire" },
            { zone = "Elwynn Forest",                 levels = "6-11", guide = "RXP/6-11 Elwynn Forest" },
            { zone = "Loch Modan",                    levels = "11-13", guide = "RXP/11-13 Loch Modan" },
            { zone = "Westfall",                      levels = "13-15", guide = "RXP/13-15 Westfall" },
            { zone = "Darkshore",                     levels = "14-16", guide = "RXP/14-16 Darkshore" },
            { zone = "Darkshore",                     levels = "16-19", guide = "RXP/16-19 Darkshore" },
            { zone = "Redridge",                      levels = "19-20", guide = "RXP/19-20 Redridge" },
            { zone = "Darkshore/Ashenvale",           levels = "20-21", guide = "RXP/20-21 Darkshore/Ashenvale" },
            { zone = "Stonetalon/Ashenvale",          levels = "21-23", guide = "RXP/21-23 Stonetalon/Ashenvale" },
        }, RXPAllianceSharedPath),
        Dwarf = MergeRoutes({
            { zone = "Coldridge Valley",              levels = "1-6", guide = "RXP/1-6 Coldridge Valley" },
            { zone = "Dun Morogh",                    levels = "6-11", guide = "RXP/6-11 Dun Morogh (Hunter)" },
            { zone = "Elwynn",                        levels = "11-12", guide = "RXP/11-12 Elwynn (Dwarf/Gnome)" },
            { zone = "Loch Modan",                    levels = "12-14", guide = "RXP/12-14 Loch Modan (Dwarf/Gnome)" },
            { zone = "Westfall",                      levels = "13-15", guide = "RXP/13-15 Westfall" },
            { zone = "Darkshore",                     levels = "14-16", guide = "RXP/14-16 Darkshore" },
            { zone = "Darkshore",                     levels = "16-19", guide = "RXP/16-19 Darkshore" },
            { zone = "Redridge",                      levels = "19-20", guide = "RXP/19-20 Redridge" },
            { zone = "Darkshore/Ashenvale",           levels = "20-21", guide = "RXP/20-21 Darkshore/Ashenvale" },
            { zone = "Stonetalon/Ashenvale",          levels = "21-23", guide = "RXP/21-23 Stonetalon/Ashenvale" },
        }, RXPAllianceSharedPath),
        Gnome = MergeRoutes({
            { zone = "Coldridge Valley",              levels = "1-6", guide = "RXP/1-6 Coldridge Valley" },
            { zone = "Dun Morogh",                    levels = "6-11", guide = "RXP/6-11 Dun Morogh (Hunter)" },
            { zone = "Elwynn",                        levels = "11-12", guide = "RXP/11-12 Elwynn (Dwarf/Gnome)" },
            { zone = "Loch Modan",                    levels = "12-14", guide = "RXP/12-14 Loch Modan (Dwarf/Gnome)" },
            { zone = "Westfall",                      levels = "13-15", guide = "RXP/13-15 Westfall" },
            { zone = "Darkshore",                     levels = "14-16", guide = "RXP/14-16 Darkshore" },
            { zone = "Darkshore",                     levels = "16-19", guide = "RXP/16-19 Darkshore" },
            { zone = "Redridge",                      levels = "19-20", guide = "RXP/19-20 Redridge" },
            { zone = "Darkshore/Ashenvale",           levels = "20-21", guide = "RXP/20-21 Darkshore/Ashenvale" },
            { zone = "Stonetalon/Ashenvale",          levels = "21-23", guide = "RXP/21-23 Stonetalon/Ashenvale" },
        }, RXPAllianceSharedPath),
        NightElf = MergeRoutes({
            { zone = "Shadowglen",                    levels = "1-6", guide = "RXP/1-6 Shadowglen" },
            { zone = "Teldrassil",                    levels = "6-11", guide = "RXP/6-11 Teldrassil" },
            { zone = "Darkshore",                     levels = "14-16", guide = "RXP/14-16 Darkshore" },
            { zone = "Darkshore",                     levels = "16-19", guide = "RXP/16-19 Darkshore" },
            { zone = "Darkshore/Ashenvale",           levels = "19-21", guide = "RXP/19-21 Darkshore/Ashenvale" },
            { zone = "Ashenvale/Stonetalon",          levels = "21-23", guide = "RXP/21-23 Ashenvale/Stonetalon" },
        }, RXPAllianceSharedPath),
        Orc = MergeRoutes({
            { zone = "Durotar",                       levels = "1-6", guide = "RXP/1-6 Durotar" },
            { zone = "Durotar",                       levels = "6-10", guide = "RXP/6-10 Durotar" },
            { zone = "Durotar",                       levels = "10-12", guide = "RXP/10-12 Durotar" },
        }, RXPHordeSharedPath),
        Troll = MergeRoutes({
            { zone = "Durotar",                       levels = "1-6", guide = "RXP/1-6 Durotar" },
            { zone = "Durotar",                       levels = "6-10", guide = "RXP/6-10 Durotar" },
            { zone = "Durotar",                       levels = "10-12", guide = "RXP/10-12 Durotar" },
        }, RXPHordeSharedPath),
        Tauren = MergeRoutes({
            { zone = "Mulgore",                       levels = "1-6", guide = "RXP/1-6 Mulgore" },
            { zone = "Mulgore",                       levels = "6-12", guide = "RXP/6-12 Mulgore" },
        }, RXPHordeSharedPath),
        Undead = MergeRoutes({
            { zone = "Tirisfal Glades",               levels = "1-6", guide = "RXP/1-6 Tirisfal Glades" },
            { zone = "Tirisfal Glades",               levels = "6-11", guide = "RXP/6-11 Tirisfal Glades" },
            { zone = "Silverpine Forest",             levels = "12-14", guide = "RXP/12-14 Silverpine Forest" },
        }, RXPHordeSharedPath),
    },
})

-- RestedXP Hardcore Route Pack - Survival routes (Full 1-60)
AegisPathfinder:RegisterRoutePack("RXP Hardcore", {
    displayName = "RXP Hardcore",
    description = "Hardcore-optimized survival routes (RXP Survival Guide)",
    routes = {
        Human = MergeRoutes({
            { zone = "Northshire",    levels = "1-6",   guide = "RXP_Hardcore/1-6 Northshire" },
            { zone = "Elwynn Forest", levels = "6-11",  guide = "RXP_Hardcore/6-11 Elwynn Forest" },
            { zone = "Loch Modan",    levels = "11-13", guide = "RXP_Hardcore/11-13 Loch Modan" },
        }, RXPHardcoreAllianceSharedPath),
        Dwarf = MergeRoutes({
            { zone = "Coldridge Valley", levels = "1-6",   guide = "RXP_Hardcore/1-6 Coldridge Valley" },
            { zone = "Dun Morogh",       levels = "6-10",  guide = "RXP_Hardcore/6-10 Dun Morogh" },
            { zone = "Elwynn",           levels = "10-11", guide = "RXP_Hardcore/10-11 Elwynn (Dwarf/Gnome)" },
            { zone = "Loch Modan",       levels = "11-13", guide = "RXP_Hardcore/11-13 Loch Modan (Dwarf/Gnome)" },
        }, RXPHardcoreAllianceSharedPath),
        Gnome = MergeRoutes({
            { zone = "Coldridge Valley", levels = "1-6",   guide = "RXP_Hardcore/1-6 Coldridge Valley" },
            { zone = "Dun Morogh",       levels = "6-10",  guide = "RXP_Hardcore/6-10 Dun Morogh" },
            { zone = "Elwynn",           levels = "10-11", guide = "RXP_Hardcore/10-11 Elwynn (Dwarf/Gnome)" },
            { zone = "Loch Modan",       levels = "11-13", guide = "RXP_Hardcore/11-13 Loch Modan (Dwarf/Gnome)" },
        }, RXPHardcoreAllianceSharedPath),
        NightElf = MergeRoutes({
            { zone = "Shadowglen", levels = "1-6",   guide = "RXP_Hardcore/1-6 Shadowglen" },
            { zone = "Teldrassil", levels = "6-11",  guide = "RXP_Hardcore/6-11 Teldrassil" },
            { zone = "Darkshore",  levels = "11-13", guide = "RXP_Hardcore/11-13 Darkshore (Night Elf)" },
            { zone = "Loch Modan", levels = "13-13", guide = "RXP_Hardcore/13-13 Loch Modan (Night Elf)" },
        }, RXPHardcoreAllianceSharedPath),
        Orc = MergeRoutes({
            { zone = "Durotar", levels = "1-6",  guide = "RXP_Hardcore/1-6 Orc/Troll" },
            { zone = "Durotar", levels = "6-13", guide = "RXP_Hardcore/6-13 Orc/Troll" },
        }, RXPHardcoreHordeSharedPath),
        Troll = MergeRoutes({
            { zone = "Durotar", levels = "1-6",  guide = "RXP_Hardcore/1-6 Orc/Troll" },
            { zone = "Durotar", levels = "6-13", guide = "RXP_Hardcore/6-13 Orc/Troll" },
        }, RXPHardcoreHordeSharedPath),
        Tauren = MergeRoutes({
            { zone = "Mulgore", levels = "1-6",  guide = "RXP_Hardcore/1-6 Tauren" },
            { zone = "Mulgore", levels = "6-13", guide = "RXP_Hardcore/6-13 Tauren" },
        }, RXPHardcoreHordeSharedPath),
        Undead = MergeRoutes({
            { zone = "Tirisfal", levels = "1-6",  guide = "RXP_Hardcore/1-6 Undead" },
            { zone = "Tirisfal", levels = "6-13", guide = "RXP_Hardcore/6-13 Undead" },
        }, RXPHardcoreHordeSharedPath),
    },
})

-- Kamisayo Speedrun Route Pack - Horde Warrior speedrun 1-60.
-- Hidden until its guides are added: none of the "(Speedrun)" guides below
-- exist in the addon (the guide is only shared on Kamisayo's Discord), so the
-- pack could only ever stop on its first leg. Characters that had picked it
-- are moved to RestedXP when they log in (Core.lua's InitializeRoute). To
-- bring it back, add the guides and take the comment brackets off.
--[[
local KamisayoRoute = {
    { zone = "Durotar",              levels = "1-13",  guide = "RXP/1-13 Durotar (Speedrun)" },
    { zone = "The Barrens",          levels = "13-16", guide = "RXP/13-16 The Barrens (Speedrun)" },
    { zone = "The Barrens",          levels = "16-22", guide = "RXP/16-22 The Barrens (Speedrun)" },
    { zone = "Stonetalon/Ashenvale", levels = "22-24", guide = "RXP/22-24 Stonetalon/Ashenvale (Speedrun)" },
    { zone = "Thousand Needles",     levels = "24-28", guide = "RXP/24-28 Thousand Needles (Speedrun)" },
    { zone = "Hillsbrad/Arathi",     levels = "28-30", guide = "RXP/28-30 Hillsbrad/Arathi (Speedrun)" },
    { zone = "Stranglethorn Vale",   levels = "30-33", guide = "RXP/30-33 Stranglethorn Vale (Speedrun)" },
    { zone = "Desolace",             levels = "33-34", guide = "RXP/33-34 Desolace (Speedrun)" },
    { zone = "Stranglethorn Vale",   levels = "34-37", guide = "RXP/34-37 Stranglethorn Vale (Speedrun)" },
    { zone = "Arathi/Alterac",       levels = "37-38", guide = "RXP/37-38 Arathi/Alterac (Speedrun)" },
    { zone = "Dustwallow Marsh",     levels = "38-39", guide = "RXP/38-39 Dustwallow Marsh (Speedrun)" },
    { zone = "Stranglethorn Vale",   levels = "39-40", guide = "RXP/39-40 Stranglethorn Vale (Speedrun)" },
    { zone = "Badlands",             levels = "40-41", guide = "RXP/40-41 Badlands (Speedrun)" },
    { zone = "Swamp of Sorrows",     levels = "41-42", guide = "RXP/41-42 Swamp of Sorrows (Speedrun)" },
    { zone = "Stranglethorn Vale",   levels = "42-43", guide = "RXP/42-43 Stranglethorn Vale (Speedrun)" },
    { zone = "Tanaris",              levels = "43-44", guide = "RXP/43-44 Tanaris (Speedrun)" },
    { zone = "Feralas",              levels = "44-46", guide = "RXP/44-46 Feralas (Speedrun)" },
    { zone = "Hinterlands",          levels = "46-49", guide = "RXP/46-49 Hinterlands (Speedrun)" },
    { zone = "Tanaris",              levels = "49-50", guide = "RXP/49-50 Tanaris (Speedrun)" },
    { zone = "Azshara",              levels = "50-51", guide = "RXP/50-51 Azshara (Speedrun)" },
    { zone = "Un'Goro Crater",       levels = "51-52", guide = "RXP/51-52 Un'Goro Crater (Speedrun)" },
    { zone = "Burning Steppes",      levels = "52-54", guide = "RXP/52-54 Burning Steppes (Speedrun)" },
    { zone = "Winterspring",         levels = "54-56", guide = "RXP/54-56 Winterspring (Speedrun)" },
    { zone = "Silithus",             levels = "56-58", guide = "RXP/56-58 Silithus (Speedrun)" },
    { zone = "Plaguelands",          levels = "58-59", guide = "RXP/58-59 Plaguelands (Speedrun)" },
    { zone = "Winterspring",         levels = "59-60", guide = "RXP/59-60 Winterspring (Speedrun)" },
}

AegisPathfinder:RegisterRoutePack("Kamisayo Speedrun", {
    displayName = "Kamisayo Speedrun",
    description = "Horde Warrior speedrun 1-60",
    factionRestriction = "Horde",
    classRestriction = "Warrior",
    routes = {
        Orc = KamisayoRoute,
        Troll = KamisayoRoute,
        Tauren = KamisayoRoute,
        Undead = KamisayoRoute,
        Goblin = KamisayoRoute,
    },
})
]]
