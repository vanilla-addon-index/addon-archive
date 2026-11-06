-- ============================================================================
-- action-editor.lua - EreaRpMasterActionEditorFrame Controller
-- ============================================================================
-- UI Structure: views/action-editor-frame.xml
-- Frame: EreaRpMasterActionEditorFrame (defined in XML)
--
-- PURPOSE: Combined list+detail dialog for editing all actions on an item.
--          Left panel shows action list, right panel shows selected action's
--          label, conditions, and schema-driven method editors.
--
-- EDITOR MODULES (loaded before this file):
--   EreaRpMasterDestroyEditor   (action-editor-destroy.lua)
--   EreaRpMasterConsumeEditor   (action-editor-consume.lua)
--   EreaRpMasterAddTextEditor   (action-editor-add-text.lua)
--   EreaRpMasterCreateEditor    (action-editor-create.lua)
--   EreaRpMasterDisplayEditor   (action-editor-display.lua)
--   EreaRpMasterMergeEditor     (action-editor-merge.lua)
--
-- METHODS:
--   EreaRpMasterActionEditorFrame:Initialize()
--   EreaRpMasterActionEditorFrame:Open(actions, onSave)
--   EreaRpMasterActionEditorFrame:Close()
--   EreaRpMasterActionEditorFrame:Save()
--
-- DEPENDENCIES:
--   - EreaRpLibraries:RPActions() (method registry, validation)
-- ============================================================================

-- ============================================================================
-- IMPORTS
-- ============================================================================
local rpActions = EreaRpLibraries:RPActions()

-- Counters for unique frame names (WoW 1.12 requires global names)
local actionRowCounter = 0
local methodControlsCounter = 0

-- ============================================================================
-- EDITOR MAP - Maps method type to editor module
-- ============================================================================
local EDITOR_MAP = {
    DestroyObject = EreaRpMasterDestroyEditor,
    CreateObject = EreaRpMasterCreateEditor,
    AddText = EreaRpMasterAddTextEditor,
    ConsumeCharge = EreaRpMasterConsumeEditor,
    DisplayCinematic = EreaRpMasterDisplayEditor,
    MergeCinematic = EreaRpMasterMergeEditor,
}

-- ============================================================================
-- PreviewCinematic (local) - Show cinematic preview over the action editor
-- ============================================================================
-- EreaRpCinematicFrame is FULLSCREEN_DIALOG strata, which is above DIALOG,
-- so it renders on top of the action editor without any hide/restore needed.
-- ============================================================================
local function PreviewCinematic(methodFrame)
    if not methodFrame.GetPreviewData then return end
    local previewData = methodFrame:GetPreviewData()
    if not previewData then return end

    local speakerName = previewData.speakerName or ""
    local dialogueText = previewData.messageTemplate or ""

    -- Resolve placeholders for preview
    local playerName = UnitName("player")
    dialogueText = string.gsub(dialogueText, "{playerName}", playerName)
    dialogueText = string.gsub(dialogueText, "{customText}", "(preview)")

    -- Build config objects from preview data
    local leftConfig = {
        type = previewData.leftType or "none",
        portraitUnit = previewData.leftPortraitUnit or "player",
        animationKey = previewData.leftAnimationKey or "",
        loopMode = previewData.leftLoopMode or "pingpong"
    }
    local rightConfig = {
        type = previewData.rightType or "none",
        portraitUnit = previewData.rightPortraitUnit or "player",
        animationKey = previewData.rightAnimationKey or "",
        loopMode = previewData.rightLoopMode or "pingpong"
    }

    EreaRpCinematicFrame:ShowDialogue(playerName, speakerName, dialogueText, leftConfig, rightConfig)
end

-- ============================================================================
-- METHOD FRAME BUILDER (local)
-- ============================================================================

local function CreateMethodFrame(parent, currentMethods, methodIndex)
    local method = currentMethods[methodIndex]
    local methodDef = rpActions.GetMethodRegistry()[method.type]

    if not methodDef then
        return nil
    end

    -- Look up the editor module for this method type
    local editorModule = EDITOR_MAP[method.type]
    if not editorModule then
        return nil
    end

    -- Create the editor frame via the module factory
    local methodFrame = editorModule.Create(parent, method.params, methodIndex)

    -- Store method index for RemoveMethod
    methodFrame.methodIndex = methodIndex

    -- Instantiate controls overlay (Remove/Down/Up buttons defined in XML template)
    methodControlsCounter = methodControlsCounter + 1
    local controlsName = "EreaRpMasterMethodControls" .. methodControlsCounter
    local controls = CreateFrame("Frame", controlsName, methodFrame, "EreaRpMasterMethodControlsTemplate")
    controls:SetAllPoints(methodFrame)

    local removeBtn = _G[controlsName .. "RemoveBtn"]
    local downBtn   = _G[controlsName .. "DownBtn"]
    local upBtn     = _G[controlsName .. "UpBtn"]

    -- Disable boundary buttons based on position in list
    if methodIndex >= table.getn(currentMethods) then -- Lua 5.0: no # operator
        downBtn:Disable()
    end
    if methodIndex <= 1 then
        upBtn:Disable()
    end

    -- Wire up click handlers
    do
        local idx = methodIndex
        removeBtn:SetScript("OnClick", function()
            EreaRpMasterActionEditorFrame:RemoveMethod(idx)
        end)
        downBtn:SetScript("OnClick", function()
            EreaRpMasterActionEditorFrame:MoveMethodDown(idx)
        end)
        upBtn:SetScript("OnClick", function()
            EreaRpMasterActionEditorFrame:MoveMethodUp(idx)
        end)
    end

    -- Preview button for cinematic methods (DisplayCinematic and MergeCinematic)
    if method.type == "DisplayCinematic" or method.type == "MergeCinematic" then
        local previewBtn = CreateFrame("Button", nil, methodFrame, "UIPanelButtonTemplate")
        previewBtn:SetPoint("RIGHT", upBtn, "LEFT", -5, 0)
        previewBtn:SetWidth(60)
        previewBtn:SetHeight(20)
        previewBtn:SetText("Preview")

        do
            local mf = methodFrame
            previewBtn:SetScript("OnClick", function()
                PreviewCinematic(mf)
            end)
        end
    end

    return methodFrame
end

-- ============================================================================
-- DEEP COPY HELPERS (local)
-- ============================================================================

local function DeepCopyMethod(method)
    local copy = { type = method.type, params = {} }
    if method.params then
        for key, value in pairs(method.params) do
            copy.params[key] = value
        end
    end
    return copy
end

local function DeepCopyAction(action)
    local copy = {
        id = action.id,
        label = action.label,
        sendStatus = action.sendStatus or false,
        methods = {},
        conditions = {}
    }
    if action.conditions then
        copy.conditions.customTextEmpty = action.conditions.customTextEmpty
        copy.conditions.counterGreaterThanZero = action.conditions.counterGreaterThanZero
    end
    if action.methods then
        for i = 1, table.getn(action.methods) do -- Lua 5.0: no # operator
            table.insert(copy.methods, DeepCopyMethod(action.methods[i]))
        end
    end
    return copy
end

local function DeepCopyActions(actions)
    local copy = {}
    if actions then
        for i = 1, table.getn(actions) do -- Lua 5.0: no # operator
            table.insert(copy, DeepCopyAction(actions[i]))
        end
    end
    return copy
end

-- ============================================================================
-- Initialize
-- ============================================================================
function EreaRpMasterActionEditorFrame:Initialize()
    local self = EreaRpMasterActionEditorFrame

    -- Store frame references
    self.titleBar = EreaRpMasterActionEditorFrameTitleBar
    self.closeButton = EreaRpMasterActionEditorFrameCloseButton
    self.noSelectionHint = EreaRpMasterActionEditorFrameNoSelectionHint

    -- Left panel
    self.actionListScroll = EreaRpMasterActionEditorFrameActionListScroll
    self.actionListScrollChild = EreaRpMasterActionEditorFrameActionListScrollChild
    self.actionListSlider = EreaRpMasterActionEditorFrameActionListSlider
    self.addActionButton = EreaRpMasterActionEditorFrameAddActionButton
    self.removeActionButton = EreaRpMasterActionEditorFrameRemoveActionButton

    -- Right panel
    self.labelEdit = EreaRpMasterActionEditorFrameLabelEdit
    self.customTextCheck = EreaRpMasterActionEditorFrameCustomTextCheck
    self.counterCheck = EreaRpMasterActionEditorFrameCounterCheck
    self.methodsScroll = EreaRpMasterActionEditorFrameMethodsScroll
    self.methodsScrollChild = EreaRpMasterActionEditorFrameMethodsScrollChild
    self.methodsSlider = EreaRpMasterActionEditorFrameMethodsSlider
    self.addMethodButton = EreaRpMasterActionEditorFrameAddMethodButton

    -- Bottom buttons
    self.saveButton = EreaRpMasterActionEditorFrameSaveButton
    self.cancelButton = EreaRpMasterActionEditorFrameCancelButton

    -- Send Status checkbox
    self.sendStatusCheck = EreaRpMasterActionEditorFrameSendStatusCheck
    self.sendStatusLabel = EreaRpMasterActionEditorFrameSendStatusLabel

    -- Right panel label refs for show/hide
    self.labelLabel = EreaRpMasterActionEditorFrameLabelLabel
    self.conditionsLabel = EreaRpMasterActionEditorFrameConditionsLabel
    self.customTextLabel = EreaRpMasterActionEditorFrameCustomTextLabel
    self.counterLabel = EreaRpMasterActionEditorFrameCounterLabel
    self.methodsLabel = EreaRpMasterActionEditorFrameMethodsLabel

    -- State
    self.actions = {}           -- Working copy of all actions
    self.selectedIndex = nil    -- Currently selected action index
    self.onSaveCallback = nil
    self.methodFrames = {}      -- Dynamic method UI frames
    self.actionRowButtons = {}  -- Action list row buttons

    -- Resize button
    self.resizeButton = EreaRpMasterActionEditorFrameResizeButton
    self.resizeButton:SetFrameStrata("DIALOG")
    self.resizeButton:SetFrameLevel(self:GetFrameLevel() + 10)
    self.resizeButton:SetScript("OnMouseDown", function()
        EreaRpMasterActionEditorFrame:StartSizing("BOTTOMRIGHT")
    end)
    self.resizeButton:SetScript("OnMouseUp", function()
        EreaRpMasterActionEditorFrame:StopMovingOrSizing()
    end)

    -- Handle resize: update right panel widths
    self:SetScript("OnSizeChanged", function()
        EreaRpMasterActionEditorFrame:OnFrameResized()
    end)

    -- Dragging
    self.titleBar:SetScript("OnMouseDown", function()
        EreaRpMasterActionEditorFrame:StartMoving()
    end)
    self.titleBar:SetScript("OnMouseUp", function()
        EreaRpMasterActionEditorFrame:StopMovingOrSizing()
    end)

    -- Close button
    self.closeButton:SetScript("OnClick", function()
        EreaRpMasterActionEditorFrame:Close()
    end)

    -- Cancel button
    self.cancelButton:SetScript("OnClick", function()
        EreaRpMasterActionEditorFrame:Close()
    end)

    -- Save button
    self.saveButton:SetScript("OnClick", function()
        EreaRpMasterActionEditorFrame:Save()
    end)

    -- Add action button
    self.addActionButton:SetScript("OnClick", function()
        EreaRpMasterActionEditorFrame:AddAction()
    end)

    -- Remove action button
    self.removeActionButton:SetScript("OnClick", function()
        EreaRpMasterActionEditorFrame:RemoveAction()
    end)

    -- Add method button
    self.addMethodButton:SetScript("OnClick", function()
        EreaRpMasterActionEditorFrame:AddMethod()
    end)

    -- Setup scrolling for both scroll frames
    self:SetupActionListScrolling()
    self:SetupMethodsScrolling()
end

-- ============================================================================
-- OnFrameResized - Update right panel widths when frame is resized
-- ============================================================================
function EreaRpMasterActionEditorFrame:OnFrameResized()
    local self = EreaRpMasterActionEditorFrame

    -- Update methods scroll child width (frame width - left panel - margins)
    local frameWidth = self:GetWidth()
    local scrollChildWidth = frameWidth - 280

    if self.methodsScrollChild then
        self.methodsScrollChild:SetWidth(scrollChildWidth)
    end

    -- Update existing method frame widths
    if not self.methodFrames then return end
    for i = 1, table.getn(self.methodFrames) do -- Lua 5.0: no # operator
        local methodFrame = self.methodFrames[i]
        if methodFrame then
            methodFrame:SetWidth(scrollChildWidth - 10)
        end
    end

    -- Update scroll range
    if self.methodsScroll then
        self.methodsScroll:UpdateScrollChildRect()
        local viewHeight = self.methodsScroll:GetHeight() or 0
        local contentHeight = self.methodsScrollChild:GetHeight() or 0
        local maxScroll = contentHeight - viewHeight
        if maxScroll < 0 then maxScroll = 0 end
        self.methodsSlider:SetMinMaxValues(0, maxScroll)
    end
end

-- ============================================================================
-- SetupActionListScrolling
-- ============================================================================
function EreaRpMasterActionEditorFrame:SetupActionListScrolling()
    local self = EreaRpMasterActionEditorFrame
    if not self.actionListScroll or not self.actionListSlider then return end

    self.actionListScroll:EnableMouseWheel(true)
    self.actionListScroll:SetScrollChild(self.actionListScrollChild)

    self.actionListSlider:SetMinMaxValues(0, 1)
    self.actionListSlider:SetValueStep(1)

    -- Lua 5.0: event params are globals
    -- Set OnValueChanged BEFORE SetValue so the template default is overridden
    self.actionListSlider:SetScript("OnValueChanged", function()
        EreaRpMasterActionEditorFrame.actionListScroll:SetVerticalScroll(arg1)
    end)
    self.actionListSlider:SetValue(0)

    self.actionListScroll:SetScript("OnMouseWheel", function()
        local current = EreaRpMasterActionEditorFrame.actionListSlider:GetValue()
        local minVal, maxVal = EreaRpMasterActionEditorFrame.actionListSlider:GetMinMaxValues()
        if arg1 > 0 then
            EreaRpMasterActionEditorFrame.actionListSlider:SetValue(math.max(minVal, current - 20))
        else
            EreaRpMasterActionEditorFrame.actionListSlider:SetValue(math.min(maxVal, current + 20))
        end
    end)
end

-- ============================================================================
-- SetupMethodsScrolling
-- ============================================================================
function EreaRpMasterActionEditorFrame:SetupMethodsScrolling()
    local self = EreaRpMasterActionEditorFrame
    if not self.methodsScroll or not self.methodsSlider then return end

    self.methodsScroll:EnableMouseWheel(true)
    self.methodsScroll:SetScrollChild(self.methodsScrollChild)

    self.methodsSlider:SetMinMaxValues(0, 1)
    self.methodsSlider:SetValueStep(1)

    -- Lua 5.0: event params are globals
    -- Set OnValueChanged BEFORE SetValue so the template default is overridden
    self.methodsSlider:SetScript("OnValueChanged", function()
        EreaRpMasterActionEditorFrame.methodsScroll:SetVerticalScroll(arg1)
    end)
    self.methodsSlider:SetValue(0)

    self.methodsScroll:SetScript("OnVerticalScroll", function()
        EreaRpMasterActionEditorFrame.methodsSlider:SetValue(arg1)
    end)

    self.methodsScroll:SetScript("OnMouseWheel", function()
        local current = EreaRpMasterActionEditorFrame.methodsSlider:GetValue()
        local minVal, maxVal = EreaRpMasterActionEditorFrame.methodsSlider:GetMinMaxValues()
        if arg1 > 0 then
            EreaRpMasterActionEditorFrame.methodsSlider:SetValue(math.max(minVal, current - 20))
        else
            EreaRpMasterActionEditorFrame.methodsSlider:SetValue(math.min(maxVal, current + 20))
        end
    end)
end

-- ============================================================================
-- Open - Show editor with actions array and callback
-- ============================================================================
-- @param actions: Array of action tables (deep-copied internally)
-- @param onSaveCallback: function(actions) called on Save
-- ============================================================================
function EreaRpMasterActionEditorFrame:Open(actions, onSaveCallback)
    local self = EreaRpMasterActionEditorFrame

    self.actions = DeepCopyActions(actions or {})
    self.onSaveCallback = onSaveCallback
    self.selectedIndex = nil

    self:RefreshActionList()
    self:ShowDetailPanel(false)

    -- Auto-select first action if any exist
    if table.getn(self.actions) > 0 then -- Lua 5.0: no # operator
        self:SelectAction(1)
    end

    self:Show()
    self:Raise()
end

-- ============================================================================
-- Close - Hide and clear state
-- ============================================================================
function EreaRpMasterActionEditorFrame:Close()
    local self = EreaRpMasterActionEditorFrame

    self:Hide()
    self.actions = {}
    self.selectedIndex = nil
    self.onSaveCallback = nil
end

-- ============================================================================
-- Save - Validate all actions and invoke callback
-- ============================================================================
function EreaRpMasterActionEditorFrame:Save()
    local self = EreaRpMasterActionEditorFrame

    -- Save currently selected action's UI state first
    self:SaveCurrentAction()

    -- Validate all actions
    for i = 1, table.getn(self.actions) do -- Lua 5.0: no # operator
        local action = self.actions[i]
        local valid, errorMsg = rpActions.ValidateAction(action)
        if not valid then
            return
        end
    end

    -- Call callback with modified actions
    if self.onSaveCallback then
        self.onSaveCallback(self.actions)
    end

    self:Close()
end

-- ============================================================================
-- ShowDetailPanel - Toggle visibility of right panel elements
-- ============================================================================
function EreaRpMasterActionEditorFrame:ShowDetailPanel(visible)
    local self = EreaRpMasterActionEditorFrame

    local method = visible and "Show" or "Hide"

    self.labelEdit[method](self.labelEdit)
    self.customTextCheck[method](self.customTextCheck)
    self.counterCheck[method](self.counterCheck)
    self.sendStatusCheck[method](self.sendStatusCheck)
    self.methodsScroll[method](self.methodsScroll)
    self.methodsSlider[method](self.methodsSlider)
    self.addMethodButton[method](self.addMethodButton)

    -- Labels
    if self.labelLabel then self.labelLabel[method](self.labelLabel) end
    if self.conditionsLabel then self.conditionsLabel[method](self.conditionsLabel) end
    if self.customTextLabel then self.customTextLabel[method](self.customTextLabel) end
    if self.counterLabel then self.counterLabel[method](self.counterLabel) end
    if self.sendStatusLabel then self.sendStatusLabel[method](self.sendStatusLabel) end
    if self.methodsLabel then self.methodsLabel[method](self.methodsLabel) end

    -- Hint text
    if self.noSelectionHint then
        if visible then
            self.noSelectionHint:Hide()
        else
            self.noSelectionHint:Show()
        end
    end

    -- Remove button enable state
    if self.removeActionButton then
        if visible then
            self.removeActionButton:Enable()
        else
            self.removeActionButton:Disable()
        end
    end
end

-- ============================================================================
-- RefreshActionList - Rebuild action row buttons in left panel
-- ============================================================================
function EreaRpMasterActionEditorFrame:RefreshActionList()
    local self = EreaRpMasterActionEditorFrame

    -- Hide and clear existing row buttons
    for i = 1, table.getn(self.actionRowButtons) do -- Lua 5.0: no # operator
        self.actionRowButtons[i]:Hide()
    end
    self.actionRowButtons = {}

    -- Create a button for each action using the virtual template
    local yOffset = -5
    for i = 1, table.getn(self.actions) do -- Lua 5.0: no # operator
        local action = self.actions[i]
        actionRowCounter = actionRowCounter + 1
        local btnName = "EreaRpMasterActionRow" .. actionRowCounter
        local btn = CreateFrame("Button", btnName, self.actionListScrollChild, "EreaRpMasterActionRowTemplate")
        btn:SetPoint("TOPLEFT", 3, yOffset)

        -- Get template child references
        local highlight = _G[btnName .. "Highlight"]
        local selected = _G[btnName .. "Selected"]
        local labelText = _G[btnName .. "Label"]

        -- Set label text
        labelText:SetText(action.label or "(unnamed)")
        btn.labelText = labelText

        -- Click handler
        do
            local idx = i
            btn:SetScript("OnClick", function()
                EreaRpMasterActionEditorFrame:SelectAction(idx)
            end)
        end

        -- Mark as selected if current
        if self.selectedIndex == i then
            btn.isSelected = true
            selected:Show()
        end

        table.insert(self.actionRowButtons, btn)
        yOffset = yOffset - 22
    end

    -- Update scroll child height
    local totalHeight = math.abs(yOffset) + 10
    self.actionListScrollChild:SetHeight(math.max(totalHeight, self.actionListScroll:GetHeight()))

    -- Update scroll range
    self.actionListScroll:UpdateScrollChildRect()
    local viewHeight = self.actionListScroll:GetHeight() or 0
    local contentHeight = self.actionListScrollChild:GetHeight() or 0
    local maxScroll = contentHeight - viewHeight
    if maxScroll < 0 then maxScroll = 0 end
    self.actionListSlider:SetMinMaxValues(0, maxScroll)
end

-- ============================================================================
-- SelectAction - Select action by index, populate right panel
-- ============================================================================
function EreaRpMasterActionEditorFrame:SelectAction(index)
    local self = EreaRpMasterActionEditorFrame

    -- Save previous action's state before switching
    self:SaveCurrentAction()

    self.selectedIndex = index
    local action = self.actions[index]

    if not action then
        self:ShowDetailPanel(false)
        self:RefreshActionList()
        return
    end

    -- Show detail panel
    self:ShowDetailPanel(true)

    -- Populate fields
    self.labelEdit:SetText(action.label or "")
    self.customTextCheck:SetChecked(action.conditions and action.conditions.customTextEmpty or false)
    self.counterCheck:SetChecked(action.conditions and action.conditions.counterGreaterThanZero or false)
    self.sendStatusCheck:SetChecked(action.sendStatus or false)

    -- Refresh methods list
    self:RefreshMethodsList()

    -- Update selection highlight in list
    self:RefreshActionList()
end

-- ============================================================================
-- SaveCurrentAction - Extract UI state back to the selected action
-- ============================================================================
function EreaRpMasterActionEditorFrame:SaveCurrentAction()
    local self = EreaRpMasterActionEditorFrame

    if not self.selectedIndex then return end
    local action = self.actions[self.selectedIndex]
    if not action then return end

    -- Save label
    action.label = self.labelEdit:GetText() or ""

    -- Generate or preserve ID
    if not action.id or action.id == "" then
        local id = string.lower(action.label)
        id = string.gsub(id, "%s+", "_")
        id = string.gsub(id, "[^%w_]", "")
        if id == "" then id = "action_" .. self.selectedIndex end
        action.id = id
    end

    -- Save conditions
    action.conditions = {
        customTextEmpty = self.customTextCheck:GetChecked() or false,
        counterGreaterThanZero = self.counterCheck:GetChecked() or false
    }

    -- Save send status flag
    action.sendStatus = self.sendStatusCheck:GetChecked() or false

    -- Extract method parameter values from editor frames
    for i = 1, table.getn(self.methodFrames) do -- Lua 5.0: no # operator
        local methodFrame = self.methodFrames[i]
        local method = action.methods[i]

        if methodFrame and method then
            -- Save to library if the editor supports it (cinematic, merge)
            if methodFrame.SaveToLibrary then
                methodFrame:SaveToLibrary()
            end
            -- Get params via standardized interface
            if methodFrame.GetParams then
                method.params = methodFrame:GetParams()
            end
        end
    end

    -- Update the row label in the list
    for i = 1, table.getn(self.actionRowButtons) do -- Lua 5.0: no # operator
        if i == self.selectedIndex and self.actionRowButtons[i].labelText then
            self.actionRowButtons[i].labelText:SetText(action.label ~= "" and action.label or "(unnamed)")
        end
    end
end

-- ============================================================================
-- AddAction - Add a new blank action and select it
-- ============================================================================
function EreaRpMasterActionEditorFrame:AddAction()
    local self = EreaRpMasterActionEditorFrame

    -- Save current action state first
    self:SaveCurrentAction()

    local newAction = {
        id = "",
        label = "New Action",
        sendStatus = false,
        methods = {},
        conditions = {
            customTextEmpty = false,
            counterGreaterThanZero = false
        }
    }

    table.insert(self.actions, newAction)
    local newIndex = table.getn(self.actions) -- Lua 5.0: no # operator
    self:RefreshActionList()
    self:SelectAction(newIndex)
end

-- ============================================================================
-- RemoveAction - Remove currently selected action
-- ============================================================================
function EreaRpMasterActionEditorFrame:RemoveAction()
    local self = EreaRpMasterActionEditorFrame

    if not self.selectedIndex then return end

    table.remove(self.actions, self.selectedIndex)

    local count = table.getn(self.actions) -- Lua 5.0: no # operator
    if count == 0 then
        self.selectedIndex = nil
        self:ShowDetailPanel(false)
    elseif self.selectedIndex > count then
        self.selectedIndex = count
    end

    self:RefreshActionList()

    if self.selectedIndex then
        self:SelectAction(self.selectedIndex)
    end
end

-- ============================================================================
-- RefreshMethodsList - Rebuild dynamic method frames in right panel
-- ============================================================================
function EreaRpMasterActionEditorFrame:RefreshMethodsList()
    local self = EreaRpMasterActionEditorFrame

    -- Clear existing method frames
    for i = 1, table.getn(self.methodFrames) do -- Lua 5.0: no # operator
        if self.methodFrames[i] then
            self.methodFrames[i]:Hide()
            self.methodFrames[i]:SetParent(nil)
            self.methodFrames[i] = nil
        end
    end
    self.methodFrames = {}

    if not self.selectedIndex then return end
    local action = self.actions[self.selectedIndex]
    if not action or not action.methods then return end

    -- Create new method frames
    local yOffset = -5
    for i = 1, table.getn(action.methods) do -- Lua 5.0: no # operator
        local methodFrame = CreateMethodFrame(self.methodsScrollChild, action.methods, i)
        if methodFrame then
            methodFrame:SetPoint("TOPLEFT", 5, yOffset)
            yOffset = yOffset - methodFrame:GetHeight() - 5
            table.insert(self.methodFrames, methodFrame)
        end
    end

    -- Update scroll child height
    local totalHeight = math.abs(yOffset) + 100
    self.methodsScrollChild:SetHeight(math.max(totalHeight, self.methodsScroll:GetHeight()))

    -- Update scroll range
    self.methodsScroll:UpdateScrollChildRect()
    local viewHeight = self.methodsScroll:GetHeight() or 0
    local contentHeight = self.methodsScrollChild:GetHeight() or 0
    local maxScroll = contentHeight - viewHeight
    if maxScroll < 0 then maxScroll = 0 end
    self.methodsSlider:SetMinMaxValues(0, maxScroll)
end

-- ============================================================================
-- AddMethod - Show dropdown of available methods, add selected
-- ============================================================================
function EreaRpMasterActionEditorFrame:AddMethod()
    local self = EreaRpMasterActionEditorFrame

    if not self.selectedIndex then return end

    local availableMethods = rpActions.GetAvailableMethods()
    local menuFrame = CreateFrame("Frame", "EreaRpMasterActionEditorMethodMenu", UIParent, "UIDropDownMenuTemplate")

    local function MenuInit()
        for i = 1, table.getn(availableMethods) do -- Lua 5.0: no # operator
            local methodInfo = availableMethods[i]
            local info = {}
            info.text = methodInfo.name
            info.tooltipTitle = methodInfo.name
            info.tooltipText = methodInfo.description
            info.notCheckable = true
            do
                local methodType = methodInfo.type
                info.func = function()
                    -- Save current state before modifying
                    EreaRpMasterActionEditorFrame:SaveCurrentAction()
                    local action = EreaRpMasterActionEditorFrame.actions[EreaRpMasterActionEditorFrame.selectedIndex]
                    if action then
                        table.insert(action.methods, {
                            type = methodType,
                            params = {}
                        })
                        EreaRpMasterActionEditorFrame:RefreshMethodsList()
                    end
                end
            end
            UIDropDownMenu_AddButton(info)
        end
    end

    UIDropDownMenu_Initialize(menuFrame, MenuInit)
    ToggleDropDownMenu(1, nil, menuFrame, "cursor", 0, 0)
end

-- ============================================================================
-- RemoveMethod - Remove method by index from selected action
-- ============================================================================
function EreaRpMasterActionEditorFrame:RemoveMethod(methodIndex)
    local self = EreaRpMasterActionEditorFrame

    if not self.selectedIndex then return end

    -- Save current param values before removing
    self:SaveCurrentAction()

    local action = self.actions[self.selectedIndex]
    if action and action.methods then
        table.remove(action.methods, methodIndex)
        self:RefreshMethodsList()
    end
end

-- ============================================================================
-- MoveMethodUp - Move method at index up by one position
-- ============================================================================
function EreaRpMasterActionEditorFrame:MoveMethodUp(methodIndex)
    local self = EreaRpMasterActionEditorFrame
    if not self.selectedIndex then return end
    if methodIndex <= 1 then return end

    self:SaveCurrentAction()

    local action = self.actions[self.selectedIndex]
    if action and action.methods and methodIndex <= table.getn(action.methods) then -- Lua 5.0: no # operator
        local tmp = action.methods[methodIndex - 1]
        action.methods[methodIndex - 1] = action.methods[methodIndex]
        action.methods[methodIndex] = tmp
        self:RefreshMethodsList()
    end
end

-- ============================================================================
-- MoveMethodDown - Move method at index down by one position
-- ============================================================================
function EreaRpMasterActionEditorFrame:MoveMethodDown(methodIndex)
    local self = EreaRpMasterActionEditorFrame
    if not self.selectedIndex then return end

    self:SaveCurrentAction()

    local action = self.actions[self.selectedIndex]
    if action and action.methods then
        local n = table.getn(action.methods) -- Lua 5.0: no # operator
        if methodIndex >= n then return end
        local tmp = action.methods[methodIndex + 1]
        action.methods[methodIndex + 1] = action.methods[methodIndex]
        action.methods[methodIndex] = tmp
        self:RefreshMethodsList()
    end
end
