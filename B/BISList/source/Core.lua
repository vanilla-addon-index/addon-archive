-- BISList Core: Data management and auto-detection

BISList = {}
BISList.Version = "1.0"

-- Equipment slot definitions (using inventory slot IDs)
BISList.Slots = {
    {id = 1, name = "Head"},
    {id = 2, name = "Neck"},
    {id = 3, name = "Shoulder"},
    {id = 15, name = "Back"},
    {id = 5, name = "Chest"},
    {id = 9, name = "Wrist"},
    {id = 10, name = "Hands"},
    {id = 6, name = "Waist"},
    {id = 7, name = "Legs"},
    {id = 8, name = "Feet"},
    {id = 11, name = "Finger"},
    {id = 13, name = "Trinket"},
    {id = 16, name = "Main Hand"},
    {id = 19, name = "One-Hand"},
    {id = 17, name = "Off Hand"},
    {id = 18, name = "Ranged"},
}

-- Initialize saved variables
function BISList:Initialize()
    if not BISListDB then
        BISListDB = {}
    end

    local playerName = UnitName("player")
    local realmName = GetRealmName()
    local charKey = playerName .. "-" .. realmName

    if not BISListDB[charKey] then
        -- New character - create default structure
        BISListDB[charKey] = {
            lists = {
                ["Leveling"] = {},
                ["PvE"] = {},
                ["PvP"] = {}
            },
            currentList = "PvE",
            listOrder = {"Leveling", "PvE", "PvP"}
        }

        -- Initialize slots for each default list
        for listName, _ in pairs(BISListDB[charKey].lists) do
            for _, slot in ipairs(self.Slots) do
                BISListDB[charKey].lists[listName][slot.id] = {}
            end
        end
    else
        -- Existing character - migrate old data structure if needed
        if not BISListDB[charKey].lists then
            -- Old data structure - migrate to new lists structure
            local oldData = {}
            -- Copy old slot data
            for slotId, items in pairs(BISListDB[charKey]) do
                if type(slotId) == "number" then
                    oldData[slotId] = items
                end
            end

            -- Create new lists structure
            BISListDB[charKey].lists = {
                ["Leveling"] = {},
                ["PvE"] = {},
                ["PvP"] = {}
            }

            -- Initialize empty slots for all lists
            for listName, _ in pairs(BISListDB[charKey].lists) do
                for _, slot in ipairs(self.Slots) do
                    BISListDB[charKey].lists[listName][slot.id] = {}
                end
            end

            -- Move old data to PvE list
            if next(oldData) then
                BISListDB[charKey].lists["PvE"] = oldData
            end

            -- Clean up old numeric keys
            for slotId, _ in pairs(oldData) do
                BISListDB[charKey][slotId] = nil
            end

            BISListDB[charKey].currentList = "PvE"
            BISListDB[charKey].listOrder = {"Leveling", "PvE", "PvP"}
        end

        -- Ensure currentList exists
        if not BISListDB[charKey].currentList then
            BISListDB[charKey].currentList = "PvE"
        end

        -- Ensure listOrder exists
        if not BISListDB[charKey].listOrder then
            BISListDB[charKey].listOrder = {}
            for listName, _ in pairs(BISListDB[charKey].lists) do
                table.insert(BISListDB[charKey].listOrder, listName)
            end
        end
    end

    self.CurrentCharacter = charKey
    self.DB = BISListDB[charKey]
    self.CurrentList = BISListDB[charKey].currentList
    self.Data = BISListDB[charKey].lists[self.CurrentList]
end

-- Switch to a different list
function BISList:SetCurrentList(listName)
    if not listName or listName == "" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000BISList:|r Invalid list name")
        return false
    end

    if not self.DB.lists[listName] then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000BISList:|r List '" .. listName .. "' does not exist")
        return false
    end

    self.CurrentList = listName
    self.DB.currentList = listName
    self.Data = self.DB.lists[listName]
    return true
end

-- Get all list names in order
function BISList:GetListNames()
    return self.DB.listOrder
end

-- Create a new list
function BISList:CreateList(listName)
    if not listName or listName == "" then
        return false
    end

    if self.DB.lists[listName] then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000BISList:|r List '" .. listName .. "' already exists")
        return false
    end

    -- Create new list with empty slots
    self.DB.lists[listName] = {}
    for _, slot in ipairs(self.Slots) do
        self.DB.lists[listName][slot.id] = {}
    end

    -- Add to order
    table.insert(self.DB.listOrder, listName)

    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00BISList:|r Created list '" .. listName .. "'")
    return true
end

-- Delete a list
function BISList:DeleteList(listName)
    if not self.DB.lists[listName] then
        return false
    end

    -- Can't delete if it's the only list
    if table.getn(self.DB.listOrder) <= 1 then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000BISList:|r Cannot delete the last list")
        return false
    end

    -- Remove from lists
    self.DB.lists[listName] = nil

    -- Remove from order
    for i, name in ipairs(self.DB.listOrder) do
        if name == listName then
            table.remove(self.DB.listOrder, i)
            break
        end
    end

    -- If we deleted the current list, switch to first available
    if self.CurrentList == listName then
        self:SetCurrentList(self.DB.listOrder[1])
    end

    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00BISList:|r Deleted list '" .. listName .. "'")
    return true
end

-- Rename a list
function BISList:RenameList(oldName, newName)
    if not self.DB.lists[oldName] then
        return false
    end

    if self.DB.lists[newName] then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000BISList:|r List '" .. newName .. "' already exists")
        return false
    end

    -- Copy data to new name
    self.DB.lists[newName] = self.DB.lists[oldName]
    self.DB.lists[oldName] = nil

    -- Update order
    for i, name in ipairs(self.DB.listOrder) do
        if name == oldName then
            self.DB.listOrder[i] = newName
            break
        end
    end

    -- Update current list if needed
    if self.CurrentList == oldName then
        self.CurrentList = newName
        self.DB.currentList = newName
        self.Data = self.DB.lists[newName]
    end

    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00BISList:|r Renamed list '" .. oldName .. "' to '" .. newName .. "'")
    return true
end

-- Move an item from current list to another list
function BISList:MoveItemToList(slotId, itemId, targetListName)
    if not self.DB.lists[targetListName] then
        return false
    end

    -- Find the item in current list
    local itemData = nil
    if not self.Data[slotId] then return false end
    for i, item in ipairs(self.Data[slotId]) do
        if item.itemId == itemId then
            itemData = item
            table.remove(self.Data[slotId], i)
            break
        end
    end

    if not itemData then
        return false
    end

    -- Add to target list
    table.insert(self.DB.lists[targetListName][slotId], itemData)

    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00BISList:|r Moved item to '" .. targetListName .. "'")
    return true
end

-- Add an item to a slot
-- itemLink: full item link from shift-click
-- slotId: the equipment slot ID
-- itemName: optional pre-formatted item name (from AtlasLoot database)
-- sourceInfo: optional source info (dungeon|boss)
function BISList:AddItem(itemLink, slotId, itemName, sourceInfo)
    if not itemLink or not slotId then
        return false
    end

    -- Extract item ID from link
    local itemId = self:GetItemIdFromLink(itemLink)
    if not itemId then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000BISList:|r Invalid item link")
        return false
    end

    -- Initialize slot if it doesn't exist (for newly added slots like One-Hand)
    if not self.Data[slotId] then
        self.Data[slotId] = {}
    end

    -- Check if item already exists in this slot
    for _, item in ipairs(self.Data[slotId]) do
        if item.itemId == itemId then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000BISList:|r Item already in list")
            return false
        end
    end

    -- Add the item
    local itemData = {
        itemId = itemId,
        itemLink = itemLink,
        itemName = itemName or nil,
        sourceInfo = sourceInfo or nil,
        acquired = false,
        addedTime = time()
    }

    table.insert(self.Data[slotId], itemData)

    -- Check if already acquired
    self:CheckItemAcquired(slotId, itemId)

    -- Display message with item name if available
    local displayName = itemLink
    if itemName then
        displayName = itemName
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00BISList:|r Added " .. displayName)
    return true
end

-- Remove an item from a slot
function BISList:RemoveItem(slotId, itemId)
    if not self.Data[slotId] then return false end
    for i, item in ipairs(self.Data[slotId]) do
        if item.itemId == itemId then
            table.remove(self.Data[slotId], i)
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00BISList:|r Item removed")
            return true
        end
    end
    return false
end

-- Extract item ID from item link
function BISList:GetItemIdFromLink(itemLink)
    if not itemLink then return nil end
    local _, _, itemId = string.find(itemLink, "item:(%d+)")
    return tonumber(itemId)
end

-- Check if an item exists in a specific slot
function BISList:ItemExistsInSlot(slotId, itemId)
    if not slotId or not itemId or not self.Data[slotId] then
        return false
    end

    for _, item in ipairs(self.Data[slotId]) do
        if item.itemId == itemId then
            return true
        end
    end
    return false
end

-- Check if a specific item is acquired (in bags, bank, or equipped)
function BISList:CheckItemAcquired(slotId, itemId)
    local acquired = false

    -- Check equipped items
    for i = 0, 19 do
        local link = GetInventoryItemLink("player", i)
        if link then
            local equippedId = self:GetItemIdFromLink(link)
            if equippedId == itemId then
                acquired = true
                break
            end
        end
    end

    -- Check bags
    if not acquired then
        for bag = 0, 4 do
            for slot = 1, GetContainerNumSlots(bag) do
                local link = GetContainerItemLink(bag, slot)
                if link then
                    local bagItemId = self:GetItemIdFromLink(link)
                    if bagItemId == itemId then
                        acquired = true
                        break
                    end
                end
            end
            if acquired then break end
        end
    end

    -- Check bank (only if bank is open)
    if not acquired and BankFrame and BankFrame:IsVisible() then
        for slot = 1, GetContainerNumSlots(-1) do
            local link = GetContainerItemLink(-1, slot)
            if link then
                local bankItemId = self:GetItemIdFromLink(link)
                if bankItemId == itemId then
                    acquired = true
                    break
                end
            end
        end

        -- Check bank bags
        for bag = 5, 10 do
            for slot = 1, GetContainerNumSlots(bag) do
                local link = GetContainerItemLink(bag, slot)
                if link then
                    local bankItemId = self:GetItemIdFromLink(link)
                    if bankItemId == itemId then
                        acquired = true
                        break
                    end
                end
            end
            if acquired then break end
        end
    end

    -- Update the data
    if self.Data[slotId] then
        for _, item in ipairs(self.Data[slotId]) do
            if item.itemId == itemId then
                item.acquired = acquired
                break
            end
        end
    end

    return acquired
end

-- Scan all tracked items for acquisition status
function BISList:ScanAllItems()
    for slotId, items in pairs(self.Data) do
        for _, item in ipairs(items) do
            self:CheckItemAcquired(slotId, item.itemId)
        end
    end
end

-- Get stats: total items and acquired items
function BISList:GetStats()
    local total = 0
    local acquired = 0

    for _, items in pairs(self.Data) do
        for _, item in ipairs(items) do
            total = total + 1
            if item.acquired then
                acquired = acquired + 1
            end
        end
    end

    return acquired, total
end

-- Event handler with throttling
local eventFrame = CreateFrame("Frame")
local lastScanTime = 0
local SCAN_THROTTLE = 2 -- Only scan once every 2 seconds

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
eventFrame:RegisterEvent("BANKFRAME_OPENED")

eventFrame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "BISList" then
        BISList:Initialize()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00BISList|r v" .. BISList.Version .. " loaded. Type |cffffffff/bislist|r to open.")

    elseif event == "PLAYER_LOGIN" then
        BISList:ScanAllItems()

    elseif event == "BAG_UPDATE" or event == "UNIT_INVENTORY_CHANGED" or event == "BANKFRAME_OPENED" then
        local currentTime = GetTime()
        if BISList.Data and (currentTime - lastScanTime) >= SCAN_THROTTLE then
            lastScanTime = currentTime
            BISList:ScanAllItems()
            -- Only refresh UI if it's visible
            if BISListUI and BISListUI.Refresh and BISListUI.IsVisible and BISListUI:IsVisible() then
                BISListUI:Refresh()
            end
        end
    end
end)

-- Slash command
SLASH_BISLIST1 = "/bislist"
SLASH_BISLIST2 = "/bis"
SlashCmdList["BISLIST"] = function(msg)
    if BISListUI then
        BISListUI:Toggle()
    end
end
