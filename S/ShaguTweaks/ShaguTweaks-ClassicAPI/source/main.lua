local _G = _G or getfenv(0)

SLASH_RELOAD1 = '/rl'
function SlashCmdList.RELOAD(msg, editbox) ReloadUI() end

local function ChatMessage(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffffff00" .. tostring(msg or "nil"))
end

-- Keep the client's native message() function when available. Older clients
-- without print() still get the historical ShaguTweaks chat fallback.
message = message or ChatMessage
print = print or ChatMessage

local function ChatErrorHandler(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffff0000" .. tostring(msg or "nil"))
end

-- Route uncaught Lua errors to chat without replacing Lua's global error().
-- Addons rely on error() to abort invalid execution paths.
seterrorhandler(ChatErrorHandler)

ShaguTweaks = CreateFrame("Frame")
ShaguTweaks.mods = {}
ShaguTweaks.overwrites = {}

-- flag official modules
local official = true

-- load translation tables
ShaguTweaks.L = (ShaguTweaks_locale[GetLocale()] or ShaguTweaks_locale["enUS"])
ShaguTweaks.T = (ShaguTweaks_translation[GetLocale()] or ShaguTweaks_translation["enUS"])

-- use table index key as translation fallback
ShaguTweaks.T = setmetatable(ShaguTweaks.T, { __index = function(tab,key)
  local value = tostring(key)
  rawset(tab, key, value)
  return value
end})

ShaguTweaks:RegisterEvent("ADDON_LOADED")
ShaguTweaks:RegisterEvent("VARIABLES_LOADED")
ShaguTweaks:SetScript("OnEvent", function()
  -- flag all external modules as unofficial
  if event == "ADDON_LOADED" then
    -- Most Extras ClassicAPI modules are built in now. With the old addon
    -- still enabled, its copies replace the built-in ones (same titles).
    if arg1 == "ShaguTweaks-extras" then
      DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00ShaguTweaks:|r the Extras modules are now built in. Disable the |cffffcc00ShaguTweaks Extras ClassicAPI|r addon so they only run once.")
    end

    ShaguTweaks.provider = nil
    official = false
    return
  end

  -- load current expansion
  if not ShaguTweaks.API.IsSupportedRuntime() then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff6060ShaguTweaks:|r ClassicAPI " .. ShaguTweaks.API.minimum_version_text
      .. "+ is required. Update both its DLL and !!!ClassicAPI addon, then restart the client. Tweaks have not been enabled.")
    return
  end
  local expansion = ShaguTweaks:GetExpansion()

  -- initialize empty config
  if not ShaguTweaks_config then ShaguTweaks_config = {} end

  local prediction = ShaguTweaks.T["Healing Predictions"]
  for _, oldName in ipairs({"Enable Healing Prediction", "Enable Healing Prediction on Unit Frames"}) do
    local oldPrediction = ShaguTweaks.T[oldName]
    if ShaguTweaks_config[prediction] == nil then ShaguTweaks_config[prediction] = ShaguTweaks_config[oldPrediction] end
    ShaguTweaks_config[oldPrediction] = nil
  end

  -- Retire the removed duplicate toggle; ClassicAPI owns these preferences.
  ShaguTweaks_config[ShaguTweaks.T["Auto Dismount"]] = nil
  -- Area looting is delegated to a dedicated addon from 3.8.6 onward.
  ShaguTweaks_config[ShaguTweaks.T["AoE Loot"]] = nil

  -- Gold numbers belong to Real Health Numbers; retire the duplicate toggle.
  ShaguTweaks_config["Unit Frame Health Colors"] = nil
  -- The portrait-only hiding option has been removed.
  ShaguTweaks_config[ShaguTweaks.T["Hide Player Portrait"]] = nil

  -- Split the former shared setting without overriding either new choice.
  local oldBigHealth = ShaguTweaks_config[ShaguTweaks.T["Unit Frame Big Health"]]
  if oldBigHealth ~= nil then
    local playerKey = ShaguTweaks.T["Unit Frame Big Health for Player"]
    local targetKey = ShaguTweaks.T["Unit Frame Big Health for Target"]
    if ShaguTweaks_config[playerKey] == nil then ShaguTweaks_config[playerKey] = oldBigHealth end
    if ShaguTweaks_config[targetKey] == nil then ShaguTweaks_config[targetKey] = oldBigHealth end
    ShaguTweaks_config[ShaguTweaks.T["Unit Frame Big Health"]] = nil
  end

  -- Replace detached native bars with copies; hiding the originals is opt-in.
  local oldStandalone = ShaguTweaks.T["Standalone Player Frame"]
  local resourceDisplay = ShaguTweaks.T["Personal Resource Display"]
  if ShaguTweaks_config[resourceDisplay] == nil then
    ShaguTweaks_config[resourceDisplay] = ShaguTweaks_config[oldStandalone]
  end
  if ShaguTweaks_config.StandalonePlayerFrame then
    local positions = ShaguTweaks_config.PersonalResourceDisplay or {}
    for _, key in ipairs({"Health", "Power"}) do
      if not positions[key] then positions[key] = ShaguTweaks_config.StandalonePlayerFrame[key] end
    end
    ShaguTweaks_config.PersonalResourceDisplay = positions
  end
  ShaguTweaks_config[oldStandalone] = nil
  ShaguTweaks_config.StandalonePlayerFrame = nil

  -- initialize overwrites
  ShaguTweaks_config.overwrites = ShaguTweaks_config.overwrites or {}

  -- read all registered mods
  for title, mod in pairs(ShaguTweaks.mods) do
    -- write initial default config
    if not ShaguTweaks_config[title] then
      ShaguTweaks_config[title] = mod.enabled and 1 or 0
    end

    -- load possible overwrites
    if mod.config then
      for name, value in pairs(mod.config) do
        ShaguTweaks.overwrites[name] = value
      end
    end

    -- apply custom overwrites
    if mod.config and ShaguTweaks_config.overwrites then
      for name, value in pairs(ShaguTweaks_config.overwrites) do
        ShaguTweaks.overwrites[name] = value
        mod.config[name] = value
      end
    end

    -- load enabled mods
    if mod.expansions[expansion] and ShaguTweaks_config[title] == 1 then
      mod:enable()
    end
  end

  -- Cast-bar movement is always available, independent of saved option flags.
  if expansion == "vanilla" and ShaguTweaks.EnableCastBarMover then
    ShaguTweaks.EnableCastBarMover()
  end

  -- Libraries that can stay dormant until a module actually consumes them
  -- get one final activation pass after every enabled module has registered
  -- its callbacks.
  if ShaguTweaks.libnameplate and ShaguTweaks.libnameplate.EnableIfNeeded then
    ShaguTweaks.libnameplate:EnableIfNeeded()
  end
end)

ShaguTweaks.register = function(self, mod)
  -- add fallback captions and providers to categories
  local provider = ShaguTweaks.provider or "|cffFF5555Mods:|r"
  local category = mod.category or ShaguTweaks.T["General"]
  mod.category = official and category or provider .. " " .. category

  -- register mod
  ShaguTweaks.mods[mod.title] = mod
  return ShaguTweaks.mods[mod.title]
end

local GetConfigValue = function(conf)
  if type(conf) == "table" and conf.r and conf.g and conf.b then
    return string.format("%s,%s,%s,%s", conf.r, conf.g, conf.b, (conf.a or 1))
  elseif type(conf) == "number" or type(conf) == "string" then
    return conf
  end

  return ""
end

-- print message without applied hooks
local originalAddMessage = DEFAULT_CHAT_FRAME.AddMessage
local stdout = function(msg)
  originalAddMessage(DEFAULT_CHAT_FRAME, msg)
end

-- add /st slash command for custom config overwrites
SLASH_STWEAKS1, SLASH_STWEAKS2, SLASH_STWEAKS3 = "/st", "/stweaks", "/shagutweaks"
SlashCmdList["STWEAKS"] = function(msg)
  local cmd = { ShaguTweaks.strsplit(" ", msg) }
  if cmd[1] == "reset" then
    ShaguTweaks_config.overwrites = {}
    ReloadUI()
  elseif cmd[1] then
    local index = cmd[1]
    local input = cmd[2] or ""

    -- detect best value format
    local value
    local rgba, _, r, g, b, a = string.find(input, "(.+),(.+),(.+),(.+)")

    value = rgba and { r = r, g = g, b = b, a = a }
    value = value or tonumber(input) and tonumber(input)
    value = value or input

    -- validate input and set config
    if not ShaguTweaks.overwrites[index] then
      local text = "|cffff5555Error:|r Overwrite |cffffcc00%s|r does not exists.|r"
      stdout(string.format(text, index), 1, 1, 1, 1)
    elseif type(ShaguTweaks.overwrites[index]) ~= type(value) then
      local text = "|cffff5555Error:|r Overwrite |cffffcc00%s|r requires to be type: |cffffcc00%s|r"
      stdout(string.format(text, index, type(ShaguTweaks.overwrites[index])), 1, 1, 1, 1)
    else
      ShaguTweaks_config.overwrites[index] = value
      local text = "Overwrite |cffffcc00%s|r is now set to: |cffffcc00%s|r"
      stdout(string.format(text, index, input), 1, 1, 1, 1)
    end
  else
    stdout("|cffffcc00Shagu|rTweaks overwrites:", 1, 1, 1, 1)
    stdout("|cffffcc00|r", 1, 1, 1, 1)
    stdout("|cffff5555Warning:|r This is for experienced users only. Do not change values unless you know what you're doing. Use '/st reset' before submitting any bug.", 1, .8, .8, 1)
    stdout("|cffffcc00|r", 1, 1, 1, 1)
    for name, value in ShaguTweaks.spairs(ShaguTweaks.overwrites) do
      stdout("  |cffaaaaaa/st|r " .. name .. " |cffffcc00" .. GetConfigValue(value), 1, 1, 1, 1)
    end
    stdout("  |cffaaaaaa/st|r reset", 1, 1, 1, 1)
  end
end
