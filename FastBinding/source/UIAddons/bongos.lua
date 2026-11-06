bongos_BindingButtonsAliases = {
    ["ActionButton"] = "ACTIONBUTTON",
    ["BActionButton"] = "ACTIONBUTTON",
    ["MultiBarBottomLeftButton"] = "ACTIONBUTTON",
    ["MultiBarBottomRightButton"] = "ACTIONBUTTON",
    ["MultiBarRightButton"] = "ACTIONBUTTON",
    ["MultiBarLeftButton"] = "ACTIONBUTTON",
    ["ShapeshiftButton"] = "SHAPESHIFTBUTTON",
    ["BClassBarButton"] = "SHAPESHIFTBUTTON",
    ["PetActionButton"] = "BONUSACTIONBUTTON",
};

function bongos_IsActionButton(button)
    local buttonName, _ = SplitActionButton(button);
    return bongos_BindingButtonsAliases[buttonName]
end

function bongos_GetBindingName(button)

    local buttonName, buttonNumber = SplitActionButton(button);
    local bindingName = bongos_BindingButtonsAliases[buttonName]

    if(buttonName == "MultiBarBottomLeftButton") then
        buttonNumber = tonumber(buttonNumber) + 12
    elseif (buttonName == "MultiBarBottomRightButton") then
        buttonNumber = tonumber(buttonNumber) + 24
    elseif (buttonName == "MultiBarRightButton") then
        buttonNumber = tonumber(buttonNumber) + 36
    elseif (buttonName == "MultiBarLeftButton") then
        buttonNumber = tonumber(buttonNumber) + 48
    else
    end

    return bindingName..buttonNumber;

end

