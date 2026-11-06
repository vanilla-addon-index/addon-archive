OctoQuestRewards = {}
local A = OctoQuestRewards
local G = getfenv(0)
-- A raw custom base XP cross-check, not the website's potentially scaled Gains.
-- https://octowow.st/db/?quest=41677 (RewXP=2150, level=32, checked 2026-10-05)
local octoBase = { [41677] = {32, 2150} }

-- Only documented, present functions are called. No modern XP API is assumed.
function A.Call(fn, a)
  if type(fn) ~= "function" then return nil end
  local ok, value
  if a == nil then ok, value = pcall(fn) else ok, value = pcall(fn, a) end
  if ok then return value end
end

local function QuestTables()
  local q = pfDB and pfDB.quests
  return q and q.data, q and (q.loc or q[GetLocale()] or q.enUS)
end

local titleIndex, indexedLocale
local function MatchTitle(title, level, description, objectives)
  local data, loc = QuestTables()
  if not data or not loc or not title then return nil end
  if indexedLocale ~= loc then
    titleIndex, indexedLocale = {}, loc
    for id, row in pairs(loc) do
      if type(row) == "table" and row.T and data[id] then
        titleIndex[row.T] = titleIndex[row.T] or {}
        table.insert(titleIndex[row.T], id)
      end
    end
  end
  local found, count = nil, 0
  for _, id in ipairs(titleIndex[title] or {}) do
    local row = data[id]
    if not level or level == row.lvl or row.lvl == -1 then
      found, count = id, count + 1
    end
  end
  if count == 1 then return found, "pfQuest title/level match (inferred ID)" end
  -- Duplicate titles need exact quest text; never pick the first guessed ID.
  found, count = nil, 0
  if pfDatabase and pfDatabase.FormatQuestText then
    for _, id in ipairs(titleIndex[title] or {}) do
      local row = loc[id]
      local d = row.D and pfDatabase:FormatQuestText(row.D)
      local o = row.O and pfDatabase:FormatQuestText(row.O)
      if (not level or level == data[id].lvl or data[id].lvl == -1)
        and ((description and description ~= "" and description == d)
          or (objectives and objectives ~= "" and objectives == o)) then
        found, count = id, count + 1
      end
    end
  end
  if count == 1 then return found, "pfQuest exact text match (inferred ID)" end
end

local function PositiveID(id)
  id = tonumber(id)
  if id and id > 0 then return id end
end

function A.LogTitle(index)
  if pfQuestCompat and pfQuestCompat.GetQuestLogTitle then
    return pfQuestCompat.GetQuestLogTitle(index)
  end
  return GetQuestLogTitle(index)
end

function A.LogID(index, title, level, description, objectives)
  if C_QuestLog and C_QuestLog.GetQuestIDForLogIndex then
    local id = PositiveID(A.Call(C_QuestLog.GetQuestIDForLogIndex, index))
    if id then return id, "C_QuestLog.GetQuestIDForLogIndex" end
  end
  local link = A.Call(G.GetQuestLink, index)
  if type(link) == "string" then
    local _, _, id = string.find(link, "quest:(%d+)")
    if PositiveID(id) then return tonumber(id), "GetQuestLink" end
  end
  return MatchTitle(title, level, description, objectives)
end

-- Vanilla degradation. Octo's server rate/scaling is not verified.
-- Level alone cannot determine base XP: quests at the same level vary widely.
function A.EstimateXP(base, questLevel, playerLevel)
  if type(base) ~= "number" or not questLevel then return nil end
  if playerLevel >= 60 then return 0 end
  if questLevel < 1 then questLevel = playerLevel end
  local difference = playerLevel - questLevel
  local factor = 1
  if A.db.scaling == "full25" then
    -- Optional explicit assumption for Turtle-like custom scaling.
    if difference > 25 then return nil end
  elseif difference >= 10 then factor = 0.1
  elseif difference > 5 then factor = (10 - difference) * 0.2 end
  return math.ceil(base * factor - 0.000001)
end

function A.GetRecord(kind)
  local r = { playerLevel = UnitLevel("player"), kind = kind }
  local index
  if kind == "log" then
    index = GetQuestLogSelection()
    local header
    local tag
    r.title, r.level, tag, header = A.LogTitle(index)
    if not r.title or header then return nil end
    local description, objectives = GetQuestLogQuestText()
    r.id, r.idSource = A.LogID(index, r.title, r.level, description, objectives)
    r.money = A.Call(G.GetQuestLogRewardMoney)
    r.moneySource = "GetQuestLogRewardMoney (server cache)"
  else
    r.title = GetTitleText()
    if not r.title or r.title == "" then return nil end
    -- VoiceOver installs GetQuestID inside its own namespace, not the engine.
    r.id = PositiveID(A.Call(G.GetQuestID))
    if r.id then r.idSource = "GetQuestID (provider unverified)" end
    if not r.id then
      r.id, r.idSource = MatchTitle(r.title, nil,
        kind == "detail" and GetQuestText() or nil,
        kind == "detail" and GetObjectiveText() or nil)
    end
    if kind == "progress" then
      -- REQUEST_ITEMS packets don't supply reward money: GetRewardMoney here
      -- can be stale. Read only a uniquely matching accepted quest instead.
      local match, count = nil, 0
      for i = 1, GetNumQuestLogEntries() do
        local title, level, tag, header = A.LogTitle(i)
        if title == r.title and not header then match, count = i, count + 1 end
      end
      if count == 1 then
        local old = GetQuestLogSelection()
        SelectQuestLogEntry(match)
        local log = A.GetRecord("log")
        SelectQuestLogEntry(old)
        if log then
          r.id, r.idSource, r.level = log.id, log.idSource, log.level
          r.money, r.moneySource = log.money, log.moneySource
        end
      end
    else
      r.money = A.Call(G.GetRewardMoney)
      r.moneySource = "GetRewardMoney (NPC server packet)"
    end
  end
  local data = QuestTables()
  if not r.level and data and r.id and data[r.id] then r.level = data[r.id].lvl end
  local cache
  if r.id and C_QuestLog and C_QuestLog.GetQuestDetails then
    cache = A.Call(C_QuestLog.GetQuestDetails, r.id)
    if type(cache) == "table" then
      r.level = cache.level or r.level
      if r.money == nil and r.playerLevel < 60 then
        r.money, r.moneySource = cache.rewardMoney, "C_QuestLog.GetQuestDetails.rewardMoney"
      end
    end
  end
  if r.money and r.money < 0 then r.money = 0 end -- A cost isn't a reward.
  local reward = r.id and PfExtend_QuestRewards and PfExtend_QuestRewards[r.id]
  local baseline = r.id and (octoBase[r.id] or (A.VanillaXP and A.VanillaXP[r.id]))
  local base
  if baseline and (baseline[1] == r.level or baseline[1] == -1) then
    base = baseline[2]
    r.xpSource = (octoBase[r.id] and "Octo DB raw RewXP" or "LibQuestXP Vanilla baseline")
      .. " + " .. A.db.scaling .. " scaling; rate assumed 1x; Octo match unverified"
  elseif not reward and type(cache) == "table" and type(cache.rewardMoneyAtMaxLevel) == "number" then
    -- Classic cache has no XP field. This is the historical Vanilla conversion,
    -- NOT a directly supplied XP value, and may differ on custom quests.
    if r.level and r.level <= 60 then
      base = cache.rewardMoneyAtMaxLevel / 0.6
      r.xpSource = "ClassicAPI max-level money / 0.6 + " .. A.db.scaling .. " scaling (estimated)"
    end
  end
  r.baseXP = base
  r.xp = A.EstimateXP(base, r.level, r.playerLevel)
  if base == nil and reward and type(reward.xp) == "number" then
    -- The installed pfExtend scraper copies displayed Gains, not raw RewXP.
    -- We cannot undo unknown website scaling. Use it only as a near-level
    -- reference, with no second scaling; suppress it on overlevelled quests.
    r.xpSource = "pfExtend website Gains reference; base XP/scaling unverified"
    if r.playerLevel >= 60 then r.xp = 0
    elseif r.level and (r.level < 1 or r.playerLevel <= r.level + 5) then r.xp = reward.xp end
  end
  r.idSource = r.idSource or "unresolved/ambiguous ID"
  r.xpSource = r.xpSource or "unavailable"
  if r.id then A.predictions[r.id] = r end
  return r
end
