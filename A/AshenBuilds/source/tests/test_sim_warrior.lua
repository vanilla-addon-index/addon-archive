-- Warrior simulator: results, armor, Protection, set bonuses and memory use.
local AB, S = AshenBuilds, AshenSim
local W = S.Warrior

local function Build(race, items, talents, enchants)
  local b = AB.NewBuildData("Test"); AB.EnsureTalents(b)
  b.class = "Warrior"; b.race = race; b.level = 60; b.items = items; b.enchants = enchants or {}
  local data = AB:GetTalentData("Warrior")
  for ti = 1, 3 do for i = 1, table.getn(data[ti]) do
    local n = data[ti][i].name
    if talents[n] then b.talents.points[AB:GetTalentKey(ti, i)] = math.min(talents[n], table.getn(data[ti][i].ranks)) end
  end end
  return b
end

-- Pre-raid dual-wield Fury; compared against thrunk112's WarriorSim-TurtleWoW (626.9 DPS
-- with its 12 s Recklessness, 631.1 here with the same; 637.1 with the DB's 15 s).
local fury = Build("Human",
  {HEAD = 12640, NECK = 15411, SHOULDER = 12927, BACK = 13340, CHEST = 11726, WRIST = 12936, HANDS = 14551, WAIST = 13959,
   LEGS = 15062, FEET = 14616, FINGER1 = 17713, FINGER2 = 13098, TRINKET1 = 11815, TRINKET2 = 13965, MAINHAND = 12940, OFFHAND = 15806},
  {["Improved Heroic Strike"] = 3, ["Tactical Mastery"] = 5, ["Deep Wounds"] = 3, ["Impale"] = 2, ["Cruelty"] = 5, ["Unbridled Wrath"] = 5,
   ["Dual Wield Specialization"] = 5, ["Improved Execute"] = 2, ["Enrage"] = 5, ["Death Wish"] = 1, ["Flurry"] = 5, ["Bloodthirst"] = 1,
   ["Improved Berserker Rage"] = 2, ["Improved Shouts"] = 5},
  {MAINHAND = 10, OFFHAND = 10})
local cfg = W.DefaultSettings(); cfg.buffs.bom = nil; cfg.buffs.gbom = true
local char = W.BuildCharacter(fury, cfg)
check("character builds", char ~= nil)
check("racial +3 sword skill", char.mh.skill == 310)
check("crit matches the reference (28%)", math.abs(char.critBase + 180 * char.agiCrit - 28) < 0.01 or math.abs(char.critBase + char.baseAgi * 1.1 * char.agiCrit - 28) < 1.5)
local acc = W.Accuracy(char, cfg)
check("accuracy HIGH with everything simulated", acc == "HIGH")

S.RunBatch(W, char, cfg, 10, 99)
collectgarbage(); collectgarbage("stop")
local before = collectgarbage("count")
local sum = S.RunBatch(W, char, cfg, 1000, 12345)
local kb = collectgarbage("count") - before
collectgarbage("restart")
local mean, sd, lo, hi = S.Stats(sum)
check(string.format("DW Fury result unchanged (%.1f, expected 637.1)", mean), math.abs(mean - 637.1) < 0.5)
check(string.format("little garbage per fight (%.1f KB)", kb / 1000), kb / 1000 < 60)
check("confidence interval is narrow", hi - lo < 10)
local again = S.Stats(S.RunBatch(W, char, cfg, 1000, 12345))
check("same seed, same result", again == mean)

-- Armor vs the Turtle raid boss armor sheet.
local function Armor(debuffs, base) local c = W.DefaultSettings(); c.targetArmor = base or 4211; c.debuffs = debuffs; return W.BuildCharacter(fury, c).targetArmor end
check("4211, Sunder+FF+CoR = 816", Armor({sunder = true, faerie = true, cor = true}) == 816)
check("4211, IEA+FF+CoR = 516", Armor({iea = true, faerie = true, cor = true}) == 516)
check("4211, IEA+FF+CoR+Annihilator = 216", Armor({iea = true, faerie = true, cor = true, annihilator = true}) == 216)
check("4611, Sunder+FF+CoR = 1216", Armor({sunder = true, faerie = true, cor = true}, 4611) == 1216)
check("Annihilator proc is 100 armor per stack", S.ProcAuras.Annihilator.armor == 100)

-- Deep Protection with a shield: Shield Slam, Revenge off the boss's swings.
local prot = Build("Tauren",
  {HEAD = 16963, NECK = 18404, SHOULDER = 16961, BACK = 61010, WRIST = 16959, HANDS = 16964, WAIST = 19137, LEGS = 16962, FEET = 16965,
   FINGER1 = 17063, FINGER2 = 18821, TRINKET1 = 19406, TRINKET2 = 19431, MAINHAND = 19019, OFFHAND = 19349},
  {["Tactical Mastery"] = 5, ["Improved Heroic Strike"] = 3, ["Deep Wounds"] = 3, ["Cruelty"] = 5, ["Unbridled Wrath"] = 5,
   ["Improved Shouts"] = 5, ["Shield Specialization"] = 5, ["Anticipation"] = 3, ["Toughness"] = 5, ["Improved Revenge"] = 3,
   ["Reprisal"] = 2, ["One-Handed Weapon Specialization"] = 5, ["Shield Slam"] = 1, ["Improved Shield Slam"] = 2, ["Concussion Blow"] = 1})
local pcfg = W.DefaultSettings()
local pchar = W.BuildCharacter(prot, pcfg)
local pacc, reasons, rot = W.Accuracy(pchar, pcfg)
check("shield picks the Protection preset", rot.key == "prot")
check("Battlegear of Wrath 3 adds 30 Battle Shout AP", pchar.set.battleShout == 30)
check("Battlegear of Wrath 5 simulated (accuracy HIGH)", pacc == "HIGH")
local psum = S.RunBatch(W, pchar, pcfg, 200, 1)
check("Shield Slam is cast", (psum.sources["Shield Slam"] or {casts = 0}).casts / psum.n > 15)
check("Revenge follows blocks, dodges and parries", (psum.sources["Revenge"] or {casts = 0}).casts / psum.n > 10)
check("boss swings give rage", (psum.counters["rage.gen.damageTaken"] or 0) > 0)

-- Armor of Wrath: +5 weapon skill (5) and Overpower attack speed (3).
local aow = {MAINHAND = 19019, OFFHAND = 19349}
for _, it in ipairs(AB.SetCatalog[674].items) do
  local item = AB:GetItem(it[1]); local slot = item and (AB:ResolveSlotForItem(item) or item.slot)
  if slot and not aow[slot] then aow[slot] = it[1] end
end
local wrath = Build("Tauren", aow, {["Tactical Mastery"] = 5, ["Improved Overpower"] = 2, ["Shield Slam"] = 1, ["Flurry"] = 5})
local wcfg = W.DefaultSettings(); wcfg.rotation = "custom"; wcfg.custom = {["Overpower"] = true, ["Shield Slam"] = true, ["Bloodrage"] = true}
local wchar = W.BuildCharacter(wrath, wcfg)
check("Armor of Wrath 5: +5 weapon skill", wchar.mh.skill == wchar.mh.sheetSkill + 5)
local wsum = S.RunBatch(W, wchar, wcfg, 200, 1)
check("Armor of Wrath 3: Overpower attack speed buff has uptime", (wsum.uptime["Overpowering Rage"] or 0) > 0)
check("Overpower reacts to dodges", (wsum.sources["Overpower"] or {casts = 0}).casts > 0)
