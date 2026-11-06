CaramelNotes = {}

local _G = getfenv(0)
local chatHooks = {}
local realm = GetRealmName()

CaramelNotes.DebugPrint = function(msg)
    if msg ~= nil then
        DEFAULT_CHAT_FRAME:AddMessage("DEBUG: " .. gsub(msg, "|", "||"))
    else
        DEFAULT_CHAT_FRAME:AddMessage("DEBUG: <nil>")
    end
end

local function StrReplace(text, from, to)
    local index = string.find(text, from, 1, true)
    if index then
        text = string.sub(text, 1, index - 1) .. to .. string.sub(text, index + string.len(from), string.len(text))
    end
    return text
end

local function RegisterEvent(event, func)
    local frame = CreateFrame("Frame")
    frame:RegisterEvent(event)
    frame:SetScript("OnEvent", func)
end

CaramelNotes.GetAllNotes = function ()
    if CaramelNotes_Data and CaramelNotes_Data[realm] then
        return CaramelNotes_Data[realm].notes
    end
    return nil
end

CaramelNotes.GetPlayerNote = function (playername)
    if playername and CaramelNotes_Data and CaramelNotes_Data[realm] and CaramelNotes_Data[realm].notes then
        return CaramelNotes_Data[realm].notes[playername]
    end
    return nil
end

CaramelNotes.SetPlayerNote = function (playername, text)
    if playername and CaramelNotes_Data and CaramelNotes_Data[realm] and CaramelNotes_Data[realm].notes then
        if text and text ~= "" then
            if not CaramelNotes_Data[realm].notes[playername] then
                CaramelNotes_Data[realm].notes[playername] = {}
                CaramelNotes_Data[realm].notes[playername].created = time()
                CaramelNotes_Data[realm].notes[playername].createdBy = UnitName("player")
                CaramelNotes_Data[realm].notes[playername].createdAtZone = GetRealZoneText()
            end
            CaramelNotes_Data[realm].notes[playername].text = text
            CaramelNotes_Data[realm].notes[playername].updated = time()
            CaramelNotes_Data[realm].notes[playername].updatedBy = UnitName("player")
            CaramelNotes_Data[realm].notes[playername].updatedAtZone = GetRealZoneText()
        else
            CaramelNotes_Data[realm].notes[playername] = nil
        end
    end
    return nil
end

CaramelNotes.GetSetting = function (setting, defaultValue)
    if not CaramelNotes_Settings then
        return defaultValue
    end
    if CaramelNotes_Settings[setting] == nil then
        return defaultValue
    end
    return CaramelNotes_Settings[setting]
end

CaramelNotes.SetSetting = function (setting, value)
    CaramelNotes_Settings[setting] = value
end

local function OnAddonLoaded()
    if arg1 == "CaramelNotes" or arg1 == "CaramelNotes-WotLK" then
        if not CaramelNotes_Data then
            CaramelNotes_Data = {}
        end
        if not CaramelNotes_Data[realm] then
            CaramelNotes_Data[realm] = {}
        end
        if not CaramelNotes_Data[realm].notes then
            CaramelNotes_Data[realm].notes = {}
        end

        if not CaramelNotes_Settings then
            CaramelNotes_Settings = {}
        end
    end
end

local originalSetItemRef = SetItemRef
function SetItemRef(link, text, button)
    if string.sub(link, 1, 13) == "caramelnotes:" then
        -- Nothing
    else
        originalSetItemRef(link, text, button)
    end
end

local function OnHyperlinkEnter()
    local link = arg1
    if string.sub(link, 1, 13) ~= "caramelnotes:" then
        return
    end
    local playername = string.sub(link, 14)
    local note = CaramelNotes.GetPlayerNote(playername)
    if not note then
        return
    end

    local showCreatedBy = CaramelNotes.GetSetting("ChatShowCreatedBy", false)
    local showCreatedAtZone = CaramelNotes.GetSetting("ChatShowCreatedAtZone", false)

    GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(playername, 1, 1, 1)
    GameTooltip:AddLine(note.text, 0.9, 0.9, 0.9)
    if showCreatedBy and showCreatedAtZone and note.createdBy and note.createdAtZone then
        GameTooltip:AddLine("-- " .. note.createdBy .. " (" .. note.createdAtZone .. ")", 0.7, 0.7, 0.7)
    elseif showCreatedBy and note.createdBy then
        GameTooltip:AddLine("-- " .. note.createdBy, 0.7, 0.7, 0.7)
    elseif showCreatedAtZone and note.createdAtZone then
        GameTooltip:AddLine("-- " .. note.createdAtZone, 0.7, 0.7, 0.7)
    end
    GameTooltip:Show()
end

local function OnHyperlinkLeave()
    local link = arg1
    if string.sub(link, 1, 13) == "caramelnotes:" then
        GameTooltip:Hide()
    end
end

local string_gmatch = string.gmatch or string.gfind

local function OnChatFrameAddMessage(frame, text, a1, a2, a3, a4, a5)
    if string.find(text, "DEBUG") then
        return text
    end

    if not CaramelNotes.GetSetting("ShowNotesInChat", true) then
        return text
    end
    for playerdata, nametext in string_gmatch(text, "|Hplayer:(.-)|h(.-)|h") do
        local playername = playerdata
        local metadataIndex = string.find(playername, ":", 1, true)
        if metadataIndex then
            playername = string.sub(playername, 1, metadataIndex - 1)
        end
        local note = CaramelNotes.GetPlayerNote(playername)
        if note then
            local from = "|Hplayer:" .. playerdata .. "|h" .. nametext .. "|h"
            local to = "|Hplayer:" .. playerdata .. "|h" .. nametext .. "|h|Hcaramelnotes:" .. playername .. "|h|cFFFFFF00 (note)|h|r"
            text = StrReplace(text, from, to)
        end
    end
    return text
end

local function RegisterChatHooks()
    for i = 1, NUM_CHAT_WINDOWS do
        local chatFrame = _G["ChatFrame"..i]
        if chatFrame and not chatHooks[i] then
            chatHooks[i] = {}
            chatHooks[i].AddMessage = chatFrame.AddMessage
            chatFrame.AddMessage = function(frame, text, a1, a2, a3, a4, a5)
                text = OnChatFrameAddMessage(frame, text, a1, a2, a3, a4, a5)
                chatHooks[i].AddMessage(frame, text, a1, a2, a3, a4, a5)
            end
            chatHooks[i].OnHyperlinkEnter = chatFrame:GetScript("OnHyperlinkEnter")
            chatFrame:SetScript("OnHyperlinkEnter", function()
                if chatHooks[i].OnHyperlinkEnter then
                    chatHooks[i].OnHyperlinkEnter()
                end
                OnHyperlinkEnter()
            end)
            chatHooks[i].OnHyperlinkLeave = chatFrame:GetScript("OnHyperlinkLeave")
            chatFrame:SetScript("OnHyperlinkLeave", function()
                if chatHooks[i].OnHyperlinkLeave then
                    chatHooks[i].OnHyperlinkLeave()
                end
                OnHyperlinkLeave()
            end)
        end
    end
end

local function RegisterCommands()
    SLASH_CARAMELNOTES1 = "/caramelnotes"
    SlashCmdList["CARAMELNOTES"] = function(msg)
        CaramelNotes.ShowNotesFrame()
    end
    SLASH_NOTES1 = "/notes"
    SlashCmdList["NOTES"] = function(msg)
        CaramelNotes.ShowNotesFrame()
    end
end

local function OnUpdateMouseoverUnit()
    if not GameTooltip:IsShown() then
        return
    end
    local unit = "mouseover"
    if not UnitIsPlayer(unit) then
        return
    end

    local showNote = CaramelNotes.GetSetting("ShowNotesInTooltips", true)
    local showCreatedBy = CaramelNotes.GetSetting("TooltipsShowCreatedBy", false)
    local showCreatedAtZone = CaramelNotes.GetSetting("TooltipsShowCreatedAtZone", false)

    if not showNote then
        return
    end
    local note = CaramelNotes.GetPlayerNote(UnitName(unit))
    if note then
        GameTooltip:AddLine(note.text, 1, 1, 0)
        if showCreatedBy and showCreatedAtZone and note.createdBy and note.createdAtZone then
            GameTooltip:AddLine("-- " .. note.createdBy .. " (" .. note.createdAtZone .. ")", 0.7, 0.7, 0.7)
        elseif showCreatedBy and note.createdBy then
            GameTooltip:AddLine("-- " .. note.createdBy, 0.7, 0.7, 0.7)
        elseif showCreatedAtZone and note.createdAtZone then
            GameTooltip:AddLine("-- " .. note.createdAtZone, 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end
end

local function RegisterUnitPopupMenus()
    UnitPopupButtons["CARAMELNOTES_EDIT_NOTE"] = {
        text = "Edit note",
        dist = 0,
    }

    local atIndex = 1
    for index, value in ipairs(UnitPopupMenus["PLAYER"]) do
        if value == "CANCEL" then
            atIndex = index
            break
        end
    end
    table.insert(UnitPopupMenus["PLAYER"], atIndex, "CARAMELNOTES_EDIT_NOTE")

    atIndex = 1
    for index, value in ipairs(UnitPopupMenus["FRIEND"]) do
        if value == "CANCEL" then
            atIndex = index
            break
        end
    end
    table.insert(UnitPopupMenus["FRIEND"], atIndex, "CARAMELNOTES_EDIT_NOTE")

    atIndex = 1
    for index, value in ipairs(UnitPopupMenus["PARTY"]) do
        if value == "CANCEL" then
            atIndex = index
            break
        end
    end
    table.insert(UnitPopupMenus["PARTY"], atIndex, "CARAMELNOTES_EDIT_NOTE")

    atIndex = 1
    for index, value in ipairs(UnitPopupMenus["RAID"]) do
        if value == "CANCEL" then
            atIndex = index
            break
        end
    end
    table.insert(UnitPopupMenus["RAID"], atIndex, "CARAMELNOTES_EDIT_NOTE")
end

if hooksecurefunc then
    hooksecurefunc("UnitPopup_OnClick", function (self)
        if self.value == "CARAMELNOTES_EDIT_NOTE" then
            local playername = UIDROPDOWNMENU_INIT_MENU.name
            if playername then
                CaramelNotes.ShowEditFrame(playername)
            end
        end
    end)
else
    local original_UnitPopup_OnClick = UnitPopup_OnClick
    function UnitPopup_OnClick()
        original_UnitPopup_OnClick()
        if this.value == "CARAMELNOTES_EDIT_NOTE" then
            local playername = _G[UIDROPDOWNMENU_INIT_MENU].name
            if playername then
                CaramelNotes.ShowEditFrame(playername)
            end
        end
    end
end

RegisterEvent("ADDON_LOADED", OnAddonLoaded)
RegisterEvent("UPDATE_MOUSEOVER_UNIT", OnUpdateMouseoverUnit)
RegisterChatHooks()
RegisterCommands()
RegisterUnitPopupMenus()
