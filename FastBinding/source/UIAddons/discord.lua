discord_BindingButtonsAliases = {
    ["DAB_ActionButton_"] = "DAB_",
    ["ShapeshiftButton"] = "SHAPESHIFTBUTTON",
    ["BClassBarButton"] = "SHAPESHIFTBUTTON",
    ["PetActionButton"] = "BONUSACTIONBUTTON",
};

function discord_IsActionButton(button)
    local buttonName = SplitActionButton(button);
    return discord_BindingButtonsAliases[buttonName]
end

function discord_GetBindingName(button)
    FBPrint.Debug(button)
    local buttonName, buttonNumber = SplitActionButton(button);
    local bindingName = discord_BindingButtonsAliases[buttonName]
    return bindingName..buttonNumber;
end