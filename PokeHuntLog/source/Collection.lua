-- PokeHuntLog: the skin index (bundled + discovered skins) and the collection built from saved pets.

local HPL = PokeHuntLog

HPL.skinsById = {}      -- [skinId] = { id, type, family, model, name, npcs, custom }
HPL.skinByNpcId = {}    -- [npcId] = skinId
HPL.skinsByName = {}    -- [lowercase creature name] = { skinId, ... }
HPL.tree = {}           -- ordered: { { name = type, families = { { name = family, skins = { skinId, ... } } } } }
HPL.skinsByZone = {}    -- [zone] = { skinId, ... }
HPL.knowsByCreature = {} -- [lowercase creature name] = abilities it knows when tamed, e.g. "Bite 2 , Dash 1"
HPL.teachers = {}       -- ["bite 2"] = { { name, level, zone, lowLevel }, ... }, who can teach that rank

-- Petopia's model name is usually just the family in plural ("Boar" / "Boars"); only worth
-- showing when it says something the family name does not.
function HPL.ModelLabel(def)
  if not def or not def.model or def.model == "" then return nil end
  if def.model == def.family then return nil end
  if def.model == def.family .. "s" then return nil end
  if def.model == def.family .. "es" then return nil end
  return def.model
end

-- Pet trainers sell these outright, so no beast teaches them. Everything else is learned by taming.
HPL.TRAINER_ABILITIES = {
  ["Arcane Resistance"] = true, ["Fire Resistance"] = true, ["Frost Resistance"] = true,
  ["Nature Resistance"] = true, ["Shadow Resistance"] = true,
  ["Great Stamina"] = true, ["Natural Armor"] = true, ["Growl"] = true,
}

-- The bottom of a level range: "9-10" -> 9, "60" -> 60, "" -> 0.
function HPL.LowLevel(text)
  local _, _, low = string.find(text or "", "^(%d+)")
  return tonumber(low) or 0
end

-- For a pet the log couldn't place, which skins could it be? A beast teaches its abilities when tamed,
-- so the pet must know every ability rank the beast knows, and can't be below the beast's level.
-- Judged on what the pet knew the first time the log saw it; later training only adds to that.
-- Returns { { skin = id, npcs = { npc, ... } }, ... } sorted by skin name; empty when nothing fits.
function HPL.GuessSkin(pet)
  local known, any = {}, false
  local spells = pet.firstSpells or pet.spells or {}
  for i = 1, table.getn(spells) do
    -- "Scorpid Poison Rank 1" in the spellbook is "Scorpid Poison 1" in the data
    local _, _, ability, rank = string.find(spells[i], "^(.-)%s+Rank%s+(%d+)$")
    if ability then
      known[string.lower(ability) .. " " .. rank] = true
      any = true
    end
  end
  if not any then return {} end

  -- The beast that explains the most of what the pet knew wins: a pet knowing Claw 2 and Scorpid Poison 1
  -- came from a beast teaching both, not from one teaching only the poison.
  local level = pet.firstLevel or pet.level or 0
  local bySkin, out, best = {}, {}, 0
  for id, def in pairs(HPL.skinsById) do
    if def.family == pet.family then
      local npcs = def.npcs or {}
      for i = 1, table.getn(npcs) do
        local taught = HPL.ParseKnows(npcs[i][7])
        if table.getn(taught) > 0 and (level == 0 or HPL.LowLevel(npcs[i][3]) <= level) then
          local fits = true
          for t = 1, table.getn(taught) do
            if not known[string.lower(taught[t].name) .. " " .. taught[t].rank] then fits = false end
          end
          local score = table.getn(taught)
          if fits and score > best then
            best = score
            bySkin, out = {}, {}
          end
          if fits and score == best then
            if not bySkin[id] then
              bySkin[id] = { skin = id, npcs = {} }
              table.insert(out, bySkin[id])
            end
            table.insert(bySkin[id].npcs, npcs[i])
          end
        end
      end
    end
  end
  table.sort(out, function(a, b) return HPL.skinsById[a.skin].name < HPL.skinsById[b.skin].name end)
  return out
end

-- A creature can teach more than one ability: "Bite 2 , Furious Howl 1". Returns { {name, rank}, ... }.
function HPL.ParseKnows(text)
  local out = {}
  if not text or text == "" then return out end
  local rest = text
  while rest and rest ~= "" do
    local comma = string.find(rest, ",", 1, true)
    local piece
    if comma then
      piece = string.sub(rest, 1, comma - 1)
      rest = string.sub(rest, comma + 1)
    else
      piece = rest
      rest = ""
    end
    local _, _, name, rank = string.find(piece, "^%s*(.-)%s+(%d+)%s*$")
    if name and name ~= "" then
      table.insert(out, { name = name, rank = tonumber(rank) })
    end
  end
  return out
end

-- Petopia calls the family roles Defense, Offense and General; these are the words hunters use.
HPL.ROLE_LABELS = { ["Defense"] = "Tank", ["Offense"] = "DPS", ["General"] = "Balanced" }
HPL.ROLE_COLORS = {
  ["Tank"] = "|cff5599ff", ["DPS"] = "|cffff6666", ["Balanced"] = "|cffffd100", ["AoE tank"] = "|cffcc77ff",
}
-- An ability that changes what the family is for.
local ROLE_BY_ABILITY = { ["Thunderstomp"] = "AoE tank" }

-- Short notes on what each trainable ability does.
HPL.ABILITY_NOTES = {
  ["Bite"] = "damage",
  ["Claw"] = "damage",
  ["Charge"] = "closes the gap and hits harder",
  ["Cower"] = "drops threat",
  ["Dash"] = "sprint",
  ["Dive"] = "sprint",
  ["Furious Howl"] = "buffs your party melee damage",
  ["Growl"] = "taunt",
  ["Lightning Breath"] = "ranged nature damage",
  ["Prowl"] = "stealth",
  ["Scorpid Poison"] = "stacking poison",
  ["Screech"] = "lowers attack power of everything in front",
  ["Shell Shield"] = "takes much less damage for a while",
  ["Thunderstomp"] = "damages and grabs everything nearby",
}

function HPL.FamilyInfo(family)
  return PokeHuntLog_Families and PokeHuntLog_Families[family] or nil
end

-- "Tank", "DPS", "Balanced" or "AoE tank"; nil for families that aren't in the database.
function HPL.FamilyRole(family)
  local info = HPL.FamilyInfo(family)
  if not info then return nil end
  local abilities = info.abilities or {}
  for i = 1, table.getn(abilities) do
    if ROLE_BY_ABILITY[abilities[i]] then return ROLE_BY_ABILITY[abilities[i]] end
  end
  return HPL.ROLE_LABELS[info.role] or info.role
end

local function Register(def)
  if HPL.skinsById[def.id] then return end
  HPL.skinsById[def.id] = def
  local npcs = def.npcs or {}
  for i = 1, table.getn(npcs) do
    local npcId, npcName = npcs[i][1], npcs[i][2]
    if npcId and npcId > 0 then
      HPL.skinByNpcId[npcId] = def.id
    end
    if npcName then
      local key = string.lower(npcName)
      if not HPL.skinsByName[key] then HPL.skinsByName[key] = {} end
      table.insert(HPL.skinsByName[key], def.id)
      if npcs[i][7] and npcs[i][7] ~= "" then
        HPL.knowsByCreature[key] = npcs[i][7]
        local taught = HPL.ParseKnows(npcs[i][7])
        for t = 1, table.getn(taught) do
          local slot = string.lower(taught[t].name) .. " " .. taught[t].rank
          if not HPL.teachers[slot] then HPL.teachers[slot] = {} end
          table.insert(HPL.teachers[slot], {
            name = npcName, level = npcs[i][3], zone = npcs[i][4], tag = npcs[i][5],
            lowLevel = HPL.LowLevel(npcs[i][3]),
          })
        end
      end
    end
  end
end

local function SortByName(a, b)
  return a.name < b.name
end

function HPL.BuildIndex()
  HPL.skinsById = {}
  HPL.skinByNpcId = {}
  HPL.skinsByName = {}
  HPL.skinsByZone = {}
  HPL.knowsByCreature = {}
  HPL.teachers = {}

  local data = PokeHuntLog_Skins or {}
  for i = 1, table.getn(data) do
    local s = data[i]
    Register({ id = s.id, type = "Beast", family = s.family, model = s.model, name = s.name, npcs = s.npcs })
  end
  for id, c in pairs(HPL.db.custom) do
    Register({ id = id, type = c.type or "Beast", family = c.family or "Unknown", model = c.family,
      name = c.name or id, custom = true,
      npcs = { { c.npcId or 0, c.creature or c.name, c.level and tostring(c.level) or "", c.zone or "", "Found in game" } } })
  end

  -- Group into Type -> Family -> Skins, sorted by name.
  local types, typeList = {}, {}
  for id, def in pairs(HPL.skinsById) do
    local t = types[def.type]
    if not t then
      t = { name = def.type, familyMap = {}, families = {} }
      types[def.type] = t
      table.insert(typeList, t)
    end
    local f = t.familyMap[def.family]
    if not f then
      f = { name = def.family, skins = {} }
      t.familyMap[def.family] = f
      table.insert(t.families, f)
    end
    table.insert(f.skins, def)
  end
  -- Which skins can be found in which zone, for the "in this zone" counts.
  for id, def in pairs(HPL.skinsById) do
    local seen = {}
    local npcs = def.npcs or {}
    for i = 1, table.getn(npcs) do
      local zone = npcs[i][4]
      if zone and zone ~= "" and not seen[zone] then
        seen[zone] = true
        if not HPL.skinsByZone[zone] then HPL.skinsByZone[zone] = {} end
        table.insert(HPL.skinsByZone[zone], id)
      end
    end
  end

  table.sort(typeList, SortByName)
  HPL.tree = {}
  for i = 1, table.getn(typeList) do
    local t = typeList[i]
    table.sort(t.families, SortByName)
    local families = {}
    for j = 1, table.getn(t.families) do
      local f = t.families[j]
      table.sort(f.skins, SortByName)
      local ids = {}
      for k = 1, table.getn(f.skins) do
        table.insert(ids, f.skins[k].id)
      end
      table.insert(families, { name = f.name, skins = ids })
    end
    table.insert(HPL.tree, { name = t.name, families = families })
  end
end

-- Work out which skin a creature has. Returns skinId and how it matched ("id", "name", "ambiguous").
function HPL.ResolveSkin(family, creatureName, npcIds)
  if npcIds then
    for i = 1, table.getn(npcIds) do
      local id = HPL.skinByNpcId[npcIds[i]]
      if id and (not family or HPL.skinsById[id].family == family) then
        return id, "id"
      end
    end
  end
  if creatureName then
    local list = HPL.skinsByName[string.lower(creatureName)]
    if list then
      local best, count = nil, 0
      for i = 1, table.getn(list) do
        if not family or HPL.skinsById[list[i]].family == family then
          count = count + 1
          if not best then best = list[i] end
        end
      end
      if best then
        return best, (count > 1) and "ambiguous" or "name"
      end
    end
  end
  return nil
end

-- A tamed beast that isn't in the bundled database becomes its own skin, named after the creature.
function HPL.AddCustomSkin(ctype, family, creatureName, npcId, level, zone)
  local id = "custom:" .. HPL.Key(family) .. ":" .. HPL.Key(creatureName)
  if not HPL.db.custom[id] then
    HPL.db.custom[id] = { type = ctype or "Beast", family = family, name = creatureName, creature = creatureName,
      npcId = npcId, level = level, zone = zone }
    HPL.BuildIndex()
  end
  return id
end

-- Build the collection from every saved pet on every character.
function HPL.RebuildCollection()
  local caught = {}      -- [skinId] = { maxLevel, maxPet, maxChar, firstTime, firstChar, firstZone, firstCreature, pets = { ... } }
  local unknown = {}     -- pets whose skin isn't known: { pet, charKey, index }

  for charKey, list in pairs(HPL.db.pets) do
    for i = 1, table.getn(list) do
      local pet = list[i]
      if pet.skin and HPL.skinsById[pet.skin] then
        local c = caught[pet.skin]
        if not c then
          c = { maxLevel = 0, pets = {} }
          caught[pet.skin] = c
        end
        table.insert(c.pets, { pet = pet, charKey = charKey })
        local level = pet.level or 0
        if level > c.maxLevel then
          c.maxLevel, c.maxPet, c.maxChar = level, pet.name, charKey
        end
        local when = pet.tamed or pet.firstSeen
        if when and (not c.firstTime or when < c.firstTime) then
          c.firstTime, c.firstChar = when, charKey
          c.firstZone, c.firstCreature, c.firstWitnessed = pet.zone, pet.creature, pet.witnessed
        end
      else
        table.insert(unknown, { pet = pet, charKey = charKey, index = i })
      end
    end
  end

  -- Totals per type and family.
  local totals = { skins = 0, caught = 0, families = 0, familiesCaught = 0, bestLevel = 0 }
  local familyStats, typeStats = {}, {}
  for i = 1, table.getn(HPL.tree) do
    local t = HPL.tree[i]
    local ts = { skins = 0, caught = 0 }
    typeStats[t.name] = ts
    for j = 1, table.getn(t.families) do
      local f = t.families[j]
      local fs = { skins = table.getn(f.skins), caught = 0, bestLevel = 0 }
      familyStats[t.name .. "/" .. f.name] = fs
      for k = 1, table.getn(f.skins) do
        local c = caught[f.skins[k]]
        if c then
          fs.caught = fs.caught + 1
          if c.maxLevel > fs.bestLevel then fs.bestLevel = c.maxLevel end
        end
      end
      ts.skins = ts.skins + fs.skins
      ts.caught = ts.caught + fs.caught
      totals.families = totals.families + 1
      if fs.caught > 0 then totals.familiesCaught = totals.familiesCaught + 1 end
      if fs.bestLevel > totals.bestLevel then totals.bestLevel = fs.bestLevel end
    end
    totals.skins = totals.skins + ts.skins
    totals.caught = totals.caught + ts.caught
  end

  HPL.caught = caught
  HPL.unknownPets = unknown
  HPL.totals = totals
  HPL.familyStats = familyStats
  HPL.typeStats = typeStats
end

-- Which families can learn an ability, from the family data.
function HPL.FamiliesWithAbility(ability)
  local families = {}
  if not PokeHuntLog_Families then return families end
  for name, info in pairs(PokeHuntLog_Families) do
    local lists = { info.abilities or {}, info.passives or {} }
    for l = 1, 2 do
      for i = 1, table.getn(lists[l]) do
        if lists[l][i] == ability then table.insert(families, name) end
      end
    end
  end
  table.sort(families)
  return families
end

-- How many skins of the zone you are standing in are still missing.
function HPL.ZoneProgress(zone)
  local ids = zone and HPL.skinsByZone[zone]
  if not ids then return nil end
  local caught, missing = 0, {}
  for i = 1, table.getn(ids) do
    if HPL.caught[ids[i]] then
      caught = caught + 1
    else
      table.insert(missing, ids[i])
    end
  end
  return caught, table.getn(ids), missing
end

-- Is every skin of this family caught?
function HPL.FamilyComplete(typeName, family)
  local stats = HPL.familyStats[typeName .. "/" .. family]
  return stats and stats.skins > 0 and stats.caught >= stats.skins
end

function HPL.Percent(part, whole)
  if not whole or whole == 0 then return 0 end
  return math.floor(part * 100 / whole + 0.5)
end
