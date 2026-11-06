-- ============================================================================
-- action-editor-side.lua - Side Editor (shared component)
-- ============================================================================
-- PURPOSE: Factory for left/right side editors used by Display Cinematic
--          and Merge Cinematic editors. Each side lets the user pick a type
--          (None/Portrait/Animation) with sub-fields for portrait unit or
--          animation selection, plus a live VideoPlayer preview.
--
-- INTERFACE:
--   EreaRpMasterSideEditor.Create(parent, sideLabel, xOffset, yOffset) -> side, height
--   side:GetType()          -> "none"|"portrait"|"animation"
--   side:GetPortraitUnit()  -> "player"|"target"
--   side:GetAnimationKey()  -> string
--   side:SetType(val)
--   side:SetPortraitUnit(val)
--   side:SetAnimationKey(val)
-- ============================================================================

EreaRpMasterSideEditor = {}

local dropdownCounter = 0
local previewCounter = 0

-- ============================================================================
-- Create - Create type/portrait/animation dropdowns for one side
-- ============================================================================
-- @param parent:     Parent frame
-- @param sideLabel:  "Left" or "Right"
-- @param xOffset:    Horizontal offset within parent (column position)
-- @param yOffset:    Y offset within parent
-- @returns: sideEditor table, totalHeight consumed (100)
-- ============================================================================
function EreaRpMasterSideEditor.Create(parent, sideLabel, xOffset, yOffset)
    local side = {}

    local cinematicAnims = EreaRpLibraries:CinematicAnimations()
    local videoPlayerLib = EreaRpLibraries:VideoPlayer()

    -- Section header
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header:SetPoint("TOPLEFT", xOffset + 10, yOffset)
    header:SetText("|cFFFFD700" .. sideLabel .. " side:|r")

    -- Type dropdown: [None, Portrait, Animation]
    dropdownCounter = dropdownCounter + 1
    local typeDropdownName = "EreaRpMasterSideEditorType" .. dropdownCounter
    local typeDropdown = CreateFrame("Frame", typeDropdownName, parent, "UIDropDownMenuTemplate")
    typeDropdown:SetPoint("TOPLEFT", xOffset, yOffset - 18)
    UIDropDownMenu_SetWidth(100, typeDropdown)  -- Lua 5.0: WoW 1.12 arg order is (width, dropdown)

    -- Portrait unit dropdown: [Player (sender), Target (sender's target)]
    dropdownCounter = dropdownCounter + 1
    local unitDropdownName = "EreaRpMasterSideEditorUnit" .. dropdownCounter
    local unitDropdown = CreateFrame("Frame", unitDropdownName, parent, "UIDropDownMenuTemplate")
    unitDropdown:SetPoint("TOPLEFT", xOffset, yOffset - 58)
    UIDropDownMenu_SetWidth(95, unitDropdown)  -- Lua 5.0: WoW 1.12 arg order is (width, dropdown)
    unitDropdown:Hide()

    local unitLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    unitLabel:SetPoint("TOPLEFT", xOffset + 10, yOffset - 42)
    unitLabel:SetText("Portrait unit:")
    unitLabel:Hide()

    -- Animation dropdown
    dropdownCounter = dropdownCounter + 1
    local animDropdownName = "EreaRpMasterSideEditorAnim" .. dropdownCounter
    local animDropdown = CreateFrame("Frame", animDropdownName, parent, "UIDropDownMenuTemplate")
    animDropdown:SetPoint("TOPLEFT", xOffset, yOffset - 58)
    UIDropDownMenu_SetWidth(72, animDropdown)  -- Lua 5.0: WoW 1.12 arg order is (width, dropdown)
    animDropdown:Hide()

    local animLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    animLabel:SetPoint("TOPLEFT", xOffset + 10, yOffset - 42)
    animLabel:SetText("Animation:")
    animLabel:Hide()

    -- Loop mode dropdown: [Ping-Pong, Cycle] — only visible for animation type
    dropdownCounter = dropdownCounter + 1
    local loopModeDropdownName = "EreaRpMasterSideEditorLoopMode" .. dropdownCounter
    local loopModeDropdown = CreateFrame("Frame", loopModeDropdownName, parent, "UIDropDownMenuTemplate")
    loopModeDropdown:SetPoint("TOPLEFT", xOffset, yOffset - 96)
    UIDropDownMenu_SetWidth(72, loopModeDropdown)
    loopModeDropdown:Hide()

    local loopModeLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    loopModeLabel:SetPoint("TOPLEFT", xOffset + 10, yOffset - 80)
    loopModeLabel:SetText("Loop:")
    loopModeLabel:Hide()

    -- Live preview: 36x36 frame with VideoPlayer, to the right of the animation dropdown
    previewCounter = previewCounter + 1
    local previewFrameName = "EreaRpMasterSideEditorPreview" .. previewCounter
    local previewFrame = CreateFrame("Frame", previewFrameName, parent)
    previewFrame:SetWidth(36)
    previewFrame:SetHeight(36)
    previewFrame:SetPoint("LEFT", animDropdown, "RIGHT", 5, 0)
    previewFrame:Hide()

    local previewTexture = previewFrame:CreateTexture(nil, "ARTWORK")
    previewTexture:SetAllPoints(previewFrame)

    local previewPlayer = videoPlayerLib.New(previewTexture)

    local function SetPreviewAnimation(animKey, loopMode)
        previewPlayer:Stop()
        if animKey and animKey ~= "" then
            previewPlayer:Play(animKey, loopMode)
            if previewPlayer:IsPlaying() then
                previewFrame:Show()
            else
                previewFrame:Hide()
            end
        else
            previewFrame:Hide()
        end
    end

    -- Helper: show/hide sub-fields based on type
    local function UpdateSubFields(selectedType)
        if selectedType == "portrait" then
            unitDropdown:Show()
            unitLabel:Show()
            animDropdown:Hide()
            animLabel:Hide()
            loopModeDropdown:Hide()
            loopModeLabel:Hide()
            previewFrame:Hide()
            previewPlayer:Stop()
        elseif selectedType == "animation" then
            unitDropdown:Hide()
            unitLabel:Hide()
            animDropdown:Show()
            animLabel:Show()
            loopModeDropdown:Show()
            loopModeLabel:Show()
            -- Restore preview if an animation is selected
            local currentAnim = UIDropDownMenu_GetSelectedValue(animDropdown) or ""
            local currentLoopMode = UIDropDownMenu_GetSelectedValue(loopModeDropdown) or "pingpong"
            SetPreviewAnimation(currentAnim, currentLoopMode)
        else
            unitDropdown:Hide()
            unitLabel:Hide()
            animDropdown:Hide()
            animLabel:Hide()
            loopModeDropdown:Hide()
            loopModeLabel:Hide()
            previewFrame:Hide()
            previewPlayer:Stop()
        end
    end

    -- Initialize type dropdown
    UIDropDownMenu_Initialize(typeDropdown, function()
        local types = {
            { text = "None", value = "none" },
            { text = "Portrait", value = "portrait" },
            { text = "Animation", value = "animation" }
        }
        for i = 1, table.getn(types) do -- Lua 5.0: table.getn
            local t = types[i]
            local info = {}
            info.text = t.text
            info.value = t.value
            do
                local val = t.value
                local txt = t.text
                info.func = function()
                    UIDropDownMenu_SetSelectedValue(typeDropdown, val)
                    UIDropDownMenu_SetText(txt, typeDropdown)
                    UpdateSubFields(val)
                end
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetSelectedValue(typeDropdown, "none")
    UIDropDownMenu_SetText("None", typeDropdown)

    -- Initialize unit dropdown
    UIDropDownMenu_Initialize(unitDropdown, function()
        local units = {
            { text = "Player (sender)", value = "player" },
            { text = "Target (sender's target)", value = "target" }
        }
        for i = 1, table.getn(units) do -- Lua 5.0: table.getn
            local u = units[i]
            local info = {}
            info.text = u.text
            info.value = u.value
            do
                local val = u.value
                local txt = u.text
                info.func = function()
                    UIDropDownMenu_SetSelectedValue(unitDropdown, val)
                    UIDropDownMenu_SetText(txt, unitDropdown)
                end
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetSelectedValue(unitDropdown, "player")
    UIDropDownMenu_SetText("Player (sender)", unitDropdown)

    -- Initialize animation dropdown
    UIDropDownMenu_Initialize(animDropdown, function()
        local noneInfo = {}
        noneInfo.text = "(None)"
        noneInfo.value = ""
        noneInfo.func = function()
            UIDropDownMenu_SetSelectedValue(animDropdown, "")
            UIDropDownMenu_SetText("(None)", animDropdown)
            SetPreviewAnimation(nil)
        end
        UIDropDownMenu_AddButton(noneInfo)

        local animList = cinematicAnims.GetAnimationList()
        for i = 1, table.getn(animList) do -- Lua 5.0: table.getn
            local entry = animList[i]
            local info = {}
            info.text = entry.label
            info.value = entry.key
            do
                local selectedKey = entry.key
                local selectedLabel = entry.label
                info.func = function()
                    UIDropDownMenu_SetSelectedValue(animDropdown, selectedKey)
                    UIDropDownMenu_SetText(selectedLabel, animDropdown)
                    local currentLoopMode = UIDropDownMenu_GetSelectedValue(loopModeDropdown) or "pingpong"
                    SetPreviewAnimation(selectedKey, currentLoopMode)
                end
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetText("(None)", animDropdown)

    -- Initialize loop mode dropdown
    UIDropDownMenu_Initialize(loopModeDropdown, function()
        local modes = {
            { text = "Ping-Pong", value = "pingpong" },
            { text = "Cycle",     value = "cycle" }
        }
        for i = 1, table.getn(modes) do -- Lua 5.0: table.getn
            local m = modes[i]
            local info = {}
            info.text = m.text
            info.value = m.value
            do
                local val = m.value
                local txt = m.text
                info.func = function()
                    UIDropDownMenu_SetSelectedValue(loopModeDropdown, val)
                    UIDropDownMenu_SetText(txt, loopModeDropdown)
                    local currentAnim = UIDropDownMenu_GetSelectedValue(animDropdown) or ""
                    SetPreviewAnimation(currentAnim, val)
                end
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetSelectedValue(loopModeDropdown, "pingpong")
    UIDropDownMenu_SetText("Ping-Pong", loopModeDropdown)

    -- Getters/setters
    function side:GetType()
        return UIDropDownMenu_GetSelectedValue(typeDropdown) or "none"
    end

    function side:GetPortraitUnit()
        return UIDropDownMenu_GetSelectedValue(unitDropdown) or "player"
    end

    function side:GetAnimationKey()
        return UIDropDownMenu_GetSelectedValue(animDropdown) or ""
    end

    function side:GetLoopMode()
        return UIDropDownMenu_GetSelectedValue(loopModeDropdown) or "pingpong"
    end

    function side:SetType(val)
        UIDropDownMenu_SetSelectedValue(typeDropdown, val or "none")
        if val == "portrait" then
            UIDropDownMenu_SetText("Portrait", typeDropdown)
        elseif val == "animation" then
            UIDropDownMenu_SetText("Animation", typeDropdown)
        else
            UIDropDownMenu_SetText("None", typeDropdown)
        end
        UpdateSubFields(val or "none")
    end

    function side:SetPortraitUnit(val)
        UIDropDownMenu_SetSelectedValue(unitDropdown, val or "player")
        if val == "target" then
            UIDropDownMenu_SetText("Target (sender's target)", unitDropdown)
        else
            UIDropDownMenu_SetText("Player (sender)", unitDropdown)
        end
    end

    function side:SetAnimationKey(val)
        UIDropDownMenu_SetSelectedValue(animDropdown, val or "")
        if val and val ~= "" then
            UIDropDownMenu_SetText(val, animDropdown)
        else
            UIDropDownMenu_SetText("(None)", animDropdown)
        end
        -- Only update live preview when animation type is active;
        -- avoids showing stale animation keys stored alongside a portrait/none type
        if side:GetType() == "animation" then
            local currentLoopMode = UIDropDownMenu_GetSelectedValue(loopModeDropdown) or "pingpong"
            SetPreviewAnimation(val, currentLoopMode)
        end
    end

    function side:SetLoopMode(val)
        local mode = val or "pingpong"
        UIDropDownMenu_SetSelectedValue(loopModeDropdown, mode)
        if mode == "cycle" then
            UIDropDownMenu_SetText("Cycle", loopModeDropdown)
        else
            UIDropDownMenu_SetText("Ping-Pong", loopModeDropdown)
        end
        if side:GetType() == "animation" then
            local currentAnim = UIDropDownMenu_GetSelectedValue(animDropdown) or ""
            SetPreviewAnimation(currentAnim, mode)
        end
    end

    -- Reposition all elements to a new horizontal offset within the parent frame.
    -- newColumnWidth (optional) resizes dropdowns proportionally to available space.
    function side.Reposition(newXOffset, newColumnWidth)
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", newXOffset + 10, yOffset)

        typeDropdown:ClearAllPoints()
        typeDropdown:SetPoint("TOPLEFT", newXOffset, yOffset - 18)

        unitDropdown:ClearAllPoints()
        unitDropdown:SetPoint("TOPLEFT", newXOffset, yOffset - 58)

        unitLabel:ClearAllPoints()
        unitLabel:SetPoint("TOPLEFT", newXOffset + 10, yOffset - 42)

        animDropdown:ClearAllPoints()
        animDropdown:SetPoint("TOPLEFT", newXOffset, yOffset - 58)

        animLabel:ClearAllPoints()
        animLabel:SetPoint("TOPLEFT", newXOffset + 10, yOffset - 42)

        loopModeLabel:ClearAllPoints()
        loopModeLabel:SetPoint("TOPLEFT", newXOffset + 10, yOffset - 80)

        loopModeDropdown:ClearAllPoints()
        loopModeDropdown:SetPoint("TOPLEFT", newXOffset, yOffset - 96)

        -- Preview is anchored relative to animDropdown, moves automatically.

        if newColumnWidth then
            local typeDdWidth = math.min(160, math.max(80, newColumnWidth - 40))
            local animDdWidth = math.min(120, math.max(60, newColumnWidth - 65))
            UIDropDownMenu_SetWidth(typeDdWidth, typeDropdown)
            UIDropDownMenu_SetWidth(typeDdWidth, unitDropdown)
            UIDropDownMenu_SetWidth(animDdWidth, animDropdown)
            UIDropDownMenu_SetWidth(animDdWidth, loopModeDropdown)
        end
    end

    -- Total height consumed: header (18) + type dropdown (40) + anim sub-field (40) + loop mode (40)
    return side, 140
end
