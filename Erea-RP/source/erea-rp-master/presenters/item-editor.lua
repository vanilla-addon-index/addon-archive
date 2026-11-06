-- ============================================================================
-- item-editor.lua - EreaRpMasterItemEditorFrame Controller
-- ============================================================================
-- UI Structure: views/item-editor.xml
-- Frame: EreaRpMasterItemEditorFrame (defined in XML)
--
-- PURPOSE: Manages the item editor dialog — create/edit items, icon selection,
--          content editing with default/template columns.
--
-- METHODS:
--   EreaRpMasterItemEditorFrame:Initialize()            - Setup refs, handlers
--   EreaRpMasterItemEditorFrame:Open(item, onSaveCb)    - Open editor for item
--   EreaRpMasterItemEditorFrame:Close()                 - Hide and clear state
--   EreaRpMasterItemEditorFrame:Save()                  - Validate and persist
--   EreaRpMasterItemEditorFrame:ResetPositions()        - Reset window position to default
--
-- DEPENDENCIES:
--   - EreaRpMasterItemLibrary (services/item-library.lua)
--   - EreaRpMasterIconPickerFrame (presenters/icon-picker.lua)
-- ============================================================================

-- ============================================================================
-- DeepCopyActions - Deep copy an actions array (local helper)
-- ============================================================================
local function DeepCopyActions(actions)
    local copy = {}
    if not actions then return copy end
    for i = 1, table.getn(actions) do -- Lua 5.0: no # operator
        local action = actions[i]
        local actionCopy = {
            id = action.id,
            label = action.label,
            sendStatus = action.sendStatus or false,
            methods = {},
            conditions = {}
        }
        if action.conditions then
            actionCopy.conditions.customTextEmpty = action.conditions.customTextEmpty
            actionCopy.conditions.counterGreaterThanZero = action.conditions.counterGreaterThanZero
        end
        if action.methods then
            for j = 1, table.getn(action.methods) do -- Lua 5.0: no # operator
                local method = action.methods[j]
                local methodCopy = { type = method.type, params = {} }
                if method.params then
                    for key, value in pairs(method.params) do
                        methodCopy.params[key] = value
                    end
                end
                table.insert(actionCopy.methods, methodCopy)
            end
        end
        table.insert(copy, actionCopy)
    end
    return copy
end

-- ============================================================================
-- Initialize
-- ============================================================================
function EreaRpMasterItemEditorFrame:Initialize()
    local self = EreaRpMasterItemEditorFrame

    -- Store frame references
    self.titleBar = EreaRpMasterItemEditorFrameTitleBar
    self.closeButton = EreaRpMasterItemEditorFrameCloseButton
    self.iconButton = EreaRpMasterItemEditorFrameIconButton
    self.iconTexture = EreaRpMasterItemEditorFrameIconButtonIconTexture
    self.nameEditBox = EreaRpMasterItemEditorFrameNameEditBox
    self.tooltipEditBox = EreaRpMasterItemEditorFrameTooltipContainerEditBox
    self.handoutEditBox = EreaRpMasterItemEditorFrameHandoutEditBox
    self.counterEditBox = EreaRpMasterItemEditorFrameCounterEditBox
    self.defaultContentEditBox = EreaRpMasterItemEditorDefaultContentEditBox
    self.defaultContentScroll = EreaRpMasterItemEditorDefaultContentScroll
    self.templateContentEditBox = EreaRpMasterItemEditorTemplateContentEditBox
    self.templateContentScroll = EreaRpMasterItemEditorTemplateContentScroll
    self.copyRightButton = EreaRpMasterItemEditorFrameCopyRightButton
    self.copyLeftButton = EreaRpMasterItemEditorFrameCopyLeftButton
    self.saveButton = EreaRpMasterItemEditorFrameSaveButton
    self.cancelButton = EreaRpMasterItemEditorFrameCancelButton
    self.editActionsButton = EreaRpMasterItemEditorFrameEditActionsButton
    self.actionCountLabel = EreaRpMasterItemEditorFrameActionCountLabel

    -- State
    self.currentItem = nil
    self.onSaveCallback = nil
    self.currentIcon = ""
    self.currentActions = {}

    -- Dragging
    self.titleBar:SetScript("OnMouseDown", function()
        EreaRpMasterItemEditorFrame:StartMoving()
    end)
    self.titleBar:SetScript("OnMouseUp", function()
        EreaRpMasterItemEditorFrame:StopMovingOrSizing()
    end)

    -- Close button
    self.closeButton:SetScript("OnClick", function()
        EreaRpMasterItemEditorFrame:Close()
    end)

    -- Cancel button
    self.cancelButton:SetScript("OnClick", function()
        EreaRpMasterItemEditorFrame:Close()
    end)

    -- Save button
    self.saveButton:SetScript("OnClick", function()
        EreaRpMasterItemEditorFrame:Save()
    end)

    -- Icon button → open picker
    self.iconButton:SetScript("OnClick", function()
        EreaRpMasterIconPickerFrame:Open(
            EreaRpMasterItemEditorFrame.currentIcon,
            function(iconPath)
                EreaRpMasterItemEditorFrame.currentIcon = iconPath
                EreaRpMasterItemEditorFrame.iconTexture:SetTexture(iconPath)
            end
        )
    end)

    -- Copy buttons (default <-> template)
    self.copyRightButton:SetScript("OnClick", function()
        local text = EreaRpMasterItemEditorFrame.defaultContentEditBox:GetText()
        EreaRpMasterItemEditorFrame.templateContentEditBox:SetText(text)
        EreaRpMasterItemEditorFrame.templateContentScroll:UpdateScrollChildRect()
    end)
    self.copyLeftButton:SetScript("OnClick", function()
        local text = EreaRpMasterItemEditorFrame.templateContentEditBox:GetText()
        EreaRpMasterItemEditorFrame.defaultContentEditBox:SetText(text)
        EreaRpMasterItemEditorFrame.defaultContentScroll:UpdateScrollChildRect()
    end)

    -- Edit Actions button → open action editor
    self.editActionsButton:SetScript("OnClick", function()
        EreaRpMasterActionEditorFrame:Open(
            EreaRpMasterItemEditorFrame.currentActions,
            function(updatedActions)
                EreaRpMasterItemEditorFrame.currentActions = updatedActions
                EreaRpMasterItemEditorFrame:UpdateActionCountLabel()
            end
        )
    end)
end

-- ============================================================================
-- Reset Positions
-- ============================================================================
-- Reset item editor window position to default (center screen)
function EreaRpMasterItemEditorFrame:ResetPositions()
    -- Reset item editor window position
    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end

-- ============================================================================
-- UpdateActionCountLabel - Show "N action(s)" next to button
-- ============================================================================
function EreaRpMasterItemEditorFrame:UpdateActionCountLabel()
    local self = EreaRpMasterItemEditorFrame
    local count = table.getn(self.currentActions) -- Lua 5.0: no # operator
    self.actionCountLabel:SetText(count .. " action(s)")
end

-- ============================================================================
-- Open - Show editor populated with item data (or defaults for new)
-- ============================================================================
function EreaRpMasterItemEditorFrame:Open(item, onSaveCallback)
    local self = EreaRpMasterItemEditorFrame

    self.currentItem = item
    self.onSaveCallback = onSaveCallback

    if item then
        -- Editing existing item
        self.currentIcon = item.icon or ""
        self.currentActions = DeepCopyActions(item.actions)
        self.nameEditBox:SetText(item.name or "")
        self.tooltipEditBox:SetText(item.tooltip or "")
        self.handoutEditBox:SetText(item.defaultHandoutText or "")
        self.counterEditBox:SetText(tostring(item.initialCounter or 0))
        self.defaultContentEditBox:SetText(item.content or "")
        self.templateContentEditBox:SetText(item.contentTemplate or "")
    else
        -- New item — set defaults
        self.currentIcon = "Interface\\Icons\\INV_Misc_Note_01"
        self.currentActions = {}
        self.nameEditBox:SetText("")
        self.tooltipEditBox:SetText("")
        self.handoutEditBox:SetText("You found this item, check /rpplayer")
        self.counterEditBox:SetText("0")
        self.defaultContentEditBox:SetText("")
        self.templateContentEditBox:SetText("")
    end

    -- Update icon texture
    if self.currentIcon ~= "" then
        self.iconTexture:SetTexture(self.currentIcon)
    else
        self.iconTexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end

    -- Update scroll frames after populating content
    self.defaultContentScroll:UpdateScrollChildRect()
    self.templateContentScroll:UpdateScrollChildRect()

    -- Update action count label
    self:UpdateActionCountLabel()

    self:Show()
    self:Raise()
end

-- ============================================================================
-- Close - Hide and clear state
-- ============================================================================
function EreaRpMasterItemEditorFrame:Close()
    local self = EreaRpMasterItemEditorFrame

    self:Hide()
    self.currentItem = nil
    self.onSaveCallback = nil
    self.currentIcon = ""
    self.currentActions = {}
end

-- ============================================================================
-- Save - Validate, persist, invoke callback
-- ============================================================================
function EreaRpMasterItemEditorFrame:Save()
    local self = EreaRpMasterItemEditorFrame

    local name = self.nameEditBox:GetText() or ""
    local tooltip = self.tooltipEditBox:GetText() or ""
    local handout = self.handoutEditBox:GetText() or ""
    local counterText = self.counterEditBox:GetText() or "0"
    local content = self.defaultContentEditBox:GetText() or ""
    local contentTemplate = self.templateContentEditBox:GetText() or ""
    local icon = self.currentIcon or ""

    -- Validate: name required
    if name == "" then
        return
    end

    -- Validate: name length
    if string.len(name) > 50 then
        return
    end

    -- Validate: tooltip length
    if string.len(tooltip) > 120 then
        return
    end

    -- Validate: icon path
    if icon ~= "" and string.sub(icon, 1, 10) ~= "Interface\\" then
        return
    end

    -- Coerce counter
    local counter = tonumber(counterText) or 0

    local data = {
        name = name,
        icon = icon,
        tooltip = tooltip,
        defaultHandoutText = handout,
        content = content,
        contentTemplate = contentTemplate,
        initialCounter = counter,
        actions = self.currentActions
    }

    if self.currentItem then
        -- Update existing item
        EreaRpMasterItemLibrary:UpdateItem(self.currentItem.id, data)
    else
        -- Create new item
        EreaRpMasterItemLibrary:CreateItem(data)
    end

    -- Invoke callback
    local cb = self.onSaveCallback
    self:Close()
    if cb then
        cb()
    end
end
