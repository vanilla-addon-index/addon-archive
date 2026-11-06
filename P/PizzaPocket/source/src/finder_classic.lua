local PP = PizzaPocket
local finder = PP.finder

local classic ={ name = 'ClassicAPI (nameplates)' }
finder.classic = classic

local CAST_GAP = 0.25

local useUnitXP = false
local lastCast = 0
local lastGuid

local function clearIfPicked()
  if lastGuid and PP.utils.guid('target') == lastGuid then ClearTarget() end
end

function classic.onLootClosed()
  clearIfPicked()
  lastGuid = nil
end

function classic.available()
  if not CLASSIC_API_VERSION then return false end
  if not C_NamePlate or not C_NamePlate.GetNamePlateGUIDs then return false end
  if not C_Spell or not C_Spell.IsSpellInRange then return false end
  return UnitDistanceSquared ~= nil
end

-- UnitXP first, so both paths measure range the same way.
local function checkRange(unit)
  if useUnitXP then return finder.unitXPRange(unit) end
  if C_Spell.IsSpellInRange(PP.PICK_POCKET, unit) == false then return 'out of range' end
  return nil
end

local function castViaTarget(guid)
  TargetUnit(guid)
  if PP.utils.guid('target') == guid then
    PP.stats.startAttempt('target', guid)
    CastSpellByName(PP.PICK_POCKET)
  else
    PP:Debug('  Could not select it either')
  end
  ClearTarget()
end

function classic.pick()
  if LootFrame:IsVisible() then return end

  -- A cast at the edge of range can fail with no reply at all, so retry soon instead of waiting on a verdict.
  if GetTime() - lastCast < CAST_GAP then return end

  useUnitXP = PP.utils.hasUnitXP()

  local guids = C_NamePlate.GetNamePlateGUIDs()
  local best, bestDist
  local enemies = 0

  for i = 1, table.getn(guids) do
    local guid = guids[i]
    if UnitCanAttack('player', guid) then
      enemies = enemies + 1
      local reason = finder.skipReason(guid, guid, checkRange)
      if reason then
        PP:Debug('  Skip: ' .. (UnitName(guid) or '?') .. ': ' .. reason)
      else
        local distSq, known = UnitDistanceSquared(guid)
        if known and (not bestDist or distSq < bestDist) then
          best, bestDist = guid, distSq
        end
      end
    end
  end

  -- false hands the press to the legacy path, e.g. when nameplates are off.
  if enemies == 0 then
    PP:Debug('No enemy nameplates, trying the next path')
    return false
  end

  if not best then
    PP:Debug('No valid target found (checked ' .. enemies .. ' enemies)')
    return
  end

  PP:Debug(string.format('Picking: %s (%.1f yd)', UnitName(best) or '?', math.sqrt(bestDist)))
  lastCast = GetTime()
  lastGuid = best
  PP.stats.startAttempt(best, best)
  if C_Spell.CastAtUnit and C_Spell.CastAtUnit(PP.PICK_POCKET, best) then
    clearIfPicked()
    return
  end

  -- A refusal that raised its own error has already resolved the attempt.
  if not PP.stats.pending() then return end
  PP.stats.cancelAttempt()
  PP:Debug('  CastAtUnit refused, casting through the target')
  castViaTarget(best)
end
