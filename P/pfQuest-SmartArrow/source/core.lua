-- pfQuest SmartArrow
-- Copyright (C) 2026 pfQuest SmartArrow contributors
--
-- This program is free software: you can redistribute it and/or modify it
-- under the terms of the GNU General Public License as published by the Free
-- Software Foundation, either version 3 of the License, or (at your option)
-- any later version. It is distributed WITHOUT ANY WARRANTY; see LICENSE.md.

-- pfQuest SmartArrow core
--
-- An extension of pfQuest's arrow, and nothing without it: it reads pfQuest's
-- world-space arrow candidates (pfQuest.route.worldcoords), plans a multi-leg
-- route with pfQuestSmartArrowGraph and publishes it as pfQuestSmartArrow.view, which
-- arrow.lua renders into pfQuest's own arrow frame. pfQuest's arrow toggle
-- (/db arrow, or the config window) switches this off with it. It also learns
-- flight paths and zone borders and offers manual waypoints (/smartarrow way).
-- It needs no other addon besides pfQuest.

local floor, sqrt = math.floor, math.sqrt
local getn, insert = table.getn, table.insert

local G = pfQuestSmartArrowGraph
local UI = pfQuestSmartArrowUI
local PL = pfQuestSmartArrowPlaces
local NAV = pfQuestSmartArrowNav
local COMPAT = pfQuestSmartArrowCompat
local DRAW = pfQuestSmartArrowDraw

local SOLVE_EVERY = 1.5   -- seconds between checks whether to replan
local REPLAN_MOVED = 12   -- yards walked since the last plan that call for a new one
local REPLAN_AGE = 6      -- seconds after which the plan is redone anyway
local REDRAW_YARDS = 30   -- yards to walk before the dotted line may change
local SAMPLE_EVERY = 0.25 -- seconds between player position samples
local SWITCH_RATIO = 0.85 -- a new target must be this much faster to win
local SWITCH_SLACK = 8    -- ...and at least this many seconds faster

local defaults = {
  enabled = "1",   -- route pfQuest's arrow (off: pfQuest's straight arrow)
  notes = "1",     -- show special notes (caves, towers, your own notes)
  drawpath = "1",  -- draw the planned path on the world map and minimap
  safety = 1,      -- 0 ignores hostile mobs, 1 avoids camps, 2-3 avoids harder
  smart = "1",     -- pick the objective with the shortest travel time
  taxi = "known",  -- known | all | none
  learn = "1",     -- learn zone borders you walk through
  mountlevel = 40,
}

pfQuestSmartArrow = CreateFrame("Frame", "pfQuestSmartArrowCore", UIParent)
local core = pfQuestSmartArrow

local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest SmartArrow|r: " .. msg)
end
core.Print = Print

local function PlayerZone()
  local name = GetRealZoneText()
  if name and pfMap and pfMap.GetMapIDByName then
    return pfMap:GetMapIDByName(name)
  end
  return nil
end

local function PlayerPoint()
  local w, n, z, c = COMPAT.PlayerPosition()
  if not n then
    return nil
  end
  local zone = PlayerZone()
  return {
    c = c, n = n, w = w, z = z, zone = zone, zones = zone and G:PointZones(zone, n, w) or nil,
    indoors = IsIndoors and IsIndoors() and true or false,
    sub = GetSubZoneText and GetSubZoneText() or nil,
  }
end

local function Key(p)
  return floor(p.n) .. ":" .. floor(p.w)
end

-- pfQuest arrow ---------------------------------------------------------------

-- pfQuest's own arrow switch. Off there means off here too.
local function PfQuestArrowOn()
  return pfQuest_config and pfQuest_config["arrow"] ~= "0"
end

local function SetRouting(on)
  if on then
    UI:Attach()
  else
    UI:Detach()
    DRAW:SetPaths(nil)
    -- fresh candidate tables make pfQuest's handler repaint its own texts
    if pfMap and pfMap.UpdateNodes then
      pfMap:UpdateNodes()
    end
  end
end

-- targets ---------------------------------------------------------------------

local function CandidateToTarget(cand)
  local node = cand[3] or {}
  local zone = node.zone
  local title = node.title or "?"
  if node.qlvl then
    title = "[" .. node.qlvl .. "] " .. title
  end
  if tonumber(node.qlvl) and pfMap and pfMap.HexDifficultyColor then
    title = pfMap:HexDifficultyColor(tonumber(node.qlvl)) .. title .. "|r"
  end

  local icon, iconcolor
  if node.texture then
    icon = node.texture
    if node.vertex and (node.vertex[1] > 0 or node.vertex[2] > 0 or node.vertex[3] > 0) then
      iconcolor = node.vertex
    end
  elseif pfQuestConfig then
    icon = pfQuestConfig.path .. "\\img\\node"
    if pfMap and pfMap.str2rgb then
      local r, g, b = pfMap.str2rgb(node.title)
      iconcolor = { r, g, b }
    end
  end

  local area = node.priority or 1
  if area < 1 then area = 1 end
  if area > 20 then area = 20 end

  return {
    c = cand[7], n = cand[1], w = cand[2],
    zone = zone, zones = zone and G:PointZones(zone, cand[1], cand[2]) or nil,
    title = title, node = node, watched = cand[5],
    icon = icon, iconcolor = iconcolor, area = (area / 10 + 1) * 50,
  }
end

-- the waypoint addons and /smartarrow way set: beats pfQuest's objectives
function core:SetWaypoint(zone, x, y, title)
  if not zone then
    self.waypoint = nil
    self.target = nil
    self.nextsolve = 0
    return true
  end
  local c, n, w = G.Resolve(zone, x, y)
  if not c then
    return nil
  end
  self.waypoint = {
    c = c, n = n, w = w, zone = zone, zones = G:PointZones(zone, n, w),
    title = title or ((G.ZoneName(zone) or "?") .. string.format(" %.1f, %.1f", x, y)),
    area = 15, manual = true,
  }
  self.target = nil
  self.nextsolve = 0
  return true
end

-- Which objective to go to. pfQuest's ordering wins when the user asked for
-- it (a clicked node, or level sort); otherwise the objective with the
-- shortest *travel time* wins, among the same watched/unwatched tier as
-- pfQuest's first choice. Must run right after G:Solve.
function core:ChooseTarget()
  if self.waypoint then
    return self.waypoint
  end

  local list = COMPAT.Candidates()
  if not list or not list[1] then
    return nil
  end

  local first = list[1]
  local explicit = pfQuest.route.IsTarget and pfQuest.route.IsTarget(first[3])
  local levelsort = pfQuest_config
    and pfQuest_config["trackingmethod"] == 5
    and pfQuest_config["trackerquestsort"] ~= "distance"

  if explicit or levelsort or pfQuestSmartArrow_config.smart ~= "1" then
    return CandidateToTarget(first)
  end

  local bestcand, bestcost
  local curcand, curcost
  local curkey = self.target and not self.target.manual and Key(self.target)
  local limit = getn(list)
  if limit > 250 then limit = 250 end

  for i = 1, limit do
    NAV.Step(3)
    local cand = list[i]
    if (cand[5] and true or false) == (first[5] and true or false) and cand[7] then
      local cz = cand[3] and cand[3].zone
      local p = { c = cand[7], n = cand[1], w = cand[2], zones = cz and G:PointZones(cz, cand[1], cand[2]) or nil }
      local cost = G:CostTo(p)
      if not bestcost or cost < bestcost then
        bestcand, bestcost = cand, cost
      end
      if curkey and Key(p) == curkey then
        curcand, curcost = cand, cost
      end
    end
  end

  -- stick with the current objective unless the new one is clearly faster
  if curcand and bestcost and curcost < G.INF
    and bestcost > curcost * SWITCH_RATIO and bestcost > curcost - SWITCH_SLACK then
    bestcand = curcand
  end

  return bestcand and CandidateToTarget(bestcand) or CandidateToTarget(first)
end

-- directions ------------------------------------------------------------------

local TRAVEL_VERB = {
  boat = "Take the boat to ",
  zeppelin = "Take the zeppelin to ",
  tram = "Ride the Deeprun Tram to ",
  portal = "Take the portal to ",
  taxi = "Fly to ",
  lift = "Take the lift ",
}

local function OtherZone(links, here)
  if not links then return nil end
  if here and here[links[1]] and not here[links[2]] then
    return links[2]
  elseif here and here[links[2]] and not here[links[1]] then
    return links[1]
  end
  return links[2]
end

local function ShortName(name)
  -- "Menethil Harbor, Wetlands" -> "Menethil Harbor"
  if not name then return "?" end
  local _, _, town = string.find(name, "^([^,]+),")
  return town or name
end

-- the zone a walk between two points happens in, for the danger map
local function LegZone(from, to, target)
  if from.zones and to.zones then
    for z in pairs(from.zones) do
      if type(z) == "number" and to.zones[z] then return z end
    end
  end
  if to.zones then
    for z in pairs(to.zones) do if type(z) == "number" then return z end end
  end
  if from.zones then
    for z in pairs(from.zones) do if type(z) == "number" then return z end end
  end
  return target and target.zone
end

-- Turn graph legs into human steps. A step's `point` is where the arrow aims
-- while that step is active; travel steps aim at their departure point.
local function BuildSteps(route, target)
  local steps = {}
  local shown = 0
  local legs = route.legs
  local zonehere = route.legs[1] and route.legs[1].from.zones

  local function TimeAt(p)
    if p == G.start or not p.id then return 0 end
    return G.dist[p.id] or 0
  end

  for i = 1, getn(legs) do
    local leg = legs[i]
    local nextleg = legs[i + 1]
    -- shown times use the real distance; the planner's detour penalties are
    -- for choosing a route, not for the clock
    local secs
    if leg.kind == "walk" then
      secs = (leg.from.c == leg.to.c) and G.Dist(leg.from, leg.to) * 1.1 / G.speed or 0
    elseif leg.final then
      secs = route.total - TimeAt(leg.from)
    else
      secs = TimeAt(leg.to) - TimeAt(leg.from)
    end
    shown = shown + secs

    if leg.kind == "walk" then
      local to = leg.to
      local text
      if leg.final and target.node and target.node.arrow == true then
        -- another addon's waypoint, pushed through pfMap:AddNode with
        -- arrow = true: guide addons put the instruction itself in the title
        text = target.title or "Next step"
      elseif leg.final then
        text = "Go to " .. (target.title or "objective")
        if target.zone and zonehere and not zonehere[target.zone] then
          text = text .. " |cff888888(" .. (G.ZoneName(target.zone) or "?") .. ")|r"
        end
      elseif to.kind == "connector" then
        local other = OtherZone(to.links, zonehere)
        text = "Go to " .. (G.ZoneName(other) or "the next zone") .. " |cff888888via " .. (to.name or "the road") .. "|r"
        if other then zonehere = G.ZoneSet(other) end
      elseif to.kind == "entrance" then
        text = "Enter " .. (to.name ~= "" and to.name or "here")
      elseif to.kind == "border" then
        -- a border in the area you are in is the exit: "Go to <next zone>";
        -- its partner just across is where you arrive, so it says nothing
        local inside = false
        if zonehere then
          for z in pairs(to.zones) do if zonehere[z] then inside = true end end
        end
        if inside and to.dest then
          text = "Go to " .. (G.ZoneName(to.dest) or "the next zone")
        else
          text = nil
          zonehere = to.zones
        end
      elseif to.kind == "gate" then
        text = to.dest and ("Go through the gate to " .. (G.ZoneName(to.dest) or "the city")) or "Go through the gate"
      elseif to.kind == "pass" then
        text = nil -- a waypoint on the way: shows the next real instruction
        zonehere = to.zones
      elseif to.kind == "taxi" then
        text = "Go to the flight master at " .. ShortName(to.name)
        zonehere = to.zones
      elseif to.kind == "dock" then
        local verb = nextleg and nextleg.kind or "boat"
        if verb == "tram" or verb == "portal" then
          text = "Go to the " .. to.name
        else
          text = "Go to the " .. verb .. " at " .. to.name
        end
        zonehere = to.zones
      else
        text = "Go to " .. (to.name or "?")
      end

      -- a hop you are already standing on is skipped by CurrentStep
      insert(steps, {
        kind = "walk", final = leg.final, point = to, from = leg.from, text = text, secs = secs,
        radius = to.radius or 10, zone = LegZone(leg.from, to, target),
      })
    else
      local verb = TRAVEL_VERB[leg.kind] or "Travel to "
      local name = leg.kind == "taxi" and ShortName(leg.to.name) or leg.to.town or leg.to.name
      if leg.kind == "lift" then
        verb, name = "Take the lift", ""
      end
      insert(steps, { kind = leg.kind, point = leg.from, dest = leg.to, text = verb .. (name or ""), secs = secs })
      zonehere = leg.to.zones
    end
  end

  -- passes (and borders into the zone you are in) carry the next real
  -- instruction, so the arrow line reads "Go to Wetlands" all the way there
  local nexttext = steps[getn(steps)] and steps[getn(steps)].text or "Go on"
  for i = getn(steps), 1, -1 do
    if steps[i].text then
      nexttext = steps[i].text
    else
      steps[i].text = nexttext
      steps[i].waypoint = true
    end
  end

  route.shown = shown
  return steps
end

local function StepSignature(steps)
  local sig = ""
  for i = 1, getn(steps) do
    local p = steps[i].point
    sig = sig .. steps[i].kind .. floor(p.n / 10) .. floor(p.w / 10) .. ";"
  end
  return sig
end

-- the first step not yet done: walk steps finish when you reach their point
local function CurrentStep(steps, player)
  for i = 1, getn(steps) do
    local s = steps[i]
    if not (s.kind == "walk" and not s.final and steps[i + 1]
      and s.point.c == player.c and G.Dist(s.point, player) < (s.radius or 30)) then
      return i
    end
  end
  return getn(steps)
end

-- main loop -------------------------------------------------------------------

-- Route to the objective. When it lies inside a place whose entrance has been
-- learned and you are still outside, the route goes to the doorway first and
-- the last leg walks in from there.
function core:PlanTo(target, player)
  local learned, shipped = PL:Find(target)
  local door = learned and not PL:Inside(learned, shipped, player) and PL:Entrance(learned, player)
  if not door then
    return G:PathTo(target)
  end

  local doorpoint = {
    kind = "entrance", c = door.c, n = door.n, w = door.w, zones = target.zones,
    name = learned.name or "", radius = 6,
  }
  local route = G:PathTo(doorpoint)
  if not route then
    return G:PathTo(target)
  end
  local last = route.legs[getn(route.legs)]
  last.final = nil
  insert(route.legs, { kind = "walk", from = doorpoint, to = target, final = true })
  route.total = route.total + G.Dist(doorpoint, target) * 1.1 / G.speed
  return route
end

function core:Solve(player, jumped)
  -- the graph changed (learned something) or you jumped far (landed,
  -- hearthed): a new situation, not two near-equal plans, so no debounce
  local rebuilt = G.dirty or jumped
  G:Solve(player)

  local target = self:ChooseTarget()
  if not target then
    self.target, self.route, self.steps = nil, nil, nil
    self.refinepending = true
    return
  end

  local route = target.c and self:PlanTo(target, player)
  if not route then
    self.target, self.route = target, nil
    self.steps = nil
    self.refinepending = true
    return
  end

  local steps = BuildSteps(route, target)
  local sig = StepSignature(steps)

  -- debounce route changes: a different plan for the same target must show
  -- up twice in a row before it replaces the current one, so two near-equal
  -- routes cannot make the arrow flip back and forth
  local sametarget = self.target and Key(self.target) == Key(target)
  if sametarget and self.steps and sig ~= self.stepsig and not rebuilt then
    if self.pendingsig == sig then
      self.pendingsig = nil
    else
      self.pendingsig = sig
      self.refinepending = true
      return
    end
  end

  if sig ~= self.stepsig then
    -- the old stretch's path no longer applies (unless it leads to the same
    -- waypoint); aim straight at the next waypoint until the new one is ready
    local first = steps[CurrentStep(steps, player)]
    local last = self.lastactive
    if not (first and first.point and last and last.key == Key(first.point)) then
      self.activepath, self.activestep = nil, nil
    end
  end
  if sig == self.stepsig and self.steps and sametarget then
    steps = self.steps -- the same plan again: keep it (and its refined paths)
  end
  self.target, self.route, self.steps, self.stepsig = target, route, steps, sig
  self.refinepending = true
end

-- Bend each walking stretch around obstacles, onto known trails and away
-- from hostile camps. A remembered route is used where there is one. The
-- stretch you are on is kept while you stay on it; the ones after it are
-- cached. The planning runs as a background job, a little each frame, so a
-- hard stretch (round a tree you just bumped into) never stalls a frame.
function core:RefinePaths(player)
  local steps = self.steps
  if not steps then
    NAV.job = nil
    self.activepath, self.activestep = nil, nil
    self:CommitPaths(nil, player)
    return
  end
  if NAV.job then
    -- one is already running: let it finish (its results fill the cache),
    -- then go again for the latest plan
    self.refineagain = true
    return
  end
  local sig = self.stepsig
  NAV:RunJob(function() core:RefineNow(steps, player, sig) end)
end

function core:RefineNow(steps, player, sig)
  local cache, fresh = self.pathcache or {}, {}
  local paths = {}
  local activepath, activestep, recalled
  local current = CurrentStep(steps, player)
  for k = current, getn(steps) do
    local s = steps[k]
    if s.kind == "walk" then
      local from = (k == current) and player or s.from
      if from and from.c and from.c == s.point.c then
        local poly
        if k == current then
          -- keep the stretch you are walking while you are on it; a new
          -- one only when you stray, the goal moves, or something new was
          -- learned (pathcache cleared)
          local key = Key(s.point)
          local last = self.lastactive
          if last and last.key == key and cache.active and NAV:OffPath(last.poly, player) < 10 then
            poly, recalled = last.poly, last.recalled
          else
            poly, recalled = NAV:Recall(from, s.point)
            poly = poly or NAV:Refine(from, s.point, s.zone)
            self.lastactive = { key = key, poly = poly, recalled = recalled }
          end
          fresh.active = true
          activepath, activestep = poly, k
        elseif from.net and s.point.net then
          poly = { from, s.point } -- a checked walk of the walking network
        else
          local key = Key(from) .. ">" .. Key(s.point)
          poly = cache[key] or NAV:Recall(from, s.point) or NAV:Refine(from, s.point, s.zone)
          fresh[key] = poly
        end
        insert(paths, poly)
      end
    end
  end
  self.pathcache = fresh
  if sig ~= self.stepsig then
    -- the plan changed while this ran: the cache is filled, go again
    self.refineagain = true
    return
  end
  self.activepath, self.activestep, self.recalled = activepath, activestep, recalled
  if activestep then self.forcedstep = nil end
  self:CommitPaths(getn(paths) > 0 and paths or nil, player)
  if not self.insample then self.needrefresh = true end
end

-- a background search just finished: show its plan now rather than on the
-- next sample, and start refining it on the next frame
function core:Solved(insample)
  self.solvejob = nil
  if not insample then
    self.nextsample = 0
    self.needrefresh = true
  end
end

-- update the arrow from the newest plan between samples (a background job
-- just finished); not a sample of its own, so the stuck check is left out
function core:Refresh()
  local player = self.lastsample
  if player and self.ready and pfQuestSmartArrow_config.enabled == "1" and PfQuestArrowOn() then
    self.refreshing = true
    UI:SetShown(self:Update(player) and true or false)
    self.refreshing = nil
  end
end

-- run background planning to the end now (tests, slash commands)
function core:FinishJobs()
  for _ = 1, 10000 do
    if self.solvejob then
      if not NAV:Resume(self.solvejob) then self:Solved() end
    elseif self.needrefresh then
      self.needrefresh = nil
      self:Refresh()
    elseif self.refinepending and self.lastsample then
      self.refinepending = nil
      self:RefinePaths(self.lastsample)
    elseif NAV.job then
      NAV:ResumeJob()
    elseif self.refineagain and self.lastsample then
      self.refineagain = nil
      self:RefinePaths(self.lastsample)
    else
      return
    end
  end
end

-- The dotted line keeps its first good guess: a new one replaces it only
-- after you walked REDRAW_YARDS since it was drawn, or for a new objective.
-- The arrow itself always follows the newest plan.
function core:CommitPaths(paths, player)
  local targetkey = self.target and Key(self.target) or ""
  local at = self.drawnat
  local now = not paths or not DRAW.paths or self.drawntarget ~= targetkey
    or not at or not player or at.c ~= player.c or G.Dist(at, player) >= REDRAW_YARDS
  if now then
    self.drawnat, self.drawntarget, self.heldpaths = player, targetkey, nil
    DRAW:SetPaths(paths)
  else
    self.heldpaths = paths
  end
end

-- Record the stretch you are walking; when you reach its end, remember the
-- way you walked it.
function core:Trace(step, player)
  if not step or step.kind ~= "walk" or not step.point or step.point.c ~= player.c then
    self.trace = nil
    return
  end
  local key = Key(step.point)
  local trace = self.trace
  if trace and trace.key ~= key then
    -- moved on to the next stretch: did you get to the end of this one?
    local last = trace[getn(trace)]
    if not trace.saved and G.Dist(last, trace.goal) < (trace.goal.radius or 10) + 8 then
      NAV:Remember(trace, trace.goal)
    end
    trace = nil
  end
  if not trace then
    trace = { key = key, goal = step.point, { c = player.c, n = player.n, w = player.w } }
    self.trace = trace
    return
  end
  local last = trace[getn(trace)]
  local d = G.Dist(last, player)
  if d > 60 or last.c ~= player.c then
    self.trace = nil -- a jump (death, teleport): not a walk
    return
  end
  if d >= 4 and getn(trace) < 600 then
    insert(trace, { c = player.c, n = player.n, w = player.w })
  end
  if not trace.saved and G.Dist(player, step.point) < 10 then
    trace.saved = true
    NAV:Remember(trace, step.point)
  end
end

function core:Update(player)
  local view = self.view or {}
  self.view = view
  view.player = player

  if UnitOnTaxi("player") then
    view.flying = true
    view.title = self.target and self.target.title or ""
    view.action = "|cff33ffccIn flight|r"
    view.point = nil
    view.notes = nil
    return true
  end
  view.flying = nil

  local target = self.target
  if not target then
    return false
  end

  view.title = target.title
  view.icon = target.icon
  view.iconcolor = target.iconcolor
  view.area = target.area

  local steps = self.steps
  if not steps then
    -- no route: other continent without a known transport, or an instance
    view.point = nil
    view.steps = nil
    view.total = nil
    view.action = "|cffff8888No known route to " .. (G.ZoneName(target.zone) or "this objective") .. "|r"
    view.notes = PL:Notes(target, player, false)
    return true
  end

  local i = CurrentStep(steps, player)
  local step = steps[i]
  view.notes = PL:Notes(target, player, step.final)
  local structure = NAV:StructureNote(target, player)
  if structure then
    insert(view.notes, 1, structure)
  end
  view.steps, view.stepsig, view.current = steps, self.stepsig, i
  view.point = step.point
  view.final = step.final
  view.total = self.route and (self.route.shown or self.route.total)
  view.yards = nil
  view.finaldist = step.final and G.Dist(player, target) or nil

  -- on foot: aim a few yards ahead along the planned path, so the arrow
  -- leads around the tree instead of at it
  if step.kind == "walk" then
    if self.activestep ~= i then
      -- reached a waypoint: plan the next stretch now (once per step, so a
      -- stretch that cannot be refined does not replan on every tick)
      if not self.refinepending and not NAV.job and not self.solvejob and self.forcedstep ~= i then
        self.forcedstep = i
        self.nextsolve = 0
      end
    elseif self.activepath then
      local carrot, remaining = NAV:Aim(self.activepath, player)
      if carrot then
        view.point = carrot
        view.yards = remaining
        local facing = COMPAT.Facing()
        if not self.refreshing and NAV:Observe(player, carrot, step.point, GetTime(), facing) then
          -- just learned something is in the way: plan around it now, and
          -- a remembered route that led here is not to be trusted
          if self.recalled then
            NAV:ForgetRoute(self.recalled)
            self.recalled = nil
          end
          self.pathcache = {}
          self.nextsolve = 0
        end
      end
    end
  end

  self:Trace(step, player)

  if step.kind == "walk" and step.final then
    -- on the last leg, show what to do there (pfQuest's objective text)
    local desc = target.node and target.node.description
    view.action = desc and (desc .. "|r") or ""
  elseif step.kind == "walk" then
    view.action = step.text
  else
    view.action = "|cff33ffcc" .. step.text .. "|r"
  end

  -- manual waypoint reached
  if target.manual and step.final and G.Dist(player, target) < 10 then
    Print("Arrived at " .. target.title .. ".")
    self:SetWaypoint(nil)
  end

  return true
end

core:SetScript("OnUpdate", function()
  if not this.ready then
    return
  end
  -- route search and path planning in the background: a little every frame
  if this.solvejob then
    if not NAV:Resume(this.solvejob) then this:Solved() end
  elseif this.needrefresh then
    -- a frame of its own for showing what a job just finished
    this.needrefresh = nil
    this:Refresh()
  elseif NAV.job then
    NAV:ResumeJob()
  elseif this.refineagain and this.lastsample then
    this.refineagain = nil
    this:RefinePaths(this.lastsample)
  end
  local now = GetTime()
  if (this.nextsample or 0) > now then
    return
  end
  this.nextsample = now + SAMPLE_EVERY

  -- routing off: pfQuest's own handler owns the arrow
  if pfQuestSmartArrow_config.enabled ~= "1" then
    return
  end

  -- pfQuest's arrow switched off: stay hidden and idle with it
  if not PfQuestArrowOn() then
    UI:SetShown(false)
    return
  end

  local player = PlayerPoint()
  if not player then
    UI:SetShown(false)
    return
  end

  this:Learn(player)
  NAV:Record(player, now)

  -- The heavy work is spread over separate ticks: a solve on one, the path
  -- refinement on the next, so they never land in the same frame.
  -- a held dotted line goes up once you have walked far enough
  if this.heldpaths and this.drawnat and (this.drawnat.c ~= player.c or G.Dist(this.drawnat, player) >= REDRAW_YARDS) then
    this:CommitPaths(this.heldpaths, player)
  end

  if this.refinepending then
    this.refinepending = nil
    this.insample = true
    this:RefinePaths(player)
    this.insample = nil
  elseif not this.solvejob and not UnitOnTaxi("player") and (this.nextsolve or 0) < now then
    local forced = (this.nextsolve or 0) == 0
    this.nextsolve = now + SOLVE_EVERY
    if forced or this:NeedsReplan(player, now) then
      local at = this.solvedat
      local jumped = at and (at.c ~= player.c or G.Dist(at, player) > 100)
      this.solvedat, this.solvetime, this.solvefp = player, now, this:CandidateFingerprint()
      -- the search runs in the background too; the arrow keeps the current
      -- plan for the few frames it takes
      -- (it starts on the next frame: this one already did the sample)
      this.solvejob = coroutine.create(function() core:Solve(player, jumped) end)
    end
  end

  UI:SetShown(this:Update(player) and true or false)
end)

-- Something that tells when pfQuest's objectives changed (quest accepted or
-- done, a node clicked, a mob killed): the count, the sum of their spots, and
-- pfQuest's explicit target. Order does not matter, so the list being
-- re-sorted by distance as you walk does not count as a change.
function core:CandidateFingerprint()
  if self.waypoint then
    return "way:" .. Key(self.waypoint)
  end
  local list = COMPAT.Candidates()
  if not list or not list[1] then return "none" end
  local sum = 0
  local count = getn(list)
  for i = 1, count do
    sum = sum + (list[i][1] or 0) + (list[i][2] or 0) * 3
  end
  local first = list[1]
  local explicit = pfQuest.route.IsTarget and pfQuest.route.IsTarget(first[3])
  return count .. ":" .. floor(sum) .. ":" .. (explicit and Key(CandidateToTarget(first)) or "")
end

-- A full replan (graph search, target choice, path refinement) only when it
-- can give a different answer: you moved a fair bit, the objectives changed,
-- you strayed from the drawn path, or the plan is getting old.
function core:NeedsReplan(player, now)
  local at = self.solvedat
  if not at or at.c ~= player.c or not self.solvetime then return true end
  if G.dirty then return true end -- learned a flight path, border or the like
  if self.pendingsig then return true end -- a new plan waiting to be confirmed
  if now - self.solvetime > REPLAN_AGE then return true end
  if G.Dist(at, player) > REPLAN_MOVED then return true end
  if self.activepath and NAV:OffPath(self.activepath, player) > 10 then return true end
  return self:CandidateFingerprint() ~= self.solvefp
end

-- learning --------------------------------------------------------------------

-- Remember the spot where you walk from one zone into another. Only real
-- walks count: same continent, a few yards apart, not on a flight.
function core:Learn(player)
  local last = self.lastsample
  self.lastsample = player
  player.taxi = UnitOnTaxi("player")

  -- plain 1.12 client: fix an approximate zone the moment you walk into it
  local map = COMPAT.LastMapPosition()
  if map and not player.taxi then
    local prev = self.lastmap
    if prev and COMPAT.Calibrate(prev, map) then
      Print("measured " .. (G.ZoneName(map.zone) or "this zone") .. "'s map; positions there are exact now")
      self:Reposition()
    end
    self.lastmap = { zone = map.zone, x = map.x, y = map.y, c = map.c, n = map.n, w = map.w, time = map.time }
  end

  PL:Learn(last, player)

  if pfQuestSmartArrow_config.learn ~= "1" or not last then
    return
  end
  if not last.zone or not player.zone or last.zone == player.zone then
    return
  end
  if last.c ~= player.c or last.taxi or player.taxi then
    return
  end
  if G.Dist(last, player) > 40 then
    return
  end

  local mid = { c = player.c, n = (last.n + player.n) / 2, w = (last.w + player.w) / 2 }
  local a, b = last.zone, player.zone
  for _, node in ipairs(G.nodes) do
    if node.c == mid.c and G.Dist(node, mid) < 200 then
      if node.kind == "connector" and node.zones[a] and node.zones[b] then return end
      if node.kind == "border" and (node.zones[a] or node.zones[b]) then return end
    end
  end

  insert(pfQuestSmartArrow_config.learned, {
    c = mid.c, n = mid.n, w = mid.w, links = { a, b },
    name = (G.ZoneName(a) or "?") .. " border",
  })
  G.dirty = true
  self.nextsolve = 0
end

function core:RecordTaxi()
  local known = pfQuestSmartArrow_char.taxi
  local added = 0
  for i = 1, NumTaxiNodes() do
    local kind = TaxiNodeGetType(i)
    local name = TaxiNodeName(i)
    if name and (kind == "CURRENT" or kind == "REACHABLE") and not known[name] then
      known[name] = true
      added = added + 1
    end
  end
  if added > 0 then
    G.dirty = true
    self.nextsolve = 0
  end
end

-- setup -----------------------------------------------------------------------

-- a zone's map position changed (calibrated): recompute everything placed by
-- map coordinates
function core:Reposition()
  NAV:ResetTransforms()
  G:ResetMaps()
  PL:Resolve()
  NAV:ResolveObstacles()
  NAV:StartRoadBuild()
  G.dirty = true
  self.pathcache = {}
  self.lastactive = nil
  self.nextsolve = 0
end

function core:ToggleNotes()
  pfQuestSmartArrow_config.notes = pfQuestSmartArrow_config.notes == "1" and "0" or "1"
end

function core:Init()
  pfQuestSmartArrow_config = pfQuestSmartArrow_config or {}
  for k, v in pairs(defaults) do
    if pfQuestSmartArrow_config[k] == nil then
      pfQuestSmartArrow_config[k] = v
    end
  end
  pfQuestSmartArrow_config.learned = pfQuestSmartArrow_config.learned or {}
  pfQuestSmartArrow_config.places = pfQuestSmartArrow_config.places or {}
  pfQuestSmartArrow_config.notes_list = pfQuestSmartArrow_config.notes_list or {}
  -- retired settings from the old step list
  pfQuestSmartArrow_config.steps, pfQuestSmartArrow_config.maxsteps = nil, nil

  pfQuestSmartArrow_char = pfQuestSmartArrow_char or {}
  pfQuestSmartArrow_char.taxi = pfQuestSmartArrow_char.taxi or {}

  -- everything below comes from pfQuest; without it there is nothing to do
  if not (pfQuest and pfQuest.route and pfMap) then
    Print("|cffff5555pfQuest is not loaded. pfQuest SmartArrow does nothing without it.|r")
    return
  end
  local ok, why = COMPAT.Ready()
  if not ok or not UI:Frame() then
    Print("|cffff5555" .. (why or "pfQuest's arrow frame is missing") .. ". pfQuest SmartArrow is disabled.|r")
    return
  end

  PL:Resolve()
  NAV:Init()
  DRAW:Hook()
  SetRouting(pfQuestSmartArrow_config.enabled == "1")
  -- build the travel graph now, while the loading screen is still up, rather
  -- than in the first frame you can move in (the first build is the big one;
  -- later ones reuse the walking network and are quick)
  G:Rebuild()
  self.ready = true
end

core:RegisterEvent("PLAYER_ENTERING_WORLD")
core:RegisterEvent("TAXIMAP_OPENED")
core:RegisterEvent("PLAYER_LEVEL_UP")
core:SetScript("OnEvent", function()
  if event == "PLAYER_ENTERING_WORLD" then
    if not this.initialized then
      this.initialized = true
      this:Init()
    end
    this.lastsample = nil
    this.nextsolve = 0
  elseif event == "TAXIMAP_OPENED" and this.ready then
    this:RecordTaxi()
    if not (C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap) then
      pfQuestSmartArrow_char.taxipos = pfQuestSmartArrow_char.taxipos or {}
      if COMPAT.RecordTaxiPositions(pfQuestSmartArrow_char.taxipos) > 0 then
        G.dirty = true
        this.nextsolve = 0
      end
    end
  elseif event == "PLAYER_LEVEL_UP" then
    this.nextsolve = 0
  end
end)

-- slash -----------------------------------------------------------------------

local function OnOff(v)
  return v == "1" and "|cff33ff33on|r" or "|cffff5555off|r"
end

local function Usage()
  local c = pfQuestSmartArrow_config
  Print("commands:")
  Print("  /smartarrow on|off - route pfQuest's arrow, or let it point straight (" .. OnOff(c.enabled) .. ")")
  Print("  /smartarrow notes - show special notes under the arrow (" .. OnOff(c.notes) .. ")")
  Print("  /smartarrow note <text> - pin a note here (e.g. 'up the ramp, second floor'); /smartarrow note - remove the nearest")
  Print("  /smartarrow smart - pick objective by travel time (" .. OnOff(c.smart) .. ")")
  Print("  /smartarrow taxi known|all|none - flight paths to use (" .. c.taxi .. ")")
  Print("  /smartarrow learn - learn zone borders, entrances and obstacles (" .. OnOff(c.learn) .. ": " .. getn(c.learned) .. " borders, " .. getn(c.places) .. " places, " .. getn(c.obstacles) .. " obstacles, " .. NAV:RouteCount() .. " routes)")
  Print("  /smartarrow stuck - the arrow points into a wall: mark it blocked and go round")
  Print("  /smartarrow trails - record the paths you walk and prefer them (" .. OnOff(c.trails_on) .. ", " .. NAV:TrailCount() .. " points)")
  Print("  /smartarrow safety 0-3 - how hard to avoid hostile mobs (" .. tostring(c.safety) .. (NAV.grid and "" or ", danger map still building") .. ")")
  Print("  /smartarrow path - draw the planned path on the map and minimap (" .. OnOff(c.drawpath) .. ")")
  Print("  /smartarrow forget borders|places|obstacles|trails|routes|all - forget learned data (notes are kept)")
  Print("  /smartarrow way [zone,] x y [title] - set a waypoint; /smartarrow way - clear")
  Print("  /smartarrow route - print the full route in chat")
  Print("  pfQuest's arrow settings still apply: /db arrow toggles it, Shift-drag moves it, Shift-wheel scales it")
  if not PfQuestArrowOn() then
    Print("  |cffff5555pfQuest's arrow is switched off, so routing is idle. Turn it on with /db arrow.|r")
  end
end

local function Toggle(key)
  pfQuestSmartArrow_config[key] = pfQuestSmartArrow_config[key] == "1" and "0" or "1"
  return pfQuestSmartArrow_config[key]
end

local function ParseWay(rest)
  -- "Wetlands, 10.5 60.2 My title" or "10.5 60.2 My title"
  local zone
  local _, _, zname, tail = string.find(rest, "^([^,]+),%s*(.*)$")
  if zname and pfMap:GetMapIDByName(zname) then
    zone = pfMap:GetMapIDByName(zname)
    rest = tail
  else
    zone = PlayerZone()
  end
  local _, _, x, y, title = string.find(rest, "^(%d+%.?%d*)[%s,]+(%d+%.?%d*)%s*(.*)$")
  x, y = tonumber(x), tonumber(y)
  if not x or not y then
    return nil
  end
  if title == "" then title = nil end
  return zone, x, y, title
end

SLASH_PFQUESTSMARTARROW1 = "/smartarrow"
SLASH_PFQUESTSMARTARROW2 = "/psa"
SlashCmdList["PFQUESTSMARTARROW"] = function(msg)
  msg = msg or ""
  local _, _, cmd, rest = string.find(msg, "^%s*(%S*)%s*(.-)%s*$")
  cmd = string.lower(cmd or "")
  local c = pfQuestSmartArrow_config

  if not core.ready then
    Print("not active (see the message at login).")
    return
  end

  if cmd == "steps" then
    cmd = "notes" -- old name
  end

  if cmd == "on" or cmd == "off" then
    c.enabled = cmd == "on" and "1" or "0"
    SetRouting(c.enabled == "1")
    core.nextsolve = 0
    Print("routing " .. OnOff(c.enabled) .. (c.enabled == "1" and "" or " (pfQuest's straight arrow)"))
  elseif cmd == "notes" then
    Print("notes " .. OnOff(Toggle("notes")))
  elseif cmd == "note" then
    local player = PlayerPoint()
    if not player then
      Print("no position")
    elseif rest == "" then
      local removed = PL:RemoveNote(player)
      Print(removed and ("removed note: " .. removed.text) or "no note within 60 yards")
    else
      PL:AddNote(player, rest)
      Print("note pinned here: " .. rest)
    end
  elseif cmd == "smart" then
    Print("travel-time targeting " .. OnOff(Toggle("smart")))
  elseif cmd == "learn" then
    Print("border learning " .. OnOff(Toggle("learn")))
  elseif cmd == "taxi" then
    if rest == "known" or rest == "all" or rest == "none" then
      c.taxi = rest
      G.dirty = true
      core.nextsolve = 0
    end
    Print("flight paths: " .. c.taxi .. " (" .. (G.taxicount or 0) .. " in use)")
  elseif cmd == "way" then
    if rest == "" then
      core:SetWaypoint(nil)
      Print("waypoint cleared")
    else
      local zone, x, y, title = ParseWay(rest)
      if zone and core:SetWaypoint(zone, x, y, title) then
        Print("waypoint set: " .. core.waypoint.title)
      else
        Print("could not place that waypoint")
      end
    end
  elseif cmd == "route" then
    if not core.steps then
      Print("no route")
    else
      Print("route to " .. (core.target.title or "?") .. " (~" .. pfQuestSmartArrow_FormatTime(core.route.shown or core.route.total) .. "):")
      local shown = 0
      for i, s in ipairs(core.steps) do
        -- waypoints on the way (passes) repeat the next instruction; fold them
        if not s.waypoint then
          shown = shown + 1
          Print("  " .. shown .. ". " .. s.text .. " |cff888888" .. pfQuestSmartArrow_FormatTime(s.secs) .. "|r")
        end
      end
    end
  elseif cmd == "stuck" then
    local player = core.lastsample
    local aim = core.view and core.view.point
    if NAV:MarkBlocked(player, aim) then
      core.pathcache = {}
      core.lastactive = nil
      core.nextsolve = 0
      Print("marked the way ahead as blocked; finding a way round")
    else
      Print("nothing to mark: the arrow is not pointing anywhere on foot")
    end
  elseif cmd == "trails" then
    Print("trail recording " .. OnOff(Toggle("trails_on")))
  elseif cmd == "path" then
    Toggle("drawpath")
    DRAW:SetPaths(DRAW.paths)
    Print("map path " .. OnOff(c.drawpath))
  elseif cmd == "safety" then
    local v = tonumber(rest)
    if v and v >= 0 and v <= 3 then
      c.safety = v
      NAV.dangercache = {}
      core.pathcache = {}
      core.nextsolve = 0
    end
    Print("safety " .. tostring(c.safety) .. " (0 ignores mobs, 1 avoids camps, 3 avoids them hard)")
  elseif cmd == "forget" then
    local what = rest ~= "" and rest or "all"
    if what == "borders" or what == "all" then c.learned = {} G.dirty = true end
    if what == "places" or what == "all" then c.places = {} end
    if what == "obstacles" or what == "all" then c.obstacles = {} end
    if what == "trails" or what == "all" then c.trails = {} NAV:RebuildHash() NAV.lasttrail = nil end
    if what == "routes" or what == "all" then NAV:ForgetRoutes() core.lastactive = nil end
    core.pathcache = {}
    core.nextsolve = 0
    Print("forgot " .. what .. " (your notes are kept)")
  else
    Usage()
  end
end
