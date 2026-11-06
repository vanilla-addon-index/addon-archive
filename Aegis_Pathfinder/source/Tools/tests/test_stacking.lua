--[[
	Tests for window stacking.

	Every window but the guide sits in the DIALOG strata, which the client
	draws in frame-level order across all of them at once. (The guide is in
	MEDIUM, with the quest log and bags, so that clicking one of those brings
	it over the guide; in DIALOG the guide covered them whatever you clicked.) Two windows built at the
	same level interleave where they overlap -- one's close chip, scrollbar
	and header drawn through the other's body -- which is what the player saw
	with the config panel open over the guide.

	The check that matters is the one the client applies: every frame in the
	window in front must sit above every frame in the window behind it. It is
	run twice, because whether SetFrameLevel drags children along with it is
	not something the 1.12 client documents, and the stacking must not depend
	on it either way.

	Run:  lua5.1 Tools/tests/test_stacking.lua
]]

package.path = "Tools/tests/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

UISpecialFrames = {}
HideUIPanel = function(f) if f and f.Hide then f:Hide() end end
ShowUIPanel = function(f) if f and f.Show then f:Show() end end
PlaySound = function() end
GameTooltip_Hide = function() end
GetNumQuestLeaderBoards = function() return 0 end
GetQuestLogLeaderBoard = function() return nil end
UnitRaceBase = function() return "Human" end

local L = setmetatable({ PART_FIND = "^(.-)@", PART_GSUB = "@.*$" },
	{ __index = function(_, k) return k end })

AegisPathfinder = {
	Locale = L,
	guides = {}, guidelist = {}, qsplusguides = {},
	actions = { "ACCEPT", "COMPLETE" }, quests = { "A@1@", "B@2@" }, tags = {}, turnedin = {},
	current = 1, myfaction = "Alliance",
	db = {
		char = {
			currentguide = "Elwynn Forest (1-12)",
			routepack = "VanillaGuide", currentroute = "Human",
			PlayStyle = "SOLO", UseAH = false, Dungeons = {},
			waypointprovider = "auto",
		},
		profile = {},
	},
	routepacks = {
		VanillaGuide = {
			name = "VanillaGuide", displayName = "Optimized", description = "",
			routes = { Human = { { zone = "Elwynn Forest", levels = "1-10", guide = "E" } } },
		},
	},
}
function AegisPathfinder:Debug() end
function AegisPathfinder:Print() end
function AegisPathfinder.trim(s) return (string.gsub(s or "", "^%s*(.-)%s*$", "%1")) end
function AegisPathfinder.select(index, ...)
	if index == "#" then return table.getn(arg) end
	return arg[index]
end
function AegisPathfinder.GetQuadrant() return "TOPRIGHT", "TOP", "RIGHT" end
function AegisPathfinder:IsTemplateGuide() return false end
function AegisPathfinder:GuideBadge() return "xp", "XP" end
function AegisPathfinder:GoToObjective() end
function AegisPathfinder:GoToPreviousObjective() end
function AegisPathfinder:SkipToNextObjective() end
function AegisPathfinder:SetTurnedIn() end
function AegisPathfinder:UpdateStatusFrame() end
function AegisPathfinder:ToggleMaterialsPanel() end
function AegisPathfinder:GuideHasMaterials() return false end
function AegisPathfinder:IsAutoDetectable() return false end
function AegisPathfinder:GetObjectiveInfo(i) return self.actions[i], self.quests[i], self.quests[i] end
function AegisPathfinder:GetObjectiveStatus() return nil end
function AegisPathfinder:GetObjectiveTag() return nil end
function AegisPathfinder:GetStepMeta() return nil, nil, false end
function AegisPathfinder:EnsureTabs()
	self.db.char.tabs = self.db.char.tabs or { { guide = self.db.char.currentguide, step = 1 } }
	return self.db.char.tabs
end
function AegisPathfinder:GetActiveTab() return self:EnsureTabs()[1], 1 end
function AegisPathfinder:HasNoGuide() return false end
function AegisPathfinder:SwitchToTab() end
function AegisPathfinder:CloseTab() end
function AegisPathfinder:GetRouteForRace() return "Human" end
function AegisPathfinder:GetAvailableRoutePacks() return { self.routepacks.VanillaGuide } end
function AegisPathfinder:SelectRoutePack() end
function AegisPathfinder:SelectRoute() end
function AegisPathfinder:GetWaypointProviders() return {} end
function AegisPathfinder:GetGuideDungeons() return {} end
function AegisPathfinder:LoadGuide() end
function AegisPathfinder:UpdateNavCallout() end

AegisPathfinder.guidelistframe = CreateFrame("Frame", nil, UIParent)

dofile("Theme.lua")
dofile("ObjectivesFrame.lua")
-- The options window carries the Item Score page, the real one.
UnitClass = function() return "Paladin", "PALADIN" end
GetTalentTabInfo = function(tab) return "Holy", "icon", 0 end
dofile("ItemScoreData.lua")
dofile("ItemScore.lua")
dofile("GearFrame.lua")
dofile("OptionsFrame.lua")

local Theme = AegisPathfinder.Theme
AegisPathfinder.icons = setmetatable({}, {
	__index = function(_, action) return Theme.actionIconByName[action] or Theme.actionIcon.N end,
})

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end

-- Every frame in a window, root included.
local function tree(f, out)
	out = out or { f }
	for _, c in ipairs(f.__children) do
		table.insert(out, c)
		tree(c, out)
	end
	return out
end
local function span(f)
	local lo, hi = math.huge, -math.huge
	for _, k in ipairs(tree(f)) do
		local l = k:GetFrameLevel()
		if l < lo then lo = l end
		if l > hi then hi = l end
	end
	return lo, hi
end
-- The client's rule, stated as a check: nothing of `back` may draw over
-- anything of `front`.
local function fullyAbove(front, back)
	local frontLo = span(front)
	local _, backHi = span(back)
	return frontLo > backHi, frontLo, backHi
end
-- And each window keeps its own shape: every child above its parent.
local function wellFormed(f)
	for _, k in ipairs(tree(f)) do
		for _, c in ipairs(k.__children) do
			if c:GetFrameLevel() <= k:GetFrameLevel() then return false end
		end
	end
	return true
end
local function show(w)
	w:Show()
	local h = w.stackWatch and w.stackWatch:GetScript("OnShow")
	if h then h() end
end
local function grab(w)
	local h = w.header:GetScript("OnMouseDown")
	if h then h() end
end

-- Synthetic windows --------------------------------------------------------------

-- Two windows built alike, both at level 1, the way every window in the
-- addon starts: a header, a body, controls in the body, a glyph on a control.
local function Window(label)
	local w = CreateFrame("Frame", nil, UIParent)
	w:SetFrameStrata("DIALOG")
	w:SetWidth(300); w:SetHeight(300)
	Theme:Chrome(w, label)
	local body = CreateFrame("Frame", nil, w)
	local row = CreateFrame("Button", nil, body)
	CreateFrame("Button", nil, row)
	Theme:ScrollBar(body)
	w:Hide()
	return w
end

for _, cascade in ipairs({ false, true }) do
	stub.cascadeLevels = cascade
	local how = cascade and "(client drags children)" or "(client does not)"
	Theme.windows = {}

	local a, b = Window("A"), Window("B")
	check(a:GetFrameLevel() == b:GetFrameLevel(),
		"%s the two start at one level, which is the bug's precondition", how)
	check(Theme:IsWindow(a) and Theme:IsWindow(b), "%s Chrome registers its window", how)
	check(a:IsToplevel(), "%s a window raises itself when clicked anywhere in it", how)

	show(a); show(b)
	local ok, lo, hi = fullyAbove(b, a)
	check(ok, "%s the window opened last draws entirely over the other (lowest %d vs highest %d)",
		how, lo, hi)
	check(wellFormed(a) and wellFormed(b), "%s and each keeps its children above their parents", how)

	grab(a)
	ok, lo, hi = fullyAbove(a, b)
	check(ok, "%s grabbing a window's header brings all of it forward (lowest %d vs highest %d)",
		how, lo, hi)

	-- Swapping back and forth must not ratchet the levels up: the client's
	-- ceiling is low on 1.12.
	for _ = 1, 50 do grab(b); grab(a) end
	local _, top = span(a)
	check(top < 60, "%s levels are rebuilt, not raised, so fifty swaps stay low (top %d)", how, top)
	check(fullyAbove(a, b), "%s and the last grabbed is still in front", how)

	-- A window the client raised on its own -- a click on a row -- is where
	-- it was left the next time something is shown.
	local c = Window("C")
	show(b)
	b:SetFrameLevel(a:GetFrameLevel() + 100)   -- as a toplevel raise might
	show(c)
	check(fullyAbove(c, b) and fullyAbove(b, a),
		"%s showing a third keeps the order the client left the others in", how)

	-- A window that builds a frame after it was stacked -- a row, a list
	-- entry -- must not land on the level of the window above it.
	show(a); show(b)
	local deepest = a
	for _, k in ipairs(tree(a)) do
		if k:GetFrameLevel() > deepest:GetFrameLevel() then deepest = k end
	end
	local late = CreateFrame("Frame", nil, deepest)
	check(late:GetFrameLevel() < span(b),
		"%s a frame created late stays under the window above (%d vs %d)",
		how, late:GetFrameLevel(), span(b))

	-- Hidden windows are not in the way of anything and take no levels.
	a:Hide()
	show(b)
	check(fullyAbove(b, c), "%s a hidden window is skipped", how)
end
stub.cascadeLevels = false

-- The windows in the screenshot ------------------------------------------------------

Theme.windows = {}
local objectives = AegisPathfinder.objectiveframe
Theme:RegisterWindow(objectives)
AegisPathfinder:UpdateObjectivePanel()
AegisPathfinder:CreateConfigPanel()
local options = AegisPathfinder.optionsframe
check(Theme:IsWindow(options), "the config panel is a stacked window")
check(Theme:IsWindow(objectives), "and so is the objectives panel")

show(objectives)
show(options)
local ok, lo, hi = fullyAbove(options, objectives)
check(ok, "config opened over the guide draws entirely over it (lowest %d vs highest %d)", lo, hi)

-- The guide is in MEDIUM with Blizzard's windows; the config panel in DIALOG
-- is drawn over it whatever their levels, so the two cannot interleave.
check(objectives:GetFrameStrata() == "MEDIUM" and options:GetFrameStrata() == "DIALOG",
	"the guide is in MEDIUM with the quest log, the config panel above it in DIALOG")
local before = objectives:GetFrameLevel()
local raised = false
objectives.Raise = function() raised = true end
grab(objectives)
check(objectives:GetFrameLevel() == before and raised,
	"grabbing the guide leaves its level to the client and raises it over the quest log (%d -> %d)",
	before, objectives:GetFrameLevel())
objectives.Raise = nil
ok, lo, hi = fullyAbove(options, objectives)
check(ok, "and does not band the DIALOG windows under it (lowest %d vs highest %d)", lo, hi)
check(wellFormed(objectives) and wellFormed(options), "neither window is flattened by the move")

local _, top = span(objectives)
check(top < 128, "the two real windows fit well inside the client's level range (top %d)", top)

-- Report ---------------------------------------------------------------------

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end

print(string.format("Stacking: %d checks", checks))
if table.getn(failures) == 0 then
	print("All stacking checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
