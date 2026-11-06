-- BananaBank Bank-Seite
-- Laeuft nur auf Chars, die per /bb setbank als Bank festgelegt sind.

local BB = BananaBank
local getn = table.getn

BB.BAG_LIST = { 0, 1, 2, 3, 4 }
BB.BANK_LIST = { -1, 5, 6, 7, 8, 9, 10 }

-- ------------------------------------------------------------
-- Scan
-- ------------------------------------------------------------
function BB:ScanContainers(bags)
  local items = {}
  for _, bag in ipairs(bags) do
    local n = GetContainerNumSlots(bag) or 0
    for slot = 1, n do
      local link = GetContainerItemLink(bag, slot)
      if link then
        local id, name, q = BB.ParseLink(link)
        local tex, count = GetContainerItemInfo(bag, slot)
        local bind = "none"
        if id then
          -- Faellt der Tooltip-Test aus, gilt das Item als ungebunden.
          -- Ein Fehler hier darf nie dazu fuehren, dass Items verschwinden.
          local ok, res = pcall(function() return self:BindOfItem(id, bag, slot) end)
          if ok and res then bind = res end
        end
        -- Seelengebundenes laesst sich nicht verschicken, also gar nicht erst anzeigen
        if id and not BB.IGNORE_IDS[id] and bind ~= "soul" then
          local e = items[id]
          if not e then
            local k, s = self:ItemCategory(id, bind)
            e = { c = 0, q = q, t = BB.ShortTex(tex), n = name or ("#" .. id), k = k, s = s }
            -- Klassenbeschraenkung ("Classes: Druid"); ein Fehler hier darf nie Items verschwinden lassen
            if self.ClassOfItem then
              local okc, cr = pcall(function() return self:ClassOfItem(id, bag, slot) end)
              if okc and cr and cr ~= "" then e.cr = cr end
            end
            items[id] = e
          end
          e.c = e.c + (count or 1)
        end
      end
    end
  end
  return items
end

local function sameItems(a, b)
  for id, it in pairs(a or {}) do
    local o = b[id]
    if not o or o.c ~= it.c or (o.cr or "") ~= (it.cr or "") then return false end
  end
  for id in pairs(b or {}) do
    if not a[id] then return false end
  end
  return true
end

-- onlyIfChanged: nichts senden, wenn sich der Inhalt nicht veraendert hat (Taschen-Ereignisse)
function BB:UpdateSnapshot(push, onlyIfChanged)
  if not self:IsBank() then return end
  -- Rang verloren? Dann nicht mehr als Bank senden.
  if not self:MayBeBank(self:Me()) then
    if not self.warnedRank then
      self.warnedRank = true
      if self:Ready() then
        self:Print("|cffff4040" .. string.format(self.T("ERR_RANK_LOST"), BB.BANK_RANK_LABEL) .. "|r")
      else
        self:Print("|cffff4040" .. string.format(self.T("ERR_RANK_MISSING"), BB.BANK_RANK_LABEL) .. "|r")
      end
    end
    return
  end
  self.warnedRank = nil
  local db = BananaBankDB
  local me = self:Me()
  -- nach dem Schliessen liefert der Client fuer Bankfaecher 0 Plaetze: dann Cache behalten
  if self.bankOpen and (GetContainerNumSlots(-1) or 0) > 0 then
    db.bankCache[me] = self:ScanContainers(BB.BANK_LIST)
  end
  -- Kein gelesener Bankinhalt? Dann wenigstens die Taschen zeigen, statt gar nichts.
  local partial = false
  if not db.bankCache[me] then
    partial = true
    if not self.warnedNoBank then
      self.warnedNoBank = true
      self:Print("|cffff8000" .. self.T("MSG_OPEN_BANK_FIRST") .. "|r")
    end
  end
  local items = {}
  local function add(src)
    for id, it in pairs(src) do
      local e = items[id]
      if not e then
        -- Kategorie immer neu bestimmen: Regeln und Bindungsdaten koennen sich geaendert haben
        local k, s = self:ItemCategory(id, db.bind and db.bind[id])
        e = { c = 0, q = it.q, t = it.t, n = it.n, k = k, s = s }
        items[id] = e
      end
      if it.cr and it.cr ~= "" then e.cr = it.cr end
      e.c = e.c + it.c
    end
  end
  if db.bankCache[me] then add(db.bankCache[me]) end
  add(self:ScanContainers(BB.BAG_LIST))
  local ts = time()
  local old = db.snaps[me]
  local changed = not old or (old.partial and true or false) ~= partial or not sameItems(old.items, items)
  if onlyIfChanged and not changed then
    -- unveraendert: hoechstens noch nachsenden, was bisher nur lokal gespeichert war
    if push and self.snapUnsent then
      self.snapUnsent = false
      self:PushSnapshot(me)
    end
    return
  end
  if old and old.ts >= ts then ts = old.ts + 1 end
  db.snaps[me] = { ts = ts, gold = GetMoney(), items = items, from = me, partial = partial }
  if push then
    self.snapUnsent = false
    self:PushSnapshot(me)
  else
    self.snapUnsent = true
  end
  if self.UI then self.UI:Refresh() end
end

-- /bb stock <Text>: zeigt, welche gespeicherten Bestaende (aller Banken) das Item enthalten und wie alt sie sind.
-- Laeuft auf jedem Client und zeigt, was dieser Client ueber den Bestand glaubt.
function BB:StockDebug(text)
  text = string.lower(text or "")
  if text == "" then
    self:Print(self.T("STOCKDBG_USAGE"))
    return
  end
  local hits = 0
  local names = {}
  for bank in pairs(BananaBankDB.snaps) do table.insert(names, bank) end
  table.sort(names)
  for i = 1, getn(names) do
    local bank = names[i]
    local snap = BananaBankDB.snaps[bank]
    for id, it in pairs(snap.items) do
      if string.find(string.lower(it.n or ""), text, 1, true) then
        hits = hits + 1
        local ok = self:MayBeBank(bank) and self.T("YES") or self.T("NO")
        self:Print(string.format(self.T("STOCKDBG_LINE"), bank, it.c, it.n, date("%d.%m. %H:%M:%S", snap.ts),
          snap.from or "?", ok))
      end
    end
  end
  if hits == 0 then self:Print(self.T("FIND_NONE")) end
end

-- /bb find <Text>: zeigt, wo dieser Char passende Items liegen hat und was als Tasche im Einsatz ist
function BB:FindItems(text)
  text = string.lower(text or "")
  if text == "" then
    self:Print(self.T("FIND_USAGE"))
    return
  end
  local hits = 0
  local function scan(list, label)
    for _, bag in ipairs(list) do
      for slot = 1, (GetContainerNumSlots(bag) or 0) do
        local link = GetContainerItemLink(bag, slot)
        if link then
          local _, name = BB.ParseLink(link)
          if name and string.find(string.lower(name), text, 1, true) then
            local _, count = GetContainerItemInfo(bag, slot)
            hits = hits + 1
            self:Print(string.format(self.T("FIND_LINE"), label, bag, slot, count or 1, name))
          end
        end
      end
    end
  end
  scan(BB.BAG_LIST, self.T("FIND_BAGS"))
  if self.bankOpen then scan(BB.BANK_LIST, self.T("FIND_BANK")) end
  -- Taschen im Einsatz (angelegt): zaehlen nicht zum Bestand
  if GetInventoryItemLink and ContainerIDToInventoryID then
    for bag = 1, 4 do
      local link = GetInventoryItemLink("player", ContainerIDToInventoryID(bag))
      if link then
        local _, name = BB.ParseLink(link)
        if name and string.find(string.lower(name), text, 1, true) then
          hits = hits + 1
          self:Print(string.format(self.T("FIND_EQUIPPED"), bag, name))
        end
      end
    end
  end
  if not self.bankOpen then
    local cache = BananaBankDB.bankCache[self:Me()] or {}
    for id, it in pairs(cache) do
      if string.find(string.lower(it.n or ""), text, 1, true) then
        hits = hits + 1
        self:Print(string.format(self.T("FIND_CACHE"), it.c, it.n))
      end
    end
  end
  if hits == 0 then self:Print(self.T("FIND_NONE")) end
end

function BB:ScheduleSnapshot(delay)
  if not self:IsBank() then return end
  self:After(delay or 3, function() BB:UpdateSnapshot(true, true) end, "snapshot")
end

-- Bestand an diesem Char (Taschen + Bank, Bank nur live wenn offen, sonst Cache)
function BB:LocalCount(id)
  local c = 0
  local bags = self:ScanContainers(BB.BAG_LIST)
  if bags[id] then c = c + bags[id].c end
  local bank
  if self.bankOpen then
    bank = self:ScanContainers(BB.BANK_LIST)
  else
    bank = BananaBankDB.bankCache[self:Me()] or {}
  end
  if bank[id] then c = c + bank[id].c end
  return c
end

-- ------------------------------------------------------------
-- Anfrage bestaetigen / ablehnen
-- ------------------------------------------------------------
function BB:Notify(r, key)
  if BananaBankDB.whisper == false then return end
  if not r or r.p == self:Me() then return end
  SendChatMessage(string.format(self.T(key), r.id), "WHISPER", nil, r.p)
end

-- Wie viele Anfragen warten auf die Bestaetigung?
function BB:OpenRequestCount()
  local n = 0
  for _, r in pairs(BananaBankDB.reqs) do
    if self:ReqState(r) == "open" then n = n + 1 end
  end
  return n
end

-- Alle offenen Anfragen mit einem Klick bestaetigen (aelteste zuerst). Mit Gildencrafter-Anspruch wird er
-- geprueft und akzeptiert; was die Regeln nicht erlauben, bleibt offen und steht im Chat.
function BB:ConfirmAll()
  if not self:BankActive() then
    self:Print("|cffff4040" .. string.format(self.T("ERR_RANK_LOST"), BB.BANK_RANK_LABEL) .. "|r")
    return 0, 0
  end
  local list = {}
  for _, r in pairs(BananaBankDB.reqs) do
    if self:ReqState(r) == "open" then table.insert(list, r) end
  end
  table.sort(list, function(a, b)
    if (a.ts or 0) ~= (b.ts or 0) then return (a.ts or 0) < (b.ts or 0) end
    return a.id < b.id
  end)
  local ok, left = 0, 0
  for i = 1, getn(list) do
    local r = list[i]
    if r.cl and next(r.cl) ~= nil then self:AcceptCrafter(r) else self:ConfirmRequest(r) end
    if r.s == "confirmed" then ok = ok + 1 else left = left + 1 end
  end
  self:Print(string.format(self.T("MSG_CONFIRM_ALL"), ok, left))
  if self.UI then self.UI:Refresh() end
  return ok, left
end

-- Uebersicht vor dem Versand: alle vorbereiteten Anfragen mit Items, Nachnahme und Hinweisen untereinander
function BB:SendOverview()
  local preps = {}
  if self.prep then table.insert(preps, self.prep) end
  for i = 1, getn(self.queue or {}) do table.insert(preps, self.queue[i]) end
  local lines = {}
  local totalCod, totalLetters = 0, 0
  for i = 1, getn(preps) do
    local p = preps[i]
    local r = p.r
    local agg, order = {}, {}
    local cod, stacks = 0, 0
    for k = p.idx, getn(p.slots) do
      local e = p.slots[k]
      local a = agg[e.id]
      if not a then a = { c = 0, cod = 0 } agg[e.id] = a table.insert(order, e.id) end
      a.c = a.c + e.c
      local c = self:MailCod(e, r)
      a.cod = a.cod + c
      cod = cod + c
      stacks = stacks + 1
    end
    local letters = math.ceil(stacks / self:MailSlots())
    totalCod = totalCod + cod
    totalLetters = totalLetters + letters
    table.insert(lines, { kind = "head", l = r.id .. "  " .. r.p, r = cod > 0 and BB.Money(cod) or self.T("OV_FREE"),
      sub = string.format(self.T("OV_LETTERS"), letters) })
    table.sort(order)
    for j = 1, getn(order) do
      local id = order[j]
      local a = agg[id]
      local u = self:GetPrice(id)
      local name = self:ColoredName(id)
      local left = a.c .. "x " .. name
      if u and a.cod > 0 then left = left .. "  |cff888888" .. string.format(self.T("OV_EACH"), BB.Money(u)) .. "|r" end
      table.insert(lines, { kind = "item", l = left, r = a.cod > 0 and BB.Money(a.cod) or "-" })
    end
    if p.short and next(p.short) then
      table.insert(lines, { kind = "warn", l = string.format(self.T("OV_SHORT"), self:ShortList(p.short)) })
    end
    local elseMiss = {}
    for id, n in pairs(p.missing or {}) do
      if n > 0 and not (p.short and p.short[id]) then elseMiss[id] = n end
    end
    if next(elseMiss) then
      table.insert(lines, { kind = "warn", l = string.format(self.T("OV_ELSE"), self:ShortList(elseMiss)) })
    end
  end
  return lines, getn(preps), totalLetters, totalCod
end

-- Gildencrafter: die Bank prueft, was sie sehen kann (Rang, Keyword, Beruf des Rezepts, noch nicht erhalten),
-- setzt bei den beanspruchten Rezepten den Preis auf 0 und bestaetigt die Anfrage.
function BB:AcceptCrafter(r)
  if not self:BankActive() then
    self:Print("|cffff4040" .. string.format(self.T("ERR_RANK_LOST"), BB.BANK_RANK_LABEL) .. "|r")
    return
  end
  if not r or r.s ~= "open" then return end
  -- nur Rezepte, die der Spieler selbst beansprucht hat (seine Pruefung findet auf seinem Client statt)
  if not r.cl or next(r.cl) == nil then return end
  local ok, bad = self:CheckRequestRules(r)
  if not ok then
    if bad[1] and bad[1].why == "UNKNOWN" then self:RequestRoster() end
    self:Print("|cffff4040" .. string.format(self.T("RB_REFUSED"), r.id, r.p) .. "|r")
    for i = 1, getn(bad) do
      local line = bad[i].text
      if bad[i].id then line = self:ColoredName(bad[i].id) .. ": " .. line end
      self:Print("|cffff9a2e" .. line .. "|r")
    end
    return
  end
  local problems = {}
  for id in pairs(r.cl) do
    if r.items[id] then
      local ok2, why = self:VerifyClaim(r.p, id)
      if not ok2 then table.insert(problems, self:ColoredName(id) .. ": " .. why) end
    end
  end
  if getn(problems) > 0 then
    self:Print("|cffff4040" .. string.format(self.T("CR_B_REFUSED"), r.id, r.p) .. "|r")
    for i = 1, getn(problems) do self:Print("|cffff9a2e" .. problems[i] .. "|r") end
    self:Print(self.T("CR_B_HINT"))
    return
  end
  r.fr = {}
  for id in pairs(r.cl) do
    if r.items[id] then r.fr[id] = 1 end
  end
  self:SetStatus(r, "confirmed")
  self:Print(string.format(self.T("CR_B_ACCEPTED"), r.id, r.p))
  self:Notify(r, "WHISPER_CONFIRMED")
end

-- Nachnahme dieser Anfrage: jetzt (ohne bereits freie Rezepte) und nach dem Akzeptieren der beanspruchten Rezepte
function BB:RequestCodTotals(r)
  local now, after = 0, 0
  if BananaBankDB.cod == false then return 0, 0 end
  if r.qid then return 0, 0 end
  for id, n in pairs(r.items) do
    local u = self:GetPrice(id) or 0
    -- was nicht lieferbar ist, kostet nichts
    n = n - self:ProjectedShort(r, id)
    if n < 0 then n = 0 end
    -- ein Gildencrafter-Anspruch gilt fuer genau ein Exemplar, jedes weitere kostet normal
    local left = n - 1
    if left < 0 then left = 0 end
    if r.fr and r.fr[id] then
      now = now + u * left
      after = after + u * left
    else
      now = now + u * n
      if r.cl and r.cl[id] then after = after + u * left else after = after + u * n end
    end
  end
  return now, after
end

-- Nachnahme des naechsten Briefs (so viele Stapel, wie der Client in einen Brief laesst)
function BB:LetterCod(p)
  if not p or not p.slots then return 0 end
  local last = p.idx + self:MailSlots() - 1
  if last > table.getn(p.slots) then last = table.getn(p.slots) end
  local sum = 0
  for k = p.idx, last do
    if p.slots[k] then sum = sum + self:MailCod(p.slots[k], p.r) end
  end
  return sum
end

-- Was steht gerade im Senden-Fenster als Nachnahme? 0, wenn der Brief keine Nachnahme ist oder das Fenster fehlt
function BB:EnteredCod()
  if not (SendMailMoney and MoneyInputFrame_GetCopper) then return nil end
  local ok, c = pcall(MoneyInputFrame_GetCopper, SendMailMoney)
  if not ok then return nil end
  if SendMailCODButton and SendMailCODButton.GetChecked and not SendMailCODButton:GetChecked() then return 0 end
  return c or 0
end

function BB:ConfirmRequest(r)
  if not self:BankActive() then
    self:Print("|cffff4040" .. string.format(self.T("ERR_RANK_LOST"), BB.BANK_RANK_LABEL) .. "|r")
    return
  end
  if not r or r.s ~= "open" then return end
  -- Regelsatz: die Bank prueft Rang und Qualitaet noch einmal (aeltere oder veraenderte Clients umgehen das Fenster)
  local ok, bad = self:CheckRequestRules(r)
  if not ok then
    if bad[1] and bad[1].why == "UNKNOWN" then self:RequestRoster() end
    self:Print("|cffff4040" .. string.format(self.T("RB_REFUSED"), r.id, r.p) .. "|r")
    for i = 1, getn(bad) do
      local line = bad[i].text
      if bad[i].id then line = self:ColoredName(bad[i].id) .. ": " .. line end
      self:Print("|cffff9a2e" .. line .. "|r")
    end
    return
  end
  self:SetStatus(r, "confirmed")
  self:Print(string.format(self.T("MSG_CONFIRMED"), r.id, r.p))
  self:Notify(r, "WHISPER_CONFIRMED")
end

function BB:RejectRequest(r)
  if not r then return end
  local st = self:ReqState(r)
  if st ~= "open" and st ~= "confirmed" and st ~= "expired" then return end
  if self.prep and self.prep.r == r then self.prep = nil end
  if self.job and self.job.r == r then self.job = nil end
  self:SetStatus(r, "rejected")
  self:Print(string.format(self.T("MSG_REJECTED"), r.id))
  self:Notify(r, "WHISPER_REJECTED")
end

-- ------------------------------------------------------------
-- Items holen: exakte Stapel in die Taschen legen (fuer je einen Brief)
-- ------------------------------------------------------------
local function slotKey(bag, slot) return bag .. ":" .. slot end

local function findEmptyBagSlot(used)
  for _, bag in ipairs(BB.BAG_LIST) do
    local n = GetContainerNumSlots(bag) or 0
    for slot = 1, n do
      if not GetContainerItemLink(bag, slot) and not used[slotKey(bag, slot)] then
        return bag, slot
      end
    end
  end
end

local function findStack(bags, id, used)
  local bestBag, bestSlot, bestCount
  for _, bag in ipairs(bags) do
    local n = GetContainerNumSlots(bag) or 0
    for slot = 1, n do
      if not used[slotKey(bag, slot)] then
        local link = GetContainerItemLink(bag, slot)
        if link then
          local lid = BB.ParseLink(link)
          if lid == id then
            local _, count, locked = GetContainerItemInfo(bag, slot)
            if not locked then
              -- groessten Stapel zuerst: weniger Briefe
              if not bestCount or (count or 1) > bestCount then
                bestBag, bestSlot, bestCount = bag, slot, (count or 1)
              end
            end
          end
        end
      end
    end
  end
  return bestBag, bestSlot, bestCount
end

-- Teilstapel desselben Items in den Taschen zu vollen Stapeln zusammenlegen (ein Zug je Aufruf).
-- true = es wurde gezogen oder ein Fach ist noch gesperrt, kurz warten und nochmal pruefen
local function consolidate(id, used)
  local _, _, _, _, _, _, stack = GetItemInfo(id)
  if not stack or stack <= 1 then return false end
  local parts = {}
  for _, bag in ipairs(BB.BAG_LIST) do
    for slot = 1, (GetContainerNumSlots(bag) or 0) do
      if not used[slotKey(bag, slot)] then
        local link = GetContainerItemLink(bag, slot)
        if link and BB.ParseLink(link) == id then
          local _, count, locked = GetContainerItemInfo(bag, slot)
          if locked then return true end
          if (count or 1) < stack then table.insert(parts, { bag = bag, slot = slot, c = count or 1 }) end
        end
      end
    end
  end
  if getn(parts) < 2 then return false end
  table.sort(parts, function(a, b) return a.c > b.c end)
  local target, src = parts[1], parts[getn(parts)]
  if CursorHasItem() then ClearCursor() end
  PickupContainerItem(src.bag, src.slot)
  PickupContainerItem(target.bag, target.slot)
  if CursorHasItem() then ClearCursor() end
  return true
end
BB.Consolidate = consolidate

function BB:StartPrepare(r)
  if not self:BankActive() then
    self:Print("|cffff4040" .. string.format(self.T("ERR_RANK_LOST"), BB.BANK_RANK_LABEL) .. "|r")
    return
  end
  if not r or r.s ~= "confirmed" then
    self:Print(self.T("ERR_NOT_CONFIRMED"))
    return
  end
  local need = {}
  for id, n in pairs(r.items) do
    local left = self:ReqLeft(r, id)
    if left > 0 then need[id] = left end
  end
  if BB.Count(need) == 0 then
    self:Print(self.T("MSG_NOTHING_LEFT"))
    return
  end
  self.prep = nil
  -- ein einzelnes Holen verwirft eine alte Sammelrunde (ausser beim automatischen Neuvorbereiten)
  if not self.batch and not self.reprep then self.queue = nil end
  self.job = { r = r, need = need, slots = {}, missing = {} }
  if not self.batch then self:Print(string.format(self.T("MSG_PREPARING"), r.id)) end
  self:PrepareStep()
end

-- ------------------------------------------------------------
-- Sammelrunde: alle bestaetigten Anfragen auf einmal aus der Bank holen und danach am Briefkasten
-- hintereinander versenden (ein Weg zur Bank, ein Weg zum Briefkasten)
-- ------------------------------------------------------------
function BB:BatchOn()
  return BananaBankDB.batch ~= false
end

-- Holen je nach Einstellung: alle Anfragen oder nur diese
function BB:FetchFor(r)
  if self:BatchOn() then self:StartPrepareAll(r) else self:StartPrepare(r) end
end

function BB:StartPrepareAll(first)
  if not self:BankActive() then
    self:Print("|cffff4040" .. string.format(self.T("ERR_RANK_LOST"), BB.BANK_RANK_LABEL) .. "|r")
    return
  end
  if self.job then return end
  local list = {}
  for _, r in pairs(BananaBankDB.reqs) do
    if r.s == "confirmed" and self:IsActive(r) then
      local left = 0
      for id in pairs(r.items) do left = left + self:ReqLeft(r, id) end
      if left > 0 then table.insert(list, r) end
    end
  end
  if getn(list) == 0 then
    self:Print(self.T("MSG_NOTHING_LEFT"))
    return
  end
  table.sort(list, function(a, b)
    if first then
      if a == first then return true end
      if b == first then return false end
    end
    if (a.ts or 0) ~= (b.ts or 0) then return (a.ts or 0) < (b.ts or 0) end
    return a.id < b.id
  end)
  self.queue = nil
  self.prep = nil
  self.batch = { list = list, idx = 0, preps = {} }
  self:Print(string.format(self.T("MSG_BATCH_START"), getn(list)))
  self:BatchNext()
end

function BB:BatchNext()
  local b = self.batch
  if not b then return end
  b.idx = b.idx + 1
  local r = b.list[b.idx]
  if not r then return self:BatchFinish() end
  local mine = b.idx
  self:StartPrepare(r)
  -- ohne Job (Fehler beim Start) mit der naechsten Anfrage weitermachen; lief die Vorbereitung schon
  -- zu Ende, ist der Index weiter und hier nichts mehr zu tun
  if not self.job and self.batch == b and b.idx == mine then return self:BatchNext() end
end

function BB:BatchFinish()
  local b = self.batch
  self.batch = nil
  self.job = nil
  if not b then return end
  local preps = b.preps
  if getn(preps) == 0 then
    self:Print("|cffff4040" .. self.T("ERR_NOTHING_PREPARED") .. "|r")
    if self.UI then self.UI:Refresh() end
    return
  end
  local stacks = 0
  for i = 1, getn(preps) do stacks = stacks + getn(preps[i].slots) end
  self.prep = table.remove(preps, 1)
  self.queue = getn(preps) > 0 and preps or nil
  self:Print(string.format(self.T("MSG_BATCH_DONE"), getn(preps) + 1, stacks))
  if self.UI then
    self.UI:Refresh()
    if self.UI.OpenSendOverview then self.UI:OpenSendOverview() end
  end
end

function BB:PrepareFail(key)
  self.job = nil
  self.reprep = nil
  if self.batch then
    -- Sammelrunde: mit dem weitermachen, was schon in den Taschen liegt
    self:Print("|cffff4040" .. self.T(key) .. "|r")
    return self:BatchFinish()
  end
  self:Print("|cffff4040" .. self.T(key) .. "|r")
  if self.UI then self.UI:Refresh() end
end

function BB:PrepareStep()
  local job = self.job
  if not job then return end
  if CursorHasItem() then ClearCursor() end

  local used = {}
  -- Stapel, die schon fuer andere Anfragen der Sammelrunde vorgesehen sind
  local function markUsed(p)
    for k = 1, getn(p.slots) do used[slotKey(p.slots[k].bag, p.slots[k].slot)] = true end
  end
  if self.batch then for i = 1, getn(self.batch.preps) do markUsed(self.batch.preps[i]) end end
  if self.queue then for i = 1, getn(self.queue) do markUsed(self.queue[i]) end end
  for i = 1, getn(job.slots) do
    local s = job.slots[i]
    used[slotKey(s.bag, s.slot)] = true
    local _, count, locked = GetContainerItemInfo(s.bag, s.slot)
    if locked then
      self:After(0.3, function() BB:PrepareStep() end, "prep")
      return
    end
    if s.pending then
      local lid = BB.ParseLink(GetContainerItemLink(s.bag, s.slot))
      if lid ~= s.id or count ~= s.c then
        if (s.tries or 0) < 8 then
          s.tries = (s.tries or 0) + 1
          self:After(0.4, function() BB:PrepareStep() end, "prep")
          return
        end
        return self:PrepareFail("ERR_MOVE_FAILED")
      end
      s.pending = nil
    end
  end

  local id, need
  for nid, n in pairs(job.need) do
    if n > 0 then
      id, need = nid, n
      break
    end
  end
  if not id then return self:PrepareDone() end

  -- Teilstapel in den Taschen erst zu vollen Stapeln zusammenlegen: weniger Briefe, stabile Faecher
  job.cons = job.cons or {}
  if (job.cons[id] or 0) < 12 and consolidate(id, used) then
    job.cons[id] = (job.cons[id] or 0) + 1
    self:After(0.5, function() BB:PrepareStep() end, "prep")
    return
  end

  -- 1. Taschen des Bank-Chars
  local bag, slot, count = findStack(BB.BAG_LIST, id, used)
  if bag then
    if count <= need then
      table.insert(job.slots, { bag = bag, slot = slot, id = id, c = count })
      job.need[id] = need - count
      self:After(0.05, function() BB:PrepareStep() end, "prep")
    else
      local eb, es = findEmptyBagSlot(used)
      if not eb then return self:PrepareFail("ERR_BAGS_FULL") end
      SplitContainerItem(bag, slot, need)
      PickupContainerItem(eb, es)
      table.insert(job.slots, { bag = eb, slot = es, id = id, c = need, pending = true })
      job.need[id] = 0
      self:After(0.5, function() BB:PrepareStep() end, "prep")
    end
    return
  end

  -- 2. Bankfaecher (nur bei geoeffneter Bank)
  if self.bankOpen then
    bag, slot, count = findStack(BB.BANK_LIST, id, used)
    if bag then
      local eb, es = findEmptyBagSlot(used)
      if not eb then return self:PrepareFail("ERR_BAGS_FULL") end
      local take = count
      if count > need then
        take = need
        SplitContainerItem(bag, slot, need)
      else
        PickupContainerItem(bag, slot)
      end
      PickupContainerItem(eb, es)
      table.insert(job.slots, { bag = eb, slot = es, id = id, c = take, pending = true })
      job.need[id] = need - take
      self:After(0.5, function() BB:PrepareStep() end, "prep")
      return
    end
  end

  -- 3. nicht (mehr) vorhanden
  job.missing[id] = need
  job.need[id] = 0
  self:After(0.05, function() BB:PrepareStep() end, "prep")
end

-- Liegt dieses Item (noch) auf einer anderen Bank?
function BB:OtherBankHas(id)
  local me = self:Me()
  local depots = (self.DepotChars and self:DepotChars()) or {}
  for bank, snap in pairs(BananaBankDB.snaps) do
    if bank ~= me and self:MayBeBank(bank) and not depots[bank] then
      local it = snap.items and snap.items[id]
      if it and (it.c or 0) > 0 then return true end
    end
  end
  return false
end

-- "36x Mageweave Cloth, 2x ..." fuer Meldung und Brief
function BB:ShortList(short)
  local parts = {}
  for id, n in pairs(short) do table.insert(parts, n .. "x " .. (self:ItemInfo(id) or "?")) end
  table.sort(parts)
  local text = table.concat(parts, ", ")
  if string.len(text) > 90 then text = string.sub(text, 1, 87) .. "..." end
  return text
end

-- Hinweis im letzten Brief einer Unterlieferung, deutsch und englisch (die Sprache des Empfaengers ist unbekannt)
function BB:ShortNote(short)
  local list = self:ShortList(short)
  return string.format(BB.L.deDE.MAIL_SHORT, list) .. "\n\n" .. string.format(BB.L.enUS.MAIL_SHORT, list)
end

function BB:PrepareDone()
  local job = self.job
  self.job = nil
  if not job then return end
  if BB.Count(job.missing) > 0 then
    for id, n in pairs(job.missing) do
      self:Print(string.format(self.T("MSG_MISSING"), n, self:ColoredName(id)))
    end
    if not self.bankOpen then self:Print(self.T("MSG_OPEN_BANK_FOR_REST")) end
  end
  if getn(job.slots) == 0 then
    -- in der Sammelrunde ist "hier nichts zu holen" nur fuer diese Anfrage so
    if self.batch then return self:BatchNext() end
    self:Print("|cffff4040" .. self.T("ERR_NOTHING_PREPARED") .. "|r")
    if self.UI then self.UI:Refresh() end
    return
  end
  -- was auf keiner anderen Bank liegt, kann nicht mehr kommen (Bestandsdifferenz): wird mit dem letzten Brief abgeschrieben
  local short = {}
  for id, n in pairs(job.missing) do
    if n > 0 and not self:OtherBankHas(id) then short[id] = n end
  end
  local newPrep = { r = job.r, slots = job.slots, idx = 1, missing = job.missing, short = next(short) and short or nil }
  if self.batch then
    table.insert(self.batch.preps, newPrep)
    return self:BatchNext()
  end
  self.prep = newPrep
  self:Print(string.format(self.T("MSG_PREPARED"), getn(job.slots), job.r.p))
  -- nach einer automatischen Neuvorbereitung (Faecher hatten sich veraendert) gleich weiter senden
  if self.reprep then
    self.reprep = nil
    if self.mailOpen then self:After(0.8, function() BB:SendNextMail() end, "reprepsend") end
  end
  if self.UI then self.UI:Refresh() end
end

-- ------------------------------------------------------------
-- Postversand: ein Stapel pro Brief (Vanilla erlaubt nur einen Anhang)
-- ------------------------------------------------------------
function BB:MailCod(e, r)
  if BananaBankDB.cod == false then return 0 end
  if not SetSendMailCOD then return 0 end
  r = r or (self.prep and self.prep.r)
  -- Quest-Auszahlung (Material zum Verarbeiten, kommt als Ware zurueck): nie Nachnahme
  if r and r.qid then return 0 end
  -- von der Bank als Gildencrafter akzeptiert: dieses Rezept ist kostenlos
  local u = self:GetPrice(e.id)
  if not u or u <= 0 then return 0 end
  local free = 0
  if r and r.fr and r.fr[e.id] then
    -- genau ein Exemplar ist frei: der erste Stapel dieses Items im Versand
    local used = 0
    local p = self.prep
    if p and p.r == r then
      for k = 1, table.getn(p.slots) do
        local s = p.slots[k]
        if s == e then break end
        if s.id == e.id then used = used + s.c end
      end
    end
    free = 1 - used
    if free < 0 then free = 0 end
    if free > e.c then free = e.c end
  end
  return u * (e.c - free)
end

-- Wie viele Anhaenge nimmt dieser Client? Vanilla kann einen, OctoWoW
-- und aehnliche Clients mehrere.
function BB:MailSlots()
  if self.mailSlots then return self.mailSlots end
  local n = 0
  for i = 1, 12 do
    if getglobal("SendMailItemButton" .. i) then n = i else break end
  end
  -- Frame noch nicht da: vorerst einen Anhang annehmen, aber nicht merken
  if n < 1 then return 1 end
  self.mailSlots = n
  return n
end

local function tryClick(index)
  if not ClickSendMailItemButton then return end
  if index then
    pcall(ClickSendMailItemButton, index)
  else
    pcall(ClickSendMailItemButton)
  end
  if CursorHasItem() then
    local btn = getglobal("SendMailItemButton" .. (index or 1))
    if btn and btn.Click then pcall(function() btn:Click() end) end
  end
end

-- Ist am Brief schon etwas angehaengt? (Antwort des Clients, nicht nur der Cursor)
local function mailHasAttachment(index)
  if not GetSendMailItem then return nil end
  local ok, name = pcall(GetSendMailItem, index)
  if ok and name and name ~= "" then return true end
  if index then
    ok, name = pcall(GetSendMailItem)
    if ok and name and name ~= "" then return true end
  end
  return false
end

-- Ersetzt TurtleMail das Sendefenster? Dann gehen Anhaenge und Senden ueber dessen eigene Funktionen.
function BB:TurtleMailActive()
  return type(TurtleMail) == "table" and type(TurtleMail.send_mail_button_onclick) == "function"
    and type(TurtleMail.sendmail_attached) == "function"
end

-- Zustand des Postfensters fuer die Fehlersuche
function BB:MailDebugInfo()
  local function vis(f) local fr = getglobal(f) if not fr then return "-" end return fr:IsVisible() and "ja" or "nein" end
  local slots = 0
  for i = 1, 12 do if getglobal("SendMailItemButton" .. i) then slots = i else break end end
  local lines = {
    "SendMailFrame sichtbar: " .. vis("SendMailFrame"),
    "SendMailItemButton-Felder: " .. slots,
    "ClickSendMailItemButton: " .. (ClickSendMailItemButton and "ja" or "nein"),
    "GetSendMailItem: " .. (GetSendMailItem and "ja" or "nein"),
    "TurtleMail geladen: " .. ((TurtleMail or getglobal("TurtleMailFrame")) and "ja" or "nein"),
    "Cursor haelt Item: " .. (CursorHasItem() and "ja" or "nein"),
    "TurtleMail-Sendefunktion: " .. (self:TurtleMailActive() and "ja" or "nein"),
  }
  if GetSendMailItem then
    local ok, a1, a2, a3 = pcall(GetSendMailItem, 1)
    table.insert(lines, "GetSendMailItem(1): " .. tostring(ok) .. ", " .. tostring(a1) .. ", " .. tostring(a2) .. ", " .. tostring(a3))
    local ok2, b1 = pcall(GetSendMailItem)
    table.insert(lines, "GetSendMailItem(): " .. tostring(ok2) .. ", " .. tostring(b1))
  end
  return lines
end

-- haengt einen Stapel an. Gibt false zurueck, wenn der Client ihn nicht nimmt;
-- das Item liegt dann wieder in seinem Fach.
function BB:AttachItem(e, index, stage)
  if CursorHasItem() then ClearCursor() end
  if stage ~= 2 and ClickSendMailItemButton then
    PickupContainerItem(e.bag, e.slot)
    if not CursorHasItem() then return false end
    -- genau ein Klick: manche Fenster uebernehmen den Anhang erst einen Moment spaeter
    -- (der Cursor bleibt kurz belegt), ein zweiter Klick haengt ihn doppelt an
    if self:MailSlots() > 1 then pcall(ClickSendMailItemButton, index) else pcall(ClickSendMailItemButton) end
    if not CursorHasItem() and mailHasAttachment(index) ~= false then return true end
    return "wait"
  end
  -- zweiter Weg: Rechtsklick auf das Item haengt es an, wenn der Reiter Senden offen ist
  -- (nur dann, sonst wuerde das Item benutzt)
  local sf = getglobal("SendMailFrame")
  if UseContainerItem and sf and sf:IsVisible() then
    pcall(UseContainerItem, e.bag, e.slot)
    if CursorHasItem() then ClearCursor() end
    if self:AttachedNow(e, index) then return true end
    return "wait"
  end
  return false
end

-- Liegt dieser Stapel im Brief? Antwort des Clients; Sperre oder leeres Fach zaehlen nur,
-- wenn das Item nicht auf dem Cursor haengt
function BB:AttachedNow(e, index)
  -- TurtleMail haelt die Anhaenge in einer eigenen Liste; GetSendMailItem sieht sie nicht
  if self:TurtleMailActive() then
    local ok, r = pcall(TurtleMail.sendmail_attached, e.bag, e.slot)
    return ok and r and true or false
  end
  if mailHasAttachment(index) then return true end
  if CursorHasItem() then return false end
  local link = GetContainerItemLink(e.bag, e.slot)
  if not link then return true end
  local _, _, locked = GetContainerItemInfo(e.bag, e.slot)
  if locked then return true end
  return false
end

function BB:ClearAttachments()
  if not ClickSendMailItemButton then return end
  for i = 1, self:MailSlots() do
    tryClick(self:MailSlots() > 1 and i or nil)
    if CursorHasItem() then ClearCursor() end
  end
end

function BB:SendNextMail()
  local p = self.prep
  if not p then return end
  if not self.mailOpen then
    self:Print(self.T("ERR_NO_MAILBOX"))
    return
  end
  if p.sending then return end
  local e = p.slots[p.idx]
  if not e then return self:MailDone() end

  local lid = BB.ParseLink(GetContainerItemLink(e.bag, e.slot))
  local _, count = GetContainerItemInfo(e.bag, e.slot)
  if lid ~= e.id or count ~= e.c then
    local r = p.r
    self.prep = nil
    -- Taschen veraendert (z. B. Stapel zusammengelegt): den Rest automatisch neu vorbereiten, hoechstens 3 Mal
    if (self.repCount or 0) < 3 and r and r.s == "confirmed" and self:BankActive() then
      self.repCount = (self.repCount or 0) + 1
      self.reprep = true
      self:Print(self.T("MSG_REPREP"))
      self:StartPrepare(r)
      if not self.job then self.reprep = nil end
    else
      self:Print("|cffff4040" .. self.T("ERR_SLOT_CHANGED") .. "|r")
    end
    if self.UI then self.UI:Refresh() end
    return
  end
  if GetMoney() < 30 then
    self:Print("|cffff4040" .. self.T("ERR_NO_POSTAGE") .. "|r")
    return
  end

  -- Schritt 1: auf den Reiter Senden wechseln. Der Client nimmt einen Anhang
  -- erst an, wenn dieser Reiter offen ist, und braucht dafuer einen Moment.
  if MailFrameTab_OnClick then pcall(MailFrameTab_OnClick, 2) end
  p.sending = true
  self:After(0.3, function() BB:SendMailStep2() end, "mailstep")
end

function BB:SendMailStep2()
  local p = self.prep
  if not p or not p.sending then return end
  local e = p.slots[p.idx]
  if not e then
    p.sending = false
    return self:MailDone()
  end

  p.stage2 = nil
  -- so viele Stapel wie der Client erlaubt in einen Brief
  local slots = self:MailSlots()
  local batch = {}
  local wait = false
  local last = p.idx + slots - 1
  if last > table.getn(p.slots) then last = table.getn(p.slots) end
  for k = p.idx, last do
    local r = self:AttachItem(p.slots[k], table.getn(batch) + 1)
    if r then
      table.insert(batch, k)
      if r == "wait" then wait = true break end
    else
      break
    end
  end

  if table.getn(batch) == 0 then return self:AttachFailed() end
  p.batch = batch
  if wait then
    -- zweiter Weg (Rechtsklick): Anhang kurz spaeter pruefen, dann senden
    self:After(0.5, function() BB:SendMailVerify() end, "mailverify")
    return
  end
  self:SendMailFinish()
end

function BB:AttachFailed()
  local p = self.prep
  if p then p.sending = false end
  self:Cancel("automail")
  self:Print("|cffff4040" .. self.T("ERR_ATTACH_FAILED") .. "|r")
  local info = self:MailDebugInfo()
  for i = 1, table.getn(info) do self:Print("|cff9a9cb3" .. info[i] .. "|r") end
  if self.UI then self.UI:Refresh() end
end

function BB:SendMailVerify()
  local p = self.prep
  if not p or not p.sending or not p.batch then return end
  local missing = {}
  for i = 1, table.getn(p.batch) do
    local ok = self:AttachedNow(p.slots[p.batch[i]], i)
    -- erster Weg: ist der Cursor nach dem Klick leer, hat das Fenster das Item genommen, auch wenn es
    -- sich per Abfrage nicht meldet (manche Fenster beantworten GetSendMailItem nicht)
    if not ok and not p.stage2 and not CursorHasItem() and not self:TurtleMailActive() then ok = true end
    if not ok then table.insert(missing, i) end
  end
  if table.getn(missing) == 0 then return self:SendMailFinish() end
  -- erster Weg hat nicht gegriffen: Cursor frei machen und einmal den Rechtsklick-Weg versuchen
  if not p.stage2 then
    p.stage2 = true
    if CursorHasItem() then ClearCursor() end
    for j = 1, table.getn(missing) do
      local i = missing[j]
      if not self:AttachItem(p.slots[p.batch[i]], i, 2) then
        p.batch = nil
        return self:AttachFailed()
      end
    end
    self:After(0.5, function() BB:SendMailVerify() end, "mailverify")
    return
  end
  p.batch = nil
  if CursorHasItem() then ClearCursor() end
  self:AttachFailed()
end

function BB:SendMailFinish()
  local p = self.prep
  if not p or not p.sending or not p.batch then return end
  p.stage2 = nil
  local batch = p.batch
  local cod = 0
  for i = 1, table.getn(batch) do
    local e = p.slots[batch[i]]
    e.cod = self:MailCod(e)   -- Preis jetzt festhalten, spaetere Preisaenderungen zaehlen nicht
    cod = cod + e.cod
  end
  p.cod = cod
  p.subject = "BananaBank " .. p.r.id .. " (" .. p.idx .. "/" .. table.getn(p.slots) .. ")"
  local body = string.format(self.T("MAIL_BODY"), p.r.id)
  -- letzter Brief einer Unterlieferung: Hinweis zur Bestandsdifferenz anhaengen
  if p.short and batch[table.getn(batch)] >= table.getn(p.slots) then
    body = string.sub(body .. "\n\n" .. self:ShortNote(p.short), 1, 500)
  end
  if SendMailNameEditBox then
    -- TurtleMail ueberschreibt SetText und ignoriert es, solange es sich einen Empfaenger gemerkt hat
    if SendMailNameEditBox._SetText then SendMailNameEditBox:_SetText(p.r.p) else SendMailNameEditBox:SetText(p.r.p) end
  end
  if SendMailSubjectEditBox then SendMailSubjectEditBox:SetText(p.subject) end
  if SendMailBodyEditBox then SendMailBodyEditBox:SetText(body) end
  -- TurtleMail: seine Senden-Funktion verschickt die Anhaenge aus der eigenen Liste. Die Funktion des
  -- Standardfensters wuerde einen Brief ohne Anhang schicken.
  if self:TurtleMailActive() and SendMailMoney and MoneyInputFrame_SetCopper then
    pcall(MoneyInputFrame_SetCopper, SendMailMoney, cod)
    if SendMailRadioButton_OnClick then pcall(SendMailRadioButton_OnClick, cod > 0 and 2 or 1) end
    if pcall(TurtleMail.send_mail_button_onclick) then return end
  end
  -- Wie von Hand: Nachnahme ins Betragsfeld, Modus waehlen, dann die Senden-Funktion des Fensters benutzen.
  -- Ersetzt ein anderes Post-Addon das Fenster, haengt es sich dort ein; der direkte Aufruf umgeht es.
  if SendMailFrame_SendMail and SendMailMoney and MoneyInputFrame_SetCopper then
    pcall(MoneyInputFrame_SetCopper, SendMailMoney, cod)
    if SendMailRadioButton_OnClick then pcall(SendMailRadioButton_OnClick, cod > 0 and 2 or 1) end
    if pcall(SendMailFrame_SendMail) then return end
  end
  if SetSendMailCOD then pcall(SetSendMailCOD, cod) end
  SendMail(p.r.p, p.subject, body)
end

-- Von Hand verschickte Post an den Anfragenden zaehlt auf die bestaetigte Anfrage: beim Absenden die Anhaenge merken,
-- beim Erfolg buchen. Briefe des Addons selbst laufen ueber den eigenen Ablauf.
function BB:HookSend()
  if self.sendHooked or not SendMail then return end
  self.sendHooked = true
  local orig = SendMail
  SendMail = function(to, subject, body)
    if BB:IsBank() and not (BB.prep and BB.prep.sending) then BB:CaptureManualMail(to) end
    return orig(to, subject, body)
  end
end

function BB:CaptureManualMail(to)
  self.manualMail = nil
  if not GetSendMailItem or not to or to == "" then return end
  local items = {}
  local n = self:MailSlots()
  for i = 1, n do
    local ok, name, _, count
    if n > 1 then ok, name, _, count = pcall(GetSendMailItem, i) else ok, name, _, count = pcall(GetSendMailItem) end
    if ok and name and name ~= "" then
      local id = self:IdByName(name)
      if id and id ~= 0 then items[id] = (items[id] or 0) + (count or 1) end
    end
  end
  if next(items) then self.manualMail = { to = to, items = items, t = GetTime() } end
end

-- Buchen: Menge auf bestaetigte Anfragen dieses Spielers verteilen, Buch-Eintrag, bei Vollstaendigkeit "versendet"
function BB:CreditManualMail(to, items)
  local credited = {}
  local lower = string.lower(to)
  for id, count in pairs(items) do
    for _, r in pairs(BananaBankDB.reqs) do
      if count > 0 and r.s == "confirmed" and string.lower(r.p or "") == lower and r.items[id] then
        local open = self:ReqLeft(r, id)
        if open > 0 then
          local amt = math.min(open, count)
          r.sent = r.sent or {}
          r.sent[id] = (r.sent[id] or 0) + amt
          count = count - amt
          local name, q = self:ItemInfo(id)
          self:AddLedger({ k = "out", p = r.p, i = id, n = name, c = amt, q = q, m = 0, code = r.id })
          credited[r] = true
        end
      end
    end
  end
  for r in pairs(credited) do
    r.u = time()
    if self:RequestComplete(r) then
      self:SetStatus(r, "sent")
      self:Print(string.format(self.T("MSG_REQUEST_DONE"), r.id, r.p))
      self:Notify(r, "WHISPER_SENT")
    else
      self:PushRequests({ r })
      self:Print(string.format(self.T("MSG_MANUAL_CREDIT"), r.id, r.p))
    end
  end
  if next(credited) then
    self:ScheduleSnapshot(2)
    if self.UI then self.UI:Refresh() end
  end
end

function BB:OnManualMailSent()
  local mm = self.manualMail
  self.manualMail = nil
  if mm and GetTime() - mm.t < 60 then self:CreditManualMail(mm.to, mm.items) end
end

-- /bb reissue <Code> [Item] [Anzahl]: eine Anfrage fuer denselben Spieler neu ausloesen (z. B. wenn etwas nicht angekommen ist).
-- Ohne Item alle Items der Anfrage, sonst nur das genannte (Teil des Namens), optional mit Anzahl.
-- Ein Quest-Auszahlungs- oder Gildencrafter-Merkmal der alten Anfrage wird uebernommen (keine Nachnahme).
function BB:Reissue(r, itemText, count)
  if not r then return nil end
  if not self:CanManageQuests() then self:Print("|cffff4040" .. self.T("ERR_NOT_BANK") .. "|r") return nil end
  itemText = string.lower(itemText or "")
  local items = {}
  for id, n in pairs(r.items) do
    local nm = string.lower(self:ItemInfo(id) or "")
    if itemText == "" or string.find(nm, itemText, 1, true) then
      local c = (count and count > 0) and count or n
      items[id] = c
    end
  end
  if next(items) == nil then self:Print(self.T("MSG_REISSUE_NOITEM")) return nil end
  local id = self:NewCodeId()
  while BananaBankDB.reqs[id] do id = self:NewCodeId() end
  local me = self:Me()
  local nr = { id = id, p = r.p, ts = time(), items = items, s = "confirmed", u = time(), by = me, sent = {}, qid = r.qid }
  if r.fr and next(r.fr) then
    nr.fr = {}
    for iid in pairs(items) do if r.fr[iid] then nr.fr[iid] = 1 end end
    if next(nr.fr) == nil then nr.fr = nil end
  end
  nr.code = self:BuildCode(id, r.p, items)
  BananaBankDB.reqs[id] = nr
  self:PushRequests({ nr })
  if r.p ~= me then self:Notify(nr, "WHISPER_CONFIRMED") end
  self:Print(string.format(self.T("MSG_REISSUED"), nr.id, r.p, r.id))
  if self.UI then self.UI:Refresh() end
  return nr
end

-- /bb nocod <Code>: eine bestehende Anfrage ohne Nachnahme verschicken (z. B. eine Quest-Auszahlung, die vor 3.10.3 angelegt wurde)
function BB:SetNoCod(r)
  if not r then return end
  if not self:CanManageQuests() then self:Print("|cffff4040" .. self.T("ERR_NOT_BANK") .. "|r") return end
  r.qid = r.qid or "manual"
  r.u = time()
  r.by = self:Me()
  self:PushRequests({ r })
  self:Print(string.format(self.T("MSG_NOCOD_SET"), r.id))
  if self.UI then self.UI:Refresh() end
end

-- Notfall: alles, was an dieser Anfrage noch offen ist, als versendet buchen (z. B. von Hand verschickt).
-- amount (nur bei einer Anfrage mit einem Item): so viele wurden wirklich verschickt, der Rest wird als
-- Bestandsdifferenz abgeschrieben.
function BB:MarkSent(r, amount)
  if not r or not (r.s == "confirmed") then return end
  r.sent = r.sent or {}
  local n = 0
  for id in pairs(r.items) do
    local left = self:ReqLeft(r, id)
    if left > 0 then
      if amount and amount < left then
        r.sh = r.sh or {}
        r.sh[id] = (r.sh[id] or 0) + (left - amount)
        left = amount
      end
      r.sent[id] = (r.sent[id] or 0) + left
      n = n + left
      local name, q = self:ItemInfo(id)
      self:AddLedger({ k = "out", p = r.p, i = id, n = name, c = left, q = q, m = 0, code = r.id })
    end
  end
  if self.prep and self.prep.r == r then self.prep = nil end
  self:SetStatus(r, "sent")
  self:Print(string.format(self.T("MSG_MARKED_SENT"), r.id, r.p, n))
  self:Notify(r, "WHISPER_SENT")
end

function BB:OnMailSent()
  local p = self.prep
  if not p or not p.sending then return self:OnManualMailSent() end
  p.sending = false
  self.repCount = 0
  local r = p.r
  r.sent = r.sent or {}
  local batch = p.batch or { p.idx }
  for i = 1, table.getn(batch) do
    local e = p.slots[batch[i]]
    if e then
      r.sent[e.id] = (r.sent[e.id] or 0) + e.c
      local name, q = self:ItemInfo(e.id)
      self:AddLedger({ k = "out", p = r.p, i = e.id, n = name, c = e.c, q = q,
        m = e.cod or 0, code = r.id })
    end
  end
  r.u = time()
  p.idx = batch[table.getn(batch)] + 1
  p.batch = nil
  if SetSendMailCOD then pcall(SetSendMailCOD, 0) end
  if p.idx > table.getn(p.slots) then
    self:MailDone()
  elseif BananaBankDB.auto then
    self:After(1.5, function() BB:SendNextMail() end, "automail")
  end
  if self.UI then self.UI:Refresh() end
end

function BB:OnMailFailed()
  local p = self.prep
  if not p or not p.sending then return end
  p.sending = false
  self:Cancel("automail")
  -- haengen die Items noch im Postfenster, zurueck in die Taschen
  local batch = p.batch or { p.idx }
  for i = 1, table.getn(batch) do
    local e = p.slots[batch[i]]
    if e then
      tryClick(self:MailSlots() > 1 and i or nil)
      if CursorHasItem() then
        PickupContainerItem(e.bag, e.slot)
        if CursorHasItem() then ClearCursor() end
      end
    end
  end
  p.batch = nil
  if SetSendMailCOD then pcall(SetSendMailCOD, 0) end
  self:Print("|cffff4040" .. self.T("ERR_MAIL_FAILED") .. "|r")
  if self.UI then self.UI:Refresh() end
end

function BB:MailDone()
  local p = self.prep
  self.prep = nil
  self.repCount = 0
  if not p then return end
  local r = p.r
  -- Unterlieferung: die Differenz abschreiben, damit die Reservierung nicht stehen bleibt
  if p.short then
    r.sh = r.sh or {}
    r.sent = r.sent or {}
    for id, n in pairs(p.short) do
      local left = (r.items[id] or 0) - (r.sent[id] or 0) - (r.sh[id] or 0)
      if left > 0 then r.sh[id] = (r.sh[id] or 0) + math.min(n, left) end
    end
    r.u = time()
    self:Print("|cffff9a2e" .. string.format(self.T("MSG_REQUEST_SHORT"), r.id, self:ShortList(p.short)) .. "|r")
  end
  if self:RequestComplete(r) then
    self:SetStatus(r, "sent")
    self:Print(string.format(self.T("MSG_REQUEST_DONE"), r.id, r.p))
    self:Notify(r, "WHISPER_SENT")
  else
    self:PushRequests({ r })
    self:Print(string.format(self.T("MSG_REQUEST_PARTIAL"), r.id))
  end
  self:ScheduleSnapshot(2)
  -- Sammelrunde: weiter mit der naechsten vorbereiteten Anfrage (Abgeschlossenes oder Abgelehntes ueberspringen)
  local nxt
  while self.queue and getn(self.queue) > 0 and not nxt do
    local cand = table.remove(self.queue, 1)
    if cand.r.s == "confirmed" then nxt = cand end
  end
  if self.queue and getn(self.queue) == 0 then self.queue = nil end
  if nxt then
    self.prep = nxt
    self:Print(string.format(self.T("MSG_BATCH_NEXT"), nxt.r.id, nxt.r.p))
    if BananaBankDB.auto and self.mailOpen then self:After(1.5, function() BB:SendNextMail() end, "automail") end
  end
  if self.UI then self.UI:Refresh() end
end

-- ------------------------------------------------------------
-- Spenden per Post erfassen (Hook auf TakeInboxItem / TakeInboxMoney)
-- ------------------------------------------------------------
BB.SYSTEM_SENDERS = {
  ["Auction House"] = true, ["Auktionshaus"] = true,
  ["The Postmaster"] = true, ["Der Postmeister"] = true, ["Postmaster"] = true,
}

-- Passt die Lieferung in die Taschen? Ein freies Fach oder genug Platz in Teilstapeln desselben Items.
-- (Voller Rucksack heisst nicht, dass der Brief nicht ankommt: das Item kann auf einen Stapel gehen.)
function BB:CanReceive(name, count)
  if self:HasFreeBagSlot() then return true end
  local room = 0
  for _, bag in ipairs(BB.BAG_LIST) do
    for slot = 1, (GetContainerNumSlots(bag) or 0) do
      local link = GetContainerItemLink(bag, slot)
      if link then
        local id, nm = BB.ParseLink(link)
        if nm == name then
          local _, c = GetContainerItemInfo(bag, slot)
          local _, _, _, _, _, _, stack = GetItemInfo(id)
          if stack and c and c < stack then room = room + (stack - c) end
        end
      end
    end
  end
  return room >= (count or 1)
end

function BB:HasFreeBagSlot()
  return findEmptyBagSlot({}) ~= nil
end

function BB:IdByName(name)
  local stock = self.stockCache or self:GetStock()
  for id, e in pairs(stock) do
    if e.n == name then return id end
  end
  return 0
end

local lastTake = { key = "", t = 0 }

-- Protokoll der Post-Entnahmen: jede Entnahme mit Ergebnis, damit nachvollziehbar ist, warum etwas nicht gebucht wurde
function BB:MailLog(sender, isItem, name, count, money, result, note)
  local db = BananaBankDB
  db.maillog = db.maillog or {}
  table.insert(db.maillog, {
    t = time(), p = sender or "?", it = isItem and 1 or 0, n = name or "", c = count or 0, m = money or 0,
    r = result, x = note or "",
  })
  while getn(db.maillog) > 80 do table.remove(db.maillog, 1) end
end

function BB:PrintMailLog(arg)
  local log = BananaBankDB.maillog or {}
  local n = tonumber(arg) or 25
  local from = math.max(1, getn(log) - n + 1)
  if getn(log) == 0 then
    self:Print(self.T(self:IsBank() and "ML_EMPTY" or "ML_NOTBANK"))
    return
  end
  self:Print(string.format(self.T("ML_HEAD"), getn(log) - from + 1, getn(log)))
  for i = from, getn(log) do
    local e = log[i]
    local what
    if e.r == "open" then what = ""
    elseif e.it == 1 then what = e.c .. "x " .. e.n else what = BB.Money(e.m) end
    local line = date("%d.%m. %H:%M:%S", e.t) .. "  " .. e.p .. "  " .. what .. "  -  "
    local col = (e.r == "booked" or e.r == "open") and "|cff80ff80" or "|cffff9a2e"
    line = line .. col .. self.T("ML_" .. string.upper(e.r)) .. "|r"
    if e.x ~= "" then line = line .. " (" .. e.x .. ")" end
    DEFAULT_CHAT_FRAME:AddMessage(line)
  end
end

function BB:OnTakeInbox(i, isItem, j)
  if not self:IsBank() then return end
  local _, _, sender, subject, money, cod, daysLeft, hasItem, _, wasReturned = GetInboxHeaderInfo(i)
  if not sender then
    self:MailLog("?", isItem, nil, 0, 0, "nosender", "Brief " .. tostring(i))
    return
  end
  if cod and cod > 0 then
    self:MailLog(sender, isItem, nil, 0, money, "cod", BB.Money(cod))
    return
  end
  -- Uebergaben zwischen Bank-Chars sind keine Spenden
  if BananaBankDB.banks[sender] or self:MayBeBank(sender) or self:IsSystemSender(sender) then
    self:MailLog(sender, isItem, nil, 0, money, "bank")
    return
  end

  local name, tex, count, q
  if isItem then
    if not hasItem then
      self:MailLog(sender, true, nil, 0, 0, "noitem", "Brief " .. tostring(i))
      return
    end
    name, tex, count, q = GetInboxItem(i, j)
    if not name then
      self:MailLog(sender, true, nil, 0, 0, "noname", "Brief " .. tostring(i))
      return
    end
    if not self:CanReceive(name, count or 1) then
      self:MailLog(sender, true, name, count or 1, 0, "noroom")
      return
    end
  else
    if not money or money <= 0 then
      self:MailLog(sender, false, nil, 0, 0, "nomoney")
      return
    end
  end

  -- doppelte Aufrufe fuer dieselbe Entnahme ignorieren; Inhalt gehoert zum Schluessel,
  -- damit mehrere gleiche Briefe hintereinander nicht verschluckt werden
  local key = sender .. "|" .. tostring(subject) .. "|" .. tostring(daysLeft) .. "|" .. tostring(isItem)
    .. "|" .. tostring(j) .. "|" .. tostring(name) .. "|" .. tostring(count) .. "|" .. tostring(money)
  -- doppelt nur, wenn sich der Briefkasten dazwischen nicht veraendert hat (sonst ist es ein weiterer gleicher Brief)
  if key == lastTake.key and lastTake.serial == (self.inboxSerial or 0) and GetTime() - lastTake.t < 3 then
    self:MailLog(sender, isItem, name, count or 1, money, "dup")
    return
  end
  lastTake.key, lastTake.t, lastTake.serial = key, GetTime(), (self.inboxSerial or 0)

  if isItem then
    local kind = "in"
    if wasReturned then kind = "back" end
    if kind == "in" then
      self:BookDonation(sender, name, count or 1, q or 1, self:IdByName(name), tex)
    else
      self:AddLedger({ k = kind, p = sender, n = name, c = count or 1, q = q or 1, i = self:IdByName(name) })
    end
    local note
    if self:IsGuildMember(sender) == false then note = self.T("ML_EXTERN") end
    self:MailLog(sender, true, name, count or 1, 0, kind == "in" and "booked" or "back", note)
    self:ScheduleSnapshot(4)
  else
    -- Gold aus einer Nachnahme ist ein Verkaufserloes, keine Spende
    local kind = "gold"
    if subject and string.find(subject, "BananaBank", 1, true) then kind = "cod" end
    if kind == "gold" then
      self:BookGold(sender, money)
    else
      self:AddLedger({ k = kind, p = sender, m = money })
    end
    local note
    if self:IsGuildMember(sender) == false then note = self.T("ML_EXTERN") end
    self:MailLog(sender, false, nil, 0, money, kind == "gold" and "gold" or "codin", note)
    self:ScheduleSnapshot(4)
  end
  if self.UI then self.UI:Refresh() end
end

function BB:HookMail()
  if self.mailHooked then return end
  self.mailHooked = true
  self:HookSend()
  local function warnNotBank()
    if not BB:IsBank() and BB:MayBeBank(BB:Me()) and not BB.warnedNoBank then
      BB.warnedNoBank = true
      BB:Print("|cffff8000" .. BB.T("MSG_MAIL_NOTBANK") .. "|r")
    end
  end
  local origItem = TakeInboxItem
  TakeInboxItem = function(i, j)
    warnNotBank()
    BB:OnTakeInbox(i, true, j)
    return origItem(i, j)
  end
  local origMoney = TakeInboxMoney
  TakeInboxMoney = function(i)
    warnNotBank()
    BB:OnTakeInbox(i, false)
    return origMoney(i)
  end
  -- Post-Addons ("alles oeffnen") und der Client selbst nehmen Briefe oft mit AutoLootMailItem
  -- und umgehen die beiden Funktionen oben: dort ebenfalls buchen
  if AutoLootMailItem then
    local origAuto = AutoLootMailItem
    AutoLootMailItem = function(i)
      warnNotBank()
      if BB:IsBank() then
        local _, _, _, _, money, cod, _, hasItem = GetInboxHeaderInfo(i)
        if hasItem then
          if BB:MailSlots() > 1 then
            for j = 1, 12 do
              local nm = GetInboxItem(i, j)
              if not nm then break end
              BB:OnTakeInbox(i, true, j)
            end
          else
            BB:OnTakeInbox(i, true)
          end
        end
        if money and money > 0 and not (cod and cod > 0) then BB:OnTakeInbox(i, false) end
      end
      return origAuto(i)
    end
  end
end

-- ------------------------------------------------------------
-- Handel erfassen
-- ------------------------------------------------------------
function BB:TradeShow()
  if not self:IsBank() then
    self.trade = nil
    return
  end
  self.trade = { p = UnitName("NPC") or UnitName("target") or "?", tin = {}, tout = {}, min = 0, mout = 0 }
end

function BB:TradeCapture()
  local tr = self.trade
  if not tr then return end
  if tr.p == "?" then tr.p = UnitName("NPC") or UnitName("target") or "?" end
  tr.tin, tr.tout = {}, {}
  for i = 1, 6 do
    local name, tex, num, q = GetTradeTargetItemInfo(i)
    if name then table.insert(tr.tin, { n = name, t = tex, c = num or 1, q = q or 1 }) end
    local pname, _, pnum, pq = GetTradePlayerItemInfo(i)
    if pname then table.insert(tr.tout, { n = pname, c = pnum or 1, q = pq or 1 }) end
  end
  tr.min = GetTargetTradeMoney() or 0
  tr.mout = GetPlayerTradeMoney() or 0
end

-- Per Handel uebergebene Ware auf eine bestaetigte Anfrage dieser Person anrechnen.
-- Gibt die Anfrage zurueck, wenn etwas angerechnet wurde.
function BB:TradeCredit(player, id, count)
  if not id or id == 0 then return nil end
  for _, r in pairs(BananaBankDB.reqs) do
    if r.p == player and r.s == "confirmed" and r.items[id] then
      r.sent = r.sent or {}
      local open = self:ReqLeft(r, id)
      if open > 0 then
        r.sent[id] = (r.sent[id] or 0) + math.min(open, count)
        return r
      end
    end
  end
  return nil
end

function BB:TradeCommit()
  local tr = self.trade
  self.trade = nil
  if not tr then return end
  -- Handel mit einem anderen Bank-Char ist keine Spende
  if BananaBankDB.banks[tr.p] or self:MayBeBank(tr.p) then return end
  for i = 1, getn(tr.tin) do
    local it = tr.tin[i]
    self:BookDonation(tr.p, it.n, it.c, it.q, self:IdByName(it.n), it.t)
  end
  local touched = {}
  for i = 1, getn(tr.tout) do
    local it = tr.tout[i]
    local id = self:IdByName(it.n)
    local r = self:TradeCredit(tr.p, id, it.c)
    if r then touched[r.id] = r end
    self:AddLedger({ k = "out", p = tr.p, n = it.n, c = it.c, q = it.q, i = id,
      code = r and r.id or "TRADE" })
  end
  for _, r in pairs(touched) do
    r.u = time()
    if self:RequestComplete(r) then
      if self.prep and self.prep.r == r then self.prep = nil end
      self:SetStatus(r, "sent")
      self:Print(string.format(self.T("MSG_REQUEST_DONE"), r.id, r.p))
      self:Notify(r, "WHISPER_SENT")
    else
      self:PushRequests({ r })
      self:Print(string.format(self.T("MSG_REQUEST_PARTIAL"), r.id))
    end
  end
  if tr.min > 0 then self:BookGold(tr.p, tr.min) end
  if tr.mout > 0 then self:AddLedger({ k = "gout", p = tr.p, m = tr.mout }) end
  self:ScheduleSnapshot(3)
  if self.UI then self.UI:Refresh() end
end

function BB:TradeClosed()
  local tok = self.trade
  self:After(3, function()
    if BB.trade == tok then BB.trade = nil end
  end, "tradeclear")
end

-- ------------------------------------------------------------
-- Abgleich Bestand gegen Buch: was liegt in der Bank, ohne dass das Buch es als Eingang kennt?
-- ------------------------------------------------------------
function BB:ReconcileList(onlyRecipes)
  local net = {}
  for _, e in pairs(BananaBankDB.ledger) do
    local n = e.n or ""
    if e.k == "in" or e.k == "back" then net[n] = (net[n] or 0) + (e.c or 0)
    elseif e.k == "out" then net[n] = (net[n] or 0) - (e.c or 0) end
  end
  local out = {}
  for id, e in pairs(self:GetStock()) do
    local k = self:ResolveCategory(id, e)
    if not onlyRecipes or k == "recipe" then
      local diff = e.c - (net[e.n] or 0)
      if diff > 0 then
        table.insert(out, { id = id, n = e.n, q = e.q or 1, t = e.t, stock = e.c, booked = net[e.n] or 0, diff = diff, k = k })
      end
    end
  end
  table.sort(out, function(a, b)
    if a.diff ~= b.diff then return a.diff > b.diff end
    return a.n < b.n
  end)
  return out
end

function BB:PrintReconcile(arg)
  arg = string.lower(arg or "")
  local only = (arg == "rezepte" or arg == "recipes")
  local list = self:ReconcileList(only)
  self.recon = list
  self:Print(string.format(self.T("RC_HEAD"), getn(list)))
  for i = 1, getn(list) do
    local e = list[i]
    DEFAULT_CHAT_FRAME:AddMessage(string.format("%d. %s  -  %s %d, %s %d, |cffffd100+%d|r", i, e.n,
      self.T("RC_STOCK"), e.stock, self.T("RC_BOOKED"), e.booked, e.diff))
  end
  if getn(list) > 0 then self:Print(self.T("RC_HOWTO")) end
end

-- Nummern wie "1,3,5-9" oder "alle" in eine Menge umwandeln
local function parseNumbers(text, max)
  local set = {}
  text = string.lower(text or "")
  if text == "alle" or text == "all" then
    for i = 1, max do set[i] = true end
    return set
  end
  for _, part in ipairs(BB.Split(text, ",")) do
    local _, _, a, b = string.find(part, "^%s*(%d+)%s*-%s*(%d+)%s*$")
    if a then
      for i = tonumber(a), math.min(tonumber(b), max) do set[i] = true end
    else
      local n = tonumber(part)
      if n and n >= 1 and n <= max then set[n] = true end
    end
  end
  return set
end

-- /bb abgleich buchen <Spieler> <Nummern|alle>
function BB:ReconcileBook(player, numbers)
  if not (self:IsBank() and self:MayBeBank(self:Me())) then
    self:Print("|cffff4040" .. self.T("ERR_NOT_BANK") .. "|r")
    return
  end
  local list = self.recon
  if not list or getn(list) == 0 then
    self:Print(self.T("RC_NOLIST"))
    return
  end
  if not player or player == "" or not numbers or numbers == "" then
    self:Print(self.T("RC_HOWTO"))
    return
  end
  local set = parseNumbers(numbers, getn(list))
  local n, items = 0, 0
  for i = 1, getn(list) do
    if set[i] then
      local e = list[i]
      self:BookDonation(player, e.n, e.diff, e.q, e.id, e.t)
      n = n + 1
      items = items + e.diff
    end
  end
  self.recon = nil
  self:Print(string.format(self.T("RC_DONE"), n, items, player))
  if self.UI then self.UI:Refresh() end
end
