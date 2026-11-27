-- AdeLazyBuffs events and slash commands.
-- Written for the Lua 5.0 client: no '#', no '%', no select(), no string.match.

local A = AdeLazyBuffs

local frame = CreateFrame("Frame", "AdeLazyBuffsFrame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("SPELLS_CHANGED")
frame:RegisterEvent("SPELLCAST_START")
frame:RegisterEvent("SPELLCAST_STOP")
frame:RegisterEvent("SPELLCAST_FAILED")
frame:RegisterEvent("SPELLCAST_INTERRUPTED")
frame:RegisterEvent("SPELLCAST_CHANNEL_START")
frame:RegisterEvent("SPELLCAST_CHANNEL_STOP")
frame:RegisterEvent("UI_ERROR_MESSAGE")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")

frame:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" then
    if arg1 == "AdeLazyBuffs" then
      A.Init()
      BINDING_NAME_ADELAZYBUFFS_NOW = A.T("Buff now")
    end
  elseif event == "PLAYER_ENTERING_WORLD" then
    local _, cls = UnitClass("player")
    A.cls = cls
    A.active = (A.PROFILES[cls] ~= nil)
    A.me = UnitName("player")
    A.swow = (type(SUPERWOW_VERSION) ~= "nil")
    if A.active then
      A.ScanBook()
      A.InstallHooks()
      A.InitMinimap()
    elseif not A.warned then
      A.warned = true
      A.Print(A.T("This class has no buff list yet: AdeLazyBuffs stays idle."))
    end
    A.Relabel()
  elseif event == "PLAYER_TARGET_CHANGED" then
    if A.active then A.Input("target change") end
  elseif event == "SPELLS_CHANGED" then
    if A.active then A.ScanBook() end
  elseif event == "SPELLCAST_START" then
    A.castUntil = GetTime() + (arg2 or 3000) / 1000 + 0.3
  elseif event == "SPELLCAST_CHANNEL_START" then
    A.castUntil = GetTime() + (arg1 or 3000) / 1000 + 0.3
  elseif event == "SPELLCAST_STOP" or event == "SPELLCAST_INTERRUPTED" or event == "SPELLCAST_CHANNEL_STOP" then
    A.castUntil = nil
    if event == "SPELLCAST_INTERRUPTED" and A.pending then A.pending.failed = true end
  elseif event == "SPELLCAST_FAILED" or event == "UI_ERROR_MESSAGE" then
    if event == "SPELLCAST_FAILED" then A.castUntil = nil end
    if A.pending and (GetTime() - A.pending.t) < 1.5 then
      A.pending.failed = true
      if A.DB and A.DB.debug then A.Print("game says: " .. tostring(arg1)) end
    end
  end
end)

-- one light pass per second (4 per second while a cast waits for its confirmation)
local acc = 0
frame:SetScript("OnUpdate", function()
  acc = acc + arg1
  local limit = 1
  if A.pending then limit = 0.25 end
  if A.autoSelfBack and GetTime() > A.autoSelfBack then
    A.autoSelfBack = nil
    SetCVar("autoSelfCast", "1")
  end
  if acc < limit then return end
  acc = 0
  if not A.active or not A.DB then return end
  local ok, err = pcall(A.Tick)
  if not ok and not A.errShown then
    A.errShown = true
    A.Print(A.TF("Error: %s", tostring(err)))
  end
end)

---------------------------------------------------------------------------
-- Slash commands: /alb, /lazybuffs
---------------------------------------------------------------------------

local function OnOff(b)
  if b then return A.T("on") end
  return A.T("off")
end

local function Switch(field, arg)
  if arg == "on" then A.DB[field] = true
  elseif arg == "off" then A.DB[field] = false
  else A.DB[field] = not A.DB[field] end
  A.RefreshWindow()
end

local function Status()
  local DB = A.DB
  A.Print(A.TF("Enabled: %s, auto-cast: %s, seals: %s, timer: %s", OnOff(DB.enabled), OnOff(DB.auto), OnOff(DB.seals), OnOff(DB.useTimer)))
  A.Print(A.TF("Seal: %s", DB.seal or A.T("none yet")))
end

local function List()
  local names = A.SortedNames()
  if table.getn(names) == 0 then
    A.Print(A.T("Nothing remembered."))
    return
  end
  local i
  for i = 1, table.getn(names) do
    local e = A.DB.targets[names[i]]
    local g = ""
    if e.greater then g = " " .. A.T("(Greater)") end
    A.Print(e.name .. ": " .. e.spell .. g)
  end
end

local function ForgetCmd(arg)
  if arg == "all" then
    A.Forget(nil)
    A.Print(A.T("Forgot everyone"))
    A.RefreshWindow()
    return
  end
  local found
  local k, e
  for k, e in pairs(A.DB.targets) do
    if e.name == arg or string.lower(e.name) == string.lower(arg) then found = e.name end
  end
  if found then
    A.ForgetPlayer(found)
    A.Print(A.TF("Forgot %s", found))
    A.RefreshWindow()
  else
    A.Print(A.TF("Nobody called %s is remembered", arg))
  end
end

SLASH_ADELAZYBUFFS1 = "/alb"
SLASH_ADELAZYBUFFS2 = "/lazybuffs"
SlashCmdList["ADELAZYBUFFS"] = function(msg)
  if not A.DB then return end
  local _, _, cmd, arg = string.find(msg or "", "^%s*(%S*)%s*(.-)%s*$")
  cmd = string.lower(cmd or "")
  if cmd == "" then
    A.ToggleWindow()
  elseif cmd == "on" then
    A.DB.enabled = true
    A.RefreshWindow()
    Status()
  elseif cmd == "off" then
    A.DB.enabled = false
    A.RefreshWindow()
    Status()
  elseif cmd == "auto" then
    Switch("auto", string.lower(arg))
    Status()
  elseif cmd == "seal" then
    Switch("seals", string.lower(arg))
    Status()
  elseif cmd == "timer" then
    Switch("useTimer", string.lower(arg))
    Status()
  elseif cmd == "debug" then
    Switch("debug", string.lower(arg))
    A.Print("debug: " .. OnOff(A.DB.debug))
  elseif cmd == "size" then
    local v = tonumber(arg)
    if v then
      if v < 8 then v = 8 elseif v > 64 then v = 64 end
      A.DB.remindSize = math.floor(v + 0.5)
      A.RefreshReminder()
      A.RefreshWindow()
    end
    A.Print(A.TF("Reminder text size: %s", A.DB.remindSize))
  elseif cmd == "now" then
    AdeLazyBuffs_Now()
  elseif cmd == "list" then
    List()
  elseif cmd == "status" then
    Status()
  elseif cmd == "why" then
    A.Why()
  elseif cmd == "forget" and arg ~= "" then
    ForgetCmd(arg)
  elseif cmd == "lang" then
    arg = string.lower(arg)
    if arg == "en" or arg == "ru" then A.DB.lang = arg else A.DB.lang = nil end
    A.Relabel()
  else
    A.Print(A.T("Commands: /alb (window), on, off, auto on|off, seal on|off, timer on|off, now, size <8-64>, list, why, debug on|off, forget <name>|all, lang auto|en|ru"))
  end
end
