-- ============================================================================
-- action-editor-consume.lua - Consume Charge Editor Controller
-- ============================================================================
-- TEMPLATE: views/action-editor-consume.xml
-- PURPOSE: Factory for Consume Charge method editor instances
-- INTERFACE:
--   EreaRpMasterConsumeEditor.Create(parent, params, methodIndex) -> frame
--   frame:GetParams() -> {}
--   frame:SetParams(params)
-- ============================================================================

EreaRpMasterConsumeEditor = {}

local counter = 0

-- ============================================================================
-- Create - Create a new editor instance from virtual template
-- ============================================================================
-- @param parent: Parent frame to attach to
-- @param params: Parameter table (ignored, no params for this type)
-- @param methodIndex: Index of this method in the methods array
-- @returns: editor frame with GetParams/SetParams methods
-- ============================================================================
function EreaRpMasterConsumeEditor.Create(parent, params, methodIndex)
    counter = counter + 1
    local frame = CreateFrame("Frame", "EreaRpMasterConsumeEditor" .. counter, parent, "EreaRpMasterConsumeEditorTemplate")
    frame:SetWidth(parent:GetWidth() - 10)

    -- Set method title
    local title = _G[frame:GetName() .. "Title"]
    title:SetText("|cFFFFD700Method " .. methodIndex .. ":|r Consume Charge")

    function frame:GetParams()
        return {}
    end

    function frame:SetParams(p)
        -- No parameters
    end

    return frame
end
