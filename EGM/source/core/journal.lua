-- EGM core: append-only event journal (idempotent by id). First-hand rules: an event about a char only counts when that char sent it.
EGM = EGM or {}
local J = {}
EGM.Journal = J

local index = {}
local orderIds = {}

local TYPES = { ORDER_CREATED = 1, ORDER_CANCEL = 1, SHIP_SENT = 1, SHIP_FAILED = 1, SHIP_SEEN = 1, SHIP_PAID = 1, SHIP_RETURNED = 1 }

local function events() return EGM.DB.events() end

function J.load()
  index, orderIds = {}, {}
  local list = events()
  for i = 1, table.getn(list) do
    index[list[i].id] = true
    if list[i].t == "ORDER_CREATED" and type(list[i].d) == "table" then orderIds[list[i].d.oid] = true end
  end
  if EGM.Orders and EGM.Orders.invalidate then EGM.Orders.invalidate() end
end

-- shape check + who may say what (the origin must be the char the event is about)
local function valid(ev)
  if type(ev) ~= "table" or type(ev.id) ~= "string" or not TYPES[ev.t] or type(ev.o) ~= "string" or type(ev.d) ~= "table" then return nil end
  ev.at = tonumber(ev.at)
  if not ev.at then return nil end
  local d = ev.d
  if ev.t == "ORDER_CREATED" then
    d.item = tonumber(d.item); d.price = tonumber(d.price); d.qty = tonumber(d.qty); d.hours = tonumber(d.hours); d.exp = tonumber(d.exp); d.stack = tonumber(d.stack) or 1
    if not (d.oid and d.buyer == ev.o and d.item and d.price and d.price > 0 and d.qty and d.qty > 0 and d.exp) then return nil end
  elseif ev.t == "SHIP_SENT" then
    d.qty = tonumber(d.qty); d.cod = tonumber(d.cod); d.item = tonumber(d.item)
    if not (d.sid and d.oid and d.seller == ev.o and d.qty and d.cod) then return nil end
  else
    if not d.oid then return nil end
    if ev.t ~= "ORDER_CANCEL" and not d.sid then return nil end
  end
  return true
end

-- Storage/relay rule: a member's events always count; events of a non-member only for an order the bucket already
-- holds (shipments/payments of an ex-member's order keep syncing), never a new order. Roster unknown: store everything.
function J.allowed(ev)
  local c = EGM.Roster and EGM.Roster.counts
  if not c or c(ev.o) then return true end
  if ev.t == "ORDER_CREATED" then return false end
  return type(ev.d) == "table" and orderIds[ev.d.oid] and true or false
end
-- relay only once the roster is known, and only what is allowed
function J.relayable(ev)
  if not (EGM.Roster and EGM.Roster.known and EGM.Roster.known()) then return false end
  return J.allowed(ev)
end

-- from = sender of the addon message (nil = this client)
function J.add(ev, from)
  if not EGM.DB.hasGuild() then return false end -- no guild, no market
  if not valid(ev) or index[ev.id] then return false end
  if from and not J.allowed(ev) then return false end
  if from and from ~= ev.o then ev.relay = 1 end
  table.insert(events(), ev)
  index[ev.id] = true
  if ev.t == "ORDER_CREATED" then
    local d = ev.d
    orderIds[d.oid] = true
    local items = EGM.DB.realm.items
    if not items[d.item] and d.name then items[d.item] = { name = d.name, tex = d.tex, stack = d.stack } end
  end
  if EGM.Orders and EGM.Orders.invalidate then EGM.Orders.invalidate() end
  EGM.Fire("STATE", ev)
  return true
end

function J.emit(t, d)
  local ev = { id = EGM.Util.newId("E"), t = t, o = EGM.Util.player(), at = EGM.Util.now(), d = d }
  if not J.add(ev) then return nil end
  if EGM.Comm and EGM.Comm.broadcast then EGM.Comm.broadcast(ev) end
  return ev
end

function J.all() return events() end
function J.has(id) return index[id] and true or false end
function J.since(at)
  local out, list = {}, events()
  for i = 1, table.getn(list) do if list[i].at >= (at or 0) then table.insert(out, list[i]) end end
  return out
end
