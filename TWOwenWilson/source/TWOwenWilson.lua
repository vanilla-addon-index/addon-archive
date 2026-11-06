local ow = CreateFrame('Frame')

ow:RegisterEvent("ADDON_LOADED")

ow:RegisterEvent("CHAT_MSG_COMBAT_SELF_HITS")
ow:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")

ow:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE")
ow:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE")

ow:SetScript("OnEvent", function()
    if event then
        if event == 'ADDON_LOADED' and arg1 == 'TWOwenWilson' then
            if not TWOW_WOW then
                TWOW_WOW = true
            end
            if not TWOW_BLONK then
                TWOW_BLONK = true
            end
            return
        end

        if (event == 'CHAT_MSG_COMBAT_SELF_HITS' or event == 'CHAT_MSG_SPELL_SELF_DAMAGE') and TWOW_WOW then
            if string.find(arg1, "You crit", 1, true) then
                PlaySoundFile("Interface\\AddOns\\TWOwenWilson\\Sounds\\" .. math.random(1, 16) .. ".mp3");
                return
            end
            if string.find(arg1, "Your ", 1, true) and string.find(arg1, " crits ", 1, true) then
                PlaySoundFile("Interface\\AddOns\\TWOwenWilson\\Sounds\\" .. math.random(1, 16) .. ".mp3");
                return
            end
        end
        if (event == "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE" or event == "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE")
                and TWOW_BLONK and UnitName('target') then
            if string.find(arg1, UnitName('target') .. " is afflicted by Mace Stun Effect.") then
                PlaySoundFile("Interface\\AddOns\\TWOwenWilson\\Sounds\\bonk.mp3");
                return
            end

        end
    end
end)

SLASH_TWOW1 = "/twow"
SlashCmdList["TWOW"] = function(cmd)
    if cmd then
        if string.find(cmd, "default") then
            if TWOW_WOW then
                TWOW_WOW = false
                DEFAULT_CHAT_FRAME:AddMessage("Default Crit Sound is now Off")
            else
                TWOW_WOW = true
                DEFAULT_CHAT_FRAME:AddMessage("Default Crit Sound is now On")
            end
        end
        if string.find(cmd, "blonk") then
            if TWOW_BLONK then
                TWOW_BLONK = false
                DEFAULT_CHAT_FRAME:AddMessage("Blonk Sound is now Off")
            else
                TWOW_BLONK = true
                DEFAULT_CHAT_FRAME:AddMessage("Blonk Sound is now On")
            end
        end
    end
end
