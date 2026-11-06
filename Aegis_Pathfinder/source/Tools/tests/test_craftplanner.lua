--[[
	Tests for the crafting route planner and its auction scan.

	The planner's answer is a number people act on at the auction house, so
	the tests hold it to what it claims: that the skill-up chance follows the
	yellow-to-grey rule, that the route it picks is the cheapest under its
	own model (checked against brute force), that a known recipe is free and
	an unknown drop is never planned, that making beats buying only when it
	is cheaper, that forty of something is priced as forty, that what one
	step makes is used by the next before anything is bought, and that a
	reagent with no price is never quietly treated as free.

	The scan is held to the suite's auction house rules: the gate before
	every query, strings for the text arguments, one read per reply, and
	only listings with exactly the name searched for.

	Run:  lua5.1 Tools/tests/test_craftplanner.lua
]]

package.path = "Tools/tests/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

local clock = 1000000
time = function() return clock end
local now = 100
GetTime = function() return now end

local printed = {}
AegisPathfinder = { db = { char = {}, realm = {} } }
local debugged = {}
function AegisPathfinder:Debug(msg) table.insert(debugged, msg) end
function AegisPathfinder:Print(msg) table.insert(printed, msg) end
local ids = {}
function AegisPathfinder:ItemIdByName(name) return ids[name] end

dofile("CraftPlanner.lua")
dofile("CraftScan.lua")
local A = AegisPathfinder
local P = A.craftPlannerTunables

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, unpack(arg))) end
end

local function lastPrint() return printed[table.getn(printed)] or "" end

-- Reading recipe lines -------------------------------------------------------

A:RegisterRecipeBook("Testcraft", {
	"Plain = Empty Vial + 2 Peacebloom @ 1-55-75-95 | trainer ~200",
	"Booked = 3 Iron Bar + #2357 @ 10-20-30-40 | book Recipe: Booked 500",
	"Unpriced Book = Iron Bar @ 1-2-3-4 | book Recipe: Unpriced Book ?",
	"Estimated Book = Iron Bar @ 1-2-3-4 | book Recipe: Estimated Book ~300",
	"Quested = Iron Bar @ 1-2-3-4 | quest",
	"Dropped = Iron Bar @ 1-2-3-4 | drop",
	"Special = Iron Bar @ 1-2-3-4 | special",
	"Skipped = Iron Bar @ 1-2-3-4 | trainer 100 | skip | nomake",
	"this line is not a recipe",
	"Confirmed = Iron Bar @ 5-6-7-8 | trainer 900",
})
local book, byName = A:GetRecipeBook("testcraft")
check(book and table.getn(book) == 9, "nine readable lines of ten parse (got %s)", book and table.getn(book) or "nil")
check(table.getn(debugged) == 1 and string.find(debugged[1], "not a recipe", 1, true),
	"the unreadable line is reported, not fatal")
local plain = byName["Plain"]
check(plain.orange == 1 and plain.yellow == 55 and plain.green == 75 and plain.grey == 95, "thresholds read")
check(table.getn(plain.reagents) == 2 and plain.reagents[1].item == "Empty Vial" and plain.reagents[1].qty == 1,
	"a reagent with no count is one")
check(plain.reagents[2].item == "Peacebloom" and plain.reagents[2].qty == 2, "a count in front is read")
check(plain.learn == "trainer" and plain.cost == 200 and plain.estimated, "~ marks an estimated trainer fee")
check(byName["Confirmed"].cost == 900 and not byName["Confirmed"].estimated, "no ~ is a confirmed fee")
local booked = byName["Booked"]
check(booked.learn == "book" and booked.book == "Recipe: Booked" and booked.cost == 500 and not booked.estimated,
	"a book with a fallback price")
check(booked.reagents[2].id == 2357 and booked.reagents[2].item == "#2357", "#<id> is an item known only by id")
check(byName["Unpriced Book"].book == "Recipe: Unpriced Book" and byName["Unpriced Book"].cost == nil,
	"a book marked ? has no fallback price")
check(byName["Estimated Book"].cost == 300 and byName["Estimated Book"].estimated, "a book's estimate")
check(byName["Quested"].learn == "quest" and byName["Quested"].cost == 0, "a quest reward costs nothing")
check(byName["Dropped"].learn == "drop" and byName["Dropped"].cost == nil, "a drop has no price")
check(byName["Special"].learn == "special", "special")
check(byName["Skipped"].skip and byName["Skipped"].nomake, "flags after the learn field")
check(A:GetRecipeBook("TESTCRAFT") == book, "professions are found whatever the case, and parsed once")
check(A:GetRecipeBook("Nothing") == nil, "no data, no book")

-- The item known only by id takes its name once the game has seen it.
local reagent = booked.reagents[2]
GetItemInfo = function() return nil end
check(A.CraftReagentName(reagent) == "Item #2357", "an unseen id reads as Item #id")
GetItemInfo = function(id) if id == 2357 then return "Thick Hide" end end
check(A.CraftReagentName(reagent) == "Thick Hide" and reagent.item == "Thick Hide", "and its name once seen")
GetItemInfo = nil

-- Skill-up chance --------------------------------------------------------------

local r = { orange = 50, yellow = 80, green = 100, grey = 120 }
check(A:CraftSkillChance(r, 49) == 0, "below orange it cannot be made")
check(A:CraftSkillChance(r, 50) == 1 and A:CraftSkillChance(r, 79) == 1, "orange is certain")
check(A:CraftSkillChance(r, 80) == 1, "yellow starts at certain")
check(math.abs(A:CraftSkillChance(r, 100) - 0.5) < 1e-9, "halfway from yellow to grey is a half")
check(math.abs(A:CraftSkillChance(r, 110) - 0.25) < 1e-9, "and falls in a straight line")
check(A:CraftSkillChance(r, 120) == 0 and A:CraftSkillChance(r, 150) == 0, "grey gives nothing")
local flat = { orange = 80, yellow = 80, green = 90, grey = 100 }
check(A:CraftSkillChance(flat, 80) == 1, "orange at yellow")
local instant = { orange = 5, yellow = 5, green = 5, grey = 5 }
check(A:CraftSkillChance(instant, 5) == 0, "a recipe grey the moment it is learned gives nothing (not 0/0)")

-- The real data ------------------------------------------------------------------

for _, f in ipairs({ "Alchemy", "Blacksmithing", "Cooking", "Enchanting", "Engineering",
	"Jewelcrafting", "Leatherworking", "Survival", "Tailoring", "Prices" }) do
	dofile("Crafting/" .. f .. ".lua")
end
local professions = A:GetPlannedProfessions()
local seen = {}
for _, p in ipairs(professions) do seen[p] = true end
for _, p in ipairs({ "Alchemy", "Blacksmithing", "Cooking", "Enchanting", "Engineering",
	"Jewelcrafting", "Leatherworking", "Survival", "Tailoring" }) do
	check(seen[p], "%s has recipe data", p)
end

local debugBefore = table.getn(debugged)
local totalRecipes = 0
for _, p in ipairs({ "Alchemy", "Blacksmithing", "Cooking", "Enchanting", "Engineering",
	"Jewelcrafting", "Leatherworking", "Survival", "Tailoring" }) do
	local recipes = A:GetRecipeBook(p)
	totalRecipes = totalRecipes + table.getn(recipes)
	for _, recipe in ipairs(recipes) do
		local ok = recipe.orange <= recipe.yellow and recipe.yellow <= recipe.green and recipe.green <= recipe.grey
			and table.getn(recipe.reagents) > 0 and recipe.learn ~= nil
		check(ok, "%s: %s is well formed", p, recipe.name)
	end
end
check(table.getn(debugged) == debugBefore, "every generated recipe line reads (%d unreadable)", table.getn(debugged) - debugBefore)
check(totalRecipes == 1095, "all 1095 recipes are there (got %d)", totalRecipes)
check(A:MerchantBuyPrice("Empty Vial") == 4 and A:MerchantBuyPrice("empty vial") == 4, "merchant prices, any case")
check(A:MerchantBuyPrice("Peacebloom") == nil, "a reagent no merchant sells has no merchant price")
local zero, priced = 0, 0
for _, p in ipairs({ "Minor Healing Potion", "Advanced Camouflage" }) do
	local s = A:MerchantSellPrice(p)
	if s == 0 then zero = zero + 1 elseif s then priced = priced + 1 end
end
check(zero == 1 and priced == 1, "sell prices include the confirmed zeroes")

-- Planning on a small, controlled profession ------------------------------------

local market, vendor = {}, {}
local function opts(extra)
	local o = {
		known = {},
		sellBack = false,
		market = function(item) return market[item] end,
		merchant = function(item) return vendor[item] end,
	}
	for k, v in pairs(extra or {}) do o[k] = v end
	return o
end

--[[ Brute force: every assignment of recipes to skill points, scored the way
	the planner scores a path -- expected cost per point, and on every switch
	the new recipe's fee and one craft. The planner must find the minimum. ]]
local function Objective(recipes, costs, fees, assignment, from)
	local total, prev = 0, nil
	for k, i in ipairs(assignment) do
		local s = from + k - 1
		local p = A:CraftSkillChance(recipes[i], s)
		if p <= 0 then return nil end
		if i ~= prev then total = total + fees[i] + costs[i] end
		total = total + costs[i] / p
		prev = i
	end
	return total
end

local function BruteForce(recipes, costs, fees, from, to)
	local n, best = to - from, nil
	local assignment = {}
	local function rec(k)
		if k > n then
			local v = Objective(recipes, costs, fees, assignment, from)
			if v and (not best or v < best) then best = v end
			return
		end
		for i = 1, table.getn(recipes) do
			assignment[k] = i
			rec(k + 1)
		end
	end
	rec(1)
	return best
end

A:RegisterRecipeBook("Smallcraft", {
	"Cheap Early = A @ 1-4-7-10 | trainer 50",
	"Pricey Wide = B @ 1-8-10-14 | trainer 10",
	"Late = C @ 5-9-11-13 | trainer 400",
})
market = { A = 10, B = 25, C = 6 }
local small = A:GetRecipeBook("Smallcraft")
local route = A:PlanCraftRoute("Smallcraft", 1, 12, opts())
local costs, fees = { 10, 25, 6 }, { 50, 10, 400 }
local planned = {}
for _, step in ipairs(route.steps) do
	for s = step.from, step.to - 1 do table.insert(planned, step.index) end
end
local got = Objective(small, costs, fees, planned, 1)
local best = BruteForce(small, costs, fees, 1, 12)
check(route.reached == 12, "the small route gets to 12")
check(got and math.abs(got - best) < 1e-6, "the planner finds the brute-force optimum (%s vs %s)", tostring(got), tostring(best))

-- A tougher shape: learning fees that only pay off over a long stretch.
A:RegisterRecipeBook("Feecraft", {
	"Starter = A @ 1-3-5-7 | trainer 0",
	"Bridge = B @ 3-6-9-12 | trainer 5",
	"Bargain = C @ 4-10-12-14 | trainer 300",
	"Spendy = D @ 2-11-12-13 | trainer 1",
})
market = { A = 4, B = 9, C = 1, D = 30 }
local fee = A:GetRecipeBook("Feecraft")
route = A:PlanCraftRoute("Feecraft", 1, 13, opts())
planned = {}
for _, step in ipairs(route.steps) do
	for s = step.from, step.to - 1 do table.insert(planned, step.index) end
end
got = Objective(fee, { 4, 9, 1, 30 }, { 0, 5, 300, 1 }, planned, 1)
best = BruteForce(fee, { 4, 9, 1, 30 }, { 0, 5, 300, 1 }, 1, 13)
check(got and math.abs(got - best) < 1e-6, "and on a route where fees matter (%s vs %s)", tostring(got), tostring(best))

-- Steps are contiguous, and crafts are the expectation rounded up.
local contiguous, expectedOk = true, true
for k, step in ipairs(route.steps) do
	if k > 1 and step.from ~= route.steps[k - 1].to then contiguous = false end
	local e = 0
	for s = step.from, step.to - 1 do e = e + 1 / A:CraftSkillChance(step.recipe, s) end
	if math.abs(e - step.expected) > 1e-9 or step.crafts ~= math.ceil(e - 1e-6) then expectedOk = false end
end
check(contiguous and route.steps[1].from == 1, "steps follow on from each other")
check(expectedOk, "crafts are the summed expectation, rounded up")

-- Learning ------------------------------------------------------------------------

A:RegisterRecipeBook("Learncraft", {
	"Trainer Dear = T @ 1-20-25-30 | trainer 100000",
	"Drop Cheap = D @ 1-20-25-30 | drop",
	"Special Cheap = S @ 1-20-25-30 | special",
	"Skip Cheap = K @ 1-20-25-30 | trainer 0 | skip",
	"Book Mid = M @ 1-20-25-30 | book Recipe: Book Mid ?",
})
market = { T = 50, D = 5, S = 1, K = 2, M = 20 }
vendor = {}
route = A:PlanCraftRoute("Learncraft", 1, 20, opts())
check(route.steps[1].name == "Trainer Dear", "an unknown drop, special or skipped recipe is never planned, nor an unpriced book")
check(route.learnTotal == 100000 and route.steps[1].learnPaid == 100000, "the trainer's fee is paid once")

route = A:PlanCraftRoute("Learncraft", 1, 20, opts({ known = { ["Drop Cheap"] = true, ["Skip Cheap"] = true } }))
check(route.steps[1].name == "Drop Cheap", "a known drop recipe is planned")
check(route.learnTotal == 0, "and costs nothing to learn")
for _, step in ipairs(route.steps) do
	check(step.name ~= "Skip Cheap", "a skipped recipe stays out even when known")
end

market["Recipe: Book Mid"] = 700
route = A:PlanCraftRoute("Learncraft", 1, 20, opts())
check(route.steps[1].name == "Book Mid" and route.learnTotal == 700, "a book with an auction price is planned at it")
vendor["Recipe: Book Mid"] = 300
route = A:PlanCraftRoute("Learncraft", 1, 20, opts())
check(route.learnTotal == 300, "a merchant's price for the book beats the auction's")
vendor, market = {}, {}

A:RegisterRecipeBook("Estimatecraft", {
	"Guessed = G @ 1-20-25-30 | book Recipe: Guessed ~250",
	"Other = G @ 1-20-25-30 | trainer 5000",
})
market = { G = 10 }
route = A:PlanCraftRoute("Estimatecraft", 1, 20, opts())
check(route.steps[1].name == "Guessed" and route.learnTotal == 250, "an unpriced book falls back on its estimate")
market["Recipe: Guessed"] = 9000
route = A:PlanCraftRoute("Estimatecraft", 1, 20, opts())
check(route.steps[1].name == "Other", "a real price replaces the estimate")

-- Making or buying ------------------------------------------------------------------

-- The bolt recipe never raises the skill (grey from the start), so it only
-- ever appears as a supplier, never as a step of its own.
A:RegisterRecipeBook("Makecraft", {
	"Bolt = 2 Cloth @ 1-1-1-1 | trainer 0",
	"Shirt = Bolt + Thread @ 1-30-35-40 | trainer 0",
})
market = { Cloth = 10, Bolt = 50, Thread = 5 }
route = A:PlanCraftRoute("Makecraft", 1, 30, opts())
local buys = route.buys
check(buys.Bolt == nil and buys.Cloth == 2 * route.steps[1].crafts, "a reagent cheaper to make is made (%s cloth for %d shirts)",
	tostring(buys.Cloth), route.steps[1].crafts)
check(route.steps[1].made and route.steps[1].made.Bolt == route.steps[1].crafts, "and the step says so")
check(math.abs(route.steps[1].perCraft - 25) < 1e-9, "one shirt costs two cloth and a thread (%s)", tostring(route.steps[1].perCraft))
market.Bolt = 15
route = A:PlanCraftRoute("Makecraft", 1, 30, opts())
check(route.buys.Bolt == route.steps[1].crafts and route.buys.Cloth == nil, "and bought when buying is cheaper")

A:RegisterRecipeBook("Nomakecraft", {
	"Bolt = 2 Cloth @ 1-1-1-1 | trainer 0 | nomake",
	"Shirt = Bolt + Thread @ 1-30-35-40 | trainer 0",
})
market = { Cloth = 10, Bolt = 50, Thread = 5 }
route = A:PlanCraftRoute("Nomakecraft", 1, 30, opts())
check(route.buys.Bolt == route.steps[1].crafts, "nomake keeps a recipe from supplying another")

-- What one step makes, a later one uses --------------------------------------------------

A:RegisterRecipeBook("Chaincraft", {
	"Potion = Herb @ 1-10-15-20 | trainer 0",
	"Big Potion = Potion + Herb @ 10-30-35-40 | trainer 0",
})
market = { Herb = 10, Potion = 1000 }
route = A:PlanCraftRoute("Chaincraft", 1, 30, opts())
check(route.steps[1].name == "Potion" and route.steps[2].name == "Big Potion", "a potion route, then a big potion route")
local made = route.steps[1].crafts
local needed = route.steps[2].crafts
local fromStock = math.min(made, needed)
check(route.buys.Potion == nil, "potions are never bought")
check((route.steps[2].made and route.steps[2].made.Potion or 0) == needed - fromStock,
	"the second step uses the first step's potions before making more")
check(route.buys.Herb == made + (needed - fromStock) + needed, "herbs: %s", tostring(route.buys.Herb))

-- Selling back -------------------------------------------------------------------------

A:RegisterRecipeBook("Sellcraft", {
	"Trinket = Ore @ 1-10-15-20 | trainer 0",
})
A:RegisterMerchantPrices({ sell = { Trinket = 3 } })
market = { Ore = 10 }
route = A:PlanCraftRoute("Sellcraft", 1, 10, opts({ sellBack = true }))
check(route.credit == 3 * route.steps[1].crafts, "what the leftovers sell for is said (%s)", tostring(route.credit))
check(route.total == route.buyTotal + route.learnTotal, "but not taken off the route's cost")
route = A:PlanCraftRoute("Sellcraft", 1, 10, opts({ sellBack = false }))
check(route.credit == 0 and route.total == route.buyTotal, "and not when selling back is off")
A:RegisterMerchantPrices({ sell = { Trinket = 0 } })
route = A:PlanCraftRoute("Sellcraft", 1, 10, opts({ sellBack = true }))
check(route.credit == 0, "an item merchants will not buy earns nothing")
A.db.char.craftsellback = false
route = A:PlanCraftRoute("Sellcraft", 1, 10, { known = {}, market = function(i) return market[i] end, merchant = function() end })
check(route.sellBack == false, "the character's setting is the default")
A.db.char.craftsellback = nil

-- What a merchant pays never chooses the route. A Spear that sells for far
-- more than its Bar would cost nothing if its price came off: the planner
-- kept crafting it while it went green -- 92 Hunting Spears for 40 points.
-- Past 10 the Lantern is still orange, and once the Spear's chance falls
-- below four in five, the cheaper way on.
A:RegisterRecipeBook("Resalecraft", {
	"Spear = Bar @ 1-10-15-20 | trainer 0",
	"Lantern = Oil @ 10-20-25-30 | trainer 0",
})
A:RegisterMerchantPrices({ sell = { Spear = 1000 } })
market = { Bar = 20, Oil = 25 }
for _, sell in ipairs({ true, false }) do
	route = A:PlanCraftRoute("Resalecraft", 1, 20, opts({ sellBack = sell }))
	local names = {}
	for _, s in ipairs(route.steps) do table.insert(names, s.name .. " " .. s.from .. "-" .. s.to) end
	check(table.getn(route.steps) == 2 and route.steps[1].name == "Spear" and route.steps[2].name == "Lantern"
		and route.steps[2].from == 12, "sell-back %s: Spears to 12, then Lanterns (%s)", tostring(sell),
		table.concat(names, ", "))
	check(route.crafts == 20, "twenty crafts, not the thirty-nine of Spears to grey (%d)", route.crafts)
end

-- Forty is priced as forty -------------------------------------------------------------

local listing = { t = clock, p = { 10, 5, 20, 10, 40, 100 } }
check(A.CraftListingCost(listing, 3) == 30, "three from the cheapest step")
check(A.CraftListingCost(listing, 8) == 5 * 10 + 3 * 20, "eight walks up a step")
check(A.CraftListingCost(listing, 300) == 50 + 200 + 100 * 40 + 185 * 40, "past the listing at its dearest price")
check(A.CraftListingCost(listing, 8, 15) == 5 * 10 + 3 * 15, "a merchant's price caps it")

-- Where each thing on the shopping list comes from.
A:RegisterRecipeBook("Sourcecraft", { "Thing = Vial + Herb @ 1-20-25-30 | trainer 0" })
market = { Vial = { t = clock, p = { 90, 100 } }, Herb = { t = clock, p = { 10, 100 } } }
vendor = { Vial = 50 }
route = A:PlanCraftRoute("Sourcecraft", 1, 20, opts())
local sources = {}
for _, line in ipairs(route.shopping) do sources[line.item] = line.source end
check(sources.Vial == "merchant" and sources.Herb == "auction", "vials from a merchant, herbs from the auction house")
vendor = {}

A:RegisterRecipeBook("Depthcraft", {
	"Thin = X @ 1-40-45-50 | trainer 0",
	"Steady = Y @ 1-40-45-50 | trainer 0",
})
market = { X = { t = clock, p = { 10, 20, 200, 100 } }, Y = 30 }
route = A:PlanCraftRoute("Depthcraft", 1, 40, opts())
check(route.steps[1].name == "Steady" or route.buys.X <= 25,
	"a thin cheap listing does not carry a long route (%s, %s X)", route.steps[1].name, tostring(route.buys.X))
check(route.total < 39 * 200, "and the total is priced at depth (%s)", tostring(route.total))

-- Unpriced ---------------------------------------------------------------------------------

A:RegisterRecipeBook("Gapcraft", {
	"Early = A @ 1-20-25-30 | trainer 0",
	"Mystery = M @ 15-40-45-50 | trainer 0",
})
market = { A = 10 }
route = A:PlanCraftRoute("Gapcraft", 1, 40, opts())
check(route.reached == 40 and route.lenient, "a route leans on an unpriced recipe only to get further")
check(table.getn(route.unpriced) == 1 and route.unpriced[1] == "M", "and names what has no price")
local last = route.steps[table.getn(route.steps)]
check(last.name == "Mystery" and last.unpriced and last.unpriced[1] == "M" and last.guessed, "the step says so")
check(route.total < P.PENALTY, "and the stand-in price never reaches the total (%s)", tostring(route.total))
check(last.from == 30, "and only where nothing priced goes on: from 30, where Early turns grey (%d)", last.from)
check(route.steps[1].name == "Early", "priced recipes still carry what they can")
market.M = 12
route = A:PlanCraftRoute("Gapcraft", 1, 40, opts())
check(not route.lenient and table.getn(route.unpriced) == 0, "priced, it is an ordinary route")

-- Leaning on unpriced recipes still never reaches for one you cannot learn.
A:RegisterRecipeBook("Dropgapcraft", {
	"Early = A @ 1-20-25-30 | trainer 0",
	"Rare = R @ 15-40-45-50 | drop",
	"Rep = R @ 15-40-45-50 | special",
	"Cooldown = R @ 15-40-45-50 | trainer 0 | skip",
})
market = { A = 10, R = 1 }
route = A:PlanCraftRoute("Dropgapcraft", 1, 40, opts())
check(route.reached == 30, "an unknown drop, reputation or skipped recipe does not fill a gap (%d)", route.reached)

A:RegisterRecipeBook("Stuckcraft", { "Only = A @ 1-20-25-30 | trainer 0" })
market = { A = 10 }
route = A:PlanCraftRoute("Stuckcraft", 1, 60, opts())
check(route.reached == 30, "no recipe past 30: the route stops at 30 (%d)", route.reached)
check(route.steps[table.getn(route.steps)].to == 30, "and its last step ends there")

local none, why = A:PlanCraftRoute("Stuckcraft", 300, 300, opts())
check(none == nil and string.find(why, "already 300", 1, true), "nothing to plan at the top")
none, why = A:PlanCraftRoute("Nosuchcraft", 1, 300, opts())
check(none == nil and string.find(why, "no recipe data", 1, true), "or without data")

-- Known recipes from the profession windows --------------------------------------------

local tradeLine, trade, craftLine, crafts = "Alchemy", {
	{ "Potions", "header" }, { "Minor Healing Potion", "trivial" }, { "Elixir of Wisdom", "optimal" },
}, "Enchanting", { { "Enchant Bracer - Minor Health", nil, "easy" } }
GetTradeSkillLine = function() return tradeLine end
GetNumTradeSkills = function() return table.getn(trade) end
GetTradeSkillInfo = function(i) return trade[i][1], trade[i][2] end
GetCraftDisplaySkillLine = function() return craftLine end
GetNumCrafts = function() return table.getn(crafts) end
GetCraftInfo = function(i) return crafts[i][1], crafts[i][2], crafts[i][3] end
check(A:CaptureKnownRecipes() == 3, "two recipes and an enchant are new")
local known = A:GetKnownRecipes("Alchemy")
check(known["Minor Healing Potion"] and known["Elixir of Wisdom"] and not known["Potions"], "headers are not recipes")
check(A:GetKnownRecipes("Enchanting")["Enchant Bracer - Minor Health"], "the craft window counts too")
check(A:CaptureKnownRecipes() == 0, "reading them again adds nothing")
trade = { { "Minor Healing Potion", "trivial" } }
A:CaptureKnownRecipes()
check(A:GetKnownRecipes("Alchemy")["Elixir of Wisdom"], "a recipe hidden under a collapsed header is not forgotten")
tradeLine, craftLine = "UNKNOWN", nil
check(A:CaptureKnownRecipes() == 0, "no window open, nothing read")

-- Where auction prices come from ---------------------------------------------------------

local exchangePrice = {}
AegisExchange = { db = {}, craft = { MarketUnit = function(id) return exchangePrice[id] end } }
ids["Iron Bar"] = 3575
exchangePrice[3575] = 900
A.db.realm.craftprices = { ["Iron Bar"] = { t = clock - 3600, p = { 500, 4 } } }
check(type(A:GetAuctionQuote("Iron Bar")) == "table", "a recent own scan beats Exchange")
A.db.realm.craftprices["Iron Bar"].t = clock - 8 * 86400
check(A:GetAuctionQuote("Iron Bar") == 900, "a week-old scan gives way to Exchange")
AegisExchange.db.demo = true
check(type(A:GetAuctionQuote("Iron Bar")) == "table", "Exchange's demo prices are not a market")
AegisExchange.db.demo = nil
AegisExchange.craft.MarketUnit = function() error("boom") end
check(type(A:GetAuctionQuote("Iron Bar")) == "table", "an Exchange error is a missing price, not a crash")
A.db.realm.craftprices["Iron Bar"] = { t = clock, p = {} }
check(A:GetAuctionQuote("Iron Bar") == nil, "searched and none listed is no price")
AegisExchange = nil
A.db.realm.craftprices = nil

-- The auction scan -------------------------------------------------------------------------

local queries, gate, page = {}, true, { shown = 0, total = 0, items = {} }
CanSendAuctionQuery = function() return gate end
QueryAuctionItems = function(...) table.insert(queries, arg) end
GetNumAuctionItems = function() return page.shown, page.total end
GetAuctionItemInfo = function(kind, i)
	local it = page.items[i]
	if not it then return nil end
	-- name, texture, count, quality, canUse, level, minBid, minIncrement, buyout
	return it[1], "tex", it[2], 1, 1, 0, 1, 1, it[3]
end
local events, driver = A.craftScanEvents, A.craftScanState.driver
local function fire(e) event = e; events:GetScript("OnEvent")() end
local function tick() driver:GetScript("OnUpdate")() end
local changed = 0
A.OnCraftDataChanged = function(self, replan) if replan then changed = changed + 1 end end

local n, reason = A:StartCraftScan({ "Linen Cloth" })
check(n == nil and string.find(reason, "auction house", 1, true), "no scan away from the auction house")
fire("AUCTION_HOUSE_SHOW")
check(A:AtAuctionHouse(), "the auction house is open")

n = A:StartCraftScan({ "Linen Cloth", "Wool Cloth", "Linen Cloth" })
check(n == 2, "two items, the repeat dropped (%s)", tostring(n))
check(driver:IsShown() and A:IsCraftScanning(), "scanning")
gate = false
tick()
check(table.getn(queries) == 0, "nothing is sent while the gate is shut")
gate = true
tick()
check(table.getn(queries) == 1, "one query once it opens")
local q = queries[1]
check(q[1] == "Linen Cloth" and q[2] == "" and q[3] == "" and q[4] == nil and q[7] == 0 and q[9] == nil,
	"the query: name, empty level strings, nil filters, page 0")
tick()
check(table.getn(queries) == 1, "no second query while the reply is awaited")

page = { shown = 4, total = 120, items = {
	{ "Linen Cloth", 20, 400 }, { "Bolt of Linen Cloth", 1, 5 }, { "Linen Cloth", 5, 150 }, { "Linen Cloth", 1, 0 },
} }
fire("AUCTION_ITEM_LIST_UPDATE")
fire("AUCTION_ITEM_LIST_UPDATE")
tick()
check(table.getn(queries) == 2 and queries[2][1] == "Linen Cloth" and queries[2][7] == 1,
	"a second page is asked for, once, however many updates fire")
page = { shown = 1, total = 120, items = { { "Linen Cloth", 10, 200 } } }
fire("AUCTION_ITEM_LIST_UPDATE")
tick()
check(queries[3][7] == 2, "and a third")
page = { shown = 1, total = 120, items = { { "Linen Cloth", 2, 60 } } }
fire("AUCTION_ITEM_LIST_UPDATE")
local stored = A.db.realm.craftprices and A.db.realm.craftprices["Linen Cloth"]
check(stored and stored.t == clock, "the item is stored when its pages are read")
check(stored and table.concat(stored.p, ",") == "20,30,30,7", "exact names only, bid-only skipped, by price, equal prices merged (%s)",
	stored and table.concat(stored.p, ",") or "nil")
tick()
check(table.getn(queries) == 4 and queries[4][1] == "Wool Cloth" and queries[4][7] == 0, "then the next item from page 0")
page = { shown = 0, total = 0, items = {} }
fire("AUCTION_ITEM_LIST_UPDATE")
check(not A:IsCraftScanning() and not driver:IsShown(), "done after the last")
check(A.db.realm.craftprices["Wool Cloth"] and table.getn(A.db.realm.craftprices["Wool Cloth"].p) == 0,
	"none listed is remembered")
check(changed == 1, "the planner is told once, at the end")
check(string.find(lastPrint(), "1 of 2 items", 1, true), "and the player: %s", lastPrint())
fire("AUCTION_ITEM_LIST_UPDATE")
check(table.getn(queries) == 4, "an update nobody asked for is ignored")

n = A:StartCraftScan({ "Linen Cloth", "Wool Cloth" })
check(n == 0, "items searched in the last half hour are skipped")
clock = clock + 31 * 60
n = A:StartCraftScan({ "Linen Cloth" })
check(n == 1, "and searched again after it")
A:StopCraftScan()
check(not A:IsCraftScanning() and string.find(lastPrint(), "stopped", 1, true), "a scan can be stopped")

n = A:StartCraftScan({ "Linen Cloth" }, true)
check(n == 1, "force searches it anyway")
tick()
now = now + 11
tick()
check(not A:IsCraftScanning(), "a reply that never comes is given up on")

n = A:StartCraftScan({ "Silk Cloth", "Mageweave Cloth" }, true)
tick()
fire("AUCTION_HOUSE_CLOSED")
check(not A:IsCraftScanning() and not A:AtAuctionHouse(), "closing the auction house ends the scan")

-- However many pages there are, an item stops at four.
fire("AUCTION_HOUSE_SHOW")
A:StartCraftScan({ "Runecloth" }, true)
tick()
local pages = 0
for i = 1, 10 do
	if not A:IsCraftScanning() then break end
	page = { shown = 1, total = 1000, items = { { "Runecloth", 1, 100 } } }
	fire("AUCTION_ITEM_LIST_UPDATE")
	pages = pages + 1
	tick()
end
check(pages == A.craftScanTunables.MAX_PAGES, "an item is read for four pages at most (%d)", pages)

-- Many listings keep the cheapest steps only.
A:StartCraftScan({ "Copper Ore" }, true)
tick()
local many = {}
for i = 1, 50 do table.insert(many, { "Copper Ore", 1, 1000 - i }) end
page = { shown = 50, total = 50, items = many }
fire("AUCTION_ITEM_LIST_UPDATE")
local ore = A.db.realm.craftprices["Copper Ore"]
check(table.getn(ore.p) == A.craftScanTunables.KEEP * 2 and ore.p[1] == 950, "the cheapest %d prices are kept", A.craftScanTunables.KEEP)

-- Every profession, from real data, with a made-up market -----------------------------------

local function synthetic(item)
	local sell = A:MerchantSellPrice(item)
	if sell and sell > 0 then return { t = clock, p = { sell * 3, 5, sell * 4, 10, sell * 6, 50 } } end
	-- Enchanting's reagents are not sold to merchants; price them anyway.
	return { t = clock, p = { 500, 20, 900, 100 } }
end
for _, p in ipairs({ "Alchemy", "Blacksmithing", "Cooking", "Enchanting", "Engineering",
	"Jewelcrafting", "Leatherworking", "Survival", "Tailoring" }) do
	local started = os.clock()
	local rt = A:PlanCraftRoute(p, 1, 300, { known = {}, market = synthetic })
	local took = os.clock() - started
	check(rt and rt.reached == 300, "%s gets to 300 (%s)", p, rt and rt.reached or "nil")
	check(rt and rt.buyTotal > 0 and rt.total >= rt.buyTotal and rt.total < 100000000,
		"%s costs something believable", p)
	check(rt and not rt.lenient, "%s needs no unpriced recipe once everything has a price", p)
	check(took < 1, "%s plans in under a second here (%.2fs)", p, took)
	-- Selling back or not, the same route: what a merchant pays is said, never
	-- planned on.
	local other = A:PlanCraftRoute(p, 1, 300, { known = {}, market = synthetic, sellBack = not rt.sellBack })
	local same = rt and other and table.getn(rt.steps) == table.getn(other.steps) and rt.total == other.total
	for i, s in ipairs(rt and rt.steps or {}) do
		local o = other and other.steps[i]
		if not o or o.name ~= s.name or o.from ~= s.from or o.crafts ~= s.crafts then same = false end
	end
	check(same, "%s takes the same route with sell-back on or off", p)
end

-- From part-way, the route starts where you are.
local part = A:PlanCraftRoute("Alchemy", 150, 300, { known = {}, market = synthetic })
check(part.steps[1].from == 150 and part.from == 150, "a route from 150 starts at 150")

if table.getn(failures) > 0 then
	for _, f in ipairs(failures) do print("FAIL: " .. f) end
	print(string.format("%d of %d checks failed", table.getn(failures), checks))
	os.exit(1)
end
print(string.format("test_craftplanner: all %d checks passed", checks))
