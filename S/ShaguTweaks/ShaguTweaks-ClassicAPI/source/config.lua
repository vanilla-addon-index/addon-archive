local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local GetExpansion = ShaguTweaks.GetExpansion
local mod = math.mod or mod

local current_config = {}
local darkKey, goldKey = T["Darkened UI"], T["Golden UI"]
local modeKey = T["UI:"]
local modeLabels = { T["Default"], T["Darkened"], T["Golden"] }
local modeOption = { title = modeKey, description = T["UI mode: Default, Darkened UI or Golden UI."], category = T["Interface"] }
local function SelectedMode()
  return current_config[darkKey] == 1 and 2 or current_config[goldKey] == 1 and 3 or 1
end
local function SelectMode(mode, dropdown)
  current_config[darkKey] = mode == 2 and 1 or 0
  current_config[goldKey] = mode == 3 and 1 or 0
  UIDropDownMenu_SetSelectedID(dropdown, mode)
  UIDropDownMenu_SetText(modeLabels[mode], dropdown)
end
local max_width = 500
local max_height = 680

local settings = CreateFrame("Frame", "AdvancedSettingsGUI", UIParent)
settings:Hide()

table.insert(UISpecialFrames, "AdvancedSettingsGUI")
settings:SetScript("OnHide", function()
  if settings.search then settings.search:ClearFocus() end
  ShowUIPanel(GameMenuFrame)
  UpdateMicroButtons()
end)

settings:SetPoint("CENTER", UIParent, "CENTER", 0, 32)
settings:SetWidth(max_width)
settings:SetMovable(true)
settings:EnableMouse(true)
settings:RegisterForDrag("LeftButton")
settings:SetScript("OnDragStart", function() this:StartMoving() end)
settings:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
settings:SetFrameStrata("DIALOG")

settings:SetBackdrop({
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true, tileSize = 32, edgeSize = 32,
  insets = { left = 11, right = 12, top = 12, bottom = 11 }
})

settings.scrollframe = CreateFrame('ScrollFrame', 'AdvancedSettingsGUIScrollframe', settings, 'UIPanelScrollFrameTemplate')
settings.scrollframe:SetWidth(max_width - 50)
settings.scrollframe:SetPoint('CENTER', settings, -16, -21)
settings.scrollframe:Hide()

settings.container = CreateFrame("Frame", "AdvancedSettingsGUIContainer", settings)
settings.empty = settings.container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
settings.empty:SetPoint("TOP", settings.container, "TOP", 0, -24)
settings.empty:SetText(T["No matching options."])
settings.empty:Hide()

settings.title = CreateFrame("Frame", "AdvancedSettingsGUITtitle", settings)
settings.title:SetPoint("TOP", settings, "TOP", 0, 12)
settings.title:SetWidth(256)
settings.title:SetHeight(64)

settings.title.tex = settings.title:CreateTexture(nil, "MEDIUM")
settings.title.tex:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
settings.title.tex:SetAllPoints()

settings.title.text = settings.title:CreateFontString(nil, "HIGH", "GameFontNormal")
settings.title.text:SetText(T["Advanced Options"])
settings.title.text:SetPoint("TOP", 0, -14)

settings.cancel = CreateFrame("Button", "AdvancedSettingsGUICancel", settings, "GameMenuButtonTemplate")
settings.cancel:SetWidth(90)
settings.cancel:SetPoint("BOTTOMRIGHT", settings, "BOTTOMRIGHT", -17, 17)
settings.cancel:SetText(CANCEL)
settings.cancel:SetScript("OnClick", function()
  current_config = {}
  settings:Hide()
end)

settings.okay = CreateFrame("Button", "AdvancedSettingsGUIOkay", settings, "GameMenuButtonTemplate")
settings.okay:SetWidth(90)
settings.okay:SetPoint("RIGHT", settings.cancel, "LEFT", 0, 0)
settings.okay:SetText(OKAY)
settings.okay:SetScript("OnClick", function()
  local reload

  -- save temporary config to real config
  for k, v in pairs(current_config) do
    if k ~= "overwrites" then
      -- check if reload is required
      if current_config[k] ~= ShaguTweaks_config[k] then
        reload = true
      end

      -- set new config
      ShaguTweaks_config[k] = v
    end
  end

  -- save slider overwrite values
  if current_config.overwrites then
    ShaguTweaks_config.overwrites = ShaguTweaks_config.overwrites or {}
    for k, v in pairs(current_config.overwrites) do
      if ShaguTweaks_config.overwrites[k] ~= v then
        reload = true
      end
      ShaguTweaks_config.overwrites[k] = v
    end
  end

  -- reload the UI if required
  if reload then
    Minimap:SetMaskTexture("Textures\\MinimapMask")
    ReloadUI()
  end

  settings:Hide()
end)

settings.defaults = CreateFrame("Button", "AdvancedSettingsGUIDefaults", settings, "GameMenuButtonTemplate")
settings.defaults:SetWidth(90)
settings.defaults:SetPoint("BOTTOMLEFT", settings, "BOTTOMLEFT", 17, 17)
settings.defaults:SetText(DEFAULTS)
settings.defaults:SetScript("OnClick", function()
  settings:defaults()
end)

settings.version = CreateFrame("Button", "AdvancedSettingsGUIVersion", settings, "GameMenuButtonTemplate")
settings.version:SetWidth(80)
settings.version:SetPoint("LEFT", settings.defaults, "RIGHT", 4, 0)
settings.version:SetText("v" .. (GetAddOnMetadata("ShaguTweaks", "Version") or "unknown"))

settings.projectLink = CreateFrame("Frame", "ShaguTweaksProjectLink", settings)
local projectLink = settings.projectLink
projectLink:SetWidth(420)
projectLink:SetHeight(110)
projectLink:SetPoint("CENTER", settings, "CENTER", 0, 0)
projectLink:SetFrameStrata("DIALOG")
projectLink:SetFrameLevel(settings:GetFrameLevel() + 10)
projectLink:EnableMouse(true)
projectLink:SetBackdrop({
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true, tileSize = 32, edgeSize = 32,
  insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
projectLink:Hide()
table.insert(UISpecialFrames, "ShaguTweaksProjectLink")
projectLink.label = projectLink:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
projectLink.label:SetPoint("TOP", projectLink, "TOP", 0, -16)
projectLink.label:SetText(T["Press Ctrl+C to copy the link."])
projectLink.edit = CreateFrame("EditBox", "ShaguTweaksProjectLinkEdit", projectLink, "InputBoxTemplate")
projectLink.edit:SetWidth(370)
projectLink.edit:SetHeight(24)
projectLink.edit:SetPoint("TOP", projectLink, "TOP", 0, -33)
projectLink.edit:SetAutoFocus(false)
projectLink.edit:SetScript("OnEscapePressed", function() projectLink:Hide() end)
projectLink.edit:SetScript("OnEnterPressed", function() projectLink:Hide() end)
projectLink:SetScript("OnHide", function() projectLink.edit:ClearFocus() end)
projectLink.close = CreateFrame("Button", nil, projectLink, "GameMenuButtonTemplate")
projectLink.close:SetWidth(90)
projectLink.close:SetPoint("BOTTOM", projectLink, "BOTTOM", 0, 12)
projectLink.close:SetText(CLOSE)
projectLink.close:SetScript("OnClick", function() projectLink:Hide() end)
settings.version:SetScript("OnClick", function()
  local color = ShaguTweaks.UIBorder
  if color then projectLink:SetBackdropBorderColor(color.r, color.g, color.b, 1) end
  projectLink:Show()
  projectLink.edit:SetText("https://octowow.st/git/OEVG/ShaguTweaks-ClassicAPI")
  projectLink.edit:SetFocus()
  projectLink.edit:HighlightText()
end)

local searchIndex = {}
local function MatchesSearch(module, title, category, query)
  if query == "" then return true end
  if not searchIndex[module] then
    local text = title .. " " .. category .. " " .. (module.description or "")
    if module.sliders then
      for _, slider in ipairs(module.sliders) do
        text = text .. " " .. (slider.label or slider.key)
      end
    end
    searchIndex[module] = string.lower(text)
  end
  return string.find(searchIndex[module], query, 1, true) ~= nil
end

settings.searchLabel = settings:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
settings.searchLabel:SetPoint("TOPLEFT", settings, "TOPLEFT", 22, -36)
settings.searchLabel:SetText(T["Search:"])
settings.search = CreateFrame("EditBox", "AdvancedSettingsGUISearch", settings, "InputBoxTemplate")
settings.search:SetPoint("TOPLEFT", settings, "TOPLEFT", 78, -30)
settings.search:SetWidth(max_width - 139)
settings.search:SetHeight(24)
settings.search:SetAutoFocus(false)
settings.search:SetText("")
settings.search:SetScript("OnEscapePressed", function() this:ClearFocus() end)
settings.search:SetScript("OnEnterPressed", function() this:ClearFocus() end)
settings.search:SetScript("OnTextChanged", function()
  settings.query = string.lower(string.gsub(string.gsub(this:GetText() or "", "^%s+", ""), "%s+$", ""))
  settings.scrollframe:SetVerticalScroll(0)
  local scrollbar = _G.AdvancedSettingsGUIScrollframeScrollBar
  if scrollbar then scrollbar:SetValue(0) end
  settings:load()
end)
settings.searchClear = CreateFrame("Button", "AdvancedSettingsGUISearchClear", settings, "UIPanelButtonTemplate")
settings.searchClear:SetPoint("LEFT", settings.search, "RIGHT", 8, 0)
settings.searchClear:SetWidth(24)
settings.searchClear:SetHeight(22)
settings.searchClear:SetText("X")
settings.searchClear:SetScript("OnClick", function()
  settings.search:SetText("")
  settings.search:ClearFocus()
end)

settings.UpdateOptionAvailability = function(self)
  if not settings.entries then return end
  for title, button in pairs(settings.entries) do
    local module = ShaguTweaks.mods[title]
    if module and module.requires then
      local available = true
      for _, required in ipairs(module.requires) do
        if current_config[required] ~= 1 then available = false end
      end
      button.dependencyMet = available
      if available then button:Enable() else button:Disable() end
      local label = _G["AdvancedSettingsGUI" .. title .. "Text"]
      if label then
        if available then label:SetTextColor(1, .82, 0)
        else label:SetTextColor(.5, .5, .5) end
      end
    end
  end
end

settings.load = function(self)
  -- never use more than 3/4 of the screen size
  max_height = math.min(UIParent:GetHeight()/UIParent:GetScale()*0.75, 680)

  -- update window sizing according to screen
  settings:SetHeight(max_height)
  settings.scrollframe:SetHeight(max_height - 152)
  settings.container:SetHeight(max_height - 30)

  settings.entries = settings.entries or {}
  -- Reuse widgets, hiding old results before building the filtered layout.
  for _, button in pairs(settings.entries) do button:Hide() end
  for _, panel in pairs(settings.category or {}) do
    panel:Hide()
    if panel.button then panel.button:Hide() end
    if panel.title then panel.title:Hide() end
  end
  local expansion = ShaguTweaks:GetExpansion()

  -- sort all configs into categories
  local gui = {}
  for title, module in pairs(ShaguTweaks.mods) do
    if title ~= darkKey and title ~= goldKey and module.expansions[expansion] then
      local category = module.category or T["General"]
      if MatchesSearch(module, title, category, settings.query or "") then
        gui[category] = gui[category] or {}
        gui[category][title] = module
      end
    end
  end

  local hasMode = expansion == "vanilla" and (ShaguTweaks.mods[darkKey] or ShaguTweaks.mods[goldKey])
  if hasMode then
    local holder = settings.entries["ui-mode"]
    if not holder then
      holder = CreateFrame("Frame", nil, settings)
      holder:SetWidth(160); holder:SetHeight(32)
      holder.label = holder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      holder.label:SetPoint("LEFT", holder, "LEFT", 0, 0)
      holder.label:SetText(modeKey)
      local dropdown = CreateFrame("Frame", "AdvancedSettingsGUIUIMode", holder, "UIDropDownMenuTemplate")
      dropdown:SetPoint("LEFT", holder, "LEFT", 22, -2)
      UIDropDownMenu_SetWidth(90, dropdown)
      UIDropDownMenu_Initialize(dropdown, function()
        for i, label in ipairs(modeLabels) do
          local choice = i
          local info = { text = label, checked = SelectedMode() == i,
            func = function() SelectMode(choice, dropdown) end }
          UIDropDownMenu_AddButton(info)
        end
      end)
      settings.modeDropdown = dropdown
      settings.entries["ui-mode"] = holder
      holder:SetScript("OnHide", function() if CloseDropDownMenus then CloseDropDownMenus() end end)
    end
    holder:ClearAllPoints()
    holder:SetPoint("TOP", settings, "TOP", 0, -56)
    holder:Show()
    UIDropDownMenu_SetSelectedID(settings.modeDropdown, SelectedMode())
    UIDropDownMenu_SetText(modeLabels[SelectedMode()], settings.modeDropdown)
    local color = ShaguTweaks.UIBorder
    if color then
      for _, suffix in ipairs({"Left", "Middle", "Right"}) do
        local texture = _G["AdvancedSettingsGUIUIMode" .. suffix]
        if texture then texture:SetVertexColor(color.r, color.g, color.b, 1) end
      end
    end
  end

  local topspace = 10
  local required_height = topspace
  local entrysize = 22
  local previous = nil

  local sortGeneralFirst = function(a, b)
    if a == T["General"] then return true end
    if b == T["General"] then return false end
    return a < b
  end

  for category, entries in ShaguTweaks.spairs(gui, sortGeneralFirst) do
    local entry, spacing = 1, 22
    local height = 0

    -- add category background
    settings.category = settings.category or {}
    settings.category[category] = settings.category[category] or CreateFrame("Frame", nil, settings.container)
    settings.category[category]:Show()
    settings.category[category]:ClearAllPoints()
    settings.category[category].buttons = {}

    if not previous then
      settings.category[category]:SetPoint("TOPLEFT", settings.container, "TOPLEFT", spacing, -spacing - topspace)
      settings.category[category]:SetPoint("TOPRIGHT", settings.container, "TOPRIGHT", -spacing, -spacing - topspace)
    else
      settings.category[category]:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -spacing)
      settings.category[category]:SetPoint("TOPRIGHT", previous, "BOTTOMRIGHT", 0, -spacing)
    end

    previous = settings.category[category]

    -- create category title collapse button
    local collapse = function(parent, expand)
      if not parent or not parent.button then return end
      local buttons = parent.buttons or {}

      if expand then
        local height = parent.collapse or parent:GetHeight()
        parent.collapse = height
      end

      if not parent.collapse then
        local height = parent:GetHeight()
        parent.collapse = height
        parent:SetHeight(1)

        for button in pairs(buttons) do button:Hide() end
        parent.button:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
        parent.button:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
        parent.button:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled")
        parent.button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
        parent:SetAlpha(0)
      else
        local height = parent.collapse
        parent.collapse = nil
        parent:SetHeight(height)

        for button in pairs(buttons) do button:Show() end
        parent.button:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
        parent.button:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
        parent.button:SetDisabledTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Disabled")
        parent.button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
        parent:SetAlpha(1)
      end
    end

    settings.category[category].button = settings.category[category].button or CreateFrame("Button", nil, settings.container)
    settings.category[category].button:Show()
    settings.category[category].button:SetPoint("TOPLEFT", settings.category[category], "TOPLEFT", 0, entrysize-4)
    settings.category[category].button:SetWidth(22)
    settings.category[category].button:SetHeight(22)
    settings.category[category].button.parent = settings.category[category]
    settings.category[category].button:SetScript("OnClick", function()
      collapse(this.parent)
    end)

    settings.category[category].title = settings.category[category].title or CreateFrame("Button", nil, settings.container)
    settings.category[category].title:Show()
    settings.category[category].title:SetPoint("TOPLEFT", settings.category[category], "TOPLEFT", 22, entrysize-4)
    settings.category[category].title:SetWidth(200)
    settings.category[category].title:SetHeight(entrysize)
    settings.category[category].title.parent = settings.category[category]
    settings.category[category].title:SetScript("OnClick", function()
      collapse(this.parent)
    end)

    settings.category[category]:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 8, edgeSize = 16,
      insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })

    if ShaguTweaks.DarkMode then
      settings.category[category]:SetBackdropColor(.1,.1,.1,1)
      settings.category[category]:SetBackdropBorderColor(.2,.2,.2,1)
    else
      settings.category[category]:SetBackdropColor(.2,.2,.2,1)
      local border = ShaguTweaks.GoldMode and ShaguTweaks.UIBorder
      if border then
        settings.category[category]:SetBackdropBorderColor(border.r, border.g, border.b, 1)
      else
        settings.category[category]:SetBackdropBorderColor(.5,.5,.5,1)
      end
    end

    -- add category title
    settings.category[category].text = settings.category[category].text or settings.category[category].title:CreateFontString(nil, "HIGH", "GameFontHighlightSmall")
    settings.category[category].text:SetJustifyH("LEFT")
    settings.category[category].text:SetAllPoints()
    settings.category[category].text:SetText(category)

    local orderedTitles = {}
    for title in ShaguTweaks.spairs(entries) do
      if title ~= "Modern Class Colors" then table.insert(orderedTitles, title) end
    end
    if entries["Modern Class Colors"] then
      local position = table.getn(orderedTitles) + 1
      for i, title in ipairs(orderedTitles) do
        if title == T["Unit Frame Class Colors"] then position = math.min(i + 2, position); break end
      end
      table.insert(orderedTitles, position, "Modern Class Colors")
    end
    for _, title in ipairs(orderedTitles) do
      local module = entries[title]
      if not settings.entries[title] then
        settings.entries[title] = CreateFrame("CheckButton", "AdvancedSettingsGUI" .. title, settings.category[category], "OptionsCheckButtonTemplate")
        settings.entries[title]:SetHeight(24)
        settings.entries[title]:SetWidth(24)
      end

      local button = _G["AdvancedSettingsGUI" .. title]
      local text = _G["AdvancedSettingsGUI" .. title .. "Text"]

      settings.category[category].buttons = settings.category[category].buttons or {}
      settings.category[category].buttons[button] = true

      button.title = title
      button:Show()
      button:ClearAllPoints()
      button:SetChecked(current_config[title] == 1 and true or nil)
      button:SetPoint("TOPLEFT", settings.category[category], "TOPLEFT", mod(entry, 2) == 1 and 17 or 17+200, math.ceil(entry/2-1)*-entrysize-spacing/2)

      -- add another row to height
      if mod(entry, 2) == 1 then height = height + entrysize end

      local title = module.title
      local description = module.description
      button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_TOPLEFT");
        GameTooltip:SetText(title, nil, nil, nil, nil, 1)
        GameTooltip:AddLine(description, 1, 1, 1, 1, 1)
        GameTooltip:Show()
      end)

      button:SetScript("OnHide", function()
        GameTooltip:Hide()
      end)

      button:SetScript("OnClick", function()
        if this.dependencyMet == false then
          this:SetChecked(current_config[this.title] == 1 and true or nil)
          return
        end
        if this:GetChecked() then
          current_config[this.title] = 1
        else
          current_config[this.title] = 0
        end
        settings:UpdateOptionAvailability()
      end)
      text:SetText(title)
      entry = entry + 1
    end

    -- render sliders declared by modules in this category
    local sliderHeight = 36
    for title, smod in ShaguTweaks.spairs(entries) do
      if smod.sliders then
        for sidx, sdef in ipairs(smod.sliders) do
          local sliderKey = "slider:" .. sdef.key
          local safeName = "AdvancedSettingsGUISlider" .. string.gsub(sdef.key, "[^%w]", "_")

          if not settings.entries[sliderKey] then
            settings.entries[sliderKey] = CreateFrame("Slider", safeName, settings.category[category], "OptionsSliderTemplate")
          end

          local slider = settings.entries[sliderKey]
          slider:Show()
          slider:ClearAllPoints()
          settings.category[category].buttons[slider] = true

          local yOffset = -(height + spacing / 2 + 16 + (sidx - 1) * sliderHeight)
          slider:SetWidth(max_width - 90)
          slider:SetPoint("TOPLEFT", settings.category[category], "TOPLEFT", 17, yOffset)
          slider:SetMinMaxValues(sdef.min, sdef.max)
          slider:SetValueStep(sdef.step or 1)

          local curVal = (current_config.overwrites and current_config.overwrites[sdef.key])
            or (ShaguTweaks_config.overwrites and ShaguTweaks_config.overwrites[sdef.key])
            or sdef.default or sdef.min

          local labelText = sdef.label or sdef.key
          local titleLabel = _G[safeName .. "Text"]
          local lowLabel   = _G[safeName .. "Low"]
          local highLabel  = _G[safeName .. "High"]
          if lowLabel   then lowLabel:SetText(sdef.min) end
          if highLabel  then highLabel:SetText(sdef.max) end
          if titleLabel then titleLabel:SetText(labelText .. ": " .. curVal) end

          local key = sdef.key
          slider:SetScript("OnValueChanged", function()
            local val = math.floor(this:GetValue() + 0.5)
            if titleLabel then titleLabel:SetText(labelText .. ": " .. val) end
            current_config.overwrites = current_config.overwrites or {}
            current_config.overwrites[key] = val
          end)
          slider:SetValue(curVal)

          height = height + sliderHeight
        end
      end
    end

    collapse(settings.category[category], true)

    height = height + spacing
    settings.category[category]:SetHeight(height)

    required_height = required_height + height + spacing
  end

  settings:UpdateOptionAvailability()
  -- set container size to required height
  if not next(gui) then
    if hasMode and MatchesSearch(modeOption, modeKey, modeOption.category, settings.query or "" ) then
      settings.empty:Hide()
    else settings.empty:Show() end
    required_height = 64
  else
    settings.empty:Hide()
  end
  settings.container:SetHeight(required_height)

  if required_height + 132 <= max_height then
    -- reduce base frame if possible
    settings:SetHeight(required_height + 132)
    settings.container:SetParent(settings)
    settings.container:ClearAllPoints()
    settings.container:SetPoint("TOPLEFT", settings, "TOPLEFT", 10, -86)
    settings.container:SetWidth(max_width - 20)

    settings.scrollframe:Hide()
  else
    -- set up scrollframe when needed
    settings.container:SetParent(settings.scrollframe)
    settings.container:ClearAllPoints()
    settings.container:SetPoint("TOPLEFT", settings.scrollframe, "TOPLEFT", 0, 0)
    settings.container:SetWidth(settings.scrollframe:GetWidth() + 20)

    settings.scrollframe:SetScrollChild(settings.container)
    settings.scrollframe:Show()
  end
end

settings.defaults = function()
  -- read default settings from modules
  for title, mod in pairs(ShaguTweaks.mods) do
    current_config[title] = mod.enabled and 1 or 0
  end

  -- reset slider overwrite values to module defaults
  current_config.overwrites = {}
  for title, mod in pairs(ShaguTweaks.mods) do
    if mod.config then
      for k, v in pairs(mod.config) do
        current_config.overwrites[k] = v
      end
    end
  end

  settings:load()
end

settings:SetScript("OnShow", function()
  -- read current config to temporary config
  for k, v in pairs(ShaguTweaks_config) do
    current_config[k] = v
  end
  -- Existing saves may contain both old toggles; retain Darkened precedence.
  if current_config[darkKey] == 1 then current_config[goldKey] = 0 end
  -- copy overwrites into a separate table so Cancel discards slider changes
  current_config.overwrites = {}
  for k, v in pairs(ShaguTweaks_config.overwrites or {}) do
    current_config.overwrites[k] = v
  end

  settings:load()
end)

-- Add "Advanced Settings" Button to the Game Menu
GameMenuFrame:SetWidth(GameMenuFrame:GetWidth() - 10)
GameMenuFrame:SetHeight(GameMenuFrame:GetHeight() + 10)
local advanced = CreateFrame("Button", "GameMenuButtonAdvancedOptions", GameMenuFrame, "GameMenuButtonTemplate")
advanced:SetPoint("TOP", GameMenuButtonUIOptions, "BOTTOM", 0, -1)
advanced:SetText(T["Advanced Options"] .. "|cffffff00*")
advanced:SetScript("OnClick", function()
  HideUIPanel(GameMenuFrame)
  settings:Show()
end)

GameMenuButtonKeybindings:ClearAllPoints()
GameMenuButtonKeybindings:SetPoint("TOP", advanced, "BOTTOM", 0, -1)
