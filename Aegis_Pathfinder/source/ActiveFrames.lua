--[[
	ActiveFrames.lua -- the Active Items and Active Targets windows.

	Two small windows in the manner of RestedXP's, hanging under the guide.

	Active Items holds a button for every item the guide wants you to use: the
	current step's |U| item, and the |U| item of any other step whose quest is
	in your log and not yet done. It replaced a single floating button that
	only ever showed the current step's.

	Active Targets holds a button for whoever the current step wants you to
	find -- the quest's giver or hand-in, what its objectives want killed or
	drop, the trainer a profession step sends you to. A click targets them and
	marks them for what the quest wants with them: a star to talk, a square
	to interact with, a skull to kill, a cross to loot. RestedXP does this with a macro; a 1.12 addon may call TargetByName
	and SetRaidTarget itself, so this needs none.

	Quest icons put the same marks on by themselves as you mouse over or
	target anyone the current step or any quest in your log wants.

	The names come from the step's |NPC| tag, and from pfQuest's database by
	the step's quest id: its starters, enders, objective units, and the units
	that drop its objective items -- those that live where the step is, when
	any do (Nearby). Without pfQuest, only |NPC| steps have targets.

	Both windows hide when they have nothing to show, and when you close the
	guide (not when it hides itself in combat or an instance: the Appearance
	page's switches say what happens to them then). Each drags by its title
	and remembers where it was left; let go of one near another, or near the
	guide, and it snaps flush against it. Until dragged, Items hangs under the
	guide and Targets under Items. /apg target and /apg useitem, and two key
	bindings, do what the macros do -- /apg target takes the nearest of the
	step's targets, then the next one out on each press, which is the macro
	RestedXP asks you to make.
]]

local AegisPathfinder = AegisPathfinder
local Theme = AegisPathfinder.Theme

local TILE = 32
local GAP = 4
local PAD = 6
local HEADER_H = 18
local INSET = 3
local MAX_ITEMS = 6
local MAX_TARGETS = 4
local THROTTLE = 0.25

-- SetRaidTarget's indices.
local STAR, SQUARE, CROSS, SKULL = 1, 6, 7, 8
AegisPathfinder.RAID_MARKS = { STAR = STAR, SQUARE = SQUARE, CROSS = CROSS, SKULL = SKULL }

--[[ Quest icons: which mark says what, as RestedXP has them.

	  star    talk      gives or takes the quest, or a trainer or vendor
	  square  interact  a friendly NPC the objectives involve
	  skull   kill      an enemy the quest wants dead
	  cross   loot      an enemy that drops what the quest wants collected
]]
local CONTEXT_MARK = { talk = STAR, interact = SQUARE, kill = SKULL, loot = CROSS }
local MARK_NAME = { [STAR] = "a star (talk)", [SQUARE] = "a square (interact)",
	[SKULL] = "a skull (kill)", [CROSS] = "a cross (loot)" }

-- The raid-marker sheet is a 4x4 grid in index order.
local MARK_SHEET = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local function MarkCoords(index)
	local col, row = math.mod(index - 1, 4), math.floor((index - 1) / 4)
	return col * 0.25, (col + 1) * 0.25, row * 0.25, (row + 1) * 0.25
end

BINDING_HEADER_AEGISPATHFINDER = "Aegis: Pathfinder"
BINDING_NAME_AEGISPATHFINDER_ACTIVEITEM = "Use the first active item"
BINDING_NAME_AEGISPATHFINDER_ACTIVETARGET = "Target and mark the next active target"

--[[ The data. ]]

-- Every item in the bags by id: where the first stack is, how many in all,
-- and its icon. By link rather than ClassicAPI, so it is the stock API.
local function BagScan()
	local held = {}
	for bag = 0, 4 do
		for slot = 1, GetContainerNumSlots(bag) or 0 do
			local link = GetContainerItemLink(bag, slot)
			local _, _, id = string.find(link or "", "item:(%d+)")
			id = tonumber(id)
			if id then
				local texture, count = GetContainerItemInfo(bag, slot)
				local entry = held[id]
				if entry then
					entry.count = entry.count + (count or 1)
				else
					held[id] = { bag = bag, slot = slot, count = count or 1, texture = texture }
				end
			end
		end
	end
	return held
end

-- Which steps carry a |U| item, remembered per step list.
local useTags, useSteps
local function UseSteps(self)
	if useTags ~= self.tags then
		useTags, useSteps = self.tags, {}
		for i, tags in pairs(self.tags or {}) do
			if type(tags) == "string" and string.find(tags, "|U|", 1, true) then
				table.insert(useSteps, i)
			end
		end
		table.sort(useSteps)
	end
	return useSteps
end

--- The items to offer: { id, step, bag, slot, count, texture }, the current
--- step's first. Only what is in the bags -- a button for an item you do
--- not have does nothing.
function AegisPathfinder:GetActiveItems()
	local out = {}
	if not self.actions or not self.current or not self.actions[self.current] then return out end

	local held, seen = BagScan(), {}
	local function add(id, step)
		id = tonumber(id)
		local h = id and held[id]
		if not h or seen[id] or table.getn(out) >= MAX_ITEMS then return end
		seen[id] = true
		table.insert(out, { id = id, step = step, bag = h.bag, slot = h.slot,
			count = h.count, texture = h.texture })
	end

	add(self:GetObjectiveTag("U", self.current), self.current)
	for _, i in ipairs(UseSteps(self)) do
		if i ~= self.current then
			local turnedin, logi, complete = self:GetObjectiveStatus(i)
			if not turnedin and logi and not complete then
				add(self:GetObjectiveTag("U", i), i)
			end
		end
	end
	return out
end

local function PfUnitName(id)
	local loc = pfDB and pfDB.units and pfDB.units.loc
	return loc and loc[id]
end

-- pfQuest marks the NPCs friendly to a faction with its letter.
local function PfFriendly(id)
	local data = pfDB and pfDB.units and pfDB.units.data and pfDB.units.data[id]
	local fac = data and data.fac
	if not fac then return false end
	local mine = UnitFactionGroup("player") == "Horde" and "H" or "A"
	return string.find(fac, mine, 1, true) ~= nil
end

-- A target list builder: `add(name, kind, context)` keeps the first of each
-- name, up to `max`, marked for its context.
local function TargetList(action, max)
	local out, seen = {}, {}
	local function add(name, kind, context)
		if not name or seen[name] or table.getn(out) >= max then return end
		seen[name] = true
		table.insert(out, { name = name, kind = kind, context = context,
			mark = CONTEXT_MARK[context], action = action })
	end
	return out, add
end

-- Whether pfQuest has unit `id` spawning in zone `zone` (by name).
local function SpawnsIn(id, zone)
	local data = pfDB.units and pfDB.units.data and pfDB.units.data[id]
	local loc = pfDB.zones and pfDB.zones.loc
	if not zone or not loc or not data or not data.coords then return false end
	for _, c in pairs(data.coords) do
		if loc[c[3]] == zone then return true end
	end
	return false
end

--[[ The ids in `ids` that live in the first of `zones` any of them live in,
	in the same order; all of them when none does, or pfQuest has no spawn
	points for them. Crocolisk Meat drops from every crocolisk in the world,
	and likelier from the Wetlands' and Stranglethorn's, so by drop chance
	alone Loch Modan's Crocolisk Hunting targeted those and never a Loch
	Crocolisk. ]]
local function Nearby(ids, zones)
	for _, zone in ipairs(zones or {}) do
		local here = {}
		for _, id in ipairs(ids) do
			if SpawnsIn(id, zone) then table.insert(here, id) end
		end
		if table.getn(here) > 0 then return here end
	end
	return ids
end

-- Who quest `qid` sends you to, by what the step does with it: its givers
-- to ACCEPT, its takers to TURNIN, and for COMPLETE its objective units
-- (friends to interact with, enemies to kill) then whoever drops its
-- objective items, likeliest first -- of those in `zones` (Nearby).
local function QuestTargets(qid, action, add, zones)
	local quests = pfDB and pfDB.quests and pfDB.quests.data
	local quest = qid and quests and quests[qid]
	if not quest then return end

	local function units(list, context)
		for _, id in ipairs(list or {}) do
			local friend = PfFriendly(id)
			add(PfUnitName(id), friend and "npc" or "enemy",
				context or (friend and "interact" or "kill"))
		end
	end

	if action == "ACCEPT" then
		units(quest.start and quest.start.U, "talk")
	elseif action == "TURNIN" then
		units(quest["end"] and quest["end"].U, "talk")
	elseif action == "COMPLETE" then
		units(Nearby(quest.obj and quest.obj.U or {}, zones))
		local items = pfDB.items and pfDB.items.data
		for _, itemId in ipairs(quest.obj and quest.obj.I or {}) do
			local drops = items and items[itemId] and items[itemId].U
			local sorted = {}
			for unit, chance in pairs(drops or {}) do
				table.insert(sorted, { id = unit, chance = tonumber(chance) or 0 })
			end
			table.sort(sorted, function(a, b)
				if a.chance ~= b.chance then return a.chance > b.chance end
				return a.id < b.id
			end)
			local ids = {}
			for _, d in ipairs(sorted) do table.insert(ids, d.id) end
			units(Nearby(ids, zones), "loot")
		end
	end
end

--- Whom step `i` (the current one by default) wants you to find:
--- { name, kind = "npc"|"enemy", context, mark, action }, at most
--- MAX_TARGETS. `context` is talk, interact, kill or loot; `mark` the raid
--- mark that says so.
function AegisPathfinder:GetActiveTargets(i)
	i = i or self.current
	if not self.actions or not i or not self.actions[i] then return {} end
	local action = self.actions[i]
	local out, add = TargetList(action, MAX_TARGETS)

	for _, name in ipairs(self:GetObjectiveTag("NPC", i) or {}) do add(name, "npc", "talk") end
	-- The step's zone, the guide's, then the one you are in.
	local zones = {}
	local function zone(z) if z and z ~= "" then table.insert(zones, z) end end
	zone((self:GetObjectiveTag("Z", i)))
	zone(self.zonename)
	zone(GetRealZoneText and GetRealZoneText())
	QuestTargets(tonumber((self:GetObjectiveTag("QID", i))), action, add, zones)
	return out
end

--[[ Quest icons.

	The mark goes on by itself when you mouse over or target someone a quest
	wants: the current step's targets, and for every other quest in your log
	its objectives -- or, once it is complete, whoever takes it. Only while a
	guide is open, only on the unmarked, the living and the non-players, and
	not in a raid, where marks belong to its leaders.
]]
local MAX_ICON_TARGETS = 40

--- Everyone quest icons may mark, by name: the step's first, then the log's.
function AegisPathfinder:GetQuestIconTargets(stepTargets)
	local byName, count = {}, 0
	local function keep(t)
		if not byName[t.name] and count < MAX_ICON_TARGETS then
			byName[t.name] = t
			count = count + 1
		end
	end
	for _, t in ipairs(stepTargets or {}) do keep(t) end

	-- The quest log's ids come from ClassicAPI; without it, the step alone.
	local ids = C_QuestLog and C_QuestLog.GetQuestIDForLogIndex
	if not ids or not pfDB then return byName end
	for li = 1, GetNumQuestLogEntries() or 0 do
		local _, _, _, isHeader, _, isComplete = GetQuestLogTitle(li)
		local qid = not isHeader and ids(li)
		if qid then
			local action = isComplete == 1 and "TURNIN" or "COMPLETE"
			local list, add = TargetList(action, MAX_TARGETS)
			QuestTargets(qid, action, add, { GetRealZoneText and GetRealZoneText() })
			for _, t in ipairs(list) do keep(t) end
		end
	end
	return byName
end

--[[ The actions. ]]

local activeItems, activeTargets = {}, {}
-- What the windows show of those: the Action Buttons page's button types
-- leave some out, while the macros, the key bindings and the quest icons
-- still have them all.
local windowItems, windowTargets = {}, {}

--- Use the `n`th active item (the first by default).
function AegisPathfinder:UseActiveItem(n)
	local entry = activeItems[n or 1]
	if not entry then
		self:Print("No item to use on this step.")
		return false
	end
	-- Where it is now: the bags can change under a list built a moment ago.
	local h = BagScan()[entry.id]
	if not h then
		self:Print("That item is no longer in your bags.")
		return false
	end
	UseContainerItem(h.bag, h.slot)
	-- Using a USE step's own item is the step.
	if entry.step == self.current and self:GetObjectiveInfo() == "USE" then self:SetTurnedIn() end
	return true
end

-- Mark `unit` for `entry`'s context. What the client says outranks the
-- database: someone to kill or loot who cannot be attacked is someone to
-- interact with. The same mark is not set again -- setting it again is how
-- the stock UI takes one off. A target button's mark (not `auto`, the quest
-- icons') waits on the Action Buttons page's raid marker switch; with it off
-- the buttons only target.
local function Mark(entry, unit, auto)
	unit = unit or "target"
	local char = AegisPathfinder.db and AegisPathfinder.db.char
	if not auto and char and char.raidmark == false then return true end
	local mark = entry.mark or STAR
	if (entry.context == "kill" or entry.context == "loot") and not UnitCanAttack("player", unit) then
		mark = SQUARE
	end
	if SetRaidTarget and GetRaidTargetIndex(unit) ~= mark then
		SetRaidTarget(unit, mark)
	end
	return true
end

local iconTargets = {}
-- True while a press looks round for the step's targets (Around): the target
-- changes once for everyone it passes, and none of them is to be marked or
-- lit up on the tiles (the PLAYER_TARGET_CHANGED handler, below).
local scanning = false

-- A guide to follow, with its window open. Hidden for combat or an instance
-- it still counts as open, as it does for the buttons.
local function GuideOpen(self)
	local g = self.objectiveframe
	if not g or not (g:IsShown() or self.hiddenForCombat or self.hiddenForInstance) then return false end
	return not (self.HasNoGuide and self:HasNoGuide())
end

--- Quest icons: mark `unit` ("mouseover" or "target") if a quest wants it --
--- only while a guide is open.
function AegisPathfinder:AutoMark(unit)
	local char = self.db and self.db.char
	if not char or char.questicons == false then return false end
	if not GuideOpen(self) then return false end
	if not UnitExists(unit) or UnitIsPlayer(unit) or UnitIsDead(unit) then return false end
	if GetNumRaidMembers and GetNumRaidMembers() > 0 then return false end
	-- Someone's mark already, ours or a party member's.
	if GetRaidTargetIndex(unit) then return false end
	local entry = iconTargets[UnitName(unit)]
	if not entry then return false end
	return Mark(entry, unit, true)
end

--[[ Each press, the next of the step's targets around you.

	TargetByName -- what /target does -- takes the nearest with the name, but
	keeps whoever you have targeted when they have it already: pressing the
	macro again stayed on the one Crocolisk. ClassicAPI's TargetNearest steps
	through everyone around you that you can attack or help, nearest first. A
	press looks through them (Around), keeps the step's targets, nearest
	first, and takes the one after whoever you have targeted -- the nearest,
	when that is nobody on the list. So the first press finds the nearest,
	and each one after it the next one out, and round again.

	Without those functions, or with none of the step's targets among those
	it reaches, it is TargetByName as it was. ]]
local AROUND = 30          -- units looked at in one press, at most
local FAR = 1e30           -- where a unit is, when its distance is unknown

-- The step's targets around you (`byName`: name to entry), nearest first,
-- as { guid, entry }. Looking changes the target; the caller puts it right.
local function Around(byName)
	local found, seen = {}, {}
	local function look()
		for _ = 1, AROUND do
			TargetNearest()
			local guid = UnitGUID("target")
			if not guid or seen[guid] then return end
			seen[guid] = true
			local entry = byName[UnitName("target")]
			if entry and not UnitIsPlayer("target") and not UnitIsDead("target") then
				local d, checked = FAR, false
				if UnitDistanceSquared then d, checked = UnitDistanceSquared("target") end
				table.insert(found, { guid = guid, entry = entry, d = checked and d or FAR })
			end
		end
	end
	-- Whatever happens, the quest icons come back on.
	scanning = true
	local ok, err = pcall(look)
	scanning = false
	if not ok then error(err, 0) end
	table.sort(found, function(a, b)
		if a.d ~= b.d then return a.d < b.d end
		return a.guid < b.guid
	end)
	return found
end

-- Target and mark the next of `entries` around you after the current target.
-- False, with the target put back, when none of them is around.
local function Cycle(entries)
	if not (TargetNearest and UnitGUID and TargetUnit) then return false end
	local byName = {}
	for _, e in ipairs(entries) do
		if not byName[e.name] then byName[e.name] = e end
	end
	local was = UnitGUID("target")
	local found = Around(byName)
	local n = table.getn(found)
	if n == 0 then
		if was then TargetUnit(was) elseif ClearTarget then ClearTarget() end
		return false
	end
	local pick = found[1]
	for i, u in ipairs(found) do
		if u.guid == was then
			pick = found[math.mod(i, n) + 1]
			break
		end
	end
	TargetUnit(pick.guid)
	return Mark(pick.entry)
end

-- The nearest with `entry`'s name, by TargetByName, marked; false for nobody.
local function ByName(entry)
	TargetByName(entry.name, true)
	if not UnitExists("target") or UnitName("target") ~= entry.name then return false end
	return Mark(entry)
end

--- Target `entry` -- the next one by that name around you, each press -- and
--- mark it. False, and a word in chat unless `quiet`, when nobody by that
--- name is close enough.
function AegisPathfinder:TargetActive(entry, quiet)
	if not entry then return false end
	if Cycle({ entry }) or ByName(entry) then return true end
	if not quiet then self:Print(entry.name .. " isn't close enough to target.") end
	return false
end

--- Mark the current target, if it is one of the step's. The last line of the
--- AegisTarget macro when it was /target lines; one saved that way still
--- calls it until the macro is next written.
function AegisPathfinder:MarkTarget()
	if not UnitExists("target") then return false end
	local name = UnitName("target")
	for _, t in ipairs(activeTargets) do
		if t.name == name then return Mark(t) end
	end
	return false
end

--- Target the next of the step's targets around you, so each press moves
--- on. What the AegisTarget macro, /apg target and the key binding do.
function AegisPathfinder:TargetNextActive()
	local n = table.getn(activeTargets)
	if n == 0 then
		self:Print("Nobody to target on this step.")
		return false
	end
	if Cycle(activeTargets) then return true end
	-- By name: the next name after the target's, round the list.
	local current = UnitExists("target") and UnitName("target")
	local start = 1
	for i, t in ipairs(activeTargets) do
		if t.name == current then start = i + 1 end
	end
	for k = 0, n - 1 do
		if ByName(activeTargets[math.mod(start - 1 + k, n) + 1]) then return true end
	end
	self:Print("None of this step's targets is close enough to target.")
	return false
end

--[[ The macros.

	RestedXP keeps a targeting macro up to date for you, so it can sit on an
	action bar. So does this: two character macros, AegisTarget and AegisItem,
	made on first use and rewritten whenever the step changes.

	AegisTarget is /apg target: each press the next of the step's targets
	around you, marked (TargetNextActive). It was a /target line per target,
	and /target stays on whoever you have targeted when they have the name,
	so pressing it again never moved on. AegisItem uses the first active
	item -- 1.12 has no /use -- and
	takes that item's icon when the macro icon list has it, so the button on
	your bar shows what it will use.

	1.12 gives each character 18 macros. With none free, nothing is made and
	the window says so. A macro is never rewritten while the macro window is
	open: the stock UI would save its own copy of the text over ours.
]]

local MACRO_SLOTS = 18         -- per character, and per account, on 1.12
local TARGET_MACRO, ITEM_MACRO = "AegisTarget", "AegisItem"
AegisPathfinder.MACROS = { TARGET = TARGET_MACRO, ITEM = ITEM_MACRO }
-- Icons by name: the macro icon list is read at run time, and the first of
-- these it has is the targeting macro's.
local TARGET_ICONS = { "Ability_Hunter_SniperShot", "Ability_TownWatch", "INV_Misc_Spyglass_02" }
local QUESTION_MARK = 1        -- the first macro icon

--- The macro index of `name`, among the account's and this character's.
local function FindMacro(name)
	local account, character = GetNumMacros()
	for i = 1, account or 0 do
		if GetMacroInfo(i) == name then return i end
	end
	for i = MACRO_SLOTS + 1, MACRO_SLOTS + (character or 0) do
		if GetMacroInfo(i) == name then return i end
	end
end
AegisPathfinder.FindMacro = FindMacro

-- A texture's file name, lower case: what a macro's icon comes down to.
local function IconBase(path)
	local _, _, base = string.find(string.lower(path or ""), "([^\\/]+)$")
	return base
end

--[[ How the macros are written.

	The stock CreateMacro and EditMacro take the icon as a place in the macro
	icon list, which the client fills lazily: until something asks for it,
	the list is empty. Read then, and kept, it made AegisTarget with the
	first place of an empty list -- no icon at all, a blank tile and a blank
	button. ClassicAPI's C_Macro takes the icon by name instead, so no list
	is involved, and an item's own icon can be set, which the list does not
	have. So C_Macro when it is there; the stock ones, with a list read again
	until it has something in it, when it is not. ]]
local function ByName()
	return C_Macro and C_Macro.CreateMacro and C_Macro.EditMacro and true or false
end

-- Macro icon places by file name, lower case; read again while the list
-- the client reports is not the one read.
local iconIndex, iconCount
local function MacroIcon(file)
	if not file then return QUESTION_MARK end
	local n = GetNumMacroIcons() or 0
	if not iconIndex or iconCount ~= n then
		iconIndex, iconCount = {}, n
		for i = 1, n do
			local base = IconBase(GetMacroIconInfo(i))
			if base and not iconIndex[base] then iconIndex[base] = i end
		end
	end
	local base = IconBase(file)
	return base and iconIndex[base] or nil
end

-- The targeting macro's icon: the first of TARGET_ICONS, by name for
-- C_Macro, else the first the icon list has.
local function TargetIcon()
	if ByName() then return TARGET_ICONS[1] end
	for _, file in ipairs(TARGET_ICONS) do
		if MacroIcon(file) then return file end
	end
end

-- AegisTarget's text. The same on every step: the step's targets are the
-- addon's to look round for, so a macro saved from an earlier step is not
-- stale.
local TARGET_BODY = "/apg target"

-- The stock action bars repaint a button when its slot changes, not when the
-- macro in it does; a new icon would wait for the next page turn otherwise.
local BARS = { "ActionButton", "BonusActionButton", "MultiBarBottomLeftButton",
	"MultiBarBottomRightButton", "MultiBarRightButton", "MultiBarLeftButton" }
local function RepaintBars(name)
	if not ActionButton_Update or not ActionButton_GetPagedID or not GetActionText then return end
	local saved = this
	for _, bar in ipairs(BARS) do
		for i = 1, 12 do
			local b = getglobal(bar .. i)
			if b then
				local ok, slot = pcall(ActionButton_GetPagedID, b)
				if ok and slot and GetActionText(slot) == name then
					this = b
					pcall(ActionButton_Update)
				end
			end
		end
	end
	this = saved
end

-- Rewrite one macro, or make it when `create`. `icon` is a texture, by
-- name or path, or nil for the question mark. Returns its index, and true
-- when it was made; nil when there is no such macro and none was made.
local function WriteMacro(name, icon, body, create)
	local byName = ByName()
	local place = not byName and (MacroIcon(icon) or QUESTION_MARK)
	-- The icon it should wear, as GetMacroInfo will say it: unknown when the
	-- stock list is still empty, and then left alone rather than rewritten.
	local want = byName and IconBase(icon or "INV_Misc_QuestionMark") or IconBase(GetMacroIconInfo(place))
	local index = FindMacro(name)
	if index then
		local _, texture, old = GetMacroInfo(index)
		if old ~= body or (want and IconBase(texture) ~= want) then
			if byName then
				index = C_Macro.EditMacro(index, name, icon or "INV_Misc_QuestionMark", body) or index
			else
				index = EditMacro(index, name, place, body) or index
			end
			RepaintBars(name)
		end
		return index
	end
	if not create then return nil end
	local _, character = GetNumMacros()
	if (character or 0) >= MACRO_SLOTS then return nil end
	if byName then return C_Macro.CreateMacro(name, icon or "INV_Misc_QuestionMark", body, true), true end
	return CreateMacro(name, place, body, nil, 1), true
end

--- Bring AegisTarget and AegisItem up to date -- always, so one on an action
--- bar never aims at a step that is over -- and make them when `create`.
--- False while the macro window is open, so the caller tries again.
function AegisPathfinder:SyncMacros(create)
	if MacroFrame and MacroFrame:IsVisible() then return false end
	local item = activeItems[1]
	local t, newT = WriteMacro(TARGET_MACRO, TargetIcon(), TARGET_BODY, create)
	local i, newI = WriteMacro(ITEM_MACRO, item and item.texture, "/apg useitem", create)
	if newT or newI then
		local made = (newT and newI) and "macros AegisTarget and AegisItem"
			or newT and "macro AegisTarget" or "macro AegisItem"
		self:Print("Made the character " .. made .. ". Drag from the Macros window onto an action bar; they follow the guide from then on.")
	end
	-- Only a macro that should exist and does not is a full book.
	if create then self.macroFull = not (t and i) or nil end
	return true
end

--[[ The windows. ]]

local items, targets, macros
local Request   -- ask for a repaint; defined with the driver below
local AnchorGrow   -- pin a dragged window by the corner it grows from; below

-- A tile: the theme's rounded square, an icon inside it, a count and a mark
-- in its corners.
local function Tile(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetWidth(TILE); b:SetHeight(TILE)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b.fill = Theme:NineSlice(b, Theme.texture.tabFill, "BACKGROUND", "panel2")
	b.border = Theme:NineSlice(b, Theme.texture.tabBorder, "BORDER", "subtle")

	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", INSET, -INSET)
	b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -INSET, INSET)

	b.count = b:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(b.count, "display", 10, "OUTLINE")
	b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
	Theme:TextColor(b.count, "text")

	b.mark = b:CreateTexture(nil, "OVERLAY")
	b.mark:SetTexture(MARK_SHEET)
	b.mark:SetWidth(12); b.mark:SetHeight(12)
	b.mark:SetPoint("TOPRIGHT", b, "TOPRIGHT", 3, 3)
	b.mark:Hide()

	-- Pressed: the icon sinks a pixel, as a button face would.
	b:SetScript("OnMouseDown", function()
		this.icon:SetPoint("TOPLEFT", this, "TOPLEFT", INSET + 1, -INSET - 1)
		this.icon:SetPoint("BOTTOMRIGHT", this, "BOTTOMRIGHT", -INSET + 1, INSET - 1)
	end)
	b:SetScript("OnMouseUp", function()
		this.icon:SetPoint("TOPLEFT", this, "TOPLEFT", INSET, -INSET)
		this.icon:SetPoint("BOTTOMRIGHT", this, "BOTTOMRIGHT", -INSET, INSET)
	end)
	return b
end

--[[ Snapping. Let go of a window near another -- or near the guide -- and it
	moves flush against it, side by side or one under the other, and lines up
	with the edge they share when that is near too. Measured on the screen,
	as the guide's scale can differ from the buttons'. ]]
local SNAP, SNAP_GAP = 14, 2
local function Snap(f)
	local s = f:GetEffectiveScale()
	local l, r, t, b = f:GetLeft(), f:GetRight(), f:GetTop(), f:GetBottom()
	if not (l and r and t and b) then return false end
	l, r, t, b = l * s, r * s, t * s, b * s
	local best, dx, dy
	for _, o in ipairs({ items, targets, macros, AegisPathfinder.objectiveframe }) do
		if o ~= f and o:IsShown() and o:GetLeft() and o:GetTop() then
			local os = o:GetEffectiveScale()
			local ol, orr, ot, ob = o:GetLeft() * os, o:GetRight() * os, o:GetTop() * os, o:GetBottom() * os
			local moves = {}
			if l < orr and r > ol then         -- one over the other
				table.insert(moves, { 0, ob - SNAP_GAP - t, true })
				table.insert(moves, { 0, ot + SNAP_GAP - b, true })
			end
			if b < ot and t > ob then          -- side by side
				table.insert(moves, { orr + SNAP_GAP - l, 0 })
				table.insert(moves, { ol - SNAP_GAP - r, 0 })
			end
			for _, m in ipairs(moves) do
				local d = math.abs(m[1]) + math.abs(m[2])
				if d <= SNAP and (not best or d < best) then
					best, dx, dy = d, m[1], m[2]
					if m[3] then
						if math.abs(ol - l) <= SNAP then dx = ol - l elseif math.abs(orr - r) <= SNAP then dx = orr - r end
					else
						if math.abs(ot - t) <= SNAP then dy = ot - t elseif math.abs(ob - b) <= SNAP then dy = ob - b end
					end
				end
			end
		end
	end
	if not best then return false end
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (l + dx) / s, (t + dy) / s)
	return true
end
AegisPathfinder.SnapActiveFrame = Snap

local function Window(name, title, key)
	local f = CreateFrame("Frame", name, UIParent)
	f:SetFrameStrata("MEDIUM")
	f:SetClampedToScreen(true)
	Theme:Scaled(f)
	f:SetWidth(TILE + PAD * 2)
	f:SetHeight(HEADER_H + PAD * 2 + TILE)
	Theme:Panel(f, "panel")

	local header = Theme:Header(f, HEADER_H)
	header.wordmark:Hide()
	local label = header:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(label, "display", 11)
	label:SetPoint("CENTER", header, "CENTER", 0, 0)
	label:SetText(string.upper(title))
	Theme:TextColor(label, "text")

	local save = Theme:PositionSaver(key)
	header:MakeDragHandle(f, function(frame)
		Snap(frame)
		AnchorGrow(frame)
		save(frame)
	end)
	f.save = save
	-- A window mid-drag is not re-anchored under the cursor.
	local start, stop = header:GetScript("OnDragStart"), header:GetScript("OnDragStop")
	header:SetScript("OnDragStart", function() f.moving = true; start() end)
	header:SetScript("OnDragStop", function() stop(); f.moving = nil end)

	f.header, f.label, f.key, f.tiles = header, label, key, {}
	f:Hide()
	return f
end

-- `f`'s first `n` tiles, built as needed; the rest hidden.
local function Fit(f, n, build)
	for i = table.getn(f.tiles) + 1, n do
		local b = build(f)
		b.index = i
		f.tiles[i] = b
	end
	local shown = {}
	for i, b in ipairs(f.tiles) do
		if i <= n then table.insert(shown, b) else b:Hide() end
	end
	return shown
end

--[[ Which way a window grows (the Action Buttons page): "right", the first
	tile at the left; "left", the first at the right; "down", a column from
	the top; "up", a column from the bottom. A window that has been dragged
	keeps the corner it grows from where you left it (AnchorGrow); until
	then it hangs under the guide. ]]
local function Grow(f)
	local char = AegisPathfinder.db and AegisPathfinder.db.char or {}
	return (f == items and char.itemsgrow) or (f == targets and char.targetsgrow) or "right"
end

-- Lay `tiles` out in `f` the way it grows, and size it to them.
local function Arrange(f, tiles)
	local dir, n = Grow(f), table.getn(tiles)
	for i, b in ipairs(tiles) do
		local k = (i - 1) * (TILE + GAP)
		b:ClearAllPoints()
		if dir == "left" then
			b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(PAD + k), -(HEADER_H + PAD))
		elseif dir == "down" then
			b:SetPoint("TOP", f, "TOP", 0, -(HEADER_H + PAD + k))
		elseif dir == "up" then
			b:SetPoint("BOTTOM", f, "BOTTOM", 0, PAD + k)
		else
			b:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + k, -(HEADER_H + PAD))
		end
		b:Show()
	end
	local run = PAD * 2 + n * TILE + math.max(n - 1, 0) * GAP
	local label = math.ceil(f.label:GetStringWidth()) + 24
	if dir == "up" or dir == "down" then
		f:SetWidth(math.max(PAD * 2 + TILE, label))
		f:SetHeight(HEADER_H + run)
	else
		f:SetWidth(math.max(run, label))
		f:SetHeight(HEADER_H + PAD * 2 + TILE)
	end
end

-- Pin a dragged window by the corner it grows from, where that corner is.
local CORNER = { right = "TOPLEFT", down = "TOPLEFT", left = "TOPRIGHT", up = "BOTTOMLEFT" }
AnchorGrow = function(f)
	local corner = CORNER[Grow(f)] or "TOPLEFT"
	local x = corner == "TOPRIGHT" and f:GetRight() or f:GetLeft()
	local y = corner == "BOTTOMLEFT" and f:GetBottom() or f:GetTop()
	if not x or not y then return false end
	f:ClearAllPoints()
	f:SetPoint(corner, UIParent, "BOTTOMLEFT", x, y)
	return true
end

-- Until dragged, Items hangs under the guide and Targets under Items -- or
-- under the guide, while Items has nothing to show.
local function Place(f, under)
	if f.moving or Theme:RestorePosition(f, f.key) then return end
	f:ClearAllPoints()
	f:SetPoint("TOPRIGHT", under, "BOTTOMRIGHT", 0, -6)
end

local function ItemTile(parent)
	local b = Tile(parent)
	b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b:SetScript("OnClick", function() AegisPathfinder:UseActiveItem(this.index) end)
	-- GameTooltip, because only it can show a game item.
	b:SetScript("OnEnter", function()
		this.border:SetTint("accent")
		local entry = windowItems[this.index]
		if not entry then return end
		GameTooltip:SetOwner(this, "ANCHOR_LEFT")
		GameTooltip:SetBagItem(entry.bag, entry.slot)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function()
		this.border:SetTint("subtle")
		GameTooltip:Hide()
	end)
	return b
end

-- The delete tile, after the items when your bags are full: the cheapest
-- thing in them, to make room (Automation.lua chooses it, and asks before
-- deleting anything that is not grey).
local function DeleteTile(parent)
	local b = Tile(parent)
	b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b.cross = b:CreateTexture(nil, "OVERLAY")
	b.cross:SetTexture(Theme.glyph.close)
	b.cross:SetWidth(12); b.cross:SetHeight(12)
	b.cross:SetPoint("TOPRIGHT", b, "TOPRIGHT", 2, 2)
	Theme:Tint(b.cross, "danger")
	b:SetScript("OnClick", function()
		local auto = AegisPathfinder.Automation
		if auto and this.entry then auto:DeleteCheapest(this.entry) end
	end)
	-- GameTooltip, because only it can show a game item.
	b:SetScript("OnEnter", function()
		this.border:SetTint("danger")
		local e = this.entry
		if not e then return end
		GameTooltip:SetOwner(this, "ANCHOR_LEFT")
		GameTooltip:SetBagItem(e.bag, e.slot)
		GameTooltip:AddLine("Your bags are full. Click to delete this, the cheapest thing in them"
			.. (e.grey and "." or (": a vendor would pay " .. AegisPathfinder.Automation.Money(e.value) .. ".")),
			0.78, 0.78, 0.74, 1)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function()
		this.border:SetTint("subtle")
		GameTooltip:Hide()
	end)
	return b
end

local function TargetTile(parent)
	local b = Tile(parent)
	b:SetScript("OnClick", function() AegisPathfinder:TargetActive(windowTargets[this.index]) end)
	b:SetScript("OnEnter", function()
		this.border:SetTint("accent")
		local entry = windowTargets[this.index]
		if not entry then return end
		local char = AegisPathfinder.db and AegisPathfinder.db.char or {}
		Theme:ShowTip(this, "TOP", entry.name, { char.raidmark == false and "Click to target."
			or string.format("Click to target and mark with %s.", MARK_NAME[entry.mark] or "a mark") })
	end)
	b:SetScript("OnLeave", function()
		AegisPathfinder:PaintTargetBorders()
		Theme:HideTip(this)
	end)
	return b
end

-- A macro's tile: click does what the macro does, dragging it picks the
-- macro up to drop on an action bar.
local function MacroTile(parent, name)
	local b = Tile(parent)
	b.macro = name
	b:RegisterForDrag("LeftButton")
	b:SetScript("OnDragStart", function()
		local index = FindMacro(this.macro)
		if index then
			PickupMacro(index)
		else
			AegisPathfinder:Print("There was no free character macro slot for " .. this.macro .. ".")
		end
	end)
	b:SetScript("OnLeave", function()
		this.border:SetTint("subtle")
		Theme:HideTip(this)
		GameTooltip:Hide()
	end)
	return b
end

local DRAG_HINT = "Drag onto an action bar: it follows the guide from then on."

local function MacroTargetTile(parent)
	local b = MacroTile(parent, TARGET_MACRO)
	b:SetScript("OnClick", function() AegisPathfinder:TargetNextActive() end)
	b:SetScript("OnEnter", function()
		this.border:SetTint("accent")
		local lines = { "The nearest, then the next one out each press:" }
		for _, t in ipairs(activeTargets) do table.insert(lines, t.name) end
		table.insert(lines, AegisPathfinder.macroFull and "No free character macro slot to make it in." or DRAG_HINT)
		Theme:ShowTip(this, "TOP", TARGET_MACRO .. " -- target and mark", lines)
	end)
	return b
end

local function MacroItemTile(parent)
	local b = MacroTile(parent, ITEM_MACRO)
	b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b:SetScript("OnClick", function() AegisPathfinder:UseActiveItem(1) end)
	-- GameTooltip, because only it can show a game item.
	b:SetScript("OnEnter", function()
		this.border:SetTint("accent")
		local entry = activeItems[1]
		if not entry then return end
		GameTooltip:SetOwner(this, "ANCHOR_LEFT")
		GameTooltip:SetBagItem(entry.bag, entry.slot)
		GameTooltip:AddLine(ITEM_MACRO .. ": " .. (AegisPathfinder.macroFull
			and "no free character macro slot to make it in." or DRAG_HINT), 0.78, 0.78, 0.74, 1)
		GameTooltip:Show()
	end)
	return b
end

function AegisPathfinder:CreateActiveFrames()
	if items then return end
	items = Window("AegisPathfinderActiveItems", "Active Items", "activeitems")
	targets = Window("AegisPathfinderActiveTargets", "Active Targets", "activetargets")
	macros = Window("AegisPathfinderMacros", "Macros", "activemacros")
	macros.targetTile = MacroTargetTile(macros)
	macros.itemTile = MacroItemTile(macros)
	items.deleteTile = DeleteTile(items)
	items.deleteTile:Hide()
	self.activeitemsframe, self.activetargetsframe, self.macrosframe = items, targets, macros
	self:ApplyButtonScale()
end

--- The three windows at the Action Buttons page's button size, on top of the
--- window scale.
function AegisPathfinder:ApplyButtonScale()
	if not items then return end
	local char = self.db and self.db.char
	local factor = char and char.buttonscale or 1
	for _, f in ipairs({ items, targets, macros }) do Theme:SetScaleFactor(f, factor) end
end

--- Which way Active Items ("items") or Active Targets ("targets") grows:
--- "right", "left", "up" or "down". A window you have dragged grows from the
--- matching corner, from where it is now.
function AegisPathfinder:SetActiveGrowth(which, dir)
	if not items then self:CreateActiveFrames() end
	local f = which == "targets" and targets or items
	self.db.char[which == "targets" and "targetsgrow" or "itemsgrow"] = dir
	if Theme:RestorePosition(f, f.key) and AnchorGrow(f) then f.save(f) end
	self:PaintActiveFrames()
end

-- The Macros window: a tile for whichever of the two has something to do.
local function PaintMacros(self, char, under)
	macros.targetTile:Hide()
	macros.itemTile:Hide()
	if char.showmacros == false then
		macros:Hide()
		return
	end

	local shown = {}
	if table.getn(activeTargets) > 0 then table.insert(shown, macros.targetTile) end
	if activeItems[1] then table.insert(shown, macros.itemTile) end

	-- The macros themselves, made once there is something for them to do;
	-- again in a moment if the macro window is open.
	if not self:SyncMacros(table.getn(shown) > 0) then Request(1) end
	if table.getn(shown) == 0 then
		macros:Hide()
		return
	end

	for i, b in ipairs(shown) do
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", macros, "TOPLEFT", PAD + (i - 1) * (TILE + GAP), -(HEADER_H + PAD))
		b:Show()
	end
	local n = table.getn(shown)
	macros:SetWidth(math.max(PAD * 2 + n * TILE + (n - 1) * GAP, math.ceil(macros.label:GetStringWidth()) + 24))

	-- The targeting macro wears its own icon, as it will on a bar.
	local index, texture = FindMacro(TARGET_MACRO), nil
	if index then _, texture = GetMacroInfo(index) end
	local t = macros.targetTile
	if texture then
		t.icon:SetTexture(texture)
		t.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		t.icon:SetVertexColor(1, 1, 1, 1)
	else
		t.icon:SetTexture(Theme.actionIcon.K)
		t.icon:SetTexCoord(0, 1, 0, 1)
		Theme:Tint(t.icon, "danger")
	end
	t.mark:SetTexCoord(MarkCoords(activeTargets[1] and activeTargets[1].mark or SKULL))
	t.mark:Show()

	local item = activeItems[1]
	if item then
		macros.itemTile.icon:SetTexture(item.texture)
		macros.itemTile.count:SetText(item.count > 1 and tostring(item.count) or "")
	end

	Place(macros, under)
	macros:Show()
end

--- Recount and repaint both windows.
function AegisPathfinder:PaintActiveFrames()
	if not items then self:CreateActiveFrames() end
	local char = self.db and self.db.char or {}
	local guide = self.objectiveframe or UIParent

	activeItems = char.showactiveitems ~= false and self:GetActiveItems() or {}
	windowItems = char.btnitems ~= false and activeItems or {}
	local cheap = char.showactiveitems ~= false and char.btndelete ~= false and self.Automation
		and self.Automation:CheapestToDelete()
	local n = table.getn(windowItems)
	local del = items.deleteTile
	if n > 0 or cheap then
		local shown = Fit(items, n, ItemTile)
		for i = 1, n do
			local b, entry = items.tiles[i], windowItems[i]
			b.icon:SetTexture(entry.texture)
			b.count:SetText(entry.count > 1 and tostring(entry.count) or "")
		end
		del.entry = cheap or nil
		if cheap then
			del.icon:SetTexture(cheap.texture)
			del.count:SetText(cheap.count > 1 and tostring(cheap.count) or "")
			table.insert(shown, del)
		else
			del:Hide()
		end
		Arrange(items, shown)
		Place(items, guide)
		items:Show()
	else
		del.entry = nil
		del:Hide()
		items:Hide()
	end

	-- The step's targets feed the macro and the quest icons as well, so they
	-- are worked out whether or not their window is showing.
	activeTargets = self:GetActiveTargets()
	iconTargets = self:GetQuestIconTargets(activeTargets)
	-- Talk to NPC covers talking and interacting; Kill enemy, killing and
	-- looting.
	windowTargets = {}
	if char.showactivetargets ~= false then
		for _, t in ipairs(activeTargets) do
			local hostile = t.context == "kill" or t.context == "loot"
			if (hostile and char.btnkill ~= false) or (not hostile and char.btntalk ~= false) then
				table.insert(windowTargets, t)
			end
		end
	end
	n = table.getn(windowTargets)
	if n > 0 then
		local shown = Fit(targets, n, TargetTile)
		Arrange(targets, shown)
		for i = 1, n do
			local b, entry = targets.tiles[i], windowTargets[i]
			local hostile = entry.context == "kill" or entry.context == "loot"
			local glyph = hostile and Theme.actionIcon.K
				or entry.context == "interact" and Theme.actionIcon.U
				or Theme.actionIconByName[entry.action] or Theme.actionIcon.N
			b.icon:SetTexture(glyph)
			Theme:Tint(b.icon, hostile and "danger" or "text")
			b.mark:SetTexCoord(MarkCoords(entry.mark))
			b.mark:Show()
			b.count:SetText("")
		end
		Place(targets, items:IsShown() and items or guide)
		targets:Show()
	else
		targets:Hide()
	end
	self:PaintTargetBorders()

	PaintMacros(self, char, targets:IsShown() and targets or items:IsShown() and items or guide)
	-- In combat, with the Appearance page's "hide the action buttons in
	-- combat too", or with the guide closed: worked out as ever, for the
	-- macros and the quest icons, but not shown. A guide hidden for combat
	-- or an instance has not been closed.
	local g = self.objectiveframe
	local closed = g and not g:IsShown() and not self.hiddenForCombat and not self.hiddenForInstance
	if self.buttonsHidden or closed then
		items:Hide()
		targets:Hide()
		macros:Hide()
	end
end

--- Light the tile of whoever is targeted now.
function AegisPathfinder:PaintTargetBorders()
	if not targets then return end
	local current = UnitExists("target") and UnitName("target")
	for i, b in ipairs(targets.tiles) do
		local entry = windowTargets[i]
		b.border:SetTint(entry and entry.name == current and "accent" or "subtle")
	end
end

--[[ Keeping up.

	The step settling asks for a repaint on the next frame. Bag updates come
	in bursts, so they ask for one THROTTLE later, and a burst is one repaint.
	A new target only relights the tiles, which is cheap enough to do at once.
]]
local driver = CreateFrame("Frame")
driver:Hide()
driver:SetScript("OnUpdate", function()
	if GetTime() < (this.due or 0) then return end
	this:Hide()
	AegisPathfinder:PaintActiveFrames()
end)
AegisPathfinder.activeDriver = driver

Request = function(delay)
	local due = GetTime() + (delay or 0)
	if not driver:IsShown() or due < (driver.due or 0) then driver.due = due end
	driver:Show()
end

function AegisPathfinder:RefreshActiveFrames()
	Request(0)
end

local events = CreateFrame("Frame")
events:RegisterEvent("BAG_UPDATE")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
events:SetScript("OnEvent", function()
	if event == "PLAYER_TARGET_CHANGED" then
		if scanning then return end
		AegisPathfinder:PaintTargetBorders()
		AegisPathfinder:AutoMark("target")
	elseif event == "UPDATE_MOUSEOVER_UNIT" then
		AegisPathfinder:AutoMark("mouseover")
	else
		Request(THROTTLE)
	end
end)
AegisPathfinder.activeEvents = events

--- Put each window back where the player left it, at login.
function AegisPathfinder:PositionActiveFrames()
	if not items then self:CreateActiveFrames() end
	self:ApplyButtonScale()
	Theme:RestorePosition(items, "activeitems")
	Theme:RestorePosition(targets, "activetargets")
	Theme:RestorePosition(macros, "activemacros")
end

--- Forget where they were dragged; they hang under the guide again.
function AegisPathfinder:ResetActiveFrames()
	Theme:ForgetPosition("activeitems")
	Theme:ForgetPosition("activetargets")
	Theme:ForgetPosition("activemacros")
	-- The old single use-item button's spot.
	Theme:ForgetPosition("itemframe")
	if items then self:PaintActiveFrames() end
end

AegisPathfinder:CreateActiveFrames()
