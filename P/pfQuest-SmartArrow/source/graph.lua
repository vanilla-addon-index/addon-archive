-- pfQuest SmartArrow
-- Copyright (C) 2026 pfQuest SmartArrow contributors
--
-- This program is free software: you can redistribute it and/or modify it
-- under the terms of the GNU General Public License as published by the Free
-- Software Foundation, either version 3 of the License, or (at your option)
-- any later version. It is distributed WITHOUT ANY WARRANTY; see LICENSE.md.

-- pfQuest SmartArrow route planner
--
-- A small travel graph in world space (yards, Map.dbc continent ids -- the
-- same frame UnitPosition and pfMap:GetWorldPos use):
--
--   connector  walkable zone border, belongs to the two zones it joins
--   dock       one end of a boat / zeppelin / tram / portal
--   taxi       a flight master the character knows
--
-- Walking is allowed between any two points on a continent, but it is only
-- cheap when both ends share a zone. Crossing a border anywhere other than a
-- connector costs WALK_OFFZONE times the distance plus a flat
-- WALK_OFFZONE_FLAT, which is what makes the
-- planner go round mountains through Dun Algaz or Thandol Span instead of
-- pointing straight over them, while still producing *some* route when the
-- connector data has a gap. Flights and transports are explicit edges.
--
-- Inside a zone, walking follows the walking network (data/walknet.lua):
-- borders, passes and gates whose straight walks were checked against the
-- game's terrain, with blocked pairs and known walls left out.
--
-- Single-source Dijkstra (heap, neighbour lists) from the player gives the
-- cost to every graph node at once, so ranking many quest objectives by real
-- travel time is a cheap extra pass over the result.
--
-- Written for the 1.12 client: Lua 5.0, so no '#', no '%', no select().

local sqrt, floor = math.sqrt, math.floor
local getn, insert = table.getn, table.insert

local G = {}
pfQuestSmartArrowGraph = G

local WALK_SAMEZONE = 1.10 -- roads are rarely straight
local WALK_OFFZONE = 2.50  -- border crossing without a known connector...
local WALK_OFFZONE_FLAT = 4000 -- ...plus this many yards, so short hops over
                               -- a ridge (Ironforge -> Menethil is ~1300 yd
                               -- as the crow flies) never beat the real road
local WALK_UNKNOWN = 1.60  -- one end has no zone (unresolved map)
local TAXI_DETOUR = 1.25   -- flight paths bend around the network
local TAXI_SPEED = 30      -- yards per second on a gryphon / wyvern
local TAXI_OVERHEAD = 15   -- talk to the flight master, take off, land
local INF = 1e30

G.nodes = {}
G.edges = {}
G.eff = {}
G.dirty = true

local function Dist(a, b)
  local dn, dw = a.n - b.n, a.w - b.w
  return sqrt(dn * dn + dw * dw)
end
G.Dist = Dist

local function ShareZone(a, b)
  if not a.zones or not b.zones then
    return nil
  end
  for z in pairs(a.zones) do
    if b.zones[z] then
      return true
    end
  end
  return false
end

-- effective walking yards between two points (distance x terrain penalty)
local function WalkYards(a, b)
  if a.c ~= b.c then
    return nil
  end
  local share = ShareZone(a, b)
  local factor
  if share == nil then
    factor = WALK_UNKNOWN
  elseif share then
    factor = WALK_SAMEZONE
  else
    factor = WALK_OFFZONE
  end
  if share == false then
    return Dist(a, b) * factor + WALK_OFFZONE_FLAT
  end
  return Dist(a, b) * factor
end
G.WalkYards = WalkYards

local function ZoneSet(a, b)
  local set = {}
  if a then set[a] = true end
  if b then set[b] = true end
  return set
end
G.ZoneSet = ZoneSet

-- zone map percent -> continent, north, west, whatever this pfQuest/client
-- offers (see compat.lua)
local function Resolve(zone, x, y)
  return pfQuestSmartArrowCompat.Resolve(zone, x, y)
end
G.Resolve = Resolve

local function ZoneName(id)
  if id and pfMap and pfMap.GetMapNameByID then
    return pfMap:GetMapNameByID(id)
  end
  return nil
end
G.ZoneName = ZoneName

local function AddNode(node)
  insert(G.nodes, node)
  node.id = getn(G.nodes)
  G.edges[node.id] = {}
  return node
end

local function AddEdge(a, b, time, kind, info)
  insert(G.edges[a.id], { to = b.id, time = time, kind = kind, info = info })
end

local function FactionOK(f)
  if not f then
    return true
  end
  local mine = UnitFactionGroup("player")
  if mine == "Alliance" then
    return f == "A"
  elseif mine == "Horde" then
    return f == "H"
  end
  return true
end

-- TaxiNodes.dbc faction: 0 neutral, 1 horde, 2 alliance
local function TaxiFactionOK(f)
  if not f or f == 0 then
    return true
  end
  local mine = UnitFactionGroup("player")
  if mine == "Alliance" then
    return f == 2
  elseif mine == "Horde" then
    return f == 1
  end
  return true
end

local function TaxiKnown(node)
  local mode = pfQuestSmartArrow_config and pfQuestSmartArrow_config.taxi or "known"
  if mode == "none" then
    return false
  elseif mode == "all" then
    return true
  end
  local known = pfQuestSmartArrow_char and pfQuestSmartArrow_char.taxi
  return known and node.name and known[node.name] and true or false
end

-- moving speed in yards per second for planning (not for the live ETA)
function G:Speed()
  local cfg = pfQuestSmartArrow_config or {}
  if cfg.speed and tonumber(cfg.speed) then
    return tonumber(cfg.speed)
  end
  local mountlevel = tonumber(cfg.mountlevel) or 40
  if UnitLevel("player") >= mountlevel then
    return 7 * 1.6
  end
  return 7
end

-- the walking network (data/walknet.lua) -------------------------------------

local WN -- parsed once: nodes, links, blocked/clear pairs, regions, barriers

local function Lines(text, fn)
  if not text then return end
  for line in string.gfind(text, "[^\n]+") do
    local f = {}
    for v in string.gfind(line, "%S+") do insert(f, v) end
    if f[1] then fn(f) end
  end
end

local function PairKey(a, b)
  if a > b then a, b = b, a end
  return a * 65536 + b
end

function G:Walknet()
  if WN ~= nil then return WN or nil end
  local data = pfQuestSmartArrowData and pfQuestSmartArrowData.walknet
  if not data then WN = false return nil end
  local wn = { nodes = {}, links = {}, blocked = {}, clear = {}, regions = {}, barriers = {}, areazones = {}, zonearea = data.zonearea or {} }
  for zone, area in pairs(wn.zonearea) do
    if not wn.areazones[area] then wn.areazones[area] = {} end
    wn.areazones[area][zone] = true
  end
  local KIND = { b = "border", p = "pass", g = "gate" }
  Lines(data.nodes, function(f)
    insert(wn.nodes, { kind = KIND[f[1]] or "pass", area = tonumber(f[2]), c = tonumber(f[3]), n = tonumber(f[4]), w = tonumber(f[5]) })
  end)
  Lines(data.links, function(f)
    insert(wn.links, { a = tonumber(f[1]), b = tonumber(f[2]), method = f[3], cost = tonumber(f[4]) or 0, oneway = f[5] == "1" })
  end)
  Lines(data.blocked, function(f) wn.blocked[PairKey(tonumber(f[1]), tonumber(f[2]))] = true end)
  Lines(data.clear, function(f) wn.clear[PairKey(tonumber(f[1]), tonumber(f[2]))] = true end)
  Lines(data.regions, function(f)
    local zone = tonumber(f[1])
    if not wn.regions[zone] then wn.regions[zone] = {} end
    insert(wn.regions[zone], { area = tonumber(f[2]), x = tonumber(f[3]), y = tonumber(f[4]), r = tonumber(f[5]) })
  end)
  Lines(data.barriers, function(f)
    insert(wn.barriers, { c = tonumber(f[1]), n1 = tonumber(f[2]), w1 = tonumber(f[3]), n2 = tonumber(f[4]), w2 = tonumber(f[5]) })
  end)
  WN = wn
  return wn
end

-- the zone set of an area: the zones whose main area it is, or the area
-- itself (a tunnel, an approach, an island) when it is nobody's main area
local function AreaZones(wn, area)
  local set = wn.areazones[area]
  if set then return set end
  set = {}
  set["a" .. area] = true
  wn.areazones[area] = set
  return set
end

-- zone map percent of a world point, for the region test
local maps = {}
function G:ResetMaps() maps = {} end
local function ToMap(zone, n, w)
  local t = maps[zone]
  if t == nil then
    local c, n0, w0 = Resolve(zone, 0, 0)
    local _, n1, w1 = Resolve(zone, 100, 100)
    t = (c and n1 and n1 ~= n0 and w1 ~= w0) and { n0 = n0, w0 = w0, dn = n1 - n0, dw = w1 - w0 } or false
    maps[zone] = t
  end
  if not t then return nil end
  return (w - t.w0) / t.dw * 100, (n - t.n0) / t.dn * 100
end

-- The zones a free point (you, an objective) counts as being in for walking.
-- Inside a region that is its own area (the Dun Algaz tunnel, Ironforge's
-- approach), that area; otherwise the zone's walking area.
function G:PointZones(zone, n, w)
  if not zone then return nil end
  local wn = self:Walknet()
  if not wn or not wn.zonearea[zone] then
    return ZoneSet(zone)
  end
  local regions = wn.regions[zone]
  if regions and n and w then
    local x, y = ToMap(zone, n, w)
    if x then
      for _, r in ipairs(regions) do
        local dx, dy = x - r.x, y - r.y
        if dx * dx + dy * dy <= r.r * r.r then
          return AreaZones(wn, r.area)
        end
      end
    end
  end
  local set = {}
  for z in pairs(AreaZones(wn, wn.zonearea[zone])) do set[z] = true end
  set[zone] = true
  return set
end

-- a straight walk from p to q runs through one of the known walls?
local function CrossesBarrier(wn, p, q)
  for _, b in ipairs(wn.barriers) do
    if b.c == p.c then
      local function side(an, aw, bn, bw, cn, cw) return (bn - an) * (cw - aw) - (bw - aw) * (cn - an) end
      local s1 = side(p.n, p.w, q.n, q.w, b.n1, b.w1)
      local s2 = side(p.n, p.w, q.n, q.w, b.n2, b.w2)
      local s3 = side(b.n1, b.w1, b.n2, b.w2, p.n, p.w)
      local s4 = side(b.n1, b.w1, b.n2, b.w2, q.n, q.w)
      if s1 * s2 <= 0 and s3 * s4 <= 0 then return true end
    end
  end
  return false
end

-- the zone-level graph ----------------------------------------------------------

local IMPLICIT_REACH = 350 -- yards: unchecked straight walks between network points

local function Covered(wn, zone)
  return wn and wn.zonearea[zone] ~= nil
end

function G:Rebuild()
  self.nodes, self.edges, self.adj, self.byzone, self.free = {}, {}, {}, {}, {}
  self.dirty = nil

  local data = pfQuestSmartArrowData or {}
  local wn = self:Walknet()

  -- the walking network: zone borders, passes, gates (fixed, numbered first)
  self.netcount = 0
  if wn then
    for i, nd in ipairs(wn.nodes) do
      AddNode({ kind = nd.kind, c = nd.c, n = nd.n, w = nd.w, zones = AreaZones(wn, nd.area),
        area = nd.area, net = i, radius = nd.kind == "pass" and 20 or 25 })
    end
    self.netcount = getn(wn.nodes)
    -- what is on the other side of a border, for "Go to <zone>". An area
    -- can hold a zone and its city (Tirisfal and Undercity); name the zone.
    local CITY = { [1519] = true, [1537] = true, [1497] = true, [1637] = true, [1638] = true, [1657] = true }
    local function Named(zones)
      local pick
      for z in pairs(zones) do
        if type(z) == "number" and (not pick or (CITY[pick] and not CITY[z])) then pick = z end
      end
      return pick
    end
    for _, l in ipairs(wn.links) do
      local a, b = self.nodes[l.a], self.nodes[l.b]
      if a and b and l.method == "w" and a.area ~= b.area then
        a.dest = a.dest or Named(b.zones)
        b.dest = b.dest or Named(a.zones)
      end
    end
    -- a border into a tunnel or pass of its own (Dun Algaz): name the zone at
    -- the far end of it instead
    local onward = {}
    for _, l in ipairs(wn.links) do
      local a, b = self.nodes[l.a], self.nodes[l.b]
      if a and b and a.area ~= b.area then
        local za, zb = Named(a.zones), Named(b.zones)
        if not za and zb then onward[a.area] = onward[a.area] or {} insert(onward[a.area], zb) end
        if not zb and za then onward[b.area] = onward[b.area] or {} insert(onward[b.area], za) end
      end
    end
    for _, l in ipairs(wn.links) do
      local a, b = self.nodes[l.a], self.nodes[l.b]
      if a and b and l.method == "w" and a.area ~= b.area then
        for _, pair in ipairs({ { a, b }, { b, a } }) do
          local from, to = pair[1], pair[2]
          if not from.dest and onward[to.area] then
            local here = Named(from.zones)
            for _, z in ipairs(onward[to.area]) do
              if z ~= here then from.dest = z break end
            end
          end
        end
      end
    end
  end

  -- hand-made connectors, only where the network does not cover both zones
  for _, con in ipairs(data.connectors or {}) do
    if not (Covered(wn, con.links[1]) and Covered(wn, con.links[2])) then
      local c, n, w = Resolve(con.zone, con.x, con.y)
      if c then
        AddNode({
          kind = "connector", c = c, n = n, w = w,
          zones = ZoneSet(con.links[1], con.links[2]),
          links = con.links, name = con.name, radius = 60,
        })
      end
    end
  end

  -- connectors learned while playing
  local learned = pfQuestSmartArrow_config and pfQuestSmartArrow_config.learned or {}
  for _, con in ipairs(learned) do
    if con.c and con.n and con.w and con.links then
      AddNode({
        kind = "connector", c = con.c, n = con.n, w = con.w,
        zones = ZoneSet(con.links[1], con.links[2]),
        links = con.links, name = con.name, radius = 40, learned = true,
      })
    end
  end

  -- transports
  for _, t in ipairs(data.transports or {}) do
    if FactionOK(t.faction) then
      local ca, na, wa = Resolve(t.a.zone, t.a.x, t.a.y)
      local cb, nb, wb = Resolve(t.b.zone, t.b.x, t.b.y)
      if ca and cb then
        local a = AddNode({ kind = "dock", c = ca, n = na, w = wa, zones = self:PointZones(t.a.zone, na, wa), name = t.a.name, town = t.a.town, radius = 35 })
        local b = AddNode({ kind = "dock", c = cb, n = nb, w = wb, zones = self:PointZones(t.b.zone, nb, wb), name = t.b.name, town = t.b.town, radius = 35 })
        AddEdge(a, b, t.time, t.kind)
        AddEdge(b, a, t.time, t.kind)
      end
    end
  end

  -- known flight masters
  local taxis = {}
  if not (C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap) then
    -- a plain 1.12 client: the flight masters placed when you opened a
    -- flight map (compat.lua); all of them are yours and known
    local mode = pfQuestSmartArrow_config and pfQuestSmartArrow_config.taxi or "known"
    if mode ~= "none" then
      for name, p in pairs(pfQuestSmartArrow_char and pfQuestSmartArrow_char.taxipos or {}) do
        local c, n, w = p.c, p.n, p.w
        if p.zone and p.x and p.y then
          local rc, rn, rw = Resolve(p.zone, p.x, p.y)
          if rc then c, n, w = rc, rn, rw end
        end
        if c and n and w then
          insert(taxis, AddNode({
            kind = "taxi", c = c, n = n, w = w,
            zones = p.zone and self:PointZones(p.zone, n, w) or nil,
            name = name, radius = 25,
          }))
        end
      end
    end
  elseif C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap then
    local ok, list = pcall(C_TaxiMap.GetTaxiNodesForMap)
    if ok and list then
      for _, t in ipairs(list) do
        if t.areaID and t.mapX and t.mapY and TaxiFactionOK(t.faction) and TaxiKnown(t) then
          local c, n, w = Resolve(t.areaID, t.mapX, t.mapY)
          if c then
            insert(taxis, AddNode({
              kind = "taxi", c = c, n = n, w = w, zones = self:PointZones(t.areaID, n, w),
              name = t.name, taxiid = t.nodeID, radius = 25,
            }))
          end
        end
      end
    end
  end
  for i = 1, getn(taxis) do
    for j = 1, getn(taxis) do
      local a, b = taxis[i], taxis[j]
      if i ~= j and a.c == b.c then
        AddEdge(a, b, Dist(a, b) * TAXI_DETOUR / TAXI_SPEED + TAXI_OVERHEAD, "taxi")
      end
    end
  end

  local nodes = self.nodes
  local count = getn(nodes)
  for i = 1, count do
    self.adj[i] = {}
    if not nodes[i].net then insert(self.free, i) end
    for z in pairs(nodes[i].zones or {}) do
      if not self.byzone[z] then self.byzone[z] = {} end
      insert(self.byzone[z], i)
    end
  end

  -- walking edges, stored as yards so mounting up needs no rebuild
  local seen = {}
  local function Walk(i, j, yards)
    local key = PairKey(i, j)
    if seen[key] then return end
    seen[key] = true
    insert(self.adj[i], j) insert(self.adj[i], yards)
    insert(self.adj[j], i) insert(self.adj[j], yards)
  end

  -- The walking network never changes, so its own edges (surveyed links and
  -- the walks between its points) are worked out once and copied on later
  -- rebuilds; only the other nodes (connectors, docks, flight masters) are
  -- joined up again. That keeps a rebuild after learning a border or a
  -- flight path from stalling a frame.
  local netcount = self.netcount
  local cache = wn and self.netcache
  -- inside a background search this lets the rebuild pause between frames
  local Step = pfQuestSmartArrowNav and pfQuestSmartArrowNav.Step or function() end
  if cache and cache.count ~= netcount then cache = nil end

  -- lifts are timed edges, kept in self.edges: always added
  if wn then
    for _, l in ipairs(wn.links) do
      local a, b = nodes[l.a], nodes[l.b]
      if a and b and l.method == "l" and l.cost > 0 then
        AddEdge(a, b, l.cost, "lift")
        if not l.oneway then AddEdge(b, a, l.cost, "lift") end
      end
    end
  end

  -- walking inside an area: allowed unless the terrain check found it blocked
  -- or it runs through a known wall (that is how the data is meant: a
  -- straight walk inside an area is fine unless shown otherwise). Two
  -- passes far apart are only joined when checked clear, which keeps the
  -- Barrens' 310 points from turning into 48,000 edges.
  local function Pair(i, j)
    local p, q = nodes[i], nodes[j]
    if p.c ~= q.c then return end
    local d = Dist(p, q)
    local factor = WALK_SAMEZONE
    if p.net and q.net then
      local key = PairKey(p.net, q.net)
      if wn.blocked[key] then
        return
      elseif wn.clear[key] then
        factor = 1.0
      elseif d > IMPLICIT_REACH and p.kind == "pass" and q.kind == "pass" then
        -- two passes far apart: only if checked (keeps the graph small);
        -- borders and gates reach across their whole area
        return
      end
    end
    if wn and getn(wn.barriers) > 0 and CrossesBarrier(wn, p, q) then
      return
    end
    Walk(i, j, d * factor)
  end

  if cache then
    for i = 1, netcount do
      local src, dst = cache[i], self.adj[i]
      Step(floor(getn(src) / 16) + 1)
      for k = 1, getn(src) do dst[k] = src[k] end
    end
    for _, key in ipairs(cache.keys) do seen[key] = true end
  elseif wn then
    -- surveyed links: crossings, tunnels, gates
    for _, l in ipairs(wn.links) do
      local a, b = nodes[l.a], nodes[l.b]
      if a and b and not (l.method == "l" and l.cost > 0) then
        local yards = l.method == "g" and 2 or Dist(a, b)
        if l.oneway then
          insert(self.adj[l.a], l.b) insert(self.adj[l.a], yards)
        else
          Walk(l.a, l.b, yards)
        end
      end
    end
    -- walks between network points
    for _, list in pairs(self.byzone) do
      local size = getn(list)
      for x = 1, size do
        local i = list[x]
        if i <= netcount then
          for y = x + 1, size do
            local j = list[y]
            if j <= netcount then Pair(i, j) Step() end
          end
        end
      end
    end
    cache = { count = netcount, keys = {} }
    for i = 1, netcount do
      local src, copy = self.adj[i], {}
      for k = 1, getn(src) do copy[k] = src[k] end
      cache[i] = copy
    end
    for key in pairs(seen) do insert(cache.keys, key) end
    self.netcache = cache
  end

  -- everything else: each free node against the nodes sharing a zone with it
  for _, i in ipairs(self.free) do
    for z in pairs(nodes[i].zones or {}) do
      local list = self.byzone[z]
      for y = 1, getn(list or {}) do
        local j = list[y]
        Step()
        if j ~= i and not seen[PairKey(i, j)] then Pair(i, j) end
      end
    end
  end

  self.taxicount = getn(taxis)
end

-- a binary heap of node ids ordered by dist[]
local function HeapPush(heap, dist, v)
  local i = getn(heap) + 1
  heap[i] = v
  while i > 1 do
    local parent = floor(i / 2)
    if dist[heap[parent]] <= dist[v] then break end
    heap[i] = heap[parent]
    i = parent
  end
  heap[i] = v
end

local function HeapPop(heap, dist)
  local size = getn(heap)
  if size == 0 then return nil end
  local top = heap[1]
  local last = heap[size]
  heap[size] = nil
  size = size - 1
  if size > 0 then
    local i = 1
    while true do
      local child = i * 2
      if child > size then break end
      if child < size and dist[heap[child + 1]] < dist[heap[child]] then child = child + 1 end
      if dist[heap[child]] >= dist[last] then break end
      heap[i] = heap[child]
      i = child
    end
    heap[i] = last
  end
  return top
end

-- Dijkstra from a free point { c, n, w, zones }. Leaves self.dist / self.prev
-- / self.via filled in for CostTo and PathTo.
function G:Solve(start)
  if self.dirty then
    self:Rebuild()
  end

  local nodes, adj, edges = self.nodes, self.adj, self.edges
  local count = getn(nodes)
  local speed = self:Speed()
  local dist, prev, via, done = {}, {}, {}, {}
  local heap = {}
  -- lets a background search pause between frames (nav.lua)
  local Step = pfQuestSmartArrowNav and pfQuestSmartArrowNav.Step or function() end

  for i = 1, count do
    Step()
    local y = WalkYards(start, nodes[i])
    dist[i] = y and y / speed or INF
    prev[i] = 0
    via[i] = "walk"
    if dist[i] < INF then HeapPush(heap, dist, i) end
  end

  while true do
    local u = HeapPop(heap, dist)
    if not u then break end
    if not done[u] then
      done[u] = true
      local best = dist[u]
      local row = adj[u]
      Step(floor(getn(row) / 8) + 1)
      for k = 1, getn(row), 2 do
        local v = row[k]
        if not done[v] then
          local t = best + row[k + 1] / speed
          if t < dist[v] then
            dist[v], prev[v], via[v] = t, u, "walk"
            HeapPush(heap, dist, v)
          end
        end
      end
      for _, e in ipairs(edges[u]) do
        local v = e.to
        if not done[v] then
          local t = best + e.time
          if t < dist[v] then
            dist[v], prev[v], via[v] = t, u, e.kind
            HeapPush(heap, dist, v)
          end
        end
      end
    end
  end

  self.start, self.dist, self.prev, self.via, self.speed = start, dist, prev, via, speed
end

-- travel seconds from the last Solve start to a free point, and the graph
-- node the final walk leaves from (0 = straight from the start). Only nodes
-- in the target's walking area, and the hand-placed ones, can be the last
-- stop before it.
function G:CostTo(target)
  if not self.start then
    return INF, 0
  end
  local speed = self.speed
  local best, from = INF, 0
  local y = WalkYards(self.start, target)
  if y then
    best = y / speed
  end
  local nodes, dist = self.nodes, self.dist
  local function Try(i)
    if dist[i] < best then
      local wy = WalkYards(nodes[i], target)
      if wy then
        local t = dist[i] + wy / speed
        if t < best then
          best, from = t, i
        end
      end
    end
  end
  local tried = {}
  for z in pairs(target.zones or {}) do
    for _, i in ipairs(self.byzone[z] or {}) do
      if not tried[i] then tried[i] = true Try(i) end
    end
  end
  for _, i in ipairs(self.free or {}) do
    if not tried[i] then Try(i) end
  end
  return best, from
end

-- ordered legs { kind, from = point, to = point, node = graph node or nil }
function G:PathTo(target)
  local total, from = self:CostTo(target)
  if total >= INF then
    return nil
  end

  local chain = {}
  local i = from
  while i and i > 0 do
    insert(chain, 1, i)
    i = self.prev[i]
  end

  local legs = {}
  local last = self.start
  for _, id in ipairs(chain) do
    local node = self.nodes[id]
    insert(legs, { kind = self.via[id], from = last, to = node })
    last = node
  end
  insert(legs, { kind = "walk", from = last, to = target, final = true })

  return { total = total, legs = legs }
end

G.INF = INF
