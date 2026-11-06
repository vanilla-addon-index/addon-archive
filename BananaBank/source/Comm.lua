-- BananaBank Kommunikation
-- Nachrichten (Prefix BBNK, Kanal GUILD):
--   H~<ver>~<qAnzahl>~<qSumme>~<bank,ts;...>~<ursprung,seq;...>~<preisTs>~<rangTs>~<rangName>
--   B~<xfer>~<teile>~<art>~<meta>                                  Transfer-Beginn
--   D~<xfer>~<nr>~<daten>                                          Transfer-Teil
-- Arten: S = Bestand (meta bank,ts,gold), L = Buchungen (meta ursprung),
--        Q = Anfragen (meta full/one), P = Preise (meta preisTs),
--        R = Bank-Rangname (meta ts, nur vom Gildenmeister)
-- Lehre aus BRP: sequenzielle Queue statt Burst, sonst schluckt der Server Nachrichten.

local BB = BananaBank
local getn = table.getn

local SEND_INTERVAL = 0.3
local CHUNK = 180
local queue = {}
local inbox = {}
local lastSend = 0
local pushes = {}      -- geplante Antworten, die abgebrochen werden, wenn jemand schneller ist
local helloReplyAt = 0
local lastQPush = 0
local versionWarned = false

-- ------------------------------------------------------------
-- Senden
-- ------------------------------------------------------------
function BB:Send(msg)
  table.insert(queue, msg)
end

function BB:QueueSize()
  return getn(queue)
end

local sendFrame = CreateFrame("Frame")
sendFrame:SetScript("OnUpdate", function()
  if getn(queue) == 0 then return end
  local now = GetTime()
  if now - lastSend < SEND_INTERVAL then return end
  lastSend = now
  local msg = table.remove(queue, 1)
  if IsInGuild() then
    SendAddonMessage(BB.PREFIX, msg, "GUILD")
    BB:Debug("-> " .. string.sub(msg, 1, 60) .. " (" .. string.len(msg) .. ")")
  end
end)

-- teilt Text so, dass kein UTF-8-Zeichen zerschnitten wird
function BB:Chunks(payload)
  local out = {}
  local len = string.len(payload)
  local pos = 1
  while pos <= len do
    local e = pos + CHUNK - 1
    if e < len then
      while e > pos do
        local nb = string.byte(payload, e + 1)
        if nb and nb >= 128 and nb < 192 then e = e - 1 else break end
      end
    end
    table.insert(out, string.sub(payload, pos, e))
    pos = e + 1
  end
  if getn(out) == 0 then out[1] = "" end
  return out
end

function BB:SendTransfer(kind, meta, payload)
  local x = BB.ToB36(math.random(46656, 1679615))
  local parts = self:Chunks(payload)
  self:Send("B~" .. x .. "~" .. getn(parts) .. "~" .. kind .. "~" .. meta)
  for i = 1, getn(parts) do
    self:Send("D~" .. x .. "~" .. i .. "~" .. parts[i])
  end
end

-- ------------------------------------------------------------
-- Serialisierung
-- ------------------------------------------------------------
function BB:SerializeSnapshot(snap)
  local recs = {}
  for id, it in pairs(snap.items) do
    table.insert(recs, id .. "~" .. it.c .. "~" .. (it.q or 1) .. "~" .. BB.Clean(it.t) .. "~" .. BB.Clean(it.n) .. "~" .. (it.k or "") .. "~" .. (it.s or "") .. "~" .. (it.cr or ""))
  end
  return table.concat(recs, "^")
end

function BB:ParseSnapshot(payload)
  local items = {}
  for _, rec in ipairs(BB.Split(payload, "^")) do
    local f = BB.Split(rec, "~")
    local id = tonumber(f[1])
    if id and tonumber(f[2]) then
      items[id] = { c = tonumber(f[2]), q = tonumber(f[3]) or 1, t = f[4] or "", n = f[5] or ("#" .. id) }
      if f[6] and BB.CAT_SET and BB.CAT_SET[f[6]] then items[id].k = f[6] end
      if f[7] and BB.SUB_SET and BB.SUB_SET[f[7]] then items[id].s = f[7] end
      if f[8] and f[8] ~= "" and string.find(f[8], "^[A-Z,]+$") then items[id].cr = f[8] end
    end
  end
  return items
end

local function pairsToString(t)
  local parts = {}
  for id, n in pairs(t or {}) do table.insert(parts, id .. ":" .. n) end
  return table.concat(parts, ",")
end

local function stringToPairs(s)
  local t = {}
  for _, p in ipairs(BB.Split(s or "", ",")) do
    local _, _, id, n = string.find(p, "^(%d+):(%d+)$")
    if id then t[tonumber(id)] = tonumber(n) end
  end
  return t
end

function BB:SerializeRequests(list)
  local recs = {}
  for i = 1, getn(list) do
    local r = list[i]
    table.insert(recs, table.concat({
      r.id, BB.Clean(r.p), r.ts or 0, r.s, r.u or 0, BB.Clean(r.by or ""),
      pairsToString(r.items), pairsToString(r.sent), pairsToString(r.cl or {}), pairsToString(r.fr or {}), pairsToString(r.sh or {}), BB.Clean(r.qid or ""),
    }, "~"))
  end
  return table.concat(recs, "^")
end

function BB:ParseRequests(payload)
  local out = {}
  for _, rec in ipairs(BB.Split(payload, "^")) do
    local f = BB.Split(rec, "~")
    if f[1] and f[2] and BB.RANK[f[4] or ""] then
      local r = {
        id = f[1], p = f[2], ts = tonumber(f[3]) or 0, s = f[4], u = tonumber(f[5]) or 0,
        by = f[6], items = stringToPairs(f[7]), sent = stringToPairs(f[8]),
        cl = stringToPairs(f[9] or ""), fr = stringToPairs(f[10] or ""), sh = stringToPairs(f[11] or ""),
        qid = (f[12] and f[12] ~= "") and f[12] or nil,
      }
      r.code = BB:BuildCode(r.id, r.p, r.items)
      table.insert(out, r)
    end
  end
  return out
end

function BB:SerializeLedger(list)
  local recs = {}
  for i = 1, getn(list) do
    local e = list[i]
    table.insert(recs, table.concat({
      e.id, e.t, e.k, e.p, e.i or 0, e.n or "", e.c or 0, e.q or 1, e.m or 0, e.code or "", e.g or "",
    }, "~"))
  end
  return table.concat(recs, "^")
end

function BB:ParseLedger(payload)
  local out = {}
  for _, rec in ipairs(BB.Split(payload, "^")) do
    local f = BB.Split(rec, "~")
    if f[1] and string.find(f[1], ":%d+$") then
      table.insert(out, {
        id = f[1], t = tonumber(f[2]) or 0, k = f[3], p = f[4], i = tonumber(f[5]) or 0,
        n = f[6] or "", c = tonumber(f[7]) or 0, q = tonumber(f[8]) or 1, m = tonumber(f[9]) or 0,
        code = f[10] or "", g = f[11] or "",
      })
    end
  end
  return out
end

local function seqOf(id)
  local _, _, origin, seq = string.find(id, "^(.+):(%d+)$")
  return origin, tonumber(seq)
end
BB.SeqOf = seqOf

-- ------------------------------------------------------------
-- Pushes
-- ------------------------------------------------------------
-- Warnung einmal je Char und Sitzung, und nur fuer Offiziere und Bank-Chars
local warned = {}
function BB:RejectBank(bank, sender)
  self:Debug("Bestand von " .. tostring(bank) .. " verworfen (Rang passt nicht)")
  if warned[bank] then return end
  warned[bank] = true
  if not self:IsOfficer() then return end
  local rank = self:RankOf(bank) or "?"
  self:Print("|cffff8000" .. string.format(self.T("MSG_BANK_BLOCKED"), bank, rank,
    BB.BANK_RANK_LABEL) .. "|r")
end

function BB:PushAll()
  for bank in pairs(BananaBankDB.snaps) do self:PushSnapshot(bank) end
  self:PushRequests()
  self:PushPrices()
  self:PushQuests()
  self:PushBankInfo()
end

function BB:PushSnapshot(bank)
  local snap = BananaBankDB.snaps[bank]
  if not snap then return end
  -- kein erlaubter Rang mehr: auch auf Nachfrage nichts herausgeben
  if not self:MayBeBank(bank) then
    pushes["S:" .. bank] = nil
    return
  end
  pushes["S:" .. bank] = nil
  self:SendTransfer("S", bank .. "," .. snap.ts .. "," .. (snap.gold or 0), self:SerializeSnapshot(snap))
end

function BB:PushRequests(list, full)
  if not list then
    list = {}
    for _, r in pairs(BananaBankDB.reqs) do table.insert(list, r) end
    full = true
  end
  if getn(list) == 0 and not full then return end
  if full then
    pushes["Q"] = nil
    lastQPush = GetTime()
  end
  self:SendTransfer("Q", full and "full" or "one", self:SerializeRequests(list))
end

function BB:PushLedger(origin, fromSeq)
  local list = {}
  for id, e in pairs(BananaBankDB.ledger) do
    local o, s = seqOf(id)
    if o == origin and s and s > (fromSeq or 0) then table.insert(list, e) end
  end
  pushes["L:" .. origin] = nil
  if getn(list) == 0 then return end
  table.sort(list, function(a, b)
    local _, sa = seqOf(a.id)
    local _, sb = seqOf(b.id)
    return sa < sb
  end)
  self:SendTransfer("L", origin, self:SerializeLedger(list))
end

-- neue eigene Buchungen gesammelt nach kurzer Pause senden
function BB:ScheduleLedgerPush()
  local me = self:Me()
  BananaBankDB.pushedSeq = BananaBankDB.pushedSeq or {}
  self:After(4, function()
    local from = BananaBankDB.pushedSeq[me] or 0
    BB:PushLedger(me, from)
    BananaBankDB.pushedSeq[me] = BananaBankDB.seqs[me] or from
  end, "ledgerpush")
end

-- zufaellig verzoegerte Antwort; faellt weg, wenn ein anderes Mitglied dasselbe schon sendet
local function schedulePush(key, fn)
  if pushes[key] then return end
  pushes[key] = true
  BB:After(1 + math.random() * 3, function()
    if pushes[key] then
      pushes[key] = nil
      fn()
    end
  end, "push:" .. key)
end

-- ------------------------------------------------------------
-- Hallo / Abgleich
-- ------------------------------------------------------------
function BB:SendHello()
  if not self:Ready() then return end
  local snaps, seqs = {}, {}
  for bank, s in pairs(BananaBankDB.snaps) do table.insert(snaps, bank .. "," .. s.ts) end
  for origin, s in pairs(BananaBankDB.seqs) do table.insert(seqs, origin .. "," .. s) end
  local qn, qs = self:RequestDigest()
  local qn2, qs2 = self:QuestDigest()
  local bn2, bs2 = self:BankInfoDigest()
  self:Send("H~" .. self.VERSION .. "~" .. qn .. "~" .. qs .. "~" .. table.concat(snaps, ";") ..
    "~" .. table.concat(seqs, ";") .. "~" .. (BananaBankDB.priceTs or 0) .. "~" .. qn2 .. "~" .. qs2 .. "~" .. bn2 .. "~" .. bs2 .. "~" .. (BananaBankDB.mainTs or 0) .. "~" .. ((BananaBankDB.rules and BananaBankDB.rules.ts) or 0))
  -- zweite, kurze Hallo-Nachricht: Staende von Hauptbank, Regeln und Rechte-Liste (die erste kann bei vielen Banken zu lang werden)
  local tn, tsum = 0, 0
  if self.TrashDigest then tn, tsum = self:TrashDigest() end
  self:Send("X~" .. (BananaBankDB.mainTs or 0) .. "~" .. ((BananaBankDB.rules and BananaBankDB.rules.ts) or 0) .. "~" .. ((BananaBankDB.rights and BananaBankDB.rights.ts) or 0) .. "~" .. tn .. "~" .. tsum)
end

local function parseList(s)
  local t = {}
  for _, p in ipairs(BB.Split(s or "", ";")) do
    local f = BB.Split(p, ",")
    if f[1] and tonumber(f[2]) then t[f[1]] = tonumber(f[2]) end
  end
  return t
end

local function versionNum(v)
  local f = BB.Split(v or "0", ".")
  return (tonumber(f[1]) or 0) * 10000 + (tonumber(f[2]) or 0) * 100 + (tonumber(f[3]) or 0)
end

function BB:OnHello(sender, ver, qn, qs, snapStr, seqStr, priceTs, gn, gs, bn, bs, mt, rt)
  if not versionWarned and versionNum(ver) > versionNum(self.VERSION) then
    versionWarned = true
    self:Print(string.format(self.T("MSG_NEW_VERSION"), ver))
  end
  local theirSnaps = parseList(snapStr)
  local theirSeqs = parseList(seqStr)
  local behind = false

  for bank, s in pairs(BananaBankDB.snaps) do
    local t = theirSnaps[bank] or 0
    if s.ts > t then
      -- Lua 5.0: Schleifenvariable ist nach der Schleife nil, darum lokale Kopie fuer die Closure
      local b = bank
      schedulePush("S:" .. b, function() BB:PushSnapshot(b) end)
    end
  end
  for bank, t in pairs(theirSnaps) do
    local mine = BananaBankDB.snaps[bank]
    if not mine or mine.ts < t then behind = true end
  end

  for origin, s in pairs(BananaBankDB.seqs) do
    local t = theirSeqs[origin] or 0
    if s > t then
      local o, from = origin, t
      schedulePush("L:" .. o, function() BB:PushLedger(o, from) end)
    end
  end
  for origin, t in pairs(theirSeqs) do
    if (BananaBankDB.seqs[origin] or 0) < t then behind = true end
  end

  local theirPrice = tonumber(priceTs) or 0
  if (BananaBankDB.priceTs or 0) > theirPrice then
    schedulePush("P", function() BB:PushPrices() end)
  elseif theirPrice > (BananaBankDB.priceTs or 0) then
    behind = true
  end

  -- Gildenquests (aeltere Versionen senden keine Pruefsumme)
  if gn and gs then
    local myGN, myGS = self:QuestDigest()
    if myGN ~= tonumber(gn) or myGS ~= tonumber(gs) then
      if myGN > 0 then schedulePush("G", function() BB:PushQuests() end) end
      behind = true
    end
  end

  -- Bank-Rollen
  if bn and bs then
    local myBN, myBS = self:BankInfoDigest()
    if myBN ~= tonumber(bn) or myBS ~= tonumber(bs) then
      if myBN > 0 then schedulePush("I", function() BB:PushBankInfo() end) end
      behind = true
    end
  end

  -- Hauptbank-Name: der neuere Stand gewinnt
  if mt and (BananaBankDB.mainTs or 0) > (tonumber(mt) or 0) then
    schedulePush("N", function() BB:PushMainBank() end)
  end

  -- Regelsatz: der neuere Stand gewinnt
  if rt and ((BananaBankDB.rules and BananaBankDB.rules.ts) or 0) > (tonumber(rt) or 0) then
    schedulePush("R", function() BB:PushRules() end)
  end

  local myN, mySum = self:RequestDigest()
  if myN ~= tonumber(qn) or mySum ~= tonumber(qs) then
    if myN > 0 then schedulePush("Q", function() BB:PushRequests() end) end
    behind = true
  end

  -- wir haben selbst Luecken: einmal zurueckgruessen, damit der andere uns beliefert
  if behind and GetTime() > helloReplyAt then
    helloReplyAt = GetTime() + 30
    self:After(2 + math.random() * 2, function() BB:SendHello() end, "helloreply")
  end
end

-- ------------------------------------------------------------
-- Transfer-Auswertung
-- ------------------------------------------------------------
function BB:OnTransfer(sender, kind, meta, payload)
  local db = BananaBankDB
  if kind == "S" then
    local f = BB.Split(meta, ",")
    local bank, ts, gold = f[1], tonumber(f[2]) or 0, tonumber(f[3]) or 0
    if not bank then return end
    -- Rang des Bank-Chars in der EIGENEN Gildenliste pruefen, nicht den Absender:
    -- Bestaende duerfen von jedem Mitglied weitergereicht werden.
    if not self:MayBeBank(bank) then
      self:RejectBank(bank, sender)
      return
    end
    -- Zeitstempel aus der Zukunft wuerden echte Updates blockieren
    if ts > time() + 86400 then
      self:Debug("Bestand von " .. bank .. " mit unmoeglichem Datum verworfen")
      return
    end
    local cur = db.snaps[bank]
    if cur and cur.ts >= ts then return end
    db.snaps[bank] = { ts = ts, gold = gold, items = self:ParseSnapshot(payload), from = sender }
    self:Debug("Bestand von " .. bank .. " uebernommen (" .. BB.Count(db.snaps[bank].items) .. " Items)")
  elseif kind == "L" then
    local n = 0
    for _, e in ipairs(self:ParseLedger(payload)) do
      if not db.ledger[e.id] then
        local o, s = seqOf(e.id)
        -- Buchungen, die eine Quest voranbringen, zaehlen nur von verifizierten Bank-Chars.
        -- Sonst koennte jedes Mitglied sich Fortschritt und Platz im Ranking schreiben.
        local forged = e.code ~= "" and (not (e.k == "in" or e.k == "qfix" or e.k == "gold") or not self:MayBeBank(o))
          and string.len(e.code) == 6 and string.sub(e.code, 1, 1) == "G"
        if forged then
          self:Debug("Quest-Buchung " .. e.id .. " verworfen (Herkunft ist keine Bank)")
        else
          db.ledger[e.id] = e
          n = n + 1
          if s and s > (db.seqs[o] or 0) then db.seqs[o] = s end
          local q = e.code ~= "" and db.quests[e.code]
          if q and (e.k == "in" or e.k == "qfix") then
            self:QLog("deliver", q, o, string.format("%s: %dx %s", e.p, e.c, e.n), e.id)
          end
          if q and e.k == "gold" then
            self:QLog("deliver", q, o, string.format("%s: %s", e.p, BB.GoldText(e.m)), e.id)
          end
        end
      end
    end
    self.qDirty = true
    self:Debug(n .. " neue Buchungen von " .. sender)
    self:QuestTick()
  elseif kind == "I" then
    local n = 0
    for _, r in ipairs(self:ParseBankInfo(payload)) do
      if self:MergeBankInfo(r) then n = n + 1 end
    end
    self:Debug(n .. " Bank-Rollen von " .. sender)
  elseif kind == "T" then
    if self.MergeTrash and self:MergeTrash(payload) then self:Debug("Trash-Entscheidungen von " .. sender) end
  elseif kind == "K" then
    if self:MergeRights(payload) then self:Debug("Rechte von " .. sender) end
  elseif kind == "R" then
    if self:MergeRules(payload) then self:Debug("Regeln von " .. sender) end
  elseif kind == "N" then
    if self:MergeMainBank(payload) then self:Debug("Hauptbank von " .. sender) end
  elseif kind == "G" then
    local n = 0
    for _, r in ipairs(self:ParseQuests(payload)) do
      if self:MergeQuest(r) then n = n + 1 end
    end
    self:Debug(n .. " Quests von " .. sender)
    self:QuestTick()
  elseif kind == "P" then
    local n = self:MergePrices(self:ParsePrices(payload))
    self:Debug(n .. " Preise von " .. sender)
  elseif kind == "Q" then
    local incoming = self:ParseRequests(payload)
    local seen = {}
    for i = 1, getn(incoming) do
      seen[incoming[i].id] = true
      self:MergeRequest(incoming[i])
    end
    -- beim Vollabgleich: haben wir Anfragen, die dem anderen fehlen? Dann selbst senden.
    if meta == "full" then
      local missing = false
      for code in pairs(db.reqs) do
        if not seen[code] then missing = true end
      end
      if missing and GetTime() - lastQPush > 20 then
        schedulePush("Q", function() BB:PushRequests() end)
      end
    end
  end
  if self.UI then self.UI:Refresh() end
end

-- X~: Staende von Hauptbank, Regeln und Rechte-Liste: der neuere Stand wird gepusht
function BB:OnHello2(sender, mt, rt, kt, tn, tsum)
  local db = BananaBankDB
  if self.TrashDigest then
    local n, s = self:TrashDigest()
    if n > 0 and (n ~= (tonumber(tn) or 0) or s ~= (tonumber(tsum) or 0)) then schedulePush("T", function() BB:PushTrash() end) end
  end
  if (db.mainTs or 0) > (tonumber(mt) or 0) then schedulePush("N", function() BB:PushMainBank() end) end
  if ((db.rules and db.rules.ts) or 0) > (tonumber(rt) or 0) then schedulePush("R", function() BB:PushRules() end) end
  if ((db.rights and db.rights.ts) or 0) > (tonumber(kt) or 0) then schedulePush("K", function() BB:PushRights() end) end
end

function BB:OnAddonMessage(prefix, msg, channel, sender)
  if prefix ~= self.PREFIX or not msg then return end
  if sender == self:Me() then return end
  -- ohne Bank-Rang in der Gilde ist das Addon gesperrt
  if not self:Ready() then return end

  local t = string.sub(msg, 1, 2)
  if t == "D~" then
    local _, _, x, i, data = string.find(msg, "^D~(%w+)~(%d+)~(.*)$")
    local box = x and inbox[sender .. ":" .. x]
    if not box then return end
    i = tonumber(i)
    if not box.parts[i] then
      box.parts[i] = data
      box.got = box.got + 1
    end
    box.t = GetTime()
    if box.got >= box.n then
      inbox[sender .. ":" .. x] = nil
      local payload = table.concat(box.parts, "", 1, box.n)
      self:OnTransfer(sender, box.kind, box.meta, payload)
    end
  elseif t == "B~" then
    local _, _, x, n, kind, meta = string.find(msg, "^B~(%w+)~(%d+)~(%a)~(.*)$")
    if not x then return end
    inbox[sender .. ":" .. x] = { n = tonumber(n), kind = kind, meta = meta, parts = {}, got = 0, t = GetTime() }
    -- jemand liefert schon: eigene geplante Antwort derselben Sache streichen
    if kind == "S" then
      local f = BB.Split(meta, ",")
      local mine = f[1] and BananaBankDB.snaps[f[1]]
      if mine and (tonumber(f[2]) or 0) >= mine.ts then pushes["S:" .. f[1]] = nil end
    elseif kind == "L" then
      pushes["L:" .. meta] = nil
    elseif kind == "Q" and meta == "full" then
      pushes["Q"] = nil
    elseif kind == "P" then
      if (tonumber(meta) or 0) >= (BananaBankDB.priceTs or 0) then pushes["P"] = nil end
    elseif kind == "G" and meta == "full" then
      pushes["G"] = nil
    elseif kind == "I" and meta == "full" then
      pushes["I"] = nil
    elseif kind == "N" then
      pushes["N"] = nil
    elseif kind == "R" then
      pushes["R"] = nil
    elseif kind == "K" then
      pushes["K"] = nil
    elseif kind == "T" then
      pushes["T"] = nil
    end
  elseif t == "V~" then
    if self.OnLevelMessage then self:OnLevelMessage(sender, msg) end
  elseif t == "X~" then
    local f = BB.Split(msg, "~")
    self:OnHello2(sender, f[2], f[3], f[4], f[5], f[6])
  elseif t == "H~" then
    local f = BB.Split(msg, "~")
    self:OnHello(sender, f[2], f[3], f[4], f[5], f[6], f[7], f[8], f[9], f[10], f[11], f[12], f[13])
  end
end

-- unvollstaendige Transfers nach einer Minute verwerfen
local cleanFrame = CreateFrame("Frame")
local cleanAcc = 0
cleanFrame:SetScript("OnUpdate", function()
  cleanAcc = cleanAcc + (arg1 or 0)
  if cleanAcc < 15 then return end
  cleanAcc = 0
  local now = GetTime()
  for key, box in pairs(inbox) do
    if now - box.t > 60 then inbox[key] = nil end
  end
end)
