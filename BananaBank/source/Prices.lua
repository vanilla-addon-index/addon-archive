-- BananaBank Preise
-- Bindung per Tooltip erkennen (1.12 hat dafuer kein API-Feld),
-- Auktionshaus seitenweise scannen (kein getAll in 1.12),
-- Gildenpreis = Schnitt der guenstigsten 30 Prozent, halbiert.

local BB = BananaBank
local getn = table.getn
local floor = math.floor

BB.priceModule = true
BB.PRICE_FACTOR = 0.5   -- Haelfte des Marktpreises
BB.PRICE_SHARE = 0.30   -- Schnitt ueber die guenstigsten 30 Prozent
BB.PRICE_MIN_OLD = 5000 -- der frueher eingebaute Mindestpreis (50 Silber): solche Preise werden neu gescannt
BB.AH_PAGE = 50
BB.AH_MAX_PAGES = 5     -- kurze Namen treffen viel; mehr als das brauchen wir nicht

-- ------------------------------------------------------------
-- Bindung per Tooltip
-- ------------------------------------------------------------
local tip
local function scanTip()
  if not tip then
    tip = CreateFrame("GameTooltip", "BananaBankScanTip", UIParent, "GameTooltipTemplate")
    tip:SetOwner(UIParent, "ANCHOR_NONE")
  end
  return tip
end

local SOUL = { ["Soulbound"] = true, ["Seelengebunden"] = true }
local BOE = { ["Binds when equipped"] = true, ["Wird beim Anlegen gebunden"] = true }
local BOP = { ["Binds when picked up"] = true, ["Wird beim Aufheben gebunden"] = true }
if ITEM_SOULBOUND then SOUL[ITEM_SOULBOUND] = true end
if ITEM_BIND_ON_EQUIP then BOE[ITEM_BIND_ON_EQUIP] = true end
if ITEM_BIND_ON_PICKUP then BOP[ITEM_BIND_ON_PICKUP] = true end

-- liefert "soul" (nicht versendbar), "boe", "bop" oder "none"
function BB:BindOfSlot(bag, slot)
  local t = scanTip()
  t:ClearLines()
  if bag == -1 then
    if not BankButtonIDToInvSlotID then return "none" end
    t:SetInventoryItem("player", BankButtonIDToInvSlotID(slot))
  else
    t:SetBagItem(bag, slot)
  end
  local n = t:NumLines() or 0
  local kind = "none"
  for i = 2, n do
    local fs = getglobal("BananaBankScanTipTextLeft" .. i)
    local line = fs and fs:GetText()
    if line then
      if SOUL[line] then return "soul" end
      if BOE[line] then kind = "boe" end
      if BOP[line] then kind = "bop" end
    end
  end
  return kind
end

-- Cache je Item-ID: Grundbindung. Seelengebunden haengt am Stapel, nicht am Item.
function BB:BindOfItem(id, bag, slot)
  local db = BananaBankDB
  db.bind = db.bind or {}
  local known = db.bind[id]
  if known == "none" then return "none" end
  local here = self:BindOfSlot(bag, slot)
  if here ~= "soul" then db.bind[id] = here end
  return here
end

-- verkaufsfaehig: bindet beim Anlegen (jede Itemart) oder ist ein Rezept. Die Kategorie kommt aus den
-- Bestaenden aller Banken, nicht nur aus den Taschen dieses Chars.
function BB:IsBOE(id)
  local db = BananaBankDB
  if db.bind and db.bind[id] == "boe" then return true end
  local e = self.stockCache and self.stockCache[id]
  return (e and (e.k == "boe" or e.k == "recipe")) and true or false
end

-- ------------------------------------------------------------
-- Preise
-- ------------------------------------------------------------
function BB:GetPrice(id)
  local p = BananaBankDB.prices[id]
  if p and p.u and p.u > 0 then
    return p.u, p.src, p.ts, p.n
  end
  -- ohne AH-Preis (und ohne Handpreis) gibt es keinen Preis
  return nil
end

-- Jedes Item bekommt seinen Gildenpreis aus dem AH (Ausnahmen gibt es nicht).
function BB:NeedsPrice(id)
  return true
end

-- Laut AH-Scan nicht im Auktionshaus gefunden (gesucht, nichts da)? Ein Handpreis hebt das auf.
function BB:AHAbsent(id)
  local p = BananaBankDB.prices[id]
  return p ~= nil and p.src == "none" and (p.u or 0) == 0
end

function BB:PriceTotal(items)
  local sum = 0
  local missing = 0
  for id, n in pairs(items) do
    local u = self:GetPrice(id)
    if u then
      sum = sum + u * n
    elseif self:NeedsPrice(id) then
      missing = missing + 1
    end
  end
  return sum, missing
end

function BB:SetPrice(id, copper, src)
  local db = BananaBankDB
  local ts = time()
  if db.priceTs and ts <= db.priceTs then ts = db.priceTs + 1 end
  if copper and copper > 0 then
    db.prices[id] = { u = floor(copper), src = src or "man", ts = ts, n = 0 }
  else
    db.prices[id] = { u = 0, src = src or "man", ts = ts, n = 0 }
  end
  db.priceTs = ts
  self:SchedulePricePush()
  if self.UI then self.UI:Refresh() end
end

-- Handpreis loeschen: der naechste Scan setzt wieder den AH-Preis
function BB:ResetPrice(id)
  local db = BananaBankDB
  local ts = time()
  if db.priceTs and ts <= db.priceTs then ts = db.priceTs + 1 end
  db.prices[id] = { u = 0, src = "ah", ts = ts, n = 0 }
  db.priceTs = ts
  self:SchedulePricePush()
  if self.UI then self.UI:Refresh() end
end

local function fromSamples(list)
  table.sort(list)
  local n = getn(list)
  local take = floor(n * BB.PRICE_SHARE + 0.5)
  if take < 1 then take = 1 end
  local sum = 0
  for i = 1, take do sum = sum + list[i] end
  local p = floor(sum / take * BB.PRICE_FACTOR)
  -- ab 1 Silber auf ganze Silber abrunden, darunter in Kupfer lassen; nie 0 (0 heisst "kein Preis")
  if p >= 100 then p = floor(p / 100) * 100 end
  if p < 1 then p = 1 end
  return p, n
end
BB.PriceFromSamples = fromSamples

-- ------------------------------------------------------------
-- Auktionshaus-Scan
-- ------------------------------------------------------------
-- Ob das Auktionshaus offen ist, entscheidet das Event. Addons wie aux
-- verstecken den Standardrahmen, dann taeuscht IsVisible.
function BB:AHOpen()
  if self.ahOpen then return true end
  if AuctionFrame and AuctionFrame.IsVisible and AuctionFrame:IsVisible() then return true end
  return false
end

-- Gezielte Suche: fuer jedes BOE-Item im Bestand eine Abfrage mit dem
-- Item-Namen. Das ganze AH durchzublaettern dauert in 1.12 Minuten und
-- liefert fast nur Angebote, die uns nicht interessieren.
-- Wie alt (in Tagen) darf ein AH-Preis sein, bevor der Scan ihn erneut holt? Einstellbar, Standard 10.
BB.PRICE_MAX_AGE_DEFAULT = 10
function BB:PriceMaxAgeDays()
  local d = BananaBankDB.priceMaxAge
  if type(d) ~= "number" or d < 0 then return BB.PRICE_MAX_AGE_DEFAULT end
  return d
end

-- Gezielte Suche: erst alle Items ohne Preis (nie gescannt oder nicht gefunden), dann die mit dem aeltesten Scan,
-- und nur die, deren Preis aelter als die eingestellten Tage ist. Von Hand gesetzte Preise bleiben.
-- Das ganze AH durchzublaettern dauert in 1.12 Minuten und liefert fast nur Angebote, die uns nicht interessieren.
function BB:PriceTargets()
  local db = BananaBankDB
  local stock = self:GetStock()
  local fresh, old = {}, {}
  local limit = self:PriceMaxAgeDays() * 86400
  local now = time()
  -- einmalige Neuberechnung (3.9.2): jeder Preis, der vor diesem Zeitpunkt entstand, wird neu geholt
  local rescanTs = db.priceRescanTs
  if rescanTs == nil and not db.priceRescanDone then
    rescanTs = now
    db.priceRescanTs = now
  end
  local stale = 0
  for id in pairs(stock) do
    local cur = db.prices[id]
    -- graue Items sind ohnehin Trash und werden nicht gesucht
    local e = stock[id]
    if not (cur and cur.src == "man") and not (e and e.q == 0) then
      local name = self:ItemInfo(id)
      if name and name ~= "" and not string.find(name, "^#%d") then
        -- nie gescannt oder zurueckgesetzt: sofort; gescannt (Preis gefunden oder nicht im AH): erst nach den eingestellten Tagen
        local scanned = cur and ((cur.src == "ah" and (cur.u or 0) > 0) or cur.src == "none")
        -- ein Preis von genau 50 Silber stammt aus der alten Mindestpreis-Regel: neu holen
        if scanned and cur.src == "ah" and cur.u == BB.PRICE_MIN_OLD then scanned = false end
        if scanned and rescanTs and (cur.ts or 0) < rescanTs then
          scanned = false
          stale = stale + 1
        end
        if not scanned then
          table.insert(fresh, id)
        elseif now - (cur.ts or 0) >= limit then
          table.insert(old, id)
        end
      end
    end
  end
  table.sort(fresh)
  table.sort(old, function(a, b)
    local ta, tb = db.prices[a].ts or 0, db.prices[b].ts or 0
    if ta ~= tb then return ta < tb end
    return a < b
  end)
  -- nichts Altes mehr uebrig: die Neuberechnung ist fertig
  self.priceRescanActive = rescanTs ~= nil and stale > 0
  if rescanTs and stale == 0 then
    db.priceRescanTs = nil
    db.priceRescanDone = true
  end
  self.priceFreshCount = getn(fresh)
  local ids = {}
  for i = 1, getn(fresh) do table.insert(ids, fresh[i]) end
  for i = 1, getn(old) do table.insert(ids, old[i]) end
  return ids
end

function BB:StartAHScan()
  if not self:BankActive() then
    self:Print(self.T("ERR_NOT_BANK"))
    return
  end
  if not self:AHOpen() then
    self:Print(self.T("ERR_NO_AH"))
    return
  end
  if self.scan then return end
  local ids = self:PriceTargets()
  if getn(ids) == 0 then
    self:Print(self.T("MSG_AH_NOTHING"))
    return
  end
  self.scan = { ids = ids, idx = 1, set = 0, seen = 0, none = 0, page = 0, hits = {},
    started = GetTime() }
  if self.priceRescanActive then self:Print(self.T("MSG_AH_RESCAN")) end
  self:Print(string.format(self.T("MSG_AH_START"), getn(ids), self.priceFreshCount or 0, self:PriceMaxAgeDays()))
  self:AHQuery()
end

function BB:StopAHScan(silent)
  if not self.scan then return end
  self.scan = nil
  self:Cancel("ahq")
  self:Cancel("ahtimeout")
  if not silent then self:Print(self.T("MSG_AH_ABORT")) end
  if self.UI then self.UI:Refresh() end
end

function BB:ScanItemName()
  local s = self.scan
  if not s then return "" end
  local id = s.ids[s.idx]
  if not id then return "" end
  return (self:ItemInfo(id))
end

function BB:AHQuery()
  local s = self.scan
  if not s then return end
  if not self:AHOpen() then return self:StopAHScan() end
  local id = s.ids[s.idx]
  if not id then return self:FinishAHScan() end
  if CanSendAuctionQuery and not CanSendAuctionQuery() then
    self:After(0.4, function() BB:AHQuery() end, "ahq")
    return
  end
  local name = self:ItemInfo(id)
  s.waiting = id
  s.page = s.page or 0
  s.hits = s.hits or {}
  -- Die Namenssuche ist eine Teilstring-Suche. Gefiltert wird ueber die Item-ID,
  -- und bei vielen Treffern blaettern wir ein paar Seiten weiter.
  QueryAuctionItems(name, nil, nil, nil, nil, nil, s.page, nil, nil)
  self:After(10, function()
    if BB.scan and BB.scan.waiting then
      BB.scan.waiting = nil
      BB:FinishTarget()
    end
  end, "ahtimeout")
end

-- Auswertung eines Items abschliessen und zum naechsten gehen
function BB:FinishTarget()
  local s = self.scan
  if not s then return end
  local id = s.ids[s.idx]
  local hits = s.hits or {}
  if id and getn(hits) > 0 then
    local db = BananaBankDB
    local ts = time()
    if db.priceTs and ts <= db.priceTs then ts = db.priceTs + 1 end
    local price, samples = fromSamples(hits)
    db.prices[id] = { u = price, src = "ah", ts = ts, n = samples }
    db.priceTs = ts
    s.set = s.set + 1
  elseif id then
    -- Nichts im AH gefunden. Das merken wir uns mit Datum, damit in der
    -- Liste steht, dass gesucht wurde und nicht, dass nie jemand geschaut hat.
    local db = BananaBankDB
    local ts = time()
    if db.priceTs and ts <= db.priceTs then ts = db.priceTs + 1 end
    db.prices[id] = { u = 0, src = "none", ts = ts, n = 0 }
    db.priceTs = ts
    s.none = s.none + 1
  end
  self:NextTarget()
end

function BB:NextTarget()
  local s = self.scan
  if not s then return end
  s.idx = s.idx + 1
  s.page = 0
  s.hits = {}
  if self.UI then self.UI:Refresh() end
  if s.idx > getn(s.ids) then
    self:FinishAHScan()
  else
    self:After(0.3, function() BB:AHQuery() end, "ahq")
  end
end

function BB:OnAuctionUpdate()
  local s = self.scan
  if not s or not s.waiting then return end
  local id = s.waiting
  s.waiting = nil
  self:Cancel("ahtimeout")

  local batch, total = GetNumAuctionItems("list")
  batch = batch or 0
  total = total or batch
  s.hits = s.hits or {}
  for i = 1, batch do
    local name, _, count, _, _, _, _, _, buyout = GetAuctionItemInfo("list", i)
    local lid
    if GetAuctionItemLink then lid = BB.ParseLink(GetAuctionItemLink("list", i)) end
    -- Die Namenssuche trifft auch aehnliche Items, deshalb ueber die ID filtern
    if lid == id and buyout and buyout > 0 and count and count > 0 then
      table.insert(s.hits, floor(buyout / count))
    end
    s.seen = s.seen + 1
  end

  -- viele Treffer auf den Namen: noch ein paar Seiten weiter
  local nextPage = (s.page or 0) + 1
  if batch > 0 and nextPage * BB.AH_PAGE < total and nextPage < BB.AH_MAX_PAGES then
    s.page = nextPage
    self:After(0.3, function() BB:AHQuery() end, "ahq")
    return
  end
  self:FinishTarget()
end

function BB:FinishAHScan()
  local s = self.scan
  self.scan = nil
  if not s then return end
  local db = BananaBankDB
  local ts = db.priceTs or time()
  db.priceScan = { ts = ts, seen = s.seen, set = s.set, items = getn(s.ids) }
  if (db.priceTs or 0) < ts then db.priceTs = ts end
  self:Print(string.format(self.T("MSG_AH_DONE"), getn(s.ids), s.set,
    floor((GetTime() - (s.started or GetTime())) + 0.5)))
  if s.none > 0 then self:Print(string.format(self.T("MSG_AH_MISSING"), s.none)) end
  self:SchedulePricePush()
  if self.UI then self.UI:Refresh() end
end

-- ------------------------------------------------------------
-- Abgleich
-- ------------------------------------------------------------
function BB:SerializePrices()
  local recs = {}
  for id, p in pairs(BananaBankDB.prices) do
    table.insert(recs, id .. "~" .. (p.u or 0) .. "~" .. (p.src or "ah") .. "~" .. (p.ts or 0) .. "~" .. (p.n or 0))
  end
  return table.concat(recs, "^")
end

function BB:ParsePrices(payload)
  local out = {}
  for _, rec in ipairs(BB.Split(payload, "^")) do
    local f = BB.Split(rec, "~")
    local id = tonumber(f[1])
    if id and tonumber(f[2]) then
      out[id] = { u = tonumber(f[2]), src = f[3] or "ah", ts = tonumber(f[4]) or 0, n = tonumber(f[5]) or 0 }
    end
  end
  return out
end

function BB:MergePrices(list)
  local db = BananaBankDB
  local changed = 0
  for id, p in pairs(list) do
    local cur = db.prices[id]
    if not cur or (p.ts or 0) > (cur.ts or 0) then
      db.prices[id] = p
      changed = changed + 1
      if (p.ts or 0) > (db.priceTs or 0) then db.priceTs = p.ts end
    end
  end
  return changed
end

function BB:PushPrices()
  local payload = self:SerializePrices()
  if payload == "" then return end
  self:SendTransfer("P", tostring(BananaBankDB.priceTs or 0), payload)
end

function BB:SchedulePricePush()
  self:After(5, function() BB:PushPrices() end, "pricepush")
end
