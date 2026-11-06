-- EGM mail: incoming C.O.D. validation and pay. Reads headers/items only, never the mail text.
EGM = EGM or {}
EGM.Mail = EGM.Mail or {}
local M = EGM.Mail

local list = {}        -- current EGM entries
local seenSent = {}    -- sid -> true, SHIP_SEEN emitted
local pending = {}     -- sid -> {oid, t}
local pendingN = 0

local function fire(n) if EGM.Fire then EGM.Fire(n) end end
local function char() return (EGM.DB and EGM.DB.char) or {} end
local function player() return (EGM.Util and EGM.Util.player and EGM.Util.player()) or UnitName("player") end

-- "EGM <oid>/<sid> <qty>x <name>" -> oid, sid, qty, name (or nil)
function M.parseSubject(subject)
  if not subject then return nil end
  -- the client shows C.O.D. mails as "(COD) <subject>" (measured on the test realm 2026-11-05)
  subject = string.gsub(subject, "^%(COD%) ", "")
  local _, _, oid, sid, qty, name = string.find(subject, "^EGM (%S+)/(%S+) (%d+)x (.+)$")
  if not oid then return nil end
  return oid, sid, tonumber(qty), name
end

-- pure validation: returns status, why, needsSync
function M.validate(e)
  local o = EGM.Orders and EGM.Orders.get and EGM.Orders.get(e.oid)
  if not o then return "Unknown", "Needs Sync: order unknown", true end
  if o.buyer ~= player() then return "Mismatch", "Not your order" end
  local sh = EGM.Orders.shipment and EGM.Orders.shipment(e.sid)
  if not sh then return "Unknown", "Needs Sync: shipment not announced", true end
  if sh.oid and sh.oid ~= e.oid then return "Mismatch", "Shipment belongs to another order" end
  if sh.paid then return "Paid", "Already paid" end
  if sh.returned then return "Returned", "Returned" end
  if o.cancelled and (not o.cancelAt or not sh.at or sh.at > o.cancelAt) then return "Mismatch", "Order was cancelled" end
  if EGM.Roster and EGM.Roster.isMember and not EGM.Roster.isMember(e.sender) then
    return "Mismatch", "Sender is not in the guild"
  end
  if e.sender ~= sh.seller then return "Mismatch", "Sender is not the announced seller" end
  if not e.hasItem then return "Mismatch", "No item attached" end
  if not e.name or string.lower(e.name) ~= string.lower(o.name or "") then return "Mismatch", "Wrong item" end
  if e.qty ~= sh.qty or e.qty ~= e.subjQty then return "Mismatch", "Quantity does not match" end
  if (o.paid or 0) + e.qty > o.qty then return "Mismatch", "Overdelivery" end
  if e.cod ~= e.qty * o.price then return "Mismatch", "C.O.D. does not match price" end
  if sh.cod and sh.cod ~= e.cod then return "Mismatch", "C.O.D. differs from announced" end
  return "Verified", "OK"
end

local function build(noAuto)
  list = {}
  local n = GetInboxNumItems() or 0
  for i = 1, n do
    local _, _, sender, subject, money, cod, _, hasItem, _, wasReturned = GetInboxHeaderInfo(i)
    local oid, sid, sq = M.parseSubject(subject)
    if oid then
      local name, _, count = nil, nil, nil
      if hasItem then name, _, count = GetInboxItem(i) end
      local e = { index = i, sender = sender, name = name, qty = count or 0, cod = cod or 0,
        oid = oid, sid = sid, subjQty = sq, hasItem = hasItem and true or false }
      local o = EGM.Orders and EGM.Orders.get and EGM.Orders.get(oid)
      e.item = o and o.item
      local st, why, sync = M.validate(e)
      if wasReturned and st ~= "Paid" then st, why = "Returned", "Returned to sender" end
      e.status, e.why, e.needsSync = st, why, sync
      table.insert(list, e)
    end
  end
  -- SHIP_SEEN once per own C.O.D.
  for i = 1, table.getn(list) do
    local e = list[i]
    local o = EGM.Orders and EGM.Orders.get and EGM.Orders.get(e.oid)
    if o and o.buyer == player() and e.cod > 0 and not seenSent[e.sid] then
      local sh = EGM.Orders.shipment and EGM.Orders.shipment(e.sid)
      if not (sh and sh.seen) then
        seenSent[e.sid] = true
        if EGM.Journal and EGM.Journal.emit then
          EGM.Journal.emit("SHIP_SEEN", { sid = e.sid, oid = e.oid })
        end
      else
        seenSent[e.sid] = true
      end
    end
  end
  fire("INBOX")
end

function M.incoming() return list end

local function payOne(e)
  if pending[e.sid] then return nil, "Already paying" end
  if GetMoney() < e.cod then return nil, "Not enough gold" end
  pending[e.sid] = { oid = e.oid, t = GetTime() }
  pendingN = pendingN + 1
  TakeInboxItem(e.index)
  return true
end

-- explicit click: Verified, or Unknown (after the user's click)
function M.pay(index)
  build(true)
  local e
  for i = 1, table.getn(list) do if list[i].index == index then e = list[i] end end
  if not e then return nil, "Mail not found" end
  if e.status ~= "Verified" and e.status ~= "Unknown" then return nil, "Not payable: " .. tostring(e.status) end
  return payOne(e)
end

function M.payVerified()
  build(true)
  local todo = {}
  for i = 1, table.getn(list) do
    if list[i].status == "Verified" then table.insert(todo, list[i]) end
  end
  local paid, spent = 0, 0
  -- highest index first so removed mails do not shift the rest
  for i = table.getn(todo), 1, -1 do
    local e = todo[i]
    if GetMoney() - spent >= e.cod and not pending[e.sid] then
      pending[e.sid] = { oid = e.oid, t = GetTime() }
      pendingN = pendingN + 1
      spent = spent + e.cod
      TakeInboxItem(e.index)
      paid = paid + 1
    end
  end
  return paid
end

local function checkPending()
  if pendingN == 0 then return end
  for sid, p in pairs(pending) do
    local still = false
    for i = 1, table.getn(list) do
      if list[i].sid == sid and list[i].hasItem then still = true end
    end
    if not still then
      pending[sid] = nil; pendingN = pendingN - 1
      if EGM.Journal and EGM.Journal.emit then EGM.Journal.emit("SHIP_PAID", { sid = sid, oid = p.oid }) end
    elseif GetTime() - p.t > 30 then
      pending[sid] = nil; pendingN = pendingN - 1
    end
  end
end

function M._onInboxUpdate()
  build(true)
  checkPending()
  if char().autopay == true then
    local any = false
    for i = 1, table.getn(list) do
      local e = list[i]
      if e.status == "Verified" and not e.needsSync and not pending[e.sid] then any = true end
    end
    if any then M.payVerified() end
  end
end

-- Paying or returning through the normal mailbox (Blizzard's C.O.D. popup, the Mail addon, a click on the attachment)
-- must count too (2026-11-05: a buyer paid the C.O.D. in the mailbox, the order stayed "in transit"). Both calls go
-- through these globals; EGM loads before "Mail" (shirsig), so its hooks wrap these wrappers.
local function ownEgmCod(index)
  local _, _, _, subject, _, cod, _, hasItem = GetInboxHeaderInfo(index)
  local oid, sid = M.parseSubject(subject)
  if not oid or not hasItem or not cod or cod <= 0 then return nil end
  local o = EGM.Orders and EGM.Orders.get and EGM.Orders.get(oid)
  if not o or o.buyer ~= player() then return nil end
  return oid, sid, cod
end

local origTake = TakeInboxItem
if origTake then
  TakeInboxItem = function(index)
    local oid, sid, cod = ownEgmCod(index)
    if oid and not pending[sid] and GetMoney() >= cod then
      pending[sid] = { oid = oid, t = GetTime() }; pendingN = pendingN + 1
    end
    return origTake(index)
  end
end

local origReturn = ReturnInboxItem
if origReturn then
  ReturnInboxItem = function(index)
    local oid, sid = ownEgmCod(index)
    if oid then
      local verified = false
      for i = 1, table.getn(list) do if list[i].sid == sid and list[i].status == "Verified" then verified = true end end
      -- only an active return of a verified mail counts against the buyer (2026-11-05)
      if EGM.Journal and EGM.Journal.emit then EGM.Journal.emit("SHIP_RETURNED", { sid = sid, oid = oid, active = verified and 1 or 0 }) end
    end
    return origReturn(index)
  end
end

-- diagnostics: a failing inbox scan must not vanish silently (2026-11-05: a buyer never recognized an EGM C.O.D.).
-- Errors go to EGM.DB.char.lastError and once into the chat; with SuperWoW's ExportFile a short trace of the last scan
-- lands in Interface/../imports (guild members without it simply get no file).
local errShown = false
local function trace(err)
  local c = char()
  local n = GetInboxNumItems() or 0
  local lines = { "at=" .. tostring(time()) .. " player=" .. tostring(player()) .. " inbox=" .. n .. " egm=" .. table.getn(list) .. " err=" .. tostring(err) }
  for i = 1, math.min(n, 20) do
    local ok, a1, a2, sender, subject, money, cod, days, hasItem = pcall(GetInboxHeaderInfo, i)
    if ok and cod and cod > 0 then
      table.insert(lines, i .. " from=" .. tostring(sender) .. " cod=" .. tostring(cod) .. " item=" .. tostring(hasItem) .. " subj=" .. tostring(subject))
    end
  end
  for i = 1, table.getn(list) do
    local e = list[i]
    table.insert(lines, "egm " .. tostring(e.oid) .. "/" .. tostring(e.sid) .. " " .. tostring(e.status) .. " " .. tostring(e.why))
  end
  -- keep the last 30 scans (a C.O.D. that is visible for one scan only must still show up)
  c.inboxLog = c.inboxLog or {}
  table.insert(c.inboxLog, table.concat(lines, " || "))
  while table.getn(c.inboxLog) > 30 do table.remove(c.inboxLog, 1) end
  c.inboxTrace = lines
  if EGM.debug and ExportFile then pcall(ExportFile, "egm_inbox_trace", table.concat(c.inboxLog, string.char(10))) end -- /egm debug
end

if CreateFrame then
  local f = CreateFrame("Frame", "EGMMailInboxFrame")
  f:RegisterEvent("MAIL_INBOX_UPDATE")
  f:RegisterEvent("MAIL_CLOSED")
  f:SetScript("OnEvent", function()
    if event == "MAIL_CLOSED" then
      list = {}; fire("INBOX")
    else
      local ok, err = pcall(EGM.Mail._onInboxUpdate)
      if not ok then
        char().lastError = { at = time(), where = "inbox", err = tostring(err) }
        if not errShown and DEFAULT_CHAT_FRAME then errShown = true; DEFAULT_CHAT_FRAME:AddMessage("|cffff2020EGM inbox error:|r " .. tostring(err)) end
      end
      pcall(trace, not ok and err or nil)
    end
  end)
end
