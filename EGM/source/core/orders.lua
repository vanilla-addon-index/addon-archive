-- EGM core: orders and shipments derived from the journal, budget, payment block, statistics
EGM = EGM or {}
local O, B, S = {}, {}, {}
EGM.Orders, EGM.Budget, EGM.Stats = O, B, S

local orders, ships, list, built = {}, {}, {}, false

function O.invalidate() built = false end
EGM.On("ROSTER", function() built = false end)

local function byTime(a, b)
  if a.at ~= b.at then return a.at < b.at end
  return a.id < b.id
end

local function shipOf(sid, oid)
  local s = ships[sid]
  if not s then s = { sid = sid, oid = oid }; ships[sid] = s end
  return s
end

local function build()
  orders, ships, list = {}, {}, {}
  local evs = {}
  local all = EGM.Journal.all()
  for i = 1, table.getn(all) do evs[i] = all[i] end
  table.sort(evs, byTime)
  -- orders of buyers who are not (or no longer) guild members stay in the data but are hidden everywhere
  local hidden = {}
  local counts = EGM.Roster and EGM.Roster.counts
  if counts then
    for i = 1, table.getn(evs) do
      local ev = evs[i]
      if ev.t == "ORDER_CREATED" and not counts(ev.d.buyer) then hidden[ev.d.oid] = true end
    end
  end
  for i = 1, table.getn(evs) do
    local ev = evs[i]
    local d = ev.d
    if hidden[d.oid] then
      -- not shown
    elseif ev.t == "ORDER_CREATED" then
      if not orders[d.oid] then
        orders[d.oid] = { oid = d.oid, buyer = d.buyer, item = d.item, name = d.name, tex = d.tex, stack = d.stack or 1, price = d.price, qty = d.qty,
          hours = d.hours, created = ev.at, exp = d.exp, cancelled = false }
      end
    elseif ev.t == "ORDER_CANCEL" then
      local o = orders[d.oid]
      if o and ev.o == o.buyer then o.cancelled = true; o.cancelAt = o.cancelAt or ev.at end
    else
      local s = shipOf(d.sid, d.oid)
      local o = orders[d.oid]
      local buyerSaid = o and ev.o == o.buyer and not ev.relay
      if ev.t == "SHIP_SENT" then
        if not s.at then s.at = ev.at; s.seller = d.seller; s.buyer = d.buyer; s.item = d.item; s.qty = d.qty; s.cod = d.cod end
      elseif ev.t == "SHIP_FAILED" then
        s.failed = s.failed or ev.at
      elseif ev.t == "SHIP_SEEN" then
        if o and ev.o == o.buyer then s.seen = s.seen or ev.at; s.seenFirstHand = s.seenFirstHand or buyerSaid end
      elseif ev.t == "SHIP_PAID" then
        if o and ev.o == o.buyer then s.paid = s.paid or ev.at end
      elseif ev.t == "SHIP_RETURNED" then
        s.returned = s.returned or ev.at
        -- only an active return of a verified mail, said by the buyer himself, counts against him (2026-11-05)
        if buyerSaid and tonumber(d.active) == 1 then s.activeReturn = true end
      end
    end
  end
  local now = EGM.Util.now()
  for oid, o in pairs(orders) do
    o.paid, o.transit, o.ships = 0, 0, {}
    for sid, s in pairs(ships) do
      if s.oid == oid and s.at then
        table.insert(o.ships, s)
        if s.paid then o.paid = o.paid + s.qty
        elseif not s.returned then o.transit = o.transit + s.qty end
      end
    end
    table.sort(o.ships, function(a, b) return a.at < b.at end)
    o.expired = now >= (o.exp or 0)
    if o.cancelled or o.expired then o.open = 0 else o.open = math.max(0, o.qty - o.paid - o.transit) end
    if o.paid >= o.qty then o.state = "filled"
    elseif o.cancelled then o.state = "cancelled"
    elseif o.expired then o.state = "expired"
    elseif o.open == 0 and o.transit > 0 then o.state = "transit" -- everything is on its way, waiting for the C.O.D. payment
    else o.state = "open" end
    table.insert(list, o)
  end
  table.sort(list, function(a, b) return a.created > b.created end)
  built = true
end

local function ensure() if not built then build() end end

function O.get(oid) ensure(); return orders[oid] end
function O.list() ensure(); return list end
function O.shipments(oid) ensure(); local o = orders[oid]; return o and o.ships or {} end
function O.shipment(sid) ensure(); local s = ships[sid]; return s and s.at and s or nil end

function O.lastFor(item)
  local l = EGM.DB.char.last and EGM.DB.char.last[tonumber(item)]
  if l then return l.price, l.qty end
  return nil
end

-- budget: real gold minus what own orders may still cost (open rest + sent but unpaid) ----------------------
function B.committed()
  ensure()
  local me, sum = EGM.Util.player(), 0
  for i = 1, table.getn(list) do
    local o = list[i]
    if o.buyer == me then sum = sum + o.price * (o.open + o.transit) end
  end
  return sum
end
function B.available() return (GetMoney() or 0) - B.committed() end

-- nil, or why this char may not create orders now (seen + unpaid, or an active return of a verified mail)
function B.blocked()
  ensure()
  local me = EGM.Util.player()
  for sid, s in pairs(ships) do
    local o = orders[s.oid]
    if o and o.buyer == me and s.at then
      if s.activeReturn then return "You returned a verified C.O.D. delivery (Order #" .. EGM.Util.shortId(o.oid) .. "). New orders are blocked." end
      if s.seen and not s.paid and not s.returned then return "You have an unpaid C.O.D. delivery (Order #" .. EGM.Util.shortId(o.oid) .. "). Pay it before creating new orders." end
    end
  end
  return nil
end

function O.create(item, name, tex, stack, price, qty, hours)
  item, price, qty, hours = tonumber(item), math.floor(tonumber(price) or 0), math.floor(tonumber(qty) or 0), tonumber(hours)
  if not item then return nil, "Choose an item." end
  if qty < 1 then return nil, "Quantity must be at least 1." end
  if price < 1 then return nil, "Set a unit price." end
  if hours ~= 24 and hours ~= 48 and hours ~= 168 then return nil, "Duration must be 24 hours, 48 hours or 7 days." end
  if not EGM.DB.hasGuild() then return nil, EGM.NO_GUILD end
  local why = B.blocked()
  if why then return nil, why end
  local total = price * qty
  if total > (GetMoney() or 0) then return nil, "Not enough gold: the order costs " .. EGM.Util.moneyPlain(total) .. "." end
  if total > B.available() then return nil, "Not enough free budget: " .. EGM.Util.moneyPlain(B.available()) .. " left after your open orders." end
  local info = EGM.Util.itemInfo(item)
  local oid = EGM.Util.newId()
  local ev = EGM.Journal.emit("ORDER_CREATED", { oid = oid, buyer = EGM.Util.player(), item = item, name = name or (info and info.name) or ("Item " .. item),
    tex = tex or (info and info.tex), stack = stack or (info and info.stack) or 1, price = price, qty = qty, hours = hours, exp = EGM.Util.now() + hours * 3600 })
  if not ev then return nil, "Could not store the order." end
  EGM.DB.char.last[item] = { price = price, qty = qty }
  return oid
end

function O.cancel(oid)
  local o = O.get(oid)
  if not o then return nil, "Unknown order." end
  if o.buyer ~= EGM.Util.player() then return nil, "Only the buyer can cancel an order." end
  -- open and in-transit orders can be cancelled; deliveries sent before the cancel stay valid (Mail.validate)
  if o.state ~= "open" and o.state ~= "transit" then return nil, "The order is " .. o.state .. "." end
  EGM.Journal.emit("ORDER_CANCEL", { oid = oid })
  return true
end

-- the buyer confirms receipt of every unpaid, unreturned shipment of his order (paid while EGM did not watch)
function O.markReceived(oid)
  local o = O.get(oid)
  if not o then return nil, "Unknown order." end
  if o.buyer ~= EGM.Util.player() then return nil, "Only the buyer can confirm receipt." end
  local n = 0
  for i = 1, table.getn(o.ships) do
    local sh = o.ships[i]
    if not sh.paid and not sh.returned then EGM.Journal.emit("SHIP_PAID", { sid = sh.sid, oid = oid }); n = n + 1 end
  end
  if n == 0 then return nil, "Nothing in transit." end
  return n
end

-- statistics: only from logged events; paid volume never mixes with open orders ---------------------------
local function pct(n, d) return d > 0 and math.floor(n * 100 / d + 0.5) or 0 end

function S.top(role, metric, days)
  ensure()
  local since = days and (EGM.Util.now() - days * 86400) or 0
  local acc = {}
  local function row(name)
    local r = acc[name]
    if not r then r = { name = name, num = 0, den = 0, value = 0, delay = 0, nd = 0 }; acc[name] = r end
    return r
  end
  if metric == "fulfillment" and role == "buyers" then
    for i = 1, table.getn(list) do
      local o = list[i]
      if o.created >= since then local r = row(o.buyer); r.num = r.num + o.paid; r.den = r.den + o.qty end
    end
  else
    for sid, s in pairs(ships) do
      if s.at and s.at >= since then
        local o = orders[s.oid]
        local who = role == "buyers" and (s.buyer or (o and o.buyer)) or s.seller
        if who then
          local r = row(who)
          if metric == "volume" then
            if s.paid then r.value = r.value + (s.cod or 0); r.num = r.num + 1 end
          elseif metric == "payment" and role == "buyers" then
            -- a paid delivery always counts; an unpaid one only once the buyer's client saw it (unseen stays neutral);
            -- the time to pay needs both the sighting and the payment (2026-11-05: a buyer paid and was not listed)
            if s.paid or s.seenFirstHand then
              r.den = r.den + 1
              if s.paid then
                r.num = r.num + 1
                if s.seen then r.delay = r.delay + math.max(0, s.paid - s.seen); r.nd = r.nd + 1 end
              end
            end
          else -- sellers: fulfillment and payment = paid shipments of the sent ones
            r.den = r.den + 1
            if s.paid then r.num = r.num + 1 end
          end
        end
      end
    end
  end
  local out = {}
  for name, r in pairs(acc) do
    if metric == "volume" then
      if r.value > 0 then r.text = EGM.Util.moneyPlain(r.value) .. " - " .. r.num .. " paid"; table.insert(out, r) end
    elseif r.den > 0 then
      r.value = pct(r.num, r.den)
      r.text = r.value .. "% - " .. r.num .. "/" .. r.den
      if r.nd > 0 then r.text = r.text .. " - avg " .. math.floor(r.delay / r.nd / 60) .. "m" end
      table.insert(out, r)
    end
  end
  table.sort(out, function(a, b) if a.value ~= b.value then return a.value > b.value end; if a.den ~= b.den then return a.den > b.den end; return a.name < b.name end)
  while table.getn(out) > 10 do table.remove(out) end
  return out
end
