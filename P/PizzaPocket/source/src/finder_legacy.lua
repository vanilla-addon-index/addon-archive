local PP = PizzaPocket
local finder = PP.finder

local legacy = { name = 'legacy (TargetNearestEnemy)' }
finder.legacy = legacy

-- TargetNearestEnemy's cycle carries over between presses, so spamming walks it off the nearest mob.
legacy.throttle = 0.25
legacy.maxCycle = 40

local lastPick = 0

local function hasSuperWoW()
  return SUPERWOW_VERSION or SetAutoloot
end

function legacy.available()
  return hasSuperWoW() and PP.utils.hasUnitXP()
end

function legacy.explain()
  if not hasSuperWoW() then PP:Print('Requires SuperWoW (for GUIDs)') end
  if not PP.utils.hasUnitXP() then PP:Print('Requires UnitXP_SP3 (for distance + targeting)') end
end

function legacy.pick()
  local now = GetTime()
  if now - lastPick < legacy.throttle then return end
  lastPick = now

  if LootFrame:IsVisible() then return end

  local seen = {}
  local checked = 0
  for i = 1, legacy.maxCycle do
    TargetNearestEnemy()

    if not UnitExists('target') then break end

    local guid = PP.utils.guid('target')
    if not guid then break end

    if seen[guid] then break end
    seen[guid] = true
    checked = checked + 1

    local reason = finder.skipReason('target', guid, finder.unitXPRange)
    if not reason then
      PP:Debug('Picking: ' .. (UnitName('target') or '?') .. ' (#' .. checked .. ')')
      PP.stats.startAttempt('target')
      CastSpellByName(PP.PICK_POCKET)
      ClearTarget()
      return
    end
    PP:Debug('  Skip: ' .. (UnitName('target') or '?') .. ': ' .. reason)
  end

  PP:Debug('No valid target found (checked ' .. checked .. ' mobs)')
  ClearTarget()
end
