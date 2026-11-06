FuBar_pfQuestFu = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceDB-2.0", "FuBarPlugin-2.0")
local L = AceLibrary("AceLocale-2.0"):new("FuBar_pfQuestFu")
local Tablet = AceLibrary("Tablet-2.0")

L:RegisterTranslations("enUS", function() return {
    ["tabletHint"] = "Click to open pfQuest menu.",
    ["labelName"] = "pfQuest",
} end)

FuBar_pfQuestFu:RegisterDB("FuBar_pfQuestFuDB")
FuBar_pfQuestFu.hasIcon = true
FuBar_pfQuestFu.defaultPosition = "RIGHT"

function FuBar_pfQuestFu:OnTextUpdate()
    if (self:IsTextShown()) then
        self:ShowText()
        self:SetText("|cffffffff"..L["labelName"].."|r")
    else
        self:HideText()
    end
end

function FuBar_pfQuestFu:OnTooltipUpdate()
    Tablet:SetHint(L["tabletHint"])
end

function FuBar_pfQuestFu:OnClick()
    if pfQuestMenu and pfQuestMenu.Show then
        pfQuestMenu.anchor = self.frame
        if pfQuestMenu:IsShown() then
            pfQuestMenu:Hide()
        else
            pfQuestMenu:Show()
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("pfQuest menu not found.")
    end
end

function FuBar_pfQuestFu:OnEnable()
    self:SetIcon("Interface\\AddOns\\pfQuest\\img\\logo.tga")
end