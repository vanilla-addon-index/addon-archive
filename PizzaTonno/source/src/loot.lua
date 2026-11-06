local PT = PizzaTonno
PT.loot = {}

-- the skill some custom rows need (condition k410)
PT.loot.ELITE_SKILL = 410
local ELITE_SKILL = PT.loot.ELITE_SKILL

-- The server's roll: group 0 rows roll on their own. Every other group rolls once, spending the
-- explicit chances in table order; whatever is left is shared evenly by the chance-0 rows. Rows
-- whose condition is off are skipped without using up the roll, so the others gain chance.
-- Negative chances are quest drops; they count like positive ones here.
-- A group without chance-0 rows can come up empty. Players only see catches that bring something
-- up, so such a group's chances are scaled to fill the whole roll, and a table adds up to 100%.
function PT.loot.chances(rows, conditions)
  local chances, groups = {}, {}

  local function add(itemId, p)
    chances[itemId] = 1 - (1 - (chances[itemId] or 0)) * (1 - p)
  end

  for _, row in ipairs(rows) do
    local itemId, chance, group, condition = row[1], math.abs(row[2]), row[3], row[4]
    if not condition or conditions[condition] then
      if group == 0 then
        add(itemId, math.min(chance, 100) / 100)
      else
        groups[group] = groups[group] or { left = 100, equal = {}, picks = {} }
        local g = groups[group]
        if chance == 0 then
          table.insert(g.equal, itemId)
        else
          table.insert(g.picks, { itemId, math.max(math.min(chance, g.left), 0) })
          g.left = g.left - chance
        end
      end
    end
  end

  for _, g in pairs(groups) do
    local n, left = table.getn(g.equal), math.max(g.left, 0)
    local scale = n == 0 and left < 100 and 100 / (100 - left) or 1
    for _, pick in ipairs(g.picks) do add(pick[1], pick[2] * scale / 100) end
    for _, itemId in ipairs(g.equal) do add(itemId, left / n / 100) end
  end

  return chances
end

local SEASONAL = { s = true, w = true }
-- by loot table, which never changes
local dependencies = {}

-- What each item's chance depends on: { [itemId] = { light = true, season = true } }. A row with a
-- condition depends on it, and so do the chance-0 rows of its group, which inherit the share it
-- leaves when it's off. Everything else has the same chance at any hour and in any season.
function PT.loot.dependencies(rows)
  if dependencies[rows] then return dependencies[rows] end
  local items, groups = {}, {}

  local function mark(target, condition)
    if SEASONAL[condition] then target.season = true else target.light = true end
  end

  for _, row in ipairs(rows) do
    local itemId, group, condition = row[1], row[3], row[4]
    if condition == 'd' or condition == 'n' or SEASONAL[condition] then
      items[itemId] = items[itemId] or {}
      groups[group] = groups[group] or {}
      mark(items[itemId], condition)
      mark(groups[group], condition)
    end
  end

  for _, row in ipairs(rows) do
    local itemId, chance, group = row[1], row[2], row[3]
    if chance == 0 and group ~= 0 and groups[group] then
      items[itemId] = items[itemId] or {}
      items[itemId].light = items[itemId].light or groups[group].light
      items[itemId].season = items[itemId].season or groups[group].season
    end
  end

  dependencies[rows] = items
  return items
end

-- by loot table, then by the conditions as a number
local rolls = {}

-- `chances` under these conditions, worked out once per table and conditions and kept, so the
-- result is shared: read it, don't change it.
function PT.loot.rolled(rows, day, summer, winter, elite)
  local key = (day and 1 or 0) + (summer and 2 or 0) + (winter and 4 or 0) + (elite and 8 or 0)
  if not rolls[rows] then rolls[rows] = {} end
  if not rolls[rows][key] then
    rolls[rows][key] = PT.loot.chances(rows, { d = day, n = not day, s = summer, w = winter, k410 = elite })
  end
  return rolls[rows][key]
end

-- Which loot conditions hold right now at this zone hour, for a player with this skill.
function PT.loot.conditions(hour, skill)
  local day = PT.clock.isDay(hour)
  return {
    d = day,
    n = not day,
    s = PT.clock.event('summer'),
    w = PT.clock.event('winter'),
    k410 = skill >= ELITE_SKILL,
  }
end

-- The skill past which nothing here changes: every catch lands and the 410 rows are open.
function PT.loot.fullSkill(rows, required)
  for _, row in ipairs(rows) do
    if row[4] == 'k410' then return math.max(required + 95, ELITE_SKILL) end
  end
  return required + 95
end

function PT.loot.landing(skill, required)
  if skill < required then return 0 end
  return math.min(skill - required + 5, 100) / 100
end
