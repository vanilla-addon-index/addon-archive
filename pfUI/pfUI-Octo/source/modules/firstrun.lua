pfUI:RegisterModule("firstrun", "vanilla:tbc", function ()
  -- The install wizard, laid out like ElvUI's installer: one window with the
  -- steps listed on the left, the current step's text and choices on the
  -- right, and Previous / Next / Skip at the bottom. Each step stays a
  -- separate page built by its function (pfUI.firstrun:AddStep), and
  -- pfUI_init[step] records the finished ones, as before. Run it again with
  -- /pfui install or Settings > General > Firstrun.
  pfUI.firstrun = CreateFrame("Frame", "pfFirstRunWizard", UIParent)
  pfUI.firstrun.steps = {}

  pfUI.firstrun:RegisterEvent("PLAYER_ENTERING_WORLD")
  pfUI.firstrun:SetScript("OnEvent", function() pfUI.firstrun:NextStep() end)

  local accent -- "|cffrrggbb" of the accent colour, set when a page is built

  function pfUI.firstrun:AddStep(name, func, title)
    if not name then return end
    table.insert(pfUI.firstrun.steps, { name = name, func = func, title = title or name })
  end

  local current -- the page on screen
  function pfUI.firstrun:NextStep()
    if current then current:Hide() current = nil end

    for id, step in ipairs(pfUI.firstrun.steps) do
      if not pfUI_init[step.name] then
        local f = step.func()
        f.id = id
        f.name = step.name
        f:UpdateSteps()
        if id == table.getn(pfUI.firstrun.steps) then f.next:SetText(T["Finish"]) end
        if id == 1 then f.prev:Disable() end
        f:Show()
        current = f
        return
      end
    end
  end

  -- starts over from the first step
  function pfUI.firstrun:Restart()
    for _, step in ipairs(pfUI.firstrun.steps) do pfUI_init[step.name] = nil end
    pfUI.firstrun:NextStep()
  end

  local function Font(parent, size, layer)
    local s = parent:CreateFontString(nil, layer or "OVERLAY", "GameFontWhite")
    s:SetFont(pfUI.font_default, size, "OUTLINE")
    return s
  end

  -- main function to create wizard windows
  local function CreateFirstRunPage(title)
    local ar, ag, ab = GetAccentColor()
    accent = rgbhex(ar, ag, ab)

    local f = CreateFrame("Frame", nil, UIParent)
    f:SetPoint("CENTER", 0, 40)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetWidth(560)
    f:SetHeight(360)
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

    CreateBackdrop(f, nil, nil, .9)
    CreateBackdropShadow(f)

    -- header
    f.header = Font(f, C.global.font_size + 6)
    f.header:SetPoint("TOPLEFT", 12, -10)
    f.header:SetText(accent .. "pf|rUI " .. accent .. "Octo|r " .. T["Installation"])

    f.close = CreateFrame("Button", nil, f)
    f.close:SetPoint("TOPRIGHT", -8, -8)
    f.close:SetWidth(12)
    f.close:SetHeight(12)
    f.close.texture = f.close:CreateTexture(nil, "OVERLAY")
    f.close.texture:SetTexture(pfUI.media["img:close"])
    f.close.texture:SetAllPoints()
    f.close.texture:SetVertexColor(1, .25, .25, 1)
    SkinButton(f.close, 1, .5, .5)
    f.close:SetScript("OnClick", function() f:Hide() current = nil end)

    -- step list
    f.side = CreateFrame("Frame", nil, f)
    f.side:SetPoint("TOPLEFT", 10, -36)
    f.side:SetPoint("BOTTOMLEFT", 10, 10)
    f.side:SetWidth(140)
    CreateBackdrop(f.side, nil, true, .6)
    f.side.lines = {}

    function f:UpdateSteps()
      for i, step in ipairs(pfUI.firstrun.steps) do
        local line = f.side.lines[i] or Font(f.side, C.global.font_size)
        f.side.lines[i] = line
        line:SetPoint("TOPLEFT", 8, -8 - (i-1) * (C.global.font_size + 8))
        line:SetJustifyH("LEFT")
        if i == f.id then
          line:SetText(accent .. "> " .. step.title .. "|r")
        elseif pfUI_init[step.name] then
          line:SetText("|cff888888" .. step.title .. "|r")
        else
          line:SetText(step.title)
        end
      end
    end

    -- page
    f.title = Font(f, C.global.font_size + 4)
    f.title:SetPoint("TOPLEFT", f.side, "TOPRIGHT", 14, -4)
    f.title:SetJustifyH("LEFT")
    f.title:SetText(accent .. (title or "") .. "|r")

    f.text = Font(f, C.global.font_size + 1)
    f.text:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -10)
    f.text:SetPoint("RIGHT", f, "RIGHT", -14, 0)
    f.text:SetJustifyH("LEFT")
    f.text:SetJustifyV("TOP")
    f.text:SetHeight(110)

    -- the step's buttons and boxes go in here
    f.content = CreateFrame("Frame", nil, f)
    f.content:SetPoint("TOPLEFT", f.side, "TOPRIGHT", 10, -150)
    f.content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 44)

    -- progress and buttons
    f.progress = CreateFrame("StatusBar", nil, f)
    f.progress:SetPoint("BOTTOMLEFT", f.side, "BOTTOMRIGHT", 100, 8)
    f.progress:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -100, 18)
    f.progress:SetHeight(12)
    f.progress:SetStatusBarTexture(pfUI.media["img:bar"])
    f.progress:SetStatusBarColor(ar, ag, ab, 1)
    CreateBackdrop(f.progress)
    f.ptext = Font(f.progress, C.global.font_size - 1)
    f.ptext:SetAllPoints()

    local _UpdateSteps = f.UpdateSteps
    function f:UpdateSteps()
      _UpdateSteps(f)
      local total = table.getn(pfUI.firstrun.steps)
      f.progress:SetMinMaxValues(0, total)
      f.progress:SetValue(f.id or 0)
      f.ptext:SetText((f.id or 0) .. " / " .. total)
    end

    f.next = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.next:SetWidth(80)
    f.next:SetHeight(20)
    f.next:SetPoint("LEFT", f.progress.backdrop, "RIGHT", 8, 0)
    f.next:SetText(T["Next"])
    f.next:SetScript("OnClick", function()
      if f.NextScript then f.NextScript() end
      pfUI_init[f.name] = true
      pfUI.firstrun:NextStep()
    end)
    SkinButton(f.next)

    f.prev = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.prev:SetWidth(80)
    f.prev:SetHeight(20)
    f.prev:SetPoint("RIGHT", f.progress.backdrop, "LEFT", -8, 0)
    f.prev:SetText(T["Previous"])
    f.prev:SetScript("OnClick", function()
      local before = f.id and pfUI.firstrun.steps[f.id - 1]
      if before then
        pfUI_init[before.name] = nil
        pfUI.firstrun:NextStep()
      end
    end)
    SkinButton(f.prev)

    -- ElvUI's "Skip Process": mark every step done without changing anything
    f.skip = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.skip:SetWidth(60)
    f.skip:SetHeight(16)
    f.skip:SetPoint("RIGHT", f.close, "LEFT", -10, 0)
    f.skip:SetText(T["Skip"])
    f.skip:SetScript("OnClick", function()
      for _, step in ipairs(pfUI.firstrun.steps) do pfUI_init[step.name] = true end
      f:Hide()
      current = nil
    end)
    SkinButton(f.skip)

    f:Hide()
    return f
  end

  -- a centred tick box in the content area
  local function Checkbox(f, name, label, checked)
    local box = CreateFrame("CheckButton", name, f.content, "UICheckButtonTemplate")
    box:SetChecked(checked)
    box.text = Font(f.content, C.global.font_size + 1)
    box.text:SetPoint("LEFT", box, "RIGHT", 6, 0)
    box.text:SetText(label)
    box:SetPoint("TOPLEFT", 10, -20)
    SkinCheckbox(box, 18)
    return box
  end

  local function Button(f, label, width, func)
    local b = CreateFrame("Button", nil, f.content, "UIPanelButtonTemplate")
    b:SetWidth(width)
    b:SetHeight(22)
    b:SetText(label)
    b:SetScript("OnClick", func)
    SkinButton(b)
    return b
  end

  -- welcome dialog
  pfUI.firstrun:AddStep("init", function()
    local f = CreateFirstRunPage(T["Welcome"])
    f.text:SetText(T["Welcome to pfUI Octo!\n\nThis installer sets up your interface in a few steps: the look, where your raid frames go, game settings and chat.\n\nEvery step can be skipped and changed later in the options (/pfui). Run this installer again with /pfui install."])
    return f
  end, T["Welcome"])

  -- choose profile
  pfUI.firstrun:AddStep("profile", function()
    local f = CreateFirstRunPage(T["Profile"])
    f.text:SetText(T["Pick a look. |cffffffffOcto|r is the recommended ElvUI-style layout: thin pixel borders, dark panels and clean fonts.\n\nChoosing a profile replaces your current settings and reloads the UI. Keep your settings with \"Next\"."])

    local function Load(config)
      _G["pfUI_config"] = config
      pfUI:LoadConfig()
      pfUI_init["profile"] = true
      ReloadUI()
    end

    f.Octo = Button(f, accent .. "Octo|r (" .. T["Recommended"] .. ")", 240, function() Load(pfUI.octo.Profile()) end)
    f.Octo:SetPoint("TOP", 0, -4)

    local others = { "Modern", "Slim", "Nostalgia", "Legacy" }
    for i, name in ipairs(others) do
      local profile = name
      local b = Button(f, profile, 90, function() Load(CopyTable(pfUI_profiles[profile])) end)
      b:SetPoint("TOP", (i - 2.5) * 96, -34)
      f[profile] = b
    end

    f.Slider = CreateFrame("Slider", "pfFirstRunWizardScaleSlider", f.content, "OptionsSliderTemplate")
    f.Slider.text = f.Slider:CreateFontString("Status", "LOW", "GameFontWhite")
    f.Slider.text:SetPoint("TOP", f.Slider, "BOTTOM", 0, 2)
    f.Slider.text:SetText(T["Scale"])

    f.Slider:SetWidth(240)
    f.Slider:SetHeight(20)
    f.Slider:SetPoint("TOP", 0, -76)
    f.Slider:SetOrientation('HORIZONTAL')
    f.Slider:SetMinMaxValues(0.5, 2.0)
    f.Slider:SetValue(UIParent:GetScale())

    f.Slider:SetScript("OnMouseUp", function()
      local scale = round(this:GetValue(),2)
      SetCVar("uiScale", scale)
      SetCVar("useUiScale", 1)
      UIParent:SetScale(scale)
      this:SetValue(scale)
    end)

    f.Slider:SetScript("OnValueChanged", function()
      local scale = round(this:GetValue(),2)
      this:SetValue(scale)
    end)

    f.Slider:SetScript("OnUpdate", function()
      local scale = round(this:GetValue(),2)
      this.text:SetText(T["Scale"] .. ": " .. scale * 100 .. "%")
    end)

    SkinSlider(f.Slider)

    return f
  end, T["Profile"])

  -- role layout: healers get the raid frames in the middle (ElvUI's healer layout)
  pfUI.firstrun.SetRaidLayout = function(role)
    C.position = C.position or {}
    if role == "HEALER" then
      -- pfRaidCluster is as big as the whole raid grid (octo: one box), so
      -- centring it centres the raid frames
      C.position["pfRaidCluster"] = { anchor = "BOTTOM", xpos = 0, ypos = 180 }
    else
      C.position["pfRaidCluster"] = nil
    end
    if pfRaidCluster then UpdateMovable(pfRaidCluster) end
  end

  pfUI.firstrun:AddStep("layout", function()
    local f = CreateFirstRunPage(T["Layout"])
    f.text:SetText(T["What do you play most?\n\n|cffffffffTank / DPS|r keeps the raid frames at the bottom left, above the chat.\n|cffffffffHealer|r puts them in the middle of the screen, above your action bars, where your eyes are.\n\nMove anything later with /moveui."])

    f.dps = Button(f, T["Tank / DPS"], 150, function() pfUI.firstrun.SetRaidLayout("DPS") f.next:Click() end)
    f.dps:SetPoint("TOP", -80, -20)
    f.healer = Button(f, T["Healer"], 150, function() pfUI.firstrun.SetRaidLayout("HEALER") f.next:Click() end)
    f.healer:SetPoint("TOP", 80, -20)
    return f
  end, T["Layout"])

  -- optimized cvars dialog
  pfUI.firstrun:AddStep("cvars", function()
    local f = CreateFirstRunPage(T["Game Settings"])
    f.text:SetText(T["Do you want me to set up the recommended Blizzard UI settings? This will enable settings that can be found in the Interface section of your client. Options like Buff Durations, Instant Quest Text, Auto Selfcast and others will be set."])
    f.checkbox = Checkbox(f, "pfCheckBoxCVAR", T["Setup Optimized Game Settings"], true)

    f.NextScript = function()
      if f.checkbox:GetChecked() then
        pfUI.SetupCVars()
      end
    end

    return f
  end, T["Game Settings"])

  -- right chat dialog
  pfUI.firstrun:AddStep("chat_right", function()
    local f = CreateFirstRunPage(T["Chat: Loot & Spam"])
    f.text:SetText(T["Do you want me to create and manage a specific Chatframe called \"Loot & Spam\"? This chat will display world channels, loot information and miscellaneous messages, that would otherwise clutter your main chatframe."])
    f.checkbox = Checkbox(f, "pfCheckBoxChatRight", T["Enable \"Loot & Spam\" Window"], true)

    f.NextScript = function()
      if not pfUI.chat then message("Couldn't apply settings. Chat module is disabled.") return end
      pfUI.chat.SetupRightChat(f.checkbox:GetChecked())
    end

    return f
  end, T["Loot & Spam"])

  -- chat position dialog
  pfUI.firstrun:AddStep("chat_position", function()
    local f = CreateFirstRunPage(T["Chat: Layout"])
    f.text:SetText(T["Do you want me to adjust the layout of your chatframes? This would make sure, that every window is placed on its dedicated position."])
    f.checkbox = Checkbox(f, "pfCheckBoxChatPosition", T["Align Chat Windows"], true)

    f.NextScript = function()
      if not pfUI.chat then message("Couldn't apply settings. Chat module is disabled.") return end
      if f.checkbox:GetChecked() then
        pfUI.chat.SetupPositions()
      end
    end

    return f
  end, T["Chat Layout"])

  -- chat channels dialog
  pfUI.firstrun:AddStep("chat_channels", function()
    local f = CreateFirstRunPage(T["Chat: Channels"])
    f.text:SetText(T["Do you want me to setup the chat channels of your chatframes? This would set important or personal messages to the left chat and world channels and lootinformation to the right chat."])
    f.checkbox = Checkbox(f, "pfCheckBoxChatChannels", T["Setup All Chat Channels"], true)

    f.NextScript = function()
      if not pfUI.chat then message("Couldn't apply settings. Chat module is disabled.") return end
      if f.checkbox:GetChecked() then
        pfUI.chat.SetupChannels()
      end
    end

    return f
  end, T["Chat Channels"])

  -- finalize dialog
  pfUI.firstrun:AddStep("finalize", function()
    local f = CreateFirstRunPage(T["Finished"])
    f.text:SetText(T["Your interface is now set up.\n\n|cffffffff/pfui|r opens the options, |cffffffff/moveui|r moves frames, |cffffffff/export|r shares your profile as a text string.\n\nHave a nice trip!"])
    f.reload = Button(f, T["Reload UI"], 120, function() pfUI_init["finalize"] = true ReloadUI() end)
    f.reload:SetPoint("TOP", 0, -20)
    return f
  end, T["Finished"])
end)
