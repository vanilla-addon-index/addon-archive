-- Ade Alts: scan
local AA = AdeAlts

----------------------------------------------------------------------
-- scanning: trade skill window
----------------------------------------------------------------------
local tip = CreateFrame("GameTooltip", "AdeAltsTip", nil, "GameTooltipTemplate")

local function TipCooldown(index)
  if GetTradeSkillCooldown then
    local c = GetTradeSkillCooldown(index)
    if c and c > 0 then return c end
  end
  tip:SetOwner(UIParent, "ANCHOR_NONE")
  tip:ClearLines()
  tip:SetTradeSkillItem(index)
  for i = 1, tip:NumLines() do
    local fs = getglobal("AdeAltsTipTextLeft" .. i)
    local t = fs and fs:GetText()
    if t then
      local l = string.lower(t)
      if string.find(l, "cooldown") and string.find(l, "remaining") then
        local d = AA.ParseDuration(t)
        if d then return d end
      end
    end
  end
  return nil
end

-- remember the known recipes of a profession (read from its trade skill / craft window)
local function StoreRecipes(prof, recs, rank, maxrank)
  if not AA.me or not prof or prof == "" or table.getn(recs) == 0 then return end
  AA.me.prof = AA.me.prof or {}
  if AA.me.profGone then AA.me.profGone[prof] = nil end
  local p = AA.me.prof[prof]
  if not p then
    p = {}
    AA.me.prof[prof] = p
  end
  if rank and rank > 0 and (p.r ~= rank or p.m ~= maxrank) then
    p.r = rank
    p.m = maxrank
    p.ts = time()
    AA.fileDirty = true
  end
  table.sort(recs)
  local sig = table.concat(recs, "~")
  if sig ~= p.sig then
    p.rec = recs
    p.sig = sig
    p.rts = time()
    AA.fileDirty = true
  end
end

function AA.ScanTradeSkills()
  if AA.scanning or not AA.me then return end
  if GetTime() - AA.lastScan < 1 then return end
  local n = GetNumTradeSkills()
  if not n or n == 0 then return end
  AA.scanning = true

  -- expand collapsed headers temporarily so every recipe is visible
  local expanded = {}
  for i = n, 1, -1 do
    local name, ttype, _, isExp = GetTradeSkillInfo(i)
    if ttype == "header" and not isExp then
      expanded[name] = true
      ExpandTradeSkillSubClass(i)
    end
  end

  n = GetNumTradeSkills()
  local nowt = time()
  local recs = {}
  for i = 1, n do
    local name, ttype = GetTradeSkillInfo(i)
    if name and ttype ~= "header" then table.insert(recs, name) end
    if name and ttype ~= "header" and AA.IsTracked(name) then
      local rem = TipCooldown(i)
      if rem then
        AA.db.tipWorks = true
        AA.SetCD(name, nowt + rem)
      else
        local cur = AA.me.cds[name]
        if AA.prov[name] and nowt - AA.prov[name] < 10 then
          -- just crafted, keep provisional value
        elseif cur and cur > nowt and not AA.db.tipWorks then
          -- tooltips don't expose cooldowns on this client: keep the estimate
        else
          AA.SetCD(name, 0)
        end
      end
    end
  end

  local pn, pr, pm = GetTradeSkillLine()
  StoreRecipes(pn, recs, pr, pm)

  -- restore collapsed state
  for i = GetNumTradeSkills(), 1, -1 do
    local name, ttype, _, isExp = GetTradeSkillInfo(i)
    if ttype == "header" and expanded[name] and isExp then
      CollapseTradeSkillSubClass(i)
    end
  end

  AA.scanning = false
  AA.lastScan = GetTime()
  if AA.Refresh then AA.Refresh() end
end

-- craft window (Enchanting uses it instead of the trade skill window)
local scanningCraft, lastCraftScan = false, 0
function AA.ScanCrafts()
  if scanningCraft or not AA.me or not GetNumCrafts then return end
  if GetTime() - lastCraftScan < 1 then return end
  local n = GetNumCrafts()
  if not n or n == 0 then return end
  local pn, pr, pm
  if GetCraftDisplaySkillLine then pn, pr, pm = GetCraftDisplaySkillLine() end
  if not pn or pn == "" then return end   -- e.g. hunter pet training
  scanningCraft = true
  if ExpandCraftSkillLine then
    for i = n, 1, -1 do
      local name, sub, ctype, _, isExp = GetCraftInfo(i)
      if ctype == "header" and not isExp then ExpandCraftSkillLine(i) end
    end
  end
  n = GetNumCrafts()
  local recs = {}
  for i = 1, n do
    local name, sub, ctype = GetCraftInfo(i)
    if name and ctype ~= "header" then table.insert(recs, name) end
  end
  StoreRecipes(pn, recs, pr, pm)
  scanningCraft = false
  lastCraftScan = GetTime()
  if AA.Refresh then AA.Refresh() end
end

-- crafting hook: provisional cooldown the moment a tracked recipe is started
local origDoTradeSkill = DoTradeSkill
DoTradeSkill = function(index, count)
  if AA.me and index then
    local name, ttype, avail = GetTradeSkillInfo(index)
    if name and avail and avail > 0 and AA.IsTracked(name) then
      local d = AA.DEFAULTS[name]
      if d then
        AA.SetCD(name, time() + d)
        AA.prov[name] = time()
      end
      AA.After(5, function() if TradeSkillFrame and TradeSkillFrame:IsVisible() then AA.ScanTradeSkills() end end)
      AA.After(12, function() if TradeSkillFrame and TradeSkillFrame:IsVisible() then AA.ScanTradeSkills() end end)
    end
  end
  return origDoTradeSkill(index, count)
end

----------------------------------------------------------------------
-- scanning: bags (Salt Shaker etc.)
----------------------------------------------------------------------
local BYNAME = {}
for id, it in pairs(AA.ITEMS) do BYNAME[it.key] = it end

-- match a tracked item by id, or by name as a fallback (in case the item id differs on this server)
function AA.ItemFromLink(link)
  if not link then return nil end
  local _, _, id = string.find(link, "item:(%d+)")
  local it = id and AA.ITEMS[tonumber(id)]
  if not it then
    local _, _, nm = string.find(link, "%[(.-)%]")
    if nm then it = BYNAME[nm] end
  end
  return it
end

AA.bankOpen = false

local function FindItemDef(link)
  local _, _, id = string.find(link, "item:(%d+)")
  local it = id and AA.ITEMS[tonumber(id)]
  if it then return it end
  local _, _, nm = string.find(link, "%[(.-)%]")
  if nm and AA.ITEMNAME[string.lower(nm)] then return AA.ITEMNAME[string.lower(nm)] end
  return nil
end

function AA.ScanBags(verbose)
  if not AA.me then return end
  local bags = { 0, 1, 2, 3, 4 }
  if AA.bankOpen then
    table.insert(bags, -1)
    for b = 5, 10 do table.insert(bags, b) end
  end
  local found = 0
  for _, bag in ipairs(bags) do
    local slots = GetContainerNumSlots(bag) or 0
    for slot = 1, slots do
      local link = GetContainerItemLink(bag, slot)
      if link then
        local it = FindItemDef(link)
        if it then
          found = found + 1
          local start, dur = GetContainerItemCooldown(bag, slot)
          local exp = 0
          if start and start > 0 and dur and dur > 30 then
            local rem = start + dur - GetTime()
            if rem > 0 then
              exp = time() + rem
              if exp > time() + it.cd + 60 then
                -- client reported a nonsense start time: keep our stored value if sane, else assume a fresh use
                local cur = AA.me.cds[it.key]
                if cur and cur > time() and cur <= time() + it.cd + 60 then exp = cur else exp = time() + it.cd end
              end
            end
          end
          if verbose then
            AA.Print(it.key .. " in bag " .. bag .. " slot " .. slot .. ": start=" .. tostring(start) .. " dur=" .. tostring(dur) .. " -> " .. (exp > 0 and AA.FormatTime(exp - time()) or "Ready"))
          end
          AA.SetCD(it.key, exp)
        end
      end
    end
  end
  if verbose and found == 0 then
    AA.Print("no tracked items found in bags" .. (AA.bankOpen and " / bank" or "") .. ". (Open the bank to scan it too.)")
  end
  return found
end

----------------------------------------------------------------------
-- scanning: character data, inventory and bank (for the alts manager)
----------------------------------------------------------------------
local QHEX = { ["9d9d9d"] = 0, ["ffffff"] = 1, ["1eff00"] = 2, ["0070dd"] = 3, ["a335ee"] = 4, ["ff8000"] = 5 }

local function LearnItem(id, link, tex)
  AA.db.items = AA.db.items or {}
  local it = AA.db.items[id]
  if it and it.n and it.t and it.t ~= "" then return end
  local _, _, nm = string.find(link, "%[(.-)%]")
  local _, _, col = string.find(link, "|c%x%x(%x%x%x%x%x%x)|H")
  local t = tex
  if t then t = (string.gsub(t, "^Interface\\Icons\\", "")) end
  AA.db.items[id] = { n = nm or ("item:" .. id), t = t or "", q = (col and QHEX[col]) or 1 }
end

-- returns aggregated list {{id,count},...} and a signature string, or nil if the containers are not available
local function ScanContainers(bags)
  local order, agg = {}, {}
  local slotsTotal = 0
  local binfo = {}
  local claimed = {}
  for _, bag in ipairs(bags) do
    local slots = GetContainerNumSlots(bag) or 0
    slotsTotal = slotsTotal + slots
    local used = 0
    for slot = 1, slots do
      local link = GetContainerItemLink(bag, slot)
      if link then
        used = used + 1
        local _, _, sid = string.find(link, "item:(%d+)")
        local id = tonumber(sid)
        if id then
          local tex, count = GetContainerItemInfo(bag, slot)
          count = count or 1
          if count < 1 then count = 1 end
          if not agg[id] then
            agg[id] = 0
            table.insert(order, id)
          end
          agg[id] = agg[id] + count
          LearnItem(id, link, tex)
        end
      end
    end
    if slots > 0 then
      -- the bag item itself (backpack / main bank have none)
      local bid = 0
      local inv
      if bag >= 1 and bag <= 4 then
        local ok, v = pcall(ContainerIDToInventoryID, bag)
        if ok then inv = v end
      elseif bag >= 5 and BankButtonIDToInvSlotID then
        local ok, v = pcall(BankButtonIDToInvSlotID, bag - 4, 1)
        if ok then inv = v end
      end
      -- the client's own bag name is authoritative; the inventory slot guess may point at another bag
      local want = GetBagName and GetBagName(bag)
      local function linkName(l)
        local _, _, nm = string.find(l or "", "%[(.-)%]")
        return nm
      end
      local pick, pickLink
      if inv then
        local l = GetInventoryItemLink("player", inv)
        if l and not claimed[inv] and (not want or want == "" or linkName(l) == want) then pick, pickLink = inv, l end
      end
      if not pick and want and want ~= "" then
        local lo, hi = 20, 23
        if bag >= 5 then lo, hi = 40, 90 end
        for s2 = lo, hi do
          if not claimed[s2] then
            local l = GetInventoryItemLink("player", s2)
            if l and linkName(l) == want then pick, pickLink = s2, l; break end
          end
        end
      end
      if pick then
        claimed[pick] = true
        local _, _, bsid = string.find(pickLink, "item:(%d+)")
        if bsid then
          bid = tonumber(bsid)
          LearnItem(bid, pickLink, GetInventoryItemTexture("player", pick))
        end
      end
      table.insert(binfo, slots .. ":" .. used .. ":" .. bid)
    end
  end
  if slotsTotal == 0 then return nil end
  local list, parts = {}, {}
  for _, id in ipairs(order) do
    table.insert(list, { id, agg[id] })
    table.insert(parts, id .. ":" .. agg[id])
  end
  return list, table.concat(parts, "~"), table.concat(binfo, "~")
end

-- equipped gear: slot -> "id:enchant:suffix:unique"
local function ScanEquip()
  if not AA.me then return false end
  local eq, parts, any = {}, {}, false
  for slot = 0, 19 do
    local link = GetInventoryItemLink("player", slot)
    if link then
      local _, _, ref = string.find(link, "item:(%-?%d+:%-?%d+:%-?%d+:%-?%d+)")
      local _, _, sid = string.find(link, "item:(%d+)")
      if ref and sid then
        eq[slot] = ref
        table.insert(parts, slot .. "=" .. ref)
        LearnItem(tonumber(sid), link, GetInventoryItemTexture("player", slot))
        any = true
      end
    end
  end
  if not any then return false end    -- gear not loaded yet: keep what we have
  local sig = table.concat(parts, "~")
  if sig ~= AA.me.eqSig then
    AA.me.equip = eq
    AA.me.eqSig = sig
    AA.me.eqTs = time()
    return true
  end
  return false
end

-- profession skill levels from the skill window
local PROFN = {
  ["Alchemy"] = 1, ["Blacksmithing"] = 1, ["Enchanting"] = 1, ["Engineering"] = 1, ["Herbalism"] = 1,
  ["Leatherworking"] = 1, ["Mining"] = 1, ["Skinning"] = 1, ["Tailoring"] = 1,
  ["Cooking"] = 1, ["First Aid"] = 1, ["Fishing"] = 1, ["Survival"] = 1, ["Jewelcrafting"] = 1,
}
local function ScanSkills()
  if not AA.me or not GetNumSkillLines then return false end
  local n = GetNumSkillLines()
  if not n or n == 0 then return false end
  -- collapsed headers hide their skills: expand them (this only happens once)
  for i = n, 1, -1 do
    local name, header, isExp = GetSkillLineInfo(i)
    if header and not isExp then ExpandSkillHeader(i) end
  end
  n = GetNumSkillLines()
  AA.me.prof = AA.me.prof or {}
  local seen, changed = {}, false
  local section
  for i = 1, n do
    local name, header, _, rank, _, _, maxRank = GetSkillLineInfo(i)
    if header then section = name end
    if not header and name and PROFN[name] and not AA.BadProf(name, maxRank)
       and not (name == "Survival" and section == "Class Skills") then
      seen[name] = true
      if AA.me.profGone then AA.me.profGone[name] = nil end
      local p = AA.me.prof[name]
      if not p then
        p = {}
        AA.me.prof[name] = p
      end
      if p.r ~= rank or p.m ~= maxRank then
        p.r = rank
        p.m = maxRank
        p.ts = time()
        changed = true
      end
    end
  end
  -- a profession that is gone from a complete skill list was unlearned: remember when, so that
  -- the shared file / chat cannot bring the old entry back
  if n >= 5 and GetTime() - AA.enterTime >= 15 then
    for name, p in pairs(AA.me.prof) do
      if not seen[name] and PROFN[name] then
        AA.me.prof[name] = nil
        AA.me.profGone = AA.me.profGone or {}
        AA.me.profGone[name] = time()
        changed = true
      end
    end
  end
  return changed
end

AA.enterTime = 0

function AA.ScanSelf()
  if not AA.me or not AA.db then return end
  local changed = false
  local lvl, gold = UnitLevel("player"), GetMoney()
  local early = GetTime() - AA.enterTime < 12     -- right after login the client may still report 0
  local metaChanged = false
  if lvl and lvl > 0 and AA.me.level ~= lvl then
    AA.me.level = lvl
    metaChanged = true
  end
  if gold and not (gold == 0 and early) and AA.me.gold ~= gold then
    AA.me.gold = gold
    metaChanged = true
  end
  if metaChanged then
    AA.me.dataTs = time()
    changed = true
  end
  if ScanEquip() then changed = true end
  if ScanSkills() then changed = true end
  local list, sig, binfo = ScanContainers({ 0, 1, 2, 3, 4 })
  if list and binfo ~= AA.me.invBags then
    AA.me.invBags = binfo
    AA.me.invBagsTs = time()
    changed = true
  end
  if list and sig ~= AA.me.invSig then
    AA.me.inv = list
    AA.me.invSig = sig
    AA.me.invTs = time()
    changed = true
  end
  if AA.bankOpen then
    local bags = { -1 }
    for b = 5, 10 do table.insert(bags, b) end
    local bl, bs, bbinfo = ScanContainers(bags)
    if bl and bbinfo ~= AA.me.bankBags then
      AA.me.bankBags = bbinfo
      AA.me.bankBagsTs = time()
      changed = true
    end
    if bl and bs ~= AA.me.bankSig then
      AA.me.bank = bl
      AA.me.bankSig = bs
      AA.me.bankTs = time()
      changed = true
    end
  end
  if changed then
    AA.fileDirty = true
    if AA.RefreshManager then AA.RefreshManager() end
  end
end

----------------------------------------------------------------------
-- data -> display
----------------------------------------------------------------------
function AA.SortedChars()
  local list = {}
  for k, c in pairs(AA.db.chars) do table.insert(list, k) end
  table.sort(list, function(a, b)
    if a == AA.myKey then return true end
    if b == AA.myKey then return false end
    return a < b
  end)
  return list
end

function AA.Entries(onlyCd)
  local out = {}
  local nowt = time()
  for _, k in ipairs(AA.SortedChars()) do
    local c = AA.db.chars[k]
    local keys = {}
    for key, exp in pairs(c.cds or {}) do table.insert(keys, key) end
    table.sort(keys)
    if table.getn(keys) > 0 or not onlyCd then
      table.insert(out, { l = "|cff" .. AA.ClassHex(c.class) .. c.name .. "|r |cff808080" .. c.realm .. "|r", r = "" })
      if table.getn(keys) == 0 then
        table.insert(out, { l = "   |cff808080(no cooldowns recorded)|r", r = "" })
      end
      for _, key in ipairs(keys) do
        local exp = c.cds[key]
        local rem = exp - nowt
        local r
        if exp <= 0 or rem <= 0 then
          r = "|cff40ff40Ready|r"
        elseif rem >= AA.DAY then
          r = "|cffff6060" .. AA.FormatTime(rem) .. "|r"
        else
          r = "|cffffd100" .. AA.FormatTime(rem) .. "|r"
        end
        table.insert(out, { l = "   " .. key, r = r })
      end
    end
  end
  return out
end

