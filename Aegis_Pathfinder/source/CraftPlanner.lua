--[[
	CraftPlanner.lua -- the cheapest way to level a crafting profession.

	The profession guides say what to craft in each skill band, chosen once by
	whoever wrote them. That choice goes stale the moment prices move: the
	cheapest way through 125-150 on a server where Bronze Bars flood the
	auction house is not the cheapest where they don't. This works the route
	out again from current prices, whenever you ask.

	What it knows about each recipe (Crafting/*.lua, converted from CraftRoute
	by Tools/build/import_recipes.py): the skill at which it turns orange, yellow,
	green and grey, its reagents, how it is learned and roughly what that
	costs. What it knows about prices: what merchants charge (Crafting/
	Prices.lua), what the auction house asks (its own scan, CraftScan.lua, or
	Aegis: Exchange's), and what merchants pay for what you make.

	How the route is found:

	  1. Every reagent gets a unit cost: the merchant's price or the auction
	     house's, whichever is lower, or the cost of making it from its own
	     reagents when this profession can and that is cheaper still.
	  2. The chance that a craft raises your skill falls in a straight line
	     from certain at yellow to nothing at grey -- the rule as Blizzard
	     describe it. So one skill point with a recipe costs, on average, a
	     craft's cost divided by that chance.
	  3. The cheapest sequence is a shortest path through the skill points,
	     where the state is the recipe you used last: carrying on with it
	     costs the next point, switching to another costs that recipe's
	     learning fee as well (and, as a nudge against one-point detours,
	     one craft of it). That is a small dynamic program -- skill points
	     times recipes -- rather than a search.
	  4. Buying forty of something costs more than forty times its cheapest
	     listing. So the route is priced at the quantities it actually
	     buys, walking up the auction listings, and planned again at those
	     prices, until it stops changing.
	  5. The finished route is played through in order, as you would craft
	     it: what an earlier step made is used by a later one before
	     anything is bought. What is left over at the end is valued at what
	     a merchant pays for it (if you ask), and said beside the route --
	     never taken off its cost, and never used to choose it. A merchant
	     who paid more for a Hunting Spear than its bars cost made it free
	     to the planner, which then kept crafting it long after it went
	     green: 92 spears for 40 points.

	A reagent no one has a price for yet keeps its recipe out of the route,
	unless the route cannot go on without it; then it is used, and said to be
	unpriced, rather than pretending the route is cheaper than it is.
]]

local AegisPathfinder = AegisPathfinder

-- Tunables, in one table: see the 32-upvalue note in CONTRIBUTING.md.
local P = {
	TYPICAL = 20,           -- units a first-pass auction price is averaged over
	FRESH = 7 * 86400,      -- an own scan younger than this beats Exchange's
	PENALTY = 10000000,     -- the stand-in for an unknown price: 1000 gold
	PASSES = 4,             -- re-pricing passes at most (step 4 above)
	MAX_DEPTH = 6,          -- how deep one intermediate may be made from another
	MAX_SKILL = 300,
}
AegisPathfinder.craftPlannerTunables = P

local books = {}                          -- lower-case profession -> book
local merchant = { buy = {}, sell = {} }  -- lower-case item -> copper

--[[ Registration: called by the generated files in Crafting/. ]]

function AegisPathfinder:RegisterRecipeBook(profession, lines)
	books[string.lower(profession)] = { name = profession, lines = lines }
end

function AegisPathfinder:RegisterMerchantPrices(prices)
	for name, copper in pairs(prices.buy or {}) do merchant.buy[string.lower(name)] = copper end
	for name, copper in pairs(prices.sell or {}) do merchant.sell[string.lower(name)] = copper end
end

--- What a merchant charges for an item, or nil if none sells it.
function AegisPathfinder:MerchantBuyPrice(item)
	return item and merchant.buy[string.lower(item)]
end

--- What a merchant pays for one: 0 if none will buy it, nil if unknown.
function AegisPathfinder:MerchantSellPrice(item)
	return item and merchant.sell[string.lower(item)]
end

--[[ Reading the recipe lines.

	"<recipe> = <reagents> @ <orange>-<yellow>-<green>-<grey> | <learned> [| flags]"

	Parsed the first time a profession is planned, not at load: nine
	professions of recipes most players never plan are only strings until
	then.
]]

local function ParseLearn(text, recipe)
	local _, _, approx, cost = string.find(text, "^trainer (~?)(%d+)$")
	if cost then
		recipe.learn, recipe.cost, recipe.estimated = "trainer", tonumber(cost), approx == "~"
		return true
	end
	local _, _, book, approx2, cost2 = string.find(text, "^book (.+) (~?)(%d+)$")
	if book then
		recipe.learn, recipe.book = "book", book
		recipe.cost, recipe.estimated = tonumber(cost2), approx2 == "~"
		return true
	end
	_, _, book = string.find(text, "^book (.+) %?$")
	if book then
		recipe.learn, recipe.book = "book", book
		return true
	end
	if text == "quest" or text == "drop" or text == "special" then
		recipe.learn = text
		recipe.cost = text == "quest" and 0 or nil
		return true
	end
	return false
end

local function ParseRecipe(line)
	local _, _, name, mats, o, y, g, r, rest =
		string.find(line, "^(.-) = (.-) @ (%d+)%-(%d+)%-(%d+)%-(%d+) | (.+)$")
	if not name then return nil end

	local recipe = {
		name = name,
		orange = tonumber(o), yellow = tonumber(y), green = tonumber(g), grey = tonumber(r),
		reagents = {},
	}
	for part in string.gfind(mats .. " + ", "(.-) %+ ") do
		local _, _, qty, item = string.find(part, "^(%d+) (.+)$")
		if not qty then qty, item = 1, part end
		local _, _, id = string.find(item, "^#(%d+)$")
		table.insert(recipe.reagents, { item = item, qty = tonumber(qty), id = id and tonumber(id) })
	end

	local first = true
	for field in string.gfind(rest .. " | ", "(.-) | ") do
		if first then
			if not ParseLearn(field, recipe) then return nil end
			first = false
		elseif field == "skip" then
			recipe.skip = true
		elseif field == "nomake" then
			recipe.nomake = true
		end
	end
	return recipe
end

--- The recipes of a profession, parsed, or nil when there is no data for it.
--- Each is { name, orange, yellow, green, grey, reagents = { { item, qty } },
--- learn, cost, estimated, book, skip, nomake }.
function AegisPathfinder:GetRecipeBook(profession)
	local book = profession and books[string.lower(profession)]
	if not book then return nil end
	if not book.recipes then
		book.recipes, book.byName = {}, {}
		for _, line in ipairs(book.lines) do
			local recipe = ParseRecipe(line)
			if recipe then
				table.insert(book.recipes, recipe)
				book.byName[recipe.name] = recipe
			else
				self:Debug("CraftPlanner: unreadable recipe line: " .. line)
			end
		end
	end
	return book.recipes, book.byName
end

--- Every profession there is recipe data for, by its in-game name.
function AegisPathfinder:GetPlannedProfessions()
	local out = {}
	for _, book in pairs(books) do table.insert(out, book.name) end
	table.sort(out)
	return out
end

--- A reagent's name. The few the data knows only by id are named by the
--- game once it has seen the item.
local function ReagentName(reagent)
	if reagent.id and string.find(reagent.item, "^#") then
		local name = GetItemInfo and GetItemInfo(reagent.id)
		if name then
			reagent.item = name
		else
			return "Item " .. reagent.item
		end
	end
	return reagent.item
end
AegisPathfinder.CraftReagentName = ReagentName

--[[ The chance of a skill-up. ]]

--- The chance one craft of `recipe` raises a skill of `skill`: certain from
--- orange to yellow, falling in a straight line to nothing at grey. Below
--- orange you cannot make it at all.
function AegisPathfinder:CraftSkillChance(recipe, skill)
	if skill < recipe.orange or skill >= recipe.grey then return 0 end
	if skill < recipe.yellow then return 1 end
	return (recipe.grey - skill) / (recipe.grey - recipe.yellow)
end

--[[ Recipes the character knows.

	Read from the profession window whenever it is open -- the trade skill
	window, or the craft window for Enchanting -- and kept per character.
	A known recipe costs nothing to learn, and a known drop or reputation
	recipe can be used at all. Only ever added to: nobody unlearns a recipe,
	and a collapsed header hiding some for a moment is no reason to forget
	them.
]]

function AegisPathfinder:GetKnownRecipes(profession)
	local store = self.db and self.db.char
	if not store or not profession then return {} end
	store.knownrecipes = store.knownrecipes or {}
	local key = string.lower(profession)
	store.knownrecipes[key] = store.knownrecipes[key] or {}
	return store.knownrecipes[key]
end

local function Remember(self, profession, names)
	if not profession or profession == "" or profession == "UNKNOWN" then return 0 end
	local known, added = self:GetKnownRecipes(profession), 0
	for _, name in ipairs(names) do
		if not known[name] then
			known[name] = true
			added = added + 1
		end
	end
	return added
end

--- Read the open profession window. Returns how many recipes were new.
function AegisPathfinder:CaptureKnownRecipes()
	local added = 0
	if GetTradeSkillLine and GetNumTradeSkills then
		local line = GetTradeSkillLine()
		local names = {}
		for i = 1, GetNumTradeSkills() or 0 do
			local name, kind = GetTradeSkillInfo(i)
			if name and kind ~= "header" then table.insert(names, name) end
		end
		added = added + Remember(self, line, names)
	end
	if GetCraftDisplaySkillLine and GetNumCrafts then
		local line = GetCraftDisplaySkillLine()
		local names = {}
		for i = 1, GetNumCrafts() or 0 do
			local name, _, kind = GetCraftInfo(i)
			if name and kind ~= "header" then table.insert(names, name) end
		end
		added = added + Remember(self, line, names)
	end
	return added
end

--[[ Auction prices.

	Two sources. This addon's own scan (CraftScan.lua) keeps every listing it
	saw, cheapest first, per realm: { t = when, p = { price, count, price,
	count, ... } }, so forty of something can be priced as forty rather than
	as forty of the cheapest one. Aegis: Exchange, when loaded, gives one
	unit price per item. A recent own scan wins; past a week, Exchange's
	price (which it keeps up to date as you use the auction house) does.
]]

function AegisPathfinder:GetAuctionListing(item)
	local realm = self.db and self.db.realm
	local store = realm and realm.craftprices
	return store and item and store[item]
end

local function ExchangePrice(self, item)
	local x = AegisExchange
	local craft = x and x.craft
	-- Demo mode's prices are made up for screenshots, not a market.
	if not (craft and craft.MarketUnit) or (x.db and x.db.demo) then return nil end
	local id = self:ItemIdByName(item)
	if not id then return nil end
	local ok, price = pcall(craft.MarketUnit, id)
	if ok and type(price) == "number" and price > 0 then return price end
	return nil
end

--- The auction house's price for an item: an own-scan listing ({ t, p }),
--- a unit price from Exchange (a number), or nil.
function AegisPathfinder:GetAuctionQuote(item)
	local listing = self:GetAuctionListing(item)
	local now = time and time() or 0
	if listing and listing.p and listing.p[1] and now - (listing.t or 0) < P.FRESH then
		return listing
	end
	local exchange = ExchangePrice(self, item)
	if exchange then return exchange end
	if listing and listing.p and listing.p[1] then return listing end
	return nil
end

--- What `n` cost, walking up a listing from its cheapest. A merchant's
--- price caps it -- a merchant never runs out -- and past the last listing
--- the rest cost what the dearest one did.
local function ListingCost(listing, n, ceiling)
	local p, total, left, last, i = listing.p, 0, n, nil, 1
	while left > 0 and p[i] do
		local price, count = p[i], p[i + 1] or 1
		if ceiling and price >= ceiling then break end
		local take = count < left and count or left
		total = total + take * price
		left = left - take
		last = price
		i = i + 2
	end
	if left > 0 then total = total + left * (ceiling or last or p[1]) end
	return total
end
AegisPathfinder.CraftListingCost = ListingCost

--[[ One planning run's prices.

	Built fresh for each plan, so a scan finishing mid-way never mixes two
	price lists in one route. `opts.merchant` and `opts.market` stand in for
	the real sources in the tests.
]]

local function NewPricer(self, profession, opts)
	local recipes, byName = self:GetRecipeBook(profession)
	local known = opts.known or self:GetKnownRecipes(profession)
	local pricer = { want = {}, known = known, byName = byName, recipes = recipes }

	local function MerchantBuy(item)
		if opts.merchant then return opts.merchant(item) end
		return self:MerchantBuyPrice(item)
	end
	local quotes = {}
	local function Quote(item)
		if quotes[item] == nil then
			local q
			if opts.market then q = opts.market(item) else q = self:GetAuctionQuote(item) end
			quotes[item] = q or false
		end
		return quotes[item] or nil
	end

	--- What `n` of an item cost to buy, and where from ("merchant" or
	--- "auction"), or nil when nobody has a price for it.
	function pricer.Buy(item, n)
		local vendor, q = MerchantBuy(item), Quote(item)
		if type(q) == "table" then
			local total = ListingCost(q, n, vendor)
			if vendor and total >= vendor * n then return vendor * n, "merchant" end
			return total, "auction"
		elseif type(q) == "number" then
			if vendor and vendor <= q then return vendor * n, "merchant" end
			return q * n, "auction"
		elseif vendor then
			return vendor * n, "merchant"
		end
		return nil
	end

	--- A recipe's learning fee, or nil when it cannot be learned (or its
	--- book has no price yet). Known recipes are free.
	function pricer.Learn(recipe)
		if known[recipe.name] then return 0 end
		if recipe.learn == "book" then
			local price = pricer.Buy(recipe.book, 1)
			return price or recipe.cost
		end
		return recipe.cost
	end

	--- True when a recipe may be planned at all.
	function pricer.Usable(recipe, lenient)
		if known[recipe.name] then return not recipe.skip end
		if recipe.skip or recipe.learn == "drop" or recipe.learn == "special" then return false end
		return lenient or pricer.Learn(recipe) ~= nil
	end

	-- A pass's unit costs, remembered until the next pass reprices them.
	local memo, making, how = {}, {}, {}
	pricer.make = how

	function pricer.Reset()
		memo, making, how = {}, {}, {}
		pricer.make = how
	end

	--- The cheapest unit cost of an item this pass: bought at the quantity
	--- the last pass wanted, or made here from its own reagents.
	function pricer.Cost(item)
		if memo[item] ~= nil then return memo[item] or nil end
		local n = pricer.want[item] or P.TYPICAL
		local total = pricer.Buy(item, n)
		local buy = total and total / n

		local recipe, make = byName[item], nil
		if recipe and not recipe.nomake and not making[item] and pricer.Usable(recipe) then
			making[item] = true
			make = 0
			for _, r in ipairs(recipe.reagents) do
				local c = pricer.Cost(ReagentName(r))
				if not c then make = nil break end
				make = make + c * r.qty
			end
			making[item] = nil
		end

		local cost = buy
		if make and (not buy or make < buy) then
			cost = make
			how[item] = recipe
		else
			how[item] = nil
		end
		-- While an item is being made its own cost is only provisional, so
		-- only settled answers are remembered.
		if not next(making) then memo[item] = cost or false end
		return cost
	end

	return pricer
end

--[[ The dynamic program (step 3). ]]

-- One craft's cost for planning: what its reagents cost. What a merchant
-- would pay for the result is left out: you may not sell it, and counting it
-- made a recipe that sells well look free however many crafts it took.
-- Unpriced reagents stand in at P.PENALTY when `lenient`, and are listed.
-- Never below a copper, so of two free recipes the one needing fewer crafts
-- still wins.
local function CraftCost(pricer, recipe, lenient)
	local cost, unpriced = 0, nil
	for _, r in ipairs(recipe.reagents) do
		local name = ReagentName(r)
		local c = pricer.Cost(name)
		if not c then
			if not lenient then return nil end
			unpriced = unpriced or {}
			table.insert(unpriced, name)
			c = P.PENALTY
		end
		cost = cost + c * r.qty
	end
	local gross = cost
	if cost < 1 then cost = 1 end
	return cost, gross, unpriced
end

-- The cheapest recipe for every skill point from `from` to `to`, as a list
-- of recipes (one per point), and the skill it got to.
local function ShortestPath(recipes, costs, learns, from, to, chance)
	local INF = 1e30
	local f, best, bestRecipe = {}, 0, nil
	local switched, bestAt = {}, {}

	local reached = from
	for s = from, to - 1 do
		local nf, nb, nbr, sw = {}, INF, nil, {}
		for i, recipe in ipairs(recipes) do
			local c = costs[i]
			if c then
				local p = chance(recipe, s)
				if p > 0 then
					-- Switching also counts one craft as overhead: a detour
					-- for a point or two is rarely worth the trip.
					local stay, switch = f[i] or INF, best + learns[i] + c
					local base = stay
					if switch < stay then base, sw[i] = switch, true end
					local v = base + c / p
					nf[i] = v
					if v < nb then nb, nbr = v, i end
				end
			end
		end
		if not nbr then break end
		switched[s], bestAt[s] = sw, bestRecipe
		f, best, bestRecipe = nf, nb, nbr
		reached = s + 1
	end

	-- Walk back from the end: each point used the recipe the next one came
	-- from, until a switch hands over to the best recipe of the point before.
	local path, i = {}, bestRecipe
	for s = reached - 1, from, -1 do
		path[s] = i
		if switched[s][i] then i = bestAt[s] end
	end
	return path, reached
end

--[[ Playing the route through (step 5). ]]

local function Account(self, route, pricer, sellBack)
	local known = pricer.known
	local stock, paid, buys = {}, {}, {}
	local learnTotal, learnUnknown = 0, {}

	local function Learn(recipe)
		if known[recipe.name] or paid[recipe.name] then return 0 end
		paid[recipe.name] = true
		local fee = pricer.Learn(recipe)
		if not fee then
			table.insert(learnUnknown, recipe.book or recipe.name)
			return 0
		end
		learnTotal = learnTotal + fee
		return fee
	end

	local function Obtain(item, n, sink, depth)
		local have = stock[item] or 0
		if have > 0 then
			local take = have < n and have or n
			stock[item] = have - take
			n = n - take
		end
		if n <= 0 then return end
		local recipe = pricer.make[item]
		if recipe and depth < P.MAX_DEPTH then
			sink.learn = (sink.learn or 0) + Learn(recipe)
			sink.made = sink.made or {}
			sink.made[item] = (sink.made[item] or 0) + n
			for _, r in ipairs(recipe.reagents) do
				Obtain(ReagentName(r), r.qty * n, sink, depth + 1)
			end
		else
			buys[item] = (buys[item] or 0) + n
			sink.buys[item] = (sink.buys[item] or 0) + n
		end
	end

	for _, step in ipairs(route.steps) do
		step.buys = {}
		step.learnPaid = Learn(step.recipe)
		for _, r in ipairs(step.recipe.reagents) do
			Obtain(ReagentName(r), r.qty * step.crafts, step, 0)
		end
		step.learnPaid = step.learnPaid + (step.learn or 0)
		step.learn = nil
		stock[step.name] = (stock[step.name] or 0) + step.crafts
	end

	-- Price what has to be bought, at the quantities bought.
	local unit, shopping, buyTotal, unpriced = {}, {}, 0, {}
	for item, n in pairs(buys) do
		local cost, source = pricer.Buy(item, n)
		if cost then
			unit[item] = cost / n
			buyTotal = buyTotal + cost
		else
			table.insert(unpriced, item)
		end
		table.insert(shopping, { item = item, count = n, cost = cost, source = source })
	end
	table.sort(shopping, function(a, b) return a.item < b.item end)
	table.sort(unpriced)

	for _, step in ipairs(route.steps) do
		local spend, missing = step.learnPaid, nil
		for item, n in pairs(step.buys) do
			if unit[item] then
				spend = spend + unit[item] * n
			else
				missing = missing or {}
				table.insert(missing, item)
			end
		end
		if missing then table.sort(missing) end
		step.spend, step.unpriced = spend, missing
	end

	-- What is left over, and what a merchant would pay for it: said beside
	-- the route's cost, not taken off it.
	local credit, leftovers = 0, {}
	for item, n in pairs(stock) do
		if n > 0 then
			local sell = self:MerchantSellPrice(item)
			local value = (sellBack and sell and sell > 0) and sell * n or 0
			credit = credit + value
			table.insert(leftovers, { item = item, count = n, value = value })
		end
	end
	table.sort(leftovers, function(a, b) return a.item < b.item end)

	route.shopping, route.leftovers = shopping, leftovers
	route.buyTotal, route.learnTotal, route.credit = buyTotal, learnTotal, credit
	route.total = buyTotal + learnTotal
	route.unpriced, route.learnUnknown = unpriced, learnUnknown
	route.buys = buys
	return route
end

--[[ Planning. ]]

local function BuildRoute(self, profession, from, to, pricer, lenient, sellBack)
	-- `sellBack` only says whether to value what is left over (Account); it
	-- never changes the route.
	local recipes = pricer.recipes
	local costs, learns, gross, missing = {}, {}, {}, {}
	for i, recipe in ipairs(recipes) do
		if pricer.Usable(recipe, lenient) then
			local c, g, unpriced = CraftCost(pricer, recipe, lenient)
			if c then
				local fee = pricer.Learn(recipe)
				if not fee then fee = P.PENALTY end
				costs[i], learns[i], gross[i], missing[i] = c, fee, g, unpriced
			end
		end
	end

	local chance = function(recipe, s) return self:CraftSkillChance(recipe, s) end
	local path, reached = ShortestPath(recipes, costs, learns, from, to, chance)

	-- Consecutive points on one recipe are one step.
	local steps = {}
	for s = from, reached - 1 do
		local i = path[s]
		local last = steps[table.getn(steps)]
		local expected = 1 / self:CraftSkillChance(recipes[i], s)
		if last and last.index == i then
			last.to = s + 1
			last.expected = last.expected + expected
		else
			table.insert(steps, {
				index = i, recipe = recipes[i], name = recipes[i].name,
				from = s, to = s + 1, expected = expected,
				perCraft = gross[i], guessed = missing[i],
			})
		end
	end
	local crafts = 0
	for _, step in ipairs(steps) do
		-- An expectation, so rounded up: 12.1 crafts is 13 trips to the
		-- anvil, not 12.
		step.crafts = math.ceil(step.expected - 1e-6)
		crafts = crafts + step.crafts
	end

	return {
		profession = profession, from = from, to = to, reached = reached,
		steps = steps, crafts = crafts, lenient = lenient, sellBack = sellBack,
	}
end

local function SameWants(a, b)
	for k, v in pairs(a) do if b[k] ~= v then return false end end
	for k, v in pairs(b) do if a[k] ~= v then return false end end
	return true
end

--- The cheapest route from skill `from` to `to` in a profession.
---
--- opts (all optional): sellBack -- value what is left over at what a
--- merchant pays (defaults to the character's setting; never changes the
--- route); known -- a set of known recipe names (defaults
--- to what the profession window showed); merchant(item), market(item) --
--- price sources, for the tests.
---
--- Returns nil and a reason when there is nothing to plan, else a route:
--- { profession, from, to, reached, steps, crafts, total, buyTotal,
---   learnTotal, credit, shopping, leftovers, unpriced, learnUnknown,
---   lenient } where each step is { name, recipe, from, to, crafts,
--- expected, perCraft, spend, learnPaid, buys, unpriced }. `reached` short
--- of `to` means no recipe the planner may use goes further; `lenient`
--- means the route had to lean on recipes with unpriced reagents. `total`
--- is what the route costs; `credit`, what a merchant would pay for what is
--- left over, is not taken off it.
function AegisPathfinder:PlanCraftRoute(profession, from, to, opts)
	opts = opts or {}
	local recipes = self:GetRecipeBook(profession)
	if not recipes then return nil, "There is no recipe data for " .. tostring(profession) .. "." end

	to = math.min(to or P.MAX_SKILL, P.MAX_SKILL)
	from = math.max(from or 1, 1)
	if from >= to then return nil, string.format("Your %s is already %d.", profession, from) end

	local sellBack = opts.sellBack
	if sellBack == nil then
		local char = self.db and self.db.char
		sellBack = not (char and char.craftsellback == false)
	end

	local pricer = NewPricer(self, profession, opts)
	local best

	for _, lenient in ipairs({ false, true }) do
		pricer.want = {}
		local lastWant
		for pass = 1, P.PASSES do
			pricer.Reset()
			local route = BuildRoute(self, profession, from, to, pricer, lenient, sellBack)
			Account(self, route, pricer, sellBack)
			route.passes = pass
			-- Further is better than cheaper: a route that stops short is not
			-- a cheaper way to the same place.
			if not best or route.reached > best.reached
				or (route.reached == best.reached and route.total < best.total) then
				best = route
			end
			if lastWant and SameWants(lastWant, route.buys) then break end
			lastWant = route.buys
			pricer.want = route.buys
		end
		-- Unpriced recipes are only worth leaning on to get further.
		if best.reached >= to then break end
	end

	return best
end

--[[ Keeping the known recipes current.

	TRADE_SKILL_UPDATE fires on every craft and every bag change while the
	window is open, so the events only mark the list stale; one OnUpdate
	later the window is read once. A new recipe changes what the planner may
	use, so the route is worked out again.
]]
local knownDriver = CreateFrame("Frame")
knownDriver:Hide()
knownDriver:SetScript("OnUpdate", function()
	this:Hide()
	local self = AegisPathfinder
	if self:CaptureKnownRecipes() > 0 and self.OnCraftDataChanged then
		self:OnCraftDataChanged(true)
	end
end)
knownDriver:RegisterEvent("TRADE_SKILL_SHOW")
knownDriver:RegisterEvent("TRADE_SKILL_UPDATE")
knownDriver:RegisterEvent("CRAFT_SHOW")
knownDriver:RegisterEvent("CRAFT_UPDATE")
knownDriver:SetScript("OnEvent", function() this:Show() end)
AegisPathfinder.knownRecipeDriver = knownDriver
