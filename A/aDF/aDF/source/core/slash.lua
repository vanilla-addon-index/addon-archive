-- Module: slash.lua
-- Purpose: provide /adf command handlers.
-- Exports: aDF.slash + SlashCmdList registration.
-- Depends on: GetDB(), HUD frame globals, aDF.Options.
-- Used by: chat command interface.

-- ==== SLASH COMMANDS ==== Define the /adf commands

function aDF.slash(arg1,arg2,arg3)
	local db = GetDB()  -- Get current configuration
    
    if arg1 == nil or arg1 == "" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A aDF:|r type |cFFFFFF00 /adf show|r to show frame",1,1,1)
        DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A aDF:|r type |cFFFFFF00 /adf hide|r to hide frame",1,1,1)
        DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A aDF:|r type |cFFFFFF00 /adf options|r for options frame",1,1,1)
        DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A aDF:|r type |cFFFFFF00 /adf reset|r to reset positions",1,1,1)
        DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A aDF:|r type |cFFFFFF00 You can move frames by holding Shift and clicking on them",1,1,1)
    else

        if arg1 == "show" then
            db.display.framesVisible = true
            if aDF_ArmorFrame then aDF_ArmorFrame:Show() end
            if aDF_ResFrame then aDF_ResFrame:Show() end
            if aDF_DebuffFrame then aDF_DebuffFrame:Show() end

        elseif arg1 == "hide" then
            db.display.framesVisible = false
            if aDF_ArmorFrame then aDF_ArmorFrame:Hide() end
            if aDF_ResFrame then aDF_ResFrame:Hide() end
            if aDF_DebuffFrame then aDF_DebuffFrame:Hide() end

        elseif arg1 == "options" or arg1 == "config" then
            aDF.Options:Show()

        elseif arg1 == "reset" then
            db.positions.armor.x, db.positions.armor.y = 0, 0
            db.positions.resistance.x, db.positions.resistance.y = 0, 30
            db.positions.debuffs.x, db.positions.debuffs.y = 0, -50
            if aDF_ArmorFrame then 
                aDF_ArmorFrame:ClearAllPoints()
                aDF_ArmorFrame:SetPoint("CENTER", 0, 0) 
            end

            if aDF_ResFrame then 
                aDF_ResFrame:ClearAllPoints()
                aDF_ResFrame:SetPoint("CENTER", 0, 30) 
            end

            if aDF_DebuffFrame then 
                aDF_DebuffFrame:ClearAllPoints()
                aDF_DebuffFrame:SetPoint("CENTER", 0, -50) 
            end

            DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A aDF:|r Positions reset",1,1,1)

        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A aDF:|r unknown command",1,0.3,0.3)
        end
    end
end

SlashCmdList['ADF_SLASH'] = aDF.slash
SLASH_ADF_SLASH1 = '/adf'

SLASH_ADF_SLASH2 = '/ADF'
