-- WorldChatFilter - compact Blizzard dropdown settings + circular minimap orb.
-- Uses Vanilla 1.12 UIDropDownMenu globals (no modern Settings API).
local WCF = WorldChatFilter
local menu, anchor, miniButton
local radius = 79

local function getDB()
  if not WCF.db then WCF.Initialize() end
  return WCF.db
end

local function addItem(text, level, func, checked, hasArrow, value)
  local info = UIDropDownMenu_CreateInfo()
  info.text = text
  info.notCheckable = checked == nil
  if checked ~= nil then info.checked = checked and 1 or nil end
  if func then info.func = func end
  if hasArrow then
    info.hasArrow = 1
    info.value = value
    info.notCheckable = 1
  end
  UIDropDownMenu_AddButton(info, level)
end

local function addTitle(text, level)
  local info = UIDropDownMenu_CreateInfo()
  info.text = text
  info.isTitle = 1
  info.notCheckable = 1
  UIDropDownMenu_AddButton(info, level)
end

local function addToggle(text, key, level)
  local db = getDB()
  addItem(text, level, function()
    db[key] = not db[key]
    if key == "customEnabled" and WCF.InvalidateMessageCache then WCF.InvalidateMessageCache() end
    if key == "customEnabled" and WCF.RefreshCustomFiltersUI then WCF.RefreshCustomFiltersUI() end
    if key == "enabled" or key == "tintWorld" then
      if WCF.RefreshWorldColor then WCF.RefreshWorldColor() end
    end
    if WCF.RefreshUI then WCF.RefreshUI() end
  end, db[key] and true or false)
end

-- Vanilla 1.12 normally opens level-3 dropdowns to the right of level 2.
-- When World Chat Color already opened to the left, that would cover level 1.
-- Reposition ONLY this addon's Color Presets submenu after the native click/hover.
local function hookPresetsOpenLeft()
  local parentList = getglobal("DropDownList2")
  if not parentList then return end
  local button = getglobal("DropDownList2Button" .. tostring(parentList.numButtons or 0))
  if not button or button.wcfPresetLeftHooked then return end
  button.wcfPresetLeftHooked = true

  local function positionOnLeft()
    if not menu or UIDROPDOWNMENU_OPEN_MENU ~= menu:GetName() or
       button.value ~= "colorPresets" then return end
    local childList = getglobal("DropDownList3")
    if not childList or not childList:IsShown() then return end
    childList:ClearAllPoints()
    childList:SetPoint("TOPRIGHT", button, "TOPLEFT", -11, 14)
    -- Retain Vanilla's vertical correction if the submenu is too low.
    local bottom = childList:GetBottom()
    if bottom and bottom < 0 then
      childList:ClearAllPoints()
      childList:SetPoint("BOTTOMRIGHT", button, "BOTTOMLEFT", -11, -14)
    end
  end

  local function hookScript(frame, script)
    if not frame then return end
    local nativeScript = frame:GetScript(script)
    frame:SetScript(script, function()
      if nativeScript then nativeScript() end
      positionOnLeft()
    end)
  end

  hookScript(button, "OnEnter")
  local arrow = getglobal(button:GetName() .. "ExpandArrow")
  hookScript(arrow, "OnEnter")
  hookScript(arrow, "OnClick")
end

local function populateMenu(self, level)
  -- Vanilla passes submenu selection through the global value variable.
  level = level or UIDROPDOWNMENU_MENU_LEVEL or 1
  local db = getDB()
  if level == 1 then
    addTitle("World Chat Filter Settings", level)
    addToggle("Enable World Chat Filter", "enabled", level)
    addItem("World Chat Color", level, nil, nil, true, "worldColor")
    addItem("Filter Categories", level, nil, nil, true, "filters")
    addItem("Custom Filters", level, nil, nil, true, "custom")
    addItem("Detection Sensitivity", level, nil, nil, true, "sensitivity")
    addItem("Statistics Panel", level, function() if WCF.ToggleStatsUI then WCF.ToggleStatsUI() end end)
    addItem("Information", level, nil, nil, true, "info")
    addItem("Explain a message: /wcf test <text>", level, function() WCF.Print("Use /wcf test <message> to see why it would be blocked.") end)
    addItem("Help / Commands", level, function() WCF.Help() end)
    addItem("Close", level, function() CloseDropDownMenus() end)
  elseif level == 2 then
    local group = UIDROPDOWNMENU_MENU_VALUE
    if group == "custom" then
      addTitle("Personal World Chat Filters", level)
      addToggle("Enable Custom Filters", "customEnabled", level)
      addItem("Manage Blocked Players & Phrases...", level, function()
        if WCF.ToggleCustomFiltersUI then WCF.ToggleCustomFiltersUI() end
      end)
      addTitle("Blocked players: " .. tostring(table.getn(db.blockedPlayers or {})), level)
      addTitle("Blocked phrases: " .. tostring(table.getn(db.blockedPhrases or {})), level)
    elseif group == "filters" then
      addTitle("World Chat Filters", level)
      addToggle("Trade / WTS / WTB", "filterTrade", level)
      addToggle("LFG / LFM / Rep Farm", "filterLFG", level)
      addToggle("Guild Recruitment", "filterGuild", level)
      addToggle("Services / Professions", "filterServices", level)
      addToggle("Repeated Messages", "filterRepeats", level)
    elseif group == "worldColor" then
      addTitle("World Chat Color", level)
      addToggle("Enable Custom World Color", "tintWorld", level)
      addItem("Color Presets", level, nil, nil, true, "colorPresets")
      hookPresetsOpenLeft()
      addItem("Choose Custom Color...", level, function()
        if WCF.OpenWorldColorPicker then WCF.OpenWorldColorPicker() end
      end)
      addItem("Reset to Dusty Gold", level, function()
        if WCF.ResetWorldColorSelection then WCF.ResetWorldColorSelection() end
      end)
      addTitle("Selected: " .. WCF.GetWorldColorLabel(), level)
    elseif group == "sensitivity" then
      addTitle("Detection Sensitivity", level)
      local function mode(label, key)
        addItem(label, level, function()
          db.sensitivity = key
          WCF.Print("Detection sensitivity: " .. key)
        end, db.sensitivity == key)
      end
      mode("Careful (fewer false positives)", "careful")
      mode("Balanced (recommended)", "balanced")
      mode("Aggressive (more ads hidden)", "aggressive")
    elseif group == "info" then
      addTitle("World Chat Filter v" .. WCF.VERSION, level)
      addTitle("World filter: " .. (db.enabled and "ON" or "OFF"), level)
      addTitle("World tint: " .. ((db.tintWorld and db.enabled) and "ON" or "OFF"), level)
      addTitle("World color: " .. WCF.GetWorldColorLabel(), level)
      addTitle("Sensitivity: " .. (db.sensitivity or "balanced"), level)
      addTitle("Hidden this session: " .. WCF.sessionHidden, level)
      addItem("Print Status to Chat", level, function() WCF.Status() end)
      addItem("Reset Session Statistics", level, function()
        if WCF.ResetSessionStats then WCF.ResetSessionStats() end
      end)
      addTitle("Shift + drag minimap icon to move", level)
    end
  elseif level == 3 then
    if UIDROPDOWNMENU_MENU_VALUE == "colorPresets" then
      addTitle("Color Presets", level)
      local _, preset
      for _, preset in ipairs(WCF.COLOR_PRESETS or {}) do
        local presetID = preset.id
        -- Native Vanilla color swatch: a small solid square shows the actual
        -- preset, instead of printing a #RRGGBB code in the menu label.
        local info = UIDropDownMenu_CreateInfo()
        info.text = preset.label
        info.checked = WCF.GetWorldColorPreset and WCF.GetWorldColorPreset() == presetID
        info.notCheckable = false
        info.hasColorSwatch = 1
        info.r, info.g, info.b = preset.r, preset.g, preset.b
        info.hasOpacity = nil
        info.func = function()
          if WCF.SelectWorldColorPreset then WCF.SelectWorldColorPreset(presetID) end
        end
        -- Clicking the square itself can open Blizzard's picker. Changes are
        -- saved as Custom; Cancel restores the selection from menu-opening.
        local formerPreset = WCF.GetWorldColorPreset and WCF.GetWorldColorPreset()
        local formerR, formerG, formerB = WCF.GetWorldColorRGB()
        info.swatchFunc = function()
          if ColorPickerFrame and ColorPickerFrame.GetColorRGB and WCF.SetCustomWorldColor then
            local r, g, b = ColorPickerFrame:GetColorRGB()
            WCF.SetCustomWorldColor(r, g, b)
          end
        end
        info.cancelFunc = function()
          if formerPreset == "custom" then
            if WCF.SetCustomWorldColor then
              WCF.SetCustomWorldColor(formerR, formerG, formerB)
            end
          elseif formerPreset and WCF.SelectWorldColorPreset then
            WCF.SelectWorldColorPreset(formerPreset)
          end
        end
        UIDropDownMenu_AddButton(info, level)
      end
    end
  end
end

function WCF.RefreshUI()
  -- The dropdown is built from live DB values every time it opens.
end

local function positionMinimapButton()
  if not miniButton or not Minimap then return end
  local angle = tonumber(getDB().minimapAngle) or 225
  local radians = math.rad(angle)
  miniButton:ClearAllPoints()
  miniButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(radians) * radius, math.sin(radians) * radius)
end

local function trackDrag()
  if not miniButton or not Minimap or not GetCursorPosition then return end
  local scale = UIParent:GetEffectiveScale() or 1
  if scale == 0 then scale = 1 end
  local cursorX, cursorY = GetCursorPosition()
  local centerX, centerY = Minimap:GetCenter()
  if not cursorX or not centerX then return end
  local dx = cursorX / scale - centerX
  local dy = cursorY / scale - centerY
  local angle = math.deg(math.atan2(dy, dx))
  getDB().minimapAngle = angle
  positionMinimapButton()
end

function WCF.ToggleUI(fromButton)
  if not menu then WCF.BuildUI() end
  if not menu then return end
  -- A hidden centered anchor is used for /wcf; clicking the orb anchors to it.
  local target = fromButton or anchor
  ToggleDropDownMenu(1, nil, menu, target:GetName(), 0, 0)
end

function WCF.BuildUI()
  if menu then return end
  menu = CreateFrame("Frame", "WorldChatFilterSettingsDropdown", UIParent, "UIDropDownMenuTemplate")
  UIDropDownMenu_Initialize(menu, populateMenu, "MENU")

  anchor = CreateFrame("Frame", "WorldChatFilterMenuAnchor", UIParent)
  anchor:SetWidth(1)
  anchor:SetHeight(1)
  anchor:SetPoint("CENTER", UIParent, "CENTER", -140, 155)

  if not Minimap then return end
  miniButton = CreateFrame("Button", "WorldChatFilterMinimapButton", Minimap)
  miniButton:SetWidth(32)
  miniButton:SetHeight(32)
  miniButton:SetFrameStrata("MEDIUM")
  miniButton:SetFrameLevel(Minimap:GetFrameLevel() + 5)
  miniButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  miniButton:RegisterForDrag("LeftButton")

  -- Single centered orb texture (64x64 TGA, drawn at 32x32) has its own gold border.
  -- Never layer MiniMap-TrackingBorder: that asset has offset atlas pixels
  -- and displays a second, empty ring next to the actual button on 1.18.
  local icon = miniButton:CreateTexture(nil, "ARTWORK")
  icon:SetWidth(32)
  icon:SetHeight(32)
  icon:SetPoint("CENTER", miniButton, "CENTER", 0, 0)
  icon:SetTexture("Interface\\AddOns\\WorldChatFilter\\Media\\WorldChatFilterOrb")

  miniButton:SetScript("OnClick", function()
    if miniButton.didDrag then
      miniButton.didDrag = nil
      return
    end
    WCF.ToggleUI(miniButton)
  end)
  miniButton:SetScript("OnDragStart", function()
    if IsShiftKeyDown and IsShiftKeyDown() then
      miniButton.didDrag = true
      miniButton:SetScript("OnUpdate", trackDrag)
    end
  end)
  miniButton:SetScript("OnDragStop", function()
    miniButton:SetScript("OnUpdate", nil)
  end)
  miniButton:SetScript("OnEnter", function()
    GameTooltip:SetOwner(miniButton, "ANCHOR_LEFT")
    GameTooltip:SetText("World Chat Filter")
    GameTooltip:AddLine("Click for settings", 1, 1, 1)
    GameTooltip:AddLine("Shift + drag to reposition", 0.65, 0.85, 1)
    GameTooltip:Show()
  end)
  miniButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
  positionMinimapButton()
end
