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

---@class KillTrack
KT = KT or {}

---@class KillTrackTools
local KTT = {}

KT.Tools = KTT

------------------
-- NUMBER TOOLS --
------------------

---@param seconds number
---@return string
function KTT:FormatSeconds( seconds )
  local hours = floor( seconds / 3600 )
  local minutes = floor( seconds / 60 ) - hours * 60
  seconds = seconds - minutes * 60 - hours * 3600
  return string.format( "%02d:%02d:%02d", hours, minutes, seconds )
end

------------------
-- STRING TOOLS --
------------------

---@param s string
---@return string
function KTT:Trim( s )
  return (string.gsub( s, "^%s*(.-)%s*$", "%1" ))
end

---@param s string
---@return string[]
function KTT:Split( s )
  local r = {}
  local tokpat = "%S+"
  local spat = "=[^(['\"])]="
  local epat = "=[(['\"])$]="
  local escpat = "=[(%*)['\"]$]="
  local buf, quoted
  for token in string.gmatch( s, tokpat ) do
    local squoted = string.match( token, spat )
    local equoted = string.match( token, epat )
    local escaped = string.match( token, escpat )
    if squoted and not quoted and not equoted then
      buf, quoted = token, squoted
    elseif buf and equoted == quoted and mod( getn( escaped ), 2 ) == 0 then
      token, buf, quoted = buf .. " " .. token, nil, nil
    elseif buf then
      buf = buf .. " " .. token
    end
    if not buf then
      r[ getn( r ) + 1 ] = string.gsub( string.gsub( string.gsub( token, spat, "" ), epat, "" ), "[%(.)]", "%1" )
      --r[getn(r) + 1] = token:gsub(spat, ""):gsub(epat, ""):gsub([[\(.)]], "%1")
    end
  end
  if buf then
    r[ getn( r ) + 1 ] = buf
  end
  return r
end

-----------------
-- TABLE TOOLS --
-----------------

---@param tbl table
---@param val any
---@return boolean
function KTT:InTable( tbl, val )
  for _, v in pairs( tbl ) do
    if v == val then return true end
  end
  return false
end

---@param tbl table
---@param cache table?
---@return table
function KTT:TableCopy( tbl, cache )
  if type( tbl ) ~= "table" then return tbl end
  cache = cache or {}
  if cache[ tbl ] then return cache[ tbl ] end
  local copy = {}
  cache[ tbl ] = copy
  for k, v in pairs( tbl ) do
    copy[ self:TableCopy( k, cache ) ] = self:TableCopy( v, cache )
  end
  return copy
end

---@param table table
---@return integer
function KTT:TableLength( table )
  local count = 0
  for _, _ in pairs( table ) do
    count = count + 1
  end
  return count
end

---@param table table
function KTT:Wipe( table )
  for k in pairs( table ) do
    table[ k ] = nil
  end
end

--------------------
-- DATETIME TOOLS --
--------------------

---@param timestamp number?
---@param format string?
---@return string|osdate
function KTT:FormatDateTime( timestamp, format )
  timestamp = timestamp or time()
  format = format or KT.Global.DATETIME_FORMAT or KT.Defaults.DateTimeFormat
  return date( format, timestamp )
end

-----------------
-- OTHER TOOLS --
-----------------

---@return boolean
function KTT.IsInParty()
  return GetNumRaidMembers() == 0 and GetNumPartyMembers() > 0
end

---@return boolean
function KTT.IsInRaid()
  return GetNumRaidMembers() > 0
end

---@return boolean
function KTT.IsInGroup()
  return KTT.IsInParty() or KTT.IsInRaid()
end

---@diagnostic disable-next-line: undefined-field
if not string.gmatch then string.gmatch = string.gfind end

---@diagnostic disable-next-line: duplicate-set-field
string.match = string.match or function( str, pattern )
  if not str then return nil end

  local _, _, r1, r2, r3, r4, r5, r6, r7, r8, r9 = string.find( str, pattern )
  return r1, r2, r3, r4, r5, r6, r7, r8, r9
end