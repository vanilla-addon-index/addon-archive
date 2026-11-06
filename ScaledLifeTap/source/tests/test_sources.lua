local SLT, BS = arg[1], arg[2]
dofile("tests/mockwow.lua")
local clock = 0
function GetTime() return clock end
local fails = 0
local function check(name, cond, extra)
  print((cond and "PASS " or "FAIL ") .. name .. (extra and ("  " .. extra) or ""))
  if not cond then fails = fails + 1 end
end
dofile(SLT .. "/Locale.lua"); dofile(SLT .. "/Scanner.lua"); dofile(SLT .. "/ScaledLifeTap.lua")
MOCK.fire("VARIABLES_LOADED"); MOCK.fire("PLAYER_ENTERING_WORLD")
MOCK.gear = MOCK.SAMPLE_GEAR
MOCK.spellbook = { {"Life Tap","Rank 1"}, {"Life Tap","Rank 2"}, {"Life Tap","Rank 3"}, {"Life Tap","Rank 4"}, {"Life Tap","Rank 5"}, {"Life Tap","Rank 6"} }
MOCK.fire("SPELLS_CHANGED")

local t, d, s, src, live = ScaledLifeTap_GetDamageBonus()
check("no mods -> built-in scanner, 518", src == "built-in scanner" and t == 518 and not live, src .. " " .. t)

function GetNampowerVersion() return 4, 5, 0 end
function GetSpellPower() return 0, 600, 600, 600, 600, 650, 600 end  -- shadow 650 (6th)
t, d, s, src, live = ScaledLifeTap_GetDamageBonus()
check("Nampower present -> uses 6th value (shadow 650)", src == "Nampower" and t == 650 and live, src .. " " .. t)

function GetSpellBonusDamage(school) return school == 6 and 700 or 1 end
t, d, s, src = ScaledLifeTap_GetDamageBonus()
check("ClassicAPI preferred over Nampower (700)", src == "ClassicAPI" and t == 700, src .. " " .. t)

SLT_Config.source = "nampower"
t, d, s, src = ScaledLifeTap_GetDamageBonus()
check("forced source nampower", src == "Nampower" and t == 650)
SLT_Config.source = "classicapi"; GetSpellBonusDamage = function() error("not in world") end
t, d, s, src = ScaledLifeTap_GetDamageBonus()
check("erroring source falls back through auto order", src == "Nampower" and t == 650, src)
GetSpellBonusDamage = nil; SLT_Config.source = "auto"

-- Nampower GetSpellPower returning nil (no player object) -> next source
local gsp = GetSpellPower; GetSpellPower = function() return nil end
t, d, s, src = ScaledLifeTap_GetDamageBonus()
check("Nampower nil -> built-in", src == "built-in scanner", src)
GetSpellPower = gsp

-- mana check: server gives 90% of predicted
function GetSpellNameAndRankForId(id) if id == 11689 then return "Life Tap", "Rank 6" end return "Shadow Bolt", "Rank 1" end
check("energize event registered", ScaledLifeTapEventFrame.events["SPELL_ENERGIZE_BY_SELF"] == true)
MOCK.echo = false
for i = 1, 12 do
  MOCK.hp, MOCK.mana = 3500, 1000; MOCK.casts = {}
  ScaledLifeTap_CastLifeTap()
  -- predicted with factor; base = 424+0.8*650 = 944 * 1.2 = 1132.8 ; server gives 90%
  MOCK.fire("SPELL_ENERGIZE_BY_SELF")  -- no args: ignored safely
  this, event, arg1, arg2, arg3, arg4, arg5 = ScaledLifeTapEventFrame, "SPELL_ENERGIZE_BY_SELF", "g", "g", 11689, 0, 1132.8 * 0.9
  ScaledLifeTapEventFrame.scripts.OnEvent()
  clock = clock + 5
end
check("correction converges near 0.90", math.abs(SLT_Config.gainFactor - 0.9) < 0.01, string.format("%.3f", SLT_Config.gainFactor))

-- other spells' energize ignored
local before = SLT_Config.gainFactor
ScaledLifeTap_CastLifeTap()
this, event, arg1, arg2, arg3, arg4, arg5 = ScaledLifeTapEventFrame, "SPELL_ENERGIZE_BY_SELF", "g", "g", 1, 0, 50
ScaledLifeTapEventFrame.scripts.OnEvent()
check("non-Life Tap energize ignored", SLT_Config.gainFactor == before)
-- stale event (>3s) ignored
clock = clock + 10
this, event, arg1, arg2, arg3, arg4, arg5 = ScaledLifeTapEventFrame, "SPELL_ENERGIZE_BY_SELF", "g", "g", 11689, 0, 500
ScaledLifeTapEventFrame.scripts.OnEvent()
check("stale energize ignored", SLT_Config.gainFactor == before)

-- correction changes rank choice: missing 1050 mana. Uncorrected r6 gain 1133 (doesn't fit); corrected ~1020 fits
MOCK.hp, MOCK.mana = 3500, 5000 - 1050; MOCK.casts = {}
ScaledLifeTap_CastLifeTap()
check("corrected gain lets rank 6 fit 1050 missing mana", MOCK.casts[1] == "id:6", tostring(MOCK.casts[1]))
SlashCmdList["SCALEDLIFETAP"]("calibrate reset")
check("calibrate reset", SLT_Config.gainFactor == 1 and SLT_Config.samples == 0)
MOCK.hp, MOCK.mana = 3500, 5000 - 1050; MOCK.casts = {}
ScaledLifeTap_CastLifeTap()
check("after reset rank 6 no longer fits -> rank 5", MOCK.casts[1] == "id:5", tostring(MOCK.casts[1]))
for _, c in ipairs({"", "status", "calibrate off", "calibrate", "source classicapi", "source auto"}) do SlashCmdList["SCALEDLIFETAP"](c) end
check("new slash commands run", SLT_Config.calibrate == true and SLT_Config.source == "auto")
-- both ClassicAPI and Nampower running (the usual setup)
SlashCmdList["SCALEDLIFETAP"]("calibrate reset")
function GetSpellBonusDamage(school) return school == 6 and 650 or 0 end   -- same field as GetSpellPower
t, d, s, src = ScaledLifeTap_GetDamageBonus()
check("both mods: ClassicAPI supplies spell damage", src == "ClassicAPI" and t == 650, src .. " " .. t)
for i = 1, 12 do
  MOCK.hp, MOCK.mana = 3500, 1000
  ScaledLifeTap_CastLifeTap()
  this, event, arg1, arg2, arg3, arg4, arg5 = ScaledLifeTapEventFrame, "SPELL_ENERGIZE_BY_SELF", "g", "g", 11689, 0, 1132.8 * 0.9
  ScaledLifeTapEventFrame.scripts.OnEvent()
  clock = clock + 5
end
check("both mods: Nampower mana check still learns", math.abs(SLT_Config.gainFactor - 0.9) < 0.01, string.format("%.3f", SLT_Config.gainFactor))
MOCK.loaded = { BonusScanner = true }; BonusScanner = { GetBonus = function() return 0 end }
t, d, s, src = ScaledLifeTap_GetDamageBonus()
check("both mods + BonusScanner returning 0: still ClassicAPI", src == "ClassicAPI" and t == 650)
GetSpellBonusDamage, GetSpellPower = nil, nil
t, d, s, src = ScaledLifeTap_GetDamageBonus()
check("no mods + BonusScanner returning 0 (DE/FR case): built-in used, not 0", src == "built-in scanner" and t > 0, src .. " " .. t)
print(fails == 0 and "ALL TESTS PASSED" or (fails .. " FAILED"))
