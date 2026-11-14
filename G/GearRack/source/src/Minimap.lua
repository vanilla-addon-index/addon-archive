if not GearRack.enabled then return end

local buttons={}
local dragging

local function positionButton(button)
    local angle=GearRackDB.settings[button.positionKey]
    if type(angle)~="number" or angle~=angle or math.abs(angle)==math.huge then angle=button.defaultAngle end
    local radius=GearRackDB.settings.SquareMinimap=="ON" and 110 or 80
    local x,y=radius*cos(angle),radius*sin(angle)
    if GearRackDB.settings.SquareMinimap=="ON" then
        x=math.max(-82,math.min(x,84));y=math.max(-86,math.min(y,82))
    end
    button:SetPoint("TOPLEFT",Minimap,"TOPLEFT",52-x,y-52)
end

function GearRack.RefreshMinimapButtons()
    for _,button in ipairs(buttons) do
        positionButton(button)
        if GearRackDB.settings.ShowIcon=="OFF" then button:Hide() else button:Show() end
    end
end

function GearRack.UpdateMinimapDrag()
    if not dragging then return end
    local x,y=GetCursorPosition()
    local scale=Minimap:GetEffectiveScale()
    x=Minimap:GetLeft()-x/scale+Minimap:GetWidth()/2
    y=y/scale-Minimap:GetBottom()-Minimap:GetHeight()/2
    local angle=math.deg(math.atan2(y,x))
    if GearRackDB.settings[dragging.positionKey]==angle then return end
    GearRackDB.settings[dragging.positionKey]=angle
    -- Dragging owns only this icon's position. Visibility and the other icon
    -- change through the ordinary settings refresh, not every rendered frame.
    positionButton(dragging)
end

local function stopDrag()
    if not dragging then return end
    GearRackEngine.StopTimer("IconDragging")
    dragging:UnlockHighlight();dragging=nil
end

function GearRack.CreateMinimapButtons()
    local trinkets=CreateFrame("Button","GearRackTrinketsMinimapButton",Minimap)
    trinkets:SetWidth(33);trinkets:SetHeight(33);trinkets:SetFrameStrata("LOW")
    local icon=trinkets:CreateTexture(nil,"BACKGROUND")
    icon:SetWidth(21);icon:SetHeight(21);icon:SetPoint("TOPLEFT",trinkets,"TOPLEFT",7,-6)
    icon:SetTexture("Interface\\Icons\\INV_Jewelry_TrinketPVP_02")
    icon:SetTexCoord(.075,.925,.075,.925)
    icon:SetVertexColor(1,1,1)
    local border=trinkets:CreateTexture(nil,"OVERLAY")
    border:SetWidth(56);border:SetHeight(56);border:SetPoint("TOPLEFT",trinkets,"TOPLEFT",0,0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    trinkets:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    trinkets.positionKey="TrinketIconPos";trinkets.defaultAngle=-25
    GearRackMinimapButton.positionKey="IconPos";GearRackMinimapButton.defaultAngle=0
    buttons={GearRackMinimapButton,trinkets}
    for _,button in ipairs(buttons) do
        local isTrinkets=button==trinkets
        button:RegisterForClicks("LeftButtonUp","RightButtonUp")
        button:RegisterForDrag("LeftButton");button:EnableMouse(true)
        button:SetScript("OnClick",function()
            if isTrinkets then
                if arg1=="RightButton" then GearRack.ShowMenuPage(GearRackTrinkets_OptFrame,1,true)
                else GearRack.ToggleTrinketPriorities() end
            else GearRackMinimapButton_OnClick(arg1) end
        end)
        button:SetScript("OnEnter",function()
            GearRackUI_OnTooltip(isTrinkets and "GearRack: Trinkets" or "GearRack: Gear sets",
                isTrinkets and "Left-click: trinkets\nRight-click: trinket options\nDrag: move icon" or GearRackUIText.DisableToggleText[GearRackDB.settings.DisableToggle])
        end)
        button:SetScript("OnLeave",function() GameTooltip:Hide() end)
        button:SetScript("OnDragStart",function()
            stopDrag();GameTooltip:Hide();dragging=this;dragging:LockHighlight();GearRackEngine.StartTimer("IconDragging")
        end)
        button:SetScript("OnDragStop",stopDrag)
        button:HookScript("OnHide",function(self) if dragging==self then stopDrag() end end)
    end
    GearRack.RefreshMinimapButtons()
end
