-- Ashen Builds combat simulator: shared engine.
--
-- Event-driven Monte Carlo simulation. Every fight is a sequence of timed events
-- (swings, ability casts, cooldowns, aura expiries, DoT ticks) pulled from a
-- priority queue in time order; class modules (SimWarrior.lua, ...) register the
-- events and decide what the character does. Nothing here is class-specific.
--
-- Accuracy bookkeeping: every mechanic a module implements is registered with a
-- status so the UI can show how much of a result is verified:
--   VERIFIED            matches current Turtle server data (Tortoise DB snapshot)
--   REFERENCE_VERIFIED  matches a maintained Turtle simulator, not independently confirmed
--   NEEDS_LIVE_TEST     a fitted/assumed formula that needs combat-log testing on Turtle
--   UNKNOWN             not modelled, or behaviour not known

AshenSim = AshenSim or {}
local S = AshenSim

S.VERIFIED, S.REFERENCE, S.LIVE, S.UNKNOWN = "VERIFIED", "REFERENCE_VERIFIED", "NEEDS_LIVE_TEST", "UNKNOWN"
S.Mechanics = {}
S.MechanicOrder = {}

-- Registers what a mechanic is based on. key: short id; source: where the numbers come from.
function S.Mechanic(key, status, source, note)
  if not S.Mechanics[key] then table.insert(S.MechanicOrder, key) end
  S.Mechanics[key] = {key = key, status = status, source = source, note = note}
end

---------------------------------------------------------------------------
-- Seeded RNG (Park-Miller minimal standard). Exact in double precision, so the
-- same seed gives the same fight on every client. Each iteration gets its own
-- seed, which also makes paired comparisons (same seeds, two builds) possible.
---------------------------------------------------------------------------
local RNG = {}
RNG.__index = RNG
local M31 = 2147483647

function S.NewRNG(seed)
  seed = math.floor(tonumber(seed) or 1)
  seed = math.mod(seed, M31 - 1)
  if seed <= 0 then seed = seed + M31 - 1 end
  local r = setmetatable({s = seed}, RNG)
  r:Next(); r:Next()
  return r
end

-- Uniform in [0, 1).
function RNG:Next()
  self.s = math.mod(self.s * 16807, M31)
  return (self.s - 1) / (M31 - 1)
end

function RNG:Range(a, b) return a + (b - a) * self:Next() end

-- Seed for iteration i of a run with base seed `base` (distinct, reproducible streams).
function S.IterationSeed(base, i) return math.mod((tonumber(base) or 1) + i * 7919, M31 - 2) + 1 end

---------------------------------------------------------------------------
-- Event queue: binary heap ordered by time, then by insertion order so events at
-- the same instant resolve in the order they were scheduled.
---------------------------------------------------------------------------
local function Less(a, b) if a.t ~= b.t then return a.t < b.t end return a.seq < b.seq end

local function Push(q, ev)
  q.n = q.n + 1; local i = q.n; q.items[i] = ev
  while i > 1 do
    local p = math.floor(i / 2)
    if Less(q.items[i], q.items[p]) then q.items[i], q.items[p] = q.items[p], q.items[i]; i = p else break end
  end
end

local function Pop(q)
  if q.n == 0 then return nil end
  local top = q.items[1]
  q.items[1] = q.items[q.n]; q.items[q.n] = nil; q.n = q.n - 1
  local i = 1
  while true do
    local l, r, m = i * 2, i * 2 + 1, i
    if l <= q.n and Less(q.items[l], q.items[m]) then m = l end
    if r <= q.n and Less(q.items[r], q.items[m]) then m = r end
    if m == i then break end
    q.items[i], q.items[m] = q.items[m], q.items[i]; i = m
  end
  return top
end

---------------------------------------------------------------------------
-- A single fight.
---------------------------------------------------------------------------
local Sim = {}
Sim.__index = Sim

-- Events are recycled once they have run. A fight schedules thousands of them,
-- and fresh tables for each would make the client pause for garbage collection
-- every few seconds while a simulation runs. Anyone holding an event must drop
-- the reference when it fires or is cancelled (every caller in the modules does).
local pool, poolN, POOL_MAX = {}, 0, 8192
local function Recycle(ev)
  ev.fn = nil; ev.a = nil
  if poolN < POOL_MAX then poolN = poolN + 1; pool[poolN] = ev end
end

-- Schedules fn(sim, arg) at absolute time t (seconds). Returns the event; set ev.dead to cancel.
function Sim:At(t, fn, arg)
  self.seq = self.seq + 1
  local ev
  if poolN > 0 then ev = pool[poolN]; pool[poolN] = nil; poolN = poolN - 1; ev.dead = nil else ev = {} end
  ev.t = t; ev.seq = self.seq; ev.fn = fn; ev.a = arg
  Push(self.queue, ev)
  return ev
end
function Sim:After(dt, fn, arg) return self:At(self.t + dt, fn, arg) end

-- Debug trace (only when a log table was supplied).
-- Callers check sim.log first so no text is built when nobody is reading it.
function Sim:Log(text) if self.log then table.insert(self.log, string.format("%8.3f  %s", self.t, text)) end end

-- Damage bookkeeping per source ("Bloodthirst", "Auto Attack (MH)", "Deep Wounds", ...).
function Sim:Damage(source, amount, result)
  local s = self.sources[source]
  if not s then s = {dmg = 0, casts = 0, results = {}}; self.sources[source] = s end
  s.dmg = s.dmg + amount; s.casts = s.casts + 1
  if result then s.results[result] = (s.results[result] or 0) + 1 end
  self.total = self.total + amount
end

function Sim:Count(key, n) self.counters[key] = (self.counters[key] or 0) + (n or 1) end

---------------------------------------------------------------------------
-- Auras: timed buffs/debuffs with optional stacks/charges and uptime tracking.
---------------------------------------------------------------------------
local Aura = {}
Aura.__index = Aura

function S.NewAura(sim, name, onGain, onFade)
  local a = setmetatable({sim = sim, name = name, active = false, stacks = 0, since = 0, uptime = 0, onGain = onGain, onFade = onFade}, Aura)
  sim.auras[name] = a
  return a
end

local function AuraExpire(sim, a) a.expiry = nil; a:Remove() end

-- Applies/refreshes for `duration` seconds (nil = until removed).
function Aura:Apply(duration, stacks)
  local sim = self.sim
  if not self.active then
    self.active = true; self.since = sim.t
    if self.onGain then self.onGain(sim, self) end
  end
  if stacks then self.stacks = stacks end
  if self.expiry then self.expiry.dead = true; self.expiry = nil end
  if duration then
    self.expiry = sim:After(duration, AuraExpire, self)
  end
end

function Aura:Remove()
  if not self.active then return end
  local sim = self.sim
  self.active = false; self.stacks = 0
  self.uptime = self.uptime + (sim.t - self.since)
  if self.expiry then self.expiry.dead = true; self.expiry = nil end
  if self.onFade then self.onFade(sim, self) end
end

-- Closes open uptime at the end of the fight.
function Aura:Close(t) if self.active then self.uptime = self.uptime + (t - self.since); self.since = t end end

---------------------------------------------------------------------------
-- Running fights.
---------------------------------------------------------------------------
-- model: a class module ({Setup(sim, char, cfg) -> actor, Start(sim, actor), Finish(sim, actor)}).
function S.RunFight(model, char, cfg, seed, log)
  local sim = setmetatable({t = 0, seq = 0, queue = {n = 0, items = {}}, rng = S.NewRNG(seed), cfg = cfg, log = log,
    sources = {}, counters = {}, auras = {}, total = 0}, Sim)
  sim.duration = cfg.duration
  local actor = model.Setup(sim, char, cfg)
  model.Start(sim, actor)
  while true do
    local ev = Pop(sim.queue)
    if not ev then break end
    if ev.t > sim.duration then Recycle(ev); break end
    if not ev.dead then sim.t = ev.t; ev.fn(sim, ev.a) end
    Recycle(ev)
  end
  local q, i = sim.queue
  for i = 1, q.n do Recycle(q.items[i]); q.items[i] = nil end
  q.n = 0
  sim.t = sim.duration
  for _, a in pairs(sim.auras) do a:Close(sim.duration) end
  model.Finish(sim, actor)
  sim.dps = sim.total / sim.duration
  return sim
end

-- Accumulates fights into a result summary.
function S.NewSummary()
  return {n = 0, sum = 0, sum2 = 0, min = nil, max = nil, sources = {}, counters = {}, uptime = {}, duration = 0}
end

function S.AddFight(sum, sim)
  sum.n = sum.n + 1
  sum.sum = sum.sum + sim.dps; sum.sum2 = sum.sum2 + sim.dps * sim.dps
  if not sum.min or sim.dps < sum.min then sum.min = sim.dps end
  if not sum.max or sim.dps > sum.max then sum.max = sim.dps end
  sum.duration = sum.duration + sim.duration
  local name, s, k, v
  for name, s in pairs(sim.sources) do
    local d = sum.sources[name]
    if not d then d = {dmg = 0, casts = 0, results = {}}; sum.sources[name] = d end
    d.dmg = d.dmg + s.dmg; d.casts = d.casts + s.casts
    for k, v in pairs(s.results) do d.results[k] = (d.results[k] or 0) + v end
  end
  for k, v in pairs(sim.counters) do sum.counters[k] = (sum.counters[k] or 0) + v end
  for name, s in pairs(sim.auras) do sum.uptime[name] = (sum.uptime[name] or 0) + s.uptime end
end

-- Mean DPS, standard deviation and 95% confidence interval of the mean.
function S.Stats(sum)
  if sum.n == 0 then return 0, 0, 0, 0 end
  local mean = sum.sum / sum.n
  local var = sum.n > 1 and math.max(0, (sum.sum2 - sum.n * mean * mean) / (sum.n - 1)) or 0
  local sd = math.sqrt(var)
  local half = 1.96 * sd / math.sqrt(sum.n)
  return mean, sd, mean - half, mean + half
end

---------------------------------------------------------------------------
-- Frame-spread runner. Runs fights for a few milliseconds per frame so the
-- client never freezes; the driving frame's OnUpdate is removed when the job
-- ends, so an idle simulator costs nothing.
---------------------------------------------------------------------------
local runner = CreateFrame and CreateFrame("Frame") or nil
local job = nil
local FRAME_BUDGET = 0.008

local function Clock()
  if debugprofilestop then return debugprofilestop() / 1000 end
  return GetTime()
end

local function Tick()
  if not job then runner:SetScript("OnUpdate", nil); return end
  local start = Clock()
  repeat
    job.i = job.i + 1
    local ok, sim = pcall(S.RunFight, job.model, job.char, job.cfg, S.IterationSeed(job.seed, job.i))
    if not ok then
      local j = job; job = nil; runner:SetScript("OnUpdate", nil)
      if j.onError then j.onError(sim) end
      return
    end
    S.AddFight(job.summary, sim)
    if job.i >= job.iterations then
      local j = job; job = nil; runner:SetScript("OnUpdate", nil)
      if j.onDone then j.onDone(j.summary) end
      return
    end
  until Clock() - start >= FRAME_BUDGET
  if job.onProgress then job.onProgress(job.i, job.iterations) end
end

-- o = {model, char, cfg, iterations, seed, onProgress(i, n), onDone(summary), onError(msg)}
function S.Start(o)
  job = {model = o.model, char = o.char, cfg = o.cfg, iterations = o.iterations, seed = o.seed or 1, i = 0,
    summary = S.NewSummary(), onProgress = o.onProgress, onDone = o.onDone, onError = o.onError}
  runner:SetScript("OnUpdate", Tick)
end

function S.Cancel() if job then job = nil; runner:SetScript("OnUpdate", nil) end end
function S.IsRunning() return job ~= nil end

-- Runs a whole batch synchronously (tests and small comparisons).
function S.RunBatch(model, char, cfg, iterations, seed)
  local sum = S.NewSummary(); local i
  for i = 1, iterations do S.AddFight(sum, S.RunFight(model, char, cfg, S.IterationSeed(seed or 1, i))) end
  return sum
end
