-- Unattributed collections and threshold changes name the game event just before them.
-- Simulates the 1.12 client's collector (1.25x).
-- Run: lua5.0 tests/test_unknown_context.lua GentleGC.lua
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
local function fire(e) event, arg1 = e, nil; this = F; F.scripts.OnEvent() end

print("1. a threshold set by nobody we can name, right after a game event")
cmd("now")
seconds(40)
fire("ZONE_CHANGED_NEW_AREA")
local used = gcinfo()
unwrapped(used + 300)
seconds(2)
check("names the event", string.find(lastMatch("threshold set to"), "by unknown addon %(after ZONE_CHANGED_NEW_AREA%)") ~= nil)
cmd("status")
check("status keeps the plain count", string.find(lastMatch("threshold set without collecting"), "unknown addon 1") ~= nil)
check("status lists the context", string.find(lastMatch("threshold changes came"), "after ZONE_CHANGED_NEW_AREA 1") ~= nil)

print("2. the same long after the last event")
seconds(60)
origCG(); setThreshold()
seconds(2)                       -- let the collection settle first
local u2 = gcinfo()
unwrapped(u2 + 300)
seconds(2)
check("says no recent event", string.find(lastMatch("threshold set to"), "%(no recent event%)") ~= nil)

print("3. an addon we can name is unchanged")
caller = "FpsWatch"
collectgarbage(gcinfo() + 500)
seconds(1)
check("named as before, no context", string.find(lastMatch("threshold set to"), "by FpsWatch %(heap") ~= nil)

print(FAILED and "SOME TESTS FAILED" or "ALL TESTS PASSED")
