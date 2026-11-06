-- BISList UI: Main window interface

BISListUI = {}

local mainFrame = nil
local contentFrames = {}
local currentViewMode = "source" -- "slot" or "source"
local currentView = "items" -- "items" or "manage"

-- Create the main window
function BISListUI:CreateMainWindow()
    if mainFrame then
        return
    end
    -- Main frame
    mainFrame = CreateFrame("Frame", "BISListMainFrame", UIParent)
    mainFrame:SetWidth(750)
    mainFrame:SetHeight(450)
    mainFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = {left = 5, right = 5, top = 5, bottom = 5}
    })
    mainFrame:SetBackdropColor(0, 0, 0, 0.9)
    mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:SetClampedToScreen(true)
    mainFrame:Hide()

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, mainFrame)
    titleBar:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 15, -10)
    titleBar:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -15, -10)
    titleBar:SetHeight(30)
    titleBar:EnableMouse(true)
    titleBar:SetScript("OnMouseDown", function() mainFrame:StartMoving() end)
    titleBar:SetScript("OnMouseUp", function() mainFrame:StopMovingOrSizing() end)

    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", titleBar, "LEFT", 0, 0)
    title:SetText("BISList - Best in Slot Tracker")

    -- Close button
    local closeButton = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -5, -5)
    closeButton:SetFrameStrata("HIGH")
    closeButton:SetFrameLevel(mainFrame:GetFrameLevel() + 5)

    -- Manage Lists button (replaces stats)
    local manageButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    manageButton:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -35, -12)
    manageButton:SetWidth(90)
    manageButton:SetHeight(20)
    manageButton:SetText("Manage Lists")
    manageButton:SetFrameStrata("HIGH")
    manageButton:SetFrameLevel(mainFrame:GetFrameLevel() + 5)
    manageButton:SetScript("OnClick", function()
        if currentView == "items" then
            currentView = "manage"
            manageButton:SetText("Back to Items")
            BISListUI:ShowManageView()
        else
            currentView = "items"
            manageButton:SetText("Manage Lists")
            BISListUI:BuildContent()
        end
    end)
    mainFrame.manageButton = manageButton

    -- View mode dropdown (custom styled)
    local modeFrame = CreateFrame("Frame", nil, mainFrame)
    modeFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 15, -45)
    modeFrame:SetWidth(200)
    modeFrame:SetHeight(25)

    local modeLabel = modeFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    modeLabel:SetPoint("LEFT", modeFrame, "LEFT", 5, 0)
    modeLabel:SetText("View:")

    -- Create custom dropdown button
    local dropdownButton = CreateFrame("Button", nil, modeFrame)
    dropdownButton:SetPoint("LEFT", modeLabel, "RIGHT", 5, 0)
    dropdownButton:SetWidth(110)
    dropdownButton:SetHeight(22)
    dropdownButton:SetFrameStrata("HIGH")
    dropdownButton:SetFrameLevel(mainFrame:GetFrameLevel() + 5)
    dropdownButton:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = {left = 3, right = 3, top = 3, bottom = 3}
    })
    dropdownButton:SetBackdropColor(0, 0, 0, 0.8)
    dropdownButton:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    -- Button text
    local buttonText = dropdownButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    buttonText:SetPoint("LEFT", dropdownButton, "LEFT", 8, 0)
    buttonText:SetJustifyH("LEFT")
    if currentViewMode == "source" then
        buttonText:SetText("By Source")
    else
        buttonText:SetText("By Slot")
    end

    -- Dropdown arrow
    local arrow = dropdownButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    arrow:SetPoint("RIGHT", dropdownButton, "RIGHT", -6, 0)
    arrow:SetText("|cffcccccc▼|r")

    -- Create dropdown menu (hidden by default)
    local dropdownMenu = CreateFrame("Frame", nil, mainFrame)
    dropdownMenu:SetPoint("TOPLEFT", dropdownButton, "BOTTOMLEFT", 0, -2)
    dropdownMenu:SetWidth(110)
    dropdownMenu:SetHeight(44)
    dropdownMenu:SetFrameStrata("DIALOG")
    dropdownMenu:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = {left = 3, right = 3, top = 3, bottom = 3}
    })
    dropdownMenu:SetBackdropColor(0, 0, 0, 0.9)
    dropdownMenu:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    dropdownMenu:Hide()

    -- Menu option: By Source
    local sourceOption = CreateFrame("Button", nil, dropdownMenu)
    sourceOption:SetPoint("TOPLEFT", dropdownMenu, "TOPLEFT", 5, -5)
    sourceOption:SetWidth(100)
    sourceOption:SetHeight(18)
    local sourceText = sourceOption:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sourceText:SetPoint("LEFT", sourceOption, "LEFT", 5, 0)
    sourceText:SetText("By Source")
    sourceOption:SetScript("OnClick", function()
        currentViewMode = "source"
        buttonText:SetText("By Source")
        dropdownMenu:Hide()
        BISListUI:BuildContent()
    end)
    sourceOption:SetScript("OnEnter", function()
        sourceOption:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background"
        })
        sourceOption:SetBackdropColor(0.2, 0.2, 0.3, 0.8)
    end)
    sourceOption:SetScript("OnLeave", function()
        sourceOption:SetBackdrop(nil)
    end)

    -- Menu option: By Slot
    local slotOption = CreateFrame("Button", nil, dropdownMenu)
    slotOption:SetPoint("TOPLEFT", sourceOption, "BOTTOMLEFT", 0, -2)
    slotOption:SetWidth(100)
    slotOption:SetHeight(18)
    local slotText = slotOption:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slotText:SetPoint("LEFT", slotOption, "LEFT", 5, 0)
    slotText:SetText("By Slot")
    slotOption:SetScript("OnClick", function()
        currentViewMode = "slot"
        buttonText:SetText("By Slot")
        dropdownMenu:Hide()
        BISListUI:BuildContent()
    end)
    slotOption:SetScript("OnEnter", function()
        slotOption:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background"
        })
        slotOption:SetBackdropColor(0.2, 0.2, 0.3, 0.8)
    end)
    slotOption:SetScript("OnLeave", function()
        slotOption:SetBackdrop(nil)
    end)

    -- Toggle menu on button click
    dropdownButton:SetScript("OnClick", function()
        if dropdownMenu:IsVisible() then
            dropdownMenu:Hide()
        else
            dropdownMenu:Show()
        end
    end)

    -- Highlight on hover
    dropdownButton:SetScript("OnEnter", function()
        dropdownButton:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    end)
    dropdownButton:SetScript("OnLeave", function()
        dropdownButton:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    end)

    -- Hide menu when clicking outside
    local hideFrame = CreateFrame("Frame", nil, UIParent)
    hideFrame:SetAllPoints(UIParent)
    hideFrame:SetFrameStrata("BACKGROUND")
    hideFrame:SetFrameLevel(0)
    hideFrame:Hide()
    hideFrame:EnableMouse(true)
    hideFrame:SetScript("OnMouseDown", function()
        dropdownMenu:Hide()
    end)

    dropdownMenu:SetScript("OnShow", function()
        hideFrame:Show()
        hideFrame:SetFrameStrata("DIALOG")
        hideFrame:SetFrameLevel(dropdownMenu:GetFrameLevel() - 1)
    end)
    dropdownMenu:SetScript("OnHide", function()
        hideFrame:Hide()
        hideFrame:SetFrameStrata("BACKGROUND")
    end)

    mainFrame.viewDropdown = dropdownButton

    -- List selector dropdown
    local listFrame = CreateFrame("Frame", nil, mainFrame)
    listFrame:SetPoint("LEFT", dropdownButton, "RIGHT", 15, 0)
    listFrame:SetWidth(150)
    listFrame:SetHeight(25)

    local listLabel = listFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listLabel:SetPoint("LEFT", listFrame, "LEFT", 0, 0)
    listLabel:SetText("List:")

    -- Create list dropdown button
    local listDropdownButton = CreateFrame("Button", nil, listFrame)
    listDropdownButton:SetPoint("LEFT", listLabel, "RIGHT", 5, 0)
    listDropdownButton:SetWidth(110)
    listDropdownButton:SetHeight(22)
    listDropdownButton:SetFrameStrata("HIGH")
    listDropdownButton:SetFrameLevel(mainFrame:GetFrameLevel() + 5)
    listDropdownButton:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = {left = 3, right = 3, top = 3, bottom = 3}
    })
    listDropdownButton:SetBackdropColor(0, 0, 0, 0.8)
    listDropdownButton:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    local listButtonText = listDropdownButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    listButtonText:SetPoint("LEFT", listDropdownButton, "LEFT", 8, 0)
    listButtonText:SetJustifyH("LEFT")
    listButtonText:SetText(BISList.CurrentList or "PvE")

    local listArrow = listDropdownButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    listArrow:SetPoint("RIGHT", listDropdownButton, "RIGHT", -6, 0)
    listArrow:SetText("|cffcccccc▼|r")

    -- Create list dropdown menu
    local listDropdownMenu = CreateFrame("Frame", nil, mainFrame)
    listDropdownMenu:SetPoint("TOPLEFT", listDropdownButton, "BOTTOMLEFT", 0, -2)
    listDropdownMenu:SetWidth(110)
    listDropdownMenu:SetFrameStrata("DIALOG")
    listDropdownMenu:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = {left = 3, right = 3, top = 3, bottom = 3}
    })
    listDropdownMenu:SetBackdropColor(0, 0, 0, 0.9)
    listDropdownMenu:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    listDropdownMenu:Hide()

    -- Function to rebuild list dropdown menu
    local function RebuildListMenu()
        -- Clear existing buttons
        local children = {listDropdownMenu:GetChildren()}
        for _, child in ipairs(children) do
            child:Hide()
            child:SetParent(nil)
        end

        local listNames = BISList:GetListNames()
        local menuHeight = (table.getn(listNames) * 20) + 10

        listDropdownMenu:SetHeight(menuHeight)

        local yOffset = -5
        for _, listName in ipairs(listNames) do
            -- Create local copy for closure
            local currentListName = listName

            local option = CreateFrame("Button", nil, listDropdownMenu)
            option:SetPoint("TOPLEFT", listDropdownMenu, "TOPLEFT", 5, yOffset)
            option:SetWidth(100)
            option:SetHeight(18)

            local optionText = option:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            optionText:SetPoint("LEFT", option, "LEFT", 5, 0)
            optionText:SetText(currentListName)

            option:SetScript("OnClick", function()
                BISList:SetCurrentList(currentListName)
                listButtonText:SetText(currentListName)
                listDropdownMenu:Hide()
                BISListUI:BuildContent()
            end)
            option:SetScript("OnEnter", function()
                option:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background"})
                option:SetBackdropColor(0.2, 0.2, 0.3, 0.8)
            end)
            option:SetScript("OnLeave", function()
                option:SetBackdrop(nil)
            end)

            yOffset = yOffset - 20
        end
    end

    listDropdownButton:SetScript("OnClick", function()
        if listDropdownMenu:IsVisible() then
            listDropdownMenu:Hide()
        else
            RebuildListMenu()
            listDropdownMenu:Show()
        end
    end)

    listDropdownButton:SetScript("OnEnter", function()
        listDropdownButton:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    end)
    listDropdownButton:SetScript("OnLeave", function()
        listDropdownButton:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    end)

    -- Hide menu when clicking outside
    local listHideFrame = CreateFrame("Frame", nil, UIParent)
    listHideFrame:SetAllPoints(UIParent)
    listHideFrame:SetFrameStrata("BACKGROUND")
    listHideFrame:SetFrameLevel(0)
    listHideFrame:Hide()
    listHideFrame:EnableMouse(true)
    listHideFrame:SetScript("OnMouseDown", function()
        listDropdownMenu:Hide()
    end)

    listDropdownMenu:SetScript("OnShow", function()
        listHideFrame:Show()
        listHideFrame:SetFrameStrata("DIALOG")
        listHideFrame:SetFrameLevel(listDropdownMenu:GetFrameLevel() - 1)
    end)
    listDropdownMenu:SetScript("OnHide", function()
        listHideFrame:Hide()
        listHideFrame:SetFrameStrata("BACKGROUND")
    end)

    mainFrame.listDropdown = listDropdownButton
    mainFrame.listDropdownText = listButtonText
    mainFrame.rebuildListMenu = RebuildListMenu

    -- Stats subtitle (subtle)
    local statsText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statsText:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 20, -70)
    statsText:SetText("|cffaaaaaa0/0 Items (0%)|r")
    mainFrame.statsText = statsText

    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", "BISListScrollFrame", mainFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 20, -85)
    scrollFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -35, 20)

    -- Content frame
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(680)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)
    mainFrame.scrollChild = scrollChild

    self.mainFrame = mainFrame
    self:BuildContent()
end

-- Build the content (all slots and items)
function BISListUI:BuildContent()
    if not mainFrame or not mainFrame.scrollChild then return end

    -- Ensure we're in items view
    currentView = "items"
    mainFrame.manageButton:SetText("Manage Lists")

    -- Show the view controls
    mainFrame.viewDropdown:GetParent():Show()
    mainFrame.listDropdown:GetParent():Show()
    mainFrame.statsText:Show()

    -- Restore scroll frame position for items view
    local scrollFrame = getglobal("BISListScrollFrame")
    if scrollFrame then
        scrollFrame:ClearAllPoints()
        scrollFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 20, -85)
        scrollFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -35, 20)
    end

    -- Completely destroy old frames to prevent memory leak
    for _, frame in ipairs(contentFrames) do
        frame:Hide()
        frame:ClearAllPoints()
        frame:SetParent(nil)
    end
    contentFrames = {}

    -- Clear all children from scrollChild
    local children = {mainFrame.scrollChild:GetChildren()}
    for _, child in ipairs(children) do
        child:Hide()
        child:ClearAllPoints()
        child:SetParent(nil)
    end

    if currentViewMode == "source" then
        self:BuildContentBySource()
    else
        self:BuildContentBySlot()
    end

    self:UpdateStats()
end

-- Build content grouped by equipment slot
function BISListUI:BuildContentBySlot()
    local scrollChild = mainFrame.scrollChild
    local columnWidth = 330

    -- Split slots into two columns (first 8 on left, rest on right)
    local leftYOffset = -10
    local rightYOffset = -10
    local maxHeight = 0
    local hasItems = false

    for i, slot in ipairs(BISList.Slots) do
        -- Skip empty slots
        local items = BISList.Data[slot.id] or {}
        if table.getn(items) > 0 then
            hasItems = true
            local slotFrame
            if i <= 8 then
                -- Left column
                slotFrame = self:CreateSlotFrame(scrollChild, slot, 10, leftYOffset, columnWidth)
                leftYOffset = leftYOffset - slotFrame:GetHeight() - 5
                maxHeight = math.max(maxHeight, math.abs(leftYOffset))
            else
                -- Right column
                slotFrame = self:CreateSlotFrame(scrollChild, slot, columnWidth + 20, rightYOffset, columnWidth)
                rightYOffset = rightYOffset - slotFrame:GetHeight() - 5
                maxHeight = math.max(maxHeight, math.abs(rightYOffset))
            end
            table.insert(contentFrames, slotFrame)
        end
    end

    -- Show empty state message if no items
    if not hasItems then
        self:ShowEmptyStateMessage(scrollChild)
        maxHeight = 200
    end

    local contentHeight = maxHeight + 20
    scrollChild:SetHeight(contentHeight)

    -- Force update scroll bar range (vanilla WoW doesn't always recalculate this)
    local scrollFrame = getglobal("BISListScrollFrame")
    local scrollBar = getglobal("BISListScrollFrameScrollBar")
    if scrollFrame and scrollBar then
        local visibleHeight = scrollFrame:GetHeight()
        local maxScroll = contentHeight - visibleHeight
        if maxScroll < 0 then maxScroll = 0 end
        scrollBar:SetMinMaxValues(0, maxScroll)
    end
end

-- Lookup itemID in embedded item database (fallback when sourceInfo is nil)
function BISListUI:LookupItemInDatabase(itemId)
    if not BISListItemDB or type(BISListItemDB) ~= "table" then
        return nil
    end

    local dataID = BISListItemDB[itemId]
    if dataID then
        return dataID .. "|AtlasLootItems"
    end

    return nil
end

-- Parse sourceInfo to human-readable name
function BISListUI:ParseSourceName(sourceInfo, itemId)
    -- If sourceInfo is nil, try to lookup by itemID
    if not sourceInfo then
        if itemId then
            local lookedUpSourceInfo = self:LookupItemInDatabase(itemId)
            if lookedUpSourceInfo then
                sourceInfo = lookedUpSourceInfo
            else
                return "Open World"
            end
        else
            return "Open World"
        end
    end

    -- Extract dataID from sourceInfo (format: "dataID|dataSource")
    -- Use string.find for Lua 5.0 compatibility (WoW 1.12.1)
    local _, _, dataID, dataSource = string.find(sourceInfo, "([^|]+)|?([^|]*)")

    -- Use the global sourceMap from SourceMap.lua
    if BISListSourceMap and BISListSourceMap[dataID] then
        return BISListSourceMap[dataID]
    end

    -- If no mapping found, return the raw dataID (better than "Open World")
    if dataID and dataID ~= "" then
        return dataID
    end

    -- Last resort
    return "Open World"
end

-- Build content grouped by source (dungeon/raid)
function BISListUI:BuildContentBySource()
    local scrollChild = mainFrame.scrollChild
    local columnWidth = 330

    -- Collect all items and group by source
    local sourceGroups = {}
    for _, slot in ipairs(BISList.Slots) do
        local items = BISList.Data[slot.id] or {}
        for _, item in ipairs(items) do
            local sourceName = self:ParseSourceName(item.sourceInfo, item.itemId)
            if not sourceGroups[sourceName] then
                sourceGroups[sourceName] = {}
            end
            -- Store item with slot info for display
            local itemWithSlot = {}
            for k, v in pairs(item) do
                itemWithSlot[k] = v
            end
            itemWithSlot.slotId = slot.id
            itemWithSlot.slotName = slot.name
            table.insert(sourceGroups[sourceName], itemWithSlot)
        end
    end

    -- Sort sources by item count (most items first), then alphabetically
    local sortedSources = {}
    for sourceName, items in pairs(sourceGroups) do
        table.insert(sortedSources, {name = sourceName, count = table.getn(items)})
    end
    table.sort(sortedSources, function(a, b)
        if a.count == b.count then
            return a.name < b.name  -- Alphabetical if same count
        end
        return a.count > b.count  -- Most items first
    end)

    -- Split into two columns, alternating row-by-row (not column-by-column)
    local leftYOffset = -10
    local rightYOffset = -10
    local maxHeight = 0

    for sourceIndex, sourceData in ipairs(sortedSources) do
        local sourceName = sourceData.name
        local items = sourceGroups[sourceName]

        local sourceFrame
        -- Odd indices go left, even indices go right (row-by-row layout)
        if math.mod(sourceIndex, 2) == 1 then
            -- Left column (odd: 1st, 3rd, 5th, etc.)
            sourceFrame = self:CreateSourceFrame(scrollChild, sourceName, items, 10, leftYOffset, columnWidth)
            leftYOffset = leftYOffset - sourceFrame:GetHeight() - 5
            maxHeight = math.max(maxHeight, math.abs(leftYOffset))
        else
            -- Right column (even: 2nd, 4th, 6th, etc.)
            sourceFrame = self:CreateSourceFrame(scrollChild, sourceName, items, columnWidth + 20, rightYOffset, columnWidth)
            rightYOffset = rightYOffset - sourceFrame:GetHeight() - 5
            maxHeight = math.max(maxHeight, math.abs(rightYOffset))
        end
        table.insert(contentFrames, sourceFrame)
    end

    -- Show empty state message if no items
    if table.getn(sortedSources) == 0 then
        self:ShowEmptyStateMessage(scrollChild)
        maxHeight = 200
    end

    -- Ensure scroll height is sufficient (minimum 500 to enable scrolling)
    local contentHeight = math.max(maxHeight + 20, 500)
    scrollChild:SetHeight(contentHeight)

    -- Force update scroll bar range (vanilla WoW doesn't always recalculate this)
    local scrollFrame = getglobal("BISListScrollFrame")
    local scrollBar = getglobal("BISListScrollFrameScrollBar")
    if scrollFrame and scrollBar then
        local visibleHeight = scrollFrame:GetHeight()
        local maxScroll = contentHeight - visibleHeight
        if maxScroll < 0 then maxScroll = 0 end
        scrollBar:SetMinMaxValues(0, maxScroll)
    end
end

-- Create a frame for one source group (dungeon/raid)
function BISListUI:CreateSourceFrame(parent, sourceName, items, xOffset, yOffset, width)
    local sourceFrame = CreateFrame("Frame", nil, parent)
    sourceFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)
    sourceFrame:SetWidth(width)

    -- Add border/background
    sourceFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = {left = 3, right = 3, top = 3, bottom = 3}
    })
    sourceFrame:SetBackdropColor(0, 0, 0, 0.5)
    sourceFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    -- Source header with name
    local sourceNameText = sourceFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sourceNameText:SetPoint("TOPLEFT", sourceFrame, "TOPLEFT", 8, -6)
    sourceNameText:SetText(sourceName)

    local itemYOffset = -24
    local itemCount = 0

    -- Create item rows
    for _, item in ipairs(items) do
        local itemFrame = self:CreateSourceItemFrame(sourceFrame, item, itemYOffset, width)
        itemYOffset = itemYOffset - 20
        itemCount = itemCount + 1
    end

    -- Set total height
    local totalHeight = 26 + (itemCount * 20)
    sourceFrame:SetHeight(totalHeight)

    return sourceFrame
end

-- Create a frame for one item in a source group
function BISListUI:CreateSourceItemFrame(parent, item, yOffset, width)
    local itemFrame = CreateFrame("Frame", nil, parent)
    itemFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, yOffset)
    itemFrame:SetWidth(width - 16)
    itemFrame:SetHeight(18)

    -- Table structure: [checkbox | slot name | item link | move button | delete button]
    local checkboxWidth = 25
    local moveButtonWidth = 16
    local deleteButtonWidth = 16
    local slotNameWidth = 50
    local itemLinkWidth = width - 16 - checkboxWidth - moveButtonWidth - deleteButtonWidth - slotNameWidth - 20

    -- Column 1: Acquisition checkbox
    local checkbox = itemFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    checkbox:SetPoint("LEFT", itemFrame, "LEFT", 2, 0)
    checkbox:SetWidth(checkboxWidth)
    checkbox:SetJustifyH("CENTER")
    if item.acquired then
        checkbox:SetText("|cff00ff00[X]|r")
    else
        checkbox:SetText("|cffaaaaaa[ ]|r")
    end

    -- Column 2: Slot name (abbreviated)
    local slotText = itemFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slotText:SetPoint("LEFT", checkbox, "RIGHT", 2, 0)
    slotText:SetWidth(slotNameWidth)
    slotText:SetJustifyH("LEFT")
    slotText:SetText("|cffaaaaaa" .. item.slotName .. "|r")

    -- Column 3: Item link
    local displayText
    if item.itemName and string.find(item.itemName, "=q") then
        -- AtlasLoot format
        displayText = gsub(item.itemName, "=q1=", "|cffFFFFFF")
        displayText = gsub(displayText, "=q2=", "|cff1eff00")
        displayText = gsub(displayText, "=q3=", "|cff0070dd")
        displayText = gsub(displayText, "=q4=", "|cffa335ee")
        displayText = gsub(displayText, "=q5=", "|cffFF8000")
        displayText = displayText .. "|r"
    elseif item.itemName and string.find(item.itemName, "|H") then
        -- Already proper link
        displayText = item.itemName
    else
        -- Try cache first for proper colored link
        local cachedName, properLink, itemRarity = GetItemInfo(item.itemId)
        -- Only use properLink if it's actually a colored link (contains |c or |H), not raw "item:xxx" format
        if properLink and string.find(properLink, "|") then
            displayText = properLink
        elseif item.itemName and item.itemName ~= "" and not string.find(item.itemName, "^item:") then
            -- Plain text name - add rarity color if available
            local colorCode = "|cffffffff" -- default white
            if itemRarity then
                local r, g, b = GetItemQualityColor(itemRarity)
                if r then
                    colorCode = string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
                end
            end
            displayText = colorCode .. item.itemName .. "|r"
        else
            displayText = "|cff999999[Item " .. item.itemId .. "]|r"
        end
    end

    local itemLink = itemFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    itemLink:SetPoint("LEFT", slotText, "RIGHT", 5, 0)
    itemLink:SetWidth(itemLinkWidth)
    itemLink:SetJustifyH("LEFT")
    itemLink:SetText(displayText)

    -- Make item link clickable - store the proper link for this item
    local linkButton = CreateFrame("Button", nil, itemFrame)
    linkButton:SetPoint("LEFT", slotText, "RIGHT", 5, 0)
    linkButton:SetWidth(itemLinkWidth)
    linkButton:SetHeight(18)

    -- Pre-compute the proper link to use for this item
    local _, _, extractedItemId = string.find(item.itemLink, "item:(%d+)")

    -- Helper function to build a proper hyperlink
    local function BuildProperLink(itemId)
        local itemName, _, itemRarity = GetItemInfo(tonumber(itemId))
        local nameToUse = itemName
        if not nameToUse or nameToUse == "" then
            nameToUse = item.itemName
            if nameToUse then
                -- Strip any existing color codes from stored name
                nameToUse = string.gsub(nameToUse, "|c%x%x%x%x%x%x%x%x", "")
                nameToUse = string.gsub(nameToUse, "|r", "")
            end
        end
        if not nameToUse or nameToUse == "" or string.find(nameToUse, "^item:") then
            nameToUse = "Item " .. itemId
        end

        -- Get color based on rarity
        local colorCode = "ffffffff" -- default white
        if itemRarity then
            local r, g, b = GetItemQualityColor(itemRarity)
            if r then
                colorCode = string.format("ff%02x%02x%02x", r * 255, g * 255, b * 255)
            end
        end

        return "|c" .. colorCode .. "|Hitem:" .. itemId .. ":0:0:0|h[" .. nameToUse .. "]|h|r"
    end

    linkButton:SetScript("OnClick", function()
        if IsShiftKeyDown() then
            if ChatFrameEditBox and ChatFrameEditBox:IsVisible() and extractedItemId then
                local properLink = BuildProperLink(extractedItemId)
                ChatFrameEditBox:Insert(properLink)
            end
        end
    end)
    linkButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(linkButton, "ANCHOR_RIGHT")
        if extractedItemId then
            -- Always try to get fresh cached link for tooltip
            local _, freshLink = GetItemInfo(tonumber(extractedItemId))
            if freshLink then
                -- Use the properly formatted link - this ensures shift-click from tooltip also works
                GameTooltip:SetHyperlink(freshLink)
            else
                -- Fallback: use raw format but tooltip shift-click may not work perfectly
                GameTooltip:SetHyperlink("item:" .. extractedItemId .. ":0:0:0")
            end
        end
        GameTooltip:Show()
    end)
    linkButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Column 4: Move to List button
    local moveButton = CreateFrame("Button", nil, itemFrame)
    moveButton:SetPoint("RIGHT", itemFrame, "RIGHT", -20, 0)
    moveButton:SetWidth(16)
    moveButton:SetHeight(16)
    moveButton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    moveButton:SetScript("OnClick", function()
        BISListUI:ShowMoveToListMenu(item.slotId, item.itemId, moveButton)
    end)
    moveButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(moveButton, "ANCHOR_RIGHT")
        GameTooltip:SetText("Move to another list")
        GameTooltip:Show()
    end)
    moveButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Column 5: Remove button
    local removeButton = CreateFrame("Button", nil, itemFrame)
    removeButton:SetPoint("RIGHT", itemFrame, "RIGHT", -2, 0)
    removeButton:SetWidth(16)
    removeButton:SetHeight(16)
    removeButton:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    removeButton:SetScript("OnClick", function()
        BISList:RemoveItem(item.slotId, item.itemId)
        BISListUI:Refresh()
    end)
    removeButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(removeButton, "ANCHOR_RIGHT")
        GameTooltip:SetText("Remove item")
        GameTooltip:Show()
    end)
    removeButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return itemFrame
end

-- Create a frame for one equipment slot
function BISListUI:CreateSlotFrame(parent, slot, xOffset, yOffset, width)
    local items = BISList.Data[slot.id] or {}

    local slotFrame = CreateFrame("Frame", nil, parent)
    slotFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)
    slotFrame:SetWidth(width)

    -- Add border/background
    slotFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = {left = 3, right = 3, top = 3, bottom = 3}
    })
    slotFrame:SetBackdropColor(0, 0, 0, 0.5)
    slotFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    -- Slot header with name
    local slotName = slotFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    slotName:SetPoint("TOPLEFT", slotFrame, "TOPLEFT", 8, -6)
    slotName:SetText(slot.name)

    local itemYOffset = -24
    local itemCount = 0

    -- Create item rows
    for _, item in ipairs(items) do
        local itemFrame = self:CreateItemFrame(slotFrame, slot.id, item, itemYOffset, width)
        itemYOffset = itemYOffset - 20
        itemCount = itemCount + 1
    end

    -- Set total height
    local totalHeight = 26 + (itemCount * 20)
    slotFrame:SetHeight(totalHeight)

    return slotFrame
end

-- Create a frame for one item in a slot
function BISListUI:CreateItemFrame(parent, slotId, item, yOffset, width)
    local itemFrame = CreateFrame("Frame", nil, parent)
    itemFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, yOffset)
    itemFrame:SetWidth(width - 16)
    itemFrame:SetHeight(18)

    -- Table structure: [checkbox | item link | move button | delete button]
    local checkboxWidth = 25
    local moveButtonWidth = 16
    local deleteButtonWidth = 16
    local itemLinkWidth = width - 16 - checkboxWidth - moveButtonWidth - deleteButtonWidth - 15

    -- Column 1: Acquisition checkbox
    local checkbox = itemFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    checkbox:SetPoint("LEFT", itemFrame, "LEFT", 2, 0)
    checkbox:SetWidth(checkboxWidth)
    checkbox:SetJustifyH("CENTER")
    if item.acquired then
        checkbox:SetText("|cff00ff00[X]|r")
    else
        checkbox:SetText("|cffaaaaaa[ ]|r")
    end

    -- Column 2: Item link
    local displayText
    if item.itemName and string.find(item.itemName, "=q") then
        -- AtlasLoot format
        displayText = gsub(item.itemName, "=q1=", "|cffFFFFFF")
        displayText = gsub(displayText, "=q2=", "|cff1eff00")
        displayText = gsub(displayText, "=q3=", "|cff0070dd")
        displayText = gsub(displayText, "=q4=", "|cffa335ee")
        displayText = gsub(displayText, "=q5=", "|cffFF8000")
        displayText = displayText .. "|r"
    elseif item.itemName and string.find(item.itemName, "|H") then
        -- Already proper link
        displayText = item.itemName
    else
        -- Try cache first for proper colored link
        local cachedName, properLink, itemRarity = GetItemInfo(item.itemId)
        -- Only use properLink if it's actually a colored link (contains |c or |H), not raw "item:xxx" format
        if properLink and string.find(properLink, "|") then
            displayText = properLink
        elseif item.itemName and item.itemName ~= "" and not string.find(item.itemName, "^item:") then
            -- Plain text name - add rarity color if available
            local colorCode = "|cffffffff" -- default white
            if itemRarity then
                local r, g, b = GetItemQualityColor(itemRarity)
                if r then
                    colorCode = string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
                end
            end
            displayText = colorCode .. item.itemName .. "|r"
        else
            displayText = "|cff999999[Item " .. item.itemId .. "]|r"
        end
    end

    local itemLink = itemFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    itemLink:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
    itemLink:SetWidth(itemLinkWidth)
    itemLink:SetJustifyH("LEFT")
    itemLink:SetText(displayText)

    -- Make item link clickable
    local linkButton = CreateFrame("Button", nil, itemFrame)
    linkButton:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
    linkButton:SetWidth(itemLinkWidth)
    linkButton:SetHeight(18)

    -- Pre-compute the proper link to use for this item
    local _, _, extractedItemId = string.find(item.itemLink, "item:(%d+)")

    -- Helper function to build a proper hyperlink
    local function BuildProperLink(itemId)
        local itemName, _, itemRarity = GetItemInfo(tonumber(itemId))
        local nameToUse = itemName
        if not nameToUse or nameToUse == "" then
            nameToUse = item.itemName
            if nameToUse then
                -- Strip any existing color codes from stored name
                nameToUse = string.gsub(nameToUse, "|c%x%x%x%x%x%x%x%x", "")
                nameToUse = string.gsub(nameToUse, "|r", "")
            end
        end
        if not nameToUse or nameToUse == "" or string.find(nameToUse, "^item:") then
            nameToUse = "Item " .. itemId
        end

        -- Get color based on rarity
        local colorCode = "ffffffff" -- default white
        if itemRarity then
            local r, g, b = GetItemQualityColor(itemRarity)
            if r then
                colorCode = string.format("ff%02x%02x%02x", r * 255, g * 255, b * 255)
            end
        end

        return "|c" .. colorCode .. "|Hitem:" .. itemId .. ":0:0:0|h[" .. nameToUse .. "]|h|r"
    end

    linkButton:SetScript("OnClick", function()
        if IsShiftKeyDown() then
            if ChatFrameEditBox and ChatFrameEditBox:IsVisible() and extractedItemId then
                local properLink = BuildProperLink(extractedItemId)
                ChatFrameEditBox:Insert(properLink)
            end
        end
    end)
    linkButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(linkButton, "ANCHOR_RIGHT")
        if extractedItemId then
            GameTooltip:SetHyperlink("item:" .. extractedItemId .. ":0:0:0")
        end
        GameTooltip:Show()
    end)
    linkButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Column 3: Move to List button
    local moveButton = CreateFrame("Button", nil, itemFrame)
    moveButton:SetPoint("RIGHT", itemFrame, "RIGHT", -20, 0)
    moveButton:SetWidth(16)
    moveButton:SetHeight(16)
    moveButton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    moveButton:SetScript("OnClick", function()
        BISListUI:ShowMoveToListMenu(slotId, item.itemId, moveButton)
    end)
    moveButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(moveButton, "ANCHOR_RIGHT")
        GameTooltip:SetText("Move to another list")
        GameTooltip:Show()
    end)
    moveButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Column 4: Remove button
    local removeButton = CreateFrame("Button", nil, itemFrame)
    removeButton:SetPoint("RIGHT", itemFrame, "RIGHT", -2, 0)
    removeButton:SetWidth(16)
    removeButton:SetHeight(16)
    removeButton:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    removeButton:SetScript("OnClick", function()
        BISList:RemoveItem(slotId, item.itemId)
        BISListUI:Refresh()
    end)
    removeButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(removeButton, "ANCHOR_RIGHT")
        GameTooltip:SetText("Remove item")
        GameTooltip:Show()
    end)
    removeButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return itemFrame
end

-- Show empty state message with instructions
function BISListUI:ShowEmptyStateMessage(parent)
    local messageFrame = CreateFrame("Frame", nil, parent)
    messageFrame:SetPoint("TOP", parent, "TOP", 0, -100)
    messageFrame:SetWidth(650)
    messageFrame:SetHeight(180)

    -- Title
    local title = messageFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", messageFrame, "TOP", 0, 0)
    title:SetText("|cffffffffNo Items in List|r")

    -- Instructions
    local instructions = messageFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    instructions:SetPoint("TOP", title, "BOTTOM", 0, -20)
    instructions:SetWidth(600)
    instructions:SetJustifyH("CENTER")
    instructions:SetText("|cffaaaaaa" ..
        "1. Ensure you have set a keybind in ESC > Key Bindings > BISList.\n\n" ..
        "2. Hover over any item.\n\n" ..
        "3. Use customized keybinding to add item to currently selected list." ..
        "|r")

    table.insert(contentFrames, messageFrame)
end

-- Update the stats display
function BISListUI:UpdateStats()
    if not mainFrame then return end

    local acquired, total = BISList:GetStats()
    local percentage = 0
    if total > 0 then
        percentage = math.floor((acquired / total) * 100)
    end

    mainFrame.statsText:SetText(string.format("|cffaaaaaa%d/%d Items (%d%%)|r", acquired, total, percentage))
end

-- Check if UI is visible
function BISListUI:IsVisible()
    return mainFrame and mainFrame:IsVisible()
end

-- Refresh the entire UI
function BISListUI:Refresh()
    if self:IsVisible() then
        if currentView == "manage" then
            self:ShowManageView()
        else
            self:BuildContent()
        end
    end
end

-- Toggle window visibility
function BISListUI:Toggle()
    if not mainFrame then
        self:CreateMainWindow()
    end

    if mainFrame then
        if mainFrame:IsVisible() then
            mainFrame:Hide()
        else
            mainFrame:Show()
            currentView = "items"
            mainFrame.manageButton:SetText("Manage Lists")
            self:BuildContent()  -- Always rebuild when showing
        end
    end
end

-- Show popup menu to move item to different list
function BISListUI:ShowMoveToListMenu(slotId, itemId, anchorFrame)
    if not slotId or not itemId then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000BISList:|r Invalid item data")
        return
    end

    local listNames = BISList:GetListNames()
    if not listNames or table.getn(listNames) <= 1 then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000BISList:|r You need at least 2 lists to move items")
        return
    end

    -- Create popup menu
    local menu = CreateFrame("Frame", nil, UIParent)
    menu:SetPoint("BOTTOMLEFT", anchorFrame, "TOPLEFT", 0, 2)
    menu:SetWidth(120)
    menu:SetFrameStrata("TOOLTIP")
    menu:SetFrameLevel(100)
    menu:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = {left = 3, right = 3, top = 3, bottom = 3}
    })
    menu:SetBackdropColor(0, 0, 0, 0.95)
    menu:SetBackdropBorderColor(0.8, 0.8, 0.8, 1)

    local menuHeight = 10
    local yOffset = -5
    local hasOptions = false

    for _, listName in ipairs(listNames) do
        -- Create local copy for closure
        local currentListName = listName

        -- Skip current list
        if currentListName ~= BISList.CurrentList then
            hasOptions = true

            local option = CreateFrame("Button", nil, menu)
            option:SetPoint("TOPLEFT", menu, "TOPLEFT", 5, yOffset)
            option:SetWidth(110)
            option:SetHeight(18)

            local optionText = option:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            optionText:SetPoint("LEFT", option, "LEFT", 5, 0)
            optionText:SetText(currentListName)

            option:SetScript("OnClick", function()
                BISList:MoveItemToList(slotId, itemId, currentListName)
                menu:Hide()
                BISListUI:Refresh()
            end)
            option:SetScript("OnEnter", function()
                option:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background"})
                option:SetBackdropColor(0.2, 0.2, 0.3, 0.8)
            end)
            option:SetScript("OnLeave", function()
                option:SetBackdrop(nil)
            end)

            yOffset = yOffset - 20
            menuHeight = menuHeight + 20
        end
    end

    if not hasOptions then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000BISList:|r No other lists available")
        menu:Hide()
        return
    end

    menu:SetHeight(menuHeight)

    -- Click outside to close
    local closeTimer = 0
    menu:SetScript("OnUpdate", function()
        closeTimer = closeTimer + arg1
        if closeTimer > 0.1 then
            closeTimer = 0
            if not MouseIsOver(menu) and not MouseIsOver(anchorFrame) then
                this.hideDelay = (this.hideDelay or 0) + 0.1
                if this.hideDelay > 0.5 then
                    menu:Hide()
                end
            else
                this.hideDelay = 0
            end
        end
    end)

    menu:SetScript("OnHide", function()
        menu:SetScript("OnUpdate", nil)
        menu:SetParent(nil)
    end)

    menu:Show()
end

-- Show the manage lists view
function BISListUI:ShowManageView()
    if not mainFrame or not mainFrame.scrollChild then
        return
    end

    -- Ensure we're in manage view
    currentView = "manage"
    mainFrame.manageButton:SetText("Back to Items")

    -- Hide the view controls
    mainFrame.viewDropdown:GetParent():Hide()
    mainFrame.listDropdown:GetParent():Hide()
    mainFrame.statsText:Hide()

    -- Move scroll frame up to use the space
    local scrollFrame = getglobal("BISListScrollFrame")
    if scrollFrame then
        scrollFrame:ClearAllPoints()
        scrollFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 20, -45)
        scrollFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -35, 20)
    end

    -- Clear existing content
    for _, frame in ipairs(contentFrames) do
        frame:Hide()
        frame:ClearAllPoints()
        frame:SetParent(nil)
    end
    contentFrames = {}

    local children = {mainFrame.scrollChild:GetChildren()}
    for _, child in ipairs(children) do
        child:Hide()
        child:ClearAllPoints()
        child:SetParent(nil)
    end

    local scrollChild = mainFrame.scrollChild
    local yOffset = -10

    -- Title (need to track it for cleanup)
    local titleFrame = CreateFrame("Frame", nil, scrollChild)
    titleFrame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 10, yOffset)
    titleFrame:SetWidth(1)
    titleFrame:SetHeight(1)
    local title = titleFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", titleFrame, "TOPLEFT", 0, 0)
    title:SetText("Manage Lists")
    table.insert(contentFrames, titleFrame)
    yOffset = yOffset - 30

    -- Create new list button
    local createButton = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
    createButton:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 10, yOffset)
    createButton:SetWidth(120)
    createButton:SetHeight(25)
    createButton:SetText("Create New List")
    createButton:SetScript("OnClick", function()
        StaticPopupDialogs["BISLIST_CREATE_LIST"] = {
            text = "Enter name for new list:",
            button1 = "Create",
            button2 = "Cancel",
            hasEditBox = 1,
            maxLetters = 30,
            OnAccept = function()
                local editBox = getglobal(this:GetParent():GetName().."EditBox")
                local listName = editBox:GetText()
                if BISList:CreateList(listName) then
                    mainFrame.rebuildListMenu()
                    BISListUI:ShowManageView()
                end
            end,
            timeout = 0,
            whileDead = 1,
            hideOnEscape = 1
        }
        StaticPopup_Show("BISLIST_CREATE_LIST")
    end)
    table.insert(contentFrames, createButton)
    yOffset = yOffset - 35

    -- List all existing lists
    local listsTitleFrame = CreateFrame("Frame", nil, scrollChild)
    listsTitleFrame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 10, yOffset)
    listsTitleFrame:SetWidth(1)
    listsTitleFrame:SetHeight(1)
    local listsTitle = listsTitleFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listsTitle:SetPoint("TOPLEFT", listsTitleFrame, "TOPLEFT", 0, 0)
    listsTitle:SetText("Your Lists:")
    table.insert(contentFrames, listsTitleFrame)
    yOffset = yOffset - 25

    local listNames = BISList:GetListNames()

    for _, listName in ipairs(listNames) do
        -- Create local copy for closure
        local currentListName = listName

        -- List frame
        local listFrame = CreateFrame("Frame", nil, scrollChild)
        listFrame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 10, yOffset)
        listFrame:SetWidth(660)
        listFrame:SetHeight(30)
        listFrame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 12,
            insets = {left = 3, right = 3, top = 3, bottom = 3}
        })
        listFrame:SetBackdropColor(0, 0, 0, 0.5)
        listFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

        -- List name
        local nameText = listFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameText:SetPoint("LEFT", listFrame, "LEFT", 10, 0)
        nameText:SetText(currentListName)

        -- Rename button
        local renameButton = CreateFrame("Button", nil, listFrame, "UIPanelButtonTemplate")
        renameButton:SetPoint("RIGHT", listFrame, "RIGHT", -90, 0)
        renameButton:SetWidth(70)
        renameButton:SetHeight(22)
        renameButton:SetText("Rename")
        renameButton:SetScript("OnClick", function()
            StaticPopupDialogs["BISLIST_RENAME_LIST"] = {
                text = "Rename '" .. currentListName .. "' to:",
                button1 = "Rename",
                button2 = "Cancel",
                hasEditBox = 1,
                maxLetters = 30,
                OnShow = function()
                    local editBox = getglobal(this:GetName().."EditBox")
                    editBox:SetText(currentListName)
                    editBox:HighlightText()
                end,
                OnAccept = function()
                    local editBox = getglobal(this:GetParent():GetName().."EditBox")
                    local newName = editBox:GetText()
                    if BISList:RenameList(currentListName, newName) then
                        mainFrame.listDropdownText:SetText(BISList.CurrentList)
                        mainFrame.rebuildListMenu()
                        BISListUI:ShowManageView()
                    end
                end,
                timeout = 0,
                whileDead = 1,
                hideOnEscape = 1
            }
            StaticPopup_Show("BISLIST_RENAME_LIST")
        end)

        -- Delete button
        local deleteButton = CreateFrame("Button", nil, listFrame, "UIPanelButtonTemplate")
        deleteButton:SetPoint("RIGHT", listFrame, "RIGHT", -10, 0)
        deleteButton:SetWidth(70)
        deleteButton:SetHeight(22)
        deleteButton:SetText("Delete")
        deleteButton:SetScript("OnClick", function()
            -- Count items in this list
            local itemCount = 0
            if BISList.DB.lists[currentListName] then
                for slotId, items in pairs(BISList.DB.lists[currentListName]) do
                    itemCount = itemCount + table.getn(items)
                end
            end

            local warningText = "Delete list '" .. currentListName .. "'?"
            if itemCount > 0 then
                warningText = warningText .. "\n\n|cffff0000Warning:|r This list contains " .. itemCount .. " item(s).\nAll items will be permanently lost!"
            end

            StaticPopupDialogs["BISLIST_DELETE_LIST"] = {
                text = warningText,
                button1 = "Delete",
                button2 = "Cancel",
                OnAccept = function()
                    if BISList:DeleteList(currentListName) then
                        mainFrame.listDropdownText:SetText(BISList.CurrentList)
                        mainFrame.rebuildListMenu()
                        BISListUI:ShowManageView()
                    end
                end,
                timeout = 0,
                whileDead = 1,
                hideOnEscape = 1
            }
            StaticPopup_Show("BISLIST_DELETE_LIST")
        end)

        table.insert(contentFrames, listFrame)
        yOffset = yOffset - 35
    end

    -- Back button
    yOffset = yOffset - 10
    local backButton = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
    backButton:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 10, yOffset)
    backButton:SetWidth(100)
    backButton:SetHeight(25)
    backButton:SetText("Back")
    backButton:SetScript("OnClick", function()
        currentView = "items"
        mainFrame.manageButton:SetText("Manage Lists")
        BISListUI:BuildContent()
    end)
    table.insert(contentFrames, backButton)

    -- Set scroll height to accommodate all content
    local totalHeight = math.abs(yOffset) + 50
    local contentHeight = math.max(totalHeight, 400)
    scrollChild:SetHeight(contentHeight)

    -- Force update scroll bar range (vanilla WoW doesn't always recalculate this)
    local scrollFrame = getglobal("BISListScrollFrame")
    local scrollBar = getglobal("BISListScrollFrameScrollBar")
    if scrollFrame and scrollBar then
        local visibleHeight = scrollFrame:GetHeight()
        local maxScroll = contentHeight - visibleHeight
        if maxScroll < 0 then maxScroll = 0 end
        scrollBar:SetMinMaxValues(0, maxScroll)
    end
end

-- Initialize UI on load (removed auto-creation, now only created when needed)
