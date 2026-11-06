--[[
  TankSuite - Core
  Namespace, saved settings, small helpers, event bus and slash commands.

  Written for the WoW 1.12 client (Lua 5.0): no "#" operator, no "%" operator,
  no string.match / select / varargs. See addons/tools/lint_lua50.py.
]]

TankSuite = TankSuite or {}
local TS = TankSuite

TS.name = "TankSuite"
TS.version = "1.0.0"

----------------------------------------------------------------------
-- Default settings (merged into TankSuiteDB, missing keys only)
----------------------------------------------------------------------
TS.defaults = {
  language = "auto", -- auto | en | fr
  minimapShow = true,
  minimapAngle = 215,

  announce = {
    enabled = true,
    groupOnly = true,
    failChannel = "YELL", -- SAY YELL PARTY RAID RAID_WARNING GROUP GROUP_RW CHANNEL SELF
    infoChannel = "SAY",
    customChannel = "TankSuite",
    alertSelf = false,
    fail = {
      taunt = true, growl = true, mocking = true, reckoning = true,
      earthshaker = true, shout = false, roar = false,
    },
    used = {
      taunt = false, growl = false, mocking = false, reckoning = false,
      earthshaker = false,
    },
    cd = {
      shieldwall = true, laststand = true, gem = true, shout = true, roar = true,
    },
    mainTank = { enabled = false, duration = 12, skipDual = true },
    removeSalvation = false,
    notifySalvation = true,
    messages = {}, -- only the templates the player edited
  },

  plates = {
    enabled = true,
    colorBar = true,
    showText = true,
    showIcon = true,
    showOnMe = false,
    combatOnly = true,
    textPos = "TOP", -- TOP | BOTTOM
    fontSize = 11,
    perTankColor = true,
    colors = {
      me    = { 0.10, 0.90, 0.25, 1 },
      tank  = { 0.15, 0.75, 1.00, 1 },
      other = { 1.00, 0.15, 0.15, 1 },
      none  = { 1.00, 0.60, 0.10, 1 },
      pet   = { 0.75, 0.75, 0.75, 1 },
    },
  },

  tankOpts = { autoDetect = true, useRaidRole = true },
  tanks = {}, -- [name] = { color = {r,g,b,1}, class = "WARRIOR" }
}

-- distinct colours handed out to tanks (avoids pure blue/green/red on purpose:
-- pfUI / ShaguPlates read the bar colour to guess the unit type)
TS.palette = {
  { 0.15, 0.75, 1.00, 1 }, -- cyan
  { 0.72, 0.45, 1.00, 1 }, -- violet
  { 1.00, 0.82, 0.20, 1 }, -- gold
  { 0.20, 0.92, 0.75, 1 }, -- teal
  { 1.00, 0.45, 0.72, 1 }, -- pink
  { 0.95, 0.95, 0.95, 1 }, -- white
}

----------------------------------------------------------------------
-- Small helpers
----------------------------------------------------------------------
function TS.Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33a0f2[TankSuite]|r " .. tostring(msg))
end

function TS.DeepCopy(v)
  if type(v) ~= "table" then return v end
  local out = {}
  for k, x in pairs(v) do out[k] = TS.DeepCopy(x) end
  return out
end

-- copy every key of src that is missing in dst (recursively)
function TS.Merge(dst, src)
  for k, v in pairs(src) do
    if dst[k] == nil then
      dst[k] = TS.DeepCopy(v)
    elseif type(dst[k]) == "table" and type(v) == "table" then
      TS.Merge(dst[k], v)
    end
  end
  return dst
end

function TS.Trim(s)
  s = string.gsub(s, "^%s+", "")
  s = string.gsub(s, "%s+$", "")
  return s
end

-- WoW hex colour escape from 0..1 floats
function TS.Hex(r, g, b)
  return string.format("|cff%02x%02x%02x",
    math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

function TS.ClassColor(class)
  local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if c then return c.r, c.g, c.b end
  return 0.85, 0.85, 0.85
end

-- optional API (SuperWoW): never touch it as a bare global
function TS.SpellName(id)
  local f = getglobal("SpellInfo")
  if f and id then
    local name = f(id)
    return name
  end
  return nil
end

-- post-hook a frame script (1.12 has no HookScript)
function TS.HookScript(frame, script, func)
  local prev = frame:GetScript(script)
  frame:SetScript(script, function()
    local a1, a2, a3, a4, a5, a6, a7, a8, a9 = arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9
    if prev then prev(a1, a2, a3, a4, a5, a6, a7, a8, a9) end
    func(a1, a2, a3, a4, a5, a6, a7, a8, a9)
  end)
end

-- run fn(...) and report a Lua error once instead of breaking the whole addon
local reported = {}
function TS.Safe(fn, a1, a2, a3, a4, a5, a6, a7, a8, a9)
  local ok, err = pcall(fn, a1, a2, a3, a4, a5, a6, a7, a8, a9)
  if not ok then
    local key = tostring(err)
    if not reported[key] then
      reported[key] = true
      TS.Print("|cffff5555Lua error:|r " .. key)
    end
  end
  return ok
end

----------------------------------------------------------------------
-- Localisation
----------------------------------------------------------------------
TS.strings = TS.strings or { en = {}, fr = {} }
TS.lang = "en"

function TS.L(key)
  local tbl = TS.strings[TS.lang]
  local v = tbl and tbl[key]
  if v == nil then v = TS.strings.en[key] end
  if v == nil then return key end
  return v
end

-- L + string.format with up to three arguments
function TS.Lf(key, a, b, c)
  return string.format(TS.L(key), a, b, c)
end

function TS.ApplyLanguage()
  local pick = TS.db and TS.db.language or "auto"
  if pick == "auto" then
    pick = (GetLocale() == "frFR") and "fr" or "en"
  end
  TS.lang = pick
end

----------------------------------------------------------------------
-- Event bus
----------------------------------------------------------------------
local handlers = {}
TS.frame = CreateFrame("Frame", "TankSuiteEventFrame")

function TS.On(event, fn)
  if not handlers[event] then
    handlers[event] = {}
    TS.frame:RegisterEvent(event)
  end
  table.insert(handlers[event], fn)
end

TS.frame:SetScript("OnEvent", function()
  local list = handlers[event]
  if not list then return end
  local a1, a2, a3, a4, a5, a6, a7, a8 = arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8
  for i = 1, table.getn(list) do
    TS.Safe(list[i], event, a1, a2, a3, a4, a5, a6, a7, a8)
  end
end)

----------------------------------------------------------------------
-- Init (after SavedVariables are loaded)
----------------------------------------------------------------------
local initFns = {}
function TS.OnInit(fn) table.insert(initFns, fn) end

function TS.Init()
  if TS.ready then return end
  TankSuiteDB = TankSuiteDB or {}
  TS.Merge(TankSuiteDB, TS.defaults)
  TS.db = TankSuiteDB
  TS.hasSuperWoW = (getglobal("SUPERWOW_VERSION") ~= nil) or (getglobal("SetAutoloot") ~= nil)
  TS.ready = true
  TS.ApplyLanguage()
  for i = 1, table.getn(initFns) do TS.Safe(initFns[i]) end
end

TS.On("VARIABLES_LOADED", function() TS.Init() end)

TS.On("PLAYER_ENTERING_WORLD", function()
  if TS.shownWelcome then return end
  TS.shownWelcome = true
  if TS.db then
    TS.Print(TS.Lf("welcome", TS.version))
    if not TS.hasSuperWoW then TS.Print("|cffffaa33" .. TS.L("nosuperwow") .. "|r") end
  end
end)

----------------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------------
local function OnOff(v) return v and "|cff44ff44ON|r" or "|cffff5555OFF|r" end

function TS.Slash(msg)
  msg = TS.Trim(msg or "")
  local _, _, cmd, rest = string.find(msg, "^(%S*)%s*(.-)$")
  cmd = string.lower(cmd or "")
  if not TS.ready then return end

  if cmd == "" or cmd == "menu" or cmd == "config" then
    TS.ToggleMenu()
  elseif cmd == "add" then
    local ok, name = TS.Roster.AddManual(rest ~= "" and rest or nil)
    if ok then TS.Print(TS.Lf("tank_added", name)) else TS.Print(TS.L("tank_add_fail")) end
    if TS.RefreshMenu then TS.RefreshMenu() end
  elseif cmd == "remove" or cmd == "del" then
    if TS.Roster.RemoveManual(rest) then TS.Print(TS.Lf("tank_removed", rest)) end
    if TS.RefreshMenu then TS.RefreshMenu() end
  elseif cmd == "list" then
    local list = TS.Roster.ListTanks()
    if table.getn(list) == 0 then TS.Print(TS.L("tank_none")) end
    for i = 1, table.getn(list) do
      local t = list[i]
      TS.Print(TS.Hex(TS.ClassColor(t.class)) .. t.name .. "|r  (" .. TS.L("src_" .. t.source) .. ")")
    end
  elseif cmd == "clear" then
    TS.db.tanks = {}
    TS.Print(TS.L("tank_cleared"))
    if TS.RefreshMenu then TS.RefreshMenu() end
  elseif cmd == "test" then
    TS.Announcer.Test()
  elseif cmd == "announce" then
    if rest == "on" or rest == "off" then TS.db.announce.enabled = (rest == "on") end
    TS.Print("Announcer: " .. OnOff(TS.db.announce.enabled))
    if TS.RefreshMenu then TS.RefreshMenu() end
  elseif cmd == "plates" then
    if rest == "on" or rest == "off" then TS.db.plates.enabled = (rest == "on") end
    TS.Print("Nameplates: " .. OnOff(TS.db.plates.enabled))
    if TS.RefreshMenu then TS.RefreshMenu() end
  elseif cmd == "lang" then
    if rest == "fr" or rest == "en" or rest == "auto" then
      TS.db.language = rest
      TS.ApplyLanguage()
      if TS.RefreshMenu then TS.RefreshMenu() end
    end
    TS.Print("Language: " .. TS.lang)
  else
    TS.Print(TS.L("help_title"))
    local keys = { "help_menu", "help_add", "help_remove", "help_list", "help_clear", "help_test", "help_toggle", "help_lang" }
    for i = 1, table.getn(keys) do DEFAULT_CHAT_FRAME:AddMessage("  " .. TS.L(keys[i])) end
  end
end

SLASH_TANKSUITE1 = "/tanksuite"
SLASH_TANKSUITE2 = "/tsuite"
SLASH_TANKSUITE3 = "/tks"
SlashCmdList["TANKSUITE"] = function(msg) TS.Safe(TS.Slash, msg) end
