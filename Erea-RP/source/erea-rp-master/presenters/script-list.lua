-- ============================================================================
-- script-list.lua - EreaRpMasterScriptListFrame Controller
-- ============================================================================
-- UI Structure: views/script-list.xml
-- Frame: EreaRpMasterScriptListFrame (defined in XML)
--
-- PURPOSE: Manages the script list UI — row pool, selection, editor,
--          test execution, save/delete actions.
--
-- METHODS:
--   EreaRpMasterScriptListFrame:Initialize()       - Setup refs, handlers
--   EreaRpMasterScriptListFrame:RefreshList()       - Rebuild script name rows
--   EreaRpMasterScriptListFrame:GetOrCreateRow(i)   - Row pool management
--   EreaRpMasterScriptListFrame:SelectScript(name)  - Highlight + load editor
--   EreaRpMasterScriptListFrame:LoadEditor(script)  - Populate editor fields
--   EreaRpMasterScriptListFrame:ClearEditor()       - Reset editor to empty
--   EreaRpMasterScriptListFrame:OnSave()            - Validate + save
--   EreaRpMasterScriptListFrame:OnTest()            - Validate + execute
--   EreaRpMasterScriptListFrame:OnNew()             - Create empty script
--   EreaRpMasterScriptListFrame:OnDelete()          - Delete with confirmation
--
-- DEPENDENCIES:
--   - EreaRpMasterScriptLibrary (services/script-library.lua)
--   - EreaRpMasterDB (SavedVariable)
-- ============================================================================

local ROW_HEIGHT = 22

-- Helper: set result text with color (EditBox doesn't render |cFF codes)
local function SetResult(text, r, g, b)
    local rt = EreaRpMasterScriptListFrame.resultText
    rt:SetText(text)
    rt:SetTextColor(r or 1, g or 1, b or 1)
end

-- ============================================================================
-- Initialize
-- ============================================================================
function EreaRpMasterScriptListFrame:Initialize()
    local self = EreaRpMasterScriptListFrame

    -- Store frame references
    self.leftPanel = EreaRpMasterScriptListFrameLeftPanel
    self.scrollFrame = EreaRpMasterScriptListScrollFrame
    self.scrollChild = EreaRpMasterScriptListScrollFrameScrollChild
    self.rightPanel = EreaRpMasterScriptListFrameRightPanel
    self.nameEditBox = EreaRpMasterScriptListFrameRightPanelNameEditBox
    self.descEditBox = EreaRpMasterScriptListFrameRightPanelDescEditBox
    self.bodyEditBox = EreaRpMasterScriptBodyEditBox
    self.bodyScroll = EreaRpMasterScriptBodyScroll
    self.resultText = EreaRpMasterScriptListFrameRightPanelResultText
    self.testButton = EreaRpMasterScriptListFrameRightPanelTestButton
    self.saveButton = EreaRpMasterScriptListFrameRightPanelSaveButton
    self.newButton = EreaRpMasterScriptListFrameLeftPanelNewButton
    self.deleteButton = EreaRpMasterScriptListFrameLeftPanelDeleteButton

    -- Test console inputs
    self.testPlayerInput = EreaRpMasterScriptListFrameRightPanelTestSectionPlayerInput
    self.testItemInput = EreaRpMasterScriptListFrameRightPanelTestSectionItemInput

    -- Row pool
    self.rowFrames = {}
    self.selectedScriptName = nil

    -- OnShow -> auto-refresh and size the script body EditBox to its scroll frame
    self:SetScript("OnShow", function()
        EreaRpMasterScriptListFrame:RefreshList()
        local scrollWidth = EreaRpMasterScriptListFrame.bodyScroll:GetWidth()
        if scrollWidth and scrollWidth > 0 then
            EreaRpMasterScriptListFrame.bodyEditBox:SetWidth(scrollWidth)
        end
    end)

    -- New button
    self.newButton:SetScript("OnClick", function()
        EreaRpMasterScriptListFrame:OnNew()
    end)

    -- Delete button
    self.deleteButton:SetScript("OnClick", function()
        EreaRpMasterScriptListFrame:OnDelete()
    end)

    -- Test button
    self.testButton:SetScript("OnClick", function()
        EreaRpMasterScriptListFrame:OnTest()
    end)

    -- Save button
    self.saveButton:SetScript("OnClick", function()
        EreaRpMasterScriptListFrame:OnSave()
    end)
end

-- ============================================================================
-- GetOrCreateRow - Row pool for left panel script names
-- ============================================================================
function EreaRpMasterScriptListFrame:GetOrCreateRow(index)
    local self = EreaRpMasterScriptListFrame

    if self.rowFrames[index] then
        return self.rowFrames[index]
    end

    local row = CreateFrame("Button", "EreaRpMasterScriptRow" .. index, self.scrollChild)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", 0, -((index - 1) * ROW_HEIGHT))
    row:SetPoint("TOPRIGHT", self.scrollChild, "TOPRIGHT", -20, -((index - 1) * ROW_HEIGHT))

    -- Backdrop for selection highlight
    row:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = nil,
        tile = true, tileSize = 16,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    row:SetBackdropColor(0, 0, 0, 0)

    -- Name text
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("LEFT", row, "LEFT", 8, 0)
    nameText:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    nameText:SetJustifyH("LEFT")
    row.nameText = nameText

    -- Highlight on hover
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

    -- Click handler (set per-row during RefreshList)
    row.scriptName = nil

    self.rowFrames[index] = row
    return row
end

-- ============================================================================
-- RefreshList - Rebuild script name rows from service
-- ============================================================================
function EreaRpMasterScriptListFrame:RefreshList()
    local self = EreaRpMasterScriptListFrame

    local scripts = EreaRpMasterScriptLibrary:GetAllScripts()
    local scriptCount = table.getn(scripts) -- Lua 5.0: no # operator

    -- Update scroll child dimensions
    local totalHeight = scriptCount * ROW_HEIGHT
    if totalHeight < 1 then totalHeight = 1 end
    self.scrollChild:SetHeight(totalHeight)
    self.scrollChild:SetWidth(self.scrollFrame:GetWidth())

    -- Populate rows
    for i = 1, scriptCount do
        local script = scripts[i]
        local row = self:GetOrCreateRow(i)

        row.scriptName = script.name
        row.nameText:SetText(script.name)

        -- Highlight selected row
        if self.selectedScriptName and self.selectedScriptName == script.name then
            row:SetBackdropColor(0.2, 0.2, 0.4, 1)
        else
            row:SetBackdropColor(0, 0, 0, 0)
        end

        row:SetScript("OnClick", function()
            EreaRpMasterScriptListFrame:SelectScript(row.scriptName)
        end)

        row:Show()
    end

    -- Hide extra rows
    local rowIndex = scriptCount + 1
    while self.rowFrames[rowIndex] do
        self.rowFrames[rowIndex]:Hide()
        rowIndex = rowIndex + 1
    end
end

-- ============================================================================
-- SelectScript - Highlight row and load into editor
-- ============================================================================
function EreaRpMasterScriptListFrame:SelectScript(name)
    local self = EreaRpMasterScriptListFrame

    self.selectedScriptName = name

    local script = EreaRpMasterScriptLibrary:GetScript(name)
    if script then
        self:LoadEditor(script)
    else
        self:ClearEditor()
    end

    -- Refresh row highlights
    self:RefreshList()
end

-- ============================================================================
-- LoadEditor - Populate editor fields from script data
-- ============================================================================
function EreaRpMasterScriptListFrame:LoadEditor(script)
    local self = EreaRpMasterScriptListFrame

    self.nameEditBox:SetText(script.name or "")
    self.descEditBox:SetText(script.description or "")
    self.bodyEditBox:SetText(script.body or "")
    SetResult("")
end

-- ============================================================================
-- ClearEditor - Reset editor to empty
-- ============================================================================
function EreaRpMasterScriptListFrame:ClearEditor()
    local self = EreaRpMasterScriptListFrame

    self.nameEditBox:SetText("")
    self.descEditBox:SetText("")
    self.bodyEditBox:SetText("")
    SetResult("")
    self.testPlayerInput:SetText("")
    self.testItemInput:SetText("")
end

-- ============================================================================
-- OnSave - Validate and save script
-- ============================================================================
function EreaRpMasterScriptListFrame:OnSave()
    local self = EreaRpMasterScriptListFrame

    local name = self.nameEditBox:GetText()
    local description = self.descEditBox:GetText()
    local body = self.bodyEditBox:GetText()

    if not name or name == "" then
        SetResult("Error: Script name is required", 1, 0, 0)
        return
    end

    -- Validate script compiles
    local ok, err = EreaRpMasterScriptLibrary:ValidateScript(body)
    if not ok then
        SetResult(tostring(err), 1, 0, 0)
        return
    end

    -- If renaming (name changed from selected), delete old entry
    if self.selectedScriptName and self.selectedScriptName ~= name then
        EreaRpMasterScriptLibrary:DeleteScript(self.selectedScriptName)
    end

    local saved = EreaRpMasterScriptLibrary:SaveScript(name, description, body)
    if not saved then
        SetResult("Error: Failed to save (DB not ready)", 1, 0, 0)
        return
    end
    self.selectedScriptName = name
    SetResult("Script saved.", 0, 1, 0)
    self:RefreshList()
end

-- ============================================================================
-- OnTest - Validate and execute script, show result
-- ============================================================================
function EreaRpMasterScriptListFrame:OnTest()
    local self = EreaRpMasterScriptListFrame

    local body = self.bodyEditBox:GetText()

    if not body or body == "" then
        SetResult("Error: Script body is empty", 1, 0, 0)
        return
    end

    -- Build context from test console inputs
    local playerName = self.testPlayerInput:GetText()
    local itemName = self.testItemInput:GetText()
    local context = {
        playerName = (playerName ~= "") and playerName or nil,
        item = (itemName ~= "") and { name = itemName } or {}
    }

    local ok, result = EreaRpMasterScriptLibrary:ExecuteScriptBody(body, context)
    if ok then
        SetResult(tostring(result), 0, 1, 0)
    else
        SetResult(tostring(result), 1, 0, 0)
    end
end

-- ============================================================================
-- OnNew - Create empty script and select it
-- ============================================================================
function EreaRpMasterScriptListFrame:OnNew()
    local self = EreaRpMasterScriptListFrame

    self.selectedScriptName = nil
    self:ClearEditor()
    self.nameEditBox:SetFocus()
end

-- ============================================================================
-- OnDelete - Delete selected script with confirmation
-- ============================================================================
-- Uses StaticPopup with global pattern (no closures) for Lua 5.0
-- ============================================================================
_PendingDeleteScriptName = nil

StaticPopupDialogs["EREA_RP_MASTER_DELETE_SCRIPT"] = {
    text = "Delete script '%s'?",
    button1 = "Delete",
    button2 = "Cancel",
    OnAccept = function()
        if _PendingDeleteScriptName then
            EreaRpMasterScriptLibrary:DeleteScript(_PendingDeleteScriptName)
            EreaRpMasterScriptListFrame.selectedScriptName = nil
            EreaRpMasterScriptListFrame:ClearEditor()
            EreaRpMasterScriptListFrame:RefreshList()
            _PendingDeleteScriptName = nil
        end
    end,
    OnCancel = function()
        _PendingDeleteScriptName = nil
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1
}

function EreaRpMasterScriptListFrame:OnDelete()
    local self = EreaRpMasterScriptListFrame

    if not self.selectedScriptName then
        SetResult("No script selected", 1, 0, 0)
        return
    end

    _PendingDeleteScriptName = self.selectedScriptName
    StaticPopup_Show("EREA_RP_MASTER_DELETE_SCRIPT", self.selectedScriptName)
end
