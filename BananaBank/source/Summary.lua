-- BananaBank Spendenbuch-Auswertung: Stacks, Summen je Item, Summen je Mitglied
--
-- Ein Buchungseintrag ist schon ein Stack (ein Post-Anhang oder ein Handelsfeld). Hat die Bank
-- eine Lieferung auf mehrere Quests aufgeteilt, tragen die Teile dieselbe Gruppe (Feld g) und
-- werden hier wieder zu EINEM Stack zusammengesetzt.

local BB = BananaBank
local getn = table.getn
local floor = math.floor

BB.summaryModule = true

local function newStack(e)
  return {
    id = e.id, t = e.t, p = e.p, i = e.i or 0, n = e.n, q = e.q or 1, c = e.c or 0, m = e.m or 0,
    code = e.code or "", parts = { { code = e.code or "", c = e.c or 0 } },
  }
end

local function byTimeDesc(a, b)
  if a.t ~= b.t then return a.t > b.t end
  return tostring(a.id) > tostring(b.id)
end

-- mode: "in" (Spenden) oder "out" (Entnahmen); who: Spielername oder nil fuer alle
function BB:LedgerStacks(mode, who)
  local want = (mode == "out") and "out" or "in"
  local groups, list = {}, {}
  for _, e in pairs(BananaBankDB.ledger) do
    if e.k == want and (not who or e.p == who) and not (want == "in" and self:IsSystemSender(e.p)) then
      local g = e.g
      local s = (g and g ~= "") and groups[g] or nil
      if s then
        s.c = s.c + (e.c or 0)
        s.m = s.m + (e.m or 0)
        if e.t < s.t then s.t = e.t end
        table.insert(s.parts, { code = e.code or "", c = e.c or 0 })
      else
        s = newStack(e)
        if g and g ~= "" then groups[g] = s end
        table.insert(list, s)
      end
    end
  end
  table.sort(list, byTimeDesc)
  return list
end

-- Icon zu Item-ID oder Name (der Bestand kennt die meisten Items)
function BB:SummaryIcon(id, name)
  if (not id or id == 0) and name then id = self:IdByName(name) end
  if id and id ~= 0 then
    local _, _, tex = self:ItemInfo(id)
    return BB.FullTex(tex), id
  end
  return BB.FullTex(""), 0
end

-- Quelle eines Stacks als Text
function BB:StackSource(s, mode)
  if mode == "out" then
    if s.code == "TRADE" then return self.T("MW_SRC_TRADE") end
    if s.code ~= "" then return string.format(self.T("MW_SRC_REQUEST"), s.code) end
    return ""
  end
  local title
  for i = 1, getn(s.parts) do
    local q = s.parts[i].code ~= "" and BananaBankDB.quests[s.parts[i].code]
    if q then title = q.title end
  end
  if title then return string.format(self.T("MW_SRC_QUEST"), title) end
  return self.T("MW_SRC_DONATION")
end

-- Alles zu einem Mitglied. mode "in": was gespendet wurde, "out": was erhalten wurde.
-- rows = chronologisch (neueste zuerst), items = Summe je Item
function BB:MemberData(name, mode)
  local db = BananaBankDB
  local d = { rows = {}, items = {}, nstacks = 0, nitems = 0, gold = 0, paid = 0, back = 0 }
  local stacks = self:LedgerStacks(mode, name)
  local map = {}
  d.nstacks = getn(stacks)
  for i = 1, getn(stacks) do
    local s = stacks[i]
    table.insert(d.rows, { kind = "stack", t = s.t, s = s })
    d.nitems = d.nitems + s.c
    local it = map[s.n]
    if not it then
      it = { n = s.n, i = s.i, q = s.q, total = 0, stacks = 0, last = 0, back = 0 }
      map[s.n] = it
      table.insert(d.items, it)
    end
    if it.i == 0 then it.i = s.i end
    it.total = it.total + s.c
    it.stacks = it.stacks + 1
    if s.t > it.last then it.last = s.t end
  end
  for _, e in pairs(db.ledger) do
    if e.p == name then
      if mode == "in" and e.k == "gold" then
        d.gold = d.gold + (e.m or 0)
        table.insert(d.rows, { kind = "money", t = e.t, m = e.m or 0, label = "gold" })
      elseif mode == "out" and e.k == "gout" then
        d.gold = d.gold + (e.m or 0)
        table.insert(d.rows, { kind = "money", t = e.t, m = e.m or 0, label = "gout" })
      elseif mode == "out" and e.k == "cod" then
        d.paid = d.paid + (e.m or 0)
        table.insert(d.rows, { kind = "money", t = e.t, m = e.m or 0, label = "cod" })
      elseif mode == "out" and e.k == "back" then
        d.back = d.back + (e.c or 0)
        table.insert(d.rows, { kind = "back", t = e.t, e = e })
        local it = map[e.n]
        if it then it.back = it.back + (e.c or 0) end
      end
    end
  end
  table.sort(d.rows, function(a, b)
    if a.t ~= b.t then return a.t > b.t end
    return tostring(a.s and a.s.id or a.e and a.e.id or "") > tostring(b.s and b.s.id or b.e and b.e.id or "")
  end)
  for i = 1, getn(d.items) do
    local it = d.items[i]
    it.net = it.total - it.back
    if it.net < 0 then it.net = 0 end
  end
  table.sort(d.items, function(a, b)
    if a.net ~= b.net then return a.net > b.net end
    return a.n < b.n
  end)
  return d
end

-- Summen ueber die ganze Gilde: je Material gesamt, Stacks, Spender
function BB:GuildTotals(mode)
  local stacks = self:LedgerStacks(mode, nil)
  local map, list = {}, {}
  local players = {}
  local g = { items = list, nitems = 0, nstacks = getn(stacks), nplayers = 0, gold = 0 }
  for i = 1, getn(stacks) do
    local s = stacks[i]
    local it = map[s.n]
    if not it then
      it = { n = s.n, i = s.i, q = s.q, total = 0, stacks = 0, last = 0, who = {}, back = 0 }
      map[s.n] = it
      table.insert(list, it)
    end
    if it.i == 0 then it.i = s.i end
    it.total = it.total + s.c
    it.stacks = it.stacks + 1
    it.who[s.p] = (it.who[s.p] or 0) + s.c
    if s.t > it.last then it.last = s.t end
    players[s.p] = true
  end
  for _, e in pairs(BananaBankDB.ledger) do
    if mode == "in" and e.k == "gold" and not self:IsSystemSender(e.p) then g.gold = g.gold + (e.m or 0) end
    if mode == "out" and e.k == "gout" then g.gold = g.gold + (e.m or 0) end
    if mode == "out" and e.k == "back" and map[e.n] then
      local it = map[e.n]
      it.back = it.back + (e.c or 0)
      if it.who[e.p] then it.who[e.p] = math.max(0, it.who[e.p] - (e.c or 0)) end
    end
  end
  local out = {}
  for i = 1, getn(list) do
    local it = list[i]
    it.net = it.total - it.back
    if it.net < 0 then it.net = 0 end
    if it.net > 0 then
      g.nitems = g.nitems + it.net
      table.insert(out, it)
    end
  end
  g.items = out
  for _ in pairs(players) do g.nplayers = g.nplayers + 1 end
  table.sort(g.items, function(a, b)
    if a.net ~= b.net then return a.net > b.net end
    return a.n < b.n
  end)
  return g
end

-- Spender eines Materials, absteigend: { {p=, c=}, ... }
function BB:ItemDonors(it)
  local list = {}
  for p, c in pairs(it.who or {}) do
    if c > 0 then table.insert(list, { p = p, c = c }) end
  end
  table.sort(list, function(a, b)
    if a.c ~= b.c then return a.c > b.c end
    return a.p < b.p
  end)
  return list
end


-- /bb ledger [N | Text | today]: letzte Buchungen im Chat, zum Gegenpruefen
local KIND_NAME = { ["in"] = "KIND_IN", out = "KIND_OUT", gold = "KIND_GOLD", gout = "KIND_GOUT", back = "KIND_BACK", cod = "KIND_COD", qfix = "KIND_QFIX", trash = "KIND_TRASH" }

function BB:PrintLedger(arg)
  arg = string.lower(arg or "")
  local list = self:LedgerSorted()   -- neueste zuerst
  local out = {}
  local limit = 15
  local since
  local text
  if arg == "today" or arg == "heute" then
    local d = date("*t")
    since = time({ year = d.year, month = d.month, day = d.day, hour = 0, min = 0, sec = 0 })
    limit = 60
  elseif tonumber(arg) then
    limit = math.min(60, math.max(1, floor(tonumber(arg))))
  elseif arg ~= "" then
    text = arg
    limit = 30
  end
  for i = 1, getn(list) do
    local e = list[i]
    local ok = true
    if since and e.t < since then ok = false end
    if text and not (string.find(string.lower(e.p or ""), text, 1, true) or string.find(string.lower(e.n or ""), text, 1, true)) then ok = false end
    if ok then table.insert(out, e) end
    if getn(out) >= limit then break end
  end
  self:Print(string.format(self.T("LEDGER_PRINT_HEAD"), getn(out), getn(list)))
  for i = getn(out), 1, -1 do
    local e = out[i]
    local what
    if e.k == "gold" or e.k == "gout" or e.k == "cod" or e.k == "trash" then
      what = BB.Money(e.m)
    else
      what = (e.c or 0) .. "x " .. (e.n or "?")
    end
    local line = date("%d.%m. %H:%M", e.t) .. "  " .. self.T(KIND_NAME[e.k] or "KIND_IN") .. "  " .. (e.p or "?") .. "  " .. what
    local qq = e.code ~= "" and BananaBankDB.quests and BananaBankDB.quests[e.code]
    if qq then line = line .. "  |cffffd100[" .. qq.title .. "]|r"
    elseif e.code ~= "" then line = line .. "  |cff9a9cb3" .. e.code .. "|r" end
    DEFAULT_CHAT_FRAME:AddMessage(line)
  end
end
