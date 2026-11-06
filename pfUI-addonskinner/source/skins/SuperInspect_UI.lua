pfUI.addonskinner:RegisterSkin("SuperInspect_UI", function()
  -- upvalue the pfUI methods we use to avoid repeated lookups
  local penv = pfUI:GetEnvironment()
  local StripTextures, CreateBackdrop, SkinCloseButton, SkinButton, SkinArrowButton, 
    SkinCheckbox, SkinCollapseButton, SetAllPointsOffset, SetHighlight, SkinScrollbar, 
    HookScript, hooksecurefunc, SkinDropDown, SkinSlider, HandleIcon, HookAddonOrVariable, GetStringColor = 
  penv.StripTextures, penv.CreateBackdrop, penv.SkinCloseButton, penv.SkinButton, penv.SkinArrowButton, 
  penv.SkinCheckbox, penv.SkinCollapseButton, penv.SetAllPointsOffset, penv.SetHighlight, penv.SkinScrollbar, 
  penv.HookScript, penv.hooksecurefunc, penv.SkinDropDown, penv.SkinSlider, penv.HandleIcon, penv.HookAddonOrVariable, penv.GetStringColor

  local function applySkin()
    StripTextures(SuperInspectFrameHeader)
  StripTextures(SuperInspectFrame)
  CreateBackdrop(SuperInspectFrame, nil, nil, .75)
  StripTextures(SuperInspect_InRangeFrame)
  CreateBackdrop(SuperInspect_InRangeFrame, nil, nil, .75)
  SuperInspect_InRangeFrame:SetPoint("TOP", 0, 105)
  SuperInspect_InRangeFrame:SetHeight(30)
  SuperInspect_InRangeFrame_Text:SetPoint("TOP", 0, 0)
  SuperInspect_InRangeFrame_Text2:SetPoint("TOP", 0, -18)
  SkinCloseButton(SuperInspectFrameHeader_CloseButton, SuperInspectFrame.backdrop, -6, -6)

  SkinArrowButton(SIButton, "right", 20)
  StripTextures(SuperInspect_ItemBonusesFrame)
  CreateBackdrop(SuperInspect_ItemBonusesFrame, nil, nil, .75)
  SkinArrowButton(SuperInspect_CompareButton, "right", 16)
  StripTextures(SuperInspect_COHBonusesFrame)
  CreateBackdrop(SuperInspect_COHBonusesFrame, nil, nil, .75)
  StripTextures(SuperInspect_USEBonusesFrame)
  CreateBackdrop(SuperInspect_USEBonusesFrame, nil, nil, .75)
  StripTextures(SuperInspect_SnTBonusesFrame)
  CreateBackdrop(SuperInspect_SnTBonusesFrame, nil, nil, .75)

  StripTextures(SuperInspect_HonorFrameProgressBar)
  CreateBackdrop(SuperInspect_HonorFrameProgressBar, nil, nil, .9)
  StripTextures(SuperInspect_HonorFrameProgressBarBG)
  SuperInspect_HonorFrameProgressBar:SetStatusBarTexture("Interface\\AddOns\\pfUI\\img\\bar")
  StripTextures(SuperInspect_HonorFrameProgressButton)
  CreateBackdrop(SuperInspect_HonorFrameProgressButton, nil, nil, .25)

  StripTextures(SuperInspect_ItemBonusesFrameCompare)
  CreateBackdrop(SuperInspect_ItemBonusesFrameCompare, nil, nil, .75)
  SuperInspect_ItemBonusesFrameCompare:ClearAllPoints()
  SuperInspect_ItemBonusesFrameCompare:SetPoint("TOPLEFT", SuperInspectFrame.backdrop, "TOPRIGHT", 1, -81)
  SkinCloseButton(SuperInspect_ItemBonusesFrameCompare_CloseButton, SuperInspect_ItemBonusesFrameCompare.backdrop, -6, -6)
  SkinButton(SuperInspect_Button_ShowHonor)
  SkinButton(SuperInspect_Button_ShowBonuses)
  SkinButton(SuperInspect_Button_ShowMobInfo)
  SkinButton(SuperInspect_Button_ShowItems)

  SuperInspect_BonusFrameParent:SetPoint("TOP", 0, -25)
  SuperInspect_HonorFrame:SetPoint("TOP", 0, -2)
  StripTextures(SuperInspect_BonusFrameParentTab1)
  CreateBackdrop(SuperInspect_BonusFrameParentTab1, nil, nil, .75)
  SuperInspect_BonusFrameParentTab1:SetHeight(16)
  StripTextures(SuperInspect_BonusFrameParentTab2)
  CreateBackdrop(SuperInspect_BonusFrameParentTab2, nil, nil, .75)
  SuperInspect_BonusFrameParentTab2:SetHeight(16)
  StripTextures(SuperInspect_BonusFrameParentTab3)
  CreateBackdrop(SuperInspect_BonusFrameParentTab3, nil, nil, .75)
  SuperInspect_BonusFrameParentTab3:SetHeight(16)
  StripTextures(SuperInspect_BonusFrameParentTab4)
  CreateBackdrop(SuperInspect_BonusFrameParentTab4, nil, nil, .75)
  SuperInspect_BonusFrameParentTab4:SetHeight(16)
	
  StripTextures(SuperInspect_HonorFrame)
  CreateBackdrop(SuperInspect_HonorFrame, nil, nil, .75)
  -- ensure HonorFrame backdrop sits above the model/background art
  if SuperInspect_HonorFrame.backdrop and SuperInspectFrame and SuperInspectFrame.backdrop then
    SuperInspect_HonorFrame.backdrop:SetFrameStrata("DIALOG")
    SuperInspect_HonorFrame.backdrop:SetFrameLevel(SuperInspectFrame.backdrop:GetFrameLevel() + 3)
  end
  HookScript(SuperInspect_HonorFrame, "OnShow", function()
    if SuperInspect_HonorFrame.backdrop and SuperInspectFrame and SuperInspectFrame.backdrop then
      SuperInspect_HonorFrame.backdrop:SetFrameStrata("DIALOG")
      SuperInspect_HonorFrame.backdrop:SetFrameLevel(SuperInspectFrame.backdrop:GetFrameLevel() + 3)
    end
  end)
	
  if SIInfoFrame then
    StripTextures(SIInfoFrame)
    CreateBackdrop(SIInfoFrame, nil, nil, .75)
    SIInfoFrame:ClearAllPoints()
    SIInfoFrame:SetPoint("TOPLEFT", SuperInspectFrame.backdrop, "TOPRIGHT", 1, -44)
    SkinCloseButton(SIInfoCloseButton, SIInfoFrame.backdrop, -6, -6)
    SkinScrollbar(SIInfoScrollFrameScrollBar)
  end
	
  SuperInspectFramePortrait:Hide()

    -- helpers for initial setup and slot updates
    local function ApplyInspectSlotInitial(btn, name)
      StripTextures(btn)
      CreateBackdrop(btn)
      SetAllPointsOffset(btn.backdrop, btn, 0)

      local icon = _G[name .. "IconTexture"] or btn:GetNormalTexture()
      if icon then
        HandleIcon(btn.backdrop, icon)
        SetAllPointsOffset(icon, btn.backdrop, 3)
        icon:SetTexCoord(.08, .92, .08, .92)
        icon:SetDrawLayer("OVERLAY")
      end

      local dur = _G[name .. "DurabilityNumber"]
      if dur and dur.SetFont then dur:SetFont(pfUI.font_default, 11, "OUTLINE"); dur:SetTextColor(1,1,1) end

      local bg = _G[name .. "BGTexture"]
      if bg and bg.Hide then bg:Hide() end

      if btn.backdrop then btn.backdrop:SetBackdropBorderColor(GetStringColor(pfUI_config.appearance.border.color)) end
    end

    local function UpdateInspectSlot(button)
      local bg = _G[button:GetName().."BGTexture"]
      if bg and bg.Hide then bg:Hide() end

      local icon = _G[button:GetName().."IconTexture"] or button:GetNormalTexture()
      if icon then
        HandleIcon(button.backdrop, icon)
        SetAllPointsOffset(icon, button.backdrop, 3)
        icon:SetTexCoord(.08, .92, .08, .92)
        icon:SetDrawLayer("OVERLAY")
      end

      local unit = SuperInspect_InvFrame and SuperInspect_InvFrame.unit
      local link = unit and GetInventoryItemLink(unit, button:GetID())
      if link then
        local _, _, itemstr = string.find(link, "(item:%d+:%d+:%d+:%d+)")
        local _, _, quality = GetItemInfo(itemstr or link)
        if quality ~= nil and button.backdrop and button.backdrop.SetBackdropBorderColor then
          local r, g, b = GetItemQualityColor(quality)
          if r and g and b then
            button.backdrop:SetBackdropBorderColor(r, g, b, 1)
          else
            button.backdrop:SetBackdropBorderColor(GetStringColor(pfUI_config.appearance.border.color))
          end
          return
        elseif (button.hasItem or link) and pfUI and pfUI.api and pfUI.api.QueueFunction then
          pfUI.api.QueueFunction(function()
            if button and button:GetName() and SuperInspect_InvFrame and SuperInspect_InvFrame.unit then
              SuperInspect_InspectPaperDollItemSlotButton_Update(button)
            end
          end)
          return
        end
      end

      if button.backdrop and button.backdrop.SetBackdropBorderColor then
        button.backdrop:SetBackdropBorderColor(GetStringColor(pfUI_config.appearance.border.color))
      end
    end

    local inspect_slots = {
      "HeadSlot","NeckSlot","ShoulderSlot","BackSlot","ChestSlot","ShirtSlot","TabardSlot",
      "WristSlot","HandsSlot","WaistSlot","LegsSlot","FeetSlot","Finger0Slot","Finger1Slot",
      "Trinket0Slot","Trinket1Slot","SecondaryHandSlot","MainHandSlot","RangedSlot"
    }

    for _, s in ipairs(inspect_slots) do
      local name = "SuperInspect_Inspect" .. s
      local btn = _G[name]
      if btn then
        ApplyInspectSlotInitial(btn, name)
      end
    end

    hooksecurefunc("SuperInspect_InspectPaperDollItemSlotButton_Update", UpdateInspectSlot)

    -- unregister skin after successful application
    pfUI.addonskinner:UnregisterSkin("SuperInspect_UI")
  end

  if SIInfoFrame then
    applySkin()
  else
    HookAddonOrVariable("SuperInspect_UI", applySkin)
  end
end)
