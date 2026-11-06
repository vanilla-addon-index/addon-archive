--=======================================================================================
-- ChickenJockey.lua
-- Item link generator with custom name and color
-- Version 2.0
--=======================================================================================

-- Rarity color mappings (WoW 1.12)
local RARITY_COLORS = {
    [0] = { name = "Poor",       color = "|cff9d9d9d", hex = "9d9d9d" },
    [1] = { name = "Common",     color = "|cffffffff", hex = "ffffff" },
    [2] = { name = "Uncommon",   color = "|cff1eff00", hex = "1eff00" },
    [3] = { name = "Rare",       color = "|cff0070dd", hex = "0070dd" },
    [4] = { name = "Epic",       color = "|cffa335ee", hex = "a335ee" },
    [5] = { name = "Legendary",  color = "|cffff8000", hex = "ff8000" },
    [6] = { name = "Artifact",   color = "|cffe6cc80", hex = "e6cc80" },
}

-- Current item data
local currentItemData = {
    id = nil,
    name = "",
    rarity = 0, -- Default to Grey
}

-- Hidden tooltip for item queries
local hiddenTooltip = CreateFrame("GameTooltip", "ChickenJockeyHiddenTooltip", UIParent, "GameTooltipTemplate")
hiddenTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

-- Query state
local queryState = {
    active = false,
    itemId = nil,
    tries = 0,
    maxTries = 10,
    isRandom = false,
    randomTries = 0,
    maxRandomTries = 5,
}

--=======================================================================================
-- Utility Functions
--=======================================================================================

local function ShowStatus(message, color)
    color = color or {1, 1, 1}
    local statusFrame = getglobal("ChickenJockeyStatus")
    if statusFrame then
        statusFrame:SetTextColor(color[1], color[2], color[3], 1)
        statusFrame:SetText(message)
    end
end

local function GetRarityFromQuality(quality)
    -- Map GetItemInfo quality to our rarity index
    if quality == nil then return 0 end
    if quality >= 0 and quality <= 6 then
        return quality
    end
    return 0
end

local function GetQualityColorCode(rarity)
    if RARITY_COLORS[rarity] then
        return RARITY_COLORS[rarity].color
    end
    return RARITY_COLORS[0].color
end

--=======================================================================================
-- Item Query Functions
--=======================================================================================

local function RequestItemFromServer(itemId)
    -- Force server query using GameTooltip SetHyperlink (ItemStatsScanner method)
    GameTooltip:SetHyperlink("item:" .. itemId .. ":0:0:0")
    GameTooltip:Hide()
    
    -- Also request via GetItemInfo
    GetItemInfo(itemId)
end

local function CheckItemInfo(itemId)
    local name, link, quality = GetItemInfo(itemId)
    return name, quality
end

local function QueryItem(itemId, isRandom)
    if not itemId or itemId == 0 then
        ShowStatus("Invalid item number", {1, 0, 0})
        return
    end
    
    queryState.active = true
    queryState.itemId = itemId
    queryState.tries = 0
    queryState.isRandom = isRandom or false
    
    -- Update UI immediately: set Item ID and show "*Querying*"
    local numberFrame = getglobal("ChickenJockeyItemNumber")
    local nameFrame = getglobal("ChickenJockeyItemName")
    if numberFrame then numberFrame:SetText(tostring(itemId)) end
    if nameFrame then nameFrame:SetText("*Querying*") end
    
    -- Request from server
    RequestItemFromServer(itemId)
    
    -- Start checking for item info
    ShowStatus("Querying server for item " .. itemId .. "...", {1, 1, 0})
end

--=======================================================================================
-- Update Frame for Item Queries
--=======================================================================================

local updateFrame = CreateFrame("Frame")
local lastCheckTime = 0
local checkInterval = 0.5 -- Check every 0.5 seconds

-- Make sure the update frame is always running
updateFrame:Show()

updateFrame:SetScript("OnUpdate", function()
    if not queryState.active then return end
    
    local now = GetTime()
    local delta = now - lastCheckTime
    if delta < checkInterval then return end
    lastCheckTime = now
    
    queryState.tries = queryState.tries + 1
    
    local name, quality = CheckItemInfo(queryState.itemId)
    
    if name then
        -- Item found!
        currentItemData.id = queryState.itemId
        currentItemData.name = name
        currentItemData.rarity = GetRarityFromQuality(quality)
        
        -- Update UI
        local numberFrame = getglobal("ChickenJockeyItemNumber")
        local nameFrame = getglobal("ChickenJockeyItemName")
        if numberFrame then numberFrame:SetText(tostring(queryState.itemId)) end
        if nameFrame then nameFrame:SetText(name) end
        
        -- Update radio button
        ChickenJockey_SetRarity(currentItemData.rarity)
        
        ShowStatus("Item found: " .. name, {0, 1, 0})
        queryState.active = false
        
        -- If this was a random query that succeeded, we're done
        if queryState.isRandom then
            queryState.isRandom = false
            queryState.randomTries = 0
        end
    elseif queryState.tries >= queryState.maxTries then
        -- Item not found after max tries
        if queryState.isRandom and queryState.randomTries < queryState.maxRandomTries then
            -- Try another random number
            queryState.randomTries = queryState.randomTries + 1
            queryState.tries = 0
            local newRandomId = math.random(100, 60000)
            queryState.itemId = newRandomId
            
            -- Update UI immediately: set Item ID and show "*Querying*"
            local numberFrame = getglobal("ChickenJockeyItemNumber")
            local nameFrame = getglobal("ChickenJockeyItemName")
            if numberFrame then numberFrame:SetText(tostring(newRandomId)) end
            if nameFrame then nameFrame:SetText("*Querying*") end
            
            RequestItemFromServer(newRandomId)
            ShowStatus("Random item " .. newRandomId .. " not found, trying another... (" .. queryState.randomTries .. "/" .. queryState.maxRandomTries .. ")", {1, 1, 0})
        else
            -- Item not found - set Item Name to "*Does Not Exist*"
            currentItemData.id = queryState.itemId
            currentItemData.name = "*Does Not Exist*"
            currentItemData.rarity = 0  -- Default to Poor
            
            -- Update UI
            local numberFrame = getglobal("ChickenJockeyItemNumber")
            local nameFrame = getglobal("ChickenJockeyItemName")
            if numberFrame then numberFrame:SetText(tostring(queryState.itemId)) end
            if nameFrame then nameFrame:SetText("*Does Not Exist*") end
            
            -- Update radio button to Poor
            ChickenJockey_SetRarity(0)
            
            ShowStatus("Item " .. queryState.itemId .. " not found", {1, 0, 0})
            queryState.active = false
            queryState.isRandom = false
            queryState.randomTries = 0
        end
    else
        -- Still waiting, request again periodically
        if math.mod(queryState.tries, 3) == 0 then
            RequestItemFromServer(queryState.itemId)
        end
    end
end)

--=======================================================================================
-- GUI Functions
--=======================================================================================

function ChickenJockey_OnLoad()
    -- Register slash command
    SLASH_CHICKENJOCKEY1 = "/cj"
    SLASH_CHICKENJOCKEY2 = "/chickenjockey"
    SlashCmdList["CHICKENJOCKEY"] = function(msg)
        if ChickenJockeyFrame:IsVisible() then
            ChickenJockeyFrame:Hide()
        else
            ChickenJockeyFrame:Show()
        end
    end
    
    -- Make frame movable
    local mainFrame = getglobal("ChickenJockeyFrame")
    if mainFrame then
        mainFrame:SetMovable(true)
        mainFrame:RegisterForDrag("LeftButton")
        mainFrame:SetScript("OnDragStart", function()
            local frame = getglobal("ChickenJockeyFrame")
            if frame then frame:StartMoving() end
        end)
        mainFrame:SetScript("OnDragStop", function()
            local frame = getglobal("ChickenJockeyFrame")
            if frame then frame:StopMovingOrSizing() end
        end)
    end
    
    -- Register for VARIABLES_LOADED to show minimap button
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("VARIABLES_LOADED")
    eventFrame:SetScript("OnEvent", function()
        if ChickenJockeyButtonFrame then
            ChickenJockeyButtonFrame:Show()
        end
    end)
    
    -- Add to special frames so ESC closes it
    table.insert(UISpecialFrames, "ChickenJockeyFrame")
    
    -- Add tooltips to buttons
    local fetchButton = getglobal("ChickenJockeyFetchButton")
    if fetchButton then
        fetchButton:SetScript("OnEnter", function()
            GameTooltip:SetOwner(fetchButton, "ANCHOR_RIGHT")
            GameTooltip:SetText("Fetch Item", 1, 1, 1)
            GameTooltip:AddLine("Queries the server for the item ID entered above.", 1, 1, 1)
            GameTooltip:Show()
        end)
        fetchButton:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end
    
    local randomButton = getglobal("ChickenJockeyRandomButton")
    if randomButton then
        randomButton:SetScript("OnEnter", function()
            GameTooltip:SetOwner(randomButton, "ANCHOR_RIGHT")
            GameTooltip:SetText("Random Item", 1, 1, 1)
            GameTooltip:AddLine("Finds a random item (ID 100-60000).", 1, 1, 1)
            GameTooltip:AddLine("Retries up to 5 times if item not found.", 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end)
        randomButton:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end
    
    local createLinkButton = getglobal("ChickenJockeyCreateLinkButton")
    if createLinkButton then
        createLinkButton:SetScript("OnEnter", function()
            GameTooltip:SetOwner(createLinkButton, "ANCHOR_TOP")
            GameTooltip:SetText("Create Link", 1, 1, 1)
            GameTooltip:AddLine("Creates an item link with custom name and quality.", 1, 1, 1)
            GameTooltip:AddLine("Sends the link to your chat window.", 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end)
        createLinkButton:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end
    
    -- Update item name when user types (check if frame exists first)
    local nameFrame = getglobal("ChickenJockeyItemName")
    if nameFrame then
        nameFrame:SetScript("OnTextChanged", function()
            local frame = getglobal("ChickenJockeyItemName")
            if frame then
                -- Check if HasFocus method exists before calling it
                if frame.HasFocus and frame:HasFocus() then
                    currentItemData.name = frame:GetText()
                end
            end
        end)
    end
    
    -- Update item number when user types (check if frame exists first)
    local numberFrame = getglobal("ChickenJockeyItemNumber")
    if numberFrame then
        numberFrame:SetScript("OnTextChanged", function()
            local frame = getglobal("ChickenJockeyItemNumber")
            if frame then
                -- Check if HasFocus method exists before calling it
                if frame.HasFocus and frame:HasFocus() then
                    local itemId = tonumber(frame:GetText())
                    if itemId and itemId > 0 then
                        currentItemData.id = itemId
                    end
                end
            end
        end)
    end
end

function ChickenJockey_SetRarity(rarity)
    currentItemData.rarity = rarity
    
    -- Uncheck all radio buttons
    local buttons = {
        getglobal("ChickenJockeyColorGrey"),
        getglobal("ChickenJockeyColorWhite"),
        getglobal("ChickenJockeyColorGreen"),
        getglobal("ChickenJockeyColorBlue"),
        getglobal("ChickenJockeyColorPurple"),
        getglobal("ChickenJockeyColorOrange"),
        getglobal("ChickenJockeyColorRed")
    }
    
    for i, button in ipairs(buttons) do
        if button then
            button:SetChecked((i - 1) == rarity)
        end
    end
end

function ChickenJockey_OnShow()
    -- Initialize UI
    local numberFrame = getglobal("ChickenJockeyItemNumber")
    local nameFrame = getglobal("ChickenJockeyItemName")
    
    -- Prepopulate with default item ID 51637 if no item data exists
    if not currentItemData.id or currentItemData.id == 0 then
        currentItemData.id = 51637
        if numberFrame then numberFrame:SetText("51637") end
        -- Trigger fetch for the default item
        QueryItem(51637, false)
    else
        if numberFrame then numberFrame:SetText(tostring(currentItemData.id)) end
        if nameFrame then nameFrame:SetText(currentItemData.name) end
    end
    
    -- Always set a default rarity if none is set
    if not currentItemData.rarity then
        currentItemData.rarity = 0  -- Default to Poor
    end
    
    -- Set radio button based on current rarity (always populated)
    ChickenJockey_SetRarity(currentItemData.rarity)
end

function ChickenJockey_FetchItem()
    local numberFrame = getglobal("ChickenJockeyItemNumber")
    if not numberFrame then
        ShowStatus("Item number field not found", {1, 0, 0})
        return
    end
    
    local itemIdText = numberFrame:GetText()
    local itemId = tonumber(itemIdText)
    
    if not itemId or itemId <= 0 then
        ShowStatus("Please enter a valid item number", {1, 0, 0})
        return
    end
    
    QueryItem(itemId, false)
end

function ChickenJockey_RandomItem()
    -- Generate random item ID and query it (works regardless of item number field)
    -- Reset query state completely
    queryState.active = false
    queryState.itemId = nil
    queryState.tries = 0
    queryState.isRandom = false
    queryState.randomTries = 0
    
    -- Generate new random ID and start query
    local randomId = math.random(100, 60000)
    QueryItem(randomId, true)
end


function ChickenJockey_CreateLink()
    local numberFrame = getglobal("ChickenJockeyItemNumber")
    local nameFrame = getglobal("ChickenJockeyItemName")
    
    if not numberFrame or not nameFrame then
        ShowStatus("UI frames not found", {1, 0, 0})
        return
    end
    
    local itemId = tonumber(numberFrame:GetText())
    local itemName = nameFrame:GetText()
    
    if not itemId or itemId <= 0 then
        ShowStatus("Please enter a valid item number", {1, 0, 0})
        return
    end
    
    if itemName == "" or itemName == nil then
        ShowStatus("Please enter an item name", {1, 0, 0})
        return
    end
    
    -- Get selected rarity from currentItemData
    local rarity = currentItemData.rarity or 0
    
    -- Get color code
    local colorCode = GetQualityColorCode(rarity)
    
    -- Create item link
    -- Format: |c<color>|Hitem:<id>:0:0:0|h[<name>]|h|r
    local itemLink = "item:" .. itemId .. ":0:0:0"
    local linkText = colorCode .. "|H" .. itemLink .. "|h[" .. itemName .. "]|h|r"
    
    -- Send to chat using DEFAULT_CHAT_FRAME
    DEFAULT_CHAT_FRAME:AddMessage(linkText)
    ShowStatus("Link sent to chat!", {0, 1, 0})
end
