-- Freewood-OctoWoW-Pet: erfasst den aktiven Jaeger-Begleiter und speichert ihn.
--
-- Gespeichert wird im Core-Datenspeicher (Account-weit): Pet.db.pets[<Besitzer>:<Name>].
-- Alle Abfragen laufen geschuetzt (pcall) und nur ausserhalb des Kampfes, damit
-- ein veraenderter oder gesperrter Rueckgabewert nie einen Fehler auslost.
--
-- Eintrag (Felder, alle optional ausser name/level):
--   name, family, creatureType, level, npcID,
--   happiness (1..3), damagePct, loyaltyRate, loyaltyText, loyaltyLevel,
--   trainingTotal, trainingSpent, speed, dmgMin, dmgMax, armor, armorBase, hpMax,
--   foods = { "..." }, abilities = { { name, rank, spellID, passive } }, others = { "..." },
--   updated, firstSeen, owner (nur eigene), src ("own" | "import")

local ADDON, NS = ...

local FW = _G.Freewood
if not FW or not FW:RequireAPI(1, ADDON) then
    return
end

local Util = FW.Util
local L = FW.L

local MAX_ABILITIES = 60
local MAX_OTHERS = 30
local MAX_FOODS = 12
local MAX_IMPORT = 300

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

local Pet = FW:NewModule("Pet", {
    version = GetMeta("Version") or "dev",
    title = L.PET_TITLE,
    description = L.PET_DESC,
    defaults = { pets = {} },
})
NS.Pet = Pet
FW.Pet = Pet -- fuer andere Freewood-Addons

------------------------------------------------------------------------
-- Kleine Pruefer
------------------------------------------------------------------------

local function Num(v)
    if Util.IsSecret(v) then
        return nil
    end
    if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then
        return v
    end
    return nil
end

local function NumIn(v, lo, hi)
    v = Num(v)
    if v and v >= lo and v <= hi then
        return v
    end
    return nil
end

local function Str(v, max)
    if Util.IsSecret(v) then
        return nil
    end
    if type(v) == "string" and v ~= "" then
        return v:sub(1, max or 64)
    end
    return nil
end

local function Round(v, decimals)
    v = Num(v)
    if not v then
        return nil
    end
    return Util.Round(v, decimals or 0)
end

------------------------------------------------------------------------
-- Auslesen
------------------------------------------------------------------------

local function ReadAbilities()
    local abilities, others = {}, {}

    if not (C_SpellBook and C_SpellBook.HasPetSpells and C_SpellBook.GetSpellBookItemName
        and Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet) then
        return abilities, others
    end

    local bank = Enum.SpellBookSpellBank.Pet
    local count = C_SpellBook.HasPetSpells()
    if type(count) ~= "number" then
        return abilities, others
    end

    for i = 1, count do
        local ok, spellName, subName = pcall(C_SpellBook.GetSpellBookItemName, i, bank)
        if ok and type(spellName) == "string" and spellName ~= "" then
            local rank
            if type(subName) == "string" then
                rank = tonumber(subName:match("(%d+)"))
            end

            local spellID, passive
            if C_SpellBook.GetSpellBookItemInfo then
                local okInfo, info = pcall(C_SpellBook.GetSpellBookItemInfo, i, bank)
                if okInfo and type(info) == "table" then
                    spellID = Num(info.spellID) or Num(info.actionID)
                    if info.isPassive == true then
                        passive = true
                    end
                end
            end

            if rank then
                if #abilities < MAX_ABILITIES then
                    abilities[#abilities + 1] = {
                        name = spellName:sub(1, 48),
                        rank = rank,
                        spellID = spellID,
                        passive = passive,
                    }
                end
            elseif #others < MAX_OTHERS then
                others[#others + 1] = spellName:sub(1, 48)
            end
        end
    end

    return abilities, others
end

local function ReadFoods()
    if not (C_PetInfo and C_PetInfo.GetPetFoodTypes) then
        return nil
    end
    local ok, a, b, c, d, e, f, g, h = pcall(C_PetInfo.GetPetFoodTypes)
    if not ok then
        return nil
    end
    local raw = { a, b, c, d, e, f, g, h }
    if type(a) == "table" then
        raw = a
    end
    local foods = {}
    for _, value in ipairs(raw) do
        if type(value) == "string" and #foods < MAX_FOODS then
            foods[#foods + 1] = value:sub(1, 32)
        end
    end
    if #foods == 0 then
        return nil
    end
    return foods
end

local function ReadNpcID()
    local guid = Util.Clean(UnitGUID("pet"))
    if type(guid) ~= "string" then
        return nil
    end
    local hk, hid = Util.ParseHexGUID(guid)
    if hk then
        if hk == "Pet" or hk == "Creature" then return hid end
        return nil
    end
    local kind, _, _, _, _, id = strsplit("-", guid)
    if kind == "Pet" or kind == "Creature" then
        return tonumber(id)
    end
    return nil
end

function Pet:BuildRecord()
    local name = Util.Clean(UnitName("pet"))
    if type(name) ~= "string" or name == "" or (UNKNOWN and name == UNKNOWN) then
        return nil
    end

    local r = {
        name = name,
        family = Str(UnitCreatureFamily("pet")),
        creatureType = Str(UnitCreatureType("pet")),
        level = NumIn(UnitLevel("pet"), 1, 100),
        npcID = ReadNpcID(),
        updated = time(),
        owner = Util.GetPlayerKey(),
        src = "own",
    }
    if not r.level then
        return nil
    end

    if C_PetInfo then
        if C_PetInfo.GetPetHappiness then
            local happiness, damagePct, loyaltyRate = C_PetInfo.GetPetHappiness()
            r.happiness = NumIn(happiness, 1, 3)
            r.damagePct = Round(damagePct)
            r.loyaltyRate = Round(loyaltyRate)
        end
        if C_PetInfo.GetPetLoyalty then
            local text = C_PetInfo.GetPetLoyalty()
            if type(text) == "string" then
                r.loyaltyText = text:sub(1, 80)
                r.loyaltyLevel = NumIn(tonumber(text:match("(%d+)")), 1, 20)
            end
        end
        if C_PetInfo.GetPetTrainingPoints then
            local total, spent = C_PetInfo.GetPetTrainingPoints()
            r.trainingTotal = Round(total)
            r.trainingSpent = Round(spent)
        end
    end

    r.speed = Round((UnitAttackSpeed("pet")), 2)

    local dmgMin, dmgMax = UnitDamage("pet")
    r.dmgMin = Round(dmgMin)
    r.dmgMax = Round(dmgMax)

    local armorBase, armorEffective = UnitArmor("pet")
    r.armorBase = Round(armorBase)
    r.armor = Round(armorEffective) or r.armorBase

    r.hpMax = Round((UnitHealthMax("pet")))

    -- Zusatzwerte (alle optional, jeweils geschuetzt gelesen)
    local function Try(fn, ...)
        if type(fn) ~= "function" then
            return nil
        end
        local ok, a, b, c, d = pcall(fn, ...)
        if ok then
            return a, b, c, d
        end
        return nil
    end
    local apBase, apPos, apNeg = Try(UnitAttackPower, "pet")
    if type(apBase) == "number" then
        r.apBase = Round(apBase)
        r.apBonus = Round((tonumber(apPos) or 0) + (tonumber(apNeg) or 0))
    end
    local _, runSpeed = Try(GetUnitSpeed, "pet")
    if type(runSpeed) == "number" then
        r.runSpeed = Round(runSpeed, 2)
    end
    r.resist = {}
    for school = 1, 6 do
        local _, total = Try(UnitResistance, "pet", school)
        r.resist[school] = type(total) == "number" and Round(total) or nil
    end
    if next(r.resist) == nil then
        r.resist = nil
    end
    local crit = Try(GetCritChance)
    if type(crit) == "number" then
        r.critMelee = Round(crit, 2)
    end
    local sCrit = Try(GetSpellCritChance, 2)
    if type(sCrit) == "number" then
        r.critSpell = Round(sCrit, 2)
    end
    local rCrit = Try(GetRangedCritChance)
    if type(rCrit) == "number" then
        r.critRanged = Round(rCrit, 2)
    end

    r.foods = ReadFoods()
    r.abilities, r.others = ReadAbilities()

    return r
end

------------------------------------------------------------------------
-- Speichern
------------------------------------------------------------------------

function Pet:Store(record)
    local key = record.owner .. ":" .. record.name
    local old = self.db.pets[key]
    record.firstSeen = (old and old.firstSeen) or record.updated
    self.db.pets[key] = record
    self.activeKey = key
    if not self.selectedKey then
        self.selectedKey = key
    end
    FW:Fire("PET_UPDATED", key, record)
    return key
end

-- Liest den aktiven Begleiter. Rueckgabe: true bei Erfolg, sonst false, Grund
function Pet:Scan()
    if not UnitExists("pet") then
        -- Begleiter entlassen oder noch nicht da: "aktiv" zuruecknehmen
        if self.activeKey then
            self.activeKey = nil
            FW:Fire("PET_UPDATED", nil, nil)
        end
        return false, "nopet"
    end
    if InCombatLockdown and InCombatLockdown() then
        self.pending = true
        return false, "combat"
    end
    local ok, record = pcall(self.BuildRecord, self)
    if not ok then
        FW:Debug("Freewood-OctoWoW-Pet: Auslesen fehlgeschlagen:", record)
        return false, "error"
    end
    if not record then
        return false, "nodata"
    end
    self:Store(record)
    return true
end

function Pet:RequestScan(delay)
    if self.scanQueued then
        return
    end
    self.scanQueued = true
    C_Timer.After(delay or 0.6, function()
        self.scanQueued = false
        self:Scan()
    end)
end

function Pet:Delete(key)
    if self.db.pets[key] then
        self.db.pets[key] = nil
        if self.selectedKey == key then
            self.selectedKey = nil
        end
        if self.activeKey == key then
            self.activeKey = nil
        end
        FW:Fire("PET_UPDATED", key, nil)
    end
end

------------------------------------------------------------------------
-- Ereignisse
------------------------------------------------------------------------

function Pet:OnUnitPet(unit)
    if unit == "player" then
        self:RequestScan(1.0)
    end
end

function Pet:OnRegenEnabled()
    if self.pending then
        self.pending = false
        self:RequestScan(0.5)
    end
end

function Pet:OnStatsChanged()
    self:RequestScan(1.5)
end

function Pet:OnEnable()
    FW:RegisterEvent("UNIT_PET", self.OnUnitPet, self)
    FW:RegisterEvent("PET_STATS_UPDATE", self.OnStatsChanged, self)
    FW:RegisterEvent("PET_BAR_UPDATE", self.OnStatsChanged, self)
    FW:RegisterEvent("SPELLS_CHANGED", self.OnStatsChanged, self)
    FW:RegisterEvent("PLAYER_REGEN_ENABLED", self.OnRegenEnabled, self)
    FW:RegisterEvent("PLAYER_ENTERING_WORLD", self.OnStatsChanged, self)
    self:RequestScan(2.0)
end

function Pet:OnDisable()
    for _, event in ipairs({ "UNIT_PET", "PET_STATS_UPDATE", "PET_BAR_UPDATE", "SPELLS_CHANGED",
        "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD" }) do
        FW:UnregisterEvent(event, self)
    end
end

------------------------------------------------------------------------
-- Export / Import
-- Geteilt wird nur, was kein Persoenliches enthaelt: kein Besitzer, keine Notizen.
------------------------------------------------------------------------

local function SanitizeList(src, max, itemFn)
    local list = {}
    if type(src) ~= "table" then
        return list
    end
    for i, item in ipairs(src) do
        if i > max then
            break
        end
        local clean = itemFn(item)
        if clean then
            list[#list + 1] = clean
        end
    end
    return list
end

-- Uebernimmt nur bekannte Felder mit gepruefter Form. Liefert nil, wenn der Eintrag unbrauchbar ist.
local function Sanitize(src)
    if type(src) ~= "table" then
        return nil
    end
    local name = Str(src.name, 48)
    local level = NumIn(src.level, 1, 100)
    if not name or not level then
        return nil
    end

    local r = {
        name = name,
        level = level,
        family = Str(src.family, 48),
        creatureType = Str(src.creatureType, 48),
        npcID = NumIn(src.npcID, 1, 10000000),
        happiness = NumIn(src.happiness, 1, 3),
        damagePct = NumIn(src.damagePct, 0, 1000),
        loyaltyRate = NumIn(src.loyaltyRate, -1000, 1000),
        loyaltyText = Str(src.loyaltyText, 80),
        loyaltyLevel = NumIn(src.loyaltyLevel, 1, 20),
        trainingTotal = NumIn(src.trainingTotal, 0, 100000),
        trainingSpent = NumIn(src.trainingSpent, 0, 100000),
        speed = NumIn(src.speed, 0, 100),
        dmgMin = NumIn(src.dmgMin, 0, 10000000),
        dmgMax = NumIn(src.dmgMax, 0, 10000000),
        armor = NumIn(src.armor, 0, 10000000),
        armorBase = NumIn(src.armorBase, 0, 10000000),
        hpMax = NumIn(src.hpMax, 0, 100000000),
        apBase = NumIn(src.apBase, 0, 10000000),
        apBonus = NumIn(src.apBonus, -10000000, 10000000),
        runSpeed = NumIn(src.runSpeed, 0, 100),
        critMelee = NumIn(src.critMelee, 0, 100),
        critSpell = NumIn(src.critSpell, 0, 100),
        critRanged = NumIn(src.critRanged, 0, 100),
        updated = NumIn(src.updated, 0, 4102444800) or 0,
    }

    if type(src.resist) == "table" then
        local res = {}
        for school = 1, 6 do
            res[school] = NumIn(src.resist[school], 0, 100000)
        end
        if next(res) ~= nil then
            r.resist = res
        end
    end

    r.foods = SanitizeList(src.foods, MAX_FOODS, function(v)
        return Str(v, 32)
    end)
    if #r.foods == 0 then
        r.foods = nil
    end

    r.abilities = SanitizeList(src.abilities, MAX_ABILITIES, function(a)
        if type(a) ~= "table" then
            return nil
        end
        local abilityName = Str(a.name, 48)
        if not abilityName then
            return nil
        end
        return {
            name = abilityName,
            rank = NumIn(a.rank, 0, 20),
            spellID = NumIn(a.spellID, 1, 10000000),
            passive = (a.passive == true) or nil,
        }
    end)

    r.others = SanitizeList(src.others, MAX_OTHERS, function(v)
        return Str(v, 48)
    end)

    return r
end

function Pet:ExportData()
    local list = {}
    for _, record in pairs(self.db.pets) do
        if record.src ~= "import" then
            local clean = Sanitize(record)
            if clean then
                list[#list + 1] = clean
            end
        end
    end
    table.sort(list, function(a, b)
        return (a.updated or 0) > (b.updated or 0)
    end)
    if #list == 0 then
        return {}
    end
    return { list = list }
end

function Pet:ValidateImport(data)
    if type(data) ~= "table" or type(data.list) ~= "table" then
        return false, L.PET_IMPORT_EMPTY
    end
    if #data.list > MAX_IMPORT then
        return false, L.PET_IMPORT_TOO_MANY
    end
    if #data.list == 0 then
        return false, L.PET_IMPORT_EMPTY
    end
    return true
end

function Pet:ImportData(data)
    local added, updated, skipped = 0, 0, 0
    for _, item in ipairs(data.list) do
        local clean = Sanitize(item)
        if not clean then
            skipped = skipped + 1
        else
            local key = "import:" .. clean.name .. ":" .. (clean.family or "?") .. ":" .. clean.level
            local existing = self.db.pets[key]
            if existing and (existing.updated or 0) >= clean.updated then
                skipped = skipped + 1
            else
                clean.src = "import"
                clean.importedAt = time()
                clean.firstSeen = (existing and existing.firstSeen) or clean.importedAt
                self.db.pets[key] = clean
                if existing then
                    updated = updated + 1
                else
                    added = added + 1
                end
            end
        end
    end
    FW:Fire("PET_UPDATED", nil, nil)
    return string.format(FW.L.PET_IMPORT_STATS, added, updated, skipped)
end

FW.Export.RegisterHandler("pets", {
    label = function()
        return FW.L.PET_EXPORT_LABEL
    end,
    export = function()
        return Pet:ExportData()
    end,
    validate = function(data)
        return Pet:ValidateImport(data)
    end,
    import = function(data)
        return Pet:ImportData(data)
    end,
})
