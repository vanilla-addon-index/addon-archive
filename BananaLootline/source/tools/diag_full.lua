--[[
  Vollpruefung mit echten Daten ueber alle Ausruestungsplaetze.

  Prueft jeden Vorschlag gegen die Itemdatenbank:
    - Anforderungsstufe innerhalb des erlaubten Bereichs?
    - Anzeige und Datenbank einig?
    - Slot passend?
    - Klassenmaske eingehalten?
    - Ruestungsart erlaubt?

  Aufruf vom Addonstamm:  lua5.1 tools/diag_full.lua [Stufe] [Klasse]
]]
string.gmatch = nil; select = nil

local LEVEL = tonumber(arg and arg[1]) or 15
local CLASS = (arg and arg[2]) or "HUNTER"

CreateFrame = function()
  return { SetScript = function() end, RegisterEvent = function() end }
end
GetItemInfo       = function() return nil end
GetNumSkillLines  = function() return 0 end
GetSkillLineInfo  = function() return nil end
ExpandSkillHeader = function() end
UnitLevel         = function() return LEVEL end

BananaLootline = { locale = "enUS", clientLocale = "enUS" }
BananaLootline.L = setmetatable({}, { __index = function(t, k) return k end })
BananaLootlineDB = { planAhead = 6, itemcache = {} }

local BLL = BananaLootline
BLL.Print, BLL.Debug = function() end, function() end

dofile("Data/ItemData.lua")
dofile("ItemDB.lua")
BLL.ItemDB:Refresh()

BLL.Weights = {
  DEFAULT_COOLDOWN = 120,
  Get = function() return { AGI = 1, STA = 1, STR = 1, INT = 1, SPI = 1,
                            ARMOR = 0.05, WEAPON_DPS = 1 } end,
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

-- Alle Plaetze, die das Addon kennt, mit leerer Ausruestung: so
-- bekommt jeder Platz Vorschlaege und nichts faellt durchs Raster.
local SLOTKEYS = {
  "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot",
  "WristSlot", "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot",
  "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot",
  "MainHandSlot", "SecondaryHandSlot", "RangedSlot",
}
local SLOTS = {}
for i = 1, table.getn(SLOTKEYS) do SLOTS[i] = { key = SLOTKEYS[i] } end

BLL.Gear = {
  SLOTS = SLOTS,
  SlotLabel = function(self, s) return s.key end,
  equipped = {},
}

dofile("Candidates.lua")
local Cand = BLL.Candidates
BLL.player = { class = CLASS, level = LEVEL }

-- Pool wie im Spiel aufbauen
Cand.StartQuery = function(self) self.state = "ready" end
Cand:StartIndex(Cand:Band())
local guard = 0
while Cand.state == "indexing" or Cand.state == "indexdb" do
  guard = guard + 1
  if guard > 20000 then print("ABBRUCH") break end
  if Cand.state == "indexing" then Cand:IndexChunk() else Cand:ImportChunk() end
end
Cand:PreloadFromItemDB()

local lo, hi = Cand:Band()
local maxReq = LEVEL + Cand:PlanAhead()

print("Klasse " .. CLASS .. ", Stufe " .. LEVEL)
print("Band " .. lo .. "-" .. hi .. ", Stufengrenze fuer Vorschlaege: " .. maxReq)
print("Pool: " .. tostring(Cand.poolSize) .. " Gegenstaende")
print("")

local SLOTNUM = {
  [1]="HeadSlot",[2]="NeckSlot",[3]="ShoulderSlot",[5]="ChestSlot",
  [6]="WaistSlot",[7]="LegsSlot",[8]="FeetSlot",[9]="WristSlot",
  [10]="HandsSlot",[11]="Finger",[12]="Trinket",[13]="Hand",
  [14]="SecondaryHandSlot",[15]="RangedSlot",[16]="BackSlot",
  [17]="MainHandSlot",[20]="ChestSlot",[21]="MainHandSlot",
  [22]="SecondaryHandSlot",[23]="SecondaryHandSlot",[25]="RangedSlot",
  [26]="RangedSlot",[28]="RangedSlot",
}
local ARMOR_OK = { CLOTH=1, LEATHER=1, MAIL=1, PLATE=1, SHIELD=1 }
local CLASSBIT = { WARRIOR=1, PALADIN=2, HUNTER=4, ROGUE=8, PRIEST=16,
                   SHAMAN=64, MAGE=128, WARLOCK=256, DRUID=1024 }

local total, problems = 0, {}
local function note(kind, msg)
  problems[kind] = problems[kind] or {}
  table.insert(problems[kind], msg)
end

for s = 1, table.getn(SLOTKEYS) do
  local key = SLOTKEYS[s]
  local ups = Cand:GetUpgrades(key, 5)
  for i = 1, table.getn(ups or {}) do
    local u = ups[i]
    total = total + 1
    local e = BLL.ItemDB:Get(u.id)
    local real = e and e.reqlevel or nil

    -- 1. Stufengrenze
    if real and real > maxReq then
      note("zu hohe Stufe", string.format(
        "%s: id=%d %s  Datenbank ab %d, Grenze %d",
        key, u.id, tostring(u.name), real, maxReq))
    end

    -- 2. Anzeige gegen Datenbank
    if real and real > 0 and u.reqLevel and u.reqLevel ~= real then
      note("Anzeige weicht ab", string.format(
        "%s: id=%d %s  Anzeige %s, Datenbank %d",
        key, u.id, tostring(u.name), tostring(u.reqLevel), real))
    end

    -- 3. Anzeige fehlt trotz Stufenangabe
    if real and real > 0 and not u.reqLevel then
      note("Anzeige fehlt", string.format(
        "%s: id=%d %s  Datenbank ab %d, Anzeige leer",
        key, u.id, tostring(u.name), real))
    end

    -- 4. Klassenmaske
    if e and e.classmask and e.classmask ~= -1 and e.classmask ~= 0 then
      local bit = CLASSBIT[CLASS]
      if bit and math.mod(math.floor(e.classmask / bit), 2) ~= 1 then
        note("falsche Klasse", string.format(
          "%s: id=%d %s  classmask=%d", key, u.id, tostring(u.name), e.classmask))
      end
    end

    -- 5. Slot
    if e and e.slot then
      local expect = SLOTNUM[e.slot]
      if expect and expect ~= "Finger" and expect ~= "Trinket" and expect ~= "Hand"
         and expect ~= key then
        note("falscher Platz", string.format(
          "%s: id=%d %s  gehoert auf %s", key, u.id, tostring(u.name), expect))
      end
    end
  end
end

print("Vorschlaege insgesamt: " .. total)
print("")

local order = { "zu hohe Stufe", "Anzeige weicht ab", "Anzeige fehlt",
                "falsche Klasse", "falscher Platz" }
local any = false
for i = 1, table.getn(order) do
  local k = order[i]
  local list = problems[k]
  if list then
    any = true
    print("-- " .. k .. " (" .. table.getn(list) .. ") --")
    for j = 1, math.min(8, table.getn(list)) do print("   " .. list[j]) end
    if table.getn(list) > 8 then
      print("   ... und " .. (table.getn(list) - 8) .. " weitere")
    end
    print("")
  end
end

print(any and "ERGEBNIS: Auffaelligkeiten gefunden"
           or "ERGEBNIS: keine Auffaelligkeiten")
