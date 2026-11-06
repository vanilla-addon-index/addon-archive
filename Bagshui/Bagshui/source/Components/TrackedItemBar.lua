-- Bagshui Tracked Item Bar
-- Exposes: Bagshui.components.TrackedItemBar
--
-- A small movable bar that shows the items you've chosen to track along with how many of each
-- you have in your bags (handy as a farming counter). Track or stop tracking an item from its
-- item menu (Alt+right-click > Manage), or Alt+click a button on the bar to stop tracking it.
-- Click a button to use the item, Shift+drag to move the bar.
--
-- Inspired by the Tracked Item Bar in Guda <https://github.com/vatichild/guda>.
-- The list of tracked items and the bar's position are stored per character.

Bagshui:AddComponent(function()
  local TrackedItemBar = {
    buttons = {},
    updatePending = false,
    updateAfter = 0,
  }
  Bagshui.components.TrackedItemBar = TrackedItemBar

  local BUTTON_SPACING = -3
  local BAR_PADDING = 4
  local UPDATE_DELAY = 0.15
  local FALLBACK_TEXTURE = "Interface\\Icons\\INV_Misc_QuestionMark"

  local frame

  --- Get the list of tracked items for the current character.
  --- Each entry is `{ id = <itemId>, texture = <icon path> }`.
  ---@return table? trackedItems
  local function GetTrackedItems()
    local characterData = Bagshui.currentCharacterData
    if not characterData then
      return nil
    end
    if type(characterData.trackedItems) ~= "table" then
      characterData.trackedItems = {}
    end
    return characterData.trackedItems
  end

  --- Extract the numeric item ID from an item link.
  ---@param link string?
  ---@return number? itemId
  local function ItemIdFromLink(link)
    if not link then
      return nil
    end
    local _, _, itemId = string.find(link, "item:(%d+)")
    return itemId and tonumber(itemId) or nil
  end

  --- Is the given item being tracked?
  ---@param itemId number
  ---@return boolean
  function TrackedItemBar:IsTracked(itemId)
    local tracked = GetTrackedItems()
    if not tracked or not itemId then
      return false
    end
    for _, entry in ipairs(tracked) do
      if entry.id == itemId then
        return true
      end
    end
    return false
  end

  --- Start or stop tracking an item.
  ---@param itemId number
  ---@param texture string? Icon path to remember so the button looks right when none are in the bags.
  function TrackedItemBar:Toggle(itemId, texture)
    local tracked = GetTrackedItems()
    if not tracked or not itemId or itemId <= 0 then
      return
    end

    for index, entry in ipairs(tracked) do
      if entry.id == itemId then
        table.remove(tracked, index)
        self:Update()
        return
      end
    end

    table.insert(tracked, { id = itemId, texture = texture })
    self:Update()
  end

  --- Find the first bag slot that holds the given item.
  ---@param itemId number
  ---@return number? bagNum
  ---@return number? slotNum
  local function FindItemInBags(itemId)
    for bagNum = 0, 4 do
      for slotNum = 1, (_G.GetContainerNumSlots(bagNum) or 0) do
        if ItemIdFromLink(_G.GetContainerItemLink(bagNum, slotNum)) == itemId then
          return bagNum, slotNum
        end
      end
    end
    return nil, nil
  end

  --- Save the bar position for the current character.
  local function SavePosition()
    local point, _, relativePoint, x, y = frame:GetPoint()
    if Bagshui.currentCharacterData and point then
      Bagshui.currentCharacterData.trackedItemBarPosition = {
        point = point,
        relativePoint = relativePoint,
        x = x,
        y = y,
      }
    end
  end

  --- Handlers shared by the buttons. Each button gets its own closures from CreateButton().
  local function StartMoving()
    if _G.IsShiftKeyDown() and not _G.CursorHasItem() then
      frame:StartMoving()
      frame.isMoving = true
    end
  end

  local function StopMoving()
    if frame.isMoving then
      frame:StopMovingOrSizing()
      frame.isMoving = false
      SavePosition()
    end
  end

  --- Create one of the item buttons.
  ---@param index number
  ---@return table button
  local function CreateButton(index)
    local button = _G.CreateFrame("Button", "BagshuiTrackedItemBarButton" .. index, frame)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    button.icon = button:CreateTexture(nil, "BACKGROUND")
    -- Inset the icon so the border doesn't overlap it.
    button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -4)
    button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 4)
    button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)

    button:SetBackdrop({
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      edgeSize = 12,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    button:SetBackdropBorderColor(1, 1, 1, 1)

    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    button:GetHighlightTexture():SetBlendMode("ADD")

    button:SetScript("OnMouseDown", function()
      if _G.arg1 == "LeftButton" then
        StartMoving()
      end
    end)
    button:SetScript("OnMouseUp", function()
      if _G.arg1 == "LeftButton" then
        StopMoving()
      end
    end)

    button:SetScript("OnClick", function()
      local itemId = _G.this.itemId
      if not itemId or frame.isMoving then
        return
      end

      if _G.IsAltKeyDown() and _G.arg1 == "LeftButton" then
        -- Stop tracking.
        TrackedItemBar:Toggle(itemId)
      elseif not _G.IsShiftKeyDown() and not _G.CursorHasItem() then
        -- Using an item while a vendor is open would sell it.
        if _G.MerchantFrame and _G.MerchantFrame:IsVisible() then
          return
        end
        local bagNum, slotNum = FindItemInBags(itemId)
        if bagNum then
          _G.UseContainerItem(bagNum, slotNum)
        end
      end
    end)

    button:SetScript("OnEnter", function()
      local itemId = _G.this.itemId
      if not itemId then
        return
      end
      _G.GameTooltip:SetOwner(_G.this, "ANCHOR_RIGHT")
      local bagNum, slotNum = FindItemInBags(itemId)
      if bagNum then
        _G.GameTooltip:SetBagItem(bagNum, slotNum)
      else
        _G.GameTooltip:SetHyperlink("item:" .. itemId .. ":0:0:0")
      end
      _G.GameTooltip:AddLine(" ")
      _G.GameTooltip:AddLine(
        string.format(Bagshui.environment.L.TrackedItemBar_InBags, _G.this.itemCount or 0),
        1,
        1,
        1
      )
      _G.GameTooltip:AddLine(Bagshui.environment.L.TrackedItemBar_Hint, 0.6, 0.6, 0.6)
      _G.GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
      _G.GameTooltip:Hide()
    end)

    return button
  end

  --- Count tracked items in the bags with a single pass and refresh the buttons.
  function TrackedItemBar:Update(sizeOverride, showOverride, orientationOverride)
    if not frame then
      return
    end

    local tracked = GetTrackedItems()
    local settings = Bagshui.environment.BsSettings
    local numTracked = tracked and table.getn(tracked) or 0

    local showBar = showOverride
    if showBar == nil and settings then
      showBar = settings.showTrackedItemBar
    end
    if numTracked == 0 or not showBar then
      frame:Hide()
      return
    end

    -- Single pass over the bags.
    local counts = {}
    local textures = {}
    for _, entry in ipairs(tracked) do
      counts[entry.id] = 0
    end
    for bagNum = 0, 4 do
      for slotNum = 1, (_G.GetContainerNumSlots(bagNum) or 0) do
        local itemId = ItemIdFromLink(_G.GetContainerItemLink(bagNum, slotNum))
        if itemId and counts[itemId] then
          local texture, itemCount = _G.GetContainerItemInfo(bagNum, slotNum)
          counts[itemId] = counts[itemId] + (itemCount or 1)
          textures[itemId] = texture
        end
      end
    end

    local vertical = (orientationOverride or (settings and settings.trackedItemBarOrientation)) == "VERTICAL"
    local buttonSize = tonumber(sizeOverride) or tonumber(settings.trackedItemBarSize) or 36

    for index, entry in ipairs(tracked) do
      local button = self.buttons[index]
      if not button then
        button = CreateButton(index)
        self.buttons[index] = button
      end

      -- Remember the icon so the button keeps looking right when none are in the bags.
      local texture = textures[entry.id]
      if not texture then
        local _, _, _, _, _, _, _, _, infoTexture = _G.GetItemInfo(entry.id)
        texture = infoTexture
      end
      if texture then
        entry.texture = texture
      end

      button.itemId = entry.id
      button.itemCount = counts[entry.id]
      button.icon:SetTexture(entry.texture or FALLBACK_TEXTURE)
      button.icon:SetVertexColor(1, 1, 1, 1)
      button.count:SetText(counts[entry.id])
      if counts[entry.id] == 0 then
        button.icon:SetVertexColor(0.4, 0.4, 0.4, 1)
        button.count:SetText("|cffff4040" .. 0 .. "|r")
      end

      button:SetWidth(buttonSize)
      button:SetHeight(buttonSize)
      button:ClearAllPoints()
      local offset = BAR_PADDING + (index - 1) * (buttonSize + BUTTON_SPACING)
      if vertical then
        button:SetPoint("TOP", frame, "TOP", 0, -offset)
      else
        button:SetPoint("LEFT", frame, "LEFT", offset, 0)
      end
      button:Show()
    end

    -- Hide buttons for items that are no longer tracked.
    for index = numTracked + 1, table.getn(self.buttons) do
      self.buttons[index]:Hide()
      self.buttons[index].itemId = nil
    end

    local length = BAR_PADDING * 2 + numTracked * (buttonSize + BUTTON_SPACING) - BUTTON_SPACING
    local thickness = buttonSize + BAR_PADDING * 2
    if vertical then
      frame:SetWidth(thickness)
      frame:SetHeight(length)
    else
      frame:SetWidth(length)
      frame:SetHeight(thickness)
    end
    frame:Show()
  end

  --- Update soon, but not more than once per burst of BAG_UPDATE events.
  function TrackedItemBar:QueueUpdate()
    if self.updatePending then
      return
    end
    self.updatePending = true
    self.updateAfter = _G.GetTime() + UPDATE_DELAY
  end

  -- Build the frame and start listening.
  frame = _G.CreateFrame("Frame", "BagshuiTrackedItemBar", _G.UIParent)
  frame:SetWidth(40)
  frame:SetHeight(44)
  frame:SetFrameStrata("MEDIUM")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:SetClampedToScreen(true)
  frame:SetPoint("BOTTOM", _G.UIParent, "BOTTOM", 0, 200)
  frame:Hide()
  frame:SetScript("OnMouseDown", function()
    if _G.arg1 == "LeftButton" then
      StartMoving()
    end
  end)
  frame:SetScript("OnMouseUp", function()
    if _G.arg1 == "LeftButton" then
      StopMoving()
    end
  end)

  local savedPosition = Bagshui.currentCharacterData and Bagshui.currentCharacterData.trackedItemBarPosition
  if savedPosition and savedPosition.point then
    frame:ClearAllPoints()
    frame:SetPoint(
      savedPosition.point,
      _G.UIParent,
      savedPosition.relativePoint or savedPosition.point,
      savedPosition.x or 0,
      savedPosition.y or 0
    )
  end

  -- The frame that listens for events is separate so it keeps running while the bar is hidden.
  local eventFrame = _G.CreateFrame("Frame", "BagshuiTrackedItemBarEvents", _G.UIParent)
  eventFrame:RegisterEvent("BAG_UPDATE")
  eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
  eventFrame:SetScript("OnEvent", function()
    TrackedItemBar:QueueUpdate()
  end)
  eventFrame:SetScript("OnUpdate", function()
    if TrackedItemBar.updatePending and _G.GetTime() >= TrackedItemBar.updateAfter then
      TrackedItemBar.updatePending = false
      TrackedItemBar:Update()
    end
  end)

  TrackedItemBar:QueueUpdate()
end)
