AcceptedUIs = {
    ["WoW Vanilla"] = {
        ["GetBindingName"] = vanilla_GetBindingName,
        ["IsActionButton"] = vanilla_IsActionButton,
    },
    ["Bongos"] = {
        ["GetBindingName"] = bongos_GetBindingName,
        ["IsActionButton"] = bongos_IsActionButton,
    },
    ["DiscordActionBars"] = {
        ["GetBindingName"] = discord_GetBindingName,
        ["IsActionButton"] = discord_IsActionButton,
    },
}

function IsAcceptedUIAddon(name)
    return IsInArray(name, AcceptedUIs)
end

function IsActionButton(button, uiAddon)
    FBPrint.Debug("Action button detected "..button);
    return AcceptedUIs[uiAddon]["IsActionButton"](button)
end

function GetBindingName(button, uiAddon)
    return AcceptedUIs[uiAddon]["GetBindingName"](button)
end