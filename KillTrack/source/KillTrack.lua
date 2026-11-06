--[[
    * Copyright (c) 2011-2020 by Adam Hellberg.
    *
    * This file is part of KillTrack.
    *
    * KillTrack is free software: you can redistribute it and/or modify
    * it under the terms of the GNU General Public License as published by
    * the Free Software Foundation, either version 3 of the License, or
    * (at your option) any later version.
    *
    * KillTrack is distributed in the hope that it will be useful,
    * but WITHOUT ANY WARRANTY; without even the implied warranty of
    * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    * GNU General Public License for more details.
    *
    * You should have received a copy of the GNU General Public License
    * along with KillTrack. If not, see <http://www.gnu.org/licenses/>.
--]]

---@type string
local NAME = "KillTrack"

---@class KillTrack
---@field PlayerName string?
local KT = KT or {}

---@class KillTrackMobData
---@field Kills integer
---@field ZoneName string
---@field LastKillAt integer?
---@field AchievCount integer
---@field Exp integer?

---@class KillTrackCharMobData
---@field Kills integer
---@field LastKillAt integer?

_G = getfenv()
local NO_NAME = "<No Name>"

KT.Name = NAME
KT.Version = GetAddOnMetadata( NAME, "Version" )
KT.Events = {}

---@class KillTrackImmediatePosition
---@field POINT string?
---@field RELATIVE string?
---@field X number?
---@field Y number?

---@class KillTrackGlobal
---@field LOAD_MESSAGE boolean
---@field PRINTKILLS boolean
---@field PRINTNEW boolean
---@field ACHIEV_THRESHOLD integer
---@field COUNT_GROUP boolean
---@field SHOW_EXP boolean
---@field MOBS { [string]: KillTrackMobData }
---@field IMMEDIATE { POSITION: KillTrackImmediatePosition, THRESHOLD: integer, FILTER: string? }
---@field BROKER { SHORT_TEXT: boolean, MINIMAP: { hide: boolean } }
---@field DISABLE_DUNGEONS boolean
---@field DISABLE_RAIDS boolean
---@field TOOLTIP boolean
---@field DATETIME_FORMAT string
KT.Global = {}

---@class KillTrackCharGlobal
---@field MOBS { [string]: KillTrackCharMobData }
KT.CharGlobal = {}

---@class KillTrackTemp
---@field Threshold integer?
---@field DeleteName string?
KT.Temp = {}

---@enum KillTrackMobSortMode
KT.Sort = {
  Desc = 0,
  Asc = 1,
  CharDesc = 2,
  CharAsc = 3,
  AlphaD = 4,
  AlphaA = 5,
  IdDesc = 6,
  IdAsc = 7
}
KT.Session = {
  Count = 0,
  ---@type { [string]: integer? }
  Kills = {}
}
KT.Messages = {
  Announce = "[KillTrack] Session Length: %s. Session Kills: %d. Kills Per Minute: %.2f."
}

KT.Defaults = {
  DateTimeFormat = "%Y-%m-%d %H:%M:%S"
}

---@type KillTrackExpTracker
local ET

local KTT = KT.Tools

---@type { [string]: string? }
local FirstDamage = {} -- Tracks first damage to a mob registered by CLEU

---@type { [string]: string? }
local LastDamage = {} -- Tracks whoever did the most recent damage to a mob

---@type { [string]: boolean? }
local HasPlayerDamage = {} -- Tracks whether the player (or pet) has dealt damage to a mob

---@type { [string]: boolean? }
local HasGroupDamage = {} -- Tracks whether a group member has dealt damage to a mob

---@type { [string]: boolean? }
local DamageValid = {} -- Determines if mob is tapped by player/group

---@param event string
function KT:OnEvent( event )
  if self.Events[ event ] then
    self.Events[ event ]()
  end
end

function KT.Events.ADDON_LOADED()
  if arg1 ~= NAME then return end

  ET = KT.ExpTracker
  if type( _G[ "KILLTRACK" ] ) ~= "table" then
    _G[ "KILLTRACK" ] = {}
  end
  KT.Global = _G[ "KILLTRACK" ]
  if type( KT.Global.LOAD_MESSAGE ) ~= "boolean" then
    KT.Global.LOAD_MESSAGE = false
  end
  if type( KT.Global.PRINTKILLS ) ~= "boolean" then
    KT.Global.PRINTKILLS = false
  end
  if type( KT.Global.PRINTNEW ) ~= "boolean" then
    KT.Global.PRINTNEW = false
  end
  if type( KT.Global.ACHIEV_THRESHOLD ) ~= "number" then
    KT.Global.ACHIEV_THRESHOLD = 1000
  end
  if type( KT.Global.COUNT_GROUP ) ~= "boolean" then
    KT.Global.COUNT_GROUP = false
  end
  if type( KT.Global.SHOW_EXP ) ~= "boolean" then
    KT.Global.SHOW_EXP = false
  end
  if type( KT.Global.MOBS ) ~= "table" then
    KT.Global.MOBS = {}
  end
  if type( KT.Global.IMMEDIATE ) ~= "table" then
    KT.Global.IMMEDIATE = {}
  end
  if type( KT.Global.IMMEDIATE.POSITION ) ~= "table" then
    KT.Global.IMMEDIATE.POSITION = {}
  end
  if type( KT.Global.IMMEDIATE.THRESHOLD ) ~= "number" then
    KT.Global.IMMEDIATE.THRESHOLD = 0
  end
  if type( KT.Global.BROKER ) ~= "table" then
    KT.Global.BROKER = {}
  end
  if type( KT.Global.BROKER.SHORT_TEXT ) ~= "boolean" then
    KT.Global.BROKER.SHORT_TEXT = false
  end
  if type( KT.Global.BROKER.MINIMAP ) ~= "table" then
    KT.Global.BROKER.MINIMAP = {}
  end
  if type( KT.Global.DISABLE_DUNGEONS ) ~= "boolean" then
    KT.Global.DISABLE_DUNGEONS = false
  end
  if type( KT.Global.DISABLE_RAIDS ) ~= "boolean" then
    KT.Global.DISABLE_RAIDS = false
  end
  if type( KT.Global.TOOLTIP ) ~= "boolean" then
    KT.Global.TOOLTIP = true
  end
  if type( KT.Global.DATETIME_FORMAT ) ~= "string" then
    KT.Global.DATETIME_FORMAT = KT.Defaults.DateTimeFormat
  end
  if type( _G[ "KILLTRACK_CHAR" ] ) ~= "table" then
    _G[ "KILLTRACK_CHAR" ] = {}
  end
  KT.CharGlobal = _G[ "KILLTRACK_CHAR" ]
  if type( KT.CharGlobal.MOBS ) ~= "table" then
    KT.CharGlobal.MOBS = {}
  end
  KT.PlayerName = UnitName( "player" )

  KT.Session.Start = time()
  KT.Broker:OnLoad()
end

function KT.Events.PLAYER_LOGIN()
  if KT.Global.LOAD_MESSAGE then
    KT:Msg( "AddOn Loaded!" )
  end

  ---@diagnostic disable-next-line: undefined-global
  KT.pfUI = IsAddOnLoaded( "pfUI" ) and pfUI and pfUI.api and pfUI.env and pfUI.env.C

  KT:ToggleCountMode( true )
end

function KT.Events.CHAT_MSG_COMBAT_PET_HITS()
  local target = string.match( arg1, "^%S+ %S+ (.+) for" )
  HasPlayerDamage[ target ] = true
end

function KT.Events.CHAT_MSG_COMBAT_PARTY_HITS()
  if not KTT.IsInGroup() or not KT.Global.COUNT_GROUP then return end
  local target = string.match( arg1, "^%S+ %S+ (.+) for" )
  HasGroupDamage[ target ] = true
end

function KT.Events.CHAT_MSG_SPELL_PARTY_DAMAGE()
  if not KTT.IsInGroup() or not KT.Global.COUNT_GROUP then return end
  local target = string.match( arg1, "^%S+'s .- hits (.+) for" )
  if not target then
    target = string.match( arg1, "^%S+'s .- crits (.+) for" )
  end

  if target then
    HasGroupDamage[ target ] = true
  end
end

function KT.Events.CHAT_MSG_COMBAT_HOSTILE_DEATH()
  local re = "^" .. string.gsub( SELFKILLOTHER, "%%s!", "(%.+)!$")
  local target = string.match( arg1, re )

  if target then
    KT:AddKill( target )
    return
  end

  re = string.gsub( UNITDIESOTHER, "%%s", "^(%.+)")
  re = string.gsub( re, "%.$", ".$" )
  target = string.match( arg1, re )

  if target and HasPlayerDamage[ target ] then
    KT:AddKill( target )
    return
  end

  if KTT.IsInGroup() and KT.Global.COUNT_GROUP then
    if target and HasGroupDamage[ target ] then
      KT:AddKill( target )
      return
    end
  end
end

function KT.Events.CHAT_MSG_COMBAT_XP_GAIN()
  ET:CheckMessage( arg1 )
end

---@param self KillTrack
---@param size integer
function KT.Events.ENCOUNTER_START( self, _, _, _, size )
  print("encounter start")
  if (self.Global.DISABLE_DUNGEONS and size == 5) or (self.Global.DISABLE_RAIDS and size > 5) then
    --self.Frame:UnregisterEvent( "COMBAT_LOG_EVENT_UNFILTERED" )
    --self.Frame:UnregisterEvent( "UPDATE_MOUSEOVER_UNIT" )
    self.Frame:UnregisterEvent( "CHAT_MSG_COMBAT_XP_GAIN" )
  end
end

---@param self KillTrack
---@param size integer
function KT.Events.ENCOUNTER_END( self, _, _, _, size )
  print("encounter end")
  if (self.Global.DISABLE_DUNGEONS and size == 5) or (self.Global.DISABLE_RAIDS and size > 5) then
    --self.Frame:RegisterEvent( "COMBAT_LOG_EVENT_UNFILTERED" )
    --self.Frame:RegisterEvent( "UPDATE_MOUSEOVER_UNIT" )
    self.Frame:RegisterEvent( "CHAT_MSG_COMBAT_XP_GAIN" )
  end
end

function KT.tooltip_enhancer( unit )
  if KT.Global.TOOLTIP and not KT.tooltipModified then
    if unit and not UnitIsPlayer( unit ) and UnitCanAttack( "player", unit ) then
      KT.tooltipModified = true
      local mob, charMob = KT:GetMob( UnitName( unit ) )
      if not mob then return end
      local gKills = mob.Kills
      local cKills = charMob and charMob.Kills or 0
      local exp = mob.Exp

      if gKills > 0 or cKills > 0 then
        GameTooltip:AddLine( string.format( "Killed %d (%d) times.", cKills, gKills ), 1, 1, 1 )
        if KT.Global.SHOW_EXP and exp then
          local toLevel = exp > 0 and math.ceil( (UnitXPMax( "player" ) - UnitXP( "player" )) / exp ) or "N/A"
          GameTooltip:AddLine( string.format( "EXP: %d (%s kills to level)", exp, toLevel ), 1, 1, 1 )
        end
        if KT.Debug then
          GameTooltip:AddLine( string.format( "ID = %s  ", UnitName( unit ) ) )
        end
        GameTooltip:Show()
      end
    end
  end
end

KT._SetUnit = GameTooltip.SetUnit
---@diagnostic disable-next-line: duplicate-set-field
function GameTooltip:SetUnit( unit )
  KT._SetUnit( self, unit )
  KT.tooltip_enhancer( unit )
end

KT._GameTooltipOnHide = GameTooltip:GetScript( "OnHide" )
GameTooltip:SetScript( "OnHide", function()
  if KT._GameTooltipOnHide then
    KT._GameTooltipOnHide()
  end
  KT.tooltipModified = false
end )

KT._GameTooltipOnUpdate = GameTooltip:GetScript( "OnUpdate" )
GameTooltip:SetScript( "OnUpdate", function()
  if KT._GameTooltipOnUpdate then
    KT._GameTooltipOnUpdate()
  end

  KT.tooltip_enhancer( "mouseover" )
end )

function KT:ToggleLoadMessage()
  self.Global.LOAD_MESSAGE = not self.Global.LOAD_MESSAGE
  if self.Global.LOAD_MESSAGE then
    self:Msg( "Now showing message on AddOn load" )
  else
    self:Msg( "No longer showing message on AddOn load" )
  end
end

function KT:ToggleExp()
  self.Global.SHOW_EXP = not self.Global.SHOW_EXP
  if self.Global.SHOW_EXP then
    self:Msg( "Now showing EXP on tooltips!" )
  else
    self:Msg( "No longer showing EXP on tooltips." )
  end
end

function KT:ToggleDebug()
  self.Debug = not self.Debug
  if self.Debug then
    self:Msg( "Debug enabled!" )
  else
    self:Msg( "Debug disabled!" )
  end
end

---@param threshold integer
function KT:SetThreshold( threshold )
  if type( threshold ) ~= "number" then
    error( "KillTrack.SetThreshold: Argument #1 (threshold) must be of type 'number'" )
  end
  self.Global.ACHIEV_THRESHOLD = threshold
  if threshold > 0 then
    self:ResetAchievCount()
    self:Msg( string.format("New kill notice (achievement) threshold set to %d.", threshold ) )
  else
    self:Msg( "Kill notices have been disabled (set threshold to a value greater than 0 to re-enable)." )
  end
end

---@param threshold integer
function KT:SetImmediateThreshold( threshold )
  if type( threshold ) ~= "number" then
    error( "KillTrack.SetImmediateThreshold: Argument #1 (threshold) must be of type 'number'" )
  end
  self.Global.IMMEDIATE.THRESHOLD = threshold
  if threshold > 0 then
    self:Msg( string.format( "New immediate threshold set to %d.", threshold ) )
  else
    self:Msg( "Immediate threshold disabled." )
  end
end

---@param filter string
function KT:SetImmediateFilter( filter )
  if type( filter ) ~= "string" then
    error( "KillTrack.SetImmediateFilter: Argument #1 (filter) must be of type 'string'" )
  end
  self.Global.IMMEDIATE.FILTER = filter
  self:Msg( "New immediate filter set to: " .. filter )
end

function KT:ClearImmediateFilter()
  self.Global.IMMEDIATE.FILTER = nil
  KT:Msg( "Immediate filter cleared!" )
end

---@param init boolean?
function KT:ToggleCountMode( init )
  if init then
    if self.Global.COUNT_GROUP then
      self.Frame:RegisterEvent( "CHAT_MSG_COMBAT_PARTY_HITS" )
      ---@diagnostic disable-next-line: param-type-mismatch
      self.Frame:RegisterEvent( "CHAT_MSG_SPELL_PARTY_DAMAGE" )
    else
      self.Frame:UnregisterEvent( "CHAT_MSG_COMBAT_PARTY_HITS" )
      ---@diagnostic disable-next-line: param-type-mismatch
      self.Frame:UnregisterEvent( "CHAT_MSG_SPELL_PARTY_DAMAGE" )
    end
  else
    self.Global.COUNT_GROUP = not self.Global.COUNT_GROUP
    if self.Global.COUNT_GROUP then
      self:Msg( "Now counting kills for every player in the group (party/raid)!" )
    else
      self:Msg( "Now counting your own killing blows ONLY." )
    end
  end
end

---@param name string
---@return KillTrackMobData
---@return KillTrackCharMobData
function KT:InitMob( name )
  local zone_name = GetRealZoneText()

  if type( self.Global.MOBS[ name ] ) ~= "table" then
    self.Global.MOBS[ name ] = { ZoneName = zone_name, Kills = 0, AchievCount = 0 }
    if self.Global.PRINTNEW then
      self:Msg( ("Created new entry for %q"):format( name ) )
    end
  end

  if type( self.CharGlobal.MOBS[ name ] ) ~= "table" then
    self.CharGlobal.MOBS[ name ] = { Kills = 0 }
    if self.Global.PRINTNEW then
      self:Msg( ("Created new entry for %q on this character."):format( name ) )
    end
  end

  return self.Global.MOBS[ name ], self.CharGlobal.MOBS[ name ]
end

---@param name string
function KT:AddKill( name )
  if not name then return end
  local current_time = time()
  self:InitMob( name )
  local globalMob = self.Global.MOBS[ name ]
  local charMob = self.CharGlobal.MOBS[ name ]
  globalMob.Kills = self.Global.MOBS[ name ].Kills + 1
  globalMob.LastKillAt = current_time
  charMob.Kills = self.CharGlobal.MOBS[ name ].Kills + 1
  charMob.LastKillAt = current_time

  HasGroupDamage[ name ] = nil
  HasPlayerDamage[ name ] = nil

  self:AddSessionKill( name )
  if self.Timer:IsRunning() then
    self.Timer:SetData( "Kills", self.Timer:GetData( "Kills", true ) + 1 )
  end

  if self.Global.PRINTKILLS then
    local kills = self.Global.MOBS[ name ].Kills
    local cKills = self.CharGlobal.MOBS[ name ].Kills
    self:Msg( string.format( "Updated %q, new kill count: %d. Kill count on this character: %d", name, kills, cKills ) )
  end

  if self.Immediate.Active then
    local filter = self.Global.IMMEDIATE.FILTER
    local filterPass = not filter or string.find( name, filter )
    if filterPass then
      self.Immediate:AddKill()
      if self.Global.IMMEDIATE.THRESHOLD > 0 and mod( self.Immediate.Kills, self.Global.IMMEDIATE.THRESHOLD ) == 0 then
        ---@diagnostic disable-next-line: param-type-mismatch
        PlaySound( "RaidWarning" )
        PlaySound( "PVPTHROUGHQUEUE" )
        RaidWarningFrame:AddMessage( string.format( "%d KILLS!", self.Immediate.Kills ) )
      end
    end
  end
  if self.Global.ACHIEV_THRESHOLD <= 0 then return end
  if type( self.Global.MOBS[ name ].AchievCount ) ~= "number" then
    self.Global.MOBS[ name ].AchievCount = floor( self.Global.MOBS[ name ].Kills / self.Global.ACHIEV_THRESHOLD )
    if self.Global.MOBS[ name ].AchievCount >= 1 then
      self:KillAlert( name, self.Global.MOBS[ name ] )
    end
  else
    local achievCount = self.Global.MOBS[ name ].AchievCount
    self.Global.MOBS[ name ].AchievCount = floor( self.Global.MOBS[ name ].Kills / self.Global.ACHIEV_THRESHOLD )
    if self.Global.MOBS[ name ].AchievCount > achievCount then
      self:KillAlert( name, self.Global.MOBS[ name ] )
    end
  end
end

---@param name string
---@param globalCount integer
---@param charCount integer
function KT:SetKills( name, globalCount, charCount )

  if type( globalCount ) ~= "number" then
    error( "'globalCount' argument must be a number" )
  end

  if type( charCount ) ~= "number" then
    error( "'charCount' argument must be a number" )
  end

  name = name or NO_NAME

  self:InitMob( name )
  self.Global.MOBS[ name ].Kills = globalCount
  self.CharGlobal.MOBS[ name ].Kills = charCount

  self:Msg( string.format("Updated %q to %d global and %d character kills", name, globalCount, charCount ) )
end

---@param name string
function KT:AddSessionKill( name )
  if self.Session.Kills[ name ] then
    self.Session.Kills[ name ] = self.Session.Kills[ name ] + 1
  else
    self.Session.Kills[ name ] = 1
  end
  self.Session.Count = self.Session.Count + 1
end

---@param name string
---@param exp integer|string
function KT:SetExp( name, exp )
  for key, mob in pairs( self.Global.MOBS ) do
    if key == name then mob.Exp = tonumber( exp ) end
  end
end

---@param max integer|string?
---@return { Name: string, Kills: integer }[]
function KT:GetSortedSessionKills( max )
  max = tonumber( max ) or 3
  local t = {}
  for k, v in pairs( self.Session.Kills ) do
    t[ getn( t ) + 1 ] = { Name = k, Kills = v }
  end
  table.sort( t, function( a, b ) return a.Kills > b.Kills end )
  -- Trim table to only contain 3 entries
  local trimmed = {}
  local c = 0
  for i, v in ipairs( t ) do
    trimmed[ i ] = v
    c = c + 1
    if c >= max then break end
  end
  return trimmed
end

function KT:ResetSession()
  KTT:Wipe( self.Session.Kills )
  self.Session.Count = 0
  self.Session.Start = time()
end

---@param id integer
---@return integer globalKills
---@return integer charKills
function KT:GetKills( id )
  local gKills, cKills = 0, 0
  local mob = self.Global.MOBS[ id ]
  if type( mob ) == "table" then
    gKills = mob.Kills
    local cMob = self.CharGlobal.MOBS[ id ]
    if type( cMob ) == "table" then
      cKills = cMob.Kills
    end
  end
  return gKills, cKills
end

---@return integer
function KT:GetTotalKills()
  local count = 0
  for _, mob in pairs( self.Global.MOBS ) do
    count = count + mob.Kills
  end
  return count
end

---@return integer killsPerSecond
---@return integer killsPerMinute
---@return integer killsPerHour
---@return integer killsThisSession
function KT:GetSessionStats()
  if not self.Session.Start then return 0, 0, 0, 0 end
  local now = time()
  local session = now - self.Session.Start
  local kps = session == 0 and 0 or self.Session.Count / session
  local kpm = kps * 60
  local kph = kpm * 60
  return kps, kpm, kph, session
end

---@param name string?
function KT:PrintKills( name )
  local found = false
  local gKills = 0
  local cKills = 0
  local lastKillAt = nil

  if name and self.Global.MOBS[ name ] then
    gKills = self.Global.MOBS[ name ].Kills
    if type( self.Global.MOBS[ name ].LastKillAt ) == "number" then
      lastKillAt = KTT:FormatDateTime( self.Global.MOBS[ name ].LastKillAt )
      found = true
    end
  end

  if name and self.CharGlobal.MOBS[ name ] then
    cKills = self.CharGlobal.MOBS[ name ].Kills
  end

  if found then
    self:Msg( string.format( "You have killed %q %d times in total, %d times on this character", name, gKills, cKills ) )
    if lastKillAt then
      self:Msg( string.format( "Last killed at %s", lastKillAt ) )
    end
  else
    if UnitExists( "target" ) and not UnitIsPlayer( "target" ) then
      name = UnitName( "target" ) or NO_NAME
    end
    self:Msg( string.format( "Unable to find %q in mob database.", tostring( name ) ) )
  end
end

---@param target string
function KT:Announce( target )
  if target == "GROUP" then
    target = ((KTT.IsInRaid() and "RAID") or (KTT.IsInGroup() and "PARTY")) or "SAY"
  end
  local _, kpm, _, length = self:GetSessionStats()
  local msg = string.format(self.Messages.Announce, KTT:FormatSeconds( length ), self.Session.Count, kpm )
  SendChatMessage( msg, target )
end

---@param msg string
function KT:Msg( msg )
  DEFAULT_CHAT_FRAME:AddMessage( "\124cff00FF00[KillTrack]\124r " .. msg )
end

---@param msg string
function KT:DebugMsg( msg )
  if not self.Debug then return end
  self:Msg( "[DEBUG] " .. msg )
end

---@param name string
---@param mob KillTrackMobData
function KT:KillAlert( name, mob )
  local data = {
    Text = string.format("%d kills on %s!", mob.Kills, name ),
    Title = "Kill Record!",
    bTitle = "Congratulations!",
    Icon = "Interface\\Icons\\ABILITY_Deathwing_Bloodcorruption_Death",
    FrameStyle = "GuildAchievement"
  }
  if IsAddOnLoaded( "Glamour" ) then
    if not _G[ "GlamourShowAlert" ] then
      self:Msg( "ERROR: GlamourShowAlert == nil! Notify AddOn developer." )
      return
    end
    _G.GlamourShowAlert( 500, data )
  else
    ---@diagnostic disable-next-line: param-type-mismatch
    PlaySound( "RaidWarning" )
    PlaySound( "PVPTHROUGHQUEUE" )
    RaidWarningFrame:AddMessage( data.Text )
  end
  self:Msg( data.Text )
end

---@param name string?
---@return KillTrackMobData|false
---@return KillTrackCharMobData|nil
function KT:GetMob( name )
  if name and self.Global.MOBS[ name ] then
    return self.Global.MOBS[ name ], self.CharGlobal.MOBS[ name ]
  end

  return false, nil
end

---@param mode KillTrackMobSortMode|integer?
---@param filter string?
---@param caseSensitive boolean|nil
---@param zoneName string|nil
---@return { Id: integer, Name: string, gKills: integer, cKills: integer }[]
function KT:GetSortedMobTable( mode, filter, caseSensitive, zoneName )
  if not tonumber( mode ) then mode = self.Sort.Desc end
  if mode < 0 or mode > 7 then mode = self.Sort.Desc end
  if filter and filter == "" then filter = nil end
  if zoneName and zoneName == "" then zoneName = nil end
  local t = {}
  for k, v in pairs( self.Global.MOBS ) do
    assert( type( v ) == "table", "Unexpected mob entry type in db: " .. type( v ) .. ". Expected table" )
    local matches = nil
    if filter then
      local name = caseSensitive and k or string.lower( k )
      filter = caseSensitive and filter or string.lower( filter )
      local status, result = pcall( function() return string.find( name, filter ) end )
      matches = status and result
    end
    local zoneMatches = nil
    if zoneName then
      zoneMatches = v.ZoneName == zoneName
    end
    if (matches or not filter) and (zoneMatches or not zoneName)  then
      local cKills = 0
      if self.CharGlobal.MOBS[ k ] and type( self.CharGlobal.MOBS[ k ] ) == "table" then
        cKills = self.CharGlobal.MOBS[ k ].Kills
      end
      local entry = { Name = k, gKills = v.Kills, cKills = cKills }
      table.insert( t, entry )
    end
  end
  local function compare( a, b )
    if mode == self.Sort.Asc then
      return a.gKills < b.gKills
    elseif mode == self.Sort.CharDesc then
      return a.cKills > b.cKills
    elseif mode == self.Sort.CharAsc then
      return a.cKills < b.cKills
    elseif mode == self.Sort.AlphaD then
      return a.Name > b.Name
    elseif mode == self.Sort.AlphaA then
      return a.Name < b.Name
    elseif mode == self.Sort.IdDesc then
      return a.Id > b.Id
    elseif mode == self.Sort.IdAsc then
      return a.Id < b.Id
    else
      return a.gKills > b.gKills -- Descending
    end
  end
  table.sort( t, compare )
  return t
end

---@param name string
---@param charOnly boolean?
function KT:Delete( name, charOnly )
  local found = false

  if self.Global.MOBS[ name ] then
    if not charOnly then self.Global.MOBS[ name ] = nil end
    if self.CharGlobal.MOBS[ name ] then
      self.CharGlobal.MOBS[ name ] = nil
    end
    found = true
  end
  if found then
    self:Msg( string.format("Deleted %s from database.", name ) )
    StaticPopup_Show( "KILLTRACK_FINISH", 1 )
  else
    self:Msg( string.format("%s was not found in the database.", name ) )
  end
end

---@param threshold integer
function KT:Purge( threshold )
  local count = 0
  for k, v in pairs( self.Global.MOBS ) do
    if type( v ) == "table" and v.Kills < threshold then
      self.Global.MOBS[ k ] = nil
      count = count + 1
    end
  end
  for k, v in pairs( self.CharGlobal.MOBS ) do
    if type( v ) == "table" and v.Kills < threshold then
      self.CharGlobal.MOBS[ k ] = nil
      count = count + 1
    end
  end
  self:Msg( string.format("Purged %d entries with a kill count below %d", count, threshold ) )
  self.Temp.Threshold = nil
  StaticPopup_Show( "KILLTRACK_FINISH", tostring( count ) )
end

function KT:Reset()
  local count = KTT:TableLength( self.Global.MOBS ) + KTT:TableLength( self.CharGlobal.MOBS )
  KTT:Wipe( self.Global.MOBS )
  KTT:Wipe( self.CharGlobal.MOBS )
  self:Msg( string.format("%d mob entries have been removed!", count ) )
  StaticPopup_Show( "KILLTRACK_FINISH", tostring( count ) )
end

function KT:ResetAchievCount()
  for _, v in pairs( self.Global.MOBS ) do
    v.AchievCount = floor( v.Kills / self.Global.ACHIEV_THRESHOLD )
  end
end

KT.Frame = CreateFrame( "Frame" )

for k, _ in pairs( KT.Events ) do
  KT.Frame:RegisterEvent( k )
end

KT.Frame:SetScript( "OnEvent", function() KT:OnEvent( event ) end )
