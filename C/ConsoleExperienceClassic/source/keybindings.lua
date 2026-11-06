-- Get localized text (with fallback)
local function L(key)
    if ConsoleExperience.locale and ConsoleExperience.locale.T then
        return ConsoleExperience.locale.T(key)
    end
    return key
end

--[[
    ConsoleExperienceClassic - Keybindings Module
    
    Handles keybindings like pfUI does:
    - Creates binding names dynamically with _G["BINDING_NAME_..."]
    - Overrides ActionButtonDown/Up to redirect to our buttons
    - Uses runOnUp="true" in Bindings.xml
    
    40 action slots mapped to keys:
    - Actions 1-10: No modifier (keys 1-0)
    - Actions 11-20: Shift (Shift+1-0)
    - Actions 21-30: Ctrl (Ctrl+1-0)
    - Actions 31-40: Ctrl+Shift (Ctrl+Shift+1-0)
]]

-- ============================================================================
-- Create Binding Names Dynamically (like pfUI does)
-- ============================================================================

-- Binding header
_G["BINDING_HEADER_CONSOLEEXPERIENCE"] = L("Console Experience")
_G["BINDING_HEADER_CELEFTBAR"] = L("CE Left Touch Bar")
_G["BINDING_HEADER_CERIGHTBAR"] = L("CE Right Touch Bar")

-- Controller button names for each position (1-10)
local buttonNames = {
    [1] = "A",
    [2] = "X",
    [3] = "Y",
    [4] = "B",
    [5] = L("Down"),
    [6] = L("Left"),
    [7] = L("Up"),
    [8] = L("Right"),
    [9] = "RB",
    [10] = "LB",
}

-- Modifier prefixes for each page
local modifierPrefixes = {
    [1] = "",           -- 1-10: No modifier
    [2] = "LT + ",      -- 11-20: Shift = LT
    [3] = "RT + ",      -- 21-30: Ctrl = RT
    [4] = "LT + RT + ", -- 31-40: Shift+Ctrl = LT + RT
}

-- Create all 40 binding names with controller button combos
for i = 1, 40 do
    local page = math.floor((i - 1) / 10) + 1
    local buttonIndex = math.mod(i - 1, 10) + 1
    local buttonName = buttonNames[buttonIndex]
    local modifier = modifierPrefixes[page]
    _G["BINDING_NAME_CE_ACTION_" .. i] = L("Action") .. i .. " (" .. modifier .. buttonName .. ")"
end

-- Create binding names for left touch bar (slots 41-45)
for i = 41, 45 do
    local buttonIndex = i - 40  -- Button 1-5 on left bar
    _G["BINDING_NAME_CE_ACTION_" .. i] = L("Left Touch Bar Button") .. " " .. buttonIndex
end

-- Create binding names for right touch bar (slots 46-50)
for i = 46, 50 do
    local buttonIndex = i - 45  -- Button 1-5 on right bar
    _G["BINDING_NAME_CE_ACTION_" .. i] = L("Right Touch Bar Button") .. " " .. buttonIndex
end

-- Cursor header and binding names
_G["BINDING_HEADER_CECURSOR"] = L("CE Cursor")
_G["BINDING_NAME_CE_CURSOR_MOVE_UP"] = L("Cursor Up")
_G["BINDING_NAME_CE_CURSOR_MOVE_DOWN"] = L("Cursor Down")
_G["BINDING_NAME_CE_CURSOR_MOVE_LEFT"] = L("Cursor Left")
_G["BINDING_NAME_CE_CURSOR_MOVE_RIGHT"] = L("Cursor Right")
_G["BINDING_NAME_CE_CURSOR_CLICK_LEFT"] = L("Cursor Click")
_G["BINDING_NAME_CE_CURSOR_CLICK_RIGHT"] = L("Cursor Right-Click")
_G["BINDING_NAME_CE_CURSOR_PICKUP"] = L("Cursor Pickup")
_G["BINDING_NAME_CE_CURSOR_BIND"] = L("Cursor Bind")
_G["BINDING_NAME_CE_CURSOR_DELETE"] = L("Cursor Delete")
_G["BINDING_NAME_CE_CURSOR_UNEQUIP"] = L("Cursor Unequip")
_G["BINDING_NAME_CE_CURSOR_CLOSE"] = L("Cursor Close")

-- Radial menu header and binding name
_G["BINDING_HEADER_CERADIAL"] = L("CE Radial Menu")
_G["BINDING_NAME_CE_TOGGLE_RADIAL"] = L("Toggle Radial Menu")

-- Interact header and binding name
_G["BINDING_HEADER_CEINTERACT"] = L("CE Interact")
_G["BINDING_NAME_CE_INTERACT"] = L("Interact with Target")

-- ============================================================================
-- CE_InteractNearest Function (used by CE_INTERACT binding)
-- ============================================================================

function CE_InteractNearest()
    -- InteractNearest is provided by Interact.dll (Turtle WoW addon)
    if InteractNearest then
        InteractNearest(1)
    else
        -- Fallback: target nearest enemy if Interact.dll is not loaded
        DEFAULT_CHAT_FRAME:AddMessage("|cffff9900[CE]|r " .. L("Interact.dll not loaded - using TargetNearestEnemy() as fallback"), 1, 0.6, 0)
        TargetNearestEnemy()
    end
end

-- ============================================================================
-- Global Action Button Handler (like pfUI's pfActionButton)
-- ============================================================================

-- Debug flag - set to true to see key press debug info
ConsoleExperience_DEBUG_KEYS = true

function ConsoleExperience_ActionButton(slot)
    -- Don't trigger if chat is open
    if ChatFrameEditBox and ChatFrameEditBox:IsShown() then return end
    
    -- Only trigger on key down (keystate is set by WoW for runOnUp bindings)
    if keystate == "down" then
        -- Calculate actual slot using the same logic as ActionBars:GetActionOffset()
        -- This ensures keybindings use the same slots as the displayed buttons
        local actualSlot = slot
        local ActionBars = ConsoleExperience.actionbars
        
        -- For slots 1-10 (base bar without modifiers), use GetActionOffset logic
        if slot >= 1 and slot <= 10 then
            if ActionBars and ActionBars.GetActionOffset then
                -- Use the same offset calculation as the action bars
                local offset = ActionBars:GetActionOffset()
                actualSlot = offset + slot
            else
                -- Fallback: basic bonus bar calculation
                local bonusBar = GetBonusBarOffset()
                if bonusBar and bonusBar > 0 then
                    actualSlot = 60 + (bonusBar * 12) + slot
                end
            end
        end
        
        -- Debug output
        if ConsoleExperience_DEBUG_KEYS then
            local bonusBar = GetBonusBarOffset() or 0
            CE_Debug("Key slot=" .. slot .. " bonus=" .. bonusBar .. " actual=" .. actualSlot .. " has=" .. tostring(HasAction(actualSlot)))
        end
        
        -- Check if healer mode is enabled and cursor is over a party/raid/player frame
        local ActionBars = ConsoleExperience.actionbars
        if ActionBars and ActionBars.ShouldCastOnHealerTarget and ActionBars:ShouldCastOnHealerTarget() then
            local Cursor = ConsoleExperience.cursor
            local currentButton = Cursor.navigationState.currentButton
            local unit = ActionBars:GetUnitFromFrame(currentButton)
            
            if unit then
                -- Use the action first
                UseAction(actualSlot, 0)
                
                -- If spell is awaiting target selection, check if we can cast on the unit
                if SpellIsTargeting() then
                    -- Check if the spell can target this unit
                    if SpellCanTargetUnit(unit) then
                        -- Cast on the unit
                        SpellTargetUnit(unit)
                        CE_Debug("Healer mode: Casting action " .. actualSlot .. " on " .. unit)
                        
                        -- Update button visual
                        local buttonNum = math.mod(slot - 1, 10) + 1
                        local button = getglobal("ConsoleActionButton" .. buttonNum)
                        if button and ConsoleExperience.actionbars then
                            ConsoleExperience.actionbars:UpdateButtonState(button)
                        end
                        return
                    else
                        -- Can't target this unit, let it work normally (player can target manually or use current target)
                        CE_Debug("Healer mode: Cannot cast action " .. actualSlot .. " on " .. unit .. " (invalid target, using default behavior)")
                        -- Don't return - let it fall through to normal behavior below
                    end
                else
                    -- Spell doesn't require targeting (instant cast, self-buff, etc.) - already executed
                    CE_Debug("Healer mode: Used action " .. actualSlot .. " (no targeting required)")
                    
                    -- Update button visual
                    local buttonNum = math.mod(slot - 1, 10) + 1
                    local button = getglobal("ConsoleActionButton" .. buttonNum)
                    if button and ConsoleExperience.actionbars then
                        ConsoleExperience.actionbars:UpdateButtonState(button)
                    end
                    return
                end
            end
        end
        
        -- Use the action (checkCursor=0, onSelf=nil to use normal targeting)
        UseAction(actualSlot, 0)
        
        -- Update button visual
        local buttonNum = math.mod(slot - 1, 10) + 1
        local button = getglobal("ConsoleActionButton" .. buttonNum)
        if button and ConsoleExperience.actionbars then
            ConsoleExperience.actionbars:UpdateButtonState(button)
        end
    end
end

-- ============================================================================
-- Keybindings Module
-- ============================================================================

ConsoleExperienceKeybindings = {}

-- Default key bindings (can be customized)
ConsoleExperienceKeybindings.DEFAULT_KEYS = {
    "1", "2", "3", "4", "5", "6", "7", "8", "9", "0"
}

function ConsoleExperienceKeybindings:SetupDefaultBindings()
    -- Only setup bindings if they haven't been set before
    -- This mimics how pfUI handles initial binding setup
    
    local keys = self.DEFAULT_KEYS
    
    -- Page 1: No modifier (actions 1-10)
    for i = 1, 10 do
        local currentKey = GetBindingKey("CE_ACTION_" .. i)
        if not currentKey then
            SetBinding(keys[i], "CE_ACTION_" .. i)
        end
    end
    
    -- Page 2: Shift (actions 11-20)
    for i = 1, 10 do
        local actionNum = i + 10
        local currentKey = GetBindingKey("CE_ACTION_" .. actionNum)
        if not currentKey then
            SetBinding("SHIFT-" .. keys[i], "CE_ACTION_" .. actionNum)
        end
    end
    
    -- Page 3: Ctrl (actions 21-30)
    for i = 1, 10 do
        local actionNum = i + 20
        local currentKey = GetBindingKey("CE_ACTION_" .. actionNum)
        if not currentKey then
            SetBinding("CTRL-" .. keys[i], "CE_ACTION_" .. actionNum)
        end
    end
    
    -- Page 4: Ctrl+Shift (actions 31-40)
    for i = 1, 10 do
        local actionNum = i + 30
        local currentKey = GetBindingKey("CE_ACTION_" .. actionNum)
        if not currentKey then
            SetBinding("CTRL-SHIFT-" .. keys[i], "CE_ACTION_" .. actionNum)
        end
    end
    
    -- Radial menu: Shift+Escape
    SetBinding("SHIFT-ESCAPE", "CE_TOGGLE_RADIAL")
    CE_Debug("Radial menu bound to SHIFT-ESCAPE")
    
    -- Save bindings (1 = account-wide)
    SaveBindings(1)
    
    CE_Debug("Default keybindings set!")
end

function ConsoleExperienceKeybindings:Initialize()
    -- Check if any CE_ACTION binding already has a key assigned.
    -- We scan all 40 slots because some may be proxied to system actions (like JUMP),
    -- which replaces their CE_ACTION_X key. On a fresh install, none will have keys.
    -- This is more robust than a saved variable flag because it directly reflects
    -- the actual WoW binding state and can't get out of sync.
    local hasExistingBindings = false
    for i = 1, 40 do
        if GetBindingKey("CE_ACTION_" .. i) then
            hasExistingBindings = true
            break
        end
    end
    
    if not hasExistingBindings then
        CE_Debug("No CE bindings found, setting up defaults...")
        self:SetupDefaultBindings()
    else
        CE_Debug("Existing CE bindings found, skipping default setup")
    end
    
    -- Initialize and apply proxied actions (replaces old useAForJump system)
    if ConsoleExperience.proxied and ConsoleExperience.proxied.Initialize then
        ConsoleExperience.proxied:Initialize()
    end
    
    -- Override default action button handlers like pfUI does
    -- This redirects default action bar keypresses to our buttons
    _G.ActionButtonDown = function(id)
        ConsoleExperience_ActionButton(id)
    end
    _G.ActionButtonUp = function(id)
        -- We use runOnUp, so this is handled by ConsoleExperience_ActionButton
    end
    
    CE_Debug("Keybindings module initialized!")
end

-- Attach to main addon
ConsoleExperience.keybindings = ConsoleExperienceKeybindings

-- Function to force reset all keybindings (called from config menu)
function ConsoleExperienceKeybindings:ResetAllBindings()
    local keys = self.DEFAULT_KEYS
    
    -- Set all CE_ACTION bindings first (proxied module will override as needed)
    for i = 1, 10 do
        SetBinding(keys[i], "CE_ACTION_" .. i)
        SetBinding("SHIFT-" .. keys[i], "CE_ACTION_" .. (i + 10))
        SetBinding("CTRL-" .. keys[i], "CE_ACTION_" .. (i + 20))
        SetBinding("CTRL-SHIFT-" .. keys[i], "CE_ACTION_" .. (i + 30))
    end
    
    -- Radial menu binding
    SetBinding("SHIFT-ESCAPE", "CE_TOGGLE_RADIAL")
    
    SaveBindings(1)
    
    -- Now apply proxied actions (will override CE_ACTION bindings where needed)
    if ConsoleExperience.proxied and ConsoleExperience.proxied.ApplyAllBindings then
        ConsoleExperience.proxied:ApplyAllBindings()
    end
end
