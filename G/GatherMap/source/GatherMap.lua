-- Gather Map - self-learning resource markers for Turtle WoW / Vanilla 1.12.

local ADDON = "Gather Map"
local MAX_PINS = 300
local UPDATE_INTERVAL = 0.10
local DUPLICATE_DISTANCE = 0.004 -- 0.4 map percentage points, as used by classic Gatherer.
local WORLD_ICON_SIZE = 16
local MINIMAP_ICON_SIZE = 16
local minimapScaleSlider = nil
local worldMapScaleSlider = nil
local GRAY_MARKER_OPACITY = 0.85
local TRACKING_FADE_YARDS = 200 -- Approximate detection radius; server visibility may vary.
local TRACKING_FADE_TRANSITION = 20
local TRACKING_FADE_ALPHA = 0

local function ActiveResourceTracking()
    -- Vanilla exposes the current tracking texture, independent of client language.
    if not GetTrackingTexture then return "both" end
    local texture = GetTrackingTexture()
    if type(texture) ~= "string" then return nil end
    texture = string.lower(texture)
    if string.find(texture, "inv_misc_flower_02", 1, true) then return "herb" end
    if string.find(texture, "spell_nature_earthquake", 1, true) then return "mineral" end
    return nil
end

local function TrackingNodeAlpha(kind, distance, tracking)
    if (kind ~= "herb" and kind ~= "mineral") or
        (tracking ~= kind and tracking ~= "both") then return 1 end
    local fraction = math.max(0, math.min(1,
        (distance - TRACKING_FADE_YARDS) / TRACKING_FADE_TRANSITION))
    return TRACKING_FADE_ALPHA + (1 - TRACKING_FADE_ALPHA) * fraction
end

local frame = CreateFrame("Frame", "GatherMapFrame")
local pins = {}
local worldPins = {}
local worldMapCheckbox = nil
local optionsFrame = nil
local minimapButton = nil
local trackingCheckboxes = {}
local minimapVisibleCheckbox = nil
local worldMapVisibleCheckbox = nil
local presetCheckboxes = {}
local resourceCheckboxes = {}
local presetCacheZone = nil
local presetCacheNodes = {}

-- These categories filter only the display of saved personal nodes.
-- Learning is ALWAYS active, regardless of visibility settings.
local trackingCategories = {
    { "herb", "Herbalism" },
    { "mineral", "Mining" },
    { "skin", "Skinning" },
    { "wood", "Woodcutting" },
    { "lock", "Lockpicking" },
    { "treasure", "Treasure Chests" },
}

local function IsCategoryTracked(kind)
    return not GatherMapDB or not GatherMapDB.tracked or
        GatherMapDB.tracked[kind or "herb"] ~= false
end
local elapsedSinceUpdate = 0
local elapsedSinceWorldUpdate = 0
local pendingNode = nil
local pendingRequirement = nil
local pendingKind = nil
local pendingTexture = nil
local pendingGather = false
local pendingLootUntil = 0
local lastRecordedName = nil
local lastRecordedKind = nil
local lastRecordedTime = 0
local lastInteractTime = 0
local interactWrapper = nil

-- Zone-name lookup is intentional. Clients with additional maps may have numeric
-- zone indices that do not match the original 1.12 indices used by old Gatherer.
local zoneScale = {
    ["Ashenvale"] = 0.15670371525706, ["Azshara"] = 0.13779501505279,
    ["Darkshore"] = 0.17799008894522, ["Darnassus"] = 0.02876626176374,
    ["Desolace"] = 0.12219839120669, ["Durotar"] = 0.14368294970080,
    ["Dustwallow Marsh"] = 0.14266384095509, ["Felwood"] = 0.15625084006464,
    ["Feralas"] = 0.18885970960818, ["Moonglade"] = 0.06292695969921,
    ["Mulgore"] = 0.13960673216274, ["Orgrimmar"] = 0.03811449638057,
    ["Silithus"] = 0.09468465888932, ["Stonetalon Mountains"] = 0.13272833611061,
    ["Tanaris"] = 0.18750104661175, ["Teldrassil"] = 0.13836131003639,
    ["The Barrens"] = 0.27539211944292, ["Barrens"] = 0.27539211944292,
    ["Thousand Needles"] = 0.11956582877920, ["Thunder Bluff"] = 0.02836291430658,
    ["Un'Goro Crater"] = 0.10054401185671, ["Winterspring"] = 0.19293573573141,

    ["Alterac Mountains"] = 0.07954563533736, ["Arathi Highlands"] = 0.10227310921644,
    ["Badlands"] = 0.07066771883566, ["Blasted Lands"] = 0.09517074521836,
    ["Burning Steppes"] = 0.08321525646393, ["Deadwind Pass"] = 0.07102298961531,
    ["Dun Morogh"] = 0.13991525534426, ["Duskwood"] = 0.07670475476181,
    ["Eastern Plaguelands"] = 0.10996723642661, ["Elwynn Forest"] = 0.09860350595046,
    ["Hillsbrad Foothills"] = 0.09090931690055, ["Ironforge"] = 0.02248317426784,
    ["Loch Modan"] = 0.07839152145224, ["Redridge Mountains"] = 0.06170112311456,
    ["Searing Gorge"] = 0.06338794005823, ["Silverpine Forest"] = 0.11931848806212,
    ["Stormwind City"] = 0.03819701270887, ["Stormwind"] = 0.03819701270887,
    ["Stranglethorn Vale"] = 0.18128603034401, ["Swamp of Sorrows"] = 0.06516347991404,
    ["The Hinterlands"] = 0.10937523495111, ["Hinterlands"] = 0.10937523495111,
    ["Tirisfal Glades"] = 0.12837403412087, ["Undercity"] = 0.02727719546939,
    ["Western Plaguelands"] = 0.12215946583965, ["Westfall"] = 0.09943208435841,
    ["Wetlands"] = 0.11745423014662,
}

-- World dimensions for supported custom outdoor and event zones.
-- Values are width and height in world yards.
-- Zone additions that remain inside a Vanilla map (for example Tirisfal
-- Uplands) already use that parent zone's scale and do not need another entry.
local customZoneSize = {
    ["Hyjal"] = { 3206.00, 2142.00 },
    ["Scarlet Enclave"] = { 3159.00, 2108.00 },
    ["Lapidis Isle"] = { 2901.45, 1915.90 },
    ["Gillijim's Isle"] = { 3092.10, 2047.00 },
    ["Tel'Abim"] = { 3227.00, 2187.00 },
    ["Alah'Thalas"] = { 1468.00, 976.00 },
    ["Gilneas"] = { 3666.00, 2442.00 },
    ["Icepoint Rock"] = { 1608.00, 1075.00 },
    ["Blackstone Island"] = { 2472.00, 1665.00 },
    ["Thalassian Highlands"] = { 3082.00, 2061.00 },
    ["Winter Veil Vale"] = { 1432.00, 977.00 },
    ["Grim Reaches"] = { 5387.00, 3584.00 },
    ["Balor"] = { 3098.00, 2068.00 },
    ["Northwind"] = { 3241.00, 2157.00 },
    ["Moonwhisper Coast"] = { 7856.00, 5241.00 },
}

-- Names seen in older client data, on the website, or with capitalization
-- differences are normalized to the current English WorldMapArea names.
local zoneAliases = {
    ["Mount Hyjal"] = "Hyjal",
    ["Island of Lapidis"] = "Lapidis Isle",
    ["Tel'abim"] = "Tel'Abim",
    ["Alah'thalas"] = "Alah'Thalas",
}

local minimapZoomYards = {
    [0] = { [0] = 300, [1] = 240, [2] = 180, [3] = 120, [4] = 80, [5] = 50 },
    [1] = { [0] = 466.6667, [1] = 400, [2] = 333.3333, [3] = 266.6667,
        [4] = 200, [5] = 133.3333 },
}

local continentScale = {
    [1] = {
        { 11016.6, 7399.9 }, { 12897.3, 8638.1 }, { 15478.8, 10368.0 },
        { 19321.8, 12992.7 }, { 25650.4, 17253.2 }, { 38787.7, 26032.1 },
    },
    [2] = {
        { 10448.3, 7072.7 }, { 12160.5, 8197.8 }, { 14703.1, 9825.0 },
        { 18568.7, 12472.2 }, { 24390.3, 15628.5 }, { 37012.2, 25130.6 },
    },
}

-- Minimum gathering requirements. Unknown/custom resources learn
-- their requirement from the object tooltip and save it with the location.
local herbRequirements = {
    ["Peacebloom"] = 1, ["Silverleaf"] = 1, ["Earthroot"] = 15,
    ["Mageroyal"] = 50, ["Briarthorn"] = 70, ["Stranglekelp"] = 85,
    ["Bruiseweed"] = 100, ["Wild Steelbloom"] = 115, ["Grave Moss"] = 120,
    ["Kingsblood"] = 125, ["Liferoot"] = 150, ["Fadeleaf"] = 160,
    ["Goldthorn"] = 170, ["Khadgar's Whisker"] = 185, ["Wintersbite"] = 195,
    ["Firebloom"] = 205, ["Purple Lotus"] = 210, ["Arthas' Tears"] = 220,
    ["Sungrass"] = 230, ["Blindweed"] = 235, ["Ghost Mushroom"] = 245,
    ["Gromsblood"] = 250, ["Golden Sansam"] = 260, ["Dreamfoil"] = 270,
    ["Mountain Silversage"] = 280, ["Plaguebloom"] = 285, ["Icecap"] = 290,
    ["Black Lotus"] = 300,
}

local mineralRequirements = {
    ["Copper Vein"] = 1,
    ["Ooze Covered Copper Vein"] = 1,
    ["Tin Vein"] = 65,
    ["Ooze Covered Tin Vein"] = 65,
    ["Silver Vein"] = 75,
    ["Ooze Covered Silver Vein"] = 75,
    ["Iron Deposit"] = 125,
    ["Ooze Covered Iron Deposit"] = 125,
    ["Gold Vein"] = 155,
    ["Ooze Covered Gold Vein"] = 155,
    ["Mithril Deposit"] = 175,
    ["Ooze Covered Mithril Deposit"] = 175,
    ["Truesilver Deposit"] = 230,
    ["Ooze Covered Truesilver Deposit"] = 230,
    ["Dark Iron Deposit"] = 230,
    ["Small Thorium Vein"] = 245,
    ["Ooze Covered Thorium Vein"] = 245,
    ["Rich Thorium Vein"] = 275,
    ["Ooze Covered Rich Thorium Vein"] = 275,
    ["Hakkari Thorium Vein"] = 275,
    ["Small Obsidian Chunk"] = 305,
    ["Large Obsidian Chunk"] = 305,
}

local miningLootNodes = {
    ["Copper Ore"] = "Copper Vein",
    ["Tin Ore"] = "Tin Vein",
    ["Silver Ore"] = "Silver Vein",
    ["Iron Ore"] = "Iron Deposit",
    ["Gold Ore"] = "Gold Vein",
    ["Mithril Ore"] = "Mithril Deposit",
    ["Truesilver Ore"] = "Truesilver Deposit",
    ["Dark Iron Ore"] = "Dark Iron Deposit",
    -- Thorium Ore alone cannot tell us whether Interact used a Small or Rich
    -- vein, so keep the generic fallback purple instead of guessing wrongly.
    ["Thorium Ore"] = "Thorium Vein",
    ["Small Obsidian Shard"] = "Small Obsidian Chunk",
    ["Large Obsidian Shard"] = "Large Obsidian Chunk",
}

-- Ordinary treasure chests have no skill requirement in the client tooltip.
-- These levels represent the chest tier, so their color follows character
-- level instead of a profession. Unknown/custom chest tiers remain purple.
local treasureLevels = {
    ["Battered Chest"] = 5,
    ["Tattered Chest"] = 15,
    ["Solid Chest"] = 20,
    ["Large Battered Chest"] = 25,
    ["Large Iron Bound Chest"] = 30,
    ["Large Solid Chest"] = 35,
    ["Buccaneer's Strongbox"] = 40,
    ["Bound Chest"] = 45,
    ["Large Mithril Bound Chest"] = 50,
    ["Large Darkwood Chest"] = 55,
}

local treeRequirements = {
    ["Simple Wood Tree"] = 5,
    ["Bright Wood Tree"] = 125,
    ["Shade Wood Tree"] = 175,
    ["Tropical Wood Tree"] = 225,
    ["Dead Wood Tree"] = 250,
    ["Star Wood Tree"] = 270,
}

local woodLootNodes = {
    ["Simple Wood"] = "Simple Wood Tree",
    ["Bright Wood"] = "Bright Wood Tree",
    ["Shade Wood"] = "Shade Wood Tree",
    ["Tropical Wood"] = "Tropical Wood Tree",
    ["Star Wood"] = "Star Wood Tree",
}

local resourceSkills = {
    herb = "Herbalism",
    mineral = "Mining",
    skin = "Skinning",
    lock = "Lockpicking",
    wood = "Survival",
}

local iconRoot = "Interface\\AddOns\\GatherMap\\Icons\\"
local herbIcons = {
    ["Peacebloom"] = iconRoot .. "HerbPeacebloom",
    ["Silverleaf"] = iconRoot .. "HerbSilverleaf",
    ["Earthroot"] = iconRoot .. "HerbEarthroot",
    ["Mageroyal"] = iconRoot .. "HerbMageroyal",
    ["Briarthorn"] = iconRoot .. "HerbBriarthorn",
    ["Stranglekelp"] = iconRoot .. "HerbStranglekelp",
    ["Bruiseweed"] = iconRoot .. "HerbBruiseweed",
    ["Wild Steelbloom"] = iconRoot .. "HerbWildSteelbloom",
    ["Grave Moss"] = iconRoot .. "HerbGraveMoss",
    ["Kingsblood"] = iconRoot .. "HerbKingsblood",
    ["Liferoot"] = iconRoot .. "HerbLiferoot",
    ["Fadeleaf"] = iconRoot .. "HerbFadeleaf",
    ["Goldthorn"] = iconRoot .. "HerbGoldthorn",
    ["Khadgar's Whisker"] = iconRoot .. "HerbKhadgarsWhisker",
    ["Wintersbite"] = iconRoot .. "HerbWintersbite",
    ["Firebloom"] = iconRoot .. "HerbFirebloom",
    ["Purple Lotus"] = iconRoot .. "HerbPurpleLotus",
    ["Arthas' Tears"] = iconRoot .. "HerbArthasTears",
    ["Sungrass"] = iconRoot .. "HerbSungrass",
    ["Blindweed"] = iconRoot .. "HerbBlindweed",
    ["Ghost Mushroom"] = iconRoot .. "HerbGhostMushroom",
    ["Gromsblood"] = iconRoot .. "HerbGromsblood",
    ["Golden Sansam"] = iconRoot .. "HerbGoldenSansam",
    ["Dreamfoil"] = iconRoot .. "HerbDreamfoil",
    ["Mountain Silversage"] = iconRoot .. "HerbMountainSilversage",
    ["Plaguebloom"] = iconRoot .. "HerbPlaguebloom",
    ["Icecap"] = iconRoot .. "HerbIcecap",
    ["Black Lotus"] = iconRoot .. "HerbBlackLotus",
}

local mineralIcons = {
    ["Copper Vein"] = "Interface\\Icons\\INV_Ore_Copper_01",
    ["Dark Iron Deposit"] = "Interface\\Icons\\INV_Ore_Mithril_01",
    ["Gemstone Deposit"] = "Interface\\Icons\\INV_Misc_Gem_Topaz_02",
    ["Gold Vein"] = "Interface\\Icons\\inv_ore_gold_01",
    ["Hakkari Thorium Vein"] = "Interface\\Icons\\INV_Ore_Thorium_02",
    ["Incendicite Mineral Vein"] = "Interface\\Icons\\INV_Ore_Thorium_01",
    ["Indurium Mineral Vein"] = "Interface\\Icons\\INV_Ore_Mithril_01",
    ["Iron Deposit"] = "Interface\\Icons\\inv_ore_iron_02",
    ["Large Obsidian Chunk"] = "Interface\\Icons\\INV_Stone_15",
    ["Lesser Bloodstone Deposit"] = "Interface\\Icons\\INV_Ore_Thorium_01",
    ["Mithril Deposit"] = "Interface\\Icons\\INV_Ore_Mithril_02",
    ["Rich Thorium Vein"] = "Interface\\Icons\\INV_Ore_Thorium_02",
    ["Silver Vein"] = "Interface\\Icons\\INV_Stone_16",
    ["Small Obsidian Chunk"] = "Interface\\Icons\\obsidian_stone_01",
    ["Small Thorium Vein"] = "Interface\\Icons\\INV_Ore_Thorium_02",
    ["Thorium Vein"] = "Interface\\Icons\\INV_Ore_Thorium_02",
    ["Tin Vein"] = "Interface\\Icons\\INV_Ore_Tin_01",
    ["Truesilver Deposit"] = "Interface\\Icons\\INV_Ore_TrueSilver_01",
}

-- GetItemInfo can return no texture when an item is not cached yet. Keep the
-- Vanilla Skinning materials explicit so that falling back never makes a low-
-- level leather look like Rugged Leather.
local skinIcons = {
    ["Ruined Leather Scraps"] = "Interface\\Icons\\INV_Misc_Pelt_Bear_Ruin_05",
    ["Light Leather"] = "Interface\\Icons\\INV_Misc_LeatherScrap_03",
    ["Light Hide"] = "Interface\\Icons\\INV_Misc_Pelt_Wolf_Ruin_02",
    ["Medium Leather"] = "Interface\\Icons\\INV_Misc_LeatherScrap_05",
    ["Medium Hide"] = "Interface\\Icons\\INV_Misc_Pelt_Boar_Ruin_02",
    ["Heavy Leather"] = "Interface\\Icons\\INV_Misc_LeatherScrap_07",
    ["Heavy Hide"] = "Interface\\Icons\\INV_Misc_Pelt_Wolf_Ruin_03",
    ["Thick Leather"] = "Interface\\Icons\\INV_Misc_LeatherScrap_08",
    ["Thick Hide"] = "Interface\\Icons\\INV_Misc_Pelt_Bear_Ruin_01",
    ["Rugged Leather"] = "Interface\\Icons\\INV_Misc_LeatherScrap_02",
    ["Rugged Hide"] = "Interface\\Icons\\INV_Misc_Pelt_Bear_Ruin_02",
    ["Thin Kodo Leather"] = "Interface\\Icons\\INV_Misc_LeatherScrap_06",
    ["Thick Wolfhide"] = "Interface\\Icons\\INV_Misc_Pelt_02",
    ["Shadowcat Hide"] = "Interface\\Icons\\INV_Misc_Pelt_01",
    ["Warbear Leather"] = "Interface\\Icons\\INV_Misc_Pelt_Bear_Ruin_05",
    ["Frostsaber Leather"] = "Interface\\Icons\\INV_Misc_Pelt_06",
    ["Chimera Leather"] = "Interface\\Icons\\INV_Misc_LeatherScrap_01",
    ["Devilsaur Leather"] = "Interface\\Icons\\INV_Misc_Pelt_03",
    ["Primal Bat Leather"] = "Interface\\Icons\\INV_Misc_Pelt_01",
    ["Primal Tiger Leather"] = "Interface\\Icons\\INV_Misc_Pelt_04",
    ["Core Leather"] = "Interface\\Icons\\INV_Ammo_FireTar",
    ["Pristine Hide of the Beast"] = "Interface\\Icons\\INV_Misc_MonsterScales_15",
}

local woodIcons = {
    ["Simple Wood Tree"] = "Interface\\Icons\\simple_wood_1",
    ["Bright Wood Tree"] = "Interface\\Icons\\oak_wood_1",
    ["Shade Wood Tree"] = "Interface\\Icons\\pine_wood_1",
    ["Tropical Wood Tree"] = "Interface\\Icons\\tropical_logs_1",
    ["Dead Wood Tree"] = "Interface\\Icons\\star_log_2",
    ["Star Wood Tree"] = "Interface\\Icons\\star_log_2",
}

local fallbackIcons = {
    mineral = "Interface\\Icons\\INV_Pick_02",
    skin = "Interface\\Icons\\INV_Misc_LeatherScrap_02",
    lock = "Interface\\Icons\\INV_Misc_Key_03",
    treasure = "Interface\\Icons\\INV_Misc_Chest_01",
    wood = "Interface\\Icons\\INV_Axe_01",
}

local colors = {
    red    = { 1.00, 0.12, 0.12 },
    orange = { 1.00, 0.50, 0.00 },
    yellow = { 1.00, 0.90, 0.10 },
    green  = { 0.20, 1.00, 0.20 },
    gray   = { 0.55, 0.55, 0.55 },
    unknown = { 0.70, 0.35, 1.00 },
}

local difficultyPriority = {
    unknown = 0, gray = 1, green = 2, yellow = 3, orange = 4, red = 5,
}

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff68cc70" .. ADDON .. ":|r " .. message)
end

local function GetSkillRank(skillName)
    local i
    for i = 1, GetNumSkillLines() do
        local name, isHeader, _, rank = GetSkillLineInfo(i)
        if not isHeader and name == skillName then
            return tonumber(rank) or 0
        end
    end
    return 0
end

local function GetResourceSkillRanks()
    return {
        herb = GetSkillRank("Herbalism"),
        mineral = GetSkillRank("Mining"),
        skin = GetSkillRank("Skinning"),
        lock = GetSkillRank("Lockpicking"),
        wood = GetSkillRank("Survival"),
    }
end

local function GetHerbalismSkill()
    return GetSkillRank("Herbalism")
end

local function Difficulty(required, skill)
    if not required then return "unknown" end
    if skill < required then return "red" end
    if skill < required + 25 then return "orange" end
    if skill < required + 50 then return "yellow" end
    if skill < required + 100 then return "green" end
    return "gray"
end

local function LevelDifficulty(requiredLevel, playerLevel)
    if not requiredLevel then return "unknown" end
    local difference = requiredLevel - playerLevel
    if difference >= 6 then return "red" end
    if difference >= 3 then return "orange" end
    if difference >= -2 then return "yellow" end
    if difference >= -9 then return "green" end
    return "gray"
end

local function RequirementFor(kind, name)
    if kind == "herb" then return herbRequirements[name] end
    if kind == "mineral" then return mineralRequirements[name] end
    if kind == "treasure" then return treasureLevels[name] end
    if kind == "wood" then return treeRequirements[name] end
    return nil
end

local function NodeDifficulty(node, skillRanks)
    local kind = node.kind or "herb"
    local required = node.required or RequirementFor(kind, node.name)
    if kind == "treasure" then
        return LevelDifficulty(required, UnitLevel("player") or 0)
    end
    local skillName = resourceSkills[kind]
    if not skillName then return "unknown" end
    local skill = skillRanks and skillRanks[kind] or GetSkillRank(skillName)
    if not skill or skill <= 0 then return "unknown" end
    return Difficulty(required, skill)
end

-- Visibility is chosen by the player, not by their character's profession.
-- Recorded nodes are account-wide and can be shown on any character.

local function IsMinimapIndoors()
    local temporaryZoom = 0
    local indoors = 1
    if GetCVar("minimapZoom") == GetCVar("minimapInsideZoom") then
        if (GetCVar("minimapInsideZoom") + 0) >= 3 then
            Minimap:SetZoom(Minimap:GetZoom() - 1)
            temporaryZoom = 1
        else
            Minimap:SetZoom(Minimap:GetZoom() + 1)
            temporaryZoom = -1
        end
    end
    if (GetCVar("minimapInsideZoom") + 0) == Minimap:GetZoom() then indoors = 0 end
    Minimap:SetZoom(Minimap:GetZoom() + temporaryZoom)
    return indoors
end

local function CanonicalZoneName(name)
    if not name then return name end
    name = string.gsub(name, "^%s+", "")
    name = string.gsub(name, "%s+$", "")
    return zoneAliases[name] or name
end

local function FindCurrentMapZone()
    local realZone = CanonicalZoneName(GetRealZoneText())
    local continent
    for continent = 1, 2 do
        local zones = { GetMapZones(continent) }
        local zone
        for zone = 1, table.getn(zones) do
            if CanonicalZoneName(zones[zone]) == realZone then
                return continent, zone, realZone
            end
        end
    end
    return nil, nil, realZone
end

local function GetPosition(forceMap)
    local continent, zone, zoneName = FindCurrentMapZone()
    if not continent or not zone then return nil end

    if forceMap and not WorldMapFrame:IsVisible() then
        SetMapZoom(continent, zone)
    end

    local x, y = GetPlayerMapPosition("player")
    if x == 0 and y == 0 and not WorldMapFrame:IsVisible() then
        SetMapZoom(continent, zone)
        x, y = GetPlayerMapPosition("player")
    end
    if x == 0 and y == 0 then return nil end
    return continent, zone, zoneName, x, y
end

local function ReadNodeTooltip(skillName)
    local name = GameTooltipTextLeft1 and GameTooltipTextLeft1:GetText()
    if not name or name == "" then return nil, nil end

    local required = nil
    local i
    for i = 2, GameTooltip:NumLines() do
        local line = getglobal("GameTooltipTextLeft" .. i)
        local text = line and line:GetText()
        if text and (not skillName or string.find(text, skillName)) then
            local _, _, number = string.find(text, "%((%d+)%)")
            if number then required = tonumber(number) end
        end
    end
    return name, required
end

local function IsChestName(name)
    if not name then return false end
    return string.find(name, "Chest") or string.find(name, "Footlocker") or
        string.find(name, "Coffer") or string.find(name, "Strongbox") or
        string.find(name, "Treasure") or string.find(name, "Cache")
end

local function SkinningRequirement(level)
    level = tonumber(level)
    if not level or level <= 0 then return nil end
    -- Vanilla uses two ranges for the highest creature level that can be
    -- skinned: skill / 10 + 10 through skill 100, then skill / 5. Inverting
    -- that rule gives the minimum Skinning skill used by the color bands.
    if level <= 10 then return 1 end
    if level <= 20 then return (level - 10) * 10 end
    return level * 5
end

local function LootItem(message)
    if not message then return nil, nil end
    local _, _, link = string.find(message, "(|c%x+|Hitem:.-|h%[[^%]]+%]|h|r)")
    local _, _, name = string.find(message, "%[([^%]]+)%]")
    local texture, itemType = nil, nil
    if link and GetItemInfo then
        local itemName, itemLink, quality, itemLevel, itemTypeFromInfo, itemSubType,
            stackCount, equipSlot, itemTexture = GetItemInfo(link)
        texture = itemTexture
        -- The item class identifies quest loot even when it is obtained by
        -- skinning.  Texture alone cannot distinguish quest items.
        itemType = itemTypeFromInfo
    end
    return name, texture, itemType
end

local function IsValidSkinningLoot(name, itemType)
    if not name then return false end
    -- Quest items may be skinned from creatures; do not learn their names.
    -- ITEM_CLASS_QUEST is localized on clients that expose it.
    if itemType == "Quest" or (ITEM_CLASS_QUEST and itemType == ITEM_CLASS_QUEST) then
        return false
    end
    -- The client may not yet have cached GetItemInfo for a custom item.
    -- Only learn known skins in that case, rather than recording a quest item
    -- whose class is unknown. Once cached, any non-quest loot is accepted.
    return itemType ~= nil or skinIcons[name] ~= nil
end

-- The shipped pfQuest locations are never copied into SavedVariables.  Decode only
-- the currently requested map; retain just one map to avoid persistent memory use.
local presetAlphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local presetDigits = {}
local presetDigit
for presetDigit = 1, string.len(presetAlphabet) do
    presetDigits[string.sub(presetAlphabet, presetDigit, presetDigit)] = presetDigit - 1
end

local function PresetNodes(zoneName)
    if zoneName == presetCacheZone then return presetCacheNodes end
    presetCacheZone = zoneName
    presetCacheNodes = {}
    local groups = GatherMapPreset and GatherMapPreset[zoneName]
    -- Retain areas missing from shipped locale tables by resolving their IDs in-client.
    if not groups and GatherMapPreset and C_Map and C_Map.GetAreas then
        local areas = C_Map.GetAreas()
        for id, name in pairs(areas or {}) do
            if CanonicalZoneName(name) == zoneName and GatherMapPreset[id] then
                groups = GatherMapPreset[id]
                break
            end
        end
    end
    if not groups then return presetCacheNodes end
    local i
    for i = 1, table.getn(groups) do
        local entry = groups[i]
        local resource = GatherMapPresetCatalog and GatherMapPresetCatalog[entry[1]]
        local name, kind, required, packed
        if resource then
            name, kind, required, packed = resource[1], resource[2], resource[3], entry[2]
        end
        if packed then
            local precision = GatherMapPresetPrecision or 500
            local stride = GatherMapPresetStride or 3
            local j
            for j = 1, string.len(packed) - stride + 1, stride do
                local point, valid = 0, true
                local k
                for k = 0, stride - 1 do
                    local digit = presetDigits[string.sub(packed, j + k, j + k)]
                    if not digit then valid = false break end
                    point = point * 64 + digit
                end
                local xi = math.floor(point / (precision + 1))
                local yi = math.mod(point, precision + 1)
                if valid and xi <= precision and yi <= precision then
                    table.insert(presetCacheNodes, {
                        name = name, kind = kind, required = required,
                        x = xi / precision, y = yi / precision, fromPreset = true,
                    })
                end
            end
        end
    end
    return presetCacheNodes
end

local function MapZoneName(continent, zone)
    if not continent or not zone or zone < 1 then return nil end
    local zones = { GetMapZones(continent) }
    return CanonicalZoneName(zones[zone])
end

local function ResourceEnabled(node)
    local kind = node.kind or "herb"
    local filters = GatherMapDB.resourceFilters and GatherMapDB.resourceFilters[kind]
    return not filters or filters[node.name] ~= false
end

local DatabaseZone
local function EachDisplayNode(continent, zone, zoneName, visit)
    if GatherMapDB.preset.showRecorded ~= false then
        local saved = DatabaseZone(continent, zone, false)
        if saved then
            local i
            for i = 1, table.getn(saved) do
                if IsCategoryTracked(saved[i].kind) and ResourceEnabled(saved[i]) then
                    visit(saved[i])
                end
            end
        end
    end
    if not GatherMapDB.preset.herb and not GatherMapDB.preset.mineral then return end
    local predefined = PresetNodes(zoneName)
    local i
    for i = 1, table.getn(predefined) do
        local node = predefined[i]
        if GatherMapDB.preset[node.kind] and ResourceEnabled(node) then visit(node) end
    end
end

DatabaseZone = function(continent, zone, create)
    local key = tostring(continent) .. ":" .. tostring(zone)
    if create and not GatherMapDB.nodes[key] then GatherMapDB.nodes[key] = {} end
    return GatherMapDB.nodes[key], key
end

local function RecordNode(name, required, kind, texture)
    if not name or name == "" then return end
    kind = kind or "herb"
    local continent, zone, zoneName, x, y = GetPosition(true)
    if not continent then
        Print("Could not read your map position; this zone may need additional map data.")
        return
    end

    required = required or RequirementFor(kind, name)
    local areaName = GetSubZoneText and GetSubZoneText() or ""
    if GetMinimapZoneText then
        local minimapName = GetMinimapZoneText()
        if minimapName and minimapName ~= "" then areaName = minimapName end
    end
    local nodes = DatabaseZone(continent, zone, true)
    local i
    for i = 1, table.getn(nodes) do
        local node = nodes[i]
        if (node.kind or "herb") == kind and node.name == name and
                math.abs(node.x - x) <= DUPLICATE_DISTANCE and
                math.abs(node.y - y) <= DUPLICATE_DISTANCE then
            node.x = (node.x * node.count + x) / (node.count + 1)
            node.y = (node.y * node.count + y) / (node.count + 1)
            node.count = node.count + 1
            if required then node.required = required end
            if texture then node.texture = texture end
            node.kind = kind
            node.zoneName = zoneName
            node.areaName = areaName
            return
        end
    end

    table.insert(nodes, {
        name = name, required = required, x = x, y = y,
        kind = kind, texture = texture, count = 1,
        zoneName = zoneName, areaName = areaName,
    })
end

local function RecordNodeOnce(name, required, kind, texture)
    kind = kind or "herb"
    local now = GetTime()
    if lastRecordedKind == kind and lastRecordedName == name and
            now - lastRecordedTime < 2 then return end
    RecordNode(name, required, kind, texture)
    lastRecordedKind = kind
    lastRecordedName = name
    lastRecordedTime = now
end

local function InstallInteractHook()
    if type(Interact) ~= "function" or Interact == interactWrapper then return end
    -- Wrap the newest implementation if Interact or another addon replaces it.
    -- Capture a separate predecessor for each wrapper. A shared variable would
    -- redirect older wrappers into newer hooks and create a recursive loop.
    local originalInteract = Interact
    interactWrapper = function(autoloot)
        lastInteractTime = GetTime()
        return originalInteract(autoloot)
    end
    Interact = interactWrapper
end

local function ResourceFromLootMessage(message)
    local name, texture = LootItem(message)
    if not name then return nil end
    if herbRequirements[name] then
        return "herb", name, herbRequirements[name], texture
    end
    local nodeName = miningLootNodes[name]
    if nodeName then
        return "mineral", nodeName, mineralRequirements[nodeName], texture
    end
    nodeName = woodLootNodes[name]
    if nodeName then
        return "wood", nodeName, treeRequirements[nodeName], texture
    end
    return nil
end

local actionKinds = {
    ["Herb Gathering"] = "herb",
    ["Mining"] = "mineral",
    ["Skinning"] = "skin",
    ["Woodcutting"] = "wood",
    ["Opening"] = "treasure",
    ["Pick Lock"] = "lock",
}

local function ClearPending()
    pendingNode = nil
    pendingRequirement = nil
    pendingKind = nil
    pendingTexture = nil
    pendingGather = false
    pendingLootUntil = 0
end

local function BeginResourceAction(actionName)
    ClearPending()
    local kind = actionKinds[actionName]
    if not kind then return false end

    local name, required
    if kind == "herb" then
        name, required = ReadNodeTooltip("Herbalism")
        required = required or herbRequirements[name]
    elseif kind == "mineral" then
        name, required = ReadNodeTooltip("Mining")
        required = required or mineralRequirements[name]
    elseif kind == "skin" then
        name = UnitName("target") or "Skinnable creature"
        required = SkinningRequirement(UnitLevel("target"))
    elseif kind == "wood" then
        name, required = ReadNodeTooltip("Survival")
        required = required or treeRequirements[name]
    else
        name, required = ReadNodeTooltip("Lockpicking")
        if kind == "treasure" and treeRequirements[name] then
            kind = "wood"
            local treeName, survivalRequirement = ReadNodeTooltip("Survival")
            name = treeName or name
            required = survivalRequirement or treeRequirements[name]
            -- Some clients report the generic Opening action for trees.
        else
            if not IsChestName(name) then return false end
            if kind == "treasure" and required then kind = "lock" end
            required = required or RequirementFor(kind, name)
        end
    end

    pendingNode = name
    pendingRequirement = required
    pendingKind = kind
    pendingTexture = nil
    pendingGather = true
    pendingLootUntil = 0
    return true
end

-- Self-contained cursor tooltip. This avoids Vanilla tooltip-template and map
-- mouse-layer differences while leaving GameTooltip free for gathering scans.
local markerTooltip = CreateFrame("Frame", "GatherMapMarkerTooltip", UIParent)
markerTooltip:SetFrameStrata("TOOLTIP")
markerTooltip:SetFrameLevel(100)
markerTooltip:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
markerTooltip:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
local markerTooltipText = markerTooltip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
markerTooltipText:SetPoint("TOPLEFT", markerTooltip, "TOPLEFT", 8, -7)
markerTooltipText:SetJustifyH("LEFT")
markerTooltip:Hide()
local hoveredPin = nil

local function ShowMarkerTooltip(pin)
    if not pin.herbNames or not pin.herbNames[1] then return end
    local text = table.concat(pin.herbNames, "\n")
    markerTooltipText:SetText(text)
    markerTooltip:SetWidth(math.max(44, markerTooltipText:GetStringWidth() + 16))
    markerTooltip:SetHeight(math.max(24, table.getn(pin.herbNames) * 14 + 12))
    markerTooltipText:SetWidth(markerTooltip:GetWidth() - 16)
    markerTooltip:Show()
end

local function PositionMarkerTooltip(cursorX, cursorY)
    local scale = markerTooltip:GetEffectiveScale()
    local x, y = cursorX / scale, cursorY / scale
    local width, height = markerTooltip:GetWidth(), markerTooltip:GetHeight()
    if x + width + 3 > UIParent:GetWidth() then x = x - width - 3 else x = x + 3 end
    if y + height + 3 > UIParent:GetHeight() then y = y - height - 3 else y = y + 3 end
    markerTooltip:ClearAllPoints()
    markerTooltip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
end

local function EnableMarkerTooltip(pin)
    -- Use screen coordinates for hover; map layers can intercept OnEnter.
    -- Mouse-disabled markers also preserve normal map clicks and dragging.
    pin:EnableMouse(false)
    local function HideMarkerTooltip()
        if hoveredPin == this then
            hoveredPin = nil
            markerTooltip:Hide()
        end
    end
    pin:SetScript("OnHide", HideMarkerTooltip)
end

local function UpdateMarkerHover()
    local cursorX, cursorY = GetCursorPosition()
    local pool = pins
    if WorldMapFrame and WorldMapFrame:IsVisible() then pool = worldPins end
    local candidate = nil
    local i
    for i = 1, table.getn(pool) do
        local pin = pool[i]
        if pin:IsVisible() and pin.herbNames and pin.herbNames[1] and pin.hitParent then
            local scale = pin.hitParent:GetEffectiveScale()
            local x, y = cursorX / scale, cursorY / scale
            if pin.hitAnchor == "TOPLEFT" then
                x = x - pin.hitParent:GetLeft()
                y = y - pin.hitParent:GetTop()
            else
                local centerX, centerY = pin.hitParent:GetCenter()
                x = x - centerX
                y = y - centerY
            end
            if x >= pin.hitLeft - 3 and x <= pin.hitRight + 3 and
                    y >= pin.hitBottom - 3 and y <= pin.hitTop + 3 then
                candidate = pin
                break
            end
        end
    end
    hoveredPin = candidate
    if candidate then
        ShowMarkerTooltip(candidate)
        PositionMarkerTooltip(cursorX, cursorY)
    else
        markerTooltip:Hide()
    end
end

local function SetMarkerNames(pin, names)
    pin.herbNames = {}
    local name
    for name in pairs(names) do table.insert(pin.herbNames, name) end
    table.sort(pin.herbNames)
    -- Pooled pins can represent a different group after moving or zooming.
    if hoveredPin == pin then ShowMarkerTooltip(pin) end
end

-- Both maps use the complete texture, without corner dots or cropped UVs.
local function CreatePinIcon(pin)
    pin.icon = pin:CreateTexture(nil, "ARTWORK")
    pin.icon:SetAllPoints(pin)
    pin.icon:SetTexCoord(0, 1, 0, 1)
end

local function GetResourceIcon(name, kind, texture)
    kind = kind or "herb"
    if kind == "skin" and skinIcons[name] then return skinIcons[name] end
    if kind == "wood" and woodIcons[name] then return woodIcons[name] end
    if texture and kind ~= "mineral" then return texture end
    if kind == "herb" then return herbIcons[name] or herbIcons["Peacebloom"] end
    if kind == "mineral" then
        local baseName = string.gsub(name or "", "^Ooze Covered ", "")
        return mineralIcons[name] or mineralIcons[baseName] or fallbackIcons.mineral
    end
    return fallbackIcons[kind] or fallbackIcons.treasure
end

-- Group bounds decide placement only; they must never stretch the icon.
local function SetPinBounds(pin, left, right, bottom, top, size, anchorParent, anchorPoint)
    local x, y = (left + right) / 2, (bottom + top) / 2
    pin:SetWidth(size)
    pin:SetHeight(size)
    anchorParent = anchorParent or Minimap
    anchorPoint = anchorPoint or "CENTER"
    pin.hitLeft, pin.hitRight = x - size / 2, x + size / 2
    pin.hitBottom, pin.hitTop = y - size / 2, y + size / 2
    pin.hitParent, pin.hitAnchor = anchorParent, anchorPoint
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", anchorParent, anchorPoint, x, y)
end

local function AcquirePin(index)
    if pins[index] then return pins[index] end
    local pin = CreateFrame("Frame", "GatherMapPin" .. index, Minimap)
    pin:SetWidth(14)
    pin:SetHeight(14)
    if MiniMapTrackingFrame then
        pin:SetFrameLevel(MiniMapTrackingFrame:GetFrameLevel() + 1)
    else
        pin:SetFrameLevel(Minimap:GetFrameLevel() + 5)
    end
    CreatePinIcon(pin)
    pins[index] = pin
    EnableMarkerTooltip(pin)
    return pin
end

local function AcquireWorldPin(index)
    if worldPins[index] then return worldPins[index] end
    local pin = CreateFrame("Frame", "GatherMapWorldPin" .. index, WorldMapButton)
    pin:SetWidth(14)
    pin:SetHeight(14)
    pin:SetFrameLevel(WorldMapButton:GetFrameLevel() + 5)
    CreatePinIcon(pin)
    worldPins[index] = pin
    EnableMarkerTooltip(pin)
    return pin
end

local function BoundsOverlap(a, b)
    return a.left <= b.right and a.right >= b.left and
        a.bottom <= b.top and a.top >= b.bottom
end

local function AddMarkerGroup(groups, x, y, difficulty, resourceName, kind, texture, displayName, trackingAlpha)
    kind = kind or "herb"
    local group = {
        left = x - 7, right = x + 7, bottom = y - 7, top = y + 7,
        difficulty = difficulty,
        trackingAlpha = trackingAlpha or 1,
        resourceKey = kind .. ":" .. (resourceName or ""),
        iconTexture = GetResourceIcon(resourceName, kind, texture),
        names = {},
    }
    if resourceName then group.names[displayName or resourceName] = true end

    -- Recheck after every expansion so chains of overlapping markers become
    -- one group even when the first and last markers do not touch directly.
    local merged = true
    while merged do
        merged = false
        local i
        for i = table.getn(groups), 1, -1 do
            local other = groups[i]
            if group.resourceKey == other.resourceKey and BoundsOverlap(group, other) then
                group.trackingAlpha = math.min(group.trackingAlpha, other.trackingAlpha)
                local name
                for name in pairs(other.names) do group.names[name] = true end
                group.left = math.min(group.left, other.left)
                group.right = math.max(group.right, other.right)
                group.bottom = math.min(group.bottom, other.bottom)
                group.top = math.max(group.top, other.top)
                if difficultyPriority[other.difficulty] > difficultyPriority[group.difficulty] then
                    group.difficulty = other.difficulty
                end
                table.remove(groups, i)
                merged = true
            end
        end
    end
    table.insert(groups, group)
end

local function HidePinsAfter(index)
    local i
    for i = index, table.getn(pins) do pins[i]:Hide() end
end


local function HideWorldPinsAfter(index)
    local i
    for i = index, table.getn(worldPins) do worldPins[i]:Hide() end
end

local controlMinimapHidden = false
local function ControlOverMinimap()
    if not IsControlKeyDown or not IsControlKeyDown() or not Minimap:IsVisible() then return false end
    local cx, cy = Minimap:GetCenter()
    local width, height = Minimap:GetWidth(), Minimap:GetHeight()
    if not cx or not cy or width <= 0 or height <= 0 then return false end
    local x, y = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    local dx, dy = (x / scale - cx) / (width / 2), (y / scale - cy) / (height / 2)
    return dx * dx + dy * dy <= 1
end

local function UpdatePins()
    if ControlOverMinimap() then
        HidePinsAfter(1)
        if hoveredPin and hoveredPin.hitParent == Minimap then
            hoveredPin = nil
            markerTooltip:Hide()
        end
        return
    end
    if not GatherMapDB or not GatherMapDB.enabled then
        HidePinsAfter(1)
        return
    end

    local continent, zone, zoneName, playerX, playerY = GetPosition(false)
    if not continent or (not zoneScale[zoneName] and not customZoneSize[zoneName]
        and not (GatherMapZoneSizes and GatherMapZoneSizes[zoneName])) then
        HidePinsAfter(1)
        return
    end

    local zoom = Minimap:GetZoom() or 0
    local scales = continentScale[continent]
    local minimapScale = scales and scales[zoom + 1]
    local exactSize = (GatherMapZoneSizes and GatherMapZoneSizes[zoneName]) or customZoneSize[zoneName]
    local areaID = GatherMapZoneAreaIDs and GatherMapZoneAreaIDs[zoneName]
    if areaID and C_Map and C_Map.GetMapWorldSize then
        local w, h = C_Map.GetMapWorldSize(areaID)
        if type(w) == "number" and type(h) == "number" and w > 0 and h > 0 then
            exactSize = {w, h}
        end
    end
    local zoomSet = minimapZoomYards[IsMinimapIndoors()]
    local zoomYards = zoomSet and zoomSet[zoom]
    if not exactSize and not minimapScale then HidePinsAfter(1) return end
    if exactSize and not zoomYards then HidePinsAfter(1) return end

    local tracking = ActiveResourceTracking()
    local localScale = zoneScale[zoneName]
    local iconSize = MINIMAP_ICON_SIZE * GatherMapDB.minimapNodeScale
    -- Keep every corner of the square icon inside the circular minimap.
    local radius = math.max(0, math.min(Minimap:GetWidth(), Minimap:GetHeight()) / 2
        - iconSize / math.sqrt(2))
    local groups = {}
    local skillRanks = GetResourceSkillRanks()
    EachDisplayNode(continent, zone, zoneName, function(node)
        local offsetX, offsetY
        if exactSize then
            offsetX = (node.x - playerX) * Minimap:GetWidth() * exactSize[1] / zoomYards
            offsetY = (node.y - playerY) * Minimap:GetHeight() * exactSize[2] / zoomYards
        else
            offsetX = (node.x - playerX) * localScale * minimapScale[1]
            offsetY = (node.y - playerY) * localScale * minimapScale[2]
        end
        -- Cull BEFORE grouping; map database coordinates may contain hundreds
        -- of locations, but only a small neighborhood reaches the minimap.
        if offsetX * offsetX + offsetY * offsetY <= radius * radius then
            local difficulty = NodeDifficulty(node, skillRanks)
            local kind = node.kind or "herb"
            -- Convert each axis separately so the fade distance is independent of zoom.
            local yardsX = offsetX * zoomYards / Minimap:GetWidth()
            local yardsY = offsetY * zoomYards / Minimap:GetHeight()
            local distance = math.sqrt(yardsX * yardsX + yardsY * yardsY)
            local alpha = TrackingNodeAlpha(kind, distance, tracking)
            -- Fully hidden nodes never enter the visible pool or its hover hit-test.
            if alpha > 0 then
                local names = {}; names[node.name] = true
                table.insert(groups, {left=offsetX-7, right=offsetX+7,
                    bottom=-offsetY-7, top=-offsetY+7, names=names,
                    difficulty=difficulty, trackingAlpha=alpha,
                    iconTexture=GetResourceIcon(node.name, kind, node.texture)})
            end
        end
    end)

    if hoveredPin and hoveredPin.hitParent == Minimap then
        hoveredPin = nil
        markerTooltip:Hide()
    end
    local shown = math.min(table.getn(groups), MAX_PINS)
    for i = 1, shown do
        local group = groups[i]
        local pin = AcquirePin(i)
        SetMarkerNames(pin, group.names)
        pin.icon:SetTexture(group.iconTexture)
        pin:SetAlpha((group.difficulty == "gray" and GRAY_MARKER_OPACITY or 1.0)
            * group.trackingAlpha)
        SetPinBounds(pin, group.left, group.right, group.bottom, group.top, iconSize)
        pin:Show()
    end
    HidePinsAfter(shown + 1)
end


local function UpdateWorldMapPins()
    if not GatherMapDB or not GatherMapDB.worldMapEnabled or
            not WorldMapFrame or not WorldMapFrame:IsVisible() then
        HideWorldPinsAfter(1)
        return
    end

    local continent = GetCurrentMapContinent()
    local zone = GetCurrentMapZone()
    if not continent or not zone or continent <= 0 or zone <= 0 then
        HideWorldPinsAfter(1)
        return
    end

    local width = WorldMapButton:GetWidth()
    local height = WorldMapButton:GetHeight()
    if not width or not height or width <= 0 or height <= 0 then
        HideWorldPinsAfter(1)
        return
    end

    local groups = {}
    local skillRanks = GetResourceSkillRanks()
    EachDisplayNode(continent, zone, MapZoneName(continent, zone), function(node)
        local x = node.x * width
        local y = -node.y * height
        AddMarkerGroup(groups, x, y, NodeDifficulty(node, skillRanks),
            node.name, node.kind or "herb", node.texture, nil)
    end)

    local shown = table.getn(groups)
    for i = 1, shown do
        local group = groups[i]
        local pin = AcquireWorldPin(i)
        SetMarkerNames(pin, group.names)
        pin.icon:SetTexture(group.iconTexture)
        pin:SetAlpha(group.difficulty == "gray" and GRAY_MARKER_OPACITY or 1.0)
        SetPinBounds(pin, group.left, group.right, group.bottom, group.top,
            WORLD_ICON_SIZE * GatherMapDB.worldMapNodeScale, WorldMapButton, "TOPLEFT")
        pin:Show()
    end
    HideWorldPinsAfter(shown + 1)
end


local function CreateWorldMapCheckbox()
    if worldMapCheckbox or not WorldMapFrame then return end
    worldMapCheckbox = CreateFrame("CheckButton", "GatherMapWorldMapToggle",
        WorldMapFrame, "UICheckButtonTemplate")
    worldMapCheckbox:SetWidth(24)
    worldMapCheckbox:SetHeight(24)
    worldMapCheckbox:SetPoint("TOPLEFT", WorldMapFrame, "TOPLEFT", 18, -42)
    worldMapCheckbox:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 10)
    local label = getglobal("GatherMapWorldMapToggleText")
    if label then
        label:SetText("Gather Map")
        label:SetTextColor(0.41, 0.80, 0.44)
    end
    worldMapCheckbox:SetChecked(GatherMapDB.worldMapEnabled)
    worldMapCheckbox:SetScript("OnClick", function()
        GatherMapDB.worldMapEnabled = this:GetChecked() and true or false
        UpdateWorldMapPins()
        if worldMapVisibleCheckbox then
            worldMapVisibleCheckbox:SetChecked(GatherMapDB.worldMapEnabled)
        end
    end)
end

-- Shared-data transfer, intentionally limited to personal learned nodes.
-- Never execute imported text as Lua: the GM1 format is a validated data format.
-- The built-in pfQuest preset and all preferences stay local to this client.
local TRANSFER_PART_LIMIT = 3400
local TRANSFER_MAX_PARTS = 500
local TRANSFER_MAX_NODES = 50000
local transferParts = nil
local transferPageIndex = 1
local incomingTransfer = nil

local function TransferHash(value)
    local hash, i = 5381, 1
    for i = 1, string.len(value) do
        hash = math.mod(hash * 33 + string.byte(value, i), 2147483647)
    end
    return string.format("%08X", hash)
end

-- Encode all punctuation, delimiters, percent signs and UTF-8 bytes.
-- Only ASCII letters, digits, underscores and spaces remain unescaped.
local function TransferEncode(value)
    local encoded = string.gsub(tostring(value or ""), "([^%w_ ])", function(char)
        return string.format("%%%02X", string.byte(char))
    end)
    return encoded
end

local function TransferDecode(value)
    local result = {}
    local i = 1
    while i <= string.len(value) do
        local ch = string.sub(value, i, i)
        if ch == "%" then
            local hex = string.sub(value, i + 1, i + 2)
            if string.len(hex) ~= 2 or not string.find(hex, "^%x%x$") then return nil end
            table.insert(result, string.char(tonumber(hex, 16)))
            i = i + 3
        elseif string.find(ch, "^[%w_ ]$") then
            table.insert(result, ch)
            i = i + 1
        else
            return nil
        end
    end
    return table.concat(result)
end

local function TransferSplit(text, delimiter, expected)
    local fields, offset = {}, 1
    while true do
        local found = string.find(text, delimiter, offset, true)
        if not found then
            table.insert(fields, string.sub(text, offset))
            break
        end
        table.insert(fields, string.sub(text, offset, found - 1))
        if table.getn(fields) >= expected then return nil end
        offset = found + string.len(delimiter)
    end
    if table.getn(fields) ~= expected then return nil end
    return fields
end

local function ExportPersonalNodes()
    local zoneKeys = {}
    for key, nodes in pairs(GatherMapDB.nodes) do
        if type(key) == "string" and type(nodes) == "table" then
            local _, _, continent, zone = string.find(key, "^(%d+):(%d+)$")
            if continent and zone then table.insert(zoneKeys, key) end
        end
    end
    table.sort(zoneKeys)
    local lines, count = {}, 0
    for _, key in ipairs(zoneKeys) do
        local _, _, continent, zone = string.find(key, "^(%d+):(%d+)$")
        local nodes = GatherMapDB.nodes[key]
        local i
        for i = 1, table.getn(nodes) do
            local node = nodes[i]
            if type(node) == "table" and type(node.name) == "string" and
                    node.name ~= "" and string.len(node.name) <= 160 and
                    type(node.x) == "number" and type(node.y) == "number" and
                    node.x >= 0 and node.x <= 1 and node.y >= 0 and node.y <= 1 and
                    string.len(tostring(node.texture or "")) <= 255 and
                    string.len(tostring(node.zoneName or "")) <= 160 and
                    string.len(tostring(node.areaName or "")) <= 160 then
                local kind = node.kind or "herb"
                if kind == "herb" or kind == "mineral" or kind == "skin" or
                        kind == "wood" or kind == "lock" or kind == "treasure" then
                    local skill = tonumber(node.required)
                    local savedRequired = skill and skill >= 0 and skill <= 500 and
                        tostring(math.floor(skill)) or ""
                    local row = table.concat({
                        continent, zone, kind,
                        tostring(math.floor(node.x * 100000 + 0.5)),
                        tostring(math.floor(node.y * 100000 + 0.5)),
                        tostring(math.max(1, math.min(1000000, math.floor(tonumber(node.count) or 1)))),
                        savedRequired,
                        TransferEncode(node.name), TransferEncode(node.texture),
                        TransferEncode(node.zoneName), TransferEncode(node.areaName),
                    }, ",")
                    table.insert(lines, row)
                    count = count + 1
                end
            end
        end
    end
    if count == 0 then return {}, 0 end
    local fullHash = TransferHash(table.concat(lines, ";"))
    local fragments, current = {}, ""
    for _, row in ipairs(lines) do
        if string.len(current) > 0 and string.len(current) + 1 + string.len(row) > TRANSFER_PART_LIMIT then
            table.insert(fragments, current)
            current = ""
        end
        if current == "" then current = row else current = current .. ";" .. row end
    end
    if current ~= "" then table.insert(fragments, current) end
    if table.getn(fragments) > TRANSFER_MAX_PARTS then
        return nil, count
    end
    local parts = {}
    local i
    for i = 1, table.getn(fragments) do
        local fragment = fragments[i]
        parts[i] = "GM1|" .. fullHash .. "|" .. i .. "|" .. table.getn(fragments) ..
            "|" .. TransferHash(fragment) .. "|" .. fragment
    end
    return parts, count
end

local function TransferParseRow(raw)
    local f = TransferSplit(raw, ",", 11)
    if not f then return nil end
    local continent, zone, x, y = tonumber(f[1]), tonumber(f[2]), tonumber(f[4]), tonumber(f[5])
    local count, required = tonumber(f[6]), f[7] ~= "" and tonumber(f[7]) or nil
    local kind = f[3]
    if not continent or continent ~= math.floor(continent) or continent < 1 or continent > 2 or
            not zone or zone ~= math.floor(zone) or zone < 1 or zone > 1024 or
            not x or x ~= math.floor(x) or x < 0 or x > 100000 or
            not y or y ~= math.floor(y) or y < 0 or y > 100000 or
            not count or count ~= math.floor(count) or count < 1 or count > 1000000 or
            (f[7] ~= "" and not required) or
            (required and (required < 0 or required > 500 or required ~= math.floor(required))) or
            (kind ~= "herb" and kind ~= "mineral" and kind ~= "skin" and
             kind ~= "wood" and kind ~= "lock" and kind ~= "treasure") then
        return nil
    end
    local name, texture = TransferDecode(f[8]), TransferDecode(f[9])
    local zoneName, areaName = TransferDecode(f[10]), TransferDecode(f[11])
    if not name or name == "" or string.len(name) > 160 or
            not texture or string.len(texture) > 255 or
            not zoneName or string.len(zoneName) > 160 or
            not areaName or string.len(areaName) > 160 then return nil end
    return {
        continent = continent, zone = zone, name = name, kind = kind,
        x = x / 100000, y = y / 100000, count = count,
        required = required, texture = texture ~= "" and texture or nil,
        zoneName = zoneName, areaName = areaName,
    }
end

local function TransferResolveZone(continent, sourceZone, name)
    if not name or name == "" then return sourceZone end
    local known = { GetMapZones(continent) }
    local i
    for i = 1, table.getn(known) do
        if CanonicalZoneName(known[i]) == CanonicalZoneName(name) then return i end
    end
    -- Avoid mapping personal nodes to the wrong zone after a client/map update.
    return nil
end

local function TransferMerge(data)
    -- A spatial hash keeps large imports fast. Check the eight neighboring
    -- cells too, so matches are found across cell boundaries.
    local added, duplicate, unknownZones = 0, 0, 0
    local zoneIndexes = {}
    local cellSize = DUPLICATE_DISTANCE
    local function CellKey(x, y)
        return math.floor(x / cellSize) .. ":" .. math.floor(y / cellSize)
    end
    local function IndexNode(index, node)
        if type(node.name) ~= "string" or type(node.x) ~= "number" or
                type(node.y) ~= "number" then return end
        local nameKey = (node.kind or "herb") .. "\031" .. node.name
        if not index[nameKey] then index[nameKey] = {} end
        local buckets = index[nameKey]
        local cell = CellKey(node.x, node.y)
        if not buckets[cell] then buckets[cell] = {} end
        table.insert(buckets[cell], node)
    end
    for _, source in ipairs(data) do
        local resolvedZone = TransferResolveZone(source.continent, source.zone, source.zoneName)
        if not resolvedZone then
            unknownZones = unknownZones + 1
        else
            local nodes, zoneKey = DatabaseZone(source.continent, resolvedZone, true)
            local index = zoneIndexes[zoneKey]
            if not index then
                index = {}
                zoneIndexes[zoneKey] = index
                for _, existing in ipairs(nodes) do IndexNode(index, existing) end
            end
            local nameKey = source.kind .. "\031" .. source.name
            local buckets = index[nameKey]
            local cx, cy = math.floor(source.x / cellSize), math.floor(source.y / cellSize)
            local exists = false
            if buckets then
                local dx, dy
                for dx = -1, 1 do
                    for dy = -1, 1 do
                        local bucket = buckets[(cx + dx) .. ":" .. (cy + dy)]
                        if bucket then
                            for _, other in ipairs(bucket) do
                                if math.abs(other.x - source.x) <= DUPLICATE_DISTANCE and
                                        math.abs(other.y - source.y) <= DUPLICATE_DISTANCE then
                                    exists = true
                                    break
                                end
                            end
                        end
                        if exists then break end
                    end
                    if exists then break end
                end
            end
            if exists then
                duplicate = duplicate + 1
            else
                local imported = {
                    name = source.name, kind = source.kind, x = source.x, y = source.y,
                    count = source.count, required = source.required,
                    texture = source.texture, zoneName = source.zoneName,
                    areaName = source.areaName,
                }
                table.insert(nodes, imported)
                IndexNode(index, imported)
                added = added + 1
            end
        end
    end
    UpdatePins()
    UpdateWorldMapPins()
    return added, duplicate, unknownZones
end

local function TransferReceivePart(text)
    text = string.gsub(text or "", "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    local _, _, fullHash, number, total, partHash, fragment =
        string.find(text, "^GM1|(%x+)|(%d+)|(%d+)|(%x+)|(.+)$")
    number, total = tonumber(number), tonumber(total)
    if not fullHash or string.len(fullHash) ~= 8 or not partHash or string.len(partHash) ~= 8 or
            not number or not total or number < 1 or total < 1 or
            number > total or total > TRANSFER_MAX_PARTS or string.len(fragment) > 8000 or
            TransferHash(fragment) ~= partHash then
        return false, "Invalid or damaged GatherMap export part."
    end
    if incomingTransfer and (incomingTransfer.hash ~= fullHash or incomingTransfer.total ~= total) then
        return false, "Another import is pending. Use Reset Import first."
    end
    if not incomingTransfer then
        incomingTransfer = { hash = fullHash, total = total, chunks = {}, received = 0 }
    end
    if incomingTransfer.chunks[number] then
        if incomingTransfer.chunks[number] == fragment then
            return false, "This part was already received (" .. incomingTransfer.received .. "/" .. total .. ")."
        end
        return false, "Conflicting part. Reset Import to start over."
    end
    incomingTransfer.chunks[number] = fragment
    incomingTransfer.received = incomingTransfer.received + 1
    if incomingTransfer.received < total then
        return true, "Part " .. number .. "/" .. total .. " received (" ..
            incomingTransfer.received .. "/" .. total .. "). Paste the next part."
    end
    local joined = table.concat(incomingTransfer.chunks, ";")
    incomingTransfer = nil
    if string.len(joined) > 2000000 or TransferHash(joined) ~= fullHash then
        return false, "Export checksum failed. No nodes were imported."
    end
    local decoded, start = {}, 1
    while start <= string.len(joined) do
        local separator = string.find(joined, ";", start, true)
        local raw = separator and string.sub(joined, start, separator - 1) or string.sub(joined, start)
        local row = TransferParseRow(raw)
        if not row then
            return false, "Invalid resource data. No nodes were imported."
        end
        table.insert(decoded, row)
        if table.getn(decoded) > TRANSFER_MAX_NODES then
            return false, "Too many locations. No nodes were imported."
        end
        if not separator then break end
        start = separator + 1
    end
    if string.sub(joined, -1) == ";" then
        return false, "Invalid final resource record. No nodes were imported."
    end
    local added, duplicates, missing = TransferMerge(decoded)
    return true, "Import done: " .. added .. " new, " .. duplicates ..
        " duplicates, " .. missing .. " unavailable zones."
end

-- The vanilla 1.12 API uses the global `this` in script handlers.
-- All controls are built once, without external UI libraries.
local function RefreshOptions()
    if not optionsFrame or not GatherMapDB then return end
    local i
    for i = 1, table.getn(trackingCategories) do
        local kind = trackingCategories[i][1]
        trackingCheckboxes[kind]:SetChecked(IsCategoryTracked(kind))
    end
    for _, check in ipairs(resourceCheckboxes) do
        check:SetChecked(GatherMapDB.resourceFilters[check.resourceKind][check.resourceName] ~= false)
    end
    minimapVisibleCheckbox:SetChecked(GatherMapDB.enabled)
    if minimapScaleSlider then minimapScaleSlider:SetValue(GatherMapDB.minimapNodeScale) end
    if worldMapScaleSlider then worldMapScaleSlider:SetValue(GatherMapDB.worldMapNodeScale) end
    worldMapVisibleCheckbox:SetChecked(GatherMapDB.worldMapEnabled)
    if GatherMapDB.preset then
        for kind, checkbox in pairs(presetCheckboxes) do
            checkbox:SetChecked(GatherMapDB.preset[kind])
        end
    end
end

local function ToggleOptions()
    if not optionsFrame then return end
    if optionsFrame:IsVisible() then
        optionsFrame:Hide()
    else
        RefreshOptions()
        optionsFrame:Show()
    end
end

-- Visual design shared by all three settings pages.  Texture paths and widget
-- APIs below are available in the Vanilla 1.12 client used by Turtle WoW 1.18.
local function CreateOptionsFrame()
    if optionsFrame then return end

    local theme = {
        navy = { 0.030, 0.041, 0.063, 0.96 },
        section = { 0.038, 0.050, 0.071, 0.92 },
        textGold = { 0.84, 0.72, 0.49 },
        textSoft = { 0.75, 0.77, 0.77 },
        textMuted = { 0.57, 0.62, 0.65 },
        copper = { 0.38, 0.30, 0.20, 0.96 },
        green = { 0.29, 0.73, 0.54 },
        teal = { 0.42, 0.76, 0.65 },
    }
    local solid = "Interface\\Tooltips\\UI-Tooltip-Background"
    local fineBorder = "Interface\\Tooltips\\UI-Tooltip-Background"

    local function SetTint(fontString, rgb)
        fontString:SetTextColor(rgb[1], rgb[2], rgb[3])
        return fontString
    end
    local function DarkBackdrop(widget, rgba, border)
        widget:SetBackdrop({
            bgFile = solid, edgeFile = fineBorder,
            tile = true, tileSize = 16, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        widget:SetBackdropColor(rgba[1], rgba[2], rgba[3], rgba[4] or 1)
        local tint = border or theme.copper
        widget:SetBackdropBorderColor(tint[1], tint[2], tint[3], tint[4] or 1)
    end
    local function Heading(parent, content, x, y)
        local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        label:SetText(content)
        SetTint(label, theme.textGold)
        return label
    end
    local function Hint(parent, content, x, y, width)
        local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        if width then label:SetWidth(width); label:SetJustifyH("LEFT") end
        label:SetText(content)
        SetTint(label, theme.textMuted)
        return label
    end
    local function Section(parent, x, y, width, height)
        local section = CreateFrame("Frame", nil, parent)
        section:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        section:SetWidth(width); section:SetHeight(height)
        DarkBackdrop(section, theme.section)
        return section
    end
    local function HorizontalLine(parent, x, y, width)
        local line = parent:CreateTexture(nil, "ARTWORK")
        line:SetTexture(solid)
        line:SetVertexColor(0.37, 0.30, 0.20, 0.62)
        line:SetWidth(width); line:SetHeight(1)
        line:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        return line
    end
    local function StyleButton(button)
        -- Replaces the red Blizzard UP / DOWN textures without changing events.
        button:SetNormalTexture(solid)
        button:SetPushedTexture(solid)
        button:SetHighlightTexture(solid)
        button:GetNormalTexture():SetVertexColor(0.065, 0.077, 0.095, 0.98)
        button:GetPushedTexture():SetVertexColor(0.13, 0.13, 0.13, 0.98)
        button:GetHighlightTexture():SetVertexColor(0.24, 0.20, 0.14, 0.24)
        DarkBackdrop(button, { 0.065, 0.077, 0.095, 0.98 })
        if button.GetFontString then
            local label = button:GetFontString()
            if label then SetTint(label, theme.textGold) end
        end
        return button
    end
    local function StyleCheck(check, name, text)
        -- A dark square with a subtle green indicator when checked.
        check:SetWidth(19); check:SetHeight(19)
        check:SetNormalTexture(solid)
        check:SetPushedTexture(solid)
        check:SetHighlightTexture(solid)
        check:SetCheckedTexture(solid)
        check:GetNormalTexture():SetVertexColor(0.075, 0.10, 0.115, 1)
        check:GetPushedTexture():SetVertexColor(0.13, 0.15, 0.16, 1)
        check:GetHighlightTexture():SetVertexColor(0.30, 0.36, 0.34, 0.28)
        local indicator = check:GetCheckedTexture()
        indicator:SetVertexColor(theme.green[1], theme.green[2], theme.green[3], 1)
        indicator:ClearAllPoints()
        indicator:SetPoint("CENTER", check, "CENTER", 0, 0)
        indicator:SetWidth(9); indicator:SetHeight(9)
        DarkBackdrop(check, { 0.055, 0.067, 0.073, 0.98 },
            { 0.32, 0.32, 0.26, 0.96 })
        local label = getglobal(name .. "Text")
        if label then
            label:ClearAllPoints()
            label:SetPoint("LEFT", check, "RIGHT", 9, 0)
            label:SetFontObject(GameFontHighlightSmall)
            label:SetText(text)
            SetTint(label, theme.textGold)
        end
        return check
    end
    local function ThemeSlider(slider)
        -- Keep the built-in slider mechanics and range, only retint artwork.
        local thumb = slider:GetThumbTexture()
        if thumb then thumb:SetVertexColor(0.81, 0.69, 0.47, 1) end
        DarkBackdrop(slider, { 0.07, 0.085, 0.10, 0.65 },
            { 0.27, 0.26, 0.22, 0.76 })
    end

    local panel = CreateFrame("Frame", "GatherMapOptionsFrame", UIParent)
    optionsFrame = panel
    panel:SetWidth(760); panel:SetHeight(700)
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    panel:SetFrameStrata("DIALOG")
    panel:SetMovable(true); panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function() this:StartMoving() end)
    panel:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    DarkBackdrop(panel, theme.navy, { 0.44, 0.35, 0.22, 0.98 })

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 25, -22)
    title:SetText("Gather Map")
    SetTint(title, theme.textGold)
    local headingRight = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headingRight:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -53, -28)
    headingRight:SetText("TURTLE WOW  |  v0.7.0")
    SetTint(headingRight, theme.teal)
    Hint(panel, "Learns resources automatically. Choose which markers appear on your maps.",
        27, -70, 690)
    HorizontalLine(panel, 24, -95, 710)
    local close = CreateFrame("Button", "GatherMapOptionsClose", panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -7, -7)

    local general = CreateFrame("Frame", "GatherMapGeneralPage", panel)
    general:SetWidth(712); general:SetHeight(510)
    general:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -160)
    local resources = CreateFrame("Frame", "GatherMapResourcesPage", panel)
    resources:SetWidth(712); resources:SetHeight(510)
    resources:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -160)
    local transfer = CreateFrame("Frame", "GatherMapTransferPage", panel)
    transfer:SetWidth(712); transfer:SetHeight(510)
    transfer:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -160)

    local tabs = {}
    local tabNames = { "General", "Node Tracking", "Import / Export" }
    local function SelectPage(index)
        general:Hide(); resources:Hide(); transfer:Hide()
        if index == 1 then general:Show()
        elseif index == 2 then resources:Show()
        else transfer:Show() end
        for i, button in ipairs(tabs) do
            if i == index then
                button:SetBackdropColor(0.13, 0.14, 0.15, 0.98)
                button:SetBackdropBorderColor(0.56, 0.45, 0.27, 1)
                button.activeLine:Show()
            else
                button:SetBackdropColor(0.045, 0.055, 0.073, 0.98)
                button:SetBackdropBorderColor(0.29, 0.27, 0.23, 1)
                button.activeLine:Hide()
            end
        end
    end
    for i, tabName in ipairs(tabNames) do
        local names = { "GatherMapGeneralTab", "GatherMapResourcesTab", "GatherMapTransferTab" }
        local tab = CreateFrame("Button", names[i], panel, "UIPanelButtonTemplate")
        tab:SetWidth(229); tab:SetHeight(34)
        tab:SetPoint("TOPLEFT", panel, "TOPLEFT", 24 + (i - 1) * 241, -110)
        tab:SetText(tabName)
        StyleButton(tab)
        local stripe = tab:CreateTexture(nil, "OVERLAY")
        stripe:SetTexture(solid)
        stripe:SetVertexColor(theme.textGold[1], theme.textGold[2], theme.textGold[3], 1)
        stripe:SetHeight(2)
        stripe:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 0, 0)
        stripe:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 0, 0)
        tab.activeLine = stripe
        local pageIndex = i
        tab:SetScript("OnClick", function() SelectPage(pageIndex) end)
        tabs[i] = tab
    end
    local footer = Hint(panel, "GATHER MAP  |  ALWAYS LEARNING", 25, -677, 390)
    SetTint(footer, theme.teal)
    local footerRight = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    footerRight:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -26, -677)
    footerRight:SetText("Settings and personal data are saved automatically")
    SetTint(footerRight, theme.textMuted)

    -- GENERAL: two-column layout instead of the old 354-pixel-tall form.
    local learnBox = Section(general, 0, 0, 346, 503)
    Heading(learnBox, "Resource tracking", 18, -19)
    Hint(learnBox, "Hidden categories are still learned.", 18, -46, 310)
    HorizontalLine(learnBox, 18, -67, 310)
    for i = 1, table.getn(trackingCategories) do
        local kind = trackingCategories[i][1]
        local displayName = trackingCategories[i][2]
        local checkName = "GatherMapTrack" .. kind
        local check = CreateFrame("CheckButton", checkName, learnBox, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", learnBox, "TOPLEFT", 22, -84 - (i - 1) * 56)
        StyleCheck(check, checkName, displayName)
        check:SetScript("OnClick", function()
            GatherMapDB.tracked[kind] = this:GetChecked() and true or false
            UpdatePins(); UpdateWorldMapPins()
        end)
        trackingCheckboxes[kind] = check
        if i < table.getn(trackingCategories) then
            HorizontalLine(learnBox, 20, -119 - (i - 1) * 56, 306)
        end
    end
    Hint(learnBox, "Recording never stops when a filter is disabled.", 19, -447, 306)
    Hint(learnBox, "Unchecking only hides the matching markers.", 19, -467, 306)

    local displayBox = Section(general, 358, 0, 354, 263)
    Heading(displayBox, "Display options", 18, -19)
    HorizontalLine(displayBox, 18, -45, 318)
    local mini = CreateFrame("CheckButton", "GatherMapShowMinimap", displayBox,
        "UICheckButtonTemplate")
    minimapVisibleCheckbox = mini
    mini:SetPoint("TOPLEFT", displayBox, "TOPLEFT", 21, -58)
    StyleCheck(mini, "GatherMapShowMinimap", "Show minimap markers")
    mini:SetScript("OnClick", function()
        GatherMapDB.enabled = this:GetChecked() and true or false
        UpdatePins()
    end)
    local world = CreateFrame("CheckButton", "GatherMapShowWorldMap", displayBox,
        "UICheckButtonTemplate")
    worldMapVisibleCheckbox = world
    world:SetPoint("TOPLEFT", displayBox, "TOPLEFT", 21, -91)
    StyleCheck(world, "GatherMapShowWorldMap", "Show world map markers")
    world:SetScript("OnClick", function()
        GatherMapDB.worldMapEnabled = this:GetChecked() and true or false
        if worldMapCheckbox then worldMapCheckbox:SetChecked(GatherMapDB.worldMapEnabled) end
        UpdateWorldMapPins()
    end)
    local slider = CreateFrame("Slider", "GatherMapMinimapNodeScale", displayBox,
        "OptionsSliderTemplate")
    minimapScaleSlider = slider
    slider:SetWidth(277); slider:SetHeight(14)
    slider:SetPoint("TOPLEFT", displayBox, "TOPLEFT", 39, -160)
    slider:SetMinMaxValues(0.5, 2); slider:SetValueStep(0.1)
    ThemeSlider(slider)
    getglobal("GatherMapMinimapNodeScaleLow"):SetText("50%")
    getglobal("GatherMapMinimapNodeScaleHigh"):SetText("200%")
    slider:SetScript("OnValueChanged", function()
        if not GatherMapDB then return end
        local value = math.floor(this:GetValue() * 10 + 0.5) / 10
        GatherMapDB.minimapNodeScale = math.max(0.5, math.min(2, value))
        getglobal("GatherMapMinimapNodeScaleText"):SetText(
            "Minimap icon size: " .. math.floor(GatherMapDB.minimapNodeScale * 100 + 0.5) .. "%")
        UpdatePins()
    end)
    getglobal("GatherMapMinimapNodeScaleText"):SetText("Minimap icon size: 100%")
    slider:SetValue(GatherMapDB.minimapNodeScale)

    local worldSlider = CreateFrame("Slider", "GatherMapWorldMapNodeScale", displayBox,
        "OptionsSliderTemplate")
    worldMapScaleSlider = worldSlider
    worldSlider:SetWidth(277); worldSlider:SetHeight(14)
    worldSlider:SetPoint("TOPLEFT", displayBox, "TOPLEFT", 39, -227)
    worldSlider:SetMinMaxValues(0.5, 2); worldSlider:SetValueStep(0.1)
    ThemeSlider(worldSlider)
    getglobal("GatherMapWorldMapNodeScaleLow"):SetText("50%")
    getglobal("GatherMapWorldMapNodeScaleHigh"):SetText("200%")
    worldSlider:SetScript("OnValueChanged", function()
        if not GatherMapDB then return end
        local value = math.floor(this:GetValue() * 10 + 0.5) / 10
        GatherMapDB.worldMapNodeScale = math.max(0.5, math.min(2, value))
        getglobal("GatherMapWorldMapNodeScaleText"):SetText(
            "World map icon size: " .. math.floor(GatherMapDB.worldMapNodeScale * 100 + 0.5) .. "%")
        UpdateWorldMapPins()
    end)
    getglobal("GatherMapWorldMapNodeScaleText"):SetText("World map icon size: 100%")
    worldSlider:SetValue(GatherMapDB.worldMapNodeScale)

    local databaseBox = Section(general, 358, -274, 354, 229)
    Heading(databaseBox, "Map database  (pfQuest)", 18, -18)
    HorizontalLine(databaseBox, 18, -44, 318)
    local presetChoices = {
        { "herb", "Preloaded herbs" },
        { "mineral", "Preloaded mining nodes" },
        { "showRecorded", "My recorded locations" },
    }
    for i = 1, table.getn(presetChoices) do
        local field, labelText = presetChoices[i][1], presetChoices[i][2]
        local checkName = "GatherMapPreset" .. field
        local check = CreateFrame("CheckButton", checkName, databaseBox,
            "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", databaseBox, "TOPLEFT", 21, -63 - (i - 1) * 44)
        StyleCheck(check, checkName, labelText)
        check:SetScript("OnClick", function()
            GatherMapDB.preset[field] = this:GetChecked() and true or false
            UpdatePins(); UpdateWorldMapPins()
        end)
        presetCheckboxes[field] = check
    end
    Hint(databaseBox, "pfQuest positions are approximate; learned nodes are separate.",
        18, -195, 317)

    -- NODE TRACKING: two-column, scrollable lists keep long node names fully
    -- readable without making the entire GUI taller than the other pages.
    local function MakeResourcePanel(kind, titleText, top, height)
        local box = Section(resources, 0, -top, 712, height)
        Heading(box, titleText .. "  |  Required skill", 16, -13)
        HorizontalLine(box, 16, -36, 680)
        local choices, seen = {}, {}
        for _, entry in ipairs(GatherMapPresetCatalog or {}) do
            if entry[2] == kind and not seen[entry[1]] then
                seen[entry[1]] = true
                table.insert(choices, { name = entry[1], required = entry[3] or 0 })
            end
        end
        table.sort(choices, function(a, b)
            if a.required == b.required then return a.name < b.name end
            return a.required < b.required
        end)
        local countHint = Hint(box, table.getn(choices) .. " types  |  Scroll for more",
            530, -13, 168)
        countHint:SetJustifyH("RIGHT")
        local scroll = CreateFrame("ScrollFrame", "GatherMapResourceScroll" .. kind, box,
            "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", box, "TOPLEFT", 13, -44)
        scroll:SetWidth(656); scroll:SetHeight(height - 53)
        local content = CreateFrame("Frame", nil, scroll)
        content:SetWidth(637)
        content:SetHeight(math.max(height - 54, 15 + math.ceil(table.getn(choices) / 2) * 26))
        for i, entry in ipairs(choices) do
            local name = "GatherMapResource" .. kind .. i
            local check = CreateFrame("CheckButton", name, content, "UICheckButtonTemplate")
            check.resourceKind = kind; check.resourceName = entry.name
            check.required = entry.required
            check:SetPoint("TOPLEFT", content, "TOPLEFT",
                6 + math.mod(i - 1, 2) * 316,
                -8 - math.floor((i - 1) / 2) * 26)
            StyleCheck(check, name, entry.name .. "  (" .. entry.required .. ")")
            check:SetChecked(GatherMapDB.resourceFilters[kind][entry.name] ~= false)
            check:SetScript("OnClick", function()
                GatherMapDB.resourceFilters[this.resourceKind][this.resourceName] =
                    this:GetChecked() and true or false
                UpdatePins(); UpdateWorldMapPins()
            end)
            table.insert(resourceCheckboxes, check)
        end
        scroll:SetScrollChild(content)
    end
    MakeResourcePanel("mineral", "Mining", 0, 229)
    MakeResourcePanel("herb", "Herbalism", 239, 267)

    -- IMPORT / EXPORT: matching gold-framed text fields and buttons.
    local exportBox = Section(transfer, 0, 0, 346, 503)
    local importBox = Section(transfer, 358, 0, 354, 503)
    Heading(exportBox, "Export learned locations", 17, -17)
    Hint(exportBox, "Personal nodes only (no presets or settings).", 17, -46, 310)
    HorizontalLine(exportBox, 17, -67, 310)
    Heading(importBox, "Import / merge locations", 17, -17)
    Hint(importBox, "Paste one GM1 part at a time. Existing nodes are safe.",
        17, -46, 315)
    HorizontalLine(importBox, 17, -67, 320)

    local function TransferButton(parent, name, caption, x, y, width, click)
        local button = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
        button:SetWidth(width); button:SetHeight(30)
        button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        button:SetText(caption)
        StyleButton(button)
        button:SetScript("OnClick", click)
        return button
    end
    local function TransferTextBox(parent, name, x, top, width, height)
        local outer = Section(parent, x, -top, width, height)
        DarkBackdrop(outer, { 0.018, 0.027, 0.044, 0.98 },
            { 0.39, 0.34, 0.24, 1 })
        local scroll = CreateFrame("ScrollFrame", name .. "Scroll", outer,
            "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", outer, "TOPLEFT", 9, -9)
        scroll:SetWidth(width - 47); scroll:SetHeight(height - 18)
        local edit = CreateFrame("EditBox", name, scroll)
        edit:SetWidth(width - 52); edit:SetHeight(height - 20)
        edit:SetMultiLine(true); edit:SetMaxLetters(0); edit:SetAutoFocus(false)
        edit:SetFontObject(ChatFontNormal or GameFontNormal)
        edit:SetTextColor(0.80, 0.84, 0.81)
        edit:SetTextInsets(4, 4, 4, 4)
        edit:SetScript("OnEscapePressed", function() this:ClearFocus() end)
        edit:SetScript("OnTextChanged", function()
            local estimated = math.max(height - 20,
                math.ceil(string.len(this:GetText() or "") / 34) * 16 + 28)
            if math.abs(this:GetHeight() - estimated) >= 2 then
                this:SetHeight(estimated)
            end
            if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
        end)
        scroll:SetScrollChild(edit)
        return edit
    end
    local exportStatus = Hint(exportBox,
        "Click Generate, then Select All and Ctrl+C.", 18, -438, 311)
    local exportEdit = TransferTextBox(exportBox, "GatherMapExportText", 17, 127, 312, 296)
    local function ShowExportPart()
        if not transferParts or table.getn(transferParts) == 0 then
            exportEdit:SetText("")
            return
        end
        exportEdit:SetText(transferParts[transferPageIndex])
        exportEdit:HighlightText(0, 0)
        exportStatus:SetText("Part " .. transferPageIndex .. "/" .. table.getn(transferParts) ..
            ": Ctrl+A, Ctrl+C. Share all parts for large databases.")
    end
    TransferButton(exportBox, "GatherMapExportGenerate", "Generate", 17, -84, 98, function()
        local count
        transferParts, count = ExportPersonalNodes()
        transferPageIndex = 1
        if not transferParts then
            exportEdit:SetText("")
            exportStatus:SetText("Too many locations to export in one session.")
        elseif table.getn(transferParts) == 0 then
            exportEdit:SetText("")
            exportStatus:SetText("No personally recorded locations to export yet.")
        else
            ShowExportPart()
            Print("exported " .. count .. " learned nodes in " .. table.getn(transferParts) .. " part(s).")
        end
    end)
    TransferButton(exportBox, "GatherMapExportSelect", "Select All", 123, -84, 96, function()
        if transferParts and table.getn(transferParts) > 0 then
            exportEdit:SetFocus(); exportEdit:HighlightText()
        end
    end)
    TransferButton(exportBox, "GatherMapExportPrevious", "<", 227, -84, 42, function()
        if transferParts and transferPageIndex > 1 then
            transferPageIndex = transferPageIndex - 1
            ShowExportPart()
        end
    end)
    TransferButton(exportBox, "GatherMapExportNext", ">", 277, -84, 52, function()
        if transferParts and transferPageIndex < table.getn(transferParts) then
            transferPageIndex = transferPageIndex + 1
            ShowExportPart()
        end
    end)
    local importEdit = TransferTextBox(importBox, "GatherMapImportText", 18, 84, 317, 339)
    local importStatus = Hint(importBox,
        "Waiting for a GM1 export part.", 18, -467, 320)
    TransferButton(importBox, "GatherMapImportAdd", "Add Part / Merge", 18, -432, 164, function()
        local accepted, result = TransferReceivePart(importEdit:GetText())
        importStatus:SetText(result)
        if accepted then importEdit:SetText("") end
        importEdit:ClearFocus()
        if string.find(result, "^Import done:") then Print(result) end
    end)
    TransferButton(importBox, "GatherMapImportReset", "Reset Import", 190, -432, 145, function()
        incomingTransfer = nil
        importEdit:SetText("")
        importEdit:ClearFocus()
        importStatus:SetText("Pending import cleared. Your saved nodes are unchanged.")
    end)

    SelectPage(1)
    table.insert(UISpecialFrames, "GatherMapOptionsFrame")
    panel:Hide()
end

local function PositionMinimapButton()
    if not minimapButton or not GatherMapDB then return end
    local angle = GatherMapDB.minimapButtonAngle or 210
    local radians = math.rad(angle)
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER",
        math.cos(radians) * 80, math.sin(radians) * 80)
end

local function UpdateMinimapButtonDrag()
    local scale = UIParent:GetEffectiveScale()
    local x, y = GetCursorPosition()
    local centerX, centerY = Minimap:GetCenter()
    if not centerX or not centerY then return end
    x = x / scale - centerX
    y = y / scale - centerY
    -- Vanilla's Lua library may not provide atan2 on every client build.
    local angle
    if math.atan2 then
        angle = math.atan2(y, x)
    elseif x == 0 then
        angle = y >= 0 and (math.pi / 2) or (-math.pi / 2)
    else
        angle = math.atan(y / x)
        if x < 0 then angle = angle + math.pi end
    end
    GatherMapDB.minimapButtonAngle = math.deg(angle)
    PositionMinimapButton()
end

local function CreateMinimapButton()
    if minimapButton then return end
    local button = CreateFrame("Button", "GatherMapMinimapButton", Minimap)
    minimapButton = button
    button:SetWidth(32)
    button:SetHeight(32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(Minimap:GetFrameLevel() + 7)
    button:SetNormalTexture("Interface\\Icons\\INV_Misc_Map_01")
    -- An inscribed square fits entirely inside the tracking button's round rim.
    local buttonIcon = button:GetNormalTexture()
    buttonIcon:ClearAllPoints()
    buttonIcon:SetPoint("CENTER", button, "CENTER", 0, 0)
    buttonIcon:SetWidth(17)
    buttonIcon:SetHeight(17)
    buttonIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetWidth(54)
    border:SetHeight(54)
    border:SetPoint("CENTER", button, "CENTER", 10, -10)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnClick", function()
        ToggleOptions()
    end)
    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:AddLine("Gather Map", 0.41, 0.80, 0.44)
        GameTooltip:AddLine("Click: settings", 1, 1, 1)
        GameTooltip:AddLine("Drag: move minimap button", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnDragStart", function()
        this:SetScript("OnUpdate", UpdateMinimapButtonDrag)
    end)
    button:SetScript("OnDragStop", function()
        this:SetScript("OnUpdate", nil)
        UpdateMinimapButtonDrag()
    end)
    PositionMinimapButton()
end

local function InitializeDatabase()
    if type(GatherMapDB) ~= "table" then GatherMapDB = {} end
    if type(GatherMapDB.nodes) ~= "table" then GatherMapDB.nodes = {} end
    if type(GatherMapDB.resourceFilters) ~= "table" then GatherMapDB.resourceFilters = {} end
    if type(GatherMapDB.resourceFilters.herb) ~= "table" then GatherMapDB.resourceFilters.herb = {} end
    if type(GatherMapDB.resourceFilters.mineral) ~= "table" then GatherMapDB.resourceFilters.mineral = {} end
    if GatherMapDB.enabled == nil then GatherMapDB.enabled = true end
    local nodeScale = tonumber(GatherMapDB.minimapNodeScale) or 1
    if nodeScale ~= nodeScale then nodeScale = 1 end
    GatherMapDB.minimapNodeScale = math.max(0.5, math.min(2,
        math.floor(nodeScale * 10 + 0.5) / 10))
    local worldNodeScale = tonumber(GatherMapDB.worldMapNodeScale) or 1
    if worldNodeScale ~= worldNodeScale then worldNodeScale = 1 end
    GatherMapDB.worldMapNodeScale = math.max(0.5, math.min(2,
        math.floor(worldNodeScale * 10 + 0.5) / 10))
    if GatherMapDB.worldMapEnabled == nil then GatherMapDB.worldMapEnabled = true end
    -- Migrate pre-0.6.7 recording checkboxes into visibility preferences.
    -- Keep the legacy field untouched for users who roll back the addon.
    if type(GatherMapDB.tracked) ~= "table" then
        GatherMapDB.tracked = {}
        if type(GatherMapDB.record) == "table" then
            for kind, visible in pairs(GatherMapDB.record) do
                GatherMapDB.tracked[kind] = visible
            end
        end
    end
    if type(GatherMapDB.preset) ~= "table" then GatherMapDB.preset = {} end
    if GatherMapDB.preset.herb == nil then GatherMapDB.preset.herb = true end
    if GatherMapDB.preset.mineral == nil then GatherMapDB.preset.mineral = true end
    if GatherMapDB.preset.showRecorded == nil then
        GatherMapDB.preset.showRecorded = true
    end
    local i
    for i = 1, table.getn(trackingCategories) do
        local kind = trackingCategories[i][1]
        if GatherMapDB.tracked[kind] == nil then GatherMapDB.tracked[kind] = true end
    end
    local databaseVersion = tonumber(GatherMapDB.version) or 1
    -- Version 1 databases contained herbs only. Mark them explicitly so the
    -- shared node table can safely hold mining, skinning, and chest locations.
    if databaseVersion < 2 then
        local _, zoneNodes
        for _, zoneNodes in pairs(GatherMapDB.nodes) do
            local i
            for i = 1, table.getn(zoneNodes) do
                if not zoneNodes[i].kind then zoneNodes[i].kind = "herb" end
            end
        end
    end
    -- Version 2 calculated the required skill incorrectly for creatures below
    -- level 21. Keep every saved hunting spot, but discard only its unreliable
    -- requirement; skinning there again restores the correct dynamic color.
    if databaseVersion < 3 then
        local _, zoneNodes
        for _, zoneNodes in pairs(GatherMapDB.nodes) do
            local i
            for i = 1, table.getn(zoneNodes) do
                if zoneNodes[i].kind == "skin" then
                    zoneNodes[i].required = nil
                end
            end
        end
    end
    GatherMapDB.version = 3
    CreateWorldMapCheckbox()
    if worldMapCheckbox then worldMapCheckbox:SetChecked(GatherMapDB.worldMapEnabled) end
    CreateOptionsFrame()
    CreateMinimapButton()
    RefreshOptions()
end

local function ShowStatus()
    local zones, nodes = 0, 0
    local counts = {
        herb = 0, mineral = 0, skin = 0, lock = 0, treasure = 0, wood = 0,
    }
    local _, zoneNodes
    for _, zoneNodes in pairs(GatherMapDB.nodes) do
        zones = zones + 1
        nodes = nodes + table.getn(zoneNodes)
        local i
        for i = 1, table.getn(zoneNodes) do
            local kind = zoneNodes[i].kind or "herb"
            counts[kind] = (counts[kind] or 0) + 1
        end
    end
    local continent, zone, zoneName = FindCurrentMapZone()
    local currentNodes = 0
    local supported = false
    if continent and zone then
        local zoneNodes = DatabaseZone(continent, zone, false)
        currentNodes = zoneNodes and table.getn(zoneNodes) or 0
        supported = zoneScale[zoneName] or customZoneSize[zoneName]
    end
    Print((GatherMapDB.enabled and "markers enabled" or "markers hidden") .. "; " ..
        nodes .. " locations in " .. zones .. " zones (herbs " .. counts.herb ..
        ", minerals " .. counts.mineral .. ", skins " .. counts.skin ..
        ", trees " .. counts.wood ..
        ", chests " .. (counts.lock + counts.treasure) .. ").")
    local presetCount = 0
    if GatherMapPreset then
        for _, records in pairs(GatherMapPreset) do
            for _, record in pairs(records) do
                presetCount = presetCount + string.len(record[2]) / (GatherMapPresetStride or 3)
            end
        end
    end
    Print("preloaded " .. presetCount .. " possible locations; herbs " ..
        (GatherMapDB.preset.herb and "on" or "off") .. ", mining " ..
        (GatherMapDB.preset.mineral and "on" or "off") ..
        "; learned nodes " .. (GatherMapDB.preset.showRecorded and "visible" or "hidden") .. ".")
    Print("skills: Herbalism " .. GetSkillRank("Herbalism") .. ", Mining " ..
        GetSkillRank("Mining") .. ", Skinning " .. GetSkillRank("Skinning") ..
        ", Survival " .. GetSkillRank("Survival") ..
        ", Lockpicking " .. GetSkillRank("Lockpicking") .. ".")
    if continent and zone then
        Print("current map " .. continent .. ":" .. zone .. " (" .. zoneName .. ") has " .. currentNodes ..
            " saved nodes; minimap scaling " .. (supported and "supported." or "NOT supported."))
    else
        Print("current zone could not be matched to a continent map.")
    end
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("SPELLCAST_START")
frame:RegisterEvent("SPELLCAST_STOP")
frame:RegisterEvent("SPELLCAST_FAILED")
frame:RegisterEvent("SPELLCAST_INTERRUPTED")
frame:RegisterEvent("CHAT_MSG_SPELL_SELF_BUFF")
frame:RegisterEvent("CHAT_MSG_LOOT")
frame:RegisterEvent("SKILL_LINES_CHANGED")
frame:RegisterEvent("MINIMAP_UPDATE_ZOOM")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("WORLD_MAP_UPDATE")

frame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "GatherMap" then
        InitializeDatabase()
        InstallInteractHook()
    elseif event == "ADDON_LOADED" and arg1 == "Interact" then
        InstallInteractHook()
    elseif event == "PLAYER_ENTERING_WORLD" then
        InitializeDatabase()
        UpdatePins()
        UpdateWorldMapPins()
    elseif event == "SPELLCAST_START" and actionKinds[arg1] then
        -- Interact.dll can start the native action without first placing the
        -- world object under GameTooltip. The success message or resulting
        -- loot fills in names that were unavailable when the cast began.
        BeginResourceAction(arg1)
    elseif event == "CHAT_MSG_SPELL_SELF_BUFF" and arg1 then
        local _, _, actionName, gatheredName =
            string.find(arg1, "^You perform (.+) on (.+)%.$")
        local kind = actionKinds[actionName]
        if treeRequirements[gatheredName] then kind = "wood" end
        if kind == "treasure" and pendingRequirement and IsChestName(gatheredName) then
            kind = "lock"
        end
        if kind == "herb" or kind == "mineral" or kind == "wood" then
            local required = RequirementFor(kind, gatheredName)
            if pendingNode == gatheredName and pendingRequirement then
                required = pendingRequirement
            end
            RecordNodeOnce(gatheredName, required, kind, pendingTexture)
            ClearPending()
            UpdatePins()
        elseif kind == "skin" then
            pendingKind = "skin"
            pendingNode = gatheredName
            if not pendingRequirement then
                pendingRequirement = SkinningRequirement(UnitLevel("target"))
            end
            pendingGather = false
            pendingLootUntil = GetTime() + 5
        elseif (kind == "treasure" or kind == "lock") and IsChestName(gatheredName) then
            if kind == "treasure" and pendingRequirement then kind = "lock" end
            RecordNodeOnce(gatheredName,
                pendingRequirement or RequirementFor(kind, gatheredName), kind,
                pendingTexture)
            ClearPending()
            UpdatePins()
        end
    elseif event == "CHAT_MSG_LOOT" then
        if pendingKind == "skin" and
                (pendingGather or GetTime() <= pendingLootUntil) then
            local itemName, itemTexture, itemType = LootItem(arg1)
            if IsValidSkinningLoot(itemName, itemType) then
                RecordNodeOnce(itemName, pendingRequirement, "skin", itemTexture)
                pendingLootUntil = GetTime() + 2
                UpdatePins()
            end
        elseif GetTime() - lastInteractTime < 10 then
            local kind, resourceName, required, texture =
                ResourceFromLootMessage(arg1)
            if kind then
                RecordNodeOnce(resourceName, required, kind, texture)
                lastInteractTime = 0
                ClearPending()
                UpdatePins()
            end
        end
    elseif event == "SPELLCAST_STOP" and pendingGather then
        if pendingKind == "skin" then
            pendingGather = false
            pendingLootUntil = GetTime() + 5
        elseif pendingNode then
            RecordNodeOnce(pendingNode, pendingRequirement, pendingKind,
                pendingTexture)
            ClearPending()
            UpdatePins()
        else
            -- Keep Interact armed briefly; a loot message may still identify
            -- an herb or mineral even when no object tooltip was available.
            pendingGather = false
            pendingLootUntil = GetTime() + 10
        end
    elseif event == "SPELLCAST_FAILED" or event == "SPELLCAST_INTERRUPTED" then
        ClearPending()
    elseif event == "WORLD_MAP_UPDATE" then
        UpdateWorldMapPins()
    elseif event == "SKILL_LINES_CHANGED" or event == "MINIMAP_UPDATE_ZOOM" or
            event == "ZONE_CHANGED_NEW_AREA" then
        UpdatePins()
        UpdateWorldMapPins()
    end
end)

frame:SetScript("OnUpdate", function()
    local hidden = ControlOverMinimap()
    if hidden ~= controlMinimapHidden then
        controlMinimapHidden = hidden
        UpdatePins()
    end
    elapsedSinceUpdate = elapsedSinceUpdate + arg1
    elapsedSinceWorldUpdate = elapsedSinceWorldUpdate + arg1
    if elapsedSinceUpdate >= UPDATE_INTERVAL then
        elapsedSinceUpdate = 0
        if pendingLootUntil > 0 and GetTime() > pendingLootUntil then
            ClearPending()
        end
        InstallInteractHook()
        UpdatePins()
        if elapsedSinceWorldUpdate >= 0.75 then
            elapsedSinceWorldUpdate = 0
            UpdateWorldMapPins()
        end
    end
    -- Follow the cursor every rendered frame, not only at the node refresh rate.
    UpdateMarkerHover()
end)

SLASH_GATHERMAP1 = "/gmap"
SLASH_GATHERMAP2 = "/gathermap"
SlashCmdList["GATHERMAP"] = function(message)
    local command = string.lower(message or "")
    if command == "config" or command == "options" then
        ToggleOptions()
    elseif command == "on" or command == "show" then
        GatherMapDB.enabled = true
        UpdatePins()
        RefreshOptions()
        Print("minimap markers enabled.")
    elseif command == "off" or command == "hide" then
        GatherMapDB.enabled = false
        UpdatePins()
        RefreshOptions()
        Print("minimap markers hidden; gathering locations will still be learned.")
    elseif command == "count" or command == "status" or command == "" then
        ShowStatus()
    else
        Print("commands: /gmap config, on, off, or count")
    end
end
