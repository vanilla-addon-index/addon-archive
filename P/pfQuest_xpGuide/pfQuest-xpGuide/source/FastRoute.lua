-- pfQuest xpGuide: the xpGuide Fast route, the addon's guide, and RestedXP's original Fast route as its fallback.
--
-- The xpGuide Fast route is RestedXP's Fast route with the xpGuide Fast options, made whole offline by tools/build_fastroute.py
-- into Data\FastRoute.lua: picking a guide asks for the experience rate and the professions (FastSetup.lua), the heading shows the
-- rate, Medium leaves out the elite quests, lines marked XP1 only show on 1x servers, and the profession checkpoints show for the
-- professions you have. It also has starting guides for the races RestedXP has none for (Turtle WoW's High Elves and Goblins).
--
-- RestedXP's own guides (Data\Guides.lua) stay as the fallback: each xpGuide Fast route guide knows its RestedXP guide (same name).
-- When the xpGuide Fast route goes wrong (a guide cannot be loaded, or errors keep coming while you follow it) the addon offers
-- RestedXP's guide, or starts it by itself when a guide cannot be loaded at all; /xpg fallback switches by hand, both ways.
--
-- Also here: what a new character starts at login, and what a character saved on a retired guide (2.0.0 took out the casual route,
-- xpGuide Fast, Bethink's Guide and VanillaGuide) goes on with.

local ER = pfQuest_xpGuide
local FR = {}
ER.FastRoute = FR
local GOLD, END = ER.GOLD, ER.END

-- The guides of Data\FastRoute.lua join RestedXP's in the one list, as kind "xproute" (Steps.Kind).
function FR.Make()
  local data = pfQuest_xpGuide_FastRoute
  if type(data) ~= "table" or type(data.guides) ~= "table" or type(pfQuest_xpGuide_Guides) ~= "table" then return 0 end
  local n = 0
  for _, g in ipairs(data.guides) do
    g.fast, g.xproute = true, true
    if g.zones then g.startZones = g.zones end
    table.insert(pfQuest_xpGuide_Guides, g)
    n = n + 1
  end
  -- the starting guides' quests (pfQuest-turtle's titles and prerequisites): known whichever pfQuest database is installed
  if type(data.quests) == "table" then
    if type(pfQuest_xpGuide_GuideQuests) ~= "table" then pfQuest_xpGuide_GuideQuests = {} end
    pfQuest_xpGuide_QuestPre = pfQuest_xpGuide_QuestPre or {}
    for id, q in pairs(data.quests) do
      if not pfQuest_xpGuide_GuideQuests[id] then pfQuest_xpGuide_GuideQuests[id] = q.n end
      if q.p and q.p ~= 0 then pfQuest_xpGuide_QuestPre[id] = q.p end
    end
  end
  return n
end

FR.count = FR.Make()

------------------------------------------------------------------------------------------------------
-- The fallback: RestedXP's original guide for an xpGuide Fast route guide, and the way back
------------------------------------------------------------------------------------------------------

-- The other side of a guide: RestedXP's guide for an xpGuide Fast route guide (same name, its "base" group), and the xpGuide Fast route
-- guide for a RestedXP guide. nil for a starting guide RestedXP has no guide for (High Elf, Goblin).
function FR.Twin(info)
  if not info then return nil end
  local S = ER.Steps
  for _, g in ipairs(S.Guides()) do
    if g.name == info.name and g.faction == info.faction and g ~= info then
      if info.xproute and S.Kind(g) == "fast" and (not info.base or g.group == info.base) then return g end
      if S.Kind(info) == "fast" and g.xproute then return g end
    end
  end
  return nil
end

-- Switches the running guide to its other side: to RestedXP's original from the xpGuide Fast route, and back. Starts part-way (the
-- steps already done in the quest log are ticked off). true when it switched.
function FR.Switch(why)
  local S = ER.Steps
  local info = S.Info()
  local twin = FR.Twin(info)
  if not twin then
    ER.Print(info and info.raceStart and "RestedXP has no guide for this start area; the fallback starts with its next guide." or
      "no guide to switch to: start a guide first.")
    return false
  end
  if not ER.StartGuide(S.Key(twin), nil, true, true) then return false end
  FR.problems = 0
  if twin.xproute then
    ER.Print("back on the xpGuide Fast route: " .. GOLD .. (twin.title or twin.name) .. END .. ".")
  else
    ER.Print((why and (why .. " ") or "") .. "Now following RestedXP's original guide: " .. GOLD .. (twin.title or twin.name) .. END ..
      ". " .. GOLD .. "/xpg fallback" .. END .. " goes back to the xpGuide Fast route.")
  end
  return true
end

-- A guide of the xpGuide Fast route that cannot be loaded: RestedXP's original starts instead, by itself (called by ER.StartGuide).
function FR.LoadFailed(key)
  local g = ER.Steps.Find(key)
  if not (g and g.xproute) then return false end
  local twin = FR.Twin(g)
  if not twin then return false end
  local ok, loaded = pcall(ER.Steps.Load, ER.Steps.Key(twin))
  if not ok or not loaded then return false end
  FR.offered = true   -- RestedXP's original comes first in the suggestions from now on (this session)
  ER.Print("the xpGuide Fast route guide " .. GOLD .. (g.title or g.name) .. END .. " could not be loaded, so RestedXP's original " ..
    GOLD .. (twin.title or twin.name) .. END .. " runs instead. Please report this.")
  return true
end

-- Lua errors of this addon while the xpGuide Fast route runs (Selftest.lua's error handler calls this). After PROBLEMS_MAX of them in
-- one session the fallback is offered once, in chat: the guide may be what goes wrong.
local PROBLEMS_MAX = 3
FR.problems = 0
function FR.OwnError()
  local info = ER.Steps and ER.Steps.Info()
  if not (info and info.xproute) then return end
  FR.problems = FR.problems + 1
  if FR.problems == PROBLEMS_MAX and not FR.offered and FR.Twin(info) then
    FR.offered = true
    ER.Print("the xpGuide Fast route keeps running into errors. " .. GOLD .. "/xpg fallback" .. END ..
      " switches to RestedXP's original guide (and back).")
  end
end

-- True while RestedXP's original is wanted first: after the offer above, or once a guide could not be loaded. Steps.Suggest reads it.
function FR.FallbackWanted()
  return FR.offered or false
end

------------------------------------------------------------------------------------------------------
-- /xpg report: what the addon sees, for a bug report (also kept in pfQuest_xpGuideDB.report)
------------------------------------------------------------------------------------------------------

-- A quest in pfQuest's data (any of its tables: vanilla, turtle and the rest)?
local function KnownToPfQuest(id)
  local q = pfDB and pfDB.quests
  if type(q) ~= "table" then return nil end
  for _, t in pairs(q) do
    if type(t) == "table" and t[id] ~= nil then return true end
  end
  return false
end

function ER.Report()
  local S = ER.Steps
  local lines = {}
  local function Add(text) table.insert(lines, text) end
  local raceName, raceToken = UnitRace("player")
  local _, class = UnitClass("player")
  Add("pfQuest xpGuide " .. tostring(ER.VERSION) .. ", client " .. tostring(GetBuildInfo and (GetBuildInfo()) or "?"))
  Add("race " .. tostring(raceName) .. " (token " .. tostring(raceToken) .. ", guides read " .. tostring(S.RaceToken(raceToken)) .. "), " ..
    tostring(class) .. ", " .. tostring(UnitFactionGroup("player")) .. ", level " .. tostring(UnitLevel("player")))
  local mapId = (GetCurrentMapContinent and GetCurrentMapZone) and (GetCurrentMapContinent() .. "/" .. GetCurrentMapZone()) or "?"
  local pfId = pfMap and pfMap.GetMapIDByName and pfMap:GetMapIDByName(GetZoneText() or "") or nil
  Add("zone " .. tostring(GetZoneText()) .. " / " .. tostring(GetSubZoneText and GetSubZoneText() or "") .. ", map " .. mapId ..
    ", pfQuest map id " .. tostring(pfId))
  local info = S.Info()
  if info then
    Add("guide " .. S.Key(info) .. " (" .. S.Kind(info) .. "), step " .. tostring(S.Position and S.Position()) .. " of " ..
      tostring(S.Count and S.Count()) .. ", " .. tostring(ER.XPRate and ER.XPRate()) .. "x, " .. tostring(ER.Mode and ER.Mode()))
  else
    Add("no guide running")
  end
  Add("pfQuest " .. (pfQuest and "yes" or "no") .. ", pfQuest-turtle " .. (IsAddOnLoaded and IsAddOnLoaded("pfQuest-turtle") and "yes" or "no") ..
    ", pfUI " .. (pfUI and "yes" or "no") .. ", pfQuest-turtle nameplate icons " .. ((ER.OtherPlateIcons and ER.OtherPlateIcons()) and "on" or "off") .. ", errors this session while following the xpGuide Fast route: " .. FR.problems)
  -- the starting guides for this race: are their first quests known, and where does the guide send you
  for _, g in ipairs(S.Guides()) do
    if g.raceStart and S.Applies(g.defaultFor) then
      local first, at
      for line in string.gfind(g.steps or "", "[^\n]+") do
        if not first then
          local _, _, id = string.find(line, "^A\t[^\t]*\t(%d+)")
          if id then first = tonumber(id) end
        end
        if not at then
          local _, _, zone = string.find(line, "^G\t[^\t]*\t([^\t]+)")
          if zone then at = zone end
        end
      end
      Add("start guide " .. g.name .. ": in " .. tostring(at) .. ", first quest " .. tostring(first) .. " known to pfQuest: " ..
        tostring(first and KnownToPfQuest(first)))
    end
  end
  if ER.db then ER.db.report = lines end
  for _, text in ipairs(lines) do ER.Print(text) end
  ER.Print("(saved in pfQuest_xpGuideDB.report in WTF\\Account\\<name>\\SavedVariables\\pfQuest_xpGuide.lua)")
end

------------------------------------------------------------------------------------------------------
-- What a character starts at login
------------------------------------------------------------------------------------------------------

-- The guide for a new character: a starting guide made for its race (High Elf, Goblin) when one fits its level, the one whose start
-- area it stands in first (a server may name the area differently: then the first that fits; /xpg report shows the zone); else the
-- best xpGuide Fast route guide for it. A race with starting guides of its own is never sent to another race's start.
function FR.BestStart()
  local S = ER.Steps
  local here = string.lower(GetZoneText() or "")
  local level = UnitLevel("player") or 1
  local list = S.Suggest()
  local own, inZone
  for _, g in ipairs(list) do
    if g.raceStart and g.lo <= level and level <= g.hi then
      own = own or g
      for z in string.gfind(g.startZones or "", "[^;]+") do
        if string.lower(z) == here and not inZone then inZone = g end
      end
    end
  end
  if inZone or own then return inZone or own end
  for _, g in ipairs(list) do
    if g.xproute and not g.raceStart then return g end
  end
  return list[1]
end

-- Run once per login, after the saved guide had its chance. Never takes a guide away: a running guide and one stopped on purpose are
-- left alone. A character saved on a guide that is no longer in the addon gets the best guide for its level, with one line that says so.
function FR.AutoStart()
  local S = ER.Steps
  if not ER.db or not S then return end
  local F = ER.FastSetupInfo
  if not S.Info() and S.Resume() and ER.ShowTracker then ER.ShowTracker() end
  if S.Info() then
    -- a character already on a guide that has never been asked its server's experience rate and its professions: asked once
    if F and not F.Asked() and ER.db.xpRate == nil and S.Info().xproute then ER.OpenFastSetup(S.Info(), true) end
    return
  end
  local saved = type(ER.db.guides) == "table" and ER.db.guides[ER.Char()] or nil
  local retired
  if type(saved) == "table" and type(saved.key) == "string" and saved.key ~= "" then
    if saved.stopped then return end
    if not S.Find(saved.key) then retired = saved.key end
  end
  if ER.db.mode == nil then ER.db.mode = "casual" end
  local best = FR.BestStart()
  if not best then return end
  -- the character's first start: the experience rate and the professions first, then the guide starts with them (Skip starts
  -- it with the settings as they are)
  if F and not F.Asked() and ER.OpenFastSetup then
    ER.OpenFastSetup(best, true)
    ER.Print("welcome! Pick your server's experience rate and your professions; the guide (" .. GOLD .. (best.title or best.name) ..
      END .. ") starts with them.")
    return
  end
  if not ER.StartGuide(S.Key(best), nil, true) then return end
  local name = GOLD .. (best.title or best.name) .. END
  if retired then
    local _, _, old = string.find(retired, "\\(.+)$")
    ER.Print("the guide you followed (" .. (old or retired) .. ") is no longer in the addon; now following " .. name ..
      " on the xpGuide Fast route. The cog under the guide window picks another.")
  else
    ER.Print("following the xpGuide Fast route: " .. name .. ", on " .. ER.MODES[ER.Mode()].label ..
      ". The cog under the guide window changes the guide or difficulty.")
  end
end

-- At login: wait at least 4 seconds, then until the quest log has been read (a part-way start looks at the log, and an unread log looks
-- empty), then start once. Gives up after 20 seconds without a log.
local starter = CreateFrame("Frame", "pfQuest_xpGuideAutoStarter")
starter:RegisterEvent("PLAYER_ENTERING_WORLD")
starter:SetScript("OnEvent", function()
  this:UnregisterEvent("PLAYER_ENTERING_WORLD")
  this.wait, this.gap = 0, 0.5
  this:SetScript("OnUpdate", function()
    this.wait = this.wait + arg1
    if this.wait < 4 then return end
    this.gap = this.gap + arg1
    if this.gap < 0.5 then return end
    this.gap = 0
    if ER.Recorder and ER.Recorder.Ready and ER.Recorder.Ready() then
      this:SetScript("OnUpdate", nil)
      FR.AutoStart()
    elseif this.wait > 20 then
      this:SetScript("OnUpdate", nil)
    end
  end)
end)

ER.Loaded("FastRoute.lua")
