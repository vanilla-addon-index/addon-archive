---
--- MarkerNames.lua - [Atlas-CFM split] display names for World Map marker tooltips.
---
--- Generated from the `Name = ...` field of each AtlasCFM.InstanceData entry in
--- Atlas-CFM_Core\CFMLoot\Data\**. Those data files are only loaded with
--- Atlas-CFM_Core, so hovering a marker before Atlas has been opened uses this
--- table instead (AtlasMapMarkers.lua prefers the real InstanceData once loaded).
---
--- @compatible World of Warcraft 1.12
---

local _G = getfenv()
local AtlasCFM = _G.AtlasCFM

local L = AtlasCFM.Localization.UI
local LZ = AtlasCFM.Localization.Zones
local LB = AtlasCFM.Localization.Bosses
local LF = AtlasCFM.Localization.Factions
local LMD = AtlasCFM.Localization.MapData
local LM = LMD

AtlasCFM.MarkerNames = {}
local N = AtlasCFM.MarkerNames

-- Each entry is evaluated in its own pcall so one missing translation can never
-- break the stub; such a marker simply falls back to its key.
local function add(key, fn)
    local ok, value = pcall(fn)
    if ok and value then N[key] = value end
end

add("TransportRoutes", function() return L["Transport Routes"] end)
add("BlackfathomDeeps", function() return LZ["Blackfathom Deeps"] end)
add("BlackrockDepths", function() return LZ["Blackrock Depths"] end)
add("BlackrockSpireLower", function() return LZ["Lower Blackrock Spire"] end)
add("BlackrockSpireUpper", function() return LZ["Upper Blackrock Spire"] end)
add("BlackwingLair", function() return LZ["Blackwing Lair"] end)
add("DireMaulEast", function() return LZ["Dire Maul (East)"] end)
add("DireMaulWest", function() return LZ["Dire Maul (West)"] end)
add("DireMaulNorth", function() return LZ["Dire Maul (North)"] end)
add("DragonmawRetreat", function() return LZ["Dragonmaw Retreat"] end)
add("EmeraldSanctum", function() return LZ["Emerald Sanctum"] end)
add("FrostmaneHollow", function() return LZ["Frostmane Hollow"] end)
add("GilneasCity", function() return LZ["Gilneas City"] end)
add("Gnomeregan", function() return LZ["Gnomeregan"] end)
add("HateforgeQuarry", function() return LZ["Hateforge Quarry"] end)
add("KarazhanCrypt", function() return LZ["Karazhan Crypt"] end)
add("LowerKarazhan", function() return LZ["Lower Karazhan Halls"] end)
add("Maraudon", function() return LZ["Maraudon"] end)
add("MoltenCore", function() return LZ["Molten Core"] end)
add("Naxxramas", function() return LZ["Naxxramas"] end)
add("OnyxiasLair", function() return LZ["Onyxia's Lair"] end)
add("RagefireChasm", function() return LZ["Ragefire Chasm"] end)
add("RazorfenDowns", function() return LZ["Razorfen Downs"] end)
add("RazorfenKraul", function() return LZ["Razorfen Kraul"] end)
add("TheRuinsofAhnQiraj", function() return LZ["Ruins of Ahn'Qiraj"] end)
add("ScarletMonasteryLibrary", function() return LZ["Scarlet Monastery (Library)"] end)
add("ScarletMonasteryArmory", function() return LZ["Scarlet Monastery (Armory)"] end)
add("ScarletMonasteryCathedral", function() return LZ["Scarlet Monastery (Cathedral)"] end)
add("ScarletMonasteryGraveyard", function() return LZ["Scarlet Monastery (Graveyard)"] end)
add("Scholomance", function() return LZ["Scholomance"] end)
add("ShadowfangKeep", function() return LZ["Shadowfang Keep"] end)
add("StormwindVault", function() return LZ["Stormwind Vault"] end)
add("StormwroughtRuins", function() return LZ["Stormwrought Ruins"] end)
add("Stratholme", function() return LZ["Stratholme"] end)
add("TheTempleofAhnQiraj", function() return LZ["Temple of Ahn'Qiraj"] end)
add("CavernsOfTimeBlackMorass", function() return LZ["The Black Morass"] end)
add("TheCrescentGrove", function() return LZ["The Crescent Grove"] end)
add("TheDeadmines", function() return LZ["The Deadmines"] end)
add("TheStockade", function() return LZ["The Stockade"] end)
add("TheSunkenTemple", function() return LMD["Sunken Temple"] end)
add("TimbermawHold", function() return LZ["Timbermaw Hold"] end)
add("TowerofKarazhan", function() return LZ["Tower of Karazhan"] end)
add("Uldaman", function() return LZ["Uldaman"] end)
add("WailingCaverns", function() return LZ["Wailing Caverns"] end)
add("WindhornCanyon", function() return LZ["Windhorn Canyon"] end)
add("ZulFarrak", function() return LZ["Zul'Farrak"] end)
add("ZulGurub", function() return LZ["Zul'Gurub"] end)
add("BGAlteracValleyNorth", function() return LZ["Alterac Valley"] .. " (" .. L["North"] .. ")" end)
add("BGAlteracValleySouth", function() return LZ["Alterac Valley"] .. " (" .. L["South"] .. ")" end)
add("BGArathiBasin", function() return LZ["Arathi Basin"] end)
add("BGWarsongGulch", function() return LZ["Warsong Gulch"] end)
add("Azuregos", function() return LB["Azuregos"] end)
add("Clackora", function() return LB["Cla'ckora"] end)
add("Concavius", function() return LB["Concavius"] end)
add("FourDragons", function() return LMD["Emerald Dragons"] end)
add("KingMosh", function() return LB["King Mosh"] end)
add("Kurinnaxx", function() return LB["Kurinnaxx"] end)
add("LadyHederine", function() return LB["Lady Hederine"] end)
add("LordKazzak", function() return LB["Lord Kazzak"] end)
add("Nerubian", function() return LB["Nerubian Overseer"] end)
add("Ostarius", function() return LB["Ostarius"] end)
add("Reaver", function() return LB["Dark Reaver of Karazhan"] end)
add("TeremustheDevourer", function() return LB["Teremus the Devourer"] end)
