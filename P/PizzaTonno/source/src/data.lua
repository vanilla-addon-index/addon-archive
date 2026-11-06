local PT = PizzaTonno
local areas, items = PT.data.areas, PT.data.items

-- Built here, after every data file ran, so areas added by a local override are indexed too.
local zoneIds, subzoneIds = {}, {}

for id, area in pairs(areas) do
  area.id = id
  -- Two zone-level areas can share a name (The Deadmines): the one with a loot table wins.
  if not area.zone and (not zoneIds[area.name] or area.loot) then
    zoneIds[area.name] = id
  end
end

for id, area in pairs(areas) do
  local zone = area.zone and areas[area.zone]
  if zone then
    subzoneIds[zone.name] = subzoneIds[zone.name] or {}
    subzoneIds[zone.name][area.name] = id
  end
end

function PT.data.area(id)
  return areas[id]
end

function PT.data.zone(zoneName)
  return areas[zoneIds[zoneName]]
end

-- What the server uses where the player stands (GameObject.cpp, bobber use): the subzone's loot
-- table if it has one, else the zone's; the subzone's skill level unless it's 0, else the zone's.
function PT.data.spot(zoneName, subzoneName)
  local zone = areas[zoneIds[zoneName]]
  local subzones = subzoneIds[zoneName]
  local subzone = subzones and areas[subzones[subzoneName]]

  local lootArea = subzone and subzone.loot and subzone or zone
  if not lootArea or not lootArea.loot then return end

  local required = subzone and subzone.skill ~= 0 and subzone.skill or zone and zone.skill or 0
  return lootArea, required
end

local withItem
local NONE = {}

-- Set of the area ids whose loot table has the item.
function PT.data.areasWith(itemId)
  if not withItem then
    withItem = {}
    for id, area in pairs(areas) do
      for _, row in ipairs(area.loot or {}) do
        withItem[row[1]] = withItem[row[1]] or {}
        withItem[row[1]][id] = true
      end
    end
  end
  return withItem[itemId] or NONE
end

function PT.data.isPool(name)
  for _, pool in pairs(PT.data.pools) do
    if pool.name == name then return true end
  end
  return false
end

-- Whether a pool that spawns in this zone can drop the item.
function PT.data.poolDrops(zoneName, itemId)
  for _, pool in pairs(PT.data.pools) do
    if pool.zones[zoneName] then
      for _, row in ipairs(pool.loot) do
        if row[1] == itemId then return true end
      end
    end
  end
  return false
end

-- The pools that spawn in the zone, each { id, pool, spawns }, most spawns first.
function PT.data.poolsIn(zoneName)
  local found = {}
  for id, pool in pairs(PT.data.pools) do
    if pool.zones[zoneName] then table.insert(found, { id = id, pool = pool, spawns = pool.zones[zoneName] }) end
  end
  table.sort(found, function (a, b) return a.spawns > b.spawns end)
  return found
end

local usedIn

-- The recipes (by spell id) that take the item as a reagent.
function PT.data.recipesWith(itemId)
  if not usedIn then
    usedIn = {}
    for id, recipe in pairs(PT.data.recipes) do
      for _, reagent in ipairs(recipe.reagents) do
        usedIn[reagent[1]] = usedIn[reagent[1]] or {}
        table.insert(usedIn[reagent[1]], id)
      end
    end
  end
  return usedIn[itemId] or NONE
end

local catchables

-- Every item any water or pool can give, by name.
function PT.data.catchables()
  if catchables then return catchables end
  local seen = {}
  for _, area in pairs(areas) do
    for _, row in ipairs(area.loot or {}) do seen[row[1]] = true end
  end
  for _, pool in pairs(PT.data.pools) do
    for _, row in ipairs(pool.loot) do seen[row[1]] = true end
  end
  catchables = {}
  for id in pairs(seen) do
    if items[id] then table.insert(catchables, id) end
  end
  table.sort(catchables, function (a, b) return items[a][1] < items[b][1] end)
  return catchables
end

-- Item classes in the data, by the game's numbers.
-- Catches the icons get wrong, and the ones that summon a fish boss.
local CATEGORIES = {
  [7973] = 'fish',  -- Big-mouth Clam
  [56086] = 'clackora',  -- Glowing Arctic Grayling
  [56087] = 'clackora',  -- Barnacle Covered Key
  [19975] = 'gahzranka',  -- Zulian Mudskunk
}

local CLASS_CATEGORIES = {
  [0] = 'consumables', [1] = 'containers', [2] = 'gear', [4] = 'gear', [5] = 'materials', [7] = 'materials',
  [9] = 'recipes', [12] = 'quest',
}

-- What kind of catch an item is: 'fish', 'clackora' or 'gahzranka' (what summons those bosses),
-- 'materials', 'consumables', 'containers', 'gear', 'recipes', 'quest' or 'other'. Fish come in
-- several classes (food, trade goods, quest items, junk), so they're told apart by their icons
-- (Mightfish, Firefin Snapper and Oily Blackmouth have monster heads); chests and crates are junk to
-- the game but open like containers.
function PT.data.category(id)
  local item = items[id]
  if not item then return 'other' end
  if CATEGORIES[id] then return CATEGORIES[id] end
  local icon = item[3]
  if not string.find(icon, 'Fishingpole') and (string.find(icon, 'Fish') or string.find(icon, 'MonsterHead')) then
    return 'fish'
  end
  if string.find(icon, 'INV_Box') or string.find(icon, 'INV_Crate') then return 'containers' end
  return CLASS_CATEGORIES[item[4]] or 'other'
end

-- Whether the item is a fish: the Fish section, and the boss summoners that are fish too (not the key).
function PT.data.isFish(id)
  local category = PT.data.category(id)
  if category == 'fish' then return true end
  local item = items[id]
  return (category == 'clackora' or category == 'gahzranka') and string.find(item[3], 'Fish') ~= nil
end

-- 'dungeon', 'raid' or 'battleground' for an instance's map, nil for the continents.
function PT.data.instance(map)
  return PT.data.maps[map]
end

-- name, quality, icon file name, item class
function PT.data.item(id)
  local item = items[id]
  if item then return item[1], item[2], item[3], item[4] end
  -- Caught, but not in the 1.17.2 data (the live server drops a few more things, like Clean
  -- Fishbones): the client knows it from its item cache, once it has seen one.
  local name, _, quality, _, _, _, _, _, texture = GetItemInfo(id)
  if name then return name, quality, texture and (string.gsub(texture, '^Interface\\Icons\\', '')) end
end
