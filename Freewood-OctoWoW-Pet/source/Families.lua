-- Freewood-OctoWoW-Pet: Familienfaktoren (Leben, Ruestung, Schaden)
-- Werte laut wow-petopia.com/forever (Gegenpruefung mit den Classic-Werten).
-- nil = auf der Quelle nicht angegeben. Reihenfolge: hp, armor, dmg.

local ADDON, NS = ...

local Pet = NS.Pet
if not Pet then
    return
end

local FAMILIES = {
    bat         = { 1.00, 1.00, 1.07, names = { "fledermaus", "bat" } },
    bear        = { 1.08, 1.05, 0.91, names = { "bär", "bear" } },
    birdofprey  = { 1.00, 1.00, 1.07, names = { "raubvogel", "bird of prey" } },
    boar        = { 1.04, 1.09, 0.90, names = { "eber", "boar" } },
    carrionbird = { 1.00, 1.05, 1.00, names = { "aasvogel", "aasvoge", "carrion bird" } },
    cat         = { 0.98, 1.00, 1.10, names = { "katze", "cat" } },
    corehound   = { nil,  nil,  1.00, names = { "kernhund", "core hound" } },
    crab        = { 0.96, 1.13, 0.95, names = { "krebs", "crab" } },
    crocolisk   = { 0.95, 1.10, 1.00, names = { "krokil", "krokilisk", "krokolisk", "crocolisk" } },
    fox         = { nil,  nil,  1.00, names = { "fuchs", "fox" } },
    gorilla     = { 1.04, 1.00, 1.02, names = { "gorilla" } },
    hyena       = { 1.00, 1.05, 1.00, names = { "hyäne", "hyaene", "hyena" } },
    owl         = { nil,  nil,  nil,  names = { "eule", "owl" } },
    raptor      = { 0.95, 1.03, 1.10, names = { "raptor" } },
    scorpid     = { 1.00, 1.10, 0.94, names = { "skorpid", "scorpid" } },
    spider      = { 1.00, 1.00, 1.07, names = { "spinne", "spider" } },
    tallstrider = { 1.05, 1.00, 1.00, names = { "weitschreiter", "tallstrider" } },
    turtle      = { 1.00, 1.13, 0.90, names = { "schildkröte", "turtle" } },
    windserpent = { 1.00, 1.00, 1.07, names = { "windnatter", "wind serpent" } },
    wolf        = { 1.00, 1.05, 1.00, names = { "wolf" } },
}

local BY_NAME = {}
for id, data in pairs(FAMILIES) do
    for _, n in ipairs(data.names) do
        BY_NAME[n] = id
    end
end

-- Liefert { hp = n|nil, armor = n|nil, dmg = n|nil, id = "bear" } oder nil
function Pet.GetFamilyMods(familyName)
    if type(familyName) ~= "string" or familyName == "" then
        return nil
    end
    local key = string.lower(familyName)
    local id = BY_NAME[key]
    if not id and #key >= 4 then
        -- Abgekuerzte Namen (z. B. "Krokil"): Anfang eines bekannten Namens
        for name, fid in pairs(BY_NAME) do
            if string.sub(name, 1, #key) == key then
                id = fid
                break
            end
        end
    end
    if not id then
        return nil
    end
    local d = FAMILIES[id]
    return { id = id, hp = d[1], armor = d[2], dmg = d[3] }
end

-- Wie GetFamilyMods, aber mit der Familien-ID ("bear")
function Pet.GetFamilyModsByID(id)
    local d = id and FAMILIES[id]
    if not d then
        return nil
    end
    return { id = id, hp = d[1], armor = d[2], dmg = d[3] }
end

-- Anzeigenamen (so wie sie im Spiel erscheinen; das Spiel kuerzt manche deutsche Namen)
local DISPLAY = {
    deDE = { bat = "Fledermaus", bear = "Bär", birdofprey = "Raubvogel", boar = "Eber", carrionbird = "Aasvoge",
        cat = "Katze", corehound = "Kernhund", crab = "Krebs", crocolisk = "Krokil", fox = "Fuchs",
        gorilla = "Gorilla", hyena = "Hyäne", owl = "Eule", raptor = "Raptor", scorpid = "Skorpid",
        spider = "Spinne", tallstrider = "Weitschreiter", turtle = "Schildkröte", windserpent = "Windnatter",
        wolf = "Wolf" },
    enUS = { bat = "Bat", bear = "Bear", birdofprey = "Bird of Prey", boar = "Boar", carrionbird = "Carrion Bird",
        cat = "Cat", corehound = "Core Hound", crab = "Crab", crocolisk = "Crocolisk", fox = "Fox",
        gorilla = "Gorilla", hyena = "Hyena", owl = "Owl", raptor = "Raptor", scorpid = "Scorpid",
        spider = "Spider", tallstrider = "Tallstrider", turtle = "Turtle", windserpent = "Wind Serpent",
        wolf = "Wolf" },
}

-- Symbole der Familien (Spiel-Icons); fehlt eines, kommt das Zaehmen-Symbol
local ICONS = {
    bat = "Ability_Hunter_Pet_Bat", bear = "Ability_Hunter_Pet_Bear", boar = "Ability_Hunter_Pet_Boar",
    carrionbird = "Ability_Hunter_Pet_Vulture", cat = "Ability_Hunter_Pet_Cat", crab = "Ability_Hunter_Pet_Crab",
    crocolisk = "Ability_Hunter_Pet_Crocolisk", gorilla = "Ability_Hunter_Pet_Gorilla",
    hyena = "Ability_Hunter_Pet_Hyena", owl = "Ability_Hunter_Pet_Owl", raptor = "Ability_Hunter_Pet_Raptor",
    scorpid = "Ability_Hunter_Pet_Scorpid", spider = "Ability_Hunter_Pet_Spider",
    tallstrider = "Ability_Hunter_Pet_TallStrider", turtle = "Ability_Hunter_Pet_Turtle",
    windserpent = "Ability_Hunter_Pet_WindSerpent", wolf = "Ability_Hunter_Pet_Wolf",
}

-- Symbolpfad zu einem Familiennamen (wie im Spiel gelesen) oder einer Familien-ID
function Pet.FamilyIcon(nameOrID)
    local id = nameOrID and (FAMILIES[nameOrID] and nameOrID or Pet.GetFamilyID(nameOrID))
    return "Interface\\Icons\\" .. ((id and ICONS[id]) or "Ability_Hunter_BeastTaming")
end

-- Familien-ID zu einem im Spiel gelesenen Namen (oder nil)
function Pet.GetFamilyID(familyName)
    local m = Pet.GetFamilyMods(familyName)
    return m and m.id or nil
end

-- Liste aller Familien-IDs
function Pet.GetFamilyIDs()
    local list = {}
    for id in pairs(FAMILIES) do
        list[#list + 1] = id
    end
    table.sort(list)
    return list
end

-- Anzeigename einer Familie in der Spielsprache (Rueckfall: Englisch, dann ID)
function Pet.FamilyDisplay(id)
    local loc = (GetLocale and GetLocale()) or "enUS"
    local set = DISPLAY[loc] or DISPLAY.enUS
    return set[id] or DISPLAY.enUS[id] or tostring(id)
end
