--[[
    ConsoleExperienceClassic - Chat Frame Module
    
    Implements ShaguController-style chat frame management:
    - Moves ChatFrameEditBox to top center when visible
    - Scales and repositions ChatFrame1 based on edit box visibility
    - Creates clickable overlay on ChatFrame1 to toggle edit box
    - Hides/repositions chat frame buttons
]]

-- Create chat module namespace
ConsoleExperience.chat = ConsoleExperience.chat or {}
local Chat = ConsoleExperience.chat

-- State tracking
Chat.managePositionsHook = nil
Chat.oskHelper = nil
Chat.initialized = false
Chat.wasDisabled = false
Chat._managePositionsWrapper = nil
Chat._inManagePositions = false
Chat.chatFrameOriginalState = {
    scale = nil,
    points = {},
    color = nil,
    alpha = nil
}
Chat.chatEditBoxOriginalState = {
    strata = nil,
    level = nil,
    saved = false
}

-- Save original chat frame state
function Chat:SaveChatFrameState()
    if not ChatFrame1 then return end
    
    self.chatFrameOriginalState.scale = ChatFrame1:GetScale()
    self.chatFrameOriginalState.points = {}
    
    for i = 1, ChatFrame1:GetNumPoints() do
        local point, relativeTo, relativePoint, x, y = ChatFrame1:GetPoint(i)
        table.insert(self.chatFrameOriginalState.points, {point, relativeTo, relativePoint, x, y})
    end
    
    -- Try to get current color/alpha if functions exist
    if ChatFrame1.GetBackdropColor then
        local r, g, b, a = ChatFrame1:GetBackdropColor()
        self.chatFrameOriginalState.color = {r, g, b, a}
    end
end

-- Restore original chat frame state
function Chat:RestoreChatFrameState()
    if not ChatFrame1 or not self.chatFrameOriginalState.scale then return end
    
    ChatFrame1:SetScale(self.chatFrameOriginalState.scale)
    ChatFrame1:ClearAllPoints()
    
    for _, pointData in ipairs(self.chatFrameOriginalState.points) do
        ChatFrame1:SetPoint(unpack(pointData))
    end
    
    -- Try to restore color, but wrap in pcall to avoid errors if function doesn't exist or has wrong signature
    if self.chatFrameOriginalState.color then
        if FCF_SetWindowColor then
            local success, err = pcall(function()
                FCF_SetWindowColor(ChatFrame1, unpack(self.chatFrameOriginalState.color))
            end)
            if not success then
                CE_Debug("Chat: Failed to restore window color: " .. tostring(err))
            end
        end
    end
    
    -- Try to restore alpha, but wrap in pcall to avoid errors
    if self.chatFrameOriginalState.alpha then
        if FCF_SetWindowAlpha then
            local success, err = pcall(function()
                FCF_SetWindowAlpha(ChatFrame1, self.chatFrameOriginalState.alpha)
            end)
            if not success then
                CE_Debug("Chat: Failed to restore window alpha: " .. tostring(err))
            end
        end
    end
end

-- Save original chat edit box layer state
function Chat:SaveChatEditBoxLayerState()
    if not ChatFrameEditBox or self.chatEditBoxOriginalState.saved then return end

    self.chatEditBoxOriginalState.strata = ChatFrameEditBox:GetFrameStrata()
    self.chatEditBoxOriginalState.level = ChatFrameEditBox:GetFrameLevel()
    self.chatEditBoxOriginalState.saved = true
end

-- Restore original chat edit box layer state
function Chat:RestoreChatEditBoxLayerState()
    if not ChatFrameEditBox or not self.chatEditBoxOriginalState.saved then return end

    if self.chatEditBoxOriginalState.strata then
        ChatFrameEditBox:SetFrameStrata(self.chatEditBoxOriginalState.strata)
    end
    if self.chatEditBoxOriginalState.level then
        ChatFrameEditBox:SetFrameLevel(self.chatEditBoxOriginalState.level)
    end

    self.chatEditBoxOriginalState.saved = false
end

-- Get anchor frame for chat positioning (when edit box is hidden)
function Chat:GetChatAnchor()
    local anchor = MainMenuBarArtFrame
    
    if MultiBarBottomLeft and MultiBarBottomLeft:IsVisible() then
        anchor = MultiBarBottomLeft
    elseif MultiBarBottomRight and MultiBarBottomRight:IsVisible() then
        anchor = MultiBarBottomRight
    elseif ShapeshiftBarFrame and ShapeshiftBarFrame:IsVisible() then
        anchor = ShapeshiftBarFrame
    elseif PetActionBarFrame and PetActionBarFrame:IsVisible() then
        anchor = PetActionBarFrame
    end
    
    return anchor
end

-- Check if chat module is enabled
function Chat:IsEnabled()
    local config = ConsoleExperience.config
    if not config then return true end  -- Default to enabled if config not available
    return config:Get("chatEnabled") ~= false
end

-- Enable chat module
function Chat:Enable()
    if not self:IsEnabled() then
        -- Force enable by setting config
        local config = ConsoleExperience.config
        if config then
            config:Set("chatEnabled", true)
        end
    end
    
    -- Initialize if not already initialized
    if not self.initialized then
        self:Initialize()
        self.initialized = true
    end
    
    -- Restore chat frame state if it was saved
    if self.wasDisabled then
        self.wasDisabled = false
        -- Re-hook into frame management
        if UIParent_ManageFramePositions then
            -- Create a stable wrapper once so we can detect whether we're already hooked
            if not self._managePositionsWrapper then
                self._managePositionsWrapper = function(a1, a2, a3)
                    Chat:ManagePositions(a1, a2, a3)
                end
            end

            -- Only hook if not already hooked to our wrapper
            if UIParent_ManageFramePositions ~= self._managePositionsWrapper then
                self.managePositionsHook = UIParent_ManageFramePositions
                UIParent_ManageFramePositions = self._managePositionsWrapper
            end
        end
        self:UpdateChatLayout()
    end
end

-- Disable chat module
function Chat:Disable()
    CE_Debug("Chat: Disable called")
    
    -- Save state
    self.wasDisabled = true
    self.initialized = false
    
    -- Only restore state if we have saved state (don't restore if never initialized)
    if self.chatFrameOriginalState.scale then
        -- Restore original chat frame state (wrapped in pcall to catch any errors)
        local success, err = pcall(function()
            self:RestoreChatFrameState()
        end)
        if not success then
            CE_Debug("Chat: Error restoring chat frame state: " .. tostring(err))
        end
    end
    
    -- Unhook from frame management
    if self.managePositionsHook then
        -- Only restore if we're currently hooked to our wrapper
        if self._managePositionsWrapper and UIParent_ManageFramePositions == self._managePositionsWrapper then
            UIParent_ManageFramePositions = self.managePositionsHook
        end
        self.managePositionsHook = nil
        CE_Debug("Chat: Unhooked from UIParent_ManageFramePositions")
    end
    
    -- Hide keyboard if visible
    local config = ConsoleExperience.config
    if config then
        config:Set("keyboardEnabled", false)
    end
    if ConsoleExperience.keyboard and ConsoleExperience.keyboard:IsVisible() then
        ConsoleExperience.keyboard:Hide()
    end
    
    -- Hide OSK helper if it exists
    if self.oskHelper then
        self.oskHelper:Hide()
    end

    -- Restore edit box layers if we elevated them
    self:RestoreChatEditBoxLayerState()
    
    CE_Debug("Chat: Disable completed")
end

-- Update chat layout based on action bar positions
-- forceUpdate: if true, update even if edit box is visible (used when transitioning from focused mode)
function Chat:UpdateChatLayout(forceUpdate)
    if not ChatFrame1 then return end
    
    -- Check if chat module is enabled
    if not self:IsEnabled() then
        return
    end
    
    -- Get config values
    local config = ConsoleExperience.config
    if not config then return end
    
    local chatWidth = config:Get("chatWidth") or 400
    local chatHeight = config:Get("chatHeight") or 150
    
    -- Only update if edit box is not visible, unless forced
    if not forceUpdate and ChatFrameEditBox and ChatFrameEditBox:IsVisible() then
        return
    end
    
    -- Calculate chat position (centered at bottom of screen)
    -- Chat should be positioned above visible bars
    local baseChatBottomY = config:Get("chatBottomY") or 20
    local chatGap = 5  -- Gap between chat and bars
    
    -- Check actual bar visibility and get actual heights
    local xpBarVisible = false
    local repBarVisible = false
    local xpBarHeight = 0
    local repBarHeight = 0
    
    if ConsoleExperience.xpbar then
        if ConsoleExperience.xpbar.xpBar then
            xpBarVisible = ConsoleExperience.xpbar.xpBar:IsShown() and ConsoleExperience.xpbar.xpBar:GetAlpha() > 0
            if xpBarVisible then
                xpBarHeight = ConsoleExperience.xpbar.xpBar.height or config:Get("xpBarHeight") or 20
            end
        end
        if ConsoleExperience.xpbar.repBar then
            repBarVisible = ConsoleExperience.xpbar.repBar:IsShown() and ConsoleExperience.xpbar.repBar:GetAlpha() > 0
            if repBarVisible then
                repBarHeight = ConsoleExperience.xpbar.repBar.height or config:Get("repBarHeight") or 20
            end
        end
    end
    
    -- Calculate chat position based on visible bars
    -- REP bar is at bottom (if shown)
    -- XP bar is above REP bar (if REP shown), otherwise below chat
    -- Chat is above XP bar (if XP shown), otherwise at base position
    
    local chatBottomY = baseChatBottomY
    
    if xpBarVisible then
        -- XP bar is visible, chat goes above it
        if repBarVisible then
            -- Both bars: REP at bottom, XP above REP, Chat above XP
            local barGap = 2  -- Gap between XP and REP bars
            -- REP at bottom, XP at repBarHeight + barGap, Chat at repBarHeight + barGap + xpBarHeight + chatGap
            chatBottomY = baseChatBottomY + repBarHeight + barGap + xpBarHeight + chatGap
        else
            -- Only XP bar: XP is positioned below chat, so chat needs to move up to make room
            -- XP bar will be at: chatBottomY - chatGap - xpBarHeight
            -- So chat should be at: baseChatBottomY + xpBarHeight + chatGap
            chatBottomY = baseChatBottomY + xpBarHeight + chatGap
        end
    elseif repBarVisible then
        -- Only REP bar: REP at bottom, Chat above REP
        chatBottomY = baseChatBottomY + repBarHeight + chatGap
    end
    -- If no bars visible, chat stays at baseChatBottomY position
    
    local halfWidth = chatWidth / 2
    
    -- Always restore to configured size and position
    ChatFrame1:SetScale(1)
    ChatFrame1:ClearAllPoints()
    -- Center horizontally using BOTTOM anchor, then set left/right edges relative to center
    ChatFrame1:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", -halfWidth, chatBottomY)
    ChatFrame1:SetPoint("TOPRIGHT", UIParent, "BOTTOM", halfWidth, chatBottomY + chatHeight)
    
    if FCF_SetWindowColor then
        FCF_SetWindowColor(ChatFrame1, 0, 0, 0)
    end
    if FCF_SetWindowAlpha then
        FCF_SetWindowAlpha(ChatFrame1, 0.6)  -- Darker background (0.6 alpha for semi-transparent dark)
    end
end

-- Manage chat frame positions (called from UIParent_ManageFramePositions hook)
function Chat:ManagePositions(a1, a2, a3)
    -- Prevent re-entrant recursion (can happen when chat/layout changes trigger UIParent_ManageFramePositions again)
    if self._inManagePositions then
        if self.managePositionsHook then
            return self.managePositionsHook(a1, a2, a3)
        end
        return
    end
    self._inManagePositions = true

    -- Check if chat module is enabled
    if not self:IsEnabled() then
        -- If disabled, call original function and return
        if self.managePositionsHook then
            local ret = self.managePositionsHook(a1, a2, a3)
            self._inManagePositions = false
            return ret
        end
        self._inManagePositions = false
        return
    end
    -- Run original function first
    if self.managePositionsHook then
        self.managePositionsHook(a1, a2, a3)
    end
    
    -- Save original state if not already saved
    if not self.chatFrameOriginalState.scale then
        self:SaveChatFrameState()
    end
    
    -- Move and resize ChatFrameEditBox
    if ChatFrameEditBox then
        local screenWidth = UIParent:GetWidth()
        ChatFrameEditBox:ClearAllPoints()
        ChatFrameEditBox:SetPoint("TOP", UIParent, "TOP", 0, -10)
        -- Scale edit box width based on screen width (15% of screen width, min 300, max 500)
        local editBoxWidth = math.max(300, math.min(500, screenWidth * 0.15))
        ChatFrameEditBox:SetWidth(editBoxWidth)
        ChatFrameEditBox:SetScale(2)
    end
    
    -- Create on-screen keyboard helper button if it doesn't exist
    if not self.oskHelper then
        self.oskHelper = CreateFrame("Button", nil, UIParent)
        self.oskHelper:SetFrameStrata("BACKGROUND")
        if ChatFrame1 then
            self.oskHelper:SetAllPoints(ChatFrame1)
        end
        self.oskHelper:SetScript("OnClick", function()
            if ChatFrameEditBox and ChatFrameEditBox:IsVisible() then
                ChatFrameEditBox:Hide()
            else
                if ChatFrameEditBox then
                    ChatFrameEditBox:Show()
                    ChatFrameEditBox:Raise()
                end
            end
        end)
        self.oskHelper.state = 0
        
        -- Set up OnUpdate script once
        local helper = self.oskHelper
        helper:SetScript("OnUpdate", function()
            -- Check if chat module is enabled
            if not Chat:IsEnabled() then
                helper.state = 0
                return
            end
            
            if ChatFrameEditBox and ChatFrameEditBox:IsVisible() and helper.state ~= 1 then
                -- Edit box is visible - show full-screen chat (focused mode)
                if ChatFrame1 then
                    ChatFrame1:Show()
                    ChatFrame1:ClearAllPoints()
                    local screenHeight = UIParent:GetHeight()
                    local screenWidth = UIParent:GetWidth()
                    local chatHeight = screenHeight * 0.48  -- Use 48% of screen height
                    -- Edit box is at -10 from top, scaled 2x (height ~30px * 2 = 60px)
                    -- Scale offset based on screen height (roughly 9% of screen height, min 80px, max 120px)
                    local editBoxOffset = math.max(80, math.min(120, screenHeight * 0.09))
                    
                    -- Ensure chat frame is visible and on top BEFORE positioning
                    ChatFrame1:SetFrameStrata("DIALOG")
                    ChatFrame1:SetFrameLevel(100)
                    ChatFrame1:SetAlpha(1.0)

                    -- Keep edit box above focused chat messages
                    self:SaveChatEditBoxLayerState()
                    ChatFrameEditBox:SetFrameStrata("DIALOG")
                    ChatFrameEditBox:SetFrameLevel(ChatFrame1:GetFrameLevel() + 20)
                    ChatFrameEditBox:Raise()
                    
                    -- Position from top, starting BELOW the edit box
                    -- Top edge starts below edit box, bottom edge at editBoxOffset + chatHeight from top
                    ChatFrame1:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -editBoxOffset)
                    ChatFrame1:SetPoint("BOTTOMRIGHT", UIParent, "TOPRIGHT", -10, -(editBoxOffset + chatHeight))
                    
                    -- Don't use scale - it makes the frame take more space than intended
                    -- ChatFrame1:SetScale(1.5)
                    
                    if FCF_SetWindowColor then
                        FCF_SetWindowColor(ChatFrame1, 0, 0, 0)
                    end
                    if FCF_SetWindowAlpha then
                        FCF_SetWindowAlpha(ChatFrame1, 0.7)  -- Reduced alpha so it's not too dark
                    end
                    
                    -- Disable fading so messages stay visible
                    if ChatFrame1.SetFadeDuration then
                        ChatFrame1:SetFadeDuration(0)
                    end
                    if ChatFrame1.SetFading then
                        ChatFrame1:SetFading(false)
                    end
                    
                    -- Scroll to bottom
                    if ChatFrame1.ScrollToBottom then
                        ChatFrame1:ScrollToBottom()
                    end
                end
                
                -- Show keyboard when edit box becomes visible (if enabled)
                local config = ConsoleExperience.config
                if config and config:Get("keyboardEnabled") then
                    if ConsoleExperience.keyboard and not ConsoleExperience.keyboard:IsVisible() then
                        ConsoleExperience.keyboard:Show()
                    end
                end
                
                helper.state = 1
            elseif (not ChatFrameEditBox or not ChatFrameEditBox:IsVisible()) and helper.state ~= 0 then
                -- Edit box is hidden - return to configured chat position and size (unfocused mode)
                -- Restore strata and frame level to normal (was set to DIALOG/100 when focused)
                if ChatFrame1 then
                    ChatFrame1:SetFrameStrata("BACKGROUND")
                    ChatFrame1:SetFrameLevel(1)
                end
                self:RestoreChatEditBoxLayerState()
                
                -- Force update to ensure we restore the configured layout
                self:UpdateChatLayout(true)
                
                -- Don't hide keyboard here - keyboard handles its own visibility via UISpecialFrames
                -- Keyboard will hide itself when Escape is pressed or when ChatFrameEditBox is hidden via its OnHide hook
                
                helper.state = 0
            end
        end)
    end
    
    -- Update helper button to cover ChatFrame1
    if ChatFrame1 and self.oskHelper then
        self.oskHelper:ClearAllPoints()
        self.oskHelper:SetAllPoints(ChatFrame1)
    end
    
    -- Update chat layout if edit box is not visible
    if not ChatFrameEditBox or not ChatFrameEditBox:IsVisible() then
        self:UpdateChatLayout()
    end
    
    -- Move and hide some chat buttons
    if ChatFrameMenuButton then
        ChatFrameMenuButton:Hide()
        ChatFrameMenuButton.Show = function() return end
    end
    
    -- Reposition scroll buttons for all chat windows
    for i = 1, NUM_CHAT_WINDOWS do
        local downButton = _G["ChatFrame"..i.."DownButton"]
        local upButton = _G["ChatFrame"..i.."UpButton"]
        local bottomButton = _G["ChatFrame"..i.."BottomButton"]
        
        if downButton then
            downButton:ClearAllPoints()
            downButton:SetPoint("BOTTOMRIGHT", _G["ChatFrame"..i], "BOTTOMRIGHT", 0, -5)
        end
        
        if upButton then
            upButton:ClearAllPoints()
            upButton:SetPoint("RIGHT", downButton, "LEFT", 0, 0)
        end
        
        if bottomButton then
            bottomButton:Hide()
            bottomButton.Show = function() return end
        end
    end

    self._inManagePositions = false
end

-- Initialize the chat module
function Chat:Initialize()
    -- Check if chat module is enabled
    if not self:IsEnabled() then
        CE_Debug("Chat frame module initialization skipped (disabled)")
        return
    end
    
    CE_Debug("Chat: Initialize called, chatEnabled=" .. tostring(self:IsEnabled()))
    
    -- Function to actually initialize the hooks
    local function DoInitialize()
        -- Check again if enabled (config might have changed)
        if not self:IsEnabled() then
            CE_Debug("Chat: DoInitialize skipped - chat not enabled")
            return
        end
        
        CE_Debug("Chat: DoInitialize starting")
        
        -- Hook into UIParent_ManageFramePositions
        if UIParent_ManageFramePositions then
            -- Create a stable wrapper once so we can detect whether we're already hooked
            if not self._managePositionsWrapper then
                self._managePositionsWrapper = function(a1, a2, a3)
                    Chat:ManagePositions(a1, a2, a3)
                end
            end

            -- Only hook if not already hooked to our wrapper
            if UIParent_ManageFramePositions ~= self._managePositionsWrapper then
                self.managePositionsHook = UIParent_ManageFramePositions
                UIParent_ManageFramePositions = self._managePositionsWrapper
                CE_Debug("Chat: Hooked into UIParent_ManageFramePositions")
            else
                CE_Debug("Chat: Already hooked, skipping hook setup")
            end
        else
            CE_Debug("Chat: UIParent_ManageFramePositions not available")
        end
        
        -- Trigger initial position update
        if UIParent_ManageFramePositions then
            UIParent_ManageFramePositions()
        end
        
        -- Update chat layout after action bars are positioned
        self:UpdateChatLayout()
        CE_Debug("Chat: DoInitialize completed")
    end
    
    -- Check if we're already in the world (e.g., after reload)
    if UnitName("player") then
        -- Already in world, initialize immediately
        DoInitialize()
    else
        -- Wait for PLAYER_ENTERING_WORLD to hook into frame management
        local initFrame = CreateFrame("Frame")
        initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        initFrame:SetScript("OnEvent", function()
            DoInitialize()
            initFrame:UnregisterAllEvents()
        end)
    end
    
    -- Also set up a one-time update frame (for cases where we need a small delay)
    -- This ensures the layout is updated even if DoInitialize runs before frames are ready
    local updateFrame = CreateFrame("Frame")
    updateFrame:SetScript("OnUpdate", function()
        -- Check if enabled
        if not self:IsEnabled() then
            updateFrame:Hide()
            return
        end
        
        -- Only run once
        if updateFrame.executed then
            return
        end
        updateFrame.executed = true
        
        -- Small delay to ensure everything is ready
        updateFrame.elapsed = (updateFrame.elapsed or 0) + arg1
        if updateFrame.elapsed < 0.1 then
            return
        end
        
        if UIParent_ManageFramePositions then
            UIParent_ManageFramePositions()
        end
        -- Update chat layout
        self:UpdateChatLayout()
        updateFrame:Hide()
        CE_Debug("Chat: OnUpdate frame executed")
    end)
    updateFrame:Show()
    
    self.initialized = true
    CE_Debug("Chat frame module initialized")
end
