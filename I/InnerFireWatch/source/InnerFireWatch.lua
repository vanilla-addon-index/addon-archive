-- InnerFireWatch (Turtle WoW / 1.12.1)
-- Tracks key self-buffs and alerts when they fall off:
--  - Priest: Inner Fire
--  - Warrior: Battle Shout
--  - Shaman: Lightning Shield / Water Shield / Earth Shield

InnerFireWatchDB = InnerFireWatchDB or {}

local f = CreateFrame("Frame")

local DEFAULTS = {
  enabled = true,
  soundEnabled = true,
  gainedMessage = false,
  largeMessageEnabled = true,

  -- Large message color (RGB 0-1 range)
  largeMessageR = 1,
  largeMessageG = 0.1,
  largeMessageB = 0.1,

  useCustomSound = true,
  customSoundPath = "Interface\\AddOns\\InnerFireWatch\\sounds\\expire.wav",
  fallbackSound = "igQuestFailed",
}

local function ApplyDefaults()
  for k, v in pairs(DEFAULTS) do
    if InnerFireWatchDB[k] == nil then
      InnerFireWatchDB[k] = v
    end
  end
end

-- Big center-screen text (independent of UIErrorsFrame)
local CenterAlert = CreateFrame("Frame", "InnerFireWatchCenterAlert", UIParent)
CenterAlert:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
CenterAlert:SetWidth(600)
CenterAlert:SetHeight(80)
CenterAlert:Hide()

CenterAlert.text = CenterAlert:CreateFontString(nil, "OVERLAY")
CenterAlert.text:SetAllPoints(CenterAlert)
CenterAlert.text:SetFont("Fonts\\FRIZQT__.TTF", 32, "OUTLINE")
CenterAlert.text:SetJustifyH("CENTER")
CenterAlert.text:SetJustifyV("MIDDLE")

local function ShowCenterAlert(msg, r, g, b)
  CenterAlert.text:SetText(msg or "")
  CenterAlert.text:SetTextColor(r or 1, g or 0.1, b or 0.1)
  CenterAlert:Show()
  CenterAlert.startTime = GetTime()
end

-- Fade out over ~2.5s
CenterAlert:SetScript("OnUpdate", function()
  if not CenterAlert:IsShown() then return end
  local t = GetTime() - (CenterAlert.startTime or 0)
  if t >= 2.5 then
    CenterAlert:Hide()
    return
  end
  local alpha = 1 - (t / 2.5)
  CenterAlert:SetAlpha(alpha)
end)

-- Returns true if player currently has a buff whose texture contains textureNeedle (lowercase compare).
local function HasBuffByTexture(textureNeedle)
  local i = 1
  while true do
    local texture = UnitBuff("player", i)
    if not texture then break end

    texture = string.lower(texture)
    if string.find(texture, textureNeedle) then
      return true
    end

    i = i + 1
  end
  return false
end

local function PlayExpireSound()
  if not InnerFireWatchDB.soundEnabled then return end

  if InnerFireWatchDB.useCustomSound and PlaySoundFile then
    PlaySoundFile(InnerFireWatchDB.customSoundPath)
    return
  end

  if PlaySound then
    PlaySound(InnerFireWatchDB.fallbackSound)
  end
end

local function NotifyExpired(buffLabel)
  local msg = buffLabel .. " has expired!"
  DEFAULT_CHAT_FRAME:AddMessage("|cffff3333" .. msg .. "|r")

  if InnerFireWatchDB.largeMessageEnabled then
    ShowCenterAlert(string.upper(buffLabel) .. " EXPIRED!", InnerFireWatchDB.largeMessageR, InnerFireWatchDB.largeMessageG, InnerFireWatchDB.largeMessageB)
  end

  if UIErrorsFrame and UIErrorsFrame.AddMessage then
    UIErrorsFrame:AddMessage(msg, 1.0, 0.1, 0.1, 1.0, 5)
  end

  PlayExpireSound()
end

local function NotifyGained(buffLabel)
  if not InnerFireWatchDB.gainedMessage then return end
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ff33" .. buffLabel .. " active.|r")
end

-- Build trackers based on class
local trackers = {}
local function BuildTrackers()
  trackers = {}

  local _, classToken = UnitClass("player")
  if classToken == "PRIEST" then
    table.insert(trackers, {
      label = "Inner Fire",
      needle = "spell_holy_innerfire",
      active = false,
    })
  elseif classToken == "WARRIOR" then
    table.insert(trackers, {
      label = "Battle Shout",
      needle = "ability_warrior_battleshout",
      active = false,
    })
  elseif classToken == "SHAMAN" then
    -- Texture needles are based on the icon file names.
    -- Lightning Shield: Spell_Nature_LightningShield
    -- Water Shield: Ability_Shaman_WaterShield
    -- Earth Shield: Spell_Nature_SkinOfEarth (commonly used in TBC/clients that add it)
    table.insert(trackers, { label = "Lightning Shield", needle = "spell_nature_lightningshield", active = false })
    table.insert(trackers, { label = "Water Shield",     needle = "ability_shaman_watershield",   active = false })
    table.insert(trackers, { label = "Earth Shield",     needle = "spell_nature_skinofearth",    active = false })
  elseif classToken == "MAGE" then
    -- Arcane Intellect: Spell_Holy_MagicalSentry
    -- Ice Armor: Spell_Ice_FrostArmor02 (use "frostarmor" to match variants)
    -- Mage Armor: Spell_MageArmor
    table.insert(trackers, { label = "Arcane Intellect", needle = "spell_holy_magicalsentry", active = false })
    table.insert(trackers, { label = "Ice Armor",         needle = "frostarmor",               active = false })
    table.insert(trackers, { label = "Mage Armor",        needle = "spell_magearmor",        active = false })
  end

  for _, t in ipairs(trackers) do
    t.active = HasBuffByTexture(t.needle)
  end
end

local function Check()
  if not InnerFireWatchDB.enabled then return end
  if not trackers or table.getn(trackers) == 0 then return end

  for _, t in ipairs(trackers) do
    local nowActive = HasBuffByTexture(t.needle)

    if t.active and (not nowActive) then
      NotifyExpired(t.label)
    elseif (not t.active) and nowActive then
      NotifyGained(t.label)
    end

    t.active = nowActive
  end
end

f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_AURAS_CHANGED")

f:SetScript("OnEvent", function()
  Check()
end)

-- Init after saved vars load
f:SetScript("OnUpdate", function()
  f:SetScript("OnUpdate", nil)
  ApplyDefaults()
  BuildTrackers()
end)

-- Slash commands
SLASH_INNERFIREWATCH1 = "/ifw"
SlashCmdList["INNERFIREWATCH"] = function(msg)
  msg = msg and string.lower(msg) or ""

  if msg == "on" then
    InnerFireWatchDB.enabled = true
    DEFAULT_CHAT_FRAME:AddMessage("InnerFireWatch: enabled")
  elseif msg == "off" then
    InnerFireWatchDB.enabled = false
    DEFAULT_CHAT_FRAME:AddMessage("InnerFireWatch: disabled")

  elseif msg == "sound on" then
    InnerFireWatchDB.soundEnabled = true
    DEFAULT_CHAT_FRAME:AddMessage("InnerFireWatch: sound enabled")
  elseif msg == "sound off" then
    InnerFireWatchDB.soundEnabled = false
    DEFAULT_CHAT_FRAME:AddMessage("InnerFireWatch: sound disabled")

  elseif msg == "custom on" then
    InnerFireWatchDB.useCustomSound = true
    DEFAULT_CHAT_FRAME:AddMessage("InnerFireWatch: custom sound enabled")
  elseif msg == "custom off" then
    InnerFireWatchDB.useCustomSound = false
    DEFAULT_CHAT_FRAME:AddMessage("InnerFireWatch: custom sound disabled")

  elseif msg == "gained on" then
    InnerFireWatchDB.gainedMessage = true
    DEFAULT_CHAT_FRAME:AddMessage("InnerFireWatch: gained message enabled")
  elseif msg == "gained off" then
    InnerFireWatchDB.gainedMessage = false
    DEFAULT_CHAT_FRAME:AddMessage("InnerFireWatch: gained message disabled")

  elseif msg == "large on" then
    InnerFireWatchDB.largeMessageEnabled = true
    DEFAULT_CHAT_FRAME:AddMessage("InnerFireWatch: large message enabled")
  elseif msg == "large off" then
    InnerFireWatchDB.largeMessageEnabled = false
    DEFAULT_CHAT_FRAME:AddMessage("InnerFireWatch: large message disabled")



  elseif msg == "white" then
    InnerFireWatchDB.largeMessageR, InnerFireWatchDB.largeMessageG, InnerFireWatchDB.largeMessageB = 1,1,1
    DEFAULT_CHAT_FRAME:AddMessage("InnerFireWatch: color set to white")
  elseif msg == "green" then
    InnerFireWatchDB.largeMessageR, InnerFireWatchDB.largeMessageG, InnerFireWatchDB.largeMessageB = 0,1,0
    DEFAULT_CHAT_FRAME:AddMessage("InnerFireWatch: color set to green")
  elseif msg == "blue" then
    InnerFireWatchDB.largeMessageR, InnerFireWatchDB.largeMessageG, InnerFireWatchDB.largeMessageB = 0,0.4,1
    DEFAULT_CHAT_FRAME:AddMessage("InnerFireWatch: color set to blue")
  elseif msg == "red" then
    InnerFireWatchDB.largeMessageR, InnerFireWatchDB.largeMessageG, InnerFireWatchDB.largeMessageB = 1,0,0
    DEFAULT_CHAT_FRAME:AddMessage("InnerFireWatch: color set to red")
  elseif msg == "yellow" then
    InnerFireWatchDB.largeMessageR, InnerFireWatchDB.largeMessageG, InnerFireWatchDB.largeMessageB = 1,1,0
    DEFAULT_CHAT_FRAME:AddMessage("InnerFireWatch: color set to yellow")
  elseif msg == "purple" then
    InnerFireWatchDB.largeMessageR, InnerFireWatchDB.largeMessageG, InnerFireWatchDB.largeMessageB = 0.7,0,1
    DEFAULT_CHAT_FRAME:AddMessage("InnerFireWatch: color set to purple")
  else
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffInnerFireWatch Commands|r")
    DEFAULT_CHAT_FRAME:AddMessage(" ")
    DEFAULT_CHAT_FRAME:AddMessage("|cffffff00General|r")
    DEFAULT_CHAT_FRAME:AddMessage("  /ifw on")
    DEFAULT_CHAT_FRAME:AddMessage("  /ifw off")
    DEFAULT_CHAT_FRAME:AddMessage("  /ifw sound on|off")
    DEFAULT_CHAT_FRAME:AddMessage("  /ifw gained on|off")
    DEFAULT_CHAT_FRAME:AddMessage("  /ifw large on|off")
    DEFAULT_CHAT_FRAME:AddMessage(" ")
    DEFAULT_CHAT_FRAME:AddMessage("|cffffff00Color Presets|r")
    DEFAULT_CHAT_FRAME:AddMessage("  /ifw white")
    DEFAULT_CHAT_FRAME:AddMessage("  /ifw green")
    DEFAULT_CHAT_FRAME:AddMessage("  /ifw blue")
    DEFAULT_CHAT_FRAME:AddMessage("  /ifw red")
    DEFAULT_CHAT_FRAME:AddMessage("  /ifw yellow")
    DEFAULT_CHAT_FRAME:AddMessage("  /ifw purple")
  end
end
