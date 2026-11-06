-- Ashen Builds combat simulator: Warrior.
--
-- The builder is the source of truth: stats come from AB:GetDerivedStats (gear,
-- enchants, talents, race), weapons from the item database, talents by name.
-- The simulator only adds what the character sheet does not show: buffs, set
-- bonuses, procs, rage and the rotation.
--
-- Every mechanic below is registered with where its numbers come from (see the
-- status list at the top of SimCore.lua). "DB" means the Tortoise DB snapshot of
-- Turtle's server data; "reference" means thrunk112's WarriorSim-TurtleWoW.

AshenSim = AshenSim or {}
local S = AshenSim
local W = {}
S.Warrior = W
S.Models = S.Models or {}
S.Models.Warrior = W

local V, R, L, U = S.VERIFIED, S.REFERENCE, S.LIVE, S.UNKNOWN
local M = S.Mechanic
M("hit", R, "reference (turtle mode)", "Miss 5% + 0.2% per defense point above weapon skill, minus hit. Dual wield: x0.8 + 20%. A queued Heroic Strike uses the single-wield miss for the main hand.")
M("dodge", R, "reference", "5% + 0.1% per defense point above weapon skill.")
M("glance", R, "reference (turtle mode)", "10% + 2% per defense point above min(skill, level x5): 40% vs level 63. Damage x uniform(0.9-0.023d, 1.0-0.017d).")
M("crit", R, "reference", "Crit - 1% per target level above yours; +3% in Berserker Stance. White hits use one roll table; Bloodthirst/Execute roll crit separately.")
M("parry", L, "classic research", "Only when attacking from the front. Chance is a setting (default 14%); Turtle boss parry is not confirmed.")
M("armor", R, "reference", "Armor / (Armor + 400 + 85 x your level), capped at 75%.")
M("rage", L, "reference best estimate", "Turtle rage from damage is a fitted formula (damage/conversion x 7.5/1.075 + speed factor). Needs combat-log testing.")
M("rageDodge", L, "reference", "A dodged white swing gives 75% of the rage an average hit would.")
M("refund", R, "reference", "Missed or dodged abilities refund 80% of their cost (not Whirlwind or Execute).")
M("heroicStrike", V, "DB", "+157 damage at 60, 15 rage (-1/2/3 Improved Heroic Strike). Replaces the next main-hand swing.")
M("cleave", R, "reference/DB", "+50 damage, 20 rage (-1/2/3 Ravager), hits a second target.")
M("bloodthirst", V, "DB", "200 + 35% attack power, 30 rage, 6 sec cooldown.")
M("mortalStrike", V, "DB", "115/120/125/130% weapon damage by rank (130% at 60). The reference sim uses weapon damage + 130 instead.")
M("whirlwind", V, "DB", "Normalized main-hand damage, up to 4 targets, 25 rage, 10 sec cooldown (-1/1.5/2 sec Ravager).")
M("execute", R, "DB base / reference per-rage value", "600 + 15 per extra rage (x Precision Cut 25/50/75%); a hit uses all remaining rage. Last 20% of the fight by default.")
M("overpower", V, "DB", "+35 damage, normalized, cannot be dodged, 5 rage, 5 sec cooldown, only for 5 sec after a dodge, Battle Stance. +25/50% crit with Improved Overpower.")
M("slam", R, "DB cast time / reference swing handling", "100% weapon damage, 15 rage, 2.5 sec cast (-0.25/0.5 Improved Slam). Swings wait for the cast to finish.")
M("deepWounds", R, "DB duration / reference ticking", "20/40/60% of average main-hand damage over 6 sec (4 ticks). Each crit restarts it.")
M("flurry", V, "DB", "+10..30% attack speed for 3 swings or 15 sec after a crit. Only white swings use charges.")
M("unbridledWrath", L, "reference", "15% per rank to gain 1 rage from a white swing/Heroic Strike that lands; 2 rage with a two-hander.")
M("bloodrage", V, "DB", "10 rage (+5/10 Improved Bloodrage) at once and 10 more over 10 sec; 60 sec cooldown.")
M("enrage", L, "DB text / reference", "+4..20% damage for 8 sec. DB says after being crit; with no boss hits the reference triggers it from Bloodrage (setting).")
M("deathWish", V, "DB", "+20% physical damage for 30 sec, 10 rage, 3 min cooldown.")
M("recklessness", V, "DB", "+100% crit for 15 sec (reference uses 12), 30 min cooldown (-4/8/12 Improved Disciplines).")
M("berserkerRage", R, "reference", "Only used with Improved Berserker Rage (+5/10 rage). Triggers the global cooldown.")
M("battleShout", V, "DB", "232 attack power (+5% per Improved Shouts rank), 2 min (+12% per Booming Voice rank).")
M("masterOfArms", V, "DB", "Axe +1..5% crit; Mace ignores 1.2..6 armor per level; Sword 1..5% chance of an extra attack.")
M("weaponSpecs", V, "DB", "Two-Hand Spec +2..6% damage, One-Hand Spec +2..10%, Dual Wield Spec +5..25% off-hand damage and +2..10% off-hand hit.")
M("racials", V, "DB", "+3 weapon skill racials (builder), Night Elf Quickness +1% attack speed.")
M("procs", R, "reference/DB", "Chance-on-hit weapons, trinkets and enchants from the item proc table. Rates marked DB come from Turtle item data.")
M("stances", R, "reference", "Switching stance keeps rage up to Tactical Mastery; 1 sec stance cooldown. Defensive Stance -10% damage.")
M("sweepingStrikes", L, "assumed", "Next 5 abilities/main-hand swings hit a second target for the same damage.")
M("shieldSlam", R, "DB base/cost/cooldown, reference coefficients", "343-359 at 60 (DB), 20 rage, 6 sec cooldown (-0.75/1.5 Improved Shield Slam). Plus 2x block value + 20% attack power (reference; Turtle's coefficients are not in the DB).")
M("revenge", V, "DB", "82-100 at 60, 5 rage, 6 sec cooldown (-0.5/1/1.5 Improved Revenge), usable for 5 sec after you block, dodge or parry. Reprisal +25/50% damage and 50/100% chance to refund.")
M("concussionBlow", V, "DB", "235 at 60, ignores armor, 20 sec cooldown, no cost, generates 10 rage.")
M("sunderArmor", V, "DB", "450 armor per stack, 5 stacks, 30 sec, 10 rage. Only used when the Sunder debuff is not already assumed in the settings.")
M("tanking", L, "classic formulas + settings", "Boss swings at the speed and damage in the settings. Avoidance vs a level 63 boss = your sheet dodge/parry/block - 0.6%; 15% crushing blows; rage from damage taken = damage / conversion x 2.5 (reference). Shield Specialization +1..5 rage per block (DB).")
M("setBonuses", V, "DB", "Set bonus stats (attack power, crit, hit, strength, agility, weapon skill, attack speed) come from each bonus spell's effects; warrior set mechanics (procs, cost and damage changes) are implemented one by one with DB values. '+5 to All Weapons' is encoded as a skill 162 aura and is assumed to cover every weapon (needs live test).")
M("reaction", R, "reference", "Each decision waits a random reaction time (setting +/- 50 ms).")

local floor, max, min = math.floor, math.max, math.min

-- Counter names like "rage.gen.white" are built once and reused, so a running
-- simulation does not create new strings on every event.
local KEYS = {}
local function Key(prefix, name)
  local t = KEYS[prefix]
  if not t then t = {}; KEYS[prefix] = t end
  local k = t[name]
  if not k then k = prefix..name; t[name] = k end
  return k
end
local MISS, DODGE, PARRY, GLANCE, CRIT, HIT = "miss", "dodge", "parry", "glance", "crit", "hit"

-- Level 1-60 crit per point of agility for warriors (reference table).
local AGI_CRIT = {0.2500,0.2381,0.2381,0.2273,0.2174,0.2083,0.2083,0.2000,0.1923,0.1923,0.1852,0.1786,0.1667,0.1613,0.1563,0.1515,0.1471,0.1389,0.1351,0.1282,0.1282,0.1250,0.1190,0.1163,0.1111,0.1087,0.1064,0.1020,0.1000,0.0962,0.0943,0.0926,0.0893,0.0877,0.0847,0.0833,0.0820,0.0794,0.0781,0.0758,0.0735,0.0725,0.0704,0.0694,0.0676,0.0667,0.0649,0.0633,0.0625,0.0610,0.0595,0.0588,0.0575,0.0562,0.0549,0.0543,0.0532,0.0521,0.0510,0.0500}

---------------------------------------------------------------------------
-- Settings (per class, kept in AshenBuildsDB.simSettings.Warrior).
---------------------------------------------------------------------------
-- Consumables and raid buffs. group: only one of the group counts.
W.BUFFS = {
  {key="bom", name="Blessing of Might", ap=155, src="DB", group="bom"},
  {key="gbom", name="Greater Blessing of Might", ap=185, src="DB", group="bom"},
  {key="kings", name="Blessing of Kings", statPct=10, src="DB"},
  {key="motw", name="Mark of the Wild", str=12, agi=12, src="DB"},
  {key="lotp", name="Leader of the Pack", crit=3, src="DB"},
  {key="dragonslayer", name="Rallying Cry of the Dragonslayer", ap=140, crit=5, src="DB"},
  {key="songflower", name="Songflower Serenade", crit=5, str=15, agi=15, src="DB"},
  {key="zandalar", name="Spirit of Zandalar", statPct=15, src="DB"},
  {key="warchief", name="Warchief's Blessing", haste=15, src="DB"},
  {key="mongoose", name="Elixir of the Mongoose", agi=25, crit=2, src="DB"},
  {key="giants", name="Elixir of Giants", str=25, src="DB", group="elixir"},
  {key="jujupower", name="Juju Power", str=30, src="DB", group="elixir"},
  {key="jujumight", name="Juju Might", ap=40, src="DB", group="apbuff"},
  {key="firewater", name="Winterfall Firewater", ap=35, src="DB", group="apbuff"},
  {key="food", name="Well Fed (+20 Strength)", str=20, src="DB"},
  {key="elemstone", name="Elemental Sharpening Stone", crit=2, src="DB", group="stone"},
  {key="densestone", name="Dense Sharpening Stone", weaponDmg=8, src="DB", group="stone"},
}
-- Target armor debuffs (Turtle DB values; same group = do not stack).
W.DEBUFFS = {
  {key="sunder", name="Sunder Armor x5", armor=2250, src="DB", group="major"},
  {key="iea", name="Improved Expose Armor (5 pts)", armor=2550, src="DB", group="major"},
  {key="faerie", name="Faerie Fire", armor=505, src="DB"},
  {key="cor", name="Curse of Recklessness", armor=640, src="DB"},
  {key="annihilator", name="Annihilator x3 (raid)", armor=300, src="DB"},
  {key="crystal", name="Crystal Yield", armor=200, src="DB"},
}

-- Boss armor (Turtle WoW Raid Boss Armor Values sheet). Picking one fills in the armor.
W.BOSSES = {
  {"MC - Most bosses", 4211}, {"MC - Sulfuron Harbinger", 4786}, {"MC - Gehennas, Lucifron, Shazzrah", 3402},
  {"Onyxia", 4211}, {"BWL - All bosses", 4211},
  {"ZG - Bloodlord Mandokir", 4211}, {"ZG - High Priest Thekal", 3850}, {"ZG - Most bosses", 3402},
  {"AQ20 - Most bosses", 4211}, {"AQ20 - Moam", 4113}, {"AQ20 - Buru the Gorger", 3402},
  {"AQ40 - Most bosses", 4211}, {"AQ40 - Emperor Vek'lor", 3833}, {"AQ40 - The Prophet Skeram", 3402},
  {"Naxx - Most bosses", 4211}, {"Naxx - Loatheb, Patch, Thaddius", 4611}, {"Naxx - Faerlina, Noth", 3850}, {"Naxx - Gothik, Kel'Thuzad", 3402},
  {"ES - Solnius", 4712}, {"ES - Erennius", 4912},
  {"Kara10 - Lord Blackwald", 4325}, {"Kara10 - Howlfang, Moroes", 3892}, {"Kara10 - Grizikil, Araxxna", 3044},
  {"Kara40 - Most bosses", 4211}, {"Kara40 - Krull", 4752}, {"Kara40 - Rook, Rupturan, Mephistroth", 4611},
  {"Kara40 - Echo, Sanv Tasdal", 3850}, {"Kara40 - Bishop", 3402},
  {"World - Kazzak, Azuregos, Dragons", 4211}, {"World - Ostarius", 5980}, {"World - Dark Reaver of Karazhan", 4285},
  {"World - Omen", 4186}, {"World - Nerubian Overseer", 3761},
  {"Silithus - Lord Skwol", 4061}, {"Silithus - Prince Thunderaan", 4213},
  {"UBRS - Gyth", 4061}, {"UBRS - Lord Valthalak", 3400}, {"Strat UD - Atiesh", 3850},
}
W.ROTATIONS = {
  {key="auto", name="Automatic (from weapons)"},
  {key="fury_dw", name="Dual-Wield Fury"},
  {key="fury_2h", name="Two-Hand Fury"},
  {key="arms", name="Arms"},
  {key="prot", name="Protection (shield)"},
  {key="custom", name="Custom"},
}
W.CUSTOM_ABILITIES = {"Bloodthirst","Mortal Strike","Whirlwind","Overpower","Slam","Hamstring","Master Strike","Rend",
  "Shield Slam","Revenge","Concussion Blow","Sunder Armor","Death Wish","Recklessness","Berserker Rage","Bloodrage"}

function W.DefaultSettings()
  return {
    duration = 120, targetLevel = 63, targetArmor = 4211, boss = "BWL - All bosses", position = "behind", parry = 14, targets = 1,
    iterations = 1000, reaction = 250, rotation = "auto", hsRage = 30, executePct = 20, startRage = 0,
    useHeroicStrike = true, enrageOnBloodrage = true, seed = 12345, randomSeed = false,
    tanking = "auto", bossSpeed = 2.0, bossMin = 1000, bossMax = 1400,
    buffs = {bom=true, kings=true, motw=true, mongoose=true, jujupower=true, jujumight=true, food=true},
    debuffs = {sunder=true, faerie=true, cor=true},
    custom = {["Bloodthirst"]=true, ["Whirlwind"]=true, ["Bloodrage"]=true, ["Death Wish"]=true, ["Recklessness"]=true},
  }
end

---------------------------------------------------------------------------
-- Builder -> simulated character.
---------------------------------------------------------------------------
local function TalentRanks(AB, build)
  local ranks = {}
  local data = AB:GetTalentData(build.class)
  if not data then return ranks end
  local ti, i, t, r
  for ti = 1, 3 do
    for i = 1, table.getn(data[ti] or {}) do
      t = data[ti][i]; r = AB:GetTalentRank(build, ti, i)
      if r > 0 and t.name then ranks[t.name] = r end
    end
  end
  return ranks
end

local STAT_PHRASES = {"critical strike", "chance to hit", "attack power", "skill", "defense", "dodge", "parry", "block",
  "damage and healing", "spell", "mana", "health", "stamina", "strength", "agility", "intellect", "spirit", "armor",
  "resist", "attack and casting speed", "attack speed", "damage taken", "threat", "movement", "run speed", "fishing", "mining", "herbalism", "skinning", "stealth", "detect"}

local function IsStatText(text)
  local lower = string.lower(text or ""); local i
  if string.find(lower, "chance on") or string.find(lower, "chance to deal") or string.find(lower, "chance when") then return false end
  if string.find(lower, "^increased [%a%- ]+ %+%d+") then return true end  -- weapon skill lines
  for i = 1, table.getn(STAT_PHRASES) do if string.find(lower, STAT_PHRASES[i], 1, true) then return true end end
  return false
end

-- Set bonus lines the simulator can apply directly.
local SET_PATTERNS = {
  {"^%+(%d+) Attack Power", "ap"},
  {"attack power by (%d+)%.$", "ap"},
  {"critical strike by (%d+)%%", "crit"},
  {"chance to hit by (%d+)%%", "hit"},
  {"^%+(%d+) Strength", "str"},
  {"^%+(%d+) Agility", "agi"},
  {"attack power granted by Battle Shout by (%d+)", "battleShout"},
  {"rage cost of Sunder Armor, Whirlwind and Heroic Strike by %-?(%d+)", "brotherhood"},
  {"attack and casting speed by (%d+)%%", "hastePct"},
}
local NO_DPS = {"Armor", "Defense", "Stamina", "Resistance", "resistance", "health", "Health", "block", "parry", "dodge", "Intellect", "Spirit", "mana", "healing", "threat", "Shield Wall", "Taunt"}

-- Warrior set mechanics by bonus spell id (values from the Turtle DB).
-- Stat-only bonuses come from AshenSim.SetEffects instead.
local function Add(c, k, v) c.set[k] = (c.set[k] or 0) + v end
local function SetProc(c, name, proc) table.insert(c.itemProcs, {proc = proc, name = name}) end
local SET_SPECIAL = {
  [23563] = function(c) Add(c, "battleShout", 30) end,                     -- Battlegear of Wrath (3)
  [21890] = function(c) c.set.wrathDiscount = true end,                   -- Battlegear of Wrath (5): 20% next ability -5 rage
  [23548] = function(c) end,                                              -- Battlegear of Wrath (8): parry after block, no damage effect
  [41361] = function(c) Add(c, "brotherhood", 5) end,                      -- Brotherhood (3): Sunder/WW/HS -5 rage
  [24431] = function(c) Add(c, "wwCost", 3) end,                           -- Vindicator's (5)
  [53200] = function(c) Add(c, "strikeCost", 10) end,                      -- Armor of Might (5): BT/MS -10 rage
  [51899] = function(c) c.set.mightRage = true end,                       -- Armor of Might (3): 10% on ability hit +15 rage
  [53206] = function(c) Add(c, "cdCost", 10) end,                          -- Armor of the Dreadnought (2): SS/DW -10 rage
  [53207] = function(c) Add(c, "abilityCrit", 0.04) end,                   -- Armor of the Dreadnought (4)
  [53205] = function(c) end,                                              -- threat only
  [53203] = function(c) c.set.overpowerHaste = true end,                  -- Armor of Wrath (3)
  [53204] = function(c) Add(c, "wwTargets", 2) end,                        -- Armor of Wrath (8)
  [52686] = function(c) c.set.unyielding = true end,                      -- Unyielding Strength (3)
  [22778] = function(c) Add(c, "hamCost", 3) end,                          -- PvP (2)
  [26109] = function(c) Add(c, "shoutCostPct", 35) end,                    -- Conqueror's (3)
  [28844] = function(c) Add(c, "revenge", 75) end,                         -- Dreadnaught's (2)
  [28842] = function(c) Add(c, "protHit", 5) end,                          -- Dreadnaught's (6)
  [21838] = function(c) c.set.mightDamaged = true end,                    -- Battlegear of Might (5)
  [49368] = function(c) c.set.thaurissan = true end,                      -- Arms of Thaurissan (2)
  [45496] = function(c) SetProc(c, "Towerforge Battlegear", {chance = 2, spell = "PowerSurge", src = "DB"}) end,
  [24256] = function(c) SetProc(c, "Primal Blessing", {chance = 1, spell = "PrimalBlessing", src = "DB"}) end,
  [9233] = function(c) SetProc(c, "Firebolt (set)", {chance = 5, dmg = 20, magic = true, src = "DB"}) end,
  [44065] = function(c) SetProc(c, "Lightning (Stormshroud)", {chance = 5, dmg = 42.5, magic = true, src = "DB"}) end,
  [23863] = function(c) SetProc(c, "Stormshroud Armor", {chance = 2, spell = "Revitalize", src = "DB"}) end,
}

local SKILL_ALL = {"Sword", "Axe", "Mace", "Dagger", "Fist", "Polearm", "Staff", "TwoHandSword", "TwoHandAxe", "TwoHandMace"}

local function ReadSetBonuses(AB, build, c)
  local counts = AB.GetSetCounts and AB:GetSetCounts(build) or {}
  local setId, n, i, j
  c.set.skill = {}
  for setId, n in pairs(counts) do
    local set = AB:GetItemSet(setId)
    if set and set.bonuses then
      for i = 1, table.getn(set.bonuses) do
        local b = set.bonuses[i]
        if n >= (b[1] or 99) then
          local text, done = b[3] or "", false
          local e = S.SetEffects and S.SetEffects[b[2]]
          if SET_SPECIAL[b[2]] then SET_SPECIAL[b[2]](c); done = true
          elseif e and not e.special then
            local k, v
            for k, v in pairs(e) do
              if k == "haste" then c.set.hastePct = (c.set.hastePct or 0) + v
              elseif k == "skill" then
                local wt, sv
                for wt, sv in pairs(v) do
                  if wt == "all" then local q; for q = 1, table.getn(SKILL_ALL) do c.set.skill[SKILL_ALL[q]] = (c.set.skill[SKILL_ALL[q]] or 0) + sv end
                  else c.set.skill[wt] = (c.set.skill[wt] or 0) + sv end
                end
              elseif k ~= "none" then c.set[k] = (c.set[k] or 0) + v end
            end
            done = true
          elseif not e then
            -- Not in the DB table: fall back to reading the bonus text.
            for j = 1, table.getn(SET_PATTERNS) do
              local _, _, v = string.find(text, SET_PATTERNS[j][1])
              if v then c.set[SET_PATTERNS[j][2]] = (c.set[SET_PATTERNS[j][2]] or 0) + tonumber(v); done = true; break end
            end
          end
          if not done and not e then
            for j = 1, table.getn(NO_DPS) do if string.find(text, NO_DPS[j], 1, true) then done = true; break end end
          end
          if not done then table.insert(c.unsupported, (set.name or "Set").." ("..b[1].."): "..text) end
        end
      end
    end
  end
end

local function WeaponFrom(AB, build, out, slot, c)
  local id = build.items and build.items[slot]
  local item = id and AB:GetItem(id)
  if not item or not item.weaponType or (item.speed or 0) <= 0 then return nil end
  local t = item.weaponType
  local two = item.twoHand or item.slot == "TWOHAND" or t == "Polearm" or t == "Staff"
  local w = {id = id, name = item.n, speed = item.speed, min = item.minDamage or 0, max = item.maxDamage or 0,
    type = t, twoHand = two, offhand = (slot == "OFFHAND"), bonus = 0, crit = 0, arp = 0}
  w.norm = two and 3.3 or (t == "Dagger" and 1.7 or 2.4)
  local sk = AB:GetWeaponSkill(build, slot, out.gear, out.talentModifiers)
  w.skill = (sk and sk.total) or c.level * 5
  local mastery = c.talents["Master of Arms"] or 0
  if t == "Axe" then w.crit = mastery end
  if t == "Mace" then w.arp = 1.2 * mastery * c.level end
  if t == "Sword" then w.swordProc = mastery end
  -- Damage modifiers from weapon specializations.
  if two then w.mod = 1 + 0.02 * (c.talents["Two-Handed Weapon Specialization"] or 0)
  else w.mod = 1 + 0.02 * (c.talents["One-Handed Weapon Specialization"] or 0) end
  if w.offhand then w.mod = 0.5 * (1 + 0.05 * (c.talents["Dual Wield Specialization"] or 0)) * w.mod end
  -- Enchant: flat weapon damage or a proc.
  local enchantID = build.enchants and build.enchants[slot]
  local enchant = enchantID and AshenBuildsEnchants and AshenBuildsEnchants[enchantID]
  if enchant then
    w.bonus = w.bonus + S.EnchantWeaponDamage(enchant)
    w.enchantProc = enchant.spell and S.EnchantProcs[enchant.spell]
    w.enchantName = enchant.n
  end
  w.proc = (w.offhand and S.OffhandProcs[id]) or S.ItemProcs[id]
  if w.proc and w.proc.spell and not S.ProcAuras[w.proc.spell] then
    table.insert(c.unsupported, item.n..": proc effect")
    w.proc = nil
  end
  return w
end

-- Builds everything the fight needs from a builder build and the class settings.
function W.BuildCharacter(build, cfg)
  local AB = AshenBuilds
  local out = AB:GetDerivedStats(build)
  local level = AB:GetBuildLevel(build)
  local c = {level = level, race = build.race, talents = TalentRanks(AB, build), unsupported = {}, set = {}, notes = {}}
  c.mh = WeaponFrom(AB, build, out, "MAINHAND", c)
  if not c.mh then return nil, "Equip a main-hand weapon to simulate." end
  if not c.mh.twoHand then c.oh = WeaponFrom(AB, build, out, "OFFHAND", c) end
  local shieldItem = AB:GetItem((build.items and build.items.OFFHAND) or 0)
  c.shield = shieldItem and shieldItem.shield
  c.offHit = 2 * (c.talents["Dual Wield Specialization"] or 0)

  -- Item effects the sheet cannot show.
  c.itemProcs = {}
  local i, slot, id, item
  for i = 1, table.getn(AB.SLOTS) do
    slot = AB.SLOTS[i]; id = build.items and build.items[slot]; item = id and AB:GetItem(id)
    if item and slot ~= "RANGED" then
      local isWeapon = (slot == "MAINHAND" or slot == "OFFHAND")
      local p = S.ItemProcs[id]
      if p and not isWeapon then
        if p.spell and not S.ProcAuras[p.spell] then table.insert(c.unsupported, item.n..": proc effect")
        else table.insert(c.itemProcs, {proc = p, name = item.n}) end
      end
      local d = AshenDB and AshenDB.ItemDetails and AshenDB.ItemDetails[id]
      local effects = d and d[9]
      local j
      for j = 1, table.getn(effects or {}) do
        local e = effects[j]
        local trig, text = e[1], e[2] or ""
        if trig == 0 then table.insert(c.unsupported, item.n..": Use - "..text)
        elseif trig == 2 then
          if not p then table.insert(c.unsupported, item.n..": Chance on hit - "..text) end
        elseif not IsStatText(text) and not p then
          table.insert(c.unsupported, item.n..": Equip - "..text)
        end
      end
    end
  end
  ReadSetBonuses(AB, build, c)
  -- Set weapon skill (the sheet does not include set bonuses).
  local function SetSkill(w)
    if not w then return end
    local key = w.type
    if w.twoHand and (key == "Sword" or key == "Axe" or key == "Mace") then key = "TwoHand"..key end
    w.sheetSkill = w.skill
    w.skill = w.skill + (c.set.skill[key] or 0)
  end
  SetSkill(c.mh); SetSkill(c.oh)

  -- Buffs and debuffs from the settings.
  local b = {str = 0, agi = 0, ap = 0, crit = 0, statPct = 0, haste = 1, weaponDmg = 0, armor = 0}
  local taken = {}
  local function Add(def)
    if def.group then if taken[def.group] then return end; taken[def.group] = true end
    b.str = b.str + (def.str or 0); b.agi = b.agi + (def.agi or 0); b.ap = b.ap + (def.ap or 0); b.crit = b.crit + (def.crit or 0)
    if def.statPct then b.statPct = b.statPct + def.statPct end
    if def.haste then b.haste = b.haste * (1 + def.haste / 100) end
    b.weaponDmg = b.weaponDmg + (def.weaponDmg or 0); b.armor = b.armor + (def.armor or 0)
  end
  for i = 1, table.getn(W.BUFFS) do if cfg.buffs[W.BUFFS[i].key] then Add(W.BUFFS[i]) end end
  for i = 1, table.getn(W.DEBUFFS) do if cfg.debuffs[W.DEBUFFS[i].key] then Add(W.DEBUFFS[i]) end end
  b.str = b.str + (c.set.str or 0); b.agi = b.agi + (c.set.agi or 0); b.ap = b.ap + (c.set.ap or 0); b.crit = b.crit + (c.set.crit or 0)

  -- Kings and Zandalar each multiply total stats.
  c.statMult = 1
  if cfg.buffs.kings then c.statMult = c.statMult * 1.10 end
  if cfg.buffs.zandalar then c.statMult = c.statMult * 1.15 end
  c.baseStr = out.str + b.str; c.baseAgi = out.agi + b.agi
  c.apBase = out.attackPower - 2 * out.str + b.ap   -- attack power not coming from strength
  c.agiCrit = AGI_CRIT[level] or 0.05
  -- The sheet crit includes agility and the main-hand skill bonus; the fight works those out itself.
  local skillCrit = ((c.mh.sheetSkill or c.mh.skill) - level * 5) * 0.04
  c.critBase = out.meleeCrit - skillCrit - out.agi * c.agiCrit + b.crit
  c.hit = out.hit + (c.set.hit or 0)
  c.spellCrit = out.spellCrit or 0
  c.spellPower = out.spellPower or 0
  c.haste = (1 + (out.haste or 0) / 100) * b.haste * (1 + (c.set.hastePct or 0) / 100)
  if c.race == "Night Elf" or c.race == "NightElf" then c.haste = c.haste * 1.01 end
  c.mh.bonus = c.mh.bonus + b.weaponDmg
  if c.oh then c.oh.bonus = c.oh.bonus + b.weaponDmg end
  c.targetArmor = max(0, (cfg.targetArmor or 0) - b.armor - (out.armorPen or 0))
  -- Defensive side, for when the boss is hitting you.
  c.dodge, c.parry, c.block, c.defense = out.dodge or 0, out.parry or 0, out.block or 0, out.defense or level * 5
  c.playerArmor = out.armor or 0
  c.blockGear = ((out.gear and out.gear.blockValue) or 0) - 1
  c.blockPct = 1 + ((out.talentModifiers and out.talentModifiers.blockValuePct) or 0) / 100
  c.out = out
  if c.set.hastePct then c.notes.hasteFromSet = c.set.hastePct end
  return c
end

---------------------------------------------------------------------------
-- Rage.
---------------------------------------------------------------------------
local function RageConversion(level) return 0.0091107836 * level * level + 3.225598133 * level + 4.2652911 end

local function AddRage(sim, a, amount, source)
  if amount <= 0 then return end
  local room = a.rageCap - a.rage
  if amount > room then sim:Count("rage.wasted", amount - room); amount = room end
  a.rage = a.rage + amount
  sim:Count("rage.gen", amount); sim:Count(Key("rage.gen.", source), amount)
end

local function SpendRage(sim, a, amount, source)
  a.rage = a.rage - amount
  sim:Count("rage.spent", amount); sim:Count(Key("rage.spent.", source), amount)
end

---------------------------------------------------------------------------
-- Stats that change during the fight.
---------------------------------------------------------------------------
local function Recalc(a)
  local c = a.char
  local str, agi, ap, crit, hit, haste, dmgBonus, armorOff = 0, 0, 0, 0, 0, 1, 0, 0
  local _, m
  for _, m in pairs(a.mods) do
    local st = m.stats
    if st then str = str + (st.str or 0); agi = agi + (st.agi or 0); ap = ap + (st.ap or 0); crit = crit + (st.crit or 0); hit = hit + (st.hit or 0) end
    if m.haste then haste = haste * (1 + m.haste / 100) end
    dmgBonus = dmgBonus + (m.dmgBonus or 0)
    if m.armor then armorOff = armorOff + m.armor * (m.stacks or 1) end
  end
  a.str = floor((c.baseStr + str) * c.statMult)
  a.agi = floor((c.baseAgi + agi) * c.statMult)
  a.ap = c.apBase + 2 * a.str + ap
  a.crit = c.critBase + a.agi * c.agiCrit + crit
  a.hit = c.hit + hit
  a.haste = c.haste * haste
  a.dmgBonus = dmgBonus
  local dm = 1
  if a.auras["Death Wish"].active then dm = dm * 1.2 end
  if a.auras["Enrage"].active then dm = dm * (1 + 0.04 * (c.talents["Enrage"] or 0)) end
  if a.stance == "defensive" then dm = dm * 0.9 end
  a.dmgmod = dm
  local maceArp = 0
  if a.mh.arp > 0 then maceArp = a.mh.arp elseif a.oh and a.oh.arp > 0 then maceArp = a.oh.arp end
  local armor = max(0, c.targetArmor - maceArp - armorOff)
  local red = armor / (armor + 400 + 85 * c.level)
  if red > 0.75 then red = 0.75 end
  a.armor = armor; a.armorMult = 1 - red
  if c.shield then a.blockValue = max(0, floor((c.blockGear + a.str / 20) * c.blockPct)) else a.blockValue = 0 end
end

local function SetMod(a, key, def, on)
  if on then a.mods[key] = def else a.mods[key] = nil end
  Recalc(a)
end

-- A buff/debuff tracked for uptime whose effect is a stat modifier.
local function ModAura(sim, a, name, def)
  return S.NewAura(sim, name, function(s, au) SetMod(a, name, def, true) end, function(s, au) SetMod(a, name, nil, false) end)
end

---------------------------------------------------------------------------
-- Attack tables.
---------------------------------------------------------------------------
local function CritChance(a, w, extra)
  local c = a.crit + (a.char.level - a.cfg.targetLevel) + w.crit + (extra or 0)
  if a.stance == "berserker" then c = c + 3 end
  return max(c, 0)
end

local function MissChance(a, w, dualWield)
  local diff = a.def - w.skill
  local miss = 5 + max(diff * 0.2, 0)
  if dualWield then miss = miss * 0.8 + 20 end
  miss = miss - a.hit
  if w.offhand then miss = miss - a.char.offHit end
  return max(miss, 0)
end

local function DodgeChance(a, w) return max(5 + (a.def - w.skill) * 0.1, 0) end

local function WhiteRoll(sim, a, w, singleWield)
  local roll = sim.rng:Next() * 100
  local tmp = MissChance(a, w, a.oh ~= nil and not singleWield)
  if roll < tmp then return MISS end
  tmp = tmp + DodgeChance(a, w); if roll < tmp then return DODGE end
  if a.front then tmp = tmp + a.cfg.parry; if roll < tmp then return PARRY end end
  tmp = tmp + 10 + max(a.def - min(a.char.level * 5, w.skill), 0) * 2; if roll < tmp then return GLANCE end
  tmp = tmp + CritChance(a, w); if roll < tmp then return CRIT end
  return HIT
end

-- Abilities: single-wield miss, optional dodge, then crit (same roll for
-- "weapon" abilities, a fresh roll for Bloodthirst/Execute).
local function SpellRoll(sim, a, w, canDodge, sameRoll, extraCrit, extraHit)
  local roll = sim.rng:Next() * 100
  local tmp = max(MissChance(a, w, false) - (extraHit or 0), 0)
  if roll < tmp then return MISS end
  if canDodge then tmp = tmp + DodgeChance(a, w); if roll < tmp then return DODGE end end
  if a.front then tmp = tmp + a.cfg.parry; if roll < tmp then return PARRY end end
  if not sameRoll then roll = sim.rng:Next() * 100; tmp = 0 end
  tmp = tmp + CritChance(a, w, extraCrit)
  if roll < tmp then return CRIT end
  return HIT
end

local function Landed(result) return result ~= MISS and result ~= DODGE and result ~= PARRY end

local function WeaponDamage(sim, a, w, normalized)
  return sim.rng:Range(w.min + w.bonus, w.max + w.bonus) + a.ap / 14 * (normalized and w.norm or w.speed) + a.dmgBonus
end

local function AverageDamage(a, w)
  return (w.min + w.max) / 2 + w.bonus + a.ap / 14 * w.norm + a.dmgBonus
end

local function GlanceMult(sim, a, w)
  local diff = a.def - w.skill
  local low = max(min(0.9 - 0.023 * diff, 0.9), 0.01)
  local high = max(min(1.0 - 0.017 * diff, 1.0), 0.2)
  return sim.rng:Range(low, high)
end

---------------------------------------------------------------------------
-- Procs and crit effects.
---------------------------------------------------------------------------
local Think, MainHandSwing, OffHandSwing

local function ProcChance(p, speed)
  if p.chance then return p.chance end
  return speed * (p.ppm or 1) / 60 * 100
end

local function ApplyProcAura(sim, a, key, label)
  local def = S.ProcAuras[key]
  local name = label or def.name
  local au = a.auras[name]
  if not au then
    au = S.NewAura(sim, name, nil, function(s, x) a.mods[name] = nil; Recalc(a) end)
  end
  local m = a.mods[name]
  if def.maxStacks then
    local stacks = min((m and m.stacks or 0) + 1, def.maxStacks)
    a.mods[name] = {stats = def.stats, haste = def.haste, dmgBonus = def.dmgBonus, armor = def.armor, stacks = stacks}
  else
    a.mods[name] = def
  end
  au:Apply(def.duration)
  Recalc(a)
end

local function MagicProc(sim, a, p, source)
  local miss = 17
  local diff = a.cfg.targetLevel - a.char.level
  if diff <= 2 then miss = 4 + max(diff, 0) elseif diff > 3 then miss = 28 + 11 * (diff - 4) end
  if sim.rng:Next() * 100 < miss then sim:Damage(source, 0, MISS); return end
  local dmg = p.dmg + (p.coeff and a.char.spellPower * p.coeff or 0)
  local result = HIT
  if sim.rng:Next() * 100 < a.char.spellCrit then dmg = dmg * 1.5; result = CRIT end
  if a.stance == "defensive" then dmg = dmg * 0.9 end
  sim:Damage(source, dmg, result)
end

local function PhysicalProc(sim, a, p, source)
  local w = a.mh
  local roll = sim.rng:Next() * 100
  local tmp = MissChance(a, w, false)
  if roll < tmp then sim:Damage(source, 0, MISS); return end
  tmp = tmp + DodgeChance(a, w)
  if roll < tmp then sim:Damage(source, 0, DODGE); return end
  local dmg, result = p.dmg, HIT
  if sim.rng:Next() * 100 < CritChance(a, w) then dmg = dmg * 2; result = CRIT end
  sim:Damage(source, dmg * a.dmgmod * w.mod * a.armorMult, result)
end

local function RunProc(sim, a, p, name, speed, fromAbility)
  if sim.rng:Next() * 100 >= ProcChance(p, speed) then return 0 end
  if p.gcd and sim.t < a.gcdEnd then return 0 end
  sim:Count(Key("proc.", name))
  if p.extra then return p.extra end
  if p.spell then ApplyProcAura(sim, a, p.spell) end
  if p.dmg then if p.magic then MagicProc(sim, a, p, name) else PhysicalProc(sim, a, p, name) end end
  return 0
end

-- Everything that can happen when a weapon attack or ability connects.
local function OnHitProcs(sim, a, w, fromAbility, adjacent)
  local extras = 0
  if w.proc then
    local n = RunProc(sim, a, w.proc, w.name, w.speed, fromAbility)
    if not adjacent then extras = extras + n end
  end
  if w.enchantProc then
    local p = w.enchantProc
    if sim.rng:Next() * 100 < ProcChance(p, w.speed) then
      sim:Count(Key("proc.", w.enchantName or "Enchant"))
      if p.spell then ApplyProcAura(sim, a, p.spell, Key(p.spell, w.offhand and " (OH)" or " (MH)")) end
      if p.dmg then MagicProc(sim, a, p, (w.enchantName or "Enchant")) end
    end
  end
  local i
  for i = 1, table.getn(a.char.itemProcs) do
    local ip = a.char.itemProcs[i]
    local n = RunProc(sim, a, ip.proc, ip.name, a.mh.speed, fromAbility)
    if not adjacent then extras = extras + n end
  end
  if w.swordProc and w.swordProc > 0 and not adjacent and a.swordAt ~= sim.t and sim.rng:Next() * 100 < w.swordProc then
    a.swordAt = sim.t; extras = extras + 1; sim:Count("proc.Sword Specialization")
  end
  if extras > 0 then a.extra = a.extra + extras end
end

local function DeepWoundsTick(sim, a)
  a.dwTick = nil
  local w = a.mh
  local avg = (w.min + w.max) / 2 + w.bonus + a.dmgBonus + a.ap / 14 * w.speed
  local dmg = avg * w.mod * a.dmgmod * 0.2 * (a.char.talents["Deep Wounds"] or 0) / 4
  sim:Damage("Deep Wounds", dmg, "tick")
  if sim.t + 1.5 <= a.dwExpire + 0.0001 then a.dwTick = sim:After(1.5, DeepWoundsTick, a) end
end

local function OnCrit(sim, a)
  if a.flurryRank > 0 then a.auras["Flurry"]:Apply(15, 3) end
  if (a.char.talents["Deep Wounds"] or 0) > 0 then
    a.auras["Deep Wounds"]:Apply(6)
    a.dwExpire = sim.t + 6
    if a.dwTick then a.dwTick.dead = true end
    a.dwTick = sim:After(1.5, DeepWoundsTick, a)
  end
end

local function ConsumeFlurry(sim, a)
  local f = a.auras["Flurry"]
  if f.active then
    f.stacks = f.stacks - 1
    if f.stacks <= 0 then f:Remove() end
  end
end

local function OpenOverpower(sim, a) a.dodgeUntil = sim.t + 5 end

local function WhiteRage(sim, a, w, result, dmg)
  local conv = a.rageConv
  if result == DODGE or result == PARRY then
    AddRage(sim, a, AverageDamage(a, w) * w.mod * a.dmgmod * a.armorMult / conv * 7.5 * 0.75, "dodge")
    return
  end
  if result == MISS then return end
  local base = dmg / conv * 7.5 / 1.075
  local speedPart
  if w.offhand then speedPart = (result == CRIT) and (w.speed * 3.5 / 2.25) or (w.speed * 1.75 / 2.4)
  else speedPart = (result == CRIT) and (w.speed * 7.5 / 2.25) or (w.speed * 3.5 / 2.25) end
  AddRage(sim, a, base + speedPart, "white")
end

local function UnbridledWrath(sim, a, w, result)
  local rank = a.char.talents["Unbridled Wrath"] or 0
  if rank > 0 and Landed(result) and sim.rng:Next() * 100 < rank * 15 then
    AddRage(sim, a, (w.twoHand and not w.offhand) and 2 or 1, "unbridled")
  end
end

---------------------------------------------------------------------------
-- Swings.
---------------------------------------------------------------------------
-- Set procs that trigger on abilities.
local function AbilityResult(sim, a, name, result)
  local set = a.char.set
  if set.mightRage and Landed(result) and sim.rng:Next() * 100 < 10 then AddRage(sim, a, 15, "setBonus") end
  if set.unyielding and (result == DODGE or result == PARRY) and (name == "Heroic Strike" or name == "Slam") then AddRage(sim, a, 5, "setBonus") end
end

local PROT_HIT = {["Sunder Armor"] = true, ["Heroic Strike"] = true, ["Revenge"] = true, ["Shield Slam"] = true}

local function ScheduleMH(sim, a, at)
  if a.mhEvent then a.mhEvent.dead = true end
  a.mhEvent = sim:At(at, MainHandSwing, a)
  a.mhSwingLen = at - sim.t
end

local function DoExtraAttack(sim, a)
  if a.extra > 0 then
    a.extra = a.extra - 1
    a.queued = nil
    ScheduleMH(sim, a, sim.t)
    sim:Count("extraAttacks")
    if a.char.set.thaurissan then ApplyProcAura(sim, a, "UnrelentingStrikes") end
  end
end

MainHandSwing = function(sim, a)
  a.mhEvent = nil
  if a.casting then a.mhDue = true; return end
  local w = a.mh
  local spell = a.queued
  a.queued = nil
  if spell and a.rage < spell.cost then if sim.log then sim:Log(spell.name.." cancelled (not enough rage)") end; spell = nil end
  local result, dmg
  if spell then
    local cost = spell.cost
    if a.wrathDiscount then cost = max(0, cost - 5); a.wrathDiscount = nil end
    SpendRage(sim, a, cost, spell.name)
    if a.char.set.wrathDiscount and sim.rng:Next() * 100 < 20 then a.wrathDiscount = true end
    result = SpellRoll(sim, a, w, true, true, 0, PROT_HIT[spell.name] and a.char.set.protHit or 0)
    AbilityResult(sim, a, spell.name, result)
    dmg = (WeaponDamage(sim, a, w, false) + spell.bonus) * w.mod * a.dmgmod
  else
    result = WhiteRoll(sim, a, w, false)
    dmg = WeaponDamage(sim, a, w, false) * w.mod * a.dmgmod
  end
  if Landed(result) then OnHitProcs(sim, a, w, spell ~= nil) end
  if not spell then ConsumeFlurry(sim, a) end
  if result == DODGE then OpenOverpower(sim, a) end
  if result == GLANCE then dmg = dmg * GlanceMult(sim, a, w) end
  if result == CRIT then dmg = dmg * (spell and a.abilityCritMult or 2); OnCrit(sim, a) end
  ScheduleMH(sim, a, sim.t + w.speed / a.haste)
  local done = Landed(result) and dmg * a.armorMult or 0
  local source = spell and spell.name or "Main Hand"
  sim:Damage(source, done, result)
  if sim.log then sim:Log(string.format("%s %s for %d  (rage %d)", source, result, done, a.rage)) end
  if spell then
    UnbridledWrath(sim, a, w, result)
    if not Landed(result) then AddRage(sim, a, spell.cost * 0.8, "refund") end
    if spell.name == "Cleave" and a.targets > 1 then
      local r2 = SpellRoll(sim, a, w, true, true, 0)
      local d2 = (WeaponDamage(sim, a, w, false) + spell.bonus) * w.mod * a.dmgmod
      if r2 == CRIT then d2 = d2 * a.abilityCritMult; OnCrit(sim, a) end
      sim:Damage("Cleave", Landed(r2) and d2 * a.armorMult or 0, r2)
    end
  else
    WhiteRage(sim, a, w, result, done)
    UnbridledWrath(sim, a, w, result)
  end
  if a.sweeping > 0 and a.targets > 1 and Landed(result) then
    a.sweeping = a.sweeping - 1; sim:Damage("Sweeping Strikes", done, result)
  end
  DoExtraAttack(sim, a)
  Think(sim, a)
end

OffHandSwing = function(sim, a)
  a.ohEvent = nil
  if a.casting then a.ohDue = true; return end
  local w = a.oh
  local result = WhiteRoll(sim, a, w, false)
  local dmg = WeaponDamage(sim, a, w, false) * w.mod * a.dmgmod
  if Landed(result) then OnHitProcs(sim, a, w, false) end
  ConsumeFlurry(sim, a)
  if result == DODGE then OpenOverpower(sim, a) end
  if result == GLANCE then dmg = dmg * GlanceMult(sim, a, w) end
  if result == CRIT then dmg = dmg * 2; OnCrit(sim, a) end
  a.ohEvent = sim:After(w.speed / a.haste, OffHandSwing, a)
  local done = Landed(result) and dmg * a.armorMult or 0
  sim:Damage("Off Hand", done, result)
  if sim.log then sim:Log(string.format("Off Hand %s for %d  (rage %d)", result, done, a.rage)) end
  WhiteRage(sim, a, w, result, done)
  UnbridledWrath(sim, a, w, result)
  DoExtraAttack(sim, a)
  Think(sim, a)
end

---------------------------------------------------------------------------
-- Abilities.
---------------------------------------------------------------------------
-- Rank and talent tables (kept outside the functions so fights create no garbage).
local T1 = {1, 1.5, 2}
local T2 = {2, 5}
local T3 = {0.25, 0.5}
local T4 = {5, 10}
local T5 = {{40, 1.15}, {48, 1.20}, {54, 1.25}, {60, 1.30}}
local T6 = {{12, 5}, {28, 15}, {44, 25}, {60, 35}}
local T7 = {{24, 75}, {32, 150}, {40, 225}, {48, 300}, {56, 600}}
local T8 = {{24, 4}, {32, 8}, {40, 12}, {48, 16}, {56, 15}}
local T9 = {{30, {175, 185}}, {38, {226, 236}}, {46, {265, 277}}, {54, {304, 318}}, {60, {343, 359}}}
local T10 = {{14, {13, 15}}, {24, {19, 23}}, {34, {26, 32}}, {44, {44, 54}}, {54, {65, 79}}, {60, {82, 100}}}
local T11 = {{40, 115}, {48, 150}, {54, 190}, {60, 235}}
local T12 = {{20, 5}, {30, 10}, {40, 18}, {50, 32}, {60, 50}}
local T13 = {{1, 11}, {8, 21}, {16, 32}, {24, 44}, {32, 58}, {40, 80}, {48, 111}, {56, 138}, {60, 157}}
local T14 = {{1, 15}, {12, 35}, {22, 55}, {32, 85}, {42, 130}, {52, 185}, {60, 232}}

local function Rank60(level, list) -- list of {minLevel, value}
  local v = list[1][2]; local i
  for i = 1, table.getn(list) do if level >= list[i][1] then v = list[i][2] end end
  return v
end

local function InExecute(sim, a) return sim.t >= a.executeAt end

local function SwitchStance(sim, a, stance)
  if a.stance == stance then return end
  a.stance = stance
  a.stanceReady = sim.t + 1
  local keep = 5 * (a.char.talents["Tactical Mastery"] or 0)
  if a.rage > keep then sim:Count("rage.stanceLost", a.rage - keep); a.rage = keep end
  Recalc(a)
  if sim.log then sim:Log("Switched to "..stance.." stance") end
end

-- Can the ability be used in (or switched into) its stance with enough rage left?
local function StanceOK(sim, a, ab)
  if not ab.stances or ab.stances[a.stance] then return true end
  if sim.t < a.stanceReady then return false end
  return 5 * (a.char.talents["Tactical Mastery"] or 0) >= ab:Cost(a)
end

local function PhysicalAbility(sim, a, name, dmg, result)
  local done = Landed(result) and dmg * a.armorMult or 0
  sim:Damage(name, done, result)
  if sim.log then sim:Log(string.format("%s %s for %d  (rage %d)", name, result, done, a.rage)) end
  return done
end

local function StrikeDamage(sim, a, ab, w, dmg, canDodge, sameRoll, extraCrit)
  local result = SpellRoll(sim, a, w, canDodge, sameRoll, extraCrit, PROT_HIT[ab.name] and a.char.set.protHit or 0)
  AbilityResult(sim, a, ab.name, result)
  if Landed(result) then OnHitProcs(sim, a, w, true) end
  if result == DODGE then OpenOverpower(sim, a) end
  if result == CRIT then dmg = dmg * a.abilityCritMult; OnCrit(sim, a) end
  if not Landed(result) and ab.refund then AddRage(sim, a, ab:Cost(a) * 0.8, "refund") end
  local done = PhysicalAbility(sim, a, ab.name, dmg, result)
  if a.sweeping > 0 and a.targets > 1 and Landed(result) and ab.name ~= "Whirlwind" then
    a.sweeping = a.sweeping - 1; sim:Damage("Sweeping Strikes", done, result)
  end
  return result
end

local function BloodrageTick(sim, a) AddRage(sim, a, 1, "bloodrage"); Think(sim, a) end
local function RendTick(sim, a) sim:Damage("Rend", a.rendTick * a.dmgmod, "tick") end

local A = {}
W.Abilities = A

A["Bloodthirst"] = {name = "Bloodthirst", cd = 6, refund = true, talent = "Bloodthirst",
  Cost = function(self, a) return 30 - (a.char.set.strikeCost or 0) end,
  Cast = function(self, sim, a)
    local dmg = (200 + 0.35 * a.ap) * a.dmgmod * a.mh.mod
    StrikeDamage(sim, a, self, a.mh, dmg, true, false, 0)
  end}

A["Mortal Strike"] = {name = "Mortal Strike", cd = 6, refund = true, talent = "Mortal Strike",
  Cost = function(self, a) return 30 - (a.char.set.strikeCost or 0) end,
  Cast = function(self, sim, a)
    local pct = Rank60(a.char.level, T5)
    StrikeDamage(sim, a, self, a.mh, WeaponDamage(sim, a, a.mh, true) * pct * a.dmgmod * a.mh.mod, true, true, 0)
  end}

A["Whirlwind"] = {name = "Whirlwind", cd = 10, refund = false, stances = {berserker = true}, level = 36,
  Cost = function(self, a) return 25 - (a.char.set.brotherhood or 0) - (a.char.set.wwCost or 0) end,
  Cooldown = function(self, a) local r = a.char.talents["Ravager"] or 0; return 10 - (T1[r] or 0) end,
  Cast = function(self, sim, a)
    local n, i = min(a.targets, 4 + (a.char.set.wwTargets or 0))
    for i = 1, n do
      local dmg = WeaponDamage(sim, a, a.mh, true) * a.dmgmod * a.mh.mod
      local result = SpellRoll(sim, a, a.mh, true, true, 0)
      if Landed(result) then OnHitProcs(sim, a, a.mh, true, i > 1) end
      if i == 1 and result == DODGE then OpenOverpower(sim, a) end
      if result == CRIT then dmg = dmg * a.abilityCritMult; OnCrit(sim, a) end
      PhysicalAbility(sim, a, "Whirlwind", dmg, result)
    end
  end}

A["Overpower"] = {name = "Overpower", cd = 5, refund = true, stances = {battle = true}, level = 12,
  Cost = function(self, a) return 5 end,
  Usable = function(self, sim, a) return sim.t < a.dodgeUntil end,
  Cast = function(self, sim, a)
    a.dodgeUntil = 0
    if a.char.set.overpowerHaste then ApplyProcAura(sim, a, "OverpoweringRage") end
    local bonus = Rank60(a.char.level, T6)
    local dmg = (WeaponDamage(sim, a, a.mh, true) + bonus) * a.dmgmod * a.mh.mod
    StrikeDamage(sim, a, self, a.mh, dmg, false, true, 25 * (a.char.talents["Improved Overpower"] or 0))
  end}

A["Execute"] = {name = "Execute", cd = 0, refund = false, stances = {battle = true, berserker = true}, level = 24,
  Cost = function(self, a) local r = a.char.talents["Improved Execute"] or 0; return 15 - (T2[r] or 0) end,
  Usable = function(self, sim, a) return InExecute(sim, a) end,
  Cast = function(self, sim, a)
    local used = floor(a.rage)
    local base = Rank60(a.char.level, T7)
    local per = Rank60(a.char.level, T8)
    local cut = 1 + 0.25 * (a.char.talents["Precision Cut"] or 0)
    local dmg = (base + per * used * cut) * a.dmgmod * a.mh.mod
    local result = StrikeDamage(sim, a, self, a.mh, dmg, true, false, 0)
    if Landed(result) then SpendRage(sim, a, a.rage, "Execute (extra rage)") end
  end}

A["Slam"] = {name = "Slam", cd = 0, refund = true, level = 30,
  Cost = function(self, a) return 15 end,
  Usable = function(self, sim, a)
    -- Only start the cast early in the swing (reference: 50% of the swing left).
    return not a.mhEvent or (a.mhEvent.t - sim.t) >= 0.5 * (a.mhSwingLen or 0)
  end,
  CastTime = function(self, a) local r = a.char.talents["Improved Slam"] or 0; return 2.5 - (T3[r] or 0) end,
  Gcd = function(self, a) local r = a.char.talents["Improved Slam"] or 0; return 1.5 - (T3[r] or 0) end,
  Cast = function(self, sim, a)
    StrikeDamage(sim, a, self, a.mh, WeaponDamage(sim, a, a.mh, false) * a.dmgmod * a.mh.mod, true, true, 0)
  end}

A["Hamstring"] = {name = "Hamstring", cd = 0, refund = true, stances = {battle = true, berserker = true}, level = 8, minRage = 50,
  Cost = function(self, a) return 10 - (a.char.set.hamCost or 0) end,
  Cast = function(self, sim, a) StrikeDamage(sim, a, self, a.mh, 45 * a.dmgmod * a.mh.mod, true, true, 0) end}

A["Master Strike"] = {name = "Master Strike", cd = 30, refund = true, talent = "Master Strike",
  Cost = function(self, a) return 20 end,
  Cast = function(self, sim, a) StrikeDamage(sim, a, self, a.mh, WeaponDamage(sim, a, a.mh, true) * 0.35 * a.dmgmod * a.mh.mod, true, true, 0) end}

A["Rend"] = {name = "Rend", cd = 0, refund = true, stances = {battle = true, defensive = true}, level = 4,
  Cost = function(self, a) return 10 end,
  Usable = function(self, sim, a) return not a.auras["Rend"].active and not InExecute(sim, a) end,
  Cast = function(self, sim, a)
    local result = SpellRoll(sim, a, a.mh, true, true, 0)
    sim:Damage("Rend", 0, result)
    if not Landed(result) then AddRage(sim, a, 8, "refund"); if result == DODGE then OpenOverpower(sim, a) end; return end
    a.auras["Rend"]:Apply(22)
    a.rendTick = 21 * (1 + 0.1 * (a.char.talents["Improved Rend"] or 0))
    local k
    for k = 1, 7 do sim:After(3 * k, RendTick, a) end
  end}

A["Sweeping Strikes"] = {name = "Sweeping Strikes", buff = true, cd = 30, refund = false, talent = "Sweeping Strikes", stances = {battle = true, berserker = true},
  Cost = function(self, a) return 20 - (a.char.set.cdCost or 0) end,
  Usable = function(self, sim, a) return a.targets > 1 end,
  Cast = function(self, sim, a) a.sweeping = 5 end}

A["Death Wish"] = {name = "Death Wish", buff = true, cd = 180, refund = false, talent = "Death Wish",
  Cost = function(self, a) return max(0, 10 - (a.char.set.cdCost or 0)) end,
  Cast = function(self, sim, a) a.auras["Death Wish"]:Apply(30) end}

A["Recklessness"] = {name = "Recklessness", buff = true, cd = 1800, refund = false, stances = {berserker = true}, level = 50, noRage = true,
  Cost = function(self, a) return 0 end,
  Cooldown = function(self, a) return 1800 - 240 * (a.char.talents["Improved Disciplines"] or 0) end,
  Cast = function(self, sim, a) a.auras["Recklessness"]:Apply(15) end}

A["Berserker Rage"] = {name = "Berserker Rage", buff = true, cd = 30, refund = false, stances = {berserker = true}, level = 32, talent = "Improved Berserker Rage",
  Cost = function(self, a) return 0 end,
  Cast = function(self, sim, a) AddRage(sim, a, 5 * (a.char.talents["Improved Berserker Rage"] or 0), "berserkerRage") end}

A["Bloodrage"] = {name = "Bloodrage", buff = true, cd = 60, refund = false, offGcd = true, level = 10,
  Cost = function(self, a) return 0 end,
  Cast = function(self, sim, a)
    local r = a.char.talents["Improved Bloodrage"] or 0
    AddRage(sim, a, 10 + (T4[r] or 0), "bloodrage")
    local k
    for k = 1, 10 do sim:After(k, BloodrageTick, a) end
    a.auras["Bloodrage"]:Apply(10)
    if a.cfg.enrageOnBloodrage and (a.char.talents["Enrage"] or 0) > 0 then a.auras["Enrage"]:Apply(8) end
  end}

A["Battle Shout"] = {name = "Battle Shout", buff = true, cd = 0, refund = false,
  Cost = function(self, a) return 10 * (1 - (a.char.set.shoutCostPct or 0) / 100) end,
  Usable = function(self, sim, a) return not a.auras["Battle Shout"].active end,
  Cast = function(self, sim, a) a.auras["Battle Shout"]:Apply(a.shoutDuration) end}

A["Shield Slam"] = {name = "Shield Slam", cd = 6, refund = true, talent = "Shield Slam", needsShield = true,
  Cost = function(self, a) return 20 end,
  Cooldown = function(self, a) local r = a.char.talents["Improved Shield Slam"] or 0; return 6 - 0.75 * r end,
  Cast = function(self, sim, a)
    local base = Rank60(a.char.level, T9)
    local dmg = (sim.rng:Range(base[1], base[2]) + 2 * a.blockValue + 0.2 * a.ap) * a.dmgmod * a.mh.mod
    StrikeDamage(sim, a, self, a.mh, dmg, true, true, 0)
    local r = a.char.talents["Improved Shield Slam"] or 0
    if r > 0 then a.bonusBlock = 35 * r; a.bonusBlockUntil = sim.t + 4.5 end
  end}

A["Revenge"] = {name = "Revenge", cd = 6, refund = true, level = 14, stances = {defensive = true},
  Cost = function(self, a) return 5 end,
  Cooldown = function(self, a) local r = a.char.talents["Improved Revenge"] or 0; return 6 - 0.5 * r end,
  Usable = function(self, sim, a) return sim.t < a.revengeUntil end,
  Cast = function(self, sim, a)
    a.revengeUntil = 0
    local base = Rank60(a.char.level, T10)
    local rp = a.char.talents["Reprisal"] or 0
    local dmg = (sim.rng:Range(base[1], base[2]) + (a.char.set.revenge or 0)) * (1 + 0.25 * rp) * a.dmgmod * a.mh.mod
    local result = StrikeDamage(sim, a, self, a.mh, dmg, true, false, 0)
    if Landed(result) and rp > 0 and sim.rng:Next() * 100 < 50 * rp then AddRage(sim, a, 5, "reprisal") end
  end}

A["Concussion Blow"] = {name = "Concussion Blow", cd = 20, refund = false, talent = "Concussion Blow",
  Cost = function(self, a) return 0 end,
  Cast = function(self, sim, a)
    local dmg = Rank60(a.char.level, T11) * a.dmgmod * a.mh.mod
    local result = SpellRoll(sim, a, a.mh, true, false, 0)
    if Landed(result) then OnHitProcs(sim, a, a.mh, true) end
    if result == DODGE then OpenOverpower(sim, a) end
    if result == CRIT then dmg = dmg * a.abilityCritMult; OnCrit(sim, a) end
    local done = Landed(result) and dmg or 0   -- ignores armor
    sim:Damage("Concussion Blow", done, result)
    if sim.log then sim:Log(string.format("Concussion Blow %s for %d  (rage %d)", result, done, a.rage)) end
    AddRage(sim, a, 10, "concussionBlow")
  end}

A["Sunder Armor"] = {name = "Sunder Armor", cd = 0, refund = true, level = 10,
  Cost = function(self, a) return 10 - (a.char.set.brotherhood or 0) end,
  Usable = function(self, sim, a)
    if a.cfg.debuffs and (a.cfg.debuffs.sunder or a.cfg.debuffs.iea) then return false end
    local au = a.auras["Sunder Armor"]
    local m = a.mods["Sunder Armor"]
    return not au.active or (m and m.stacks or 0) < 5 or (au.expiry and au.expiry.t - sim.t < 3)
  end,
  Cast = function(self, sim, a)
    local result = SpellRoll(sim, a, a.mh, true, true, 0)
    sim:Damage("Sunder Armor", 0, result)
    if result == DODGE then OpenOverpower(sim, a) end
    if not Landed(result) then AddRage(sim, a, self:Cost(a) * 0.8, "refund"); return end
    OnHitProcs(sim, a, a.mh, true)
    local m = a.mods["Sunder Armor"]
    local stacks = min(((m and m.stacks) or 0) + 1, 5)
    a.mods["Sunder Armor"] = {armor = 450, stacks = stacks}
    a.auras["Sunder Armor"]:Apply(30)
    Recalc(a)
  end}

-- Heroic Strike / Cleave are queued on the next main-hand swing.
local function HSInfo(a)
  local level = a.char.level
  if a.targets > 1 then
    return {name = "Cleave", cost = 20 - (a.char.talents["Ravager"] or 0), bonus = Rank60(level, T12)}
  end
  return {name = "Heroic Strike", cost = 15 - (a.char.talents["Improved Heroic Strike"] or 0) - (a.char.set.brotherhood or 0),
    bonus = Rank60(level, T13)}
end

---------------------------------------------------------------------------
-- Rotations: ordered priority lists for the normal and execute phases.
---------------------------------------------------------------------------
local ROTATIONS = {
  fury_dw = {stance = "berserker",
    normal = {"Battle Shout", "Bloodrage", "Death Wish", "Recklessness", "Berserker Rage", "Bloodthirst", "Whirlwind"},
    exec = {"Bloodrage", "Death Wish", "Recklessness", "Berserker Rage", "Bloodthirst", "Execute"}},
  fury_2h = {stance = "berserker",
    normal = {"Battle Shout", "Bloodrage", "Death Wish", "Recklessness", "Berserker Rage", "Bloodthirst", "Whirlwind"},
    exec = {"Bloodrage", "Death Wish", "Recklessness", "Berserker Rage", "Bloodthirst", "Execute"}},
  arms = {stance = "battle",
    normal = {"Battle Shout", "Bloodrage", "Sweeping Strikes", "Death Wish", "Recklessness", "Mortal Strike", "Whirlwind", "Overpower", "Slam", "Master Strike"},
    exec = {"Bloodrage", "Death Wish", "Recklessness", "Mortal Strike", "Execute"}},
  prot = {stance = "defensive",
    normal = {"Battle Shout", "Bloodrage", "Shield Slam", "Revenge", "Bloodthirst", "Concussion Blow", "Sunder Armor", "Death Wish", "Master Strike"},
    exec = {"Battle Shout", "Bloodrage", "Shield Slam", "Revenge", "Bloodthirst", "Concussion Blow", "Sunder Armor", "Death Wish", "Master Strike"}},
}

function W.ResolveRotation(char, cfg)
  local key = cfg.rotation or "auto"
  if key == "auto" then
    if char.shield then key = "prot"
    elseif char.mh.twoHand then key = (char.talents["Mortal Strike"] and "arms") or "fury_2h"
    else key = "fury_dw" end
  end
  if key == "custom" then
    local normal, exec = {"Battle Shout"}, {}
    local i, name
    for i = 1, table.getn(W.CUSTOM_ABILITIES) do
      name = W.CUSTOM_ABILITIES[i]
      if cfg.custom and cfg.custom[name] then table.insert(normal, name) end
    end
    -- Execute phase: cooldowns, then Bloodthirst/Mortal Strike, then Execute (as the reference sim).
    local EXEC_KEEP = {["Bloodrage"]=1, ["Death Wish"]=1, ["Recklessness"]=1, ["Berserker Rage"]=1, ["Bloodthirst"]=2, ["Mortal Strike"]=2, ["Shield Slam"]=2}
    local tier
    for tier = 1, 2 do
      for i = 2, table.getn(normal) do if EXEC_KEEP[normal[i]] == tier then table.insert(exec, normal[i]) end end
    end
    table.insert(exec, "Execute")
    local stance = "berserker"
    if cfg.custom and (cfg.custom["Overpower"] or cfg.custom["Rend"]) and not cfg.custom["Whirlwind"] then stance = "battle" end
    if cfg.custom and cfg.custom["Revenge"] and not cfg.custom["Whirlwind"] and not cfg.custom["Overpower"] then stance = "defensive" end
    return {key = "custom", stance = stance, normal = normal, exec = exec}
  end
  if key == "furyprot" then key = "prot" end
  local r = ROTATIONS[key] or ROTATIONS.fury_dw
  return {key = key, stance = r.stance, normal = r.normal, exec = r.exec, partial = r.partial}
end

-- Drops abilities the character does not have (talent or level).
local function Known(char, list)
  local out, i, ab = {}
  for i = 1, table.getn(list) do
    ab = A[list[i]]
    if ab and (not ab.talent or (char.talents[ab.talent] or 0) > 0) and (not ab.level or char.level >= ab.level) and (not ab.needsShield or char.shield) then table.insert(out, ab) end
  end
  return out
end

---------------------------------------------------------------------------
-- Decisions.
---------------------------------------------------------------------------
local function React(sim, a) return sim.rng:Range(a.reactMin, a.reactMax) end

local function Ready(sim, a, ab) return (a.cdReady[ab.name] or 0) <= sim.t + 0.00001 end

local function Usable(sim, a, ab)
  if not Ready(sim, a, ab) then return false end
  if not ab.offGcd and sim.t < a.gcdEnd then return false end
  local cost = ab:Cost(a)
  if a.wrathDiscount and cost > 0 and not ab.buff then cost = max(0, cost - 5) end
  if a.rage < cost then return false end
  if ab.minRage and a.rage < ab.minRage then return false end
  if not StanceOK(sim, a, ab) then return false end
  if ab.Usable and not ab:Usable(sim, a) then return false end
  return true
end

local function FinishCast(sim, a)
  local ab = a.casting
  a.casting = nil
  ab:Cast(sim, a)
  sim:Count(Key("cast.", ab.name))
  DoExtraAttack(sim, a)
  if a.mhDue then a.mhDue = nil; MainHandSwing(sim, a) end
  if a.ohDue then a.ohDue = nil; OffHandSwing(sim, a) end
  Think(sim, a)
end

local function Use(sim, a, ab)
  if ab.stances and not ab.stances[a.stance] then
    local target = ab.stances.berserker and "berserker" or (ab.stances.battle and "battle" or "defensive")
    SwitchStance(sim, a, target)
  end
  local cost = ab:Cost(a)
  local offensive = cost > 0 and not ab.buff
  if offensive and a.wrathDiscount then cost = max(0, cost - 5); a.wrathDiscount = nil end
  if cost > 0 then SpendRage(sim, a, cost, ab.name) end
  if offensive and a.char.set.wrathDiscount and sim.rng:Next() * 100 < 20 then a.wrathDiscount = true end
  a.cdReady[ab.name] = sim.t + (ab.Cooldown and ab:Cooldown(a) or ab.cd)
  if not ab.offGcd then a.gcdEnd = sim.t + (ab.Gcd and ab:Gcd(a) or 1.5) end
  if ab.CastTime then
    a.casting = ab
    if sim.log then sim:Log("Casting "..ab.name) end
    sim:After(ab:CastTime(a), FinishCast, a)
    return
  end
  ab:Cast(sim, a)
  sim:Count(Key("cast.", ab.name))
  if ab.buff then if sim.log then sim:Log(ab.name.." used  (rage "..floor(a.rage)..")") end end
  DoExtraAttack(sim, a)
end

local function Act(sim, a)
  local ab = a.pendingAb
  a.pending = nil; a.pendingAb = nil
  if not a.casting and Usable(sim, a, ab) then Use(sim, a, ab) end
  Think(sim, a)
end

local function QueueHS(sim, a)
  a.hsPending = nil
  if a.queued or InExecute(sim, a) then return end
  local q = a.hsInfo
  if a.rage >= q.cost and a.rage >= a.cfg.hsRage then a.queued = q; if sim.log then sim:Log(q.name.." queued  (rage "..floor(a.rage)..")") end end
end

local function Wake(sim, a) a.wakeEv = nil; Think(sim, a) end

Think = function(sim, a)
  if a.useHS and not a.queued and not a.hsPending and not InExecute(sim, a) then
    local q = a.hsInfo
    if a.rage >= q.cost and a.rage >= a.cfg.hsRage then a.hsPending = sim:After(React(sim, a), QueueHS, a) end
  end
  if a.pending or a.casting then return end
  -- After a cooldown pulled us out of the rotation's stance, go back as soon as we can.
  if a.stance ~= a.rot.stance and sim.t >= a.stanceReady then SwitchStance(sim, a, a.rot.stance) end
  local list = InExecute(sim, a) and a.execList or a.normalList
  local i, ab
  for i = 1, table.getn(list) do
    ab = list[i]
    if Usable(sim, a, ab) then a.pendingAb = ab; a.pending = sim:After(React(sim, a), Act, a); return end
  end
  -- Nothing to do now: wake up when a cooldown, the global cooldown or the execute phase ends.
  local wake, now, t = nil, sim.t + 0.00001, nil
  for i = -2, table.getn(list) do
    if i == -2 then t = a.gcdEnd elseif i == -1 then t = a.executeAt elseif i == 0 then t = a.stanceReady else t = a.cdReady[list[i].name] end
    if t and t > now and (not wake or t < wake) then wake = t end
  end
  if wake and (not a.wakeEv or a.wakeEv.dead or a.wakeEv.t > wake) then
    if a.wakeEv then a.wakeEv.dead = true end
    a.wakeEv = sim:At(wake, Wake, a)
  end
end

---------------------------------------------------------------------------
-- The boss hitting you (tanking): avoidance, rage from damage taken, Revenge.
---------------------------------------------------------------------------
local function BossSwing(sim, a)
  local c, cfg = a.char, a.cfg
  a.bossEvent = sim:After(cfg.bossSpeed, BossSwing, a)
  local diff = (cfg.targetLevel * 5) - c.defense           -- boss weapon skill vs your defense
  local roll = sim.rng:Next() * 100
  local tmp = max(5 - diff * 0.04, 0)
  if roll < tmp then sim:Count("boss.miss"); return end
  tmp = tmp + max(c.dodge - 0.6, 0)
  if roll < tmp then sim:Count("boss.dodge"); a.revengeUntil = sim.t + 5; Think(sim, a); return end
  tmp = tmp + max(c.parry - 0.6, 0)
  if roll < tmp then sim:Count("boss.parry"); a.revengeUntil = sim.t + 5; Think(sim, a); return end
  local blocked = false
  if c.shield then
    local bonus = (a.bonusBlockUntil and sim.t < a.bonusBlockUntil) and (a.bonusBlock or 0) or 0
    tmp = tmp + max(c.block - 0.6, 0) + bonus
    if roll < tmp then blocked = true end
    a.bonusBlockUntil = nil
  end
  local dmg = sim.rng:Range(cfg.bossMin, cfg.bossMax)
  local crit = false
  if not blocked then
    tmp = tmp + max(5 + diff * 0.04, 0)
    if roll < tmp then crit = true; dmg = dmg * 2
    else tmp = tmp + 15; if roll < tmp then dmg = dmg * 1.5; sim:Count("boss.crushing") end end
  end
  local armor = c.playerArmor
  dmg = dmg * (1 - min(armor / (armor + 400 + 85 * cfg.targetLevel), 0.75))
  if a.stance == "defensive" then dmg = dmg * 0.9 end
  if blocked then
    dmg = max(dmg - a.blockValue, 0); sim:Count("boss.block"); a.revengeUntil = sim.t + 5
    local ss = c.talents["Shield Specialization"] or 0
    if ss > 0 then AddRage(sim, a, ss, "shieldSpec") end
  elseif crit then
    sim:Count("boss.crit")
    if (c.talents["Enrage"] or 0) > 0 then a.auras["Enrage"]:Apply(8) end
  else sim:Count("boss.hit") end
  sim:Count("damageTaken", dmg)
  AddRage(sim, a, dmg / a.rageConv * 2.5, "damageTaken")
  if c.set.mightDamaged and dmg > 0 and sim.rng:Next() * 100 < 20 then AddRage(sim, a, 1, "setBonus") end
  Think(sim, a)
end

function W.IsTanking(char, cfg)
  if cfg.tanking == "on" then return true end
  if cfg.tanking == "off" then return false end
  return char.shield and true or false
end

---------------------------------------------------------------------------
-- Model interface for AshenSim.RunFight.
---------------------------------------------------------------------------
function W.Setup(sim, char, cfg)
  local rot = W.ResolveRotation(char, cfg)
  local a = {char = char, cfg = cfg, mh = char.mh, oh = char.oh, mods = {}, auras = sim.auras, cdReady = {},
    rage = cfg.startRage or 0, gcdEnd = 0, stanceReady = 0, dodgeUntil = 0, extra = 0, sweeping = 0,
    targets = max(1, cfg.targets or 1), front = (cfg.position == "front"), def = cfg.targetLevel * 5,
    stance = rot.stance, rot = rot, revengeUntil = 0}
  a.rageCap = 100 + 10 * (char.talents["Boundless Anger"] or 0)
  a.rageConv = RageConversion(char.level)
  a.flurryRank = char.talents["Flurry"] or 0
  a.abilityCritMult = 1 + 1 * (1 + 0.1 * (char.talents["Impale"] or 0) + (char.set.abilityCrit or 0))
  a.reactMin = max(0, (cfg.reaction or 250) - 50) / 1000; a.reactMax = ((cfg.reaction or 250) + 50) / 1000
  a.executeAt = cfg.duration * (1 - (cfg.executePct or 20) / 100)
  a.useHS = cfg.useHeroicStrike ~= false
  a.hsInfo = HSInfo(a)
  a.normalList = Known(char, rot.normal)
  a.execList = Known(char, rot.exec)
  a.shoutDuration = 120 * (1 + 0.12 * (char.talents["Booming Voice"] or 0))
  local shoutAP = floor(Rank60(char.level, T14) * (1 + 0.05 * (char.talents["Improved Shouts"] or 0))) + (char.set.battleShout or 0)
  ModAura(sim, a, "Battle Shout", {stats = {ap = shoutAP}})
  ModAura(sim, a, "Death Wish", {})
  ModAura(sim, a, "Enrage", {})
  ModAura(sim, a, "Recklessness", {stats = {crit = 100}})
  local fl = S.NewAura(sim, "Flurry", nil, nil)
  local hasteMod = {haste = 5 + 5 * a.flurryRank}
  fl.onGain = function(s, au) a.mods["Flurry"] = hasteMod; Recalc(a) end
  fl.onFade = function(s, au) a.mods["Flurry"] = nil; Recalc(a) end
  S.NewAura(sim, "Deep Wounds")
  S.NewAura(sim, "Bloodrage")
  S.NewAura(sim, "Rend")
  S.NewAura(sim, "Sunder Armor", nil, function(s, au) a.mods["Sunder Armor"] = nil; Recalc(a) end)
  a.tanking = W.IsTanking(char, cfg)
  Recalc(a)
  return a
end

function W.Start(sim, a)
  -- Battle Shout goes up before the pull.
  if a.char.level >= 1 then a.auras["Battle Shout"]:Apply(a.shoutDuration) end
  ScheduleMH(sim, a, 0)
  if a.oh then a.ohEvent = sim:At(a.oh.speed / a.haste / 2, OffHandSwing, a) end
  sim:At(a.executeAt, Think, a)
  if a.tanking then a.bossEvent = sim:At(sim.rng:Range(0, a.cfg.bossSpeed), BossSwing, a) end
  Think(sim, a)
end

function W.Finish(sim, a)
  sim:Count("rage.end", a.rage)
end

-- Reads the saved settings for the class, filling in anything missing.
function W.GetSettings()
  AshenBuildsDB = AshenBuildsDB or {}
  AshenBuildsDB.simSettings = AshenBuildsDB.simSettings or {}
  local saved = AshenBuildsDB.simSettings.Warrior
  local d = W.DefaultSettings()
  if not saved then AshenBuildsDB.simSettings.Warrior = d; return d end
  if saved.boss == nil then saved.boss = "custom" end   -- settings from before the boss list
  local k, v
  for k, v in pairs(d) do if saved[k] == nil then saved[k] = v end end
  return saved
end

-- Accuracy summary for the UI: HIGH only when every equipped effect and the
-- rotation are fully modelled.
function W.Accuracy(char, cfg)
  local rot = W.ResolveRotation(char, cfg)
  local reasons = {}
  local i
  for i = 1, table.getn(char.unsupported) do table.insert(reasons, "SIM EFFECT NOT IMPLEMENTED: "..char.unsupported[i]) end
  if rot.partial then table.insert(reasons, rot.partial) end
  if cfg.position == "front" then table.insert(reasons, "Boss parry chance is a setting, not confirmed for Turtle.") end
  if (rot.key == "prot" or (rot.key == "custom" and cfg.custom and cfg.custom["Revenge"])) and not W.IsTanking(char, cfg) then
    table.insert(reasons, "Revenge needs the boss attacking you - turn on Tanking in the settings.")
  end
  return (table.getn(reasons) == 0) and "HIGH" or "PARTIAL", reasons, rot
end
