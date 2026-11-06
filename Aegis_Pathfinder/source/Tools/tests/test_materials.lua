--[[
	Tests for the shopping list, and for sending it to Aegis: Exchange.

	The number this panel shows is the whole point of it: reagents for the
	steps still AHEAD of you, not the reference document's total from skill 1.
	Get that wrong and it is worse than no list, because it looks authoritative.

	The same goes for what reaches Exchange: its shopping list multiplies each
	project's reagents by how many it is set to make, and that product has to
	land on the totals shown here -- and has to stop counting a craft the
	moment the guide moves past it, or Exchange tells you to buy again what
	you have already used.

	Run:  lua5.1 Tools/tests/test_materials.lua
]]

package.path = "Tools/tests/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

UISpecialFrames = {}

-- A clock the test moves, so the bag-update throttle can be stepped past.
local now = 100
GetTime = function() return now end

local printed = {}
AegisPathfinder = {
	actions = {}, quests = {}, tags = {}, turnedin = {},
	current = 1,
	db = { char = { currentguide = "Alchemy (1-300)" }, profile = {} },
}
function AegisPathfinder:Debug() end
function AegisPathfinder:Print(msg) table.insert(printed, msg) end
function AegisPathfinder.trim(s) return (string.gsub(s or "", "^%s*(.-)%s*$", "%1")) end
function AegisPathfinder.select(index, ...)
	if index == "#" then return table.getn(arg) end
	return arg[index]
end
function AegisPathfinder:GetObjectiveStatus(i)
	return self.turnedin[self.quests[i]]
end
function AegisPathfinder:GetObjectiveInfo(i)
	if not self.actions[i] then return end
	return self.actions[i], (string.gsub(self.quests[i], "@.*@", ""))
end

dofile("Theme.lua")
dofile("Parser.lua")
dofile("Professions.lua")
dofile("MaterialsFrame.lua")
local Theme = AegisPathfinder.Theme

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end

local function lastPrint() return printed[table.getn(printed)] or "" end

-- A three-step craft route sharing a reagent across two of the steps.
AegisPathfinder.actions = { "USE", "USE", "USE" }
AegisPathfinder.quests = { "Craft A@1@", "Craft B@2@", "Craft C@3@" }
local ROUTE = {
	"|SKILL|Alchemy 1 63| |CRAFT|40 Minor Healing Potion| |MATS|1x Peacebloom, 1x Silverleaf, 1x Empty Vial|",
	"|SKILL|Alchemy 63 80| |CRAFT|10 Elixir of Minor Agility| |MATS|2x Swiftthistle, 1x Empty Vial|",
	"|SKILL|Alchemy 80 90| |CRAFT|5 Blackmouth Oil| |MATS|2x Oily Blackmouth|",
}
local function route()
	AegisPathfinder.tags = { ROUTE[1], ROUTE[2], ROUTE[3] }
end
route()

-- Arithmetic -----------------------------------------------------------------

local function totals()
	local out = {}
	for _, e in ipairs(AegisPathfinder:GetRemainingMaterials() or {}) do
		out[e.item] = e.need
	end
	return out
end

local t = totals()
-- 40 crafts x 1 + 10 crafts x 1 = 50 vials across the two steps that use them.
check(t["Empty Vial"] == 50, "a reagent used by two steps should be summed: expected 50, got %s",
	tostring(t["Empty Vial"]))
check(t["Peacebloom"] == 40, "40 crafts x 1 Peacebloom = 40, got %s", tostring(t["Peacebloom"]))
check(t["Swiftthistle"] == 20, "10 crafts x 2 Swiftthistle = 20, got %s", tostring(t["Swiftthistle"]))
check(t["Oily Blackmouth"] == 10, "5 crafts x 2 = 10, got %s", tostring(t["Oily Blackmouth"]))

-- The whole point: completed steps drop out of the total.
AegisPathfinder.turnedin["Craft A@1@"] = true
t = totals()
check(t["Peacebloom"] == nil,
	"a finished step's reagents must leave the list -- you already bought them")
check(t["Empty Vial"] == 10,
	"vials should drop to the 10 the remaining step needs, got %s", tostring(t["Empty Vial"]))

AegisPathfinder.turnedin["Craft B@2@"] = true
AegisPathfinder.turnedin["Craft C@3@"] = true
check(AegisPathfinder:GetRemainingMaterials() == nil,
	"with everything done there is nothing to buy, so the list is nil rather than empty")

AegisPathfinder.turnedin = {}

-- A guide with no |MATS| tags at all.
AegisPathfinder.tags = { "|QID|41187|", "|QID|41188|", "|N|just a note|" }
check(AegisPathfinder:GetRemainingMaterials() == nil,
	"a quest guide has no materials and must not invent an empty list")
check(not AegisPathfinder:GuideHasMaterials(),
	"and the panel is told there is no shopping list to offer")

route()
check(AegisPathfinder:GuideHasMaterials(), "a craft guide has a shopping list to offer")

-- A |MATS| tag with no |CRAFT| count means one craft, not zero.
AegisPathfinder.tags[3] = "|MATS|3x Mageweave Cloth|"
t = totals()
check(t["Mageweave Cloth"] == 3,
	"a step with no craft count should count as one craft, got %s",
	tostring(t["Mageweave Cloth"]))
route()

-- Which craft "this step" means ----------------------------------------------

check(AegisPathfinder:GetShoppingStep() == 1, "the step you are on, when it is a craft")
AegisPathfinder.turnedin["Craft A@1@"] = true
check(AegisPathfinder:GetShoppingStep() == 2, "otherwise the next craft that is not done")
AegisPathfinder.turnedin = {}
AegisPathfinder.tags = { "|QID|1|", ROUTE[2], ROUTE[3] }
check(AegisPathfinder:GetShoppingStep() == 2,
	"a trainer visit or a note before the craft looks ahead to it")
route()

-- The bags ----------------------------------------------------------------------

stub.bags = {
	[0] = { [1] = { id = 2447, name = "Peacebloom", count = 12 },
	        [5] = { id = 3371, name = "Empty Vial", count = 20 } },
	[2] = { [3] = { id = 2447, name = "Peacebloom", count = 8 },
	        [9] = { id = 765, name = "Silverleaf", count = 40 } },
}
local held = AegisPathfinder:CountBags()
check(held["Peacebloom"] == 20, "stacks in two bags add up: 12 + 8 = 20, got %s", tostring(held["Peacebloom"]))
check(held["Silverleaf"] == 40, "a full stack counts, got %s", tostring(held["Silverleaf"]))
check(held["Swiftthistle"] == nil, "and what is not carried is not counted")
check(AegisPathfinder:ItemIdByName("Peacebloom") == 2447,
	"the bags give the item's id away, got %s", tostring(AegisPathfinder:ItemIdByName("Peacebloom")))

local function byItem(list)
	local out = {}
	for _, e in ipairs(list or {}) do out[e.item] = e end
	return out
end

local stepList, forStep = AegisPathfinder:GetShoppingList("step")
local s = byItem(stepList)
check(forStep == 1 and s["Peacebloom"] and s["Peacebloom"].need == 40 and s["Peacebloom"].have == 20,
	"this step: 40 Peacebloom needed and 20 carried, got %s/%s",
	tostring(s["Peacebloom"] and s["Peacebloom"].have), tostring(s["Peacebloom"] and s["Peacebloom"].need))
check(s["Swiftthistle"] == nil, "this step lists only this step's reagents")
local routeList = byItem(AegisPathfinder:GetShoppingList("route"))
check(routeList["Empty Vial"].need == 50 and routeList["Empty Vial"].have == 20,
	"the whole route: 50 vials needed, 20 carried")
check(routeList["Swiftthistle"].have == 0, "nothing carried reads as 0, not blank")

-- Panel ----------------------------------------------------------------------

AegisPathfinder:CreateMaterialsPanel()
local frame = AegisPathfinder.materialsframe

-- Beside Send to Exchange, the same profession planned at today's prices.
do
	local toggled = 0
	local real = AegisPathfinder.ToggleCraftRoutePanel
	AegisPathfinder.ToggleCraftRoutePanel = function() toggled = toggled + 1 end
	check(frame.cheapest and frame.cheapest:GetText() == "CHEAPEST ROUTE", "the list offers the cheapest route")
	this = frame.cheapest
	frame.cheapest:GetScript("OnClick")()
	check(toggled == 1, "which opens the crafting route window")
	AegisPathfinder.ToggleCraftRoutePanel = real
end
check(frame ~= nil, "the materials panel was not created")
check(not frame:IsShown(), "it starts hidden")

local function visibleRows()
	local out = {}
	for _, r in ipairs({ frame:GetChildren() }) do
		if r.qty and r.name and r:IsShown() and r.name:GetText() ~= "" then
			out[r.name:GetText()] = r
		end
	end
	return out
end

frame:Show()
AegisPathfinder:UpdateMaterialsPanel()
check(string.find(frame.subtitle:GetText(), "Alchemy", 1, true) ~= nil,
	"the whole-route subtitle names the guide, got '%s'", tostring(frame.subtitle:GetText()))
check(frame.tabs.route:IsActive() and not frame.tabs.step:IsActive(),
	"the whole route is the list it opens on")

local shown = visibleRows()
check(shown["Peacebloom"] and shown["Peacebloom"].qty:GetText() == "20/40",
	"a row reads have/need, got '%s'", tostring(shown["Peacebloom"] and shown["Peacebloom"].qty:GetText()))
check(shown["Silverleaf"] and shown["Silverleaf"].qty:GetText() == "40/40",
	"a covered row reads full, got '%s'", tostring(shown["Silverleaf"] and shown["Silverleaf"].qty:GetText()))
check(string.find(frame.subtitle:GetText(), "4 of 5 still to get", 1, true) ~= nil,
	"and the subtitle says how many are still short, got '%s'", tostring(frame.subtitle:GetText()))

-- Colour says the same: gold for short, the accent for covered.
local gold, accent = Theme.color.gold, Theme.color.accent
local pc = shown["Peacebloom"].qty.__color
local sc = shown["Silverleaf"].qty.__color
check(pc[1] == gold[1] and pc[2] == gold[2], "a short count is gold")
check(sc[1] == accent[1] and sc[2] == accent[2], "a covered count is the accent")

-- More in the bags than needed does not read as "60/40".
stub.bags[3] = { [1] = { id = 765, name = "Silverleaf", count = 20 } }
AegisPathfinder:UpdateMaterialsPanel()
check(visibleRows()["Silverleaf"].qty:GetText() == "40/40",
	"a surplus is shown as covered, not as more than needed, got '%s'",
	visibleRows()["Silverleaf"].qty:GetText())
stub.bags[3] = nil

-- Five reagents, five rows: the window is sized to its list.
local h5 = frame:GetHeight()
this = frame.tabs.step
frame.tabs.step:GetScript("OnClick")()
check(AegisPathfinder.db.profile.shoppingscope == "step", "the tab remembers the scope")
check(frame.tabs.step:IsActive() and not frame.tabs.route:IsActive(), "and lights up")
check(string.find(frame.subtitle:GetText(), "Craft A", 1, true) ~= nil,
	"this step names the craft, got '%s'", tostring(frame.subtitle:GetText()))
shown = visibleRows()
check(shown["Peacebloom"] and not shown["Swiftthistle"], "and lists only its reagents")
-- Three reagents is the fewest rows a list keeps, so it is a little smaller.
check(frame:GetHeight() < h5, "a shorter list is a smaller window: %s vs %s", frame:GetHeight(), h5)

-- Every craft done: this step has nothing to show, and says why.
AegisPathfinder.turnedin = { ["Craft A@1@"] = true, ["Craft B@2@"] = true, ["Craft C@3@"] = true }
AegisPathfinder:UpdateMaterialsPanel()
check(string.find(frame.subtitle:GetText(), "No crafting left", 1, true) ~= nil,
	"a finished route says so, got '%s'", tostring(frame.subtitle:GetText()))
AegisPathfinder.turnedin = {}
this = frame.tabs.route
frame.tabs.route:GetScript("OnClick")()

AegisPathfinder:ToggleMaterialsPanel()
check(not frame:IsShown(), "toggle hides a shown panel")
AegisPathfinder:ToggleMaterialsPanel()
check(frame:IsShown(), "toggle shows a hidden one")

-- Counts follow the bags, a burst at a time.
stub.bags[0][1].count = 40
this = frame
frame:GetScript("OnEvent")()
check(frame.dirty, "a bag update marks the list stale")
check(visibleRows()["Peacebloom"].qty:GetText() == "20/40", "without repainting inside the event")
frame:GetScript("OnUpdate")()
check(visibleRows()["Peacebloom"].qty:GetText() == "20/40",
	"nor straight after the last paint -- a burst is one repaint, not one per bag")
now = now + 1
frame:GetScript("OnUpdate")()
check(visibleRows()["Peacebloom"].qty:GetText() == "40/40",
	"a moment later it catches up, got '%s'", visibleRows()["Peacebloom"].qty:GetText())
check(not frame.dirty, "and is clean again")

-- A guide with nothing to buy says so rather than showing a blank panel.
AegisPathfinder.tags = { "|QID|1|", "|QID|2|", "|QID|3|" }
AegisPathfinder:UpdateMaterialsPanel()
check(string.find(frame.subtitle:GetText(), "no materials", 1, true) ~= nil,
	"an empty list should be explained, got '%s'", tostring(frame.subtitle:GetText()))

-- Updating a hidden panel must be a no-op, not an error.
frame:Hide()
local ok = pcall(function() AegisPathfinder:UpdateMaterialsPanel() end)
check(ok, "updating a hidden panel should be safe")

-- Where it opens ------------------------------------------------------------------

-- Beside the guide, on whichever side has room.
local guide = CreateFrame("Frame", "FakeGuide", UIParent)
guide:SetWidth(396); guide:SetHeight(300)
guide:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -40, -180)
AegisPathfinder.objectiveframe = guide
local quadrant = "RIGHT"
function AegisPathfinder.GetQuadrant() return "TOP" .. quadrant, "TOP", quadrant end

route()
this = frame
frame:GetScript("OnShow")()
local p, rel, rp, x = frame:GetPoint()
check(p == "TOPRIGHT" and rel == guide and rp == "TOPLEFT" and x == -8,
	"it pops out to the left of a guide on the right, got %s %s %s", tostring(p), tostring(rp), tostring(x))
quadrant = "LEFT"
frame:GetScript("OnShow")()
p, rel, rp, x = frame:GetPoint()
check(p == "TOPLEFT" and rel == guide and rp == "TOPRIGHT" and x == 8,
	"and to the right of one on the left, got %s %s %s", tostring(p), tostring(rp), tostring(x))

-- Dragged somewhere, it opens there -- it used to save the spot and forget it.
AegisPathfinder.db.profile.materialsframepoint = "TOPLEFT"
AegisPathfinder.db.profile.materialsframerel = "BOTTOMLEFT"
AegisPathfinder.db.profile.materialsframex = 300
AegisPathfinder.db.profile.materialsframey = 500
frame:GetScript("OnShow")()
p, rel, rp, x = frame:GetPoint()
check(p == "TOPLEFT" and rel == UIParent and rp == "BOTTOMLEFT" and x == 300,
	"a dragged window reopens where it was left, got %s %s %s", tostring(p), tostring(rp), tostring(x))
Theme:ForgetPosition("materialsframe")

-- Scrolling --------------------------------------------------------------------

-- More reagents than rows. The bar is the theme's -- UIPanelScrollBarTemplate
-- brought Blizzard's arrows and knob -- and it moves a row at a time.
local many = {}
for i = 1, 25 do table.insert(many, string.format("1x Reagent %02d", i)) end
AegisPathfinder.tags = {
	"|SKILL|Alchemy 1 10| |CRAFT|1 Thing| |MATS|" .. table.concat(many, ", ") .. "|",
	"|QID|2|", "|QID|3|",
}
frame:Show()
AegisPathfinder:UpdateMaterialsPanel()
local bar = frame.slider
check(bar.track ~= nil and bar.up ~= nil and bar.down ~= nil,
	"the list scrolls with the theme's bar")
check(bar:IsShown(), "which shows once the list outgrows the rows")
local _, hi = bar:GetMinMaxValues()
check(hi == 11, "25 reagents in 14 rows scroll by 11, got %s", tostring(hi))
local tall = frame:GetHeight()
check(tall > h5, "a long list opens the window to its full height")

-- The rows are the panel's children carrying a quantity and a name.
local function firstRow()
	for _, r in ipairs({ frame:GetChildren() }) do
		if r.qty and r.name then return r.name:GetText() end
	end
end
check(firstRow() == "Reagent 01", "the list starts at the top, got '%s'", tostring(firstRow()))
bar.down:GetScript("OnClick")()
check(firstRow() == "Reagent 02", "the down caret moves one row, got '%s'", tostring(firstRow()))
arg1 = -1; frame:GetScript("OnMouseWheel")()
check(firstRow() == "Reagent 03", "and so does the wheel, got '%s'", tostring(firstRow()))
for _ = 1, 20 do bar.down:GetScript("OnClick")() end
check(bar:GetValue() == 11, "and neither runs past the end, got %s", tostring(bar:GetValue()))
for _ = 1, 20 do bar.up:GetScript("OnClick")() end
check(bar:GetValue() == 0 and firstRow() == "Reagent 01",
	"or past the top, got %s", tostring(bar:GetValue()))
frame:Hide()

-- Aegis: Exchange -----------------------------------------------------------------

--[[ A stand-in for Exchange's crafting store, doing what its craft.Projects,
	AddProject and DeleteProject do (Aegis_Exchange core/buy.lua): add or
	replace by name, newest at the top; demo mode reads a made-up list in
	place of the saved one; nothing is stored before its data has loaded. ]]
local ex = { store = { projects = {} }, adds = 0, refreshed = 0 }
local function ExchangeCrafts(store)
	local list = {}
	for _, p in ipairs(store.projects) do table.insert(list, p) end
	return list
end
AegisExchange = {
	db = { demo = false, names = { ["Silverleaf"] = 765, ["Swiftthistle"] = 2452 } },
	ui = { RefreshCraft = function() ex.refreshed = ex.refreshed + 1 end },
	craft = {
		DEMO = { { name = "Sulfuron Hammer", want = 1, reagents = {} } },
	},
}
function AegisExchange.db.IdFromName(name) return AegisExchange.db.names[name] end
function AegisExchange.craft.Projects()
	if AegisExchange.db.demo then return AegisExchange.craft.DEMO end
	return ex.store and ex.store.projects or {}
end
function AegisExchange.craft.AddProject(project)
	local s = ex.store
	if not s or not project or not project.name then return nil end
	ex.adds = ex.adds + 1
	local i = 1
	while i <= table.getn(s.projects) do
		if s.projects[i].name == project.name then table.remove(s.projects, i) else i = i + 1 end
	end
	table.insert(s.projects, 1, project)
	return project
end
function AegisExchange.craft.DeleteProject(index)
	local s = ex.store
	if s and s.projects[index] then table.remove(s.projects, index) end
end

-- What Exchange's shopping list comes to: each project's reagents times
-- the crafts it is set for (craft.CraftsFor(want, made) = ceil(want / made)).
local function exchangeTotals()
	local out = {}
	for _, p in ipairs(AegisExchange.craft.Projects()) do
		local crafts = math.ceil((p.want or 1) / (p.made or 1))
		for _, r in ipairs(p.reagents or {}) do
			out[r.name] = (out[r.name] or 0) + (r.count or 1) * crafts
		end
	end
	return out
end
local function projectNamed(name)
	for i, p in ipairs(AegisExchange.craft.Projects()) do
		if p.name == name then return p, i end
	end
end
local function flush()
	-- The step update marks the list stale; one OnUpdate later it syncs.
	this = AegisPathfinder.shoppingDriver
	AegisPathfinder.shoppingDriver:GetScript("OnUpdate")()
end

-- The player has captured one recipe of their own, which is not ours to
-- remove, and another that shares a name with a craft on the route.
local theirs = { name = "Arcanite Bar", itemId = 12360, made = 1, want = 2,
	reagents = { { name = "Thorium Bar", itemId = 12359, count = 1 } } }
local theirPotion = { name = "Minor Healing Potion", itemId = 118, made = 1, want = 3,
	reagents = { { name = "Peacebloom", itemId = 2447, count = 1 },
	             { name = "Empty Vial", itemId = 3371, count = 1 } } }
ex.store.projects = { theirPotion, theirs }

route()
AegisPathfinder.turnedin = {}
AegisPathfinder.current = 1
stub.bags = {}   -- ids from elsewhere, not the bags

-- Not loaded.
local saved = AegisExchange
AegisExchange = nil
check(AegisPathfinder:ExchangeState() == "missing", "no Exchange reads as missing")
check(AegisPathfinder:SendShoppingListToExchange() == false, "and sending is refused")
check(string.find(lastPrint(), "isn't loaded", 1, true) ~= nil, "with a reason, got '%s'", lastPrint())
check(string.find(AegisPathfinder:ExchangeHint(), "isn't loaded", 1, true) ~= nil,
	"the button's tooltip says so before you click")
AegisExchange = saved

-- Demo mode shows made-up projects in place of the saved ones: nothing is
-- sent into it, and nothing is taken out of the saved list through it.
AegisExchange.db.demo = true
check(AegisPathfinder:ExchangeState() == "demo", "demo mode is its own state")
check(AegisPathfinder:SendShoppingListToExchange() == false, "and sending is refused in it")
check(string.find(lastPrint(), "demo mode", 1, true) ~= nil, "saying why, got '%s'", lastPrint())
check(table.getn(ex.store.projects) == 2, "the saved list is untouched")
check(not AegisPathfinder:IsInExchange(), "and nothing is marked as sent")
AegisExchange.db.demo = false

-- Sent.
check(AegisPathfinder:ExchangeState() == "ready", "loaded, out of demo mode, it is ready")
local before = table.getn(printed)
check(AegisPathfinder:SendShoppingListToExchange() == true, "sending works")
check(AegisPathfinder:IsInExchange(), "and the guide is marked as sent")
local said = table.concat(printed, "\n", before + 1)
check(string.find(said, "Sent 3 crafts", 1, true) ~= nil,
	"and says how many went, got '%s'", said)
-- Oily Blackmouth has never been carried or scanned, and pfQuest is not here.
check(string.find(said, "1 reagent could not be matched", 1, true) ~= nil,
	"and owns up to a reagent it could not find an id for, got '%s'", said)
check(ex.refreshed > 0, "Exchange's Crafting tab is asked to repaint")

local list = AegisExchange.craft.Projects()
check(list[1].name == "Minor Healing Potion" and list[2].name == "Elixir of Minor Agility"
	and list[3].name == "Blackmouth Oil",
	"one project per craft, the next craft on top: got %s, %s, %s",
	tostring(list[1] and list[1].name), tostring(list[2] and list[2].name), tostring(list[3] and list[3].name))
check(projectNamed("Arcanite Bar") == theirs, "the player's own recipe stays")

local potion = projectNamed("Minor Healing Potion")
check(potion.want == 40 and potion.made == 1,
	"want is the craft count, made one per craft: got want %s made %s", tostring(potion.want), tostring(potion.made))
check(potion.reagents[1].count == 1, "reagents are per craft; Exchange multiplies them by want")
check(potion.pathfinder == "Alchemy (1-300)", "a sent project says where it came from")
check(potion.replaced == theirPotion,
	"the player's own Minor Healing Potion is held, not lost, while ours stands in for it")
check(potion.itemId == 118, "and its exact item id is kept, got %s", tostring(potion.itemId))

local elixir = projectNamed("Elixir of Minor Agility")
check(elixir.reagents[1].itemId == 2452,
	"a reagent id can come from Exchange's own name map, got %s", tostring(elixir.reagents[1].itemId))

local et, pt = exchangeTotals(), totals()
for item, need in pairs(pt) do
	check(et[item] == need, "Exchange's list comes to the same %s as ours: %s vs %s", item,
		tostring(et[item]), tostring(need))
end

-- Kept in step: finishing the potions takes them off Exchange's list.
AegisPathfinder.turnedin["Craft A@1@"] = true
AegisPathfinder.current = 2
AegisPathfinder:RefreshShoppingList()
check(projectNamed("Minor Healing Potion").pathfinder,
	"not straight away -- the step update only marks it stale")
flush()
local mhp = projectNamed("Minor Healing Potion")
check(mhp == theirPotion and not mhp.pathfinder,
	"a craft the guide has moved past leaves Exchange, and the player's own recipe comes back")
check(exchangeTotals()["Peacebloom"] == nil or exchangeTotals()["Peacebloom"] == 1 * 3,
	"so Exchange no longer counts 40 Peacebloom you have already used")
check(projectNamed("Elixir of Minor Agility").pathfinder, "the rest stay")

-- Nothing changed, nothing rewritten.
local adds = ex.adds
AegisPathfinder:RefreshShoppingList()
flush()
check(ex.adds == adds, "an update that changes nothing writes nothing (%d writes)", ex.adds - adds)

-- On another guide's tab, the sent list is left as it is.
AegisPathfinder.db.char.currentguide = "Elwynn Forest (1-12)"
AegisPathfinder.turnedin["Craft B@2@"] = true
flush()
check(projectNamed("Elixir of Minor Agility") and projectNamed("Elixir of Minor Agility").pathfinder,
	"a different guide does not touch what the profession guide sent")
AegisPathfinder.db.char.currentguide = "Alchemy (1-300)"
flush()
check(projectNamed("Elixir of Minor Agility") == nil, "back on it, it catches up")

-- The route done: nothing left to shop for.
AegisPathfinder.turnedin["Craft C@3@"] = true
flush()
local ours = 0
for _, p in ipairs(AegisExchange.craft.Projects()) do if p.pathfinder then ours = ours + 1 end end
check(ours == 0, "a finished route leaves nothing of ours in Exchange, %d left", ours)
check(not AegisPathfinder:IsInExchange(), "and stops syncing")
check(table.getn(AegisExchange.craft.Projects()) == 2, "the player's two recipes are all that is left")

-- Sending a finished route is refused rather than sending nothing.
check(AegisPathfinder:SendShoppingListToExchange() == false, "a finished route has nothing to send")
AegisPathfinder.turnedin = {}
AegisPathfinder.current = 1

-- The button: send, then take back out.
AegisPathfinder:ToggleMaterialsPanel()
check(frame.exchange:GetText() == "SEND TO EXCHANGE", "the button offers to send, got '%s'", frame.exchange:GetText())
this = frame.exchange
frame.exchange:GetScript("OnClick")()
check(AegisPathfinder:IsInExchange(), "clicking it sends")
check(frame.exchange:GetText() == "REMOVE FROM EXCHANGE",
	"and then it offers to take the list back out, got '%s'", frame.exchange:GetText())
frame.exchange:GetScript("OnEnter")()
check(Theme.tip and Theme.tip:IsShown(), "its tooltip explains")
frame.exchange:GetScript("OnLeave")()
frame.exchange:GetScript("OnClick")()
check(not AegisPathfinder:IsInExchange(), "clicking again takes it out")
check(string.find(lastPrint(), "Took 3 crafts", 1, true) ~= nil, "and says so, got '%s'", lastPrint())
check(projectNamed("Minor Healing Potion") == theirPotion and projectNamed("Arcanite Bar") == theirs,
	"leaving the player's own recipes as they were")
check(table.getn(AegisExchange.craft.Projects()) == 2, "and nothing else")

-- Exchange's own repaint failing is its business, not an error here.
AegisExchange.ui.RefreshCraft = function() error("tab not built") end
ok = pcall(function() AegisPathfinder:SendShoppingListToExchange() end)
check(ok, "a failing Exchange repaint does not break sending")
AegisPathfinder:RemoveShoppingListFromExchange()

-- Before Exchange has loaded its saved data it cannot store anything.
local store = ex.store
ex.store = nil
check(AegisPathfinder:SendShoppingListToExchange() == false, "an Exchange with no data yet refuses")
check(not AegisPathfinder:IsInExchange(), "and the guide is not marked as sent")
ex.store = store

-- The same craft twice on a route is one project, both counts; the same
-- name made two different ways is two.
AegisPathfinder.actions = { "USE", "USE", "USE", "NOTE" }
AegisPathfinder.quests = { "Craft A@1@", "Craft B@2@", "Craft C@3@", "Gather for Dirge@4@" }
AegisPathfinder.tags = {
	"|CRAFT|10 Bronze Bar| |MATS|1x Copper Bar, 1x Tin Bar|",
	"|CRAFT|5 Silver Bar| |MATS|1x Silver Ore|",
	"|CRAFT|20 Bronze Bar| |MATS|1x Copper Bar, 1x Tin Bar|",
	"|MATS|12x Giant Egg|",
}
local crafts = AegisPathfinder:GetRemainingCrafts()
check(table.getn(crafts) == 3, "two Bronze Bar steps are one project, got %d", table.getn(crafts))
check(crafts[1].name == "Bronze Bar" and crafts[1].want == 30, "wanting both counts, got %s", tostring(crafts[1].want))
check(crafts[3].name == "Gather for Dirge" and crafts[3].want == 1 and crafts[3].reagents[1].count == 12,
	"reagents with nothing to craft are named for the step")
AegisPathfinder.tags[3] = "|CRAFT|20 Bronze Bar| |MATS|2x Copper Bar|"
crafts = AegisPathfinder:GetRemainingCrafts()
check(table.getn(crafts) == 4 and crafts[3].name == "Bronze Bar (2)",
	"a second recipe under one name is kept apart, got %s", tostring(crafts[3] and crafts[3].name))

-- pfQuest knows every item's name, so a reagent nobody has carried or
-- scanned still gets its id.
pfDB = { items = { loc = { [2770] = "Copper Ore", [2840] = "Copper Bar", [99999] = "Copper Bar" } } }
check(AegisPathfinder:ItemIdByName("Copper Bar") == 2840,
	"pfQuest's item names give an id, the original one where a name repeats, got %s",
	tostring(AegisPathfinder:ItemIdByName("Copper Bar")))

-- End-to-end against the guide's own table ----------------------------------

--[[ The strongest check available offline.

	The generated Alchemy guide is a table of steps, each with its craft count
	and each craft's reagents. Running it through the real parsers and summing
	from step one must come to the same totals as multiplying those out by
	hand. If the converter drops a step, mangles a craft count, or the tag
	round trip loses a reagent, these numbers diverge. The same guide sent to
	Exchange must come to the same numbers there.
]]
AegisPathfinder.guides, AegisPathfinder.guidelist = {}, {}
AegisPathfinder.qsplusguides = {}
AegisPathfinder.turnedin = {}
AegisPathfinder.current = 1
function AegisPathfinder:RegisterGuide(name, nextzone, faction, loader)
	self.guides[name] = loader
	table.insert(self.guidelist, name)
end

dofile("QuestShellPlusParser.lua")
dofile("Guides/Professions/Alchemy.lua")

local alchemy = AegisPathfinder.qsplusguides["Alchemy (1-300)"]
check(alchemy ~= nil, "the Alchemy guide did not register")
local ALCHEMY_TOTALS = {}
for _, st in ipairs(alchemy and alchemy.steps or {}) do
	for _, r in ipairs(st.craft and st.reagents or {}) do
		ALCHEMY_TOTALS[r.item] = (ALCHEMY_TOTALS[r.item] or 0) + r.qty * st.craft.count
	end
end
check(ALCHEMY_TOTALS["Empty Vial"] and ALCHEMY_TOTALS["Peacebloom"], "the Alchemy guide's crafts have reagents")

if alchemy then
	local aa, qq, tt = AegisPathfinder:ParseQuestShellPlus(alchemy)
	AegisPathfinder.actions, AegisPathfinder.quests, AegisPathfinder.tags = aa, qq, tt

	local computed = {}
	for _, e in ipairs(AegisPathfinder:GetRemainingMaterials() or {}) do
		computed[e.item] = e.need
	end

	for item, expected in pairs(ALCHEMY_TOTALS) do
		check(computed[item] == expected,
			"Alchemy needs %d %s by its steps, computed %s",
			expected, item, tostring(computed[item]))
	end
	for item, got in pairs(computed) do
		check(ALCHEMY_TOTALS[item] ~= nil,
			"computed a reagent no step lists: %s (%d)", item, got)
	end

	AegisExchange.ui.RefreshCraft = function() end
	check(AegisPathfinder:SendShoppingListToExchange() == true, "the Alchemy route sends")
	local sent = exchangeTotals()
	for item, expected in pairs(ALCHEMY_TOTALS) do
		check(sent[item] == expected,
			"sent to Exchange, Alchemy still needs %d %s, Exchange would count %s",
			expected, item, tostring(sent[item]))
	end
	AegisPathfinder:RemoveShoppingListFromExchange()
end

-- Report ---------------------------------------------------------------------

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end

print(string.format("Materials: %d checks", checks))
if table.getn(failures) == 0 then
	print("All materials checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
