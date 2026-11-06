local EF
if EFrame == nil then 
    EFrame = {}
end
EF = EFrame

setmetatable(EF, {__index = getfenv() })
setfenv(1, EF)

local options


function showOptions()
    if not options then
        options = EFrame.Window()
        options.title = "Emerald Framework Configuration"
        options.centralItem = ColumnLayout(options)
        options.defaultStyle = EFrame.ComboBox(options.centralItem)
        local styles = {}
        local i, current = 1, nil
        for k, v in pairs(EFrame.styles) do
            tinsert(styles, k)
            if i then
                if EmeraldFrameworkSettings.defaultStyle == k then
                    current = i
                    i = nil
                else
                    i = i +1
                end
            end
        end
        options.defaultStyle.model = styles
        options.defaultStyle.currentIndex = current
        function options.defaultStyle:onActivated(what)
            EmeraldFrameworkSettings.defaultStyle = styles[what]
            ReloadUI()
        end
        
        options.color = EFrame.Button(options.centralItem)
        options.color.text = "Color"
        local function ShowColorPicker(r, g, b, a, changedCallback)
            ColorPickerFrame:SetColorRGB(r,g,b);
            ColorPickerFrame.hasOpacity, ColorPickerFrame.opacity = (a ~= nil), a;
            ColorPickerFrame.previousValues = {r,g,b,a};
            ColorPickerFrame.func, ColorPickerFrame.opacityFunc, ColorPickerFrame.cancelFunc = changedCallback, changedCallback, changedCallback;
            ColorPickerFrame:Hide();
            ColorPickerFrame:Show();
        end
        function options.color.onClicked()
            local color = Theme.__color
            ShowColorPicker(color[1], color[2], color[3], color[4], function (restore)
                if restore then
                    Theme.color = restore
                else
                    local r, g, b = ColorPickerFrame:GetColorRGB()
                    Theme.color = {r, g, b, OpacitySliderFrame:GetValue()}
                end
            end)
        end
        options.color.z = 3
    end
end

local function chatcmd(msg)
    if not msg or msg == "" then
        if not options then
            showOptions()
        else
            options.visible = not options.visible
        end
        return
    else
        print("EmeraldFramework slash command: /ef")
    end
end

setglobal("SLASH_EMERALDFRAMEWORK1", "/emeraldframeowkr")
setglobal("SLASH_EMERALDFRAMEWORK2", "/ef")
SlashCmdList["EMERALDFRAMEWORK"] = chatcmd  
