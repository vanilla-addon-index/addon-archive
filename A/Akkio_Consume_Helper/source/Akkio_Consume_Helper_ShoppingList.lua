-- Akkio's Consume Helper - Shopping List Module
-- This file handles the shopping list functionality for low consumables

-- ============================================================================
-- SHOPPING LIST CORE FUNCTIONALITY
-- ============================================================================

-- Global table for shopping list data
if not Akkio_Consume_Helper_Shopping then
  Akkio_Consume_Helper_Shopping = {}
end

-- Initialize shopping list settings in the main saved variables
local function InitializeShoppingListSettings()
  if not Akkio_Consume_Helper_Settings.shoppingList then
    Akkio_Consume_Helper_Settings.shoppingList = {
      enabled = true,
      thresholds = {
        -- Category-based thresholds for consistent duration items
        flasks = 2,        -- Alert when < 2 flasks
        elixirs = 5,       -- Alert when < 5 elixirs  
        food = 10,         -- Alert when < 10 food items
        weaponEnchants = 3, -- Alert when < 3 weapon enchants
        other = 10         -- Default for other consumables (fallback)
      },
      -- Individual item thresholds for "other" category items
      individualThresholds = {
        -- Will be populated with items like:
        -- ["Juju Power"] = 4,
        -- ["Winterfall Firewater"] = 15,
        -- ["Gift of Arthas"] = 4,
      },
      autoUpdate = true,    -- Automatically update shopping list when bag contents change
      showInTooltip = true, -- Show shopping list info in tooltips
      alertOnLogin = true,  -- Show shopping list alert when logging in with low items
      -- Window position settings
      windowPositions = {
        shoppingList = {
          point = "CENTER",
          relativeTo = "UIParent",
          relativePoint = "CENTER",
          xOffset = 250,
          yOffset = 0
        },
        settings = {
          point = "CENTER",
          relativeTo = "UIParent", 
          relativePoint = "CENTER",
          xOffset = 400,
          yOffset = 0
        }
      }
    }
  else
    -- Update existing settings if needed (for version compatibility)
    if not Akkio_Consume_Helper_Settings.shoppingList.thresholds then
      Akkio_Consume_Helper_Settings.shoppingList.thresholds = {
        flasks = 2,
        elixirs = 5,
        food = 10,
        weaponEnchants = 3,
        other = 10
      }
    else
      -- Force update the "other" threshold if it's still 5 (old default)
      if Akkio_Consume_Helper_Settings.shoppingList.thresholds.other == 5 then
        Akkio_Consume_Helper_Settings.shoppingList.thresholds.other = 10
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00Akkio Shopping List:|r Updated 'other' category threshold from 5 to 10")
      end
    end
    
    -- Initialize individual thresholds table if it doesn't exist
    if not Akkio_Consume_Helper_Settings.shoppingList.individualThresholds then
      Akkio_Consume_Helper_Settings.shoppingList.individualThresholds = {}
    end
    
    -- Initialize window positions if they don't exist
    if not Akkio_Consume_Helper_Settings.shoppingList.windowPositions then
      Akkio_Consume_Helper_Settings.shoppingList.windowPositions = {
        shoppingList = {
          point = "CENTER",
          relativeTo = "UIParent",
          relativePoint = "CENTER",
          xOffset = 250,
          yOffset = 0
        },
        settings = {
          point = "CENTER",
          relativeTo = "UIParent", 
          relativePoint = "CENTER",
          xOffset = 400,
          yOffset = 0
        }
      }
    end
  end
end

-- Shopping list frame reference
local shoppingListFrame = nil

-- ============================================================================
-- POSITION SAVING UTILITY FUNCTIONS
-- ============================================================================

-- Function to save window position (simplified and safe like main file)
local function SaveWindowPosition(frame, positionKey)
  if not frame or not positionKey then return end
  
  local point, relativeTo, relativePoint, xOffset, yOffset = frame:GetPoint()
  if point then
    local settings = Akkio_Consume_Helper_Settings.shoppingList.windowPositions
    settings[positionKey] = {
      point = point,
      relativeTo = "UIParent", -- Always use UIParent as string for consistency
      relativePoint = relativePoint,
      xOffset = xOffset,
      yOffset = yOffset
    }
  end
end

-- Function to restore window position (simplified and safe like main file)
local function RestoreWindowPosition(frame, positionKey)
  if not frame or not positionKey then return end
  
  local settings = Akkio_Consume_Helper_Settings.shoppingList.windowPositions
  local pos = settings and settings[positionKey]
  
  if pos then
    frame:ClearAllPoints()
    frame:SetPoint(pos.point, pos.relativeTo, pos.relativePoint, pos.xOffset, pos.yOffset)
  end
end

-- ============================================================================
-- ITEM CATEGORIZATION & THRESHOLD MANAGEMENT
-- ============================================================================

-- Function to determine item category for threshold purposes
local function GetItemCategory(buffData)
  if not buffData then return "other" end
  
  -- Check for weapon enchants first
  if buffData.isWeaponEnchant then
    return "weaponEnchants"
  end
  
  -- Find which section this item belongs to by looking at the data table
  local allBuffs = Akkio_Consume_Helper_Data.allBuffs
  local currentSection = "other"
  
  -- Disable debug logging by default
  -- DEFAULT_CHAT_FRAME:AddMessage("DEBUG: Looking for item: " .. (buffData.name or "nil"))
  
  for _, buff in ipairs(allBuffs) do
    if buff.header then
      -- Update current section based on header
      local headerName = string.lower(buff.name)
      if string.find(headerName, "flask") then
        currentSection = "flasks"
      elseif string.find(headerName, "food") then
        currentSection = "food"
      elseif string.find(headerName, "weapon") then
        currentSection = "weaponEnchants"
      elseif string.find(headerName, "elixir") then
        currentSection = "elixirs" -- This section has both elixirs and non-elixirs
      else
        currentSection = "other"
      end
      -- DEFAULT_CHAT_FRAME:AddMessage("DEBUG: Header '" .. buff.name .. "' -> section: " .. currentSection)
    elseif buff.name == buffData.name then
      -- Found our item, now determine if it should use the section or be "other"
      -- DEFAULT_CHAT_FRAME:AddMessage("DEBUG: Found item '" .. buff.name .. "' in section: " .. currentSection)
      if currentSection == "elixirs" then
        -- Check if it's actually an elixir or should be "other"
        local itemName = string.lower(buffData.name or "")
        if string.find(itemName, "elixir") or string.find(itemName, "mageblood") or string.find(itemName, "dreamshard") then
          -- DEFAULT_CHAT_FRAME:AddMessage("DEBUG: '" .. buffData.name .. "' categorized as elixirs")
          return "elixirs"
        else
          -- Juju, Winterfall Firewater, Gift of Arthas, etc.
          -- DEFAULT_CHAT_FRAME:AddMessage("DEBUG: '" .. buffData.name .. "' categorized as other (from elixir section)")
          return "other"
        end
      else
        -- For other sections, use the section directly
        -- DEFAULT_CHAT_FRAME:AddMessage("DEBUG: '" .. buffData.name .. "' categorized as: " .. currentSection)
        return currentSection
      end
    end
  end
  
  -- Default fallback
  -- DEFAULT_CHAT_FRAME:AddMessage("DEBUG: '" .. (buffData.name or "nil") .. "' not found, defaulting to other")
  return "other"
end

-- Function to get threshold for a specific item
local function GetItemThreshold(buffData)
  local category = GetItemCategory(buffData)
  
  -- For "other" category items, check if there's an individual threshold first
  if category == "other" and buffData.name then
    local individualThreshold = Akkio_Consume_Helper_Settings.shoppingList.individualThresholds[buffData.name]
    if individualThreshold then
      return individualThreshold
    end
    
    -- If no individual threshold set, calculate based on duration
    if buffData.duration then
      local gameplayHours = 2
      local gameplayMinutes = gameplayHours * 60
      local itemDurationMinutes = buffData.duration / 60
      
      if itemDurationMinutes > 0 then
        local calculatedThreshold = math.ceil(gameplayMinutes / itemDurationMinutes)
        calculatedThreshold = math.max(3, math.min(20, calculatedThreshold))
        
        -- Auto-save this calculated threshold as individual threshold
        Akkio_Consume_Helper_Settings.shoppingList.individualThresholds[buffData.name] = calculatedThreshold
        
        return calculatedThreshold
      end
    end
  end
  
  -- Use category-based threshold
  local categoryThreshold = Akkio_Consume_Helper_Settings.shoppingList.thresholds[category] or 5
  return categoryThreshold
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Function to find item amount in bags (adapted from main addon)
local function findItemInBags(itemName)
  local totalAmount = 0
  for bag = 0, 4 do -- 0 = backpack, 1–4 = bags
    local bagSlots = GetContainerNumSlots(bag)
    if bagSlots and bagSlots > 0 then
      for slot = 1, bagSlots do
        local itemLink = GetContainerItemLink(bag, slot)
        if itemLink then
          -- Extract item name from link, handling items with charges
          local _, _, linkItemName = string.find(itemLink, "%[(.-)%]")
          -- Remove charge information if present (e.g., "Brilliant Wizard Oil (5)" -> "Brilliant Wizard Oil")
          if linkItemName then
            linkItemName = string.gsub(linkItemName, " %(%d+%)$", "")
            if linkItemName == itemName then
              local _, itemCount = GetContainerItemInfo(bag, slot)
              -- Handle charged items (negative count) vs stacked items (positive count)
              if itemCount then
                if itemCount < 0 then
                  -- Charged item: count represents charges remaining, convert to positive
                  totalAmount = totalAmount + math.abs(itemCount)
                else
                  -- Regular stacked item: count represents stack size
                  totalAmount = totalAmount + itemCount
                end
              end
            end
          end
        end
      end
    end
  end
  return totalAmount
end

-- ============================================================================
-- SHOPPING LIST DATA GENERATION
-- ============================================================================

-- Function to scan enabled buffs and generate shopping list
local function GenerateShoppingList()
  if not Akkio_Consume_Helper_Settings.shoppingList.enabled then
    return {}
  end
  
  local shoppingList = {}
  local enabledBuffs = Akkio_Consume_Helper_Settings.enabledBuffs or {}
  
  -- Access the buff data from the main data file
  local allBuffs = Akkio_Consume_Helper_Data.allBuffs
  
  for _, enabledBuffName in ipairs(enabledBuffs) do
    -- Handle weapon enchant naming (name_slot format)
    local actualName = enabledBuffName
    local slot = nil
    
    if string.find(enabledBuffName, "_mainhand") then
      actualName = string.gsub(enabledBuffName, "_mainhand", "")
      slot = "mainhand"
    elseif string.find(enabledBuffName, "_offhand") then
      actualName = string.gsub(enabledBuffName, "_offhand", "")
      slot = "offhand"
    end
    
    -- Find the buff data
    for _, buff in ipairs(allBuffs) do
      if not buff.header and buff.name == actualName then
        -- Skip class buffs that can't be purchased (they are cast by other players)
        if buff.canBeAnounced == true then
          -- This is a class buff, skip it
          break
        end
        
        -- For weapon enchants, check if slots match
        if buff.isWeaponEnchant and slot and buff.slot == slot then
          -- Found matching weapon enchant
          local currentAmount = findItemInBags(buff.name)
          local threshold = GetItemThreshold(buff)
          
          if currentAmount < threshold then
            table.insert(shoppingList, {
              name = buff.name,
              slot = slot,
              currentAmount = currentAmount,
              threshold = threshold,
              needed = threshold - currentAmount,
              category = GetItemCategory(buff),
              icon = buff.icon,
              isWeaponEnchant = true
            })
          end
          break
        elseif not buff.isWeaponEnchant and not slot then
          -- Found matching regular consumable
          local currentAmount = findItemInBags(buff.name)
          local threshold = GetItemThreshold(buff)
          
          if currentAmount < threshold then
            table.insert(shoppingList, {
              name = buff.name,
              currentAmount = currentAmount,
              threshold = threshold,
              needed = threshold - currentAmount,
              category = GetItemCategory(buff),
              icon = buff.icon,
              isWeaponEnchant = false
            })
          end
          break
        end
      end
    end
  end
  
  -- Sort shopping list by priority (category) and then by name
  local categoryPriority = {
    flasks = 1,
    elixirs = 2,
    weaponEnchants = 3,
    food = 4,
    other = 5
  }
  
  table.sort(shoppingList, function(a, b)
    local aPriority = categoryPriority[a.category] or 5
    local bPriority = categoryPriority[b.category] or 5
    
    if aPriority == bPriority then
      return a.name < b.name
    end
    return aPriority < bPriority
  end)
  
  return shoppingList
end

-- ============================================================================
-- SHOPPING LIST UI
-- ============================================================================

-- Function to create the shopping list UI
local function BuildShoppingListUI()
  if shoppingListFrame then
    shoppingListFrame:Show()
    return
  end
  
  local frameWidth = 450 --increased width to accommodate all elements
  local frameHeight = 500
  
  shoppingListFrame = CreateFrame("Frame", "AkkioShoppingListFrame", UIParent)
  shoppingListFrame:SetWidth(frameWidth)
  shoppingListFrame:SetHeight(frameHeight)
  
  -- Restore saved position or use default
  RestoreWindowPosition(shoppingListFrame, "shoppingList")
  if not shoppingListFrame:GetPoint() then
    shoppingListFrame:SetPoint("CENTER", UIParent, "CENTER", 250, 0) -- Default position
  end
  
  shoppingListFrame:SetFrameStrata("DIALOG")
  shoppingListFrame:SetFrameLevel(60)
  shoppingListFrame:SetMovable(true)
  shoppingListFrame:EnableMouse(true)
  shoppingListFrame:RegisterForDrag("LeftButton")
  shoppingListFrame:SetScript("OnDragStart", function() shoppingListFrame:StartMoving() end)
  shoppingListFrame:SetScript("OnDragStop", function() 
    shoppingListFrame:StopMovingOrSizing()
    SaveWindowPosition(shoppingListFrame, "shoppingList")
  end)
  shoppingListFrame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 8,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
  })
  shoppingListFrame:SetBackdropColor(0.05, 0.15, 0.1, 0.95) -- Dark green theme
  shoppingListFrame:SetBackdropBorderColor(0.5, 0.8, 0.5, 1) -- Light green border
  
  shoppingListFrame:Hide() -- Hidden by default

  -- Title
  local title = shoppingListFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", shoppingListFrame, "TOP", 0, -16)
  title:SetText("Shopping List - Low Consumables")
  title:SetTextColor(0.5, 1, 0.5, 1) -- Light green

  -- Close button (X) in top-right corner
  local closeXButton = CreateFrame("Button", nil, shoppingListFrame)
  closeXButton:SetWidth(30)
  closeXButton:SetHeight(30)
  closeXButton:SetPoint("TOPRIGHT", shoppingListFrame, "TOPRIGHT", -15, -15)
  closeXButton:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
  closeXButton:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
  closeXButton:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
  closeXButton:SetScript("OnClick", function()
    shoppingListFrame:Hide()
  end)
  
  -- Tooltip for X button
  closeXButton:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:AddLine("Close Shopping List", 1, 1, 1, 1)
    GameTooltip:AddLine("You can also press Escape", 0.7, 0.7, 0.7, 1)
    GameTooltip:Show()
  end)
  closeXButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  -- Refresh button
  local refreshButton = CreateFrame("Button", nil, shoppingListFrame, "UIPanelButtonTemplate")
  refreshButton:SetWidth(80)
  refreshButton:SetHeight(25)
  refreshButton:SetPoint("TOP", title, "BOTTOM", 0, -10)
  refreshButton:SetText("Refresh")
  refreshButton:SetScript("OnClick", function()
    UpdateShoppingListDisplay()
  end)

  -- Content area for shopping list items with scroll frame
  local scrollFrame = CreateFrame("ScrollFrame", "AkkioShoppingScrollFrame", shoppingListFrame)
  scrollFrame:SetPoint("TOPLEFT", shoppingListFrame, "TOPLEFT", 20, -80)  -- Absolute positioning from main frame
  scrollFrame:SetPoint("BOTTOMRIGHT", shoppingListFrame, "BOTTOMRIGHT", -25, 60) -- Full width usage
  
  -- Add border to scroll frame for alignment debugging
  scrollFrame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 8,
    edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
  })
  scrollFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.2) -- Very dark, semi-transparent background
  scrollFrame:SetBackdropBorderColor(0.5, 0.8, 1, 0.8) -- Light blue border for visibility
  
  -- Create scroll bar manually for better compatibility
  local scrollbar = CreateFrame("Slider", "AkkioShoppingScrollBar", scrollFrame, "UIPanelScrollBarTemplate")
  scrollbar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 4, -16)
  scrollbar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 4, 16)
  scrollbar:SetMinMaxValues(1, 1)
  scrollbar:SetValueStep(1)
  scrollbar.scrollStep = 20
  scrollbar:SetValue(0)
  scrollbar:SetWidth(16)
  scrollbar:SetScript("OnValueChanged", function()
    scrollFrame:SetVerticalScroll(this:GetValue())
  end)
  
  -- Enable mouse wheel scrolling with explicit event handling
  scrollFrame:EnableMouseWheel(true)
  scrollFrame:SetScript("OnMouseWheel", function()
    local scrollbar = getglobal("AkkioShoppingScrollBar")
    local step = scrollbar.scrollStep or 20
    local value = scrollbar:GetValue()
    local minVal, maxVal = scrollbar:GetMinMaxValues()

    if arg1 > 0 then
      value = math.max(minVal, value - step)
    else
      value = math.min(maxVal, value + step)
    end

    scrollbar:SetValue(value)
  end)
  
  -- Create the content frame that will hold all the items
  shoppingListFrame.contentFrame = CreateFrame("Frame", nil, scrollFrame)
  shoppingListFrame.contentFrame:SetWidth(scrollFrame:GetWidth())
  shoppingListFrame.contentFrame:SetHeight(1) -- Will be resized dynamically
  scrollFrame:SetScrollChild(shoppingListFrame.contentFrame)
  
  -- Settings button
  local settingsButton = CreateFrame("Button", nil, shoppingListFrame, "UIPanelButtonTemplate")
  settingsButton:SetWidth(120)
  settingsButton:SetHeight(25)
  settingsButton:SetPoint("BOTTOMLEFT", shoppingListFrame, "BOTTOMLEFT", 20, 20)
  settingsButton:SetText("Threshold Settings")
  settingsButton:SetScript("OnClick", function()
    BuildShoppingListSettingsUI()
  end)

  -- Close button
  local closeButton = CreateFrame("Button", nil, shoppingListFrame, "UIPanelButtonTemplate")
  closeButton:SetWidth(80)
  closeButton:SetHeight(25)
  closeButton:SetPoint("BOTTOMRIGHT", shoppingListFrame, "BOTTOMRIGHT", -20, 20)
  closeButton:SetText("Close")
  closeButton:SetScript("OnClick", function()
    shoppingListFrame:Hide()
  end)

  -- Initial content update
  UpdateShoppingListDisplay()
end

-- Function to update the shopping list display
function UpdateShoppingListDisplay()
  if not shoppingListFrame or not shoppingListFrame.contentFrame then
    return
  end
  
  -- Clear existing content
  local children = {shoppingListFrame.contentFrame:GetChildren()}
  for _, child in ipairs(children) do
    child:Hide()
    child:SetParent(nil)
  end
  
  local shoppingList = GenerateShoppingList()
  
  if table.getn(shoppingList) == 0 then
    -- No items needed - show success message
    local noItemsLabel = shoppingListFrame.contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    noItemsLabel:SetPoint("CENTER", shoppingListFrame.contentFrame, "CENTER", 0, 0)
    noItemsLabel:SetText("✓ All consumables well stocked!")
    noItemsLabel:SetTextColor(0.5, 1, 0.5, 1) -- Light green
    
    -- Set content frame height for empty state
    shoppingListFrame.contentFrame:SetHeight(100)
    
    -- Update scrollbar for empty state
    local scrollbar = getglobal("AkkioShoppingScrollBar")
    if scrollbar then
      scrollbar:SetMinMaxValues(0, 0)
      scrollbar:SetValue(0)
    end
    return
  end
  
  -- Calculate total height needed for all items
  local itemHeight = 36
  local totalHeight = table.getn(shoppingList) * itemHeight
  shoppingListFrame.contentFrame:SetHeight(totalHeight)
  
  -- Display shopping list items
  local yOffset = 0
  for i, item in ipairs(shoppingList) do
    -- Create item frame
    local itemFrame = CreateFrame("Frame", nil, shoppingListFrame.contentFrame)
    itemFrame:SetWidth(shoppingListFrame.contentFrame:GetWidth() - 20) -- Account for scrollbar
    itemFrame:SetHeight(itemHeight)
    itemFrame:SetPoint("TOPLEFT", shoppingListFrame.contentFrame, "TOPLEFT", 0, yOffset)
    
    -- Item icon
    local icon = CreateFrame("Button", nil, itemFrame)
    icon:SetWidth(24)
    icon:SetHeight(24)
    icon:SetPoint("LEFT", itemFrame, "LEFT", 10, 0)  -- Proper margin inside frame
    icon:SetNormalTexture(item.icon)
    
    -- Item name and details
    local nameLabel = itemFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("LEFT", icon, "RIGHT", 8, 4)
    nameLabel:SetWidth(280) -- Increased width for longer item names
    nameLabel:SetJustifyH("LEFT")
    
    local itemText = item.name
    if item.isWeaponEnchant then
      itemText = itemText .. " (" .. (item.slot == "mainhand" and "MH" or "OH") .. ")"
    end
    nameLabel:SetText(itemText)
    nameLabel:SetTextColor(1, 1, 1, 1)
    
    -- Amount needed
    local amountLabel = itemFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    amountLabel:SetPoint("LEFT", icon, "RIGHT", 8, -8)
    amountLabel:SetWidth(280) -- Increased width to match name label
    amountLabel:SetJustifyH("LEFT")
    amountLabel:SetText("Need " .. item.needed .. " more (have " .. item.currentAmount .. "/" .. item.threshold .. ")")
    amountLabel:SetTextColor(1, 0.8, 0.2, 1) -- Orange
    
    -- Category badge
    local categoryLabel = itemFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    categoryLabel:SetPoint("RIGHT", itemFrame, "RIGHT", 120, 0)  -- More space from edge
    categoryLabel:SetWidth(100) -- Wider category badge area
    categoryLabel:SetJustifyH("RIGHT")
    categoryLabel:SetText("[" .. string.upper(item.category) .. "]")
    
    -- Color code by category
    if item.category == "flasks" then
      categoryLabel:SetTextColor(1, 0.4, 1, 1) -- Purple
    elseif item.category == "elixirs" then
      categoryLabel:SetTextColor(0.4, 0.8, 1, 1) -- Blue
    elseif item.category == "weaponEnchants" then
      categoryLabel:SetTextColor(1, 0.6, 0.2, 1) -- Orange
    elseif item.category == "food" then
      categoryLabel:SetTextColor(0.8, 1, 0.4, 1) -- Green
    else
      categoryLabel:SetTextColor(0.8, 0.8, 0.8, 1) -- Gray
    end
    
    yOffset = yOffset - itemHeight
  end
  
  -- Update scroll range for our custom scroll bar
  local scrollFrame = getglobal("AkkioShoppingScrollFrame")
  local scrollbar = getglobal("AkkioShoppingScrollBar")
  if scrollFrame and scrollbar then
    local scrollFrameHeight = scrollFrame:GetHeight()
    local maxScroll = math.max(0, totalHeight - scrollFrameHeight)
    scrollbar:SetMinMaxValues(0, maxScroll)
    scrollbar.scrollStep = math.max(1, maxScroll / 10) -- 10% steps for smooth scrolling
    scrollbar:SetValue(0) -- Reset to top when content updates
  end
end

-- ============================================================================
-- SHOPPING LIST SETTINGS UI
-- ============================================================================

local shoppingListSettingsFrame = nil

function BuildShoppingListSettingsUI()
  if shoppingListSettingsFrame then
    shoppingListSettingsFrame:Show()
    return
  end
  
  local frameWidth = 500
  local frameHeight = 600
  
  shoppingListSettingsFrame = CreateFrame("Frame", "AkkioShoppingListSettingsFrame", UIParent)
  shoppingListSettingsFrame:SetWidth(frameWidth)
  shoppingListSettingsFrame:SetHeight(frameHeight)
  
  -- Restore saved position or use default
  RestoreWindowPosition(shoppingListSettingsFrame, "settings")
  if not shoppingListSettingsFrame:GetPoint() then
    shoppingListSettingsFrame:SetPoint("CENTER", UIParent, "CENTER", 400, 0) -- Default position
  end
  
  shoppingListSettingsFrame:SetFrameStrata("DIALOG")
  shoppingListSettingsFrame:SetFrameLevel(70)
  shoppingListSettingsFrame:SetMovable(true)
  shoppingListSettingsFrame:EnableMouse(true)
  shoppingListSettingsFrame:RegisterForDrag("LeftButton")
  shoppingListSettingsFrame:SetScript("OnDragStart", function() shoppingListSettingsFrame:StartMoving() end)
  shoppingListSettingsFrame:SetScript("OnDragStop", function() 
    shoppingListSettingsFrame:StopMovingOrSizing()
    SaveWindowPosition(shoppingListSettingsFrame, "settings")
  end)
  shoppingListSettingsFrame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 8,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
  })
  shoppingListSettingsFrame:SetBackdropColor(0.1, 0.1, 0.15, 0.95)
  shoppingListSettingsFrame:SetBackdropBorderColor(0.7, 0.7, 0.9, 1)
  
  -- Title
  local title = shoppingListSettingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", shoppingListSettingsFrame, "TOP", 0, -16)
  title:SetText("Shopping List Threshold Settings")
  title:SetTextColor(0.9, 0.9, 1, 1)
  
  local yOffset = -50
  
  -- Category Thresholds Section
  local categoryHeader = shoppingListSettingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  categoryHeader:SetPoint("TOPLEFT", shoppingListSettingsFrame, "TOPLEFT", 20, yOffset)
  categoryHeader:SetText("Category Thresholds:")
  categoryHeader:SetTextColor(0.8, 1, 0.8, 1)
  yOffset = yOffset - 25
  
  -- Category threshold controls
  local categories = {
    {key = "flasks", name = "Flasks", color = {1, 0.4, 1}},
    {key = "elixirs", name = "Elixirs", color = {0.4, 0.8, 1}},
    {key = "food", name = "Food", color = {0.8, 1, 0.4}},
    {key = "weaponEnchants", name = "Weapon Enchants", color = {1, 0.6, 0.2}},
    {key = "other", name = "Other (Fallback)", color = {0.8, 0.8, 0.8}}
  }
  
  for _, category in ipairs(categories) do
    -- Capture category data in local variables to avoid scope issues
    local categoryKey = category.key
    local categoryName = category.name
    local categoryColor = category.color
    
    -- Category label
    local label = shoppingListSettingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", shoppingListSettingsFrame, "TOPLEFT", 30, yOffset)
    label:SetText(categoryName .. ":")
    label:SetTextColor(categoryColor[1], categoryColor[2], categoryColor[3], 1)
    
    -- Edit box for threshold value
    local editBox = CreateFrame("EditBox", nil, shoppingListSettingsFrame)
    editBox:SetWidth(60)
    editBox:SetHeight(20)
    editBox:SetPoint("TOPLEFT", shoppingListSettingsFrame, "TOPLEFT", 300, yOffset + 3)
    editBox:SetAutoFocus(false)
    editBox:SetNumeric(true)
    editBox:SetMaxLetters(3)
    editBox:SetText(tostring(Akkio_Consume_Helper_Settings.shoppingList.thresholds[categoryKey] or 5))
    
    -- Set up backdrop manually for compatibility
    editBox:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true,
      tileSize = 8,
      edgeSize = 8,
      insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    editBox:SetBackdropColor(0.2, 0.2, 0.2, 0.9)
    editBox:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    
    -- Set up font
    editBox:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    editBox:SetTextColor(1, 1, 1, 1)
    editBox:SetJustifyH("CENTER")
    
    -- Enable interaction
    editBox:EnableMouse(true)
    editBox:EnableKeyboard(true)
    editBox:Show()
    
    -- Save the threshold when focus is lost
    editBox:SetScript("OnEditFocusLost", function()
      local currentText = editBox:GetText()
      local value = tonumber(currentText) or 5
      value = math.max(1, math.min(99, value)) -- Clamp between 1-99
      
      -- Update the saved value using captured variables
      local thresholds = Akkio_Consume_Helper_Settings.shoppingList.thresholds
      if thresholds then
        thresholds[categoryKey] = value
        editBox:SetText(tostring(value))
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00Shopping List:|r Updated " .. categoryName .. " threshold to " .. value)
      end
    end)
    
    yOffset = yOffset - 30
  end
  
  yOffset = yOffset - 10
  
  -- Individual Items Section
  local individualHeader = shoppingListSettingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  individualHeader:SetPoint("TOPLEFT", shoppingListSettingsFrame, "TOPLEFT", 20, yOffset)
  individualHeader:SetText("Individual Item Thresholds:")
  individualHeader:SetTextColor(0.8, 1, 0.8, 1)
  yOffset = yOffset - 25
  
  -- Scroll frame for individual items
  local scrollFrame = CreateFrame("ScrollFrame", "AkkioSettingsScrollFrame", shoppingListSettingsFrame)
  scrollFrame:SetPoint("TOPLEFT", shoppingListSettingsFrame, "TOPLEFT", 20, yOffset)
  scrollFrame:SetPoint("BOTTOMRIGHT", shoppingListSettingsFrame, "BOTTOMRIGHT", -40, 60)
  
  -- Add border to settings scroll frame for alignment debugging
  scrollFrame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 8,
    edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
  })
  scrollFrame:SetBackdropColor(0.05, 0.05, 0.1, 0.3) -- Very dark purple, semi-transparent background
  scrollFrame:SetBackdropBorderColor(0.8, 0.5, 1, 0.8) -- Light purple border for visibility
  
  -- Create scroll bar
  local scrollbar = CreateFrame("Slider", "AkkioSettingsScrollBar", scrollFrame, "UIPanelScrollBarTemplate")
  scrollbar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 4, -16)
  scrollbar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 4, 16)
  scrollbar:SetMinMaxValues(1, 1)
  scrollbar:SetValueStep(1)
  scrollbar.scrollStep = 20
  scrollbar:SetValue(0)
  scrollbar:SetWidth(16)
  scrollbar:SetScript("OnValueChanged", function()
    scrollFrame:SetVerticalScroll(scrollbar:GetValue())
  end)
  
  -- Enable mouse wheel scrolling
  scrollFrame:EnableMouseWheel(true)
  scrollFrame:SetScript("OnMouseWheel", function()
    local scrollbar = getglobal("AkkioSettingsScrollBar")
    local step = scrollbar.scrollStep or 20
    local value = scrollbar:GetValue()
    local minVal, maxVal = scrollbar:GetMinMaxValues()

    if arg1 > 0 then
      value = math.max(minVal, value - step)
    else
      value = math.min(maxVal, value + step)
    end

    scrollbar:SetValue(value)
  end)
  
  -- Content frame for individual items with proper width
  local contentFrame = CreateFrame("Frame", nil, scrollFrame)
  contentFrame:SetWidth(420) -- Fixed width to ensure elements fit properly
  scrollFrame:SetScrollChild(contentFrame)
  
  -- Function to refresh individual items list
  local function RefreshIndividualItems()
    -- Clear existing content
    local children = {contentFrame:GetChildren()}
    for _, child in ipairs(children) do
      child:Hide()
      child:SetParent(nil)
    end
    
    local individualThresholds = Akkio_Consume_Helper_Settings.shoppingList.individualThresholds
    local itemList = {}
    
    -- Convert to sortable list - just show what's in individualThresholds
    for itemName, threshold in pairs(individualThresholds) do
      table.insert(itemList, {name = itemName, threshold = threshold})
    end
    
    -- Sort alphabetically
    table.sort(itemList, function(a, b) return a.name < b.name end)
    
    local itemHeight = 30
    local totalHeight = table.getn(itemList) * itemHeight
    contentFrame:SetHeight(math.max(200, totalHeight))
    
    local yPos = 0
    for i, item in ipairs(itemList) do
      -- Capture item data in local variables to avoid scope issues
      local itemName = item.name
      local itemThreshold = item.threshold
      
      -- Item frame
      local itemFrame = CreateFrame("Frame", nil, contentFrame)
      itemFrame:SetWidth(contentFrame:GetWidth())
      itemFrame:SetHeight(itemHeight)
      itemFrame:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, yPos)
      
      -- Debug: Add a background to make the frame visible
      itemFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = nil,
        tile = false,
        tileSize = 0,
        edgeSize = 0,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
      })
      itemFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.3) -- Very subtle background
      
      -- Item name
      local nameLabel = itemFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      nameLabel:SetPoint("LEFT", itemFrame, "LEFT", 10, 0)
      nameLabel:SetWidth(250)
      nameLabel:SetJustifyH("LEFT")
      nameLabel:SetText(itemName)
      nameLabel:SetTextColor(0.9, 0.9, 0.9, 1)
      
      -- Threshold edit box with better visibility and positioning
      local thresholdBox = CreateFrame("EditBox", nil, itemFrame)
      thresholdBox:SetWidth(60)
      thresholdBox:SetHeight(20)
      thresholdBox:SetPoint("LEFT", itemFrame, "LEFT", 280, 0) -- Use LEFT anchor for better control
      thresholdBox:SetAutoFocus(false)
      thresholdBox:SetNumeric(true)
      thresholdBox:SetMaxLetters(3)
      thresholdBox:SetText(tostring(itemThreshold))
      thresholdBox:SetFrameLevel(itemFrame:GetFrameLevel() + 5) -- Higher frame level
      
      -- Set up backdrop manually for compatibility
      thresholdBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
      })
      thresholdBox:SetBackdropColor(0.2, 0.2, 0.2, 0.9) -- More opaque background
      thresholdBox:SetBackdropBorderColor(0.5, 0.5, 0.5, 1) -- Add border for visibility
      
      -- Set up font for the edit box
      thresholdBox:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
      thresholdBox:SetTextColor(1, 1, 1, 1)
      thresholdBox:SetJustifyH("CENTER")
      
      -- Make sure the edit box is visible and functional
      thresholdBox:Show()
      thresholdBox:EnableMouse(true)
      thresholdBox:EnableKeyboard(true)
      
      thresholdBox:SetScript("OnEditFocusLost", function()
        local currentText = thresholdBox:GetText()
        local value = tonumber(currentText) or 1
        value = math.max(1, math.min(99, value))
        
        -- Update the saved value using the captured itemName
        local itemThresholds = Akkio_Consume_Helper_Settings.shoppingList.individualThresholds
        if itemThresholds then
          itemThresholds[itemName] = value
          thresholdBox:SetText(tostring(value))
          DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00Shopping List:|r Updated " .. itemName .. " threshold to " .. value)
        end
      end)
      
      -- Also save on Enter key
      thresholdBox:SetScript("OnEnterPressed", function()
        local currentText = thresholdBox:GetText()
        local value = tonumber(currentText) or 1
        value = math.max(1, math.min(99, value))
        
        -- Update the saved value using the captured itemName
        local itemThresholds = Akkio_Consume_Helper_Settings.shoppingList.individualThresholds
        if itemThresholds then
          itemThresholds[itemName] = value
          thresholdBox:SetText(tostring(value))
          thresholdBox:ClearFocus()
          DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00Shopping List:|r Updated " .. itemName .. " threshold to " .. value)
        end
      end)
      
      -- Reset to auto button - positioned after the edit box
      local resetButton = CreateFrame("Button", nil, itemFrame, "UIPanelButtonTemplate")
      resetButton:SetWidth(50)
      resetButton:SetHeight(20)
      resetButton:SetPoint("LEFT", thresholdBox, "RIGHT", 10, 0) -- Position relative to edit box
      resetButton:SetText("Auto")
      resetButton:SetFrameLevel(itemFrame:GetFrameLevel() + 5) -- Same level as edit box
      resetButton:SetScript("OnClick", function()
        -- Find the buff data to recalculate using the captured itemName
        local allBuffs = Akkio_Consume_Helper_Data.allBuffs
        
        for _, buff in ipairs(allBuffs) do
          if buff.name == itemName and buff.duration then
            local gameplayMinutes = 120 -- 2 hours
            local itemDurationMinutes = buff.duration / 60
            local autoThreshold = math.max(3, math.min(20, math.ceil(gameplayMinutes / itemDurationMinutes)))
            
            -- Update the saved value using the captured itemName
            local itemThresholds = Akkio_Consume_Helper_Settings.shoppingList.individualThresholds
            if itemThresholds then
              itemThresholds[itemName] = autoThreshold
              thresholdBox:SetText(tostring(autoThreshold))
              DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00Shopping List:|r Auto-calculated " .. itemName .. " threshold: " .. autoThreshold)
            end
            break
          end
        end
      end)
      
      yPos = yPos - itemHeight
    end
    
    -- Update scroll range
    local scrollFrameHeight = scrollFrame:GetHeight()
    local maxScroll = math.max(0, totalHeight - scrollFrameHeight)
    scrollbar:SetMinMaxValues(0, maxScroll)
    scrollbar.scrollStep = math.max(1, maxScroll / 10)
    scrollbar:SetValue(0)
    
    if table.getn(itemList) == 0 then
      local noItemsLabel = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      noItemsLabel:SetPoint("CENTER", contentFrame, "CENTER", 0, 0)
      noItemsLabel:SetText("No individual thresholds needed.\nAll enabled items use category defaults.")
      noItemsLabel:SetTextColor(0.6, 0.6, 0.6, 1)
      contentFrame:SetHeight(200)
    end
  end
  
  -- Initial population
  RefreshIndividualItems()
  
  -- Populate All button (to make all "other" items visible for editing)
  local populateButton = CreateFrame("Button", nil, shoppingListSettingsFrame, "UIPanelButtonTemplate")
  populateButton:SetWidth(100)
  populateButton:SetHeight(25)
  populateButton:SetPoint("BOTTOM", shoppingListSettingsFrame, "BOTTOM", 40, 20)
  populateButton:SetText("Populate All")
  populateButton:SetScript("OnClick", function()
    -- Force populate all "other" category items and also any items without clear category
    local enabledBuffs = Akkio_Consume_Helper_Settings.enabledBuffs or {}
    local allBuffs = Akkio_Consume_Helper_Data.allBuffs
    local individualThresholds = Akkio_Consume_Helper_Settings.shoppingList.individualThresholds
    local addedCount = 0
    
    for _, enabledBuffName in ipairs(enabledBuffs) do
      local actualName = enabledBuffName
      -- Remove weapon slot suffixes
      if string.find(enabledBuffName, "_mainhand") then
        actualName = string.gsub(enabledBuffName, "_mainhand", "")
      elseif string.find(enabledBuffName, "_offhand") then
        actualName = string.gsub(enabledBuffName, "_offhand", "")
      end
      
      -- Find buff data
      for _, buff in ipairs(allBuffs) do
        if not buff.header and buff.name == actualName then
          -- Skip weapon enchants and class buffs
          if not buff.isWeaponEnchant and buff.canBeAnounced ~= true then
            -- Check if this item would be categorized as "other" OR force add common consumables
            local category = GetItemCategory(buff)
            local isCommonConsumable = (
              string.find(string.lower(buff.name), "juju") or
              string.find(string.lower(buff.name), "winterfall") or
              string.find(string.lower(buff.name), "gift of arthas") or
              string.find(string.lower(buff.name), "crystal") or
              string.find(string.lower(buff.name), "brilliant") or
              category == "other"
            )
            
            if isCommonConsumable then
              -- Add to individual thresholds if not already present
              if not individualThresholds[buff.name] then
                if buff.duration then
                  local gameplayMinutes = 120 -- 2 hours
                  local itemDurationMinutes = buff.duration / 60
                  local autoThreshold = math.max(3, math.min(20, math.ceil(gameplayMinutes / itemDurationMinutes)))
                  individualThresholds[buff.name] = autoThreshold
                else
                  individualThresholds[buff.name] = 10 -- Default for items without duration
                end
                addedCount = addedCount + 1
              end
            end
          end
          break
        end
      end
    end
    
    RefreshIndividualItems()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00Shopping List:|r Populated " .. addedCount .. " individual thresholds")
  end)
  
  -- Save button to refresh main shopping list
  local saveButton = CreateFrame("Button", nil, shoppingListSettingsFrame, "UIPanelButtonTemplate")
  saveButton:SetWidth(80)
  saveButton:SetHeight(25)
  saveButton:SetPoint("BOTTOMLEFT", shoppingListSettingsFrame, "BOTTOMLEFT", 20, 20)
  saveButton:SetText("Save")
  saveButton:SetScript("OnClick", function()
    -- Close the settings window first to resolve frame conflicts
    shoppingListSettingsFrame:Hide()
    
    -- Then refresh the shopping list with new settings
    if shoppingListFrame and shoppingListFrame.contentFrame and UpdateShoppingListDisplay then
      UpdateShoppingListDisplay()
      DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00Shopping List:|r Settings saved and shopping list refreshed!")
    else
      DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00Shopping List:|r Settings saved!")
    end
  end)
  
  -- Reset All button (now just resets to auto-calculated values)
  local resetAllButton = CreateFrame("Button", nil, shoppingListSettingsFrame, "UIPanelButtonTemplate")
  resetAllButton:SetWidth(100)
  resetAllButton:SetHeight(25)
  resetAllButton:SetPoint("BOTTOM", shoppingListSettingsFrame, "BOTTOM", -60, 20)
  resetAllButton:SetText("Reset to Auto")
  resetAllButton:SetScript("OnClick", function()
    -- Recalculate all thresholds instead of clearing them
    local individualThresholds = Akkio_Consume_Helper_Settings.shoppingList.individualThresholds
    local allBuffs = Akkio_Consume_Helper_Data.allBuffs
    
    for itemName, _ in pairs(individualThresholds) do
      for _, buff in ipairs(allBuffs) do
        if buff.name == itemName and buff.duration then
          local gameplayMinutes = 120 -- 2 hours
          local itemDurationMinutes = buff.duration / 60
          local autoThreshold = math.max(3, math.min(20, math.ceil(gameplayMinutes / itemDurationMinutes)))
          individualThresholds[itemName] = autoThreshold
          break
        end
      end
    end
    
    RefreshIndividualItems()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00Shopping List:|r Reset all individual thresholds to auto-calculated values")
  end)
  
  -- Close button
  local closeButton = CreateFrame("Button", nil, shoppingListSettingsFrame, "UIPanelButtonTemplate")
  closeButton:SetWidth(80)
  closeButton:SetHeight(25)
  closeButton:SetPoint("BOTTOMRIGHT", shoppingListSettingsFrame, "BOTTOMRIGHT", -20, 20)
  closeButton:SetText("Close")
  closeButton:SetScript("OnClick", function()
    shoppingListSettingsFrame:Hide()
  end)
end

-- ============================================================================
-- INTEGRATION & INITIALIZATION
-- ============================================================================

-- Function to add shopping list button to main settings UI
function AddShoppingListButtonToSettings()
  -- This will be called from the main file to integrate with existing settings UI
  -- TODO: Add shopping list button to main settings panel
end

-- Function to initialize shopping list on addon load
function InitializeShoppingList()
  InitializeShoppingListSettings()
  
  -- Register slash command
  SLASH_ACTSHOPPING1 = "/actshopping"
  SLASH_ACTSHOPPING2 = "/actshop"
  SlashCmdList["ACTSHOPPING"] = function(msg)
    if not shoppingListFrame then
      BuildShoppingListUI()
    end
    if shoppingListFrame then
      shoppingListFrame:Show()
    end
  end
  
  DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00Akkio Shopping List:|r Type /actshopping or /actshop to open shopping list")
end

-- ============================================================================
-- EXTERNAL INTERFACE
-- ============================================================================

-- Make key functions available to main addon
Akkio_Consume_Helper_Shopping.Initialize = InitializeShoppingList
Akkio_Consume_Helper_Shopping.BuildUI = BuildShoppingListUI
Akkio_Consume_Helper_Shopping.UpdateDisplay = UpdateShoppingListDisplay
Akkio_Consume_Helper_Shopping.GenerateList = GenerateShoppingList
