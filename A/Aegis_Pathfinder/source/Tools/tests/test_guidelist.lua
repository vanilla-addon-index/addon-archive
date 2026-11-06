--[[
	Tests for guide categorisation and the tab/badge widgets behind it.

	Two things here are easy to get silently wrong. Profession guides are named
	"Alchemy (1-300)", which matches none of the name prefixes the categoriser
	keys on, so without an explicit rule they land in with the zone guides.
	And a placeholder guide looks exactly like an authored one in a list, which
	is what the TPL badge is for.

	Run:  lua5.1 Tools/tests/test_guidelist.lua
]]

package.path = "Tools/tests/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

AegisPathfinder = { qsplusguides = {}, db = { char = {}, profile = {} } }
dofile("Theme.lua")

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end

local Theme = AegisPathfinder.Theme

--[[ Categorisation.

	Lifted rather than loaded: Core.lua is 2,400 lines of addon construction
	and pulling it in would test Ace2's stubbing, not this logic. These are the
	two functions under test, kept identical to Core.lua -- if they drift, the
	check at the bottom of this file fails.
]]
-- The zone list itself is read out of Core.lua, so a zone missing there is
-- missing here too.
local TURTLE_ZONES = {}
do
	local src = io.open("Core.lua"):read("*a")
	local _, _, block = string.find(src, "local TURTLE_ZONES = (%b{})")
	for zone in string.gfind(block or "", '%["([^"]+)"%]%s*=%s*true') do TURTLE_ZONES[zone] = true end
end

function AegisPathfinder:IsTemplateGuide(guideName)
	local qsp = self.qsplusguides and self.qsplusguides[guideName]

	return (qsp and qsp.template) and true or false
end

function AegisPathfinder:GetGuideCategory(guideName)
	local qsp = self.qsplusguides and self.qsplusguides[guideName]
	if qsp and qsp.category == "Profession" then
		return "profession"
	end
	if string.find(guideName, "^Dungeons/") then return "dungeon" end
	if string.find(guideName, "^Class/") then return "class" end
	if string.find(guideName, "^Optimized/") then return "optimized" end
	if string.find(guideName, "^RXP/") then return "rxp" end
	if string.find(guideName, "^RXP_Hardcore/") then return "rxp_hc" end
	for zone in pairs(TURTLE_ZONES) do
		if string.find(guideName, zone) then return "turtle" end
	end
	return "zone"
end

AegisPathfinder.qsplusguides["Alchemy (1-300)"] =
	{ category = "Profession", steps = {} }
AegisPathfinder.qsplusguides["Fishing (1-300)"] =
	{ category = "Profession", template = true, steps = {} }

check(AegisPathfinder:GetGuideCategory("Alchemy (1-300)") == "profession",
	"a profession guide must not fall through to the zone category")
check(AegisPathfinder:GetGuideCategory("Fishing (1-300)") == "profession",
	"a profession template is still a profession")
check(AegisPathfinder:GetGuideCategory("Optimized/Darkshore (12-17)") == "optimized",
	"name-prefixed categories still work")
check(AegisPathfinder:GetGuideCategory("RXP/Elwynn Forest (6-11)") == "rxp", "RXP")
check(AegisPathfinder:GetGuideCategory("RXP_Hardcore/Durotar (1-12)") == "rxp_hc", "RXP hardcore")
check(AegisPathfinder:GetGuideCategory("Thalassian Highlands (1-10)") == "turtle",
	"custom zones are detected by zone name")
check(AegisPathfinder:GetGuideCategory("Westfall (12-17)") == "zone",
	"anything else is a zone guide")
check(AegisPathfinder:GetGuideCategory("Dungeons/Uldaman (41-51)") == "dungeon", "a dungeon guide")
check(AegisPathfinder:GetGuideCategory("Dungeons/Gilneas City (38-46)") == "dungeon",
	"a dungeon guide named for a custom zone's dungeon is still a dungeon guide")
check(AegisPathfinder:GetGuideCategory("Class/Warlock: Voidwalker (10)") == "class", "a class quest guide")
check(AegisPathfinder:GetGuideCategory("Class/Hunter: Taming the Beast (10)") == "class",
	"a class quest guide however it is named")

-- A class quest guide has one level, not a range: "(10)" is 10 to 10.
do
	local src = io.open("Core.lua"):read("*a")
	local from = string.find(src, "function AegisPathfinder:ParseGuideLevelRange", 1, true)
	local to = string.find(src, "\nend\n", from, true)
	assert(from and to, "could not find ParseGuideLevelRange in Core.lua")
	assert(loadstring(string.sub(src, from, to + 4)))()
	local lo, hi = AegisPathfinder:ParseGuideLevelRange("Class/Warlock: Voidwalker (10)")
	check(lo == 10 and hi == 10, "Voidwalker (10) is level 10, got %s-%s", tostring(lo), tostring(hi))
	lo, hi = AegisPathfinder:ParseGuideLevelRange("Class/Mage: Level 10 Quest (10)")
	check(lo == 10 and hi == 10, "a number in the name is not the level, got %s-%s", tostring(lo), tostring(hi))
	lo, hi = AegisPathfinder:ParseGuideLevelRange("Dungeons/Uldaman (41-51)")
	check(lo == 41 and hi == 51, "a range is still a range")
	lo, hi = AegisPathfinder:ParseGuideLevelRange("RXP/12-14 Loch Modan")
	check(lo == 12 and hi == 14, "and the bare range RestedXP's names have")
end

-- Every custom zone guide belongs under the Custom tab: the ones the
-- guide list has always had, and the newer Scarlet Enclave and Hyjal, which
-- used to land under Zones.
for _, name in ipairs({ "Thalassian Highlands (1-10)", "Blackstone Island (1-10)", "Northwind (28-34)",
		"Balor (29-34)", "Grim Reaches (33-38)", "Gilneas (39-46)", "Icepoint Rock (44-47)",
		"Lapidis Isle (48-53)", "Gillijim's Isle (48-53)", "Tel'Abim (54-60)",
		"Scarlet Enclave (55-60)", "Hyjal (58-60)", "Moonwhisper Coast (52-60)" }) do
	check(AegisPathfinder:GetGuideCategory(name) == "turtle", "%s belongs under Custom", name)
end
-- Guides/Both holds only custom-zone guides; each of them must be found.
for file in io.popen("ls Guides/Both/*.lua"):lines() do
	local _, _, name = string.find(io.open(file):read("*a"), 'RegisterGuide%("([^"]+)"')
	check(name and AegisPathfinder:GetGuideCategory(name) == "turtle",
		"%s (%s) belongs under Custom", tostring(name), file)
end

check(AegisPathfinder:IsTemplateGuide("Fishing (1-300)") == true,
	"an unauthored guide reports as a template")
check(AegisPathfinder:IsTemplateGuide("Alchemy (1-300)") == false,
	"an authored guide is not a template")
check(AegisPathfinder:IsTemplateGuide("Westfall (12-17)") == false,
	"a guide with no QuestShell+ table is not a template")
check(AegisPathfinder:IsTemplateGuide("No Such Guide") == false,
	"an unknown guide is not a template, and must not error")

-- Tabs -----------------------------------------------------------------------

local tab = Theme:Tab(UIParent, "Professions", 84, 22)
check(tab.label:GetText() == "PROFESSIONS", "tab labels are uppercased, got '%s'",
	tostring(tab.label:GetText()))
check(tab:IsActive() == false, "a new tab starts inactive")
check(tab.fill.center.__color[1] > 0.22 and tab.fill.center.__color[1] < 0.24,
	"an inactive tab sits in the tab-strip colour")

tab:SetActive(true)
check(tab:IsActive() == true, "SetActive registers")
check(tab.fill.center.__color[1] > 0.12 and tab.fill.center.__color[1] < 0.13,
	"an active tab takes the panel colour, so it reads as continuous with the list")
check(tab.label.__color[2] > 0.78, "an active tab's label is accent")

tab:SetActive(false)
check(tab.label.__color[1] > 0.75 and tab.label.__color[2] > 0.75,
	"an inactive tab's label returns to dim")

-- Badges ---------------------------------------------------------------------

local tpl = Theme:Badge(UIParent, "TPL", "tpl")
check(tpl.label:GetText() == "TPL", "badge text, got '%s'", tostring(tpl.label:GetText()))
check(tpl.bg.__color[1] > 0.3 and tpl.bg.__color[1] < 0.35,
	"a TPL badge is grey, not gold -- it marks absence of content, not a feature")
check(tpl.label.__color[1] > 0.9, "TPL text is light on grey")

local xp = Theme:Badge(UIParent, "XP", "xp")
check(xp.bg.__color[1] > 0.88, "an XP badge is gold")
check(xp.label.__color[1] < 0.2, "XP text is dark on gold")
check(xp:GetWidth() >= 22, "a badge has a minimum width so short labels still read")

xp:SetKind("tpl", "TPL")
check(xp.bg.__color[1] < 0.35, "SetKind should switch a badge's appearance")

--[[ What a guide is, on its tab: XP for leveling, PF a profession (a
	crafting route included), DG a dungeon, HC hardcore, TPL a placeholder.
	GuideBadge is lifted from Core.lua as it is. ]]
do
	local src = io.open("Core.lua"):read("*a")
	local from = string.find(src, "function AegisPathfinder:GuideBadge", 1, true)
	local to = string.find(src, "function AegisPathfinder:GetGuideCategory", from, true)
	assert(from and to, "could not find GuideBadge in Core.lua")
	assert(loadstring(string.sub(src, from, to - 1)))()
	AegisPathfinder.qsplusguides["Alchemy (cheapest route)"] = { category = "Profession", planned = true, steps = {} }
	local function badge(name)
		local kind, text = AegisPathfinder:GuideBadge(name)
		return kind .. ":" .. text
	end
	check(badge("Alchemy (1-300)") == "pf:PF", "a profession guide is PF, got %s", badge("Alchemy (1-300)"))
	check(badge("Alchemy (cheapest route)") == "pf:PF", "so is a crafting route")
	check(badge("Fishing (1-300)") == "tpl:TPL", "a placeholder is TPL, whatever it is")
	check(badge("Dungeons/Uldaman (41-51)") == "dg:DG", "a dungeon guide is DG")
	check(badge("Class/Warlock: Voidwalker (10)") == "cl:CL", "a class quest guide is CL")
	check(badge("RXP_Hardcore/Durotar (1-12)") == "hc:HC", "a hardcore guide is HC")
	check(badge("Optimized/Loch Modan (17-18)") == "xp:XP" and badge("RXP/Elwynn Forest (6-11)") == "xp:XP"
		and badge("Thalassian Highlands (1-10)") == "xp:XP", "leveling guides are XP")

	local b = Theme:Badge(UIParent, "XP", "xp")
	b:SetKind("pf", "PF")
	check(b.label:GetText() == "PF" and b.bg.__color[3] > b.bg.__color[1], "PF is blue")
	b:SetKind("dg", "DG")
	check(b.label:GetText() == "DG" and b.bg.__color[3] > b.bg.__color[2] and b.bg.__color[1] > b.bg.__color[2],
		"DG is violet")
	b:SetKind("cl", "CL")
	check(b.label:GetText() == "CL" and b.bg.__color[2] > b.bg.__color[1] and b.bg.__color[3] > b.bg.__color[1],
		"CL is teal")
	b:SetKind("hc", "HC")
	check(b.bg.__color[1] > 0.8 and b.bg.__color[2] < 0.4 and b.label.__color[1] > 0.9, "HC is red, its text light")
	b:SetKind("xp", "XP")
	check(b.bg.__color[1] > 0.88 and b.label.__color[1] < 0.2, "and back to gold")
end

-- Drift check ----------------------------------------------------------------

-- The two functions above are copies. If Core.lua's versions change shape,
-- this catches it rather than letting the copies quietly go stale.
local core = io.open("Core.lua"):read("*a")
check(string.find(core, 'string.find(guideName, "^Dungeons/")', 1, true) ~= nil,
	"Core.lua no longer puts the dungeon guides under Dungeons the way this test assumes")
check(string.find(core, 'string.find(guideName, "^Class/")', 1, true) ~= nil,
	"Core.lua no longer puts the class quest guides under Class the way this test assumes")
check(string.find(core, 'qsp.category == "Profession"', 1, true) ~= nil,
	"Core.lua no longer categorises professions the way this test assumes")
check(string.find(core, "function AegisPathfinder:IsTemplateGuide", 1, true) ~= nil,
	"Core.lua no longer defines IsTemplateGuide")

-- Report ---------------------------------------------------------------------

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end

print(string.format("GuideList: %d checks", checks))
if table.getn(failures) == 0 then
	print("All guide list checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
