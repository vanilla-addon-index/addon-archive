--[[
	Tests for the Gear Finder (GearFinder.lua, GearFinderTab.lua): which
	dungeons it looks in, which of their drops it weighs, loading the ones the
	client has not seen, the upgrades by slot, the cells and the picks, the
	suggested dungeon, the tab on the character panel, and naming upgrades on
	walking in -- through the real item score, on a small made-up GearData.

	Run:  lua5.1 Tools/tests/test_gearfinder.lua
]]

package.path = "Tools/tests/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

UISpecialFrames = {}
local now = 100
GetTime = function() return now end
local printed = {}
AegisPathfinder = { db = { char = {}, profile = {} } }
function AegisPathfinder:Print(msg) table.insert(printed, msg) end
function AegisPathfinder.FormatCopper(c) return c .. "c" end

local level, faction = 20, "Alliance"
UnitLevel = function() return level end
UnitFactionGroup = function() return faction end
UnitClass = function() return "Warrior", "WARRIOR" end
GetTalentTabInfo = function(tab) return "Arms", "icon", tab == 1 and 11 or 0 end
GetSpellName = function() return nil end
GetItemQualityColor = function() return 1, 1, 1, "|cff0070dd" end
GameTooltip.SetHyperlink = function(self, l) self.__link = l end
GameTooltip.Hide = function() end

-- Items the client has; the rest it is asked for.
local ITEMS, asked = {}, {}
C_Item = { RequestLoadItemDataByID = function(id) table.insert(asked, id) end }
local function item(id, loc, str, quality, level)
	ITEMS[id] = { loc = loc, quality = quality, level = level,
		lines = { "Item " .. id, "+" .. str .. " Strength" } }
end
GetItemInfo = function(it)
	local _, _, id = string.find(it, "item:(%d+)")
	local def = ITEMS[tonumber(id)]
	if not def then return nil end
	return "Item " .. id, it, def.quality or 3, def.level or 20, "Armor", "Plate", 1, def.loc, "icon"
end
local worn = {}
GetInventoryItemLink = function(unit, slot)
	return worn[slot] and ("|Hitem:" .. worn[slot] .. ":0:0:0|h[x]|h")
end

--[[ The client's character panel, as far as the tab touches it: the panel,
	its five tabs (Pet hidden, as for a class without a pet), its pages, and
	the functions that swap them -- ToggleCharacter and the PanelTemplates,
	as FrameXML 1.12.1 has them. ]]
CharacterFrame = CreateFrame("Frame", "CharacterFrame", UIParent)
CharacterFrame:SetWidth(384); CharacterFrame:SetHeight(512)
CharacterFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104)
CharacterFrame:Hide()
CHARACTERFRAME_SUBFRAMES = { "PaperDollFrame", "PetPaperDollFrame", "SkillFrame", "ReputationFrame", "HonorFrame" }
for i, name in ipairs(CHARACTERFRAME_SUBFRAMES) do
	local sub = CreateFrame("Frame", name, CharacterFrame)
	sub:SetID(({ PaperDollFrame = 1, PetPaperDollFrame = 2, ReputationFrame = 3, SkillFrame = 4, HonorFrame = 5 })[name])
	sub:Hide()
end
for i = 1, 5 do
	local t = CreateFrame("Button", "CharacterFrameTab" .. i, CharacterFrame)
	t:SetID(i)
	t:SetWidth(80); t:SetHeight(32)
	if i == 1 then
		t:SetPoint("CENTER", CharacterFrame, "BOTTOMLEFT", 60, 62)
	else
		t:SetPoint("LEFT", getglobal("CharacterFrameTab" .. (i - 1)), "RIGHT", -16, 0)
	end
end
CharacterFrameTab2:Hide()
CharacterFrameTab3:SetPoint("LEFT", CharacterFrameTab1, "RIGHT", -16, 0)
CreateFrame("Button", "CharacterFrameCloseButton", CharacterFrame)
function PanelTemplates_SetNumTabs(frame, n) frame.numTabs = n end
function PanelTemplates_SetTab(frame, id) frame.selectedTab = id end
function PlaySound() end
local toggled = {}
function ShowUIPanel(f) f:Show() end
function HideUIPanel(f) f:Hide() end
function ToggleCharacter(tab)
	table.insert(toggled, tab)
	local sub = getglobal(tab)
	PanelTemplates_SetTab(CharacterFrame, sub:GetID())
	if CharacterFrame:IsVisible() and sub:IsVisible() then return HideUIPanel(CharacterFrame) end
	ShowUIPanel(CharacterFrame)
	for _, name in ipairs(CHARACTERFRAME_SUBFRAMES) do
		local f = getglobal(name)
		if name == tab then
			f:Show()
			local h = f:GetScript("OnShow")
			if h then local old = this; this = f; h(); this = old end
		elseif f:IsShown() then
			f:Hide()
			local h = f:GetScript("OnHide")
			if h then local old = this; this = f; h(); this = old end
		end
	end
end
GetInventorySlotInfo = function(name) return 1, "Interface\\PaperDoll\\UI-PaperDoll-Slot-" .. name end

dofile("Theme.lua")
dofile("ItemScoreData.lua")
dofile("ItemScore.lua")
dofile("GearData.lua")
dofile("GearAdvisor.lua")
dofile("GuidePictures.lua")
dofile("GearFinder.lua")
dofile("GearFinderTab.lua")
local A, IS, GF = AegisPathfinder, AegisPathfinder.ItemScore, AegisPathfinder.GearFinder
function IS:ReadLines(it)
	local _, _, id = string.find(it, "item:(%d+)")
	local out = {}
	for _, l in ipairs(ITEMS[tonumber(id)].lines) do table.insert(out, { left = l }) end
	return out
end

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end
--[[ Before the addon has its settings. The item score, the Gear Advisor and
	the Gear finder register their events as their files load, so some come
	before OnInitialize: your gear arriving at login, zoning in. The item
	score's reached for the settings and stopped with "attempt to index field
	'db' (a nil value)". They wait now. ]]
do
	local saved = A.db
	A.db = nil
	local function fire(f, ev, a1, script)
		local oldThis, oldEvent, oldArg = this, event, arg1
		this, event, arg1 = f, ev, a1
		local ok, err = pcall(f:GetScript(script or "OnEvent"))
		this, event, arg1 = oldThis, oldEvent, oldArg
		return ok, err
	end
	for _, case in ipairs({
		{ IS.events, "UNIT_INVENTORY_CHANGED", "player" },
		{ IS.events, "SPELLS_CHANGED" },
		{ IS.events, "CHARACTER_POINTS_CHANGED" },
		{ GF.events, "ZONE_CHANGED_NEW_AREA" },
		{ A.GearAdvisor.events, "UNIT_INVENTORY_CHANGED", "player" },
	}) do
		local ok, err = fire(case[1], case[2], case[3])
		check(ok, "%s before the settings are there: nothing happens, got %s", case[2], tostring(err))
	end
	A.GearAdvisor.events.dirty = -100             -- a scan long overdue
	local ok, err = fire(A.GearAdvisor.events, nil, nil, "OnUpdate")
	check(ok, "and the Gear Advisor's scan waits too, got %s", tostring(err))
	A.GearAdvisor.events.dirty = nil
	A.db = saved
end

local function run(f, script)
	local h = f:GetScript(script)
	assert(h, "no " .. script .. " script")
	local old = this
	this = f
	h()
	this = old
end

-- The real data is there and in the shape the finder reads.
local real = AegisPathfinder.GearData
check(table.getn(real.dungeons) >= 20, "the dungeons and raids are in GearData")
local dm
for _, d in ipairs(real.dungeons) do if d.code == "DM" then dm = d end end
check(dm and dm.lo == 18 and table.getn(dm.loot) > 10, "the Deadmines, with its loot")
local vanCleef
for _, drop in ipairs(dm.loot) do
	if drop[2] == "Edwin VanCleef" and real.items[drop[1]] then vanCleef = drop end
end
check(vanCleef and real.items[vanCleef[1]][1], "VanCleef's drops, with their slot")
-- Bosses a script summons are on no map; the data names them.
local sources = {}
for _, d in ipairs(real.dungeons) do
	for _, drop in ipairs(d.loot) do sources[drop[2] .. " @ " .. d.code] = true end
end
check(sources["Ragnaros @ MC"] and sources["Nefarian @ BWL"] and sources["Darkmaster Gandling @ SCHOLO"],
	"summoned bosses' loot is there, in their instances")
-- Quest, reputation and crafted gear.
check(real.crafted[12640] and real.crafted[12640][1] == "Blacksmithing" and real.crafted[12640][2] == 300
	and real.crafted[12640][3] == false, "Lionheart Helm: Blacksmithing 300, anyone's to wear")
check(real.crafted[15063] and real.crafted[15063][1] == "Leatherworking", "Devilsaur Gauntlets: Leatherworking")
check(real.quests[8041] and real.quests[8041][5] == 270 and real.quests[8041][6] == 4
	and real.factions[270][1] == "Zandalar Tribe", "a Zandalar quest, at Friendly")
check(real.repgear[19083] and real.factions[real.repgear[19083][1]][2] == "Horde", "Frostwolf gear, for the Horde")
local rewards = 0
for _ in pairs(real.quests) do rewards = rewards + 1 end
check(rewards > 500, "hundreds of quests whose rewards are gear, got %d", rewards)
for _, table_ in ipairs({ real.repgear, real.crafted }) do
	for id in pairs(table_) do
		check(real.items[id], "item %d has its slot and level", id)
		break
	end
end

-- Turtle WoW's own dungeons, from pfQuest-turtle.
local turtle = {}
for _, d in ipairs(real.dungeons) do if d.turtle then turtle[d.name] = d end end
local cg = turtle["Crescent Grove"]
check(cg and cg.kind == "dungeon" and cg.lo >= 30 and cg.hi <= 40 and cg.lo <= cg.hi,
	"Crescent Grove, at the levels its creatures are, got %s-%s", tostring(cg and cg.lo), tostring(cg and cg.hi))
check(sources["Grovetender Engryss @ CG"] and sources["High Priestess A'lathea @ CG"], "with its bosses' drops")
local unknown = 0
for _, drop in ipairs(cg.loot) do if not real.items[drop[1]] then unknown = unknown + 1 end end
check(unknown > 0, "Turtle's own items, which the client describes, not the data")
for _, name in ipairs({ "Dragonmaw Retreat", "Stormwrought Ruins", "Gilneas City", "Hateforge Quarry",
	"Karazhan Crypt", "The Black Morass", "Stormwind Vault" }) do
	check(turtle[name] and turtle[name].kind == "dungeon" and table.getn(turtle[name].loot) > 10,
		"%s is there, with its loot", name)
end
-- Newer than the pfQuest-turtle the rest is read from: InstanceJournal's.
local whc, fh = turtle["Windhorn Canyon"], turtle["Frostmane Hollow"]
check(whc and whc.kind == "dungeon" and whc.lo == 26 and whc.hi == 30, "Windhorn Canyon, 1.18.1's, at 26-30")
check(sources["Chieftain Shalk Blackwind @ WHC"] and sources["Prophet Stormhoof @ WHC"], "with each boss's own drops")
local chance = 0
for _, drop in ipairs(whc and whc.loot or {}) do if drop[2] == "Pathun Duskhide" then chance = math.max(chance, drop[3]) end end
check(chance == 25, "at InstanceJournal's chances, not the scrape's placeholder, got %s", tostring(chance))
check(fh and fh.kind == "dungeon" and fh.lo == 13 and fh.hi == 20, "Frostmane Hollow, in Dun Morogh, at 13-20")
check(turtle["Emerald Sanctum"] and turtle["Emerald Sanctum"].kind == "raid"
	and turtle["Tower of Karazhan"] and turtle["Tower of Karazhan"].kind == "raid", "and Turtle's raids, as raids")
for name, d in pairs(turtle) do
	check(d.hi <= 60, "%s's levels are ones a player can be, got %s", name, tostring(d.hi))
end
-- Turtle's changes to the vanilla instances, over the CMaNGOS loot.
local function dropsIn(code)
	for _, d in ipairs(real.dungeons) do
		if d.code == code then
			local out = {}
			for _, drop in ipairs(d.loot) do out[drop[1]] = drop end
			return out
		end
	end
end
local mc, dmLoot = dropsIn("MC"), dropsIn("DM")
check(mc[16812] and mc[16812][2] == "Incindis", "Molten Core as Turtle has it: Gloves of Prophecy from Incindis, got %s",
	tostring(mc[16812] and mc[16812][2]))
check(not mc[16799], "and not what Turtle took out: Arcanist Bindings off the core hounds")
local basalthar = false
for _, drop in pairs(mc) do if drop[2] == "Basalthar" then basalthar = true end end
check(basalthar, "and a boss Turtle added there")
check(dmLoot[81005] and dmLoot[81005][2] == "Edwin VanCleef" and not real.items[81005],
	"VanCleef's Spiked Defias Spaulders, one of Turtle's own, which the client describes")
check(dmLoot[5196] or dmLoot[5193] or dmLoot[5202], "and the Deadmines' own drops are still there")

-- A small world to look in.
AegisPathfinder.GearData = {
	sell = {},
	dungeons = {
		{ code = "DM", name = "The Deadmines", lo = 18, hi = 25, kind = "dungeon", loot = {
			{ 101, "Edwin VanCleef", 20 }, { 102, "Cookie", 65 }, { 103, "Mr. Smite", 40 },
			{ 104, "Gilnid", 30 }, { 105, "Captain Greenskin", 30 },
		} },
		{ code = "WC", name = "Wailing Caverns", lo = 18, hi = 25, kind = "dungeon", loot = {
			{ 111, "Mutanus", 25 }, { 112, "Lady Anacondra", 20 }, { 113, "Lord Pythas", 20 },
			{ 114, "Lord Cobrahn", 20 }, { 115, "Lord Serpentis", 20 },
		} },
		{ code = "RFC", name = "Ragefire Chasm", lo = 13, hi = 18, kind = "dungeon", faction = "Horde", loot = {
			{ 121, "Taragaman", 30 },
		} },
		{ code = "SFK", name = "Shadowfang Keep", lo = 23, hi = 29, kind = "dungeon", loot = {
			{ 131, "Arugal", 30 },
		} },
		{ code = "ZG", name = "Zul'Gurub", lo = 60, hi = 60, kind = "raid", loot = {
			{ 141, "Hakkar", 10 },
		} },
		-- One of Turtle's own: its items have no entry below.
		{ code = "CG", name = "Crescent Grove", lo = 18, hi = 25, kind = "dungeon", turtle = true, loot = {
			{ 201, "Grovetender", 25 }, { 202, "Elder", 100 }, { 203, "Warden", 30 },
			{ 204, "Keeper", 20 }, { 205, "Raxxieth", 25 },
		} },
	},
	items = {
		[101] = { "INVTYPE_CHEST", 3, 20, 0 }, [102] = { "INVTYPE_HEAD", 2, 19, 0 },
		[103] = { "INVTYPE_2HWEAPON", 3, 20, 0 }, [104] = { "INVTYPE_HEAD", 2, 19, 0 },
		[105] = { "INVTYPE_HEAD", 2, 30, 0 },       -- too high for now
		[111] = { "INVTYPE_HEAD", 2, 18, 0 }, [112] = { "INVTYPE_HEAD", 2, 18, 0 },
		[113] = { "INVTYPE_HEAD", 2, 18, 128 },     -- mages only
		[114] = { "INVTYPE_WRIST", 2, 18, 0 },       -- not loaded yet
		[115] = { "INVTYPE_HEAD", 2, 18, 0 },
		[121] = { "INVTYPE_HEAD", 3, 16, 0 }, [131] = { "INVTYPE_HEAD", 3, 23, 0 },
		[141] = { "INVTYPE_HEAD", 4, 60, 0 },
	},
}
item(101, "INVTYPE_CHEST", 12); item(102, "INVTYPE_HEAD", 8); item(103, "INVTYPE_2HWEAPON", 20)
item(104, "INVTYPE_HEAD", 11); item(105, "INVTYPE_HEAD", 30); item(111, "INVTYPE_HEAD", 9)
item(112, "INVTYPE_HEAD", 14); item(113, "INVTYPE_HEAD", 40); item(121, "INVTYPE_HEAD", 50)
item(131, "INVTYPE_HEAD", 13); item(141, "INVTYPE_HEAD", 99); item(115, "INVTYPE_HEAD", 12)
item(900, "INVTYPE_HEAD", 10)
item(201, "INVTYPE_FEET", 7)                -- Turtle's own boots
item(202, "", 99)                           -- a badge: not gear
item(203, "INVTYPE_FEET", 50, 0)            -- grey
item(205, "INVTYPE_FEET", 60, 3, 30)        -- too high for now; 204 not loaded yet
worn[1] = 900
A.db.char.Dungeons = { DM = true, WC = true, SFK = true }
-- Quests, reputation and crafting come later; drops alone until then.
GF.Settings().quests, GF.Settings().reputation, GF.Settings().crafted = false, false, false

-- Where it looks ------------------------------------------------------------------

local function codes()
	local out = {}
	for _, d in ipairs(GF:Dungeons()) do out[d.code] = true end
	return out
end
local c = codes()
check(c.DM and c.WC, "the dungeons at your level")
check(not c.RFC, "not the other side's")
check(c.SFK, "one starting a few levels above you")
check(not c.ZG, "no raids until you ask")
-- The Dungeons page's ticks are which dungeons' quests the route takes in,
-- and the setup unticks most for the route; they hid those dungeons' gear.
A.db.char.Dungeons.WC = false
check(codes().WC, "a dungeon unticked on the Dungeons page still: those ticks are the route's")
A.db.char.Dungeons.WC = true
GF.Settings().raids = true
check(not codes().ZG, "a raid only at its level, even when asked")
GF.Settings().raids = false
-- The options' two upgrade sources: dungeons, and raids.
GF.Settings().dungeons = false
check(table.getn(GF:Dungeons()) == 0, "with Dungeons unticked under the sources, no dungeons")
level = 60
GF.Settings().raids = true
c = codes()
check(c.ZG and not c.DM, "and with Raids ticked, the raids alone, got DM %s", tostring(c.DM))
level = 20
GF.Settings().raids, GF.Settings().dungeons = false, true
check(GF.ForClass(128, "MAGE") and not GF.ForClass(128, "WARRIOR") and GF.ForClass(0, "WARRIOR"),
	"class masks read")
A.db.char.SelfFound = true
check(table.getn(GF:Dungeons()) == 0, "Solo Self-Found runs no dungeons, so none are looked in")
A.db.char.SelfFound = nil
check(codes().DM, "and off again, they are")

-- What it finds -----------------------------------------------------------------------

local weighed = {}
local compare = IS.Compare
function IS:Compare(it, w)
	local _, _, id = string.find(it, "item:(%d+)")
	weighed[tonumber(id)] = true
	return compare(self, it, w)
end
local results, missing = GF:Find()
check(not weighed[202] and not weighed[203], "a badge or a grey item is never even weighed")
local slots = {}
for _, g in ipairs(results) do slots[g.slot] = g.entries end
check(slots.Head and slots.Head[1].id == 112, "the best head first (+14 over +10), got %s",
	tostring(slots.Head and slots.Head[1].id))
check(table.getn(slots.Head) == 4, "every upgrade for the slot, for its list: four, got %d",
	slots.Head and table.getn(slots.Head) or 0)
check(slots.Head[2].id == 131 and slots.Head[3].id == 115 and slots.Head[4].id == 104,
	"best first: +14, +13, +12, +11, got %s", tostring(slots.Head[4].id))
for _, e in ipairs(slots.Head) do
	check(e.id ~= 102, "not one that is worse than what you wear")
	check(e.id ~= 105, "not one too far above your level")
	check(e.id ~= 113, "not one for another class")
end
check(slots.Chest and slots.Chest[1].compare.emptySlot, "a slot you have nothing in")
check(slots["Main hand"] and slots["Main hand"][1].id == 103 and slots["Main hand"][1].source == "Mr. Smite",
	"a two-hander under the main hand it replaces, with who drops it")
check(missing == 2 and not slots.Wrist, "items not loaded yet are counted, not guessed at")
check(slots.Feet and slots.Feet[1].id == 201 and slots.Feet[1].dungeon == "Crescent Grove"
	and slots.Feet[1].source == "Grovetender", "a Turtle dungeon's own item, described by the client")
check(table.getn(slots.Feet) == 1, "not its badge, its grey, or one above your level (%d listed)", table.getn(slots.Feet))
check(slots.Feet[1].level == 20, "at the level the client gives it")
check(results[1].slot == "Head", "slots in the character sheet's order, got %s", results[1].slot)

-- Loading what the client has not seen.
check(GF:Pending() == 2, "they are queued to load")
now = now + 1
run(GF.events, "OnUpdate")
check(asked[1] == 114 and asked[2] == 204, "and asked for the safe way, Turtle's own too")
item(114, "INVTYPE_WRIST", 4)
item(204, "INVTYPE_FINGER", 5)
results, missing = GF:Find()
check(missing == 0, "once they have come, nothing is missing")
slots = {}
for _, g in ipairs(results) do slots[g.slot] = g.entries end
check(slots.Finger and slots.Finger[1].id == 204, "and the Turtle item that came is weighed")

-- Quests, reputation and crafting ------------------------------------------------------

local data = AegisPathfinder.GearData
data.factions = { [529] = { "Argent Dawn", "" }, [730] = { "Stormpike Guard", "Alliance" },
	[729] = { "Frostwolf Clan", "Horde" } }
data.quests = {
	[301] = { "The Hard Way", 18, "", 0, 0, 0, { 311 } },          -- a waist for anyone
	[302] = { "For the Horde", 18, "Horde", 0, 0, 0, { 312 } },    -- the other side's
	[303] = { "Mage Business", 18, "", 128, 0, 0, { 313 } },       -- mages only
	[304] = { "Later On", 30, "", 0, 0, 0, { 314 } },               -- not yet
	[305] = { "Done Already", 15, "", 0, 0, 0, { 315 } },          -- handed in
	[306] = { "Old Hat", 5, "", 0, 0, 0, { 316 } },                 -- long outgrown
	[307] = { "Dawn Duty", 18, "", 0, 529, 5, { 317 } },           -- needs Honored
}
data.repgear = { [321] = { 730, 6, "Quartermaster Rhon" }, [322] = { 729, 6, "Jotek" } }
data.crafted = { [331] = { "Blacksmithing", 150, false }, [332] = { "Leatherworking", 140, true },
	[333] = { "Tailoring", 145, true } }
local function meta(id, loc, lvl) data.items[id] = { loc, 3, lvl or 20, 0 } end
meta(311, "INVTYPE_WAIST"); meta(312, "INVTYPE_WAIST"); meta(313, "INVTYPE_WAIST"); meta(314, "INVTYPE_WAIST", 30)
meta(315, "INVTYPE_WAIST"); meta(316, "INVTYPE_WAIST", 8); meta(317, "INVTYPE_LEGS")
meta(321, "INVTYPE_SHOULDER"); meta(322, "INVTYPE_SHOULDER")
meta(331, "INVTYPE_HAND"); meta(332, "INVTYPE_FEET"); meta(333, "INVTYPE_CLOAK")
for _, id in ipairs({ 311, 312, 313, 314, 315, 316 }) do item(id, "INVTYPE_WAIST", 5 + id - 310) end
item(317, "INVTYPE_LEGS", 6); item(321, "INVTYPE_SHOULDER", 6); item(322, "INVTYPE_SHOULDER", 9)
item(331, "INVTYPE_HAND", 6); item(332, "INVTYPE_FEET", 50); item(333, "INVTYPE_CLOAK", 6)
A.db.char.completedquestsbyid = { [305] = true }
local skills = { { "Professions", 1 }, { "Tailoring", nil, nil, 150 } }
GetNumSkillLines = function() return table.getn(skills) end
GetSkillLineInfo = function(i) local l = skills[i]; return l[1], l[2], l[3], l[4] end
GF.Settings().quests, GF.Settings().reputation, GF.Settings().crafted = true, true, true
local function found()
	local out = {}
	for _, g in ipairs((GF:Find())) do
		for _, e in ipairs(g.entries) do out[e.id] = e end
	end
	return out
end
local f = found()
check(f[311] and f[311].where == "Quest: The Hard Way", "a quest reward, and the quest, got %s", tostring(f[311] and f[311].where))
check(not f[312], "not the other side's quest")
check(not f[313], "not a quest for another class")
check(not f[314], "not a quest you cannot take yet")
check(not f[315], "not a quest you have handed in")
check(not f[316], "nor gear you have long outgrown")
check(f[317] and f[317].where == "Quest: Dawn Duty (Honored, Argent Dawn)", "a quest that needs reputation says so, got %s",
	tostring(f[317] and f[317].where))
check(f[321] and f[321].where == "Revered with Stormpike Guard \194\183 Quartermaster Rhon",
	"gear a vendor sells at a reputation rank, got %s", tostring(f[321] and f[321].where))
check(not f[322], "not the other side's")
check(f[331] and f[331].where == "Blacksmithing 150 \194\183 made by a crafter", "crafted gear anyone can have made, got %s",
	tostring(f[331] and f[331].where))
check(not f[332], "not gear that binds on pickup to a crafter you are not")
check(f[333] and f[333].where == "Tailoring 145", "but yes if you are one, got %s", tostring(f[333] and f[333].where))
-- Most quest rewards need no level: read as level 0, every one was "long
-- outgrown" and none was weighed. Such a reward is as near as its quest.
data.quests[308] = { "Plain Reward", 18, "", 0, 0, 0, { 318 } }
data.quests[309] = { "Long Ago", 6, "", 0, 0, 0, { 319 } }
data.quests[310] = { "Coming Up", 22, "", 0, 0, 0, { 320 } }
for _, id in ipairs({ 318, 319, 320 }) do meta(id, "INVTYPE_WRIST", 0); item(id, "INVTYPE_WRIST", id - 310) end
f = found()
check(f[318] and f[318].level == 18, "a reward that needs no level, weighed at its quest's, got %s",
	tostring(f[318] and f[318].level))
check(f[320] and f[320].level == 22, "a quest a level or two off: at that level, got %s", tostring(f[320] and f[320].level))
check(not f[319], "but not one whose quest you have long outgrown")
data.quests[308], data.quests[309], data.quests[310] = nil, nil, nil
A.db.char.SelfFound = true
f = found()
check(not f[331] and f[333], "Solo Self-Found: only what you make yourself")
check(f[311] and f[321], "and still quests and reputation")
A.db.char.SelfFound = nil
GF.Settings().quests, GF.Settings().reputation, GF.Settings().crafted = false, false, false
f = found()
check(not f[311] and not f[321] and not f[333], "each can be switched off")
GF.Settings().quests, GF.Settings().reputation, GF.Settings().crafted = true, true, true

-- The cells ----------------------------------------------------------------------------

-- Two rings from the Deadmines, better than the Grove's: two cells, two rings.
table.insert(data.dungeons[1].loot, { 106, "Rhahk'Zor", 30 })
table.insert(data.dungeons[1].loot, { 107, "Sneed", 30 })
meta(106, "INVTYPE_FINGER"); meta(107, "INVTYPE_FINGER")
item(106, "INVTYPE_FINGER", 8); item(107, "INVTYPE_FINGER", 6)
GF:Refresh()
local function cellsByKey()
	local out = {}
	for _, cell in ipairs(GF:Cells()) do out[cell.key] = cell end
	return out
end
local cells = cellsByKey()
check(table.getn(GF:Cells()) == 17, "a cell a slot, two each for rings and trinkets, no shirt or tabard, got %d",
	table.getn(GF:Cells()))
check(cells.head.shown and cells.head.shown.id == 112 and not cells.head.picked, "a cell shows the slot's biggest upgrade")
check(table.getn(cells.head.entries) == 4, "and offers them all in its list")
check(cells.neck.shown == nil, "a slot with none shows none")
check(cells.mainhand.shown.id == 103 and cells.offhand.shown == nil, "the two-hander in the main hand, and no off hand")
check(cells.finger1.shown.id == 106 and cells.finger2.shown.id == 107, "two rings, the two biggest, got %s and %s",
	tostring(cells.finger1.shown and cells.finger1.shown.id), tostring(cells.finger2.shown and cells.finger2.shown.id))
local offered = {}
for _, e in ipairs(cells.finger2.entries) do offered[e.id] = true end
check(not offered[106] and offered[107] and offered[204], "never the ring the other cell shows")
check(cells.waist.shown.where == "Quest: The Hard Way" and cells.shoulder.shown.where, "quest and vendor gear have cells too")

-- Picks.
GF:SetPick("finger2", 106)
cells = cellsByKey()
check(cells.finger2.shown.id == 106 and cells.finger2.picked, "picking the other cell's ring takes it")
check(cells.finger1.shown.id == 107 and not cells.finger1.picked, "and the other cell shows the next one")
GF:SetPick("finger2", nil)
GF:SetPick("head", 131)
cells = cellsByKey()
check(cells.head.shown.id == 131 and cells.head.picked, "a pick is what its cell shows")
check(A.db.char.gearfinder.picks.head == 131, "kept with the character's settings")
GF:SetPick("head", 112)
check(A.db.char.gearfinder.picks.head == nil, "picking the biggest again is no pick at all")

-- The suggested dungeon: by how many cells, then by how much.
local function codesOf(ranked)
	local out = {}
	for _, t in ipairs(ranked) do table.insert(out, t.code) end
	return table.concat(out, " ")
end
local ranked = GF:Suggest()
check(codesOf(ranked) == "DM WC CG", "the dungeon with most of the cells' items first, got %s", codesOf(ranked))
check(ranked[1].n == 4 and ranked[1].name == "The Deadmines" and ranked[1].lo == 18 and ranked[1].hi == 25,
	"with how many, its name and levels")
check(table.concat(ranked[1].slots, ", ") == "Chest, Main hand, Finger 1, Finger 2", "and which cells, got %s",
	table.concat(ranked[1].slots, ", "))
GF:SetPick("finger2", 204)
ranked = GF:Suggest()
check(codesOf(ranked) == "DM CG WC", "a pick moves a dungeon up: the Grove now two, ahead of the Caverns on what they add, got %s",
	codesOf(ranked))
GF:SetPick("finger2", nil)
local fake = function(code, name, worth) return { label = code, shown = { code = code, dungeon = name, compare = { pct = worth } } } end
ranked = GF:Suggest({ fake("A", "Alpha", 10), fake("B", "Beta", 50), fake("A", "Alpha", 10), fake("C", "Gamma", 20), fake("B", "Beta", 0) })
check(codesOf(ranked) == "B A C", "count first, then what they add up to, got %s", codesOf(ranked))
ranked = GF:Suggest({ fake("Z", "Zeta", 10), fake("Y", "Eta", 10) })
check(codesOf(ranked) == "Y Z", "then by name, got %s", codesOf(ranked))
check(GF.Worth({ compare = { emptySlot = true, delta = 5 } }) == 100, "an empty slot filled counts as +100%")

-- Picks you no longer need are forgotten.
GF:SetPick("head", 131)
worn[1] = 131
GF:Refresh()
check(A.db.char.gearfinder.picks.head == nil, "once you wear it")
worn[1] = 900
GF:SetPick("head", 104)
worn[1] = 121
GF:Refresh()
check(A.db.char.gearfinder.picks.head == nil, "or it is no longer an upgrade")
worn[1] = 900
GF:SetPick("head", 131)
GF.Settings().dungeons = false
GF:Refresh()
check(A.db.char.gearfinder.picks.head == 131 and not cellsByKey().head.shown,
	"but not because dungeons are unticked under the sources: shown again when they are ticked")
GF.Settings().dungeons = true
GF:Refresh()
check(cellsByKey().head.shown.id == 131, "as it is")
GF:SetPick("head", nil)

-- What the footer says.
local status, nothing = GF:Status()
check(string.find(status, "Looking in The Deadmines, Wailing Caverns, Shadowfang Keep, Crescent Grove", 1, true),
	"where it looked, got %s", status)
GF.Settings().dungeons = false
status = GF:Status()
check(string.find(status, "both unticked under Upgrade sources, so it looks at quests, reputation and crafting only", 1, true),
	"with neither source ticked, it says so, got %s", status)
GF.Settings().quests, GF.Settings().reputation, GF.Settings().crafted = false, false, false
status, nothing = GF:Status()
check(string.find(status, "has nowhere to look", 1, true) and string.find(nothing, "nowhere to look", 1, true),
	"and with nothing else, that it has nowhere to look, got %s", status)
GF.Settings().raids = true
status = GF:Status()
check(status == "There is no raid at your level to look in.", "raids alone, below them: no ticks to blame, got %s", status)
GF.Settings().raids = false
GF.Settings().quests, GF.Settings().reputation, GF.Settings().crafted, GF.Settings().dungeons = true, true, true, true
level = 60
GF.Settings().raids = true
status = GF:Status()
check(string.find(status, "4 dungeons and 1 raid", 1, true) and not string.find(status, "The Deadmines", 1, true),
	"too many to name, so counted, got %s", status)
level = 20
GF.Settings().raids = false
A.db.char.SelfFound = true
status = GF:Status()
check(string.find(status, "Solo Self-Found is on, so it looks in no dungeons.", 1, true) == 1,
	"with Self-Found on it says why there are no dungeons, got %s", status)
A.db.char.SelfFound = nil
GF.Settings().enabled = false
check(GF:Status() == "The Gear Finder is switched off in the options.", "and when it is switched off")
GF.Settings().enabled = true

-- The tab ---------------------------------------------------------------------------------

local tab, page = GF.tab, GF.panel
-- The tab is placed as the file loads, before OnInitialize has made the
-- saved settings.
do
	local saved = A.db
	A.db = nil
	local ok, err = pcall(GF.PlaceTab, GF)
	check(ok and tab:IsShown(), "placing the tab before the settings exist is no error, got %s", tostring(err))
	A.db = saved
end
check(tab and tab:GetName() == "CharacterFrameTab6" and tab:GetID() == 6, "a sixth tab on the character panel")
check(page and page:GetID() == 6 and CHARACTERFRAME_SUBFRAMES[6] == "AegisPathfinderGearFinderPage",
	"and its page, one of the panel's, swapped by the client's own ToggleCharacter")
check(CharacterFrame.numTabs == 6, "which the panel's tab code walks to, got %s", tostring(CharacterFrame.numTabs))
GF:PlaceTab()
check(math.abs(tab:GetLeft() - (CharacterFrameTab5:GetRight() - 16)) < 0.01,
	"after the last tab, overlapping as the client's do, got %s", tostring(tab:GetLeft()))
CharacterFrameTab5:Hide()
GF:PlaceTab()
check(math.abs(tab:GetLeft() - (CharacterFrameTab4:GetRight() - 16)) < 0.01, "after the last one shown, when the last is hidden")
CharacterFrameTab5:Show()
-- pfUI's skin: its own gap, and the tab skinned to match.
local skinned
pfUI = { api = { SkinTab = function(t) skinned = t end } }
CharacterFrameTab5.backdrop = {}
CharacterFrameTab5:ClearAllPoints()
CharacterFrameTab5:SetPoint("LEFT", CharacterFrameTab4, "RIGHT", 3, 0)
GF:PlaceTab()
check(skinned == tab and math.abs(tab:GetLeft() - (CharacterFrameTab5:GetRight() + 3)) < 0.01,
	"with pfUI, skinned like its tabs and spaced like them")
pfUI, CharacterFrameTab5.backdrop = nil, nil
CharacterFrameTab5:ClearAllPoints()
CharacterFrameTab5:SetPoint("LEFT", CharacterFrameTab4, "RIGHT", -16, 0)
GF:PlaceTab()

-- Opening it.
local opened, config = {}, {}
function A:OpenGuideTab(name) table.insert(opened, name) end
function A:ShowConfigPage(name) table.insert(config, name) end
A.guidelist = { "Dungeons/Wailing Caverns (17-24)", "Dungeons/The Deadmines (17-24)" }
run(tab, "OnClick")
check(toggled[table.getn(toggled)] == "AegisPathfinderGearFinderPage" and page:IsShown() and CharacterFrame:IsShown(),
	"the tab opens the character panel on its page")
check(not PaperDollFrame:IsShown(), "in place of the other pages")
check(not CharacterFrameCloseButton:IsShown(), "the panel's own close button hidden, not over the page's header")
local ui = GF.ui
check(ui and ui.cells and table.getn(ui.cells) == 17, "its cells drawn")
local head = ui.cells[1]
check(head.name:GetText() == "Item 112" and head.gain:GetText() == "+40%", "a cell: the item and what it gains, got %s %s",
	tostring(head.name:GetText()), tostring(head.gain:GetText()))
check(head.where:GetText() == "Wailing Caverns \194\183 Lady Anacondra", "and where it drops, got %s",
	tostring(head.where:GetText()))
check(ui.cells[2].name:GetText() == "No upgrade found" and ui.cells[2].where:GetText() == "Neck",
	"a slot with nothing says so")
check(ui.cells[5].gain:GetText() == "Empty slot", "and a slot you wear nothing in, got %s", tostring(ui.cells[5].gain:GetText()))
check(ui.right.name:GetText() == "The Deadmines" and ui.right.count:GetText() == "4 upgrades here",
	"the suggested dungeon, and how many upgrades, got %s", tostring(ui.right.count:GetText()))
check(ui.right.slots:GetText() == "Chest, Main hand, Finger 1, Finger 2", "which cells")
check(ui.right.rank:GetText() == "1 of 3 dungeons with upgrades", "and where it stands, got %s", tostring(ui.right.rank:GetText()))
check(ui.right.pic.kind == "screen", "its loading screen")
check(ui.right.guide:IsShown() and ui.right.guide.guideName == "Dungeons/The Deadmines (17-24)", "and its guide")
run(ui.right.guide, "OnClick")
check(opened[1] == "Dungeons/The Deadmines (17-24)", "which the button opens")
run(ui.right.next, "OnClick")
check(ui.right.name:GetText() == "Wailing Caverns", "the arrows step to the next dungeon, got %s", tostring(ui.right.name:GetText()))
run(ui.right.prev, "OnClick")
run(ui.right.prev, "OnClick")
check(ui.right.name:GetText() == "Crescent Grove", "and round from the first to the last, got %s", tostring(ui.right.name:GetText()))
check(not ui.right.guide:IsShown(), "a dungeon with no guide has no button")
check(string.find(ui.status:GetText(), "Looking in", 1, true), "the footer says where it looked")
-- The cog called ShowConfigPage alone, which does nothing while the options
-- window is not open.
function A:CreateConfigPanel() self.optionsframe = CreateFrame("Frame", nil, UIParent); self.optionsframe:Hide() end
run(ui.cog, "OnClick")
check(config[1] == "Gear" and A.optionsframe and A.optionsframe:IsShown(), "the cog opens the options, at the Gear page")
A.optionsframe:Hide()
-- The page drags the character panel, and has its own close button.
check(page.__dragButton == "LeftButton", "the page is a drag handle")
run(page, "OnDragStart")
check(CharacterFrame.__moving and CharacterFrame.__movable, "dragging it moves the character panel")
run(page, "OnDragStop")
check(not CharacterFrame.__moving, "and lets go")

-- A slot's list.
run(head, "OnClick")
local list = ui.list
check(list:IsShown() and list.title:GetText() == "HEAD" and list.count:GetText() == "4 upgrades", "a cell opens its slot's list")
check(list.rows[1]:IsShown() and list.rows[4]:IsShown() and not list.rows[5]:IsShown(), "a row an upgrade")
check(list.rows[1].mark:GetText() == "Biggest" and list.rows[2].mark:GetText() == "", "the one shown, marked")
check(list.rows[2].where:GetText() == "Shadowfang Keep \194\183 Arugal \194\183 30% \194\183 at level 23",
	"where each drops, how often, and the level it needs, got %s",
	tostring(list.rows[2].where:GetText()))
check(not list.clear:IsShown(), "no pick to clear yet")
run(list.rows[2], "OnClick")
check(not list:IsShown() and head.name:GetText() == "Item 131" and head.chip:IsShown(),
	"picking one closes the list, and the cell shows it as your pick")
run(head, "OnClick")
check(list.clear:IsShown() and list.rows[2].mark:GetText() == "Your pick", "the list marks your pick, and can clear it")
run(list.clear, "OnClick")
check(head.name:GetText() == "Item 112" and not head.chip:IsShown(), "cleared, it is the biggest again")
run(ui.cells[2], "OnClick")
check(not list:IsShown(), "an empty slot has no list")

-- Nothing found, switched off, and going.
GF.Settings().dungeons = false
GF.Settings().quests, GF.Settings().reputation, GF.Settings().crafted = false, false, false
GF:SettingsChanged()
check(ui.right.empty:IsShown() and ui.right.emptyTitle:GetText() == "Nothing to upgrade", "nothing found: why")
check(ui.right.pic.kind == "logo" and ui.right.pic:IsShown(), "the logo where the loading screen was")
-- Switching to a spec with nothing to suggest took the spec menu with it.
local function onPage(f)
	while f and f ~= page do
		if not f:IsShown() then return false end
		f = f:GetParent()
	end
	return f == page
end
check(onPage(ui.right.spec), "and the spec menu still there, to switch back")
GF.Settings().quests, GF.Settings().reputation, GF.Settings().crafted, GF.Settings().dungeons = true, true, true, true
GF.Settings().enabled = false
GF:SettingsChanged()
check(not tab:IsShown(), "switched off, the tab goes")
GF.Settings().enabled = true
GF:SettingsChanged()
check(tab:IsShown(), "and comes back")
ToggleCharacter("PaperDollFrame")
check(not page:IsShown() and PaperDollFrame:IsShown(), "another tab's page replaces it")
check(CharacterFrameCloseButton:IsShown(), "and the panel's close button is back")
A:ToggleGearFinder()
check(toggled[table.getn(toggled)] == "AegisPathfinderGearFinderPage" and page:IsShown(), "the options' button opens it")
run(head, "OnEnter")
check(GameTooltip.__link == "item:112:0:0:0", "hovering a cell shows the item")

-- Walking into a dungeon ----------------------------------------------------------------

printed = {}
GF:Announce("Wailing Caverns")
check(printed[1] and string.find(printed[1], "Upgrades in Wailing Caverns: Item 112 +40%", 1, true),
	"entering a dungeon names its upgrades, got %s", tostring(printed[1]))
printed = {}
GF:Announce("Elwynn Forest")
check(printed[1] == nil, "not somewhere that is not a dungeon")
A.db.char.Dungeons.WC = false
GF:Announce("Wailing Caverns")
check(printed[1] ~= nil, "a dungeon you have unticked still says, once you are in it")
check(A.db.char.Dungeons.WC == false, "without changing what you ticked")
GF.Settings().announce = false
printed = {}
GF:Announce("Wailing Caverns")
check(printed[1] == nil, "and not at all when switched off")

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end
print(string.format("GearFinder: %d checks", checks))
if table.getn(failures) == 0 then
	print("All gear finder checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
