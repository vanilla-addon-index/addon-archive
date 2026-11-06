setfenv(1, Gromissingcrafts)

---@shape ProfessionFrame
---@field id string
---@field type LcpProfessionFrameType
---@field profession string
---@field widget Frame

---@shape WindowState
---@field widget Window
---@field opened boolean
---@field frameId string|nil

---@class UIManager
---@field _addonInfo AddonInfo
---@field _repos Repositories
---@field _locale GromissingcraftsLocale
---@field _placementPolicy PlacementPolicy
---@field _vanillaFramePool VanillaFramePool
---@field _buttonsByFrameId table<string, OpenButton>
---@field _windowState WindowState
---@field _filtersPanel FiltersPanel
---@field _craftsList CraftsList
---@field _dataStateManager DataStateManager
UIManager = {}

---@param addonInfo AddonInfo
---@param repositories Repositories
---@param locale GromissingcraftsLocale
---@param LibItemTooltip LibItemTooltip
---@return self
function UIManager:Create(addonInfo, repositories, locale, LibItemTooltip)
    self._addonInfo = addonInfo
    self._repos = repositories
    self._locale = locale
    self._placementPolicy = PlacementPolicy
    self._vanillaFramePool = VanillaFramePool:Create()
    self._tooltipEnhancer = TooltipEnhancer:Create(self._repos.craftRepository, self._repos.characterRepository, locale, LibItemTooltip)
    self._buttonsByFrameId = {}

    ---@param crafts Craft[]
    local function updateCrafts(crafts)
        if self._craftsList ~= nil then
            self._craftsList:PopulateInterface(crafts)
        end
    end

    self._dataStateManager = DataStateManager:Create(self._repos.craftRepository, updateCrafts)

    hookGlobalFunction("MovePanelToLeft", function() self:UpdateGeometry() end)
    hookGlobalFunction("MovePanelToCenter", function() self:UpdateGeometry() end)

    return self
end

---@param profession string
function UIManager:OnDataUpdated(profession)
    self._dataStateManager:OnCraftsUpdated(profession)
end

---@param profession string
---@param frame Frame
---@param frameType LcpProfessionFrameType
function UIManager:OnProfessionFrameOpened(profession, frame, frameType)
    ---@type ProfessionFrame
    local professionFrame = {
        id = getFrameId(frame),
        type = frameType,
        profession = profession,
        widget = frame,
    }

    if self:IsWindowAttachedTo(professionFrame.id) then
        self._dataStateManager:OnProfessionSwitchedInFrame(profession)
    else
        self:DestroyButton(professionFrame.id)
        self:CreateButton(professionFrame)
    end

    self:UpdateGeometry()
end

---@param frame Frame
---@param frameType LcpProfessionFrameType
function UIManager:OnProfessionFrameClosed(frame, frameType)
    local frameId = getFrameId(frame)
    self:DestroyButton(frameId)
    if self:IsWindowAttachedTo(frameId) then
        self:CloseWindow()
    else
        self:UpdateGeometry()
    end
end

---@param frame ProfessionFrame
function UIManager:OnWindowOpened(frame)
    self._windowState.opened = true
    self._windowState.frameId = frame.id
    if self._filtersPanel ~= nil then
        self._filtersPanel:Clear()
    end
    self._dataStateManager:OnWindowOpened(frame.profession)
    self:CheckButtons()
end

function UIManager:OnWindowClosed()
    self._windowState.opened = false
    self._windowState.frameId = nil
    self._dataStateManager:OnWindowClosed()
    self:CheckButtons()
end

---@param frame ProfessionFrame
function UIManager:OnButtonClicked(frame)
    if self:IsWindowAttachedTo(frame.id) then
        self:CloseWindow()
    else
        self:OpenWindow(frame)
    end
end

---@param professionFrame ProfessionFrame
function UIManager:CreateButton(professionFrame)
    local FrameType = LibCraftingProfessionsConstants.FrameType

    ---@type 0|1
    local delayInFrames = 0
    if professionFrame.type == FrameType.AdvancedTradeSkillWindow2 or professionFrame.type == FrameType.Artisan then
        delayInFrames = 1 -- Work around async window initialization behavior
    end

    local onClick = function()
        self:OnButtonClicked(professionFrame)
    end

    callDelayed(delayInFrames, function()
        self._buttonsByFrameId[professionFrame.id] = OpenButton:Create(onClick, professionFrame, self._placementPolicy)
    end)
end

---@param frameId string
function UIManager:DestroyButton(frameId)
    local button = tpop(self._buttonsByFrameId, frameId)
    if button ~= nil then
        (--[[---@not nil]] button):Destroy()
    end
end

function UIManager:CheckButtons()
    local activeId
    if self._windowState ~= nil and self._windowState.opened then
        activeId = self._windowState.frameId
    end
    for frameId, button in pairs(self._buttonsByFrameId) do
        button:SetChecked(frameId == activeId)
    end
end

---@param frame ProfessionFrame
function UIManager:OpenWindow(frame)
    if self:IsWindowAttachedTo(frame.id) then
        return
    end

    if self._windowState == nil then
        local onClose = function()
            self:OnWindowClosed()
        end

        local filtersPanel = FiltersPanel:Create()
        local craftsList = CraftsList:Create(self._locale, self._vanillaFramePool)
        local window = Window:Create(self._addonInfo, onClose, filtersPanel, craftsList, frame, self._placementPolicy)

        filtersPanel:OnChange(function(filters)
            self._dataStateManager:OnFiltersChanged(filters)
        end)

        self._windowState = {
            widget = window,
            frameId = frame.id,
            opened = true
        }
        self._filtersPanel = filtersPanel
        self._craftsList = craftsList
    end

    self._windowState.widget:Show(frame)
    self:OnWindowOpened(frame)
end

function UIManager:CloseWindow()
    self._windowState.widget:Hide()
    self:OnWindowClosed()
end

---@param frameId string
---@return boolean
function UIManager:IsWindowAttachedTo(frameId)
    return self._windowState ~= nil and self._windowState.opened and self._windowState.frameId == frameId
end

function UIManager:UpdateGeometry()
    if self._windowState ~= nil and self._windowState.opened then
        self._windowState.widget:UpdateGeometry()
    end
end
