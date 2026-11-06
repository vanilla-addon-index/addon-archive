-- RogueTicker: Energy, tick prediction and combo point tracker for rogues
-- Compatible with WoW Vanilla 1.12.1 (Lua 5.0)

-- Initialize addon namespace
RogueTicker = {}
local RT = RogueTicker

-- Default settings
local defaults = {
    enabled = true,
    locked = false,
    showEnergy = true,
    showTicks = true,
    showComboPoints = true,
    frameX = 0,
    frameY = -100,
    frameWidth = 180,
    frameHeight = 60,
    scale = 1.0,
    energyColor = {0.80, 0.77, 0.33, 1}, -- Darker Rogue Energy Yellow (20% darker)
    comboColor = {1, 0.2, 0.2, 1}, -- Red
    tickColor = {0.5, 1, 0.5, 1}  -- Green
}

-- Variables
local mainFrame
local energyFrame
local comboFrame
local tickFrame
local lastEnergyTime = 0
local lastEnergy = 0
local energyTickTimer = 0
local ENERGY_TICK_INTERVAL = 2.0 -- Energy ticks every 2 seconds (base rate)
local isInCombat = false -- Track combat state

-- Smooth animation variables
local displayedEnergy = 0 -- Current displayed energy (for smooth animation)
local targetEnergy = 0 -- Target energy value
local animationSpeed = 200 -- Energy units per second for smooth animation

-- Vigor Talent Handler
-- Get Vigor talent rank (increases max energy by 5 per rank)
local function GetVigorRank()
    -- Check for Vigor talent (tab 1, talent 16)
    local _, _, _, _, currRank = GetTalentInfo(1, 16)
    return currRank or 0
end

-- Blade Rush Talent Handler
-- Calculate dynamic energy tick rate based on Blade Rush talent and agility
local function GetEnergyTickRate()
    local baseTickRate = 2.0 -- Base 2 seconds
    
    -- Check for Blade Rush talent (tab 2, talent 16)
    local _, _, _, _, currRank = GetTalentInfo(2, 16)
    local bladeRushRank = currRank or 0
    
    if bladeRushRank > 0 then
        local agility = UnitStat("player", 2) -- 2 is agility stat index
        local reductionPerAgi = 0.0006 * bladeRushRank -- 0.0006 for rank 1, 0.0012 for rank 2
        local totalReduction = agility * reductionPerAgi
        baseTickRate = baseTickRate - totalReduction
        
        -- Ensure we don't go below a reasonable minimum (e.g., 0.5 seconds)
        if baseTickRate < 0.5 then
            baseTickRate = 0.5
        end
    end
    
    return baseTickRate
end

-- Update energy tick rate
function RT:UpdateEnergyTickRate()
    ENERGY_TICK_INTERVAL = GetEnergyTickRate()
end

-- Initialize saved variables
function RT:InitializeDB()
    if not RogueTickerDB then
        RogueTickerDB = {}
    end
    
    -- Copy defaults for missing values
    for key, value in pairs(defaults) do
        if RogueTickerDB[key] == nil then
            RogueTickerDB[key] = value
        end
    end
end

-- Create main frame
function RT:CreateMainFrame()
    mainFrame = CreateFrame("Frame", "RogueTickerMainFrame", UIParent)
    mainFrame:SetWidth(RogueTickerDB.frameWidth)
    mainFrame:SetHeight(RogueTickerDB.frameHeight)
    mainFrame:SetPoint("CENTER", UIParent, "CENTER", RogueTickerDB.frameX, RogueTickerDB.frameY)
    -- Scale is already included in the saved frameWidth/frameHeight, so set to 1.0
    mainFrame:SetScale(1.0)
    
    -- Background
    mainFrame.bg = mainFrame:CreateTexture(nil, "BACKGROUND")
    mainFrame.bg:SetAllPoints(mainFrame)
    mainFrame.bg:SetTexture(0, 0, 0, 0.3) -- Visible when unlocked
    
    -- Update background visibility based on lock state
    RT:UpdateBackground()
    

    
    -- Make draggable and resizable when unlocked
    mainFrame:SetMovable(true)
    mainFrame:SetResizable(true)
    -- Set consistent resize limits based on default size (180x60)
    -- This prevents cascading size changes after reload
    local baseWidth = 180
    local baseHeight = 60
    local minWidth = math.floor(baseWidth * 0.6)   -- 108
    local minHeight = math.floor(baseHeight * 0.6)  -- 36
    local maxWidth = math.floor(baseWidth * 3.0)   -- 540
    local maxHeight = math.floor(baseHeight * 3.0)  -- 180
    mainFrame:SetMinResize(minWidth, minHeight)
    mainFrame:SetMaxResize(maxWidth, maxHeight)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", function()
        if not RogueTickerDB.locked then
            this:StartMoving()
        end
    end)
    mainFrame:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        local x, y = this:GetCenter()
        local uiX, uiY = UIParent:GetCenter()
        RogueTickerDB.frameX = x - uiX
        RogueTickerDB.frameY = y - uiY
    end)
    
    -- Add real-time resize handler
    mainFrame:SetScript("OnSizeChanged", function()
        RT:UpdateFrameSizes()
    end)
    
    -- Create resize handle
    RT:CreateResizeHandle()
    
    -- Set initial resize limits
    RT:UpdateResizeLimits()
    
    -- Set initial font sizes based on frame dimensions
    RT:UpdateFontSizes()
end

-- Create resize handle in bottom right corner
function RT:CreateResizeHandle()
    local resizeHandle = CreateFrame("Frame", "RogueTickerResize", mainFrame)
    resizeHandle:SetWidth(16)
    resizeHandle:SetHeight(16)
    resizeHandle:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", 8, -8)
    resizeHandle:EnableMouse(true)
    
    -- Create textures for different states
    resizeHandle.normalTexture = resizeHandle:CreateTexture(nil, "ARTWORK")
    resizeHandle.normalTexture:SetAllPoints(resizeHandle)
    resizeHandle.normalTexture:SetTexture("Interface\\AddOns\\RogueTicker\\img\\SizeGrabber-Up")
    
    resizeHandle.highlightTexture = resizeHandle:CreateTexture(nil, "HIGHLIGHT")
    resizeHandle.highlightTexture:SetAllPoints(resizeHandle)
    resizeHandle.highlightTexture:SetTexture("Interface\\AddOns\\RogueTicker\\img\\SizeGrabber-Highlight")
    
    resizeHandle.pushedTexture = resizeHandle:CreateTexture(nil, "ARTWORK")
    resizeHandle.pushedTexture:SetAllPoints(resizeHandle)
    resizeHandle.pushedTexture:SetTexture("Interface\\AddOns\\RogueTicker\\img\\SizeGrabber-Down")
    resizeHandle.pushedTexture:Hide()
    
    -- Mouse events for visual feedback
    resizeHandle:SetScript("OnMouseDown", function()
        resizeHandle.normalTexture:Hide()
        resizeHandle.pushedTexture:Show()
    end)
    
    resizeHandle:SetScript("OnMouseUp", function()
        resizeHandle.pushedTexture:Hide()
        resizeHandle.normalTexture:Show()
    end)
    
    -- Drag functionality for resizing
    resizeHandle:RegisterForDrag("LeftButton")
    resizeHandle:SetScript("OnDragStart", function()
        if not RogueTickerDB.locked then
            mainFrame:StartSizing("BOTTOMRIGHT")
        end
    end)
    
    resizeHandle:SetScript("OnDragStop", function()
        mainFrame:StopMovingOrSizing()
        -- Save the actual frame dimensions
        RogueTickerDB.frameWidth = mainFrame:GetWidth()
        RogueTickerDB.frameHeight = mainFrame:GetHeight()
        -- Don't update scale - we're storing actual pixel dimensions
        -- Update resize limits based on new size
        RT:UpdateResizeLimits()
        -- Update font sizes based on new frame size
        RT:UpdateFontSizes()
    end)
    
    -- Store reference and set initial visibility
    mainFrame.resizeHandle = resizeHandle
    if RogueTickerDB.locked then
        resizeHandle:Hide()
    else
        resizeHandle:Show()
    end
end

-- Update frame scaling
function RT:UpdateScale()
    local scale = RogueTickerDB.scale or 1.0
    mainFrame:SetScale(scale)
end

-- Update resize limits based on default frame size (consistent limits)
function RT:UpdateResizeLimits()
    if not mainFrame then return end
    
    -- Use consistent limits based on default size (180x60)
    -- This prevents cascading size changes after reload
    local baseWidth = 180
    local baseHeight = 60
    local minWidth = math.floor(baseWidth * 0.6)   -- 108
    local minHeight = math.floor(baseHeight * 0.6)  -- 36
    local maxWidth = math.floor(baseWidth * 3.0)   -- 540
    local maxHeight = math.floor(baseHeight * 3.0)  -- 180
    mainFrame:SetMinResize(minWidth, minHeight)
    mainFrame:SetMaxResize(maxWidth, maxHeight)
end

-- Update font sizes based on frame dimensions
function RT:UpdateFontSizes()
    if not mainFrame then return end
    
    local currentWidth = mainFrame:GetWidth()
    local currentHeight = mainFrame:GetHeight()
    local baseWidth = 180  -- Default width
    local baseHeight = 60  -- Default height
    
    -- Calculate scale factor based on frame size (use smaller dimension to maintain readability)
    local widthScale = currentWidth / baseWidth
    local heightScale = currentHeight / baseHeight
    local fontScale = math.min(widthScale, heightScale)
    
    -- Clamp font scale to reasonable bounds (1.0x to 2.5x for better readability at minimum size)
    fontScale = math.max(1.0, math.min(2.5, fontScale))
    
    -- Get base font size from GameFontNormalSmall (typically 12px)
    local baseFontSize = 12
    local newFontSize = math.floor(baseFontSize * fontScale + 0.5) -- Round to nearest integer
    
    -- Update energy text fonts
    if energyFrame and energyFrame.text then
        local font, _, flags = energyFrame.text:GetFont()
        if font then
            energyFrame.text:SetFont(font, newFontSize, flags)
        end
    end
    
    if energyFrame and energyFrame.textShadow then
        local font, _, flags = energyFrame.textShadow:GetFont()
        if font then
            energyFrame.textShadow:SetFont(font, newFontSize, flags)
        end
    end
end

-- Update background visibility based on lock state
function RT:UpdateBackground()
    if not mainFrame or not mainFrame.bg then return end
    
    if RogueTickerDB.locked then
        mainFrame.bg:SetTexture(0, 0, 0, 0) -- Fully transparent when locked
    else
        mainFrame.bg:SetTexture(0, 0, 0, 0.3) -- Visible when unlocked
    end
end

-- Update child frame sizes based on main frame dimensions
function RT:UpdateFrameSizes()
    if not mainFrame or not energyFrame or not comboFrame then return end
    
    local newWidth = mainFrame:GetWidth()
    local newHeight = mainFrame:GetHeight()
    
    -- Calculate proportional heights based on total height
    local energyHeight = math.max(12, newHeight * 0.33) -- At least 12px, 33% of total height
    local comboHeight = math.max(15, newHeight * 0.42) -- At least 15px, 42% of total height
    local topMargin = math.max(5, newHeight * 0.08) -- At least 5px margin
    local spacing = 3 -- Fixed 3px spacing between energy bar and combo frame
    
    -- Update combo frame dimensions and position (above energy bar)
    comboFrame:SetWidth(newWidth)
    comboFrame:SetHeight(comboHeight)
    comboFrame:SetPoint("TOP", mainFrame, "TOP", 0, -topMargin)
    
    -- Update energy frame dimensions and position (below combo frame)
    energyFrame:SetWidth(newWidth)
    energyFrame:SetHeight(energyHeight)
    energyFrame:ClearAllPoints()
    energyFrame:SetPoint("TOP", comboFrame, "BOTTOM", 0, -spacing)
     
     -- Update energy bar height
     if energyFrame.bar then
         energyFrame.bar:SetHeight(energyHeight)
     end
     
     -- Update tick spark height
     if tickFrame and tickFrame.spark then
         tickFrame.spark:SetHeight(energyHeight + 5) -- Slightly taller than energy bar
     end
    
    -- Update combo point positioning and sizing based on new dimensions
    if comboFrame.points then
        local fixedSpacing = 3 -- Fixed 3px spacing between all combo points
        local minPointWidth = 15 -- Minimum width for each combo point
        local totalSpacingWidth = 4 * fixedSpacing -- Total width needed for spacing (4 gaps between 5 points)
        local availableForPoints = newWidth - totalSpacingWidth -- Width available for the actual points
        
        local pointWidth = math.max(minPointWidth, availableForPoints / 5) -- Divide available width by 5 points
        
        local pointHeight = math.max(12, comboHeight - 5) -- Leave some margin
        for i = 1, 5 do
            if comboFrame.points[i] then
                local xPos = (i-1) * (pointWidth + fixedSpacing)
                comboFrame.points[i]:SetPoint("LEFT", comboFrame, "LEFT", xPos, 0)
                comboFrame.points[i]:SetWidth(pointWidth)
                comboFrame.points[i]:SetHeight(pointHeight)
            end
        end
    end
    
    -- Update font sizes when frame dimensions change
    RT:UpdateFontSizes()
end

-- Create energy display
function RT:CreateEnergyFrame()
    energyFrame = CreateFrame("Frame", nil, mainFrame)
    energyFrame:SetWidth(180)
    energyFrame:SetHeight(20)
    energyFrame:SetPoint("TOP", comboFrame, "BOTTOM", 0, -5)
    
    -- Energy bar background
    energyFrame.bg = energyFrame:CreateTexture(nil, "BACKGROUND")
    energyFrame.bg:SetAllPoints(energyFrame)
    energyFrame.bg:SetTexture(0, 0, 0, 0.4)
    
    -- Energy bar custom border (simple 1px outline)
    energyFrame.borderTop = energyFrame:CreateTexture(nil, "OVERLAY")
    energyFrame.borderTop:SetPoint("TOPLEFT", energyFrame, "TOPLEFT", -1, 1)
    energyFrame.borderTop:SetPoint("TOPRIGHT", energyFrame, "TOPRIGHT", 1, 1)
    energyFrame.borderTop:SetHeight(1)
    energyFrame.borderTop:SetTexture(0, 0, 0, 0.8)
    
    energyFrame.borderBottom = energyFrame:CreateTexture(nil, "OVERLAY")
    energyFrame.borderBottom:SetPoint("BOTTOMLEFT", energyFrame, "BOTTOMLEFT", -1, -1)
    energyFrame.borderBottom:SetPoint("BOTTOMRIGHT", energyFrame, "BOTTOMRIGHT", 1, -1)
    energyFrame.borderBottom:SetHeight(1)
    energyFrame.borderBottom:SetTexture(0, 0, 0, 0.8)
    
    energyFrame.borderLeft = energyFrame:CreateTexture(nil, "OVERLAY")
    energyFrame.borderLeft:SetPoint("TOPLEFT", energyFrame, "TOPLEFT", -1, 1)
    energyFrame.borderLeft:SetPoint("BOTTOMLEFT", energyFrame, "BOTTOMLEFT", -1, -1)
    energyFrame.borderLeft:SetWidth(1)
    energyFrame.borderLeft:SetTexture(0, 0, 0, 0.8)
    
    energyFrame.borderRight = energyFrame:CreateTexture(nil, "OVERLAY")
    energyFrame.borderRight:SetPoint("TOPRIGHT", energyFrame, "TOPRIGHT", 1, 1)
    energyFrame.borderRight:SetPoint("BOTTOMRIGHT", energyFrame, "BOTTOMRIGHT", 1, -1)
    energyFrame.borderRight:SetWidth(1)
    energyFrame.borderRight:SetTexture(0, 0, 0, 0.8)
    
    -- Energy bar with gradient texture
    energyFrame.bar = energyFrame:CreateTexture(nil, "ARTWORK")
    energyFrame.bar:SetHeight(20)
    energyFrame.bar:SetPoint("LEFT", energyFrame, "LEFT", 0, 0)
    energyFrame.bar:SetTexture("Interface\\AddOns\\RogueTicker\\img\\bar_gradient")
    energyFrame.bar:SetVertexColor(RogueTickerDB.energyColor[1], RogueTickerDB.energyColor[2], RogueTickerDB.energyColor[3], RogueTickerDB.energyColor[4])
    
    -- Energy text shadow (outline effect)
    energyFrame.textShadow = energyFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    energyFrame.textShadow:SetPoint("RIGHT", energyFrame, "RIGHT", -4.5, -0.5)
    energyFrame.textShadow:SetTextColor(0, 0, 0, 1)
    
    -- Energy text
    energyFrame.text = energyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    energyFrame.text:SetPoint("RIGHT", energyFrame, "RIGHT", -5, 0)
    energyFrame.text:SetTextColor(1, 1, 1, 1)
end

-- Create energy tick spark frame
function RT:CreateTickFrame()
    tickFrame = CreateFrame("Frame", nil, energyFrame)
    tickFrame:SetAllPoints(energyFrame)
    tickFrame:Hide() -- Start hidden
    
    -- Energy tick spark
    tickFrame.spark = tickFrame:CreateTexture(nil, "OVERLAY")
    tickFrame.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    tickFrame.spark:SetHeight(25) -- Slightly taller than energy bar
    tickFrame.spark:SetWidth(20)
    tickFrame.spark:SetBlendMode("ADD")
    tickFrame.spark:SetPoint("LEFT", tickFrame, "LEFT", 0, 0)
    
    -- Initialize tick variables
    tickFrame.lastEnergy = UnitMana("player")
    tickFrame.mode = "ENERGY"
end

-- Create combo point display
function RT:CreateComboFrame()
    comboFrame = CreateFrame("Frame", nil, mainFrame)
    comboFrame:SetWidth(180)
    comboFrame:SetHeight(25)
    comboFrame:SetPoint("TOP", mainFrame, "TOP", 0, -10)
    
    comboFrame.points = {}
    for i = 1, 5 do
        -- Create individual combo point frames
        local pointFrame = CreateFrame("Frame", "RogueTickerCombo" .. i, comboFrame)
        pointFrame:SetWidth(32)
        pointFrame:SetHeight(20)
        pointFrame:SetPoint("LEFT", comboFrame, "LEFT", (i-1) * 37, 0)
        
        -- Combo point background
        pointFrame.bg = pointFrame:CreateTexture(nil, "BACKGROUND")
        pointFrame.bg:SetAllPoints(pointFrame)
        pointFrame.bg:SetTexture(0, 0, 0, 0.3)
        
        -- Combo point custom border (simple 1px outline)
        pointFrame.borderTop = pointFrame:CreateTexture(nil, "OVERLAY")
        pointFrame.borderTop:SetPoint("TOPLEFT", pointFrame, "TOPLEFT", -1, 1)
        pointFrame.borderTop:SetPoint("TOPRIGHT", pointFrame, "TOPRIGHT", 1, 1)
        pointFrame.borderTop:SetHeight(1)
        pointFrame.borderTop:SetTexture(0, 0, 0, 0.7)
        
        pointFrame.borderBottom = pointFrame:CreateTexture(nil, "OVERLAY")
        pointFrame.borderBottom:SetPoint("BOTTOMLEFT", pointFrame, "BOTTOMLEFT", -1, -1)
        pointFrame.borderBottom:SetPoint("BOTTOMRIGHT", pointFrame, "BOTTOMRIGHT", 1, -1)
        pointFrame.borderBottom:SetHeight(1)
        pointFrame.borderBottom:SetTexture(0, 0, 0, 0.7)
        
        pointFrame.borderLeft = pointFrame:CreateTexture(nil, "OVERLAY")
        pointFrame.borderLeft:SetPoint("TOPLEFT", pointFrame, "TOPLEFT", -1, 1)
        pointFrame.borderLeft:SetPoint("BOTTOMLEFT", pointFrame, "BOTTOMLEFT", -1, -1)
        pointFrame.borderLeft:SetWidth(1)
        pointFrame.borderLeft:SetTexture(0, 0, 0, 0.7)
        
        pointFrame.borderRight = pointFrame:CreateTexture(nil, "OVERLAY")
        pointFrame.borderRight:SetPoint("TOPRIGHT", pointFrame, "TOPRIGHT", 1, 1)
        pointFrame.borderRight:SetPoint("BOTTOMRIGHT", pointFrame, "BOTTOMRIGHT", 1, -1)
        pointFrame.borderRight:SetWidth(1)
        pointFrame.borderRight:SetTexture(0, 0, 0, 0.7)
        
        -- Main combo point texture
        pointFrame.tex = pointFrame:CreateTexture(nil, "ARTWORK")
        pointFrame.tex:SetAllPoints(pointFrame)
        
        -- Color coding based on pfUI example: 1-2 red, 3 yellow, 4-5 green
        if i < 3 then
            pointFrame.tex:SetTexture(1, 0.3, 0.3, 0.75) -- Red
        elseif i < 4 then
            pointFrame.tex:SetTexture(1, 1, 0.3, 0.75) -- Yellow
        else
            pointFrame.tex:SetTexture(0.3, 1, 0.3, 0.75) -- Green
        end
        
        pointFrame:Hide() -- Start hidden
        comboFrame.points[i] = pointFrame
    end
    

end

-- Update energy display with smooth animation
function RT:UpdateEnergy(dt)
    if not RogueTickerDB.showEnergy or not energyFrame then return end
    
    local currentEnergy = UnitMana("player")
    local maxEnergy = UnitManaMax("player")
    local powerType = UnitPowerType("player")
    
    -- Only show for rogues with energy
    if powerType ~= 3 then -- 3 = Energy
        mainFrame:Hide()
        return
    else
        mainFrame:Show()
    end
    
    -- Initialize displayed energy on first run
    if displayedEnergy == 0 then
        displayedEnergy = currentEnergy
        targetEnergy = currentEnergy
    end
    
    -- Update target energy
    targetEnergy = currentEnergy
    
    -- Smooth interpolation towards target
    if displayedEnergy ~= targetEnergy then
        local energyDiff = targetEnergy - displayedEnergy
        local maxChange = animationSpeed * (dt or 0.016) -- Default to ~60fps if no dt
        
        if energyDiff > 0 then
            -- Energy increasing (regeneration)
            displayedEnergy = displayedEnergy + math.min(maxChange, energyDiff)
        else
            -- Energy decreasing (spending)
            displayedEnergy = displayedEnergy + math.max(-maxChange, energyDiff)
        end
        
        -- Snap to target if very close
        if math.abs(targetEnergy - displayedEnergy) < 0.1 then
            displayedEnergy = targetEnergy
        end
    end
    
    -- Update bar width with smooth displayed energy
    local percentage = displayedEnergy / maxEnergy
    local frameWidth = energyFrame:GetWidth()
    energyFrame.bar:SetWidth(frameWidth * percentage)
    
    -- Update text with actual current energy (not displayed)
    energyFrame.text:SetText(currentEnergy)
    energyFrame.textShadow:SetText(currentEnergy)
    
    -- Track energy changes for tick prediction
    local currentTime = GetTime()
    if currentEnergy > lastEnergy then
        lastEnergyTime = currentTime
        energyTickTimer = 0
    end
    lastEnergy = currentEnergy
end

-- Update energy tick spark (fluid animation)
function RT:UpdateTick()
    if not RogueTickerDB.showTicks or not tickFrame then return end
    
    local powerType = UnitPowerType("player")
    if powerType ~= 3 then -- Not energy
        tickFrame:Hide()
        return
    end
    
    local currentEnergy = UnitMana("player")
    local maxEnergy = UnitManaMax("player")
    
    -- Calculate time since last energy tick
    local currentTime = GetTime()
    local timeSinceLastTick = currentTime - lastEnergyTime
    local tickRate = GetEnergyTickRate()
    
    -- Show tick animation during combat, hide when out of combat
    if isInCombat then
        -- In combat: show tick animation regardless of energy level
        if not tickFrame.start then
            -- Calculate remaining time until next tick
            local timeUntilNextTick = tickRate - mod(timeSinceLastTick, tickRate)
            tickFrame.target = timeUntilNextTick
            tickFrame:Show()
        end
    else
        -- Out of combat: only show on energy changes (original behavior)
        if tickFrame.lastEnergy and currentEnergy > tickFrame.lastEnergy then
            local diff = currentEnergy - tickFrame.lastEnergy
            if diff > 0 then
                -- Calculate remaining time until next tick based on when this tick occurred
                local timeUntilNextTick = tickRate
                tickFrame.target = timeUntilNextTick
                tickFrame:Show()
            end
        else
            -- Hide when out of combat and no energy change
            tickFrame:Hide()
            return
        end
    end
    
    -- Check if energy increased during animation (restart animation with correct timing)
    if tickFrame.lastEnergy and currentEnergy > tickFrame.lastEnergy and tickFrame.start then
        -- Energy tick occurred during animation - restart with new timing
        lastEnergyTime = GetTime()
        local timeUntilNextTick = GetEnergyTickRate()
        tickFrame.target = timeUntilNextTick
        tickFrame.start = nil -- Force restart
    end
    
    tickFrame.lastEnergy = currentEnergy
    
    -- Handle spark animation
    if tickFrame.target then
        tickFrame.start = GetTime()
        tickFrame.max = tickFrame.target
        tickFrame.target = nil
    end
    
    if not tickFrame.start then 
        tickFrame:Hide()
        return 
    end
    
    tickFrame.current = GetTime() - tickFrame.start
    
    -- Reset animation when complete
    if tickFrame.current > tickFrame.max then
        tickFrame.start = nil
        tickFrame.max = nil
        tickFrame.current = nil
        tickFrame:Hide()
        return
    end
    
    -- Calculate spark position (fluid motion across the bar)
    local progress = tickFrame.current / tickFrame.max
    local barWidth = energyFrame:GetWidth() -- Current energy bar width
    local sparkPos = barWidth * progress
    
    -- Position the spark
    tickFrame.spark:SetPoint("LEFT", tickFrame, "LEFT", sparkPos - 10, 0)
end

-- Update combo points (enhanced with pfUI-style display)
function RT:UpdateComboPoints()
    if not RogueTickerDB.showComboPoints or not comboFrame then return end
    
    local comboPoints = GetComboPoints("target")
    
    -- Show all 5 combo points when unlocked for preview, otherwise show actual count
    if not RogueTickerDB.locked then
        -- Show all 5 combo points when unlocked for preview
        for i = 1, 5 do
            comboFrame.points[i]:Show()
        end
    else
        -- Normal behavior when locked - show actual combo points
        for i = 1, comboPoints do
            comboFrame.points[i]:Show()
        end
        
        -- Hide remaining combo points
        for i = comboPoints + 1, 5 do
            comboFrame.points[i]:Hide()
        end
    end
end

-- Main update function
function RT:OnUpdate(dt)
    self:UpdateEnergy(dt)
    self:UpdateTick()
    self:UpdateComboPoints()
end

-- Event handler
function RT:OnEvent(event)
    if event == "ADDON_LOADED" and arg1 == "RogueTicker" then
        self:InitializeDB()
        self:CreateMainFrame()
        self:CreateEnergyFrame()
        self:CreateTickFrame()
        self:CreateComboFrame()
        -- UpdateScale removed - we now use scale 1.0 with actual pixel dimensions
        
        -- Check if player is a rogue
        local _, playerClass = UnitClass("player")
        if playerClass ~= "ROGUE" then
            mainFrame:Hide()
            DEFAULT_CHAT_FRAME:AddMessage("RogueTicker: This addon is designed for rogues only.")
            return
        end
        
        -- Calculate initial energy tick rate
        self:UpdateEnergyTickRate()
        
        -- Initialize combat state
        isInCombat = UnitAffectingCombat("player") or false
        
        DEFAULT_CHAT_FRAME:AddMessage("RogueTicker loaded! Type /rt for options.")
        
    elseif event == "UNIT_MANA" and arg1 == "player" then
        self:UpdateEnergy()
        self:UpdateTick()
        
    elseif event == "UNIT_MAXMANA" and arg1 == "player" then
        self:UpdateEnergy()
        self:UpdateTick()
        
    elseif event == "UNIT_COMBO_POINTS" or event == "PLAYER_COMBO_POINTS" then
        self:UpdateComboPoints()
        
    elseif event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        self:UpdateComboPoints()
        
    -- Update energy tick rate when talents or stats change
    elseif event == "CHARACTER_POINTS_CHANGED" or (event == "UNIT_STATS" and arg1 == "player") then
        self:UpdateEnergyTickRate()
        
    -- Combat state tracking
    elseif event == "PLAYER_REGEN_DISABLED" then
        isInCombat = true
        self:UpdateTick()
        
    elseif event == "PLAYER_REGEN_ENABLED" then
        isInCombat = false
        self:UpdateTick()
    end
end

-- Slash command handler
function RT:SlashCommand(msg)
    local command = strlower(msg or "")
    
    if command == "toggle" then
        RogueTickerDB.enabled = not RogueTickerDB.enabled
        if RogueTickerDB.enabled then
            mainFrame:Show()
            DEFAULT_CHAT_FRAME:AddMessage("RogueTicker: Enabled")
        else
            mainFrame:Hide()
            DEFAULT_CHAT_FRAME:AddMessage("RogueTicker: Disabled")
        end
        
    elseif command == "lock" then
        RogueTickerDB.locked = not RogueTickerDB.locked
        if mainFrame.resizeHandle then
            if RogueTickerDB.locked then
                mainFrame.resizeHandle:Hide()
            else
                mainFrame.resizeHandle:Show()
            end
        end
        RT:UpdateBackground()
        RT:UpdateComboPoints() -- Update combo points display for preview effect
        if RogueTickerDB.locked then
            DEFAULT_CHAT_FRAME:AddMessage("RogueTicker: Frame locked")
        else
            DEFAULT_CHAT_FRAME:AddMessage("RogueTicker: Frame unlocked (drag to move/resize)")
        end
        
    elseif command == "reset" then
        RogueTickerDB.frameX = 0
        RogueTickerDB.frameY = -100
        RogueTickerDB.frameWidth = 180
        RogueTickerDB.frameHeight = 60
        RogueTickerDB.scale = 1.0
        mainFrame:SetWidth(RogueTickerDB.frameWidth)
        mainFrame:SetHeight(RogueTickerDB.frameHeight)
        mainFrame:SetScale(1.0)
        mainFrame:ClearAllPoints()
        mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -100)
        mainFrame:Show()
        RT:UpdateFrameSizes()
        DEFAULT_CHAT_FRAME:AddMessage("RogueTicker: Position and size reset")
        
    elseif command == "info" or command == "calc" then
        -- Display current energy tick rate calculations
        local baseTickRate = 2.0
        local _, _, _, _, currRank = GetTalentInfo(2, 16)
        local bladeRushRank = currRank or 0
        local agility = UnitStat("player", 2)
        local currentTickRate = GetEnergyTickRate()
        local vigorRank = GetVigorRank()
        local maxEnergy = UnitManaMax("player")
        
        -- Format talent displays
        local bladeRushDisplay
        if bladeRushRank == 0 then
            bladeRushDisplay = "No talent"
        else
            bladeRushDisplay = bladeRushRank .. "/2"
        end
        
        local vigorDisplay
        if vigorRank == 0 then
            vigorDisplay = "No talent"
        else
            vigorDisplay = vigorRank .. "/2"
        end
        
        local energyBonus = vigorRank * 5
        
        DEFAULT_CHAT_FRAME:AddMessage("RogueTicker - Talent Info:")
        DEFAULT_CHAT_FRAME:AddMessage("  Max energy: " .. maxEnergy .. " (Base: 100, Vigor bonus: +" .. energyBonus .. ")")
        DEFAULT_CHAT_FRAME:AddMessage("  Vigor talent: " .. vigorDisplay)
        DEFAULT_CHAT_FRAME:AddMessage("  Base tick rate: " .. baseTickRate .. " seconds")
        DEFAULT_CHAT_FRAME:AddMessage("  Current agility: " .. agility)
        DEFAULT_CHAT_FRAME:AddMessage("  Blade Rush talent: " .. bladeRushDisplay)
        
        if bladeRushRank > 0 then
            local reductionPerAgi = 0.0006 * bladeRushRank
            local totalReduction = agility * reductionPerAgi
            DEFAULT_CHAT_FRAME:AddMessage("  Reduction per agility: " .. string.format("%.4f", reductionPerAgi) .. " seconds")
            DEFAULT_CHAT_FRAME:AddMessage("  Total reduction: " .. string.format("%.3f", totalReduction) .. " seconds")
        else
            DEFAULT_CHAT_FRAME:AddMessage("  No Blade Rush talent - using base rate")
        end
        
        DEFAULT_CHAT_FRAME:AddMessage("  Current tick rate: " .. string.format("%.3f", currentTickRate) .. " seconds")
        
    else
        DEFAULT_CHAT_FRAME:AddMessage("RogueTicker Commands:")
        DEFAULT_CHAT_FRAME:AddMessage("/rt toggle - Enable/disable addon")
        DEFAULT_CHAT_FRAME:AddMessage("/rt lock - Lock/unlock frame (position and resize)")
        DEFAULT_CHAT_FRAME:AddMessage("/rt reset - Reset frame position")
        DEFAULT_CHAT_FRAME:AddMessage("/rt info - Show talent calculations")
    end
end

-- Register events and initialize
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("UNIT_MANA")
eventFrame:RegisterEvent("UNIT_MAXMANA")
eventFrame:RegisterEvent("UNIT_COMBO_POINTS")
eventFrame:RegisterEvent("PLAYER_COMBO_POINTS")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("CHARACTER_POINTS_CHANGED")
eventFrame:RegisterEvent("UNIT_STATS")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function()
    RT:OnEvent(event)
end)

-- Update timer with delta time tracking
local updateFrame = CreateFrame("Frame")
local lastUpdateTime = 0
updateFrame:SetScript("OnUpdate", function()
    local currentTime = GetTime()
    local dt = currentTime - lastUpdateTime
    if lastUpdateTime == 0 then dt = 0.016 end -- Initialize with ~60fps
    lastUpdateTime = currentTime
    RT:OnUpdate(dt)
end)

-- Register slash command
SLASH_ROGUETICKER1 = "/rt"
SLASH_ROGUETICKER2 = "/rogueticker"
SlashCmdList["ROGUETICKER"] = function(msg)
    RT:SlashCommand(msg)
end