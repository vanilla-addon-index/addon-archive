local events = CreateFrame("Frame", nil, UIParent)
events:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS")

events:SetScript("OnEvent", function()
    if (string.find(arg1, "You gain Not There.")) then
        PlaySoundFile[[Interface\AddOns\BuffAlert\sound.ogg]]
    end
end)