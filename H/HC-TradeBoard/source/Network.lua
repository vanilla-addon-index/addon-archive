local TB = TradeBoard

local QUESTION_TEXTURE = "Interface\\Icons\\INV_Misc_QuestionMark"
-- The 1.12 custom channel is the only peer transport available across guilds.
-- Keep it deliberately slow so ordinary player chat always wins the throttle.
local SEND_DELAY = 5.0
local WORLD_SEND_DELAY = 20.0
local MAX_SEND_QUEUE = 80
local MAX_SENDS_PER_MINUTE = 8

local function LowerName(name)
    return string.lower(name or "")
end

local function SplitMessage(message)
    local fields = {}
    local value
    for value in string.gfind((message or "") .. "~", "(.-)~") do
        table.insert(fields, value)
    end
    return fields
end

local function CopyTags(tags)
    local result = {}
    local key, value
    if tags then
        for key, value in pairs(tags) do
            result[key] = value
        end
    end
    return result
end

function TB:EscapeProtocol(text)
    text = tostring(text or "")
    text = string.gsub(text, "%%", "%%25")
    text = string.gsub(text, "~", "%%7E")
    text = string.gsub(text, "|", "%%7C")
    return text
end

function TB:UnescapeProtocol(text)
    text = tostring(text or "")
    text = string.gsub(text, "%%7C", "|")
    text = string.gsub(text, "%%7E", "~")
    text = string.gsub(text, "%%25", "%%")
    return text
end

function TB:GetListingKey(owner, id)
    return LowerName(owner) .. "~" .. tostring(id or "")
end

function TB:RebuildListingIndex()
    self.ListingIndex = {}
    local i
    for i = 1, table.getn(self.Listings) do
        local listing = self.Listings[i]
        self.ListingIndex[self:GetListingKey(listing.owner, listing.id)] = i
    end
end

function TB:UpsertListing(listing)
    self:RefreshListingMetadata(listing)
    local key = self:GetListingKey(listing.owner, listing.id)
    local index = self.ListingIndex[key]
    if index then
        self.Listings[index] = listing
    else
        table.insert(self.Listings, listing)
    end
    self:RebuildListingIndex()
end

function TB:RemoveListing(owner, id)
    local key = self:GetListingKey(owner, id)
    local index = self.ListingIndex[key]
    if not index then
        return nil
    end
    local removed = self.Listings[index]
    table.remove(self.Listings, index)
    self:RebuildListingIndex()
    if self.State.selectedListing == removed then
        self.State.selectedListing = nil
    end
    return removed
end

function TB:ExtractItemName(link)
    local _, _, name = string.find(link or "", "%[(.-)%]")
    return name or "Unknown Item"
end

function TB:ExtractItemID(link)
    local _, _, itemID = string.find(link or "", "item:(%d+)")
    return tonumber(itemID)
end

function TB:ExtractItemKey(link)
    local _, _, itemKey = string.find(link or "", "|Hitem:([^|]+)|h")
    return itemKey
end

function TB:GetItemMetadata(link)
    if not link or not GetItemInfo then return nil end
    local _, _, itemString = string.find(link, "|H([^|]+)|h")
    itemString = itemString or link
    if not self.ItemMetadataCache or (self.ItemMetadataCacheCount or 0) >= 1000 then
        self.ItemMetadataCache = {}; self.ItemMetadataCacheCount = 0
    end
    local saved = self.ItemMetadataCache[itemString]
    if saved and saved.retryAt then
        if GetTime() < saved.retryAt then return nil end
        self.ItemMetadataCache[itemString] = nil
        self.ItemMetadataCacheCount = math.max(0, (self.ItemMetadataCacheCount or 0) - 1)
        saved = nil
    end
    if saved then
        if string.find(link, "|Hitem:", 1, 1) then saved.itemLink = link end
        return saved
    end
    local name, itemLink, quality, fourth, fifth, sixth, seventh, eighth, ninth, tenth = GetItemInfo(itemString)
    if not name then
        local itemID = self:ExtractItemID(link)
        if itemID then
            name, itemLink, quality, fourth, fifth, sixth, seventh, eighth, ninth, tenth = GetItemInfo(itemID)
        end
    end
    if not name then
        -- Filters and duplicated chat links can request the same cache miss
        -- repeatedly. Retry on a later refresh, at most once per two seconds.
        self.ItemMetadataCache[itemString] = { retryAt = GetTime() + 2 }
        self.ItemMetadataCacheCount = (self.ItemMetadataCacheCount or 0) + 1
        return nil
    end
    local data = { name = name, quality = self:NormalizeQuality(quality), itemLink = itemLink }
    -- 1.12 has nine returns: field 4 is required level, field 5 is item type.
    -- Newer clients insert item level at field 4. Detect the tuple, not build IDs,
    -- since client extensions can provide either shape.
    if type(fifth) == "string" then
        data.requiredLevel = tonumber(fourth) or 0
        data.itemType = fifth; data.subType = sixth; data.maxStack = seventh
        data.equipLocation = eighth; data.texture = ninth
    else
        data.itemLevel = tonumber(fourth)
        data.requiredLevel = tonumber(fifth) or 0
        data.itemType = sixth; data.subType = seventh; data.maxStack = eighth
        data.equipLocation = ninth; data.texture = tenth
    end
    data.category = self:GetItemCategory(data.itemType)
    data.tags = self:GetItemTags(data.category, data.subType)
    -- Full incoming links preserve random suffixes and stay clickable on 1.12,
    -- whose second return is commonly an unformatted item string.
    if string.find(link, "|Hitem:", 1, 1) then data.itemLink = link end
    if not data.itemType or not data.subType then return nil end
    self.ItemMetadataCache[itemString] = data
    self.ItemMetadataCacheCount = (self.ItemMetadataCacheCount or 0) + 1
    return data
end

function TB:RefreshListingMetadata(listing)
    if not listing then return nil end
    local data = self:GetItemMetadata(listing.itemLink)
    if not data then return nil end
    listing.name = data.name
    if not string.find(listing.itemLink or "", "|Hitem:", 1, 1) then listing.itemLink = data.itemLink or listing.itemLink end
    listing.texture = data.texture or listing.texture
    listing.quality = data.quality
    listing.requiredLevel = data.requiredLevel
    -- Old saved 1.12 rows put minimum level in itemLevel; do not retain that
    -- misleading value when this client cannot provide actual item level.
    listing.itemLevel = data.itemLevel or 0
    listing.itemType = data.itemType; listing.subType = data.subType
    listing.category = data.category; listing.tags = CopyTags(data.tags)
    return 1
end

function TB:CountItemInBags(itemLink)
    local total = 0
    local itemKey = self:ExtractItemKey(itemLink)
    local bag, slot
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link and self:ExtractItemKey(link) == itemKey then
                local texture, count = GetContainerItemInfo(bag, slot)
                total = total + (count or 1)
            end
        end
    end
    return total
end

function TB:GetItemCategory(itemType)
    if itemType == "Weapon" then
        return "Weapons"
    elseif itemType == "Armor" then
        return "Armor"
    elseif itemType == "Container" then
        return "Containers"
    elseif itemType == "Consumable" then
        return "Consumables"
    elseif itemType == "Trade Goods" then
        return "Trade Goods"
    elseif itemType == "Recipe" then
        return "Recipes"
    elseif itemType == "Projectile" then
        return "Projectiles"
    elseif itemType == "Quiver" then
        return "Quivers"
    end
    return "Miscellaneous"
end

function TB:GetItemTags(category, subType)
    local tags = {}
    subType = subType or ""

    if category == "Armor" then
        if subType == "Cloth" or subType == "Leather" or subType == "Mail" or subType == "Plate" then
            tags[subType] = 1
        elseif string.find(subType, "Shield") then
            tags.Shields = 1
        end
    elseif category == "Weapons" then
        if string.find(subType, "Two%-Handed") or subType == "Staves" or subType == "Polearms" then
            tags["2H"] = 1
        elseif not string.find(subType, "Bow") and not string.find(subType, "Gun") and not string.find(subType, "Crossbow") and not string.find(subType, "Wand") then
            tags["1H"] = 1
        end

        if string.find(subType, "Sword") then
            tags.Swords = 1
        elseif string.find(subType, "Axe") then
            tags.Axe = 1
        elseif string.find(subType, "Mace") then
            tags.Maces = 1
        elseif string.find(subType, "Dagger") then
            tags.Daggers = 1
        elseif string.find(subType, "Stav") then
            tags.Staves = 1
        elseif string.find(subType, "Fist") then
            tags.Fists = 1
        elseif string.find(subType, "Bow") or string.find(subType, "Gun") or string.find(subType, "Crossbow") then
            tags.Ranged = 1
        end
    end
    return tags
end

function TB:ParseChatQuantity(message)
    local _, _, amount = string.find(message or "", "[xX](%d+)")
    if not amount then _, _, amount = string.find(message or "", "(%d+)%s*[xX]") end
    amount = tonumber(amount) or 1
    if amount < 1 then amount = 1 elseif amount > 1000 then amount = 1000 end
    return amount
end

function TB:ParseChatPrice(message, quantity)
    local lower = string.lower(message or "")
    local gold, silver, copper = 0, 0, 0
    local _, _, value = string.find(lower, "(%d+%.?%d*)%s*g")
    gold = tonumber(value) or 0
    _, _, value = string.find(lower, "(%d+)%s*s")
    silver = tonumber(value) or 0
    _, _, value = string.find(lower, "(%d+)%s*c")
    copper = tonumber(value) or 0
    local price = math.floor((gold * 10000) + (silver * 100) + copper)
    if price > 0 and (string.find(lower, "each", 1, 1) or string.find(lower, " ea", 1, 1)) then
        price = price * (quantity or 1)
    end
    return price
end

function TB:InferChatProfession(message)
    local lower = string.lower(message or "")
    local rules = {
        { "crusader", "Enchanting" }, { "fiery weapon", "Enchanting" }, { "enchant", "Enchanting" },
        { "arcanite", "Alchemy" }, { "transmute", "Alchemy" }, { "alchemy", "Alchemy" },
        { "mooncloth", "Tailoring" }, { "tailor", "Tailoring" },
        { "blacksmith", "Blacksmithing" }, { "engineering", "Engineering" },
        { "leatherwork", "Leatherworking" }, { "herbal", "Herbalism" },
        { "mining", "Mining" }, { "skinning", "Skinning" }, { "cooking", "Cooking" },
        { "first aid", "First Aid" },
    }
    local i
    for i = 1, table.getn(rules) do if string.find(lower, rules[i][1], 1, 1) then return rules[i][2] end end
    return nil
end

function TB:ImportWorldEntry(entry)
    if not entry or not entry.id then return end
    local person = TradeBoardDB and TradeBoardDB.worldPeople and TradeBoardDB.worldPeople[LowerName(entry.sender)] or nil
    local quantity = self:ParseChatQuantity(entry.message)
    local totalPrice = self:ParseChatPrice(entry.message, quantity)
    local itemExpiresAt = entry.timestamp + (entry.type == "WTS" and self.CHAT_WTS_TTL or self.WORLD_LOG_TTL)
    local itemCount = table.getn(entry.items or {})
    -- The archive outlives WTS items. Login rebuilds and peer snapshots must
    -- not recreate expired Browse offers, while services retain their own TTL.
    if self:GetWallTime() >= itemExpiresAt then itemCount = 0 end
    local i
    for i = 1, itemCount do
        local link = entry.items[i]
        local data = self:GetItemMetadata(link) or {}
        self:UpsertListing({
            id = "chat:" .. entry.id .. ":" .. i, owner = entry.sender, trader = entry.sender,
            guild = entry.guild or (person and person.guild) or "", class = entry.class or (person and person.class) or "",
            itemID = self:ExtractItemID(link), itemLink = data.itemLink or link, name = data.name or self:ExtractItemName(link),
            texture = data.texture or QUESTION_TEXTURE, quality = data.quality or 1,
            requiredLevel = data.requiredLevel or 0, itemLevel = data.itemLevel or 0,
            quantity = quantity, totalPrice = totalPrice, priceKnown = totalPrice > 0 and 1 or nil,
            traderLevel = tonumber(entry.level) or (person and person.level) or 0,
            orderType = entry.type == "WTB" and "BUY" or "SELL", category = data.category or "Miscellaneous",
            tags = CopyTags(data.tags), online = 1, lastSeen = GetTime(),
            lastSeenAt = entry.timestamp, expiresAt = itemExpiresAt,
            source = "CHAT", channel = entry.channel,
        })
    end
    if entry.type ~= "WTB" then
        local profession = self:InferChatProfession(entry.message)
        if profession then
            self:UpsertService({
                owner = entry.sender, trader = entry.sender, guild = entry.guild or (person and person.guild) or "",
                class = entry.class or (person and person.class) or "", level = tonumber(entry.level) or (person and person.level) or 0,
                profession = profession, rank = 0, maxRank = 0, note = entry.message or "",
                online = 1, lastSeen = GetTime(), lastSeenAt = entry.timestamp,
                expiresAt = entry.timestamp + self.WORLD_LOG_TTL, source = "CHAT", channel = entry.channel,
            })
        end
    end
end

function TB:RebuildChatOffers()
    local i
    for i = table.getn(self.Listings), 1, -1 do if self.Listings[i].source == "CHAT" then table.remove(self.Listings, i) end end
    self:RebuildListingIndex()
    for i = table.getn(self.Services), 1, -1 do if self.Services[i].source == "CHAT" then table.remove(self.Services, i) end end
    self:RebuildServiceIndex()
    for i = 1, table.getn(self.WorldLog or {}) do self:ImportWorldEntry(self.WorldLog[i]) end
end

function TB:EncodeTags(tags)
    local order = { "2H", "1H", "Swords", "Axe", "Maces", "Daggers", "Staves", "Fists", "Ranged", "Cloth", "Leather", "Mail", "Plate", "Shields" }
    local parts = {}
    local i
    for i = 1, table.getn(order) do
        if tags and tags[order[i]] then
            table.insert(parts, order[i])
        end
    end
    return table.concat(parts, ",")
end

function TB:DecodeTags(text)
    local tags = {}
    local value
    for value in string.gfind((text or "") .. ",", "(.-),") do
        if value ~= "" then
            if string.sub(value, 1, 6) == "Ranged" then
                tags.Ranged = 1
            else
                tags[value] = 1
            end
        end
    end
    return tags
end

function TB:IsBagItemTradeable(bag, slot)
    if not self.scanTooltip then
        self.scanTooltip = CreateFrame("GameTooltip", "TradeBoardScanTooltip", UIParent, "GameTooltipTemplate")
        self.scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end
    self.scanTooltip:ClearLines()
    self.scanTooltip:SetBagItem(bag, slot)
    local soulboundText = string.upper(ITEM_SOULBOUND or "Soulbound")
    local questText = string.upper(ITEM_BIND_QUEST or "Quest Item")
    local i
    for i = 1, self.scanTooltip:NumLines() do
        local line = getglobal("TradeBoardScanTooltipTextLeft" .. i)
        local text = line and line:GetText()
        if text then
            text = string.upper(text)
            if string.find(text, soulboundText, 1, 1) or string.find(text, questText, 1, 1) then
                return nil
            end
        end
    end
    return 1
end

function TB:BuildBagListingCandidate(bag, slot, quiet)
    local link = GetContainerItemLink(bag, slot)
    local texture, count, locked, bagQuality = GetContainerItemInfo(bag, slot)
    if not link or locked then
        if not quiet then
            self:SetStatus("That bag slot cannot be listed right now.")
        end
        return nil
    end
    if not self:IsBagItemTradeable(bag, slot) then
        if not quiet then
            self:SetStatus("Soulbound and quest items cannot be advertised for trade.")
        end
        return nil
    end

    local data = self:GetItemMetadata(link) or {}
    local itemID = self:ExtractItemID(link)
    local itemKey = self:ExtractItemKey(link)
    local availableQuantity = self:CountItemInBags(link)
    local i
    for i = 1, table.getn(self.MyListings) do
        if self:ExtractItemKey(self.MyListings[i].itemLink) == itemKey then
            availableQuantity = availableQuantity - (self.MyListings[i].quantity or 0)
        end
    end
    if availableQuantity < 0 then
        availableQuantity = 0
    end
    return {
        bag = bag,
        slot = slot,
        itemID = itemID,
        itemKey = itemKey,
        itemLink = data.itemLink or link,
        name = data.name or self:ExtractItemName(link),
        texture = data.texture or texture or QUESTION_TEXTURE,
        quality = data.quality or self:NormalizeQuality(bagQuality or 1),
        itemLevel = data.itemLevel or 0,
        requiredLevel = data.requiredLevel or 0,
        itemType = data.itemType or "",
        subType = data.subType or "",
        category = data.category or "Miscellaneous",
        tags = CopyTags(data.tags),
        availableQuantity = availableQuantity,
        maxStack = data.maxStack or count or 1,
    }
end

function TB:ApplyBagListingCandidate(candidate)
    if not candidate then
        return nil
    end
    local currentLink = GetContainerItemLink(candidate.bag, candidate.slot)
    if not currentLink or self:ExtractItemKey(currentLink) ~= candidate.itemKey then
        self.dragListingCandidate = nil
        self:SetStatus("The dragged item did not return to its original bag slot. Try Shift-clicking it instead.")
        return nil
    end
    self.PendingListing = candidate
    self.bagPickMode = nil
    self.dragListingCandidate = nil
    if self.UpdateListingEditor then
        self:UpdateListingEditor()
    end
    self:SetStatus("Selected " .. self.PendingListing.name .. " from your bags.")
    return 1
end

function TB:SelectBagItem(bag, slot)
    return self:ApplyBagListingCandidate(self:BuildBagListingCandidate(bag, slot, nil))
end

function TB:BeginBagPick()
    self.bagPickMode = 1
    self:SetStatus("Open your bags yourself, then left-click an item. Shift-click also works without activating this mode.")
    if self.UpdateListingEditor then
        self:UpdateListingEditor()
    end
end

function TB:CancelBagPick()
    self.bagPickMode = nil
    self:SetStatus("Bag selection cancelled.")
    if self.UpdateListingEditor then
        self:UpdateListingEditor()
    end
end

function TB:HookBagItemClicks()
    if self.originalContainerClick or not ContainerFrameItemButton_OnClick then
        return
    end
    self.originalContainerClick = ContainerFrameItemButton_OnClick
    ContainerFrameItemButton_OnClick = function(button, ignoreModifiers)
        local tradeBoardOpen = TB.Frames and TB.Frames.main and TB.Frames.main:IsShown()
        if tradeBoardOpen and button == "LeftButton" then
            local bag = this:GetParent():GetID()
            local slot = this:GetID()
            if ignoreModifiers and TB.State.activeTab == "My Listings" then
                TB.dragListingCandidate = TB:BuildBagListingCandidate(bag, slot, 1)
            elseif IsShiftKeyDown() and (not ChatFrameEditBox or not ChatFrameEditBox:IsShown()) then
                TB:SetActiveTab("My Listings")
                TB:SelectBagItem(bag, slot)
                return
            elseif TB.bagPickMode and TB.State.activeTab == "My Listings" then
                TB:SelectBagItem(bag, slot)
                return
            end
        end
        TB.originalContainerClick(button, ignoreModifiers)
    end
end

function TB:SaveMyListings()
    if not TradeBoardDB then
        TradeBoardDB = {}
    end
    local owner = LowerName(UnitName("player"))
    local saved = TradeBoardDB.listings or {}
    local result = {}
    local i
    for i = 1, table.getn(saved) do
        if LowerName(saved[i].owner) ~= owner then
            table.insert(result, saved[i])
        end
    end
    for i = 1, table.getn(self.MyListings) do
        table.insert(result, self.MyListings[i])
    end
    TradeBoardDB.listings = result
end

function TB:RefreshOwnListingLevels(level)
    level = self:SetPlayerLevel(level)
    local changed
    local i
    for i = 1, table.getn(self.MyListings) do
        if self.MyListings[i].traderLevel ~= level then
            self.MyListings[i].traderLevel = level
            changed = 1
        end
    end
    if changed then
        self:SaveMyListings()
    end
    return level
end

function TB:LoadSavedListings()
    self.MyListings = {}
    local saved = TradeBoardDB and TradeBoardDB.listings or {}
    local playerName = UnitName("player") or "Unknown"
    local i
    for i = 1, table.getn(saved) do
        local listing = saved[i]
        if LowerName(listing.owner) == LowerName(playerName) then
            listing.trader = playerName
            listing.traderLevel = self:GetPlayerLevel()
            listing.guild = self:GetPlayerGuildName()
            listing.online = 1
            listing.isMine = 1
            listing.lastSeen = GetTime()
            listing.lastSeenAt = self:GetWallTime()
            listing.tags = CopyTags(listing.tags)
            if listing.tags["Ranged (Bow/Xbow/Gun)"] or listing.tags["Ranged (Box/Xbox/Gun)"] then
                listing.tags.Ranged = 1
            end
            listing.quality = self:NormalizeQuality(listing.quality)
            if listing.totalPrice == nil then listing.totalPrice = (tonumber(listing.unitPrice) or 0) * (tonumber(listing.quantity) or 1) end
            listing.unitPrice = nil
            table.insert(self.MyListings, listing)
            self:UpsertListing(listing)
        end
    end
end

function TB:CreateMyListing(quantity, totalPrice)
    local pending = self.PendingListing
    if not pending then
        self:SetStatus("Choose an item from your bags first.")
        return nil
    end
    local currentLink = GetContainerItemLink(pending.bag, pending.slot)
    if not currentLink or self:ExtractItemKey(currentLink) ~= pending.itemKey then
        self:SetStatus("That item moved. Choose it from your bags again.")
        return nil
    end
    if not self:IsBagItemTradeable(pending.bag, pending.slot) then
        self:SetStatus("That item is no longer tradeable.")
        return nil
    end
    local availableNow = self:CountItemInBags(currentLink)
    local listedIndex
    for listedIndex = 1, table.getn(self.MyListings) do
        if self:ExtractItemKey(self.MyListings[listedIndex].itemLink) == pending.itemKey then
            availableNow = availableNow - (self.MyListings[listedIndex].quantity or 0)
        end
    end
    if availableNow < 0 then
        availableNow = 0
    end
    pending.availableQuantity = availableNow
    quantity = tonumber(quantity) or 0
    totalPrice = tonumber(totalPrice) or 0
    if quantity < 1 or quantity > pending.availableQuantity then
        if self.UpdateListingEditor then
            self:UpdateListingEditor()
        end
        self:SetStatus("Quantity must be between 1 and " .. pending.availableQuantity .. ".")
        return nil
    end
    if totalPrice < 1 then
        self:SetStatus("Set a total price before listing the item.")
        return nil
    end
    if not TradeBoardDB then
        TradeBoardDB = {}
    end
    TradeBoardDB.nextListingID = (TradeBoardDB.nextListingID or 0) + 1
    local owner = UnitName("player") or "Unknown"
    local listing = {
        id = tostring(TradeBoardDB.nextListingID),
        owner = owner,
        trader = owner,
        traderLevel = self:GetPlayerLevel(),
        guild = self:GetPlayerGuildName(),
        itemID = pending.itemID,
        itemLink = pending.itemLink,
        name = pending.name,
        texture = pending.texture,
        quality = pending.quality,
        itemLevel = pending.itemLevel,
        requiredLevel = pending.requiredLevel,
        quantity = quantity,
        totalPrice = totalPrice,
        category = pending.category,
        tags = CopyTags(pending.tags),
        orderType = "SELL",
        online = 1,
        isMine = 1,
        lastSeen = GetTime(),
        lastSeenAt = self:GetWallTime(),
    }
    table.insert(self.MyListings, listing)
    self.State.myListingOffset = table.getn(self.MyListings) - self.MAX_MY_LISTING_ROWS
    if self.State.myListingOffset < 0 then
        self.State.myListingOffset = 0
    end
    self:UpsertListing(listing)
    self:SaveMyListings()
    self.PendingListing = nil
    self:QueueListingAnnouncement(listing, 0)
    if self.UpdateListingEditor then
        self:UpdateListingEditor()
    end
    if self.UpdateMyListings then
        self:UpdateMyListings()
    end
    if self.UpdateBrowse then
        self:UpdateBrowse()
    end
    local status = "Listed " .. listing.name .. " for " .. self:FormatMoney(totalPrice) .. " total."
    if not self:IsListingVisible(listing) then
        status = status .. " Your current Browse filters hide it."
    end
    self:SetStatus(status)
    self:RefreshNetworkStatus()
    return listing
end

function TB:DeleteMyListing(id)
    local i
    for i = table.getn(self.MyListings), 1, -1 do
        if self.MyListings[i].id == id then
            local name = self.MyListings[i].name
            table.remove(self.MyListings, i)
            self:RemoveListing(UnitName("player"), id)
            self:SaveMyListings()
            self:CancelQueuedKey("listing:" .. tostring(id))
            self:QueueMessage(self.PROTOCOL .. "~D~" .. self:EscapeProtocol(id), 0, "delete-listing:" .. tostring(id))
            self.State.selectedMyListing = nil
            if self.UpdateMyListings then
                self:UpdateMyListings()
            end
            if self.UpdateBrowse then
                self:UpdateBrowse()
            end
            self:SetStatus("Removed your listing for " .. name .. ".")
            self:RefreshNetworkStatus()
            return 1
        end
    end
    return nil
end

function TB:BuildListingMessage(listing, omitTexture, omitGuild)
    local message = self.PROTOCOL .. "~A~" ..
        self:EscapeProtocol(listing.id) .. "~" ..
        self:EscapeProtocol(listing.itemLink) .. "~" ..
        tostring(listing.quality or 1) .. "~" ..
        tostring(listing.requiredLevel or 0) .. "~" ..
        tostring(listing.itemLevel or 0) .. "~" ..
        tostring(listing.quantity or 1) .. "~" ..
        tostring(listing.totalPrice or 0) .. "~" ..
        tostring(listing.traderLevel or 1) .. "~" ..
        tostring(listing.orderType or "SELL") .. "~" ..
        self:EscapeProtocol(listing.category or "Miscellaneous") .. "~" ..
        self:EscapeProtocol(self:EncodeTags(listing.tags)) .. "~" ..
        self:EscapeProtocol((not omitTexture and listing.texture) or "") .. "~" ..
        self:EscapeProtocol((not omitGuild and listing.guild) or "")
    return message
end

function TB:QueueListingAnnouncement(listing, delay)
    if listing.isMine then
        listing.traderLevel = self:GetPlayerLevel()
        listing.guild = self:GetPlayerGuildName()
        listing.online = 1
        listing.lastSeen = GetTime()
        listing.lastSeenAt = self:GetWallTime()
    end
    local message = self:BuildListingMessage(listing, nil, nil)
    if string.len(message) > 250 then
        message = self:BuildListingMessage(listing, 1, nil)
    end
    if string.len(message) > 250 then
        message = self:BuildListingMessage(listing, 1, 1)
    end
    self:QueueMessage(message, delay or 0, "listing:" .. tostring(listing.id or ""))
end

function TB:IsSupportedProfession(name)
    local i
    for i = 1, table.getn(self.ProfessionNames) do
        if self.ProfessionNames[i] == name then
            return 1
        end
    end
    return nil
end

function TB:RefreshKnownProfessions()
    self.KnownProfessions = {}
    local i
    local skillCount = GetNumSkillLines() or 0
    self.professionsReady = skillCount > 0 and 1 or nil
    for i = 1, skillCount do
        local skillName, header, isExpanded, skillRank, numTempPoints, skillModifier, skillMaxRank = GetSkillLineInfo(i)
        if not header and self:IsSupportedProfession(skillName) then
            self.KnownProfessions[skillName] = {
                rank = (skillRank or 0) + (numTempPoints or 0) + (skillModifier or 0),
                maxRank = skillMaxRank or 0,
            }
        end
    end
    return self.KnownProfessions
end

function TB:GetServiceKey(owner, profession, source)
    return LowerName(owner) .. "~" .. string.lower(profession or "") .. "~" .. (source == "CHAT" and "chat" or "published")
end

function TB:RebuildServiceIndex()
    self.ServiceIndex = {}
    local i
    for i = 1, table.getn(self.Services) do
        local service = self.Services[i]
        self.ServiceIndex[self:GetServiceKey(service.owner, service.profession, service.source)] = i
    end
end

function TB:UpsertService(service)
    local key = self:GetServiceKey(service.owner, service.profession, service.source)
    local index = self.ServiceIndex[key]
    if index then
        self.Services[index] = service
    else
        table.insert(self.Services, service)
    end
    self:RebuildServiceIndex()
end

function TB:RemoveServices(owner)
    local changed = nil
    local i
    for i = table.getn(self.Services), 1, -1 do
        if LowerName(self.Services[i].owner) == LowerName(owner) and self.Services[i].source ~= "CHAT" then
            if self.State.selectedService == self.Services[i] then
                self.State.selectedService = nil
            end
            table.remove(self.Services, i)
            changed = 1
        end
    end
    if changed then
        self:RebuildServiceIndex()
    end
    return changed
end

function TB:SaveMyServices()
    if not TradeBoardDB then
        TradeBoardDB = {}
    end
    local owner = LowerName(UnitName("player"))
    local saved = TradeBoardDB.services or {}
    local result = {}
    local i
    for i = 1, table.getn(saved) do
        if LowerName(saved[i].owner) ~= owner then
            table.insert(result, saved[i])
        end
    end
    for i = 1, table.getn(self.MyServices) do
        table.insert(result, self.MyServices[i])
    end
    TradeBoardDB.services = result
end

function TB:LoadSavedServices()
    self.MyServices = {}
    self:RefreshKnownProfessions()
    if not self.professionsReady then
        return nil
    end
    local saved = TradeBoardDB and TradeBoardDB.services or {}
    local playerName = UnitName("player") or "Unknown"
    local i
    for i = 1, table.getn(saved) do
        local service = saved[i]
        if LowerName(service.owner) == LowerName(playerName) and self.KnownProfessions[service.profession] then
            service.owner = playerName
            service.trader = playerName
            service.rank = self.KnownProfessions[service.profession].rank
            service.maxRank = self.KnownProfessions[service.profession].maxRank
            service.note = service.note or ""
            service.guild = self:GetPlayerGuildName()
            service.online = 1
            service.isMine = 1
            service.lastSeen = GetTime()
            service.lastSeenAt = self:GetWallTime()
            table.insert(self.MyServices, service)
            self:UpsertService(service)
        end
    end
    self:SaveMyServices()
    self.servicesLoaded = 1
    return 1
end

function TB:BuildServiceMessage(service)
    return self.PROTOCOL .. "~S~" ..
        self:EscapeProtocol(service.profession) .. "~" ..
        tostring(service.rank or 0) .. "~" ..
        tostring(service.maxRank or 0) .. "~" ..
        self:EscapeProtocol(service.note or "") .. "~" ..
        self:EscapeProtocol(service.guild or "")
end

function TB:QueueServiceAnnouncement(service, delay)
    if service.isMine then
        service.guild = self:GetPlayerGuildName()
        service.online = 1
        service.lastSeen = GetTime()
        service.lastSeenAt = self:GetWallTime()
    end
    self:QueueMessage(self:BuildServiceMessage(service), delay or 0, "service:" .. string.lower(service.profession or ""))
end

function TB:CancelPendingProfessionUpdates()
    self.PendingProfessionUpdates = {}
    if self.Network then
        self.Network.professionUpdateDue = nil
    end
end

function TB:ClearQueuedServiceAnnouncements()
    if not self.SendQueue then
        return
    end
    local i
    for i = table.getn(self.SendQueue), 1, -1 do
        local key = self.SendQueue[i].key
        if key == "services:reset" or (key and string.sub(key, 1, 8) == "service:") then
            table.remove(self.SendQueue, i)
        end
    end
end

function TB:RecordPublishedProfessionChanges()
    if not self.servicesLoaded or table.getn(self.MyServices) == 0 then
        return 0
    end
    if not self.PendingProfessionUpdates then
        self.PendingProfessionUpdates = {}
    end
    local changed = 0
    local i
    for i = 1, table.getn(self.MyServices) do
        local service = self.MyServices[i]
        local known = self.KnownProfessions and self.KnownProfessions[service.profession]
        if known and (service.rank ~= known.rank or service.maxRank ~= known.maxRank) then
            service.rank = known.rank
            service.maxRank = known.maxRank
            self.PendingProfessionUpdates[service.profession] = 1
            changed = changed + 1
        end
    end
    if changed > 0 then
        self:SaveMyServices()
        self.Network.professionUpdateDue = GetTime() + self.PROFESSION_UPDATE_DEBOUNCE
        if self.UpdateProfessions then
            self:UpdateProfessions()
        end
    end
    return changed
end

function TB:FlushPublishedProfessionChanges()
    local pending = self.PendingProfessionUpdates or {}
    self.PendingProfessionUpdates = {}
    self.Network.professionUpdateDue = nil
    local delay = 0
    local queued = 0
    local i
    for i = 1, table.getn(self.MyServices) do
        local service = self.MyServices[i]
        if pending[service.profession] then
            self:QueueServiceAnnouncement(service, delay)
            delay = delay + SEND_DELAY
            queued = queued + 1
        end
    end
    return queued
end

function TB:SaveOwnServices(services)
    self:CancelPendingProfessionUpdates()
    self:ClearQueuedServiceAnnouncements()
    local owner = UnitName("player") or "Unknown"
    self:RemoveServices(owner)
    self.MyServices = {}
    local i
    for i = 1, table.getn(services) do
        local service = services[i]
        service.owner = owner
        service.trader = owner
        service.guild = self:GetPlayerGuildName()
        service.online = 1
        service.isMine = 1
        service.lastSeen = GetTime()
        service.lastSeenAt = self:GetWallTime()
        table.insert(self.MyServices, service)
        self:UpsertService(service)
    end
    self:SaveMyServices()
    self:QueueMessage(self.PROTOCOL .. "~Z", 0, "services:reset")
    local delay = SEND_DELAY
    for i = 1, table.getn(self.MyServices) do
        self:QueueServiceAnnouncement(self.MyServices[i], delay)
        delay = delay + SEND_DELAY
    end
    if self.UpdateProfessions then
        self:UpdateProfessions()
    end
    return table.getn(self.MyServices)
end

function TB:DeleteOwnServices()
    if table.getn(self.MyServices) == 0 then
        self:SetStatus("You do not have any published profession services.")
        return nil
    end
    self:SaveOwnServices({})
    self.State.selectedService = nil
    self:SetStatus("Your profession services were removed and the withdrawal was announced.")
    return 1
end

function TB:HandleServiceMessage(fields, sender)
    local profession = self:UnescapeProtocol(fields[3] or "")
    if not self:IsSupportedProfession(profession) then
        return
    end
    local existing = self.ServiceIndex[self:GetServiceKey(sender, profession, nil)]
    existing = existing and self.Services[existing] or nil
    local guild = self:UnescapeProtocol(fields[7] or "")
    local service = {
        owner = sender,
        trader = sender,
        guild = guild ~= "" and guild or (existing and existing.guild) or "",
        profession = profession,
        rank = tonumber(fields[4]) or 0,
        maxRank = tonumber(fields[5]) or 0,
        note = self:UnescapeProtocol(fields[6] or ""),
        online = 1,
        lastSeen = GetTime(),
        lastSeenAt = self:GetWallTime(),
    }
    self:UpsertService(service)
    self:SaveRemoteCache()
end

function TB:SaveRemoteCache()
    if not TradeBoardDB then
        TradeBoardDB = {}
    end
    local playerName = LowerName(UnitName("player"))
    local listings = {}
    local services = {}
    local i
    for i = 1, table.getn(self.Listings) do
        local listing = self.Listings[i]
        if not listing.isMine and listing.source ~= "CHAT" and LowerName(listing.owner) ~= playerName then
            table.insert(listings, listing)
        end
    end
    for i = 1, table.getn(self.Services) do
        local service = self.Services[i]
        if not service.isMine and service.source ~= "CHAT" and LowerName(service.owner) ~= playerName then
            table.insert(services, service)
        end
    end
    TradeBoardDB.remoteListings = listings
    TradeBoardDB.remoteServices = services
end

function TB:LoadRemoteCache()
    local playerName = LowerName(UnitName("player"))
    local savedListings = TradeBoardDB and TradeBoardDB.remoteListings or {}
    local savedServices = TradeBoardDB and TradeBoardDB.remoteServices or {}
    local i
    for i = 1, table.getn(savedListings) do
        local listing = savedListings[i]
        if type(listing) == "table" and listing.owner and listing.id and listing.itemLink and LowerName(listing.owner) ~= playerName then
            listing.trader = listing.trader or listing.owner
            listing.guild = listing.guild or ""
            listing.texture = listing.texture or QUESTION_TEXTURE
            listing.quality = self:NormalizeQuality(listing.quality)
            listing.requiredLevel = tonumber(listing.requiredLevel) or 0
            listing.itemLevel = tonumber(listing.itemLevel) or 0
            listing.quantity = tonumber(listing.quantity) or 1
            if listing.totalPrice == nil then listing.totalPrice = (tonumber(listing.unitPrice) or 0) * (tonumber(listing.quantity) or 1) end
            listing.totalPrice = tonumber(listing.totalPrice) or 0
            listing.unitPrice = nil
            listing.traderLevel = tonumber(listing.traderLevel) or 0
            listing.tags = CopyTags(listing.tags)
            listing.online = nil
            listing.isMine = nil
            listing.lastSeen = nil
            listing.lastSeenAt = tonumber(listing.lastSeenAt)
            self:UpsertListing(listing)
        end
    end
    for i = 1, table.getn(savedServices) do
        local service = savedServices[i]
        if type(service) == "table" and service.owner and self:IsSupportedProfession(service.profession) and LowerName(service.owner) ~= playerName then
            service.trader = service.trader or service.owner
            service.guild = service.guild or ""
            service.rank = tonumber(service.rank) or 0
            service.maxRank = tonumber(service.maxRank) or 0
            service.note = service.note or ""
            service.online = nil
            service.isMine = nil
            service.lastSeen = nil
            service.lastSeenAt = tonumber(service.lastSeenAt)
            self:UpsertService(service)
        end
    end
end

function TB:UpsertChain(chain)
    local owner = LowerName(chain.owner)
    local i
    for i = 1, table.getn(self.Chains) do
        if LowerName(self.Chains[i].owner) == owner then
            self.Chains[i] = chain
            return i
        end
    end
    table.insert(self.Chains, chain)
    return table.getn(self.Chains)
end

function TB:RemoveChain(owner)
    local i
    for i = table.getn(self.Chains), 1, -1 do
        if LowerName(self.Chains[i].owner) == LowerName(owner) then
            table.remove(self.Chains, i)
            if self.State.selectedChain == i then
                self.State.selectedChain = nil
            elseif self.State.selectedChain and self.State.selectedChain > i then
                self.State.selectedChain = self.State.selectedChain - 1
            end
            return 1
        end
    end
    return nil
end

function TB:BuildChainFromSaved(saved, owner, isMine)
    if not saved or not saved.members then
        return nil
    end
    local members = {}
    local i
    for i = 1, 12 do
        local memberName = saved.members[i] or ""
        table.insert(members, {
            level = i * 5,
            name = memberName ~= "" and memberName or "Open slot",
            filled = memberName ~= "" and 1 or nil,
            online = LowerName(memberName) == LowerName(owner) and 1 or nil,
        })
    end
    return {
        name = saved.name or ((owner or "Unknown") .. "'s Chain"),
        owner = owner,
        members = members,
        crossFaction = 1,
        isMine = isMine,
        lastSeen = GetTime(),
    }
end

function TB:SaveOwnChain(name, memberNames)
    if not TradeBoardDB then
        TradeBoardDB = {}
    end
    TradeBoardDB.myChain = { name = name, members = memberNames }
    local owner = UnitName("player") or "Unknown"
    local chain = self:BuildChainFromSaved(TradeBoardDB.myChain, owner, 1)
    local index = self:UpsertChain(chain)
    self.State.selectedChain = index
    self:QueueChainAnnouncement(chain, 0)
    return chain
end

function TB:LoadSavedChain()
    if TradeBoardDB and TradeBoardDB.myChain then
        local chain = self:BuildChainFromSaved(TradeBoardDB.myChain, UnitName("player") or "Unknown", 1)
        self.State.selectedChain = self:UpsertChain(chain)
    end
end

function TB:DeleteOwnChain()
    if not TradeBoardDB or not TradeBoardDB.myChain then
        self:SetStatus("You do not have a listed trade chain.")
        return nil
    end
    TradeBoardDB.myChain = nil
    self:RemoveChain(UnitName("player"))
    self:QueueMessage(self.PROTOCOL .. "~X", 0)
    if self.UpdateTradeChains then
        self:UpdateTradeChains()
    end
    self:SetStatus("Your trade-chain listing was deleted and its removal was announced.")
    return 1
end

function TB:BuildChainMessage(chain)
    local message = self.PROTOCOL .. "~C~" .. self:EscapeProtocol(chain.name)
    local i
    for i = 1, 12 do
        local member = chain.members[i]
        local name = member and member.filled and member.name or ""
        message = message .. "~" .. self:EscapeProtocol(name)
    end
    return message
end

function TB:QueueChainAnnouncement(chain, delay)
    self:QueueMessage(self:BuildChainMessage(chain), delay or 0, "chain")
end

function TB:BuildChainOrderMessage(order)
    return self.PROTOCOL .. "~O~" .. self:EscapeProtocol(order.id) .. "~" .. self:EscapeProtocol(order.chainOwner) .. "~" ..
        self:EscapeProtocol(order.customer) .. "~" .. self:EscapeProtocol(order.item) .. "~" .. tostring(order.quantity or 1) .. "~" ..
        self:EscapeProtocol(order.fromName) .. "~" .. self:EscapeProtocol(order.toName) .. "~" .. self:EscapeProtocol(order.note) .. "~" ..
        self:EscapeProtocol(order.status) .. "~" .. tostring(order.updatedAt or self:GetWallTime()) .. "~" .. self:EscapeProtocol(order.updatedBy)
end

function TB:QueueChainOrderAnnouncement(order, delay)
    local message = self:BuildChainOrderMessage(order)
    if string.len(message) <= 250 then self:QueueMessage(message, delay or 0, "order:" .. order.id) end
end

function TB:QueueVolunteerAnnouncement(volunteer, delay)
    local message = self.PROTOCOL .. "~V~" .. self:EscapeProtocol(volunteer.name) .. "~" .. tostring(volunteer.level or 0) .. "~" ..
        tostring(volunteer.low or 0) .. "~" .. tostring(volunteer.high or 0) .. "~" .. (volunteer.enabled and "1" or "0") .. "~" ..
        tostring(volunteer.updatedAt or self:GetWallTime())
    self:QueueMessage(message, delay or 0, "volunteer:" .. LowerName(volunteer.name))
end

function TB:QueueMessage(message, delay, queueKey)
    if not self.SendQueue then
        self.SendQueue = {}
    end
    if string.len(message) > 250 then
        self:SetStatus("An HC TradeBoard message was too long to send safely.")
        return nil
    end
    local due = GetTime() + (delay or 0)
    if queueKey then
        local i
        for i = 1, table.getn(self.SendQueue) do
            local queued = self.SendQueue[i]
            if queued.key == queueKey then
                queued.message = message
                if due < queued.due then queued.due = due end
                return 1
            end
        end
    end
    if table.getn(self.SendQueue) >= MAX_SEND_QUEUE then
        self:SetStatus("Network queue is full; duplicate background data was dropped safely.")
        return nil
    end
    table.insert(self.SendQueue, { message = message, due = due, key = queueKey })
    return 1
end

function TB:CancelQueuedKey(queueKey)
    if not self.SendQueue or not queueKey then return end
    local i
    for i = table.getn(self.SendQueue), 1, -1 do
        if self.SendQueue[i].key == queueKey then table.remove(self.SendQueue, i) end
    end
end

function TB:BuildWorldMessage(entry)
    return self.PROTOCOL .. "~W~" .. self:EscapeProtocol(entry.id) .. "~" ..
        tostring(entry.timestamp or self:GetWallTime()) .. "~" .. tostring(entry.type or "WTS") .. "~" ..
        tostring(entry.channel or "World") .. "~" .. self:EscapeProtocol(entry.sender or "Unknown") .. "~" ..
        tostring(entry.level or 0) .. "~" .. self:EscapeProtocol(entry.class or "") .. "~" ..
        self:EscapeProtocol(entry.guild or "") .. "~" .. self:EscapeProtocol(entry.message or "")
end

function TB:QueueWorldAnnouncement(entry, delay)
    if not entry or not entry.id then return end
    local message = self:BuildWorldMessage(entry)
    if string.len(message) <= 250 then
        local due = GetTime() + (delay or 0)
        if self.Network and self.Network.nextWorldShareDue and due < self.Network.nextWorldShareDue then due = self.Network.nextWorldShareDue end
        if self.Network then self.Network.nextWorldShareDue = due + WORLD_SEND_DELAY end
        self:QueueMessage(message, due - GetTime(), "world:" .. entry.id)
    end
end

function TB:QueueIdentityAnnouncement(name, level, class, guild, verifiedAt, delay)
    if not name or name == "" then return end
    local message = self.PROTOCOL .. "~I~" .. self:EscapeProtocol(name) .. "~" .. tostring(level or 0) .. "~" ..
        self:EscapeProtocol(class or "") .. "~" .. self:EscapeProtocol(guild or "") .. "~" .. tostring(verifiedAt or self:GetWallTime())
    self:QueueMessage(message, delay or 0, "identity:" .. LowerName(name))
end

function TB:QueueSharedSnapshots(baseDelay)
    local delay = baseDelay or 8
    local first = table.getn(self.WorldLog or {}) - 3
    if first < 1 then first = 1 end
    local i
    for i = first, table.getn(self.WorldLog or {}) do
        self:QueueWorldAnnouncement(self.WorldLog[i], delay + (math.random() * 8))
        delay = delay + SEND_DELAY
    end
    local identities = {}
    local name, person
    for name, person in pairs((TradeBoardDB and TradeBoardDB.worldPeople) or {}) do
        table.insert(identities, { name = name, person = person })
    end
    table.sort(identities, function(a, b) return (a.person.seenAt or 0) > (b.person.seenAt or 0) end)
    local limit = table.getn(identities)
    if limit > 2 then limit = 2 end
    for i = 1, limit do
        person = identities[i].person
        self:QueueIdentityAnnouncement(person.name or identities[i].name, person.level, person.class, person.guild, person.seenAt, delay + (math.random() * 8))
        delay = delay + SEND_DELAY
    end
end

function TB:HandleWorldMessage(fields, peerSender)
    local entry = {
        id = self:UnescapeProtocol(fields[3] or ""), timestamp = tonumber(fields[4]) or 0,
        type = fields[5], channel = fields[6], sender = self:UnescapeProtocol(fields[7] or ""),
        level = tonumber(fields[8]) or 0, class = self:UnescapeProtocol(fields[9] or ""),
        guild = self:UnescapeProtocol(fields[10] or ""), message = self:UnescapeProtocol(fields[11] or ""),
        source = "PEER", relayPeer = peerSender,
    }
    if entry.id == "" or entry.sender == "" or (entry.type ~= "WTS" and entry.type ~= "WTB" and entry.type ~= "LFW") then return end
    if entry.channel ~= "World" and entry.channel ~= "Trade" then return end
    if entry.timestamp < self:GetWallTime() - self.WORLD_LOG_TTL then return end
    self:InitializeWorldLog()
    self:CancelQueuedKey("world:" .. entry.id)
    local i
    for i = 1, table.getn(self.WorldLog) do if self.WorldLog[i].id == entry.id then return end end
    entry.items = self:ExtractWorldItemLinks(entry.message)
    table.insert(self.WorldLog, entry)
    self:PruneWorldLog()
    self:RememberWorldPerson(entry.sender, entry.guild, entry.level, entry.class, entry.timestamp)
    self:ImportWorldEntry(entry)
    if self.CheckWantedEntry then self:CheckWantedEntry(entry) end
end

function TB:HandleChainOrderMessage(fields, peerSender)
    if not self.UpsertChainOrder then return end
    local order = { id = self:UnescapeProtocol(fields[3] or ""), chainOwner = self:UnescapeProtocol(fields[4] or ""),
        customer = self:UnescapeProtocol(fields[5] or ""), item = self:UnescapeProtocol(fields[6] or ""), quantity = tonumber(fields[7]) or 1,
        fromName = self:UnescapeProtocol(fields[8] or ""), toName = self:UnescapeProtocol(fields[9] or ""), note = self:UnescapeProtocol(fields[10] or ""),
        status = self:UnescapeProtocol(fields[11] or "REQUESTED"), updatedAt = tonumber(fields[12]) or 0,
        updatedBy = self:UnescapeProtocol(fields[13] or "") }
    if order.id == "" or order.item == "" or LowerName(order.updatedBy) ~= LowerName(peerSender) or order.updatedAt < self:GetWallTime() - self.CHAIN_ORDER_TTL then return end
    if order.status ~= "REQUESTED" and order.status ~= "PICKED UP" and order.status ~= "DELIVERED" then return end
    order.quantity = math.max(1, math.min(9999, order.quantity))
    local existing, i
    for i = 1, table.getn(self.ChainOrders or {}) do if self.ChainOrders[i].id == order.id then existing = self.ChainOrders[i]; break end end
    if not existing then
        if LowerName(order.customer) ~= LowerName(peerSender) then return end
    else
        local sender = LowerName(peerSender)
        if sender ~= LowerName(existing.customer) and sender ~= LowerName(existing.chainOwner) and sender ~= LowerName(existing.fromName) and sender ~= LowerName(existing.toName) then return end
        -- Status participants cannot rewrite the original request or route.
        order.chainOwner = existing.chainOwner; order.customer = existing.customer; order.item = existing.item
        order.quantity = existing.quantity; order.fromName = existing.fromName; order.toName = existing.toName
    end
    self:CancelQueuedKey("order:" .. order.id)
    self:UpsertChainOrder(order)
end

function TB:HandleVolunteerMessage(fields, peerSender)
    if not self.InitializeFeatureData then return end
    self:InitializeFeatureData()
    local name = self:UnescapeProtocol(fields[3] or "")
    local updatedAt = tonumber(fields[8]) or 0
    if name == "" or LowerName(name) ~= LowerName(peerSender) or updatedAt < self:GetWallTime() - self.CHAIN_ORDER_TTL then return end
    local existing = self.ChainVolunteers[LowerName(name)]
    if not existing or updatedAt >= (tonumber(existing.updatedAt) or 0) then
        local level = tonumber(fields[4]) or 0
        self.ChainVolunteers[LowerName(name)] = { name = name, level = level, low = math.max(1, level - 5),
            high = math.min(60, level + 5), enabled = fields[7] == "1" and 1 or nil, updatedAt = updatedAt }
    end
end

function TB:HandleIdentityMessage(fields)
    local name = self:UnescapeProtocol(fields[3] or "")
    local verifiedAt = tonumber(fields[7]) or 0
    if name == "" or verifiedAt < self:GetWallTime() - 86400 then return end
    self:CancelQueuedKey("identity:" .. LowerName(name))
    local existing = TradeBoardDB and TradeBoardDB.worldPeople and TradeBoardDB.worldPeople[LowerName(name)]
    if existing and (tonumber(existing.seenAt) or 0) >= verifiedAt then return end
    self:RememberWorldPerson(name, self:UnescapeProtocol(fields[6] or ""), tonumber(fields[4]), self:UnescapeProtocol(fields[5] or ""), verifiedAt)
end

function TB:HideNetworkChannel()
    local i
    for i = 1, 7 do
        local chatFrame = getglobal("ChatFrame" .. i)
        if chatFrame then
            ChatFrame_RemoveChannel(chatFrame, self.CHANNEL_NAME)
        end
    end
end

function TB:GetNetworkPeerCount()
    local now = GetTime()
    local count = 0
    local name, peer
    for name, peer in pairs(self.Network.peers) do
        if now - peer.lastSeen < self.REMOTE_TTL then
            count = count + 1
        end
    end
    return count
end

function TB:RefreshNetworkStatus()
    if not self.Frames or not self.Frames.networkText or not self.Network then
        return
    end
    local state = self.Network.state
    local text
    local r, g, b = 0.80, 0.72, 0.52
    if state == "JOINING" then
        text = "Network: joining " .. self.CHANNEL_NAME
    elseif state == "PROBING" then
        text = "Network: probing peers..."
    elseif state == "CONNECTED" then
        local count = self:GetNetworkPeerCount()
        text = "Network: " .. count .. " peer"
        if count ~= 1 then
            text = text .. "s"
        end
        text = text .. " / " .. table.getn(self.Listings) .. " items / " .. table.getn(self.Services) .. " services"
        if self.Network.crossFactionSeen then
            text = text .. " / cross-faction"
        end
        r, g, b = 0.30, 1.00, 0.30
    elseif state == "ALONE" then
        text = "Network: channel joined / no reply yet"
        r, g, b = 1.00, 0.78, 0.25
    elseif state == "ERROR" then
        text = "Network: could not join " .. self.CHANNEL_NAME
        r, g, b = 1.00, 0.25, 0.20
    else
        text = "Network: offline"
        r, g, b = 0.70, 0.35, 0.30
    end
    self.Frames.networkText:SetText(text)
    self.Frames.networkText:SetTextColor(r, g, b)
    if self.UpdateMyListings then
        self:UpdateMyListings()
    end
end

function TB:MarkPeer(sender, faction, level, guild)
    if LowerName(sender) == LowerName(UnitName("player")) then
        return
    end
    local key = LowerName(sender)
    local existing = self.Network.peers[key]
    if (not faction or faction == "") and existing then
        faction = existing.faction
    end
    level = tonumber(level) or (existing and existing.level)
    if (not guild or guild == "") and existing then guild = existing.guild end
    self.Network.peers[key] = { lastSeen = GetTime(), faction = faction, level = level, guild = guild or "" }
    if level or (guild and guild ~= "") then self:RememberWorldPerson(sender, guild, level) end
    local myFaction = UnitFactionGroup("player")
    if faction and myFaction and faction ~= "" and faction ~= myFaction then
        self.Network.crossFactionSeen = 1
    end
    self.Network.state = "CONNECTED"
    self:RefreshNetworkStatus()
end

function TB:SendQueuedMessage()
    if not self.SendQueue or table.getn(self.SendQueue) == 0 then
        return
    end
    local channelID = GetChannelName(self.CHANNEL_NAME)
    if not channelID or channelID == 0 then
        return
    end
    local now = GetTime()
    if self.Network.userChatQuietUntil and now < self.Network.userChatQuietUntil then return end
    if self.Network.lastSend and now - self.Network.lastSend < SEND_DELAY then
        return
    end
    self.Network.sendTimes = self.Network.sendTimes or {}
    local historyIndex
    for historyIndex = table.getn(self.Network.sendTimes), 1, -1 do
        if now - self.Network.sendTimes[historyIndex] >= 60 then table.remove(self.Network.sendTimes, historyIndex) end
    end
    if table.getn(self.Network.sendTimes) >= MAX_SENDS_PER_MINUTE then return end
    local chosen = nil
    local chosenDue = nil
    local i
    for i = 1, table.getn(self.SendQueue) do
        local queued = self.SendQueue[i]
        if queued.due <= now and (not chosenDue or queued.due < chosenDue) then
            chosen = i
            chosenDue = queued.due
        end
    end
    if chosen then
        local queued = self.SendQueue[chosen]
        table.remove(self.SendQueue, chosen)
        SendChatMessage(queued.message, "CHANNEL", nil, channelID)
        self.Network.lastSend = now
        table.insert(self.Network.sendTimes, now)
    end
end

function TB:QueueOwnData(baseDelay)
    local delay = baseDelay or 0
    local i
    for i = 1, table.getn(self.MyListings) do
        self:QueueListingAnnouncement(self.MyListings[i], delay)
        delay = delay + SEND_DELAY
    end
    if TradeBoardDB and TradeBoardDB.myChain then
        local ownChain
        for i = 1, table.getn(self.Chains) do
            if self.Chains[i].isMine then
                ownChain = self.Chains[i]
                break
            end
        end
        if ownChain then
            self:QueueChainAnnouncement(ownChain, delay)
            delay = delay + SEND_DELAY
        end
    end
    for i = 1, table.getn(self.MyServices) do
        self:QueueServiceAnnouncement(self.MyServices[i], delay)
        delay = delay + SEND_DELAY
    end
    if self.GetOwnVolunteer then
        local volunteer = self:GetOwnVolunteer()
        if volunteer then self:QueueVolunteerAnnouncement(volunteer, delay); delay = delay + SEND_DELAY end
    end
    if self.ChainOrders then
        local sentOrders = 0
        for i = table.getn(self.ChainOrders), 1, -1 do
            if sentOrders < 5 and LowerName(self.ChainOrders[i].updatedBy) == LowerName(UnitName("player")) then
                self:QueueChainOrderAnnouncement(self.ChainOrders[i], delay)
                delay = delay + SEND_DELAY
                sentOrders = sentOrders + 1
            end
        end
    end
end

function TB:ProbeAndSync()
    local channelID = GetChannelName(self.CHANNEL_NAME)
    if not channelID or channelID == 0 then
        if self.Network.state == "ERROR" then
            self.Network.joinAttempts = 0
        end
        self:JoinNetworkChannel()
        return
    end
    local now = GetTime()
    if self.Network.lastProbeAt and now - self.Network.lastProbeAt < 30 then return end
    self.Network.lastProbeAt = now
    self.Network.probeCounter = self.Network.probeCounter + 1
    local nonce = tostring(self.Network.probeCounter) .. tostring(math.floor(GetTime()))
    self.Network.probeNonce = nonce
    self.Network.probeDeadline = GetTime() + 8
    self.Network.state = "PROBING"
    self:QueueMessage(self.PROTOCOL .. "~P~" .. nonce, 0, "probe")
    self:QueueMessage(self.PROTOCOL .. "~Q~" .. nonce, SEND_DELAY, "sync-query")
    self:RefreshNetworkStatus()
end

function TB:JoinNetworkChannel()
    local channelID = GetChannelName(self.CHANNEL_NAME)
    if channelID and channelID > 0 then
        self.Network.channelID = channelID
        self:HideNetworkChannel()
        self:ProbeAndSync()
        return
    end
    self.Network.state = "JOINING"
    self.Network.joinStarted = GetTime()
    self.Network.joinAttempts = (self.Network.joinAttempts or 0) + 1
    JoinChannelByName(self.CHANNEL_NAME, nil, DEFAULT_CHAT_FRAME:GetID())
    self:RefreshNetworkStatus()
end

function TB:HandleListingMessage(fields, sender)
    local itemLink = self:UnescapeProtocol(fields[4])
    local data = self:GetItemMetadata(itemLink) or {}
    local transmittedTexture = self:UnescapeProtocol(fields[14] or "")
    local existing = self.ListingIndex[self:GetListingKey(sender, self:UnescapeProtocol(fields[3]))]
    existing = existing and self.Listings[existing] or nil
    local guild = self:UnescapeProtocol(fields[15] or "")
    local listing = {
        id = self:UnescapeProtocol(fields[3]),
        owner = sender,
        trader = sender,
        guild = guild ~= "" and guild or (existing and existing.guild) or "",
        itemID = self:ExtractItemID(itemLink),
        itemLink = data.itemLink or itemLink,
        name = data.name or self:ExtractItemName(itemLink),
        texture = transmittedTexture ~= "" and transmittedTexture or data.texture or QUESTION_TEXTURE,
        quality = self:NormalizeQuality(tonumber(fields[5]) or data.quality or 1),
        requiredLevel = data.requiredLevel or tonumber(fields[6]) or 0,
        itemLevel = data.itemLevel or tonumber(fields[7]) or 0,
        quantity = tonumber(fields[8]) or 1,
        totalPrice = tonumber(fields[9]) or 0,
        traderLevel = tonumber(fields[10]) or 0,
        orderType = fields[11] == "BUY" and "BUY" or "SELL",
        category = self:UnescapeProtocol(fields[12] or "Miscellaneous"),
        tags = self:DecodeTags(self:UnescapeProtocol(fields[13] or "")),
        online = 1,
        lastSeen = GetTime(),
        lastSeenAt = self:GetWallTime(),
    }
    self:UpsertListing(listing)
    self:RememberWorldPerson(sender, listing.guild, listing.traderLevel)
    self:SaveRemoteCache()
end

function TB:HandleChainMessage(fields, sender)
    local saved = { name = self:UnescapeProtocol(fields[3]), members = {} }
    local i
    for i = 1, 12 do
        saved.members[i] = self:UnescapeProtocol(fields[i + 3] or "")
    end
    self:UpsertChain(self:BuildChainFromSaved(saved, sender, nil))
end

function TB:HandleProtocolMessage(message, sender)
    if string.sub(message or "", 1, string.len(self.PROTOCOL) + 1) ~= self.PROTOCOL .. "~" then
        return
    end
    if LowerName(sender) == LowerName(UnitName("player")) then
        return
    end
    local fields = SplitMessage(message)
    local operation = fields[2]
    if operation == "P" then
        local nonce = fields[3] or ""
        self.Network.pendingProbeResponse = { nonce = nonce, due = GetTime() + (math.random() * 4) }
        self:MarkPeer(sender)
    elseif operation == "R" then
        local nonce = fields[3] or ""
        if self.Network.pendingProbeResponse and self.Network.pendingProbeResponse.nonce == nonce then
            self.Network.pendingProbeResponse = nil
        end
        self:MarkPeer(sender, fields[5], fields[6], self:UnescapeProtocol(fields[7] or ""))
    elseif operation == "Q" then
        local now = GetTime()
        if table.getn(self.MyListings) > 0 or table.getn(self.MyServices) > 0 or (TradeBoardDB and TradeBoardDB.myChain) or
            table.getn(self.WorldLog or {}) > 0 or table.getn(self.ChainOrders or {}) > 0 or (self.GetOwnVolunteer and self:GetOwnVolunteer()) then
            self.Network.queryReplyAt = self.Network.queryReplyAt or {}
            local requester = LowerName(sender)
            if not self.Network.queryReplyAt[requester] or now - self.Network.queryReplyAt[requester] > 600 then
                self.Network.queryReplyAt[requester] = now
                local delay = 5 + (math.random() * 20)
                self:QueueOwnData(delay)
                self:QueueSharedSnapshots(delay + 4)
            end
        end
        self:MarkPeer(sender)
    elseif operation == "A" then
        self:HandleListingMessage(fields, sender)
        self:MarkPeer(sender)
        if self.UpdateBrowse then
            self:UpdateBrowse()
        end
    elseif operation == "D" then
        self:RemoveListing(sender, self:UnescapeProtocol(fields[3]))
        self:SaveRemoteCache()
        self:MarkPeer(sender)
        if self.UpdateBrowse then
            self:UpdateBrowse()
        end
    elseif operation == "C" then
        self:HandleChainMessage(fields, sender)
        self:MarkPeer(sender)
        if self.UpdateTradeChains then
            self:UpdateTradeChains()
        end
    elseif operation == "X" then
        self:RemoveChain(sender)
        self:MarkPeer(sender)
        if self.UpdateTradeChains then
            self:UpdateTradeChains()
        end
    elseif operation == "S" then
        self:HandleServiceMessage(fields, sender)
        self:MarkPeer(sender)
        if self.UpdateProfessions then
            self:UpdateProfessions()
        end
    elseif operation == "Z" then
        self:RemoveServices(sender)
        self:SaveRemoteCache()
        self:MarkPeer(sender)
        if self.UpdateProfessions then
            self:UpdateProfessions()
        end
    elseif operation == "W" then
        self:HandleWorldMessage(fields, sender)
        self:MarkPeer(sender)
        if self.UpdateWorldLog then self:UpdateWorldLog() end
        if self.UpdateBrowse then self:UpdateBrowse() end
        if self.UpdateProfessions then self:UpdateProfessions() end
    elseif operation == "I" then
        self:HandleIdentityMessage(fields)
        self:MarkPeer(sender)
        if self.UpdateWorldLog then self:UpdateWorldLog() end
        if self.UpdateBrowse then self:UpdateBrowse() end
        if self.UpdateProfessions then self:UpdateProfessions() end
    elseif operation == "O" then
        self:HandleChainOrderMessage(fields, sender)
        self:MarkPeer(sender)
        if self.UpdateDeliveryDesk then self:UpdateDeliveryDesk() end
    elseif operation == "V" then
        self:HandleVolunteerMessage(fields, sender)
        self:MarkPeer(sender)
        if self.UpdateDeliveryDesk then self:UpdateDeliveryDesk() end
    end
end

function TB:ExpireRemoteData()
    local now = GetTime()
    local wallNow = self:GetWallTime()
    local i
    local changed = nil
    for i = table.getn(self.Listings), 1, -1 do
        local listing = self.Listings[i]
        if listing.source == "CHAT" and listing.expiresAt and wallNow >= listing.expiresAt then
            table.remove(self.Listings, i)
            changed = 1
        elseif not listing.isMine and listing.online and listing.lastSeen and now - listing.lastSeen > self.REMOTE_TTL then
            listing.online = nil
            changed = 1
        end
    end
    if changed then
        self:RebuildListingIndex()
        self:SaveRemoteCache()
        if self.UpdateBrowse then
            self:UpdateBrowse()
        end
    end
    for i = table.getn(self.Chains), 1, -1 do
        local chain = self.Chains[i]
        if not chain.isMine and chain.lastSeen and now - chain.lastSeen > self.REMOTE_TTL then
            table.remove(self.Chains, i)
            changed = 1
        end
    end
    if changed and self.UpdateTradeChains then
        self:UpdateTradeChains()
    end
    local servicesChanged = nil
    for i = table.getn(self.Services), 1, -1 do
        local service = self.Services[i]
        if service.source == "CHAT" and service.expiresAt and wallNow >= service.expiresAt then
            table.remove(self.Services, i)
            servicesChanged = 1
        elseif not service.isMine and service.online and service.lastSeen and now - service.lastSeen > self.REMOTE_TTL then
            service.online = nil
            servicesChanged = 1
        end
    end
    if servicesChanged then
        self:RebuildServiceIndex()
        self:SaveRemoteCache()
        if self.UpdateProfessions then
            self:UpdateProfessions()
        end
    end
end

function TB:NetworkOnUpdate()
    if not self.Network then
        return
    end
    local now = GetTime()
    if self.PendingManualWhoName and self.pendingManualWhoStarted and now - self.pendingManualWhoStarted > 15 then self.PendingManualWhoName = nil end
    if self.Network.professionUpdateDue and now >= self.Network.professionUpdateDue then
        self:FlushPublishedProfessionChanges()
    end
    self:SendQueuedMessage()

    if self.Frames and self.Frames.main and self.Frames.main:IsShown() then
        if self.Network.nextOpenSync and now >= self.Network.nextOpenSync then
            self.Network.nextOpenSync = now + self.AUTO_SYNC_INTERVAL
            self:ProbeAndSync()
        end
    else
        self.Network.nextOpenSync = nil
    end

    if self.Network.pendingProbeResponse and now >= self.Network.pendingProbeResponse.due then
        local response = self.Network.pendingProbeResponse
        self.Network.pendingProbeResponse = nil
        self:QueueMessage(self.PROTOCOL .. "~R~" .. response.nonce .. "~" .. self.VERSION .. "~" .. (UnitFactionGroup("player") or "") .. "~" .. tostring(self:GetPlayerLevel()) .. "~" .. self:EscapeProtocol(self:GetPlayerGuildName()), 0)
    end

    if self.Network.probeDeadline and now >= self.Network.probeDeadline then
        self.Network.probeDeadline = nil
        if self:GetNetworkPeerCount() > 0 then
            self.Network.state = "CONNECTED"
        else
            self.Network.state = "ALONE"
        end
        self:RefreshNetworkStatus()
    end

    if self.Network.state == "JOINING" and self.Network.joinStarted and now - self.Network.joinStarted > 5 then
        local channelID = GetChannelName(self.CHANNEL_NAME)
        if channelID and channelID > 0 then
            self.Network.channelID = channelID
            self.Network.joinAttempts = 0
            self:HideNetworkChannel()
            self:ProbeAndSync()
        else
            if (self.Network.joinAttempts or 0) >= 3 then
                self.Network.state = "ERROR"
                self.Network.joinStarted = nil
                self:RefreshNetworkStatus()
            else
                self.Network.joinStarted = now
                self.Network.joinAttempts = (self.Network.joinAttempts or 0) + 1
                JoinChannelByName(self.CHANNEL_NAME, nil, DEFAULT_CHAT_FRAME:GetID())
            end
        end
    end

    if self.Network.nextAnnouncement and now >= self.Network.nextAnnouncement then
        local channelID = GetChannelName(self.CHANNEL_NAME)
        if channelID and channelID > 0 then
            self:QueueOwnData(math.random() * 12)
        end
        self.Network.nextAnnouncement = now + self.ANNOUNCE_INTERVAL + (math.random() * 45)
    end

    if not self.Network.nextCleanup or now >= self.Network.nextCleanup then
        self.Network.nextCleanup = now + 30
        self:ExpireRemoteData()
        self:RefreshNetworkStatus()
    end
end

function TB:NetworkOnEvent(eventName, one, two, three, four, five, six, seven, eight, nine)
    if eventName == "VARIABLES_LOADED" then
        if not TradeBoardDB then
            TradeBoardDB = {}
        end
        self:LoadSavedListings()
        self:LoadSavedChain()
        self:LoadSavedServices()
        self:LoadRemoteCache()
        self:InitializeWorldLog()
        if self.InitializeFeatureData then self:InitializeFeatureData() end
        if self.UpdateMyListings then
            self:UpdateMyListings()
        end
        if self.UpdateTradeChains then
            self:UpdateTradeChains()
        end
        if self.UpdateProfessions then
            self:UpdateProfessions()
        end
    elseif eventName == "PLAYER_ENTERING_WORLD" then
        self:RefreshOwnListingLevels()
        if not self.servicesLoaded then
            self:LoadSavedServices()
            if self.UpdateProfessions then
                self:UpdateProfessions()
            end
        end
        self:JoinNetworkChannel()
    elseif eventName == "CHAT_MSG_CHANNEL" then
        if LowerName(two) == LowerName(UnitName("player")) and nine and string.upper(nine) ~= string.upper(self.CHANNEL_NAME) then
            self.Network.userChatQuietUntil = GetTime() + 15
        end
        self:CaptureWorldMessage(one, two, nine)
        if not nine or nine == "" or string.upper(nine) == string.upper(self.CHANNEL_NAME) then
            self:HandleProtocolMessage(one, two)
        end
    elseif eventName == "CHAT_MSG_SAY" or eventName == "CHAT_MSG_YELL" or eventName == "CHAT_MSG_GUILD" or eventName == "CHAT_MSG_PARTY" or eventName == "CHAT_MSG_RAID" or eventName == "CHAT_MSG_WHISPER_INFORM" then
        if LowerName(two) == LowerName(UnitName("player")) or eventName == "CHAT_MSG_WHISPER_INFORM" then self.Network.userChatQuietUntil = GetTime() + 15 end
    elseif eventName == "WHO_LIST_UPDATE" then
        if self.PendingManualWhoName and GetNumWhoResults and GetWhoInfo then
            local i
            for i = 1, GetNumWhoResults() do
                local name, guild, level, race, class = GetWhoInfo(i)
                if name and string.lower(name) == self.PendingManualWhoName then
                    local verifiedAt = self:GetWallTime()
                    self:RememberWorldPerson(name, guild, level, class, verifiedAt)
                    self:QueueIdentityAnnouncement(name, level, class, guild, verifiedAt, 0)
                    self:SetStatus("Updated " .. name .. ": level " .. tostring(level or "?") .. (class and class ~= "" and (" " .. class) or "") .. ". Shared with peers.")
                    break
                end
            end
        end
        self.PendingManualWhoName = nil
        if self.UpdateWorldLog then self:UpdateWorldLog() end
        if self.UpdateBrowse then self:UpdateBrowse() end
        if self.UpdateProfessions then self:UpdateProfessions() end
    elseif eventName == "CHAT_MSG_CHANNEL_NOTICE" then
        if one == "YOU_JOINED" and nine and string.upper(nine) == string.upper(self.CHANNEL_NAME) then
            self.Network.channelID = GetChannelName(self.CHANNEL_NAME)
            self.Network.joinAttempts = 0
            self:HideNetworkChannel()
            self:ProbeAndSync()
        elseif one == "YOU_LEFT" and nine and string.upper(nine) == string.upper(self.CHANNEL_NAME) then
            self.Network.state = "OFFLINE"
            self:RefreshNetworkStatus()
        end
    elseif eventName == "PLAYER_LOGOUT" then
        self:SaveMyListings()
        self:SaveMyServices()
        self:SaveRemoteCache()
    elseif eventName == "SKILL_LINES_CHANGED" then
        self:RefreshKnownProfessions()
        if not self.servicesLoaded then
            self:LoadSavedServices()
            if self.UpdateProfessions then
                self:UpdateProfessions()
            end
            return
        end
        self:RecordPublishedProfessionChanges()
    end
end

function TB:InitializeNetwork()
    self.SendQueue = {}
    self.PendingProfessionUpdates = {}
    self.Network = {
        state = "OFFLINE",
        peers = {},
        probeCounter = 0,
        nextAnnouncement = GetTime() + 30 + (math.random() * 30),
    }
    self:HookBagItemClicks()

    local frame = CreateFrame("Frame", nil, UIParent)
    frame:RegisterEvent("VARIABLES_LOADED")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PLAYER_LOGOUT")
    frame:RegisterEvent("CHAT_MSG_CHANNEL")
    frame:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE")
    frame:RegisterEvent("CHAT_MSG_SAY")
    frame:RegisterEvent("CHAT_MSG_YELL")
    frame:RegisterEvent("CHAT_MSG_GUILD")
    frame:RegisterEvent("CHAT_MSG_PARTY")
    frame:RegisterEvent("CHAT_MSG_RAID")
    frame:RegisterEvent("CHAT_MSG_WHISPER_INFORM")
    frame:RegisterEvent("SKILL_LINES_CHANGED")
    frame:RegisterEvent("WHO_LIST_UPDATE")
    frame:SetScript("OnEvent", function()
        TB:NetworkOnEvent(event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
    end)
    frame:SetScript("OnUpdate", function()
        TB:NetworkOnUpdate()
    end)
    self.Frames.networkEventFrame = frame
    self:RefreshNetworkStatus()
end
