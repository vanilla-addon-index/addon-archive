--[[
	Tests for the Talent Advisor on Modern Spellbook's talent window
	(TalentModern.lua).

	Modern Spellbook is stood in for as far as Pathfinder reads it, in the
	shape its own files have (Talents/MSB_TalentTree.lua, MSB_TalentGrid.lua,
	MSB_TalentSimulation.lua): TalentTree, made from CTalentTree, with its
	frame ModernTalentTreeFrame, a spec a tree (a panel, its header, a grid of
	icons, each icon a frame with its border_frame, talent_name, talent_tab
	and talent_index), its expanded view, Refresh and UpdateSimControls; and
	TalentSimulation, made from CTalentSimulation, with a working plan, the
	saved list of 20 and the mode.

	Once it has loaded its window has to be marked after every Refresh: the
	strip over it (the build, the card for the next point, the buttons), the
	badges, ring and NEXT on every tree's talents and NEXT POINT HERE by the
	next point's tree, the expanded view's talents too; the marks stepping
	aside while it shows a plan; nothing with the advisor off. Plan to my
	level and Whole build have to land in its list and be the plan it shows;
	Share has to give the build's string and follow a pasted one.

	Run:  lua5.1 Tools/tests/test_talentmodern.lua
]]

package.path = "Tools/tests/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

local printed = {}
AegisPathfinder = { db = { char = {}, profile = {} } }
local A = AegisPathfinder
function A:Print(msg) table.insert(printed, msg) end
function A:Say(msg) end
local refreshedOptions = 0
function A:RefreshConfigPanel() refreshedOptions = refreshedOptions + 1 end
A.ItemScore = { Spec = function() return "Fury", "picked" end }
UISpecialFrames = {}
GetTime = function() return 100 end

local checks, failures = 0, {}
local function check(cond, msg, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(msg, unpack(arg))) end
end

local function fire(f, script, ev, a1)
	local h = f:GetScript(script)
	assert(h, "no " .. script .. " script")
	local oldThis, oldEvent, oldArg = this, event, arg1
	this, event, arg1 = f, ev, a1
	h()
	this, event, arg1 = oldThis, oldEvent, oldArg
end

-- The talent API for the warrior's trees, with the ranks given.
local TREES = dofile("Tools/tests/talent_trees.lua")
local current = { trees = TREES.WARRIOR, ranks = {}, unspent = 1, level = 22 }
GetNumTalentTabs = function() return table.getn(current.trees) end
GetTalentTabInfo = function(t) return current.trees[t].name, "icon", 0, "bg" end
GetNumTalents = function(t) return table.getn(current.trees[t].talents) end
GetTalentInfo = function(t, i)
	local x = current.trees[t].talents[i]
	if not x then return nil end
	return x[1], "icon", x[2], x[3], current.ranks[x[1]] or 0, x[4], nil, 1
end
GetTalentPrereqs = function(t, i)
	local x = current.trees[t].talents[i]
	if x[5] > 0 then return x[5], x[6], nil end
end
UnitLevel = function() return current.level end
UnitCharacterPoints = function() return current.unspent, 0 end
UnitClass = function() return "Warrior", "WARRIOR" end
GameTooltip.SetTalent = function() end

dofile("Theme.lua")
dofile("TalentBuilds.lua")
dofile("TalentAdvisor.lua")
dofile("TalentWindow.lua")
dofile("TalentModern.lua")
local TA = A.TalentAdvisor
local MW = TA.Modern

local points = TA.Points(A.TalentBuilds.WARRIOR.levelling)
local function After(n)
	local r = {}
	for k = 1, n do r[points[k]] = (r[points[k]] or 0) + 1 end
	return r
end
local function Find(name)
	for t, tree in ipairs(current.trees) do
		for i, x in ipairs(tree.talents) do
			if x[1] == name then return t, i end
		end
	end
end

check(MW and not MW.hooked, "nothing is hooked before Modern Spellbook loads")

-- Modern Spellbook, as it loads ------------------------------------------------

local calls = { refresh = 0, controls = 0 }
CTalentTree = {}
CTalentTree.__index = CTalentTree
function CTalentTree:Refresh() calls.refresh = calls.refresh + 1 end
function CTalentTree:UpdateSimControls() calls.controls = calls.controls + 1 end
local function Grid(parent, t)
	local grid = { icons = {} }
	for i, x in ipairs(current.trees[t].talents) do
		local f = CreateFrame("Button", nil, parent)
		local border = CreateFrame("Frame", nil, f)
		table.insert(grid.icons, { frame = f, border_frame = border, talent_name = x[1], talent_tab = t, talent_index = i })
	end
	return grid
end
local frame = CreateFrame("Frame", "ModernTalentTreeFrame", UIParent)
frame:Hide()
local tree = setmetatable({ frame = frame, specs = {}, expanded_view = { grids_by_tab = {} } }, CTalentTree)
for t = 1, 3 do
	local panel = CreateFrame("Frame", nil, frame)
	local header = panel:CreateFontString(nil, "OVERLAY")
	table.insert(tree.specs, { panel = panel, header = header, grid = Grid(panel, t), tab_index = t,
		tab_name = current.trees[t].name })
end

-- Its plans: a working plan, a list of 20 saved, learned or simulated.
local sim = { mode = "learned", saved = {} }
function sim:Load() end
local function Blank() return { points = 0, { points = 0 }, { points = 0 }, { points = 0 } } end
function sim:NewWorkingPlan() self.working = Blank() end
function sim:GetPlan() return self.working end
function sim:GetSavedPlans() return self.saved end
function sim:SaveWorkingPlan(name)
	self.working.name = name
	for i, p in ipairs(self.saved) do
		if p.name == name then self.saved[i] = self.working; return end
	end
	if table.getn(self.saved) >= 20 then return end
	table.insert(self.saved, self.working)
end
function sim:SetMode(mode) self.mode = mode end
function sim:IsSimulated() return self.mode == "simulated" end
local made = 0
CTalentSimulation = function() made = made + 1; return sim end
TalentTree = tree

fire(MW.events, "OnEvent", "ADDON_LOADED", "SomeOtherAddon")
check(not MW.hooked, "another addon loading hooks nothing")
fire(MW.events, "OnEvent", "ADDON_LOADED", "ModernSpellBook")
check(MW.hooked and rawget(tree, "Refresh") ~= nil, "Modern Spellbook loading wraps its window's Refresh")

-- A level 22 warrior, the first 12 points spent, one to spend.
current.level, current.unspent, current.ranks = 22, 1, After(12)
frame:Show()
fire(frame, "OnShow")
tree:Refresh()
check(calls.refresh == 1, "its own Refresh still runs")
local strip = MW.strip
check(strip and strip:IsShown() and strip:GetParent() == frame, "the strip shows, on its window")
check(strip.card:IsShown() and strip.card.title:GetText() == "Take Deep Wounds"
	and strip.card.detail:GetText() == "Rank 3 of 3 in Arms · 1 point to spend",
	"the card says where the next point goes, got %s", tostring(strip.card.title:GetText()))
check(strip.drop.label:GetText() == "Leveling, then Fury at 60", "following levelling, then Fury")

local function Icon(name, grid)
	local t, i = Find(name)
	return (grid or tree.specs[t].grid).icons[i]
end
local deep = Icon("Deep Wounds").frame.apMarks
check(deep and deep.badge:IsShown() and deep.badge.text:GetText() == "3" and deep.glow:IsShown() and deep.tag:IsShown(),
	"Deep Wounds: its badge, the gold ring and NEXT")
local _, rel = deep.glow:GetPoint(1)
check(rel == Icon("Deep Wounds").border_frame, "centred on the icon, not the cell")
check(Icon("Improved Heroic Strike").frame.apMarks.badge.tick:IsShown(), "a talent taken in full has a tick")
check(not Icon("Improved Thunder Clap").frame.apMarks.badge:IsShown(), "one the build leaves alone has nothing")
check(Icon("Cruelty").frame.apMarks.badge.text:GetText() == "5", "every tree is marked at once: Cruelty, 5")
check(tree.specs[1].apPill:IsShown() and not tree.specs[2].apPill:IsShown() and not tree.specs[3].apPill:IsShown(),
	"NEXT POINT HERE by Arms alone")

-- Its expanded view of one tree has its own grid.
local fury = Grid(frame, 2)
tree.expanded_view.grids_by_tab[2] = fury
tree.expanded_view.grid = fury
tree.expanded_spec = 2
tree:Refresh()
check(Icon("Cruelty", fury).frame.apMarks.badge:IsShown(), "the expanded view's talents are marked too")
tree.expanded_spec = nil

-- Showing a plan: the marks step aside, the strip stays.
sim.mode = "simulated"
TalentSimulation = sim
tree:Refresh()
check(not Icon("Deep Wounds").frame.apMarks:IsShown() and not tree.specs[1].apPill:IsShown() and strip:IsShown(),
	"while it shows a plan, no marks; the strip stays")
sim.mode = "learned"
tree:Refresh()
check(Icon("Deep Wounds").frame.apMarks:IsShown(), "back on your talents, the marks are back")

-- The advisor off: nothing.
A.db.char.talentadvisor = false
TA:Refresh()
check(not strip:IsShown() and not Icon("Deep Wounds").frame.apMarks:IsShown(), "no strip and no marks with the advisor off")
A.db.char.talentadvisor = true
TA:Refresh()
check(strip:IsShown(), "on again")

-- Points off the build: the strip says so on a row of its own.
check(strip:GetHeight() == 60, "one row to start with, got %s", tostring(strip:GetHeight()))
current.ranks["Improved Thunder Clap"] = 2
tree:Refresh()
check(strip.warn:GetText() == "2 points off the build. It carries on from the closest point." and strip:GetHeight() == 78,
	"two points off the build: said under the row, the strip a row taller")
current.ranks["Improved Thunder Clap"] = nil
tree:Refresh()
check(strip:GetHeight() == 60 and strip.warn:GetText() == "", "back on the build: one row")

-- Plans ----------------------------------------------------------------------

TalentSimulation = nil
printed = {}
fire(strip.mine, "OnClick")
check(made == 1 and TalentSimulation == sim, "its plans are made as its window makes them, the first time")
local p = sim.saved[1]
check(p and p.name == "Pathfinder: Leveling to 22" and p.points == 13,
	"Plan to my level: 13 points at 22, named so, got %s %s", p and tostring(p.name) or "none", p and tostring(p.points) or "")
local t, i = Find("Deep Wounds")
check(p and p[t][i] == 3 and p[t].points == 13, "Deep Wounds at 3, every point in Arms, by tree and number")
check(sim.working == p and sim.mode == "simulated", "and it is the plan its window shows")
check(calls.controls >= 1 and string.find(printed[1] or "", "press its Apply", 1, true), "its window told, and chat says how to learn it")
fire(strip.whole, "OnClick")
check(table.getn(sim.saved) == 2 and sim.saved[2].name == "Pathfinder: Leveling" and sim.saved[2].points == 51,
	"Whole build: all 51")
fire(strip.mine, "OnClick")
check(table.getn(sim.saved) == 2, "saving the same plan again replaces it")
for k = 3, 20 do sim.saved[k] = { name = "Mine " .. k, points = 0 } end
current.level = 23
printed = {}
fire(strip.mine, "OnClick")
check(table.getn(sim.saved) == 20 and string.find(printed[1] or "", "its list is full", 1, true),
	"with its list full it says so, got %s", tostring(printed[1]))
current.level = 22

-- Share and plan ---------------------------------------------------------------

sim.mode = "learned"
fire(strip.share, "OnClick")
local share = MW.share
check(share and share:IsShown(), "Share opens the dialog")
local text = TA:ShareText(TA:State())
check(share.shareBox:GetText() == text and string.find(text, "^MSB1%-WARRIOR%-"), "with the build's string")
check(share.shareTitle:GetText() == "Share Warrior leveling", "named for the build")
check(share.mine.label:GetText() == "PLAN TO MY LEVEL · 13 POINTS" and share.whole.label:GetText() == "WHOLE BUILD · 51 POINTS",
	"its plan buttons say how many points, got %s", tostring(share.mine.label:GetText()))
share.shareBox:SetText("typed over")
fire(share.shareBox, "OnTextChanged")
check(share.shareBox:GetText() == text, "the string can't be typed over")

share.followBox:SetText("MSB1-MAGE-5")
fire(share.follow, "OnClick")
check(string.find(share.said:GetText(), "another class", 1, true) and A.db.char.talentbuild ~= "shared",
	"another class's string is refused")
local prot = TA.SpecBuild(A.TalentBuilds.WARRIOR, "Protection")
local protText = TA.ShareString(TA.ReadTree(), "WARRIOR", TA.Targets(TA.Points(prot)))
share.followBox:SetText(protText)
refreshedOptions = 0
fire(share.follow, "OnClick")
check(A.db.char.talentbuild == "shared" and string.find(share.said:GetText(), "Following it", 1, true)
	and refreshedOptions == 1, "a pasted Protection string is followed, the options told")
check(strip.drop.label:GetText() == "Shared build" and share.shareTitle:GetText() == "Share Shared build",
	"the strip and the dialog name it")
check(tree.specs[3].apPill:IsShown() and not tree.specs[1].apPill:IsShown(), "its first point is in Protection")
A.db.char.talentbuild = "auto"

-- Without its plans (an older Modern Spellbook): the plan buttons can't be pressed.
TalentSimulation, CTalentSimulation = nil, nil
TA:Refresh()
check(strip.mine:GetAlpha() < 1 and strip.whole:GetAlpha() < 1 and strip.share:GetAlpha() == 1,
	"no plans to save to: the plan buttons dimmed, Share still there")
MW:PaintShare()
check(share.mine:GetAlpha() < 1, "and the dialog's")

-- Its window closing takes the dialog with it.
fire(frame, "OnHide")
check(not share:IsShown(), "closing its window closes the dialog")

-- The card on a level up is put away when its window is open.
TA.Window:Toast(23, TA:State(nil, 23, 1))
check(not (TA.Window.toast and TA.Window.toast:IsShown()), "no card over its window when it is open")
frame:Hide()
TA.Window:Toast(23, TA:State(nil, 23, 1))
check(TA.Window.toast:IsShown(), "a card when it isn't")
frame:Show()
tree:Refresh()
check(not TA.Window.toast:IsShown(), "and opening it puts the card away")

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end
print(string.format("TalentModern: %d checks", checks))
if table.getn(failures) == 0 then
	print("All Modern Spellbook checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
