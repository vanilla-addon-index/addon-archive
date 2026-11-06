setfenv(1, Gromissingcrafts)

---@shape Coords
---@field x number
---@field y number

---@shape Anchor
---@field framePoint WidgetAnchorPoint
---@field selfPoint WidgetAnchorPoint
---@field selfCoords Coords

---@shape Geometry
---@field width number
---@field height number
---@field offsetX number
---@field offsetY number

---@class PlacementPolicy
PlacementPolicy = {}

local FrameType = LibCraftingProfessionsConstants.FrameType

---@return boolean
local function pfUI()
    return IsAddOnLoaded("pfUI") == 1
end

---@param frameType LcpProfessionFrameType
---@return boolean
local function frameTypeSupportedByPfUI(frameType)
    return frameType == FrameType.VanillaCraftFrame or
           frameType == FrameType.VanillaTradeSkillFrame or
           frameType == FrameType.TurtleTradeSkillFrame
end

---@return boolean
local function MTSL()
    return getglobal("MTSLUI_TOGGLE_BUTTON") ~= nil
end

---@param frameType LcpProfessionFrameType
---@return Anchor
function PlacementPolicy:GetOpenButtonAnchor(frameType)
    ---@type Anchor
    local anchor = {
        framePoint = "TOPRIGHT",
        selfPoint = "TOPRIGHT",
        selfCoords = {x = 0, y = 0},
    }

    if pfUI() and frameTypeSupportedByPfUI(frameType) then
        if MTSL() then
            anchor.selfCoords = {x = -15, y = -70}
        else
            anchor.selfCoords = {x = -30, y = -1}
        end
    elseif frameType == FrameType.AdvancedTradeSkillWindow then
        anchor.selfCoords = {x = -54, y = -91}
    elseif frameType == FrameType.AdvancedTradeSkillWindow2 then
        anchor.selfCoords = {x = -48, y = -77}
    elseif frameType == FrameType.Artisan then
        anchor.selfCoords = {x = -44, y = -60}
    elseif frameType == FrameType.TurtleTradeSkillFrame then
        anchor.selfCoords = {x = -96, y = -61}
    elseif frameType == FrameType.VanillaTradeSkillFrame then
        if MTSL() then
            anchor.selfCoords = {x = -93, y = 20}
        else
            anchor.selfCoords = {x = -38, y = 20}
        end
    elseif frameType == FrameType.VanillaCraftFrame then
        anchor.selfCoords = {x = -44, y = -60}
    end

    return anchor
end

--[[
offsetX/offsetY are relative to the profession frame's TOPRIGHT corner, meant
to be used directly as a SetPoint offset anchored to that frame (not to
UIParent). That makes the window a true child-of-position: WoW keeps it in
sync automatically whenever the profession frame moves, with no polling or
move hooks required.
]]
---@param frameType LcpProfessionFrameType
---@return Geometry
function PlacementPolicy:GetMainWindowGeometry(frameType)
    ---@type Geometry
    local status

    if pfUI() and frameTypeSupportedByPfUI(frameType) then
        status = {width = 384, height = 450, offsetX = 0, offsetY = 5}
    elseif frameType == FrameType.AdvancedTradeSkillWindow then
        status = {width = 384, height = 430, offsetX = -40, offsetY = -10}
    elseif frameType == FrameType.AdvancedTradeSkillWindow2 then
        status = {width = 384, height = 494, offsetX = -5, offsetY = -10}
    elseif frameType == FrameType.Artisan then
        status = {width = 384, height = 469, offsetX = -5, offsetY = -10}
    elseif frameType == FrameType.TurtleTradeSkillFrame then
        status = {width = 384, height = 430, offsetX = -87, offsetY = -10}
    else
        status = {width = 384, height = 430, offsetX = -40, offsetY = -10}
    end

    return status
end
