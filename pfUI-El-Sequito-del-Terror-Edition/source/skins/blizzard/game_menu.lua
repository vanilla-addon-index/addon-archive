pfUI:RegisterSkin("Game Menu", "vanilla:tbc", function ()
  local rawborder, border = GetBorderSize()

  -- [ Internal Helpers ]
  local function SkinAndAnchorMenu()
    StripTextures(GameMenuFrame)
    if not GameMenuFrame.backdrop then
      CreateBackdrop(GameMenuFrame, nil, true, .75)
      CreateBackdropShadow(GameMenuFrame)
    end

    local title = GetNoNameObject(GameMenuFrame, "FontString", "ARTWORK", MAIN_MENU)
    if title then
      title:SetTextColor(1,1,1,1)
      title:ClearAllPoints()
      title:SetPoint("TOP", GameMenuFrame, "TOP", 0, 16)
      title:SetFont(pfUI.font_default, C.global.font_size + 2, "OUTLINE")
    end

    -- Create or skin our own buttons
    if not GameMenuButtonPFUI then
      local pfUIButton = CreateFrame("Button", "GameMenuButtonPFUI", GameMenuFrame, "GameMenuButtonTemplate")
      pfUIButton:SetText(T["|cff33ffccpf|cffffffffUI|cffcccccc Config"])
      pfUIButton:SetScript("OnClick", function()
        pfUI.gui:Show()
        HideUIPanel(GameMenuFrame)
      end)
      SkinButton(pfUIButton)
    end

    if not GameMenuButtonPFUIAddOns and pfUI.addons then
      local pfUIAddonButton = CreateFrame("Button", "GameMenuButtonPFUIAddOns", GameMenuFrame, "GameMenuButtonTemplate")
      pfUIAddonButton:SetText(T["AddOns"])
      pfUIAddonButton:SetScript("OnClick", function()
        pfUI.addons:Show()
        HideUIPanel(GameMenuFrame)
      end)
      SkinButton(pfUIAddonButton)
    end

    -- Define the stack order (Turtle WoW aware)
    local buttonStack = {
      "GameMenuButtonPFUI",
      "GameMenuButtonPFUIAddOns",
      "GameMenuButtonDonationStore",        -- Turtle WoW
      "GameMenuButtonDonation",             -- Turtle WoW alt
      "GameMenuButtonShop",                 -- Turtle WoW Shop (Donación)
      "GameMenuButtonTurtleShop",           -- Turtle WoW Shop (Alternative)
      "GameMenuButtonHardcoreCharacter",    -- Turtle WoW Hardcore
      "GameMenuButtonHelp",
      "GameMenuButtonOptions",
      "GameMenuButtonSoundOptions",
      "GameMenuButtonUIOptions",
      "GameMenuButtonKeybindings",
      "GameMenuButtonMacros",
      "GameMenuButtonMoveAnything",         -- Thirdparty
      "GameMenuButtonHardcoreDeathLogGUI",  -- Hardcore Addon
      "GameMenuButtonAddOns",
      "GameMenuButtonRatings",
      "GameMenuButtonLogout",
      "GameMenuButtonQuit",
      "GameMenuButtonContinue",
    }

    local b_width = 160 -- Standard width
    local b_height = 22 -- Standard height
    local b_spacing = 5 -- Tactical breathing room
    local lastButton = nil
    local count = 0

    GameMenuFrame:SetWidth(b_width + 20)

    for _, name in ipairs(buttonStack) do
      local button = _G[name]
      if button and button:IsShown() then
        button:ClearAllPoints()
        button:SetHeight(b_height)
        button:SetWidth(b_width)

        if not lastButton then
          button:SetPoint("TOP", 0, -10)
        else
          button:SetPoint("TOP", lastButton, "BOTTOM", 0, -b_spacing)
        end
        SkinButton(button)
        lastButton = button
        count = count + 1
      end
    end

    -- Adjust frame height based on button count
    GameMenuFrame:SetHeight(count * (b_height + b_spacing) + 20)
  end

  -- Initial Run
  SkinAndAnchorMenu()

  -- Hook OnShow to catch dynamic buttons from other addons (MCP, Turtle engine etc)
  HookScript(GameMenuFrame, "OnShow", function()
    SkinAndAnchorMenu()
  end)
end)
