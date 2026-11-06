-- Relationships Quest And Item Browser

local RelationshipsQuestAndItemBrowser = CreateFrame("Frame", "RelationshipsQuestAndItemBrowserCore")
RelationshipsQuestAndItemBrowser:RegisterEvent("PLAYER_LOGIN")
RelationshipsQuestAndItemBrowser:RegisterEvent("ADDON_LOADED")
RelationshipsQuestAndItemBrowser:RegisterEvent("PLAYER_LOGOUT")

RelationshipsQuestAndItemBrowserDB = RelationshipsQuestAndItemBrowserDB or {}

local RQL_ORIGINAL_SET_ITEM_REF = nil
local RQL_ORIGINAL_CHAT_HYPERLINK_SHOW = nil
local RQL_INDEX_READY = nil
local RQL_SEARCH_RESULTS = {}
local RQL_SELECTED_QUEST_ID = nil
local RQL_MODE = "browser"
local RQL_SEARCH_TEXT = ""
local RQL_LEVEL_FILTER = 0
local RQL_TYPE_FILTER = 0
local RQL_FACTION_FILTER = 0
local RQL_SOURCE_FILTER = 0
local RQL_MAX_RESULTS = 5000
local RQL_ROWS_VISIBLE = 16
local RQL_ROW_HEIGHT = 20
local RQL_PAGE = 1
local RQL_DEFAULT_BACKGROUND = "Light Sepia"
local RQL_SUPPRESS_SETITEMREF_ROUTE = nil
local RQL_SUPPRESS_CHATFRAME_ROUTE = nil

local function RQL_GetStartupBackground()
    local saved = RelationshipsQuestAndItemBrowserDB and RelationshipsQuestAndItemBrowserDB.bgColor
    if saved and saved ~= "" then return saved end
    return RQL_DEFAULT_BACKGROUND
end

-- Item browser state (Item tab)
local RQL_TAB = "quests"           -- "quests" | "items"
local RQL_ITEM_SEARCH_TEXT = ""
local RQL_ITEM_SOURCE_FILTER = 0
local RQL_ITEM_SEARCH_RESULTS = {}
local RQL_ITEM_INDEX_READY = nil
local RQL_ITEM_PAGE = 1
local RQL_SELECTED_ITEM_ID = nil

local RQL_LEVELS = {
    "All levels", "1-9", "10-19", "20-29", "30-39", "40-49", "50-59", "60+"
}
local RQL_TYPES = {
    "All types", "Normal", "Elite/Group", "Dungeon/Raid", "PvP", "Class", "Profession", "Seasonal/Event"
}
local RQL_FACTIONS = { "All factions", "Alliance", "Horde", "Neutral/Both" }
local RQL_SOURCES = { "All sources", "Vanilla", "Turtle/OctoWoW" }

-- ---------------------------------------------------------------------------
-- Dungeon / Raid classification
-- ---------------------------------------------------------------------------
-- Keyword-based detection is far more reliable than zone-id lookups because
-- pfQuest coord data for dungeon quests is inconsistent, and Turtle/OctoWoW
-- adds new dungeons/raids that aren't in vanilla's AreaTable at all.
--
-- A quest is considered Dungeon/Raid if its title, objective text or
-- description contains any of these keywords. Keywords are matched with
-- plain (non-pattern) string.find and are lower-case.
--
-- Sources: Wowhead Classic dungeon/raid quest lists, the Turtle WoW wiki
-- (turtle-wow.fandom.com) custom dungeon/raid pages, and OctoWoW patch notes.
local RQL_DUNGEON_KEYWORDS = {
    -- Vanilla dungeons
    "ragefire chasm",
    "wailing caverns",
    "the deadmines", "deadmines",
    "shadowfang keep",
    "blackfathom deeps",
    "the stockade", "the stockades", "stormwind stockade",
    "gnomeregan",
    "razorfen kraul",
    "razorfen downs",
    "scarlet monastery",
    "uldaman",
    "zul'farrak", "zulfarrak", "zul\'farrak",
    "maraudon",
    "sunken temple", "temple of atal'hakkar", "atal\'hakkar", "atalhakkar",
    "blackrock depths",
    "lower blackrock spire", "upper blackrock spire", "blackrock spire", "lbrs", "ubrs",
    "dire maul",
    "stratholme",
    "scholomance",
    -- Vanilla raids
    "molten core",
    "onyxia's lair", "onyxia\'s lair", "onyxias lair", "lair of onyxia",
    "blackwing lair", "nefarian",
    "zul'gurub", "zul\'gurub", "zulgurub",
    "ruins of ahn'qiraj", "ruins of ahn\'qiraj", "aq20",
    "temple of ahn'qiraj", "temple of ahn\'qiraj", "aq40", "ahn'qiraj", "ahn\'qiraj",
    "naxxramas",
    -- Turtle WoW / OctoWoW dungeons & raids
    "emerald sanctum",
    "karazhan crypt", "karazhan halls", "lower karazhan", "upper karazhan", "karazhan",
    "hateforge quarry", "hateforge",
    "gilneas city", "gilneas",
    "stormwind vault",
    "crescent grove",
    "black morass",
    "caverns of time",
    "tower of karazhan",
    "kara10", "kara40",
}

-- ---------- helpers ----------

local function RQL_TableSize(t)
    local n = 0
    if type(t) == "table" then for _ in pairs(t) do n = n + 1 end end
    return n
end

local function RQL_GetDB(section, key)
    if RelationshipsQuestAndItemBrowserData and RelationshipsQuestAndItemBrowserData[section] then
        return RelationshipsQuestAndItemBrowserData[section][key]
    end
    return nil
end

local function RQL_PatchTable(base, diff)
    if type(diff) ~= "table" then return base end
    if type(base) ~= "table" then base = {} end
    for k, v in pairs(diff) do
        if type(v) == "string" and v == "_" then
            base[k] = nil
        elseif type(v) == "table" and type(base[k]) == "table" then
            RQL_PatchTable(base[k], v)
        else
            base[k] = v
        end
    end
    return base
end

local function RQL_CopyTable(source)
    local dest = {}
    if type(source) ~= "table" then return dest end
    for k, v in pairs(source) do
        if type(v) == "table" then dest[k] = RQL_CopyTable(v) else dest[k] = v end
    end
    return dest
end

local function RQL_CleanText(text)
    if not text then return "" end
    text = tostring(text)
    text = string.gsub(text, "%$B", "\n")
    text = string.gsub(text, "%$N", UnitName("player") or "player")
    text = string.gsub(text, "%$C", UnitClass("player") or "class")
    text = string.gsub(text, "%$R", UnitRace("player") or "race")
    text = string.gsub(text, "%$G([^:;]*):([^;]*);", "%1/%2")
    text = string.gsub(text, "%$T", "")
    text = string.gsub(text, "\\'", "'")
    text = string.gsub(text, '\\"', '"')
    return text
end

local function RQL_ParseQuestLink(link)
    if not link then return nil end
    local _, _, qid, qlevel, qname = string.find(link, "quest:(%d+):([%-%d]*)|h%[(.-)%]|h")
    if qid then return tonumber(qid), tonumber(qlevel) or 0, qname end
    _, _, qid = string.find(link, "quest:(%d+)")
    if qid then return tonumber(qid), 0, nil end
    return nil
end

local function RQL_ColorByLevel(questLevel)
    if not questLevel or questLevel == 0 then return "|cFFFFFFFF" end
    local playerLevel = UnitLevel("player") or 1
    local diff = questLevel - playerLevel
    if diff >= 5 then return "|cFFFF0000"
    elseif diff >= 3 then return "|cFFFF8040"
    elseif diff >= -2 then return "|cFFFFFF00"
    elseif diff >= -4 then return "|cFF40BF40" end
    return "|cFF808080"
end

local function RQL_EntryIsDeleted(v)
    return type(v) == "string" and v == "_"
end

-- Detect dev/test/unused quest titles that should not appear in the browser.
local function RQL_IsDevQuestTitle(title)
    if not title or title == "" then return 1 end
    local low = string.lower(title)
    if string.find(low, "%[dep%]", 1) then return 1 end
    if string.find(low, "%[dev%]", 1) then return 1 end
    if string.find(low, "%[nyi%]", 1) then return 1 end
    if string.find(low, "%[phase", 1) then return 1 end
    if string.find(low, "%(dev%)", 1) then return 1 end
    if string.find(low, "%(test%)", 1) then return 1 end
    if string.find(low, "test quest", 1, true) then return 1 end
    if string.find(low, "internal", 1, true) then return 1 end
    if string.find(low, "unused", 1, true) then return 1 end
    if string.find(low, "deprecated", 1, true) then return 1 end
    if string.find(low, "placeholder", 1, true) then return 1 end
    if string.find(low, "^qa ", 1) then return 1 end
    if string.find(low, "^gm ", 1) then return 1 end
    if string.find(low, "do not use", 1, true) then return 1 end
    if string.find(low, "debug", 1, true) then return 1 end
    if title == "NYI" or title == "TEST" or title == "OLD" then return 1 end
    return nil
end

local function RQL_GetQuestLocale(id)
    local vanilla = RQL_GetDB("quests", "enUS")
    local turtle = RQL_GetDB("quests", "enUS-turtle")
    local base = nil
    if vanilla and type(vanilla[id]) == "table" then base = RQL_CopyTable(vanilla[id]) end
    if turtle then
        local tv = turtle[id]
        if RQL_EntryIsDeleted(tv) then base = nil
        elseif type(tv) == "table" then base = RQL_PatchTable(base, tv) end
    end
    return base
end

local function RQL_GetQuestMeta(id)
    local vanilla = RQL_GetDB("quests", "data")
    local turtle = RQL_GetDB("quests", "data-turtle")
    local base = nil
    if vanilla and type(vanilla[id]) == "table" then base = RQL_CopyTable(vanilla[id]) end
    if turtle then
        local tv = turtle[id]
        if RQL_EntryIsDeleted(tv) then base = nil
        elseif type(tv) == "table" then base = RQL_PatchTable(base, tv) end
    end
    return base
end

local function RQL_GetName(section, id)
    local vanilla = RQL_GetDB(section, "enUS")
    local turtle = RQL_GetDB(section, "enUS-turtle")
    local name = nil
    if vanilla and vanilla[id] and vanilla[id] ~= "_" then name = vanilla[id] end
    if turtle and turtle[id] then
        if turtle[id] == "_" then name = nil else name = turtle[id] end
    end
    if type(name) ~= "string" then return nil end
    return name
end

local function RQL_GetData(section, id)
    local vanilla = RQL_GetDB(section, "data")
    local turtle = RQL_GetDB(section, "data-turtle")
    local base = nil
    if vanilla and type(vanilla[id]) == "table" then base = RQL_CopyTable(vanilla[id]) end
    if turtle then
        local tv = turtle[id]
        if RQL_EntryIsDeleted(tv) then base = nil
        elseif type(tv) == "table" then base = RQL_PatchTable(base, tv) end
    end
    return base
end

local function RQL_GetZoneName(zoneId)
    if not zoneId then return "Unknown zone" end
    return RQL_GetName("zones", zoneId) or ("Zone #" .. zoneId)
end

local function RQL_GetFirstCoord(section, id)
    local data = RQL_GetData(section, id)
    if data and type(data.coords) == "table" then
        for _, coord in pairs(data.coords) do
            if type(coord) == "table" and coord[1] and coord[2] and coord[3] then
                return coord[1], coord[2], coord[3]
            end
        end
    end
    return nil
end

local function RQL_FormatCoord(section, id)
    local x, y, zone = RQL_GetFirstCoord(section, id)
    if x and y and zone then
        return RQL_GetZoneName(zone) .. " " .. string.format("%.1f, %.1f", x, y)
    end
    return "Location unknown"
end

local function RQL_FormatEntityLines(section, ids, limit)
    local out = {}
    if type(ids) ~= "table" then return out end
    local count = 0
    local shown = 0
    for _, id in pairs(ids) do
        count = count + 1
        if shown < (limit or 12) then
            shown = shown + 1
            local prefix
            if section == "units" then prefix = "NPC #"
            elseif section == "objects" then prefix = "Object #"
            else prefix = "Item #" end
            local name = RQL_GetName(section, id) or (prefix .. id)
            local coord = ""
            if section == "units" or section == "objects" then
                coord = "  |cFF808080" .. RQL_FormatCoord(section, id) .. "|r"
            end
            table.insert(out, "  |cFFFFFFFF" .. name .. "|r|cFF808080 (" .. id .. ")|r" .. coord)
        end
    end
    if count > shown then
        table.insert(out, "  |cFF808080...and " .. (count - shown) .. " more.|r")
    end
    return out
end

local function RQL_GetQuestSource(id)
    local turtleLocale = RQL_GetDB("quests", "enUS-turtle")
    local turtleData = RQL_GetDB("quests", "data-turtle")
    if (turtleLocale and type(turtleLocale[id]) == "table") or (turtleData and type(turtleData[id]) == "table") then
        return "Turtle/OctoWoW"
    end
    return "Vanilla"
end

-- Text-based dungeon detection: check title / objective / description
-- against a curated keyword list covering every vanilla dungeon + raid
-- and every Turtle/OctoWoW custom dungeon/raid.
local function RQL_TextMentionsDungeon(searchable)
    if not searchable or searchable == "" then return nil end
    for _, kw in ipairs(RQL_DUNGEON_KEYWORDS) do
        if string.find(searchable, kw, 1, true) then return 1 end
    end
    return nil
end

local function RQL_GetQuestFlags(id, meta)
    local flags = {}
    local isElite, isDungeon, isPvp, isClass, isProfession, isEvent = nil,nil,nil,nil,nil,nil
    if meta then
        if meta.class then isClass = 1 end
        if meta.skill then isProfession = 1 end
        if meta.event then isEvent = 1 end
        local function checkUnits(ids)
            if type(ids) ~= "table" then return end
            for _, uid in pairs(ids) do
                local u = RQL_GetData("units", uid)
                if u and u.rnk and tonumber(u.rnk) and tonumber(u.rnk) >= 1 then isElite = 1 end
            end
        end
        if type(meta.start) == "table" then checkUnits(meta.start.U) end
        if type(meta["end"]) == "table" then checkUnits(meta["end"].U) end
        if type(meta.obj) == "table" then checkUnits(meta.obj.U) end
    end

    -- Text search over title + objectives + description for PvP/dungeon
    local loc = RQL_GetQuestLocale(id)
    local searchable = ""
    if loc then
        searchable = string.lower((loc.T or "") .. " " .. (loc.O or "") .. " " .. (loc.D or ""))
    end
    if string.find(searchable, "warsong gulch", 1, true)
       or string.find(searchable, "arathi basin", 1, true)
       or string.find(searchable, "alterac valley", 1, true)
       or string.find(searchable, "battleground", 1, true) then
        isPvp = 1
    end
    if RQL_TextMentionsDungeon(searchable) then
        isDungeon = 1
    end

    -- PvP wins over Dungeon (Alterac Valley grave quests etc. are PvP)
    if isPvp then isDungeon = nil end

    if isDungeon then table.insert(flags, "Dungeon/Raid") end
    if isElite and not isDungeon then table.insert(flags, "Elite/Group") end
    if isPvp then table.insert(flags, "PvP") end
    if isClass then table.insert(flags, "Class") end
    if isProfession then table.insert(flags, "Profession") end
    if isEvent then table.insert(flags, "Event") end
    if table.getn(flags) == 0 then table.insert(flags, "Normal") end
    return flags, isElite, isDungeon, isPvp, isClass, isProfession, isEvent
end

local function RQL_JoinFlags(flags)
    local text = ""
    for _, value in ipairs(flags) do
        if text ~= "" then text = text .. ", " end
        text = text .. value
    end
    return text
end

local function RQL_GetFaction(meta)
    if not meta or not meta.race then return "Neutral/Both" end
    local race = tonumber(meta.race) or 0
    local ALLIANCE = 77
    local HORDE = 178
    if race == ALLIANCE then return "Alliance" end
    if race == HORDE then return "Horde" end
    if race == (ALLIANCE + HORDE) or race == 255 then return "Neutral/Both" end
    return "Faction/race locked"
end

local function RQL_GetQuestData(id, linkLevel, linkName)
    local locale = RQL_GetQuestLocale(id)
    local meta = RQL_GetQuestMeta(id)
    local data = {}
    data.id = id
    data.title = linkName or (locale and locale.T) or ("Quest #" .. id)
    data.objectives = locale and locale.O or nil
    data.description = locale and locale.D or nil
    data.level = (meta and meta.lvl) or linkLevel or 0
    data.min = (meta and meta.min) or 0
    data.meta = meta
    data.locale = locale
    data.source = RQL_GetQuestSource(id)
    data.flags = RQL_GetQuestFlags(id, meta)
    data.faction = RQL_GetFaction(meta)
    return data
end

-- ---------- indexing / filtering ----------

local function RQL_IndexQuests()
    if RQL_INDEX_READY then return end
    RQL_INDEX_READY = {}
    local vanilla = RQL_GetDB("quests", "enUS") or {}
    local turtle = RQL_GetDB("quests", "enUS-turtle") or {}
    local ids = {}
    for id, v in pairs(vanilla) do if type(v) == "table" then ids[id] = 1 end end
    for id, v in pairs(turtle) do if type(v) == "table" then ids[id] = 1 end end
    for id in pairs(ids) do
        local loc = RQL_GetQuestLocale(id)
        local meta = RQL_GetQuestMeta(id)
        if loc and loc.T and loc.T ~= "_" then
            local title = RQL_CleanText(loc.T)
            if not RQL_IsDevQuestTitle(title) then
                local obj = RQL_CleanText(loc.O or "")
                local flags, isElite, isDungeon, isPvp, isClass, isProfession, isEvent = RQL_GetQuestFlags(id, meta)
                table.insert(RQL_INDEX_READY, {
                    id = id, title = title,
                    lower = string.lower(title .. " " .. obj .. " " .. id),
                    level = (meta and meta.lvl) or 0,
                    min = (meta and meta.min) or 0,
                    flags = flags,
                    faction = RQL_GetFaction(meta),
                    source = RQL_GetQuestSource(id),
                    isElite = isElite, isDungeon = isDungeon, isPvp = isPvp,
                    isClass = isClass, isProfession = isProfession, isEvent = isEvent
                })
            end
        end
    end
    table.sort(RQL_INDEX_READY, function(a, b)
        if a.level == b.level then return a.title < b.title end
        return a.level < b.level
    end)
end

local function RQL_LevelMatches(level)
    if RQL_LEVEL_FILTER == 0 then return 1 end
    level = tonumber(level) or 0
    if RQL_LEVEL_FILTER == 1 then return level >= 1 and level <= 9 end
    if RQL_LEVEL_FILTER == 2 then return level >= 10 and level <= 19 end
    if RQL_LEVEL_FILTER == 3 then return level >= 20 and level <= 29 end
    if RQL_LEVEL_FILTER == 4 then return level >= 30 and level <= 39 end
    if RQL_LEVEL_FILTER == 5 then return level >= 40 and level <= 49 end
    if RQL_LEVEL_FILTER == 6 then return level >= 50 and level <= 59 end
    if RQL_LEVEL_FILTER == 7 then return level >= 60 end
    return 1
end

local function RQL_TypeMatches(row)
    if RQL_TYPE_FILTER == 0 then return 1 end
    if RQL_TYPE_FILTER == 1 then return not row.isElite and not row.isDungeon and not row.isPvp and not row.isClass and not row.isProfession and not row.isEvent end
    if RQL_TYPE_FILTER == 2 then return row.isElite and not row.isDungeon end
    if RQL_TYPE_FILTER == 3 then return row.isDungeon end
    if RQL_TYPE_FILTER == 4 then return row.isPvp end
    if RQL_TYPE_FILTER == 5 then return row.isClass end
    if RQL_TYPE_FILTER == 6 then return row.isProfession end
    if RQL_TYPE_FILTER == 7 then return row.isEvent end
    return 1
end

local function RQL_FactionMatches(row)
    if RQL_FACTION_FILTER == 0 then return 1 end
    if RQL_FACTION_FILTER == 1 then return row.faction == "Alliance" or row.faction == "Neutral/Both" end
    if RQL_FACTION_FILTER == 2 then return row.faction == "Horde" or row.faction == "Neutral/Both" end
    if RQL_FACTION_FILTER == 3 then return row.faction == "Neutral/Both" end
    return 1
end

local function RQL_SourceMatches(row)
    if RQL_SOURCE_FILTER == 0 then return 1 end
    if RQL_SOURCE_FILTER == 1 then return row.source == "Vanilla" end
    if RQL_SOURCE_FILTER == 2 then return row.source == "Turtle/OctoWoW" end
    return 1
end

local function RQL_SearchQuests()
    RQL_IndexQuests()
    RQL_SEARCH_RESULTS = {}
    local query = string.lower(RQL_SEARCH_TEXT or "")
    for _, row in ipairs(RQL_INDEX_READY) do
        if (query == "" or string.find(row.lower, query, 1, true))
           and RQL_LevelMatches(row.level) and RQL_TypeMatches(row)
           and RQL_FactionMatches(row) and RQL_SourceMatches(row) then
            table.insert(RQL_SEARCH_RESULTS, row)
            if table.getn(RQL_SEARCH_RESULTS) >= RQL_MAX_RESULTS then break end
        end
    end
    RQL_PAGE = 1
end


local RQL_UI = RQL_UI or {}
-- ---------- Item metadata / tooltip scanner ----------
-- Vanilla 1.12: GetItemInfo returns name, link, quality, minLevel, itemType,
-- itemSubType, maxStack, itemEquipLoc, itemTexture. Uncached items return nil;
-- probing via a hidden tooltip warms the client-side cache.
local RQL_ITEM_META_CACHE = {}

local function RQL_EnsureScanTip()
    if not RQL_UI.scanTip then
        RQL_UI.scanTip = CreateFrame("GameTooltip", "RelationshipsQuestAndItemBrowserScanTip", UIParent, "GameTooltipTemplate")
    end
    -- IMPORTANT: re-owner every call. In 1.12 a GameTooltip that has been
    -- hidden / cleared returns 0 lines from SetHyperlink until SetOwner runs
    -- again, which was the root cause of "item details never show" even after
    -- the client had cached the item.
    RQL_UI.scanTip:SetOwner(UIParent, "ANCHOR_NONE")
    return RQL_UI.scanTip
end

local RQL_QUALITY_HEX = {
    [0] = "|cff9d9d9d", [1] = "|cffffffff", [2] = "|cff1eff00",
    [3] = "|cff0070dd", [4] = "|cffa335ee", [5] = "|cffff8000",
    [6] = "|cffe6cc80", [7] = "|cffe6cc80",
}

local function RQL_GetItemMeta(id)
    if not id then return nil end
    local cached = RQL_ITEM_META_CACHE[id]
    if cached and cached.name then return cached end
    -- Warm the cache via the scanning tooltip.
    local tip = RQL_EnsureScanTip()
    tip:ClearLines()
    tip:SetHyperlink("item:" .. id .. ":0:0:0")

    -- GetItemInfo return order differs across 1.12-based clients:
    --   * Vanilla 1.12 (9 values):
    --       name, link, quality, minLevel, iType, iSubType, stack, equipLoc, texture
    --   * Turtle / OctoWoW / TBC-onward (10 values, adds iLevel):
    --       name, link, quality, iLevel, minLevel, iType, iSubType, stack, equipLoc, texture
    -- If we blindly unpack 10 vars on a 9-value client, every field after
    -- `quality` shifts left by one and `texture` receives `equipLoc`
    -- (e.g. "INVTYPE_WEAPON"), which SetTexture renders as the red "?"
    -- placeholder. Detect the shape from the last argument instead.
    local r1, r2, r3, r4, r5, r6, r7, r8, r9, r10 = GetItemInfo(id)
    local name, link, quality = r1, r2, r3
    if not name then
        if not cached then RQL_ITEM_META_CACHE[id] = { pending = 1 } end
        return RQL_ITEM_META_CACHE[id]
    end
    local function RQL_IsTexturePath(v)
        if type(v) ~= "string" then return nil end
        if string.find(v, "\\") then return 1 end
        local lv = string.lower(v)
        if string.find(lv, "^interface") then return 1 end
        return nil
    end
    local minLevel, iType, iSubType, maxStack, equipLoc, texture
    if RQL_IsTexturePath(r10) then
        -- 10-value form (has iLevel we don't need)
        minLevel, iType, iSubType, maxStack, equipLoc, texture = r5, r6, r7, r8, r9, r10
    elseif RQL_IsTexturePath(r9) then
        -- 9-value vanilla form
        minLevel, iType, iSubType, maxStack, equipLoc, texture = r4, r5, r6, r7, r8, r9
    else
        -- Unknown shape: prefer 9-value defaults, leave texture nil so the
        -- caller falls back to the question-mark placeholder.
        minLevel, iType, iSubType, maxStack, equipLoc = r4, r5, r6, r7, r8
        texture = nil
    end
    if texture and not RQL_IsTexturePath(texture) then texture = nil end
    local m = {
        name = name, link = link, quality = quality or 1,
        minLevel = minLevel or 0, iType = iType, iSubType = iSubType,
        equipLoc = equipLoc, texture = texture,
    }
    RQL_ITEM_META_CACHE[id] = m
    return m
end

local function RQL_ScanItemTooltipLines(id)
    local tip = RQL_EnsureScanTip()
    tip:ClearLines()
    tip:SetHyperlink("item:" .. id .. ":0:0:0")
    local n = tip:NumLines() or 0
    local out = {}
    -- We already display the weapon/armor subtype ("Axe", "Bow", ...) in
    -- the meta header line, and vanilla renders that same word on the right
    -- side of the slot line AND the "Binds when picked up/equipped" line.
    -- Without suppression the panel reads: "Binds when picked up   Axe" and
    -- "Two-Hand   Bow" on every weapon, which duplicates the header.
    --
    -- Suppress when the right-side text matches meta.iSubType / meta.iType
    -- (case-insensitive) OR any known weapon/armor subtype word, so it works
    -- even when the meta cache hasn't populated yet on the first scan.
    local meta = RQL_ITEM_META_CACHE[id]
    local dupA = meta and meta.iSubType or nil
    local dupB = meta and meta.iType or nil
    local dupSet = {
        ["axe"]=1,["axes"]=1,["bow"]=1,["bows"]=1,["gun"]=1,["guns"]=1,
        ["mace"]=1,["maces"]=1,["polearm"]=1,["polearms"]=1,
        ["staff"]=1,["staves"]=1,["sword"]=1,["swords"]=1,
        ["dagger"]=1,["daggers"]=1,["fist weapon"]=1,["fist weapons"]=1,
        ["crossbow"]=1,["crossbows"]=1,["wand"]=1,["wands"]=1,
        ["thrown"]=1,["cloth"]=1,["leather"]=1,["mail"]=1,["plate"]=1,
        ["shield"]=1,["shields"]=1,["idol"]=1,["libram"]=1,["totem"]=1,
        ["miscellaneous"]=1,
    }
    for i = 1, n do
        local lfs = _G and _G["RelationshipsQuestAndItemBrowserScanTipTextLeft" .. i]
                    or getglobal("RelationshipsQuestAndItemBrowserScanTipTextLeft" .. i)
        local rfs = _G and _G["RelationshipsQuestAndItemBrowserScanTipTextRight" .. i]
                    or getglobal("RelationshipsQuestAndItemBrowserScanTipTextRight" .. i)
        local ltext = lfs and lfs:GetText() or ""
        local rtext = rfs and rfs:GetText() or ""
        local r, g, b = 1, 1, 1
        if lfs and lfs.GetTextColor then r, g, b = lfs:GetTextColor() end
        local hex = string.format("|cff%02x%02x%02x", math.floor((r or 1)*255), math.floor((g or 1)*255), math.floor((b or 1)*255))
        local line = hex .. (ltext or "") .. "|r"
        local rtrim = rtext and string.gsub(rtext, "^%s*(.-)%s*$", "%1") or ""
        local rlow = string.lower(rtrim)
        local isDup = (rtrim == "")
            or (dupA and rlow == string.lower(dupA))
            or (dupB and rlow == string.lower(dupB))
            or dupSet[rlow]
        if not isDup then
            local rr, gg, bb = 1, 1, 1
            if rfs and rfs.GetTextColor then rr, gg, bb = rfs:GetTextColor() end
            local rhex = string.format("|cff%02x%02x%02x", math.floor((rr or 1)*255), math.floor((gg or 1)*255), math.floor((bb or 1)*255))
            line = line .. "     " .. rhex .. rtext .. "|r"
        end
        table.insert(out, line)
    end
    return out
end

-- ---------- Item browser (Items tab) ----------

local function RQL_GetItemSource(id)
    local turtle = RQL_GetDB("items", "enUS-turtle")
    if turtle and turtle[id] and turtle[id] ~= "_" then return "Turtle/OctoWoW" end
    return "Vanilla"
end

-- Detect dev/test/unused item names that should be hidden from the browser.
local function RQL_IsDevItemName(name)
    if not name or name == "" then return 1 end
    local low = string.lower(name)
    if string.find(low, "monster %-", 1) then return 1 end
    if string.find(low, "qatest", 1, true) then return 1 end
    if string.find(low, "^old", 1) then return 1 end
    if string.find(low, "%[dep%]", 1) then return 1 end
    if string.find(low, "%[dev%]", 1) then return 1 end
    if string.find(low, "%[nyi%]", 1) then return 1 end
    if string.find(low, "test item", 1, true) then return 1 end
    if string.find(low, "unused", 1, true) then return 1 end
    if string.find(low, "deprecated", 1, true) then return 1 end
    if string.find(low, "placeholder", 1, true) then return 1 end
    if string.find(low, "debug", 1, true) then return 1 end
    return nil
end

-- Find quests that reference an item (as start / turn-in / objective).
local function RQL_ItemFindQuests(itemId)
    local out = {}
    local seen = {}
    local function scan(dbKey)
        local db = RQL_GetDB("quests", dbKey)
        if type(db) ~= "table" then return end
        for qid, meta in pairs(db) do
            if type(meta) == "table" then
                local hit
                local function has(list)
                    if type(list) ~= "table" then return nil end
                    for _, v in pairs(list) do
                        if v == itemId then return 1 end
                    end
                    return nil
                end
                if type(meta.start) == "table" and has(meta.start.I) then hit = "Starts" end
                if not hit and type(meta["end"]) == "table" and has(meta["end"].I) then hit = "Turn-in" end
                if not hit and type(meta.obj) == "table" and has(meta.obj.I) then hit = "Objective" end
                if hit and not seen[qid] then
                    seen[qid] = 1
                    table.insert(out, { id = qid, role = hit })
                end
            end
        end
    end
    scan("data")
    scan("data-turtle")
    return out
end

local function RQL_IndexItems()
    if RQL_ITEM_INDEX_READY then return end
    RQL_ITEM_INDEX_READY = {}
    local vanilla = RQL_GetDB("items", "enUS") or {}
    local turtle = RQL_GetDB("items", "enUS-turtle") or {}
    local ids = {}
    for id, v in pairs(vanilla) do if type(v) == "string" and v ~= "_" then ids[id] = 1 end end
    for id, v in pairs(turtle) do
        if v == "_" then ids[id] = nil
        elseif type(v) == "string" then ids[id] = 1 end
    end
    for id in pairs(ids) do
        local name = RQL_GetName("items", id)
        if name and not RQL_IsDevItemName(name) then
            table.insert(RQL_ITEM_INDEX_READY, {
                id = id,
                name = name,
                lower = string.lower(name .. " " .. id),
                source = RQL_GetItemSource(id),
            })
        end
    end
    table.sort(RQL_ITEM_INDEX_READY, function(a, b) return a.name < b.name end)
end

local function RQL_ItemSourceMatches(row)
    if RQL_ITEM_SOURCE_FILTER == 0 then return 1 end
    if RQL_ITEM_SOURCE_FILTER == 1 then return row.source == "Vanilla" end
    if RQL_ITEM_SOURCE_FILTER == 2 then return row.source == "Turtle/OctoWoW" end
    return 1
end

local function RQL_SearchItems()
    RQL_IndexItems()
    RQL_ITEM_SEARCH_RESULTS = {}
    local query = string.lower(RQL_ITEM_SEARCH_TEXT or "")
    for _, row in ipairs(RQL_ITEM_INDEX_READY) do
        if (query == "" or string.find(row.lower, query, 1, true))
           and RQL_ItemSourceMatches(row) then
            table.insert(RQL_ITEM_SEARCH_RESULTS, row)
            if table.getn(RQL_ITEM_SEARCH_RESULTS) >= RQL_MAX_RESULTS then break end
        end
    end
    RQL_ITEM_PAGE = 1
end

-- ---------- UI ----------

function RQL_LinkQuestToChat(id, level, title)
    if not id then return end
    local meta = RQL_GetQuestMeta(id)
    local loc = RQL_GetQuestLocale(id)
    local lvl = tonumber(level) or (meta and tonumber(meta.lvl)) or 0
    local name = title or (loc and loc.T) or ("Quest #" .. id)
    local link = "|cffffff00|Hquest:" .. id .. ":" .. lvl .. "|h[" .. name .. "]|h|r"

    if not ChatFrameEditBox then return end
    if not ChatFrameEditBox:IsVisible() then
        ChatFrameEditBox:Show()
    end
    ChatFrameEditBox:SetFocus()
    ChatFrameEditBox:Insert(link)
end


local function RQL_TotalPages()
    local results = (RQL_TAB == "items") and RQL_ITEM_SEARCH_RESULTS or RQL_SEARCH_RESULTS
    local n = table.getn(results)
    if n <= 0 then return 1 end
    return math.floor((n - 1) / RQL_ROWS_VISIBLE) + 1
end

local function RQL_CurrentPage()
    if RQL_TAB == "items" then return RQL_ITEM_PAGE end
    return RQL_PAGE
end

local function RQL_SetCurrentPage(p)
    if RQL_TAB == "items" then RQL_ITEM_PAGE = p else RQL_PAGE = p end
end

local function RQL_UpdateStatus()
    if RQL_TAB == "items" then
        if RQL_UI.itemStatus then
            local total = RQL_ITEM_INDEX_READY and table.getn(RQL_ITEM_INDEX_READY) or 0
            local n = table.getn(RQL_ITEM_SEARCH_RESULTS)
            RQL_UI.itemStatus:SetText("Matches: " .. n .. " / " .. total .. " items")
        end
    else
        if RQL_UI.status then
            local total = RQL_INDEX_READY and table.getn(RQL_INDEX_READY) or 0
            local n = table.getn(RQL_SEARCH_RESULTS)
            RQL_UI.status:SetText("Matches: " .. n .. " / " .. total .. " quests")
        end
    end
    if RQL_UI.pageLabel then
        RQL_UI.pageLabel:SetText("Page " .. RQL_CurrentPage() .. " / " .. RQL_TotalPages())
    end
end

local function RQL_UpdateList()
    if not RQL_UI.rows then return end
    local total = RQL_TotalPages()
    local page = RQL_CurrentPage()
    if page < 1 then page = 1 end
    if page > total then page = total end
    RQL_SetCurrentPage(page)
    local offset = (page - 1) * RQL_ROWS_VISIBLE
    local results = (RQL_TAB == "items") and RQL_ITEM_SEARCH_RESULTS or RQL_SEARCH_RESULTS
    for i = 1, RQL_ROWS_VISIBLE do
        local row = RQL_UI.rows[i]
        local idx = i + offset
        local r = results[idx]
        if r then
            if RQL_TAB == "items" then
                local meta = RQL_GetItemMeta(r.id)
                local qcol = "|cFFFFFFFF"
                local lvlText = "?"
                if meta and meta.name then
                    qcol = RQL_QUALITY_HEX[meta.quality or 1] or "|cFFFFFFFF"
                    local minLvl = tonumber(meta.minLevel)
                    lvlText = (minLvl and minLvl > 0) and tostring(minLvl) or "-"
                end
                row.left:SetText(qcol .. "[" .. lvlText .. "] " .. r.name .. "|r")
                row.right:SetText("|cFF808080(#" .. r.id .. ", " .. r.source .. ")|r")
                row.itemId = r.id
                row.itemName = r.name
                row.questId = nil
            else
                local lvlNum = tonumber(r.level)
                local lvl = lvlNum and lvlNum > 0 and tostring(lvlNum) or "?"
                local color = RQL_ColorByLevel(r.level)
                row.left:SetText(color .. "[" .. lvl .. "]|r " .. r.title)
                row.right:SetText("|cFF808080(" .. RQL_JoinFlags(r.flags) .. ", " .. r.source .. ")|r")
                row.questId = r.id
                row.questLevel = r.level
                row.questTitle = r.title
                row.itemId = nil
            end
            row:Show()
        else
            row:Hide()
            row.questId = nil
            row.itemId = nil
        end
    end
    if RQL_UI.pageLabel then
        RQL_UI.pageLabel:SetText("Page " .. page .. " / " .. total)
    end
    if RQL_UI.btnPrev then
        if page <= 1 then RQL_UI.btnPrev:Disable() else RQL_UI.btnPrev:Enable() end
    end
    if RQL_UI.btnNext then
        if page >= total then RQL_UI.btnNext:Disable() else RQL_UI.btnNext:Enable() end
    end
end

-- ---------- Detail view (Quest-log style) ----------

-- Header gap (space above a section header) and body gap (space between the
-- header and its body text) are separated so titles never sit tight against
-- the previous paragraph, matching the real quest log layout.
local RQL_HEADER_GAP = 20   -- space above a section header
local RQL_BODY_GAP   = 8    -- space between header and its body
local RQL_DETAIL_PAD = 18   -- inner left/right/top padding of the parchment

local function RQL_DetailSetSection(fs, label, body, prev)
    if not body or body == "" then
        fs.header:Hide(); fs.text:Hide()
        return prev
    end
    fs.header:SetText(label)
    fs.text:SetText(body)
    fs.header:ClearAllPoints()
    if prev then
        fs.header:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -RQL_HEADER_GAP)
    else
        fs.header:SetPoint("TOPLEFT", RQL_UI.detailContent, "TOPLEFT", 0, 0)
    end
    fs.text:ClearAllPoints()
    fs.text:SetPoint("TOPLEFT", fs.header, "BOTTOMLEFT", 0, -RQL_BODY_GAP)
    fs.text:SetWidth(RQL_UI.detailContent:GetWidth())
    fs.header:Show(); fs.text:Show()
    return fs.text
end

local function RQL_MakeDetailSection(parent)
    -- Header: gold quest-log header font
    local h = parent:CreateFontString(nil, "OVERLAY", "QuestTitleFont")
    h:SetJustifyH("LEFT"); h:Hide()
    -- Body: the standard quest-log body font
    local b = parent:CreateFontString(nil, "OVERLAY", "QuestFont")
    b:SetJustifyH("LEFT"); b:SetJustifyV("TOP"); b:SetSpacing(2); b:Hide()
    return { header = h, text = b }
end

local RQL_ShowQuest -- forward declaration; defined below
local function RQL_RenderQuestDetail(id, linkLevel, linkName)
    local data = RQL_GetQuestData(id, linkLevel, linkName)

    -- Title
    RQL_UI.dTitle:SetText(data.title)
    RQL_UI.dTitle:SetWidth(RQL_UI.detailContent:GetWidth())

    -- Meta line under title (with a bit of breathing room below the title)
    local color = RQL_ColorByLevel(data.level)
    local lvlText = (data.level and data.level > 0) and tostring(data.level) or "?"
    local minText = (data.min and data.min > 0) and tostring(data.min) or "any"
    local metaLine = color .. "Level " .. lvlText .. "|r"
        .. "   |cFFFFD100Requires:|r " .. minText
        .. "   |cFFFFD100Type:|r " .. RQL_JoinFlags(data.flags)
        .. "   |cFFFFD100Faction:|r " .. data.faction
        .. "   |cFFFFD100Source:|r " .. data.source
        .. "   |cFF808080#" .. id .. "|r"
    RQL_UI.dMeta:SetText(metaLine)
    RQL_UI.dMeta:SetWidth(RQL_UI.detailContent:GetWidth())
    RQL_UI.dMeta:ClearAllPoints()
    RQL_UI.dMeta:SetPoint("TOPLEFT", RQL_UI.dTitle, "BOTTOMLEFT", 0, -10)

    local prev = RQL_UI.dMeta

    prev = RQL_DetailSetSection(RQL_UI.dObjSection, "Objective",
        data.objectives and RQL_CleanText(data.objectives) or nil, prev)

    prev = RQL_DetailSetSection(RQL_UI.dDescSection, "Description",
        data.description and RQL_CleanText(data.description) or nil, prev)

    -- Start / End / Objective NPC + Object lists (items handled separately below)
    local locBody = ""
    if data.meta then
        local function add(label, lines)
            if table.getn(lines) == 0 then return end
            if locBody ~= "" then locBody = locBody .. "\n\n" end
            locBody = locBody .. "|cFFFFD100" .. label .. "|r\n\n" .. table.concat(lines, "\n")
        end
        if type(data.meta.start) == "table" then
            add("Quest Giver (NPC)", RQL_FormatEntityLines("units", data.meta.start.U))
            add("Quest Giver (Object)", RQL_FormatEntityLines("objects", data.meta.start.O))
        end
        if type(data.meta["end"]) == "table" then
            add("Turn-in (NPC)", RQL_FormatEntityLines("units", data.meta["end"].U))
            add("Turn-in (Object)", RQL_FormatEntityLines("objects", data.meta["end"].O))
        end
        if type(data.meta.obj) == "table" then
            add("Objective NPCs", RQL_FormatEntityLines("units", data.meta.obj.U))
            add("Objective Objects", RQL_FormatEntityLines("objects", data.meta.obj.O))
        end
    end
    prev = RQL_DetailSetSection(RQL_UI.dLocSection, "Locations",
        locBody ~= "" and locBody or nil, prev)

    -- ---------- Clickable Items section ----------
    RQL_UI.dItemButtons = RQL_UI.dItemButtons or {}
    for i = 1, table.getn(RQL_UI.dItemButtons) do RQL_UI.dItemButtons[i]:Hide() end

    local itemEntries = {}
    local seenItem = {}
    local function collectItems(label, ids)
        if type(ids) ~= "table" then return end
        for _, iid in pairs(ids) do
            if iid and not seenItem[iid] then
                seenItem[iid] = 1
                local name = RQL_GetName("items", iid) or ("Item #" .. iid)
                table.insert(itemEntries, { id = iid, name = name, role = label })
            end
        end
    end
    if data.meta then
        if type(data.meta.start) == "table" then collectItems("Starts quest", data.meta.start.I) end
        if type(data.meta["end"]) == "table" then collectItems("Turn-in", data.meta["end"].I) end
        if type(data.meta.obj) == "table" then collectItems("Objective", data.meta.obj.I) end
    end

    if table.getn(itemEntries) > 0 then
        local sec = RQL_UI.dItemSection
        sec.header:SetText("Items (click to open)")
        sec.header:ClearAllPoints()
        sec.header:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -RQL_HEADER_GAP)
        sec.header:Show()
        sec.text:Hide()

        local anchor = sec.header
        local gap = RQL_BODY_GAP
        for i = 1, table.getn(itemEntries) do
            local entry = itemEntries[i]
            local btn = RQL_UI.dItemButtons[i]
            if not btn then
                btn = CreateFrame("Button", nil, RQL_UI.detailContent)
                btn:SetHeight(16)
                local fs = btn:CreateFontString(nil, "OVERLAY", "QuestFont")
                fs:SetPoint("LEFT", btn, "LEFT", 0, 0)
                fs:SetJustifyH("LEFT")
                btn.fs = fs
                local hl = btn:CreateTexture(nil, "HIGHLIGHT")
                hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
                hl:SetBlendMode("ADD")
                hl:SetAllPoints(btn)
                btn:SetScript("OnEnter", function()
                    if this.fs then this.fs:SetTextColor(1, 1, 0.4) end
                end)
                btn:SetScript("OnLeave", function()
                    if this.fs then this.fs:SetTextColor(1, 1, 1) end
                end)
                btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                btn:SetScript("OnClick", function()
                    if this.itemId then
                        RQL_ShowItem(this.itemId, this.itemName)
                        if RQL_UI.detailScroll then RQL_UI.detailScroll:SetVerticalScroll(0) end
                    end
                end)
                RQL_UI.dItemButtons[i] = btn
            end
            btn.itemId = entry.id
            btn.itemName = entry.name
            btn.fs:SetText("  |cFFFFFFFF" .. entry.name .. "|r  |cFF808080(#" .. entry.id .. ", " .. entry.role .. ")|r  |cFFAAAAFF[click to open]|r")
            btn.fs:SetTextColor(1, 1, 1)
            btn:SetWidth(RQL_UI.detailContent:GetWidth())
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", anchor, (anchor == sec.header) and "BOTTOMLEFT" or "BOTTOMLEFT", 0, -gap)
            btn:Show()
            anchor = btn
            gap = 4
        end
        prev = anchor
    else
        RQL_UI.dItemSection.header:Hide()
        RQL_UI.dItemSection.text:Hide()
    end

    -- Prerequisites (clickable — jump straight to the required quest)
    RQL_UI.dPreButtons = RQL_UI.dPreButtons or {}
    -- Hide any previously-shown prereq buttons before re-rendering
    for i = 1, table.getn(RQL_UI.dPreButtons) do
        RQL_UI.dPreButtons[i]:Hide()
    end

    local preList = (data.meta and type(data.meta.pre) == "table") and data.meta.pre or nil
    if preList and table.getn(preList) > 0 then
        local sec = RQL_UI.dPreSection
        sec.header:SetText("Prerequisites (click to open)")
        sec.header:ClearAllPoints()
        sec.header:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -RQL_HEADER_GAP)
        sec.header:Show()
        sec.text:Hide()

        local anchor = sec.header
        local gap = RQL_BODY_GAP
        for i = 1, table.getn(preList) do
            local preId = preList[i]
            local preLocale = RQL_GetQuestLocale(preId)
            local name = (preLocale and preLocale.T) or ("Quest #" .. preId)

            local btn = RQL_UI.dPreButtons[i]
            if not btn then
                btn = CreateFrame("Button", nil, RQL_UI.detailContent)
                btn:SetHeight(16)
                local fs = btn:CreateFontString(nil, "OVERLAY", "QuestFont")
                fs:SetPoint("LEFT", btn, "LEFT", 0, 0)
                fs:SetJustifyH("LEFT")
                btn.fs = fs
                local hl = btn:CreateTexture(nil, "HIGHLIGHT")
                hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
                hl:SetBlendMode("ADD")
                hl:SetAllPoints(btn)
                btn:SetScript("OnEnter", function()
                    if this.fs then this.fs:SetTextColor(1, 1, 0.4) end
                end)
                btn:SetScript("OnLeave", function()
                    if this.fs then this.fs:SetTextColor(1, 1, 1) end
                end)
                btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                btn:SetScript("OnClick", function()
                    if this.preId then
                        RQL_ShowQuest(this.preId, 0, this.preName)
                        if RQL_UI.detailScroll then RQL_UI.detailScroll:SetVerticalScroll(0) end
                    end
                end)
                RQL_UI.dPreButtons[i] = btn
            end
            btn.preId = preId
            btn.preName = name
            btn.fs:SetText("  " .. name .. "  |cFF808080(#" .. preId .. ")|r  |cFFAAAAFF[click to open]|r")
            btn.fs:SetTextColor(1, 1, 1)
            btn:SetWidth(RQL_UI.detailContent:GetWidth())
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", anchor, (anchor == sec.header) and "BOTTOMLEFT" or "BOTTOMLEFT", 0, -gap)
            btn:Show()
            anchor = btn
            gap = 4
        end
        prev = anchor
    else
        -- No prerequisites — hide the section entirely.
        RQL_UI.dPreSection.header:Hide()
        RQL_UI.dPreSection.text:Hide()
    end

    if not data.meta then
        RQL_UI.dFooter:SetText("|cFFFF8080No bundled database entry found. Showing link-only data.|r")
        RQL_UI.dFooter:ClearAllPoints()
        RQL_UI.dFooter:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -RQL_HEADER_GAP)
        RQL_UI.dFooter:SetWidth(RQL_UI.detailContent:GetWidth())
        RQL_UI.dFooter:Show()
    else
        RQL_UI.dFooter:Hide()
    end

    -- Recompute scroll-child height so the ScrollFrame knows how far to scroll.
    -- Without this the child stays at its initial height (1) and the wheel /
    -- scrollbar have no range on longer quests.
    local function _rql_h(fs)
        if not fs then return 0 end
        if fs.IsShown and not fs:IsShown() then return 0 end
        -- GetStringHeight may be missing on some 1.12 clients / non-FontString
        -- regions. Guard the call and fall back to GetHeight so a nil method
        -- can't abort the whole layout (which would leave the ScrollFrame
        -- with a stale/zero range and break the scrollbar).
        local h
        if type(fs.GetStringHeight) == "function" then
            local ok, v = pcall(fs.GetStringHeight, fs)
            if ok and v and v > 0 then h = v end
        end
        if (not h) and type(fs.GetHeight) == "function" then
            local ok, v = pcall(fs.GetHeight, fs)
            if ok and v then h = v end
        end
        return h or 0
    end
    local total = _rql_h(RQL_UI.dTitle) + 10 + _rql_h(RQL_UI.dMeta)
    local function _rql_addSec(sec)
        if sec and sec.header and sec.header:IsShown() then
            total = total + RQL_HEADER_GAP + _rql_h(sec.header)
            if sec.text and sec.text:IsShown() then
                total = total + RQL_BODY_GAP + _rql_h(sec.text)
            end
        end
    end
    _rql_addSec(RQL_UI.dObjSection)
    _rql_addSec(RQL_UI.dDescSection)
    _rql_addSec(RQL_UI.dLocSection)
    if RQL_UI.dPreSection and RQL_UI.dPreSection.header:IsShown() then
        total = total + RQL_HEADER_GAP + _rql_h(RQL_UI.dPreSection.header)
        local btns = RQL_UI.dPreButtons or {}
        local shown = 0
        for i = 1, table.getn(btns) do
            if btns[i]:IsShown() then
                total = total + (shown == 0 and RQL_BODY_GAP or 4) + (btns[i]:GetHeight() or 16)
                shown = shown + 1
            end
        end
    end
    if RQL_UI.dItemSection and RQL_UI.dItemSection.header:IsShown() then
        total = total + RQL_HEADER_GAP + _rql_h(RQL_UI.dItemSection.header)
        local btns = RQL_UI.dItemButtons or {}
        local shown = 0
        for i = 1, table.getn(btns) do
            if btns[i]:IsShown() then
                total = total + (shown == 0 and RQL_BODY_GAP or 4) + (btns[i]:GetHeight() or 16)
                shown = shown + 1
            end
        end
    end
    if RQL_UI.dFooter:IsShown() then
        total = total + RQL_HEADER_GAP + _rql_h(RQL_UI.dFooter)
    end
    RQL_UI.detailContent:SetHeight(total + 24)
    if RQL_UI.detailScroll and RQL_UI.detailScroll.UpdateScrollChildRect then
        RQL_UI.detailScroll:UpdateScrollChildRect()
        -- Nudge the scroll position so the ScrollFrame recomputes its
        -- vertical range immediately. Without this, the scrollbar thumb
        -- occasionally stays disabled on longer quests until the user
        -- resizes or reopens the frame.
        local cur = RQL_UI.detailScroll:GetVerticalScroll() or 0
        local maxs = RQL_UI.detailScroll:GetVerticalScrollRange() or 0
        if cur > maxs then cur = maxs end
        RQL_UI.detailScroll:SetVerticalScroll(cur)
    end
end

-- ---------- Show/hide screens ----------

local function RQL_UpdateTabVisuals()
    if RQL_UI.tabQuests and RQL_UI.tabItems then
        if RQL_TAB == "items" then
            RQL_UI.tabItems:LockHighlight()
            RQL_UI.tabQuests:UnlockHighlight()
        else
            RQL_UI.tabQuests:LockHighlight()
            RQL_UI.tabItems:UnlockHighlight()
        end
    end
end

local function RQL_ShowBrowser()
    RQL_TAB = "quests"
    RQL_MODE = "browser"
    RQL_UI.iRetryFor = nil
    if RelationshipsQuestAndItemBrowserFrameTitle then RelationshipsQuestAndItemBrowserFrameTitle:SetText("Relationships Quest And Item Browser") end
    if RQL_UI.detail then RQL_UI.detail:Hide() end
    if RQL_UI.itemDetail then RQL_UI.itemDetail:Hide() end
    if RQL_UI.itemControls then RQL_UI.itemControls:Hide() end
    if RQL_UI.listArea then RQL_UI.listArea:Show() end
    if RQL_UI.controls then RQL_UI.controls:Show() end
    if RQL_UI.pager then RQL_UI.pager:Show() end
    RQL_UpdateTabVisuals()
    RQL_SearchQuests()
    RQL_UpdateStatus()
    RQL_UpdateList()
    RelationshipsQuestAndItemBrowserFrame:Show()
end

local function RQL_ShowItemBrowser()
    RQL_TAB = "items"
    RQL_MODE = "browser"
    RQL_UI.iRetryFor = nil
    if RelationshipsQuestAndItemBrowserFrameTitle then RelationshipsQuestAndItemBrowserFrameTitle:SetText("Relationships Quest And Item Browser") end
    if RQL_UI.detail then RQL_UI.detail:Hide() end
    if RQL_UI.itemDetail then RQL_UI.itemDetail:Hide() end
    if RQL_UI.controls then RQL_UI.controls:Hide() end
    if RQL_UI.itemControls then RQL_UI.itemControls:Show() end
    if RQL_UI.listArea then RQL_UI.listArea:Show() end
    if RQL_UI.pager then RQL_UI.pager:Show() end
    RQL_UpdateTabVisuals()
    RQL_SearchItems()
    RQL_UpdateStatus()
    RQL_UpdateList()
    RelationshipsQuestAndItemBrowserFrame:Show()
end

function RQL_ShowQuest(id, level, name)
    RQL_MODE = "details"
    RQL_SELECTED_QUEST_ID = id
    -- Cancel any pending item-detail tooltip retry from a previous screen.
    RQL_UI.iRetryFor = nil
    if RelationshipsQuestAndItemBrowserFrameTitle then RelationshipsQuestAndItemBrowserFrameTitle:SetText("Quest Details") end
    if RQL_UI.controls then RQL_UI.controls:Hide() end
    if RQL_UI.listArea then RQL_UI.listArea:Hide() end
    if RQL_UI.pager then RQL_UI.pager:Hide() end
    -- Hide item screens too, otherwise navigating quest -> item -> related
    -- quest leaves the item detail rendered underneath the quest text.
    if RQL_UI.itemControls then RQL_UI.itemControls:Hide() end
    if RQL_UI.itemDetail then RQL_UI.itemDetail:Hide() end
    RQL_RenderQuestDetail(id, level, name)
    if RQL_UI.detailScroll then RQL_UI.detailScroll:SetVerticalScroll(0) end
    if RQL_UI.detail then RQL_UI.detail:Show() end
    RelationshipsQuestAndItemBrowserFrame:Show()
end

-- Item detail renderer + shower
function RQL_ShowItem(id, name)
    if not id then return end
    RQL_MODE = "itemDetails"
    RQL_SELECTED_ITEM_ID = id
    if not RQL_UI.itemDetail then return end
    if RelationshipsQuestAndItemBrowserFrameTitle then RelationshipsQuestAndItemBrowserFrameTitle:SetText("Item Details") end
    if RQL_UI.controls then RQL_UI.controls:Hide() end
    if RQL_UI.itemControls then RQL_UI.itemControls:Hide() end
    if RQL_UI.listArea then RQL_UI.listArea:Hide() end
    if RQL_UI.pager then RQL_UI.pager:Hide() end
    if RQL_UI.detail then RQL_UI.detail:Hide() end

    local resolvedName = name or RQL_GetName("items", id) or ("Item #" .. id)
    local source = RQL_GetItemSource(id)

    local meta = RQL_GetItemMeta(id)
    local qcol = "|cFFFFFFFF"
    local lvlText = "-"
    local extra = ""
    if meta and meta.name then
        qcol = RQL_QUALITY_HEX[meta.quality or 1] or "|cFFFFFFFF"
        local ml = tonumber(meta.minLevel)
        if ml and ml > 0 then lvlText = tostring(ml) end
        if meta.iType then
            extra = "   |cFFFFD100Type:|r " .. meta.iType
            if meta.iSubType and meta.iSubType ~= "" then extra = extra .. " (" .. meta.iSubType .. ")" end
        end
    end
    RQL_UI.iTitle:SetText(qcol .. "[" .. lvlText .. "] " .. resolvedName .. "|r")
    RQL_UI.iMeta:SetText("|cFFFFD100Item ID:|r " .. id .. "   |cFFFFD100Source:|r " .. source .. extra)

    -- Icon: use GetItemInfo texture when we have it; fall back to the
    -- vanilla question-mark placeholder so the slot is never empty. Keep
    -- it on top of the decorative slot art; UI-EmptySlot-Disabled is not
    -- just a border and can otherwise cover the icon on 1.12 clients.
    if RQL_UI.iIcon then
        if meta and meta.texture then
            RQL_UI.iIcon:SetTexture(meta.texture)
        else
            RQL_UI.iIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end
        RQL_UI.iIcon:Show()
    end

    -- Scan full tooltip and render into the description FontString.
    if not RQL_UI.iDesc then
        -- Use the standard quest-log body font (larger + more legible than
        -- GameFontHighlightSmall) and add generous line spacing so each
        -- stat / enchant / requirement row is clearly separated.
        RQL_UI.iDesc = RQL_UI.itemDetailContent:CreateFontString(nil, "OVERLAY", "QuestFont")
        RQL_UI.iDesc:SetJustifyH("LEFT")
        RQL_UI.iDesc:SetJustifyV("TOP")
        RQL_UI.iDesc:SetSpacing(7)
    end
    RQL_UI.iDesc:ClearAllPoints()
    -- Anchor description strictly BELOW the icon + meta block. Icon is 44
    -- tall at y=0, meta line sits under the title to its right, so the
    -- guaranteed clearance point is icon-height + a comfortable gap.
    RQL_UI.iDesc:SetPoint("TOPLEFT", RQL_UI.itemDetailContent, "TOPLEFT",
        0, -(44 + RQL_HEADER_GAP + 6))
    RQL_UI.iDesc:SetWidth(RQL_UI.itemDetailContent:GetWidth())
    local lines = RQL_ScanItemTooltipLines(id)
    local desc
    if lines and table.getn(lines) > 0 then
        desc = table.concat(lines, "\n")
    else
        -- Fall back to whatever GetItemInfo gave us so the panel is never
        -- empty. An OnUpdate retry (below) will replace this once the
        -- client-side item cache is warm.
        local parts = {}
        table.insert(parts, qcol .. resolvedName .. "|r")
        if meta and meta.name then
            if meta.iType then
                local t = meta.iType
                if meta.iSubType and meta.iSubType ~= "" then t = t .. " (" .. meta.iSubType .. ")" end
                table.insert(parts, "|cFFFFFFFF" .. t .. "|r")
            end
            if meta.minLevel and meta.minLevel > 0 then
                table.insert(parts, "|cFFFFFFFFRequires Level " .. meta.minLevel .. "|r")
            end
        end
        table.insert(parts, "|cFF808080Loading full item data from the server... this will refresh in a moment.|r")
        desc = table.concat(parts, "\n")
        -- Schedule a re-scan; the OnUpdate ticker in RQL_UI.retryTicker will
        -- keep probing SetHyperlink until GameTooltip returns real lines.
        RQL_UI.iRetryFor = id
        RQL_UI.iRetryElapsed = 0
        RQL_UI.iRetryTries = 0
    end
    RQL_UI.iDesc:SetText(desc)
    RQL_UI.iDesc:Show()
    local descH = RQL_UI.iDesc:GetHeight() or 0

    -- Clear previous quest buttons
    for i = 1, table.getn(RQL_UI.iQuestButtons) do RQL_UI.iQuestButtons[i]:Hide() end

    local relatedQuests = RQL_ItemFindQuests(id)
    local sec = RQL_UI.iQuestSection
    local totalHeight = 40 + 20 + RQL_HEADER_GAP + descH
    if table.getn(relatedQuests) > 0 then
        sec.header:SetText("Related Quests (click to open)")
        sec.header:ClearAllPoints()
        sec.header:SetPoint("TOPLEFT", RQL_UI.iDesc, "BOTTOMLEFT", 0, -RQL_HEADER_GAP)
        sec.header:Show()
        sec.text:Hide()
        totalHeight = totalHeight + RQL_HEADER_GAP + 20

        local anchor = sec.header
        local gap = RQL_BODY_GAP
        for i = 1, table.getn(relatedQuests) do
            local entry = relatedQuests[i]
            local loc = RQL_GetQuestLocale(entry.id)
            local meta = RQL_GetQuestMeta(entry.id)
            local title = (loc and loc.T) or ("Quest #" .. entry.id)
            local lvl = (meta and meta.lvl) or 0

            local btn = RQL_UI.iQuestButtons[i]
            if not btn then
                btn = CreateFrame("Button", nil, RQL_UI.itemDetailContent)
                btn:SetHeight(16)
                local fs = btn:CreateFontString(nil, "OVERLAY", "QuestFont")
                fs:SetPoint("LEFT", btn, "LEFT", 0, 0)
                fs:SetJustifyH("LEFT")
                btn.fs = fs
                local hl = btn:CreateTexture(nil, "HIGHLIGHT")
                hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
                hl:SetBlendMode("ADD")
                hl:SetAllPoints(btn)
                btn:SetScript("OnEnter", function() if this.fs then this.fs:SetTextColor(1, 1, 0.4) end end)
                btn:SetScript("OnLeave", function() if this.fs then this.fs:SetTextColor(1, 1, 1) end end)
                btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                btn:SetScript("OnClick", function()
                    if this.qid then RQL_ShowQuest(this.qid, this.qlvl, this.qtitle) end
                end)
                RQL_UI.iQuestButtons[i] = btn
            end
            btn.qid = entry.id
            btn.qlvl = lvl
            btn.qtitle = title
            local lvlText = (lvl and lvl > 0) and tostring(lvl) or "?"
            local color = RQL_ColorByLevel(lvl)
            btn.fs:SetText("  " .. color .. "[" .. lvlText .. "]|r " .. title .. "  |cFF808080(#" .. entry.id .. ", " .. entry.role .. ")|r  |cFFAAAAFF[click to open]|r")
            btn.fs:SetTextColor(1, 1, 1)
            btn:SetWidth(RQL_UI.itemDetailContent:GetWidth())
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -gap)
            btn:Show()
            anchor = btn
            gap = 4
            totalHeight = totalHeight + gap + 16
        end
    else
        sec.header:SetText("Related Quests")
        sec.header:ClearAllPoints()
        sec.header:SetPoint("TOPLEFT", RQL_UI.iDesc, "BOTTOMLEFT", 0, -RQL_HEADER_GAP)
        sec.header:Show()
        sec.text:SetText("|cFF808080No quests reference this item in the bundled database.|r")
        sec.text:ClearAllPoints()
        sec.text:SetPoint("TOPLEFT", sec.header, "BOTTOMLEFT", 0, -RQL_BODY_GAP)
        sec.text:SetWidth(RQL_UI.itemDetailContent:GetWidth())
        sec.text:Show()
        totalHeight = totalHeight + RQL_HEADER_GAP + RQL_BODY_GAP + 40
    end

    RQL_UI.itemDetailContent:SetHeight(totalHeight + 24)
    if RQL_UI.itemDetailScroll and RQL_UI.itemDetailScroll.UpdateScrollChildRect then
        RQL_UI.itemDetailScroll:UpdateScrollChildRect()
        RQL_UI.itemDetailScroll:SetVerticalScroll(0)
    end

    RQL_UI.itemDetail:Show()
    RelationshipsQuestAndItemBrowserFrame:Show()
end

-- Dropdown helper
local function RQL_MakeDropdown(name, parent, x, y, width, labelText, items, getIndex, setIndex)
    local dd = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    local label = dd:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("BOTTOMLEFT", dd, "TOPLEFT", 18, 2)
    label:SetText(labelText)
    UIDropDownMenu_SetWidth(width, dd)
    local function init()
        for i, txt in ipairs(items) do
            local info = {}
            info.text = txt
            info.value = i - 1
            info.checked = nil
            info.func = function()
                setIndex(this.value)
                UIDropDownMenu_SetSelectedValue(dd, this.value)
                UIDropDownMenu_SetText(items[this.value + 1], dd)
                RQL_ShowBrowser()
            end
            UIDropDownMenu_AddButton(info)
        end
    end
    UIDropDownMenu_Initialize(dd, init)
    UIDropDownMenu_SetSelectedValue(dd, getIndex())
    UIDropDownMenu_SetText(items[getIndex() + 1], dd)
    return dd
end

local function RQL_BuildUI()
    if RQL_UI.built then return end
    RQL_UI.built = 1
    local parent = RelationshipsQuestAndItemBrowserFrame

    -- ---------- Tab bar (Quests / Items) ----------
    local tabQuests = CreateFrame("Button", "RelationshipsQuestAndItemBrowserTabQuests", parent, "UIPanelButtonTemplate")
    tabQuests:SetWidth(90) tabQuests:SetHeight(22)
    tabQuests:SetPoint("TOPLEFT", parent, "TOPLEFT", 22, -42)
    tabQuests:SetText("Quests")
    tabQuests:SetScript("OnClick", function() RQL_ShowBrowser() end)
    RQL_UI.tabQuests = tabQuests

    local tabItems = CreateFrame("Button", "RelationshipsQuestAndItemBrowserTabItems", parent, "UIPanelButtonTemplate")
    tabItems:SetWidth(90) tabItems:SetHeight(22)
    tabItems:SetPoint("LEFT", tabQuests, "RIGHT", 6, 0)
    tabItems:SetText("Items")
    tabItems:SetScript("OnClick", function() RQL_ShowItemBrowser() end)
    RQL_UI.tabItems = tabItems

    -- ---------- Parchment background (quest-log style) ----------
    -- The vanilla client ships Interface\QuestFrame\QuestBG as a 512x512
    -- parchment. We tile a 2x2 grid so it covers the whole frame interior
    -- regardless of frame size. Layered in BACKGROUND so it renders over
    -- the plain dialog backdrop but under all content.
    -- Darker parchment-brown background for better text contrast.
    local bg = parent:CreateTexture(nil, "BACKGROUND")
    -- Dark gold solid fill for the "Default" background. Chosen for good
    -- contrast against white/yellow text without relying on a texture path
    -- (some 1.12 clients fail to load Interface\QuestFrame\QuestBG and
    -- would render fully transparent).
    bg:SetTexture(0.32, 0.24, 0.10)
    bg:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -12)
    bg:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -12, 12)
    RQL_UI.bgParchment = bg


    -- controls container
    local controls = CreateFrame("Frame", nil, parent)
    controls:SetPoint("TOPLEFT", parent, "TOPLEFT", 22, -84)
    controls:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -22, -84)
    controls:SetHeight(132)
    RQL_UI.controls = controls

    local searchLabel = controls:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    searchLabel:SetPoint("TOPLEFT", controls, "TOPLEFT", 0, 0)
    searchLabel:SetText("Search:")
    local edit = CreateFrame("EditBox", "RelationshipsQuestAndItemBrowserSearchBox", controls, "InputBoxTemplate")
    edit:SetHeight(20)
    edit:SetWidth(380)
    edit:SetPoint("TOPLEFT", controls, "TOPLEFT", 60, 2)
    edit:SetAutoFocus(nil)
    edit:SetScript("OnEnterPressed", function()
        RQL_SEARCH_TEXT = this:GetText() or ""
        this:ClearFocus()
        RQL_ShowBrowser()
    end)
    edit:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    edit:SetScript("OnTextChanged", function()
        RQL_SEARCH_TEXT = this:GetText() or ""
        RQL_SearchQuests()
        RQL_UpdateStatus()
        RQL_UpdateList()
    end)
    RQL_UI.search = edit

    local btnSearch = CreateFrame("Button", nil, controls, "UIPanelButtonTemplate")
    btnSearch:SetWidth(70) btnSearch:SetHeight(22)
    btnSearch:SetPoint("LEFT", edit, "RIGHT", 8, 0)
    btnSearch:SetText("Search")
    btnSearch:SetScript("OnClick", function()
        RQL_SEARCH_TEXT = edit:GetText() or ""
        RQL_ShowBrowser()
    end)

    local btnReset = CreateFrame("Button", nil, controls, "UIPanelButtonTemplate")
    btnReset:SetWidth(70) btnReset:SetHeight(22)
    btnReset:SetPoint("LEFT", btnSearch, "RIGHT", 4, 0)
    btnReset:SetText("Reset")
    btnReset:SetScript("OnClick", function()
        RQL_SEARCH_TEXT = ""
        RQL_LEVEL_FILTER = 0; RQL_TYPE_FILTER = 0
        RQL_FACTION_FILTER = 0; RQL_SOURCE_FILTER = 0
        edit:SetText("")
        UIDropDownMenu_SetSelectedValue(RQL_UI.ddLevel, 0); UIDropDownMenu_SetText(RQL_LEVELS[1], RQL_UI.ddLevel)
        UIDropDownMenu_SetSelectedValue(RQL_UI.ddType, 0); UIDropDownMenu_SetText(RQL_TYPES[1], RQL_UI.ddType)
        UIDropDownMenu_SetSelectedValue(RQL_UI.ddFaction, 0); UIDropDownMenu_SetText(RQL_FACTIONS[1], RQL_UI.ddFaction)
        UIDropDownMenu_SetSelectedValue(RQL_UI.ddSource, 0); UIDropDownMenu_SetText(RQL_SOURCES[1], RQL_UI.ddSource)
        RQL_ShowBrowser()
    end)

    -- ---------- Options: background color ----------
    -- Colored overlay approach: leave the parchment backdrop untouched
    -- (so "Default" is truly the original look) and lay a solid-color
    -- texture over it inside the border. Hidden when Default is chosen.
    RQL_BG_PRESETS = {
        { name = "Parchment",      r = 0.00, g = 0.00, b = 0.00, a = 0.00 },

{ name = "Light Sepia", r = 0.8428, g = 0.7448, b = 0.5880, a = 1.00 },
{ name = "Sepia",          r = 0.38, g = 0.29, b = 0.20, a = 1.00 },

{ name = "Charcoal",       r = 0.25, g = 0.25, b = 0.26, a = 1.00 },
{ name = "Black",          r = 0.14, g = 0.14, b = 0.15, a = 1.00 },

{ name = "Midnight Blue",  r = 0.13, g = 0.20, b = 0.36, a = 1.00 },
{ name = "Forest Green",   r = 0.12, g = 0.28, b = 0.18, a = 1.00 },
{ name = "Deep Red",       r = 0.40, g = 0.13, b = 0.13, a = 1.00 },
{ name = "Royal Purple",   r = 0.31, g = 0.15, b = 0.42, a = 1.00 },
    }

    -- Create the overlay once, parented to the main frame, sitting just
    -- inside the DialogBox border insets (11/12/12/11) and BELOW all UI
    -- content by using the BACKGROUND layer with a low sublevel.
    if RelationshipsQuestAndItemBrowserFrame and not RQL_UI.bgOverlay then
        -- Draw on BORDER layer (above the DialogBox parchment backdrop, below
        -- ARTWORK/OVERLAY content) so the selected color fully covers the
        -- parchment. Earlier this sat on BACKGROUND at sublevel 0, where on
        -- some 1.12 / Turtle builds it rendered UNDER the parchment bgFile
        -- and blended through it, making colors look muddy / "combined".
        local ov = RelationshipsQuestAndItemBrowserFrame:CreateTexture(nil, "BORDER")
        ov:SetTexture(0, 0, 0, 0)
        ov:SetPoint("TOPLEFT", RelationshipsQuestAndItemBrowserFrame, "TOPLEFT", 11, -12)
        ov:SetPoint("BOTTOMRIGHT", RelationshipsQuestAndItemBrowserFrame, "BOTTOMRIGHT", -12, 11)
        ov:Hide()
        RQL_UI.bgOverlay = ov
    end

    function RQL_ApplyBackground(name)
        local preset = RQL_BG_PRESETS[1]
        for i = 1, table.getn(RQL_BG_PRESETS) do
            if RQL_BG_PRESETS[i].name == name then preset = RQL_BG_PRESETS[i] break end
        end
        local ov = RQL_UI.bgOverlay
        if ov then
            if preset.a and preset.a > 0 then
                ov:SetTexture(preset.r, preset.g, preset.b, preset.a)
                -- Belt-and-braces: some 1.12 clients cache the previous
                -- color when SetTexture is called with new r,g,b on an
                -- already-solid texture, producing a blended / wrong hue.
                if ov.SetVertexColor then
                    ov:SetVertexColor(preset.r, preset.g, preset.b, preset.a)
                end
                ov:Show()
            else
                ov:Hide()
            end
        end
        RelationshipsQuestAndItemBrowserDB = RelationshipsQuestAndItemBrowserDB or {}
        RelationshipsQuestAndItemBrowserDB.bgColor = preset.name
    end

    local btnOptions = CreateFrame("Button", "RelationshipsQuestAndItemBrowserOptionsBtn", controls, "UIPanelButtonTemplate")
    btnOptions:SetWidth(80) btnOptions:SetHeight(22)
    btnOptions:SetPoint("LEFT", btnReset, "RIGHT", 4, 0)
    btnOptions:SetText("Options")

    -- A tiny custom menu is more reliable than UIDropDownMenu for this client.
    -- Some 1.12/Turtle builds reuse dropdown button state in a way that makes
    -- color clicks intermittently miss or call the wrong handler.
    local optMenu = CreateFrame("Frame", "RelationshipsQuestAndItemBrowserOptionsMenu", parent)
    optMenu:SetWidth(170)
    optMenu:SetHeight(30 + (table.getn(RQL_BG_PRESETS) * 20))
    optMenu:SetPoint("TOPLEFT", btnOptions, "BOTTOMLEFT", 0, -2)
    optMenu:SetFrameStrata("DIALOG")
    optMenu:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 16,
        insets = { left = 5, right = 5, top = 5, bottom = 5 }
    })
    optMenu:EnableMouse(true)
    optMenu:Hide()
    RQL_UI.optionsMenu = optMenu

    local optTitle = optMenu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    optTitle:SetPoint("TOPLEFT", optMenu, "TOPLEFT", 12, -10)
    optTitle:SetText("Background Color")

    for i = 1, table.getn(RQL_BG_PRESETS) do
        local preset = RQL_BG_PRESETS[i]
        local row = CreateFrame("Button", nil, optMenu)
        row:SetWidth(146)
        row:SetHeight(18)
        row:SetPoint("TOPLEFT", optMenu, "TOPLEFT", 12, -10 - (i * 20))
        row.presetName = preset.name

        local swatch = row:CreateTexture(nil, "ARTWORK")
        swatch:SetWidth(12)
        swatch:SetHeight(12)
        swatch:SetPoint("LEFT", row, "LEFT", 0, 0)
        if preset.a and preset.a > 0 then
            swatch:SetTexture(preset.r, preset.g, preset.b)
        else
            swatch:SetTexture(0.32, 0.24, 0.10)
        end

        local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("LEFT", swatch, "RIGHT", 6, 0)
        text:SetText(preset.name)
        row.text = text

        row:SetScript("OnEnter", function()
            if this.text then this.text:SetTextColor(1, 1, 0.4) end
        end)
        row:SetScript("OnLeave", function()
            if this.text then this.text:SetTextColor(1, 1, 1) end
        end)
        row:SetScript("OnClick", function()
            if this.presetName then RQL_ApplyBackground(this.presetName) end
            if RQL_UI.optionsMenu then RQL_UI.optionsMenu:Hide() end
        end)
    end

    btnOptions:SetScript("OnClick", function()
        if RQL_UI.optionsMenu and RQL_UI.optionsMenu:IsShown() then
            RQL_UI.optionsMenu:Hide()
        elseif RQL_UI.optionsMenu then
            RQL_UI.optionsMenu:Show()
        end
    end)

    -- Filter dropdowns — spaced to fit inside a 720-wide frame
    RQL_UI.ddLevel   = RQL_MakeDropdown("RelationshipsQuestAndItemBrowserDDLevel",   controls, -12,  -72,  90, "Level",   RQL_LEVELS,   function() return RQL_LEVEL_FILTER end,   function(v) RQL_LEVEL_FILTER = v end)
    RQL_UI.ddType    = RQL_MakeDropdown("RelationshipsQuestAndItemBrowserDDType",    controls, 128, -72, 130, "Type",    RQL_TYPES,    function() return RQL_TYPE_FILTER end,    function(v) RQL_TYPE_FILTER = v end)
    RQL_UI.ddFaction = RQL_MakeDropdown("RelationshipsQuestAndItemBrowserDDFaction", controls, 298, -72, 120, "Faction", RQL_FACTIONS, function() return RQL_FACTION_FILTER end, function(v) RQL_FACTION_FILTER = v end)
    RQL_UI.ddSource  = RQL_MakeDropdown("RelationshipsQuestAndItemBrowserDDSource",  controls, 458, -72, 130, "Source",  RQL_SOURCES,  function() return RQL_SOURCE_FILTER end,  function(v) RQL_SOURCE_FILTER = v end)

    local status = controls:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", controls, "TOPLEFT", 0, -114)
    status:SetText("")
    RQL_UI.status = status

    -- pager (bottom)
    local pager = CreateFrame("Frame", nil, parent)
    pager:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 22, 16)
    pager:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -22, 16)
    pager:SetHeight(24)
    RQL_UI.pager = pager

    local btnPrev = CreateFrame("Button", nil, pager, "UIPanelButtonTemplate")
    btnPrev:SetWidth(110) btnPrev:SetHeight(22)
    btnPrev:SetPoint("LEFT", pager, "LEFT", 0, 0)
    btnPrev:SetText("<< Prev Page")
    btnPrev:SetScript("OnClick", function()
        RQL_SetCurrentPage(RQL_CurrentPage() - 1)
        RQL_UpdateList()
        RQL_UpdateStatus()
    end)
    RQL_UI.btnPrev = btnPrev

    local btnNext = CreateFrame("Button", nil, pager, "UIPanelButtonTemplate")
    btnNext:SetWidth(110) btnNext:SetHeight(22)
    btnNext:SetPoint("RIGHT", pager, "RIGHT", 0, 0)
    btnNext:SetText("Next Page >>")
    btnNext:SetScript("OnClick", function()
        RQL_SetCurrentPage(RQL_CurrentPage() + 1)
        RQL_UpdateList()
        RQL_UpdateStatus()
    end)
    RQL_UI.btnNext = btnNext

    local pageLabel = pager:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    pageLabel:SetPoint("CENTER", pager, "CENTER", 0, 0)
    pageLabel:SetText("Page 1 / 1")
    RQL_UI.pageLabel = pageLabel

    -- list area
    local listArea = CreateFrame("Frame", nil, parent)
    listArea:SetPoint("TOPLEFT", parent, "TOPLEFT", 22, -224)
    listArea:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -22, 48)
    RQL_UI.listArea = listArea

    RQL_UI.rows = {}
    for i = 1, RQL_ROWS_VISIBLE do
        local row = CreateFrame("Button", nil, listArea)
        row:SetHeight(RQL_ROW_HEIGHT)
        if i == 1 then
            row:SetPoint("TOPLEFT", listArea, "TOPLEFT", 0, 0)
            row:SetPoint("TOPRIGHT", listArea, "TOPRIGHT", 0, 0)
        else
            row:SetPoint("TOPLEFT", RQL_UI.rows[i-1], "BOTTOMLEFT", 0, 0)
            row:SetPoint("TOPRIGHT", RQL_UI.rows[i-1], "BOTTOMRIGHT", 0, 0)
        end
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        hl:SetBlendMode("ADD")
        hl:SetAllPoints(row)
        row:SetHighlightTexture(hl)

        local right = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        right:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        right:SetJustifyH("RIGHT")
        right:SetHeight(RQL_ROW_HEIGHT)
        right:SetWidth(240)
        right:SetNonSpaceWrap(false)
        row.right = right

        local left = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        left:SetPoint("LEFT", row, "LEFT", 4, 0)
        left:SetPoint("RIGHT", right, "LEFT", -8, 0)
        left:SetJustifyH("LEFT")
        left:SetHeight(RQL_ROW_HEIGHT)
        left:SetNonSpaceWrap(false)
        row.left = left

        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetScript("OnClick", function()
            if this.itemId then
                RQL_ShowItem(this.itemId, this.itemName)
                return
            end
            if not this.questId then return end
            RQL_ShowQuest(this.questId, this.questLevel, this.questTitle)
        end)
        RQL_UI.rows[i] = row
    end

    -- ---------- Detail view (quest-log style) ----------
    local detail = CreateFrame("Frame", nil, parent)
    detail:SetPoint("TOPLEFT", parent, "TOPLEFT", 22, -84)
    detail:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -22, 48)
    detail:Hide()
    RQL_UI.detail = detail

    local dscroll = CreateFrame("ScrollFrame", "RelationshipsQuestAndItemBrowserDetailScroll", detail, "UIPanelScrollFrameTemplate")
    dscroll:SetPoint("TOPLEFT", detail, "TOPLEFT", RQL_DETAIL_PAD, -RQL_DETAIL_PAD)
    dscroll:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -(RQL_DETAIL_PAD + 24), RQL_DETAIL_PAD)
    RQL_UI.detailScroll = dscroll
    dscroll:EnableMouseWheel(true)
    dscroll:SetScript("OnMouseWheel", function()
        local step = 24
        local cur = this:GetVerticalScroll()
        local maxs = this:GetVerticalScrollRange()
        local nv = cur - (arg1 * step)
        if nv < 0 then nv = 0 end
        if nv > maxs then nv = maxs end
        this:SetVerticalScroll(nv)
    end)

    local dcontent = CreateFrame("Frame", nil, dscroll)
    -- Inner width: frame(720) - 2*margin(22) - 2*pad(18) - scrollbar(24) ≈ 616
    dcontent:SetWidth(612) dcontent:SetHeight(1)
    dscroll:SetScrollChild(dcontent)
    RQL_UI.detailContent = dcontent

    -- Title
    local dTitle = dcontent:CreateFontString(nil, "OVERLAY", "QuestTitleFont")
    dTitle:SetPoint("TOPLEFT", dcontent, "TOPLEFT", 0, 0)
    dTitle:SetWidth(612)
    dTitle:SetJustifyH("LEFT")
    RQL_UI.dTitle = dTitle

    -- Meta line
    local dMeta = dcontent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dMeta:SetPoint("TOPLEFT", dTitle, "BOTTOMLEFT", 0, -10)
    dMeta:SetWidth(612)
    dMeta:SetJustifyH("LEFT")
    RQL_UI.dMeta = dMeta

    -- Sections
    RQL_UI.dObjSection  = RQL_MakeDetailSection(dcontent)
    RQL_UI.dDescSection = RQL_MakeDetailSection(dcontent)
    RQL_UI.dLocSection  = RQL_MakeDetailSection(dcontent)
    RQL_UI.dPreSection  = RQL_MakeDetailSection(dcontent)
    RQL_UI.dItemSection = RQL_MakeDetailSection(dcontent)

    local dFooter = dcontent:CreateFontString(nil, "OVERLAY", "QuestFont")
    dFooter:SetWidth(612)
    dFooter:SetJustifyH("LEFT")
    dFooter:Hide()
    RQL_UI.dFooter = dFooter

    local btnBack = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btnBack:SetWidth(90) btnBack:SetHeight(22)
    btnBack:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 22, 16)
    btnBack:SetText("Back")
    btnBack:SetScript("OnClick", function()
        local savedPage = RQL_PAGE
        RQL_ShowBrowser()
        RQL_PAGE = savedPage
        RQL_UpdateList()
    end)

    local btnLink = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btnLink:SetWidth(130) btnLink:SetHeight(22)
    btnLink:SetPoint("LEFT", btnBack, "RIGHT", 6, 0)
    btnLink:SetText("Link to Chat")
    btnLink:SetScript("OnClick", function()
        if RQL_SELECTED_QUEST_ID then
            RQL_LinkQuestToChat(RQL_SELECTED_QUEST_ID, nil, nil)
        end
    end)
    btnLink:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:AddLine("Insert a clickable quest link into the chat edit box.")
        GameTooltip:AddLine("Tip: shift-click a quest in the list to link it directly.", 1,1,1)
        GameTooltip:Show()
    end)
    btnLink:SetScript("OnLeave", function() GameTooltip:Hide() end)

    detail:SetScript("OnShow", function() btnBack:Show(); btnLink:Show() end)
    detail:SetScript("OnHide", function() btnBack:Hide(); btnLink:Hide() end)
    btnBack:Hide()
    btnLink:Hide()

    -- ---------- Item controls (separate search bar for items) ----------
    local iControls = CreateFrame("Frame", nil, parent)
    iControls:SetPoint("TOPLEFT", parent, "TOPLEFT", 22, -84)
    iControls:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -22, -84)
    iControls:SetHeight(132)
    iControls:Hide()
    RQL_UI.itemControls = iControls

    local iSearchLabel = iControls:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    iSearchLabel:SetPoint("TOPLEFT", iControls, "TOPLEFT", 0, 0)
    iSearchLabel:SetText("Item Search:")

    local iEdit = CreateFrame("EditBox", "RelationshipsQuestAndItemBrowserItemSearchBox", iControls, "InputBoxTemplate")
    iEdit:SetHeight(20)
    iEdit:SetWidth(380)
    iEdit:SetPoint("TOPLEFT", iControls, "TOPLEFT", 78, 2)
    iEdit:SetAutoFocus(nil)
    iEdit:SetScript("OnEnterPressed", function()
        RQL_ITEM_SEARCH_TEXT = this:GetText() or ""
        this:ClearFocus()
        RQL_ShowItemBrowser()
    end)
    iEdit:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    iEdit:SetScript("OnTextChanged", function()
        RQL_ITEM_SEARCH_TEXT = this:GetText() or ""
        RQL_SearchItems()
        RQL_UpdateStatus()
        RQL_UpdateList()
    end)
    RQL_UI.itemSearch = iEdit

    local iBtnSearch = CreateFrame("Button", nil, iControls, "UIPanelButtonTemplate")
    iBtnSearch:SetWidth(70) iBtnSearch:SetHeight(22)
    iBtnSearch:SetPoint("LEFT", iEdit, "RIGHT", 8, 0)
    iBtnSearch:SetText("Search")
    iBtnSearch:SetScript("OnClick", function()
        RQL_ITEM_SEARCH_TEXT = iEdit:GetText() or ""
        RQL_ShowItemBrowser()
    end)

    local iBtnReset = CreateFrame("Button", nil, iControls, "UIPanelButtonTemplate")
    iBtnReset:SetWidth(70) iBtnReset:SetHeight(22)
    iBtnReset:SetPoint("LEFT", iBtnSearch, "RIGHT", 4, 0)
    iBtnReset:SetText("Reset")
    iBtnReset:SetScript("OnClick", function()
        RQL_ITEM_SEARCH_TEXT = ""
        RQL_ITEM_SOURCE_FILTER = 0
        iEdit:SetText("")
        if RQL_UI.ddItemSource then
            UIDropDownMenu_SetSelectedValue(RQL_UI.ddItemSource, 0)
            UIDropDownMenu_SetText(RQL_SOURCES[1], RQL_UI.ddItemSource)
        end
        RQL_ShowItemBrowser()
    end)

    RQL_UI.ddItemSource = RQL_MakeDropdown(
        "RelationshipsQuestAndItemBrowserDDItemSource", iControls, -12, -72, 130, "Source", RQL_SOURCES,
        function() return RQL_ITEM_SOURCE_FILTER end,
        function(v) RQL_ITEM_SOURCE_FILTER = v end)

    -- The RQL_MakeDropdown reset flow calls RQL_ShowBrowser after selection.
    -- Rewrite the item-source dropdown init so it refreshes the ITEM browser.
    UIDropDownMenu_Initialize(RQL_UI.ddItemSource, function()
        for i, txt in ipairs(RQL_SOURCES) do
            local info = {}
            info.text = txt
            info.value = i - 1
            info.func = function()
                RQL_ITEM_SOURCE_FILTER = this.value
                UIDropDownMenu_SetSelectedValue(RQL_UI.ddItemSource, this.value)
                UIDropDownMenu_SetText(RQL_SOURCES[this.value + 1], RQL_UI.ddItemSource)
                RQL_ShowItemBrowser()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetSelectedValue(RQL_UI.ddItemSource, 0)
    UIDropDownMenu_SetText(RQL_SOURCES[1], RQL_UI.ddItemSource)

    local iStatus = iControls:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    iStatus:SetPoint("TOPLEFT", iControls, "TOPLEFT", 0, -114)
    iStatus:SetText("")
    RQL_UI.itemStatus = iStatus

    -- ---------- Item detail view ----------
    local iDetail = CreateFrame("Frame", nil, parent)
    iDetail:SetPoint("TOPLEFT", parent, "TOPLEFT", 22, -84)
    iDetail:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -22, 48)
    iDetail:Hide()
    RQL_UI.itemDetail = iDetail

    local iScroll = CreateFrame("ScrollFrame", "RelationshipsQuestAndItemBrowserItemDetailScroll", iDetail, "UIPanelScrollFrameTemplate")
    iScroll:SetPoint("TOPLEFT", iDetail, "TOPLEFT", RQL_DETAIL_PAD, -RQL_DETAIL_PAD)
    iScroll:SetPoint("BOTTOMRIGHT", iDetail, "BOTTOMRIGHT", -(RQL_DETAIL_PAD + 24), RQL_DETAIL_PAD)
    iScroll:EnableMouseWheel(true)
    iScroll:SetScript("OnMouseWheel", function()
        local step = 24
        local cur = this:GetVerticalScroll()
        local maxs = this:GetVerticalScrollRange()
        local nv = cur - (arg1 * step)
        if nv < 0 then nv = 0 end
        if nv > maxs then nv = maxs end
        this:SetVerticalScroll(nv)
    end)
    RQL_UI.itemDetailScroll = iScroll

    local iContent = CreateFrame("Frame", nil, iScroll)
    iContent:SetWidth(612) iContent:SetHeight(1)
    iScroll:SetScrollChild(iContent)
    RQL_UI.itemDetailContent = iContent

    -- Slot art goes behind the item icon. UI-EmptySlot-Disabled is a full
    -- empty-slot texture (not just a transparent border), so using OVERLAY
    -- made the icon area look like a blank box on Turtle/OctoWoW.
    local iIconBorder = iContent:CreateTexture(nil, "BACKGROUND")
    iIconBorder:SetTexture("Interface\\Buttons\\UI-EmptySlot-Disabled")
    iIconBorder:SetWidth(66) iIconBorder:SetHeight(66)
    iIconBorder:SetPoint("TOPLEFT", iContent, "TOPLEFT", -11, 11)
    RQL_UI.iIconBorder = iIconBorder

    -- Icon (populated from GetItemInfo in RQL_ShowItem). Sits top-left.
    local iIcon = iContent:CreateTexture(nil, "ARTWORK")
    iIcon:SetWidth(44) iIcon:SetHeight(44)
    iIcon:SetPoint("TOPLEFT", iContent, "TOPLEFT", 0, 0)
    iIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    iIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    RQL_UI.iIcon = iIcon

    local iTitle = iContent:CreateFontString(nil, "OVERLAY", "QuestTitleFont")
    iTitle:SetPoint("TOPLEFT", iIcon, "TOPRIGHT", 14, -2)
    iTitle:SetWidth(612 - 60)
    iTitle:SetJustifyH("LEFT")
    RQL_UI.iTitle = iTitle

    local iMeta = iContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    iMeta:SetPoint("TOPLEFT", iTitle, "BOTTOMLEFT", 0, -8)
    iMeta:SetWidth(612 - 60)
    iMeta:SetJustifyH("LEFT")
    RQL_UI.iMeta = iMeta

    RQL_UI.iQuestSection = RQL_MakeDetailSection(iContent)
    RQL_UI.iQuestButtons = {}

    local iBtnBack = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    iBtnBack:SetWidth(90) iBtnBack:SetHeight(22)
    iBtnBack:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 22, 16)
    iBtnBack:SetText("Back")
    iBtnBack:SetScript("OnClick", function()
        local savedPage = RQL_ITEM_PAGE
        RQL_ShowItemBrowser()
        RQL_ITEM_PAGE = savedPage
        RQL_UpdateList()
    end)

    local iBtnLink = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    iBtnLink:SetWidth(130) iBtnLink:SetHeight(22)
    iBtnLink:SetPoint("LEFT", iBtnBack, "RIGHT", 6, 0)
    iBtnLink:SetText("Link to Chat")
    iBtnLink:SetScript("OnClick", function()
        if RQL_SELECTED_ITEM_ID then RQL_LinkItemToChat(RQL_SELECTED_ITEM_ID) end
    end)

    iDetail:SetScript("OnShow", function() iBtnBack:Show(); iBtnLink:Show() end)
    iDetail:SetScript("OnHide", function() iBtnBack:Hide(); iBtnLink:Hide() end)
    iBtnBack:Hide()
    iBtnLink:Hide()
end

-- ---------- Item-detail async cache retry ----------
-- Vanilla 1.12 clients populate the item cache asynchronously the first
-- time an item is referenced. We keep probing GameTooltip for up to a few
-- seconds after opening an item panel and refresh the description as soon
-- as real tooltip lines come back.
function RQL_ItemDetailRetryTick(elapsed)
    -- Deferred chat-link insertion: poll GetItemInfo until the client has
    -- cached the real signed hyperlink, then drop it into the edit box.
    if RQL_UI.iLinkPendingFor then
        RQL_UI.iLinkPendingElapsed = (RQL_UI.iLinkPendingElapsed or 0) + (elapsed or 0)
        if RQL_UI.iLinkPendingElapsed >= 0.2 then
            RQL_UI.iLinkPendingElapsed = 0
            RQL_UI.iLinkPendingTries = (RQL_UI.iLinkPendingTries or 0) + 1
            local pid = RQL_UI.iLinkPendingFor
            if RQL_TryInsertItemLink(pid) then
                RQL_UI.iLinkPendingFor = nil
            elseif RQL_UI.iLinkPendingTries >= 25 then
                RQL_UI.iLinkPendingFor = nil
                if DEFAULT_CHAT_FRAME then
                    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF6060RQL|r Could not fetch item link from server. Try again in a moment.")
                end
            end
        end
    end

    if not RQL_UI.iRetryFor then return end
    RQL_UI.iRetryElapsed = (RQL_UI.iRetryElapsed or 0) + (elapsed or 0)
    if RQL_UI.iRetryElapsed < 0.25 then return end
    RQL_UI.iRetryElapsed = 0
    RQL_UI.iRetryTries = (RQL_UI.iRetryTries or 0) + 1
    local id = RQL_UI.iRetryFor
    local lines = RQL_ScanItemTooltipLines(id)
    if lines and table.getn(lines) > 0 then
        RQL_UI.iRetryFor = nil
        if RQL_UI.iDesc and RQL_UI.itemDetail and RQL_UI.itemDetail:IsShown()
           and RQL_SELECTED_ITEM_ID == id then
            RQL_UI.iDesc:SetText(table.concat(lines, "\n"))
            if RQL_UI.itemDetailContent and RQL_UI.itemDetailScroll
               and RQL_UI.itemDetailScroll.UpdateScrollChildRect then
                local h = 40 + 20 + RQL_HEADER_GAP + (RQL_UI.iDesc:GetHeight() or 0) + 60
                local btns = RQL_UI.iQuestButtons or {}
                for i = 1, table.getn(btns) do
                    if btns[i]:IsShown() then h = h + 20 end
                end
                RQL_UI.itemDetailContent:SetHeight(h + 24)
                RQL_UI.itemDetailScroll:UpdateScrollChildRect()
            end
        end
    elseif RQL_UI.iRetryTries >= 20 then
        RQL_UI.iRetryFor = nil
    end
end

-- ---------- Item chat linking ----------
-- Insert a genuine client-cached item link into chat. Vanilla WoW strips
-- user-typed |Hitem:...|h strings before send -- ONLY the |cXXXX|Hitem:...
-- link that GetItemInfo returns after the client has cached the item is
-- treated as a real hyperlink. We warm the cache via SetHyperlink and
-- retry for a few seconds if needed.
local function RQL_TryInsertItemLink(id)
    local name, link, quality = GetItemInfo(id)
    if not name then return nil end
    -- On some 1.12-based clients (Turtle WoW / OctoWoW) GetItemInfo can
    -- return the bare itemString ("item:12345:0:0:0") instead of the fully
    -- signed "|cXXXXXXXX|Hitem:...|h[Name]|h|r" hyperlink. If we don't
    -- detect that we would drop raw text into chat that looks like
    -- "item:0:0:0:12345" and is not clickable. Rebuild a proper hyperlink
    -- from the pieces we do have.
    if not link or not string.find(link, "|H") then
        local color = RQL_QUALITY_HEX[quality or 1] or "|cffffffff"
        link = color .. "|Hitem:" .. id .. ":0:0:0|h[" .. name .. "]|h|r"
    end
    if not ChatFrameEditBox then return 1 end
    if not ChatFrameEditBox:IsVisible() then ChatFrameEditBox:Show() end
    ChatFrameEditBox:SetFocus()
    ChatFrameEditBox:Insert(link)
    return 1
end

function RQL_LinkItemToChat(id)
    if not id then return end
    -- Force the client to cache the item so GetItemInfo returns the real
    -- signed link on the next tick.
    RQL_EnsureScanTip()
    RQL_UI.scanTip:ClearLines()
    RQL_UI.scanTip:SetHyperlink("item:" .. id .. ":0:0:0")

    if RQL_TryInsertItemLink(id) then return end

    -- Not cached yet -- schedule delayed insertion.
    RQL_UI.iLinkPendingFor = id
    RQL_UI.iLinkPendingElapsed = 0
    RQL_UI.iLinkPendingTries = 0
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99RQL|r Fetching item data from server, link will drop into chat in a moment...")
    end
end

-- ---------- minimap button ----------

local function RQL_SaveMinimapPos()
    if not RQL_UI.minimap then return end
    RelationshipsQuestAndItemBrowserDB.minimap = RelationshipsQuestAndItemBrowserDB.minimap or {}
    local x, y = RQL_UI.minimap:GetCenter()
    if x and y then
        RelationshipsQuestAndItemBrowserDB.minimap.x = x
        RelationshipsQuestAndItemBrowserDB.minimap.y = y
    end
end

local function RQL_RestoreMinimapPos()
    if not RQL_UI.minimap then return end
    local pos = RelationshipsQuestAndItemBrowserDB.minimap
    RQL_UI.minimap:ClearAllPoints()
    if pos and pos.x and pos.y then
        RQL_UI.minimap:SetPoint("CENTER", UIParent, "BOTTOMLEFT", pos.x, pos.y)
    else
        RQL_UI.minimap:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -8, -8)
    end
end

local function RQL_BuildMinimapButton()
    if RQL_UI.minimap then return end
    local btn = CreateFrame("Button", "RelationshipsQuestAndItemBrowserMinimap", UIParent)
    btn:SetFrameStrata("MEDIUM")
    btn:SetWidth(32) btn:SetHeight(32)
    btn:SetMovable(true)
    btn:EnableMouse(true)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")

    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    icon:SetWidth(20) icon:SetHeight(20)
    icon:SetPoint("CENTER", btn, "CENTER", 0, 1)

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetWidth(54) border:SetHeight(54)
    border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    hl:SetBlendMode("ADD")
    hl:SetAllPoints(btn)
    btn:SetHighlightTexture(hl)

    btn:SetScript("OnClick", function()
        if arg1 == "RightButton" then
            RelationshipsQuestAndItemBrowserDB.minimap = nil
            RQL_RestoreMinimapPos()
        else
            if RelationshipsQuestAndItemBrowserFrame:IsVisible() then
                RelationshipsQuestAndItemBrowserFrame:Hide()
            else
                RQL_ShowBrowser()
            end
        end
    end)
    btn:SetScript("OnDragStart", function() this:StartMoving() end)
    btn:SetScript("OnDragStop", function() this:StopMovingOrSizing(); RQL_SaveMinimapPos() end)
    btn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:AddLine("Relationships Quest And Item Browser")
        GameTooltip:AddLine("Left-click: open browser", 1,1,1)
        GameTooltip:AddLine("Right-click: reset icon to minimap", 1,1,1)
        GameTooltip:AddLine("Drag: move anywhere", 1,1,1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    RQL_UI.minimap = btn
    RQL_RestoreMinimapPos()
end

-- ---------- chat link plus-button overlay ----------
--
-- Behaviour:
--   * A tiny green [+] Button is overlaid directly on top of every quest /
--     item hyperlink that is currently visible in a chat frame.
--   * The [+] tracks the link as chat scrolls: it appears when the message
--     is on screen and hides when it scrolls off. Switching chat tabs also
--     hides / shows it, since inactive tabs' frames are hidden.
--   * Clicking the [+] opens the quest / item in the RQL browser.
--   * The original chat link is untouched, so default Blizzard tooltip,
--     quest popup and shift-insert still work.
--
-- Why an overlay button instead of an inline "|Hrqlopen:..." link:
--   Some Turtle / OctoWoW builds don't dispatch clicks for unknown link
--   types AND refuse to let addons attach an OnHyperlinkShow script to
--   chat frames. A real Button widget floated over the FontString is the
--   only mechanism that reliably works on those clients.

local RQL_PLUS_BTN_SIZE = 12
local RQL_PLUS_POOL     = {}
local RQL_PoolIndex     = 0
local RQL_PLUS_MEASURE  -- hidden FontString reused to measure prefix widths

local function RQL_GetMeasurer(refFontString)
    if not RQL_PLUS_MEASURE then
        RQL_PLUS_MEASURE = UIParent:CreateFontString(nil, "BACKGROUND")
        RQL_PLUS_MEASURE:Hide()
    end
    local obj = refFontString and refFontString.GetFontObject and refFontString:GetFontObject()
    if obj then
        RQL_PLUS_MEASURE:SetFontObject(obj)
    else
        -- Fall back to font path / size directly.
        local path, size, flags
        if refFontString and refFontString.GetFont then path, size, flags = refFontString:GetFont() end
        if path and size then RQL_PLUS_MEASURE:SetFont(path, size, flags) end
    end
    return RQL_PLUS_MEASURE
end

local function RQL_StripCodes(s)
    if type(s) ~= "string" then return "" end
    s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
    s = string.gsub(s, "|r", "")
    s = string.gsub(s, "|T[^|]*|t", "")
    -- Strip hyperlink openers/closers but keep the display text between them,
    -- since that text renders and consumes width in the source FontString.
    s = string.gsub(s, "|H[^|]*|h", "")
    s = string.gsub(s, "|h", "")
    return s
end

local function RQL_PlusOnClick()
    local e = this and this.rqlEntry
    if not e then return end
    if e.kind == "quest" then
        RQL_ShowQuest(e.id, e.level or 0, e.name)
    elseif e.kind == "item" then
        RQL_ShowItem(e.id, e.name)
    end
end

local function RQL_PlusOnEnter()
    if not (this and this.rqlEntry) then return end
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    if this.rqlEntry.kind == "quest" then
        GameTooltip:AddLine("Open quest in RQL browser")
    else
        GameTooltip:AddLine("Open item in RQL browser")
    end
    if this.rqlEntry.name then
        GameTooltip:AddLine(this.rqlEntry.name, 1, 1, 1)
    end
    GameTooltip:Show()
end

local function RQL_PlusOnLeave() GameTooltip:Hide() end

local function RQL_AcquirePlusButton()
    RQL_PoolIndex = RQL_PoolIndex + 1
    local btn = RQL_PLUS_POOL[RQL_PoolIndex]
    if not btn then
        btn = CreateFrame("Button", "RQL_PlusButton" .. RQL_PoolIndex, UIParent)
        btn:SetFrameStrata("HIGH")
        btn:SetWidth(RQL_PLUS_BTN_SIZE)
        btn:SetHeight(RQL_PLUS_BTN_SIZE)
        local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetAllPoints(btn)
        fs:SetText("|cff33ff99+|r")
        btn:SetFontString(fs)
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(btn)
        bg:SetTexture(0, 0, 0, 0.6)
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(btn)
        hl:SetTexture(1, 1, 1, 0.30)
        btn:SetHighlightTexture(hl)
        btn:SetScript("OnClick", RQL_PlusOnClick)
        btn:SetScript("OnEnter", RQL_PlusOnEnter)
        btn:SetScript("OnLeave", RQL_PlusOnLeave)
        RQL_PLUS_POOL[RQL_PoolIndex] = btn
    end
    return btn
end

local function RQL_HideUnusedButtons()
    local i = RQL_PoolIndex + 1
    while RQL_PLUS_POOL[i] do
        RQL_PLUS_POOL[i]:Hide()
        RQL_PLUS_POOL[i].rqlEntry = nil
        i = i + 1
    end
end

-- Word-wrap `plain` using the same width the FontString wraps at, and
-- return (lineCount, lastLineWidth, lineHeight). Used so the [+] follows a
-- message onto its wrapped continuation line instead of flying off the right
-- edge of the chat frame at the end of the (never-rendered) full-width line.
local function RQL_WrapMetrics(fs, plain)
    local measurer = RQL_GetMeasurer(fs)
    local _, fontSize = fs:GetFont()
    fontSize = fontSize or 12
    local spacing = 0
    if fs.GetSpacing then spacing = fs:GetSpacing() or 0 end
    local lineHeight = fontSize + spacing

    local maxW = 0
    if fs.GetWidth then maxW = fs:GetWidth() or 0 end
    if maxW <= 0 then
        local L, R = fs:GetLeft(), fs:GetRight()
        if L and R then maxW = R - L end
    end

    measurer:SetText(plain or "")
    local totalW = measurer:GetStringWidth() or 0
    if maxW <= 0 or totalW <= maxW then
        return 1, totalW, lineHeight
    end

    local lines = 1
    local lineText = ""
    local lineW = totalW
    local i = 1
    local len = string.len(plain)
    while i <= len do
        local sp = string.find(plain, " ", i, true)
        local word
        if sp then
            word = string.sub(plain, i, sp)
            i = sp + 1
        else
            word = string.sub(plain, i)
            i = len + 1
        end
        local candidate = lineText .. word
        measurer:SetText(candidate)
        local cw = measurer:GetStringWidth() or 0
        if cw > maxW and lineText ~= "" then
            lines = lines + 1
            lineText = word
            measurer:SetText(lineText)
            lineW = measurer:GetStringWidth() or 0
        else
            lineText = candidate
            lineW = cw
        end
    end
    return lines, lineW, lineHeight
end

-- Place a [+] button at the end of the message's LAST rendered line (which
-- may be a wrapped continuation, not the source string's true end). Multiple
-- [+] icons for a message stagger horizontally past that anchor, and wrap
-- down to a further line if they would otherwise exit the chat frame's
-- right edge, so nothing gets clipped or pushed off the frame.
local function RQL_PlaceButton(fs, anchorText, entry, frame, stagger)
    if not fs or not fs.GetLeft then return end
    local left = fs:GetLeft()
    local top  = fs:GetTop()
    if not left or not top then return end

    local frameLeft  = frame and frame:GetLeft()
    local frameRight = frame and frame:GetRight()

    local plain = RQL_StripCodes(anchorText)
    local lines, lastW, lineH = RQL_WrapMetrics(fs, plain)

    local gap = 2
    local step = RQL_PLUS_BTN_SIZE + 2
    local baseX = left + lastW + gap
    local baseY = top - 1 - (lines - 1) * lineH

    local x = baseX + (stagger or 0) * step
    local y = baseY

    -- If the staggered [+] would run past the chat frame's right edge,
    -- wrap it to a new line beneath the message rather than clipping it.
    if frameRight and (x + RQL_PLUS_BTN_SIZE) > frameRight then
        local firstRowSlots = math.floor((frameRight - baseX) / step)
        if firstRowSlots < 0 then firstRowSlots = 0 end
        local wrapLeft = frameLeft or left
        local wrapRowSlots = math.floor((frameRight - wrapLeft) / step)
        if wrapRowSlots < 1 then wrapRowSlots = 1 end
        local s = stagger or 0
        if s < firstRowSlots then
            x = baseX + s * step
            y = baseY
        else
            local over = s - firstRowSlots
            local row = 1 + math.floor(over / wrapRowSlots)
            local col = over - (row - 1) * wrapRowSlots
            x = wrapLeft + col * step
            y = baseY - row * step
        end
    end

    if frameLeft and x < frameLeft then x = frameLeft end

    local btn = RQL_AcquirePlusButton()
    btn:ClearAllPoints()
    -- Position from UIParent BOTTOMLEFT using the FontString's absolute top.
    btn:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    btn.rqlEntry = entry
    btn:Show()
end

local function RQL_ProcessChatFrame(frame)
    if not frame or not frame.IsVisible or not frame:IsVisible() then return end
    if not frame.GetRegions then return end
    local regions = { frame:GetRegions() }
    local n = table.getn(regions)
    for i = 1, n do
        local r = regions[i]
        if r and r.GetObjectType and r:GetObjectType() == "FontString"
           and r.IsVisible and r:IsVisible() then
            local t = r:GetText()
            if t and string.find(t, "|H", 1, 1) then
                -- Collect every quest/item link with its span in `t`, then
                -- place one [+] per link. Position rule:
                --   * link is followed by more text in the same line -> put
                --     the [+] after the FULL message text (last character)
                --   * link is at the very end of the message         -> put
                --     the [+] immediately after the link's display text
                local matches = {}
                local pos = 1
                while 1 do
                    local s, e, id, lvl, name = string.find(t,
                        "|Hquest:(%d+):(%-?%d+)|h%[([^%]]*)%]|h", pos)
                    if not s then break end
                    table.insert(matches, {
                        s = s, e = e,
                        entry = { kind = "quest", id = tonumber(id),
                                  level = tonumber(lvl), name = name },
                    })
                    pos = e + 1
                end
                pos = 1
                while 1 do
                    local s, e, id, name = string.find(t,
                        "|Hitem:(%d+)[^|]*|h%[([^%]]*)%]|h", pos)
                    if not s then break end
                    table.insert(matches, {
                        s = s, e = e,
                        entry = { kind = "item", id = tonumber(id), name = name },
                    })
                    pos = e + 1
                end
                table.sort(matches, function(a, b) return a.s < b.s end)

                -- Place all [+] buttons grouped together at the end of the
                -- message (after the last character / link) so multiple linked
                -- quests / items get a run of plus icons like "+++" rather
                -- than being spread throughout the line. `stagger` shifts each
                -- subsequent button one icon-width to the right.
                for j = 1, table.getn(matches) do
                    RQL_PlaceButton(r, t, matches[j].entry, frame, j - 1)
                end
            end
        end
    end
end

-- Event-driven [+] scanning.
--
-- The old implementation ran a full chat-frame scan ~33 times per second
-- (every 0.03s) regardless of whether chat had changed. On busy zones /
-- raids that constant `frame:GetRegions()` + regex work was a real source
-- of random lag spikes (GC pressure from throwaway region tables).
--
-- Now we scan only when:
--   * a CHAT_MSG_* event arrives (with a tiny delay so the chat frame has
--     laid out the new region before we measure it), or
--   * the user scrolls / resizes a chat frame (hooked below), or
--   * the addon just finished loading (initial pass over existing chat).
--
-- Scans are rate-limited to at most one every RQL_SCAN_MIN_INTERVAL.
-- Near-instant update: [+] icons must track new chat lines the same frame
-- they render. A 0.25s throttle was visibly slow when messages scrolled up
-- and the old [+] drifted with them. We now scan on the very next frame.
-- Tiny throttle: enough to coalesce bursts of chat events (raids, spammy
-- channels) into a single rescan per frame-ish window, but small enough
-- that the [+] still tracks new lines effectively instantly to the eye.
local RQL_SCAN_MIN_INTERVAL = 0.03
local RQL_SCAN_DELAY        = 0.01
local RQL_SCAN_PENDING_AT   = nil
local RQL_SCAN_LAST_AT      = 0

function RQL_SchedulePlusScan(delay)
    local now = GetTime()
    local at  = now + (delay or RQL_SCAN_DELAY)
    local earliest = RQL_SCAN_LAST_AT + RQL_SCAN_MIN_INTERVAL
    if at < earliest then at = earliest end
    if not RQL_SCAN_PENDING_AT or at < RQL_SCAN_PENDING_AT then
        RQL_SCAN_PENDING_AT = at
    end
end

-- Called every frame from the main OnUpdate. Cheap when idle: two compares
-- and an early return. Only does real work when a scan is due.
function RQL_PlusTick(elapsed)
    if not RQL_SCAN_PENDING_AT then return end
    if GetTime() < RQL_SCAN_PENDING_AT then return end
    RQL_SCAN_PENDING_AT = nil
    RQL_SCAN_LAST_AT    = GetTime()

    RQL_PoolIndex = 0
    local maxFrames = NUM_CHAT_WINDOWS or 7
    for i = 1, maxFrames do
        local f = getglobal("ChatFrame" .. i)
        -- IsVisible() is false for docked tabs that aren't the front tab
        -- and for hidden / minimized chat windows, so we naturally skip
        -- all of those.
        if f and f.IsVisible and f:IsVisible() then
            RQL_ProcessChatFrame(f)
        end
    end
    RQL_HideUnusedButtons()
end

-- Watcher frame that listens for chat traffic and requests a rescan.
local RQL_ChatWatch = CreateFrame("Frame", "RQL_ChatWatch")
local RQL_CHAT_EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE",
    "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_PARTY", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
    "CHAT_MSG_CHANNEL",
    "CHAT_MSG_SYSTEM", "CHAT_MSG_LOOT", "CHAT_MSG_TRADESKILLS",
    "CHAT_MSG_BATTLEGROUND", "CHAT_MSG_BATTLEGROUND_LEADER",
}
for i = 1, table.getn(RQL_CHAT_EVENTS) do
    RQL_ChatWatch:RegisterEvent(RQL_CHAT_EVENTS[i])
end
RQL_ChatWatch:SetScript("OnEvent", function()
    RQL_SchedulePlusScan()
end)

-- Immediately hide every [+] button in the pool. Used on tab-switch so a
-- stale icon from the previous tab disappears the instant the user clicks
-- a new tab, without waiting for the next scan tick.
local function RQL_HideAllPlusButtons()
    local i = 1
    while RQL_PLUS_POOL[i] do
        RQL_PLUS_POOL[i]:Hide()
        RQL_PLUS_POOL[i].rqlEntry = nil
        i = i + 1
    end
    RQL_PoolIndex = 0
end

local function RQL_HookChatLinks()
    -- Chat scrolling / paging moves existing linked lines but doesn't fire
    -- an event. Wrap the standard scroll helpers so [+] follows the text.
    local names = { "ScrollUp", "ScrollDown", "ScrollToTop",
                    "ScrollToBottom", "PageUp", "PageDown" }
    local maxFrames = NUM_CHAT_WINDOWS or 7
    for i = 1, maxFrames do
        local f = getglobal("ChatFrame" .. i)
        if f then
            for j = 1, table.getn(names) do
                local n = names[j]
                local flag = "_rql_hooked_" .. n
                if f[n] and not f[flag] then
                    local orig = f[n]
                    f[flag] = orig
                    f[n] = function()
                        orig(f)
                        RQL_SchedulePlusScan()
                    end
                end
            end
        end
    end

    -- Hook chat tab clicks so switching tabs instantly clears any stale [+]
    -- from the previously-visible tab and re-scans the newly-visible one.
    -- Also hook OnShow/OnHide on the frames themselves as a safety net for
    -- undock/dock and other visibility changes.
    for i = 1, maxFrames do
        local tab = getglobal("ChatFrame" .. i .. "Tab")
        if tab and not tab._rql_hooked_click then
            local origClick = tab:GetScript("OnClick")
            tab._rql_hooked_click = true
            tab:SetScript("OnClick", function()
                if origClick then origClick() end
                RQL_HideAllPlusButtons()
                RQL_SchedulePlusScan(0)
            end)
        end
        local f = getglobal("ChatFrame" .. i)
        if f and not f._rql_hooked_vis then
            f._rql_hooked_vis = true
            local origShow = f:GetScript("OnShow")
            f:SetScript("OnShow", function()
                if origShow then origShow() end
                RQL_HideAllPlusButtons()
                RQL_SchedulePlusScan(0)
            end)
            local origHide = f:GetScript("OnHide")
            f:SetScript("OnHide", function()
                if origHide then origHide() end
                RQL_HideAllPlusButtons()
                RQL_SchedulePlusScan(0)
            end)
        end
    end

    -- Do one pass shortly after login so already-visible chat gets [+].
    RQL_SchedulePlusScan(0.3)
end
-- ---------- events / slash ----------

RelationshipsQuestAndItemBrowser:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "RelationshipsQuestAndItemBrowser" then
        RelationshipsQuestAndItemBrowserDB = RelationshipsQuestAndItemBrowserDB or {}
    elseif event == "PLAYER_LOGOUT" then
        if RQL_UI and RQL_UI.minimap then
            RelationshipsQuestAndItemBrowserDB = RelationshipsQuestAndItemBrowserDB or {}
            RelationshipsQuestAndItemBrowserDB.minimap = RelationshipsQuestAndItemBrowserDB.minimap or {}
            local cx, cy = RQL_UI.minimap:GetCenter()
            if cx and cy then
                RelationshipsQuestAndItemBrowserDB.minimap.x = cx
                RelationshipsQuestAndItemBrowserDB.minimap.y = cy
            end
        end
    elseif event == "PLAYER_LOGIN" then
        RQL_HookChatLinks()
        RQL_BuildUI()
        RQL_BuildMinimapButton()
        -- Item-detail async tooltip retry ticker.
        RelationshipsQuestAndItemBrowser:SetScript("OnUpdate", function()
            RQL_ItemDetailRetryTick(arg1)
            if RQL_PlusTick then RQL_PlusTick(arg1) end
        end)
        if RQL_ApplyBackground then
            RQL_ApplyBackground(RQL_GetStartupBackground())
        end
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99Relationships Quest And Item Browser|r loaded. Click quest links, /rql, or use the minimap book icon.")
        end
    end
end)

local function RQL_SetFilterFromWord(kind, value)
    value = string.lower(value or "")
    if kind == "level" then
        RQL_LEVEL_FILTER = 0
        if value == "1-9" or value == "1" then RQL_LEVEL_FILTER = 1
        elseif value == "10-19" or value == "10" then RQL_LEVEL_FILTER = 2
        elseif value == "20-29" or value == "20" then RQL_LEVEL_FILTER = 3
        elseif value == "30-39" or value == "30" then RQL_LEVEL_FILTER = 4
        elseif value == "40-49" or value == "40" then RQL_LEVEL_FILTER = 5
        elseif value == "50-59" or value == "50" then RQL_LEVEL_FILTER = 6
        elseif value == "60" or value == "60+" then RQL_LEVEL_FILTER = 7 end
    elseif kind == "type" then
        RQL_TYPE_FILTER = 0
        if value == "normal" then RQL_TYPE_FILTER = 1
        elseif value == "elite" or value == "group" then RQL_TYPE_FILTER = 2
        elseif value == "dungeon" or value == "raid" then RQL_TYPE_FILTER = 3
        elseif value == "pvp" then RQL_TYPE_FILTER = 4
        elseif value == "class" then RQL_TYPE_FILTER = 5
        elseif value == "profession" or value == "skill" then RQL_TYPE_FILTER = 6
        elseif value == "event" or value == "seasonal" then RQL_TYPE_FILTER = 7 end
    elseif kind == "faction" then
        RQL_FACTION_FILTER = 0
        if value == "alliance" or value == "a" then RQL_FACTION_FILTER = 1
        elseif value == "horde" or value == "h" then RQL_FACTION_FILTER = 2
        elseif value == "neutral" or value == "n" or value == "both" then RQL_FACTION_FILTER = 3 end
    elseif kind == "source" then
        RQL_SOURCE_FILTER = 0
        if value == "vanilla" then RQL_SOURCE_FILTER = 1
        elseif value == "turtle" or value == "octo" or value == "octowow" then RQL_SOURCE_FILTER = 2 end
    end
end

SLASH_RELATIONSHIPSQUESTANDITEMBROWSER1 = "/rql"
SLASH_RELATIONSHIPSQUESTANDITEMBROWSER2 = "/questbrowser"
SLASH_RELATIONSHIPSQUESTANDITEMBROWSER3 = "/rqib"
SLASH_RELATIONSHIPSQUESTANDITEMBROWSER4 = "/questitembrowser"
SlashCmdList["RELATIONSHIPSQUESTANDITEMBROWSER"] = function(msg)
    msg = msg or ""
    local _, _, cmd, rest = string.find(msg, "^%s*(%S+)%s*(.-)%s*$")
    cmd = cmd and string.lower(cmd) or ""
    if cmd == "" then
        RQL_ShowBrowser()
    elseif cmd == "close" or cmd == "hide" then
        RelationshipsQuestAndItemBrowserFrame:Hide()
    elseif cmd == "search" then
        RQL_SEARCH_TEXT = rest or ""
        if RQL_UI.search then RQL_UI.search:SetText(RQL_SEARCH_TEXT) end
        RQL_ShowBrowser()
    elseif cmd == "level" or cmd == "type" or cmd == "faction" or cmd == "source" then
        RQL_SetFilterFromWord(cmd, rest)
        RQL_ShowBrowser()
    elseif cmd == "reset" then
        RQL_SEARCH_TEXT = ""
        RQL_LEVEL_FILTER = 0; RQL_TYPE_FILTER = 0
        RQL_FACTION_FILTER = 0; RQL_SOURCE_FILTER = 0
        if RQL_UI.search then RQL_UI.search:SetText("") end
        RQL_ShowBrowser()
    elseif cmd == "quest" and rest then
        local id = tonumber(rest)
        if id then RQL_ShowQuest(id, 0, nil) end
    elseif cmd == "items" then
        RQL_ITEM_SEARCH_TEXT = rest or ""
        if RQL_UI.itemSearch then RQL_UI.itemSearch:SetText(RQL_ITEM_SEARCH_TEXT) end
        RQL_ShowItemBrowser()
    elseif cmd == "item" and rest then
        local id = tonumber(rest)
        if id then RQL_ShowItem(id, nil) end
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99RQL|r usage:")
        DEFAULT_CHAT_FRAME:AddMessage("  /rql                     open browser")
        DEFAULT_CHAT_FRAME:AddMessage("  /rql search <text>       search")
        DEFAULT_CHAT_FRAME:AddMessage("  /rql level 20-29         filter level")
        DEFAULT_CHAT_FRAME:AddMessage("  /rql type dungeon        filter type")
        DEFAULT_CHAT_FRAME:AddMessage("  /rql faction alliance    filter faction")
        DEFAULT_CHAT_FRAME:AddMessage("  /rql source turtle       filter source")
        DEFAULT_CHAT_FRAME:AddMessage("  /rql quest <id>          show a specific quest")
        DEFAULT_CHAT_FRAME:AddMessage("  /rql items <text>        open item browser and search")
        DEFAULT_CHAT_FRAME:AddMessage("  /rql item <id>           show a specific item")
        DEFAULT_CHAT_FRAME:AddMessage("  /rql reset               reset filters")
    end
end
