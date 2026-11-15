-- AdeChatFix: the Russian 1.12 language patch saved the trailing space of
-- chat strings as "32" (the code of a space). This puts the space back.

local reported = false

local function AdeChatFix_Run()
    local fixed = 0
    for k, v in pairs(_G) do
        if type(k) == "string" and type(v) == "string"
           and string.sub(k, 1, 5) == "CHAT_" and string.find(v, "32$") then
            local new = string.gsub(v, "32$", " ")
            setglobal(k, new)
            fixed = fixed + 1
        end
    end
    if fixed > 0 and not reported then
        reported = true
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99AdeChatFix:|r fixed " .. fixed .. " chat strings.")
    end
end

-- Run right away, then again on every loading screen
-- (login, /reload, instances, teleports, portals, hearthstone).
AdeChatFix_Run()

local f = CreateFrame("Frame")
f:RegisterEvent("VARIABLES_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()
    AdeChatFix_Run()
end)
