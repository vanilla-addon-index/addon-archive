-- BISList Context Menu: Item link click hooking

BISListContextMenu = {}

local currentItemLink = nil
local lastHoveredItemLink = nil
local lastHoveredItemName = nil
local lastHoveredSourceInfo = nil
local hideTimer = 0

-- Debug mode flag (off by default to reduce spam)
local DEBUG_MODE = false

-- Debug logging helper
local function DebugLog(msg)
    if DEBUG_MODE then
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00[BISList Debug]|r " .. msg)
    end
end

-- Get the equipment slot for an item
function BISListContextMenu:GetItemSlot(itemLink)
    if not itemLink then return nil end

    -- Extract item ID from link
    local _, _, itemId = string.find(itemLink, "item:(%d+)")
    if not itemId then
        DebugLog("GetItemSlot: Failed to extract item ID from link")
        return nil
    end

    DebugLog("GetItemSlot: Extracted item ID: " .. itemId)

    -- Correct order for vanilla 1.12.1:
    -- itemName, itemLink, itemRarity, itemLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture
    local itemName, itemLink2, itemRarity, itemLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(itemId)

    DebugLog("GetItemSlot: GetItemInfo results:")
    DebugLog("  itemName: " .. tostring(itemName))
    DebugLog("  itemEquipLoc: " .. tostring(itemEquipLoc))
    DebugLog("  itemType: " .. tostring(itemType))
    DebugLog("  itemSubType: " .. tostring(itemSubType))

    if not itemEquipLoc or itemEquipLoc == "" then
        DebugLog("GetItemSlot: No equipment location (not equippable or not cached)")
        return nil
    end

    -- INVTYPE_WEAPON means one-hand weapon - use dedicated One-Hand slot (19)
    if itemEquipLoc == "INVTYPE_WEAPON" then
        DebugLog("GetItemSlot: INVTYPE_WEAPON detected, using One-Hand slot")
        return 19
    end

    -- Map itemEquipLoc to slot IDs
    local slotMap = {
        ["INVTYPE_HEAD"] = 1,
        ["INVTYPE_NECK"] = 2,
        ["INVTYPE_SHOULDER"] = 3,
        ["INVTYPE_BODY"] = 4,
        ["INVTYPE_CHEST"] = 5,
        ["INVTYPE_ROBE"] = 5,
        ["INVTYPE_WAIST"] = 6,
        ["INVTYPE_LEGS"] = 7,
        ["INVTYPE_FEET"] = 8,
        ["INVTYPE_WRIST"] = 9,
        ["INVTYPE_HAND"] = 10,
        ["INVTYPE_FINGER"] = 11,
        ["INVTYPE_TRINKET"] = 13,
        ["INVTYPE_CLOAK"] = 15,
        ["INVTYPE_2HWEAPON"] = 16,
        ["INVTYPE_WEAPONMAINHAND"] = 16,
        ["INVTYPE_WEAPONOFFHAND"] = 17,
        ["INVTYPE_SHIELD"] = 17,
        ["INVTYPE_HOLDABLE"] = 17,
        ["INVTYPE_RANGED"] = 18,
        ["INVTYPE_RANGEDRIGHT"] = 18,
        ["INVTYPE_THROWN"] = 18,
        ["INVTYPE_RELIC"] = 18,
    }

    local slotId = slotMap[itemEquipLoc]
    DebugLog("GetItemSlot: Mapped to slot ID: " .. tostring(slotId))
    return slotId
end

-- Show slot selection dialog
function BISListContextMenu:ShowSlotSelectionDialog(itemLink)
    StaticPopupDialogs["BISLIST_SELECT_SLOT"] = {
        text = "Select equipment slot for " .. itemLink .. ":",
        button1 = "Cancel",
        hasEditBox = 0,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        OnShow = function()
            -- Create buttons for each slot
            local yOffset = -60
            for i, slot in ipairs(BISList.Slots) do
                local button = CreateFrame("Button", "BISListSlotButton"..i, this, "UIPanelButtonTemplate")
                button:SetWidth(180)
                button:SetHeight(25)
                button:SetPoint("TOP", 0, yOffset)
                button:SetText(slot.name)
                button:SetScript("OnClick", function()
                    BISListContextMenu:AddItemToSlot(itemLink, slot.id)
                    this:GetParent():Hide()
                end)
                yOffset = yOffset - 30
            end
        end,
        OnHide = function()
            -- Clean up buttons
            for i = 1, 17 do
                local button = getglobal("BISListSlotButton"..i)
                if button then
                    button:Hide()
                    button:SetParent(nil)
                end
            end
        end
    }

    StaticPopup_Show("BISLIST_SELECT_SLOT")
end

-- Show weapon slot selection dialog (Main Hand / Off Hand)
-- Used for INVTYPE_WEAPON items that can go in either hand
local pendingWeaponItemLink = nil
local pendingWeaponItemName = nil
local pendingWeaponSourceInfo = nil

function BISListContextMenu:ShowWeaponSlotDialog(itemLink, itemName, sourceInfo)
    pendingWeaponItemLink = itemLink
    pendingWeaponItemName = itemName
    pendingWeaponSourceInfo = sourceInfo

    StaticPopupDialogs["BISLIST_WEAPON_SLOT"] = {
        text = "Select slot for one-hand weapon:",
        button1 = "Main Hand",
        button2 = "Off Hand",
        button3 = "Cancel",
        OnAccept = function()
            -- Main Hand (slot 16)
            local itemId = BISList:GetItemIdFromLink(pendingWeaponItemLink)
            if itemId then
                BISList:AddItem(pendingWeaponItemLink, 16, pendingWeaponItemName, pendingWeaponSourceInfo)
                if BISListUI and BISListUI.Refresh and BISListUI:IsVisible() then
                    BISListUI:Refresh()
                end
            end
        end,
        OnCancel = function()
            -- Off Hand (slot 17)
            local itemId = BISList:GetItemIdFromLink(pendingWeaponItemLink)
            if itemId then
                BISList:AddItem(pendingWeaponItemLink, 17, pendingWeaponItemName, pendingWeaponSourceInfo)
                if BISListUI and BISListUI.Refresh and BISListUI:IsVisible() then
                    BISListUI:Refresh()
                end
            end
        end,
        OnAlt = function()
            -- Cancel - do nothing
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1
    }

    StaticPopup_Show("BISLIST_WEAPON_SLOT")
end

-- Add item to a specific slot with notes dialog
function BISListContextMenu:AddItemToSlot(itemLink, slotId)
    StaticPopupDialogs["BISLIST_ADD_NOTES"] = {
        text = "Add notes for " .. itemLink .. ":",
        button1 = "Add",
        button2 = "Skip",
        hasEditBox = 1,
        maxLetters = 100,
        OnAccept = function()
            local editBox = getglobal(this:GetParent():GetName().."EditBox")
            local notes = editBox:GetText()
            BISList:AddItem(itemLink, slotId, notes)
            if BISListUI and BISListUI.Refresh then
                BISListUI:Refresh()
            end
        end,
        OnCancel = function()
            -- Add without notes
            BISList:AddItem(itemLink, slotId, "")
            if BISListUI and BISListUI.Refresh then
                BISListUI:Refresh()
            end
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1
    }

    StaticPopup_Show("BISLIST_ADD_NOTES")
end

-- Handle context menu click
function BISListContextMenu:OnMenuClick(itemLink)
    if not itemLink then return end

    -- Try to auto-detect slot
    local slotId = self:GetItemSlot(itemLink)

    if slotId then
        -- Show notes dialog
        self:AddItemToSlot(itemLink, slotId)
    else
        -- Show slot selection dialog
        self:ShowSlotSelectionDialog(itemLink)
    end
end

-- Hook SetItemRef to catch item link clicks with Alt modifier
local originalSetItemRef = SetItemRef
function SetItemRef(link, text, button)
    -- If Alt-clicking an item link, add to BIS list
    if IsAltKeyDown() and string.find(link, "item:") then
        local slotId = BISListContextMenu:GetItemSlot(link)
        if slotId then
            BISList:AddItem(link, slotId, "")
            if BISListUI and BISListUI.Refresh and BISListUI:IsVisible() then
                BISListUI:Refresh()
            end
        end
        return
    end
    -- Call original function
    return originalSetItemRef(link, text, button)
end

-- Hook GameTooltip to track hovered items from chat links
local originalTooltipSetItem = GameTooltip.SetHyperlink
GameTooltip.SetHyperlink = function(self, link)
    originalTooltipSetItem(self, link)
    if link and string.find(link, "item:") then
        lastHoveredItemLink = link
    end
end

-- Hook ChatEdit_InsertLink to intercept Shift+Alt+Click and fix raw item links
local originalChatEdit_InsertLink = ChatEdit_InsertLink
function ChatEdit_InsertLink(link)
    if IsAltKeyDown() and link and string.find(link, "item:") then
        local slotId = BISListContextMenu:GetItemSlot(link)
        if slotId then
            BISList:AddItem(link, slotId, "")
            if BISListUI and BISListUI.Refresh and BISListUI:IsVisible() then
                BISListUI:Refresh()
            end
        end
        return
    end

    -- Fix raw item links (e.g., "item:12345:0:0:0") to proper hyperlink format
    if link and string.find(link, "^item:%d+") and not string.find(link, "|H") then
        local _, _, itemId = string.find(link, "item:(%d+)")
        if itemId then
            local itemName, _, itemRarity = GetItemInfo(tonumber(itemId))
            local nameToUse = itemName or ("Item " .. itemId)

            -- Get color based on rarity
            local colorCode = "ffffffff" -- default white
            if itemRarity then
                local r, g, b = GetItemQualityColor(itemRarity)
                if r then
                    colorCode = string.format("ff%02x%02x%02x", r * 255, g * 255, b * 255)
                end
            end

            link = "|c" .. colorCode .. "|Hitem:" .. itemId .. ":0:0:0|h[" .. nameToUse .. "]|h|r"
        end
    end

    -- Only call original if it exists
    if originalChatEdit_InsertLink then
        return originalChatEdit_InsertLink(link)
    end
end

-- Hook GameTooltip:SetBagItem to capture bag item hovers
local originalSetBagItem = GameTooltip.SetBagItem
GameTooltip.SetBagItem = function(self, bag, slot)
    local result = originalSetBagItem(self, bag, slot)
    local link = GetContainerItemLink(bag, slot)
    if link then
        lastHoveredItemLink = link
        -- The link itself is already the proper colored item link!
        lastHoveredItemName = link
    end
    return result
end

-- Hook GameTooltip:SetInventoryItem to capture equipped item hovers
local originalSetInventoryItem = GameTooltip.SetInventoryItem
GameTooltip.SetInventoryItem = function(self, unit, slot)
    local result = originalSetInventoryItem(self, unit, slot)
    local link = GetInventoryItemLink(unit, slot)
    if link then
        lastHoveredItemLink = link
        -- The link itself is already the proper colored item link!
        lastHoveredItemName = link
    end
    return result
end

-- Hook GameTooltip:SetLootItem for loot window
local originalSetLootItem = GameTooltip.SetLootItem
GameTooltip.SetLootItem = function(self, slot)
    local result = originalSetLootItem(self, slot)
    local link = GetLootSlotLink(slot)
    if link then
        lastHoveredItemLink = link
        -- The link itself is already the proper colored item link!
        lastHoveredItemName = link
    end
    return result
end

-- Continuously check for AtlasLoot and other addon item tooltips
local updateFrame = CreateFrame("Frame")
local lastLoggedItemID = nil
local lastLoggedFrame = nil
updateFrame:SetScript("OnUpdate", function()
    -- Handle hide timer countdown
    if hideTimer > 0 then
        hideTimer = hideTimer - arg1
        if hideTimer <= 0 then
            lastHoveredItemLink = nil
            lastHoveredItemName = nil
            lastHoveredSourceInfo = nil
            lastLoggedItemID = nil
            lastLoggedFrame = nil
        end
    end

    -- Check both GameTooltip and AtlasLootTooltip
    local tooltipVisible = GameTooltip:IsVisible() or (AtlasLootTooltip and AtlasLootTooltip:IsVisible())

    -- Debug: Log tooltip state periodically
    if tooltipVisible and not lastLoggedItemID then
        DebugLog("Tooltip became visible")
        DebugLog("  GameTooltip visible: " .. tostring(GameTooltip:IsVisible()))
        DebugLog("  AtlasLootTooltip visible: " .. tostring(AtlasLootTooltip and AtlasLootTooltip:IsVisible()))
    end

    if tooltipVisible then
        -- Reset hide timer since tooltip is visible
        hideTimer = 0

        -- Check mouse focus for AtlasLoot item buttons
        local mouseFocus = GetMouseFocus()
        local itemCaptured = false

        -- Debug: Always log frame info when tooltip is visible (not just when frame changes)
        if mouseFocus then
            local frameName = mouseFocus:GetName() or "unnamed"

            -- Only log if we haven't captured an item for this tooltip yet
            if not lastLoggedItemID or lastLoggedItemID == "noitem" then
                DebugLog("=== Tooltip visible, checking frame ===")
                DebugLog("Frame name: " .. frameName)
                DebugLog("Frame type: " .. (mouseFocus:GetObjectType() or "unknown"))

                -- Always check for item-related properties when debugging
                DebugLog("Checking properties:")
                DebugLog("  itemID: " .. tostring(mouseFocus.itemID))
                DebugLog("  link: " .. tostring(mouseFocus.link))
                DebugLog("  itemLink: " .. tostring(mouseFocus.itemLink))
                DebugLog("  itemIDName: " .. tostring(mouseFocus.itemIDName))
                DebugLog("  lootpage: " .. tostring(mouseFocus.lootpage))
                DebugLog("  buttoninfo: " .. tostring(mouseFocus.buttoninfo))

                lastLoggedFrame = mouseFocus
            end
        else
            if not lastLoggedItemID then
                DebugLog("WARNING: Tooltip visible but no mouse focus!")
            end
        end

        if mouseFocus then
            local rawID = nil
            local itemID = nil

            -- Check for itemID (regular AtlasLoot items)
            if mouseFocus.itemID then
                rawID = tostring(mouseFocus.itemID)

                -- If itemID has 's' prefix (set/special item), prefer dressingroomID as the real item ID
                if string.find(rawID, "^s%d+$") and mouseFocus.dressingroomID then
                    itemID = tonumber(mouseFocus.dressingroomID)
                    DebugLog("Item has 's' prefix, using dressingroomID: " .. tostring(itemID))
                else
                    -- Try direct conversion for regular numeric IDs
                    itemID = tonumber(rawID)

                    -- If that fails, extract from 's' prefix as fallback
                    if not itemID then
                        local _, _, numPart = string.find(rawID, "^s(%d+)$")
                        if numPart then
                            itemID = tonumber(numPart)
                            DebugLog("Extracted item ID from 's' prefix: " .. itemID)
                        end
                    end
                end
            -- Check for dressingroomID (container items like Tier Sets preview)
            elseif mouseFocus.dressingroomID then
                itemID = tonumber(mouseFocus.dressingroomID)
                DebugLog("Found dressingroomID: " .. tostring(itemID))
            end

            if itemID then
                -- Store the basic link format
                lastHoveredItemLink = "item:" .. itemID .. ":0:0:0"
                itemCaptured = true

                -- Only log when item changes to avoid spam
                if itemID ~= lastLoggedItemID then
                    DebugLog("MouseFocus itemID: " .. itemID)
                    DebugLog("  Frame name: " .. (mouseFocus:GetName() or "unnamed"))
                    DebugLog("  Link: " .. lastHoveredItemLink)
                    lastLoggedItemID = itemID
                end

                -- Capture item name from AtlasLoot database or GetItemInfo
                if mouseFocus.itemIDName then
                    lastHoveredItemName = mouseFocus.itemIDName
                else
                    -- Try to get name from GetItemInfo for container items
                    local itemName = GetItemInfo(itemID)
                    if itemName then
                        lastHoveredItemName = itemName
                    else
                        lastHoveredItemName = nil
                    end
                end

                -- Capture source information if available
                if AtlasLootItemsFrame and AtlasLootItemsFrame.refresh then
                    local dataID = AtlasLootItemsFrame.refresh[1]
                    local dataSource = AtlasLootItemsFrame.refresh[2]
                    if dataID and dataSource then
                        lastHoveredSourceInfo = dataID .. "|" .. dataSource
                    end
                end
            end
        end

        -- AtlasLoot stores itemID directly on GameTooltip
        if not itemCaptured then
            if GameTooltip.itemID then
                local itemID = tonumber(GameTooltip.itemID)
                if itemID then
                    -- Always use the constructed link format that will work
                    lastHoveredItemLink = "item:" .. itemID .. ":0:0:0"
                    itemCaptured = true

                    -- Only log when item changes
                    if itemID ~= lastLoggedItemID then
                        DebugLog("GameTooltip itemID: " .. itemID)
                        DebugLog("  Link: " .. lastHoveredItemLink)
                        lastLoggedItemID = itemID
                    end
                end
            end
        end

        -- Debug: Check if we failed to capture an item
        if not itemCaptured and tooltipVisible and GameTooltip:NumLines() > 0 then
            -- Only log once per tooltip show
            if not lastLoggedItemID or lastLoggedItemID ~= "noitem" then
                DebugLog("=== FAILED to capture item ===")
                DebugLog("GameTooltip.itemID: " .. tostring(GameTooltip.itemID))
                DebugLog("NumLines: " .. GameTooltip:NumLines())
                if GameTooltipTextLeft1 then
                    DebugLog("Tooltip text: " .. tostring(GameTooltipTextLeft1:GetText()))
                end
                if mouseFocus then
                    DebugLog("MouseFocus: " .. tostring(mouseFocus:GetName()))
                end
                lastLoggedItemID = "noitem"  -- Prevent spam
            end
        end

        -- Check common item link storage fields on mouse focus
        if mouseFocus then
            local itemLink = mouseFocus.link or mouseFocus.itemLink or mouseFocus.itemlink
            if itemLink and string.find(itemLink, "item:") then
                lastHoveredItemLink = itemLink
            end
        end
    end
end)

-- Hook GameTooltip:Hide with delayed clear to handle rapid tooltip changes
local originalHide = GameTooltip.Hide
GameTooltip.Hide = function(self)
    -- Don't clear immediately, set a timer to clear after 0.5 seconds
    hideTimer = 0.5
    return originalHide(self)
end

-- Helper function to convert AtlasLoot format to colored text
local function AtlasLoot_FixText(text)
    if not text then return nil end
    -- Convert AtlasLoot color codes to WoW color codes
    text = gsub(text, "=q1=", "|cffFFFFFF")  -- common
    text = gsub(text, "=q2=", "|cff1eff00")  -- uncommon
    text = gsub(text, "=q3=", "|cff0070dd")  -- rare
    text = gsub(text, "=q4=", "|cffa335ee")  -- epic
    text = gsub(text, "=q5=", "|cffFF8000")  -- legendary
    return text
end

-- Function to add/remove currently hovered item (called by keybinding)
function BISList_AddHoveredItem()
    DebugLog("=== BISList_AddHoveredItem called ===")
    DebugLog("lastHoveredItemLink: " .. tostring(lastHoveredItemLink))

    if lastHoveredItemLink then
        DebugLog("Calling GetItemSlot for: " .. lastHoveredItemLink)
        local slotId = BISListContextMenu:GetItemSlot(lastHoveredItemLink)
        DebugLog("GetItemSlot returned: " .. tostring(slotId))

        if slotId then
            -- Extract item ID
            local itemId = BISList:GetItemIdFromLink(lastHoveredItemLink)
            DebugLog("Item ID: " .. tostring(itemId))

            if itemId then
                -- Check if item already exists in the slot
                if BISList:ItemExistsInSlot(slotId, itemId) then
                    -- Remove it
                    DebugLog("Item exists, removing")
                    BISList:RemoveItem(slotId, itemId)
                else
                    -- Try to get proper item name from various sources
                    local itemName = lastHoveredItemName
                    if not itemName or itemName == "" or string.find(itemName, "^item:") then
                        -- Try AtlasLootTooltip first (for container items like Tier Sets)
                        if AtlasLootTooltip and AtlasLootTooltip:IsVisible() and AtlasLootTooltipTextLeft1 then
                            itemName = AtlasLootTooltipTextLeft1:GetText()
                        end
                        -- Fallback to GetItemInfo cache
                        if not itemName or itemName == "" then
                            local cachedName, cachedLink = GetItemInfo(itemId)
                            if cachedName then
                                itemName = cachedName
                            end
                        end
                    end

                    -- Add it with captured name and source info
                    DebugLog("Item doesn't exist, adding")
                    DebugLog("  Name: " .. tostring(itemName))
                    DebugLog("  Source: " .. tostring(lastHoveredSourceInfo))
                    BISList:AddItem(lastHoveredItemLink, slotId, itemName, lastHoveredSourceInfo)
                end

                -- Refresh UI if visible
                if BISListUI and BISListUI.Refresh and BISListUI:IsVisible() then
                    BISListUI:Refresh()
                end
            else
                DebugLog("ERROR: Could not extract item ID from link")
            end
        else
            -- Check if it's a one-hand weapon (INVTYPE_WEAPON) that needs slot selection
            local itemId = BISList:GetItemIdFromLink(lastHoveredItemLink)
            if itemId then
                local _, _, _, _, _, _, _, itemEquipLoc = GetItemInfo(itemId)
                if itemEquipLoc == "INVTYPE_WEAPON" then
                    DebugLog("One-hand weapon detected, showing slot selection dialog")
                    -- Get item name for the dialog
                    local itemName = lastHoveredItemName
                    if not itemName or itemName == "" or string.find(itemName, "^item:") then
                        if AtlasLootTooltip and AtlasLootTooltip:IsVisible() and AtlasLootTooltipTextLeft1 then
                            itemName = AtlasLootTooltipTextLeft1:GetText()
                        end
                        if not itemName or itemName == "" then
                            local cachedName = GetItemInfo(itemId)
                            if cachedName then
                                itemName = cachedName
                            end
                        end
                    end
                    BISListContextMenu:ShowWeaponSlotDialog(lastHoveredItemLink, itemName, lastHoveredSourceInfo)
                else
                    DebugLog("ERROR: GetItemSlot returned nil - cannot determine slot (equipLoc: " .. tostring(itemEquipLoc) .. ")")
                end
            else
                DebugLog("ERROR: GetItemSlot returned nil - cannot determine slot")
            end
        end
    else
        DebugLog("ERROR: No item link captured (lastHoveredItemLink is nil)")
    end
end

-- Slash command for manual testing
SLASH_BISTEST1 = "/bistest"
SlashCmdList["BISTEST"] = function(msg)
    BISList_AddHoveredItem()
end

-- Slash command to toggle debug mode
SLASH_BISDEBUG1 = "/bisdebug"
SlashCmdList["BISDEBUG"] = function(msg)
    DEBUG_MODE = not DEBUG_MODE
    if DEBUG_MODE then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00BISList:|r Debug mode enabled")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00BISList:|r Debug mode disabled")
    end
end

-- Slash command to manually check current mouse focus
SLASH_BISCHECK1 = "/bischeck"
SlashCmdList["BISCHECK"] = function(msg)
    -- Always output, regardless of DEBUG_MODE
    DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00[BISCheck]|r === Manual check requested ===")
    local mouseFocus = GetMouseFocus()
    if mouseFocus then
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00[BISCheck]|r Mouse focus frame: " .. tostring(mouseFocus:GetName()))
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00[BISCheck]|r   Type: " .. tostring(mouseFocus:GetObjectType()))
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00[BISCheck]|r   itemID: " .. tostring(mouseFocus.itemID))
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00[BISCheck]|r   dressingroomID: " .. tostring(mouseFocus.dressingroomID))
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00[BISCheck]|r   link: " .. tostring(mouseFocus.link))
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00[BISCheck]|r   itemLink: " .. tostring(mouseFocus.itemLink))
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00[BISCheck]|r   itemIDName: " .. tostring(mouseFocus.itemIDName))
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00[BISCheck]|r   container: " .. tostring(mouseFocus.container))

        -- Check parent
        local parent = mouseFocus:GetParent()
        if parent then
            DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00[BISCheck]|r   Parent: " .. tostring(parent:GetName()))
            if parent.itemID then
                DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00[BISCheck]|r     Parent.itemID: " .. tostring(parent.itemID))
            end
            if parent.container then
                DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00[BISCheck]|r     Parent.container: " .. tostring(parent.container))
            end
        end

        -- Check all child frames
        local numChildren = mouseFocus:GetNumChildren()
        if numChildren > 0 then
            DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00[BISCheck]|r   NumChildren: " .. numChildren)
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00[BISCheck]|r No mouse focus!")
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00[BISCheck]|r GameTooltip visible: " .. tostring(GameTooltip:IsVisible()))
    DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00[BISCheck]|r GameTooltip.itemID: " .. tostring(GameTooltip.itemID))
    if GameTooltipTextLeft1 then
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00[BISCheck]|r GameTooltip text: " .. tostring(GameTooltipTextLeft1:GetText()))
    end
    -- Check AtlasLootTooltip
    if AtlasLootTooltip then
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00[BISCheck]|r AtlasLootTooltip visible: " .. tostring(AtlasLootTooltip:IsVisible()))
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00[BISCheck]|r AtlasLootTooltip.itemID: " .. tostring(AtlasLootTooltip.itemID))
        if AtlasLootTooltipTextLeft1 then
            DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00[BISCheck]|r AtlasLootTooltip text: " .. tostring(AtlasLootTooltipTextLeft1:GetText()))
        end
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00[BISCheck]|r lastHoveredItemLink: " .. tostring(lastHoveredItemLink))

    -- Try to parse item from tooltip text
    if GameTooltip:IsVisible() and GameTooltipTextLeft1 then
        local text = GameTooltipTextLeft1:GetText()
        if text then
            DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00[BISCheck]|r Attempting to find item by name: " .. text)
        end
    end
end

-- Hook into the UI
local hookFrame = CreateFrame("Frame")
hookFrame:RegisterEvent("PLAYER_LOGIN")
hookFrame:SetScript("OnEvent", function()
    if event == "PLAYER_LOGIN" then
        -- Set default keybinding if none is set
        local key1, key2 = GetBindingKey("BISLIST_ADD")
        if not key1 and not key2 then
            SetBinding("ALT-B", "BISLIST_ADD")
            SaveBindings(GetCurrentBindingSet())
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00BISList:|r Loaded! Default keybind set to ALT-B. Hover items and press ALT-B to add to your list, or use /bis to view.")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00BISList:|r Loaded! Hover items and press ALT-B to add to your list, or use /bis to view.")
        end
    end
end)
