string.gmatch = nil; select = nil
local function strip(t) t = string.gsub(t, "|c%x%x%x%x%x%x%x%x", ""); return (string.gsub(t, "|r", "")) end
local function newObj(kind)
  local o = { kind = kind, shown = true, h = 0, w = 0, text = "", size = 13, scripts = {}, pts = {} }
  return setmetatable(o, { __index = function(t, k)
    local m = {
      Show = function(self) self.shown = true end, Hide = function(self) self.shown = false end,
      IsShown = function(self) return self.shown end,
      SetHeight = function(self, v) self.h = v end, GetHeight = function(self) return self.h end,
      SetWidth = function(self, v) self.w = v end,
      SetText = function(self, v) self.text = v or "" end,
      SetTexture = function(self, v) self.tex = v end,
      SetFont = function(self, f, s) self.size = s end,
      GetStringWidth = function(self)
        local w = 0
        for line in string.gfind(strip(self.text) .. "\n", "([^\n]*)\n") do
          local lw = string.len(line) * self.size * 0.55
          if lw > w then w = lw end
        end
        return w
      end,
      SetScript = function(self, n, f) self.scripts[n] = f end,
      SetPoint = function(self, a, rel, b, x, y) table.insert(self.pts, { a, x, y }) end,
      ClearAllPoints = function(self) self.pts = {} end,
      CreateTexture = function() return newObj("tex") end,
      CreateFontString = function() return newObj("fs") end,
      SetMinMaxValues = function() end, SetValue = function(self, v) self.val = v end,
    }
    if m[k] then return m[k] end
    if string.find(k, "^%u") then return function() end end
  end })
end
CreateFrame = function(k) return newObj(k) end
GetItemInfo = function() return nil, nil, nil, nil, nil, nil, nil, nil, "Interface\\Icons\\X" end
GetLocale = function() return "deDE" end
GameTooltip = newObj("Tooltip")
GetInventorySlotInfo = function() return 6 end
GetInventoryItemTexture = function() return "Interface\\Icons\\Belt" end
local chat = {}
BananaLootline = { player = { level = 15 } }
dofile("Locale.lua")
local BLL = BananaLootline
BLL.locale = "deDE"
BLL.Print = function(self, m) table.insert(chat, m) end
BLL.Scanner = { GetLines = function() end }
BLL.Weights = { Get = function() return { STA = 1, STR = 1, INT = 0.5, SPI = 0.3, ARMOR = 0.05, AGI = 1 } end }
dofile("UI.lua")
local UI = BLL.UI
UI.frame = newObj("Frame")
UI:BuildDetailPane()
local pane = UI.detail
local sv = pane.slotView
local ok = true
local function check(c, m) if not c then ok = false; print("FEHLER: " .. m) end end

BLL.Gear = { equipped = { WaistSlot = { name = "Dryweed Belt", quality = 2, stats = { INT = 2, ARMOR = 38 } } } }
local function src(n, ch, z, t, ql) return { { name = n, chance = ch, zone = z, stype = t or "U", questLevel = ql } } end
BLL.Candidates = { pool = {}, Progress = function() return nil end,
  GetUpgrades = function(self, slot, n) return {
    { id = 1, name = "Girdle of Nobility", quality = 2, gain = 1.9, diff = { STA = 2, ARMOR = -20, INT = 1 }, sources = src("Brainwashed Noble", 64, "Westfall") },
    { id = 2, name = "Heated Leather Belt", quality = 2, gain = 1.1, diff = { STR = 2, ARMOR = 4, SPI = 1 }, sources = src("Bazzalan", 30, "Ragefire Chasm") },
    { id = 3, name = "Ein extrem langer Gürtelname der Weisheit und des Überflusses", quality = 3, gain = 12.4, locked = true, reqLevel = 20,
      diff = { STA = 2, INT = -2, ARMOR = -22, SPI = 2, AGI = 5, STR = 3 }, sources = src("Der Questgeber mit sehr langem Namen", 1, "Loch Modan", "Q", 18) },
  } end }

UI:ShowDetail("WaistSlot")
check(sv.shown, "Slotansicht sichtbar")
check(strip(sv.secCur.text.text) == "Angelegt" and strip(sv.secUp.text.text) == "Upgrades", "Bereichstitel")
check(strip(sv.cur.name.text) == "Dryweed Belt", "Name angelegt")
check(sv.cur.icon.tex == "Interface\\Icons\\Belt", "Icon angelegt")
check(string.find(strip(sv.cur.stats.text), "+2 Int.") and string.find(strip(sv.cur.stats.text), "+38 Ruestung"), "Werte lesbar: " .. strip(sv.cur.stats.text))
check(string.find(sv.cur.stats.text, "ARMOR") == nil, "keine internen Schluessel")
check(strip(sv.secUp.right.text) == "3 gefunden", "Anzahl")

local lastBottom = 130
for i = 1, 3 do
  local r = pane.rows[i]
  check(r.shown, "Zeile " .. i .. " sichtbar")
  local top = -r.pts[1][3]
  check(top >= lastBottom, "Zeile " .. i .. " ueberlappt")
  lastBottom = top + r.h
  check(lastBottom <= 540, "Zeile " .. i .. " ragt aus dem Bereich")
  for _, fs in ipairs({ r.name, r.diffText, r.srcText }) do
    check(fs:GetStringWidth() <= fs.w + 0.01, "Zeile " .. i .. " zu breit: " .. strip(fs.text))
    check(string.find(fs.text, "\n") == nil, "Zeile " .. i .. " mehrzeilig")
  end
  print(i, strip(r.name.text), "|", strip(r.value.text), "|", strip(r.diffText.text), "|", strip(r.srcText.text))
end
-- Grosse Chancen ohne Nachkommastelle, kleine mit dreien: die Zahlen
-- aus dem Export reichen bis 0,0045 Prozent, "0.0%" waere dort nichts
-- als ein Irrtum. Siehe BLL:FormatChance in Locale.lua.
check(string.find(strip(pane.rows[1].srcText.text), "Brainwashed Noble  64%  Westfall", 1, true), "Quelle mit Chance und Zone")
check(BLL:FormatChance(0.0045) == "0.0045%", "winzige Chance bleibt lesbar")
check(BLL:FormatChance(0.00001) == "<0.0001%", "noch kleinere wird zusammengefasst")
check(BLL:FormatChance(0.0163) == "0.016%", "kleine Chance mit drei Stellen")
check(BLL:FormatChance(1.92) == "1.9%", "einstellige Chance mit einer Stelle")
check(BLL:FormatChance(0) == nil, "null ist keine Chance")
check(strip(pane.rows[1].value.text) == "+1.9", "Wert")
local q = strip(pane.rows[3].srcText.text)
check(string.find(q, "^ab 20") and string.find(q, "Quest:") and string.find(q, "Stufe 18") and string.find(q, "Loch Modan") and not string.find(q, "1.0%%"), "Questquelle: " .. q)
check(not pane.rows[3].sep.shown and pane.rows[1].sep.shown, "Trennlinien")
check(not pane.rows[4].shown, "leere Zeilen versteckt")

-- Leerer Slot
UI:ShowDetail("HeadSlot")
check(strip(sv.cur.name.text) == "Leer" and string.find(sv.cur.icon.tex, "PaperDoll"), "leerer Slot")

-- Verzauberungen ohne Partner-Addon
local groups = { { slotName = "Umhang", items = { { name = "Enchant Cloak - Lesser Agility", src = "Verzauberkunst", stats = { AGI = 3 }, score = 7.5 } } } }
BLL.EnchantDB = { loaded = true, GetAll = function() return groups end }
UI:ShowEnchants()
check(not sv.shown, "Slotansicht beim Wechsel versteckt")
local row = pane.llRows[2]
check(string.find(row.subText.text, "Crafter") == nil, "ohne Addon keine Crafterangabe")
this = row; row.scripts.OnClick()
check(string.find(chat[table.getn(chat)], "nicht installiert"), "Hinweis ohne Addon")

-- Mit Partner-Addon
local shown
BRPP_API = { version = 1,
  GetCrafters = function(n) if n == "Enchant Cloak - Lesser Agility" then return 3, 1, 1 end return 0, 0, 0 end,
  ShowRecipe = function(n) shown = n; return n == "Enchant Cloak - Lesser Agility" end }
UI:ShowEnchants()
row = pane.llRows[2]
print(strip(row.subText.text))
check(string.find(strip(row.subText.text), "3 Crafter %(1 online%)"), "Crafterangabe")
this = row; row.scripts.OnClick()
check(shown == "Enchant Cloak - Lesser Agility", "Klick oeffnet Partner-Addon")
groups[1].items[1].name = "Enchant Cloak - Unknown"
UI:ShowEnchants()
check(string.find(strip(pane.llRows[2].subText.text), "kein Crafter"), "kein Crafter")
this = pane.llRows[2]; pane.llRows[2].scripts.OnClick()
check(string.find(chat[table.getn(chat)], "Niemand"), "Hinweis ohne Treffer")
print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
