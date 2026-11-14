-- AdeSPD combat learner.
-- For spell parts that have no coefficient in Data.lua we measure it from your own hits:
--
--   hit = ((baseRoll + spellPower * coefficient) * auraMult + flatMod) * modMult
--
-- Every non-crit hit is turned back into a coefficient estimate (baseRoll is taken as the middle
-- of the spell's base range, whose width is the only noise). The estimates are averaged; after
-- AdeSPD.NEED_HITS hits with a small standard error the value is used in the tooltip.
-- Uses Nampower's SPELL_DAMAGE_EVENT_SELF / SPELL_HEAL_BY_SELF events.
--
-- Stored parts: "d" direct damage, "o" damage over time, "hd" direct healing, "ho" healing over time.

local A = AdeSPD
local try = A.try

local BATCH    = 100      -- hits per refinement batch (after the first value is shown at NEED_HITS)
local MIN_SP   = 5        -- below this power a hit says nothing about the coefficient (the standard error check does the rest)
local MAX_SE   = 0.05     -- standard error (as a coefficient, 0.05 = 5%) needed to trust a value
local MAX_ERR  = 3        -- ... and the same error times your spell / attack power must be under this many damage points

---------------------------------------------------------------------------
-- Why events were not used (shown by /spd why)
---------------------------------------------------------------------------

A.skips = {}
A.skipById = {}     -- last skip reason per spell id
A.seen = {}         -- number of damage / heal events per spell id since login
local nskips = 0
local function Skip(why)
  local _, _, sid = string.find(why, "^(%d+):")
  if sid then A.skipById[tonumber(sid)] = why end
  nskips = nskips + 1
  A.skips[math.mod(nskips, 12) + 1] = why
end
function A.SkipCount() return nskips end

-- last few measurements of combo point abilities (shown by /spd why)
A.notes = {}
local nnotes = 0
function A.Note(msg)
  nnotes = nnotes + 1
  A.notes[math.mod(nnotes, 6) + 1] = msg
end

---------------------------------------------------------------------------
-- Stored statistics
---------------------------------------------------------------------------

local function Accumulate(id, part, c, raw, power, w)
  local DB = A.DB
  local weighted = w ~= nil
  w = w or 1
  local L = DB.learned[id]
  if not L then
    L = {}
    DB.learned[id] = L
  end
  local s = L[part]
  if not s then
    s = { n = 0, w = 0, s = 0, q = 0 }
    L[part] = s
  end
  if not s.w then s.w = s.n end
  -- combo finisher data gathered before the weighted model (or with mistakes) is thrown away once
  if weighted and s.cw ~= 2 then
    s.n, s.w, s.s, s.q, s.p, s.fin, s.fn, s.mx, s.mn, s.fmx, s.fmn = 0, 0, 0, 0, 0, nil, nil, nil, nil, nil, nil
    s.cw = 2
  end
  -- a hit far away from what the others say (wrong combo point count, an unmodelled debuff) is dropped
  if s.n >= 15 and s.w > 0 and power and power > 0 then
    local m = s.s / s.w
    local v = (s.q - s.w * m * m) / (s.n - 1)
    if v < 0 then v = 0 end
    local sd = math.sqrt(v)
    if sd < 0.02 then sd = 0.02 end
    local r = math.abs(c - m) * math.sqrt(w)
    if r > 4 * sd and r * power > 25 then
      A.outliers = (A.outliers or 0) + 1
      return
    end
  end
  s.n = s.n + 1
  s.w = s.w + w
  s.s = s.s + w * c
  s.q = s.q + w * c * c
  s.p = (s.p or 0) + (power or 0) * math.sqrt(w)
  if raw then
    -- lowest / highest full hit seen (before armor), used for the "Total damage" range
    if not s.mx or raw > s.mx then s.mx = raw end
    if not s.mn or raw < s.mn then s.mn = raw end
  end
  if s.n >= BATCH then
    s.fmx, s.fmn = s.mx, s.mn
    s.mx, s.mn = nil, nil
    -- batch finished: its mean becomes the shown value (if it is stable), then a new batch starts
    local mean = s.s / s.w
    local var = (s.q - s.w * mean * mean) / (s.n - 1)
    if var < 0 then var = 0 end
    local se0 = math.sqrt(var / s.w)
    if se0 <= MAX_SE and se0 * (s.p / s.n) <= MAX_ERR then
      if mean < 0 then mean = 0 end
      s.fin = mean
      s.fn = (s.fn or 0) + s.n
    end
    s.n, s.w, s.s, s.q, s.p = 0, 0, 0, 0, 0
  end
end

-- Returns mean, hits, standard error.
function A.LearnedStats(id, part)
  local L = id and A.DB.learned[id]
  local s = L and L[part]
  if not s or s.n < 1 then return nil, 0, 1 end
  local w = s.w or s.n
  local mean = s.s / w
  local se = 1
  if s.n > 1 then
    local var = (s.q - w * mean * mean) / (s.n - 1)
    if var < 0 then var = 0 end
    se = math.sqrt(var / w)
  end
  return mean, s.n, se
end

-- Lowest / highest full non-crit hit of the last finished batch and the running one.
function A.ObservedRange(id, part)
  local L = id and A.DB.learned[id]
  local s = L and L[part]
  if not s then return nil end
  local mn, mx = s.fmn, s.fmx
  if s.n >= 5 then
    if s.mx and ((not mx) or s.mx > mx) then mx = s.mx end
    if s.mn and ((not mn) or s.mn < mn) then mn = s.mn end
  end
  return mn, mx
end

-- Returns coefficient (only when trusted), hits.
-- Once a 100-hit batch has finished, its value is used (and replaced by every following batch).
function A.LearnedFinal(id, part)
  local L = id and A.DB.learned[id]
  local f = L and L[part]
  if f and f.fin then return f.fin, f.fn end
  local mean, n, se = A.LearnedStats(id, part)
  local L2 = id and A.DB.learned[id]
  local s2 = L2 and L2[part]
  local avgp = (s2 and s2.n > 0 and s2.p) and (s2.p / s2.n) or 0
  if mean and n >= A.NEED_HITS and se <= MAX_SE and se * avgp <= MAX_ERR then
    if mean < 0 then mean = 0 end
    return mean, n
  end
  return nil, n
end

---------------------------------------------------------------------------
-- Turning an event into a measurement
---------------------------------------------------------------------------

-- The spellbook spell whose tooltip owns this event. Damage / healing often comes from a triggered
-- spell (Holy Nova, Arcane Missiles); for channels the active cast is the fallback.
local function Owner(eventId)
  if A.known[eventId] then return eventId end
  if A.trigOwner[eventId] then return A.trigOwner[eventId] end
  local ci = try(GetCastInfo)
  if type(ci) == "table" and ci.spellId and ci.spellId ~= 0 then
    local oi = A.Info(ci.spellId)
    if oi then
      local i
      for i = 1, 3 do
        if oi.eff[i].trig == eventId then return ci.spellId end
      end
    end
  end
  -- an event spell that shares its name with exactly one kind of spellbook spell is its companion
  -- (the heal of Holy Nova): remember it, so tooltip and learner treat it as part of that spell
  local ev = A.Info(eventId)
  if ev and ev.name and ev.name ~= "" then
    local best = nil
    local id
    for id in pairs(A.known) do
      local K = A.Info(id)
      if K and K.name == ev.name and not A.IsPassive(K) then
        if (not best) or (K.spellLevel == ev.spellLevel and best.spellLevel ~= ev.spellLevel)
           or (K.spellLevel == ev.spellLevel and best.spellLevel == ev.spellLevel and A.RankNum(K.rank) > A.RankNum(best.rank)) then
          best = K
        elseif best.spellLevel ~= ev.spellLevel and K.spellLevel ~= ev.spellLevel and A.RankNum(K.rank) > A.RankNum(best.rank) then
          best = K
        end
      end
    end
    if best then
      A.DB.comp[eventId] = best.id
      A.trigOwner[eventId] = best.id
      if not A.compOf[best.id] then A.compOf[best.id] = {} end
      A.compOf[best.id][eventId] = true
      return best.id
    end
  end
  return eventId
end

-- Returns owner id, part ("d" or "o"), lo, hi (base range per hit), ticks.
local function Model(eventId, periodic, heal)
  local ev = A.Info(eventId)
  if not ev then Skip(eventId .. ": no spell record") return nil end
  local owner = Owner(eventId)
  local oi = A.Info(owner)
  if not oi then Skip(eventId .. ": owner " .. owner .. " has no record") return nil end
  local wantType, wantAura = 2, 3
  if heal then wantType, wantAura = 10, 8 end
  local i

  if periodic then
    local e = nil
    for i = 1, 3 do
      if ev.eff[i].aura == wantAura then e = ev.eff[i] break end
    end
    if not e then Skip(eventId .. ": periodic event but no periodic effect in the record") return nil end
    local ticks = A.Ticks(eventId, e)
    if not ticks then Skip(eventId .. ": no duration / amplitude for ticks") return nil end
    local lo, hi = A.Range(e, ev)
    return owner, "o", lo, hi, ticks
  end

  local e = nil
  for i = 1, 3 do
    if ev.eff[i].type == wantType then e = ev.eff[i] break end
  end
  if not e then Skip(eventId .. ": no direct " .. (heal and "heal" or "damage") .. " effect in the record") return nil end
  local lo, hi = A.Range(e, ev)
  if owner ~= eventId then
    -- triggered by another spell: a channel tick when the trigger effect has an amplitude, else a direct hit
    local oe = nil
    for i = 1, 3 do
      if oi.eff[i].trig == eventId then oe = oi.eff[i] break end
    end
    if oe and oe.amp > 0 then
      local ticks = A.Ticks(owner, oe)
      if not ticks then Skip(eventId .. ": channel without duration") return nil end
      return owner, "o", lo, hi, ticks, true
    end
  end
  return owner, "d", lo, hi, 1
end

-- Fraction of physical damage removed by the armor of the target (only when it is your current target).
local function ArmorReduction(target)
  local g = try(GetUnitGUID, "target")
  if not g or not target or string.lower(tostring(g)) ~= string.lower(tostring(target)) then return nil end
  local ok, base, eff = pcall(UnitResistance, "target", 0)
  if not ok or type(eff) ~= "number" or eff <= 0 then return nil end
  local lvl = UnitLevel("player") or 60
  local dr = eff / (eff + 85 * lvl + 400)
  if dr > 0.75 then dr = 0.75 end
  return dr
end

-- Combo point finishers (Eviscerate): the bonus is attack power x coefficient x combo points. The stock
-- tooltip lists the range per combo point; the coefficient is measured against the middle of that range.
local function MeasureCombo(owner, eventId, amount, target)
  local DB = A.DB
  local cp = A.cp
  if A.spent and (not GetTime or GetTime() - (A.spentT or 0) < 2) then cp = A.spent end
  A.spent = nil
  local R = A.comboRange[owner]
  local oi = A.Info(owner)
  local ev = A.Info(eventId)
  local nm = oi and oi.name or tostring(owner)
  if not cp or not R or not R[cp] then
    Skip(eventId .. ": combo point ability, hover the " .. nm .. " tooltip once after login and use it with combo points")
    return
  end
  local schoolIdx = ((ev and ev.school) or 0) + 1
  if schoolIdx == 1 then
    local dr = ArmorReduction(target)
    if not dr then Skip(eventId .. ": physical hit, target armor unknown (target the mob you hit)") return end
    amount = amount / (1 - dr)
  end
  local sp = A.AttackPower(A.IsRanged(oi, nil))
  if type(sp) ~= "number" or sp < MIN_SP then Skip(eventId .. ": attack power " .. tostring(sp) .. " below " .. MIN_SP) return end
  local M, mult = 1, 1
  if DB.mods then
    local T = A.AuraTotals()
    M = T.dmgPct[schoolIdx] or 1
    local _, m = A.Mods(eventId, 0)
    mult = m
  end
  local mid = (R[cp][1] + R[cp][2]) / 2
  local c = ((amount / M - mid) / mult) / (sp * cp)
  A.Note(string.format("%s: %d combo points, hit %d (stock middle %d) -> coefficient %.4f, attack power %d", nm, cp,
    math.floor(amount), mid, c, math.floor(sp)))
  if c < -0.02 or c > 0.3 then Skip(eventId .. ": combo coefficient " .. c .. " out of range") return end
  Accumulate(owner, "d", c, amount, sp, cp * cp)
end

local function Measure(heal, eventId, amount, periodic, target)
  local DB = A.DB
  if not DB.learn or not A.np then return end
  local owner, part, lo, hi, ticks, chan = Model(eventId, periodic, heal)
  if not owner then return end
  if (not heal) and part == "d" and A.comboSpells[owner] then
    MeasureCombo(owner, eventId, amount, target)
    return
  end
  if heal then part = "h" .. part end
  local ev = A.Info(eventId)
  local schoolIdx = (ev.school or 0) + 1
  local oi = A.Info(owner)
  local enName = ev.en or ev.name
  local entry = AdeSPD_Data[enName] or (AdeSPD_Melee and AdeSPD_Melee[enName])
  local ap = (not heal) and A.UsesAP(oi, entry)
  if ap then
    if A.HasCombo(ev) or A.HasCombo(oi) then Skip(eventId .. ": combo point ability, not learned") return end
    -- armor reduces direct physical hits (bleeds ignore it)
    if schoolIdx == 1 and part == "d" then
      local dr = ArmorReduction(target)
      if not dr then Skip(eventId .. ": physical hit, target armor unknown (target the mob you hit)") return end
      amount = amount / (1 - dr)
    end
  end
  local sp = A.PowerFor(heal, schoolIdx, oi, entry)
  if type(sp) ~= "number" or sp < MIN_SP then Skip(eventId .. ": " .. (ap and "attack" or "spell") .. " power " .. tostring(sp) .. " below " .. MIN_SP) return end

  local M = 1
  local flat, mult = 0, 1
  if DB.mods then
    local T = A.AuraTotals()
    if heal then M = T.healMult else M = T.dmgPct[schoolIdx] or 1 end
    -- real DoT ticks use the DoT modifiers; channel ticks (Icicles, Arcane Missiles) are damage hits and
    -- use the damage modifiers
    local modType = 0
    if periodic then modType = 22 end
    flat, mult = A.Mods(eventId, modType)
    if modType == 22 then flat = flat / ticks end
  end

  local x = (amount / mult - flat) / M
  local pad = 0
  local wsrc = ev
  if not A.WeaponKind(ev) then wsrc = oi end
  local wk = A.WeaponKind(wsrc)
  if wk and not heal then
    -- weapon damage ability with an extra damage number (Steady Shot, Arcane Shot): take the weapon hit out
    -- first. A single hit can be anywhere in the weapon damage range, so allow for that below.
    local w, spread = A.WeaponHit(wk, A.IsRanged(oi, entry), wsrc)
    if not w then Skip(eventId .. ": weapon damage unknown") return end
    x = x - w
    pad = spread
  end
  -- discard hits that cannot be explained (unmodelled debuffs on the target, overheal, ...)
  if x < lo - 1.5 - pad or x > hi + 2 * sp + 2 + pad then
    Skip(eventId .. ": amount " .. amount .. " does not fit base " .. lo .. ".." .. hi .. " + spell power " .. math.floor(sp))
    return
  end
  local c = (x - (lo + hi) / 2) / sp
  if part == "o" or part == "ho" then c = c * ticks end
  if c < -0.2 or c > 4 then Skip(eventId .. ": coefficient " .. c .. " out of range") return end
  Accumulate(owner, part, c, amount, sp)
end

---------------------------------------------------------------------------
-- Event entry points
---------------------------------------------------------------------------

local function IsMine(guid)
  local mine = try(GetUnitGUID, "player")
  if not mine or not guid then return true end
  return string.lower(tostring(guid)) == string.lower(tostring(mine))
end

local function ParseMitigation(str)
  if type(str) ~= "string" then return 0, 0, 0 end
  local _, _, a, b, c = string.find(str, "(%-?%d+),(%-?%d+),(%-?%d+)")
  return tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0
end

-- SPELL_DAMAGE_EVENT_SELF: targetGuid, casterGuid, spellId, amount, mitigationStr, hitInfo, spellSchool, effectAuraStr
function A.OnDamage(target, caster, spellId, amount, mit, hitInfo, school, effAura)
  if A.DB.log then
    A.Print("dmg " .. tostring(spellId) .. " amount=" .. tostring(amount) .. " mit=" .. tostring(mit)
      .. " hit=" .. tostring(hitInfo) .. " school=" .. tostring(school) .. " aura=" .. tostring(effAura))
  end
  if not IsMine(caster) then return end
  spellId = tonumber(spellId)
  amount = tonumber(amount) or 0
  if not spellId or amount <= 0 then return end
  A.seen[spellId] = (A.seen[spellId] or 0) + 1
  if tonumber(hitInfo) == 2 then return end              -- crit
  local absorb, block, resist = ParseMitigation(mit)
  local periodic = false
  if type(effAura) == "string" then
    local _, _, au = string.find(effAura, "(%d+)%s*$")
    if au and tonumber(au) > 0 then periodic = true end
  end
  Measure(false, spellId, amount + absorb + resist, periodic, target)
end

-- SPELL_HEAL_BY_SELF: targetGuid, casterGuid, spellId, amount, critical, periodic
function A.OnHeal(target, caster, spellId, amount, crit, periodic)
  if A.DB.log then
    A.Print("heal " .. tostring(spellId) .. " amount=" .. tostring(amount) .. " crit=" .. tostring(crit)
      .. " periodic=" .. tostring(periodic))
  end
  if not IsMine(caster) then return end
  spellId = tonumber(spellId)
  amount = tonumber(amount) or 0
  if not spellId or amount <= 0 then return end
  A.seen[spellId] = (A.seen[spellId] or 0) + 1
  if tonumber(crit) == 1 then return end
  Measure(true, spellId, amount, tonumber(periodic) == 1)
end
