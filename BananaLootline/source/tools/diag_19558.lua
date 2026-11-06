--[[
  Diagnoselauf mit den ECHTEN Daten.

  Keine Attrappe fuer die Itemdatenbank: geladen wird Data/ItemData.lua
  mit allen 11349 Eintraegen. Nachgestellt wird der Zustand aus dem
  Fehlerbericht - Stufe-15-Jaeger, im gespeicherten Cache ein alter
  Eintrag fuer 19558 mit Stufe 18.

  Protokolliert wird jeder Schritt, an dem das Item haengen bleiben
  koennte. Aufruf vom Addonstamm aus:  lua5.1 tools/diag_19558.lua
]]
string.gmatch = nil; select = nil

local ITEM = 19558

------------------------------------------------------------------
-- WoW-API, soweit gebraucht
------------------------------------------------------------------

local frames = {}
CreateFrame = function()
  local f = { SetScript = function() end, RegisterEvent = function() end }
  table.insert(frames, f)
  return f
end

-- Der Client kennt das Item nicht (so wie beim ersten /bll dump)
GetItemInfo = function(id) return nil end

-- Waffenfertigkeiten: Bogen gelernt
GetNumSkillLines   = function() return 1 end
GetSkillLineInfo   = function(i) return "Bows", nil, nil, 1, 0, 0, 1 end
ExpandSkillHeader  = function() end
UnitLevel          = function() return 15 end

BananaLootline = { locale = "enUS", clientLocale = "enUS" }
BananaLootline.L = setmetatable({}, { __index = function(t, k) return k end })
BananaLootlineDB = { planAhead = 6, itemcache = {} }

local BLL = BananaLootline
local log = {}
BLL.Print = function(self, m) table.insert(log, m) end
BLL.Debug = function() end

------------------------------------------------------------------
-- Echte Daten und echte Module
------------------------------------------------------------------

dofile("Data/ItemData.lua")
dofile("ItemDB.lua")
BLL.ItemDB:Refresh()

BLL.Weights = {
  DEFAULT_COOLDOWN = 120,
  Get = function() return { AGI = 1, STA = 1, STR = 1, WEAPON_DPS = 1 } end,
  Score = function(self, s, w, e)
    local t = 0
    for _, v in pairs(s or {}) do t = t + v end
    for _, v in pairs(e or {}) do t = t + v end
    return t
  end,
  UseEffectScore = function() return 0, false end,
}
BLL.SetDB = { loaded = false }
BLL.Sources = {
  available = true, items = {}, units = {}, quests = {},
  UnitLevel = function() return nil end,
  GetItemSources = function() return {} end,
}
BLL.Gear = {
  SLOTS = { { key = "RangedSlot" } },
  SlotLabel = function() return "Distanz" end,
  equipped = { ["RangedSlot"] = { id = 1, name = "Alter Bogen", stats = { AGI = 1 } } },
}

dofile("Candidates.lua")
local Cand = BLL.Candidates

BLL.player = { class = "HUNTER", level = 15, race = "Orc" }

local function line(s) print(s) end
local function head(s) print("") print("== " .. s .. " ==") end

------------------------------------------------------------------
head("Schritt 1: Was steht in der Itemdatenbank?")
------------------------------------------------------------------

local db = BLL.ItemDB:Get(ITEM)
line("Eintraege geladen : " .. BLL.ItemDB.count)
line("ItemDB:Get(" .. ITEM .. ") : " .. (db and "gefunden" or "NICHT GEFUNDEN"))
if db then
  line("   name     = " .. tostring(db.name))
  line("   reqlevel = " .. tostring(db.reqlevel))
  line("   ilvl     = " .. tostring(db.ilvl))
  line("   slot     = " .. tostring(db.slot))
end

-- Schluesseltyp pruefen: ein String-Schluessel wuerde jeden Zugriff
-- mit einer Zahl ins Leere laufen lassen.
local anyKey
for k in pairs(BLL.ItemDB.data) do anyKey = k break end
line("Schluesseltyp der Daten: " .. type(anyKey))
line("Zugriff mit Zahl  : " .. (BLL.ItemDB.data[19558] and "ok" or "nil"))
line("Zugriff mit String: " .. (BLL.ItemDB.data["19558"] and "ok" or "nil"))

------------------------------------------------------------------
head("Schritt 2: Was liefert RequiredLevel?")
------------------------------------------------------------------

local stale = { n = "Outrider's Bow", q = 3, r = 18, e = "INVTYPE_RANGED",
                ic = 2, sc = 2, st = { AGI = 5, STA = 11 } }
line("Cache-Eintrag vorher, r = " .. tostring(stale.r))
local rl = Cand:RequiredLevel(stale, ITEM)
line("RequiredLevel(...)      = " .. tostring(rl))
line("Cache-Eintrag nachher,  r = " .. tostring(stale.r))
line(rl == 60 and "   -> ABGLEICH GREIFT" or "   -> ABGLEICH GREIFT NICHT")

------------------------------------------------------------------
head("Schritt 3: Was macht PreloadFromItemDB mit dem Item?")
------------------------------------------------------------------

BananaLootlineDB.itemcache = {}
Cand.pool = { [ITEM] = 18 }
Cand.fromImport = {}
local skipped, needStats = Cand:PreloadFromItemDB()
local c = BananaLootlineDB.itemcache[ITEM]
line("aussortiert: " .. tostring(skipped) .. ", ohne Werte: " .. tostring(needStats))
if not c then
  line("Cache-Eintrag: keiner angelegt")
else
  line("Cache-Eintrag: skip=" .. tostring(c.skip) .. "  r=" .. tostring(c.r)
       .. "  cv=" .. tostring(c.cv))
end

------------------------------------------------------------------
head("Schritt 4: Mit ALTEM Cache-Eintrag, wie beim Nutzer")
------------------------------------------------------------------

-- So sieht ein Eintrag aus, den StoreItem frueher geschrieben hat:
-- kein cv-Feld, Stufe 18.
BananaLootlineDB.itemcache = {
  [ITEM] = { n = "Outrider's Bow", q = 3, r = 18, e = "INVTYPE_RANGED",
             a = nil, st = { AGI = 5, STA = 11, WEAPON_DPS = 36.7 } },
}
Cand.pool = { [ITEM] = 18 }
line("vor dem Lauf : r=" .. tostring(BananaLootlineDB.itemcache[ITEM].r)
     .. "  cv=" .. tostring(BananaLootlineDB.itemcache[ITEM].cv))
Cand:PreloadFromItemDB()
local c2 = BananaLootlineDB.itemcache[ITEM]
if not c2 then
  line("nach dem Lauf: Eintrag entfernt (wird neu angefragt)")
else
  line("nach dem Lauf: skip=" .. tostring(c2.skip) .. "  r=" .. tostring(c2.r)
       .. "  cv=" .. tostring(c2.cv))
end

------------------------------------------------------------------
head("Schritt 5: Taucht das Item in den Vorschlaegen auf?")
------------------------------------------------------------------

local function tryUpgrades(tag, cacheEntry)
  BananaLootlineDB.itemcache = { [ITEM] = cacheEntry }
  Cand.pool = { [ITEM] = 18 }
  Cand.fromImport = {}
  Cand.skills = { known = { [2] = true, [3] = true, [18] = true }, dualWield = true }
  Cand.skillsDirty = false
  local ups = Cand:GetUpgrades("RangedSlot", 5)
  local n = table.getn(ups or {})
  local hit = nil
  for i = 1, n do if ups[i].id == ITEM then hit = ups[i] end end
  line(tag)
  line("   Vorschlaege: " .. n .. (hit and ("  -> ITEM DABEI, Anzeige 'ab "
       .. tostring(hit.reqLevel) .. "'") or "  -> Item nicht dabei"))
  return hit
end

tryUpgrades("Alter Eintrag ohne cv, r=18:",
  { n = "Outrider's Bow", q = 3, r = 18, e = "INVTYPE_RANGED",
    st = { AGI = 5, STA = 11 }, ic = 2, sc = 2 })

tryUpgrades("Eintrag mit korrektem r=60:",
  { n = "Outrider's Bow", q = 3, r = 60, e = "INVTYPE_RANGED",
    st = { AGI = 5, STA = 11 }, ic = 2, sc = 2, cv = Cand.CACHE_VERSION })

tryUpgrades("Eintrag ganz ohne Stufenangabe:",
  { n = "Outrider's Bow", q = 3, e = "INVTYPE_RANGED",
    st = { AGI = 5, STA = 11 }, ic = 2, sc = 2 })

------------------------------------------------------------------
head("Schritt 6: Kompletter Durchlauf ueber die echte Datenbank")
------------------------------------------------------------------

-- Pool aus dem Import aufbauen, wie im Spiel, und schauen, welche
-- Stufe-60-Teile es bis in die Vorschlaege schaffen.
BananaLootlineDB.itemcache = {}
Cand.StartQuery = function(self) self.state = "ready" end
Cand:StartIndex(Cand:Band())
local guard = 0
while Cand.state == "indexing" or Cand.state == "indexdb" do
  guard = guard + 1
  if guard > 5000 then line("ABBRUCH: Zustandsmaschine haengt") break end
  if Cand.state == "indexing" then Cand:IndexChunk() else Cand:ImportChunk() end
end
local lo, hi = Cand:Band()
line("Band            : " .. lo .. "-" .. hi)
line("Pool gesamt     : " .. tostring(Cand.poolSize))
line("Item im Pool    : " .. (Cand.pool[ITEM] and "JA" or "nein"))

Cand:PreloadFromItemDB()
local ups = Cand:GetUpgrades("RangedSlot", 10)
line("Vorschlaege fuer den Distanzplatz: " .. table.getn(ups or {}))
local bad = 0
for i = 1, table.getn(ups or {}) do
  local u = ups[i]
  local e = BLL.ItemDB:Get(u.id)
  local real = e and e.reqlevel or 0
  local flag = (real > 21) and "  <-- ZU HOCH" or ""
  if real > 21 then bad = bad + 1 end
  line(string.format("   id=%-7s %-32s Anzeige 'ab %s'  Datenbank %s%s",
    tostring(u.id), tostring(u.name), tostring(u.reqLevel), tostring(real), flag))
end
line("Teile ueber der Stufengrenze in der Liste: " .. bad)

print("")
print(bad == 0 and "ERGEBNIS: kein zu hohes Teil in den Vorschlaegen"
                or "ERGEBNIS: es kommen zu hohe Teile durch")
