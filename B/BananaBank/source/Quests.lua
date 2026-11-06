-- BananaBank Gildenquests: Daten, Fortschritt aus dem Spendenbuch, Punkte, Reservierung, Log
--
-- Eine Quest verlangt ein oder mehrere Items. Der Fortschritt wird NICHT extra gezaehlt,
-- sondern aus dem Spendenbuch abgeleitet: Nimmt der Bank-Char eine Lieferung an (Post oder
-- Handel), schreibt er die Quest in den Buchungseintrag (Feld code). Alle Clients rechnen
-- dieselbe Summe, und wer offline war, holt sie beim Abgleich nach.

local BB = BananaBank
local getn = table.getn
local floor = math.floor

BB.questModule = true
BB.QUEST_MAX_ITEMS = 6
BB.QUEST_MAX_GOLD = 6          -- Gold-Ziele (je ein Bank-Char); Items + Gold-Ziele zusammen hoechstens QUEST_MAX_ITEMS
BB.GOLD = 10000
BB.QUEST_MAX_OPEN = 8
BB.QUEST_TITLE_LEN = 40
BB.QUEST_TEXT_LEN = 180
BB.QUEST_TIP_LEN = 200        -- eigener Tooltip-Text einer Quest
BB.QUEST_LOG_MAX = 400
BB.QUEST_POINTS = 10          -- eine ganze Quest allein erledigt = 10 Punkte
BB.QRANK = { open = 1, closed = 2, cancelled = 3 }

-- ------------------------------------------------------------
-- Rechte: Gildenmeister (Rang 1), Gildenbank (Rang 2), Offiziere (Rang 3)
-- Der Rang kommt aus der eigenen Gildenliste, nicht vom Absender.
-- ------------------------------------------------------------
function BB:CanManageQuests(name)
  name = name or self:Me()
  if not self:Ready() then return false end
  local _, idx = self:RankOf(name)
  if idx and idx <= 2 then return true end
  return self:MayBeBank(name)
end

-- ------------------------------------------------------------
-- Text-Werkzeuge
-- ------------------------------------------------------------
local function cutUtf8(s, len)
  if string.len(s) <= len then return s end
  local e = len
  while e > 0 do
    local nb = string.byte(s, e + 1)
    if nb and nb >= 128 and nb < 192 then e = e - 1 else break end
  end
  return string.sub(s, 1, e)
end

local function cleanText(s, len)
  s = BB.Clean(s)
  s = string.gsub(s, "[%c]+", " ")
  s = string.gsub(s, "^%s+", "")
  s = string.gsub(s, "%s+$", "")
  return cutUtf8(s, len)
end
BB.QuestClean = cleanText

-- Icon einer Quest: nur der Dateiname unter Interface\\Icons, ohne Sonderzeichen
local function cleanIcon(s)
  s = BB.ShortTex(s or "")
  s = string.gsub(s, "[^%w_%-]", "")
  return string.sub(s, 1, 60)
end
BB.QuestCleanIcon = cleanIcon

local function cleanName(s)
  s = cleanText(s, 60)
  s = string.gsub(s, "[,:;]", " ")
  return s
end

-- ------------------------------------------------------------
-- Datenbank-Zugriff
-- ------------------------------------------------------------
function BB:QuestList()
  local list = {}
  for _, q in pairs(BananaBankDB.quests) do table.insert(list, q) end
  return list
end

function BB:QuestNeed(q)
  local n = 0
  for _, need in pairs(q.items) do n = n + need end
  -- Gold-Ziele zaehlen je 1 Gold als 1 Einheit
  for _, c in pairs(q.gold or {}) do n = n + floor(c / BB.GOLD) end
  return n
end

-- Gold-Ziel in Kurzform: 5g, 1g 50s
function BB.GoldText(c)
  c = c or 0
  local g, sil = floor(c / 10000), floor(mod(c, 10000) / 100)
  if g > 0 and sil > 0 then return g .. "g " .. sil .. "s" end
  if g > 0 then return g .. "g" end
  if sil > 0 then return sil .. "s" end
  return c .. "c"
end

-- Name, Qualitaet, Icon eines Quest-Items: zuerst der eigene Client, dann die Angaben der Quest
function BB:QuestItemInfo(q, id)
  local name, quality, tex = self:ItemInfo(id)
  if string.sub(name, 1, 1) ~= "#" then return name, quality, tex end
  local m = q and q.meta and q.meta[id]
  if m then return m.n, m.q or 1, m.t or "" end
  return name, quality, tex
end

-- ------------------------------------------------------------
-- Fortschritt (aus dem Spendenbuch abgeleitet)
-- stats[id] = { got = {itemId = n}, eff = {itemId = min(n, Bedarf)}, by = {Spieler = n},
--               done, need, complete }
-- ------------------------------------------------------------
function BB:QuestStats()
  if self.qStats and not self.qDirty then return self.qStats end
  local db = BananaBankDB
  local out = {}
  for id in pairs(db.quests) do out[id] = { got = {}, eff = {}, by = {}, gg = {}, geff = {}, gby = {}, done = 0, need = 0 } end
  for _, e in pairs(db.ledger) do
    if BB:IsSystemSender(e.p) then
      -- NPC-Buchungen (z. B. Auktionshaus) zaehlen nie fuer Quests
    elseif (e.k == "in" or e.k == "qfix") and e.code ~= "" then
      local s = out[e.code]
      local q = s and db.quests[e.code]
      if q and q.items[e.i] then
        s.got[e.i] = (s.got[e.i] or 0) + e.c
        s.by[e.p] = (s.by[e.p] or 0) + e.c
      end
    elseif e.k == "gold" and e.code ~= "" then
      -- Gold-Spende an einen Bank-Char der Quest (n = Bank-Char, der den Brief geleert hat)
      local s = out[e.code]
      local q = s and db.quests[e.code]
      if q and q.gold and q.gold[e.n] then
        s.gg[e.n] = (s.gg[e.n] or 0) + e.m
        s.gby[e.p] = (s.gby[e.p] or 0) + e.m
      end
    end
  end
  for id, s in pairs(out) do
    local q = db.quests[id]
    for iid, need in pairs(q.items) do
      local g = s.got[iid] or 0
      if g > need then g = need end
      s.eff[iid] = g
      s.done = s.done + g
      s.need = s.need + need
    end
    -- Gold-Ziele: je Bank-Char gedeckelt, zaehlen in ganzen Gold
    for bank, goal in pairs(q.gold or {}) do
      local g = s.gg[bank] or 0
      if g > goal then g = goal end
      s.geff[bank] = g
      s.done = s.done + floor(g / BB.GOLD)
      s.need = s.need + floor(goal / BB.GOLD)
    end
    s.complete = s.need > 0 and s.done >= s.need
  end
  self.qStats = out
  self.qDirty = false
  return out
end

-- offen | complete | expired | closed | cancelled
function BB:QuestState(q)
  if q.s == "cancelled" then return "cancelled" end
  if q.s == "closed" then return "closed" end
  local s = self:QuestStats()[q.id]
  if s and s.complete then return "complete" end
  if q.due and q.due > 0 and time() > q.due then return "expired" end
  return "open"
end

function BB:QuestIsActive(q)
  local st = self:QuestState(q)
  return st == "open" or st == "complete"
end

-- Reihenfolge der besten Helfer einer Quest: { {p=, c=}, ... }
function BB:QuestTop(q)
  local s = self:QuestStats()[q.id]
  local list = {}
  if s then
    local seen = {}
    for p, c in pairs(s.by) do
      seen[p] = { p = p, c = c, g = s.gby[p] or 0 }
      table.insert(list, seen[p])
    end
    for p, g in pairs(s.gby) do
      if not seen[p] then table.insert(list, { p = p, c = 0, g = g }) end
    end
  end
  local function score(e) return e.c + e.g / BB.GOLD end
  table.sort(list, function(a, b)
    if score(a) == score(b) then return a.p < b.p end
    return score(a) > score(b)
  end)
  return list
end

-- ------------------------------------------------------------
-- Ranking: Punkte = Anteil an jeder Quest, zusammengezaehlt
-- since: nur Lieferungen ab diesem Zeitpunkt (nil = dauerhaft)
-- ------------------------------------------------------------
function BB:QuestRanking(since)
  local db = BananaBankDB
  local need = {}
  for id, q in pairs(db.quests) do need[id] = self:QuestNeed(q) end
  local per = {}
  for _, e in pairs(db.ledger) do
    if BB:IsSystemSender(e.p) then
      -- NPC-Buchungen (z. B. Auktionshaus) zaehlen nie fuer das Ranking
    elseif (e.k == "in" or e.k == "qfix") and e.code ~= "" and (not since or e.t >= since) then
      local q = db.quests[e.code]
      if q and q.s ~= "cancelled" and q.items[e.i] and need[q.id] > 0 then
        local r = per[e.p]
        if not r then
          r = { p = e.p, pts = 0, c = 0, quests = {}, nq = 0 }
          per[e.p] = r
        end
        r.pts = r.pts + e.c / need[q.id] * BB.QUEST_POINTS
        r.c = r.c + e.c
        if not r.quests[q.id] then
          r.quests[q.id] = true
          r.nq = r.nq + 1
        end
      end
    elseif e.k == "gold" and e.code ~= "" and (not since or e.t >= since) then
      local q = db.quests[e.code]
      if q and q.s ~= "cancelled" and q.gold and q.gold[e.n] and need[q.id] > 0 then
        local r = per[e.p]
        if not r then
          r = { p = e.p, pts = 0, c = 0, quests = {}, nq = 0 }
          per[e.p] = r
        end
        r.pts = r.pts + (e.m / BB.GOLD) / need[q.id] * BB.QUEST_POINTS
        if not r.quests[q.id] then
          r.quests[q.id] = true
          r.nq = r.nq + 1
        end
      end
    end
  end
  local list = {}
  for _, r in pairs(per) do table.insert(list, r) end
  table.sort(list, function(a, b)
    if a.pts ~= b.pts then return a.pts > b.pts end
    if a.c ~= b.c then return a.c > b.c end
    return a.p < b.p
  end)
  return list
end

-- ------------------------------------------------------------
-- Zuordnung einer Lieferung (Bank-Char): welche Quest bekommt wie viel?
-- Aeltere Quests zuerst. Ueberschuss bleibt normale Spende.
-- ------------------------------------------------------------
function BB:ResolveQuestItem(name, tex)
  local db = BananaBankDB
  local short = BB.ShortTex(tex)
  local texHit
  for _, q in pairs(db.quests) do
    if self:QuestState(q) == "open" then
      for iid in pairs(q.items) do
        local lname = GetItemInfo(iid)
        local m = q.meta and q.meta[iid]
        if (lname and lname == name) or (m and m.n == name) then return iid end
        if short ~= "" and m and m.t == short then texHit = iid end
      end
    end
  end
  return texHit
end

function BB:QuestSplit(id, count)
  if not id or id == 0 then return { { code = "", c = count } } end
  local stats = self:QuestStats()
  local cand = {}
  for _, q in pairs(BananaBankDB.quests) do
    local need = q.items[id]
    if need and self:QuestState(q) == "open" then
      local s = stats[q.id]
      local left = need - ((s and s.got[id]) or 0)
      if left > 0 then table.insert(cand, { q = q, left = left }) end
    end
  end
  table.sort(cand, function(a, b)
    if a.q.ts ~= b.q.ts then return a.q.ts < b.q.ts end
    return a.q.id < b.q.id
  end)
  local parts = {}
  local rest = count
  for i = 1, getn(cand) do
    if rest <= 0 then break end
    local take = cand[i].left
    if take > rest then take = rest end
    table.insert(parts, { code = cand[i].q.id, c = take })
    rest = rest - take
  end
  if rest > 0 then table.insert(parts, { code = "", c = rest }) end
  return parts
end

-- Gold, das ein Bank-Char per Post/Handel bekommen hat: erst offene Quests mit Gold-Ziel fuer diesen
-- Char (aelteste zuerst), der Rest ist eine normale Gold-Spende.
function BB:QuestGoldSplit(bank, money)
  local stats = self:QuestStats()
  local cand = {}
  for _, q in pairs(BananaBankDB.quests) do
    local goal = q.gold and q.gold[bank]
    if goal and self:QuestState(q) == "open" then
      local s = stats[q.id]
      local left = goal - ((s and s.gg[bank]) or 0)
      if left > 0 then table.insert(cand, { q = q, left = left }) end
    end
  end
  table.sort(cand, function(a, b)
    if a.q.ts ~= b.q.ts then return a.q.ts < b.q.ts end
    return a.q.id < b.q.id
  end)
  local parts, rest = {}, money
  for i = 1, getn(cand) do
    if rest <= 0 then break end
    local take = cand[i].left
    if take > rest then take = rest end
    table.insert(parts, { code = cand[i].q.id, m = take })
    rest = rest - take
  end
  if rest > 0 then table.insert(parts, { code = "", m = rest }) end
  return parts
end

function BB:BookGold(sender, money)
  local me = self:Me()
  self:Print(string.format(self.T("MSG_GOLD_BOOKED"), sender, BB.GoldText(money)))
  local parts = self:QuestGoldSplit(me, money)
  for i = 1, getn(parts) do
    local e = self:AddLedger({ k = "gold", p = sender, m = parts[i].m, n = me, code = parts[i].code })
    if parts[i].code ~= "" then
      local q = BananaBankDB.quests[parts[i].code]
      if q then
        self:QLog("deliver", q, me, string.format("%s: %s", e.p, BB.GoldText(e.m)), e.id)
        local s = self:QuestStats()[q.id]
        self:Print(string.format(self.T("QMSG_GOLD"), q.title, me, BB.GoldText((s and s.geff[me]) or 0), BB.GoldText(q.gold[me] or 0)))
      end
    end
  end
  if self.QuestTick then self:QuestTick() end
end

-- Bank-Char hat eine Lieferung fuer eine Quest gebucht
function BB:OnQuestDelivery(e)
  local q = BananaBankDB.quests[e.code]
  if not q then return end
  self:QLog("deliver", q, self:Me(), string.format("%s: %dx %s", e.p, e.c, e.n), e.id)
  local s = self:QuestStats()[q.id]
  local need = q.items[e.i] or 0
  local got = (s and s.eff[e.i]) or 0
  self:Print(string.format(self.T("QMSG_PROGRESS"), q.title, e.n, got, need))
end

-- ------------------------------------------------------------
-- Reservierung: gelieferte Items einer Quest bleiben fuer Anfragen gesperrt
-- ------------------------------------------------------------
function BB:QuestReserved(res)
  local stats = self:QuestStats()
  for id, q in pairs(BananaBankDB.quests) do
    if q.rs == 1 and self:QuestIsActive(q) then
      local s = stats[id]
      if s then
        for iid in pairs(q.items) do
          local n = s.eff[iid] or 0
          if n > 0 then res[iid] = (res[iid] or 0) + n end
        end
      end
    end
  end
end

-- ------------------------------------------------------------
-- Log (versteckt, nur ueber /bb questlog fuer Quest-Verwalter)
-- ------------------------------------------------------------
function BB:QLog(act, q, actor, x, key)
  local db = BananaBankDB
  db.qlog = db.qlog or {}
  if key then
    if not self.qlogKeys then
      self.qlogKeys = {}
      for i = 1, getn(db.qlog) do
        if db.qlog[i].k then self.qlogKeys[db.qlog[i].k] = true end
      end
    end
    if self.qlogKeys[key] then return end
    self.qlogKeys[key] = true
  end
  table.insert(db.qlog, {
    t = time(), a = actor or "?", act = act, id = q and q.id or "", title = q and q.title or "",
    x = x or "", k = key,
  })
  while getn(db.qlog) > BB.QUEST_LOG_MAX do
    local old = table.remove(db.qlog, 1)
    if old and old.k and self.qlogKeys then self.qlogKeys[old.k] = nil end
  end
end

function BB:PrintQuestLog(n)
  if not self:CanManageQuests() then
    self:Print("|cffff4040" .. self.T("ERR_QUEST_NOPERM") .. "|r")
    return
  end
  local log = BananaBankDB.qlog or {}
  n = tonumber(n) or 15
  if n < 1 then n = 1 end
  if n > 60 then n = 60 end
  local from = getn(log) - n + 1
  if from < 1 then from = 1 end
  self:Print(string.format(self.T("QLOG_HEAD"), getn(log) - from + 1, getn(log)))
  for i = from, getn(log) do
    local e = log[i]
    local line = date("%d.%m. %H:%M", e.t) .. "  |cffffd100" .. e.a .. "|r  " ..
      self.T("QLOG_" .. string.upper(e.act))
    if e.title and e.title ~= "" then line = line .. "  \"" .. e.title .. "\"" end
    if e.x and e.x ~= "" then line = line .. "  |cff9a9cb3" .. e.x .. "|r" end
    DEFAULT_CHAT_FRAME:AddMessage(line)
  end
end

-- ------------------------------------------------------------
-- Quests anlegen und aendern (nur Quest-Verwalter)
-- ------------------------------------------------------------
local function noPerm(self)
  self:Print("|cffff4040" .. self.T("ERR_QUEST_NOPERM") .. "|r")
end

-- Gold-Ziele bereinigen: { [Bank-Char] = Kupfer }, ganze Gold, 1..99999
function BB:CleanGold(g)
  local out, n = {}, 0
  for name, c in pairs(g or {}) do
    name = string.gsub(tostring(name), "[~%^,:|%c%s]", "")
    c = floor((tonumber(c) or 0) / BB.GOLD) * BB.GOLD
    if name ~= "" and c >= BB.GOLD and c <= 99999 * BB.GOLD and n < BB.QUEST_MAX_GOLD then
      out[name] = c
      n = n + 1
    end
  end
  return out
end

function BB:CountOpenQuests()
  local n = 0
  for _, q in pairs(BananaBankDB.quests) do
    if q.s == "open" then n = n + 1 end
  end
  return n
end

-- items = { [id] = Bedarf }, meta = { [id] = { n=, q=, t= } }
function BB:CreateQuest(title, text, items, meta, days, reserve, icon, tip, gold)
  if not self:CanManageQuests() then noPerm(self) return nil end
  title = cleanText(title, BB.QUEST_TITLE_LEN)
  text = cleanText(text, BB.QUEST_TEXT_LEN)
  if title == "" then self:Print("|cffff4040" .. self.T("ERR_QUEST_TITLE") .. "|r") return nil end
  gold = self:CleanGold(gold)
  if BB.Count(items) + BB.Count(gold) == 0 then self:Print("|cffff4040" .. self.T("ERR_QUEST_ITEMS") .. "|r") return nil end
  if BB.Count(items) + BB.Count(gold) > BB.QUEST_MAX_ITEMS then
    self:Print("|cffff4040" .. string.format(self.T("ERR_QUEST_ITEM_MAX"), BB.QUEST_MAX_ITEMS) .. "|r")
    return nil
  end
  if self:CountOpenQuests() >= BB.QUEST_MAX_OPEN then
    self:Print("|cffff4040" .. string.format(self.T("ERR_QUEST_MAX"), BB.QUEST_MAX_OPEN) .. "|r")
    return nil
  end
  local now = time()
  local id = "G" .. self:NewCodeId()
  while BananaBankDB.quests[id] do id = "G" .. self:NewCodeId() end
  local q = {
    id = id, c = self:Me(), ts = now, s = "open", u = now, by = self:Me(),
    due = (days and days > 0) and (now + days * 86400) or 0, rs = reserve and 1 or 0,
    title = title, text = text, items = items, meta = meta or {}, gold = gold,
    ic = cleanIcon(icon), tip = cleanText(tip or "", BB.QUEST_TIP_LEN),
  }
  BananaBankDB.quests[id] = q
  self.qDirty = true
  self:QLog("create", q, self:Me(), nil, id .. ":open:" .. q.u)
  self:PushQuests({ q })
  self:QuestTick()
  return q
end

function BB:EditQuest(q, title, text, items, meta, days, reserve, icon, tip, gold)
  if not self:CanManageQuests() then noPerm(self) return false end
  if q.s ~= "open" then return false end
  title = cleanText(title, BB.QUEST_TITLE_LEN)
  text = cleanText(text, BB.QUEST_TEXT_LEN)
  if title == "" then self:Print("|cffff4040" .. self.T("ERR_QUEST_TITLE") .. "|r") return false end
  gold = self:CleanGold(gold)
  if BB.Count(items) + BB.Count(gold) == 0 then self:Print("|cffff4040" .. self.T("ERR_QUEST_ITEMS") .. "|r") return false end
  if BB.Count(items) + BB.Count(gold) > BB.QUEST_MAX_ITEMS then
    self:Print("|cffff4040" .. string.format(self.T("ERR_QUEST_ITEM_MAX"), BB.QUEST_MAX_ITEMS) .. "|r")
    return false
  end
  q.title, q.text, q.items, q.meta, q.gold = title, text, items, meta or {}, gold
  if icon ~= nil then q.ic = cleanIcon(icon) end
  if tip ~= nil then q.tip = cleanText(tip, BB.QUEST_TIP_LEN) end
  q.rs = reserve and 1 or 0
  if days and days >= 0 then
    if days == 0 then q.due = 0 else q.due = time() + days * 86400 end
  end
  q.u = math.max(time(), (q.u or 0) + 1)
  q.by = self:Me()
  self.qDirty = true
  self:QLog("edit", q, self:Me(), nil, q.id .. ":open:" .. q.u)
  self:PushQuests({ q })
  self:QuestTick()
  return true
end

-- status: "closed" (abgeschlossen, Reservierung endet) oder "cancelled"
function BB:SetQuestStatus(q, status)
  if not self:CanManageQuests() then noPerm(self) return false end
  if (BB.QRANK[q.s] or 0) >= BB.QRANK[status] then return false end
  q.s = status
  q.u = math.max(time(), (q.u or 0) + 1)
  q.by = self:Me()
  self.qDirty = true
  self:QLog(status == "closed" and "close" or "cancel", q, self:Me(), nil, q.id .. ":" .. status .. ":" .. q.u)
  self:PushQuests({ q })
  self:QuestTick()
  return true
end

-- Auszahlung: die gelieferten (reservierten) Mengen einer Quest als bestaetigte Anfrage an einen
-- Empfaenger (z.B. den Schneider) schicken. Die Quest wird abgeschlossen, die Quest-Reservierung
-- endet und die Anfrage haelt dieselben Mengen reserviert, bis die Bank sie verschickt hat.
function BB:CreateQuestPayout(q, recipient)
  if not q then return nil end
  if not self:CanManageQuests() then noPerm(self) return nil end
  if q.s == "closed" or q.s == "cancelled" then return nil, "CLOSED" end
  recipient = BB.Clean(recipient or "")
  if recipient == "" then return nil, "NAME" end
  recipient = string.upper(string.sub(recipient, 1, 1)) .. string.lower(string.sub(recipient, 2))
  local st = self:QuestStats()[q.id]
  local items = {}
  if st then
    for iid, n in pairs(st.eff) do
      if n > 0 then items[iid] = n end
    end
  end
  if BB.Count(items) == 0 then return nil, "EMPTY" end
  local id = self:NewCodeId()
  while BananaBankDB.reqs[id] do id = self:NewCodeId() end
  local me = self:Me()
  local r = {
    id = id, p = recipient, ts = time(), items = items, s = "confirmed", u = time(), by = me, sent = {},
    qid = q.id,
  }
  r.code = self:BuildCode(id, recipient, items)
  BananaBankDB.reqs[id] = r
  self:PushRequests({ r })
  if recipient ~= me then self:Notify(r, "WHISPER_CONFIRMED") end
  self:QLog("payout", q, me, recipient .. " " .. id)
  if q.s ~= "closed" and q.s ~= "cancelled" then self:SetQuestStatus(q, "closed") end
  self.qDirty = true
  return r
end

-- ------------------------------------------------------------
-- Neu ausschreiben ("Wiederholen"): gleiche Items, Icon und Tooltip, neuer Name, Fortschritt 0
-- ------------------------------------------------------------
-- "Name #2" -> "Name #3": die hoechste vorhandene Nummer mit gleichem Namen plus 1
function BB:NextQuestTitle(title)
  local base = (string.gsub(title or "", "%s*#%d+$", ""))
  local n = 1
  for _, o in pairs(BananaBankDB.quests) do
    local ob = (string.gsub(o.title or "", "%s*#%d+$", ""))
    if ob == base then
      local _, _, num = string.find(o.title or "", "#(%d+)$")
      local nn = tonumber(num) or 1
      if nn > n then n = nn end
    end
  end
  local suffix = " #" .. (n + 1)
  return cutUtf8(base, BB.QUEST_TITLE_LEN - string.len(suffix)) .. suffix
end

-- Tage der urspruenglichen Laufzeit (0 = keine Frist)
function BB:QuestSpanDays(q)
  if q.due and q.due > 0 and q.ts and q.due > q.ts then
    return math.max(1, math.ceil((q.due - q.ts) / 86400))
  end
  return 0
end

-- closeOld: die alte Quest vorher abschliessen (gibt ihren Platz unter den aktiven Quests frei)
function BB:RepeatQuest(q, title, days, reserve, closeOld)
  if not q then return nil end
  if not self:CanManageQuests() then noPerm(self) return nil end
  title = cleanText(title, BB.QUEST_TITLE_LEN)
  if title == "" then self:Print("|cffff4040" .. self.T("ERR_QUEST_TITLE") .. "|r") return nil end
  local freed = (closeOld and q.s == "open") and 1 or 0
  if self:CountOpenQuests() - freed >= BB.QUEST_MAX_OPEN then
    self:Print("|cffff4040" .. string.format(self.T("ERR_QUEST_MAX"), BB.QUEST_MAX_OPEN) .. "|r")
    return nil
  end
  local items, meta = {}, {}
  for id, need in pairs(q.items) do
    items[id] = need
    local m = q.meta and q.meta[id]
    if m then meta[id] = { n = m.n, q = m.q, t = m.t } end
  end
  if closeOld and q.s == "open" then self:SetQuestStatus(q, "closed") end
  return self:CreateQuest(title, q.text or "", items, meta, days, reserve, q.ic, q.tip)
end

-- ------------------------------------------------------------
-- Chat: Quest als Text, Items als echte Item-Links
-- ------------------------------------------------------------
function BB:ItemLinkText(id, name, quality)
  local c = BB.QUALITY_COLOR[quality or 1] or BB.QUALITY_COLOR[1]
  return "|cff" .. c[4] .. "|Hitem:" .. id .. ":0:0:0|h[" .. name .. "]|h|r"
end

function BB:QuestItemLink(q, id)
  local name, quality = self:QuestItemInfo(q, id)
  return self:ItemLinkText(id, name, quality)
end

-- kurzer Text fuer die Eingabezeile (Shift-Klick auf die Quest)
function BB:QuestChatText(q)
  return "|cffffd100|Hbbquest:" .. q.id .. "|h[" .. self.T("QCHAT_TAG") .. ": " .. q.title .. "]|h|r"
end

-- Zeilen fuer den Gildenchat (je unter 250 Byte)
function BB:QuestChatLines(q)
  local s = self:QuestStats()[q.id]
  local lines = {}
  local head = string.format(self.T("QCHAT_HEAD"), q.title, s and s.done or 0, s and s.need or self:QuestNeed(q))
  if q.due and q.due > 0 then head = head .. string.format(self.T("QCHAT_DUE"), date("%d.%m.", q.due)) end
  table.insert(lines, head)
  local prefix = self.T("QCHAT_ITEMS")
  local cur = prefix
  local ids = {}
  for id in pairs(q.items) do table.insert(ids, id) end
  table.sort(ids)
  for i = 1, getn(ids) do
    local part = self:QuestItemLink(q, ids[i]) .. " x" .. q.items[ids[i]]
    if cur ~= prefix and string.len(cur) + string.len(part) + 2 > 245 then
      table.insert(lines, cur)
      cur = prefix
    end
    cur = (cur == prefix) and (cur .. part) or (cur .. ", " .. part)
  end
  if cur ~= prefix then table.insert(lines, cur) end
  if q.gold and BB.Count(q.gold) > 0 then
    local names = {}
    for bank, c in pairs(q.gold) do table.insert(names, bank .. " " .. BB.GoldText(c)) end
    table.sort(names)
    local gl = self.T("QCHAT_GOLD")
    for i = 1, getn(names) do
      local part = names[i]
      if string.len(gl) + string.len(part) + 2 > 245 then
        table.insert(lines, gl)
        gl = self.T("QCHAT_GOLD")
      end
      gl = (gl == self.T("QCHAT_GOLD")) and (gl .. part) or (gl .. ", " .. part)
    end
    table.insert(lines, gl)
  end
  table.insert(lines, self.T("QCHAT_HOW"))
  return lines
end

function BB:PostQuestToGuild(q)
  if not q then return false end
  if not self:CanManageQuests() then noPerm(self) return false end
  if not IsInGuild or not IsInGuild() then self:Print("|cffff4040" .. self.T("QCHAT_NOGUILD") .. "|r") return false end
  local lines = self:QuestChatLines(q)
  for i = 1, getn(lines) do
    local line = lines[i]
    self:After((i - 1) * 0.5, function() SendChatMessage(line, "GUILD") end)
  end
  self:Print(self.T("QCHAT_SENT"))
  return true
end

-- ------------------------------------------------------------
-- Netz: Quests serialisieren und zusammenfuehren
-- ------------------------------------------------------------
function BB:SerializeGold(g)
  local parts = {}
  for name, c in pairs(self:CleanGold(g)) do table.insert(parts, name .. ":" .. c) end
  table.sort(parts)
  return table.concat(parts, ",")
end

function BB:ParseGold(str)
  local g = {}
  for _, p in ipairs(BB.Split(str or "", ",")) do
    local f = BB.Split(p, ":")
    if f[1] and f[1] ~= "" and tonumber(f[2]) then g[f[1]] = tonumber(f[2]) end
  end
  return self:CleanGold(g)
end

function BB:SerializeQuests(list)
  local recs = {}
  for i = 1, getn(list) do
    local q = list[i]
    local its = {}
    for id, need in pairs(q.items) do
      local m = (q.meta and q.meta[id]) or {}
      table.insert(its, table.concat({ id, need, m.q or 1, BB.Clean(m.t or ""), cleanName(m.n or "") }, ":"))
    end
    table.insert(recs, table.concat({
      q.id, BB.Clean(q.c), q.ts or 0, q.s, q.u or 0, BB.Clean(q.by or ""), q.due or 0, q.rs or 0,
      cleanText(q.title, BB.QUEST_TITLE_LEN), cleanText(q.text or "", BB.QUEST_TEXT_LEN),
      table.concat(its, ","),
      cleanIcon(q.ic or ""), cleanText(q.tip or "", BB.QUEST_TIP_LEN),
      self:SerializeGold(q.gold),
    }, "~"))
  end
  return table.concat(recs, "^")
end

function BB:ParseQuests(payload)
  local out = {}
  for _, rec in ipairs(BB.Split(payload, "^")) do
    local f = BB.Split(rec, "~")
    if f[1] and string.len(f[1]) == 6 and BB.QRANK[f[4] or ""] and f[9] and f[9] ~= "" then
      local items, meta, n = {}, {}, 0
      for _, p in ipairs(BB.Split(f[11] or "", ",")) do
        local g = BB.Split(p, ":")
        local id, need = tonumber(g[1]), tonumber(g[2])
        if id and need and need > 0 and need <= 99999 and n < BB.QUEST_MAX_ITEMS then
          items[id] = need
          meta[id] = { q = tonumber(g[3]) or 1, t = g[4] or "", n = g[5] or ("#" .. id) }
          n = n + 1
        end
      end
      local gold = f[14] and BB:ParseGold(f[14]) or nil
      if n > 0 or (gold and BB.Count(gold) > 0) then
        table.insert(out, {
          id = f[1], c = f[2], ts = tonumber(f[3]) or 0, s = f[4], u = tonumber(f[5]) or 0,
          by = f[6], due = tonumber(f[7]) or 0, rs = tonumber(f[8]) or 0,
          title = cleanText(f[9], BB.QUEST_TITLE_LEN), text = cleanText(f[10] or "", BB.QUEST_TEXT_LEN),
          items = items, meta = meta,
          -- Felder 12/13 kennen nur Versionen ab 1.8.0; fehlen sie, bleibt der alte Wert erhalten (nil)
          ic = f[12] and cleanIcon(f[12]) or nil, tip = f[13] and cleanText(f[13], BB.QUEST_TIP_LEN) or nil,
          gold = gold,
        })
      end
    end
  end
  return out
end

function BB:PushQuests(list, full)
  if not list then
    list = self:QuestList()
    full = true
  end
  if getn(list) == 0 and not full then return end
  self:SendTransfer("G", full and "full" or "one", self:SerializeQuests(list))
end

function BB:QuestDigest()
  local n, sum = 0, 0
  for id, q in pairs(BananaBankDB.quests) do
    n = n + 1
    sum = mod(sum + BB.Hash(id .. q.s .. (q.u or 0)), 16777213)
  end
  return n, sum
end

-- Zustand aus dem Netz uebernehmen. Gibt true zurueck, wenn sich etwas geaendert hat.
function BB:MergeQuest(r)
  local db = BananaBankDB
  -- nur Quests von Quest-Verwaltern, geprueft in der EIGENEN Gildenliste
  if not self:CanManageQuests(r.by) then
    self:Debug("Quest von " .. tostring(r.by) .. " verworfen (kein Quest-Recht)")
    return false
  end
  local cur = db.quests[r.id]
  if not cur then
    db.quests[r.id] = r
    self.qDirty = true
    self:QLog("create", r, r.c, nil, r.id .. ":open:" .. r.ts)
    if r.s ~= "open" then
      self:QLog(r.s == "closed" and "close" or "cancel", r, r.by, nil, r.id .. ":" .. r.s .. ":" .. r.u)
    end
    return true
  end
  local rc, rn = BB.QRANK[cur.s] or 0, BB.QRANK[r.s] or 0
  local changed = false
  if rn > rc then
    cur.s = r.s
    changed = true
    self:QLog(r.s == "closed" and "close" or "cancel", cur, r.by, nil, r.id .. ":" .. r.s .. ":" .. r.u)
  end
  if r.u > (cur.u or 0) and rn >= rc then
    if rn == rc and rn == 1 then
      cur.title, cur.text, cur.items, cur.meta = r.title, r.text, r.items, r.meta
      cur.due, cur.rs = r.due, r.rs
      if r.gold ~= nil then cur.gold = r.gold end
      if r.ic ~= nil then cur.ic = r.ic end
      if r.tip ~= nil then cur.tip = r.tip end
      self:QLog("edit", cur, r.by, nil, r.id .. ":open:" .. r.u)
    end
    cur.u, cur.by = r.u, r.by
    changed = true
  elseif rn > rc then
    cur.u, cur.by = math.max(cur.u or 0, r.u), r.by
  end
  if changed then self.qDirty = true end
  return changed
end

-- ------------------------------------------------------------
-- Ereignisse: neue Quest, fertig, abgelaufen ... (nur Meldungen, kein Zustand)
-- ------------------------------------------------------------
function BB:QuestTick()
  local db = BananaBankDB
  if not db then return end
  local first = not self.qSeen
  self.qSeen = self.qSeen or {}
  local stats = self:QuestStats()
  for id, q in pairs(db.quests) do
    local st = self:QuestState(q)
    local prev = self.qSeen[id]
    if not first and prev ~= st then
      if prev == nil and (st == "open" or st == "complete") then
        self:Print(string.format(self.T("QMSG_NEW"), q.title, q.by or "?"))
        if self.UI and self.UI.ShowQuestToast then
          self.UI:ShowQuestToast(self.T("QTOAST_NEW"), q.title, false)
        end
      elseif st == "complete" then
        local top = self:QuestTop(q)
        local best = top[1] and top[1].p or "-"
        self:Print(string.format(self.T("QMSG_DONE"), q.title, best))
        self:QLog("complete", q, "-", best, id .. ":complete")
        if self.UI and self.UI.ShowQuestToast then
          self.UI:ShowQuestToast(self.T("QTOAST_DONE"), q.title .. "  |cffa8a8c0" .. string.format(self.T("QTOAST_BEST"), best) .. "|r", true)
        end
      elseif st == "expired" then
        self:Print(string.format(self.T("QMSG_EXPIRED"), q.title))
        self:QLog("expire", q, "-", nil, id .. ":expire")
      elseif st == "closed" then
        self:Print(string.format(self.T("QMSG_CLOSED"), q.title, q.by or "?"))
      elseif st == "cancelled" then
        self:Print(string.format(self.T("QMSG_CANCELLED"), q.title, q.by or "?"))
      end
    end
    self.qSeen[id] = st
  end
  if self.UI then
    if self.UI.RefreshQuestTracker then self.UI:RefreshQuestTracker() end
    self.UI:Refresh()
  end
end

-- einmal pro Minute: Fristen pruefen
local tickFrame = CreateFrame("Frame")
local tickAcc = 0
tickFrame:SetScript("OnUpdate", function()
  tickAcc = tickAcc + (arg1 or 0)
  if tickAcc < 60 then return end
  tickAcc = 0
  if BananaBankDB and BB.qSeen then BB:QuestTick() end
end)


-- ------------------------------------------------------------
-- Nachtraege (nur Bank-Chars, deren Buchungen die anderen akzeptieren)
-- ------------------------------------------------------------
local function bankOnly(self)
  if self:IsBank() and self:MayBeBank(self:Me()) then return true end
  self:Print("|cffff4040" .. self.T("ERR_NOT_BANK") .. "|r")
  return false
end

-- Spenden, die nach dem Anlegen einer Quest gebucht wurden, aber keiner Quest zugeordnet sind,
-- nachtraeglich der Quest gutschreiben. Die alten Eintraege bleiben unveraendert, der Nachtrag
-- ist ein eigener Eintrag (k = qfix, g = ID der Spende), so sehen es alle Clients gleich.
function BB:CreditQuestDeliveries()
  if not bankOnly(self) then return end
  local db = BananaBankDB
  local credited = {}
  for _, e in pairs(db.ledger) do
    if e.k == "qfix" and e.g ~= "" then credited[e.g] = (credited[e.g] or 0) + (e.c or 0) end
  end
  local entries = {}
  for _, e in pairs(db.ledger) do
    if e.k == "in" and e.code == "" then table.insert(entries, e) end
  end
  table.sort(entries, function(a, b)
    if a.t ~= b.t then return a.t < b.t end
    return a.id < b.id
  end)
  local quests = {}
  for _, qu in pairs(db.quests) do
    if qu.s == "open" then table.insert(quests, qu) end
  end
  table.sort(quests, function(a, b)
    if a.ts ~= b.ts then return a.ts < b.ts end
    return a.id < b.id
  end)
  local made, units = 0, 0
  for qi = 1, getn(quests) do
    local qu = quests[qi]
    for ei = 1, getn(entries) do
      local e = entries[ei]
      local left = e.c - (credited[e.id] or 0)
      if left > 0 and e.t >= qu.ts then
        -- passendes Quest-Item: ID oder Name
        local iid
        for id in pairs(qu.items) do
          local m = qu.meta and qu.meta[id]
          local lname = GetItemInfo(id)
          if id == e.i or (lname and lname == e.n) or (m and m.n == e.n) then iid = id end
        end
        if iid then
          local s = self:QuestStats()[qu.id]
          local need = qu.items[iid] - ((s and s.got[iid]) or 0)
          if need > 0 then
            local take = left
            if take > need then take = need end
            self:AddLedger({ k = "qfix", p = e.p, n = e.n, c = take, q = e.q, i = iid, code = qu.id, g = e.id, t = e.t })
            credited[e.id] = (credited[e.id] or 0) + take
            made = made + 1
            units = units + take
          end
        end
      end
    end
  end
  if made > 0 then
    self:QLog("credit", nil, self:Me(), string.format("%d Eintraege, %d Items", made, units))
    self:QuestTick()
  end
  self:Print(string.format(self.T("QCREDIT_DONE"), made, units))
end

-- Eine Spende von Hand buchen (z.B. wenn Post angenommen wurde, ohne dass sie erfasst wurde)
function BB:ManualBook(player, count, itemText)
  if not bankOnly(self) then return end
  count = tonumber(count)
  itemText = string.lower(itemText or "")
  if not player or player == "" or not count or count < 1 or itemText == "" then
    self:Print(self.T("QBOOK_USAGE"))
    return
  end
  count = floor(count)
  local matches = {}
  local exact
  for id, e in pairs(self:GetStock()) do
    local nm = string.lower(e.n or "")
    if nm == itemText then exact = { id = id, e = e } end
    if string.find(nm, itemText, 1, true) then table.insert(matches, { id = id, e = e }) end
  end
  local pick = exact
  if not pick then
    if getn(matches) == 0 then
      self:Print(string.format(self.T("QBOOK_NOITEM"), itemText))
      return
    elseif getn(matches) > 1 then
      local names = {}
      for i = 1, getn(matches) do
        if getn(names) < 5 then table.insert(names, matches[i].e.n) end
      end
      self:Print(string.format(self.T("QBOOK_MANY"), table.concat(names, ", ")))
      return
    end
    pick = matches[1]
  end
  self:BookDonation(BB.Clean(player), pick.e.n, count, pick.e.q or 1, pick.id, "")
  self:Print(string.format(self.T("QBOOK_DONE"), count, pick.e.n, player))
end
