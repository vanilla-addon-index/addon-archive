-- Run from the workspace root with Lua 5.1+ (the addon remains Lua 5.0 compatible).
table.getn = table.getn or function(value) return #value end
string.gfind = string.gfind or string.gmatch
local now = 1000
local openedWhisper, clickedItem, tooltipItem
local Frame = {}
Frame.__index = function(self, key)
    local methods = {
        SetScript = function(object, name, callback) object.scripts[name] = callback end,
        SetText = function(object, text) object.text = text end,
        SetTextColor = function(object, r, g, b) object.textColor = { r, g, b } end,
        SetTexture = function(object, texture) object.texture = texture end,
        Show = function(object) object.shown = true end,
        Hide = function(object) object.shown = false end,
        IsShown = function(object) return object.shown end,
        Enable = function(object) object.enabled = true end,
        Disable = function(object) object.enabled = false end,
        CreateTexture = function() return CreateFrame("Texture") end,
        CreateFontString = function() return CreateFrame("FontString") end,
        SetHyperlink = function(object, link) tooltipItem = link end,
    }
    if methods[key] then return methods[key] end
    if string.find(key, "^[A-Z]") then return function() end end
    return nil
end
function CreateFrame() return setmetatable({ scripts = {}, shown = true }, Frame) end
function GetTime() return now end
function UnitName() return "Me" end
function GetItemInfo() return nil end
function IsShiftKeyDown() return nil end
function SetItemRef(link) clickedItem = link end
function SendChatMessage() error("guild notifications must not send chat") end
function SendAddonMessage() error("guild notifications must not share guild chat") end
UIParent = CreateFrame()
GameTooltip = CreateFrame()

dofile("HC-Tradeboard/Core.lua")
dofile("HC-Tradeboard/Network.lua")
dofile("HC-Tradeboard/Features.lua")
dofile("HC-Tradeboard/GuildLoot.lua")
local TB = TradeBoard
TB.OpenWorldWhisper = function(self, name) openedWhisper = name end
local function link(id, name) return "|cff1eff00|Hitem:" .. id .. ":0:0:0|h[" .. name .. "]|h|r" end
local cloak = link(1, "Ancient Cloak of Agility")
local sphere = link(2, "Sorcerer Sphere of the Eagle")
local ring = link(3, "Widow's Kiss")

assert(not TB:CaptureGuildLootMessage("I looted " .. cloak, "Frank"), "ordinary loot chatter created a popup")
assert(not TB:CaptureGuildLootMessage("WTB " .. cloak, "Buyer"), "buy request created a giveaway")
assert(not TB:CaptureGuildLootMessage("Anyone need " .. cloak, "Me"), "own guild message created a popup")
assert(TB:CaptureGuildLootMessage("Anyone need anything? " .. cloak .. " 49+-", "Frank"), "screenshot offer was not detected")
assert(TB.GuildLoot.active.kind == "GIVE" and TB.GuildLoot.active.sender == "Frank", "offer metadata is incorrect")
assert(TB:CaptureGuildLootMessage(sphere, "Frank"), "item-only followup was not included")
assert(TB:CaptureGuildLootMessage(ring, "Frank"), "second item-only followup was not included")
assert(table.getn(TB.GuildLoot.active.links) == 3, "followups did not merge into active offer")
assert(not TB:CaptureGuildLootMessage(ring, "Frank"), "duplicate offer was not suppressed")
assert(not TB:CaptureGuildLootMessage(sphere, "Other"), "another sender inherited the offer context")
assert(not TB:CaptureGuildLootMessage("I crafted " .. link(4, "Free Action Potion"), "Crafter"), "item-name keyword triggered a giveaway")
assert(TB:CaptureGuildLootMessage("wTs " .. sphere .. " 2g", "Seller"), "case-insensitive sale was not detected")
assert(table.getn(TB.GuildLoot.queue) == 1, "second seller was not queued")

local frame = TB.GuildLoot.frame
assert(frame.muteDuration.seconds == 600 and frame.mute.text == "Mute Guild", "popup mute controls were not initialized")
this = frame.rows[1]
this.scripts.OnEnter()
assert(tooltipItem == "item:1:0:0:0", "hover did not show item tooltip")
this.scripts.OnClick()
assert(clickedItem == "item:1:0:0:0", "click did not open item")
frame.whisper.scripts.OnClick()
assert(openedWhisper == "Frank", "whisper action used wrong author")
frame.dismiss.scripts.OnClick()
assert(TB.GuildLoot.active.sender == "Seller", "dismiss did not advance queue")
now = now + 61
this = frame
frame.scripts.OnUpdate()
assert(not TB.GuildLoot.active and not frame.shown, "popup did not expire")
assert(not TB:CaptureGuildLootMessage(link(5, "Stale Followup"), "Frank"), "stale offer context accepted a followup")

TB:SetGuildLootEnabled(false)
assert(not TB:CaptureGuildLootMessage("FREE " .. cloak, "Frank"), "disabled notifications captured guild offers")
TB:SetGuildLootEnabled(true)
assert(TB:CaptureGuildLootMessage("FREE " .. cloak, "Frank"), "notifications did not re-enable")
assert(not TB:CaptureGuildLootMessage("Congrats!", "Frank"), "unrelated chatter created a popup")
assert(not TB:CaptureGuildLootMessage(sphere, "Frank"), "unrelated chatter did not end continuation")
TB:ClearGuildLoot()
assert(not TB:CaptureGuildLootMessage("Anyone want anything?", "Frank"), "plain introduction created an empty offer")
assert(TB:CaptureGuildLootMessage(sphere, "Frank"), "plain introduction did not establish continuation")

-- Offer tags match punctuation and casing, but never words inside item links.
local tags = { "ANYONE?", "Anybody!", "any1?", "nEeD?", "NEEDS ?", "FREE!", "Giving:", "Giveaway!" }
local i
for i = 1, table.getn(tags) do
    TB:ClearGuildLoot()
    assert(TB:CaptureLootMessage(tags[i] .. " " .. cloak, "PublicSeller", "World", 4), "public offer tag was missed: " .. tags[i])
    assert(TB.GuildLoot.active.kind == "GIVE", "public offer tag was classified as a sale")
end
TB:ClearGuildLoot()
assert(not TB:CaptureLootMessage("I crafted " .. link(4, "Free Action Potion"), "Crafter", "World", 4), "linked item name triggered a public giveaway")
assert(not TB:CaptureLootMessage("freestyle needless " .. cloak, "Crafter", "World", 4), "partial word triggered a public giveaway")
assert(not TB:CaptureLootMessage("Anyone? " .. cloak, "LocalSeller", "General", 1), "unsupported channel created a popup")

-- Routine public sales remain in Browse; tagged sales retain their selling intent.
assert(not TB:CaptureLootMessage("WTS " .. cloak, "PublicSeller", "Trade", 2), "ordinary public WTS created a popup")
assert(not TB:CaptureLootMessage("WTB anyone selling " .. cloak, "Buyer", "World", 4), "public WTB was treated as an offer")
assert(TB:CaptureLootMessage("wTs - anyone needs? " .. cloak .. " 2g", "PublicSeller", "2. Trade - City", 2), "tagged public sale was missed")
assert(TB.GuildLoot.active.kind == "SELL" and TB.GuildLoot.active.channel == "Trade", "tagged public sale lost kind or channel")

-- Continuations, duplicate keys, and merged rows stay isolated by source and author.
TB:ClearGuildLoot()
assert(TB:CaptureGuildLootMessage("Anyone? " .. cloak, "Frank"))
assert(not TB:CaptureLootMessage(sphere, "Frank", "World", 4), "World inherited Guild continuation")
assert(TB:CaptureLootMessage("free " .. cloak, "Frank", "World", 4), "Guild duplicate key suppressed World offer")
assert(TB:CaptureLootMessage("free " .. cloak, "Frank", "Trade", 2), "World duplicate key suppressed Trade offer")
assert(not TB:CaptureLootMessage("FREE " .. cloak, "Frank", "World", 4), "same-source duplicate was not suppressed")
assert(TB:CaptureLootMessage(sphere, "Frank", "World", 4), "World followup failed")
assert(TB:CaptureGuildLootMessage(ring, "Frank"), "Guild followup failed after public traffic")
assert(table.getn(TB.GuildLoot.queue) == 2 and table.getn(TB.GuildLoot.active.links) == 2, "sources merged into Guild active popup")
assert(TB.GuildLoot.queue[1].channel == "World" and table.getn(TB.GuildLoot.queue[1].links) == 2, "World continuation merged into the wrong offer")
assert(TB.GuildLoot.queue[2].channel == "Trade" and table.getn(TB.GuildLoot.queue[2].links) == 1, "World continuation merged into Trade")
assert(not TB:CaptureLootMessage("Congrats!", "Frank", "World", 4))
assert(not TB:CaptureLootMessage(ring, "Frank", "World", 4), "unrelated World chatter retained continuation")
assert(TB:CaptureGuildLootMessage(sphere, "Frank"), "World chatter ended Guild continuation")

-- A reused popup must repaint author and excerpt, preserving item quality colors.
ChatTypeInfo = { CHANNEL4 = { r = 0.8, g = 0.6, b = 0.4 }, CHANNEL2 = { r = 0.9, g = 0.5, b = 0.3 }, CHANNEL = { r = 0.7, g = 0.6, b = 0.5 } }
local function assertPopupColor(r, g, b)
    local sellerColor, messageColor = frame.seller.textColor, frame.message.textColor
    assert(sellerColor and sellerColor[1] == r and sellerColor[2] == g and sellerColor[3] == b, "seller retained incorrect channel color")
    assert(messageColor and messageColor[1] == r and messageColor[2] == g and messageColor[3] == b, "message retained incorrect channel color")
    assert(frame.rows[1].label.text == cloak, "popup changed item quality link color")
end
assertPopupColor(0.25, 1, 0.25)
TB:DismissGuildLoot()
assert(frame.title.text == "World loot offers", "World popup was mislabeled")
assertPopupColor(0.8, 0.6, 0.4)
TB:DismissGuildLoot()
assert(frame.title.text == "Trade loot offers", "Trade popup was mislabeled")
assertPopupColor(0.9, 0.5, 0.3)
TB:ClearGuildLoot()
assert(TB:CaptureLootMessage("free " .. cloak, "Fallback", "World"))
assertPopupColor(0.7, 0.6, 0.5)
TB:ClearGuildLoot()
ChatTypeInfo = nil
assert(TB:CaptureLootMessage("free " .. cloak, "Fallback", "World"))
assertPopupColor(1, 0.75, 0.75)
TB:ClearGuildLoot()
assert(TB:CaptureGuildLootMessage("free " .. cloak, "Frank"))
assertPopupColor(0.25, 1, 0.25)

-- Exercise actual chat event routing: arg8 is the channel number, not arg7.
TB:ClearGuildLoot()
event, arg1, arg2, arg4, arg7, arg8, arg9 = "CHAT_MSG_CHANNEL", "anyone needs ? " .. link(6, "Duskwoven Cape of Frozen Wrath") .. " 45+-", "Daarkynn", "4. World", 26, 4, "World"
TB.GuildLoot.events.scripts.OnEvent()
assert(TB.GuildLoot.active and TB.GuildLoot.active.channel == "World" and TB.GuildLoot.active.channelNumber == 4, "screenshot chat event used wrong channel or number")
TB:ClearGuildLoot()
arg1, arg2, arg4, arg8, arg9 = "Anybody? " .. cloak, "TradeSeller", "2. Trade - City", 2, nil
TB.GuildLoot.events.scripts.OnEvent()
assert(TB.GuildLoot.active and TB.GuildLoot.active.channel == "Trade" and TB.GuildLoot.active.channelNumber == 2, "chat event did not fall back to full channel name")
TB:ClearGuildLoot()
arg1, arg2, arg4, arg8, arg9 = "Anyone? " .. cloak, "LocalSeller", "1. General - City", 1, "General"
TB.GuildLoot.events.scripts.OnEvent()
assert(not TB.GuildLoot.active, "General event bypassed public channel restrictions")
arg4, arg8, arg9 = "5. Guild", 5, "Guild"
TB.GuildLoot.events.scripts.OnEvent()
assert(not TB.GuildLoot.active, "custom public channel named Guild was treated as guild chat")
event, arg1, arg2 = "CHAT_MSG_GUILD", "WTS " .. cloak, "GuildSeller"
TB.GuildLoot.events.scripts.OnEvent()
assert(TB.GuildLoot.active and TB.GuildLoot.active.channel == "Guild", "guild event lost its original sale behavior")
event, arg1, arg2, arg4, arg7, arg8, arg9 = nil, nil, nil, nil, nil, nil, nil

-- The existing notification switch applies to public channels too.
TB:SetGuildLootEnabled(false)
assert(not TB:CaptureLootMessage("free " .. cloak, "PublicSeller", "World", 4), "disabled notifications captured a public offer")
assert(not TB.GuildLoot.active and table.getn(TB.GuildLoot.queue) == 0, "disabling notifications retained a popup")
TB:SetGuildLootEnabled(true)
assert(TB:CaptureLootMessage("free " .. cloak, "PublicSeller", "World", 4), "public notifications did not re-enable")

-- Muting from the popup uses the selected duration and only suppresses its source.
this = frame.muteDuration.options[1]
this.scripts.OnClick()
assert(frame.muteDuration.seconds == 300 and TradeBoardDB.popupMuteSeconds == 300, "popup duration dropdown did not save 5 minutes")
this = frame.mute
this.scripts.OnClick()
assert(not TB:IsLootSourceEnabled("World") and not TB.GuildLoot.active, "popup mute button did not suppress World/Trade")
TB:SetLootMute("Public", 0)

TB:ClearGuildLoot()
for i = 1, 140 do TB:CaptureGuildLootMessage("WTS " .. link(i, "Item " .. i), "Seller" .. i) end
assert(table.getn(TB.GuildLoot.queue) <= 20, "offer queue is unbounded")
assert(table.getn(TB.GuildLoot.recent) <= 100, "duplicate cache is unbounded")
assert(table.getn(TB.GuildLoot.contexts) <= 32, "followup context is unbounded")
TB:ClearGuildLoot()
print("HC TradeBoard guild loot smoke test passed")
