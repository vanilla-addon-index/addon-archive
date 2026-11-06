--[[ GearFinder.lua -- upgrades waiting in the dungeons you run, as Zygor's Gear
	Finder has.

	GearData.lua lists what drops in each dungeon and raid (from CMaNGOS, with
	Turtle WoW's changes laid over it, and for Turtle's own from pfQuest-turtle): the item, who drops it and how
	often, and the item's slot, quality, required level and classes. Turtle's
	own items come with none of that; the client says what they are once it
	has loaded them -- slot, quality and level from GetItemInfo, and whether
	your class can use one from the red lines on its tooltip, as for any item. The finder takes the dungeons you can go to
	-- those starting no more than a few levels above you, on your side; raids
	only when you tick them -- and
	weighs each of their items for your spec against what you wear, with the
	item score. What beats it is kept under the slot it would go in -- the
	one the item score says it replaces, so a one-hander a dual wielder would
	put in the off hand is an off-hand upgrade -- best first, with where it
	drops.

	The Gear Finder tab on the character panel (GearFinderTab.lua) shows a
	cell per slot: the biggest upgrade, or the one you picked from the slot's
	list. Two rings and two trinkets are worn, so those slots have two cells,
	never showing the same item. The suggested dungeon is the one the items in
	the cells drop in most: by how many slots it upgrades, then by how much.

	An item has to be in the client's cache to be read. Those that are not
	are asked for the safe way (ClassicAPI's C_Item.RequestLoadItemDataByID)
	a few at a time, and the cells fill in as they arrive.

	Walking into a dungeon says, in chat, which of its drops are upgrades.

	Not only drops: quest rewards from quests you have still to do, gear a
	reputation vendor sells, and crafted gear (GearData's quests, repgear and
	crafted), each switched in the options. Those are looked at only near your
	level -- no more than AHEAD above it and BELOW under it -- since there are
	thousands, and each has to be loaded to be weighed. Crafted gear that binds
	on pickup counts only if you have the profession; so does all of it under
	Solo Self-Found, when nobody else may make it for you.
]]

local AegisPathfinder = AegisPathfinder

local GF = {}
AegisPathfinder.GearFinder = GF

-- Timing and limits, in one table: see the 32-upvalue note in CONTRIBUTING.md.
local L = {
	AHEAD = 3,              -- dungeons and items up to this many levels above you
	LOAD_BATCH = 5, LOAD_EVERY = 0.1, REFRESH_EVERY = 0.5,
	NAMED = 4,              -- the note names this many places it looked, then counts
	BELOW = 10,             -- quest, reputation and crafted gear this far under your level
	RANKS = { [0] = "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" },
	LOAD_GIVE_UP = 10,      -- seconds after the last request: an item never sent is not waited for
	EMPTY_WORTH = 100,      -- what filling an empty slot counts for, in %, when dungeons are ranked
}

-- The slots, in the order the character sheet has them, and the slot each
-- of the character's inventory slots belongs to.
local GROUPS = { "Head", "Neck", "Shoulder", "Back", "Chest", "Wrist", "Hands", "Waist", "Legs", "Feet",
	"Finger", "Trinket", "Main hand", "Off hand", "Ranged" }
local GROUP_OF = {
	[1] = "Head", [2] = "Neck", [3] = "Shoulder", [15] = "Back", [5] = "Chest", [9] = "Wrist",
	[10] = "Hands", [6] = "Waist", [7] = "Legs", [8] = "Feet", [11] = "Finger", [12] = "Finger",
	[13] = "Trinket", [14] = "Trinket", [16] = "Main hand", [17] = "Off hand", [18] = "Ranged",
}

--[[ The tab's cells, laid out like the character sheet: two columns of
	eight, and the ranged slot under the suggested dungeon. `inv` names the
	inventory slot whose empty picture a cell shows when it has no upgrade.
	Shirt and tabard are left out: they have no stats. ]]
GF.CELLS = {
	{ key = "head", label = "Head", group = "Head", col = 1, row = 1, inv = "HeadSlot" },
	{ key = "neck", label = "Neck", group = "Neck", col = 1, row = 2, inv = "NeckSlot" },
	{ key = "shoulder", label = "Shoulder", group = "Shoulder", col = 1, row = 3, inv = "ShoulderSlot" },
	{ key = "back", label = "Back", group = "Back", col = 1, row = 4, inv = "BackSlot" },
	{ key = "chest", label = "Chest", group = "Chest", col = 1, row = 5, inv = "ChestSlot" },
	{ key = "wrist", label = "Wrist", group = "Wrist", col = 1, row = 6, inv = "WristSlot" },
	{ key = "mainhand", label = "Main hand", group = "Main hand", col = 1, row = 7, inv = "MainHandSlot" },
	{ key = "offhand", label = "Off hand", group = "Off hand", col = 1, row = 8, inv = "SecondaryHandSlot" },
	{ key = "hands", label = "Hands", group = "Hands", col = 2, row = 1, inv = "HandsSlot" },
	{ key = "waist", label = "Waist", group = "Waist", col = 2, row = 2, inv = "WaistSlot" },
	{ key = "legs", label = "Legs", group = "Legs", col = 2, row = 3, inv = "LegsSlot" },
	{ key = "feet", label = "Feet", group = "Feet", col = 2, row = 4, inv = "FeetSlot" },
	{ key = "finger1", label = "Finger 1", group = "Finger", col = 2, row = 5, inv = "Finger0Slot" },
	{ key = "finger2", label = "Finger 2", group = "Finger", col = 2, row = 6, inv = "Finger1Slot" },
	{ key = "trinket1", label = "Trinket 1", group = "Trinket", col = 2, row = 7, inv = "Trinket0Slot" },
	{ key = "trinket2", label = "Trinket 2", group = "Trinket", col = 2, row = 8, inv = "Trinket1Slot" },
	{ key = "ranged", label = "Ranged", group = "Ranged", col = 3, row = 8, inv = "RangedSlot" },
}

-- Each class's bit in an item's class mask.
local CLASS_BIT = {
	WARRIOR = 1, PALADIN = 2, HUNTER = 4, ROGUE = 8, PRIEST = 16,
	SHAMAN = 64, MAGE = 128, WARLOCK = 256, DRUID = 1024,
}

local function settings()
	local db = AegisPathfinder.db.char
	db.gearfinder = db.gearfinder or {}
	local s = db.gearfinder
	if s.enabled == nil then s.enabled = true end
	if s.raids == nil then s.raids = false end
	if s.announce == nil then s.announce = true end
	for _, key in ipairs({ "dungeons", "quests", "reputation", "crafted" }) do
		if s[key] == nil then s[key] = true end
	end
	-- The upgrade you chose for a cell, by the cell's key: { finger2 = 1156 }.
	s.picks = s.picks or {}
	return s
end
GF.Settings = settings

--- Whether an item's class mask lets your class use it.
function GF.ForClass(mask, class)
	if not mask or mask == 0 then return true end
	local bit = CLASS_BIT[class]
	if not bit then return true end
	return math.mod(math.floor(mask / bit), 2) == 1
end

--- The dungeons the finder looks in, for your level and side.
function GF:Dungeons()
	local level = UnitLevel("player") or 1
	local faction = UnitFactionGroup("player")
	local s = settings()
	local out = {}
	-- Solo Self-Found runs no dungeons.
	if AegisPathfinder.db.char.SelfFound then return out end
	for _, d in ipairs(AegisPathfinder.GearData.dungeons) do
		local ok = d.lo <= level + L.AHEAD
		-- The two upgrade sources the options tick: dungeons, and raids.
		if d.kind == "raid" and not s.raids then ok = false end
		if d.kind ~= "raid" and not s.dungeons then ok = false end
		if d.faction and faction and d.faction ~= faction then ok = false end
		-- Not the Dungeons page's ticks: those are which dungeons' quests the
		-- route takes in, set by the setup for the route. A dungeon you skip
		-- for its quests may still be where your upgrades are.
		if ok then table.insert(out, d) end
	end
	return out
end

--[[ Loading items the client has not seen ]]

local loadQueue, requested = {}, {}

local function wantLoaded(id)
	if requested[id] then return end
	requested[id] = true
	table.insert(loadQueue, id)
end

function GF:Pending()
	return table.getn(loadQueue)
end

function GF:DrainLoads()
	local n = 0
	while n < L.LOAD_BATCH and table.getn(loadQueue) > 0 do
		local id = table.remove(loadQueue, 1)
		if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
		n = n + 1
	end
end

--[[ Finding upgrades ]]

--- What the data says about an item -- { slot, quality, required level,
--- class mask } -- or, for Turtle's own items, what the client does once it
--- has the item: nil until then, false if it is not gear worth weighing.
local function describe(items, id, it)
	local meta = items[id]
	if meta then return meta end
	local _, _, quality, minLevel, _, _, _, loc = GetItemInfo(it)
	if not quality then return nil end
	if quality < 2 or not loc or loc == "" or not AegisPathfinder.ItemScore.SLOTS[loc] then return false end
	return { loc, quality, minLevel or 0, 0 }
end

local results, missing = {}, 0

--- Your professions, by name, with your skill in each.
local function Professions()
	local out = {}
	for i = 1, (GetNumSkillLines and GetNumSkillLines() or 0) do
		local name, isHeader, _, rank = GetSkillLineInfo(i)
		if name and not isHeader then out[name] = rank end
	end
	return out
end

--- Gear from quests you have still to do, reputation vendors and crafting,
--- near your level, for your side and class: { item, where it comes from }.
function GF:Others(level, class)
	local data, s, db = AegisPathfinder.GearData, settings(), AegisPathfinder.db.char
	local faction = UnitFactionGroup("player")
	local out = {}
	-- How near your level an item is: its required level, or, for one with
	-- none -- most quest rewards -- the level its quest is taken at. Read as
	-- level 0, every such reward was "long outgrown" and never weighed.
	local function near(id, taken)
		local m = data.items[id]
		if not m then return nil end
		local lvl = m[3] > 0 and m[3] or (taken or 0)
		return lvl <= level + L.AHEAD and lvl >= level - L.BELOW and lvl
	end
	local function ours(side) return side == "" or not faction or side == faction end
	if s.quests then
		for q, d in pairs(data.quests or {}) do
			local done = (db.completedquestsbyid and db.completedquestsbyid[q])
				or (AegisPathfinder.IsQuestCompletedOnServer and AegisPathfinder:IsQuestCompletedOnServer(q))
			if not done and d[2] <= level + L.AHEAD and ours(d[3]) and GF.ForClass(d[4], class) then
				local where = "Quest: " .. d[1]
				if d[5] > 0 then where = where .. " (" .. L.RANKS[d[6]] .. ", " .. data.factions[d[5]][1] .. ")" end
				for _, id in ipairs(d[7]) do
					local lvl = near(id, d[2])
					if lvl then table.insert(out, { id, where, lvl }) end
				end
			end
		end
	end
	if s.reputation then
		for id, d in pairs(data.repgear or {}) do
			local f = data.factions[d[1]]
			if near(id) and ours(f[2]) then
				table.insert(out, { id, L.RANKS[d[2]] .. " with " .. f[1] .. " \194\183 " .. d[3] })
			end
		end
	end
	if s.crafted then
		local mine = Professions()
		for id, d in pairs(data.crafted or {}) do
			local skill = mine[d[1]]
			-- Bind on pickup, or Solo Self-Found: only if you make it yourself.
			if near(id) and (skill or not (d[3] or db.SelfFound)) then
				table.insert(out, { id, d[1] .. " " .. d[2] .. (skill and "" or " \194\183 made by a crafter") })
			end
		end
	end
	return out
end

--- Every upgrade in the dungeons you run, and from the other sources that
--- are on: by slot, best first. Items not loaded yet are asked for, and
--- counted.
function GF:Find()
	local IS = AegisPathfinder.ItemScore
	local items = AegisPathfinder.GearData.items
	local level = UnitLevel("player") or 1
	local _, class = UnitClass("player")
	local weights = IS:Weights()
	local bySlot, seen = {}, {}
	missing = 0
	-- One item from anywhere: weighed, and kept if it is an upgrade. A drop
	-- has its dungeon, who drops it and the chance; anything else says where.
	local function consider(id, dungeon, code, source, chance, where, taken)
		local it = "item:" .. id .. ":0:0:0"
		local meta = not seen[id] and describe(items, id, it)
		if meta == nil and not seen[id] then
			-- One of Turtle's own, not loaded yet: nothing to go on until it is.
			seen[id] = true
			wantLoaded(id)
			missing = missing + 1
		elseif meta and math.max(meta[3], taken or 0) <= level + L.AHEAD and GF.ForClass(meta[4], class) then
			seen[id] = true
			if not GetItemInfo(it) then
				wantLoaded(id)
				missing = missing + 1
			else
				local c = IS:Compare(it, weights)
				if c and c.usable and not c.noCompare and (c.delta or 0) > 0.0001 then
					-- Under the slot it would replace; the data's own slot if
					-- the score did not say.
					local fits = IS.SLOTS[meta[1]]
					local group = GROUP_OF[c.slot or (fits and fits[1]) or 0]
					if group then
						bySlot[group] = bySlot[group] or {}
						table.insert(bySlot[group], {
							id = id, item = it, dungeon = dungeon, code = code, source = source,
							-- "at level N": the item's, or a quest's you cannot take yet.
							chance = chance, where = where, compare = c, level = math.max(meta[3], taken or 0),
						})
					end
				end
			end
		end
	end
	for _, d in ipairs(self:Dungeons()) do
		for _, drop in ipairs(d.loot) do consider(drop[1], d.name, d.code, drop[2], drop[3]) end
	end
	for _, o in ipairs(self:Others(level, class)) do consider(o[1], nil, nil, nil, nil, o[2], o[3]) end
	results = {}
	for _, g in ipairs(GROUPS) do
		local list = bySlot[g]
		if list then
			table.sort(list, function(a, b)
				if a.compare.delta ~= b.compare.delta then return a.compare.delta > b.compare.delta end
				return a.id < b.id
			end)
			table.insert(results, { slot = g, entries = list })
		end
	end
	return results, missing
end

function GF:Results() return results, missing end

--- The upgrades that drop in one dungeon, best first.
function GF:UpgradesIn(name)
	local out = {}
	for _, g in ipairs(results) do
		for _, e in ipairs(g.entries) do
			if e.dungeon == name then table.insert(out, e) end
		end
	end
	table.sort(out, function(a, b) return a.compare.delta > b.compare.delta end)
	return out
end

--[[ The cells ]]

--- What an upgrade is worth when dungeons are ranked: its %, or, for a slot
--- you have nothing in, EMPTY_WORTH.
function GF.Worth(e)
	local c = e.compare
	if c.pct then return c.pct end
	return c.emptySlot and L.EMPTY_WORTH or 0
end

local function listed(list, id)
	if not id then return nil end
	for _, e in ipairs(list) do if e.id == id then return e end end
end

local function firstBut(list, id)
	for _, e in ipairs(list) do if e.id ~= id then return e end end
end

local function without(list, id)
	if not id then return list end
	local out = {}
	for _, e in ipairs(list) do if e.id ~= id then table.insert(out, e) end end
	return out
end

--- The tab's cells, in GF.CELLS's order: { key, label, col, row, inv,
--- entries (what its list offers, best first), shown (the upgrade it shows,
--- or nil), picked (shown because you chose it) }. The two cells of a ring
--- or trinket slot never show the same item, nor offer the one the other
--- shows.
function GF:Cells()
	local picks = settings().picks
	local byGroup = {}
	for _, g in ipairs(results) do byGroup[g.slot] = g.entries end
	local out, pairOf = {}, {}
	for _, def in ipairs(GF.CELLS) do
		local list = byGroup[def.group] or {}
		local cell = { key = def.key, label = def.label, col = def.col, row = def.row, inv = def.inv,
			group = def.group, entries = list }
		local first = pairOf[def.group]
		if first then
			-- The second of two: settle both together, a pick on either side
			-- taking its item from the other.
			local p1, p2 = listed(list, picks[first.key]), listed(list, picks[def.key])
			if p1 and p2 and p1.id == p2.id then p2 = nil end
			first.shown = p1 or firstBut(list, p2 and p2.id)
			cell.shown = p2 or firstBut(list, first.shown and first.shown.id)
			first.picked, cell.picked = p1 ~= nil, p2 ~= nil
			first.entries = without(list, cell.shown and cell.shown.id)
			cell.entries = without(list, first.shown and first.shown.id)
		else
			local pick = listed(list, picks[def.key])
			cell.shown, cell.picked = pick or list[1], pick ~= nil
			pairOf[def.group] = cell
		end
		table.insert(out, cell)
	end
	return out
end

--- Choose upgrade `id` for cell `key`; nil, or the cell's own first choice,
--- goes back to the biggest.
function GF:SetPick(key, id)
	local picks = settings().picks
	for _, cell in ipairs(self:Cells()) do
		if cell.key == key and cell.entries[1] and cell.entries[1].id == id then id = nil end
	end
	picks[key] = id
end

local function Worn(id)
	for slot = 1, 19 do
		local link = GetInventoryItemLink("player", slot)
		local _, _, have = string.find(link or "", "item:(%d+)")
		if have and tonumber(have) == id then return true end
	end
end

--- Picks you have since put on, or that are no longer upgrades, are
--- forgotten. One the finder is not looking at just now -- a raid's, with
--- raids unticked -- is kept for when it is; so is everything while items
--- are still loading, when a pick may simply not have been weighed yet.
function GF:PrunePicks()
	local picks = settings().picks
	local IS = AegisPathfinder.ItemScore
	local all = {}
	for _, g in ipairs(results) do
		for _, e in ipairs(g.entries) do all[e.id] = true end
	end
	for key, id in pairs(picks) do
		if Worn(id) then
			picks[key] = nil
		elseif missing == 0 and not all[id] then
			local link = "item:" .. id .. ":0:0:0"
			if GetItemInfo(link) then
				local up, c = IS:IsUpgrade(link, true)
				if c and not up then picks[key] = nil end
			end
		end
	end
end

--- The dungeons the cells' items drop in, best first: by how many cells,
--- then by what those upgrades add up to. Each: { code, name, lo, hi, kind,
--- n, total, slots (the cells' labels) }.
function GF:Suggest(cells)
	local info, tally, order = {}, {}, {}
	for _, d in ipairs(AegisPathfinder.GearData.dungeons) do info[d.code] = d end
	for _, cell in ipairs(cells or self:Cells()) do
		local e = cell.shown
		if e and e.code then
			local t = tally[e.code]
			if not t then
				local d = info[e.code] or {}
				t = { code = e.code, name = e.dungeon, lo = d.lo, hi = d.hi, kind = d.kind, n = 0, total = 0, slots = {} }
				tally[e.code] = t
				table.insert(order, t)
			end
			t.n = t.n + 1
			t.total = t.total + GF.Worth(e)
			table.insert(t.slots, cell.label)
		end
	end
	table.sort(order, function(a, b)
		if a.n ~= b.n then return a.n > b.n end
		if a.total ~= b.total then return a.total > b.total end
		return a.name < b.name
	end)
	return order
end

--- Where an upgrade comes from, in a line: the dungeon and who drops it, or
--- the quest, vendor or recipe.
function GF.Where(e)
	return e.where or (e.dungeon .. " \194\183 " .. e.source)
end

--- What the tab's footer says: where it looked, or why it did not.
function GF:Status()
	local IS = AegisPathfinder.ItemScore
	local s = settings()
	local dungeons = self:Dungeons()
	-- Where it looked: named, if a few; counted, if many -- at 60 it is
	-- every dungeon there is, too many names for one line.
	local names, nd, nr = {}, 0, 0
	for _, d in ipairs(dungeons) do
		table.insert(names, d.name)
		if d.kind == "raid" then nr = nr + 1 else nd = nd + 1 end
	end
	local function count(n, one) return n .. " " .. one .. (n == 1 and "" or "s") end
	local places = {}
	if table.getn(names) > 0 then
		table.insert(places, table.getn(names) <= L.NAMED and table.concat(names, ", ")
			or (count(nd, "dungeon") .. (nr > 0 and (" and " .. count(nr, "raid")) or "")))
	end
	if s.quests then table.insert(places, "quests") end
	if s.reputation then table.insert(places, "reputation") end
	if s.crafted then table.insert(places, "crafting") end
	local n = table.getn(places)
	local where = n <= 1 and (places[1] or "")
		or (table.concat(places, ", ", 1, n - 1) .. " and " .. places[n])
	local text
	if not s.enabled then
		text = "The Gear Finder is switched off in the options."
	elseif not s.dungeons and not s.raids then
		text = "Dungeons and Raids are both unticked under Upgrade sources"
			.. (n > 0 and (", so it looks at " .. where .. " only.") or ", so it has nowhere to look.")
	elseif table.getn(dungeons) == 0 and AegisPathfinder.db.char.SelfFound then
		text = "Solo Self-Found is on, so it looks in no dungeons."
			.. (n > 0 and (" Looking at " .. where .. ".") or "")
	elseif n == 0 then
		text = "There is no " .. (s.dungeons and "dungeon" or "raid") .. " at your level to look in."
	else
		text = "Looking in " .. where .. "."
	end
	if s.enabled and missing > 0 then
		text = text .. string.format(" Loading %d more items...", missing)
		-- Raids are hundreds more; say why it is taking a while.
		if s.raids then text = text .. " Raids take a minute or two, the first time." end
	end
	local spec = IS:SpecLabel((IS:Spec()))
	local nothing = missing > 0 and "Loading items from the server..."
		or (n > 0 and ("Nothing from " .. where .. " beats what you wear for " .. spec .. ".")
		or "There is nowhere to look: see the Gear options.")
	return text, nothing
end

function GF:Refresh()
	if settings().enabled then
		self:Find()
		self:PrunePicks()
	else
		results, missing = {}, 0
	end
	if self.Paint then self:Paint() end
end

--- Whether the tab is up, so there is something to keep filled.
function GF:Showing()
	return self.panel and self.panel:IsVisible()
end

--- A Gear Finder setting changed in the options: the tab follows at once
--- (and goes, with the Gear Finder switched off).
function GF:SettingsChanged()
	if self.PlaceTab then self:PlaceTab() end
	if self:Showing() then self:Refresh() end
end

--[[ Walking into a dungeon ]]

function GF:Announce(zone)
	if not settings().enabled or not settings().announce then return end
	local known
	for _, d in ipairs(AegisPathfinder.GearData.dungeons) do
		if d.name == zone then known = d end
	end
	if not known then return end
	-- Look in this dungeon even if it is not one the finder would pick.
	local s = settings()
	local raids, dungeons = s.raids, s.dungeons
	s.raids, s.dungeons = true, true
	self:Find()
	s.raids, s.dungeons = raids, dungeons
	-- What was found for this one dungeon is not what the tab shows.
	if self:Showing() then self.events.refreshAt = GetTime() end
	local ups = self:UpgradesIn(zone)
	if table.getn(ups) == 0 then return end
	local parts = {}
	for i = 1, math.min(3, table.getn(ups)) do
		local e = ups[i]
		local name = GetItemInfo(e.item)
		table.insert(parts, (name or ("item " .. e.id)) .. " " .. AegisPathfinder.GearAdvisor.Gain(e.compare)
			.. " (" .. e.source .. ")")
	end
	AegisPathfinder:Print(string.format("Upgrades in %s: %s%s", zone, table.concat(parts, "; "),
		table.getn(ups) > 3 and string.format(", and %d more -- /apg finder", table.getn(ups) - 3) or "."))
end

--[[ Events ]]

local events = CreateFrame("Frame")
GF.events = events
events:RegisterEvent("PLAYER_LEVEL_UP")
events:RegisterEvent("UNIT_INVENTORY_CHANGED")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:SetScript("OnEvent", function()
	-- Zoning in at login comes before the addon has its settings.
	if not AegisPathfinder.db then return end
	if event == "ZONE_CHANGED_NEW_AREA" then
		GF:Announce(GetRealZoneText())
	elseif GF:Showing() and (event ~= "UNIT_INVENTORY_CHANGED" or arg1 == "player") then
		this.refreshAt = GetTime()
	end
end)
events:SetScript("OnUpdate", function()
	local now = GetTime()
	if table.getn(loadQueue) > 0 and now - (this.loadedAt or 0) >= L.LOAD_EVERY then
		this.loadedAt = now
		GF:DrainLoads()
		this.refreshAt = this.refreshAt or now
	end
	-- While items arrive, the open tab refills now and then -- until a while
	-- after the last request, so an item the server never sends is not
	-- waited for for ever.
	if this.refreshAt and now - this.refreshAt >= L.REFRESH_EVERY then
		this.refreshAt = nil
		if GF:Showing() then
			GF:Refresh()
			if missing > 0 and now - (this.loadedAt or 0) < L.LOAD_GIVE_UP then this.refreshAt = now end
		end
	end
end)

function GF:Initialize()
	AegisPathfinder.ItemScore:OnChange(function()
		if GF:Showing() then GF.events.refreshAt = GetTime() end
	end)
end
