string.gmatch = nil; select = nil
BananaLootline = { locale = "deDE", clientLocale = "enUS", L = setmetatable({}, { __index = function(t, k) return k end }) }
BananaLootlineDB = { planAhead = 6 }
CreateFrame = function() return { SetScript = function() end, Hide = function() end, Show = function() end, RegisterEvent = function() end } end
local BLL = BananaLootline
BLL.Gear = { equipped = {}, SLOTS = {} }
BLL.Weights = {
  Score = function(self, st) local n = 0; for _, v in pairs(st or {}) do n = n + v end; return n end,
  UseEffectScore = function() return 0 end,
}
dofile("Candidates.lua")
BLL.Sources = { GetItemSources = function() return {} end }
local Cand = BLL.Candidates
local ok = true
local function check(c, m) if not c then ok = false; print("FEHLER: " .. m) end end

-- Fertigkeitenfenster nachbilden wie der Client: Kopfzeilen immer
-- sichtbar, Unterzeilen nur unter aufgeklappten Kopfzeilen.
local lines, expanded
local function visible()
  local out, open = {}, true
  for _, l in ipairs(lines) do
    if l[2] then open = expanded[l[1]]; table.insert(out, l)
    elseif open then table.insert(out, l) end
  end
  return out
end
local function setSkills(list, collapsedHeader)
  lines = list; expanded = {}
  for _, l in ipairs(lines) do if l[2] then expanded[l[1]] = (l[1] ~= collapsedHeader) end end
  GetNumSkillLines = function() return table.getn(visible()) end
  GetSkillLineInfo = function(i)
    local l = visible()[i]; if not l then return nil end
    return l[1], l[2], l[2] and expanded[l[1]] or nil
  end
  ExpandSkillHeader = function(i)
    if i == 0 then for k in pairs(expanded) do expanded[k] = true end
    else local l = visible()[i]; if l and l[2] then expanded[l[1]] = true end end
  end
  CollapseSkillHeader = function(i)
    local l = visible()[i]; if l and l[2] then expanded[l[1]] = false end
  end
  Cand.skillsDirty = true
end

local W = { "Weapon Skills", true }
BananaLootlineDB.itemcache = {
  [1] = { e = "INVTYPE_2HWEAPON", r = 12, st = { AGI = 9 }, ic = 2, sc = 8,  n = "Zweihandschwert" },
  [2] = { e = "INVTYPE_2HWEAPON", r = 12, st = { AGI = 8 }, ic = 2, sc = 6,  n = "Stangenwaffe" },
  [3] = { e = "INVTYPE_WEAPON",   r = 12, st = { AGI = 7 }, ic = 2, sc = 0,  n = "Einhandaxt" },
  [4] = { e = "INVTYPE_2HWEAPON", r = 12, st = { AGI = 6 }, ic = 2, sc = 1,  n = "Zweihandaxt" },
  [5] = { e = "INVTYPE_WEAPON",   r = 12, st = { AGI = 5 }, ic = 2, sc = 13, n = "Faustwaffe" },
}
Cand.pool = { [1] = 12, [2] = 12, [3] = 12, [4] = 12, [5] = 12 }
local function ids(list) local t = {}; for i = 1, table.getn(list or {}) do t[list[i].id] = list[i] end; return t end

-- Zwergenjaeger 15: startet mit Schusswaffen und Einhandaexten
BLL.player = { class = "HUNTER", level = 15 }
setSkills({ W, { "Guns" }, { "Axes" }, { "Unarmed" } })
local main = ids(Cand:GetUpgrades("MainHandSlot", 10))
check(main[3] and not main[3].learnSkill and not main[3].locked, "Einhandaxt gelernt: frei")
check(main[1] and main[1].learnSkill and not main[1].locked and main[1].reqLevel == 12, "Zweihandschwert: lernen, sofort moeglich")
check(main[2] and main[2].learnSkill and main[2].locked and main[2].reqLevel == 20, "Stangenwaffe: lernen ab 20")
check(main[5] and main[5].learnSkill, "Faustwaffe fuer Jaeger lernbar")
local off = ids(Cand:GetUpgrades("SecondaryHandSlot", 10))
check(off[3] and off[3].dualWield and off[3].reqLevel == 20 and off[3].locked, "Schildhand ohne Beidhaendigkeit: ab 20")

-- Jaeger 22 mit gelernter Beidhaendigkeit
BLL.player = { class = "HUNTER", level = 22 }
setSkills({ W, { "Guns" }, { "Axes" }, { "Dual Wield" } })
off = ids(Cand:GetUpgrades("SecondaryHandSlot", 10))
check(off[3] and not off[3].dualWield and not off[3].locked, "Beidhaendigkeit gemeldet: frei")

-- Jaeger 22 ohne gelernte Beidhaendigkeit: frei, aber mit Hinweis
setSkills({ W, { "Guns" }, { "Axes" } })
off = ids(Cand:GetUpgrades("SecondaryHandSlot", 10))
check(off[3] and not off[3].locked and off[3].learnSkill and not off[3].dualWield, "Beidhaendigkeit lernbar: Hinweis statt Sperre")

-- Eingeklappte Ueberschrift: wird fuer den Scan auf- und danach wieder zugeklappt
BLL.player = { class = "HUNTER", level = 15 }
setSkills({ { "Class Skills", true }, { "Beast Mastery" }, W, { "Guns" }, { "Axes" } }, "Weapon Skills")
main = ids(Cand:GetUpgrades("MainHandSlot", 10))
check(main[3] and not main[3].learnSkill, "eingeklappt: Axt trotzdem erkannt")
check(expanded["Weapon Skills"] == false and expanded["Class Skills"] == true, "alter Zustand wiederhergestellt")

-- Schamane: Zweihandaxt nur mit Talent
BLL.player = { class = "SHAMAN", level = 25 }
setSkills({ W, { "Maces" }, { "Staves" }, { "Axes" } })
main = ids(Cand:GetUpgrades("MainHandSlot", 10))
check(main[4] == nil, "Schamane ohne Talent: keine Zweihandaxt")
check(main[5] == nil, "Schamane: keine Faustwaffe")
setSkills({ W, { "Maces" }, { "Staves" }, { "Two-Handed Axes" } })
main = ids(Cand:GetUpgrades("MainHandSlot", 10))
check(main[4] and not main[4].learnSkill, "Schamane mit Talent: Zweihandaxt frei")

-- Schurke: keine Axt
BLL.player = { class = "ROGUE", level = 20 }
setSkills({ W, { "Daggers" }, { "Dual Wield" } })
main = ids(Cand:GetUpgrades("MainHandSlot", 10))
check(main[3] == nil, "Schurke: keine Einhandaxt")

-- Unbekannte Sprache: keine Fertigkeit erkannt -> keine Sperre durch Fertigkeiten
BLL.player = { class = "HUNTER", level = 15 }
setSkills({ { "Waffenfertigkeiten?", true }, { "Unbekannt" } })
main = ids(Cand:GetUpgrades("MainHandSlot", 10))
check(Cand.skills == nil and main[1] and not main[1].learnSkill, "Rueckfall auf Klassentabelle")
print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
