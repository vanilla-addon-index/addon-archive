TradeBoard = {}

TradeBoard.VERSION = "0.8.2"
TradeBoard.DISPLAY_TITLE = "HC TradeBoard"
TradeBoard.COLORED_TITLE = "|cffb8c0ccHC|r |cffa335eeTradeBoard|r"
TradeBoard.MAX_VISIBLE_ROWS = 10
TradeBoard.MAX_MY_LISTING_ROWS = 9
TradeBoard.CHANNEL_NAME = "TradeBoard"
TradeBoard.PROTOCOL = "TB2"
TradeBoard.REMOTE_TTL = 600
TradeBoard.ANNOUNCE_INTERVAL = 900
TradeBoard.AUTO_SYNC_INTERVAL = 600
TradeBoard.PROFESSION_UPDATE_DEBOUNCE = 45
TradeBoard.MAX_WORLD_LOGS = 500
TradeBoard.MAX_WORLD_ROWS = 10
TradeBoard.WORLD_LOG_TTL = 43200
TradeBoard.CHAT_WTS_TTL = 10800
TradeBoard.MAX_PROFESSION_ROWS = 10
TradeBoard.WHO_COOLDOWN = 30
TradeBoard.MEMORY_SAMPLE_INTERVAL = 30

TradeBoard.Listings = {}
TradeBoard.ListingIndex = {}
TradeBoard.MyListings = {}
TradeBoard.Chains = {}
TradeBoard.Services = {}
TradeBoard.ServiceIndex = {}
TradeBoard.MyServices = {}

TradeBoard.ProfessionNames = {
    "Alchemy",
    "Blacksmithing",
    "Enchanting",
    "Engineering",
    "Herbalism",
    "Leatherworking",
    "Mining",
    "Skinning",
    "Tailoring",
    "Cooking",
    "First Aid",
}

TradeBoard.GuildSigilTextures = {
    "Interface\\Icons\\INV_Shield_04",
    "Interface\\Icons\\INV_Shield_05",
    "Interface\\Icons\\INV_Shield_06",
    "Interface\\Icons\\INV_Shield_07",
    "Interface\\Icons\\INV_Shield_08",
    "Interface\\Icons\\INV_Shield_09",
    "Interface\\Icons\\INV_Shield_10",
    "Interface\\Icons\\INV_Shield_11",
}

TradeBoard.Quality = {
    [1] = { name = "Common", r = 1.00, g = 1.00, b = 1.00, hex = "ffffffff" },
    [2] = { name = "Uncommon / Magic", r = 0.12, g = 1.00, b = 0.12, hex = "ff1eff00" },
    [3] = { name = "Rare", r = 0.20, g = 0.50, b = 1.00, hex = "ff3399ff" },
    [4] = { name = "Epic", r = 0.70, g = 0.30, b = 1.00, hex = "ffb048ff" },
    [5] = { name = "Legendary", r = 1.00, g = 0.50, b = 0.05, hex = "ffff8000" },
}

TradeBoard.Categories = {
    "All Items",
    "Weapons",
    "Armor",
    "Containers",
    "Consumables",
    "Trade Goods",
    "Recipes",
    "Projectiles",
    "Quivers",
    "Miscellaneous",
}

TradeBoard.Subcategories = {
    Weapons = { "2H", "1H", "Swords", "Axe", "Maces", "Daggers", "Staves", "Fists", "Ranged" },
    Armor = { "Cloth", "Leather", "Mail", "Plate", "Shields" },
}

TradeBoard.State = {
    activeTab = "Browse",
    category = "All Items",
    categoryView = "root",
    subCategory = nil,
    myLevelRange = nil,
    onlineOnly = 1,
    listingType = "ALL",
    levelType = "all",
    minLevel = 0,
    maxLevel = 0,
    search = "",
    rarities = {
        [1] = 1,
        [2] = 1,
        [3] = 1,
        [4] = 1,
        [5] = 1,
    },
    browseOffset = 0,
    selectedListing = nil,
    myListingOffset = 0,
    selectedChain = nil,
    chainOffset = 0,
    chainOrderOffset = 0,
    selectedMyListing = nil,
    profession = "All Services",
    professionOffset = 0,
    selectedService = nil,
    guildFilter = nil,
    sortKey = "totalPrice",
    sortAscending = 1,
    worldOffset = 0,
    worldSearch = "",
    worldType = "ALL",
    worldChannel = "ALL",
    wantedOffset = 0,
    professionSearch = "",
    professionSource = "ALL",
    professionOnlineOnly = nil,
}

function TradeBoard:GetPlayerLevel()
    local level = tonumber(UnitLevel("player"))
    if level and level > 0 and (not self.PlayerLevel or level > self.PlayerLevel) then
        self.PlayerLevel = level
    end
    return self.PlayerLevel or 1
end

function TradeBoard:SetPlayerLevel(level)
    level = tonumber(level)
    if level and level > 0 then
        self.PlayerLevel = level
    end
    return self:GetPlayerLevel()
end

function TradeBoard:GetTraderRange()
    local level = self:GetPlayerLevel()
    local low = level - 5
    local high = level + 5
    if low < 1 then
        low = 1
    end
    if high > 60 then
        high = 60
    end
    return low, high
end

function TradeBoard:GetTraderRangeLabel()
    local low, high = self:GetTraderRange()
    return "My level range (" .. low .. "-" .. high .. ")"
end

function TradeBoard:GetWallTime()
    if type(time) == "function" then
        local now = tonumber(time())
        if now and now > 0 then
            return now
        end
    end
    return math.floor(GetTime())
end

function TradeBoard:FormatLastSeen(timestamp)
    timestamp = tonumber(timestamp)
    if not timestamp then
        return "unknown"
    end
    local elapsed = self:GetWallTime() - timestamp
    if elapsed < 0 then
        elapsed = 0
    end
    if elapsed < 60 then
        return "<1m"
    elseif elapsed < 3600 then
        return math.floor(elapsed / 60) .. "m"
    elseif elapsed < 86400 then
        return math.floor(elapsed / 3600) .. "h"
    end
    return math.floor(elapsed / 86400) .. "d"
end

function TradeBoard:GetPlayerGuildName()
    local guildName = GetGuildInfo("player")
    return guildName or ""
end

function TradeBoard:IsWorldChannel(channelName)
    local name = string.lower(channelName or "")
    name = string.gsub(name, "^%d+%.%s*", "")
    return name == "world"
end

function TradeBoard:IsTradeChannel(channelName)
    local name = string.lower(channelName or "")
    name = string.gsub(name, "^%d+%.%s*", "")
    return name == "trade" or string.find(name, "^trade%s*%-") ~= nil
end

function TradeBoard:GetWorldMessageType(message)
    local padded = " " .. string.upper(message or "") .. " "
    if string.find(padded, "[%s%p]WTB[%s%p]") then return "WTB" end
    if string.find(padded, "[%s%p]WTS[%s%p]") then return "WTS" end
    if string.find(padded, "[%s%p]LFW[%s%p]") then return "LFW" end
    return nil
end

function TradeBoard:GetWorldMessageID(message, sender, channelName, timestamp)
    local source = string.lower((sender or "") .. "|" .. (channelName or "") .. "|" .. (message or ""))
    local hash = 5381
    local i
    for i = 1, string.len(source) do hash = math.mod((hash * 33) + string.byte(source, i), 2147483647) end
    return tostring(math.floor((tonumber(timestamp) or self:GetWallTime()) / 60)) .. ":" .. tostring(hash)
end

function TradeBoard:ExtractWorldItemLinks(message)
    local links = {}
    local seen = {}
    local link
    for link in string.gfind(message or "", "(|c%x+|Hitem:[^|]+|h%[[^]]+%]|h|r)") do
        if not seen[link] then seen[link] = 1; table.insert(links, link) end
    end
    return links
end

function TradeBoard:GetWorldMessageSegments(message)
    local segments = {}
    local text = message or ""
    local cursor = 1
    while cursor <= string.len(text) do
        local first, last, link = string.find(text, "(|c%x+|Hitem:[^|]+|h%[[^]]+%]|h|r)", cursor)
        if not first then
            table.insert(segments, { text = string.sub(text, cursor) })
            break
        end
        if first > cursor then
            table.insert(segments, { text = string.sub(text, cursor, first - 1) })
        end
        table.insert(segments, { text = link, itemLink = link })
        cursor = last + 1
    end
    if table.getn(segments) == 0 then table.insert(segments, { text = text }) end
    return segments
end

function TradeBoard:OpenWorldWhisper(name)
    if not name or name == "" or not ChatFrame_OpenChat then return end
    ChatFrame_OpenChat("/w " .. name .. " ")
    self:SetStatus("Whisper opened for " .. name .. ".")
end

function TradeBoard:GetWhoCooldownRemaining()
    return math.max(0, math.ceil((self.manualWhoReadyAt or 0) - GetTime()))
end

function TradeBoard:RequestManualWho(name)
    if not name or name == "" or not SendWho then return nil end
    local remaining = self:GetWhoCooldownRemaining()
    if remaining > 0 then
        self:SetStatus("Who search is ready in " .. remaining .. "s.")
        return nil
    end
    name = string.gsub(name, '"', "")
    if name == "" then return nil end
    self.PendingManualWhoName = string.lower(name)
    self.pendingManualWhoStarted = GetTime()
    self.manualWhoReadyAt = GetTime() + self.WHO_COOLDOWN
    if SetWhoToUI then SetWhoToUI(1) end
    SendWho('n-"' .. name .. '"')
    self:SetStatus("Who search sent for " .. name .. ".")
    if self.RefreshWhoButtons then self:RefreshWhoButtons() end
    return 1
end

function TradeBoard:GetKnownTraderInfo(name)
    local key = string.lower(name or "")
    if key == string.lower(UnitName("player") or "") then
        return self:GetPlayerLevel(), self:GetPlayerGuildName()
    end
    local knownGuild = ""
    if TradeBoardDB and TradeBoardDB.worldPeople and TradeBoardDB.worldPeople[key] then
        local person = TradeBoardDB.worldPeople[key]
        knownGuild = person.guild or ""
        local level = tonumber(person.level)
        if level and level > 0 then return level, knownGuild end
    end
    if self.Network and self.Network.peers and self.Network.peers[key] then
        local peer = self.Network.peers[key]
        if knownGuild == "" then knownGuild = peer.guild or "" end
        local level = tonumber(peer.level)
        if level and level > 0 then return level, knownGuild end
    end
    local i
    for i = 1, table.getn(self.Listings) do
        local listing = self.Listings[i]
        if string.lower(listing.trader or "") == key then
            if knownGuild == "" then knownGuild = listing.guild or "" end
            local level = tonumber(listing.traderLevel)
            if level and level > 0 then return level, knownGuild end
        end
    end
    for i = 1, table.getn(self.Services) do
        local service = self.Services[i]
        if string.lower(service.trader or "") == key then
            if knownGuild == "" then knownGuild = service.guild or "" end
            local level = tonumber(service.level)
            if not level or level < 1 then level = tonumber(service.traderLevel) end
            if level and level > 0 then return level, knownGuild end
        end
    end
    for i = 1, table.getn(self.WorldLog or {}) do
        local entry = self.WorldLog[i]
        if string.lower(entry.sender or "") == key then
            if knownGuild == "" then knownGuild = entry.guild or "" end
            local level = tonumber(entry.level)
            if level and level > 0 then return level, knownGuild end
        end
    end
    return nil, knownGuild
end

function TradeBoard:InitializeWorldLog()
    if self.worldLogInitialized and self.WorldLog then return end
    if not TradeBoardDB then TradeBoardDB = {} end
    if type(TradeBoardDB.worldLog) ~= "table" then TradeBoardDB.worldLog = {} end
    if type(TradeBoardDB.worldPeople) ~= "table" then TradeBoardDB.worldPeople = {} end
    self.WorldLog = TradeBoardDB.worldLog
    local firstInitialization = not self.worldLogInitialized
    local i
    for i = 1, table.getn(self.WorldLog) do
        local entry = self.WorldLog[i]
        if type(entry) == "table" then
            if type(entry.items) ~= "table" then entry.items = self:ExtractWorldItemLinks(entry.message) end
            entry.channel = entry.channel or "World"
            entry.id = entry.id or self:GetWorldMessageID(entry.message, entry.sender, entry.channel, entry.timestamp)
        end
    end
    self:PruneWorldLog()
    self.worldLogInitialized = 1
    if firstInitialization and self.RebuildChatOffers then self:RebuildChatOffers() end
end

function TradeBoard:CaptureWorldMessage(message, sender, channelName)
    local channel
    if self:IsWorldChannel(channelName) then channel = "World"
    elseif self:IsTradeChannel(channelName) then channel = "Trade"
    else return end
    local kind = self:GetWorldMessageType(message)
    if not kind then return end
    if not self.WorldLog then self:InitializeWorldLog() end
    local level, guild = self:GetKnownTraderInfo(sender)
    local now = self:GetWallTime()
    local entry = {
        timestamp = now, type = kind, sender = sender or "Unknown", channel = channel,
        level = level, guild = guild or "", message = message or "",
        items = self:ExtractWorldItemLinks(message),
    }
    local known = TradeBoardDB.worldPeople[string.lower(sender or "")]
    entry.class = known and known.class or ""
    entry.id = self:GetWorldMessageID(entry.message, entry.sender, entry.channel, entry.timestamp)
    local i
    for i = 1, table.getn(self.WorldLog) do if self.WorldLog[i].id == entry.id then return end end
    table.insert(self.WorldLog, entry)
    self:PruneWorldLog()
    if self.ImportWorldEntry then self:ImportWorldEntry(entry) end
    if self.CheckWantedEntry then self:CheckWantedEntry(entry) end
    if self.QueueWorldAnnouncement then self:QueueWorldAnnouncement(entry, 4 + (math.random() * 14)) end
    if self.UpdateWorldLog then self:UpdateWorldLog() end
end

function TradeBoard:PruneWorldLog()
    if not self.WorldLog then return end
    local cutoff = self:GetWallTime() - self.WORLD_LOG_TTL
    local i
    for i = table.getn(self.WorldLog), 1, -1 do
        local entry = self.WorldLog[i]
        if type(entry) ~= "table" or (tonumber(entry.timestamp) or 0) < cutoff then table.remove(self.WorldLog, i) end
    end
    while table.getn(self.WorldLog) > self.MAX_WORLD_LOGS do table.remove(self.WorldLog, 1) end
end

function TradeBoard:RememberWorldPerson(name, guild, level, class, verifiedAt)
    if not name or name == "" then return end
    if not self.WorldLog or not TradeBoardDB or not TradeBoardDB.worldPeople then self:InitializeWorldLog() end
    local key = string.lower(name)
    local existing = TradeBoardDB.worldPeople[key] or {}
    local seenAt = tonumber(verifiedAt) or self:GetWallTime()
    local incomingLevel = tonumber(level)
    if not incomingLevel or incomingLevel < 1 then incomingLevel = nil end
    -- Relayed chat often has no identity, or predates a manual WHO result.
    -- It may fill a missing value, but must never replace newer verified data.
    if (tonumber(existing.seenAt) or 0) > seenAt then
        guild = existing.guild ~= "" and existing.guild or guild
        incomingLevel = tonumber(existing.level) or incomingLevel
        class = existing.class ~= "" and existing.class or class
        seenAt = existing.seenAt
    end
    TradeBoardDB.worldPeople[key] = {
        name = name or existing.name,
        guild = guild and guild ~= "" and guild or existing.guild or "",
        level = incomingLevel or existing.level,
        class = class and class ~= "" and class or existing.class or "",
        seenAt = seenAt,
    }
    local person = TradeBoardDB.worldPeople[key]
    local i
    for i = 1, table.getn(self.WorldLog or {}) do
        local entry = self.WorldLog[i]
        if string.lower(entry.sender or "") == key then
            entry.guild = person.guild or entry.guild or ""
            entry.level = person.level or entry.level
            entry.class = person.class or entry.class or ""
        end
    end
    for i = 1, table.getn(self.Listings or {}) do
        local listing = self.Listings[i]
        if string.lower(listing.trader or "") == key then listing.guild = person.guild; listing.traderLevel = person.level or listing.traderLevel; listing.class = person.class end
    end
    for i = 1, table.getn(self.Services or {}) do
        local service = self.Services[i]
        if string.lower(service.trader or "") == key then service.guild = person.guild; service.level = person.level or service.level; service.class = person.class end
    end
end

function TradeBoard:GetFilteredWorldLog()
    local result = {}
    local needle = string.lower(self.State.worldSearch or "")
    local i
    for i = 1, table.getn(self.WorldLog or {}) do
        local entry = self.WorldLog[i]
        local typeMatches = self.State.worldType == "ALL" or entry.type == self.State.worldType
        local channelMatches = self.State.worldChannel == "ALL" or entry.channel == self.State.worldChannel
        local text = string.lower((entry.sender or "") .. " " .. (entry.guild or "") .. " " .. (entry.message or ""))
        if typeMatches and channelMatches and (needle == "" or string.find(text, needle, 1, 1)) then table.insert(result, entry) end
    end
    return result
end

function TradeBoard:GetGuildSigilTexture(guildName)
    local normalized = string.lower(guildName or "")
    local count = table.getn(self.GuildSigilTextures)
    local hash = 0
    local i
    for i = 1, string.len(normalized) do
        hash = math.mod((hash * 33) + string.byte(normalized, i), count)
    end
    return self.GuildSigilTextures[hash + 1]
end

function TradeBoard:FormatMoney(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.floor(math.mod(copper, 10000) / 100)
    local coins = math.mod(copper, 100)
    local result = ""

    if gold > 0 then
        result = gold .. "g "
    end
    if silver > 0 or gold > 0 then
        result = result .. silver .. "s "
    end
    return result .. coins .. "c"
end

function TradeBoard:ColorText(text, quality)
    local info = self.Quality[quality] or self.Quality[1]
    return "|c" .. info.hex .. text .. "|r"
end

function TradeBoard:NormalizeQuality(quality)
    quality = tonumber(quality) or 1
    if quality < 1 then
        return 1
    elseif quality > 5 then
        return 5
    end
    return quality
end

function TradeBoard:GetListingItemLink(listing)
    if listing and listing.itemLink then
        return listing.itemLink
    end
    if not listing or not listing.itemID then
        return nil
    end
    local info = self.Quality[listing.quality] or self.Quality[1]
    return "|c" .. info.hex .. "|Hitem:" .. listing.itemID .. ":0:0:0|h[" .. listing.name .. "]|h|r"
end

function TradeBoard:GetListingTooltipHyperlink(listing)
    local link = self:GetListingItemLink(listing)
    if not link then
        return nil
    end
    local _, _, hyperlink = string.find(link, "|H([^|]+)|h")
    if hyperlink then
        return hyperlink
    end
    if string.find(link, "^item:") then
        return link
    end
    return nil
end

function TradeBoard:ListingHasTag(listing, tag)
    if tag == "Ranged" and listing.tags then
        if listing.tags.Ranged or listing.tags["Ranged (Bow/Xbow/Gun)"] or listing.tags["Ranged (Box/Xbox/Gun)"] then
            return 1
        end
    end
    return listing.tags and listing.tags[tag]
end

function TradeBoard:IsListingVisible(listing)
    local state = self.State

    if state.category ~= "All Items" and listing.category ~= state.category then
        return nil
    end

    if state.subCategory and not self:ListingHasTag(listing, state.subCategory) then
        return nil
    end

    if not state.rarities[listing.quality] then
        return nil
    end

    if state.listingType ~= "ALL" and listing.orderType ~= state.listingType then
        return nil
    end

    if state.onlineOnly and not listing.online then
        return nil
    end

    local traderLevel = tonumber(listing.traderLevel) or 0
    if state.myLevelRange and traderLevel > 0 then
        local low, high = self:GetTraderRange()
        if traderLevel < low or traderLevel > high then
            return nil
        end
    end

    if state.levelType == "required" or state.levelType == "item" then
        local level = tonumber(listing.requiredLevel) or 0
        if state.levelType == "item" then level = tonumber(listing.itemLevel) or 0 end
        if state.minLevel and state.minLevel > 0 and level < state.minLevel then return nil end
        if state.maxLevel and state.maxLevel > 0 and level > state.maxLevel then return nil end
    end

    if state.search and state.search ~= "" then
        local needle = string.lower(state.search)
        local haystack = string.lower(listing.name or "")
        if not string.find(haystack, needle, 1, 1) then
            return nil
        end
    end

    return 1
end

local function NormalizeBrowseName(value)
    local text = string.gsub(value or "", "|c%x%x%x%x%x%x%x%x", "")
    text = string.gsub(text, "|r", "")
    text = string.gsub(text, "%s+", " ")
    text = string.gsub(text, "^%s*(.-)%s*$", "%1")
    return string.lower(text)
end

function TradeBoard:GetBrowseListingKey(listing)
    local itemName = NormalizeBrowseName(listing.name)
    local traderName = NormalizeBrowseName(listing.trader or listing.owner)
    return itemName .. "\031" .. traderName
end

function TradeBoard:IsPreferredBrowseListing(candidate, current)
    -- Published quantities/prices are explicitly entered by the seller.
    local candidatePublished = candidate.source ~= "CHAT"
    local currentPublished = current.source ~= "CHAT"
    if candidatePublished ~= currentPublished then return candidatePublished end
    local candidateAt = tonumber(candidate.lastSeenAt) or 0
    local currentAt = tonumber(current.lastSeenAt) or 0
    if candidateAt ~= currentAt then return candidateAt > currentAt end
    -- Equal timestamps must produce the same result regardless of peer order.
    return tostring(candidate.id or "") > tostring(current.id or "")
end

function TradeBoard:GetFilteredListings()
    local filtered = {}
    local resultIndex = {}
    local allKeys = {}
    local uniqueTotal = 0
    local wallNow = self:GetWallTime()
    local count = table.getn(self.Listings)
    local i

    for i = 1, count do
        -- Resolve cached item data before category/rarity/level filtering. A row
        -- excluded here never reaches the UI, so rendering cannot repair it.
        local listing = self.Listings[i]
        if self.RefreshListingMetadata then self:RefreshListingMetadata(listing) end
        if not (listing.source == "CHAT" and listing.expiresAt and wallNow >= listing.expiresAt) then
            local key = self:GetBrowseListingKey(listing)
            if not allKeys[key] then allKeys[key] = 1; uniqueTotal = uniqueTotal + 1 end
            -- Fold only the Browse result. Keep protocol IDs, personal listings
            -- and the original archive intact for withdrawals and Wanted filters.
            if self:IsListingVisible(listing) then
                local index = resultIndex[key]
                if not index then
                    table.insert(filtered, listing)
                    resultIndex[key] = table.getn(filtered)
                elseif self:IsPreferredBrowseListing(listing, filtered[index]) then
                    filtered[index] = listing
                end
            end
        end
    end

    filtered.totalUnique = uniqueTotal
    if self.State.selectedListing then
        local index = resultIndex[self:GetBrowseListingKey(self.State.selectedListing)]
        self.State.selectedListing = index and filtered[index] or nil
    end

    local sortKey = self.State.sortKey
    local ascending = self.State.sortAscending

    table.sort(filtered, function(a, b)
        local aValue = a[sortKey]
        local bValue = b[sortKey]

        if sortKey == "name" or sortKey == "trader" or sortKey == "guild" or sortKey == "class" or sortKey == "source" then
            aValue = string.lower(aValue or "")
            bValue = string.lower(bValue or "")
        elseif sortKey == "online" then
            aValue = a.online and 1 or 0
            bValue = b.online and 1 or 0
        else
            aValue = aValue or 0
            bValue = bValue or 0
        end

        if aValue == bValue then
            local aName = string.lower(a.name or "")
            local bName = string.lower(b.name or "")
            if aName == bName then
                return string.lower(a.trader or "") < string.lower(b.trader or "")
            end
            return aName < bName
        end

        if ascending then
            return aValue < bValue
        end
        return aValue > bValue
    end)

    return filtered
end

function TradeBoard:SetSort(sortKey)
    if self.State.sortKey == sortKey then
        if self.State.sortAscending then
            self.State.sortAscending = nil
        else
            self.State.sortAscending = 1
        end
    else
        self.State.sortKey = sortKey
        self.State.sortAscending = 1
    end
    self.State.browseOffset = 0
end

function TradeBoard:ResetFilters()
    local state = self.State
    state.category = "All Items"
    state.categoryView = "root"
    state.subCategory = nil
    state.myLevelRange = nil
    state.onlineOnly = nil
    state.listingType = "ALL"
    state.levelType = "all"
    state.minLevel = 0
    state.maxLevel = 0
    state.search = ""
    state.browseOffset = 0

    local quality
    for quality = 1, 5 do
        state.rarities[quality] = 1
    end
end

function TradeBoard:SampleMemoryUsage()
    local now = GetTime()
    if self.memorySample and now < (self.nextMemorySampleAt or 0) then return self.memorySample end
    self.nextMemorySampleAt = now + self.MEMORY_SAMPLE_INTERVAL
    local sample = { sampledAt = now, scope = "unavailable" }
    -- Per-addon profiling is supplied by newer/extended clients. Never label
    -- the shared Lua heap as TradeBoard's own memory on stock Vanilla.
    if type(UpdateAddOnMemoryUsage) == "function" and type(GetAddOnMemoryUsage) == "function" then
        local updated = pcall(UpdateAddOnMemoryUsage)
        if updated then
            local ok, value = pcall(GetAddOnMemoryUsage, "HC-Tradeboard")
            local kilobytes = ok and tonumber(value)
            if kilobytes and kilobytes >= 0 then sample.scope = "addon"; sample.mb = kilobytes / 1024 end
        end
    end
    if not sample.mb and type(gcinfo) == "function" then
        local ok, value = pcall(gcinfo)
        local kilobytes = ok and tonumber(value)
        if kilobytes and kilobytes >= 0 then sample.scope = "lua"; sample.mb = kilobytes / 1024 end
    end
    self.memorySample = sample
    return sample
end

function TradeBoard:SetStatus(text)
    if self.Frames and self.Frames.statusText then
        self.Frames.statusText:SetText(text)
    end
end
