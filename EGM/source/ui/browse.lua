-- ui/browse.lua - Browse Tab (Tab 1) for ERROR Guild Market
-- Lua 5.0 / WoW 1.12.1
-- Laid out directly in 832x447 Blizzard AuctionFrame "Browse" coordinates.

EGM = EGM or {}
EGM.UI = EGM.UI or {}
EGM.UI.Browse = EGM.UI.Browse or {}

local B = {
  ROW_HEIGHT = 17,
  NUM_ROWS = 17,

  browseFrame = nil,
  scrollFrame = nil,

  filterItemBox = nil,
  filterBuyerBox = nil,
  checkOnline = nil,
  checkDeliverable = nil,
  checkHideOwn = nil,
  radioMatching = nil,
  radioAll = nil,
  radioIncoming = nil,

  headerButtons = {},
  rows = {},
  bottom = {},

  filterState = {
    item = "",
    buyer = "",
    onlineOnly = false,
    deliverableOnly = false,
    hideOwn = false,
    view = "matching", -- "matching" | "all" | "incoming"
  },

  sortKey = "exp",
  sortAsc = true,
  selectedOid = nil,
  selectedIncomingIdx = nil,
  deliverQty = 0,
  visibleOrders = {},
  visibleIncoming = {},
}

local ORDER_COLUMNS = {
  { key = "name",        label = "Item",       x = 186, w = 162 },
  { key = "buyer",       label = "Buyer",      x = 348, w = 78  },
  { key = "online",      label = "Status",     x = 426, w = 54  },
  { key = "price",       label = "Unit Price", x = 480, w = 70  },
  { key = "open",        label = "Open",       x = 550, w = 38  },
  { key = "bags",        label = "Bags",       x = 588, w = 42  },
  { key = "deliverable", label = "Deliv.",     x = 630, w = 50  },
  { key = "payout",      label = "Payout",     x = 680, w = 68  },
  { key = "exp",         label = "Expires",    x = 748, w = 48  },
}

local INCOMING_COLUMNS = {
  { key = nil, label = "From",   x = 186, w = 100 },
  { key = nil, label = "Item",   x = 286, w = 190 },
  { key = nil, label = "Qty",    x = 476, w = 50  },
  { key = nil, label = "C.O.D.", x = 526, w = 96  },
  { key = nil, label = "Order",  x = 622, w = 84  },
  { key = nil, label = "Status", x = 706, w = 90  },
}

-- Safe Lua 5.0 / stub.lua helpers
local function numOr(v, d)
  if type(v) == "number" then
    return v
  end
  return d
end

local function strOr(v, d)
  if type(v) == "string" then
    return v
  end
  return d
end

local function nowSec()
  if EGM.Util and type(EGM.Util.now) == "function" then
    local t = EGM.Util.now()
    if type(t) == "number" then
      return t
    end
  end
  if type(time) == "function" then
    local t = time()
    if type(t) == "number" then
      return t
    end
  end
  return 0
end

local function playerName()
  if EGM.Util and type(EGM.Util.player) == "function" then
    local p = EGM.Util.player()
    if type(p) == "string" then
      return p
    end
  end
  if type(UnitName) == "function" then
    local p = UnitName("player")
    if type(p) == "string" then
      return p
    end
  end
  return ""
end

local function formatMoney(copper)
  local c = numOr(copper, 0)
  if c < 0 then c = 0 end
  if EGM.Util and type(EGM.Util.money) == "function" then
    local s = EGM.Util.money(c)
    if type(s) == "string" then
      return s
    end
  end
  local g = math.floor(c / 10000)
  local s = math.floor(math.mod(c, 10000) / 100)
  local rem = math.mod(c, 100)
  if g > 0 then
    return string.format("|cffffd700%dg|r |cffc7c7cf%02ds|r |cffeda55f%02dc|r", g, s, rem)
  elseif s > 0 then
    return string.format("|cffc7c7cf%ds|r |cffeda55f%02dc|r", s, rem)
  else
    return string.format("|cffeda55f%dc|r", rem)
  end
end

local function formatMoneyPlain(copper)
  local c = numOr(copper, 0)
  if c < 0 then c = 0 end
  if EGM.Util and type(EGM.Util.moneyPlain) == "function" then
    local s = EGM.Util.moneyPlain(c)
    if type(s) == "string" then
      return s
    end
  end
  local g = math.floor(c / 10000)
  local s = math.floor(math.mod(c, 10000) / 100)
  local rem = math.mod(c, 100)
  if g > 0 then
    if rem > 0 then
      return string.format("%dg %02ds %02dc", g, s, rem)
    end
    return string.format("%dg %02ds", g, s)
  elseif s > 0 then
    if rem > 0 then
      return string.format("%ds %02dc", s, rem)
    end
    return string.format("%ds", s)
  else
    return string.format("%dc", rem)
  end
end

local function formatExpires(expUnix)
  local exp = numOr(expUnix, 0)
  local rem = exp - nowSec()
  if rem <= 0 then
    return "0m"
  end
  if rem >= 48 * 3600 then   -- 7-day orders: "6d 23h" like My Orders
    return string.format("%dd %dh", math.floor(rem / 86400), math.floor(math.mod(rem, 86400) / 3600))
  end
  if rem >= 3600 then
    return string.format("%dh", math.floor(rem / 3600))
  end
  local mins = math.floor(rem / 60)
  if mins < 1 then
    mins = 1
  end
  return string.format("%dm", mins)
end

local function isBuyerOnline(buyer)
  if not buyer or buyer == "" then
    return false
  end
  if buyer == playerName() then
    return true
  end
  if EGM.Roster and type(EGM.Roster.isOnline) == "function" then
    if EGM.Roster.isOnline(buyer) then
      return true
    end
  end
  return false
end

local function getBagCount(itemId)
  if not itemId then
    return 0
  end
  if EGM.Bags and type(EGM.Bags.count) == "function" then
    local n = EGM.Bags.count(itemId)
    if type(n) == "number" and n >= 0 then
      return n
    end
  end
  return 0
end

local function isMailboxOpen()
  if EGM.Mail and type(EGM.Mail.isOpen) == "function" then
    if EGM.Mail.isOpen() then
      return true
    end
  end
  return false
end

local function isMailBusy()
  if EGM.Mail and type(EGM.Mail.busy) == "function" then
    if EGM.Mail.busy() then
      return true
    end
  end
  return false
end

local function getIncomingList()
  if EGM.Mail and type(EGM.Mail.incoming) == "function" then
    local list = EGM.Mail.incoming()
    if type(list) == "table" then
      return list
    end
  end
  return {}
end

local function getOrderItemMeta(order)
  local name = strOr(order and order.name, nil)
  local tex = strOr(order and order.tex, nil)
  local stack = numOr(order and order.stack, nil)
  if order and order.item and EGM.Util and type(EGM.Util.itemInfo) == "function" then
    local info = EGM.Util.itemInfo(order.item)
    if type(info) == "table" then
      if not name or name == "" then name = strOr(info.name, nil) end
      if not tex or tex == "" then tex = strOr(info.tex, nil) end
      if not stack or stack < 1 then stack = numOr(info.stack, nil) end
    end
  end
  if not name or name == "" then
    name = "Item #" .. tostring(order and order.item or "?")
  end
  if not tex or tex == "" then
    tex = "Interface\\Icons\\INV_Misc_QuestionMark"
  end
  if not stack or stack < 1 then
    stack = 20
  end
  return name, tex, stack
end

local function truncateText(str, maxLen)
  local s = strOr(str, "")
  if string.len(s) > maxLen then
    if maxLen <= 3 then
      return string.sub(s, 1, maxLen), true
    end
    return string.sub(s, 1, maxLen - 2) .. "..", true
  end
  return s, false
end

local function showItemTooltip(owner, itemId, fallbackName)
  if not GameTooltip then
    return
  end
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  local known = nil
  if itemId and type(GetItemInfo) == "function" then
    known = GetItemInfo(itemId)
  end
  if known and type(GameTooltip.SetHyperlink) == "function" then
    GameTooltip:SetHyperlink("item:" .. tostring(itemId) .. ":0:0:0")
    GameTooltip:Show()
  elseif fallbackName and type(GameTooltip.SetText) == "function" then
    GameTooltip:SetText(fallbackName, 1.0, 0.82, 0.0)
    if itemId and type(GameTooltip.AddLine) == "function" then
      GameTooltip:AddLine("Item ID: " .. tostring(itemId), 0.7, 0.7, 0.7)
    end
    GameTooltip:Show()
  end
end

local function hideTooltip()
  if GameTooltip and type(GameTooltip.Hide) == "function" then
    GameTooltip:Hide()
  end
end

local function buildPlanLines(order, qty)
  if not order or not qty or qty < 1 then
    return {}
  end
  local name, _, stack = getOrderItemMeta(order)
  local plan = nil
  if EGM.Mail and type(EGM.Mail.plan) == "function" then
    plan = EGM.Mail.plan(order.oid, qty)
  end
  local lines = {}
  if type(plan) == "table" and table.getn(plan) > 0 then
    local n = table.getn(plan)
    local i
    for i = 1, n do
      local p = plan[i]
      if type(p) == "table" then
        local pq = numOr(p.qty, 0)
        local pcod = numOr(p.cod, pq * numOr(order.price, 0))
        table.insert(lines, string.format("%d x %s - C.O.D. %s", pq, name, formatMoneyPlain(pcod)))
      end
    end
  else
    local rem = qty
    local unitPrice = numOr(order.price, 0)
    while rem > 0 do
      local sq = rem
      if sq > stack then
        sq = stack
      end
      local cod = sq * unitPrice
      table.insert(lines, string.format("%d x %s - C.O.D. %s", sq, name, formatMoneyPlain(cod)))
      rem = rem - sq
    end
  end
  return lines
end

local function showOrderRowTooltip(row, e)
  if not e or not GameTooltip then
    return
  end
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  GameTooltip:SetText(strOr(e.name, "Order"), 1.0, 0.82, 0.0)
  local statusTxt = e.online and "|cff20ff20(Online)|r" or "|cff999999(Offline)|r"
  GameTooltip:AddLine(string.format("Order #%s  -  Buyer: %s %s", tostring(e.oid or "?"), strOr(e.buyer, "?"), statusTxt), 1.0, 1.0, 1.0)
  GameTooltip:AddLine("Unit Price: " .. formatMoneyPlain(e.price), 0.9, 0.82, 0.5)

  local o = e.order or {}
  local totalOrdered = numOr(o.qty, e.open)
  local totalPaid = numOr(o.paid, 0)
  local totalTransit = numOr(o.transit, 0)
  GameTooltip:AddLine(string.format("Ordered: %d  |  Paid: %d  |  In Transit: %d  |  Open: %d", totalOrdered, totalPaid, totalTransit, e.open), 0.85, 0.85, 0.85)
  GameTooltip:AddLine(string.format("Expires: %s  |  In Bags: %d  |  Deliverable: %d", formatExpires(e.exp), e.bags, e.deliverable), 0.85, 0.85, 0.85)

  local prevQty = e.deliverable
  if e.oid == B.selectedOid and B.deliverQty > 0 then
    prevQty = B.deliverQty
  end
  if prevQty > 0 then
    local lines = buildPlanLines(o, prevQty)
    if table.getn(lines) > 0 then
      GameTooltip:AddLine("Shipment Preview (" .. tostring(prevQty) .. "):", 1.0, 0.82, 0.0)
      local maxLines = table.getn(lines)
      if maxLines > 5 then maxLines = 5 end
      local i
      for i = 1, maxLines do
        GameTooltip:AddLine("  " .. lines[i], 0.8, 0.9, 0.8)
      end
      if table.getn(lines) > 5 then
        GameTooltip:AddLine(string.format("  ... (+%d more mails)", table.getn(lines) - 5), 0.7, 0.7, 0.7)
      end
    end
  else
    GameTooltip:AddLine("No deliverable items in bags.", 0.6, 0.6, 0.6)
  end
  GameTooltip:Show()
end

local function showIncomingRowTooltip(row, d)
  if not d or not GameTooltip then
    return
  end
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  GameTooltip:SetText(strOr(d.name, "Incoming C.O.D."), 1.0, 0.82, 0.0)
  GameTooltip:AddLine(string.format("From: %s  |  Qty: %d", strOr(d.sender, "?"), numOr(d.qty, 0)), 1.0, 1.0, 1.0)
  GameTooltip:AddLine(string.format("C.O.D.: %s  |  Order: %s", formatMoneyPlain(numOr(d.cod, 0)), d.oid and ("#" .. tostring(d.oid)) or "-"), 0.85, 0.85, 0.85)
  if d.why and d.why ~= "" then
    GameTooltip:AddLine("Status: " .. strOr(d.status, "Mismatch") .. " - " .. tostring(d.why), 1.0, 0.3, 0.3)
  elseif d.status then
    GameTooltip:AddLine("Status: " .. tostring(d.status), 0.8, 0.9, 0.8)
  end
  GameTooltip:Show()
end

local function collectFilteredOrders()
  local raw = {}
  if EGM.Orders and type(EGM.Orders.list) == "function" then
    local list = EGM.Orders.list()
    if type(list) == "table" then
      raw = list
    end
  end

  local itemNeedle = string.lower(strOr(B.filterState.item, ""))
  local buyerNeedle = string.lower(strOr(B.filterState.buyer, ""))
  local me = playerName()

  local out = {}
  local n = table.getn(raw)
  local i
  for i = 1, n do
    local o = raw[i]
    if type(o) == "table" then
      local state = strOr(o.state, "open")
      local openQty = numOr(o.open, 0)
      local isCancelled = o.cancelled and true or false
      local isExpired = o.expired and true or false
      if state == "open" and not isCancelled and not isExpired and openQty > 0 then
        local itemName, itemTex, itemStack = getOrderItemMeta(o)
        local buyer = strOr(o.buyer, "")
        local online = isBuyerOnline(buyer)
        local inBags = getBagCount(o.item)
        local own = (buyer ~= "" and buyer == me)
        local deliverable = openQty
        if inBags < deliverable then
          deliverable = inBags
        end
        -- you cannot send mail to yourself: an own order is never deliverable
        if deliverable < 0 or own then
          deliverable = 0
        end
        local unitPrice = numOr(o.price, 0)
        local payout = deliverable * unitPrice
        local total = openQty * unitPrice
        local exp = numOr(o.exp, 0)

        local keep = true
        if B.filterState.view == "matching" then
          if itemNeedle ~= "" then
            if not string.find(string.lower(itemName), itemNeedle, 1, true) then
              keep = false
            end
          end
          if keep and buyerNeedle ~= "" then
            if not string.find(string.lower(buyer), buyerNeedle, 1, true) then
              keep = false
            end
          end
          if keep and B.filterState.onlineOnly and not online then
            keep = false
          end
          if keep and B.filterState.deliverableOnly and deliverable <= 0 then
            keep = false
          end
          if keep and B.filterState.hideOwn and buyer == me then
            keep = false
          end
        end

        if keep then
          table.insert(out, {
            order = o,
            oid = o.oid,
            item = o.item,
            name = itemName,
            tex = itemTex,
            stack = itemStack,
            buyer = buyer,
            online = online,
            price = unitPrice,
            open = openQty,
            bags = inBags,
            deliverable = deliverable,
            payout = payout,
            total = total,
            own = own,
            exp = exp,
          })
        end
      end
    end
  end

  local sk = B.sortKey
  local sa = B.sortAsc
  table.sort(out, function(a, b)
    local va = a[sk]
    local vb = b[sk]
    if sk == "online" then
      va = a.online and 1 or 0
      vb = b.online and 1 or 0
    elseif sk == "name" or sk == "buyer" then
      va = string.lower(strOr(va, ""))
      vb = string.lower(strOr(vb, ""))
    else
      va = numOr(va, 0)
      vb = numOr(vb, 0)
    end
    if va == vb then
      return tostring(a.oid or "") < tostring(b.oid or "")
    end
    if sa then
      return va < vb
    else
      return va > vb
    end
  end)

  return out
end

local function findEntryByOid(oid)
  if not oid then
    return nil
  end
  local n = table.getn(B.visibleOrders)
  local i
  for i = 1, n do
    if B.visibleOrders[i].oid == oid then
      return B.visibleOrders[i]
    end
  end
  if EGM.Orders and type(EGM.Orders.get) == "function" then
    local o = EGM.Orders.get(oid)
    if type(o) == "table" then
      local itemName, itemTex, itemStack = getOrderItemMeta(o)
      local buyer = strOr(o.buyer, "")
      local openQty = numOr(o.open, 0)
      local inBags = getBagCount(o.item)
      local deliv = openQty
      if inBags < deliv then deliv = inBags end
      if deliv < 0 then deliv = 0 end
      local price = numOr(o.price, 0)
      return {
        order = o,
        oid = o.oid,
        item = o.item,
        name = itemName,
        tex = itemTex,
        stack = itemStack,
        buyer = buyer,
        online = isBuyerOnline(buyer),
        price = price,
        open = openQty,
        bags = inBags,
        deliverable = deliv,
        payout = deliv * price,
        exp = numOr(o.exp, 0),
      }
    end
  end
  return nil
end

local function findSelectedIncoming()
  local list = B.visibleIncoming
  local n = table.getn(list)
  if n == 0 then
    return nil
  end
  local i
  for i = 1, n do
    local d = list[i]
    if d and (d.index == B.selectedIncomingIdx or i == B.selectedIncomingIdx) then
      return d
    end
  end
  return list[1]
end

local function setDeliverQty(val)
  local q = math.floor(numOr(tonumber(val), 0))
  if q < 0 then q = 0 end
  B.deliverQty = q
  if B.bottom.qtyBox then
    B.bottom.qtyBox._updating = true
    B.bottom.qtyBox._textVal = tostring(q)
    B.bottom.qtyBox:SetText(tostring(q))
    B.bottom.qtyBox._updating = false
  end
end

local function updateFilterButtons()
  local incCount = table.getn(getIncomingList())
  if B.radioIncoming and B.radioIncoming._label then
    B.radioIncoming._label:SetText(string.format("Incoming C.O.D. (%d)", incCount))
  end

  local views = {
    { btn = B.radioMatching, key = "matching" },
    { btn = B.radioAll,      key = "all"      },
    { btn = B.radioIncoming, key = "incoming" },
  }
  local i
  for i = 1, 3 do
    local v = views[i]
    if v.btn then
      local active = (B.filterState.view == v.key)
      v.btn._checked = active
      if v.btn._selTex then
        if active then v.btn._selTex:Show() else v.btn._selTex:Hide() end
      end
      if v.btn._label then
        if active then
          v.btn._label:SetTextColor(1.0, 1.0, 1.0)
        else
          v.btn._label:SetTextColor(1.0, 0.82, 0.0)
        end
      end
    end
  end
end

local function updateColumnHeaders()
  if not B.browseFrame then
    return
  end
  local isIncoming = (B.filterState.view == "incoming")
  local cols = isIncoming and INCOMING_COLUMNS or ORDER_COLUMNS
  local numCols = table.getn(cols)
  local i
  for i = 1, table.getn(B.headerButtons) do
    local hb = B.headerButtons[i]
    if hb then
      if i <= numCols then
        local c = cols[i]
        hb:ClearAllPoints()
        hb:SetPoint("TOPLEFT", B.browseFrame, "TOPLEFT", c.x, -82)
        hb:SetWidth(c.w)
        hb:SetHeight(19)
        hb._sortKey = c.key
        hb._baseLabel = c.label
        local label = c.label
        if c.key and c.key == B.sortKey then
          label = label .. (B.sortAsc and " ^" or " v")
          hb._label:SetTextColor(1.0, 1.0, 1.0)
        else
          hb._label:SetTextColor(1.0, 0.82, 0.0)
        end
        hb._label:SetText(label)
        hb:Show()
      else
        hb:Hide()
      end
    end
  end
end

local function refreshBottomBar()
  local b = B.bottom
  if not b or not b.deliverBtn then
    return
  end

  local incList = getIncomingList()
  B.visibleIncoming = incList
  local hasVerified = false
  local i
  for i = 1, table.getn(incList) do
    if incList[i] and incList[i].status == "Verified" then
      hasVerified = true
    end
  end
  if hasVerified then
    b.payVerifiedBtn:Enable()
    b.payVerifiedBtn._enabled = true
  else
    b.payVerifiedBtn:Disable()
    b.payVerifiedBtn._enabled = false
  end

  local selInc = findSelectedIncoming()
  if selInc and selInc.status ~= "Paid" and selInc.status ~= "Returned" then
    b.payBtn:Enable()
    b.payBtn._enabled = true
  else
    b.payBtn:Disable()
    b.payBtn._enabled = false
  end

  if B.filterState.view == "incoming" then
    b.qtyLabel:Hide()
    b.qtyBox:Hide()
    b.maxBtn:Hide()
    b.deliverBtn:Hide()
    b.retryBtn:Hide()
    b.payBtn:Show()
    b.payVerifiedBtn:Show()

    if selInc then
      local st = strOr(selInc.status, "Unknown")
      b.statusText:SetText(string.format("%s x%d from %s - %s (%s)",
        truncateText(strOr(selInc.name, "Item"), 18),
        numOr(selInc.qty, 0),
        strOr(selInc.sender, "?"),
        formatMoney(numOr(selInc.cod, 0)),
        st))
    else
      b.statusText:SetText("|cff888888No incoming C.O.D. mails.|r")
    end
    return
  end

  -- Orders view ("matching" or "all")
  b.payBtn:Hide()
  b.payVerifiedBtn:Hide()
  b.qtyLabel:Show()
  b.qtyBox:Show()
  b.maxBtn:Show()
  b.deliverBtn:Show()

  local entry = findEntryByOid(B.selectedOid)
  if not entry then
    b.statusText:SetText(EGM.DB and EGM.DB.hasGuild and not EGM.DB.hasGuild() and ("|cffff8040" .. EGM.NO_GUILD .. "|r") or "|cff888888Select an order to deliver.|r")
    b.deliverBtn:Disable()
    b.deliverBtn._enabled = false
    b.maxBtn:Disable()
    b.maxBtn._enabled = false
    b.retryBtn:Show()
    b.retryBtn:Disable()
    b.retryBtn._enabled = false
    return
  end

  local isOwnOrder = (entry.buyer ~= "" and entry.buyer == playerName())
  if entry.deliverable > 0 and not isOwnOrder then
    b.maxBtn:Enable()
    b.maxBtn._enabled = true
  else
    b.maxBtn:Disable()
    b.maxBtn._enabled = false
  end

  local mailOpen = isMailboxOpen()
  local busy = isMailBusy()
  local qtyValid = (B.deliverQty >= 1 and B.deliverQty <= entry.deliverable and entry.deliverable >= 1)
  local canDeliver = (not isOwnOrder) and mailOpen and qtyValid and (not busy) and (entry.open > 0)

  if canDeliver then
    b.deliverBtn:Enable()
    b.deliverBtn._enabled = true
  else
    b.deliverBtn:Disable()
    b.deliverBtn._enabled = false
  end

  local statusMsg = ""
  if isOwnOrder then
    statusMsg = "|cffff6060Own orders cannot be delivered.|r"
  elseif not mailOpen then
    statusMsg = "|cffaaaaaaOpen a mailbox to deliver.|r"
  elseif B.deliverQty > 0 and qtyValid then
    statusMsg = string.format("Deliver %d x %s -> %s",
      B.deliverQty,
      truncateText(entry.name, 16),
      formatMoney(B.deliverQty * entry.price))
  end

  if EGM.Mail and type(EGM.Mail.status) == "function" then
    local st = EGM.Mail.status()
    if type(st) == "table" and (not st.oid or st.oid == entry.oid) then
      local sent = numOr(st.sent, 0)
      local total = numOr(st.total, 0)
      if st.err and st.err ~= "" then
        statusMsg = string.format("|cffff2020%s (%d/%d sent)|r", tostring(st.err), sent, total)
      elseif total > 0 then
        statusMsg = string.format("|cff20ff20Sending: %d / %d mails|r", sent, total)
      end
    end
  end
  b.statusText:SetText(statusMsg)

  local hasDraft = false
  if EGM.Mail and type(EGM.Mail.draft) == "function" then
    local dr = EGM.Mail.draft(entry.oid)
    if type(dr) == "table" then
      if table.getn(dr) > 0 then
        hasDraft = true
      end
    elseif dr then
      hasDraft = true
    end
  end

  if hasDraft and not isOwnOrder then
    b.retryBtn:Show()
    if mailOpen and not busy then
      b.retryBtn:Enable()
      b.retryBtn._enabled = true
    else
      b.retryBtn:Disable()
      b.retryBtn._enabled = false
    end
  else
    -- always shown like the AH's Bid button; greyed out without unsent mails
    b.retryBtn:Show()
    b.retryBtn:Disable()
    b.retryBtn._enabled = false
  end
end

local function layoutRowForOrder(row)
  row.iconBtn:Show()
  row.c1:SetPoint("LEFT", row, "LEFT", 18, 0)
  row.c2:SetPoint("LEFT", row, "LEFT", 156, 0)
  row.c3:SetPoint("LEFT", row, "LEFT", 234, 0)
  row.c4:SetPoint("LEFT", row, "LEFT", 288, 0)
  row.c5:SetPoint("LEFT", row, "LEFT", 358, 0)
  row.c6:SetPoint("LEFT", row, "LEFT", 396, 0)
  -- same offset to the column headers as c2..c6 (header x - 192); without a point a FontString is never drawn
  row.c7:SetPoint("LEFT", row, "LEFT", 438, 0)
  row.c8:SetPoint("LEFT", row, "LEFT", 488, 0)
  row.c9:SetPoint("LEFT", row, "LEFT", 556, 0)
  row.c7:Show()
  row.c8:Show()
  row.c9:Show()
end

local function layoutRowForIncoming(row)
  row.iconBtn:Hide()
  row.c1:SetPoint("LEFT", row, "LEFT", 2, 0)
  row.c2:SetPoint("LEFT", row, "LEFT", 94, 0)
  row.c3:SetPoint("LEFT", row, "LEFT", 284, 0)
  row.c4:SetPoint("LEFT", row, "LEFT", 334, 0)
  row.c5:SetPoint("LEFT", row, "LEFT", 430, 0)
  row.c6:SetPoint("LEFT", row, "LEFT", 514, 0)
  row.c7:Hide()
  row.c8:Hide()
  row.c9:Hide()
end

local function refreshRows()
  B.visibleOrders = collectFilteredOrders()
  B.visibleIncoming = getIncomingList()

  local offset = 0
  if B.scrollFrame and FauxScrollFrame_GetOffset then
    local o = FauxScrollFrame_GetOffset(B.scrollFrame)
    if type(o) == "number" and o >= 0 then
      offset = o
    end
  end

  if B.filterState.view == "incoming" then
    local totalInc = table.getn(B.visibleIncoming)
    if not B.selectedIncomingIdx and totalInc > 0 then
      local first = B.visibleIncoming[1]
      B.selectedIncomingIdx = (first and first.index) or 1
    end
    if B.scrollFrame and FauxScrollFrame_Update then
      pcall(FauxScrollFrame_Update, B.scrollFrame, totalInc, B.NUM_ROWS, B.ROW_HEIGHT)
    end
    local i
    for i = 1, B.NUM_ROWS do
      local row = B.rows[i]
      local idx = offset + i
      if idx <= totalInc then
        local d = B.visibleIncoming[idx]
        row._mode = "incoming"
        row._incoming = d
        row._entry = nil
        row._oid = nil
        layoutRowForIncoming(row)
        row:Show()

        local key = d.index or idx
        row._incKey = key

        row.c1:SetText(truncateText(strOr(d.sender, "?"), 14))
        row.c2:SetText(truncateText(strOr(d.name, "Item #" .. tostring(d.item or "?")), 26))
        row.c3:SetText(tostring(numOr(d.qty, 0)))
        row.c4:SetText(formatMoney(numOr(d.cod, 0)))
        row.c5:SetText(d.oid and ("#" .. tostring(d.oid)) or "-")

        local st = strOr(d.status, "Unknown")
        if st == "Verified" then
          row.c6:SetText("|cff20ff20Verified|r")
        elseif st == "Mismatch" then
          row.c6:SetText("|cffff2020Mismatch|r")
        elseif st == "Unknown" then
          row.c6:SetText("|cffffd100Unknown|r")
        else
          row.c6:SetText("|cff888888" .. st .. "|r")
        end

        if key == B.selectedIncomingIdx then
          row.selBg:Show()
        else
          row.selBg:Hide()
        end
      else
        row._mode = nil
        row._incoming = nil
        row._entry = nil
        row._oid = nil
        row:Hide()
      end
    end
    return
  end

  -- Orders view ("matching" or "all")
  local total = table.getn(B.visibleOrders)
  if not B.selectedOid and total > 0 then
    B.selectedOid = B.visibleOrders[1].oid
    local defaultDeliv = B.visibleOrders[1].deliverable
    setDeliverQty(defaultDeliv > 0 and defaultDeliv or 1)
  elseif B.selectedOid then
    local cur = findEntryByOid(B.selectedOid)
    if not cur and total > 0 then
      B.selectedOid = B.visibleOrders[1].oid
      local defaultDeliv = B.visibleOrders[1].deliverable
      setDeliverQty(defaultDeliv > 0 and defaultDeliv or 1)
    end
  end

  if B.scrollFrame and FauxScrollFrame_Update then
    pcall(FauxScrollFrame_Update, B.scrollFrame, total, B.NUM_ROWS, B.ROW_HEIGHT)
  end

  local i
  for i = 1, B.NUM_ROWS do
    local row = B.rows[i]
    local idx = offset + i
    if idx <= total then
      local e = B.visibleOrders[idx]
      row._mode = "order"
      row._entry = e
      row._incoming = nil
      row._oid = e.oid
      layoutRowForOrder(row)
      row:Show()

      row.iconTex:SetTexture(e.tex)
      row.iconBtn._item = e.item
      row.iconBtn._name = e.name

      local nameDisp = truncateText(e.name, 22)
      local buyerDisp = truncateText(e.buyer, 12)

      row.c1:SetText(nameDisp)
      row.c2:SetText(buyerDisp)

      if e.own then
        row.c3:SetText("|cff69ccf0Yours|r")
      elseif e.online then
        row.c3:SetText("|cff20ff20Online|r")
      else
        row.c3:SetText("|cff888888Offline|r")
      end

      row.c4:SetText(formatMoney(e.price))
      row.c5:SetText(tostring(e.open))
      row.c6:SetText(tostring(e.bags))
      if e.own then
        row.c7:SetText("|cff777777-|r")
      else
        row.c7:SetText(tostring(e.deliverable))
      end

      if e.deliverable <= 0 then
        -- nothing to deliver now (none in bags, or your own order): the order's total value in grey
        row.c8:SetText("|cff777777" .. formatMoneyPlain(e.total or 0) .. "|r")
      elseif e.online then
        row.c8:SetText(formatMoney(e.payout))
      else
        row.c8:SetText("|cffcbb777" .. formatMoneyPlain(e.payout) .. "|r")
      end

      row.c9:SetText(formatExpires(e.exp))

      if e.oid == B.selectedOid then
        row.selBg:Show()
      else
        row.selBg:Hide()
      end
    else
      row._mode = nil
      row._entry = nil
      row._incoming = nil
      row._oid = nil
      row:Hide()
    end
  end
end

local function refreshBrowseTab()
  if not B.browseFrame then
    return
  end
  updateFilterButtons()
  updateColumnHeaders()
  refreshRows()
  refreshBottomBar()
end

local function selectOrder(oid)
  B.selectedOid = oid
  local entry = findEntryByOid(oid)
  if entry then
    if entry.deliverable > 0 then
      setDeliverQty(entry.deliverable)
    else
      setDeliverQty(0)
    end
  end
  refreshBrowseTab()
end

local function setRadioView(viewMode)
  B.filterState.view = viewMode
  refreshBrowseTab()
end

local function createCheckButton(parent, name, labelText, x, y, onClick)
  local cb = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
  cb:SetWidth(20)
  cb:SetHeight(20)
  cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  cb._checked = false
  cb:SetChecked(nil)

  local lbl = getglobal(name .. "Text")
  if not lbl then
    lbl = cb:CreateFontString(name .. "Label", "OVERLAY", "GameFontHighlightSmall")
  end
  lbl:ClearAllPoints()
  lbl:SetPoint("LEFT", cb, "RIGHT", 2, 0)
  lbl:SetText(labelText)
  cb._label = lbl

  cb:SetScript("OnClick", function()
    cb._checked = not cb._checked
    cb:SetChecked(cb._checked and 1 or nil)
    if onClick then
      onClick(cb._checked)
    end
  end)
  return cb
end

local function createAuctionFilterButton(parent, name, labelText, anchorTo, x, y, onClick)
  local btn = CreateFrame("Button", name, parent)
  btn:SetWidth(156)
  btn:SetHeight(20)
  if anchorTo then
    btn:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", x, y)
  else
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  end

  local bg = btn:CreateTexture(name .. "NormalTex", "BACKGROUND")
  bg:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-FilterBg")
  bg:SetTexCoord(0, 0.53125, 0, 0.625)
  bg:SetAllPoints(btn)
  btn._bgTex = bg

  local sel = btn:CreateTexture(name .. "SelTex", "ARTWORK")
  sel:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
  if sel.SetBlendMode then sel:SetBlendMode("ADD") end
  sel:SetVertexColor(1.0, 0.82, 0.0, 0.55)
  sel:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
  sel:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
  sel:Hide()
  btn._selTex = sel

  local hl = btn:CreateTexture(name .. "HighlightTex", "HIGHLIGHT")
  hl:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
  if hl.SetBlendMode then hl:SetBlendMode("ADD") end
  hl:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
  hl:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)

  local lbl = btn:CreateFontString(name .. "Text", "OVERLAY", "GameFontNormalSmall")
  lbl:SetPoint("LEFT", btn, "LEFT", 8, 0)
  lbl:SetJustifyH("LEFT")
  lbl:SetText(labelText)
  btn._label = lbl

  btn:SetScript("OnClick", function()
    if PlaySound then PlaySound("igMainMenuOptionCheckBoxOn") end
    if onClick then onClick() end
  end)
  return btn
end

-- shared with the Statistics tab (same left list look)
EGM.UI = EGM.UI or {}
EGM.UI.filterButton = createAuctionFilterButton

-- Plain-text description of what a Deliver click does (shown in the confirm dialog)
function B.deliverText(name, buyer, price, qty, mails)
  local total = qty * price
  local s = string.format("Send %dx %s to %s as C.O.D. for %s", qty, tostring(name), tostring(buyer), formatMoneyPlain(total))
  if qty > 1 then s = s .. string.format(" (%d x %s)", qty, formatMoneyPlain(price)) end
  if mails > 1 then s = s .. string.format(" in %d mails", mails) end
  return s .. string.format("? You need a free bag slot to split the stack. %s pays when taking the mail; the gold comes to you by mail.", tostring(buyer))
end

-- Deliver / Retry: ask first (option "Confirm before delivering", default on), then send
local pending
function B.confirmSend(e, qty, isRetry)
  if not e or not qty or qty < 1 then return end
  local function run()
    if EGM.Mail then
      if isRetry then
        if type(EGM.Mail.retry) == "function" then EGM.Mail.retry(e.oid) end
      elseif type(EGM.Mail.deliver) == "function" then
        EGM.Mail.deliver(e.oid, qty)
      end
    end
    refreshBrowseTab()
  end
  local c = EGM.DB and EGM.DB.char
  if (c and c.confirmDeliver == false) or not StaticPopup_Show or not StaticPopupDialogs then run(); return end
  local mails = 1
  if EGM.Mail and EGM.Mail.plan then mails = table.getn(EGM.Mail.plan(e.oid, qty)); if mails < 1 then mails = 1 end end
  pending = run
  StaticPopupDialogs["EGM_CONFIRM_DELIVER"] = {
    text = "%s", button1 = "Send", button2 = "Cancel",
    OnAccept = function() local fn = pending; pending = nil; if fn then fn() end end,
    OnCancel = function() pending = nil end,
    timeout = 0, whileDead = 1, hideOnEscape = 1,
  }
  StaticPopup_Show("EGM_CONFIRM_DELIVER", B.deliverText(e.name, e.buyer, e.price, qty, mails))
end

EGM.UI.confirmSend, EGM.UI.deliverText = B.confirmSend, B.deliverText

local function buildTopSearchArea(parent)
  -- Item Name (like BrowseName at 80,-41)
  local itemLbl = parent:CreateFontString("EGMFrameBrowseItemLabel", "OVERLAY", "GameFontHighlightSmall")
  itemLbl:SetPoint("TOPLEFT", parent, "TOPLEFT", 80, -41)
  itemLbl:SetText("Item Name")

  local itemBox = CreateFrame("EditBox", "EGMFrameBrowseFilterItem", parent, "InputBoxTemplate")
  B.filterItemBox = itemBox
  itemBox:SetWidth(140)
  itemBox:SetHeight(16)
  itemBox:SetPoint("TOPLEFT", parent, "TOPLEFT", 84, -56)
  itemBox:SetAutoFocus(false)
  itemBox:SetScript("OnTextChanged", function()
    local txt = strOr(itemBox:GetText(), itemBox._textVal or "")
    B.filterState.item = txt
    if txt ~= "" and B.filterState.view ~= "matching" then
      setRadioView("matching")
    else
      refreshBrowseTab()
    end
  end)
  itemBox:SetScript("OnEnterPressed", function() itemBox:ClearFocus() end)
  itemBox:SetScript("OnEscapePressed", function() itemBox:ClearFocus() end)

  -- Buyer box next to Item Name (x ~235)
  local buyerLbl = parent:CreateFontString("EGMFrameBrowseBuyerLabel", "OVERLAY", "GameFontHighlightSmall")
  buyerLbl:SetPoint("TOPLEFT", parent, "TOPLEFT", 235, -41)
  buyerLbl:SetText("Buyer")

  local buyerBox = CreateFrame("EditBox", "EGMFrameBrowseFilterBuyer", parent, "InputBoxTemplate")
  B.filterBuyerBox = buyerBox
  buyerBox:SetWidth(130)
  buyerBox:SetHeight(16)
  buyerBox:SetPoint("TOPLEFT", parent, "TOPLEFT", 239, -56)
  buyerBox:SetAutoFocus(false)
  buyerBox:SetScript("OnTextChanged", function()
    local txt = strOr(buyerBox:GetText(), buyerBox._textVal or "")
    B.filterState.buyer = txt
    if txt ~= "" and B.filterState.view ~= "matching" then
      setRadioView("matching")
    else
      refreshBrowseTab()
    end
  end)
  buyerBox:SetScript("OnEnterPressed", function() buyerBox:ClearFocus() end)
  buyerBox:SetScript("OnEscapePressed", function() buyerBox:ClearFocus() end)

  -- Checkboxes in the IsUsableCheckButton area (x ~ 445..620, y -40..-76)
  B.checkOnline = createCheckButton(parent, "EGMFrameBrowseCheckOnline", "Online only", 445, -40, function(checked)
    B.filterState.onlineOnly = checked
    if checked and B.filterState.view ~= "matching" then
      setRadioView("matching")
    else
      refreshBrowseTab()
    end
  end)

  B.checkDeliverable = createCheckButton(parent, "EGMFrameBrowseCheckDeliverable", "Deliverable only", 445, -58, function(checked)
    B.filterState.deliverableOnly = checked
    if checked and B.filterState.view ~= "matching" then
      setRadioView("matching")
    else
      refreshBrowseTab()
    end
  end)

  B.checkHideOwn = createCheckButton(parent, "EGMFrameBrowseCheckHideOwn", "Hide my orders", 555, -49, function(checked)
    B.filterState.hideOwn = checked
    if checked and B.filterState.view ~= "matching" then
      setRadioView("matching")
    else
      refreshBrowseTab()
    end
  end)

  -- Search & Reset buttons (80x22) at the right of the top area (x ~ 662..824, y -52)
  local searchBtn = CreateFrame("Button", "EGMFrameBrowseSearchBtn", parent, "UIPanelButtonTemplate")
  searchBtn:SetWidth(80)
  searchBtn:SetHeight(22)
  searchBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", 662, -52)
  searchBtn:SetText("Search")
  searchBtn:SetScript("OnClick", function()
    refreshBrowseTab()
  end)

  local resetBtn = CreateFrame("Button", "EGMFrameBrowseResetBtn", parent, "UIPanelButtonTemplate")
  resetBtn:SetWidth(80)
  resetBtn:SetHeight(22)
  resetBtn:SetPoint("LEFT", searchBtn, "RIGHT", 4, 0)
  resetBtn:SetText("Reset")
  resetBtn:SetScript("OnClick", function()
    B.filterState.item = ""
    B.filterState.buyer = ""
    B.filterState.onlineOnly = false
    B.filterState.deliverableOnly = false
    B.filterState.hideOwn = false
    B.filterItemBox._textVal = ""
    B.filterItemBox:SetText("")
    B.filterBuyerBox._textVal = ""
    B.filterBuyerBox:SetText("")
    B.checkOnline._checked = false
    B.checkOnline:SetChecked(nil)
    B.checkDeliverable._checked = false
    B.checkDeliverable:SetChecked(nil)
    B.checkHideOwn._checked = false
    B.checkHideOwn:SetChecked(nil)
    setRadioView("matching")
  end)
end

local function buildLeftCategoryColumn(parent)
  -- AuctionFilterButton1 TOPLEFT at 23, -105 (width 156, height 20)
  B.radioMatching = createAuctionFilterButton(parent, "EGMFrameBrowseViewMatching", "Matching Orders", nil, 23, -105, function()
    setRadioView("matching")
  end)

  B.radioAll = createAuctionFilterButton(parent, "EGMFrameBrowseViewAll", "All Orders", B.radioMatching, 0, -2, function()
    setRadioView("all")
  end)

  B.radioIncoming = createAuctionFilterButton(parent, "EGMFrameBrowseViewIncoming", "Incoming C.O.D. (0)", B.radioAll, 0, -2, function()
    setRadioView("incoming")
  end)
end

local function buildResultList(parent)
  -- 9 column sort header buttons at y = -82 starting at x = 186 (WhoFrame-ColumnTabs 3-slice look)
  local hIdx
  for hIdx = 1, table.getn(ORDER_COLUMNS) do
    local col = ORDER_COLUMNS[hIdx]
    local hb = CreateFrame("Button", "EGMFrameBrowseHeader" .. hIdx, parent)
    hb:SetWidth(col.w)
    hb:SetHeight(19)
    hb:SetPoint("TOPLEFT", parent, "TOPLEFT", col.x, -82)
    hb._sortKey = col.key
    hb._baseLabel = col.label

    local leftTex = hb:CreateTexture(nil, "BACKGROUND")
    leftTex:SetTexture("Interface\\FriendsFrame\\WhoFrame-ColumnTabs")
    leftTex:SetWidth(5)
    leftTex:SetHeight(19)
    leftTex:SetPoint("TOPLEFT", hb, "TOPLEFT", 0, 0)
    leftTex:SetTexCoord(0, 0.078125, 0, 0.59375)

    local rightTex = hb:CreateTexture(nil, "BACKGROUND")
    rightTex:SetTexture("Interface\\FriendsFrame\\WhoFrame-ColumnTabs")
    rightTex:SetWidth(4)
    rightTex:SetHeight(19)
    rightTex:SetPoint("TOPRIGHT", hb, "TOPRIGHT", 0, 0)
    rightTex:SetTexCoord(0.90625, 0.96875, 0, 0.59375)

    local midTex = hb:CreateTexture(nil, "BACKGROUND")
    midTex:SetTexture("Interface\\FriendsFrame\\WhoFrame-ColumnTabs")
    midTex:SetHeight(19)
    midTex:SetPoint("TOPLEFT", leftTex, "TOPRIGHT", 0, 0)
    midTex:SetPoint("BOTTOMRIGHT", rightTex, "BOTTOMLEFT", 0, 0)
    midTex:SetTexCoord(0.078125, 0.90625, 0, 0.59375)

    local hlTex = hb:CreateTexture(nil, "HIGHLIGHT")
    hlTex:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight")
    if hlTex.SetBlendMode then hlTex:SetBlendMode("ADD") end
    hlTex:SetPoint("TOPLEFT", hb, "TOPLEFT", 2, -2)
    hlTex:SetPoint("BOTTOMRIGHT", hb, "BOTTOMRIGHT", -2, 2)

    local fs = hb:CreateFontString("EGMFrameBrowseHeader" .. hIdx .. "Text", "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("LEFT", hb, "LEFT", 4, 0)
    fs:SetText(col.label)
    hb._label = fs

    hb:SetScript("OnClick", function()
      local sk = hb._sortKey
      if not sk then
        return
      end
      if B.sortKey == sk then
        B.sortAsc = not B.sortAsc
      else
        B.sortKey = sk
        if sk == "name" or sk == "buyer" or sk == "exp" then
          B.sortAsc = true
        else
          B.sortAsc = false
        end
      end
      refreshBrowseTab()
    end)

    B.headerButtons[hIdx] = hb
  end

  -- BrowseScrollFrame with TOPRIGHT at 797, -105 (FauxScrollFrame scrollbar sits at 797..818)
  local sf = CreateFrame("ScrollFrame", "EGMFrameBrowseScrollFrame", parent, "FauxScrollFrameTemplate")
  B.scrollFrame = sf
  sf:SetPoint("TOPLEFT", parent, "TOPLEFT", 186, -105)
  sf:SetPoint("TOPRIGHT", parent, "TOPLEFT", 797, -105)
  sf:SetHeight(296)
  sf:SetScript("OnVerticalScroll", function()
    if FauxScrollFrame_OnVerticalScroll then
      FauxScrollFrame_OnVerticalScroll(B.ROW_HEIGHT, function()
        refreshRows()
      end)
    else
      refreshRows()
    end
  end)

  -- 17 compact 17px rows starting at x = 195, y = -110 (ending at y = -399, x = 795)
  local i
  for i = 1, B.NUM_ROWS do
    local row = CreateFrame("Button", "EGMFrameBrowseRow" .. i, parent)
    row:SetWidth(600)
    row:SetHeight(B.ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 195, -110 - (i - 1) * B.ROW_HEIGHT)

    local selBg = row:CreateTexture(nil, "BACKGROUND")
    selBg:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
    if selBg.SetBlendMode then selBg:SetBlendMode("ADD") end
    selBg:SetVertexColor(1.0, 0.82, 0.0, 0.45)
    selBg:SetAllPoints(row)
    selBg:Hide()
    row.selBg = selBg

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
    if hl.SetBlendMode then hl:SetBlendMode("ADD") end
    hl:SetVertexColor(1.0, 1.0, 1.0, 0.25)
    hl:SetAllPoints(row)

    local rIconBtn = CreateFrame("Button", "EGMFrameBrowseRow" .. i .. "Icon", row)
    rIconBtn:SetWidth(14)
    rIconBtn:SetHeight(14)
    rIconBtn:SetPoint("LEFT", row, "LEFT", 0, 0)
    local rIconTex = rIconBtn:CreateTexture(nil, "ARTWORK")
    rIconTex:SetAllPoints(rIconBtn)
    rIconBtn:SetScript("OnEnter", function()
      showItemTooltip(rIconBtn, rIconBtn._item, rIconBtn._name)
    end)
    rIconBtn:SetScript("OnLeave", function()
      hideTooltip()
    end)
    row.iconBtn = rIconBtn
    row.iconTex = rIconTex

    row.c1 = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.c2 = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.c3 = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.c4 = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.c5 = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.c6 = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.c7 = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.c8 = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.c9 = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    layoutRowForOrder(row)

    row:SetScript("OnClick", function()
      if row._mode == "incoming" then
        B.selectedIncomingIdx = row._incKey
        refreshBrowseTab()
      elseif row._oid then
        selectOrder(row._oid)
      end
    end)

    row:SetScript("OnEnter", function()
      if row._mode == "incoming" and row._incoming then
        showIncomingRowTooltip(row, row._incoming)
      elseif row._entry then
        showOrderRowTooltip(row, row._entry)
      end
    end)
    row:SetScript("OnLeave", function()
      hideTooltip()
    end)

    B.rows[i] = row
  end
end

local function buildBottomBar(parent)
  -- Right-side chained 80x22 buttons like BrowseBidButton / BrowseBuyoutButton / BrowseCloseButton
  local closeBtn = CreateFrame("Button", "EGMFrameBrowseCloseBtn", parent, "UIPanelButtonTemplate")
  closeBtn:SetWidth(80)
  closeBtn:SetHeight(22)
  closeBtn:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -8, 14)
  closeBtn:SetText("Close")
  closeBtn:SetScript("OnClick", function()
    if EGM.UI and type(EGM.UI.hide) == "function" then
      EGM.UI.hide()
    elseif EGMFrame and EGMFrame.Hide then
      EGMFrame:Hide()
    end
  end)
  B.bottom.closeBtn = closeBtn

  local deliverBtn = CreateFrame("Button", "EGMFrameBrowseDeliverBtn", parent, "UIPanelButtonTemplate")
  deliverBtn:SetWidth(80)
  deliverBtn:SetHeight(22)
  deliverBtn:SetPoint("RIGHT", closeBtn, "LEFT", 0, 0)
  deliverBtn:SetText("Deliver")
  deliverBtn:SetScript("OnClick", function()
    local e = findEntryByOid(B.selectedOid)
    if not e then return end
    if e.buyer == playerName() then return end
    if not isMailboxOpen() then return end
    if B.deliverQty < 1 or B.deliverQty > e.deliverable then return end
    B.confirmSend(e, B.deliverQty, false)
  end)
  B.bottom.deliverBtn = deliverBtn

  local retryBtn = CreateFrame("Button", "EGMFrameBrowseRetryBtn", parent, "UIPanelButtonTemplate")
  retryBtn:SetWidth(80)
  retryBtn:SetHeight(22)
  retryBtn:SetPoint("RIGHT", deliverBtn, "LEFT", 0, 0)
  retryBtn:SetText("Retry")
  retryBtn:SetScript("OnClick", function()
    if B.selectedOid and EGM.Mail and type(EGM.Mail.retry) == "function" then
      local e = findEntryByOid(B.selectedOid)
      local qty = 0
      local dr = EGM.Mail.draft and EGM.Mail.draft(B.selectedOid)
      if type(dr) == "table" then for i = 1, table.getn(dr) do qty = qty + (dr[i].qty or 0) end end
      B.confirmSend(e, qty, true)
    end
  end)
  retryBtn:Hide()
  B.bottom.retryBtn = retryBtn

  -- Incoming C.O.D. mode bottom buttons ("Pay" and "Pay Verified")
  local payVerifiedBtn = CreateFrame("Button", "EGMFrameBrowsePayVerifiedBtn", parent, "UIPanelButtonTemplate")
  payVerifiedBtn:SetWidth(80)
  payVerifiedBtn:SetHeight(22)
  payVerifiedBtn:SetPoint("RIGHT", closeBtn, "LEFT", 0, 0)
  payVerifiedBtn:SetText("Pay Verified")
  payVerifiedBtn:SetScript("OnClick", function()
    if EGM.Mail and type(EGM.Mail.payVerified) == "function" then
      EGM.Mail.payVerified()
      refreshBrowseTab()
    end
  end)
  payVerifiedBtn:Hide()
  B.bottom.payVerifiedBtn = payVerifiedBtn

  local payBtn = CreateFrame("Button", "EGMFrameBrowsePayBtn", parent, "UIPanelButtonTemplate")
  payBtn:SetWidth(80)
  payBtn:SetHeight(22)
  payBtn:SetPoint("RIGHT", payVerifiedBtn, "LEFT", 0, 0)
  payBtn:SetText("Pay")
  payBtn:SetScript("OnClick", function()
    local d = findSelectedIncoming()
    if d and EGM.Mail and type(EGM.Mail.pay) == "function" then
      EGM.Mail.pay(d.index)
      refreshBrowseTab()
    end
  end)
  payBtn:Hide()
  B.bottom.payBtn = payBtn

  -- Left/Centre bottom area: Deliver quantity box + Max button + status text
  local qtyLabel = parent:CreateFontString("EGMFrameBrowseQtyLabel", "OVERLAY", "GameFontNormalSmall")
  qtyLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 188, -419)
  qtyLabel:SetText("Deliver:")
  qtyLabel:SetTextColor(1.0, 0.82, 0.0)
  B.bottom.qtyLabel = qtyLabel

  local qtyBox = CreateFrame("EditBox", "EGMFrameBrowseDeliverQty", parent, "InputBoxTemplate")
  qtyBox:SetWidth(54)
  qtyBox:SetHeight(18)
  qtyBox:SetPoint("LEFT", qtyLabel, "RIGHT", 8, 0)
  qtyBox:SetAutoFocus(false)
  qtyBox:SetNumeric(true)
  qtyBox:SetText("0")
  qtyBox._textVal = "0"
  qtyBox:SetScript("OnTextChanged", function()
    if qtyBox._updating then
      return
    end
    local rawTxt = strOr(qtyBox:GetText(), qtyBox._textVal or "0")
    local n = tonumber(rawTxt) or 0
    if n < 0 then n = 0 end
    B.deliverQty = math.floor(n)
    refreshBottomBar()
  end)
  -- clicking into the field selects the number, so typing "3" replaces the prefilled maximum instead of making "63"
  qtyBox:SetScript("OnEditFocusGained", function() qtyBox:HighlightText() end)
  qtyBox:SetScript("OnEnterPressed", function() qtyBox:ClearFocus() end)
  qtyBox:SetScript("OnEscapePressed", function() qtyBox:ClearFocus() end)
  B.bottom.qtyBox = qtyBox

  local maxBtn = CreateFrame("Button", "EGMFrameBrowseMaxBtn", parent, "UIPanelButtonTemplate")
  maxBtn:SetWidth(42)
  maxBtn:SetHeight(20)
  maxBtn:SetPoint("LEFT", qtyBox, "RIGHT", 4, 0)
  maxBtn:SetText("Max")
  maxBtn:SetScript("OnClick", function()
    local e = findEntryByOid(B.selectedOid)
    if e then
      setDeliverQty(e.deliverable)
      refreshBottomBar()
    end
  end)
  B.bottom.maxBtn = maxBtn

  local statusText = parent:CreateFontString("EGMFrameBrowseDeliveryStatus", "OVERLAY", "GameFontHighlightSmall")
  statusText:SetPoint("LEFT", maxBtn, "RIGHT", 10, 0)
  statusText:SetPoint("RIGHT", retryBtn, "LEFT", -6, 0)
  statusText:SetJustifyH("LEFT")
  statusText:SetText("")
  B.bottom.statusText = statusText
end

local function buildBrowseTab(parent)
  B.browseFrame = parent
  buildTopSearchArea(parent)
  buildLeftCategoryColumn(parent)
  buildResultList(parent)
  buildBottomBar(parent)
  refreshBrowseTab()
end

-- Public helpers on EGM.UI.Browse for programmatic inspection and testing
function EGM.UI.Browse.refresh()
  refreshBrowseTab()
end

function EGM.UI.Browse.selectOrder(oid)
  selectOrder(oid)
end

function EGM.UI.Browse.getSelectedOid()
  return B.selectedOid
end

function EGM.UI.Browse.getVisibleOrders()
  return B.visibleOrders
end

function EGM.UI.Browse.getVisibleIncoming()
  return B.visibleIncoming
end

function EGM.UI.Browse.selectIncoming(index)
  B.selectedIncomingIdx = index
  refreshBrowseTab()
end

function EGM.UI.Browse.setFilter(field, value)
  if B.filterState[field] ~= nil then
    B.filterState[field] = value
    refreshBrowseTab()
  end
end

function EGM.UI.Browse.setSort(colKey, ascending)
  B.sortKey = colKey
  if ascending ~= nil then
    B.sortAsc = ascending and true or false
  end
  refreshBrowseTab()
end

function EGM.UI.Browse.setDeliverQuantity(qty)
  setDeliverQty(qty)
  refreshBottomBar()
end

if EGM.UI and type(EGM.UI.registerTab) == "function" then
  EGM.UI.registerTab(1, buildBrowseTab, refreshBrowseTab, "Browse")
else
  EGM.PendingTabs = EGM.PendingTabs or {}
  table.insert(EGM.PendingTabs, { index = 1, build = buildBrowseTab, refresh = refreshBrowseTab, art = "Browse" })
end
