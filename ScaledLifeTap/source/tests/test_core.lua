-- usage: lua50 test_slt.lua <slt dir> <bonusscanner dir>
local SLT, BS = arg[1], arg[2]
dofile("tests/mockwow.lua")
local clock = 0
function GetTime() return clock end
local fails = 0
local function check(name, cond, extra)
  print((cond and "PASS " or "FAIL ") .. name .. (extra and ("  " .. extra) or ""))
  if not cond then fails = fails + 1 end
end

-- load BonusScanner for parity reference
dofile(BS .. "/Localization.lua"); dofile(BS .. "/BonusScanner.lua")
MOCK.gear = MOCK.SAMPLE_GEAR
MOCK.makeBonusScannerFrames()
MOCK.fire("PLAYER_ENTERING_WORLD"); MOCK.tick(1.1)
local bsD, bsS = BonusScanner:GetBonus("DMG"), BonusScanner:GetBonus("SHADOWDMG")

-- load SLT v4
dofile(SLT .. "/Locale.lua"); dofile(SLT .. "/Scanner.lua"); dofile(SLT .. "/ScaledLifeTap.lua")
MOCK.fire("VARIABLES_LOADED"); MOCK.fire("PLAYER_ENTERING_WORLD")

-- 1. parity with BonusScanner on sample gear
SLT_Config.source = "internal"
local d, s = ScaledLifeTap_Scanner:Get()
check("built-in scanner matches BonusScanner on sample gear", d == bsD and s == bsS,
  string.format("built-in D=%d S=%d / BonusScanner D=%d S=%d", d, s, bsD, bsS))

-- 2. parity on assorted edge-case lines (each fed as its own item)
local cases = {
  {"x","+40 Shadow Spell Damage"}, {"x","Shadow Damage +20"}, {"x","+13 Spell Damage and Healing/+1 Stamina"},
  {"x","Minor Wizard Oil (30 min)"}, {"x","Lesser Wizard Oil"}, {"x","Wizard Oil"},
  {"x","Spell Damage +15 and +1% Spell Critical Strike"}, {"x","+20 Fire Spell Damage"},
  {"x","Equip: Increases damage done to Undead by magical spells and effects by up to 60."},
  {"x","Equip: Increases healing done by spells and effects by up to 44."},
  {"x","+10 Shadow Resistance"}, {"x","Use: Increases damage and healing done by magical spells and effects by up to 175 for 15 sec."},
  {"x","Set A (2/5)", "Set: Increases damage and healing done by magical spells and effects by up to 23.", "(4) Set: Increases damage and healing done by magical spells and effects by up to 99."},
}
for i, item in ipairs(cases) do
  MOCK.gear = { [1] = item }
  BonusScanner:ScanEquipment()
  ScaledLifeTap_Scanner:MarkDirty()
  local d2, s2 = ScaledLifeTap_Scanner:Get()
  local ok = d2 == tonumber(BonusScanner:GetBonus("DMG")) and s2 == tonumber(BonusScanner:GetBonus("SHADOWDMG"))
  check("parity: " .. item[2], ok, string.format("v4 D=%d S=%d / BS D=%d S=%d", d2, s2, BonusScanner:GetBonus("DMG"), BonusScanner:GetBonus("SHADOWDMG")))
end

-- set bonus counted once even when 3 pieces carry the same "Set:" line
MOCK.gear = {
  [1] = {"a","Set X (3/8)","Set: Increases damage and healing done by magical spells and effects by up to 23."},
  [3] = {"b","Set X (3/8)","Set: Increases damage and healing done by magical spells and effects by up to 23."},
  [5] = {"c","Set X (3/8)","Set: Increases damage and healing done by magical spells and effects by up to 23."},
}
ScaledLifeTap_Scanner:MarkDirty()
check("active set bonus counted once", (ScaledLifeTap_Scanner:Get()) == 23)

-- 3. lazy scanning: no rescans without inventory change; party events ignored
MOCK.gear = MOCK.SAMPLE_GEAR
ScaledLifeTap_Scanner:MarkDirty(); ScaledLifeTap_Scanner:Get()
MOCK.tooltipCalls = 0
for i = 1, 100 do ScaledLifeTap_Scanner:Get() end
check("100 casts with unchanged gear -> 0 rescans", MOCK.tooltipCalls == 0)
MOCK.fire("UNIT_INVENTORY_CHANGED", "party1"); ScaledLifeTap_Scanner:Get()
check("party member gear change ignored", MOCK.tooltipCalls == 0)
MOCK.fire("UNIT_INVENTORY_CHANGED", "player"); ScaledLifeTap_Scanner:Get()
check("player gear change -> exactly one rescan", MOCK.tooltipCalls == 17, MOCK.tooltipCalls .. " slot reads")
local hasOnUpdate = false
for _, fr in ipairs(MOCK.frames) do if fr.name and string.find(fr.name, "ScaledLifeTap") and fr.scripts.OnUpdate then hasOnUpdate = true end end
check("no OnUpdate handler", not hasOnUpdate)

-- 4. no Life Tap in spellbook: v3 would loop forever, v4 must return
MOCK.spellbook = { {"Shadow Bolt","Rank 1"} }
MOCK.fire("SPELLS_CHANGED"); MOCK.casts = {}
ScaledLifeTap_CastLifeTap()
check("no Life Tap learned: returns without casting", table.getn(MOCK.casts) == 0)

-- 5. rank selection
MOCK.spellbook = { {"Shadow Bolt","Rank 9"}, {"Life Tap","Rank 1"}, {"Life Tap","Rank 2"}, {"Life Tap","Rank 3"},
                   {"Life Tap","Rank 4"}, {"Life Tap","Rank 5"}, {"Life Tap","Rank 6"}, {"Corruption","Rank 7"} }
MOCK.fire("SPELLS_CHANGED")
SLT_Config.bonus = 0
-- bonus = 443+75 = 518; Imp LT 2/2 -> x1.2
-- r6: cost 424+0.8*518=838.4 gain 1006; r5: 724.4/869; r4 634.4/761; r3 554.4/665; r2 427.2/513; r1 226.8/272
local function cast(hp, mana)
  MOCK.hp, MOCK.mana = hp, mana; MOCK.casts = {}
  ScaledLifeTap_CastLifeTap()
  return MOCK.casts[1]
end
check("missing 4000 mana -> rank 6", cast(3500, 1000) == "id:7")
check("missing 900 mana -> rank 5", cast(3500, 4100) == "id:6")
check("missing 600 mana -> rank 2", cast(3500, 4400) == "id:3")
check("missing 100 mana, overtap on -> rank 1", cast(3500, 4900) == "id:2")
SLT_Config.overtap = false
check("missing 100 mana, overtap off -> nothing", cast(3500, 4900) == nil)
SLT_Config.overtap = true
check("full mana -> nothing", cast(3500, 5000) == nil)
check("low health (800) -> highest rank that leaves >0 hp (r5, 724)", cast(800, 1000) == "id:6")
check("health 200 -> nothing (would cost more than you have)", cast(200, 1000) == nil)
SLT_Config.reserve = 50
check("reserve 50% (1750) at 2300 hp -> r2 (r3 would leave 1745)", cast(2300, 1000) == "id:3")
SLT_Config.reserve = 0
MOCK.talents[1][5][2] = 0; MOCK.fire("CHARACTER_POINTS_CHANGED")
check("no Imp LT talent: missing 840 -> r6 fits exactly (838)", cast(3500, 4160) == "id:7")
MOCK.talents[1][5][2] = 2; MOCK.fire("CHARACTER_POINTS_CHANGED")

-- 6. source=auto uses BonusScanner when loaded
MOCK.loaded = { BonusScanner = true }
SLT_Config.source = "auto"
MOCK.gear = { [1] = {"x","+100 Spell Damage"} }
ScaledLifeTap_Scanner:MarkDirty()
BonusScanner:ScanEquipment()
local total, _, _, src = ScaledLifeTap_GetDamageBonus()
check("auto source skips BonusScanner (uses built-in)", src == "built-in scanner", src .. " " .. total)
SLT_Config.source = "bonusscanner"
total, _, _, src = ScaledLifeTap_GetDamageBonus()
check("forced source bonusscanner still works", src == "BonusScanner" and total == 100, src .. " " .. total)
SLT_Config.source = "auto"
MOCK.loaded = nil

-- 7. v3 saved variable migration
SLT_Config = { overtapEnabled = false }
MOCK.fire("VARIABLES_LOADED")
check("v3 overtapEnabled=false migrated", SLT_Config.overtap == false and SLT_Config.source == "auto")

-- 8. slash commands don't error
MOCK.echo = false
for _, c in ipairs({"", "status", "overtap", "debug on", "reserve 20", "bonus 40", "source internal", "rescan", "cast", "garbage"}) do
  SlashCmdList["SCALEDLIFETAP"](c)
end
check("slash commands run", SLT_Config.reserve == 20 and SLT_Config.bonus == 40 and SLT_Config.source == "internal")

-- 9. performance: built-in scan vs BonusScanner
MOCK.gear = MOCK.SAMPLE_GEAR
collectgarbage(); collectgarbage(1e9)
local N = 2000
local kb0, t0 = gcinfo(), os.clock()
for i = 1, N do ScaledLifeTap_Scanner:Scan() end
local tnew, knew = (os.clock() - t0) / N * 1e6, (gcinfo() - kb0) / N
collectgarbage(); collectgarbage(1e9)
kb0, t0 = gcinfo(), os.clock()
for i = 1, N do BonusScanner:ScanEquipment() end
local tbs, kbs = (os.clock() - t0) / N * 1e6, (gcinfo() - kb0) / N
print(string.format("PERF full gear scan: v4 built-in %.0f us, %.2f KB garbage | BonusScanner %.0f us, %.2f KB garbage", tnew, knew, tbs, kbs))
collectgarbage(); collectgarbage(1e9)
SLT_Config.source = "internal"; SLT_Config.debug = false
kb0, t0 = gcinfo(), os.clock()
for i = 1, 100000 do MOCK.mana = 1000; ScaledLifeTap_CastLifeTap() end
print(string.format("PERF cast with cached gear: %.2f us/press, %.3f KB garbage/press", (os.clock() - t0) / 100000 * 1e6, (gcinfo() - kb0) / 100000))

print(fails == 0 and "ALL TESTS PASSED" or (fails .. " FAILED"))
