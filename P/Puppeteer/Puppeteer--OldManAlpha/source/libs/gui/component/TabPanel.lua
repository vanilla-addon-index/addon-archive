PTGuiTabPanel = PTGuiTabComponent:Extend("tab_panel")
PTGuiTabPanel:SetTabPosition("TOP", 5, 0)

function PTGuiTabPanel:New()
    return self.super.New(self)
end

function PTGuiTabPanel:PlayTabSound()
    PlaySound("GAMESPELLBUTTONMOUSEDOWN")
end

PTGuiLib.RegisterComponent(PTGuiTabPanel)