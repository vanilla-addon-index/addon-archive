--[[
	Tests for the options panel -- the concept's #options.

	It used to be a column of buttons that opened the dungeons, the filters and
	the route picker as three more windows. It is one window now, with the
	categories down the left as Zygor's options have them and the concept's
	sections, in the concept's order, on their pages; so this checks the
	layout, the pages, and that every control actually drives the setting it
	shows.

	Run:  lua5.1 Tools/tests/test_options.lua
]]

package.path = "Tools/tests/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

UISpecialFrames = {}
HideUIPanel = function(f) if f and f.Hide then f:Hide() end end
ShowUIPanel = function(f) if f and f.Show then f:Show() end end
GameTooltip_Hide = function() end
UnitRaceBase = function() return "Human" end

AegisPathfinder = {
	myfaction = "Alliance",
	db = {
		char = {
			routepack = "VanillaGuide", currentroute = "Human",
			PlayStyle = "SOLO", UseAH = false, Dungeons = {},
			autoquest = true, trackquests = false, skipfollowups = true,
			offercustomzones = true, shownavcallout = true, showminimapbutton = true,
			waypointprovider = "auto", currentguide = "Elwynn Forest (1-12)",
		},
		profile = {},
	},
	routepacks = {
		VanillaGuide = {
			name = "VanillaGuide", displayName = "Optimized", description = "Quest-optimized",
			routes = { Human = {
				{ zone = "Elwynn Forest", levels = "1-10", guide = "E" },
				{ zone = "Westfall", levels = "10-12", guide = "W" },
			} },
		},
		RestedXP = {
			name = "RestedXP", displayName = "RestedXP", description = "Speedrun",
			routes = { Human = {} },
		},
	},
}
function AegisPathfinder:Debug() end
function AegisPathfinder:Print() end
function AegisPathfinder.GetQuadrant() return "TOPRIGHT", "TOP", "RIGHT" end
function AegisPathfinder:GetRouteForRace() return "Human" end
function AegisPathfinder:GetAvailableRoutePacks()
	return { self.routepacks.RestedXP, self.routepacks.VanillaGuide }
end
function AegisPathfinder:SelectRoutePack(name) self.db.char.routepack = name end
function AegisPathfinder:SelectRoute(route) self.db.char.currentroute = route end
function AegisPathfinder:GetWaypointProviders()
	return { { name = "TomTom", label = "TomTom" } }
end
function AegisPathfinder:SetWaypointProvider(n) self.db.char.waypointprovider = n end
function AegisPathfinder:GetGuideDungeons() return { DM = true } end
function AegisPathfinder:HasNoGuide() return false end
function AegisPathfinder:SetSelfFound(on)
	self.db.char.SelfFound = on and true or false
	self:RefreshConfigPanel()
end
function AegisPathfinder:LoadGuide() self.__reloaded = (self.__reloaded or 0) + 1 end
function AegisPathfinder:UpdateStatusFrame() end
function AegisPathfinder:UpdateNavCallout() self.__arrowRefreshed = true end
function AegisPathfinder:UpdateMinimapButton() self.__minimapRefreshed = true end
function AegisPathfinder:RefreshActiveFrames() self.__activeRefreshed = (self.__activeRefreshed or 0) + 1 end
function AegisPathfinder:QueryServerCompletedQuests() self.__rescanned = true end
function AegisPathfinder:ShowErrorLog() self.__errorlog = true end
-- The guide's own setters (ObjectivesFrame.lua), as its menu calls them.
function AegisPathfinder:SetGuideLocked(on) self.db.profile.objframelocked = on and true or nil end
function AegisPathfinder:SetGuideTransparent(on) self.db.profile.objframetransparent = on and true or nil end

AegisPathfinder.objectiveframe = CreateFrame("Frame", nil, UIParent)

-- The arrow switches live in Navigation.lua, which enumerates the world map
-- as it loads; lift just the block under test, with stand-ins for the two
-- waypoint addons' providers it asks whether they are loaded.
local tomtomLoaded = true
providers = {
	tomtom = { IsAvailable = function() return tomtomLoaded end },
	pfquest = { IsAvailable = function() return pfQuest_config ~= nil end },
}
do
	local nav = io.open("Navigation.lua"):read("*a")
	local from = string.find(nav, "--[[ Which arrows point", 1, true)
	local to = string.find(nav, "-- Helper to get valid zone data", 1, true)
	assert(from and to, "could not find the arrow block in Navigation.lua")
	assert(loadstring(string.sub(nav, from, to - 1)))()
end
AegisPathfinder.__provider = { label = "TomTom" }
function AegisPathfinder:GetWaypointProvider() return self.__provider end
function AegisPathfinder:ClearWaypoint() self.__cleared = true end
function AegisPathfinder:ForceWaypointUpdate() self.__resent = true end

-- The item score is the real one: its page is in this window.
UnitClass = function() return "Paladin", "PALADIN" end
local talents = { 0, 0, 0 }
GetTalentTabInfo = function(tab) return ({ "Holy", "Protection", "Retribution" })[tab], "icon", talents[tab] end
local advisorSettings = { enabled = true, popups = true, questmark = true, bagmark = true }
local finderSettings = { enabled = true, announce = true, dungeons = true, raids = false, quests = true, reputation = true,
	crafted = true }
AegisPathfinder.GearFinder = { Settings = function() return finderSettings end,
	SettingsChanged = function() AegisPathfinder.__finderChanged = (AegisPathfinder.__finderChanged or 0) + 1 end }
function AegisPathfinder:ToggleGearFinder() self.__finder = (self.__finder or 0) + 1 end
AegisPathfinder.GearAdvisor = {
	Settings = function() return advisorSettings end,
	Dirty = function() end,
	ClearDeclined = function() AegisPathfinder.__declinedCleared = true end,
}

dofile("Theme.lua")
dofile("ItemScoreData.lua")
dofile("ItemScore.lua")
local scoreSettings = AegisPathfinder.ItemScore.Settings()
-- The Talent Advisor is the real one, without a talent tree: its settings are on Extras.
dofile("TalentBuilds.lua")
dofile("TalentAdvisor.lua")
local talentRefreshes, talentOpened = 0, 0
function AegisPathfinder.TalentAdvisor:Refresh() talentRefreshes = talentRefreshes + 1 end
function AegisPathfinder.TalentAdvisor:OpenWindow() talentOpened = talentOpened + 1 end
dofile("GearFrame.lua")
dofile("Credits.lua")
dofile("OptionsFrame.lua")

-- Fire a script the way the client does: with `this` set to its frame.
local function fire(f, script)
	local h = f:GetScript(script)
	assert(h, "no " .. script .. " script")
	local old = this
	this = f
	h()
	this = old
end
local function click(f) fire(f, "OnClick") end

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end

AegisPathfinder:CreateConfigPanel()
local frame = AegisPathfinder.optionsframe
frame:Show()
fire(frame, "OnShow")
local db = AegisPathfinder.db.char

-- One window: the categories on the left, the concept's pane beside them ---------

check(frame:GetWidth() == 396 + 150, "the concept's 396px pane and a 150px list, got %s", frame:GetWidth())
check(frame.header ~= nil and frame.subhead ~= nil, "it wears the concept's chrome")
check(frame.subhead.label:GetText() == "CONFIG \194\183 ROUTE",
	"and names itself Config, and the page, got '%s'", tostring(frame.subhead.label:GetText()))

local order = {}
for _, h in ipairs(frame.sections) do table.insert(order, h.label:GetText()) end
local want = { "RACE", "ROUTE PACK", "DUNGEONS", "TURTLE WOW'S OWN", "ALONG THE WAY", "BOSS NOTES", "FILTERS", "SERVER THEME" }
for i, name in ipairs(want) do
	check(order[i] == name, "section %d should be %s, got %s", i, name, tostring(order[i]))
end

-- Nothing opens a window of its own any more.
check(AegisPathfinder.dungeonframe == nil, "dungeons are a section, not a window")
check(AegisPathfinder.filtersframe == nil, "filters are a section, not a window")
check(AegisPathfinder.ToggleDungeonPanel == nil and AegisPathfinder.ToggleFiltersPanel == nil,
	"the functions that opened those windows are gone")

-- The pages, and the list that picks them.
local PAGES = { "Route", "Dungeons", "Filters", "Appearance", "Step Display", "Automation", "Action Buttons",
	"Navigation", "Maps", "Gear", "Item Score", "Extras", "Maintenance", "About" }
local names = {}
for _, p in ipairs(frame.pages) do table.insert(names, p.pageName) end
check(table.concat(names, ", ") == table.concat(PAGES, ", "), "the pages, in order: %s", table.concat(names, ", "))
check(table.getn(frame.navButtons) == table.getn(PAGES), "one entry in the list per page")
for i, b in ipairs(frame.navButtons) do
	check(b.label:GetText() == PAGES[i], "list entry %d names %s, got %s", i, PAGES[i], tostring(b.label:GetText()))
	local _, rel, _, x = b:GetPoint()
	check(rel == frame.nav and x == 0, "and sits in the list down the left")
end
local function navNamed(name)
	for _, b in ipairs(frame.navButtons) do if b.pageName == name then return b end end
end
local function pageNamed(name)
	for _, p in ipairs(frame.pages) do if p.pageName == name then return p end end
end
local function shown()
	local out = {}
	for _, p in ipairs(frame.pages) do if p:IsShown() then table.insert(out, p.pageName) end end
	return table.concat(out, ", ")
end
check(shown() == "Route", "it opens on the first page alone, got '%s'", shown())
check(frame.navButtons[1].active and frame.navButtons[1].mark:IsShown() and not frame.navButtons[2].mark:IsShown(),
	"marked in the list")
local _, scrollRel, _, scrollX = frame.scroll:GetPoint()
check(scrollRel == frame and scrollX == 150 + 14, "the page sits right of the list, got %s", tostring(scrollX))

click(frame.navButtons[3])
check(shown() == "Filters", "clicking an entry shows its page alone, got '%s'", shown())
check(frame.subhead.label:GetText() == "CONFIG \194\183 FILTERS", "and names it, got '%s'",
	tostring(frame.subhead.label:GetText()))
check(frame.navButtons[3].active and not frame.navButtons[1].active, "and moves the mark")
AegisPathfinder:ShowConfigPage("Nowhere")
check(shown() == "Route", "a page that is not there falls back to the first")

-- Each page's sections run top to bottom, from its top, without overlapping.
local lastY, lastPage = 1, nil
for _, h in ipairs(frame.sections) do
	local _, _, _, _, yoff = h:GetPoint()
	local p = h:GetParent()
	if p ~= lastPage then
		check(yoff == 0, "section %s opens its page", h.label:GetText())
	else
		check(yoff < lastY, "section %s should sit below the one before it", h.label:GetText())
	end
	lastY, lastPage = yoff, p
end
check(frame.sections[1]:GetParent().pageName == "Route" and frame.sections[2]:GetParent().pageName == "Route",
	"Race and Route pack share the Route page")

-- A long page scrolls; a short one does not -------------------------------------

check(not frame.scrollbar:IsShown(), "the Route page fits, so no scroll bar")
local long
for i, p in ipairs(frame.pages) do
	if not long and p.contentHeight > frame.visible then long = i end
end
check(long ~= nil, "at least one page is taller than the window")
if long then
	click(frame.navButtons[long])
	local _, range = frame.scrollbar:GetMinMaxValues()
	check(range > 0 and frame.scrollbar:IsShown(), "the %s page scrolls (range %s)", frame.pages[long].pageName, range)
	check(frame.holder:GetHeight() == frame.pages[long].contentHeight, "over its own height")
	arg1 = -1; fire(frame, "OnMouseWheel")
	check(frame.scroll:GetVerticalScroll() > 0, "the mouse wheel scrolls the page")
	arg1 = 1; fire(frame, "OnMouseWheel")
	check(frame.scroll:GetVerticalScroll() == 0, "and back up, without going past the top")
	arg1 = -1; fire(frame, "OnMouseWheel")
	click(frame.navButtons[1])
	check(frame.scroll:GetVerticalScroll() == 0 and frame.scrollbar:GetValue() == 0,
		"another page opens at its top, the scroll bar with it")
end

-- A list left open does not hang over the next page.
click(frame.race)
check(frame.race.list:IsShown(), "the race list opens")
click(frame.navButtons[2])
check(not frame.race.list:IsShown(), "and closes when the page changes")
click(frame.navButtons[1])

-- Race -------------------------------------------------------------------------------

check(frame.race.label:GetText() == "Human (Alliance) - yours",
	"the race dropdown shows the current race, marked as yours, got '%s'",
	tostring(frame.race.label:GetText()))
check(table.getn(frame.race.items) == 5, "one entry per Alliance race, got %d",
	table.getn(frame.race.items))
click(frame.race)
check(frame.race.list:IsShown(), "clicking the dropdown opens its list")
click(frame.race.rows[2])
check(db.currentroute == "Dwarf", "picking a race selects its route, got %s", tostring(db.currentroute))
check(not frame.race.list:IsShown(), "and closes the list")

-- Route pack --------------------------------------------------------------------------

db.currentroute = "Human"
AegisPathfinder:RefreshConfigPanel()
local optimized, rested
for _, p in ipairs(frame.packPills) do
	if p.packName == "VanillaGuide" then optimized = p end
	if p.packName == "RestedXP" then rested = p end
end
check(optimized and optimized.label:GetText() == "OPTIMIZED",
	"the default pack is shown as the concept names it")
check(optimized and optimized.fill.center.__color[2] > 0.7, "and it is the active pill")
click(rested)
check(db.routepack == "RestedXP", "clicking a pill switches pack, got %s", tostring(db.routepack))

-- The preview is the route this race takes under the selected pack.
click(optimized)
check(frame.preview.rows[1].lvl:GetText() == "1-10"
	and frame.preview.rows[1].zone:GetText() == "Elwynn Forest",
	"the preview lists the route's first leg, got '%s %s'",
	tostring(frame.preview.rows[1].lvl:GetText()), tostring(frame.preview.rows[1].zone:GetText()))
check(frame.preview.rows[2].zone:GetText() == "Westfall", "and its second")
check(not frame.preview.rows[3]:IsShown(), "and nothing past the end of it")

-- Dungeons ------------------------------------------------------------------------------

check(table.getn(frame.chips) == 22, "fifteen dungeon chips and Turtle's seven, got %d", table.getn(frame.chips))
local whc
for _, c in ipairs(frame.chips) do if c.dungeonCode == "WHC" then whc = c end end
check(whc ~= nil, "Windhorn Canyon has a chip")
click(whc)
check(db.Dungeons.WHC == true and whc:IsActive(), "and it ticks like any other")
click(whc)
check(db.Dungeons.WHC == false and not whc:IsActive(), "and unticks")
check(not frame.alongSwitch:IsOn(), "dungeon guides along the way start off")
click(frame.alongSwitch)
check(db.offerdungeons == true and frame.alongSwitch:IsOn(), "and the switch turns them on")
click(frame.alongSwitch)
check(db.offerdungeons == false, "and off")
check(frame.midSwitch:IsOn(), "a dungeon's guide at the middle of its levels starts on")
click(frame.midSwitch)
check(db.middungeons == false and not frame.midSwitch:IsOn(), "and the switch turns it off")
click(frame.midSwitch)
check(db.middungeons == true, "and on")
local dm
for _, c in ipairs(frame.chips) do if c.dungeonCode == "DM" then dm = c end end
check(dm.dot:IsShown(), "the dungeon this guide has steps for carries the blue dot")
local reloads = AegisPathfinder.__reloaded or 0
click(dm)
check(db.Dungeons.DM == true, "clicking a chip opts in")
check((AegisPathfinder.__reloaded or 0) > reloads, "and reloads the guide so it takes effect")

-- Filters -------------------------------------------------------------------------------

check(not frame.groupSwitch:IsOn(), "solo by default, so group mode is off")
check(frame.filterNote:GetText() == "Solo mode \194\183 Auction House steps hidden",
	"the summary reads as the concept's does, got '%s'", tostring(frame.filterNote:GetText()))
click(frame.groupSwitch)
check(db.PlayStyle == "GROUP", "the switch sets group mode, got %s", tostring(db.PlayStyle))
check(frame.groupSwitch:IsOn(), "and shows it")
click(frame.ahSwitch)
check(db.UseAH == true, "the Auction House switch turns those steps on")
check(frame.filterNote:GetText() == "Group mode \194\183 Auction House steps shown",
	"and the summary follows, got '%s'", tostring(frame.filterNote:GetText()))

-- Gear: the score on tooltips, and the weights window.
check(frame.scoreTips:IsOn(), "the item score is on tooltips by default")
click(frame.scoreTips)
check(scoreSettings.tooltips == false, "and the switch takes it off")
click(frame.scoreTips)
click(frame.weightsButton)
check(frame.page == "Item Score", "Stat weights turns to the Item Score page, got %s", tostring(frame.page))
check(AegisPathfinder.gearframe == nil, "not a window of its own")

-- Item Score: Zygor's page, listed under Gear.
local scoreNav, gearNav
for _, b in ipairs(frame.navButtons) do
	if b.pageName == "Item Score" then scoreNav = b end
	if b.pageName == "Gear" then gearNav = b end
end
local _, _, _, scoreX = scoreNav.label:GetPoint()
local _, _, _, gearX = gearNav.label:GetPoint()
check(scoreX > gearX, "the list sets Item Score in under Gear (%s against %s)", tostring(scoreX), tostring(gearX))
check(frame.subhead.label:GetText() == "CONFIG \194\183 ITEM SCORE", "the subhead names it")
local scorePage = AegisPathfinder.itemscorepage
check(scorePage.body:IsShown() and scorePage.body.pageName == "Item Score", "the page is shown")
check(scorePage.cells.STRENGTH and scorePage.cells.STRENGTH:IsShown(), "with the weights on it")
local _, shortRange = frame.scrollbar:GetMinMaxValues()
click(scorePage.showAll)
local _, longRange = frame.scrollbar:GetMinMaxValues()
check(longRange > shortRange and frame.holder:GetHeight() == scorePage.body.contentHeight,
	"Show all stats lengthens the page, and the window scrolls further (%s to %s)", shortRange, longRange)
arg1 = -3; fire(frame, "OnMouseWheel")
local at = frame.scroll:GetVerticalScroll()
click(scorePage.showAll)
check(frame.scroll:GetVerticalScroll() == math.min(at, select(2, frame.scrollbar:GetMinMaxValues())),
	"and shortening it keeps your place where it can")
click(scorePage.spec)
check(scorePage.spec.list:IsShown(), "the spec picker opens")
click(gearNav)
check(not scorePage.spec.list:IsShown(), "and closes with the page")
talents[2] = 21
AegisPathfinder.ItemScore:Changed()
check(scorePage.spec.items[1].label == "Auto (Retribution)", "off screen, the page waits")
click(scoreNav)
check(scorePage.spec.items[1].label == "Auto (Protection)", "and is drawn afresh when turned to, got %s",
	scorePage.spec.items[1].label)
talents[2] = 0
AegisPathfinder.ItemScore:Changed()
click(gearNav)

-- /apg gear: the window at this page, or closed if it is on it.
AegisPathfinder:ToggleItemScorePage()
check(frame:IsShown() and frame.page == "Item Score", "/apg gear turns an open window to the page")
AegisPathfinder:ToggleItemScorePage()
check(not frame:IsShown(), "and again closes it")
AegisPathfinder:ToggleItemScorePage()
check(frame:IsShown() and frame.page == "Item Score", "and opens it at the page when it is closed")
click(frame.navButtons[1])
check(frame.advisor.enabled:IsOn() and frame.advisor.popups:IsOn(), "the Gear Advisor is on, with pop-ups")
check(not frame.advisor.autoequip:IsOn() and not frame.advisor.questpick:IsOn(),
	"nothing is equipped or picked for you until you ask")
click(frame.advisor.autoequip)
check(advisorSettings.autoequip == true, "the switch asks for it")
click(frame.advisor.enabled)
check(advisorSettings.enabled == false and not frame.advisor.popups:IsEnabled(),
	"with the advisor off its other switches are held")
click(frame.advisor.enabled)
check(frame.advisor.popups:IsEnabled(), "and let go when it is back on")
click(frame.clearDeclined)
check(AegisPathfinder.__declinedCleared, "Clear declined items clears them")
check(frame.finder.enabled:IsOn() and frame.finder.announce:IsOn(), "the gear finder is on, and names upgrades")
-- The upgrade sources: a box each, Zygor's Dungeons and Raids and the three
-- that were "Look at ..." switches, which keep what they were set to.
check(frame.finder.quests == nil and frame.finder.reputation == nil and frame.finder.crafted == nil,
	"quest, reputation and crafted gear are no longer switches")
check(frame.sources.quests:IsOn() and frame.sources.reputation:IsOn() and frame.sources.crafted:IsOn(),
	"but boxes under the sources, ticked as the switches were")
check(frame.sources.quests.label:GetText() == "Quest rewards" and frame.sources.reputation.label:GetText()
	== "Reputation vendors" and frame.sources.crafted.label:GetText() == "Crafted gear", "named for what they are")
do
	local _, _, _, x1, y1 = frame.sources.dungeons:GetPoint()
	local _, _, _, x2, y2 = frame.sources.raids:GetPoint()
	local _, _, _, x3, y3 = frame.sources.quests:GetPoint()
	local _, _, _, x5, y5 = frame.sources.crafted:GetPoint()
	check(y1 == y2 and x2 > x1 and x3 == x1 and y3 < y1 and y5 < y3, "two to a row, three rows")
	check(x2 + frame.sources.reputation:GetWidth() <= frame.bodyW, "and inside the page")
end
click(frame.sources.crafted)
check(finderSettings.crafted == false and (AegisPathfinder.__finderChanged or 0) > 0, "each of which can be unticked")
click(frame.sources.crafted)
click(frame.sources.quests)
click(frame.sources.reputation)
click(frame.sources.crafted)
check(not finderSettings.quests and not finderSettings.reputation and not finderSettings.crafted and finderSettings.dungeons,
	"so it can look in dungeons alone")
click(frame.sources.quests)
click(frame.sources.reputation)
click(frame.sources.crafted)
check(frame.sources.dungeons:IsOn() and not frame.sources.raids:IsOn(), "upgrade sources: Dungeons ticked, Raids not")
local said = {}
local keepPrint = AegisPathfinder.Print
function AegisPathfinder:Print(msg) table.insert(said, msg) end
local changed = AegisPathfinder.__finderChanged or 0
click(frame.sources.raids)
check(finderSettings.raids == true and frame.sources.raids:IsOn(), "ticking Raids looks in raids")
check(said[1] and string.find(said[1], "minute or two", 1, true), "and says the first look takes a while, got %s", tostring(said[1]))
check((AegisPathfinder.__finderChanged or 0) > changed, "and the tab follows at once")
click(frame.sources.dungeons)
check(finderSettings.dungeons == false, "Dungeons can be unticked too")
click(frame.sources.dungeons)
click(frame.sources.raids)
check(finderSettings.dungeons and not finderSettings.raids, "and both back as they were")
AegisPathfinder.Print = keepPrint
click(frame.finder.enabled)
check(finderSettings.enabled == false and not frame.finder.announce:IsEnabled() and not frame.sources.raids:IsEnabled(),
	"off, its other switches and the sources are held")
click(frame.finder.enabled)
click(frame.openFinder)
check(AegisPathfinder.__finder == 1, "the Open the Gear Finder button opens it")

-- Solo Self-Found holds group mode, the Auction House and the dungeons off,
-- and lets them go again as they were.
check(not frame.ssfSwitch:IsOn(), "Solo Self-Found is off by default")
fire(frame.ssfSwitch, "OnEnter")
check(AegisPathfinder.Theme.tip and AegisPathfinder.Theme.tip:IsShown(), "hovering it explains it, without an error")
fire(frame.ssfSwitch, "OnLeave")
check(db.PlayStyle == "GROUP" and db.UseAH and db.Dungeons.DM, "group mode, the Auction House and Deadmines are on")
click(frame.ssfSwitch)
check(db.SelfFound == true, "the Self-Found switch turns it on")
check(not frame.ahSwitch:IsOn(), "with Self-Found on, the Auction House switch reads off")
check(not frame.ahSwitch:IsEnabled(), "and cannot be clicked")
check(not frame.groupSwitch:IsOn() and not frame.groupSwitch:IsEnabled(), "group mode reads off and cannot be clicked")
check(not dm:IsActive() and not dm:IsEnabled(), "the dungeons read off and cannot be clicked")
click(dm)
check(db.Dungeons.DM == true and not dm:IsActive(), "a click on a held dungeon does nothing")
check(frame.wiredHint:GetText() == "Solo Self-Found is on: no dungeons until it is off.",
	"the dungeons page says why, got '%s'", tostring(frame.wiredHint:GetText()))
check(frame.filterNote:GetText() == "Solo Self-Found \194\183 no group quests, dungeons, trading or Auction House steps",
	"the summary says so, got '%s'", tostring(frame.filterNote:GetText()))
check(db.UseAH == true and db.PlayStyle == "GROUP" and db.Dungeons.DM == true,
	"Self-Found does not forget the choices underneath")
click(frame.ssfSwitch)
check(db.SelfFound == false and frame.ahSwitch:IsOn() and frame.ahSwitch:IsEnabled(),
	"turning Self-Found off gives the Auction House switch back as it was")
check(frame.groupSwitch:IsOn() and frame.groupSwitch:IsEnabled(), "and group mode")
check(dm:IsActive() and dm:IsEnabled(), "and the dungeons")

-- The knob slides: left when off, right when on.
local _, _, _, onX = frame.groupSwitch.knob:GetPoint()
click(frame.groupSwitch)
local _, _, _, offX = frame.groupSwitch.knob:GetPoint()
check(onX > offX, "the knob sits right when on (%s) and left when off (%s)", onX, offX)

-- Server theme ---------------------------------------------------------------------------

local themeLabels = {}
for _, row in ipairs(frame.theme.rows) do table.insert(themeLabels, row.text:GetText()) end
check(table.concat(themeLabels, ", ") == "Day, Night, Turtle WoW, OctoWoW, RavenCraft, Capybara Paradise, Aegis",
	"the themes, in order: %s", table.concat(themeLabels, ", "))
check(frame.theme.label:GetText() == "Turtle WoW", "the theme defaults to Turtle WoW, got '%s'",
	tostring(frame.theme.label:GetText()))
check(frame.server == nil, "the Server dropdown is gone")
local function pickTheme(label)
	for _, row in ipairs(frame.theme.rows) do
		if row.text:GetText() == label then click(row) return end
	end
	error("no theme " .. label)
end
local Theme = AegisPathfinder.Theme
local green = { Theme.color.accent[1], Theme.color.accent[2], Theme.color.accent[3] }
pickTheme("OctoWoW")
check(AegisPathfinder.db.profile.theme == "octowow", "picking a theme saves it")
check(Theme.color.accent[1] > green[1] and Theme.color.accent[3] > green[3], "and the accent turns purple")
check(frame.themeNote:GetText() == "OctoWoW's purple.", "the note says what it looks like, got '%s'",
	tostring(frame.themeNote:GetText()))
check(AegisPathfinder.db.profile.server == nil, "a theme is colours only: it says nothing about your server")
pickTheme("RavenCraft")
check(string.find(frame.themeNote:GetText(), "RavenCraft's dark grey", 1, true) == 1
	and not string.find(frame.themeNote:GetText(), "guide data", 1, true), "and nothing about guide data")
pickTheme("Night")
check(frame.themeNote:GetText() == "Moonlight blue on deeper panels.", "Night says only what it looks like")

-- Switch colours: the theme's, or red and green.
check(frame.redGreen and not frame.redGreen:IsOn() and Theme.switchColours == "theme",
	"switches take the theme's colours to start with")
click(frame.redGreen)
check(AegisPathfinder.db.profile.switchcolours == "redgreen" and Theme.switchColours == "redgreen",
	"the switch turns them red and green, and it is saved, got %s", tostring(AegisPathfinder.db.profile.switchcolours))
do
	local r, g = frame.redGreen.track:GetVertexColor()
	check(g > r, "and it is green itself now it is on")
end
AegisPathfinder:RefreshConfigPanel()
check(frame.redGreen:IsOn(), "the panel shows it on")
click(frame.redGreen)
check(AegisPathfinder.db.profile.switchcolours == "theme" and Theme.switchColours == "theme",
	"and off, the theme's again")

-- Window scale -------------------------------------------------------------------------

check(frame.scale and frame.scale.value:GetText() == "100%", "the scale starts at 100%%, got '%s'",
	tostring(frame.scale and frame.scale.value:GetText()))
frame.scale.slider:SetValue(1.25)            -- the player drags it
check(AegisPathfinder.db.profile.windowscale == 1.25, "dragging the scale saves it, got %s",
	tostring(AegisPathfinder.db.profile.windowscale))
check(math.abs(frame:GetScale() - 1.25) < 1e-6, "and scales this window, got %s", tostring(frame:GetScale()))
check(frame.scale.value:GetText() == "125%", "and says so, got '%s'", tostring(frame.scale.value:GetText()))
frame.scale.slider:SetValue(3)
check(AegisPathfinder.db.profile.windowscale == Theme.SCALE_MAX, "no bigger than the most it allows, got %s",
	tostring(AegisPathfinder.db.profile.windowscale))
local later = CreateFrame("Frame", nil, UIParent)
Theme:RegisterWindow(later)
check(math.abs(later:GetScale() - Theme.SCALE_MAX) < 1e-6, "a window built later takes the scale too")
AegisPathfinder:SetWindowScale(1)
check(math.abs(frame:GetScale() - 1) < 1e-6 and math.abs(later:GetScale() - 1) < 1e-6, "and back to 100%%")
-- A drag: the scale slider sits in a window it scales, so while the mouse is
-- held only the number follows it. Rescaling on every step moved the slider
-- out from under the cursor and chased it to 60%, stuck there.
frame.scale.slider:GetScript("OnMouseDown")()
frame.scale.slider:SetValue(0.6)              -- where the window's shift would pull it
frame.scale.slider:SetValue(1.2)
check(AegisPathfinder.db.profile.windowscale == 1, "a drag in progress saves nothing yet, got %s",
	tostring(AegisPathfinder.db.profile.windowscale))
check(math.abs(frame:GetScale() - 1) < 1e-6, "nor scales the window under the cursor, got %s", tostring(frame:GetScale()))
check(frame.scale.value:GetText() == "120%", "but the number follows the thumb, got '%s'",
	tostring(frame.scale.value:GetText()))
frame.scale.slider:GetScript("OnMouseUp")()
check(math.abs(AegisPathfinder.db.profile.windowscale - 1.2) < 1e-6 and math.abs(frame:GetScale() - 1.2) < 1e-6,
	"letting go applies where it was let go, got %s", tostring(AegisPathfinder.db.profile.windowscale))
frame.scale.slider:GetScript("OnMouseUp")()
check(math.abs(AegisPathfinder.db.profile.windowscale - 1.2) < 1e-6, "and a second release changes nothing")
AegisPathfinder:SetWindowScale(1)
frame.scale:SetValue(1)
pickTheme("Turtle WoW")
check(Theme.color.accent[1] == green[1] and Theme.color.accent[2] == green[2], "and Turtle WoW is green again")

-- The addon's own settings ---------------------------------------------------------------

-- Behaviour's switches went to Zygor's pages, keeping their saved values.
local HOME = {
	autoquest = "Automation", trackquests = "Automation",
	skipfollowups = "Step Display", offercustomzones = "Step Display", classquests = "Step Display",
	showminimapbutton = "Appearance",
	showactiveitems = "Action Buttons", showactivetargets = "Action Buttons", showmacros = "Action Buttons",
	questicons = "Action Buttons",
}
for key, pageName in pairs(HOME) do
	local sw = frame.switches[key]
	check(sw and sw:GetParent().pageName == pageName, "%s is on the %s page, got %s", key, pageName,
		tostring(sw and sw:GetParent().pageName))
end
check(pageNamed("Behaviour") == nil, "and the Behaviour page is gone")
check(frame.switches.autoquest:IsOn(), "switches start from the saved settings")
check(not frame.switches.trackquests:IsOn(), "off ones included")
click(frame.switches.trackquests)
check(db.trackquests == true, "and write back to them")

-- Automation's own: all quests and picking from a list under accepting, the
-- flight master, the vendor.
local autoPage = pageNamed("Automation")
for _, key in ipairs({ "allquests", "autogossip", "autofly", "autobuy", "sellbutton", "autosell" }) do
	check(frame.switches[key] and frame.switches[key]:GetParent() == autoPage, "%s is on the Automation page", key)
end
check(not frame.switches.allquests:IsOn() and frame.switches.autogossip:IsOn(),
	"all quests off and picking from a list on, to start with")
check(frame.switches.autobuy:IsOn() and frame.switches.sellbutton:IsOn(), "buying and the Sell greys button on")
check(not frame.switches.autosell:IsOn() and not frame.switches.autofly:IsOn(), "selling and flying by themselves off")
do
	local _, _, _, parentX = frame.switches.autoquest:GetPoint()
	local _, _, _, subX = frame.switches.allquests:GetPoint()
	check(subX > parentX, "all quests sits in under accepting the guide's (%s, %s)", tostring(subX), tostring(parentX))
	check(frame.switches.allquests:GetWidth() < frame.switches.autoquest:GetWidth(), "and stops at the same edge")
end
click(frame.switches.autoquest)
check(not db.autoquest and not frame.switches.allquests:IsEnabled() and not frame.switches.autogossip:IsEnabled(),
	"accepting off holds the two under it off")
click(frame.switches.autoquest)
check(frame.switches.allquests:IsEnabled() and frame.switches.autogossip:IsEnabled(), "and lets them go")
click(frame.switches.allquests)
check(db.allquests == true, "all quests switches on")
click(frame.switches.allquests)
click(frame.switches.autogossip)
check(db.autogossip == false and not frame.switches.autogossip:IsOn(), "picking from a list switches off")
click(frame.switches.autogossip)
click(frame.switches.autofly)
check(db.autofly == true, "flying by itself switches on")
click(frame.switches.autofly)
do
	local keepAuto = AegisPathfinder.Automation
	AegisPathfinder.Automation = { PlaceButton = function() AegisPathfinder.__placed = true end }
	click(frame.switches.sellbutton)
	check(db.sellbutton == false and AegisPathfinder.__placed, "the Sell greys button goes at once")
	click(frame.switches.sellbutton)
	AegisPathfinder.Automation = keepAuto
end
check(frame.repair:GetParent() == autoPage and frame.repair.label:GetText() == "Don't repair",
	"repairing: a dropdown, not repairing to start with, got %s", tostring(frame.repair.label:GetText()))
click(frame.repair)
click(frame.repair.rows[2])
check(db.autorepair == "own" and frame.repair.label:GetText() == "With my own money", "and with your own money")
click(frame.repair)
check(frame.repair.list:IsShown(), "its list opens")
click(navNamed("Gear"))
check(not frame.repair.list:IsShown(), "and closes with the page, as the others do")
click(navNamed("Automation"))

-- Appearance's guide settings and the hiding switches; Step Display's steps,
-- skips and party sync.
do
	local profile = AegisPathfinder.db.profile
	local calls = {}
	local function stubCall(name) AegisPathfinder[name] = function(_, v) table.insert(calls, name .. " " .. tostring(v)) end end
	for _, name in ipairs({ "SetGuideOpacity", "SetBrowserOpacity", "SetStepTextSize", "SetGuideProgressShown",
		"SetGuideUpward" }) do stubCall(name) end
	local appearance, steps = pageNamed("Appearance"), pageNamed("Step Display")
	check(frame.guideOpacity:GetParent() == appearance and frame.browserOpacity:GetParent() == appearance
		and frame.textSize:GetParent() == appearance, "the opacity and text size sliders are on Appearance")
	check(frame.guideOpacity.value:GetText() == "50%" and frame.browserOpacity.value:GetText() == "100%"
		and frame.textSize.value:GetText() == "100%", "at 50%%, 100%% and 100%% to start with")
	check(frame.guideOpacity:GetAlpha() < 1, "the guide's opacity is held while Transparency is off")
	do
		local _, _, _, ox = frame.guideOpacity:GetPoint()
		local _, _, _, tx = frame.guideTransparent:GetPoint()
		check(ox > tx, "and sits in under Transparency")
	end
	profile.objframetransparent = true
	AegisPathfinder:RefreshConfigPanel()
	check(frame.guideOpacity:GetAlpha() == 1, "and let go with it on")
	profile.objframetransparent = nil
	frame.guideOpacity.slider:SetValue(0.3)
	frame.browserOpacity.slider:SetValue(0.6)
	frame.textSize.slider:SetValue(1.2)
	check(calls[1] == "SetGuideOpacity 0.3" and calls[2] == "SetBrowserOpacity 0.6" and string.find(calls[3], "SetStepTextSize 1.2", 1, true),
		"each slider sets its own, got %s", table.concat(calls, ", "))
	check(frame.guideProgress:IsOn() and not frame.guideUpward:IsOn(), "the progress bar on and growing upward off, to start with")
	click(frame.guideProgress)
	click(frame.guideUpward)
	check(calls[4] == "SetGuideProgressShown false" and calls[5] == "SetGuideUpward true", "the switches say so, got %s %s",
		tostring(calls[4]), tostring(calls[5]))
	-- Hiding the guide.
	for _, key in ipairs({ "hideininstance", "showafterinstance", "hideincombat", "hidebuttonscombat" }) do
		check(frame.pswitches[key] and frame.pswitches[key]:GetParent() == appearance, "%s is on Appearance", key)
	end
	check(not frame.pswitches.hideininstance:IsOn() and frame.pswitches.showafterinstance:IsOn()
		and not frame.pswitches.showafterinstance:IsEnabled(), "hiding in dungeons off; showing again on, held with it")
	click(frame.pswitches.hideininstance)
	check(profile.hideininstance == true and frame.pswitches.showafterinstance:IsEnabled(), "on, the one under it is let go")
	click(frame.pswitches.showafterinstance)
	check(profile.showafterinstance == false, "and can be switched off")
	click(frame.pswitches.hideincombat)
	click(frame.pswitches.hidebuttonscombat)
	check(profile.hideincombat and profile.hidebuttonscombat, "hiding in combat, and the buttons with it")
	profile.hideininstance, profile.showafterinstance, profile.hideincombat, profile.hidebuttonscombat = nil, nil, nil, nil
	-- Step Display.
	check(frame.focusSteps:GetParent() == steps and frame.focusSteps.label:GetText() == "1 (the step you are on)",
		"steps shown in focus mode: one to start with")
	click(frame.focusSteps)
	click(frame.focusSteps.rows[3])
	check(db.focussteps == 3, "and up to five, got %s", tostring(db.focussteps))
	db.focussteps = nil
	local reloads = AegisPathfinder.__reloaded or 0
	check(frame.switches.skiphearth:GetParent() == steps and not frame.switches.skiphearth:IsOn(), "skipping hearthstones off to start with")
	click(frame.switches.skiphearth)
	check(db.skiphearth == true and (AegisPathfinder.__reloaded or 0) > reloads, "on, the guide is read again without them")
	click(frame.switches.skipflightpaths)
	check(db.skipflightpaths == true, "and flight paths")
	click(frame.switches.skiphearth)
	click(frame.switches.skipflightpaths)
	local stopped
	AegisPathfinder.shareState = { active = true }
	function AegisPathfinder:StopSharing() stopped = true end
	function AegisPathfinder:PaintShareButton() self.__sharePainted = true end
	check(frame.switches.partysync:IsOn() and frame.askShare:IsEnabled(), "party sync on, asking before inviting let go")
	click(frame.switches.partysync)
	check(db.partysync == false and stopped and AegisPathfinder.__sharePainted, "off, sharing stops and the icon goes")
	check(not frame.askShare:IsEnabled(), "and asking is held off with it")
	click(frame.switches.partysync)
	check(frame.askShare:IsEnabled(), "back on, let go")
	AegisPathfinder.shareState = nil
end

-- Action Buttons: which way the windows grow, their size, which buttons, the mark.
do
	local abPage = pageNamed("Action Buttons")
	local grown, scaled = {}, 0
	function AegisPathfinder:SetActiveGrowth(which, dir) table.insert(grown, which .. " " .. dir) end
	function AegisPathfinder:ApplyButtonScale() scaled = scaled + 1 end
	check(frame.itemsGrow:GetParent() == abPage and frame.targetsGrow:GetParent() == abPage, "the growth dropdowns are on the page")
	check(frame.itemsGrow.label:GetText() == "Right" and frame.targetsGrow.label:GetText() == "Right", "both grow right to start with")
	click(frame.itemsGrow)
	click(frame.itemsGrow.rows[3])
	check(db.itemsgrow == "up" and grown[1] == "items up", "picking Up grows Active Items up, got %s", tostring(grown[1]))
	click(frame.targetsGrow)
	click(frame.targetsGrow.rows[2])
	check(db.targetsgrow == "left" and grown[2] == "targets left", "and Active Targets its own way")
	check(frame.buttonSize:GetParent() == abPage and frame.buttonSize.value:GetText() == "100%", "button size: 100%% to start with")
	frame.buttonSize.slider:SetValue(1.25)
	check(math.abs(db.buttonscale - 1.25) < 1e-6 and scaled == 1, "dragging it sizes the windows, got %s", tostring(db.buttonscale))
	for _, key in ipairs({ "btnitems", "btntalk", "btnkill", "btndelete" }) do
		check(frame.boxes[key] and frame.boxes[key]:IsOn(), "the %s box is ticked to start with", key)
	end
	check(frame.boxes.btndelete.label:GetText() == "Delete cheapest item", "the fourth is Delete cheapest item")
	local before = AegisPathfinder.__activeRefreshed or 0
	click(frame.boxes.btnkill)
	check(db.btnkill == false and (AegisPathfinder.__activeRefreshed or 0) > before, "unticking one repaints the windows")
	click(frame.boxes.btnkill)
	check(frame.switches.raidmark and frame.switches.raidmark:IsOn(), "the target buttons mark, to start with")
	click(frame.switches.raidmark)
	check(db.raidmark == false, "and can be told not to")
	click(frame.switches.raidmark)
	db.itemsgrow, db.targetsgrow, db.buttonscale = nil, nil, nil
	AegisPathfinder:RefreshConfigPanel()
	check(frame.itemsGrow.label:GetText() == "Right" and frame.buttonSize.value:GetText() == "100%",
		"a character without them reads right and 100%%")
end

-- Maps: the reveal, the step's places, the trail and its style, the rares.
do
	local profile = AegisPathfinder.db.profile
	local mapsPage = pageNamed("Maps")
	local redrawn = 0
	local savedMaps = AegisPathfinder.Maps
	AegisPathfinder.Maps = { Refresh = function() redrawn = redrawn + 1 end }
	for _, key in ipairs({ "mapreveal", "mapmarkers", "anttrail", "maprares", "raresseethru" }) do
		check(frame.pswitches[key] and frame.pswitches[key]:GetParent() == mapsPage, "%s is on Maps, kept per profile", key)
	end
	check(frame.pswitches.mapreveal:IsOn() and frame.pswitches.mapmarkers:IsOn() and frame.pswitches.anttrail:IsOn(),
		"the reveal, the step's places and the trail are on to start with")
	check(not frame.pswitches.maprares:IsOn() and not frame.pswitches.raresseethru:IsEnabled(),
		"the rares off, and see-through held with them")
	click(frame.pswitches.mapreveal)
	check(profile.mapreveal == false and redrawn == 1, "switching the reveal off redraws the map")
	click(frame.pswitches.mapreveal)
	-- The trail's style: a short dropdown in under its switch.
	check(frame.antStyle:GetParent() == mapsPage and frame.antStyle.dropdown.label:GetText() == "Dots",
		"the trail is dots to start with")
	do
		local _, _, _, sx = frame.antStyle:GetPoint()
		local _, _, _, tx = frame.pswitches.anttrail:GetPoint()
		check(sx > tx, "its style sits in under the trail's switch")
	end
	check(frame.antStyle:GetAlpha() == 1, "and is let go while the trail is on")
	click(frame.antStyle.dropdown)
	click(frame.antStyle.dropdown.rows[2])
	check(profile.antstyle == "dashes" and frame.antStyle.dropdown.label:GetText() == "Dashes", "dashes, picked")
	click(frame.pswitches.anttrail)
	check(profile.anttrail == false and frame.antStyle:GetAlpha() < 1, "the trail off holds its style")
	check(not frame.antStyle.dropdown:IsMouseEnabled(), "which cannot be opened then")
	click(frame.pswitches.anttrail)
	-- The rares: the size held, and see-through, until they are on.
	check(frame.rareSize:GetParent() == mapsPage and frame.rareSize.value:GetText() == "100%"
		and frame.rareSize:GetAlpha() < 1, "the icon size is 100%%, held while the rares are off")
	click(frame.pswitches.maprares)
	check(profile.maprares == true and frame.rareSize:GetAlpha() == 1 and frame.pswitches.raresseethru:IsEnabled(),
		"rares on: the size and see-through let go")
	local before = redrawn
	frame.rareSize.slider:SetValue(1.3)
	check(math.abs(profile.raresize - 1.3) < 1e-6 and redrawn > before, "a bigger icon redraws them, got %s",
		tostring(profile.raresize))
	click(frame.pswitches.raresseethru)
	check(profile.raresseethru == true, "and they can be see-through")
	profile.mapreveal, profile.anttrail, profile.antstyle, profile.maprares = nil, nil, nil, nil
	profile.raresize, profile.raresseethru = nil, nil
	AegisPathfinder:RefreshConfigPanel()
	check(frame.antStyle.dropdown.label:GetText() == "Dots" and frame.rareSize.value:GetText() == "100%",
		"a profile without them reads dots and 100%%")
	AegisPathfinder.Maps = savedMaps
end

-- Extras: chat messages, detailed reputation, level-up announcements.
do
	local extras = pageNamed("Extras")
	check(frame.switches.chatmessages and frame.switches.chatmessages:GetParent() == extras
		and frame.switches.chatmessages:IsOn(), "Pathfinder's chat messages: on Extras, on to start with")
	check(frame.switches.repdetail and frame.switches.repdetail:GetParent() == extras
		and not frame.switches.repdetail:IsOn(), "detailed reputation gains: off to start with")
	click(frame.switches.chatmessages)
	check(db.chatmessages == false, "the chat messages can be switched off")
	click(frame.switches.repdetail)
	check(db.repdetail == true, "and the reputation detail on")
	local labels = {}
	for _, key in ipairs({ "levelemote", "levelparty", "levelguild" }) do
		local box = frame.boxes[key]
		check(box and box:GetParent():GetParent() == extras, "the %s box is on Extras", key)
		if box then table.insert(labels, box.label:GetText()) end
	end
	check(table.concat(labels, ", ") == "Emote, Party chat, Guild chat", "Emote, Party chat, Guild chat; got %s",
		table.concat(labels, ", "))
	check(frame.boxes.levelemote:IsOn() and not frame.boxes.levelparty:IsOn() and not frame.boxes.levelguild:IsOn(),
		"the emote ticked to start with, party and guild not")
	click(frame.boxes.levelemote)
	check(db.levelemote == false, "the emote can be unticked")
	click(frame.boxes.levelparty)
	check(db.levelparty == true and frame.boxes.levelparty:IsOn(), "ticking one turns it on")
	AegisPathfinder:RefreshConfigPanel()
	check(frame.boxes.levelparty:IsOn() and not frame.boxes.levelemote:IsOn() and not frame.boxes.levelguild:IsOn(),
		"and they stay as set")
	-- The Talent Advisor: on to start with, the chat line too, following
	-- levelling then your spec.
	local TA = AegisPathfinder.TalentAdvisor
	local advisor, talentChat = frame.switches.talentadvisor, frame.switches.talentchat
	check(advisor and advisor:GetParent() == extras and advisor:IsOn() and advisor:IsEnabled(),
		"the Talent Advisor's switch is on Extras, on to start with")
	check(talentChat and talentChat:IsOn() and talentChat:IsEnabled(), "and naming the talent in chat, under it")
	check(frame.talentBuild and frame.talentBuild:GetParent() == extras and frame.talentBuild:GetValue() == "auto",
		"the build to follow: levelling, then your spec")
	local labels, order = {}, {}
	for _, item in ipairs(frame.talentBuild.items) do
		labels[item.value] = item.label
		table.insert(order, item.value)
	end
	local preferred = TA:PreferredBuild(AegisPathfinder.TalentBuilds.PALADIN)
	check(preferred and labels.auto == "Leveling, then " .. preferred.spec .. " at 60",
		"it names your spec, got %s", tostring(labels.auto))
	check(labels.levelling == "Paladin leveling" and labels["levelling:Protection"] == "Paladin Protection leveling"
		and table.concat(order, ",") == "auto,auto:Protection,levelling,levelling:Protection,Holy,Protection,Retribution",
		"then Protection, the levelling builds and each spec's, got %s", table.concat(order, ","))
	check(preferred and labels[preferred.spec] == preferred.spec .. " at 60 (my spec)", "yours marked")
	check(labels.Holy == "Holy at 60" or preferred.spec == "Holy", "the others not")
	click(advisor)
	check(db.talentadvisor == false and talentRefreshes == 1, "switched off, the talent window is drawn again")
	check(not talentChat:IsEnabled() and frame.talentBuild:GetAlpha() < 1, "and the chat line and the build are held")
	click(advisor)
	check(db.talentadvisor == true and talentChat:IsEnabled() and frame.talentBuild:GetAlpha() == 1, "on again")
	fire(frame.talentBuild.rows[5], "OnClick")
	check(db.talentbuild == "Holy" and talentRefreshes == 3, "picking Holy follows it, and redraws, got %s",
		tostring(db.talentbuild))
	AegisPathfinder:RefreshConfigPanel()
	check(frame.talentBuild:GetValue() == "Holy", "a refresh keeps it")
	click(frame.openTalents)
	check(talentOpened == 1, "Open the talent window opens it")
	db.talentbuild = "auto"
	check(frame.boxes.btnkill:IsOn(), "the Action Buttons boxes still read on to start with")
	db.chatmessages, db.repdetail, db.levelparty, db.levelemote = nil, nil, nil, nil
	AegisPathfinder:RefreshConfigPanel()
	check(frame.switches.chatmessages:IsOn() and frame.boxes.levelemote:IsOn() and not frame.boxes.levelparty:IsOn(),
		"a character without them: messages on, the emote only")
end
check(frame.switches.shownavcallout == nil,
	"our arrow's switch is in the Arrows section, with the others")
check(frame.switches.showminimapbutton ~= nil and frame.switches.showminimapbutton:IsOn(),
	"the minimap button has a switch, on by default")
click(frame.switches.showminimapbutton)
check(db.showminimapbutton == false and AegisPathfinder.__minimapRefreshed,
	"which hides the button at once")

-- Offering the custom zones when a guide finishes: its own switch, in place of
-- "Open custom-zone guides automatically", which nothing ever read.
check(frame.switches.autobranch == nil, "the switch that did nothing is gone")
local offer = frame.switches.offercustomzones
check(offer ~= nil and offer:IsOn(), "the custom-zone offer has a switch, on")
click(offer)
check(db.offercustomzones == false and not offer:IsOn(), "which turns it off")
click(offer)

-- The Active Items, Active Targets and Macros windows: a switch each, on unless the
-- saved setting says otherwise, repainting as they change.
for _, key in ipairs({ "showactiveitems", "showactivetargets", "showmacros", "questicons" }) do
	local sw = frame.switches[key]
	check(sw ~= nil, "%s has a switch", key)
	if sw then
		local before = AegisPathfinder.__activeRefreshed or 0
		click(sw)
		check(db[key] == sw:IsOn(), "%s writes back", key)
		check((AegisPathfinder.__activeRefreshed or 0) == before + 1, "and repaints the windows at once")
	end
end

-- Lock window and Transparency: the guide's ≡ menu settings, on Appearance too.
check(frame.guideLock:GetParent().pageName == "Appearance" and frame.guideTransparent:GetParent().pageName == "Appearance",
	"the guide's lock and transparency are on the Appearance page")
check(not frame.guideLock:IsOn() and not frame.guideTransparent:IsOn(), "both off to start with")
click(frame.guideLock)
check(AegisPathfinder.db.profile.objframelocked == true, "the switch locks the guide, as its menu does")
click(frame.guideTransparent)
check(AegisPathfinder.db.profile.objframetransparent == true, "and makes it see-through")
AegisPathfinder.db.profile.objframelocked = nil              -- unlocked from the menu
AegisPathfinder:RefreshConfigPanel()
check(not frame.guideLock:IsOn() and frame.guideTransparent:IsOn(), "and shows what the menu set")
click(frame.guideTransparent)
-- Asking before inviting the party: the share popup's "don't ask again".
check(frame.askShare:GetParent().pageName == "Step Display" and frame.askShare:IsOn(), "Step Display asks before inviting, by default")
click(frame.askShare)
check(db.sharenowarn == true, "off, it shares without asking")
click(frame.askShare)
check(db.sharenowarn == nil and frame.askShare:IsOn(), "and on, it asks again")
db.sharenowarn = true                                        -- "don't ask again" in the popup
AegisPathfinder:RefreshConfigPanel()
check(not frame.askShare:IsOn(), "the popup's box shows here")
db.sharenowarn = nil
AegisPathfinder:RefreshConfigPanel()

click(frame.waypoints.rows[2])
check(db.waypointprovider == "TomTom", "the waypoint dropdown picks a provider, got %s",
	tostring(db.waypointprovider))

-- Arrows -----------------------------------------------------------------------

--[[ A switch each for ours, TomTom's and pfQuest's: one, some, all or none.
	A character from before the setting had ours on and the waypoint addon's
	too -- two arrows -- and gets ours alone. ]]
local arrows = frame.arrows
check(arrows and arrows.pathfinder and arrows.tomtom and arrows.pfquest, "a switch for each arrow")
check(arrows.pathfinder:IsOn() and not arrows.tomtom:IsOn(), "ours alone by default")
check(not arrows.pfquest:IsOn() and not arrows.pfquest:IsEnabled(),
	"pfQuest not loaded: its switch is held off")
check(string.find(frame.arrowNote:GetText(), "pfQuest is not loaded", 1, true) ~= nil,
	"and the note says why, got '%s'", tostring(frame.arrowNote:GetText()))
AegisPathfinder.__cleared, AegisPathfinder.__resent, AegisPathfinder.__arrowRefreshed = nil, nil, nil
click(arrows.tomtom)
check(db.providerarrow == true and db.shownavcallout == true and arrows.tomtom:IsOn(),
	"TomTom's on, and ours stays: two arrows")
check(AegisPathfinder.__cleared and AegisPathfinder.__resent,
	"re-sending the waypoint so the change takes at once")
check(AegisPathfinder.__arrowRefreshed, "and ours is refreshed too")
check(AegisPathfinder:DescribeArrows() == "Pathfinder, TomTom", "diagnav names both, got %s",
	AegisPathfinder:DescribeArrows())
click(arrows.pathfinder)
check(db.shownavcallout == false and AegisPathfinder:IsArrowOn("tomtom"), "ours off, TomTom's alone")
check(string.find(frame.arrowNote:GetText(), "map pins", 1, true) ~= nil,
	"the note says the pins stay whichever arrow, got '%s'", tostring(frame.arrowNote:GetText()))

-- pfQuest loaded: its switch is pfQuest's own setting, both ways.
pfQuest_config = { arrow = "1" }
local pfArrow = CreateFrame("Frame", nil, UIParent)
pfQuest = { route = { arrow = pfArrow } }
AegisPathfinder:RefreshConfigPanel()
check(arrows.pfquest:IsEnabled() and arrows.pfquest:IsOn(), "pfQuest's switch reads pfQuest's own arrow setting")
click(arrows.pfquest)
check(pfQuest_config.arrow == "0" and not pfArrow:IsShown(), "off, pfQuest's arrow is off in pfQuest, and hidden")
click(arrows.pathfinder)
click(arrows.pfquest)
check(pfQuest_config.arrow == "1" and db.shownavcallout and AegisPathfinder:IsArrowOn("tomtom"),
	"and all three can be on at once")
check(AegisPathfinder:DescribeArrows() == "Pathfinder, TomTom, pfQuest", "got %s", AegisPathfinder:DescribeArrows())
pfQuest_config.arrow = "0"                       -- /db arrow, in pfQuest
AegisPathfinder:RefreshConfigPanel()
check(not arrows.pfquest:IsOn(), "and /db arrow in pfQuest shows here")
pfQuest_config, pfQuest = nil, nil

-- TomTom not loaded: held off, saying so.
tomtomLoaded = false
AegisPathfinder:RefreshConfigPanel()
check(not arrows.tomtom:IsEnabled() and not arrows.tomtom:IsOn(), "TomTom not loaded: held off")
check(string.find(frame.arrowNote:GetText(), "TomTom and pfQuest are not loaded", 1, true) ~= nil,
	"and the note names both missing, got '%s'", tostring(frame.arrowNote:GetText()))
tomtomLoaded = true

-- A provider whose waypoint is its arrow cannot have the arrow taken away.
AegisPathfinder.__provider = { label = "Cartographer", arrowIsWaypoint = true }
AegisPathfinder:RefreshConfigPanel()
check(string.find(frame.arrowNote:GetText(), "Cartographer's waypoint is its arrow", 1, true) ~= nil,
	"and says so for Cartographer, got '%s'", tostring(frame.arrowNote:GetText()))
AegisPathfinder.__provider = { label = "TomTom" }

-- Someone who had turned ours off before the setting existed kept the
-- waypoint addon's arrow, and still does.
db.shownavcallout, db.providerarrow = false, nil
check(AegisPathfinder:IsArrowOn("tomtom") and not AegisPathfinder:IsArrowOn("pathfinder"),
	"an old 'arrow off' keeps TomTom's")
db.shownavcallout, db.providerarrow = true, false
AegisPathfinder:RefreshConfigPanel()

click(frame.rescan)
check(AegisPathfinder.__rescanned, "Rescan progress asks the server")
click(frame.errorlog)
check(AegisPathfinder.__errorlog, "Error log opens the log")

-- A label too long for its line wraps; it does not run off the edge -------------

local long = Theme:Switch(UIParent, string.rep("Pick it for me when quests turn in ", 3))
check(long:Fit(354) > 22 and long.label:GetWidth() == 354 - 45,
	"a long switch label wraps within the row, and the row grows (%s)", tostring(long:GetHeight()))
local short = Theme:Switch(UIParent, "Group mode")
check(short:Fit(354) == 22, "a short one stays one line")
for key, sw in pairs(frame.advisor) do
	check(sw.label:GetWidth() == sw:GetWidth() - 45, "the %s switch's label stops at the row's edge", key)
end
check(frame.switches.questicons.label:GetWidth() == frame.switches.questicons:GetWidth() - 45,
	"and the quest icons one")

-- The resize grip ---------------------------------------------------------------

check(frame.grip ~= nil and frame.grip:GetScript("OnMouseDown") ~= nil, "the window has a resize grip")
local _, _, gripPoint = frame.grip:GetPoint()
check(gripPoint == "BOTTOMRIGHT", "in its bottom right corner")
click(navNamed("Gear"))                   -- the long page
local _, gearRange = frame.scrollbar:GetMinMaxValues()
stub.cursor, stub.mouseDown = { 500, 300 }, true
fire(frame.grip, "OnMouseDown")
stub.cursor = { 600, 200 }                -- 100 right, 100 down
fire(frame.grip, "OnUpdate")
check(frame:GetWidth() == 546 + 100 and frame:GetHeight() == 560 + 100,
	"dragging it right and down makes the window wider and taller, got %sx%s", frame:GetWidth(), frame:GetHeight())
local _, tallerRange = frame.scrollbar:GetMinMaxValues()
-- At least that much less: wider, what wraps takes fewer lines too.
check(gearRange > 0 and tallerRange <= math.max(0, gearRange - 100) and not frame.scrollbar:IsShown() == (tallerRange == 0),
	"the page scrolls at least that much less, or not at all (%s from %s)", tallerRange, gearRange)
check(frame.holder:GetWidth() == frame.bodyW and frame.bodyW == 396 - 28 - 10 - 4 + 100,
	"the pane widens with it, got %s", tostring(frame.bodyW))
check(frame.advisor.enabled:GetWidth() == frame.bodyW and frame.sections[1]:GetWidth() == frame.bodyW,
	"and what is on it: switches and section rules")
check(frame.race:GetWidth() == frame.bodyW and frame.race.list:GetWidth() == frame.bodyW, "dropdowns and their lists")
check(AegisPathfinder.itemscorepage.share:GetWidth() == frame.bodyW - 206 - 16,
	"and the Item Score page's share column, out to the new edge")
stub.mouseDown = false
fire(frame.grip, "OnUpdate")
check(frame.grip.sizing == nil, "letting go ends it")
check(AegisPathfinder.db.profile.optionswidth == 646 and AegisPathfinder.db.profile.optionsheight == 660,
	"and the size is kept for next time")
AegisPathfinder:SizeConfigWindow(100, 100, true)
check(frame:GetWidth() == 546 and frame:GetHeight() == 360, "never narrower than it opens, nor very short")
AegisPathfinder:SizeConfigWindow(5000, 5000)
check(frame:GetWidth() == 1024 - 40 and frame:GetHeight() == 768 - 40, "nor bigger than the screen")
AegisPathfinder:SizeConfigWindow()
check(frame:GetWidth() == 546 and frame:GetHeight() == 560 and frame.bodyW == 396 - 28 - 10 - 4,
	"and back to its first size")

-- A label that wraps at one width and not at another: the rows under it
-- follow, rather than leaving a gap.
local pick, border = frame.advisor.questpick, frame.advisor.bagmark
local stringWidth = pick.label.GetStringWidth
pick.label.GetStringWidth = function() return frame.bodyW - 45 - 4 end   -- just fits
check(pick:Fit(frame.bodyW) == 22, "a label that just fits is one line, not counted as two")
pick.label.GetStringWidth = function() return 400 end   -- too long for the first width
AegisPathfinder:SizeConfigWindow(546, 560)
AegisPathfinder:SizeConfigWindow(547, 560)             -- a new width: laid out again
local _, _, _, _, pickY = pick:GetPoint()
local _, _, _, _, borderY = border:GetPoint()
check(pick:GetHeight() > 22 and borderY == pickY - pick:GetHeight() - 6,
	"wrapped, it is taller and the next row sits under it (%s, %s, %s)", pickY, pick:GetHeight(), borderY)
AegisPathfinder:SizeConfigWindow(546 + 200, 560)
local _, _, _, _, pickY2 = pick:GetPoint()
local _, _, _, _, borderY2 = border:GetPoint()
check(pick:GetHeight() == 22 and borderY2 == pickY2 - 22 - 6,
	"wider, it is one line and the next row moves up to it (%s, %s)", pickY2, borderY2)
local gearPage = pageNamed("Gear")
local lowest = 0
for _, e in ipairs(gearPage.flow) do
	if e.region then
		local _, _, _, _, ry = e.region:GetPoint()
		if ry < lowest then lowest = ry end
	end
end
check(gearPage.contentHeight > -lowest, "the page's height follows")
pick.label.GetStringWidth = stringWidth
AegisPathfinder:SizeConfigWindow()
click(frame.navButtons[1])

-- The route preview takes the room down to the foot of the window, and
-- more as the window is made taller: the route, not empty panel.
local preview, routePage = frame.preview, frame.pages[1]
local opened = preview.visibleRows
check(opened > 7, "the preview fills the Route page, more than its old seven rows, got %d", opened)
check(routePage.contentHeight <= frame.visible, "and the page still fits without scrolling (%s of %s)",
	tostring(routePage.contentHeight), tostring(frame.visible))
AegisPathfinder:SizeConfigWindow(546, 700)
check(preview.visibleRows == opened + 7, "140 taller, it shows seven rows more, got %d from %d", preview.visibleRows, opened)
check(routePage.contentHeight <= frame.visible, "and still fits")
local legs = table.getn(preview.entries)
local shown = 0
for _, row in ipairs(preview.rows) do if row:IsShown() then shown = shown + 1 end end
check(shown == math.min(legs, preview.visibleRows), "as many rows shown as fit or as the route has, got %d", shown)
AegisPathfinder:SizeConfigWindow()
check(preview.visibleRows == opened, "and back to what it opened with")

-- Credits ---------------------------------------------------------------------

--[[ Credits are a button on the About page, not a slash command that printed
	into chat. ]]
local last = frame.sections[table.getn(frame.sections)]
check(last.label:GetText() == "ABOUT", "the last section is About, got %s",
	tostring(last.label:GetText()))
check(last:GetParent().pageName == "About" and frame.credits:GetParent() == last:GetParent(),
	"on the About page, with the Credits button")
check(frame.credits ~= nil and frame.credits.label:GetText() == "CREDITS",
	"with a Credits button in it")
local _, _, _, _, lastY = last:GetPoint()
local _, _, _, _, buttonY = frame.credits:GetPoint()
check(buttonY < lastY, "under the About header, at the bottom of the panel")
check(AegisPathfinder.PrintCredits == nil, "the chat printout is gone")

check(AegisPathfinder.creditsframe == nil, "the credits window is built on first use")
frame:ClearAllPoints()
frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 300, -100)
AegisPathfinder.objectiveframe:ClearAllPoints()
AegisPathfinder.objectiveframe:SetWidth(400)
AegisPathfinder.objectiveframe:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 704, -100)
click(frame.credits)
local credits = AegisPathfinder.creditsframe
check(credits ~= nil and credits:IsShown(), "clicking the button opens the credits")
check(AegisPathfinder.Theme:IsWindow(credits), "a stacked window like every other")
check(credits.subhead.label:GetText() == "CREDITS", "wearing the same chrome")
fire(credits, "OnShow")
check(credits:GetRight() == frame:GetLeft() - 8,
	"opening beside the options panel, away from the guide (right %s, options left %s)",
	tostring(credits:GetRight()), tostring(frame:GetLeft()))

check(table.getn(credits.sections) == table.getn(AegisPathfinder.creditsData),
	"one section per heading in Credits.lua, got %d", table.getn(credits.sections))
for i, section in ipairs(AegisPathfinder.creditsData) do
	check(credits.sections[i].label:GetText() == string.upper(section[1]),
		"section %d is %s, got %s", i, section[1], tostring(credits.sections[i].label:GetText()))
end
local found = false
for _, r in ipairs(credits.body.__regions) do
	local t = r.GetText and r:GetText()
	if t and string.find(t, "Tekkub", 1, true) and string.find(t, "TourGuide", 1, true) then
		found = string.find(t, "|cffffffffTekkub|r", 1, true) ~= nil
	end
end
check(found, "each credit names its person in white, then what they did")

click(frame.credits)
check(not credits:IsShown(), "the button closes them again")
click(frame.credits)
fire(frame, "OnHide")
check(not credits:IsShown(), "and they close with the options panel")

-- Report ---------------------------------------------------------------------

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end

print(string.format("Options: %d checks", checks))
if table.getn(failures) == 0 then
	print("All options checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
