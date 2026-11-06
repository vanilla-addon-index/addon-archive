--[[----------------------------------------------------------------------
  BananaLootline - Sources.lua

  Woher die Fundorte kommen.

  ZWEI QUELLEN, KLARE AUFTEILUNG:

    Data/SourceData.lua  - der Import aus dem OctoWoW-Export dieses
                           Servers. Liefert Gegner, Mobstufe, Elite,
                           Fraktion, Dropchance, Haendlerpreis und
                           Questbelohnung. Das sind die Zahlen, die im
                           Spiel gelten.
    pfQuest              - liefert nur noch die Karte: wo ein Gegner
                           steht. Die Geografie dort ist richtig.

  Warum die Aufteilung. pfQuests Loot-Angaben stammen aus dem
  Vanilla-Datenstand und stimmen fuer OctoWoW nicht. Nachgewiesen an
  "Feet of the Lynx" (Stufe 19): pfQuest nennt als beste Quelle einen
  Gegner jenseits von Stufe 60 mit 1,92 Prozent. Der Server kennt fuer
  dasselbe Teil nur Gegner zwischen Stufe 23 und 24, keinen ueber
  0,0045 Prozent. Questbelohnungen fehlen in pfQuest vollstaendig - das
  Feld ["Q"] kommt in keiner items-Datei vor, der Zweig lief immer ins
  Leere. Der Export kennt 2664 Gegenstaende aus Quests.

  Die Zonen-ID des Exports ist NICHT benutzbar: sie mischt
  AreaTable-IDs (Freiland) mit Map-IDs (Instanzen), und beide
  ueberschneiden sich. 209 ist als Map-ID Zul'Farrak, als AreaTable
  Shadowfang Keep. Deshalb bestimmt der Importer die Zone aus pfQuests
  Koordinaten, dessen Nummernkreis in sich geschlossen ist, und legt sie
  fertig in SourceData.lua ab. Zur Laufzeit wird nichts geraten.

  pfQuest-Datenformat, soweit noch gelesen (verifiziert gegen roby-brok/pfQuest-octo):

    pfDB["items"]["data"][itemID] = {
      ["U"] = { [unitID]   = dropChance },   -- Unit (Mob/Boss)
      ["O"] = { [objectID] = dropChance },   -- Objekt (Truhe etc.)
      ["V"] = { [vendorID] = 0 },            -- Haendler
      ["Q"] = { [questID]  = 1 },            -- Questbelohnung
      ["C"] = { ... },                       -- Container
      ["L"] = { [refID]    = chance },       -- Referenz-Loottabelle
    }
    pfDB["items"]["loc"][itemID]  = "Itemname"
    pfDB["units"]["data"][unitID] = { ["coords"] = { {x, y, zoneID, respawn}, ... }, ["lvl"] = "60" }
    pfDB["units"]["loc"][unitID]  = "Unitname"
    pfDB["zones"]["loc"][zoneID]  = "Zonenname"
    pfDB["refloot"]["data"][refID]= { ["U"] = { [unitID] = chance }, ... }

  Die "-turtle"-Tabellen aus dem Octo-Pack werden von pfQuests patchtable.lua
  vor unserem Start in ["data"] / ["loc"] gemerged. Wir lesen deshalb immer
  die gemergten Tabellen und nie die "-turtle"-Varianten direkt.
------------------------------------------------------------------------]]

BananaLootline = BananaLootline or {}
local BLL = BananaLootline
BLL.Sources = {}
local Sources = BLL.Sources

Sources.available = false

------------------------------------------------------------------
-- Init / Erkennung
------------------------------------------------------------------

function Sources:Init()
  -- Der Import ist die erste Quelle und braucht pfQuest nicht.
  self.imported  = BananaLootlineSourceData
  self.npcNames  = BananaLootlineNpcNames
  self.zoneNames = BananaLootlineZoneNames

  if not pfDB then
    self.items = nil
    self.available = (self.imported ~= nil)
    BLL:Debug("Sources init: pfQuest fehlt, Import="
      .. (self.imported and "ok" or "fehlt"))
    return self.available
  end

  self.items   = pfDB["items"]   and pfDB["items"]["data"]
  self.itemloc = pfDB["items"]   and (pfDB["items"]["loc"] or pfDB["items"]["enUS"])
  self.units   = pfDB["units"]   and pfDB["units"]["data"]
  self.unitloc = pfDB["units"]   and (pfDB["units"]["loc"] or pfDB["units"]["enUS"])
  self.objects = pfDB["objects"] and pfDB["objects"]["data"]
  self.objloc  = pfDB["objects"] and (pfDB["objects"]["loc"] or pfDB["objects"]["enUS"])
  self.quests  = pfDB["quests"]  and pfDB["quests"]["data"]
  self.questloc= pfDB["quests"]  and (pfDB["quests"]["loc"] or pfDB["quests"]["enUS"])
  self.zoneloc = pfDB["zones"]   and (pfDB["zones"]["loc"] or pfDB["zones"]["enUS"])
  self.refloot = pfDB["refloot"] and pfDB["refloot"]["data"]

  self.available = (self.items ~= nil) or (self.imported ~= nil)

  -- Octo-Pack erkennen: der Pack setzt eine eigene SavedVariable
  self.octoPack = (pfQuest_turtlecount ~= nil)

  BLL:Debug("Sources init: items=" .. (self.items and "ok" or "fehlt")
    .. " units=" .. (self.units and "ok" or "fehlt")
    .. " import=" .. (self.imported and "ok" or "fehlt")
    .. " octopack=" .. (self.octoPack and "ja" or "nein"))

  return self.available
end

------------------------------------------------------------------
-- Namensaufloesung
------------------------------------------------------------------

-- pfQuest zuerst, weil es den Namen in der Clientsprache kennt. Der
-- Import ist immer englisch und deckt die 2,5 Prozent ab, die pfQuest
-- nicht kennt.
function Sources:UnitName(id)
  local v = self.unitloc and self.unitloc[id]
  if type(v) == "table" then v = v[1] end
  if v then return v end
  if self.npcNames and self.npcNames[id] then return self.npcNames[id] end
  return "Unit #" .. id
end

function Sources:ObjectName(id)
  if not self.objloc then return "Objekt #" .. id end
  local v = self.objloc[id]
  if type(v) == "table" then return v[1] or ("Objekt #" .. id) end
  return v or ("Objekt #" .. id)
end

function Sources:QuestName(id)
  if not self.questloc then return "Quest #" .. id end
  local v = self.questloc[id]
  if type(v) == "table" then return v["T"] or ("Quest #" .. id) end
  return v or ("Quest #" .. id)
end

function Sources:ZoneName(id)
  if not id then return nil end

  -- Eigene Benennung hat Vorrang. Fuer Orte, die weder pfQuest noch der
  -- Import kennt, laesst sich der Name mit "/bll zone <id> <Name>"
  -- nachtragen - das ueberlebt jedes Datenupdate.
  local own = BananaLootlineDB and BananaLootlineDB.zoneNames
  if own and own[id] then return own[id] end

  local name = self.zoneloc and self.zoneloc[id]
  if name == "_" or name == "???" then name = nil end
  if not name and self.zoneNames then name = self.zoneNames[id] end
  if name == "_" or name == "???" then name = nil end

  -- Ohne Namen trotzdem eine Gruppe bilden. Die Alternative waere, die
  -- Gegenstaende aus dem Wegplan fallen zu lassen - bei Zone 5557 sind
  -- das 37 Stueck mit Itemlevel 92 bis 96. Die Nummer im Namen sagt,
  -- was man benennen muss.
  if not name then
    return (BLL.locale == "deDE") and ("Zone " .. id) or ("Zone " .. id)
  end
  return name
end

function Sources:ItemName(id)
  if not self.itemloc then return nil end
  local v = self.itemloc[id]
  if type(v) == "table" then return v[1] end
  return v
end

------------------------------------------------------------------
-- Zone einer Unit bestimmen (haeufigste Zone in den Koordinaten)
------------------------------------------------------------------

function Sources:UnitZone(unitID)
  if not self.units then return nil end
  local unit = self.units[unitID]
  if not unit or type(unit) ~= "table" or not unit["coords"] then return nil end

  local counts, best, bestZone = {}, 0, nil
  local coords = unit["coords"]
  for i = 1, table.getn(coords) do
    local zone = coords[i][3]
    if zone then
      counts[zone] = (counts[zone] or 0) + 1
      if counts[zone] > best then
        best, bestZone = counts[zone], zone
      end
    end
  end
  return bestZone and self:ZoneName(bestZone) or nil
end

function Sources:UnitLevel(unitID)
  if not self.units then return nil end
  local unit = self.units[unitID]
  if type(unit) ~= "table" then return nil end
  return unit["lvl"]
end

------------------------------------------------------------------
-- Hauptfunktion: alle Quellen eines Items
------------------------------------------------------------------

------------------------------------------------------------------
-- Unerreichbare Quellen
--
-- Der Serverdatenbestand enthaelt Entwicklereintraege: Mobs, die im
-- Spiel nicht vorkommen, meist mit "[UNUSED]" im Namen und Dropchance
-- null. pfQuest gibt sie treu wieder - fuer einen Ausruestungsplaner
-- sind sie aber wertlos: ein Item, das nur dort haengt, kann man nicht
-- bekommen.
--
-- Vorsicht bei der Chance: bei Haendlern (V) und Quests (Q) bedeutet
-- eine fehlende Chance NICHT "nie", sondern "nicht zufaellig". Nur bei
-- echten Drops (U, O, C) ist null tatsaechlich unerreichbar.
------------------------------------------------------------------

local UNUSED_MARKERS = {
  "%[UNUSED%]", "%[DEPRECATED%]", "%[OLD%]", "%[PH%]", "%[TEST%]",
  "%[NYI%]", "^UNUSED", "Test Mob", "%(OLD%)", "%(unused%)",
}

------------------------------------------------------------------
-- Fraktionspruefung fuer Quests
--
-- pfQuest fuehrt an jeder Quest eine Rassenmaske. Die beobachteten
-- Werte 589 und 434 sind exakt die Bitsummen der beiden Fraktionen:
--   589 = Mensch 1 + Zwerg 4 + Nachtelf 8 + Gnom 64 + Hochelf 512
--   434 = Ork 2 + Untoter 16 + Tauren 32 + Troll 128 + Goblin 256
--
-- Ohne diese Pruefung landen Questbelohnungen der Gegenfraktion in der
-- Lootline - unerreichbar, aber unauffaellig, weil die Quest existiert.
------------------------------------------------------------------

local RACE_BITS = { 1, 2, 4, 8, 16, 32, 64, 128, 256, 512 }

local FACTION_MASK = {
  Alliance = 589,
  Horde    = 434,
}

local function maskHas(mask, bit)
  return math.mod(math.floor(mask / bit), 2) == 1
end

function Sources:PlayerRaceMask()
  if self.raceMask then return self.raceMask end
  local faction = UnitFactionGroup and UnitFactionGroup("player")
  self.raceMask = FACTION_MASK[faction or ""] or 0
  return self.raceMask
end

-- Teilen sich Questmaske und Spielerfraktion mindestens ein Volk?
function Sources:RaceAllows(questMask)
  if not questMask or questMask == 0 then return true end
  local mine = self:PlayerRaceMask()
  if mine == 0 then return true end   -- Fraktion unbekannt: durchlassen

  for i = 1, table.getn(RACE_BITS) do
    local b = RACE_BITS[i]
    if maskHas(questMask, b) and maskHas(mine, b) then return true end
  end
  return false
end

-- Wie weit ueber der eigenen Stufe eine Quelle noch als erreichbar gilt.
--
-- Grosszuegig bemessen, damit Instanzen drinbleiben: ein Stufe-15-
-- Charakter geht in die Todesminen, wo Gegner bis Stufe 21 stehen, und
-- das mit einer Gruppe auch frueher als empfohlen. Mit 10 Stufen
-- Zuschlag bleibt das drin, ein Gegner jenseits von 60 aber draussen.
-- Die Vorausplanung kommt oben drauf, weil sie ohnehin Ziele fuer
-- spaeter zeigen soll.
local REACH_MARGIN = 10

-- Klassenmaske einer Quest aus Data/QuestData.lua (pfQuest "class").
function Sources:QuestClassMask(questID)
  local qd = BananaLootlineQuestData
  local q = qd and qd.q and questID and qd.q[questID]
  return q and q.c or nil
end

-- Liegen alle Quellen eines Teils in Inhalten, die auf dem Server
-- noch nicht offen sind? Dann gehoert es in keine Liste.
--
-- Die Phasensperre entfernte bisher nur die Quellen. Das Teil selbst
-- blieb in "Pro Item" stehen, mit "Keine Quellendaten": ein Tester auf
-- Stufe 60 bekam fast nur Teile aus Naxxramas, AQ40, BWL und dem Rock
-- of Desolation vorgeschlagen - alle gesperrt.
--
-- Nur wenn jede Quelle einen Ort hat und jeder Ort gesperrt ist. Eine
-- Quelle ohne Ort oder eine Herstellung laesst das Teil drin; dann
-- weiss das Addon zu wenig, um es wegzulassen.
function Sources:OnlyLockedSources(itemID)
  if not BLL.Phases or not self.imported or not itemID then return false end
  local e = self.imported[itemID]
  if type(e) ~= "table" then return false end
  if e.c then return false end
  local any = false
  for _, key in ipairs({ "d", "v", "q", "o" }) do
    local rows = e[key]
    for i = 1, table.getn(rows or {}) do
      local z = rows[i].z
      if not z or BLL.Phases:IsOpen(z) then return false end
      any = true
    end
  end
  return any
end

function Sources:IsReachable(entry)
  -- Quest der Gegenfraktion: existiert, aber nicht fuer diesen Charakter
  if entry.stype == "Q" and not self:RaceAllows(entry.questRace) then
    return false
  end

  -- Klassenquest einer anderen Klasse. Gemeldet von einem Tester:
  -- Belohnungen aus Klassenquests standen bei allen Klassen in der
  -- Liste. Der Import kennt die Klasse einer Quest nicht, pfQuest schon.
  if entry.stype == "Q" and entry.questClass and BLL.ItemDB and BLL.player
     and not BLL.ItemDB:MaskAllows(entry.questClass, BLL.player.class) then
    return false
  end

  local name = entry.name or ""
  for i = 1, table.getn(UNUSED_MARKERS) do
    if string.find(name, UNUSED_MARKERS[i]) then return false end
  end

  -- Inhalt, der auf dem Server noch nicht offen ist.
  --
  -- Das war die Ursache des gemeldeten Unsinns: ein Stufe-57-Paladin
  -- bekam Naxxramas, Ahn'Qiraj und den Turm von Karazhan als besten
  -- Wegplan - Instanzen, die es auf OctoWoW noch nicht gibt. Die Pruefung
  -- an der Gegnerstufe konnte das nicht sehen, weil ein Stufe-63-Boss in
  -- Naxxramas genauso aussieht wie ein Stufe-63-Gegner in Silithus.
  -- Welche Zone zu welcher Phase gehoert, steht in Phases.lua.
  if entry.zoneID and BLL.Phases and not BLL.Phases:IsOpen(entry.zoneID) then
    return false
  end

  if entry.stype == "U" or entry.stype == "O" or entry.stype == "C" then
    if not entry.chance or entry.chance <= 0 then return false end
  end

  -- Mob weit ueber der eigenen Stufe: rechnerisch eine Quelle, praktisch
  -- keine.
  --
  -- "Feet of the Lynx" ist ab Stufe 19 tragbar. pfQuest fuehrt als
  -- beste Quelle den "Eroded Anubisath Warbringer" mit 1,92 % - einen
  -- Gegner jenseits von Stufe 60. Fuer einen Stufe-15-Jaeger stand
  -- damit ein Ziel ganz oben im Wegplan, an das er nicht herankommt.
  -- 644 der 8364 Quellenpaare im Datenbestand sehen so aus.
  if entry.level and BLL.player and BLL.player.level then
    local lvl = tonumber(entry.level)
    if lvl then
      local ahead = (BLL.Candidates and BLL.Candidates.PlanAhead
                     and BLL.Candidates:PlanAhead()) or 0
      if lvl > BLL.player.level + ahead + REACH_MARGIN then
        return false
      end
    end
  end

  -- Quests tragen ihre Stufe in questLevel, nicht in level. Der Filter
  -- oben lief deshalb an ihnen vorbei: einem Stufe-15-Jaeger standen
  -- "Windreaper" aus einer Stufe-57-Quest und "Archlight Talisman" aus
  -- einer Stufe-50-Quest ganz oben im Wegplan, beide in den Oestlichen
  -- Pestlaendern. 2032 der 2883 Questquellen im Datenbestand liegen
  -- ueber Stufe 21.
  --
  -- Hier gilt kein Zuschlag wie bei Gegnern. Einen Gegner ueber der
  -- eigenen Stufe kann man in einer Gruppe erlegen; eine Quest, deren
  -- Mindeststufe man nicht hat, kann man nicht einmal annehmen. Die
  -- Angabe ist die geforderte Stufe des Servers, bei 2905 von 2906
  -- Questbelohnungen vorhanden.
  if entry.questLevel and BLL.player and BLL.player.level then
    local lvl = tonumber(entry.questLevel)
    if lvl then
      local ahead = (BLL.Candidates and BLL.Candidates.PlanAhead
                     and BLL.Candidates:PlanAhead()) or 0
      if lvl > BLL.player.level + ahead then
        return false
      end
    end
  end

  return true
end

local TYPE_LABEL = {
  ["U"] = "DROPS_FROM",
  ["O"] = "OBJECT",
  ["V"] = "VENDOR",
  ["Q"] = "QUEST",
  ["C"] = "OBJECT",
}

------------------------------------------------------------------
-- Quellen aus dem Import
--
-- SourceData.lua haelt je Gegenstand bis zu drei Quellen pro Art, nach
-- Chance sortiert. Mehr braucht niemand: wer ein Teil sucht, will die
-- drei besten Gegner, nicht alle 473.
--
--   d Gegner   { n = NPC, l = Stufe, z = Zone, p = Chance,
--                e = Elitestufe, f = Fraktion }
--   v Haendler { n = NPC, z = Zone, c = Preis in Kupfer, f, t = Marke }
--   q Quest    { q = Quest-ID, t = Titel, l = Mindeststufe, f,
--                x = Anzahl Auswahlbelohnungen }
--   o Objekt   { n = ID, t = Name, p = Chance }
--   c Beruf    { s = Zauber-ID, t = Name }
--
-- f ist 1 fuer Allianz, 2 fuer Horde, fehlt wenn beide herankommen.
------------------------------------------------------------------

local FACTION_NAME = { [1] = "Alliance", [2] = "Horde" }

function Sources:FactionAllows(side)
  if not side then return true end
  local mine = UnitFactionGroup and UnitFactionGroup("player")
  if not mine then return true end
  return FACTION_NAME[side] == mine
end

function Sources:ImportedSources(itemID)
  if not self.imported or not itemID then return nil end
  local entry = self.imported[itemID]
  if type(entry) ~= "table" then return nil end

  local L = BLL.L
  local minChance = (BananaLootlineDB and BananaLootlineDB.minDropChance) or 0
  local out = {}

  local function add(row)
    if self:FactionAllows(row.faction) then table.insert(out, row) end
  end

  for i = 1, table.getn(entry.d or {}) do
    local r = entry.d[i]
    if (r.p or 0) >= minChance then
      add({
        stype     = "U",
        typeLabel = L["DROPS_FROM"],
        id        = r.n,
        name      = self:UnitName(r.n),
        zone      = r.z and self:ZoneName(r.z) or nil,
        zoneID    = r.z,
        level     = r.l,
        chance    = r.p,
        elite     = r.e,
        faction   = r.f,
        imported  = true,
      })
    end
  end

  for i = 1, table.getn(entry.v or {}) do
    local r = entry.v[i]
    add({
      stype     = "V",
      typeLabel = L["VENDOR"],
      id        = r.n,
      name      = self:UnitName(r.n),
      zone      = r.z and self:ZoneName(r.z) or nil,
      zoneID    = r.z,
      cost      = r.c,
      tag       = r.t,
      faction   = r.f,
      sure      = true,
      imported  = true,
    })
  end

  for i = 1, table.getn(entry.q or {}) do
    local r = entry.q[i]
    add({
      stype      = "Q",
      typeLabel  = L["QUEST"],
      id         = r.q,
      name       = r.t,
      questLevel = r.l,
      choices    = r.x,
      faction    = r.f,
      -- Der Ort einer Questbelohnung ist der Questgeber. Ohne ihn
      -- stuende sie ohne Ort in der Liste und der Wegplan sagte nichts.
      zone       = r.z and self:ZoneName(r.z) or nil,
      zoneID     = r.z,
      giver      = r.g and self:UnitName(r.g) or nil,
      questClass = self:QuestClassMask(r.q),
      sure       = true,
      imported   = true,
    })
  end

  for i = 1, table.getn(entry.o or {}) do
    local r = entry.o[i]
    if (r.p or 0) >= minChance then
      add({
        stype     = "O",
        typeLabel = L["OBJECT"],
        id        = r.n,
        name      = r.t,
        chance    = r.p,
        zone      = r.z and self:ZoneName(r.z) or nil,
        zoneID    = r.z,
        imported  = true,
      })
    end
  end

  if table.getn(out) == 0 then return nil end
  return out
end

function Sources:GetItemSources(itemID, depth)
  if not self.available or not itemID then return nil end
  depth = depth or 0
  if depth > 1 then return nil end   -- Rekursion ueber refloot begrenzen

  local L = BLL.L
  local minChance = (BananaLootlineDB and BananaLootlineDB.minDropChance) or 0

  -- Der Import gewinnt, wo er etwas weiss. Seine Zahlen kommen von
  -- diesem Server; pfQuests Zahlen kommen aus dem Vanilla-Datenstand.
  -- Nur wenn der Import den Gegenstand nicht kennt, wird pfQuest
  -- gelesen - dann ist eine ungenaue Angabe besser als keine.
  local imported = self:ImportedSources(itemID)
  if imported then
    if not (BananaLootlineDB and BananaLootlineDB.showUnreachable) then
      local keep = {}
      for i = 1, table.getn(imported) do
        if self:IsReachable(imported[i]) then
          table.insert(keep, imported[i])
        end
      end
      imported = keep
    end
    table.sort(imported, function(a, b)
      local ca = a.sure and 100 or (a.chance or 0)
      local cb = b.sure and 100 or (b.chance or 0)
      return ca > cb
    end)
    -- Kennt der Import den Gegenstand, ist das die Antwort - auch wenn
    -- der Filter alles verworfen hat. Kein Rueckfall auf pfQuest:
    -- "keine erreichbare Quelle" ist richtig, pfQuests Endgame-Gegner
    -- waere falsch.
    if table.getn(imported) == 0 then return nil end
    return imported
  end

  local entry = self.items and self.items[itemID]
  if not entry or type(entry) ~= "table" then return nil end

  local out = {}

  -- Direkte Quellen
  for stype, label in pairs(TYPE_LABEL) do
    local group = entry[stype]
    if group then
      for id, chance in pairs(group) do
        local numChance = tonumber(chance) or 0
        if numChance >= minChance then
          local name, zone, lvl, questLevel, questRace, giverName
          if stype == "U" or stype == "V" then
            name = self:UnitName(id)
            zone = self:UnitZone(id)
            lvl  = self:UnitLevel(id)
          elseif stype == "O" or stype == "C" then
            name = self:ObjectName(id)
          elseif stype == "Q" then
            name = self:QuestName(id)
            local q = self.quests and self.quests[id]
            if type(q) == "table" then
              questLevel = q["lvl"] or q["min"]
              questRace = q["race"]
              -- Ort der Quest ueber ihren Geber bestimmen. Ohne das
              -- landen alle Questbelohnungen in der Sammelgruppe
              -- "Ohne Ortsangabe" und man sieht nicht, wohin man muss.
              if q["start"] and q["start"]["U"] then
                local giver = q["start"]["U"][1]
                if giver then
                  zone = self:UnitZone(giver)
                  giverName = self:UnitName(giver)
                end
              end
            end
          end

          table.insert(out, {
            stype      = stype,
            typeLabel  = L[label],
            id         = id,
            name       = name,
            zone       = zone,
            level      = lvl,
            questLevel = questLevel,
            questRace  = questRace,
            giver      = giverName,
            -- Quest und Haendler sind sichere Quellen. pfQuest fuehrt dort
            -- 1 bzw. 0 - das ist kein Prozentwert. Als 1 % gelesen, verlor
            -- jede Questbelohnung gegen einen Mob-Drop ab 1,1 %.
            chance     = (stype ~= "Q" and stype ~= "V" and numChance > 0) and numChance or nil,
            sure       = (stype == "Q" or stype == "V") or nil,
          })
        end
      end
    end
  end

  -- Referenz-Loottabellen aufloesen: das Item haengt an einer geteilten
  -- Tabelle, die wiederum an Units haengt.
  -- Das Feld heisst in allen geprueften Datenpaketen "R", nicht "L":
  -- pfQuest-octo, pfQuest-turtle und das Vanilla-Paket fuehren
  -- ausnahmslos ["R"], ein ["L"] kommt in keiner items-Datei vor. Der
  -- Zweig lief damit immer ins Leere. Allein im OctoWoW-Datenstand
  -- haengen 706 Gegenstaende an einer Referenztabelle, 247 davon haben
  -- gar keine andere Quelle und standen deshalb ohne Fundort da.
  -- Beide Schreibweisen werden gelesen, falls ein Paket doch abweicht.
  local refs = entry["R"] or entry["L"]
  if refs and self.refloot then
    for refID, refChance in pairs(refs) do
      local ref = self.refloot[refID]
      if type(ref) == "table" and ref["U"] then
        for unitID, uChance in pairs(ref["U"]) do
          local combined = (tonumber(refChance) or 100) * (tonumber(uChance) or 100) / 100
          if combined >= minChance then
            table.insert(out, {
              stype     = "U",
              typeLabel = L["DROPS_FROM"],
              id        = unitID,
              name      = self:UnitName(unitID),
              zone      = self:UnitZone(unitID),
              level     = self:UnitLevel(unitID),
              chance    = combined,
              viaRef    = refID,
            })
          end
        end
      end
    end
  end

  -- Unerreichbares aussortieren, bevor sortiert wird. Abschaltbar,
  -- falls jemand den Rohbestand sehen will.
  if not (BananaLootlineDB and BananaLootlineDB.showUnreachable) then
    local keep = {}
    for i = 1, table.getn(out) do
      if self:IsReachable(out[i]) then table.insert(keep, out[i]) end
    end
    out = keep
  end

  -- Nach Dropchance absteigend sortieren, sichere Quellen zuerst
  table.sort(out, function(a, b)
    local ca = a.sure and 100 or (a.chance or 0)
    local cb = b.sure and 100 or (b.chance or 0)
    return ca > cb
  end)

  -- Gleichnamige Quellen zusammenfassen. "Kolkar's Booty" existiert
  -- dreimal mit verschiedenen Objekt-IDs - dreimal dieselbe Zeile im
  -- Tooltip hilft niemandem. Die hoechste Chance gewinnt, die Anzahl
  -- wird vermerkt.
  local merged, byKey = {}, {}
  for i = 1, table.getn(out) do
    local e = out[i]
    local key = (e.name or "?") .. "|" .. (e.zone or "")
    local prev = byKey[key]
    if prev then
      prev.count = (prev.count or 1) + 1
      if (e.chance or 0) > (prev.chance or 0) then prev.chance = e.chance end
    else
      byKey[key] = e
      table.insert(merged, e)
    end
  end

  return merged
end

------------------------------------------------------------------
-- Umkehrung: welche Items droppt diese Unit?
-- (Grundlage fuer spaetere "Was kann ich in Dungeon X holen"-Ansicht.
--  Achtung: linearer Scan ueber die gesamte Itemtabelle, deshalb nur
--  auf Anfrage aufrufen und das Ergebnis cachen.)
------------------------------------------------------------------

local dropCache = {}

function Sources:GetUnitDrops(unitID)
  if not self.available or not self.items then return nil end
  if dropCache[unitID] then return dropCache[unitID] end

  local out = {}
  for itemID, entry in pairs(self.items) do
    if type(entry) == "table" and entry["U"] and entry["U"][unitID] then
      table.insert(out, {
        id     = itemID,
        name   = self:ItemName(itemID),
        chance = entry["U"][unitID],
      })
    end
  end

  table.sort(out, function(a, b) return (a.chance or 0) > (b.chance or 0) end)
  dropCache[unitID] = out
  return out
end

------------------------------------------------------------------
-- Tooltip-Hook: Quellen an jeden Item-Tooltip anhaengen
------------------------------------------------------------------

-- Der 1.12-Client kennt KEIN GameTooltip:GetItem() - das kam erst in
-- spaeteren Versionen dazu. Der Hook darf den Link also nicht
-- zurueckfragen, sondern muss ihn sich beim Setzen merken.
--
-- Genau daran ist der alte Hook gescheitert: beim Ueberfahren von Items
-- lief jedes Mal "attempt to call method GetItem (a nil value)" in den
-- Chat. Dass es auf einem Charakter zu funktionieren schien, lag nur
-- daran, dass dort ein anderer Pfad griff.

local lastTooltipItem = nil
local pendingLink = nil     -- vom zuletzt gesetzten Tooltip

------------------------------------------------------------------
-- Zugangsbedingung aus dem ECHTEN Tooltip mitlesen
--
-- Der nachgebaute Scan-Tooltip liefert sie nicht. Bei "Outrider's Bow"
-- kamen dort sechs Zeilen an, im Spiel hat er sieben: die Zeile
-- "Warsong Gulch - Revered" fehlte in jeder Leseart - versteckt,
-- sichtbar, an WorldFrame und an UIParent gehaengt.
--
-- Auch der Datenbankauszug fuehrt das Feld nicht. Der Tooltip im Spiel
-- ist damit die einzige Stelle, an der diese Auskunft ueberhaupt steht.
-- Also wird sie hier abgegriffen, sobald der Spieler ueber den
-- Gegenstand faehrt - in der Vorschlagsliste also beim Hinsehen.
--
-- Der Befund landet im gespeicherten Cache und gilt ab dann dauerhaft,
-- auch wenn der Client den Tooltip laengst wieder vergessen hat.
------------------------------------------------------------------

local function CaptureRestriction(tooltip, itemID)
  if not itemID or not BananaLootlineDB then return end
  local cache = BananaLootlineDB.itemcache
  if not cache then return end

  local entry = cache[itemID]
  -- Unbekannt oder laengst geklaert: nichts zu tun.
  if not entry or entry.lock ~= nil then return end

  local name = tooltip.GetName and tooltip:GetName()
  local n = tooltip.NumLines and tooltip:NumLines() or 0
  if not name or n < 2 then return end

  -- Steht ueberhaupt noch derselbe Gegenstand im Tooltip? Die Pruefung
  -- laeuft verzoegert, in der Zwischenzeit kann der Zeiger weiter sein.
  -- Ohne diesen Abgleich bekaeme der falsche Gegenstand die Sperre.
  if entry.n then
    local first = getglobal(name .. "TextLeft1")
    local title = first and first:GetText()
    if title and title ~= "" and title ~= entry.n then return end
  end

  -- Zeile 1 ist der Itemname, eine Bedingung steht direkt darunter.
  -- Beim eigenen Zusatzblock abbrechen, damit wir nicht unsere eigenen
  -- Zeilen auswerten.
  for i = 2, n do
    local fs = getglobal(name .. "TextLeft" .. i)
    local txt = fs and fs:GetText()
    if txt == "|cffffcc33Banana|cffffffffLootline|r" then break end
    if BLL.Scanner:IsRestrictionLine(txt) then
      entry.lock = txt
      BLL:Debug("Zugangsbedingung fuer " .. itemID .. ": " .. txt)
      return
    end
  end
end

------------------------------------------------------------------
-- Verzoegerter Abgriff
--
-- Die Bedingungszeile kommt von einem fremden Addon, nicht vom Client.
-- Welches zuerst an den Tooltip schreibt, entscheidet die
-- Ladereihenfolge - darauf koennen wir uns nicht verlassen. Deshalb
-- wird die Itemnummer nur vorgemerkt und einen Frame spaeter gelesen,
-- wenn alle anderen Addons ihre Zeilen angehaengt haben.
------------------------------------------------------------------

local captureQueue = nil
local captureFrame = CreateFrame("Frame", "BananaLootlineTooltipWatcher")
captureFrame:SetScript("OnUpdate", function()
  if not captureQueue then return end
  local id = captureQueue
  captureQueue = nil
  if GameTooltip and GameTooltip.IsShown and GameTooltip:IsShown() then
    CaptureRestriction(GameTooltip, id)
  end
end)

local function QueueCapture(itemID)
  captureQueue = itemID
end

local function AppendSources(tooltip, knownLink)
  if not tooltip or not tooltip.AddLine then return end

  local link = knownLink or pendingLink

  -- Falls der Client die Funktion doch mitbringt, nutzen wir sie -
  -- aber nur, wenn sie wirklich existiert.
  if not link and type(tooltip.GetItem) == "function" then
    local _, l = tooltip:GetItem()
    link = l
  end
  if not link then return end

  local itemID = BLL.Scanner:GetItemID(link)
  if not itemID then return end

  -- Die Bedingung wird IMMER mitgelesen: sie haengt weder an der
  -- Quellenanzeige noch an pfQuest, und sie ist die einzige Auskunft
  -- darueber, ob man an den Gegenstand ueberhaupt herankommt. Auch vor
  -- der Wiederholungssperre, damit sie ankommt, wenn derselbe
  -- Gegenstand zweimal hintereinander unter dem Zeiger liegt.
  --
  -- Erst im naechsten Frame, nicht sofort: Die Zeile stammt von einem
  -- anderen Addon, und wer zuerst gehookt hat, schreibt zuerst. Mit
  -- allen Addons aus verschwand sie im Test komplett. Sofort gelesen
  -- wuerden wir also je nach Ladereihenfolge ins Leere greifen; einen
  -- Frame spaeter sind alle durch.
  QueueCapture(itemID)

  -- Ab hier geht es nur noch um die angehaengte Quellenliste.
  if not BananaLootlineDB or not BananaLootlineDB.tooltipSources then return end
  if not Sources.available then return end

  if lastTooltipItem == itemID then return end
  lastTooltipItem = itemID

  local list = Sources:GetItemSources(itemID)
  if not list or table.getn(list) == 0 then return end

  local maxN = BananaLootlineDB.maxSources or 5
  local shown = math.min(maxN, table.getn(list))

  tooltip:AddLine(" ")
  tooltip:AddLine("|cffffcc33Banana|cffffffffLootline|r", 1, 1, 1)

  for i = 1, shown do
    local s = list[i]
    local right = ""
    if s.chance then
      right = string.format("%.1f%%", s.chance)
    end
    local left = s.name or "?"
    if s.count and s.count > 1 then
      left = left .. " |cff666666x" .. s.count .. "|r"
    end
    if s.zone then
      left = left .. " |cff888888(" .. s.zone .. ")|r"
    end
    tooltip:AddDoubleLine("  " .. left, right, 0.8, 0.8, 0.8, 0.6, 0.9, 0.6)
  end

  if table.getn(list) > shown then
    tooltip:AddLine("  |cff666666+ " .. (table.getn(list) - shown) .. " weitere|r")
  end

  tooltip:Show()
end

------------------------------------------------------------------
-- Hooks auf die Setter, die den Link liefern
--
-- 1.12 kennt kein HookScript, also klassisches Function-Hooking. Jeder
-- Setter merkt sich den Link, bevor der Tooltip gebaut wird.
------------------------------------------------------------------

local origSetHyperlink = GameTooltip.SetHyperlink
GameTooltip.SetHyperlink = function(self, link)
  pendingLink = link
  origSetHyperlink(self, link)
  AppendSources(self, link)
end

local origSetBagItem = GameTooltip.SetBagItem
if origSetBagItem then
  GameTooltip.SetBagItem = function(self, bag, slot)
    pendingLink = GetContainerItemLink and GetContainerItemLink(bag, slot) or nil
    local a, b = origSetBagItem(self, bag, slot)
    AppendSources(self, pendingLink)
    return a, b
  end
end

local origSetInventoryItem = GameTooltip.SetInventoryItem
if origSetInventoryItem then
  GameTooltip.SetInventoryItem = function(self, unit, slot, a1, a2)
    pendingLink = GetInventoryItemLink and GetInventoryItemLink(unit, slot) or nil
    local r1, r2 = origSetInventoryItem(self, unit, slot, a1, a2)
    AppendSources(self, pendingLink)
    return r1, r2
  end
end

local origSetLootItem = GameTooltip.SetLootItem
if origSetLootItem then
  GameTooltip.SetLootItem = function(self, slot)
    pendingLink = GetLootSlotLink and GetLootSlotLink(slot) or nil
    local r = origSetLootItem(self, slot)
    AppendSources(self, pendingLink)
    return r
  end
end

-- Beim Verstecken zuruecksetzen, sonst bleibt beim erneuten Anfahren
-- desselben Items der Block aus.
local origHide = GameTooltip.Hide
GameTooltip.Hide = function(self)
  lastTooltipItem = nil
  pendingLink = nil
  origHide(self)
end
