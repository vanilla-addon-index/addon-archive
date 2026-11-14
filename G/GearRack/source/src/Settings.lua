if not GearRack.enabled then return end

local _, ns = ...
local UI = ns.UI

-- The primary gear editor is also the existing /gr and binding entry point.
function GearRack.ToggleSettings()
    if GearRackUI_SetsFrame:IsShown() then
        GearRack.CloseMenus()
    else
        GearRack.OpenGearSets()
    end
end

function GearRack.GetBarProfile()
    return GearRackDB.bars[GearRack.CharacterKey()]
end

function GearRack.OpenGearSets()
    GearRackUI_MenuFrame:Hide()
    GearRack.ShowMenuPage(GearRackUI_SetsFrame,2,true)
end

function GearRack.SetSetButtonVisible(visible)
    local saved=GearRack.GetBarProfile()
    local found=false
    for i=#saved.Bar,1,-1 do
        if saved.Bar[i]==20 then
            if not visible then saved.SetButtonPosition=i end
            if not visible or found then table.remove(saved.Bar,i) else found=true end
        end
    end
    if visible and not found then
        local position=tonumber(saved.SetButtonPosition)
        if not position or position~=position or math.abs(position)==math.huge then position=#saved.Bar+1 end
        position=math.max(1,math.min(#saved.Bar+1,math.floor(position)))
        table.insert(saved.Bar,position,20)
        saved.SetButtonPosition=position
    end
    saved.Inv[20]=visible and 1 or nil
    GearRackUI_RefreshBar()
end

function GearRack.SlashHandler(input)
    input=string.match(input or "","^%s*(.-)%s*$")
    local command=string.lower(input)
    if command=="" or command=="opt" or command=="options" then GearRack.ToggleSettings()
    elseif command=="trinkets" then GearRackTrinkets.SlashHandler("")
    elseif string.find(command,"^trinkets%s+") then GearRackTrinkets.SlashHandler(string.match(input,"^%S+%s+(.*)$"))
    elseif command=="queues" then GearRack.OpenTrinketPriorities()
    elseif command=="sets" then GearRack.OpenGearSets()
    elseif command=="layout" then GearRack.OpenBarLayout()
    elseif command=="keys" then GearRack.CloseMenus();KeyBindingFrame_LoadUI();ShowUIPanel(KeyBindingFrame)
    elseif command=="bar" then GearRackUI_Toggle()
    elseif string.find(command,"^equip%s+") or string.find(command,"^toggle%s+") or command=="lock" or command=="unlock"
        or string.find(command,"^scale%s+") or command=="reset bar" or command=="reset event" or command=="reset events" then GearRackUI_SlashHandler(input)
    else
        DEFAULT_CHAT_FRAME:AddMessage("GearRack: /gr [sets | layout | trinkets | queues | keys | bar | equip <set> | toggle <set> | lock | unlock | scale <n> | reset bar | reset events]")
    end
end

-- A ForgeUI card with a Back pill, title and close glyph; it starts hidden.
function GearRack.CreateSettingsPanel(name,titleText,height)
    local frame=CreateFrame("Frame",name,UIParent)
    frame:SetWidth(360)
    frame:SetHeight(height)
    frame:SetPoint("CENTER",UIParent,"CENTER",0,0)
    frame:SetFrameStrata("DIALOG")
    UI.Surface(frame,14)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart",function() this:StartMoving() end)
    frame:SetScript("OnDragStop",function() this:StopMovingOrSizing() end)
    frame:SetScript("OnHide",function() this:StopMovingOrSizing() end)
    GearRack.SetEscapable(name,true)
    local title=frame:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    title:SetPoint("TOPLEFT",frame,"TOPLEFT",92,-16)
    title:SetText(titleText)
    UI.Color(title,"heading")
    -- The close glyph of UI.Window.
    local close=CreateFrame("Button",name.."Close",frame)
    close:SetWidth(22);close:SetHeight(22)
    close:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-14,-14)
    close:RegisterForClicks("LeftButtonUp")
    UI.Disc(close,"HIGHLIGHT",22,UI.halo):SetAllPoints(close)
    local glyph=close:CreateTexture(nil,"ARTWORK")
    glyph:SetTexture(UI.close)
    glyph:SetWidth(12);glyph:SetHeight(12)
    glyph:SetPoint("CENTER",close,"CENTER",0,0)
    UI.Tint(glyph,UI.hint)
    close:SetScript("OnClick",function() GearRack.CloseMenus() end)
    GearRack.CreateSettingsButton(frame,name.."Back","Back",18,-9,GearRack.BackMenu,64)
    frame:Hide()
    return frame
end

-- A ForgeUI pill. height defaults to 32.
function GearRack.CreateSettingsButton(frame,name,label,x,y,action,width,height)
    -- Actions take domain arguments, not ClassicAPI's (button, mouseButton).
    return UI.Button(name,frame,label,x,y,width or 156,function() action() end,
        {height=height or 32,font="GameFontHighlight"})
end

-- Game Menu > AddOn Options > GearRack (ClassicAPI): one page, one button
-- per window. Each closes the options window and the game menu first.
local function OptionsEntry()
    local entry=CreateFrame("Frame","GearRackOptionsEntry")
    entry.name="GearRack"
    local heading=entry:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    heading:SetPoint("TOPLEFT",entry,"TOPLEFT",16,-16)
    heading:SetText("GearRack")
    local line=entry:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    line:SetPoint("TOPLEFT",heading,"BOTTOMLEFT",0,-8)
    line:SetText("Type /gr to open gear sets at any time.")
    local function Open(name,label,x,open)
        UI.Select(UI.Button(name,entry,label,x,-70,172,function()
            if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then InterfaceOptionsFrame:Hide() end
            if GameMenuFrame and GameMenuFrame:IsShown() then HideUIPanel(GameMenuFrame) end
            open()
        end),true)
    end
    Open("GearRackOptionsSets","Gear sets",16,GearRack.OpenGearSets)
    Open("GearRackOptionsTrinkets","Trinkets",196,function() GearRack.ShowMenuPage(GearRackTrinkets_OptFrame,1,true) end)
    InterfaceOptions_AddCategory(entry)
end

function GearRack.CreateSettings()
    SlashCmdList.GEARRACK=GearRack.SlashHandler
    SLASH_GEARRACK1="/gearrack"
    SLASH_GEARRACK2="/gr"
    GearRack.CreateBarLayout()
    GearRack.CreateNavigation()
    GearRack.CreateMinimapButtons()
    GearRack.CreateSetMacroHandles()
    OptionsEntry()
end
