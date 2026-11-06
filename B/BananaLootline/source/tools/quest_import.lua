--[[----------------------------------------------------------------------
  BananaLootline - tools/quest_import.lua

  Baut Data/QuestData.lua: zu jeder Quest, die im Import als Quelle
  eines Gegenstands steht, ihre ganze Vorquestreihe - Name, Stufen,
  Questgeber und Abgabe mit Ort und Koordinaten, Zieltext. Damit zeigt
  das Addon beim Klick auf eine Questbelohnung, wo die Reihe anfaengt,
  auch ohne pfQuest im Client.

  Aufruf (Lua 5.1, vom Addon-Stamm aus):
    lua5.1 tools/quest_import.lua <pfQuest> <pfQuest-turtle> <pfQuest-octo>

  Jedes Argument ist ein pfQuest-Ordner. Spaetere ueberschreiben
  fruehere, also das Serverpaket zuletzt - wie in pfQuest selbst. "_"
  loescht einen Eintrag.

  Quelle: pfQuest (github.com/shagu/pfQuest) und seine Serverpakete.
  Der OctoWoW-Export fuehrt keine Vorquests.
------------------------------------------------------------------------]]

local dirs = arg
if not dirs[1] then
  print("Aufruf: lua5.1 tools/quest_import.lua <pfQuest> [<pfQuest-turtle>] [<pfQuest-octo>]")
  os.exit(2)
end

pfDB = { quests = {}, units = {}, zones = {}, objects = {} }

-- Eine pfQuest-Datei laden und ihren Inhalt unter einem festen Schluessel
-- abholen, egal ob sie "data" oder "data-turtle" heisst.
local function load(path, kind, key)
  local f = io.open(path, "r")
  if not f then return nil end
  f:close()
  pfDB[kind] = {}
  dofile(path)
  for _, v in pairs(pfDB[kind]) do return v end
end

local function merge(dst, src)
  if not src then return end
  for k, v in pairs(src) do
    if v == "_" then dst[k] = nil else dst[k] = v end
  end
end

local quests, qloc, units, uloc, zloc = {}, {}, {}, {}, {}
for i = 1, table.getn(dirs) do
  local d = dirs[i] .. "/db/"
  local suf = (i == 1) and "" or "-turtle"
  merge(quests, load(d .. "quests" .. suf .. ".lua", "quests"))
  merge(qloc,   load(d .. "enUS/quests" .. suf .. ".lua", "quests"))
  merge(units,  load(d .. "units" .. suf .. ".lua", "units"))
  merge(uloc,   load(d .. "enUS/units" .. suf .. ".lua", "units"))
  merge(zloc,   load(d .. "enUS/zones" .. suf .. ".lua", "zones"))
end

dofile("Data/SourceData.lua")
dofile("Data/ZoneNames.lua")
dofile("Data/NpcData.lua")

-- Ausgangsmenge: alle Quests, die im Import Gegenstaende belohnen
local want, order = {}, {}
local function need(id)
  if want[id] then return end
  want[id] = true
  table.insert(order, id)
end
for _, s in pairs(BananaLootlineSourceData) do
  for i = 1, table.getn(s.q or {}) do need(s.q[i].q) end
end
local direct = table.getn(order)

-- Vorquests transitiv dazunehmen
local i = 1
while i <= table.getn(order) do
  local q = quests[order[i]]
  if type(q) == "table" and q.pre then
    for _, p in ipairs(q.pre) do need(p) end
  end
  i = i + 1
end

-- Ort und Koordinaten eines NPC: die Zone mit den meisten Punkten,
-- davon der erste Punkt.
local function place(uid)
  local u = units[uid]
  if type(u) ~= "table" or type(u.coords) ~= "table" then return nil end
  local tally, best = {}, nil
  for _, c in ipairs(u.coords) do
    local z = c[3]
    if z then
      tally[z] = (tally[z] or 0) + 1
      if not best or tally[z] > tally[best] then best = z end
    end
  end
  if not best then return nil end
  for _, c in ipairs(u.coords) do
    if c[3] == best then return best, c[1], c[2] end
  end
end

local outQ, outU, outZ = {}, {}, {}
local usedU = {}
local function first(t) return type(t) == "table" and t[1] or nil end

local found, withPre = 0, 0
for _, id in ipairs(order) do
  local q = quests[id]
  local l = qloc[id]
  if type(q) == "table" then
    found = found + 1
    local e = { l = q.lvl, m = q.min, r = q.race, c = q.class }
    if type(l) == "table" then
      e.t = l.T
      if l.O and l.O ~= "" then
        local o = string.gsub(l.O, "%$[bB]", " ")
        if string.len(o) > 180 then o = string.sub(o, 1, 177) .. "..." end
        e.o = o
      end
    end
    if q.pre then e.p = q.pre; withPre = withPre + 1 end
    e.s = q.start and first(q.start.U)
    e.so = q.start and first(q.start.O)
    e.e = q["end"] and first(q["end"].U)
    if e.s then usedU[e.s] = true end
    if e.e then usedU[e.e] = true end
    outQ[id] = e
  end
end

for uid in pairs(usedU) do
  local z, x, y = place(uid)
  local n = type(uloc[uid]) == "string" and uloc[uid] or nil
  outU[uid] = { n = n, z = z, x = x, y = y }
  if z and not BananaLootlineZoneNames[z] and type(zloc[z]) == "string" then
    outZ[z] = zloc[z]
  end
end

------------------------------------------------------------------
-- Schreiben
------------------------------------------------------------------

local function str(s)
  s = string.gsub(s, "\\", "\\\\")
  s = string.gsub(s, "\"", "\\\"")
  s = string.gsub(s, "\n", " ")
  return "\"" .. s .. "\""
end

local function sorted(t)
  local k = {}
  for id in pairs(t) do table.insert(k, id) end
  table.sort(k)
  return k
end

local fh = io.open("Data/QuestData.lua", "w")
fh:write("-- Automatisch erzeugt von tools/quest_import.lua\n")
fh:write("-- Quelle: pfQuest und seine Serverpakete\n")
fh:write(string.format("-- Quests: %d (%d belohnen Gegenstaende, Rest Vorquests)\n", found, direct))
fh:write("-- q: t Titel, l Questlevel, m Mindeststufe, r Rassenmaske, c Klassenmaske,\n")
fh:write("--    p Vorquests, s Geber-NPC, so Geber-Objekt, e Abgabe-NPC, o Ziel\n")
fh:write("-- u: n Name, z Zone, x/y Koordinaten des Questgebers\n")
fh:write("-- REINE DATEN. Nicht von Hand bearbeiten.\n\n")
fh:write("BananaLootlineQuestData = {\nq = {\n")
for _, id in ipairs(sorted(outQ)) do
  local e = outQ[id]
  local parts = {}
  if e.t then table.insert(parts, "t=" .. str(e.t)) end
  if e.l then table.insert(parts, "l=" .. e.l) end
  if e.m then table.insert(parts, "m=" .. e.m) end
  if e.r then table.insert(parts, "r=" .. e.r) end
  if e.c then table.insert(parts, "c=" .. e.c) end
  if e.p then table.insert(parts, "p={" .. table.concat(e.p, ",") .. "}") end
  if e.s then table.insert(parts, "s=" .. e.s) end
  if e.so then table.insert(parts, "so=" .. e.so) end
  if e.e then table.insert(parts, "e=" .. e.e) end
  if e.o then table.insert(parts, "o=" .. str(e.o)) end
  fh:write("[" .. id .. "]={" .. table.concat(parts, ",") .. "},\n")
end
fh:write("},\nu = {\n")
for _, id in ipairs(sorted(outU)) do
  local e = outU[id]
  local parts = {}
  if e.n then table.insert(parts, "n=" .. str(e.n)) end
  if e.z then table.insert(parts, "z=" .. e.z) end
  if e.x then table.insert(parts, string.format("x=%.1f,y=%.1f", e.x, e.y)) end
  fh:write("[" .. id .. "]={" .. table.concat(parts, ",") .. "},\n")
end
fh:write("},\nz = {\n")
for _, id in ipairs(sorted(outZ)) do
  fh:write("[" .. id .. "]=" .. str(outZ[id]) .. ",\n")
end
fh:write("},\n}\n")
fh:close()

print(string.format("Quests: %d gesucht, %d gefunden, %d mit Vorquests; NPCs %d",
  table.getn(order), found, withPre, table.getn(sorted(outU))))
