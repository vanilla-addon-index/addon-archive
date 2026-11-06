-- Module: events.lua
-- Purpose: main event dispatcher and startup sequence.
-- Exports: aDF:OnEvent() and SetScript("OnEvent", ...).
-- Depends on: EnsureConfigStructure(), aDF_Default(), aDF_State, Update/Init/Sort.
-- Used by: WoW event system.

-- ==== EVENT HANDLING ==== Main event handling
local S = aDF_State
local lastAuraTime = 0
local pendingUpdate = false

function aDF:OnEvent()

	-- ==== ADDON LOADED ==== subsection
	-- Initialize addon when loaded, set up frames, defaults, etc.

	if event == "ADDON_LOADED" and arg1 == "aDF" then

		-- Ensure the configuration structure is valid

		EnsureConfigStructure()
		
		-- Initialize defaults for debuffs if needed

		aDF_Default()
		
		-- Initialize state variables

		S.target = nil
		S.armorPrev = 30000
		S.lastResUpdate = 0
		
		-- Create frames!!!!!!
		
		aDF:Init()
		aDF.Options:Gui()
		aDF:Sort()
		aDF:Update()

        DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A aDF:|r Loaded",1,1,1)
        DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A aDF:|r type |cFFFFFF00 /adf show|r to show frame",1,1,1)
        DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A aDF:|r type |cFFFFFF00 /adf hide|r to hide frame",1,1,1)
        DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A aDF:|r type |cFFFFFF00 /adf options|r for options frame",1,1,1)
        DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A aDF:|r type |cFFFFFF00 /adf reset|r to reset positions",1,1,1)
        
		return
    end
    
	-- ==== THROTTLE FOR UNIT_AURA ====

    if event == "UNIT_AURA" then

		-- Only our target

        if arg1 ~= S.target then
            return
        end
        
		-- Throttle updates to at most once every 0.5 seconds
		-- This 0,5 can be slow to sunder, and warrior cry. But is necessary to performance

        local now = GetTime()
        if now - lastAuraTime > 0.5 then
            aDF:Update()
            lastAuraTime = now
            pendingUpdate = false
        else
            pendingUpdate = true
        end
        return
    end
    
    -- ==== ACTIONS ON OTHER EVENTS ====
	
    if pendingUpdate and GetTime() - lastAuraTime > 0.5 then
        aDF:Update()
        lastAuraTime = GetTime()
        pendingUpdate = false
    end
    
    if event == "PLAYER_TARGET_CHANGED" then
        pendingUpdate = false
        
        S.target = nil
        if UnitExists("target") then
            S.target = "target"
        end
        S.armorPrev = 30000
        aDF:Update()
        return
    end
end

-- ==== SCRIPT REGISTRATION ====
-- Register the main event handler, if commented/delete the addon will not work, plis don't touch :(


aDF:SetScript("OnEvent", aDF.OnEvent)
