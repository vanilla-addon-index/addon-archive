-- weirdperformance cycles: a heap drop with the threshold reset by the normal rule is not an unknown addon.
-- Simulates the 1.12 client's collector (1.25x).
-- Run: lua5.0 tests/test_wp_minor.lua GentleGC.lua
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

function GetWeirdUtilsVersion(m)
  if m == "weirdperformance" then return "1.2.1" end
  return { weirdperformance = "1.2.1" }
end
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
local function clear() log = {} end
local function has(pat) return count(pat) > 0 end

-- room above the heap so the real Lua collector doesn't fire while we allocate
local function roomy() origCG(gcinfo() + 200000) end

seconds(40)
roomy()
seconds(2)
local _, T = gcinfo()

print("1. heap drops, threshold back at the normal rule: a weirdperformance cycle")
clear()
GARB = {}
for i = 1, 6 * 7000 do GARB[i] = { i, i } end
seconds(1)                       -- the per-frame sample sees the grown heap
GARB = nil
origCG()                         -- frees it (and moves the threshold, as any collection does)
origCG(math.floor(gcinfo() * 1.25))   -- threshold reset by the normal rule, as weirdperformance's shrink does
seconds(2)
check("recognized as a minor sweep", has("weirdperformance cycle: freed"))
check("not counted as an unknown addon", not has("collection by unknown addon"))
check("not counted as an automatic collection", not has("automatic GC detected"))
cmd("status")
check("status counts it", has("weirdperformance minor sweeps: 1,"))
check("not in 'by other addons'", not has("by other addons"))

print("2. heap drops and the threshold moves too: still an unknown collection, now with the numbers")
roomy()
seconds(2)
_, T = gcinfo()
clear()
GARB = {}
for i = 1, 6 * 7000 do GARB[i] = { i, i } end
seconds(1)
GARB = nil
origCG()                         -- threshold left where the collection put it (2x live)
seconds(2)
check("unknown addon, as before", has("collection by unknown addon"))
check("with heap and threshold numbers", string.find(lastMatch("collection by unknown addon"), "%[heap [%d%.]+ %-> [%d%.]+mb, threshold [%d%.]+ %-> [%d%.]+mb%]") ~= nil)
cmd("status")
check("listed under other addons", has("by other addons: 1"))

print("3. a drop of a few KB is not counted")
roomy()
seconds(2)
clear()
GARB = {}
for i = 1, 300 do GARB[i] = { i } end
seconds(1)
GARB = nil
origCG(); origCG(math.floor(gcinfo() * 1.25))
seconds(2)
check("tiny drop not printed as a cycle", not has("weirdperformance cycle: freed"))
check("tiny drop not an unknown addon", not has("collection by unknown addon"))

print(FAILED and "SOME TESTS FAILED" or "ALL TESTS PASSED")
