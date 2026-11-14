-- Step 3: reads your character (what the game tells us) and works out the main role,
-- the role mix for the play mode, the target level and the melee miss chance.
-- Nothing here scores items yet.

local AG = AdeGear
local Char = {}
AG.Char = Char

-- role of each talent tree, in the order of the trees in the talent window
local TREE_ROLE = {
  WARRIOR = { "dmg", "dmg", "tank" },
  PALADIN = { "heal", "tank", "dmg" },
  PRIEST = { "dmg", "heal", "dmg" },   -- Discipline is a damage tree on this server
  SHAMAN = { "dmg", "dmg", "heal" },
  DRUID = { "dmg", "feral", "heal" },
  HUNTER = { "dmg", "dmg", "dmg" },
  ROGUE = { "dmg", "dmg", "dmg" },
  MAGE = { "dmg", "dmg", "dmg" },
  WARLOCK = { "dmg", "dmg", "dmg" },
}

local ROLE_NAME = { tank = "Tank", heal = "Healer", dmg = "Damage" }

-- calls a game function that may not exist on this client
local function Try(fn, a)
  if type(fn) ~= "function" then return nil end
  local ok, r1, r2, r3, r4, r5 = pcall(fn, a)
  if ok then return r1, r2, r3, r4, r5 end
  return nil
end

----------------------------------------------------------------------
-- Role from the talent points
----------------------------------------------------------------------

-- returns { role = "tank"|"heal"|"dmg", trees = { {name, points} ... }, main = tree index,
--           noPoints = true when nothing is spent, feral = true when a Druid is in the feral tree }
function Char.Spec(class)
  local spec = { trees = {}, role = "dmg", main = nil }
  local n = Try(GetNumTalentTabs) or 0
  local best, bestPoints = nil, 0
  for i = 1, n do
    local name, icon, points = GetTalentTabInfo(i)
    points = points or 0
    table.insert(spec.trees, { name = name, points = points })
    if points > bestPoints then best, bestPoints = i, points end
  end
  if not best then
    spec.noPoints = true
    local cd = AG.ClassData and AG.ClassData[class]
    if cd and cd.default then spec.role = cd.default end
    return spec
  end
  spec.main = best
  local role = TREE_ROLE[class] and TREE_ROLE[class][best] or "dmg"
  local byTalents, info = Char.RoleFromTalents(class)
  if byTalents then
    spec.role = byTalents
    spec.byTalents = info
    return spec
  end
  if role == "feral" then
    -- bear or cat depends on how the Druid plays; not decided here
    spec.feral = true
    role = "dmg"
  end
  spec.role = role
  return spec
end

-- Role from the talents you really picked (not from the tree). The class file lists talents that
-- point to a role, each with a weight per rank: roleTalents = { ["Searing Light"] = { dmg = 2 } }.
-- Returns role, info or nil when the class has no list or AdeTalents is not ready.
--   info = { scores = { tank, heal, dmg }, counted = { { name, rank, w } ... }, low = true when too
--   few points are spent to tell, then the class default role is used }
function Char.RoleFromTalents(class)
  local cd = AG.ClassData and AG.ClassData[class]
  if not cd or not cd.roleTalents then return nil end
  if not (AdeTalents and AdeTalents.IsReady and AdeTalents.IsReady() and AdeTalents.GetRank) then return nil end
  local score = { tank = 0, heal = 0, dmg = 0 }
  local counted = {}
  for name, w in pairs(cd.roleTalents) do
    local r = AdeTalents.GetRank(name)
    if r and r > 0 then
      for role, x in pairs(w) do score[role] = score[role] + x * r end
      table.insert(counted, { name = name, rank = r, w = w })
    end
  end
  table.sort(counted, function(a, b) return a.name < b.name end)
  local info = { scores = score, counted = counted }
  local default = cd.default or "dmg"
  local best, bestScore, tie = nil, 0, false
  local order = { "tank", "heal", "dmg" }
  for i = 1, 3 do
    local s = score[order[i]]
    if s > bestScore + 0.0001 then
      best, bestScore, tie = order[i], s, false
    elseif s > 0 and math.abs(s - bestScore) <= 0.0001 then
      tie = true
    end
  end
  if not best or bestScore < (cd.roleMin or 3) then
    info.low = true
    return default, info
  end
  if tie then
    info.tie = true
    return default, info
  end
  return best, info
end

-- Style inside the damage role (Hunter: ranged or melee), from the talents you picked.
-- styleTalents = { ["Lethal Shots"] = { ranged = 1 }, ... }; the style with more points wins,
-- too few points or a tie: styleDefault. Returns style, info, or nil when the class has no styles.
function Char.StyleFromTalents(class)
  local cd = AG.ClassData and AG.ClassData[class]
  if not cd or not (cd.styleTalents or cd.styleTrees) then return nil end
  local default = cd.styleDefault or "dmg"
  local info = { scores = {}, counted = {} }
  if cd.styleTrees then
    -- the style is the talent tree with the most points (Mage: arcane, fire or frost)
    local n = Try(GetNumTalentTabs) or 0
    local best, bestPoints, tie = nil, 0, false
    for t = 1, n do
      local _, _, points = GetTalentTabInfo(t)
      points = points or 0
      local style = cd.styleTrees[t]
      if style then
        info.scores[style] = points
        if points > bestPoints then best, bestPoints, tie = style, points, false
        elseif points == bestPoints and points > 0 then tie = true end
      end
    end
    if not best or bestPoints < (cd.styleMin or 3) then info.low = true return default, info end
    if tie then info.tie = true return default, info end
    return best, info
  end
  if not (AdeTalents and AdeTalents.IsReady and AdeTalents.IsReady() and AdeTalents.GetRank) then
    info.notReady = true
    return default, info
  end
  for name, w in pairs(cd.styleTalents or {}) do
    local r = AdeTalents.GetRank(name)
    if r and r > 0 then
      for style, x in pairs(w) do info.scores[style] = (info.scores[style] or 0) + x * r end
      table.insert(info.counted, { name = name, rank = r, w = w })
    end
  end
  table.sort(info.counted, function(a, b) return a.name < b.name end)
  local best, bestScore, tie = nil, 0, false
  for style, s in pairs(info.scores) do
    if s > bestScore + 0.0001 then
      best, bestScore, tie = style, s, false
    elseif math.abs(s - bestScore) <= 0.0001 and s > 0 then
      tie = true
    end
  end
  if not best or bestScore < (cd.styleMin or 3) then info.low = true return default, info end
  if tie then info.tie = true return default, info end
  return best, info
end

local ccache = nil

-- attack power and the weapons you hold, for classes whose values follow them (cached for a second)
function Char.Combat(c)
  local now = GetTime()
  if ccache and ccache.class == c.class and now - ccache.t < 1 then
    for k, v in pairs(ccache.v) do c[k] = v end
    return c
  end
  local v = {}
  local ab, ap1, ap2 = Try(UnitAttackPower, "player")
  if ab then v.ap = ab + (ap1 or 0) + (ap2 or 0) end
  local rab, rap1, rap2 = Try(UnitRangedAttackPower, "player")
  if rab then v.rap = rab + (rap1 or 0) + (rap2 or 0) end
  v.rangedItem = AG.Items.FromSlot(18)
  v.ammoItem = AG.Items.FromSlot(0)
  v.mainItem = AG.Items.FromSlot(16)
  v.rangedDps = 0
  if v.rangedItem and v.rangedItem.weapon and v.rangedItem.weapon.dps then v.rangedDps = v.rangedItem.weapon.dps end
  if v.ammoItem and v.ammoItem.ammoDps then v.rangedDps = v.rangedDps + v.ammoItem.ammoDps end
  v.mainDps = 0
  if v.mainItem and v.mainItem.weapon and v.mainItem.weapon.dps then
    v.mainDps = v.mainItem.weapon.dps
    v.mainSpeed = v.mainItem.weapon.speed
  end
  v.rangedWeaponDps = 0
  if v.rangedItem and v.rangedItem.weapon and v.rangedItem.weapon.dps then
    v.rangedWeaponDps = v.rangedItem.weapon.dps
    v.rangedSpeed = v.rangedItem.weapon.speed
  end
  v.ammoDps = (v.ammoItem and v.ammoItem.ammoDps) or 0
  v.offItem = AG.Items.FromSlot(17)
  v.offDps = 0
  if v.offItem and v.offItem.weapon and v.offItem.weapon.dps then
    v.offDps = v.offItem.weapon.dps
    v.offSpeed = v.offItem.weapon.speed
  end
  local ok, stat, eff = pcall(UnitStat, "player", 2)
  if ok and stat then v.agility = eff or stat end
  ccache = { class = c.class, t = now, v = v }
  for k, x in pairs(v) do c[k] = x end
  return c
end

-- the same character with another item in a weapon slot (16 main hand, 17 off hand, 18 ranged, 0 ammo);
-- item = nil empties the slot. A two-hander also empties the off hand. Works on a copy made by the caller.
function Char.Override(c, slot, item)
  local w = item and item.weapon
  if slot == 16 then
    c.mainItem = item
    c.mainDps = (w and w.dps) or 0
    c.mainSpeed = w and w.speed
    if item and item.slot == "TWOHAND" then
      c.offItem = nil
      c.offDps = 0
      c.offSpeed = nil
    end
  elseif slot == 17 then
    c.offItem = item
    c.offDps = (w and w.dps) or 0
    c.offSpeed = w and w.speed
  elseif slot == 18 then
    c.rangedItem = item
    c.rangedWeaponDps = (w and w.dps) or 0
    c.rangedSpeed = w and w.speed
    c.rangedDps = c.rangedWeaponDps + (c.ammoDps or 0)
  elseif slot == 0 then
    c.ammoItem = item
    c.ammoDps = (item and item.ammoDps) or 0
    c.rangedDps = (c.rangedWeaponDps or 0) + c.ammoDps
  end
  return c
end

----------------------------------------------------------------------
-- Play mode, role mix, target level
----------------------------------------------------------------------

-- the share of damage that a tank or healer also counts while soloing:
-- full up to level 10, then falling in a straight line to nothing at the chosen level
function Char.DamageShare(level)
  if AG.Get("playstyle") ~= 1 or not AG.Get("leveling") then return 0 end
  local top = AG.Get("fadeLevel")
  if level >= top then return 0 end
  local f = (top - level) / (top - 10)
  if f > 1 then f = 1 end
  return (AG.Get("damageShare") / 100) * f
end

-- { tank, heal, dmg } shares that add up to 1
function Char.RoleMix(role, level)
  if role == "dmg" then return { tank = 0, heal = 0, dmg = 1 } end
  local share = Char.DamageShare(level)
  local mix = { tank = 0, heal = 0, dmg = share }
  mix[role] = 1 - share
  return mix
end

-- level of the enemy the hit and defense numbers are worked out against
function Char.TargetLevel(level)
  local mode = AG.Get("playstyle")
  local t
  if mode >= 3 then t = 63
  elseif mode == 2 then t = level + 2
  else t = level + 1 end
  if t > 63 then t = 63 end
  return t
end

----------------------------------------------------------------------
-- Melee miss chance with a white hit (one weapon), rules of the Turtle / Octo sheet:
-- 5% plus 0.2% for every point the target's defense (5 x level) is above your weapon skill.
-- Rows of the sheet (target level 63): skill 300 = 8%, 305 = 7%, 315 = 5%.
-- The sheet stops at a gap of 15 points, beyond it the number is an extrapolation.
-- The hit cap is the same number (new rules: cap = miss chance).
----------------------------------------------------------------------

function Char.MeleeMiss(skill, targetLevel)
  local gap = targetLevel * 5 - skill
  if gap < 0 then gap = 0 end
  return 5 + 0.2 * gap, gap > 15
end

----------------------------------------------------------------------
-- Gear totals: stats of everything you wear, set bonuses counted once per set
----------------------------------------------------------------------

local SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }

function Char.GearTotals(getEquipped)
  getEquipped = getEquipped or AG.Items.FromSlot
  local total, count, setDone, sets = {}, 0, {}, {}
  local function add(stats)
    for k, v in pairs(stats) do total[k] = (total[k] or 0) + v end
  end
  for i = 1, table.getn(SLOTS) do
    local it = getEquipped(SLOTS[i])
    if it then
      count = count + 1
      add(it.stats)
      -- worn pieces per set, counted here instead of trusting the number in a tooltip
      if it.set and it.set.name then sets[it.set.name] = (sets[it.set.name] or 0) + 1 end
      if it.set and it.set.name and not setDone[it.set.name] then
        setDone[it.set.name] = true
        for j = 1, table.getn(it.set.bonuses) do
          if it.set.bonuses[j].active then add(it.set.bonuses[j].stats) end
        end
      end
    end
  end
  return total, count, sets
end

----------------------------------------------------------------------
-- Everything in one table
----------------------------------------------------------------------

-- the light part: class, level, role, mix, target level (cheap, used on every item hover)
function Char.Basic()
  local _, class = UnitClass("player")
  local level = UnitLevel("player")
  local c = { class = class, level = level }
  c.spec = Char.Spec(class)
  c.role = c.spec.role
  local forced = AG.Get("role")
  if forced == "tank" or forced == "heal" or forced == "dmg" then
    c.role = forced
    c.forced = true
  end
  c.mix = Char.RoleMix(c.role, level)
  c.target = Char.TargetLevel(level)
  c.style, c.styleInfo = Char.StyleFromTalents(class)
  local okA, _, effA = pcall(UnitArmor, "player")
  if okA and effA then c.armor = effA end
  local okH, hp = pcall(UnitHealthMax, "player")
  if okH and hp then c.health = hp end
  if AG.Races then c.race = AG.Races.Current() end
  return c
end

function Char.Read()
  local c = Char.Basic()
  local class, level = c.class, c.level

  local mb, mm, ob, om = UnitAttackBothHands("player")
  c.mainSkill = (mb or 0) + (mm or 0)
  -- off hand skill only counts when a weapon is held there
  local oh = AG.Items.FromSlot(17)
  if oh and oh.weapon and ob and ob > 0 then c.offSkill = ob + (om or 0) end
  local rb, rm = Try(UnitRangedAttack, "player")
  if rb then c.rangedSkill = rb + (rm or 0) end
  local db, dm = Try(UnitDefense, "player")
  if db then c.defense = db + (dm or 0) end
  c.miss, c.missGuess = Char.MeleeMiss(c.mainSkill, c.target)

  local ab, ap1, ap2 = Try(UnitAttackPower, "player")
  if ab then c.ap = ab + (ap1 or 0) + (ap2 or 0) end
  local rab, rap1, rap2 = Try(UnitRangedAttackPower, "player")
  if rab then c.rap = rab + (rap1 or 0) + (rap2 or 0) end
  local _, effective = Try(UnitArmor, "player")
  c.armor = effective

  c.stats = {}
  local names = { "STR", "AGI", "STA", "INT", "SPI" }
  for i = 1, 5 do
    local s, e = UnitStat("player", i)
    c.stats[names[i]] = e or s
  end

  c.crit = Try(GetCritChance)
  c.dodge = Try(GetDodgeChance)
  c.parry = Try(GetParryChance)
  c.block = Try(GetBlockChance)

  c.gear, c.gearCount = Char.GearTotals()
  c.talentsReady = AdeTalents and AdeTalents.IsReady and AdeTalents.IsReady() and true or false
  c.talentsVersion = AdeTalents and AdeTalents.version
  return c
end

----------------------------------------------------------------------
-- /adeg me
----------------------------------------------------------------------

local function Say(text)
  DEFAULT_CHAT_FRAME:AddMessage("  " .. text)
end

-- two decimals, like the character window (8.98%, 11.68%)
local function Pct(v)
  return string.format("%.2f%%", v)
end

-- /adeg role why: which of your talents point to which role
function Char.RoleWhy()
  local ok, c = pcall(Char.Basic)
  if not ok then AG.Msg("could not read the character: " .. tostring(c)) return end
  if c.styleInfo then
    local sc = {}
    for style, x in pairs(c.styleInfo.scores) do table.insert(sc, style .. " " .. AG.Items.NumText(x)) end
    if table.getn(sc) == 0 then table.insert(sc, "no points") end
    AG.Msg("style: " .. tostring(c.style) .. " (talent points: " .. table.concat(sc, ", ") .. ")")
    if c.styleInfo.notReady then DEFAULT_CHAT_FRAME:AddMessage("  AdeTalents is not ready yet, using the default style") end
    if c.styleInfo.low then DEFAULT_CHAT_FRAME:AddMessage("  too few points to tell, using the default style") end
    if c.styleInfo.tie then DEFAULT_CHAT_FRAME:AddMessage("  equal points, using the default style") end
    for i = 1, table.getn(c.styleInfo.counted) do
      local t = c.styleInfo.counted[i]
      local parts = {}
      for style, x in pairs(t.w) do table.insert(parts, style .. " +" .. AG.Items.NumText(x * t.rank)) end
      DEFAULT_CHAT_FRAME:AddMessage("  " .. t.name .. " " .. t.rank .. ": " .. table.concat(parts, ", "))
    end
  end
  local info = c.spec.byTalents
  if not info and c.styleInfo then return end
  if not info then
    local cd = AG.ClassData and AG.ClassData[c.class]
    if cd and cd.roleTalents then
      AG.Msg("AdeTalents is not ready yet, the role comes from the talent tree for now: " .. ROLE_NAME[c.spec.role])
    else
      AG.Msg(tostring(c.class) .. ": no talent list for the role yet, the role comes from the talent tree: " .. ROLE_NAME[c.spec.role])
    end
    return
  end
  AG.Msg("role from your talents: " .. ROLE_NAME[c.spec.role])
  if c.forced then
    DEFAULT_CHAT_FRAME:AddMessage("  but you forced the role with /adeg role: " .. ROLE_NAME[c.role] .. " is used for values. Type /adeg role auto to follow the talents.")
  end
  DEFAULT_CHAT_FRAME:AddMessage("  points: heal " .. AG.Items.NumText(info.scores.heal) .. ", damage " .. AG.Items.NumText(info.scores.dmg) ..
    ", tank " .. AG.Items.NumText(info.scores.tank))
  if info.low then DEFAULT_CHAT_FRAME:AddMessage("  too few points to tell, using the class default (like at the start of leveling)") end
  if info.tie then DEFAULT_CHAT_FRAME:AddMessage("  heal and damage are equal, using the class default") end
  for i = 1, table.getn(info.counted) do
    local t = info.counted[i]
    local parts = {}
    for role, x in pairs(t.w) do table.insert(parts, role .. " +" .. AG.Items.NumText(x * t.rank)) end
    DEFAULT_CHAT_FRAME:AddMessage("  " .. t.name .. " " .. t.rank .. ": " .. table.concat(parts, ", "))
  end
  if table.getn(info.counted) == 0 then DEFAULT_CHAT_FRAME:AddMessage("  none of your talents are on the list") end
end

function Char.Print()
  local ok, c = pcall(Char.Read)
  if not ok then
    AG.Msg("could not read the character: " .. tostring(c))
    return
  end
  AG.Msg(tostring(c.class) .. " level " .. c.level)

  local trees = {}
  for i = 1, table.getn(c.spec.trees) do
    table.insert(trees, c.spec.trees[i].name .. " " .. c.spec.trees[i].points)
  end
  local roleText = ROLE_NAME[c.role]
  if c.spec.noPoints then roleText = roleText .. " (no talent points yet)" end
  if c.forced then roleText = ROLE_NAME[c.role] .. " (set with /adeg role)" end
  if c.spec.byTalents and not c.forced then
    local sc = c.spec.byTalents.scores
    roleText = roleText .. " (talent points: heal " .. AG.Items.NumText(sc.heal) .. ", damage " .. AG.Items.NumText(sc.dmg) ..
      ", tank " .. AG.Items.NumText(sc.tank)
    if c.spec.byTalents.low then roleText = roleText .. "; too few to tell, class default" end
    if c.spec.byTalents.tie then roleText = roleText .. "; tie, class default" end
    roleText = roleText .. ")"
  end
  if c.spec.feral then roleText = roleText .. " (feral: bear or cat is not decided yet)" end
  Say("talents: " .. table.concat(trees, " / ") .. "  ->  main role: " .. roleText)

  local modes = { "Solo", "Party", "Raids" }
  local mode = AG.Get("playstyle")
  if mode > 3 then mode = 3 end
  local parts = {}
  if c.mix.tank > 0 then table.insert(parts, "Tank " .. math.floor(c.mix.tank * 100 + 0.5) .. "%") end
  if c.mix.heal > 0 then table.insert(parts, "Heal " .. math.floor(c.mix.heal * 100 + 0.5) .. "%") end
  if c.mix.dmg > 0 then table.insert(parts, "Damage " .. math.floor(c.mix.dmg * 100 + 0.5) .. "%") end
  Say("play mode: " .. modes[mode] .. "  ->  mix: " .. table.concat(parts, ", "))
  Say("target level for hit numbers: " .. c.target)

  local skill = "main hand skill " .. c.mainSkill
  if c.offSkill then skill = skill .. ", off hand " .. c.offSkill end
  if c.rangedSkill then skill = skill .. ", ranged " .. c.rangedSkill end
  Say(skill)
  if c.missGuess then
    Say("white hit vs that target: your skill is more than 15 points below its defense, the sheet has no number for that")
  else
    Say("white hit miss chance vs that target, one weapon: " .. string.format("%.1f%%", c.miss))
  end
  if c.defense then Say("defense " .. c.defense) end
  if c.armor then Say("armor " .. c.armor) end

  local st = c.stats
  Say("strength " .. tostring(st.STR) .. ", agility " .. tostring(st.AGI) .. ", stamina " .. tostring(st.STA) ..
    ", intellect " .. tostring(st.INT) .. ", spirit " .. tostring(st.SPI))
  if c.ap then
    local t = "attack power " .. c.ap
    if c.rap then t = t .. ", ranged " .. c.rap end
    Say(t)
  end
  if c.crit then Say("melee crit " .. Pct(c.crit) .. ", dodge " .. Pct(c.dodge or 0) .. ", parry " .. Pct(c.parry or 0) .. ", block " .. Pct(c.block or 0)) end

  local g = c.gear
  local gearKeys = { "HIT", "SPELLHIT", "CRIT", "SPELLCRIT", "SP", "HEAL", "MP5", "DEFENSE" }
  local gp = {}
  for i = 1, table.getn(gearKeys) do
    local k = gearKeys[i]
    if g[k] and g[k] ~= 0 then table.insert(gp, AG.Items.Label(k) .. " " .. AG.Items.NumText(g[k])) end
  end
  for k, v in pairs(g) do
    if string.find(k, "^SKILL_") or string.find(k, "^DMG_") then
      table.insert(gp, AG.Items.Label(k) .. " " .. AG.Items.NumText(v))
    end
  end
  if table.getn(gp) == 0 then table.insert(gp, "none of the numbers we follow") end
  Say("from your " .. c.gearCount .. " worn items (set bonuses included): " .. table.concat(gp, ", "))

  if c.talentsVersion then
    local r = "not read yet"
    if c.talentsReady then r = "ready" end
    local data = "effects data: no"
    if AdeTalents.GetData and (AdeTalents.GetData("Mental Strength") or AdeTalents.GetData("Divine Strength") or AdeTalents.GetData("Toughness") or AdeTalents.GetData("Cruelty")) then data = "effects data: yes" end
    Say("AdeTalents v" .. c.talentsVersion .. ": " .. r .. ", " .. data)
  else
    Say("AdeTalents not found (needed from step 4)")
  end
  if g.FERAL_AP then Say("attack power only in druid forms: " .. AG.Items.NumText(g.FERAL_AP)) end
  Say("note: hit from talents is not counted yet, spell hit and spell power come from gear only")
end
