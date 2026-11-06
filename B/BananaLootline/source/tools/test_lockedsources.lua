-- Teile, deren Quellen alle in noch gesperrten Phasen liegen, fallen aus
-- jeder Liste - nicht nur ihre Quellen.
--
-- Gemeldet von einem Tester auf Stufe 60: "Pro Item" zeigte Drake Fang
-- Talisman (BWL), Shieldrender Talisman (Rock of Desolation), Jom Gabbar
-- (AQ40) und Bonescythe Gauntlets (Naxxramas), alle mit "No source data".
string.gmatch = nil; select = nil
GetLocale = function() return "enUS" end
BananaLootline = {}
dofile("Locale.lua")
local BLL = BananaLootline
BLL.Print, BLL.Debug = function() end, function() end
GameTooltip = { AddLine = function() end }
CreateFrame = function() return { SetScript = function() end, RegisterEvent = function() end } end
WorldFrame, getglobal = {}, function() end
BananaLootlineDB = {}
dofile("Data/SourceData.lua"); dofile("Data/ZoneNames.lua"); dofile("Data/NpcData.lua")
dofile("Data/ItemData.lua")
dofile("Phases.lua")
pfDB = nil
dofile("Sources.lua"); BLL.Sources:Init()
local S = BLL.Sources
local ok = true
local function check(c, m) if not c then ok = false; print("FEHLER: " .. m) end end

local byName = {}
for id, e in pairs(BananaLootlineItemData) do byName[e.name] = id end

for _, n in ipairs({ "Drake Fang Talisman", "Shieldrender Talisman", "Jom Gabbar",
                     "Bonescythe Gauntlets" }) do
  check(byName[n] and S:OnlyLockedSources(byName[n]), n .. " gilt als gesperrt")
end
-- Gegenproben: offene Instanz, hergestellt, unbekannt
check(not S:OnlyLockedSources(116), "Belt of Binding (Frostmane Hollow) bleibt")
check(not S:OnlyLockedSources(6468), "Deviate Scale Belt (hergestellt) bleibt")
check(not S:OnlyLockedSources(99999999), "unbekanntes Teil bleibt")

-- Wird die Phase von Hand geoeffnet, ist das Teil wieder da
local id = byName["Bonescythe Gauntlets"]
BananaLootlineDB.phaseOpen = { [6] = true }
check(not S:OnlyLockedSources(id), "nach /bll phase 6 on wieder erreichbar")
print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
