pfUI.addonskinner:RegisterSkin("Outfitter", function()
  local penv = pfUI:GetEnvironment()
  local StripTextures, CreateBackdrop = penv.StripTextures, penv.CreateBackdrop

  local ICON_INSET = -2
  local SetAllPointsOffset = penv.SetAllPointsOffset

  -- Outfitter QuickSlots skin: apply pfUI backdrops, crop icons, and color per-slot borders by item quality

  local function skinSlotName(name)
    local btn = _G[name]
    if not btn or btn._pfuiSkinned then return end
    StripTextures(btn, true)
    CreateBackdrop(btn, ICON_INSET)

    -- capture icon before we clear blizzard textures
    local icon = _G[name .. "Icon"] or _G[name .. "IconTexture"] or (btn.GetNormalTexture and btn:GetNormalTexture())

    -- clear and neutralize Blizzard-provided normal/highlight textures so they don't reappear when the slot is updated
    if btn.SetNormalTexture then
      btn:SetNormalTexture("")
      btn.SetNormalTexture = function() return end
    end
    if btn.GetNormalTexture then
      local nt = btn:GetNormalTexture()
      if nt and nt.SetTexture then nt:SetTexture("") end
    end
    if btn.SetHighlightTexture then
      btn:SetHighlightTexture("")
      btn.SetHighlightTexture = function() return end
    end
    -- clear and block pushed textures (this prevents the pressed highlight border)
    if btn.SetPushedTexture then
      btn:SetPushedTexture("")
      btn.SetPushedTexture = function() return end
    end
    if btn.GetPushedTexture then
      local pt = btn:GetPushedTexture()
      if pt and pt.SetTexture then pt:SetTexture("") end
      if pt and pt.Hide then pt:Hide() end
    end

    -- ensure slot backdrop and its border are positioned above the quickslots parent
    local parentLvl = (OutfitterQuickSlots and OutfitterQuickSlots:GetFrameLevel()) or (btn:GetParent() and btn:GetParent():GetFrameLevel()) or 0
    if btn.backdrop and btn.backdrop.SetFrameLevel then btn.backdrop:SetFrameLevel(parentLvl + 1) end
    if btn.backdrop and btn.backdrop.SetDrawLayer then btn.backdrop:SetDrawLayer("BORDER", 0) end
    if btn.backdrop_border and btn.backdrop_border.SetFrameLevel then btn.backdrop_border:SetFrameLevel(parentLvl + 2) end

    if icon and icon.SetTexCoord then
      icon:SetTexCoord(.07, .93, .07, .93)
      icon:SetParent(btn)
      if btn.backdrop and SetAllPointsOffset then
        -- inset by 1 px so the border remains visible
        SetAllPointsOffset(icon, btn.backdrop, ICON_INSET + 4)
      else
        icon:SetAllPoints(btn)
      end
      if icon.SetDrawLayer then icon:SetDrawLayer("OVERLAY", 300) end
      -- raise icon above any backdrop border (use the highest available framelevel)
      do
        local base = (btn.backdrop and btn.backdrop.GetFrameLevel and btn.backdrop:GetFrameLevel()) or btn:GetFrameLevel() or 0
        if btn.backdrop_border and btn.backdrop_border.GetFrameLevel then
          local b = btn.backdrop_border:GetFrameLevel()
          if b > base then base = b end
        end
        if icon.SetFrameLevel then icon:SetFrameLevel(base + 3) end
      end

      -- ensure texcoords persist if texture gets changed later
      if hooksecurefunc and icon.SetTexture then
        hooksecurefunc(icon, "SetTexture", function(self)
          self:SetTexCoord(.07, .93, .07, .93)
        end)
      end
    end

    btn._pfuiSkinned = true
  end

  local Skin = function()
    -- skin quickslots parent and a small grid of possible children (minimal & explicit)
    if OutfitterQuickSlots then
      StripTextures(OutfitterQuickSlots, true, "BACKGROUND")
      CreateBackdrop(OutfitterQuickSlots, nil, true, .75)

      -- hide Outfitter's segmented background textures (they show through when the frame grows)
      local function hideQuickBacks()
        for i=0,26 do local f=_G["OutfitterQuickSlotsBack"..i] if f and f.Hide then f:Hide() end end
        for _,n in ipairs({"OutfitterQuickSlotsBackStart1","OutfitterQuickSlotsBackStart2","OutfitterQuickSlotsBackEnd1","OutfitterQuickSlotsBackEnd2","OutfitterQuickSlotsBackEnd"}) do local f=_G[n] if f and f.Hide then f:Hide() end end
      end
      hideQuickBacks()

      local function updateSlot(name, parentIndex)
        skinSlotName(name)
        -- ensure Blizzard textures are not restored when Outfitter populates the slot
        local btn = _G[name]
        if btn then
          if btn.SetNormalTexture then btn:SetNormalTexture("") end
          if btn.GetNormalTexture then local nt = btn:GetNormalTexture(); if nt and nt.SetTexture then nt:SetTexture("") end end
          if btn.GetHighlightTexture then local ht = btn:GetHighlightTexture(); if ht and ht.SetTexture then ht:SetTexture("") end end
        end

        -- determine bag/slot from the parent quickslot container
        local parent = _G["OutfitterQuickSlotsItem"..(parentIndex or 0)]
        if parent and parent.GetID and btn and btn.GetID then
          local bag = parent:GetID()
          local slot = btn:GetID()
          if bag and slot then
            local _, _, _, quality = GetContainerItemInfo(bag, slot)
            if quality then
              local r,g,b = GetItemQualityColor(quality)
              if btn.backdrop and btn.backdrop.SetBackdropBorderColor then btn.backdrop:SetBackdropBorderColor(r,g,b,1) end
              return
            end
          end
        end

        if btn and btn.backdrop and btn.backdrop.SetBackdropBorderColor then btn.backdrop:SetBackdropBorderColor(0,0,0,1) end
      end

      -- skin a fixed range of quickslot children (minimal & explicit)
for i=1,27 do
  for j=1,2 do
    updateSlot("OutfitterQuickSlotsItem"..i.."Item"..j, i)
  end
end

      -- lightweight hooks: re-hide backgrounds and refresh slots when Outfitter updates
      if hooksecurefunc then
        hooksecurefunc("OutfitterQuickSlots_SetNumSlots", function(pNum)
          hideQuickBacks()
          for i=1,(pNum or 0) do
              for j=1,2 do
                updateSlot("OutfitterQuickSlotsItem"..i.."Item"..j, i)
              end
            end
        end)
        hooksecurefunc("OutfitterQuickSlots_SetSlotToBag", function(index, b, s)
          updateSlot("OutfitterQuickSlotsItem"..index.."Item1", index)
        end)

        -- also hook the global ContainerFrame_Update so we refresh per-slot quality borders
        -- anytime Blizzard updates the slot frame (covers moves/unequips that modify container state)
        hooksecurefunc("ContainerFrame_Update", function(frame)
          -- accept either a frame object or a frame name string
          if not frame then return end
          local fname
          if type(frame) == "string" then
            fname = frame
          elseif type(frame) == "table" and frame.GetName then
            fname = frame:GetName()
          end
          if not fname then return end
          local _, _, parentIndex = string.find(fname, "^OutfitterQuickSlotsItem(%d+)$")
          if parentIndex then
            parentIndex = tonumber(parentIndex)
            for j=1,2 do
              local childName = fname .. "Item" .. j
              updateSlot(childName, parentIndex)
            end
          end
        end)
      end
    end
  end

  if not OutfitterCurrentOutfit then
    local orig_Outfitter_PEW = Outfitter_PlayerEnteringWorld

    Outfitter_PlayerEnteringWorld = function(self, event)
      orig_Outfitter_PEW(self, event)
      Skin()
    end
  else
    Skin()
  end 

  pfUI.addonskinner:UnregisterSkin("Outfitter")
end)
