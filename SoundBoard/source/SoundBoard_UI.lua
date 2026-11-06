SoundBoard_UI = {}

function SoundBoard_UI:CreateFrame()
    local frame = CreateFrame("Frame", "SoundBoardFrame", UIParent)
    frame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background" })
    frame:SetPoint("CENTER", UIParent, "CENTER")
    frame:SetWidth(200)
    frame:SetHeight(240) -- ou ajuste selon visuel
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) this:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) this:StopMovingOrSizing() end)

    -- 🌈 Titre "SoundBoard" arc-en-ciel fluide, centré (WoW 1.12 compatible)
    local letters = {}
    local text = "SoundBoard"
    local frameWidth = 200
    local letterWidth = 12 -- estimation visuelle moyenne
    local numLetters = string.len(text)
    local totalWidth = numLetters * letterWidth
    local startX = math.floor((frameWidth - totalWidth) * 0.5)


    for i = 1, numLetters do
        local letter = string.sub(text, i, i)
        local fontString = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        fontString:SetText(letter)
        fontString:SetPoint("TOPLEFT", frame, "TOPLEFT", startX + (i - 1) * letterWidth, 20)
        fontString:SetTextColor(1, 1, 1)
        table.insert(letters, fontString)
    end

    -- Convertit une teinte H (0–1) en RGB
    local function HSVtoRGB(h)
        local r, g, b
        local i = math.floor(h * 6)
        local f = h * 6 - i
        local q = 1 - f

        i = math.mod(i, 6)
        if i == 0 then r, g, b = 1, f, 0
        elseif i == 1 then r, g, b = q, 1, 0
        elseif i == 2 then r, g, b = 0, 1, f
        elseif i == 3 then r, g, b = 0, q, 1
        elseif i == 4 then r, g, b = f, 0, 1
        elseif i == 5 then r, g, b = 1, 0, q
        end
        return r, g, b
    end

    -- Animation arc-en-ciel fluide
    frame:SetScript("OnUpdate", function()
        if not this.rainbowTimer then this.rainbowTimer = 0 end
        this.rainbowTimer = this.rainbowTimer + arg1

        local baseHue = this.rainbowTimer * 0.2
        baseHue = baseHue - math.floor(baseHue) -- simule % 1

        for i, letter in ipairs(letters) do
            local hue = baseHue + i * 0.08
            hue = hue - math.floor(hue) -- simule % 1
            local r, g, b = HSVtoRGB(hue)
            letter:SetTextColor(r, g, b)
        end
    end)

    -- ✅ Bouton Close
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetWidth(32)
    closeBtn:SetHeight(32)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 10, 10)
    closeBtn:SetScript("OnClick", function()
        frame:Hide()
    end)

    -- ✅ ScrollFrame pour les sons (max hauteur = 6 lignes de 30px)
    local scrollFrame = CreateFrame("ScrollFrame", "SoundBoardScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -30)
    scrollFrame:SetWidth(160)
    scrollFrame:SetHeight(160)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(160)
    content:SetHeight(400) -- assez grand pour forcer la scrollbar à apparaître

    scrollFrame:SetScrollChild(content)

    local allSounds = self:GetAllSounds()

    local colCount = 2
    local spacingX = 8
    local spacingY = 6
    local buttonWidth = 75
    local buttonHeight = 24

    local i = 0
    local maxRow = 0

    for name, _ in pairs(allSounds) do
        local soundName = name
        local btn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")

        -- Tronquer le texte si trop long
        local maxTextLength = 8
        local displayName = soundName
        if string.len(soundName) > maxTextLength then
            displayName = string.sub(soundName, 1, maxTextLength - 3) .. "..."
        end

        btn:SetText(displayName)
        btn:SetWidth(buttonWidth)
        btn:SetHeight(buttonHeight)

        -- Calcul position en grille 3 colonnes
        local col = math.mod(i, colCount)
        local row = math.floor(i / colCount)

        btn:SetPoint("TOPLEFT", content, "TOPLEFT",
            col * (buttonWidth + spacingX),
            -row * (buttonHeight + spacingY))

        btn:SetScript("OnClick", function()
            SoundBoard:SendSound(soundName)
        end)

        btn:SetScript("OnEnter", function()
            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:SetText(soundName, 1, 1, 1)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        i = i + 1
        maxRow = row
    end

    content:SetHeight((maxRow + 1) * (buttonHeight + spacingY))

    -- ✅ Bouton texte mute
    self:AddMuteButton(frame)

    frame:Hide()

    SLASH_SOUNDBOARD1 = "/sb"
    SlashCmdList["SOUNDBOARD"] = function()
        if frame:IsShown() then
            frame:Hide()
        else
            frame:Show()
        end
    end
end



-- 🔁 Réimplémentation du bouton mute avec texte
function SoundBoard_UI:AddMuteButton(parent)
    if self.muteButton then return end

    if SoundBoard == nil then SoundBoard = {} end
    if SoundBoard.muted == nil then SoundBoard.muted = false end

    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetWidth(80)
    btn:SetHeight(20)
    btn:SetPoint("BOTTOM", parent, "BOTTOM", 0, 6)

    local function UpdateText()
        btn:SetText("Son : " .. (SoundBoard.muted and "On" or "Off"))
    end

    btn:SetScript("OnClick", function()
        SoundBoard.muted = not SoundBoard.muted
        if SoundBoard.muted then
            print("🔇 Mute mode activated.")
        else
            print("🔊 Mute mode disabled.")
        end
        UpdateText()
    end)

    btn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:SetText("Sound on/off", 1, 1, 1)
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    UpdateText()
    btn:Show()

    self.muteButton = btn
end

function SoundBoard_UI:GetAllSounds()
    local sounds = {}
    for k, v in pairs(SoundBoard_Sounds or {}) do sounds[k] = v end
    for k, v in pairs(SoundBoard_Custom or {}) do sounds[k] = v end
    return sounds
end
