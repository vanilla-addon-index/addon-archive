-- ============================================================================
-- action-editor-merge.lua - Merge Cinematic Editor Controller
-- ============================================================================
-- TEMPLATE: views/action-editor-merge.xml
-- PURPOSE: Factory for Merge Cinematic method editor instances
-- DEPENDENCIES: EreaRpMasterCinematicComponent (action-editor-cinematic.lua)
-- INTERFACE:
--   EreaRpMasterMergeEditor.Create(parent, params, methodIndex) -> frame
--   frame:GetParams() -> { mergeGroup = string }
--   frame:SetParams(params)
--   frame:SaveToLibrary()
-- ============================================================================

EreaRpMasterMergeEditor = {}

local counter = 0
local dropdownCounter = 0

-- ============================================================================
-- Create - Create a new Merge Cinematic editor instance
-- ============================================================================
function EreaRpMasterMergeEditor.Create(parent, params, methodIndex)
    counter = counter + 1
    local frame = CreateFrame("Frame", "EreaRpMasterMergeEditor" .. counter, parent, "EreaRpMasterMergeEditorTemplate")
    frame:SetWidth(parent:GetWidth() - 10)

    -- Set method title
    local title = _G[frame:GetName() .. "Title"]
    title:SetText("|cFFFFD700Method " .. methodIndex .. ":|r Merge Cinematic")

    -- Get XML child references
    local idEdit = _G[frame:GetName() .. "IdEdit"]

    -- ---- Create group selection dropdown dynamically ----

    dropdownCounter = dropdownCounter + 1
    local groupDropdownName = "EreaRpMasterMergeEditorGroup" .. dropdownCounter
    local groupDropdown = CreateFrame("Frame", groupDropdownName, frame, "UIDropDownMenuTemplate")
    groupDropdown:SetPoint("TOPLEFT", 0, -48)
    UIDropDownMenu_SetWidth(270, groupDropdown)  -- bounded left of text column (~355px)

    -- ---- Embed the shared cinematic component ----

    local cinematicTop = -120
    local cinematic, cinematicHeight = EreaRpMasterCinematicComponent.Create(frame, cinematicTop)

    -- Initial column layout based on current frame width, then reflow on resize
    cinematic.Reflow(frame:GetWidth())
    frame:SetScript("OnSizeChanged", function()
        cinematic.Reflow(this:GetWidth()) -- Lua 5.0: this
    end)

    -- ---- Create amount and description fields dynamically ----

    local postCinematicY = cinematicTop - cinematicHeight - 10

    local amountLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    amountLabel:SetPoint("TOPLEFT", 20, postCinematicY)
    amountLabel:SetText("Amount:")

    local amountEdit = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    amountEdit:SetPoint("TOPLEFT", 20, postCinematicY - 18)
    amountEdit:SetWidth(80)
    amountEdit:SetHeight(25)
    amountEdit:SetAutoFocus(false)
    amountEdit:SetText("2")
    amountEdit:SetScript("OnEscapePressed", function() this:ClearFocus() end) -- Lua 5.0: this

    local amtHint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    amtHint:SetPoint("LEFT", amountEdit, "RIGHT", 10, 0)
    amtHint:SetText("|cFF888888(Triggers within 5s to merge)|r")

    local descLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    descLabel:SetPoint("TOPLEFT", 20, postCinematicY - 48)
    descLabel:SetText("Description:")

    local descEdit = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    descEdit:SetPoint("TOPLEFT", 20, postCinematicY - 66)
    descEdit:SetWidth(320)
    descEdit:SetHeight(25)
    descEdit:SetAutoFocus(false)
    descEdit:SetScript("OnEscapePressed", function() this:ClearFocus() end) -- Lua 5.0: this

    -- Save merge group button
    local saveBtnY = postCinematicY - 98
    local saveBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    saveBtn:SetPoint("TOPLEFT", 20, saveBtnY)
    saveBtn:SetWidth(140)
    saveBtn:SetHeight(22)
    saveBtn:SetText("Save Merge Group")

    -- Adjust total frame height
    frame:SetHeight(math.abs(saveBtnY) + 30)

    -- ---- Helper functions ----

    local function LoadMergeGroup(groupId)
        if not EreaRpMasterDB or not EreaRpMasterDB.mergeLibrary then return end
        local entry = EreaRpMasterDB.mergeLibrary[groupId]
        if not entry then return end

        idEdit:SetText(groupId)
        idEdit:EnableKeyboard(false)  -- Cannot change ID of existing group
        amountEdit:SetText(tostring(entry.amount or 2))
        descEdit:SetText(entry.description or "")

        -- Load cinematic data (speaker, dialogue, sides)
        cinematic:SetData(entry)
    end

    local function ClearForm()
        idEdit:SetText("")
        idEdit:EnableKeyboard(true)
        amountEdit:SetText("2")
        descEdit:SetText("")
        cinematic:Clear()
    end

    -- ---- Initialize group selection dropdown ----

    UIDropDownMenu_Initialize(groupDropdown, function()
        -- "(New) Create new merge group"
        local newInfo = {}
        newInfo.text = "(New) Create new merge group"
        newInfo.value = "_NEW_"
        newInfo.func = function()
            UIDropDownMenu_SetSelectedValue(groupDropdown, "_NEW_")
            UIDropDownMenu_SetText("(New) Create new merge group", groupDropdown)
            ClearForm()
        end
        UIDropDownMenu_AddButton(newInfo)

        -- Existing merge groups
        if EreaRpMasterDB and EreaRpMasterDB.mergeLibrary then
            for groupId, entry in pairs(EreaRpMasterDB.mergeLibrary) do
                local info = {}
                info.text = groupId .. ": " .. (entry.description or "")
                info.value = groupId
                do
                    local gid = groupId
                    info.func = function()
                        UIDropDownMenu_SetSelectedValue(groupDropdown, gid)
                        UIDropDownMenu_SetText(gid, groupDropdown)
                        LoadMergeGroup(gid)
                    end
                end
                UIDropDownMenu_AddButton(info)
            end
        end
    end)
    UIDropDownMenu_SetText("Select merge group...", groupDropdown)

    -- ---- Helper to build save data from cinematic + merge fields ----

    local function BuildSaveData()
        local data = cinematic:GetData()
        data.amount = tonumber(amountEdit:GetText()) or 2
        data.description = descEdit:GetText() or ""

        -- Build script references
        local scriptRefs = cinematic.GetScriptReferences()
        local scriptRefsStr = ""
        if table.getn(scriptRefs) > 0 then -- Lua 5.0: table.getn
            scriptRefsStr = table.concat(scriptRefs, ",")
        end
        data.scriptReferences = scriptRefsStr

        return data
    end

    -- ---- Save button handler ----

    saveBtn:SetScript("OnClick", function()
        local groupId = idEdit:GetText() or ""
        local data = BuildSaveData()

        -- Validate
        if groupId == "" then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[RP Master]|r Group ID is required", 1, 0, 0)
            return
        end
        if not string.find(groupId, "^[%w_]+$") then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[RP Master]|r Group ID can only contain letters, numbers, and underscores", 1, 0, 0)
            return
        end
        if data.speakerName == "" then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[RP Master]|r Speaker name is required", 1, 0, 0)
            return
        end
        if data.messageTemplate == "" then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[RP Master]|r Dialogue text is required", 1, 0, 0)
            return
        end
        if data.amount < 1 then data.amount = 1 end

        -- Save to library
        if not EreaRpMasterDB.mergeLibrary then
            EreaRpMasterDB.mergeLibrary = {}
        end
        EreaRpMasterDB.mergeLibrary[groupId] = data

        -- Select the saved group in the dropdown
        UIDropDownMenu_SetSelectedValue(groupDropdown, groupId)
        UIDropDownMenu_SetText(groupId, groupDropdown)
        idEdit:EnableKeyboard(false)

        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RP Master]|r Saved merge group: " .. groupId, 0, 1, 0)
    end)

    -- ---- Public interface ----

    function frame:GetParams()
        local selectedValue = UIDropDownMenu_GetSelectedValue(groupDropdown) or ""
        if selectedValue == "_NEW_" then
            selectedValue = ""
        end
        return {
            mergeGroup = selectedValue
        }
    end

    function frame:SetParams(p)
        if p and p.mergeGroup and p.mergeGroup ~= "" then
            UIDropDownMenu_SetSelectedValue(groupDropdown, p.mergeGroup)
            UIDropDownMenu_SetText(p.mergeGroup, groupDropdown)
            LoadMergeGroup(p.mergeGroup)
        end
    end

    function frame:GetPreviewData()
        return cinematic:GetData()
    end

    function frame:SaveToLibrary()
        -- Called during SaveCurrentAction to persist changes
        local groupId = idEdit:GetText() or ""
        if groupId == "" or groupId == "_NEW_" then return end

        local data = BuildSaveData()
        if data.speakerName == "" and data.messageTemplate == "" then return end

        if not EreaRpMasterDB.mergeLibrary then
            EreaRpMasterDB.mergeLibrary = {}
        end
        EreaRpMasterDB.mergeLibrary[groupId] = data
    end

    -- Pre-populate if params provided
    if params then
        frame:SetParams(params)
    end

    return frame
end
