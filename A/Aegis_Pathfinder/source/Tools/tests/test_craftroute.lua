--[[
	Tests for the crafting route window and loading a route as a guide
	(CraftRouteFrame.lua).

	A planned guide has to be as usable as an authored one: every trainer
	and rank step still there, each where your skill cap runs out, the
	crafts in between contiguous and self-completing on your skill. The
	window has to show the plan it would load, re-plan only when something
	it depends on changed, and say plainly where its prices come from and
	what has none.

	Run:  lua5.1 Tools/tests/test_craftroute.lua
]]

package.path = "Tools/tests/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

UISpecialFrames = {}
local clock = 1000000
time = function() return clock end
GetTime = function() return 100 end
date = function() return "26 Sep" end

-- The character's professions.
local skills = { { "Alchemy", 1 }, { "Cooking", 1 } }
GetNumSkillLines = function() return table.getn(skills) end
GetSkillLineInfo = function(i)
	local s = skills[i]
	return s[1], nil, nil, s[2], nil, nil, 300
end

local printed, opened, loaded, switched = {}, {}, {}, {}
local activeTab, tabs = 1, {}
AegisPathfinder = {
	guides = {}, guidelist = {}, nextzones = {},
	myfaction = "Alliance",
	db = { char = {}, realm = {}, profile = {} },
}
local A = AegisPathfinder
function A:Debug() end
function A:Print(msg) table.insert(printed, msg) end
function A.trim(s) return (string.gsub(s or "", "^%s*(.-)%s*$", "%1")) end
function A:RegisterGuide(name, nextzone, faction, loader)
	if not self.guides[name] then table.insert(self.guidelist, name) end
	self.guides[name] = loader
end
function A:GetGuideCategory(name)
	local g = self.qsplusguides and self.qsplusguides[name]
	return (g and g.category == "Profession") and "profession" or "zone"
end
function A:FindTab(name) return tabs[name] end
function A:OpenGuideTab(name) table.insert(opened, name) end
function A:SwitchToTab(i) table.insert(switched, i) end
function A:LoadGuide(name) table.insert(loaded, name) end
function A:UpdateStatusFrame() end

dofile("Theme.lua")
dofile("QuestShellPlusParser.lua")
dofile("Professions.lua")
dofile("CraftPlanner.lua")
dofile("CraftScan.lua")
dofile("CraftRouteFrame.lua")
for _, f in ipairs({ "Alchemy", "Blacksmithing", "Cooking", "Enchanting", "Engineering",
	"Jewelcrafting", "Leatherworking", "Survival", "Tailoring", "Prices" }) do
	dofile("Crafting/" .. f .. ".lua")
end
dofile("Guides/Professions/Alchemy.lua")
dofile("Guides/Professions/Cooking.lua")
local Theme = A.Theme

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, unpack(arg))) end
end
local function lastPrint() return printed[table.getn(printed)] or "" end
-- Handlers read the frame from the `this` global, as on the client.
local function run(f, script) this = f; f:GetScript(script)() end

-- A market for everything: three times what a merchant pays, or a flat price.
local marketOn = true
function A:GetAuctionQuote(item)
	if not marketOn then return nil end
	local sell = self:MerchantSellPrice(item)
	if sell and sell > 0 then return { t = clock, p = { sell * 3, 5, sell * 4, 10, sell * 6, 50 } } end
	return { t = clock, p = { 500, 20, 900, 100 } }
end

-- Money ------------------------------------------------------------------------

local M = A.FormatCopper
check(M(0) == "0c" and M(7) == "7c", "copper alone")
check(M(1234) == "12s 34c", "silver and copper: %s", M(1234))
check(M(123456) == "12g 34s 56c", "gold, silver and copper: %s", M(123456))
check(M(1000500) == "100g 5s", "past a hundred gold the copper goes: %s", M(1000500))
check(M(-250) == "-2s 50c", "negative: %s", M(-250))
check(M(99.6) == "1s", "rounded to the copper, and zero units left out: %s", M(99.6))
check(M(30005) == "3g 5c", "a zero in the middle is left out: %s", M(30005))
check(M(1000099) == "100g", "past a hundred gold, copper and all: %s", M(1000099))
check(M(nil) == "?", "unknown")

-- Which profession -------------------------------------------------------------

check(A:GuideProfession("Alchemy (1-300)") == "Alchemy", "an authored profession guide")
check(A:GuideProfession("Alchemy (cheapest route)") == nil, "a planned guide not registered yet is not a profession guide")
check(A:GuideProfession("Elwynn Forest (1-12)") == nil, "a zone guide is not")
A.db.char.currentguide = "Cooking (1-300)"
check(A:DefaultCraftProfession() == "Cooking", "the window opens on the guide you are reading")
A.db.char.currentguide = "Elwynn Forest (1-12)"
A.db.char.craftprofession = "Tailoring"
check(A:DefaultCraftProfession() == "Tailoring", "else the last one planned")
A.db.char.craftprofession = nil
check(A:DefaultCraftProfession() == "Alchemy", "else the first you have")

-- The guide --------------------------------------------------------------------

local route = A:PlanCraftRoute("Alchemy", 1, 300, { known = {} })
check(route and route.reached == 300, "an Alchemy route to 300")
local guide = A:BuildCraftGuide(route)
check(guide.category == "Profession" and guide.planned and guide.faction == "Both", "a profession guide, marked as planned")

local steps = guide.steps
check(steps[1].type == "NOTE" and string.find(steps[1].note, route.crafts .. " crafts", 1, true)
	and string.find(steps[1].note, "26 Sep", 1, true), "it opens with what the plan is and when it was made")
local titles = {}
for _, s in ipairs(steps) do titles[s.title] = true end
check(not titles["Before you start"], "the authored guide's own introduction is not carried over")

-- Craft steps: contiguous, from where the route starts to where it ends.
local crafts, prev, contiguous, craftTotal = {}, nil, true, 0
for i, s in ipairs(steps) do
	if s.skill then
		table.insert(crafts, i)
		if prev and s.skill.from ~= prev then contiguous = false end
		prev = s.skill.to
		craftTotal = craftTotal + s.craft.count
		check(s.type == "USE" and s.skill.profession == "Alchemy", "a craft step completes on Alchemy skill")
		check(string.find(s.title, "^Craft " .. s.craft.count .. "x ") ~= nil, "titled by its count: %s", s.title)
		check(s.reagents and table.getn(s.reagents) > 0, "and lists its reagents")
	end
end
check(contiguous and steps[crafts[1]].skill.from == 1 and prev == 300, "crafts run from 1 to 300 without a gap")
check(craftTotal >= route.crafts, "splitting at the ranks keeps every craft (%d of %d)", craftTotal, route.crafts)
local _, alchemyByName = A:GetRecipeBook("Alchemy")
local countsRight = true
for _, i in ipairs(crafts) do
	local s = steps[i]
	local e = 0
	for k = s.skill.from, s.skill.to - 1 do e = e + 1 / A:CraftSkillChance(alchemyByName[s.craft.item], k) end
	if s.craft.count ~= math.ceil(e - 1e-6) then countsRight = false end
end
check(countsRight, "a craft step split at a rank counts the crafts for its own stretch")

-- Every rank step, where the cap runs out.
local function IndexOf(pred)
	for i, s in ipairs(steps) do if pred(s) then return i end end
end
local function RankAt(cap)
	return IndexOf(function(s) return s.rank and s.rank.cap == cap end)
end
local function CraftEndingAt(skill)
	return IndexOf(function(s) return s.skill and s.skill.to == skill end)
end
local function CraftStartingAt(skill)
	return IndexOf(function(s) return s.skill and s.skill.from == skill end)
end
check(RankAt(75) and RankAt(75) < crafts[1], "Apprentice comes before the first craft")
for _, cap in ipairs({ 150, 225, 300 }) do
	local rank, before, after = RankAt(cap), CraftEndingAt(cap - 75), CraftStartingAt(cap - 75)
	check(rank and before and after and before < rank and rank < after,
		"the rank to %d sits between the crafts to %d and from %d", cap, cap - 75, cap - 75)
end
local level10 = IndexOf(function(s) return s.level == 10 end)
check(level10 and level10 < RankAt(150), "the level a rank needs comes before it")
local alliance, horde = 0, 0
for _, s in ipairs(steps) do
	if s.rank and s.rank.cap == 150 then
		if s.faction == "Alliance" then alliance = alliance + 1 elseif s.faction == "Horde" then horde = horde + 1 end
	end
end
check(alliance == 1 and horde == 1, "both factions' trainers are kept; the parser picks yours")

-- A trainer recipe you do not know sends you to your trainers.
local withNpcs, trainerCrafts = 0, 0
for _, s in ipairs(steps) do
	if s.skill then
		local _, byName = A:GetRecipeBook("Alchemy")
		if byName[s.craft.item].learn == "trainer" then
			trainerCrafts = trainerCrafts + 1
			if s.npcs and table.getn(s.npcs) > 0 then withNpcs = withNpcs + 1 end
		end
	end
end
check(trainerCrafts > 0 and withNpcs == trainerCrafts, "trainer crafts carry the trainers (%d of %d)", withNpcs, trainerCrafts)
local horded = false
for _, s in ipairs(steps) do
	if s.skill and s.npcs then
		for _, n in ipairs(s.npcs) do if n == "Whuut" then horded = true end end
	end
end
check(not horded, "and only your faction's")

-- A recipe you know needs no trainer.
local known = A:GetKnownRecipes("Alchemy")
local firstCraft = steps[crafts[1]].craft.item
known[firstCraft] = true
guide = A:BuildCraftGuide(route)
for _, s in ipairs(guide.steps) do
	if s.skill and s.craft.item == firstCraft then
		check(s.npcs == nil and string.find(s.note, "You know this recipe", 1, true), "a known recipe needs no trainer")
		break
	end
end
known[firstCraft] = nil

-- The parser reads it as any other guide: craft steps become SKILL steps.
local actions, quests, tags = A:ParseQuestShellPlus(guide)
local skillTags, rankTags = 0, 0
for i, t in ipairs(tags) do
	if string.find(t, "|SKILL|Alchemy ", 1, true) then skillTags = skillTags + 1 end
	if string.find(t, "|RANK|Alchemy 150|", 1, true) then rankTags = rankTags + 1 end
end
check(skillTags == table.getn(crafts), "every craft is a SKILL step once parsed (%d)", skillTags)
check(rankTags == 1, "and only the Alliance Journeyman step survives the faction filter (%d)", rankTags)

-- Part-way: the ranks you already have come first and clear themselves.
local mid = A:PlanCraftRoute("Alchemy", 120, 300, { known = {} })
local midGuide = A:BuildCraftGuide(mid)
steps = midGuide.steps
local firstMid
for i, s in ipairs(steps) do if s.skill then firstMid = i break end end
check(RankAt(75) < firstMid and RankAt(150) < firstMid, "ranks below where you are come before the first craft")
check(steps[firstMid].skill.from == 120, "which starts at 120")
local e150 = RankAt(225)
check(CraftEndingAt(150) < e150 and e150 < CraftStartingAt(150), "Expert still sits at 150")

-- Cooking: the Expert cookbook at 150, the Artisan quest at 225.
local cook = A:PlanCraftRoute("Cooking", 1, 300, { known = {} })
steps = A:BuildCraftGuide(cook).steps
local book = IndexOf(function(s) return s.type == "BUY" and s.rank and s.rank.cap == 225 end)
check(book and CraftEndingAt(150) < book and book < CraftStartingAt(150), "the Expert cookbook at 150")
local level40 = IndexOf(function(s) return s.level == 40 end)
local artisan = RankAt(300)
check(level40 and artisan and CraftEndingAt(225) < level40 and level40 < artisan and artisan < CraftStartingAt(225),
	"the Artisan quest, level 40 first, at 225")
check(steps[table.getn(steps)].title == "Guide Complete", "the authored ending stays at the end")

-- A route that stops short says so.
A:RegisterRecipeBook("Shortcraft", { "Only = Herb @ 1-20-25-30 | trainer 0" })
local short = A:PlanCraftRoute("Shortcraft", 1, 300, { known = {} })
local shortGuide = A:BuildCraftGuide(short)
check(shortGuide.steps[table.getn(shortGuide.steps)].title == "Where the route stops", "a short route says where it stops")

-- Loading and keeping it ------------------------------------------------------------

check(A:LoadCraftGuide(route), "the route loads")
check(A.guides["Alchemy (cheapest route)"] and A.qsplusguides["Alchemy (cheapest route)"].planned,
	"registered as Alchemy (cheapest route)")
check(opened[1] == "Alchemy (cheapest route)", "and opened in a tab")
check(A.db.char.craftguides.Alchemy and A.db.char.craftguides.Alchemy.steps, "and saved for the next session")
check(string.find(lastPrint(), "Loaded Alchemy (cheapest route)", 1, true), "and the player is told: %s", lastPrint())
check(A:GetGuideCategory("Alchemy (cheapest route)") == "profession", "it lists with the profession guides")
check(A:GuideProfession("Alchemy (cheapest route)") == "Alchemy", "and opens the window on Alchemy")

tabs["Alchemy (cheapest route)"] = 1
activeTab = 1
A.db.char.activetab = 1
local before = table.getn(opened)
A:LoadCraftGuide(route)
check(table.getn(opened) == before and loaded[table.getn(loaded)] == "Alchemy (cheapest route)"
	and table.getn(switched) == 0, "loading again over the open tab rereads it in place")
tabs["Alchemy (cheapest route)"] = 3
A:LoadCraftGuide(route)
check(switched[table.getn(switched)] == 3, "or switches to its tab")
tabs = {}

A.guides, A.guidelist, A.qsplusguides = {}, {}, {}
A:RestoreCraftGuides()
check(A.guides["Alchemy (cheapest route)"] and A.qsplusguides["Alchemy (cheapest route)"].planned,
	"a saved route is registered again next session")
local noRoute = A:LoadCraftGuide({ steps = {} })
check(noRoute == false and string.find(lastPrint(), "no route", 1, true), "nothing to load, nothing loaded")
dofile("Guides/Professions/Alchemy.lua")
dofile("Guides/Professions/Cooking.lua")

-- What to scan ------------------------------------------------------------------------

local items = A:GetCraftScanItems("Alchemy", route)
local position, merchantSold, books = {}, 0, 0
for i, item in ipairs(items) do
	check(not position[item], "%s is listed once", item)
	position[item] = i
	if A:MerchantBuyPrice(item) then merchantSold = merchantSold + 1 end
	if string.find(item, "^Recipe: ") then books = books + 1 end
end
check(merchantSold == 0, "nothing a merchant sells is scanned")
check(not position["Empty Vial"], "not even vials")
check(books > 0, "recipe books are scanned")
local firstReagent = A.CraftReagentName(route.steps[1].recipe.reagents[1])
local routeItems = 0
for _, step in ipairs(route.steps) do
	for _, r in ipairs(step.recipe.reagents) do
		local name = A.CraftReagentName(r)
		if not A:MerchantBuyPrice(name) then routeItems = math.max(routeItems, position[name] or 999) end
	end
end
local distinct = {}
for _, step in ipairs(route.steps) do
	for _, r in ipairs(step.recipe.reagents) do
		local name = A.CraftReagentName(r)
		if not A:MerchantBuyPrice(name) then distinct[name] = true end
	end
	if step.recipe.book then distinct[step.recipe.book] = true end
end
local nDistinct = 0
for _ in pairs(distinct) do nDistinct = nDistinct + 1 end
check(routeItems <= nDistinct, "the route's own items come first (%d within %d)", routeItems, nDistinct)
check(table.getn(items) > nDistinct, "then everything else the profession could use")

-- The window ------------------------------------------------------------------------

local plans = 0
local realPlan = A.PlanCraftRoute
A.PlanCraftRoute = function(self, a, b, c, d) plans = plans + 1 return realPlan(self, a, b, c, d) end

A.db.char.currentguide = "Alchemy (1-300)"
A:ToggleCraftRoutePanel()
local frame = A.craftframe
check(frame and frame:IsShown(), "the window opens")
run(frame, "OnShow")    -- the client runs it on Show; the stub does not
check(frame.pick:GetValue() == "Alchemy", "on the guide's profession")
check(plans == 1, "planned once to open (%d)", plans)
A:UpdateCraftRoutePanel()
A:UpdateCraftRoutePanel()
check(plans == 1, "and not again for a repaint (%d)", plans)

local shown = A:GetCraftPlan()
check(frame.total:GetText() == M(shown.total), "the total: %s", tostring(frame.total:GetText()))
check(frame.crafts:GetText() == shown.crafts .. " crafts", "the crafts: %s", tostring(frame.crafts:GetText()))
check(frame.range:GetText() == "SKILL 1 TO 300", "the range: %s", tostring(frame.range:GetText()))
check(string.find(frame.breakdown:GetText(), "Reagents " .. M(shown.buyTotal), 1, true)
	and string.find(frame.breakdown:GetText(), "recipes " .. M(shown.learnTotal), 1, true),
	"what the total is made of: %s", frame.breakdown:GetText())

local rows = {}
local function Rows()
	rows = {}
	for _, child in ipairs(frame.__children or {}) do
		if child.band and child.mats then table.insert(rows, child) end
	end
	return rows
end
Rows()
check(table.getn(rows) == 8, "eight step rows (%d)", table.getn(rows))
local r1 = rows[1]
local s1 = shown.steps[1]
check(r1.band:GetText() == s1.from .. "-" .. s1.to and r1.name:GetText() == s1.name and r1.count:GetText() == "x" .. s1.crafts,
	"a row: band, recipe, crafts")
check(r1.mats:GetText() == A.CraftReagentLine(s1.recipe) and r1.spend:GetText() == M(s1.spend), "then reagents and spend")
A:ShowCraftStepTip(r1)
check(Theme.tip and Theme.tip:IsShown(), "a row explains itself on hover")

-- Scrolling moves the rows along.
if table.getn(shown.steps) > 8 then
	check(frame.slider:IsShown(), "a long route scrolls")
	frame.slider:SetValue(1)
	check(rows[1].name:GetText() == shown.steps[2].name, "one row down")
	frame.slider:SetValue(0)
end

-- Where the prices come from.
check(frame.status:GetText() == "No auction prices yet: merchant prices only. Scan at the auction house.",
	"no scan and no Exchange: %s", frame.status:GetText())
A.db.realm.craftprices = { Peacebloom = { t = clock - 7200, p = { 10, 1 } } }
AegisExchange = { craft = {} }
A:UpdateCraftRoutePanel()
check(frame.status:GetText() == "Auction prices from your scan 2 h ago and Aegis: Exchange.", "sources: %s", frame.status:GetText())
AegisExchange = nil

-- Selling back, and replanning on change.
run(frame.sell, "OnClick")
check(A.db.char.craftsellback == false and plans == 2, "the switch turns sell-back off and replans")
check(not string.find(frame.breakdown:GetText(), "sold back", 1, true), "nothing is sold back")
run(frame.sell, "OnClick")
check(A.db.char.craftsellback == true, "and on again")

local p0 = plans
A:OnCraftDataChanged(false)
A:UpdateCraftRoutePanel()
check(plans == p0, "scan progress alone does not replan")
A:OnCraftDataChanged(true)
check(frame.dirty, "new prices mark the window stale")
run(frame, "OnUpdate")
check(plans == p0 + 1 and not frame.dirty, "and it replans once, on the next frame")

frame.pick.onSelect("Cooking")
check(frame.pick:GetValue() == "Cooking" and A.db.char.craftprofession == "Cooking", "picking a profession plans it")

-- Unpriced reagents are called out.
marketOn = false
A:OnCraftDataChanged(true)
A:UpdateCraftRoutePanel()
local plan = A:GetCraftPlan()
if plan.lenient and table.getn(plan.unpriced) > 0 then
	check(string.find(frame.status:GetText(), "no price yet", 1, true), "unpriced: %s", frame.status:GetText())
	check(string.find(frame.breakdown:GetText(), "unpriced", 1, true), "and counted in the breakdown")
end
marketOn = true
A:OnCraftDataChanged(true)

-- What merchants pay for the leftovers is said beside the cost, never off it:
-- a Gem that sells for fifty times its Rock still costs its Rocks.
A:RegisterRecipeBook("Profitcraft", { "Gem = Rock @ 1-20-25-30 | trainer 0" })
A:RegisterMerchantPrices({ buy = { Rock = 1 }, sell = { Gem = 50 } })
skills = { { "Profitcraft", 1 } }
frame.pick.onSelect("Profitcraft")
check(not string.find(frame.total:GetText(), "^%+") and not string.find(frame.crafts:GetText(), "pays for itself", 1, true),
	"the total is what the route costs: %s, %s", frame.total:GetText(), frame.crafts:GetText())
check(string.find(frame.breakdown:GetText(), "leftovers sell for about", 1, true),
	"and the leftovers' price is beside it: %s", frame.breakdown:GetText())

-- Nothing to plan.
skills = { { "Profitcraft", 300 } }
A:UpdateCraftRoutePanel()
check(frame.total:GetText() == "" and string.find(frame.breakdown:GetText(), "already 300", 1, true),
	"at the top there is nothing to plan: %s", frame.breakdown:GetText())
local visible = 0
for _, row in ipairs(rows) do if row:IsShown() then visible = visible + 1 end end
check(visible == 0, "and no rows")
skills = { { "Alchemy", 1 }, { "Cooking", 1 } }
frame.pick.onSelect("Alchemy")

-- The scan button.
run(frame.scan, "OnClick")
check(lastPrint() == "Open the auction house first.", "away from the auction house it says why")
local started
local realStart = A.StartCraftScan
A.StartCraftScan = function(self, list) started = list return table.getn(list) end
A.AtAuctionHouse = function() return true end
run(frame.scan, "OnClick")
check(started and started[1] and string.find(lastPrint(), "Scanning " .. table.getn(started) .. " items for Alchemy", 1, true),
	"at it, the scan starts with the route's items: %s", lastPrint())
A.IsCraftScanning = function() return true, 3, 40 end
A:UpdateCraftRoutePanel()
check(frame.scan:GetText() == "STOP SCAN", "the button stops a running scan")
check(frame.status:GetText() == "Scanning the auction house: 3 of 40...", "and the status line counts: %s", frame.status:GetText())
local stopped = false
A.StopCraftScan = function() stopped = true end
run(frame.scan, "OnClick")
check(stopped, "clicking it stops the scan")
A.StartCraftScan = realStart

-- Load as guide, from the window.
opened = {}
run(frame.load, "OnClick")
check(opened[1] == "Alchemy (cheapest route)", "Load as guide opens the planned guide")

A:ToggleCraftRoutePanel()
check(not frame:IsShown(), "and the window closes")

if table.getn(failures) > 0 then
	for _, f in ipairs(failures) do print("FAIL: " .. f) end
	print(string.format("%d of %d checks failed", table.getn(failures), checks))
	os.exit(1)
end
print(string.format("test_craftroute: all %d checks passed", checks))
