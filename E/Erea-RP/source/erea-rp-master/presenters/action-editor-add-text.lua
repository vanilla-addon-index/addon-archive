-- ============================================================================
-- action-editor-add-text.lua - Add Text Editor Controller
-- ============================================================================
-- TEMPLATE: views/action-editor-add-text.xml
-- PURPOSE: Factory for Add Text (Set Custom Text) method editor instances
-- INTERFACE:
--   EreaRpMasterAddTextEditor.Create(parent, params, methodIndex) -> frame
--   frame:GetParams() -> { instruction = string }
--   frame:SetParams(params)
-- ============================================================================

EreaRpMasterAddTextEditor = {}

local counter = 0

-- ============================================================================
-- Create - Create a new editor instance from virtual template
-- ============================================================================
-- @param parent: Parent frame to attach to
-- @param params: Parameter table with optional instruction field
-- @param methodIndex: Index of this method in the methods array
-- @returns: editor frame with GetParams/SetParams methods
-- ============================================================================
function EreaRpMasterAddTextEditor.Create(parent, params, methodIndex)
    counter = counter + 1
    local frame = CreateFrame("Frame", "EreaRpMasterAddTextEditor" .. counter, parent, "EreaRpMasterAddTextEditorTemplate")
    frame:SetWidth(parent:GetWidth() - 10)

    -- Set method title
    local title = _G[frame:GetName() .. "Title"]
    title:SetText("|cFFFFD700Method " .. methodIndex .. ":|r Set Custom Text")

    -- Get child references
    local instructionEdit = _G[frame:GetName() .. "InstructionEdit"]

    function frame:GetParams()
        return {
            instruction = instructionEdit:GetText() or ""
        }
    end

    function frame:SetParams(p)
        if p and p.instruction then
            instructionEdit:SetText(p.instruction)
        end
    end

    -- Pre-populate if params provided
    if params then
        frame:SetParams(params)
    end

    return frame
end
