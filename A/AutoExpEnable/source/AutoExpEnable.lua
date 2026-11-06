EXP = CreateFrame("Frame", nil, nil)  
EXP:RegisterEvent("CHAT_MSG_SYSTEM")
EXP:RegisterEvent("PLAYER_LOGIN")
--EXP:RegisterAllEvents()

EXP:SetScript("OnEvent", function()
    if event == "CHAT_MSG_SYSTEM" then
        if ("XP gain is now OFF" == arg1) or ("XP gain is OFF" == arg1) then
            DEFAULT_CHAT_FRAME:AddMessage("Now exp gain OFF can .xp on to ON")
            UIErrorsFrame:AddMessage("Now exp gain OFF can .xp on to ON", 1.0, 0.0, 0.0, 53, 5)
        end
        if(string.find(arg1,"erver ") ~= nil and string.find(arg1," restart") ~= nil) then
            DEFAULT_CHAT_FRAME:AddMessage(arg1)
            UIErrorsFrame:AddMessage(arg1, 1.0, 0.0, 0.0, 53, 5)
        end
    end
    if event == "PLAYER_LOGIN" then
        ChatFrame_RemoveMessageGroup(ChatFrame1, "CHANNEL")
    end
end)
