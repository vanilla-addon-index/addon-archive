-- BananaBank Gildencrafter: Rezepte kostenlos anfragen, wenn die Offiziersnotiz ein passendes Keyword hat,
-- der Beruf stimmt, das Rezept noch nicht gelernt ist und der Skill reicht.
-- Gelernte Rezepte und Skillstufen kennt nur der eigene Client: sie werden beim Oeffnen des Berufefensters gemerkt.

local BB = BananaBank
local getn = table.getn

BB.craftModule = true

-- ------------------------------------------------------------
-- Eigene Rezepte und Skillstufen merken (Berufefenster und Verzauberkunst)
-- ------------------------------------------------------------
local function store(sub, skill, names)
  local db = BananaBankDB
  db.known = db.known or {}
  local me = BB:Me()
  local k = db.known[me]
  if not k then k = { skill = {}, recipes = {} } db.known[me] = k end
  k.skill[sub] = skill
  k.recipes[sub] = names
  k.ts = time()
end

function BB:ScanTradeSkills()
  if not GetTradeSkillLine or not GetNumTradeSkills then return end
  local name, rank = GetTradeSkillLine()
  local sub = self:ProfOfName(name)
  if not sub or not rank then return end
  local names = {}
  for i = 1, GetNumTradeSkills() do
    local rname, rtype = GetTradeSkillInfo(i)
    if rname and rtype ~= "header" then names[string.lower(rname)] = true end
  end
  store(sub, rank, names)
end

function BB:ScanCrafts()
  if not GetCraftDisplaySkillLine or not GetNumCrafts then return end
  local name, rank = GetCraftDisplaySkillLine()
  local sub = self:ProfOfName(name)
  if not sub or not rank then return end
  local names = {}
  for i = 1, GetNumCrafts() do
    local rname, _, rtype = GetCraftInfo(i)
    if rname and rtype ~= "header" then names[string.lower(rname)] = true end
  end
  store(sub, rank, names)
end

-- ------------------------------------------------------------
-- Rezept: Name und benoetigter Skill
-- ------------------------------------------------------------
-- "Pattern: Red Mageweave Headband" -> "red mageweave headband"
function BB:RecipeName(itemName)
  local _, _, rest = string.find(itemName or "", "^[^:]+:%s*(.+)$")
  return string.lower(rest or itemName or "")
end

local tip
-- "Requires Tailoring (240)" aus dem Item-Tooltip lesen; nur wenn der Client das Item kennt
function BB:RecipeRequirement(id, sub)
  self.reqCache = self.reqCache or {}
  if self.reqCache[id] then return self.reqCache[id] end
  if not GetItemInfo(id) then return nil end
  if not tip then
    tip = CreateFrame("GameTooltip", "BananaBankReqTip", UIParent, "GameTooltipTemplate")
    tip:SetOwner(UIParent, "ANCHOR_NONE")
  end
  tip:ClearLines()
  tip:SetHyperlink("item:" .. id .. ":0:0:0")
  local pats = {}
  for i = 1, getn(BB.PROF) do
    if BB.PROF[i][1] == sub then pats = BB.PROF[i][2] end
  end
  for i = 1, 12 do
    local fs = getglobal("BananaBankReqTipTextLeft" .. i)
    local text = fs and fs:GetText()
    if text then
      local _, _, n = string.find(text, "%((%d+)%)")
      if n then
        local low = string.lower(text)
        for j = 1, getn(pats) do
          if string.find(low, pats[j], 1, true) then
            self.reqCache[id] = tonumber(n)
            return tonumber(n)
          end
        end
      end
    end
  end
  return nil
end

-- Darf dieser Char dieses Rezept als Gildencrafter kostenlos anfragen?
-- true | false, Grund, Zahl. Gruende: NOTRECIPE, NOKEYWORD, NOSCAN, KNOWN, NOREQ, SKILL
function BB:CraftEligible(id)
  local e = self.stockCache and self.stockCache[id]
  if not e then return false, "NOTRECIPE" end
  local k, sub = self:ResolveCategory(id, e)
  if k ~= "recipe" or not sub then return false, "NOTRECIPE" end
  local me = self:Me()
  if not self:HasProfKeyword(me, sub) then return false, "NOKEYWORD" end
  return self:RecipeUsable(id, e, sub)
end

-- Kann dieser Char (eigener Client) das Rezept benutzen? Beruf gescannt, Rezept noch nicht gelernt, Skill reicht.
-- true | false, Grund, Zahl. Gruende: NOSCAN, KNOWN, SKILL
function BB:RecipeUsable(id, e, sub)
  local me = self:Me()
  local known = BananaBankDB.known and BananaBankDB.known[me]
  if not known or not known.skill[sub] then return false, "NOSCAN", sub end
  local rname = self:RecipeName(e.n)
  if known.recipes[sub] and known.recipes[sub][rname] then return false, "KNOWN" end
  -- Den noetigen Skill kennt der Client nur, wenn er das Item schon einmal gesehen hat.
  -- Ohne diese Angabe gilt das Rezept trotzdem als anfragbar (die Bank kennt die Skills ohnehin nicht).
  local req = self:RecipeRequirement(id, sub)
  if req and known.skill[sub] < req then return false, "SKILL", req end
  return true
end

function BB:CraftText(id)
  local ok, why, n = self:CraftEligible(id)
  if ok then return nil end
  if why == "NOTRECIPE" or why == "NOKEYWORD" then return nil end
  if why == "NOSCAN" then return string.format(self.T("CR_NOSCAN"), self.T("SUB_" .. string.upper(n or "other"))) end
  if why == "SKILL" then return string.format(self.T("CR_SKILL"), n or 0) end
  return self.T("CR_" .. why)
end

-- ------------------------------------------------------------
-- Pruefung durch die Bank: nur, was sie selbst sehen kann
-- ------------------------------------------------------------
-- Hat dieser Spieler dieses Rezept schon einmal bekommen (laut Buch)?
function BB:RecipeReceived(player, itemName)
  for _, e in pairs(BananaBankDB.ledger) do
    if e.k == "out" and e.p == player and e.n == itemName then return e.t end
  end
  return nil
end

-- true | false, Text
function BB:VerifyClaim(player, id)
  local e = self.stockCache and self.stockCache[id]
  local name = self:ItemInfo(id)
  if not e then return false, self.T("CR_B_NOSTOCK") end
  local k, sub = self:ResolveCategory(id, e)
  if k ~= "recipe" or not sub then return false, self.T("CR_NOTRECIPE") end
  if not self:HasProfKeyword(player, sub) then return false, self.T("CR_B_NOKEYWORD") end
  local got = self:RecipeReceived(player, name)
  if got then return false, string.format(self.T("CR_B_RECEIVED"), BB.Date(got)) end
  return true
end

-- ------------------------------------------------------------
-- Korb: Gildencrafter-Haken je Rezept
-- ------------------------------------------------------------
-- Standard: jedes berechtigte Rezept im Korb wird automatisch beansprucht.
-- claims[id] == false heisst: der Spieler hat den Anspruch bewusst abgewaehlt.
function BB:ToggleClaim(id)
  local db = BananaBankDB
  db.claims = db.claims or {}
  if not self:CraftEligible(id) then return end
  if db.claims[id] == false then db.claims[id] = nil else db.claims[id] = false end
end

function BB:ClaimOn(id)
  local db = BananaBankDB
  return self:CraftEligible(id) and not (db.claims and db.claims[id] == false)
end

-- gueltige Claims fuer den Korb (nur Items im Korb, die berechtigt und nicht abgewaehlt sind)
function BB:ValidClaims(items)
  local out = {}
  for id in pairs(items) do
    if self:ClaimOn(id) then out[id] = 1 end
  end
  return out
end

-- Rezepte dieser Anfrage, die die Bank selbst als Gildencrafter-Anspruch bestaetigen koennte
-- (Keyword, Beruf des Rezepts, noch nicht erhalten). Hilft, wenn der Client des Spielers keinen Anspruch mitsendet.
-- /bb rights [Name]: Regeln, Keywords und Rechte eines Spielers, zum Nachvollziehen
function BB:PrintRights(name)
  local rules = BananaBankDB.rules
  self:Print(string.format(self.T("DBG_NOTES"), self.canSeeNotes and self.T("YES") or self.T("NO")))
  local kws = {}
  for i = 1, table.getn(rules and rules.keywords or {}) do
    kws[i] = rules.keywords[i].kw .. "=" .. self:KeywordProfLabel(rules.keywords[i].prof)
  end
  self:Print(string.format(self.T("DBG_KWTABLE"), (table.getn(kws) > 0) and table.concat(kws, ", ") or "-"))
  name = (name and name ~= "") and name or self:Me()
  local e = BananaBankDB.ranks[name]
  local r = BananaBankDB.rights
  self:Print(string.format(self.T("DBG_PLAYER"), name, e and e.r or "?", (e and e.kw) or "-", (r and r.map and r.map[name]) or "-"))
  local mine = self:KeywordsOf(name)
  self:Print(string.format(self.T("DBG_EFFECTIVE"), table.concat(mine, ", ")))
end

-- /bb craft [Text]: warum ist (k)ein Rezept als Gildencrafter anfragbar?
function BB:PrintCraft(text)
  text = string.lower(text or "")
  self:GetStock()
  local n = 0
  for id, e in pairs(self.stockCache or {}) do
    local k = self:ResolveCategory(id, e)
    if k == "recipe" and (text == "" or string.find(string.lower(e.n or ""), text, 1, true)) then
      n = n + 1
      if n <= 12 then
        local ok, why, extra = self:CraftEligible(id)
        self:Print(e.n .. ": " .. (ok and self.T("DBG_OK") or (why .. (extra and (" " .. tostring(extra)) or ""))))
      end
    end
  end
  if n == 0 then self:Print(self.T("DBG_NONE")) end
end
