-- SilverFrame

local function ApplySilverFrame()
    if PlayerFrameTexture then
        PlayerFrameTexture:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Rare")
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_LEVEL_UP")

events:SetScript("OnEvent", function()
    ApplySilverFrame()
end)
