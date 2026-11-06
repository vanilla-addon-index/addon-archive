-- weirdperformance.dll mode: its collector runs one full mark per cycle and
-- then sweeps in chunks, setting the threshold to heap + 128 KB in between.
-- Emulated here as the game would show it through gcinfo()/collectgarbage().
-- Run: lua5.0 tests/test_weirdperf.lua GentleGC.lua
format = string.format
local now = 1000
function GetTime() return now end
local combat = false
function UnitAffectingCombat() return combat end
function UnitIsAFK() return false end
local log = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) table.insert(log, m); print("  " .. m) end }
SlashCmdList = {}
FRAMES = {}
function CreateFrame()
  local f = { scripts = {} }
  function f:RegisterEvent() end
  function f:UnregisterEvent() end
  function f:SetScript(k, fn) self.scripts[k] = fn end
  table.insert(FRAMES, f)
  return f
end
function GetWeirdUtilsVersion(m)
  if m == "weirdperformance" then return "1.0" end
  return { weirdperformance = "1.0" }
end

-- the emulated collector (the real Lua threshold is kept out of the way)
local realGC, realInfo = collectgarbage, gcinfo
local W = { thr = 0, sweeping = false, left = 0, cycles = 0, chunks = 0 }
local CHUNKS = 3
local function heap() return (realInfo()) end
local function wpRun()                 -- the hooked luaC_collectgarbage
  if not W.sweeping then
    W.cycles = W.cycles + 1
    realGC(); realGC(4000000)          -- the mark (the emulation frees everything here)
    W.sweeping, W.left = true, CHUNKS
    W.thr = heap() + 128
  else
    W.chunks = W.chunks + 1
    W.left = W.left - 1
    if W.left <= 0 then
      W.sweeping = false
      W.thr = math.floor(heap() * 1.25)
    else
      W.thr = heap() + 128
    end
  end
end
gcinfo = function() return heap(), W.thr end
collectgarbage = function(n)           -- lua_setgcthreshold + luaC_checkGC
  if type(n) == "table" then return realGC(n) end   -- (invalid argument: errors, like the game)
  W.thr = n or 0
  if heap() >= W.thr then wpRun() end
end
local function engine() if heap() >= W.thr then wpRun() end end

LIVE = {}
for i = 1, 300000 do LIVE[i] = { i } end
realGC(); realGC(4000000)
W.thr = math.floor(heap() * 1.25)

dofile(arg[1])
local F = FRAMES[1]
local HF = FRAMES[2]
event, arg1 = "ADDON_LOADED", "GentleGC"; this = F; F.scripts.OnEvent()
local SF = FRAMES[4]
local cmd = SlashCmdList.GENTLEGC
cmd("debug 2")

local function count(pat) local n = 0; for _, m in ipairs(log) do if string.find(m, pat) then n = n + 1 end end; return n end
local function lastMatch(pat) for i = table.getn(log), 1, -1 do if string.find(log[i], pat) then return log[i] end end; return "" end
local function check(name, c) print((c and "PASS " or "FAIL ") .. name); if not c then FAILED = true end end
local junk, ji = {}, 0
-- one frame: allocate `kb` of garbage, let the collector react, then GentleGC's OnUpdates
-- (allocation is counted in objects, ~9 per KB, so a collection in the middle
-- of the frame doesn't change how much the frame allocates)
local function frame(dt, kb)
  local n = math.floor((kb or 0) * 9)
  for k = 1, n do
    ji = ji + 1; junk[ji] = { ji }
    if ji > 20000 then junk, ji = {}, 0 end
    if math.mod(k, 50) == 0 then engine() end
  end
  engine()
  now = now + dt
  SF.scripts.OnUpdate()
  arg1 = dt; this = F; F.scripts.OnUpdate()
  if HF.scripts.OnUpdate then HF.scripts.OnUpdate() end
end
local function play(seconds, kbPerSec)
  for i = 1, seconds * 10 do frame(0.1, (kbPerSec or 0) / 10) end
end

print("1. detected")
cmd("status")
check("status names weirdperformance", count("weirdperformance: ") >= 1)

print("2. the game's cycles and chunks while playing")
cmd("pressure 100")                    -- GentleGC holds off: the game starts every cycle here
play(40, 400)                          -- 400 KB/s of garbage
local gameCycles = W.cycles
check("the emulated collector ran cycles and chunks", W.cycles >= 1 and W.chunks >= 2)
check("chunks aren't reported as threshold changes", count("threshold set to") == 0)
check("chunks aren't reported as collections", count("automatic GC detected") <= W.cycles)
check("each game-started cycle reported once", count("weirdperformance cycle started") == W.cycles)
check("no 'didn't run a normal collection' warnings", count("didn't run a normal collection") == 0)
check("no 'did not run' warnings", count("did not run") == 0)

print("3. GentleGC starts a cycle only when none is running")
while W.sweeping do frame(0.1, 200) end
play(2)
local c0 = W.cycles
cmd("now")
check("GentleGC's collection started a cycle", W.cycles == c0 + 1 and W.sweeping)
check("logged as a cycle start", string.find(lastMatch("manual:"), "started a weirdperformance cycle") ~= nil)
local c1, k1 = W.cycles, W.chunks
cmd("now")
check("mid-cycle, GentleGC does nothing", W.cycles == c1 and W.chunks == k1)

print("4. no pressure attempts in the middle of a cycle")
cmd("pressure 70")
local before = count("pressure:")
for i = 1, 30 do frame(0.1, 3) end     -- 90 KB in all: stays inside one chunk
check("still mid-cycle", W.sweeping)
check("no pressure collection mid-cycle", count("pressure:") == before)

print("5. the end of a cycle teaches the ratio and the live estimate")
while W.sweeping do frame(0.1, 200) end
play(1)
cmd("status")
check("ratio measured as ~1.25x (read a frame late, so a little lower)", string.find(lastMatch("collector:"), "lowest 1%.2[0-5]x") ~= nil)
local _, _, live = string.find(lastMatch("heap .* live ~"), "live ~([%d%.]+)mb")
check("live estimate matches the heap after the cycle", live and math.abs(tonumber(live) - heap() / 1024) < 1)

print("6. combat: chunks keep running, the next cycle waits for the fight to end")
-- start a cycle, then pull while it runs
cmd("now")
check("a cycle is running at the pull", W.sweeping)
combat = true
event = "PLAYER_REGEN_DISABLED"; this = F; F.scripts.OnEvent()
check("threshold not raised mid-cycle (chunks continue)", W.thr <= heap() + 256)
while W.sweeping do frame(0.1, 200) end
play(1)
local used = heap()
check("after the cycle ends in combat, the headroom is added", W.thr >= used + 32 * 1024 - 256)
local cyclesInCombat = W.cycles
play(20, 1000)                          -- 20 MB of garbage in the fight
check("no new cycle during the fight", W.cycles == cyclesInCombat)
combat = false
event = "PLAYER_REGEN_ENABLED"; this = F; F.scripts.OnEvent()
play(2)
cmd("status")
check("status counts cycles and chunks", string.find(lastMatch("weirdperformance: "), "sweep chunks") ~= nil)

print("6b. a cycle starting in the fight, and the fight ending mid-cycle")
while W.sweeping do frame(0.1, 200) end
play(1)
combat = true
event = "PLAYER_REGEN_DISABLED"; this = F; F.scripts.OnEvent()
local c6 = W.cycles
while W.cycles == c6 do frame(0.1, 100) end       -- the fight fills the raised headroom
check("a cycle started in the fight", W.sweeping)
combat = false
event = "PLAYER_REGEN_ENABLED"; this = F; F.scripts.OnEvent()
check("leaving combat mid-cycle keeps the chunk threshold", W.thr <= heap() + 256)
local k6 = W.chunks
play(2, 400)
check("chunks keep running after the fight", W.chunks > k6)

print("7. freeze detector names weirdperformance's collector")
cmd("pressure 100")
cmd("hitch")
while W.sweeping do frame(0.1, 200) end
play(1)
while heap() < W.thr - 96 and not W.sweeping do frame(0.1, 16) end  -- creep up to the threshold...
now = now + 0.4                                   -- ...and cross it inside a long frame
frame(0.05, 200)
local f = lastMatch("freeze")
check("freeze names weirdperformance", string.find(f, "weirdperformance") ~= nil or string.find(f, "GentleGC collection") ~= nil)
cmd("hitch 0")

print(FAILED and "SOME TESTS FAILED" or "ALL TESTS PASSED")
