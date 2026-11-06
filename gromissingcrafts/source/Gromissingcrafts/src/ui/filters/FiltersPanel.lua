setfenv(1, Gromissingcrafts)

--[[
Search-only now - the profession/character dropdowns were removed. The
window is already scoped to whichever profession frame it's attached to and
always shows the current logged-in character, so nothing is lost: this panel
just holds the recipe-name search box.
]]

---@class FiltersPanel
---@field _frame Frame
---@field _searchField SearchField
---@field _onChange fun()
FiltersPanel = {}

---@shape Filters
---@field searchQuery string

local PANEL_WIDTH = 352
local PANEL_HEIGHT = 24
local SEARCH_FIELD_MARGIN = 8

FiltersPanel.WIDTH = PANEL_WIDTH
FiltersPanel.HEIGHT = PANEL_HEIGHT

---@return self
function FiltersPanel:Create()
    local panel = --[[---@type self]] {}
    setmetatable(panel, {__index = FiltersPanel})

    local frame = CreateFrame("Frame", nil, nil)
    frame:SetWidth(PANEL_WIDTH)
    frame:SetHeight(PANEL_HEIGHT)
    frame:SetFrameStrata("DIALOG")

    local searchField = SearchField:Create(PANEL_WIDTH - (2 * SEARCH_FIELD_MARGIN), function()
        if panel._onChange ~= nil then
            panel._onChange()
        end
    end)

    local searchFieldFrame = searchField:GetFrame()
    searchFieldFrame:SetParent(frame)
    searchFieldFrame:ClearAllPoints()
    searchFieldFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", SEARCH_FIELD_MARGIN, 0)
    searchFieldFrame:SetFrameStrata("DIALOG")

    panel._frame = frame
    panel._searchField = searchField

    return panel
end

---@return Frame
function FiltersPanel:GetFrame()
    return self._frame
end

---@param callback fun(filters: Filters)
function FiltersPanel:OnChange(callback)
    self._onChange = function()
        callback(self:GetFilters())
    end
end

---@return Filters
function FiltersPanel:GetFilters()
    return {
        searchQuery = self._searchField:GetText(),
    }
end

function FiltersPanel:Clear()
    self._searchField:SetText("")
end
