-- Run from the workspace root with Lua 5.1 or Fengari.
table.getn = table.getn or function(value) return #value end
string.gfind = string.gfind or string.gmatch
math.mod = math.mod or math.fmod

local wallNow, sessionNow = 2000000000, 1000
local cachedNames = {}
function UnitName() return "Tester" end
function UnitLevel() return 30 end
function GetGuildInfo() return "Test Guild" end
function GetTime() return sessionNow end
function time() return wallNow end
function UnitFactionGroup() return "Alliance" end
function GetItemInfo(item)
    local name = cachedNames[item]
    if name then return name, item, 2, 10, "Armor", "Mail", 1, "INVTYPE_CHEST", "MailIcon" end
end

dofile("HC-Tradeboard/Core.lua")
dofile("HC-Tradeboard/Network.lua")
local TB = TradeBoard
local ring = "|cff1eff00|Hitem:100:0:0:0|h[Amber Ring]|h|r"
local boots = "|cff1eff00|Hitem:101:0:0:0|h[Mail Boots]|h|r"

local function reset()
    TB.Listings, TB.ListingIndex, TB.MyListings = {}, {}, {}
    TB.Services, TB.ServiceIndex, TB.WorldLog = {}, {}, {}
    TB.ItemMetadataCache, TB.ItemMetadataCacheCount, cachedNames = {}, 0, {}
    TB.State.selectedListing = nil
    TB:ResetFilters()
    TradeBoardDB = nil
    TB:InitializeWorldLog()
end

local function chat(id, timestamp, sender, link, message, kind)
    local entry = {
        id = id, timestamp = timestamp, sender = sender, channel = "World",
        type = kind or "WTS", items = { link }, message = message,
    }
    TB:ImportWorldEntry(entry)
    return TB.Listings[table.getn(TB.Listings)]
end

local function published(id, name, seller, timestamp)
    local listing = {
        id = id, name = name, owner = seller, trader = seller,
        quality = 2, category = "Armor", tags = { Mail = 1 },
        quantity = 1, totalPrice = 50000, orderType = "SELL",
        source = "LISTED", online = 1, lastSeenAt = timestamp,
    }
    TB:UpsertListing(listing)
    return listing
end

reset()
local old = chat("old", wallNow - 120, "Seller", ring, "WTS " .. ring .. " x2 2g total")
TB.State.selectedListing = old
local newest = chat("new", wallNow - 60, "Seller", ring, "WTS " .. ring .. " x3 4g total")
local visible = TB:GetFilteredListings()
assert(table.getn(visible) == 1 and visible[1] == newest, "repeat WTS did not show only the newest offer")
assert(visible[1].quantity == 3 and visible[1].totalPrice == 40000, "duplicate quantities/prices were combined or stale")
assert(visible[1].expiresAt == wallNow - 60 + TB.CHAT_WTS_TTL, "dedup renewed the original offer expiry")
assert(TB.State.selectedListing == newest, "selected listing did not follow its replacement")
assert(table.getn(TB.Listings) == 2 and visible.totalUnique == 1, "dedup deleted protocol records or inflated the UI count")

local replay = {
    id = "peer-old", timestamp = wallNow - 90, sender = "Seller", channel = "Trade",
    type = "WTS", message = "WTS " .. ring .. " x9 1g total",
}
local fields = {}
for field in string.gfind(TB:BuildWorldMessage(replay) .. "~", "(.-)~") do table.insert(fields, field) end
TB:HandleWorldMessage(fields, "Relay")
visible = TB:GetFilteredListings()
assert(table.getn(visible) == 1 and visible[1] == newest, "older peer replay replaced a newer local offer")
assert(table.getn(TB.WorldLog) == 1 and table.getn(TB.Listings) == 3, "Browse folding removed archive or protocol records")

local own = published("own", "Amber Ring", "Seller", wallNow - 300)
TB.MyListings = { own }
visible = TB:GetFilteredListings()
assert(table.getn(visible) == 1 and visible[1] == own, "published offer did not take priority over inferred chat")
assert(table.getn(TB.MyListings) == 1 and TB.MyListings[1] == own, "Browse folding mutated My Listings")
chat("other-seller", wallNow, "OtherSeller", ring, "WTS " .. ring)
chat("other-item", wallNow, "Seller", boots, "WTS " .. boots)
visible = TB:GetFilteredListings()
assert(table.getn(visible) == 3 and visible.totalUnique == 3, "distinct items or sellers were folded together")

reset()
published("a", "  |cff1eff00Amber   Ring|r  ", "  SELLER ", wallNow)
local normalizedWinner = published("b", "amber ring", "seller", wallNow)
visible = TB:GetFilteredListings()
assert(table.getn(visible) == 1 and visible[1] == normalizedWinner, "name/color/whitespace normalization or stable tie failed")
TB.Listings[1], TB.Listings[2] = TB.Listings[2], TB.Listings[1]
visible = TB:GetFilteredListings()
assert(visible[1] == normalizedWinner, "equal-time winner changed with arrival order")

reset()
local sale = chat("sale", wallNow - 20, "Seller", ring, "WTS " .. ring)
local wanted = chat("wanted", wallNow - 10, "Seller", ring, "WTB " .. ring, "WTB")
visible = TB:GetFilteredListings()
assert(table.getn(visible) == 1 and visible[1] == wanted, "All listings showed duplicate sale/wanted rows")
TB.State.listingType = "SELL"
visible = TB:GetFilteredListings()
assert(table.getn(visible) == 1 and visible[1] == sale, "dedup hid the sale from its type filter")
TB.State.listingType = "BUY"
visible = TB:GetFilteredListings()
assert(table.getn(visible) == 1 and visible[1] == wanted, "dedup hid the wanted offer from its type filter")

reset()
local first = chat("uncached-a", wallNow - 20, "Seller", ring, "WTS " .. ring)
local second = chat("uncached-b", wallNow - 10, "Seller", boots, "WTS " .. boots)
assert(table.getn(TB:GetFilteredListings()) == 2, "uncached distinct names unexpectedly collapsed")
cachedNames["item:100:0:0:0"], cachedNames["item:101:0:0:0"] = "Resolved Mail", "Resolved Mail"
sessionNow = sessionNow + 3
TB.State.category, TB.State.subCategory = "Armor", "Mail"
visible = TB:GetFilteredListings()
assert(table.getn(visible) == 1 and visible[1] == second, "newly cached names were not folded before category filtering")
assert(first.name == "Resolved Mail" and second.name == "Resolved Mail", "cached metadata was not refreshed")

reset()
local stillValid = chat("wanted-valid", wallNow - TB.CHAT_WTS_TTL - 10, "Seller", ring, "WTB " .. ring, "WTB")
local expiresFirst = chat("sale-expiring", wallNow - TB.CHAT_WTS_TTL + 1, "Seller", ring, "WTS " .. ring)
assert(TB:GetFilteredListings()[1] == expiresFirst, "newer active sale was not initially selected")
wallNow = wallNow + 2
visible = TB:GetFilteredListings()
assert(table.getn(visible) == 1 and visible[1] == stillValid and visible.totalUnique == 1, "expired winner hid a valid offer for the same item/seller")
TB.State.selectedListing = stillValid
TB.State.search = "no such item"
visible = TB:GetFilteredListings()
assert(table.getn(visible) == 0 and visible.totalUnique == 1 and not TB.State.selectedListing, "filtered count or stale selection was not updated")

print("HC TradeBoard Browse dedup regression tests passed")
