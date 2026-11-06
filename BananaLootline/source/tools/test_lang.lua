string.gmatch = nil; select = nil
local function strip(t) t = string.gsub(t or "", "|c%x%x%x%x%x%x%x%x", ""); return (string.gsub(t, "|r", "")) end
local function newObj(kind)
  local o = { shown = true, h = 0, w = 0, text = "", size = 13, scripts = {}, pts = {}, level = 1 }
  return setmetatable(o, { __index = function(t, k)
    local m = {
      Show = function(self) self.shown = true end, Hide = function(self) self.shown = false end,
      IsShown = function(self) return self.shown end,
      SetHeight = function(self, v) self.h = v end, GetHeight = function(self) return self.h end,
      SetWidth = function(self, v) self.w = v end,
      SetText = function(self, v) self.text = v or "" end, GetText = function(self) return self.text end,
      SetTexture = function(self, v) self.tex = v end, GetTexture = function(self) return self.tex end,
      SetFont = function(self, f, s) self.size = s end,
      SetTextColor = function(self, r, g, b) self.color = { r, g, b } end,
      GetStringWidth = function(self) return string.len(strip(self.text)) * self.size * 0.55 end,
      SetScript = function(self, n, f) self.scripts[n] = f end,
      SetPoint = function(self, a, rel, b, x, y) table.insert(self.pts, { a, x, y }) end,
      ClearAllPoints = function(self) self.pts = {} end,
      CreateTexture = function() return newObj("tex") end,
      CreateFontString = function() return newObj("fs") end,
      GetFrameLevel = function(self) return self.level end, SetFrameLevel = function(self, v) self.level = v end,
    }
    if m[k] then return m[k] end
    if string.find(k, "^%u") then return function() end end
  end })
end
CreateFrame = function(k, name) local f = newObj(k); if name then _G[name] = f end; return f end
UIParent = newObj(); GameTooltip = newObj(); UISpecialFrames = {}
tinsert = table.insert
GetLocale = function() return "enUS" end          -- englischer Client
GetInventorySlotInfo = function() return 1 end
GetInventoryItemTexture = function() return nil end
UnitStat = function(u, i) return 20 + i, 20 + i, 0, 0 end
UnitArmor = function() return 461, 461 end
UnitAttackPower = function() return 80, 7, 0 end
UnitRangedAttackPower = function() return 130, 6, 0 end
GetCritChance = function() return 5.2 end
GetDodgeChance = function() return 6.11 end
local chat = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(self, m) table.insert(chat, m) end }

BananaLootline = {}
dofile("Locale.lua")
local BLL = BananaLootline
local ok = true
local function check(c, m) if not c then ok = false; print("FEHLER: " .. m) end end

local L = BLL.L                              -- wie Core.lua: Referenz vorher gemerkt
check(BLL.locale == "enUS" and L["EMPTY"] == "Empty", "Start in Clientsprache")
local patterns = BLL.PATTERNS
BLL:SetLanguage("deDE")
check(BLL.locale == "deDE" and L["EMPTY"] == "Leer", "Umschalten erreicht gemerkte Referenz")
check(BLL.PATTERNS == patterns and BLL.clientLocale == "enUS", "Tooltip-Muster bleiben Clientsprache")
check(string.find(BLL.DMG_PATTERN, "Damage") ~= nil, "Schadensmuster bleibt englisch")
BLL:SetLanguage("auto")
check(BLL.locale == "enUS", "auto = Client")

BLL.Print = function(self, m) table.insert(chat, m) end
BLL.player = { name = "Lumihunt", level = 15, class = "HUNTER" }
BLL.Gear = { equipped = {}, SLOTS = {}, SlotLabel = function() return "" end }
BLL.Scanner = { GetLines = function() end, ClearCache = function() end }
BLL.Weights = { Get = function() return {} end, activeSpec = nil }
BLL.Sources = { available = true }
BLL.Candidates = { pool = nil, Progress = function() return nil end, GetLootline = function() return {} end }
BananaLootlineDB = { language = "auto" }
dofile("UI.lua")
local UI = BLL.UI
UI.UpdateSelection = function() end
UI.RefreshModel = function() end
UI.CreateSlotButton = function() return newObj("Button") end
UI:Init()
local f = UI.frame
f.shown = true
UI.slotButtons = {}

-- Statfeld wie im Charakterfenster: zwei Kaesten, je sechs Zeilen
UnitAttackBothHands = function() return 65, 4 end
UnitDamage = function() return 14.2, 17.6 end
UnitAttackSpeed = function() return 1.8 end
UnitStat = function(u, i) if i == 5 then return 31, 29, 0, -2 end return 20 + i, 20 + i, (i == 1) and 2 or 0, 0 end
UnitArmor = function() return 461, 461, 461, 0, 0 end
UnitRangedAttack = function() return 70, 0 end
UnitRangedDamage = function() return 2.9, 20.1, 31.8 end
UnitDefense = function() return 75, 0 end
UnitHealthMax = function() return 420 end
UnitManaMax = function() return 380 end
BananaLootlineChar = {}
UI:UpdateStatsPanel()
local sp = UI.statsPanel
local function boxRows(b)
  local out = {}
  for i = 1, 6 do
    local c = sp.boxes[b].cells[i]
    out[i] = strip(c.label.text) .. strip(c.value.text)
  end
  return out
end
local L1, R1 = boxRows(1), boxRows(2)
print(strip(sp.boxes[1].head.text.text) .. " | " .. table.concat(L1, "  "))
print(strip(sp.boxes[2].head.text.text) .. " | " .. table.concat(R1, "  "))
check(strip(sp.boxes[1].head.text.text) == "Base Stats" and strip(sp.boxes[2].head.text.text) == "Melee", "Kopfzeilen wie im Original")
check(L1[1] == "Strength:21" and L1[5] == "Spirit:29" and L1[6] == "Armor:461", "Grundwerte")
check(string.find(sp.boxes[1].cells[1].value.text, "44ff44") and string.find(sp.boxes[1].cells[5].value.text, "ff5555"), "gruen/rot nach Modifikator")
check(R1[1] == "Skill:69" and R1[2] == "Damage:14 - 18" and R1[3] == "Speed:1.80" and R1[4] == "Power:87"
  and R1[5] == "Hit Rating:0%" and R1[6] == "Crit Chance:5.20%", "Nahkampf wie im Original")
local x, y = sp.pts[1][2], sp.pts[1][3]
check(x >= 46 and x + sp.w <= 284, "zwischen den Slotspalten (x " .. x .. " bis " .. (x + sp.w) .. ")")
check(y == -228 and y - sp.h >= -338, "direkt unter der Figur, ueber Slotname und Waffen (y " .. y .. " bis " .. (y - sp.h) .. ")")
check(sp.level > UI.model:GetFrameLevel(), "ueber dem Modell")
for b = 1, 2 do for i = 1, 6 do
  local c = sp.boxes[b].cells[i]
  check(c.label:GetStringWidth() + c.value:GetStringWidth() + 4 <= c.label.w, "zu eng: " .. strip(c.label.text) .. strip(c.value.text))
end end
-- Auswahl ueber das Menue
local added = {}
UIDropDownMenu_AddButton = function(info) table.insert(added, info) end
sp.boxes[2].dd.initialize()
check(table.getn(added) == 5 and added[2].checked, "Menue mit fuenf Kategorien, Nahkampf markiert")
this = { value = "RANGED" }; added[3].func()
check(strip(sp.boxes[2].head.text.text) == "Ranged" and BananaLootlineChar.statBoxes.right == "RANGED", "Auswahl gespeichert")
R1 = boxRows(2)
check(R1[1] == "Skill:70" and R1[2] == "Damage:20 - 32" and R1[3] == "Speed:2.90", "Distanzwerte")
-- Ohne Menue-API blaettert der Klick weiter
ToggleDropDownMenu = nil
this = sp.boxes[2].head; sp.boxes[2].head.scripts.OnClick()
check(BananaLootlineChar.statBoxes.right == "SPELL", "Blaettern als Rueckfall")
for _, cat in ipairs({ "SPELL", "DEFENSE" }) do
  UI:SetStatBoxCat(sp.boxes[2], cat)
  for i = 1, 6 do
    local c = sp.boxes[2].cells[i]
    check(c.label:GetStringWidth() + c.value:GetStringWidth() + 4 <= c.label.w, cat .. " zu eng: " .. strip(c.label.text) .. strip(c.value.text))
  end
  print(cat .. " | " .. table.concat(boxRows(2), "  "))
end
UI:SetStatBoxCat(sp.boxes[2], "MELEE")

-- Sprachknopf DE
check(f.enBtn.fs.color[1] == 1 and f.deBtn.fs.color[1] == 0.5, "EN aktiv markiert")
this = f.deBtn; f.deBtn.scripts.OnClick()
check(BananaLootlineDB.language == "deDE" and BLL.locale == "deDE", "DE gespeichert")
check(f.deBtn.fs.color[1] == 1, "DE aktiv markiert")
check(UI.viewButtons[2].text == "Pro Item" and UI.viewButtons[3].text == "Verzauberung", "Ansichtsknoepfe deutsch")
check(UI.rescanBtn.text == "Neu scannen" and UI.upgradeBtn.text == "Upgrades suchen", "Knoepfe deutsch")
check(strip(sp.boxes[1].head.text.text) == "Grundwerte" and strip(sp.boxes[1].cells[6].label.text) == "Ruestung:", "Statfeld deutsch")
for b = 1, 2 do for i = 1, 6 do local c = sp.boxes[b].cells[i]
  check(c.label:GetStringWidth() + c.value:GetStringWidth() + 4 <= c.label.w, "DE zu eng: " .. strip(c.label.text) .. strip(c.value.text)) end end
check(string.find(f.subtitle.text, "Stufe 15") and string.find(f.subtitle.text, "keine Spez. erkannt"), "Untertitel deutsch")
check(string.find(chat[table.getn(chat)], "Deutsch"), "Chatmeldung")
this = f.enBtn; f.enBtn.scripts.OnClick()
check(UI.viewButtons[2].text == "Per item" and string.find(f.subtitle.text, "no spec detected"), "zurueck auf Englisch")

-- Dankesfenster
UI:ShowThanks()
local tf = UI.thanksFrame
check(tf.shown and strip(tf.titleFS.text) == "Thank you for your support!", "Dankesfenster englisch")
check(tf.nameBox.text == "Lumihunt", "Autorname")
this = f.deBtn; f.deBtn.scripts.OnClick()
check(tf.titleFS.text == "Danke fuer die Unterstuetzung!" and tf.okBtn.text == "Schliessen", "Dankesfenster folgt der Sprache")
this = tf.mailBtn; tf.mailBtn.scripts.OnClick()
check(string.find(chat[table.getn(chat)], "Briefkasten"), "Hinweis ohne Briefkasten")
print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
