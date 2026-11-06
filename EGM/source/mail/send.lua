-- EGM mail: C.O.D. send queue. One stack per mail, one mail at a time, confirmed by MAIL_SEND_SUCCESS.
EGM = EGM or {}
EGM.Mail = EGM.Mail or {}
local M = EGM.Mail

local GAP = 0.6        -- seconds between two mails
local SPLITWAIT = 0.4  -- seconds after a split before attaching
local TIMEOUT = 10     -- seconds without answer -> Unknown

local open = false
local q = nil          -- active series
local status = nil     -- {oid, sent, total, err}
local timer = 0
local phase = nil      -- nil | "gap" | "split" | "await"
local cur = nil        -- current mail

local function fire(n) if EGM.Fire then EGM.Fire(n) end end
local function char() return (EGM.DB and EGM.DB.char) or {} end
local function player() return (EGM.Util and EGM.Util.player and EGM.Util.player()) or UnitName("player") end
local function mp(c) if EGM.Util and EGM.Util.moneyPlain then return EGM.Util.moneyPlain(c) end return tostring(c) end
local function short(id) if EGM.Util and EGM.Util.shortId then return EGM.Util.shortId(id) end return id end

local function stackSize(o)
  local info = EGM.Util and EGM.Util.itemInfo and EGM.Util.itemInfo(o.item)
  local s = (info and info.stack) or o.stack or 1
  if not s or s < 1 then s = 1 end
  return s
end

function M.isOpen() return open end
function M.busy() return q ~= nil end
function M.status() return status end

-- preview: array of {qty, cod}, one stack per mail
function M.plan(oid, qty)
  local out = {}
  local o = EGM.Orders and EGM.Orders.get and EGM.Orders.get(oid)
  qty = tonumber(qty)
  if not o or not qty or qty < 1 then return out end
  local size = stackSize(o)
  local rest = qty
  while rest > 0 do
    local n = rest
    if n > size then n = size end
    table.insert(out, { qty = n, cod = n * o.price })
    rest = rest - n
  end
  return out
end

local function saveDraft(oid, rest)
  local c = char()
  c.drafts = c.drafts or {}
  if rest and rest > 0 then c.drafts[oid] = { qty = rest, at = time() } else c.drafts[oid] = nil end
end

function M.draft(oid)
  local c = char()
  local d = c.drafts and c.drafts[oid]
  if not d or not d.qty or d.qty < 1 then return nil end
  local p = M.plan(oid, d.qty)
  if table.getn(p) == 0 then return nil end
  return p
end

local function whisper(msg)
  if char().whisper == false then return end
  if EGM.Roster and EGM.Roster.isOnline and EGM.Roster.isOnline(q.buyer) then
    SendChatMessage(msg, "WHISPER", nil, q.buyer)
  end
end

local function finish()
  local s = q
  phase = nil; cur = nil; timer = 0
  if s then
    if not status.err and s.sentMails > 0 then
      whisper(string.format("[GuildMarket] Sent %dx %s via %d C.O.D. mail%s for Order #%s (%s total).",
        s.sentQty, s.name, s.sentMails, s.sentMails == 1 and "" or "s", short(s.oid), mp(s.sentCod)))
    elseif status.err == "Mailbox Full" then
      whisper("[GuildMarket] My mail for Order #" .. short(s.oid) ..
        " could not be sent: your mailbox is full. Please make room, then I will send the rest.")
    end
  end
  q = nil
  fire("SEND")
end

-- stop the series. uncertain = the current mail may or may not have gone out (not in the draft, no SHIP_FAILED)
local function stop(err, uncertain, emitFail)
  local rest = q.remaining
  if uncertain and cur then rest = rest - cur.qty end
  status.err = err
  -- a refused mail keeps its stack in the send slot; take it out so a retry can attach again
  if err ~= "Unknown" and GetSendMailItem and GetSendMailItem() then
    EGM.Util.real("ClickSendMailItemButton")()
    if ClearCursor then ClearCursor() end
  end
  saveDraft(q.oid, rest)
  if emitFail and cur and EGM.Journal and EGM.Journal.emit then
    EGM.Journal.emit("SHIP_FAILED", { sid = cur.sid, oid = q.oid, why = err })
  end
  finish()
end

-- choose the stack for the next mail; returns mail table or nil, err
local function prepare()
  local o = EGM.Orders.get(q.oid)
  if not o then return nil, "Order not found" end
  if o.buyer == player() then return nil, "Cannot deliver to your own order" end
  if o.state ~= "open" then return nil, "Order is " .. tostring(o.state) end
  if q.remaining > o.open then return nil, "Order changed (only " .. o.open .. " open)" end
  local want = q.remaining
  local size = stackSize(o)
  if want > size then want = size end
  local stacks = EGM.Bags.stacks(o.item)
  local exact, bigger, biggest
  for i = 1, table.getn(stacks) do
    local s = stacks[i]
    if s.count == want then
      exact = exact or s
    elseif s.count > want then
      if not bigger or s.count < bigger.count then bigger = s end
    end
    if not biggest or s.count > biggest.count then biggest = s end
  end
  local m = { qty = want, item = o.item, name = o.name }
  m.sid = (EGM.Util.newId and EGM.Util.newId()) or tostring(time())
  if exact then
    m.bag, m.slot = exact.bag, exact.slot
  elseif bigger then
    local fb, fs
    if EGM.Bags.freeSlot then fb, fs = EGM.Bags.freeSlot() end
    if not fb then return nil, "Needs 1 free bag slot to split a stack" end
    m.bag, m.slot, m.fbag, m.fslot = bigger.bag, bigger.slot, fb, fs
  elseif biggest then
    -- no stack as large as wanted: send the largest one as is
    m.qty = biggest.count
    m.bag, m.slot = biggest.bag, biggest.slot
  else
    return nil, "Item not in bags"
  end
  m.cod = m.qty * o.price
  return m
end

-- the 1.12 client attaches asynchronously: open the Send Mail tab, put the stack into the slot, then wait (phase
-- "attach") until GetSendMailItem() reports it before setting C.O.D. and sending (2026-11-05: "Could not attach item")
local function sendNow()
  SetSendMailCOD(cur.cod)
  local subject = "EGM " .. q.oid .. "/" .. cur.sid .. " " .. cur.qty .. "x " .. cur.name
  phase = "await"; timer = 0
  SendMail(q.buyer, subject, "EGM C.O.D. delivery")
end

local function attachAndSend()
  local b, s = cur.bag, cur.slot
  if cur.fbag then b, s = cur.fbag, cur.fslot end
  local _, count = EGM.Util.real("GetContainerItemInfo")(b, s)
  if not count or count ~= cur.qty then return false, "Item split failed" end
  if SendMailFrame and not SendMailFrame:IsVisible() and MailFrameTab_OnClick then pcall(MailFrameTab_OnClick, 2) end
  if GetSendMailItem and GetSendMailItem() then return false, "Send mail already has an attachment" end
  EGM.Util.real("PickupContainerItem")(b, s)
  EGM.Util.real("ClickSendMailItemButton")()
  if CursorHasItem and CursorHasItem() then ClearCursor(); return false, "Could not attach item" end
  if not GetSendMailItem then sendNow(); return true end
  phase = "attach"; timer = 0
  return true
end

local function nextMail()
  if q.remaining <= 0 then finish() return end
  local m, err = prepare()
  if not m then
    cur = nil
    stop(err, false, false)
    return
  end
  cur = m
  if m.fbag then
    SplitContainerItem(m.bag, m.slot, m.qty)
    EGM.Util.real("PickupContainerItem")(m.fbag, m.fslot)
    phase = "split"; timer = 0
  else
    local ok, e = attachAndSend()
    if not ok then stop(e, false, true) end
  end
end

local function sendDone()
  q.remaining = q.remaining - cur.qty
  q.sentQty = q.sentQty + cur.qty
  q.sentCod = q.sentCod + cur.cod
  q.sentMails = q.sentMails + 1
  status.sent = status.sent + 1
  if status.sent > status.total then status.total = status.sent end
  if EGM.Journal and EGM.Journal.emit then
    EGM.Journal.emit("SHIP_SENT", { sid = cur.sid, oid = q.oid, seller = player(), buyer = q.buyer,
      item = cur.item, qty = cur.qty, cod = cur.cod })
  end
  cur = nil
  saveDraft(q.oid, q.remaining)
  fire("SEND")
  if q.remaining > 0 then phase = "gap"; timer = 0 else finish() end
end

local function failure(text)
  if not q or phase ~= "await" then return end
  local low = string.lower(text or "")
  local err = text or "Mail failed"
  if string.find(low, "mailbox") and string.find(low, "full") then err = "Mailbox Full"
  -- the client only shows this generic text when the server refuses the mail (a full recipient mailbox on the test realm)
  elseif string.find(low, "could not be sent", 1, true) then err = "Mailbox Full" end
  stop(err, false, true)
end

function M.deliver(oid, qty)
  if q then return nil, "Already sending" end
  if not open then return nil, "Open a mailbox first" end
  local o = EGM.Orders and EGM.Orders.get and EGM.Orders.get(oid)
  if not o then return nil, "Order not found" end
  qty = tonumber(qty)
  if not qty or qty < 1 or qty ~= math.floor(qty) then return nil, "Invalid quantity" end
  if o.buyer == player() then return nil, "Cannot deliver to your own order" end
  if o.state ~= "open" then return nil, "Order is " .. tostring(o.state) end
  if qty > o.open then return nil, "Only " .. o.open .. " still open" end
  if EGM.Bags.count(o.item) < qty then return nil, "Not enough in bags" end
  q = { oid = oid, buyer = o.buyer, name = o.name, remaining = qty, sentQty = 0, sentCod = 0, sentMails = 0 }
  status = { oid = oid, sent = 0, total = table.getn(M.plan(oid, qty)), err = nil }
  local c = char()
  if c.drafts then c.drafts[oid] = nil end
  phase = "gap"; timer = 0
  fire("SEND")
  return true
end

function M.retry(oid)
  local d = char().drafts and char().drafts[oid]
  if not d or not d.qty or d.qty < 1 then return nil, "No draft" end
  return M.deliver(oid, d.qty)
end

function M._onUpdate(elapsed)
  if not q or not phase then return end
  timer = timer + (elapsed or 0)
  if phase == "gap" then
    if timer >= GAP then timer = 0; phase = nil; nextMail() end
  elseif phase == "split" then
    if timer >= SPLITWAIT then
      local ok, e = attachAndSend()
      if not ok then
        if timer < 2 then return end -- split stack may still be locked, retry briefly
        stop(e, false, true)
      end
    end
  elseif phase == "attach" then
    if GetSendMailItem() then sendNow()
    elseif timer >= 3 then stop("Could not attach item", false, true) end
  elseif phase == "await" then
    if timer >= TIMEOUT then stop("Unknown", true, false) end
  end
end

function M._onEvent(ev, a1)
  if ev == "MAIL_SHOW" then
    open = true
    fire("MAIL_SHOW")
    if char().openAtMailbox ~= false and EGM.UI and EGM.UI.show then EGM.UI.show(1, true) end
  elseif ev == "MAIL_CLOSED" then
    open = false
    if q then
      if phase == "await" then stop("Unknown", true, false) else stop("Mailbox closed", false, cur ~= nil) end
    end
    fire("MAIL_CLOSED")
    if EGM.UI and EGM.UI.closeFromMailbox then EGM.UI.closeFromMailbox() end
  elseif ev == "MAIL_SEND_SUCCESS" then
    if q and phase == "await" then sendDone() end
  elseif ev == "MAIL_FAILED" then
    failure("Mail failed")
  elseif ev == "UI_ERROR_MESSAGE" then
    failure(a1)
  elseif ev == "CHAT_MSG_SYSTEM" then
    local low = string.lower(a1 or "")
    if string.find(low, "online") or string.find(low, "offline") then return end
    if string.find(low, "mail") or string.find(low, "cannot") or string.find(low, "can't")
      or string.find(low, "not enough") or string.find(low, "full") then
      failure(a1)
    end
  end
end

if CreateFrame then
  local f = CreateFrame("Frame", "EGMMailSendFrame")
  f:RegisterEvent("MAIL_SHOW")
  f:RegisterEvent("MAIL_CLOSED")
  f:RegisterEvent("MAIL_SEND_SUCCESS")
  f:RegisterEvent("MAIL_FAILED")
  f:RegisterEvent("UI_ERROR_MESSAGE")
  f:RegisterEvent("CHAT_MSG_SYSTEM")
  f:SetScript("OnEvent", function() EGM.Mail._onEvent(event, arg1) end)
  f:SetScript("OnUpdate", function() EGM.Mail._onUpdate(arg1) end)
end
