-- PPBuddy.lua
-- Compact blessing status bar for any class.
-- Works standalone: listens to PallyPower's PLPWR addon messages directly.
-- Also reads PallyPowerTW globals if PP is installed locally (no conflict).
-- No dependency on PallyPowerTW.

-- ============================================================
-- Saved variables
-- ============================================================
-- PPBuddy_Config is declared in the TOC as SavedVariables.
-- Do NOT initialise it here — that would overwrite the loaded data.
-- Defaults are applied in PPB_Init() after the saved data is available.
--
-- PPBuddy_Config = {
--   banned  = {},          -- [blessingID] = true
--   prefs   = {},          -- [assignedBlessingID] = preferredBlessingID
--   posX    = nil,
--   posY    = nil,
-- }

-- ============================================================
-- Constants
-- ============================================================
local PP_PREFIX   = "PLPWR"
local UPDATE_FREQ = 2
local initDone    = false

local ClassTokenToID = {
    WARRIOR = 0, ROGUE = 1, PRIEST = 2, DRUID   = 3,
    PALADIN = 4, HUNTER = 5, MAGE  = 6, WARLOCK = 7, SHAMAN = 8,
}

local BlessingNames = {
    [0] = "Wisdom", [1] = "Might",     [2] = "Salvation",
    [3] = "Light",  [4] = "Kings",     [5] = "Sanctuary",
}

local BlessingTextures = {
    [0] = "Spell_Holy_GreaterBlessingofWisdom",
    [1] = "Spell_Holy_GreaterBlessingofKings",
    [2] = "Spell_Holy_GreaterBlessingofSalvation",
    [3] = "Spell_Holy_GreaterBlessingofLight",
    [4] = "Spell_Magic_GreaterBlessingofKings",
    [5] = "Spell_Holy_GreaterBlessingofSanctuary",
}

local BlessingTexturesSmall = {
    [0] = "Spell_Holy_SealOfWisdom",
    [1] = "Spell_Holy_FistOfJustice",
    [2] = "Spell_Holy_SealOfSalvation",
    [3] = "Spell_Holy_PrayerOfHealing02",
    [4] = "Spell_Magic_MageArmor",
    [5] = "Spell_Nature_LightningShield",
}

local ICON_PREFIX = "Interface\\Icons\\"

local BlessingIcons = {
    [0] = ICON_PREFIX .. "Spell_Holy_GreaterBlessingofWisdom",
    [1] = ICON_PREFIX .. "Spell_Holy_GreaterBlessingofKings",
    [2] = ICON_PREFIX .. "Spell_Holy_GreaterBlessingofSalvation",
    [3] = ICON_PREFIX .. "Spell_Holy_GreaterBlessingofLight",
    [4] = ICON_PREFIX .. "Spell_Magic_GreaterBlessingofKings",
    [5] = ICON_PREFIX .. "Spell_Holy_GreaterBlessingofSanctuary",
}

local FLYOUT_DELAY = 0.5   -- seconds of hover before flyout appears

local DEFAULT_MSG_ASSIGNED = "Hey %player%, could I please get %buff%? Thank you! :)"
local DEFAULT_MSG_ALT      = "Hey %player%, could I get a 10-minute %altbuff% instead of %buff%? Thank you! :)"


-- ============================================================
-- Assignment table  [pallyName][classID] = blessingID or -1
-- ============================================================
local PPB_Assignments = {}

-- ============================================================
-- Core helpers
-- ============================================================

local function PPB_Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffff00PPBuddy:|r " .. tostring(msg))
end

local function PPB_GetMyClassID()
    local _, token = UnitClass("player")
    return token and ClassTokenToID[token]
end

local function PPB_HasBuff(blessingID)
    local fragGreat = BlessingTextures[blessingID]
    local fragSmall = BlessingTexturesSmall[blessingID]
    local i = 1
    while true do
        local tex = UnitBuff("player", i)
        if not tex then break end
        if fragGreat and string.find(tex, fragGreat) then return true end
        if fragSmall and string.find(tex, fragSmall) then return true end
        i = i + 1
    end
    return false
end

local function PPB_CancelBuff(blessingID)
    local fragGreat = BlessingTextures[blessingID]
    local fragSmall = BlessingTexturesSmall[blessingID]
    local counter = 0
    while GetPlayerBuff(counter) >= 0 do
        local index, untilCancelled = GetPlayerBuff(counter)
        if untilCancelled ~= 1 then
            local tex = GetPlayerBuffTexture(index)
            if tex then
                if (fragGreat and string.find(tex, fragGreat)) or
                   (fragSmall and string.find(tex, fragSmall)) then
                    CancelPlayerBuff(index)
                    UIErrorsFrame:Clear()
                    UIErrorsFrame:AddMessage("PPBuddy: Removed " .. (BlessingNames[blessingID] or "?"))
                    return
                end
            end
        end
        counter = counter + 1
    end
end

-- ============================================================
-- Assignment data — sync from PP globals + parse PLPWR messages
-- ============================================================

local function PPB_SyncFromPP()
    if not PallyPower_Assignments then return end
    for pallyName, assignments in next, PallyPower_Assignments do
        if type(assignments) == "table" then
            if not PPB_Assignments[pallyName] then PPB_Assignments[pallyName] = {} end
            for classID = 0, 9 do
                local bid = assignments[classID]
                if bid and type(bid) == "number" then
                    PPB_Assignments[pallyName][classID] = bid
                end
            end
        end
    end
end

local function PPB_ParseSelf(sender, msg)
    local _, _, numbers, assign = string.find(msg, "SELF ([0-9n]*)@?([0-9n]*)")
    if not numbers then return end
    if not PPB_Assignments[sender] then PPB_Assignments[sender] = {} end
    if assign and assign ~= "" then
        for classID = 0, 9 do
            local ch = string.sub(assign, classID + 1, classID + 1)
            PPB_Assignments[sender][classID] = (ch == "n" or ch == "") and -1 or (tonumber(ch) or -1)
        end
    end
end

local function PPB_ParseAssign(msg)
    local _, _, name, classID, bid = string.find(msg, "ASSIGN (.*) (.*) (.*)")
    if not name then return end
    classID = tonumber(classID)
    bid     = tonumber(bid)
    if not classID or not bid then return end
    if not PPB_Assignments[name] then PPB_Assignments[name] = {} end
    PPB_Assignments[name][classID] = bid
end

local function PPB_ParseMassign(msg)
    local _, _, name, bid = string.find(msg, "MASSIGN (.*) (.*)")
    if not name then return end
    bid = tonumber(bid)
    if not bid then return end
    if not PPB_Assignments[name] then PPB_Assignments[name] = {} end
    for classID = 0, 9 do PPB_Assignments[name][classID] = bid end
end

local function PPB_ParseClear(sender)
    PPB_Assignments[sender] = nil
end

local function PPB_PruneAssignments()
    local present = {}
    if GetNumRaidMembers() > 0 then
        for i = 1, GetNumRaidMembers() do
            local name = GetRaidRosterInfo(i)
            if name then present[name] = true end
        end
    else
        present[UnitName("player")] = true
        for i = 1, GetNumPartyMembers() do
            local name = UnitName("party" .. i)
            if name then present[name] = true end
        end
    end
    for name in next, PPB_Assignments do
        if not present[name] then PPB_Assignments[name] = nil end
    end
end

local function PPB_GetMyAssignments()
    local myClassID = PPB_GetMyClassID()
    if not myClassID then return {} end
    local seen = {}
    for pallyName, assignments in next, PPB_Assignments do
        if type(assignments) == "table" then
            local bid = assignments[myClassID]
            if bid and type(bid) == "number" and bid >= 0 and bid <= 5 then
                if not seen[bid] then seen[bid] = pallyName end
            end
        end
    end
    local results = {}
    for bid = 0, 5 do
        if seen[bid] then
            table.insert(results, { blessingID = bid, pallyName = seen[bid] })
        end
    end
    return results
end

local function PPB_RequestAssignments()
    if GetNumRaidMembers() > 0 then
        SendAddonMessage(PP_PREFIX, "REQ", "RAID")
    elseif GetNumPartyMembers() > 0 then
        SendAddonMessage(PP_PREFIX, "REQ", "PARTY")
    end
end
-- Build a whisper string by substituting keywords in the saved template.
local function PPB_BuildMessage(template, player, buff, altbuff)
    local msg = template or DEFAULT_MSG_ASSIGNED
    msg = string.gsub(msg, "%%player%%", player  or "")
    msg = string.gsub(msg, "%%buff%%",   buff    or "")
    msg = string.gsub(msg, "%%altbuff%%",altbuff or "")
    return msg
end


-- ============================================================
-- Flyout menu
-- A pool of small icon buttons that appear above the hovered icon.
-- Only one flyout visible at a time.
-- ============================================================

local PPB_UpdateUI  -- forward declaration

local FlyoutFrame  = nil
local FlyoutBtns   = {}
local FLYOUT_BTN_SIZE = 20
local FLYOUT_PAD      = 2

local function PPB_HideFlyout()
    if FlyoutFrame then FlyoutFrame:Hide() end
end

local function PPB_BuildFlyout()
    FlyoutFrame = CreateFrame("Frame", "PPBuddyFlyout", UIParent)
    FlyoutFrame:SetFrameStrata("TOOLTIP")
    FlyoutFrame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = true, tileSize = 8, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    FlyoutFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    FlyoutFrame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    FlyoutFrame:EnableMouse(true)
    FlyoutFrame:Hide()

    -- Mouse tracking handled entirely in OnUpdate via MouseIsOver polling

    -- Build 6 blessing option buttons
    for i = 0, 5 do
        local btn = CreateFrame("Button", "PPBuddyFlyoutBtn" .. i, FlyoutFrame)
        btn:SetWidth(FLYOUT_BTN_SIZE)
        btn:SetHeight(FLYOUT_BTN_SIZE)
        btn:RegisterForClicks("LeftButtonUp")

        local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetTexture("Interface\\Buttons\\WHITE8x8")
        highlight:SetVertexColor(1, 1, 1, 0.25)

        local border = btn:CreateTexture(nil, "BACKGROUND")
        border:SetAllPoints()
        border:SetTexture("Interface\\Buttons\\WHITE8x8")
        border:SetVertexColor(0.2, 0.2, 0.2, 1)
        btn.border = border

        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT",     btn, "TOPLEFT",     1, -1)
        icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
        btn.icon = icon

        btn:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            local bname = BlessingNames[this.blessingID] or "?"
            if this.isCurrent then
                GameTooltip:SetText(bname, 0.7, 0.7, 1)
                GameTooltip:AddLine("Currently assigned buff", 0.6, 0.6, 0.6)
            else
                GameTooltip:SetText(bname, 1, 1, 1)
                GameTooltip:AddLine("Set as preferred buff", 0.8, 0.8, 0.8)
                GameTooltip:AddLine("Click to set as preferred buff", 0.8, 0.8, 0.8)
            end
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        btn:SetScript("OnClick", function()
            local assignedBid = FlyoutFrame.assignedBid
            local pallyName   = FlyoutFrame.pallyName
            local prefBid     = this.blessingID

            if prefBid == assignedBid then
                -- Clicking the assigned buff clears any preference
                PPBuddy_Config.prefs[assignedBid] = nil
                PPB_Print("Preference cleared for " .. BlessingNames[assignedBid])
            else
                -- Save preference silently — left-click on the main bar will whisper
                PPBuddy_Config.prefs[assignedBid] = prefBid
                PPB_Print("Preferred buff set to " .. BlessingNames[prefBid] .. " (left-click to whisper)")
            end

            PPB_HideFlyout()
            PPB_UpdateUI()
        end)

        FlyoutBtns[i] = btn
    end
end

local function PPB_ShowFlyout(parentBtn)
    if not FlyoutFrame then PPB_BuildFlyout() end

    local assignedBid = parentBtn.blessingID
    local prefBid     = PPBuddy_Config.prefs[assignedBid]

    FlyoutFrame.assignedBid = assignedBid
    FlyoutFrame.pallyName   = parentBtn.pallyName
    FlyoutFrame.sourceBtn   = parentBtn

    -- Size and position the flyout above the parent button
    local totalW = 6 * FLYOUT_BTN_SIZE + 5 * FLYOUT_PAD + 4
    FlyoutFrame:SetWidth(totalW)
    FlyoutFrame:SetHeight(FLYOUT_BTN_SIZE + 4)

    -- Position above the parent icon
    FlyoutFrame:ClearAllPoints()
    FlyoutFrame:SetPoint("BOTTOMLEFT", parentBtn, "TOPLEFT", 0, 2)

    for i = 0, 5 do
        local btn = FlyoutBtns[i]
        btn:SetPoint("TOPLEFT", FlyoutFrame, "TOPLEFT",
            2 + i * (FLYOUT_BTN_SIZE + FLYOUT_PAD), -2)
        btn.blessingID = i
        btn.isCurrent  = (i == assignedBid)
        btn.icon:SetTexture(BlessingIcons[i])

        -- Highlight the currently selected preference or the assigned buff
        if i == (prefBid or assignedBid) then
            btn.border:SetVertexColor(0.2, 0.5, 1, 1)   -- blue = selected
        elseif i == assignedBid then
            btn.border:SetVertexColor(0.4, 0.4, 0.4, 1) -- grey = assigned
        else
            btn.border:SetVertexColor(0.15, 0.15, 0.15, 1)
        end
        btn:Show()
    end

    FlyoutFrame:Show()
end

-- ============================================================
-- Main frame + icon buttons
-- ============================================================

local PPBFrame = nil
local PPBBtns  = {}

local ICON_SIZE = 24
local PAD       = 3
local BORDER    = 2

-- Per-button hover timer state
local hoverTimer  = 0
local hoverTarget = nil  -- the btn currently being hovered

local function PPB_CreateFrame()
    PPBFrame = CreateFrame("Frame", "PPBuddyFrame", UIParent)
    PPBFrame:SetHeight(ICON_SIZE + BORDER * 2)
    PPBFrame:SetWidth(ICON_SIZE + BORDER * 2)
    PPBFrame:SetFrameStrata("MEDIUM")
    PPBFrame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = true, tileSize = 8, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    PPBFrame:SetBackdropColor(0, 0, 0, 0.6)
    PPBFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
    PPBFrame:SetMovable(true)
    PPBFrame:EnableMouse(true)
    PPBFrame:RegisterForDrag("LeftButton")
    PPBFrame:SetScript("OnDragStart", function() this:StartMoving() end)
    PPBFrame:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        PPBuddy_Config.posX = this:GetLeft()
        PPBuddy_Config.posY = this:GetTop() * -1
    end)
    local x = PPBuddy_Config.posX or 20
    local y = PPBuddy_Config.posY or -200
    PPBFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
end

local function PPB_GetOrCreateBtn(i)
    if PPBBtns[i] then return PPBBtns[i] end

    local btn = CreateFrame("Button", "PPBuddyBtn" .. i, PPBFrame)
    btn:SetWidth(ICON_SIZE)
    btn:SetHeight(ICON_SIZE)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local border = btn:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetTexture("Interface\\Buttons\\WHITE8x8")
    border:SetVertexColor(0, 0, 0, 0)
    btn.border = border

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT",     btn, "TOPLEFT",     1, -1)
    icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
    btn.icon = icon

    local banMark = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    banMark:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 1, -1)
    banMark:SetText("")
    btn.banMark = banMark

    btn:SetScript("OnEnter", function()
        local b = this
        -- Start hover timer for flyout
        hoverTarget = b
        hoverTimer  = 0

        -- Tooltip
        GameTooltip:SetOwner(b, "ANCHOR_BOTTOMLEFT")
        local assignedBid = b.blessingID
        local prefBid     = PPBuddy_Config.prefs[assignedBid]
        local pallyStr    = b.pallyName or "?"

        if b.banned then
            GameTooltip:SetText(BlessingNames[assignedBid], 0.7, 0.7, 0.7)
            GameTooltip:AddLine("Banned - auto-removed", 1, 0.4, 0.4)
            GameTooltip:AddLine("Right-click to unban", 0.6, 0.6, 0.6)
        elseif prefBid then
            -- Has a preference set
            local prefName     = BlessingNames[prefBid]
            local assignedName = BlessingNames[assignedBid]
            if b.hasPref then
                -- Have the preferred buff
                GameTooltip:SetText(prefName, 0.4, 1, 0.4)
                GameTooltip:AddLine("You have your preferred buff", 0.6, 0.9, 0.6)
                GameTooltip:AddLine(" ", 0, 0, 0)
                GameTooltip:AddLine(pallyStr .. " is assigned to buff you " .. assignedName, 0.7, 0.7, 0.7)
            else
                -- Prefer a different buff, don't have it yet
                GameTooltip:SetText(prefName, 0.4, 0.6, 1)
                GameTooltip:AddLine("Preferred buff - missing", 0.5, 0.7, 1)
                GameTooltip:AddLine(" ", 0, 0, 0)
                GameTooltip:AddLine(pallyStr .. " is assigned to buff you " .. assignedName, 0.7, 0.7, 0.7)
                GameTooltip:AddLine("Left-click to whisper " .. pallyStr .. " for " .. prefName, 1, 1, 0)
            end
            GameTooltip:AddLine(" ", 0, 0, 0)
            GameTooltip:AddLine("Right-click to clear preference", 0.6, 0.6, 0.6)
            GameTooltip:AddLine("Hover to change preference", 0.6, 0.6, 0.6)
        elseif b.hasIt then
            GameTooltip:SetText(BlessingNames[assignedBid], 0.4, 1, 0.4)
            GameTooltip:AddLine("Assigned: " .. pallyStr, 0.8, 0.8, 0.8)
            GameTooltip:AddLine("Right-click to ban", 0.6, 0.6, 0.6)
            GameTooltip:AddLine("Hover to set preference", 0.6, 0.6, 0.6)
        else
            GameTooltip:SetText(BlessingNames[assignedBid], 1, 0.4, 0.4)
            GameTooltip:AddLine("Missing!", 1, 0.5, 0.5)
            GameTooltip:AddLine("Assigned: " .. pallyStr, 0.8, 0.8, 0.8)
            GameTooltip:AddLine("Left-click to whisper " .. pallyStr, 1, 1, 0)
            GameTooltip:AddLine("Right-click to ban", 0.6, 0.6, 0.6)
            GameTooltip:AddLine("Hover to set preference", 0.6, 0.6, 0.6)
        end
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
        if hoverTarget == this then
            hoverTarget = nil
            hoverTimer  = 0
        end
    end)

    btn:SetScript("OnClick", function()
        local b = this
        local assignedBid = b.blessingID
        local prefBid     = PPBuddy_Config.prefs[assignedBid]

        PPB_HideFlyout()

        if arg1 == "RightButton" then
            if prefBid then
                -- Clear preference
                PPBuddy_Config.prefs[assignedBid] = nil
                PPB_Print("Preference cleared for " .. BlessingNames[assignedBid])
            elseif PPBuddy_Config.banned[assignedBid] then
                PPBuddy_Config.banned[assignedBid] = nil
                PPB_Print(BlessingNames[assignedBid] .. " ban removed.")
            else
                PPBuddy_Config.banned[assignedBid] = true
                PPB_Print(BlessingNames[assignedBid] .. " banned - will auto-remove.")
                PPB_CancelBuff(assignedBid)
            end
            PPB_UpdateUI()

        elseif arg1 == "LeftButton" then
            if b.pallyName then
                local whisper
                if prefBid and prefBid ~= assignedBid then
                    local tmpl = (PPBuddy_Config.msgAlt and PPBuddy_Config.msgAlt ~= "")
                        and PPBuddy_Config.msgAlt or DEFAULT_MSG_ALT
                    whisper = PPB_BuildMessage(tmpl, b.pallyName,
                        BlessingNames[assignedBid], BlessingNames[prefBid])
                else
                    local tmpl = (PPBuddy_Config.msgAssigned and PPBuddy_Config.msgAssigned ~= "")
                        and PPBuddy_Config.msgAssigned or DEFAULT_MSG_ASSIGNED
                    whisper = PPB_BuildMessage(tmpl, b.pallyName,
                        BlessingNames[assignedBid], nil)
                end
                SendChatMessage(whisper, "WHISPER", nil, b.pallyName)
                PPB_Print("Whispered " .. b.pallyName)
            end
        end
    end)

    PPBBtns[i] = btn
    return btn
end

-- ============================================================
-- UI update
-- ============================================================

PPB_UpdateUI = function()
    if not PPBFrame then return end

    local assignments = PPB_GetMyAssignments()
    local count = table.getn(assignments)

    if count == 0 then
        PPBFrame:Hide()
        return
    end

    local totalW = BORDER * 2 + count * ICON_SIZE + (count - 1) * PAD
    PPBFrame:SetWidth(totalW)
    PPBFrame:SetHeight(ICON_SIZE + BORDER * 2)

    for i, info in ipairs(assignments) do
        local btn         = PPB_GetOrCreateBtn(i)
        local assignedBid = info.blessingID
        local prefBid     = PPBuddy_Config.prefs[assignedBid]
        local banned      = PPBuddy_Config.banned[assignedBid]

        -- Determine what buff to actually check for
        local checkBid = prefBid or assignedBid
        local hasIt    = PPB_HasBuff(checkBid)
        -- Also check if we have the assigned buff (even if pref is set)
        local hasAssigned = PPB_HasBuff(assignedBid)

        btn.blessingID = assignedBid
        btn.pallyName  = info.pallyName
        btn.hasIt      = hasIt
        btn.hasPref    = prefBid and hasIt
        btn.banned     = banned

        btn:SetPoint("TOPLEFT", PPBFrame, "TOPLEFT",
            BORDER + (i - 1) * (ICON_SIZE + PAD), -BORDER)

        -- Show the preferred icon if set, otherwise assigned
        btn.icon:SetTexture(BlessingIcons[prefBid or assignedBid])

        if banned then
            -- Grey: banned
            btn.border:SetVertexColor(0.25, 0.25, 0.25, 0.9)
            btn.icon:SetVertexColor(0.4, 0.4, 0.4)
            btn.banMark:SetText("|cffff3333x|r")
        elseif prefBid and hasIt then
            -- Green: have preferred buff
            btn.border:SetVertexColor(0, 0.7, 0, 0.8)
            btn.icon:SetVertexColor(1, 1, 1)
            btn.banMark:SetText("")
        elseif prefBid and not hasIt then
            -- Blue: preferred buff set but missing
            btn.border:SetVertexColor(0.2, 0.5, 1, 0.9)
            btn.icon:SetVertexColor(1, 1, 1)
            btn.banMark:SetText("")
        elseif hasIt then
            -- Green: have assigned buff
            btn.border:SetVertexColor(0, 0.7, 0, 0.8)
            btn.icon:SetVertexColor(1, 1, 1)
            btn.banMark:SetText("")
        else
            -- Red: assigned buff missing, no preference
            btn.border:SetVertexColor(0.8, 0, 0, 0.8)
            btn.icon:SetVertexColor(1, 1, 1)
            btn.banMark:SetText("")
        end

        btn:Show()
    end

    for i = count + 1, table.getn(PPBBtns) do
        PPBBtns[i]:Hide()
    end

    PPBFrame:Show()
end

-- ============================================================
-- Auto-remove banned buffs
-- ============================================================

local function PPB_EnforceBans()
    for bid, _ in next, PPBuddy_Config.banned do
        if PPB_HasBuff(bid) then PPB_CancelBuff(bid) end
    end
end

-- ============================================================
-- Event handler + OnUpdate
-- ============================================================

local timeSince        = 0
local uiDirty          = false
local flyoutCloseTimer = 0
local FLYOUT_CLOSE_DELAY = 0.3  -- seconds after mouse leaves before flyout closes

local PPBEventFrame = CreateFrame("Frame", "PPBuddyEventFrame", UIParent)
PPBEventFrame:RegisterEvent("PLAYER_LOGIN")
PPBEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
PPBEventFrame:RegisterEvent("PLAYER_AURAS_CHANGED")
PPBEventFrame:RegisterEvent("RAID_ROSTER_UPDATE")
PPBEventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
PPBEventFrame:RegisterEvent("CHAT_MSG_ADDON")

PPBEventFrame:SetScript("OnEvent", function()
    if event == "CHAT_MSG_ADDON" and arg1 == PP_PREFIX then
        local msg    = arg2
        local sender = arg4
        if string.find(msg, "^SELF") then
            PPB_ParseSelf(sender, msg)
            uiDirty = true
        elseif string.find(msg, "^MASSIGN") then
            PPB_ParseMassign(msg)
            uiDirty = true
        elseif string.find(msg, "^ASSIGN") then
            if not string.find(msg, "^[AMS]ASSIGN") then
                PPB_ParseAssign(msg)
                uiDirty = true
            end
        elseif string.find(msg, "^CLEAR") then
            PPB_ParseClear(sender)
            uiDirty = true
        end
        return
    end

    if event == "PLAYER_AURAS_CHANGED" then
        if initDone then PPB_EnforceBans() end
        uiDirty = true
        return
    end

    if event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" then
        PPB_PruneAssignments()
        PPB_SyncFromPP()
        uiDirty = true
        return
    end

    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LOGIN" then
        PPB_SyncFromPP()
        PPB_RequestAssignments()
        uiDirty = true
        return
    end
end)

PPBEventFrame:SetScript("OnUpdate", function()
    if not initDone then return end

    local dt = arg1

    -- Hover timer: show flyout after FLYOUT_DELAY seconds
    if hoverTarget then
        hoverTimer = hoverTimer + dt
        if hoverTimer >= FLYOUT_DELAY then
            hoverTimer = 0
            if not (FlyoutFrame and FlyoutFrame:IsVisible()) then
                PPB_ShowFlyout(hoverTarget)
            end
        end
    end

    -- Flyout hide: poll MouseIsOver every frame — no reliance on OnLeave firing
    if FlyoutFrame and FlyoutFrame:IsVisible() then
        local overFlyout = MouseIsOver(FlyoutFrame)
        local overSource = FlyoutFrame.sourceBtn and MouseIsOver(FlyoutFrame.sourceBtn)
        if overFlyout or overSource then
            flyoutCloseTimer = 0  -- reset while mouse is over
        else
            flyoutCloseTimer = flyoutCloseTimer + dt
            if flyoutCloseTimer >= FLYOUT_CLOSE_DELAY then
                flyoutCloseTimer = 0
                PPB_HideFlyout()
            end
        end
    else
        flyoutCloseTimer = 0
    end

    -- Main UI refresh
    timeSince = timeSince + dt
    if timeSince >= UPDATE_FREQ then
        timeSince = 0
        PPB_SyncFromPP()
        if uiDirty and PPBFrame then
            uiDirty = false
            PPB_UpdateUI()
        end
    end
end)


-- ============================================================
-- Config panel
-- A small draggable window with two editable message templates.
-- Opened via /ppb config
-- ============================================================

local PPBConfigFrame = nil

local function PPB_BuildConfigPanel()
    if PPBConfigFrame then
        local eb1 = getglobal("PPBuddyConfigEB1")
        local eb2 = getglobal("PPBuddyConfigEB2")
        if eb1 then eb1:SetText(PPBuddy_Config.msgAssigned or DEFAULT_MSG_ASSIGNED) end
        if eb2 then eb2:SetText(PPBuddy_Config.msgAlt      or DEFAULT_MSG_ALT)      end
        PPBConfigFrame:Show()
        return
    end

    local W, H = 480, 300
    local f = CreateFrame("Frame", "PPBuddyConfigFrame", UIParent)
    f:SetWidth(W)
    f:SetHeight(H)
    f:SetFrameStrata("DIALOG")
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    f:SetBackdropColor(0.05, 0.05, 0.08, 0.97)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop",  function() this:StopMovingOrSizing() end)
    f:SetClampedToScreen(true)
    PPBConfigFrame = f

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", f, "TOP", 0, -14)
    title:SetText("|cffffff00PPBuddy|r Message Templates")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() PPBConfigFrame:Hide() end)

    local function MakeField(ebName, label, yOffset, savedKey, defaultVal, keywords)
        local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", f, "TOPLEFT", 18, yOffset)
        lbl:SetTextColor(0.8, 0.8, 1)
        lbl:SetText(label)

        local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", f, "TOPLEFT", 18, yOffset - 16)
        hint:SetTextColor(0.5, 0.5, 0.5)
        hint:SetText(keywords)

        local box = CreateFrame("Frame", nil, f)
        box:SetPoint("TOPLEFT",  f, "TOPLEFT",  18, yOffset - 34)
        box:SetPoint("TOPRIGHT", f, "TOPRIGHT", -80, yOffset - 34)
        box:SetHeight(52)

        local boxBg = box:CreateTexture(nil, "BACKGROUND")
        boxBg:SetAllPoints()
        boxBg:SetTexture("Interface\\Buttons\\WHITE8x8")
        boxBg:SetVertexColor(0.08, 0.08, 0.12, 1)

        local boxBorder = box:CreateTexture(nil, "BORDER")
        boxBorder:SetPoint("TOPLEFT",     box, "TOPLEFT",     -1,  1)
        boxBorder:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT",  1, -1)
        boxBorder:SetTexture("Interface\\Buttons\\WHITE8x8")
        boxBorder:SetVertexColor(0.35, 0.35, 0.5, 1)

        local eb = CreateFrame("EditBox", ebName, box)
        eb:SetPoint("TOPLEFT",     box, "TOPLEFT",     4, -4)
        eb:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -4,  4)
        eb:SetMultiLine(true)
        eb:SetFontObject(ChatFontNormal)
        eb:SetTextColor(1, 1, 0.8)
        eb:SetMaxLetters(200)
        eb:SetAutoFocus(false)
        eb:EnableMouse(true)

        eb:SetScript("OnEscapePressed", function() this:ClearFocus() end)
        eb:SetScript("OnTabPressed",    function() this:ClearFocus() end)
        eb:SetScript("OnEditFocusGained", function()
            boxBorder:SetVertexColor(0.5, 0.7, 1, 1)
        end)
        eb:SetScript("OnEditFocusLost", function()
            boxBorder:SetVertexColor(0.35, 0.35, 0.5, 1)
            local val = string.gsub(this:GetText(), "\n", "")
            if val == "" then
                PPBuddy_Config[savedKey] = defaultVal
                this:SetText(defaultVal)
            else
                PPBuddy_Config[savedKey] = val
            end
        end)

        local reset = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        reset:SetPoint("TOPLEFT", box, "TOPRIGHT", 4, 0)
        reset:SetWidth(58)
        reset:SetHeight(26)
        reset:SetText("Reset")
        reset:SetScript("OnClick", function()
            PPBuddy_Config[savedKey] = defaultVal
            eb:SetText(defaultVal)
        end)

        return eb
    end

    local eb1 = MakeField(
        "PPBuddyConfigEB1",
        "Assigned buff whisper  (regular request)",
        -38, "msgAssigned", DEFAULT_MSG_ASSIGNED,
        "Keywords:  %player%  %buff%"
    )
    local eb2 = MakeField(
        "PPBuddyConfigEB2",
        "Alternate buff whisper  (swap request)",
        -148, "msgAlt", DEFAULT_MSG_ALT,
        "Keywords:  %player%  %buff%  %altbuff%"
    )

    local footer = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 14)
    footer:SetTextColor(0.4, 0.4, 0.4)
    footer:SetText("Changes save automatically when you click away.")

    eb1:SetText(PPBuddy_Config.msgAssigned or DEFAULT_MSG_ASSIGNED)
    eb2:SetText(PPBuddy_Config.msgAlt      or DEFAULT_MSG_ALT)
    f:Show()
end


-- ============================================================
-- Slash commands
-- ============================================================

SlashCmdList["PPBUDDY"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "show" then
        if not PPBFrame then PPB_Init() end
        PPB_SyncFromPP()
        PPB_UpdateUI()
        if PPBFrame then PPBFrame:Show() end
    elseif msg == "hide" then
        if PPBFrame then PPBFrame:Hide() end
    elseif msg == "reset" then
        if PPBFrame then
            PPBFrame:ClearAllPoints()
            PPBFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -200)
            PPBuddy_Config.posX = 20
            PPBuddy_Config.posY = -200
        end
    elseif msg == "bans" then
        PPB_Print("Banned blessings:")
        local any = false
        for bid, _ in next, PPBuddy_Config.banned do
            PPB_Print("  - " .. (BlessingNames[bid] or tostring(bid)))
            any = true
        end
        if not any then PPB_Print("  (none)") end
    elseif msg == "clearbans" then
        PPBuddy_Config.banned = {}
        PPB_Print("All bans cleared.")
        PPB_UpdateUI()
    elseif msg == "prefs" then
        PPB_Print("Preferences:")
        local any = false
        for assignedBid, prefBid in next, PPBuddy_Config.prefs do
            PPB_Print("  " .. BlessingNames[assignedBid] .. " -> " .. BlessingNames[prefBid])
            any = true
        end
        if not any then PPB_Print("  (none)") end
    elseif msg == "clearprefs" then
        PPBuddy_Config.prefs = {}
        PPB_Print("All preferences cleared.")
        PPB_UpdateUI()
    elseif msg == "config" then
        PPB_BuildConfigPanel()
    elseif msg == "debug" then
        local _, token = UnitClass("player")
        local myID = ClassTokenToID[token]
        PPB_Print("=== PPBuddy Debug ===")
        PPB_Print("Class: " .. tostring(token) .. " -> PP classID: " .. tostring(myID))
        PPB_Print("PP globals present: " .. (PallyPower_Assignments and "YES" or "NO"))
        local count = 0
        for pallyName, assignments in next, PPB_Assignments do
            count = count + 1
            local line = "  " .. tostring(pallyName) .. ": "
            if type(assignments) == "table" then
                for classID = 0, 9 do
                    local bid = assignments[classID]
                    if bid and bid ~= -1 then
                        line = line .. "[c" .. classID .. "=" .. (BlessingNames[bid] or tostring(bid)) .. "] "
                    end
                end
            end
            PPB_Print(line)
        end
        if count == 0 then PPB_Print("  No assignments known yet.") end
        local found = PPB_GetMyAssignments()
        PPB_Print("My buffs (" .. table.getn(found) .. "):")
        for _, info in ipairs(found) do
            PPB_Print("  " .. BlessingNames[info.blessingID] .. " from " .. info.pallyName)
        end
    else
        PPB_Print("PPBuddy commands:")
        PPB_Print("  /ppb show, hide, reset")
        PPB_Print("  /ppb config")
        PPB_Print("  /ppb bans, clearbans")
        PPB_Print("  /ppb prefs, clearprefs")
        PPB_Print("  /ppb debug")
    end
end
SLASH_PPBUDDY1 = "/ppb"
SLASH_PPBUDDY2 = "/ppbuddy"

-- ============================================================
-- Init
-- ============================================================

function PPB_Init()
    if initDone then return end
    initDone = true
    if not PPBuddy_Config          then PPBuddy_Config         = {} end
    if not PPBuddy_Config.banned   then PPBuddy_Config.banned  = {} end
    if not PPBuddy_Config.prefs      then PPBuddy_Config.prefs      = {} end
    if not PPBuddy_Config.msgAssigned then PPBuddy_Config.msgAssigned = DEFAULT_MSG_ASSIGNED end
    if not PPBuddy_Config.msgAlt      then PPBuddy_Config.msgAlt      = DEFAULT_MSG_ALT      end
    PPB_CreateFrame()
    PPB_SyncFromPP()
    PPB_UpdateUI()
    PPB_RequestAssignments()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("VARIABLES_LOADED")
initFrame:SetScript("OnEvent", function() PPB_Init() end)
