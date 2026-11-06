setfenv(1, Gromissingcrafts)

--[[
Fixed pool of row widgets sized to exactly fill the visible area (see the
earlier note in git history / CHANGES about why - a real ScrollFrame wasn't
clipping content reliably on this client). Scrolling changes which slice of
the data those rows display; the scrollbar here is a fully custom, drag/click
capable widget built the same template-free way as Dropdown.lua, and every
piece gets an explicit "DIALOG" strata - strata is NOT inherited from a
parent frame in this client, so anything left unset can lose input priority
to whatever else is on screen at that spot.
]]

---@class CraftsList
---@field _frame Frame
---@field _rows Frame
---@field _track Frame
---@field _thumb Button
---@field _locale GromissingcraftsLocale
---@field _framePool VanillaFramePool
---@field _items CraftsListItem[]
---@field _crafts Craft[]
---@field _scrollOffset number
---@field _visibleRowCount number
CraftsList = {}

local CONTENT_WIDTH = 352
local SCROLLBAR_WIDTH = 24 -- 1.5x the original 16px
local SCROLLBAR_GAP = 4
local ROW_WIDTH = CONTENT_WIDTH - SCROLLBAR_WIDTH - SCROLLBAR_GAP
local ROW_HEIGHT = 16

---@return number
local function getCursorY()
    local _, y = GetCursorPosition()
    return y / UIParent:GetEffectiveScale()
end

---@param locale GromissingcraftsLocale
---@param vanillaFramePool VanillaFramePool
---@return CraftsList
function CraftsList:Create(locale, vanillaFramePool)
    local list = --[[---@type self]] {}
    setmetatable(list, {__index = CraftsList})

    local frame = CreateFrame("Frame", nil, nil)
    frame:SetWidth(CONTENT_WIDTH)
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function()
        list:Scroll(-arg1)
    end)

    local rows = CreateFrame("Frame", nil, frame)
    rows:SetWidth(ROW_WIDTH)
    rows:SetFrameStrata("DIALOG")
    rows:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)

    local upButton = CreateFrame("Button", nil, frame)
    upButton:SetWidth(SCROLLBAR_WIDTH)
    upButton:SetHeight(SCROLLBAR_WIDTH)
    upButton:SetFrameStrata("DIALOG")
    upButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    local upTexture = upButton:CreateTexture()
    upTexture:SetTexture([[Interface\Buttons\UI-ScrollBar-ScrollUpButton-Up]])
    upTexture:SetAllPoints(upButton)
    upButton:SetNormalTexture(upTexture)
    local upHighlight = upButton:CreateTexture()
    upHighlight:SetTexture([[Interface\Buttons\UI-ScrollBar-ScrollUpButton-Highlight]])
    upHighlight:SetAllPoints(upButton)
    upHighlight:SetBlendMode("ADD")
    upButton:SetHighlightTexture(upHighlight)
    upButton:SetScript("OnClick", function() list:Scroll(-1) end)

    local downButton = CreateFrame("Button", nil, frame)
    downButton:SetWidth(SCROLLBAR_WIDTH)
    downButton:SetHeight(SCROLLBAR_WIDTH)
    downButton:SetFrameStrata("DIALOG")
    downButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    local downTexture = downButton:CreateTexture()
    downTexture:SetTexture([[Interface\Buttons\UI-ScrollBar-ScrollDownButton-Up]])
    downTexture:SetAllPoints(downButton)
    downButton:SetNormalTexture(downTexture)
    local downHighlight = downButton:CreateTexture()
    downHighlight:SetTexture([[Interface\Buttons\UI-ScrollBar-ScrollDownButton-Highlight]])
    downHighlight:SetAllPoints(downButton)
    downHighlight:SetBlendMode("ADD")
    downButton:SetHighlightTexture(downHighlight)
    downButton:SetScript("OnClick", function() list:Scroll(1) end)

    local track = CreateFrame("Frame", nil, frame)
    track:SetWidth(SCROLLBAR_WIDTH)
    track:SetFrameStrata("DIALOG")
    track:SetPoint("TOP", upButton, "BOTTOM", 0, 0)
    track:SetPoint("BOTTOM", downButton, "TOP", 0, 0)
    local trackTexture = track:CreateTexture()
    trackTexture:SetTexture([[Interface\Buttons\UI-ScrollBar-Track]])
    trackTexture:SetAllPoints(track)

    local thumb = CreateFrame("Button", nil, track)
    thumb:SetWidth(SCROLLBAR_WIDTH - 2)
    thumb:SetFrameStrata("DIALOG")
    thumb:EnableMouse(true)
    local thumbTexture = thumb:CreateTexture()
    thumbTexture:SetTexture([[Interface\Buttons\UI-ScrollBar-Knob]])
    thumbTexture:SetAllPoints(thumb)
    thumb:SetNormalTexture(thumbTexture)
    thumb:Hide()

    list._frame = frame
    list._rows = rows
    list._track = track
    list._thumb = thumb
    list._locale = locale
    list._framePool = vanillaFramePool
    list._items = {}
    list._crafts = {}
    list._scrollOffset = 0
    list._visibleRowCount = 0

    thumb:SetScript("OnMouseDown", function()
        thumb:SetScript("OnUpdate", function()
            if not IsMouseButtonDown("LeftButton") then
                thumb:SetScript("OnUpdate", nil)
                return
            end
            list:_DragThumbTo(getCursorY())
        end)
    end)
    thumb:SetScript("OnMouseUp", function()
        thumb:SetScript("OnUpdate", nil)
    end)

    return list
end

---@return Frame
function CraftsList:GetFrame()
    return self._frame
end

---@param height number
function CraftsList:SetHeight(height)
    self._frame:SetHeight(height)
    self._rows:SetHeight(height)
    self._visibleRowCount = math.max(1, math.floor(height / ROW_HEIGHT))
    self:_EnsureItemPool()
    self:_Render()
end

function CraftsList:_EnsureItemPool()
    ---@type Frame
    local anchor = self._rows
    for i = 1, self._visibleRowCount do
        if self._items[i] == nil then
            local item = CraftsListItem:Create(ROW_WIDTH, ROW_HEIGHT, self._locale, self._framePool)
            item:GetFrame():SetFrameStrata("DIALOG")
            item:Attach(self._rows, anchor, "TOPLEFT", i == 1 and "TOPLEFT" or "BOTTOMLEFT", 0, 0)
            self._items[i] = item
        end
        anchor = self._items[i]:GetFrame()
    end
    for i = getn(self._items), self._visibleRowCount + 1, -1 do
        local item = tremove(self._items, i)
        item:Destroy()
    end
end

---@param delta number
function CraftsList:Scroll(delta)
    self._scrollOffset = self._scrollOffset + delta
    self:_Render()
end

---@param cursorY number
function CraftsList:_DragThumbTo(cursorY)
    local maxOffset = getn(self._crafts) - self._visibleRowCount
    if maxOffset <= 0 then
        return
    end

    local trackTop = self._track:GetTop()
    local trackHeight = self._track:GetHeight()
    local thumbHeight = self._thumb:GetHeight()
    local travel = trackHeight - thumbHeight
    if travel <= 0 then
        return
    end

    local distanceFromTop = trackTop - cursorY - (thumbHeight / 2)
    local progress = distanceFromTop / travel
    if progress < 0 then
        progress = 0
    elseif progress > 1 then
        progress = 1
    end

    self._scrollOffset = math.floor((progress * maxOffset) + 0.5)
    self:_Render()
end

---@param a Craft
---@param b Craft
---@return boolean
local function compareCrafts(a, b)
    if a.skillLevel ~= b.skillLevel then
        return a.skillLevel < b.skillLevel
    end
    return a.localizedName < b.localizedName
end

---@param crafts Craft[]
function CraftsList:PopulateInterface(crafts)
    table.sort(crafts, compareCrafts)
    self._crafts = crafts
    self._scrollOffset = 0
    self:_Render()
end

function CraftsList:_Render()
    local craftCount = getn(self._crafts)
    local maxOffset = craftCount - self._visibleRowCount
    if maxOffset < 0 then
        maxOffset = 0
    end
    if self._scrollOffset > maxOffset then
        self._scrollOffset = maxOffset
    end
    if self._scrollOffset < 0 then
        self._scrollOffset = 0
    end

    ---@param clickedItem CraftsListItem
    local highlightItem = function(clickedItem)
        for _, otherItem in ipairs(self._items) do
            otherItem:SetHighlight(otherItem == clickedItem)
        end
    end

    for i = 1, self._visibleRowCount do
        local item = self._items[i]
        if item ~= nil then
            local craft = self._crafts[self._scrollOffset + i]
            if craft ~= nil then
                item:SetHighlight(false)
                item:OnClick(highlightItem)
                item:PopulateInterface(craft)
                item:GetFrame():Show()
            else
                item:GetFrame():Hide()
            end
        end
    end

    self:_UpdateThumb(maxOffset, craftCount)
end

---@param maxOffset number
---@param craftCount number
function CraftsList:_UpdateThumb(maxOffset, craftCount)
    if maxOffset <= 0 then
        self._thumb:Hide()
        return
    end

    local trackHeight = self._track:GetHeight()
    local thumbHeight = trackHeight * (self._visibleRowCount / craftCount)
    if thumbHeight < 10 then
        thumbHeight = 10
    end
    if thumbHeight > trackHeight then
        thumbHeight = trackHeight
    end

    local travel = trackHeight - thumbHeight
    local progress = self._scrollOffset / maxOffset

    self._thumb:SetHeight(thumbHeight)
    self._thumb:ClearAllPoints()
    self._thumb:SetPoint("TOP", self._track, "TOP", 0, -(progress * travel))
    self._thumb:Show()
end
