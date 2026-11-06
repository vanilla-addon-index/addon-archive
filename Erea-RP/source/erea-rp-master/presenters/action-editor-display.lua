-- ============================================================================
-- action-editor-display.lua - Display Cinematic Editor Controller
-- ============================================================================
-- TEMPLATE: views/action-editor-display.xml
-- PURPOSE: Factory for Display Cinematic method editor instances
-- DEPENDENCIES: EreaRpMasterCinematicComponent (action-editor-cinematic.lua)
-- INTERFACE:
--   EreaRpMasterDisplayEditor.Create(parent, params, methodIndex) -> frame
--   frame:GetParams() -> { cinematicId = string }
--   frame:SetParams(params)
--   frame:SaveToLibrary()
--   frame:GetPreviewData() -> table
-- ============================================================================

EreaRpMasterDisplayEditor = {}

local counter = 0

-- ============================================================================
-- HELPERS (module-local)
-- ============================================================================

local function GenerateCinematicGuid()
    local chars = "abcdef0123456789"
    local result = "cin_"
    for i = 1, 8 do
        local idx = math.floor(math.random() * 16) + 1
        result = result .. string.sub(chars, idx, idx)
    end
    result = result .. "_" .. math.floor(GetTime())
    return result
end

-- ============================================================================
-- Create - Create a new Display Cinematic editor instance
-- ============================================================================
function EreaRpMasterDisplayEditor.Create(parent, params, methodIndex)
    counter = counter + 1
    local frame = CreateFrame("Frame", "EreaRpMasterDisplayEditor" .. counter, parent, "EreaRpMasterDisplayEditorTemplate")
    frame:SetWidth(parent:GetWidth() - 10)

    -- Set method title
    local title = _G[frame:GetName() .. "Title"]
    title:SetText("|cFFFFD700Method " .. methodIndex .. ":|r Display Cinematic")

    -- Hidden cinematic ID (auto-generated for new, loaded for existing)
    frame.cinematicId = nil

    -- Embed the shared cinematic component below the method title
    local cinematic, cinematicHeight = EreaRpMasterCinematicComponent.Create(frame, -23)

    -- Adjust frame height: 23px for title row + component height + bottom margin
    frame:SetHeight(23 + cinematicHeight + 5)

    -- Initial column layout based on current frame width, then reflow on resize
    cinematic.Reflow(frame:GetWidth())
    frame:SetScript("OnSizeChanged", function()
        cinematic.Reflow(this:GetWidth()) -- Lua 5.0: this
    end)

    -- ---- Public interface ----

    function frame:GetParams()
        return {
            cinematicId = self.cinematicId or ""
        }
    end

    function frame:SetParams(p)
        if p and p.cinematicId then
            self:LoadCinematic(p.cinematicId)
        end
    end

    function frame:LoadCinematic(cinematicId)
        self.cinematicId = cinematicId
        if not cinematicId or cinematicId == "" then return end

        local entry = EreaRpMasterDB.cinematicLibrary and EreaRpMasterDB.cinematicLibrary[cinematicId]
        if not entry then return end

        cinematic:SetData(entry)
    end

    function frame:SaveToLibrary()
        if not self.cinematicId or self.cinematicId == "" then
            self.cinematicId = GenerateCinematicGuid()
        end

        if not EreaRpMasterDB.cinematicLibrary then
            EreaRpMasterDB.cinematicLibrary = {}
        end

        local data = cinematic:GetData()

        -- Build script references
        local scriptRefs = cinematic.GetScriptReferences()
        local scriptRefsStr = ""
        if table.getn(scriptRefs) > 0 then -- Lua 5.0: table.getn
            scriptRefsStr = table.concat(scriptRefs, ",")
        end

        data.scriptReferences = scriptRefsStr
        EreaRpMasterDB.cinematicLibrary[self.cinematicId] = data
    end

    function frame:GetPreviewData()
        return cinematic:GetData()
    end

    -- Pre-populate if params provided
    if params then
        frame:SetParams(params)
    end

    return frame
end
