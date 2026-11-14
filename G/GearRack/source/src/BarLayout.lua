if not GearRack.enabled then return end

local _, ns = ...
local UI = ns.UI

local labels={
    [0]="Ammo",[1]="Head",[2]="Neck",[3]="Shoulders",[4]="Shirt",[5]="Chest",
    [6]="Waist",[7]="Legs",[8]="Feet",[9]="Wrists",[10]="Hands",[11]="Ring 1",
    [12]="Ring 2",[13]="Trinket 1",[14]="Trinket 2",[15]="Back",[16]="Main hand",
    [17]="Off hand",[18]="Ranged",[19]="Tabard",[20]="Gear sets",
}
local rows,page,pageLabel={},1
local perPage=8

function GearRack.MoveBarSlot(slot,direction)
    if direction~=-1 and direction~=1 then return false end
    local saved=GearRack.GetBarProfile()
    for index,value in ipairs(saved.Bar) do
        if value==slot then
            local target=index+direction
            if target<1 or target>#saved.Bar then return false end
            table.remove(saved.Bar,index)
            table.insert(saved.Bar,target,slot)
            for i,id in ipairs(saved.Bar) do
                if id==20 then saved.SetButtonPosition=i;break end
            end
            GearRackUI_RefreshBar()
            return true
        end
    end
    return false
end

function GearRack.RefreshBarLayout()
    local saved=GearRack.GetBarProfile()
    local pages=math.max(1,math.ceil(#saved.Bar/perPage))
    page=math.min(page,pages)
    pageLabel:SetText(page.." / "..pages)
    for i,row in ipairs(rows) do
        local index=(page-1)*perPage+i
        row.slot=saved.Bar[index]
        if row.slot then
            row.label:SetText(index..". "..(labels[row.slot] or tostring(row.slot)))
            local texture
            if row.slot==20 then
                local _,_,setTexture=GearRackUI_GetUserSets()
                texture=setTexture
            else
                texture=GetInventoryItemTexture("player",row.slot)
                if not texture then
                    local info=GearRackUI.Indexes[row.slot]
                    if info then
                        local _,empty=GetInventorySlotInfo(info.slotName)
                        texture=empty
                    end
                end
            end
            row.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
            UI.SetEnabled(row.up,index>1)
            UI.SetEnabled(row.down,index<#saved.Bar)
            row:Show()
        else
            row:Hide()
        end
    end
    UI.SetEnabled(GearRackBarPrevious,page>1)
    UI.SetEnabled(GearRackBarNext,page<pages)
end

function GearRack.OpenBarLayout()
    if not GearRackUI_SetsFrame:IsShown() then GearRack.OpenGearSets() end
    GearRack.ShowMenuPage(GearRackBarLayout)
end

function GearRack.CreateBarLayout()
    local frame=GearRack.CreateSettingsPanel("GearRackBarLayout","Bar layout",492)
    local bar=CreateFrame("CheckButton","GearRackShowEquipment",frame,"UICheckButtonTemplate")
    bar:SetPoint("TOPLEFT",frame,"TOPLEFT",17,-46)
    GearRackShowEquipmentText:SetText("Show equipment bar")
    bar:SetScript("OnClick",function()
        local visible=this:GetChecked() and "ON" or "OFF"
        if GearRack.GetBarProfile().Visible~=visible then GearRackUI_Toggle() end
    end)
    local sets=CreateFrame("CheckButton","GearRackShowSetButton",frame,"UICheckButtonTemplate")
    sets:SetPoint("TOPLEFT",frame,"TOPLEFT",17,-78)
    GearRackShowSetButtonText:SetText("Show gear-set button on the bar")
    sets:SetScript("OnClick",function()
        GearRack.SetSetButtonVisible(this:GetChecked());GearRack.RefreshBarLayout()
    end)
    UI.Color(GearRackShowEquipmentText,"text")
    UI.Color(GearRackShowSetButtonText,"text")
    local help=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    UI.Color(help,"hint")
    help:SetPoint("TOPLEFT",frame,"TOPLEFT",20,-120)
    help:SetWidth(270);help:SetJustifyH("LEFT")
    help:SetText("Move any button up or down in this list.\nThe bar follows this order in its growth direction.")
    pageLabel=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    pageLabel:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-20,-121)
    UI.Color(pageLabel,"hint")
    for i=1,perPage do
        local row=CreateFrame("Frame",nil,frame)
        row:SetWidth(320);row:SetHeight(32)
        row:SetPoint("TOPLEFT",frame,"TOPLEFT",20,-158-(i-1)*34)
        row.icon=row:CreateTexture(nil,"ARTWORK")
        row.icon:SetWidth(26);row.icon:SetHeight(26)
        row.icon:SetPoint("LEFT",row,"LEFT",0,0)
        row.label=row:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        row.label:SetPoint("LEFT",row,"LEFT",34,0);row.label:SetWidth(180);row.label:SetJustifyH("LEFT")
        UI.Color(row.label,"text")
        local function move(direction)
            GearRack.MoveBarSlot(row.slot,direction)
            GearRack.RefreshBarLayout()
        end
        row.up=GearRack.CreateSettingsButton(row,"GearRackBarRow"..i.."Up","Up",220,0,function() move(-1) end,44)
        row.down=GearRack.CreateSettingsButton(row,"GearRackBarRow"..i.."Down","Down",270,0,function() move(1) end,50)
        rows[i]=row
    end
    GearRack.CreateSettingsButton(frame,"GearRackBarPrevious","Previous",20,-442,function()
        page=math.max(1,page-1);GearRack.RefreshBarLayout()
    end,80)
    GearRack.CreateSettingsButton(frame,"GearRackBarNext","Next",108,-442,function()
        page=page+1;GearRack.RefreshBarLayout()
    end,80)
    GearRack.CreateSettingsButton(frame,"GearRackMoreEquipment","Equipment options",196,-442,GearRack.OpenEquipmentSettings,144)
    frame:SetScript("OnShow",function()
        local saved=GearRack.GetBarProfile()
        bar:SetChecked(saved.Visible~="OFF");sets:SetChecked(saved.Inv[20] and true or false)
        GearRack.RefreshBarLayout()
    end)
end
