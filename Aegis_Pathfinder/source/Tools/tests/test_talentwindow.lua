--[[
	Tests for the Talent Advisor on the talent window (TalentWindow.lua),
	and what it says in chat (TalentAdvisor.lua).

	The client's window is stood in for with the names Blizzard_TalentUI
	1.12.1 has -- TalentFrame, TalentFrameTalent1-20, TalentFrameTab1-5,
	TalentFrame_Update, TalentFrame_OnShow, PanelTemplates_* -- and
	GameTooltip:SetTalent. Once the window has loaded it has to be marked
	after every redraw: the badge with the points the build puts on each
	talent (to take, done, or "+N" off the build), the glow and NEXT on the
	next point's talent and a dot on its tab, the window opening on that
	tree; the strip over it with the build followed, where the next point
	goes and the points off the build -- or why the build is not followed;
	the tooltip's line; nothing at all with the advisor off. In chat: the
	talent to take on a level up, once the chat line is on; your spec's build
	being ready at 60, once; a build that doesn't fit, once a session.

	Run:  lua5.1 Tools/tests/test_talentwindow.lua
]]

package.path = "Tools/tests/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

local said, printed = {}, {}
AegisPathfinder = { db = { char = {}, profile = {} } }
local A = AegisPathfinder
function A:Print(msg) table.insert(printed, msg) end
function A:Say(msg) table.insert(said, msg) end
local refreshedOptions = 0
function A:RefreshConfigPanel() refreshedOptions = refreshedOptions + 1 end
A.ItemScore = { Spec = function() return "Fury", "picked" end }

local checks, failures = 0, {}
local function check(cond, msg, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(msg, unpack(arg))) end
end

-- Fire a script the way the client does: with `this`, `event` and `arg1` set.
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
local current = { trees = TREES.WARRIOR, ranks = {}, unspent = 0, level = 22 }
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

-- Where each talent is: tree and index.
local function Find(name)
	for t, tree in ipairs(current.trees) do
		for i, x in ipairs(tree.talents) do
			if x[1] == name then return t, i end
		end
	end
end

-- The client's tooltip: what SetTalent was asked, and the lines after.
local tipAsked, tipLines = {}, {}
GameTooltip.SetTalent = function(self, tab, index) table.insert(tipAsked, { tab, index }); tipLines = {} end
GameTooltip.AddLine = function(self, text, r, g, b) table.insert(tipLines, { text = text, r = r, g = g, b = b }) end

dofile("Theme.lua")
dofile("TalentBuilds.lua")
dofile("TalentAdvisor.lua")
dofile("TalentWindow.lua")
local TA = A.TalentAdvisor
local TW = TA.Window
local Theme = A.Theme

local points = TA.Points(A.TalentBuilds.WARRIOR.levelling)
local function After(n)
	local r = {}
	for k = 1, n do r[points[k]] = (r[points[k]] or 0) + 1 end
	return r
end

-- The talent window ------------------------------------------------------------

check(TW and not TW.hooked, "nothing is hooked before the talent window loads")

-- Blizzard_TalentUI, as it loads.
MAX_NUM_TALENTS, MAX_TALENT_TABS = 20, 5
PanelTemplates_GetSelectedTab = function(f) return f.selectedTab end
PanelTemplates_SetTab = function(f, id) f.selectedTab = id end
local drawn = 0
CreateFrame("Frame", "TalentFrame", UIParent)
TalentFrame:Hide()
TalentFrame.selectedTab = 1
for i = 1, MAX_NUM_TALENTS do
	local b = CreateFrame("Button", "TalentFrameTalent" .. i, TalentFrame)
	b:SetID(i)
end
for i = 1, MAX_TALENT_TABS do
	local tab = CreateFrame("Button", "TalentFrameTab" .. i, TalentFrame)
	tab:SetID(i)
	_G["TalentFrameTab" .. i .. "Text"] = tab:CreateFontString(nil, "OVERLAY")
end
function TalentFrame_Update()
	drawn = drawn + 1
	local n = GetNumTalents(TalentFrame.selectedTab)
	for i = 1, MAX_NUM_TALENTS do
		if i <= n then getglobal("TalentFrameTalent" .. i):Show() else getglobal("TalentFrameTalent" .. i):Hide() end
	end
end
function TalentFrame_OnShow() TalentFrame_Update() end
local function Open()
	TalentFrame:Show()
	TalentFrame_OnShow()   -- the frame's OnShow script calls it by name
end
local function Button(name)
	local t, i = Find(name)
	return getglobal("TalentFrameTalent" .. i), t
end
local function Marks(name)
	local b = Button(name)
	return b.apMarks
end

fire(TW.events, "OnEvent", "ADDON_LOADED", "SomeOtherAddon")
check(not TW.hooked, "another addon loading hooks nothing")
fire(TW.events, "OnEvent", "ADDON_LOADED", "Blizzard_TalentUI")
check(TW.hooked and TW.strip and not TW.strip:IsShown(), "Blizzard_TalentUI loading hooks the window, its strip hidden")

-- A level 22 warrior, the build's first 12 points spent, one to spend: the
-- 13th is Deep Wounds' third rank, in Arms.
current.level, current.unspent, current.ranks = 22, 1, After(12)
TalentFrame.selectedTab = 2
Open()
check(TalentFrame.selectedTab == 1, "the window opens on Arms, where the next point goes")
local strip = TW.strip
check(strip:IsShown() and strip:GetParent() == TalentFrame, "the strip shows, on the window")
check(strip.card:IsShown() and strip.card.title:GetText() == "Take Deep Wounds"
	and strip.card.detail:GetText() == "Rank 3 of 3 in Arms · 1 point to spend",
	"its card says where the next point goes, got %s / %s", tostring(strip.card.title:GetText()),
	tostring(strip.card.detail:GetText()))
check(strip.card.icon:GetTexture() == "icon" and strip.note:GetText() == "", "with the talent's icon, and no line besides")
check(strip.warn:GetText() == "", "nothing off the build")
check(strip.drop:GetValue() == "auto" and strip.drop.label:GetText() == "Leveling, then Fury at 60",
	"following levelling, then Fury, got %s", tostring(strip.drop.label:GetText()))
local _, rel = strip:GetPoint(1)
check(rel == TalentFrame, "over the window's own frame")

local deep = Marks("Deep Wounds")
check(deep and deep:IsShown() and deep.badge:IsShown() and deep.badge.text:GetText() == "3",
	"Deep Wounds has its badge: the build puts 3 there")
check(deep.glow:IsShown() and deep.tag:IsShown(), "and the glow and NEXT: the next point goes there")
local _, _, _, _, tagY = deep.tag:GetPoint(1)
check(tagY == TW.G.NEXT_LIFT and tagY >= TW.G.BADGE_H / 2, "NEXT sits clear of the badge at the talent's top right")
local r, g, b = deep.badge.text:GetTextColor()
local c = TW.G.ON_ACCENT
check(r == c[1] and g == c[2] and b == c[3], "points still to take: dark on the accent")
r, g, b = deep.glow:GetVertexColor()
check(r == 1 and g == TW.G.GOLD[2] and b == 0, "the ring is gold")
local ihs = Marks("Improved Heroic Strike")
check(ihs.badge:IsShown() and not ihs.glow:IsShown(), "Improved Heroic Strike has its badge, not the ring")
check(ihs.badge.tick:IsShown() and not ihs.badge.text:IsShown(), "all taken: a tick, not a number")
check(not Marks("Improved Thunder Clap").badge:IsShown(), "a talent the build leaves alone has no badge")
check(TalentFrameTab1.apDot:IsShown() and not TalentFrameTab2.apDot:IsShown() and not TalentFrameTab3.apDot:IsShown(),
	"Arms' tab has the dot")
check(TalentFrameTab1.apLit:IsShown() and not TalentFrameTab2.apLit:IsShown(), "and is lit gold")

-- Another tree: its talents marked, no glow, the dot still on Arms.
PanelTemplates_SetTab(TalentFrame, 2)
TalentFrame_Update()
local cruelty = Marks("Cruelty")
check(cruelty:IsShown() and cruelty.badge.text:GetText() == "5" and not cruelty.glow:IsShown(),
	"on Fury: Cruelty, 5 to come, not next")
check(TalentFrameTab1.apDot:IsShown(), "and the dot stays on Arms")
local hidden = getglobal("TalentFrameTalent20")
check(not hidden:IsShown() and not (hidden.apMarks and hidden.apMarks.badge:IsShown()),
	"a button the tree doesn't use has no badge")

-- Points off the build, at 29: two in Improved Thunder Clap.
current.level, current.unspent = 29, 1
current.ranks = After(18)
current.ranks["Improved Thunder Clap"] = 2
PanelTemplates_SetTab(TalentFrame, 1)
TalentFrame_Update()
local itc = Marks("Improved Thunder Clap")
check(itc.badge:IsShown() and itc.badge.text:GetText() == "+2", "Improved Thunder Clap: +2, off the build")
r, g, b = itc.badge.text:GetTextColor()
check(r < 0.2 and g < 0.2 and b < 0.2, "dark text on amber")
check(strip.warn:GetText() == "2 points off the build. It carries on from the closest point.",
	"the strip counts them, got %s", tostring(strip.warn:GetText()))
check(strip.card.title:GetText() == "Take Impale", "and carries on: Impale, got %s", tostring(strip.card.title:GetText()))
check(Marks("Impale").glow:IsShown(), "the glow on Impale")

-- No point to spend: where the next level's goes.
current.unspent = 0
TalentFrame_Update()
check(strip.card.title:GetText() == "Next: Impale" and strip.card.detail:GetText() == "Rank 1 of 2 in Arms · at level 30",
	"no point to spend, got %s / %s", tostring(strip.card.title:GetText()), tostring(strip.card.detail:GetText()))

-- The tooltip.
current.unspent = 1
local t, i = Find("Impale")
GameTooltip:SetTalent(t, i)
check(tipAsked[1] and tipAsked[1][1] == t and tipAsked[1][2] == i, "the client's tooltip is still shown")
local texts = {}
for _, l in ipairs(tipLines) do table.insert(texts, l.text) end
check(table.concat(texts, "|") == " |Pathfinder: Warrior leveling puts 2 points here.|Your next point goes here.",
	"then the advisor's lines, got %s", table.concat(texts, "|"))
c = Theme.color.accentGlow
check(tipLines[2] and tipLines[2].r == c[1] and tipLines[2].g == c[2], "in the theme's colour")
t, i = Find("Improved Thunder Clap")
GameTooltip:SetTalent(t, i)
check(tipLines[2] and tipLines[2].text == "Pathfinder: Warrior leveling puts no points here.",
	"a talent off the build says so")
t, i = Find("Improved Heroic Strike")
GameTooltip:SetTalent(t, i)
check(tipLines[2] and tipLines[2].text == "Pathfinder: Warrior leveling puts 3 points here: done.", "and one done")
t, i = Find("Piercing Howl")
GameTooltip:SetTalent(t, i)
check(table.getn(tipLines) == 0, "a talent the build leaves alone adds nothing")

-- The advisor off: nothing on the window or the tooltip.
A.db.char.talentadvisor = false
local before = drawn
TA:Refresh()
check(drawn == before + 1, "switching it off draws the window again")
check(not strip:IsShown() and not Marks("Impale"):IsShown(), "no strip and no marks with the advisor off")
check(not TalentFrameTab1.apDot:IsShown(), "and no dot")
t, i = Find("Impale")
GameTooltip:SetTalent(t, i)
check(table.getn(tipLines) == 0, "nor a tooltip line")
A.db.char.talentadvisor = true
TA:Refresh()
check(strip:IsShown() and Marks("Impale").glow:IsShown(), "on again")

-- Picking another build from the strip: the options' setting.
local order = {}
for _, item in ipairs(strip.drop.items) do table.insert(order, item.value) end
check(table.concat(order, ",") == "auto,auto:Protection,levelling,levelling:Protection,Arms,Fury,Protection",
	"the menu: auto, then Protection, the levelling builds and each spec, got %s", table.concat(order, ","))
check(strip.drop.items[2].label == "Protection leveling, then Fury at 60"
	and strip.drop.items[4].label == "Warrior Protection leveling", "Protection leveling named both ways, got %s / %s",
	strip.drop.items[2].label, strip.drop.items[4].label)
check(strip.drop.items[6].label == "Fury at 60 (my spec)", "your spec marked")
refreshedOptions = 0
fire(strip.drop.rows[7], "OnClick")
check(A.db.char.talentbuild == "Protection" and refreshedOptions == 1, "picking Protection follows it, the options too")
check(strip.drop.label:GetText() == "Protection at 60", "the strip names it")
PanelTemplates_SetTab(TalentFrame, 3)
TalentFrame_Update()
check(Marks("Shield Specialization").badge:IsShown(), "and marks Protection's talents")
A.db.char.talentbuild = "auto"

-- pfUI's skin: over its backdrop of the window.
TalentFrame.backdrop = CreateFrame("Frame", nil, TalentFrame)
TalentFrame_Update()
_, rel = strip:GetPoint(1)
check(rel == TalentFrame.backdrop, "with pfUI, over its backdrop")
TalentFrame.backdrop = nil

-- At 60 with all 51 on the levelling build.
current.level, current.unspent, current.ranks = 60, 0, After(51)
TalentFrame_Update()
check(not strip.card:IsShown() and strip.note:GetText() == "All 51 points spent. Your Fury build is ready for when you respec.",
	"at 60: your spec's build is ready, got %s", tostring(strip.note:GetText()))
check(strip.drop.label:GetText() == "Leveling (done), then Fury", "the menu says so, got %s",
	tostring(strip.drop.label:GetText()))
-- After a respec: Fury's build.
current.ranks, current.unspent = {}, 51
TalentFrame_Update()
check(strip.drop.label:GetText() == "Fury, my spec" and string.find(strip.card.title:GetText(), "^Take "),
	"after a respec: Fury's, from its first point, got %s", tostring(strip.drop.label:GetText()))

-- A tree the build doesn't fit: why, and no marks.
local saved = current.trees
local changed = {}
for _, tree in ipairs(TREES.WARRIOR) do
	local talents = {}
	for _, x in ipairs(tree.talents) do
		if x[1] ~= "Master Strike" then table.insert(talents, x) end
	end
	table.insert(changed, { name = tree.name, talents = talents })
end
current.trees, current.level, current.unspent, current.ranks = changed, 22, 1, {}
TA.fit = {}
PanelTemplates_SetTab(TalentFrame, 1)
TalentFrame_Update()
check(strip:IsShown() and strip.note:GetText() == "" and strip.warn:GetText() == "The Warrior leveling build doesn't "
	.. "fit your talent tree (it has no Master Strike), so the Talent Advisor won't follow it.",
	"the strip says why, got %s", tostring(strip.warn:GetText()))
check(not Marks("Improved Heroic Strike"):IsShown() and not TalentFrameTab1.apDot:IsShown(), "and marks nothing")

-- In chat ---------------------------------------------------------------------

-- A level up: the talent to take.
said, printed = {}, {}
current.trees, current.ranks, current.unspent = saved, After(12), 0
TA.fit, TA.warned = {}, {}
fire(TA.events, "OnEvent", "PLAYER_LEVEL_UP", "22")
check(said[1] == "Level 22: a talent point to spend. Take Deep Wounds (rank 3 of 3) in Arms.",
	"level 22: Deep Wounds, got %s", tostring(said[1]))
A.db.char.talentchat = false
TA:LevelUp(22)
check(table.getn(said) == 1, "not with the chat line off")
A.db.char.talentchat = true
TA:LevelUp(9)
check(table.getn(said) == 1, "nothing before 10")
A.db.char.talentadvisor = false
TA:LevelUp(22)
check(table.getn(said) == 1, "nothing with the advisor off")
A.db.char.talentadvisor = true

-- A build that doesn't fit: said once, as a warning.
current.trees = changed
TA.fit = {}
TA:LevelUp(23)
TA:LevelUp(24)
check(table.getn(printed) == 1 and string.find(printed[1], "doesn't fit your talent tree (it has no Master Strike)", 1, true),
	"a build that doesn't fit is said once, got %d", table.getn(printed))
check(table.getn(said) == 1, "and no talent named")
current.trees = saved
TA.fit = {}

-- At 60, the last point spent on the levelling build: Fury's is ready, once.
said = {}
current.level, current.unspent, current.ranks = 60, 0, After(51)
fire(TA.events, "OnEvent", "CHARACTER_POINTS_CHANGED", "-1")
check(said[1] == TA.ReadyLine("Fury"), "all 51 spent: Fury's build is ready, got %s", tostring(said[1]))
TA:PointsChanged()
check(table.getn(said) == 1, "said once")
current.ranks, current.unspent = {}, 51
TA:PointsChanged()
current.ranks, current.unspent = After(51), 0
TA:PointsChanged()
check(table.getn(said) == 2, "a respec, and the levelling build again: said again")
current.ranks = After(50)
current.unspent = 1
said = {}
TA:PointsChanged()
check(table.getn(said) == 0, "not before the last point")

-- Off the window: the card on a level up, and the talents button lit.
local toggled = 0
ToggleTalentFrame = function() toggled = toggled + 1 end
CreateFrame("Button", "TalentMicroButton", UIParent)
TalentMicroButton:SetWidth(28); TalentMicroButton:SetHeight(58)
GetTime = function() return 100 end
TalentFrame:Hide()
current.level, current.unspent, current.ranks = 22, 1, After(12)
TA.fit = {}
TA:LevelUp(22)
local toast = TW.toast
check(toast and toast:IsShown() and toast.title:GetText() == "Level 22: a talent point"
	and toast.line:GetText() == "Take Deep Wounds (rank 3 of 3) in Arms.",
	"a level up puts up the card, got %s / %s", toast and tostring(toast.title:GetText()) or "none",
	toast and tostring(toast.line:GetText()) or "")
check(toast.icon:GetTexture() == "icon", "with the talent's icon")
fire(toast.later, "OnClick")
check(not toast:IsShown(), "Later puts it away")
TA:LevelUp(22)
fire(toast.open, "OnClick")
check(not toast:IsShown() and toggled == 1, "Open talents opens the window and puts the card away")
A.db.char.talentnudge = false
TA:LevelUp(22)
check(not toast:IsShown(), "no card with pointing out switched off")
A.db.char.talentnudge = nil
TalentFrame:Show()
TA:LevelUp(22)
check(not toast:IsShown(), "nor with the talent window already open")
TA:LevelUp(22)
TalentFrame_Update()
check(not toast:IsShown(), "and opening it puts the card away")
TalentFrame:Hide()
GetTime = function() return 100 + TW.G.TOAST_SHOWS + 1 end
toast:Show()
fire(toast, "OnUpdate")
check(not toast:IsShown(), "it goes by itself after a while")

fire(TA.events, "OnEvent", "CHARACTER_POINTS_CHANGED", "-1")
check(TalentMicroButton.apGlow:IsShown() and TalentMicroButton.apCount:IsShown()
	and TalentMicroButton.apCount.text:GetText() == "1", "a point to spend lights the talents button, with 1 on it")
current.unspent = 0
fire(TA.events, "OnEvent", "CHARACTER_POINTS_CHANGED", "-1")
check(not TalentMicroButton.apGlow:IsShown() and not TalentMicroButton.apCount:IsShown(), "spent, it goes out")
current.unspent = 2
A.db.char.talentnudge = false
fire(TA.events, "OnEvent", "PLAYER_ENTERING_WORLD")
check(not TalentMicroButton.apGlow:IsShown(), "not lit with pointing out switched off")
A.db.char.talentnudge = nil
fire(TA.events, "OnEvent", "PLAYER_ENTERING_WORLD")
check(TalentMicroButton.apCount.text:GetText() == "2", "two to spend: 2")

-- Opening the window from the options.
toggled = 0
printed = {}
current.level = 5
TA:OpenWindow()
check(toggled == 0 and printed[1] == "Talents come at level 10.", "before 10 it says when talents come")
current.level = 20
TA:OpenWindow()
check(toggled == 1, "from 10 it opens the window")

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end
print(string.format("TalentWindow: %d checks", checks))
if table.getn(failures) == 0 then
	print("All talent window checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
