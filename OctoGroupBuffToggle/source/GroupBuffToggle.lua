-- Group Buff Toggle - World of Warcraft 1.12

local MAX_MEMBERS = 4
local MAX_BUFFS = 16
local ICON_SIZE = 20
local ICON_GAP = 2
local ICONS_PER_ROW = 8
local buffFrames = {}
local updateElapsed = 0
local targetBuffFrame

local function BuffsEnabled()
    return GroupBuffsDB and GroupBuffsDB.enabled == true
end

local function TargetBuffsEnabled()
    return GroupBuffsDB and GroupBuffsDB.targetEnabled == true
end

local function GroupCheckboxEnabled()
    return not GroupBuffsDB or GroupBuffsDB.groupCheckbox ~= false
end

local function TargetCheckboxEnabled()
    return not GroupBuffsDB or GroupBuffsDB.targetCheckbox ~= false
end

local function HideMemberBuffs(member)
    local container = buffFrames[member]
    if not container then return end
    local index
    for index = 1, MAX_BUFFS do container.buttons[index]:Hide() end
    container:Hide()
end

local function BuffOnEnter()
    if not this.unit or not this.buffIndex then return end
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetUnitBuff(this.unit, this.buffIndex)
end

local function CreateMemberBuffs(member)
    local partyFrame = getglobal("PartyMemberFrame" .. member)
    if not partyFrame then return nil end

    local container = CreateFrame("Frame", "GroupBuffsMember" .. member, UIParent)
    container:SetWidth(ICONS_PER_ROW * (ICON_SIZE + ICON_GAP))
    container:SetHeight(2 * (ICON_SIZE + ICON_GAP))
    container:SetPoint("TOPLEFT", partyFrame, "TOPRIGHT", 8, -4)
    container.buttons = {}

    local index
    for index = 1, MAX_BUFFS do
        local button = CreateFrame("Button", "GroupBuffButton" .. member .. "_" .. index, container)
        button:SetWidth(ICON_SIZE)
        button:SetHeight(ICON_SIZE)
        local column = math.mod(index - 1, ICONS_PER_ROW)
        local row = math.floor((index - 1) / ICONS_PER_ROW)
        button:SetPoint("TOPLEFT", container, "TOPLEFT",
            column * (ICON_SIZE + ICON_GAP), -row * (ICON_SIZE + ICON_GAP))

        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetAllPoints(button)
        button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        button.border = button:CreateTexture(nil, "OVERLAY")
        button.border:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
        button.border:SetAllPoints(button)
        button.border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
        button.border:SetVertexColor(0.65, 0.65, 0.65)
        button:SetScript("OnEnter", BuffOnEnter)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        container.buttons[index] = button
    end

    buffFrames[member] = container
    return container
end

local function CreateTargetBuffs()
    if targetBuffFrame or not TargetFrame then return end
    targetBuffFrame = CreateFrame("Frame", "TargetBuffs", UIParent)
    targetBuffFrame:SetWidth(ICONS_PER_ROW * (ICON_SIZE + ICON_GAP))
    targetBuffFrame:SetHeight(2 * (ICON_SIZE + ICON_GAP))
    targetBuffFrame:SetPoint("TOPLEFT", TargetFrame, "TOPRIGHT", 38, -18)
    targetBuffFrame.buttons = {}

    local index
    for index = 1, MAX_BUFFS do
        local button = CreateFrame("Button", "TargetBuffButton" .. index, targetBuffFrame)
        button:SetWidth(ICON_SIZE)
        button:SetHeight(ICON_SIZE)
        local column = math.mod(index - 1, ICONS_PER_ROW)
        local row = math.floor((index - 1) / ICONS_PER_ROW)
        button:SetPoint("TOPLEFT", targetBuffFrame, "TOPLEFT",
            column * (ICON_SIZE + ICON_GAP), -row * (ICON_SIZE + ICON_GAP))
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetAllPoints(button)
        button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        button.border = button:CreateTexture(nil, "OVERLAY")
        button.border:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
        button.border:SetAllPoints(button)
        button.border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
        button.border:SetVertexColor(0.65, 0.65, 0.65)
        button.unit = "target"
        button.buffIndex = index
        button:SetScript("OnEnter", BuffOnEnter)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        targetBuffFrame.buttons[index] = button
    end
end

local function UpdateTargetBuffs()
    CreateTargetBuffs()
    if not targetBuffFrame then return end
    if TargetBuffsCheckButton then
        TargetBuffsCheckButton:ClearAllPoints()
        TargetBuffsCheckButton:SetPoint("LEFT", TargetFrame, "RIGHT", 4, -38)
        if TargetCheckboxEnabled() and UnitExists("target") and TargetFrame:IsShown() then
            TargetBuffsCheckButton:Show()
        else
            TargetBuffsCheckButton:Hide()
        end
    end
    targetBuffFrame:ClearAllPoints()
    targetBuffFrame:SetPoint("TOPLEFT", TargetFrame, "TOPRIGHT", 38, -18)
    if not TargetBuffsEnabled() or not UnitExists("target") or not TargetFrame:IsShown() then
        local index
        for index = 1, MAX_BUFFS do targetBuffFrame.buttons[index]:Hide() end
        targetBuffFrame:Hide()
        return
    end

    targetBuffFrame:Show()
    local index
    for index = 1, MAX_BUFFS do
        local texture = UnitBuff("target", index)
        local button = targetBuffFrame.buttons[index]
        if texture then button.icon:SetTexture(texture); button:Show() else button:Hide() end
    end
end

local function UpdateMember(member)
    local unit = "party" .. member
    local partyFrame = getglobal("PartyMemberFrame" .. member)
    local container = buffFrames[member] or CreateMemberBuffs(member)
    if not container then return end

    container:ClearAllPoints()
    container:SetPoint("TOPLEFT", partyFrame, "TOPRIGHT", 8, -4)
    if not BuffsEnabled() or not UnitExists(unit) or not partyFrame:IsShown() then
        HideMemberBuffs(member)
        return
    end

    container:Show()
    local index
    for index = 1, MAX_BUFFS do
        local texture, applications = UnitBuff(unit, index)
        local button = container.buttons[index]
        if texture then
            button.unit = unit
            button.buffIndex = index
            button.icon:SetTexture(texture)
            button:Show()
        else
            button:Hide()
        end
    end
end

local function UpdateCheckboxPosition()
    if not GroupBuffsCheckButton then return end
    local anchor
    local member
    for member = MAX_MEMBERS, 1, -1 do
        local frame = getglobal("PartyMemberFrame" .. member)
        if frame and frame:IsShown() and UnitExists("party" .. member) then
            anchor = frame
            break
        end
    end

    GroupBuffsCheckButton:ClearAllPoints()
    if anchor and GroupCheckboxEnabled() then
        GroupBuffsCheckButton:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 4, -6)
        GroupBuffsCheckButton:Show()
    else
        GroupBuffsCheckButton:Hide()
    end
end

local function UpdateAll()
    local member
    for member = 1, MAX_MEMBERS do UpdateMember(member) end
    UpdateCheckboxPosition()
    UpdateTargetBuffs()
end

local function CreateCheckbox()
    if GroupBuffsCheckButton then return end
    local checkbox = CreateFrame("CheckButton", "GroupBuffsCheckButton", UIParent, "UICheckButtonTemplate")
    checkbox:SetWidth(24)
    checkbox:SetHeight(24)
    getglobal(checkbox:GetName() .. "Text"):SetText("Buffs")
    checkbox:SetChecked(BuffsEnabled())
    checkbox:SetScript("OnClick", function()
        GroupBuffsDB.enabled = this:GetChecked() and true or false
        UpdateAll()
    end)
    checkbox:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText("Group Buffs")
        GameTooltip:AddLine("Show party-member buffs beside the group frames.", 1, 1, 1, 1)
        GameTooltip:Show()
    end)
    checkbox:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local targetCheckbox = CreateFrame("CheckButton", "TargetBuffsCheckButton", UIParent, "UICheckButtonTemplate")
    targetCheckbox:SetWidth(24)
    targetCheckbox:SetHeight(24)
    targetCheckbox:SetPoint("LEFT", TargetFrame, "RIGHT", 4, -38)
    getglobal(targetCheckbox:GetName() .. "Text"):SetText("Buffs")
    targetCheckbox:SetChecked(TargetBuffsEnabled())
    targetCheckbox:SetScript("OnClick", function()
        GroupBuffsDB.targetEnabled = this:GetChecked() and true or false
        UpdateTargetBuffs()
    end)
    targetCheckbox:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText("Target Buffs")
        GameTooltip:AddLine("Show buffs beside the target frame.", 1, 1, 1, 1)
        GameTooltip:Show()
    end)
    targetCheckbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("VARIABLES_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PARTY_MEMBERS_CHANGED")
events:RegisterEvent("UNIT_AURA")
events:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        GroupBuffsDB = GroupBuffsDB or {}
        if GroupBuffsDB.enabled == nil then GroupBuffsDB.enabled = false end
        if GroupBuffsDB.targetEnabled == nil then GroupBuffsDB.targetEnabled = false end
        if GroupBuffsDB.groupCheckbox == nil then GroupBuffsDB.groupCheckbox = true end
        if GroupBuffsDB.targetCheckbox == nil then GroupBuffsDB.targetCheckbox = true end
        CreateCheckbox()
    end
    UpdateAll()
end)
events:SetScript("OnUpdate", function()
    updateElapsed = updateElapsed + arg1
    if updateElapsed >= 0.5 then
        updateElapsed = 0
        UpdateAll()
    end
end)

SLASH_GROUPBUFFS1 = "/groupbuffs"
SlashCmdList["GROUPBUFFS"] = function(message)
    GroupBuffsDB = GroupBuffsDB or {}
    message = string.lower(message or "")
    message = string.gsub(message, "^%s+", "")
    message = string.gsub(message, "%s+$", "")

    local _, _, control, action = string.find(message, "^(%S+)%s+(%S+)$")
    local key
    if control == "group" or control == "party" then
        key = "enabled"
    elseif control == "groupbox" or control == "groupcheckbox" or control == "partybox" then
        key = "groupCheckbox"
    elseif control == "target" then
        key = "targetEnabled"
    elseif control == "targetbox" or control == "targetcheckbox" then
        key = "targetCheckbox"
    end

    if key and (action == "on" or action == "off" or action == "toggle") then
        if action == "toggle" then
            GroupBuffsDB[key] = not GroupBuffsDB[key]
        else
            GroupBuffsDB[key] = action == "on"
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Group Buffs:|r " .. control .. " " .. (GroupBuffsDB[key] and "on" or "off") .. ".")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Group Buffs commands:|r")
        DEFAULT_CHAT_FRAME:AddMessage("/groupbuffs group on|off|toggle")
        DEFAULT_CHAT_FRAME:AddMessage("/groupbuffs groupbox on|off|toggle")
        DEFAULT_CHAT_FRAME:AddMessage("/groupbuffs target on|off|toggle")
        DEFAULT_CHAT_FRAME:AddMessage("/groupbuffs targetbox on|off|toggle")
        DEFAULT_CHAT_FRAME:AddMessage("Party buffs: " .. (BuffsEnabled() and "on" or "off")
            .. ", party checkbox: " .. (GroupCheckboxEnabled() and "on" or "off")
            .. ", target buffs: " .. (TargetBuffsEnabled() and "on" or "off")
            .. ", target checkbox: " .. (TargetCheckboxEnabled() and "on" or "off"))
    end

    if GroupBuffsCheckButton then GroupBuffsCheckButton:SetChecked(BuffsEnabled()) end
    if TargetBuffsCheckButton then TargetBuffsCheckButton:SetChecked(TargetBuffsEnabled()) end
    UpdateAll()
end
