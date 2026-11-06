-- HasteDisplay: Draggable haste percentage display with consumable indicators
HasteDisplay = {}

-- Create the main frame
local frame = CreateFrame("Frame", "HasteDisplayFrame", UIParent)
frame:SetWidth(125)
frame:SetHeight(50)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:SetMovable(true)
frame:SetUserPlaced(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetClampedToScreen(true)


local bg = frame:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints(frame)
bg:SetTexture(0, 0, 0, 0.5)

local jujuText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
jujuText:SetPoint("TOP", frame, "TOP", 0, -2)
jujuText:SetText("Juju Flurry")
frame.jujuText = jujuText


local potionText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
potionText:SetPoint("TOP", jujuText, "BOTTOM", 0, 0)
potionText:SetText("Potion of Quickness")
frame.potionText = potionText


local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
text:SetPoint("TOP", potionText, "BOTTOM", 0, -2)
text:SetTextColor(1, 1, 1, 1)
text:SetText("0.00%")
frame.hasteText = text

-- Drag functionality
frame:SetScript("OnDragStart", function()
    this:StartMoving()
end)

frame:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    -- Save position
    if not HasteDisplayDB then
        HasteDisplayDB = {}
    end
    local point, _, relativePoint, xOfs, yOfs = this:GetPoint()
    HasteDisplayDB.point = point
    HasteDisplayDB.relativePoint = relativePoint
    HasteDisplayDB.x = xOfs
    HasteDisplayDB.y = yOfs
end)

local function GetColorForHaste(projectedHaste)
    if projectedHaste < 58 then
        return 0, 1, 0, 1 -- Green
    elseif projectedHaste < 100 then
        return 1, 1, 0, 1 -- Yellow
    else
        return 1, 0, 0, 1 -- Red
    end
end

local function UpdateHaste()
    local haste = GetUnitField("player", "modCastSpeed")
    if haste and haste > 0 then
        haste = (1/haste - 1) * 100
        frame.hasteText:SetText(string.format("%.2f%%", haste))
        
        -- Calculate projected haste with Juju Flurry (3% mult)
        local jujuHaste = haste * 1.03
        local jr, jg, jb, ja = GetColorForHaste(jujuHaste)
        frame.jujuText:SetTextColor(jr, jg, jb, ja)
        
        -- Calculate projected haste with Potion of Quickness (5% mult)
        local potionHaste = haste * 1.05
        local pr, pg, pb, pa = GetColorForHaste(potionHaste)
        frame.potionText:SetTextColor(pr, pg, pb, pa)
    else
        frame.hasteText:SetText("0.00%")
        -- Default to green when no haste
        frame.jujuText:SetTextColor(0, 1, 0, 1)
        frame.potionText:SetTextColor(0, 1, 0, 1)
    end
end

frame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "HasteDisplay" then
        -- Load saved position
        if HasteDisplayDB and HasteDisplayDB.point then
            frame:ClearAllPoints()
            frame:SetPoint(
                HasteDisplayDB.point,
                UIParent,
                HasteDisplayDB.relativePoint,
                HasteDisplayDB.x,
                HasteDisplayDB.y
            )
        end
        UpdateHaste()
    elseif event == "PLAYER_ENTERING_WORLD" or 
           event == "UNIT_INVENTORY_CHANGED" or 
           event == "PLAYER_AURAS_CHANGED" then
        UpdateHaste()
    end
end)

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
frame:RegisterEvent("PLAYER_AURAS_CHANGED")

SLASH_HASTEDISPLAY1 = "/hastedisplay"
SLASH_HASTEDISPLAY2 = "/haste"
SlashCmdList["HASTEDISPLAY"] = function(msg)
    if frame:IsShown() then
        frame:Hide()
        DEFAULT_CHAT_FRAME:AddMessage("HasteDisplay hidden. Use /haste to show again.")
    else
        frame:Show()
        UpdateHaste()
        DEFAULT_CHAT_FRAME:AddMessage("HasteDisplay shown.")
    end
end


HasteDisplay.frame = frame
