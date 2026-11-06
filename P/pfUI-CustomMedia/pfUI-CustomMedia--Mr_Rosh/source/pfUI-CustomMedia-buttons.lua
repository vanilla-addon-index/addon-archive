if not pfUI or type(pfUI.RegisterModule) ~= "function" then return end

pfUI:RegisterModule("CustomMedia", "vanilla:tbc", function()
  if type(pfUI.gui) ~= "table" or type(pfUI.gui.dropdowns) ~= "table" or type(C) ~= "table" then return end

  -- Cache frequently used globals
  local _G = _G
  local strsplit = strsplit
  local tonumber = tonumber
  local type = type
  local pairs = pairs

  local addonpath
  local tocs = { "", "-master", "-tbc", "-wotlk" }
  for _, name in ipairs(tocs) do
    local current = string.format("pfUI-CustomMedia%s", name)
    local _, title = GetAddOnInfo(current)
    if title then
      addonpath = "Interface\\AddOns\\" .. current
      break
    end
  end
  if not addonpath then return end

  if not C.CustomMedia then C.CustomMedia = {} end
  -- Action bar settings
  C.CustomMedia.actionbar_texture = C.CustomMedia.actionbar_texture or "Default"
  C.CustomMedia.actionbar_color = C.CustomMedia.actionbar_color or "1,1,1,0.5"
  -- Bags settings
  C.CustomMedia.bags_texture = C.CustomMedia.bags_texture or "Default"
  C.CustomMedia.bags_color = C.CustomMedia.bags_color or "1,1,1,0.5"
  C.CustomMedia.debug = false -- turn true if you want print statements

  local texture_options = {
    "Default:Default",
    "Wings:Wings",
    "Lion:Lion",
    "Eagle:Eagle",
    "Grunge:Grunge",
    "Textured:Textured",
    "Transparent:Transparent",
    "Dragon:Dragon",
    "Skull:Skull"
  }

  pfUI.gui.dropdowns.CustomMedia_actionbar = texture_options
  pfUI.gui.dropdowns.CustomMedia_bags = texture_options

  local function PrintDebug(msg)
    if C.CustomMedia.debug then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[CustomMedia]:|r " .. msg)
    end
  end

  local textures = {
    Default = nil,
    Wings = addonpath .. "\\backgrounds\\wings",
    Lion = addonpath .. "\\backgrounds\\lion",
    Eagle = addonpath .. "\\backgrounds\\eagle",
    Grunge = addonpath .. "\\backgrounds\\grunge",
    Textured = addonpath .. "\\backgrounds\\textured",
    Transparent = addonpath .. "\\backgrounds\\transparent",
    Dragon = addonpath .. "\\backgrounds\\dragon",
    Skull = addonpath .. "\\backgrounds\\skull"
  }

  local function GetTexture(selection)
    return textures[selection] or nil
  end

  local function GetStringColor(color)
    if type(color) == "string" then
      local r, g, b, a = strsplit(",", color)
      return tonumber(r), tonumber(g), tonumber(b), tonumber(a) or 1
    elseif type(color) == "table" then
      return color.r or 1, color.g or 1, color.b or 1, color.a or 1
    end
    return 1, 1, 1, 1 -- default to white if no valid color is provided
  end

  local function ApplyBackground(texture, r, g, b, a, frame)
    -- Style hidden buttons too. pfUI creates most buttons during login and
    -- reveals them later when their bar, stance, bag, or bank becomes active.
    if not frame then return end
    if not frame.bg then
      frame.bg = frame:CreateTexture(nil, "BACKGROUND")
      frame.bg:SetDrawLayer("BACKGROUND", -8)
      frame.bg:SetAllPoints(frame)
    end
    if texture then
      frame.bg:SetTexture(texture)
      frame.bg:SetTexCoord(0, 1, 0, 1)
      frame.bg:SetVertexColor(r, g, b, a)
      frame.bg:Show()
      PrintDebug("Applied texture to " .. (frame:GetName() or "unknown"))
    else
      frame.bg:SetTexture(nil)
      frame.bg:Hide()
    end
    local icon = frame.icon or frame:GetNormalTexture()
    if icon then
      icon:SetDrawLayer("ARTWORK", 1)
      icon:Show()
    end
  end

  -- Cache button groups for faster lookup
  local buttonGroups = {
    { name = "pfActionBarMainButton", count = 12 },
    { name = "pfActionBarRightButton", count = 12 },
    { name = "pfActionBarVerticalButton", count = 12 },
    { name = "pfActionBarLeftButton", count = 12 },
    { name = "pfActionBarTopButton", count = 12 },
    { name = "pfActionBarStanceBar1Button", count = 12 },
    { name = "pfActionBarStanceBar2Button", count = 12 },
    { name = "pfActionBarStanceBar3Button", count = 12 },
    { name = "pfActionBarStanceBar4Button", count = 12 },
    { name = "pfActionBarPetButton", count = 10 },
    { name = "pfActionBarStancesButton", count = 10 },
    { name = "pfActionBarPagingButton", count = 12 },
  }

  -- Cache resolved button frames so we don't re-_G lookup every update pass.
  local cachedButtons = {}
  local function GetCachedButton(groupName, index)
    local key = groupName .. index
    local button = cachedButtons[key]
    if not button then
      button = _G[key]
      cachedButtons[key] = button
    end
    return button
  end

  local function UpdateButtons()
    local texture = GetTexture(C.CustomMedia.actionbar_texture)
    local r, g, b, a = GetStringColor(C.CustomMedia.actionbar_color)
    for _, group in ipairs(buttonGroups) do
      for i = 1, group.count do
        local button = GetCachedButton(group.name, i)
        if button then
          ApplyBackground(texture, r, g, b, a, button)
        end
      end
    end
  end

  local function UpdateBags()
    local texture = GetTexture(C.CustomMedia.bags_texture)
    local r, g, b, a = GetStringColor(C.CustomMedia.bags_color)
    for bagIndex = 0, 4 do
      for slotIndex = 1, 36 do
        local button = _G["pfBag" .. bagIndex .. "item" .. slotIndex]
        if button then
          ApplyBackground(texture, r, g, b, a, button)
        end
      end
    end
  end

  local function UpdateBank()
    local texture = GetTexture(C.CustomMedia.bags_texture)
    local r, g, b, a = GetStringColor(C.CustomMedia.bags_color)
    for slotIndex = 1, 24 do
      local button = _G["pfBag-1item" .. slotIndex]
      if button then
        ApplyBackground(texture, r, g, b, a, button)
      end
    end
    for bagIndex = 5, 10 do
      for slotIndex = 1, 36 do
        local button = _G["pfBag" .. bagIndex .. "item" .. slotIndex]
        if button then
          ApplyBackground(texture, r, g, b, a, button)
        end
      end
    end
  end

  local function UpdateAll()
    UpdateButtons()
    UpdateBags()
    if BankFrame and BankFrame:IsShown() then
      UpdateBank()
    end
  end

  -- Delayed update mechanism (Vanilla-compatible)
  local delayFrame = CreateFrame("Frame")
  local delayTime = 1
  local elapsedTime = 0
  delayFrame:Hide()

  delayFrame:SetScript("OnUpdate", function()
    -- Capture arg1 into a local (Classic 1.12-safe).
    local elapsed = arg1 or 0
    elapsedTime = elapsedTime + elapsed
    if elapsedTime >= delayTime then
      UpdateAll()
      delayFrame:Hide()
      elapsedTime = 0
    end
  end)

  local function DelayedUpdate()
    delayFrame:Show()
  end

  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:RegisterEvent("BAG_UPDATE")
  f:RegisterEvent("BANKFRAME_OPENED")
  f:RegisterEvent("BANKFRAME_CLOSED")
  f:RegisterEvent("ADDON_LOADED")

  f:SetScript("OnEvent", function()
    -- Capture event and arg1 into locals (Classic 1.12-safe).
    local event, arg1 = event, arg1

    if event == "PLAYER_ENTERING_WORLD" or (event == "ADDON_LOADED" and arg1 == "pfUI") then
      DelayedUpdate()
      if event == "PLAYER_ENTERING_WORLD" then
        this:UnregisterEvent("PLAYER_ENTERING_WORLD")
      end
    elseif event == "BAG_UPDATE" then
      UpdateBags()
    elseif event == "BANKFRAME_OPENED" then
      UpdateBank()
    elseif event == "BANKFRAME_CLOSED" then
      UpdateBags()
    end
  end)

  -- GUI config
  if type(pfUI.gui.UpdaterFunctions) ~= "table" then
    pfUI.gui.UpdaterFunctions = {}
  end
  pfUI.gui.UpdaterFunctions["CustomMedia"] = function()
    UpdateAll()
    DelayedUpdate()
  end

  if type(pfUI.gui.CreateGUIEntry) == "function" and type(pfUI.gui.CreateConfig) == "function" then
    pfUI.gui.CreateGUIEntry("Thirdparty", "CustomMedia", function()
      -- Action Bar Settings
      pfUI.gui.CreateConfig(pfUI.gui.UpdaterFunctions["CustomMedia"], "Action Bar Background", nil, nil, "header")
      pfUI.gui.CreateConfig(pfUI.gui.UpdaterFunctions["CustomMedia"], "Select Texture", C.CustomMedia, "actionbar_texture", "dropdown", pfUI.gui.dropdowns.CustomMedia_actionbar)
      pfUI.gui.CreateConfig(pfUI.gui.UpdaterFunctions["CustomMedia"], "Pick Color", C.CustomMedia, "actionbar_color", "color")

      -- Bags Settings
      pfUI.gui.CreateConfig(pfUI.gui.UpdaterFunctions["CustomMedia"], "Bags Background", nil, nil, "header")
      pfUI.gui.CreateConfig(pfUI.gui.UpdaterFunctions["CustomMedia"], "Select Texture", C.CustomMedia, "bags_texture", "dropdown", pfUI.gui.dropdowns.CustomMedia_bags)
      pfUI.gui.CreateConfig(pfUI.gui.UpdaterFunctions["CustomMedia"], "Pick Color", C.CustomMedia, "bags_color", "color")
      pfUI.gui.CreateConfig(nil, "Gryphon Position", nil, nil, "header")
      pfUI.gui.CreateConfig(nil, "Reset position", nil, nil, "button", function()
        if pfUI.customMedia and type(pfUI.customMedia.ResetGryphonPosition) == "function" then
          pfUI.customMedia.ResetGryphonPosition()
        end
      end)
    end)
  elseif type(pfUI.gui.tabs) == "table" and type(pfUI.gui.tabs.thirdparty) == "table" and pfUI.gui.tabs.thirdparty.tabs and type(pfUI.gui.tabs.thirdparty.tabs.CreateTabChild) == "function" then
    local tabs = pfUI.gui.tabs.thirdparty.tabs
    tabs.CustomMedia = tabs:CreateTabChild("CustomMedia", true)
    tabs.CustomMedia:SetScript("OnShow", function()
      if not this.setup then
        this.setup = true
        DelayedUpdate()
      end
    end)
  end

  -- Initial update
  DelayedUpdate()
end)
