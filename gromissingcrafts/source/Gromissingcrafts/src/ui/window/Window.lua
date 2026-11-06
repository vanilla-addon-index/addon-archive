setfenv(1, Gromissingcrafts)

---@class Window
---@field _frame Frame
---@field _titleText FontString
---@field _professionFrame ProfessionFrame
---@field _closeButton Button
---@field _placementPolicy PlacementPolicy
---@field _onClose function
Window = {}

local BACKDROP = {
    bgFile = [[Interface\DialogFrame\UI-DialogBox-Background]],
    edgeFile = [[Interface\DialogFrame\UI-DialogBox-Border]],
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = {left = 11, right = 12, top = 12, bottom = 11},
}

local TITLE_BAR_HEIGHT = 24
local CONTENT_MARGIN = 16

---@param addonInfo AddonInfo
---@param onClose fun():void
---@param filtersPanel FiltersPanel
---@param craftsList CraftsList
---@param professionFrame ProfessionFrame
---@param placementPolicy PlacementPolicy
---@return self
function Window:Create(addonInfo, onClose, filtersPanel, craftsList, professionFrame, placementPolicy)
    local window = --[[---@type self]] {}
    setmetatable(window, {__index = Window})

    local frameStatus = placementPolicy:GetMainWindowGeometry(professionFrame.type)

    local frame = CreateFrame("Frame", "GromissingcraftsWindow", UIParent)
    frame:SetBackdrop(BACKDROP)
    frame:SetBackdropColor(1, 1, 1, 1)
    -- Fixed high strata (not "whatever the profession frame uses") so this
    -- window and its widgets reliably win input priority over anything the
    -- profession frame or other addons draw underneath it.
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetWidth(frameStatus.width)
    frame:SetHeight(frameStatus.height)

    -- Anchored directly to the profession frame (not to a computed UIParent
    -- offset) so it moves together with it automatically - no drag support
    -- of its own, it's not meant to be repositioned independently.
    frame:SetPoint("TOPLEFT", professionFrame.widget, "TOPRIGHT", frameStatus.offsetX, frameStatus.offsetY)

    local titleText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    titleText:SetPoint("TOP", frame, "TOP", 0, -14)
    titleText:SetText(format('%s v%s', addonInfo.name, addonInfo.version))

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetFrameStrata("DIALOG")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function()
        window:Hide()
    end)

    local filtersPanelFrame = filtersPanel:GetFrame()
    filtersPanelFrame:SetParent(frame)
    filtersPanelFrame:ClearAllPoints()
    filtersPanelFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", CONTENT_MARGIN, -(TITLE_BAR_HEIGHT + 8))

    local craftsListFrame = craftsList:GetFrame()
    craftsListFrame:SetParent(frame)
    craftsListFrame:ClearAllPoints()
    craftsListFrame:SetPoint("TOPLEFT", filtersPanelFrame, "BOTTOMLEFT", 0, -5)

    window._frame = frame
    window._titleText = titleText
    window._professionFrame = professionFrame
    window._closeButton = closeButton
    window._placementPolicy = placementPolicy
    window._craftsList = craftsList
    window._onClose = onClose

    window:UpdateGeometry()

    return window
end

function Window:UpdateGeometry()
    local frameStatus = self._placementPolicy:GetMainWindowGeometry(self._professionFrame.type)
    self._frame:SetWidth(frameStatus.width)
    self._frame:SetHeight(frameStatus.height)
    self._frame:ClearAllPoints()
    self._frame:SetPoint("TOPLEFT", self._professionFrame.widget, "TOPRIGHT", frameStatus.offsetX, frameStatus.offsetY)
    self._frame:Show()

    -- Recomputed on every geometry change, not just at creation: different
    -- profession frame types (and pfUI vs not) report different heights.
    self._craftsList:SetHeight(frameStatus.height - (TITLE_BAR_HEIGHT + 8) - FiltersPanel.HEIGHT - CONTENT_MARGIN)
end

---@param professionFrame ProfessionFrame
function Window:Show(professionFrame)
    self._professionFrame = professionFrame
    self._frame:Show()
    self:UpdateGeometry()
end

function Window:Hide()
    self._frame:Hide()
    self._onClose()
end
