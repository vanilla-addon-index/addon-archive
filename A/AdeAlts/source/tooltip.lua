-- Ade Alts: tooltip (recipe items show which of your alts can learn them)
local AA = AdeAlts

local PREFIX = { Pattern = 1, Recipe = 1, Plans = 1, Formula = 1, Schematic = 1, Manual = 1, Design = 1, Book = 1, Technique = 1 }

-- finds the craft(s) taught by the item in the tooltip: by item id (from the item link) first,
-- then by the "Teaches you how to craft X" line, finally by the item name
local function FindHits(tt)
  local idx = AA.RIndex()
  if tt.adeLink then
    local _, _, id = string.find(tt.adeLink, "item:(%d+)")
    if id and idx.byItem[tonumber(id)] then return idx.byItem[tonumber(id)] end
  end
  local name = tt:GetName()
  local title
  for i = 1, tt:NumLines() do
    local fs = getglobal(name .. "TextLeft" .. i)
    local txt = fs and fs:GetText()
    if txt then
      if i == 1 then title = txt end
      local _, _, id = string.find(txt, "ItemID: (%d+)")
      if id and idx.byItem[tonumber(id)] then return idx.byItem[tonumber(id)] end
      local _, _, craft = string.find(txt, "Teaches you how to craft (.-)%.?$")
      if craft and idx.byAny[string.lower(craft)] then return idx.byAny[string.lower(craft)] end
    end
  end
  if title then
    local _, _, pre, nm = string.find(title, "^(%a+): (.+)$")
    if pre and PREFIX[pre] and idx.byAny[string.lower(nm)] then return idx.byAny[string.lower(nm)] end
  end
  return nil
end

-- item id of the tooltip (from the item link, or an "ItemID: n" line added by another addon)
local function ItemId(tt)
  if tt.adeLink then
    local _, _, id = string.find(tt.adeLink, "item:(%d+)")
    if id then return tonumber(id) end
  end
  local name = tt:GetName()
  for i = 1, tt:NumLines() do
    local fs = getglobal(name .. "TextLeft" .. i)
    local txt = fs and fs:GetText()
    local _, _, id = string.find(txt or "", "ItemID: (%d+)")
    if id then return tonumber(id) end
  end
  return nil
end

-- how many of the item the other alts carry: total, {{name, class, bags, bank}, ...}
local function CountOnAlts(id)
  local total, rows = 0, {}
  for _, k in ipairs(AA.SortedAlts()) do
    local c = AA.db.chars[k]
    if c and k ~= AA.myKey then
      local nb, nk = 0, 0
      for _, e in ipairs(c.inv or {}) do if e[1] == id then nb = nb + e[2] end end
      for _, e in ipairs(c.bank or {}) do if e[1] == id then nk = nk + e[2] end end
      if nb + nk > 0 then
        total = total + nb + nk
        table.insert(rows, { c = c, bags = nb, bank = nk })
      end
    end
  end
  return total, rows
end

-- item id of the tooltip (item link, or an "ItemID: n" line some addons add)
local function TipItemId(tt)
  if tt.adeLink then
    local _, _, id = string.find(tt.adeLink, "item:(%d+)")
    if id then return tonumber(id) end
  end
  local name = tt:GetName()
  for i = 1, tt:NumLines() do
    local fs = getglobal(name .. "TextLeft" .. i)
    local txt = fs and fs:GetText()
    if txt then
      local _, _, id = string.find(txt, "ItemID: (%d+)")
      if id then return tonumber(id) end
    end
  end
  return nil
end

local function HasHeader(tt)
  local name = tt:GetName()
  for i = 1, tt:NumLines() do
    local fs = getglobal(name .. "TextLeft" .. i)
    if fs and fs:GetText() == "Ade Alts" then return true end
  end
  return false
end

local function CountIn(list, id)
  if not list then return 0 end
  for _, e in ipairs(list) do
    if e[1] == id then return e[2] or 0 end
  end
  return 0
end

function AA.EnhanceTooltip(tt)
  if not AA.db or not AA.RIndex or tt.adeDone then return end
  if HasHeader(tt) then tt.adeDone = true; return end
  local added = false
  local function header()
    if not added then
      tt:AddLine(" ")
      tt:AddLine("Ade Alts", 0.2, 1, 0.8)
      added = true
    end
  end

  -- 1) recipe items: which alts know / can learn the recipe
  local hits = FindHits(tt)
  if hits then
    local done = {}
    for _, h in ipairs(hits) do
      local key = string.lower(h.c[2])
      if not done[h.prof .. "|" .. key] then
        done[h.prof .. "|" .. key] = true
        for _, k in ipairs(AA.SortedAlts()) do
          local ch = AA.db.chars[k]
          local p = ch and ch.prof and ch.prof[h.prof]
          if p then
            header()
            local col = "|cff" .. AA.ClassHex(ch.class)
            local label
            if not p.rec then
              label = "|cff808080" .. h.prof .. " recipes not scanned|r"
            else
              local has = false
              for _, n in ipairs(p.rec) do
                if string.lower(n) == key then has = true; break end
              end
              if has then
                label = "|cff808080already known|r"
              elseif h.c[3] > (p.r or 0) then
                label = "|cffff6060needs " .. h.prof .. " " .. h.c[3] .. " (has " .. (p.r or 0) .. ")|r"
              else
                label = "|cff40ff40can learn now|r"
              end
            end
            tt:AddDoubleLine(col .. ch.name .. "|r", label)
          end
        end
      end
    end
  end

  -- 2) how many of the item the other alts carry (bags + bank)
  local id = TipItemId(tt)
  if id then
    local rows, total = {}, 0
    for _, k in ipairs(AA.SortedAlts()) do
      if k ~= AA.myKey then
        local ch = AA.db.chars[k]
        local nb, nk = CountIn(ch.inv, id), CountIn(ch.bank, id)
        if nb + nk > 0 then
          table.insert(rows, { ch = ch, b = nb, k = nk })
          total = total + nb + nk
        end
      end
    end
    if table.getn(rows) > 0 then
      table.sort(rows, function(x, y) return (x.b + x.k) > (y.b + y.k) end)
      header()
      tt:AddDoubleLine("On alts:", "|cffffffff" .. total .. "|r")
      for i, r in ipairs(rows) do
        if i > 10 then
          tt:AddLine("  ... and " .. (table.getn(rows) - 10) .. " more", 0.6, 0.6, 0.6)
          break
        end
        local parts = {}
        if r.b > 0 then table.insert(parts, "bags " .. r.b) end
        if r.k > 0 then table.insert(parts, "bank " .. r.k) end
        tt:AddDoubleLine("  |cff" .. AA.ClassHex(r.ch.class) .. r.ch.name .. "|r", "|cffc0c0c0" .. table.concat(parts, ", ") .. "|r")
      end
    end
  end

  tt.adeDone = true
  if added then tt:Show() end
end

-- tooltip functions that show an item: remember the item link, then add our lines
local GETTERS = {
  SetBagItem = function(a, b) return GetContainerItemLink(a, b) end,
  SetInventoryItem = function(a, b) return GetInventoryItemLink(a, b) end,
  SetHyperlink = function(a) return a end,
  SetLootItem = function(a) return GetLootSlotLink(a) end,
  SetMerchantItem = function(a) return GetMerchantItemLink(a) end,
  SetAuctionItem = function(a, b) return GetAuctionItemLink(a, b) end,
  SetQuestItem = function(a, b) return GetQuestItemLink(a, b) end,
  SetQuestLogItem = function(a, b) return GetQuestLogItemLink(a, b) end,
  SetTradePlayerItem = function(a) return GetTradePlayerItemLink(a) end,
  SetTradeTargetItem = function(a) return GetTradeTargetItemLink(a) end,
  SetInboxItem = function(a) return GetInboxItemLink and GetInboxItemLink(a, 1) end,
  SetTradeSkillItem = function(a, b) return GetTradeSkillItemLink and GetTradeSkillItemLink(a) end,
}

local function Hook(tt)
  if not tt then return end
  for fname, getter in pairs(GETTERS) do
    local orig = tt[fname]
    if orig then
      tt[fname] = function(self, a, b, c, d)
        local r1, r2, r3 = orig(self, a, b, c, d)
        self.adeDone = nil
        local ok, link = pcall(getter, a, b)
        self.adeLink = ok and link or nil
        AA.EnhanceTooltip(self)
        return r1, r2, r3
      end
    end
  end
  -- forget the item when the tooltip closes
  local oldHide = tt:GetScript("OnHide")
  tt:SetScript("OnHide", function()
    this.adeDone = nil
    this.adeLink = nil
    if oldHide then oldHide() end
  end)
end

Hook(GameTooltip)
Hook(ItemRefTooltip)
