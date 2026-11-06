-- ============================================================================
-- icon-picker.lua - EreaRpMasterIconPickerFrame Controller
-- ============================================================================
-- UI Structure: views/icon-picker.xml
-- Frame: EreaRpMasterIconPickerFrame (defined in XML)
--
-- PURPOSE: FauxScrollFrame-based icon grid picker. Creates a fixed pool of
--          icon buttons and pages through the filtered icon list on scroll.
--
-- METHODS:
--   EreaRpMasterIconPickerFrame:Initialize()              - Create button pool
--   EreaRpMasterIconPickerFrame:Open(currentIcon, cb)     - Show picker
--   EreaRpMasterIconPickerFrame:FilterIcons()             - Apply text filter
--   EreaRpMasterIconPickerFrame:UpdateGrid()              - Refresh visible buttons
--   EreaRpMasterIconPickerFrame:ResetPositions()          - Reset window position to default
--
-- DEPENDENCIES:
--   - EreaRpMaster_GetIconList() (data/icon-list.lua)
--   - FauxScrollFrame API (Blizzard built-in)
-- ============================================================================

-- ============================================================================
-- Constants
-- ============================================================================
local ICONS_PER_ROW = 7
local ICON_SIZE = 40
local ICON_SPACING = 10
local NUM_ICON_ROWS = 10
local NUM_ICON_BUTTONS = ICONS_PER_ROW * NUM_ICON_ROWS  -- 70
local ICON_ROW_HEIGHT = ICON_SIZE + ICON_SPACING         -- 50

-- ============================================================================
-- Initialize
-- ============================================================================
function EreaRpMasterIconPickerFrame:Initialize()
    local self = EreaRpMasterIconPickerFrame

    -- Store refs
    self.titleBar = EreaRpMasterIconPickerFrameTitleBar
    self.closeButton = EreaRpMasterIconPickerFrameCloseButton
    self.filterEditBox = EreaRpMasterIconPickerFrameFilterEditBox
    self.scrollFrame = EreaRpMasterIconPickerScrollFrame
    self.wowheadEditBox = EreaRpMasterIconPickerFrameWoWHeadEditBox
    self.wowheadPreview = EreaRpMasterIconPickerFrameWoWHeadPreview
    self.wowheadUseButton = EreaRpMasterIconPickerFrameWoWHeadUseButton

    -- State
    self.filteredIcons = {}
    self.onSelectCallback = nil
    self.iconButtons = {}

    -- Dragging
    self.titleBar:SetScript("OnMouseDown", function()
        EreaRpMasterIconPickerFrame:StartMoving()
    end)
    self.titleBar:SetScript("OnMouseUp", function()
        EreaRpMasterIconPickerFrame:StopMovingOrSizing()
    end)

    -- Close button
    self.closeButton:SetScript("OnClick", function()
        EreaRpMasterIconPickerFrame:Hide()
    end)

    -- Filter EditBox → filter on text change
    self.filterEditBox:SetScript("OnTextChanged", function()
        EreaRpMasterIconPickerFrame:FilterIcons()
        EreaRpMasterIconPickerFrame:UpdateGrid()
    end)

    -- Scroll frame → update grid on scroll
    self.scrollFrame:SetScript("OnVerticalScroll", function()
        -- Lua 5.0: scroll offset is in global arg1
        FauxScrollFrame_OnVerticalScroll(ICON_ROW_HEIGHT, function()
            EreaRpMasterIconPickerFrame:UpdateGrid()
        end)
    end)

    -- WoWHead preview: slot background + icon texture
    local wowheadBg = self.wowheadPreview:CreateTexture(
        "EreaRpMasterIconPickerFrameWoWHeadPreviewBg", "BACKGROUND")
    wowheadBg:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    wowheadBg:SetWidth(46)
    wowheadBg:SetHeight(46)
    wowheadBg:SetPoint("CENTER", self.wowheadPreview, "CENTER", 0, 0)
    local wowheadTex = self.wowheadPreview:CreateTexture(
        "EreaRpMasterIconPickerFrameWoWHeadPreviewIcon", "ARTWORK")
    wowheadTex:SetWidth(36)
    wowheadTex:SetHeight(36)
    wowheadTex:SetPoint("CENTER", self.wowheadPreview, "CENTER", 0, 0)
    self.wowheadPreview.iconTexture = wowheadTex

    -- WoWHead EditBox: tooltip
    self.wowheadEditBox:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText("Paste an icon name from wowhead.com/classic/icons\n(e.g. ability_impalingbolt)", 1, 1, 1)
        GameTooltip:Show()
    end)
    self.wowheadEditBox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- WoWHead EditBox: live preview on text change
    self.wowheadEditBox:SetScript("OnTextChanged", function()
        local text = string.gsub(this:GetText(), "^%s*(.-)%s*$", "%1")  -- trim
        if text ~= "" then
            local previewPath = "Interface\\Icons\\" .. text
            -- Clear first: SetTexture silently fails on invalid paths, leaving the old icon
            EreaRpMasterIconPickerFrame.wowheadPreview.iconTexture:SetTexture("")
            EreaRpMasterIconPickerFrame.wowheadPreview.iconTexture:SetTexture(previewPath)
            EreaRpMasterIconPickerFrame.wowheadPreview:Show()
        else
            EreaRpMasterIconPickerFrame.wowheadPreview:Hide()
        end
    end)

    -- WoWHead Use button: select icon by name
    self.wowheadUseButton:SetScript("OnClick", function()
        local text = string.gsub(
            EreaRpMasterIconPickerFrameWoWHeadEditBox:GetText(),
            "^%s*(.-)%s*$", "%1")
        if text == "" then return end

        -- Try case-insensitive lookup in icon list for canonical path
        local iconPath = nil
        local lower = string.lower(text)
        local allIcons = EreaRpMaster_GetIconList()
        for i = 1, table.getn(allIcons) do  -- Lua 5.0: no # operator
            local entry = allIcons[i]
            local lastSlash = string.find(entry, "\\[^\\]*$")
            local filename = lastSlash and string.sub(entry, lastSlash + 1) or entry
            if string.lower(filename) == lower then
                iconPath = entry  -- use canonical casing from list
                break
            end
        end

        -- Fall back to inferred path (MPQ is case-insensitive on WoW)
        if not iconPath then
            iconPath = "Interface\\Icons\\" .. text
        end

        if EreaRpMasterIconPickerFrame.onSelectCallback then
            EreaRpMasterIconPickerFrame.onSelectCallback(iconPath)
        end
        EreaRpMasterIconPickerFrame:Hide()
    end)

    -- Create fixed pool of icon buttons
    for i = 1, NUM_ICON_BUTTONS do
        local row = math.floor((i - 1) / ICONS_PER_ROW)
        local col = math.mod((i - 1), ICONS_PER_ROW)  -- Lua 5.0: no % operator

        local btnName = "EreaRpMasterIconPickerBtn" .. i
        local btn = CreateFrame("Button", btnName, self)
        btn:SetWidth(ICON_SIZE)
        btn:SetHeight(ICON_SIZE)
        btn:SetPoint("TOPLEFT", self.scrollFrame, "TOPLEFT",
            col * (ICON_SIZE + ICON_SPACING),
            -(row * (ICON_SIZE + ICON_SPACING)))
        btn:EnableMouse(true)

        -- Slot background
        local slotBg = btn:CreateTexture(btnName .. "SlotBg", "BACKGROUND")
        slotBg:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        slotBg:SetWidth(56)
        slotBg:SetHeight(56)
        slotBg:SetPoint("CENTER", btn, "CENTER", 0, 0)

        -- Icon texture
        local iconTex = btn:CreateTexture(btnName .. "Icon", "ARTWORK")
        iconTex:SetWidth(36)
        iconTex:SetHeight(36)
        iconTex:SetPoint("CENTER", btn, "CENTER", 0, 0)
        btn.iconTexture = iconTex

        -- Highlight
        local highlight = btn:CreateTexture(btnName .. "Highlight", "HIGHLIGHT")
        highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        highlight:SetBlendMode("ADD")
        highlight:SetAllPoints(btn)

        -- Store icon path on button for handlers
        btn.iconPath = nil

        -- OnClick
        btn:SetScript("OnClick", function()
            local path = this.iconPath
            if path and EreaRpMasterIconPickerFrame.onSelectCallback then
                EreaRpMasterIconPickerFrame.onSelectCallback(path)
            end
            EreaRpMasterIconPickerFrame:Hide()
        end)

        -- OnEnter → tooltip
        btn:SetScript("OnEnter", function()
            if this.iconPath then
                GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
                -- Extract filename, replace underscores with spaces
                local filename = this.iconPath
                local lastSlash = string.find(filename, "\\[^\\]*$")
                if lastSlash then
                    filename = string.sub(filename, lastSlash + 1)
                end
                filename = string.gsub(filename, "_", " ")
                GameTooltip:SetText(filename, 1, 1, 1)
                GameTooltip:Show()
            end
        end)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        btn:Hide()
        self.iconButtons[i] = btn
    end
end

-- ============================================================================
-- Open - Show picker with current icon and callback
-- ============================================================================
function EreaRpMasterIconPickerFrame:Open(currentIcon, onSelectCallback)
    local self = EreaRpMasterIconPickerFrame

    self.onSelectCallback = onSelectCallback
    self.filterEditBox:SetText("")
    self.wowheadEditBox:SetText("")
    self.wowheadPreview:Hide()
    self:FilterIcons()
    self:UpdateGrid()
    self:Show()
    self:Raise()
end

-- ============================================================================
-- Reset Positions
-- ============================================================================
-- Reset icon picker window position to default (center screen)
function EreaRpMasterIconPickerFrame:ResetPositions()
    -- Reset icon picker window position
    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end

-- ============================================================================
-- FilterIcons - Build filtered list from icon data
-- ============================================================================
function EreaRpMasterIconPickerFrame:FilterIcons()
    local self = EreaRpMasterIconPickerFrame

    local allIcons = EreaRpMaster_GetIconList()
    local filterText = string.lower(self.filterEditBox:GetText() or "")
    self.filteredIcons = {}

    if filterText == "" then
        -- No filter — show all
        for i = 1, table.getn(allIcons) do  -- Lua 5.0: no # operator
            table.insert(self.filteredIcons, allIcons[i])
        end
    else
        for i = 1, table.getn(allIcons) do  -- Lua 5.0: no # operator
            local iconPath = allIcons[i]
            -- Extract filename after last backslash
            local filename = iconPath
            local lastSlash = string.find(iconPath, "\\[^\\]*$")
            if lastSlash then
                filename = string.sub(iconPath, lastSlash + 1)
            end
            -- Case-insensitive substring match
            if string.find(string.lower(filename), filterText, 1, true) then
                table.insert(self.filteredIcons, iconPath)
            end
        end
    end
end

-- ============================================================================
-- UpdateGrid - Refresh visible buttons based on scroll offset
-- ============================================================================
function EreaRpMasterIconPickerFrame:UpdateGrid()
    local self = EreaRpMasterIconPickerFrame

    local totalIcons = table.getn(self.filteredIcons)  -- Lua 5.0: no # operator
    local totalRows = math.ceil(totalIcons / ICONS_PER_ROW)
    if totalRows < 1 then totalRows = 1 end

    FauxScrollFrame_Update(self.scrollFrame, totalRows, NUM_ICON_ROWS, ICON_ROW_HEIGHT)

    local offset = FauxScrollFrame_GetOffset(self.scrollFrame)

    for i = 1, NUM_ICON_BUTTONS do
        local btn = self.iconButtons[i]
        local row = math.floor((i - 1) / ICONS_PER_ROW)
        local col = math.mod((i - 1), ICONS_PER_ROW)  -- Lua 5.0: no % operator
        local iconIndex = (offset + row) * ICONS_PER_ROW + col + 1

        if iconIndex <= totalIcons then
            local iconPath = self.filteredIcons[iconIndex]
            btn.iconPath = iconPath
            btn.iconTexture:SetTexture(iconPath)
            btn:Show()
        else
            btn.iconPath = nil
            btn:Hide()
        end
    end
end
