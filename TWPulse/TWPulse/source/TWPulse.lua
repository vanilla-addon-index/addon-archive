-- TWPulse.lua (Vanilla 1.12 / Turtle)

-------------------------------------------------
-- Emulation _G pour Vanilla 1.12
-------------------------------------------------
if not _G then
    _G = setmetatable({}, {
        __index = function(t, k) return getglobal(k) end,
        __newindex = function(t, k, v) setglobal(k, v) end,
    })
end

-------------------------------------------------
-- Racine
-------------------------------------------------
local TWP = CreateFrame("Frame")

-------------------------------------------------
-- Save + defaults
-------------------------------------------------
if not TWPB_P then TWPB_P = 100 end
if not TWPB_X then TWPB_X = 0 end
if not TWPB_Y then TWPB_Y = 0 end
TWP.defaults = { size = TWPB_P }
TWP.locked = true

-------------------------------------------------
-- Helpers
-------------------------------------------------
local function TableSize(t)
    local size = 0
    for _ in t do size = size + 1 end
    return size
end

function string:split(delimiter)
    local result = {}
    local from = 1
    local delim_from, delim_to = string.find(self, delimiter, from)
    while delim_from do
        table.insert(result, string.sub(self, from, delim_from - 1))
        from = delim_to + 1
        delim_from, delim_to = string.find(self, delimiter, from)
    end
    table.insert(result, string.sub(self, from))
    return result
end

local function GetTotalSpells()
    local total = 0
    local tabs = GetNumSpellTabs()
    for i = 1, tabs do
        local _, _, offset, numSpells = GetSpellTabInfo(i)
        total = total + numSpells
    end
    return total
end

-------------------------------------------------
-- Init
-------------------------------------------------
TWP:RegisterEvent("ADDON_LOADED")
TWP:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "TWPulse" then
        local size = TWPB_P
        TWP.defaults.size = size

        TWPulse:ClearAllPoints()
        TWPulse:SetPoint("CENTER", UIParent, "CENTER", TWPB_X, TWPB_Y)
        TWPulse:SetWidth(size)
        TWPulse:SetHeight(size)
        TWPulse:SetScript("OnDragStart", function() this:StartMoving() end)
        TWPulse:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

        if TWPulseUnlock then
            TWPulseUnlock:ClearAllPoints()
            TWPulseUnlock:SetPoint("CENTER", TWPulse, "CENTER")
            TWPulseUnlock:SetWidth(size)
            TWPulseUnlock:SetHeight(size)
        end

        if TWP.locked then
            TWPulseUnlock:Hide()
            TWPulse:Hide()
            TWPulse:EnableMouse(false)
        else
            TWPulseUnlock:Show()
            TWPulse:Show()
            TWPulse:EnableMouse(true)
        end

        TWP.scan:Show()
    end
end)

-------------------------------------------------
-- Tracking des cooldowns
-------------------------------------------------
TWP.tracked = {}

TWP.scan = CreateFrame("Frame")
TWP.scan:Hide()
TWP.scan:SetScript("OnShow", function() this.startTime = GetTime() end)

TWP.scan:SetScript("OnUpdate", function()
    local plus = 0.1 --seconds
    local gt = GetTime() * 1000
    local st = (this.startTime + plus) * 1000
    if gt >= st then

        local maxSpells = 500;
        local id = 0;
        while (id <= maxSpells) do
            id = id + 1;
            local spellName = GetSpellName(id, BOOKTYPE_SPELL);


            if spellName then
                local start, duration = GetSpellCooldown(id, BOOKTYPE_SPELL)
                local cd = start + duration - GetTime()
                if cd > 1.7 then
                    TWP.tracked[spellName] = id
                end
            end
        end

        for name, spellId in next, TWP.tracked do
            if spellId then
                local start, duration = GetSpellCooldown(spellId, BOOKTYPE_SPELL)
                local cd = start + duration - GetTime()
                if cd <= 0 then
                    TWP.tracked[name] = nil
                    local tEx = string.split(GetSpellTexture(spellId, BOOKTYPE_SPELL), '\\')
                    local tex = tEx[table.getn(tEx)]
                    TWP.QueuePulse(tex)
                end
            end
        end

        this.startTime = GetTime()
    end
end)

-------------------------------------------------
-- Pool d’icônes réutilisables
-------------------------------------------------
TWP.animationFrames = {}
TWP.freeFrames = {}
TWP.animateQueue = {}

local function GetPulseFrame(tex)
    if TWP.freeFrames[1] then
        local frame = table.remove(TWP.freeFrames, 1)
        frame.tex = tex
        return frame
    else
        local frame = CreateFrame("Frame", "TWP_"..tex, TWPulse, "TWPulseTemplate")
        frame.icon = _G["TWP_"..tex.."Icon"]
        return frame
    end
end

function TWP.QueuePulse(tex)
    if TWP.animateQueue[tex] then return end -- protection doublon
    local frame = GetPulseFrame(tex)
    frame.icon:SetTexture("Interface\\Icons\\"..tex)
    frame:SetAlpha(1)
    frame.icon:SetWidth(TWP.defaults.size)
    frame.icon:SetHeight(TWP.defaults.size)
    frame:Show()
    TWP.animationFrames[tex] = frame
    TWP.animateQueue[tex] = 1
    TWP.animation:Show()
end

-------------------------------------------------
-- Animation
-------------------------------------------------
TWP.animation = CreateFrame("Frame")
TWP.animation:Hide()
TWP.animation:SetScript("OnShow", function() this.startTime = GetTime() end)
TWP.animation:SetScript("OnUpdate", function()
    if GetTime() - this.startTime >= 0.01 then
        local baseSize = TWP.defaults.size
        for tex, alpha in next, TWP.animateQueue do
            local frame = TWP.animationFrames[tex]
            if frame and alpha then
                frame:SetAlpha(alpha)
                local scale = alpha + 0.5
                frame.icon:SetWidth(baseSize * scale)
                frame.icon:SetHeight(baseSize * scale)
                TWP.animateQueue[tex] = alpha - 0.02
                if TWP.animateQueue[tex] <= 0 then
                    frame:SetAlpha(0)
                    frame.icon:SetWidth(baseSize)
                    frame.icon:SetHeight(baseSize)
                    frame:Hide()
                    TWP.animateQueue[tex] = nil
                    TWP.animationFrames[tex] = nil
                    table.insert(TWP.freeFrames, frame)
                end
            end
        end

        if TWP.locked then
            if TableSize(TWP.animateQueue) > 0 then
                TWPulse:Show()
                TWPulse:SetScript("OnDragStart", function() this:StartMoving() end)
                TWPulse:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
            else
                TWPulse:Hide()
            end
        else
            TWPulse:Show()
            TWPulse:SetScript("OnDragStart", function() this:StartMoving() end)
            TWPulse:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
        end

        this.startTime = GetTime()
    end
end)

-------------------------------------------------
-- Options Frame
-------------------------------------------------
local TWPOptions = CreateFrame("Frame", "TWPOptionsFrame", UIParent)
TWPOptions:SetWidth(300)
TWPOptions:SetHeight(230)
TWPOptions:SetPoint("CENTER", UIParent, "CENTER")
TWPOptions:EnableMouse(true)
TWPOptions:SetMovable(true)
TWPOptions:RegisterForDrag("LeftButton")
TWPOptions:SetClampedToScreen(true)
TWPOptions:SetScript("OnDragStart", function() this:StartMoving() end)
TWPOptions:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
TWPOptions:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left=8, right=8, top=8, bottom=8 }
})
TWPOptions:Hide()

-- Titre
TWPOptions.title = TWPOptions:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
TWPOptions.title:SetPoint("TOP", 0, -20)
TWPOptions.title:SetText("TWPulse Options")

-- Checkbox Lock
local lockCheck = CreateFrame("CheckButton", "TWPOptionsLockCheck", TWPOptions, "UICheckButtonTemplate")
lockCheck:SetPoint("TOPLEFT", 20, -60)
lockCheck.text = lockCheck:CreateFontString(nil,"OVERLAY","GameFontNormal")
lockCheck.text:SetPoint("LEFT", lockCheck, "RIGHT",25,0)
lockCheck.text:SetText("Lock Pulse Frame")
lockCheck:SetScript("OnClick", function()
    if this:GetChecked() then
        TWP.locked = true
        TWPulseUnlock:Hide()
        TWPulse:Hide()
        TWPulse:EnableMouse(false)
    else
        TWP.locked = false
        TWPulseUnlock:Show()
        TWPulse:Show()
        TWPulse:EnableMouse(true)
    end
end)

-- Slider Taille
-- Slider Taille
local sizeSlider = CreateFrame("Slider", "TWPOptionsSizeSlider", TWPOptions, "OptionsSliderTemplate")
sizeSlider:SetWidth(200)
sizeSlider:SetHeight(16)
sizeSlider:SetPoint("TOP",0,-120)
sizeSlider:SetMinMaxValues(40,200)
sizeSlider:SetValueStep(5)
sizeSlider:SetValue(TWPB_P or TWP.defaults.size)

-- Créer les textes Low/High et Label manuellement
if sizeSlider.Low then sizeSlider.Low:Hide() end
if sizeSlider.High then sizeSlider.High:Hide() end
sizeSlider.LowText = sizeSlider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
sizeSlider.LowText:SetPoint("LEFT", sizeSlider, "LEFT", -10, 0)
sizeSlider.LowText:SetText("40")
sizeSlider.HighText = sizeSlider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
sizeSlider.HighText:SetPoint("RIGHT", sizeSlider, "RIGHT", 10, 0)
sizeSlider.HighText:SetText("200")
sizeSlider.Label = sizeSlider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
sizeSlider.Label:SetPoint("BOTTOM", sizeSlider, "TOP", 0, 2)
sizeSlider.Label:SetText("Icon Size")


sizeSlider:SetScript("OnValueChanged", function()
    local val = this:GetValue()
    TWP.defaults.size = val
    TWPB_P = val
    TWPulse:SetWidth(val)
    TWPulse:SetHeight(val)
    if TWPulseUnlock then
        TWPulseUnlock:SetWidth(val)
        TWPulseUnlock:SetHeight(val)
    end
    -- update pulses actifs
    for _, frame in next, TWP.animationFrames do
        frame.icon:SetWidth(val)
        frame.icon:SetHeight(val)
    end
end)

-- Boutons Reset et Fermer
local resetBtn = CreateFrame("Button", nil, TWPOptions, "UIPanelButtonTemplate")
resetBtn:SetWidth(80)
resetBtn:SetHeight(22)
resetBtn:SetPoint("BOTTOMLEFT", 20, 20)
resetBtn:SetText("Reset")
resetBtn:SetScript("OnClick", function()
    -- Reset taille
    TWPB_P = 100
    TWP.defaults.size = 100
    sizeSlider:SetValue(100)
    TWPulse:SetWidth(100)
    TWPulse:SetHeight(100)
    if TWPulseUnlock then
        TWPulseUnlock:SetWidth(100)
        TWPulseUnlock:SetHeight(100)
    end
    -- Reset position
    TWPB_X = 0
    TWPB_Y = 0
    TWPulse:ClearAllPoints()
    TWPulse:SetPoint("CENTER", UIParent, "CENTER", TWPB_X, TWPB_Y)
    if TWPulseUnlock then
        TWPulseUnlock:ClearAllPoints()
        TWPulseUnlock:SetPoint("CENTER", TWPulse, "CENTER")
    end
end)

local closeBtn = CreateFrame("Button", nil, TWPOptions, "UIPanelButtonTemplate")
closeBtn:SetWidth(80)
closeBtn:SetHeight(22)
closeBtn:SetPoint("BOTTOMRIGHT", -20, 20)
closeBtn:SetText("Fermer")
closeBtn:SetScript("OnClick", function() TWPOptions:Hide() end)

-------------------------------------------------
-- Drag TWPulseUnlock
-------------------------------------------------
TWPulseUnlock:RegisterForDrag("LeftButton")
TWPulseUnlock:SetMovable(true)
TWPulseUnlock:SetScript("OnDragStart", function() TWPulse:StartMoving() end)
TWPulseUnlock:SetScript("OnDragStop", function()
    TWPulse:StopMovingOrSizing()
    local _, _, _, x, y = TWPulse:GetPoint()
    TWPB_X = x or 0
    TWPB_Y = y or 0
end)

-------------------------------------------------
-- Slash Command
-------------------------------------------------
SLASH_TWPOPTIONS1 = "/twp"
SlashCmdList["TWPOPTIONS"] = function(msg)
    if msg == "test" then
        TWP.QueuePulse("Spell_Holy_SealOfMight")
    else
        if TWPOptions:IsShown() then
            TWPOptions:Hide()
        else
            lockCheck:SetChecked(TWP.locked)
            sizeSlider:SetValue(TWP.defaults.size)
            TWPOptions:Show()
        end
    end
end
