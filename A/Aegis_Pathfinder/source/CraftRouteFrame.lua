--[[
	CraftRouteFrame.lua -- the crafting route window, and loading a route as a
	guide.

	The planner (CraftPlanner.lua) works out the cheapest way from your skill
	to 300 at today's prices. This shows it: the total, what it is made of,
	and a step per recipe -- the skill band, how many crafts, what they need
	and what they cost -- with a scan button for the auction house and a
	button that turns the route into a guide.

	The guide it makes keeps everything the authored profession guide knows
	that prices do not change: the trainers for each rank, the level each
	rank needs, the Expert cookbook, the Artisan quests. Those steps are
	placed where your skill cap runs out; the crafts in between are the
	planner's. It is saved per character, so it is still there after a
	reload, and it is replaced when you plan again.
]]

local AegisPathfinder = AegisPathfinder
local Theme = AegisPathfinder.Theme

-- Layout, in one table: see the 32-upvalue note in CONTRIBUTING.md.
local L = {
	WIDTH = 360, PAD = 12, ROW_H = 30, MAX_ROWS = 8, BUTTON_H = 22, SCROLL_W = 10,
	CHROME_TOP = 30 + 18,
}
L.PICK_TOP = L.CHROME_TOP + 8
L.TOTAL_TOP = L.PICK_TOP + 30 + 8
L.BREAK_TOP = L.TOTAL_TOP + 22
L.STATUS_TOP = L.BREAK_TOP + 14
L.LIST_TOP = L.STATUS_TOP + 14 + 10
L.SWITCH_H = 22
L.FOOT_H = L.BUTTON_H + L.PAD * 2
L.HEIGHT = L.LIST_TOP + L.MAX_ROWS * L.ROW_H + 8 + L.SWITCH_H + L.FOOT_H

local rows = {}
local offset = 0
-- Past any skill: where a block with nowhere earlier to go is placed.
-- (math.huge is Lua 5.1; the client has 5.0.)
local P_END = 1e9

--[[ Money. ]]

--- "12g 4s 97c", leaving out units that are zero: "2s", "3g 5c". Past a
--- hundred gold the copper is noise and is left off.
function AegisPathfinder.FormatCopper(copper)
	if not copper then return "?" end
	local sign = ""
	if copper < 0 then sign, copper = "-", -copper end
	copper = math.floor(copper + 0.5)
	local g = math.floor(copper / 10000)
	local s = math.floor(math.mod(copper, 10000) / 100)
	local c = math.mod(copper, 100)
	if g >= 100 then c = 0 end
	local parts = {}
	if g > 0 then table.insert(parts, g .. "g") end
	if s > 0 then table.insert(parts, s .. "s") end
	if c > 0 or table.getn(parts) == 0 then table.insert(parts, c .. "c") end
	return sign .. table.concat(parts, " ")
end
local Money = AegisPathfinder.FormatCopper

--[[ Which profession, from where. ]]

--- The profession an authored or planned profession guide is for.
function AegisPathfinder:GuideProfession(guideName)
	if not guideName or self:GetGuideCategory(guideName) ~= "profession" then return nil end
	local _, _, name = string.find(guideName, "^(.-) %(")
	if name and self:GetRecipeBook(name) then return name end
	return nil
end

--- The profession the window opens on: the guide you are reading, else the
--- last one planned, else the first you have.
function AegisPathfinder:DefaultCraftProfession()
	local fromGuide = self:GuideProfession(self.db and self.db.char.currentguide)
	if fromGuide then return fromGuide end
	local last = self.db and self.db.char.craftprofession
	if last and self:GetRecipeBook(last) then return last end
	local all = self:GetPlannedProfessions()
	for _, name in ipairs(all) do
		if self:GetSkillRank(name) then return name end
	end
	return all[1]
end

function AegisPathfinder:CurrentCraftProfession()
	return self.craftprofession or self:DefaultCraftProfession()
end

--[[ The current plan, worked out once per change of input.

	Planning a profession is a few hundred thousand small steps -- quick,
	but not something to do on every repaint. It is redone when the
	profession, your skill, the sell-back setting, prices or known recipes
	change, and not otherwise.
]]
local planned = { key = nil, route = nil, why = nil }
local dataVersion = 0

function AegisPathfinder:GetCraftPlan()
	local profession = self:CurrentCraftProfession()
	if not profession then return nil, "There is no recipe data." end
	local from = self:GetSkillRank(profession) or 1
	local sellBack = self.db.char.craftsellback ~= false
	local key = table.concat({ profession, from, tostring(sellBack), dataVersion }, "|")
	if planned.key ~= key then
		planned.key = key
		planned.route, planned.why = self:PlanCraftRoute(profession, from, 300, { sellBack = sellBack })
	end
	return planned.route, planned.why, profession
end

--- Prices or known recipes changed (`replan`), or only the scan's progress.
function AegisPathfinder:OnCraftDataChanged(replan)
	if replan then dataVersion = dataVersion + 1 end
	local frame = self.craftframe
	if frame and frame:IsVisible() then frame.dirty = true end
end

--[[ What to scan.

	Every reagent and recipe book the profession could use and no merchant
	sells: the route's own first (so a scan cut short still prices what
	matters most), then the rest, which is what lets the planner find a
	cheaper recipe than the one it has now.
]]
function AegisPathfinder:GetCraftScanItems(profession, route)
	local recipes = self:GetRecipeBook(profession)
	if not recipes then return {} end
	local known = self:GetKnownRecipes(profession)
	local out, seen = {}, {}
	local function Add(item)
		if item and not seen[item] and not string.find(item, "^Item #")
			and not self:MerchantBuyPrice(item) then
			seen[item] = true
			table.insert(out, item)
		end
	end
	for _, step in ipairs(route and route.steps or {}) do
		for _, r in ipairs(step.recipe.reagents) do Add(self.CraftReagentName(r)) end
		if step.recipe.book and not known[step.name] then Add(step.recipe.book) end
	end
	for _, recipe in ipairs(recipes) do
		local usable = known[recipe.name] or not (recipe.skip or recipe.learn == "drop" or recipe.learn == "special")
		if usable and not recipe.skip then
			for _, r in ipairs(recipe.reagents) do Add(self.CraftReagentName(r)) end
			if recipe.book and not known[recipe.name] then Add(recipe.book) end
		end
	end
	return out
end

--[[ How a step's recipe is learned, in words. ]]

function AegisPathfinder:CraftLearnText(step, profession)
	local recipe = step.recipe
	if self:GetKnownRecipes(profession)[recipe.name] then return "You know this recipe" end
	local paid = step.learnPaid and step.learnPaid > 0 and Money(step.learnPaid) or nil
	if recipe.learn == "trainer" then
		return paid and string.format("Trainer, %s%s", recipe.estimated and "about " or "", paid) or "Trainer"
	elseif recipe.learn == "book" then
		local where = self:MerchantBuyPrice(recipe.book) and "a vendor" or "the auction house"
		return paid and string.format("%s, from %s, %s", recipe.book, where, paid)
			or string.format("%s, from %s", recipe.book, where)
	elseif recipe.learn == "quest" then
		return "A quest reward"
	end
	return "You know this recipe"
end

--- What one craft costs, in words -- or that some of it has no price yet,
--- rather than the planner's stand-in for an unknown price.
function AegisPathfinder:CraftEachText(step)
	if step.guessed then
		return "No price yet for " .. table.concat(step.guessed, ", ") .. "."
	end
	return "About " .. Money(step.perCraft) .. " a craft."
end

-- "2 Silverleaf, Empty Vial": one craft's reagents.
local function ReagentLine(recipe)
	local parts = {}
	for _, r in ipairs(recipe.reagents) do
		local name = AegisPathfinder.CraftReagentName(r)
		table.insert(parts, r.qty > 1 and (r.qty .. " " .. name) or name)
	end
	return table.concat(parts, ", ")
end
AegisPathfinder.CraftReagentLine = ReagentLine

--[[ The route as a guide. ]]

local function GuideName(profession)
	return profession .. " (cheapest route)"
end

-- The authored guide for a profession: "Alchemy (1-300)".
local function AuthoredGuide(self, profession)
	for name, guide in pairs(self.qsplusguides or {}) do
		if guide.category == "Profession" and not guide.planned
			and string.find(name, "^" .. string.gsub(profession, "(%W)", "%%%1") .. " %(") then
			return guide
		end
	end
	return nil
end

-- The authored guide's steps that are not crafts, in blocks, each placed at
-- the skill it belongs at. A block that raises the skill cap goes where the
-- old cap runs out (Journeyman at 75, Expert at 150, Artisan at 225); a
-- block that raises no cap stays where the authored route had it.
local function Gates(authored)
	local blocks, current, at = {}, nil, 0
	local intro = true
	for _, step in ipairs(authored and authored.steps or {}) do
		if step.skill then
			intro = false
			current = nil
			at = step.skill.to or at
		elseif not (intro and step.type == "NOTE") then
			intro = false
			if not current then
				current = { steps = {}, at = at }
				table.insert(blocks, current)
			end
			table.insert(current.steps, step)
			if step.rank and step.rank.cap then
				local where = step.rank.cap - 75
				if not current.cap or where < current.at then current.at = where end
				current.cap = true
			end
		end
	end
	return blocks
end

-- The skill-up chances of `recipe` from `from` to `to`, summed: how many
-- crafts that stretch is expected to take.
local function ExpectedCrafts(self, recipe, from, to)
	local n = 0
	for s = from, to - 1 do
		local p = self:CraftSkillChance(recipe, s)
		if p > 0 then n = n + 1 / p end
	end
	return n
end

local function CraftStep(self, route, step, from, to, trainers)
	local profession = route.profession
	local recipe = step.recipe
	local crafts = step.crafts
	if from ~= step.from or to ~= step.to then
		crafts = math.ceil(ExpectedCrafts(self, recipe, from, to) - 1e-6)
	end
	local reagents = {}
	for _, r in ipairs(recipe.reagents) do
		table.insert(reagents, { item = self.CraftReagentName(r), qty = r.qty })
	end
	local learn = self:CraftLearnText(step, profession)
	local note = string.format("Takes you from %d to %d. %s", from, to, self:CraftEachText(step))
	local out = {
		type = "USE",
		title = string.format("Craft %dx %s", crafts, recipe.name),
		note = note .. " Learn it: " .. learn .. ".",
		skill = { profession = profession, from = from, to = to },
		craft = { item = recipe.name, count = crafts },
		reagents = reagents,
		source = learn,
	}
	-- A trainer recipe you do not know yet: the trainers are who the step
	-- sends you to, as the rank steps do.
	if recipe.learn == "trainer" and trainers and not self:GetKnownRecipes(profession)[recipe.name] then
		out.npcs = trainers
	end
	return out
end

--- The route as a QuestShell+ guide table.
function AegisPathfinder:BuildCraftGuide(route)
	local profession = route.profession
	local authored = AuthoredGuide(self, profession)
	local blocks = Gates(authored)
	local myfaction = self.myfaction or UnitFactionGroup("player")

	local steps = {
		{
			type = "NOTE",
			title = GuideName(profession),
			note = string.format("Planned at %s prices: %s for %d crafts, skill %d to %d. Plan it again from the crafting route window (/apg craft) whenever prices move.",
				date and date("%d %b") or "today's",
				"about " .. Money(route.total),
				route.crafts, route.from, route.reached),
		},
	}

	-- Craft steps split wherever a block lands inside them.
	local cuts = {}
	for _, block in ipairs(blocks) do cuts[block.at] = true end

	local b, trainers = 1, nil
	local function PlaceBlocksUpTo(skill)
		while blocks[b] and blocks[b].at <= skill do
			for _, s in ipairs(blocks[b].steps) do
				table.insert(steps, s)
				if s.type == "TRAIN" and s.npcs and (not s.faction or s.faction == "Both" or s.faction == myfaction) then
					trainers = s.npcs
				end
			end
			b = b + 1
		end
	end

	for _, step in ipairs(route.steps) do
		local from = step.from
		PlaceBlocksUpTo(from)
		for cut = step.from + 1, step.to - 1 do
			if cuts[cut] then
				table.insert(steps, CraftStep(self, route, step, from, cut, trainers))
				from = cut
				PlaceBlocksUpTo(cut)
			end
		end
		table.insert(steps, CraftStep(self, route, step, from, step.to, trainers))
	end
	PlaceBlocksUpTo(P_END)

	if route.reached < route.to then
		table.insert(steps, {
			type = "NOTE",
			title = "Where the route stops",
			note = string.format("Nothing the planner could use goes past %d. Scan prices at the auction house, or learn more recipes, and plan again.", route.reached),
		})
	end

	return { faction = "Both", category = "Profession", planned = true, steps = steps }
end

local function Register(self, profession, guide)
	self:RegisterQuestShellPlusGuide(GuideName(profession), guide)
end

--- Turn a route into a guide and open it.
function AegisPathfinder:LoadCraftGuide(route)
	route = route or self:GetCraftPlan()
	if not route or table.getn(route.steps) == 0 then
		self:Print("There is no route to load.")
		return false
	end
	local profession = route.profession
	local guide = self:BuildCraftGuide(route)
	self.db.char.craftguides = self.db.char.craftguides or {}
	self.db.char.craftguides[profession] = guide
	Register(self, profession, guide)

	local name = GuideName(profession)
	local tab = self.FindTab and self:FindTab(name)
	if tab and tab == (self.db.char.activetab or 1) then
		-- Already on it: read the new steps in place.
		self:LoadGuide(name)
		self:UpdateStatusFrame()
	elseif tab then
		self:SwitchToTab(tab)
		self:LoadGuide(name)
		self:UpdateStatusFrame()
	elseif self.OpenGuideTab then
		self:OpenGuideTab(name)
	else
		self:LoadGuide(name)
	end
	self:Print(string.format("Loaded %s: %d crafts, about %s.", name, route.crafts, Money(route.total)))
	return true
end

--- Put back the routes loaded as guides in earlier sessions. Called while
--- the guides register, so a planned guide you were on reopens like any other.
function AegisPathfinder:RestoreCraftGuides()
	for profession, guide in pairs(self.db.char.craftguides or {}) do
		if type(guide) == "table" and guide.steps then Register(self, profession, guide) end
	end
end

--[[ The window. ]]

local function Scroll(frame, delta)
	frame.slider:Nudge(delta)
end

function AegisPathfinder:CreateCraftRoutePanel()
	local frame = CreateFrame("Frame", "AegisPathfinderCraftRoute", UIParent)
	self.craftframe = frame
	frame:SetFrameStrata("DIALOG")
	frame:SetWidth(L.WIDTH)
	frame:SetHeight(L.HEIGHT)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	Theme:Panel(frame, "panel")
	frame:Hide()

	Theme:Chrome(frame, "Crafting route", Theme:PositionSaver("craftframe"))

	local pick = Theme:Dropdown(frame, 170, function(value)
		AegisPathfinder.craftprofession = value
		AegisPathfinder.db.char.craftprofession = value
		offset = 0
		AegisPathfinder:UpdateCraftRoutePanel()
	end)
	pick:SetPoint("TOPLEFT", frame, "TOPLEFT", L.PAD, -L.PICK_TOP)
	frame.pick = pick

	local range = frame:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(range, "display", 12)
	range:SetPoint("LEFT", pick, "RIGHT", 10, 0)
	range:SetPoint("RIGHT", frame, "RIGHT", -L.PAD, 0)
	range:SetJustifyH("RIGHT")
	Theme:TextColor(range, "textDim")
	frame.range = range

	local total = frame:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(total, "display", 18)
	total:SetPoint("TOPLEFT", frame, "TOPLEFT", L.PAD, -L.TOTAL_TOP)
	Theme:TextColor(total, "gold")
	frame.total = total

	local crafts = frame:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(crafts, "body", 11)
	crafts:SetPoint("BOTTOMLEFT", total, "BOTTOMRIGHT", 8, 2)
	Theme:TextColor(crafts, "textDim")
	frame.crafts = crafts

	local function Line(top)
		local fs = frame:CreateFontString(nil, "OVERLAY")
		Theme:SetFont(fs, "body", 10)
		fs:SetPoint("TOPLEFT", frame, "TOPLEFT", L.PAD, -top)
		fs:SetPoint("RIGHT", frame, "RIGHT", -L.PAD, 0)
		fs:SetHeight(12)
		fs:SetJustifyH("LEFT")
		Theme:TextColor(fs, "textDim")
		return fs
	end
	frame.breakdown = Line(L.BREAK_TOP)
	frame.status = Line(L.STATUS_TOP)
	Theme:Divider(frame, frame.status, "BOTTOMLEFT", 0, -5)

	for i = 1, L.MAX_ROWS do
		local row = CreateFrame("Button", nil, frame)
		row:SetHeight(L.ROW_H)
		row:SetPoint("TOPLEFT", frame, "TOPLEFT", L.PAD, -(L.LIST_TOP + (i - 1) * L.ROW_H))
		row:SetPoint("RIGHT", frame, "RIGHT", -L.PAD - L.SCROLL_W - 6, 0)

		local hl = row:CreateTexture(nil, "HIGHLIGHT")
		hl:SetTexture(Theme.texture.solid)
		hl:SetAllPoints(row)
		hl:SetVertexColor(1, 1, 1, 0.04)

		local band = row:CreateFontString(nil, "OVERLAY")
		Theme:SetFont(band, "display", 11)
		band:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -2)
		band:SetWidth(52)
		band:SetJustifyH("LEFT")
		Theme:TextColor(band, "accent")

		local count = row:CreateFontString(nil, "OVERLAY")
		Theme:SetFont(count, "display", 11)
		count:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -2)
		count:SetJustifyH("RIGHT")
		Theme:TextColor(count, "gold")

		local name = row:CreateFontString(nil, "OVERLAY")
		Theme:SetFont(name, "body", 11)
		name:SetPoint("TOPLEFT", band, "TOPRIGHT", 4, 0)
		name:SetPoint("RIGHT", count, "LEFT", -6, 0)
		name:SetHeight(13)
		name:SetJustifyH("LEFT")

		local spend = row:CreateFontString(nil, "OVERLAY")
		Theme:SetFont(spend, "body", 10)
		spend:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 3)
		spend:SetJustifyH("RIGHT")
		Theme:TextColor(spend, "textDim")

		local mats = row:CreateFontString(nil, "OVERLAY")
		Theme:SetFont(mats, "body", 10)
		mats:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 56, 3)
		mats:SetPoint("RIGHT", spend, "LEFT", -6, 0)
		mats:SetHeight(12)
		mats:SetJustifyH("LEFT")
		Theme:TextColor(mats, "textDim")

		row.band, row.name, row.count, row.mats, row.spend = band, name, count, mats, spend
		row:SetScript("OnEnter", function() AegisPathfinder:ShowCraftStepTip(this) end)
		row:SetScript("OnLeave", function() Theme:HideTip(this) end)
		row:EnableMouseWheel(true)
		row:SetScript("OnMouseWheel", function() Scroll(frame, -(arg1 or 0)) end)
		rows[i] = row
	end

	local slider = Theme:ScrollBar(frame, L.SCROLL_W)
	slider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -(L.LIST_TOP + L.SCROLL_W))
	slider:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, L.FOOT_H + L.SWITCH_H + 8 + L.SCROLL_W)
	slider:SetMinMaxValues(0, 0)
	slider:SetValueStep(1)
	slider:SetValue(0)
	slider:SetScript("OnValueChanged", function()
		if slider.updating then return end
		offset = math.floor(arg1 or slider:GetValue() or 0)
		AegisPathfinder:UpdateCraftRoutePanel()
	end)
	frame.slider = slider
	frame:EnableMouseWheel(true)
	frame:SetScript("OnMouseWheel", function() Scroll(frame, -(arg1 or 0)) end)

	local sell = Theme:Switch(frame, "Say what a merchant pays for what is left over", function(on)
		AegisPathfinder.db.char.craftsellback = on
		AegisPathfinder:UpdateCraftRoutePanel()
	end)
	sell:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", L.PAD, L.FOOT_H)
	sell:SetPoint("RIGHT", frame, "RIGHT", -L.PAD, 0)
	Theme:SetFont(sell.label, "body", 11)
	frame.sell = sell

	local half = (L.WIDTH - L.PAD * 2 - 6) / 2
	local scan = Theme:PanelButton(frame, "Scan prices", half, L.BUTTON_H)
	scan:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", L.PAD, L.PAD)
	scan:SetScript("OnClick", function() AegisPathfinder:ToggleCraftScan() end)
	local enter, leave = scan:GetScript("OnEnter"), scan:GetScript("OnLeave")
	scan:SetScript("OnEnter", function()
		enter()
		Theme:ShowTip(this, "BOTTOM", AegisPathfinder:CraftScanHint())
	end)
	scan:SetScript("OnLeave", function() leave() Theme:HideTip(this) end)
	frame.scan = scan

	local load = Theme:PanelButton(frame, "Load as guide", half, L.BUTTON_H)
	load:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -L.PAD, L.PAD)
	load:SetScript("OnClick", function() AegisPathfinder:LoadCraftGuide() end)
	local lenter, lleave = load:GetScript("OnEnter"), load:GetScript("OnLeave")
	load:SetScript("OnEnter", function()
		lenter()
		Theme:ShowTip(this, "BOTTOM", "Follow this route as a guide", {
			"Your trainers and rank steps stay; the crafts are these. Planning again and loading replaces it.",
		})
	end)
	load:SetScript("OnLeave", function() lleave() Theme:HideTip(this) end)
	frame.load = load

	-- Scan progress and new known recipes repaint at most once a frame.
	frame:SetScript("OnUpdate", function()
		if this.dirty then AegisPathfinder:UpdateCraftRoutePanel() end
	end)
	frame:SetScript("OnShow", function()
		offset = 0
		local guide = AegisPathfinder.objectiveframe
		if not Theme:RestorePosition(this, "craftframe") and guide and AegisPathfinder.GetQuadrant then
			local _, _, hhalf = AegisPathfinder.GetQuadrant(guide)
			this:ClearAllPoints()
			if hhalf == "LEFT" then
				this:SetPoint("TOPLEFT", guide, "TOPRIGHT", 8, 0)
			else
				this:SetPoint("TOPRIGHT", guide, "TOPLEFT", -8, 0)
			end
		end
		AegisPathfinder:UpdateCraftRoutePanel()
	end)

	table.insert(UISpecialFrames, "AegisPathfinderCraftRoute")
end

-- The rows' steps, for their tooltips.
local shownSteps = {}

function AegisPathfinder:ShowCraftStepTip(row)
	local step = row.step
	if not step then return end
	local profession = self:CurrentCraftProfession()
	local lines = {
		string.format("%d crafts (%.1f expected). %s", step.crafts, step.expected, self:CraftEachText(step)),
		"Learn it: " .. self:CraftLearnText(step, profession),
		"Each craft: " .. ReagentLine(step.recipe),
	}
	local buy = {}
	for item, n in pairs(step.buys or {}) do table.insert(buy, n .. " " .. item) end
	table.sort(buy)
	if table.getn(buy) > 0 then table.insert(lines, "To buy: " .. table.concat(buy, ", ")) end
	local made = {}
	for item, n in pairs(step.made or {}) do table.insert(made, n .. " " .. item) end
	table.sort(made)
	if table.getn(made) > 0 then table.insert(lines, "Made first: " .. table.concat(made, ", ")) end
	if step.unpriced then table.insert(lines, "No price yet: " .. table.concat(step.unpriced, ", ")) end
	Theme:ShowTip(row, "RIGHT", string.format("%s, %d to %d", step.name, step.from, step.to), lines)
end

local function ClearRows()
	for _, row in ipairs(rows) do
		row.step = nil
		row:Hide()
	end
end

-- A scan's age in words: "20 minutes ago", "3 hours ago", "2 days ago".
local function Age(seconds)
	if seconds < 3600 then return string.format("%d min ago", math.max(1, math.floor(seconds / 60))) end
	if seconds < 86400 then return string.format("%d h ago", math.floor(seconds / 3600)) end
	return string.format("%d days ago", math.floor(seconds / 86400))
end

--- Where the prices come from, and what is missing, for the status line.
function AegisPathfinder:CraftPriceStatus(route)
	local scanning, done, of = self:IsCraftScanning()
	if scanning then
		return string.format("Scanning the auction house: %d of %d...", done, of), "accent"
	end
	local unpriced = route and table.getn(route.unpriced or {}) or 0
	if route and route.lenient and unpriced > 0 then
		return string.format("%d reagent%s ha%s no price yet. Scan at the auction house.",
			unpriced, unpriced == 1 and "" or "s", unpriced == 1 and "s" or "ve"), "gold"
	end
	local sources = {}
	local newest
	for _, entry in pairs(self.db.realm and self.db.realm.craftprices or {}) do
		if entry.t and (not newest or entry.t > newest) then newest = entry.t end
	end
	if newest then table.insert(sources, "your scan " .. Age(time() - newest)) end
	if AegisExchange and AegisExchange.craft then table.insert(sources, "Aegis: Exchange") end
	if table.getn(sources) == 0 then
		return "No auction prices yet: merchant prices only. Scan at the auction house.", "gold"
	end
	return "Auction prices from " .. table.concat(sources, " and ") .. ".", "textDim"
end

function AegisPathfinder:CraftScanHint()
	local scanning = self:IsCraftScanning()
	if scanning then return "Stop the scan", { "Prices found so far are kept." } end
	if not self:AtAuctionHouse() then
		return "Open the auction house to scan", {
			"Searches for each reagent this profession uses, and keeps every listing so large amounts are priced right.",
		}
	end
	local route, _, profession = self:GetCraftPlan()
	local n = table.getn(self:GetCraftScanItems(profession, route))
	return string.format("Scan the auction house: %d searches", n), {
		"One per reagent and recipe, this route's first, so stopping early still prices what matters most. Items searched in the last half hour are skipped.",
		"A minute or two with the AuctionQueryThrottle DLL; without it the client allows a search every few seconds.",
	}
end

function AegisPathfinder:ToggleCraftScan()
	if self:IsCraftScanning() then return self:StopCraftScan() end
	local route, _, profession = self:GetCraftPlan()
	local n, why = self:StartCraftScan(self:GetCraftScanItems(profession, route))
	if not n then
		self:Print(why)
	elseif n == 0 then
		self:Print("Every reagent was searched in the last half hour; nothing to scan.")
	else
		self:Print(string.format("Scanning %d items for %s. Leave the auction house open until it is done.", n, profession))
	end
	self:UpdateCraftRoutePanel()
end

function AegisPathfinder:UpdateCraftRoutePanel()
	local frame = self.craftframe
	if not frame or not frame:IsVisible() then return end
	frame.dirty = nil

	local items = {}
	for _, name in ipairs(self:GetPlannedProfessions()) do
		local rank = self:GetSkillRank(name)
		table.insert(items, { value = name, label = rank and string.format("%s (%d)", name, rank) or name })
	end
	frame.pick:SetItems(items)

	local route, why, profession = self:GetCraftPlan()
	frame.pick:SetValue(profession)
	frame.sell:SetOn(self.db.char.craftsellback ~= false)
	frame.scan:SetText(self:IsCraftScanning() and "Stop scan" or "Scan prices")

	local status, color = self:CraftPriceStatus(route)
	frame.status:SetText(status)
	Theme:TextColor(frame.status, color)

	if not route then
		frame.range:SetText("")
		frame.total:SetText("")
		frame.crafts:SetText("")
		frame.breakdown:SetText(why or "")
		ClearRows()
		frame.slider:Hide()
		return
	end

	frame.range:SetText(string.format("SKILL %d TO %d", route.from, route.reached))
	frame.total:SetText(Money(route.total))
	Theme:TextColor(frame.total, "gold")
	frame.crafts:SetText(string.format("%d crafts", route.crafts))

	local parts = { "Reagents " .. Money(route.buyTotal), "recipes " .. Money(route.learnTotal) }
	-- What is left over is yours to sell or not; it is not off the cost.
	if route.credit > 0 then table.insert(parts, "leftovers sell for about " .. Money(route.credit)) end
	local unpriced = table.getn(route.unpriced or {})
	if unpriced > 0 then table.insert(parts, "+ " .. unpriced .. " unpriced") end
	if route.reached < route.to then table.insert(parts, "stops at " .. route.reached) end
	frame.breakdown:SetText(table.concat(parts, " \194\183 "))

	shownSteps = route.steps
	local total = table.getn(shownSteps)
	local maxOffset = math.max(0, total - L.MAX_ROWS)
	if offset > maxOffset then offset = maxOffset end
	if offset < 0 then offset = 0 end
	if maxOffset > 0 then
		frame.slider:Show()
		frame.slider.updating = true
		frame.slider:SetMinMaxValues(0, maxOffset)
		frame.slider:SetValue(offset)
		frame.slider.updating = nil
	else
		frame.slider:Hide()
	end

	for i, row in ipairs(rows) do
		local step = shownSteps[i + offset]
		row.step = step
		if step then
			row:Show()
			row.band:SetText(string.format("%d-%d", step.from, step.to))
			row.name:SetText(step.name)
			row.count:SetText("x" .. step.crafts)
			row.mats:SetText(ReagentLine(step.recipe))
			row.spend:SetText(Money(step.spend))
			if step.unpriced then
				Theme:TextColor(row.name, "gold")
				Theme:TextColor(row.spend, "gold")
			else
				Theme:TextColor(row.name, "text")
				Theme:TextColor(row.spend, "textDim")
			end
		else
			row:Hide()
		end
	end
end

function AegisPathfinder:ToggleCraftRoutePanel()
	if not self.craftframe then self:CreateCraftRoutePanel() end
	if self.craftframe:IsShown() then
		self.craftframe:Hide()
	else
		self.craftprofession = nil
		self.craftframe:Show()
	end
end
