-- EGM item tooltips: lists the open guild orders of an item under the item info (option "tooltip", default on).
-- 1.12 has no hooksecurefunc: every tooltip method is wrapped (original first, then our lines, then Show to resize).
EGM = EGM or {}
EGM.Tooltip = EGM.Tooltip or {}
local T = EGM.Tooltip

local MAX_ROWS = 3
local byItem, byName, dirty = {}, {}, true -- cache of open orders per item id / item name, rebuilt on STATE and ROSTER

local function enabled()
  local c = EGM.DB and EGM.DB.char
  return not (c and c.tooltip == false)
end

local function better(a, b)
  if a.price ~= b.price then return a.price > b.price end
  return a.created < b.created
end

local function rebuild()
  byItem, byName, dirty = {}, {}, false
  local list = EGM.Orders and EGM.Orders.list and EGM.Orders.list() or {}
  for i = 1, table.getn(list) do
    local o = list[i]
    -- same rule as Browse: open orders of current guild members (Orders.list already hides the others)
    if o.state == "open" and (o.open or 0) > 0 and not o.expired then
      local row = { price = o.price, qty = o.open, buyer = o.buyer, created = o.created or 0, exp = o.exp or 0 }
      local e = byItem[o.item]
      if not e then e = { rows = {} }; byItem[o.item] = e end
      table.insert(e.rows, row)
      if o.name then byName[o.name] = o.item end
    end
  end
  for _, e in pairs(byItem) do table.sort(e.rows, better) end
end
function T.invalidate() dirty = true end
EGM.On("STATE", T.invalidate)
EGM.On("ROSTER", T.invalidate)

-- { {text, r, g, b}, ... } for an item (id, or name when only the name is known); empty table = nothing to show
function T.lines(id, name)
  local out = {}
  if not enabled() then return out end
  if dirty then rebuild() end
  id = tonumber(id) or (name and byName[name])
  local e = id and byItem[id]
  if not e then return out end
  local now = EGM.Util.now()
  local rows, total = {}, 0
  for i = 1, table.getn(e.rows) do
    local r = e.rows[i]
    if r.exp > now then table.insert(rows, r); total = total + r.qty end
  end
  if table.getn(rows) == 0 then return out end
  local me = EGM.Util.player()
  local function who(r) return r.buyer .. (r.buyer == me and " (you)" or "") end
  table.insert(out, { string.format("Guild orders: %d open - best %s (%s)", total, EGM.Util.moneyPlain(rows[1].price), who(rows[1])), 0.85, 0.31, 0.17 })
  if table.getn(rows) > 1 then
    for i = 1, math.min(MAX_ROWS, table.getn(rows)) do
      local r = rows[i]
      table.insert(out, { string.format("  %dx %s - %s", r.qty, EGM.Util.moneyPlain(r.price), who(r)), 0.85, 0.85, 0.85 })
    end
  end
  return out
end

-- adds the lines to a tooltip that just showed an item
function T.decorate(tt, link, name)
  if not tt then return end
  local id, linkName = EGM.Util.itemIdFromLink(link)
  local lines = T.lines(id, linkName or name)
  if table.getn(lines) == 0 then return end
  for i = 1, table.getn(lines) do
    local l = lines[i]
    tt:AddLine(l[1], l[2], l[3], l[4])
  end
  tt:Show() -- resizes the tooltip to the new lines
end

-- how each tooltip method tells us the item: link(a1, a2) or name(a1, a2)
local function inboxName(i) local n = GetInboxItem and GetInboxItem(i); return n end
local function sendMailName() local n = GetSendMailItem and GetSendMailItem(); return n end
local SOURCES = {
  SetBagItem = { link = function(b, s) return GetContainerItemLink and GetContainerItemLink(b, s) end },
  SetInventoryItem = { link = function(u, s) return GetInventoryItemLink and GetInventoryItemLink(u, s) end },
  SetHyperlink = { link = function(l) return l end },
  SetLootItem = { link = function(s) return GetLootSlotLink and GetLootSlotLink(s) end },
  SetMerchantItem = { link = function(i) return GetMerchantItemLink and GetMerchantItemLink(i) end },
  SetAuctionItem = { link = function(t, i) return GetAuctionItemLink and GetAuctionItemLink(t, i) end },
  SetTradePlayerItem = { link = function(i) return GetTradePlayerItemLink and GetTradePlayerItemLink(i) end },
  SetTradeTargetItem = { link = function(i) return GetTradeTargetItemLink and GetTradeTargetItemLink(i) end },
  SetCraftItem = { link = function(i, r) return GetCraftReagentItemLink and GetCraftReagentItemLink(i, r) end },
  SetTradeSkillItem = { link = function(i, r)
    if r then return GetTradeSkillReagentItemLink and GetTradeSkillReagentItemLink(i, r) end
    return GetTradeSkillItemLink and GetTradeSkillItemLink(i)
  end },
  SetQuestItem = { link = function(t, i) return GetQuestItemLink and GetQuestItemLink(t, i) end },
  SetQuestLogItem = { link = function(t, i) return GetQuestLogItemLink and GetQuestLogItemLink(t, i) end },
  SetInboxItem = { name = inboxName },
  SetSendMailItem = { name = sendMailName },
}

-- wraps tt[method]; the original runs first with all its arguments and returns unchanged
function T.wrap(tt, method, src)
  local orig = tt and tt[method]
  if type(orig) ~= "function" then return false end
  tt[method] = function(self, a1, a2, a3, a4)
    local r1, r2, r3 = orig(self, a1, a2, a3, a4)
    if enabled() then
      local link, name
      if src.link then link = src.link(a1, a2) end
      if src.name then name = src.name(a1, a2) end
      if link or name then T.decorate(self, link, name) end
    end
    return r1, r2, r3
  end
  return true
end

function T.install()
  for method, src in pairs(SOURCES) do
    T.wrap(GameTooltip, method, src)
  end
  if ItemRefTooltip then T.wrap(ItemRefTooltip, "SetHyperlink", SOURCES.SetHyperlink) end
end
T.install()
