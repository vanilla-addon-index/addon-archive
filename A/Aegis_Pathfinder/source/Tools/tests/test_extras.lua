--[[
	Tests for the options' Extras page: what Extras.lua says in chat.

	The routine lines have to go when "Show Pathfinder chat messages" is
	off and nothing else with them; a reputation gain has to say where the
	faction stands and how far to the next rank, a faction under a closed
	header included, which is closed again after; a level up has to go to
	each channel ticked, worded for it, with the time at the level written
	properly -- and nowhere when it is unticked, or to a party or guild you
	are not in.

	Run:  lua5.1 Tools/tests/test_extras.lua
]]

package.path = "Tools/tests/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

local printed, sent = {}, {}
AegisPathfinder = { db = { char = {}, profile = {} } }
local A = AegisPathfinder
function A:Print(msg) table.insert(printed, msg) end
local levelTime = { secs = 7260, whole = true }
local asked
function A:TimeAtLevel(level)
	asked = level
	return levelTime.secs, levelTime.whole
end
SendChatMessage = function(msg, channel) table.insert(sent, channel .. ": " .. msg) end
local party, guild = 0, false
GetNumPartyMembers = function() return party end
IsInGuild = function() return guild end

-- The reputation panel's list, as the client gives it: headers open or
-- closed, and only the rows under open ones.
FACTION_STANDING_INCREASED = "Reputation with %s increased by %d."
FACTION_STANDING_DECREASED = "Reputation with %s decreased by %d."
for i, name in ipairs({ "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }) do
	_G["FACTION_STANDING_LABEL" .. i] = name
end
local factions = {
	{ name = "Alliance", header = true, rows = {
		{ name = "Stormwind", standing = 6, bottom = 9000, top = 21000, value = 13350 },
		{ name = "Ironforge", standing = 8, bottom = 42000, top = 43000, value = 42999 },
	} },
	{ name = "Other", header = true, collapsed = true, rows = {
		{ name = "Booty Bay", standing = 4, bottom = 0, top = 3000, value = 2990 },
	} },
}
local expanded, collapsed = 0, 0
local function Rows()
	local out = {}
	for _, h in ipairs(factions) do
		table.insert(out, h)
		if not h.collapsed then
			for _, r in ipairs(h.rows) do table.insert(out, r) end
		end
	end
	return out
end
GetNumFactions = function() return table.getn(Rows()) end
GetFactionInfo = function(i)
	local r = Rows()[i]
	if not r then return end
	if r.header then return r.name, "", 0, 0, 0, 0, false, false, true, r.collapsed end
	return r.name, "", r.standing, r.bottom, r.top, r.value, false, true, false, false
end
ExpandFactionHeader = function(i) Rows()[i].collapsed = false; expanded = expanded + 1 end
CollapseFactionHeader = function(i) Rows()[i].collapsed = true; collapsed = collapsed + 1 end

dofile("Extras.lua")
local X = A.Extras

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end
local function fire(ev, a1)
	event, arg1 = ev, a1
	X.frame:GetScript("OnEvent")()
end
local function tick(secs)
	arg1 = secs
	X.frame:GetScript("OnUpdate")()
end

-- Show Pathfinder chat messages ------------------------------------------------------

A:Say("Flying to Ironforge.")
check(printed[1] == "Flying to Ironforge.", "a routine line shows to start with")
A.db.char.chatmessages = false
A:Say("Sold 3 grey items for 12s.")
A:Print("Not enough money to repair: it costs 2g.")
check(table.getn(printed) == 2 and printed[2] == "Not enough money to repair: it costs 2g.",
	"switched off: the routine line goes, the warning stays")
A.db.char.chatmessages = true
A:Say("Repaired for 1g.")
check(printed[3] == "Repaired for 1g.", "and comes back on")
A.db.char.chatmessages = nil
printed = {}

-- The words ------------------------------------------------------------------------

local durations = { { 0, "less than a minute" }, { 59, "less than a minute" }, { 60, "1 minute" },
	{ 119, "1 minute" }, { 120, "2 minutes" }, { 3599, "59 minutes" }, { 3600, "1 hour" },
	{ 3720, "1 hour 2 minutes" }, { 7260, "2 hours 1 minute" }, { 7259 + 60, "2 hours 1 minute" },
	{ 7200 + 59, "2 hours" } }
for _, d in ipairs(durations) do
	check(X.Duration(d[1]) == d[2], "%d seconds read %q, got %q", d[1], d[2], X.Duration(d[1]))
end
for _, t in ipairs({ { 0, "0" }, { 999, "999" }, { 7650, "7,650" }, { 12000, "12,000" }, { 1234567, "1,234,567" } }) do
	check(X.Thousands(t[1]) == t[2], "%d reads %s, got %s", t[1], t[2], X.Thousands(t[1]))
end

-- Reputation -----------------------------------------------------------------------

do
	local faction, amount = X.ParseGain("Reputation with Stormwind increased by 25.")
	check(faction == "Stormwind" and amount == 25, "the client's line read: Stormwind, 25")
	check(X.ParseGain("Reputation with Stormwind decreased by 25.") == nil, "a loss is not a gain")
	check(X.ParseGain("You are now Honored with Stormwind.") == nil, "nor a new rank's line")
	check(X.ParseGain("Reputation with Timbermaw Hold increased by 250.") == "Timbermaw Hold", "a name of two words")
end
check(X.ReputationLine("Stormwind", 25) == "Stormwind +25: Honored 4,350 / 12,000, 7,650 to Revered",
	"where it stands and how far to the next rank, got %s", X.ReputationLine("Stormwind", 25))
check(X.ReputationLine("Ironforge", 5) == "Ironforge +5: Exalted 999 / 1,000", "Exalted: no rank after it, got %s",
	X.ReputationLine("Ironforge", 5))
do
	local line = X.ReputationLine("Booty Bay", 10)
	check(line == "Booty Bay +10: Neutral 2,990 / 3,000, 10 to Friendly", "a faction under a closed header is found, got %s",
		line)
end
check(expanded == 1 and collapsed == 1 and factions[2].collapsed, "the header is opened to look, and closed again")
expanded, collapsed = 0, 0
check(X.ReputationLine("Ravenholdt", 5) == "Ravenholdt +5", "a faction not in the list: just the gain")
check(collapsed == 1 and factions[2].collapsed, "and the headers are left as they were")

fire("CHAT_MSG_COMBAT_FACTION_CHANGE", "Reputation with Stormwind increased by 25.")
tick(1)
check(table.getn(printed) == 0, "off to start with: nothing said")
A.db.char.repdetail = true
fire("CHAT_MSG_COMBAT_FACTION_CHANGE", "Reputation with Stormwind increased by 25.")
tick(0.1)
check(table.getn(printed) == 0, "on: not said at once, while the standing settles")
tick(0.15)
check(printed[1] == "Stormwind +25: Honored 4,350 / 12,000, 7,650 to Revered", "then said, got %s", tostring(printed[1]))
fire("CHAT_MSG_COMBAT_FACTION_CHANGE", "Reputation with Stormwind decreased by 10.")
tick(1)
check(table.getn(printed) == 1, "a loss says nothing")
A.db.char.chatmessages = false
fire("CHAT_MSG_COMBAT_FACTION_CHANGE", "Reputation with Ironforge increased by 5.")
tick(1)
check(printed[2] == "Ironforge +5: Exalted 999 / 1,000", "asked for, it shows with the routine lines off")
A.db.char.chatmessages, A.db.char.repdetail = nil, nil
printed = {}

-- Level-ups ------------------------------------------------------------------------

-- A character that has not touched them: the emote, and nothing else.
check(X:AnnounceLevel(23) == 1, "to start with, one goes out")
check(sent[1] == "EMOTE: Pathfinder: I just leveled up from 22 to 23! (2 hours 1 minute)",
	"the emote, got %s", tostring(sent[1]))
check(asked == 22, "with the time at the level just left")
sent = {}
A.db.char.levelemote = false
check(X:AnnounceLevel(23) == 0 and table.getn(sent) == 0, "the emote unticked, none ticked: nothing goes out")
A.db.char.levelparty, A.db.char.levelguild = true, true
check(X:AnnounceLevel(23) == 0, "party and guild ticked, in neither: nothing goes out")
party, guild = 2, true
check(X:AnnounceLevel(23) == 2, "in both: two")
check(sent[1] == "PARTY: Pathfinder: I leveled up from 22 to 23! (2 hours 1 minute)"
	and sent[2] == "GUILD: Pathfinder: I leveled up from 22 to 23! (2 hours 1 minute)", "worded for them, got %s / %s",
	tostring(sent[1]), tostring(sent[2]))
sent = {}
levelTime = { secs = 65, whole = true }
X:AnnounceLevel(2)
check(sent[1] == "PARTY: Pathfinder: I leveled up from 1 to 2! (1 minute)", "one minute, got %s", tostring(sent[1]))
sent = {}
levelTime = { secs = 600, whole = false }
X:AnnounceLevel(23)
check(sent[1] == "PARTY: Pathfinder: I leveled up from 22 to 23!", "a level not counted from its start: no time, got %s",
	tostring(sent[1]))
sent = {}
levelTime = { secs = 7260, whole = true }
A.db.char.levelemote = nil
fire("PLAYER_LEVEL_UP", "23")
check(table.getn(sent) == 3, "the level-up event announces to all three ticked")
sent = {}
A.db.char.levelemote, A.db.char.levelparty, A.db.char.levelguild = false, nil, nil
fire("PLAYER_LEVEL_UP", "24")
check(table.getn(sent) == 0, "all unticked: nothing")
A.db.char.levelemote = nil
do
	local saved = A.db
	A.db = nil
	local ok = pcall(function()
		fire("PLAYER_LEVEL_UP", "25")
		fire("CHAT_MSG_COMBAT_FACTION_CHANGE", "Reputation with Stormwind increased by 25.")
		tick(1)
		A:Say("x")
	end)
	check(ok, "before the settings are read: no error")
	A.db = saved
end

-- The talent trees, for the Talent Advisor to come ----------------------------------

do
	-- Two trees of a made-up class, the second talent of the first needing
	-- the first; the client's prerequisite comes as tier, column, met.
	local TREES = {
		{ name = "Arms", talents = { { "Deflection", 1, 2, 5 }, { "Tactical Mastery", 2, 2, 5, { 1, 2 } } } },
		{ name = "Fury", talents = { { "Cruelty", 1, 3, 5 } } },
	}
	UnitClass = function() return "Warrior", "WARRIOR" end
	GetNumTalentTabs = function() return table.getn(TREES) end
	GetTalentTabInfo = function(t) return TREES[t].name, "icon", 0, "bg" end
	GetNumTalents = function(t) return table.getn(TREES[t].talents) end
	GetTalentInfo = function(t, i)
		local x = TREES[t].talents[i]
		return x[1], "icon", x[2], x[3], 0, x[4], nil, 1
	end
	GetTalentPrereqs = function(t, i)
		local pre = TREES[t].talents[i][5]
		if pre then return pre[1], pre[2], nil end
	end
	local asked = {}
	local savedLines = X.TalentLines
	X.TalentLines = function(t, i)
		table.insert(asked, t .. ":" .. i)
		return { TREES[t].talents[i][1], "Rank 0/5", "Next rank:", "Does something." }
	end
	A.db.account = {}
	printed = {}
	check(X:SaveTalentTrees() == 3, "three talents saved")
	local w = A.db.account.talenttrees and A.db.account.talenttrees.WARRIOR
	check(w and w.class == "Warrior" and table.getn(w.trees) == 2 and w.trees[1].name == "Arms",
		"for the account, by class: both trees, by name")
	local tm = w and w.trees[1].talents[2]
	check(tm and tm.name == "Tactical Mastery" and tm.tier == 2 and tm.column == 2 and tm.max == 5,
		"each talent's place and ranks")
	check(tm and table.getn(tm.prereqs) == 1 and tm.prereqs[1].tier == 1 and tm.prereqs[1].column == 2,
		"and what it needs first")
	check(tm and tm.text == "Tactical Mastery | Rank 0/5 | Next rank: | Does something.", "and its tooltip, got %s",
		tostring(tm and tm.text))
	check(table.getn(w.trees[1].talents[1].prereqs) == 0, "a talent that needs nothing first: none")
	check(string.find(printed[1] or "", "Warrior", 1, true) and string.find(printed[1], "1 of 9", 1, true),
		"says so, and how many classes are in, got %s", tostring(printed[1]))
	-- Another class adds to them.
	UnitClass = function() return "Mage", "MAGE" end
	X:SaveTalentTrees()
	check(A.db.account.talenttrees.WARRIOR and A.db.account.talenttrees.MAGE, "a second class adds its own")
	check(string.find(printed[2] or "", "Mage, Warrior (2 of 9)", 1, true), "listed, got %s", tostring(printed[2]))
	X.TalentLines = savedLines
	printed = {}
end

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end
print(string.format("Extras: %d checks", checks))
if table.getn(failures) == 0 then
	print("All extras checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
