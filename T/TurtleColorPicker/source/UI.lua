-- TurtleColorPicker UI
-- WoW 1.12 / Lua 5.0
-- All state is stored in the F table to avoid 32-upvalue limit.

local TCP = TurtleColorPicker

local F = {
    initialized = false,
    session = nil,
    draggingSV = false,
    draggingHue = false,
    hexHasFocus = false,
    main = nil,
    svFrame = nil, svBase = nil, svCursor = nil,
    hueFrame = nil, hueCursor = nil,
    oldSwatch = nil, newSwatch = nil, previewBorder = nil,
    hexContainer = nil, hexEditBox = nil,
    okBtn = nil, cancelBtn = nil,
}

-- Layout constants
F.SV_SIZE = 150
F.HUE_WIDTH = 20
F.HUE_HEIGHT = 150
F.PAD = 12
F.SPACING = 8
F.SWATCH_H = 22
F.BTN_W = 55
F.BTN_H = 22

-- Frame width: PAD | SV | GAP | HUE | PAD
F.HUE_GAP = 8
F.CONTENT_W = F.SV_SIZE + F.HUE_GAP + F.HUE_WIDTH
F.FRAME_W = F.CONTENT_W + F.PAD * 2

F.HUE_COLORS = {
    {1, 0, 0},
    {1, 1, 0},
    {0, 1, 0},
    {0, 1, 1},
    {0, 0, 1},
    {1, 0, 1},
    {1, 0, 0},
}

-- ============================================================
-- CURSOR
-- ============================================================

local function CreateCrosshairCursor(parent, size)
    local f = CreateFrame("Frame", nil, parent)
    f:SetWidth(size)
    f:SetHeight(size)
    f:SetFrameLevel(parent:GetFrameLevel() + 5)

    local len = (size / 2) - 2

    -- Black shadow (drawn first, behind white)
    local dirs = {
        {"RIGHT", "CENTER", -1, 0, len + 1, 3},
        {"LEFT",  "CENTER",  1, 0, len + 1, 3},
        {"BOTTOM","CENTER",  0, 1, 3, len + 1},
        {"TOP",   "CENTER",  0,-1, 3, len + 1},
    }
    for i = 1, 4 do
        local d = dirs[i]
        local t = f:CreateTexture(nil, "ARTWORK")
        t:SetWidth(d[5])
        t:SetHeight(d[6])
        t:SetPoint(d[1], f, d[2], d[3], d[4])
        t:SetTexture(0, 0, 0, 0.5)
    end

    -- White cross
    local wdirs = {
        {"RIGHT", "CENTER", -2, 0, len, 1},
        {"LEFT",  "CENTER",  2, 0, len, 1},
        {"BOTTOM","CENTER",  0, 2, 1, len},
        {"TOP",   "CENTER",  0,-2, 1, len},
    }
    for i = 1, 4 do
        local d = wdirs[i]
        local t = f:CreateTexture(nil, "OVERLAY")
        t:SetWidth(d[5])
        t:SetHeight(d[6])
        t:SetPoint(d[1], f, d[2], d[3], d[4])
        t:SetTexture(1, 1, 1, 0.85)
    end

    return f
end

-- ============================================================
-- UPDATE
-- ============================================================

local function UpdateColor()
    local s = F.session
    if not s then return end

    local r, g, b = TCP.HSVtoRGB(s.h, s.s, s.v)

    local hr, hg, hb = TCP.HSVtoRGB(s.h, 1, 1)
    F.svBase:SetTexture(hr, hg, hb, 1)

    F.svCursor:ClearAllPoints()
    F.svCursor:SetPoint("CENTER", F.svFrame, "BOTTOMLEFT", s.s * F.SV_SIZE, s.v * F.SV_SIZE)

    F.hueCursor:ClearAllPoints()
    F.hueCursor:SetPoint("CENTER", F.hueFrame, "TOPLEFT", F.HUE_WIDTH / 2, -(s.h * F.HUE_HEIGHT))

    F.newSwatch:SetTexture(r, g, b, 1)

    if F.hexEditBox and F.hexEditBox:IsShown() then
        if not F.hexHasFocus then
            F.hexEditBox:SetText(TCP.RGBtoHex(r, g, b))
        end
    end

    TCP:_NotifyChange()
end

local function UpdateSVFromMouse()
    local s = F.session
    if not s then return end
    local cx, cy = GetCursorPosition()
    local scale = F.svFrame:GetEffectiveScale()
    cx = cx / scale
    cy = cy / scale

    local newS = TCP.Clamp((cx - F.svFrame:GetLeft()) / F.SV_SIZE, 0, 1)
    local newV = TCP.Clamp((cy - F.svFrame:GetBottom()) / F.SV_SIZE, 0, 1)
    if newS == s.s and newV == s.v then return end
    s.s = newS
    s.v = newV
    UpdateColor()
end

local function UpdateHueFromMouse()
    local s = F.session
    if not s then return end
    local cx, cy = GetCursorPosition()
    local scale = F.hueFrame:GetEffectiveScale()
    cy = cy / scale

    local newH = TCP.Clamp((F.hueFrame:GetTop() - cy) / F.HUE_HEIGHT, 0, 0.9999)
    if newH == s.h then return end
    s.h = newH
    UpdateColor()
end

-- ============================================================
-- LAYOUT (forward declaration, defined after Init)
-- ============================================================

local RecalcLayout

-- ============================================================
-- INIT
-- ============================================================

local function Init()
    if F.initialized then return end
    F.initialized = true

    -- Main Frame
    F.main = CreateFrame("Frame", "TurtleColorPickerFrame", UIParent)
    F.main:SetFrameStrata("FULLSCREEN_DIALOG")
    F.main:SetWidth(F.FRAME_W)
    F.main:SetHeight(300)
    F.main:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    F.main:SetMovable(true)
    F.main:EnableMouse(true)
    F.main:RegisterForDrag("LeftButton")
    F.main:SetClampedToScreen(true)
    F.main:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    F.main:SetBackdropColor(0.06, 0.06, 0.06, 0.92)
    F.main:SetBackdropBorderColor(0.45, 0.45, 0.45, 1)
    F.main:Hide()

    F.main:SetScript("OnDragStart", function() this:StartMoving() end)
    F.main:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

    table.insert(UISpecialFrames, "TurtleColorPickerFrame")

    F.main:SetScript("OnHide", function()
        F.draggingSV = false
        F.draggingHue = false
        TCP:_NotifyCancel()
        F.session = nil
        TCP._session = nil
    end)

    F.main:SetScript("OnUpdate", function()
        if F.draggingSV then
            UpdateSVFromMouse()
        elseif F.draggingHue then
            UpdateHueFromMouse()
        end
    end)

    -- Title bar
    local title = F.main:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOP", F.main, "TOP", 0, -4)
    title:SetText("Color Picker")
    title:SetTextColor(0.8, 0.8, 0.8, 0.5)

    -- Offset top content below mini-title
    local topOff = F.PAD + 8

    -- SV Square
    F.svFrame = CreateFrame("Button", nil, F.main)
    F.svFrame:SetWidth(F.SV_SIZE)
    F.svFrame:SetHeight(F.SV_SIZE)
    F.svFrame:SetPoint("TOPLEFT", F.main, "TOPLEFT", F.PAD, -topOff)
    F.svFrame:RegisterForClicks("LeftButtonDown", "LeftButtonUp")

    F.svBase = F.svFrame:CreateTexture(nil, "BACKGROUND")
    F.svBase:SetAllPoints(F.svFrame)
    F.svBase:SetTexture(1, 0, 0, 1)

    local svWhite = F.svFrame:CreateTexture(nil, "BORDER")
    svWhite:SetAllPoints(F.svFrame)
    svWhite:SetTexture(1, 1, 1, 1)
    svWhite:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 1, 1, 1, 1, 0)

    local svBlack = F.svFrame:CreateTexture(nil, "ARTWORK")
    svBlack:SetAllPoints(F.svFrame)
    svBlack:SetTexture(0, 0, 0, 1)
    svBlack:SetGradientAlpha("VERTICAL", 0, 0, 0, 1, 0, 0, 0, 0)

    local svBorder = CreateFrame("Frame", nil, F.svFrame)
    svBorder:SetPoint("TOPLEFT", F.svFrame, "TOPLEFT", -1, 1)
    svBorder:SetPoint("BOTTOMRIGHT", F.svFrame, "BOTTOMRIGHT", 1, -1)
    svBorder:SetFrameLevel(F.svFrame:GetFrameLevel() + 3)
    svBorder:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 9,
    })
    svBorder:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.7)

    F.svCursor = CreateCrosshairCursor(F.svFrame, 15)

    F.svFrame:SetScript("OnMouseDown", function()
        F.draggingSV = true
        UpdateSVFromMouse()
    end)
    F.svFrame:SetScript("OnMouseUp", function()
        F.draggingSV = false
    end)

    -- Hue Bar
    F.hueFrame = CreateFrame("Button", nil, F.main)
    F.hueFrame:SetWidth(F.HUE_WIDTH)
    F.hueFrame:SetHeight(F.HUE_HEIGHT)
    F.hueFrame:SetPoint("TOPLEFT", F.svFrame, "TOPRIGHT", F.HUE_GAP, 0)
    F.hueFrame:RegisterForClicks("LeftButtonDown", "LeftButtonUp")

    local segH = F.HUE_HEIGHT / 6
    for i = 1, 6 do
        local seg = F.hueFrame:CreateTexture(nil, "ARTWORK")
        seg:SetWidth(F.HUE_WIDTH)
        seg:SetHeight(segH)
        seg:SetPoint("TOPLEFT", F.hueFrame, "TOPLEFT", 0, -(i - 1) * segH)
        seg:SetTexture(1, 1, 1, 1)
        local t = F.HUE_COLORS[i]
        local b = F.HUE_COLORS[i + 1]
        seg:SetGradient("VERTICAL", b[1], b[2], b[3], t[1], t[2], t[3])
    end

    local hueBorder = CreateFrame("Frame", nil, F.hueFrame)
    hueBorder:SetPoint("TOPLEFT", F.hueFrame, "TOPLEFT", -1, 1)
    hueBorder:SetPoint("BOTTOMRIGHT", F.hueFrame, "BOTTOMRIGHT", 1, -1)
    hueBorder:SetFrameLevel(F.hueFrame:GetFrameLevel() + 3)
    hueBorder:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 9,
    })
    hueBorder:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.7)

    -- Hue Cursor (small arrows / bar)
    F.hueCursor = CreateFrame("Frame", nil, F.hueFrame)
    F.hueCursor:SetWidth(F.HUE_WIDTH + 4)
    F.hueCursor:SetHeight(5)
    F.hueCursor:SetFrameLevel(F.hueFrame:GetFrameLevel() + 5)

    local hcBg = F.hueCursor:CreateTexture(nil, "ARTWORK")
    hcBg:SetAllPoints(F.hueCursor)
    hcBg:SetTexture(0, 0, 0, 0.8)

    local hcInner = F.hueCursor:CreateTexture(nil, "OVERLAY")
    hcInner:SetPoint("TOPLEFT", F.hueCursor, "TOPLEFT", 1, -1)
    hcInner:SetPoint("BOTTOMRIGHT", F.hueCursor, "BOTTOMRIGHT", -1, 1)
    hcInner:SetTexture(1, 1, 1, 0.85)

    F.hueFrame:SetScript("OnMouseDown", function()
        F.draggingHue = true
        UpdateHueFromMouse()
    end)
    F.hueFrame:SetScript("OnMouseUp", function()
        F.draggingHue = false
    end)

    F._topOff = topOff

    -- Preview Swatches
    F.previewBorder = CreateFrame("Frame", nil, F.main)
    F.previewBorder:SetHeight(F.SWATCH_H)

    F.oldSwatch = F.previewBorder:CreateTexture(nil, "ARTWORK")
    F.oldSwatch:SetHeight(F.SWATCH_H)
    F.oldSwatch:SetPoint("TOPLEFT", F.previewBorder, "TOPLEFT", 0, 0)
    F.oldSwatch:SetTexture(1, 1, 1, 1)

    F.newSwatch = F.previewBorder:CreateTexture(nil, "ARTWORK")
    F.newSwatch:SetHeight(F.SWATCH_H)
    F.newSwatch:SetPoint("TOPRIGHT", F.previewBorder, "TOPRIGHT", 0, 0)
    F.newSwatch:SetTexture(1, 0, 0, 1)

    -- Thin divider between swatches
    local swatchDiv = F.previewBorder:CreateTexture(nil, "OVERLAY")
    swatchDiv:SetWidth(1)
    swatchDiv:SetHeight(F.SWATCH_H)
    swatchDiv:SetPoint("CENTER", F.previewBorder, "CENTER", 0, 0)
    swatchDiv:SetTexture(0.15, 0.15, 0.15, 1)

    -- Hex Input
    F.hexContainer = CreateFrame("Frame", nil, F.main)
    F.hexContainer:SetHeight(F.BTN_H)
    F.hexContainer:Hide()

    local hexLabel = F.hexContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hexLabel:SetPoint("LEFT", F.hexContainer, "LEFT", 0, 0)
    hexLabel:SetText("#")
    hexLabel:SetTextColor(0.6, 0.6, 0.6, 1)

    F.hexEditBox = CreateFrame("EditBox", "TurtleColorPickerHexInput", F.hexContainer)
    F.hexEditBox:SetWidth(48)
    F.hexEditBox:SetHeight(F.BTN_H)
    F.hexEditBox:SetPoint("LEFT", hexLabel, "RIGHT", 3, 0)
    F.hexEditBox:SetFontObject(GameFontHighlightSmall)
    F.hexEditBox:SetAutoFocus(false)
    F.hexEditBox:SetMaxLetters(6)
    F.hexEditBox:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    F.hexEditBox:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    F.hexEditBox:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.8)
    F.hexEditBox:SetTextInsets(4, 4, 0, 0)

    F.hexEditBox:SetScript("OnEnterPressed", function()
        local sess = F.session
        if not sess then return end
        local text = F.hexEditBox:GetText()
        local r, g, b = TCP.HexToRGB(text)
        if r then
            sess.h, sess.s, sess.v = TCP.RGBtoHSV(r, g, b)
            UpdateColor()
        else
            local cr, cg, cb = TCP.HSVtoRGB(sess.h, sess.s, sess.v)
            F.hexEditBox:SetText(TCP.RGBtoHex(cr, cg, cb))
        end
        F.hexEditBox:ClearFocus()
    end)

    F.hexEditBox:SetScript("OnEscapePressed", function()
        local sess = F.session
        if not sess then return end
        local r, g, b = TCP.HSVtoRGB(sess.h, sess.s, sess.v)
        F.hexEditBox:SetText(TCP.RGBtoHex(r, g, b))
        F.hexEditBox:ClearFocus()
    end)

    F.hexEditBox:SetScript("OnEditFocusGained", function()
        F.hexHasFocus = true
    end)
    F.hexEditBox:SetScript("OnEditFocusLost", function()
        F.hexHasFocus = false
    end)

    F.hexEditBox:SetScript("OnTextChanged", function()
        local sess = F.session
        if not sess then return end
        if not F.hexHasFocus then return end
        local text = F.hexEditBox:GetText()
        if string.len(text) == 6 then
            local r, g, b = TCP.HexToRGB(text)
            if r then
                sess.h, sess.s, sess.v = TCP.RGBtoHSV(r, g, b)
                UpdateColor()
            end
        end
    end)

    -- OK / Cancel
    F.okBtn = CreateFrame("Button", nil, F.main, "UIPanelButtonTemplate")
    F.okBtn:SetWidth(F.BTN_W)
    F.okBtn:SetHeight(F.BTN_H)
    F.okBtn:SetText("OK")
    F.okBtn:SetScript("OnClick", function()
        TCP:_NotifyOk()
    end)

    F.cancelBtn = CreateFrame("Button", nil, F.main, "UIPanelButtonTemplate")
    F.cancelBtn:SetWidth(F.BTN_W)
    F.cancelBtn:SetHeight(F.BTN_H)
    F.cancelBtn:SetText("Cancel")
    F.cancelBtn:SetScript("OnClick", function()
        TCP:_NotifyCancel()
        F.main:Hide()
    end)
end

-- ============================================================
-- LAYOUT IMPLEMENTATION
-- ============================================================

RecalcLayout = function()
    local s = F.session
    if not s then return end

    local cw = F.CONTENT_W
    local topOff = F._topOff or (F.PAD + 8)
    local yOff = -topOff - F.SV_SIZE

    -- Preview swatches
    yOff = yOff - F.SPACING
    F.previewBorder:ClearAllPoints()
    F.previewBorder:SetPoint("TOPLEFT", F.main, "TOPLEFT", F.PAD, yOff)
    F.previewBorder:SetWidth(cw)
    F.previewBorder:Show()

    local swatchW = math.floor((cw - 1) / 2)
    F.oldSwatch:SetWidth(swatchW)
    F.newSwatch:SetWidth(swatchW)
    yOff = yOff - F.SWATCH_H

    -- Bottom row: hex input (left) + buttons (right) on same line
    yOff = yOff - F.SPACING
    local rowH = F.BTN_H

    F.okBtn:ClearAllPoints()
    F.cancelBtn:ClearAllPoints()
    local btnGap = 4
    -- Anchor buttons to right edge of content area (flush with swatches)
    local rightEdge = F.PAD + cw + 2
    F.cancelBtn:SetPoint("TOPRIGHT", F.main, "TOPLEFT", rightEdge, yOff)
    F.okBtn:SetPoint("TOPRIGHT", F.cancelBtn, "TOPLEFT", -btnGap, 0)

    if s.hasHexInput then
        F.hexContainer:ClearAllPoints()
        F.hexContainer:SetPoint("TOPLEFT", F.main, "TOPLEFT", F.PAD, yOff)
        F.hexContainer:SetPoint("TOPRIGHT", F.okBtn, "TOPLEFT", -btnGap, 0)
        F.hexContainer:Show()
    else
        F.hexContainer:Hide()
    end

    yOff = yOff - rowH

    F.main:SetHeight(math.abs(yOff) + F.PAD)
end

-- ============================================================
-- PUBLIC
-- ============================================================

function TurtleColorPicker_UI:Show(sess)
    Init()
    F.session = sess

    F.oldSwatch:SetTexture(sess.origR, sess.origG, sess.origB, 1)

    if sess.hasHexInput then
        local r, g, b = TCP.HSVtoRGB(sess.h, sess.s, sess.v)
        F.hexEditBox:SetText(TCP.RGBtoHex(r, g, b))
        F.hexEditBox:ClearFocus()
    end

    RecalcLayout()
    UpdateColor()

    -- Position near anchor frame if provided
    if sess.anchorFrame then
        local anchor = sess.anchorFrame
        local scale = F.main:GetEffectiveScale()
        local aScale = anchor:GetEffectiveScale()
        -- Get anchor position in screen coords
        local aLeft = anchor:GetLeft() * aScale
        local aRight = anchor:GetRight() * aScale
        local aTop = anchor:GetTop() * aScale
        -- Convert to our scale
        local screenW = GetScreenWidth() * UIParent:GetEffectiveScale()
        local fw = F.main:GetWidth() * scale
        local fh = F.main:GetHeight() * scale

        -- Try to place to the right of the anchor with a small gap
        local gap = 8
        local targetX = aRight + gap
        local targetY = aTop

        -- If it would go off the right edge, place to the left instead
        if (targetX + fw) > screenW then
            targetX = aLeft - fw - gap
        end
        -- Clamp Y so it stays on screen
        local screenH = GetScreenHeight() * UIParent:GetEffectiveScale()
        if targetY > screenH then targetY = screenH end
        if (targetY - fh) < 0 then targetY = fh end

        -- Convert back to our frame's scale and set position from BOTTOMLEFT of UIParent
        F.main:ClearAllPoints()
        F.main:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", targetX / scale, targetY / scale)
    end

    F.main:Show()
end

function TurtleColorPicker_UI:Hide()
    if F.main then
        F.main:Hide()
    end
end
