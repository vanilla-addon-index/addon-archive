-- pfQuest xpGuide: the guide engine. It reads one of RestedXP's leveling guides (Data\Guides.lua), keeps the steps that
-- are for this character, and moves through them by itself: a step is done when its quests are accepted, finished
-- or handed in, its level is reached, its place is reached, and so on. Windows live in Tracker.lua and Arrow.lua;
-- this file only decides, so it can be tested away from the game.
--
-- A guide's steps come as one string (built by tools/build-guides.js), one item per line, fields split by tabs:
--   S  need  not  flags                  a new step: who it is for, who it is not for, and its flags
--   G  cond  zone x y radius flag text   a place (flag 0: a point on the way, not the end)
--   A/T cond questId text                accept / hand in a quest
--   C  cond questId objective text       finish a quest (or one of its objectives)
--   K  cond itemId count questId text    have this many of an item
--   X  cond < level xp skip text         reach a level (skip: only skip the step when you are past it)
--   H/B/P/F/Z/V/M/R/U/I                  hearth, set hearth, flight path, fly, zone, vendor or trainer, tick by
--                                        hand, abandon, use an item, plain text
--   Q/W/SW/L/N                           only do the step when: on a quest / not in a zone / below a level / ...
-- "cond" is RestedXP's own condition ("Human Warrior", "!Hunter", "Alliance/Horde", "20"), checked by Applies.

local ER = pfQuest_xpGuide
local S = {}
ER.Steps = S

local guide = nil        -- the guide being followed: { info, steps = { ... }, labels = { name = index } }
local state = nil        -- saved progress for this character: ER.db.guides[char]
local live = { fired = {}, holdAt = nil, bags = nil, bindAt = nil, startZone = nil }
local GOLDISH = "|cffffd100"

------------------------------------------------------------------------------------------------------
-- Who you are, and RestedXP's conditions
------------------------------------------------------------------------------------------------------

local RACE_ALIAS = { Undead = "Scourge" }
local LATER_GAMES = { TBC = true, WOTLK = true, CATA = true, MOP = true, RETAIL = true, DF = true, SOD = true, SOM = true }

-- The race's token, the same however the server spells it: "High Elf" and "BloodElf" (pfQuest-turtle's name for race bit 512) are
-- the HighElf of the guides' conditions.
local RACE_TOKEN = { BloodElf = "HighElf" }
function S.RaceToken(race)
  race = string.gsub(tostring(race or ""), "%s+", "")
  return RACE_TOKEN[race] or race
end

local function Me()
  local _, race = UnitRace("player")
  race = S.RaceToken(race)
  local _, class = UnitClass("player")
  return race or "", class or "", UnitFactionGroup("player") or "Alliance", UnitLevel("player") or 1
end

local cache = {}
local function Entry(entry, race, class, faction, level)
  entry = RACE_ALIAS[entry] or entry
  local up = string.upper(entry)
  if up == "CLASSIC" or up == "ENUS" then return true end
  if LATER_GAMES[up] then return false end
  local n = tonumber(entry)
  if n then return level >= n end
  -- the experience rate and the professions (Character.lua)
  local w = ER.CondWord and ER.CondWord(entry)
  if w ~= nil then return w end
  return up == class or entry == race or entry == faction
end

local function Parse(text, race, class, faction, level)
  -- (a b) and !(a b): worked out first, then read as one word.
  text = string.gsub(text, "(!?)%(%s*(.-)%s*%)", function(op, inner)
    local v = Parse(inner, race, class, faction, level)
    if op == "!" then v = not v end
    return v and " CLASSIC " or " NULL "
  end)
  for part in string.gfind(text, "[^/]+") do
    local all = true
    for entry in string.gfind(part, "!?[%w_]+") do
      local neg = string.sub(entry, 1, 1) == "!"
      if neg then entry = string.sub(entry, 2) end
      local v = Entry(entry, race, class, faction, level)
      if neg then v = not v end
      if not v then all = false break end
    end
    if all then return true end
  end
  return false
end

-- Does a RestedXP condition fit this character? An empty one always does.
function S.Applies(text)
  if not text or text == "" then return true end
  local race, class, faction, level = Me()
  local key = text .. "#" .. level .. race .. class .. faction .. (ER.CondSig and ER.CondSig() or "")
  if cache[key] == nil then cache[key] = Parse(text, race, class, faction, level) end
  return cache[key]
end

------------------------------------------------------------------------------------------------------
-- Quests: titles, the quest log, and what has been handed in
------------------------------------------------------------------------------------------------------

function S.QuestTitle(id)
  id = tonumber(id)
  if not id then return nil end
  local t = pfQuest_xpGuide_GuideQuests and pfQuest_xpGuide_GuideQuests[id]
  if t then return t end
  local row = ER.QuestRow and ER.QuestRow(id)
  if row and row.n then return row.n end
  -- pfQuest's own quest names (its database has the server's own quests too, e.g. pfQuest-turtle)
  local loc = pfDB and pfDB.quests and (pfDB.quests.loc or pfDB.quests.enUS)
  local q = type(loc) == "table" and rawget(loc, id)   -- pfQuest's table as stored (no lookups through other code)
  if type(q) == "table" and type(q.T) == "string" and q.T ~= "" then return q.T end
  return nil
end

-- Words with quest tags ({q456}, from Bethink's guides) get the quest's name.
local function QuestWords(text)
  if not text or not string.find(text, "{q", 1, true) then return text end
  return (string.gsub(text, "{q(%d+)}", function(id) return S.QuestTitle(id) or ("quest " .. id) end))
end
S.QuestWords = QuestWords

local function Log()
  return (ER.Recorder and ER.Recorder.Known and ER.Recorder.Known()) or {}
end

local function DoneTable()
  if not ER.db then return {} end
  if type(ER.db.done) ~= "table" then ER.db.done = {} end
  local c = ER.Char()
  if type(ER.db.done[c]) ~= "table" then ER.db.done[c] = {} end
  return ER.db.done[c]
end

-- Titles more than one quest of the current guide shares ("The Tome of Valor", parts 1 and 2): for those only
-- the quest's own number counts as handed in, never the title.
local function Shared(title)
  return guide and guide.shared and guide.shared[title]
end

-- A quest in your log counts by its title. For a title several quests of the guide share ("Fields of Grief",
-- parts 1 and 2), the log's quest is this one only when its number (from pfQuest) says so; with no number known,
-- when this one is not handed in yet and the log's quest level is this one's (parts 1 and 2 almost always differ in level).
function S.InLog(id)
  local title = S.QuestTitle(id)
  local row = title and Log()[title]
  if not row or not Shared(title) then return row or nil end
  id = tonumber(id)
  local pfid = tonumber(row.pfid)
  if pfid and pfQuest_xpGuide_GuideQuests and pfQuest_xpGuide_GuideQuests[pfid] == title then
    return pfid == id and row or nil
  end
  if DoneTable()[id] then return nil end
  local want, have = S.QuestLevel(id), tonumber(row.qlevel)
  if want and have and have > 0 and have ~= want then return nil end
  return row
end

-- The quests that need a quest handed in first (its followers), from the starting guides' quest data (Data\FastRoute.lua).
local followers
local function Followers()
  if followers then return followers end
  followers = {}
  for id, p in pairs(pfQuest_xpGuide_QuestPre or {}) do
    followers[p] = followers[p] or {}
    table.insert(followers[p], id)
  end
  -- (not the addon's own quest data: its "previous quest" can be a lead-in the next quest does not need, so a follow-up picked
  -- up would wrongly count it as done)
  return followers
end

local Recorded
-- A quest is done when a later quest of its chain is in your log or handed in: the game offers that one only after it. So a
-- character who played a starting guide before pfQuest kept a record still has the chain behind it counted as done.
local function DoneByLater(id, depth)
  local f = Followers()[id]
  if not f or depth > 12 then return false end
  for _, n in ipairs(f) do
    if S.InLog(n) or Recorded(n) or DoneByLater(n, depth + 1) then return true end
  end
  return false
end

-- (asked often, for every step: the answers of one frame are kept for that frame)
local laterAt, laterCache = nil, {}
function S.TurnedIn(id)
  id = tonumber(id)
  if Recorded(id) then return true end
  if not id or not Followers()[id] then return false end
  local now = GetTime and GetTime() or 0
  if now ~= laterAt then laterAt, laterCache = now, {} end
  local v = laterCache[id]
  if v == nil then
    v = DoneByLater(id, 0)
    laterCache[id] = v
  end
  return v
end

Recorded = function(id)
  id = tonumber(id)
  local done = DoneTable()
  if done[id] then return true end
  -- pfQuest's own record of what this character handed in, for quests done before pfQuest xpGuide was installed (or
  -- while it was off): those steps already count as done, so the zone's count must see them too
  local history = getglobal and getglobal("pfQuest_history")
  if id and type(history) == "table" and history[id] ~= nil then return true end
  local title = S.QuestTitle(id)
  if not title or Shared(title) then return false end
  return done[title] and not Log()[title] and true or false
end

-- A quest title tidied for comparing: no colour codes, lower case, single spaces, no spaces at the ends.
local function NormTitle(s)
  if type(s) ~= "string" then return "" end
  s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
  s = string.gsub(s, "|r", "")
  s = string.gsub(s, "^%[[%d%?%+%-]*%]%s*", "")
  s = string.lower(s)
  s = string.gsub(s, "%s+", " ")
  s = string.gsub(s, "^ ", "")
  s = string.gsub(s, " $", "")
  return s
end

-- An Accept step whose quest is in the log under a slightly different spelling (case, double spaces) or another quest
-- number: the tidied titles are compared. Not for titles two quests of this guide share.
function S.AcceptInLog(e)
  if not e then return false end
  local want = {}
  local dataTitle = S.QuestTitle(e.id)
  if dataTitle then
    if Shared(dataTitle) then return false end
    want[NormTitle(dataTitle)] = true
  end
  if type(e.text) == "string" then
    local words = string.gsub(e.text, "^Accept%s+", "")
    want[NormTitle(words)] = true
  end
  want[""] = nil
  for title in pairs(Log()) do
    if want[NormTitle(title)] then return true end
  end
  return false
end

-- The quest's line in the quest log, for its objectives.
local function LogIndex(title)
  local n = GetNumQuestLogEntries() or 0
  for i = 1, n do
    local t, _, _, isHeader = GetQuestLogTitle(i)
    if t == title and not isHeader then return i end
  end
  return nil
end
S.LogIndex = LogIndex

-- Every objective of a quest in your log: { { text = "Tough Wolf Meat: 3/8", done = false }, ... }.
function S.Objectives(title)
  local out = {}
  local index = title and LogIndex(title)
  if not index then return out end
  local n = GetNumQuestLeaderBoards and GetNumQuestLeaderBoards(index) or 0
  for j = 1, n do
    local text, _, finished = GetQuestLogLeaderBoard(j, index)
    if text then table.insert(out, { text = text, done = finished and true or false }) end
  end
  return out
end

-- One objective of a quest in your log: its text ("Tough Wolf Meat: 3/8") and whether it is done.
function S.Objective(id, obj)
  local title = S.QuestTitle(id)
  local index = title and LogIndex(title)
  if not index then return nil, false end
  local text, _, finished = GetQuestLogLeaderBoard(tonumber(obj) or 1, index)
  return text, finished and true or false
end

-- What is still to do on a quest in your log: the texts of its open objectives ("Bleeding Horror slain: 0/8"), or nil
-- when it is finished or not in the log. A quest with no objectives to show (take a letter somewhere) counts as finished.
local function LeftToDo(id)
  local row = S.InLog(id)
  if not row or row.complete then return nil end
  local open = {}
  for _, o in ipairs((S.Objectives(S.QuestTitle(id)))) do
    if not o.done then table.insert(open, o.text) end
  end
  if table.getn(open) == 0 then return nil end
  return open
end
S.LeftToDo = LeftToDo

------------------------------------------------------------------------------------------------------
-- Bags, level, places
------------------------------------------------------------------------------------------------------

local function CountItems()
  local counts = {}
  for bag = 0, 4 do
    local slots = GetContainerNumSlots(bag) or 0
    for slot = 1, slots do
      local link = GetContainerItemLink(bag, slot)
      if link then
        local _, _, id = string.find(link, "item:(%d+)")
        local _, count = GetContainerItemInfo(bag, slot)
        id = tonumber(id)
        if id then counts[id] = (counts[id] or 0) + (count or 1) end
      end
    end
  end
  return counts
end

function S.ItemCount(id)
  if not live.bags then live.bags = CountItems() end
  return live.bags[tonumber(id) or 0] or 0
end

-- Is the character at this level, plus (or minus) some experience? xp: "+1000", "-500", ".5" or "".
local function Reached(level, xp)
  local now = UnitLevel("player") or 1
  level = tonumber(level) or 0
  if now ~= level then
    if xp and string.sub(xp, 1, 1) == "-" and now == level - 1 then
      local need = tonumber(string.sub(xp, 2)) or 0
      return (UnitXPMax("player") or 0) - (UnitXP("player") or 0) <= need
    end
    return now > level
  end
  if not xp or xp == "" or string.sub(xp, 1, 1) == "-" then return true end
  if string.sub(xp, 1, 1) == "." then
    return (UnitXP("player") or 0) >= (tonumber("0" .. xp) or 0) * (UnitXPMax("player") or 1)
  end
  return (UnitXP("player") or 0) >= (tonumber(xp) or 0)
end
S.Reached = Reached

-- Quest levels against yours. A quest turns grey (too easy, next to no experience) the way the game colours
-- them: nothing up to level 5, then your level minus 5 and a tenth of it, from 40 your level minus 1 and a fifth.
local function GreyLevel(level)
  if level <= 5 then return 0 end
  if level < 40 then return level - 5 - math.floor(level / 10) end
  return level - 1 - math.floor(level / 5)
end
S.GreyLevel = GreyLevel

function S.QuestLevel(id)
  local row = ER.QuestRow and ER.QuestRow(tonumber(id))
  return row and row.l and row.l > 0 and row.l or nil
end

function S.TooEasy(id)
  local l = S.QuestLevel(id)
  return l ~= nil and l <= GreyLevel(UnitLevel("player") or 1)
end

-- How many levels above you a quest may be before the guide warns about it: the difficulty's own number, moved
-- up or down by what you answered when asked how it is going (Adapt.lua).
local COMFORT = { casual = 2, medium = 3, hard = 4 }
function S.Comfort()
  local mode = ER.Mode and ER.Mode() or "casual"
  local c = (COMFORT[mode] or 3) + (ER.AdaptShift and ER.AdaptShift() or 0)
  if c < 1 then c = 1 end
  return c
end

-- How many levels above you a quest is, when that is more than you are comfortable with; nil when it is fine.
function S.TooHard(id)
  local l = S.QuestLevel(id)
  if not l then return nil end
  local over = l - (UnitLevel("player") or 1)
  if over > S.Comfort() then return over end
  return nil
end

local function SameText(a, b)
  return a and b and string.lower(a) == string.lower(b)
end

local function InZone(list)
  local zone, sub = GetZoneText() or "", (GetSubZoneText and GetSubZoneText()) or ""
  for name in string.gfind(list or "", "[^,]+") do
    if SameText(name, zone) or SameText(name, sub) then return true end
  end
  return false
end

-- Yards between two map points in one zone (map percent), using the zone's size.
function S.Yards(zone, x1, y1, x2, y2)
  local size = pfQuest_xpGuide_ZoneSizes and pfQuest_xpGuide_ZoneSizes[zone]
  local w, h = 4000, 2667
  if size then w, h = size[1], size[2] end
  local dx, dy = (x2 - x1) / 100 * w, (y2 - y1) / 100 * h
  return math.sqrt(dx * dx + dy * dy), dx, dy
end

-- Yards, and the way east and south, from a place in one zone to a place in another zone of the same continent. Data\ZoneSizes.lua gives each
-- zone c (continent), l and t (its left and top edge in world yards): l grows to the west and t to the north, so a place's west
-- coordinate is l - x / 100 * width and its north coordinate is t - y / 100 * height. Returns yards, east, south (east below 0: the place is
-- to the west; south below 0: to the north), or nil when a zone has no such numbers or the zones are on other continents.
-- The signs come from the data only and have not been tried in the game.
function S.CrossYards(zone1, x1, y1, zone2, x2, y2)
  local sizes = pfQuest_xpGuide_ZoneSizes
  local a, b = sizes and sizes[zone1], sizes and sizes[zone2]
  if not (a and b and a.c and a.l and a.t and b.c and b.l and b.t) or a.c ~= b.c then return nil end
  local east = (a.l - x1 / 100 * a[1]) - (b.l - x2 / 100 * b[1])
  local south = (a.t - y1 / 100 * a[2]) - (b.t - y2 / 100 * b[2])
  return math.sqrt(east * east + south * south), east, south
end

-- Where you stand: zone and map position, read at most ten times a second (the arrow asks far more often).
local hereAt, hereZone, hereX, hereY
function S.Here()
  local now = GetTime()
  -- With the world map open the game gives your place on the map being looked at, which may be another zone
  -- or the whole continent: keep the last place read with the map closed.
  if hereAt and WorldMapFrame and WorldMapFrame:IsVisible() then return hereZone, hereX, hereY end
  if not hereAt or now - hereAt > 0.1 or now < hereAt then
    local zone, _, x, y = ER.Where()
    hereZone, hereX, hereY, hereAt = zone, x, y, now
  end
  return hereZone, hereX, hereY
end

-- How far you are from a point: yards, or nil when it is in another zone (or the map cannot tell).
function S.DistanceTo(zone, x, y)
  local here, px, py = S.Here()
  if not SameText(here, zone) or (px == 0 and py == 0) then return nil end
  return (S.Yards(zone, px, py, x, y))
end

------------------------------------------------------------------------------------------------------
-- Reading a guide
------------------------------------------------------------------------------------------------------

local function Split(line)
  local out, pos = {}, 1
  while true do
    local s, e = string.find(line, "\t", pos, true)
    if not s then
      table.insert(out, string.sub(line, pos))
      break
    end
    table.insert(out, string.sub(line, pos, s - 1))
    pos = e + 1
  end
  return out
end

local function Flags(text)
  local f = {}
  for pair in string.gfind(text or "", "[^;]+") do
    local _, _, k, v = string.find(pair, "^([^=]+)=(.*)$")
    if k then f[k] = v end
  end
  return f
end

-- Element fields by kind, after the kind and the condition.
local FIELDS = {
  G = { "zone", "x", "y", "radius", "flag", "text" }, A = { "id", "text" }, T = { "id", "text" },
  C = { "id", "obj", "text" }, K = { "item", "count", "id", "text" }, X = { "op", "level", "xp", "skip", "text" },
  L = { "level", "xp" }, Q = { "test", "ids" }, W = { "zones", "flag" }, SW = { "zones", "flag" },
  N = { "items", "op", "total" }, H = { "text" }, B = { "text" }, P = { "name", "text" }, F = { "dest", "text" },
  Z = { "zone", "text" }, V = { "what", "text" }, M = { "text" }, R = { "id", "text" }, U = { "item", "text" },
  I = { "text" },
}
local NUMBERS = { x = true, y = true, radius = true, id = true, obj = true, item = true, count = true, level = true, total = true }

-- Mode filters: Casual and Medium leave group quests out (and keep the way round them), Hard does them.
local function GroupsOn()
  local mode = ER.Mode and ER.Mode()
  return mode == "hard"
end

local function EliteQuest(id)
  local row = ER.QuestRow and ER.QuestRow(id)
  return row and row.e and true or false
end

-- Every step of the guide stays in the list, numbered as in the guide, so the saved place still fits after a
-- level-up or a change of difficulty. Whether a step is for you is asked as you get to it (Fits, below). The
-- lines inside a step that are for another race or class are left out here.
local function ParseSteps(info)
  local steps, labels, shared, titles, turnins = {}, {}, {}, {}, {}
  local step
  for line in string.gfind(info.steps, "[^\n]+") do
    local f = Split(line)
    local kind = f[1]
    if kind == "S" then
      local nots = {}
      for nope in string.gfind(f[3] or "", "[^|]+") do table.insert(nots, nope) end
      step = { flags = Flags(f[4]), need = f[2] or "", nots = nots, elements = {}, n = table.getn(steps) + 1 }
      table.insert(steps, step)
      if step.flags.label then labels[step.flags.label] = step.n end
    elseif step and FIELDS[kind] and S.Applies(f[2]) then
      local e = { kind = kind }
      for i, name in ipairs(FIELDS[kind]) do
        local v = f[i + 2]
        if v == "" then v = nil end
        if v and NUMBERS[name] then v = tonumber(v) or v end
        -- RestedXP writes 0 or -1 for "no radius".
        if name == "radius" and type(v) == "number" and v <= 0 then v = nil end
        e[name] = v
      end
      table.insert(step.elements, e)
      if kind == "T" and type(e.id) == "number" and not turnins[e.id] and S.Applies(step.need) then turnins[e.id] = step.n end
      if e.id and (kind == "A" or kind == "T" or kind == "C") then
        local title = S.QuestTitle(e.id)
        if title then
          if titles[title] and titles[title] ~= e.id then shared[title] = true end
          titles[title] = e.id
        end
      end
    end
  end
  return steps, labels, shared, turnins
end

local function Plain(text)
  text = string.gsub(text or "", "|c%x%x%x%x%x%x%x%x", "")
  return (string.gsub(text, "|r", ""))
end

-- Lines that only send you farming money (RestedXP's "loot them until you have 10 copper worth of vendor items").
-- Left out when you said you have money on another character (Adapt.lua asks).
local MONEY = { "worth of vendor", "of vendor trash", "vendor trash/money", "grind money", "copper worth", "silver worth" }
local function MoneyText(text)
  if not text then return false end
  local t = string.lower(Plain(text))
  for _, p in ipairs(MONEY) do
    if string.find(t, p, 1, true) then return true end
  end
  return false
end
S.MoneyText = MoneyText

local function HasMoney()
  return ER.HasMoney and ER.HasMoney() or false
end

-- A step that is only there to farm money: all its words are about money and there is nothing else to do in it.
local function MoneyStep(step)
  local any = false
  for _, e in ipairs(step.elements) do
    local k = e.kind
    if k == "M" or k == "I" then
      if not MoneyText(e.text) then return false end
      any = true
    elseif k ~= "G" and k ~= "W" and k ~= "SW" and k ~= "L" and k ~= "Q" and k ~= "N" then
      return false
    end
  end
  return any
end

-- What the difficulty leaves out, as one table for the casual route and for every other guide. Each quest has letters:
--   e  an elite to kill        g  a group quest           d  an objective only inside a dungeon
--   s  an escort               v  the safe route skips it
--   h  the friends found it Hard (Data\Ratings.lua)       m  Hard for this character (what the addon learned)
-- LEAVE_OUT says which letters leave a quest out on each difficulty. A quest with an objective only inside a dungeon (d) is out on
-- every difficulty (the route builder already drops quests that are only a dungeon).
S.LEAVE_OUT = { casual = "egdsvhm", medium = "egdhm", hard = "d" }

-- True when any of the letters is one the difficulty leaves out. No difficulty counts as Casual.
function S.LeftByKinds(letters, mode)
  local out = S.LEAVE_OUT[mode or "casual"]
  if not out or not letters then return false end
  for i = 1, string.len(letters) do
    if string.find(out, string.sub(letters, i, i), 1, true) then return true end
  end
  return false
end

-- The letters of a quest for this character, for any guide: the danger table (Data\Danger.lua) for the character's faction, then h
-- (friends' Hard) when the table did not give it, then m (learned Hard).
function S.Kinds(id)
  local letters = ""
  id = tonumber(id)
  if not id then return letters end
  local danger = pfQuest_xpGuide_Danger
  if type(danger) == "table" and type(danger.danger) == "table" then
    local _, _, faction = Me()
    local byId = danger.danger[faction]
    if type(byId) == "table" and type(byId[id]) == "string" then letters = byId[id] end
  end
  if not string.find(letters, "h", 1, true) and type(pfQuest_xpGuide_Ratings) == "table" and type(pfQuest_xpGuide_Ratings.hard) == "table" and pfQuest_xpGuide_Ratings.hard[id] then
    letters = letters .. "h"
  end
  if ER.LearnedHard and ER.LearnedHard(id) then letters = letters .. "m" end
  return letters
end

-- An escort quest: the player has to walk someone through a fight, so the addon never accepts it for them.
function S.Escort(id)
  return string.find(S.Kinds(id), "s", 1, true) ~= nil
end

-- True when a quest waits for a quest before it that the difficulty leaves out (a follow-up of a left-out quest is out too: the NPC would
-- never offer it). The chain is followed up through the quest rows; a quest in your log or handed in ends the walk, because then the way
-- on is open. The casual route does this itself (ER.RouteLeftOut).
local function ChainLeftOut(id, mode)
  local at = id
  for _ = 1, 20 do
    local row = ER.QuestRow and ER.QuestRow(at)
    local p = row and row.p
    if not p then return false end
    if S.InLog(p) or S.TurnedIn(p) then return false end
    if S.LeftByKinds(S.Kinds(p), mode) then return true end
    at = p
  end
  return false
end

-- A quest the difficulty or your level leaves out: one the table above names, one with an elite to kill on Casual, or one too
-- easy for you. The casual route adds its own leave-outs (quests of a zone you are past).
-- A quest you already have always stays.
local function LeftOut(id)
  if S.InLog(id) then return false end
  if ER.RouteLeftOut and ER.RouteLeftOut(id) then return true end
  local mode = ER.Mode and ER.Mode()
  if S.LeftByKinds(S.Kinds(id), mode) then return true end
  local info = guide and guide.info
  if not (info and info.route) and ChainLeftOut(id, mode) then return true end
  if (mode == "casual" or (mode == "medium" and info and info.fast)) and EliteQuest(id) then return true end
  -- a quest the guide's catch-up steps need (from the guide before) is not too easy: the chain goes on from it
  if guide and guide.needed and guide.needed[tonumber(id)] then return false end
  return S.TooEasy(id)
end
S.LeftOut = LeftOut

-- Handed in as pfQuest saw it (its own list of quests this character handed in), for quests done before pfQuest xpGuide was there.
local function PfDone(id)
  local history = getglobal and getglobal("pfQuest_history")
  return type(history) == "table" and history[id] ~= nil
end

-- A quest the game will not offer you yet: you are below its lowest level, or the quest before it in its chain is not handed in
-- although this guide hands it in at an earlier step. The guide decides the order: a quest before it that the guide hands in only
-- later, or never, does not count (the data can be wrong, or it was done before the addon knew). A hand-in of that quest earlier in
-- the same step counts when the quest is in your log, so a step "hand in X, accept the next one" still waits for the next one.
-- A step is only judged when you get to it, so the list of steps to come still shows it. The casual route waits for the level with
-- a grind bridge, so there only the quest before counts.
local function NotYet(id, step)
  id = tonumber(id)
  if not id or id == 0 or S.InLog(id) or S.TurnedIn(id) then return false end
  if step and state and step.n and step.n > state.pos then return false end
  local row = ER.QuestRow and ER.QuestRow(id)
  if not row then return false end
  local info = guide and guide.info
  if row.m and not (info and info.route) and (UnitLevel("player") or 1) < row.m then return true end
  local p = tonumber(row.p)
  if not p or p == id or S.TurnedIn(p) or PfDone(p) then return false end
  local at = guide and guide.turnins and guide.turnins[p]
  if not at then return false end
  if not (step and step.n) then return true end
  for _, e in ipairs(step.elements) do
    if e.kind == "A" and tonumber(e.id) == id then break end
    if e.kind == "T" and tonumber(e.id) == p then return not S.InLog(p) end
  end
  return at < step.n
end
S.NotYet = NotYet

-- A quest in your log that this guide hands in at a step still ahead of you (the first one), or nil. Moving on to the next guide before
-- that hand-in would leave its follow-up quests unoffered: the next guide's first steps often pick them up.
function S.HandInAhead()
  if not guide or not state then return nil end
  for i = state.pos, table.getn(guide.steps) do
    local step = guide.steps[i]
    if S.Fits(step) then
      for _, e in ipairs(step.elements) do
        if e.kind == "T" and e.id and S.InLog(e.id) and not S.TurnedIn(e.id) then return tonumber(e.id) end
      end
    end
  end
  return nil
end

-- A quest in your log, not finished yet, that this guide hands in at a step still ahead of you (the move-on question waits for it:
-- moving on would leave its follow-ups behind); nil when there is none.
function S.UnfinishedHandInAhead()
  if not guide or not state then return nil end
  for i = state.pos, table.getn(guide.steps) do
    local step = guide.steps[i]
    if not state.passed[i] and S.Fits(step) then
      for _, e in ipairs(step.elements) do
        local id = tonumber(e.id)
        if e.kind == "T" and id and not S.TurnedIn(id) then
          local row = S.InLog(id)
          if row and not (row.complete or not row.obj or table.getn(row.obj) == 0) then return id end
        end
      end
    end
  end
  return nil
end

-- The quests in your log that are finished (or have nothing to do, as a delivery) and that this guide hands in at a step still
-- ahead of you: { { n = step, id, title }, ... } in the guide's order, each quest once. The move-on question lists them.
function S.ReadyHandIns()
  local out, seen = {}, {}
  if not guide or not state then return out end
  for i = state.pos, table.getn(guide.steps) do
    local step = guide.steps[i]
    if not state.passed[i] and S.Fits(step) then
      for _, e in ipairs(step.elements) do
        local id = tonumber(e.id)
        if e.kind == "T" and id and not seen[id] and not S.TurnedIn(id) then
          local row = S.InLog(id)
          if row and (row.complete or not row.obj or table.getn(row.obj) == 0) then
            seen[id] = true
            table.insert(out, { n = i, id = id, title = S.QuestTitle(id) })
          end
        end
      end
    end
  end
  return out
end

-- An accept line the game will not offer yet, unless the quest is already in your log under another spelling.
local function Blocked(e, step)
  return NotYet(e.id, step) and not S.AcceptInLog(e)
end

-- The guide sends you to your class trainer at levels 10, 20, 30, 40, 50 and 60 only (the owner's wish): a training line
-- ("Train your class spells", "Train [Shadow Bolt]") at any other level is left out. Professions (First Aid and the like)
-- are not class training and always stay. The guide's own trainer steps (classtrain=1, every 4 levels where the route passes
-- your class trainer: tools/build_fastroute.py) always stay too.
local PROFESSIONS = { "First Aid", "Cooking", "Fishing", "Mining", "Herbalism", "Skinning", "Tailoring", "Engineering",
  "Alchemy", "Blacksmithing", "Leatherworking", "Enchanting", "Riding" }
local function LateTrainer(e, step)
  if e.kind ~= "V" or e.what == "vendor" then return false end
  if step and step.flags.classtrain then return false end
  if math.mod(UnitLevel("player") or 1, 10) == 0 then return false end
  local text = string.gsub(e.text or "", "|c%x%x%x%x%x%x%x%x", "")
  if not string.find(text, "^Train") then return false end
  for _, name in ipairs(PROFESSIONS) do
    if string.find(text, name, 1, true) then return false end
  end
  return true
end
S.LateTrainer = LateTrainer

-- A step that is only a trainer visit left out by LateTrainer (with its place and its "Talk to" line).
local function OnlyLateTrainer(step)
  local late = false
  for _, e in ipairs(step.elements) do
    local k = e.kind
    if k == "V" then
      if not LateTrainer(e, step) then return false end
      late = true
    elseif not (k == "G" or k == "I" or k == "Q" or k == "W" or k == "SW" or k == "L" or k == "N"
      or (k == "X" and (e.skip or e.op == "<"))) then
      return false
    end
  end
  return late
end

-- Does the step have more to do than picking quests up? (A hand-in or objectives of a quest you have.)
local function OtherWork(step)
  for _, e in ipairs(step.elements) do
    if (e.kind == "T" or e.kind == "C" or e.kind == "K") and e.id and e.id ~= 0 and S.InLog(e.id) then return true end
  end
  return false
end

-- Is this step for you? Its race, class and faction, and the difficulty: Casual and Medium leave group quests out
-- (and take RestedXP's way round them), Hard does them. A step that only picks up quests that are left out
-- (LeftOut) or that the game will not offer yet (NotYet) goes too, and the rest of those quests skip themselves
-- because they are never in the log. With money on another character, the money-farming steps go.
local function Fits(step)
  if table.getn(step.elements) == 0 then return false end
  if not S.Applies(step.need) then return false end
  if OnlyLateTrainer(step) then return false end
  -- A step the casual route made with its own condition (RouteRun.lua).
  if step.flags.rt and ER.RouteStepOut and ER.RouteStepOut(step) then return false end
  for _, nope in ipairs(step.nots) do
    if S.Applies(nope) then return false end
  end
  local groups = GroupsOn()
  if step.flags.group and not groups then return false end
  if step.flags.solo and groups then return false end
  local accepts, out = 0, 0
  for _, e in ipairs(step.elements) do
    if e.kind == "A" then
      accepts = accepts + 1
      if LeftOut(e.id) or Blocked(e, step) then out = out + 1 end
    end
  end
  if accepts > 0 and out == accepts and not OtherWork(step) then return false end
  if HasMoney() and MoneyStep(step) then return false end
  return true
end
S.Fits = Fits

-- A step that picks up a quest only because it is too easy for you now is left out.
local function EasyStep(step)
  if step.flags.catchup then return false end
  for _, e in ipairs(step.elements) do
    if e.kind == "A" and S.TooEasy(e.id) and not S.InLog(e.id) then return true end
  end
  return false
end

------------------------------------------------------------------------------------------------------
-- The list of guides
------------------------------------------------------------------------------------------------------

local function Key(info)
  return info.group .. "\\" .. info.name
end
S.Key = Key

-- The guides for this character: their faction, and RestedXP's own "who is this for".
function S.Guides()
  local _, _, faction = Me()
  local out = {}
  for _, g in ipairs(pfQuest_xpGuide_Guides or {}) do
    if g.faction == faction and S.Applies(g.cond) then table.insert(out, g) end
  end
  for _, g in ipairs(ER.RouteGuides and ER.RouteGuides() or {}) do table.insert(out, g) end
  return out
end

-- Which family a guide belongs to: "xproute" (the xpGuide Fast route, the addon's guide) or "fast" (RestedXP's original Fast route,
-- the fallback). 2.0.0 retired the others (the casual route, xpGuide Fast, Bethink's Guide, VanillaGuide).
function S.Kind(g)
  if not g then return nil end
  return g.xproute and "xproute" or "fast"
end

-- RestedXP's original guides are the fallback: they sit in their own folder in the guide list.
function S.Fallback(g)
  return S.Kind(g) == "fast"
end

-- The guides grouped the way RestedXP's menu shows them: { { name, lo, guides = { ... } }, ... }.
function S.Groups()
  local groups, byName = {}, {}
  for _, g in ipairs((S.Guides())) do
    local grp = byName[g.group]
    if not grp then
      local _, _, lo = string.find(g.group, "(%d+)%-%d+$")
      grp = { name = g.group, lo = tonumber(lo) or 0, guides = {} }
      byName[g.group] = grp
      table.insert(groups, grp)
    end
    table.insert(grp.guides, g)
  end
  -- the xpGuide Fast route first, then RestedXP's original (the fallback). By level within each.
  local function Rank(grp)
    return S.Kind(grp.guides[1]) == "xproute" and 0 or 1
  end
  table.sort(groups, function(a, b)
    local ra, rb = Rank(a), Rank(b)
    if ra ~= rb then return ra < rb end
    return a.lo < b.lo
  end)
  -- within a group by level, then by top level (a starting guide among the others, not after them); the same levels keep their order
  for _, grp in ipairs(groups) do
    local at = {}
    for i, g in ipairs(grp.guides) do at[g] = i end
    table.sort(grp.guides, function(a, b)
      if (a.lo or 0) ~= (b.lo or 0) then return (a.lo or 0) < (b.lo or 0) end
      if (a.hi or 0) ~= (b.hi or 0) then return (a.hi or 0) < (b.hi or 0) end
      return at[a] < at[b]
    end)
  end
  return groups
end

-- Saved keys from older versions began with the group's old name ("RestedXP Alliance 1-20\..."): the same guide, so it still counts.
-- Starting guides renamed or moved to another group (2.1.0): a place saved in the old one carries on in the new one.
local RENAMED = {
  ["xpGuide Fast route Alliance\\1-5 Quel'Thalas Gate (High Elf)"] = "xpGuide Fast route Alliance 1-20\\1-6 Quel'Thalas Gate (High Elf)",
  ["xpGuide Fast route Alliance 1-20\\1-5 Quel'Thalas Gate (High Elf)"] = "xpGuide Fast route Alliance 1-20\\1-6 Quel'Thalas Gate (High Elf)",
  ["xpGuide Fast route Alliance 1-20\\5-11 Alah'Thalas (High Elf)"] = "xpGuide Fast route Alliance 1-20\\6-11 Alah'Thalas (High Elf)",
  ["xpGuide Fast route Alliance\\5-11 Alah'Thalas (High Elf)"] = "xpGuide Fast route Alliance 1-20\\6-11 Alah'Thalas (High Elf)",
  ["xpGuide Fast route Horde\\1-11 Blackstone Island (Goblin)"] = "xpGuide Fast route Horde 1-22\\1-11 Blackstone Island (Goblin)",
  ["1-5 Quel'Thalas Gate (High Elf)"] = "xpGuide Fast route Alliance 1-20\\1-6 Quel'Thalas Gate (High Elf)",
  ["5-11 Alah'Thalas (High Elf)"] = "xpGuide Fast route Alliance 1-20\\6-11 Alah'Thalas (High Elf)",
}
local function NewKey(key)
  if type(key) == "string" then
    key = string.gsub(key, "^RestedXP ", "")
    return RENAMED[key] or key
  end
  return key
end
S.NewKey = NewKey

function S.Find(key)
  key = NewKey(key)
  for _, g in ipairs(pfQuest_xpGuide_Guides or {}) do
    if Key(g) == key or g.name == key then return g end
  end
  return ER.RouteFind and ER.RouteFind(key) or nil
end

local function DefaultFor(g)
  if not g.defaultFor or g.defaultFor == "" then return false end
  return S.Applies(g.defaultFor)
end

-- Guides that fit your level, best first: one you are in the middle of, then a starting zone made for your race,
-- then one whose zone you are standing in. The xpGuide Fast route comes first; RestedXP's original (the fallback) comes first only
-- once the xpGuide Fast route went wrong (FastRoute.lua). prefer (a kind, see S.Kind) puts guides of that family first: the one you
-- are following.
function S.Suggest(prefer)
  local _, _, _, level = Me()
  local here = GetZoneText() or ""
  local list = {}
  for _, g in ipairs((S.Guides())) do
    if level >= g.lo and level < math.max(g.hi, g.lo + 1) then
      local score = 0
      if DefaultFor(g) then score = score + 5 end
      local kind = S.Kind(g)
      if kind == "xproute" then score = score + 10 end   -- the xpGuide Fast route is the default
      if kind == "fast" and ER.FastRoute and ER.FastRoute.FallbackWanted() then score = score + 30 end
      if prefer and kind == prefer then score = score + 20 end
      if g.raceStart then score = score + 12 end         -- a starting guide made for your race (High Elf, Goblin)
      if string.find(string.lower(g.title or g.name), string.lower(here), 1, true) then score = score + 3 end
      score = score - (level - g.lo) * 0.1
      table.insert(list, { g = g, score = score })
    end
  end
  -- Nothing at exactly this level: the nearest guide above it.
  if table.getn(list) == 0 then
    local best
    for _, g in ipairs((S.Guides())) do
      if g.lo > level and (not best or g.lo < best.lo) then best = g end
    end
    if best then table.insert(list, { g = best, score = 0 }) end
  end
  table.sort(list, function(a, b) return a.score > b.score end)
  local out = {}
  for _, c in ipairs(list) do table.insert(out, c.g) end
  return out
end

------------------------------------------------------------------------------------------------------
-- Is a step done, and should it be skipped?
------------------------------------------------------------------------------------------------------

local function Fired(step, what)
  return live.fired[step.n .. ":" .. what]
end

local function Fire(step, what)
  live.fired[step.n .. ":" .. what] = true
end

-- Has this element been done? nil for elements that are only there to read (text, places, items to use).
local function ElementDone(step, e)
  local k = e.kind
  -- a quest this addon does not know (no title anywhere, e.g. a server's own quest without pfQuest data): it cannot be
  -- followed in the quest log, so the step is ticked by hand
  if (k == "A" or k == "C" or k == "T") and e.id and e.id > 0 and not S.QuestTitle(e.id) then return nil end
  if k == "A" then
    -- A quest left out (too easy, or an elite on Casual) or not offered yet, in a step kept for a hand-in: nothing to wait for.
    if LeftOut(e.id) and not S.TurnedIn(e.id) then return nil end
    if S.InLog(e.id) or S.TurnedIn(e.id) or S.AcceptInLog(e) then return true end
    if NotYet(e.id, step) then return nil end
    return false
  end
  -- Handing in or finishing a quest you do not have is nothing to wait for (you skipped it, or it is one of two
  -- quests with the same name and you have the other), as in RestedXP.
  if k == "T" then return S.TurnedIn(e.id) or not S.InLog(e.id) end
  if k == "C" then
    if S.TurnedIn(e.id) then return true end
    local row = S.InLog(e.id)
    if not row then return true end
    if row.complete then return true end
    if e.obj then
      local _, finished = S.Objective(e.id, e.obj)
      return finished
    end
    return false
  end
  if k == "K" then
    if e.id and e.id ~= 0 then
      if S.TurnedIn(e.id) then return true end
      local row = S.InLog(e.id)
      if not row or row.complete then return true end
    end
    return S.ItemCount(e.item) >= (e.count or 1)
  end
  if k == "X" then
    if e.skip or e.op == "<" then return nil end
    return Reached(e.level, e.xp)
  end
  if k == "R" then return not S.InLog(e.id) end
  if k == "Z" then return SameText(GetZoneText(), e.zone) or SameText(GetSubZoneText and GetSubZoneText(), e.zone) end
  if k == "F" then return (UnitOnTaxi and UnitOnTaxi("player")) or Fired(step, "fly") or false end
  if k == "P" then return Fired(step, "fp") or false end
  if k == "H" then return Fired(step, "hs") or false end
  if k == "V" then
    if LateTrainer(e, step) then return nil end
    return Fired(step, e.what == "vendor" and "vendor" or "trainer") or false
  end
  if k == "B" then
    local bind = GetBindLocation and GetBindLocation()
    if Fired(step, "bind") then return true end
    if e.text and bind then
      local _, _, where = string.find(e.text, " to (.+)$")
      if where and SameText(string.gsub(where, "|c%x%x%x%x%x%x%x%x", ""), bind) then return true end
    end
    return false
  end
  if k == "M" then
    if HasMoney() and MoneyText(e.text) then return nil end
    return Fired(step, "tick") or false
  end
  -- "Cast [Summon Imp]" and the like: done while a pet is out (any pet, so a warlock without that demon yet is
  -- not stuck on it).
  if k == "I" and e.text and (string.find(e.text, "%[Summon %a+%]") or string.find(e.text, "%[Call Pet%]")) then
    return UnitExists("pet") and true or false
  end
  return nil
end
S.ElementDone = ElementDone

-- The quest-based elements of a step all point at quests you do not have (and have not handed in): there is
-- nothing to do, so the step is skipped. Accepts never count here: you can always pick a quest up.
local function NothingToDo(step)
  local any = false
  for _, e in ipairs(step.elements) do
    if e.kind == "A" or e.kind == "H" or e.kind == "B" or e.kind == "P" or e.kind == "F" or e.kind == "V" or e.kind == "X"
      or e.kind == "Z" or e.kind == "M" or (e.kind == "K" and (not e.id or e.id == 0)) then
      return false
    end
    if e.kind == "T" or e.kind == "C" or e.kind == "K" or e.kind == "R" then
      any = true
      if S.InLog(e.id) or S.TurnedIn(e.id) then return false end
    end
  end
  return any
end

-- A "reach level" step among a guide's catch-up steps (from the guide before): nothing to do when the quests the next step picks up
-- are in your log or handed in already (you did that part in the guide before, at its level).
local function CatchupGrindPassed(pos)
  local step = guide and guide.steps[pos]
  if not (step and step.flags.catchup) then return false end
  for _, e in ipairs(step.elements) do
    if e.kind ~= "X" and e.kind ~= "I" and e.kind ~= "G" then return false end
  end
  local nxt = guide.steps[pos + 1]
  if not nxt then return false end
  local any = false
  for _, e in ipairs(nxt.elements) do
    if e.kind == "A" and e.id and e.id ~= 0 then
      if not (S.InLog(e.id) or S.TurnedIn(e.id)) then return false end
      any = true
    end
  end
  return any
end

local function LabelDone(label)
  local n = guide and guide.labels[label]
  if not n then return true end
  return state.passed[n] and true or false
end

-- Should this step be left out when you get to it? Its own "only when ..." lines decide.
local function Gated(step)
  if step.flags.requires and not LabelDone(step.flags.requires) then return true end
  for _, e in ipairs(step.elements) do
    local k = e.kind
    if k == "Q" then
      local any = false
      for id in string.gfind(e.ids or "", "%d+") do
        local yes
        if e.test == "on" or e.test == "noton" then yes = S.InLog(id)
        elseif e.test == "done" then yes = S.TurnedIn(id)
        else
          local row = S.InLog(id)
          yes = row and row.complete
        end
        if yes then any = true end
      end
      if e.test == "noton" then
        if any then return true end
      elseif not any then
        return true
      end
    elseif k == "W" or k == "SW" then
      local inside = InZone(e.zones)
      if e.flag == "1" then
        if not inside then return true end
      elseif inside then
        return true
      end
    elseif k == "L" then
      local now = UnitLevel("player") or 1
      if now > e.level or (now == e.level and e.xp and e.xp ~= "" and Reached(e.level, e.xp)) then return true end
    elseif k == "X" and (e.skip or e.op == "<") then
      if Reached(e.level, e.xp) then return true end
    elseif k == "N" then
      local count = 0
      for id in string.gfind(e.items or "", "%d+") do count = count + S.ItemCount(id) end
      local total, op = e.total or 1, e.op or ""
      local ok
      if op == "<" then ok = count < total
      elseif op == ">" then ok = count > total
      elseif op == "=" or op == "<=" or op == ">=" then
        ok = count == total or (op == "<=" and count < total) or (op == ">=" and count > total)
      else ok = count >= total end
      if not ok then return true end
    end
  end
  return false
end

-- The last place in a step: where it ends.
local function LastPlace(step)
  local last
  for _, e in ipairs(step.elements) do
    if e.kind == "G" then last = e end
  end
  return last
end

local function Arrived(e, yards)
  if not e then return false end
  local d = S.DistanceTo(e.zone, e.x, e.y)
  return d ~= nil and d <= (yards or e.radius or 10)
end

-- Is the whole step done? Every element that can be done is. A step with nothing to tick is done when you reach
-- its last place, or when you tick it by hand.
-- What "Hand in, then move on" (S.HandInFirst) keeps of a step, done: the finished quests handed in (or no longer in your log);
-- a quest the next guide needs picked up, its objectives done, handed in. What cannot be done (a quest you do not carry, one the
-- game does not offer) does not hold the guide.
local function HandInsDone(reqs)
  for _, r in ipairs(reqs) do
    local id = r.id
    if S.TurnedIn(id) then
      -- done
    elseif not r.bridge then
      if S.InLog(id) then return false end
    elseif r.kind == "A" then
      -- to pick up: unless the game does not offer it (its own prerequisite not handed in: nothing to wait for)
      local p = S.QuestPre(id)
      if not S.InLog(id) and not (p and p ~= 0 and not S.TurnedIn(p)) then return false end
    elseif r.kind == "C" then
      -- its objectives done, if you carry it
      local row = S.InLog(id)
      if row and not (row.complete or not row.obj or table.getn(row.obj) == 0) then return false end
    else
      -- handed in, if you carry it
      if S.InLog(id) then return false end
    end
  end
  return true
end

local function StepDone(step)
  local any = false
  for _, e in ipairs(step.elements) do
    local d = ElementDone(step, e)
    if d ~= nil then
      any = true
      if not d then return false end
    end
  end
  if any then return true end
  local last = LastPlace(step)
  if last then
    if Fired(step, "tick") then return true end
    return Arrived(last, last.radius or 10)
  end
  return Fired(step, "tick") or false
end
S.StepDone = StepDone

------------------------------------------------------------------------------------------------------
-- Moving through the guide
------------------------------------------------------------------------------------------------------

local function Saved()
  if not ER.db then return nil end
  if type(ER.db.guides) ~= "table" then ER.db.guides = {} end
  return ER.db.guides[ER.Char()]
end

local function Changed()
  if ER.StepsChanged then ER.StepsChanged() end
end

local function MainAfter(n)
  for i = n + 1, table.getn(guide.steps) do
    local s = guide.steps[i]
    if not (s.flags.completewith or s.flags.sticky) and Fits(s) then return i end
  end
  return nil
end

-- Steps shown beside the current one ("on the way", "keep an eye out"): done when their own things are done, or
-- (for "complete with") when the step they go with is.
local function SideDone(n)
  local step = guide.steps[n]
  if StepDone(step) then return true end
  local with = step.flags.completewith
  if with == "next" then
    local m = MainAfter(n)
    return m == nil or (state.passed[m] and true or false) or state.pos > m
  elseif with then
    local m = guide.labels[with]
    return m == nil or (state.passed[m] and true or false)
  end
  -- Sticky: until done, or until the guide is well past it.
  return state.pos - n > 40
end

-- You handed in the quest this step is about and walked off without the new quest it offers (the NPC did not
-- offer it, or you said no): the step moves on instead of waiting for ever. Later steps for that quest skip
-- themselves, since it is not in your log.
local function WalkedOff(step)
  if step.flags.completewith or step.flags.sticky then return false end
  local handedIn, open = false, false
  for _, e in ipairs(step.elements) do
    local d = ElementDone(step, e)
    if e.kind == "A" then
      -- a quest too hard for you that Take and hand in quests left to you: you have not chosen to leave it, so the step waits
      -- (take it, or Skip step); walking away does not drop it and its later steps
      if d == false and S.TooHard(e.id) and not LeftOut(e.id) then return false end
      if d == false then open = true end
    elseif d == false then
      return false
    elseif e.kind == "T" and e.id and S.TurnedIn(e.id) then
      handedIn = true
    end
  end
  if not (handedIn and open) then return false end
  local last = LastPlace(step)
  local d = last and S.DistanceTo(last.zone, last.x, last.y)
  if d == nil then return false end
  -- walked off: far from the step's place. Not when the hearthstone (or a loading screen) took you away while on this step: that
  -- is not choosing to leave the follow-up behind, so the guide still sends you back, until you have been at the place again.
  live.near = live.near or {}
  if d <= 60 then
    live.near[step.n] = true
    return false
  end
  if live.jumped and live.jumped[step.n] and not live.near[step.n] then return false end
  return true
end

local function BeginStep()
  live.bindAt = GetBindLocation and GetBindLocation() or nil
  live.reached = {}
end

-- Moves forward past everything that is done or does not apply; stops at the first step there is still something
-- to do in. Returns true when the current step changed.
local function Advance()
  if not guide then return false end
  if ER.Recorder and ER.Recorder.Ready and not ER.Recorder.Ready() then return false end
  local start = state.pos
  local n = table.getn(guide.steps)
  for i = table.getn(state.side), 1, -1 do
    local s = state.side[i]
    if state.passed[s] or SideDone(s) then
      state.passed[s] = state.passed[s] or "done"
      table.remove(state.side, i)
    end
  end
  while state.pos <= n do
    local pos = state.pos
    local step = guide.steps[pos]
    if live.holdAt == pos then
      -- a step you went back to by hand counts as walked off only after you have been at its place again (you are far from it
      -- when you jump back, which would pass it over at once)
      if not live.holdNear then
        local last = LastPlace(step)
        local d = last and S.DistanceTo(last.zone, last.x, last.y)
        if d and d <= 60 then live.holdNear = true end
      end
      if live.holdWasDone == false and (StepDone(step) or (live.holdNear and WalkedOff(step))) then
        live.holdAt = nil
      else
        break
      end
    end
    if state.passed[pos] then
      state.pos = pos + 1
    elseif state.handIn and state.handIn[pos] then
      -- kept by "Hand in, then move on": done when what it keeps is done, whatever else the step has
      if not HandInsDone(state.handIn[pos]) then break end
      state.passed[pos] = "done"
      state.pos = pos + 1
    elseif not Fits(step) then
      if EasyStep(step) then live.easySkipped = (live.easySkipped or 0) + 1 end
      state.passed[pos] = "skip"
      state.pos = pos + 1
    elseif Gated(step) or NothingToDo(step) or CatchupGrindPassed(pos) then
      state.passed[pos] = "skip"
      state.pos = pos + 1
    elseif StepDone(step) then
      state.passed[pos] = "done"
      state.pos = pos + 1
    elseif WalkedOff(step) then
      state.passed[pos] = "skip"
      state.pos = pos + 1
    elseif step.flags.completewith or step.flags.sticky then
      local listed = false
      for _, s in ipairs(state.side) do if s == pos then listed = true end end
      if not listed then table.insert(state.side, pos) end
      state.pos = pos + 1
    else
      break
    end
  end
  -- A "complete with next" step whose partner has now gone by is finished too.
  for i = table.getn(state.side), 1, -1 do
    local s = state.side[i]
    if SideDone(s) then
      state.passed[s] = state.passed[s] or "done"
      table.remove(state.side, i)
    end
  end
  if state.pos ~= start then
    BeginStep()
    return true
  end
  return false
end

-- Where to start in a guide picked part-way through: the last step that picks up a quest you have or have handed in,
-- or hands in (or finishes) one you have handed in; and when you are past the start of the guide in level, no earlier
-- than the first quest that is not too easy for you. Never past a step that still has work on a quest in your log
-- (one not finished): a hand-in far ahead of the kill step must not take you past the kill step.
local function StartAt(useLevel)
  local last, cap = 0, nil
  for i, step in ipairs(guide.steps) do
    for _, e in ipairs(Fits(step) and step.elements or {}) do
      local k = e.kind
      if k == "A" and (S.InLog(e.id) or S.TurnedIn(e.id)) then
        last = i
      elseif (k == "T" or k == "C") and S.TurnedIn(e.id) then
        last = i
      end
      if not cap and (k == "C" or k == "K" or k == "T") and e.id and e.id ~= 0 and not S.TurnedIn(e.id) then
        local row = S.InLog(e.id)
        if row and not row.complete then cap = i end
      end
    end
  end
  local byLevel, easySeen = 0, false
  for i, step in ipairs(guide.steps) do
    local good, easy = false, false
    for _, e in ipairs(step.elements) do
      if e.kind == "A" then
        if S.TooEasy(e.id) and not step.flags.catchup then easy = true elseif not LeftOut(e.id) then good = true end
      end
    end
    if good and Fits(step) then
      if easySeen then byLevel = i end
      break
    end
    if easy then easySeen = true end
  end
  -- your level, when nothing of this guide is recorded (quests handed in before pfQuest was installed are in no record): the
  -- guide's "reach level" lines say where a character of that level is; past the last one you have reached
  local level, byGrind = UnitLevel("player") or 1, 0
  for i, step in ipairs(guide.steps) do
    for _, e in ipairs(step.elements) do
      if e.kind == "X" and tonumber(e.level) and tonumber(e.level) <= level and tonumber(e.level) > (guide.info.lo or 1) then
        byGrind = i + 1
      end
    end
  end
  if byGrind > table.getn(guide.steps) then byGrind = 0 end
  -- only with no record of this guide's quests (a record, even of a few, says better where you are than the level does), and only
  -- for a character the guide has not followed before: one going on from the guide before starts the next one at its quests,
  -- not past them because its level is already above the first "reach level" line
  if last > 0 or not useLevel then byGrind = 0 end
  local start = math.max(1, last, byLevel, byGrind)
  if cap and cap < start then start = cap end
  return start, last, byGrind
end

-- Everything before the start counts as behind you. A start past step 1 is said, with what it is based on (S.StartNote).
local function StartPoint(useLevel)
  local start, byQuests, byGrind = StartAt(useLevel)
  for i = 1, start - 1 do state.passed[i] = "auto" end
  state.pos = start
  local handed = 0
  for _, step in ipairs(guide.steps) do
    for _, e in ipairs(step.elements) do if e.kind == "T" and e.id and S.TurnedIn(e.id) then handed = handed + 1 end end
  end
  live.startNote = { pos = start, handed = handed, level = UnitLevel("player") or 1, byGrind = byGrind or 0 }
end

-- What the last start part-way was based on, once (Tracker.lua says it): { pos, handed, level, byGrind }, or nil.
function S.StartNote()
  local n = live.startNote
  live.startNote = nil
  return n
end

-- How far ahead of the quest log a saved place may be before it is moved back: this many steps that are for you.
local RESYNC_GAP = 15

-- Starts the guide again where the quest log says you are. Quests handed in stay handed in.
local function Resync()
  state.pos, state.passed, state.fired, state.side, state.bridges = 1, {}, {}, {}, nil
  live.fired = state.fired
  live.holdAt = nil
  StartPoint()
end

-- The steps that are for you from step a up to (not with) step b.
local function StepsBetween(a, b)
  local n = 0
  for i = a, b - 1 do
    local s = guide.steps[i]
    if s and not (s.flags.completewith or s.flags.sticky) and Fits(s) then n = n + 1 end
  end
  return n
end

-- Once per version of the addon: a saved place far ahead of what the quest log says (left from an older version, or
-- pushed on past unfinished work) goes back to where the quest log says. Waits until the quest log has been read.
local function CheckOnce()
  if not guide or not state or state.synced == ER.VERSION then return end
  if ER.Recorder and ER.Recorder.Ready and not ER.Recorder.Ready() then return end
  state.synced = ER.VERSION
  local start = StartAt()
  if state.pos > start and StepsBetween(start, state.pos) >= RESYNC_GAP then
    Resync()
    BeginStep()
  end
end

-- Starts (or carries on with) a guide. fresh: start it again from the top.
function S.Load(key, fresh)
  local info = S.Find(key)
  if not info or not ER.db then return false end
  local steps, labels, shared, turnins = ParseSteps(info)
  guide = { info = info, steps = steps, labels = labels, shared = shared, turnins = turnins, needed = {} }
  -- the quests of the catch-up steps (what this guide needs from the guide before): never left out as too easy or by difficulty
  for _, st in ipairs(steps) do
    if st.flags.catchup then for _, e in ipairs(st.elements) do if e.id and tonumber(e.id) then guide.needed[tonumber(e.id)] = true end end end
  end
  local saved = Saved()
  local count = table.getn(steps)
  if saved and saved.key ~= Key(info) and NewKey(saved.key) == Key(info) then saved.key = Key(info) end
  if fresh or not saved or saved.key ~= Key(info) then
    -- a character the guide has not followed before (no place saved in any guide): its level says where it is, too (StartAt)
    local newHere = not saved
    saved = { key = Key(info), pos = 1, passed = {}, fired = {}, side = {}, synced = ER.VERSION, front = info.front or 0 }
    -- The casual route's step list can grow between versions, so its record keeps the length it was saved with.
    if info.route then saved.count = count end
    ER.db.guides[ER.Char()] = saved
    state = saved
    if not fresh then StartPoint(newHere) end
  elseif info.route and saved.count ~= count then
    -- A casual-route position saved with another step list (an older version, or none noted) would land on the wrong step. The record
    -- stays (its other fields too) but starts again where the quest log says the player is; quests handed in stay handed in.
    -- RestedXP guides never change their step list, so their records only get the once-per-version check (CheckOnce).
    saved.pos, saved.passed, saved.fired, saved.side, saved.bridges = 1, {}, {}, {}, nil
    state = saved
    StartPoint()
    saved.count = count
  end
  state = saved
  state.stopped = nil
  -- The guide has catch-up steps at its front (what it needs from the guide before) that the saved place did not count (saved
  -- by an older version, or the steps changed): every step number moves by that many. The catch-up steps come first when any
  -- of them still has something for you; done ones pass by themselves, then the steps you had passed, back to your place.
  local front = info.front or 0
  if (state.front or 0) ~= front and type(state.pos) == "number" then
    local d = front - (state.front or 0)
    local function Shift(t)
      local n = {}
      for k, v in pairs(t or {}) do if type(k) == "number" and k + d >= 1 then n[k + d] = v end end
      return n
    end
    state.passed, state.fired, state.handIn = Shift(state.passed), Shift(state.fired), state.handIn and Shift(state.handIn)
    local side = {}
    for _, i in ipairs(state.side or {}) do if i + d >= 1 then table.insert(side, i + d) end end
    state.side = side
    state.pos = math.max(1, state.pos + d)
    for i = 1, front do state.passed[i] = nil end
    local open = false
    for i = 1, front do if steps[i] and Fits(steps[i]) and not StepDone(steps[i]) then open = true end end
    if open then state.pos = 1 end
    state.front = front
  end
  -- the quests you abandoned while another guide ran (and have not picked up again) count here too
  for id in pairs(S.CharAbandoned and S.CharAbandoned() or {}) do
    if not S.InLog(id) and not S.TurnedIn(id) then
      state.abandoned = state.abandoned or {}
      state.abandoned[id] = true
    end
  end
  if type(state.pos) ~= "number" then state.pos = 1 end
  state.passed = state.passed or {}
  state.fired = state.fired or {}
  state.side = state.side or {}
  live.fired = state.fired
  live.holdAt, live.bags, live.near, live.jumped = nil, nil, nil, nil
  BeginStep()
  CheckOnce()
  Advance()
  Changed()
  return true
end

-- Puts the guide back where the quest log says you are (the "Find my place" button). Quests handed in stay handed in.
-- Returns the step it is on now, or nil with no guide running.
function S.FindMyPlace()
  if not guide or not state then return nil end
  Resync()
  state.synced = ER.VERSION
  BeginStep()
  Advance()
  Changed()
  if ER.ArrowUpdate then ER.ArrowUpdate() end
  return state.pos
end

function ER.FindMyPlace()
  local pos = S.FindMyPlace()
  if not pos then
    ER.Print("no guide is running. Pick a guide first.")
  elseif S.Current() then
    ER.Print("back on step " .. pos .. " of " .. S.Count() .. ", where your quest log says you are.")
  else
    ER.Print("your quest log says this guide is done.")
  end
end

-- Picks the guide back up after logging in, if one was running on this character.
function S.Resume()
  local saved = Saved()
  if saved and saved.key and not saved.stopped and S.Find(saved.key) then return S.Load(saved.key) end
  return false
end

function S.Stop()
  local saved = Saved()
  if saved then saved.stopped = true end
  guide, state = nil, nil
  Changed()
end

-- The guide that follows this one: the first of RestedXP's "next" guides that is for this character.
function S.NextGuide()
  local info = guide and guide.info
  if not info or not info.next or info.next == "" then return nil end
  local mine = S.Guides()
  -- the same family first: the xpGuide Fast route's guides carry RestedXP's names, and go on to their own copy
  local kind = S.Kind(info)
  for _, same in ipairs({ true, false }) do
    for name in string.gfind(info.next, "[^;]+") do
      name = string.gsub(string.gsub(name, "^%s+", ""), "%s+$", "")
      for _, g in ipairs(mine) do
        if (g.name == name or g.title == name) and (S.Kind(g) == kind) == same then return g end
      end
    end
  end
  return nil
end

-- The guide to go on to from this one: RestedXP's "next" guide, else the next guide up of the same kind (Bethink's after
-- Bethink's, VanillaGuide's after VanillaGuide's, the fast routes after a fast route): the one that fits your level,
-- else the lowest one above this. nil when there is none.
function S.FollowOn()
  local info = guide and guide.info
  if not info then return nil end
  local nxt = S.NextGuide()
  if nxt then return nxt end
  local Kind = S.Kind
  local function Zone(g) return string.lower((string.gsub(g.title or g.name or "", "^[%d%-%s]+", ""))) end
  local kind, level, zone = Kind(info), UnitLevel("player") or 1, Zone(info)
  -- best: fits your level, then the same zone, then a guide made for your race, then the lowest
  local best, bestScore
  for _, g in ipairs((S.Guides())) do
    if g ~= info and Kind(g) == kind and (g.lo or 0) > (info.lo or 0) then
      local score = -(g.lo or 0) * 0.01
      if g.lo <= level and level < math.max(g.hi or 0, g.lo + 1) then score = score + 10 end
      if zone ~= "" and Zone(g) == zone then score = score + 5 end
      if DefaultFor(g) then score = score + 3 end
      if not best or score > bestScore then best, bestScore = g, score end
    end
  end
  return best
end

-- Two levels past the top of the guide: it has little left for you.
function S.Outlevelled()
  local info = guide and guide.info
  if not info or not info.hi or info.hi <= 0 then return false end
  -- A casual-route zone moves on by itself when you are past it.
  if info.route then return false end
  return (UnitLevel("player") or 1) >= info.hi + 2
end

-- How many steps were left out for being too easy since the last time this was asked.
function S.TakeEasySkipped()
  local n = live.easySkipped or 0
  live.easySkipped = 0
  return n
end

function S.Running() return guide ~= nil end
function S.Info() return guide and guide.info end
function S.Count() return guide and table.getn(guide.steps) or 0 end
function S.Position() return state and state.pos or 0 end
function S.Step(n) return guide and guide.steps[n] end
function S.Current() return guide and guide.steps[state.pos] end
function S.Passed(n) return state and state.passed[n] end

-- The steps beside the current one, in guide order.
function S.Side()
  local out = {}
  if not guide then return out end
  for _, n in ipairs(state.side) do table.insert(out, guide.steps[n]) end
  table.sort(out, function(a, b) return a.n < b.n end)
  return out
end

-- The next few steps after the current one that are still to come.
function S.Upcoming(count)
  local out = {}
  if not guide then return out end
  for i = state.pos + 1, table.getn(guide.steps) do
    local s = guide.steps[i]
    if not state.passed[i] and not s.flags.completewith and not s.flags.sticky and Fits(s) then
      table.insert(out, s)
      if table.getn(out) >= count then break end
    end
  end
  return out
end

-- Every step of the guide that fits you, in order, for the guide window's list: { step = s, done = true when it is behind
-- you (before the current step, or passed over), how = "done" / "skip" / "passed" (see below) }. Steps that only ride along with another (completewith, sticky) are left out.
function S.All()
  local out = {}
  if not guide then return out end
  S.SettleAbandoned()
  local regainAt = S.RegainSteps()
  for i, s in ipairs(guide.steps) do
    -- a step you skipped yourself stays listed (ticked) even though its quest is now left out, so it can be taken back
    -- so does a step of a quest you abandoned (and its chain), whatever else would leave it out, so it can be clicked to go back
    if not s.flags.completewith and not s.flags.sticky and (Fits(s) or (state.mine and state.mine[i] and state.passed[i])
      or (state.abandoned and S.AbandonedIn(s)) or (state.dropped and state.passed[i] and S.DroppedIn(s))) then
      local p = state.passed[i]
      -- every step behind you has a record of how it was left (Advance, Jump and the part-way start write one); a step
      -- behind you without one was brought back (a quest you abandoned and picked up again) and is still to do
      local done = p and true or false
      -- how it was left behind: "done" (its work was done or its quest handed in), "skip" (you skipped it), "passed" (the
      -- guide passed over it: a quest you never took, not needed, or you went past it), "abandoned" (its quest, or one
      -- before it in its chain, was abandoned and not handed in: never shown as completed), nil while it is still to do
      local how = nil
      if done then
        if S.AbandonedIn(s) then how = "abandoned"
        elseif S.DroppedIn(s) then how = "passed"
        elseif p == "done" then how = "done"
        elseif p == "skip" then how = (state.mine and state.mine[i]) and "skip" or "passed"
        else how = StepDone(s) and "done" or "passed" end
      end
      -- regain: the step of an abandoned quest that goes back to where you pick it up (shown as a button in the list)
      table.insert(out, { step = s, done = done, how = how, regain = regainAt[i] })
    end
  end
  return out
end

-- Auto mode reads what the guide wants. How many steps ahead of the current one a quest pick-up still counts as wanted.
local WANT_AHEAD = 10

-- The steps that count as "now": the current one, the side steps and the next few that still fit.
local function NowSteps()
  local steps = {}
  if S.Current() then table.insert(steps, S.Current()) end
  for _, s in ipairs((S.Side())) do table.insert(steps, s) end
  return steps
end

-- Quests the guide wants taken now: { [tidied title] = quest id }, from the A lines of the current step and the side steps; and,
-- when npc (the tidied titles the NPC you talk to offers or takes: { [title] = true }) shows it is the NPC of the step you are on,
-- the A lines of the next WANT_AHEAD steps for as long as they stay with that NPC. A quest that is in the log, handed in, left out,
-- not offered yet or too hard is not in it. An escort quest is not in it either (the player accepts those), unless withEscorts.
function S.WantedAccepts(withEscorts, npc)
  local out = {}
  if not guide then return out end
  local function Want(step, e)
    return e.kind == "A" and e.id and e.id ~= 0 and not LeftOut(e.id) and not NotYet(e.id, step) and not S.TooHard(e.id)
      and not S.InLog(e.id) and not S.TurnedIn(e.id) and not S.AcceptInLog(e) and (withEscorts or not S.Escort(e.id))
  end
  local function Names(e)
    local t = {}
    local title = S.QuestTitle(e.id)
    if title then table.insert(t, NormTitle(title)) end
    if type(e.text) == "string" then
      table.insert(t, NormTitle((string.gsub(string.gsub(e.text, "^Accept%s+", ""), "^Turn in%s+", ""))))
    end
    return t
  end
  local function AtNpc(e)
    if not npc then return false end
    for _, n in ipairs(Names(e)) do if npc[n] then return true end end
    return false
  end
  local function Add(e)
    for _, n in ipairs(Names(e)) do out[n] = e.id end
  end
  -- the steps you are on: their pick-ups, whoever offers them
  local now = NowSteps()
  local here = false
  for _, step in ipairs(now) do
    if not Gated(step) then
      for _, e in ipairs(step.elements) do
        if Want(step, e) then Add(e) end
        if (e.kind == "A" or e.kind == "T") and e.id and e.id ~= 0 and AtNpc(e) then here = true end
      end
    end
  end
  -- the next steps' pick-ups only from the NPC of the step you are on (one that offers or takes a quest of it), and only while
  -- the next steps stay with that NPC: a quest giver standing beside it gives nothing the step does not name
  if here then
    for _, step in ipairs((S.Upcoming(WANT_AHEAD))) do
      if Gated(step) then break end
      local quests, mine = 0, 0
      for _, e in ipairs(step.elements) do
        if (e.kind == "A" or e.kind == "T") and e.id and e.id ~= 0 then
          quests = quests + 1
          if AtNpc(e) or (e.kind == "T" and S.TurnedIn(e.id)) then mine = mine + 1 end
        end
      end
      if quests == 0 or mine < quests then break end
      for _, e in ipairs(step.elements) do if Want(step, e) then Add(e) end end
    end
  end
  out[""] = nil
  return out
end

-- Every quest the running guide hands in (the T lines of any step): { [tidied title] = quest id }. Made once per guide.
function S.HandInTitles()
  if not guide then return {} end
  if not guide.handIn then
    local t = {}
    for _, step in ipairs(guide.steps) do
      for _, e in ipairs(step.elements) do
        if e.kind == "T" and e.id and e.id ~= 0 then
          local title = S.QuestTitle(e.id)
          if title then t[NormTitle(title)] = e.id end
          if type(e.text) == "string" then
            t[NormTitle((string.gsub(e.text, "^Turn in%s+", "")))] = e.id
          end
        end
      end
    end
    t[""] = nil
    guide.handIn = t
  end
  return guide.handIn
end

-- The lines of one kind ("F", "B", "H" ...) in the current and side steps that are not done yet: { { step = , e = }, ... }.
function S.OpenElements(kind)
  local out = {}
  if not guide then return out end
  for _, step in ipairs((NowSteps())) do
    for _, e in ipairs(step.elements) do
      if e.kind == kind and ElementDone(step, e) == false then table.insert(out, { step = step, e = e }) end
    end
  end
  return out
end

S.NormTitle = NormTitle

-- On to the next step. The > button and /xpg next only page on and teach nothing. A real Skip (the Skip button, the "Stuck?
-- Skip this step" line or tip) passes learn = true: a step left with quest work still in it counts as skipped, and Adapt.lua learns
-- from that.
function S.Next(learn)
  if not guide then return end
  local from = state.pos
  local step = guide.steps[from]
  local marked
  if learn and step and ER.OnStepSkipped and not StepDone(step) then marked = ER.OnStepSkipped(step) end
  local mineNow = false
  if from <= table.getn(guide.steps) then
    if learn and not state.passed[from] then
      state.mine = state.mine or {}
      state.mine[from] = true
      mineNow = true
    end
    state.passed[from] = state.passed[from] or "skip"
  end
  -- what the guide passes over by itself right after (the skipped quest's chain among it), so an unskip can bring it back
  local open = {}
  for i = from + 1, table.getn(guide.steps) do if not state.passed[i] then open[i] = true end end
  state.pos = from + 1
  live.holdAt = nil
  BeginStep()
  Advance()
  if learn then
    state.lastSkip, state.lastSkipTo = mineNow and from or state.lastSkip, state.pos
    if mineNow then
      local auto = {}
      for i = from + 1, state.pos - 1 do
        if open[i] and state.passed[i] == "skip" then table.insert(auto, i) end
      end
      state.skipWith = state.skipWith or {}
      state.skipWith[from] = { ids = marked, auto = auto }
    end
  end
  Changed()
end

-- The < button: back to the step before, and stay there until you move on.
function S.Prev()
  if not guide then return end
  for i = state.pos - 1, 1, -1 do
    local s = guide.steps[i]
    if not s.flags.completewith and not s.flags.sticky and Fits(s) then
      state.passed[i] = nil
      state.pos = i
      live.holdAt, live.holdWasDone, live.holdNear = i, StepDone(s), nil
      BeginStep()
      Changed()
      return
    end
  end
end

-- The quest that must be handed in before this one is offered: the addon's quest data (the starting guides' quests from
-- Data\FastRoute.lua among them), else pfQuest's; nil when none is known.
function S.QuestPre(id)
  id = tonumber(id)
  if not id then return nil end
  local row = ER.QuestRow and ER.QuestRow(id)
  if row and tonumber(row.p) then return tonumber(row.p) end
  if pfQuest_xpGuide_QuestPre and pfQuest_xpGuide_QuestPre[id] then return pfQuest_xpGuide_QuestPre[id] end
  local db = pfDB and pfDB["quests"] and pfDB["quests"]["data"]
  local q = db and db[id]
  local pre = q and q["pre"]
  if type(pre) == "table" then return tonumber(pre[1]) end
  return tonumber(pre)
end

-- The quests the next guide needs done first: the prerequisites (followed back) of the quests it picks up, not handed in yet, that
-- this guide picks up, does or hands in at a step still ahead ("Message for the Windrunner" before "The Silver Covenant").
-- { [id] = true }, and the same as a list { { id, title } } in this guide's order.
function S.Bridges(nextInfo)
  local set, list = {}, {}
  if not guide or not state or not nextInfo or type(nextInfo.steps) ~= "string" or not ER.QuestRow then return set, list end
  local need = {}
  for id in string.gfind(nextInfo.steps, "\nA\t[^\t\n]*\t(%d+)") do
    local p, guard = S.QuestPre(tonumber(id)), 0
    while p and p ~= 0 and not need[p] and not S.TurnedIn(p) and guard < 20 do
      need[p] = true
      p = S.QuestPre(p)
      guard = guard + 1
    end
  end
  -- only those you can still get: in your log, or offered once their own prerequisite is done (or is one of these)
  local can, changed = {}, true
  while changed do
    changed = false
    for q in pairs(need) do
      if not can[q] then
        local p = S.QuestPre(q)
        if S.InLog(q) or not p or p == 0 or S.TurnedIn(p) or can[p] then can[q] = true changed = true end
      end
    end
  end
  need = can
  for i = state.pos, table.getn(guide.steps) do
    local step = guide.steps[i]
    if not state.passed[i] then
      for _, e in ipairs(step.elements) do
        local id = tonumber(e.id)
        if id and need[id] and not set[id] and (e.kind == "A" or e.kind == "C" or e.kind == "T") then
          set[id] = true
          table.insert(list, { id = id, title = S.QuestTitle(id) })
        end
      end
    end
  end
  return set, list
end

-- "Hand in, then move on" (and "Move on now", needsOnly, when the next guide needs something of this one): every step ahead is
-- passed over except those hand-ins (a step counts as done once its hand-ins are,
-- its other lines, such as a follow-up to pick up, are left), and when they are done the guide goes on to the next guide you
-- chose (Tracker.lua's NextToStart reads S.ThenGuide).
function S.HandInFirst(nextKey, needsOnly)
  if not guide or not state then return false end
  -- needsOnly ("Move on now"): only what the next guide needs, not the other finished quests
  local list = needsOnly and {} or S.ReadyHandIns()
  local keep = {}
  for _, h in ipairs(list) do
    keep[h.n] = keep[h.n] or {}
    table.insert(keep[h.n], { kind = "T", id = h.id })
  end
  -- and what the next guide needs done first: those quests picked up, done and handed in where this guide does it
  local bridge = S.Bridges(S.Find(nextKey))
  for i = state.pos, table.getn(guide.steps) do
    if not state.passed[i] then
      for _, e in ipairs(guide.steps[i].elements) do
        local id = tonumber(e.id)
        if id and bridge[id] and (e.kind == "A" or e.kind == "C" or e.kind == "T") then
          keep[i] = keep[i] or {}
          table.insert(keep[i], { kind = e.kind, id = id, bridge = true })
        end
      end
    end
  end
  for i = state.pos, table.getn(guide.steps) do
    if not keep[i] then state.passed[i] = state.passed[i] or "skip" end
  end
  state.handIn = keep
  state.thenGuide = nextKey
  for i = table.getn(state.side), 1, -1 do
    if not keep[state.side[i]] then table.remove(state.side, i) end
  end
  BeginStep()
  Advance()
  Changed()
  if ER.ArrowUpdate then ER.ArrowUpdate() end
  return next(keep) ~= nil
end

-- The guide chosen with "Hand in, then move on", once this guide is done; nil otherwise.
function S.ThenGuide()
  local key = state and state.thenGuide
  return key and S.Find(key) or nil
end

-- Jumps to a step picked from the list. Going forward leaves the steps in between behind.
function S.Jump(n)
  if not guide or not guide.steps[n] then return end
  if n > state.pos then
    for i = state.pos, n - 1 do state.passed[i] = state.passed[i] or "skip" end
  end
  state.passed[n] = nil
  -- back to a step you skipped yourself: what that skip left out comes back too (its quests' chains, and the steps passed
  -- over with it)
  local with = state.skipWith and state.skipWith[n]
  if with and state.mine and state.mine[n] then
    if ER.OnStepUnskipped then ER.OnStepUnskipped(with.ids) end
    for _, i in ipairs(with.auto or {}) do
      if state.passed[i] == "skip" and not (state.mine and state.mine[i]) then state.passed[i] = nil end
    end
    state.skipWith[n] = nil
  end
  if state.mine then state.mine[n] = nil end
  if state.retaken and state.retaken.n == n then state.retaken = nil end
  state.pos = n
  live.holdAt, live.holdWasDone, live.holdNear = n, StepDone(guide.steps[n]), nil
  BeginStep()
  Advance()
  Changed()
end

-- The tick box of a later step in the guide window's list: ticked (on), the guide passes over it when it gets there; unticked
-- again, the step is back. Only for steps after the one you are on.
function S.SkipLater(n, on)
  if not guide or not guide.steps[n] or n <= state.pos then return end
  if on and S.Finished(guide.steps[n]) then return end
  state.mine = state.mine or {}
  if on then state.passed[n], state.mine[n] = "skip", true else state.passed[n], state.mine[n] = nil, nil end
  Changed()
end

-- Did this guide hand the quest in? A hand-in step for it that is behind you and that the guide marked done (not one you
-- skipped). Counts hand-ins the addon did not see happen (done before it was installed, or with it off) once the guide has
-- moved past them, so the zone's "X/N quests" agrees with the ticked steps.
function S.HandedInHere(id)
  id = tonumber(id)
  if not guide or not id then return false end
  for i = 1, math.min(state.pos - 1, table.getn(guide.steps)) do
    if state.passed[i] == "done" then
      for _, e in ipairs(guide.steps[i].elements) do
        if e.kind == "T" and tonumber(e.id) == id then return true end
      end
    end
  end
  return false
end

-- Is a step's quest work finished, so it must not be skipped? A step that is done, or one whose quest (to hand in or
-- to work on) is complete in your log: only the hand-in is left, and skipping would throw it away.
function S.Finished(step)
  if type(step) ~= "table" then return false end
  if StepDone(step) then return true end
  for _, e in ipairs(step.elements or {}) do
    if (e.kind == "T" or e.kind == "C") and e.id and e.id ~= 0 then
      local row = S.InLog(e.id)
      if row and row.complete then return true end
    end
  end
  return false
end

-- Can a step behind you be taken back (unticked in the list)? Only one that was not finished: a skipped step whose quests are
-- not done since.
function S.CanUnskip(n)
  if not guide or not guide.steps[n] or n >= state.pos then return false end
  -- a step left behind because you abandoned its quest (or one before it in its chain) can be taken back while the quest
  -- can still be picked up; once it cannot, it is skipped for good
  if S.AbandonedIn(guide.steps[n]) then return true end
  if S.DroppedIn(guide.steps[n]) then return false end
  -- your own skip: while any of the step's quests can still be done (a step can hold quests of several chains)
  if state.mine and state.mine[n] and state.passed[n] == "skip" then
    local ids = S.StepQuests(guide.steps[n])
    if table.getn(ids) > 0 then
      local any = false
      for _, id in ipairs(ids) do if S.CanPickUp(id) then any = true end end
      if not any then return false end
      -- one can still be done: it can be taken back (the skip's "left out" marks would make the step look done)
      return true
    end
  end
  if state.passed[n] == "done" then return false end
  if StepDone(guide.steps[n]) then return false end
  return true
end

------------------------------------------------------------------------------------------------------
-- Abandoned quests
------------------------------------------------------------------------------------------------------

-- The guide's quest ids with this title (or this pfQuest id, when it is one of the guide's).
local function GuideIdsFor(title, pfid)
  local out, seen = {}, {}
  if not guide then return out end
  local want = NormTitle(title)
  for _, step in ipairs(guide.steps) do
    for _, e in ipairs(step.elements) do
      local id = (e.kind == "A" or e.kind == "C" or e.kind == "T") and tonumber(e.id)
      if id and id > 0 and not seen[id] then
        if (pfid and tonumber(pfid) == id) or (not pfid and NormTitle(S.QuestTitle(id)) == want) then
          seen[id] = true
          table.insert(out, id)
        end
      end
    end
  end
  return out
end

-- GuideIdsFor, plus the quest itself when this guide has no step for it (RestedXP's route: a chain's first quest in one guide,
-- the rest in the next): by its pfQuest id, or by title among the quests you abandoned.
local function QuestIdsFor(title, pfid)
  local out = GuideIdsFor(title, pfid)
  local seen = {}
  for _, id in ipairs(out) do seen[id] = true end
  local id = tonumber(pfid)
  if id and id > 0 and not seen[id] then
    table.insert(out, id)
    seen[id] = true
  end
  if not pfid and title then
    local want = NormTitle(title)
    local mine = S.CharAbandoned and S.CharAbandoned() or {}
    for aid in pairs(mine) do
      if not seen[aid] and NormTitle(S.QuestTitle(aid)) == want then
        table.insert(out, aid)
        seen[aid] = true
      end
    end
  end
  return out
end

-- The abandoned quest a step is about (one of its pick-ups, quest work or hand-ins), or nil.
function S.AbandonedIn(step)
  if not state or not state.abandoned or type(step) ~= "table" then return nil end
  for _, e in ipairs(step.elements or {}) do
    local id = (e.kind == "A" or e.kind == "C" or e.kind == "T") and tonumber(e.id)
    if id and state.abandoned[id] then return id end
  end
  -- a later quest of an abandoned quest's chain, held back by it: the abandoned one is what to take back
  for aid in pairs(state.abandoned) do
    for _, f in ipairs((ER.QuestsAfter and ER.QuestsAfter(aid)) or {}) do
      for _, e in ipairs(step.elements or {}) do
        if (e.kind == "A" or e.kind == "C" or e.kind == "T") and tonumber(e.id) == f and not S.TurnedIn(f) then return aid end
      end
    end
  end
  return nil
end

-- Can an abandoned quest still be picked up? Not once it is handed in, or while the game would not offer it (below its
-- level, or the quest before it in its chain not handed in).
local function PickUpStep(id)
  for i, step in ipairs(guide.steps) do
    for _, e in ipairs(step.elements) do
      if e.kind == "A" and tonumber(e.id) == id then return i, step end
    end
  end
  return nil
end

function S.CanPickUp(id)
  id = tonumber(id)
  if not guide or not id then return false end
  if S.TurnedIn(id) then return false end
  -- a grey quest (too easy for you now) is no longer worth going back for, even one still in your log; unless this guide needs it
  if S.TooEasy(id) and not (guide.needed and guide.needed[id]) then return false end
  if S.InLog(id) then return true end
  local _, step = PickUpStep(id)
  if NotYet(id, step) then return false end
  return true
end

-- An abandoned quest that can no longer be picked up is skipped for good: its steps (and its chain's) stay skipped and
-- are not offered back. Run before the list is drawn.
function S.SettleAbandoned()
  if not state or not state.abandoned then return end
  for id in pairs(state.abandoned) do
    if not S.CanPickUp(id) then
      state.abandoned[id] = nil
      if S.CharAbandoned then S.CharAbandoned()[id] = nil end
      state.dropped = state.dropped or {}
      state.dropped[id] = true
    end
  end
end

-- A quest skipped for good after abandoning it (S.SettleAbandoned), or one of its chain's later quests: never shown as
-- completed, never offered back.
function S.DroppedIn(step)
  if not state or not state.dropped or type(step) ~= "table" then return nil end
  for did in pairs(state.dropped) do
    local related = { [did] = true }
    for _, f in ipairs((ER.QuestsAfter and ER.QuestsAfter(did)) or {}) do related[f] = true end
    for _, e in ipairs(step.elements or {}) do
      local id = (e.kind == "A" or e.kind == "C" or e.kind == "T") and tonumber(e.id)
      if id and related[id] and not S.TurnedIn(id) then return did end
    end
  end
  return nil
end

-- The step of each abandoned quest that is shown as a button in the list: its pick-up step (or, with none in this guide,
-- its first step). { [step number] = quest id }.
function S.RegainSteps()
  local out = {}
  if not guide or not state then return out end
  -- abandoned quests: their pick-up step (or, with none in this guide, their first step)
  for id in pairs(state.abandoned or {}) do
    local n = PickUpStep(id)
    if not n then
      for i, step in ipairs(guide.steps) do
        for _, e in ipairs(step.elements) do
          if (e.kind == "C" or e.kind == "T") and tonumber(e.id) == id and not n then n = i end
        end
      end
    end
    if n and n < state.pos then out[n] = { id = id, kind = "abandoned" } end
  end
  -- steps you skipped yourself that still have a quest you can do. A step may hold quests of several chains (picked up
  -- together before any is done): it counts while any of them can still be done, and it is left out only when every one
  -- of its quests comes back with an earlier skipped (or abandoned) quest, as a later part of that quest's chain.
  local skipped = {}
  for i = 1, math.min(state.pos - 1, table.getn(guide.steps)) do
    if state.mine and state.mine[i] and state.passed[i] == "skip" then
      local ids = S.StepQuests(guide.steps[i])
      local open = {}
      for _, id in ipairs(ids) do
        if not (state.abandoned and state.abandoned[id]) and S.CanPickUp(id) then table.insert(open, id) end
      end
      if table.getn(open) > 0 then table.insert(skipped, { n = i, ids = open }) end
    end
  end
  local seenQuest = {}
  for k, sk in ipairs(skipped) do
    local new = {}
    for _, id in ipairs(sk.ids) do
      local under = seenQuest[id]
      if not under then
        for j, other in ipairs(skipped) do
          if j < k then
            for _, oid in ipairs(other.ids) do
              for _, f in ipairs((ER.QuestsAfter and ER.QuestsAfter(oid)) or {}) do if f == id then under = true end end
            end
          end
        end
        for aid in pairs(state.abandoned or {}) do
          for _, f in ipairs((ER.QuestsAfter and ER.QuestsAfter(aid)) or {}) do if f == id then under = true end end
        end
      end
      if not under then table.insert(new, id) end
    end
    for _, id in ipairs(sk.ids) do seenQuest[id] = true end
    if table.getn(new) > 0 and not out[sk.n] then out[sk.n] = { id = new[1], ids = new, kind = "skipped" } end
  end
  return out
end

-- Every quest a step is about (pick-ups, quest work, hand-ins), each once, in order.
function S.StepQuests(step)
  local out, seen = {}, {}
  for _, e in ipairs((step and step.elements) or {}) do
    local id = (e.kind == "A" or e.kind == "C" or e.kind == "T") and tonumber(e.id)
    if id and id > 0 and not seen[id] then
      seen[id] = true
      table.insert(out, id)
    end
  end
  return out
end

-- The quest a step is about: its first pick-up, quest work or hand-in. nil for a step with none.
function S.MainQuest(step)
  for _, e in ipairs((step and step.elements) or {}) do
    local id = (e.kind == "A" or e.kind == "C" or e.kind == "T") and tonumber(e.id)
    if id and id > 0 then return id end
  end
  return nil
end

-- The steps behind you for an abandoned quest's work and hand-in, which come back: the ones the guide passed over, and
-- the ones done before you abandoned it (a quest picked up again starts from nothing). Not while it counts as handed in.
local function PassedFor(id, pickup)
  local out = {}
  if S.TurnedIn(id) or (pickup and S.InLog(id)) then return out end
  for i = 1, math.min(state.pos - 1, table.getn(guide.steps)) do
    local p = state.passed[i]
    if (p == "skip" and not (state.mine and state.mine[i])) or p == "done" then
      for _, e in ipairs(guide.steps[i].elements) do
        if (e.kind == "C" or e.kind == "T" or (pickup and e.kind == "A")) and tonumber(e.id) == id then
          table.insert(out, i)
          break
        end
      end
    end
  end
  return out
end

-- The quests after this one in its chain that are not handed in yet: abandoning it held them back too (their pick-ups wait for
-- it), so they come back with it.
local function ChainAfter(id)
  local out = {}
  for _, f in ipairs((ER.QuestsAfter and ER.QuestsAfter(id)) or {}) do
    if not S.TurnedIn(f) then table.insert(out, f) end
  end
  return out
end

-- Every step behind you that comes back for an abandoned quest: its own work and hand-in, and its chain's later quests
-- (pick-up, work, hand-in). Returns the list and the first of them.
local function BackFor(id)
  local all, first = {}, nil
  local function Add(list)
    for _, i in ipairs(list) do
      table.insert(all, i)
      if not first or i < first then first = i end
    end
  end
  Add(PassedFor(id))
  for _, f in ipairs((ChainAfter(id))) do Add(PassedFor(f, true)) end
  return all, first
end

-- The quests you abandoned, per character, so every guide knows (RestedXP's route spreads a chain over several guides, and each
-- guide keeps its own record): ER.db.abandoned[char] = { [quest id] = true }.
local function CharAbandoned()
  if not ER.db then return {} end
  if type(ER.db.abandoned) ~= "table" then ER.db.abandoned = {} end
  local who = ER.Char()
  if type(ER.db.abandoned[who]) ~= "table" then ER.db.abandoned[who] = {} end
  return ER.db.abandoned[who]
end
S.CharAbandoned = CharAbandoned

-- Recorder.lua: a quest left your log and was not handed in. Its steps the guide passes over from now on can be taken back.
function S.OnAbandon(title, pfid)
  if not guide or not state or not title then return end
  state.abandoned = state.abandoned or {}
  local ids = QuestIdsFor(title, pfid)
  local mine = CharAbandoned()
  for _, id in ipairs(ids) do state.abandoned[id] = true; mine[id] = true end
  Changed()
end

-- Recorder.lua: a quest came into your log. If you had abandoned it, the steps the guide passed over for it come back,
-- and the step box offers to go back to them (S.Retaken).
function S.OnAccept(title, pfid)
  if guide and state and state.dropped and title then
    for _, id in ipairs((GuideIdsFor(title, pfid))) do
      if state.dropped[id] then
        state.dropped[id] = nil
        state.abandoned = state.abandoned or {}
        state.abandoned[id] = true
      end
    end
  end
  if not guide or not state or not title then return end
  local ids = QuestIdsFor(title, pfid)
  local mine = CharAbandoned()
  for _, id in ipairs(ids) do mine[id] = nil end
  if not state.abandoned then return end
  local first
  for _, id in ipairs(ids) do
    if state.abandoned[id] then
      state.abandoned[id] = nil
      local list, f = BackFor(id)
      for _, i in ipairs(list) do state.passed[i] = nil end
      if f and (not first or f < first) then first = f end
    end
  end
  -- picked up again: the guide goes back to its steps by itself (and then carries on where you were), once the quest log
  -- has been read with the quest in it (S.AfterLogScan)
  if first then
    state.retaken = nil
    live.backTo = (live.backTo and live.backTo < first) and live.backTo or first
  end
  Changed()
end

-- Recorder.lua, after each read of the quest log: a pending go-back (a quest picked up again) happens now, with the quest
-- in the log, so its work step is not taken for done.
function S.AfterLogScan()
  local n = live and live.backTo
  if not n or not guide then return end
  live.backTo = nil
  S.Jump(n)
end

-- A quest you abandoned and picked up again, whose steps are behind you: { n = its first step, title }. nil otherwise.
function S.Retaken()
  local r = state and state.retaken
  if not r or not guide or not guide.steps[r.n] or r.n >= state.pos or state.passed[r.n] then return nil end
  return r
end

-- Back to a step of a quest you abandoned (from the list): its passed-over steps come back too. When the quest is not in
-- your log, the guide goes back to where you pick it up.
function S.Retake(n)
  if not guide or not guide.steps[n] then return end
  local id = S.AbandonedIn(guide.steps[n])
  if not id then return S.Jump(n) end
  local target = n
  local list = BackFor(id)
  for _, i in ipairs(list) do
    state.passed[i] = nil
    if i < target then target = i end
  end
  if not S.InLog(id) then
    for i = target - 1, 1, -1 do
      local found = false
      for _, e in ipairs(guide.steps[i].elements) do
        if e.kind == "A" and tonumber(e.id) == id then found = true end
      end
      if found then target = i break end
    end
  end
  state.retaken = nil
  -- you asked to go back to it: no longer abandoned, or the guide would pass its steps over again at once (a step that picks up
  -- several quests, as RestedXP's do, counts as done while this one is abandoned)
  if state.abandoned then state.abandoned[id] = nil end
  CharAbandoned()[id] = nil
  S.Jump(target)
end

-- The step you just skipped with the Skip button, while you are still on the step the skip took you to: the guide window
-- offers "Unskip previous" for it. nil otherwise.
function S.SkippedBehind()
  if not guide or not state.mine then return nil end
  local n = state.lastSkip
  if not n or n >= state.pos or not state.mine[n] or state.passed[n] ~= "skip" then return nil end
  -- a step whose quests are finished by now is not offered back
  if StepDone(guide.steps[n]) then return nil end
  -- only until the guide moves on from where the skip left you
  if state.lastSkipTo ~= state.pos then return nil end
  return n
end

-- Ticks a step by hand (a "do this" line with nothing the game can check).
function S.Tick(n)
  if not guide then return end
  local step = guide.steps[n or state.pos]
  if not step then return end
  Fire(step, "tick")
  if live.holdAt == step.n then live.holdAt = nil end
  S.Check()
end

------------------------------------------------------------------------------------------------------
-- The arrow's target
------------------------------------------------------------------------------------------------------

local function Reach(step, i)
  return live.reached and live.reached[step.n .. ":" .. i]
end

-- The first place in a step you have not reached yet. Points "on the way" (flag 0) count as reached when you get
-- within their radius; the last place is the destination.
local function NextPlace(step)
  local places = {}
  for i, e in ipairs(step.elements) do
    if e.kind == "G" then table.insert(places, { i = i, e = e }) end
  end
  local n = table.getn(places)
  if n == 0 then return nil end
  for j, p in ipairs(places) do
    local last = j == n
    if last or not Reach(step, p.i) then
      if not last and p.e.radius and Arrived(p.e, p.e.radius) then
        live.reached[step.n .. ":" .. p.i] = true
      else
        return p.e
      end
    end
  end
  -- A loop goes round again.
  if step.flags.loop then
    for _, p in ipairs(places) do live.reached[step.n .. ":" .. p.i] = nil end
  end
  return places[n].e
end

-- The zone the guide has you in at a step: the last place (G) at or before it.
local function GuideZone(step)
  if not guide or not step or not step.n then return nil end
  for n = step.n, 1, -1 do
    local st = guide.steps[n]
    if st then
      for i = table.getn(st.elements), 1, -1 do
        local e = st.elements[i]
        if e.kind == "G" and e.zone and e.zone ~= "" then return e.zone, e.x, e.y end
      end
    end
  end
  return nil
end

-- Where to go for a quest's objectives: a spot in the guide's zone when there is one. The data names only the best-known spot of
-- each target, which can be another zone (wolves that mostly live in Dun Morogh, for a quest done in Elwynn Forest); with a zone
-- known and no objective in it there is no spot (the caller falls back to the hand-in place). With no zone, the first spot.
local function ObjectiveSpot(facts, zone, gx, gy)
  -- Where you are in that zone (else the guide's place there): the spawn nearest to it, like pfQuest's own arrow.
  if zone and ER.SpawnNear then
    local hz, hx, hy = S.Here()
    local rx, ry = gx, gy
    if hz and string.lower(hz) == string.lower(zone) and hx and hy and not (hx == 0 and hy == 0) then rx, ry = hx, hy end
    if rx and ry then
      local best
      for _, o in pairs(facts.objectives or {}) do
        for _, r in ipairs(o.refs or {}) do
          local w = ER.SpawnNear(r.db, r.id, zone, rx, ry)
          if w and (not best or w.d < best.d) then best = w end
        end
      end
      if best then return best end
    end
  end
  local names = {}
  for name in pairs(facts.objectives or {}) do table.insert(names, name) end
  table.sort(names)
  local first
  for _, name in ipairs(names) do
    local o = facts.objectives[name]
    local list = { o.where }
    for _, w in ipairs(o.wheres or {}) do table.insert(list, w) end
    for _, w in ipairs(list) do
      if w and w.map and w.x then
        if not zone or string.lower(w.map) == string.lower(zone) then return w end
        first = first or w
      end
    end
  end
  if zone then return nil end
  return first
end

local function QuestPlace(step)
  for _, e in ipairs(step.elements) do
    local done = ElementDone(step, e)
    if e.kind == "A" and not done then
      local row = ER.QuestRow and ER.QuestRow(e.id)
      local z = row and pfQuest_xpGuide_Zones and pfQuest_xpGuide_Zones[row.zone]
      if row and z and row.x then return { zone = z.name, x = row.x, y = row.y, text = row.g } end
    elseif (e.kind == "T" or e.kind == "C") and not done then
      local facts = ER.QuestFacts and ER.QuestFacts(e.id)
      if facts then
        local w
        if e.kind == "T" then w = facts.taker and facts.taker.where
        else local gz, gx, gy = GuideZone(step); w = ObjectiveSpot(facts, gz, gx, gy) end
        if w and w.map and w.x then return { zone = w.map, x = w.x, y = w.y, text = e.kind == "T" and facts.taker.name or nil } end
      end
      -- A quest to do that pfQuest has no objective spot for (talk to someone, deliver something: "A Good Friend") is done
      -- where it is handed in. With no place at all, pfQuest's own arrow went to another quest's objective instead.
      if e.kind == "C" then
        local p = S.PlaceFor({ id = e.id, what = "turnin" })
        if p then
          p.text = "Finish " .. (S.QuestTitle(e.id) or "the quest")
          return p
        end
      end
    end
  end
  return nil
end

-- A step whose only open work is handing in quests you have not finished: the arrow goes to where the first one's
-- objectives are (the guide's own place for them when a step near you has one, else pfQuest's), not to the NPC who
-- takes it. nil when there is other work in the step, or no place is known.
local function UnfinishedPlace(step)
  local first
  for _, e in ipairs(step.elements) do
    if ElementDone(step, e) == false then
      if e.kind ~= "T" or not LeftToDo(e.id) then return nil end
      first = first or e
    end
  end
  if not first then return nil end
  local title = S.QuestTitle(first.id)
  return S.PlaceFor({ id = first.id, title = title and ("Finish " .. title) or nil, what = "do" })
end

-- VanillaGuide's steps have one map spot for a whole line ("accept X from Ilthalaine, then kill the boars at (57, 45)"),
-- usually where the quest is done. On those steps (flag vg) the arrow follows the line part by part: the first thing not
-- done yet decides. A quest to pick up: its quest giver. A quest to do: the spot the line's words give for it (TextPlace),
-- else the guide's spot. A quest to hand in: the hand-in NPC (RestedXP's place, else pfQuest's), else the guide's spot.
-- The spot the step's own words give for a quest to do. VanillaGuide's one map spot for a line is often a stop between two
-- things ("get Webwood Ichor ... (57, 32). Get Webwood Egg ... at (57, 26) inside the cave" has its spot at (57, 36)), so
-- the arrow goes where the line says the quest is done. The quest is found where the guide names it as a quest (in the
-- quest colour; a place can have the same name, "Grind up to the Jasperlode Mine at (61, 53) ... for The Jasperlode
-- Mine"), and the spot taken from its own sentence: "kill ogres at (81, 42) for Extinguish the Firegut then run back to
-- (84, 68)" is done at (81, 42), the spot before "for <quest>"; "Webwood Egg at (57, 26)" at the first spot after it.
local COORD = "%((%d+%.?%d*)%s*,%s*(%d+%.?%d*)%)"
local function Breaks(text)
  local out, init = {}, 1
  while true do
    local a, b = string.find(text, "[%.;!]%s", init)
    if not a then break end
    table.insert(out, { a, b })
    init = b + 1
  end
  init = 1
  while true do
    local a, b = string.find(text, "%sthen%s", init)
    if not a then break end
    table.insert(out, { a, b })
    init = b + 1
  end
  return out
end
local function Coords(text)
  local out = {}
  for x, y in string.gfind(text, COORD) do
    x, y = tonumber(x), tonumber(y)
    if x and y and x > 0 and x < 100 and y > 0 and y < 100 then table.insert(out, { x, y }) end
  end
  return out
end
local function TextPlace(step, title, zone)
  if not title or not zone then return nil end
  local name = string.lower(Plain(title))
  for _, e in ipairs(step.elements) do
    if e.kind == "I" and e.text then
      local raw = string.lower(e.text)
      local at = string.find(raw, "|cffffd100" .. name, 1, true)
      if not at then at = string.find(raw, name, 1, true) end
      if at then
        local before = Plain(string.sub(raw, 1, at - 1))
        local after = string.sub(Plain(string.sub(raw, at)), string.len(name) + 1)
        -- its sentence: back to the last break before the name, on to the first break after it
        local from = 0
        for _, br in ipairs(Breaks(before)) do if br[2] > from then from = br[2] end end
        before = string.sub(before, from + 1)
        local to
        for _, br in ipairs(Breaks(after)) do if not to or br[1] < to then to = br[1] end end
        if to then after = string.sub(after, 1, to - 1) end
        local b, a = Coords(before), Coords(after)
        local nb = table.getn(b)
        if nb > 0 and string.find(before, "for%s*$") then return b[nb][1], b[nb][2] end
        if a[1] then return a[1][1], a[1][2] end
        if nb > 0 then return b[nb][1], b[nb][2] end
        return nil
      end
    end
  end
  return nil
end

local function PartPlace(step)
  if not step.flags.vg then return nil end
  local spot
  for _, e in ipairs(step.elements) do if e.kind == "G" then spot = e end end
  for _, e in ipairs(step.elements) do
    if (e.kind == "A" or e.kind == "C" or e.kind == "T") and ElementDone(step, e) == false then
      local title = S.QuestTitle(e.id) or "the quest"
      if e.kind == "A" then
        local row = ER.QuestRow and ER.QuestRow(e.id)
        local z = row and pfQuest_xpGuide_Zones and pfQuest_xpGuide_Zones[row.zone]
        -- the quest data's giver, when it is in the step's zone (the data puts a few givers in the wrong zone); otherwise
        -- the guide's own spot
        if row and z and row.x and (not spot or string.lower(spot.zone or "") == string.lower(z.name)) then
          return { zone = z.name, x = row.x, y = row.y, text = "Accept " .. title .. (row.g and (" from " .. row.g) or "") }
        end
        -- not in the quest data: RestedXP's place for picking it up, when in the step's zone (or the step has no spot)
        local pz, px, py
        if ER.RoutePickUpPlace then pz, px, py = ER.RoutePickUpPlace(e.id) end
        if pz and (not spot or string.lower(spot.zone or "") == string.lower(pz)) then
          return { zone = pz, x = px, y = py, text = "Accept " .. title }
        end
        if spot then return { zone = spot.zone, x = spot.x, y = spot.y, text = "Accept " .. title } end
        return nil
      elseif e.kind == "C" then
        local tx, ty = TextPlace(step, S.QuestTitle(e.id), spot and spot.zone)
        if tx then return { zone = spot.zone, x = tx, y = ty, text = "Finish " .. title } end
        if spot then return { zone = spot.zone, x = spot.x, y = spot.y, text = "Finish " .. title } end
        return nil
      else
        local zone = spot and spot.zone
        local hx, hy
        if ER.RouteHandInPlace then hx, hy = ER.RouteHandInPlace(e.id, zone) end   -- ("a and f()" would keep only hx)
        if hx then return { zone = zone, x = hx, y = hy, text = "Hand in " .. title } end
        local facts = ER.QuestFacts and ER.QuestFacts(e.id)
        local w = facts and facts.taker and facts.taker.where
        if w and w.map and w.x then return { zone = w.map, x = w.x, y = w.y, text = "Hand in " .. title .. " to " .. (facts.taker.name or "") } end
        if spot then return { zone = spot.zone, x = spot.x, y = spot.y, text = "Hand in " .. title } end
        return nil
      end
    end
  end
  return nil
end
S.PartPlace = PartPlace
S.TextPlace = TextPlace

-- A place with no words of its own is labelled with what the step says ("Talk to Deputy Willem").
local function Labelled(step, e)
  if not e or e.text then return e end
  if not e.label then
    for _, o in ipairs(step.elements) do
      if o.kind == "I" and o.text then e.label = o.text break end
    end
    e.label = e.label or S.Title(step)
  end
  return { zone = e.zone, x = e.x, y = e.y, radius = e.radius, text = e.label }
end

-- Where the arrow should point now: { zone, x, y, text } or nil.
function S.Target()
  if not guide then return nil end
  for _, step in ipairs((S.Side())) do
    if step.flags.completewith then
      local p = NextPlace(step)
      if p then return Labelled(step, p) end
    end
  end
  local cur = S.Current()
  if not cur then return nil end
  if cur.flags.grind and ER.GrindTarget then
    local grindPlace = ER.GrindTarget(cur)
    if grindPlace then return grindPlace end
  end
  return PartPlace(cur) or UnfinishedPlace(cur) or Labelled(cur, NextPlace(cur)) or QuestPlace(cur)
end

------------------------------------------------------------------------------------------------------
-- What the window says
------------------------------------------------------------------------------------------------------

local function Where(x, y)
  return "(" .. math.floor(x + 0.5) .. ", " .. math.floor(y + 0.5) .. ")"
end

-- Your experience against a grind target, updated as you kill: "you: level 5, 1840/2800 xp, 510 to go".
local function XpNow(e)
  local now, xp, max = UnitLevel("player") or 1, UnitXP("player") or 0, UnitXPMax("player") or 0
  local level, s = tonumber(e.level) or now, e.xp or ""
  local sign = string.sub(s, 1, 1)
  local togo
  if now == level and s ~= "" and sign ~= "-" then
    if sign == "." then togo = math.ceil((tonumber("0" .. s) or 0) * max) - xp
    else togo = (tonumber(s) or 0) - xp end
  elseif now == level - 1 then
    togo = max - xp
    if sign == "-" then togo = togo - (tonumber(string.sub(s, 2)) or 0) end
  end
  local out = "you: level " .. now .. ", " .. xp .. "/" .. max .. " xp"
  if togo and togo > 0 then out = out .. ", " .. togo .. " to go" end
  return out
end

-- A grind target in plain words instead of RestedXP's "Grind to 2350+/2800xp".
local function GrindText(e)
  local level, s = tonumber(e.level) or 1, e.xp or ""
  local sign = string.sub(s, 1, 1)
  if s == "" then return "Grind until level " .. level end
  if sign == "." then return "Grind until halfway through level " .. level end
  if sign == "-" then return "Grind until you are " .. string.sub(s, 2) .. " xp short of level " .. level end
  return "Grind until level " .. level .. " and " .. (tonumber(s) or s) .. " xp"
end

-- One element as a line: { text, done (true/false/nil for plain text), kind }. nil for lines not worth showing.
function S.Line(step, e)
  local k = e.kind
  local text = QuestWords(e.text)
  -- A grind step of the casual route names the mob and the place (Grind.lua); without a spot the route's own words stay.
  if k == "I" and step.flags.grind and ER.GrindText then
    local grindText = ER.GrindText(step)
    if grindText then text = grindText end
  end
  if k == "G" then
    if not text then
      -- A place with no words only gets a line when the step has nothing else to say.
      for _, o in ipairs(step.elements) do
        if o.kind ~= "G" and o.kind ~= "Q" and o.kind ~= "W" and o.kind ~= "SW" and o.kind ~= "L" and o.kind ~= "N" then return nil end
      end
      if LastPlace(step) ~= e then return nil end
      text = "Go to " .. e.zone .. " " .. Where(e.x, e.y)
    end
    return { text = text, kind = k }
  end
  if k == "Q" or k == "W" or k == "SW" or k == "L" or k == "N" then return nil end
  if (k == "I" or k == "M") and HasMoney() and MoneyText(text) then return nil end
  if LateTrainer(e, step) then return nil end
  if k == "A" and (LeftOut(e.id) or Blocked(e, step)) and not S.TurnedIn(e.id) then return nil end
  local done = ElementDone(step, e)
  if k == "A" then text = text or ("Accept " .. (S.QuestTitle(e.id) or ("quest " .. e.id)))
  elseif k == "T" then
    text = text or ("Hand in " .. (S.QuestTitle(e.id) or ("quest " .. e.id)))
    -- Only on the step you are on (and the ones beside it): a hand-in further on is still to come anyway.
    local open = not done and state and step.n and step.n <= state.pos and LeftToDo(e.id)
    if open then text = text .. " " .. GOLDISH .. "(Finish it first: " .. table.concat(open, ", ") .. ")|r" end
  elseif k == "C" then
    text = text or ("Finish " .. (S.QuestTitle(e.id) or ("quest " .. e.id)))
    if e.obj and not done then
      local progress = S.Objective(e.id, e.obj)
      if progress then text = text .. " " .. GOLDISH .. "(" .. progress .. ")|r" end
    elseif not e.obj and not done then
      -- No objective named: say what is left of the first one, so the line tells what to do now.
      for _, o in ipairs((S.Objectives(S.QuestTitle(e.id)))) do
        if not o.done then
          text = text .. " " .. GOLDISH .. "(" .. o.text .. ")|r"
          break
        end
      end
    end
  elseif k == "K" then
    if not text or text == "" then return nil end
    if not done then text = text .. " " .. GOLDISH .. "(" .. S.ItemCount(e.item) .. "/" .. (e.count or 1) .. ")|r" end
  elseif k == "X" then
    if e.skip or e.op == "<" then return nil end
    text = GrindText(e)
    if not done then text = text .. " " .. GOLDISH .. "(" .. XpNow(e) .. ")|r" end
  elseif k == "U" then
    if not text or text == "" then return nil end
  end
  if not text or text == "" then return nil end
  return { text = text, done = done, kind = k }
end

-- A short name for a step in the list: its title, or the first thing it asks for.
function S.Title(step)
  if step.flags.grind and ER.GrindTitle then
    local grindTitle = ER.GrindTitle(step)
    if grindTitle then return grindTitle end
  end
  if step.flags.title and step.flags.title ~= "" then return step.flags.title end
  local best, train
  for _, e in ipairs(step.elements) do
    local line = S.Line(step, e)
    if line then
      if e.kind == "A" or e.kind == "T" or e.kind == "C" then return line.text end
      best = best or line.text
      if e.kind == "V" and e.what ~= "vendor" then train = train or line.text end
    end
  end
  -- A trainer visit says so ("Learn new spells from Rupert"), not just "Talk to Rupert", which reads like a quest.
  if train and best then
    local _, _, name = string.find(best, "^Talk to (|c%x+.-|r)")
    if name then
      local what = "new spells"
      local _, _, one = string.find(train, "^Train (%[.-%])$")
      if one then what = one end
      return "Learn " .. what .. " from " .. name
    end
  end
  return best or "..."
end

-- Does this step need ticking by hand? (Nothing in it the game can check, and no place to reach.)
function S.ByHand(step)
  for _, e in ipairs(step.elements) do
    if ElementDone(step, e) ~= nil then return false end
  end
  return LastPlace(step) == nil
end

------------------------------------------------------------------------------------------------------
-- The simple list, warnings, and enemies to watch out for
------------------------------------------------------------------------------------------------------

-- The steps the guide is busy with: the current one, the ones beside it, then the next few.
local function NearSteps(ahead)
  local list = {}
  local cur = S.Current()
  if cur then table.insert(list, cur) end
  for _, s in ipairs((S.Side())) do table.insert(list, s) end
  for _, s in ipairs((S.Upcoming(ahead))) do table.insert(list, s) end
  return list
end

-- The quests for the simple list, in the order the guide gets to them: the ones in the current and side steps,
-- the ones coming up, then anything else in your quest log. Each: { id, title, level, what = "pickup", "do" or
-- "turnin", who }. Quests to pick up only come from the next few steps, so the list stays about here and now.
function S.QuestList(max)
  local out, seen = {}, {}
  if not guide then return out end
  local near = NearSteps(20)
  for i, step in ipairs(near) do
    for _, e in ipairs(step.elements) do
      local k = e.kind
      local id = e.id
      if (k == "A" or k == "T" or k == "C" or k == "K") and id and id ~= 0 and not seen[id] then
        local title = S.QuestTitle(id)
        if title and not seen[title] and not S.TurnedIn(id) then
          local row = S.InLog(id)
          local what, who
          if row then
            what = row.complete and "turnin" or "do"
            if what == "turnin" then
              local facts = ER.QuestFacts and ER.QuestFacts(id)
              who = facts and facts.taker and facts.taker.name
            end
          elseif k == "A" and i <= 6 and not LeftOut(id) and not NotYet(id, step) then
            what = "pickup"
            local qrow = ER.QuestRow and ER.QuestRow(id)
            who = qrow and qrow.g
          end
          if what then
            seen[id], seen[title] = true, true
            table.insert(out, { id = id, title = title, level = S.QuestLevel(id), what = what, who = who })
          end
        end
      end
    end
  end
  local n = GetNumQuestLogEntries() or 0
  for i = 1, n do
    local title, level, _, header, _, complete = GetQuestLogTitle(i)
    if title and not header and not seen[title] then
      seen[title] = true
      -- complete is 1 when done, -1 when failed.
      table.insert(out, { title = title, level = level, what = complete == 1 and "turnin" or "do" })
    end
  end
  while table.getn(out) > max do table.remove(out) end
  return out
end

-- Where a quest in the simple list happens, for the arrow: the guide's own place for it when a step near you has
-- one, else from the quest data (who gives it, where its targets are, who takes it back).
function S.PlaceFor(q)
  if not guide or not q then return nil end
  local want = q.what == "pickup" and "A" or (q.what == "turnin" and "T" or "C")
  if q.id then
    for _, step in ipairs((NearSteps(30))) do
      for _, e in ipairs(step.elements) do
        if e.id == q.id and (e.kind == want or (want == "C" and e.kind == "K")) then
          local last = LastPlace(step)
          if last then return { zone = last.zone, x = last.x, y = last.y, radius = last.radius, text = q.title } end
        end
      end
    end
    if want == "A" then
      local row = ER.QuestRow and ER.QuestRow(q.id)
      local z = row and pfQuest_xpGuide_Zones and pfQuest_xpGuide_Zones[row.zone]
      if row and z and row.x then return { zone = z.name, x = row.x, y = row.y, text = q.title } end
    else
      local facts = ER.QuestFacts and ER.QuestFacts(q.id)
      local w
      if facts and want == "T" then
        w = facts.taker and facts.taker.where
      elseif facts then
        local gz, gx, gy = GuideZone(S.Current()); w = ObjectiveSpot(facts, gz, gx, gy)
      end
      if w and w.map and w.x then return { zone = w.map, x = w.x, y = w.y, text = q.title } end
      -- A quest to do that pfQuest has no objective spot for (talk to someone, deliver something: "A Good Friend") is done where
      -- it is handed in. Without this the step had no place, and pfQuest's own arrow went to another quest's objective.
      if want == "C" and not q.fallback then
        return S.PlaceFor({ id = q.id, title = q.title, what = "turnin", fallback = true })
      end
    end
  end
  return nil
end

-- RestedXP's own warnings in the steps you are on ("Try to avoid Mangy Duskbats ...", "Be careful ...").
local WARN = { "avoid", "careful", "caution", "cautious", "watch out", "danger", "beware", "elite", "difficult",
  "hits hard", "aggro", "tougher" }
local function WarningText(text)
  if not text then return false end
  local t = string.lower(Plain(text))
  for _, w in ipairs(WARN) do
    if string.find(t, w, 1, true) then return true end
  end
  return false
end

-- Cave words, each with what the player is told it is (mine, crypt or cave). The same list tools/lib/danger-words.js uses.
local CAVE_KIND = { cave = "cave", caves = "cave", cavern = "cave", caverns = "cave", crypt = "crypt", crypts = "crypt", den = "cave",
  grotto = "cave", burrow = "cave", burrows = "cave", hollow = "cave", tunnel = "cave", tunnels = "cave", barrow = "crypt",
  barrows = "crypt", catacomb = "crypt", catacombs = "crypt", lair = "cave", tomb = "crypt", tombs = "crypt", quarry = "mine",
  mines = "mine" }
local CAVE_ORDER = { "mine", "crypt", "cave" }

-- The cave word a text names: "mine", "crypt" or "cave", else nil. "The Den" (a place in Durotar) is no cave, and "mine" counts
-- only as a place ("Fargodeep Mine", "the mine"), not as "this one is mine".
function S.CaveWord(text)
  if type(text) ~= "string" then return nil end
  text = Plain(text)
  local at = string.find(string.lower(text), "the den", 1, true)
  while at do
    text = string.sub(text, 1, at - 1) .. " " .. string.sub(text, at + 7)
    at = string.find(string.lower(text), "the den", 1, true)
  end
  local low = string.lower(text)
  local found = {}
  -- Always the whole word: "Kobold Miners", "Find Minerals" and "Miner's Fortune" are no mine.
  local words = " " .. string.gsub(low, "[^%a]", " ") .. " "
  if string.find(" " .. text .. " ", "[^%a]Mine[^%a]") or string.find(words, " the mine ", 1, true) or string.find(words, " a mine ", 1, true) then
    found.mine = true
  end
  local padded = " " .. string.gsub(low, "[^%a']", " ") .. " "
  for word, kind in pairs(CAVE_KIND) do
    if string.find(padded, " " .. word .. " ", 1, true) then found[kind] = true end
  end
  for _, kind in ipairs(CAVE_ORDER) do
    if found[kind] then return kind end
  end
  return nil
end

-- What the player reads when a step goes into a cave.
local CAVE_TAIL = ", easy to pull too many and hard to run away."
function S.CaveLine(word)
  return "Heads up: this goes into a " .. (word or "cave") .. CAVE_TAIL
end

local ESCORT_LINE = "Escort quest: the NPC is weak and mobs come in waves. Skip it if it goes wrong."
local SAFE_LINE = "Risky quest: Casual leaves it out. Take care."

-- The warnings for the current and side steps, { { text, line, kind, step }, ... }; line is what the player reads. Kinds, in order:
--   cave      the step goes into a cave (the u letter of its quest, or its own words), on every difficulty
--   survival  the quest's danger lines from Data\Survival.lua, on Casual and Medium
--   escort    Medium keeps an escort quest and says so          safe  Medium keeps a quest the safe route skips and says so
--   rxp       the guide's own warning lines
-- Only the first 2 unless all is true (the enemy tooltip wants every one).
function S.Warnings(all)
  local out = {}
  if not guide then return out end
  local list = {}
  local cur = S.Current()
  if cur then table.insert(list, cur) end
  for _, s in ipairs((S.Side())) do table.insert(list, s) end
  local mode = ER.Mode and ER.Mode() or "casual"
  -- Only the quests you are doing: one the difficulty leaves out, and a line already done, say nothing.
  local ids, seen, notDoing = {}, {}, {}
  for _, step in ipairs(list) do
    for _, e in ipairs(step.elements) do
      local id = tonumber(e.id)
      if (e.kind == "A" or e.kind == "C" or e.kind == "K") and id and id ~= 0 then
        if LeftOut(id) or ElementDone(step, e) ~= false then
          notDoing[e] = true
        elseif not seen[id] then
          seen[id] = true
          table.insert(ids, { id = id, step = step })
        end
      end
    end
  end
  local cave, caveStep
  local danger = pfQuest_xpGuide_Danger
  for _, q in ipairs(ids) do
    if not cave and string.find(S.Kinds(q.id), "u", 1, true) then
      cave = type(danger) == "table" and type(danger.caveword) == "table" and danger.caveword[q.id] or "cave"
      caveStep = q.step
    end
  end
  if not cave then
    for _, step in ipairs(list) do
      for _, e in ipairs(step.elements) do
        if not cave and not notDoing[e] then
          cave = S.CaveWord(e.text)
          caveStep = step
        end
      end
    end
  end
  if cave then
    table.insert(out, { text = "this goes into a " .. cave .. CAVE_TAIL, line = S.CaveLine(cave), kind = "cave", step = caveStep })
  end
  local _, _, faction = Me()
  local surv = pfQuest_xpGuide_Survival
  local byFaction = type(surv) == "table" and surv[faction]
  local warn = type(byFaction) == "table" and byFaction.warn
  if (mode == "casual" or mode == "medium") and type(warn) == "table" then
    local said = {}
    for _, q in ipairs(ids) do
      if type(warn[q.id]) == "string" then
        for text in string.gfind(warn[q.id], "[^\n]+") do
          if not said[text] then
            said[text] = true
            table.insert(out, { text = text, line = "Heads up: " .. text, kind = "survival", step = q.step })
          end
        end
      end
    end
  end
  if mode == "medium" then
    local escort, safe
    for _, q in ipairs(ids) do
      local k = S.Kinds(q.id)
      if not escort and string.find(k, "s", 1, true) then escort = q.step end
      if not safe and string.find(k, "v", 1, true) then safe = q.step end
    end
    if escort then table.insert(out, { text = ESCORT_LINE, line = ESCORT_LINE, kind = "escort", step = escort }) end
    if safe then table.insert(out, { text = SAFE_LINE, line = SAFE_LINE, kind = "safe", step = safe }) end
  end
  for _, step in ipairs(list) do
    for _, e in ipairs(step.elements) do
      if (e.kind == "I" or e.kind == "M") and WarningText(e.text) then
        table.insert(out, { text = e.text, line = "Heads up: " .. e.text, kind = "rxp", step = step })
      end
    end
  end
  if all then return out end
  local few = {}
  for i = 1, 2 do
    if out[i] then table.insert(few, out[i]) end
  end
  return few
end

-- One enemy's name as the guides and the game both can write it: lower case, and plural made single ("young
-- wolves" and "Young Wolf" both give "young wolf").
function S.Singular(name)
  name = string.lower(name or "")
  if string.sub(name, -3) == "ves" then return string.sub(name, 1, -4) .. "f" end
  if string.sub(name, -3) == "ies" then return string.sub(name, 1, -4) .. "y" end
  if string.sub(name, -1) == "s" and string.sub(name, -2) ~= "ss" then return string.sub(name, 1, -2) end
  return name
end

-- Enemies the warnings name: the red-coloured names before any "than" ("avoid Mangy Duskbats ... tougher to kill
-- than Duskbats" names Mangy Duskbats only). { { name = singular name, text = the warning }, ... }.
function S.WarnedEnemies()
  local out = {}
  for _, w in ipairs((S.Warnings(true))) do
    local text = w.text
    local cut = string.find(string.lower(text), " than ", 1, true)
    if cut then text = string.sub(text, 1, cut) end
    for name in string.gfind(text, "|c[fF][fF][fF][fF]5722(.-)|r") do
      table.insert(out, { name = S.Singular(name), text = w.text })
    end
  end
  return out
end

-- Enemies the steps you are on send you to kill ("Kill Young Scavengers and Duskbats ..."): the red-coloured names
-- in their "kill" lines, warnings and money lines left aside. A set of singular names.
function S.TargetNames()
  local out = {}
  if not guide then return out end
  local list = {}
  local cur = S.Current()
  if cur then table.insert(list, cur) end
  for _, s in ipairs((S.Side())) do table.insert(list, s) end
  for _, step in ipairs(list) do
    for _, e in ipairs(step.elements) do
      local text = e.text
      if (e.kind == "I" or e.kind == "M") and text and string.find(string.lower(text), "kill", 1, true)
        and not WarningText(text) and not (HasMoney() and MoneyText(text)) then
        for name in string.gfind(text, "|c[fF][fF][fF][fF]5722(.-)|r") do out[S.Singular(name)] = true end
      end
    end
  end
  return out
end

------------------------------------------------------------------------------------------------------
-- Watching the game
------------------------------------------------------------------------------------------------------

-- The hearthstone or a loading screen took you somewhere else: the steps you were on keep their place to go back to (WalkedOff).
local function Jumped()
  if not guide or not state then return end
  live.jumped = live.jumped or {}
  live.near = live.near or {}
  live.jumped[state.pos] = true
  live.near[state.pos] = nil
  for _, s in ipairs(state.side or {}) do live.jumped[s] = true live.near[s] = nil end
end

local function FireAll(what)
  if not guide then return end
  local list = S.Side()
  local cur = S.Current()
  if cur then table.insert(list, cur) end
  for _, step in ipairs(list) do Fire(step, what) end
end

-- A quest was handed in. The quest log has no quest numbers, so the number comes from pfQuest when it can tell,
-- or else from the guide: the quest of that title the current steps hand in.
function S.OnTurnIn(title, pfid)
  if not guide or not title then return end
  local done = DoneTable()
  if pfid then
    done[pfid] = true
    return
  end
  local list = S.Side()
  local cur = S.Current()
  if cur then table.insert(list, 1, cur) end
  -- The first one not already handed in: two quests of one name can be handed in back to back (the paladin's
  -- "The Tome of Divinity", parts 1 and 2, in one step).
  for _, step in ipairs(list) do
    for _, e in ipairs(step.elements) do
      if e.kind == "T" and not done[e.id] and S.QuestTitle(e.id) == title then
        done[e.id] = true
        return
      end
    end
  end
  for i = state.pos, math.min(state.pos + 30, table.getn(guide.steps)) do
    for _, e in ipairs(guide.steps[i].elements) do
      if e.kind == "T" and not done[e.id] and S.QuestTitle(e.id) == title then
        done[e.id] = true
        return
      end
    end
  end
end

-- Looks again at everything and moves on when the step is done. Runs on a timer and after game events.
function S.Check()
  if not guide then return end
  CheckOnce()
  Advance()
  -- A finished guide goes straight on to the next one (Tracker.lua starts it and says so in chat).
  if not S.Current() and ER.AutoNextGuide and ER.AutoNextGuide() then return end
  -- Every time, not only when the step changes: the kill and loot counts ("3/8") move too.
  Changed()
  if ER.ArrowUpdate then ER.ArrowUpdate() end
end

local watcher = CreateFrame("Frame", "pfQuest_xpGuideStepsWatcher")
for _, ev in ipairs({ "BAG_UPDATE", "PLAYER_LEVEL_UP", "PLAYER_XP_UPDATE", "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA",
  "ZONE_CHANGED_INDOORS", "MERCHANT_CLOSED", "TRAINER_CLOSED", "TAXIMAP_OPENED", "SPELLCAST_START", "SPELLCAST_STOP",
  "SPELLCAST_FAILED", "SPELLCAST_INTERRUPTED", "PLAYER_ENTERING_WORLD", "QUEST_LOG_UPDATE" }) do
  watcher:RegisterEvent(ev)
end
watcher.wait = 0
watcher:SetScript("OnEvent", function()
  if event == "PLAYER_ENTERING_WORLD" then
    Jumped()
  elseif event == "BAG_UPDATE" then
    live.bags = nil
  elseif event == "MERCHANT_CLOSED" then
    FireAll("vendor")
  elseif event == "TRAINER_CLOSED" then
    FireAll("trainer")
  elseif event == "TAXIMAP_OPENED" then
    if ER.RouteTaxiOpened then ER.RouteTaxiOpened() end
    FireAll("fp")
  elseif event == "SPELLCAST_START" then
    live.hearthing = arg1 == "Hearthstone"
  elseif event == "SPELLCAST_STOP" then
    if live.hearthing then FireAll("hs") Jumped() end
    live.hearthing = false
  elseif event == "SPELLCAST_FAILED" or event == "SPELLCAST_INTERRUPTED" then
    live.hearthing = false
  end
  this.soon = true
end)
watcher:SetScript("OnUpdate", function()
  this.wait = this.wait + arg1
  if this.wait < (this.soon and 0.3 or 1) then return end
  this.wait, this.soon = 0, false
  if guide then
    local bind = GetBindLocation and GetBindLocation()
    if live.bindAt and bind and bind ~= live.bindAt then
      FireAll("bind")
      live.bindAt = bind
    end
    S.Check()
  end
end)


ER.Loaded("Steps.lua")
