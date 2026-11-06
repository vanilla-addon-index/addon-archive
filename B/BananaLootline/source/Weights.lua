--[[----------------------------------------------------------------------
  BananaLootline - Weights.lua

  Statgewichte pro Klasse.

  ACHTUNG - das sind PLATZHALTER. Sie sind grob an gaengige Vanilla-Werte
  angelehnt und reichen, um "deutlich besser" von "deutlich schlechter" zu
  unterscheiden. Sie sind KEINE ernsthafte Theorycraft-Grundlage und kennen
  keine Spezialisierungen.

  Genau dieser Teil steht auf der To-Do-Liste. Bis dahin: die Gewichte sind
  zur Laufzeit ueberschreibbar, damit du experimentieren kannst, ohne die
  Datei anzufassen:

      /bll weight STR 3
      /bll weight reset

  Groessenordnungen: Grundwerte liegen bei 1-2.5 pro Punkt. Prozentwerte
  wie Crit und Hit kommen als kleine Zahlen (1, 2) aus dem Tooltip und
  brauchen deshalb Gewichte im Bereich 15-35, sonst fallen sie durch.
------------------------------------------------------------------------]]

BananaLootline = BananaLootline or {}
local BLL = BananaLootline
BLL.Weights = {}
local Weights = BLL.Weights

Weights.DEFAULTS = {
  WARRIOR = {
    STR = 2.0, AGI = 1.5, STA = 1.0,
    AP = 1.0, CRIT = 25, HIT = 30,
    ARMOR = 0.03, DEFENSE = 1.0, DODGE = 12, PARRY = 12, BLOCK = 8,
    WEAPON_DPS = 6.0,
  },
  PALADIN = {
    STR = 2.0, AGI = 1.0, STA = 1.2, INT = 0.5, SPI = 0.2,
    AP = 1.0, CRIT = 22, HIT = 28, SPELLPOWER = 0.5,
    ARMOR = 0.05, DEFENSE = 1.0, DODGE = 12, PARRY = 12, BLOCK = 8,
    MP5 = 2.0, WEAPON_DPS = 5.0,
  },
  -- Jaeger: belegt. Quelle: Icy Veins, "Classic Hunter DPS Stat
  -- Priority" (Impakt, Stand 17.11.2024), Bezug Stufe 60:
  --   1 Beweglichkeit ~ 2,5 Angriffskraft (ohne Buffs)
  --   1 % Krit ~ 32 AP, 1 % Treffer ~ 32 AP
  --   allgemeine Angriffskraft wirkt auf Nah- UND Fernkampf -> AP = RAP
  --   Staerke bringt nur Nahkampf-AP und ist fuer Jaeger kaum von Nutzen
  -- STA, INT, ARMOR, WEAPON_DPS sind weiter Schaetzwerte.
  -- MELEE_DPS: die Nahkampfwaffe eines Jaegers ist vor allem Werte-
  -- traeger, geschossen wird mit dem Bogen. Mit vollem WEAPON_DPS stand
  -- "Rockslicer" (Zweihandaxt, 18,2 DPS gegen 2,5 beim Dolch) fuer
  -- rund 47 Punkte im Wegplan und zog die Todesminen ueber jeden Ort
  -- mit Ruestungsupgrades.
  HUNTER = {
    AGI = 2.5, STR = 0.1, STA = 1.0, INT = 0.3,
    RAP = 1.0, AP = 1.0, CRIT = 32, HIT = 32,
    ARMOR = 0.02, WEAPON_DPS = 3.0, MELEE_DPS = 0.5,
  },
  ROGUE = {
    AGI = 2.5, STR = 1.0, STA = 1.0,
    AP = 1.0, CRIT = 25, HIT = 35,
    ARMOR = 0.02, WEAPON_DPS = 5.0,
  },
  PRIEST = {
    INT = 1.0, SPI = 0.8, STA = 0.8,
    SPELLPOWER = 1.5, HEALPOWER = 1.0, SPELLCRIT = 15, SPELLHIT = 20,
    MP5 = 3.0, ARMOR = 0.01,
  },
  SHAMAN = {
    INT = 1.0, STA = 1.0, STR = 1.0, AGI = 1.0, SPI = 0.5,
    SPELLPOWER = 1.2, HEALPOWER = 0.8, AP = 0.7,
    SPELLCRIT = 12, CRIT = 12, MP5 = 3.0, ARMOR = 0.02,
  },
  MAGE = {
    INT = 1.0, SPI = 0.5, STA = 0.8,
    SPELLPOWER = 1.6, SPELLCRIT = 18, SPELLHIT = 25,
    MP5 = 2.5, ARMOR = 0.01,
  },
  WARLOCK = {
    INT = 1.0, SPI = 0.5, STA = 1.0,
    SPELLPOWER = 1.6, SPELLCRIT = 15, SPELLHIT = 25,
    MP5 = 2.0, ARMOR = 0.01,
  },
  DRUID = {
    INT = 1.0, STA = 1.0, SPI = 0.7, AGI = 1.0, STR = 1.0,
    SPELLPOWER = 1.2, HEALPOWER = 0.8, SPELLCRIT = 12,
    AP = 0.5, CRIT = 12, MP5 = 3.0, ARMOR = 0.02,
  },
}

-- Widerstaende zaehlen fuer alle minimal mit, damit ein reines
-- Widerstandsitem nicht als Nullwert durchfaellt.
local COMMON = {
  -- 10 Leben entsprechen grob 1 Ausdauer, Mana zaehlt noch weniger.
  -- Ohne diese Gewichte fielen die "Minor Health"-Verzauberungen mit
  -- Wert 0 durch und taeuchten nie auf.
  HEALTH = 0.1, MANA = 0.05,
  RES_FIRE = 0.3, RES_FROST = 0.3, RES_NATURE = 0.3,
  RES_SHADOW = 0.3, RES_ARCANE = 0.3,
}

------------------------------------------------------------------
-- Spezialisierung erkennen
--
-- GetTalentTabInfo liefert pro Baum die vergebenen Punkte. Der Baum
-- mit den meisten gilt als Spezialisierung.
--
-- Unter 10 vergebenen Punkten insgesamt wird NICHT geraten: auf
-- niedriger Stufe sagen drei Punkte nichts aus, und eine falsche
-- Spezialisierung verzerrt die Bewertung staerker, als gar keine zu
-- haben. Dann gelten die Klassenwerte.
------------------------------------------------------------------

Weights.MIN_POINTS = 10

function Weights:DetectSpec()
  if not GetNumTalentTabs then return nil end

  local best, bestPoints, total = nil, -1, 0
  local bestName = nil

  for i = 1, GetNumTalentTabs() do
    local name, _, points = GetTalentTabInfo(i)
    points = points or 0
    total = total + points
    if points > bestPoints then
      bestPoints = points
      best = i
      bestName = name
    end
  end

  if total < self.MIN_POINTS then return nil, bestName, total end
  return best, bestName, total
end

------------------------------------------------------------------
-- Abweichungen pro Spezialisierung
--
-- Nur was sich wirklich unterscheidet. Alles Uebrige kommt aus den
-- Klassenwerten. Schluessel ist die Nummer des Talentbaums.
--
-- Bei Magiern zaehlt schulgebundener Zauberschaden voll statt halb,
-- wenn er zur eigenen Schule passt - ein Feuerstab ist fuer einen
-- Feuermagier eben so gut wie allgemeine Zaubermacht.
------------------------------------------------------------------

Weights.SPECS = {
  WARRIOR = {
    [1] = { name = "Waffen",     STR = 2.2, CRIT = 28, HIT = 32 },
    [2] = { name = "Furor",      STR = 2.0, AGI = 1.8, CRIT = 28, HIT = 35 },
    [3] = { name = "Schutz",     STA = 2.5, ARMOR = 0.12, DEFENSE = 3.0,
                                 DODGE = 25, PARRY = 25, BLOCK = 20,
                                 STR = 0.8, CRIT = 8, HIT = 8, WEAPON_DPS = 1.0 },
  },
  PALADIN = {
    [1] = { name = "Heilig",     INT = 1.2, SPI = 0.8, HEALPOWER = 1.6,
                                 SPELLPOWER = 1.0, MP5 = 4.0, STR = 0.2, AP = 0.1 },
    [2] = { name = "Schutz",     STA = 2.5, ARMOR = 0.12, DEFENSE = 3.0,
                                 DODGE = 25, PARRY = 25, BLOCK = 20, STR = 0.8 },
    [3] = { name = "Vergeltung", STR = 2.2, AP = 1.0, CRIT = 25, HIT = 30,
                                 INT = 0.2, MP5 = 0.5 },
  },
  -- Die Quelle unterscheidet die Jaeger-Spezialisierungen nicht. Die
  -- frueheren Abweichungen pro Spec waren geraten und sind entfallen;
  -- alle drei nutzen die belegten Klassenwerte.
  HUNTER = {
    [1] = { name = "Tierherrschaft" },
    [2] = { name = "Treffsicherheit" },
    [3] = { name = "Ueberleben" },
  },
  ROGUE = {
    [1] = { name = "Meucheln",   AGI = 2.6, CRIT = 28, HIT = 35 },
    [2] = { name = "Kampf",      AGI = 2.4, STR = 1.2, WEAPON_DPS = 6.0, HIT = 38 },
    [3] = { name = "Taeuschung", AGI = 2.6, STA = 1.2, CRIT = 26 },
  },
  PRIEST = {
    [1] = { name = "Disziplin",  INT = 1.2, HEALPOWER = 1.4, MP5 = 3.5 },
    [2] = { name = "Heilig",     INT = 1.2, SPI = 1.0, HEALPOWER = 1.8, MP5 = 4.0,
                                 SPELLPOWER = 0.8 },
    [3] = { name = "Schatten",   SPELLPOWER = 1.8, SPELLCRIT = 20, SPELLHIT = 28,
                                 HEALPOWER = 0.1, SPI = 0.3,
                                 SPELLPOWER_SHADOW = 1.8 },
  },
  SHAMAN = {
    [1] = { name = "Elementar",  SPELLPOWER = 1.7, SPELLCRIT = 20, SPELLHIT = 28,
                                 INT = 1.1, AP = 0.1, STR = 0.1,
                                 SPELLPOWER_NATURE = 1.7, SPELLPOWER_FIRE = 1.4 },
    [2] = { name = "Verstaerkung", STR = 1.8, AGI = 1.8, AP = 1.0, CRIT = 22,
                                 HIT = 28, SPELLPOWER = 0.3, INT = 0.3 },
    [3] = { name = "Wiederherstellung", INT = 1.2, SPI = 0.9, HEALPOWER = 1.8,
                                 MP5 = 4.0, SPELLPOWER = 0.5 },
  },
  MAGE = {
    [1] = { name = "Arkan",      SPELLPOWER = 1.6, SPELLPOWER_ARCANE = 1.6, INT = 1.2 },
    [2] = { name = "Feuer",      SPELLPOWER = 1.6, SPELLPOWER_FIRE = 1.6,
                                 SPELLCRIT = 22 },
    [3] = { name = "Frost",      SPELLPOWER = 1.6, SPELLPOWER_FROST = 1.6,
                                 SPELLHIT = 28 },
  },
  WARLOCK = {
    [1] = { name = "Gebrechen",  SPELLPOWER = 1.6, SPELLPOWER_SHADOW = 1.6,
                                 SPELLHIT = 30 },
    [2] = { name = "Daemonologie", SPELLPOWER = 1.5, STA = 1.4, SPELLPOWER_SHADOW = 1.5 },
    [3] = { name = "Zerstoerung", SPELLPOWER = 1.7, SPELLCRIT = 20,
                                 SPELLPOWER_FIRE = 1.7, SPELLPOWER_SHADOW = 1.7 },
  },
  DRUID = {
    [1] = { name = "Gleichgewicht", SPELLPOWER = 1.7, SPELLCRIT = 20, INT = 1.2,
                                 SPELLPOWER_ARCANE = 1.7, SPELLPOWER_NATURE = 1.7,
                                 AP = 0.1, STR = 0.1, AGI = 0.3 },
    [2] = { name = "Wildheit",   AGI = 2.2, STR = 2.0, STA = 1.5, AP = 1.0,
                                 CRIT = 24, HIT = 30, ARMOR = 0.08,
                                 INT = 0.2, SPELLPOWER = 0.1, MP5 = 0.3 },
    [3] = { name = "Wiederherstellung", INT = 1.2, SPI = 0.9, HEALPOWER = 1.8,
                                 MP5 = 4.0, SPELLPOWER = 0.5, AGI = 0.2, STR = 0.1 },
  },
}

------------------------------------------------------------------
-- Eigene Wahl der Spezialisierung
--
-- Die Erkennung bleibt der Normalfall. Unter 10 Talentpunkten gibt es
-- aber nichts zu erkennen, und ein Stufe-15-Jaeger weiss trotzdem, was
-- er spielen will. Die Wahl liegt pro Charakter in den SavedVariables;
-- nil heisst automatisch.
------------------------------------------------------------------

-- Englische Namen fuer die Anzeige. Schluessel bleibt der deutsche.
Weights.SPEC_EN = {
  ["Waffen"] = "Arms", ["Furor"] = "Fury", ["Schutz"] = "Protection",
  ["Heilig"] = "Holy", ["Vergeltung"] = "Retribution",
  ["Tierherrschaft"] = "Beast Mastery", ["Treffsicherheit"] = "Marksmanship",
  ["Ueberleben"] = "Survival", ["Meucheln"] = "Assassination",
  ["Kampf"] = "Combat", ["Taeuschung"] = "Subtlety",
  ["Disziplin"] = "Discipline", ["Schatten"] = "Shadow",
  ["Elementar"] = "Elemental", ["Verstaerkung"] = "Enhancement",
  ["Wiederherstellung"] = "Restoration", ["Arkan"] = "Arcane",
  ["Feuer"] = "Fire", ["Frost"] = "Frost", ["Gebrechen"] = "Affliction",
  ["Daemonologie"] = "Demonology", ["Zerstoerung"] = "Destruction",
  ["Gleichgewicht"] = "Balance", ["Wildheit"] = "Feral",
}

function Weights:SpecName(name)
  if BLL.locale ~= "deDE" and self.SPEC_EN[name] then return self.SPEC_EN[name] end
  return name
end

function Weights:ChosenSpec()
  local tab = BananaLootlineChar and BananaLootlineChar.spec
  local class = BLL.player and BLL.player.class
  local specs = self.SPECS[class or ""]
  if tab and specs and specs[tab] then return tab end
  return nil
end

function Weights:SetSpec(tab)
  BananaLootlineChar = BananaLootlineChar or {}
  BananaLootlineChar.spec = tab
end

-- Liefert den geltenden Talentbaum und ob er von Hand gewaehlt ist.
function Weights:ActiveTab()
  local chosen = self:ChosenSpec()
  if chosen then return chosen, true end
  return (self:DetectSpec()), false
end

-- Talentbaum aus Nummer oder Namensanfang, z.B. "2" oder "tier".
function Weights:FindSpec(text)
  local class = BLL.player and BLL.player.class
  local specs = self.SPECS[class or ""]
  if not specs or not text then return nil end
  local n = tonumber(text)
  if n and specs[n] then return n end
  local low = string.lower(text)
  for i = 1, 3 do
    local de = specs[i] and specs[i].name
    local en = de and self.SPEC_EN[de]
    if (de and string.find(string.lower(de), low, 1, true) == 1)
        or (en and string.find(string.lower(en), low, 1, true) == 1) then
      return i
    end
  end
  return nil
end

function Weights:Get()
  local class = BLL.player and BLL.player.class

  -- Spezialisierung zuerst bestimmen, auch wenn gleich eigene Gewichte
  -- gelten. Frueher kehrte Get() bei eigenen Gewichten sofort zurueck:
  -- die Unterzeile zeigte dann "keine Spez. erkannt", und eine Wahl im
  -- Menue aenderte sichtbar nichts - gemeldet von einem Tester auf
  -- Stufe 60 mit 51 Talentpunkten.
  local tab, manual = self:ActiveTab()
  local specs = self.SPECS[class or ""]
  self.specManual = manual
  if tab and specs and specs[tab] then
    self.activeSpec = self:SpecName(specs[tab].name)
  else
    self.activeSpec = nil
  end

  -- Eigene Gewichte (/bll weight, Menue "Statgewichte") haben Vorrang
  -- vor Klasse und Spec. Sie gelten pro Charakter.
  local own = self:Custom()
  self.customWeights = own and true or nil
  if own then return own end
  return self:BaseFor(class, tab)
end

-- Gewichte einer Klasse und Spec ohne eigene Aenderungen. tab nil heisst
-- reine Klassenwerte.
function Weights:BaseFor(class, tab)
  local base = self.DEFAULTS[class or ""] or self.DEFAULTS["WARRIOR"]
  local specs = self.SPECS[class or ""]
  local out = {}
  for k, v in pairs(base) do out[k] = v end
  if tab and specs and specs[tab] then
    for k, v in pairs(specs[tab]) do
      if k ~= "name" then out[k] = v end
    end
  end
  for k, v in pairs(COMMON) do
    if not out[k] then out[k] = v end
  end
  return out
end

-- Eigene Gewichte des Charakters. Bis 0.23.4 lagen sie fuer den ganzen
-- Account in BananaLootlineDB.weights; der erste Charakter, der sie
-- liest, uebernimmt sie.
function Weights:Custom()
  BananaLootlineChar = BananaLootlineChar or {}
  if BananaLootlineDB and BananaLootlineDB.weights and not BananaLootlineChar.weights then
    BananaLootlineChar.weights = BananaLootlineDB.weights
    BananaLootlineDB.weights = nil
  end
  return BananaLootlineChar.weights
end

-- Alle Gewichte auf einmal setzen (Menue), nil hebt sie auf.
function Weights:SetAll(t)
  BananaLootlineChar = BananaLootlineChar or {}
  if not t then BananaLootlineChar.weights = nil return end
  local copy = {}
  for k, v in pairs(t) do if v and v ~= 0 then copy[k] = v end end
  BananaLootlineChar.weights = copy
end

function Weights:Set(stat, value)
  BananaLootlineChar = BananaLootlineChar or {}
  BananaLootlineChar.weights = self:Custom() or self:Get()
  if value == nil or value == 0 then
    BananaLootlineChar.weights[stat] = nil
  else
    BananaLootlineChar.weights[stat] = value
  end
end

function Weights:Reset()
  BananaLootlineChar = BananaLootlineChar or {}
  BananaLootlineChar.weights = nil
  if BananaLootlineDB then BananaLootlineDB.weights = nil end
end

------------------------------------------------------------------
-- Use-Effekte
--
-- Ein Use-Effekt ist nicht mit festen Werten vergleichbar. "+100
-- Angriffskraft fuer 20 Sekunden alle 2 Minuten" sind im Schnitt rund
-- 17 Angriffskraft, nicht 100. Gerechnet wird also die Ueberdeckung:
--
--     Anteil = Dauer / Abklingzeit
--
-- Problem: der Datenbankexport liefert bei KEINEM Use-Effekt eine
-- Abklingzeit - die Seite schreibt sie offenbar in einer Form, die der
-- Exporter nicht erkennt. Ohne sie ist der Anteil unbestimmt.
--
-- Statt zu raten oder den Effekt zu ignorieren wird eine angenommene
-- Abklingzeit verwendet, die man aendern kann. Wo sie greift, wird das
-- Ergebnis als Schaetzung ausgewiesen - im Fenster steht dann "gesch."
-- hinter dem Wert.
------------------------------------------------------------------

Weights.DEFAULT_COOLDOWN = 180    -- Sekunden, wenn die Datenbank keine nennt

-- Welcher Stat steckt hinter dem Effekttext? Nur das Noetigste, alles
-- andere bleibt unbewertet.
local USE_STAT = {
  { "AP",         "[Aa]ttack [Pp]ower" },
  { "SPELLPOWER", "damage and healing" },
  { "SPELLPOWER", "[Ss]pell [Dd]amage" },
  { "HEALPOWER",  "healing done" },
  { "STR",        "Strength" },
  { "AGI",        "Agility" },
  { "STA",        "Stamina" },
  { "INT",        "Intellect" },
  { "SPI",        "Spirit" },
  { "ARMOR",      "[Aa]rmor" },
  { "DODGE",      "dodge" },
  { "CRIT",       "critical strike" },
}

function Weights:UseEffectScore(uses)
  if not uses then return 0, nil end

  local w = self:Get()
  local cdDefault = (BananaLootlineDB and BananaLootlineDB.useCooldown)
                    or self.DEFAULT_COOLDOWN
  local total, estimated = 0, false

  for i = 1, table.getn(uses) do
    local u = uses[i]
    if u.v and u.t then
      local stat = nil
      for p = 1, table.getn(USE_STAT) do
        if string.find(u.t, USE_STAT[p][2]) then
          stat = USE_STAT[p][1]
          break
        end
      end

      local weight = stat and w[stat]
      if weight then
        local duration = u.d or 20
        local cooldown = u.cd
        if not cooldown then
          cooldown = cdDefault
          estimated = true
        end
        if cooldown > 0 then
          local uptime = duration / cooldown
          if uptime > 1 then uptime = 1 end
          total = total + (u.v * uptime * weight)
        end
      end
    end
  end

  return total, estimated
end

------------------------------------------------------------------
-- Bewertung
------------------------------------------------------------------

-- Waffenwerte werden nur fuer Waffenslots gewertet, sonst verzerrt der
-- DPS-Wert eines Zweihaenders jeden Vergleich.
local WEAPON_ONLY = {
  WEAPON_DPS = true, WEAPON_MIN = true,
  WEAPON_MAX = true, WEAPON_SPEED = true,
}

-- Score einer reinen Werteliste. extra kann weitere Werte beisteuern
-- (etwa aus einem Setbonus), die genauso gewichtet werden.
function Weights:Score(stats, isWeapon, extra)
  if not stats and not extra then return 0 end
  if extra then
    local merged = {}
    for k, v in pairs(stats or {}) do merged[k] = v end
    for k, v in pairs(extra) do merged[k] = (merged[k] or 0) + v end
    stats = merged
  end
  if not stats then return 0 end
  local w = self:Get()
  local score = 0

  for stat, value in pairs(stats) do
    if not (WEAPON_ONLY[stat] and not isWeapon) then
      local weight = w[stat]
      if stat == "WEAPON_DPS" and isWeapon == "melee" and w["MELEE_DPS"] then
        weight = w["MELEE_DPS"]
      end

      -- Schulgebundener Zauberschaden ("nur Arkan") zaehlt nur zur
      -- Haelfte: er wirkt bloss auf einen Teil der Zauber. Ohne diese
      -- Daempfung wuerde ein Feuerstab fuer einen Frostmagier so hoch
      -- bewertet wie fuer einen Feuermagier.
      if not weight and string.find(stat, "^SPELLPOWER_") then
        weight = (w["SPELLPOWER"] or 0) * 0.5
      end

      if weight and weight ~= 0 then
        score = score + (value * weight)
      end
    end
  end

  return score
end

-- Welche Stats haben zum Score beigetragen? Fuer die Anzeige,
-- damit nachvollziehbar ist, warum ein Item vorgeschlagen wird.
function Weights:Explain(stats, isWeapon)
  if not stats then return "" end
  local w = self:Get()
  local parts = {}

  for i = 1, table.getn(BLL.STATS) do
    local stat = BLL.STATS[i]
    local value = stats[stat]
    if value and not (WEAPON_ONLY[stat] and not isWeapon) and w[stat] then
      local sign = (value < 0) and "" or "+"
      table.insert(parts, sign .. value .. " " .. stat)
    end
  end

  return table.concat(parts, ", ")
end
