--[[
	Tests for ItemScore.lua: reading an item's tooltip, weighing it for your
	spec, and comparing it with what you wear.

	The tooltips are the real 1.12 wording, fed in line by line where the
	client would fill a hidden tooltip.

	Run:  lua5.1 Tools/tests/test_itemscore.lua
]]

package.path = "Tools/tests/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

AegisPathfinder = { db = { char = {}, profile = {} } }
function AegisPathfinder:Print() end

-- The character: a Paladin, with talents, spells and gear set per test.
local talents = { { "Holy", 0 }, { "Protection", 0 }, { "Retribution", 0 } }
GetTalentTabInfo = function(tab) return talents[tab][1], "icon", talents[tab][2] end
UnitClass = function() return "Paladin", "PALADIN" end
local spells = {}
GetSpellName = function(i) return spells[i] end
local worn = {}
GetInventoryItemLink = function(unit, slot)
	return worn[slot] and ("|cff1eff00|Hitem:" .. worn[slot] .. ":0:0:0|h[x]|h|r")
end

-- Items: id -> { equipLoc, tooltip lines }. A line is text, or
-- { text, right, redLeft, redRight }.
local ITEMS = {}
GetItemInfo = function(item)
	local _, _, id = string.find(item, "item:(%d+)")
	local def = ITEMS[tonumber(id)]
	if not def then return nil end
	return "Item " .. id, item, 2, 20, "Armor", "Mail", 1, def.loc, "icon"
end

dofile("ItemScoreData.lua")
dofile("ItemScore.lua")
local IS = AegisPathfinder.ItemScore

function IS:ReadLines(item)
	local _, _, id = string.find(item, "item:(%d+)")
	local out = {}
	for _, l in ipairs(ITEMS[tonumber(id)].lines) do
		if type(l) == "string" then l = { l } end
		table.insert(out, { left = l[1], right = l[2], leftRed = l[3], rightRed = l[4] })
	end
	return out
end

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end
local function near(a, b) return a and math.abs(a - b) < 0.001 end

-- Reading a tooltip -----------------------------------------------------------

ITEMS[1] = { loc = "INVTYPE_CHEST", lines = {
	"Scaled Leather Chestpiece", "Soulbound", { "Chest", "Mail" }, "182 Armor",
	"+10 Strength", "+5 Stamina",
	"Equip: Improves your chance to get a critical strike by 1%.",
	"Durability 85 / 85", "Requires Level 30",
} }
local info = IS:Read("item:1:0:0:0")
check(info.stats.STRENGTH == 10 and info.stats.STAMINA == 5, "primary stats read")
check(info.stats.ARMOR == 182, "armor read, got %s", tostring(info.stats.ARMOR))
check(info.stats.CRIT == 1, "an equip line's crit read, got %s", tostring(info.stats.CRIT))
check(info.level == 30 and info.usable and not info.later, "a white Requires Level is usable now")
check(info.stats.HEALTH == nil and info.stats.MANA == nil, "no stray stats from other lines")

ITEMS[2] = { loc = "INVTYPE_WEAPONMAINHAND", lines = {
	"Fiery Blade", { "Main Hand", "Sword" }, { "7 - 14 Damage", "Speed 2.00" }, "(5.3 damage per second)",
	"+3 Agility",
	"Chance on hit: Blasts a target for 90 Fire damage.",
	"Equip: Increases damage done by Fire spells and effects by up to 10.",
} }
info = IS:Read("item:2:0:0:0")
check(near(info.stats.DPS, 5.3), "weapon DPS read, got %s", tostring(info.stats.DPS))
check(info.stats.FIRE == nil and info.stats["FIRE DAMAGE"] == 10,
	"a school's spell damage read from its equip line, not the proc's 90 (got %s)", tostring(info.stats["FIRE DAMAGE"]))
check(info.stats["SPELL DAMAGE"] == nil, "and not also counted as general spell damage")

ITEMS[3] = { loc = "INVTYPE_HEAD", lines = {
	"Robe Hood", "Equip: Increases damage and healing done by magical spells and effects by up to 12.",
	"Set: Increases your chance to hit by 1%.", "Improved Set Bonus (2) Set: +10 Stamina",
} }
info = IS:Read("item:3:0:0:0")
check(info.stats["SPELL POWER"] == 12, "spell power read, got %s", tostring(info.stats["SPELL POWER"]))
check(info.stats.HIT == nil and info.stats.STAMINA == nil, "a set bonus counts for nothing")
-- It heals as much as it says: healing too, where a healer's weight is.
check(info.stats.HEALING == 12, "damage and healing is healing as well, got %s", tostring(info.stats.HEALING))

-- A narrower stat is not counted again as its general one, and the number is
-- the line's, not the stat's name's ("mana per 5" has a 5 of its own).
ITEMS[901] = { loc = "INVTYPE_FINGER", lines = { "Ring", "Finger",
	"Equip: Improves your chance to get a critical strike with spells by 1%.",
	"Equip: Restores 12 mana per 5 sec.",
	"Equip: Restores 4 health per 5 sec.",
} }
info = IS:Read("item:901:0:0:0")
check(info.stats["SPELL CRIT"] == 1 and info.stats.CRIT == nil, "spell crit is not melee crit too, got %s",
	tostring(info.stats.CRIT))
check(info.stats["MANA PER 5"] == 12, "twelve mana per 5 is twelve, got %s", tostring(info.stats["MANA PER 5"]))
check(info.stats.MANA == nil, "and not a mana pool as well, got %s", tostring(info.stats.MANA))
check(info.stats["HEALTH PER 5"] == 4 and info.stats.HEALTH == nil, "four health per 5 is four, got %s",
	tostring(info.stats["HEALTH PER 5"]))
ITEMS[902] = { loc = "INVTYPE_RANGED", lines = { "Bow", { "Ranged", "Bow" },
	"Equip: Improves your chance to get a critical strike with ranged weapons by 1%." } }
info = IS:Read("item:902:0:0:0")
check(info.stats["RANGED CRIT"] == 1 and info.stats.CRIT == nil, "ranged crit is not melee crit too")

-- A bow's, a wand's or a thrown weapon's DPS is ranged weapon DPS, not a
-- melee weapon's: a hunter's bow is worth far more than its sword.
ITEMS[903] = { loc = "INVTYPE_RANGED", lines = { "Hunting Bow", { "Ranged", "Bow" },
	{ "12 - 23 Damage", "Speed 2.70" }, "(6.5 damage per second)", "+3 Agility" } }
ITEMS[904] = { loc = "INVTYPE_RANGEDRIGHT", lines = { "Wand", { "Ranged", "Wand" },
	{ "13 - 25 Shadow Damage", "Speed 1.50" }, "(12.7 damage per second)" } }
ITEMS[905] = { loc = "INVTYPE_THROWN", lines = { "Knives", { "Thrown", "Thrown" },
	{ "5 - 10 Damage", "Speed 2.00" }, "(3.8 damage per second)" } }
for id, dps in pairs({ [903] = 6.5, [904] = 12.7, [905] = 3.8 }) do
	info = IS:Read("item:" .. id .. ":0:0:0")
	check(near(info.stats["RANGED DPS"], dps) and info.stats.DPS == nil, "item %d: %s ranged DPS, no melee DPS (got %s, %s)",
		id, dps, tostring(info.stats["RANGED DPS"]), tostring(info.stats.DPS))
end
check(IS:Read("item:903:0:0:0").stats.AGILITY == 3, "a bow's other stats still read")
check(near(IS:Read("item:2:0:0:0").stats.DPS, 5.3) and IS:Read("item:2:0:0:0").stats["RANGED DPS"] == nil,
	"a sword's DPS stays melee DPS")

-- Weapon skills are not part of the score.
ITEMS[8] = { loc = "INVTYPE_HAND", lines = { "Edgemaster's Handguards", "Hands", "Equip: Increased Axes +7.",
	"Equip: Increased Daggers +7.", "Equip: Increased Swords +7." } }
check(next(IS:Read("item:8:0:0:0").stats) == nil, "a weapon skill line adds nothing")
for _, stat in ipairs(AegisPathfinder.ItemScoreData.stats) do
	check(stat ~= "SWORDS" and stat ~= "DAGGERS", "no weapon skill among the weights (%s)", stat)
end

-- What you cannot use.
ITEMS[4] = { loc = "INVTYPE_HEAD", lines = { "Plate Helm", { "Head", "Plate", false, true }, "+20 Strength" } }
check(IS:Read("item:4:0:0:0").usable == false, "a red armour type means you cannot wear it")
ITEMS[5] = { loc = "INVTYPE_HEAD", lines = { "Cloth Hood", "Head", { "Classes: Mage", nil, true }, "+5 Intellect" } }
check(IS:Read("item:5:0:0:0").usable == false, "a red class line means it is not for you")
ITEMS[6] = { loc = "INVTYPE_HEAD", lines = { "Helm", "Head", "+9 Strength", { "Requires Level 40", nil, true } } }
info = IS:Read("item:6:0:0:0")
check(info.usable and info.later and info.level == 40, "a red Requires Level means later, not never")
ITEMS[7] = { loc = "INVTYPE_HEAD", lines = { "Helm", "Head", "+9 Strength", { "Durability 0 / 50", nil, true } } }
check(IS:Read("item:7:0:0:0").usable, "a broken item is still yours to wear")

-- The enchant is not the item's: the same item string, whatever is on it.
check(IS:BaseItem("|cff1eff00|Hitem:1:1887:0:777|h[x]|h|r") == "item:1:0:0:0", "enchant and unique id cleared")
check(IS:BaseItem("item:1:0:-12:0") == "item:1:0:-12:0", "a random suffix kept")

-- Weighing ----------------------------------------------------------------------

check(near(IS:ScoreStats({ HIT = 8 }, { HIT = 2 }), (6 + 2 * 0.35) * 2), "past the hit soft cap, points count less")
check(near(IS:ScoreStats({ STRENGTH = 10, SPIRIT = 3 }, { STRENGTH = 1.5 }), 15), "an unweighted stat counts 0")

-- Your spec ------------------------------------------------------------------------

check(IS:Spec() == "Retribution", "no talents: the levelling spec, got %s", tostring(IS:Spec()))
talents[1][2], talents[3][2] = 11, 5
local spec, why = IS:Spec()
check(spec == "Holy" and why == "talents", "the tree with most points, got %s (%s)", tostring(spec), tostring(why))
IS:SetSpec("Protection")
check(IS:Spec() == "Protection", "a spec you pick wins over the talents")
IS:SetSpec(nil)
check(IS:Spec() == "Holy", "and Auto goes back to them")
check(IS:SpecLabel("FeralCat") == "Feral (cat)" and IS:SpecLabel("Holy") == "Holy", "spec names for people")

-- Your weights -----------------------------------------------------------------------

local changed = 0
IS:OnChange(function() changed = changed + 1 end)
local default = IS:Weights().STRENGTH
IS:SetWeight("STRENGTH", 9)
check(IS:Weights().STRENGTH == 9 and IS:IsCustom(), "a weight you set is used, and marks the spec custom")
check(changed > 0, "and tells whoever listens")
IS:SetWeight("STRENGTH", default)
check(not IS:IsCustom(), "setting it back to the default is no change at all")
IS:SetWeight("STRENGTH", 9)
IS:ResetWeights()
check(IS:Weights().STRENGTH == default and not IS:IsCustom(), "reset goes back to the defaults")

-- Sharing, in OctoPawn's string: every stat, so the scale arrives whole
-- wherever its defaults differ (OctoPawn's, or this addon's other set).
IS:SetWeight("STRENGTH", 2.5)
IS:SetWeight("SPELL POWER", 0)
local text = IS:Export()
local Data = AegisPathfinder.ItemScoreData
local parts = 0
for _ in string.gfind(text, "[^|*]+:[%d%.%-]+") do parts = parts + 1 end
check(string.find(text, "^OPW1:PALADIN:Holy:%*") and parts == table.getn(Data.stats),
	"export writes every stat (%d of %d): %s", parts, table.getn(Data.stats), string.sub(text, 1, 60))
check(string.find(text, "|STRENGTH:2.5", 1, true) and string.find(text, "|SPELL POWER:0|", 1, true)
	and string.find(text, "|HEALING:1|", 1, true), "with your changes and the defaults")
IS:ResetWeights()
local ok = IS:Import("  " .. text .. "  ")
check(ok and IS:Weights().STRENGTH == 2.5 and IS:Weights()["SPELL POWER"] == 0, "import puts them back")
local kept = 0
for _ in pairs(IS.Settings().custom[IS:CustomKey()] or {}) do kept = kept + 1 end
check(kept == 2, "and keeps as changes only what differs from the defaults, got %d", kept)
ok = IS:Import("OPW1:PALADIN:Holy:*STRENGTH:3")
check(ok and IS:Weights().STRENGTH == 3 and IS:Weights().HEALING == 1, "OctoPawn's short string: those stats, over the defaults")
ok = IS:Import("OPW1:PALADIN:Retribution:*")
check(ok and IS:Spec() == "Retribution" and not IS:IsCustom(), "an empty import picks the spec, with its defaults")
local bad, why2 = IS:Import("OPW1:MAGE:Frost:*")
check(not bad and string.find(why2, "MAGE"), "another class's weights are refused")
bad, why2 = IS:Import("OPW1:PALADIN:Holy:*STRENGTH:lots")
check(not bad and string.find(why2, "lots"), "a value that is not a number is refused")
check(not IS:Import("hello"), "and so is anything else")
IS:SetSpec(nil)
talents[1][2], talents[3][2] = 0, 11

-- Leveling and 60 ------------------------------------------------------------------

--[[ Two sets of defaults: leveling's below 60, 60's at it. The tanks have
	one, used throughout. A change is kept for the set it was made in. ]]
do
	local level = 1
	UnitLevel = function() return level end
	local lev, set = IS:Defaults("PALADIN", "Retribution")
	check(set == "leveling" and lev == Data.leveling.PALADIN.Retribution, "below 60, the leveling set")
	level = 59
	check(select(2, IS:Defaults("PALADIN", "Retribution")) == "leveling", "still at 59")
	level = 60
	local max
	max, set = IS:Defaults("PALADIN", "Retribution")
	check(set == "max" and max == Data.weights.PALADIN.Retribution, "at 60, the 60 set")
	level = 12
	max, set = IS:Defaults("PALADIN", "Protection")
	check(set == "max" and max == Data.weights.PALADIN.Protection, "a tank uses the tank set at 12 too")
	check(Data.leveling.PALADIN.Protection == nil and Data.leveling.WARRIOR.Protection == nil
		and Data.leveling.DRUID.FeralBear == nil and Data.leveling.SHAMAN.EnhancementTank == nil,
		"no tank has a leveling set")
	local known = {}
	for _, stat in ipairs(Data.stats) do known[stat] = true end
	for class, specs in pairs(Data.weights) do
		for spec, w in pairs(specs) do
			local tank = spec == "Protection" or spec == "FeralBear" or spec == "EnhancementTank"
			check(tank or Data.leveling[class][spec], "%s %s has a leveling set", class, spec)
			local unknown = {}
			for _, set in ipairs({ w, (Data.leveling[class] or {})[spec] or {} }) do
				for stat in pairs(set) do if not known[stat] then table.insert(unknown, stat) end end
			end
			check(table.getn(unknown) == 0, "%s %s weighs only stats it knows: %s", class, spec, table.concat(unknown, ", "))
		end
	end
	-- The weights players reported: a leveling Affliction warlock's Stamina.
	local aff = Data.leveling.WARLOCK.Affliction
	check(aff.STAMINA >= 0.8 and aff.STAMINA > aff.INTELLECT, "leveling Affliction weighs Stamina (%s) over Intellect (%s)",
		tostring(aff.STAMINA), tostring(aff.INTELLECT))
	check(Data.weights.WARLOCK.Affliction.STAMINA < aff.STAMINA, "and less at 60")
	for _, spec in ipairs({ "BeastMastery", "Marksmanship", "Survival" }) do
		local w = Data.weights.HUNTER[spec]
		check(w["RANGED DPS"] > 5 * w.DPS, "a hunter's bow DPS is worth far more than a melee weapon's (%s)", spec)
	end
	check(Data.leveling.MAGE.Frost["RANGED DPS"] > Data.leveling.MAGE.Frost.DPS, "a leveling mage's wand counts")

	-- A change made while leveling stays with the leveling set.
	level = 30
	IS:SetSpec("Retribution")
	IS:ResetWeights()
	IS:SetWeight("STAMINA", 4)
	check(IS:Weights().STAMINA == 4 and IS:IsCustom(), "a change while leveling")
	level = 60
	check(IS:Weights().STAMINA == Data.weights.PALADIN.Retribution.STAMINA and not IS:IsCustom(),
		"is not carried into the 60 set")
	IS:SetWeight("STAMINA", 0.5)
	level = 30
	check(IS:Weights().STAMINA == 4, "and the 60 set's change does not touch leveling's")
	IS:ResetWeights()
	check(not IS:IsCustom(), "Reset weights clears the set scored with")
	level = 60
	check(IS:IsCustom(), "and only that one")
	IS:ResetWeights()

	-- The level-up event comes before UnitLevel says the new level.
	level = 59
	local onEvent = IS.events:GetScript("OnEvent")
	event, arg1 = "PLAYER_LEVEL_UP", 60
	onEvent()
	check(IS:Level() == 60 and select(2, IS:Defaults()) == "max", "PLAYER_LEVEL_UP's 60 switches to the 60 set at once")
	event, arg1 = nil, nil
	level = 60
	IS:SetSpec(nil)
	UnitLevel = function() return 1 end
end

-- The old defaults' changes are cleared once, with a word in chat.
do
	local s = IS.Settings()
	s.custom = { ["PALADIN:Holy"] = { STRENGTH = 3 } }
	s.weightsVersion = nil
	local said
	local print = AegisPathfinder.Print
	function AegisPathfinder:Print(msg) said = msg end
	IS:Initialize()
	check(next(s.custom) == nil and s.weightsVersion == IS.WEIGHTS_VERSION, "old changes cleared")
	check(said and string.find(said, "new stat weights") and string.find(said, "cleared"), "and said so: %s", tostring(said))
	said = nil
	s.custom = { ["PALADIN:Holy"] = { STRENGTH = 3 } }
	IS:Initialize()
	check(s.custom["PALADIN:Holy"].STRENGTH == 3 and said == nil, "once only")
	s.custom, s.weightsVersion = {}, nil
	IS:Initialize()
	check(said == nil and s.weightsVersion == IS.WEIGHTS_VERSION, "nothing to clear, nothing said")
	AegisPathfinder.Print = print
	s.custom = {}
end

-- Comparing with what you wear --------------------------------------------------------

local function item(id, loc, str)
	ITEMS[id] = { loc = loc, lines = { "Item " .. id, "+" .. str .. " Strength" } }
end
local W = { STRENGTH = 1 }

item(10, "INVTYPE_HEAD", 10); item(11, "INVTYPE_HEAD", 12)
worn[1] = 10
local c = IS:Compare("item:11:0:0:0", W)
check(c.slot == 1 and near(c.delta, 2) and near(c.pct, 20), "a better helm: +20%%, got %s", tostring(c.pct))
worn[1] = nil
c = IS:Compare("item:11:0:0:0", W)
check(c.emptySlot and c.pct == nil, "nothing worn: an empty slot, no percentage")

-- Rings go against the weaker of the two.
item(20, "INVTYPE_FINGER", 8); item(21, "INVTYPE_FINGER", 3); item(22, "INVTYPE_FINGER", 5)
worn[11], worn[12] = 20, 21
c = IS:Compare("item:22:0:0:0", W)
check(c.slot == 12 and near(c.delta, 2), "a ring replaces the weaker ring")

-- Two-handers against both hands; an off-hand with a two-hander on is not comparable.
item(30, "INVTYPE_WEAPONMAINHAND", 6); item(31, "INVTYPE_SHIELD", 4); item(32, "INVTYPE_2HWEAPON", 9)
worn[16], worn[17] = 30, 31
c = IS:Compare("item:32:0:0:0", W)
check(near(c.equipped, 10) and near(c.delta, -1), "a two-hander is weighed against both hands")
worn[16], worn[17] = 32, nil
c = IS:Compare("item:31:0:0:0", W)
check(c.noCompare, "a shield with a two-hander on has nothing to compare with")
c = IS:Compare("item:30:0:0:0", W)
check(c.slot == 16 and near(c.equipped, 9), "a one-hander replaces the two-hander")

-- One-handers go in either hand once you can dual wield.
item(40, "INVTYPE_WEAPON", 7); item(41, "INVTYPE_WEAPON", 2); item(42, "INVTYPE_WEAPON", 5)
worn[16], worn[17] = 40, 41
c = IS:Compare("item:42:0:0:0", W)
check(c.slot == 16, "without Dual Wield a one-hander is for the main hand")
spells = { "Attack", "Dual Wield" }
IS:Forget()
c = IS:Compare("item:42:0:0:0", W)
check(c.slot == 17 and near(c.delta, 3), "with Dual Wield it replaces the weaker hand")

-- Upgrades.
worn[1] = 10
check(IS:IsUpgrade("item:11:0:0:0") ~= nil, "IsUpgrade answers")
ITEMS[12] = { loc = "INVTYPE_HEAD", lines = { "Helm", "Head", "+40 Strength", { "Requires Level 50", nil, true } } }
check(not IS:IsUpgrade("item:12:0:0:0"), "an item for later is not an upgrade now")
check(IS:IsUpgrade("item:12:0:0:0", true), "but is one for later")
ITEMS[13] = { loc = "INVTYPE_HEAD", lines = { "Helm", { "Head", "Plate", false, true }, "+40 Strength" } }
check(not IS:IsUpgrade("item:13:0:0:0", true), "an item you cannot wear is never an upgrade")
check(IS:Compare("item:99:0:0:0") == nil, "an item the client has not seen is not read at all")

-- The tooltip line ---------------------------------------------------------------------

worn[1] = 10
local left, right = IS:TooltipText("item:11:0:0:0")
check(left == "Pathfinder (Retribution)", "the line names the spec, got %s", tostring(left))
check(string.find(right, "%+20%%") and string.find(right, "|cff40ff40"), "an upgrade shows green +20%%, got %s", tostring(right))
left, right = IS:TooltipText("item:13:0:0:0")
check(string.find(right, "not for you"), "an item you cannot wear says so")
IS.Settings().tooltips = false
check(IS:TooltipText("item:11:0:0:0") == nil, "switched off, no line")
IS.Settings().tooltips = true

-- Tooltips get the line from every way the client fills them.
local added = {}
local tip = { AddDoubleLine = function(self, l, r) table.insert(added, l) end, Show = function() end }
function tip:SetBagItem() return "orig" end
GetContainerItemLink = function() return "|Hitem:11:0:0:0|h[x]|h" end
IS:HookTooltip(tip)
check(tip:SetBagItem(0, 1) == "orig", "the client's own call still happens")
check(added[1] == "Pathfinder (Retribution)", "and the score line is added")
IS:HookTooltip(tip)
tip:SetBagItem(0, 1)
check(table.getn(added) == 2, "hooking twice adds the line once")

-- More than one spec, and the best you have worn for each (Pawn's way) --------------

--[[ A Retribution paladin who tanks now and then: Protection is switched on
	too. Each spec remembers the best it has seen worn in each slot, and an
	item is weighed against that, so the tank helm in the bank still sets the
	bar for Protection while the Retribution helm is on. ]]
do
	worn = {}
	talents[1][2], talents[2][2], talents[3][2] = 0, 0, 11
	local ret, prot = IS:Weights("PALADIN", "Retribution"), IS:Weights("PALADIN", "Protection")
	check(IS:Spec() == "Retribution", "scored as Retribution")
	check(table.concat(IS:ActiveSpecs(), ",") == "Retribution", "only your spec to begin with")

	ITEMS[60] = { loc = "INVTYPE_HEAD", lines = { "Tank Helm", "Head", "+20 Stamina", "+4 Strength" } }
	ITEMS[61] = { loc = "INVTYPE_HEAD", lines = { "Ret Helm", "Head", "+14 Strength", "+3 Stamina" } }
	ITEMS[62] = { loc = "INVTYPE_HEAD", lines = { "Better Tank Helm", "Head", "+24 Stamina", "+4 Strength" } }
	local function sc(id, w) return IS:Score("item:" .. id .. ":0:0:0", w) end
	check(sc(60, prot) > sc(61, prot) and sc(61, ret) > sc(60, ret), "the tank helm is Protection's, the other Retribution's")

	IS:SetSpecActive("Protection", true)
	check(table.concat(IS:ActiveSpecs(), ",") == "Retribution,Protection", "Protection is scored too, after yours")
	check(IS:IsSpecActive("Protection") and IS:IsSpecActive("Retribution") and not IS:IsSpecActive("Holy"),
		"and says so")

	worn[1] = 60; IS:RecordWorn()           -- tanking
	worn[1] = 61; IS:RecordWorn()           -- back to Retribution
	local c = IS:CompareBest("item:62:0:0:0", "Protection")
	check(near(c.equipped, sc(60, prot)), "a tank helm is weighed against the best tank helm you have worn, not the one on (%s, not %s)",
		tostring(c.equipped), tostring(sc(61, prot)))
	check(c.delta > 0 and near(c.pct, (sc(62, prot) - sc(60, prot)) / sc(60, prot) * 100), "and is a small upgrade")
	c = IS:CompareBest("item:62:0:0:0", "Retribution")
	check(near(c.equipped, sc(61, ret)), "for Retribution the bar is the Retribution helm")

	local lines = IS:TooltipLines("item:62:0:0:0")
	check(lines and table.getn(lines) == 2 and lines[1][1] == "Pathfinder (Retribution)" and lines[2][1] == "Pathfinder (Protection)",
		"the tooltip has a line for each spec, yours first")
	check(string.find(lines[2][2], "|cff40ff40", 1, true), "Protection's in green, an upgrade: %s", tostring(lines[2][2]))

	local ups = IS:SpecUpgrades("item:62:0:0:0")
	check(table.getn(ups) == 1 and ups[1].spec == "Protection", "it is an upgrade for Protection alone, the drop notice says")
	check(table.getn(IS:SpecUpgrades("item:61:0:0:0")) == 0, "the helm you wear is nobody's upgrade")

	-- Rings keep the best two.
	for id, str in pairs({ [70] = 20, [71] = 15, [72] = 10, [73] = 12 }) do
		ITEMS[id] = { loc = "INVTYPE_FINGER", lines = { "Ring " .. id, "+" .. str .. " Strength" } }
	end
	worn[11], worn[12] = 70, 71; IS:RecordWorn()
	worn[11], worn[12] = 72, nil; IS:RecordWorn()
	c = IS:CompareBest("item:73:0:0:0", "Retribution")
	check(near(c.equipped, sc(71, ret)), "a ring is weighed against the second best you have worn (%s)", tostring(c.equipped))
	check(c.delta < 0, "so a 12 is not an upgrade over a 20 and a 15")

	-- A two-hander against the best two-hander, or both hands together.
	ITEMS[80] = { loc = "INVTYPE_WEAPONMAINHAND", lines = { "Mace", { "Main Hand", "Mace" }, "+10 Strength" } }
	ITEMS[81] = { loc = "INVTYPE_SHIELD", lines = { "Shield", "Off Hand", "+6 Strength" } }
	ITEMS[82] = { loc = "INVTYPE_2HWEAPON", lines = { "Greatsword", "Two-Hand", "+14 Strength" } }
	worn[16], worn[17] = 80, 81; IS:RecordWorn()
	worn[16], worn[17] = 82, nil; IS:RecordWorn()
	c = IS:CompareBest("item:82:0:0:0", "Retribution")
	check(near(c.equipped, sc(80, ret) + sc(81, ret)), "a two-hander against the best main hand and off hand together (%s)", tostring(c.equipped))
	check(not IS:CompareBest("item:81:0:0:0", "Retribution").noCompare, "an off hand you have had has something to compare with")

	-- Forgetting starts again from what you wear.
	IS:ForgetBest()
	worn[1] = 61
	c = IS:CompareBest("item:62:0:0:0", "Protection")
	check(near(c.equipped, sc(61, prot)), "forgotten, the bar is the helm you wear")

	-- An empty slot, never filled.
	ITEMS[90] = { loc = "INVTYPE_CLOAK", lines = { "Cloak", "Back", "+5 Stamina" } }
	check(IS:CompareBest("item:90:0:0:0", "Protection").emptySlot, "a slot never filled is empty")

	IS:SetSpecActive("Protection", false)
	check(table.concat(IS:ActiveSpecs(), ",") == "Retribution", "switched off, only your spec")
	check(table.getn(IS:TooltipLines("item:62:0:0:0")) == 1, "and one tooltip line")
end

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end
print(string.format("ItemScore: %d checks", checks))
if table.getn(failures) == 0 then
	print("All item score checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
