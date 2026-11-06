-- AtlasLoot_GearFilter - Standalone class-based item filter for AtlasLoot TW Edition
-- Hooks into AtlasLoot without modifying any of its files.
-- Lua 5.0 compatible (WoW 1.12 / Interface 11200)

AtlasLoot_GearFilter = {}

-- Class bitmasks (decimal, no hex literals in Lua 5.0)
local C = {
    WARRIOR = 1,
    PALADIN = 2,
    HUNTER  = 4,
    ROGUE   = 8,
    PRIEST  = 16,
    SHAMAN  = 32,
    MAGE    = 64,
    WARLOCK = 128,
    DRUID   = 256,
}

local ALL = C.WARRIOR + C.PALADIN + C.HUNTER + C.ROGUE + C.PRIEST
            + C.SHAMAN + C.MAGE + C.WARLOCK + C.DRUID

local MELEE = C.WARRIOR + C.PALADIN + C.HUNTER + C.ROGUE + C.SHAMAN + C.DRUID
local CASTER = C.DRUID + C.MAGE + C.PALADIN + C.PRIEST + C.SHAMAN + C.WARLOCK
local PHYS = C.DRUID + C.HUNTER + C.PALADIN + C.ROGUE + C.SHAMAN + C.WARRIOR
local TANK = C.DRUID + C.PALADIN + C.SHAMAN + C.WARRIOR

local band = bit and bit.band or function(a, b)
    local result, bitval = 0, 1
    while a > 0 and b > 0 do
        if math.mod(a, 2) == 1 and math.mod(b, 2) == 1 then
            result = result + bitval
        end
        bitval = bitval * 2
        a = math.floor(a / 2)
        b = math.floor(b / 2)
    end
    return result
end

-- =====================================================================
-- Equipment type filter
-- TurtleWoW GetItemInfo returns:
--   1=name  2=link  3=quality  4=iLvl  5=typeCoarse("Armor"/"Weapon")
--   6=typeFine("Cloth"/"Staves"/"Mail"/"Plate"/...)  7=stackCount
--   8=equipLoc("INVTYPE_HEAD"/...)  9=icon  10=sellPrice
-- We read slot 6 as `itemType` (the fine-grained subtype) and slot 8 as
-- `itemEquipLoc` - both are needed for the type filter and the equip-loc
-- bypass for slot-class-agnostic items (cloaks, rings, neck, trinkets).
-- =====================================================================

local TYPE_FILTER = {
    -- Weapons
    ["One-Handed Axes"]   = C.HUNTER + C.PALADIN + C.SHAMAN + C.WARRIOR,
    ["Two-Handed Axes"]   = C.HUNTER + C.PALADIN + C.SHAMAN + C.WARRIOR,
    ["Axes"]              = C.HUNTER + C.PALADIN + C.SHAMAN + C.WARRIOR,
    ["Bows"]              = C.HUNTER + C.ROGUE + C.WARRIOR,
    ["Guns"]              = C.HUNTER + C.ROGUE + C.WARRIOR,
    ["Crossbows"]         = C.HUNTER + C.ROGUE + C.WARRIOR,
    ["One-Handed Maces"]  = C.DRUID + C.PALADIN + C.PRIEST + C.ROGUE + C.SHAMAN + C.WARRIOR,
    ["Two-Handed Maces"]  = C.DRUID + C.PALADIN + C.SHAMAN + C.WARRIOR,
    ["Maces"]             = C.DRUID + C.PALADIN + C.PRIEST + C.ROGUE + C.SHAMAN + C.WARRIOR,
    ["Polearms"]          = C.DRUID + C.HUNTER + C.PALADIN + C.WARRIOR,
    ["One-Handed Swords"] = C.HUNTER + C.MAGE + C.PALADIN + C.ROGUE + C.WARLOCK + C.WARRIOR,
    ["Two-Handed Swords"] = C.HUNTER + C.PALADIN + C.WARRIOR,
    ["Swords"]            = C.HUNTER + C.MAGE + C.PALADIN + C.ROGUE + C.WARLOCK + C.WARRIOR,
    ["Staves"]            = C.DRUID + C.HUNTER + C.MAGE + C.PRIEST + C.SHAMAN + C.WARLOCK,
    ["Fist Weapons"]      = C.DRUID + C.HUNTER + C.ROGUE + C.SHAMAN + C.WARRIOR,
    ["Daggers"]           = C.DRUID + C.HUNTER + C.MAGE + C.PRIEST + C.ROGUE + C.SHAMAN + C.WARLOCK + C.WARRIOR,
    ["Thrown"]             = C.ROGUE + C.WARRIOR,
    ["Wands"]             = C.MAGE + C.PRIEST + C.WARLOCK,
    ["Fishing Poles"]     = ALL,

    -- Armor (downward visibility: each class sees its main type and lighter ones)
    ["Cloth"]             = C.PRIEST + C.MAGE + C.WARLOCK,
    ["Leather"]           = C.HUNTER + C.SHAMAN + C.DRUID + C.ROGUE,
    ["Mail"]              = C.WARRIOR + C.PALADIN + C.HUNTER + C.SHAMAN,
    ["Plate"]             = C.WARRIOR + C.PALADIN,
    ["Shields"]           = C.WARRIOR + C.PALADIN + C.SHAMAN,
    ["Librams"]           = C.PALADIN,
    ["Idols"]             = C.DRUID,
    ["Totems"]            = C.SHAMAN,

    -- Generic (all classes)
    ["Miscellaneous"]     = ALL,
}

local EQUIP_LOC_FILTER = {
    ["INVTYPE_QUIVER"]  = C.HUNTER,
    ["INVTYPE_RELIC"]   = C.SHAMAN + C.PALADIN + C.DRUID,
    ["INVTYPE_AMMO"]    = C.HUNTER + C.ROGUE + C.WARRIOR,
}

-- Equip-loc bypass for slot-class-agnostic items.
-- These slots have no class-armor restriction (cloaks, rings, neck, trinkets,
-- offhand holdables) - TYPE_FILTER must be skipped for them, otherwise items
-- like cloaks (which have itemSubType = "Cloth") get filtered out for melee.
local TYPE_BYPASS_LOCS = {
    ["INVTYPE_CLOAK"]    = true,
    ["INVTYPE_FINGER"]   = true,
    ["INVTYPE_NECK"]     = true,
    ["INVTYPE_TRINKET"]  = true,
    ["INVTYPE_HOLDABLE"] = true,
}

-- =====================================================================
-- D1 / T0.5 set ownership whitelist
-- Cloth/Leather/Mail/Plate sets of the same armor class share nearly
-- identical stat profiles (Sta+Int+Spirit for casters, Str+Sta for melee).
-- A stat-based filter cannot distinguish Priest/Mage/Warlock sets from
-- each other. This whitelist is checked as the FIRST step in CanUse()
-- and overrides all other logic for the 72 D1/T0.5 set items.
-- =====================================================================
local D1_SET_OWNER = {
    -- Vestments of the Devout (Priest)
    [16693]="PRIEST", [16695]="PRIEST", [16690]="PRIEST", [16697]="PRIEST",
    [16692]="PRIEST", [16696]="PRIEST", [16694]="PRIEST", [16691]="PRIEST",
    -- Magister's Regalia (Mage)
    [16686]="MAGE",   [16689]="MAGE",   [16688]="MAGE",   [16683]="MAGE",
    [16684]="MAGE",   [16685]="MAGE",   [16687]="MAGE",   [16682]="MAGE",
    -- Dreadmist Raiment (Warlock)
    [16698]="WARLOCK",[16701]="WARLOCK",[16700]="WARLOCK",[16703]="WARLOCK",
    [16705]="WARLOCK",[16702]="WARLOCK",[16699]="WARLOCK",[16704]="WARLOCK",
    -- Shadowcraft Armor (Rogue)
    [16707]="ROGUE",  [16708]="ROGUE",  [16721]="ROGUE",  [16710]="ROGUE",
    [16712]="ROGUE",  [16713]="ROGUE",  [16709]="ROGUE",  [16711]="ROGUE",
    -- Wildheart Raiment (Druid)
    [16720]="DRUID",  [16718]="DRUID",  [16706]="DRUID",  [16714]="DRUID",
    [16717]="DRUID",  [16716]="DRUID",  [16719]="DRUID",  [16715]="DRUID",
    -- Beaststalker Armor (Hunter)
    [16677]="HUNTER", [16679]="HUNTER", [16674]="HUNTER", [16681]="HUNTER",
    [16676]="HUNTER", [16680]="HUNTER", [16678]="HUNTER", [16675]="HUNTER",
    -- The Elements (Shaman)
    [16667]="SHAMAN", [16669]="SHAMAN", [16666]="SHAMAN", [16671]="SHAMAN",
    [16672]="SHAMAN", [16673]="SHAMAN", [16668]="SHAMAN", [16670]="SHAMAN",
    -- Lightforge Armor (Paladin)
    [16727]="PALADIN",[16729]="PALADIN",[16726]="PALADIN",[16722]="PALADIN",
    [16724]="PALADIN",[16723]="PALADIN",[16728]="PALADIN",[16725]="PALADIN",
    -- Battlegear of Valor (Warrior)
    [16731]="WARRIOR",[16733]="WARRIOR",[16730]="WARRIOR",[16735]="WARRIOR",
    [16737]="WARRIOR",[16736]="WARRIOR",[16732]="WARRIOR",[16734]="WARRIOR",
}

-- =====================================================================
-- Stat-based tooltip scanning
-- =====================================================================

local scanTip = nil
local statCache = {}

local STAT_PATTERNS = {
    -- Primary stats
    { "%+%d+ Agility",               PHYS },
    { "%+%d+ Strength",              C.DRUID + C.PALADIN + C.ROGUE + C.SHAMAN + C.WARRIOR },
    { "%+%d+ Intellect",             C.DRUID + C.HUNTER + C.MAGE + C.PALADIN + C.PRIEST + C.SHAMAN + C.WARLOCK },
    { "%+%d+ Stamina",               ALL },
    -- Spirit is universal mana/health regen - every class benefits, including
    -- Warriors and Rogues at low levels and on filler-stat items. Restricting
    -- Spirit excludes Warrior/Rogue from their own D1 sets (Helm of Valor +8
    -- Spirit, Shadowcraft Cap +5 Spirit) when AND-chained with other stats.
    { "%+%d+ Spirit",                ALL },

    -- Hit
    { "Hit Chance",                  PHYS },
    { "chance to hit by",            PHYS },
    { "Spell Hit",                   CASTER },
    { "hit with spells",             CASTER },

    -- Crit
    { "Critical Strike",             PHYS },
    { "critical strike by",          PHYS },
    { "Spell Critical",              CASTER },
    { "critical strike with spells", CASTER },

    -- Attack power
    { "%+%d+ Attack Power",          PHYS },
    { "attack power by %d+",         PHYS },
    { "Ranged Attack Power",         C.HUNTER },
    { "ranged attack power",         C.HUNTER },

    -- Generic spell power
    { "damage and healing done by magical spells", CASTER },
    { "damage done by magical spells",             CASTER },
    { "%+%d+ Spell Power",          CASTER },
    { "%+%d+ Spell Damage",         CASTER },

    -- Use-effect patterns (active item procs)
    -- IMPORTANT: combined pattern MUST come first, then split patterns.
    -- The Use-line loop semantics (see ScanItemStats) breaks on first match.
    { "Use:[^\n]*spell damage[^\n]*healing", CASTER },
    { "Use:[^\n]*your healing by up to %d+", C.DRUID + C.PALADIN + C.PRIEST + C.SHAMAN },
    { "Use:[^\n]*spell damage by up to %d+", CASTER },
    { "Use:[^\n]*attack power by %d+",       PHYS },
    { "Use:[^\n]*your.+critical strike",     PHYS },

    -- TurtleWoW spell power formulations (preventive - for items not yet tested)
    { "Damage and Healing Spells",   CASTER },
    { "damage and healing by up to", CASTER },

    -- Healing power
    { "healing done by spells",      C.DRUID + C.PALADIN + C.PRIEST + C.SHAMAN },
    { "Healing Spells",              C.DRUID + C.PALADIN + C.PRIEST + C.SHAMAN },
    { "%+%d+ Healing",              C.DRUID + C.PALADIN + C.PRIEST + C.SHAMAN },

    -- School-specific spell power
    { "Nature spells",               C.DRUID + C.SHAMAN },
    { "Arcane spells",               C.DRUID + C.MAGE },
    { "Fire spells",                 C.MAGE + C.SHAMAN + C.WARLOCK },
    { "Frost spells",                C.MAGE },
    { "Holy spells",                 C.PALADIN + C.PRIEST },
    { "Shadow spells",               C.PRIEST + C.WARLOCK },

    -- Mp5
    { "mana per 5 sec",              CASTER },
    { "mana every 5 sec",            CASTER },

    -- Tank stats
    { "Increased Defense",           TANK },
    { "Defense %+%d+",               TANK },
    { "%+%d+ Defense",               TANK },
    { "Dodge",                       PHYS },
    { "chance to dodge",             PHYS },
    { "Parry",                       C.PALADIN + C.ROGUE + C.SHAMAN + C.WARRIOR },
    { "chance to parry",             C.PALADIN + C.ROGUE + C.SHAMAN + C.WARRIOR },
    { "Block",                       C.PALADIN + C.SHAMAN + C.WARRIOR },
    { "chance to block",             C.PALADIN + C.SHAMAN + C.WARRIOR },
    { "Block Value",                 C.PALADIN + C.SHAMAN + C.WARRIOR },

    -- Weapon skill
    { "Increased .+ %+%d+",          PHYS },
    { "Weapon Skill",                PHYS },

    -- Haste
    { "attack speed",                ALL },
    { "casting speed",               ALL },
    { "Haste",                       ALL },
}

local function ScanItemStats(itemID)
    if statCache[itemID] then
        return statCache[itemID]
    end

    if not scanTip then
        scanTip = CreateFrame("GameTooltip", "ALGearFilterScanTip", nil, "GameTooltipTemplate")
    end
    scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
    scanTip:ClearLines()
    scanTip:SetHyperlink("item:" .. itemID .. ":0:0:0")

    local numLines = scanTip:NumLines()
    if not numLines or numLines < 2 then
        statCache[itemID] = { mask = ALL, hasClassesRestriction = false }
        return statCache[itemID]
    end

    local result = ALL
    local foundAnyStat = false
    local hasClassesRestriction = false

    for i = 2, numLines do
        local textObj = getglobal("ALGearFilterScanTipTextLeft" .. i)
        if textObj then
            local text = textObj:GetText()
            if text and text ~= "" then
                -- Hard class restriction: "Classes: Warrior, Paladin"
                if string.find(text, "^Classes:") then
                    local classMask = 0
                    if string.find(text, "Warrior") then classMask = classMask + C.WARRIOR end
                    if string.find(text, "Paladin") then classMask = classMask + C.PALADIN end
                    if string.find(text, "Hunter") then classMask = classMask + C.HUNTER end
                    if string.find(text, "Rogue") then classMask = classMask + C.ROGUE end
                    if string.find(text, "Priest") then classMask = classMask + C.PRIEST end
                    if string.find(text, "Shaman") then classMask = classMask + C.SHAMAN end
                    if string.find(text, "Mage") then classMask = classMask + C.MAGE end
                    if string.find(text, "Warlock") then classMask = classMask + C.WARLOCK end
                    if string.find(text, "Druid") then classMask = classMask + C.DRUID end
                    if classMask > 0 then
                        result = band(result, classMask)
                        foundAnyStat = true
                        hasClassesRestriction = true
                    end
                elseif string.find(text, "^%(%d+%) Set:") then
                    -- skip "(2) Set: ..." set bonus lines
                elseif string.find(text, "%(%d+/%d+%)") then
                    -- skip "Ironweave Battlesuit (0/8)" set header
                elseif string.find(text, "^%s%s") then
                    -- skip indented set member lines like "  Ironweave Belt"
                else
                    local isUseLine = string.find(text, "^Use:") ~= nil
                    for idx = 1, table.getn(STAT_PATTERNS) do
                        local pat = STAT_PATTERNS[idx][1]
                        local cls = STAT_PATTERNS[idx][2]
                        if string.find(text, pat) then
                            result = band(result, cls)
                            foundAnyStat = true
                            if isUseLine then
                                break  -- only first matching pattern wins for Use: lines
                            end
                        end
                    end
                end
            end
        end
    end

    if not foundAnyStat then
        result = ALL
    end

    statCache[itemID] = { mask = result, hasClassesRestriction = hasClassesRestriction }
    return statCache[itemID]
end

-- =====================================================================
-- Core filter
-- =====================================================================

AtlasLoot_GearFilter.selectedClass = nil

function AtlasLoot_GearFilter.CanUse(className, itemID)
    if not className or not itemID then return true end

    local classBit = C[className]
    if not classBit then return true end

    -- D1/T0.5 set whitelist overrides everything else
    local d1Owner = D1_SET_OWNER[itemID]
    if d1Owner then
        return d1Owner == className
    end

    local itemName, _, _, _, itemTypeCoarse, itemType, _, itemEquipLoc = GetItemInfo(itemID)
    if not itemName then return true end

    -- Crafting recipes (patterns, plans, formulas, schematics, designs) are
    -- never filtered by class. Their tooltips describe the CRAFTED item's
    -- stats, which the stat scanner would otherwise use to narrow down the
    -- visible classes - a Rogue must still see a Tailoring pattern for a
    -- cloth caster robe because any character can learn the recipe.
    if itemTypeCoarse == "Recipe" then
        return true
    end

    -- Equipment location check (quiver, relic, ammo)
    local locFilter = EQUIP_LOC_FILTER[itemEquipLoc]
    if locFilter then
        if band(locFilter, classBit) == 0 then
            return false
        end
    end

    -- Stat scan (also detects explicit Classes: restrictions)
    local statInfo = ScanItemStats(itemID)
    local statMask = statInfo.mask

    -- Type check - skip for slot-agnostic locs OR if item has explicit Classes line
    if not TYPE_BYPASS_LOCS[itemEquipLoc] and not statInfo.hasClassesRestriction then
        local typeFilter = TYPE_FILTER[itemType]
        if typeFilter then
            if band(typeFilter, classBit) == 0 then
                return false
            end
        end
    end

    if band(statMask, classBit) == 0 then
        return false
    end

    return true
end

-- =====================================================================
-- UI
-- =====================================================================

function AtlasLoot_GearFilter.GetPlayerClass()
    local _, cls = UnitClass("player")
    return cls
end

function AtlasLoot_GearFilter.CreateButtons(parentFrame)
    local CLASSES = {
        { key = "WARRIOR",  img = "warrior" },
        { key = "PALADIN",  img = "paladin" },
        { key = "HUNTER",   img = "hunter"  },
        { key = "ROGUE",    img = "rogue"   },
        { key = "PRIEST",   img = "priest"  },
        { key = "SHAMAN",   img = "shaman"  },
        { key = "MAGE",     img = "mage"    },
        { key = "WARLOCK",  img = "warlock" },
        { key = "DRUID",    img = "druid"   },
    }

    local mainFrame = AtlasLootDefaultFrame or parentFrame
    local SIZE = 20
    local PAD = 2
    local buttons = {}
    local flevel = mainFrame:GetFrameLevel() + 20

    local count = table.getn(CLASSES)
    local totalWidth = count * SIZE + (count - 1) * PAD
    local startX = -(totalWidth / 2) + (SIZE / 2)

    for idx, cls in ipairs(CLASSES) do
        local btn = CreateFrame("Button", "AtlasLootGearFilter_" .. cls.key, mainFrame)
        btn:SetWidth(SIZE)
        btn:SetHeight(SIZE)
        if idx == 1 then
            -- Y = -18: 3px below the original AtlasLoot top header to give the
            -- title bar more breathing room (kept in sync with RepositionUI).
            btn:SetPoint("TOP", mainFrame, "TOP", startX, -18)
        else
            btn:SetPoint("LEFT", buttons[idx - 1], "RIGHT", PAD, 0)
        end
        btn:SetFrameLevel(flevel)
        btn:SetNormalTexture("Interface\\AddOns\\AtlasLoot\\Images\\" .. cls.img)
        btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        btn.classKey = cls.key
        btn:SetScript("OnClick", function()
            AtlasLoot_GearFilter.SetFilter(this.classKey)
        end)
        btn:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT")
            local k = this.classKey
            GameTooltip:SetText(string.sub(k, 1, 1) .. string.lower(string.sub(k, 2)))
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        table.insert(buttons, btn)
    end

    AtlasLoot_GearFilter.buttons = buttons
    AtlasLoot_GearFilter.UpdateButtonHighlights()
end

function AtlasLoot_GearFilter.UpdateButtonHighlights()
    if not AtlasLoot_GearFilter.buttons then return end
    local sel = AtlasLoot_GearFilter.selectedClass
    for idx, btn in ipairs(AtlasLoot_GearFilter.buttons) do
        if sel == nil or btn.classKey == sel then
            btn:SetAlpha(1.0)
        else
            btn:SetAlpha(0.4)
        end
    end
end

function AtlasLoot_GearFilter.SetFilter(className)
    -- Toggle off when clicking the already-active class
    if className and AtlasLoot_GearFilter.selectedClass == className then
        className = nil
    end
    AtlasLoot_GearFilter.selectedClass = className
    statCache = {}
    if AtlasLoot_GearFilterDB then
        AtlasLoot_GearFilterDB.selectedClass = className
    end
    AtlasLoot_GearFilter.UpdateButtonHighlights()
    if AtlasLootItemsFrame and AtlasLootItemsFrame.refresh then
        local r = AtlasLootItemsFrame.refresh
        AtlasLoot_ShowItemsFrame(r[1], r[2], r[3])
    end
end

function AtlasLoot_GearFilter.Init()
    -- Initialize own saved variables
    if not AtlasLoot_GearFilterDB then
        AtlasLoot_GearFilterDB = {}
    end
    -- Migration from previous AtlasLoot_ClassFilter release (same addon,
    -- renamed for branding). If the old SavedVariables table exists and the
    -- new one has no selected class yet, copy the selection over and clear
    -- the old key.
    if AtlasLoot_ClassFilterDB
       and not AtlasLoot_GearFilterDB.selectedClass
       and AtlasLoot_ClassFilterDB.selectedClass then
        AtlasLoot_GearFilterDB.selectedClass = AtlasLoot_ClassFilterDB.selectedClass
        AtlasLoot_ClassFilterDB.selectedClass = nil
    end
    -- Migration from the even older integrated version that stored the class
    -- on the main AtlasLoot char DB.
    if not AtlasLoot_GearFilterDB.selectedClass
       and AtlasLootCharDB
       and AtlasLootCharDB.ClassFilterClass then
        AtlasLoot_GearFilterDB.selectedClass = AtlasLootCharDB.ClassFilterClass
        AtlasLootCharDB.ClassFilterClass = nil
    end
    AtlasLoot_GearFilter.selectedClass = AtlasLoot_GearFilterDB.selectedClass
end

-- =====================================================================
-- UI Repositioning (replaces XML edits on AtlasLoot)
-- =====================================================================

function AtlasLoot_GearFilter.RepositionUI()
    -- Top header layout: every element below the title bar is shifted down by
    -- 3px (Y = original - 3) to give the "AtlasLoot TW Edition" title more
    -- breathing room. Affected: Options/Atlas (Y -15 -> -18), Menu/SubMenu
    -- (Y -40 -> -43), ItemsFrame (Y -85 -> -88), and the class filter buttons
    -- (set in CreateButtons, kept in sync there). SelectedCategory and
    -- SelectedTable follow Menu/SubMenu via their BOTTOM anchor automatically.

    -- Options/Atlas buttons aligned with content area (45px inset)
    local opts = AtlasLootDefaultFrame_Options
    if opts then
        opts:ClearAllPoints()
        opts:SetPoint("TOPLEFT", AtlasLootDefaultFrame, "TOPLEFT", 45, -18)
    end
    local atlas = AtlasLootDefaultFrame_Atlas
    if atlas then
        atlas:ClearAllPoints()
        atlas:SetPoint("TOPRIGHT", AtlasLootDefaultFrame, "TOPRIGHT", -45, -18)
    end

    -- Menu / SubMenu (the "Select Loot Table" / "Select Sub-Table" buttons)
    local menu = AtlasLootDefaultFrame_Menu
    if menu then
        menu:ClearAllPoints()
        menu:SetPoint("TOP", AtlasLootDefaultFrame, "TOP", -130, -43)
    end
    local sub = AtlasLootDefaultFrame_SubMenu
    if sub then
        sub:ClearAllPoints()
        sub:SetPoint("TOP", AtlasLootDefaultFrame, "TOP", 130, -43)
    end

    -- Items frame (the whole content area + 30 item slots + boss menu list)
    local items = AtlasLootItemsFrame
    if items then
        items:ClearAllPoints()
        items:SetPoint("TOPLEFT", AtlasLootDefaultFrame, "TOPLEFT", 45, -88)
    end
    -- NOTE: SelectedCategory / SelectedTable FontStrings are NOT repositioned.
    -- AtlasLoot's original anchors (TOP, Menu/SubMenu, BOTTOM, 0, -4) keep boss
    -- name labels correctly placed under the menu buttons. A previous version
    -- of this addon repositioned them to TOPLEFT/-65 which broke layouts like
    -- "General Drakkisath" being mis-positioned.

    -- Move sub-table prev/next arrows from the bottom corners of the content
    -- area into the top corners, on the same row as the white sub-table name
    -- label. The Back button at the bottom is left untouched.
    local prev = AtlasLootItemsFrame_PREV
    if prev then
        prev:ClearAllPoints()
        prev:SetPoint("TOPLEFT", AtlasLootItemsFrame, "TOPLEFT", 12, -8)
    end
    local nxt = AtlasLootItemsFrame_NEXT
    if nxt then
        nxt:ClearAllPoints()
        nxt:SetPoint("TOPRIGHT", AtlasLootItemsFrame, "TOPRIGHT", -5, -8)
    end
end

-- =====================================================================
-- Apply to rendered buttons
-- =====================================================================

function AtlasLoot_GearFilter.ApplyToItems(dataID, dataSource)
    local sel = AtlasLoot_GearFilter.selectedClass
    if not sel then
        for i = 1, 30 do
            local btn = _G["AtlasLootItem_" .. i]
            if btn and btn:IsShown() then
                btn:SetAlpha(1.0)
            end
        end
        return
    end

    for i = 1, 30 do
        local btn = _G["AtlasLootItem_" .. i]
        if btn and btn:IsShown() and btn.itemID then
            local rawID = btn.itemID
            if type(rawID) == "number" or (type(rawID) == "string" and string.find(rawID, "^%d+$")) then
                local itemID = tonumber(rawID)
                if itemID and itemID > 0 then
                    if AtlasLoot_GearFilter.CanUse(sel, itemID) then
                        btn:SetAlpha(1.0)
                    else
                        btn:SetAlpha(0.3)
                    end
                else
                    btn:SetAlpha(1.0)
                end
            else
                btn:SetAlpha(1.0)
            end
        end
    end
end

-- =====================================================================
-- Self-bootstrapping hooks (runs at file load time)
-- Dependencies: AtlasLoot guarantees all globals exist
-- =====================================================================

-- Guard: only hook if AtlasLoot is loaded
if not AtlasLootDefaultFrame_OnShow then
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[AtlasLoot-GearFilter]|r AtlasLoot not found, filter disabled.")
    return
end

-- Hook AtlasLootDefaultFrame_OnShow (post-hook: init UI on first show)
local orig_OnShow = AtlasLootDefaultFrame_OnShow
AtlasLootDefaultFrame_OnShow = function()
    orig_OnShow()
    if not AtlasLoot_GearFilter.buttons then
        AtlasLoot_GearFilter.Init()
        AtlasLoot_GearFilter.CreateButtons(AtlasLootDefaultFrame)
        AtlasLoot_GearFilter.RepositionUI()
    end
end

-- Hook AtlasLoot_ShowItemsFrame (post-hook: apply filter after items render)
local orig_ShowItems = AtlasLoot_ShowItemsFrame
AtlasLoot_ShowItemsFrame = function(a, b, c)
    orig_ShowItems(a, b, c)
    AtlasLoot_GearFilter.ApplyToItems(a, b)
end
