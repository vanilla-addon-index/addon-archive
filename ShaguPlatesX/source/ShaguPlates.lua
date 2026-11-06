-- Check for SuperWoW at startup
if not SetAutoloot then
  StaticPopupDialogs["SHAGUPLATESX_NO_SUPERWOW"] = {
    text = "|cffffffaaShaguPlatesX|r |cffff0000requires SuperWoW 1.4 or greater to operate.|r\n\nhttps://github.com/balakethelock/SuperWoW/releases/",
    button1 = TEXT(OKAY),
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    showAlert = 1,
  }
  StaticPopup_Show("SHAGUPLATESX_NO_SUPERWOW")
  return
end

SLASH_RELOAD1 = '/rl'
function SlashCmdList.RELOAD(msg, editbox)
  ReloadUI()
end

SLASH_SHAGUPLATESX1 = '/shaguplates'
SLASH_SHAGUPLATESX2 = '/splates'
SLASH_SHAGUPLATESX3 = '/sp'
SLASH_SHAGUPLATESX4 = '/shaguplatesx'
SLASH_SHAGUPLATESX5 = '/splatesx'
SLASH_SHAGUPLATESX6 = '/spx'
function SlashCmdList.SHAGUPLATESX(msg, editbox)
  if ShaguPlatesX.gui:IsShown() then
    ShaguPlatesX.gui:Hide()
  else
    ShaguPlatesX.gui:Show()
  end
end

SLASH_GM1, SLASH_GM2 = '/gm', '/support'
function SlashCmdList.GM(msg, editbox)
  ToggleHelpFrame(1)
end

ShaguPlatesX = CreateFrame("Frame", nil, UIParent)
ShaguPlatesX:RegisterEvent("ADDON_LOADED")

-- provide ShaguPlates global for compatibility with addons like ShaguTweaks
-- that check for its presence to avoid duplicate functionality
if not ShaguPlates then
  ShaguPlates = ShaguPlatesX
end

-- setup bootvar
ShaguPlatesX.bootup = true

-- initialize saved variables
ShaguPlatesX_playerDB = {}
ShaguPlatesX_config = {}
ShaguPlatesX_init = {}
ShaguPlatesX_profiles = {}
ShaguPlatesX_addon_profiles = {}
ShaguPlatesX_cache = {}

-- localization
ShaguPlatesX_locale = {}
ShaguPlatesX_translation = {}

-- initialize default variables
ShaguPlatesX.cache = {}
ShaguPlatesX.module = {}
ShaguPlatesX.modules = {}
ShaguPlatesX.skin = {}
ShaguPlatesX.skins = {}
ShaguPlatesX.environment = {}
ShaguPlatesX.movables = {}
ShaguPlatesX.version = {}
ShaguPlatesX.hooks = {}
ShaguPlatesX.env = {}

-- detect current addon path
local tocs = { "", "-master" }
for _, name in pairs(tocs) do
  local current = string.format("ShaguPlatesX%s", name)
  local _, title = GetAddOnInfo(current)
  if title then
    ShaguPlatesX.name = current
    ShaguPlatesX.path = "Interface\\AddOns\\" .. current
    break
  end
end

-- handle/convert media dir paths
ShaguPlatesX.media = setmetatable({}, { __index = function(tab,key)
  local value = tostring(key)
  if strfind(value, "img:") then
    value = string.gsub(value, "img:", ShaguPlatesX.path .. "\\img\\")
  elseif strfind(value, "font:") then
    value = string.gsub(value, "font:", ShaguPlatesX.path .. "\\fonts\\")
  else
    value = string.gsub(value, "Interface\\AddOns\\ShaguPlates\\", ShaguPlatesX.path .. "\\")
  end
  rawset(tab,key,value)
  return value
end})

-- cache client version
local _, _, _, client = GetBuildInfo()
client = client or 11200
ShaguPlatesX.expansion = "vanilla"
ShaguPlatesX.client = client

-- setup ShaguPlates namespace
setmetatable(ShaguPlatesX.env, {__index = getfenv(0)})

function ShaguPlatesX:UpdateColors()
  if ShaguPlatesX.expansion == "vanilla" then
    -- update table to get unknown colors and blue shamans for vanilla
    RAID_CLASS_COLORS = {
      ["WARRIOR"] = { r = 0.78, g = 0.61, b = 0.43, colorStr = "ffc79c6e" },
      ["MAGE"]    = { r = 0.41, g = 0.8,  b = 0.94, colorStr = "ff69ccf0" },
      ["ROGUE"]   = { r = 1,    g = 0.96, b = 0.41, colorStr = "fffff569" },
      ["DRUID"]   = { r = 1,    g = 0.49, b = 0.04, colorStr = "ffff7d0a" },
      ["HUNTER"]  = { r = 0.67, g = 0.83, b = 0.45, colorStr = "ffabd473" },
      ["SHAMAN"]  = { r = 0.14, g = 0.35, b = 1.0,  colorStr = "ff0070de" },
      ["PRIEST"]  = { r = 1,    g = 1,    b = 1,    colorStr = "ffffffff" },
      ["WARLOCK"] = { r = 0.58, g = 0.51, b = 0.79, colorStr = "ff9482c9" },
      ["PALADIN"] = { r = 0.96, g = 0.55, b = 0.73, colorStr = "fff58cba" },
    }

    RAID_CLASS_COLORS = setmetatable(RAID_CLASS_COLORS, { __index = function(tab,key)
      return { r = 0.6,  g = 0.6,  b = 0.6,  colorStr = "ff999999" }
    end})
  end
end

function ShaguPlatesX:UpdateFonts()
  -- abort when config is not ready yet
  if not ShaguPlatesX_config or not ShaguPlatesX_config.global then return end

  -- load font configuration
  local default, tooltip, unit, unit_name, combat
  if ShaguPlatesX_config.global.force_region == "1" and GetLocale() == "zhCN" and ShaguPlatesX.expansion == "vanilla" then
    -- force locale compatible fonts (zhCN 1.12)
    default = "Fonts\\FZXHLJW.TTF"
    tooltip = "Fonts\\FZXHLJW.TTF"
    combat = "Fonts\\FZXHLJW.TTF"
    unit = "Fonts\\FZXHLJW.TTF"
    unit_name = "Fonts\\FZXHLJW.TTF"
  elseif ShaguPlatesX_config.global.force_region == "1" and GetLocale() == "zhTW" and ShaguPlatesX.expansion == "vanilla" then
    -- force locale compatible fonts (zhTW 1.12)
    default = "Fonts\\FZXHLJW.ttf"
    tooltip = "Fonts\\FZXHLJW.ttf"
    combat = "Fonts\\FZXHLJW.ttf"
    unit = "Fonts\\FZXHLJW.ttf"
    unit_name = "Fonts\\FZXHLJW.ttf"
  elseif ShaguPlatesX_config.global.force_region == "1" and GetLocale() == "koKR" then
    -- force locale compatible fonts (koKR)
    default = "Fonts\\2002.TTF"
    tooltip = "Fonts\\2002.TTF"
    combat = "Fonts\\2002.TTF"
    unit = "Fonts\\2002.TTF"
    unit_name = "Fonts\\2002.TTF"
  else
    -- use default entries
    default = ShaguPlatesX.media[ShaguPlatesX_config.global.font_default]
    tooltip = ShaguPlatesX.media[ShaguPlatesX_config.tooltip.font_tooltip]
    combat = ShaguPlatesX.media[ShaguPlatesX_config.global.font_combat]
    unit = ShaguPlatesX.media[ShaguPlatesX_config.global.font_unit]
    unit_name = ShaguPlatesX.media[ShaguPlatesX_config.global.font_unit_name]
  end

  -- write setting shortcuts
  ShaguPlatesX.font_default = default
  ShaguPlatesX.font_combat = combat
  ShaguPlatesX.font_unit = unit
  ShaguPlatesX.font_unit_name = unit_name

  -- skip setting fonts, keep blizzard defaults
  if ShaguPlatesX_config.global.font_blizzard == "1" then
    return
  end

  -- set game constants

  -- set dropdown font to default size

  -- change default game font objects

  if TextStatusBarTextSmall then -- does not exist in koKR
  end
end

local translations
function ShaguPlatesX:GetEnvironment()
  -- load api into environment
  for m, func in pairs(ShaguPlatesX.api or {}) do
    ShaguPlatesX.env[m] = func
  end

  if ShaguPlatesX_config and ShaguPlatesX_config.global and ShaguPlatesX_config.global.language and not translations then
    local lang = ShaguPlatesX_config and ShaguPlatesX_config.global and ShaguPlatesX_config.global.language and ShaguPlatesX_translation[ShaguPlatesX_config.global.language] and ShaguPlatesX_config.global.language or GetLocale()
    ShaguPlatesX.env.T = setmetatable(ShaguPlatesX_translation[lang] or {}, { __index = function(tab,key)
      local value = tostring(key)
      rawset(tab,key,value)
      return value
    end})
    translations = true
  end

  ShaguPlatesX.env._G = getfenv(0)
  ShaguPlatesX.env.C = ShaguPlatesX_config
  ShaguPlatesX.env.L = (ShaguPlatesX_locale[GetLocale()] or ShaguPlatesX_locale["enUS"])

  return ShaguPlatesX.env
end

function ShaguPlatesX:RegisterModule(name, a2, a3)
  if ShaguPlatesX.module[name] then return end
  local hasv = type(a2) == "string"
  local func, version = hasv and a3 or a2, hasv and a2 or "vanilla"

  -- check for client compatibility
  if not strfind(version, ShaguPlatesX.expansion) then return end

  ShaguPlatesX.module[name] = func
  table.insert(ShaguPlatesX.modules, name)
  if not ShaguPlatesX.bootup then
    ShaguPlatesX:LoadModule(name)
  end
end

function ShaguPlatesX:RegisterSkin(name, a2, a3)
  if ShaguPlatesX.skin[name] then return end
  local hasv = type(a2) == "string"
  local func, version = hasv and a3 or a2, hasv and a2 or "vanilla"

  -- check for client compatibility
  if not strfind(version, ShaguPlatesX.expansion) then return end

  ShaguPlatesX.skin[name] = func
  table.insert(ShaguPlatesX.skins, name)
  if not ShaguPlatesX.bootup then
    ShaguPlatesX:LoadSkin(name)
  end
end

function ShaguPlatesX:LoadModule(m)
  setfenv(ShaguPlatesX.module[m], ShaguPlatesX:GetEnvironment())
  ShaguPlatesX.module[m]()
end

function ShaguPlatesX:LoadSkin(s)
  setfenv(ShaguPlatesX.skin[s], ShaguPlatesX:GetEnvironment())
  ShaguPlatesX.skin[s]()
end

ShaguPlatesX:SetScript("OnEvent", function()

  -- make sure to initialize and set our fonts
  -- each time an addon got loaded but only
  -- when the config is already accessible
  if not ShaguPlatesX.bootup then
    ShaguPlatesX:UpdateFonts()
  end

  if arg1 == ShaguPlatesX.name then
    -- read ShaguPlates version from .toc file
    local major, minor, fix = ShaguPlatesX.api.strsplit(".", tostring(GetAddOnMetadata(ShaguPlatesX.name, "Version")))
    ShaguPlatesX.version.major = tonumber(major) or 1
    ShaguPlatesX.version.minor = tonumber(minor) or 2
    ShaguPlatesX.version.fix   = tonumber(fix)   or 0
    ShaguPlatesX.version.string = ShaguPlatesX.version.major .. "." .. ShaguPlatesX.version.minor .. "." .. ShaguPlatesX.version.fix

    -- use "Modern" as default profile on a fresh install
    if ShaguPlatesX.api.isempty(ShaguPlatesX_init) and ShaguPlatesX.api.isempty(ShaguPlatesX_config) then
    end

    ShaguPlatesX:LoadConfig()
    ShaguPlatesX:MigrateConfig()
    ShaguPlatesX:UpdateFonts()

    -- disable ShaguTweaks nameplate library to avoid duplicate processing
    if ShaguPlatesX_config.global.override_shagutweaks_nameplates == "1" and ShaguTweaks and ShaguTweaks.libnameplate then
      ShaguTweaks.libnameplate:SetScript("OnUpdate", nil)
      ShaguTweaks.libnameplate.OnInit = {}
      ShaguTweaks.libnameplate.OnShow = {}
      ShaguTweaks.libnameplate.OnUpdate = {}
    end

    -- manage ShaguTweaks target frame libraries based on TargetFrame visibility
    -- disable libdebuff and libcast if the frame is permanently hidden by another addon
    if ShaguPlatesX_config.global.override_shagutweaks_targetlibs == "1" and ShaguTweaks and (ShaguTweaks.libdebuff or ShaguTweaks.libcast) then
      local libdebuff = ShaguTweaks.libdebuff
      local libcast = ShaguTweaks.libcast

      local libdebuff_stored = false
      local libdebuff_onevent, libdebuff_updateunits
      local libdebuff_events = {
        "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE",
        "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE",
        "CHAT_MSG_SPELL_FAILED_LOCALPLAYER",
        "CHAT_MSG_SPELL_SELF_DAMAGE",
        "PLAYER_TARGET_CHANGED",
        "SPELLCAST_STOP",
        "UNIT_AURA",
        "CHAT_MSG_COMBAT_SELF_HITS",
      }

      local libcast_stored = false
      local libcast_onevent
      local libcast_events = {
        "CHAT_MSG_SPELL_SELF_DAMAGE",
        "CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE",
        "CHAT_MSG_SPELL_HOSTILEPLAYER_BUFF",
        "CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE",
        "CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF",
        "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_BUFFS",
        "CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_BUFFS",
        "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE",
        "CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE",
        "CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE",
        "CHAT_MSG_SPELL_PARTY_DAMAGE",
        "CHAT_MSG_SPELL_PARTY_BUFF",
        "CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE",
        "CHAT_MSG_SPELL_PERIODIC_PARTY_BUFFS",
        "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE",
        "CHAT_MSG_SPELL_PERIODIC_CREATURE_BUFFS",
        "CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE",
        "CHAT_MSG_SPELL_CREATURE_VS_CREATURE_BUFF",
        "SPELLCAST_START",
        "SPELLCAST_STOP",
        "SPELLCAST_FAILED",
        "SPELLCAST_INTERRUPTED",
        "SPELLCAST_DELAYED",
        "SPELLCAST_CHANNEL_START",
        "SPELLCAST_CHANNEL_STOP",
        "SPELLCAST_CHANNEL_UPDATE",
      }

      local function DisableTargetFrameLibs()
        if libdebuff and not libdebuff_stored then
          libdebuff_onevent = libdebuff:GetScript("OnEvent")
          libdebuff_updateunits = libdebuff.UpdateUnits
          libdebuff:UnregisterAllEvents()
          libdebuff:SetScript("OnEvent", nil)
          libdebuff.UpdateUnits = function() end
          libdebuff_stored = true
        end
        if libcast and not libcast_stored then
          libcast_onevent = libcast:GetScript("OnEvent")
          libcast:UnregisterAllEvents()
          libcast:SetScript("OnEvent", nil)
          libcast_stored = true
        end
      end

      local function EnableTargetFrameLibs()
        if libdebuff and libdebuff_stored then
          for _, event in pairs(libdebuff_events) do
            pcall(function() libdebuff:RegisterEvent(event) end)
          end
          libdebuff:SetScript("OnEvent", libdebuff_onevent)
          libdebuff.UpdateUnits = libdebuff_updateunits
          libdebuff_stored = false
        end
        if libcast and libcast_stored then
          for _, event in pairs(libcast_events) do
            pcall(function() libcast:RegisterEvent(event) end)
          end
          libcast:SetScript("OnEvent", libcast_onevent)
          libcast_stored = false
        end
      end

      -- check if TargetFrame is permanently hidden (has target but frame not visible)
      local targetlibs_checker = CreateFrame("Frame")
      local checked = false
      targetlibs_checker:RegisterEvent("PLAYER_TARGET_CHANGED")
      targetlibs_checker:SetScript("OnEvent", function()
        if checked then return end
        if UnitExists("target") then
          checked = true
          -- we have a target - if TargetFrame still isn't visible, it's been replaced
          if TargetFrame and not TargetFrame:IsVisible() then
            DisableTargetFrameLibs()
            targetlibs_checker:UnregisterAllEvents()
          else
            -- frame is working normally, stop checking
            targetlibs_checker:UnregisterAllEvents()
          end
        end
      end)

      -- also hook TargetFrame hide for dynamic detection
      if TargetFrame then
        local oldHide = TargetFrame:GetScript("OnHide")
        TargetFrame:SetScript("OnHide", function()
          if oldHide then oldHide() end
          -- only disable if hidden while we have a target (permanent hide)
          if UnitExists("target") and checked then
            DisableTargetFrameLibs()
          end
        end)

        local oldShow = TargetFrame:GetScript("OnShow")
        TargetFrame:SetScript("OnShow", function()
          if oldShow then oldShow() end
          EnableTargetFrameLibs()
        end)
      end
    end

    -- load modules
    for _, m in pairs(this.modules) do
      if not ( ShaguPlatesX_config["disabled"] and ShaguPlatesX_config["disabled"][m]  == "1" ) then
        ShaguPlatesX:LoadModule(m)
      end
    end

    -- load skins
    for _, s in pairs(this.skins) do
      if not ( ShaguPlatesX_config["disabled"] and ShaguPlatesX_config["disabled"]["skin_" .. s]  == "1" ) then
        ShaguPlatesX:LoadSkin(s)
      end
    end

    ShaguPlatesX.bootup = nil
  end
end)

ShaguPlatesX.backdrop = {
  bgFile = "Interface\\BUTTONS\\WHITE8X8", tile = false, tileSize = 0,
  edgeFile = "Interface\\BUTTONS\\WHITE8X8", edgeSize = 1,
  insets = {left = -1, right = -1, top = -1, bottom = -1},
}
ShaguPlatesX.backdrop_no_top = ShaguPlatesX.backdrop

ShaguPlatesX.backdrop_thin = {
  bgFile = "Interface\\BUTTONS\\WHITE8X8", tile = false, tileSize = 0,
  edgeFile = "Interface\\BUTTONS\\WHITE8X8", edgeSize = 1,
  insets = {left = 0, right = 0, top = 0, bottom = 0},
}

ShaguPlatesX.backdrop_hover = {
  edgeFile = "Interface\\BUTTONS\\WHITE8X8", edgeSize = 24,
  insets = {left = -1, right = -1, top = -1, bottom = -1},
}

ShaguPlatesX.backdrop_shadow = {
  edgeFile = ShaguPlatesX.media["img:glow2"], edgeSize = 8,
  insets = {left = 0, right = 0, top = 0, bottom = 0},
}

ShaguPlatesX.backdrop_blizz_bg = {
  bgFile =  "Interface\\BUTTONS\\WHITE8X8", tile = true, tileSize = 8,
  insets = { left = 3, right = 3, top = 3, bottom = 3 }
}

ShaguPlatesX.backdrop_blizz_border = {
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
  insets = { left = 3, right = 3, top = 3, bottom = 3 }
}

ShaguPlatesX.backdrop_blizz_full = {
  bgFile =  "Interface\\BUTTONS\\WHITE8X8", tile = true, tileSize = 8,
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
  insets = { left = 3, right = 3, top = 3, bottom = 3 }
}

local message = function(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffcccc33INFO: |cffffff55" .. ( msg or "nil" ))
end

error = function(msg)
  if PF_DEBUG_MODE then message(debugstack()) end
  if string.find(msg, "AddOns\\ShaguPlatesX") then
    DEFAULT_CHAT_FRAME:AddMessage("|cffcc3333ERROR: |cffff5555".. (msg or "nil" ))
  elseif not ShaguPlatesX_config or (ShaguPlatesX_config.global and ShaguPlatesX_config.global.errors == "1") then
    DEFAULT_CHAT_FRAME:AddMessage("|cffcc3333ERROR: |cffff5555".. (msg or "nil" ))
  end
end

function ShaguPlatesX.SetupCVars()
  ClearTutorials()
  TutorialFrame_HideAllAlerts()

  ConsoleExec("CameraDistanceMaxFactor 5")

  SetCVar("autoSelfCast", "1")
  SetCVar("profanityFilter", "0")

  MultiActionBar_ShowAllGrids()
  ALWAYS_SHOW_MULTIBARS = "1"

  SHOW_BUFF_DURATIONS = "1"
  QUEST_FADING_DISABLE = "1"
  NAMEPLATES_ON = "1"

  SHOW_COMBAT_TEXT = "1"
  COMBAT_TEXT_SHOW_LOW_HEALTH_MANA = "1"
  COMBAT_TEXT_SHOW_AURAS = "1"
  COMBAT_TEXT_SHOW_AURA_FADE = "1"
  COMBAT_TEXT_SHOW_COMBAT_STATE = "1"
  COMBAT_TEXT_SHOW_DODGE_PARRY_MISS = "1"
  COMBAT_TEXT_SHOW_RESISTANCES = "1"
  COMBAT_TEXT_SHOW_REPUTATION = "1"
  COMBAT_TEXT_SHOW_REACTIVES = "1"
  COMBAT_TEXT_SHOW_FRIENDLY_NAMES = "1"
  COMBAT_TEXT_SHOW_COMBO_POINTS = "1"
  COMBAT_TEXT_SHOW_MANA = "1"
  COMBAT_TEXT_FLOAT_MODE = "1"
  COMBAT_TEXT_SHOW_HONOR_GAINED = "1"
  UIParentLoadAddOn("Blizzard_CombatText")
end
