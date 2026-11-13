local _G = ShaguTweaks.GetGlobalEnv()
local L = ShaguTweaks.L
local API = ShaguTweaks.API
local libspell = ShaguTweaks.libspell
local libtipscan = ShaguTweaks.libtipscan
local hooksecurefunc = ShaguTweaks.hooksecurefunc
if ShaguTweaks.GetExpansion() ~= "vanilla" then return end

local valid_units = {}
valid_units["pet"] = true
valid_units["player"] = true
valid_units["target"] = true
valid_units["mouseover"] = true

valid_units["pettarget"] = true
valid_units["playertarget"] = true
valid_units["targettarget"] = true
valid_units["mouseovertarget"] = true
valid_units["targettargettarget"] = true

for i=1,4 do valid_units["party" .. i] = true end
for i=1,4 do valid_units["partypet" .. i] = true end
for i=1,40 do valid_units["raid" .. i] = true end
for i=1,40 do valid_units["raidpet" .. i] = true end

for i=1,4 do valid_units["party" .. i .. "target"] = true end
for i=1,4 do valid_units["partypet" .. i .. "target"] = true end
for i=1,40 do valid_units["raid" .. i .. "target"] = true end
for i=1,40 do valid_units["raidpet" .. i .. "target"] = true end

valid_units.focus = true
valid_units.focustarget = true
local libcast = CreateFrame("Frame", "ShaguTweaksEnemyCast")
ShaguTweaks.libcast = libcast
local player = UnitName("player")
local _, playerClass = UnitClass("player")
local useClassicCasts = API and API.casts
local needsCustomHunter = useClassicCasts and playerClass == "HUNTER"
local lastrank
local scanner
local function GetScanner()
  if not scanner then scanner = libtipscan:GetScanner("libcast") end
  return scanner
end
libcast.db = {}
if needsCustomHunter then libcast.db[player] = {} end

function libcast:Prune(now)
  for key, cast in pairs(self.db) do
    if key ~= player and (not cast.start or not cast.casttime or cast.start + cast.casttime/1000 <= now) then self.db[key] = nil end
  end
end
local function ReadCached(key, channel)
  local cast = key and libcast.db[key]
  if not cast or not cast.cast or not cast.start or not cast.casttime then return end
  if cast.start + cast.casttime/1000 <= GetTime() then
    if key == player then cast.cast = nil else libcast.db[key] = nil end
    return
  end
  if (cast.channel and true or false) ~= channel then return end
  return cast.cast, cast.rank or "", "", cast.icon, cast.start*1000,
    cast.start*1000 + cast.casttime, nil
end
ShaguTweaks.UnitCastingInfo = function(unit)
  if valid_units[unit] then
    local name, rank, text, icon, startTime, endTime, trade = API.GetCastInfo(unit)
    if name then return name, rank, text, icon, startTime, endTime, trade end
    -- A missing native cast is authoritative. Only the local Hunter's custom
    -- emulation may fill a native gap; never consult a name-keyed remote cache.
    if unit ~= "player" or not needsCustomHunter then return end
    unit = player
  end
  return ReadCached(unit, false)
end
ShaguTweaks.UnitChannelInfo = function(unit)
  if valid_units[unit] then
    return API.GetChannelInfo(unit)
  end
  return ReadCached(unit, true)
end

-- No ClassicAPI remote event mirror or combat-text parser. Official castbars
-- query ClassicAPI directly; optional SuperWoW owns timed GUID records only.
if needsCustomHunter then
  libcast:RegisterEvent("SPELLCAST_STOP")
  libcast:RegisterEvent("SPELLCAST_FAILED")
  libcast:RegisterEvent("SPELLCAST_INTERRUPTED")
  libcast:SetScript("OnEvent", function()
    local cast = libcast.db[player]
    if cast then cast.cast = nil end
    lastrank = nil
  end)
--[[ Custom Casts
  Enable Castbars for spells that don't have a castbar by default
  (e.g Multi-Shot and Aimed Shot)
]]--
local aimedshot = L["customcast"]["AIMEDSHOT"]
local multishot = L["customcast"]["MULTISHOT"]

libcast.customcast = {}
libcast.customcast[strlower(aimedshot)] = function(begin, duration)
  if begin then
    local duration = duration or 3000

    for i=1,32 do
      local buff = UnitBuff("player", i)
      if buff == "Interface\\Icons\\Racial_Troll_Berserk" then
        local berserk = 0.3
        if((UnitHealth("player")/UnitHealthMax("player")) >= 0.40) then
          berserk = (1.30 - (UnitHealth("player") / UnitHealthMax("player"))) / 3
        end
        duration = duration / (1 + berserk)
      elseif buff == "Interface\\Icons\\Ability_Hunter_RunningShot" then
        duration = duration / 1.4
      elseif buff == "Interface\\Icons\\Ability_Warrior_InnerRage" then
        duration = duration / 1.3
      elseif buff == "Interface\\Icons\\Inv_Trinket_Naxxramas04" then
        duration = duration / 1.2
      end
    end

    local _,_, lag = GetNetStats()
    local start = GetTime() + lag/1000

    -- add cast action to the database
    libcast.db[player].cast = aimedshot
    libcast.db[player].rank = lastrank
    libcast.db[player].start = start
    libcast.db[player].casttime = duration
    libcast.db[player].icon = "Interface\\Icons\\Inv_spear_07"
    libcast.db[player].channel = nil
  else
    -- remove cast action to the database
    libcast.db[player].cast = nil
    libcast.db[player].rank = nil
    libcast.db[player].start = nil
    libcast.db[player].casttime = nil
    libcast.db[player].icon = nil
    libcast.db[player].channel = nil
  end
end

libcast.customcast[strlower(multishot)] = function(begin, duration)
  if begin then
    local duration = duration or 500

    for i=1,32 do
      local buff = UnitBuff("player", i)
      if buff == "Interface\\Icons\\Racial_Troll_Berserk" then
        local berserk = 0.3
        if((UnitHealth("player")/UnitHealthMax("player")) >= 0.40) then
          berserk = (1.30 - (UnitHealth("player") / UnitHealthMax("player"))) / 3
        end
        duration = duration / (1 + berserk)
      elseif buff == "Interface\\Icons\\Ability_Hunter_RunningShot" then
        duration = duration / 1.4
      elseif buff == "Interface\\Icons\\Ability_Warrior_InnerRage" then
        duration = duration / 1.3
      elseif buff == "Interface\\Icons\\Inv_Trinket_Naxxramas04" then
        duration = duration / 1.2
      end
    end

    local _,_, lag = GetNetStats()
    local start = GetTime() + lag/1000

    -- add cast action to the database
    libcast.db[player].cast = multishot
    libcast.db[player].rank = lastrank
    libcast.db[player].start = start
    libcast.db[player].casttime = duration
    libcast.db[player].icon = "Interface\\Icons\\Ability_upgrademoonglaive"
    libcast.db[player].channel = nil
  else
    -- remove cast action to the database
    libcast.db[player].cast = nil
    libcast.db[player].rank = nil
    libcast.db[player].start = nil
    libcast.db[player].casttime = nil
    libcast.db[player].icon = nil
    libcast.db[player].channel = nil
  end
end

local function GetCustomCast(spell)
  if not spell then return end

  local lowerSpell = strlower(spell)
  for custom, func in pairs(libcast.customcast) do
    if strfind(lowerSpell, custom) then
      return func
    end
  end
end

local function CastCustom(spell)
  local func = GetCustomCast(spell)
  if func and not ShaguTweaks.UnitCastingInfo("player") then
    func(true)
  end
end

hooksecurefunc("CastSpell", function(id, bookType)
  local spellName, rank = GetSpellName(id, bookType)
  if not GetCustomCast(spellName) then return end
  lastrank = rank

  if GetSpellCooldown(id, bookType) ~= 0 then
    CastCustom(spellName)
  end
end)

hooksecurefunc("CastSpellByName", function(spell, target)
  -- Only Aimed Shot and Multi-Shot need the legacy custom-cast emulation.
  -- Ordinary macro casts can return immediately instead of resolving their
  -- spellbook rank on every invocation.
  local custom = GetCustomCast(spell)
  if not custom then return end

  _, lastrank = libspell.GetSpellInfo(spell)

  for i=1,120 do
    -- detect if any cast is ongoing
    if IsCurrentAction(i) then
      if not ShaguTweaks.UnitCastingInfo(player) then
        custom(true)
      end
      return
    end
  end
end)

hooksecurefunc("UseAction", function(slot, target, button)
  -- ClassicAPI identifies action slots in native code. This avoids building a
  -- hidden tooltip for every button press, while keeping the old scanner as a
  -- cold compatibility path for an older ClassicAPI action surface.
  if API and API.actioninfo and API.GetActionInfo then
    local actionType, actionID = API.GetActionInfo(slot)

    if actionType == "macro" then
      -- The real spell selected by a conditional macro is handled later by
      -- CastSpellByName. Do not guess it from the macro's first cast line.
      return
    elseif actionType == "item" then
      lastrank = nil
      return
    elseif actionType == "spell" and actionID then
      local spellName, rank = API.GetSpellInfo(actionID)
      if not GetCustomCast(spellName) then return end
      lastrank = rank
      if not IsCurrentAction(slot) then return end
      CastCustom(spellName)
      return
    elseif actionType then
      return
    end
  end

  if GetActionText(slot) or not IsCurrentAction(slot) then return end
  local tip = GetScanner()
  tip:SetAction(slot)
  local spellName, rank = tip:Line(1)

  lastrank = rank
  CastCustom(spellName)
end)
end
