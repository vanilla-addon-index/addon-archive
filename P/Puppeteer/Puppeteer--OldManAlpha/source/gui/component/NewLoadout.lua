PTNewLoadout = PTGuiComponent:Extend("puppeteer_new_loadout")

function PTNewLoadout:New()
    local obj = setmetatable({}, self)
    local frame = CreateFrame("Frame", self:GenerateName())
    obj:SetHandle(frame)
    obj:SetSimpleBackground(PTGuiComponent.BACKGROUND_DIALOG)

    local title = PTGuiLib.Get("title", frame)
        :SetSize(192, 36)
        :SetPoint("CENTER", frame, "TOP")
        :SetText("New Bindings Loadout")
    obj:AddComponent("Title", title)

    local margin = 115
    local yPos = -35

    local inheritLabel = PTGuiLib.GetText(frame, "Copy From")
        :SetPoint("RIGHT", frame, "TOPLEFT", margin, yPos)
    local inheritDropdown = PTGuiLib.Get("dropdown", frame)
        :SetPoint("LEFT", inheritLabel, "RIGHT", 5, 0)
        :SetWidth(150)
        :SetDynamicOptions(function(addOption, level, args)
            addOption("text", "<Blank>",
                "dropdownText", "<Blank>",
                "initFunc", args.initFunc)
            for _, name in ipairs(Puppeteer.GetBindingLoadoutNames()) do
                addOption("text", name,
                    "dropdownText", name,
                    "initFunc", args.initFunc)
            end
        end, {
            initFunc = function(self, gui)
                self.checked = self.text == gui:GetText()
            end
        })
        :SetText("<Blank>")
    obj:AddComponent("InheritDropdown", inheritDropdown)

    yPos = yPos - 30
    
    local nameLabel = PTGuiLib.GetText(frame, "Loadout Name")
        :SetPoint("RIGHT", frame, "TOPLEFT", margin, yPos)
    local nameEditbox = PTGuiLib.Get("editbox", frame)
        :SetPoint("LEFT", nameLabel, "RIGHT", 5, 0)
        :SetSize(150, 20)
        :SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
        end)
    obj:AddComponent("NameEditbox", nameEditbox)

    local cancelButton = PTGuiLib.Get("button", frame)
        :SetText("Cancel")
        :SetPoint("BOTTOM", frame, "BOTTOM", 0, 5)
        :SetSize(150, 20)
        :OnClick(function()
            PTSettingsGui.PopOverlayFrame()
            obj:Dispose()
        end)
    cancelButton:SetClickSound(PlaySound, "igMainMenuClose")

    local createLoadoutButton = PTGuiLib.Get("button", frame)
        :SetText("Create Loadout")
        :SetPoint("BOTTOM", cancelButton, "TOP", 0, 5)
        :SetSize(150, 20)
        :OnClick(function()
            local inheritFrom = inheritDropdown:GetText()
            local name = nameEditbox:GetText()
            if name == "" or name == "<Blank>" then
                return
            end
            local loadouts = Puppeteer.GetBindingLoadouts()
            if loadouts[name] then
                DEFAULT_CHAT_FRAME:AddMessage("Loadout with that name already exists!")
                return
            end
            local loadout = Puppeteer.NewBindingsLoadout(name, loadouts[inheritFrom])
            Puppeteer.SetSelectedBindingsLoadout(name)
            PTSettingsGui.PopOverlayFrame()
            obj:Dispose()
        end)
    createLoadoutButton:SetClickSound(PlaySound, "igMainMenuClose")
    
    return obj
end

function PTNewLoadout:OnAcquire()
    self.super.OnAcquire(self)
    self:SetSize(300, 150)
    self:GetInheritDropdown():SetText("<Blank>")
    self:GetNameEditbox():SetText("")
end

function PTNewLoadout:OnDispose()
    self.super.OnDispose(self)
end

PTNewLoadout:CreateGetter("InheritDropdown")
PTNewLoadout:CreateGetter("NameEditbox")

PTGuiLib.RegisterComponent(PTNewLoadout)