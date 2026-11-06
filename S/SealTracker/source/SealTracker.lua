--[[
    Seal Tracker for Turtle WoW (1.12.1)
    Displays your current Paladin seal with a countdown timer.
    Features: Draggable, Resizable, Lockable
    
    Slash Commands:
        /sealtracker or /st - Show commands
        /st lock - Toggle frame lock
        /st reset - Reset position to center
        /st scale <number> - Set scale (0.5 to 2.0)
        /st show - Force show the frame
]]

-- ============================================================================
-- SAVED VARIABLES & DEFAULTS
-- ============================================================================

-- SealTrackerDB is loaded from SavedVariables - only initialize if nil
if not SealTrackerDB then
    SealTrackerDB = {}
end

local defaults = {
    locked = false,
    scale = 1.0,
    posX = 0,
    posY = 0,
    showTimer = true,
    showName = false,
    frameWidth = 64,
    frameHeight = 64,
}

-- ============================================================================
-- SEAL DATA (Vanilla 1.12 + Turtle WoW customs)
-- ============================================================================

local SEALS = {
    -- Standard Vanilla Seals (all 30 second duration)
    ["Seal of Righteousness"] = { duration = 30, texture = "Interface\\Icons\\Ability_ThunderBolt" },
    ["Seal of the Crusader"] = { duration = 30, texture = "Interface\\Icons\\Spell_Holy_HolySmite" },
    ["Seal of Command"] = { duration = 30, texture = "Interface\\Icons\\Ability_Warrior_InnerRage" },
    ["Seal of Justice"] = { duration = 30, texture = "Interface\\Icons\\Spell_Holy_SealOfWrath" },
    ["Seal of Light"] = { duration = 30, texture = "Interface\\Icons\\Spell_Holy_HealingAura" },
    ["Seal of Wisdom"] = { duration = 30, texture = "Interface\\Icons\\Spell_Holy_RighteousnessAura" },
}

-- ============================================================================
-- LOCAL STATE
-- ============================================================================

local SealTracker = {}
local currentSeal = nil
local sealExpireTime = 0
local sealTexture = nil
local isUpdating = false
local addonLoaded = false
local lastScanTime = 0
local SCAN_INTERVAL = 0.25  -- Scan every 0.25 seconds to catch refreshes

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SealTracker]|r " .. tostring(msg))
    end
end

local function GetSealInfo(sealName)
    if not sealName then return nil end
    if SEALS[sealName] then
        return SEALS[sealName]
    end
    -- Fallback for unknown seals - check if it starts with "Seal of"
    if string.find(sealName, "^Seal of") then
        return { duration = 30, texture = "Interface\\Icons\\INV_Misc_QuestionMark" }
    end
    return nil
end

local function FormatTime(seconds)
    if seconds <= 0 then
        return "0"
    elseif seconds < 10 then
        return string.format("%.1f", seconds)
    else
        return string.format("%d", math.floor(seconds))
    end
end

local function UpdateFontSize(frame, iconSize)
    -- Scale font size based on icon size (default icon is 48, default font is 18)
    local fontSize = math.max(10, math.floor(iconSize * 0.375))
    frame.timer:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
end

-- ============================================================================
-- BUFF SCANNING
-- ============================================================================

local function ScanForSeal()
    local foundSeal = nil
    local foundExpire = 0
    local foundTexture = nil
    
    if not SealTracker_TooltipFrame then return nil, 0, nil end
    
    for i = 0, 31 do
        local texture = GetPlayerBuffTexture(i)
        if texture then
            -- We need to identify the buff by tooltip
            SealTracker_TooltipFrame:SetOwner(UIParent, "ANCHOR_NONE")
            SealTracker_TooltipFrame:SetPlayerBuff(i)
            local textLine = getglobal("SealTracker_TooltipFrameTextLeft1")
            local buffName = nil
            if textLine then
                buffName = textLine:GetText()
            end
            SealTracker_TooltipFrame:Hide()
            
            if buffName then
                local sealInfo = GetSealInfo(buffName)
                if sealInfo then
                    -- Found a seal! Get remaining time
                    local timeLeft = GetPlayerBuffTimeLeft(i)
                    foundSeal = buffName
                    foundExpire = GetTime() + (timeLeft or sealInfo.duration)
                    foundTexture = texture
                    break
                end
            end
        end
    end
    
    return foundSeal, foundExpire, foundTexture
end

-- ============================================================================
-- FRAME CREATION
-- ============================================================================

local function CreateTooltipFrame()
    local f = CreateFrame("GameTooltip", "SealTracker_TooltipFrame", UIParent, "GameTooltipTemplate")
    f:SetOwner(UIParent, "ANCHOR_NONE")
    f:Hide()
    return f
end

local function CreateMainFrame()
    local f = CreateFrame("Frame", "SealTrackerFrame", UIParent)
    f:SetWidth(64)
    f:SetHeight(64)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("MEDIUM")
    
    -- Background
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints(f)
    f.bg:SetTexture(0, 0, 0, 0.5)
    
    -- Border
    f:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    f:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.8)
    
    -- Seal Icon
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetPoint("CENTER", f, "CENTER", 0, 0)
    f.icon:SetWidth(48)
    f.icon:SetHeight(48)
    f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    
    -- Icon Border Frame - a mini frame just for the border around the icon
    f.iconBorderFrame = CreateFrame("Frame", nil, f)
    f.iconBorderFrame:SetPoint("TOPLEFT", f.icon, "TOPLEFT", -4, 4)
    f.iconBorderFrame:SetPoint("BOTTOMRIGHT", f.icon, "BOTTOMRIGHT", 4, -4)
    f.iconBorderFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    f.iconBorderFrame:SetBackdropColor(0, 0, 0, 0.5)
    f.iconBorderFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.9)
    f.iconBorderFrame:SetFrameLevel(f:GetFrameLevel())  -- Behind the icon
    f.iconBorderFrame:Hide()
    
    -- Timer Text
    f.timer = f:CreateFontString(nil, "OVERLAY")
    f.timer:SetFont("Fonts\\FRIZQT__.TTF", 18, "OUTLINE")
    f.timer:SetPoint("CENTER", f.icon, "CENTER", 0, 0)
    f.timer:SetTextColor(1, 1, 1, 1)
    f.timer:SetShadowOffset(1, -1)
    
    -- Seal Name (optional)
    f.name = f:CreateFontString(nil, "OVERLAY")
    f.name:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    f.name:SetPoint("TOP", f, "BOTTOM", 0, -2)
    f.name:SetTextColor(1, 0.82, 0, 1)
    f.name:Hide()
    
    -- No Seal indicator
    f.noSeal = f:CreateFontString(nil, "OVERLAY")
    f.noSeal:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    f.noSeal:SetPoint("CENTER", f, "CENTER", 0, 0)
    f.noSeal:SetText("No Seal")
    f.noSeal:SetTextColor(0.5, 0.5, 0.5, 1)
    
    -- Resize handle
    f.resizeButton = CreateFrame("Button", nil, f)
    f.resizeButton:SetWidth(16)
    f.resizeButton:SetHeight(16)
    f.resizeButton:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    f.resizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    f.resizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    f.resizeButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    f.resizeButton:EnableMouse(true)
    
    -- Unlock indicator (shows when unlocked)
    f.unlockIcon = f:CreateFontString(nil, "OVERLAY")
    f.unlockIcon:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    f.unlockIcon:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -2)
    f.unlockIcon:SetText("U")
    f.unlockIcon:SetTextColor(0, 1, 0, 1)
    f.unlockIcon:Hide()
    
    return f
end

-- ============================================================================
-- FRAME BEHAVIOR
-- ============================================================================

local function SetupDragging(frame)
    frame:RegisterForDrag("LeftButton")
    
    frame:SetScript("OnDragStart", function()
        if not SealTrackerDB.locked then
            this:StartMoving()
        end
    end)
    
    frame:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        -- Save position relative to center of screen
        local centerX = this:GetLeft() + (this:GetWidth() / 2)
        local centerY = this:GetTop() - (this:GetHeight() / 2)
        local screenCenterX = UIParent:GetWidth() / 2
        local screenCenterY = UIParent:GetHeight() / 2
        SealTrackerDB.posX = centerX - screenCenterX
        SealTrackerDB.posY = centerY - screenCenterY
    end)
    
    -- Right-click menu
    frame:SetScript("OnMouseUp", function()
        if arg1 == "RightButton" then
            if frame.menu then
                UIDropDownMenu_Initialize(frame.menu, frame.menuInit, "MENU")
                ToggleDropDownMenu(1, nil, frame.menu, "cursor", 0, 0)
            end
        end
    end)
end

local function SetupResizing(frame)
    local resizing = false
    local startX, startY, startW, startH
    
    frame.resizeButton:SetScript("OnMouseDown", function()
        if not SealTrackerDB.locked then
            resizing = true
            startX, startY = GetCursorPosition()
            local scale = frame:GetEffectiveScale()
            startX = startX / scale
            startY = startY / scale
            startW = frame:GetWidth()
            startH = frame:GetHeight()
        end
    end)
    
    frame.resizeButton:SetScript("OnMouseUp", function()
        resizing = false
        SealTrackerDB.frameWidth = frame:GetWidth()
        SealTrackerDB.frameHeight = frame:GetHeight()
    end)
    
    frame:SetScript("OnUpdate", function()
        -- Handle resizing
        if resizing then
            local curX, curY = GetCursorPosition()
            local scale = frame:GetEffectiveScale()
            curX = curX / scale
            curY = curY / scale
            
            local newW = math.max(40, math.min(150, startW + (curX - startX)))
            local newH = math.max(40, math.min(150, startH - (curY - startY)))
            
            frame:SetWidth(newW)
            frame:SetHeight(newH)
            
            local iconSize = math.min(newW, newH) - 16
            frame.icon:SetWidth(iconSize)
            frame.icon:SetHeight(iconSize)
            UpdateFontSize(frame, iconSize)
            -- Border scales automatically via anchor points
        end
        
        -- Periodic scan to catch seal refreshes that events might miss
        local now = GetTime()
        if now - lastScanTime >= SCAN_INTERVAL then
            lastScanTime = now
            
            -- Quick scan for seal refresh detection
            local seal, expire, texture = ScanForSeal()
            
            if seal then
                -- If we found a seal, check if the expiration time changed significantly
                -- (more than 1 second difference means it was refreshed)
                if seal == currentSeal and expire > sealExpireTime + 1 then
                    -- Seal was refreshed! Update the expiration time
                    sealExpireTime = expire
                    sealTexture = texture
                elseif seal ~= currentSeal then
                    -- Different seal, do full update
                    currentSeal = seal
                    sealExpireTime = expire
                    sealTexture = texture
                    SealTracker.UpdateDisplay()
                end
            elseif currentSeal and not seal then
                -- Seal fell off
                currentSeal = nil
                SealTracker.UpdateDisplay()
            end
        end
        
        -- Update timer display
        if currentSeal and isUpdating then
            local remaining = sealExpireTime - GetTime()
            if remaining > 0 then
                frame.timer:SetText(FormatTime(remaining))
                
                if remaining <= 5 then
                    frame.timer:SetTextColor(1, 0.2, 0.2, 1)
                elseif remaining <= 10 then
                    frame.timer:SetTextColor(1, 1, 0, 1)
                else
                    frame.timer:SetTextColor(1, 1, 1, 1)
                end
            else
                currentSeal = nil
                SealTracker.UpdateDisplay()
            end
        end
    end)
end

local function SetupTooltip(frame)
    frame:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        if currentSeal then
            GameTooltip:SetText(currentSeal, 1, 0.82, 0)
            local remaining = sealExpireTime - GetTime()
            if remaining > 0 then
                GameTooltip:AddLine(string.format("%.1f seconds remaining", remaining), 1, 1, 1)
            end
        else
            GameTooltip:SetText("Seal Tracker", 1, 0.82, 0)
            GameTooltip:AddLine("No seal active", 0.5, 0.5, 0.5)
        end
        GameTooltip:AddLine(" ")
        if SealTrackerDB.locked then
            GameTooltip:AddLine("Type /st lock to unlock", 0.5, 0.5, 0.5)
        else
            GameTooltip:AddLine("Drag to move | Right-click for menu", 0.5, 0.5, 0.5)
        end
        GameTooltip:Show()
    end)
    
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function SetupRightClickMenu(frame)
    local menu = CreateFrame("Frame", "SealTrackerMenu", UIParent, "UIDropDownMenuTemplate")
    
    local function InitializeMenu()
        local info
        
        -- Title
        info = {}
        info.text = "Seal Tracker"
        info.isTitle = 1
        info.notCheckable = 1
        UIDropDownMenu_AddButton(info)
        
        -- Lock toggle
        info = {}
        if SealTrackerDB.locked then
            info.text = "Unlock Frame"
        else
            info.text = "Lock Frame"
        end
        info.notCheckable = 1
        info.func = function()
            SealTracker.ToggleLock()
        end
        UIDropDownMenu_AddButton(info)
        
        -- Show timer
        info = {}
        info.text = "Show Timer"
        info.checked = SealTrackerDB.showTimer
        info.func = function()
            SealTrackerDB.showTimer = not SealTrackerDB.showTimer
            SealTracker.UpdateDisplay()
        end
        UIDropDownMenu_AddButton(info)
        
        -- Show name
        info = {}
        info.text = "Show Seal Name"
        info.checked = SealTrackerDB.showName
        info.func = function()
            SealTrackerDB.showName = not SealTrackerDB.showName
            SealTracker.UpdateDisplay()
        end
        UIDropDownMenu_AddButton(info)
        
        -- Reset
        info = {}
        info.text = "Reset Position"
        info.notCheckable = 1
        info.func = function()
            SealTracker.ResetPosition()
        end
        UIDropDownMenu_AddButton(info)
        
        -- Close
        info = {}
        info.text = "Close"
        info.notCheckable = 1
        info.func = function()
            CloseDropDownMenus()
        end
        UIDropDownMenu_AddButton(info)
    end
    
    frame.menuInit = InitializeMenu
    frame.menu = menu
end

-- ============================================================================
-- PUBLIC FUNCTIONS
-- ============================================================================

function SealTracker.UpdateDisplay()
    local frame = SealTrackerFrame
    if not frame or not addonLoaded then return end
    
    -- Scan for current seal
    local seal, expire, texture = ScanForSeal()
    currentSeal = seal
    sealExpireTime = expire
    sealTexture = texture
    
    if currentSeal then
        -- Show seal icon and timer
        frame.icon:SetTexture(sealTexture or SEALS[currentSeal].texture)
        frame.icon:Show()
        frame.noSeal:Hide()
        isUpdating = true
        
        if SealTrackerDB.showTimer then
            frame.timer:Show()
        else
            frame.timer:Hide()
        end
        
        if SealTrackerDB.showName then
            local shortName = string.gsub(currentSeal, "Seal of ", "")
            frame.name:SetText(shortName)
            frame.name:Show()
        else
            frame.name:Hide()
        end
        
        frame:Show()
    else
        -- No seal
        frame.icon:Hide()
        frame.timer:Hide()
        frame.name:Hide()
        frame.noSeal:Show()
        isUpdating = false
        
        -- Hide when locked + no seal, show when unlocked
        if SealTrackerDB.locked then
            frame:Hide()
        else
            frame:Show()
        end
    end
    
    -- When locked: hide UI chrome, show clean icon border
    -- When unlocked: show frame chrome for positioning
    if SealTrackerDB.locked then
        frame.unlockIcon:Hide()
        frame.resizeButton:Hide()
        frame.bg:Hide()
        frame:SetBackdrop(nil)
        if currentSeal then
            frame.iconBorderFrame:Show()
        else
            frame.iconBorderFrame:Hide()
        end
    else
        frame.unlockIcon:Show()
        frame.resizeButton:Show()
        frame.bg:Show()
        frame:SetBackdrop({
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        frame:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.8)
        frame.iconBorderFrame:Hide()
    end
end

function SealTracker.ToggleLock()
    SealTrackerDB.locked = not SealTrackerDB.locked
    if SealTrackerDB.locked then
        Print("Frame locked - will hide when no seal is active")
    else
        Print("Frame unlocked - drag to reposition")
    end
    SealTracker.UpdateDisplay()
end

function SealTracker.ResetPosition()
    SealTrackerDB.posX = 0
    SealTrackerDB.posY = 0
    SealTrackerDB.frameWidth = 64
    SealTrackerDB.frameHeight = 64
    SealTrackerDB.scale = 1.0
    SealTrackerDB.locked = false
    
    local frame = SealTrackerFrame
    if frame then
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        frame:SetWidth(64)
        frame:SetHeight(64)
        frame:SetScale(1.0)
        frame.icon:SetWidth(48)
        frame.icon:SetHeight(48)
        UpdateFontSize(frame, 48)
        -- Border scales automatically via anchors
    end
    
    Print("Position reset to center, frame unlocked")
    SealTracker.UpdateDisplay()
end

function SealTracker.SetScale(scale)
    scale = tonumber(scale)
    if not scale or scale < 0.5 or scale > 2.0 then
        Print("Scale must be between 0.5 and 2.0")
        return
    end
    SealTrackerDB.scale = scale
    if SealTrackerFrame then
        SealTrackerFrame:SetScale(scale)
    end
    Print("Scale set to " .. scale)
end

function SealTracker.ForceShow()
    if SealTrackerFrame then
        SealTrackerFrame:Show()
        Print("Frame shown. Use /st lock to toggle lock state.")
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local function LoadSettings()
    -- Apply defaults for any missing settings
    for k, v in pairs(defaults) do
        if SealTrackerDB[k] == nil then
            SealTrackerDB[k] = v
        end
    end
    
    local frame = SealTrackerFrame
    if not frame then return end
    
    -- Apply saved position
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", SealTrackerDB.posX or 0, SealTrackerDB.posY or 0)
    
    -- Apply saved size
    frame:SetWidth(SealTrackerDB.frameWidth or 64)
    frame:SetHeight(SealTrackerDB.frameHeight or 64)
    
    -- Scale icon (border scales automatically via anchors)
    local iconSize = math.min(SealTrackerDB.frameWidth or 64, SealTrackerDB.frameHeight or 64) - 16
    frame.icon:SetWidth(iconSize)
    frame.icon:SetHeight(iconSize)
    UpdateFontSize(frame, iconSize)
    
    -- Apply scale
    frame:SetScale(SealTrackerDB.scale or 1.0)
end

local function Initialize()
    -- Check if player is a Paladin
    local _, class = UnitClass("player")
    if class ~= "PALADIN" then
        Print("This addon only works for Paladins!")
        return
    end
    
    CreateTooltipFrame()
    local frame = CreateMainFrame()
    SetupDragging(frame)
    SetupResizing(frame)
    SetupTooltip(frame)
    SetupRightClickMenu(frame)
    LoadSettings()
    
    addonLoaded = true
    
    -- Don't call UpdateDisplay here - just show the frame at saved position
    -- Aura events will handle showing/hiding properly
    frame:Show()
    
    if SealTrackerDB.locked then
        Print("Loaded! Frame is locked. Type /st lock to unlock.")
    else
        Print("Loaded! Type /st for commands.")
    end
end

-- ============================================================================
-- EVENT HANDLING
-- ============================================================================

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_AURAS_CHANGED")
eventFrame:RegisterEvent("UNIT_AURA")

eventFrame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "SealTracker" then
        -- Our saved variables are now available
        if not SealTrackerDB then
            SealTrackerDB = {}
        end
    elseif event == "PLAYER_LOGIN" then
        Initialize()
    elseif event == "PLAYER_AURAS_CHANGED" then
        if addonLoaded then
            SealTracker.UpdateDisplay()
        end
    elseif event == "UNIT_AURA" then
        if arg1 == "player" and addonLoaded then
            SealTracker.UpdateDisplay()
        end
    end
end)

-- ============================================================================
-- SLASH COMMANDS
-- ============================================================================

SLASH_SEALTRACKER1 = "/sealtracker"
SLASH_SEALTRACKER2 = "/st"

SlashCmdList["SEALTRACKER"] = function(msg)
    if not msg then msg = "" end
    msg = string.lower(msg)
    
    -- Trim whitespace
    msg = string.gsub(msg, "^%s*(.-)%s*$", "%1")
    
    if msg == "" or msg == "help" then
        Print("Commands:")
        Print("  /st lock - Toggle lock (locked = auto-hide when no seal)")
        Print("  /st reset - Reset position/size and unlock")
        Print("  /st show - Force show the frame")
        Print("  /st timer - Toggle timer display")
        Print("  /st name - Toggle seal name")
        Print("  /st scale 1.5 - Set scale (0.5 to 2.0)")
        
    elseif msg == "lock" then
        SealTracker.ToggleLock()
        
    elseif msg == "reset" then
        SealTracker.ResetPosition()
        
    elseif msg == "show" then
        SealTracker.ForceShow()
        
    elseif msg == "timer" then
        SealTrackerDB.showTimer = not SealTrackerDB.showTimer
        Print("Timer " .. (SealTrackerDB.showTimer and "shown" or "hidden"))
        SealTracker.UpdateDisplay()
        
    elseif msg == "name" then
        SealTrackerDB.showName = not SealTrackerDB.showName
        Print("Seal name " .. (SealTrackerDB.showName and "shown" or "hidden"))
        SealTracker.UpdateDisplay()
        
    elseif string.find(msg, "^scale") then
        -- Extract number after "scale "
        local _, _, num = string.find(msg, "scale%s+([%d%.]+)")
        if num then
            SealTracker.SetScale(num)
        else
            Print("Usage: /st scale 1.5")
        end
        
    else
        Print("Unknown command. Type /st for help.")
    end
end
