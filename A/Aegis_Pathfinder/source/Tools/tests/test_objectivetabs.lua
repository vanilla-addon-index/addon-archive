--[[
	Tests for the guide tab model and the bar that draws it.

	The panel used to hold one guide plus at most one branch off it. It now
	holds as many as the concept's tab bar implies, so this covers the list
	itself -- opening, switching, closing, and where each tab's step goes --
	as well as the bar: which tab is active, where the + sits once tabs come
	and go, and that the main route can never be closed out from under the
	addon.

	Run:  lua5.1 Tools/tests/test_objectivetabs.lua
]]

package.path = "Tools/tests/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

UISpecialFrames = {}
HideUIPanel = function(f) if f and f.Hide then f:Hide() end end
ShowUIPanel = function(f) if f and f.Show then f:Show() end end
PlaySound = function() end
GetNumQuestLeaderBoards = function() return 0 end
GetQuestLogLeaderBoard = function() return nil end
UnitLevel = function() return 12 end

local L = setmetatable({ PART_FIND = "^(.-)@", PART_GSUB = "@.*$" },
	{ __index = function(_, k) return k end })

AegisPathfinder = {
	Locale = L,
	guidelist = {}, qsplusguides = {},
	actions = {}, quests = {}, tags = {}, turnedin = {},
	current = 1, myfaction = "Alliance", icons = {},
	db = { char = { currentguide = "Elwynn Forest (1-12)" }, profile = {} },
	-- Every guide the tests open has to exist as far as Core is concerned.
	guides = setmetatable({}, { __index = function() return function() return "" end end }),
}
function AegisPathfinder:Debug() end
function AegisPathfinder:Print() self.__printed = true end
function AegisPathfinder.trim(s) return (string.gsub(s or "", "^%s*(.-)%s*$", "%1")) end
function AegisPathfinder.select(index, ...)
	if index == "#" then return table.getn(arg) end
	return arg[index]
end
function AegisPathfinder:IsTemplateGuide(name)
	local qsp = self.qsplusguides and self.qsplusguides[name]
	return (qsp and qsp.template) and true or false
end
function AegisPathfinder:GetObjectiveStatus() return nil end
function AegisPathfinder:GetObjectiveInfo(i)
	return self.actions[i], self.quests[i], self.quests[i]
end
function AegisPathfinder:GetObjectiveTag() return nil end
function AegisPathfinder:GetStepMeta() return nil, nil, false end
function AegisPathfinder:IsAutoDetectable() return false end
function AegisPathfinder:ParseGuideLevelRange() return nil, nil end
function AegisPathfinder:UpdateStatusFrame() end
function AegisPathfinder:UpdateGuideListPanel() end
function AegisPathfinder:GetGuideCategory(name)
	local qsp = self.qsplusguides[name]
	if qsp and qsp.category == "Profession" then return "profession" end
	if string.find(name or "", "^Dungeons/") then return "dungeon" end
	return "zone"
end
AegisPathfinder.qsplusguides["Alchemy (1-300)"] = { category = "Profession", steps = {} }
do
	local src = io.open("Core.lua"):read("*a")
	local from = string.find(src, "function AegisPathfinder:GuideBadge", 1, true)
	local to = string.find(src, "function AegisPathfinder:GetGuideCategory", from, true)
	assert(loadstring(string.sub(src, from, to - 1)))()
end
function AegisPathfinder:GetOptimizedGuideForLevel() return nil end
function AegisPathfinder:ToggleMaterialsPanel() end
function AegisPathfinder:GuideHasMaterials() return false end
function AegisPathfinder:GoToObjective() end
function AegisPathfinder:GoToPreviousObjective() end
function AegisPathfinder:SkipToNextObjective() end
function AegisPathfinder:SetTurnedIn() end
-- Loading a guide only has to move currentguide for these tests.
function AegisPathfinder:LoadGuide(name)
	self.db.char.currentguide = name
	self.current = 1
end

AegisPathfinder.optionsframe = CreateFrame("Frame", nil, UIParent)
AegisPathfinder.guidelistframe = CreateFrame("Frame", nil, UIParent)

dofile("Theme.lua")
dofile("ObjectivesFrame.lua")

-- The tab model lives in Core.lua, which is far too large to load under the
-- stub; lift just the functions under test out of it.
local core = io.open("Core.lua"):read("*a")
local from = string.find(core, "AegisPathfinder.NO_GUIDE =", 1, true)
local to = string.find(core, "---------------------------------\n--      Branching Functions", 1, true)
assert(from and to, "could not find the tab block in Core.lua")
assert(loadstring(string.sub(core, from, to - 1)))()

-- Plus ReturnFromBranch, the way back to the main route's tab.
local bfrom = string.find(core, "--[[ Go back to the main route", 1, true)
local bto = string.find(core, "-- Get the optimized guide for a given level", 1, true)
assert(bfrom and bto, "could not find the branch block in Core.lua")
assert(loadstring(string.sub(core, bfrom, bto - 1)))()

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end

local frame = AegisPathfinder.objectiveframe
AegisPathfinder:UpdateObjectivePanel()

local function names()
	local out = {}
	for _, t in ipairs(AegisPathfinder.db.char.tabs or {}) do table.insert(out, t.guide) end
	return table.concat(out, ", ")
end

-- One guide, one tab ----------------------------------------------------------

AegisPathfinder:UpdateObjectiveTabs()
check(frame.guideTabs[1]:IsShown(), "the guide you are on gets a tab")
check(frame.guideTabs[1].label:GetText() == "Elwynn Forest (1-12)",
	"the first tab names the loaded guide, got '%s'",
	tostring(frame.guideTabs[1].label:GetText()))
check(not frame.guideTabs[2]:IsShown(), "and no others until you open one")
check(frame.guideTabs[1].close:IsShown(),
	"every tab can be closed, even when it is the only one")
check(frame.guideTabs[1].badge.label:GetText() == "XP",
	"an authored guide gets the XP badge, got '%s'",
	tostring(frame.guideTabs[1].badge.label:GetText()))

-- Opening keeps what you were reading ------------------------------------------

AegisPathfinder.current = 14
AegisPathfinder:OpenGuideTab("Alchemy (1-300)")
AegisPathfinder:UpdateObjectiveTabs()

check(table.getn(AegisPathfinder.db.char.tabs) == 2,
	"opening a guide adds a tab, got: %s", names())
check(AegisPathfinder.db.char.tabs[1].guide == "Elwynn Forest (1-12)",
	"the guide you were on keeps its tab, got: %s", names())
check(AegisPathfinder.db.char.tabs[1] and AegisPathfinder.db.char.tabs[1].step == 14,
	"and its place in it, got %s",
	tostring(AegisPathfinder.db.char.tabs[1] and AegisPathfinder.db.char.tabs[1].step))
check(AegisPathfinder.db.char.activetab == 2, "the new tab is the active one")
check(frame.guideTabs[2]:IsShown(), "the second tab is drawn")
check(frame.guideTabs[2].close:IsShown(), "and it can be closed")
check(frame.guideTabs[2].badge.label:GetText() == "PF", "a profession guide's tab says PF, got '%s'",
	tostring(frame.guideTabs[2].badge.label:GetText()))
check(frame.guideTabs[1].badge.label:GetText() == "XP", "while the leveling guide's still says XP")

-- The old branch flags are answered from the tabs, so everything that reads
-- them keeps working.
check(AegisPathfinder.db.char.isbranching == true,
	"an active tab other than the first is a branch")
check(AegisPathfinder.db.char.branchsavedguide == "Elwynn Forest (1-12)",
	"and the main route is what tab 1 holds, got '%s'",
	tostring(AegisPathfinder.db.char.branchsavedguide))

-- A third, and a fourth.
AegisPathfinder:OpenGuideTab("Westfall (12-17)")
AegisPathfinder:OpenGuideTab("Mining (1-300)")
AegisPathfinder:UpdateObjectiveTabs()
check(table.getn(AegisPathfinder.db.char.tabs) == 4,
	"four guides open at once, got: %s", names())
check(frame.guideTabs[4]:IsShown(), "all four are drawn")

-- Opening one that is already open switches to it rather than duplicating.
AegisPathfinder:OpenGuideTab("Alchemy (1-300)")
check(table.getn(AegisPathfinder.db.char.tabs) == 4,
	"opening an open guide must not duplicate its tab, got: %s", names())
check(AegisPathfinder.db.char.activetab == 2,
	"it switches to the tab that already has it, got %s",
	tostring(AegisPathfinder.db.char.activetab))

-- Switching resumes where you left off ------------------------------------------

AegisPathfinder.current = 7
AegisPathfinder:SwitchToTab(1)
check(AegisPathfinder.db.char.tabs[2] and AegisPathfinder.db.char.tabs[2].step == 7,
	"leaving a tab remembers where you were in it, got %s",
	tostring(AegisPathfinder.db.char.tabs[2] and AegisPathfinder.db.char.tabs[2].step))
check(AegisPathfinder.current == 14,
	"and returning to one resumes there, got %s", tostring(AegisPathfinder.current))
check(AegisPathfinder.db.char.currentguide == "Elwynn Forest (1-12)",
	"switching loads that tab's guide, got '%s'",
	tostring(AegisPathfinder.db.char.currentguide))
check(AegisPathfinder.db.char.isbranching == false,
	"back on tab 1 is not branching")

AegisPathfinder:UpdateObjectiveTabs()
check(frame.guideTabs[1].fill.center.__color[1] < 0.2,
	"the active tab takes the panel fill so it reads as continuous with the list")

-- Closing ------------------------------------------------------------------------

AegisPathfinder:SwitchToTab(3)      -- Westfall
AegisPathfinder:CloseTab(3)
AegisPathfinder:UpdateObjectiveTabs()
check(table.getn(AegisPathfinder.db.char.tabs) == 3,
	"closing removes the tab, got: %s", names())
check(AegisPathfinder.db.char.activetab == 1,
	"closing the tab you are on returns you to the main route, got %s",
	tostring(AegisPathfinder.db.char.activetab))

-- Closing a tab to the left of the active one keeps you on the same guide.
AegisPathfinder:SwitchToTab(3)      -- Mining
local before = AegisPathfinder.db.char.currentguide
AegisPathfinder:CloseTab(2)         -- Alchemy, to its left
check(AegisPathfinder.db.char.currentguide == before,
	"closing a tab beside you must not move you, got '%s'",
	tostring(AegisPathfinder.db.char.currentguide))
check(AegisPathfinder.db.char.activetab == 2,
	"the active index follows the tab, got %s",
	tostring(AegisPathfinder.db.char.activetab))


-- Returning from a branch closes it and goes back to tab 1.
AegisPathfinder:SwitchToTab(2)
AegisPathfinder:ReturnFromBranch()
check(table.getn(AegisPathfinder.db.char.tabs) == 1,
	"returning closes the branch tab, got: %s", names())
check(AegisPathfinder.db.char.activetab == 1, "and lands on the main route")
check(AegisPathfinder.db.char.isbranching == false, "which is not a branch")

--[[ A class quest guide finishing hands back to tab 1 without changing its
	guide while it is still at your level: a paladin on Optimized Redridge
	(18-20) at 20, whose route pack is RestedXP Hardcore, was put on the
	Hardcore Redridge guide when Tome of Valor finished. Out-levelled, tab 1
	moves on along its own guides, not the pack's. ]]
do
	local A = AegisPathfinder
	local savedParse, savedOpt, savedSucc, savedLevel = A.ParseGuideLevelRange, A.GetOptimizedGuideForLevel,
		A.GetRouteSuccessor, UnitLevel
	A.nextzones = A.nextzones or {}
	A.nextzones["Optimized/Redridge (18-20)"] = "Optimized/Darkshore (20-21)"
	A.nextzones["Optimized/Darkshore (20-21)"] = "Optimized/Ashenvale (21-22)"
	function A:ParseGuideLevelRange(name)
		local _, _, lo, hi = string.find(name or "", "%((%d+)%-(%d+)%)")
		return tonumber(lo), tonumber(hi)
	end
	function A:GetOptimizedGuideForLevel() return "RXP_Hardcore/19-20 Redridge" end
	function A:GetRouteSuccessor() return nil end
	local level = 20
	UnitLevel = function() return level end
	local function handBack()
		A.db.char.tabs = { { guide = "Optimized/Redridge (18-20)", step = 12 },
			{ guide = "Class/Paladin: Tome of Valor (20)", step = 3 } }
		A.db.char.activetab = 2
		A:ReturnFromBranch()
		return A.db.char.tabs[1].guide
	end
	check(handBack() == "Optimized/Redridge (18-20)",
		"at 20, the class guide hands back to Optimized Redridge, got %s", tostring(A.db.char.tabs[1].guide))
	check(table.getn(A.db.char.tabs) == 1 and A.db.char.activetab == 1, "and its own tab closes")
	level = 21
	check(handBack() == "Optimized/Darkshore (20-21)",
		"out-levelled at 21, tab 1 goes on to the next Optimized guide, got %s", tostring(A.db.char.tabs[1].guide))
	level = 23
	check(handBack() == "RXP_Hardcore/19-20 Redridge",
		"past every guide it leads to, the route pack's guide is the last resort, got %s",
		tostring(A.db.char.tabs[1].guide))
	A.ParseGuideLevelRange, A.GetOptimizedGuideForLevel, A.GetRouteSuccessor, UnitLevel = savedParse, savedOpt,
		savedSucc, savedLevel
end

-- The + button --------------------------------------------------------------------

AegisPathfinder:UpdateObjectiveTabs()
local function lastAnchorTarget(f)
	local pts = f.__points
	return pts[table.getn(pts)][2]
end
check(lastAnchorTarget(frame.addTab) == frame.guideTabs[1],
	"with one tab, + sits beside it")

AegisPathfinder:OpenGuideTab("Alchemy (1-300)")
AegisPathfinder:UpdateObjectiveTabs()
check(lastAnchorTarget(frame.addTab) == frame.guideTabs[2],
	"with two, + follows the last one rather than floating where a closed tab was")

--[[ More guides than fit.

	Squeezing every open guide into the bar is what reduced five of them to
	"Optim... North... Gilnea...". The bar shows as many as fit at a readable
	width -- four at most -- and a ‹ › pair scrolls through the rest. ]]
local function shown()
	local out = {}
	for i = 1, 8 do
		if frame.guideTabs[i]:IsShown() then table.insert(out, i) end
	end
	return out
end
local function shownList() return table.concat(shown(), ",") end
-- Walk the row left to right: 8px in, ‹, the tabs in view, ›, then the +.
local function rightEdge()
	local x = 8
	if frame.tabLeft:IsShown() then x = x + frame.tabLeft:GetWidth() + 2 end
	for _, i in ipairs(shown()) do x = x + frame.guideTabs[i]:GetWidth() + 2 end
	x = x - 2
	if frame.tabRight:IsShown() then x = x + 2 + frame.tabRight:GetWidth() end
	if frame.addTab:IsShown() then x = x + 4 + frame.addTab:GetWidth() end
	return x
end
local function narrowest()
	local w = math.huge
	for _, i in ipairs(shown()) do w = math.min(w, frame.guideTabs[i]:GetWidth()) end
	return w
end
-- As the client fires it: with `this` set to the button.
local function click(b)
	local old = this
	this = b
	b:GetScript("OnClick")()
	this = old
end

-- Two open: both fit, and there is nothing to scroll.
check(not frame.tabLeft:IsShown() and not frame.tabRight:IsShown(),
	"with room for every tab there are no arrows")

for _, name in ipairs({ "A (1-2)", "B (1-2)", "C (1-2)", "D (1-2)", "E (1-2)", "F (1-2)" }) do
	AegisPathfinder:OpenGuideTab(name)
end
AegisPathfinder:UpdateObjectiveTabs()
check(table.getn(AegisPathfinder.db.char.tabs) == 8, "eight tabs open, got: %s", names())

-- At the concept's 396px, three at a time.
check(frame:GetWidth() == 396, "the panel opens at the concept's 396px, got %s", frame:GetWidth())
check(table.getn(shown()) == 3, "which shows three tabs at a time, got %s", shownList())
check(narrowest() >= 100, "each readable, got %d px", narrowest())
check(rightEdge() <= 396, "with the arrows and the + still inside it, reaching %d px", rightEdge())

-- Widened, four -- the most the bar shows at once.
frame:SetWidth(630)
AegisPathfinder:UpdateObjectiveTabs()
check(table.getn(shown()) == 4, "a panel widened to 630px shows four, got %s", shownList())
check(narrowest() >= 100, "each at a readable width, got %d px", narrowest())
check(frame.guideTabs[8]:IsShown(), "including the one just opened, which is the one you are on")
check(shownList() == "5,6,7,8", "so the view is the last four, got %s", shownList())
check(frame.tabLeft:IsShown() and frame.tabRight:IsShown(), "and the arrows appear")
check(frame.tabLeft:IsEnabled() and not frame.tabRight:IsEnabled(),
	"‹ has somewhere to go, › does not")
check(rightEdge() <= frame:GetWidth(),
	"the arrows, four tabs and the + fit inside the panel (%d of %d px)",
	rightEdge(), frame:GetWidth())
check(lastAnchorTarget(frame.tabRight) == frame.guideTabs[8], "› follows the last tab in view")
check(lastAnchorTarget(frame.addTab) == frame.tabRight, "and the + follows ›")
check(frame.guideTabs[8].badge:IsShown(), "at this width the badge still fits")

-- The arrows move the view, one tab at a time, and only the view.
click(frame.tabLeft)
check(shownList() == "4,5,6,7", "‹ moves the view back one tab, got %s", shownList())
check(AegisPathfinder.db.char.activetab == 8, "without switching guides")
check(frame.tabRight:IsEnabled(), "and › has somewhere to go again")
AegisPathfinder:UpdateObjectiveTabs()
check(shownList() == "4,5,6,7", "a repaint leaves the view where you put it, got %s", shownList())
for _ = 1, 10 do click(frame.tabLeft) end
check(shownList() == "1,2,3,4", "‹ stops at the first tab, got %s", shownList())
check(not frame.tabLeft:IsEnabled(), "and dims there")
click(frame.tabRight)
check(shownList() == "2,3,4,5", "› moves forward one, got %s", shownList())

-- The wheel over the bar does the same.
arg1 = -1; frame.tabbar:GetScript("OnMouseWheel")()
check(shownList() == "3,4,5,6", "wheel down scrolls forward, got %s", shownList())
arg1 = 1; frame.tabbar:GetScript("OnMouseWheel")()
check(shownList() == "2,3,4,5", "wheel up scrolls back, got %s", shownList())

-- Clicking a tab in view switches to it without moving the view.
click(frame.guideTabs[3])
check(AegisPathfinder.db.char.activetab == 3, "clicking a tab in view switches to it")
check(shownList() == "2,3,4,5", "and the view stays put, got %s", shownList())

-- Picking an already-open guide from the list switches to its tab, and
-- that tab comes into view.
AegisPathfinder:OpenGuideTab("F (1-2)")
AegisPathfinder:UpdateObjectiveTabs()
check(AegisPathfinder.db.char.activetab == 8, "picking an open guide switches to its tab")
check(shownList() == "5,6,7,8", "and scrolls to it, got %s", shownList())
AegisPathfinder:SwitchToTab(1)
AegisPathfinder:UpdateObjectiveTabs()
check(shownList() == "1,2,3,4", "in either direction, got %s", shownList())

-- The prefix every tab shares is not worth a third of a tab.
AegisPathfinder.db.char.tabs[2].guide = "Optimized/Elwynn Forest (1-10)"
AegisPathfinder:UpdateObjectiveTabs()
check(frame.guideTabs[2].label:GetText() == "Elwynn Forest (1-10)",
	"a tab names the guide without its pack prefix, got '%s'",
	tostring(frame.guideTabs[2].label:GetText()))
AegisPathfinder.db.char.tabs[2].guide = "Alchemy (1-300)"

-- A narrower panel shows fewer at a time, still at a readable width.
frame:SetWidth(420)
AegisPathfinder:UpdateObjectiveTabs()
check(table.getn(shown()) == 3, "a 420px panel shows three, got %s", shownList())
check(narrowest() >= 100, "each still readable, got %d px", narrowest())
check(rightEdge() <= 420, "and the row still fits, reaching %d px", rightEdge())
check(not frame.guideTabs[1].badge:IsShown(),
	"narrow tabs drop the badge so the name keeps the room")
frame:SetWidth(396)
AegisPathfinder:UpdateObjectiveTabs()

-- Past capacity there is nowhere to put another, and it says so.
AegisPathfinder.__printed = nil
AegisPathfinder:OpenGuideTab("G (1-2)")
check(table.getn(AegisPathfinder.db.char.tabs) == 8,
	"a ninth guide must not open, got: %s", names())
check(AegisPathfinder.__printed, "and the player is told why")
AegisPathfinder:UpdateObjectiveTabs()
check(not frame.addTab:IsShown(),
	"at capacity the + stops offering what it cannot do")

-- Replacing what a tab shows ----------------------------------------------------

AegisPathfinder:SwitchToTab(2)
AegisPathfinder:LoadGuideInTab("Westfall (12-17)")
check(table.getn(AegisPathfinder.db.char.tabs) == 8,
	"loading into a tab must not add one, got: %s", names())
check(AegisPathfinder.db.char.tabs[2].guide == "Westfall (12-17)",
	"the tab you are on shows the new guide, got '%s'",
	tostring(AegisPathfinder.db.char.tabs[2].guide))

-- Closing everything ------------------------------------------------------------

--[[ Every tab closes, the first included. Closing the last leaves the panel
	empty and waiting, rather than quietly loading a guide -- and that has to
	survive the auto-advance chain, which is why the sentinel is "No Guide". ]]
while table.getn(AegisPathfinder.db.char.tabs) > 0 do
	AegisPathfinder:CloseTab(1)
end
check(AegisPathfinder:HasNoGuide(), "with every tab closed there is no guide")
check(AegisPathfinder.db.char.currentguide == "No Guide",
	"and currentguide is the sentinel LoadNextGuide refuses to advance from, got '%s'",
	tostring(AegisPathfinder.db.char.currentguide))
check(AegisPathfinder.current == nil, "no current step")
check(AegisPathfinder.db.char.isbranching == false, "and nothing to branch from")

frame:Show()      -- a hidden panel does not repaint; it will on OnShow
AegisPathfinder:UpdateOHPanel()
check(frame.emptyState:IsShown(), "the panel shows its empty state")
check(frame.emptyState.text:GetText() == "Click here to load a guide",
	"inviting a pick, got '%s'", tostring(frame.emptyState.text:GetText()))
for i = 1, 8 do
	check(not frame.guideTabs[i]:IsShown(), "tab %d should be gone", i)
end

-- The invitation is a button onto the guide list.
AegisPathfinder.guidelistframe:Hide()
frame.emptyState:GetScript("OnClick")()
check(AegisPathfinder.guidelistframe:IsShown(), "clicking it opens the guide list")

check(not frame.navrow.stepControls[1]:IsShown()
	and not frame.navrow.stepControls[2]:IsShown()
	and not frame.navrow.stepControls[3]:IsShown(),
	"with no guide there is nothing to step through, so the step arrows go")

--[[ Picking a guide from the empty panel, with the real LoadGuide.

	Everything above runs a LoadGuide that only moves currentguide, which is
	how this shipped broken: the real one records how far through the
	outgoing guide you got as (current - 1) / steps, and with every tab
	closed there is no current step. It threw after the tab had been added,
	so the player got a tab with no guide in it. ]]
local fakeLoadGuide = AegisPathfinder.LoadGuide
do
	local kept = {}
	for k, v in pairs(AegisPathfinder) do kept[k] = v end
	function AegisPathfinder.split(delim, text)
		local out = {}
		for piece in string.gfind(text, "([^" .. delim .. "]+)") do table.insert(out, piece) end
		return out
	end
	function AegisPathfinder:IsDebugging() return false end
	dofile("Parser.lua")
	local real = AegisPathfinder.LoadGuide
	-- Keep only the real LoadGuide; everything it calls stays as the test has it.
	for k, v in pairs(kept) do AegisPathfinder[k] = v end
	AegisPathfinder.LoadGuide = real
end
function AegisPathfinder:WarmCaches() end
function AegisPathfinder:SmartSkipToStep() self.current = 1 end
AegisPathfinder.db.char.completion = {}
AegisPathfinder.db.char.turnins = {}
AegisPathfinder.guides["Elwynn Forest (1-12)"] = function() return [[
A A Threat Within |QID|783| |N|Deputy Willem, outside the abbey|
T A Threat Within |QID|783| |N|Marshal McBride, inside|
]] end

local ok, err = pcall(function()
	AegisPathfinder:LoadGuideInTab("Elwynn Forest (1-12)")
end)
check(ok, "opening a guide from the empty panel must not error: %s", tostring(err))
check(table.getn(AegisPathfinder.db.char.tabs) == 1,
	"a guide picked with nothing open gets a tab, got: %s", names())
check(AegisPathfinder.db.char.currentguide == "Elwynn Forest (1-12)",
	"and the guide is actually loaded into it, got '%s'",
	tostring(AegisPathfinder.db.char.currentguide))
check(table.getn(AegisPathfinder.actions) == 2,
	"its steps are parsed, got %d", table.getn(AegisPathfinder.actions))
check(AegisPathfinder.current == 1, "and there is a step to be on")
check(AegisPathfinder.db.char.completion["No Guide"] == nil,
	"nothing is recorded against the empty panel as if it were a guide")
AegisPathfinder:UpdateOHPanel()
check(not frame.emptyState:IsShown(), "and the empty state goes away")
check(frame.guideTabs[1]:IsShown() and frame.guideTabs[1].label:GetText() == "Elwynn Forest (1-12)",
	"the tab names the guide, got '%s'", tostring(frame.guideTabs[1].label:GetText()))
check(frame.navrow.stepControls[1]:IsShown(), "and the step arrows come back")

-- Left-click from the list takes the same path, through OpenGuideTab.
AegisPathfinder:CloseTab(1)
ok, err = pcall(function() AegisPathfinder:OpenGuideTab("Elwynn Forest (1-12)") end)
check(ok, "opening a new tab from the empty panel must not error: %s", tostring(err))
check(table.getn(AegisPathfinder.actions) == 2, "and loads the guide into it")

-- The ✓ in the nav row, with nothing open, has nothing to mark. It is hidden
-- then, but SetTurnedIn with no step is also reachable from key bindings.
AegisPathfinder:CloseTab(1)
AegisPathfinder.LoadGuide = fakeLoadGuide
do
	local stubSetTurnedIn = AegisPathfinder.SetTurnedIn
	local sfrom = string.find(core, "function AegisPathfinder:SetTurnedIn", 1, true)
	local sto = sfrom and string.find(core, "\nend\n", sfrom, true)
	assert(sfrom and sto, "could not find SetTurnedIn in Core.lua")
	assert(loadstring(string.sub(core, sfrom, sto + 4)))()
	ok, err = pcall(function() AegisPathfinder:SetTurnedIn() end)
	check(ok, "marking the current step done with no guide open must not error: %s", tostring(err))
	AegisPathfinder.SetTurnedIn = stubSetTurnedIn
end

-- Migration -------------------------------------------------------------------------

-- An empty list is a real state and must not be rebuilt on the next read.
AegisPathfinder.db.char.tabs = {}
AegisPathfinder.db.char.currentguide = "No Guide"
check(table.getn(AegisPathfinder:EnsureTabs()) == 0,
	"a closed-everything list stays empty rather than being rebuilt")

-- A character saved by the old one-deep branch model.
AegisPathfinder.db.char.tabs = nil
AegisPathfinder.db.char.activetab = nil
AegisPathfinder.db.char.isbranching = true
AegisPathfinder.db.char.branchsavedguide = "Elwynn Forest (1-12)"
AegisPathfinder.db.char.branchsavedstep = 22
AegisPathfinder.db.char.currentguide = "Alchemy (1-300)"
AegisPathfinder.current = 5

local migrated = AegisPathfinder:EnsureTabs()
check(table.getn(migrated) == 2,
	"an old branch becomes two tabs, got: %s", names())
check(migrated[1] and migrated[1].guide == "Elwynn Forest (1-12)" and migrated[1].step == 22,
	"the guide that was set aside becomes tab 1, at the step it was left")
check(migrated[2] and migrated[2].guide == "Alchemy (1-300)",
	"and the branch becomes tab 2, got '%s'",
	tostring(migrated[2] and migrated[2].guide))
check(AegisPathfinder.db.char.activetab == 2, "with the branch active")

-- Report ---------------------------------------------------------------------

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end

print(string.format("ObjectiveTabs: %d checks", checks))
if table.getn(failures) == 0 then
	print("All objective tab checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
