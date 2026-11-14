-- The real comparison: the hovered item against what you wear in the slot it would take.
-- Builds the data table the panel (Panel.lua) draws. Scores are in the currency of your class
-- (1 point = 1 spell power, healing power or attack power), worked out with your talents (Weights.lua).
--
-- Weapons are scored with the weights of the character that HOLDS them: a dagger and a sword each
-- get the weights you would have with that weapon in hand (Backstab needs a dagger, a slow weapon
-- hits harder with special attacks), so the totals are comparable.

local AG = AdeGear
local Compare = {}
AG.Compare = Compare

local WEAPON_SLOTS = { [16] = true, [17] = true, [18] = true, [0] = true }

local function Copy(t)
  local n = {}
  for k, v in pairs(t) do n[k] = v end
  return n
end

-- weights of the character c (with an item in a weapon slot when slot is given), role mix as given
local function WeightsFor(c, mix, slot, item, replace)
  local c2 = Copy(c)
  if mix then c2.mix = mix end
  if slot and WEAPON_SLOTS[slot] then AG.Char.Override(c2, slot, item) end
  local w = AG.Weights.Compute(c2)
  if w then pcall(AG.Weights.ApplyCaps, w, c2) end
  return w
end

local function Add(into, rows)
  for k, v in pairs(rows) do into[k] = (into[k] or 0) + v end
end

-- one scenario: newItem goes into slot, "gone" lists { item, slot } that leave the body
-- returns old score, new score, rows delta, stat amount delta, weights of the new state
local function Evaluate(c, mix, scenario)
  local wOld = WeightsFor(c, mix)
  if not wOld then return nil end
  local oldTotal, newTotal = 0, 0
  local rows, amounts = {}, {}

  for i = 1, table.getn(scenario.gone) do
    local g = scenario.gone[i]
    local tot, r, st = AG.Weights.ItemValue(g.item, wOld, g.slot)
    oldTotal = oldTotal + tot
    for k, v in pairs(r) do rows[k] = (rows[k] or 0) - v end
    for k, v in pairs(st) do amounts[k] = (amounts[k] or 0) - v end
  end

  local wNew = wOld
  if WEAPON_SLOTS[scenario.slot] then
    wNew = WeightsFor(c, mix, scenario.slot, scenario.item)
    if not wNew then return nil end
  end
  local tot, r, st = AG.Weights.ItemValue(scenario.item, wNew, scenario.slot)
  newTotal = tot
  Add(rows, r)
  Add(amounts, st)

  -- a weapon change also changes how the weapons you keep are worth (an off hand dagger without a
  -- dagger in the main hand ...): the kept ones are counted under the new weights as well
  if WEAPON_SLOTS[scenario.slot] then
    for i = 1, table.getn(scenario.kept or {}) do
      local g = scenario.kept[i]
      local t1, r1 = AG.Weights.ItemValue(g.item, wOld, g.slot)
      local t2, r2 = AG.Weights.ItemValue(g.item, wNew, g.slot)
      oldTotal = oldTotal + t1
      newTotal = newTotal + t2
      for k, v in pairs(r1) do rows[k] = (rows[k] or 0) - v end
      Add(rows, r2)
    end
  end
  return { old = oldTotal, new = newTotal, rows = rows, amounts = amounts, wOld = wOld, wNew = wNew }
end

local function ItemCard(it, score)
  return { name = it.name, q = it.quality or 1, icon = it.icon, score = score }
end

-- how many pieces of a set you really wear: the piece names of the tooltip against the names of your
-- worn items. (The piece count in a tooltip was off by one for worn pieces on some reads, so it is not trusted.)
local wornNames = nil
local function WornNames()
  local names = {}
  local any = false
  for slot = 1, 19 do
    local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
    if link then
      local s, e, name = string.find(link, "%[(.-)%]")
      if name then names[name] = true; any = true end
    end
  end
  if not any then return nil end
  return names
end

local function Have(set)
  -- worn pieces counted from your slots beat the number printed in a tooltip
  local counts = AG.Weights.SetCounts and AG.Weights.SetCounts()
  if counts and set and set.name and counts[set.name] then return counts[set.name] end
  if not wornNames or not set or not set.pieces or table.getn(set.pieces) == 0 then return set and set.have end
  local n = 0
  for i = 1, table.getn(set.pieces) do
    if wornNames[set.pieces[i].name] then n = n + 1 end
  end
  return n
end

-- set bonuses: the pieces you would wear after the swap. Bonuses that need more pieces than you have now
-- and not more than you would have are counted as extra stats on the new item. Taking a piece out of
-- ANOTHER set can switch its bonuses off; the tooltip does not say which, so that only gives a note.
local function SetEffect(it, sc)
  local notes = {}
  local S = it.set
  local extra = nil
  if S and S.name and S.have and S.bonuses then
    local before = Have(S)
    local after = before + 1
    for i = 1, table.getn(sc.gone) do
      local g = sc.gone[i].item
      if g.set and g.set.name == S.name then after = after - 1 end
    end
    for i = 1, table.getn(S.bonuses) do
      local b = S.bonuses[i]
      if b.n and b.n > before and b.n <= after then
        if b.stats and next(b.stats) then
          extra = extra or {}
          for k, v in pairs(b.stats) do extra[k] = (extra[k] or 0) + v end
          table.insert(notes, "Set bonus (" .. b.n .. " pieces) counted: " .. b.text)
        else
          table.insert(notes, "Set bonus (" .. b.n .. " pieces), not counted: " .. b.text)
        end
      end
    end
  end
  for i = 1, table.getn(sc.gone) do
    local g = sc.gone[i].item
    if g.set and g.set.name and g.set.have and not (S and S.name == g.set.name) then
      local gHave = Have(g.set)
      local gAfter = gHave - 1
      local unknown = false
      for j = 1, table.getn(g.set.bonuses or {}) do
        local b = g.set.bonuses[j]
        -- on by the tooltip colour, or because you wear enough pieces for a bonus whose number is known
        local on = b.active or (b.n and b.n <= gHave)
        if on then
          if b.n then
            if b.n > gAfter and b.n <= gHave then
              -- this bonus needs the piece you take out
              if b.stats and next(b.stats) then
                extra = extra or {}
                for k, v in pairs(b.stats) do extra[k] = (extra[k] or 0) - v end
                table.insert(notes, "Loses set bonus of " .. g.set.name .. " (" .. b.n .. " pieces): " .. b.text)
              else
                table.insert(notes, "Loses set bonus of " .. g.set.name .. " (" .. b.n .. " pieces), not counted: " .. b.text)
              end
            end
          elseif not (b.minHave and b.minHave <= gAfter) then
            unknown = true
          end
        end
      end
      if unknown then
        table.insert(notes, "Takes a piece out of " .. g.set.name .. " (" .. tostring(gHave) .. "/" .. tostring(g.set.total) .. "): a bonus may stop, its piece count is not known yet (hover the set's pieces you do not wear and it learns it)")
      end
    end
  end
  if not extra then return it, notes end
  local copy = {}
  for k, v in pairs(it) do copy[k] = v end
  copy.stats = {}
  for k, v in pairs(it.stats) do copy.stats[k] = v end
  for k, v in pairs(extra) do copy.stats[k] = (copy.stats[k] or 0) + v end
  return copy, notes
end

-- damage reduction from armor (1.12 formula), capped at 75%
local function Reduction(armor, level)
  local dr = armor / (armor + 400 + 85 * level)
  if dr > 0.75 then dr = 0.75 end
  return dr * 100
end

-- every way the item can go in: list of scenarios
local function Scenarios(it, targets)
  local list = {}
  local main = AG.Items.FromSlot(16)
  for i = 1, table.getn(targets) do
    local t = targets[i]
    local eq = t.equipped
    -- a one-hander can't go in the off hand while a two-hander is held: not a real option
    local blocked = (t.slot == 17 and it.slot == "ONEHAND" and main and main.slot == "TWOHAND")
    if not blocked then
    local sc = { slot = t.slot, item = it, label = t.label, gone = {}, kept = {}, notes = {}, equipped = eq }
    for j = 1, table.getn(t.notes or {}) do table.insert(sc.notes, t.notes[j]) end
    if eq then table.insert(sc.gone, { item = eq, slot = t.slot }) end

    if t.slot == 16 then
      local off = AG.Items.FromSlot(17)
      if it.slot == "TWOHAND" and off then
        table.insert(sc.gone, { item = off, slot = 17 })
        sc.label = "Main hand + off hand"
      elseif off and not (eq and eq.slot == "TWOHAND") then
        table.insert(sc.kept, { item = off, slot = 17 })
      end
    elseif t.slot == 17 then
      local main = AG.Items.FromSlot(16)
      if main and main.slot == "TWOHAND" then
        -- a shield or off-hand item can't be worn with a two-hander: the game takes the two-hander off
        table.insert(sc.gone, { item = main, slot = 16 })
        sc.label = "Off hand (replaces the two-hander)"
      elseif main then
        table.insert(sc.kept, { item = main, slot = 16 })
      end
    end
    local pseudo, setNotes = SetEffect(it, sc)
    sc.item = pseudo
    for j = 1, table.getn(setNotes) do table.insert(sc.notes, setNotes[j]) end
    table.insert(list, sc)
    end
  end
  return list
end


local function CapNotes(res, c)
  local notes = {}
  local caps = res.wNew and res.wNew.caps
  if not caps then return notes end
  local order = { "HIT", "SPELLHIT", "DEFENSE" }
  for i = 1, 3 do
    local k = order[i]
    local cp = caps[k]
    local d = res.amounts[k]
    if cp and d and d ~= 0 then
      local after = cp.have + d
      local text
      if after >= cp.cap then
        text = string.format("%s: %g of about %g, the cap is reached", cp.name, after, cp.cap)
        if cp.have >= cp.cap then text = text .. " (more has little value)" end
      else
        text = string.format("%s: %g of about %g (cap)", cp.name, after, cp.cap)
      end
      if k == "DEFENSE" and after >= cp.cap then
        text = string.format("Defense %g: crit immune (%g), more is only avoidance", after, cp.cap)
      end
      table.insert(notes, text)
    end
  end
  return notes
end

local STATE_NOTICE = {
  itemlevel = { "USABLE LATER", { 1, 0.82, 0 } },
  train = { "NEEDS TRAINING", { 1, 0.6, 0.2 } },
  level = { "LOCKED BY LEVEL", { 1, 0.6, 0.2 } },
  prof = { "NEEDS A PROFESSION", { 1, 0.6, 0.2 } },
  need = { "NEEDS A MATCHING WEAPON", { 1, 0.6, 0.2 } },
}

local function Pretty(class)
  return string.upper(string.sub(class, 1, 1)) .. string.lower(string.sub(class, 2))
end

-- builds the panel data for an item, or nil when there is nothing to compare (not gear)
function Compare.Build(it)
  if not it or not it.slot or it.bag or it.slot == "SHIRT" or it.slot == "TABARD" then return nil end
  local ctx = AG.Rules.Context()
  local check = AG.Rules.Check(it, ctx)
  local ok, c = pcall(AG.Char.Basic)
  if not ok or not c then return nil end
  local cd = AG.ClassData[c.class]
  if cd and cd.needsCombat then pcall(AG.Char.Combat, c) end

  local d = { class = c.class, classText = Pretty(c.class or "?") }
  if c.style and c.role == "dmg" then d.classText = d.classText .. " (" .. c.style .. ")" end

  if check.state == "never" or check.state == "classlock" or check.state == "notgear" then
    d.unusable = { title = "You can't use this item", lines = check.lines }
    if check.state == "notgear" then d.unusable.title = "Not gear" end
    return d
  end
  if not cd then
    d.unusable = { title = "No stat values for " .. tostring(c.class) .. " yet", lines = {} }
    return d
  end
  local notice = STATE_NOTICE[check.state]
  if notice then
    local text = notice[1]
    if check.lines and check.lines[1] then text = text .. ": " .. check.lines[1] end
    d.notice = { text = text, color = notice[2] }
  end

  wornNames = WornNames()
  local targets = AG.Rules.Targets(it, ctx)
  if table.getn(targets) == 0 then return nil end
  local list = Scenarios(it, targets)

  -- the way in that gains the most
  local best, bestRes, bestGain = nil, nil, nil
  local options = {}
  for i = 1, table.getn(list) do
    local res = Evaluate(c, c.mix, list[i])
    if res then
      local gain = res.new - res.old
      if not bestGain or gain > bestGain then best, bestRes, bestGain = list[i], res, gain end
      local name = "empty"
      if list[i].gone[1] then name = list[i].gone[1].item.name end
      local pct = nil
      if res.old > 0.05 then pct = (res.new - res.old) / res.old * 100 end
      table.insert(options, { label = list[i].label, name = name, pct = pct, gain = gain, sc = list[i] })
    end
  end
  if not best then
    d.unusable = { title = "No stat values for this role yet", lines = {} }
    return d
  end

  Compare.lastItem = it
  Compare.lastBest = best
  local res = bestRes
  d.mix = c.mix
  d.roleText = AG.Weights.MixText(res.wNew)
  if AG.GearScore then
    local gOld = 0
    for i = 1, table.getn(best.gone) do gOld = gOld + AG.GearScore.Item(best.gone[i].item) end
    d.gs = { new = AG.GearScore.Item(it), old = gOld }
  end
  d.new = ItemCard(it, res.new)
  if table.getn(best.gone) > 0 then
    local first = best.gone[1].item
    d.equipped = ItemCard(first, res.old)
    if table.getn(best.gone) > 1 then d.equipped.name = first.name .. " + off hand" end
  else
    d.equipped = { name = "Empty slot", q = 1, score = 0 }
    d.empty = true
  end
  if table.getn(targets) > 1 or best.label ~= targets[1].label then d.target = best.label end

  -- stat by stat: amount difference and its points
  d.stats = {}
  local why = res.wNew.why or {}
  for k, pts in pairs(res.rows) do
    local amount = res.amounts[k] or 0
    if math.abs(pts) >= 0.05 or math.abs(amount) > 0 then
      local note = why[k] and why[k][1] or nil
      table.insert(d.stats, { label = AG.Items.Label(k), delta = amount, value = pts, note = note, fmt = "%+g" })
    end
  end

  -- talents that touched the stats shown
  d.talents = {}
  local seen = {}
  for i = 1, table.getn(d.stats) do
    local row = d.stats[i]
    if row.note then
      local s, e = string.find(row.note, ": ", 1, true)
      if s then
        local name = string.sub(row.note, 1, s - 1)
        if not seen[name] then
          seen[name] = true
          table.insert(d.talents, { name = name, text = string.sub(row.note, e + 1) })
        end
      end
    end
  end

  -- by role: the same swap when you play only that role
  d.roles = {}
  local names = { { "tank", "Tank" }, { "heal", "Healer" }, { "dmg", "Damage" } }
  for i = 1, 3 do
    local role = names[i][1]
    local mix = { tank = 0, heal = 0, dmg = 0 }
    mix[role] = 1
    local test = AG.Weights.Compute({ class = c.class, mix = mix, style = c.style, level = c.level, race = c.race })
    if test and not test.fallback then
      local r = Evaluate(c, mix, best)
      if r and r.old > 0.5 then
        table.insert(d.roles, { label = names[i][2], pct = (r.new - r.old) / r.old * 100 })
      end
    end
  end
  if table.getn(d.roles) < 2 then d.roles = {} end

  -- every slot it could go in (rings, trinkets, one-handers in a dual wield)
  d.options = {}
  if table.getn(options) > 1 then
    for i = 1, table.getn(options) do
      local o = options[i]
      table.insert(d.options, { label = o.label, name = o.name, pct = o.pct, gain = o.gain, best = (o.sc == best) })
    end
  end

  -- effects that are not numbers: what you get and what you lose
  d.effects = { gained = {}, lost = {} }
  for i = 1, table.getn(it.special or {}) do table.insert(d.effects.gained, it.special[i]) end
  for i = 1, table.getn(best.gone) do
    local g = best.gone[i].item
    for j = 1, table.getn(g.special or {}) do table.insert(d.effects.lost, g.special[j]) end
  end

  d.notes = CapNotes(res, c)
  -- tanks: how much damage armor takes away, and the 75% cap
  local tankish = c.mix and c.mix.tank and c.mix.tank > 0.5
  if tankish and c.armor and c.armor > 0 then
    local lv = c.target or c.level or 60
    local now = Reduction(c.armor, lv)
    local da = res.amounts.ARMOR or 0
    local text
    if da ~= 0 then
      text = string.format("Armor %d to %d: %.1f%% to %.1f%% damage reduction (cap 75%%)", c.armor, c.armor + da, now, Reduction(c.armor + da, lv))
    else
      text = string.format("Armor %d: %.1f%% damage reduction (cap 75%%)", c.armor, now)
    end
    table.insert(d.notes, text)
  end
  for i = 1, table.getn(best.notes) do table.insert(d.notes, best.notes[i]) end

  d.warnings = {}
  for i = 1, table.getn(it.special or {}) do table.insert(d.warnings, "Not counted: " .. it.special[i]) end
  for i = 1, table.getn(it.unparsed or {}) do table.insert(d.warnings, "Not understood: " .. it.unparsed[i]) end
  if it.set and it.set.name then table.insert(d.warnings, "Set bonuses are not counted yet") end
  return d
end

----------------------------------------------------------------------
-- Quick verdict for icons and /adeg best: is it better than what you wear, and by how much
----------------------------------------------------------------------

local qctx = nil
local qcache = {}

-- forget everything worked out so far (gear, talents or level changed)
function Compare.Flush()
  qctx = nil
  qcache = {}
  if AG.Weights.Flush then AG.Weights.Flush() end
end

local function QuickCtx()
  local now = GetTime()
  if qctx and now - qctx.t < 1 then return qctx end
  local ok, c = pcall(AG.Char.Basic)
  if not ok or not c then return nil end
  local cd = AG.ClassData[c.class]
  if cd and cd.needsCombat then pcall(AG.Char.Combat, c) end
  qctx = { t = now, c = c, ctx = AG.Rules.Context(), cd = cd }
  return qctx
end

-- returns nil (not gear / not for you), or { state, pct, gain, label, name }
-- state is the usability state (ok = you can wear it now); pct is the gain over what it replaces
local function QuickItem(it)
  if not it or not it.slot or it.bag or it.slot == "SHIRT" or it.slot == "TABARD" or it.slot == "AMMO" then return nil end
  local q = QuickCtx()
  if not q or not q.cd then return nil end
  local check = AG.Rules.Check(it, q.ctx)
  if check.state == "never" or check.state == "classlock" or check.state == "notgear" then return nil end
  wornNames = WornNames()
  local targets = AG.Rules.Targets(it, q.ctx)
  if table.getn(targets) == 0 then return nil end
  local list = Scenarios(it, targets)
  local best, bestGain, bestRes = nil, nil, nil
  for i = 1, table.getn(list) do
    local res = Evaluate(q.c, q.c.mix, list[i])
    if res then
      local gain = res.new - res.old
      if not bestGain or gain > bestGain then best, bestGain, bestRes = list[i], gain, res end
    end
  end
  if not best then return nil end
  local pct = nil
  if bestRes.old > 0.05 then pct = bestGain / bestRes.old * 100 end
  local name = "empty slot"
  if best.gone[1] then name = best.gone[1].item.name end
  return { state = check.state, gain = bestGain, pct = pct, label = best.label, name = name, empty = (table.getn(best.gone) == 0) }
end

-- same for an item link, remembered until something changes
function Compare.Quick(link)
  local str = AG.Items.ItemString(link)
  if not str then return nil end
  local hit = qcache[str]
  if hit ~= nil then
    if hit == false then return nil end
    return hit
  end
  local it = AG.Items.FromLink(str)
  local ok, r = pcall(QuickItem, it)
  if not ok then AG.lastError = tostring(r); r = nil end
  qcache[str] = r or false
  return r
end

-- is it worth an arrow: better by at least 2% (or any gain for an empty slot)
function Compare.IsUpgrade(r)
  if not r or r.gain <= 0.05 then return false end
  if r.empty or not r.pct then return true end
  return r.pct >= 2
end

----------------------------------------------------------------------
-- Showing it next to the tooltip
----------------------------------------------------------------------

local function Detail()
  local detail = AG.Get("detail")
  if IsAltKeyDown and IsAltKeyDown() then detail = 3 end
  return detail
end

local function Panel()
  if Compare.tip then return Compare.tip end
  local tip = AG.Panel.Get()
  tip.frame:SetScript("OnUpdate", function()
    Compare.elapsed = (Compare.elapsed or 0) + arg1
    if Compare.elapsed < 0.1 then return end
    Compare.elapsed = 0
    if not (Compare.owner and Compare.owner:IsShown()) then return end
    -- Alt opens the detailed view
    local alt = IsAltKeyDown and IsAltKeyDown() and true or false
    if alt ~= Compare.alt and Compare.data then
      Compare.alt = alt
      AG.Panel.Update(Compare.data, Detail()):Show()
      AG.Inspect.anchorKey = nil   -- the height changed: place it again
    end
    AG.Inspect.Anchor(tip, Compare.owner)
  end)
  Compare.tip = tip
  return tip
end

-- /adeg set: what was read about the sets of the last compared item (for finding mistakes)
local function SetInfo(label, item)
  local say = function(t) DEFAULT_CHAT_FRAME:AddMessage(t) end
  if not item then say("  " .. label .. ": none") return end
  local S = item.set
  if not S then say("  " .. label .. " " .. tostring(item.name) .. ": no set") return end
  say("  " .. label .. " " .. tostring(item.name) .. ": set " .. tostring(S.name) .. " " .. tostring(S.have) .. "/" .. tostring(S.total))
  for i = 1, table.getn(S.bonuses or {}) do
    local b = S.bonuses[i]
    local st = ""
    if b.stats then for k, v in pairs(b.stats) do st = st .. " " .. k .. "=" .. v end end
    say("    bonus n=" .. tostring(b.n) .. " active=" .. tostring(b.active) .. " seenOnWith=" .. tostring(b.minHave) .. " stats:" .. st .. "  " .. tostring(b.text))
  end
end

function Compare.SetDebug()
  AG.Msg("sets of the last compared item")
  local counts = AG.Weights.SetCounts and AG.Weights.SetCounts()
  if counts then
    for name, n in pairs(counts) do DEFAULT_CHAT_FRAME:AddMessage("  worn pieces counted from your slots: " .. name .. " " .. n) end
  end
  SetInfo("hovered", Compare.lastItem)
  local best = Compare.lastBest
  if best then
    for i = 1, table.getn(best.gone) do SetInfo("replaced", best.gone[i].item) end
    for i = 1, table.getn(best.notes) do DEFAULT_CHAT_FRAME:AddMessage("  note: " .. best.notes[i]) end
  end
end

function Compare.Hide()
  Compare.owner = nil
  Compare.data = nil
  if Compare.tip then Compare.tip:Hide() end
end

function Compare.Show(owner, link, own)
  if not AG.Get("enabled") or own then Compare.Hide() return end
  if AG.Get("shiftOnly") and not (IsShiftKeyDown and IsShiftKeyDown()) then Compare.Hide() return end
  local it = AG.Items.FromLink(link)
  if not it then Compare.Hide() return end
  local ok, d = pcall(Compare.Build, it)
  if not ok then
    Compare.Hide()
    AG.lastError = d
    return
  end
  if not d then Compare.Hide() return end
  local tip = Panel()
  Compare.owner = owner
  Compare.data = d
  Compare.alt = IsAltKeyDown and IsAltKeyDown() and true or false
  AG.Panel.Update(d, Detail())
  AG.Inspect.anchorKey = nil
  AG.Inspect.Anchor(tip, owner)
  tip:Show()
end
