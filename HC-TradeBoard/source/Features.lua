local TB = TradeBoard

TB.MAX_WANTED = 50
TB.MAX_CHAIN_ORDERS = 100
TB.CHAIN_ORDER_TTL = 604800
TB.Wanted = {}
TB.ChainOrders = {}
TB.ChainVolunteers = {}

local function Lower(value)
    return string.lower(value or "")
end

local function Trim(value)
    value = string.gsub(value or "", "^%s+", "")
    return string.gsub(value, "%s+$", "")
end

local function Plain(value)
    value = string.gsub(value or "", "|c%x%x%x%x%x%x%x%x", "")
    value = string.gsub(value, "|H[^|]+|h", "")
    value = string.gsub(value, "|[hr]", "")
    value = string.gsub(value, "%[", "")
    value = string.gsub(value, "%]", "")
    value = string.gsub(value, "%s+", " ")
    return Lower(Trim(value))
end

function TB:InitializeFeatureData()
    TradeBoardDB = TradeBoardDB or {}
    TradeBoardDB.settings = TradeBoardDB.settings or {}
    TradeBoardDB.lootMuteUntil = TradeBoardDB.lootMuteUntil or {}
    TradeBoardDB.wanted = TradeBoardDB.wanted or {}
    TradeBoardDB.chainOrders = TradeBoardDB.chainOrders or {}
    TradeBoardDB.chainVolunteers = TradeBoardDB.chainVolunteers or {}
    self.Wanted = TradeBoardDB.wanted
    self.ChainOrders = TradeBoardDB.chainOrders
    self.ChainVolunteers = TradeBoardDB.chainVolunteers
    if TradeBoardDB.settings.wantedNotifications == nil then TradeBoardDB.settings.wantedNotifications = 1 end
    self:PruneFeatureData()
end

function TB:PruneFeatureData()
    local now = self:GetWallTime()
    local i
    for i = table.getn(self.ChainOrders or {}), 1, -1 do
        local order = self.ChainOrders[i]
        if type(order) ~= "table" or now - (tonumber(order.updatedAt) or 0) > self.CHAIN_ORDER_TTL then
            table.remove(self.ChainOrders, i)
        end
    end
    while table.getn(self.ChainOrders or {}) > self.MAX_CHAIN_ORDERS do table.remove(self.ChainOrders, 1) end
    while table.getn(self.Wanted or {}) > self.MAX_WANTED do table.remove(self.Wanted, 1) end
    local key, volunteer
    for key, volunteer in pairs(self.ChainVolunteers or {}) do
        if type(volunteer) ~= "table" or now - (tonumber(volunteer.updatedAt) or 0) > self.CHAIN_ORDER_TTL then
            self.ChainVolunteers[key] = nil
        end
    end
end

function TB:IsLootSourceEnabled(channel)
    self:InitializeFeatureData()
    local key = channel == "Guild" and "Guild" or "Public"
    local untilAt = tonumber(TradeBoardDB.lootMuteUntil[key]) or 0
    if untilAt < 0 then return nil end
    if untilAt > self:GetWallTime() then return nil end
    if untilAt ~= 0 then TradeBoardDB.lootMuteUntil[key] = 0 end
    return 1
end

function TB:SetLootMute(channel, seconds)
    self:InitializeFeatureData()
    local key = channel == "Guild" and "Guild" or "Public"
    seconds = tonumber(seconds) or 0
    -- A deliberate settings action supersedes the legacy global /tb loot off.
    TradeBoardDB.guildLootEnabled = 1
    TradeBoardDB.lootMuteUntil[key] = seconds < 0 and -1 or (seconds > 0 and self:GetWallTime() + seconds or 0)
    if self.GuildLoot and self.GuildLoot.active then
        local activeKey = self.GuildLoot.active.channel == "Guild" and "Guild" or "Public"
        if activeKey == key and not self:IsLootSourceEnabled(self.GuildLoot.active.channel) then self:DismissGuildLoot() end
    end
    if self.UpdateSettings then self:UpdateSettings() end
end

function TB:GetLootMuteLabel(channel)
    self:InitializeFeatureData()
    local key = channel == "Guild" and "Guild" or "Public"
    local untilAt = tonumber(TradeBoardDB.lootMuteUntil[key]) or 0
    if untilAt < 0 then return "Muted until enabled" end
    local remaining = untilAt - self:GetWallTime()
    if remaining <= 0 then return "Enabled" end
    if remaining >= 3600 then return "Muted " .. math.ceil(remaining / 3600) .. "h" end
    return "Muted " .. math.ceil(remaining / 60) .. "m"
end

function TB:AddWanted(value)
    self:InitializeFeatureData()
    value = Trim(value)
    if value == "" then return nil, "Enter an item name or item link." end
    local link = string.match and string.match(value, "(|c%x+|Hitem:[^|]+|h%[[^]]+%]|h|r)") or nil
    if not link then local _, _, found = string.find(value, "(|c%x+|Hitem:[^|]+|h%[[^]]+%]|h|r)"); link = found end
    local name = link and self:ExtractItemName(link) or value
    local normalized = Plain(name)
    if normalized == "" then return nil, "That subscription has no searchable name." end
    local i
    for i = 1, table.getn(self.Wanted) do
        if self.Wanted[i].normalized == normalized then return nil, "That item is already subscribed." end
    end
    local wanted = { id = tostring(self:GetWallTime()) .. ":" .. tostring(math.random(1000, 9999)), name = name, itemLink = link, normalized = normalized, enabled = 1, createdAt = self:GetWallTime() }
    table.insert(self.Wanted, wanted)
    if self.UpdateWanted then self:UpdateWanted() end
    return wanted
end

function TB:RemoveWanted(id)
    local i
    for i = table.getn(self.Wanted or {}), 1, -1 do
        if self.Wanted[i].id == id then table.remove(self.Wanted, i); break end
    end
    if self.UpdateWanted then self:UpdateWanted() end
end

function TB:ToggleWanted(id)
    local i
    for i = 1, table.getn(self.Wanted or {}) do
        if self.Wanted[i].id == id then self.Wanted[i].enabled = self.Wanted[i].enabled and nil or 1; break end
    end
    if self.UpdateWanted then self:UpdateWanted() end
end

function TB:CheckWantedEntry(entry)
    if not entry or entry.type ~= "WTS" then return end
    self:InitializeFeatureData()
    if not TradeBoardDB.settings.wantedNotifications or (self.IsGuildLootEnabled and not self:IsGuildLootEnabled()) then return end
    if not self:IsLootSourceEnabled(entry.channel) then return end
    local haystack = Plain(entry.message)
    local links = entry.items or self:ExtractWorldItemLinks(entry.message)
    if table.getn(links) == 0 then return end
    self.wantedMatchesSeen = self.wantedMatchesSeen or {}
    local i
    for i = 1, table.getn(self.Wanted) do
        local wanted = self.Wanted[i]
        local matched = wanted.enabled and not wanted.itemLink and string.find(haystack, wanted.normalized, 1, 1)
        if wanted.enabled and wanted.itemLink then
            local linkedIndex
            for linkedIndex = 1, table.getn(links) do
                if Plain(self:ExtractItemName(links[linkedIndex])) == wanted.normalized then matched = 1; break end
            end
        end
        if matched then
            local key = tostring(entry.id) .. ":" .. tostring(wanted.id)
            if not self.wantedMatchesSeen[key] then
                self.wantedMatchesSeen[key] = self:GetWallTime()
                local matchingLinks = {}
                local linkIndex
                for linkIndex = 1, table.getn(links) do
                    local linkedName = Plain(self:ExtractItemName(links[linkIndex]))
                    if (wanted.itemLink and linkedName == wanted.normalized) or (not wanted.itemLink and string.find(linkedName, wanted.normalized, 1, 1)) then table.insert(matchingLinks, links[linkIndex]) end
                end
                if table.getn(matchingLinks) == 0 then matchingLinks = links end
                self:QueueWantedPopup(entry, wanted, matchingLinks)
            end
        end
    end
end

function TB:QueueWantedPopup(entry, wanted, links)
    if not self.GuildLoot or not self.ShowGuildLootPopup then return end
    local offer = { author = Lower(entry.sender), sender = entry.sender, kind = "WANTED", links = links, at = GetTime(), message = entry.message,
        channel = entry.channel or "World", wanted = wanted.name, channelNumber = entry.channel == "Trade" and 2 or 4 }
    table.insert(self.GuildLoot.queue, offer)
    while table.getn(self.GuildLoot.queue) > 20 do table.remove(self.GuildLoot.queue, 1) end
    self:ShowGuildLootPopup()
end

function TB:GetOwnVolunteer()
    self:InitializeFeatureData()
    return self.ChainVolunteers[Lower(UnitName("player") or "")]
end

function TB:SetChainVolunteer(enabled)
    self:InitializeFeatureData()
    local name = UnitName("player") or "Unknown"
    local level = self:GetPlayerLevel()
    local low = math.max(1, level - 5)
    local high = math.min(60, level + 5)
    local volunteer = { name = name, level = level, low = low, high = high, enabled = enabled and 1 or nil, updatedAt = self:GetWallTime() }
    self.ChainVolunteers[Lower(name)] = volunteer
    if self.QueueVolunteerAnnouncement then self:QueueVolunteerAnnouncement(volunteer, 0) end
    if self.UpdateDeliveryDesk then self:UpdateDeliveryDesk() end
end

function TB:UpsertChainOrder(order)
    self:InitializeFeatureData()
    local i
    for i = 1, table.getn(self.ChainOrders) do
        if self.ChainOrders[i].id == order.id then
            if (tonumber(order.updatedAt) or 0) >= (tonumber(self.ChainOrders[i].updatedAt) or 0) then self.ChainOrders[i] = order end
            return i
        end
    end
    table.insert(self.ChainOrders, order)
    self:PruneFeatureData()
    return table.getn(self.ChainOrders)
end

function TB:CreateChainOrder(chainOwner, itemText, quantity, fromName, toName, note)
    self:InitializeFeatureData()
    itemText = Trim(itemText)
    if itemText == "" then return nil, "Enter an item or item link." end
    local owner = UnitName("player") or "Unknown"
    local now = self:GetWallTime()
    local order = { id = Lower(owner) .. ":" .. tostring(now) .. ":" .. tostring(math.random(100, 999)), chainOwner = chainOwner or owner,
        customer = owner, item = itemText, quantity = math.max(1, tonumber(quantity) or 1), fromName = Trim(fromName) ~= "" and Trim(fromName) or owner,
        toName = Trim(toName), note = Trim(note), status = "REQUESTED", updatedAt = now, updatedBy = owner }
    self:UpsertChainOrder(order)
    if self.QueueChainOrderAnnouncement then self:QueueChainOrderAnnouncement(order, 0) end
    if self.UpdateDeliveryDesk then self:UpdateDeliveryDesk() end
    return order
end

function TB:AdvanceChainOrder(order)
    if not order or not self:CanAdvanceChainOrder(order) then return nil end
    if order.status == "REQUESTED" then order.status = "PICKED UP"
    elseif order.status == "PICKED UP" then order.status = "DELIVERED"
    else order.status = "REQUESTED" end
    order.updatedAt = self:GetWallTime()
    order.updatedBy = UnitName("player") or "Unknown"
    if self.QueueChainOrderAnnouncement then self:QueueChainOrderAnnouncement(order, 0) end
    if self.UpdateDeliveryDesk then self:UpdateDeliveryDesk() end
    return 1
end

function TB:CanAdvanceChainOrder(order)
    if not order then return nil end
    local player = Lower(UnitName("player") or "")
    return player == Lower(order.customer) or player == Lower(order.chainOwner) or player == Lower(order.fromName) or player == Lower(order.toName)
end
