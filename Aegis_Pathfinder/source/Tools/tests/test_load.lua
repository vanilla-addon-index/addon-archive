--[[
	The whole addon, loaded as the client loads it: every .lua file in the
	.toc, in order, with the real Ace2 libraries.

	A file that stops part-way while loading takes everything after the line
	that failed with it, and the errors that follow name other files. Core.lua
	built its race table from ClassicAPI at load, and indexed
	GetFactionInfo(i).groupTag -- nil for a race with no faction group, which
	ChrRaces has (creature races). So Core.lua stopped at that line: no
	OnInitialize, so no saved settings ("ItemScore.lua:72: attempt to index
	field 'db'"), no GetObjectiveInfo ("QuestTracker.lua:177: attempt to call
	method 'GetObjectiveInfo'").

	Run:  lua5.1 Tools/tests/test_load.lua
]]

package.path = "Tools/tests/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

-- What the Ace2 libraries and the files reach for as they load.
table.setn = function() end               -- Lua 5.0's; 5.1 only complains
debugstack = function() return "Interface\\AddOns\\Aegis_Pathfinder\\Core.lua:6: in main chunk\n" end
geterrorhandler = function() return function() end end
GetBuildInfo = function() return "1.12.1", "5875", "Sep 19 2006", 11200 end
GetLocale = function() return "enUS" end
UnitName = function() return "Tester" end
GetRealmName = function() return "Realm" end
UnitClass = function() return "Paladin", "PALADIN" end
UnitRace = function() return "Human", "Human" end
UnitFactionGroup = function() return "Alliance" end
FACTION_HORDE, FACTION_ALLIANCE, PLAYER_OF_REALM = "Horde", "Alliance", "%s of %s"
CHARACTER, REALM, CLASS = "Character: ", "Realm: ", "Class: "
IsAddOnLoaded = function() return false end
LoadAddOn = function() return false end
GetNumAddOns = function() return 1 end
GetAddOnInfo = function() return "Aegis_Pathfinder", "Aegis: Pathfinder", "", true, true end
GetAddOnMetadata = function() return nil end
IsLoggedIn = function() return false end
GetMapContinents = function() return "Kalimdor", "Eastern Kingdoms" end
GetMapZones = function(c) if c == 1 then return "Durotar" end return "Elwynn Forest" end
GetNumQuestLogEntries = function() return 0 end
SlashCmdList, hash_SlashCmdList, UISpecialFrames = {}, {}, {}
DEFAULT_CHAT_FRAME = CreateFrame("Frame")
DEFAULT_CHAT_FRAME.AddMessage = function() end

-- ClassicAPI, with a race that has no faction group, as ChrRaces' creature
-- races do: GetFactionInfo is nil for it.
local RACES = { { "Human", "Human", "Alliance" }, { "Orc", "Orc", "Horde" }, { "Fel Orc", "FelOrc", nil } }
C_CreatureInfo = {
	GetRaceInfo = function(i)
		local r = RACES[i]
		return r and { raceName = r[1], clientFileString = r[2], raceID = i }
	end,
	GetFactionInfo = function(i)
		local r = RACES[i]
		return r and r[3] and { name = r[3], groupTag = r[3] }
	end,
}
local function anything() return setmetatable({}, { __index = function() return function() end end }) end
C_QuestLog, C_Item = anything(), anything()
local tickers = {}
C_Timer = { After = function() end, NewTicker = function(_, f) table.insert(tickers, f) end }
UnitRaceBase = function() return "Human", "Human" end
CLASSIC_API_VERSION = 10509

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end

local files = {}
for line in io.lines("Aegis_Pathfinder.toc") do
	line = string.gsub(line, "\r", "")
	if not string.find(line, "^#") and string.find(line, "%.lua$") then
		table.insert(files, (string.gsub(line, "\\", "/")))
	end
end
check(table.getn(files) > 30, "the .toc lists the addon's files, got %d", table.getn(files))

for _, f in ipairs(files) do
	local chunk, err = loadfile(f)
	check(chunk ~= nil, "%s parses: %s", f, tostring(err))
	if chunk then
		local ok, e = pcall(chunk)
		check(ok, "%s loads to its end: %s", f, tostring(e))
		if not ok then break end
	end
end

local A = AegisPathfinder
check(A and type(A.OnInitialize) == "function", "Core.lua defines OnInitialize, so the settings are made")
check(A and type(A.GetObjectiveInfo) == "function", "and GetObjectiveInfo, the flight-point watcher's")
check(A and A.turtleRaces.Human and A.turtleRaces.Human.faction == "Alliance"
	and A.turtleRaces.Orc and A.turtleRaces.Orc.faction == "Horde", "the playable races are read, with their side")
check(A and A.turtleRaces.FelOrc == nil, "and a race with no side is left out, not an error")

--[[ A level up, with every file loaded in the .toc's order.

	Core.lua and QuestTracker.lua each defined PLAYER_LEVEL_UP, one for the
	starting zone and one for |LV| steps; QuestTracker.lua's, loaded after,
	replaced Core.lua's, so the starting zone only handed over to the shared
	route at the next login. And the starting zone judged by UnitLevel, which
	can still say the old level while the event fires. ]]
if A and A.PLAYER_LEVEL_UP then
	local ticked, moved = 0, 0
	local saved = {}
	for _, k in ipairs({ "db", "GetObjectiveTag", "GetObjectiveInfo", "SetTurnedIn", "IsInStartingZone",
		"TransitionFromStartingZone", "actions", "quests", "turnedin", "Debug" }) do saved[k] = A[k] end
	A.db = { char = { startingzoneselected = true, startingzonecomplete = false } }
	A.Debug = function() end
	A.GetObjectiveTag = function(_, tag) if tag == "LV" then return "12" end end
	local stepAction = "GRIND"
	A.GetObjectiveInfo = function() return stepAction end
	A.SetTurnedIn = function(self) ticked = ticked + 1; self.turnedin[self.quests[1]] = true end
	A.IsInStartingZone = function() return true, { rejoinLevel = 12 } end
	A.TransitionFromStartingZone = function() moved = moved + 1 end
	-- Four of five steps done: the fifth is the level step.
	A.actions = { "ACCEPT", "TURNIN", "ACCEPT", "TURNIN", "GRIND" }
	A.quests = { "Level@5@", "a@1@", "b@2@", "c@3@", "d@4@" }
	A.turnedin = { ["a@1@"] = true, ["b@2@"] = true, ["c@3@"] = true, ["d@4@"] = true }
	local keepLevel = UnitLevel
	UnitLevel = function() return 11 end        -- not caught up with the event yet

	A:PLAYER_LEVEL_UP(12)
	check(ticked == 1, "a level up ticks the step waiting on level 12")
	check(moved == 1, "and hands the outlevelled starting zone over to the shared route, at the event's level 12")

	ticked, moved = 0, 0
	A.db.char.startingzonecomplete = true
	A:PLAYER_LEVEL_UP(12)
	check(moved == 0, "not once the starting zone is done")

	-- A level note ("Level 10 Required") is a level gate too; a quest's own
	-- step with |LV| only says the level it needs, and stays until done.
	ticked = 0
	stepAction = "NOTE"
	A:PLAYER_LEVEL_UP(12)
	check(ticked == 1, "a level note ticks at its level")
	ticked = 0
	stepAction = "TURNIN"
	A:PLAYER_LEVEL_UP(12)
	check(ticked == 0, "a turn-in needing level 12 isn't ticked by reaching it")

	UnitLevel = keepLevel
	for k in pairs(saved) do A[k] = saved[k] end
end

--[[ Arriving at a point on a continent's map: RestedXP's "Travel to
	Kalimdor (51.9, 55.5)", the Wailing Caverns' meeting stone. The arrival
	check didn't know the continents' names, so it read the numbers on the
	map of the zone you were in -- and ticked the step standing on 51.9, 55.5
	of the Barrens, nowhere near the cave. ]]
if A and table.getn(tickers) == 1 then
	local ticked, yards, asked = 0, 400, nil
	local saved = {}
	for _, k in ipairs({ "current", "actions", "GetObjectiveInfo", "GetObjectiveTag", "SetTurnedIn", "Debug",
		"updatedelay", "recheckCompletion" }) do saved[k] = A[k] end
	local keep = { WorldMapFrame, SetMapToCurrentZone, GetCurrentMapContinent, GetCurrentMapZone, GetPlayerMapPosition }
	A.current, A.actions, A.updatedelay, A.recheckCompletion = 1, { "RUN" }, nil, nil
	A.Debug = function() end
	A.GetObjectiveInfo = function() return "RUN", "Travel to Kalimdor" end
	A.GetObjectiveTag = function(_, tag)
		if tag == "N" then return "(51.9, 55.5) (WC Dungeon Quest)" end
		if tag == "Z" then return "Kalimdor" end
	end
	A.SetTurnedIn = function() ticked = ticked + 1 end
	-- In the Barrens, on 51.9, 55.5 of the Barrens' own map.
	WorldMapFrame = CreateFrame("Frame")
	WorldMapFrame:Hide()
	SetMapToCurrentZone = function() end
	GetCurrentMapContinent, GetCurrentMapZone = function() return 1 end, function() return 1 end
	GetPlayerMapPosition = function() return 0.519, 0.555 end

	tickers[1]()
	check(ticked == 0, "a continent's point is not read on the map of the zone you are in")

	Astrolabe = {
		GetCurrentPlayerPosition = function() return 1, 1, 0.519, 0.555 end,
		ComputeDistance = function(_, c1, z1, x1, y1, c2, z2, x2, y2)
			asked = { c2, z2, x2, y2 }
			return yards, 1, 1
		end,
	}
	tickers[1]()
	check(ticked == 0 and asked and asked[1] == 1 and asked[2] == 0 and math.abs(asked[3] - 0.519) < 1e-9,
		"Astrolabe measures it on Kalimdor's own map, and 400 yd off is not there")
	yards = 20
	tickers[1]()
	check(ticked == 1, "20 yd is: the point is only written to a tenth of a percent of the continent")

	Astrolabe = nil
	WorldMapFrame, SetMapToCurrentZone, GetCurrentMapContinent, GetCurrentMapZone, GetPlayerMapPosition =
		keep[1], keep[2], keep[3], keep[4], keep[5]
	for k in pairs(saved) do A[k] = saved[k] end
end
check(table.getn(tickers) == 1, "one ticker, QuestTracker's arrival check, got %d", table.getn(tickers))

--[[ Starting up: the chat commands, and progress carried over from
	TurtleGuide, the addon this one grew from. /vg was TurtleGuide's command
	and is gone; a character's TurtleGuideDB is still adopted, once, when
	there is no Pathfinder save to lose. ]]
if A and A.OnInitialize then
	local said = {}
	local saved, themeSaved = {}, {}
	for _, k in ipairs({ "db", "RegisterDB", "RegisterDefaults", "SetupErrorCapture", "RestoreCraftGuides",
		"PositionActiveFrames", "CreateConfigPanel", "Print" }) do saved[k] = A[k] end
	for _, k in ipairs({ "ApplyTheme", "SetWindowScale", "SetSwitchColours" }) do
		themeSaved[k] = A.Theme[k]
		A.Theme[k] = function() end
	end
	local function none() end
	A.RegisterDB = function(self) self.db = { char = { panelopen = false }, profile = {} } end
	A.RegisterDefaults, A.SetupErrorCapture, A.RestoreCraftGuides = none, none, none
	A.PositionActiveFrames, A.CreateConfigPanel = none, none
	A.Print = function(_, msg) table.insert(said, msg) end

	local old = { chars = { ["Tester of Realm"] = { currentguide = "Elwynn Forest (1-10)" } } }
	TurtleGuideDB, AegisPathfinderDB = old, nil
	local ok, err = pcall(A.OnInitialize, A)
	check(ok, "OnInitialize runs, got %s", tostring(err))
	check(AegisPathfinderDB == old, "a character's TurtleGuide progress is carried over")
	check(said[1] == "Imported your saved progress from TurtleGuide.", "and chat says so, got %s", tostring(said[1]))

	local slashes = {}
	for k, v in pairs(_G) do
		if type(k) == "string" and string.find(k, "^SLASH_AEGISPATHFINDER%d+$") then slashes[v] = true end
	end
	check(slashes["/apg"] and slashes["/pathfinder"], "/apg and /pathfinder are the addon's commands")
	check(not slashes["/vg"], "/vg, TurtleGuide's command, is not registered")
	check(not slashes["/aegis"], "nor /aegis, which belongs to another Aegis addon")

	local mine = { chars = { ["Tester of Realm"] = { currentguide = "Westfall (10-12)" } } }
	TurtleGuideDB, AegisPathfinderDB, said = old, mine, {}
	A:OnInitialize()
	check(AegisPathfinderDB == mine and table.getn(said) == 0, "a Pathfinder save is never replaced by an old one")

	--[[ A ClassicAPI too old to run on. OnEnable stopped with a message, but
		OnInitialize had already asked for the login, which loaded the guides
		regardless -- and before v1.3.11 ClassicAPI hasn't put back the
		coroutine library the login uses: "Core.lua:799: attempt to index
		global 'coroutine'" on OctoWoW, and no guides. ]]
	local keepVersion, keepFaction = CLASSIC_API_VERSION, A.myfaction
	A.myfaction, TurtleGuideDB, AegisPathfinderDB = nil, nil, nil
	CLASSIC_API_VERSION, said = 10310, {}
	A:OnInitialize()
	check(not A:IsEventRegistered("PLAYER_ENTERING_WORLD"), "a ClassicAPI before v1.5.9 doesn't get the login")
	A:OnEnable()
	check(said[1] and string.find(said[1], "this client has v1.3.10.", 1, true)
		and not A:IsEventRegistered("PLAYER_ENTERING_WORLD"), "OnEnable stops, saying which ClassicAPI it found, got %s",
		tostring(said[1]))
	CLASSIC_API_VERSION, said = nil, {}
	A:OnEnable()
	check(said[1] and string.find(said[1], "this client has none.", 1, true), "or that there's none, got %s",
		tostring(said[1]))
	CLASSIC_API_VERSION, AegisPathfinderDB = 10509, nil
	A:OnInitialize()
	check(A:IsEventRegistered("PLAYER_ENTERING_WORLD"), "v1.5.9 gets the login")
	A:UnregisterEvent("PLAYER_ENTERING_WORLD")
	CLASSIC_API_VERSION, A.myfaction = keepVersion, keepFaction

	TurtleGuideDB, AegisPathfinderDB = nil, nil
	for k in pairs(saved) do A[k] = saved[k] end
	for k, f in pairs(themeSaved) do A.Theme[k] = f end
end

--[[ The guide browser over every guide the addon has: the guides the .toc's
	Guides.xml files load, every category opened, every folder walked, and
	every guide pointed at, so its picture is drawn. ]]
if A and A.ShowGuideList then
	for line in io.lines("Aegis_Pathfinder.toc") do
		line = string.gsub(string.gsub(line, "\r", ""), "\\", "/")
		if not string.find(line, "^#") and string.find(line, "%.xml$") then
			local dir = string.gsub(line, "[^/]+$", "")
			for f in string.gfind(io.open(line):read("*a"), '<Script%s+file="([^"]+)"') do
				local chunk, err = loadfile(dir .. string.gsub(f, "\\", "/"))
				local ok, e = chunk and pcall(chunk)
				check(ok, "%s loads: %s", f, tostring(err or e))
			end
		end
	end
	check(table.getn(A.guidelist) > 300, "the Alliance's guides are registered, got %d", table.getn(A.guidelist))
	local saved = A.db
	A.db = { char = { completion = {}, turnins = {}, favorites = {}, recentguides = {}, leveltime = {}, gold = {},
		completedquestsbyid = {}, completedquests = {}, browsertab = "home", browsercolour = true,
		browserticks = true, browserpanels = {}, Dungeons = { DM = true, WC = true },
		tabs = { { guide = "Optimized/Ashenvale (24-25)", step = 1 } }, currentguide = "Optimized/Ashenvale (24-25)" },
		profile = {} }
	IsShiftKeyDown = function() return false end
	local keepLevel = UnitLevel
	UnitLevel = function() return 24 end
	local ok, err = pcall(function()
		local list, ui = A.guidelistframe, A.browserui
		list:Show()
		this = list
		list:GetScript("OnShow")()
		check(ui.cards.suggested.rows[1].guide == "Optimized/Wetlands (25-27)", "Home suggests the route's next leg, got %s",
			tostring(ui.cards.suggested.rows[1].guide))
		local pointed, pictures = 0, {}
		local function walk(depth)
			for _, r in ipairs(ui.rows) do
				if r:IsShown() and r.guide then
					this = r
					r:GetScript("OnEnter")()
					r:GetScript("OnLeave")()
					pointed = pointed + 1
					pictures[ui.picture.kind] = true
				end
			end
			local folders = {}
			for i, r in ipairs(ui.rows) do if r:IsShown() and r.folder then table.insert(folders, i) end end
			for _, i in ipairs(folders) do
				this, arg1 = ui.rows[i], "LeftButton"
				ui.rows[i]:GetScript("OnClick")()
				if depth < 3 then walk(depth + 1) end
				this = ui.back
				ui.back:GetScript("OnClick")()
			end
		end
		for _, c in ipairs(ui.categories) do
			this, arg1 = c, "LeftButton"
			c:GetScript("OnClick")()
			walk(1)
		end
		check(pointed > 100, "guides pointed at across the categories, got %d", pointed)
		check(pictures.map and pictures.screen and pictures.class and pictures.icon,
			"and every kind of picture drawn: maps, loading screens, class crests, profession icons")
		list:Hide()
	end)
	check(ok, "the browser runs over every guide: %s", tostring(err))
	UnitLevel = keepLevel
	A.db = saved
end

-- A line with a "%" in it, through the real AceConsole: it once went to
-- string.format and stopped ("invalid option in `format'").
do
	local said
	local add = DEFAULT_CHAT_FRAME.AddMessage
	DEFAULT_CHAT_FRAME.AddMessage = function(_, text) said = text end
	local ok, err = pcall(function() AegisPathfinder:Print("Gloves: a +12% upgrade (50% done)") end)
	DEFAULT_CHAT_FRAME.AddMessage = add
	check(ok, "a line with %% in it prints, got %s", tostring(err))
	check(said and string.find(said, "Gloves: a +12% upgrade (50% done)", 1, true), "and reads as written, got %s",
		tostring(said))
end

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end
print(string.format("Load: %d checks", checks))
if table.getn(failures) == 0 then
	print("All load checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
