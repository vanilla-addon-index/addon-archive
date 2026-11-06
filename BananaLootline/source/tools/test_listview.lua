string.gmatch = nil; select = nil
-- Minimaler 1.12-UI-Stub: Frames, Texturen, FontStrings mit Breitenmessung
local function strip(t) t = string.gsub(t, "|c%x%x%x%x%x%x%x%x", ""); return (string.gsub(t, "|r", "")) end
local function newObj(kind)
  local o = { kind = kind, shown = true, h = 0, w = 0, text = "", size = 13, scripts = {}, pts = {} }
  local mt = {}
  mt.__index = function(t, k)
    local m = {
      Show = function(self) self.shown = true end, Hide = function(self) self.shown = false end,
      IsShown = function(self) return self.shown end,
      SetHeight = function(self, v) self.h = v end, GetHeight = function(self) return self.h end,
      SetWidth = function(self, v) self.w = v end, GetWidth = function(self) return self.w end,
      SetText = function(self, v) self.text = v or "" end, GetText = function(self) return self.text end,
      SetFont = function(self, f, s, o2) self.size = s end,
      GetStringWidth = function(self)
        -- ~0.55 Pixel pro Punkt Schriftgroesse und Zeichen, Outline +5%
        local n = string.len(strip(self.text))
        return n * self.size * 0.55
      end,
      SetScript = function(self, n, f) self.scripts[n] = f end,
      SetPoint = function(self, a, rel, b, x, y) table.insert(self.pts, {a, x, y}) end,
      ClearAllPoints = function(self) self.pts = {} end,
      CreateTexture = function() return newObj("tex") end,
      CreateFontString = function() return newObj("fs") end,
      SetMinMaxValues = function(self, a, b) self.min, self.max = a, b end,
      SetValue = function(self, v) self.val = v; if self.scripts.OnValueChanged then this = self; self.scripts.OnValueChanged() end end,
      GetValue = function(self) return self.val end,
    }
    if m[k] then return m[k] end
    if string.find(k, "^%u") then return function() end end
    return nil
  end
  return setmetatable(o, mt)
end
CreateFrame = function(k) return newObj(k) end
GetItemInfo = function() return nil end
GetLocale = function() return "deDE" end

BananaLootline = { locale = "deDE", player = { level = 15 } }
dofile("Locale.lua")
local BLL = BananaLootline
BLL.locale = "deDE"
BLL.L = BLL.L or {}; BLL.L.QUEST_CHOICE = "Wahl aus"
BLL.Scanner = { GetLines = function() end }
dofile("UI.lua")
local UI = BLL.UI
UI.frame = newObj("Frame")
UI:BuildDetailPane()
local pane = UI.detail

local ok = true
local function check(c, msg) if not c then ok = false; print("FEHLER: " .. msg) end end
local avail = pane:GetHeight() - 34 - 10

local function checkRows(label)
  local lastBottom = -1
  for i = 1, table.getn(pane.llRows) do
    local r = pane.llRows[i]
    if r.shown then
      local y = -r.pts[1][3]
      check(y >= lastBottom, label .. ": Zeile " .. i .. " ueberlappt")
      check(y + r.h <= 34 + avail, label .. ": Zeile " .. i .. " ragt unten raus")
      lastBottom = y + r.h
      check(r.leftText:GetStringWidth() <= r.leftText.w + 0.01,
        label .. ": zu breit: " .. strip(r.leftText.text))
      if r.subText.shown then
        check(r.subText:GetStringWidth() <= r.subText.w + 0.01, label .. ": Werte zu breit")
      end
    end
  end
end

-- Verzauberungen: 6 Slots a 3 Eintraege -> muss scrollen
local groups = {}
local slots = { "Umhang", "Brust", "Armschiene", "Haende", "Fuesse", "Waffe" }
for s = 1, 6 do
  local items = {}
  for i = 1, 3 do
    table.insert(items, { name = "Verzauberung " .. slots[s] .. " - Grosser Widerstand " .. i, src = "Verzauberkunst",
      stats = { RES_FIRE = 5, RES_FROST = 5, RES_NATURE = 5, RES_SHADOW = 5, RES_ARCANE = 5 }, score = 7.5 })
  end
  table.insert(groups, { slotName = slots[s], items = items })
end
BLL.EnchantDB = { loaded = true, GetAll = function() return groups end }
UI:ShowEnchants()
check(table.getn(pane.list) == 24, "Listenlaenge Verzauberung")
check(pane.scroll.shown, "Scrollleiste sichtbar")
checkRows("Verz. oben")
local r1 = pane.llRows[2]
check(r1.subText.shown and string.find(r1.subText.text, "alle Widerstaende") ~= nil, "Widerstaende zusammengefasst: " .. r1.subText.text)
check(string.find(r1.subText.text, "RES_") == nil, "keine internen Schluessel")

-- Mausrad bis ganz nach unten
for k = 1, 30 do arg1 = -1; pane.scripts.OnMouseWheel() end
checkRows("Verz. unten")
local lastShown
for i = 1, table.getn(pane.llRows) do if pane.llRows[i].shown then lastShown = pane.llRows[i] end end
check(lastShown and string.find(lastShown.leftText.text, "Waffe") ~= nil, "Letzter Eintrag erreichbar")
check(pane.scroll.val == pane.offset, "Leiste folgt Mausrad")
-- Ueber die Leiste zurueck nach oben
pane.scroll:SetValue(1)
check(pane.offset == 1, "Leiste setzt Position")

-- Lootline: lange Zonennamen mit Umlaut
BLL.Candidates = { Progress = function() return nil end, pool = {} }
local ll = {}
local zones = { "Die Todesminen", "Rotkammgebirge", "Scharlachrotes Kloster - Kathedrale Grabmal Düsterbruch", "Westfall" }
for z = 1, 4 do
  local items = {}
  for i = 1, 7 do table.insert(items, { id = i, name = "Sehr langer Itemname Nummer " .. i .. " des Grauens", slotName = "Schildhand", quality = 2, chance = 1.5, pct = 50 }) end
  table.insert(ll, { zone = zones[z], category = "DUNGEON", lvlRange = "17-24", minLevel = "17", items = items, priority = 100 - z })
end
BLL.Candidates.GetLootline = function() return ll end
UI:ShowLootline()
check(pane.offset == 1, "Ansichtswechsel setzt Position zurueck")
checkRows("Lootline oben")
for k = 1, 5 do arg1 = -1; pane.scripts.OnMouseWheel() end
checkRows("Lootline mitte")
-- Umlaut nicht zerschnitten
for i = 1, table.getn(pane.llRows) do
  local t = pane.llRows[i].leftText.text
  local bad = string.find(t, "[\195][^\128-\191]") or string.find(t, "[\195]$")
  check(not bad, "UTF-8 zerschnitten: " .. t)
end
-- Aktualisierung derselben Ansicht behaelt Position
local keep = pane.offset
UI:ShowLootline()
check(pane.offset == keep, "Refresh behaelt Position")
-- Kopfzeile: Klammerzahl und Stufenbereich bleiben erhalten
local head = pane.llRows[1]
for i = 1, table.getn(pane.llRows) do
  local t = strip(pane.llRows[i].leftText.text)
  if string.find(t, "Kathedrale") or string.find(t, "Scharlach") then
    print("Kopf: " .. t)
    check(string.find(t, "%(7%)") and string.find(t, "17%-24") and string.find(t, "%.%.%."), "Kopf gekuerzt, Anzahl/Stufe erhalten")
  end
end
print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
