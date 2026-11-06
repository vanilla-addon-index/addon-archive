-- BananaBank Regelsatz: wer darf anfragen, und welche Qualitaet ab welchem Rang.
-- Wird nur von einem Char mit dem Rang Gildenbank gepflegt und mit der Gilde synchronisiert.
-- Ohne gespeicherten Regelsatz sind alle Anfragen gesperrt.

local BB = BananaBank
local getn = table.getn

BB.rulesModule = true
BB.RULE_KEYS = { "req", "q2", "q3", "q4" }

-- ------------------------------------------------------------
-- Raenge: Name und Position (0 = hoechster Rang)
-- ------------------------------------------------------------
function BB:RankList()
  if self.rankListCache then return self.rankListCache end
  local out, seen = {}, {}
  local n = GuildControlGetNumRanks and GuildControlGetNumRanks() or 0
  if n and n > 0 and GuildControlGetRankName then
    for i = 1, n do
      local name = GuildControlGetRankName(i)
      if name and name ~= "" then
        table.insert(out, { i = i - 1, n = name })
        seen[i - 1] = true
      end
    end
  end
  for _, e in pairs(BananaBankDB.ranks) do
    if e.r and e.i and not seen[e.i] then
      seen[e.i] = true
      table.insert(out, { i = e.i, n = e.r })
    end
  end
  table.sort(out, function(a, b) return a.i < b.i end)
  self.rankListCache = out
  return out
end

-- Rang einer Regel aufloesen: erst nach Name, sonst nach Position (Rang wurde umbenannt).
-- Gibt Position, aktuellen Namen und ob der Name noch stimmt zurueck.
function BB:RuleRank(spec)
  if not spec then return nil end
  local list = self:RankList()
  local want = string.lower(spec.n or "")
  for i = 1, getn(list) do
    if string.lower(list[i].n) == want then return list[i].i, list[i].n, true end
  end
  for i = 1, getn(list) do
    if list[i].i == spec.i then return spec.i, list[i].n, false end
  end
  return spec.i, nil, false
end

-- ------------------------------------------------------------
-- Pruefung
-- ------------------------------------------------------------
local QKEY = { [2] = "q2", [3] = "q3" }

-- Darf dieser Spieler anfragen (und dieses Qualitaetsstufe)? true | false, Grund, Rangname
-- Gruende: NORULES, UNKNOWN, RANK, QUALITY (dann Rangname und Regelschluessel)
function BB:CanRequest(name, q)
  name = name or self:Me()
  if self:MayBeBank(name) then return true end
  local rules = BananaBankDB.rules
  if not rules or not rules.req then return false, "NORULES" end
  local e = BananaBankDB.ranks[name]
  if not e then return false, "UNKNOWN" end
  local reqI, reqN = self:RuleRank(rules.req)
  if not reqI or e.i > reqI then return false, "RANK", reqN or rules.req.n end
  if q and q >= 2 then
    local key = q >= 4 and "q4" or QKEY[q]
    local qi, qn = self:RuleRank(rules[key])
    if not qi or e.i > qi then return false, "QUALITY", qn or (rules[key] and rules[key].n) or "?", key end
  end
  return true
end

-- Text fuer den Spieler, warum etwas gesperrt ist (nil = erlaubt)
function BB:BlockText(name, q)
  local ok, why, rank, key = self:CanRequest(name, q)
  if ok then return nil end
  if why == "NORULES" then return self.T("RB_NORULES") end
  if why == "UNKNOWN" then return self.T("RB_UNKNOWN") end
  if why == "RANK" then return string.format(self.T("RB_RANK"), rank or "?") end
  return string.format(self.T("RB_QUALITY"), self.T("RB_" .. string.upper(key or "q2")), rank or "?")
end

function BB:ItemBlockText(name, id)
  local _, q = self:ItemInfo(id)
  local t = self:BlockText(name, q)
  if t then return t end
  if self:MayBeBank(name) then return nil end
  -- Klassen-Items nur fuer die passende Klasse
  if self.ClassBlockText then
    local ct = self:ClassBlockText(name, id)
    if ct then return ct end
  end
  -- ohne Preis nicht anfragbar: nicht im Auktionshaus gefunden oder noch nicht gescannt
  if not self:GetPrice(id) then return self.T("RB_NOPRICE") end
  -- Rezepte: nur einmal ueber die Gildenbank, und nur, wenn der Char es benutzen kann
  local rt = self:RecipeBlockText(name, id)
  if rt then return rt end
  if self:InDepotOnly(id) then return self.T("RB_DEPOT") end
  return nil
end

-- Pruefung einer fertigen Anfrage durch die Bank. Gibt true oder false und die Liste der Verstoesse zurueck.
-- Rezepte (zum AH-Preis wie zum Gildencrafter-Anspruch): 1. hat dieser Char es schon ueber die Gildenbank
-- bekommen (laut Buch), dann kein zweites; 2. auf dem eigenen Client: Beruf gescannt, Rezept noch nicht
-- gelernt, Skill reicht. Berufe und gelernte Rezepte kennt nur der eigene Client, die Bank prueft das Buch.
function BB:RecipeBlockText(name, id)
  local e = self.stockCache and self.stockCache[id]
  if not e then return nil end
  local k, sub = self:ResolveCategory(id, e)
  if k ~= "recipe" then return nil end
  local got = self.RecipeReceived and self:RecipeReceived(name, e.n or "")
  if got then return string.format(self.T("RB_RECIPE_OWNED"), BB.Date(got)) end
  if name == self:Me() and sub and self.RecipeUsable then
    local ok, why, n = self:RecipeUsable(id, e, sub)
    if not ok then
      if why == "NOSCAN" then return string.format(self.T("CR_NOSCAN"), self.T("SUB_" .. string.upper(n or "other"))) end
      if why == "SKILL" then return string.format(self.T("CR_SKILL"), n or 0) end
      return self.T("CR_" .. why)
    end
  end
  return nil
end

function BB:CheckRequestRules(r)
  local bad = {}
  local ok, why = self:CanRequest(r.p, nil)
  if not ok then
    table.insert(bad, { why = why, text = self:BlockText(r.p, nil) })
    return false, bad
  end
  for id in pairs(r.items) do
    local t = self:ItemBlockText(r.p, id)
    if t then
      table.insert(bad, { id = id, text = t })
    elseif r.items[id] > 1 and not self:MayBeBank(r.p) then
      -- ein Rezept nur einmal pro Anfrage
      local e = self.stockCache and self.stockCache[id]
      if e and (self:ResolveCategory(id, e)) == "recipe" then
        table.insert(bad, { id = id, text = self.T("RB_RECIPE_ONE") })
      end
    end
  end
  return getn(bad) == 0, bad
end

-- ------------------------------------------------------------
-- Speichern und Synchronisieren
-- ------------------------------------------------------------

-- Lagertypen: frei benennbar, erscheinen im Baum unter "Nur ansehen". Standard: Willkommenspakete und Raid Stuff.
BB.DEPOT_TYPE_MAX = 6
BB.DEPOT_MAX = 4

local function cleanLabel(x)
  x = BB.Clean(x or "")
  x = string.gsub(x, "[;:,]", "")
  x = string.gsub(x, "^%s+", "")
  x = string.gsub(x, "%s+$", "")
  if string.len(x) > 24 then x = string.sub(x, 1, 24) end
  return x
end
BB.CleanDepotLabel = cleanLabel

-- Liste { id = , name = } mit aufgeloesten Namen (Standardtypen ohne Namen heissen wie in der Sprache)
function BB:DepotTypes()
  local rules = BananaBankDB.rules
  local out = {}
  local list = rules and rules.depotTypes
  if list then
    for i = 1, getn(list) do
      local t = list[i]
      local name = t.name
      if not name or name == "" then
        if t.id == "welcome" then name = self.T("DEPOT_WELCOME") elseif t.id == "raid" then name = self.T("DEPOT_RAID") else name = t.id end
      end
      table.insert(out, { id = t.id, name = name })
    end
    return out
  end
  return { { id = "welcome", name = self.T("DEPOT_WELCOME") }, { id = "raid", name = self.T("DEPOT_RAID") } }
end

-- Arbeitskopie der Typen fuer die Einstellungen
function BB:DepotTypeListForEdit()
  local out = {}
  local list = self:DepotTypes()
  for i = 1, getn(list) do table.insert(out, { id = list[i].id, name = list[i].name }) end
  return out
end

function BB:DepotTypeById(id)
  local list = self:DepotTypes()
  for i = 1, getn(list) do
    if list[i].id == id then return list[i] end
  end
  return nil
end

-- Lagerchars: Liste { n = Name, k = Typ-ID }. Ihr Bestand ist nur im eigenen Eintrag zu sehen.
-- (Aeltere Staende hatten eine Zuordnung Art -> Name; die wird hier mit gelesen.)
function BB:DepotList()
  local out = {}
  local d = BananaBankDB.rules and BananaBankDB.rules.depots
  if not d then return out end
  if d[1] ~= nil then
    for i = 1, getn(d) do
      if d[i].n and d[i].n ~= "" then table.insert(out, { n = d[i].n, k = d[i].k }) end
    end
  else
    for kind, name in pairs(d) do
      if type(name) == "string" and name ~= "" then table.insert(out, { n = name, k = kind }) end
    end
  end
  return out
end

function BB:DepotChars()
  local map = {}
  local list = self:DepotList()
  for i = 1, getn(list) do map[list[i].n] = list[i].k end
  return map
end

function BB:DepotHas(kind)
  local list = self:DepotList()
  for i = 1, getn(list) do
    if list[i].k == kind then return true end
  end
  return false
end

function BB:DepotOf(name)
  if not name then return nil end
  return self:DepotChars()[name]
end

-- Bestand der Lagerchars einer Art, wie GetStock aufgebaut
function BB:DepotStock(kind)
  local out = {}
  local db = BananaBankDB
  for name, k in pairs(self:DepotChars()) do
    local snap = k == kind and db.snaps[name]
    if snap and self:MayBeBank(name) then
      for id, it in pairs(snap.items) do
        local e = out[id]
        if not e then
          e = { c = 0, q = it.q, t = it.t, n = it.n, per = {} }
          out[id] = e
        end
        if it.k and not e.k then e.k = it.k end
        if it.s and not e.s then e.s = it.s end
        e.c = e.c + it.c
        e.per[name] = (e.per[name] or 0) + it.c
      end
    end
  end
  return out
end

function BB:SaveRules(edit)
  local me = self:Me()
  if not self:MayBeBank(me) then
    self:Print("|cffff4040" .. self.T("RL_NOPERM") .. "|r")
    return false
  end
  for i = 1, getn(BB.RULE_KEYS) do
    local sp = edit[BB.RULE_KEYS[i]]
    if not sp or not sp.n then
      self:Print("|cffff4040" .. self.T("RL_INCOMPLETE") .. "|r")
      return false
    end
  end
  local db = BananaBankDB
  local old = db.rules and db.rules.ts or 0
  local rules = { ts = math.max(time(), old + 1), by = me }
  for i = 1, getn(BB.RULE_KEYS) do
    local sp = edit[BB.RULE_KEYS[i]]
    rules[BB.RULE_KEYS[i]] = { n = sp.n, i = sp.i }
  end
  -- Lagertypen (nur wenn bearbeitet, sonst bleiben die bisherigen)
  local types = {}
  local ids = {}
  if edit.depotTypes then
    local nextNum = 1
    for i = 1, getn(edit.depotTypes) do
      local id = edit.depotTypes[i].id
      local num = id and tonumber(string.sub(id, 2))
      if num and string.sub(id, 1, 1) == "c" and num >= nextNum then nextNum = num + 1 end
    end
    for i = 1, getn(edit.depotTypes) do
      local t = edit.depotTypes[i]
      local name = cleanLabel(t.name)
      local id = t.id
      if name ~= "" and getn(types) < BB.DEPOT_TYPE_MAX then
        if not id or id == "" then id = "c" .. nextNum nextNum = nextNum + 1 end
        if not ids[id] then
          ids[id] = true
          table.insert(types, { id = id, name = name })
        end
      end
    end
    rules.depotTypes = types
  else
    local cur = self:DepotTypes()
    for i = 1, getn(cur) do ids[cur[i].id] = true end
    if db.rules and db.rules.depotTypes then rules.depotTypes = db.rules.depotTypes end
  end
  -- Lagerchars (optional)
  rules.depots = {}
  local seen = {}
  for i = 1, getn(edit.depots or {}) do
    local d = edit.depots[i]
    local n = d.n and d.n ~= "" and BB.CleanCharName(d.n) or nil
    if n and d.k and ids[d.k] and not seen[n] and getn(rules.depots) < BB.DEPOT_MAX then
      seen[n] = true
      table.insert(rules.depots, { n = n, k = d.k })
    end
  end
  -- Keywords (Offiziersnotiz): nur wenn bearbeitet, sonst bleiben die bisherigen
  if edit.keywords then
    rules.keywords = {}
    local used = {}
    for i = 1, getn(edit.keywords) do
      local k = edit.keywords[i]
      local kw = BB.CleanKeyword(k.kw)
      if kw ~= "" and k.prof and BB.KW_PROF_SET[k.prof] and not used[kw] and getn(rules.keywords) < BB.KW_MAX then
        used[kw] = true
        table.insert(rules.keywords, { kw = kw, prof = k.prof })
      end
    end
  elseif db.rules and db.rules.keywords then
    rules.keywords = db.rules.keywords
  end
  db.rules = rules
  self:PushRules()
  self:Print(self.T("RL_SAVED_MSG"))
  if self.UI then self.UI:Refresh() end
  return true
end

local function cleanName(s)
  s = BB.Clean(s or "")
  s = string.gsub(s, ",", "")
  return s
end

function BB:SerializeRules(rules)
  local parts = { rules.ts, BB.Clean(rules.by or "") }
  for i = 1, getn(BB.RULE_KEYS) do
    local sp = rules[BB.RULE_KEYS[i]]
    table.insert(parts, cleanName(sp.n) .. "," .. (sp.i or 0))
  end
  local dep = {}
  local list = {}
  local d = rules.depots
  if d and d[1] ~= nil then list = d
  elseif d then for kind, name in pairs(d) do table.insert(list, { n = name, k = kind }) end end
  for i = 1, getn(list) do
    if list[i].n and list[i].n ~= "" then table.insert(dep, list[i].k .. ":" .. cleanName(list[i].n)) end
  end
  table.insert(parts, table.concat(dep, ";"))
  local ty = {}
  local tl = rules.depotTypes
  if tl then
    for i = 1, getn(tl) do
      if tl[i].id and tl[i].name and tl[i].name ~= "" then table.insert(ty, tl[i].id .. ":" .. cleanLabel(tl[i].name)) end
    end
  end
  local tyStr = "*"                       -- Standardtypen
  if tl then tyStr = (getn(ty) > 0) and table.concat(ty, ";") or "-" end
  table.insert(parts, tyStr)
  local kws = {}
  for i = 1, getn(rules.keywords or {}) do
    local k = rules.keywords[i]
    table.insert(kws, k.kw .. ":" .. k.prof)
  end
  table.insert(parts, (getn(kws) > 0) and table.concat(kws, ";") or "-")
  return table.concat(parts, "~")
end

function BB:ParseRules(payload)
  local f = BB.Split(payload or "", "~")
  local ts = tonumber(f[1])
  if not ts or not f[2] or f[2] == "" then return nil end
  local rules = { ts = ts, by = f[2] }
  for i = 1, getn(BB.RULE_KEYS) do
    local sp = BB.Split(f[2 + i] or "", ",")
    if not sp[1] or sp[1] == "" or not tonumber(sp[2]) then return nil end
    rules[BB.RULE_KEYS[i]] = { n = sp[1], i = tonumber(sp[2]) }
  end
  -- Typen zuerst, damit die Lagerchars auf gueltige Typen zeigen ("*" oder fehlend = Standardtypen)
  if f[8] ~= nil and f[8] ~= "*" then
    local types = {}
    if f[8] ~= "-" then
      for _, part in ipairs(BB.Split(f[8], ";")) do
        local d = BB.Split(part, ":")
        local id, name = d[1], cleanLabel(d[2] or "")
        if id and string.find(id, "^[%a%d]+$") and name ~= "" and getn(types) < BB.DEPOT_TYPE_MAX then
          table.insert(types, { id = id, name = name })
        end
      end
    end
    rules.depotTypes = types
  end
  rules.keywords = {}
  if f[9] and f[9] ~= "-" then
    for _, part in ipairs(BB.Split(f[9], ";")) do
      local d = BB.Split(part, ":")
      local kw = BB.CleanKeyword(d[1])
      if kw ~= "" and d[2] and BB.KW_PROF_SET[d[2]] and getn(rules.keywords) < BB.KW_MAX then
        table.insert(rules.keywords, { kw = kw, prof = d[2] })
      end
    end
  end
  local valid = { welcome = true, raid = true }
  if rules.depotTypes then
    valid = {}
    for i = 1, getn(rules.depotTypes) do valid[rules.depotTypes[i].id] = true end
  end
  rules.depots = {}
  for _, part in ipairs(BB.Split(f[7] or "", ";")) do
    local d = BB.Split(part, ":")
    local kind = d[1]
    if valid[kind] and BB.CleanCharName and d[2] and BB.CleanCharName(d[2]) and getn(rules.depots) < BB.DEPOT_MAX then
      table.insert(rules.depots, { n = BB.CleanCharName(d[2]), k = kind })
    end
  end
  return rules
end

function BB:PushRules()
  local rules = BananaBankDB.rules
  if not rules then return end
  self:SendTransfer("R", "one", self:SerializeRules(rules))
end

-- Nur von einem verifizierten Bank-Char (Rang laut eigener Gildenliste), neuerer Stand gewinnt
function BB:MergeRules(payload)
  local r = self:ParseRules(payload)
  if not r then return false end
  local cur = BananaBankDB.rules
  if r.ts > time() + 86400 or (cur and r.ts <= (cur.ts or 0)) then return false end
  if not self:MayBeBank(r.by) then
    self:Debug("Regeln von " .. tostring(r.by) .. " verworfen (kein Bank-Rang)")
    return false
  end
  BananaBankDB.rules = r
  if self.UI then self.UI:Refresh() end
  return true
end


-- ------------------------------------------------------------
-- Keywords in der Offiziersnotiz: [B, GSN, GE]
-- ------------------------------------------------------------
BB.KW_PROFS = { "alch", "bs", "ench", "eng", "lw", "tail", "jc", "cook", "fa" }
BB.KW_PROF_SET = {}
for i = 1, getn(BB.KW_PROFS) do BB.KW_PROF_SET[BB.KW_PROFS[i]] = true end
BB.KW_MAX = 10

function BB.CleanKeyword(x)
  x = string.upper(BB.Clean(x or ""))
  x = string.gsub(x, "[^%w]", "")
  if string.len(x) > 6 then x = string.sub(x, 1, 6) end
  return x
end

-- alle Keywords aus einem Notiztext: "[B, GS]" gibt { "B", "GS" }
function BB:ParseNoteKeywords(note)
  local out = {}
  note = note or ""
  local pos = 1
  while true do
    local a, b, inner = string.find(note, "%[([^%]]*)%]", pos)
    if not a then break end
    for _, part in ipairs(BB.Split(inner, ",")) do
      local kw = BB.CleanKeyword(part)
      if kw ~= "" then table.insert(out, kw) end
    end
    pos = b + 1
  end
  return out
end

-- Keywords eines Spielers: aus der Offiziersnotiz, wenn dieser Client sie lesen darf, sonst aus der
-- Liste, die die Bank-Chars an die Gilde senden
function BB:KeywordsOf(name)
  local e = BananaBankDB.ranks[name]
  if self.canSeeNotes then
    local list = {}
    if e and e.kw then list = BB.Split(e.kw, ",") end
    return list
  end
  local r = BananaBankDB.rights
  local kw = r and r.map and r.map[name]
  if kw then return BB.Split(kw, ",") end
  return {}
end

-- Hat der Spieler ein Keyword, das laut Regelsatz zu diesem Beruf gehoert?
function BB:HasProfKeyword(name, prof)
  local rules = BananaBankDB.rules
  if not rules or not rules.keywords then return false end
  local mine = self:KeywordsOf(name)
  for i = 1, getn(mine) do
    for j = 1, getn(rules.keywords) do
      if rules.keywords[j].kw == mine[i] and rules.keywords[j].prof == prof then return true end
    end
  end
  return false
end

-- ------------------------------------------------------------
-- Rechte-Liste: Bank-Chars mit "Offiziersnotiz sehen" senden Spieler -> Keywords an die Gilde,
-- damit jeder Client seine eigenen Rechte kennt (die eigene Notiz sieht er sonst nicht).
-- ------------------------------------------------------------
function BB:RightsMap()
  local map = {}
  for name, e in pairs(BananaBankDB.ranks) do
    if e.kw and e.kw ~= "" then map[name] = e.kw end
  end
  return map
end

local function rightsDigest(map)
  local keys = {}
  for name in pairs(map) do table.insert(keys, name) end
  table.sort(keys)
  local h = 0
  for i = 1, getn(keys) do h = mod(h + BB.Hash(keys[i] .. map[keys[i]]), 16777213) end
  return getn(keys) .. ":" .. h
end

function BB:RightsRefresh()
  if not self:MayBeBank(self:Me()) then return end
  local map = self:RightsMap()
  local dg = rightsDigest(map)
  local db = BananaBankDB
  if db.rights and db.rights.dg == dg then return end
  db.rights = { ts = math.max(time(), ((db.rights and db.rights.ts) or 0) + 1), by = self:Me(), map = map, dg = dg }
  self:SchedulePush("K")
end

function BB:SchedulePush(kind)
  if kind == "K" and self.After then
    self:After(2 + math.random() * 3, function() BB:PushRights() end, "push:K")
  end
end

function BB:SerializeRights(r)
  local parts = { r.ts, BB.Clean(r.by or "") }
  local n = 0
  for name, kw in pairs(r.map) do
    if n < 120 then
      table.insert(parts, BB.Clean(name) .. ":" .. BB.Clean(kw))
      n = n + 1
    end
  end
  return table.concat(parts, "~")
end

function BB:ParseRights(payload)
  local f = BB.Split(payload or "", "~")
  local ts = tonumber(f[1])
  if not ts or not f[2] or f[2] == "" then return nil end
  local r = { ts = ts, by = f[2], map = {} }
  for i = 3, getn(f) do
    local d = BB.Split(f[i], ":")
    if d[1] and d[1] ~= "" and d[2] and d[2] ~= "" then r.map[d[1]] = d[2] end
  end
  return r
end

function BB:PushRights()
  local r = BananaBankDB.rights
  if not r then return end
  self:SendTransfer("K", "one", self:SerializeRights(r))
end

function BB:MergeRights(payload)
  local r = self:ParseRights(payload)
  if not r then return false end
  local cur = BananaBankDB.rights
  if r.ts > time() + 86400 or (cur and r.ts <= (cur.ts or 0)) then return false end
  if not self:MayBeBank(r.by) then return false end
  r.dg = rightsDigest(r.map)
  BananaBankDB.rights = r
  if self.UI then self.UI:Refresh() end
  return true
end

-- ------------------------------------------------------------
-- Items: Taschen nur mit Keyword B, Lager nie
-- ------------------------------------------------------------
-- liegt das Item nur in einem Lager (und nicht im normalen Bestand)?
function BB:InDepotOnly(id)
  if not (self.DepotChars and next(self:DepotChars())) then return false end
  local main = self.stockCache and self.stockCache[id]
  if main and main.c > 0 then return false end
  local db = BananaBankDB
  for name in pairs(self:DepotChars()) do
    local snap = db.snaps[name]
    if snap and snap.items[id] then return true end
  end
  return false
end

function BB:ItemIsBag(id)
  local e = self.stockCache and self.stockCache[id]
  if not e then return false end
  local k = self:ResolveCategory(id, e)
  return k == "bag"
end

function BB:KeywordProfLabel(prof)
  if prof == "bags" then return self.T("KW_BAGS") end
  return self.T("SUB_" .. string.upper(prof or "other"))
end
