-- ============================================================================
-- action-editor-cinematic.lua - Cinematic Editor (shared component)
-- ============================================================================
-- PURPOSE: Reusable cinematic editing block used by both Display Cinematic
--          and Merge Cinematic editors.
--
-- LAYOUT (3-column, all starting at yOffset):
--
--   yOffset+0:   hint text (left portion, gray)              | "Title:"
--   yOffset-18:  "Script references (inferred): ..."         | Title EditBox
--   yOffset-36:  script ref display (green, left portion)    |
--   yOffset-54:  "Left side:"   "Right side:"                | "Text:"
--   yOffset-72:  [type dd]      [type dd]                    | Text EditBox (top)
--   yOffset-96:  [sub labels]   [sub labels]                 | ...
--   yOffset-114: [sub dd+prv]   [sub dd+prv]                 | Text EditBox (bottom)
--
--   Left side column:  xOffset=5,   ~165px wide
--   Right side column: xOffset=178, ~165px wide
--   Text column:       TOPRIGHT(-10), width=150
--
-- DEPENDENCIES: EreaRpMasterSideEditor (action-editor-side.lua)
--
-- INTERFACE:
--   EreaRpMasterCinematicComponent.Create(parent, yOffset) -> component, height
--   component:GetData()  -> { speakerName, messageTemplate, left/right fields }
--   component:SetData(data)
--   component:Clear()
--   component.GetScriptReferences() -> { scriptName, ... }
-- ============================================================================

EreaRpMasterCinematicComponent = {}

-- ============================================================================
-- HELPERS (module-local)
-- ============================================================================

local function GetScriptReferencesFromText(text)
    local scriptNames = {}
    if not text or text == "" then return scriptNames end

    -- Lua 5.0: manual parsing for {script:XXX} placeholders
    local i = 1
    while i <= string.len(text) do
        local start_script, end_script = string.find(text, "{script:", i, true)
        if start_script then
            local start_name = end_script + 1
            local end_name = string.find(text, "}", start_name, true)
            if end_name then
                local scriptName = string.sub(text, start_name, end_name - 1)
                table.insert(scriptNames, scriptName)
                i = end_name + 1
            else
                break
            end
        else
            break
        end
    end

    return scriptNames
end

-- ============================================================================
-- Create - Build the cinematic editing block within a parent frame
-- ============================================================================
-- @param parent:   Parent frame (method block frame)
-- @param yOffset:  Y position within parent where this block begins
-- @returns:        component table, totalHeight consumed
-- ============================================================================
function EreaRpMasterCinematicComponent.Create(parent, yOffset)
    local comp = {}

    -- ── Row 0: placeholder hint (left portion) + "Title:" column header ───────

    local hintLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hintLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    hintLabel:SetText("|cFF888888(Use {playerName}, {customText} or {script:name} in Title & Text)|r")

    local titleColLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    titleColLabel:SetPoint("TOPLEFT", parent, "TOPRIGHT", -155, yOffset)
    titleColLabel:SetText("Title:")

    -- ── Row 1: script references label + Title EditBox ─────────────────────────

    local scriptRefLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    scriptRefLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset - 18)
    scriptRefLabel:SetText("Script references (inferred):")

    local titleBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    titleBox:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOffset - 18)
    titleBox:SetWidth(150)
    titleBox:SetHeight(22)
    titleBox:SetAutoFocus(false)
    titleBox:SetMaxLetters(100)
    titleBox:SetScript("OnEscapePressed", function() this:ClearFocus() end) -- Lua 5.0: this

    -- ── Row 2: script references display (bounded left of text column) ─────────

    local scriptRefDisplay = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    scriptRefDisplay:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset - 36)
    scriptRefDisplay:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -165, yOffset - 36)
    scriptRefDisplay:SetJustifyH("LEFT")
    scriptRefDisplay:SetTextColor(0.5, 0.8, 0.5)
    scriptRefDisplay:SetText("(No scripts found)")

    -- ── Row 3: side headers (Left/Right via SideEditor) + "Text:" column header ─

    -- "Left side:" and "Right side:" headers are created inside SideEditor.Create.
    -- We pass yOffset-54 so they appear at row 3.

    local textColLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    textColLabel:SetPoint("TOPLEFT", parent, "TOPRIGHT", -155, yOffset - 54)
    textColLabel:SetText("Text:")

    -- ── Text EditBox (right column, multiline, backdrop container) ─────────────
    -- Spans rows 3-6 alongside the side editors.

    local textContainer = CreateFrame("Frame", nil, parent)
    textContainer:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOffset - 72)
    textContainer:SetWidth(150)
    textContainer:SetHeight(90)
    textContainer:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    textContainer:SetBackdropColor(0.1, 0.1, 0.1, 1)
    textContainer:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    local msgBox = CreateFrame("EditBox", nil, textContainer)
    msgBox:SetMultiLine(true)
    msgBox:SetAutoFocus(false)
    msgBox:SetWidth(136)
    msgBox:SetHeight(78)
    msgBox:SetPoint("TOPLEFT", textContainer, "TOPLEFT", 7, -6)
    msgBox:SetFontObject(ChatFontNormal)
    msgBox:SetTextInsets(3, 3, 3, 3)
    msgBox:SetMaxLetters(500)
    msgBox:SetScript("OnEscapePressed", function() this:ClearFocus() end) -- Lua 5.0: this

    -- ── Left and Right side editors (side by side, sharing rows 3-6) ───────────
    -- Left side column starts at xOffset=5, right at xOffset=178.
    -- Both share the same yOffset-54 so their headers align with "Text:".

    local leftSide,  leftHeight  = EreaRpMasterSideEditor.Create(parent, "Left",  5,   yOffset - 54)
    local rightSide, rightHeight = EreaRpMasterSideEditor.Create(parent, "Right", 178, yOffset - 54)

    -- ── Script reference update helpers ────────────────────────────────────────

    local function GetScriptReferences()
        local scriptNames = {}

        local spkText = titleBox:GetText() or ""
        local spkRefs = GetScriptReferencesFromText(spkText)
        for i = 1, table.getn(spkRefs) do -- Lua 5.0: table.getn
            table.insert(scriptNames, spkRefs[i])
        end

        local msgText = msgBox:GetText() or ""
        local msgRefs = GetScriptReferencesFromText(msgText)
        for i = 1, table.getn(msgRefs) do -- Lua 5.0: table.getn
            table.insert(scriptNames, msgRefs[i])
        end

        -- Remove duplicates
        local uniqueNames = {}
        local seen = {}
        for i = 1, table.getn(scriptNames) do -- Lua 5.0: table.getn
            local name = scriptNames[i]
            if not seen[name] then
                table.insert(uniqueNames, name)
                seen[name] = true
            end
        end

        return uniqueNames
    end
    comp.GetScriptReferences = GetScriptReferences

    -- Reflow all columns to fill the available frame width.
    -- Called on creation and whenever the parent method frame is resized.
    -- Text column scales at ~28% of frame width; side columns share the rest equally.
    function comp.Reflow(frameWidth)
        local rightPad   = 10
        local textColWidth = math.max(150, math.floor(frameWidth * 0.28))

        -- Side columns share space left of the text column
        -- leftMargin=5, colGap=6, rightPad+textColWidth reserved on the right
        local available = frameWidth - 5 - 6 - textColWidth - rightPad
        local sideWidth = math.floor(available / 2)
        if sideWidth < 100 then sideWidth = 100 end

        -- Reposition and resize side columns
        leftSide.Reposition(5, sideWidth)
        rightSide.Reposition(5 + sideWidth + 6, sideWidth)

        -- Text column: left edge is -(rightPad + textColWidth) from TOPRIGHT
        -- Labels sit 5px inside that left edge
        local labelOffset = -(rightPad + textColWidth - 5)

        titleColLabel:ClearAllPoints()
        titleColLabel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", labelOffset, yOffset)

        textColLabel:ClearAllPoints()
        textColLabel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", labelOffset, yOffset - 54)

        -- Resize Title EditBox
        titleBox:ClearAllPoints()
        titleBox:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -rightPad, yOffset - 18)
        titleBox:SetWidth(textColWidth)

        -- Resize Text container and inner EditBox
        textContainer:ClearAllPoints()
        textContainer:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -rightPad, yOffset - 72)
        textContainer:SetWidth(textColWidth)
        msgBox:SetWidth(textColWidth - 14)  -- 7px inset each side

        -- Script ref display: spans from left margin to just before the text column
        scriptRefDisplay:ClearAllPoints()
        scriptRefDisplay:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset - 36)
        scriptRefDisplay:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -(textColWidth + rightPad + 5), yOffset - 36)
    end

    local function UpdateScriptReferences()
        local uniqueNames = GetScriptReferences()
        if table.getn(uniqueNames) > 0 then -- Lua 5.0: table.getn
            scriptRefDisplay:SetText(table.concat(uniqueNames, ", "))
        else
            scriptRefDisplay:SetText("(No scripts found)")
        end
    end

    -- Wire up real-time script reference updates
    titleBox:SetScript("OnTextChanged", function() UpdateScriptReferences() end)
    msgBox:SetScript("OnTextChanged", function() UpdateScriptReferences() end)

    -- ── Public interface ────────────────────────────────────────────────────────

    function comp:GetData()
        -- Build legacy animationKey from sides (for backwards compat with older saves)
        local legacyAnimKey = ""
        if rightSide:GetType() == "animation" then
            legacyAnimKey = rightSide:GetAnimationKey()
        elseif leftSide:GetType() == "animation" then
            legacyAnimKey = leftSide:GetAnimationKey()
        end

        return {
            speakerName     = titleBox:GetText() or "",
            messageTemplate = msgBox:GetText() or "",
            animationKey    = legacyAnimKey,
            leftType             = leftSide:GetType(),
            leftPortraitUnit     = leftSide:GetPortraitUnit(),
            leftAnimationKey     = leftSide:GetAnimationKey(),
            leftLoopMode         = leftSide:GetLoopMode(),
            rightType            = rightSide:GetType(),
            rightPortraitUnit    = rightSide:GetPortraitUnit(),
            rightAnimationKey    = rightSide:GetAnimationKey(),
            rightLoopMode        = rightSide:GetLoopMode()
        }
    end

    function comp:SetData(data)
        if not data then return end

        titleBox:SetText(data.speakerName or "")
        msgBox:SetText(data.messageTemplate or "")

        -- Load side configs (new fields) or fall back to legacy animationKey
        if data.leftType then
            leftSide:SetType(data.leftType)
            leftSide:SetPortraitUnit(data.leftPortraitUnit or "player")
            leftSide:SetAnimationKey(data.leftAnimationKey or "")
            leftSide:SetLoopMode(data.leftLoopMode or "pingpong")
            rightSide:SetType(data.rightType or "none")
            rightSide:SetPortraitUnit(data.rightPortraitUnit or "player")
            rightSide:SetAnimationKey(data.rightAnimationKey or "")
            rightSide:SetLoopMode(data.rightLoopMode or "pingpong")
        else
            -- Legacy: portrait on left, animation on right if animationKey exists
            leftSide:SetType("portrait")
            leftSide:SetPortraitUnit("player")
            local animKey = data.animationKey or ""
            if animKey ~= "" then
                rightSide:SetType("animation")
                rightSide:SetAnimationKey(animKey)
            else
                rightSide:SetType("none")
            end
        end

        UpdateScriptReferences()
    end

    function comp:Clear()
        titleBox:SetText("")
        msgBox:SetText("")
        leftSide:SetType("none")
        leftSide:SetLoopMode("pingpong")
        rightSide:SetType("none")
        rightSide:SetLoopMode("pingpong")
        scriptRefDisplay:SetText("(No scripts found)")
    end

    -- Total height: sides start at yOffset-54, consume 140px → bottom at yOffset-194.
    -- Text container: top at yOffset-72, height 90 → bottom at yOffset-162.
    -- Return the deeper of the two plus a small bottom margin.
    local totalHeight = 194 + 8  -- 8px bottom padding
    return comp, totalHeight
end
