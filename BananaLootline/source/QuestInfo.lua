--[[----------------------------------------------------------------------
  BananaLootline - QuestInfo.lua

  Klick auf eine Questbelohnung zeigt die ganze Questreihe: von der
  ersten Vorquest bis zur Quest mit der Belohnung, jeweils mit Name,
  Stufe, Questgeber samt Ort und Koordinaten, Abgabe und Ziel. Dazu die
  anderen Teile, falls die Belohnung eine Auswahl ist.

  Daten aus Data/QuestData.lua (tools/quest_import.lua, Quelle pfQuest).
  Fehlt eine Quest dort - OctoWoW-eigene Quests stehen nicht immer in
  pfQuest -, gilt, was der Import selbst weiss: Name, Stufe, Geber.
------------------------------------------------------------------------]]

local BLL = BananaLootline
BLL.QuestInfo = {}
local QI = BLL.QuestInfo

local MAX_CHAIN = 25

local function QD() return BananaLootlineQuestData end

-- Was der Import zu einer Quest weiss: aus der Quellzeile eines Items.
function QI:ImportRow(qid, itemID)
  local src = BananaLootlineSourceData
  if not src then return nil end
  local function scan(s)
    for i = 1, table.getn(s and s.q or {}) do
      if s.q[i].q == qid then return s.q[i] end
    end
  end
  if itemID and src[itemID] then
    local r = scan(src[itemID])
    if r then return r end
  end
  for _, s in pairs(src) do
    local r = scan(s)
    if r then return r end
  end
end

-- Eine Quest als einheitliche Tabelle.
function QI:Quest(qid, itemID)
  local d = QD() and QD().q and QD().q[qid]
  local imp = (not d or not d.t) and self:ImportRow(qid, itemID) or nil
  if not d and not imp then return nil end
  d = d or {}
  return {
    id     = qid,
    title  = d.t or (imp and imp.t) or BLL.Sources:QuestName(qid),
    level  = d.l,
    min    = d.m or (imp and imp.l),
    race   = d.r,
    pre    = d.p,
    giver  = d.s or (imp and imp.g),
    giverObject = d.so,
    finish = d.e,
    goal   = d.o,
    zone   = imp and imp.z,
  }
end

-- Name, Zone und Koordinaten eines NPC.
function QI:Npc(uid)
  if not uid then return nil end
  local u = QD() and QD().u and QD().u[uid] or {}
  -- pfQuest im Client zuerst (Clientsprache), dann die eigenen Daten.
  -- UnitName liefert fuer Unbekannte "Unit #266" statt nil.
  local name = BLL.Sources:UnitName(uid)
  if not name or name == "" or string.find(name, "#%d+$") then name = u.n or name end
  local zone
  if u.z then
    zone = BLL.Sources:ZoneName(u.z)
    if string.find(zone or "", "^Zone ") and QD().z and QD().z[u.z] then
      zone = QD().z[u.z]
    end
  end
  return { id = uid, name = name or ("NPC " .. uid), zone = zone, x = u.x, y = u.y }
end

-- Die Reihe von der ersten Vorquest bis qid. Bei mehreren Vorquests
-- gilt die erste, die die eigene Rasse annehmen darf; die anderen
-- werden als Alternativen vermerkt (oft dieselbe Quest fuer die andere
-- Fraktion).
function QI:Chain(qid, itemID)
  local chain, seen = {}, {}
  local cur = qid
  while cur and not seen[cur] and table.getn(chain) < MAX_CHAIN do
    seen[cur] = true
    local q = self:Quest(cur, (cur == qid) and itemID or nil)
    if not q then break end
    table.insert(chain, 1, q)
    local nextPre, alts = nil, 0
    for i = 1, table.getn(q.pre or {}) do
      local p = q.pre[i]
      local pq = QD() and QD().q and QD().q[p]
      if not pq or BLL.Sources:RaceAllows(pq.r) then
        if not nextPre then nextPre = p else alts = alts + 1 end
      end
    end
    q.altPre = (alts > 0) and alts or nil
    cur = nextPre
  end
  return chain
end

-- Andere Teile derselben Quest, zwischen denen man waehlt.
function QI:Rewards(qid)
  local out = {}
  for itemID, s in pairs(BananaLootlineSourceData or {}) do
    for i = 1, table.getn(s.q or {}) do
      if s.q[i].q == qid then
        local e = BLL.ItemDB and BLL.ItemDB:Get(itemID)
        table.insert(out, { id = itemID, name = e and e.name or ("Item " .. itemID),
                            quality = e and e.quality })
      end
    end
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

------------------------------------------------------------------
-- Text
------------------------------------------------------------------

local function Where(npc, de)
  if not npc then return "|cff888888?|r" end
  local s = "|cffffffff" .. npc.name .. "|r"
  if npc.zone then s = s .. " - " .. npc.zone end
  if npc.x then s = s .. string.format(" |cff888888(%.0f, %.0f)|r", npc.x, npc.y) end
  return s
end

function QI:Text(qid, itemID)
  local L = BLL.L
  local de = (BLL.locale == "deDE")
  local chain = self:Chain(qid, itemID)
  local lines = {}
  local function add(t) table.insert(lines, t) end

  if table.getn(chain) == 0 then
    add(L["QI_UNKNOWN"])
    return table.concat(lines, "\n"), 0
  end

  local n = table.getn(chain)
  if n > 1 then
    add(string.format(L["QI_CHAIN"], n))
    add(" ")
  end

  local myLevel = BLL.player and BLL.player.level or 0
  for i = 1, n do
    local q = chain[i]
    local last = (i == n)
    local col = last and "|cffffd100" or "|cffffffff"
    local lvl = ""
    if q.min then
      local c = (q.min > myLevel) and "|cffff8800" or "|cff888888"
      lvl = "  " .. c .. string.format(L["QI_FROM"], q.min) .. "|r"
    end
    if q.level then lvl = lvl .. " |cff888888(" .. string.format(L["QI_LEVEL"], q.level) .. ")|r" end
    add(col .. i .. ". " .. (q.title or "?") .. "|r" .. lvl
      .. (last and ("  |cff00ff00" .. L["QI_REWARD"] .. "|r") or ""))

    if q.giver then
      add("    " .. L["QI_START"] .. " " .. Where(self:Npc(q.giver), de))
    elseif q.giverObject then
      add("    " .. L["QI_START"] .. " " .. (BLL.Sources:ObjectName(q.giverObject) or ("#" .. q.giverObject)))
    elseif q.zone then
      add("    " .. L["QI_START"] .. " |cff888888" .. (BLL.Sources:ZoneName(q.zone) or "?") .. "|r")
    end
    if q.finish and q.finish ~= q.giver then
      add("    " .. L["QI_END"] .. " " .. Where(self:Npc(q.finish), de))
    end
    if q.goal then add("    |cffaaaaaa" .. q.goal .. "|r") end
    if q.altPre then add("    |cff888888" .. L["QI_ALT"] .. "|r") end
  end

  local rewards = self:Rewards(qid)
  if table.getn(rewards) > 1 then
    add(" ")
    add(L["QI_CHOICE"])
    for i = 1, table.getn(rewards) do
      local r = rewards[i]
      add("    " .. ((r.id == itemID) and "|cff00ff00> " or "|cffffffff  ") .. r.name .. "|r")
    end
  end
  return table.concat(lines, "\n"), n
end

------------------------------------------------------------------
-- Fenster
------------------------------------------------------------------

function QI:Frame()
  if self.frame then return self.frame end
  local f = CreateFrame("Frame", "BananaLootlineQuestFrame", UIParent)
  f:SetWidth(420); f:SetHeight(200)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
  f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() this:StartMoving() end)
  f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  -- Eine Stufe ueber dem Hauptfenster (DIALOG), sonst liegt das
  -- Fenster bei gleicher Ebene dahinter.
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  tinsert(UISpecialFrames, "BananaLootlineQuestFrame")

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", f, "TOP", 0, -18)
  title:SetWidth(360)
  f.title = title

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)

  local body = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  body:SetPoint("TOPLEFT", f, "TOPLEFT", 24, -48)
  body:SetWidth(372)
  body:SetJustifyH("LEFT")
  body:SetJustifyV("TOP")
  f.body = body

  -- Mit pfQuest: die Quest auf der Karte zeigen. pfQuests eigene
  -- Suche, ueber pcall - fehlt die Funktion in einer Fassung, bleibt
  -- es bei einer Meldung.
  local map = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  map:SetWidth(150); map:SetHeight(22)
  map:SetPoint("BOTTOM", f, "BOTTOM", 0, 18)
  map:SetScript("OnClick", function() QI:ShowOnMap() end)
  f.map = map

  self.frame = f
  return f
end

function QI:FirstOpenQuest()
  local chain = self.chain or {}
  return chain[1] and chain[1].id
end

function QI:ShowOnMap()
  local qid = self:FirstOpenQuest()
  local ok = false
  if qid and pfDatabase and pfDatabase.SearchQuestID and pfMap then
    ok = pcall(function()
      local maps = pfDatabase:SearchQuestID(qid, { addon = "BananaLootline" })
      if pfMap.UpdateNodes then pfMap:UpdateNodes() end
      if pfMap.ShowMapID and pfDatabase.GetBestMap then
        pfMap:ShowMapID(pfDatabase:GetBestMap(maps))
      end
    end)
  end
  if not ok then BLL:Print(BLL.L["QI_NOMAP"]) end
end

-- Links neben dem Hauptfenster, oben buendig. Reicht der Platz links
-- nicht, rechts daneben; ist das Hauptfenster zu, in die Bildmitte.
function QI:Place(f)
  local main = BananaLootlineFrame
  f:ClearAllPoints()
  if not (main and main:IsVisible()) then
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    return
  end
  local left = (main:GetLeft() or 0) * main:GetEffectiveScale()
  local need = f:GetWidth() * f:GetEffectiveScale()
  if left >= need then
    f:SetPoint("TOPRIGHT", main, "TOPLEFT", 2, 0)
  else
    f:SetPoint("TOPLEFT", main, "TOPRIGHT", -2, 0)
  end
end

function QI:Show(qid, itemID)
  if not qid then return end
  local f = self:Frame()
  local L = BLL.L
  self.chain = self:Chain(qid, itemID)
  local e = itemID and BLL.ItemDB and BLL.ItemDB:Get(itemID)
  f.title:SetText(e and e.name or L["QI_TITLE"])
  local text = self:Text(qid, itemID)
  f.body:SetText(text)
  f.map:SetText(L["QI_MAP"])
  if pfDatabase and pfMap then f.map:Show() else f.map:Hide() end
  local h = (f.body:GetHeight() or 100) + 100
  if h < 160 then h = 160 end
  f:SetHeight(h)
  self:Place(f)
  f:Show()
end
