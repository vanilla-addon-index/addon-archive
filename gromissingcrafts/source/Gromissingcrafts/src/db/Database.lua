setfenv(1, Gromissingcrafts)

---@class Database
---@field _db DatabaseSavedVariable
Database = {}

---@shape DatabaseProfession
---@field rank number
---@field knownLocalizedSkillNames string[]

---@shape DatabaseCharacter
---@field realm string
---@field english_faction string
---@field localized_faction string
---@field name string
---@field professionsByLocalizedName table<string, DatabaseProfession>

---@shape DatabaseSavedVariable
---@field global {realmToNameToCharacter: table<string, table<string, DatabaseCharacter>>}

local SAVED_VARIABLE_NAME = "GromissingcraftsDatabase"

---@return DatabaseCharacter
local function newCharacterDefaults()
    return {
        realm = "",
        english_faction = "",
        localized_faction = "",
        name = "",
        professionsByLocalizedName = {},
    }
end

---@return self
function Database:Create()
    ---@type DatabaseSavedVariable
    local saved = getglobal(SAVED_VARIABLE_NAME)
    if type(saved) ~= "table" then
        saved = --[[---@type DatabaseSavedVariable]] {}
        setglobal(SAVED_VARIABLE_NAME, saved)
    end
    if type(saved.global) ~= "table" then
        saved.global = {realmToNameToCharacter = {}}
    end
    if type(saved.global.realmToNameToCharacter) ~= "table" then
        saved.global.realmToNameToCharacter = {}
    end

    self._db = saved

    return self
end

---@param realm string
---@return table<string, DatabaseCharacter>
function Database:_GetOrCreateRealm(realm)
    local realms = self._db.global.realmToNameToCharacter
    local nameToCharacter = realms[realm]
    if nameToCharacter == nil then
        nameToCharacter = {}
        realms[realm] = nameToCharacter
    end
    return nameToCharacter
end

---@param realm string
---@param name string
---@return DatabaseCharacter
function Database:_GetOrCreateCharacter(realm, name)
    local nameToCharacter = self:_GetOrCreateRealm(realm)
    local character = nameToCharacter[name]
    if character == nil then
        character = newCharacterDefaults()
        nameToCharacter[name] = character
    end
    return character
end

---@return DatabaseCharacter[]
function Database:GetCharacters()
    self:_SavePlayer()

    ---@type DatabaseCharacter[]
    local characters = {}
    for _, nameToCharacter in pairs(self._db.global.realmToNameToCharacter) do
        for _, character in pairs(nameToCharacter) do
            tinsert(characters, character)
        end
    end
    return characters
end

---@param characterName string
---@param localizedProfessionName string
---@return string[]
function Database:GetLocalizedSkillNames(characterName, localizedProfessionName)
    ---@type DatabaseProfession
    local profession
    for _, nameToCharacter in pairs(self._db.global.realmToNameToCharacter) do
        if nameToCharacter[characterName] ~= nil then
            profession = nameToCharacter[characterName].professionsByLocalizedName[localizedProfessionName]
        end
    end
    return (profession or {}).knownLocalizedSkillNames or {}
end

---@param localizedProfessionName string
---@param professionRank number
---@param localizedSkillNames string[]
function Database:SaveCurrentPlayerSkills(localizedProfessionName, professionRank, localizedSkillNames)
    local player = self:_SavePlayer()
    player.professionsByLocalizedName[localizedProfessionName] = {
        rank = professionRank,
        knownLocalizedSkillNames = localizedSkillNames
    }
end

---@param localizedProfessionNames string[]
function Database:SaveCurrentPlayerProfessions(localizedProfessionNames)
    ---@type table<string, boolean>
    local set = {}
    for _, localizedProfessionName in ipairs(localizedProfessionNames) do
        set[localizedProfessionName] = true
    end

    local player = self:_SavePlayer()
    for localizedProfessionName, _ in pairs(player.professionsByLocalizedName) do
        if set[localizedProfessionName] == nil then
            player.professionsByLocalizedName[localizedProfessionName] = nil
        end
    end
end

---@return DatabaseCharacter
function Database:_SavePlayer()
    local realm = GetRealmName()
    local name, _ = UnitName("player")
    local english_faction, localized_faction = UnitFactionGroup("player")

    local player = self:_GetOrCreateCharacter(realm, name)
    player.realm = realm
    player.english_faction = english_faction
    player.localized_faction = localized_faction
    player.name = name
    return player
end
