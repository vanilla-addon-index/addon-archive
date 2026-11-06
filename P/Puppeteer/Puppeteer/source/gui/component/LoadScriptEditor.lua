PTLoadScriptEditor = PTGuiComponent:Extend("puppeteer_load_script_editor")
local colorize = PTUtil.Colorize

function PTLoadScriptEditor:New()
    local obj = setmetatable({}, self)
    local frame = CreateFrame("Frame", self:GenerateName())
    obj:SetHandle(frame)
    obj:SetSimpleBackground(PTGuiComponent.BACKGROUND_DIALOG)
    local title = PTGuiLib.Get("title", frame)
        :SetSize(192, 36)
        :SetPoint("CENTER", frame, "TOP")
        :SetText("Edit Script")
    obj:AddComponent("Title", title)
    local editbox = PTGuiLib.Get("multi_line_editbox", frame)
        :SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -30)
        :SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 30)
        :SetScript("OnTabPressed", function(self)
            self:GetHandle():Insert("  ")
        end)
    editbox:GetScrollFrame():SetSimpleBackground()
    obj:AddComponent("Editbox", editbox)

    local saveButton = PTGuiLib.Get("button", frame)
        :SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 5)
        :SetSize(150, 20)
        :SetText("Save")
        :OnClick(function()
            obj.Callback(true, editbox:GetText())
        end, true)
    local cancelButton = PTGuiLib.Get("button", frame)
        :SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 5, 5)
        :SetSize(150, 20)
        :SetText("Cancel")
        :OnClick(function()
            obj.Callback(false)
        end, true)
    return obj
end

function PTLoadScriptEditor:OnAcquire()
    self.super.OnAcquire(self)
    self:GetEditbox():SetText("")
    self:GetEditbox():GetScrollFrame():FixNextUpdate()
    self:SetSize(375, 325)
end

PTLoadScriptEditor:CreateGetter("Editbox")

function PTLoadScriptEditor:SetCallback(func)
    self.Callback = func
    return self
end

function PTLoadScriptEditor:SetTitle(title)
    self:GetComponent("Title"):SetText(title)
    return self
end

PTGuiLib.RegisterComponent(PTLoadScriptEditor)