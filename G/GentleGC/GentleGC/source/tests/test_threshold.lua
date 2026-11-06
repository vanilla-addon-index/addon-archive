-- Threshold changes by other addons, the pressure guard, and the pause vs
-- garbage-freed estimate. Simulates the 1.12 client's collector (1.25x).
-- Run: lua5.0 tests/test_threshold.lua GentleGC.lua
format = string.format
local now = 1000
function GetTime() return now end
function UnitAffectingCombat() return false end
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
local caller = nil
function debugstack()
  local s = "Interface\\AddOns\\GentleGC\\GentleGC.lua:400: in function `WrappedCollect'\n"
  if caller then s = s .. "Interface\\AddOns\\" .. caller .. "\\core.lua:12: in function `x'\n" end
  return s
end

-- the client's collector: full collections leave the threshold at 1.25x live,
-- and take 10 ms + 8 ms per MB freed (simulated on the clock)
local origCG = collectgarbage
local function setThreshold() local u = gcinfo(); origCG(math.floor(u * 1.25)) end
local timed = false
collectgarbage = function(n)
  if n == nil or n == 0 then
    local before = gcinfo()
    origCG(); setThreshold()
    if timed then now = now + 0.010 + 0.008 * (before - gcinfo()) / 1024 end
  else
    origCG(n)
  end
end
local unwrapped = collectgarbage   -- what an addon holds if it loaded before us

LIVE = {}
for i = 1, 300000 do LIVE[i] = { i } end
origCG(); setThreshold()

dofile(arg[1])
local F = FRAMES[1]
event, arg1 = "ADDON_LOADED", "GentleGC"; this = F; F.scripts.OnEvent()
local SF = FRAMES[4]
local cmd = SlashCmdList.GENTLEGC
cmd("debug 2")

local function count(pat) local n = 0; for _, m in ipairs(log) do if string.find(m, pat) then n = n + 1 end end; return n end
local function lastMatch(pat) for i = table.getn(log), 1, -1 do if string.find(log[i], pat) then return log[i] end end; return "" end
local function check(name, c) print((c and "PASS " or "FAIL ") .. name); if not c then FAILED = true end end
local function frame(dt) now = now + dt; SF.scripts.OnUpdate(); arg1 = dt; this = F; F.scripts.OnUpdate() end
local function seconds(n) for i = 1, n * 10 do frame(0.1) end end
local function garbageMB(mb) local t = {}; for i = 1, mb * 7000 do t[i] = { i, i } end end

print("1. the login case: an addon leaves the threshold just above the heap")
cmd("now")                       -- ratio measured, live known
seconds(40)
local used = gcinfo()
unwrapped(used + 300)            -- threshold 0.3 MB above the heap, no collection
seconds(6)
check("logged as a threshold change, not a collection", string.find(lastMatch("threshold set to"), "by unknown addon") ~= nil)
check("no pressure collection for nothing", count("pressure:") == 0)
cmd("status")
check("status lists it", string.find(lastMatch("threshold set without collecting"), "unknown addon 1") ~= nil)

print("2. a wrapped addon setting the threshold is named")
caller = "FpsWatch"
collectgarbage(gcinfo() + 500)
caller = nil
check("named in the log", string.find(lastMatch("threshold set to"), "by FpsWatch") ~= nil)
origCG(); setThreshold()         -- the game collects at that threshold
seconds(2)

print("3. a game collection that frees under 1 MB is still a collection")
local autoBefore = count("automatic GC detected")
do
  local _, t = gcinfo()
  local junk, i = {}, 0
  while gcinfo() < t * 0.995 do
    for k = 1, 200 do i = i + 1; junk[i] = { i } end
    SF.scripts.OnUpdate()
  end
  junk = nil
end
origCG(); setThreshold()
seconds(1)
check("detected as automatic", count("automatic GC detected") == autoBefore + 1)
check("not reported as a threshold change", count("threshold set to") == 2)

print("4. pressure with real garbage still collects")
now = now + 40
local l, t = gcinfo()
do
  local junk, i = {}, 0
  while gcinfo() < l + (t - l) * 0.85 do
    for k = 1, 300 do i = i + 1; junk[i] = { i } end
    if i > 20000 then junk = {}; i = 0 end
    SF.scripts.OnUpdate()
  end
end
seconds(2)
check("pressure collection ran", count("pressure:") == 1)
check("it freed garbage", string.find(lastMatch("pressure:"), "freed [1-9]") ~= nil)

print("5. pause vs garbage freed")
timed = true
cmd("slow 0")
for k, mb in ipairs({ 1, 4, 8, 12, 16, 20, 25 }) do
  now = now + 40
  origCG(gcinfo() + 64 * 1024)   -- room for this much garbage without the test Lua collecting on its own
  seconds(1)
  garbageMB(mb)
  cmd("now")
end
cmd("status")
local line = lastMatch("pause vs garbage freed")
local _, _, a, b = string.find(line, "~(%-?%d+)ms %+ ([%d%.]+)ms per MB")
a, b = tonumber(a), tonumber(b)
check("model shown", a ~= nil and b ~= nil)
check("fixed part ~10 ms", a and a >= 0 and a <= 25)
check("per-MB part ~8 ms", b and b >= 6.5 and b <= 9.5)

print("6. an addon loaded before GentleGC turns collectgarbage() into 'threshold just above the heap'")
-- (the 0.0-0.3 MB "pressure" collections every few seconds)
FRAMES = {}
log = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) table.insert(log, m); print("  " .. m) end }
GentleGCDB = nil
SlashCmdList = {}
local client = collectgarbage
collectgarbage = function(n)
  caller = "FpsWatch"            -- this wrapper's frame is on the stack while it runs
  if n == nil or n == 0 then
    client(gcinfo() + 200)       -- no collection: threshold 0.2 MB above the heap
  else
    client(n)
  end
  caller = nil
end
timed = false
origCG(); setThreshold()
dofile(arg[1])
F = FRAMES[1]
event, arg1 = "ADDON_LOADED", "GentleGC"; this = F; F.scripts.OnEvent()
SF = FRAMES[4]
cmd = SlashCmdList.GENTLEGC
cmd("debug 1")
garbageMB(6)
cmd("now")
check("reported once", count("didn't run a normal collection") == 1)
check("names the wrapping addon", string.find(lastMatch("didn't run a normal collection"), "wrapped by FpsWatch") ~= nil)
seconds(30)
check("no repeated pressure attempts", count("pressure:") == 0)
cmd("status")
check("status shows the wrapper", string.find(lastMatch("collectgarbage is wrapped"), "by FpsWatch; 1 of") ~= nil)
check("not counted as a collection", string.find(lastMatch("session:"), "0 collections") ~= nil)
check("ratio not learned from it", count("not measured yet") == 1)

print(FAILED and "SOME TESTS FAILED" or "ALL TESTS PASSED")
