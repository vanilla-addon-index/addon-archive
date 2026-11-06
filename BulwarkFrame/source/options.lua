-- BulwarkFrame - options.lua
-- Standalone options panel (no Blizzard InterfaceOptions integration on 1.12). Built lazily on
-- first open, repopulated from BulwarkFrameDB on show. Opened by the minimap button's left click
-- and by /bulwark options. WoW-API file (parse-checked only).
--
-- Widget wiring uses the 1.12 templates: UICheckButtonTemplate (GetChecked() -> 1/nil) and
-- OptionsSliderTemplate (SetMinMaxValues BEFORE SetValue, else it clamps to 0). Colour swatches
-- drive ColorPickerFrame the way pfUI does -- func/cancelFunc plus ShowUIPanel.

BulwarkFrame = BulwarkFrame or {}
local BF = BulwarkFrame

local PANEL_W = 430
-- Content width of one column: panel minus both outer margins minus the gutter, halved.
local COL_W = (PANEL_W - 48 - 12) / 2
local panel = nil
local cbIndex, slIndex, swIndex, ebIndex = 0, 0, 0, 0
local refreshers = {}

local function db() return BulwarkFrameDB end

-- 1.12: a FontString created WITHOUT a font object has no font, and FontString:SetText() then
-- throws "Font not set" -- which aborts the rest of the panel build. Every CreateFontString here
-- therefore passes an inherit template, and this only swaps in the pfUI face afterwards.
local function ApplyFont(fs, size)
    if not fs then return end
    if pfUI and pfUI.font_default then
        fs:SetFont(pfUI.font_default, size or 12)
    else
        fs:SetFontObject(GameFontNormalSmall)
    end
end

-- Extends a widget's hover area across the whole row, so the tooltip also appears over its label
-- rather than only over the 22px box itself. 1.12 FontStrings take no mouse events, so this is an
-- invisible button laid over the row; clicking it forwards to the real widget, which also makes
-- the label clickable -- the behaviour anyone expects from a labelled checkbox.
local function AddRowHover(widget, tip, onClick)
    if not widget then return end
    local hover = CreateFrame("Button", nil, widget:GetParent())
    hover:SetPoint("TOPLEFT", widget, "TOPLEFT", 0, 0)
    hover:SetWidth(COL_W)
    hover:SetHeight(widget:GetHeight() or 22)
    hover:SetFrameLevel((widget:GetFrameLevel() or 1) + 1)
    hover:SetScript("OnClick", onClick)
    return hover
end

local function AddTooltip(widget, text)
    if not widget or not text then return end
    widget.bfTip = text
    local oldEnter = widget:GetScript("OnEnter")
    local oldLeave = widget:GetScript("OnLeave")
    widget:SetScript("OnEnter", function()
        if oldEnter then oldEnter() end
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText(this.bfTip, 1, 1, 1, 1, 1)
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function()
        if oldLeave then oldLeave() end
        GameTooltip:Hide()
    end)
end

-- Any change to a display option has to reach the frame immediately -- an options panel whose
-- effect only shows after /reload trains you to distrust it.
local function Applied()
    BF.ApplyLayout()
    BF.RequestUpdate()
end

-- ---- widget factories -------------------------------------------------------------------

local function CreateCheckbox(parent, label, tip, getter, setter)
    cbIndex = cbIndex + 1
    local name = "BulwarkFrameOptCheck" .. cbIndex
    local cb = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    cb:SetWidth(22)
    cb:SetHeight(22)
    local lbl = getglobal(name .. "Text")
    if lbl then lbl:SetText(label); ApplyFont(lbl) end
    cb.bfSet = setter
    cb.bfLabel = label       -- scratch field for the offline stub; the real client's own label
                              -- text lives in the $parentText template region instead.
    cb:SetScript("OnClick", function()
        this.bfSet(this:GetChecked() == 1)
        Applied()
    end)
    AddTooltip(cb, tip)
    AddTooltip(AddRowHover(cb, tip, function()
        cb:SetChecked(not (cb:GetChecked() == 1) and 1 or nil)
        cb.bfSet(cb:GetChecked() == 1)
        Applied()
    end), tip)
    if pfUI and pfUI.api and pfUI.api.SkinCheckbox then pfUI.api.SkinCheckbox(cb) end
    table.insert(refreshers, function() cb:SetChecked(getter() and 1 or nil) end)
    return cb
end

local function CreateSlider(parent, label, minVal, maxVal, step, fmt, tip, getter, setter)
    slIndex = slIndex + 1
    local name = "BulwarkFrameOptSlider" .. slIndex
    local sl = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    sl:SetWidth(COL_W)
    sl:SetHeight(16)
    sl:SetMinMaxValues(minVal, maxVal)
    sl:SetValueStep(step)
    local low, high, txt = getglobal(name .. "Low"), getglobal(name .. "High"), getglobal(name .. "Text")
    if low then low:SetText(tostring(minVal)); ApplyFont(low, 10) end
    if high then high:SetText(tostring(maxVal)); ApplyFont(high, 10) end
    if txt then
        txt:ClearAllPoints()
        txt:SetPoint("BOTTOMLEFT", sl, "TOPLEFT", 0, 2)
        txt:SetJustifyH("LEFT")
        ApplyFont(txt, 11)
    end
    sl.bfFmt = fmt
    sl.bfText = txt
    sl.bfSet = setter
    sl:SetScript("OnValueChanged", function()
        local v = this:GetValue()
        if this.bfText then this.bfText:SetText(string.format(this.bfFmt, v)) end
        this.bfSet(v)
        Applied()
    end)
    AddTooltip(sl, tip)
    if pfUI and pfUI.api and pfUI.api.SkinSlider then pfUI.api.SkinSlider(sl) end
    table.insert(refreshers, function()
        local v = getter()
        sl:SetValue(v)
        if txt then txt:SetText(string.format(fmt, v)) end
    end)
    return sl
end

-- A colour swatch. `key` names the config field holding {r,g,b}.
local function CreateSwatch(parent, label, key, tip)
    swIndex = swIndex + 1
    local holder = CreateFrame("Button", "BulwarkFrameOptSwatch" .. swIndex, parent)
    holder:SetWidth(18)
    holder:SetHeight(18)

    local tex = holder:CreateTexture("BulwarkFrameOptSwatchTex" .. swIndex, "ARTWORK")
    tex:SetTexture("Interface\\Buttons\\WHITE8X8")
    tex:SetPoint("TOPLEFT", holder, "TOPLEFT", 1, -1)
    tex:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -1, 1)

    local border = holder:CreateTexture("BulwarkFrameOptSwatchBorder" .. swIndex, "BACKGROUND")
    border:SetTexture("Interface\\Buttons\\WHITE8X8")
    border:SetVertexColor(0, 0, 0, 1)
    border:SetAllPoints(holder)

    local lbl = holder:CreateFontString("BulwarkFrameOptSwatchLabel" .. swIndex, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("LEFT", holder, "RIGHT", 6, 0)
    lbl:SetText(label)
    ApplyFont(lbl)

    holder:SetScript("OnClick", function()
        local c = db()[key] or { 1, 1, 1 }
        local pr, pg, pb = c[1], c[2], c[3]
        -- Captured for cancel: ColorPickerFrame keeps calling func while the user drags, so the
        -- config is written live and cancel has to put the old value back explicitly.
        ColorPickerFrame.func = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local cc = db()[key]
            cc[1], cc[2], cc[3] = r, g, b
            tex:SetVertexColor(r, g, b)
            Applied()
        end
        ColorPickerFrame.cancelFunc = function()
            local cc = db()[key]
            cc[1], cc[2], cc[3] = pr, pg, pb
            tex:SetVertexColor(pr, pg, pb)
            Applied()
        end
        ColorPickerFrame.opacityFunc = nil
        ColorPickerFrame.hasOpacity = nil
        ColorPickerFrame:SetColorRGB(pr, pg, pb)
        ColorPickerFrame:SetFrameStrata("DIALOG")
        ShowUIPanel(ColorPickerFrame)
    end)
    AddTooltip(holder, tip)
    AddTooltip(AddRowHover(holder, tip, function() holder:Click() end), tip)

    table.insert(refreshers, function()
        local c = db()[key] or { 1, 1, 1 }
        tex:SetVertexColor(c[1], c[2], c[3])
    end)
    return holder
end

-- A numeric edit box: a label above a small InputBoxTemplate field. Used for the two spell ids,
-- which are not on any slider scale -- typing the exact id is the only sane input for one.
-- Applies on Enter or on losing focus (tabbing/clicking away), the same "commit, don't live-type"
-- behaviour InputBoxTemplate users get everywhere else in the default UI. An unparsable entry is
-- reverted to the current stored value rather than silently written as nil.
local function CreateEditBox(parent, label, tip, getter, setter)
    ebIndex = ebIndex + 1
    local name = "BulwarkFrameOptEdit" .. ebIndex
    local holder = CreateFrame("Frame", name .. "Holder", parent)
    holder:SetWidth(COL_W)
    holder:SetHeight(34)

    local lbl = holder:CreateFontString(name .. "Label", "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    lbl:SetJustifyH("LEFT")
    lbl:SetText(label)
    ApplyFont(lbl, 11)

    local eb = CreateFrame("EditBox", name, holder, "InputBoxTemplate")
    eb:SetWidth(90)
    eb:SetHeight(18)
    eb:SetAutoFocus(false)
    eb:SetMaxLetters(6)
    if eb.SetNumeric then eb:SetNumeric(true) end
    eb:SetPoint("TOPLEFT", holder, "TOPLEFT", 4, -16)

    local function commit()
        local v = tonumber(eb:GetText())
        -- Spell ids start at 1 -- 0 (or negative) is never a real aura id, and tonumber("0")
        -- is truthy, so it has to be rejected explicitly rather than falling through as if it
        -- were a valid id. Treated exactly like any other unparsable entry: revert, don't write.
        if v and math.floor(v) >= 1 then
            eb.bfSet(math.floor(v))
        else
            eb:SetText(tostring(getter()))
        end
        eb:ClearFocus()
        Applied()
    end
    eb.bfSet = setter
    eb:SetScript("OnEnterPressed", commit)
    eb:SetScript("OnEscapePressed", function() eb:SetText(tostring(getter())); eb:ClearFocus() end)
    eb:SetScript("OnEditFocusLost", commit)

    -- No AddRowHover here: an overlay button covering the row would sit above the edit box and
    -- eat the click meant to focus it. The tooltip is on the field and the label only.
    AddTooltip(eb, tip)
    holder:EnableMouse(true)
    AddTooltip(holder, tip)
    table.insert(refreshers, function() eb:SetText(tostring(getter())) end)
    return holder
end

local function CreateButton(parent, label, tip, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetWidth(110)
    b:SetHeight(20)
    b:SetText(label)
    b:SetScript("OnClick", onClick)
    AddTooltip(b, tip)
    if pfUI and pfUI.api and pfUI.api.SkinButton then pfUI.api.SkinButton(b) end
    return b
end

local function CreateHeading(parent, text, x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetText(text)
    ApplyFont(fs, 13)
    fs:SetTextColor(1, 0.82, 0)
    return fs
end

-- ---- panel ------------------------------------------------------------------------------

local function BuildPanel()
    if panel then return end

    -- Chrome copied from TotemBar's options panel so the two addons read as one family:
    -- gold title top-left, close button top-right, clamped to screen, ESC closes, version footer.
    -- The one thing NOT copied is its hardcoded height -- that file carries a comment warning that
    -- every new row has to be added to the constant by hand or the last widget lands on the footer,
    -- which is exactly the bug reported here. The height below is computed from the layout cursor.
    panel = CreateFrame("Frame", "BulwarkFrameOptions", UIParent)
    panel:SetWidth(PANEL_W)
    panel:SetHeight(200)                     -- provisional; recomputed at the end of this function
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    panel:SetFrameStrata("DIALOG")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function() this:StartMoving() end)
    panel:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    panel:SetClampedToScreen(true)
    -- Own frame art, generated by tools/gen_panel_textures.js with the same parameters TotemBar
    -- uses, so the two panels read as one product. Deliberately not pfUI's generic backdrop and
    -- not the Blizzard dialog frame: this is the addon's own chrome, and it ships with the addon.
    panel:SetBackdrop({
        bgFile = "Interface\\AddOns\\BulwarkFrame\\textures\\panel_bg",
        edgeFile = "Interface\\AddOns\\BulwarkFrame\\textures\\panel_border",
        tile = true, tileSize = 128, edgeSize = 16,
        insets = { left = 5, right = 5, top = 5, bottom = 5 },
    })
    panel:SetBackdropColor(1, 1, 1, 0.97)

    local title = panel:CreateFontString("BulwarkFrameOptionsTitle", "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    title:SetText("BulwarkFrame Options")
    ApplyFont(title, 14)
    title:SetTextColor(0.85, 0.66, 0.31)

    local close = CreateFrame("Button", "BulwarkFrameOptionsClose", panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -8)
    if pfUI and pfUI.api and pfUI.api.SkinCloseButton then pfUI.api.SkinCloseButton(close, panel) end

    -- Layout cursors, one per column. Step sizes match TotemBar's: a checkbox row is 28, a slider
    -- row 44 (it carries its value label above the track), a button row 28, a group heading 22.
    local L, R = 24, PANEL_W / 2 + 6
    local yL, yR = -44, -44
    local lowest = -44

    local function placeL(w, dy)
        w:SetPoint("TOPLEFT", panel, "TOPLEFT", L, yL)
        yL = yL - dy
        if yL < lowest then lowest = yL end
    end
    local function placeR(w, dy)
        w:SetPoint("TOPLEFT", panel, "TOPLEFT", R, yR)
        yR = yR - dy
        if yR < lowest then lowest = yR end
    end
    -- A slider carries its value label ABOVE the track (OptionsSliderTemplate's $parentText,
    -- re-anchored in CreateSlider), so the cursor has to leave room for it before placing the
    -- track -- otherwise the label overlaps whatever sits above, which is exactly how the
    -- "Absorb model" heading ended up written through "Elemental Weapons rank". TotemBar's 44px
    -- slider row is this same allowance, just folded into one number.
    -- Measured, not guessed: with a 14px allowance the value label's top edge sat at rel-y 408.7
    -- while the heading above ended at 414.7 -- a 6px overlap. 24 puts the label 4px clear.
    local SLIDER_LABEL = 24
    local function sliderL(w) yL = yL - SLIDER_LABEL; placeL(w, 26) end
    local function sliderR(w) yR = yR - SLIDER_LABEL; placeR(w, 26) end
    local function headL(text) CreateHeading(panel, text, L, yL); yL = yL - 22; if yL < lowest then lowest = yL end end
    local function headR(text) CreateHeading(panel, text, R, yR); yR = yR - 22; if yR < lowest then lowest = yR end end

    -- left column: frame ------------------------------------------------------------------
    headL("Frame")

    local lock = CreateCheckbox(panel, "Lock position", "Stops the frame from being dragged.",
        function() return db().locked end,
        function(v) db().locked = v end)
    placeL(lock, 28)

    local mm = CreateCheckbox(panel, "Minimap button", "Show the minimap button.",
        function() return db().showMinimapButton end,
        function(v) db().showMinimapButton = v; if BF.UpdateMinimapButton then BF.UpdateMinimapButton() end end)
    placeL(mm, 28)

    local hideInactive = CreateCheckbox(panel, "Hide when idle",
        "Hide the frame when the buffer is down and you are out of combat.",
        function() return db().hideWhenInactive end,
        function(v) db().hideWhenInactive = v end)
    placeL(hideInactive, 28)

    local hideOOC = CreateCheckbox(panel, "Combat only", "Show the frame only while in combat.",
        function() return db().hideOutOfCombat end,
        function(v) db().hideOutOfCombat = v end)
    placeL(hideOOC, 40)

    local scale = CreateSlider(panel, "Scale", 0.5, 2.0, 0.05, "Scale: %.2f",
        "Overall size of the frame.",
        function() return db().scale end,
        function(v) db().scale = v end)
    sliderL(scale)

    local width = CreateSlider(panel, "Width", 80, 400, 5, "Width: %d px",
        "Frame width in pixels.",
        function() return db().width end,
        function(v) db().width = math.floor(v) end)
    sliderL(width)

    local barH = CreateSlider(panel, "Threshold bar height", 6, 30, 1, "Threshold bar: %d px",
        "Height of the hit-threshold bar.",
        function() return db().barHeight end,
        function(v) db().barHeight = math.floor(v) end)
    sliderL(barH)

    local timeH = CreateSlider(panel, "Expiry bar height", 3, 24, 1, "Expiry bar: %d px",
        "Height of the expiry bar. Deliberately flatter than the threshold bar.",
        function() return db().timeBarHeight end,
        function(v) db().timeBarHeight = math.floor(v) end)
    sliderL(timeH)

    local swingH = CreateSlider(panel, "Swing line height", 1, 8, 1, "Swing line: %d px",
        "Thickness of the swing line.",
        function() return db().swingHeight end,
        function(v) db().swingHeight = math.floor(v) end)
    sliderL(swingH)

    local spacing = CreateSlider(panel, "Bar spacing", 0, 10, 1, "Bar spacing: %d px",
        "Vertical gap between the threshold bar, the expiry bar, and the swing line.",
        function() return db().spacing end,
        function(v) db().spacing = math.floor(v) end)
    sliderL(spacing)

    -- right column: elements, colours, model ----------------------------------------------
    local ry = -46
    headR("Elements")

    local e1 = CreateCheckbox(panel, "Hit threshold", "Show the threshold bar.",
        function() return db().showThreshold end,
        function(v) db().showThreshold = v end)
    placeR(e1, 28)

    local e2 = CreateCheckbox(panel, "Expiry", "Show the expiry bar.",
        function() return db().showExpiry end,
        function(v) db().showExpiry = v end)
    placeR(e2, 28)

    local e3 = CreateCheckbox(panel, "Swing timer", "Show the swing line.",
        function() return db().showSwing end,
        function(v) db().showSwing = v end)
    placeR(e3, 28)

    local e3b = CreateCheckbox(panel, "Swing on expiry bar",
        "Let the swing marker ride the expiry bar like pfUI's mana tick, instead of taking its own line.",
        function() return db().swingOnExpiryBar end,
        function(v) db().swingOnExpiryBar = v end)
    placeR(e3b, 28)

    -- Which question the big number answers. A cycle button rather than two checkboxes: the two
    -- readings are exclusive, and showing both at once would invite reading one as the other.
    local modeBtn = CreateButton(panel, "Show: max hit",
        "What the number means. 'max hit' = how large a single hit may be before the buffer is "
        .. "drained. 'max shield' = how much damage it still absorbs. They differ by the absorb "
        .. "rate, so this is not a formatting choice.",
        function()
            local dd = db()
            dd.displayMode = (dd.displayMode == "hit") and "shield" or "hit"
            this:SetText(dd.displayMode == "shield" and "Show: max shield" or "Show: max hit")
            Applied()
        end)
    placeR(modeBtn, 28)
    table.insert(refreshers, function()
        modeBtn:SetText(db().displayMode == "shield" and "Show: max shield" or "Show: max hit")
    end)

    local e4 = CreateCheckbox(panel, "Threshold text", "Show the current / maximum numbers.",
        function() return db().showThresholdText end,
        function(v) db().showThresholdText = v end)
    placeR(e4, 28)

    local e5 = CreateCheckbox(panel, "Expiry text", "Show the remaining seconds as a number.",
        function() return db().showExpiryText end,
        function(v) db().showExpiryText = v end)
    placeR(e5, 28)

    local e6 = CreateCheckbox(panel, "Attack speed text",
        "Show the current weapon attack speed on the left of the expiry bar.",
        function() return db().showSpeedText end,
        function(v) db().showSpeedText = v end)
    placeR(e6, 28)

    local expiryAlpha = CreateSlider(panel, "Expiry bar opacity", 0, 1, 0.05, "Expiry bar opacity: %.2f",
        "Alpha of the expiry bar. Kept lower than the threshold bar by default so it reads as the "
        .. "secondary readout.",
        function() return db().expiryAlpha end,
        function(v) db().expiryAlpha = v end)
    sliderR(expiryAlpha)

    headR("Colours")

    local sw1 = CreateSwatch(panel, "Low", "colorRed", "Colour below the low threshold.")
    placeR(sw1, 24)
    local sw2 = CreateSwatch(panel, "Medium", "colorYellow", "Colour between the two thresholds.")
    placeR(sw2, 24)
    local sw3 = CreateSwatch(panel, "High", "colorGreen", "Colour above the high threshold.")
    placeR(sw3, 24)
    local sw4 = CreateSwatch(panel, "Swing marker", "colorSwing", "Colour of the swing marker.")
    placeR(sw4, 24)

    -- Background colour is a 4-element {r,g,b,a} table; CreateSwatch only ever touches indices
    -- 1..3, so the alpha channel gets its own slider straight onto the same table rather than a
    -- second colour-helper -- there is no opacity-capable picker in this file to reuse.
    local sw5 = CreateSwatch(panel, "Background", "colorBg", "Background colour of the frame.")
    placeR(sw5, 24)

    local bgAlpha = CreateSlider(panel, "Background opacity", 0, 1, 0.05, "Background opacity: %.2f",
        "Opacity of the frame's background panel.",
        function() return (db().colorBg or {})[4] or 0.8 end,
        function(v) local c = db().colorBg; if c then c[4] = v end end)
    sliderR(bgAlpha)

    headR("Thresholds")

    -- Keeps a red/yellow threshold pair from inverting (red > yellow would break the colour
    -- chain in core/calc.lua's poolColorName/timeColorName -- values below "green" would never
    -- reach it, since "red" already claims everything up to its now-higher bound). The slider
    -- the user is actively moving wins; its partner is pulled along to match instead of being
    -- left crossed. Only refreshes the panel when a clamp actually fired, so an ordinary
    -- (non-crossing) drag stays a single write. This is the one place both keys of a pair are
    -- ever written from the panel -- there is no slash-command path for these -- so the clamp
    -- lives here rather than in a shared config setter.
    local function clampPair(loKey, hiKey, movedKey, v)
        local d = db()
        d[movedKey] = v
        if movedKey == loKey and d[hiKey] and d[loKey] > d[hiKey] then
            d[hiKey] = d[loKey]
            BF.RefreshOptions()
        elseif movedKey == hiKey and d[loKey] and d[hiKey] < d[loKey] then
            d[loKey] = d[hiKey]
            BF.RefreshOptions()
        end
    end

    local poolRed = CreateSlider(panel, "Pool red threshold", 0, 100, 5, "Pool turns red below: %.0f%%",
        "The threshold bar turns red at or below this fraction of the pool.",
        function() return (db().poolRed or 0.30) * 100 end,
        function(v) clampPair("poolRed", "poolYellow", "poolRed", v / 100) end)
    sliderR(poolRed)

    local poolYellow = CreateSlider(panel, "Pool yellow threshold", 0, 100, 5, "Pool turns green above: %.0f%%",
        "The threshold bar turns green above this fraction of the pool (yellow in between).",
        function() return (db().poolYellow or 0.70) * 100 end,
        function(v) clampPair("poolRed", "poolYellow", "poolYellow", v / 100) end)
    sliderR(poolYellow)

    local timeRed = CreateSlider(panel, "Expiry red threshold", 0, BF.BUFFER_DURATION, 0.5,
        "Expiry turns red below: %.1fs",
        "The expiry bar turns red once fewer than this many seconds remain.",
        function() return db().timeRed or 2.0 end,
        function(v) clampPair("timeRed", "timeYellow", "timeRed", v) end)
    sliderR(timeRed)

    local timeYellow = CreateSlider(panel, "Expiry yellow threshold", 0, BF.BUFFER_DURATION, 0.5,
        "Expiry turns green above: %.1fs",
        "The expiry bar turns green once more than this many seconds remain (yellow in between).",
        function() return db().timeYellow or 5.0 end,
        function(v) clampPair("timeRed", "timeYellow", "timeYellow", v) end)
    sliderR(timeYellow)

    headR("Absorb model")

    local rank = CreateSlider(panel, "Talent rank", 0, 3, 1, "Elemental Weapons rank: %d",
        "Rank of Elemental Weapons: 5 / 10 / 15 % absorbed. Rank 0 means the talent is not learned.",
        function() return db().talentRank end,
        function(v) db().talentRank = math.floor(v) end)
    sliderR(rank)

    -- Set bonus: the T2.5 "+3 % absorption" wording is ambiguous (15 -> 18, or 15 x 1.03) and
    -- unmeasured. Rather than pick one silently, both readings are selectable and "none" is the
    -- default -- see README.
    local setBtn = CreateButton(panel, "Set bonus: none",
        "T2.5 set bonus reading. 'add' means 15 -> 18 %, 'mult' means 15 x 1.03. Not yet measured.",
        function()
            local d = db()
            if d.setBonusMode == "none" then d.setBonusMode = "add"
            elseif d.setBonusMode == "add" then d.setBonusMode = "mult"
            else d.setBonusMode = "none" end
            this:SetText("Set bonus: " .. d.setBonusMode)
            Applied()
        end)
    placeR(setBtn, 28)
    table.insert(refreshers, function() setBtn:SetText("Set bonus: " .. (db().setBonusMode or "none")) end)

    local setVal = CreateSlider(panel, "Set bonus value", 0, 20, 1, "Set bonus value: %d%%",
        "The set bonus percentage the reading above applies. Only used while the set bonus reading "
        .. "is 'add' or 'mult'.",
        function() return db().setBonusValue end,
        function(v) db().setBonusValue = math.floor(v) end)
    sliderR(setVal)

    local latency = CreateCheckbox(panel, "Latency-adjust swing",
        "Shift the swing marker by your round-trip time, so it shows when to press rather than "
        .. "when the server swung.",
        function() return db().swingUseLatency end,
        function(v) db().swingUseLatency = v; BF.RefreshSwingInputs() end)
    placeR(latency, 28)

    local latencyShare = CreateSlider(panel, "Latency share", 0, 1, 0.05, "Latency share: %.2f",
        "How much of the round-trip time to shift the swing marker by: 1.00 = the full round trip, "
        .. "0.50 = downstream only. Only used while latency-adjust is on.",
        function() return db().swingLatencyShare end,
        function(v) db().swingLatencyShare = v; BF.RefreshSwingInputs() end)
    sliderR(latencyShare)

    headR("Aura IDs")

    local poolAuraBox = CreateEditBox(panel, "Pool aura spell id",
        "Spell id of the Earthen Bulwark Durability debuff, whose stack count is the pool level. "
        .. "TurtleWoW can renumber a custom spell between patches -- if the readout goes blank after "
        .. "an update, /bulwark probe to find the new id and enter it here.",
        function() return db().poolAura end,
        function(v) db().poolAura = v end)
    placeR(poolAuraBox, 36)

    local timeAuraBox = CreateEditBox(panel, "Time aura spell id",
        "Spell id of the Earthen Bulwark buff, whose remaining duration drives the expiry bar. "
        .. "TurtleWoW can renumber a custom spell between patches -- if the readout goes blank after "
        .. "an update, /bulwark probe to find the new id and enter it here.",
        function() return db().timeAura end,
        function(v) db().timeAura = v end)
    placeR(timeAuraBox, 40)

    -- footer -------------------------------------------------------------------------------
    local demoBtn = CreateButton(panel, "Demo", "Run the display off a synthetic cycle so colours "
        .. "and sizes can be judged without a fight.", function()
        local on = BF.ToggleDemo()
        this:SetText(on and "Demo: on" or "Demo")
    end)
    demoBtn:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 24, 20)
    -- The one stateful widget that had no refresher, unlike modeBtn and setBtn above: demo mode can
    -- also be toggled from '/bulwark demo', and without this the button kept whatever label it last
    -- set itself -- reading "Demo" over a running demo, or "Demo: on" over a live readout.
    table.insert(refreshers, function()
        demoBtn:SetText(BF.IsDemo() and "Demo: on" or "Demo")
    end)

    local probeBtn = CreateButton(panel, "Probe", "Dump the live aura/weapon data we still need "
        .. "(also /bulwark probe).", function() BF.RunProbe() end)
    probeBtn:SetPoint("LEFT", demoBtn, "RIGHT", 8, 0)

    local resetBtn = CreateButton(panel, "Reset", "Restore every setting to its default.", function()
        BF.resetConfig()
        Applied()
        BF.RefreshOptions()
        if BF.UpdateMinimapButton then BF.UpdateMinimapButton() end
    end)
    resetBtn:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -24, 20)

    -- Height from the layout cursor, not from a hand-maintained constant. `lowest` tracks the
    -- deepest point either column reached, and the footer row is added below it -- so a new option
    -- can never again end up outside the frame (which is what happened: the last checkbox sat 14px
    -- past the bottom edge after two options were added to a fixed 470).
    local FOOTER = 56
    panel:SetHeight(-lowest + FOOTER)

    -- Footer buttons, full content width split three ways, mirroring TotemBar's block layout.
    local btnW = (PANEL_W - 48 - 16) / 3
    demoBtn:SetWidth(btnW)
    probeBtn:SetWidth(btnW)
    resetBtn:SetWidth(btnW)

    local ver = (GetAddOnMetadata and GetAddOnMetadata("BulwarkFrame", "Version")) or "0.3.1"
    local verFS = panel:CreateFontString("BulwarkFrameOptionsVersion", "OVERLAY", "GameFontNormalSmall")
    ApplyFont(verFS, 10)
    verFS:SetPoint("BOTTOM", panel, "BOTTOM", 0, 6)
    verFS:SetText("v" .. ver)
    verFS:SetTextColor(0.6, 0.6, 0.6)

    -- ESC closes it, like every other panel in this UI.
    tinsert(UISpecialFrames, "BulwarkFrameOptions")

    panel:Hide()
end

function BF.RefreshOptions()
    local i
    for i = 1, table.getn(refreshers) do refreshers[i]() end
end

function BF.ToggleOptions()
    BuildPanel()
    if panel:IsShown() then
        panel:Hide()
    else
        BF.RefreshOptions()
        panel:Show()
    end
end
