-- pfQuest xpGuide: what the guide needs to know about you besides your race and class: the experience rate of your server
-- (2x or 1x) and your professions. Steps.lua asks it through the words in a step's condition: XP1 and XP2 for the rate,
-- and Mining, Herbalism, Skinning, Alchemy, Blacksmithing, Engineering, Enchanting, Leatherworking, Tailoring,
-- FirstAid, Cooking, Fishing and Survival for a profession. A step written "S\tXP1" is only for 1x, "S\tMining" only for
-- a miner. The Character page of Settings.lua sets both.
--
-- A profession counts when your skill list has it (it is read from the game), or when you ticked it for a profession you
-- mean to learn. First Aid and Cooking are on until you untick them: they are cheap and worth having on the way.

local ER = pfQuest_xpGuide

ER.PRIMARY = { "Mining", "Herbalism", "Skinning", "Alchemy", "Blacksmithing", "Engineering", "Enchanting",
  "Leatherworking", "Tailoring" }
ER.SECONDARY = { "First Aid", "Cooking", "Fishing", "Survival" }

-- The professions worth having on the way to 60, by class: two primary ones, and the secondary ones every class wants.
local RECOMMENDED = {
  WARRIOR = { "Mining", "Blacksmithing" }, PALADIN = { "Mining", "Blacksmithing" },
  HUNTER = { "Skinning", "Leatherworking" }, ROGUE = { "Mining", "Engineering" },
  PRIEST = { "Tailoring", "Enchanting" }, SHAMAN = { "Skinning", "Leatherworking" },
  MAGE = { "Tailoring", "Enchanting" }, WARLOCK = { "Tailoring", "Enchanting" },
  DRUID = { "Herbalism", "Alchemy" },
}
local RECOMMENDED_SECONDARY = { ["First Aid"] = true, ["Cooking"] = true }

-- the word used in a condition, and the profession it stands for
local WORD = {}
for _, n in ipairs(ER.PRIMARY) do WORD[string.upper(n)] = n end
for _, n in ipairs(ER.SECONDARY) do WORD[string.upper((string.gsub(n, " ", "")))] = n end

local known, ranks, maxranks, sig = nil, {}, {}, nil

local function Db() return ER.db or {} end

local function IsPrimary(name)
  for _, n in ipairs(ER.PRIMARY) do if n == name then return true end end
  return false
end

------------------------------------------------------------------------------------------------------
-- The rate
------------------------------------------------------------------------------------------------------

-- 1 or 2. Normal experience is the default.
function ER.XPRate()
  local r = Db().xpRate
  if r == 2 then return 2 end
  return 1
end

local function Changed()
  sig = nil
  if ER.Steps and ER.Steps.Running and ER.Steps.Running() then
    -- A Fast guide marks single lines with XP1 and the professions; those are read when the guide is opened, so it is read
    -- again (the place in it stays).
    local info = ER.Steps.Info and ER.Steps.Info()
    if info and info.fast and ER.Steps.Load and ER.Steps.Key then ER.Steps.Load(ER.Steps.Key(info)) end
    if ER.Steps.Check then ER.Steps.Check() end
    if ER.StepsChanged then ER.StepsChanged() end
  end
end

function ER.SetXPRate(rate, quiet)
  rate = tonumber(rate)
  if rate ~= 1 and rate ~= 2 then return false end
  if not ER.db then return false end
  ER.db.xpRate = rate
  if not quiet and ER.Print then
    ER.Print("experience rate is now " .. ER.GOLD .. rate .. "x" .. ER.END .. ". "
      .. (rate == 2 and "Quests give double, so the Fast guides leave out the quests a 1x server needs for the same levels."
        or "The Fast guides keep the extra quests that a 1x server needs for the same levels."))
  end
  Changed()
  return true
end

------------------------------------------------------------------------------------------------------
-- Professions
------------------------------------------------------------------------------------------------------

-- The professions in your skill list, with their skill. Headers that are folded in the skill window are opened for the
-- look and folded again.
local function Scan()
  local out, rk, mx = {}, {}, {}
  if GetNumSkillLines and GetSkillLineInfo then
    local opened = {}
    local ok = pcall(function()
      local n = GetNumSkillLines() or 0
      for i = n, 1, -1 do
        local name, header, expanded = GetSkillLineInfo(i)
        if header and not expanded and ExpandSkillHeader then
          ExpandSkillHeader(i)
          table.insert(opened, i)
        end
      end
      n = GetNumSkillLines() or 0
      for i = 1, n do
        local name, header, _, rank, _, _, maxRank = GetSkillLineInfo(i)
        if name and not header then
          out[name] = true
          rk[name] = tonumber(rank) or 0
          mx[name] = tonumber(maxRank) or 0
        end
      end
      for _, i in ipairs(opened) do
        if CollapseSkillHeader then CollapseSkillHeader(i) end
      end
    end)
    if not ok then out, rk, mx = {}, {}, {} end
  end
  return out, rk, mx
end

local function Known()
  if not known then known, ranks, maxranks = Scan() end
  return known
end

-- Do you have it, or mean to? (Not asked about yet: the class's suggestion.)
function ER.HasProf(name)
  if Known()[name] then return true end
  local chosen = Db().profs
  local v
  if type(chosen) == "table" then v = chosen[name] end
  if v == nil then return ER.Recommended(name) end
  return v and true or false
end

-- Is it one the guide suggests for your class? The two primary professions of the class, unless you already have some: the free
-- places are filled in the class's order. First Aid and Cooking for everybody.
function ER.Recommended(name)
  if RECOMMENDED_SECONDARY[name] then return true end
  if not IsPrimary(name) then return false end
  local _, class = UnitClass("player")
  local list = RECOMMENDED[class or ""] or {}
  local have = 0
  for _, n in ipairs(ER.PRIMARY) do if Known()[n] then have = have + 1 end end
  local free = 2 - have
  for _, n in ipairs(list) do
    if free <= 0 then break end
    if not Known()[n] then
      if n == name then return true end
      free = free - 1
    end
  end
  return false
end

-- Your skill and its top, for the lists: "Mining 150/300", or "not learned".
function ER.ProfDetail(name)
  Known()
  if ranks[name] and Known()[name] then return ranks[name] .. "/" .. (maxranks[name] or 0) end
  return "not learned"
end

-- Is it in your skill list (not only ticked)?
function ER.KnowsProf(name) return Known()[name] and true or false end

-- Your skill in it (0 when you do not have it).
function ER.ProfRank(name)
  Known()
  return ranks[name] or 0
end

function ER.SetProf(name, on)
  if not ER.db or not WORD[string.upper((string.gsub(name, " ", "")))] then return false end
  if type(ER.db.profs) ~= "table" then ER.db.profs = {} end
  ER.db.profs[name] = on and true or false
  Changed()
  return true
end

-- Your professions, for the chat line and the tests: "Mining, Cooking".
function ER.ProfList()
  local out = {}
  for _, n in ipairs(ER.PRIMARY) do if ER.HasProf(n) then table.insert(out, n) end end
  for _, n in ipairs(ER.SECONDARY) do if ER.HasProf(n) then table.insert(out, n) end end
  return out
end

------------------------------------------------------------------------------------------------------
-- The words in a condition (Steps.lua)
------------------------------------------------------------------------------------------------------

-- true or false for XP1, XP2 and a profession word; nil for any other word (a race, a class, a level...).
function ER.CondWord(entry)
  local up = string.upper(entry)
  if up == "XP1" then return ER.XPRate() == 1 end
  if up == "XP2" then return ER.XPRate() == 2 end
  local prof = WORD[up]
  if prof then return ER.HasProf(prof) end
  return nil
end

-- A short text that changes when the rate or a profession does, so answers kept for a condition are not reused.
function ER.CondSig()
  if not sig then
    local t = { ER.XPRate() }
    for _, n in ipairs(ER.PRIMARY) do table.insert(t, ER.HasProf(n) and 1 or 0) end
    for _, n in ipairs(ER.SECONDARY) do table.insert(t, ER.HasProf(n) and 1 or 0) end
    sig = table.concat(t, "")
  end
  return sig
end

-- Learning or dropping a profession changes the skill list.
local f = CreateFrame("Frame")
f:RegisterEvent("SKILL_LINES_CHANGED")
f:SetScript("OnEvent", function()
  known = nil
  Changed()
end)

ER.Loaded("Character.lua")
