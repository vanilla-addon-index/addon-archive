--[[
	Run CraftRoute's route planner outside the game and print its routes.

	    lua5.1 Tools/build/craftroute_harness.lua <CraftRoute checkout> <names.lua> <markup>

	Called by Tools/build/import_routes.py, which explains why. This file is
	this addon's own: just enough of the game's API for CraftRoute's data and
	planner to load, and the price stand-ins described below. Nothing of
	CraftRoute is copied here; it is loaded from the checkout and only what it
	prints is kept.

	names.lua returns { [itemId] = name } for reagents CraftRoute gives by id
	(the game's GetItemInfo answers that in game).

	Prices are CraftRoute's own sample auction scan (test_scan_data.lua) and
	its merchant prices. Its scan has no listing for most things you gather
	yourself -- meat, fish, Survival's wood and leaves -- and an unpriced
	reagent keeps its recipe out of a route, which stops Cooking at skill 1.
	So a raw material (no recipe makes it) with no listing and no merchant
	selling it is listed at <markup> times what a merchant pays for it, in
	quantity. Those names are printed, for the guides to say so.

	Output, tab separated:
	  route   <profession> <total copper> <skill reached> <stuck at or ->
	  step    <profession> <from> <to> <expected crafts> <recipe>
	  standin <item> <copper>
	  scan    <newest listing's unix time>
]]

local dir, namesFile, markup = arg[1], arg[2], tonumber(arg[3])
if not (dir and namesFile and markup) then
	io.stderr:write("usage: lua5.1 craftroute_harness.lua <CraftRoute checkout> <names.lua> <markup>\n")
	os.exit(2)
end

-- The WoW 1.12 globals the files use.
getn, tinsert, tremove, strlower, strupper, strfind, strsub, strlen, strrep, format =
	table.getn, table.insert, table.remove, string.lower, string.upper, string.find, string.sub,
	string.len, string.rep, string.format
floor, ceil, mod, abs, min, max = math.floor, math.ceil, math.mod, math.abs, math.min, math.max
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
UnitRace = function() return "Human", "Human" end
GetTime = function() return 0 end
time = os.time
local function frame()
	return { RegisterEvent = function() end, UnregisterEvent = function() end, SetScript = function() end,
		Show = function() end, Hide = function() end }
end
CreateFrame = frame
local NAMES = dofile(namesFile)
GetItemInfo = function(id) return NAMES[tonumber(id)] end

local PROFESSIONS = { "alchemy", "blacksmithing", "cooking", "enchanting", "engineering",
	"jewelcrafting", "leatherworking", "survival", "tailoring" }

local files = { "data_vendorprices.lua", "data_vendorsellprices.lua" }
for _, p in ipairs(PROFESSIONS) do table.insert(files, "data_" .. p .. ".lua") end
for _, f in ipairs({ "core.lua", "scan.lua", "test_scan_data.lua" }) do table.insert(files, f) end
for _, f in ipairs(files) do dofile(dir .. "/" .. f) end

local newest = 0
for _, s in pairs(CraftRoute_Scans) do
	if s.timestamp and s.timestamp > newest then newest = s.timestamp end
end

-- The stand-ins: raw materials only, so a craftable reagent is still costed
-- by making it.
local made, raw = {}, {}
for _, p in ipairs(PROFESSIONS) do
	for _, r in ipairs(CraftRoute_Data[p]) do made[strlower(r.name)] = true end
end
for _, p in ipairs(PROFESSIONS) do
	for _, r in ipairs(CraftRoute_Data[p]) do
		for _, g in ipairs(r.reagents) do
			local name = CraftRoute.ResolveReagent(g)
			if name then raw[strlower(name)] = name end
		end
	end
end
local standins = {}
for key, name in pairs(raw) do
	local sell = CraftRoute_VendorSellPrices[key]
	if not made[key] and not CraftRoute_Scans[key] and not CraftRoute_VendorPrices[key] and sell and sell > 0 then
		local copper = sell * markup
		CraftRoute_Scans[key] = { timestamp = newest, listings = { { unitPrice = copper, qty = 100000 } } }
		table.insert(standins, { name = name, copper = copper })
	end
end
table.sort(standins, function(a, b) return strlower(a.name) < strlower(b.name) end)

for _, p in ipairs(PROFESSIONS) do
	local total, steps, _, reached, stuckAt = CraftRoute.CalculatePath(p, 300, 1)
	print(table.concat({ "route", p, string.format("%d", total or 0), tostring(reached or 0),
		stuckAt and tostring(stuckAt) or "-" }, "\t"))
	for i = 1, (steps and getn(steps) or 0) do
		local st = steps[i]
		print(table.concat({ "step", p, st.fromSkill, st.toSkill, string.format("%.4f", st.expectedCrafts),
			st.name }, "\t"))
	end
end
for _, s in ipairs(standins) do print("standin\t" .. s.name .. "\t" .. s.copper) end
print("scan\t" .. newest)
