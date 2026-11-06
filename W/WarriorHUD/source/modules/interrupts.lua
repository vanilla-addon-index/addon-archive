if UnitClass("player") == "Warrior" then

-- Interrupt Detection Module - Enhanced with SuperWoW/UnitXP_SP3 support
local _G = getfenv(0)
local editmode = false
local WHUD_INTERRUPT_FRAME = nil
local WHUD_INTERRUPT_TEXT = nil
local WHUD_INTERRUPT_ICON = nil
local WHUD_INTERRUPT_TIMER = nil
local lastInterruptCheck = 0

function WHUD_Interrupts_Init()
    -- Only create if we have enhanced features
    if WHUD_GetEnhancementStatus then
        local status = WHUD_GetEnhancementStatus()
        if status.features.castDetection then
            CreateInterruptFrames()
            WHUD_Interrupts_VarUpdate()
            DEFAULT_CHAT_FRAME:AddMessage("|cff8f4108WarriorHUD|r: Interrupt detection enabled (SuperWoW detected)")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff8f4108WarriorHUD|r: Interrupt detection disabled (requires SuperWoW)")
        end
    end
end

function CreateInterruptFrames()
    -- Main interrupt warning frame
    WHUD_INTERRUPT_FRAME = CreateFrame("Frame", "WHUD_INTERRUPT", UIParent)
    WHUD_INTERRUPT_FRAME:SetWidth(300)
    WHUD_INTERRUPT_FRAME:SetHeight(60)
    WHUD_INTERRUPT_FRAME:SetFrameStrata("HIGH")
    WHUD_INTERRUPT_FRAME:SetAlpha(0.9)
    WHUD_INTERRUPT_FRAME:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
    
    -- Background
    WHUD_INTERRUPT_FRAME:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Background",
        edgeFile = "Interface\\AddOns\\WarriorHUD\\textures\\border.tga",
        tile = false, tileSize = 0, edgeSize = 2,
        insets = {left = 2, right = 2, top = 2, bottom = 2}
    })
    WHUD_INTERRUPT_FRAME:SetBackdropColor(0.8, 0.2, 0.2, 0.8)
    WHUD_INTERRUPT_FRAME:SetBackdropBorderColor(1, 1, 0, 1)
    
    -- Interrupt text
    WHUD_INTERRUPT_TEXT = WHUD_INTERRUPT_FRAME:CreateFontString(nil, "OVERLAY")
    WHUD_INTERRUPT_TEXT:SetParent(WHUD_INTERRUPT_FRAME)
    WHUD_INTERRUPT_TEXT:SetFont("Interface\\AddOns\\WarriorHUD\\fonts\\Myriad-Pro.ttf", 16, "OUTLINE")
    WHUD_INTERRUPT_TEXT:SetPoint("CENTER", WHUD_INTERRUPT_FRAME, "CENTER", 0, 8)
    WHUD_INTERRUPT_TEXT:SetJustifyH("CENTER")
    WHUD_INTERRUPT_TEXT:SetVertexColor(1, 1, 1)
    
    -- Timer text
    WHUD_INTERRUPT_TIMER = WHUD_INTERRUPT_FRAME:CreateFontString(nil, "OVERLAY")
    WHUD_INTERRUPT_TIMER:SetParent(WHUD_INTERRUPT_FRAME)
    WHUD_INTERRUPT_TIMER:SetFont("Interface\\AddOns\\WarriorHUD\\fonts\\Myriad-Pro.ttf", 12, "OUTLINE")
    WHUD_INTERRUPT_TIMER:SetPoint("CENTER", WHUD_INTERRUPT_FRAME, "CENTER", 0, -12)
    WHUD_INTERRUPT_TIMER:SetJustifyH("CENTER")
    WHUD_INTERRUPT_TIMER:SetVertexColor(1, 1, 0)
    
    -- Spell icon
    WHUD_INTERRUPT_ICON = WHUD_INTERRUPT_FRAME:CreateTexture("WHUD_INTERRUPT_ICON", "ARTWORK")
    WHUD_INTERRUPT_ICON:SetWidth(32)
    WHUD_INTERRUPT_ICON:SetHeight(32)
    WHUD_INTERRUPT_ICON:SetPoint("LEFT", WHUD_INTERRUPT_FRAME, "LEFT", 8, 0)
    
    WHUD_INTERRUPT_FRAME:Hide()
end

function WHUD_Interrupts_OnUpdate()
    if not WHUD_INTERRUPT_FRAME then return end
    
    -- Throttle checks to every 0.1 seconds
    local currentTime = GetTime()
    if currentTime - lastInterruptCheck < 0.1 then
        return
    end
    lastInterruptCheck = currentTime
    
    if not editmode and UnitExists("target") and UnitCanAttack("player", "target") then
        local opportunity = WHUD_GetInterruptOpportunities and WHUD_GetInterruptOpportunities()
        
        if opportunity and opportunity.canInterrupt then
            -- Show interrupt warning
            WHUD_INTERRUPT_TEXT:SetText("INTERRUPT: " .. opportunity.spell)
            WHUD_INTERRUPT_TIMER:SetText(string.format("%.1fs remaining", opportunity.timeLeft))
            
            -- Set spell icon if available
            local spellTexture = GetSpellTexture(opportunity.spell)
            if spellTexture then
                WHUD_INTERRUPT_ICON:SetTexture(spellTexture)
                WHUD_INTERRUPT_ICON:Show()
            else
                WHUD_INTERRUPT_ICON:Hide()
            end
            
            -- Color coding based on urgency
            if opportunity.timeLeft <= 1 then
                WHUD_INTERRUPT_FRAME:SetBackdropColor(1, 0, 0, 0.9) -- Red - urgent
                WHUD_INTERRUPT_TIMER:SetVertexColor(1, 0, 0)
            elseif opportunity.timeLeft <= 2 then
                WHUD_INTERRUPT_FRAME:SetBackdropColor(1, 0.5, 0, 0.8) -- Orange - warning
                WHUD_INTERRUPT_TIMER:SetVertexColor(1, 0.5, 0)
            else
                WHUD_INTERRUPT_FRAME:SetBackdropColor(0.8, 0.2, 0.2, 0.8) -- Default red
                WHUD_INTERRUPT_TIMER:SetVertexColor(1, 1, 0)
            end
            
            if not WHUD_INTERRUPT_FRAME:IsVisible() then
                WHUD_INTERRUPT_FRAME:Show()
            end
        else
            -- Hide interrupt warning
            if WHUD_INTERRUPT_FRAME:IsVisible() then
                WHUD_INTERRUPT_FRAME:Hide()
            end
        end
    else
        -- No valid target or not attackable
        if WHUD_INTERRUPT_FRAME:IsVisible() then
            WHUD_INTERRUPT_FRAME:Hide()
        end
    end
end

function WHUD_Interrupts_VarUpdate()
    if WHUD_INTERRUPT_FRAME then
        -- Update position and appearance based on variables
        -- For now, use a static position - could be made configurable
        WHUD_INTERRUPT_FRAME:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
        WHUD_INTERRUPT_FRAME:SetAlpha(0.9)
    end
end

function WHUD_Interrupts_EditMode(t)
    if not WHUD_INTERRUPT_FRAME then return end
    
    if t == 0 then
        editmode = false
        WHUD_INTERRUPT_FRAME:Hide()
    else
        editmode = true
        WHUD_INTERRUPT_TEXT:SetText("INTERRUPT: Fireball")
        WHUD_INTERRUPT_TIMER:SetText("2.3s remaining")
        WHUD_INTERRUPT_ICON:SetTexture("Interface\\Icons\\Spell_Fire_FlameBolt")
        WHUD_INTERRUPT_ICON:Show()
        WHUD_INTERRUPT_FRAME:Show()
    end
end

-- Status check function
function WHUD_Interrupts_IsAvailable()
    if WHUD_GetEnhancementStatus then
        local status = WHUD_GetEnhancementStatus()
        return status.features.castDetection
    end
    return false
end

-- Get available interrupt abilities
function WHUD_GetAvailableInterrupts()
    local interrupts = {}
    
    -- Check if player has interrupt abilities available
    if WHUD_SPELLINFO and WHUD_SPELLINFO["Shield Bash"] and WHUD_SPELLINFO["Shield Bash"][1] > 0 then
        local start, duration = GetSpellCooldown(WHUD_SPELLINFO["Shield Bash"][1], "BOOKTYPE_SPELL")
        if start == 0 then -- Not on cooldown
            table.insert(interrupts, {name = "Shield Bash", range = 5, cooldown = 0})
        end
    end
    
    if WHUD_SPELLINFO and WHUD_SPELLINFO["Pummel"] and WHUD_SPELLINFO["Pummel"][1] > 0 then
        local start, duration = GetSpellCooldown(WHUD_SPELLINFO["Pummel"][1], "BOOKTYPE_SPELL")
        if start == 0 then -- Not on cooldown
            table.insert(interrupts, {name = "Pummel", range = 5, cooldown = 0})
        end
    end
    
    return interrupts
end

end
