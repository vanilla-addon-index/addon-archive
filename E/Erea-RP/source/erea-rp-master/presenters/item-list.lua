-- ============================================================================
-- item-list.lua - EreaRpMasterItemListFrame Controller
-- ============================================================================
-- UI Structure: views/item-list.xml
-- Frame: EreaRpMasterItemListFrame (defined in XML)
--
-- PURPOSE: Manages the item list UI behavior — row pool, selection,
--          toolbar actions, scroll, status bar.
--
-- METHODS:
--   EreaRpMasterItemListFrame:Initialize()        - Setup refs, handlers
--   EreaRpMasterItemListFrame:RefreshList()        - Reload items, rebuild rows
--   EreaRpMasterItemListFrame:GetOrCreateRow(i)    - Row pool management
--   EreaRpMasterItemListFrame:SelectItem(id)       - Track selection, update UI
--   EreaRpMasterItemListFrame:ShowContextMenu(id)  - Right-click context menu
--   EreaRpMasterItemListFrame:UpdateStatusBar()    - Update "X item(s)" text
--
-- DEPENDENCIES:
--   - EreaRpMasterItemLibrary (services/item-library.lua)
--   - EreaRpMasterDB (SavedVariable)
-- ============================================================================

local ROW_HEIGHT = 60
local ICON_SIZE = 40

-- ============================================================================
-- Initialize
-- ============================================================================
function EreaRpMasterItemListFrame:Initialize()
    local self = EreaRpMasterItemListFrame

    -- Store frame references
    self.scrollFrame = EreaRpMasterItemListScrollFrame
    self.scrollChild = EreaRpMasterItemListScrollFrameScrollChild
    self.bottomBar = EreaRpMasterItemListFrameBottomBar
    self.dbNameEditBox = EreaRpMasterItemListFrameBottomBarDbNameEditBox
    self.newButton = EreaRpMasterItemListFrameBottomBarNewButton
    self.commitButton = EreaRpMasterItemListFrameBottomBarCommitButton
    self.syncButton = EreaRpMasterItemListFrameBottomBarSyncButton
    self.statusText = EreaRpMasterItemListFrameBottomBarStatusText

    -- Row pool
    self.rowFrames = {}
    self.selectedItemId = nil

    -- Context menu dropdown
    self.contextMenu = CreateFrame("Frame", "EreaRpMasterItemListContextMenu", UIParent, "UIDropDownMenuTemplate")

    -- OnShow → auto-refresh when tab selected
    self:SetScript("OnShow", function()
        EreaRpMasterItemListFrame:RefreshList()
    end)

    -- New button
    self.newButton:SetScript("OnClick", function()
        EreaRpMasterItemEditorFrame:Open(nil, function()
            EreaRpMasterItemListFrame:RefreshList()
        end)
    end)

    -- Commit button
    self.commitButton:SetScript("OnClick", function()
        -- Save database name from EditBox
        local dbName = EreaRpMasterItemListFrame.dbNameEditBox:GetText()
        if EreaRpMasterDB then
            EreaRpMasterDB.databaseName = dbName
        end

        local ok, err = EreaRpMasterItemLibrary:CommitDatabase()
        if ok then
            EreaRpMasterItemListFrame:RefreshList()
        end
    end)

    -- Sync button
    self.syncButton:SetScript("OnClick", function()
        EreaRpMasterItemLibrary:SyncToRaid()
    end)

    -- DbNameEditBox OnEditFocusLost → save to DB
    self.dbNameEditBox:SetScript("OnEditFocusLost", function()
        if EreaRpMasterDB then
            EreaRpMasterDB.databaseName = EreaRpMasterItemListFrame.dbNameEditBox:GetText()
        end
    end)

    -- Close context menu when clicking on scroll frame (empty space)
    self.scrollFrame:SetScript("OnMouseDown", function()
        CloseDropDownMenus()
    end)

    -- Re-layout rows when main window resizes
    EreaRpMasterMainWindow:SetScript("OnSizeChanged", function()
        EreaRpMasterMainWindow:SaveSize()
        if EreaRpMasterItemListFrame:IsShown() then
            EreaRpMasterItemListFrame:RefreshList()
        end
    end)
end

-- ============================================================================
-- RefreshList - Load items, rebuild rows, update scroll
-- ============================================================================
function EreaRpMasterItemListFrame:RefreshList()
    local self = EreaRpMasterItemListFrame

    -- Load database name into EditBox
    if EreaRpMasterDB then
        self.dbNameEditBox:SetText(EreaRpMasterDB.databaseName or "")
    end

    -- Get sorted items
    local items = EreaRpMasterItemLibrary:GetAllItems()
    local itemCount = table.getn(items)  -- Lua 5.0: no # operator

    -- Derive content width from the main window (always has explicit size)
    -- MainWindow insets: 15px left + 15px right = 30px for the ContentFrame
    -- Reserve 22px for UIPanelScrollFrameTemplate scrollbar
    local mainWidth = EreaRpMasterMainWindow:GetWidth() or 700
    local contentWidth = mainWidth - 30 - 22

    -- Set scroll child width explicitly (WoW 1.12 scroll children ignore anchors)
    self.scrollChild:SetWidth(contentWidth)

    -- Hide all existing rows
    for i = 1, table.getn(self.rowFrames) do  -- Lua 5.0: no # operator
        self.rowFrames[i]:Hide()
    end

    -- Create/reuse rows for each item
    for i = 1, itemCount do
        local item = items[i]
        local row = self:GetOrCreateRow(i)

        -- Position row with explicit width (TOPRIGHT anchors don't work in scroll children)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", 0, -((i - 1) * ROW_HEIGHT))
        row:SetWidth(contentWidth)
        row:SetHeight(ROW_HEIGHT)

        -- Set icon
        if item.icon and item.icon ~= "" then
            row.icon:SetTexture(item.icon)
        else
            row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end

        -- Set name
        row.nameText:SetText(item.name or "Unnamed")

        -- Set tooltip preview (truncate if needed)
        local tooltipPreview = item.tooltip or ""
        if string.len(tooltipPreview) > 80 then
            tooltipPreview = string.sub(tooltipPreview, 1, 77) .. "..."
        end
        row.tooltipText:SetText(tooltipPreview)

        -- Color: red if uncommitted, white if committed
        local uncommitted = EreaRpMasterItemLibrary:IsItemUncommitted(item)
        if uncommitted then
            row.nameText:SetTextColor(1, 0.4, 0.4)
            row.tooltipText:SetTextColor(0.8, 0.3, 0.3)
        else
            row.nameText:SetTextColor(1, 1, 1)
            row.tooltipText:SetTextColor(0.7, 0.7, 0.7)
        end

        -- Highlight selected row
        if self.selectedItemId and item.id == self.selectedItemId then
            row:SetBackdropColor(0.2, 0.2, 0.4, 1)
        else
            row:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
        end

        -- Store item ID on row for click handler
        row.itemId = item.id

        -- Click handler (Lua 5.0: arg1 = mouse button)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetScript("OnClick", function()
            if arg1 == "RightButton" then
                -- Right-click: force select (no toggle) + show context menu
                EreaRpMasterItemListFrame.selectedItemId = nil
                EreaRpMasterItemListFrame:SelectItem(this.itemId)
                EreaRpMasterItemListFrame:ShowContextMenu(this.itemId)
            else
                -- Left-click: select item and close any open context menu
                EreaRpMasterItemListFrame:SelectItem(this.itemId)
                CloseDropDownMenus()
            end
        end)

        -- Hover effect
        row:SetScript("OnEnter", function()
            if this.itemId ~= EreaRpMasterItemListFrame.selectedItemId then
                this:SetBackdropColor(0.15, 0.15, 0.25, 1)
            end
        end)
        row:SetScript("OnLeave", function()
            if this.itemId ~= EreaRpMasterItemListFrame.selectedItemId then
                this:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
            end
        end)

        row:Show()
    end

    -- Update scroll child height
    local totalHeight = itemCount * ROW_HEIGHT
    if totalHeight < 1 then totalHeight = 1 end
    self.scrollChild:SetHeight(totalHeight)
    self.scrollFrame:UpdateScrollChildRect()

    -- Update status bar
    self:UpdateStatusBar()
end

-- ============================================================================
-- GetOrCreateRow - Row pool management
-- ============================================================================
function EreaRpMasterItemListFrame:GetOrCreateRow(index)
    local self = EreaRpMasterItemListFrame

    if self.rowFrames[index] then
        return self.rowFrames[index]
    end

    -- Create new row button with backdrop
    local rowName = "EreaRpMasterItemListRow" .. index
    local row = CreateFrame("Button", rowName, self.scrollChild)
    row:SetHeight(ROW_HEIGHT)
    row:EnableMouse(true)

    -- Backdrop
    row:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    row:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
    row:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.5)

    -- Icon texture (40x40)
    local icon = row:CreateTexture(rowName .. "Icon", "ARTWORK")
    icon:SetWidth(ICON_SIZE)
    icon:SetHeight(ICON_SIZE)
    icon:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.icon = icon

    -- Name FontString
    local nameText = row:CreateFontString(rowName .. "Name", "OVERLAY", "GameFontNormal")
    nameText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -4)
    nameText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -4)
    nameText:SetJustifyH("LEFT")
    row.nameText = nameText

    -- Tooltip preview FontString
    local tooltipText = row:CreateFontString(rowName .. "Tooltip", "OVERLAY", "GameFontHighlightSmall")
    tooltipText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -4)
    tooltipText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, 0)
    tooltipText:SetJustifyH("LEFT")
    tooltipText:SetTextColor(0.7, 0.7, 0.7)
    row.tooltipText = tooltipText

    self.rowFrames[index] = row
    return row
end

-- ============================================================================
-- SelectItem - Track selection, update row highlights
-- ============================================================================
function EreaRpMasterItemListFrame:SelectItem(id)
    local self = EreaRpMasterItemListFrame

    -- nil clears selection; clicking same item toggles off
    if id == nil then
        self.selectedItemId = nil
    elseif self.selectedItemId == id then
        self.selectedItemId = nil
    else
        self.selectedItemId = id
    end

    -- Update row highlight colors
    for i = 1, table.getn(self.rowFrames) do  -- Lua 5.0: no # operator
        local row = self.rowFrames[i]
        if row:IsShown() then
            if row.itemId == self.selectedItemId then
                row:SetBackdropColor(0.2, 0.2, 0.4, 1)
            else
                row:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
            end
        end
    end
end

-- ============================================================================
-- UpdateStatusBar - Show "X item(s) (Y uncommitted)" or "(all committed)"
-- ============================================================================
function EreaRpMasterItemListFrame:UpdateStatusBar()
    local self = EreaRpMasterItemListFrame

    local itemCount = EreaRpMasterItemLibrary:GetItemCount()
    local uncommittedCount = EreaRpMasterItemLibrary:GetUncommittedCount()

    local text = itemCount .. " item(s)"
    if uncommittedCount > 0 then
        text = text .. " (" .. uncommittedCount .. " uncommitted)"
    elseif itemCount > 0 then
        text = text .. " (all committed)"
    end

    self.statusText:SetText(text)
end

-- ============================================================================
-- ShowContextMenu - Right-click context menu for an item row
-- ============================================================================
function EreaRpMasterItemListFrame:ShowContextMenu(id)
    local self = EreaRpMasterItemListFrame
    local item = EreaRpMasterItemLibrary:GetItem(id)
    if not item then return end

    local menuId = id  -- capture for menu init closure

    -- Lua 5.0: UIDropDownMenu_Initialize with "MENU" displayMode
    UIDropDownMenu_Initialize(self.contextMenu, function()
        local info

        -- Edit
        info = {}
        info.text = "Edit"
        info.notCheckable = 1
        info.func = function()
            local editItem = EreaRpMasterItemLibrary:GetItem(menuId)
            if editItem then
                EreaRpMasterItemEditorFrame:Open(editItem, function()
                    EreaRpMasterItemListFrame:RefreshList()
                end)
            end
        end
        UIDropDownMenu_AddButton(info)

        -- Give Item (only if committed — needs guid from committed database)
        local committedItem = EreaRpMasterDB
            and EreaRpMasterDB.committedDatabase
            and EreaRpMasterDB.committedDatabase.items
            and EreaRpMasterDB.committedDatabase.items[menuId]
        info = {}
        info.text = "Give Item"
        info.notCheckable = 1
        if committedItem and committedItem.guid then
            info.func = function()
                EreaRpMasterGiveItemFrame:Open(committedItem)
            end
        else
            info.disabled = 1
        end
        UIDropDownMenu_AddButton(info)

        -- Delete
        info = {}
        info.text = "Delete"
        info.notCheckable = 1
        info.func = function()
            EreaRpMaster_PendingDeleteItemId = menuId
            local delItem = EreaRpMasterItemLibrary:GetItem(menuId)
            StaticPopup_Show("EreaRpMaster_DELETE_ITEM", (delItem and delItem.name) or "Unknown")
        end
        UIDropDownMenu_AddButton(info)

        -- Revert (only if item has uncommitted changes that can be reverted)
        local hasCommitted = EreaRpMasterDB
            and EreaRpMasterDB.committedDatabase
            and EreaRpMasterDB.committedDatabase.items
            and EreaRpMasterDB.committedDatabase.items[menuId]
        local hasUncommitted = EreaRpMasterItemLibrary:IsItemUncommitted(item)
        if hasCommitted and hasUncommitted then
            info = {}
            info.text = "Revert"
            info.notCheckable = 1
            info.func = function()
                EreaRpMaster_PendingRevertItemId = menuId
                local revItem = EreaRpMasterItemLibrary:GetItem(menuId)
                StaticPopup_Show("EreaRpMaster_REVERT_ITEM", (revItem and revItem.name) or "Unknown")
            end
            UIDropDownMenu_AddButton(info)
        else
            info = {}
            info.text = "Revert"
            info.notCheckable = 1
            info.disabled = 1
            UIDropDownMenu_AddButton(info)
        end

        -- Cancel
        info = {}
        info.text = "Cancel"
        info.notCheckable = 1
        info.func = function()
            CloseDropDownMenus()
        end
        UIDropDownMenu_AddButton(info)
    end, "MENU")

    ToggleDropDownMenu(1, nil, self.contextMenu, "cursor", 0, 0)
end

-- ============================================================================
-- StaticPopup: Delete Item Confirmation
-- ============================================================================
-- Lua 5.0: StaticPopup callbacks cannot receive parameters, use global state
EreaRpMaster_PendingDeleteItemId = nil

StaticPopupDialogs["EreaRpMaster_DELETE_ITEM"] = {
    text = "Delete '%s'?",
    button1 = "Delete",
    button2 = "Cancel",
    OnAccept = function()
        if EreaRpMaster_PendingDeleteItemId then
            EreaRpMasterItemLibrary:DeleteItem(EreaRpMaster_PendingDeleteItemId)
            EreaRpMasterItemListFrame:SelectItem(nil)
            EreaRpMasterItemListFrame:RefreshList()
            EreaRpMaster_PendingDeleteItemId = nil
        end
    end,
    OnCancel = function()
        EreaRpMaster_PendingDeleteItemId = nil
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true
}

-- ============================================================================
-- StaticPopup: Revert Item Confirmation
-- ============================================================================
-- Lua 5.0: StaticPopup callbacks cannot receive parameters, use global state
EreaRpMaster_PendingRevertItemId = nil

StaticPopupDialogs["EreaRpMaster_REVERT_ITEM"] = {
    text = "Revert '%s' to last committed version?",
    button1 = "Revert",
    button2 = "Cancel",
    OnAccept = function()
        if EreaRpMaster_PendingRevertItemId then
            EreaRpMasterItemLibrary:RevertItem(EreaRpMaster_PendingRevertItemId)
            EreaRpMasterItemListFrame:RefreshList()
            EreaRpMaster_PendingRevertItemId = nil
        end
    end,
    OnCancel = function()
        EreaRpMaster_PendingRevertItemId = nil
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true
}
