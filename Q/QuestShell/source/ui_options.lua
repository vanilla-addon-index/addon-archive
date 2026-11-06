-- =========================

-- QuestShell UI — Options (Vanilla/Turtle safe)
-- =========================
QuestShellUI = QuestShellUI or {}

local optFrame, lockChk, arrowChk, fontSlider, fontValueFS

local function EnsureDB()
    QuestShellDB = QuestShellDB or {}
    QuestShellDB.ui = QuestShellDB.ui or {}
    if QuestShellDB.ui.locked == nil then QuestShellDB.ui.locked = false end
    if QuestShellDB.ui.arrowEnabled == nil then QuestShellDB.ui.arrowEnabled = true end
    if QuestShellDB.ui.trackerFontScale == nil then QuestShellDB.ui.trackerFontScale = 1.3 end
end

local function P(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[QuestShell]|r "..tostring(msg))
    end
end

local function ApplyArrow(flag)
    EnsureDB()
    QuestShellDB.ui.arrowEnabled = (flag and true or false)
    if not flag then
        if QuestShellUI and QuestShellUI.ArrowClear then QuestShellUI.ArrowClear() end
    else
        if QuestShellUI_UpdateAll then QuestShellUI_UpdateAll() end
    end
    P("Arrow "..(flag and "enabled" or "disabled")..".")
end

local function ApplyFontScale(scale)
    EnsureDB()
    if scale < 0.6 then scale = 0.6 end
    if scale > 1.8 then scale = 1.8 end
    QuestShellDB.ui.trackerFontScale = scale
    if fontValueFS then fontValueFS:SetText(string.format("%.2f", scale)) end
    if QuestShellUI and QuestShellUI.SetFontScale then
        QuestShellUI.SetFontScale(scale)  -- calls QS_TrackerApplyFontScale() and refreshes tracker. 
    end
end

local function ClampAndPlace(f, x, y, fw, fh)
    if not f or not UIParent then return end
    f:ClearAllPoints(); f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x or 0, y or 0); f:Show()
    local sw, sh = UIParent:GetWidth() or 1024, UIParent:GetHeight() or 768
    local cx, cy = x or 0, y or 0
    local ww, hh = fw or (f:GetWidth() or 360), fh or (f:GetHeight() or 260)
    if cx > sw - ww then cx = sw - ww end
    if cx < 0 then cx = 0 end
    if cy > 0 then cy = 0 end
    if cy < -(sh - hh) then cy = -(sh - hh) end
    f:ClearAllPoints(); f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", cx, cy)
end

local function EnsureOptionsFrame()
    if optFrame then return end
    EnsureDB()

    optFrame = CreateFrame("Frame", "QuestShellOptions", UIParent)
    optFrame:SetWidth(360); optFrame:SetHeight(220)
    optFrame:SetBackdrop({
        bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=16,
        insets={ left=6, right=6, top=6, bottom=6 }
    })
    optFrame:SetBackdropColor(0,0,0,0.92)
    optFrame:SetMovable(true); optFrame:EnableMouse(true)
    optFrame:RegisterForDrag("LeftButton")
    optFrame:SetScript("OnDragStart", function() this:StartMoving() end)
    optFrame:SetScript("OnDragStop",  function() this:StopMovingOrSizing() end)
    ClampAndPlace(optFrame, 380, -180, 360, 220)

    local title = optFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", optFrame, "TOPLEFT", 10, -10)
    title:SetText("|cffffff00QuestShell – Options|r")

    local close = CreateFrame("Button", nil, optFrame, "UIPanelButtonTemplate")
    close:SetPoint("TOPRIGHT", optFrame, "TOPRIGHT", -10, -8)
    close:SetWidth(60); close:SetHeight(20)
    close:SetText("Close")
    close:SetScript("OnClick", function() optFrame:Hide() end)

    -- Lock frames
    lockChk = CreateFrame("CheckButton", "QuestShellOptLock", optFrame, "UICheckButtonTemplate")
    lockChk:SetPoint("TOPLEFT", optFrame, "TOPLEFT", 12, -44)
    getglobal(lockChk:GetName().."Text"):SetText("Lock frames (disable dragging)")
    lockChk:SetChecked(QuestShellDB.ui.locked and true or false)
    lockChk:SetScript("OnClick", function()
        EnsureDB()
        QuestShellDB.ui.locked = (lockChk:GetChecked() and true or false)
        P(QuestShellDB.ui.locked and "Frames locked." or "Frames unlocked (drag with header).")
    end)

    -- Arrow toggle
    arrowChk = CreateFrame("CheckButton", "QuestShellOptArrow", optFrame, "UICheckButtonTemplate")
    arrowChk:SetPoint("TOPLEFT", lockChk, "BOTTOMLEFT", 0, -8)
    getglobal(arrowChk:GetName().."Text"):SetText("Enable waypoint arrow (TomTom)")
    arrowChk:SetChecked(QuestShellDB.ui.arrowEnabled and true or false)
    arrowChk:SetScript("OnClick", function() ApplyArrow(arrowChk:GetChecked()) end)

    -- Font slider
    local fsLabel = optFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fsLabel:SetPoint("TOPLEFT", arrowChk, "BOTTOMLEFT", 0, -16)
    fsLabel:SetText("Tracker font scale")

    fontSlider = CreateFrame("Slider", "QuestShellOptFont", optFrame, "OptionsSliderTemplate")
    fontSlider:SetPoint("TOPLEFT", fsLabel, "BOTTOMLEFT", 0, -10)
    fontSlider:SetPoint("RIGHT", optFrame, "RIGHT", -70, 0)
    fontSlider:SetMinMaxValues(0.6, 1.8)
    fontSlider:SetValueStep(0.05)
    -- NOTE: No SetObeyStepOnDrag() in 1.12; removed.

    getglobal(fontSlider:GetName().."Low"):SetText("0.6")
    getglobal(fontSlider:GetName().."High"):SetText("1.8")
    getglobal(fontSlider:GetName().."Text"):SetText("") -- we show numeric at the right instead

    fontValueFS = optFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fontValueFS:SetPoint("LEFT", fontSlider, "RIGHT", 6, 0)
    fontValueFS:SetText("1.30")

    local function SyncFontFromSlider()
        local v = fontSlider:GetValue()
        if fontValueFS then fontValueFS:SetText(string.format("%.2f", v)) end
        ApplyFontScale(v)
    end

    fontSlider:SetScript("OnValueChanged", function() SyncFontFromSlider() end)
    fontSlider:SetScript("OnMouseUp", function() SyncFontFromSlider() end)

    fontSlider:SetValue(QuestShellDB.ui.trackerFontScale or 1.3)
    SyncFontFromSlider()

    -- Reset positions (soft)
    local resetBtn = CreateFrame("Button", nil, optFrame, "UIPanelButtonTemplate")
    resetBtn:SetPoint("BOTTOMLEFT", optFrame, "BOTTOMLEFT", 10, 10)
    resetBtn:SetWidth(120); resetBtn:SetHeight(22)
    resetBtn:SetText("Reset positions")
    resetBtn:SetScript("OnClick", function()
        EnsureDB()
        QuestShellDB.ui.trackerX, QuestShellDB.ui.trackerY = 250, -140
        QuestShellDB.ui.listX,    QuestShellDB.ui.listY    = 560, -220
        P("Positions reset. Drag headers to adjust.")
        if QuestShellTracker then QuestShellTracker:ClearAllPoints(); QuestShellTracker:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 250, -140) end
        if QuestShellSteps   then QuestShellSteps:ClearAllPoints();   QuestShellSteps:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 560, -220) end
    end)
end

function QuestShellUI.ShowOptions()
    EnsureOptionsFrame()
    optFrame:Show()
end