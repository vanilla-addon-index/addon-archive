--[[ ItemScore.lua -- what an item is worth to you, and whether it beats what
	you are wearing.

	A 1.12 client cannot ask an item for its stats: they are only ever written
	on its tooltip. So an item is read the way a player reads it -- a hidden
	tooltip is filled with it, and each line is matched against the stat
	patterns in ItemScoreData.lua (OctoPawn's, MIT). The stats found are
	weighted for your class and spec, past a soft cap each further point
	counting for less, and summed: the item's score.

	Your spec is the talent tree you have put most points into, until you pick
	one; below level 10, with no talents, it is your class's usual levelling
	spec. Each spec has two sets of weights (Tools/build/build_weights.py):
	one for leveling, used below 60, and one for 60. The tanks have one set,
	used at every level. Weights you change are kept per spec and set, on top
	of the defaults.

	Comparing is by slot. A ring or trinket is weighed against the weaker of
	the two you wear -- the one it would replace -- and a one-hander against
	your off hand too if you can dual wield. A two-hander is weighed against
	your main and off hand together. Enchants are left out on both sides, so
	an enchanted old item does not hide a better new one.

	Whether you can use an item is read off the same tooltip: the client
	colours red what you cannot use -- the armour or weapon type, a class or
	race you are not, a skill you lack. A red "Requires Level" alone means you
	can, later.
]]

local AegisPathfinder = AegisPathfinder
local Data = AegisPathfinder.ItemScoreData

local IS = {}
AegisPathfinder.ItemScore = IS

-- Talent trees as the 1.12 client names them, to the spec keys in the data.
local TREE_SPEC = {
	["Beast Mastery"] = "BeastMastery",
	["Feral Combat"] = "FeralCat",
}

-- Before talents: each class's usual levelling spec.
local LEVELLING_SPEC = {
	WARRIOR = "Arms", PALADIN = "Retribution", HUNTER = "BeastMastery", ROGUE = "Combat",
	PRIEST = "Shadow", SHAMAN = "Enhancement", MAGE = "Frost", WARLOCK = "Affliction",
	DRUID = "FeralCat",
}

local SPEC_LABEL = {
	BeastMastery = "Beast Mastery",
	FeralCat = "Feral (cat)",
	FeralBear = "Feral (bear)",
	EnhancementTank = "Enhancement (tank)",
}

-- Where each kind of item goes. Two slots: it takes whichever it beats more.
local SLOTS = {
	INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 },
	INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 },
	INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 },
	INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 },
	INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16 }, INVTYPE_2HWEAPON = { 16 },
	INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 },
	INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
	INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 },
	INVTYPE_RELIC = { 18 },
}
IS.SLOTS = SLOTS

local MAINHAND, OFFHAND = 16, 17

-- A ranged weapon's DPS is its own stat: a bow's is worth far more to a
-- hunter, and a wand's to a caster, than a melee weapon's.
local RANGED_WEAPON = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true }

-- The level the leveling weights give way to the 60 set at.
IS.MAX_LEVEL = 60

-- Raised when the default weights change so that edits made against the old
-- ones are cleared once (Initialize): 2 is the weights worked out for 0.23.4,
-- in place of OctoPawn's.
IS.WEIGHTS_VERSION = 2

--[[ Settings ]]

local function settings()
	local db = AegisPathfinder.db.char
	db.itemscore = db.itemscore or {}
	local s = db.itemscore
	if s.tooltips == nil then s.tooltips = true end
	if s.notify == nil then s.notify = true end
	s.custom = s.custom or {}
	s.active = s.active or {}      -- spec -> true: scored as well as yours
	s.best = s.best or {}          -- spec -> group -> { { item, score }, ... }
	return s
end
IS.Settings = settings

function IS:Class()
	local _, token = UnitClass("player")
	return token
end

--- Every spec the data has for a class, in a steady order.
function IS:Specs(class)
	local out = {}
	for spec in pairs(Data.weights[class or self:Class()] or {}) do table.insert(out, spec) end
	table.sort(out)
	return out
end

function IS:SpecLabel(spec)
	return SPEC_LABEL[spec] or spec
end

--- The tree with most points in it; nil with none spent.
function IS:DetectSpec(class)
	class = class or self:Class()
	local best, bestPoints = nil, 0
	for tab = 1, 3 do
		local name, _, points = GetTalentTabInfo(tab)
		if name and (points or 0) > bestPoints then
			best, bestPoints = TREE_SPEC[name] or string.gsub(name, " ", ""), points
		end
	end
	if best and Data.weights[class] and Data.weights[class][best] then return best end
	return nil
end

--- The spec scored for: the one picked, else the talents', else levelling's.
function IS:Spec()
	local class = self:Class()
	local picked = settings().spec
	if picked and Data.weights[class] and Data.weights[class][picked] then return picked, "picked" end
	local detected = self:DetectSpec(class)
	if detected then return detected, "talents" end
	return LEVELLING_SPEC[class], "levelling"
end

function IS:SetSpec(spec)
	settings().spec = spec
	self:Changed()
end

-- PLAYER_LEVEL_UP's new level: UnitLevel can still say the old one then.
local levelSeen

function IS:Level()
	local level = UnitLevel("player") or 1
	if levelSeen and levelSeen > level then return levelSeen end
	return level
end

--- The default weights for a class and spec at your level, and which set
--- they are: "leveling" below 60, "max" at 60 -- and for a spec with no
--- leveling set (the tanks) at every level.
function IS:Defaults(class, spec)
	class = class or self:Class()
	spec = spec or self:Spec()
	if self:Level() < IS.MAX_LEVEL then
		local leveling = ((Data.leveling or {})[class] or {})[spec]
		if leveling then return leveling, "leveling" end
	end
	return (Data.weights[class] or {})[spec] or {}, "max"
end

--- Where your changes to a spec's weights are kept: one place for each set,
--- so a change made while leveling is not carried into the 60 set.
function IS:CustomKey(class, spec)
	class = class or self:Class()
	spec = spec or self:Spec()
	local _, set = self:Defaults(class, spec)
	if set == "leveling" then return class .. ":" .. spec .. ":leveling" end
	return class .. ":" .. spec
end

--- The weights for a class and spec: the defaults, with your changes on top.
function IS:Weights(class, spec)
	class = class or self:Class()
	if not spec then spec = self:Spec() end
	local out = {}
	for stat, w in pairs(self:Defaults(class, spec)) do out[stat] = w end
	for stat, w in pairs(settings().custom[self:CustomKey(class, spec)] or {}) do out[stat] = w end
	return out
end

function IS:IsCustom(class, spec)
	return next(settings().custom[self:CustomKey(class, spec)] or {}) ~= nil
end

--- Change one weight of the spec scored for. Setting it back to the
--- default removes the change.
function IS:SetWeight(stat, value)
	local key = self:CustomKey()
	local custom = settings().custom
	custom[key] = custom[key] or {}
	local default = self:Defaults()[stat] or 0
	if math.abs((value or 0) - default) < 0.00005 then
		custom[key][stat] = nil
	else
		custom[key][stat] = value
	end
	if not next(custom[key]) then custom[key] = nil end
	self:Changed()
end

--- Back to the default weights, for the spec and set scored with now.
function IS:ResetWeights()
	settings().custom[self:CustomKey()] = nil
	self:Changed()
end

--- Clear edits made against older default weights, once. True if there were
--- any to clear.
function IS:MigrateWeights()
	local s = settings()
	if s.weightsVersion == IS.WEIGHTS_VERSION then return false end
	local had = next(s.custom) ~= nil
	s.custom = {}
	s.weightsVersion = IS.WEIGHTS_VERSION
	return had
end

local function trimNum(v)
	local s = string.format("%.4f", v)
	s = string.gsub(s, "0+$", "")
	s = string.gsub(s, "%.$", "")
	return s
end

--[[ Sharing weights, in OctoPawn's own string -- OPW1:CLASS:SPEC:*STAT:v|STAT:v.
	Each stat read from one is put over the defaults. The weights here are not
	OctoPawn's, so every stat is written out, those weighed 0 too: the scale
	arrives whole, in OctoPawn or in another copy of this addon at another
	level. ]]
function IS:Export()
	local class, spec = self:Class(), self:Spec()
	local weights = self:Weights(class, spec)
	local parts = {}
	for _, stat in ipairs(Data.stats) do
		table.insert(parts, stat .. ":" .. trimNum(weights[stat] or 0))
	end
	return "OPW1:" .. class .. ":" .. spec .. ":*" .. table.concat(parts, "|")
end

--- Returns true, or false and why not. Weights for another spec of your
--- class switch you to it; another class's are refused. They become your
--- changes to the set scored with now, those the same as its defaults left
--- out.
function IS:Import(text)
	text = string.gsub(text or "", "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	local _, _, class, spec, rest = string.find(text, "^OPW1:([%w_]+):([%w_]+):%*(.*)$")
	if not class then return false, "Not a weights string (OPW1:CLASS:SPEC:*...)." end
	if class ~= self:Class() then return false, "Those weights are for a " .. class .. "." end
	if not (Data.weights[class] and Data.weights[class][spec]) then
		return false, "There is no " .. spec .. " spec for your class."
	end
	local custom = {}
	local defaults = self:Defaults(class, spec)
	for chunk in string.gfind(rest, "[^|]+") do
		local _, _, stat, v = string.find(chunk, "^([^:]+):(%-?[%d%.]+)$")
		if not stat or not tonumber(v) then return false, "Could not read \"" .. chunk .. "\"." end
		if math.abs(tonumber(v) - (defaults[stat] or 0)) >= 0.00005 then custom[stat] = tonumber(v) end
	end
	local s = settings()
	s.spec = spec
	s.custom[self:CustomKey(class, spec)] = next(custom) and custom or nil
	self:Changed()
	return true
end

--[[ Reading an item ]]

local cache = {}

--- A link's item string with its enchant and unique id cleared: the item
--- as it drops, random suffix and all.
function IS:BaseItem(link)
	if not link then return nil end
	local _, _, id, _, suffix = string.find(link, "item:(%d+):(%-?%d+):(%-?%d+):(%-?%d+)")
	if not id then
		_, _, id = string.find(link, "item:(%d+)")
		suffix = "0"
	end
	if not id then return nil end
	return "item:" .. id .. ":0:" .. suffix .. ":0"
end

local scanTip
--- The tooltip's lines for an item string: { left, right, leftRed, rightRed }.
--- Tests replace this; everything else goes through it.
function IS:ReadLines(item)
	if not scanTip then
		scanTip = CreateFrame("GameTooltip", "AegisPathfinderScanTip", nil, "GameTooltipTemplate")
	end
	scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
	scanTip:ClearLines()
	scanTip:SetHyperlink(item)
	local lines = {}
	for i = 1, scanTip:NumLines() do
		local l = getglobal("AegisPathfinderScanTipTextLeft" .. i)
		local r = getglobal("AegisPathfinderScanTipTextRight" .. i)
		local function red(fs)
			if not fs or not fs:IsShown() then return false end
			local cr, cg, cb = fs:GetTextColor()
			return cr and cr > 0.9 and cg < 0.2 and cb < 0.2
		end
		table.insert(lines, {
			left = l and l:GetText(), right = r and r:IsShown() and r:GetText(),
			leftRed = red(l), rightRed = red(r),
		})
	end
	scanTip:Hide()
	return lines
end

local function numberNear(line, upper, pattern)
	local s, e = string.find(upper, pattern)
	if not s then return nil end
	-- After the stat's name, not inside it: "MANA PER 5" has a 5 of its own,
	-- and "Restores 12 mana per 5 sec." was read as 5.
	local _, _, after = string.find(string.sub(line, e + 1), "([%+%-]?%d+%.?%d*)")
	if after then return tonumber(after) end
	local last
	for n in string.gfind(string.sub(line, 1, s - 1), "([%+%-]?%d+%.?%d*)") do last = n end
	return last and tonumber(last)
end

local function isSetBonus(upper)
	return string.find(upper, "%)%s*SET%s*:") or string.find(upper, "^SET%s*:") or string.find(upper, "SET BONUS")
end

local SPELL_SCHOOL = { "NATURE DAMAGE", "FIRE DAMAGE", "FROST DAMAGE", "SHADOW DAMAGE", "ARCANE DAMAGE", "HOLY DAMAGE" }

-- A general stat is not counted again on a line one of its own kind already
-- counted: "critical strike with spells" is spell crit, not melee crit too;
-- "mana per 5 sec." is regen, not a mana pool as well.
local NARROWER = {
	CRIT = { "SPELL CRIT", "HOLY CRIT", "RANGED CRIT", "RESILIENCE" },
	MANA = { "MANA PER 5", "CASTING REGEN" },
	HEALTH = { "HEALTH PER 5" },
}

--- The stats on one line of a tooltip, added into `totals`. The rules are
--- OctoPawn's: the first pattern for a stat wins, a set bonus counts for
--- nothing, and a school's spell damage is not also general spell damage.
--- Some are stricter: a "chance on hit" line's numbers are the proc's -- 90
--- Fire damage on a sword is not 90 spell damage for you -- so only an
--- extra-attack chance counts from one; a general stat is not counted again
--- where a narrower one was (NARROWER); and "damage and healing" heals as
--- much as it says, so it is healing as well as spell power -- a healer's
--- SPELL POWER weight is for its damage side.
local function readStats(line, totals, state)
	local upper = string.upper(line)
	if isSetBonus(upper) then return end
	if string.find(upper, "DAMAGE PER SECOND") or string.find(upper, "DPS") then state.pastDPS = true end
	-- Above the DPS line, "damage" is the weapon's hit range, not a stat.
	if not (state.pastDPS or not string.find(upper, "DAMAGE") or string.find(upper, "PER SECOND")
		or string.find(upper, "SPELLS")) then
		return
	end
	for _, word in ipairs({ "REQUIRES", "SOULBOUND", "UNIQUE", "LEVEL", "BIND", "MADE BY", "DURABILITY" }) do
		if string.find(upper, word) then return end
	end
	local procLine = string.find(upper, "CHANCE ON HIT") ~= nil
	local matched = {}
	for _, p in ipairs(Data.patterns) do
		local pattern, stat = p[1], p[2]
		if not matched[stat] and string.find(upper, pattern) then
			local skip = false
			for _, narrow in ipairs(NARROWER[stat] or {}) do
				if matched[narrow] then skip = true end
			end
			if skip then
				-- counted already, as its narrower kind
			elseif procLine and stat ~= "EXTRA ATTACK" then
				skip = true
			elseif stat == "HIT" and string.find(upper, "SPELL") then
				skip = true
			elseif stat == "SPELL DAMAGE" or stat == "SPELL POWER" then
				for _, school in ipairs(SPELL_SCHOOL) do
					if matched[school] then skip = true end
				end
			elseif stat == "ATTACK POWER" then
				skip = matched["FERAL ATTACK POWER"] or matched["RANGED ATTACK POWER"] or matched["ATTACK POWER UNDEAD"]
					or string.find(upper, "FERAL") or string.find(upper, "IN CAT") or string.find(upper, "IN BEAR")
					or string.find(upper, "MOONKIN") or string.find(upper, "UNDEAD")
			end
			if not skip then
				local n = numberNear(line, upper, pattern)
				if stat == "EXTRA ATTACK" or (not n and stat == "LIFESTEAL") then
					local _, _, pct = string.find(line, "([%+%-]?%d+%.?%d*)%s*%%")
					if pct then n = tonumber(pct) end
				end
				if n then
					matched[stat] = true
					totals[stat] = (totals[stat] or 0) + n
					if stat == "SPELL POWER" and string.find(upper, "HEALING") and not matched["HEALING"] then
						matched["HEALING"] = true
						totals["HEALING"] = (totals["HEALING"] or 0) + n
					end
				end
			end
		end
	end
end

--- What an item is: its stats, where it goes, and whether you can use it
--- (now, later, or never). Cached by item string.
function IS:Read(link)
	local item = self:BaseItem(link)
	if not item then return nil end
	if cache[item] then return cache[item] end
	-- An item the client has not seen is never put in a tooltip: on 1.12 that
	-- asks the server for it, and some servers disconnect you for asking.
	local name, _, _, _, _, _, _, equipLoc = GetItemInfo(item)
	if not name then return nil end
	local info = { item = item, equipLoc = equipLoc, stats = {}, usable = true }
	local state = {}
	for i, l in ipairs(self:ReadLines(item)) do
		if l.left then
			if l.left == "Binds when equipped" then info.boe = true end
			local _, _, level = string.find(l.left, "^Requires Level (%d+)")
			if level then
				info.level = tonumber(level)
				if l.leftRed then info.later = true end
			elseif l.leftRed and not string.find(l.left, "^Durability") and i > 1 then
				info.usable = false
			end
			if i > 1 then readStats(l.left, info.stats, state) end
		end
		if l.rightRed and l.right then info.usable = false end
	end
	if RANGED_WEAPON[equipLoc] and info.stats.DPS then
		info.stats["RANGED DPS"], info.stats.DPS = info.stats.DPS, nil
	end
	cache[item] = info
	return info
end

--- The score of a set of stats with a set of weights, soft caps applied.
function IS:ScoreStats(stats, weights)
	local total = 0
	for stat, value in pairs(stats) do
		local w = weights[stat] or 0
		if w ~= 0 then
			local cap = Data.softcaps[stat]
			local v = value
			if cap and v > cap.cap then v = cap.cap + (v - cap.cap) * cap.after end
			total = total + v * w
		end
	end
	return total
end

function IS:Score(link, weights)
	local info = self:Read(link)
	if not info then return nil end
	return self:ScoreStats(info.stats, weights or self:Weights()), info
end

--[[ Comparing with what you wear ]]

local canDualWield
function IS:CanDualWield()
	if canDualWield == nil then
		canDualWield = false
		local i = 1
		while true do
			local name = GetSpellName(i, "spell")
			if not name then break end
			if name == "Dual Wield" then canDualWield = true; break end
			i = i + 1
		end
	end
	return canDualWield
end

--- The score of what you wear in a slot (0 if nothing), and its info.
function IS:EquippedScore(slot, weights)
	local link = GetInventoryItemLink("player", slot)
	if not link then return 0, nil end
	local score, info = self:Score(link, weights)
	return score or 0, info
end

--- How an item compares with what you wear.
--- Returns { score, equipped, delta, pct, slot, usable, later, emptySlot, noCompare }
--- or nil for something you do not wear.
function IS:Compare(link, weights)
	weights = weights or self:Weights()
	local score, info = self:Score(link, weights)
	if not score or not info.equipLoc or not SLOTS[info.equipLoc] then return nil end
	local out = { score = score, usable = info.usable, later = info.later, level = info.level }

	local loc = info.equipLoc
	local slots = SLOTS[loc]
	if loc == "INVTYPE_WEAPON" and self:CanDualWield() then slots = { MAINHAND, OFFHAND } end

	local mainScore, mainInfo = self:EquippedScore(MAINHAND, weights)
	local twoHanded = mainInfo and mainInfo.equipLoc == "INVTYPE_2HWEAPON"

	if loc == "INVTYPE_2HWEAPON" then
		local offScore = twoHanded and 0 or self:EquippedScore(OFFHAND, weights)
		out.slot, out.equipped = MAINHAND, mainScore + offScore
	elseif twoHanded and (loc == "INVTYPE_WEAPONOFFHAND" or loc == "INVTYPE_SHIELD" or loc == "INVTYPE_HOLDABLE") then
		-- An off-hand is only half of what would replace a two-hander.
		out.slot, out.noCompare = OFFHAND, true
		return out
	else
		-- The slot it would replace: the weakest of those it fits.
		for _, slot in ipairs(slots) do
			local s = self:EquippedScore(slot, weights)
			if not out.slot or s < out.equipped then out.slot, out.equipped = slot, s end
		end
		if twoHanded and out.slot == OFFHAND then out.slot, out.equipped = MAINHAND, mainScore end
	end
	out.emptySlot = not GetInventoryItemLink("player", out.slot)
	out.delta = score - out.equipped
	if out.equipped > 0 then out.pct = out.delta / out.equipped * 100 end
	return out
end

--- An upgrade you can wear now (or, with `later`, once you reach its level).
function IS:IsUpgrade(link, later)
	local c = self:Compare(link)
	if not c or c.noCompare or not c.usable then return false, c end
	if c.later and not later then return false, c end
	return c.delta > 0.0001, c
end

--[[ Your specs, Pawn's way.

	Pawn scores an item for every spec you tell it about, not only the one
	you play, and weighs it against the best item you have worn in that slot
	for that spec -- so the healing set in your bags does not stop a tooltip
	saying a drop is a tank upgrade. The same here. The spec you are scored as
	is always on, and any other spec of your class can be switched on, on the
	Item Score page. Whenever what you wear changes, each spec that is on
	remembers the best it has seen you wear in each slot, and an item is
	weighed against that, or what you wear now if that is better. With
	nothing remembered that is what you wear, as Compare has it.

	Rings and trinkets keep the best two, as you wear two. A two-hander is
	weighed against the best two-hander, or the best main hand and off hand
	together, whichever is more; a one-hander against the best main hand, or
	either hand once you can dual wield. What a spec remembers is weighed
	again with the weights of the day, so changing them does not leave stale
	scores behind. ]]

local GROUP_OF_SLOT = {
	[1] = "HEAD", [2] = "NECK", [3] = "SHOULDER", [5] = "CHEST", [6] = "WAIST", [7] = "LEGS",
	[8] = "FEET", [9] = "WRIST", [10] = "HAND", [11] = "FINGER", [12] = "FINGER", [13] = "TRINKET",
	[14] = "TRINKET", [15] = "BACK", [16] = "MAINHAND", [17] = "OFFHAND", [18] = "RANGED",
}
IS.GROUP_OF_SLOT = GROUP_OF_SLOT
IS.REMEMBER = 4        -- items kept a group, so a change of weights can reorder them

--- The group a worn item counts in: its slot's, and a two-hander apart.
local function wornGroup(slot, info)
	if slot == MAINHAND and info.equipLoc == "INVTYPE_2HWEAPON" then return "TWOHAND" end
	return GROUP_OF_SLOT[slot]
end

--- The specs scored: yours first, then those switched on, in order.
function IS:ActiveSpecs()
	local class, main = self:Class(), self:Spec()
	local out = { main }
	local have = Data.weights[class] or {}
	for _, spec in ipairs(self:Specs(class)) do
		if spec ~= main and have[spec] and settings().active[spec] then table.insert(out, spec) end
	end
	return out
end

function IS:IsSpecActive(spec)
	return spec == self:Spec() or settings().active[spec] == true
end

function IS:SetSpecActive(spec, on)
	settings().active[spec] = on and true or nil
	if on then self:RecordWorn({ spec }) end
	self:Changed()
end

local function remember(spec, group, item, score)
	local best = settings().best
	best[spec] = best[spec] or {}
	local pool = best[spec][group] or {}
	local known = false
	for _, e in ipairs(pool) do
		if e.item == item then e.score, known = score, true end
	end
	if not known then table.insert(pool, { item = item, score = score }) end
	table.sort(pool, function(a, b) return a.score > b.score end)
	while table.getn(pool) > IS.REMEMBER do table.remove(pool) end
	best[spec][group] = pool
end

--- Remember what you wear, for each spec that is on (or those given).
function IS:RecordWorn(specs)
	specs = specs or self:ActiveSpecs()
	local class = self:Class()
	for _, spec in ipairs(specs) do
		local weights = self:Weights(class, spec)
		for slot in pairs(GROUP_OF_SLOT) do
			local link = GetInventoryItemLink("player", slot)
			if link then
				local score, info = self:Score(link, weights)
				if score then remember(spec, wornGroup(slot, info), info.item, score) end
			end
		end
	end
end

--- Start remembering afresh, from what you wear now.
function IS:ForgetBest()
	settings().best = {}
	self:RecordWorn()
	self:Changed()
end

--- A group's scores for a spec, best first: what it remembers and what you
--- wear, each item once, weighed with `weights`.
function IS:BestScores(spec, group, weights)
	local seen, out = {}, {}
	local function add(item, fallback)
		if not item or seen[item] then return end
		seen[item] = true
		table.insert(out, self:Score(item, weights) or fallback or 0)
	end
	for _, e in ipairs((settings().best[spec] or {})[group] or {}) do add(e.item, e.score) end
	for slot in pairs(GROUP_OF_SLOT) do
		local link = GetInventoryItemLink("player", slot)
		local info = link and self:Read(link)
		if info and wornGroup(slot, info) == group then add(info.item) end
	end
	table.sort(out, function(a, b) return a > b end)
	return out
end

--- How an item compares, for a spec (yours if none), with the best you have
--- had for it: Compare's answer, `equipped` being that best.
function IS:CompareBest(link, spec)
	local class = self:Class()
	spec = spec or self:Spec()
	local weights = self:Weights(class, spec)
	local score, info = self:Score(link, weights)
	if not score or not info.equipLoc or not SLOTS[info.equipLoc] then return nil end
	local out = { score = score, usable = info.usable, later = info.later, level = info.level, spec = spec }
	local function top(group, n) return self:BestScores(spec, group, weights)[n or 1] end

	local loc, base = info.equipLoc, nil
	if loc == "INVTYPE_FINGER" or loc == "INVTYPE_TRINKET" then
		base = top(loc == "INVTYPE_FINGER" and "FINGER" or "TRINKET", 2)
	elseif loc == "INVTYPE_2HWEAPON" then
		local two, main, off = top("TWOHAND"), top("MAINHAND"), top("OFFHAND")
		if two or main or off then base = math.max(two or 0, (main or 0) + (off or 0)) end
	elseif loc == "INVTYPE_WEAPONOFFHAND" or loc == "INVTYPE_SHIELD" or loc == "INVTYPE_HOLDABLE" then
		base = top("OFFHAND")
		if not base and top("TWOHAND") and not top("MAINHAND") then
			-- An off hand is only half of what would replace a two-hander.
			out.noCompare = true
			return out
		end
	elseif GROUP_OF_SLOT[SLOTS[loc][1]] == "MAINHAND" then
		base = top("MAINHAND") or top("TWOHAND")
		if loc == "INVTYPE_WEAPON" and self:CanDualWield() then
			local off = top("OFFHAND")
			if off and (not base or off < base) then base = off end
		end
	else
		base = top(GROUP_OF_SLOT[SLOTS[loc][1]])
	end
	out.emptySlot = base == nil
	out.equipped = base or 0
	out.delta = score - out.equipped
	if out.equipped > 0 then out.pct = out.delta / out.equipped * 100 end
	return out
end

--- The specs, other than yours, an item beats your best for, now:
--- { { spec, compare }, ... }.
function IS:SpecUpgrades(link)
	local out, main = {}, self:Spec()
	for _, spec in ipairs(self:ActiveSpecs()) do
		if spec ~= main then
			local c = self:CompareBest(link, spec)
			if c and c.usable and not c.later and not c.noCompare and c.delta > 0.0001 then
				table.insert(out, { spec = spec, compare = c })
			end
		end
	end
	return out
end

--[[ Keeping it current ]]

local listeners = {}
function IS:OnChange(fn) table.insert(listeners, fn) end

--- Weights or spec changed: every score is stale, the stats are not.
function IS:Changed()
	for _, fn in ipairs(listeners) do fn() end
end

--- What the client says about items changed (a level, a new weapon skill).
function IS:Forget()
	cache = {}
	canDualWield = nil
	self:Changed()
end

--[[ Tooltips ]]

--- One spec's line under an item: its score, and against the best you have
--- had for that spec.
local function specLine(c)
	local left = "Pathfinder (" .. IS:SpecLabel(c.spec) .. ")"
	local right = string.format("%.1f", c.score)
	local color = "|cffd0d0d0"
	if not c.usable then
		right, color = "not for you", "|cff9d9d9d"
	elseif c.noCompare then
		right = right .. " (with a two-hander)"
	elseif c.emptySlot then
		right, color = right .. "  empty slot", "|cff40ff40"
	elseif c.pct then
		local sign = c.pct >= 0 and "+" or ""
		color = c.pct > 0.05 and "|cff40ff40" or (c.pct < -0.05 and "|cffff5050" or color)
		right = right .. string.format("  %s%.0f%%", sign, c.pct)
		if c.later then right = right .. " at " .. c.level end
	end
	return left, color .. right .. "|r"
end

--- The lines added under an item, one for each spec that is on, yours
--- first: { { left, right }, ... }, or nil.
function IS:TooltipLines(link)
	if not settings().tooltips then return nil end
	local lines = {}
	for _, spec in ipairs(self:ActiveSpecs()) do
		local ok, c = pcall(function() return self:CompareBest(link, spec) end)
		if ok and c then
			local left, right = specLine(c)
			table.insert(lines, { left, right })
		end
	end
	return table.getn(lines) > 0 and lines or nil
end

--- Your spec's line alone.
function IS:TooltipText(link)
	local lines = self:TooltipLines(link)
	if lines then return lines[1][1], lines[1][2] end
end

local function addLine(tip, link)
	if not link then return end
	local lines = IS:TooltipLines(link)
	if not lines then return end
	for _, l in ipairs(lines) do tip:AddDoubleLine(l[1], l[2], 0.62, 0.84, 0.43, 1, 1, 1) end
	tip:Show()
end

-- Each way the client fills a tooltip with an item, and how to get its link.
local SETTERS = {
	SetBagItem = function(bag, slot) return GetContainerItemLink(bag, slot) end,
	SetInventoryItem = function(unit, slot) return GetInventoryItemLink(unit, slot) end,
	SetLootItem = function(slot) return GetLootSlotLink(slot) end,
	SetQuestItem = function(kind, index) return GetQuestItemLink(kind, index) end,
	SetQuestLogItem = function(kind, index) return GetQuestLogItemLink(kind, index) end,
	SetMerchantItem = function(index) return GetMerchantItemLink(index) end,
	SetAuctionItem = function(kind, index) return GetAuctionItemLink(kind, index) end,
	SetTradePlayerItem = function(index) return GetTradePlayerItemLink(index) end,
	SetTradeTargetItem = function(index) return GetTradeTargetItemLink(index) end,
	SetHyperlink = function(link) return link end,
}

function IS:HookTooltip(tip)
	if not tip or tip.__aegisScored then return end
	tip.__aegisScored = true
	for method, getLink in pairs(SETTERS) do
		local original, find = tip[method], getLink
		if original then
			tip[method] = function(self, a1, a2, a3)
				local r1, r2, r3 = original(self, a1, a2, a3)
				local okLink, link = pcall(find, a1, a2, a3)
				if okLink and link and string.find(link, "item:") then addLine(self, link) end
				return r1, r2, r3
			end
		end
	end
end

--[[ Events ]]

--[[ Registered as the file loads, so they can come before the addon has its
	saved settings: your gear arriving at login is UNIT_INVENTORY_CHANGED, and
	recording it reached for settings that were not there yet ("attempt to
	index field 'db'"). Until then they are let go; Initialize records what
	you wear once the settings are there. ]]
local events = CreateFrame("Frame")
IS.events = events
events:RegisterEvent("PLAYER_LEVEL_UP")
events:RegisterEvent("SKILL_LINES_CHANGED")
events:RegisterEvent("SPELLS_CHANGED")
events:RegisterEvent("CHARACTER_POINTS_CHANGED")
events:RegisterEvent("UNIT_INVENTORY_CHANGED")
events:SetScript("OnEvent", function()
	if not AegisPathfinder.db then return end
	if event == "UNIT_INVENTORY_CHANGED" then
		if arg1 == "player" then IS:RecordWorn() end
	elseif event == "CHARACTER_POINTS_CHANGED" then
		IS:Changed()
	else
		-- At 60 the weights change set; the level says when.
		if event == "PLAYER_LEVEL_UP" then levelSeen = tonumber(arg1) end
		IS:Forget()
	end
end)

function IS:Initialize()
	if self:MigrateWeights() then
		AegisPathfinder:Print("Item score: new stat weights for every spec, for leveling and for 60. "
			.. "Your own changes to the old ones were cleared; change them again on the Item Score page (/apg gear).")
	end
	self:HookTooltip(GameTooltip)
	self:HookTooltip(ItemRefTooltip)
	self:RecordWorn()
end
