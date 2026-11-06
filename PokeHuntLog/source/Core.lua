-- PokeHuntLog: shared namespace, saved variables, helpers and slash commands.
-- Target client is WoW 1.12.1 (Lua 5.0): no '#', no '%', no string.match, varargs via 'arg'.

PokeHuntLog = {}
local HPL = PokeHuntLog

HPL.VERSION = "2.0.1"
HPL.DB_VERSION = 1
HPL.MAX_LEVEL = 60
HPL.TAME_BEAST_SPELL_ID = 1515
HPL.TAME_BEAST_NAME = "Tame Beast"
HPL.TAME_WINDOW = 60          -- seconds between starting Tame Beast and the pet appearing
HPL.PREFIX = "|cffabd473PokeHuntLog:|r "

HPL.FAMILY_ICONS = {
  ["Bat"] = "Ability_Hunter_Pet_Bat",
  ["Bear"] = "Ability_Hunter_Pet_Bear",
  ["Boar"] = "Ability_Hunter_Pet_Boar",
  ["Carrion Bird"] = "Ability_Hunter_Pet_Vulture",
  ["Cat"] = "Ability_Hunter_Pet_Cat",
  ["Crab"] = "Ability_Hunter_Pet_Crab",
  ["Crocolisk"] = "Ability_Hunter_Pet_Crocolisk",
  ["Gorilla"] = "Ability_Hunter_Pet_Gorilla",
  ["Hyena"] = "Ability_Hunter_Pet_Hyena",
  ["Owl"] = "Ability_Hunter_Pet_Owl",
  ["Raptor"] = "Ability_Hunter_Pet_Raptor",
  ["Scorpid"] = "Ability_Hunter_Pet_Scorpid",
  ["Spider"] = "Ability_Hunter_Pet_Spider",
  ["Tallstrider"] = "Ability_Hunter_Pet_Tallstrider",
  ["Turtle"] = "Ability_Hunter_Pet_Turtle",
  ["Wind Serpent"] = "Ability_Hunter_Pet_WindSerpent",
  ["Wolf"] = "Ability_Hunter_Pet_Wolf",
}
HPL.UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

function HPL.Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage(HPL.PREFIX .. tostring(msg))
end

-- Shown in chat only with /petlog debug on.
function HPL.Debug(msg)
  if HPL.db and HPL.db.settings.debug then
    DEFAULT_CHAT_FRAME:AddMessage("|cff888888[PokeHuntLog debug]|r " .. tostring(msg))
  end
end

function HPL.FamilyIcon(family)
  local icon = family and HPL.FAMILY_ICONS[family]
  if icon then
    return "Interface\\Icons\\" .. icon
  end
  return HPL.UNKNOWN_ICON
end

-- Lowercase and strip everything but letters and digits, for lookup keys.
function HPL.Key(s)
  if not s then return "" end
  local k = string.gsub(s, "[^%w]", "")
  return string.lower(k)
end

function HPL.CharKey()
  return (UnitName("player") or "?") .. " - " .. (GetRealmName() or "?")
end

function HPL.CharName(charKey)
  if not charKey then return "?" end
  local dash = string.find(charKey, " - ", 1, true)
  if dash then
    return string.sub(charKey, 1, dash - 1)
  end
  return charKey
end

function HPL.IsHunter()
  local _, class = UnitClass("player")
  return class == "HUNTER"
end

function HPL.FormatDate(t)
  if not t then return "?" end
  return date("%d %b %Y", t)
end

-- The 1.12 dialog background art is partly see-through, so whatever sits behind a window
-- (quest tracker, chat, the world) reads through the text. A solid layer underneath fixes it.
function HPL.Opaque(f, pad)
  if f.phlSolid then return end
  pad = pad or 11
  f.phlSolid = f:CreateTexture(nil, "BACKGROUND")
  f.phlSolid:SetTexture(0.05, 0.05, 0.07, 1)
  f.phlSolid:SetPoint("TOPLEFT", f, "TOPLEFT", pad, -pad)
  f.phlSolid:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -pad, pad)
end

-- Run func once after 'seconds'. Uses one shared frame whose OnUpdate is removed when idle.
local timers = {}
local timerFrame = CreateFrame("Frame")
local function TimerUpdate()
  local now = GetTime()
  local i = 1
  while i <= table.getn(timers) do
    local t = timers[i]
    if now >= t.at then
      table.remove(timers, i)
      local ok, err = pcall(t.func)
      if not ok then HPL.Print("error: " .. tostring(err)) end
    else
      i = i + 1
    end
  end
  if table.getn(timers) == 0 then
    timerFrame:SetScript("OnUpdate", nil)
  end
end

function HPL.After(seconds, func)
  table.insert(timers, { at = GetTime() + seconds, func = func })
  timerFrame:SetScript("OnUpdate", TimerUpdate)
end

-- SuperWoW GUIDs look like "0xF13000178A00ABCD": 4 hex digits of type, 6 of creature entry, 6 of spawn counter.
-- Returns possible NPC ids, best guess first, because the exact layout isn't confirmed in game yet.
function HPL.NpcIdsFromGuid(guid)
  if type(guid) ~= "string" then return nil end
  local hex = guid
  local prefix = string.sub(hex, 1, 2)
  if prefix == "0x" or prefix == "0X" then
    hex = string.sub(hex, 3)
  end
  local len = string.len(hex)
  if len < 16 then
    hex = string.rep("0", 16 - len) .. hex
  end
  local ids = {}
  local a = tonumber(string.sub(hex, 5, 10), 16)
  if a and a > 0 then table.insert(ids, a) end
  local b = tonumber(string.sub(hex, 5, 8), 16)
  if b and b > 0 and b ~= a then table.insert(ids, b) end
  return ids
end

function HPL.UnitGuid(unit)
  if not SUPERWOW_VERSION then return nil end
  local exists, guid = UnitExists(unit)
  if exists and type(guid) == "string" then
    return guid
  end
  return nil
end

local function NewDB()
  return {
    version = HPL.DB_VERSION,
    settings = {
      showUncaught = false,
      notify = true,
      minimapAngle = 215,
      minimapHidden = false,
      collapsed = {},
      debug = false,
      tooltip = true,
      trainerReminder = true,
    },
    pets = {},     -- [charKey] = { pet records }
    custom = {},   -- [skinId] = skins discovered in game that aren't in the bundled database
    stats = { tames = 0 },
  }
end

-- Fill in anything missing so older or damaged saved data can't break the addon.
local function UpgradeDB(db)
  local fresh = NewDB()
  for k, v in pairs(fresh) do
    if type(db[k]) ~= type(v) then
      db[k] = v
    end
  end
  for k, v in pairs(fresh.settings) do
    if db.settings[k] == nil then
      db.settings[k] = v
    end
  end
  if type(db.settings.collapsed) ~= "table" then db.settings.collapsed = {} end
  if type(db.stats.tames) ~= "number" then db.stats.tames = 0 end
  db.version = HPL.DB_VERSION
  return db
end

function HPL.PetsFor(charKey)
  local pets = HPL.db.pets[charKey]
  if not pets then
    pets = {}
    HPL.db.pets[charKey] = pets
  end
  return pets
end

-- Called after any change to pets or settings.
function HPL.Changed()
  HPL.RebuildCollection()
  if HPL.RefreshUI then HPL.RefreshUI() end
end

local function FindPetByName(name)
  if not name or name == "" then return nil end
  local want = string.lower(name)
  local found, foundChar, foundIndex
  for charKey, list in pairs(HPL.db.pets) do
    for i = 1, table.getn(list) do
      if string.lower(list[i].name or "") == want then
        if charKey == HPL.CharKey() or not found then
          found, foundChar, foundIndex = list[i], charKey, i
        end
      end
    end
  end
  return found, foundChar, foundIndex
end

local function SlashHandler(msg)
  msg = msg or ""
  local _, _, cmd, rest = string.find(msg, "^%s*(%S*)%s*(.-)%s*$")
  cmd = string.lower(cmd or "")

  if cmd == "" or cmd == "show" then
    HPL.ToggleWindow()
  elseif cmd == "uncaught" then
    HPL.db.settings.showUncaught = not HPL.db.settings.showUncaught
    HPL.Print("uncaught skins are now " .. (HPL.db.settings.showUncaught and "shown" or "hidden") .. ".")
    HPL.Changed()
  elseif cmd == "minimap" then
    HPL.db.settings.minimapHidden = not HPL.db.settings.minimapHidden
    if HPL.UpdateMinimapButton then HPL.UpdateMinimapButton() end
  elseif cmd == "notify" then
    HPL.db.settings.notify = not HPL.db.settings.notify
    HPL.Print("new skin messages " .. (HPL.db.settings.notify and "on" or "off") .. ".")
  elseif cmd == "range" or cmd == "feed" or cmd == "swing" or cmd == "arcane" or cmd == "ammo" or cmd == "move" then
    HPL.ToolsMoved(true)
  elseif cmd == "training" or cmd == "train" then
    HPL.ToggleTraining()
  elseif cmd == "trainer" then
    HPL.db.settings.trainerReminder = not HPL.db.settings.trainerReminder
    HPL.Print("training reminders " .. (HPL.db.settings.trainerReminder and "on" or "off") .. ".")
  elseif cmd == "export" then
    HPL.ShowExport()
  elseif cmd == "tooltip" then
    HPL.db.settings.tooltip = not HPL.db.settings.tooltip
    HPL.Print("beast tooltips " .. (HPL.db.settings.tooltip and "on" or "off") .. ".")
  elseif cmd == "version" then
    HPL.Print("version " .. HPL.VERSION .. ".")
  elseif cmd == "help" then
    HPL.ShowHelp()
  elseif cmd == "scan" then
    HPL.ScanActivePet("scan")
    HPL.Print("checked your current pet.")
  elseif cmd == "forget" or cmd == "unassign" then
    local pet, charKey, index = FindPetByName(rest)
    if not pet then
      HPL.Print("no saved pet named '" .. rest .. "'.")
    elseif cmd == "forget" then
      table.remove(HPL.db.pets[charKey], index)
      HPL.Print("forgot " .. pet.name .. " (" .. HPL.CharName(charKey) .. ").")
      HPL.Changed()
    else
      pet.skin = nil
      pet.match = "manual"
      HPL.Print(pet.name .. " moved to 'Unknown skin'. Open /petlog to assign it.")
      HPL.Changed()
    end
  elseif cmd == "debug" then
    if rest == "on" or rest == "off" then
      HPL.db.settings.debug = (rest == "on")
      HPL.Print("debug messages " .. rest .. ".")
    else
      HPL.PrintDebugInfo()
    end
  elseif cmd == "reset" then
    if rest == "confirm" then
      PokeHuntLogDB = NewDB()
      HPL.db = PokeHuntLogDB
      HPL.BuildIndex()
      HPL.Changed()
      HPL.Print("all saved pets and settings were reset.")
    else
      HPL.Print("this deletes your whole pet log. Type '/petlog reset confirm' to do it.")
    end
  else
    HPL.Print("commands (type /petlog help for the how-to window):")
    HPL.Print("/petlog - open or close the log")
    HPL.Print("/petlog help - how to use PokeHuntLog")
    HPL.Print("/petlog version - show which version you have")
    HPL.Print("/petlog uncaught - show or hide skins you haven't caught")
    HPL.Print("/petlog minimap - show or hide the minimap button")
    HPL.Print("/petlog notify - turn new skin messages on or off")
    HPL.Print("/petlog tooltip - turn the \"new skin\" line on beast tooltips on or off")
    HPL.Print("/petlog training - what your pet and you can learn")
    HPL.Print("/petlog trainer - turn training reminders on or off")
    HPL.Print("/petlog export - copy your collection as text")
    HPL.Print("/petlog scan - re-check your current pet")
    HPL.Print("/petlog unassign <pet name> - clear a pet's skin so you can pick it again")
    HPL.Print("/petlog forget <pet name> - remove a saved pet")
    HPL.Print("/petlog debug - print pet and target details (for bug reports)")
    HPL.Print("/petlog reset - delete everything")
  end
end

-- 2.0 moved the range icon, feed reminder, swing timer, Arcane Shot icon and ammo warnings into Class
-- Toolkit, a separate addon for every class. Hunters without it are told once, and any old command says
-- where they went.
local TOOLKIT_URL = "github.com/notforever-ship-it/ClassToolkit"

function HPL.ToolsMoved(asked)
  local has = IsAddOnLoaded("ClassToolkit")
  if has then
    if asked then HPL.Print("the hunter tools live in Class Toolkit now: type /ctk.") end
  else
    HPL.Print("the range icon, feed reminder, swing timer, Arcane Shot icon and ammo warnings moved to " ..
      "Class Toolkit, a separate addon for every class. Get it from " .. TOOLKIT_URL .. " (RavenLaunch can " ..
      "install it from that address).")
  end
end

local notice = CreateFrame("Frame")
notice:RegisterEvent("PLAYER_ENTERING_WORLD")
notice:SetScript("OnEvent", function()
  notice:UnregisterEvent("PLAYER_ENTERING_WORLD")
  HPL.After(10, function()
    if HPL.db and HPL.IsHunter() and not HPL.db.stats.toolsMovedNotice then
      HPL.db.stats.toolsMovedNotice = true
      HPL.ToolsMoved(false)
    end
  end)
end)

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function()
  if event ~= "ADDON_LOADED" or arg1 ~= "PokeHuntLog" then return end
  loader:UnregisterEvent("ADDON_LOADED")

  if type(PokeHuntLogDB) ~= "table" then
    PokeHuntLogDB = NewDB()
  end
  HPL.db = UpgradeDB(PokeHuntLogDB)

  HPL.BuildIndex()
  HPL.RebuildCollection()
  HPL.InitTracker()
  HPL.InitMinimapButton()
  HPL.InitTooltip()
  HPL.InitTraining()

  SLASH_POKEHUNTLOG1 = "/petlog"
  SLASH_POKEHUNTLOG2 = "/phl"
  SlashCmdList["POKEHUNTLOG"] = SlashHandler
end)
