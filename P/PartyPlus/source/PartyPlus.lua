local PartyPlus = CreateFrame("Frame", "PartyPlusFrame", UIParent)
PartyPlus:SetWidth(260)
PartyPlus:SetHeight(350)
PartyPlus:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
PartyPlus:SetMovable(true)
PartyPlus:EnableMouse(true)
PartyPlus:RegisterForDrag("LeftButton")
PartyPlus:SetScript("OnDragStart", function() PartyPlus:StartMoving() end)
PartyPlus:SetScript("OnDragStop", function() PartyPlus:StopMovingOrSizing() end)
PartyPlus:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
PartyPlus:SetBackdropColor(0, 0, 0, 0.8)

local title = PartyPlus:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
title:SetPoint("TOP", PartyPlus, "TOP", 0, -6)
title:SetText("Party Plus")

local closeButton = CreateFrame("Button", nil, PartyPlus, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", PartyPlus, "TOPRIGHT", -5, -5)
closeButton:SetScript("OnClick", function() PartyPlus:Hide() end)

local function CreateInputBox(parent, label, x, y, name, defaultNumber)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetWidth(260)
    frame:SetHeight(20)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", frame, "LEFT", 0, 0)
    text:SetText(label)

    local rightFrame = CreateFrame("Frame", nil, frame)
    rightFrame:SetWidth(80)
    rightFrame:SetHeight(20)
    rightFrame:SetPoint("RIGHT", frame, "RIGHT", 0, 0)

    local editbox = CreateFrame("EditBox", name, rightFrame, "InputBoxTemplate")
    editbox:SetWidth(40)
    editbox:SetHeight(20)
    editbox:SetPoint("RIGHT", rightFrame, "RIGHT", -23, 0)
    editbox:SetAutoFocus(false)
    editbox:SetNumeric(true)
    editbox:SetNumber(0)
    editbox:SetBackdropColor(0, 0, 0, 0.8)
    editbox:SetBackdropBorderColor(0.5, 0.5, 0.5)
    editbox:SetNumber(defaultNumber)

    local textColor = {1, 1, 1}
    editbox:SetTextColor(unpack(textColor))

    local function AdjustValue(delta)
        local value = editbox:GetNumber() + delta
        if value < 0 then value = 0 end
        editbox:SetNumber(value)
    end

    local plusButton = CreateFrame("Button", nil, rightFrame, "UIPanelButtonTemplate")
    plusButton:SetWidth(20)
    plusButton:SetHeight(20)
    plusButton:SetText("+")
    plusButton:SetPoint("RIGHT", editbox, "LEFT", -8, 0)
    plusButton:SetScript("OnClick", function() AdjustValue(1) end)

    local minusButton = CreateFrame("Button", nil, rightFrame, "UIPanelButtonTemplate")
    minusButton:SetWidth(20)
    minusButton:SetHeight(20)
    minusButton:SetText("-")
    minusButton:SetPoint("RIGHT", plusButton, "LEFT", -4, 0)
    minusButton:SetScript("OnClick", function() AdjustValue(-1) end)

    return editbox
end

local tankBox = CreateInputBox(PartyPlus, "Tanks:", 10, -35, "tankBox", 1)
local healerBox = CreateInputBox(PartyPlus, "Healers:", 10, -65, "healerBox", 1)
local dpsBox = CreateInputBox(PartyPlus, "DPS:", 10, -95, "dpsBox", 3)
local requiredBox = CreateInputBox(PartyPlus, "Required Party Size:", 10, -125, "requiredBox", 5)
local softReserveBox = CreateInputBox(PartyPlus, "Soft Reserve Count:", 10, -155, "softReserveBox", 0)

local hardReserveLabel = PartyPlus:CreateFontString(nil, "OVERLAY", "GameFontNormal")
hardReserveLabel:SetPoint("TOPLEFT", PartyPlus, "TOPLEFT", 10, -185)
hardReserveLabel:SetText("Hard Reserves")

local hardReserverBox = CreateFrame("EditBox", "hardReserveBox", PartyPlus, "InputBoxTemplate")
hardReserverBox:SetWidth(232)
hardReserverBox:SetHeight(20)
hardReserverBox:SetPoint("TOPLEFT", PartyPlus, "TOPLEFT", 16, -200)
hardReserverBox:SetAutoFocus(false)

local dungeonLabel = PartyPlus:CreateFontString(nil, "OVERLAY", "GameFontNormal")
dungeonLabel:SetPoint("TOPLEFT", PartyPlus, "TOPLEFT", 10, -230)
dungeonLabel:SetText("Content Name")

local dungeonBox = CreateFrame("EditBox", "dungeonBox", PartyPlus, "InputBoxTemplate")
dungeonBox:SetWidth(232)
dungeonBox:SetHeight(20)
dungeonBox:SetPoint("TOPLEFT", PartyPlus, "TOPLEFT", 16, -250)
dungeonBox:SetAutoFocus(false)

local channelLabel = PartyPlus:CreateFontString(nil, "OVERLAY", "GameFontNormal")
channelLabel:SetPoint("TOPLEFT", PartyPlus, "TOPLEFT", 10, -280)
channelLabel:SetText("Chat Channels (Space Seperated)")

local channelBox = CreateFrame("EditBox", "channelBox", PartyPlus, "InputBoxTemplate")
channelBox:SetWidth(232)
channelBox:SetHeight(20)
channelBox:SetPoint("TOPLEFT", PartyPlus, "TOPLEFT", 16, -295)
channelBox:SetAutoFocus(false)
channelBox:SetText("yell 1")

local postButton = CreateFrame("Button", nil, PartyPlus, "UIPanelButtonTemplate")
postButton:SetWidth(100)
postButton:SetHeight(25)
postButton:SetPoint("BOTTOM", PartyPlus, "BOTTOM", 0, 10)
postButton:SetText("Post")

local function GetGroupSize()
    if GetNumRaidMembers() > 0 then
        return GetNumRaidMembers() 
    elseif GetNumPartyMembers() > 0 then
        return GetNumPartyMembers() + 1 
    else
        return 1
    end
end

local function OnTabPressed_EditBox(editbox, nextEditBox)
    editbox:SetScript("OnTabPressed", function()
        if nextEditBox then
            nextEditBox:SetFocus()
        end
    end)
end

OnTabPressed_EditBox(tankBox, healerBox)
OnTabPressed_EditBox(healerBox, dpsBox)
OnTabPressed_EditBox(dpsBox, requiredBox)
OnTabPressed_EditBox(requiredBox, softReserveBox)
OnTabPressed_EditBox(softReserveBox, hardReserverBox)
OnTabPressed_EditBox(hardReserverBox, dungeonBox)
OnTabPressed_EditBox(dungeonBox, channelBox)
OnTabPressed_EditBox(channelBox, tankBox)

local function PostToChat()
    local tanks = tankBox:GetNumber()
    local healers = healerBox:GetNumber()
    local dps = dpsBox:GetNumber()
    local required = requiredBox:GetNumber()
    local softReserves = softReserveBox:GetNumber()
    local hardReserves = hardReserveBox:GetText()
    local dungeon = dungeonBox:GetText()
    local channelInput = channelBox:GetText()

    if required == 0 or required == "" then
        print("Required Party Size is required!")
        return
    end

    if dungeon == "" then
        print("Dungeon Name is required!")
        return
    end

    local partySize = GetGroupSize()

    local messageParts = {}

    if tanks > 0 then
        local tankText = (tanks == 1) and "TANK" or "TANKS"
        table.insert(messageParts, string.format("%d %s", tanks, tankText))
    end
    
    if healers > 0 then
        local healerText = (healers == 1) and "HEALER" or "HEALERS"
        table.insert(messageParts, string.format("%d %s", healers, healerText))
    end

    if dps > 0 then
        table.insert(messageParts, string.format("%d DPS", dps))
    end

    if dungeon ~= "" then
        table.insert(messageParts, dungeon)
    end

    table.insert(messageParts, string.format("%d/%d", partySize, required))

    local message = "LFM " .. table.concat(messageParts, ", ")

    if hardReserves ~= "" then
        message = message.." [HR: "..hardReserves.."] "
    end

    if softReserves > 0 then
        message = message.." ("..softReserves.." SR > MS > OS) "
    end

      local validChannels = {
        s = "SAY",
        say = "SAY",
        g = "GUILD",
        guild = "GUILD",
        r = "RAID",
        raid = "RAID",
        p = "PARTY",
        party = "PARTY",
        w = "WHISPER",
        whisper = "WHISPER",
        y = "YELL",
        yell = "YELL"
    }

    local channels = {} 

    for channel in string.gmatch(channelInput, "[^ ]+") do
        tinsert(channels, channel)
    end

    for _, channel in ipairs(channels) do
        local num = tonumber(channel)  -- Check if it's a number (for numbered channels)
        if num then
            SendChatMessage(message, "CHANNEL", nil, num)
        else
            local channelType = validChannels[string.lower(channel)]
            if channelType then
                SendChatMessage(message, channelType)
            else
                print("Invalid channel: " .. channel)
            end
        end
    end
end

postButton:SetScript("OnClick", PostToChat)

SLASH_PARTYPLUS1 = "/partyplus"

function SlashCmdList.PARTYPLUS(msg, editBox)
    if PartyPlus:IsShown() then
        PartyPlus:Hide()
    else
        PartyPlus:Show()
    end
end

local function ClearFocus(self, button)
    tankBox:ClearFocus()
    healerBox:ClearFocus()
    dpsBox:ClearFocus()
    requiredBox:ClearFocus()
    dungeonBox:ClearFocus()
    channelBox:ClearFocus()
end

PartyPlus:SetScript("OnMouseDown", ClearFocus)
WorldFrame:SetScript("OnMouseDown", ClearFocus)

PartyPlus:Hide()

local PartyPlusMinimapButton = CreateFrame("Button", "PartyPlusMinimapButton", Minimap)
PartyPlusMinimapButton:SetWidth(32)
PartyPlusMinimapButton:SetHeight(32)
PartyPlusMinimapButton:SetFrameStrata("MEDIUM")
PartyPlusMinimapButton:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 5, -5)

local border = PartyPlusMinimapButton:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetWidth(54)
border:SetHeight(54)
border:SetPoint("CENTER", PartyPlusMinimapButton, "CENTER", 11, -11)

local icon = PartyPlusMinimapButton:CreateTexture(nil, "BACKGROUND")
icon:SetTexture("Interface\\Icons\\INV_Misc_EngGizmos_01") 
icon:SetWidth(20)
icon:SetHeight(20)
icon:SetPoint("CENTER", PartyPlusMinimapButton, "CENTER", 0, 0)

PartyPlusMinimapButton:SetScript("OnEnter", function()
    GameTooltip:SetOwner(PartyPlusMinimapButton, "ANCHOR_RIGHT")  
    GameTooltip:SetText("Party Plus", 1, 1, 1)  
    GameTooltip:AddLine("Click to open Party Plus", 0.8, 0.8, 0.8) 
    GameTooltip:AddLine("Or use /partyplus.", 0.8, 0.8, 0.8)  
    GameTooltip:AddLine("Ctrl + Left Click to reposition the minimap icon.", 0.8, 0.8, 0.8)  
    GameTooltip:Show() 
end)

PartyPlusMinimapButton:SetScript("OnLeave", function()
    GameTooltip:Hide()  
end)

-- Make it draggable (only while holding Ctrl)
local isDragging = false

PartyPlusMinimapButton:SetMovable(true)
PartyPlusMinimapButton:EnableMouse(true)

PartyPlusMinimapButton:RegisterForDrag("LeftButton")

-- Drag start functionality: only works when holding Ctrl
PartyPlusMinimapButton:SetScript("OnDragStart", function(self)
    if IsControlKeyDown() then  
        isDragging = true
        PartyPlusMinimapButton:StartMoving()
    end
end)

-- Drag stop functionality
PartyPlusMinimapButton:SetScript("OnDragStop", function(self)
    if isDragging then
        PartyPlusMinimapButton:StopMovingOrSizing()
        isDragging = false  
    end
end)

-- Button click functionality
PartyPlusMinimapButton:SetScript("OnClick", function()
    if PartyPlus:IsShown() then
        PartyPlus:Hide()
    else
        PartyPlus:Show()
    end
end)

PartyPlusMinimapButton:Show()
