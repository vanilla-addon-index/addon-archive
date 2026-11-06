-- Freewood-OctoWoW-Beasts: Archiv wilder Tiere
-- Lernt beim Spielen (anvisieren, Wildtierkunde, Zaehmen), kennt optional Startdaten
-- aus Freewood-OctoWoW-BeastsData und teilt eigene Funde per Export/Import.
--
-- Eigene Eintraege (db.beasts[npcID]):
--   name, fid (Familien-ID), family (Text aus dem Spiel), lvl1, lvl2, c (Klassifizierung),
--   zone, tameable, diet (Kuerzel mfcbur), seen, lored, tamed, tamedAt, firstSeen, updated,
--   grid = { [Karte] = { [Zellen-Nr] = Anzahl } } (Raster 200 x 200, Zelle = 0,5 % der Karte),
--   petAbilities = { {name, rank, spellID, passive} },
--   extra = { "Zeile aus Wildtierkunde" }
-- Importierte Eintraege liegen getrennt in db.imported[npcID] und ueberschreiben nie eigene Daten.

local ADDON, NS = ...

local FW = _G.Freewood
if not FW or not FW:RequireAPI(1, ADDON) then
    return
end

local Util = FW.Util
local L = FW.L
local Pet = FW.Pet
if not Pet then
    return
end

local GRID = 200            -- Raster: 200 x 200 Zellen pro Karte (Zelle = 0,5 %)
local MAX_CELLS = 800       -- hoechstens so viele verschiedene Zellen pro Tier
local MAX_EXTRA = 8
local MAX_PETABIL = 60
local MAX_IMPORT = 500
local STAY_INTERVAL = 10    -- Sekunden: in derselben Zelle erst danach erneut zaehlen
local LORE_INTERVAL = 4     -- Sekunden zwischen zwei Tooltip-Auslesungen pro Tier

local DIET_ORDER = "mfcbur"

local FOOD_ALIASES = {
    m = { "fleisch", "meat" },
    f = { "fisch", "fish" },
    c = { "käse", "kaese", "cheese" },
    b = { "brot", "bread" },
    u = { "fungus", "pilz", "pilze", "mushroom" },
    r = { "obst", "frucht", "früchte", "fruit" },
}
local FOOD_BY_NAME = {}
for code, names in pairs(FOOD_ALIASES) do
    for _, n in ipairs(names) do
        FOOD_BY_NAME[n] = code
    end
end

local function GetMeta(field)
    local fn = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    if fn then
        local ok, value = pcall(fn, ADDON, field)
        if ok then
            return value
        end
    end
    return nil
end

local Beasts = FW:NewModule("Beasts", {
    version = GetMeta("Version") or "dev",
    title = L.BEAST_TITLE,
    description = L.BEAST_DESC,
    defaults = {
        beasts = {}, imported = {}, relay = {}, familyNames = {},
        settings = { seed = true, mapPower = 1.0, share = { guild = false, party = false, raid = false, global = false }, people = {} },
        sync = { have = {}, sent = 0, received = 0 },
    },
})
NS.Beasts = Beasts
FW.Beasts = Beasts

local function Now()
    return (GetTime and GetTime()) or time()
end

local function Num(v, lo, hi)
    if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then
        if lo and v < lo then
            return nil
        end
        if hi and v > hi then
            return nil
        end
        return v
    end
    return nil
end

local function Str(v, max)
    if type(v) ~= "string" then
        return nil
    end
    v = v:gsub("[%c]", " ")
    if v == "" then
        return nil
    end
    return v:sub(1, max or 64)
end

------------------------------------------------------------------------
-- Nahrung
------------------------------------------------------------------------

-- Liste von Texten ("Fleisch", "Fisch") in Kuerzel ("mf"), Reihenfolge fest
function Beasts.FoodsToCodes(list)
    local have = {}
    for _, text in ipairs(list or {}) do
        if type(text) == "string" then
            local code = FOOD_BY_NAME[string.lower((text:gsub("^%s+", ""):gsub("%s+$", "")))]
            if code then
                have[code] = true
            end
        end
    end
    local out = {}
    for i = 1, #DIET_ORDER do
        local c = DIET_ORDER:sub(i, i)
        if have[c] then
            out[#out + 1] = c
        end
    end
    return table.concat(out)
end

local function CleanDiet(v)
    if type(v) ~= "string" then
        return nil
    end
    local out = {}
    for i = 1, #DIET_ORDER do
        local c = DIET_ORDER:sub(i, i)
        if v:find(c, 1, true) then
            out[#out + 1] = c
        end
    end
    if #out == 0 then
        return nil
    end
    return table.concat(out)
end

------------------------------------------------------------------------
-- Startdaten
------------------------------------------------------------------------

function Beasts:SeedNpcs()
    local seed = _G.FreewoodBeastsSeed
    return seed and seed.npcs or nil
end

function Beasts:HasSeed()
    return self:SeedNpcs() ~= nil
end

function Beasts:SeedEnabled()
    return self.db.settings.seed ~= false and self:HasSeed()
end

function Beasts:SeedEntry(id)
    if not self:SeedEnabled() then
        return nil
    end
    return self:SeedNpcs()[id]
end

function Beasts:SetSeedEnabled(on)
    self.db.settings.seed = on and true or false
    self.index = nil
    FW:Fire("BEASTS_UPDATED")
end

------------------------------------------------------------------------
-- Karten- und Gebietsnamen
------------------------------------------------------------------------

local mapNames, areaNames = {}, {}

function Beasts.MapName(mapID)
    if not mapID then
        return nil
    end
    local cached = mapNames[mapID]
    if cached ~= nil then
        return cached or nil
    end
    local name
    if C_Map and C_Map.GetMapInfo then
        local ok, info = pcall(C_Map.GetMapInfo, mapID)
        if ok and info then
            name = info.name
        end
    end
    mapNames[mapID] = name or false
    return name
end

function Beasts.AreaName(areaID)
    if not areaID then
        return nil
    end
    local cached = areaNames[areaID]
    if cached ~= nil then
        return cached or nil
    end
    local name
    if C_Map and C_Map.GetAreaInfo then
        local ok, value = pcall(C_Map.GetAreaInfo, areaID)
        if ok then
            name = value
        end
    end
    areaNames[areaID] = name or false
    return name
end

------------------------------------------------------------------------
-- Eigene Eintraege
------------------------------------------------------------------------

Beasts.GRID = GRID

local function CellIndex(x, y)
    local cx = math.min(GRID - 1, math.max(0, math.floor(x * GRID)))
    local cy = math.min(GRID - 1, math.max(0, math.floor(y * GRID)))
    return cy * GRID + cx
end

local function GridCount(grid)
    local n = 0
    if type(grid) == "table" then
        for _, cells in pairs(grid) do
            for _ in pairs(cells) do
                n = n + 1
            end
        end
    end
    return n
end

-- Eine Sichtung in die Zelle eintragen. Rueckgabe: true wenn die Zelle neu ist.
local function AddSighting(e, m, idx, amount)
    e.grid = e.grid or {}
    local cells = e.grid[m]
    if not cells then
        cells = {}
        e.grid[m] = cells
    end
    local n = cells[idx]
    if n then
        cells[idx] = math.min(65535, n + (amount or 1))
        return false
    end
    if GridCount(e.grid) >= MAX_CELLS then
        return false
    end
    cells[idx] = math.min(65535, amount or 1)
    return true
end

-- Raster als Liste { {m, x, y, n} } (x,y = Zellen 0..199), haeufigste zuerst
local function FlattenGrid(grid)
    local list = {}
    for m, cells in pairs(grid or {}) do
        for idx, n in pairs(cells) do
            list[#list + 1] = { m = m, x = idx % GRID, y = math.floor(idx / GRID), n = n }
        end
    end
    table.sort(list, function(a, b)
        if a.n ~= b.n then
            return a.n > b.n
        end
        if a.m ~= b.m then
            return a.m < b.m
        end
        if a.y ~= b.y then
            return a.y < b.y
        end
        return a.x < b.x
    end)
    while #list > MAX_CELLS do
        list[#list] = nil
    end
    return list
end

function Beasts:Touch(id)
    local e = self.db.beasts[id]
    if not e then
        e = { firstSeen = time(), updated = time() }
        self.db.beasts[id] = e
        self.isNew = true
    end
    return e
end

-- Kurze Pruefsumme der wichtigen Felder: nur bei Aenderung wird neu gezeichnet und "updated" gesetzt
local function Signature(e)
    local abil = 0
    for _, a in ipairs(e.petAbilities or {}) do
        abil = abil + (a.rank or 0) + 1
    end
    return table.concat({
        tostring(e.name), tostring(e.fid), tostring(e.family), tostring(e.lvl1), tostring(e.lvl2), tostring(e.c),
        tostring(e.zone), tostring(e.seen), tostring(e.lored), tostring(e.tameable), tostring(e.tamed),
        tostring(e.diet), GridCount(e.grid), e.extra and #e.extra or 0, abil,
    }, "|")
end

function Beasts:Commit(id, e, before)
    if Signature(e) ~= before then
        e.updated = time()
        self.index = nil
        FW:Fire("BEASTS_UPDATED", id)
        return true
    end
    return false
end

local function PlayerPoint()
    local loc = Util.GetPlayerLocation()
    if loc and loc.mapID and loc.x and loc.y then
        return loc.mapID, loc.x, loc.y, loc.zone
    end
    return nil, nil, nil, loc and loc.zone
end

local function CleanLine(text)
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Liest den Tooltip einer Einheit. Rueckgabe: nil oder
-- { tameable=bool, diet="mf"|nil, extra={...} } (nur wenn Wildtierkunde-Zeilen da sind)
function Beasts:ReadLore(unit, name)
    if not (C_TooltipInfo and C_TooltipInfo.GetUnit) then
        return nil
    end
    local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then
        return nil
    end
    local info = { extra = {} }
    local found = false
    local level = UnitLevel and Util.Clean(UnitLevel(unit))
    if type(level) ~= "number" then
        level = nil
    end
    local typeLow = UnitCreatureType and Util.Clean(UnitCreatureType(unit))
    typeLow = type(typeLow) == "string" and string.lower(typeLow) or nil
    for i, line in ipairs(data.lines) do
        local text = type(line) == "table" and Util.Clean(line.leftText)
        if type(text) == "string" and i > 1 then
            text = CleanLine(text)
            local low = string.lower(text)
            if text == "" or text == name then
                -- nichts
            elseif low == "wildtier" or low == "beast" or (typeLow and low == typeLow) then
                -- Typzeile
            elseif low == "zähmbar" or low == "zaehmbar" or low == "tameable" then
                info.tameable = true
                found = true
            elseif low:find("^ernährung:") or low:find("^ernaehrung:") or low:find("^diet:") then
                local rest = text:match(":%s*(.+)$") or ""
                local foods = {}
                for part in rest:gmatch("[^,]+") do
                    foods[#foods + 1] = part
                end
                local codes = Beasts.FoodsToCodes(foods)
                if codes ~= "" then
                    info.diet = codes
                end
                found = true
            elseif low:find("^spezialisierung:") or low:find("^specialization:") then
                found = true
            elseif low:find("^stufe") or low:find("^level") or (level and level > 0 and low:find(tostring(level), 1, true) and low:find("%d")) then
                -- Stufenzeile
            elseif #info.extra < MAX_EXTRA then
                info.extra[#info.extra + 1] = text:sub(1, 120)
            end
        end
    end
    if not found then
        return nil
    end
    return info
end

local function AddExtra(e, lines)
    if not lines or #lines == 0 then
        return
    end
    e.extra = e.extra or {}
    for _, line in ipairs(lines) do
        local dup = false
        for _, have in ipairs(e.extra) do
            if have == line then
                dup = true
                break
            end
        end
        if not dup and #e.extra < MAX_EXTRA then
            e.extra[#e.extra + 1] = line
        end
    end
end

-- Einheit beobachten und ins Archiv uebernehmen
-- Rueckgabe: true, wenn die Einheit ein Wildtier fuers Archiv ist
-- Geheime Werte (secret values) fuehren zum Abbruch ohne Fehlermeldung.
function Beasts:Observe(unit)
    local ok, result = pcall(self.ObserveImpl, self, unit)
    if ok then
        return result and true or false
    end
    return false
end

function Beasts:ObserveImpl(unit)
    if Util.IsSecret(unit) or not UnitExists(unit) then
        return false
    end
    local isPlayer, controlled = UnitIsPlayer(unit), UnitPlayerControlled(unit)
    if Util.IsSecret(isPlayer) or Util.IsSecret(controlled) or isPlayer or controlled then
        return false
    end
    local guid = Util.Clean(UnitGUID(unit))
    if type(guid) ~= "string" then
        return false
    end
    -- Octo/1.12: GUID ist ein Hex-String (0xF130...), nicht "Creature-..."
    local hexKind = Util.ParseHexGUID(guid)
    if hexKind then
        if hexKind ~= "Creature" then
            return false
        end
    elseif not guid:find("^Creature") then
        return false
    end
    local id = Util.GetNpcID(guid)
    if not id then
        return false
    end

    local family = UnitCreatureFamily and Util.Clean(UnitCreatureFamily(unit))
    if family == "" then
        family = nil
    end
    local known = self.db.beasts[id] ~= nil
    local inSeed = self:SeedNpcs() and self:SeedNpcs()[id] ~= nil
    local name = Util.Clean(UnitName(unit))

    local lore
    local now = Now()
    local last = self.loreAt[id]
    if (family or known or inSeed) and (not last or now - last >= LORE_INTERVAL) then
        self.loreAt[id] = now
        lore = self:ReadLore(unit, name)
    end

    if not (family or inSeed or known or lore) then
        return false
    end

    local e = self:Touch(id)
    local wasNew = self.isNew
    self.isNew = nil
    local before = wasNew and "" or Signature(e)

    e.name = Str(name, 64) or e.name
    e.seen = true
    e.lastSeen = time()
    if family then
        e.family = Str(family, 48)
        local fid = Pet.GetFamilyID(family)
        if fid then
            e.fid = fid
            self.db.familyNames[fid] = e.family
        end
    end
    local lvl = UnitLevel and Util.Clean(UnitLevel(unit))
    if type(lvl) == "number" and lvl > 0 then
        e.lvl1 = (e.lvl1 and math.min(e.lvl1, lvl)) or lvl
        e.lvl2 = (e.lvl2 and math.max(e.lvl2, lvl)) or lvl
    end
    local class = UnitClassification and Util.Clean(UnitClassification(unit))
    if type(class) == "string" and class ~= "normal" and class ~= "trivial" and class ~= "minus" then
        e.c = class
    end

    local m, x, y, zone = PlayerPoint()
    if zone and zone ~= "" then
        e.zone = Str(zone, 64)
    end
    if m and x and y then
        local idx = CellIndex(x, y)
        local key = m * GRID * GRID + idx
        local lastAt = self.trackAt[id]
        if self.lastCell[id] ~= key or not lastAt or now - lastAt >= STAY_INTERVAL then
            self.lastCell[id] = key
            self.trackAt[id] = now
            AddSighting(e, m, idx)
        end
    end

    if lore then
        e.lored = true
        if lore.tameable then
            e.tameable = true
        end
        if lore.diet then
            e.diet = lore.diet
        end
        AddExtra(e, lore.extra)
    end

    if self:Commit(id, e, before) and wasNew then
        FW:Debug(string.format(FW.L.BEAST_LEARNED, e.name or tostring(id)))
    end
    return true
end

-- Solange ein Wildtier im Ziel ist, jede Sekunde die Position festhalten
function Beasts:StartTracking()
    if self.tracking then
        return
    end
    self.tracking = true
    local function tick()
        if not Beasts:IsEnabled() or not UnitExists("target") or not Beasts:Observe("target") then
            Beasts.tracking = false
            return
        end
        C_Timer.After(1, tick)
    end
    C_Timer.After(1, tick)
end

-- Begleiter wurde erfasst: das Tier gilt als gezaehmt, Zauberbuch wird mitgenommen
function Beasts:OnPetUpdated(key, rec)
    if type(rec) ~= "table" or rec.src == "import" or not rec.npcID or key ~= Pet.activeKey then
        return
    end
    local e = self:Touch(rec.npcID)
    local before = self.isNew and "" or Signature(e)
    self.isNew = nil
    e.tamed = true
    e.tameable = true
    e.tamedAt = e.tamedAt or time()
    if type(rec.family) == "string" and rec.family ~= "" then
        e.family = Str(rec.family, 48)
        local fid = Pet.GetFamilyID(rec.family)
        if fid then
            e.fid = fid
            self.db.familyNames[fid] = e.family
        end
    end
    if type(rec.foods) == "table" and #rec.foods > 0 then
        local codes = Beasts.FoodsToCodes(rec.foods)
        if codes ~= "" then
            e.diet = codes
        end
    end
    local list = {}
    for _, a in ipairs(rec.abilities or {}) do
        if #list >= MAX_PETABIL then
            break
        end
        if type(a) == "table" and type(a.name) == "string" then
            list[#list + 1] = { name = a.name, rank = a.rank, spellID = a.spellID, passive = a.passive and true or nil }
        end
    end
    if #list > 0 then
        e.petAbilities = list
    end
    self:Commit(rec.npcID, e, before)
end

------------------------------------------------------------------------
-- Zusammengefuehrte Sicht (eigen, Import, Startdaten)
------------------------------------------------------------------------

function Beasts.StatusOf(own, imp)
    local tamed = (own and own.tamed) or (imp and imp.tamed)
    local lored = (own and own.lored) or (imp and imp.lored)
    if tamed then
        return "tamed"
    elseif lored then
        return "lored"
    elseif own or imp then
        return "seen"
    end
    return "unknown"
end

local function SeedZone(seed)
    if not seed then
        return nil
    end
    return Beasts.MapName(seed.m) or Beasts.AreaName(seed.a)
end

function Beasts:FamilyText(fid, fallback)
    if not fid then
        return fallback
    end
    return self.db.familyNames[fid] or Pet.FamilyDisplay(fid)
end

function Beasts:Summary(id)
    local own, imp, seed = self.db.beasts[id], self.db.imported[id], self:SeedEntry(id)
    local fid = (own and own.fid) or (imp and imp.fid) or (seed and seed.f ~= "" and seed.f) or nil
    local familyText = (own and own.family) or (imp and imp.family)
    local s = {
        id = id,
        own = own, imp = imp, seed = seed,
        name = (own and own.name) or (imp and imp.name) or (seed and seed.n) or string.format(FW.L.BEAST_UNNAMED, id),
        fid = fid,
        status = Beasts.StatusOf(own, imp),
        zone = (own and own.zone) or (imp and imp.zone) or SeedZone(seed),
        lvl1 = (own and own.lvl1) or (imp and imp.lvl1) or (seed and seed.l and seed.l[1]),
        lvl2 = (own and own.lvl2) or (imp and imp.lvl2) or (seed and seed.l and seed.l[2]),
        c = (own and own.c) or (imp and imp.c) or (seed and seed.c),
        diet = (own and own.diet) or (imp and imp.diet) or (seed and seed.d ~= "" and seed.d) or nil,
        tameable = (own and own.tameable) or (imp and imp.tameable) or (seed and true) or nil,
    }
    s.family = (own and own.family) or self:FamilyText(fid, familyText)
    s.sortName = string.lower(s.name)
    return s
end

-- Alle Eintraege als Liste (ohne Filter), nach Namen sortiert
function Beasts:Index()
    if self.index then
        return self.index
    end
    local ids = {}
    for id in pairs(self.db.beasts) do
        ids[id] = true
    end
    for id in pairs(self.db.imported) do
        ids[id] = true
    end
    local seed = self:SeedEnabled() and self:SeedNpcs()
    if seed then
        for id in pairs(seed) do
            ids[id] = true
        end
    end
    local list = {}
    for id in pairs(ids) do
        list[#list + 1] = self:Summary(id)
    end
    table.sort(list, function(a, b)
        if a.sortName ~= b.sortName then
            return a.sortName < b.sortName
        end
        return a.id < b.id
    end)
    self.index = list
    return list
end

-- Filter: { text, fid, zone, status }
-- Name und Rang (Zahl) eines Zaubers aus den Spieldaten; nil, wenn noch nicht bekannt
function Beasts.SpellInfo(spellID)
    local name, rank
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and type(info) == "table" then
            name = info.name
        end
    end
    if C_Spell and C_Spell.GetSpellSubtext then
        local ok, text = pcall(C_Spell.GetSpellSubtext, spellID)
        if ok and type(text) == "string" then
            rank = tonumber(string.match(text, "(%d+)"))
        end
    end
    return name, rank or 0
end

-- Faehigkeiten, die ein Tier beim Zaehmen lehrt (Startdaten) bzw. die sein Begleiter hat:
-- { [name] = { [rang] = true } } plus Hoechstrang; im Eintrag zwischengespeichert, sobald alle Namen bekannt sind
function Beasts:Abilities(s)
    if s.abil then
        return s.abil
    end
    local map, complete = {}, true
    local function add(name, rank)
        local e = map[name]
        if not e then
            e = { ranks = {}, max = 0 }
            map[name] = e
        end
        e.ranks[rank] = true
        if rank > e.max then
            e.max = rank
        end
    end
    if s.seed and s.seed.t then
        for _, spellID in ipairs(s.seed.t) do
            local name, rank = Beasts.SpellInfo(spellID)
            if name then
                add(name, rank)
            else
                complete = false
            end
        end
    end
    local pa = (s.own and s.own.petAbilities) or (s.imp and s.imp.petAbilities)
    for _, a in ipairs(pa or {}) do
        if a.name then
            add(a.name, tonumber(a.rank) or 0)
        end
    end
    if complete then
        s.abil = map
    end
    return map
end

-- filter: text, fid, zone, status, ability (Name), rank (Zahl), rankMin (true = "ab diesem Rang")
-- Zweiter Rueckgabewert: Zahl der Tiere ohne Faehigkeitsdaten (nur bei Faehigkeitsfilter)
function Beasts:Filtered(filter)
    local out = {}
    local missing = 0
    local text = filter.text and filter.text ~= "" and string.lower(filter.text) or nil
    for _, s in ipairs(self:Index()) do
        local ok = true
        if filter.fid and s.fid ~= filter.fid then
            ok = false
        elseif filter.zone and s.zone ~= filter.zone then
            ok = false
        elseif filter.status and s.status ~= filter.status then
            ok = false
        elseif text then
            local hay = s.sortName .. " " .. string.lower(s.family or "") .. " " .. string.lower(s.zone or "")
            if not hay:find(text, 1, true) then
                ok = false
            end
        end
        if ok and filter.ability then
            local abil = self:Abilities(s)
            if not next(abil) then
                missing = missing + 1
                ok = false
            else
                local e = abil[filter.ability]
                if not e then
                    ok = false
                elseif filter.rank then
                    if filter.rankMin then
                        ok = e.max >= filter.rank
                    else
                        ok = e.ranks[filter.rank] == true
                    end
                end
            end
        end
        if ok then
            out[#out + 1] = s
        end
    end
    return out, missing
end

-- Alle Faehigkeiten (Namen, sortiert) und die Raenge einer Faehigkeit
function Beasts:AbilityChoices()
    local names, seen = {}, {}
    for _, s in ipairs(self:Index()) do
        for name in pairs(self:Abilities(s)) do
            if not seen[name] then
                seen[name] = true
                names[#names + 1] = name
            end
        end
    end
    table.sort(names)
    return names
end

function Beasts:AbilityRanks(name)
    local ranks, seen = {}, {}
    for _, s in ipairs(self:Index()) do
        local e = self:Abilities(s)[name]
        if e then
            for r in pairs(e.ranks) do
                if r > 0 and not seen[r] then
                    seen[r] = true
                    ranks[#ranks + 1] = r
                end
            end
        end
    end
    table.sort(ranks)
    return ranks
end

-- Familien und Gebiete, die im Index vorkommen (fuer die Auswahllisten)
function Beasts:FilterChoices()
    local fams, zones, famSeen, zoneSeen = {}, {}, {}, {}
    for _, s in ipairs(self:Index()) do
        if s.fid and not famSeen[s.fid] then
            famSeen[s.fid] = true
            fams[#fams + 1] = { id = s.fid, text = self:FamilyText(s.fid) }
        end
        if s.zone and not zoneSeen[s.zone] then
            zoneSeen[s.zone] = true
            zones[#zones + 1] = s.zone
        end
    end
    table.sort(fams, function(a, b)
        return a.text < b.text
    end)
    table.sort(zones)
    return fams, zones
end

-- Fundorte gruppiert nach Karte: { {mapID, name, own={ {x,y,n} }, imp={...}, seed={ {x,y} }} }
-- x,y in Zehntel-Prozent (0..1000)
function Beasts:Locations(s)
    local groups, order = {}, {}
    local function group(m)
        local g = groups[m]
        if not g then
            g = { mapID = m, name = Beasts.MapName(m) or ("Map " .. tostring(m)), own = {}, imp = {}, seed = {} }
            groups[m] = g
            order[#order + 1] = g
        end
        return g
    end
    local function addGrid(entry, key)
        for m, cells in pairs(entry and entry.grid or {}) do
            local g = group(m)
            for idx, n in pairs(cells) do
                g[key][#g[key] + 1] = { (idx % GRID) * 5 + 2.5, math.floor(idx / GRID) * 5 + 2.5, n }
            end
            table.sort(g[key], function(a, b)
                if a[3] ~= b[3] then
                    return a[3] > b[3]
                end
                if a[2] ~= b[2] then
                    return a[2] < b[2]
                end
                return a[1] < b[1]
            end)
        end
    end
    addGrid(s.own, "own")
    addGrid(s.imp, "imp")
    if s.seed and s.seed.m and s.seed.p then
        local g = group(s.seed.m)
        for i = 1, #s.seed.p - 1, 2 do
            g.seed[#g.seed + 1] = { s.seed.p[i], s.seed.p[i + 1] }
        end
    end
    table.sort(order, function(a, b)
        local ca = #a.own + #a.imp + #a.seed
        local cb = #b.own + #b.imp + #b.seed
        if ca ~= cb then
            return ca > cb
        end
        return a.name < b.name
    end)
    return order
end

-- Gewichte pro Rasterzelle fuer eine Karte, ueber mehrere Tiere (ids = { [npcID] = true })
-- Rueckgabe: { [Zellen-Nr] = Gewicht }
function Beasts:MapWeights(ids, mapID)
    local weights = {}
    local function add(idx, w)
        weights[idx] = (weights[idx] or 0) + w
    end
    for id in pairs(ids) do
        local own, imp, seed = self.db.beasts[id], self.db.imported[id], self:SeedEntry(id)
        local oc = own and own.grid and own.grid[mapID]
        if oc then
            for idx, n in pairs(oc) do
                add(idx, 2 + math.min(n, 8) * 0.25)
            end
        end
        local ic = imp and imp.grid and imp.grid[mapID]
        if ic then
            for idx, n in pairs(ic) do
                add(idx, 1.5 + math.min(n, 8) * 0.15)
            end
        end
        if seed and seed.m == mapID and seed.p then
            for i = 1, #seed.p - 1, 2 do
                local cx = math.min(GRID - 1, math.floor(seed.p[i] / 1000 * GRID))
                local cy = math.min(GRID - 1, math.floor(seed.p[i + 1] / 1000 * GRID))
                add(cy * GRID + cx, 1)
            end
        end
    end
    return weights
end

-- Punkte fuer die Codex-Karte (wie "Auf Karte zeigen" in der Datenbank):
-- { {m, x, y, n, name, k}, ... } mit x, y als Anteil 0..1; ids = { [npcID] = true }
local MAP_POINTS_MAX = 3000
function Beasts:MapPoints(ids)
    local pts = {}
    for id in pairs(ids) do
        local sum = self:Summary(id)
        local name = (sum and sum.name) or ("#" .. tostring(id))
        local function addGrid(entry)
            for m, cells in pairs(entry and entry.grid or {}) do
                for idx, n in pairs(cells) do
                    pts[#pts + 1] = { m = m, x = ((idx % GRID) + 0.5) / GRID,
                        y = (math.floor(idx / GRID) + 0.5) / GRID, n = n, name = name, k = "u" }
                end
            end
        end
        addGrid(self.db.beasts[id])
        addGrid(self.db.imported[id])
        local seed = self:SeedEntry(id)
        if seed and seed.m and seed.p then
            for i = 1, #seed.p - 1, 2 do
                pts[#pts + 1] = { m = seed.m, x = seed.p[i] / 1000, y = seed.p[i + 1] / 1000, n = 1, name = name, k = "u" }
            end
        end
    end
    if #pts > MAP_POINTS_MAX then
        table.sort(pts, function(a, b) return a.n > b.n end)
        for i = #pts, MAP_POINTS_MAX + 1, -1 do
            pts[i] = nil
        end
    end
    return pts
end

-- Tiere mit Funden in der Naehe einer Kartenzelle: { {id, own, imp, seed}, ... }, meiste Funde zuerst
function Beasts:BeastsAt(ids, mapID, cx, cy, radius)
    local out = {}
    local function near(idx)
        local x = idx % GRID
        local y = math.floor(idx / GRID)
        return math.abs(x - cx) <= radius and math.abs(y - cy) <= radius
    end
    for id in pairs(ids) do
        local own, imp, seed = self.db.beasts[id], self.db.imported[id], self:SeedEntry(id)
        local h = { id = id, own = 0, imp = 0, seed = 0 }
        local oc = own and own.grid and own.grid[mapID]
        if oc then
            for idx, n in pairs(oc) do
                if near(idx) then h.own = h.own + n end
            end
        end
        local ic = imp and imp.grid and imp.grid[mapID]
        if ic then
            for idx, n in pairs(ic) do
                if near(idx) then h.imp = h.imp + n end
            end
        end
        if seed and seed.m == mapID and seed.p then
            for i = 1, #seed.p - 1, 2 do
                local x = math.min(GRID - 1, math.floor(seed.p[i] / 1000 * GRID))
                local y = math.min(GRID - 1, math.floor(seed.p[i + 1] / 1000 * GRID))
                if math.abs(x - cx) <= radius and math.abs(y - cy) <= radius then h.seed = h.seed + 1 end
            end
        end
        if h.own + h.imp + h.seed > 0 then
            h.total = h.own * 3 + h.imp * 2 + h.seed
            out[#out + 1] = h
        end
    end
    table.sort(out, function(a, b)
        if a.total ~= b.total then return a.total > b.total end
        return a.id < b.id
    end)
    return out
end

------------------------------------------------------------------------
-- Ereignisse
------------------------------------------------------------------------

function Beasts:OnTargetChanged()
    if self:Observe("target") then
        self:StartTracking()
    end
end

function Beasts:OnMouseover()
    self:Observe("mouseover")
end

function Beasts:OnTargetAura(unit)
    if unit ~= "target" then
        return
    end
    -- Wildtierkunde zeigt sich als Aura: kurz warten, dann Tooltip erneut lesen
    if self.auraTimer then
        return
    end
    self.auraTimer = true
    C_Timer.After(0.4, function()
        Beasts.auraTimer = nil
        local guid = Util.Clean(UnitGUID("target"))
        local id = type(guid) == "string" and Util.GetNpcID(guid) or nil
        if id then
            Beasts.loreAt[id] = nil
        end
        Beasts:Observe("target")
    end)
end

-- Alte Eintraege (Punktlisten) ins Raster uebertragen, Typzeile aus den Hinweisen entfernen
local function MigrateEntry(e)
    if type(e) ~= "table" then
        return
    end
    if type(e.locs) == "table" then
        for _, p in ipairs(e.locs) do
            if type(p) == "table" and type(p.m) == "number" and type(p.x) == "number" and type(p.y) == "number" then
                AddSighting(e, p.m, CellIndex(p.x / 1000, p.y / 1000))
            end
        end
        e.locs = nil
    end
    if type(e.extra) == "table" then
        local keep = {}
        for _, line in ipairs(e.extra) do
            local low = type(line) == "string" and string.lower(line) or ""
            if low ~= "wildtier" and low ~= "beast" and low ~= "" then
                keep[#keep + 1] = line
            end
        end
        e.extra = #keep > 0 and keep or nil
    end
end

-- Alte Eintraege umwandeln. Laeuft bei OnEnable, denn OnInitialize wuerde bei schon
-- bereitem Core noch vor der Definition dieser Funktionen aufgerufen.
function Beasts:Migrate()
    for _, e in pairs(self.db.beasts) do
        MigrateEntry(e)
    end
    for _, e in pairs(self.db.imported) do
        MigrateEntry(e)
    end
    self.index = nil
end

function Beasts:OnEnable()
    self.loreAt = self.loreAt or {}
    self.trackAt = self.trackAt or {}
    self.lastCell = self.lastCell or {}
    self:Migrate()
    FW:RegisterEvent("PLAYER_TARGET_CHANGED", self.OnTargetChanged, self)
    FW:RegisterEvent("UPDATE_MOUSEOVER_UNIT", self.OnMouseover, self)
    FW:RegisterEvent("UNIT_AURA", self.OnTargetAura, self)
    FW:On("PET_UPDATED", self.OnPetUpdated, self)
    if self.Sync then
        self.Sync:Start()
    end
end

function Beasts:OnDisable()
    if self.Sync then
        self.Sync:Stop()
    end
    FW:UnregisterEvent("PLAYER_TARGET_CHANGED", self)
    FW:UnregisterEvent("UPDATE_MOUSEOVER_UNIT", self)
    FW:UnregisterEvent("UNIT_AURA", self)
    FW:Off("PET_UPDATED", self)
end

------------------------------------------------------------------------
-- Export / Import
-- Geteilt werden nur eigene Funde, nichts Persoenliches.
------------------------------------------------------------------------

local function SanitizeList(src, max, fn)
    local list = {}
    if type(src) ~= "table" then
        return list
    end
    for _, v in ipairs(src) do
        if #list >= max then
            break
        end
        local clean = fn(v)
        if clean ~= nil then
            list[#list + 1] = clean
        end
    end
    return list
end

local function Sanitize(src)
    if type(src) ~= "table" then
        return nil
    end
    local id = Num(src.id, 1, 10000000)
    if not id then
        return nil
    end
    local r = {
        id = math.floor(id),
        name = Str(src.name, 64),
        fid = Str(src.fid, 24),
        family = Str(src.family, 48),
        lvl1 = Num(src.lvl1, 1, 120),
        lvl2 = Num(src.lvl2, 1, 120),
        c = Str(src.c, 16),
        zone = Str(src.zone, 64),
        tameable = (src.tameable == true) or nil,
        diet = CleanDiet(src.diet),
        seen = (src.seen == true) or nil,
        lored = (src.lored == true) or nil,
        tamed = (src.tamed == true) or nil,
        updated = Num(src.updated, 1, 4102444800) or time(),
    }
    -- Raster: flache Liste cells { {m,x,y,n} } (neu) oder Punkte locs (alt, Zehntel-Prozent)
    local grid, total = {}, 0
    local function put(m, cx, cy, n)
        if total >= MAX_CELLS then
            return
        end
        local cells = grid[m]
        if not cells then
            cells = {}
            grid[m] = cells
        end
        local idx = cy * GRID + cx
        if not cells[idx] then
            total = total + 1
        end
        cells[idx] = math.max(cells[idx] or 0, n)
    end
    if type(src.cells) == "table" then
        for _, p in ipairs(src.cells) do
            if type(p) == "table" then
                local m, x, y, n = Num(p.m, 1, 100000), Num(p.x, 0, GRID - 1), Num(p.y, 0, GRID - 1), Num(p.n, 1, 65535)
                if m and x and y and n then
                    put(m, math.floor(x), math.floor(y), math.floor(n))
                end
            end
        end
    end
    if type(src.locs) == "table" then
        for _, p in ipairs(src.locs) do
            if type(p) == "table" then
                local m, x, y = Num(p.m, 1, 100000), Num(p.x, 0, 1000), Num(p.y, 0, 1000)
                if m and x and y then
                    put(m, math.min(GRID - 1, math.floor(x / 1000 * GRID)), math.min(GRID - 1, math.floor(y / 1000 * GRID)), 1)
                end
            end
        end
    end
    r.grid = total > 0 and grid or nil
    r.petAbilities = SanitizeList(src.petAbilities, MAX_PETABIL, function(a)
        if type(a) ~= "table" then
            return nil
        end
        local n = Str(a.name, 64)
        if not n then
            return nil
        end
        return { name = n, rank = Num(a.rank, 0, 20), spellID = Num(a.spellID, 1, 10000000), passive = (a.passive == true) or nil }
    end)
    r.extra = SanitizeList(src.extra, MAX_EXTRA, function(v)
        return Str(v, 120)
    end)
    if #r.petAbilities == 0 then r.petAbilities = nil end
    if #r.extra == 0 then r.extra = nil end
    return r
end

function Beasts:ExportData()
    local list = {}
    for id, e in pairs(self.db.beasts) do
        local copy = {}
        for k, v in pairs(e) do
            copy[k] = v
        end
        copy.id = id
        copy.cells = FlattenGrid(e.grid)
        local clean = Sanitize(copy)
        if clean then
            -- Ausgabe als flache Liste statt verschachtelter Tabelle
            clean.cells = FlattenGrid(clean.grid)
            clean.grid = nil
            if #clean.cells == 0 then
                clean.cells = nil
            end
            list[#list + 1] = clean
        end
    end
    table.sort(list, function(a, b)
        return a.id < b.id
    end)
    if #list == 0 then
        return {}
    end
    return { list = list }
end

-- Was geteilt werden darf: der eigene Eintrag, sonst ein ueber das Brett erhaltener (db.relay) aus der Ebene "importiert"
function Beasts:ShareEntry(id)
    local e = self.db.beasts[id]
    if e then return e end
    local relay = self.db.relay
    if relay and relay[id] then return self.db.imported[id] end
    return nil
end

-- Ids aller teilbaren Eintraege: eigene Funde und ueber das Brett erhaltene
function Beasts:ShareIds()
    local out = {}
    for id, e in pairs(self.db.beasts) do
        if type(id) == "number" and (e.seen or e.lored or e.tamed) then out[id] = e end
    end
    for id in pairs(self.db.relay or {}) do
        local e = self.db.imported[id]
        if type(id) == "number" and e and not out[id] then out[id] = e end
    end
    return out
end

-- Eigener Eintrag als bereinigter Datensatz zum Teilen (flache Zellenliste), nil wenn leer
function Beasts:ShareRecord(id)
    local e = self:ShareEntry(id)
    if not e then
        return nil
    end
    local copy = {}
    for k, v in pairs(e) do
        copy[k] = v
    end
    copy.id = id
    copy.cells = FlattenGrid(e.grid)
    local clean = Sanitize(copy)
    if not clean then
        return nil
    end
    clean.cells = FlattenGrid(clean.grid)
    clean.grid = nil
    if #clean.cells == 0 then
        clean.cells = nil
    end
    return clean
end

-- Zahl der eigenen teilbaren Eintraege und ihr Pruefwert (Reihenfolge egal)
function Beasts:ShareSummary()
    local n, h = 0, 0
    for id, e in pairs(self:ShareIds()) do
        n = n + 1
        h = (h + id * 131 + ((e.updated or 0) % 1000003)) % 2147483647
    end
    return n, h
end

function Beasts:ValidateImport(data)
    if type(data) ~= "table" or type(data.list) ~= "table" or #data.list == 0 then
        return false, L.BEAST_IMPORT_EMPTY
    end
    if #data.list > MAX_IMPORT then
        return false, L.BEAST_IMPORT_TOO_MANY
    end
    return true
end

function Beasts:ImportData(data, opts)
    opts = opts or {}
    local added, updated, skipped = 0, 0, 0
    for _, item in ipairs(data.list) do
        local clean = Sanitize(item)
        if not clean then
            skipped = skipped + 1
        else
            local id = clean.id
            clean.id = nil
            local old = self.db.imported[id]
            if old and not opts.merge and (old.updated or 0) >= clean.updated then
                skipped = skipped + 1
            else
                if old then
                    -- Fundorte beider Staende zusammenfuehren, Merkmale vereinen
                    local merged = { grid = {} }
                    for _, source in ipairs({ old.grid or {}, clean.grid or {} }) do
                        for m, cells in pairs(source) do
                            for idx, n in pairs(cells) do
                                local have = merged.grid[m] and merged.grid[m][idx]
                                if have then
                                    merged.grid[m][idx] = math.max(have, n)
                                else
                                    AddSighting(merged, m, idx, n)
                                end
                            end
                        end
                    end
                    clean.grid = GridCount(merged.grid) > 0 and merged.grid or nil
                    clean.seen = clean.seen or old.seen
                    clean.lored = clean.lored or old.lored
                    clean.tamed = clean.tamed or old.tamed
                    clean.tameable = clean.tameable or old.tameable
                    clean.updated = math.max(old.updated or 0, clean.updated)
                    if not clean.petAbilities then clean.petAbilities = old.petAbilities end
                    if not clean.extra then clean.extra = old.extra end
                    updated = updated + 1
                else
                    added = added + 1
                end
                clean.importedAt = time()
                self.db.imported[id] = clean
                if clean.fid and clean.family then
                    self.db.familyNames[clean.fid] = self.db.familyNames[clean.fid] or clean.family
                end
            end
        end
    end
    self.index = nil
    FW:Fire("BEASTS_UPDATED")
    return string.format(FW.L.BEAST_IMPORT_STATS, added, updated, skipped)
end

FW.Export.RegisterHandler("beasts", {
    label = function()
        return FW.L.BEAST_EXPORT_LABEL
    end,
    export = function()
        return Beasts:ExportData()
    end,
    validate = function(data)
        return Beasts:ValidateImport(data)
    end,
    import = function(data)
        return Beasts:ImportData(data)
    end,
})
