--[[----------------------------------------------------------------------
  BananaLootline - Scanner.lua

  Liest Stats aus einem Item, indem der Tooltip in einen unsichtbaren
  Frame gerendert und zeilenweise geparst wird. Das ist im 1.12-Client
  der einzige Weg an die Werte zu kommen (kein GetItemStats).

  Ergebnis: flache Tabelle { STR = 10, STA = 15, ARMOR = 115, ... }
  Nicht vorhandene Stats fehlen (nicht 0), damit man leicht pruefen kann,
  ob ein Item ueberhaupt geparst wurde.

  Achtung: GetItemInfo() liefert im 1.12-Client KEIN Itemlevel - nur
  Name, Link, Qualitaet, benoetigte Stufe, Typ, Subtyp, Stackgroesse,
  EquipLoc und Textur. Itemlevel kommt aus der importierten ItemDB.
------------------------------------------------------------------------]]

BananaLootline = BananaLootline or {}
local BLL = BananaLootline
BLL.Scanner = {}
local Scanner = BLL.Scanner

------------------------------------------------------------------
-- Versteckter Scan-Tooltip
------------------------------------------------------------------

local scanTip = CreateFrame("GameTooltip", "BananaLootlineScanTooltip", nil, "GameTooltipTemplate")
scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")

Scanner.tooltip = scanTip

-- Cache, damit dasselbe Item nicht bei jedem Tooltip-Hover neu geparst wird.
local cache = {}

function Scanner:ClearCache()
  cache = {}
end

------------------------------------------------------------------
-- Hilfsfunktionen
------------------------------------------------------------------

-- Akzeptiert itemID (Zahl), vollen Itemlink oder nackten "item:1234:0:0:0"
--
-- WICHTIG: GetInventoryItemLink() und GetContainerItemLink() liefern den
-- VOLLSTAENDIGEN Link inklusive Farbcode und Klammertext:
--
--   |cffffffff|Hitem:12345:0:0:0|h[Schwert]|h|r
--
-- SetHyperlink() im 1.12-Client akzeptiert aber nur den nackten Teil
-- zwischen |H und |h. Alles andere wirft "Unknown link type".
-- Deshalb hier IMMER reduzieren, bevor der Link weitergereicht wird.
function Scanner:NormalizeLink(item)
  if type(item) == "number" then
    return "item:" .. item .. ":0:0:0"
  end

  if type(item) ~= "string" or item == "" then
    return nil
  end

  -- Vollen Link auf den Hyperlink-Teil reduzieren
  local _, _, inner = string.find(item, "|H(.-)|h")
  if inner then
    return inner
  end

  -- Bereits nackt uebergeben
  if string.find(item, "^item:") then
    return item
  end

  -- Reine Zahl als String
  local id = tonumber(item)
  if id then
    return "item:" .. id .. ":0:0:0"
  end

  return nil
end

local function ToHyperlink(item)
  return Scanner:NormalizeLink(item)
end

-- Suffix-IDs koennen negativ sein (Items mit Zufallsverzauberung),
-- deshalb das Vorzeichen im Pattern zulassen.
function Scanner:GetItemID(link)
  if not link then return nil end
  if type(link) == "number" then return link end
  local _, _, id = string.find(link, "item:(%-?%d+)")
  return tonumber(id)
end

-- Setboni stehen im Tooltip als "Set: ..." (aktiv) oder "(3) Set: ..."
-- (noch nicht aktiv) - im deutschen Client genauso. Bewertet werden sie
-- ueber SetDB, mit der Zahl der tatsaechlich getragenen Teile. Aus dem
-- Tooltip gelesen zaehlten sie doppelt oder, haeufiger: eine Zeile wie
-- "Set: Reduces the cooldown of your Vanish ability by 30 sec." oder
-- "Set: Restores 2 energy..." passte auf kein Muster, galt als
-- unbezifferter Effekt, und das ganze Teil wurde als nicht vollstaendig
-- bewertbar markiert - gemeldet von einem Tester mit Setteilen.
local SET_LINE = { "^Set:", "^%(%d+%) Set:" }

local function ShouldSkip(line)
  for i = 1, table.getn(BLL.SKIP_PREFIX) do
    if string.find(line, BLL.SKIP_PREFIX[i], 1, true) then
      return true
    end
  end
  for i = 1, table.getn(SET_LINE) do
    if string.find(line, SET_LINE[i]) then return true end
  end
  return false
end

------------------------------------------------------------------
-- Rohe Tooltipzeilen holen
------------------------------------------------------------------

-- ClearLines() setzt im 1.12-Client nur den internen Zeilenzaehler zurueck,
-- laesst die Texte der FontStrings aber stehen. Hat das naechste Item
-- weniger Zeilen als das vorherige, liefert NumLines() die alten Zeilen mit
-- und wir parsen Werte, die dem Item gar nicht gehoeren. Genau so bekam ein
-- Off-Hand-Schmuckstueck das Tempo des zuvor gescannten Dolches.
--
-- Deshalb vor jedem Scan alle FontStrings explizit leeren.
local MAX_TOOLTIP_LINES = 40

local function WipeScanTooltip()
  for i = 1, MAX_TOOLTIP_LINES do
    local left  = getglobal("BananaLootlineScanTooltipTextLeft" .. i)
    local right = getglobal("BananaLootlineScanTooltipTextRight" .. i)
    if left  then left:SetText("")  end
    if right then right:SetText("") end
  end
end

function Scanner:GetLines(item)
  local link = ToHyperlink(item)
  if not link then return nil end

  -- Der Scanner ist ausschliesslich fuer Items zustaendig. Quest-, Spell-
  -- oder Enchant-Links koennen ueber GetItem()/Chatlinks hereinkommen und
  -- haetten hier nichts verloren.
  if not string.find(link, "^item:") then return nil end

  scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
  scanTip:ClearLines()
  WipeScanTooltip()

  -- Zusaetzlich abgesichert: selbst wenn doch mal ein kaputter Link
  -- durchrutscht, soll das den Aufrufer nicht abbrechen und vor allem
  -- nicht das Fehlerfenster fluten.
  local ok = pcall(function() scanTip:SetHyperlink(link) end)
  if not ok then
    BLL:Debug("SetHyperlink fehlgeschlagen fuer: " .. tostring(link))
    scanTip:Hide()
    return nil
  end

  local lines = {}
  local n = scanTip:NumLines()
  for i = 1, n do
    local left = getglobal("BananaLootlineScanTooltipTextLeft" .. i)
    local right = getglobal("BananaLootlineScanTooltipTextRight" .. i)
    local lt = left and left:GetText()
    local rt = right and right:GetText()
    if lt and lt ~= "" then table.insert(lines, lt) end
    if rt and rt ~= "" then table.insert(lines, rt) end
  end

  scanTip:Hide()
  return lines
end

------------------------------------------------------------------
-- Stats parsen
------------------------------------------------------------------

-- Deutet die Zeile auf einen Effekt hin, den kein Wertmuster erfasst?
-- Wird nur fuer Zeilen gefragt, auf die vorher nichts gepasst hat.
local function LooksLikeEffect(line)
  local hints = BLL.EFFECT_HINTS
  if not hints then return false end
  local low = string.lower(line)
  for i = 1, table.getn(hints) do
    if string.find(low, hints[i], 1, true) then return true end
  end
  return false
end

-- Nennt die Zeile eine Zugangsbedingung - Ruf, PvP-Rang, Beruf?
--
-- Reine Stufenzeilen sind hier nicht mehr zu erwarten: die filtert
-- ShouldSkip ueber SKIP_PREFIX bereits vorher heraus. Was als
-- Bedingungszeile uebrig bleibt, ist etwas, das man sich erst verdienen
-- muss - und damit nichts, das in einem Wegplan stehen sollte.
local function IsRestriction(line)
  local pre = BLL.RESTRICT_PREFIX
  if pre then
    for i = 1, table.getn(pre) do
      if string.find(line, pre[i]) then return true end
    end
  end
  local words = BLL.RESTRICT_WORDS
  if words then
    local low = string.lower(line)
    for i = 1, table.getn(words) do
      if string.find(low, words[i], 1, true) then return true end
    end
  end
  return false
end

-- Oeffentliche Fassung fuer Aufrufer ausserhalb des Statscans, vor allem
-- den Tooltip-Hook. Reine Stufenzeilen filtert sie gleich mit weg - im
-- Statscan uebernimmt das vorher SKIP_PREFIX.
function Scanner:IsRestrictionLine(line)
  if type(line) ~= "string" or line == "" then return false end
  if ShouldSkip(line) then return false end
  return IsRestriction(line)
end

-- Liefert die Werte und - als zweiten Rueckgabewert - eine Tabelle mit
-- dem, was der Tooltip sonst noch verraet. Aufrufer, die nur die Werte
-- brauchen, merken davon nichts.
--
--   meta.unscored    Zeilen, die nach einem Effekt aussehen, aus denen
--                    aber kein Wert kam (Procs). Verhindert, dass ein
--                    starkes Teil als "nichts wert" durchgeht.
--   meta.restricted  Die Zeile mit einer Zugangsbedingung, falls es eine
--                    gibt. Ruf, PvP-Rang oder Beruf.
function Scanner:GetStats(item)
  local id = (type(item) == "number") and item or self:GetItemID(item)
  if id and cache[id] then
    local c = cache[id]
    return c.stats, c.meta
  end

  local lines = self:GetLines(item)
  if not lines or table.getn(lines) == 0 then return nil end

  local stats = {}
  local unscored = {}
  local restricted = nil
  local patterns = BLL.PATTERNS
  local pcount = table.getn(patterns)

  for i = 1, table.getn(lines) do
    local line = lines[i]

    if not ShouldSkip(line) then
      local matched = false

      -- Schadensbereich zuerst (zwei Captures)
      local _, _, dmin, dmax = string.find(line, BLL.DMG_PATTERN)
      if dmin then
        stats["WEAPON_MIN"] = tonumber(dmin)
        stats["WEAPON_MAX"] = tonumber(dmax)
        matched = true
      else
        for p = 1, pcount do
          local entry = patterns[p]
          local key, pat, sign = entry[1], entry[2], entry[3] or 1
          local _, _, value = string.find(line, pat)
          if value then
            local num = tonumber(value)
            if num then
              stats[key] = (stats[key] or 0) + (num * sign)
            end
            matched = true
            break   -- eine Zeile liefert maximal einen Stat
          end
        end
      end

      if not matched then
        -- Bedingung vor Effekt pruefen: "Benoetigt: Feldwebel" ist keine
        -- unbezifferte Staerke, sondern eine geschlossene Tuer.
        if not restricted and IsRestriction(line) then
          restricted = line
        elseif LooksLikeEffect(line) then
          table.insert(unscored, line)
        end
      end
    end
  end

  local meta = nil
  if table.getn(unscored) > 0 or restricted then
    meta = { unscored = (table.getn(unscored) > 0) and unscored or nil,
             restricted = restricted }
  end

  if id then cache[id] = { stats = stats, meta = meta } end
  return stats, meta
end

------------------------------------------------------------------
-- Kompakte Iteminfo (Name, Qualitaet, Slot, ...)
------------------------------------------------------------------

function Scanner:GetItemInfoSafe(item)
  local id = (type(item) == "number") and item or self:GetItemID(item)
  if not id then return nil end

  -- 1.12: name, link, quality, reqLevel, type, subType, stackCount, equipLoc, texture
  local name, link, quality, reqLevel, itype, subtype, stack, equipLoc, texture = GetItemInfo(id)

  if not name then
    -- Item ist nicht im Client-Cache. Der Tooltip-Aufruf oben stoesst die
    -- Serverabfrage an; beim naechsten Versuch ist es meist da.
    self:GetLines(id)
    name, link, quality, reqLevel, itype, subtype, stack, equipLoc, texture = GetItemInfo(id)
  end

  if not name then return nil end

  local info = {
    id       = id,
    name     = name,
    link     = link,
    quality  = quality,
    reqLevel = reqLevel,
    itype    = itype,
    subtype  = subtype,
    equipLoc = equipLoc,
    texture  = texture,
  }

  -- Itemlevel und weitere Felder aus der importierten DB anreichern
  if BLL.ItemDB and BLL.ItemDB.loaded then
    local extra = BLL.ItemDB:Get(id)
    if extra then
      info.ilvl        = extra.ilvl
      info.classMask   = extra.classmask
      info.raceMask    = extra.racemask
      info.slotDB      = extra.slot
    end
  end

  return info
end

------------------------------------------------------------------
-- Debughilfe: rohe Zeilen ins Chatfenster
------------------------------------------------------------------

function Scanner:DumpLines(item)
  local lines = self:GetLines(item)
  if not lines then
    BLL:Print(BLL.L["NO_SOURCE"])
    return
  end

  BLL:Print(BLL.L["DUMP_LINES"])
  for i = 1, table.getn(lines) do
    DEFAULT_CHAT_FRAME:AddMessage("  |cff888888[" .. i .. "]|r " .. lines[i])
  end

  local stats, meta = self:GetStats(item)
  local found = ""
  for k, v in pairs(stats or {}) do
    found = found .. k .. "=" .. v .. "  "
  end
  BLL:Print(string.format(BLL.L["DUMP_FOUND"],
    (found ~= "") and found or ("|cffff0000" .. BLL.L["DUMP_NOTHING"] .. "|r")))

  -- Zeilen, die nach einem Effekt aussehen, aus denen aber kein Wert
  -- kam. Wer eine harmlose Zeile hier auftauchen sieht, hat einen
  -- Fehlalarm gefunden - genau dafuer steht sie hier.
  if meta and meta.unscored then
    BLL:Print("|cffff8800" .. BLL.L["DUMP_UNSCORED"] .. "|r")
    for i = 1, table.getn(meta.unscored) do
      DEFAULT_CHAT_FRAME:AddMessage("  |cff888888-|r " .. meta.unscored[i])
    end
  end

  if meta and meta.restricted then
    BLL:Print("|cffff0000" .. BLL.L["DUMP_LOCKED"] .. "|r")
    DEFAULT_CHAT_FRAME:AddMessage("  |cff888888-|r " .. meta.restricted)
  end
end

------------------------------------------------------------------
-- Tooltip-Diagnose
--
-- Anlass: Der Tooltip im Spiel zeigte bei "Outrider's Bow" die Zeile
-- "Warsong Gulch - Revered". Im Scan-Tooltip fehlte sie, obwohl das
-- Muster sie erkannt haette. Ohne diese Zeile kann das Addon nicht
-- wissen, dass man den Gegenstand nicht einfach kaufen kann.
--
-- Diese Funktion liest denselben Gegenstand auf vier Wegen und zeigt,
-- welcher die vollstaendigen Zeilen liefert. Damit laesst sich die
-- Ursache feststellen, statt sie zu vermuten.
------------------------------------------------------------------

function Scanner:CompareTooltip(item)
  local link = ToHyperlink(item)
  if not link then
    BLL:Print(BLL.L["USAGE_TIP"])
    return
  end

  -- Jeder Weg: Beschreibung, Besitzer, ob der Tooltip sichtbar gemacht wird
  local ways = {
    { "SetOwner(WorldFrame), versteckt", WorldFrame, false },
    { "SetOwner(WorldFrame), sichtbar",  WorldFrame, true  },
    { "SetOwner(UIParent), versteckt",   UIParent,   false },
    { "SetOwner(UIParent), sichtbar",    UIParent,   true  },
  }

  BLL:Print(string.format(BLL.L["TIP_COMPARE"], link))

  for w = 1, table.getn(ways) do
    local name, owner, show = ways[w][1], ways[w][2], ways[w][3]

    scanTip:SetOwner(owner or WorldFrame, "ANCHOR_NONE")
    scanTip:ClearLines()
    WipeScanTooltip()
    if show then scanTip:Show() end

    local ok = pcall(function() scanTip:SetHyperlink(link) end)
    local n = ok and scanTip:NumLines() or 0

    local got = {}
    for i = 1, n do
      local l = getglobal("BananaLootlineScanTooltipTextLeft" .. i)
      local r = getglobal("BananaLootlineScanTooltipTextRight" .. i)
      local lt = l and l:GetText()
      local rt = r and r:GetText()
      if lt and lt ~= "" then table.insert(got, "L" .. i .. ": " .. lt) end
      if rt and rt ~= "" then table.insert(got, "R" .. i .. ": " .. rt) end
    end
    scanTip:Hide()

    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc33" .. name .. "|r  NumLines="
      .. n .. ", Zeilen=" .. table.getn(got))
    for i = 1, table.getn(got) do
      DEFAULT_CHAT_FRAME:AddMessage("   |cff888888" .. got[i] .. "|r")
    end
  end

  BLL:Print(BLL.L["TIP_HINT"])
end

------------------------------------------------------------------
-- Stats zweier Items vergleichen -> Differenztabelle
------------------------------------------------------------------

function Scanner:Diff(itemA, itemB)
  local a = self:GetStats(itemA) or {}
  local b = self:GetStats(itemB) or {}
  local diff = {}

  for k, v in pairs(a) do diff[k] = (diff[k] or 0) + v end
  for k, v in pairs(b) do diff[k] = (diff[k] or 0) - v end

  -- Nulldifferenzen entfernen
  for k, v in pairs(diff) do
    if v == 0 then diff[k] = nil end
  end
  return diff
end
