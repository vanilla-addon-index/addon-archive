if UnitClass("player") == "Warrior" then

-- Enhancement Detection and Compatibility Layer
local _G = getfenv(0)

-- Detection flags
local HAS_SUPERWOW = false
local HAS_UNITXP = false
local ENHANCEMENT_VERSION = "1.0"

-- Initialize enhancement detection
function WHUD_Enhancements_Init()
    -- Detect SuperWoW
    if SuperWoW_GetVersion then
        HAS_SUPERWOW = true
        DEFAULT_CHAT_FRAME:AddMessage("|cff8f4108WarriorHUD|r: SuperWoW detected - Enhanced features enabled")
    end
    
    -- Detect UnitXP_SP3
    if UnitXP_GetDistance then
        HAS_UNITXP = true
        DEFAULT_CHAT_FRAME:AddMessage("|cff8f4108WarriorHUD|r: UnitXP_SP3 detected - Enhanced features enabled")
    end
    
    if not HAS_SUPERWOW and not HAS_UNITXP then
        DEFAULT_CHAT_FRAME:AddMessage("|cff8f4108WarriorHUD|r: Standard mode - Consider SuperWoW or UnitXP_SP3 for enhanced features")
    end
end

-- Enhanced Distance Checking (UnitXP_SP3 > fallback)
function WHUD_GetTargetDistance()
    if HAS_UNITXP and UnitXP_GetDistance then
        return UnitXP_GetDistance("target")
    else
        -- Fallback: Basic range estimation using spell ranges
        if CheckInteractDistance("target", 3) then
            return 5 -- Melee range
        elseif CheckInteractDistance("target", 2) then
            return 15 -- Medium range
        else
            return 25 -- Long range estimate
        end
    end
end

-- Enhanced Line of Sight (UnitXP_SP3 > fallback)
function WHUD_HasLineOfSight()
    if HAS_UNITXP and UnitXP_CheckLineOfSight then
        return UnitXP_CheckLineOfSight("target")
    else
        -- Fallback: Assume line of sight if target exists and is visible
        return UnitExists("target") and UnitIsVisible("target")
    end
end

-- Enhanced Position Checking (UnitXP_SP3)
function WHUD_IsPlayerBehindTarget()
    if HAS_UNITXP and UnitXP_IsPlayerBehindMob then
        return UnitXP_IsPlayerBehindMob("target")
    else
        -- Fallback: Cannot determine, return false
        return false
    end
end

-- Enhanced Target GUID (SuperWoW > fallback)
function WHUD_GetTargetGUID()
    if HAS_SUPERWOW and SuperWoW_GetTargetGUID then
        return SuperWoW_GetTargetGUID()
    else
        -- Fallback: Use target name (less reliable)
        return UnitName("target")
    end
end

-- Enhanced Cast Information (SuperWoW > fallback)
function WHUD_GetTargetCastInfo()
    if HAS_SUPERWOW and SuperWoW_GetCastInfo then
        return SuperWoW_GetCastInfo("target")
    else
        -- Fallback: No cast information available
        return nil, nil, nil, nil, nil, nil
    end
end

-- Enhanced Timer Functions (UnitXP_SP3 > fallback)
function WHUD_GetPreciseTime()
    if HAS_UNITXP and UnitXP_GetPreciseTime then
        return UnitXP_GetPreciseTime()
    else
        -- Fallback: Standard GetTime()
        return GetTime()
    end
end

-- Enhanced Combat Event Detection
function WHUD_ParseCombatEvent(arg1)
    local eventData = {
        isEnhanced = HAS_SUPERWOW or HAS_UNITXP,
        targetGUID = WHUD_GetTargetGUID(),
        distance = WHUD_GetTargetDistance(),
        hasLOS = WHUD_HasLineOfSight(),
        isBehind = WHUD_IsPlayerBehindTarget(),
        timestamp = WHUD_GetPreciseTime(),
        rawMessage = arg1
    }
    return eventData
end

-- Enhanced Ability Range Checking
function WHUD_IsAbilityInRange(abilityName)
    local distance = WHUD_GetTargetDistance()
    local hasLOS = WHUD_HasLineOfSight()
    
    -- Return false if no line of sight
    if not hasLOS then
        return false
    end
    
    -- Check specific ability ranges
    if abilityName == "Execute" or abilityName == "Overpower" then
        return distance <= 5 -- Melee range
    elseif abilityName == "Charge" then
        return distance >= 8 and distance <= 25
    elseif abilityName == "Intercept" then
        return distance >= 8 and distance <= 25
    elseif abilityName == "Taunt" then
        return distance <= 30
    else
        -- Default melee abilities
        return distance <= 5
    end
end

-- Enhanced Multi-Target Tracking
WHUD_ENHANCED_TARGETS = {}

function WHUD_UpdateTargetTracking()
    if not (HAS_SUPERWOW or HAS_UNITXP) then
        return -- No enhanced tracking without mods
    end
    
    -- Clear old data
    WHUD_ENHANCED_TARGETS = {}
    
    -- Track current target
    if UnitExists("target") then
        local targetGUID = WHUD_GetTargetGUID()
        WHUD_ENHANCED_TARGETS[targetGUID] = {
            name = UnitName("target"),
            distance = WHUD_GetTargetDistance(),
            health = UnitHealth("target"),
            maxHealth = UnitHealthMax("target"),
            level = UnitLevel("target"),
            timestamp = WHUD_GetPreciseTime()
        }
    end
end

-- Enhanced Execute Range Detection
function WHUD_GetExecuteTargets()
    local executeTargets = {}
    
    -- Enhanced multi-target execute detection
    if HAS_SUPERWOW or HAS_UNITXP then
        for guid, data in pairs(WHUD_ENHANCED_TARGETS) do
            local healthPercent = (data.health / data.maxHealth) * 100
            if healthPercent <= 20 and data.distance <= 5 then
                table.insert(executeTargets, data.name)
            end
        end
    else
        -- Fallback: Only current target
        if UnitExists("target") then
            local healthPercent = (UnitHealth("target") / UnitHealthMax("target")) * 100
            if healthPercent <= 20 and WHUD_GetTargetDistance() <= 5 then
                table.insert(executeTargets, UnitName("target"))
            end
        end
    end
    
    return executeTargets
end

-- Enhanced Overpower Opportunity Detection
function WHUD_Enhanced_Overpower_OnEvent(arg1)
    local eventData = WHUD_ParseCombatEvent(arg1)
    
    -- More precise dodge detection with enhanced data
    if eventData.targetGUID and eventData.distance <= 5 and eventData.hasLOS then
        if (arg1 == string.format(VSDODGESELFOTHER, UnitName("target"))) or 
           (string.find(arg1,"Your") and string.find(arg1,"was dodged by "..UnitName("target"))) then
            
            -- Enhanced overpower tracking
            WHUD_OP_TIME = eventData.timestamp + 4
            
            -- Store enhanced data for this opportunity
            WHUD_OP_ENHANCED_DATA = {
                targetGUID = eventData.targetGUID,
                distance = eventData.distance,
                timestamp = eventData.timestamp,
                isBehind = eventData.isBehind
            }
            
            return true
        end
    end
    
    return false
end

-- Enhanced Interrupt Detection
function WHUD_GetInterruptOpportunities()
    local spell, rank, displayName, icon, startTime, endTime = WHUD_GetTargetCastInfo()
    
    if spell and startTime and endTime then
        local castTime = endTime - startTime
        local timeLeft = endTime - WHUD_GetPreciseTime()
        local distance = WHUD_GetTargetDistance()
        
        return {
            spell = spell,
            timeLeft = timeLeft,
            canInterrupt = distance <= 5 and timeLeft > 0.5, -- Give 0.5s buffer
            interruptAbilities = {"Shield Bash", "Pummel"}
        }
    end
    
    return nil
end

-- Enhancement Status Check
function WHUD_GetEnhancementStatus()
    return {
        hasSuperwow = HAS_SUPERWOW,
        hasUnitXP = HAS_UNITXP,
        version = ENHANCEMENT_VERSION,
        features = {
            preciseDistance = HAS_UNITXP,
            lineOfSight = HAS_UNITXP,
            positionDetection = HAS_UNITXP,
            combatGUIDs = HAS_SUPERWOW,
            castDetection = HAS_SUPERWOW,
            multiTarget = HAS_SUPERWOW or HAS_UNITXP
        }
    }
end

end
