-- pfQuest xpGuide director: the facts about quests that every guide asks, from Data\Zones.lua (quests by zone): a quest's row, the
-- chain it belongs to, what comes after it, which quests are done or skipped, and the difficulty you are on (ER.Mode). No windows in
-- this file.

local ER = pfQuest_xpGuide

-- The three difficulties: a label and a sentence for each. What each one does is in Steps.lua: LEAVE_OUT (which quests it leaves out,
-- for every guide), COMFORT (how many levels above you a quest may be before the guide warns, and what a grind bridge levels to) and
-- GroupsOn (Hard does group quests); Adapt.lua moves you up or down one when you say how it is going.
ER.MODES = {
  casual = { label = "Casual", tip = "The guide leaves out group, elite, dungeon and escort quests, and risky ones." },
  medium = { label = "Medium", tip = "Leaves out group, elite and dungeon quests; warns on escorts and risky ones." },
  hard = { label = "Hard", tip = "Everything except dungeon quests." },
}
ER.MODE_ORDER = { "casual", "medium", "hard" }

------------------------------------------------------------------------------------------------------
-- Who you are
------------------------------------------------------------------------------------------------------

local RACE_BITS = { Human = 1, Orc = 2, Dwarf = 4, NightElf = 8, Scourge = 16, Undead = 16, Tauren = 32, Gnome = 64, Troll = 128,
  Goblin = 256, HighElf = 512 }
local CLASS_BITS = { WARRIOR = 1, PALADIN = 2, HUNTER = 4, ROGUE = 8, PRIEST = 16, SHAMAN = 64, MAGE = 128, WARLOCK = 256, DRUID = 1024 }
local RACE_LIST = { 1, 2, 4, 8, 16, 32, 64, 128, 256, 512 }
local ALLIANCE_MASK = 1 + 4 + 8 + 64 + 512
local HORDE_MASK = 2 + 16 + 32 + 128 + 256

local function HasBit(mask, bit)
  if not mask or not bit or bit == 0 then return false end
  return math.mod(math.floor(mask / bit), 2) == 1
end

-- Race bit, class bit and the mask of the whole faction for the character playing.
function ER.PlayerMasks()
  local _, raceToken = UnitRace("player")
  local _, classToken = UnitClass("player")
  local faction = UnitFactionGroup("player")
  local factionMask = faction == "Horde" and HORDE_MASK or ALLIANCE_MASK
  return RACE_BITS[raceToken or ""] or 0, CLASS_BITS[classToken or ""] or 0, factionMask
end

-- Can this character take the quest at all? A quest for another race or class is not offered. A race this
-- file does not know falls back to the faction.
local function ForMe(q, raceBit, classBit, factionMask)
  if q.r then
    if raceBit ~= 0 then
      if not HasBit(q.r, raceBit) then return false end
    else
      local ok = false
      for _, bit in ipairs(RACE_LIST) do
        if HasBit(factionMask, bit) and HasBit(q.r, bit) then ok = true end
      end
      if not ok then return false end
    end
  end
  if q.c and classBit ~= 0 and not HasBit(q.c, classBit) then return false end
  return true
end

------------------------------------------------------------------------------------------------------
-- What you have already done, and what you said no to
------------------------------------------------------------------------------------------------------

local function DoneTable()
  if not ER.db then return {} end
  if type(ER.db.done) ~= "table" then ER.db.done = {} end
  local char = ER.Char()
  if type(ER.db.done[char]) ~= "table" then
    ER.db.done[char] = {}
    -- First time: learn from the journal what this character already handed in.
    for _, e in ipairs(ER.db.journal or {}) do
      if e.t == "turnin" and e.char == char and e.title then
        ER.db.done[char][e.pfid or e.title] = true
        ER.db.done[char][e.title] = true
      end
    end
  end
  return ER.db.done[char]
end

function ER.MarkDone(title, pfid)
  local done = DoneTable()
  if title then done[title] = true end
  if pfid then done[pfid] = true end
end

-- Everything that happens when a quest is handed in, in this order: the done list first, then the guide.
-- Recorder.lua calls it once per hand-in.
function ER.OnTurnIn(title, pfid)
  if not title then return end
  ER.MarkDone(title, pfid)
  if ER.Steps and ER.Steps.OnTurnIn then ER.Steps.OnTurnIn(title, pfid) end
end

function ER.IsDone(q)
  local done = DoneTable()
  return done[q.id] or done[q.n] or false
end

local function Skipped(q)
  return ER.db and type(ER.db.skipped) == "table" and ER.db.skipped[q.id] or false
end

-- "Not today": the director stops suggesting this quest. /xpg unskip brings them all back.
function ER.SkipQuest(id)
  if not ER.db then return end
  if type(ER.db.skipped) ~= "table" then ER.db.skipped = {} end
  ER.db.skipped[id] = true
end

-- Also brings back the quests the guide learned to leave out for this character (died twice on, skipped).
function ER.ClearSkipped()
  if not ER.db then return end
  ER.db.skipped = {}
  local a = type(ER.db.adapt) == "table" and ER.db.adapt[ER.Char()]
  if type(a) == "table" then
    a.hard, a.deaths = {}, {}
  end
end

local function InLog(q)
  local known = ER.Recorder and ER.Recorder.Known and ER.Recorder.Known()
  return known and known[q.n] or false
end

------------------------------------------------------------------------------------------------------
-- Zones and chains
------------------------------------------------------------------------------------------------------

local zoneByName, byId, followers

local function BuildIndex()
  if zoneByName then return end
  zoneByName, byId, followers = {}, {}, {}
  for zid, z in pairs(pfQuest_xpGuide_Zones or {}) do
    zoneByName[string.lower(z.name)] = zid
    for i = 1, table.getn(z.q) do
      local q = z.q[i]
      q.zone = zid
      byId[q.id] = q
      if q.p then
        if not followers[q.p] then followers[q.p] = {} end
        table.insert(followers[q.p], q.id)
      end
    end
  end
end

function ER.ZoneId(name)
  BuildIndex()
  if not name then return nil end
  return zoneByName[string.lower(name)]
end

function ER.ZoneRows(zid)
  local z = pfQuest_xpGuide_Zones and pfQuest_xpGuide_Zones[zid]
  return z and z.q or {}, z and z.name
end

-- A quest's place in its chain: { first = id, ids = {all, in order}, pos = this one's step, len = how many }.
-- The chain runs through the quest itself: the quests before it (each one's prerequisite, back to the first), the quest,
-- then its follow-ups (where a quest has several, the one in the same zone as the first). nil when it stands alone.
function ER.ChainOf(id)
  BuildIndex()
  local q = byId[id]
  if not q then return nil end
  local before, seen, cur = {}, { [id] = true }, id
  while byId[cur] and byId[cur].p and byId[byId[cur].p] and not seen[byId[cur].p] and table.getn(before) < 40 do
    cur = byId[cur].p
    seen[cur] = true
    table.insert(before, 1, cur)
  end
  local first = before[1] or id
  local ids = {}
  for _, b in ipairs(before) do table.insert(ids, b) end
  table.insert(ids, id)
  local pos = table.getn(ids)
  cur = id
  local guard = 0
  while followers[cur] and guard < 40 do
    local nxt
    for _, f in ipairs(followers[cur]) do
      if not seen[f] and (not nxt or (byId[f] and byId[first] and byId[f].zone == byId[first].zone)) then nxt = f end
    end
    if not nxt then break end
    seen[nxt] = true
    table.insert(ids, nxt)
    cur = nxt
    guard = guard + 1
  end
  if table.getn(ids) < 2 then return nil end
  return { first = first, ids = ids, pos = pos, len = table.getn(ids) }
end

-- Every quest that needs this one first, on every branch, however far down: abandoning it holds them all back.
local afterMemo = {}
function ER.QuestsAfter(id)
  BuildIndex()
  if afterMemo[id] then return afterMemo[id] end
  local out, seen, queue = {}, { [id] = true }, { id }
  while table.getn(queue) > 0 and table.getn(out) < 200 do
    local cur = table.remove(queue, 1)
    for _, f in ipairs(followers[cur] or {}) do
      if not seen[f] then
        seen[f] = true
        table.insert(out, f)
        table.insert(queue, f)
      end
    end
  end
  afterMemo[id] = out
  return out
end

-- The database has a few absurd experience numbers (custom quests); a quest is never counted for more than
-- a generous amount for its level.
local function XP(q)
  if not q.xp then return 0 end
  return math.min(q.xp, q.l * 120 + 300)
end
ER.QuestXP = XP

-- The chain's total: levels it spans, experience (when known), and whether anything in it gives an item.
function ER.ChainSummary(chain)
  BuildIndex()
  local lo, hi, xp, rewards, names = 99, 0, 0, false, {}
  for _, id in ipairs(chain.ids) do
    local q = byId[id]
    if q then
      if q.l < lo then lo = q.l end
      if q.l > hi then hi = q.l end
      xp = xp + XP(q)
      if q.rw then rewards = true end
      table.insert(names, q.n)
    end
  end
  return { lo = lo, hi = hi, xp = xp, rewards = rewards, names = names }
end

-- A quest's row in the data, by id, and whether it is in your quest log now (the wizard uses both).
function ER.QuestRow(id)
  BuildIndex()
  return byId[id]
end
ER.InLog = InLog


function ER.Mode()
  local key = ER.db and ER.db.mode
  if key == "normal" or key == "everything" then return "hard" end
  if ER.MODES[key] then return key end
  return "casual"
end

function ER.SetMode(key, quiet)
  if not ER.MODES[key] then return end
  ER.db.mode = key
  if not quiet then
    ER.Print("difficulty is now " .. ER.GOLD .. ER.MODES[key].label .. ER.END .. ". " .. ER.MODES[key].tip)
  end
  -- A guide that is running carries on with the new difficulty (Steps.lua asks it at every step).
  if ER.Steps and ER.Steps.Running() then
    ER.Steps.Check()
    if ER.StepsChanged then ER.StepsChanged() end
  end
end

-- Saves made before this version: Hard was saved as "normal", and Everything (every quest, a rating box after each
-- hand-in) is now Hard with the tick "Ask me how hard each quest was". Core.lua calls this once (pfQuest_xpGuideDB.tidy090).
function ER.MigrateMode(db)
  if type(db) ~= "table" then return end
  if db.mode == "normal" then
    db.mode = "hard"
  elseif db.mode == "everything" then
    db.mode = "hard"
    db.autoPrompt = true
  end
end

ER.Loaded("Director.lua")
