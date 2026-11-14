-- Step 4: what one point of each stat is worth to YOU.
--
-- value of a stat = (base weight of the class, role and style + what talents add) x what talents multiply
--
-- Currency: set per class (Priest: 1 point = 1 spell power, Hunter: 1 point = 1 attack power).
-- The base numbers live in Classes\<CLASS>.lua. A base table can be a function of your character
-- (attack power, weapon dps, level), so the values follow your gear and level. Talent numbers come
-- from AdeTalents at your real ranks, so a talent with 0 points changes nothing and at level 10
-- (one point) almost nothing changes.
--
-- Rules (see Classes\PRIEST.lua and Classes\HUNTER.lua):
--   statpct  "+10% total Intellect": every point of that stat counts (1 + pct) times
--   convert  "25% of total Spirit as spell power": a point of Spirit also gives pct of a point of
--            spell power, so Spirit is worth base + pct x (value of spell power)
--   conv     the same, but built into the class (Agility gives crit), pct comes from a function
-- A rule can be limited to roles = { heal = true } or styles = { melee = true }.
-- The percent boost is applied last, so it also boosts what the stat converts into
-- (Spirit of Redemption makes Spiritual Guidance stronger, as in the game).

local AG = AdeGear
local Wt = {}
AG.Weights = Wt
AG.ClassData = AG.ClassData or {}

local function DefaultSource()
  return {
    Rank = function(name)
      if AdeTalents and AdeTalents.GetRank then return AdeTalents.GetRank(name) end
      return 0
    end,
    Max = function(name)
      if AdeTalents and AdeTalents.GetMaxRank then return AdeTalents.GetMaxRank(name) end
      return nil
    end,
    -- number {num} of the talent text at your current rank, nil if no points or unknown
    Value = function(name, num)
      if not (AdeTalents and AdeTalents.GetValues) then return nil end
      local v = AdeTalents.GetValues(name)
      if not v or not v[num] then return nil end
      return math.floor(v[num] * 100 + 0.5) / 100
    end,
  }
end

local function Num(x)
  return string.format("%g", x)
end

-- physical damage reduction of an armor value against an attacker of the given level (1.12 formula)
function Wt.ArmorDR(armor, attackerLevel)
  local k = 400 + 85 * attackerLevel
  return armor / (armor + k)
end

-- value of one point of armor in Stamina points, for a tank: the extra damage reduction compared with
-- the extra health one Stamina gives (10). Falls to almost nothing at the 75% cap.
function Wt.ArmorWeight(c)
  local L = c.target or c.level or 60
  local A = c.armor or 0
  local k = 400 + 85 * L
  local dr = A / (A + k)
  if dr >= 0.75 then return 0.02 end
  local h = c.health
  if not h or h <= 0 then h = (c.level or 60) * 90 end
  local w = (k / ((A + k) * (A + k))) / (1 - dr) * h / 10
  if w < 0.02 then w = 0.02 end
  if w > 0.2 then w = 0.2 end
  return w
end

-- the base table of a role (and style) of a class, or nil
local function RoleTable(cd, role, style, c)
  local t = nil
  if style then t = cd.roles[role .. ":" .. style] end
  if not t then t = cd.roles[role] end
  if type(t) == "function" then t = t(c or {}) end
  if not t then return nil end
  local n = {}
  for k, v in pairs(t) do n[k] = v end
  -- chance on hit damage and damage done to attackers: small values (threat from thorns with several mobs)
  if n.PROC_DMG == nil then
    if role == "dmg" then n.PROC_DMG = 0.2 elseif role == "tank" then n.PROC_DMG = 0.1 else n.PROC_DMG = 0 end
  end
  if role == "tank" then
    if n.THORNS == nil then n.THORNS = 0.35 end
    -- avoidance (defense, dodge, parry, block) is worth a share of health: one percent of avoided hits is
    -- about 1% of your health pool, which grows with level (about 9 health per level, 10 health = 1 Stamina)
    if cd.avoid then
      local av = ((c and c.level) or 60) * 0.09
      for k, f in pairs(cd.avoid) do n[k] = f * av end
    end
    -- armor: what one more point adds to damage reduction, against your health, up to the 75% cap
    if cd.armorDR and c and c.armor and c.armor > 0 then
      n.ARMOR = Wt.ArmorWeight(c)
    end
    -- resistances: a small value for a tank (all schools alike)
    local schools = { "ARCANE", "FIRE", "FROST", "NATURE", "SHADOW" }
    for i = 1, 5 do
      local k = "RES_" .. schools[i]
      if n[k] == nil then n[k] = 0.12 end
    end
  end
  t = n
  return t
end

local function Allowed(m, role, style)
  if m.roles and not m.roles[role] then return false end
  if m.styles and not (style and m.styles[style]) then return false end
  return true
end

-- weights of one role. Returns final, why, where why[stat] = list of texts
function Wt.Resolve(cd, role, src, base, style, c)
  base = base or RoleTable(cd, role, style, c)
  if not base then return nil end
  local mult, why, core = {}, {}, {}
  for k, v in pairs(base) do core[k] = v end

  local function note(stat, text)
    why[stat] = why[stat] or {}
    table.insert(why[stat], text)
  end
  local function label(m)
    local s = m.talent
    local r, mx = src.Rank(m.talent), src.Max(m.talent)
    if r and mx then s = s .. " " .. r .. "/" .. mx end
    return s
  end

  local mods = cd.mods or {}
  for i = 1, table.getn(mods) do
    local m = mods[i]
    if m.kind == "statpct" and core[m.stat] ~= nil and Allowed(m, role, style) then
      local pct = src.Value(m.talent, m.num)
      if pct and pct ~= 0 then
        if m.sign then pct = pct * m.sign end
        mult[m.stat] = (mult[m.stat] or 1) * (1 + pct / 100)
        note(m.stat, label(m) .. ": " .. m.text .. " " .. (pct > 0 and "+" or "") .. Num(pct) .. "%")
      end
    end
  end

  -- fixed additions: a talent that makes a stat matter (Seal of Command: spell power for Retribution)
  for i = 1, table.getn(mods) do
    local m = mods[i]
    if m.kind == "add" and core[m.stat] ~= nil and Allowed(m, role, style) then
      local r = src.Rank(m.talent)
      if r and r > 0 then
        core[m.stat] = core[m.stat] + m.value * (m.perRank and r or 1)
        note(m.stat, label(m) .. ": " .. m.text)
      end
    end
  end

  -- conversions built into the class (Agility gives crit): pct = percent of one point of "to"
  local conv = cd.conv or {}
  for i = 1, table.getn(conv) do
    local m = conv[i]
    if core[m.from] ~= nil and base[m.to] ~= nil and Allowed(m, role, style) then
      local pct = m.pct(c or {})
      if pct and pct > 0 then
        core[m.from] = core[m.from] + (pct / 100) * base[m.to] * (mult[m.to] or 1)
        if m.note then note(m.from, m.note(c or {})) end
      end
    end
  end

  for i = 1, table.getn(mods) do
    local m = mods[i]
    if m.kind == "convert" and core[m.from] ~= nil and base[m.to] ~= nil and Allowed(m, role, style) then
      local pct = src.Value(m.talent, m.num)
      if pct and pct ~= 0 then
        core[m.from] = core[m.from] + (pct / 100) * base[m.to] * (mult[m.to] or 1)
        note(m.from, label(m) .. ": " .. Num(pct) .. "% " .. m.text)
      end
    end
  end

  local final = {}
  for k, v in pairs(core) do final[k] = v * (mult[k] or 1) end
  return final, why
end

-- c = { class, mix = { tank, heal, dmg }, style, ... }. Returns a table or nil plus a message.
--   weights[stat], base[stat], why[stat] = { texts }, shares[role], order = list of stats
function Wt.Compute(c, src)
  src = src or DefaultSource()
  local cd = AG.ClassData[c.class]
  if not cd then return nil, "no stat values for " .. tostring(c.class) .. " yet" end

  local shares, bases, sum = {}, {}, 0
  for role, share in pairs(c.mix or {}) do
    if share > 0 then
      local b = RoleTable(cd, role, c.style, c)
      if b then
        shares[role] = share
        bases[role] = b
        sum = sum + share
      end
    end
  end
  local fallback = nil
  if sum <= 0 then
    fallback = cd.default or "dmg"
    shares = {}
    shares[fallback] = 1
    bases[fallback] = RoleTable(cd, fallback, c.style, c)
    sum = 1
  end

  local w = { weights = {}, base = {}, why = {}, shares = {}, order = cd.order, fallback = fallback, offHandHit = cd.offHandHit,
    style = c.style, currency = cd.currency }
  for role, share in pairs(shares) do
    share = share / sum
    w.shares[role] = share
    local final, why = Wt.Resolve(cd, role, src, bases[role], c.style, c)
    -- racial percent boosts to a stat
    if c.race and AG.Races then
      local rm = AG.Races.Mods(c.race)
      for i = 1, table.getn(rm) do
        local m = rm[i]
        if final[m.stat] ~= nil then
          final[m.stat] = final[m.stat] * (1 + m.pct / 100)
          why[m.stat] = why[m.stat] or {}
          table.insert(why[m.stat], m.text)
        end
      end
    end
    for k, v in pairs(final) do
      w.weights[k] = (w.weights[k] or 0) + share * v
      w.base[k] = (w.base[k] or 0) + share * bases[role][k]
    end
    for stat, list in pairs(why) do
      w.why[stat] = w.why[stat] or {}
      for i = 1, table.getn(list) do
        local dup = false
        for j = 1, table.getn(w.why[stat]) do
          if w.why[stat][j] == list[i] then dup = true end
        end
        if not dup then table.insert(w.why[stat], list[i]) end
      end
    end
  end
  -- weapons are not the whole damage: white hits and special attacks also scale with attack power and
  -- stats, so weapon dps and hit size count only a part of what the calculation says (/adeg weapon)
  local scale = AG.Get("weaponScale")
  if type(scale) ~= "number" then scale = 0.3 end
  w.weaponScale = scale
  local keys = { "WEAPON_MELEE", "WEAPON_HIT", "WEAPON_RANGED", "AMMO_DPS" }
  for i = 1, table.getn(keys) do
    local k = keys[i]
    if w.weights[k] then w.weights[k] = w.weights[k] * scale end
    if w.base[k] then w.base[k] = w.base[k] * scale end
  end
  return w
end

-- the stats of an item plus weapon damage rows (only for classes that value them)
local RANGED_KIND = { Bow = true, Gun = true, Crossbow = true, Thrown = true, Wand = true }
function Wt.ItemStats(it, w, placed)
  local s = {}
  for k, v in pairs(it.stats) do s[k] = v end
  if it.weapon and it.weapon.dps then
    local f = 1
    if it.slot == "OFFHAND" or placed == 17 then f = 0.5 end   -- the off hand hits for half
    local avg = (it.weapon.avg or 0) + (it.weapon.extra or 0)
    if it.slot == "RANGED" and it.weaponKind == "Wand" then
      if AG.Get("wand") ~= false and w.weights.WEAPON_WAND and w.weights.WEAPON_WAND ~= 0 then s.WEAPON_WAND = it.weapon.dps end
    elseif it.slot == "RANGED" and RANGED_KIND[it.weaponKind or ""] then
      if w.weights.WEAPON_RANGED and w.weights.WEAPON_RANGED ~= 0 then s.WEAPON_RANGED = it.weapon.dps end
    elseif it.slot == "ONEHAND" or it.slot == "TWOHAND" or it.slot == "MAINHAND" or it.slot == "OFFHAND" then
      if w.weights.WEAPON_MELEE and w.weights.WEAPON_MELEE ~= 0 then s.WEAPON_MELEE = it.weapon.dps * f end
      -- special attacks hit with the main hand only (Hunter Mongoose Bite uses both)
      local off = (it.slot == "OFFHAND" or placed == 17)
      if w.weights.WEAPON_HIT and w.weights.WEAPON_HIT ~= 0 and (not off or w.offHandHit) then s.WEAPON_HIT = avg * f end
    end
  end
  if it.ammoDps and w.weights.AMMO_DPS and w.weights.AMMO_DPS ~= 0 then s.AMMO_DPS = it.ammoDps end
  return s
end

-- points of an item: returns total and rows[stat] = points
function Wt.ItemValue(it, w, placed)
  local total, rows = 0, {}
  local stats = Wt.ItemStats(it, w, placed)
  for k, v in pairs(stats) do
    local x = w.weights[k]
    if x and x ~= 0 then
      rows[k] = v * x
      total = total + v * x
    end
  end
  return total, rows, stats
end


----------------------------------------------------------------------
-- Step 4e: level scaling of Intellect, hit caps, weapon skill, defense cap
----------------------------------------------------------------------

-- Intellect needed for 1% spell crit at your level: "full" at 60, about a fifth of that at level 1
-- (an estimate in a straight line, class numbers: mage 59.5, priest 59.2, warlock 60.6, shaman 59.2, druid 60, paladin 54)
function Wt.IntPerCrit(c, full)
  local l = (c and c.level) or 60
  if l < 1 then l = 1 end
  if l > 60 then l = 60 end
  return full * (0.2 + 0.8 * (l - 1) / 59)
end

local skipManual = false
local gcache = nil
local function GearCache()
  local now = GetTime()
  if gcache and now - gcache.t < 1 then return gcache end
  local ok, v, n, sets = pcall(AG.Char.GearTotals)
  if not ok or not v then v = {}; sets = nil end
  gcache = { t = now, v = v, sets = sets }
  return gcache
end
local function GearTotals()
  return GearCache().v
end

function Wt.Flush() gcache = nil end

-- worn pieces per set name, counted from the items in your slots (nil when not available)
function Wt.SetCounts()
  return GearCache().sets
end

local MELEE_SKILL = {
  Sword = "SKILL_SWORDS", Axe = "SKILL_AXES", Mace = "SKILL_MACES", Dagger = "SKILL_DAGGERS",
  Polearm = "SKILL_POLEARMS", Staff = "SKILL_STAVES", ["Fist Weapon"] = "SKILL_FIST_WEAPONS", Fist = "SKILL_FIST_WEAPONS",
}

local MELEE_SKILL_KEYS = {}
for _, v in pairs(MELEE_SKILL) do MELEE_SKILL_KEYS[v] = true end

-- spell miss chance by level difference (1.12 rules): 4, 5, 6 percent, then 17 for a level 63 target
local function SpellCap(level, target)
  local d = (target or level) - level
  if d <= 0 then return 4 end
  if d == 1 then return 5 end
  if d == 2 then return 6 end
  return 17
end

-- Applies the caps to a finished weight table. Returns a list of notes (also kept in w.capNotes).
function Wt.ApplyCaps(w, c)
  local notes = {}
  if not w or not c then return notes end
  w.caps = {}
  local gear = GearTotals()
  local function scale(stat, f)
    if w.weights[stat] then w.weights[stat] = w.weights[stat] * f end
  end

  -- melee hit: cap = miss chance of a white hit (the Turtle / Octo rule), 19 points more when dual wielding
  if w.weights.HIT and w.weights.HIT ~= 0 and c.mainSkill == nil then
    local okb, mb, mm = pcall(UnitAttackBothHands, "player")
    if okb then c.mainSkill = (mb or 0) + (mm or 0) end
  end
  if w.weights.HIT and w.weights.HIT ~= 0 and c.mainSkill and c.mainSkill > 0 then
    local miss = AG.Char.MeleeMiss(c.mainSkill, c.target or c.level)
    local cap = miss
    local oh = AG.Items.FromSlot(17)
    if oh and oh.weapon then cap = cap + 19 end
    local have = gear.HIT or 0
    w.caps.HIT = { have = have, cap = cap, name = "Hit %" }
    if have >= cap then
      scale("HIT", 0.15)
      table.insert(notes, "Hit % counts only a little: your gear gives " .. Num(have) .. "%, the cap is about " .. Num(cap) .. "%")
    else
      table.insert(notes, "Hit %: " .. Num(have) .. " of about " .. Num(cap) .. "% cap")
    end
  end

  -- spell hit
  if w.weights.SPELLHIT and w.weights.SPELLHIT ~= 0 then
    local cap = SpellCap(c.level or 60, c.target)
    local have = gear.SPELLHIT or 0
    w.caps.SPELLHIT = { have = have, cap = cap, name = "Spell hit %" }
    if have >= cap then
      scale("SPELLHIT", 0.15)
      table.insert(notes, "Spell hit % counts only a little: your gear gives " .. Num(have) .. "%, the cap is about " .. Num(cap) .. "%")
    else
      table.insert(notes, "Spell hit %: " .. Num(have) .. " of about " .. Num(cap) .. "% cap")
    end
  end

  -- weapon skill for held weapons (the Hunter table sets its own): a point lowers the miss chance by 0.2%
  -- until your skill reaches 5 x the target's level, and adds a little crit. Racial skill (Human swords +3)
  -- is already in the skill the game reports, so a race that is already at the cap gets no value from more.
  local tl = (c.target or c.level or 60) * 5
  if w.weights.HIT and w.weights.HIT ~= 0 then
    if not c.mainItem then c.mainItem = AG.Items.FromSlot(16) end
    if not c.offItem then c.offItem = AG.Items.FromSlot(17) end
    local base = w.base.HIT or w.weights.HIT
    local function skillFor(item)
      local kind = item and item.weaponKind
      local key = kind and MELEE_SKILL[kind]
      if key and not w.weights[key] then
        local v = 0.2 * w.weights.HIT + 0.04 * (w.weights.CRIT or 0)
        w.weights[key] = v
        w.base[key] = 0.2 * base + 0.04 * (w.base.CRIT or 0)
      end
    end
    skillFor(c.mainItem)
    skillFor(c.offItem)
  end
  local ms = c.mainSkill
  if ms and ms >= tl then
    for k, v in pairs(w.weights) do
      if MELEE_SKILL_KEYS[k] then
        w.weights[k] = 0.04 * (w.weights.CRIT or 0)
        table.insert(notes, "Weapon skill " .. ms .. " is already at the cap of " .. tl .. ": more skill counts only a little")
        break
      end
    end
  end
  local okr, rb, rm2 = pcall(UnitRangedAttack, "player")
  if okr and rb and (rb + (rm2 or 0)) >= tl then
    local keys = { "SKILL_BOWS", "SKILL_GUNS", "SKILL_CROSSBOWS" }
    for i = 1, 3 do
      if w.weights[keys[i]] then w.weights[keys[i]] = 0 end
    end
  end

  -- tank: crits against you are gone at defense 5 x level + 125 + 5 per level of the target above you
  -- (440 for a level 60 against a level 63 boss); more defense then only adds avoidance
  if w.weights.DEFENSE and w.weights.DEFENSE ~= 0 and (c.role == "tank" or (w.shares and w.shares.tank and w.shares.tank > 0.5)) then
    local d = c.defense
    if not d then
      local ok, b, m = pcall(UnitDefense, "player")
      if ok and b then d = b + (m or 0) end
    end
    local lv = c.level or 60
    local diff = (c.target or lv) - lv
    if diff < 0 then diff = 0 end
    local cap = 5 * lv + 125 + 5 * diff
    if d then w.caps.DEFENSE = { have = d, cap = cap, name = "Defense" } end
    if d and d >= cap then
      scale("DEFENSE", 0.4)
      table.insert(notes, "Defense " .. d .. " is past " .. cap .. " (crit immune), more counts only as avoidance")
    elseif d and d >= cap - 30 then
      -- close to the cap: the value fades out over the last 30 points
      scale("DEFENSE", 1 - 0.6 * (d - (cap - 30)) / 30)
      table.insert(notes, "Defense " .. d .. " of " .. cap .. " (crit immune), nearly there")
    elseif d then
      table.insert(notes, "Defense " .. d .. " of " .. cap .. " (crit immune)")
    end
  end
  w.capNotes = notes
  return notes
end

-- auto = true: the calculated values only, without the ones you typed in the options
function Wt.ForPlayer(auto)
  local ok, c = pcall(AG.Char.Basic)
  if not ok or not c then return nil end
  local cd = AG.ClassData[c.class]
  if cd and cd.needsCombat then pcall(AG.Char.Combat, c) end
  local w = Wt.Compute(c)
  if w then
    skipManual = auto and true or false
    pcall(Wt.ApplyCaps, w, c)
    skipManual = false
  end
  return w, c
end

function Wt.MixText(w)
  local names = { tank = "Tank", heal = "Heal", dmg = "Damage" }
  if w.style then names.dmg = "Damage (" .. w.style .. ")" end
  local parts = {}
  local order = { "tank", "heal", "dmg" }
  for i = 1, 3 do
    local s = w.shares[order[i]]
    if s and s > 0.004 then table.insert(parts, names[order[i]] .. " " .. math.floor(s * 100 + 0.5) .. "%") end
  end
  return table.concat(parts, ", ")
end

----------------------------------------------------------------------
-- /adeg weights
----------------------------------------------------------------------

local function Say(text)
  DEFAULT_CHAT_FRAME:AddMessage("  " .. text)
end

local function F(x)
  return string.format("%.3g", x)
end

function Wt.Print()
  local ok, c = pcall(AG.Char.Basic)
  if not ok then
    AG.Msg("could not read the character: " .. tostring(c))
    return
  end
  local cd = AG.ClassData[c.class]
  if cd and cd.needsCombat then pcall(AG.Char.Combat, c) end
  local w, err = Wt.Compute(c)
  if w then pcall(Wt.ApplyCaps, w, c) end
  AG.Msg("stat values: " .. tostring(c.class) .. " level " .. c.level)
  if not w then
    Say(err)
    return
  end
  local role = "main role from talents: " .. tostring(c.role)
  if c.forced then role = "role set with /adeg role: " .. tostring(c.role) end
  Say(role .. "  ->  valued as: " .. Wt.MixText(w))
  if c.race then
    local rm = AG.Races and AG.Races.Mods(c.race) or {}
    local extra = ""
    if table.getn(rm) > 0 then extra = ", its stat bonus is counted" end
    Say("race: " .. c.race .. extra)
  end
  if w.fallback then Say("this class has no table for that role yet, using " .. w.fallback) end
  if cd and cd.needsCombat then
    local parts = {}
    if c.rap then table.insert(parts, "ranged attack power " .. c.rap) end
    if c.ap then table.insert(parts, "attack power " .. c.ap) end
    table.insert(parts, "ranged weapon + ammo dps " .. string.format("%.1f", c.rangedDps or 0))
    table.insert(parts, "main hand dps " .. string.format("%.1f", c.mainDps or 0))
    Say("read from you: " .. table.concat(parts, ", "))
  end
  if AdeTalents and AdeTalents.GetValues and AdeTalents.GetData then
    local test = (cd and cd.mods and cd.mods[1] and AdeTalents.GetData(cd.mods[1].talent)) or AdeTalents.GetData("Mental Strength") or AdeTalents.GetData("Lightning Reflexes") or AdeTalents.GetData("Divine Strength") or AdeTalents.GetData("Toughness")
    if not test then Say("AdeTalents has no effects data for your class: talents are NOT counted") end
  else
    Say("AdeTalents not found or too old: talents are NOT counted, only base values")
  end
  Say((w.currency or "1 point = 1 spell power") .. ". Base numbers are first estimates, talents change them as shown:")
  if w.weaponScale and w.weaponScale ~= 1 then
    Say("weapon dps, hit size and ammo count x" .. w.weaponScale .. " of the calculation (change with /adeg weapon)")
  end
  if w.capNotes then
    for i = 1, table.getn(w.capNotes) do Say(w.capNotes[i]) end
  end
  local order = {}
  for i = 1, table.getn(w.order or {}) do table.insert(order, w.order[i]) end
  for k, v in pairs(w.weights) do
    if string.find(k, "^SKILL_") then table.insert(order, k) end
  end
  for i = 1, table.getn(order) do
    local k = order[i]
    local final = w.weights[k]
    if final and (final ~= 0 or (w.base[k] or 0) ~= 0) then
      local line = AG.Items.Label(k) .. ": " .. F(final)
      if math.abs(final - (w.base[k] or 0)) > 0.0005 then line = line .. "  (base " .. F(w.base[k]) .. ")" end
      local why = w.why[k]
      if why then
        for j = 1, table.getn(why) do line = line .. "  | " .. why[j] end
      end
      Say(line)
    end
  end
end

----------------------------------------------------------------------
-- Values you typed in the options window (AdeGearDB.manual[class][stat]) replace the calculated ones
----------------------------------------------------------------------

-- Raids: long fights make mana regeneration worth more to a healer, and level 63 bosses make weapon skill
-- worth more (glancing blows and misses). The hit and defense caps already follow the boss level.
local RAID_REGEN = 0.3     -- extra value of mana per 5 sec for a healer
local RAID_SKILL = 0.25    -- extra value of weapon skill

function Wt.RaidTune(w)
  if not w or not w.weights or AG.Get("playstyle") < 3 then return end
  w.why = w.why or {}
  local heal = (w.shares and w.shares.heal) or 0
  if heal > 0 then
    for _, k in ipairs({ "MP5", "CASTREGEN" }) do
      if w.weights[k] and w.weights[k] ~= 0 then
        w.weights[k] = w.weights[k] * (1 + RAID_REGEN * heal)
        w.why[k] = w.why[k] or {}
        table.insert(w.why[k], "Raids: long fights, mana regen counts more")
      end
    end
  end
  for k, v in pairs(w.weights) do
    if string.find(k, "^SKILL_") and v ~= 0 then
      w.weights[k] = v * (1 + RAID_SKILL)
      w.why[k] = w.why[k] or {}
      table.insert(w.why[k], "Raids: level 63 bosses, skill counts more")
    end
  end
end

local capsOriginal = Wt.ApplyCaps
function Wt.ApplyCaps(w, c)
  local notes = capsOriginal(w, c)
  Wt.RaidTune(w)
  if skipManual or not w or not c or not AdeGearDB or not AdeGearDB.manual then return notes end
  local m = AdeGearDB.manual[c.class]
  if not m then return notes end
  w.manual = {}
  for k, v in pairs(m) do
    if type(v) == "number" then
      w.weights[k] = v
      w.manual[k] = true
      w.why[k] = { "set by you: " .. v }
      if w.caps then w.caps[k] = nil end
    end
  end
  return notes
end
