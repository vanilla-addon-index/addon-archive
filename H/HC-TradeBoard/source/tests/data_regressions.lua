-- Run from the workspace root. Covers 1.12 item tuples, filters and manual WHO.
table.getn = table.getn or function(value) return #value end
string.gfind = string.gfind or string.gmatch
math.mod = math.mod or math.fmod

local now = 1000
local wallNow = 2000000000
local signature = "vanilla"
local cached = true
local sentWho = {}
local mailLink = "|cff1eff00|Hitem:2979:0:0:0|h[Veteran Boots]|h|r"
local ringLink = "|cff1eff00|Hitem:11968:0:0:0|h[Amber Ring]|h|r"
function UnitName() return "Tester" end
function UnitLevel() return 25 end
function UnitFactionGroup() return "Alliance" end
function GetGuildInfo() return "Test Guild" end
function GetTime() return now end
function time() return wallNow end
function SendWho(query) table.insert(sentWho, query) end
function SetWhoToUI() end
function GetItemInfo(query)
    if not cached then return nil end
    -- Stock clients/cache helpers may require the numeric item ID.
    if type(query) ~= "number" then return nil end
    local name, subtype, equip, level = "Mail Boots", "Mail", "INVTYPE_FEET", 18
    if query == 11968 then name = "Amber Ring"; subtype = "Miscellaneous"; equip = "INVTYPE_FINGER"; level = 16 end
    if signature == "vanilla" then
        return name, "item:" .. query .. ":0:0:0", 2, level, "Armor", subtype, 1, equip, "Interface\\Icons\\INV_Boots_01"
    end
    return name, "item:" .. query .. ":0:0:0", 2, 23, level, "Armor", subtype, 1, equip, "Interface\\Icons\\INV_Boots_01"
end

dofile("HC-Tradeboard/Core.lua")
dofile("HC-Tradeboard/Network.lua")
local TB = TradeBoard
local failures = {}
local function test(name, callback)
    local ok, problem = pcall(callback)
    if ok then print("PASS: " .. name)
    else table.insert(failures, name .. ": " .. tostring(problem)); print("FAIL: " .. failures[table.getn(failures)]) end
end
local function reset()
    TB.Listings = {}; TB.ListingIndex = {}; TB.Services = {}; TB.ServiceIndex = {}
    TB.WorldLog = nil; TB.worldLogInitialized = nil; TradeBoardDB = nil
    TB.ItemMetadataCache = nil; TB.ItemMetadataCacheCount = nil
    TB:InitializeWorldLog(); TB:ResetFilters()
    now = 1000; cached = true; signature = "vanilla"
end

test("Vanilla mail items are visible under Armor > Mail on first filter", function()
    reset()
    TB:CaptureWorldMessage("wts " .. mailLink, "Seller", "World")
    TB.State.category = "Armor"; TB.State.subCategory = "Mail"
    local rows = TB:GetFilteredListings()
    assert(table.getn(rows) == 1, "mail item incorrectly excluded")
    assert(rows[1].requiredLevel == 18 and rows[1].itemLevel == 0, "vanilla required level read as item level")
    assert(rows[1].texture == "Interface\\Icons\\INV_Boots_01", "vanilla icon shifted to wrong return field")
    assert(rows[1].itemLink == mailLink, "display hyperlink replaced with raw item string")
end)

test("Modern item tuples also resolve correct category and levels", function()
    reset(); signature = "modern"
    TB:CaptureWorldMessage("WTS " .. mailLink, "Seller", "Trade")
    TB.State.category = "Armor"; TB.State.subCategory = "Mail"
    local rows = TB:GetFilteredListings()
    assert(table.getn(rows) == 1 and rows[1].requiredLevel == 18 and rows[1].itemLevel == 23, "modern item tuple incorrectly normalized")
end)

test("Uncached items recover before filtering and migrate old wrong categories", function()
    reset(); cached = false
    TB:CaptureWorldMessage("WTS " .. mailLink, "Seller", "World")
    local listing = TB.Listings[1]
    TB.State.category = "Armor"; TB.State.subCategory = "Mail"
    assert(table.getn(TB:GetFilteredListings()) == 0, "uncached item was assigned a guessed category")
    cached = true; now = now + 3
    assert(table.getn(TB:GetFilteredListings()) == 1, "cached item never reached rendering because filtering happened first")
    listing.category = "Miscellaneous"; listing.tags = {}; listing.itemLevel = 18
    assert(table.getn(TB:GetFilteredListings()) == 1, "old incorrect category did not migrate")
    assert(listing.itemLevel == 0, "old incorrect 1.12 item level was retained")
end)

test("WHO enrichment cannot hide a ring when Level is All", function()
    reset()
    TB:CaptureWorldMessage("WTS " .. ringLink, "RingSeller", "World")
    local ring = TB.Listings[1]
    assert(table.getn(TB:GetFilteredListings()) == 1, "ring missing before WHO")
    function GetNumWhoResults() return 1 end
    function GetWhoInfo() return "RingSeller", "Guild", 60, "Human", "Mage" end
    TB.PendingManualWhoName = "ringseller"
    TB:NetworkOnEvent("WHO_LIST_UPDATE")
    assert(table.getn(TB.Listings) == 1 and TB.Listings[1] == ring, "WHO removed/replaced original offer")
    assert(table.getn(TB:GetFilteredListings()) == 1, "WHO hid ring after seller level became known")
    assert(ring.traderLevel == 60 and TB.WorldLog[1].level == 60, "Browse and World did not share WHO identity")
    TB.State.minLevel = 50; TB.State.maxLevel = 60
    assert(table.getn(TB:GetFilteredListings()) == 1, "All level mode applied stale min/max values")
    TB.State.myLevelRange = 1
    assert(table.getn(TB:GetFilteredListings()) == 0, "explicit seller range should still work")
end)

test("Default filters do not silently enable seller-level range", function()
    dofile("HC-Tradeboard/Core.lua")
    local state = TradeBoard.State
    assert(not state.myLevelRange and state.levelType == "all", "startup enables a hidden seller-level filter")
    TradeBoard = TB
end)

test("Required/item levels, category, rarity, type, and online filters", function()
    reset(); signature = "modern"
    TB:CaptureWorldMessage("WTS " .. mailLink, "Seller", "World")
    TB.State.levelType = "required"; TB.State.minLevel = 20
    assert(table.getn(TB:GetFilteredListings()) == 0, "required-level minimum ignored")
    TB.State.levelType = "item"
    assert(table.getn(TB:GetFilteredListings()) == 1, "item-level filter used required level")
    TB.State.maxLevel = 22
    assert(table.getn(TB:GetFilteredListings()) == 0, "item-level maximum ignored")
    TB:ResetFilters(); TB.State.category = "Weapons"
    assert(table.getn(TB:GetFilteredListings()) == 0, "armor included in weapons")
    TB:ResetFilters(); TB.State.rarities[2] = nil
    assert(table.getn(TB:GetFilteredListings()) == 0, "rarity filter ignored")
    TB:ResetFilters(); TB.State.listingType = "BUY"
    assert(table.getn(TB:GetFilteredListings()) == 0, "sale item included in wanted")
    TB:ResetFilters(); TB.Listings[1].online = nil; TB.State.onlineOnly = 1
    assert(table.getn(TB:GetFilteredListings()) == 0, "online filter ignored")
end)

test("Every AH category and armor/weapon subtype is classified", function()
    reset()
    local originalGetItemInfo = GetItemInfo
    local examples = {
        { "Armor", "Cloth", "Armor", "Cloth" }, { "Armor", "Leather", "Armor", "Leather" },
        { "Armor", "Mail", "Armor", "Mail" }, { "Armor", "Plate", "Armor", "Plate" },
        { "Armor", "Shields", "Armor", "Shields" }, { "Armor", "Miscellaneous", "Armor" },
        { "Weapon", "One-Handed Swords", "Weapons", "Swords" },
        { "Weapon", "Two-Handed Axes", "Weapons", "2H" },
        { "Weapon", "One-Handed Maces", "Weapons", "1H" },
        { "Weapon", "Daggers", "Weapons", "Daggers" }, { "Weapon", "Staves", "Weapons", "Staves" },
        { "Weapon", "Fist Weapons", "Weapons", "Fists" }, { "Weapon", "Crossbows", "Weapons", "Ranged" },
        { "Container", "Bag", "Containers" }, { "Consumable", "Consumable", "Consumables" },
        { "Trade Goods", "Cloth", "Trade Goods" }, { "Recipe", "Tailoring", "Recipes" },
        { "Projectile", "Arrow", "Projectiles" }, { "Quiver", "Quiver", "Quivers" },
        { "Miscellaneous", "Junk", "Miscellaneous" },
    }
    local i
    for i = 1, table.getn(examples) do
        local item = examples[i]
        TB.ItemMetadataCache = nil
        GetItemInfo = function(query) return "Example", query, 2, 18, item[1], item[2], 1, "", "icon" end
        local listing = { itemLink = mailLink, quantity = 1, orderType = "SELL", online = 1, traderLevel = 25 }
        TB:RefreshListingMetadata(listing)
        TB.State.category = item[3]; TB.State.subCategory = item[4]
        assert(TB:IsListingVisible(listing), "failed " .. item[3] .. " / " .. (item[4] or item[2]))
    end
    GetItemInfo = originalGetItemInfo
end)

test("WHO cooldown is shared across sellers and survives replies", function()
    reset(); TB.manualWhoReadyAt = nil; sentWho = {}
    assert(TB:RequestManualWho("First"), "first WHO refused")
    assert(TB:GetWhoCooldownRemaining() == 30, "cooldown did not start at 30")
    now = now + 0.1
    assert(TB:GetWhoCooldownRemaining() == 30, "countdown rounded down early")
    assert(not TB:RequestManualWho("Second") and table.getn(sentWho) == 1, "second seller bypassed cooldown")
    TB:NetworkOnEvent("WHO_LIST_UPDATE")
    assert(TB:GetWhoCooldownRemaining() == 30, "WHO reply cleared server cooldown")
    now = now + 29.9
    assert(TB:GetWhoCooldownRemaining() == 0 and TB:RequestManualWho("Second"), "WHO did not unlock after 30 seconds")
    assert(table.getn(sentWho) == 2, "unlocked WHO not sent")
end)

test("Missing/older peer identities cannot erase verified WHO information", function()
    reset()
    TB:CaptureWorldMessage("WTS " .. ringLink, "Seller", "World")
    TB:RememberWorldPerson("Seller", "Guild", 60, "Mage", wallNow)
    TB:RememberWorldPerson("Seller", "", 0, "", wallNow - 60)
    assert(TB.Listings[1].traderLevel == 60 and TB.WorldLog[1].level == 60, "older peer snapshot erased seller level")
    assert(TradeBoardDB.worldPeople.seller.class == "Mage", "older peer snapshot erased class")
end)

test("Unknown identity rows do not hide known level on another shared row", function()
    reset()
    TradeBoardDB.worldPeople.seller = { level = 0, guild = "Known Guild" }
    TB.Network = { peers = { seller = { level = 0 } } }
    TB.Listings = { { trader = "Seller", traderLevel = 0 }, { trader = "Seller", traderLevel = 42 } }
    local level, guild = TB:GetKnownTraderInfo("seller")
    assert(level == 42 and guild == "Known Guild", "empty person/peer/first listing blocked later known identity")
    TB.Listings = {}; TB.Services = { { trader = "Seller", level = 0 }, { trader = "Seller", level = 43 } }
    assert(TB:GetKnownTraderInfo("Seller") == 43, "first unknown service blocked later known service")
    TB.Services = {}; TB.WorldLog = { { sender = "Seller", level = 44 } }
    assert(TB:GetKnownTraderInfo("Seller") == 44, "known World identity unavailable to Browse")
    TB.Network = nil
end)

test("Raw metadata cache never replaces a later full item hyperlink", function()
    reset()
    local raw = "item:11968:0:0:0"
    assert(TB:GetItemMetadata(raw), "raw item did not populate metadata")
    local listing = { itemLink = ringLink }
    TB:RefreshListingMetadata(listing)
    assert(listing.itemLink == ringLink, "full ring hyperlink replaced by earlier raw cache entry")
    TB:CaptureWorldMessage("WTS " .. ringLink, "Seller", "World")
    assert(TB.Listings[1].itemLink == ringLink, "chat import received raw cached hyperlink")
end)

test("Repeated cache misses are bounded and resolve after retry", function()
    reset()
    local originalGetItemInfo = GetItemInfo
    local calls = 0
    GetItemInfo = function(query) calls = calls + 1; return originalGetItemInfo(query) end
    cached = false
    local i
    for i = 1, 20 do TB:GetItemMetadata(mailLink) end
    assert(calls == 2, "uncached repeated rows hammered item lookup")
    cached = true; now = now + 2
    assert(TB:GetItemMetadata(mailLink), "cache miss never retried")
    assert(calls == 4, "retry made unexpected lookups")
    GetItemInfo = originalGetItemInfo
end)

test("WTS item offers expire at three hours while services, WTB and archive remain", function()
    reset()
    local postedAt = wallNow
    TB:CaptureWorldMessage("wTs " .. ringLink, "Seller", "World")
    local sale = TB.Listings[1]
    TB:CaptureWorldMessage("WTS Crusader enchants", "Crafter", "Trade")
    TB:CaptureWorldMessage("WTB " .. mailLink, "Buyer", "World")
    local wanted = TB.Listings[2]
    TB:UpsertListing({ owner = "Manual", trader = "Manual", id = "manual", itemLink = ringLink, isMine = 1 })
    assert(sale.expiresAt == postedAt + 10800, "WTS expiry is not measured from original post")
    assert(wanted.expiresAt == postedAt + 43200 and TB.Services[1].expiresAt == postedAt + 43200, "non-WTS/service lifetime was shortened")
    wallNow = postedAt + 10799
    TB:ExpireRemoteData()
    assert(table.getn(TB.Listings) == 3, "WTS item expired before three hours")
    wallNow = postedAt + 10800
    TB:ExpireRemoteData(); TB:PruneWorldLog()
    assert(table.getn(TB.Listings) == 2 and not TB.ListingIndex[TB:GetListingKey("Seller", sale.id)], "WTS item survived three-hour cleanup")
    assert(table.getn(TB.Services) == 1 and table.getn(TB.WorldLog) == 3, "cleanup removed services or chat archive early")
    wallNow = postedAt
end)

test("Login rebuilding the twelve-hour archive never resurrects expired WTS items", function()
    reset()
    local postedAt = wallNow
    TB:CaptureWorldMessage("WTS " .. ringLink, "Seller", "Trade")
    TB:CaptureWorldMessage("WTS Crusader enchant " .. mailLink, "Crafter", "World")
    -- Simulate an old version's derived 12-hour offers being rebuilt on login.
    TB.Listings[1].expiresAt = postedAt + 43200
    wallNow = postedAt + 10800
    TB.WorldLog = nil; TB.worldLogInitialized = nil
    TB:InitializeWorldLog()
    assert(table.getn(TB.Listings) == 0, "login restored expired WTS items")
    assert(table.getn(TB.WorldLog) == 2 and table.getn(TB.Services) == 1, "login lost archive or still-active profession offer")
    assert(TB.Services[1].expiresAt == postedAt + 43200, "rebuild extended service lifetime")
    wallNow = postedAt
end)

test("Old peer WTS snapshots stay archived without restarting the Browse lifetime", function()
    reset()
    local function receive(id, age)
        local entry = {
            id = id, timestamp = wallNow - age, type = "WTS", channel = "World", sender = "PeerSeller",
            message = "WTS Crusader enchant " .. ringLink,
        }
        local fields, field = {}, nil
        for field in string.gfind(TB:BuildWorldMessage(entry) .. "~", "(.-)~") do table.insert(fields, field) end
        TB:HandleWorldMessage(fields, "Relay")
    end
    receive("old", 10800)
    assert(table.getn(TB.WorldLog) == 1 and table.getn(TB.Services) == 1, "old peer snapshot was not archived with its active service")
    assert(table.getn(TB.Listings) == 0, "peer replay resurrected expired item")
    receive("recent", 7200)
    assert(table.getn(TB.Listings) == 1 and TB.Listings[1].expiresAt == wallNow + 3600, "peer receipt restarted full three-hour lifetime")
end)

assert(table.getn(failures) == 0, table.concat(failures, "\n"))
print("HC TradeBoard data regression tests passed")
