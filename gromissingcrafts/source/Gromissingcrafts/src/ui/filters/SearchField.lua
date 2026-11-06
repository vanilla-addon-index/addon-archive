setfenv(1, Gromissingcrafts)

--[[
Not InputBoxTemplate - same reasoning as Dropdown.lua: pfUI (and similar
skinning addons) appear to hook known Blizzard template names and that broke
click/focus handling for other widgets here. A bare EditBox with a manual
backdrop avoids giving it anything to key off of.
]]

---@class SearchField
---@field _frame EditBox
---@field _text string
SearchField = {}

---@param width number pixel width
---@param onChange fun()
---@return self
function SearchField:Create(width, onChange)
    local object = --[[---@type self]] {}
    setmetatable(object, {__index = SearchField})

    local frame = CreateFrame("EditBox", nil, nil)
    frame:SetWidth(width)
    frame:SetHeight(20)
    frame:SetFrameStrata("DIALOG")
    frame:SetAutoFocus(false)
    frame:SetMaxLetters(250)
    frame:EnableMouse(true)

    frame:SetBackdrop({
        bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
        edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = {left = 3, right = 3, top = 3, bottom = 3},
    })
    frame:SetBackdropColor(0, 0, 0, 0.8)

    frame:SetFontObject(GameFontHighlightSmall)
    frame:SetTextInsets(6, 6, 0, 0)
    frame:SetJustifyH("LEFT")

    frame:SetScript("OnTextChanged", function()
        object._text = frame:GetText()
        onChange()
    end)
    frame:SetScript("OnEscapePressed", function()
        frame:ClearFocus()
    end)
    frame:SetScript("OnEnterPressed", function()
        frame:ClearFocus()
    end)
    frame:SetScript("OnMouseDown", function()
        frame:SetFocus()
    end)

    object._frame = frame
    object._text = ""
    return object
end

---@return Frame
function SearchField:GetFrame()
    return self._frame
end

---@return string
function SearchField:GetText()
    return self._text
end

---@param text string
function SearchField:SetText(text)
    self._frame:SetText(text)
    self._text = text
end
