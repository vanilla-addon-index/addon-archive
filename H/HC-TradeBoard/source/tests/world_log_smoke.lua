-- Standalone logic smoke test; run from the workspace root with Lua 5.0/5.1.
table.getn = table.getn or function(value) return #value end
string.gfind = string.gfind or string.gmatch
math.mod = math.mod or math.fmod

function UnitName() return "Tester" end
function UnitLevel() return 30 end
function GetGuildInfo() return "Test Guild" end
function GetTime() return 1000 end
function time() return 2000000000 end
function UnitFactionGroup() return "Alliance" end
function GetItemInfo(link)
    if arg and arg[1] == "vanilla" then
        return "Linen Cloth", link, 2, 5, "Trade Goods", "Cloth", 20, "", "Interface\\Icons\\INV_Fabric_Linen_01"
    end
    return "Linen Cloth", link, 2, 10, 5, "Trade Goods", "Cloth", 20, "", "Interface\\Icons\\INV_Fabric_Linen_01"
end

dofile("HC-Tradeboard/Core.lua")
dofile("HC-Tradeboard/Network.lua")

local TB = TradeBoard

assert(TB.WORLD_LOG_TTL == 43200, "chat archive TTL is not 12 hours")
TradeBoardDB = nil
TB:InitializeWorldLog()

TB:CaptureWorldMessage("ordinary conversation", "Chatter", "World")
assert(table.getn(TB.WorldLog) == 0, "non-WTS/LFW message was captured")
TB:CaptureWorldMessage("WTS cloth", "Seller", "General")
assert(table.getn(TB.WorldLog) == 0, "non-World message was captured")

local link = "|cff1eff00|Hitem:2589:0:0:0|h[Linen Cloth]|h|r"
TB:CaptureWorldMessage("wTs " .. link .. " x20 2g total", "Seller", "1. World")
assert(table.getn(TB.WorldLog) == 1, "WTS message was not captured")
assert(TB.WorldLog[1].type == "WTS", "WTS type was not classified")
assert(TB.WorldLog[1].items[1] == link, "item hyperlink was not retained")
assert(TB.WorldLog[1].channel == "World", "World channel was not retained")
assert(table.getn(TB.Listings) == 1 and TB.Listings[1].source == "CHAT", "World item was not imported into Browse")
assert(TB.Listings[1].quantity == 20 and TB.Listings[1].totalPrice == 20000, "chat quantity or total price parsing failed")
local segments = TB:GetWorldMessageSegments("wTs " .. link .. " cheap")
assert(table.getn(segments) == 3, "World message was not split around its item link")
assert(segments[2].itemLink == link and segments[3].text == " cheap", "clickable item segment was not retained inline")

TB:CaptureWorldMessage("lfw alchemist", "Crafter", "World")
assert(table.getn(TB.WorldLog) == 2 and TB.WorldLog[2].type == "LFW", "LFW message was not captured")
TB:RememberWorldPerson("Crafter", "Potion Club", 42)
assert(TB.WorldLog[2].guild == "Potion Club" and TB.WorldLog[2].level == 42, "known peer metadata was not applied")

TB:CaptureWorldMessage("wTb linen cloth", "Buyer", "World")
assert(table.getn(TB.WorldLog) == 3 and TB.WorldLog[3].type == "WTB", "case-insensitive WTB message was not captured")
TB:CaptureWorldMessage("WTS Crusader enchants, your mats", "Enchanter", "2. Trade - City")
assert(table.getn(TB.WorldLog) == 4 and TB.WorldLog[4].channel == "Trade", "Trade channel message was not captured")
local foundChatService
local serviceIndex
for serviceIndex = 1, table.getn(TB.Services) do
    if TB.Services[serviceIndex].trader == "Enchanter" and TB.Services[serviceIndex].profession == "Enchanting" then foundChatService = TB.Services[serviceIndex] end
end
assert(foundChatService and foundChatService.source == "CHAT", "profession chat offer was not imported")

TB.State.worldType = "WTS"
TB.State.worldSearch = "seller"
assert(table.getn(TB:GetFilteredWorldLog()) == 1, "World log filtering failed")

local friends = { shown = true }
function friends:IsShown() return self.shown end
FriendsFrame = friends
function HideUIPanel(frame) frame.shown = false end
function GetNumWhoResults() return 1 end
function GetWhoInfo() return "Buyer", "Buyers Guild", 37, "Human", "Mage" end
TB.PendingManualWhoName = "buyer"
TB:NetworkOnEvent("WHO_LIST_UPDATE")
assert(FriendsFrame:IsShown(), "manual Who window was unexpectedly closed")
assert(TB.WorldLog[3].guild == "Buyers Guild" and TB.WorldLog[3].level == 37 and TB.WorldLog[3].class == "Mage", "Who result did not enrich WTB data")
local identityQueued
local queuedIndex
for queuedIndex = 1, table.getn(TB.SendQueue or {}) do if string.find(TB.SendQueue[queuedIndex].message, "~I~", 1, 1) then identityQueued = 1 end end
assert(identityQueued, "manual Who identity was not queued for peer sharing")

local openedChat, sentWho, whoToUI
function ChatFrame_OpenChat(text) openedChat = text end
function SendWho(query) sentWho = query end
function SetWhoToUI(value) whoToUI = value end
TB:OpenWorldWhisper("Seller")
assert(openedChat == "/w Seller ", "character click did not prepare a whisper")
TB:RequestManualWho("Seller")
assert(sentWho == 'n-"Seller"' and whoToUI == 1, "Who button did not issue a visible character Who query")
assert(TB.PendingManualWhoName == "seller", "manual Who request was not tracked")

local peerEntry = {
    id = "peer:1", timestamp = TB:GetWallTime(), type = "WTS", channel = "Trade", sender = "RemoteSeller",
    level = 44, class = "Rogue", guild = "Remote Guild", message = "WTS " .. link .. " 3g",
}
local peerFields = {}
local field
for field in string.gfind(TB:BuildWorldMessage(peerEntry) .. "~", "(.-)~") do table.insert(peerFields, field) end
TB:HandleWorldMessage(peerFields, "Relay")
assert(TB.WorldLog[table.getn(TB.WorldLog)].source == "PEER", "peer World message was not stored")
assert(TradeBoardDB.worldPeople.remoteseller.class == "Rogue", "peer identity data was not retained")

local listingMessage = TB:BuildListingMessage({ id = "1", itemLink = link, quality = 2, requiredLevel = 5, itemLevel = 10, quantity = 20, totalPrice = 30000, traderLevel = 30, orderType = "SELL", category = "Trade Goods", tags = {}, guild = "Test Guild" })
assert(string.find(listingMessage, "~20~30000~", 1, 1), "listing protocol did not transmit total price")

TB.SendQueue = {}
TB:QueueMessage("first", 10, "same-record")
local firstDue = TB.SendQueue[1].due
TB:QueueMessage("newest", 20, "same-record")
assert(table.getn(TB.SendQueue) == 1 and TB.SendQueue[1].message == "newest" and TB.SendQueue[1].due == firstDue, "network queue did not coalesce duplicate records")
TB.Network = { peers = {}, state = "OFFLINE" }
TB:NetworkOnEvent("CHAT_MSG_WHISPER_INFORM", "hello", "Friend")
assert(TB.Network.userChatQuietUntil == GetTime() + 15, "background traffic did not use the conservative pause after player chat")

print("HC TradeBoard World log smoke test passed")
