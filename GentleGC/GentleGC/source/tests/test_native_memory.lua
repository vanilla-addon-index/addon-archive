-- Native per-addon memory (ClassicAPI), the companion fallback, and the client info lines.
-- Run: lua5.0 tests/test_native_memory.lua GentleGC.lua

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
local function clear() log = {} end
local function has(pat) return count(pat) > 0 end

print("1. without ClassicAPI's functions: the companion is asked for")
clear()
cmd("addons")
check("explains the companion", has("per%-addon memory needs"))
cmd("addons measure")
check("measure falls through to the companion text", has("per%-addon memory needs"))

-- a stand-in for ClassicAPI's profiling functions
local names = {}
local kbs = {}
local ADDONS = 20
for i = 1, ADDONS do names[i] = "Addon" .. i; kbs[i] = i * 100 end        -- 100 KB .. 2000 KB
names[21] = "Blizzard_Thing"; kbs[21] = 0                                  -- Blizzard / not loaded: 0
local updates = 0
function GetNumAddOns() return table.getn(names) end
function GetAddOnInfo(i) return names[i] end
function UpdateAddOnMemoryUsage() updates = updates + 1 end
function GetAddOnMemoryUsage(i)
  if i < 1 or i > table.getn(names) then error("bad index") end
  return kbs[i]
end

print("2. with them: a live list, biggest first, top 15")
clear()
cmd("addons")
check("one update per listing", updates == 1)
check("header says where it comes from", has("addon memory now %(from ClassicAPI%)"))
check("total counts the 20 loaded addons", has("in 20 addons"))
check("zero rows (not loaded) are left out", not has("Blizzard_Thing"))
check("biggest is first", string.find(log[2], "Addon20") ~= nil)
check("15 rows shown", count("Addon%d+") == 15)
check("says how many more", has("and 5 more"))
check("no growth on the first check", not has("since the last check"))

print("3. 'all' lists every addon")
clear()
cmd("addons all")
check("20 rows", count("Addon%d+") == 20)

print("4. growth since the last check is shown")
kbs[3] = kbs[3] + 3000
kbs[4] = kbs[4] + 50          -- under 100 KB: not worth a note
clear()
cmd("addons all")
check("Addon3 grew", string.find(lastMatch("Addon3 "), "%+2%.9 MB since the last check") ~= nil or string.find(lastMatch("Addon3"), "since the last check") ~= nil)
check("Addon4's small change is not flagged", string.find(lastMatch("Addon4 "), "since the last check") == nil)

print("5. measure is not needed")
clear()
cmd("addons measure")
check("says so", has("no measuring needed"))

print("6. a client where the update call errors falls back")
local good = UpdateAddOnMemoryUsage
function UpdateAddOnMemoryUsage() error("nope") end
clear()
cmd("addons")
check("falls back to the companion text", has("per%-addon memory needs"))
UpdateAddOnMemoryUsage = good

print("7. everything reporting 0 falls back")
local saved = {}
for i = 1, table.getn(kbs) do saved[i] = kbs[i]; kbs[i] = 0 end
clear()
cmd("addons")
check("falls back", has("per%-addon memory needs"))
for i = 1, table.getn(kbs) do kbs[i] = saved[i] end

print("8. client info lines in /ggc")
clear()
cmd("status")
check("no cvar function: no client lines", not has("client:"))
local cvars = { scriptMemory = "0", scriptProfile = "0" }
function GetCVar(k) return cvars[k] end
-- the slash command prints them after the status block
clear()
cmd("status")
check("limit off", has("client: interface memory limit off"))
check("profiling off prints no warning", not has("CPU profiling is ON"))
cvars.scriptMemory = "65536"; cvars.scriptProfile = "1"
clear()
cmd("status")
check("limit shown", has("interface memory limit 64.0 MB"))
check("profiling warning", has("CPU profiling is ON"))

print(FAILED and "SOME TESTS FAILED" or "ALL TESTS PASSED")
