-- pfUI Octo: the ElvUI-style look.
--
-- pfUI.octo.look holds only appearance settings: 1px black pixel borders,
-- near-black backdrops, PT Sans Narrow text with Expressway numbers and the
-- ElvUI bar texture. It never touches sizes or positions, so it can be laid
-- over any existing config (pfUI.octo.ApplyLook, a button in Settings >
-- Appearance and the install wizard).
--
-- pfUI_profiles["Octo"] is the "Slim" profile (pfUI's closest to ElvUI's
-- layout) with that look on top. A fresh install starts on it (pfUI.lua).

pfUI.octo = pfUI.octo or {}

local FONT = "Interface\\AddOns\\pfUI\\fonts\\"
local BAR = "Interface\\AddOns\\pfUI\\img\\bar_elvui"
local TEXT = FONT .. "PT-Sans-Narrow-Bold.ttf"
local NUMBERS = FONT .. "Expressway.ttf"

local look = {
  ["global"] = {
    ["font_default"] = TEXT,
    ["font_unit"] = NUMBERS,
    ["font_unit_name"] = TEXT,
    ["font_combat"] = NUMBERS,
    ["font_size"] = "12",
    ["font_unit_size"] = "12",
    ["font_unit_style"] = "OUTLINE",
  },
  ["appearance"] = {
    ["border"] = {
      ["color"] = "0,0,0,1",
      ["background"] = "0.06,0.06,0.06,0.9",
      ["shadow"] = "0",
      ["pixelperfect"] = "1",
      ["force_blizz"] = "0",
      ["default"] = "1",
      ["actionbars"] = "-1",
      ["unitframes"] = "-1",
      ["panels"] = "-1",
      ["chat"] = "-1",
      ["bags"] = "-1",
      ["nameplates"] = "-1",
    },
    ["accent"] = {
      ["mode"] = "class",
    },
    ["castbar"] = {
      ["texture"] = BAR,
    },
    ["cd"] = {
      ["font"] = NUMBERS,
    },
  },
  ["bars"] = {
    ["font"] = NUMBERS,
  },
  ["chat"] = {
    ["global"] = {
      ["custombg"] = "1",
      ["border"] = "0,0,0,1",
      ["background"] = "0.06,0.06,0.06,0.75",
    },
  },
  ["tooltip"] = {
    ["font_tooltip"] = TEXT,
    ["statusbar"] = {
      ["texture"] = BAR,
    },
  },
  ["panel"] = {
    ["xp"] = {
      ["texture"] = BAR,
    },
  },
  ["nameplates"] = {
    ["healthtexture"] = BAR,
  },
  ["unitframes"] = {},
}

-- every unit frame gets the bar texture (same list as api/config.lua)
for _, unit in pairs({ "player", "target", "focus", "focustarget", "group", "grouptarget", "grouppet",
                       "raid", "ttarget", "pet", "ptarget", "fallback", "tttarget" }) do
  look["unitframes"][unit] = { ["bartexture"] = BAR, ["pbartexture"] = BAR }
end

pfUI.octo.look = look

-- copies every value of src into dst, creating sub-tables as needed
local function merge(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
      merge(dst[k], v)
    else
      dst[k] = v
    end
  end
  return dst
end
pfUI.octo.merge = merge

-- Lays the look over a config table (default: the live pfUI_config).
-- The caller reloads the UI afterwards.
function pfUI.octo.ApplyLook(config)
  return merge(config or pfUI_config, look)
end

-- The Octo profile: Slim + the look. Built on first use, after profiles.lua
-- has defined Slim (env.xml loads this file after it).
function pfUI.octo.Profile()
  return merge(merge({}, pfUI_profiles["Slim"] or {}), look)
end

local octo = pfUI.octo.Profile()
pfUI_profiles["Octo"] = octo

-- saved variables replace pfUI_profiles on load: put Octo back, as
-- profiles.lua does for the stock profiles
local loader = CreateFrame("Frame")
loader:RegisterEvent("VARIABLES_LOADED")
loader:SetScript("OnEvent", function()
  pfUI_profiles["Octo"] = octo
  this:UnregisterAllEvents()
end)
