-- Custom WowRadio minimap icon.
-- Loaded after Core.lua so the button keeps all existing behavior.

local function ApplyWowRadioMinimapIcon()
if not WowRadioMinimapButton then
return
end

-- Do not depend on GetRegions()/region order on Vanilla.
-- Draw a dedicated texture directly over the stock icon instead.
if not WowRadioMinimapButton.WowRadioCustomIcon then
local icon = WowRadioMinimapButton:CreateTexture(nil, "ARTWORK")
icon:SetTexture("Interface\\AddOns\\WowRadio-Vanilla\\media\\WowRadio_MinimapIcon.tga")
-- The custom artwork is already tightly cropped for the 20x20 minimap slot.
icon:SetTexCoord(0, 1, 0, 1)
icon:SetWidth(20)
icon:SetHeight(20)
icon:SetPoint("TOPLEFT", WowRadioMinimapButton, "TOPLEFT", 7, -5)
WowRadioMinimapButton.WowRadioCustomIcon = icon
else
WowRadioMinimapButton.WowRadioCustomIcon:SetTexture("Interface\\AddOns\\WowRadio-Vanilla\\media\\WowRadio_MinimapIcon.tga")
WowRadioMinimapButton.WowRadioCustomIcon:SetTexCoord(0, 1, 0, 1)
WowRadioMinimapButton.WowRadioCustomIcon:Show()
end
end

local originalCreateMinimapButton = WowRadio.CreateMinimapButton

function WowRadio:CreateMinimapButton()
originalCreateMinimapButton(self)
ApplyWowRadioMinimapIcon()
end

-- Also handle the case where the button already exists when this file loads.
ApplyWowRadioMinimapIcon()
