-- See (https://www.wowinterface.com/forums/showthread.php?t=5889) for BBar commands

GryllsBongos_Settings = {
    bar1 = "none",
    bar2 = "none",
    bar3 = "none",
    bar4 = "none",
    bar5 = "none",
    bar6 = "none",
    bar7 = "none",
    bar8 = "none",
    bar9 = "none",
    bar10 = "none",
    bags = "none",
    class = "none",
    key = "none",
    menu = "none",
    xp = "none",
	pet = "none",
}

local function setVar(i, action)
    if i == 1 then
        if action ~= nil then
            GryllsBongos_Settings.bar1 = action
        else
            return GryllsBongos_Settings.bar1
        end
    elseif i == 2 then
        if action ~= nil then
            GryllsBongos_Settings.bar2 = action
        else
            return GryllsBongos_Settings.bar2
        end
    elseif i == 3 then
        if action ~= nil then
            GryllsBongos_Settings.bar3 = action
        else
            return GryllsBongos_Settings.bar3
        end
    elseif i == 4 then
        if action ~= nil then
            GryllsBongos_Settings.bar4 = action
        else
            return GryllsBongos_Settings.bar4
        end
    elseif i == 5 then
        if action ~= nil then
            GryllsBongos_Settings.bar5 = action
        else
            return GryllsBongos_Settings.bar5
        end
    elseif i == 6 then
        if action ~= nil then
            GryllsBongos_Settings.bar6 = action
        else
            return GryllsBongos_Settings.bar6
        end
    elseif i == 7 then
        if action ~= nil then
            GryllsBongos_Settings.bar7 = action
        else
            return GryllsBongos_Settings.bar7
        end
    elseif i == 8 then
        if action ~= nil then
            GryllsBongos_Settings.bar8 = action
        else
            return GryllsBongos_Settings.bar8
        end
    elseif i == 9 then
        if action ~= nil then
            GryllsBongos_Settings.bar9 = action
        else
            return GryllsBongos_Settings.bar9
        end
    elseif i == 10 then
        if action ~= nil then
            GryllsBongos_Settings.bar10 = action
        else
            return GryllsBongos_Settings.bar10
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF9900Grylls|rBongos: could not find setting for i = "..i)
    end
end

local function bongosToggle(barnum)
    local bar = BBar.IDToBar(barnum)
    BBar.Toggle(bar, false)
end

local function bongosHide(barnum)
    local bar = BBar.IDToBar(barnum)
    BBar.Hide(bar, false)
end

local function bongosShow(barnum)
    local bar = BBar.IDToBar(barnum)
    BBar.Show(bar, false)
end

local function bongosSetAlpha(barnum, alpha)
    local bar = BBar.IDToBar(barnum)
    BBar.SetAlpha(bar, alpha, false)
end

local function BarToggle()
    for i = 1, 10 do
        if setVar(i) == "toggle" then
            bongosToggle(i)
        end
    end

    if GryllsBongos_Settings.bags == "toggle" then
        BBar.Toggle(BBagBar, false)
    end

    if GryllsBongos_Settings.class == "toggle" then
        BBar.Toggle(BClassBar, false)
    end

    if GryllsBongos_Settings.key == "toggle" then
        BBar.Toggle(BKeyBar, false)
    end

    if GryllsBongos_Settings.menu == "toggle" then
        BBar.Toggle(BMenuBar, false)
    end

    if GryllsBongos_Settings.xp == "toggle" then
        BBar.Toggle(BXPBar, false)
    end
	
	if GryllsBongos_Settings.pet == "toggle" then
        BBar.Toggle(BPetBar, false)
    end

end

local function BarHide()
    for i = 1, 10 do
        if setVar(i) == "hide" then
            bongosHide(i)
        end
    end

    if GryllsBongos_Settings.bags == "hide" then
        BBar.Hide(BBagBar, false)
    end

    if GryllsBongos_Settings.class == "hide" then
        BBar.Hide(BClassBar, false)
    end

    if GryllsBongos_Settings.key == "hide" then
        BBar.Hide(BKeyBar, false)
    end

    if GryllsBongos_Settings.menu == "hide" then
        BBar.Hide(BMenuBar, false)
    end

    if GryllsBongos_Settings.xp == "hide" then
        BBar.Hide(BXPBar, false)
    end
	
    if GryllsBongos_Settings.pet == "hide" then
        BBar.Hide(BPetBar, false)
    end
end

local function BarShow()
    for i = 1, 10 do
        if setVar(i) == "show" then
            bongosShow(i)
        end
    end

    if GryllsBongos_Settings.bags == "show" then
        BBar.Show(BBagBar, false)
    end

    if GryllsBongos_Settings.class == "show" then
        BBar.Show(BClassBar, false)
    end

    if GryllsBongos_Settings.key == "show" then
        BBar.Show(BKeyBar, false)
    end

    if GryllsBongos_Settings.menu == "show" then
        BBar.Show(BMenuBar, false)
    end

    if GryllsBongos_Settings.xp == "show" then
        BBar.Show(BXPBar, false)
    end
	
    if GryllsBongos_Settings.pet == "show" then
        BBar.Show(BPetBar, false)
    end
end

local function BarMouseoverSetScript(bar, barnum)

    local thebar = bar
    if thebar == "bar" then
        thebar = BBar.IDToBar(barnum)
    end

    local f = CreateFrame("Frame", nil, UIParent)
    f:SetAllPoints(thebar)
    f:SetFrameStrata("LOW")
    f:EnableMouse(true)
    f.fadetime = 0
    f.fader = CreateFrame("Frame", nil, UIParent)

    if thebar == "bar" then
        f:SetScript("OnEnter", function()
            bongosShow(thebar)
        end)
    else
        f:SetScript("OnEnter", function()
            BBar.Show(thebar, false)
        end)
    end

    if thebar == "bar" then
        f:SetScript("OnLeave", function()
            f.fadetime = GetTime() + 2 -- adjust to your desired fade timr in seconds (minimum 1)
            f.fader:SetScript("OnUpdate", function()
                if GetTime() >= f.fadetime then
                    bongosHide(thebar)
                    f.fader:SetScript("OnUpdate", nil)
                end
            end)
        end)
        bongosHide(bar)
    else
        f:SetScript("OnLeave", function()
            f.fadetime = GetTime() + 2 -- adjust to your desired fade timr in seconds (minimum 1)
            f.fader:SetScript("OnUpdate", function()
                if GetTime() >= f.fadetime then
                    BBar.Hide(thebar, false)
                    f.fader:SetScript("OnUpdate", nil)
                end
            end)
        end)
        BBar.Hide(thebar, false)
    end
end

local function BarMouseover()
    for i = 1, 10 do
        if setVar(i) == "mouseover" then
            BarMouseoverSetScript("bar", i)
        end
    end

    if GryllsBongos_Settings.bags == "mouseover" then
        BarMouseoverSetScript(BBagBar)
    end

    if GryllsBongos_Settings.class == "mouseover" then
        BarMouseoverSetScript(BClassBar)
    end

    if GryllsBongos_Settings.key == "mouseover" then
        BarMouseoverSetScript(BKeyBar)
    end

    if GryllsBongos_Settings.menu == "mouseover" then
        BarMouseoverSetScript(BMenuBar)
    end

    if GryllsBongos_Settings.xp == "mouseover" then
        BarMouseoverSetScript(BXPBar)
    end
	
    if GryllsBongos_Settings.pet == "mouseover" then
        BarMouseoverSetScript(BPetBar)
    end
end

local function BarUpdate()
    BarToggle()
    BarHide()
    BarShow()
    BarMouseover()
end

local function BarReset()
    for i = 1, 10 do
        setVar(i, "none")
    end

    GryllsBongos_Settings.bags = "none"
    GryllsBongos_Settings.class = "none"
    GryllsBongos_Settings.key = "none"
    GryllsBongos_Settings.menu = "none"
    GryllsBongos_Settings.xp = "none"
    GryllsBongos_Settings.pet = "none"
end

local function GryllsBongos_commands(msg, editbox)
    local yellow = "FFFFFF00"
    local orange = "FFFF9900"

    local function fontnum(msg)
        local startPos = string.find(msg, "%d")
        local numstr = string.sub(msg, startPos)
        if tonumber(numstr) then
            return tonumber(numstr)
        else
            DEFAULT_CHAT_FRAME:AddMessage("Grylls|rBongos:|r bar number was not found, please try again")
        end
    end

    local barnum = nil
    if string.find(msg, "mouseover bar %d") then
        barnum = fontnum(msg)
        setVar(barnum, "mouseover")
        DEFAULT_CHAT_FRAME:AddMessage("|c"..orange.."Grylls|rBongos:|r Bar "..barnum.." is set to mouseover (please reload)")
    elseif string.find(msg, "toggle bar %d") then
        barnum = fontnum(msg)
        setVar(barnum, "toggle")
        DEFAULT_CHAT_FRAME:AddMessage("|c"..orange.."Grylls|rBongos:|r Bar "..barnum.." is set to toggle (please reload to sync toggled elemets)")
    elseif string.find(msg, "hide bar %d") then
        barnum = fontnum(msg)
        setVar(barnum, "hide")
        DEFAULT_CHAT_FRAME:AddMessage("|c"..orange.."Grylls|rBongos:|r Bar "..barnum.." is set to hidden")
        BarUpdate()
    elseif string.find(msg, "show bar %d") then
        barnum = fontnum(msg)
        setVar(barnum, "show")
        DEFAULT_CHAT_FRAME:AddMessage("|c"..orange.."Grylls|rBongos:|r Bar "..barnum.." is set to show")
        BarUpdate()
    -- bags
    elseif msg == "mouseover bags" then
        GryllsBongos_Settings.bags = "mouseover"
        DEFAULT_CHAT_FRAME:AddMessage("|c"..orange.."Grylls|rBongos:|r bags is set to mouseover (please reload)")
        BarUpdate()
    elseif msg == "toggle bags" then
        GryllsBongos_Settings.bags = "toggle"
        DEFAULT_CHAT_FRAME:AddMessage("|c"..orange.."Grylls|rBongos:|r bags is set to toggle (please reload to sync toggled elemets)")
        BarUpdate()
    elseif msg == "hide bags" then
        GryllsBongos_Settings.bags = "hide"
        DEFAULT_CHAT_FRAME:AddMessage("|c"..orange.."Grylls|rBongos:|r bags is set to hidden")
        BarUpdate()
    elseif msg == "show bags" then
        GryllsBongos_Settings.bags = "show"
        DEFAULT_CHAT_FRAME:AddMessage("|c"..orange.."Grylls|rBongos:|r bags is set to show")
        BarUpdate()
    -- class
    elseif msg == "mouseover class" then
        GryllsBongos_Settings.class = "mouseover"
        DEFAULT_CHAT_FRAME:AddMessage("|c"..orange.."Grylls|rBongos:|r class is set to mouseover (please reload)")
        BarUpdate()
    elseif msg == "toggle class" then
        GryllsBongos_Settings.class = "toggle"
        DEFAULT_CHAT_FRAME:AddMessage("|c"..orange.."Grylls|rBongos:|r class is set to toggle (please reload to sync toggled elemets)")
        BarUpdate()
    elseif msg == "hide class" then
        GryllsBongos_Settings.class = "hide"
        DEFAULT_CHAT_FRAME:AddMessage("|c"..orange.."Grylls|rBongos:|r class is set to hidden")
        BarUpdate()
    elseif msg == "show class" then
        GryllsBongos_Settings.class = "show"
        DEFAULT_CHAT_FRAME:AddMessage("|c"..orange.."Grylls|rBongos:|r class is set to show")
        BarUpdate()
    -- key
    elseif msg == "mouseover key" then
        GryllsBongos_Settings.key = "mouseover"
        DEFAULT_CHAT_FRAME:AddMessage("|c"..orange.."Grylls|rBongos:|r key is set to mouseover (please reload)")
        BarUpdate()
    elseif msg == "toggle key" then
        GryllsBongos_Settings.key = "toggle"
        DEFAULT_CHAT_FRAME:AddMessage("|c"..orange.."Grylls|rBongos:|r key is set to toggle (please reload to sync toggled elemets)")
        BarUpdate()
    elseif msg == "hide key" then
        GryllsBongos_Settings.key = "hide"
        DEFAULT_CHAT_FRAME:AddMessage("|c"..orange.."Grylls|rBongos:|r key is set to hidden")
        BarUpdate()
    elseif msg == "show key" then
        GryllsBongos_Settings.key = "show"
        DEFAULT_CHAT_FRAME:AddMessage("|c"..orange.."Grylls|rBongos:|r key is set to show")
        BarUpdate()
    -- menu
    elseif msg == "mouseover menu" then
        GryllsBongos_Settings.menu = "mouseover"
        DEFAULT_CHAT_FRAME:AddMessage("|c"..orange.."Grylls|rBongos:|r menu is set to mouseover (please reload)")
        BarUpdate()
    elseif msg == "toggle menu" then
        GryllsBongos_Settings.menu = "toggle"
        DEFAULT_CHAT_FRAME:AddMessage("|c"..orange.."Grylls|rBongos:|r menu is set to toggle (please reload to sync toggled elemets)")
        BarUpdate()
    elseif msg == "hide menu" then
        GryllsBongos_Settings.menu = "hide"
        DEFAULT_CHAT_FRAME:AddMessage("|c"..orange.."Grylls|rBongos:|r menu is set to hidden")
        BarUpdate()
    elseif msg == "show menu" then
        GryllsBongos_Settings.menu = "show"
        DEFAULT_CHAT_FRAME:AddMessage("|c"..orange.."Grylls|rBongos:|r menu is set to show")
        BarUpdate()
    -- xp
    elseif msg == "mouseover xp" then
        GryllsBongos_Settings.xp = "mouseover"
        DEFAULT_CHAT_FRAME:AddMessage("|c"..orange.."Grylls|rBongos:|r xp is set to mouseover (please reload)")
        BarUpdate()
    elseif msg == "toggle xp" then
        GryllsBongos_Settings.xp = "toggle"
        DEFAULT_CHAT_FRAME:AddMessage("|c"..orange.."Grylls|rBongos:|r xp is set to toggle (please reload to sync toggled elemets)")
        BarUpdate()
    elseif msg == "hide xp" then
        GryllsBongos_Settings.xp = "hide"
        DEFAULT_CHAT_FRAME:AddMessage("|c"..orange.."Grylls|rBongos:|r xp is set to hidden")
        BarUpdate()
    elseif msg == "show xp" then
        GryllsBongos_Settings.xp = "show"
        DEFAULT_CHAT_FRAME:AddMessage("|c"..orange.."Grylls|rBongos:|r xp is set to show")
        BarUpdate()
    -- pet
    elseif msg == "mouseover pet" then
        GryllsBongos_Settings.pet = "mouseover"
        DEFAULT_CHAT_FRAME:AddMessage("|c"..orange.."Grylls|rBongos:|r pet is set to mouseover (please reload)")
        BarUpdate()
    elseif msg == "toggle pet" then
        GryllsBongos_Settings.pet = "toggle"
        DEFAULT_CHAT_FRAME:AddMessage("|c"..orange.."Grylls|rBongos:|r pet is set to toggle (please reload to sync toggled elemets)")
        BarUpdate()
    elseif msg == "hide pet" then
        GryllsBongos_Settings.pet = "hide"
        DEFAULT_CHAT_FRAME:AddMessage("|c"..orange.."Grylls|rBongos:|r pet is set to hidden")
        BarUpdate()
    elseif msg == "show pet" then
        GryllsBongos_Settings.pet = "show"
        DEFAULT_CHAT_FRAME:AddMessage("|c"..orange.."Grylls|rBongos:|r pet is set to show")
        BarUpdate()

    elseif msg == "toggle" then
        BarToggle()
    elseif msg == "update" then -- debug function
        BarUpdate()
        DEFAULT_CHAT_FRAME:AddMessage("|c"..orange.."Grylls|rBongos:|r updated bars")
    elseif msg == "reset" then
        BarReset()
        DEFAULT_CHAT_FRAME:AddMessage("|c"..orange.."Grylls|rBongos:|r settings reset (requires reload)")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|c"..orange.."Grylls|rBongos usage:|r")
        DEFAULT_CHAT_FRAME:AddMessage("|c"..yellow.."/gb mouseover bar n|r - show bar n on mouseover")
        DEFAULT_CHAT_FRAME:AddMessage("|c"..yellow.."/gb mouseover bags|r - show bags bar on mouseover")
        DEFAULT_CHAT_FRAME:AddMessage("|c"..yellow.."/gb mouseover class|r - show class bar on mouseover")
        DEFAULT_CHAT_FRAME:AddMessage("|c"..yellow.."/gb mouseover key|r - show key bar on mouseover")
        DEFAULT_CHAT_FRAME:AddMessage("|c"..yellow.."/gb mouseover menu|r - show menu bar n on mouseover")
        DEFAULT_CHAT_FRAME:AddMessage("|c"..yellow.."/gb mouseover xp|r - show xp bar on mouseover")
		DEFAULT_CHAT_FRAME:AddMessage("|c"..yellow.."/gb mouseover pet|r - show pet bar on mouseover")
		
        DEFAULT_CHAT_FRAME:AddMessage("|c"..yellow.."/gb toggle|r - toggles all elements that are set to toggle")
        DEFAULT_CHAT_FRAME:AddMessage("|c"..yellow.."/gb toggle bar n|r - toggle bar n with command")
        DEFAULT_CHAT_FRAME:AddMessage("|c"..yellow.."/gb toggle bags|r - toggle bags bar with command")
        DEFAULT_CHAT_FRAME:AddMessage("|c"..yellow.."/gb toggle class|r - toggle class bar with command")
        DEFAULT_CHAT_FRAME:AddMessage("|c"..yellow.."/gb toggle key|r - toggle key bar with command")
        DEFAULT_CHAT_FRAME:AddMessage("|c"..yellow.."/gb toggle menu|r - toggle menu bar with command")
        DEFAULT_CHAT_FRAME:AddMessage("|c"..yellow.."/gb toggle xp|r - toggle xp bar with command")
        DEFAULT_CHAT_FRAME:AddMessage("|c"..yellow.."/gb toggle pet|r - toggle pet bar with command")		

        DEFAULT_CHAT_FRAME:AddMessage("|c"..yellow.."/gb hide bar n|r - hide bar n")
        DEFAULT_CHAT_FRAME:AddMessage("|c"..yellow.."/gb hide bags|r - hide bags bar")
        DEFAULT_CHAT_FRAME:AddMessage("|c"..yellow.."/gb hide class|r - hide class bar")
        DEFAULT_CHAT_FRAME:AddMessage("|c"..yellow.."/gb hide key|r - hide key bar")
        DEFAULT_CHAT_FRAME:AddMessage("|c"..yellow.."/gb hide menu|r - hide menu bar")
        DEFAULT_CHAT_FRAME:AddMessage("|c"..yellow.."/gb hide xp|r - hide xp bar")
		DEFAULT_CHAT_FRAME:AddMessage("|c"..yellow.."/gb hide pet|r - hide pet bar")
		
        DEFAULT_CHAT_FRAME:AddMessage("|c"..yellow.."/gb show bar n|r - show bar n")
        DEFAULT_CHAT_FRAME:AddMessage("|c"..yellow.."/gb show bags|r - show bags bar")
        DEFAULT_CHAT_FRAME:AddMessage("|c"..yellow.."/gb show class|r - show class bar")
        DEFAULT_CHAT_FRAME:AddMessage("|c"..yellow.."/gb show key|r - show key bar")
        DEFAULT_CHAT_FRAME:AddMessage("|c"..yellow.."/gb show menu|r - show menu bar")
        DEFAULT_CHAT_FRAME:AddMessage("|c"..yellow.."/gb show xp|r - show xp bar")
		DEFAULT_CHAT_FRAME:AddMessage("|c"..yellow.."/gb show pet|r - show pet bar")

        DEFAULT_CHAT_FRAME:AddMessage("|c"..yellow.."/gb reset|r - resets all bar settings")
	end
end

local GryllsBongos = CreateFrame("Frame", nil, UIParent)
GryllsBongos:RegisterEvent("ADDON_LOADED")
GryllsBongos:RegisterEvent("PLAYER_ENTERING_WORLD")
GryllsBongos:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" then
        if not GryllsBongos.loaded then
            SLASH_GRYLLSBONGOS1 = "/gryllsbongos"
            SLASH_GRYLLSBONGOS2 = "/gb"
            SlashCmdList["GRYLLSBONGOS"] = GryllsBongos_commands
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF9900Grylls|rBongos loaded! /gb")
            GryllsBongos.loaded = true
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        BarUpdate()
    end
end)