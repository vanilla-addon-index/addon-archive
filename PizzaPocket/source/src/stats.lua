local PP = PizzaPocket

PP.stats = {}
local stats = PP.stats

local ATTEMPT_WINDOW = 1.5

local attempt = nil

-- Which resist line the server actually sends is unknown, so match every variant.
local RESIST_LINES = {
  { 'resisted', SPELLRESISTSELFOTHER  or 'Your %s was resisted by %s.' },
  { 'immune',   SPELLIMMUNESELFOTHER  or 'Your %s failed. %s is immune.' },
  { 'missed',   SPELLMISSSELFOTHER    or 'Your %s missed %s.' },
  { 'dodged',   SPELLDODGEDSELFOTHER  or 'Your %s was dodged by %s.' },
  { 'evaded',   SPELLEVADEDSELFOTHER  or 'Your %s was evaded by %s.' },
}

local BLOCK_LINES = {
  SPELLFAILPERFORMSELF or 'You fail to perform %s: %s.',
  SPELLFAILCASTSELF    or 'You fail to cast %s: %s.',
}

for i = 1, table.getn(RESIST_LINES) do
  RESIST_LINES[i][2] = PP.utils.buildPattern(RESIST_LINES[i][2])
end
for i = 1, table.getn(BLOCK_LINES) do
  BLOCK_LINES[i] = PP.utils.buildPattern(BLOCK_LINES[i])
end

function stats.new()
  return {
    picked   = 0,
    resisted = 0,
    blocked  = 0,
    silent   = 0,
    kinds    = {},
    reasons  = {},
    deltas   = {},
  }
end

function stats.normalize(s)
  if type(s) ~= 'table' then return stats.new() end
  local base = stats.new()
  for k, v in pairs(base) do
    if s[k] == nil then s[k] = v end
  end
  return s
end

stats.session = stats.new()
stats.alltime = stats.new()

function stats.rate(s)
  local total = s.picked + s.resisted
  if total == 0 then return nil, 0, 0 end
  return s.resisted / total * 100, s.resisted, total
end

function stats.startAttempt(unit, guid)
  local level = UnitLevel(unit)
  attempt = {
    guid  = guid,
    name  = UnitName(unit) or '?',
    delta = (level and level > 0) and (UnitLevel('player') - level) or nil,
    time  = GetTime(),
  }
end

function stats.pending()
  return attempt ~= nil
end

function stats.cancelAttempt()
  attempt = nil
end

local function bump(s, outcome, kind, reason, delta)
  s[outcome] = s[outcome] + 1

  if kind then s.kinds[kind] = (s.kinds[kind] or 0) + 1 end
  if reason then s.reasons[reason] = (s.reasons[reason] or 0) + 1 end

  if delta and outcome ~= 'blocked' then
    local d = s.deltas[delta]
    if not d then
      d = { picked = 0, resisted = 0, silent = 0 }
      s.deltas[delta] = d
    end
    d[outcome] = d[outcome] + 1
  end
end

local function resolve(outcome, kind, reason)
  local delta = attempt and attempt.delta
  local who = attempt and attempt.name or '?'
  attempt = nil

  bump(stats.session, outcome, kind, reason, delta)
  bump(stats.alltime, outcome, kind, reason, delta)
  PP.statsframe.update()

  PP:Debug('  ' .. who .. ': ' .. (kind or reason or outcome))
end

function stats.poll()
  if attempt and GetTime() - attempt.time > ATTEMPT_WINDOW then
    resolve('silent')
  end
end

function stats.onCombatMessage(msg)
  if not msg then return end

  for i = 1, table.getn(RESIST_LINES) do
    local kind = RESIST_LINES[i][1]
    local _, _, spell = string.find(msg, RESIST_LINES[i][2])
    if spell == PP.PICK_POCKET then
      resolve('resisted', kind)
      return
    end
  end

  for i = 1, table.getn(BLOCK_LINES) do
    local _, _, spell, reason = string.find(msg, BLOCK_LINES[i])
    if spell == PP.PICK_POCKET then
      resolve('blocked', nil, reason)
      return
    end
  end

  if string.find(msg, PP.PICK_POCKET, 1, true) then
    PP:Debug('  Unmatched: ' .. msg)
  end
end

-- UI errors carry no spell name, so only trust them while an attempt is open.
function stats.onErrorMessage(msg)
  if not attempt or not msg then return end
  resolve('blocked', nil, msg)
end

function stats.onLootOpened()
  if UnitExists('target') and UnitIsDeadOrGhost('target') then return end

  local guid = UnitExists('target') and PP.utils.guid('target') or attempt and attempt.guid

  if attempt then resolve('picked') end
  if guid then PP.picked[guid] = true end
end

function stats.report(label, s)
  local rate, resisted, total = stats.rate(s)
  PP:Print(PP.Colors.primary .. label .. '|r')
  if not rate then
    PP:Print('  No attempts yet')
    return
  end

  PP:Print(string.format('  %d attempts: %d picked, %d resisted (%.1f%% resist)',
    total, s.picked, resisted, rate))

  if s.silent > 0 then
    PP:Print('  ' .. s.silent .. ' silent (no verdict seen, not counted)')
  end

  local kinds = ''
  for kind, count in pairs(s.kinds) do
    kinds = kinds .. (kinds ~= '' and ', ' or '') .. kind .. ' ' .. count
  end
  if kinds ~= '' then PP:Print('  Resist messages: ' .. kinds) end

  if s.blocked > 0 then
    PP:Print('  ' .. s.blocked .. ' blocked before casting (not counted in the rate):')
    for reason, count in pairs(s.reasons) do
      PP:Print('    ' .. reason .. ': ' .. count)
    end
  end

  local levels = {}
  for delta in pairs(s.deltas) do table.insert(levels, delta) end
  table.sort(levels)

  if table.getn(levels) > 0 then PP:Print('  By level gap:') end

  for i = 1, table.getn(levels) do
    local delta = levels[i]
    local d = s.deltas[delta]
    local dTotal = d.picked + d.resisted
    local where
    if delta > 0 then
      where = delta .. ' below you'
    elseif delta == 0 then
      where = 'your level'
    else
      where = -delta .. ' above you'
    end
    if dTotal > 0 then
      PP:Print(string.format('    %s: %d/%d resist (%.1f%%)',
        where, d.resisted, dTotal, d.resisted / dTotal * 100))
    end
  end
end
