if not GearRack.enabled then return end

local _, ns = ...
local UI = ns.UI

-- Primary editors are siblings. Only Bar layout has a return page.
-- Keep the game's Escape handler and defer returns until its hide pass ends.
local pages,history={},{}
local active,changing,returnTimer
local revision=0

local function cancelReturn()
    revision=revision+1
    if returnTimer then returnTimer:Cancel();returnTimer=nil end
end

local function snapshot(frame)
    local tab
    if frame==GearRackUI_SetsFrame then tab=GearRackUI.SelectedTab or 2
    elseif frame==GearRackTrinkets_OptFrame then tab=GearRackTrinkets.SelectedTab or 3 end
    return {frame=frame,tab=tab}
end

local function display(page)
    changing=true
    for _,frame in ipairs(pages) do if frame~=page.frame then frame:Hide() end end
    active=page.frame
    active:Show()
    if page.tab then
        if active==GearRackUI_SetsFrame then GearRackUI_Tab(page.tab)
        elseif active==GearRackTrinkets_OptFrame then GearRackTrinkets.Tab_OnClick(page.tab) end
    end
    changing=nil
end

function GearRack.ShowMenuPage(frame,tab,restart)
    cancelReturn()
    if restart or not active then history={} end
    local previous=active and snapshot(active)
    if previous and previous.frame==frame and (not tab or previous.tab==tab) and frame:IsShown() then return end
    if previous and not restart then
        table.insert(history,previous)
    end
    display({frame=frame,tab=tab})
end

function GearRack.CloseMenus()
    cancelReturn();history={};active=nil
    changing=true
    for _,frame in ipairs(pages) do frame:Hide() end
    changing=nil
end

function GearRack.BackMenu()
    cancelReturn()
    local previous=table.remove(history)
    if previous then display(previous) else GearRack.CloseMenus() end
end

local function pageHidden(frame)
    if changing or active~=frame or frame:IsShown() then return end
    active=nil
    local previous=table.remove(history)
    if not previous then return end
    cancelReturn()
    local token=revision
    -- Native CloseWindows hides every visible UISpecialFrame in one pass.
    -- Show the previous page after that pass, regardless of registry order.
    returnTimer=C_Timer.NewTimer(0,function()
        if token~=revision then return end
        returnTimer=nil
        if UIParent:IsShown() and not UnitIsDeadOrGhost("player") then display(previous) end
    end)
end

function GearRack.OpenTrinketPriorities(slot)
    local which=slot and slot-13 or GearRackTrinkets.CurrentlySorting or 0
    GearRackUI_MenuFrame:Hide()
    GearRackTrinkets_MenuFrame:Hide()
    GearRackTrinkets.ClearTooltip()
    GearRack.ShowMenuPage(GearRackTrinkets_OptFrame,which==1 and 2 or 3,true)
end

function GearRack.OpenEquipmentSettings()
    GearRack.ShowMenuPage(GearRackUI_SetsFrame,1,true)
end

function GearRack.ToggleTrinketPriorities()
    if GearRackTrinkets_OptFrame:IsShown() then GearRack.CloseMenus()
    else GearRack.OpenTrinketPriorities() end
end

function GearRack.CreateNavigation()
    pages={GearRackBarLayout,GearRackUI_SetsFrame,GearRackTrinkets_OptFrame}
    for _,frame in ipairs(pages) do
        GearRack.SetEscapable(frame:GetName(),true)
        frame:HookScript("OnShow",function(self)
            if not changing and active~=self then GearRack.ShowMenuPage(self,nil,true) end
        end)
        frame:HookScript("OnHide",pageHidden)
    end
    -- Reserve a footer without moving the original editor contents.
    GearRackUI_SetsFrame:SetHeight(368)
    GearRackUI_Sets_Inv16:SetPoint("BOTTOM",GearRackUI_SetsFrame,"BOTTOM",-57,42)
    GearRack.CreateSettingsButton(GearRackUI_SetsFrame,"GearRackSetsLayout","Bar layout",8,-336,GearRack.OpenBarLayout,100,24)
    GearRack.CreateSettingsButton(GearRackUI_SetsFrame,"GearRackSetsTrinkets","Trinkets",116,-336,GearRack.OpenTrinketPriorities,156,24)
    GearRackTrinkets_OptFrame:SetHeight(360)
    GearRackTrinkets_SubOptFrame:SetPoint("BOTTOMRIGHT",GearRackTrinkets_OptFrame,"BOTTOMRIGHT",-8,42)
    GearRackTrinkets_SubQueueFrame:SetPoint("BOTTOMRIGHT",GearRackTrinkets_OptFrame,"BOTTOMRIGHT",-8,42)
    GearRack.CreateSettingsButton(GearRackTrinkets_OptFrame,"GearRackPrioritiesSets","Gear sets",8,-328,GearRack.OpenGearSets,284,24)
    local options=GearRackTrinkets_SubOptFrame
    local show=CreateFrame("CheckButton","GearRackShowTrinkets",options,"UICheckButtonTemplate")
    show:SetPoint("TOPLEFT",GearRackTrinkets_OptShowHotKeys,"BOTTOMLEFT",-4,0)
    GearRackShowTrinketsText:SetText("Show trinket bar")
    show:SetScript("OnClick",function()
        local visible=this:GetChecked() and true or false
        GearRackCharDB.trinkets.Visible=visible and "ON" or "OFF"
        if visible then GearRackTrinkets_MainFrame:Show() else GearRackTrinkets_MainFrame:Hide() end
    end)
    local hold=CreateFrame("CheckButton","GearRackHoldTrinkets",options,"UICheckButtonTemplate")
    hold:SetPoint("TOPLEFT",show,"BOTTOMLEFT",0,0)
    GearRackHoldTrinketsText:SetText("Keep manual choices")
    hold:SetScript("OnClick",function()
        GearRackCharDB.KeepManualTrinkets=this:GetChecked() and true or false
        if not GearRackCharDB.KeepManualTrinkets then table.wipe(GearRackCharDB.HeldQueues) end
        GearRackTrinkets.ReflectQueueEnabled()
    end)
    hold:SetScript("OnEnter",function()
        GameTooltip:SetOwner(this,"ANCHOR_RIGHT")
        GameTooltip:AddLine("Keep manual trinket choices",UI.heading[1],UI.heading[2],UI.heading[3])
        GameTooltip:AddLine("A trinket you or a gear set puts on pauses that slot's queue until you resume it.",1,1,1,true)
        GameTooltip:Show()
    end)
    hold:SetScript("OnLeave",function() GameTooltip:Hide() end)
    UI.Color(GearRackShowTrinketsText,"text")
    UI.Color(GearRackHoldTrinketsText,"text")
    options:HookScript("OnShow",function()
        show:SetChecked(GearRackCharDB.trinkets.Visible=="ON")
        hold:SetChecked(GearRackCharDB.KeepManualTrinkets)
    end)
end
