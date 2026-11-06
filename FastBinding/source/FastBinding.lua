FastBinding.Frame = CreateFrame("Frame");
FastBinding.Enabled = false;
FastBinding.UIAddon = "WoW Vanilla";

local FBDarkOverlay

-- Plugin enabler
function FastBinding.Enable(enable)

    FastBinding.Enabled = enable;

    if not FBDarkOverlay then
        FBDarkOverlay = CreateFrame("Frame", "FBDarkOverlay", UIParent)
        FBDarkOverlay:SetAllPoints(UIParent)
        FBDarkOverlay.texture = FBDarkOverlay:CreateTexture()
        FBDarkOverlay.texture:SetAllPoints(FBDarkOverlay)
        FBDarkOverlay.texture:SetTexture(0, 0, 0, 0.7)
    end

    if enable then
        FastBinding.Frame:EnableKeyboard(true);
        FastBinding.Frame:SetScript("OnKeyDown", function()
            local key = arg1;
            this:OnKeyDown(key);
        end);
        FBPrint.Chat("Enabled binding. Press ENTER or ESCAPE (with mouse out of action bars) to disable", "green");
        FBDarkOverlay:Show()

    else
        FastBinding.Frame:EnableKeyboard(nil);
        FastBinding.Frame:SetScript("OnKeyDown", nil);
        FBPrint.Chat("Disabled binding", "green");
        FBDarkOverlay:Hide()
    end

end

-- Handler: /fb slash command
SLASH_FASTBINDING1 = "/fb";
SlashCmdList["FASTBINDING"] = function(cmd)
    if(cmd == "") then
        FastBinding.Enable(not FastBinding.Enabled)
    elseif(cmd == "debug") then
        if(FastBinding.Debug) then
            FastBinding.Debug = false
            FBPrint.Chat("Debug mode disabled")
        else
            FastBinding.Debug = true
            FBPrint.Chat("Debug mode enabled")
        end
    else
        if(FastBinding.Debug) then
            FBPrint.Debug(GetBindingAction(cmd))
        end
    end
end

-- Handler: on load to detect UIAddon
FastBinding.Frame:RegisterEvent("PLAYER_LOGIN")
FastBinding.Frame:SetScript("OnEvent", function()
    for i = 1, GetNumAddOns() do
        local name, title, _, enabled, loadable, reason = GetAddOnInfo(i)
        if IsAddOnLoaded(i) then
            if IsAcceptedUIAddon(name) then
                FastBinding.UIAddon = name
                break
            end
        end
    end

    if(FastBinding.Debug) then
        FBPrint.Chat("Loaded FastBinding as Debug", "yellow")
    else
        FBPrint.Chat("Loaded FastBinding", "yellow")
    end
    FBPrint.Chat("Detected '"..FastBinding.UIAddon.."' as UI Manager", "yellow")

end)

-- Handler: on key down to detect pressed key
function FastBinding.Frame:OnKeyDown(key)

    local frame = GetMouseFocus():GetName();

    -- ENTER always disables FastBinding
    if key == "ENTER" then
        FastBinding.Enable(false)
        return
    end

    -- Ignore modifier keys
    if key == "ALT" or key == "SHIFT" or key == "CTRL" then
        return
    end

    if IsActionButton(frame, FastBinding.UIAddon) then
        -- ESCAPE on ActionButton resets binding
        if key == "ESCAPE" then
            FastBinding.ResetActionButton(frame)
        else
            FastBinding.SetKeyToActionButton(key, frame)
        end
    else
        -- ESCAPE out ActionButton disables FB
        if key == "ESCAPE" then
            FastBinding.Enable(false)
        end
    end

end

-- Actioner: Set binding
function FastBinding.SetKeyToActionButton(key, actionButton)

    local bindingName = GetBindingName(actionButton, FastBinding.UIAddon);

    if (IsShiftKeyDown()) then
        key = "SHIFT-"..key;
    end
    if (IsControlKeyDown()) then
        key = "CTRL-"..key;
    end
    if (IsAltKeyDown()) then
        key = "ALT-"..key;
    end

    local usedKey = GetBindingKey(bindingName);
    if usedKey then
        SetBinding(usedKey);
    end

    if SetBinding(key, bindingName, 1) then
        FBPrint.Chat("Set "..key.. " to "..bindingName);
    end

    SaveBindings(2);

end

-- Actioner: Reset binding
function FastBinding.ResetActionButton(actionButton)

    local bindingName = GetBindingName(actionButton, FastBinding.UIAddon);
    local usedKey = GetBindingKey(bindingName);
    if usedKey then
        SetBinding(usedKey);
        FBPrint.Chat("Removed "..usedKey.." from "..bindingName);
        SaveBindings(2);
    end

end