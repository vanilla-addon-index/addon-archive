--[[--------------------------------------------------------------------
  Time To Drink  -  Turtle WoW (vanilla 1.12) addon   v1.1
  Watches a chosen healer's mana while you are in a 5-man party
  (disabled in raids) and announces in party chat when they drop
  below a configurable threshold, repeating on an adjustable cooldown.

  Slash commands:
    /ttd            toggle the window
    /ttd status     print current settings + party state
    /ttd test       send a test line to party chat
    /ttd debug      toggle verbose messages
----------------------------------------------------------------------]]

TimeToDrink = {}
local TTD = TimeToDrink

TTD.roster         = {}
TTD.selectedHealer = nil
TTD.threshold      = 40
TTD.cooldown       = 15
TTD.lastAnnounce   = 0
TTD.wasInParty     = false
TTD.pollElapsed    = 0
TTD.debug          = false
TTD.inWorld        = false
TTD.initialized    = false
TTD.disabled       = false
TTD.locked         = false
TTD.pos            = nil
TTD.mmbAngle       = 200
TTD.mmbHidden      = false

local MIN_COOLDOWN  = 10
local POLL_INTERVAL = 0.5

local function msg(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99TTD:|r " .. text)
end
local function dbg(text)
    if TTD.debug then DEFAULT_CHAT_FRAME:AddMessage("|cff8888ffTTD debug:|r " .. text) end
end
local function err(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cffff4040TTD error:|r " .. tostring(text))
end

function TTD_SaveHealer()
    if type(TimeToDrinkDB) == "table" then TimeToDrinkDB.healer = TTD.selectedHealer end
end

local function TTD_InFivePlayerParty()
    if GetNumRaidMembers() > 0 then return false end
    return GetNumPartyMembers() > 0
end

local function TTD_ClampThreshold(v)
    if not v then return TTD.threshold end
    if v < 1 then v = 1 end
    if v > 100 then v = 100 end
    return math.floor(v)
end

local function TTD_ClampCooldown(v)
    if not v then return TTD.cooldown end
    if v < MIN_COOLDOWN then v = MIN_COOLDOWN end
    return math.floor(v)
end

function TTD_RefreshRoster()
    TTD.roster = {}
    if not TTD_InFivePlayerParty() then return end
    local myname = UnitName("player")
    table.insert(TTD.roster, myname)
    local n = GetNumPartyMembers()
    local i = 1
    while i <= n do
        local nm = UnitName("party" .. i)
        if nm then table.insert(TTD.roster, nm) end
        i = i + 1
    end
    if TTD.selectedHealer then
        local found = false
        local j = 1
        while j <= table.getn(TTD.roster) do
            if TTD.roster[j] == TTD.selectedHealer then found = true end
            j = j + 1
        end
        if not found then TTD.selectedHealer = nil end
    end
end

local function TTD_UnitForName(name)
    if not name then return nil end
    if UnitName("player") == name then return "player" end
    local n = GetNumPartyMembers()
    local i = 1
    while i <= n do
        if UnitName("party" .. i) == name then return "party" .. i end
        i = i + 1
    end
    return nil
end

function TTD_InitHealerDropdown()
    local dd = TimeToDrinkHealerDropdown
    if not dd then return end
    UIDropDownMenu_Initialize(dd, function()
        local i = 1
        while i <= table.getn(TTD.roster) do
            local nm   = TTD.roster[i]
            local info = {}
            info.text  = nm
            info.value = nm
            info.func  = function()
                TTD.selectedHealer = nm
                TTD_SaveHealer()
                local t = getglobal("TimeToDrinkHealerDropdownText")
                if t then t:SetText(nm) end
                dbg("healer set to " .. nm)
                if TTD_InFivePlayerParty() and not TTD.disabled then
                    SendChatMessage(nm .. " has been set as the healer in Time To Drink.  The party will be alerted when they drop below " .. TTD.threshold .. "% mana.", "PARTY")
                end
            end
            UIDropDownMenu_AddButton(info)
            i = i + 1
        end
    end)

    local t = getglobal("TimeToDrinkHealerDropdownText")
    if TTD.selectedHealer then
        if t then t:SetText(TTD.selectedHealer) end
    else
        if t then t:SetText("Select healer") end
    end
end

function TTD_UpdateLockVisual()
    local lock = TimeToDrinkLockButton
    if not lock then return end
    if TTD.locked then
        lock:SetNormalTexture("Interface\\Buttons\\LockButton-Locked-Up")
        lock:SetPushedTexture("Interface\\Buttons\\LockButton-Locked-Up")
    else
        lock:SetNormalTexture("Interface\\Buttons\\LockButton-Unlocked-Up")
        lock:SetPushedTexture("Interface\\Buttons\\LockButton-Unlocked-Up")
    end
    lock:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
end

function TTD_UpdateReadout()
    local st = TimeToDrinkStatus
    if st then
        if not TTD.selectedHealer then
            st:SetText("Alerts inactive: no healer selected.")
        elseif TTD.disabled then
            st:SetText("Alerts muted (quiet mode).")
        else
            st:SetText("Alerts active.")
        end
    end
    local fs = TimeToDrinkReadout
    if not fs then return end
    if not TTD.selectedHealer then
        fs:SetText("Healer mana: (none selected)")
        fs:SetTextColor(0.7, 0.7, 0.7)
        return
    end
    local unit = TTD_UnitForName(TTD.selectedHealer)
    if not unit or not UnitExists(unit) then
        fs:SetText(TTD.selectedHealer .. ": not in party")
        fs:SetTextColor(0.7, 0.7, 0.7)
        return
    end
    if UnitPowerType(unit) ~= 0 then
        fs:SetText(TTD.selectedHealer .. " mana: n/a (shapeshifted)")
        fs:SetTextColor(0.7, 0.7, 0.7)
        return
    end
    local mm = UnitManaMax(unit)
    if not mm or mm == 0 then
        fs:SetText(TTD.selectedHealer .. " mana: --")
        fs:SetTextColor(0.7, 0.7, 0.7)
        return
    end
    local pct = math.floor((UnitMana(unit) / mm) * 100)
    fs:SetText(TTD.selectedHealer .. " mana: " .. pct .. "%")
    if pct < TTD.threshold then
        fs:SetTextColor(1.0, 0.3, 0.3)
    else
        fs:SetTextColor(0.4, 1.0, 0.4)
    end
end

local function TTD_CreateUI()
    if TimeToDrinkUI then return end

    local f = CreateFrame("Frame", "TimeToDrinkUI", UIParent)
    f:SetWidth(172)
    f:SetHeight(200)
    f:SetClampedToScreen(true)
    if TTD.pos and TTD.pos.point and TTD.pos.relPoint and TTD.pos.x and TTD.pos.y then
        f:SetPoint(TTD.pos.point, UIParent, TTD.pos.relPoint, TTD.pos.x, TTD.pos.y)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    end
    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() if not TTD.locked then this:StartMoving() end end)
    f:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        local point, _, relPoint, x, y = this:GetPoint()
        TTD.pos = { point = point, relPoint = relPoint, x = x, y = y }
    end)
    f:Hide()

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", f, "TOP", 0, -14)
    title:SetText("Time To Drink")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)

    local lock = CreateFrame("Button", "TimeToDrinkLockButton", f)
    lock:SetWidth(24); lock:SetHeight(24)
    lock:SetPoint("RIGHT", close, "LEFT", 2, 0)
    lock:SetScript("OnClick", function()
        TTD.locked = not TTD.locked
        TTD_UpdateLockVisual()
    end)
    TTD_UpdateLockVisual()

    -- Healer selector
    local hl = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hl:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -38)
    hl:SetText("Healer")

    local dd = CreateFrame("Frame", "TimeToDrinkHealerDropdown", f, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", hl, "BOTTOMLEFT", -16, -2)

    -- Threshold row
    local tl = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tl:SetWidth(60); tl:SetJustifyH("LEFT")
    tl:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -84)
    tl:SetText("Alert below")

    local te = CreateFrame("EditBox", "TimeToDrinkThresholdEdit", f, "InputBoxTemplate")
    te:SetWidth(38); te:SetHeight(18)
    te:SetPoint("LEFT", tl, "RIGHT", 2, 0)
    te:SetAutoFocus(false)
    te:SetMaxLetters(3)
    te:SetText("" .. TTD.threshold)
    te:SetScript("OnTextChanged", function()
        local s = this:GetText()
        local clean = string.gsub(s, "[^0-9]", "")
        if clean ~= s then this:SetText(clean) end
    end)
    local function commitThreshold()
        TTD.threshold = TTD_ClampThreshold(tonumber(this:GetText()))
        this:SetText("" .. TTD.threshold)
        this:ClearFocus()
    end
    te:SetScript("OnEnterPressed", commitThreshold)
    te:SetScript("OnEditFocusLost", commitThreshold)

    local tu = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tu:SetPoint("LEFT", te, "RIGHT", 6, 0)
    tu:SetText("% mana")

    -- Cooldown row
    local cl = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cl:SetWidth(60); cl:SetJustifyH("LEFT")
    cl:SetPoint("TOPLEFT", tl, "BOTTOMLEFT", 0, -14)
    cl:SetText("Repeat every")

    local ce = CreateFrame("EditBox", "TimeToDrinkCooldownEdit", f, "InputBoxTemplate")
    ce:SetWidth(38); ce:SetHeight(18)
    ce:SetPoint("LEFT", cl, "RIGHT", 2, 0)
    ce:SetAutoFocus(false)
    ce:SetMaxLetters(4)
    ce:SetText("" .. TTD.cooldown)
    ce:SetScript("OnTextChanged", function()
        local s = this:GetText()
        local clean = string.gsub(s, "[^0-9]", "")
        if clean ~= s then this:SetText(clean) end
    end)
    local function commitCooldown()
        TTD.cooldown = TTD_ClampCooldown(tonumber(this:GetText()))
        this:SetText("" .. TTD.cooldown)
        this:ClearFocus()
    end
    ce:SetScript("OnEnterPressed", commitCooldown)
    ce:SetScript("OnEditFocusLost", commitCooldown)

    local cu = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cu:SetPoint("LEFT", ce, "RIGHT", 6, 0)
    cu:SetText("sec")

    -- Mute toggle
    local cb = CreateFrame("CheckButton", "TimeToDrinkDisableCheck", f, "UICheckButtonTemplate")
    cb:SetWidth(20); cb:SetHeight(20)
    cb:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -128)
    local cbText = getglobal("TimeToDrinkDisableCheckText")
    if cbText then cbText:SetText("Mute alerts") end
    cb:SetChecked(TTD.disabled)
    cb:SetScript("OnClick", function()
        if this:GetChecked() then TTD.disabled = true else TTD.disabled = false end
        dbg("disabled = " .. tostring(TTD.disabled))
    end)

    -- Live readout + status
    local readout = f:CreateFontString("TimeToDrinkReadout", "OVERLAY", "GameFontNormalSmall")
    readout:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -152)
    readout:SetText("Healer mana: (none selected)")

    local status = f:CreateFontString("TimeToDrinkStatus", "OVERLAY", "GameFontDisableSmall")
    status:SetPoint("BOTTOM", f, "BOTTOM", 0, 12)
    status:SetText("Pick a healer to activate alerts.")
end

function TTD_ShowUI()
    TTD_CreateUI()
    TTD_RefreshRoster()
    TTD_InitHealerDropdown()
    if TimeToDrinkThresholdEdit then TimeToDrinkThresholdEdit:SetText("" .. TTD.threshold) end
    if TimeToDrinkCooldownEdit  then TimeToDrinkCooldownEdit:SetText("" .. TTD.cooldown) end
    if TimeToDrinkDisableCheck  then TimeToDrinkDisableCheck:SetChecked(TTD.disabled) end
    TTD_UpdateReadout()
    TimeToDrinkUI:Show()
end

function TTD_ToggleUI()
    TTD_CreateUI()
    if TimeToDrinkUI:IsShown() then
        TimeToDrinkUI:Hide()
    else
        TTD_ShowUI()
    end
end

local function TTD_CheckHealer()
    if not TTD.inWorld then return end
    if TTD.disabled then return end
    if not TTD_InFivePlayerParty() then return end
    if not TTD.selectedHealer then return end
    local unit = TTD_UnitForName(TTD.selectedHealer)
    if not unit or not UnitExists(unit) then return end
    if UnitIsDeadOrGhost(unit) then return end
    if UnitPowerType(unit) ~= 0 then return end
    local maxMana = UnitManaMax(unit)
    if not maxMana or maxMana == 0 then return end
    local pct = (UnitMana(unit) / maxMana) * 100
    if pct < TTD.threshold then
        if (GetTime() - TTD.lastAnnounce) >= TTD.cooldown then
            SendChatMessage("The healer has less than " .. TTD.threshold .. "% mana", "PARTY")
            TTD.lastAnnounce = GetTime()
            dbg("announced (" .. math.floor(pct) .. "% now)")
        end
    end
end

local driver = CreateFrame("Frame", "TimeToDrinkDriver", UIParent)
driver:RegisterEvent("VARIABLES_LOADED")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("PARTY_MEMBERS_CHANGED")
driver:RegisterEvent("RAID_ROSTER_UPDATE")
driver:RegisterEvent("PLAYER_LOGOUT")
driver:RegisterEvent("CHAT_MSG_PARTY")
driver:RegisterEvent("CHAT_MSG_PARTY_LEADER")

driver:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        if type(TimeToDrinkDB) ~= "table" then TimeToDrinkDB = {} end
        if TimeToDrinkDB.threshold then TTD.threshold = TTD_ClampThreshold(TimeToDrinkDB.threshold) end
        if TimeToDrinkDB.cooldown  then TTD.cooldown  = TTD_ClampCooldown(TimeToDrinkDB.cooldown) end
        if TimeToDrinkDB.disabled ~= nil then TTD.disabled = TimeToDrinkDB.disabled end
        if TimeToDrinkDB.locked ~= nil then TTD.locked = TimeToDrinkDB.locked end
        if TimeToDrinkDB.pos then TTD.pos = TimeToDrinkDB.pos end
        if TimeToDrinkDB.mmbAngle then TTD.mmbAngle = TimeToDrinkDB.mmbAngle end
        if TimeToDrinkDB.mmbHidden ~= nil then TTD.mmbHidden = TimeToDrinkDB.mmbHidden end
        TTD_CreateMinimapButton()
        TTD_UpdateMinimapButtonPosition()
        if TimeToDrinkMinimapButton then
            if TTD.mmbHidden then TimeToDrinkMinimapButton:Hide() else TimeToDrinkMinimapButton:Show() end
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        TTD.inWorld = true
        if not TTD.initialized then
            TTD.wasInParty = TTD_InFivePlayerParty()
            -- Restore the saved healer only if still grouped with them
            -- (covers reload / reconnect). A genuine new party clears it on join.
            if type(TimeToDrinkDB) == "table" and TimeToDrinkDB.healer
               and TTD_InFivePlayerParty() and TTD_UnitForName(TimeToDrinkDB.healer) then
                TTD.selectedHealer = TimeToDrinkDB.healer
            else
                TTD.selectedHealer = nil
                TTD_SaveHealer()
            end
            TTD.initialized = true
        end

    elseif event == "PLAYER_LOGOUT" then
        if type(TimeToDrinkDB) ~= "table" then TimeToDrinkDB = {} end
        TimeToDrinkDB.threshold = TTD.threshold
        TimeToDrinkDB.cooldown  = TTD.cooldown
        TimeToDrinkDB.disabled  = TTD.disabled
        TimeToDrinkDB.locked    = TTD.locked
        TimeToDrinkDB.pos       = TTD.pos
        TimeToDrinkDB.healer    = TTD.selectedHealer
        TimeToDrinkDB.mmbAngle  = TTD.mmbAngle
        TimeToDrinkDB.mmbHidden = TTD.mmbHidden

    elseif event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_PARTY_LEADER" then
        -- If anyone (any client) posts the low-mana alert, start our cooldown too,
        -- so multiple copies of the addon don't double up.
        if arg1 and string.find(arg1, "has less than", 1, true) and string.find(arg1, "mana", 1, true) then
            TTD.lastAnnounce = GetTime()
        end

    elseif event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
        local inParty = TTD_InFivePlayerParty()
        local prevHealer = TTD.selectedHealer
        TTD_RefreshRoster()
        -- Designated healer left, while we were already grouped (not on a fresh join).
        if prevHealer and not TTD.selectedHealer and TTD.inWorld and not TTD.disabled
           and TTD.wasInParty and TTD_InFivePlayerParty() then
            SendChatMessage("The healer has left the party, please designate a new healer, or mute the addon.", "PARTY")
        end
        if prevHealer and not TTD.selectedHealer then TTD_SaveHealer() end
        -- On joining a fresh party, require the player to pick a healer again.
        if TTD.inWorld and inParty and not TTD.wasInParty then
            TTD.selectedHealer = nil
            TTD_SaveHealer()
            local ok, e = pcall(TTD_ShowUI)
            if not ok then err(e) end
        end
        if TimeToDrinkUI and TimeToDrinkUI:IsShown() then TTD_InitHealerDropdown() end
        if TimeToDrinkUI and TimeToDrinkUI:IsShown() then TTD_UpdateReadout() end
        TTD.wasInParty = inParty
    end
end)
driver:Show()

driver:SetScript("OnUpdate", function()
    TTD.pollElapsed = TTD.pollElapsed + arg1
    if TTD.pollElapsed < POLL_INTERVAL then return end
    TTD.pollElapsed = 0
    if TimeToDrinkUI and TimeToDrinkUI:IsShown() then TTD_UpdateReadout() end
    TTD_CheckHealer()
end)

-- ===== Minimap button (Morning Glory Dew icon, item 8766) =====
function TTD_UpdateMinimapButtonPosition()
    local btn = TimeToDrinkMinimapButton
    if not btn then return end
    local rad = (TTD.mmbAngle or 200) * math.pi / 180
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * 80, math.sin(rad) * 80)
end

function TTD_MinimapButtonDragUpdate()
    local mx, my = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local px, py = GetCursorPosition()
    if not (mx and px and scale) then return end
    px = px / scale
    py = py / scale
    TTD.mmbAngle = math.deg(math.atan2(py - my, px - mx))
    TTD_UpdateMinimapButtonPosition()
end

function TTD_CreateMinimapButton()
    if TimeToDrinkMinimapButton then return end
    if not Minimap then return end

    local btn = CreateFrame("Button", "TimeToDrinkMinimapButton", Minimap)
    btn:SetWidth(31); btn:SetHeight(31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:EnableMouse(true)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")

    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetWidth(20); icon:SetHeight(20)
    icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 6, -6)
    local tex = nil
    if GetItemIcon then tex = GetItemIcon(8766) end
    icon:SetTexture(tex or "Interface\\Icons\\INV_Drink_10")

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetWidth(53); border:SetHeight(53)
    border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    btn:SetScript("OnClick", function() TTD_ToggleUI() end)
    btn:SetScript("OnDragStart", function() this:SetScript("OnUpdate", TTD_MinimapButtonDragUpdate) end)
    btn:SetScript("OnDragStop", function()
        this:SetScript("OnUpdate", nil)
        if type(TimeToDrinkDB) == "table" then TimeToDrinkDB.mmbAngle = TTD.mmbAngle end
    end)
    btn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:AddLine("Time To Drink")
        GameTooltip:AddLine("Click to open. Drag to move.", 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    TTD_UpdateMinimapButtonPosition()
    if TTD.mmbHidden then btn:Hide() end
end

SLASH_TIMETODRINK1 = "/ttd"
SLASH_TIMETODRINK2 = "/timetodrink"
SlashCmdList["TIMETODRINK"] = function(arg)
    local cmd = string.lower(arg or "")

    if cmd == "status" then
        msg("disabled=" .. tostring(TTD.disabled) .. "  threshold=" .. TTD.threshold .. "%  cooldown=" .. TTD.cooldown .. "s  healer=" ..
            (TTD.selectedHealer or "none") .. "  inParty=" .. tostring(TTD_InFivePlayerParty()) ..
            "  raid=" .. tostring(GetNumRaidMembers() > 0))
        return
    end

    if cmd == "test" then
        if TTD_InFivePlayerParty() then
            SendChatMessage("Time To Drink test - if you see this, chat works.", "PARTY")
            msg("sent test line to party chat.")
        else
            msg("not in a 5-man party, so nothing was sent to party chat.")
        end
        return
    end

    if cmd == "debug" then
        TTD.debug = not TTD.debug
        msg("debug " .. (TTD.debug and "ON" or "OFF"))
        return
    end

    if cmd == "reset" then
        TTD.pos = nil
        local ok, e = pcall(function()
            TTD_CreateUI()
            TimeToDrinkUI:ClearAllPoints()
            TimeToDrinkUI:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
            TimeToDrinkUI:Show()
        end)
        if ok then msg("window reset to center of screen.") else err(e) end
        return
    end

    if cmd == "enable" then
        TTD.disabled = false
        if TimeToDrinkDisableCheck then TimeToDrinkDisableCheck:SetChecked(false) end
        msg("alerts ENABLED (pick a healer to activate).")
        return
    end

    if cmd == "disable" then
        TTD.disabled = true
        if TimeToDrinkDisableCheck then TimeToDrinkDisableCheck:SetChecked(true) end
        msg("alerts DISABLED (muted).")
        return
    end

    if cmd == "minimap" then
        TTD.mmbHidden = not TTD.mmbHidden
        TTD_CreateMinimapButton()
        if TimeToDrinkMinimapButton then
            if TTD.mmbHidden then TimeToDrinkMinimapButton:Hide() else TimeToDrinkMinimapButton:Show() end
        end
        if type(TimeToDrinkDB) == "table" then TimeToDrinkDB.mmbHidden = TTD.mmbHidden end
        msg("minimap button " .. (TTD.mmbHidden and "hidden" or "shown"))
        return
    end

    local ok, e = pcall(TTD_ToggleUI)
    if not ok then err(e) end
end

msg("loaded v1.10. /ttd open, /ttd reset, /ttd enable, /ttd disable, /ttd minimap, /ttd status. (5-man parties only)")
