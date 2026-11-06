--[[
	Tests for GuideEngine.lua -- what survived the status card's deletion.

	The card is gone, but almost nothing that lived in that file was the card:
	the auto-detection table, the step metadata the objectives panel renders,
	and the use-item button are all still here. This checks that the surface
	really did go and that none of the engine went with it.

	Run:  lua5.1 Tools/tests/test_guideengine.lua
]]

package.path = "Tools/tests/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

GameTooltip_Hide = function() end
HideUIPanel = function(f) if f and f.Hide then f:Hide() end end
ShowUIPanel = function(f) if f and f.Show then f:Show() end end
SetItemButtonTexture = function() end
C_Timer = { After = function() end, NewTicker = function() end }
C_Item = { GetItemCount = function() return 0 end }

AegisPathfinder = {
	qsplusguides = {},
	guides = {}, guidelist = {}, nextzones = {},
	actions = {}, quests = {}, tags = {}, turnedin = {},
	current = 1, myfaction = "Alliance",
	icons = {},
	db = { char = {}, profile = {} },
}
function AegisPathfinder:Debug() end
function AegisPathfinder:Print() end
function AegisPathfinder:Say(msg) self:Print(msg) end   -- Extras.lua's, always on here
function AegisPathfinder.trim(s) return (string.gsub(s or "", "^%s*(.-)%s*$", "%1")) end
function AegisPathfinder.select(index, ...)
	if index == "#" then return table.getn(arg) end
	return arg[index]
end
function AegisPathfinder.GetQuadrant() return nil, nil, "RIGHT" end
function AegisPathfinder:GetWaypointProvider() return self.__provider end
function AegisPathfinder:IsSkillObjective(i)
	return self:GetObjectiveTag("SKILL", i) ~= nil
end
function AegisPathfinder:GetSkillProgress() return nil, self.__rank end
function AegisPathfinder:FindBagSlot() return nil end
function AegisPathfinder:GetObjectiveInfo(i)
	return self.actions[i], self.quests[i], self.quests[i]
end

dofile("Theme.lua")
dofile("Parser.lua")      -- provides GetObjectiveTag
dofile("GuideEngine.lua")

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end

-- The card is gone -----------------------------------------------------------

check(AegisPathfinder.statusframe == nil,
	"the status card was deleted; nothing should rebuild it")
check(AegisPathfinder.statuscard == nil, "the status card rows should be gone")
check(AegisPathfinder.statusskin == nil, "the status card skin should be gone")
check(AegisPathfinder.UpdateStatusCard == nil,
	"UpdateStatusCard painted the card and should not have survived it")
check(AegisPathfinder.LayoutStatusCard == nil, "LayoutStatusCard should be gone")
check(AegisPathfinder.ToggleStatusFrame == nil,
	"there is no card left to toggle")

-- The engine is not ----------------------------------------------------------

for _, fn in ipairs({ "UpdateStatusFrame", "ScheduleStatusUpdate", "SetStatusText",
		"IsAutoDetectable", "GetStepMeta", "GetStepProse", "ToggleObjectivePanel" }) do
	check(type(AegisPathfinder[fn]) == "function",
		"%s is engine, not card, and must survive", fn)
end

-- The single use-item button became the Active Items window (ActiveFrames.lua,
-- Tools/tests/test_activeframes.lua); nothing here builds it any more.
check(getglobal("AegisPathfinderItemButton") == nil,
	"the old use-item button is the Active Items window now")
check(AegisPathfinder.PLAYER_REGEN_ENABLED == nil,
	"and the combat wait that only it needed went with it")

-- Auto-detection -------------------------------------------------------------

check(AegisPathfinder:IsAutoDetectable("ACCEPT"), "ACCEPT is auto-detectable via ClassicAPI")
check(AegisPathfinder:IsAutoDetectable("TURNIN"), "TURNIN is auto-detectable")
check(AegisPathfinder:IsAutoDetectable("COMPLETE"), "COMPLETE is auto-detectable")
check(AegisPathfinder:IsAutoDetectable("SETHEARTH"), "SETHEARTH is auto-detectable")
check(not AegisPathfinder:IsAutoDetectable("NOTE"), "a NOTE can only be read by the player")
check(not AegisPathfinder:IsAutoDetectable("BUY"), "a BUY step cannot be detected")
check(not AegisPathfinder:IsAutoDetectable("GRIND"), "a GRIND step cannot be detected")
check(not AegisPathfinder:IsAutoDetectable(nil), "a nil action is not auto-detectable")

AegisPathfinder.__provider = nil
check(not AegisPathfinder:IsAutoDetectable("RUN"),
	"travel cannot self-complete with no waypoint provider")
AegisPathfinder.__provider = "TomTom"
check(AegisPathfinder:IsAutoDetectable("RUN"),
	"travel completes on arrival once a provider is active")

AegisPathfinder.tags = { [1] = "|SKILL|Alchemy 1 63| |CRAFT|40 Minor Healing Potion|" }
check(AegisPathfinder:IsAutoDetectable("USE", 1),
	"a craft step with a SKILL target is auto-detectable")
AegisPathfinder.tags = { [1] = "|N|Read this|" }
check(not AegisPathfinder:IsAutoDetectable("USE", 1),
	"a USE step with no skill target is not auto-detectable")

-- Step metadata --------------------------------------------------------------

-- What the card's meta row used to paint is now data the panel renders.
AegisPathfinder.tags = { [1] = "|QID|41187| |N|Aerthand Skyshield in Brinthilien (48.3, 84.3)|" }

local qid, meta, warn = AegisPathfinder:GetStepMeta(1)
check(qid == "41187", "the quest id should come back on its own, got '%s'", tostring(qid))
check(not warn, "a step's metadata is never a warning")
check(string.find(meta, "QID 41187", 1, true) ~= nil,
	"the meta string should carry the quest id, got '%s'", tostring(meta))
check(string.find(meta, "48.3, 84.3", 1, true) ~= nil,
	"coordinates buried in the note should be pulled out, got '%s'", tostring(meta))

-- Prose is the note without the coordinates, which are reported separately.
local prose = AegisPathfinder:GetStepProse("Aerthand Skyshield in Brinthilien (48.3, 84.3)")
check(prose == "Aerthand Skyshield in Brinthilien",
	"coordinates belong on the meta row, not in the prose -- got '%s'", tostring(prose))
check(AegisPathfinder:GetStepProse(nil) == nil, "no note means no prose")
check(AegisPathfinder:GetStepProse("  (12.3, 45.6)  ") == nil,
	"a note that is only coordinates leaves no prose behind")

-- A profession step reports its live skill range.
AegisPathfinder.tags = { [1] = "|SKILL|Alchemy 1 63| |CRAFT|40 Minor Healing Potion|" }
AegisPathfinder.__rank = 27
local _, skillMeta = AegisPathfinder:GetStepMeta(1)
check(string.find(skillMeta, "Alchemy 27/63", 1, true) ~= nil,
	"a profession step should show progress against its target, got '%s'",
	tostring(skillMeta))
AegisPathfinder.__rank = nil
local _, bandMeta = AegisPathfinder:GetStepMeta(1)
check(string.find(bandMeta, "Alchemy 1-63", 1, true) ~= nil,
	"with no rank yet it should show the band, got '%s'", tostring(bandMeta))

-- Nothing to say.
AegisPathfinder.tags = { [1] = "" }
local noQid, noMeta = AegisPathfinder:GetStepMeta(1)
check(noQid == nil and noMeta == nil,
	"a step with no id, skill or coordinates reports nothing rather than an empty string")

-- A player once told to expect another server's data is not warned: the
-- servers share these quests and places.
AegisPathfinder.db.profile.server = "ravencraft"
AegisPathfinder.tags = { [1] = "|QID|41187| |N|Aerthand Skyshield (48.3, 84.3)|" }
local wQid, warnMeta, isWarn = AegisPathfinder:GetStepMeta(1)
check(not isWarn and wQid == "41187" and string.find(warnMeta, "QID 41187", 1, true) ~= nil,
	"a server saved by an older version raises no warning, got '%s'", tostring(warnMeta))
AegisPathfinder.db.profile.server = nil

-- Before any guide is loaded ------------------------------------------------

--[[ At login the guide loads only after every guide file has registered, and
	events arrive in between -- SKILL_LINES_CHANGED always does. It reached
	the engine with no step list and failed on ipairs(nil). ]]
do
	local a, q, t, c = AegisPathfinder.actions, AegisPathfinder.quests,
		AegisPathfinder.turnedin, AegisPathfinder.current
	AegisPathfinder.actions, AegisPathfinder.quests = nil, nil
	AegisPathfinder.turnedin, AegisPathfinder.current = nil, nil
	local ok, err = pcall(function() AegisPathfinder:UpdateStatusFrame() end)
	check(ok, "an event before the guide loads must not error: %s", tostring(err))
	AegisPathfinder.actions, AegisPathfinder.quests = a, q
	AegisPathfinder.turnedin, AegisPathfinder.current = t, c
end

-- The shopping list and the active windows follow the step ---------------------

--[[ The shopping list, and Aegis: Exchange once the list has been sent there,
	are brought up to date whenever the current step settles -- which has to
	include running off the end of the guide, or Exchange would keep asking
	for the last craft's reagents after it was done. ]]
do
	local refreshed, active = 0, 0
	function AegisPathfinder:RefreshShoppingList() refreshed = refreshed + 1 end
	function AegisPathfinder:RefreshActiveFrames() active = active + 1 end
	function AegisPathfinder:GetObjectiveStatus(i) return self.turnedin[self.quests[i]] end
	function AegisPathfinder:LoadNextGuide() return false end
	function AegisPathfinder:GetLootRequirement() return nil end
	function AegisPathfinder:TrackCurrentQuest() end
	AegisPathfinder.__provider = nil   -- no waypoint to map
	function AegisPathfinder:UpdateOHPanel() end
	function AegisPathfinder:UpdateNavCallout() end
	function AegisPathfinder:RedriveQuestAutomation() end
	QuestLog_Update = function() end
	QuestWatch_Update = function() end
	GetZoneText = function() return "Elwynn Forest" end
	GetSubZoneText = function() return "" end
	AegisPathfinder.turninskipwarned = {}
	AegisPathfinder.actions = { "NOTE", "NOTE" }
	AegisPathfinder.quests = { "Read one@1@", "Read two@2@" }
	AegisPathfinder.tags = { "|N|one|", "|N|two|" }
	AegisPathfinder.turnedin = { ["Read one@1@"] = true }
	AegisPathfinder.current = 1

	local ok, err = pcall(function() AegisPathfinder:UpdateStatusFrame() end)
	check(ok, "a step update runs: %s", tostring(err))
	check(AegisPathfinder.current == 2 and refreshed == 1,
		"moving to a step refreshes the shopping list once, got step %s and %d refreshes",
		tostring(AegisPathfinder.current), refreshed)
	check(active == 1, "and the active items and targets once, got %d", active)

	AegisPathfinder.turnedin["Read two@2@"] = true
	ok, err = pcall(function() AegisPathfinder:UpdateStatusFrame() end)
	check(ok, "finishing the guide runs: %s", tostring(err))
	check(refreshed == 2, "and so does finishing the guide, got %d refreshes", refreshed)
	check(active == 2, "which empties the active windows too, got %d", active)
end

-- A finished guide offers the custom zones before moving on -------------------------

--[[ When "Where next?" has something to ask (NextGuideFrame.lua), the engine
	waits for the answer instead of loading the next guide or leaving a
	branch -- otherwise the question would arrive after the move it is
	asking about. With nothing to ask, the old path runs. ]]
do
	local asked, moved, returned = 0, 0, 0
	function AegisPathfinder:LoadNextGuide() moved = moved + 1; return false end
	function AegisPathfinder:ReturnFromBranch() returned = returned + 1 end
	local answer = true
	function AegisPathfinder:OfferNextGuide() asked = asked + 1; return answer end

	AegisPathfinder.db.char.isbranching = nil
	AegisPathfinder:UpdateStatusFrame()
	check(asked == 1 and moved == 0, "a finished guide asks first and does not move on (asked %d, moved %d)", asked, moved)
	AegisPathfinder.db.char.isbranching = true
	AegisPathfinder:UpdateStatusFrame()
	check(returned == 0, "nor leaves a finished custom zone")

	answer = false
	AegisPathfinder:UpdateStatusFrame()
	check(returned == 1, "with nothing to ask, a finished branch returns as before")
	AegisPathfinder.db.char.isbranching = nil
	AegisPathfinder:UpdateStatusFrame()
	check(moved == 1, "and a finished route guide moves on as before")
	AegisPathfinder.OfferNextGuide = nil
end

-- Sharing holds a finished step for the party (PartySync.lua) --------------------------

do
	AegisPathfinder.actions = { "NOTE", "NOTE", "NOTE" }
	AegisPathfinder.quests = { "One@1@", "Two@2@", "Three@3@" }
	AegisPathfinder.tags = { "|N|1|", "|N|2|", "|N|3|" }
	AegisPathfinder.turnedin = { ["One@1@"] = true, ["Two@2@"] = true }
	AegisPathfinder.current = 2
	local asked = {}
	function AegisPathfinder:ShareHold(nextstep, oldcurrent)
		table.insert(asked, { nextstep, oldcurrent })
		return 2
	end
	AegisPathfinder:UpdateStatusFrame()
	check(asked[1] and asked[1][1] == 3 and asked[1][2] == 2,
		"the engine asks with the next step and the one it was on")
	check(AegisPathfinder.current == 2, "and stays on the held step, got %s", tostring(AegisPathfinder.current))
	function AegisPathfinder:ShareHold() return nil end
	AegisPathfinder:UpdateStatusFrame()
	check(AegisPathfinder.current == 3, "released, it moves on")

	AegisPathfinder.turnedin["Three@3@"] = true
	local moved = 0
	function AegisPathfinder:LoadNextGuide() moved = moved + 1; return false end
	function AegisPathfinder:ShareHold(nextstep) if nextstep == nil then return 3 end end
	AegisPathfinder:UpdateStatusFrame()
	check(AegisPathfinder.current == 3 and moved == 0, "a finished guide waits for the party before moving on")
	AegisPathfinder.ShareHold = nil
end

-- An optional accept waits for its |PRE| --------------------------------------------

--[[ "A Rescue OOX-22/FE! ... |PRE|2766| |O|" is offered once Find OOX-22/FE!
	is handed in, and skipped until then. The guides give the prerequisite as a
	quest id; it was looked up among the steps' names and never found, so the
	step was never offered at all. ]]
do
	AegisPathfinder.Locale = AegisPathfinder.Locale or { PART_GSUB = "%s%(Part %d+%)" }
	AegisPathfinder.db.char.completedquests = {}
	AegisPathfinder.db.char.completedquestsbyid = {}
	function AegisPathfinder:IsQuestCompletedOnServer(qid)
		return qid and self.db.char.completedquestsbyid[tonumber(qid)] == true or false
	end
	local function stepAfterUpdate(actions, quests, tags, turnedin)
		AegisPathfinder.actions, AegisPathfinder.quests, AegisPathfinder.tags = actions, quests, tags
		AegisPathfinder.turnedin = turnedin or {}
		AegisPathfinder.current = 1
		AegisPathfinder:UpdateStatusFrame()
		return AegisPathfinder.current
	end
	local rescue = { { "ACCEPT", "NOTE" }, { "Rescue OOX-22/FE!@1@", "After@2@" },
		{ "|QID|2767| |PRE|2766| |O|", "|N|after|" } }

	check(stepAfterUpdate(rescue[1], rescue[2], rescue[3]) == 2,
		"before Find OOX-22/FE! is handed in, the rescue is skipped")
	AegisPathfinder.db.char.completedquestsbyid[2766] = true
	check(stepAfterUpdate(rescue[1], rescue[2], rescue[3]) == 1,
		"once the server has it handed in, the rescue is offered")
	AegisPathfinder.db.char.completedquestsbyid[2766] = nil

	check(stepAfterUpdate({ "TURNIN", "ACCEPT", "NOTE" },
		{ "Find OOX-22/FE!@1@", "Rescue OOX-22/FE!@2@", "After@3@" },
		{ "|QID|2766|", "|QID|2767| |PRE|2766| |O|", "|N|after|" },
		{ ["Find OOX-22/FE!@1@"] = true }) == 2,
		"so is it when this guide's own turn-in for it is ticked")

	local oox = { { "ACCEPT", "NOTE" }, { "An OOX of Your Own@1@", "After@2@" },
		{ "|QID|3721| |PRE|836, 2767, 648| |O|", "|N|after|" } }
	AegisPathfinder.db.char.completedquestsbyid[836] = true
	AegisPathfinder.db.char.completedquestsbyid[2767] = true
	check(stepAfterUpdate(oox[1], oox[2], oox[3]) == 2, "a list of prerequisites needs all of them")
	AegisPathfinder.db.char.completedquestsbyid[648] = true
	check(stepAfterUpdate(oox[1], oox[2], oox[3]) == 1, "and with all three the step is offered")

	local named = { { "TURNIN", "ACCEPT", "NOTE" },
		{ "Contracts in Moonwhisper Coast@1@", "Zalwan's Cut@2@", "After@3@" },
		{ "|O|", "|QID|41975| |PRE|Contracts in Moonwhisper Coast| |O|", "|N|after|" } }
	check(stepAfterUpdate(named[1], named[2], named[3]) == 3, "a prerequisite named, not numbered, still waits")
	check(stepAfterUpdate(named[1], named[2], named[3], { ["Contracts in Moonwhisper Coast@1@"] = true }) == 2,
		"and is found by its name")

	check(not AegisPathfinder:IsPrereqTurnedIn("") and not AegisPathfinder:IsPrereqTurnedIn(nil),
		"no prerequisite is never handed in")
end

-- A collect note ticks itself --------------------------------------------------------

--[[ The Optimized guides had notes to collect a quest's items -- Bingles'
	four tools in Loch Modan -- that waited for a click. Tagged with the item
	(|L|, from the quest's own requirements), each ticks when the item is in
	your bags, and shows the ⟳. These are the guide's own four lines. ]]
do
	local steps = {}
	for line in io.lines("Guides/Optimized/Alliance/17_18_Loch_Modan.lua") do
		local _, _, title, tags = string.find(line, "^N (Bingles' [^|]-) (|.*)$")
		if title then table.insert(steps, { title = title, tags = tags }) end
	end
	check(table.getn(steps) == 4, "the guide has Bingles' four tools, got %d", table.getn(steps))
	local want = { ["Bingles' Wrench"] = 7343, ["Bingles' Screwdriver"] = 7345,
		["Bingles' Hammer"] = 7346, ["Bingles' Blastencapper"] = 7376 }

	local bags = { [7343] = 1 }               -- the wrench, and nothing else yet
	C_Item.GetItemCount = function(id) return bags[id] or 0 end
	-- Core.lua's, as far as an |L| tag goes (an earlier block stubbed it out).
	function AegisPathfinder:GetLootRequirement(i)
		local id, qty = self:GetObjectiveTag("L", i)
		if id then return tonumber(id), qty end
	end
	function AegisPathfinder:SetTurnedIn(i, value)
		self.turnedin[self.quests[i]] = value and true or nil
		self:UpdateStatusFrame()
	end
	AegisPathfinder.actions, AegisPathfinder.quests, AegisPathfinder.tags = {}, {}, {}
	for k, s in ipairs(steps) do
		AegisPathfinder.actions[k] = "NOTE"
		AegisPathfinder.quests[k] = s.title .. "@" .. k .. "@"
		AegisPathfinder.tags[k] = s.tags
	end
	for k, s in ipairs(steps) do
		local id, qty = AegisPathfinder:GetObjectiveTag("L", k)
		check(tonumber(id) == want[s.title] and qty == 1, "%s is tagged with its item, got %s x%s",
			s.title, tostring(id), tostring(qty))
		check(AegisPathfinder:IsAutoDetectable("NOTE", k), "and shows the auto-tick mark")
	end
	-- The engine looks at steps up to the first one not done: one picked up
	-- ahead of its step ticks the moment the guide reaches it.
	local function ticked()
		local out = {}
		for k, s in ipairs(steps) do
			if AegisPathfinder.turnedin[AegisPathfinder.quests[k]] then table.insert(out, s.title) end
		end
		return table.concat(out, ", ")
	end
	AegisPathfinder.turnedin, AegisPathfinder.current = {}, 1
	AegisPathfinder:UpdateStatusFrame()
	check(ticked() == "", "on the Blastencapper with only the wrench, nothing ticks yet; got %s", ticked())
	bags[7376] = 1
	AegisPathfinder:UpdateStatusFrame()
	check(ticked() == "Bingles' Blastencapper, Bingles' Wrench" and AegisPathfinder.current == 3,
		"the Blastencapper ticks, then the wrench already in the bags; got %s at step %s",
		ticked(), tostring(AegisPathfinder.current))
	bags[7345], bags[7346] = 1, 1
	AegisPathfinder:UpdateStatusFrame()
	check(ticked() == "Bingles' Blastencapper, Bingles' Wrench, Bingles' Hammer, Bingles' Screwdriver",
		"with all four, all four tick; got %s", ticked())
	C_Item.GetItemCount = function() return 0 end
	AegisPathfinder.SetTurnedIn, AegisPathfinder.GetLootRequirement = nil, nil
end

-- A level note ticks itself ----------------------------------------------------------

--[[ Teldrassil (1-12)'s step "Level 10 Required" was a plain note: reaching
	10 left it waiting for a click. With |LV|10| it is done at level 10,
	shows the ⟳, and still waits below it. ]]
do
	local line
	for l in io.lines("Guides/Alliance/01_12_Teldrassil.lua") do
		if string.find(l, "^N Level 10 Required ") then line = l end
	end
	local _, _, tags = string.find(line or "", "^N Level 10 Required (|.*)$")
	check(tags and string.find(tags, "|LV|10|", 1, true), "the guide's level note carries |LV|10|")
	function AegisPathfinder:SetTurnedIn(i, value)
		self.turnedin[self.quests[i]] = value and true or nil
		self:UpdateStatusFrame()
	end
	function AegisPathfinder:GetLootRequirement() return nil end
	AegisPathfinder.actions = { "NOTE", "ACCEPT" }
	AegisPathfinder.quests = { "Level 10 Required@1@", "Tumors@2@" }
	AegisPathfinder.tags = { tags or "", "|QID|923|" }
	check(AegisPathfinder:IsAutoDetectable("NOTE", 1), "and shows the auto-tick mark")
	local level = 9
	local keepLevel = UnitLevel
	UnitLevel = function() return level end
	AegisPathfinder.turnedin, AegisPathfinder.current = {}, 1
	AegisPathfinder:UpdateStatusFrame()
	check(not AegisPathfinder.turnedin["Level 10 Required@1@"] and AegisPathfinder.current == 1,
		"at level 9 it waits")
	level = 10
	AegisPathfinder:UpdateStatusFrame()
	check(AegisPathfinder.turnedin["Level 10 Required@1@"] and AegisPathfinder.current == 2,
		"at level 10 it is done, and the guide moves on")
	UnitLevel = keepLevel
	AegisPathfinder.SetTurnedIn, AegisPathfinder.GetLootRequirement = nil, nil
end

-- A grind to a level waits for it ---------------------------------------------------

--[[ RestedXP's "Grind to level 10" steps had no |LV|, so the guide passed over
	them at once. Now they wait for the level and tick there -- unless marked
	optional, as "Grind to 6 |O|" is: that one never holds the guide up. ]]
do
	local line
	for l in io.lines("Guides/RXP/Alliance/06_11_Teldrassil.lua") do
		if string.find(l, "^G Grind to level 10 |Z|Teldrassil|") then line = l end
	end
	local _, _, tags = string.find(line or "", "^G Grind to level 10 (|.*)$")
	check(tags and string.find(tags, "|LV|10|", 1, true), "RestedXP's Teldrassil grind carries |LV|10|")
	function AegisPathfinder:SetTurnedIn(i, value)
		self.turnedin[self.quests[i]] = value and true or nil
		self:UpdateStatusFrame()
	end
	function AegisPathfinder:GetLootRequirement() return nil end
	AegisPathfinder.actions = { "GRIND", "ACCEPT" }
	AegisPathfinder.quests = { "Grind to level 10@1@", "Tumors@2@" }
	AegisPathfinder.tags = { tags or "", "|QID|923|" }
	check(AegisPathfinder:IsAutoDetectable("GRIND", 1), "and shows the auto-tick mark")
	local level = 9
	local keepLevel = UnitLevel
	UnitLevel = function() return level end
	AegisPathfinder.turnedin, AegisPathfinder.current = {}, 1
	AegisPathfinder:UpdateStatusFrame()
	check(not AegisPathfinder.turnedin["Grind to level 10@1@"] and AegisPathfinder.current == 1,
		"at level 9 the grind waits")
	level = 10
	AegisPathfinder:UpdateStatusFrame()
	check(AegisPathfinder.turnedin["Grind to level 10@1@"] and AegisPathfinder.current == 2,
		"at level 10 it is done, and the guide moves on")

	-- Optional: passed over below the level, ticked once there.
	AegisPathfinder.quests = { "Grind to 6@1@", "Tumors@2@" }
	AegisPathfinder.tags = { "|O| |Z|Elwynn Forest| |LV|6|", "|QID|923|" }
	level = 5
	AegisPathfinder.turnedin, AegisPathfinder.current = {}, 1
	AegisPathfinder:UpdateStatusFrame()
	check(AegisPathfinder.current == 2 and not AegisPathfinder.turnedin["Grind to 6@1@"],
		"an optional grind does not hold the guide below its level, got step %d", AegisPathfinder.current)
	level = 6
	AegisPathfinder.current = 1
	AegisPathfinder:UpdateStatusFrame()
	check(AegisPathfinder.turnedin["Grind to 6@1@"], "and is ticked once you are there")
	UnitLevel = keepLevel
	AegisPathfinder.SetTurnedIn, AegisPathfinder.GetLootRequirement = nil, nil
end

-- An optional trip waits on its quest's prerequisite ---------------------------------

-- A dungeon guide's trip to Darnassus for Blood of Vorgendor, which needs
-- quest 41377 first: passed over until it is done, then taken.
do
	function AegisPathfinder:SetTurnedIn(i, value)
		self.turnedin[self.quests[i]] = value and true or nil
		self:UpdateStatusFrame()
	end
	function AegisPathfinder:GetLootRequirement() return nil end
	local prereqDone = false
	local keepPre = AegisPathfinder.IsPrereqTurnedIn
	function AegisPathfinder:IsPrereqTurnedIn() return prereqDone end
	AegisPathfinder.actions = { "RUN", "ACCEPT", "RUN" }
	AegisPathfinder.quests = { "Darnassus@1@", "Blood of Vorgendor@2@", "Shadowfang Keep@3@" }
	AegisPathfinder.tags = { "|N|Travel to Darnassus| |Z|Darnassus| |O| |PRE|41377|",
		"|QID|41378| |O| |PRE|41377|", "|N|The keep (42.8, 67.5)| |Z|Silverpine Forest|" }
	AegisPathfinder.turnedin, AegisPathfinder.current = {}, 1
	AegisPathfinder:UpdateStatusFrame()
	check(AegisPathfinder.current == 3, "without the first quest, the trip and the accept are passed over; at %s",
		tostring(AegisPathfinder.current))
	prereqDone = true
	AegisPathfinder.turnedin, AegisPathfinder.current = {}, 1
	AegisPathfinder:UpdateStatusFrame()
	check(AegisPathfinder.current == 1, "with it, the guide goes to Darnassus; at %s", tostring(AegisPathfinder.current))
	AegisPathfinder.IsPrereqTurnedIn = keepPre
	AegisPathfinder.SetTurnedIn, AegisPathfinder.GetLootRequirement = nil, nil
end

-- Travel steps: by any road, and the way there behind you ------------------------

--[[ RestedXP's 13-15 Westfall opens on "Travel to Elwynn Forest (19.0, 81.0)
	|O|", RestedXP's "#sticky .zone Westfall": the way out of Elwynn, done on
	entering Westfall. It only ticked within yards of its point, so a player
	who flew from Stormwind into Westfall had the guide stay on it while the
	Westfall quests went by. These are the guide's own lines. ]]
do
	local lines = {}
	for l in io.lines("Guides/RXP/Alliance/13_15_Westfall.lua") do
		if string.find(l, "^[RA] ") then table.insert(lines, l) end
		if table.getn(lines) == 2 then break end
	end
	local function step(line)
		local _, _, a, title, tags = string.find(line or "", "^(%a) (.-) (|.*)$")
		return a, title, tags
	end
	local _, title1, tags1 = step(lines[1])
	local _, title2, tags2 = step(lines[2])
	check(title1 == "Travel to Elwynn Forest" and string.find(tags1 or "", "|O|", 1, true)
		and string.find(tags1 or "", "|Z|Elwynn Forest|", 1, true),
		"the guide still opens on its optional way out of Elwynn, got %s", tostring(lines[1]))
	check(title2 == "The Forgotten Heirloom" and string.find(tags2 or "", "|Z|Westfall|", 1, true),
		"then Farmer Furlbrow's quest in Westfall, got %s", tostring(lines[2]))

	function AegisPathfinder:SetTurnedIn(i, value)
		self.turnedin[self.quests[i]] = value and true or nil
		self:UpdateStatusFrame()
	end
	function AegisPathfinder:GetLootRequirement() return nil end
	local inLog = {}
	function AegisPathfinder:GetObjectiveStatus(i)
		local qid = tonumber((self:GetObjectiveTag("QID", i)))
		return self.turnedin[self.quests[i]], qid and inLog[qid] and 1 or nil
	end
	local zone, subzone = "Stormwind City", "Trade District"
	GetZoneText = function() return zone end
	GetSubZoneText = function() return subzone end
	local function westfall(at, sub)
		zone, subzone = at, sub or ""
		AegisPathfinder.actions = { "RUN", "ACCEPT", "NOTE" }
		AegisPathfinder.quests = { title1 .. "@1@", title2 .. "@2@", "After@3@" }
		AegisPathfinder.tags = { tags1, tags2, "|N|after|" }
		AegisPathfinder.turnedin, AegisPathfinder.current = {}, 1
		AegisPathfinder:UpdateStatusFrame()
		return AegisPathfinder.current
	end
	check(westfall("Stormwind City", "Trade District") == 1, "in Stormwind the guide points the way out of Elwynn")
	check(westfall("Westfall", "Sentinel Hill") == 2,
		"flown into Westfall, the way there is behind you: on to Furlbrow, got step %d", AegisPathfinder.current)
	check(AegisPathfinder.turnedin[title1 .. "@1@"], "and it is ticked, so leaving Westfall does not bring it back")
	check(westfall("Elwynn Forest", "Goldshire") == 2, "in Elwynn it is done as it says: Travel to Elwynn Forest")
	inLog[64] = true
	check(westfall("Stormwind City", "Trade District") == 3,
		"with Furlbrow's quest already taken, it is behind you too, and so is the accept; got step %d",
		AegisPathfinder.current)
	inLog[64] = nil

	-- Teldrassil (1-12)'s step 87: "Gnarlpine Hold", a stop carrying The
	-- Glowing Fruit's id. Done in Gnarlpine Hold, or once the fruit's quest
	-- is in the log wherever you are -- the scan the quest log now asks for.
	local gnarl = {}
	for l in io.lines("Guides/Alliance/01_12_Teldrassil.lua") do
		if string.find(l, "^R Gnarlpine Hold ") or string.find(l, "^A The Glowing Fruit ") then
			local _, _, title, tags = string.find(l, "^%a (.-) (|.*)$")
			table.insert(gnarl, { title = title, tags = tags })
		end
	end
	local function teldrassil(sub)
		zone, subzone = "Teldrassil", sub
		AegisPathfinder.actions = { "RUN", "ACCEPT", "NOTE" }
		AegisPathfinder.quests = { gnarl[1].title .. "@1@", gnarl[2].title .. "@2@", "After@3@" }
		AegisPathfinder.tags = { gnarl[1].tags, gnarl[2].tags, "|N|after|" }
		AegisPathfinder.turnedin, AegisPathfinder.current = {}, 1
		AegisPathfinder:UpdateStatusFrame()
		return AegisPathfinder.current
	end
	check(table.getn(gnarl) == 2 and string.find(gnarl[1].tags, "|QID|930|", 1, true),
		"the zone guide's Gnarlpine Hold carries The Glowing Fruit's id")
	check(teldrassil("Dolanaar") == 1, "in Dolanaar without the fruit, the guide points to Gnarlpine Hold")
	check(teldrassil("Gnarlpine Hold") == 2, "in Gnarlpine Hold it is done")
	inLog[930] = true
	check(teldrassil("Dolanaar") == 3, "with The Glowing Fruit taken it is done wherever you are, got step %d",
		AegisPathfinder.current)
	inLog[930] = nil

	-- "Travel to Westfall (60.0, 19.4)", not optional, in RestedXP Hardcore.
	local tagsTo = "|N|(60.0, 19.4)| |Z|Westfall|"
	local function travel(name, tags, at, sub)
		zone, subzone = at, sub or ""
		AegisPathfinder.actions = { "RUN", "NOTE" }
		AegisPathfinder.quests = { name .. "@1@", "After@2@" }
		AegisPathfinder.tags = { tags, "|N|after|" }
		AegisPathfinder.turnedin, AegisPathfinder.current = {}, 1
		AegisPathfinder:UpdateStatusFrame()
		return AegisPathfinder.current
	end
	check(travel("Travel to Westfall", tagsTo, "Westfall", "Sentinel Hill") == 2,
		"Travel to Westfall is done anywhere in Westfall, not only at its point")
	check(travel("Travel to Westfall", tagsTo, "Elwynn Forest", "Goldshire") == 1, "and not before")
	check(travel("the Westfall Lighthouse", "|N|(30.0, 86.0)| |O| |Z|Westfall|", "Westfall", "Westfall Lighthouse") == 2,
		"the Westfall Lighthouse is done at the Westfall Lighthouse")
	check(travel("Travel towards Lakeshire", "|N|(30.7, 60.0)| |Z|Redridge Mountains|", "Redridge Mountains", "Lakeshire") == 2,
		"Travel towards Lakeshire is done in Lakeshire")
	check(travel("Westbrook Garrison", "|N|(24.8, 76.2)| |Z|Elwynn Forest|", "Elwynn Forest", "Goldshire") == 1,
		"a stop in the zone you are in still waits for you to get there")
	check(travel("Stormwind City", "|SZ|Stormwind City|", "Stormwind City", "Trade District") == 2,
		"a step's |SZ| is still read")
	-- The way there passes on only for an optional step: a stop waits.
	zone, subzone = "Westfall", ""
	AegisPathfinder.actions = { "RUN", "ACCEPT" }
	AegisPathfinder.quests = { "Westbrook Garrison@1@", "The Forgotten Heirloom@2@" }
	AegisPathfinder.tags = { "|N|(24.8, 76.2)| |Z|Elwynn Forest|", "|QID|64| |Z|Westfall|" }
	AegisPathfinder.turnedin, AegisPathfinder.current = {}, 1
	AegisPathfinder:UpdateStatusFrame()
	check(AegisPathfinder.current == 1, "a travel step that is not optional is not passed over by zone")
	check(AegisPathfinder:IsWayThere(1) == false, "nor is it a way there")
	AegisPathfinder.tags[1] = "|N|(24.8, 76.2)| |O| |PRE|41377| |Z|Elwynn Forest|"
	check(AegisPathfinder:IsWayThere(1) == false, "nor one that waits on a quest")

	AegisPathfinder.SetTurnedIn, AegisPathfinder.GetObjectiveStatus = nil, nil
	AegisPathfinder.GetLootRequirement = nil
	GetZoneText = function() return "Elwynn Forest" end
	GetSubZoneText = function() return "" end
end

-- Quests under a collapsed header ---------------------------------------------------

--[[ The quest log's functions see only the rows in sight. A guide quest under
	a collapsed header looked never accepted, so the headers are opened: once,
	not again for ten seconds, and only for a quest of the guide's. ]]
do
	local rows = { { "Westfall", true }, { "The Forgotten Heirloom", false, 64 } }
	local quests, onList, expanded, said = 3, { [64] = true, [36] = true }, 0, {}
	GetNumQuestLogEntries = function() return table.getn(rows), quests end
	GetQuestLogTitle = function(i) return rows[i][1], 10, nil, rows[i][2] and 1 or nil end
	C_QuestLog = { GetQuestIDForLogIndex = function(i) return rows[i][3] end,
		IsOnQuest = function(q) return onList[q] == true end }
	ExpandQuestHeader = function(i) if i == 0 then expanded = expanded + 1 end end
	local now = 1000
	GetTime = function() return now end
	function AegisPathfinder:Say(msg) table.insert(said, msg) end
	AegisPathfinder.actions = { "ACCEPT", "TURNIN" }
	AegisPathfinder.quests = { "The Forgotten Heirloom@1@", "Westfall Stew@2@" }
	AegisPathfinder.tags = { "|QID|64|", "|QID|36|" }

	check(AegisPathfinder:RevealGuideQuests() and expanded == 1,
		"Westfall Stew is on the quest list but out of sight: the headers open")
	check(table.getn(said) == 1 and string.find(said[1], "collapsed", 1, true), "and the guide says why")
	now = 1005
	check(not AegisPathfinder:RevealGuideQuests() and expanded == 1, "not again within ten seconds")
	now = 1011
	AegisPathfinder:RevealGuideQuests()
	check(expanded == 2 and table.getn(said) == 1, "again after, without saying it twice")
	table.insert(rows, { "Westfall Stew", false, 36 })
	now = 1030
	check(not AegisPathfinder:RevealGuideQuests() and expanded == 2, "with every quest in sight, nothing to open")
	table.remove(rows)
	AegisPathfinder.tags = { "|QID|64|", "|QID|99|" }
	check(not AegisPathfinder:RevealGuideQuests() and expanded == 2,
		"a hidden quest that is not the guide's is left where you put it")

	GetNumQuestLogEntries, GetQuestLogTitle, C_QuestLog, ExpandQuestHeader, GetTime = nil, nil, nil, nil, nil
	function AegisPathfinder:Say(msg) self:Print(msg) end
end

-- Report ---------------------------------------------------------------------

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end

print(string.format("GuideEngine: %d checks", checks))
if table.getn(failures) == 0 then
	print("All guide engine checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
