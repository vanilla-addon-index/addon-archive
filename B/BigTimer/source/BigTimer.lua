--[[
    BigTimer.lua
    WoW 1.12 / Lua 5 -- requires BigWigs with Pulltimer plugin
    Includes a QuickMark style raid target icon strip.
--]]

local ADDON    = "BigTimer"
local BTN_W    = 36
local BTN_H    = 26
local BTN_GAP  = 2
local PAD      = 5
local SET_W    = 180
local SET_H    = 196
local VIS_POLL = 2.0

-- Raid mark strip
local NUM_MARKS    = 8
local MARK_MAX     = 28   -- largest an icon is allowed to get
local MARK_MIN_GAP = 2    -- smallest spacing between icons
local STRIP_GAP    = 3    -- space between the icon strip and the timer buttons
local MARK_TEX     = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local MARK_NAMES   = { "Star", "Circle", "Diamond", "Triangle",
                       "Moon", "Square", "Cross", "Skull" }

local DEFAULTS = {
    barAbsX    = 400,
    barAbsY    = 300,
    scalePct   = 100,
    horizontal = true,
    locked     = false,
    setAbsX    = nil,
    setAbsY    = nil,
    breakMins  = 3,
    showMarks  = true,
    markPosH   = "TOP",    -- TOP or BOTTOM (horizontal bar)
    markPosV   = "LEFT",   -- LEFT or RIGHT (vertical bar)
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

-- Raid: leader or assist.  Party (not raid): leader only.
local function ShouldShow()
    if GetNumRaidMembers() > 0 then
        return (IsRaidLeader() or IsRaidOfficer()) and true or false
    end
    if GetNumPartyMembers() > 0 then
        if IsPartyLeader and IsPartyLeader() then return true end
        -- Fallback: party leader index 0 means the player is the leader
        if GetPartyLeaderIndex and GetPartyLeaderIndex() == 0 then return true end
        return false
    end
    return false
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

-- Same behaviour as QuickMark: clicking the mark already on the target clears it.
local function ApplyMark(idx)
    if not UnitExists("target") then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff6600[BigTimer]|r No target to mark.")
        return
    end
    if idx ~= 0 and GetRaidTargetIndex("target") == idx then
        SetRaidTarget("target", 0)
    else
        SetRaidTarget("target", idx)
    end
end

local mainFrame, settingsFrame
local buttons = {}
local markButtons = {}
local markSideBtn
local UpdateLayout, UpdateVisibility

-- Last layout results, used to keep the timer buttons from moving
-- when the mark strip is toggled or flipped to the other side.
local lastBX, lastBY, lastFH = PAD, PAD, 0

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

local function MarkSide()
    if BigTimerDB.horizontal then
        return BigTimerDB.markPosH
    end
    return BigTimerDB.markPosV
end

local SIDE_LABELS = {
    TOP    = "Marks: Top",
    BOTTOM = "Marks: Bottom",
    LEFT   = "Marks: Left",
    RIGHT  = "Marks: Right",
}

local function RefreshMarkSideBtn()
    if not markSideBtn then return end
    markSideBtn:SetText(SIDE_LABELS[MarkSide()] or "Marks")
    if BigTimerDB.showMarks then
        markSideBtn:Enable()
    else
        markSideBtn:Disable()
    end
end

UpdateLayout = function()
    local n     = table.getn(buttons)
    local isH   = BigTimerDB.horizontal
    local showM = BigTimerDB.showMarks

    -- Length of the timer button group along the bar, and its thickness across it
    local rowLen, cross
    if isH then
        rowLen = n*BTN_W + (n-1)*BTN_GAP
        cross  = BTN_H
    else
        rowLen = n*BTN_H + (n-1)*BTN_GAP
        cross  = BTN_W
    end

    -- Size the icons (8 marks + clear) so they always fit inside the length
    -- of the timer bar, then spread them evenly so the strip lines up with both ends.
    local nM = table.getn(markButtons)
    local mSize, mGap, stripThick = 0, 0, 0
    if showM then
        mSize = math.floor((rowLen - (nM-1)*MARK_MIN_GAP) / nM)
        if mSize > MARK_MAX then mSize = MARK_MAX end
        mGap = (rowLen - nM*mSize) / (nM-1)
        stripThick = mSize + STRIP_GAP
    end

    -- Offsets from the frame's top left corner (y measured downward)
    local side = MarkSide()
    local bx, by, mx, my = PAD, PAD, PAD, PAD
    local fw, fh
    if isH then
        fw = PAD*2 + rowLen
        fh = PAD*2 + cross + stripThick
        if showM then
            if side == "TOP" then
                by = PAD + stripThick
            else
                my = PAD + cross + STRIP_GAP
            end
        end
    else
        fw = PAD*2 + cross + stripThick
        fh = PAD*2 + rowLen
        if showM then
            if side == "LEFT" then
                bx = PAD + stripThick
            else
                mx = PAD + cross + STRIP_GAP
            end
        end
    end

    mainFrame:SetWidth(fw)
    mainFrame:SetHeight(fh)

    for i, btn in ipairs(buttons) do
        btn:ClearAllPoints()
        if isH then
            btn:SetPoint("TOPLEFT", mainFrame, "TOPLEFT",
                bx + (i-1)*(BTN_W+BTN_GAP), -by)
        else
            btn:SetPoint("TOPLEFT", mainFrame, "TOPLEFT",
                bx, -(by + (i-1)*(BTN_H+BTN_GAP)))
        end
        btn:SetWidth(BTN_W)
        btn:SetHeight(BTN_H)
    end

    for i, mb in ipairs(markButtons) do
        mb:ClearAllPoints()
        if showM then
            mb:SetWidth(mSize)
            mb:SetHeight(mSize)
            if isH then
                mb:SetPoint("TOPLEFT", mainFrame, "TOPLEFT",
                    mx + (i-1)*(mSize+mGap), -my)
            else
                mb:SetPoint("TOPLEFT", mainFrame, "TOPLEFT",
                    mx, -(my + (i-1)*(mSize+mGap)))
            end
            mb:Show()
        else
            mb:Hide()
        end
    end

    lastBX, lastBY, lastFH = bx, by, fh
    RefreshMarkSideBtn()
end

-- Re-layout while holding the timer buttons still on screen.
-- Used when the mark strip is toggled or moved to the other side,
-- so only the strip appears to move, not the buttons you aim at.
local function RelayoutKeepButtons()
    local oldBX, oldTop = lastBX, lastFH - lastBY
    local es = mainFrame:GetEffectiveScale()
    local ax, ay = FrameAbsPos(mainFrame)
    UpdateLayout()
    local newTop = lastFH - lastBY
    ax = ax + (oldBX - lastBX) * es
    ay = ay + (oldTop - newTop) * es
    SetFrameAbsPos(mainFrame, ax, ay)
    BigTimerDB.barAbsX, BigTimerDB.barAbsY = ax, ay
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

local function MakeMarkButton(idx)
    local mb = CreateFrame("Button", nil, mainFrame)
    mb:SetWidth(MARK_MAX)
    mb:SetHeight(MARK_MAX)
    mb:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local tex = mb:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(mb)
    tex:SetTexture(MARK_TEX)
    local col = math.mod(idx - 1, 4)
    local row = math.floor((idx - 1) / 4)
    tex:SetTexCoord(col*0.25, col*0.25 + 0.25, row*0.25, row*0.25 + 0.25)

    mb:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    local hl = mb:GetHighlightTexture()
    if hl then hl:SetBlendMode("ADD") end

    mb:SetScript("OnClick", function()
        if arg1 == "RightButton" then
            ApplyMark(0)
        else
            ApplyMark(idx)
        end
    end)
    mb:SetScript("OnEnter", function()
        OnAnyEnter()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:SetText(
            "Mark target: "..MARK_NAMES[idx].."\n"..
            "|cffaaaaaaClick again to remove.  Right-click clears any mark.|r",
            1, 1, 1)
        GameTooltip:Show()
    end)
    mb:SetScript("OnLeave", function()
        OnAnyLeave()
        GameTooltip:Hide()
    end)
    return mb
end

local function MakeClearButton()
    local cb = CreateFrame("Button", nil, mainFrame)
    cb:SetWidth(MARK_MAX)
    cb:SetHeight(MARK_MAX)
    cb:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local tex = cb:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(cb)
    tex:SetTexture("Interface\\AddOns\\BigTimer\\Textures\\ClearMark")

    cb:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    local hl = cb:GetHighlightTexture()
    if hl then hl:SetBlendMode("ADD") end

    cb:SetScript("OnClick", function() ApplyMark(0) end)
    cb:SetScript("OnEnter", function()
        OnAnyEnter()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:SetText("Clear target's mark", 1, 1, 1)
        GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", function()
        OnAnyLeave()
        GameTooltip:Hide()
    end)
    return cb
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

    -- Row 1: orientation button + lock checkbox
    local oBtn = CreateFrame("Button","BigTimerOrientBtn",f,"UIPanelButtonTemplate")
    oBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 36)
    oBtn:SetWidth(90)
    oBtn:SetHeight(20)
    oBtn:SetText(BigTimerDB.horizontal and "Vertical" or "Horizontal")
    oBtn:SetScript("OnClick", function()
        BigTimerDB.horizontal = not BigTimerDB.horizontal
        this:SetText(BigTimerDB.horizontal and "Vertical" or "Horizontal")
        UpdateLayout()
    end)

    local lLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lLbl:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 41)
    lLbl:SetText("Lock Bar")

    local lCB = CreateFrame("CheckButton","BigTimerLockCB",f,"UICheckButtonTemplate")
    lCB:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 34)
    lCB:SetWidth(22)
    lCB:SetHeight(22)
    lCB:SetChecked(BigTimerDB.locked and 1 or nil)
    lCB:SetScript("OnClick", function()
        BigTimerDB.locked = (this:GetChecked() == 1)
        mainFrame:SetMovable(not BigTimerDB.locked)
    end)

    -- Row 2: mark strip side button + show marks checkbox
    markSideBtn = CreateFrame("Button","BigTimerMarkSideBtn",f,"UIPanelButtonTemplate")
    markSideBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 10)
    markSideBtn:SetWidth(90)
    markSideBtn:SetHeight(20)
    markSideBtn:SetScript("OnClick", function()
        if BigTimerDB.horizontal then
            if BigTimerDB.markPosH == "TOP" then
                BigTimerDB.markPosH = "BOTTOM"
            else
                BigTimerDB.markPosH = "TOP"
            end
        else
            if BigTimerDB.markPosV == "LEFT" then
                BigTimerDB.markPosV = "RIGHT"
            else
                BigTimerDB.markPosV = "LEFT"
            end
        end
        RelayoutKeepButtons()
    end)
    markSideBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:SetText(
            "Which side of the bar the raid marks sit on.\n"..
            "|cffaaaaaaHorizontal and vertical remember their own side.|r",
            1, 1, 1)
        GameTooltip:Show()
    end)
    markSideBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local mLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mLbl:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 15)
    mLbl:SetText("Show Marks")

    local mCB = CreateFrame("CheckButton","BigTimerMarksCB",f,"UICheckButtonTemplate")
    mCB:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 8)
    mCB:SetWidth(22)
    mCB:SetHeight(22)
    mCB:SetChecked(BigTimerDB.showMarks and 1 or nil)
    mCB:SetScript("OnClick", function()
        BigTimerDB.showMarks = (this:GetChecked() == 1)
        RelayoutKeepButtons()
    end)

    RefreshMarkSideBtn()
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
    local readyBtn = MakeButton("Ready", "Send a ready check")
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

    -- Raid target icons, laid out Skull .. Star
    for i = 1, NUM_MARKS do
        markButtons[i] = MakeMarkButton(NUM_MARKS + 1 - i)
    end
    -- Clear button at the end of the strip (red no symbol, like QuickMark)
    markButtons[NUM_MARKS + 1] = MakeClearButton()

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
        "|cffffff66[BigTimer]|r Loaded. Bar appears with raid lead/assist, or party lead.")
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("VARIABLES_LOADED")
boot:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        OnLoad()
        boot:UnregisterAllEvents()
    end
end)
