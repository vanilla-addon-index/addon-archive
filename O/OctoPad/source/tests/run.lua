--[[ OctoPad offline logic tests

Runs the add-on's pure logic outside the game against a stub WoW API.

  cd OctoPad-dev
  lua tests/run.lua          (Lua 5.1 or newer; the add-on itself targets the game's Lua 5.0)

Covered: settings migrations, Console Experience Jump / Interact per controller style, window adapter matching,
the known-spell table.  Not covered: anything that needs real frames, the HUD or the game's tooltips.
]]

-- Lua 5.0 compatibility for newer interpreters
table.getn = table.getn or function(t) return #t end
math.mod = math.mod or math.fmod
local unpack = unpack or table.unpack

-- stub WoW API: unknown globals are callable no-op objects
local function Stub()
  local s = {}
  setmetatable(s, {
    __index = function(t, k) return Stub() end,
    __call = function() return nil end,
  })
  return s
end
local frames = {}
local function NewFrame()
  local f = { scripts = {} }
  setmetatable(f, { __index = function(t, k)
    if k == "SetScript" then return function(self, n, fn) self.scripts[n] = fn end end
    if k == "GetScript" then return function(self, n) return self.scripts[n] end end
    return function() return nil end
  end })
  table.insert(frames, f)
  return f
end
CreateFrame = function() return NewFrame() end
UIParent, WorldFrame, GameTooltip, DEFAULT_CHAT_FRAME = NewFrame(), NewFrame(), NewFrame(), NewFrame()
DEFAULT_CHAT_FRAME.AddMessage = function() end
SlashCmdList, UISpecialFrames, StaticPopupDialogs = {}, {}, {}
getglobal = function(n) return _G[n] end
setglobal = function(n, v) _G[n] = v end
GetTime = function() return 0 end
UnitName = function() return "Tester" end
GetRealmName = function() return "Test" end
-- globals that must read as "not there" (optional add-ons, client extensions, saved variables)
local ABSENT = { OctoPadDB = 1, pfUI = 1, pfUI_config = 1, SUPERWOW_VERSION = 1, UnitXP = 1, InteractNearest = 1,
                 ConsoleExperience = 1, CE = 1, Bagshui = 1, OctoPadMenu = 1 }
setmetatable(_G, { __index = function(t, k)
  if ABSENT[k] then return nil end
  if type(k) == "string" and string.find(k, "^%u") then return Stub() end      -- WoW API functions / frames
  return nil
end })

local function load(file)
  local f = assert(loadfile("OctoPad/" .. file))
  f()
end
load("OctoPad.lua")
load("OctoPadSpells.lua")
load("OctoPadAdapters.lua")

local OP = OctoPad
local fails, passes = 0, 0
local function eq(name, got, want)
  if got == want then passes = passes + 1
  else fails = fails + 1 print("FAIL " .. name .. ": got " .. tostring(got) .. ", want " .. tostring(want)) end
end

-- fire ADDON_LOADED with old-style settings
OctoPadCharDB = { keycaps = "auto", cursor = true, ui = { [3] = "UI_CURSOR" }, slots = {}, aggro = true }
event, arg1 = "ADDON_LOADED", "OctoPad"
for _, f in ipairs(frames) do
  if f.scripts.OnEvent then f.scripts.OnEvent() end
end
local cfg = OP.cfg
eq("cfg loaded", cfg ~= nil, true)
eq("migration: cursor dropped", cfg.cursor, nil)
eq("migration: UI_CURSOR dropped", cfg.ui[3], nil)
eq("migration: keycaps auto -> chevron", cfg.keycaps, "chevron")
eq("migration: aggro moved out", cfg.aggro, nil)
eq("migration: smartcat", cfg.smartcat and cfg.smartcat.buffs, true)
eq("schema", cfg.schema, table.getn(OP.MIGRATIONS))

-- running migrations again changes nothing
cfg.keycaps = "retro"
OP.Migrate(cfg)
eq("migrations run once", cfg.keycaps, "retro")

-- Console Experience defaults per controller style
local ce = OP.PROFILES.ce
cfg.style = "xbox"     eq("xbox A = Jump", ce[1], "JUMP")       eq("xbox X = Interact", ce[2], "INTERACT")
cfg.style = "ps"       eq("ps Cross = Jump", ce[1], "JUMP")     eq("ps Square = Interact", ce[2], "INTERACT")
cfg.style = "switch"   eq("switch X (top) = Jump", ce[3], "JUMP") eq("switch A (right) = Interact", ce[4], "INTERACT")
cfg.style = "switchn"  eq("switchn X = Jump", ce[2], "JUMP")    eq("switchn A = Interact", ce[1], "INTERACT")
eq("LT+LB = Sit", ce[20], "SITSTAND")
eq("RT+RB = Auto-run", ce[29], "AUTORUN")
eq("RT+LB no longer Interact", ce[30], nil)

-- adapters
eq("only: exact name", OP.AdapterMatch(OP.Adapters.QuestFrame.only, "QuestFrameAcceptButton"), true)
eq("only: pattern", OP.AdapterMatch(OP.Adapters.QuestFrame.only, "QuestRewardItem3"), true)
eq("only: close button excluded", OP.AdapterMatch(OP.Adapters.QuestFrame.only, "QuestFrameCloseButton"), false)
local adv = OP.AdapterAdvance("ClassTrainerSkill4")
eq("advance: trainer skill -> Train", adv and adv[2][1], "ClassTrainerTrainButton")
eq("advance: Craft pattern does not match CraftCreateButton", OP.AdapterAdvance("CraftCreateButton"), nil)
local mail = OP.AdapterAdvance("MailItem2Button")
eq("advance: mail -> take item", mail and mail[2][1], "OpenMailPackageButton")

-- known spells
eq("Heroic Strike is harmful", OP.SPELL_KIND["heroic strike"], "harm")
eq("Battle Shout not forced", OP.SPELL_KIND["battle shout"], nil)
eq("Flash Heal is helpful", OP.SPELL_KIND["flash heal"], "help")
eq("Holy Shock left to the tooltip", OP.SPELL_KIND["holy shock"], nil)

print(string.format("%d passed, %d failed", passes, fails))
if fails > 0 then os.exit(1) end
