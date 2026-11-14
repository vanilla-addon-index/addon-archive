-- AdeSPD core: dependency detection, spell records (Nampower), spell power, auras, spell index.
-- Written for the Lua 5.0 client: no '#', no '%', no select(), no string.match.

AdeSPD = {}
local A = AdeSPD

A.VERSION = "0.1.0"
A.NEED_HITS = 15            -- non-crit hits needed before a learned coefficient is trusted
A.SCHOOL_NAMES = { "Physical", "Holy", "Fire", "Nature", "Frost", "Shadow", "Arcane" }
A.SCHOOL_IDX = {}
do
  local i
  for i = 1, 7 do A.SCHOOL_IDX[A.SCHOOL_NAMES[i]] = i end
end

A.DB = { enabled = true, armor = true, window = true, spellbook = false, detail = false, mods = true, learn = true, log = false,
         prefer = "table", maxId = 110000, learned = {}, idcache = {}, record = "auto", comp = {} }

function A.Print(msg)
  if A.capture then table.insert(A.capture, msg) return end      -- collected for the output window
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99AdeSPD|r: " .. msg)
end

-- pcall wrapper: returns up to three results, nil when the function is missing or errors.
local function try(f, a, b, c)
  if type(f) ~= "function" then return nil end
  local ok, r1, r2, r3 = pcall(f, a, b, c)
  if ok then return r1, r2, r3 end
  return nil
end
A.try = try

local function Round(x) return math.floor(x + 0.5) end
A.Round = Round

-- Name and rank text of a spell id as the client shows them (localized). Nampower's
-- GetSpellNameAndRankForId gives both in the client language; the record field is the fallback.
local function NameRank(id)
  if type(GetSpellNameAndRankForId) == "function" then
    local ok, n, r = pcall(GetSpellNameAndRankForId, id)
    if ok and type(n) == "string" and n ~= "" then
      if (r == nil or r == "") then
        local _, _, a, b = string.find(n, "^(.-) | (.+)$")
        if a then n, r = a, b end
      end
      return n, (r or "")
    end
  end
  local n = try(GetSpellRecField, id, "name")
  if type(n) ~= "string" or n == "" then return nil end
  local r = try(GetSpellRecField, id, "rank")
  return n, (type(r) == "string" and r or "")
end
A.NameRank = NameRank

-- Language of the client: tooltips are only read word by word on English clients. Everywhere else the
-- numbers come from the spell record and are added as extra lines (/spd record on|off|auto).
function A.RecordMode()
  local m = A.DB.record
  if m == "on" then return true end
  if m == "off" then return false end
  local l = try(GetLocale)
  return type(l) == "string" and l ~= "enUS" and l ~= "enGB"
end
function A.Lang()
  local l = try(GetLocale)
  if l == "ruRU" then return "ru" end
  return "en"
end

local function HasBit(mask, bit)
  return math.mod(math.floor((mask or 0) / bit), 2) == 1
end
A.HasBit = HasBit

---------------------------------------------------------------------------
-- Dependencies
---------------------------------------------------------------------------

function A.Detect()
  A.np    = (type(GetSpellRec) == "function") and (type(GetSpellModifiers) == "function")
  A.swow  = (type(SUPERWOW_VERSION) ~= "nil") or (type(GetPlayerBuffID) == "function")
  A.capi  = (type(GetSpellBonusDamage) == "function") and (type(GetSpellBonusHealing) == "function")
end
A.Detect()

---------------------------------------------------------------------------
-- Spell records (Nampower GetSpellRec)
---------------------------------------------------------------------------

-- Nampower returns C arrays. Support both 0-based and 1-based layouts.
local function at(t, i)
  if type(t) ~= "table" then return 0 end
  local v
  if t[0] ~= nil then v = t[i - 1] else v = t[i] end
  if type(v) ~= "number" then return 0 end
  return v
end

local infoCache = {}

function A.Info(id)
  if not id then return nil end
  local c = infoCache[id]
  if c ~= nil then
    if c == false then return nil end
    return c
  end
  local rec = try(GetSpellRec, id)
  if type(rec) ~= "table" or not rec.name then
    infoCache[id] = false
    return nil
  end
  local nm, rk = NameRank(id)
  local I = { id = id, name = nm or rec.name, rank = rk or rec.rank, en = (AdeSPD_En and AdeSPD_En[id]) or rec.name,
              school = rec.school or 0,
              spellLevel = rec.spellLevel or 0, baseLevel = rec.baseLevel or 0,
              maxLevel = rec.maxLevel or 0, attributes = rec.attributes or 0, eff = {} }
  local i
  for i = 1, 3 do
    I.eff[i] = {
      type = at(rec.effect, i),               aura = at(rec.effectApplyAuraName, i),
      bp   = at(rec.effectBasePoints, i),     sides = at(rec.effectDieSides, i),
      rppl = at(rec.effectRealPointsPerLevel, i),
      amp  = at(rec.effectAmplitude, i),      misc = at(rec.effectMiscValue, i),
      trig = at(rec.effectTriggerSpell, i),
      ppc  = at(rec.effectPointsPerCombo, i),
    }
  end
  infoCache[id] = I
  return I
end

function A.RankNum(r)
  if type(r) ~= "string" then return 0 end
  local _, _, n = string.find(r, "(%d+)")
  if n then return tonumber(n) end
  return 0
end

function A.IsPassive(I)
  return I and HasBit(I.attributes, 64)
end

-- What the spell does, looking one level into triggered spells (channels such as Arcane Missiles,
-- instant area spells such as Holy Nova). Returns { d, o, hd, ho }:
--   d = direct damage, o = damage over time, hd = direct healing, ho = healing over time
function A.Parts(I)
  local P = { d = false, o = false, hd = false, ho = false }
  if not I then return P end
  local i, j
  for i = 1, 3 do
    local e = I.eff[i]
    if e.type == 2 then P.d = true end
    if e.type == 10 then P.hd = true end
    if e.aura == 3 then P.o = true end
    if e.aura == 8 then P.ho = true end
    if e.trig > 0 then
      local T = A.Info(e.trig)
      if T then
        local chan = e.amp > 0
        for j = 1, 3 do
          local te = T.eff[j]
          if te.aura == 3 then
            P.o = true
          elseif te.type == 2 then
            if chan then P.o = true P.chan = true else P.d = true end
          end
          if te.aura == 8 then
            P.ho = true
          elseif te.type == 10 then
            if chan then P.ho = true P.chan = true else P.hd = true end
          end
        end
      end
    end
  end
  local comp = A.compOf and A.compOf[I.id]
  if comp then
    local cid
    for cid in pairs(comp) do
      local C = A.Info(cid)
      if C then
        for j = 1, 3 do
          local ce = C.eff[j]
          if ce.type == 2 then P.d = true end
          if ce.type == 10 then P.hd = true end
          if ce.aura == 3 then P.o = true end
          if ce.aura == 8 then P.ho = true end
        end
      end
    end
  end
  return P
end

-- Weapon damage effects: 121 normalized weapon damage, 58 / 17 weapon damage, 31 weapon percent.
-- Returns "normalized", "weapon" or nil.
function A.WeaponKind(I)
  if not I then return nil end
  local i, kind
  for i = 1, 3 do
    local t = I.eff[i].type
    if t == 121 then return "normalized" end
    if t == 58 or t == 17 or t == 31 then kind = "weapon" end
  end
  return kind
end

-- true when any effect scales per combo point (these are not learned)
function A.HasCombo(I)
  local i
  for i = 1, 3 do
    if I.eff[i].ppc ~= 0 then return true end
  end
  return false
end

local function MeleeEntry(I, entry)
  if entry and entry.ap ~= nil then return entry end
  return I and AdeSPD_Melee and AdeSPD_Melee[I.en or I.name] or nil
end

-- Does the damage of this spell scale with attack power (instead of spell power)?
function A.UsesAP(I, entry)
  local m = MeleeEntry(I, entry)
  if m and m.ap then return true end
  if entry and entry.school == "Physical" then return true end
  return I ~= nil and (I.school or 0) == 0 and not (entry and entry.heal)
end

function A.IsRanged(I, entry)
  local m = MeleeEntry(I, entry)
  if m and m.ranged then return true end
  return I ~= nil and HasBit(I.attributes, 2)
end

-- Total attack power (base + buffs - debuffs), melee or ranged.
function A.AttackPower(ranged)
  local f = UnitAttackPower
  if ranged then f = UnitRangedAttackPower end
  if type(f) ~= "function" then return 0, "none" end
  local ok, base, pos, neg = pcall(f, "player")
  if not ok or type(base) ~= "number" then return 0, "none" end
  return base + (pos or 0) + (neg or 0), "api"
end

-- Attack power of the pet (Kill Command scales with it); 0 without a pet or without the API.
function A.PetAttackPower()
  if type(UnitAttackPower) ~= "function" then return 0 end
  if UnitExists and not UnitExists("pet") then return 0 end
  local ok, base, pos, neg = pcall(UnitAttackPower, "pet")
  if not ok or type(base) ~= "number" then return 0 end
  return base + (pos or 0) + (neg or 0)
end

-- Spell power, or attack power for abilities that use it. Returns value, source.
function A.PowerFor(isHeal, schoolIdx, I, entry)
  if (not isHeal) and I and A.UsesAP(I, entry) then return A.AttackPower(A.IsRanged(I, entry)) end
  return A.SpellPower(isHeal, schoolIdx)
end

-- Damage multiplier from the armor of your current target against your physical hits (1 = none).
-- Needs an attackable target whose armor the client can read; otherwise 1.
function A.ArmorFactor()
  if type(UnitExists) ~= "function" or not UnitExists("target") then return 1 end
  if type(UnitCanAttack) == "function" and not UnitCanAttack("player", "target") then return 1 end
  local ok, base, eff = pcall(UnitResistance, "target", 0)
  if not ok or type(eff) ~= "number" or eff <= 0 then return 1 end
  local lvl = UnitLevel("player") or 60
  local dr = eff / (eff + 85 * lvl + 400)
  if dr > 0.75 then dr = 0.75 end
  return 1 - dr, dr
end

-- Average weapon hit of a weapon damage ability, as the character sheet shows it (it already contains
-- attack power / 14 x swing speed). Normalized abilities swap the swing speed for the normalized one,
-- "weapon percent" effects (31) scale it. Returns nil when the API is missing.
function A.WeaponRange(kind, ranged)
  local f = UnitDamage
  if ranged then f = UnitRangedDamage end
  if type(f) ~= "function" then return nil end
  local ok, a, b, c = pcall(f, "player")
  if not ok then return nil end
  local mn, mx = a, b
  if ranged then mn, mx = b, c end
  if type(mn) ~= "number" or type(mx) ~= "number" then return nil end
  if kind == "normalized" then
    local d = A.AttackPower(ranged) / 14 * (A.WeaponSpeed("normalized", ranged) - A.WeaponSpeed("weapon", ranged))
    mn, mx = mn + d, mx + d
  end
  return mn, mx
end

function A.WeaponHit(kind, ranged, I)
  local mn, mx = A.WeaponRange(kind, ranged)
  if not mn then return nil end
  local pf = 1
  local i
  for i = 1, 3 do
    if I and I.eff[i].type == 31 then pf = pf * (I.eff[i].bp + 1) / 100 end
  end
  -- average weapon hit, and half the spread of the weapon damage (how far a single hit can be from it)
  return (mn + mx) / 2 * pf, (mx - mn) / 2 * pf
end

-- Weapon speed used by a weapon damage ability: normalized (dagger 1.7, 2H 3.3, else 2.4, ranged 2.8)
-- or the real swing speed. Returns speed in seconds.
function A.WeaponSpeed(kind, ranged)
  if ranged then
    local ok, sp = pcall(UnitRangedDamage, "player")
    if ok and type(sp) == "number" and sp > 0 then return sp end
    return 2.8
  end
  if kind == "normalized" then
    local link = GetInventoryItemLink and GetInventoryItemLink("player", 16)
    if link and GetItemInfo then
      local _, _, _, _, _, _, sub, _, loc = GetItemInfo(link)
      if loc == "INVTYPE_2HWEAPON" then return 3.3 end
      if sub == "Daggers" then return 1.7 end
    end
    return 2.4
  end
  local ok, sp = pcall(UnitAttackSpeed, "player")
  if ok and type(sp) == "number" and sp > 0 then return sp end
  return 2.4
end

-- "dmg" / "heal" / nil
function A.EffectKind(I)
  local P = A.Parts(I)
  if P.d or P.o then return "dmg" end
  if P.hd or P.ho then return "heal" end
  return nil
end

-- Spell id whose spell mods apply: the triggered spell when there is one (Arcane Missiles, Holy Nova).
function A.ModSpellId(I)
  local i
  for i = 1, 3 do
    if I.eff[i].trig > 0 then return I.eff[i].trig end
  end
  return I.id
end

-- Number of ticks of a periodic effect (duration / amplitude).
function A.Ticks(spellId, e)
  local dur = try(GetSpellDuration, spellId, 1)
  if type(dur) == "number" and dur > 0 and e.amp > 0 then return dur / e.amp end
  return nil
end

-- Value range of one effect for this player level: lo, hi (vanilla: bp + 1..sides).
function A.Range(e, I)
  local bp = e.bp
  local lvl = UnitLevel("player") or 60
  if I.maxLevel > 0 and lvl > I.maxLevel then lvl = I.maxLevel end
  if lvl > I.baseLevel and e.rppl ~= 0 then
    local add = (lvl - I.baseLevel) * e.rppl
    if add >= 0 then bp = bp + math.floor(add) else bp = bp + math.ceil(add) end
  end
  if e.sides > 1 then return bp + 1, bp + e.sides end
  if e.sides == 1 then return bp + 1, bp + 1 end
  return bp, bp
end

-- What the spell does according to its record, one entry per kind:
--   { key = "d" | "o" | "hd" | "ho", lo, hi (base value per hit / per tick), ticks, chan }
-- Looks one level into triggered spells like A.Parts does.
function A.PartRanges(I)
  local out, seen = {}, {}
  if not I then return out end
  local function add(key, lo, hi, ticks, chan)
    if seen[key] then return end
    seen[key] = true
    out[table.getn(out) + 1] = { key = key, lo = lo, hi = hi, ticks = ticks or 1, chan = chan }
  end
  local i, j
  for i = 1, 3 do
    local e = I.eff[i]
    local lo, hi = A.Range(e, I)
    if e.type == 2 then add("d", lo, hi) end
    if e.type == 10 then add("hd", lo, hi) end
    if e.aura == 3 then add("o", lo, hi, A.Ticks(I.id, e)) end
    if e.aura == 8 then add("ho", lo, hi, A.Ticks(I.id, e)) end
    if e.trig > 0 then
      local T = A.Info(e.trig)
      if T then
        local chan = e.amp > 0
        for j = 1, 3 do
          local te = T.eff[j]
          local tlo, thi = A.Range(te, T)
          if te.aura == 3 then
            add("o", tlo, thi, A.Ticks(T.id, te))
          elseif te.type == 2 then
            if chan then add("o", tlo, thi, A.Ticks(I.id, e), true) else add("d", tlo, thi) end
          end
          if te.aura == 8 then
            add("ho", tlo, thi, A.Ticks(T.id, te))
          elseif te.type == 10 then
            if chan then add("ho", tlo, thi, A.Ticks(I.id, e), true) else add("hd", tlo, thi) end
          end
        end
      end
    end
  end
  local comp = A.compOf and A.compOf[I.id]
  if comp then
    local cid
    for cid in pairs(comp) do
      local C = A.Info(cid)
      if C then
        for j = 1, 3 do
          local ce = C.eff[j]
          local clo, chi = A.Range(ce, C)
          if ce.type == 2 then add("d", clo, chi) end
          if ce.type == 10 then add("hd", clo, chi) end
          if ce.aura == 3 then add("o", clo, chi, A.Ticks(C.id, ce)) end
          if ce.aura == 8 then add("ho", clo, chi, A.Ticks(C.id, ce)) end
        end
      end
    end
  end
  return out
end

-- Spell modifiers from talents / buffs (Nampower): flat, multiplier.
-- Nampower reports the percent part as a multiplier in percent (102 = x1.02, 90 = x0.9) and 0
-- when there is no percent modifier at all.
function A.Mods(spellId, modType)
  local flat, pct = try(GetSpellModifiers, spellId, modType)
  if type(flat) ~= "number" then flat = 0 end
  local mult = 1
  if type(pct) == "number" and pct ~= 0 then mult = pct / 100 end
  return flat, mult
end

---------------------------------------------------------------------------
-- Auras (buffs): Nampower unit field, SuperWoW as fallback
---------------------------------------------------------------------------

function A.PlayerAuraIds()
  local out, n = {}, 0
  local t = try(GetUnitField, "player", "aura")
  if type(t) == "table" then
    local k, v
    for k, v in pairs(t) do
      if type(v) == "number" and v > 0 then
        n = n + 1
        out[n] = v
      end
    end
  elseif type(GetPlayerBuffID) == "function" and type(GetPlayerBuff) == "function" then
    local i
    for i = 0, 31 do
      local b = GetPlayerBuff(i, "HELPFUL")
      if (not b) or b < 0 then break end
      local id = try(GetPlayerBuffID, b)
      if type(id) == "number" and id > 0 then
        n = n + 1
        out[n] = id
      end
    end
  end
  return out, n
end

local function EffValue(e)
  if e.sides > 1 then return e.bp + (e.sides + 1) / 2 end
  if e.sides == 1 then return e.bp + 1 end
  return e.bp
end

-- Summed effect of the active auras:
--   dmg[s]    flat spell damage per school index (aura 13, MOD_DAMAGE_DONE)
--   dmgPct[s] damage multiplier per school      (aura 79, MOD_DAMAGE_PERCENT_DONE)
--   heal      flat bonus healing                (aura 135, MOD_HEALING_DONE)
--   healMult  healing multiplier                (aura 136, MOD_HEALING_DONE_PERCENT)
function A.AuraTotals()
  local T = { dmg = { 0, 0, 0, 0, 0, 0, 0 }, dmgPct = { 1, 1, 1, 1, 1, 1, 1 }, heal = 0, healMult = 1 }
  local ids, n = A.PlayerAuraIds()
  local k, i, s
  for k = 1, n do
    local I = A.Info(ids[k])
    if I then
      for i = 1, 3 do
        local e = I.eff[i]
        if e.aura == 13 then
          for s = 1, 7 do
            if HasBit(e.misc, 2 ^ (s - 1)) then T.dmg[s] = T.dmg[s] + EffValue(e) end
          end
        elseif e.aura == 79 then
          for s = 1, 7 do
            if HasBit(e.misc, 2 ^ (s - 1)) then T.dmgPct[s] = T.dmgPct[s] * (1 + (e.bp + 1) / 100) end
          end
        elseif e.aura == 135 then
          T.heal = T.heal + EffValue(e)
        elseif e.aura == 136 then
          T.healMult = T.healMult * (1 + (e.bp + 1) / 100)
        end
      end
    end
  end
  return T
end

---------------------------------------------------------------------------
-- Spell power
---------------------------------------------------------------------------

-- Gear fallback: "Equip: Increases ..." lines of the equipped items.
local gear = { both = 0, healonly = 0, school = {} }
local gearDirty = true
local scanTip

function A.MarkGearDirty() gearDirty = true end

local function ScanGear()
  if not scanTip then
    scanTip = CreateFrame("GameTooltip", "AdeSPDScanTooltip", nil, "GameTooltipTemplate")
  end
  local both, healonly, school = 0, 0, {}
  local slot, i
  for slot = 1, 19 do
    scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
    scanTip:ClearLines()
    if scanTip:SetInventoryItem("player", slot) then
      for i = 2, scanTip:NumLines() do
        local fs = getglobal("AdeSPDScanTooltipTextLeft" .. i)
        local t = fs and fs:GetText()
        if t and string.find(t, "^Equip: ") then
          local _, _, v = string.find(t, "Increases damage and healing done by magical spells and effects by up to (%d+)")
          if v then
            both = both + tonumber(v)
          else
            _, _, v = string.find(t, "Increases healing done by spells and effects by up to (%d+)")
            if v then
              healonly = healonly + tonumber(v)
            else
              local sc
              _, _, sc, v = string.find(t, "Increases damage done by (%a+) spells and effects by up to (%d+)")
              if sc and v then school[sc] = (school[sc] or 0) + tonumber(v) end
            end
          end
        end
      end
    end
  end
  gear.both, gear.healonly, gear.school = both, healonly, school
  gearDirty = false
end

-- Returns spell power, source. schoolIdx: 1..7 (Physical, Holy, Fire, Nature, Frost, Shadow, Arcane)
function A.SpellPower(isHeal, schoolIdx)
  local v
  if isHeal then
    v = try(GetSpellBonusHealing)
  elseif schoolIdx then
    v = try(GetSpellBonusDamage, schoolIdx)
  end
  if type(v) == "number" then return v, "api" end
  return A.ComputedSpellPower(isHeal, schoolIdx), "computed"
end

-- Gear scan + auras, used when ClassicAPI's functions are missing (and by /spd debug).
function A.ComputedSpellPower(isHeal, schoolIdx)
  if gearDirty then ScanGear() end
  local T = A.AuraTotals()
  if isHeal then
    return gear.both + gear.healonly + T.heal
  end
  local nm = schoolIdx and A.SCHOOL_NAMES[schoolIdx]
  return gear.both + ((nm and gear.school[nm]) or 0) + ((schoolIdx and T.dmg[schoolIdx]) or 0)
end

---------------------------------------------------------------------------
-- Spell id index: "Name|rank" -> spell id, only for spells in your spellbook
---------------------------------------------------------------------------

A.idByKey = {}
A.known = {}
local scan = nil
local scanFrame

local function key(name, rankNum) return name .. "|" .. rankNum end
A.key = key

function A.IdFor(name, rankNum)
  return A.idByKey[key(name, rankNum)]
end

local function Cache(k, id)
  A.idByKey[k] = id
  A.known[id] = true
  A.DB.idcache[k] = id
end

-- triggered spell id -> the spellbook spell that triggers it (Holy Nova, Arcane Missiles, ...)
A.trigOwner = {}
A.compOf = {}
function A.BuildTriggerMap()
  A.trigOwner = {}
  A.compOf = {}
  local id
  for id in pairs(A.known) do
    local I = A.Info(id)
    if I then
      local i
      for i = 1, 3 do
        local t = I.eff[i].trig
        if t > 0 then A.trigOwner[t] = id end
      end
    end
  end
  -- companion spells found by name (a heal that shares its name with the damage spell but is not
  -- referenced by the record, Holy Nova on Turtle WoW): learned from events, kept in the saved data
  local ev, own
  for ev, own in pairs(A.DB.comp or {}) do
    if A.known[own] and not A.known[ev] then
      A.trigOwner[ev] = own
      if not A.compOf[own] then A.compOf[own] = {} end
      A.compOf[own][ev] = true
    end
  end
end

local function RecMatches(id, name, rankNum)
  local nm, rk = NameRank(id)
  if nm ~= name then return false end
  return A.RankNum(rk) == rankNum
end

function A.SpellbookEntries()
  local out = {}
  local tabs = try(GetNumSpellTabs) or 0
  local t, i
  for t = 1, tabs do
    local _, _, off, num = GetSpellTabInfo(t)
    for i = off + 1, off + num do
      local n, r = GetSpellName(i, "spell")
      if n then
        local rn = A.RankNum(r)
        out[key(n, rn)] = { n, rn }
      end
    end
  end
  return out
end

local function Score(I)
  local s = 0
  if A.EffectKind(I) then s = s + 2 end
  if A.IsPassive(I) then s = s - 3 end
  if I.spellLevel > 0 then s = s + 1 end
  return s
end

local function ScanStep()
  if not scan then return end
  local stop = scan.i + 2500
  while scan.i < stop and scan.i < A.DB.maxId do
    scan.i = scan.i + 1
    local nm, rk = NameRank(scan.i)
    if nm and scan.names[nm] then
      local k = key(nm, A.RankNum(rk))
      if scan.want[k] then
        local I = A.Info(scan.i)
        if I then
          local sc = Score(I)
          if (not scan.best[k]) or sc > scan.score[k] then
            scan.best[k] = scan.i
            scan.score[k] = sc
          end
        end
      end
    end
  end
  if scan.i >= A.DB.maxId then
    local k, id, found = nil, nil, 0
    for k, id in pairs(scan.best) do
      Cache(k, id)
      found = found + 1
    end
    A.Print("spell index ready (" .. found .. "/" .. scan.nwant .. " new spells found)")
    scan = nil
    A.BuildTriggerMap()
    if scanFrame then scanFrame:Hide() end
  end
end

function A.ScanStep() ScanStep() end
function A.IsScanning() return scan ~= nil end

function A.RefreshIndex(force)
  if not A.np then return end
  if scan and not force then return end        -- a scan is already running
  local DB = A.DB
  local _, build = GetBuildInfo()
  if force or DB.build ~= build then
    DB.idcache = {}
    DB.build = build
  end
  A.idByKey, A.known = {}, {}
  local entries = A.SpellbookEntries()
  local missing, names, nmiss = {}, {}, 0
  local k, v
  for k, v in pairs(entries) do
    local id = DB.idcache[k]
    if id and RecMatches(id, v[1], v[2]) then
      A.idByKey[k] = id
      A.known[id] = true
    else
      id = try(GetSpellIdForName, v[1])
      if type(id) == "number" and id > 0 and RecMatches(id, v[1], v[2]) then
        Cache(k, id)
      else
        missing[k] = v
        names[v[1]] = true
        nmiss = nmiss + 1
      end
    end
  end
  A.BuildTriggerMap()
  if nmiss > 0 then
    scan = { i = 0, want = missing, names = names, nwant = nmiss, best = {}, score = {} }
    A.Print("indexing " .. nmiss .. " spell ranks (one time, runs in the background)...")
    if not scanFrame then
      scanFrame = CreateFrame("Frame")
      scanFrame:SetScript("OnUpdate", function() A.ScanStep() end)
    end
    scanFrame:Show()
  end
end
