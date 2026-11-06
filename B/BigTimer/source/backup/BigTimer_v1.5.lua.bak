--[[
    BigTimer.lua  v1.5
    WoW 1.12 / Lua 5 -- requires BigWigs with Pulltimer plugin
--]]

local ADDON    = "BigTimer"
local BTN_W    = 36
local BTN_H    = 26
local BTN_GAP  = 2
local PAD      = 5
local SET_W    = 180
local SET_H    = 168
local VIS_POLL = 2.0

local DEFAULTS = {
    barAbsX    = 400,
    barAbsY    = 300,
    scalePct   = 100,
    horizontal = true,
    locked     = false,
    setAbsX    = nil,
    setAbsY    = nil,
    breakMins  = 3,
}

BigTimerDB = BigTimerDB or {}
local function InitDB()
    if BigTimerDB.scaleIdx ~= nil then
        BigTimerDB.scaleIdx = nil
    end
    for k, v in pairs(DEFAULTS) do
        if BigTimerDB[k] == nil then BigTimerDB[k] = v end
    end
end

local function ScaleFromPct(pct)
    return (pct or 100) / 100.0
end

local function FrameAbsPos(f)
    local es = f:GetEffectiveScale()
    return (f:GetLeft() or 0) * es, (f:GetBottom() or 0) * es
end

local function SetFrameAbsPos(f, absX, absY)
    local es = f:GetEffectiveScale()
    f:ClearAllPoints()
    f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", absX / es, absY / es)
end

local function ShouldShow()
    return GetNumRaidMembers() > 0 and (IsRaidLeader() or IsRaidOfficer())
end

local function FirePull(seconds, isBreak)
    if isBreak then
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cffffff66[BigTimer]|r Break timer started: " ..
            BigTimerDB.breakMins .. " min (" ..
            (BigTimerDB.breakMins * 60) ..
            "s).  BigWigs always labels its bar \"Pull\".")
    end
    if SlashCmdList and SlashCmdList["BWPT_SHORTHAND"] then
        SlashCmdList["BWPT_SHORTHAND"](tostring(seconds))
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffff6600[BigTimer]|r BigWigs Pulltimer not loaded.")
    end
end

local mainFrame, settingsFrame
local buttons = {}
local UpdateLayout, UpdateVisibility

-- Hover counter: tracks how many children are under the mouse.
-- Only fades to 25% when ALL of them have fired OnLeave (count == 0).
-- Prevents flickering when moving between adjacent buttons.
local hoverCount = 0
local function OnAnyEnter()
    hoverCount = hoverCount + 1
    mainFrame:SetAlpha(1.0)
end
local function OnAnyLeave()
    hoverCount = hoverCount - 1
    if hoverCount <= 0 then
        hoverCount = 0
        mainFrame:SetAlpha(0.25)
    end
end

UpdateLayout = function()
    local n, isH = table.getn(buttons), BigTimerDB.horizontal
    local fw = isH and (PAD*2 + n*BTN_W + (n-1)*BTN_GAP) or (PAD*2 + BTN_W)
    local fh = isH and (PAD*2 + BTN_H) or (PAD*2 + n*BTN_H + (n-1)*BTN_GAP)
    mainFrame:SetWidth(fw)
    mainFrame:SetHeight(fh)
    for i, btn in ipairs(buttons) do
        btn:ClearAllPoints()
        if isH then
            btn:SetPoint("TOPLEFT", mainFrame, "TOPLEFT",
                PAD + (i-1)*(BTN_W+BTN_GAP), -PAD)
            btn:SetWidth(BTN_W)
        else
            btn:SetPoint("TOPLEFT", mainFrame, "TOPLEFT",
                PAD, -(PAD + (i-1)*(BTN_H+BTN_GAP)))
            btn:SetWidth(fw - PAD*2)
        end
        btn:SetHeight(BTN_H)
    end
end

UpdateVisibility = function()
    if ShouldShow() then
        mainFrame:Show()
    else
        mainFrame:Hide()
        if settingsFrame then settingsFrame:Hide() end
    end
end

-- MakeButton always wires OnEnter/OnLeave into the hover counter.
-- Pass nil for tip on buttons that override OnEnter afterwards.
local function MakeButton(label, tip)
    local btn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    btn:SetWidth(BTN_W)
    btn:SetHeight(BTN_H)
    btn:SetText(label)
    btn:SetScript("OnEnter", function()
        OnAnyEnter()
        if tip then
            GameTooltip:SetOwner(this, "ANCHOR_TOP")
            GameTooltip:SetText(tip, 1, 1, 1)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function()
        OnAnyLeave()
        GameTooltip:Hide()
    end)
    return btn
end

local function BuildSettingsFrame()
    local f = CreateFrame("Frame", "BigTimerSettingsFrame", UIParent)
    f:SetFrameStrata("DIALOG")
    f:SetWidth(SET_W)
    f:SetHeight(SET_H)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=10,
        insets={left=3,right=3,top=3,bottom=3},
    })
    f:SetBackdropColor(0.08, 0.08, 0.14, 0.95)
    f:SetBackdropBorderColor(0.45, 0.45, 0.65, 1.0)
    f:Hide()

    -- Escape key closes this window
    table.insert(UISpecialFrames, "BigTimerSettingsFrame")

    f:SetScript("OnMouseDown", function() this:StartMoving() end)
    f:SetScript("OnMouseUp", function()
        this:StopMovingOrSizing()
        local ax, ay = FrameAbsPos(this)
        BigTimerDB.setAbsX, BigTimerDB.setAbsY = ax, ay
    end)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", f, "TOP", 0, -7)
    title:SetText("|cffffff99BigTimer|r  |cff888888By Fayz|r")

    -- Break slider
    local bHdr = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bHdr:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -24)
    bHdr:SetText("Break Duration:")

    local bSl = CreateFrame("Slider","BigTimerBreakSlider",f,"OptionsSliderTemplate")
    bSl:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -40)
    bSl:SetWidth(SET_W - 20)
    bSl:SetMinMaxValues(1, 10)
    bSl:SetValueStep(1)
    bSl:SetValue(BigTimerDB.breakMins)
    getglobal("BigTimerBreakSliderLow"):SetText("1m")
    getglobal("BigTimerBreakSliderHigh"):SetText("10m")

    local bVal = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bVal:SetPoint("TOP", bSl, "BOTTOM", 0, 2)
    bVal:SetText(BigTimerDB.breakMins.." min  ("..(BigTimerDB.breakMins*60).."s)")
    bSl:SetScript("OnValueChanged", function()
        local v = math.floor(this:GetValue()+0.5)
        BigTimerDB.breakMins = v
        bVal:SetText(v.." min  ("..(v*60).."s)")
    end)

    -- Scale slider (25% to 200% in 1% steps)
    local sHdr = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sHdr:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -84)
    sHdr:SetText("Scale:")

    local sSl = CreateFrame("Slider","BigTimerScaleSlider",f,"OptionsSliderTemplate")
    sSl:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -100)
    sSl:SetWidth(SET_W - 20)
    sSl:SetMinMaxValues(25, 200)
    sSl:SetValueStep(1)
    sSl:SetValue(BigTimerDB.scalePct)
    getglobal("BigTimerScaleSliderLow"):SetText("Smaller")
    getglobal("BigTimerScaleSliderHigh"):SetText("Larger")

    sSl:SetScript("OnValueChanged", function()
        local v = math.floor(this:GetValue() + 0.5)
        BigTimerDB.scalePct = v
        local sc = ScaleFromPct(v)
        local absX, absY = FrameAbsPos(mainFrame)
        mainFrame:SetScale(sc)
        SetFrameAbsPos(mainFrame, absX, absY)
        BigTimerDB.barAbsX, BigTimerDB.barAbsY = absX, absY
    end)

    -- Orientation button
    local oBtn = CreateFrame("Button","BigTimerOrientBtn",f,"UIPanelButtonTemplate")
    oBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 10)
    oBtn:SetWidth(90)
    oBtn:SetHeight(20)
    oBtn:SetText(BigTimerDB.horizontal and "Vertical" or "Horizontal")
    oBtn:SetScript("OnClick", function()
        BigTimerDB.horizontal = not BigTimerDB.horizontal
        this:SetText(BigTimerDB.horizontal and "Vertical" or "Horizontal")
        UpdateLayout()
    end)

    -- Lock checkbox
    local lLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lLbl:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 15)
    lLbl:SetText("Lock Bar")

    local lCB = CreateFrame("CheckButton","BigTimerLockCB",f,"UICheckButtonTemplate")
    lCB:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 8)
    lCB:SetWidth(22)
    lCB:SetHeight(22)
    lCB:SetChecked(BigTimerDB.locked and 1 or nil)
    lCB:SetScript("OnClick", function()
        BigTimerDB.locked = (this:GetChecked() == 1)
        mainFrame:SetMovable(not BigTimerDB.locked)
    end)

    return f
end

local function OpenSettings()
    if settingsFrame:IsShown() then settingsFrame:Hide(); return end
    if BigTimerDB.setAbsX and BigTimerDB.setAbsY then
        SetFrameAbsPos(settingsFrame, BigTimerDB.setAbsX, BigTimerDB.setAbsY)
    else
        local bx, by = FrameAbsPos(mainFrame)
        local bh = mainFrame:GetHeight() * mainFrame:GetEffectiveScale()
        local sy = by + bh + 8
        if (sy + SET_H) > GetScreenHeight() then sy = by - SET_H - 8 end
        SetFrameAbsPos(settingsFrame, bx, sy)
    end
    settingsFrame:Show()
end

local function OnLoad()
    InitDB()

    mainFrame = CreateFrame("Frame", "BigTimerMainFrame", UIParent)
    mainFrame:SetFrameStrata("HIGH")
    mainFrame:SetClampedToScreen(true)
    mainFrame:EnableMouse(true)
    mainFrame:SetMovable(not BigTimerDB.locked)
    mainFrame:SetScale(ScaleFromPct(BigTimerDB.scalePct))

    -- Defer position restore by one frame so UIParent effective scale is
    -- fully settled. Without this the bar drifts left on every reload.
    local posFixFrame = CreateFrame("Frame")
    posFixFrame:SetScript("OnUpdate", function()
        SetFrameAbsPos(mainFrame, BigTimerDB.barAbsX, BigTimerDB.barAbsY)
        posFixFrame:SetScript("OnUpdate", nil)
    end)

    mainFrame:SetBackdrop({
        bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=12,
        insets={left=3,right=3,top=3,bottom=3},
    })
    mainFrame:SetBackdropColor(0.08, 0.08, 0.14, 0.88)
    mainFrame:SetBackdropBorderColor(0.40, 0.40, 0.60, 1.0)

    -- Wire the frame background into the hover counter so padding areas
    -- between buttons do not accidentally trigger a fade-out.
    mainFrame:SetScript("OnEnter", function() OnAnyEnter() end)
    mainFrame:SetScript("OnLeave", function() OnAnyLeave() end)

    mainFrame:SetScript("OnMouseDown", function()
        if not BigTimerDB.locked then this:StartMoving() end
    end)
    mainFrame:SetScript("OnMouseUp", function()
        this:StopMovingOrSizing()
        local ax, ay = FrameAbsPos(this)
        BigTimerDB.barAbsX, BigTimerDB.barAbsY = ax, ay
    end)

    for _, sec in ipairs({10, 15, 20, 30, 60}) do
        local s = sec
        local btn = MakeButton(tostring(s), "Pull in "..s.." seconds")
        btn:SetScript("OnClick", function() FirePull(s) end)
        buttons[table.getn(buttons)+1] = btn
    end

    -- Break button: override OnEnter for dynamic tooltip (duration can change)
    local brkBtn = MakeButton("Break", nil)
    brkBtn:SetScript("OnEnter", function()
        OnAnyEnter()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:SetText(
            "Start "..BigTimerDB.breakMins.." min break timer\n"..
            "|cffaaaaaa(Change duration in Settings)|r", 1, 1, 1)
        GameTooltip:Show()
    end)
    brkBtn:SetScript("OnLeave", function()
        OnAnyLeave()
        GameTooltip:Hide()
    end)
    brkBtn:SetScript("OnClick", function() FirePull(BigTimerDB.breakMins*60, true) end)
    buttons[table.getn(buttons)+1] = brkBtn

    -- Ready check button
    local readyBtn = MakeButton("Ready", "Send a ready check to the raid")
    readyBtn:SetScript("OnClick", function() DoReadyCheck() end)
    buttons[table.getn(buttons)+1] = readyBtn

    local xBtn = MakeButton("X",
        "Cancel pull timer\n"..
        "|cffff8800Note:|r if no timer is active,\n"..
        "BigWigs starts a 6s pull instead.")
    xBtn:SetScript("OnClick", function() FirePull(0) end)
    buttons[table.getn(buttons)+1] = xBtn

    local cfgBtn = MakeButton("Cfg", "Open BigTimer settings")
    cfgBtn:SetScript("OnClick", function() OpenSettings() end)
    buttons[table.getn(buttons)+1] = cfgBtn

    settingsFrame = BuildSettingsFrame()
    UpdateLayout()

    local acc = 0
    local poll = CreateFrame("Frame")
    poll:SetScript("OnUpdate", function()
        acc = acc + arg1
        if acc >= VIS_POLL then acc = 0; UpdateVisibility() end
    end)
    UpdateVisibility()

    -- Start faded; brightens on first mouse-over
    mainFrame:SetAlpha(0.25)

    DEFAULT_CHAT_FRAME:AddMessage(
        "|cffffff66[BigTimer]|r Loaded. Bar appears when you have raid lead or assist.")
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("VARIABLES_LOADED")
boot:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        OnLoad()
        boot:UnregisterAllEvents()
    end
end)
