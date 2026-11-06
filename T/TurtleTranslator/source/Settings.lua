-- Settings.lua
-- Handles UI creation, slash command, and settings persistence

local settingsFrame = nil

local function CreateSettingsUI()
    if settingsFrame and settingsFrame:IsShown() then
        settingsFrame:Hide()
        return
    end

    settingsFrame = CreateFrame("Frame", "TurtleTranslatorSettings", UIParent)
    settingsFrame:SetWidth(600)          -- even more width for comfort
    settingsFrame:SetHeight(400)

    settingsFrame:SetPoint("CENTER", UIParent, "CENTER", 
        TurtleTranslatorDB.windowPos.x or 0, 
        TurtleTranslatorDB.windowPos.y or 0)
    
    settingsFrame:SetMovable(true)
    settingsFrame:EnableMouse(true)
    settingsFrame:RegisterForDrag("LeftButton")

    settingsFrame:SetScript("OnDragStart", function() this:StartMoving() end)
    settingsFrame:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        local frameCenterX, frameCenterY = this:GetCenter()
        local parentCenterX, parentCenterY = UIParent:GetCenter()
        TurtleTranslatorDB.windowPos = TurtleTranslatorDB.windowPos or {}
        TurtleTranslatorDB.windowPos.x = frameCenterX - parentCenterX
        TurtleTranslatorDB.windowPos.y = frameCenterY - parentCenterY
        if TurtleTranslatorDB.debugEnabled then
            DEFAULT_CHAT_FRAME:AddMessage("|cff19e6caDEBUG|r Saved pos: x=" .. TurtleTranslatorDB.windowPos.x .. ", y=" .. TurtleTranslatorDB.windowPos.y)
        end
    end)

    settingsFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    settingsFrame:SetBackdropColor(0, 0, 0, 0.85)
    settingsFrame:SetBackdropBorderColor(1, 1, 1, 0.5)

    local title = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -12)
    title:SetText("TurtleTranslator Settings")

    local closeBtn = CreateFrame("Button", nil, settingsFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -4, -4)

    local cbEnable = CreateFrame("CheckButton", nil, settingsFrame, "OptionsCheckButtonTemplate")
    cbEnable:SetPoint("TOPLEFT", 20, -40)
    local txtEnable = cbEnable:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    txtEnable:SetPoint("LEFT", cbEnable, "RIGHT", 5, 1)
    txtEnable:SetText("Enable translation")
    cbEnable:SetChecked(TurtleTranslatorDB.enabled == true or TurtleTranslatorDB.enabled == 1)
    cbEnable:SetScript("OnClick", function()
        TurtleTranslatorDB.enabled = (this:GetChecked() == 1)
    end)

    -- Channels section (unchanged, but confirm spacingX is enough)
    local channels = {
		{key = "whisper",       text = "Whispers"},
		{key = "party",         text = "Party"},
		{key = "officer",       text = "Officer"},
		{key = "battleground",  text = "Battlegrounds"},
		
		{key = "say",           text = "Say"},
		{key = "guild",         text = "Guild"},
		{key = "raid",          text = "Raid"},
		{key = "otherchannels", text = "Other Channels"},
		
		{key = "yell",          text = "Yell"},
		{key = "emote",         text = "Emotes"},
		{key = "raidwarning",   text = "Raid Warnings"},
	}

    local channelLabel = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    channelLabel:SetPoint("TOPLEFT", 20, -80)
    channelLabel:SetText("Translate incoming messages from these channels:")

    local xStart = 30
    local yStart = -105
    local spacingX = 130   -- keep good spacing
    local spacingY = -28

    -- We define positions manually for this custom 3-row layout
    local positions = {
        -- Row 1
        {x = xStart + 0*spacingX, y = yStart + 0*spacingY},      -- Whispers
        {x = xStart + 1*spacingX, y = yStart + 0*spacingY},      -- Party
        {x = xStart + 2*spacingX, y = yStart + 0*spacingY},      -- Officer
        {x = xStart + 3*spacingX, y = yStart + 0*spacingY},      -- Battlegrounds
        
        -- Row 2
        {x = xStart + 0*spacingX, y = yStart + 1*spacingY},      -- Say
        {x = xStart + 1*spacingX, y = yStart + 1*spacingY},      -- Guild
        {x = xStart + 2*spacingX, y = yStart + 1*spacingY},      -- Raid
        {x = xStart + 3*spacingX, y = yStart + 1*spacingY},      -- Other Channels
        
        -- Row 3
        {x = xStart + 0*spacingX, y = yStart + 2*spacingY},      -- Yell
        {x = xStart + 1*spacingX, y = yStart + 2*spacingY},      -- Emotes
        -- skip col 2
        {x = xStart + 3*spacingX, y = yStart + 2*spacingY},      -- Raid Warnings
    }

    for i, ch in ipairs(channels) do
		local key = ch.key
        local pos = positions[i]
        if not pos then break end  -- safety

        local cb = CreateFrame("CheckButton", nil, settingsFrame, "OptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", pos.x, pos.y)

        local txt = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        txt:SetPoint("LEFT", cb, "RIGHT", 5, 1)
        txt:SetText(ch.text)

        cb:SetChecked(TurtleTranslatorDB.channels[key] == true or TurtleTranslatorDB.channels[key] == 1)
        cb:SetScript("OnClick", function()
			TurtleTranslatorDB.channels[key] = (this:GetChecked() == 1)
		end)
    end

    -- Language sections side by side
    local langY = -210

    -- Translate messages TO (left side)
    local toLabel = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    toLabel:SetPoint("TOPLEFT", 25, langY)
    toLabel:SetText("Translate messages to:")

    local radioButtons = {}

    -- Left column TO
    for i = 1, 5 do
        local lang = langs[i]
        if not lang then break end

        local radio = CreateFrame("CheckButton", nil, settingsFrame, "OptionsCheckButtonTemplate")
        radio:SetPoint("TOPLEFT", 35, langY - 20 - ((i-1) * 24))

        local txt = radio:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        txt:SetPoint("LEFT", radio, "RIGHT", 5, 1)
        txt:SetText(lang.name)

        local idx = lang.index
        radio:SetScript("OnClick", function()
            if this:GetChecked() == 1 then
                TurtleTranslatorDB.targetLangIndex = idx
                for _, other in ipairs(radioButtons) do
                    if other ~= this then other:SetChecked(false) end
                end
            else
                this:SetChecked(true)
            end
        end)

        table.insert(radioButtons, radio)
    end

    -- Right column TO
    for i = 6, numLangs do
        local lang = langs[i]
        if not lang then break end

        local radio = CreateFrame("CheckButton", nil, settingsFrame, "OptionsCheckButtonTemplate")
        radio:SetPoint("TOPLEFT", 180, langY - 20 - ((i-6) * 24))

        local txt = radio:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        txt:SetPoint("LEFT", radio, "RIGHT", 5, 1)
        txt:SetText(lang.name)

        local idx = lang.index
        radio:SetScript("OnClick", function()
            if this:GetChecked() == 1 then
                TurtleTranslatorDB.targetLangIndex = idx
                for _, other in ipairs(radioButtons) do
                    if other ~= this then other:SetChecked(false) end
                end
            else
                this:SetChecked(true)
            end
        end)

        table.insert(radioButtons, radio)
    end

    -- Initial check for TO radios
    for _, radio in ipairs(radioButtons) do radio:SetChecked(false) end
    for i, lang in ipairs(langs) do
        if lang.index == TurtleTranslatorDB.targetLangIndex then
            radioButtons[i]:SetChecked(true)
            break
        end
    end

    -- Translate messages FROM (right side)
    local fromLabel = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fromLabel:SetPoint("TOPLEFT", 320, langY)  -- clearly to the right
    fromLabel:SetText("Translate messages from:")

    -- Left column FROM
    for i = 1, 5 do
        local lang = langs[i]
        if not lang then break end

        local cb = CreateFrame("CheckButton", nil, settingsFrame, "OptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 330, langY - 20 - ((i-1) * 24))

        local txt = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        txt:SetPoint("LEFT", cb, "RIGHT", 5, 1)
        txt:SetText(lang.name)

        local idx = lang.index
        cb:SetChecked(TurtleTranslatorDB.sourceLangs[idx] == true or TurtleTranslatorDB.sourceLangs[idx] == 1)
        cb:SetScript("OnClick", function()
            TurtleTranslatorDB.sourceLangs[idx] = (this:GetChecked() == 1)
        end)
    end

    -- Right column FROM
    for i = 6, numLangs do
        local lang = langs[i]
        if not lang then break end

        local cb = CreateFrame("CheckButton", nil, settingsFrame, "OptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 460, langY - 20 - ((i-6) * 24))

        local txt = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        txt:SetPoint("LEFT", cb, "RIGHT", 5, 1)
        txt:SetText(lang.name)

        local idx = lang.index
        cb:SetChecked(TurtleTranslatorDB.sourceLangs[idx] == true or TurtleTranslatorDB.sourceLangs[idx] == 1)
        cb:SetScript("OnClick", function()
            TurtleTranslatorDB.sourceLangs[idx] = (this:GetChecked() == 1)
        end)
    end

end

-- Slash command (unchanged)
SLASH_TT1 = "/tt"
SLASH_TT2 = "/translator"
SlashCmdList["TT"] = function(msg)
    if msg then msg = string.lower(msg) end

    if not msg or msg == "" or msg == "menu" or msg == "settings" or msg == "config" then
        CreateSettingsUI()
    elseif msg == "debug" then
        TurtleTranslatorDB.debugEnabled = not TurtleTranslatorDB.debugEnabled
        local status = TurtleTranslatorDB.debugEnabled and "|cff00ff00ON|r" or "|cffff0000OFF|r"
        DEFAULT_CHAT_FRAME:AddMessage("|cff19e6caTurtleTranslator Debug: " .. status .. " (use /tt debug to toggle)")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff19e6caUsage:|r /tt [menu|debug]")
    end
end