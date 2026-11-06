vanilla_BindingButtonsAliases = {
    ["ActionButton"] = "ACTIONBUTTON",
    ["BonusActionButton"] = "ACTIONBUTTON",
    ["MultiBarBottomLeftButton"] = "MULTIACTIONBAR1BUTTON",
    ["MultiBarBottomRightButton"] = "MULTIACTIONBAR2BUTTON",
    ["MultiBarRightButton"] = "MULTIACTIONBAR3BUTTON",
    ["MultiBarLeftButton"] = "MULTIACTIONBAR4BUTTON",
    ["ShapeshiftButton"] = "SHAPESHIFTBUTTON",
    ["BClassBarButton"] = "SHAPESHIFTBUTTON",
    ["PetActionButton"] = "BONUSACTIONBUTTON",
};

function vanilla_IsActionButton(button)
    local buttonName, _ = SplitActionButton(button);
    return vanilla_BindingButtonsAliases[buttonName]
end

function vanilla_GetBindingName(button)

    local buttonName, buttonNumber = SplitActionButton(button);
    local bindingName = vanilla_BindingButtonsAliases[buttonName]

    return bindingName..buttonNumber;

end

