--[[
    ConsoleExperienceClassic
    A controller-style action bar for WoW 1.12
    
    Main entry point - creates the ConsoleExperience global frame
    that other modules attach to.
]]

_G = getfenv(0)

-- Create the main addon frame
ConsoleExperience = CreateFrame("Frame", nil, UIParent)
ConsoleExperience:RegisterEvent("ADDON_LOADED")
ConsoleExperience:RegisterEvent("VARIABLES_LOADED")
ConsoleExperience:RegisterEvent("PLAYER_ENTERING_WORLD")
ConsoleExperience:RegisterEvent("PLAYER_LOGOUT")

-- Configuration storage (saved variables)
ConsoleExperienceDB = ConsoleExperienceDB or {}

ConsoleExperience:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" then
        -- Check if pfUI just loaded
        if arg1 == "pfUI" then
            -- pfUI loaded, disable chat module if not already disabled
            if ConsoleExperience.config then
                local currentValue = ConsoleExperience.config:Get("chatEnabled")
                if currentValue ~= false then
                    ConsoleExperience.config:Set("chatEnabled", false)
                    CE_Debug("pfUI detected on ADDON_LOADED - chat module automatically disabled")
                    -- If chat module is already initialized, disable it now
                    if ConsoleExperience.chat and ConsoleExperience.chat.Disable then
                        ConsoleExperience.chat:Disable()
                    end
                end
            end
        end
        
        if arg1 == "ConsoleExperienceClassic" then
            -- Initialize configuration if it doesn't exist
            if ConsoleExperienceDB == nil then
                ConsoleExperienceDB = {}
            end
            
-- Addon loaded message (always show)
        end
        
    elseif event == "VARIABLES_LOADED" then
        -- Initialize config DB with defaults
        if ConsoleExperience.config and ConsoleExperience.config.InitializeDB then
            ConsoleExperience.config:InitializeDB()
        end
        
        -- Initialize action bars after saved variables are loaded
        if ConsoleExperience.actionbars and ConsoleExperience.actionbars.Initialize then
            ConsoleExperience.actionbars:Initialize()
        end
        
        -- Initialize auto spell rank module
        if ConsoleExperience.autorank and ConsoleExperience.autorank.Initialize then
            ConsoleExperience.autorank:Initialize()
        end
        
        -- Initialize cursor tooltip module
        if ConsoleExperience.cursor and ConsoleExperience.cursor.tooltip and ConsoleExperience.cursor.tooltip.Initialize then
            ConsoleExperience.cursor.tooltip:Initialize()
        end
        
        -- Initialize frame hooks for cursor navigation
        if ConsoleExperience.hooks and ConsoleExperience.hooks.Initialize then
            ConsoleExperience.hooks:Initialize()
        end
        
        -- Initialize radial menu
        if ConsoleExperience.radial and ConsoleExperience.radial.Initialize then
            ConsoleExperience.radial:Initialize()
        end
        
        -- Initialize placement frame
        if ConsoleExperience.placement and ConsoleExperience.placement.Initialize then
            ConsoleExperience.placement:Initialize()
        end
        
        -- Initialize chat frame module
        -- Initialize chat module only if enabled
        if ConsoleExperience.chat then
            local config = ConsoleExperience.config
            if config and config:Get("chatEnabled") ~= false then
                if ConsoleExperience.chat.Initialize then
                    ConsoleExperience.chat:Initialize()
                end
            else
                -- Chat is disabled, call Disable to ensure clean state
                if ConsoleExperience.chat.Disable then
                    ConsoleExperience.chat:Disable()
                end
            end
        end
        
        -- Initialize keyboard module
        if ConsoleExperience.keyboard and ConsoleExperience.keyboard.Initialize then
            ConsoleExperience.keyboard:Initialize()
        end
        
        -- Initialize XP/Rep bar module
        if ConsoleExperience.xpbar and ConsoleExperience.xpbar.Initialize then
            ConsoleExperience.xpbar:Initialize()
        end
        
        -- Initialize cast bar module
        if ConsoleExperience.castbar and ConsoleExperience.castbar.Initialize then
            ConsoleExperience.castbar:Initialize()
        end
        
        CE_Debug("ConsoleExperience loaded!")
        
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Re-initialize action bars on zone changes/reloads
        if ConsoleExperience.actionbars and ConsoleExperience.actionbars.OnPlayerEnteringWorld then
            ConsoleExperience.actionbars:OnPlayerEnteringWorld()
        end
        
        -- Setup keybindings on PLAYER_ENTERING_WORLD (later than VARIABLES_LOADED)
        -- Only run once, not on every zone change
        if not ConsoleExperience.keybindingsInitialized then
            ConsoleExperience.keybindingsInitialized = true
            if ConsoleExperience.keybindings and ConsoleExperience.keybindings.Initialize then
                ConsoleExperience.keybindings:Initialize()
            end
        end
        
    elseif event == "PLAYER_LOGOUT" then
        -- Save configuration
        ConsoleExperienceDB = ConsoleExperienceDB
    end
end)

-- Debug function - only prints if debug is enabled in config
function ConsoleExperience:Debug(msg)
    if self.config and self.config:Get("debugEnabled") then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff9900[CE]|r " .. tostring(msg))
    end
end

-- Global shortcut for debug
function CE_Debug(msg)
    if ConsoleExperience.config and ConsoleExperience.config:Get("debugEnabled") then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff9900[CE]|r " .. tostring(msg))
    end
end

-- Print function - always prints (for important messages)
function ConsoleExperience:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[CE]|r " .. tostring(msg))
end

function CE_Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[CE]|r " .. tostring(msg))
end

-- Debug slash command to get frame name under mouse
SLASH_CEFRAME1 = "/ceframe"
SlashCmdList["CEFRAME"] = function(msg)
    local frame = GetMouseFocus()
    if frame then
        local name = frame:GetName() or "(unnamed)"
        local objType = frame:GetObjectType() or "unknown"
        local parent = frame:GetParent()
        local parentName = parent and (parent:GetName() or "(unnamed parent)") or "none"
        
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[CE Frame]|r")
        DEFAULT_CHAT_FRAME:AddMessage("  Name: |cffffcc00" .. name .. "|r")
        DEFAULT_CHAT_FRAME:AddMessage("  Type: |cff88ccff" .. objType .. "|r")
        DEFAULT_CHAT_FRAME:AddMessage("  Parent: |cffcccccc" .. parentName .. "|r")
        
        -- Try to get texture info
        local textureInfo = nil
        
        -- If frame itself is a texture
        if frame.GetTexture and frame:GetTexture() then
            textureInfo = frame:GetTexture()
        end
        
        -- Try to find textures in common child elements
        if not textureInfo then
            -- Check for icon texture (common in buttons)
            local iconName = name and (name .. "Icon")
            local iconTex = iconName and getglobal(iconName)
            if iconTex and iconTex.GetTexture then
                textureInfo = iconTex:GetTexture()
            end
        end
        
        if not textureInfo then
            -- Check NormalTexture (buttons)
            if frame.GetNormalTexture then
                local normalTex = frame:GetNormalTexture()
                if normalTex and normalTex.GetTexture then
                    textureInfo = normalTex:GetTexture()
                end
            end
        end
        
        if not textureInfo then
            -- Scan all regions for textures
            local regions = { frame:GetRegions() }
            for _, region in ipairs(regions) do
                if region and region:GetObjectType() == "Texture" and region.GetTexture then
                    local tex = region:GetTexture()
                    if tex and tex ~= "" then
                        textureInfo = tex
                        break
                    end
                end
            end
        end
        
        if textureInfo then
            DEFAULT_CHAT_FRAME:AddMessage("  Texture: |cff88ff88" .. tostring(textureInfo) .. "|r")
        else
            DEFAULT_CHAT_FRAME:AddMessage("  Texture: |cff888888(none found)|r")
        end
        
        -- Also show in a popup for easy copying
        if msg == "copy" then
            -- Create a simple editbox for copying
            if not CE_FrameCopyBox then
                local f = CreateFrame("Frame", "CE_FrameCopyBox", UIParent)
                f:SetWidth(300)
                f:SetHeight(50)
                f:SetPoint("CENTER")
                f:SetFrameStrata("DIALOG")
                f:SetBackdrop({
                    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                    tile = true, tileSize = 32, edgeSize = 16,
                    insets = { left = 5, right = 5, top = 5, bottom = 5 }
                })
                f:EnableMouse(true)
                
                local eb = CreateFrame("EditBox", nil, f)
                eb:SetPoint("TOPLEFT", 10, -10)
                eb:SetPoint("BOTTOMRIGHT", -10, 10)
                eb:SetFontObject(GameFontNormal)
                eb:SetAutoFocus(true)
                eb:SetScript("OnEscapePressed", function() f:Hide() end)
                f.editBox = eb
            end
            local copyText = textureInfo or name
            CE_FrameCopyBox.editBox:SetText(copyText)
            CE_FrameCopyBox.editBox:HighlightText()
            CE_FrameCopyBox:Show()
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[CE Frame]|r No frame under mouse")
    end
end
