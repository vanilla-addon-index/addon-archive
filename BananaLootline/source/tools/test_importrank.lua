-- Teile, die nur der Import als Quelle kennt, werden nicht nach hinten
-- sortiert.
--
-- "Belt of Binding" stand im Spiel in keiner Liste, obwohl /bll why
-- zeigte: im Pool, tragbar, 13,4 Punkte gegen 1,4, Quelle Hailar the
-- Frigid in Frostmane Hollow. pfQuest kennt das Teil nicht; es galt
-- deshalb als "ohne Fundort" und landete hinter allen Teilen, die
-- pfQuest kennt - mit sechs Plaetzen in der Liste also nirgends.
string.gmatch = nil; select = nil
BananaLootline = { locale = "deDE", clientLocale = "enUS",
                   L = setmetatable({}, { __index = function(t, k) return k end }) }
BananaLootlineDB = { planAhead = 0, itemcache = {} }
CreateFrame = function() return { SetScript = function() end, RegisterEvent = function() end } end
local BLL = BananaLootline
BLL.Print = function() end
dofile("Candidates.lua")
local Cand = BLL.Candidates
local ok = true
local function check(c, m) if not c then ok = false; print("FEHLER: " .. m) end end

local DB = {
  [116]   = { name = "Belt of Binding",  slot = 6, reqlevel = 13, ilvl = 18, quality = 3,
              itemclass = 4, subclass = 2, classmask = -1, stats = { AGI = 12 } },
  [10412] = { name = "Belt of the Fang", slot = 6, reqlevel = 16, ilvl = 21, quality = 3,
              itemclass = 4, subclass = 2, classmask = -1, stats = { AGI = 10 } },
  [5780]  = { name = "Murloc Scale Belt", slot = 6, reqlevel = 14, ilvl = 19, quality = 2,
              itemclass = 4, subclass = 2, classmask = -1, stats = { AGI = 14 } },
}
BLL.ItemDB = { loaded = true, data = DB, Get = function(self, id) return DB[id] end,
               MaskAllows = function() return true end }
BLL.Sources = {
  items    = { [10412] = {} },                       -- pfQuest kennt nur Belt of the Fang
  imported = { [116] = { d = { { n = 63130, p = 33.33, z = 822 } } } },
  GetItemSources = function(self, id)
    if id == 116 then return { { stype = "U", zone = "Frostmane Hollow", chance = 33.33 } } end
    if id == 10412 then return { { stype = "U", zone = "Wailing Caverns", chance = 25 } } end
    return nil
  end,
}
BLL.Weights = { Score = function(self, s) local t = 0; for _, v in pairs(s or {}) do t = t + v end return t end,
                UseEffectScore = function() return 0, false end }
BLL.SetDB = { loaded = false }
BLL.Gear = { equipped = {} }
BLL.player = { class = "HUNTER", level = 16 }
Cand.skills = { known = {}, dualWield = true }
Cand.skillsDirty = false
Cand.AnnouncePool = function() end
Cand.StartQuery = function(self) self.state = "ready" end

Cand.pool, Cand.poolSize, Cand.fromImport, Cand.importCount = { [10412] = 16 }, 1, {}, 0
Cand:StartImportIndex()
while Cand.state == "indexdb" do Cand:ImportChunk() end

check(Cand.pool[116], "Belt of Binding liegt im Pool")
check(not Cand.fromImport[116], "der Import kennt seine Quelle - es gilt nicht als ohne Fundort")
check(Cand.fromImport[5780] == 1, "ein Teil ohne jede Quelle gilt als ohne Fundort")

Cand:PreloadFromItemDB()
local ups = Cand:GetUpgrades("WaistSlot", 6)
check(ups[1] and ups[1].id == 116, "Belt of Binding steht vor Belt of the Fang, steht "
  .. tostring(ups[1] and ups[1].name))
check(ups[2] and ups[2].id == 10412, "Belt of the Fang als zweites")
check(ups[3] and ups[3].id == 5780, "das Teil ohne Fundort trotz hoeherer Punktzahl hinten")

print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
