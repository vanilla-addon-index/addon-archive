-- Freewood-OctoWoW-Core: Hilfsfunktionen
-- Kopieren/Zusammenfuehren von Tabellen, Geld, Items (asynchron), Pruefsumme,
-- NPC-ID aus GUID, Spielerposition.

local ADDON, FW = ...

local Util = {}
FW.Util = Util

------------------------------------------------------------------------
-- Tabellen
------------------------------------------------------------------------

function Util.CopyTable(src, seen)
    if type(src) ~= "table" then
        return src
    end
    seen = seen or {}
    if seen[src] then
        return seen[src]
    end
    local dst = {}
    seen[src] = dst
    for k, v in pairs(src) do
        dst[k] = Util.CopyTable(v, seen)
    end
    return dst
end

-- Geheime Werte (secret values): das Spiel gibt manche Angaben, vor allem zu fremden Einheiten,
-- als "geheimen" Wert zurueck. Damit darf Addon-Code nichts rechnen, vergleichen oder indizieren.
function Util.IsSecret(v)
    local fn = _G.issecretvalue
    if type(fn) == "function" then
        local ok, res = pcall(fn, v)
        return ok and res and true or false
    end
    return false
end

-- Gibt v zurueck, aber nil, wenn der Wert geheim ist
function Util.Clean(v)
    if Util.IsSecret(v) then
        return nil
    end
    return v
end

-- Ergaenzt fehlende Schluessel in target aus defaults. Vorhandene Werte bleiben.
function Util.MergeDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then
                target[k] = Util.CopyTable(v)
            else
                Util.MergeDefaults(target[k], v)
            end
        elseif target[k] == nil then
            target[k] = v
        end
    end
    return target
end

function Util.Count(t)
    local n = 0
    for _ in pairs(t) do
        n = n + 1
    end
    return n
end

------------------------------------------------------------------------
-- Zahlen und Geld
------------------------------------------------------------------------

function Util.Round(n, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor(n * mult + 0.5) / mult
end

function Util.Clamp(n, lo, hi)
    if n < lo then
        return lo
    end
    if n > hi then
        return hi
    end
    return n
end

function Util.FormatNumber(n)
    local text = string.format("%.0f", math.floor(math.abs(n) + 0.5))
    local sep = (FW.activeLocale == "deDE") and "." or ","
    local count
    repeat
        text, count = text:gsub("^(%d+)(%d%d%d)", "%1" .. sep .. "%2")
    until count == 0
    if n < 0 then
        text = "-" .. text
    end
    return text
end

local MONEY_COLORS = { g = "f0bf5c", s = "c4c8d0", c = "c8793c" }

-- Kupfer -> "12G 34S 56K". opts.plain: ohne Farben, opts.noCopper: Kupfer weglassen
function Util.FormatMoney(copper, opts)
    opts = opts or {}
    copper = tonumber(copper) or 0
    local negative = copper < 0
    if negative then
        copper = -copper
    end
    copper = math.floor(copper)

    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local rest = copper % 100
    local L = FW.L

    local function unit(key, symbol)
        if opts.plain then
            return symbol
        end
        return "|cff" .. MONEY_COLORS[key] .. symbol .. "|r"
    end

    local parts = {}
    if gold > 0 then
        parts[#parts + 1] = Util.FormatNumber(gold) .. unit("g", L.MONEY_G)
    end
    if silver > 0 then
        parts[#parts + 1] = silver .. unit("s", L.MONEY_S)
    end
    if rest > 0 and not (opts.noCopper and gold > 0) then
        parts[#parts + 1] = rest .. unit("c", L.MONEY_C)
    end
    if #parts == 0 then
        parts[1] = "0" .. unit("c", L.MONEY_C)
    end

    local text = table.concat(parts, " ")
    if negative then
        text = "-" .. text
    end
    return text
end

------------------------------------------------------------------------
-- Pruefsumme (Adler-32-Variante, nur Rechnen mit kleinen Zahlen)
------------------------------------------------------------------------

function Util.Hash(text)
    local a, b = 1, 0
    for i = 1, #text do
        a = (a + text:byte(i)) % 65521
        b = (b + a) % 65521
    end
    return string.format("%04x%04x", b, a)
end

------------------------------------------------------------------------
-- Items (mit asynchronem Nachladen)
------------------------------------------------------------------------

local function RawItemInfo(idOrLink)
    if C_Item and C_Item.GetItemInfo then
        return C_Item.GetItemInfo(idOrLink)
    end
    return GetItemInfo(idOrLink)
end

-- Liefert eine Tabelle oder nil, wenn die Daten noch nicht im Cache sind.
function Util.GetItem(idOrLink)
    local name, link, quality, itemLevel, minLevel, itemType, itemSubType,
        stackCount, equipLoc, icon, sellPrice, classID, subClassID = RawItemInfo(idOrLink)
    if not name then
        return nil
    end
    local id = tonumber(idOrLink)
    if not id and type(link) == "string" then
        id = tonumber(link:match("item:(%d+)"))
    end
    return {
        id = id,
        name = name,
        link = link,
        quality = quality or 1,
        itemLevel = itemLevel,
        minLevel = minLevel,
        type = itemType,
        subType = itemSubType,
        stackCount = stackCount,
        equipLoc = equipLoc,
        icon = icon,
        sellPrice = sellPrice or 0,
        classID = classID,
        subClassID = subClassID,
    }
end

local pendingItems = {}      -- itemID -> Liste der wartenden Callbacks
local itemQueue = {}         -- noch nicht gesendete Anfragen (Reihenfolge)
local itemQueueHead = 1
local itemSent = {}          -- itemID -> true, wenn gesendet und noch offen
local itemOut = 0            -- Zahl offener, gesendeter Anfragen
local itemFailed = {}        -- itemID -> true, Zeitueberschreitung (wird am Ende nochmal versucht)
local itemFailedList = {}
local itemRetried = {}
local ITEM_TIMEOUT = 5       -- Sekunden ohne Antwort = nicht ladbar
local ITEM_MAX_OUT = 50      -- so viele Anfragen gleichzeitig offen
Util.ITEM_TIMEOUT = ITEM_TIMEOUT

local PumpItems

local function ItemFinish(itemID, info)
    local list = pendingItems[itemID]
    if itemSent[itemID] then
        itemSent[itemID] = nil
        itemOut = math.max(0, itemOut - 1)
    end
    pendingItems[itemID] = nil
    if list then
        for _, callback in ipairs(list) do
            FW.SafeCall(callback, info)
        end
    end
end

-- Zweiter Versuch fuer alles, was keine Antwort bekam: erst wenn die Warteschlange leer ist.
local function RetryFailed()
    if itemQueueHead <= #itemQueue or itemOut > 0 then
        return
    end
    local todo = {}
    for _, id in ipairs(itemFailedList) do
        if itemFailed[id] and not itemRetried[id] then
            itemRetried[id] = true
            todo[#todo + 1] = id
        end
    end
    itemFailedList = {}
    for _, id in ipairs(todo) do
        itemFailed[id] = nil
        Util.RequestItem(id, function(info)
            if info and FW.Fire then FW:Fire("CODEX_ITEMS_LOADED") end
        end)
    end
end

function PumpItems()
    while itemOut < ITEM_MAX_OUT and itemQueueHead <= #itemQueue do
        local id = itemQueue[itemQueueHead]
        itemQueueHead = itemQueueHead + 1
        if pendingItems[id] and not itemSent[id] then
            if Util.GetItem(id) then
                ItemFinish(id, Util.GetItem(id))
            else
                itemSent[id] = true
                itemOut = itemOut + 1
                if C_Item and C_Item.RequestLoadItemDataByID then
                    C_Item.RequestLoadItemDataByID(id)
                end
                if C_Timer and C_Timer.After then
                    C_Timer.After(ITEM_TIMEOUT, function()
                        if itemSent[id] then
                            if not itemFailed[id] then
                                itemFailed[id] = true
                                itemFailedList[#itemFailedList + 1] = id
                            end
                            ItemFinish(id, nil)
                            PumpItems()
                        end
                    end)
                end
            end
        end
    end
    if itemQueueHead > #itemQueue then
        itemQueue = {}
        itemQueueHead = 1
        if itemOut == 0 and #itemFailedList > 0 and C_Timer and C_Timer.After then
            C_Timer.After(1, RetryFailed)
        end
    end
end

-- Ruft callback(info) auf, sobald die Item-Daten da sind (sofort, falls schon im Cache).
-- info ist nil, wenn das Item nicht geladen werden konnte (nach ITEM_TIMEOUT Sekunden ohne Antwort).
-- Anfragen laufen gestaffelt: schnelle Antworten zuerst, Ausfaelle werden zum Schluss einmal wiederholt.
function Util.RequestItem(itemID, callback)
    local info = Util.GetItem(itemID)
    if info then
        FW.SafeCall(callback, info)
        return
    end
    local list = pendingItems[itemID]
    if not list then
        list = {}
        pendingItems[itemID] = list
        itemQueue[#itemQueue + 1] = itemID
    end
    list[#list + 1] = callback
    PumpItems()
end

FW:RegisterEvent("GET_ITEM_INFO_RECEIVED", function(itemID, success)
    if not pendingItems[itemID] then
        return
    end
    itemFailed[itemID] = nil
    ItemFinish(itemID, success and Util.GetItem(itemID) or nil)
    PumpItems()
end)

------------------------------------------------------------------------
-- Kreaturen und Orte
------------------------------------------------------------------------

-- GUID "Creature-0-4621-1-27730-4107-0000477262" -> 4107 (sechstes Feld)
-- Octo/1.12: GUID als Hex "0xF130003A5C0012AB" = Typ (F13 Kreatur, F14 Begleiter,
-- F11 Objekt, F15 Fahrzeug), Eintrags-ID (6 Hex), Zaehler (6 Hex).
-- Rueckgabe: "Creature" / "Pet" / "GameObject" / "Vehicle", ID; sonst nil.
local HEX_KIND = { F13 = "Creature", F14 = "Pet", F11 = "GameObject", F15 = "Vehicle" }
function Util.ParseHexGUID(guid)
    if type(guid) ~= "string" then
        return nil
    end
    local hex = guid:match("^0[xX](%x+)$")
    if not hex or #hex ~= 16 then
        return nil
    end
    local kind = HEX_KIND[hex:sub(1, 3):upper()]
    if not kind then
        return nil
    end
    return kind, tonumber(hex:sub(5, 10), 16)
end

function Util.GetNpcID(guid)
    if type(guid) ~= "string" then
        return nil
    end
    local hk, hid = Util.ParseHexGUID(guid)
    if hk then
        if hk == "Creature" or hk == "Vehicle" then
            return hid
        end
        return nil
    end
    local kind, _, _, _, _, id = strsplit("-", guid)
    if kind == "Creature" or kind == "Vehicle" then
        return tonumber(id)
    end
    return nil
end

-- Aktuelle Position des Spielers. x und y sind 0..1 auf der Karte, koennen
-- in Instanzen fehlen. Die Koordinaten sind die des Spielers, nicht des Ziels.
function Util.GetPlayerLocation()
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local x, y
    if mapID then
        local pos = C_Map.GetPlayerMapPosition(mapID, "player")
        if pos then
            x, y = pos:GetXY()
        end
    end
    return {
        mapID = mapID,
        x = x and Util.Round(x, 4) or nil,
        y = y and Util.Round(y, 4) or nil,
        zone = GetZoneText(),
        subzone = GetSubZoneText(),
        t = time(),
    }
end

function Util.GetPlayerKey()
    local name = UnitName("player")
    local realm = GetRealmName() or ""
    return name .. "-" .. (realm:gsub("%s", ""))
end
