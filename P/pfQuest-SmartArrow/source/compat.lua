-- pfQuest SmartArrow
-- Copyright (C) 2026 pfQuest SmartArrow contributors
--
-- This program is free software: you can redistribute it and/or modify it
-- under the terms of the GNU General Public License as published by the Free
-- Software Foundation, either version 3 of the License, or (at your option)
-- any later version. It is distributed WITHOUT ANY WARRANTY; see LICENSE.md.

-- pfQuest SmartArrow: what this pfQuest and this client can tell us
--
-- The rest of the addon works in world yards (north, west, continent). Where
-- those come from depends on the pfQuest build and the client:
--
--   "pfquest"  pfQuest has world coordinates of its own (brues-code fork with
--              ClassicAPI): pfMap:GetWorldPos, pfQuest.route.worldcoords,
--              UnitPosition.
--   "cmap"     the client has ClassicAPI (C_Map, UnitPosition) but pfQuest
--              does not use it for routes (lightblade fork with ClassicAPI).
--   "maps"     a plain 1.12 client: positions are read off the zone map
--              (GetPlayerMapPosition) and turned into world yards with the
--              zone table in data/zones.lua.
--
-- Objectives come from pfQuest.route.worldcoords when pfQuest builds it, and
-- otherwise from pfQuest.route.coords (zone map percent on the map pfQuest
-- shows, which it keeps on your zone), converted the same way.

local floor, sqrt = math.floor, math.sqrt
local getn, insert = table.getn, table.insert

local C = {}
pfQuestSmartArrowCompat = C

function C:Mode()
  if self.mode then return self.mode end
  if pfMap and pfMap.GetWorldPos and UnitPosition then
    self.mode = "pfquest"
  elseif UnitPosition and C_Map and C_Map.GetWorldPosFromMapPos then
    self.mode = "cmap"
  else
    self.mode = "maps"
  end
  return self.mode
end

-- the zone rectangle, with your own correction if you have walked into it
local function Rect(zone)
  local rect = pfQuestSmartArrowData and pfQuestSmartArrowData.zones and pfQuestSmartArrowData.zones[zone]
  if not rect then return nil end
  local fixed = pfQuestSmartArrow_config and pfQuestSmartArrow_config.zonefix and pfQuestSmartArrow_config.zonefix[zone]
  if fixed then
    return { c = rect.c, l = fixed.l, t = fixed.t, w = rect.w, h = rect.h }
  end
  return rect
end
C.Rect = Rect

-- zone map percent -> continent, north, west
function C.Resolve(zone, x, y)
  if not zone or not x or not y then return nil end
  -- the best source there is: pfQuest's own, the client's, then the table
  if pfMap and pfMap.GetWorldPos then
    local ok, c, n, w = pcall(pfMap.GetWorldPos, pfMap, zone, x, y)
    if ok and c then return c, n, w end
  elseif C_Map and C_Map.GetWorldPosFromMapPos then
    local ok, c, world = pcall(C_Map.GetWorldPosFromMapPos, zone, { x = x / 100, y = y / 100 })
    if ok and c and world then return c, world.x, world.y end
  end
  local rect = Rect(zone)
  if not rect then return nil end
  return rect.c, rect.t - y / 100 * rect.h, rect.l - x / 100 * rect.w
end

-- continent, north, west -> zone map percent (may lie outside 0..100)
function C.ToMap(zone, n, w)
  local rect = Rect(zone)
  if rect and C:Mode() == "maps" then
    return (rect.l - w) / rect.w * 100, (rect.t - n) / rect.h * 100
  end
  return nil
end

-- the map pfQuest is showing (it keeps the world map on your zone)
function C.ShownMap()
  if pfMap and pfMap.GetMapID and GetCurrentMapContinent and GetCurrentMapZone then
    return pfMap:GetMapID(GetCurrentMapContinent(), GetCurrentMapZone())
  end
  return nil
end

local last -- last good position, for the moments the map shows elsewhere

-- like UnitPosition("player"): west, north, height, continent
function C.PlayerPosition()
  if UnitPosition then
    return UnitPosition("player")
  end
  local x, y = GetPlayerMapPosition("player")
  local zone = C.ShownMap()
  if x and y and (x > 0 or y > 0) and zone then
    local c, n, w = C.Resolve(zone, x * 100, y * 100)
    if c then
      last = { w = w, n = n, c = c, time = GetTime(), zone = zone, x = x * 100, y = y * 100 }
      return w, n, nil, c
    end
  end
  -- the world map is open on another zone: keep the last position a while
  if last and GetTime() - last.time < 30 then
    return last.w, last.n, nil, last.c
  end
  return nil
end

-- where on the shown map you stand, for calibrating approximate zones
function C.LastMapPosition()
  return last
end

function C.Facing()
  if GetPlayerFacing then
    local ok, f = pcall(GetPlayerFacing)
    if ok and f then return f end
  end
  if pfQuestCompat and pfQuestCompat.GetPlayerFacing then
    local ok, f = pcall(pfQuestCompat.GetPlayerFacing)
    if ok and f then return f end
  end
  return nil
end

-- objectives --------------------------------------------------------------------

local cache, cachefrom, cachecount, cachefirst, cachezone, cachetime

-- pfQuest's arrow candidates as world points: { north, west, node, distance,
-- watched, ?, continent } (the layout of pfQuest.route.worldcoords)
function C.Candidates()
  local route = pfQuest and pfQuest.route
  if not route then return nil end
  if route.worldcoords then return route.worldcoords end

  local coords = route.coords
  if not coords then return nil end
  if route.targetMissing then return {} end

  local zone = C.ShownMap()
  local count = getn(coords)
  local first = coords[1]
  local now = GetTime()
  if cache and cachefrom == coords and cachecount == count and cachefirst == first and cachezone == zone
    and now - cachetime < 1 then
    return cache
  end

  local list = {}
  for i = 1, count do
    local e = coords[i]
    local node = e[3]
    local z = (node and node.zone) or zone
    local c, n, w = C.Resolve(z, e[1], e[2])
    if c then
      insert(list, { n, w, node, e[4], nil, nil, c })
    end
  end
  cache, cachefrom, cachecount, cachefirst, cachezone, cachetime = list, coords, count, first, zone, now
  return list
end

function C.Ready()
  local route = pfQuest and pfQuest.route
  if not route or not route.arrow then
    return false, "pfQuest is not loaded"
  end
  if not (route.worldcoords or route.coords) then
    return false, "this pfQuest has no arrow route"
  end
  if not route.IsTarget then
    return false, "this pfQuest has no arrow targets (pfQuest.route.IsTarget)"
  end
  if C:Mode() == "maps" and not (pfQuestSmartArrowData and pfQuestSmartArrowData.zones) then
    return false, "zone table missing (data/zones.lua)"
  end
  if not C.Facing() then
    return false, "cannot read your facing"
  end
  return true
end

-- flight paths without C_TaxiMap ------------------------------------------------

-- The 1.12 flight map gives names and positions on the taxi map only. Where
-- each flight master stands comes from pfQuest's own list of them
-- (pfDB meta "flight"): the node you are at is the flight master nearest
-- you; the others are matched by zone (from the "Town, Zone" name), and
-- where a zone has several, by where they sit on the taxi map relative to
-- the ones already placed.
local function FlightMasters(zone, faction)
  local found = {}
  local meta = pfDB and pfDB["meta"] and pfDB["meta"]["flight"]
  local units = pfDB and pfDB["units"] and pfDB["units"]["data"]
  if not meta or not units then return found end
  for id, fac in pairs(meta) do
    if not fac or fac == "" or string.find(fac, faction) then
      local unit = units[id]
      if unit and unit["coords"] then
        for _, c in pairs(unit["coords"]) do
          if c[3] == zone then
            local wc, wn, ww = C.Resolve(zone, c[1], c[2])
            if wc then insert(found, { c = wc, n = wn, w = ww, zone = zone, x = c[1], y = c[2] }) end
          end
        end
      end
    end
  end
  return found
end

-- a zone id from a flight map name part: exact, or a zone whose name starts
-- with it (the 1.12 flight map shortens: "Elwynn", "Tirisfal", "Hillsbrad")
local function ZoneByName(name)
  if not name or name == "" then return nil end
  if pfMap and pfMap.GetMapIDByName then
    local id = pfMap:GetMapIDByName(name)
    if id then return id end
  end
  local loc = pfDB and pfDB["zones"] and pfDB["zones"]["loc"]
  local zones = pfQuestSmartArrowData and pfQuestSmartArrowData.zones
  if loc and zones then
    local len = string.len(name)
    for id, full in pairs(loc) do
      if zones[id] and string.sub(full, 1, len) == name then return id end
    end
  end
  return nil
end

-- every flight master of yours on a continent
local function AllFlightMasters(continent, faction)
  local found = {}
  local zones = pfQuestSmartArrowData and pfQuestSmartArrowData.zones or {}
  for zone, rect in pairs(zones) do
    if rect.c == continent then
      for _, fm in ipairs(FlightMasters(zone, faction)) do insert(found, fm) end
    end
  end
  return found
end

function C.RecordTaxiPositions(store)
  if not NumTaxiNodes or not TaxiNodeName or not TaxiNodePosition then return 0 end
  local faction = UnitFactionGroup("player") == "Horde" and "H" or "A"
  local count = NumTaxiNodes()
  local nodes = {}
  local here
  for i = 1, count do
    local kind = TaxiNodeGetType(i)
    if kind == "CURRENT" or kind == "REACHABLE" then
      local name = TaxiNodeName(i)
      local tx, ty = TaxiNodePosition(i)
      local _, _, town, zonename = string.find(name or "", "^(.-),%s*(.+)$")
      town = town or name
      -- "Ironforge, Dun Morogh": the flight master stands on the city's map
      local entry = { name = name, tx = tx, ty = ty, current = kind == "CURRENT",
        townzone = ZoneByName(town), zone = ZoneByName(zonename) }
      insert(nodes, entry)
      if entry.current then here = entry end
    end
  end

  -- the one you are standing at
  local pw, pn, _, pc = C.PlayerPosition()
  local placed = {}
  if here and pn then
    local m = C.LastMapPosition()
    here.pos = { c = pc, n = pn, w = pw }
    if m then here.pos.zone, here.pos.x, here.pos.y = m.zone, m.x, m.y end
    insert(placed, here)
  end
  -- zones with a single flight master of yours
  local pending = {}
  for _, e in ipairs(nodes) do
    if not e.pos then
      local list = {}
      if e.townzone then
        for _, fm in ipairs(FlightMasters(e.townzone, faction)) do insert(list, fm) end
        if getn(list) > 0 then e.zone = e.townzone end
      end
      if getn(list) == 0 and e.zone then
        list = FlightMasters(e.zone, faction)
      end
      if getn(list) == 1 then
        e.pos = list[1]
        insert(placed, e)
      else
        -- several in the zone, or the name did not lead to one: every
        -- flight master of yours on this continent, nearest the taxi map wins
        e.candidates = getn(list) > 1 and list or (here and here.pos and AllFlightMasters(here.pos.c, faction)) or {}
        insert(pending, e)
      end
    end
  end
  -- the rest: fit taxi-map -> world scale from the placed ones (relative to
  -- the first), then take the candidate nearest where the map puts it
  local origin = placed[1]
  if origin and getn(placed) >= 2 then
    local sx, sy, kx, ky = 0, 0, 0, 0
    for i = 2, getn(placed) do
      local e = placed[i]
      if e.pos.c == origin.pos.c then
        local dx, dy = e.tx - origin.tx, e.ty - origin.ty
        if dx ~= 0 then sx = sx + (e.pos.w - origin.pos.w) * dx kx = kx + dx * dx end
        if dy ~= 0 then sy = sy + (e.pos.n - origin.pos.n) * dy ky = ky + dy * dy end
      end
    end
    local scalew = kx > 0 and sx / kx or nil
    local scalen = ky > 0 and sy / ky or nil
    for _, e in ipairs(pending) do
      if scalew and scalen then
        local guess = { n = origin.pos.n + (e.ty - origin.ty) * scalen, w = origin.pos.w + (e.tx - origin.tx) * scalew }
        local best, bestd
        for _, cand in ipairs(e.candidates) do
          if cand.c == origin.pos.c then
            local dn, dw = cand.n - guess.n, cand.w - guess.w
            local d = dn * dn + dw * dw
            if not bestd or d < bestd then best, bestd = cand, d end
          end
        end
        e.pos = best
      end
    end
  end

  local added = 0
  for _, e in ipairs(nodes) do
    if e.pos and e.name then
      if not store[e.name] then added = added + 1 end
      -- kept as a map position, so a zone measured later moves it too
      store[e.name] = { c = e.pos.c, n = e.pos.n, w = e.pos.w, zone = e.pos.zone or e.zone, x = e.pos.x, y = e.pos.y }
    end
  end
  return added
end

-- calibrating approximate zones -----------------------------------------------

-- Walking from a zone we know exactly into one whose table entry is only an
-- estimate: your last position in the old zone is your position in the new
-- one a moment later, give or take a few yards. That fixes the new zone's
-- corner (l, t) from its map coordinates. Returns true when it did.
function C.Calibrate(previous, now)
  if C:Mode() ~= "maps" or not previous or not now then return false end
  if previous.zone == now.zone or previous.c ~= now.c then return false end
  local old, new = Rect(previous.zone), Rect(now.zone)
  local data = pfQuestSmartArrowData.zones[now.zone]
  if not old or not new or not data or not data.approx then return false end
  if old.approx or (pfQuestSmartArrow_config.zonefix or {})[now.zone] then return false end
  if now.time - previous.time > 1.5 then return false end
  local cfg = pfQuestSmartArrow_config
  cfg.zonefix = cfg.zonefix or {}
  cfg.zonefix[now.zone] = {
    l = previous.w + now.x / 100 * data.w,
    t = previous.n + now.y / 100 * data.h,
  }
  return true
end
