--[[
	GuideBrowser.lua -- what the guide browser (GuideListFrame.lua) shows.

	The browser is laid out like Zygor's: categories down the left, a category's
	folders and guides in the middle, the guide you point at on the right, and a
	Home tab of small panels. This file is everything behind it that is not a
	frame, so it can be tested without one:

	  * the categories and their folders -- Leveling holds Optimized, RestedXP,
	    RestedXP Hardcore, the zone guides by continent and the custom zones;
	    a folder too long to read is split by level;
	  * search, across every guide the browser lists;
	  * the guides you opened lately, and the ones you starred;
	  * what to do next: the route's next leg, a class quest, a ticked dungeon
	    or a custom zone at your level;
	  * two trackers: time played at each level, and gold earned today and
	    this week -- both counted from when the character first ran a version
	    with them, while you play.
]]

local AegisPathfinder = AegisPathfinder

local Browser = {}
AegisPathfinder.Browser = Browser

--[[ The sidebar, top to bottom. `badge` is a Theme.BADGES kind drawn as the
	row's icon; `glyph` a Theme.glyph name (or an action icon's DSL letter);
	`soon` greys a category out until it has guides. ]]
Browser.CATEGORIES = {
	{ key = "leveling",    label = "Leveling",      badge = "xp" },
	{ key = "dungeons",    label = "Dungeons",      badge = "dg" },
	{ key = "class",       label = "Class Quests",  badge = "cl" },
	{ key = "professions", label = "Professions",   badge = "pf" },
	{ key = "favorites",   label = "Favorites",     glyph = "star" },
	{ key = "reputations", label = "Reputations",   glyph = "heart",    soon = true },
	{ key = "dailies",     label = "Dailies",       glyph = "bang",     soon = true },
	{ key = "events",      label = "Events",        glyph = "calendar", soon = true },
	{ key = "gold",        label = "Gold",          glyph = "B",        soon = true },
	{ key = "pets",        label = "Pets & Mounts", glyph = "P",        soon = true },
	{ key = "titles",      label = "Titles",        glyph = "medal",    soon = true },
}

Browser.LONG = 24          -- a folder with more guides than this is split by level
Browser.BANDS = {          -- ... into these, by the level a guide starts at
	{ 1, 19, "Levels 1-20" }, { 20, 39, "Levels 20-40" }, { 40, 99, "Levels 40-60" },
}
Browser.RECENT_MAX = 30    -- guides remembered as opened lately
Browser.SUGGEST_MAX = 5

-- The leveling packs, as GetGuideCategory names them, in the order shown.
local PACKS = {
	{ "optimized", "Optimized" }, { "rxp", "RestedXP" }, { "rxp_hc", "RestedXP Hardcore" },
}

--[[ The zones: the world map's name for each, its map's folder under
	Interface\WorldMap (GuidePictures.lua draws it) and its continent ("EK",
	"K", or nil for Turtle WoW's own, which have the Custom zones folder).
	`also` lists what guide titles call it, and places in it a title may name
	instead -- RestedXP's "1-6 Coldridge Valley" is in Dun Morogh. ]]
Browser.ZONES = {
	["Alterac Mountains"]    = { "Alterac", "EK", also = { "Alterac" } },
	["Arathi Highlands"]     = { "Arathi", "EK", also = { "Arathi" } },
	["Badlands"]             = { "Badlands", "EK" },
	["Blasted Lands"]        = { "BlastedLands", "EK" },
	["Burning Steppes"]      = { "BurningSteppes", "EK" },
	["Deadwind Pass"]        = { "DeadwindPass", "EK" },
	["Dun Morogh"]           = { "DunMorogh", "EK", also = { "Coldridge Valley", "Kharanos" } },
	["Duskwood"]             = { "Duskwood", "EK" },
	["Eastern Plaguelands"]  = { "EasternPlaguelands", "EK" },
	["Elwynn Forest"]        = { "Elwynn", "EK", also = { "Elwynn", "Northshire" } },
	["Hillsbrad Foothills"]  = { "Hilsbrad", "EK", also = { "Hillsbrad" } },
	["Ironforge"]            = { "Ironforge", "EK" },
	["Loch Modan"]           = { "LochModan", "EK" },
	["Redridge Mountains"]   = { "Redridge", "EK", also = { "Redridge" } },
	["Searing Gorge"]        = { "SearingGorge", "EK" },
	["Silverpine Forest"]    = { "Silverpine", "EK", also = { "Silverpine" } },
	["Stormwind City"]       = { "Stormwind", "EK", also = { "Stormwind" } },
	["Stranglethorn Vale"]   = { "Stranglethorn", "EK", also = { "Stranglethorn" } },
	["Swamp of Sorrows"]     = { "SwampOfSorrows", "EK" },
	["The Hinterlands"]      = { "Hinterlands", "EK", also = { "Hinterlands" } },
	["Tirisfal Glades"]      = { "Tirisfal", "EK", also = { "Tirisfal", "Deathknell" } },
	["Undercity"]            = { "Undercity", "EK" },
	["Western Plaguelands"]  = { "WesternPlaguelands", "EK" },
	["Westfall"]             = { "Westfall", "EK" },
	["Wetlands"]             = { "Wetlands", "EK" },
	["Ashenvale"]            = { "Ashenvale", "K" },
	["Azshara"]              = { "Aszhara", "K" },
	["Darkshore"]            = { "Darkshore", "K" },
	["Darnassus"]            = { "Darnassis", "K" },
	["Desolace"]             = { "Desolace", "K" },
	["Durotar"]              = { "Durotar", "K", also = { "Valley of Trials" } },
	["Dustwallow Marsh"]     = { "Dustwallow", "K", also = { "Dustwallow" } },
	["Felwood"]              = { "Felwood", "K" },
	["Feralas"]              = { "Feralas", "K" },
	["Moonglade"]            = { "Moonglade", "K" },
	["Mulgore"]              = { "Mulgore", "K", also = { "Camp Narache" } },
	["Orgrimmar"]            = { "Ogrimmar", "K" },
	["Silithus"]             = { "Silithus", "K" },
	["Stonetalon Mountains"] = { "StonetalonMountains", "K", also = { "Stonetalon" } },
	["Tanaris"]              = { "Tanaris", "K" },
	["Teldrassil"]           = { "Teldrassil", "K", also = { "Shadowglen" } },
	["The Barrens"]          = { "Barrens", "K", also = { "Barrens" } },
	["Thousand Needles"]     = { "ThousandNeedles", "K" },
	["Thunder Bluff"]        = { "ThunderBluff", "K" },
	["Un'Goro Crater"]       = { "UngoroCrater", "K", also = { "Un'Goro", "Un'goro", "Ungoro" } },
	["Winterspring"]         = { "Winterspring", "K" },
	-- Turtle WoW's own, where pfUI's map data names their maps.
	["Balor"]                = { "Balor" },
	-- No map data; their pictures are maps the addon carries (Theme.zonemap).
	["Moonwhisper Coast"]    = { "MoonwhisperCoast" },
	["Scarlet Enclave"]      = { "ScarletEnclave" },
	["Blackstone Island"]    = { "BlackstoneIsland" },
	["Gillijim's Isle"]      = { "Gillijim" },
	["Gilneas"]              = { "Gilneas" },
	["Grim Reaches"]         = { "GrimReaches" },
	["Hyjal"]                = { "Hyjal" },
	["Icepoint Rock"]        = { "Icepoint" },
	["Lapidis Isle"]         = { "Lapidis" },
	["Northwind"]            = { "Northwind" },
	["Tel'Abim"]             = { "TelAbim" },
	["Thalassian Highlands"] = { "ThalassianHighlands" },
}
Browser.CONTINENTS = { { "EK", "Eastern Kingdoms" }, { "K", "Kalimdor" } }

-- The instances besides the dungeons the setup and the Dungeons page list
-- (DUNGEON_INFO, TURTLE_DUNGEON_INFO): the later dungeons and the raids.
Browser.INSTANCES = {
	"Blackrock Spire", "Dire Maul", "Scholomance", "Stratholme", "Onyxia's Lair", "Molten Core",
	"Blackwing Lair", "Zul'Gurub", "Ruins of Ahn'Qiraj", "Temple of Ahn'Qiraj", "Naxxramas",
}
-- What the Dungeons category calls the route legs that are dungeon runs.
Browser.ROUTE_LEGS = "On the routes"
-- ... and the attunement guides (Guides/Attunements/), with the packs' chains
-- that open a dungeon or raid, which have no level range to file them by:
-- RestedXP's Onyxia Attunement and Scholomance Key.
Browser.ACCESS = "Attunements and keys"
Browser.ACCESS_WORDS = { "Attunement", "Key" }
-- The attunement guides' own words for each, by side: { guide, instance,
-- kind ("raid" or "dungeon"), level, attuned = { quests } }.
Browser.ATTUNEMENTS = {}

--[[ Guides ---------------------------------------------------------------- ]]

--- A guide's title without its pack prefix: "Optimized/Duskwood (28-29)"
--- reads "Duskwood (28-29)".
function Browser.Title(name)
	return (string.gsub(name or "", "^[%w_]+/", ""))
end

--- Guides by the level they start at, then the level they end, then name.
function Browser.ByLevel(a, b)
	local alo, ahi = AegisPathfinder:ParseGuideLevelRange(a)
	local blo, bhi = AegisPathfinder:ParseGuideLevelRange(b)
	if not alo and not blo then return a < b end
	if not alo then return false end
	if not blo then return true end
	if alo ~= blo then return alo < blo end
	if ahi ~= bhi then return ahi < bhi end
	return a < b
end

local function ByName(a, b) return Browser.Title(a) < Browser.Title(b) end

--- The dungeon or raid a title names -- "Optimized/Uldaman (45-46)" is a
--- route's run through Uldaman -- the longest name that fits, or nil.
function Browser.DungeonIn(title)
	local best
	local function try(name)
		if name and string.find(title, name, 1, true) and string.len(name) > string.len(best or "") then best = name end
	end
	for _, list in ipairs({ AegisPathfinder.DUNGEON_INFO or {}, AegisPathfinder.TURTLE_DUNGEON_INFO or {} }) do
		for _, d in ipairs(list) do try(d.name) end
	end
	for _, name in ipairs(Browser.INSTANCES) do try(name) end
	return best
end

-- A leveling guide that is a dungeon run: it is listed under Dungeons.
local function RouteLeg(name)
	return Browser.DungeonIn(Browser.Title(name)) ~= nil
end

--- The attunement guides of a side, as their files tell them.
function AegisPathfinder:RegisterAttunements(side, list)
	Browser.ATTUNEMENTS[side] = list
end

--- What attunement guide `name` opens, for your side; nil for another guide.
function AegisPathfinder:AttunementInfo(name)
	for _, a in ipairs(Browser.ATTUNEMENTS[self.myfaction or ""] or {}) do
		if a.guide == name then return a end
	end
	return nil
end

--- Whether you are attuned: a quest that finishes guide `name` is handed in.
function AegisPathfinder:IsAttuned(name)
	local a = self:AttunementInfo(name)
	for _, q in ipairs(a and a.attuned or {}) do
		if self:IsQuestCompletedOnServer(q) then return true end
	end
	return false
end

--- Attunement guides: raids before dungeons, then by level, then name.
function Browser.ByAttunement(a, b)
	local ia, ib = AegisPathfinder:AttunementInfo(a), AegisPathfinder:AttunementInfo(b)
	local ra, rb = ia and ia.kind == "raid" and 0 or 1, ib and ib.kind == "raid" and 0 or 1
	if ra ~= rb then return ra < rb end
	local la, lb = ia and ia.level or 0, ib and ib.level or 0
	if la ~= lb then return la < lb end
	return a < b
end

--- Whether a pack's guide is a chain that opens a dungeon or raid: a word
--- of its title is one of ACCESS_WORDS.
function Browser.AccessChain(name)
	local title = " " .. Browser.Title(name) .. " "
	for _, word in ipairs(Browser.ACCESS_WORDS) do
		if string.find(title, "[%s:/]" .. word .. "[%s%(]") then return true end
	end
	return false
end

--- The guides the browser lists: every one registered for you -- a class
--- quest guide only when it is your class's and your race has its chain.
function AegisPathfinder:BrowserGuides()
	local out, seen = {}, {}
	for _, name in ipairs(self.guidelist or {}) do
		if self.guides[name] and not seen[name] and not self:IsRoutePackGuide(name)
			and (self:GetGuideCategory(name) ~= "class" or (self.IsMyClassGuide and self:IsMyClassGuide(name))) then
			seen[name] = true
			table.insert(out, name)
		end
	end
	return out
end

--- The zone a guide is in: the one its title names, else the one most of
--- its steps' |Z| tags name. Nil for none the browser knows. Asked once a
--- guide; the answer is kept.
function AegisPathfinder:GuideBrowserZone(name)
	Browser.zoneCache = Browser.zoneCache or {}
	local known = Browser.zoneCache[name]
	if known ~= nil then return known or nil end
	local zones = Browser.ZONES
	local zone = self:GuideZone(name)
	if not zones[zone or ""] then
		-- A zone, or a place in one, anywhere in the title: the longest match.
		zone = nil
		local title, best = Browser.Title(name), 0
		for z, info in pairs(zones) do
			for _, n in ipairs({ z, unpack(info.also or {}) }) do
				if string.len(n) > best and string.find(title, n, 1, true) then
					zone, best = z, string.len(n)
				end
			end
		end
	end
	if not zone then
		local fn = self.guides and self.guides[name]
		local text = type(fn) == "function" and fn()
		if type(text) == "string" then
			local count, most = {}, 0
			for z in string.gfind(text, "|Z|([^|]+)|") do
				if zones[z] then
					count[z] = (count[z] or 0) + 1
					if count[z] > most then zone, most = z, count[z] end
				end
			end
		end
	end
	Browser.zoneCache[name] = zone or false
	return zone
end

--[[ Folders ----------------------------------------------------------------

	A folder is { title, items }, an item either { folder = <folder> } or
	{ guide = <name> }. A category is a folder too. ]]

local function Folder(title, guides, sorter)
	table.sort(guides, sorter or Browser.ByLevel)
	local items = {}
	for _, g in ipairs(guides) do table.insert(items, { guide = g }) end
	return { title = title, items = items }
end

-- A long folder as folders by level; a short one as it is.
local function Banded(title, guides)
	if table.getn(guides) <= Browser.LONG then return Folder(title, guides) end
	local bands = {}
	for _, band in ipairs(Browser.BANDS) do
		local these = {}
		for _, g in ipairs(guides) do
			local lo = AegisPathfinder:ParseGuideLevelRange(g) or 1
			if lo >= band[1] and lo <= band[2] then table.insert(these, g) end
		end
		if table.getn(these) > 0 then table.insert(bands, { folder = Folder(band[3], these) }) end
	end
	return { title = title, items = bands }
end

--- Category `key`'s folder, as the browser shows it now.
function AegisPathfinder:BrowserCategory(key)
	local guides = self:BrowserGuides()
	local by, legs, access, attune = {}, {}, {}, {}
	for _, g in ipairs(guides) do
		local cat = self:GetGuideCategory(g)
		local packs = cat ~= "dungeon" and cat ~= "class" and cat ~= "profession"
		if cat == "attunement" then
			table.insert(attune, g)
		elseif packs and Browser.AccessChain(g) then
			table.insert(access, g)
		elseif packs and RouteLeg(g) then
			table.insert(legs, g)
		else
			by[cat] = by[cat] or {}
			table.insert(by[cat], g)
		end
	end
	local label
	for _, c in ipairs(Browser.CATEGORIES) do
		if c.key == key then label = c.label end
	end

	if key == "leveling" then
		local items = {}
		for _, pack in ipairs(PACKS) do
			if by[pack[1]] then table.insert(items, { folder = Banded(pack[2], by[pack[1]]) }) end
		end
		if by.zone then
			local per, other = {}, {}
			for _, g in ipairs(by.zone) do
				local info = Browser.ZONES[self:GuideBrowserZone(g) or ""]
				local c = info and info[2]
				if c then per[c] = per[c] or {}; table.insert(per[c], g) else table.insert(other, g) end
			end
			local zoneItems = {}
			for _, c in ipairs(Browser.CONTINENTS) do
				if per[c[1]] then table.insert(zoneItems, { folder = Folder(c[2], per[c[1]]) }) end
			end
			if table.getn(other) > 0 then table.insert(zoneItems, { folder = Folder("Other zones", other) }) end
			table.insert(items, { folder = { title = "Zone guides", items = zoneItems } })
		end
		if by.turtle then table.insert(items, { folder = Folder("Custom zones", by.turtle) }) end
		return { title = label, items = items }
	elseif key == "dungeons" then
		-- The dungeon guides; and first, the routes' own runs through a
		-- dungeon, each saying whose route it is on, then the attunements and
		-- keys: raid or dungeon, or Attuned once done, and the packs' own.
		local folder = Folder(label, by.dungeon or {})
		local packs = {}
		for _, pack in ipairs(PACKS) do packs[pack[1]] = pack[2] end
		local at = 1
		if legs[1] then
			local runs = Folder(Browser.ROUTE_LEGS, legs)
			for _, item in ipairs(runs.items) do item.why = packs[self:GetGuideCategory(item.guide)] end
			table.insert(folder.items, at, { folder = runs })
			at = at + 1
		end
		if attune[1] or access[1] then
			table.sort(attune, Browser.ByAttunement)
			table.sort(access, ByName)
			local items = {}
			for _, g in ipairs(attune) do
				local a = self:AttunementInfo(g)
				table.insert(items, { guide = g, why = self:IsAttuned(g) and "Attuned"
					or (a and a.kind == "raid" and "Raid" or "Dungeon") })
			end
			for _, g in ipairs(access) do
				table.insert(items, { guide = g, why = packs[self:GetGuideCategory(g)] })
			end
			table.insert(folder.items, at, { folder = { title = Browser.ACCESS, items = items } })
		end
		return folder
	elseif key == "class" then
		return Folder(label, by.class or {})
	elseif key == "professions" then
		return Folder(label, by.profession or {}, ByName)
	elseif key == "favorites" then
		local favs = {}
		for _, g in ipairs(guides) do
			if self:IsFavoriteGuide(g) then table.insert(favs, g) end
		end
		return Folder(label, favs, ByName)
	end
	return { title = label or "", items = {} }
end

--- Every guide whose title holds `text`, any case, by title.
function AegisPathfinder:BrowserSearch(text)
	local out = {}
	text = string.lower(text or "")
	if text == "" then return out end
	for _, g in ipairs(self:BrowserGuides()) do
		if string.find(string.lower(Browser.Title(g)), text, 1, true) then table.insert(out, g) end
	end
	table.sort(out, ByName)
	return out
end

--- The sidebar category a guide belongs to: "leveling", "dungeons",
--- "class" or "professions".
function AegisPathfinder:BrowserCategoryOf(name)
	local cat = self:GetGuideCategory(name)
	if cat == "dungeon" then return "dungeons" end
	if cat == "class" then return "class" end
	if cat == "profession" then return "professions" end
	if cat == "attunement" or RouteLeg(name) or Browser.AccessChain(name) then return "dungeons" end
	return "leveling"
end

--[[ Progress, favourites, recent ---------------------------------------- ]]

--- How far through guide `name` you are, 0 to 1.
function AegisPathfinder:GuideProgress(name)
	local db = self.db.char
	if db.currentguide == name and self.current and self.actions and table.getn(self.actions) > 0 then
		return math.min(1, (self.current - 1) / table.getn(self.actions))
	end
	return (db.completion or {})[name] or 0
end

--- How guide `name` suits `level`, as the quest log colours a quest (a
--- Theme.LEVEL_COLORS key): "grey" once outlevelled, "green" in its range,
--- then "yellow", "orange" and "red" the further short of it. Nil for a
--- guide without levels, and a profession's, whose range is its skill.
function AegisPathfinder:GuideDifficulty(name, level)
	local lo, hi = self:ParseGuideLevelRange(name)
	if not lo or not level or self:GetGuideCategory(name) == "profession" then return nil end
	if level > hi then return "grey" end
	if level >= lo then return "green" end
	if lo - level <= 2 then return "yellow" end
	if lo - level <= 5 then return "orange" end
	return "red"
end

--- Whether guide `name` is done with: finished, or below `level`.
function AegisPathfinder:IsGuideDoneWith(name, level)
	if ((self.db.char.completion or {})[name] or 0) >= 1 then return true end
	local _, hi = self:ParseGuideLevelRange(name)
	return hi ~= nil and level ~= nil and level > hi
end

function AegisPathfinder:IsFavoriteGuide(name)
	return (self.db.char.favorites or {})[name] == true
end

function AegisPathfinder:ToggleFavoriteGuide(name)
	local favs = self.db.char.favorites or {}
	self.db.char.favorites = favs
	favs[name] = not favs[name] or nil
	return favs[name] == true
end

--- Remember `name` as the guide opened last.
function AegisPathfinder:NoteRecentGuide(name)
	if not name or name == self.NO_GUIDE then return end
	local list = self.db.char.recentguides or {}
	for i = table.getn(list), 1, -1 do
		if list[i] == name then table.remove(list, i) end
	end
	table.insert(list, 1, name)
	while table.getn(list) > Browser.RECENT_MAX do table.remove(list) end
	self.db.char.recentguides = list
end

--- The guides opened lately, the last first, up to `n`: only those still
--- registered.
function AegisPathfinder:RecentGuides(n)
	local out = {}
	for _, g in ipairs(self.db.char.recentguides or {}) do
		if self.guides[g] then table.insert(out, g) end
		if n and table.getn(out) >= n then break end
	end
	return out
end

--[[ What to do next ------------------------------------------------------ ]]

--- The ticked dungeons whose guide fits `level` as a custom zone does (one
--- short of its bottom to its top), not finished: { guide }. None in Solo
--- Self-Found.
function AegisPathfinder:DungeonGuidesAtLevel(level)
	local db = self.db.char
	local out = {}
	if db.SelfFound or not level then return out end
	local ticked, completion = db.Dungeons or {}, db.completion or {}
	for _, list in ipairs({ self.DUNGEON_INFO or {}, self.TURTLE_DUNGEON_INFO or {} }) do
		for _, d in ipairs(list) do
			if ticked[d.code] then
				local prefix = "Dungeons/" .. d.name .. " ("
				for _, g in ipairs(self.guidelist or {}) do
					if self.guides[g] and string.sub(g, 1, string.len(prefix)) == prefix and (completion[g] or 0) < 1 then
						local lo, hi = self:ParseGuideLevelRange(g)
						if lo and hi and level >= lo - 1 and level <= hi then table.insert(out, g) end
					end
				end
			end
		end
	end
	table.sort(out, Browser.ByLevel)
	return out
end

--- What fits you now, up to SUGGEST_MAX: { guide, why }. The route's next
--- leg; the class quests ready for you; ticked dungeons and custom zones at
--- your level.
function AegisPathfinder:BrowserSuggestions()
	local out, seen = {}, {}
	local function add(g, why)
		if g and self.guides[g] and not seen[g] and table.getn(out) < Browser.SUGGEST_MAX then
			seen[g] = true
			table.insert(out, { guide = g, why = why })
		end
	end
	local level = UnitLevel("player")
	local tabs = self.EnsureTabs and self:EnsureTabs()
	local main = (tabs and tabs[1] and tabs[1].guide) or self.db.char.currentguide
	if main and self.GetRouteSuccessor then add(self:GetRouteSuccessor(main), "Next on your route") end
	if self.GetClassMilestones then
		for _, m in ipairs(self:GetClassMilestones(level, true)) do add(m.guide, "A class quest at your level") end
	end
	for _, g in ipairs(self:DungeonGuidesAtLevel(level)) do add(g, "A ticked dungeon at your level") end
	for _, s in ipairs(self:AttunementsToDo(level)) do add(s.guide, s.why) end
	if self.GetCustomZoneChoices then
		for _, z in ipairs(self:GetCustomZoneChoices(level, main)) do add(z.guide, "A custom zone at your level") end
	end
	return out
end

--- The attunements to suggest at `level`: those you have started and not
--- finished, then the first you can start -- the lowest level, a raid's
--- before a dungeon's -- so a level 60 is not offered all of them at once.
function AegisPathfinder:AttunementsToDo(level)
	local started, fresh = {}, nil
	local list = {}
	for _, a in ipairs(Browser.ATTUNEMENTS[self.myfaction or ""] or {}) do
		if self.guides[a.guide] then table.insert(list, a.guide) end
	end
	table.sort(list, Browser.ByAttunement)
	for _, g in ipairs(list) do
		local a = self:AttunementInfo(g)
		if not self:IsAttuned(g) and (level or 0) >= a.level then
			if (self:GuideProgress(g) or 0) > 0 then
				table.insert(started, { guide = g, why = "An attunement you started: " .. a.instance })
			elseif not fresh or a.level < fresh.level then
				fresh = { guide = g, level = a.level, why = "Opens " .. a.instance .. ", at your level" }
			end
		end
	end
	if fresh then table.insert(started, fresh) end
	return started
end

--- Whether guide `name` is among the suggestions now (the list's star).
function AegisPathfinder:IsSuggestedGuide(name)
	for _, s in ipairs(self:BrowserSuggestions()) do
		if s.guide == name then return true end
	end
	return false
end

--[[ The trackers ------------------------------------------------------------

	Time at each level is counted while you play: from logging in, banked at
	each level up, each loading screen and at logout. A level reached before
	this was here is counted from then on, so the first level's figure is
	short. Gold earned is every rise in your money -- loot, quest rewards,
	sales, mail -- by day and by week; spending is not taken off. ]]

local clock = { since = nil, level = nil }
Browser.clock = clock

local function Now() return GetTime() end

-- Add the time since the clock last started to the level it was running for.
local function Bank()
	local db = AegisPathfinder.db and AegisPathfinder.db.char
	if not db or not clock.since or not clock.level then return end
	db.leveltime = db.leveltime or {}
	db.leveltime[clock.level] = (db.leveltime[clock.level] or 0) + (Now() - clock.since)
	clock.since = Now()
end

local function DateKeys()
	local d = date or (os and os.date)
	return d("%Y-%m-%d"), d("%Y-%W")
end

--- Handle the trackers' events; `arg1` as the event gives it.
function AegisPathfinder:TrackerEvent(event, a1)
	local db = self.db and self.db.char
	if not db then return end
	if event == "PLAYER_ENTERING_WORLD" then
		if not clock.since then clock.since, clock.level = Now(), UnitLevel("player") end
		local gold = db.gold or {}
		db.gold = gold
		gold.last = GetMoney()
	elseif event == "PLAYER_LEVEL_UP" then
		Bank()
		clock.level = tonumber(a1) or UnitLevel("player")
		clock.since = Now()
		-- Counted from its first minute: its time is the whole of it.
		db.levelwhole = db.levelwhole or {}
		db.levelwhole[clock.level] = true
	elseif event == "PLAYER_LOGOUT" or event == "PLAYER_LEAVING_WORLD" then
		-- Banked before every loading screen too, so the time is in the saved
		-- table well before the client writes it out.
		Bank()
	elseif event == "PLAYER_MONEY" then
		local gold = db.gold or {}
		db.gold = gold
		local now = GetMoney()
		local gained = gold.last and now - gold.last or 0
		gold.last = now
		if gained > 0 then
			local day, week = DateKeys()
			if gold.day ~= day then gold.day, gold.today = day, 0 end
			if gold.week ~= week then gold.week, gold.thisweek = week, 0 end
			gold.today = (gold.today or 0) + gained
			gold.thisweek = (gold.thisweek or 0) + gained
		end
	end
end

--- Time played at each level counted so far, the highest first: { level,
--- seconds, current }, the level you are at counting up as you play.
function AegisPathfinder:LevelTimes()
	local db = self.db.char
	local times = {}
	for level, secs in pairs(db.leveltime or {}) do times[tonumber(level)] = secs end
	if clock.since and clock.level then
		times[clock.level] = (times[clock.level] or 0) + (Now() - clock.since)
	end
	local out = {}
	for level, secs in pairs(times) do
		table.insert(out, { level = level, seconds = secs, current = level == clock.level })
	end
	table.sort(out, function(a, b) return a.level > b.level end)
	return out
end

--- Seconds played at `level` so far, and whether that is all of it: the
--- level began while the tracker was counting. Right after a level up, the
--- level just left, whichever of the level-up handlers runs first.
function AegisPathfinder:TimeAtLevel(level)
	local db = self.db.char
	local secs = (db.leveltime or {})[level]
	if clock.since and clock.level == level then secs = (secs or 0) + (Now() - clock.since) end
	return secs, (db.levelwhole or {})[level] == true
end

--- Gold earned today and this week, in copper.
function AegisPathfinder:GoldEarned()
	local gold = self.db.char.gold or {}
	local day, week = DateKeys()
	return gold.day == day and (gold.today or 0) or 0, gold.week == week and (gold.thisweek or 0) or 0
end

--- "1h 12m", "58m 40s", "40s".
function Browser.Duration(secs)
	secs = math.floor(secs or 0)
	local h, m, s = math.floor(secs / 3600), math.floor(math.mod(secs, 3600) / 60), math.mod(secs, 60)
	if h > 0 then return string.format("%dh %02dm", h, m) end
	if m > 0 then return string.format("%dm %02ds", m, s) end
	return string.format("%ds", s)
end

--- Copper as gold, silver and copper: { {"3", "g"}, {"41", "s"}, {"12", "c"} },
--- leading zero amounts left out (always the copper).
function Browser.Coins(copper)
	copper = math.floor(copper or 0)
	local g, s, c = math.floor(copper / 10000), math.floor(math.mod(copper, 10000) / 100), math.mod(copper, 100)
	local out = {}
	if g > 0 then table.insert(out, { tostring(g), "g" }) end
	if g > 0 or s > 0 then table.insert(out, { tostring(s), "s" }) end
	table.insert(out, { tostring(c), "c" })
	return out
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:RegisterEvent("PLAYER_LEAVING_WORLD")
events:RegisterEvent("PLAYER_LOGOUT")
events:RegisterEvent("PLAYER_MONEY")
events:SetScript("OnEvent", function()
	if AegisPathfinder.db then AegisPathfinder:TrackerEvent(event, arg1) end
end)
Browser.events = events
