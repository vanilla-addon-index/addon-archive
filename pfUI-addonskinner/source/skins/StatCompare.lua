pfUI.addonskinner:RegisterSkin("StatCompare", function()
  if pfUI and pfUI.api and pfUI_config then
    local penv = pfUI:GetEnvironment()
    local StripTextures, CreateBackdrop, CreateBackdropShadow = penv.StripTextures, penv.CreateBackdrop, penv.CreateBackdropShadow
    local SkinButton, SkinCloseButton, SetAllPointsOffset = penv.SkinButton, penv.SkinCloseButton, penv.SetAllPointsOffset
    local HookScript, GetStringColor = penv.HookScript, penv.GetStringColor

    local frames = { "StatCompareSelfFrame", "StatCompareTargetFrame" }

    local function SkinStatCompareFrame(frame)
      if not frame or frame.pfSkinned then return end
      StripTextures(frame)
      if frame.SetBackdrop then frame:SetBackdrop(nil) end
      if frame.SetBackdropColor then frame:SetBackdropColor(0, 0, 0, 0) end
      CreateBackdrop(frame, nil, nil, .8)
      CreateBackdropShadow(frame)
      if frame.backdrop then
        frame.backdrop:SetBackdropColor(0, 0, 0, .8)
        local er, eg, eb, ea = GetStringColor(pfUI_config.appearance.border.color)
        frame.backdrop:SetBackdropBorderColor(er, eg, eb, ea)
      end

      local closeBtn = _G[frame:GetName() .. "CloseButton"]
      if closeBtn then
        SkinCloseButton(closeBtn, frame.backdrop)
      end

      local otherButtons = { "ArmorButton", "StatsButton", "SpellsButton" }
      local textures = {
        "Interface\\Icons\\inv_misc_book_08",
        "Interface\\Icons\\inv_misc_note_01",
        "Interface\\Icons\\inv_helmet_10",
      }

      for i, suffix in ipairs(otherButtons) do
        local btn = _G[frame:GetName() .. suffix]
        if btn and not btn.pfMoved then
          SkinButton(btn)
          btn:ClearAllPoints()
          btn:SetPoint("TOPRIGHT", closeBtn, "TOPLEFT", -(i - 1) * btn:GetWidth(), 0)
          btn.pfMoved = true
          if not btn.pfIcon then
            btn.pfIcon = btn:CreateTexture(nil, "OVERLAY")
            btn.pfIcon:SetTexture(textures[i])
            btn.pfIcon:SetTexCoord(.08, .92, .08, .92)
            SetAllPointsOffset(btn.pfIcon, btn, 3)
          end
        end
      end

      frame.pfSkinned = true
    end

    for _, name in ipairs(frames) do
      local f = _G[name]
      if f then
        SkinStatCompareFrame(f)
        HookScript(f, "OnShow", function()
          SkinStatCompareFrame(this)
        end)
      end
    end

    local origSCShowFrame = SCShowFrame
    if origSCShowFrame then
      _G.SCShowFrame = function(frame, target, tiptitle, tiptext, anchorx, anchory)
        origSCShowFrame(frame, target, tiptitle, tiptext, anchorx, anchory)
        SkinStatCompareFrame(frame)
      end
    end
  end
  pfUI.addonskinner:UnregisterSkin("StatCompare")
end)
