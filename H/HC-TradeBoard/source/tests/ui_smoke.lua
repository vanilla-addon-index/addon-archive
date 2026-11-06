-- Headless WoW 1.12 UI regression test. Run from the workspace root.
-- Pass --preview to emit an SVG of the filter bar using recorded frame geometry.
table.getn = table.getn or function(value) return #value end
string.gfind = string.gfind or string.gmatch
math.mod = math.mod or math.fmod
math.atan2 = math.atan2 or math.atan

local objects = {}
local Frame, methods = {}, {}
local function fire(object, eventName, eventArgument)
    local previousThis, previousArg1 = this, arg1
    this, arg1 = object, eventArgument
    local callback = object.scripts[eventName]
    if callback then callback() end
    this, arg1 = previousThis, previousArg1
end
local function newObject(kind, name, parent)
    local object = setmetatable({ scripts = {}, points = {}, shown = true, enabled = true, parent = parent, frameType = kind, name = name }, Frame)
    table.insert(objects, object)
    if name then _G[name] = object end
    return object
end
local function plainText(value)
    local text = tostring(value or "")
    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = string.gsub(text, "|H[^|]+|h", "")
    return string.gsub(text, "|[hr]", "")
end
function methods:SetWidth(value) self.width = value end
function methods:SetHeight(value) self.height = value end
function methods:GetWidth() return rawget(self, "width") or (self.frameType == "FontString" and self:GetStringWidth()) or 100 end
function methods:GetHeight() return rawget(self, "height") or (self.frameType == "FontString" and 12) or 100 end
function methods:SetText(value)
    local changed = self.textValue ~= value
    self.textValue = value or ""
    if changed then fire(self, "OnTextChanged") end
end
function methods:GetText() return self.textValue or "" end
function methods:GetStringWidth() return string.len(plainText(self.textValue)) * 6 end
function methods:SetScript(eventName, callback) self.scripts[eventName] = callback end
function methods:GetScript(eventName) return self.scripts[eventName] end
function methods:Show() local changed = not self.shown; self.shown = true; if changed then fire(self, "OnShow") end end
function methods:Hide() local changed = self.shown; self.shown = false; if changed then fire(self, "OnHide") end end
function methods:IsShown() return self.shown end
function methods:Enable() self.enabled = true end
function methods:Disable() self.enabled = false end
function methods:EnableMouse(value) self.mouseEnabled = value end
function methods:EnableKeyboard(value) self.keyboardEnabled = value end
function methods:SetAlpha(value) self.alpha = value end
function methods:SetClampedToScreen(value) self.clampedToScreen = value end
function methods:SetPoint(point, relative, relativePoint, x, y)
    assert(type(point) == "string" and type(relative) == "table" and type(relativePoint) == "string", "invalid legacy SetPoint signature")
    assert(type(x) == "number" and type(y) == "number", "SetPoint coordinates must be numeric")
    self.points[point] = { point = point, relative = relative, relativePoint = relativePoint, x = x, y = y }
end
function methods:ClearAllPoints() self.points = {} end
function methods:SetAllPoints(relative)
    self:SetPoint("TOPLEFT", relative, "TOPLEFT", 0, 0)
    self:SetPoint("BOTTOMRIGHT", relative, "BOTTOMRIGHT", 0, 0)
end
function methods:SetBackdropColor(r, g, b, a) self.backdropColor = { r, g, b, a } end
function methods:SetBackdropBorderColor(r, g, b, a) self.borderColor = { r, g, b, a } end
function methods:SetTextColor(r, g, b) self.textColor = { r, g, b } end
function methods:SetJustifyV(value) self.justifyV = value end
function methods:SetTexture(value) self.textureValue = value end
function methods:SetHyperlink(value) self.hyperlink = value end
function methods:GetFrameLevel() return 1 end
function methods:GetEffectiveScale() return 1 end
function methods:GetCenter() return 500, 400 end
function methods:GetTop() return 500 end
function methods:GetID() return 1 end
function methods:GetName() return self.name end
function methods:NumLines() return 0 end
function methods:CreateTexture(name) return newObject("Texture", name, self) end
function methods:CreateFontString(name) return newObject("FontString", name, self) end
Frame.__index = function(self, key)
    if methods[key] then return methods[key] end
    -- Unknown data fields must be nil, not fake methods; this catches stale rows.
    if string.find(key, "^[A-Z]") then return function() end end
    return nil
end
function CreateFrame(frameType, name, parent) return newObject(frameType, name, parent) end

UIParent = CreateFrame("Frame", "UIParent")
Minimap = CreateFrame("Frame", "Minimap", UIParent)
GameTooltip = CreateFrame("Frame", "GameTooltip", UIParent)
ChatFrameEditBox = CreateFrame("EditBox", "ChatFrameEditBox", UIParent)
DEFAULT_CHAT_FRAME = CreateFrame("Frame", "ChatFrame1", UIParent)
UISpecialFrames = {}
SlashCmdList = {}

local now, whoQueries = 1000, {}
local openedChat, openedItem
function getglobal(name) return _G[name] end
function UnitName() return "Tester" end
function UnitLevel() return 30 end
function UnitFactionGroup() return "Alliance" end
function GetGuildInfo() return "Test Guild" end
function GetTime() return now end
function time() return 2000000000 + math.floor(now - 1000) end
function date() return "09-15 12:00" end
function GetCursorPosition() return 500, 400 end
function GetNumSkillLines() return 0 end
function GetChannelName() return 0 end
function GetContainerNumSlots() return 0 end
function GetItemInfo(link)
    -- Actual Vanilla tuple: type is fifth; there is no extra required-level slot.
    if string.find(tostring(link), "3302", 1, 1) then
        return "Brackwater Boots", link, 2, 10, "Armor", "Mail", 1, "INVTYPE_FEET", "Interface\\Icons\\INV_Boots_03"
    elseif string.find(tostring(link), "9991", 1, 1) then
        return "Test Rare Ring", link, 3, 35, "Armor", "Miscellaneous", 1, "INVTYPE_FINGER", "Interface\\Icons\\INV_Jewelry_Ring_01"
    end
    return "Linen Cloth", link, 2, 0, "Trade Goods", "Cloth", 20, "", "Interface\\Icons\\INV_Fabric_Linen_01"
end
function IsShiftKeyDown() return nil end
function CursorHasItem() return nil end
function ClearCursor() end
function ChatFrame_OpenChat(text) openedChat = text end
function SetItemRef(hyperlink) openedItem = hyperlink end
function AddFriend() end
function ChatFrame_RemoveChannel() end
function SetWhoToUI() end
function SendWho(query) table.insert(whoQueries, query) end

dofile("HC-Tradeboard/Core.lua")
dofile("HC-Tradeboard/Network.lua")
dofile("HC-Tradeboard/Features.lua")
dofile("HC-Tradeboard/UI.lua")
dofile("HC-Tradeboard/GuildLoot.lua")

local TB = TradeBoard
assert(TB.Frames.main.width == 1180 and TB.Frames.main.height == 720, "main window did not use approved larger layout")
assert(table.getn(TB.Frames.resultRows) == 10, "Browse did not create ten rows")
assert(table.getn(TB.Frames.myListingRows) == 9, "My Listings did not create nine rows")
assert(table.getn(TB.Frames.professionRows) == 10, "Professions did not create ten rows")
assert(table.getn(TB.Frames.worldLogRows) == 10, "World Trade did not create ten rows")
assert(TB.Frames.browseScrollbar and TB.Frames.worldScrollbar and TB.Frames.professionScrollbar, "classic scrollbars were not created")
assert(TB.Frames.tabs.Wanted and TB.Frames.settingsButton and TB.Frames.minimizeButton, "Wanted/settings/minimize controls were not created")
assert(not TB.Frames.main.clampedToScreen, "main window is still clamped and cannot be parked out of frame")

-- Compact mode must leave a draggable title bar and restore the full layout.
TB.Frames.main:Show()
TB:SetMinimized(1)
assert(TB.Frames.main:GetWidth() == 420 and TB.Frames.main:GetHeight() == 64 and not TB.Frames.content:IsShown(), "minimize did not collapse to its title bar")
TB:SetMinimized(nil)
assert(TB.Frames.main:GetWidth() == 1180 and TB.Frames.main:GetHeight() == 720 and TB.Frames.content:IsShown(), "restore did not return the approved full layout")

local function click(button)
    assert(button:IsShown() and button.enabled, "cannot click hidden or disabled button")
    fire(button, "OnClick", "LeftButton")
end
local function choose(dropdown, value)
    click(dropdown)
    assert(dropdown.menu:IsShown(), "dropdown menu did not open")
    local i
    for i = 1, table.getn(dropdown.options) do
        if dropdown.options[i].value == value then
            click(dropdown.options[i])
            assert(not dropdown.menu:IsShown() and dropdown.value == value, "dropdown selection did not close/apply")
            return
        end
    end
    error("dropdown option missing: " .. tostring(value))
end
local function findRow(rows, field, predicate)
    local i
    for i = 1, table.getn(rows) do
        if rows[i][field] and predicate(rows[i][field]) then return rows[i] end
    end
    error("expected visible row missing")
end

-- Single-line mockup layout: every direct label/control must fit without overlap.
local filterBar = TB.Frames.browseFilterBar
local controls = {
    TB.Frames.searchField, TB.Frames.levelDropdown, TB.Frames.minLevel,
    TB.Frames.maxLevel, TB.Frames.rarityDropdown, TB.Frames.listingTypeDropdown,
    TB.Frames.onlineCheck, TB.Frames.clearFilters,
}
local intervals = {}
local function recordInterval(object, label)
    local point = object.points.LEFT or object.points.RIGHT
    assert(point and point.relative == filterBar and point.y == 0, label .. " is not centered in the single filter row")
    local left = point.relativePoint == "RIGHT" and filterBar:GetWidth() + point.x - object:GetWidth() or point.x
    assert(left >= 0 and left + object:GetWidth() <= filterBar:GetWidth(), label .. " leaves the filter bar")
    assert(object:GetHeight() <= filterBar:GetHeight(), label .. " is taller than the filter bar")
    table.insert(intervals, { left = left, right = left + object:GetWidth(), object = object, label = label })
end
local i
for i = 1, table.getn(controls) do recordInterval(controls[i], "filter control " .. i) end
for i = 1, table.getn(objects) do
    local object = objects[i]
    if object.parent == filterBar and object.frameType == "FontString" and object ~= TB.Frames.searchPlaceholder then
        recordInterval(object, object:GetText())
    end
end
table.sort(intervals, function(a, b) return a.left < b.left end)
for i = 2, table.getn(intervals) do
    assert(intervals[i].left >= intervals[i - 1].right, intervals[i - 1].label .. " overlaps " .. intervals[i].label)
end
assert(filterBar:GetHeight() == 42, "filter row grew beyond the approved compact layout")

local link = "|cff1eff00|Hitem:2589:0:0:0|h[Linen Cloth]|h|r"
local mailLink = "|cff1eff00|Hitem:3302:0:0:0|h[Brackwater Boots]|h|r"
local ringLink = "|cff0070dd|Hitem:9991:0:0:0|h[Test Rare Ring]|h|r"
local function listing(id, itemLink, trader, level, price, orderType)
    return { id = id, owner = trader, trader = trader, itemLink = itemLink, name = TB:ExtractItemName(itemLink), quantity = 1,
        totalPrice = price, traderLevel = level, class = "", guild = "Guild", orderType = orderType or "SELL",
        quality = 2, category = "Miscellaneous", tags = {}, online = 1, lastSeen = GetTime(), lastSeenAt = time() }
end
TB.Listings = {
    listing("one", link, "Seller", 30, 20000),
    listing("mail", mailLink, "UnknownSeller", 0, 30000),
    listing("ring", ringLink, "RingSeller", 0, 40000, "BUY"),
}
TB.Listings[1].quantity = 20
TB:RebuildListingIndex()
TB:UpdateBrowse()
local knownRow = findRow(TB.Frames.resultRows, "listing", function(value) return value.id == "one" end)
assert(knownRow.price:GetText() == "2g 0s 0c", "Browse did not display total price")
assert(not knownRow.whoButton:IsShown(), "Browse offered Who when seller level was already known")

TB.MyListings = { TB.Listings[1] }
TB:UpdateMyListings()
assert(TB.Frames.myListingRows[1].price:GetText() == "2g 0s 0c", "My Listings did not display total price")

choose(TB.Frames.listingTypeDropdown, "BUY")
assert(table.getn(TB:GetFilteredListings()) == 1 and TB.Frames.resultRows[1].listing.id == "ring", "Wanted dropdown did not filter Browse")
choose(TB.Frames.listingTypeDropdown, "ALL")
choose(TB.Frames.rarityDropdown, 3)
assert(table.getn(TB:GetFilteredListings()) == 1 and TB.Frames.resultRows[1].listing.id == "ring", "Rare dropdown did not filter Browse")
choose(TB.Frames.rarityDropdown, "ALL")
choose(TB.Frames.levelDropdown, "required")
TB.Frames.minLevel:SetText("9"); TB.Frames.maxLevel:SetText("12"); fire(TB.Frames.maxLevel, "OnEnterPressed")
assert(table.getn(TB:GetFilteredListings()) == 1 and TB.Frames.resultRows[1].listing.id == "mail", "Required Min/Max did not use item requirement")
choose(TB.Frames.levelDropdown, "all")
assert(table.getn(TB:GetFilteredListings()) == 3, "All level mode still applied stale Min/Max bounds")
assert(not TB.Frames.minLevel.keyboardEnabled and not TB.Frames.maxLevel.mouseEnabled, "All level mode left irrelevant bounds enabled")
choose(TB.Frames.levelDropdown, "range")
assert(TB.State.myLevelRange and TB.Frames.levelDropdown.value == "range", "My range dropdown did not set its filter")
click(TB.Frames.clearFilters)

-- Exercise actual sidebar clicks, including metadata repaired before filtering.
local armorButton = findRow(TB.Frames.categoryButtons, "categoryEntry", function(value) return value.name == "Armor" end)
click(armorButton)
local mailButton = findRow(TB.Frames.categoryButtons, "categoryEntry", function(value) return value.name == "Mail" end)
click(mailButton)
assert(TB.State.category == "Armor" and TB.State.subCategory == "Mail", "sidebar clicks did not select Armor > Mail")
assert(table.getn(TB:GetFilteredListings()) == 1 and TB.Frames.resultRows[1].listing.id == "mail", "Armor > Mail omitted the mail listing")
TB.Frames.searchField:SetText("mail"); choose(TB.Frames.rarityDropdown, 3); choose(TB.Frames.listingTypeDropdown, "BUY")
TB.Frames.minLevel:SetText("40"); TB.Frames.maxLevel:SetText("50")
click(TB.Frames.levelDropdown)
click(TB.Frames.rarityDropdown)
assert(not TB.Frames.levelDropdown.menu:IsShown(), "opening another dropdown left overlapping menus open")
click(TB.Frames.clearFilters)
assert(TB.State.category == "All Items" and not TB.State.subCategory and not TB.State.myLevelRange, "Clear did not reset category/level selection")
assert(TB.Frames.searchField:GetText() == "" and TB.Frames.minLevel:GetText() == "" and TB.Frames.maxLevel:GetText() == "", "Clear did not clear text filters")
assert(TB.Frames.levelDropdown.value == "all" and TB.Frames.rarityDropdown.value == "ALL" and TB.Frames.listingTypeDropdown.value == "ALL", "Clear did not synchronize dropdown labels")
assert(not TB.Frames.onlineCheck.checked and not TB.Frames.rarityDropdown.menu:IsShown() and table.getn(TB:GetFilteredListings()) == 3, "Clear did not restore all listings")

TB.Services = {
    { owner = "Crafter", trader = "Crafter", guild = "Crafters", profession = "Enchanting", rank = 300, maxRank = 300, note = "Crusader", source = "CHAT", level = 60, class = "Priest", online = 1 },
    { owner = "UnknownSeller", trader = "UnknownSeller", guild = "Crafters", profession = "Alchemy", rank = 0, maxRank = 0, note = "Transmute", source = "CHAT", level = 0, online = 1 },
}
TB:RebuildServiceIndex()
TB:UpdateProfessions()
local knownCrafter = findRow(TB.Frames.professionRows, "service", function(value) return value.trader == "Crafter" end)
assert(knownCrafter.source:GetText() == "Chat" and not knownCrafter.whoButton:IsShown(), "known Chat crafter did not hide Who")

TB.Chains = { TB:BuildChainFromSaved({ name = "Test Chain", members = { "Tester" } }, "Tester", 1) }
TB.State.selectedChain = 1
TB:UpdateTradeChains()
assert(not TB.Frames.chainWhoButton:IsShown(), "own-character Trade Chain Who button should be hidden")

TradeBoardDB = { worldLog = {}, worldPeople = {} }
TB.WorldLog = TradeBoardDB.worldLog
TB:CaptureWorldMessage("WTS " .. link .. " 2g", "Seller", "World")
TB:CaptureWorldMessage("WTS " .. mailLink .. " 3g", "UnknownSeller", "World")
TB:UpdateWorldLog()
local knownWorld = findRow(TB.Frames.worldLogRows, "entry", function(value) return value.sender == "Seller" end)
assert(not knownWorld.whoButton:IsShown(), "World ignored seller level already available in Browse")
TB:UpdateBrowse()
local unknownBrowse = findRow(TB.Frames.resultRows, "listing", function(value) return value.id == "mail" end)
local unknownRing = findRow(TB.Frames.resultRows, "listing", function(value) return value.id == "ring" end)
local unknownWorld = findRow(TB.Frames.worldLogRows, "entry", function(value) return value.sender == "UnknownSeller" end)
local unknownProfession = findRow(TB.Frames.professionRows, "service", function(value) return value.trader == "UnknownSeller" end)
local function assertUnknownButtons(text, enabled)
    local buttons = { unknownBrowse.whoButton, unknownRing.whoButton, unknownWorld.whoButton, unknownProfession.whoButton }
    local index
    for index = 1, table.getn(buttons) do
        assert(buttons[index]:IsShown() and buttons[index].label:GetText() == text and buttons[index].enabled == enabled, "Who countdown is not shared across Browse/World/Professions")
    end
end
assertUnknownButtons("?", true)
click(unknownBrowse.whoButton)
assert(table.getn(whoQueries) == 1 and whoQueries[1] == 'n-"UnknownSeller"', "Browse Who did not request the correct character")
assertUnknownButtons("30", false)
assert(not TB:RequestManualWho("RingSeller") and table.getn(whoQueries) == 1, "cooldown allowed a second server query")
now = 1017
fire(TB.Frames.main, "OnUpdate")
assertUnknownButtons("13", false)
click(TB.Frames.tabs["World Trade"])
assert(unknownWorld.whoButton.label:GetText() == "13", "tab switch reset the shared cooldown")
click(TB.Frames.tabs["Professions"])
assert(unknownProfession.whoButton.label:GetText() == "13", "Professions tab lost the active countdown")
now = 1030
fire(TB.Frames.main, "OnUpdate")
assertUnknownButtons("?", true)
click(unknownWorld.whoButton)
assert(table.getn(whoQueries) == 2, "Who was not reusable after thirty seconds")
TB:RememberWorldPerson("UnknownSeller", "Verified Guild", 42, "Mage", time())
TB:UpdateBrowse(); TB:UpdateWorldLog(); TB:UpdateProfessions(); TB:RefreshWhoButtons()
assert(not unknownBrowse.whoButton:IsShown() and not unknownWorld.whoButton:IsShown() and not unknownProfession.whoButton:IsShown(), "resolved Who information did not hide buttons across tabs")
assert(unknownRing.whoButton:IsShown() and unknownRing.whoButton.label:GetText() == "30" and not unknownRing.whoButton.enabled, "another seller lost the shared cooldown when a Who response arrived")
assert(findRow(TB.Frames.resultRows, "listing", function(value) return value.id == "mail" end).listing.traderLevel == 42, "Who identity update removed or failed to enrich Browse listing")

-- Settings, subscriptions and delivery tracking are account-wide and peer-safe.
TB:InitializeFeatureData()
click(TB.Frames.settingsButton)
assert(TB.Frames.settingsPanel:IsShown(), "gear button did not open settings")
TB:SetLootMute("Guild", 300)
TB:SetLootMute("Public", 600)
assert(TB:GetLootMuteLabel("Guild") == "Muted 5m" and TB:GetLootMuteLabel("World") == "Muted 10m", "source-specific popup timers were not stored")
TB:SetLootMute("Guild", 0); TB:SetLootMute("Public", 0)
click(TB.Frames.tabs.Wanted)
local wanted = assert(TB:AddWanted(mailLink))
assert(TB.Frames.wantedRows[1]:IsShown() and TB.Frames.wantedRows[1].name:GetText() == mailLink, "Wanted subscription was not rendered")
TB:ClearGuildLoot()
TB:CaptureWorldMessage("WTS " .. mailLink .. " 3g", "WantedSeller", "World")
assert(TB.GuildLoot.active and TB.GuildLoot.active.kind == "WANTED" and TB.GuildLoot.active.wanted == wanted.name, "matching World WTS did not open a Wanted alert")
TB:ClearGuildLoot(); TB:SetLootMute("Public", 300)
TB:CheckWantedEntry({ id = "muted-match", type = "WTS", channel = "World", sender = "MutedSeller", message = "WTS " .. mailLink, items = { mailLink } })
assert(not TB.GuildLoot.active, "public mute did not suppress Wanted popup")
TB:SetLootMute("Public", 0)
TB:RemoveWanted(wanted.id)

TB:SetChainVolunteer(1)
local ownVolunteer = TB:GetOwnVolunteer()
assert(ownVolunteer and ownVolunteer.enabled and ownVolunteer.low == 25 and ownVolunteer.high == 35, "trade-chain volunteer range was not current level +/-5")
local order = assert(TB:CreateChainOrder("ChainOwner", mailLink, 4, "Tester", "Mule", "bank handoff"))
assert(order.status == "REQUESTED" and order.quantity == 4 and order.fromName == "Tester" and order.toName == "Mule", "delivery order lost its route fields")
TB:AdvanceChainOrder(order); assert(order.status == "PICKED UP", "delivery order did not advance to picked up")
TB:AdvanceChainOrder(order); assert(order.status == "DELIVERED", "delivery order did not advance to delivered")
TB:OpenDeliveryDesk()
assert(TB.Frames.deliveryDesk:IsShown() and TB.Frames.orderRows[1]:IsShown(), "delivery desk did not show tracked orders")
local remoteOrder = TB.PROTOCOL .. "~O~remote-order~ChainOwner~RemoteBuyer~Copper Bar~2~Banker~Carrier~meet SW~REQUESTED~" .. tostring(TB:GetWallTime()) .. "~RemoteBuyer"
TB:HandleProtocolMessage(remoteOrder, "RemoteBuyer")
assert(table.getn(TB.ChainOrders) == 2, "peer delivery order was not accepted")
TB.Frames.deliveryDesk:Hide(); TB.Frames.settingsPanel:Hide()

-- World message text and link hitboxes must stay inside their bordered rows.
local function assertWorldMessageLayout(row)
    local function top(object)
        if object == row then return 0 end
        local point = object.points.TOPLEFT or object.points.TOPRIGHT or object.points.LEFT
        assert(point, "World row control has no recorded anchor")
        if point.point == "LEFT" then
            return top(point.relative) + (point.relative:GetHeight() - object:GetHeight()) / 2 - point.y
        end
        assert(point.relativePoint == "TOPLEFT" or point.relativePoint == "TOPRIGHT", "unexpected World row top anchor")
        return top(point.relative) - point.y
    end
    local headerBottom = 0
    local header = { row.metaPrefix, row.senderButton, row.whoButton, row.level, row.class, row.guildButton, row.source }
    local index
    for index = 1, table.getn(header) do
        local object = header[index]
        if object:IsShown() then headerBottom = math.max(headerBottom, top(object) + object:GetHeight()) end
    end
    local previous, usedWidth, visibleCount = nil, 0, 0
    for index = 1, table.getn(row.messageParts) do
        local part = row.messageParts[index]
        if part:IsShown() then
            visibleCount = visibleCount + 1
            assert(top(part) >= headerBottom, "World message overlaps its seller/header line")
            assert(row:GetHeight() - top(part) - part:GetHeight() >= 4, "World message text/link hitbox crosses the bottom border or lacks padding")
            if previous then
                local point = part.points.LEFT
                assert(point and point.relative == previous and point.relativePoint == "RIGHT" and point.x == 0 and point.y == 0,
                    "World inline text and item links are not adjacent")
                assert(part:GetHeight() == previous:GetHeight(), "World message segments have mismatched line heights")
            else
                assert(part.points.TOPLEFT.relative == row and part.points.TOPLEFT.x == 7, "World message lost its left padding")
            end
            assert(part.text.points.TOPLEFT.relative == part and part.text.points.BOTTOMRIGHT.relative == part,
                "World message font no longer fits its clickable segment")
            assert(part.text.justifyV == "MIDDLE", "World message text is not vertically centered within its segment")
            usedWidth = usedWidth + part:GetWidth()
            assert(7 + usedWidth <= row:GetWidth() - 7, "World message overflowed the right border")
            previous = part
        else
            assert(not part.itemLink, "hidden/reused World message segment retained a clickable item")
        end
    end
    assert(visibleCount > 0, "World message has no visible segments")
    return usedWidth, visibleCount
end
for i = 1, table.getn(TB.Frames.worldLogRows) do
    if TB.Frames.worldLogRows[i].entry then assertWorldMessageLayout(TB.Frames.worldLogRows[i]) end
end
local savedWorldLog = TB.WorldLog
local reusedWorldRow = TB.Frames.worldLogRows[1]
TB.WorldLog = { { sender = "LongSeller", channel = "World", type = "WTS", timestamp = time(), level = 0,
    message = "WTS " .. link .. " " .. mailLink .. " " .. ringLink .. " " .. string.rep("long offer ", 200) .. link } }
TB:UpdateWorldLog()
local longWidth, longParts = assertWorldMessageLayout(reusedWorldRow)
assert(longWidth == 1082 and longParts > 3, "long World offer did not exercise clipped multi-link segments")
fire(reusedWorldRow.messageParts[2], "OnEnter")
assert(GameTooltip:IsShown() and GameTooltip.hyperlink == "item:2589:0:0:0", "World inline item lost its hover tooltip")
click(reusedWorldRow.messageParts[2])
assert(openedItem == "item:2589:0:0:0", "World inline item click did not open the item")
fire(reusedWorldRow.messageParts[2], "OnLeave")
assert(not GameTooltip:IsShown(), "World inline item tooltip did not close")
TB.WorldLog = { { sender = "ShortSeller", channel = "Trade", type = "WTS", timestamp = time(), level = 30,
    message = "WTS " .. mailLink .. " 3g" } }
TB:UpdateWorldLog()
assert(TB.Frames.worldLogRows[1] == reusedWorldRow and reusedWorldRow.entry.sender == "ShortSeller", "World message frame was not reused")
local shortWidth, shortParts = assertWorldMessageLayout(reusedWorldRow)
assert(shortWidth < longWidth and shortParts == 3, "short reused World row retained long message segments")
fire(reusedWorldRow.messageParts[2], "OnEnter")
assert(GameTooltip.hyperlink == "item:3302:0:0:0", "reused World item tooltip retained the previous seller's item")
click(reusedWorldRow.messageParts[2])
assert(openedItem == "item:3302:0:0:0", "reused World item click retained the previous seller's item")
click(reusedWorldRow.messageParts[3])
assert(openedItem == "item:3302:0:0:0", "plain World message text unexpectedly opened an item")
fire(reusedWorldRow.messageParts[2], "OnLeave")
TB.WorldLog = savedWorldLog
TB:UpdateWorldLog()

-- Guild notifications construct real popup controls and preserve their actions.
local queuedBeforeGuild = table.getn(TB.SendQueue or {})
TB:CaptureGuildLootMessage("Anyone need anything? " .. link .. mailLink, "Frank")
TB:CaptureGuildLootMessage(ringLink, "Frank")
local guildPopup = TB.GuildLoot.frame
assert(guildPopup and guildPopup:IsShown() and guildPopup:GetWidth() == 330 and guildPopup:GetHeight() == 337, "guild offer did not open its loot-sized popup")
assert(TB.GuildLoot.active.sender == "Frank" and table.getn(TB.GuildLoot.active.links) == 3, "linked guild follow-up items did not join the offer")
assert(guildPopup.muteDuration.seconds == 600 and guildPopup.mute:GetText() == "Mute Guild", "guild popup mute controls were not initialized")
assert(guildPopup.rows[1].itemLink == link and guildPopup.rows[3].itemLink == ringLink and not guildPopup.rows[4]:IsShown(), "guild popup item rows were incorrect")
fire(guildPopup.rows[1], "OnEnter")
assert(GameTooltip.hyperlink == "item:2589:0:0:0", "guild loot item did not show its tooltip")
click(guildPopup.rows[1])
assert(openedItem == "item:2589:0:0:0", "guild loot item click did not open the item")
click(guildPopup.whisper)
assert(openedChat == "/w Frank ", "guild popup whisper targeted the wrong character")
assert(table.getn(TB.SendQueue or {}) == queuedBeforeGuild, "guild popup created peer/chat traffic")
click(guildPopup.dismiss)
assert(not guildPopup:IsShown() and not TB.GuildLoot.active, "guild popup did not dismiss")

-- The popup can mute its own source using the same account-wide timer as Settings.
TB:CaptureLootMessage("free " .. link, "WorldSeller", "World", 4)
TB:CaptureGuildLootMessage("free " .. mailLink, "GuildSeller2")
fire(guildPopup.muteDuration.options[1], "OnClick")
assert(guildPopup.muteDuration.seconds == 300 and TradeBoardDB.popupMuteSeconds == 300, "popup mute duration was not selected or saved")
click(guildPopup.mute)
assert(not TB:IsLootSourceEnabled("World") and TB.GuildLoot.active and TB.GuildLoot.active.channel == "Guild", "popup mute did not isolate World/Trade from Guild")
assert(guildPopup.mute:GetText() == "Mute Guild", "popup mute button did not follow the next popup source")
click(guildPopup.dismiss)
TB:SetLootMute("Public", 0)

-- Memory labels distinguish addon measurements from the shared Vanilla heap,
-- and sampling must stay throttled even when the window is reopened.
local memoryUpdates, totalReads = 0, 0
function UpdateAddOnMemoryUsage() memoryUpdates = memoryUpdates + 1 end
function GetAddOnMemoryUsage(name)
    assert(name == "HC-Tradeboard", "memory lookup targeted a different addon")
    return 2560
end
function gcinfo() totalReads = totalReads + 1; return 20480, 40960 end
TB.memorySample = nil; TB.nextMemorySampleAt = nil
TB.Frames.main:Hide()
fire(TB.Frames.main, "OnUpdate")
assert(memoryUpdates == 0 and totalReads == 0, "closed board sampled memory")
TB.Frames.main:Show()
fire(TB.Frames.main, "OnUpdate")
assert(TB.Frames.memoryLabel:GetText() == "Addon: 2.50 MB" and totalReads == 0, "addon KB were not converted to MB or scope was wrong")
for i = 1, 20 do fire(TB.Frames.main, "OnUpdate") end
TB.Frames.main:Hide(); TB.Frames.main:Show()
fire(TB.Frames.main, "OnUpdate")
assert(memoryUpdates == 1, "frame updates or reopening bypassed memory sampling throttle")
function GetAddOnMemoryUsage() error("unsupported profiler") end
now = now + 30
fire(TB.Frames.main, "OnUpdate")
assert(TB.Frames.memoryLabel:GetText() == "Lua total: 20.00 MB" and totalReads == 1, "failed client profiler did not fall back to clearly labelled total Lua memory")
UpdateAddOnMemoryUsage = nil; GetAddOnMemoryUsage = nil
now = now + 30
fire(TB.Frames.main, "OnUpdate")
assert(TB.memorySample.scope == "lua" and totalReads == 2, "stock Vanilla gcinfo memory read failed")
fire(TB.Frames.memoryUsage, "OnEnter")
assert(GameTooltip:IsShown() and GameTooltip:GetText() == "HC TradeBoard memory", "memory label did not show its explanation tooltip")
fire(TB.Frames.memoryUsage, "OnLeave")
assert(not GameTooltip:IsShown(), "memory tooltip did not close")
gcinfo = nil
now = now + 30
fire(TB.Frames.main, "OnUpdate")
assert(TB.Frames.memoryLabel:GetText() == "Memory: unavailable", "missing memory APIs displayed a fabricated value")
TB.Frames.main:Hide()

if arg and arg[1] == "--preview" then
    local function xml(value)
        local result = plainText(value)
        result = string.gsub(result, "&", "&amp;"); result = string.gsub(result, "<", "&lt;"); result = string.gsub(result, ">", "&gt;")
        return result
    end
    local function color(value, fallback)
        if not value then return fallback end
        return string.format("#%02x%02x%02x", math.floor(value[1] * 255), math.floor(value[2] * 255), math.floor(value[3] * 255))
    end
    print("FILTER_PREVIEW_BEGIN")
    print('<svg xmlns="http://www.w3.org/2000/svg" width="1180" height="130" viewBox="0 0 1180 130">')
    print('<rect width="1180" height="130" fill="#11100c"/><text x="16" y="25" fill="#d9b85c" font-size="16" font-family="serif">HC TradeBoard - actual Lua filter geometry</text>')
    print('<rect x="16" y="44" width="1148" height="42" rx="3" fill="#070706" stroke="#816b36"/>')
    for i = 1, table.getn(intervals) do
        local interval, object = intervals[i], intervals[i].object
        local x, width = 16 + interval.left, interval.right - interval.left
        if object == TB.Frames.onlineCheck then
            print('<rect x="' .. (x + 3) .. '" y="56" width="18" height="18" rx="2" fill="#0d0d0b" stroke="#8b713b"/>')
            if object.checked then print('<path d="M' .. (x + 5) .. ' 64 l4 4 l10 -12" stroke="#dfbd3e" fill="none" stroke-width="3"/>') end
        elseif object.frameType ~= "FontString" then
            print('<rect x="' .. x .. '" y="51" width="' .. width .. '" height="28" rx="3" fill="' .. color(object.backdropColor, "#161510") .. '" stroke="' .. color(object.borderColor, "#8b713b") .. '"/>')
        end
        local label = object.label and object.label:GetText() or object:GetText()
        if object == TB.Frames.searchField then label = "Search items..." end
        local textX, anchor = x + 8, "start"
        if object.frameType == "FontString" then textX = x
        elseif object == TB.Frames.onlineCheck then textX = x + 26
        elseif object == TB.Frames.clearFilters then textX = x + width / 2; anchor = "middle" end
        print('<text x="' .. textX .. '" y="69" text-anchor="' .. anchor .. '" fill="#d9c990" font-size="12" font-family="Arial">' .. xml(label) .. '</text>')
        if object.options then print('<path d="M' .. (x + width - 18) .. ' 61 h10 l-5 7z" fill="#d6ad35"/>') end
    end
    print('<text x="16" y="113" fill="#aaa28d" font-size="11" font-family="Arial">Geometry preview only; WoW supplies the final fonts and textures.</text></svg>')
    print("FILTER_PREVIEW_END")
end

print("HC TradeBoard UI smoke test passed: dropdowns, filter geometry, Mail category, shared Who cooldown, identity, World message bounds/link reuse, guild loot popup and memory label")
