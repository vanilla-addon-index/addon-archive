setfenv(1, Gromissingcrafts)

---@class DataStateManager
---@field _craftRepository CraftRepository
---@field _updateCrafts fun(crafts: Craft[]): void
---@field _selectedCharacter string|nil
---@field _selectedProfession string|nil
---@field _searchQuery string
DataStateManager = {}

---@param craftRepository CraftRepository
---@param updateCrafts fun(crafts: Craft[]): void
function DataStateManager:Create(craftRepository, updateCrafts)
    self._craftRepository = craftRepository
    self._updateCrafts = updateCrafts
    return self
end

---@param profession string
function DataStateManager:OnWindowOpened(profession)
    local player, _ = UnitName("player")
    self._selectedCharacter = player
    self._selectedProfession = profession
    self._searchQuery = ""
    self:UpdateCrafts()
end

function DataStateManager:OnWindowClosed()
    self._selectedCharacter = nil
    self._selectedProfession = nil
    self._searchQuery = ""
end

---@param newProfession string
function DataStateManager:OnProfessionSwitchedInFrame(newProfession)
    self._selectedProfession = newProfession
    self:UpdateCrafts()
end

---@param profession string
function DataStateManager:OnCraftsUpdated(profession)
    if profession == self._selectedProfession then
        self:UpdateCrafts()
    end
end

---@param filters Filters
function DataStateManager:OnFiltersChanged(filters)
    self._searchQuery = filters.searchQuery
    self:UpdateCrafts()
end

function DataStateManager:UpdateCrafts()
    if self._selectedCharacter == nil or self._selectedProfession == nil then
        return
    end
    self._updateCrafts(self._craftRepository:FindMissing(self._selectedCharacter, self._selectedProfession, self._searchQuery or ""))
end
