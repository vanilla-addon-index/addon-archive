local actiontypes = {
	A = "ACCEPT",
	C = "COMPLETE",
	T = "TURNIN",
	K = "KILL",
	R = "RUN",
	H = "HEARTH",
	h = "SETHEARTH",
	G = "GRIND",
	F = "FLY",
	f = "GETFLIGHTPOINT",
	N = "NOTE",
	B = "BUY",
	b = "BOAT",
	U = "USE",
	P = "PET",
	D = "DIE",
	t = "TRAIN",
}


--[[ Zones as the guides write them, and as the world map names them.

	A step without a |Z| tag is in the guide's zone, taken from its title, and
	some titles shorten it: "Optimized/Redridge (18-20)" is in Redridge
	Mountains. The map has no "Redridge", so every waypoint on such a step
	went to the zone you were standing in, and said so in chat -- "Cannot
	find zone "Redridge", using current zone." -- step after step. A few |Z|
	tags shorten the same way. ]]
AegisPathfinder.ZONE_NAMES = {
	["Alterac"] = "Alterac Mountains",
	["Arathi"] = "Arathi Highlands",
	["Barrens"] = "The Barrens",
	["Dustwallow"] = "Dustwallow Marsh",
	["Hillsbrad"] = "Hillsbrad Foothills",
	["Hinterlands"] = "The Hinterlands",
	["Redridge"] = "Redridge Mountains",
	["Stonetalon"] = "Stonetalon Mountains",
	["Stormwind"] = "Stormwind City",
	["Stranglethorn"] = "Stranglethorn Vale",
	["Tirisfal"] = "Tirisfal Glades",
	["Un'Goro"] = "Un'Goro Crater",
	["Un'goro"] = "Un'Goro Crater",
}

--- The world map's name for a zone as a guide writes it; nil for none.
function AegisPathfinder:ZoneName(name)
	if not name or name == "" then return nil end
	return self.ZONE_NAMES[name] or name
end

--- The zone a guide is in, from its title less any pack prefix:
--- "Optimized/Redridge (18-20)" is in Redridge Mountains.
function AegisPathfinder:GuideZone(name)
	local _, _, zone = string.find(name or "", "([^/]+) %(.*%)$")
	return self:ZoneName(zone)
end


function AegisPathfinder:GetObjectiveTag(tag, i)
	i = i or self.current
	if not self.tags then return end
	local tags = self.tags[i]
	if not tags then return end

	if tag == "O" then
		return string.find(tags, "|O|")
	elseif tag == "T" then
		return string.find(tags, "|T|")
	elseif tag == "S" then
		return string.find(tags, "|S|")
	elseif tag == "QID" then
		return self.select(3, string.find(tags, "|QID|(%d+)|"))
	elseif tag == "L" then
		local _, _, lootitem, lootqty = string.find(tags, "|L|(%d+)%s?(%d*)|")
		lootqty = tonumber(lootqty) or 1

		return lootitem, lootqty
	elseif tag == "SKILL" then
		-- |SKILL|<profession> <from> <to>| -- profession names can contain a
		-- space ("First Aid"), so match the two trailing numbers and take
		-- everything before them as the name.
		local _, _, profession, from, to = string.find(tags, "|SKILL|(.-)%s+(%d+)%s+(%d+)|")
		if not profession then return end

		return profession, tonumber(from), tonumber(to)
	elseif tag == "RANK" then
		-- |RANK|<profession> <cap>| -- the name can have a space in it.
		local _, _, profession, cap = string.find(tags, "|RANK|(.-)%s+(%d+)|")
		if not profession then return end

		return profession, tonumber(cap)
	elseif tag == "NPC" then
		-- |NPC|<name>;<name>| as a list.
		local _, _, list = string.find(tags, "|NPC|([^|]*)|")
		if not list then return end
		local names = {}
		for name in string.gfind(list, "[^;]+") do table.insert(names, name) end
		return names
	elseif tag == "CRAFT" then
		local _, _, count, item = string.find(tags, "|CRAFT|(%d+)%s+([^|]*)|")
		if not count then return end

		return item, tonumber(count)
	elseif tag == "Z" then
		return self:ZoneName(self.select(3, string.find(tags, "|Z|([^|]*)|?")))
	end

	return self.select(3, string.find(tags, "|" .. tag .. "|([^|]*)|?"))
end

--[[ What a boss step says for each role.

	A dungeon guide's boss steps carry a line for each role -- |TANK|, |HEAL|
	and |DPS| -- beside the note: what the tank, the healer and damage dealers
	should do about what the boss does. The guide window shows the lines for
	the role picked on the Dungeons page, or all three. ]]
AegisPathfinder.DUNGEON_ROLES = {
	{ key = "tank", tag = "TANK", label = "Tank", color = "blue" },
	{ key = "heal", tag = "HEAL", label = "Healer", color = "accentGlow" },
	{ key = "dps", tag = "DPS", label = "Damage", color = "danger" },
}

--- The role lines a step has for the role picked: { { role, text } }.
function AegisPathfinder:GetRoleLines(i)
	local pick = self.db and self.db.char and self.db.char.dungeonrole or "all"
	local out = {}
	for _, role in ipairs(self.DUNGEON_ROLES) do
		if pick == "all" or pick == role.key then
			local text = self:GetObjectiveTag(role.tag, i)
			if text and text ~= "" then table.insert(out, { role = role, text = text }) end
		end
	end
	return out
end

--- A step's note with its role lines under it, each labelled in its role's
--- colour; the note alone for a step with none.
function AegisPathfinder:GetStepNote(i)
	local note = self:GetObjectiveTag("N", i)
	local lines = self:GetRoleLines(i)
	if table.getn(lines) == 0 then return note end
	local out = {}
	if note and note ~= "" then table.insert(out, note) end
	for _, line in ipairs(lines) do
		table.insert(out, self.Theme:Code(line.role.color) .. line.role.label .. ":|r " .. line.text)
	end
	return table.concat(out, "\n")
end

--[[ Which dungeons a guide has steps for.

	The |D| filter runs at parse time, so a step for a dungeon the player has
	not opted into is gone from self.actions entirely -- there is no way to ask
	the parsed guide what it knows about. This scans the raw guide text
	instead, which is the only place the full picture survives.

	Used by the dungeon panel to mark which chips are relevant to the guide
	you are actually on. Results are cached per guide: the scan walks the whole
	guide text, and guides run to hundreds of steps.
]]
function AegisPathfinder:GetGuideDungeons(guideName)
	guideName = guideName or self.db.char.currentguide
	if not guideName then return {} end

	self.guidedungeoncache = self.guidedungeoncache or {}
	if self.guidedungeoncache[guideName] then
		return self.guidedungeoncache[guideName]
	end

	local found = {}
	local loader = self.guides and self.guides[guideName]
	if type(loader) == "function" then
		-- A guide that errors while loading must not take the panel down with
		-- it; an empty result just means no chips get marked.
		local ok, text = pcall(loader)
		if ok and type(text) == "string" then
			for tag in string.gfind(text, "|D|([^|]+)|") do
				for _, part in ipairs(self.split("/", tag)) do
					if string.sub(part, 1, 1) == "!" then part = string.sub(part, 2) end
					part = string.upper(part)
					if part ~= "" then found[part] = true end
				end
			end
		end
	end

	self.guidedungeoncache[guideName] = found

	return found
end

local function DumpQuestDebug(accepts, turnins, completes)
	for quest in pairs(accepts) do if not turnins[quest] then AegisPathfinder:Debug(string.format(
			"Quest has no 'turnin' objective: %s", quest)) end end
	for quest in pairs(turnins) do if not accepts[quest] then AegisPathfinder:Debug(string.format(
			"Quest has no 'accept' objective: %s", quest)) end end
	for quest in pairs(completes) do if not accepts[quest] and not turnins[quest] then AegisPathfinder:Debug(string.format(
			"Quest has no 'accept' and 'turnin' objectives: %s", quest)) end end
end


local titlematches = { "For", "A", "The", "Or", "In", "Then", "From", "To" }
local function DebugQuestObjective(text, action, quest, accepts, turnins, completes)
	local haserrors

	if (action == "A" and accepts[quest] or action == "T" and turnins[quest] or action == "C" and completes[quest]) and not string.find(text, "|NODEBUG|") then
		AegisPathfinder:Debug(string.format("%s %s -- Duplicate objective", action, quest))
		haserrors = true
	end

	if action == "A" then
		accepts[quest] = true
	elseif action == "T" then
		turnins[quest] = true
	elseif action == "C" then
		completes[quest] = true
	end

	if string.find(text, "|NODEBUG|") then return haserrors end

	if action == "A" or action == "C" or action == "T" then
		-- Catch bad Title Case
		for _, word in pairs(titlematches) do
			if string.find(quest, "[^:]%s" .. word .. "%s") or string.find(quest, "[^:]%s" .. word .. "$") or string.find(quest, "[^:]%s" .. word .. "@") then
				AegisPathfinder:Debug(string.format("%s %s -- Contains bad title case", action, quest))
				haserrors = true
			end
		end
	end

	local _, _, comment = string.find(text, "(|[NLUC]V?|[^|]+)$") or string.find(text, "(|[NLUC]V?|[^|]+) |[NLUC]V?|")
	if comment then
		AegisPathfinder:Debug("Unclosed comment: " .. comment)
		haserrors = true
	end

	return haserrors
end


local myclass, myrace = UnitClass("player"), UnitRace("player")
--- Whether a step of guide action `code` is left out on the Step Display
--- page's say: setting your hearthstone at an inn (h), or discovering a
--- flight path at a flight master (f).
function AegisPathfinder:SkipsStep(code)
	local db = self.db and self.db.char
	if not db then return false end
	return (code == "h" and db.skiphearth) or (code == "f" and db.skipflightpaths) or false
end

local function StepParse(guide)
	local accepts, turnins, completes = {}, {}, {}
	--[[ A step's key is its name and its place among ALL the guide's steps,
		whatever the filters keep. It was its place among the steps kept, so
		switching group mode, the Auction House, a dungeon chip or Solo
		Self-Found renumbered every step after the first one it added or took
		away, and the ticks saved against those keys landed on other steps.
		For a guide with nothing filtered the two are the same numbers.
		Ticks saved the old way are moved over once (MigrateStepKeys). ]]
	local place = 0
	local actions, quests, tags = {}, {}, {}
	local i, haserrors = 1, false
	local guidet = AegisPathfinder.split("\r\n", guide)

	local seenObjectives = {}
	local lastHearthLocation = nil

	local function matchFilter(filter, myValue)
		if not filter then return true end
		local components = AegisPathfinder.split("/", filter)
		local hasMatches = false
		local hasNegations = false

		for _, sp in ipairs(components) do
			if string.sub(sp, 1, 1) == "!" then
				hasNegations = true
				if string.sub(sp, 2) == myValue then return false end
			else
				if sp == myValue then hasMatches = true end
			end
		end

		if hasNegations and not hasMatches then return true end
		return hasMatches
	end

	local function matchDungeonFilter(dungeon)
		if not dungeon then return true end
		local components = AegisPathfinder.split("/", dungeon)
		local hasMatches = false
		local hasNegations = false

		for _, sp in ipairs(components) do
			local isNegation = string.sub(sp, 1, 1) == "!"
			local code = isNegation and string.sub(sp, 2) or sp
			code = string.upper(code)

			-- Solo Self-Found runs no dungeons, whichever are ticked.
			local db = AegisPathfinder.db and AegisPathfinder.db.char
			local isSelected = db and not db.SelfFound and db.Dungeons and db.Dungeons[code]

			if isNegation then
				hasNegations = true
				if isSelected then return false end
			else
				if isSelected then hasMatches = true end
			end
		end

		if hasNegations and not hasMatches then return true end
		return hasMatches
	end

	local function matchPlayStyleFilter(playstyle)
		if not playstyle then return true end
		local db = AegisPathfinder.db and AegisPathfinder.db.char
		-- Solo Self-Found is solo, whatever group mode says.
		local setting = db and not db.SelfFound and db.PlayStyle or "SOLO"
		return string.upper(playstyle) == string.upper(setting)
	end

	-- An |AH| step needs Auction House steps on and Solo Self-Found off; a
	-- |TRADE| step -- one that needs another player -- needs Self-Found off.
	local function matchAHFilter(ah, trade)
		local db = AegisPathfinder.db and AegisPathfinder.db.char
		if trade and db and db.SelfFound then return false end
		if not ah then return true end
		return db and not not db.UseAH and not db.SelfFound
	end

	for _, text in pairs(guidet) do
		local _, _, action, quest, tag = string.find(text, "^(%a) ([^|]*)(.*)")
		if action and actiontypes[action] then place = place + 1 end
		local _, _, class = string.find(text, "|C|([^|]+)|")
		local _, _, race = string.find(text, "|R|([^|]+)|")
		local _, _, dungeon = string.find(text, "|D|([^|]+)|")
		local _, _, playstyle = string.find(text, "|P|([^|]+)|")
		local hasAH = not not string.find(text, "|AH|", 1, true)
		local hasTrade = not not string.find(text, "|TRADE|", 1, true)
		if text ~= "" and matchFilter(class, myclass) and matchFilter(race, myrace)
			and matchDungeonFilter(dungeon) and matchPlayStyleFilter(playstyle)
			and matchAHFilter(hasAH, hasTrade) and not AegisPathfinder:SkipsStep(action) then
			if action and actiontypes[action] then
				quest = AegisPathfinder.trim(quest)
				
				-- Deduplicate duplicate ACCEPT (A), TURNIN (T), and SETHEARTH (h) objectives
				local cleanQuest = quest
				local qid = nil
				if tag then
					local _, _, qid_val = string.find(tag, "|QID|(%d+)|")
					qid = qid_val
				end
				
				local isDuplicate = false
				if action == "A" or action == "T" then
					local key = action .. ":" .. (qid or cleanQuest)
					if seenObjectives[key] then
						isDuplicate = true
					else
						seenObjectives[key] = true
					end
				elseif action == "h" then
					if cleanQuest == lastHearthLocation then
						isDuplicate = true
					else
						lastHearthLocation = cleanQuest
					end
				end
				
				if not isDuplicate then
					quest = quest .. "@" .. place .. "@"
					actions[i], quests[i], tags[i] = actiontypes[action], quest, tag
					i = i + 1
					haserrors = DebugQuestObjective(text, action, quest, accepts, turnins, completes) or haserrors
				end
			end
		end
	end
	DumpQuestDebug(accepts, turnins, completes)
	if haserrors and AegisPathfinder:IsDebugging() then AegisPathfinder:Print("This guide contains errors") end

	return actions, quests, tags
end


-- Drain a warm queue ({kind="q"|"i", id=n}) a few entries per tick instead of
-- all at once. A synchronous burst of hundreds of RequestLoad* calls at guide
-- load spikes CPU and, when the QIDs are for another server's content and never
-- resolve, can crash the client's fixed Lua pool. Each LoadGuide bumps
-- warmtoken so a queue from a previous guide stops draining.
local WARM_BATCH = 5      -- requests per tick
local WARM_INTERVAL = 0.1 -- seconds between ticks
function AegisPathfinder:WarmCaches(queue)
	self.warmtoken = (self.warmtoken or 0) + 1
	local token = self.warmtoken
	local n = table.getn(queue)
	local idx = 1
	local function drain()
		if token ~= self.warmtoken then return end -- superseded by a newer load
		local processed = 0
		while idx <= n and processed < WARM_BATCH do
			local e = queue[idx]
			idx = idx + 1
			processed = processed + 1
			if e.kind == "q" then
				if not C_QuestLog.IsQuestDataCachedByID(e.id) then
					C_QuestLog.RequestLoadQuestByID(e.id)
				end
			elseif not C_Item.IsItemDataCachedByID(e.id) then
				C_Item.RequestLoadItemDataByID(e.id)
			end
		end
		if idx <= n then C_Timer.After(WARM_INTERVAL, drain) end
	end
	drain()
end

--[[ Move a guide's saved ticks to the keys StepParse gives now, once.

	They were saved as name@N@ with N the step's place among the steps kept,
	which is its index here; they are now name@P@ with P its place among all
	the guide's steps. A guide ticked under the filters it was saved with
	maps step for step. Nothing is lost that was right: a tick saved under
	other filters was already on the wrong step. `db.char.stepkeys[guide]`
	says it is done, and a guide first opened now has nothing to move. ]]
function AegisPathfinder:MigrateStepKeys(name)
	local db = self.db.char
	db.stepkeys = db.stepkeys or {}
	if db.stepkeys[name] then return end
	db.stepkeys[name] = 2
	local saved = db.turnins[name]
	if not saved or not next(saved) then return end
	local moved = {}
	for i, quest in ipairs(self.quests or {}) do
		local old = string.gsub(quest, "@%d+@$", "") .. "@" .. i .. "@"
		if saved[old] then moved[quest] = saved[old] end
	end
	for k in pairs(saved) do saved[k] = nil end
	for k, v in pairs(moved) do saved[k] = v end
end

function AegisPathfinder:LoadGuide(name, complete)
	if not name then return end
	-- Your place (Core.lua's RememberPlace) belongs to the guide you leave.
	self.place = nil
	-- Record how far through the outgoing guide the player got. With every
	-- tab closed there is no outgoing guide -- no step, nothing parsed -- and
	-- nothing to record.
	local outgoing = self.db.char.currentguide
	if outgoing and outgoing ~= AegisPathfinder.NO_GUIDE then
		if complete then
			self.db.char.completion[outgoing] = 1
		elseif self.actions and self.current and table.getn(self.actions) > 0 then
			self.db.char.completion[outgoing] = (self.current - 1) / table.getn(self.actions)
		end
	end

	self.db.char.currentguide = self.guides[name] and name or self.guidelist[1]
	-- The guide browser's history (GuideBrowser.lua).
	if self.NoteRecentGuide then self:NoteRecentGuide(self.db.char.currentguide) end

	--[[ Keep the active tab pointing at what is actually loaded.

		Guides also change without anyone touching a tab -- LoadNextGuide when
		a route rolls over, or picking a different route pack -- and a tab bar
		naming the guide you were on two zones ago is worse than none.
	]]
	if self.EnsureTabs then
		local tab = self:GetActiveTab()
		if not tab then
			-- Loaded with every tab closed -- a route pick, or first login --
			-- so the guide gets a tab rather than showing with none.
			table.insert(self:EnsureTabs(), { guide = self.db.char.currentguide, step = 1 })
			self.db.char.activetab = 1
			self:SyncBranchState()
		elseif tab.guide ~= self.db.char.currentguide then
			tab.guide = self.db.char.currentguide
			tab.step = 1
		end
	end

	self:Debug(string.format("Loading guide: %s", name))
	self.guidechanged = true
	self.zonename = self:GuideZone(name)
	local guideContent = self.guides[self.db.char.currentguide]()
	if type(guideContent) == "table" and guideContent.steps then
		-- QuestShell+ format (Lua table with steps array)
		self.actions, self.quests, self.tags = self:ParseQuestShellPlus(guideContent)
	else
		-- Traditional AegisPathfinder format (string)
		self.actions, self.quests, self.tags = StepParse(guideContent)
	end

	-- Per-load loot-requirement cache; keyed by step index, so it must be
	-- dropped whenever the step list is re-parsed
	self.lootreqcache = {}

	-- Collect everything the guide references so later title/name/icon lookups
	-- are cache hits. The RequestLoad* calls are drained on a throttle (see
	-- WarmCaches): firing hundreds synchronously floods the engine's
	-- quest-query subsystem, and on a mismatched server (e.g. a Turtle guide on
	-- a vanilla realm) most QIDs never resolve, so a login-time burst of dead
	-- requests can exhaust the client's fixed Lua pool.
	local requested = {}
	local warmqueue = {}
	local function enqueue(kind, id)
		if not id then return end
		local key = kind .. id
		if requested[key] then return end
		requested[key] = true
		warmqueue[table.getn(warmqueue) + 1] = { kind = kind, id = id }
	end
	for i in ipairs(self.actions) do
		local qid = tonumber((self:GetObjectiveTag("QID", i)))
		enqueue("q", qid)
		enqueue("i", tonumber((self:GetObjectiveTag("L", i))))
		enqueue("i", tonumber((self:GetObjectiveTag("U", i))))

		-- Sanity-check authored |OIDX| tags against the quest's objective
		-- list; skipped silently while the static data is still loading
		local oidx = tonumber((self:GetObjectiveTag("OIDX", i)))
		if qid and oidx then
			local numObjectives = C_QuestLog.GetNumQuestObjectives(qid)
			if numObjectives and oidx > numObjectives then
				self:Debug(string.format("Step %d: |OIDX|%d| out of range - quest %d has %d objectives",
					i, oidx, qid, numObjectives))
			end
		end
	end
	self:WarmCaches(warmqueue)

	if not self.db.char.turnins[name] then self.db.char.turnins[name] = {} end
	self.turnedin = self.db.char.turnins[name]
	self:MigrateStepKeys(name)

	-- Step keys restart per guide, so the skipped-turnin warnings reset too
	self.turninskipwarned = {}

	if self.manuallyUnchecked then
		for k in pairs(self.manuallyUnchecked) do
			self.manuallyUnchecked[k] = nil
		end
	end

	-- Smart skip: scan quest log and skip to furthest incomplete step
	self:SmartSkipToStep()
end

-- Get quest prerequisites from pfQuest database (if available)
-- Returns table of prerequisite QIDs, or nil if not found
function AegisPathfinder:GetQuestPrerequisites(qid)
	if not qid then return nil end
	qid = tonumber(qid)
	if not qid then return nil end

	-- Check if pfQuest database is available
	if not pfDB or not pfDB["quests"] or not pfDB["quests"]["data"] then
		return nil
	end

	local questData = pfDB["quests"]["data"][qid]
	if questData and questData["pre"] then
		return questData["pre"]
	end
	return nil
end

-- Check if a quest is possible for the player's race and class
function AegisPathfinder:IsQuestPossible(qid, visited)
	if not qid then return true end
	qid = tonumber(qid)
	if not qid then return true end

	visited = visited or {}
	if visited[qid] then return true end
	visited[qid] = true

	local questOverrides = {
		-- Tauren starting area / Rites of the Earthmother chain (Tauren only)
		[752] = { race = 32 }, -- A Humble Task
		[753] = { race = 32 }, -- A Humble Task
		[755] = { race = 32 }, -- Rites of the Earthmother
		[757] = { race = 32 }, -- Rite of Strength
		[763] = { race = 32 }, -- The Rite of Vision
		[767] = { race = 32 }, -- The Rite of Vision
		[771] = { race = 32 }, -- The Rite of Vision
		[772] = { race = 32 }, -- The Rite of Vision
		[773] = { race = 32 }, -- Rite of Wisdom
	}

	local requiredRace, requiredClass
	local override = questOverrides[qid]
	if override then
		requiredRace = override.race
		requiredClass = override.class
	elseif pfDB and pfDB["quests"] and pfDB["quests"]["data"] then
		local questData = pfDB["quests"]["data"][qid]
		if questData then
			requiredRace = questData["race"]
			requiredClass = questData["class"]
		end
	end

	-- Check race restriction. The bits are pfQuest's (pfDB.bitraces, with
	-- pfQuest-turtle's two), keyed by UnitRace's second return: Undead is
	-- "Scourge" and High Elf "BloodElf" there. Goblin and High Elf were the
	-- wrong way round, so a Goblin read every Horde quest (mask 434) as not
	-- for its race and the guide ticked it done -- straight to step 100; and
	-- Undead and High Elves, under names the client does not use, were never
	-- checked at all.
	if requiredRace and requiredRace ~= 0 then
		local raceMap = {
			["Human"] = 1,
			["Orc"] = 2,
			["Dwarf"] = 4,
			["NightElf"] = 8,
			["Scourge"] = 16,
			["Undead"] = 16,
			["Tauren"] = 32,
			["Gnome"] = 64,
			["Troll"] = 128,
			["Goblin"] = 256,
			["BloodElf"] = 512,
			["HighElf"] = 512,
		}
		local _, myRaceFile = UnitRace("player")
		local myRaceMask = raceMap[myRaceFile]
		if myRaceMask then
			if math.mod(math.floor(requiredRace / myRaceMask), 2) == 0 then
				return false
			end
		end
	end

	-- Check class restriction
	if requiredClass and requiredClass ~= 0 then
		local classMap = {
			["WARRIOR"] = 1,
			["PALADIN"] = 2,
			["HUNTER"] = 4,
			["ROGUE"] = 8,
			["PRIEST"] = 16,
			["SHAMAN"] = 64,
			["MAGE"] = 128,
			["WARLOCK"] = 256,
			["DRUID"] = 1024,
		}
		local _, myClassFile = UnitClass("player")
		local myClassMask = classMap[myClassFile]
		if myClassMask then
			if math.mod(math.floor(requiredClass / myClassMask), 2) == 0 then
				return false
			end
		end
	end

	-- Recursively check prerequisites (only if not overridden)
	if not override then
		local prereqs = self:GetQuestPrerequisites(qid)
		if prereqs then
			for _, prereqQid in ipairs(prereqs) do
				if not self:IsQuestPossible(prereqQid, visited) then
					return false
				end
			end
		end
	end

	return true
end

-- Recursively mark all prerequisites of a quest as completed
-- Returns count of newly marked quests
function AegisPathfinder:MarkPrerequisitesCompleted(qid, visited)
	if not qid then return 0 end
	visited = visited or {}

	-- Prevent infinite loops
	if visited[qid] then return 0 end
	visited[qid] = true

	local prereqs = self:GetQuestPrerequisites(qid)
	if not prereqs then return 0 end

	local count = 0
	for _, prereqQid in ipairs(prereqs) do
		-- Mark this prerequisite as completed
		if not self.db.char.completedquestsbyid[prereqQid] then
			self.db.char.completedquestsbyid[prereqQid] = true
			self:Debug("Inferred completed (pfQuest prereq): QID " .. prereqQid)
			count = count + 1
		end
		-- Recursively mark its prerequisites
		count = count + self:MarkPrerequisitesCompleted(prereqQid, visited)
	end
	return count
end

-- Check if a quest's prerequisites are met
-- Returns: met (bool), unmetQids (table of unmet prerequisite QIDs)
function AegisPathfinder:ArePrerequisitesMet(qid)
	if not qid then return true, {} end
	qid = tonumber(qid)
	if not qid then return true, {} end

	local prereqs = self:GetQuestPrerequisites(qid)
	if not prereqs then return true, {} end

	local unmet = {}
	for _, prereqQid in ipairs(prereqs) do
		-- Check if prerequisite is completed (by QID or in quest log)
		local isComplete = self.db.char.completedquestsbyid[prereqQid]
		if not isComplete then
			-- Also check if it's in the quest log (accepted but not turned in yet)
			-- That means the player is working on it, which is fine
			local inLog = self:IsQuestInLogByQid(prereqQid)
			if not inLog then
				table.insert(unmet, prereqQid)
			end
		end
	end

	return table.getn(unmet) == 0, unmet
end

-- Check if a quest (by QID) is in the player's quest log
function AegisPathfinder:IsQuestInLogByQid(qid)
	qid = tonumber(qid)
	if not qid then return false end
	return C_QuestLog.IsOnQuest(qid)
end

-- Get quest name by QID
function AegisPathfinder:GetQuestNameByQid(qid)
	qid = tonumber(qid)
	if not qid then return nil end

	-- Server-authoritative quest cache first: guaranteed to match the titles
	-- the quest log uses (warmed for all guide QIDs at load)
	local title = C_QuestLog.GetTitleForQuestID(qid)
	if title then return title end

	-- Fall back to pfQuest localized quest names
	if pfDB and pfDB["quests"] and pfDB["quests"]["loc"] then
		local locData = pfDB["quests"]["loc"][qid]
		if locData then
			-- pfQuest stores quest data as table with "T" (title) field
			if type(locData) == "table" then
				return locData["T"]
			end
			return locData
		end
	end

	return nil
end

-- Find the guide step index for a given QID
-- Returns step index or nil if not found
function AegisPathfinder:FindGuideStepByQid(qid)
	if not qid or not self.quests or not self.actions then return nil end
	qid = tostring(qid)

	for i, quest in ipairs(self.quests) do
		local stepQid = self:GetObjectiveTag("QID", i)
		if stepQid == qid then
			return i
		end
	end
	return nil
end

-- Get unmet prerequisites for current objective, with guide step info
-- Returns table: { {qid=123, name="Quest Name", guideStep=5}, ... }
function AegisPathfinder:GetUnmetPrerequisites(stepIndex)
	stepIndex = stepIndex or self.current
	if not stepIndex then return {} end

	local qid = self:GetObjectiveTag("QID", stepIndex)
	if not qid then return {} end

	local met, unmetQids = self:ArePrerequisitesMet(qid)
	if met then return {} end

	local result = {}
	for _, prereqQid in ipairs(unmetQids) do
		local info = {
			qid = prereqQid,
			name = self:GetQuestNameByQid(prereqQid) or ("QID " .. prereqQid),
			guideStep = self:FindGuideStepByQid(prereqQid)
		}
		table.insert(result, info)
	end
	return result
end

-- Smart guide switching: scan quest log and skip completed content
function AegisPathfinder:SmartSkipToStep(look)
	if not self.actions or not self.quests then return end
	-- Quests under a collapsed header are not scanned below (GuideEngine.lua).
	if self.RevealGuideQuests then self:RevealGuideQuests() end

	-- Name-keyed maps serve steps without a |QID| tag; QID-keyed maps are
	-- authoritative for tagged steps and immune to duplicate quest names
	local completedQuests = {}
	local inProgressQuests = {}
	local completedQuestIDs = {}
	local inProgressQuestIDs = {}

	-- Scan quest log
	for i = 1, GetNumQuestLogEntries() do
		local title, _, _, isHeader, _, isComplete = GetQuestLogTitle(i)
		if not isHeader and title then
			local questID = C_QuestLog.GetQuestIDForLogIndex(i)
			title = string.gsub(title, "%[[0-9%+%-]+]%s", "")
			if isComplete == 1 then
				completedQuests[title] = true
				if questID then completedQuestIDs[questID] = true end
			else
				inProgressQuests[title] = true
				if questID then inProgressQuestIDs[questID] = true end
			end
		end
	end

	-- Database Self-Healing:
	-- If a quest is in the player's quest log, it cannot be fully turned in / completed.
	-- Clear any stale/corrupted completed flags for this quest and all its candidates in the guide.
	for i, quest in ipairs(self.quests) do
		local cleanQuest = string.gsub(quest, "@.*@", "")
		cleanQuest = string.gsub(cleanQuest, AegisPathfinder.Locale.PART_GSUB, "")
		local qidNum = tonumber((self:GetObjectiveTag("QID", i)))
		local inLog
		if qidNum then
			inLog = completedQuestIDs[qidNum] or inProgressQuestIDs[qidNum]
		else
			inLog = completedQuests[cleanQuest] or inProgressQuests[cleanQuest]
		end
		if inLog then
			-- Do not clear QID if it is confirmed completed in pfQuest history
			if qidNum and not (pfQuest_history and (pfQuest_history[qidNum] or pfQuest_history[tostring(qidNum)])) then
				self.db.char.completedquestsbyid[qidNum] = nil
			end
			self.db.char.completedquests[cleanQuest] = nil
		end
	end

	-- QUEST CHAIN INFERENCE via pfQuest database:
	-- For each quest in the guide that's in the player's log, look up its
	-- prerequisites in pfQuest and mark them as completed.
	if pfDB and pfDB["quests"] and pfDB["quests"]["data"] then
		for i, quest in ipairs(self.quests) do
			local action = self.actions[i]
			local qid = self:GetObjectiveTag("QID", i)
			if qid and (action == "ACCEPT" or action == "COMPLETE" or action == "TURNIN") then
				local cleanQuest = string.gsub(quest, "@.*@", "")
				cleanQuest = string.gsub(cleanQuest, AegisPathfinder.Locale.PART_GSUB, "")
				local qidInLog = inProgressQuestIDs[tonumber(qid)] or completedQuestIDs[tonumber(qid)]
				-- If quest is in log, mark its prerequisites as completed
				if qidInLog then
					local qidNum = tonumber(qid)
					local canInfer = true
					local prereqs = self:GetQuestPrerequisites(qidNum)
					if prereqs then
						for _, preQid in ipairs(prereqs) do
							if not self.db.char.completedquestsbyid[preQid] then
								-- Check if the prerequisite has the same name
								local preQuestData = pfDB["quests"]["data"][preQid]
								if preQuestData then
									local preQuestName = pfDB.quests.loc and pfDB.quests.loc[preQid] and
									pfDB.quests.loc[preQid]["T"] or nil
									if preQuestName then
										local cleanPreQuest = string.gsub(preQuestName, "%[[0-9%+%-]+]%s", "")
										cleanPreQuest = string.gsub(cleanPreQuest, AegisPathfinder.Locale.PART_GSUB, "")
										if cleanPreQuest == cleanQuest then
											canInfer = false
											break
										end
									end
								end
							end
						end
					end

					if canInfer then
						self:MarkPrerequisitesCompleted(qidNum)
					end
				end
			end
		end
	end

	-- Pre-mark completed quests by QID (from pfQuest inference) or impossible quests
	for i, quest in ipairs(self.quests) do
		local action = self.actions[i]
		local qid = self:GetObjectiveTag("QID", i)
		if qid then
			local qidNum = tonumber(qid)
			if (qidNum and self.db.char.completedquestsbyid[qidNum]) or not self:IsQuestPossible(qidNum) then
				if action == "TURNIN" or action == "ACCEPT" or action == "COMPLETE" or action == "RUN" then
					self.turnedin[quest] = true
				end
			end
		end
	end

	-- Pre-mark locally-tracked completed quests (by name)
	for i, quest in ipairs(self.quests) do
		local action = self.actions[i]
		local qid = self:GetObjectiveTag("QID", i)
		if not qid then
			local cleanQuest = string.gsub(quest, "@.*@", "")
			cleanQuest = string.gsub(cleanQuest, AegisPathfinder.Locale.PART_GSUB, "")
			if self.db.char.completedquests[cleanQuest] then
				if action == "TURNIN" or action == "ACCEPT" or action == "COMPLETE" or action == "RUN" then
					self.turnedin[quest] = true
				end
			end
		end
	end

	--[[ Where you are: the first step your quest log shows work at (a quest in
		progress, or ready to hand in), else the first step not done.

		It used to keep the last step not done instead of the first, so with
		nothing in your log -- a new character -- it put you at the end of the
		guide, and every step before counted as done. ]]
	local furthestStep = 1
	local firstOpen, byLog
	for i, quest in ipairs(self.quests) do
		local action = self.actions[i]
		local cleanQuest = string.gsub(quest, "@.*@", "")
		cleanQuest = string.gsub(cleanQuest, AegisPathfinder.Locale.PART_GSUB, "")
		local qidNum = tonumber((self:GetObjectiveTag("QID", i)))
		local isCompleted = (qidNum and self.db.char.completedquestsbyid[qidNum]) or
		(not qidNum and self.db.char.completedquests[cleanQuest])

		-- Quest log state, QID-keyed when the step is tagged
		local logInProgress, logComplete
		if qidNum then
			logInProgress = inProgressQuestIDs[qidNum]
			logComplete = completedQuestIDs[qidNum]
		else
			logInProgress = inProgressQuests[cleanQuest]
			logComplete = completedQuests[cleanQuest]
		end

		if action == "ACCEPT" then
			-- If quest is in log or completed, mark as done
			if logInProgress or logComplete or isCompleted then
				self.turnedin[quest] = true
			end
		elseif action == "TURNIN" then
			-- If quest is complete and in log, we need to turn it in
			if logComplete and not self.turnedin[quest] then
				furthestStep, byLog = i, true
				break
			elseif isCompleted then
				self.turnedin[quest] = true
			end
		elseif action == "COMPLETE" then
			-- If quest is in progress but not complete, this is our step
			if logInProgress and not logComplete and not isCompleted then
				furthestStep, byLog = i, true
				break
			elseif logComplete or isCompleted then
				self.turnedin[quest] = true
			end
		elseif action == "RUN" then
			-- Run/Travel steps with QID: auto-complete if linked quest is done
			if qidNum and self.db.char.completedquestsbyid[qidNum] then
				self.turnedin[quest] = true
			end
		elseif action == "TRAIN" then
			if self:IsTrainingCompleted(cleanQuest) then
				self.turnedin[quest] = true
			end
		end

		-- Track last incomplete step
		local stepTurnedIn = self.turnedin[quest]
		if not stepTurnedIn and action == "TURNIN" then
			if not logInProgress and not logComplete and not isCompleted then
				stepTurnedIn = true
			end
		end

		if not stepTurnedIn and not firstOpen then
			firstOpen = i
			furthestStep = i
		end
	end

	if furthestStep > 1 then
		self:Debug(string.format(AegisPathfinder.Locale["Skipping to step %d (completed content detected)"], furthestStep))
	end

	--[[ The steps on the way that the quest log cannot vouch for.

		A note, a run, a flight path, a hearth: nothing in the log says
		whether you did them. When the log puts you further on, they were
		left unticked, and the next status update, which starts from step 1
		and stops at the first step not done, went back to the first of them.
		Loch Modan's opened at Crocolisk Hunting, step 28, then fell back to
		its opening note, step 1, 0 done.

		So each is ticked when the next quest step after it is one the log
		shows you have reached: accepted, done, handed in, or where the log
		put you. A flight path before a quest you have not picked up yet
		stays, and the guide still takes you there. `look` only finds the
		place (FindPlace) and ticks nothing. ]]
	if not look then
		local function reached(j)
			if j == furthestStep or self.turnedin[self.quests[j]] then return true end
			local qid = tonumber((self:GetObjectiveTag("QID", j)))
			if qid then
				return inProgressQuestIDs[qid] or completedQuestIDs[qid] or self.db.char.completedquestsbyid[qid]
					or (self.IsQuestCompletedOnServer and self:IsQuestCompletedOnServer(qid))
			end
			local name = string.gsub(string.gsub(self.quests[j], "@.*@", ""), AegisPathfinder.Locale.PART_GSUB, "")
			return inProgressQuests[name] or completedQuests[name] or self.db.char.completedquests[name]
		end
		local QUEST_STEP = { ACCEPT = true, COMPLETE = true, TURNIN = true }
		local nextReached = byLog          -- the next quest step after i, reached?
		for i = furthestStep - 1, 1, -1 do
			local action = self.actions[i]
			if QUEST_STEP[action] then
				if reached(i) then
					nextReached = true
				elseif action ~= "TURNIN" and not self:GetObjectiveTag("O", i) then
					nextReached = false
				end
				-- A hand-in for a quest never picked up, and an optional
				-- quest not taken, the status update passes over: they say
				-- nothing either way.
			elseif nextReached and not self.turnedin[self.quests[i]] then
				self.turnedin[self.quests[i]] = true
			end
		end
	end

	-- Set initial current position
	self.current = furthestStep
end
