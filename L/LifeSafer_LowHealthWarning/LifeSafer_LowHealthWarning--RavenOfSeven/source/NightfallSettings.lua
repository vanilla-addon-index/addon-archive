
function LifeSafer_NightfallSettings_OnLoad()

  -- setup GUI labels
  for i, value in LifeSafer_NightfallSettings_Labels do
    getglobal("NightfallSettingsFrameLabel".. i):SetText(value)
  end
  getglobal("NightfallSettingsFrameVersion"):SetText(LifeSafer_Nightfall_Version)

  -- setup components
  -- checkbuttons
  for i, value in LifeSafer_NightfallSettings_CheckButtonTooltipStrings do
    getglobal("NightfallSettingsFrameCheckButton".. i).tooltipText = value
  end

  for i, value in LifeSafer_NightfallSettings_CheckButtonStrings do
    getglobal("NightfallSettingsFrameCheckButton".. i.. "Text"):SetText(value)
  end

  -- regular buttons
  for i, value in LifeSafer_NightfallSettings_ButtonStrings do
    getglobal("NightfallSettingsFrameButton".. i.. "Text"):SetText(value)
  end

  -- make config window close on escape
  tinsert(UISpecialFrames, "NightfallSettingsFrame")

  -- add window to built-in UI window managment
  UIPanelWindows["NightfallSettingsFrame"] = { area = "left", pushable = 2, whileDead = 1 }

end


function LifeSafer_NightfallSettings_OnShow()

  -- initalize GUI
  local checkButtons = { [1] = LifeSafer_Nightfall_Enabled, [2] = LifeSafer_Nightfall_UseLargeEffect,
                         [3] = LifeSafer_Nightfall_SoundEffects, [4] = LifeSafer_Nightfall_ShardEnabled, }
  LifeSafer_NightfallSettings_SetValues(checkButtons)

end


function LifeSafer_NightfallSettings_SetValues(checkButtonValues)

  -- set components to parameters
  for i, value in checkButtonValues do
    getglobal("NightfallSettingsFrameCheckButton".. i):SetChecked(value)
  end

end


function LifeSafer_NightfallSettings_ApplySettings()

  -- set addon enabled
  LifeSafer_Nightfall_Enabled = getglobal("NightfallSettingsFrameCheckButton1"):GetChecked() or false
  LifeSafer_Nightfall_UseLargeEffect = getglobal("NightfallSettingsFrameCheckButton2"):GetChecked() or false
  LifeSafer_Nightfall_SoundEffects = getglobal("NightfallSettingsFrameCheckButton3"):GetChecked() or false
  LifeSafer_Nightfall_ShardEnabled = getglobal("NightfallSettingsFrameCheckButton4"):GetChecked() or false

  -- propagate settings
  LifeSafer_Nightfall_ApplySettings()

end


function LifeSafer_NightfallSettings_ResetSettings()

  -- restore default values
  local checkButtons = { LifeSafer_Nightfall_Default_Enabled, LifeSafer_Nightfall_Default_UseLargeEffect,
                         LifeSafer_Nightfall_SoundEffects, LifeSafer_Nightfall_Default_ShardEnabled, }
  LifeSafer_NightfallSettings_SetValues(checkButtons)

end
