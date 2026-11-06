-- Name: Tattler
-- License: LGPL v2.1

-- stop loading addon if no superwow
if not SetAutoloot then
  DEFAULT_CHAT_FRAME:AddMessage("[|cff00ff00Tattler|r] requires |cffffd200SuperWoW|r to operate.")
  return
end

local DEBUG_MODE = false

local success = true
local failure = nil

local amcolor = {
  blue = format("|c%02X%02X%02X%02X", 1, 41,146,255),
  red = format("|c%02X%02X%02X%02X",1, 255, 0, 0),
  green = format("|c%02X%02X%02X%02X",1, 22, 255, 22),
  yellow = format("|c%02X%02X%02X%02X",1, 255, 255, 0),
  orange = format("|c%02X%02X%02X%02X",1, 255, 146, 24),
  red = format("|c%02X%02X%02X%02X",1, 255, 0, 0),
  gray = format("|c%02X%02X%02X%02X",1, 187, 187, 187),
  gold = format("|c%02X%02X%02X%02X",1, 255, 255, 154),
  blizzard = format("|c%02X%02X%02X%02X",1, 180,244,1),
}

local function colorize(msg,color)
  local c = color or ""
  return c..msg..FONT_COLOR_CODE_CLOSE
end

local function showOnOff(setting)
  local b = "d"
  return setting and colorize("On",amcolor.blue) or colorize("Off",amcolor.red)
end

local function alprint(msg)
  DEFAULT_CHAT_FRAME:AddMessage(msg)
end

local function debug_print(text)
    if DEBUG_MODE == true then DEFAULT_CHAT_FRAME:AddMessage(text) end
end

-------------------------------------------------
-- Table funcs
-------------------------------------------------

local function isempty(t)
  for _ in pairs(t) do
    return false
  end
  return true
end

local function iskey(table,item)
  for k,v in pairs(table) do
    if item == k then
      return true
    end
  end
  return false
end

local function iselem(table,item)
  for k,v in pairs(table) do
    if item == k then
      return true
    end
  end
  return false
end

local function wipe(table)
  for k,_ in pairs(table) do
    table[k] = nil
  end
end

-------------------------------------------------
-- Data
-------------------------------------------------

-------------------------------------------------

local Tattler = CreateFrame("Frame","Tattler")

local live_raid = {}
local function RaidUpdate()
  local t = {}
  for i=1,GetNumRaidMembers() do
    local name,rank,_,_,class,_ = GetRaidRosterInfo(i)
    local _,guid = UnitExists("raid"..i)
    t[guid] = true
    -- alprint(name .. " " .. guid)
  end
  live_raid = t
end

local LOCAL_RAID_CLASS_COLORS = {
  ["HUNTER"] = { r = 0.67, g = 0.83, b = 0.45, colorStr = "ffabd473" },
  ["WARLOCK"] = { r = 0.58, g = 0.51, b = 0.79, colorStr = "ff9482c9" },
  ["PRIEST"] = { r = 1.0, g = 1.0, b = 1.0, colorStr = "ffffffff" },
  ["PALADIN"] = { r = 0.96, g = 0.55, b = 0.73, colorStr = "fff58cba" },
  ["MAGE"] = { r = 0.41, g = 0.8, b = 0.94, colorStr = "ff69ccf0" },
  ["ROGUE"] = { r = 1.0, g = 0.96, b = 0.41, colorStr = "fffff569" },
  ["DRUID"] = { r = 1.0, g = 0.49, b = 0.04, colorStr = "ffff7d0a" },
  ["SHAMAN"] = { r = 0.0, g = 0.44, b = 0.87, colorStr = "ff0070de" },
  ["WARRIOR"] = { r = 0.78, g = 0.61, b = 0.43, colorStr = "ffc79c6e" },
  ["DEATHKNIGHT"] = { r = 0.77, g = 0.12 , b = 0.23, colorStr = "ffc41f3b" },
  ["MONK"] = { r = 0.0, g = 1.00 , b = 0.59, colorStr = "ff00ff96" },
}

local function Colorize(text,hex)
  return DEBUG and text or ("|c"..hex..text.."|r")
  -- return "\124c"..hex..text.."\124r"
end

local function ColorizeName(unit)
  local _,c = UnitClass(unit)
  -- erroring on someone, someone offline maybe
  local cc = (LOCAL_RAID_CLASS_COLORS[c] and LOCAL_RAID_CLASS_COLORS[c].colorStr) or "ffc0c0c0"
  -- if not cc then cc = ffc0c0c0 end
  return Colorize(UnitName(unit),cc)
end

function TattleBuff(user,rank,spell,who,max)
  local u = ColorizeName(user)
  local w = who and who ~= "" and ColorizeName(who)

  -- x has cast rank [x] [spell] on [target], max rank is [y]
  local local_s,local_s2
  if w then
    -- local_s = format("[%s] has %s a %s %s [%s]",u,how,used,at,w)
    local_s = format("[%s] has cast Rank %d %s on %s, max rank is %d",u,rank,spell,w,max)
    local_s2 = format("[%s] has cast Rank %d %s on %s, max rank is %d",user,rank,spell,who,max)
  else
    local_s = format("[%s] has cast Rank %d %s, max rank is %d",u,rank,spell,max)
    local_s2 = format("[%s] has cast Rank %d %s, max rank is %d",user,rank,spell,max)
    -- local_s = format("[%s] has %s a %s",u,how,used)
  end
  -- SendChatMessage(local_s,"RAID")
  DEFAULT_CHAT_FRAME:AddMessage(local_s)
end

local tattled = {}
local report_dummies = true
-- local player_guid = nil

local tattler_version = GetAddOnMetadata("Tattler", "Version")
local tattler_prefix = "Tattler:"..tattler_version

local tattles = {
  -- spell_id: object, verb, adverb, color, location/metadata
  -- [6603]  = { "Attack", "done", "to", "ff1eff00", "zone" }, -- testing
  [21343] = { "Snowball", "has thrown a", "at", "ff1eff00", "raid", ignore_charmed = true, ignore_pet = true },
  [23065] = { "Happy Fun Rock", "has thrown a", "at", "ff1eff00", "any" },
  [23135] = { "Heavy Leather Ball", "has thrown a", "at", "ff1eff00", "any" },
  [24733] = { "Bat Cosume", "has placed a", "on", "ff1eff00", "raid" },
  [24737] = { "Ghost Cosume", "has placed a", "on", "ff1eff00", "raid" },
  [24719] = { "Leper Gnome Cosume", "placed a", "on", "ff1eff00", "raid" },
  [24718] = { "Ninja Cosume", "has placed a", "on", "ff1eff00", "raid" },
  [24717] = { "Pirate Cosume", "has placed a", "on", "ff1eff00", "raid" },
  [24724] = { "Skeleton Cosume", "has placed a", "on", "ff1eff00", "raid" },
  [24720] = { "Random Cosume", "has placed a", "on", "ff1eff00", "raid" },
  [24741] = { "Wisp Cosume", "has placed a", "on", "ff1eff00", "raid" },
  [21358] = { "Rune of the Firelord", "has doused a", nil, "ff1eff00", "douse" },
  [45304] = { "Rune of the Firelord", "has doused a", nil, "ff1eff00", "douse" },
  [46001] = { "Mailbox", "has deployed a", nil, "ff1eff00", "zone" },
  [27571] = { "Cascade of Roses", "has showered a", "on", "ffff86e0", "any" },
  [45407] = { "Oranges", "is summoning", nil, "ff1eff00", "zone" },
}

-- DEBUG = 1

function Tattler:Tattle(spell_id,caster,target,extra)
  if target and UnitExists(target) then
    if tattles[spell_id].ignore_charmed and UnitIsCharmed(target) then
      return end
    if false and tattles[spell_id].ignore_pet then -- false because we curently exclude pets in CASTEVENT anyway
      for i=1,GetNumRaidMembers() do
        if UnitIsUnit(target,"raidpet"..i) then
          return
        end
      end
    end
  end -- ignore tattling on mc/pet

  local u = ColorizeName(caster)
  local w = target and target ~= "" and ColorizeName(target)
  local ex = extra or ""

  local verb = tattles[spell_id][2]
  local adverb = tattles[spell_id][3]
  local color = tattles[spell_id][4]
  local meta = tattles[spell_id][5]
  local item = Colorize(tattles[spell_id][1], color)
  
  if meta == "raid" and not IsInInstance() then return end
  if meta == "zone" then
    ex = not IsInInstance() and (" at " .. extra) or (" inside " .. extra)
  end
  if meta == "douse" then
    ex = " " .. extra .. "/7"
  end


  local local_s = ""
  if w then
    local_s = format("[%s] %s %s %s [%s]%s",u,verb,item,adverb,w,ex)
  else
    local_s = format("[%s] %s %s%s",u,verb,item,ex)
  end
  SendChatMessage(local_s,"RAID")
end

function Tattler.UNIT_CASTEVENT(caster,target,action,spell_id,cast_time)
  -- skip spells we don't track and non-player actions
  if not tattles[spell_id] then return end
  -- don't currently care about things from mobs
  if string.sub(caster,3,3) == "F" then return end
  -- don't currently care about things hitting mobs, this currently excludes pets too
  if string.sub(target,3,3) == "F" then return end
  -- don't care about self-griefs
  if caster == target then return end

  local extra = nil
  local meta = tattles[spell_id][5]

  -- if action == "MAINHAND" then action = "CAST" end
  if UnitInRaid(caster) and action == "CAST" then
    if meta == "zone" then
      local sz = GetSubZoneText()
      extra = (sz and sz ~= "" and sz) or GetRealZoneText()
    end
    if meta == "douse" then
      for i=1,GetNumSavedInstances() do
        instanceName, instanceID, instanceReset = GetSavedInstanceInfo(i);
        -- print(instanceName)
        if instanceName == "Molten Core" then
          if TattlerDB.douse_tracking.id ~= instanceID then TattlerDB.douse_tracking.count = 0 end
          TattlerDB.douse_tracking.id = instanceID
          TattlerDB.douse_tracking.count = TattlerDB.douse_tracking.count + 1
          extra = TattlerDB.douse_tracking.count
          break
        end
      end
    end

    SendAddonMessage(tattler_prefix, Tattler:FormMsg(spell_id,caster,target,extra), "RAID")
  end
end

function Tattler.ADDON_LOADED(addon_name)
  if addon_name ~= "Tattler" then return end
  TattlerDB = TattlerDB or {}
  TattlerDB.douse_tracking = TattlerDB.douse_tracking or { id = 0, count = 0 }
  RequestRaidInfo()
end

-- fight ended, pull raid info in case it was a boss for douse id
function Tattler.PLAYER_REGEN_ENABLED()
  if GetRealZoneText() == "Molten Core" then
    RequestRaidInfo()
  end
end

function Tattler.UPDATE_INSTANCE_INFO()
  if GetNumSavedInstances() == 0 then
    TattlerDB.douse_tracking = { id = 0, count = 0 }
  end
end

-- tell us if ver1 is >= ver 2
function Tattler:VersionGTE(ver1,ver2)
  local v1,v2 = {},{}
  local len1,len2 = 0,0
  for n in string.gfind(ver1,"(%d+).?") do
    table.insert(v1,tonumber(n))
    len1 = len1 + 1
    -- print(n)
  end
  for n in string.gfind(ver2,"(%d+).?") do
    table.insert(v2,tonumber(n))
    len2 = len2 + 1
    -- print(n)
  end

  -- pick the larger to ensure a full run
  for i=1,(len1 > len2 and len1 or len2) do
    if v1[i] and v2[i] then
      if v1[i] == v2[i] then
        -- do nothing this round
      else
        return v1[i] > v2[i]
      end
    elseif v1[i] then
      return true
    else
      return false
    end
  end
end

function Tattler:FormMsg(spell_id,caster,target,extra)
  return format("%d:%s,%s,%s",spell_id,caster,target or "",extra or "")
end
function Tattler:ParseMsg(msg)
  local _,_,spell_id,caster,target,extra = string.find(msg,"(%d+):(%w+),(%w*),([%w'. ]*)")
  return tonumber(spell_id),caster,target,extra
end

-- store the tattles you see, group by msg
local current_tattles = {}
function Tattler.CHAT_MSG_ADDON(prefix,msg,channel,sender)
  local _,_,ver = string.find(prefix,"^Tattler:(.+)")
  if not ver then return end
-- TODO is this right? should this consider the whole msg or just the spell id, target,caster ?

  local spell_id,caster,target,extra = Tattler:ParseMsg(msg)
  local uid = spell_id..caster..target

  current_tattles[uid] = current_tattles[uid] or { elapsed = 0, copies = {} }
  table.insert(current_tattles[uid].copies, { version = ver, sender = sender, spell_id = spell_id, target = target, caster = caster, extra = extra })

  Tattler:SetScript("OnUpdate", function ()
    for msg,data in pairs(current_tattles) do
      data.elapsed = data.elapsed + arg1
      -- in 0.2 secs check msg's, clear out everything by version, if you're first in the list then tattle
      if data.elapsed > 0.2 then
        local _,temp = next(data.copies)
        -- keep first entry of highest version
        for _,copy in ipairs(data.copies) do
          temp = Tattler:VersionGTE(copy.version,temp.version) and copy or temp
        end

        -- keep highest douse too
        if tattles[spell_id][5] == "douse" then
          local highest_douse = 0
          for _,copy in ipairs(data.copies) do
            local d1 = tonumber(copy.extra)
            local d2 = tonumber(temp.extra)
            if not (d1 and d2) then break end
            temp = (d1 > d2) and copy or temp
            TattlerDB.douse_tracking.count = (d1 >= d2) and d1 or d2
          end
        end

        if temp.sender == UnitName("player") or DEBUG then
          local spell_id,caster,target,extra = Tattler:ParseMsg(msg)
          Tattler:Tattle(temp.spell_id,temp.caster,temp.target,temp.extra)
        end
        current_tattles[msg] = nil
      end
    end
    -- tattles over, remove the update loop
    if not next(current_tattles) then Tattler:SetScript("OnUpdate", nil) end
  end)
end

function Tattler.PLAYER_ENTERING_WORLD()
  -- _,player_guid = UnitExists("player")
end

Tattler:RegisterEvent("UNIT_CASTEVENT")
-- Tattler:RegisterEvent("PLAYER_ENTERING_WORLD")
Tattler:RegisterEvent("ADDON_LOADED")
Tattler:RegisterEvent("CHAT_MSG_ADDON")
Tattler:RegisterEvent("PLAYER_REGEN_ENABLED")
Tattler:RegisterEvent("UPDATE_INSTANCE_INFO")
Tattler:SetScript("OnEvent", function ()
  Tattler[event](arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10)
end)
