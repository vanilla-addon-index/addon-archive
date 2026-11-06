local PP = PizzaPocket

PP.finder = {}
local finder = PP.finder

finder.RANGE = 3

finder.PICKABLE = {
  ['Humanoid'] = true,
  ['Undead']   = true,
}

local warned = false

function finder.skipReason(unit, guid, checkRange)
  if not guid then return 'no guid' end
  if PP.picked[guid] then return 'already picked' end
  if UnitIsDeadOrGhost(unit) then return 'dead' end
  local kind = UnitCreatureType(unit)
  if not finder.PICKABLE[kind] then return 'type: ' .. (kind or 'nil') end
  return checkRange(unit)
end

function finder.unitXPRange(unit)
  local ok, dist = pcall(UnitXP, 'distanceBetween', 'player', unit)
  if not ok or not dist then return 'no dist' end
  if dist > finder.RANGE then return string.format('dist %.1f', dist) end
  return nil
end

function finder.active()
  if finder.classic.available() then return finder.classic end
  if finder.legacy.available() then return finder.legacy end
  return nil
end

function finder.pick()
  local classic, legacy = finder.classic, finder.legacy
  if classic.available() and classic.pick() ~= false then return end

  if legacy.available() then
    legacy.pick()
    return
  end

  if warned or classic.available() then return end
  warned = true
  legacy.explain()
end
