-- pfQuest SmartArrow
-- Copyright (C) 2026 pfQuest SmartArrow contributors
--
-- This program is free software: you can redistribute it and/or modify it
-- under the terms of the GNU General Public License as published by the Free
-- Software Foundation, either version 3 of the License, or (at your option)
-- any later version. It is distributed WITHOUT ANY WARRANTY; see LICENSE.md.

-- pfQuest SmartArrow: local navigation
--
-- graph.lua decides *which* zone exits, flights and boats to take. This file
-- decides how to walk each stretch in between, so the arrow and the map path
-- bend around things instead of running straight at them:
--
--   obstacles  circles you cannot walk through. A few ship in
--              data/obstacles.lua (placed from pfQuest's own NPC positions),
--              the rest are learned: when you keep sliding sideways while
--              facing the arrow, something is in the way, and a small circle
--              is added there.
--   trails     the paths you actually walk, recorded as you play. Walked
--              ground is known to be passable and is mostly road, so the
--              planner prefers it.
--   danger     a per-zone grid built from pfQuest's spawn data: hostile mobs
--              weighted by their level against yours (elites count triple,
--              grey mobs and critters not at all). Paths are charged extra
--              for crossing it, so they skirt camps when the detour is worth it.
--
-- Refine(a, b, zone) returns a polyline from a to b. The search runs on a
-- small local graph: a, b, points around nearby obstacles, nearby trail
-- points and a coarse lattice for detours, with straight edges between
-- neighbours that do not cross an obstacle.
--
-- Lua 5.0: no '#', no '%', no select().

local sqrt, floor, cos, sin, atan2, abs, pi = math.sqrt, math.floor, math.cos, math.sin, math.atan2, math.abs, math.pi
local getn, insert = table.getn, table.insert

local N = CreateFrame("Frame", "pfQuestSmartArrowNav", UIParent)
pfQuestSmartArrowNav = N

local TRAIL_STEP = 12     -- yards between recorded trail points
local TRAIL_SNAP = 6      -- reuse a trail point this close
local TRAIL_BREAK = 60    -- a jump this long is a teleport, not a walk
local TRAIL_FACTOR = 0.75 -- walked ground costs this much of open ground
local TRAIL_CAP = 30000   -- recorded points, account wide
local HASH = 50           -- spatial hash cell, yards
local RING = 8            -- points around each obstacle
local RING_PAD = 9        -- yards outside the obstacle edge
local MAX_TRAIL_NODES = 140
local MAX_LATTICE = 90

local function Dist(a, b)
  local dn, dw = a.n - b.n, a.w - b.w
  return sqrt(dn * dn + dw * dw)
end

local function Cfg()
  return pfQuestSmartArrow_config
end

-- world <-> zone map ----------------------------------------------------------

local transforms = {}
function N:ResetTransforms() transforms = {} self.dangercache = {} end
function N:Transform(zone)
  if not zone then return nil end
  local t = transforms[zone]
  if t == nil then
    local G = pfQuestSmartArrowGraph
    local c, n0, w0 = G.Resolve(zone, 0, 0)
    local _, n1, w1 = G.Resolve(zone, 100, 100)
    if c and n1 and n1 ~= n0 and w1 ~= w0 then
      t = { c = c, n0 = n0, w0 = w0, dn = n1 - n0, dw = w1 - w0 }
    else
      t = false
    end
    transforms[zone] = t
  end
  return t or nil
end

-- zone map percent of a world point (may lie outside 0..100)
function N:WorldToMap(zone, n, w)
  local t = self:Transform(zone)
  if not t then return nil end
  return (w - t.w0) / t.dw * 100, (n - t.n0) / t.dn * 100, t.c
end

-- danger ----------------------------------------------------------------------

N.grid = nil       -- [zone][cell] = { [level] = weight }
N.dangercache = {} -- [zone][cell] = value, for one player level
N.dangerlevel = nil

local function MaxLevel(lvl)
  if not lvl then return 1 end
  local best = 1
  for num in string.gfind(lvl, "%d+") do
    local v = tonumber(num)
    if v and v > best then best = v end
  end
  return best
end

local function CellKey(x, y)
  return floor(x) * 128 + floor(y)
end

-- built once per login in small slices so the client does not hitch
function N:StartDangerBuild()
  if self.builder or self.grid then return end
  if not (pfDB and pfDB["units"] and pfDB["units"]["data"]) then return end
  local mine = UnitFactionGroup("player") == "Horde" and "H" or "A"
  local grid = {}
  self.builder = coroutine.create(function()
    local count = 0
    for _, unit in pairs(pfDB["units"]["data"]) do
      local fac = unit["fac"]
      local coords = unit["coords"]
      if coords and (not fac or not string.find(fac, mine)) then
        local level = MaxLevel(unit["lvl"])
        local rank = tonumber(unit["rnk"]) or 0
        local weight = (rank == 1 or rank == 2 or rank == 3) and 3 or 1
        for _, c in pairs(coords) do
          local x, y, zone = c[1], c[2], c[3]
          if zone and x and y then
            local zgrid = grid[zone]
            if not zgrid then zgrid = {} grid[zone] = zgrid end
            local key = CellKey(x, y)
            local cell = zgrid[key]
            if not cell then cell = {} zgrid[key] = cell end
            cell[level] = (cell[level] or 0) + weight
          end
        end
      end
      count = count + 1
      if count >= 250 then
        count = 0
        coroutine.yield()
      end
    end
    N.grid = grid
  end)
end

local function LevelWeight(mob, me)
  if mob <= 1 and me > 3 then return 0 end -- critters
  local d = mob - me
  if d <= -8 then return 0 end              -- grey, will not attack
  if d <= -4 then return 0.3 end
  local w = 1 + 0.35 * d
  if w > 4 then w = 4 end
  if w < 0.5 then w = 0.5 end
  return w
end

local function CellDanger(zgrid, key, me)
  local cell = zgrid[key]
  if not cell then return 0 end
  local sum = 0
  for level, weight in pairs(cell) do
    sum = sum + weight * LevelWeight(level, me)
  end
  return sum
end

-- hostile pressure at a world point, roughly "mobs that may attack you here"
function N:DangerAt(zone, p)
  local grid = self.grid
  if not grid or not zone then return 0 end
  local zgrid = grid[zone]
  if not zgrid then return 0 end
  local x, y = self:WorldToMap(zone, p.n, p.w)
  if not x or x < 0 or x >= 100 or y < 0 or y >= 100 then return 0 end

  local me = UnitLevel("player")
  if self.dangerlevel ~= me then
    self.dangerlevel = me
    self.dangercache = {}
  end
  local zcache = self.dangercache[zone]
  if not zcache then zcache = {} self.dangercache[zone] = zcache end

  local key = CellKey(x, y)
  local v = zcache[key]
  if not v then
    -- the cell itself plus some of its neighbours: aggro reaches across lines
    v = CellDanger(zgrid, key, me)
      + 0.4 * (CellDanger(zgrid, key + 128, me) + CellDanger(zgrid, key - 128, me)
             + CellDanger(zgrid, key + 1, me) + CellDanger(zgrid, key - 1, me))
    zcache[key] = v
  end
  return v
end

local function Safety()
  local s = tonumber(Cfg().safety)
  if not s then return 1 end
  return s
end

-- multiplier on walking cost for a given danger value
local function DangerFactor(d)
  local f = 1 + Safety() * 0.5 * d
  if f > 6 then f = 6 end
  return f
end

-- obstacles -------------------------------------------------------------------

N.shipped = {}

function N:ResolveObstacles()
  self.shipped = {}
  local G = pfQuestSmartArrowGraph
  for _, o in ipairs(pfQuestSmartArrowData and pfQuestSmartArrowData.obstacles or {}) do
    local c, n, w = G.Resolve(o.zone, o.x, o.y)
    if c then
      local ob = { c = c, n = n, w = w, r = o.r, name = o.name, area = o.area, up = o.up, down = o.down }
      if o.doors then
        ob.doors = {}
        for _, d in ipairs(o.doors) do
          local dc, dn, dw = G.Resolve(d.zone or o.zone, d.x, d.y)
          if dc then insert(ob.doors, { c = dc, n = dn, w = dw }) end
        end
      end
      insert(self.shipped, ob)
    end
  end
end

-- inside it? For a building that means you are going in or out, so it is
-- not in your way. A learned obstacle is only a guess at a rock or a wall,
-- so you have to be well inside before it stops counting.
local function Within(o, p)
  return Dist(o, p) <= (o.learned and o.r * 0.5 or o.r)
end

local function EachObstacle(fn)
  for _, o in ipairs(N.shipped) do fn(o) end
  for _, o in ipairs(Cfg().obstacles) do fn(o) end
end

-- the structure (a tree or building with doors) a point is on or in
local function StructureAt(p)
  for _, o in ipairs(N.shipped) do
    if o.doors and o.area and o.c == p.c and Dist(o, p) < o.area then
      return o
    end
  end
  return nil
end
N.StructureAt = function(self, p) return StructureAt(p) end

-- does segment p-q pass through circle o?
local function SegmentHits(p, q, o)
  local dn, dw = q.n - p.n, q.w - p.w
  local len2 = dn * dn + dw * dw
  local t = 0
  if len2 > 0 then
    t = ((o.n - p.n) * dn + (o.w - p.w) * dw) / len2
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
  end
  local cn, cw = p.n + dn * t - o.n, p.w + dw * t - o.w
  return cn * cn + cw * cw < o.r * o.r
end

local function SegmentClear(p, q, obs)
  for i = 1, getn(obs) do
    if SegmentHits(p, q, obs[i]) then return false end
  end
  return true
end

local function InsideAny(p, obs)
  for i = 1, getn(obs) do
    local o = obs[i]
    if Dist(p, o) < o.r then return true end
  end
  return false
end

-- trails ----------------------------------------------------------------------

N.hash = {} -- [c][key] = { index, ... }
N.roads = {}    -- built-in roads from NPC patrols, same shape as trails
N.roadhash = {}

local function HashKey(n, w)
  return floor(n / HASH) .. ":" .. floor(w / HASH)
end

local function Trails(c)
  local all = Cfg().trails
  local t = all[c]
  if not t then
    t = { n = {}, w = {}, l = {} }
    all[c] = t
  end
  return t
end

function N:RebuildHash()
  self.hash = {}
  for c, t in pairs(Cfg().trails) do
    local h = {}
    self.hash[c] = h
    for i = 1, getn(t.n) do
      local key = HashKey(t.n[i], t.w[i])
      if not h[key] then h[key] = {} end
      insert(h[key], i)
    end
  end
end

function N:TrailCount()
  local total = 0
  for _, t in pairs(Cfg().trails) do total = total + getn(t.n) end
  return total
end

local function NearestTrail(c, p, radius)
  local h = N.hash[c]
  if not h then return nil end
  local t = Cfg().trails[c]
  local best, bestd
  local cn, cw = floor(p.n / HASH), floor(p.w / HASH)
  for dn = -1, 1 do
    for dw = -1, 1 do
      local list = h[(cn + dn) .. ":" .. (cw + dw)]
      if list then
        for _, i in ipairs(list) do
          local en, ew = t.n[i] - p.n, t.w[i] - p.w
          local d = sqrt(en * en + ew * ew)
          if d <= radius and (not bestd or d < bestd) then
            best, bestd = i, d
          end
        end
      end
    end
  end
  return best
end

local function Link(t, a, b)
  if a == b then return end
  local la = t.l[a]
  for _, v in ipairs(la) do if v == b then return end end
  insert(la, b)
  insert(t.l[b], a)
end

-- remember where you walk
function N:Record(player, now)
  -- ground height for structures: wherever you stand outside one
  if player.z and not player.taxi and not StructureAt(player) then
    self.groundz = player.z
  end

  if Cfg().trails_on == "0" or player.taxi or not player.c then
    self.lasttrail = nil
    return
  end
  local last = self.lasttrail
  if last and last.c == player.c and Dist(last, player) < TRAIL_STEP then
    return
  end

  -- walking through the middle of a learned obstacle proves it was wrong
  local obstacles = Cfg().obstacles
  for i = getn(obstacles), 1, -1 do
    local o = obstacles[i]
    if o.c == player.c and Dist(o, player) < o.r * 0.5 then
      table.remove(obstacles, i)
    end
  end

  local t = Trails(player.c)
  local index = NearestTrail(player.c, player, TRAIL_SNAP)
  if not index then
    if self:TrailCount() >= TRAIL_CAP then return end
    insert(t.n, player.n)
    insert(t.w, player.w)
    insert(t.l, {})
    index = getn(t.n)
    local h = self.hash[player.c]
    if not h then h = {} self.hash[player.c] = h end
    local key = HashKey(player.n, player.w)
    if not h[key] then h[key] = {} end
    insert(h[key], index)
  end

  if last and last.c == player.c and last.index and now - last.time < 12
    and Dist(last, player) < TRAIL_BREAK then
    Link(t, last.index, index)
  end
  self.lasttrail = { c = player.c, n = player.n, w = player.w, index = index, time = now }
end

-- stuck detection -------------------------------------------------------------

N.history = {}
N.stuck = 0

-- Called every sample while the arrow points somewhere on foot. Returns true
-- when it has just learned an obstacle.
--
-- Running into something in WoW does not stop you dead: you slide along it,
-- keeping only the part of your movement that runs along the surface. So the
-- sign of a blocked path is moving, but at well under your usual speed, while
-- facing where the arrow points. Running straight into something stops you
-- instead, so "was running, now stopped dead, still facing the arrow" counts
-- too. Fighting (snares) and the last few yards are ignored. A wrong guess is
-- cheap: the circle is small, and walking through its middle later deletes it
-- (see Record).
function N:Observe(player, aim, goal, now, facing)
  local hist = self.history
  insert(hist, { t = now, n = player.n, w = player.w, c = player.c })
  while hist[1] and now - hist[1].t > 1.05 do
    table.remove(hist, 1)
  end
  local old = hist[1]
  local span = old and (now - old.t) or 0
  local speed = (span > 0 and old.c == player.c) and Dist(old, player) / span or 0

  -- your usual speed: the fastest you moved lately, slowly forgotten
  local usual = (self.usual or 7) * 0.995
  if speed > usual and speed < 40 then usual = speed end
  if usual < 7 then usual = 7 end
  self.usual = usual

  -- on a ramp or in a building we know about, turning and climbing is
  -- expected; do not mistake it for a wall
  if StructureAt(player) then
    self.stuck = 0
    return false
  end

  if Cfg().learn ~= "1" or not aim or not goal or not facing or player.taxi or span < 0.7
    or (UnitAffectingCombat and UnitAffectingCombat("player")) or Dist(player, goal) < 15 then
    self.stuck = 0
    return false
  end

  local want = atan2(aim.w - player.w, aim.n - player.n)
  local off = abs(want - facing)
  while off > pi do off = abs(off - 2 * pi) end

  if speed >= 0.8 * usual then
    self.running = now
  end
  local sliding = speed > 0.5 and speed < 0.6 * usual
  local stopped = speed <= 0.5 and self.running and now - self.running < 2.5
  if (sliding or stopped) and off < 0.6 then
    self.stuck = self.stuck + 0.25
  else
    self.stuck = 0
  end
  if self.stuck < 1.25 then
    return false
  end
  self.stuck = 0
  self.running = nil

  -- you are at its edge: put the centre a little more than one radius ahead
  local d = Dist(player, aim)
  if d < 0.1 then return false end
  local spot = {
    c = player.c,
    n = player.n + (aim.n - player.n) / d * 8,
    w = player.w + (aim.w - player.w) / d * 8,
    r = 6, learned = true,
  }
  -- bumping into the same thing again: it is bigger than we thought
  for _, o in ipairs(Cfg().obstacles) do
    if o.c == spot.c and Dist(o, spot) < o.r + 4 then
      if o.r < 25 then
        o.r = o.r + 3
        o.n = o.n + (spot.n - o.n) * 0.3
        o.w = o.w + (spot.w - o.w) * 0.3
      end
      return true
    end
  end
  if getn(Cfg().obstacles) < 2000 then
    insert(Cfg().obstacles, spot)
  end
  return true
end

-- /smartarrow stuck: you say something is in the way, right where the
-- arrow points. Same circle the automatic detection would add.
function N:MarkBlocked(player, aim)
  if not player or not aim or aim.c ~= player.c then return false end
  local d = Dist(player, aim)
  if d < 0.1 then return false end
  local spot = {
    c = player.c,
    n = player.n + (aim.n - player.n) / d * 8,
    w = player.w + (aim.w - player.w) / d * 8,
    r = 7, learned = true,
  }
  for _, o in ipairs(Cfg().obstacles) do
    if o.c == spot.c and Dist(o, spot) < o.r + 4 then
      if o.r < 25 then o.r = o.r + 4 end
      return true
    end
  end
  insert(Cfg().obstacles, spot)
  return true
end

-- background work ---------------------------------------------------------------

-- Planning a path round obstacles can take a while on the 1.12 client. It
-- runs as a job, a little each frame: the planner calls Step() as it goes,
-- and when the frame's share is used up the job pauses until the next
-- frame. Outside a job (slash commands, tests) Step() does nothing and the
-- planner simply runs to the end.
local STEP_CHUNK = 25      -- units of work between clock checks
local STEP_MS = 2          -- milliseconds per frame, where there is a clock
local STEP_UNITS = 400     -- units per frame, where there is none

local function Step(units)
  local j = N.slice
  if not j then return end
  j.count = j.count + (units or 1)
  if j.count < j.check then return end
  j.check = j.count + STEP_CHUNK
  if j.clock then
    if j.clock() - j.start < STEP_MS then return end
  elseif j.count < STEP_UNITS then
    return
  end
  coroutine.yield()
end

N.Step = Step -- for graph.lua's search

-- start fn as a job (replacing any job still running)
function N:RunJob(fn)
  self.job = coroutine.create(fn)
end

-- one frame's share of the running job; true while it has more to do
function N:ResumeJob()
  local co = self.job
  if not co then return false end
  local alive = self:Resume(co)
  if not alive and self.job == co then self.job = nil end
  return alive
end

-- one frame's share of coroutine co; false once it is finished (or failed)
function N:Resume(co)
  local clock = debugprofilestop
  self.slice = { count = 0, check = STEP_CHUNK, clock = clock, start = clock and clock() or 0 }
  local ok, err = coroutine.resume(co)
  self.slice = nil
  if not ok then
    if not self.joberror and DEFAULT_CHAT_FRAME then
      self.joberror = true
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfQuest SmartArrow|r: path planning error: " .. tostring(err))
    end
    return false
  end
  return coroutine.status(co) ~= "dead"
end

-- the local planner -----------------------------------------------------------

local function EdgeCost(p, q, zone, dp, dq)
  local len = Dist(p, q)
  local d = (dp + dq) / 2
  if len > 60 then
    local mid = { n = (p.n + q.n) / 2, w = (p.w + q.w) / 2 }
    d = (dp + dq + 2 * N:DangerAt(zone, mid)) / 4
  end
  return len * DangerFactor(d)
end

local function PerpDist(p, a, b)
  local dn, dw = b.n - a.n, b.w - a.w
  local len2 = dn * dn + dw * dw
  if len2 == 0 then return Dist(p, a) end
  local t = ((p.n - a.n) * dn + (p.w - a.w) * dw) / len2
  if t < 0 then t = 0 elseif t > 1 then t = 1 end
  local cn, cw = a.n + dn * t - p.n, a.w + dw * t - p.w
  return sqrt(cn * cn + cw * cw)
end


local function BestDoor(o, a, b)
  local best, bestd
  for _, d in ipairs(o.doors) do
    local cost = Dist(a, d) + Dist(d, b)
    if not bestd or cost < bestd then best, bestd = d, cost end
  end
  return best
end

local function Join(first, rest)
  local out = {}
  for i = 1, getn(first) do insert(out, first[i]) end
  for i = 2, getn(rest) do insert(out, rest[i]) end
  return out
end

function N:Refine(a, b, zone)
  if a.c ~= b.c then return { a, b } end

  -- getting on or off a structure: through one of its doors. Standing at
  -- ground level in its area (beside it, or stuck inside the trunk) is not
  -- being *on* it: your height against the ground you last stood on outside
  -- tells the two apart. Unknown height counts as up, the safe guess.
  local sa, sb = StructureAt(a), StructureAt(b)
  if sa and a.z and self.groundz and a.z - self.groundz < 6 then
    sa = nil
  end
  if sa ~= sb then
    if sa then
      local door = BestDoor(sa, a, b)
      if door then
        door = { c = door.c, n = door.n, w = door.w }
        local down = self:RefineDirect(a, door, zone)
        if sb then
          local door2 = BestDoor(sb, door, b)
          if door2 then
            door2 = { c = door2.c, n = door2.n, w = door2.w }
            return Join(Join(down, self:RefineDirect(door, door2, zone)), { door2, b })
          end
        end
        return Join(down, self:RefineDirect(door, b, zone))
      end
    else
      local door = BestDoor(sb, a, b)
      if door then
        door = { c = door.c, n = door.n, w = door.w }
        return Join(self:RefineDirect(a, door, zone), { door, b })
      end
    end
  end
  return self:RefineDirect(a, b, zone)
end

-- the one note a structure needs: how to get on it, or off it
function N:StructureNote(target, player)
  if not target or not player or target.c ~= player.c then return nil end
  local st, sp = StructureAt(target), StructureAt(player)
  local ground = sp and player.z and self.groundz and player.z - self.groundz < 6
  if ground then
    -- beside it, or inside the trunk at ground level
    if st == sp then return nil end
    if Dist(sp, player) < sp.r then
      return "Inside " .. (sp.name or "it") .. ": leave the way you came in"
    end
    sp = nil
  end
  if st and st ~= sp then return st.up end
  if sp and sp ~= st then return sp.down end
  return nil
end

function N:RefineDirect(a, b, zone)
  if a.c ~= b.c then return { a, b } end
  local len = Dist(a, b)
  if len < 12 then return { a, b } end

  local margin = len * 0.35
  if margin < 60 then margin = 60 end
  if margin > 400 then margin = 400 end
  local minN, maxN = math.min(a.n, b.n) - margin, math.max(a.n, b.n) + margin
  local minW, maxW = math.min(a.w, b.w) - margin, math.max(a.w, b.w) + margin

  -- obstacles in the corridor. One that holds b is a building you are
  -- going into, so it does not count. One that holds a is one you are stuck
  -- inside: leaving it straight through the wall is allowed but expensive,
  -- so the way you came in (your recorded trail) wins whenever there is one.
  local obs, escape = {}, {}
  EachObstacle(function(o)
    if o.c == a.c and o.n + o.r >= minN and o.n - o.r <= maxN
      and o.w + o.r >= minW and o.w - o.r <= maxW and not Within(o, b) then
      if Within(o, a) then
        insert(escape, o)
      else
        insert(obs, o)
      end
    end
  end)

  -- trail points in the corridor: your own walked trails (store 1) and the
  -- built-in roads from NPC patrols (store 2)
  local trailpts = {}
  local stores = {
    { t = Cfg().trails[a.c], h = self.hash[a.c] },
    { t = self.roads[a.c], h = self.roadhash[a.c] },
  }
  for st = 1, 2 do
    local t, h = stores[st].t, stores[st].h
    if t and h then
      for cn = floor(minN / HASH), floor(maxN / HASH) do
        for cw = floor(minW / HASH), floor(maxW / HASH) do
          local list = h[cn .. ":" .. cw]
          Step()
          if list then
            for _, i in ipairs(list) do
              Step()
              local p = { n = t.n[i], w = t.w[i], c = a.c, tid = i, st = st }
              local pd = PerpDist(p, a, b)
              if pd <= margin then
                p.pd = pd
                insert(trailpts, p)
              end
            end
          end
        end
      end
    end
  end
  if getn(trailpts) > MAX_TRAIL_NODES then
    table.sort(trailpts, function(x, y) return x.pd < y.pd end)
    for i = getn(trailpts), MAX_TRAIL_NODES + 1, -1 do table.remove(trailpts, i) end
  end

  -- straight line already fine?
  local hasdanger = self.grid and self.grid[zone]
  if getn(obs) == 0 and getn(escape) == 0 and getn(trailpts) == 0 then
    if not hasdanger then return { a, b } end
    local worst, steps = 0, floor(len / 25) + 1
    for i = 0, steps do
      local f = i / steps
      local d = self:DangerAt(zone, { n = a.n + (b.n - a.n) * f, w = a.w + (b.w - a.w) * f })
      if d > worst then worst = d end
    end
    if worst < 0.5 then return { a, b } end
  end

  -- local graph
  local nodes = { a, b }
  local rings = {}
  for _, o in ipairs(obs) do insert(rings, o) end
  for _, o in ipairs(escape) do insert(rings, o) end
  for _, o in ipairs(rings) do
    for k = 0, RING - 1 do
      local ang = k * 2 * pi / RING
      local p = { c = a.c, n = o.n + cos(ang) * (o.r + RING_PAD), w = o.w + sin(ang) * (o.r + RING_PAD), ring = true }
      if not InsideAny(p, obs) then insert(nodes, p) end
    end
  end
  for _, p in ipairs(trailpts) do
    Step()
    if not InsideAny(p, obs) then insert(nodes, p) end
  end
  local spacing = len / 8
  if spacing < 35 then spacing = 35 end
  if spacing > 250 then spacing = 250 end
  if hasdanger then
    local added = 0
    local n = minN
    while n <= maxN and added < MAX_LATTICE do
      local w = minW
      while w <= maxW and added < MAX_LATTICE do
        local p = { c = a.c, n = n, w = w }
        if PerpDist(p, a, b) <= margin and not InsideAny(p, obs) then
          insert(nodes, p)
          added = added + 1
        end
        Step()
        w = w + spacing
      end
      n = n + spacing
    end
  end

  local count = getn(nodes)
  local danger = {}
  local tindex = { {}, {} }
  for i = 1, count do
    Step()
    danger[i] = hasdanger and self:DangerAt(zone, nodes[i]) or 0
    if nodes[i].tid then tindex[nodes[i].st][nodes[i].tid] = i end
  end

  -- edges: the start, the end and the points around obstacles see each
  -- other at any range (a visibility graph: the shortest way round a circle
  -- runs along such lines); trail and lattice points only link to neighbours
  -- within reach. No edge may cross an obstacle. Recorded trail links are
  -- added as well: walked, so passable by definition.
  local reach = spacing * 1.6
  if reach < 80 then reach = 80 end
  local adj = {}
  for i = 1, count do adj[i] = {} end
  for i = 1, count do
    local p = nodes[i]
    for j = i + 1, count do
      Step()
      local q = nodes[j]
      local d = Dist(p, q)
      local far = (i <= 2 or p.ring) and (j <= 2 or q.ring)
      if (d <= reach or far) and SegmentClear(p, q, obs) then
        local cost = EdgeCost(p, q, zone, danger[i], danger[j])
        if getn(escape) > 0 and not SegmentClear(p, q, escape) then
          cost = cost * 6 -- through the wall of what you are stuck in
        end
        insert(adj[i], j) insert(adj[i], cost)
        insert(adj[j], i) insert(adj[j], cost)
      end
    end
    local store = p.tid and stores[p.st].t
    if store then
      for _, other in ipairs(store.l[p.tid] or {}) do
        local j = tindex[p.st][other]
        if j and j > i then
          local cost = EdgeCost(p, nodes[j], zone, danger[i], danger[j]) * TRAIL_FACTOR
          insert(adj[i], j) insert(adj[i], cost)
          insert(adj[j], i) insert(adj[j], cost)
        end
      end
    end
  end

  -- Dijkstra from a (1) to b (2)
  local dist, prev, done = {}, {}, {}
  for i = 1, count do dist[i] = 1e30 end
  dist[1] = 0
  for _ = 1, count do
    local u, best = nil, 1e30
    for i = 1, count do
      if not done[i] and dist[i] < best then u, best = i, dist[i] end
    end
    if not u or u == 2 then break end
    Step(floor(count / 20) + 1)
    done[u] = true
    local list = adj[u]
    for k = 1, getn(list), 2 do
      local v, cost = list[k], list[k + 1]
      if not done[v] and best + cost < dist[v] then
        dist[v] = best + cost
        prev[v] = u
      end
    end
  end
  if dist[2] >= 1e30 then
    return { a, b }
  end

  local path = {}
  local i = 2
  while i do
    insert(path, 1, nodes[i])
    i = prev[i]
  end

  -- pull the string: drop corners the path does not need
  local out = { path[1] }
  local k = 1
  local total = getn(path)
  while k < total do
    local jump = k + 1
    for j = total, k + 2, -1 do
      Step(j - k)
      local direct = EdgeCost(path[k], path[j], zone, self:DangerAt(zone, path[k]), self:DangerAt(zone, path[j]))
      if getn(escape) > 0 and not SegmentClear(path[k], path[j], escape) then
        direct = direct * 6
      end
      local along = 0
      for s = k, j - 1 do
        local f = EdgeCost(path[s], path[s + 1], zone, self:DangerAt(zone, path[s]), self:DangerAt(zone, path[s + 1]))
        if path[s].tid and path[s + 1].tid then
          f = f * TRAIL_FACTOR
        elseif getn(escape) > 0 and not SegmentClear(path[s], path[s + 1], escape) then
          f = f * 6
        end
        along = along + f
      end
      if direct <= along * 1.03 and SegmentClear(path[k], path[j], obs) then
        jump = j
        break
      end
    end
    insert(out, path[jump])
    k = jump
  end
  return out
end

-- following a polyline --------------------------------------------------------

-- where along the polyline the player is, and the point `ahead` yards on
-- from there: aiming at it makes the arrow lead around corners
function N:Carrot(poly, player, ahead)
  local count = getn(poly)
  if count < 2 then return poly[1], 0, 1 end
  local bestd, bestseg, bestt
  for i = 1, count - 1 do
    local a, b = poly[i], poly[i + 1]
    local dn, dw = b.n - a.n, b.w - a.w
    local len2 = dn * dn + dw * dw
    local t = 0
    if len2 > 0 then
      t = ((player.n - a.n) * dn + (player.w - a.w) * dw) / len2
      if t < 0 then t = 0 elseif t > 1 then t = 1 end
    end
    local cn, cw = a.n + dn * t - player.n, a.w + dw * t - player.w
    local d = cn * cn + cw * cw
    if not bestd or d < bestd then bestd, bestseg, bestt = d, i, t end
  end

  -- remaining length from the projection to the end
  local a, b = poly[bestseg], poly[bestseg + 1]
  local seglen = Dist(a, b)
  local remaining = seglen * (1 - bestt)
  for i = bestseg + 1, count - 1 do
    remaining = remaining + Dist(poly[i], poly[i + 1])
  end

  -- walk `ahead` yards along the line
  local left = ahead
  local i, t = bestseg, bestt
  while i < count do
    local p, q = poly[i], poly[i + 1]
    local l = Dist(p, q)
    local avail = l * (1 - t)
    if avail >= left and l > 0 then
      local f = t + left / l
      return { c = p.c, n = p.n + (q.n - p.n) * f, w = p.w + (q.w - p.w) * f }, remaining + sqrt(bestd), bestseg
    end
    left = left - avail
    i, t = i + 1, 0
  end
  return poly[count], remaining + sqrt(bestd), bestseg
end

-- how far the player is from the polyline
function N:OffPath(poly, player)
  local best = 1e30
  for i = 1, getn(poly) - 1 do
    local d = PerpDist(player, poly[i], poly[i + 1])
    if d < best then best = d end
  end
  return best
end

-- remembered routes -------------------------------------------------------------

-- Every walking stretch you finish is remembered as the way you actually
-- walked it, simplified to a few corners. The next time you walk between
-- the same two places, in either direction (there and back for a quest),
-- that route is used as it is: no planning, and the dotted line does not
-- change under you. A remembered route that gets you stuck is forgotten.
local MEM_MAX = 400        -- routes kept (least recently used go first)
local MEM_BUCKET = 60      -- yards: index cell size for route ends
local MEM_END = 15         -- yards: how close a route's end must be to the goal
local MEM_JOIN = 30        -- yards: how far off the route you may start
local MEM_MIN = 40         -- yards: shorter stretches are not worth keeping
local MEM_SIMPLIFY = 3     -- yards: how far the kept corners may stray from your walk

local function Routes()
  local cfg = Cfg()
  cfg.routes = cfg.routes or {}
  return cfg.routes
end

local function MemKey(c, n, w)
  return c .. ":" .. floor(n / MEM_BUCKET) .. ":" .. floor(w / MEM_BUCKET)
end

function N:MemoryIndex()
  if self.memindex then return self.memindex end
  local index = {}
  for _, r in ipairs(Routes()) do
    local p, last = r.p, getn(r.p) - 1
    for _, k in ipairs({ MemKey(r.c, p[1], p[2]), MemKey(r.c, p[last], p[last + 1]) }) do
      index[k] = index[k] or {}
      insert(index[k], r)
    end
  end
  self.memindex = index
  return index
end

function N:RouteCount()
  return getn(Routes())
end

function N:ForgetRoutes()
  Cfg().routes = {}
  self.memindex = nil
end

function N:ForgetRoute(r)
  local routes = Routes()
  for i = getn(routes), 1, -1 do
    if routes[i] == r then table.remove(routes, i) end
  end
  self.memindex = nil
end

-- the routes with an end near point p
local function NearEnds(index, p)
  local found, seen = {}, {}
  local cn, cw = floor(p.n / MEM_BUCKET), floor(p.w / MEM_BUCKET)
  for dn = -1, 1 do
    for dw = -1, 1 do
      for _, r in ipairs(index[p.c .. ":" .. (cn + dn) .. ":" .. (cw + dw)] or {}) do
        if not seen[r] then seen[r] = true insert(found, r) end
      end
    end
  end
  return found
end

-- the corners of route r as points, ordered so the route ends nearest b
local function Oriented(r, b)
  local p, count = r.p, getn(r.p) / 2
  local pts = {}
  for i = 1, count do pts[i] = { c = r.c, n = p[i * 2 - 1], w = p[i * 2] } end
  if Dist(pts[1], b) < Dist(pts[count], b) then
    local rev = {}
    for i = count, 1, -1 do insert(rev, pts[i]) end
    pts = rev
  end
  return pts
end

-- A remembered way from a to b: the rest of a remembered route, from the
-- spot on it nearest to a, when that is close and nothing is in the way.
function N:Recall(a, b)
  if not a or not b or a.c ~= b.c then return nil end
  local best, bestpoly, bestcost
  for _, r in ipairs(NearEnds(self:MemoryIndex(), b)) do
    if r.c == b.c then
      local pts = Oriented(r, b)
      local count = getn(pts)
      if Dist(pts[count], b) <= MEM_END then
        -- the nearest spot on the route to a
        local bd, bs, bt
        for i = 1, count - 1 do
          local p, q = pts[i], pts[i + 1]
          local dn, dw = q.n - p.n, q.w - p.w
          local len2 = dn * dn + dw * dw
          local t = len2 > 0 and ((a.n - p.n) * dn + (a.w - p.w) * dw) / len2 or 0
          if t < 0 then t = 0 elseif t > 1 then t = 1 end
          local x = { n = p.n + dn * t, w = p.w + dw * t }
          local d = Dist(a, x)
          if not bd or d < bd then bd, bs, bt = d, i, t end
        end
        if bd and bd <= MEM_JOIN then
          local p, q = pts[bs], pts[bs + 1]
          local join = { c = a.c, n = p.n + (q.n - p.n) * bt, w = p.w + (q.w - p.w) * bt }
          local poly = { a }
          if bd > 2 then insert(poly, join) end
          for i = bs + 1, count - 1 do insert(poly, pts[i]) end
          insert(poly, b)
          -- the way onto the route, and the last bit to the goal, must be clear
          local obs = {}
          EachObstacle(function(o)
            if o.c == a.c and (Dist(o, a) < o.r + MEM_JOIN + 5 or Dist(o, b) < o.r + MEM_END + 5)
              and not Within(o, b) and not Within(o, a) then insert(obs, o) end
          end)
          local n = getn(poly)
          if SegmentClear(poly[1], poly[2], obs) and SegmentClear(poly[n - 1], poly[n], obs) then
            local cost = bd
            for i = 1, n - 1 do cost = cost + Dist(poly[i], poly[i + 1]) end
            if not bestcost or cost < bestcost then best, bestpoly, bestcost = r, poly, cost end
          end
        end
      end
    end
  end
  if best then best.t = time and time() or 0 end
  return bestpoly, best
end

-- Douglas-Peucker: keep the corners that matter
local function Simplify(pts, first, last, out)
  local p, q = pts[first], pts[last]
  local worst, at = 0, nil
  for i = first + 1, last - 1 do
    local d = PerpDist(pts[i], p, q)
    if d > worst then worst, at = d, i end
  end
  if at and worst > MEM_SIMPLIFY then
    Simplify(pts, first, at, out)
    Simplify(pts, at, last, out)
  else
    insert(out, q)
  end
end

-- remember the walk `trace` (points from start to goal) as the way to goal
function N:Remember(trace, goal)
  local count = getn(trace)
  if count < 2 or not goal or trace[1].c ~= goal.c then return false end
  local start = trace[1]
  local straight = Dist(start, goal)
  if straight < MEM_MIN then return false end
  local walked = 0
  for i = 1, count - 1 do walked = walked + Dist(trace[i], trace[i + 1]) end
  walked = walked + Dist(trace[count], goal)
  -- a long detour (a fight, a chase, a wrong turn) is not a route
  if walked > straight * 2.2 and walked > straight + 150 then return false end

  local pts = {}
  for i = 1, count do pts[i] = trace[i] end
  insert(pts, { c = goal.c, n = goal.n, w = goal.w })
  local kept = { pts[1] }
  Simplify(pts, 1, getn(pts), kept)
  local flat = {}
  for _, p in ipairs(kept) do
    insert(flat, floor(p.n * 10 + 0.5) / 10)
    insert(flat, floor(p.w * 10 + 0.5) / 10)
  end

  -- replaces a route between the same two places
  local routes = Routes()
  for i = getn(routes), 1, -1 do
    local r = routes[i]
    local last = getn(r.p) - 1
    if r.c == goal.c then
      local s = { n = r.p[1], w = r.p[2] }
      local e = { n = r.p[last], w = r.p[last + 1] }
      if (Dist(s, start) < MEM_JOIN and Dist(e, goal) < MEM_END) or (Dist(e, start) < MEM_JOIN and Dist(s, goal) < MEM_END) then
        table.remove(routes, i)
      end
    end
  end
  insert(routes, { c = goal.c, p = flat, t = time and time() or 0 })
  if getn(routes) > MEM_MAX then
    table.sort(routes, function(x, y) return (x.t or 0) > (y.t or 0) end)
    for i = getn(routes), MEM_MAX + 1, -1 do table.remove(routes, i) end
  end
  self.memindex = nil
  return true
end

-- The aim point for the arrow: as far ahead as possible (up to 12 yards)
-- without the straight line to it clipping an obstacle, so cutting a corner
-- never takes you into the tree you are walking round.
function N:Aim(poly, player)
  local near = {}
  EachObstacle(function(o)
    if o.c == player.c and Dist(o, player) < o.r + 60 and not Within(o, player) then
      insert(near, o)
    end
  end)
  if getn(near) == 0 then
    return self:Carrot(poly, player, 12)
  end

  local padded = {}
  for i = 1, getn(near) do
    local o = near[i]
    padded[i] = { c = o.c, n = o.n, w = o.w, r = o.r + 2 }
  end
  local ahead = { 12, 7, 3 }
  local carrot, remaining
  for i = 1, 3 do
    carrot, remaining = self:Carrot(poly, player, ahead[i])
    if SegmentClear(player, carrot, padded) then
      return carrot, remaining
    end
  end

  -- every short aim clips something: take the usual aim point and push it out
  -- of each obstacle to a safe distance, so the arrow curves round the edge
  carrot, remaining = self:Carrot(poly, player, 12)
  local p = { c = carrot.c, n = carrot.n, w = carrot.w }
  for i = 1, getn(near) do
    local o = near[i]
    local d = Dist(p, o)
    local safe = o.r + 6
    if d < safe then
      if d < 0.01 then
        p.n, p.w = o.n + (player.n - o.n), o.w + (player.w - o.w)
        d = Dist(p, o)
      end
      p.n = o.n + (p.n - o.n) / d * safe
      p.w = o.w + (p.w - o.w) / d * safe
    end
  end
  return p, remaining
end

-- driver for the danger build -------------------------------------------------

N:SetScript("OnUpdate", function()
  if this.builder then
    local ok = coroutine.resume(this.builder)
    if not ok or coroutine.status(this.builder) == "dead" then
      this.builder = nil
      N.dangercache = {}
    end
  elseif this.roadbuilder then
    local ok = coroutine.resume(this.roadbuilder)
    if not ok or coroutine.status(this.roadbuilder) == "dead" then
      this.roadbuilder = nil
    end
  end
end)

-- the built-in roads (data/roads.lua), turned into world-space trail points
-- once per login, a few stretches per frame
function N:StartRoadBuild()
  if not (pfQuestSmartArrowData and pfQuestSmartArrowData.roads) then return end
  self.roads, self.roadhash = {}, {}
  self.roadbuilder = coroutine.create(function()
    local work = 0
    for zone, list in pairs(pfQuestSmartArrowData.roads) do
      local tr = N:Transform(zone)
      if tr then
        local store = N.roads[tr.c]
        if not store then store = { n = {}, w = {}, l = {} } N.roads[tr.c] = store end
        local hash = N.roadhash[tr.c]
        if not hash then hash = {} N.roadhash[tr.c] = hash end
        for _, line in ipairs(list) do
          local prev
          for x, y in string.gfind(line, "([%d%.]+),([%d%.]+)") do
            local n = tr.n0 + tonumber(y) / 100 * tr.dn
            local w = tr.w0 + tonumber(x) / 100 * tr.dw
            -- reuse a road point within 4 yards, so crossing patrols join up
            local index
            local key = HashKey(n, w)
            for _, i in ipairs(hash[key] or {}) do
              local dn, dw = store.n[i] - n, store.w[i] - w
              if dn * dn + dw * dw < 16 then index = i break end
            end
            if not index then
              insert(store.n, n) insert(store.w, w) insert(store.l, {})
              index = getn(store.n)
              if not hash[key] then hash[key] = {} end
              insert(hash[key], index)
            end
            if prev then Link(store, prev, index) end
            prev = index
          end
          work = work + 1
          if work >= 20 then work = 0 coroutine.yield() end
        end
      end
    end
  end)
end

function N:RoadCount()
  local total = 0
  for _, t in pairs(self.roads) do total = total + getn(t.n) end
  return total
end

function N:Init()
  local cfg = Cfg()
  cfg.obstacles = cfg.obstacles or {}
  cfg.trails = cfg.trails or {}
  if cfg.safety == nil then cfg.safety = 1 end
  if cfg.trails_on == nil then cfg.trails_on = "1" end
  self:ResolveObstacles()
  self:RebuildHash()
  self:StartDangerBuild()
  self:StartRoadBuild()
end
