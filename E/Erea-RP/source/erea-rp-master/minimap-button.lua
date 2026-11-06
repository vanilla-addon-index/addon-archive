-- ============================================================================
-- minimap-button.lua - Minimap button for RPMaster
-- ============================================================================
-- PURPOSE: Provides a minimap button to quickly open the RPMaster interface
--
-- FEATURES:
--   - Draggable around the minimap edge
--   - Left-click to toggle RPMaster window
--   - Tooltip with addon info
--   - Position persistence
-- ============================================================================

-- ============================================================================
-- CONSTANTS
-- ============================================================================
local BUTTON_SIZE = 32
local BUTTON_RADIUS = 80

-- ============================================================================
-- CREATE MINIMAP BUTTON FRAME
-- ============================================================================
local minimapButton = CreateFrame("Button", "EreaRpMasterMinimapButton", Minimap)
minimapButton:SetWidth(BUTTON_SIZE)
minimapButton:SetHeight(BUTTON_SIZE)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetMovable(true)
minimapButton:EnableMouse(true)
minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
minimapButton:RegisterForDrag("LeftButton")

-- Button background texture
local bg = minimapButton:CreateTexture(nil, "BACKGROUND")
bg:SetWidth(BUTTON_SIZE)
bg:SetHeight(BUTTON_SIZE)
bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
bg:SetPoint("CENTER", minimapButton, "CENTER", 0, 0)

-- Button icon texture
local icon = minimapButton:CreateTexture(nil, "ARTWORK")
icon:SetWidth(20)
icon:SetHeight(20)
icon:SetTexture("Interface\\Icons\\INV_Misc_Note_02")
icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)  -- Crop edges for cleaner look
icon:SetPoint("CENTER", minimapButton, "CENTER", 0, 0)

-- Border overlay
local border = minimapButton:CreateTexture(nil, "OVERLAY")
border:SetWidth(52)
border:SetHeight(52)
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetPoint("TOPLEFT", minimapButton, "TOPLEFT", 0, 0)

-- ============================================================================
-- UpdatePosition() - Position button around minimap edge
-- ============================================================================
local function UpdatePosition(angle)
    local x = math.cos(angle) * BUTTON_RADIUS
    local y = math.sin(angle) * BUTTON_RADIUS
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

-- Tooltip
minimapButton:SetScript("OnEnter", function()
    GameTooltip:SetOwner(minimapButton, "ANCHOR_LEFT")
    GameTooltip:SetText("RP Master", 1, 1, 1)
    GameTooltip:AddLine("Game Master RP Item Tool", 0.8, 0.8, 0.8)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Left-click: Open/Close", 0, 1, 0)
    GameTooltip:AddLine("Drag: Move button", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end)

minimapButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- Click handler
minimapButton:SetScript("OnClick", function()
    local button = arg1 or "LeftButton"
    
    if button == "LeftButton" then
        if EreaRpMaster_ToggleMainFrame then
            EreaRpMaster_ToggleMainFrame()
        end
    elseif button == "RightButton" then
        -- Show dropdown menu on right-click
        local menu = CreateFrame("Frame", "EreaRpMasterMenu", UIParent, "UIDropDownMenuTemplate")
        
        -- Initialize menu
        UIDropDownMenu_Initialize(menu, function()
            -- Reset Positions option
            UIDropDownMenu_AddButton({
                text = "Reset Positions",
                func = function()
                    -- Reset all RP Master frames
                    if EreaRpMasterMainWindow and EreaRpMasterMainWindow.ResetPositions then
                        EreaRpMasterMainWindow:ResetPositions()
                    end
                    if EreaRpMasterIconPickerFrame and EreaRpMasterIconPickerFrame.ResetPositions then
                        EreaRpMasterIconPickerFrame:ResetPositions()
                    end
                    if EreaRpMasterItemEditorFrame and EreaRpMasterItemEditorFrame.ResetPositions then
                        EreaRpMasterItemEditorFrame:ResetPositions()
                    end
                end
            })
        end, "MENU")
        
        -- Show menu at cursor position
        ToggleDropDownMenu(1, nil, menu, "cursor")
    end
end)

-- Drag handlers
minimapButton:SetScript("OnDragStart", function()
    minimapButton:LockHighlight()
    minimapButton.isDragging = true
end)

minimapButton:SetScript("OnDragStop", function()
    minimapButton:UnlockHighlight()
    minimapButton.isDragging = false

    -- Save position
    if EreaRpMasterDB and EreaRpMasterDB.preferences then
        if not EreaRpMasterDB.preferences.minimapButton then
            EreaRpMasterDB.preferences.minimapButton = {}
        end
        local x, y = minimapButton:GetCenter()
        local mmX, mmY = Minimap:GetCenter()
        local angle = math.atan2(y - mmY, x - mmX)
        EreaRpMasterDB.preferences.minimapButton.angle = angle
    end
end)

minimapButton:SetScript("OnUpdate", function()
    if minimapButton.isDragging then
        local mouseX, mouseY = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        mouseX = mouseX / scale
        mouseY = mouseY / scale

        local mmX, mmY = Minimap:GetCenter()
        local angle = math.atan2(mouseY - mmY, mouseX - mmX)
        UpdatePosition(angle)
    end
end)

-- ============================================================================
-- INITIALIZATION
-- ============================================================================
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    initFrame.timer = 0
    initFrame:SetScript("OnUpdate", function()
        initFrame.timer = initFrame.timer + arg1  -- Lua 5.0: elapsed time is arg1
        if initFrame.timer >= 1.0 then
            -- Ensure structure exists
            if EreaRpMasterDB and EreaRpMasterDB.preferences and not EreaRpMasterDB.preferences.minimapButton then
                EreaRpMasterDB.preferences.minimapButton = {
                    angle = math.rad(225)
                }
            end

            -- Load saved position or default
            local angle = math.rad(225)
            if EreaRpMasterDB and EreaRpMasterDB.preferences and EreaRpMasterDB.preferences.minimapButton then
                angle = EreaRpMasterDB.preferences.minimapButton.angle
            end

            UpdatePosition(angle)
            minimapButton:Show()

            initFrame:SetScript("OnUpdate", nil)
        end
    end)
    initFrame:UnregisterEvent("PLAYER_LOGIN")
end)
