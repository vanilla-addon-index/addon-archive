-- AdeSPD tooltip: rewrites the numbers of spell tooltips and adds status lines.
--
-- A spell can have four kinds of numbers: d = direct damage, o = damage over time,
-- hd = direct healing, ho = healing over time (Holy Nova has d and hd, Holy Fire has d and o).

local A = AdeSPD
local Round = A.Round
-- The game cuts the damage of a hit down to a whole number (it does not round), so shown numbers are cut too.
local function Floor(x) return math.floor(x + 0.000001) end

local GREEN  = "|cff40ff40"
local GOLD   = "|cffffd100"
local GRAY   = "|cffa0a0a0"
local ORANGE = "|cffff9933"

local KEYS = { "d", "o", "hd", "ho" }
local KEYNAME = { d = "direct", o = "over time", hd = "direct heal", ho = "heal over time" }

---------------------------------------------------------------------------
-- Text rewriting
---------------------------------------------------------------------------

-- A number is an effect value when it follows one of these words ...
local function ValidPre(pre)
  return string.find(pre, "[Ff]or $") or string.find(pre, "[Cc]ausing $") or string.find(pre, "[Cc]auses $")
      or string.find(pre, "[Cc]ause $") or string.find(pre, "[Dd]eals $") or string.find(pre, "[Dd]ealing $")
      or string.find(pre, "[Dd]oing $") or string.find(pre, "[Aa]dditional $") or string.find(pre, "[Aa]nother $")
      or string.find(pre, "[Aa]bsorbs $") or string.find(pre, "[Hh]eals $") or string.find(pre, " of $")
end

-- ... or when "damage" / "health" follows it ("790 to 795 damage over 15 sec", "350 to 435 Holy damage").
local function ValidAfter(after)
  return string.find(after, "^ %a+ damage") or string.find(after, "^ damage") or string.find(after, "^ health")
end

local function LastPos(str, pat)
  local last = 0
  local pos = 1
  while true do
    local s, e = string.find(str, pat, pos)
    if not s then break end
    last = s
    pos = s + 1
  end
  return last
end

-- In a tooltip that mixes damage and healing, decide from the words since the previous number.
local function IsHealClause(clause)
  local _, _, tail = string.find(clause, "^.*%. (.*)$")
  if tail then clause = tail end
  return LastPos(clause, "[Hh]eal") > LastPos(clause, "[Dd]amage")
end

-- ctx.f[key](num, T)  new value of a number of kind key (nil = leave alone). T = number of ticks the
--                     number stands for (1 when it is the total of the whole duration)
-- ctx.kinds           { dmg = bool, heal = bool }
-- Returns the new text and how many numbers changed.
function A.Rewrite(text, ctx)
  local out, pos, len, changed = "", 1, string.len(text), 0
  -- the description can be one text with several lines inside (combo point list "3 points: 103-131 damage")
  local clauseStart = 1
  while pos <= len do
    local s, e, num = string.find(text, "(%d+)", pos)
    if not s then break end
    out = out .. string.sub(text, pos, s - 1)
    local pre = string.sub(text, 1, s - 1)
    local rest = string.sub(text, e + 1)
    pos = e + 1
    -- inside a "N points: lo-hi" line the bonus is per combo point
    local _, _, cpn = string.find(pre, "\n%s*(%d+) points?[^\n]*$")
    if not cpn then _, _, cpn = string.find(pre, "^%s*(%d+) points?[^\n]*$") end
    ctx.cp = cpn and tonumber(cpn) or nil

    local _, de = string.find(rest, "^%.%d+")
    if de then
      -- decimal such as "1.5" or "0.95": copy unchanged
      out = out .. num .. string.sub(rest, 1, de)
      pos = e + 1 + de
    else
      local _, re, num2 = string.find(rest, "^ to (%d+)")
      local sep = " to "
      if not re then
        _, re, num2 = string.find(rest, "^%-(%d+)")      -- "41-192 damage" (combo point lists)
        sep = "-"
      end
      local after = rest
      if re then after = string.sub(rest, re + 1) end

      local fn, T, kk = nil, 1, nil
      if (ValidPre(pre) or ValidAfter(after))
         and not string.find(after, "^ sec") and not string.find(after, "^ min")
         and not string.find(after, "^ yd") and not string.find(after, "^ yard")
         and not string.find(after, "^%%") then
        local _, _, seg = string.find(after, "^([^%d]*)")
        local _, _, ev, tot = string.find(after, "^[^%d]*every ([%d%.]+) sec for ([%d%.]+) sec")
        local over = false
        if string.find(seg, "over") then
          over = true
        elseif ev and tot and tonumber(ev) > 0 then
          over = true
          T = tonumber(tot) / tonumber(ev)
        end
        local heal = false
        if ctx.kinds.heal and ctx.kinds.dmg then
          heal = IsHealClause(string.sub(text, clauseStart, s - 1))
        elseif ctx.kinds.heal then
          heal = true
        end
        if string.find(after, "^ health") then heal = true end        -- "restores 25 health"
        local key = (heal and "h" or "") .. (over and "o" or "d")
        fn = ctx.f[key]
        kk = key
        clauseStart = e + 1
        if re then clauseStart = e + 1 + re end
      end

      if fn then
        local a = fn(tonumber(num), T)
        local b = nil
        if re then b = fn(tonumber(num2), T) end
        if a and kk == "d" and ctx.sum then
          ctx.sum[1] = ctx.sum[1] + a
          ctx.sum[2] = ctx.sum[2] + (b or a)
        end
        if a and ((not re) or b) and (Floor(a) ~= tonumber(num) or (re and Floor(b) ~= tonumber(num2))) then
          changed = changed + 1
          if re then
            out = out .. GREEN .. Floor(a) .. sep .. Floor(b) .. GOLD
          else
            out = out .. GREEN .. Floor(a) .. GOLD
          end
        else
          if re then out = out .. num .. sep .. num2 else out = out .. num end
        end
      else
        if re then out = out .. num .. sep .. num2 else out = out .. num end
      end
      if re then pos = e + 1 + re end
    end
  end
  out = out .. string.sub(text, pos)
  return out, changed
end

---------------------------------------------------------------------------
-- Coefficients from Data.lua
---------------------------------------------------------------------------

-- key: "d" (direct / absorb) or "o" (over time); castBase = rank cast time in sec (talent free)
function A.TableCoef(entry, key, rank, castBase, I)
  local c = entry[key]
  if not c then return nil end
  if key == "d" and entry.drank and entry.drank[rank] then c = entry.drank[rank] end
  if entry.mult then c = c * entry.mult end
  if key == "d" and entry.ct and castBase and castBase > 0 and castBase < entry.ct then
    c = c * castBase / entry.ct
  end
  if I then
    -- vanilla rules: spells learned below level 20 lose 3.75% per missing level, and a rank is
    -- scaled by (rank level + 6) / caster level when you are much higher level than the rank (downranking)
    local lv = I.spellLevel
    if lv > 0 then
      if lv < 20 then c = c * (1 - (20 - lv) * 0.0375) end
      local pl = 0
      if UnitLevel then pl = UnitLevel("player") or 0 end
      if pl > 0 and (lv + 6) / pl < 1 then c = c * (lv + 6) / pl end
    end
  end
  return c
end

-- Cast time of the rank without talents and haste. The tooltip shows it with both applied, so undo the
-- cast time modifier, then snap to the nearest half second when close (cast times come in 0.5 steps;
-- haste makes 3.5 show as 3.41).
local function BaseCast(id, shown)
  if not shown then return nil end
  local b = shown
  if id then
    local flat, mult = A.Mods(id, 10)
    b = (shown * 1000 / mult - flat) / 1000
    if b < 0 then b = 0 end
  end
  local half = math.floor(b * 2 + 0.5) / 2
  if math.abs(b - half) <= 0.15 then b = half end
  return b
end

---------------------------------------------------------------------------
-- Tooltip processing
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Record mode (non English clients): numbers come from the spell record, shown as extra lines
---------------------------------------------------------------------------

local TXT = {
  en = { d = "Damage", o = "Damage over time", hd = "Healing", ho = "Healing over time", tick = "per tick",
         calc = "AdeSPD: calculating in process, need combat data (%d/%d hits)",
         calc2 = "AdeSPD: calculating in process, %d hits, not accurate enough yet, keep using it",
         learned = "AdeSPD: coefficient learned from combat (%d hits)",
         unsupported = "AdeSPD: weapon / combo point abilities are not shown yet on this client language" },
  ru = { d = "Урон", o = "Урон за время", hd = "Исцеление", ho = "Исцеление за время", tick = "за тик",
         calc = "AdeSPD: идёт расчёт, нужны данные боя (%d/%d ударов)",
         calc2 = "AdeSPD: идёт расчёт, %d ударов, пока неточно, продолжайте использовать",
         learned = "AdeSPD: коэффициент выучен в бою (%d ударов)",
         unsupported = "AdeSPD: способности с оружием и очками серии пока не поддерживаются" },
}
local function Lx() return TXT[A.Lang()] or TXT.en end
A.TXT = TXT

-- cast time shown in the header ("2.5 sec cast", Russian clients write the seconds with "сек")
local function CastFromTooltip(tt, prefix, recmode)
  local cast
  local n = tt:NumLines()
  local i
  for i = 2, n do
    local fs = getglobal(prefix .. "TextLeft" .. i)
    local t = fs and fs:GetText()
    if t then
      local _, _, c = string.find(t, "^([%d%.]+) sec cast")
      if c then cast = tonumber(c) end
      if not c and recmode and i <= 5 and string.len(t) < 48 then
        local _, _, c2 = string.find(t, "(%d+[%.,]?%d*)%s*сек")
        if c2 then cast = tonumber((string.gsub(c2, ",", "."))) end
      end
    end
  end
  return cast
end

local function NearNum(a, b)
  local tol = b * 0.025
  if tol < 2 then tol = 2 end
  return math.abs(a - b) <= tol
end

-- Finds the number (or "A - B" range) of the text that equals the stock values of the job and writes the
-- new values in green in its place. job = { slo, shi, nlo, nhi }. Returns the new text and whether it did.
local function InColorCode(text, s)
  local lastc, p = nil, 1
  while true do
    local a = string.find(text, "|c", p, true)
    if not a or a >= s then break end
    lastc = a
    p = a + 1
  end
  return lastc ~= nil and s <= lastc + 9
end

local function ReplaceInText(text, job)
  local pos = 1
  while true do
    local s, e, a = string.find(text, "(%d+)", pos)
    if not s then return text, false end
    local skip = string.find(text, "^[%.,]%d", e + 1)
    if InColorCode(text, s) then skip = true end
    if not skip and s > 2 and string.find(string.sub(text, s - 1, s - 1), "[%.,]") and string.find(string.sub(text, s - 2, s - 2), "%d") then skip = true end
    if not skip then
      local av = tonumber(a)
      local _, re, sep, b = string.find(text, "^(%s*%-%s*)(%d+)", e + 1)
      if not re then _, re, sep, b = string.find(text, "^( до )(%d+)", e + 1) end
      if not re then _, re, sep, b = string.find(text, "^( to )(%d+)", e + 1) end
      if job.shi ~= job.slo then
        if re and NearNum(av, job.slo) and NearNum(tonumber(b), job.shi) then
          return string.sub(text, 1, s - 1) .. GREEN .. Floor(job.nlo) .. sep .. Floor(job.nhi) .. GOLD .. string.sub(text, re + 1), true
        end
      elseif NearNum(av, job.slo) then
        local ne = e
        if re and NearNum(tonumber(b), job.shi) then ne = re end
        return string.sub(text, 1, s - 1) .. GREEN .. Floor(job.nlo) .. GOLD .. string.sub(text, ne + 1), true
      end
    end
    pos = e + 1
  end
end

A.ReplaceInText = ReplaceInText

local function Range(lo, hi)
  if Floor(lo) == Floor(hi) then return "" .. Floor(lo) end
  return Floor(lo) .. "-" .. Floor(hi)
end

-- The real numbers of every part. They replace the stock numbers of the description where those can be
-- recognised (the number matches what the record says); the rest is added as extra lines.
-- Returns how many numbers were replaced plus lines added.
local function RecordLines(tt, prefix, I, P, c, X)
  local added = 0
  local L = Lx()
  local parts = A.PartRanges(I)
  local n = tt:NumLines()
  local jobsOf = {}
  local i, k
  for i = 1, table.getn(parts) do
    local r = parts[i]
    local key = r.key
    local cf = c[key]
    local has = (key == "d" and P.d) or (key == "o" and P.o) or (key == "hd" and P.hd) or (key == "ho" and P.ho)
    if cf and has then
      local heal = (key == "hd" or key == "ho")
      local sp = heal and X.spH or X.spD
      local M = heal and X.MH or X.MD
      local job = { key = key, jobs = {}, done = 0 }
      if key == "d" or key == "hd" then
        local red = heal and 1 or X.red
        local slo, shi = (r.lo + X.flatD) * X.multD, (r.hi + X.flatD) * X.multD
        local nlo, nhi = (slo + sp * cf * X.multD) * M * red, (shi + sp * cf * X.multD) * M * red
        job.jobs[1] = { slo = slo, shi = shi, nlo = nlo, nhi = nhi }
        job.text = L[key] .. ": " .. Range(nlo, nhi)
      else
        local mult, flat = X.multO, X.flatO
        if r.chan then mult, flat = X.multD, X.flatD end
        local ticks = r.ticks
        if not ticks or ticks < 1 then ticks = 1 end
        local slo, shi = r.lo * ticks + flat, r.hi * ticks + flat
        slo, shi = slo * mult, shi * mult
        local nlo, nhi = (slo + sp * cf * mult) * M, (shi + sp * cf * mult) * M
        job.jobs[1] = { slo = slo, shi = shi, nlo = nlo, nhi = nhi }
        job.text = L[key] .. ": " .. Range(nlo, nhi)
        if ticks > 1 then
          job.jobs[2] = { slo = slo / ticks, shi = shi / ticks, nlo = nlo / ticks, nhi = nhi / ticks }
          job.text = job.text .. " (" .. Range(nlo / ticks, nhi / ticks) .. " " .. L.tick .. ")"
        end
      end
      jobsOf[table.getn(jobsOf) + 1] = job
    end
  end

  local replaced, added = 0, 0
  for i = 2, n do
    local fs = getglobal(prefix .. "TextLeft" .. i)
    local t = fs and fs:GetText()
    if t and string.len(t) > 30 and not string.find(t, GREEN, 1, true) then
      local changed = false
      for k = 1, table.getn(jobsOf) do
        local J = jobsOf[k]
        local m
        for m = 1, table.getn(J.jobs) do
          if not J.jobs[m].done then
            local nt, ok = ReplaceInText(t, J.jobs[m])
            if ok then
              t = nt
              J.jobs[m].done = true
              changed = true
              replaced = replaced + 1
            end
          end
        end
      end
      if changed then fs:SetText(t) end
    end
  end
  for k = 1, table.getn(jobsOf) do
    local J = jobsOf[k]
    if not J.jobs[1].done then
      tt:AddLine(GREEN .. J.text .. "|r")
      added = added + 1
    end
  end
  return replaced, added
end

-- Replacement text for spells whose Russian description is wrong (Data_Ru.lua).
local function FixDescription(tt, prefix, enName)
  local fix = AdeSPD_RuText and AdeSPD_RuText[enName]
  if not fix then return false end
  local best, bestLen = nil, 0
  local n = tt:NumLines()
  local i
  for i = 2, n do
    local fs = getglobal(prefix .. "TextLeft" .. i)
    local t = fs and fs:GetText()
    if t and string.len(t) > bestLen and not string.find(t, GREEN, 1, true) then best, bestLen = fs, string.len(t) end
  end
  if best and bestLen > 60 then
    -- {pet:80}: 80% of the attack power of the pet
    local _, _, pct = string.find(fix, "{pet:(%d+)}")
    if pct then
      local val = A.PetAttackPower() * tonumber(pct) / 100
      local rep = ""
      if val > 0 then
        local red = 1
        if A.DB.armor then red = A.ArmorFactor() end
        rep = " " .. GREEN .. "(" .. Floor(val * red) .. ")" .. GOLD
      end
      local s0, e0 = string.find(fix, "{pet:%d+}")
      fix = string.sub(fix, 1, s0 - 1) .. rep .. string.sub(fix, e0 + 1)
    end
    best:SetText(fix)
    tt:Show()
    return true
  end
  return false
end

local function Why(name, rank, msg)
  A.last = name .. " (rank " .. rank .. "): " .. msg
end

-- "45% ranged weapon damage" / "100% of weapon damage" / "150% melee damage" / "weapon damage" /
-- "in addition to your melee damage": add your real weapon damage range (character sheet) in green after
-- the words. Returns the new text and the scaled range (or nil).
local function WeaponPass(t, wk, factor, defRanged)
  if string.find(t, GREEN .. " (", 1, true) then return t, nil, nil end
  local ranged = defRanged
  local s, e, pct
  local pats = { "(%d+)%% of ranged weapon damage", "(%d+)%% ranged weapon damage", "(%d+)%% of weapon damage",
                 "(%d+)%% weapon damage", "(%d+)%% melee damage" }
  local k
  for k = 1, 5 do
    s, e, pct = string.find(t, pats[k])
    if s then
      if k <= 2 then ranged = true end
      break
    end
  end
  if not s then
    s, e = string.find(t, "ranged weapon damage")
    if s then pct, ranged = "100", true end
  end
  if not s then
    s, e = string.find(t, "weapon damage")
    if s then pct = "100" end
  end
  if not s then
    s, e = string.find(t, "your melee damage")
    if s then pct = "100" end
  end
  if not s then return t, nil, nil end
  local mn, mx = A.WeaponRange(wk or "weapon", ranged)
  if not mn then return t, nil, nil end
  pct = tonumber(pct) / 100 * factor
  local lo, hi = mn * pct, mx * pct
  return string.sub(t, 1, e) .. GREEN .. " (" .. Floor(lo) .. " to " .. Floor(hi) .. ")" .. GOLD
    .. string.sub(t, e + 1), lo, hi
end

-- Combo point lists ("3 points: 103-131 damage"): remember the stock ranges per combo point so the learner
-- can measure the attack power bonus per combo point against them.
A.comboRange = {}
A.comboSpells = {}
local function CacheCombo(tt, prefix, id)
  if not id then return end
  local store, any = {}, false
  local i
  for i = 2, tt:NumLines() do
    local fs = getglobal(prefix .. "TextLeft" .. i)
    local t = fs and fs:GetText()
    if t and not string.find(t, GREEN, 1, true) then
      local pos = 1
      while true do
        local s, e, n, lo, hi = string.find(t, "(%d+) points?%s*:%s*(%d+)%-(%d+)", pos)
        if not s then break end
        store[tonumber(n)] = { tonumber(lo), tonumber(hi) }
        any = true
        pos = e + 1
      end
    end
  end
  if any then
    A.comboRange[id] = store
    A.comboSpells[id] = true
  end
end

-- "deals 25% of your Attack Power as damage": add the real number in green after the words.
local function ApPercentPass(t, factor, petFactor)
  if string.find(t, GREEN .. " (", 1, true) then return t, false end
  local ranged = true
  local s, e, pct = string.find(t, "(%d+)%% of your Ranged Attack Power as damage")
  if not s then
    ranged = false
    s, e, pct = string.find(t, "(%d+)%% of your Attack Power as damage")
  end
  local pet = false
  if not s then
    -- "Commands your pet to attack for 80% of its Attack Power": the pet's attack power, not the player's
    s, e, pct = string.find(t, "(%d+)%% of its Attack Power")
    pet = true
  end
  if not s then return t, false end
  local ap
  if pet then ap = A.PetAttackPower() else ap = A.AttackPower(ranged) end
  if not ap or ap <= 0 then return t, true end
  local v = ap * tonumber(pct) / 100 * (pet and petFactor or factor)
  return string.sub(t, 1, e) .. GREEN .. " (" .. Floor(v) .. ")" .. GOLD .. string.sub(t, e + 1), true
end

-- Returns true when the tooltip has such a line; rewrites the lines when factor is given.
local function ApPercentLines(tt, prefix, factor, petFactor)
  local found = false
  local i
  for i = 2, tt:NumLines() do
    local fs = getglobal(prefix .. "TextLeft" .. i)
    local t = fs and fs:GetText()
    if t then
      local nt, has = ApPercentPass(t, factor or 1, petFactor or 1)
      if has then found = true end
      if factor and nt ~= t then fs:SetText(nt) end
    end
  end
  return found
end

-- true when a red "Requires ..." line says the ability cannot be used with the equipped weapon
local function RequirementUnmet(tt, prefix)
  local i
  for i = 2, tt:NumLines() do
    local fs = getglobal(prefix .. "TextLeft" .. i)
    local t = fs and fs:GetText()
    if t and string.find(t, "^Requires ") and fs.GetTextColor then
      local r, g, b = fs:GetTextColor()
      if r and r > 0.8 and g and g < 0.35 and b and b < 0.35 then return true end
    end
  end
  return false
end

-- Returns summed weapon range, and the flat "plus N" of the text when parseFlat.
local function WeaponLines(tt, prefix, wk, factor, I, entry, parseFlat)
  local n = tt:NumLines()
  local i
  local ranged = A.IsRanged(I, entry)
  for i = 2, n do
    local fs = getglobal(prefix .. "TextLeft" .. i)
    local t = fs and fs:GetText()
    if t and string.find(t, "Requires Ranged Weapon", 1, true) then ranged = true end
  end
  local lo, hi, flat
  for i = 2, n do
    local fs = getglobal(prefix .. "TextLeft" .. i)
    local t = fs and fs:GetText()
    if t then
      local nt, l, h = WeaponPass(t, wk, factor, ranged)
      if nt ~= t then fs:SetText(nt) end
      if l then
        lo, hi = (lo or 0) + l, (hi or 0) + h
      end
      if parseFlat and not flat then
        local _, _, f = string.find(t, "plus an additional (%d+)")
        if not f then _, _, f = string.find(t, "plus (%d+)") end
        if not f then _, _, f = string.find(t, "causes (%d+) damage in addition") end
        if not f then _, _, f = string.find(t, "melee damage by (%d+)") end
        if not f then _, _, f = string.find(t, "additional (%d+)") end
        if f and string.find(t, "damage") then flat = tonumber(f) end
      end
    end
  end
  if not lo and I then
    -- no weapon words in the text (Multi-Shot: "hitting 3 targets for an additional 120 damage"):
    -- the ability still hits for weapon damage, scaled by its weapon percent effect
    local w, spread = A.WeaponHit(wk or "weapon", ranged, I)
    if w then lo, hi = w - spread, w + spread end
    if lo then lo, hi = lo * factor, hi * factor end
  end
  return lo, hi, flat
end

function A.Process(tt)
  local DB = A.DB
  if not DB.enabled then return end
  local prefix = tt:GetName()
  if not prefix then return end
  local l1 = getglobal(prefix .. "TextLeft1")
  local name = l1 and l1:GetText()
  if not name then return end
  local r1 = getglobal(prefix .. "TextRight1")
  local rank = A.RankNum(r1 and r1:GetText())

  local id = nil
  if A.np then id = A.IdFor(name, rank) end
  local I = id and A.Info(id) or nil
  local enName = (I and I.en) or name
  local entry = AdeSPD_Data[enName] or (AdeSPD_Melee and AdeSPD_Melee[enName])
  if A.RecordMode() and A.Lang() == "ru" then FixDescription(tt, prefix, enName) end
  if not entry and not I then
    if A.np and A.IsScanning() then Why(name, rank, "spell index still being built") else Why(name, rank, "no spell id found and not in the table") end
    return
  end

  -- which kinds of numbers the spell has
  local P
  if I then
    P = A.Parts(I)
  elseif entry.heal then
    P = { d = false, o = false, hd = entry.d ~= nil, ho = entry.o ~= nil }
  else
    P = { d = entry.d ~= nil, o = entry.o ~= nil, hd = false, ho = false }
  end
  if entry and I and entry.heal and (P.d or P.o) and not (P.hd or P.ho) then
    -- the table says heal, the record found only generic effects: trust the table
    P.hd, P.ho, P.d, P.o = P.d, P.o, false, false
  end
  CacheCombo(tt, prefix, id)
  local apPct = ApPercentLines(tt, prefix, nil)
  if apPct then P = { d = false, o = false, hd = false, ho = false } end      -- the tooltip has no number to scale
  local ap = (not (P.hd or P.ho)) and A.UsesAP(I, entry) and (P.d or P.o)
  local ranged = ap and A.IsRanged(I, entry)

  -- armor of the current target reduces direct physical hits (bleeds ignore it)
  local ar = 1
  if DB.armor and ((I and (I.school or 0) == 0) or (entry and entry.school == "Physical")) then
    ar = A.ArmorFactor()
  end
  local red = ar                                       -- direct hits

  -- damage factor for the weapon hit (talents / buffs that raise damage done)
  local wfactor = 1
  local wk = I and A.WeaponKind(I) or nil
  if not wk and I and (I.school or 0) == 0 and not (P.d or P.o or P.hd or P.ho) then
    -- next-swing abilities (Heroic Strike: "increases melee damage by 21") hit for the swing + the number
    local k
    for k = 2, tt:NumLines() do
      local fs = getglobal(prefix .. "TextLeft" .. k)
      local tx = fs and fs:GetText()
      if tx and string.find(tx, "melee damage by %d+") then wk = "weapon" break end
    end
  end
  if wk and DB.mods then
    local _, m = A.Mods(A.ModSpellId(I), 0)
    local T = A.AuraTotals()
    wfactor = m * (T.dmgPct[(I.school or 0) + 1] or 1)
  end

  if wk then wfactor = wfactor * red end
  if wk and RequirementUnmet(tt, prefix) then wk = nil end       -- wrong weapon equipped: no weapon numbers

  -- weapon, attack power percent and combo point abilities read the tooltip words: English clients only for now
  if A.RecordMode() and (wk or apPct or (I and A.HasCombo(I))) then
    Why(name, rank, "weapon / attack power percent / combo point abilities are not supported on this client language yet")
    return
  end

  if not (P.d or P.o or P.hd or P.ho) then
    if apPct then
      local f = red
      if DB.mods and I then
        local _, m = A.Mods(A.ModSpellId(I), 0)
        local T = A.AuraTotals()
        f = f * m * (T.dmgPct[(I.school or 0) + 1] or 1)
      end
      ApPercentLines(tt, prefix, f, red)
      tt:Show()
      Why(name, rank, "damage is a percent of attack power, number added to the text")
      return
    end
    if wk then
      local lo, hi, flat = WeaponLines(tt, prefix, wk, wfactor, I, entry, true)
      if lo and flat then
        tt:AddLine(GREEN .. "Total damage: " .. Floor(lo + flat * red) .. " to " .. Floor(hi + flat * red) .. "|r")
      end
      tt:Show()
    end
    Why(name, rank, A.WeaponKind(I) and "weapon damage ability without an extra damage number, nothing to add" or "not a damage or healing spell")
    return
  end

  local n = tt:NumLines()
  local i
  local recmode = A.RecordMode()
  local cast = CastFromTooltip(tt, prefix, recmode)

  -- coefficient of every part: table first (or learned first with /spd prefer learned)
  local tc = {}
  if entry then
    local cb = BaseCast(id, cast)
    local lvI = I
    if ap then lvI = nil end                    -- the level 20 penalty is a spell power rule
    local td = A.TableCoef(entry, "d", rank, cb, lvI)
    local to = A.TableCoef(entry, "o", rank, cb, lvI)
    if entry.heal then tc.hd, tc.ho = td, to else tc.d, tc.o = td, to end
  end
  local c, src, hits = {}, {}, {}
  local k
  for k = 1, 4 do
    local key = KEYS[k]
    local lc, ln = A.LearnedFinal(id, key)
    hits[key] = ln
    if DB.prefer == "learned" then
      if lc then c[key], src[key] = lc, "learned" elseif tc[key] then c[key], src[key] = tc[key], "table" end
    else
      if tc[key] then c[key], src[key] = tc[key], "table" elseif lc then c[key], src[key] = lc, "learned" end
    end
  end

  local schoolIdx
  if entry and entry.school then schoolIdx = A.SCHOOL_IDX[entry.school] end
  if not schoolIdx and I then schoolIdx = (I.school or 0) + 1 end
  local spD, srcD
  if ap then spD, srcD = A.AttackPower(ranged) else spD, srcD = A.SpellPower(false, schoolIdx) end
  local spH, srcH = A.SpellPower(true, nil)
  spD, spH = spD or 0, spH or 0
  -- no power at all (a hunter has no spell power): the bonus is zero whatever the coefficient is
  for k = 1, 4 do
    local key = KEYS[k]
    local pw = (key == "d" or key == "o") and spD or spH
    if not c[key] and pw < 5 then c[key], src[key] = 0, "none" end
  end

  -- talents / buffs
  local flatD, multD, flatO, multO, MD, MH = 0, 1, 0, 1, 1, 1
  if DB.mods and id then
    local mid = A.ModSpellId(I)
    flatD, multD = A.Mods(mid, 0)
    flatO, multO = A.Mods(mid, 22)
    if P.chan then multO, flatO = multD, flatD end      -- channel ticks use the damage modifiers
    local T = A.AuraTotals()
    MD = T.dmgPct[schoolIdx or 1] or 1
    MH = T.healMult
  end

  local ctx = { sum = { 0, 0 }, f = {}, kinds = { dmg = (P.d or P.o), heal = (P.hd or P.ho) } }
  local function make(key, sp, M, over)
    local cf = c[key]
    if not cf then return end
    if over then
      ctx.f[key] = function(num, T)
        if not T or T < 1 then T = 1 end
        return (num + sp * cf / T * multO) * M
      end
    else
      ctx.f[key] = function(num)
        return (num + sp * cf * multD * (ctx.cp or 1)) * M * red
      end
    end
  end
  make("d", spD, MD, false)
  make("o", spD, MD, true)
  make("hd", spH, MH, false)
  make("ho", spH, MH, true)

  local total = 0
  if recmode then
    local rep, add = RecordLines(tt, prefix, I, P, c, { spD = spD, spH = spH, MD = MD, MH = MH, flatD = flatD, multD = multD,
                                                        flatO = flatO, multO = multO, red = red })
    total = rep + add
  elseif ctx.f.d or ctx.f.o or ctx.f.hd or ctx.f.ho then
    for i = 2, n do
      local fs = getglobal(prefix .. "TextLeft" .. i)
      local t = fs and fs:GetText()
      if t and not string.find(t, GREEN, 1, true) then
        local newText, changed = A.Rewrite(t, ctx)
        if changed > 0 then
          fs:SetText(newText)
          total = total + changed
        end
      end
    end
  end

  -- explain record for /spd explain
  local ex = name .. " rank " .. rank .. " id " .. tostring(id) .. ": parts"
  for k = 1, 4 do
    local key = KEYS[k]
    local has = (key == "d" and P.d) or (key == "o" and P.o) or (key == "hd" and P.hd) or (key == "ho" and P.ho)
    if has then
      ex = ex .. " [" .. key .. " "
      if c[key] then ex = ex .. string.format("%.1f%% %s", c[key] * 100, src[key]) else ex = ex .. "no coefficient, " .. hits[key] .. " hits" end
      ex = ex .. "]"
    end
  end
  ex = ex .. string.format(", %s dmg %d heal %d, mods x%.2f/x%.2f flat %d/%d, auras x%.2f/x%.2f, armor x%.2f, cast %s, %d numbers changed",
    ap and "attack power" or "spell power", Round(spD), Round(spH), multD, multO, Round(flatD), Round(flatO), MD, MH, ar, tostring(cast), total)
  A.last = ex

  local lines = 0
  if wk then
    local lo, hi = WeaponLines(tt, prefix, wk, wfactor, I, entry, false)
    if lo and P.d and c.d then
      -- weapon hit + the extra damage number; widen with the hits actually seen (target debuffs, ...)
      lo, hi = lo + ctx.sum[1], hi + ctx.sum[2]
      local omn, omx = A.ObservedRange(id, "d")
      if omn then omn, omx = omn * red, omx * red end        -- observed hits are stored before armor
      if omn and omn < lo then lo = omn end
      if omx and omx > hi then hi = omx end
      tt:AddLine(GREEN .. "Total damage: " .. Floor(lo) .. " to " .. Floor(hi) .. "|r")
      lines = lines + 1
    end
  end

  -- parts that exist but have no coefficient yet
  if I and DB.learn then
    local need = false
    local best = 0
    for k = 1, 4 do
      local key = KEYS[k]
      local has = (key == "d" and P.d) or (key == "o" and P.o) or (key == "hd" and P.hd) or (key == "ho" and P.ho)
      if has and not c[key] then
        need = true
        if hits[key] > best then best = hits[key] end
      end
    end
    if need then
      if best >= A.NEED_HITS then
        tt:AddLine(ORANGE .. string.format(Lx().calc2, best) .. "|r")
      else
        tt:AddLine(ORANGE .. string.format(Lx().calc, best, A.NEED_HITS) .. "|r")
      end
      lines = lines + 1
    end
  end

  local learnedHits = nil
  for k = 1, 4 do
    local key = KEYS[k]
    if src[key] == "learned" and (not learnedHits or hits[key] > learnedHits) then learnedHits = hits[key] end
  end
  if learnedHits then
    tt:AddLine(GRAY .. string.format(Lx().learned, learnedHits) .. "|r")
    lines = lines + 1
  end

  if DB.detail then
    local parts = ""
    for k = 1, 4 do
      local key = KEYS[k]
      if c[key] then parts = parts .. string.format(" %s %.1f%%", KEYNAME[key], c[key] * 100) end
    end
    if parts ~= "" then
      local extra = ""
      if multD ~= 1 or multO ~= 1 or MD ~= 1 or MH ~= 1 then
        extra = string.format(", mods x%.2f/x%.2f, buffs x%.2f", multD, multO, MD)
      end
      local sp = ""
      if ctx.kinds.dmg then sp = Round(spD) end
      if ctx.kinds.heal then
        if sp ~= "" then sp = sp .. "/" .. Round(spH) .. " heal" else sp = Round(spH) .. " heal" end
      end
      tt:AddLine(GRAY .. "AdeSPD: " .. (ap and "attack power " or "spell power ") .. sp .. " (" .. srcD .. ")," .. parts .. extra .. "|r")
      lines = lines + 1
    end
  end

  if total > 0 or lines > 0 then tt:Show() end
end

---------------------------------------------------------------------------
-- Hooks
---------------------------------------------------------------------------

local hooked = false

local function HookMethod(tt, method)
  local orig = tt[method]
  if type(orig) ~= "function" then return end
  tt[method] = function(self, a1, a2, a3)
    local r1, r2, r3 = orig(self, a1, a2, a3)
    -- spellbook tooltips stay untouched unless /spd book is on
    if method == "SetAction" or A.DB.spellbook then
      local ok, err = pcall(A.Process, self)
      if not ok then A.DB.lasterror = err end
    end
    return r1, r2, r3
  end
end

function A.InstallHooks()
  if hooked then return end
  hooked = true
  HookMethod(GameTooltip, "SetAction")
  HookMethod(GameTooltip, "SetSpell")
end
