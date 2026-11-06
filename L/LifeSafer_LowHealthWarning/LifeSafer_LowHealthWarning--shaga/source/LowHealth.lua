function LifeSafer_LowHealth_OnLoad()

  local health, mana, sound = "UNIT_HEALTH", "UNIT_MANA", "SOUND"

  LifeSafer_LowHealth_Version = "2.2.2"

  -- these are the default values
  LifeSafer_LowHealth_Default_Enabled = true
  LifeSafer_LowHealth_Default_SoundEnabled = true
  LifeSafer_LowHealth_Default_HealthEnabled = true
  LifeSafer_LowHealth_Default_ManaEnabled = true
  LifeSafer_LowHealth_Default_SoundCombatOnly = false
  LifeSafer_LowHealth_Default_HealthCombatOnly = false
  LifeSafer_LowHealth_Default_ManaCombatOnly = false
  LifeSafer_LowHealth_Default_HealthSync = false
  LifeSafer_LowHealth_Default_ManaSync = false
  LifeSafer_LowHealth_Default_HealthEmote = false
  LifeSafer_LowHealth_Default_ManaEmote = false
  LifeSafer_LowHealth_Default_UseAltTextures = false
  LifeSafer_LowHealth_Default_Thresholds = {
    [health] = { [1] = 40, [2] = 20 }, -- regular and critical, in percent
    [mana] = { [1] = 40, [2] = 20 },
    [sound] = { [1] = 50 },
  }

  -- set variables to their default values. these will be overriden when variables are loaded
  LifeSafer_LowHealth_Enabled = LifeSafer_LowHealth_Default_Enabled
  LifeSafer_LowHealth_SoundEnabled = LifeSafer_LowHealth_Default_SoundEnabled
  LifeSafer_LowHealth_HealthEnabled = LifeSafer_LowHealth_Default_HealthEnabled
  LifeSafer_LowHealth_ManaEnabled = LifeSafer_LowHealth_Default_ManaEnabled
  LifeSafer_LowHealth_SoundCombatOnly = LifeSafer_LowHealth_Default_SoundCombatOnly
  LifeSafer_LowHealth_HealthCombatOnly = LifeSafer_LowHealth_Default_HealthCombatOnly
  LifeSafer_LowHealth_ManaCombatOnly = LifeSafer_LowHealth_Default_ManaCombatOnly
  LifeSafer_LowHealth_HealthSync = LifeSafer_LowHealth_Default_HealthSync
  LifeSafer_LowHealth_ManaSync = LifeSafer_LowHealth_Default_ManaSync
  LifeSafer_LowHealth_HealthEmote = LifeSafer_LowHealth_Default_HealthEmote
  LifeSafer_LowHealth_ManaEmote = LifeSafer_LowHealth_Default_ManaEmote
  LifeSafer_LowHealth_Thresholds = LifeSafer_LowHealth_Default_Thresholds
  LifeSafer_LowHealth_UseAltTextures = LifeSafer_LowHealth_Default_UseAltTextures

  LifeSafer_LowHealth_HealthFrame = LowHealthFrame
  LifeSafer_LowHealth_ManaFrame = OutOfControlFrame

  -- these values keep track of animation
  this.states = { [health] = 0, [mana] = 0 }

  -- change the blue frame to act as the red one
  OutOfControlFrame:ClearAllPoints()
  OutOfControlFrame:SetParent("WorldFrame")
  OutOfControlFrame:SetAllPoints("WorldFrame")

  -- set both frames transparent to avoid onload flashing
  LowHealthFrame:SetAlpha(0)
  OutOfControlFrame:SetAlpha(0)

  -- command line
  SlashCmdList["LOWHEALTHWARNINGCMD"] = LifeSafer_LowHealth_CMD
  SLASH_LOWHEALTHWARNINGCMD1 = "/lowhealthwarning"
  SLASH_LOWHEALTHWARNINGCMD2 = "/lowhealth"
  SLASH_LOWHEALTHWARNINGCMD3 = "/lhw"

end


function LifeSafer_LowHealth_ApplySettings()

  -- for compatibility with older versions of saved variables
  if (not LifeSafer_LowHealth_Thresholds["SOUND"]) then
    LifeSafer_LowHealth_Thresholds["SOUND"] = { [1] = 30 }
  end

  local frame = getglobal("LowHealthWarningFrame")

  LifeSafer_LowHealth_FlashFrameStop(LifeSafer_LowHealth_HealthFrame, "UNIT_HEALTH")
  LifeSafer_LowHealth_FlashFrameStop(LifeSafer_LowHealth_ManaFrame, "UNIT_MANA")

  -- register or unregister events
  if (LifeSafer_LowHealth_Enabled) then
    LifeSafer_LowHealth_HealthFrame = LifeSafer_LowHealth_UseAltTextures and LowHealthWarningFrameAltTexture1 or LowHealthFrame
    frame:RegisterEvent("UNIT_DISPLAYPOWER")
    if (LifeSafer_LowHealth_HealthEnabled or LifeSafer_LowHealth_SoundEnabled) then
      frame:RegisterEvent("UNIT_HEALTH")
    end
    LifeSafer_LowHealth_ManaCheck()
    LifeSafer_LowHealth_ManaFrame = LifeSafer_LowHealth_UseAltTextures and LowHealthWarningFrameAltTexture2 or OutOfControlFrame
  else
    frame:UnregisterEvent("UNIT_HEALTH")
    frame:UnregisterEvent("UNIT_MANA")
    frame:UnregisterEvent("UNIT_DISPLAYPOWER")
  end

end


function LifeSafer_LowHealth_FlashFrame(value, regular, critical, frame, state)

  local REGULAR_FLASH, CRITICAL_FLASH = 1, 2

  -- disable
  if (value > regular or LifeSafer_LowHealth_CombatCheck(state) or UnitIsDeadOrGhost("player")) then
    if (UIFrameIsFlashing(frame) or UIFrameIsFading(frame)) then
      LifeSafer_LowHealth_FlashFrameStop(frame, state)
    end
  -- regular flash
  elseif (value > critical) then
    if (not (LowHealthWarningFrame.states[state] == REGULAR_FLASH)) then
      if (UIFrameIsFlashing(frame)) then
        --frame.flashDuration = frame.flashDuration + 10
        frame.fadeInTime = 0.4
        frame.fadeOutTime = 0.6
        frame.flashInHoldTime = 1
      else
        UIFrameFlash(frame, 0.4, 0.6, -1, nil, 1, 0)
      end
      LowHealthWarningFrame.states[state] = REGULAR_FLASH
    end
  -- critical flash
  else
    if (not (LowHealthWarningFrame.states[state] == CRITICAL_FLASH)) then
      if (LifeSafer_LowHealth_HealthEmote and state == "UNIT_HEALTH") then DoEmote("healme") end
      if (LifeSafer_LowHealth_ManaEmote and state == "UNIT_MANA") then DoEmote("oom") end
      if (UIFrameIsFlashing(frame)) then
        --frame.flashDuration = frame.flashDuration + 10
        frame.fadeInTime = 0.2
        frame.fadeOutTime = 0.8
        frame.flashInHoldTime = 0
      else
        UIFrameFlash(frame, 0.2, 0.8, -1, nil, 0, 0)
      end
      LowHealthWarningFrame.states[state] = CRITICAL_FLASH
    end
  end

end

function LifeSafer_LowHealth_SmoothFlashFrame(value, threshold, frame, state)

  -- disable
  if (value > threshold or LifeSafer_LowHealth_CombatCheck(state) or UnitIsDeadOrGhost("player")) then
    LifeSafer_LowHealth_FlashFrameStop(frame, state)
  -- smooth flash
  else
    local rate = LifeSafer_LowHealth_GetHeartRate(state)
    local flashIn, flashOut = rate * 0.1, rate * 0.4
    if (UIFrameIsFlashing(frame)) then
      frame.flashDuration = frame.flashDuration + rate + 1
      if (rate < 1) then
        frame.fadeInTime = rate * 0.15
        frame.fadeOutTime = rate * 0.85
        frame.flashInHoldTime = 0
      else
        frame.fadeInTime = 0.2
        frame.fadeOutTime = 0.8
        frame.flashInHoldTime = rate - 1
      end
    else
      UIFrameFlash(frame, 0.2, 0.8, 10, nil, rate -1, 0)
    end
  end

end


function LifeSafer_LowHealth_FlashFrameStop(frame, state)

  UIFrameFlashRemoveFrame(frame)
  UIFrameFadeRemoveFrame(frame)
  UIFrameFadeOut(frame, 0.5, frame:GetAlpha(), 0)
  LowHealthWarningFrame.states[state] = 0

end


function LifeSafer_LowHealth_OnEvent()

  if (event == "UNIT_DISPLAYPOWER") then 
    LifeSafer_LowHealth_ManaCheck()
    return
  end

  -- unpacks regular threshold, critical threshold, nil, nil, nil
  local t1, t2, value, frame, smooth = unpack(LifeSafer_LowHealth_Thresholds[event])

  -- pick frame based on event
  if (event == "UNIT_HEALTH") then
    value = UnitHealth("player") / UnitHealthMax("player")
    LifeSafer_LowHealth_SoundCheck(this, value * 100, unpack(LifeSafer_LowHealth_Thresholds["SOUND"]))
    if (not LifeSafer_LowHealth_HealthEnabled) then
      return -- this hack is because both sound and health flash need this event
    end
    frame = LifeSafer_LowHealth_HealthFrame
    smooth = LifeSafer_LowHealth_HealthSync
  elseif (event == "UNIT_MANA") then
    value = UnitMana("player") / UnitManaMax("player")
    frame = LifeSafer_LowHealth_ManaFrame
    smooth = LifeSafer_LowHealth_ManaSync
  end

  if (smooth) then -- flash differently depending on settings
    LifeSafer_LowHealth_SmoothFlashFrame(value * 100, t1, frame, event)
  else
    LifeSafer_LowHealth_FlashFrame(value * 100, t1, t2, frame, event)
  end

end


function LifeSafer_LowHealth_CombatCheck(state)

  local combat = UnitAffectingCombat("player")
  if (not state or state == "UNIT_HEALTH") then
    return LifeSafer_LowHealth_HealthCombatOnly and not combat
  elseif (state == "UNIT_MANA") then
    return LifeSafer_LowHealth_ManaCombatOnly and not combat
  else
    return LifeSafer_LowHealth_SoundCombatOnly and not combat
  end

end


function LifeSafer_LowHealth_SoundCheck(frame, value, threshold)

  -- disable
  if (value > threshold or not LifeSafer_LowHealth_SoundEnabled or LifeSafer_LowHealth_CombatCheck("SOUND") or UnitIsDeadOrGhost("player")) then
    if (frame.heartRate) then
      frame:SetScript("OnUpdate", nil)
      frame.heartRate = nil
    end
  -- regular
  elseif (not frame.heartRate) then
    frame:SetScript("OnUpdate", LifeSafer_LowHealth_OnUpdate)
    frame.timer = 1
    frame.heartRate = 0
  end
end


function LifeSafer_LowHealth_ManaCheck()

  local mana, frame = "UNIT_MANA", getglobal("LowHealthWarningFrame")
  if (LifeSafer_LowHealth_ManaEnabled and UnitPowerType("player") == 0) then
    -- player is using mana
    frame:RegisterEvent(mana)
  else
    frame:UnregisterEvent(mana)
    LifeSafer_LowHealth_FlashFrameStop(LifeSafer_LowHealth_ManaFrame, mana)
  end
end


function LifeSafer_LowHealth_OnUpdate()

  if (this.timer > this.heartRate) then
    PlaySoundFile("Interface\\AddOns\\LifeSafer_LowHealthWarning\\Sounds\\LifeSafer_LifeAlert_Low.mp3")
    this.heartRate = LifeSafer_LowHealth_GetHeartRate()
    this.timer = 0
  else
    this.timer = this.timer + arg1
  end

end


function LifeSafer_LowHealth_GetHeartRate(state)
  if (state and state == "UNIT_MANA") then
    return 0.5 + 2.0 * UnitMana("player") / UnitManaMax("player")
  else
    return 0.5 + 2.0 * UnitHealth("player") / UnitHealthMax("player")
  end
end


function LifeSafer_LowHealth_CMD(arg1)

  if (not arg1) then
    return
  end

  if (string.find(arg1, "^settings$") or arg1 == "") then
    ShowUIPanel(LowHealthSettingsFrame)
    return
  end

end
