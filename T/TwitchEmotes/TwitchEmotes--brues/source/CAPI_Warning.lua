local CLASSIC_API_WEBSITE = "https://github.com/brues-code/ClassicAPI"
local CLASSIC_API_LATEST_URL = CLASSIC_API_WEBSITE .. "/releases/latest"

local headline = "TwitchEmotes has been disabled."
local detail = "The ClassicAPI DLL isn't loaded. Download the latest release from: "

local function ShowRequiredPopup()
    StaticPopupDialogs["TWITCH_CLASSICAPI_REQUIRED"] = {
    text = headline .. "\n\n" .. detail,
    button1 = OKAY,
    hasEditBox = 1,
    editBoxWidth = 280,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
    OnShow = function()
        local editBox = getglobal(this:GetName().."EditBox")
        if editBox then
        editBox:SetText(CLASSIC_API_LATEST_URL)
        editBox:HighlightText()
        editBox:SetFocus()
        end
    end,
    }
    StaticPopup_Show("TWITCH_CLASSICAPI_REQUIRED")
    DEFAULT_CHAT_FRAME:AddMessage(
        headline .. " " .. detail .. CLASSIC_API_LATEST_URL,
        1, 0.3, 0.3
    )
end

local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
loginFrame:SetScript("OnEvent", function()
    loginFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
    ShowRequiredPopup()
end)
