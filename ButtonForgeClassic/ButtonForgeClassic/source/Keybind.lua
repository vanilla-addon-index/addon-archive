-- ButtonForge Classic - keybinding mode for Vanilla 1.12
local BF = BFClassic

BINDING_HEADER_BUTTONFORGECLASSIC = "ButtonForge Classic"

-- v0.4.32: Keybinds are attached to the physical ButtonForge button position
-- (bindingId), not to the backing Vanilla ActionSlot. This keeps keybinds in
-- place when actions are swapped between buttons.
function BFC_ButtonBinding(bindingId)
    if BF and BF.UseBindingId then
        BF:UseBindingId(bindingId)
    end
end

local function BFC_SetBindingLabels()
    local max = BF.MaxBindingButtons or ((BF.ActionSlotEnd or 120) - (BF.ActionSlotStart or 73) + 1)
    local id
    for id = 1, max do
        _G["BINDING_NAME_BFC_BUTTON_" .. tostring(id)] = "ButtonForge Button " .. tostring(id)
    end
end
BFC_SetBindingLabels()

function BF:GetBindingCommandForButtonId(bindingId)
    if not bindingId then return nil end
    return "BFC_BUTTON_" .. tostring(bindingId)
end

-- Legacy helper kept so older code does not error. New code should not use it
-- for visible hotkeys or assigning keybinds.
function BF:GetBindingCommandForSlot(slot)
    if not slot then return nil end
    return "BFC_ACTIONSLOT_" .. tostring(slot)
end

function BF:GetButtonByBindingId(bindingId)
    if not self.Bars then return nil end
    local i, j
    for i = 1, table.getn(self.Bars) do
        local bar = self.Bars[i]
        if bar and bar.buttons then
            for j = 1, table.getn(bar.buttons) do
                local button = bar.buttons[j]
                if button and button.bindingId == bindingId then
                    return button
                end
            end
        end
    end
    return nil
end

function BF:UseBindingId(bindingId)
    local button = self:GetButtonByBindingId(tonumber(bindingId) or bindingId)
    if button then
        self:UseButton(button)
    end
end

function BF:EnsureProfileKeybinds()
    self:EnsureDB()
    if not ButtonForgeClassicDB.profile.keybinds then
        ButtonForgeClassicDB.profile.keybinds = {}
    end
    ButtonForgeClassicDB.keybinds = ButtonForgeClassicDB.profile.keybinds
    return ButtonForgeClassicDB.profile.keybinds
end

function BF:ClearAllButtonForgeBindings()
    if not SetBinding or not GetBindingKey then return end
    local max = self.MaxBindingButtons or ((self.ActionSlotEnd or 120) - (self.ActionSlotStart or 73) + 1)
    local id
    for id = 1, max do
        self:ClearBindingForCommand(self:GetBindingCommandForButtonId(id))
    end

    -- Clean up old alpha action-slot based commands so legacy bindings cannot
    -- follow swapped actions anymore.
    local slot
    for slot = (self.ActionSlotStart or 73), (self.ActionSlotEnd or 120) do
        self:ClearBindingForCommand(self:GetBindingCommandForSlot(slot))
    end

    local b1 = GetBindingAction and GetBindingAction("BUTTON1")
    local b2 = GetBindingAction and GetBindingAction("BUTTON2")
    if b1 and string.find(b1, "BFC_") then SetBinding("BUTTON1") end
    if b2 and string.find(b2, "BFC_") then SetBinding("BUTTON2") end
end

function BF:ApplyProfileKeybindings()
    -- Do not clear/rebuild on login. WoW loads saved bindings. We only refresh
    -- displayed hotkeys. Assigning/clearing a keybind handles the active binding.
    self:EnsureProfileKeybinds()
    self:RefreshAllHotkeys()
end

function BF:StoreProfileKeybinding(bindingId, key)
    local keybinds = self:EnsureProfileKeybinds()
    if not bindingId then return end
    keybinds[tostring(bindingId)] = key
end

-- Legacy no-op. Keybinds now stay on physical button positions automatically,
-- because the command is BFC_BUTTON_<bindingId> rather than BFC_ACTIONSLOT_<slot>.
function BF:SwapKeybindingsForSlots(slotA, slotB)
end

function BF:ShortenKeyText(text)
    if not text or text == "" then return "" end

    -- Keep button labels inside the icon. This only changes the displayed text;
    -- the actual binding stays unchanged. Handle specific mouse labels before
    -- the generic BUTTON/MOUSEBUTTON replacement so Middle Mouse becomes MM.
    text = string.gsub(text, "MOUSEWHEELUP", "MWU")
    text = string.gsub(text, "MOUSEWHEELDOWN", "MWD")
    text = string.gsub(text, "Mouse Wheel Up", "MWU")
    text = string.gsub(text, "Mouse Wheel Down", "MWD")

    text = string.gsub(text, "Middle Mouse Button", "MM")
    text = string.gsub(text, "Middle Mouse", "MM")
    text = string.gsub(text, "MIDDLE MOUSE", "MM")
    text = string.gsub(text, "Mouse Button 3", "MM")
    text = string.gsub(text, "MOUSEBUTTON3", "MM")
    text = string.gsub(text, "BUTTON3", "MM")
    text = string.gsub(text, "Button 3", "MM")

    text = string.gsub(text, "Mouse Button 4", "M4")
    text = string.gsub(text, "Mouse Button 5", "M5")
    text = string.gsub(text, "MOUSEBUTTON4", "M4")
    text = string.gsub(text, "MOUSEBUTTON5", "M5")
    text = string.gsub(text, "BUTTON4", "M4")
    text = string.gsub(text, "BUTTON5", "M5")

    text = string.gsub(text, "Left Mouse Button", "LM")
    text = string.gsub(text, "Right Mouse Button", "RM")
    text = string.gsub(text, "Mouse Button 1", "LM")
    text = string.gsub(text, "Mouse Button 2", "RM")
    text = string.gsub(text, "BUTTON1", "LM")
    text = string.gsub(text, "BUTTON2", "RM")

    text = string.gsub(text, "MOUSEBUTTON", "M")
    text = string.gsub(text, "Mouse Button ", "M")
    text = string.gsub(text, "BUTTON", "M")
    text = string.gsub(text, "Button ", "M")
    text = string.gsub(text, "NUMPAD", "N")
    text = string.gsub(text, "Num Pad ", "N")
    text = string.gsub(text, "CTRL%-", "C-")
    text = string.gsub(text, "ALT%-", "A-")
    text = string.gsub(text, "SHIFT%-", "S-")
    text = string.gsub(text, "Ctrl%-", "C-")
    text = string.gsub(text, "Alt%-", "A-")
    text = string.gsub(text, "Shift%-", "S-")

    return text
end


function BF:GetKeyTextForButton(button)
    if not button or not button.bindingId then return "" end
    local command = self:GetBindingCommandForButtonId(button.bindingId)
    if not command or not GetBindingKey then return "" end
    local key1 = GetBindingKey(command)
    if key1 then
        local text = key1
        if GetBindingText then
            text = GetBindingText(key1, "KEY_", 1) or key1
        end
        return self:ShortenKeyText(text)
    end
    return ""
end

function BF:GetKeyTextForSlot(slot)
    return ""
end

function BF:ClearBindingForCommand(command)
    if not command or not GetBindingKey or not SetBinding then return end
    local k1, k2 = GetBindingKey(command)
    if k1 then SetBinding(k1) end
    if k2 then SetBinding(k2) end
end

function BF:SaveCurrentBindings()
    -- Keep the last known-good behavior for Turtle/1.12. Do not do any broad
    -- clear/rebuild here; just save the explicit binding change the user made.
    if SaveBindings then
        SaveBindings(2)
    end
end

function BF:UpdateButtonHotkey(button)
    if not button or not button.hotkey then return end
    local text = self:GetKeyTextForButton(button)
    button.hotkey:SetText(text or "")
end

function BF:UpdateKeybindModeVisuals()
    if not self.Bars then return end
    local i, j
    for i = 1, table.getn(self.Bars) do
        local bar = self.Bars[i]
        if bar then
            self:ApplyBarBackground(bar, bar.save)
            if bar.buttons then
                for j = 1, table.getn(bar.buttons) do
                    if bar.buttons[j] then
                        self:RefreshButton(bar.buttons[j])
                    end
                end
            end
        end
    end
end

function BF:RefreshAllHotkeys()
    if not self.Bars then return end
    local i, j
    for i = 1, table.getn(self.Bars) do
        local bar = self.Bars[i]
        if bar and bar.buttons then
            for j = 1, table.getn(bar.buttons) do
                self:UpdateButtonHotkey(bar.buttons[j])
            end
        end
    end
end

function BF:IsKeybindMode()
    self:EnsureDB()
    return ButtonForgeClassicDB.settings and ButtonForgeClassicDB.settings.keybindMode
end

function BF:SetKeybindMode(enabled)
    self:EnsureDB()
    ButtonForgeClassicDB.settings.keybindMode = enabled and true or false

    if enabled then
        ButtonForgeClassicDB.settings.configMode = true
        self:CreateKeybindCaptureFrame()
        self.KeybindFrame:Show()
        self:Print(self:T("KEYBIND_MODE_ON"))
    else
        self.KeybindTarget = nil
        if self.KeybindFrame then self.KeybindFrame:Hide() end
        self:Print(self:T("KEYBIND_MODE_OFF"))
    end

    self:ApplyConfigModeToAllBars()
    self:UpdateKeybindModeVisuals()
    self:RefreshAllHotkeys()
end

function BF:ToggleKeybindMode()
    self:SetKeybindMode(not self:IsKeybindMode())
end

function BF:NormalizeBindingKey(key)
    if not key or key == "UNKNOWN" then return nil end

    if key == "LeftButton" then key = "BUTTON1" end
    if key == "RightButton" then key = "BUTTON2" end
    if key == "MiddleButton" then key = "BUTTON3" end
    if key == "Button1" or key == "MouseButton1" then key = "BUTTON1" end
    if key == "Button2" or key == "MouseButton2" then key = "BUTTON2" end

    -- Safety: never allow primary mouse buttons as bindings. Binding these
    -- breaks camera movement, targeting, looting and normal UI interaction.
    if key == "BUTTON1" or key == "BUTTON2" then
        return nil
    end
    if key == "Button4" or key == "MouseButton4" then key = "BUTTON4" end
    if key == "Button5" or key == "MouseButton5" then key = "BUTTON5" end
    if key == "MouseWheelUp" then key = "MOUSEWHEELUP" end
    if key == "MouseWheelDown" then key = "MOUSEWHEELDOWN" end

    -- Modifier-only presses should not become bindings.
    if key == "LSHIFT" or key == "RSHIFT" or key == "SHIFT" or
       key == "LCTRL" or key == "RCTRL" or key == "CTRL" or
       key == "LALT" or key == "RALT" or key == "ALT" then
        return nil
    end

    local prefix = ""
    if IsControlKeyDown and IsControlKeyDown() then prefix = prefix .. "CTRL-" end
    if IsAltKeyDown and IsAltKeyDown() then prefix = prefix .. "ALT-" end
    if IsShiftKeyDown and IsShiftKeyDown() then prefix = prefix .. "SHIFT-" end
    return prefix .. key
end


function BF:AssignKeyToButton(button, key)
    if not button or not button.bindingId then
        self:Print(self:T("KEYBIND_NO_TARGET"))
        return
    end

    local command = self:GetBindingCommandForButtonId(button.bindingId)
    if not command then return end

    if key == "ESCAPE" or key == "DELETE" or key == "BACKSPACE" then
        self:ClearBindingForCommand(command)
        self:StoreProfileKeybinding(button.bindingId, nil)
        self:SaveCurrentBindings()
        self:UpdateButtonHotkey(button)
        self:Print(self:T("KEYBIND_CLEARED"))
        return
    end

    local bindKey = self:NormalizeBindingKey(key)
    if not bindKey then return end

    self:ClearBindingForCommand(command)
    if SetBinding then
        local ok = SetBinding(bindKey, command)
        self:StoreProfileKeybinding(button.bindingId, bindKey)
        self:SaveCurrentBindings()
        self:RefreshAllHotkeys()
        if ok == nil or ok == 1 then
            self:Print(self:T("KEYBIND_ASSIGNED") .. ": " .. self:ShortenKeyText(bindKey) .. " -> " .. (button.parentBar.save.name or "Bar") .. " Button " .. tostring(button.index))
        else
            self:Print("Binding failed: " .. bindKey)
        end
    end
end

function BF:CreateKeybindCaptureFrame()
    if self.KeybindFrame then return end
    local f = CreateFrame("Frame", "ButtonForgeClassicKeybindFrame", UIParent)
    f:SetAllPoints(UIParent)
    f:SetFrameStrata("DIALOG")
    f:EnableKeyboard(true)
    f:EnableMouse(false)
    f:Hide()
    f:SetScript("OnKeyDown", function()
        if arg1 == "ESCAPE" and not BF.KeybindTarget then
            BF:SetKeybindMode(false)
            return
        end
        if BF.KeybindTarget then
            BF:AssignKeyToButton(BF.KeybindTarget, arg1)
        else
            BF:Print(BF:T("KEYBIND_NO_TARGET"))
        end
    end)
    self.KeybindFrame = f
end
