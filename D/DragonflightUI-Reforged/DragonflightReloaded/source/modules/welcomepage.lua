---@diagnostic disable: deprecated
setfenv(1, DFRL:GetEnvironment())

function DFRL:SetTempValue(tableName, key, value)
    if not self.tempDB[tableName] then
        self.tempDB[tableName] = {}
    end

    self.tempDB[tableName][key] = value

    return true
end

function DFRL:GetTempValue(tableName, key)
    if not self.tempDB[tableName] then
        return nil
    end

    return self.tempDB[tableName][key]
end

function DFRL:ClearTempValue(tableName, key)
    if not self.tempDB[tableName] then
        return nil
    end

    self.tempDB[tableName][key] = nil
end

local function AddGradientLine(frame, anchor, yOffset)
    local width = frame:GetWidth() - 16
    local height = 3

    local left = frame:CreateTexture(nil, "OVERLAY")
    left:SetTexture("Interface\\Buttons\\WHITE8x8")
    if anchor == "TOP" then
        left:SetPoint("TOP", frame, "TOP", 0, yOffset -1)
        left:SetPoint("RIGHT", frame, "TOP", 0, yOffset -1)
    else
        left:SetPoint("BOTTOM", frame, "BOTTOM", 0, yOffset + 1)
        left:SetPoint("RIGHT", frame, "BOTTOM", 0, yOffset + 1)
    end
    left:SetWidth(width / 2)
    left:SetHeight(height)
    left:SetGradientAlpha("HORIZONTAL", 1, 0.82, 0, 0, 1, 0.82, 0, 1)

    local right = frame:CreateTexture(nil, "OVERLAY")
    right:SetTexture("Interface\\Buttons\\WHITE8x8")
    if anchor == "TOP" then
        right:SetPoint("TOP", frame, "TOP", 0, yOffset - 1)
        right:SetPoint("LEFT", frame, "TOP", 0, yOffset - 1)
    else
        right:SetPoint("BOTTOM", frame, "BOTTOM", 0, yOffset +1)
        right:SetPoint("LEFT", frame, "BOTTOM", 0, yOffset +1)
    end
    right:SetWidth(width / 2)
    right:SetHeight(height)
    right:SetGradientAlpha("HORIZONTAL", 1, 0.82, 0, 1, 1, 0.82, 0, 0)
end

local function ShowWelcomePage()
    local welcomeFrame = CreateFrame("Frame", "DFRL_WelcomeFrame", UIParent)
    welcomeFrame:SetWidth(400)
    welcomeFrame:SetHeight(250)
    welcomeFrame:SetPoint("CENTER", 0, 0)
    welcomeFrame:SetFrameStrata("TOOLTIP")
    welcomeFrame:SetToplevel(true)
    welcomeFrame:SetBackdrop{
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    }
    welcomeFrame:EnableMouse(true)

    AddGradientLine(welcomeFrame, "TOP", -0)
    AddGradientLine(welcomeFrame, "BOTTOM", 0)

    local title = welcomeFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -20)
    title:SetText("|cFFFFFFFFWelcome to|r |cFFFFD700Dragonflight|r: |cFFFFFFFFReloaded|r!")

    local text = welcomeFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOP", title, "BOTTOM", 0, -16)
    text:SetWidth(380)
    text:SetText("Tip:\nHold CTRL + SHIFT + ALT to move frames.\n\n\nBefore reporting bugs:\n|cffff6060Please disable all other addons|n except Dragonflight: Reloaded.|r\n\n90% of bug reports lead to conflicts with other addons.\nThank you for helping us keep bug reports accurate!")

    local okBtn = CreateFrame("Button", nil, welcomeFrame, "UIPanelButtonTemplate")
    okBtn:SetWidth(120)
    okBtn:SetHeight(24)
    okBtn:SetPoint("BOTTOM", 0, 20)
    okBtn:SetText("Dont show again")
    okBtn:Disable()

    okBtn:SetScript("OnClick", function()
        welcomeFrame:Hide()
        DFRL:SetTempValue("generic", "firstRun", true)
    end)

    local barWidth = 200
    local barHeight = 3
    local timerBar = welcomeFrame:CreateTexture(nil, "OVERLAY")
    timerBar:SetTexture("Interface\\Buttons\\WHITE8x8")
    timerBar:SetVertexColor(1, 0.82, 0)
    timerBar:SetPoint("BOTTOM", okBtn, "TOP", 0, 10)
    timerBar:SetWidth(barWidth)
    timerBar:SetHeight(barHeight)

    local elapsed = 0
    welcomeFrame:SetScript("OnUpdate", function()
        elapsed = elapsed + arg1
        if elapsed >= 10 then
            okBtn:Enable()
            timerBar:Hide()
            welcomeFrame:SetScript("OnUpdate", nil)
        else
            timerBar:SetWidth(barWidth * (1 - elapsed / 10))
        end
    end)
end

local function PatchWarning()
    local patchFrame = CreateFrame("Frame", "DFRL_WelcomeFrame", UIParent)
    patchFrame:SetWidth(400)
    patchFrame:SetHeight(200)
    patchFrame:SetPoint("CENTER", 0, 240)
    patchFrame:SetBackdrop{
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        tile = true, tileSize = 32, edgeSize = 32,
    }
    patchFrame:EnableMouse(true)

    AddGradientLine(patchFrame, "TOP", -0)
    AddGradientLine(patchFrame, "BOTTOM", 0)

    local title = patchFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -20)
    title:SetText("|cFFFF0000Important Patch Warning|r")

    local text = patchFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOP", title, "BOTTOM", 0, -16)
    text:SetWidth(380)
    text:SetText("Patch 1.2.0 implemented config changes.\nAbout 15 options have been added.\n\nYour config DB has been reset.")

    local okBtn = CreateFrame("Button", nil, patchFrame, "UIPanelButtonTemplate")
    okBtn:SetWidth(120)
    okBtn:SetHeight(24)
    okBtn:SetPoint("BOTTOM", 0, 20)
    okBtn:SetText("Dont show again")
    okBtn:Disable()

    okBtn:SetScript("OnClick", function()
        patchFrame:Hide()
        DFRL:SetTempValue("generic", "patchWarn", true)
    end)

    local barWidth = 200
    local barHeight = 3
    local timerBar = patchFrame:CreateTexture(nil, "OVERLAY")
    timerBar:SetTexture("Interface\\Buttons\\WHITE8x8")
    timerBar:SetVertexColor(1, 0.82, 0)
    timerBar:SetPoint("BOTTOM", okBtn, "TOP", 0, 10)
    timerBar:SetWidth(barWidth)
    timerBar:SetHeight(barHeight)

    local elapsed = 0
    patchFrame:SetScript("OnUpdate", function()
        elapsed = elapsed + arg1
        if elapsed >= 10 then
            okBtn:Enable()
            timerBar:Hide()
            patchFrame:SetScript("OnUpdate", nil)
        else
            timerBar:SetWidth(barWidth * (1 - elapsed / 10))
        end
    end)

end

local f = CreateFrame("Frame")
f:RegisterEvent("VARIABLES_LOADED")
f:SetScript("OnEvent", function()
    if not DFRL:GetTempValue("generic", "firstRun") then
        ShowWelcomePage()
    end

    if not DFRL:GetTempValue("generic", "patchWarn") then
        PatchWarning()
    end
end)
