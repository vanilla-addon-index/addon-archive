pfUI.addonskinner:RegisterSkin("BetterCharacterStats", function()
  if pfUI and pfUI.api and pfUI_config then
    local penv = pfUI:GetEnvironment()
    local GetStringColor, GetBorderSize = penv.GetStringColor, penv.GetBorderSize
    local SkinDropDown, HookScript = penv.SkinDropDown, penv.HookScript

    local bcsframe = _G["BCSFrame"]
    if not bcsframe then
      pfUI.addonskinner:UnregisterSkin("BetterCharacterStats")
      return
    end

    local function ApplyBCSSkin()
      for _, region in ipairs({bcsframe:GetRegions()}) do
        if region and region.Hide then region:Hide() end
      end

      if not bcsframe.pfborder then
        local rawborder, border = GetBorderSize()
        local er, eg, eb, ea = GetStringColor(pfUI_config.appearance.border.color)

        local b = CreateFrame("Frame", nil, bcsframe:GetParent())
        b:SetFrameLevel(bcsframe:GetFrameLevel() - 2)
        b:SetPoint("TOPLEFT", bcsframe, "TOPLEFT", -border, border)
        b:SetPoint("BOTTOMRIGHT", bcsframe, "BOTTOMRIGHT", border, -border)
        b:SetBackdrop(pfUI.backdrop)
        b:SetBackdropColor(0, 0, 0, .8)
        b:SetBackdropBorderColor(er, eg, eb, ea)
        bcsframe.pfborder = b

        local shadow = CreateFrame("Frame", nil, bcsframe:GetParent())
        shadow:SetFrameLevel(bcsframe:GetFrameLevel() - 3)
        shadow:SetPoint("TOPLEFT", b, "TOPLEFT", -3, 3)
        shadow:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 3, -3)
        shadow:SetBackdrop({ bgFile = pfUI.media["img:blank"], tile = true, tileSize = 1 })
        shadow:SetBackdropColor(0, 0, 0, .5)
        bcsframe.pfborder_shadow = shadow
      end
    end

    local function ApplyDropDownSkin()
      if bcsframe.pfdropskinned then return end

      local left = _G["PlayerStatFrameLeftDropDown"]
      local right = _G["PlayerStatFrameRightDropDown"]

      if left and left:GetObjectType() == "Frame" then
        SkinDropDown(left, nil, nil, nil, true)
        if left.backdrop then
          left.backdrop:SetPoint("TOPLEFT", 19, -2)
          left.backdrop:SetPoint("BOTTOMRIGHT", -19, 7)
        end
      end

      if right and right:GetObjectType() == "Frame" then
        SkinDropDown(right, nil, nil, nil, true)
        if right.backdrop then
          right.backdrop:SetPoint("TOPLEFT", 19, -2)
          right.backdrop:SetPoint("BOTTOMRIGHT", -19, 7)
        end
      end

      bcsframe.pfdropskinned = true
    end

    local dropper = CreateFrame("Frame", nil, UIParent)
    dropper:RegisterEvent("PLAYER_ENTERING_WORLD")
    dropper:SetScript("OnEvent", function()
      this:UnregisterAllEvents()
      ApplyDropDownSkin()
    end)

    HookScript(bcsframe, "OnShow", ApplyBCSSkin)
    ApplyBCSSkin()
  end
  pfUI.addonskinner:UnregisterSkin("BetterCharacterStats")
end)
