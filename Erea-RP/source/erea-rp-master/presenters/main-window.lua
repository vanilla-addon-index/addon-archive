-- ============================================================================
-- main-window.lua - EreaRpMasterMainWindow Controller
-- ============================================================================
-- UI Structure: views/main-window.xml
-- Frame: EreaRpMasterMainWindow (defined in XML)
--
-- PURPOSE: Manages the main RP Master window behavior
--
-- METHODS:
--   EreaRpMasterMainWindow:Initialize() - Setup drag, resize, position
--   EreaRpMasterMainWindow:SavePosition() - Persist position to SavedVariables
--   EreaRpMasterMainWindow:LoadPosition() - Restore position from SavedVariables
--   EreaRpMasterMainWindow:SaveSize() - Persist size to SavedVariables
--   EreaRpMasterMainWindow:LoadSize() - Restore size from SavedVariables
--   EreaRpMasterMainWindow:ResetPositions() - Reset all window positions to default
-- ============================================================================

-- ============================================================================
-- Initialize Main Window
-- ============================================================================
function EreaRpMasterMainWindow:Initialize()
    -- Set title
    local title = EreaRpMasterMainWindowTitle
    title:SetText("RP Master - Game Master")

    -- Setup draggable title bar
    local titleBar = EreaRpMasterMainWindowTitleBar
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        EreaRpMasterMainWindow:StartMoving()
    end)
    titleBar:SetScript("OnDragStop", function()
        EreaRpMasterMainWindow:StopMovingOrSizing()
        EreaRpMasterMainWindow:SavePosition()
    end)

    -- Setup resize button
    local resizeBtn = EreaRpMasterMainWindowResizeButton
    resizeBtn:SetFrameStrata("HIGH")
    resizeBtn:SetFrameLevel(EreaRpMasterMainWindow:GetFrameLevel() + 100)
    resizeBtn:SetScript("OnMouseDown", function()
        EreaRpMasterMainWindow:StartSizing("BOTTOMRIGHT")
    end)
    resizeBtn:SetScript("OnMouseUp", function()
        EreaRpMasterMainWindow:StopMovingOrSizing()
        EreaRpMasterMainWindow:SavePosition()
        EreaRpMasterMainWindow:SaveSize()
    end)

    -- Track size changes
    EreaRpMasterMainWindow:SetScript("OnSizeChanged", function()
        EreaRpMasterMainWindow:SaveSize()
    end)

    -- Load saved position and size
    self:LoadPosition()
    self:LoadSize()
end

-- ============================================================================
-- Save Position
-- ============================================================================
function EreaRpMasterMainWindow:SavePosition()
    if not EreaRpMasterDB or not EreaRpMasterDB.preferences then return end
    local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()
    EreaRpMasterDB.preferences.windowPositions.main = { point, relativePoint, xOfs, yOfs }
end

-- ============================================================================
-- Load Position
-- ============================================================================
function EreaRpMasterMainWindow:LoadPosition()
    if not EreaRpMasterDB or not EreaRpMasterDB.preferences then return end
    local pos = EreaRpMasterDB.preferences.windowPositions.main
    if pos then
        self:ClearAllPoints()
        self:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    end
end

-- ============================================================================
-- Save Size
-- ============================================================================
function EreaRpMasterMainWindow:SaveSize()
    if not EreaRpMasterDB or not EreaRpMasterDB.preferences then return end
    EreaRpMasterDB.preferences.windowSize = { self:GetWidth(), self:GetHeight() }
end

-- ============================================================================
-- Load Size
-- ============================================================================
function EreaRpMasterMainWindow:LoadSize()
    if not EreaRpMasterDB or not EreaRpMasterDB.preferences then return end
    local size = EreaRpMasterDB.preferences.windowSize
    if size then
        self:SetWidth(size[1])
        self:SetHeight(size[2])
    end
end

-- ============================================================================
-- Reset Positions
-- ============================================================================
-- Reset all window positions to default (center screen)
function EreaRpMasterMainWindow:ResetPositions()
    -- Reset main window position
    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end

-- ============================================================================
-- Tab Switching
-- ============================================================================
EreaRpMaster_CurrentTab = nil

function EreaRpMaster_SwitchTab(tabName)
    -- Content frame names by tab (convention -- defined in future task XMLs)
    local frames = {
        items   = "EreaRpMasterItemListFrame",
        states  = "EreaRpMasterClueListFrame",
        monitor = "EreaRpMasterPlayerMonitorFrame",
        scripts = "EreaRpMasterScriptListFrame"
    }
    -- Tab button names (defined in main-window.xml)
    local buttons = {
        items   = "EreaRpMasterMainWindowTabBarTabItems",
        states  = "EreaRpMasterMainWindowTabBarTabStates",
        monitor = "EreaRpMasterMainWindowTabBarTabMonitor",
        scripts = "EreaRpMasterMainWindowTabBarTabScripts"
    }

    -- Show/hide content frames
    for name, frameName in pairs(frames) do
        local frame = _G[frameName]
        if frame then
            if name == tabName then frame:Show() else frame:Hide() end
        end
    end

    -- Highlight active tab button
    for name, btnName in pairs(buttons) do
        local btn = _G[btnName]
        if btn then
            if name == tabName then
                btn:SetBackdropColor(0.25, 0.25, 0.25, 1)
                btn:SetBackdropBorderColor(1, 0.82, 0, 1)
            else
                btn:SetBackdropColor(0.1, 0.1, 0.1, 1)
                btn:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
            end
        end
    end

    EreaRpMaster_CurrentTab = tabName
    if EreaRpMasterDB and EreaRpMasterDB.preferences then
        EreaRpMasterDB.preferences.activeTab = tabName
    end
end
