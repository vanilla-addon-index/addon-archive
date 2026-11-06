string.gmatch = nil; select = nil
local frames = {}
local function newObj()
  local o = { scripts = {} }
  return setmetatable(o, { __index = function(t, k)
    if k == "SetScript" then return function(self, n, f) self.scripts[n] = f end end
    if k == "CreateFontString" or k == "CreateTexture" then return function() return newObj() end end
    if string.find(k, "^%u") then return function() end end
  end })
end
CreateFrame = function() local f = newObj(); table.insert(frames, f); return f end
GetLocale = function() return "deDE" end
GetInventorySlotInfo = function() return 1, "tex" end
getglobal = function(n) return _G[n] end
UIParent = newObj(); GameTooltip = newObj(); ItemRefTooltip = newObj()
DEFAULT_CHAT_FRAME = { AddMessage = function(self, m) print("CHAT", m) end }
hooksecurefunc = nil
SlashCmdList = {}
-- Alte gespeicherte Variablen, wie der Client sie nach Umbenennung der WTF-Datei laedt
OctoLootlineDB = { zoneCategory = { deadmines = "DUNGEON" }, aheadLevels = 4 }
OctoLootlineChar = { gear = { x = 1 }, wishlist = {} }

local toc = io.open("BananaLootline.toc"):read("*a")
for line in string.gfind(toc, "[^\n]+") do
  if not string.find(line, "^##") and string.find(line, "%.lua$") then
    local path = string.gsub(line, "\\", "/")
    local ok, err = pcall(dofile, path)
    if not ok then print("LADEFEHLER", path, err) end
  end
end
local ok = true
local function check(c, m) if not c then ok = false; print("FEHLER: " .. m) end end
check(BananaLootline ~= nil, "globale Tabelle BananaLootline")
check(OctoLootline == nil, "keine alte globale Tabelle")
check(SlashCmdList["BANANALOOTLINE"] ~= nil, "Slash-Handler registriert")
check(SLASH_BANANALOOTLINE1 == "/bll", "/bll")
check(BananaLootlineItemData ~= nil and BananaLootlineSetData ~= nil
  and BananaLootlineZoneData ~= nil and BananaLootlineEnchantData ~= nil, "Datentabellen unter neuem Namen")
for _, f in ipairs(frames) do
  if f.scripts.OnEvent then event = "VARIABLES_LOADED"; this = f; f.scripts.OnEvent() end
end
check(BananaLootlineDB and BananaLootlineDB.zoneCategory.deadmines == "DUNGEON", "Einstellungen uebernommen")
check(BananaLootlineDB.aheadLevels == 4, "eigener Wert bleibt")
check(BananaLootlineDB.tooltipSources == true, "Standardwerte ergaenzt")
check(BananaLootlineChar.gear.x == 1, "Charakterdaten uebernommen")
check(OctoLootlineDB == nil and OctoLootlineChar == nil, "alte Variablen geleert")
check(BananaLootline.migrated == true, "Hinweis vorgemerkt")
print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
