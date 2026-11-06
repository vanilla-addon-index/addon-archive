--[[ OptionsFrame.lua -- the concept's #options panel, in pages.

	Categories down the left, as Zygor's options have them; the page picked
	on the right, scrolling when it is taller than the window. The pages hold
	the concept's sections, in the concept's order:

	  Race          a dropdown of your faction's races
	  Route pack    pills, with a preview of the route underneath
	  Dungeons      the chip grid
	  Filters       group mode, Auction House steps and Solo Self-Found
	  Server theme  a dropdown: the colours of your server, or Day or Night

	That is the concept. It used to be a menu of buttons that opened the
	dungeons, the filters and the route picker as three more windows; all of
	that lives here now, in the concept's language.

	The concept has no home for the addon's own behaviour settings, the item
	score, the waypoint provider or the maintenance actions, so they follow as
	more sections in the same style -- the substitution is the extra sections, not
	a different look.

	The pages after Filters follow Zygor's, in this style; Behaviour was
	spread over Step Display, Automation and Action Buttons, every setting
	keeping its saved value.

	  Route           Race, Route pack
	  Dungeons        Dungeons, Turtle WoW's own, Along the way
	  Filters         Filters
	  Appearance      Server theme and switch colours, window scale, the guide
	                  window (lock, transparency), the minimap button
	  Step Display    Between guides, Sync & Share
	  Automation      Quests
	  Action Buttons  the Active Items, Active Targets and Macros windows,
	                  quest icons
	  Navigation      Waypoints, Arrows
	  Gear            the item score, the Gear Advisor, the Gear Finder
	    Item Score    the stat weights (GearFrame.lua), listed under Gear
	  Maintenance     Maintenance
	  About           About, Credits
]]

local AegisPathfinder = AegisPathfinder
local Theme = AegisPathfinder.Theme

-- Concept geometry: .panel{width:396px}, .options-body{padding:12px 14px 16px},
-- section{margin-bottom:16px}.
-- The pane keeps the concept's 396px; the category list sits beside it.
local PANE_W, HEIGHT = 396, 560
local NAV_W, NAV_ROW_H = 150, 30
local WIDTH = PANE_W + NAV_W
local HEADER_H, SUBHEAD_H = 30, 18
local CHROME_TOP = HEADER_H + SUBHEAD_H
local PAD_X, PAD_TOP, PAD_BOTTOM = 14, 12, 16
local SCROLL_W = 10
local BODY_W = PANE_W - PAD_X * 2 - SCROLL_W - 4
local SECTION_GAP = 16
local MIN_HEIGHT = 360                -- the grip goes no shorter; never narrower than WIDTH
local HEADER_GAP = 7                  -- h3 margin-bottom

-- The dungeon grid: four across in a 396px panel.
local CHIP_COLS, CHIP_GAP, CHIP_H = 4, 6, 34
local CHIP_W = math.floor((BODY_W - (CHIP_COLS - 1) * CHIP_GAP) / CHIP_COLS)

-- The Gear Finder's upgrade sources: two boxes to a row, three rows.
local SOURCE_COL, SOURCE_ROW = 170, 26
local SOURCES_H = 17 + 3 * SOURCE_ROW

--[[ Turtle WoW's own dungeons, at InstanceJournal's levels. No route guide
	has steps for them, so the first-time setup does not offer them; the
	Dungeons page does. Ticked, their dungeon guides (Guides/Dungeons/, under
	these names) can be offered along the way. The Gear Finder looks in them
	ticked or not: its Upgrade sources decide where it looks. ]]
AegisPathfinder.TURTLE_DUNGEON_INFO = {
	{ code = "FH",  name = "Frostmane Hollow",   lo = 13, hi = 20 },
	{ code = "WHC", name = "Windhorn Canyon",    lo = 26, hi = 30 },
	{ code = "DMR", name = "Dragonmaw Retreat",  lo = 26, hi = 35 },
	{ code = "SWR", name = "Stormwrought Ruins", lo = 32, hi = 44 },
	{ code = "CG",  name = "Crescent Grove",     lo = 33, hi = 39 },
	{ code = "GC",  name = "Gilneas City",       lo = 43, hi = 52 },
	{ code = "HQ",  name = "Hateforge Quarry",   lo = 51, hi = 60 },
}

-- The route preview: .route-preview{max-height:150px}, rows of about 20px.
local PREVIEW_ROWS, PREVIEW_ROW_H = 7, 20
local PREVIEW_H = PREVIEW_ROWS * PREVIEW_ROW_H + 8

local DUNGEONS = {
	{ code = "RFC",       name = "Ragefire Chasm" },
	{ code = "WC",        name = "Wailing Caverns" },
	{ code = "DM",        name = "Deadmines" },
	{ code = "SFK",       name = "Shadowfang Keep" },
	{ code = "BFD",       name = "Blackfathom Deeps" },
	{ code = "STOCKADES", name = "The Stockade" },
	{ code = "GNOMER",    name = "Gnomeregan" },
	{ code = "RFK",       name = "Razorfen Kraul" },
	{ code = "SM",        name = "Scarlet Monastery" },
	{ code = "RFD",       name = "Razorfen Downs" },
	{ code = "ULDA",      name = "Uldaman" },
	{ code = "ZF",        name = "Zul'Farrak" },
	{ code = "MARA",      name = "Maraudon" },
	{ code = "ST",        name = "Sunken Temple" },
	{ code = "BRD",       name = "Blackrock Depths" },
}

-- Races each faction can be routed as. The value is the route name the
-- route packs are keyed by.
local RACES = {
	Alliance = {
		{ label = "Human",     route = "Human" },
		{ label = "Dwarf",     route = "Dwarf" },
		{ label = "Night Elf", route = "NightElf" },
		{ label = "Gnome",     route = "Gnome" },
		{ label = "High Elf",  route = "HighElf" },
	},
	Horde = {
		{ label = "Orc",    route = "Orc" },
		{ label = "Troll",  route = "Troll" },
		{ label = "Tauren", route = "Tauren" },
		{ label = "Undead", route = "Undead" },
		{ label = "Goblin", route = "Goblin" },
	},
}

--- How tall fine print is at `width`: what the client says, or, where it says
--- less, the lines its unwrapped width needs -- a wrapped font string's own
--- height is not to be trusted on 1.12. Slack for where the words break.
local function TextHeight(fs, width)
	local sw = fs:GetStringWidth() or 0
	local lines = sw <= width and 1 or math.ceil(sw / (width * 0.9))
	return math.max(fs:GetHeight() or 0, lines * 13)
end

--- Lay a page out again at `width`, from what `place` remembered: what wraps
--- takes its new height and everything under it moves up or down to suit.
local function Reflow(p, width)
	local y = 0
	for _, e in ipairs(p.flow) do
		if e.region then
			e.region:ClearAllPoints()
			e.region:SetPoint("TOPLEFT", p, "TOPLEFT", e.indent or 0, -y)
			y = y + (type(e.height) == "function" and e.height(width) or e.height)
		end
		y = y + e.gap
	end
	-- The Item Score page's list sets its own height.
	if not p.ownHeight then
		p.contentHeight = y + PAD_BOTTOM
		p:SetHeight(p.contentHeight)
	end
end

--- A row of the route preview: level range and zone.
local function PreviewRow(preview, i)
	local row = CreateFrame("Frame", nil, preview)
	row:SetHeight(PREVIEW_ROW_H)
	row:SetPoint("TOPLEFT", preview, "TOPLEFT", 10, -(4 + (i - 1) * PREVIEW_ROW_H))
	row:SetPoint("RIGHT", preview, "RIGHT", -10, 0)
	row.lvl = row:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(row.lvl, "body2", 11)
	row.lvl:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.lvl:SetWidth(52)
	row.lvl:SetJustifyH("LEFT")
	Theme:TextColor(row.lvl, "accent")
	row.zone = row:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(row.zone, "body", 11)
	row.zone:SetPoint("LEFT", row.lvl, "RIGHT", 8, 0)
	row.zone:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	row.zone:SetJustifyH("LEFT")
	Theme:TextColor(row.zone, "textDim")
	return row
end

--- Reload whichever guide is on screen so a filter change takes effect.
local function ReloadCurrentGuide()
	local self = AegisPathfinder
	if self:HasNoGuide() then return end
	self:LoadGuide(self.db.char.currentguide)
	self:UpdateStatusFrame()
end

--[[ The pages laid out along Zygor's -- Appearance's guide settings, Step
	Display, Automation, Action Buttons, Maps -- built from the layout kit
	CreateConfigPanel hands them (`k`): its page, place, section, note and
	space, the page being built (k.body()) and the window (k.frame). They are
	out here so that function stays inside Lua 5.0's limits on locals and
	upvalues. ]]
local Build = {}

-- How far a switch that belongs to the one above it sits in under it.
local SUB_INDENT = 24

--- A switch for a per-character setting, db.char[key], kept in frame.switches
--- for RefreshConfigPanel; `after(on)` updates whatever it shows on screen.
--- `opts`: `parent`, the key of the switch it sits in under and is held off
--- with; `defaultOn`, read as on until it is switched off (a setting older
--- characters do not have yet).
function Build.CharSwitch(k, key, label, after, opts)
	opts = opts or {}
	local store = opts.profile and "profile" or "char"
	local sw = Theme:Switch(k.body(), label, function(on)
		AegisPathfinder.db[store][key] = on
		if after then after(on) end
	end)
	sw.settingKey, sw.defaultOn = key, opts.defaultOn
	local indent = opts.parent and SUB_INDENT or nil
	k.place(sw, function(w) return sw:Fit(w - (indent or 0)) end, 8, indent)
	local list = opts.profile and k.frame.pswitches or k.frame.switches
	list[key] = sw
	if opts.parent then (opts.profile and k.frame.psubSwitches or k.frame.subSwitches)[key] = opts.parent end
	return sw
end

--- The same for a setting kept per profile: db.profile[key], in frame.pswitches.
function Build.ProfileSwitch(k, key, label, after, opts)
	opts = opts or {}
	opts.profile = true
	return Build.CharSwitch(k, key, label, after, opts)
end

local function Percent(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end

--- A slider written as a percentage; `indent` sets it in under the row above.
function Build.Slider(k, label, lo, hi, step, onChange, indent)
	local row = Theme:Slider(k.body(), label, lo, hi, step, onChange, Percent)
	k.place(row, function(w) return row:Fit(w - (indent or 0)) end, 6, indent)
	return row
end

--- Hold a slider or a dropdown's row off, as a switch is held: dimmed, and
--- not to be dragged or opened.
function Build.Hold(row, held)
	row:SetAlpha(held and 0.45 or 1)
	local control = row.slider or row.dropdown
	control:EnableMouse(not held)
	if held and control.list then control.list:Hide() end
end

--- A line of body text over the control it names.
function Build.Label(k, text)
	local fs = k.body():CreateFontString(nil, "OVERLAY")
	Theme:SetFont(fs, "body", 13)
	Theme:TextColor(fs, "text")
	fs:SetJustifyH("LEFT")
	fs:SetText(text)
	k.place(fs, 16, 6)
	return fs
end

--- A switch whose setting has its own setter (`set(on)`), kept as frame[name].
function Build.Switch(k, name, label, set, indent)
	local sw = Theme:Switch(k.body(), label, function(on) set(on) end)
	k.place(sw, function(w) return sw:Fit(w - (indent or 0)) end, 8, indent)
	k.frame[name] = sw
	return sw
end

local function RefreshActive() AegisPathfinder:RefreshActiveFrames() end

--- Appearance, after the theme and the scale: the guide window, and the
--- minimap button.
function Build.AppearanceGuide(k)
	local A = AegisPathfinder
	local f = k.frame
	k.section("Guide window")
	-- The same settings as the guide's ≡ menu has, and kept in step with it.
	Build.Switch(k, "guideLock", "Lock window", function(on) A:SetGuideLocked(on) end)
	Build.Switch(k, "guideTransparent", "Transparency", function(on)
		A:SetGuideTransparent(on)
		A:RefreshConfigPanel()
	end)
	f.guideOpacity = Build.Slider(k, "Guide window opacity", 0.2, 1, 0.05, function(v) A:SetGuideOpacity(v) end,
		SUB_INDENT)
	f.browserOpacity = Build.Slider(k, "Guide browser opacity", 0.4, 1, 0.05, function(v) A:SetBrowserOpacity(v) end)
	f.textSize = Build.Slider(k, "Step text size", 0.8, 1.4, 0.05, function(v) A:SetStepTextSize(v) end)
	Build.Switch(k, "guideProgress", "Show the progress bar", function(on) A:SetGuideProgressShown(on) end)
	Build.Switch(k, "guideUpward", "Grow upward from where I put it", function(on) A:SetGuideUpward(on) end)
	k.note("Growing upward suits a guide at the bottom of the screen: its bottom edge stays where "
		.. "you left it. Lock window and Transparency are in the menu at the guide's top left too.")
	k.space(k.SECTION_GAP)
	k.section("Hiding the guide")
	Build.ProfileSwitch(k, "hideininstance", "Hide the guide in dungeons and raids", function() A:RefreshConfigPanel() end)
	Build.ProfileSwitch(k, "showafterinstance", "Show it again when I leave", nil,
		{ parent = "hideininstance", defaultOn = true })
	Build.ProfileSwitch(k, "hideincombat", "Hide the guide in combat", function() A:RefreshConfigPanel() end)
	Build.ProfileSwitch(k, "hidebuttonscombat", "Hide the action buttons in combat too", nil, { parent = "hideincombat" })
	k.space(k.SECTION_GAP - 8)
	k.section("Minimap")
	Build.CharSwitch(k, "showminimapbutton", "Minimap button", function() A:UpdateMinimapButton() end)
	k.space(k.SECTION_GAP - 8)
end

-- Whose lines a dungeon guide's boss steps show.
local DUNGEON_ROLES = { { value = "all", label = "All roles" }, { value = "tank", label = "Tank" },
	{ value = "heal", label = "Healer" }, { value = "dps", label = "Damage" } }

local FOCUS_STEPS = { { value = 1, label = "1 (the step you are on)" }, { value = 2, label = "2" },
	{ value = 3, label = "3" }, { value = 4, label = "4" }, { value = 5, label = "5" } }

--- Step Display: how many steps, which to skip, what comes between guides,
--- and sharing with your party.
function Build.StepDisplay(k)
	local A = AegisPathfinder
	k.page("Step Display")
	k.section("Steps")
	Build.CharDropdown(k, "focusSteps", "Steps shown in focus mode", "focussteps", FOCUS_STEPS, function()
		if A.OnObjectiveFrameResized and A.objectiveframe and A.objectiveframe.footer then
			A:OnObjectiveFrameResized()
			A:UpdateOHPanel()
		end
	end)
	k.note("Up to five: the step you are on and the ones after it. Overview still shows the whole guide.")
	k.space(10)
	Build.CharSwitch(k, "skiphearth", "Skip setting my hearthstone", ReloadCurrentGuide)
	Build.CharSwitch(k, "skipflightpaths", "Skip discovering new flight paths", ReloadCurrentGuide)
	k.note("A later step may still say to hearth or fly there: it is not rewritten.")
	k.space(k.SECTION_GAP)
	k.section("Between guides")
	Build.CharSwitch(k, "skipfollowups", "Skip suggested follow-ups")
	Build.CharSwitch(k, "offercustomzones", "Offer custom zones between guides")
	Build.CharSwitch(k, "classquests", "Offer class quests at their level")
	k.space(k.SECTION_GAP - 8)
	k.section("Sync & Share")
	Build.CharSwitch(k, "partysync", "Party sync", function(on)
		if not on and A.shareState and A.shareState.active then A:StopSharing(true) end
		if A.PaintShareButton then A:PaintShareButton() end
		A:RefreshConfigPanel()
	end, { defaultOn = true })
	-- The share popup's "don't ask again", as a setting you can take back.
	Build.Switch(k, "askShare", "Ask before inviting my party", function(on)
		AegisPathfinder.db.char.sharenowarn = not on or nil
	end, SUB_INDENT)
	k.note("The party icon on the step row, and invitations from your party to share their guide.")
	k.space(k.SECTION_GAP)
end

--- Automation: what the addon does for you. It replaced Behaviour.
function Build.Automation(k)
	local A = AegisPathfinder
	k.page("Automation")
	k.section("Quests")
	Build.CharSwitch(k, "autoquest", "Accept and turn in the guide's quests", function() A:RefreshConfigPanel() end)
	Build.CharSwitch(k, "allquests", "All quests, not only the guide's", nil, { parent = "autoquest" })
	Build.CharSwitch(k, "autogossip", "Pick the guide's quest from an NPC's list", nil,
		{ parent = "autoquest", defaultOn = true })
	Build.CharSwitch(k, "trackquests", "Track quests automatically")
	k.note("Hold Shift as you talk to an NPC and nothing happens by itself. All quests takes "
		.. "no grey quests, and leaves two places in your quest log for the guide's.")
	k.space(k.SECTION_GAP)
	k.section("Travel")
	Build.CharSwitch(k, "autofly", "Take the step's flight when I open the flight master's map")
	k.space(k.SECTION_GAP - 8)
	k.section("Inventory")
	Build.CharSwitch(k, "autobuy", "Buy what the step says to buy, at its vendor", nil, { defaultOn = true })
	k.note("Only for steps that name the item and how many, and only as many as you still need.")
	k.space(10)
	Build.CharSwitch(k, "sellbutton", "\"Sell greys\" button on the vendor window", function()
		if A.Automation then A.Automation:PlaceButton() end
	end, { defaultOn = true })
	Build.CharSwitch(k, "autosell", "Sell greys automatically")
	Build.Label(k, "Repair automatically")
	local repair = Theme:Dropdown(k.body(), k.BODY_W, function(v) A.db.char.autorepair = v end)
	repair:SetItems({ { value = "off", label = "Don't repair" }, { value = "own", label = "With my own money" } })
	k.place(repair, 30, 6)
	k.wide(repair)
	k.frame.repair = repair
	table.insert(k.frame.lateDropdowns, repair)
	k.note("1.12 has no guild bank, so there is no repairing with guild money.")
	k.space(k.SECTION_GAP)
end

--- A named dropdown of `items` for db.char[key], kept as frame[name].
function Build.CharDropdown(k, name, label, key, items, after)
	Build.Label(k, label)
	local d = Theme:Dropdown(k.body(), k.BODY_W, function(v)
		AegisPathfinder.db.char[key] = v
		if after then after(v) end
	end)
	d:SetItems(items)
	d.settingKey = key
	k.place(d, 30, 8)
	k.wide(d)
	k.frame[name] = d
	table.insert(k.frame.lateDropdowns, d)
	return d
end

-- The box grid's geometry: two to a row.
local BOX_COL, BOX_ROW = 170, 26

--- A label over boxes, two to a row, each a per-character setting that is on
--- until it is unticked -- or off until ticked, with `true` as its third
--- field; kept in frame.boxes for RefreshConfigPanel.
function Build.Boxes(k, label, defs, after)
	local rows = math.ceil(table.getn(defs) / 2)
	local h = 17 + rows * BOX_ROW
	local holder = CreateFrame("Frame", nil, k.body())
	holder:SetHeight(h)
	holder:SetWidth(k.BODY_W)
	local fs = holder:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(fs, "body", 13)
	Theme:TextColor(fs, "text")
	fs:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
	fs:SetText(label)
	for i, def in ipairs(defs) do
		local key = def[1]
		local box = Theme:Checkbox(holder, def[2], function(on)
			AegisPathfinder.db.char[key] = on
			if after then after(on) end
		end)
		box:Fit()
		box:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", math.mod(i - 1, 2) * BOX_COL, -(4 + math.floor((i - 1) / 2) * BOX_ROW))
		box.defaultOff = def[3]
		k.frame.boxes[key] = box
	end
	k.place(holder, h, 4)
	return holder
end

local GROWTH = { { value = "right", label = "Right" }, { value = "left", label = "Left" },
	{ value = "up", label = "Up" }, { value = "down", label = "Down" } }

--- Action Buttons: the windows of buttons that hang under the guide.
function Build.ActionButtons(k)
	local A = AegisPathfinder
	k.page("Action Buttons")
	k.section("Windows")
	Build.CharSwitch(k, "showactiveitems", "Active items window", RefreshActive)
	Build.CharSwitch(k, "showactivetargets", "Active targets window", RefreshActive)
	Build.CharSwitch(k, "showmacros", "Macros window (AegisTarget, AegisItem)", RefreshActive)
	Build.CharSwitch(k, "questicons", "Quest icons: mark quest NPCs as you mouse over them", RefreshActive)
	k.space(k.SECTION_GAP - 8)
	k.section("Layout")
	Build.CharDropdown(k, "itemsGrow", "Active items grow", "itemsgrow", GROWTH,
		function(v) A:SetActiveGrowth("items", v) end)
	Build.CharDropdown(k, "targetsGrow", "Active targets grow", "targetsgrow", GROWTH,
		function(v) A:SetActiveGrowth("targets", v) end)
	local size = Theme:Slider(k.body(), "Button size", 0.6, 1.5, 0.05, function(v)
		A.db.char.buttonscale = v
		A:ApplyButtonScale()
	end, function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end)
	k.place(size, function(w) return size:Fit(w) end, 6)
	k.frame.buttonSize = size
	k.note("A window you have dragged grows from the matching corner, where you left it; until "
		.. "then it hangs under the guide. The size is on top of the window scale.")
	k.space(k.SECTION_GAP)
	k.section("Buttons")
	Build.Boxes(k, "Buttons to show", { { "btnitems", "Quest items" }, { "btntalk", "Talk to NPC" },
		{ "btnkill", "Kill enemy" }, { "btndelete", "Delete cheapest item" } }, RefreshActive)
	k.note("Delete cheapest item appears when your bags are full: the cheapest grey first, and it "
		.. "asks before deleting anything that is not grey. 1.12 does not say what vendors pay, so "
		.. "the prices are the CMaNGOS database's; Turtle WoW's own items are offered only when grey.")
	k.space(10)
	Build.CharSwitch(k, "raidmark", "Mark whoever the target buttons target", nil, { defaultOn = true })
	k.note("A star to talk, a square to interact, a skull to kill, a cross to loot. Off, the "
		.. "buttons only target. Quest icons mark by themselves either way.")
	k.space(k.SECTION_GAP)
end

local TRAIL_STYLES = { { value = "dots", label = "Dots" }, { value = "dashes", label = "Dashes" } }
local SMALL_DROPDOWN_W = 140

--- A short dropdown for db.profile[key] with its label beside it, set in under
--- the switch above; the row is kept as frame[name], its dropdown as
--- row.dropdown.
function Build.ProfileDropdown(k, name, label, key, items, after)
	local row = CreateFrame("Frame", nil, k.body())
	row:SetHeight(30)
	row:SetWidth(k.BODY_W - SUB_INDENT)
	local fs = row:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(fs, "body", 13)
	Theme:TextColor(fs, "text")
	fs:SetPoint("LEFT", row, "LEFT", 0, 0)
	fs:SetText(label)
	local d = Theme:Dropdown(row, SMALL_DROPDOWN_W, function(v)
		AegisPathfinder.db.profile[key] = v
		if after then after(v) end
	end)
	d:SetPoint("LEFT", fs, "RIGHT", 10, 0)
	d:SetItems(items)
	row.dropdown = d
	k.place(row, 30, 8, SUB_INDENT)
	k.frame[name] = row
	table.insert(k.frame.lateDropdowns, d)
	return row
end

--- Maps: what Pathfinder draws on the world map and the minimap (Maps.lua).
function Build.Maps(k)
	local A = AegisPathfinder
	local function redraw() if A.Maps then A.Maps:Refresh() end end
	local function redrawAndHold()
		redraw()
		A:RefreshConfigPanel()
	end
	k.page("Maps")
	k.section("World map")
	Build.ProfileSwitch(k, "mapreveal", "Reveal the whole map", redraw, { defaultOn = true })
	k.note("Places you have not been are drawn a little dimmer. Held off while pfUI's own map "
		.. "reveal is on, or Cartographer or MetaMap's fog of war draws them.")
	k.space(10)
	Build.ProfileSwitch(k, "mapmarkers", "Show the step on the map: quest givers, hand-ins and kill areas",
		redraw, { defaultOn = true })
	k.note("Quest givers, hand-ins and kill areas come from pfQuest; without it, only the place "
		.. "the step's note gives. On the zone you are looking at.")
	k.space(k.SECTION_GAP)
	k.section("Ant trail")
	Build.ProfileSwitch(k, "anttrail", "A trail from me to the waypoint", redrawAndHold, { defaultOn = true })
	Build.ProfileDropdown(k, "antStyle", "Style", "antstyle", TRAIL_STYLES, redraw)
	k.note("On the world map, in the theme's colour, when you and the waypoint are in the zone it "
		.. "shows. On the minimap too when Astrolabe is loaded (TomTom-TWOW brings it).")
	k.space(k.SECTION_GAP)
	k.section("Points of interest")
	Build.ProfileSwitch(k, "maprares", "Rare creatures near my level", redrawAndHold)
	k.frame.rareSize = Build.Slider(k, "Icon size", 0.6, 1.6, 0.1, function(v)
		A.db.profile.raresize = v
		redraw()
	end, SUB_INDENT)
	Build.ProfileSwitch(k, "raresseethru", "See-through icons", redraw, { parent = "maprares" })
	k.note("From pfQuest-turtle's database: 293 rares and 147 rare elites, shown within four "
		.. "levels of yours. Where they can spawn, not whether one is up.")
	k.space(k.SECTION_GAP)
end

--- Extras: what the addon says in chat (Extras.lua, and Say in Core.lua).
function Build.Extras(k)
	k.page("Extras")
	k.section("Chat")
	Build.CharSwitch(k, "chatmessages", "Show Pathfinder chat messages", nil, { defaultOn = true })
	k.note("Off, the routine lines stay out of your chat: the load message, flights taken, greys "
		.. "sold, upgrades put on, guides handed over. Errors, warnings and replies to what you "
		.. "click or type still show.")
	k.space(10)
	Build.CharSwitch(k, "repdetail", "Show detailed reputation gains")
	k.note("When a reputation goes up, where it stands and how far it is to the next rank: "
		.. "\"Stormwind +25: Honored 4,350 / 12,000, 7,650 to Revered\".")
	k.space(k.SECTION_GAP)
	k.section("Level-ups")
	Build.Boxes(k, "Announce level-ups to:", { { "levelemote", "Emote" }, { "levelparty", "Party chat", true },
		{ "levelguild", "Guild chat", true } })
	k.note("The emote, on to start with, reads \"<you> Pathfinder: I just leveled up from 22 to "
		.. "23! (2 hours 1 minute)\"; your party and guild, once ticked, get \"Pathfinder: I leveled "
		.. "up from 22 to 23! (2 hours 1 minute)\". The time is how long you spent at the level, "
		.. "when the guide counted all of it. Nothing goes to a party or guild you are not in.")
	k.space(k.SECTION_GAP)
	Build.TalentAdvisor(k)
end

--- The Talent Advisor (TalentAdvisor.lua, TalentWindow.lua), on Extras.
function Build.TalentAdvisor(k)
	local A = AegisPathfinder
	local function redraw()
		if A.TalentAdvisor then A.TalentAdvisor:Refresh() end
	end
	k.section("Talent Advisor")
	Build.CharSwitch(k, "talentadvisor", "Talent Advisor: mark where my points go on the talent window", function()
		redraw()
		A:RefreshConfigPanel()
	end, { defaultOn = true })
	Build.CharDropdown(k, "talentBuild", "Build to follow", "talentbuild",
		A.TalentAdvisor and A.TalentAdvisor:BuildItems() or {}, redraw)
	k.note("Your spec is the one picked on the Item Score page, or the one your talents lean to. "
		.. "Until 60 it follows your class's leveling build, and at 60 it says when your spec's is "
		.. "ready for a respec. Pick another here or above the talent window. It never spends a point.")
	k.space(10)
	Build.CharSwitch(k, "talentchat", "Name the talent to take in chat when I level up", nil,
		{ parent = "talentadvisor", defaultOn = true })
	Build.CharSwitch(k, "talentnudge", "Point out a talent point: a card when I level up, and the talents button lit",
		redraw, { parent = "talentadvisor", defaultOn = true })
	k.note("With Modern Spellbook's talent window, the advisor marks it the same way, and saves its builds "
		.. "as Modern Spellbook plans for its Apply. Share there gives a build as its string, and follows one.")
	local open = Theme:Pill(k.body(), "Open the talent window", 170, 26)
	open:SetScript("OnClick", function()
		if A.TalentAdvisor then A.TalentAdvisor:OpenWindow() end
	end)
	k.place(open, 26, 6)
	k.frame.openTalents = open
	k.space(k.SECTION_GAP)
end

function AegisPathfinder:CreateConfigPanel()
	local frame = CreateFrame("Frame", "AegisPathfinderOptions", UIParent)
	self.optionsframe = frame
	frame:SetFrameStrata("DIALOG")
	frame:SetWidth(WIDTH)
	frame:SetHeight(HEIGHT)
	-- .#options sits left of #objectives in the concept (right:456px against
	-- right:40px), so it opens beside the guide rather than over it.
	frame:SetPoint("TOPRIGHT", AegisPathfinder.objectiveframe, "TOPLEFT", -8, 0)
	Theme:Panel(frame, "panel")
	frame:Hide()

	Theme:Chrome(frame, "Config", Theme:PositionSaver("optionsframe"))

	-- The concept's header carries a ☰ on the left of this window too, titled
	-- "Back". Here it brings the guide forward.
	local back = Theme:ChipButton(frame.header, "menu")
	back:SetPoint("LEFT", frame.header, "LEFT", 8, 0)
	back:SetScript("OnClick", function()
		if not AegisPathfinder.objectiveframe:IsShown() then
			AegisPathfinder.objectiveframe:Show()
		end
	end)
	back:SetScript("OnEnter", function()
		this.fill:SetTint("text", 0.10)
		Theme:Tint(this.glyph, "text")
		Theme:ShowTip(this, "BOTTOM", "Back to the guide")
	end)
	back:SetScript("OnLeave", function()
		this.fill:SetTint("text", 0.04)
		Theme:Tint(this.glyph, "textDim")
		Theme:HideTip(this)
	end)

	--[[ The scrolling body.

		The concept's .options-body is overflow-y:auto: seven sections do not
		fit a 560px window. A ScrollFrame holds them, the theme's scroll bar
		drives it, and the mouse wheel works anywhere over the panel.
	]]
	local scroll = CreateFrame("ScrollFrame", "AegisPathfinderOptionsScroll", frame)
	scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", NAV_W + PAD_X, -(CHROME_TOP + PAD_TOP))
	scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(PAD_X + SCROLL_W), PAD_BOTTOM)

	-- The scroll child holds every page; one is shown at a time, and the
	-- holder takes its height.
	local holder = CreateFrame("Frame", nil, scroll)
	holder:SetWidth(BODY_W)
	holder:SetHeight(1)
	scroll:SetScrollChild(holder)
	local body
	frame.pages = {}

	local bar = Theme:ScrollBar(frame, SCROLL_W)
	bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -(CHROME_TOP + PAD_TOP + SCROLL_W))
	bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, PAD_BOTTOM + SCROLL_W)
	bar:SetMinMaxValues(0, 0)
	bar:SetValue(0)
	bar:SetScript("OnValueChanged", function() scroll:SetVerticalScroll(arg1 or 0) end)
	bar.up:SetScript("OnClick", function() bar:SetValue(math.max(0, bar:GetValue() - 40)) end)
	bar.down:SetScript("OnClick", function()
		local _, hi = bar:GetMinMaxValues()
		bar:SetValue(math.min(hi, bar:GetValue() + 40))
	end)

	frame:EnableMouseWheel(true)
	frame:SetScript("OnMouseWheel", function()
		local _, hi = bar:GetMinMaxValues()
		local v = bar:GetValue() - (arg1 or 0) * 40
		if v < 0 then v = 0 elseif v > hi then v = hi end
		bar:SetValue(v)
	end)

	-- Lay the sections out top to bottom with a running cursor, a page at a
	-- time.
	local y = 0
	local function page(name, sub)
		if body then body.contentHeight = y + PAD_BOTTOM end
		body = CreateFrame("Frame", nil, holder)
		body:SetWidth(BODY_W)
		body:SetHeight(1)
		body:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
		body:Hide()
		body.pageName, body.sub = name, sub
		body.flow = {}
		table.insert(frame.pages, body)
		y = 0
	end
	-- What widens with the window, each with how to set it to a width.
	frame.stretch = {}
	local function stretchy(fit) table.insert(frame.stretch, fit) end
	--[[ Lay a region out under the last, and remember it, so the page can be
		laid out again at another width (Reflow). `height` is a number, or a
		function of the width for what wraps. ]]
	local function place(region, height, gap, indent)
		table.insert(body.flow, { region = region, height = height, gap = gap or 0, indent = indent })
		region:ClearAllPoints()
		region:SetPoint("TOPLEFT", body, "TOPLEFT", indent or 0, -y)
		y = y + (type(height) == "function" and height(BODY_W) or height) + (gap or 0)
	end
	local function space(n)
		table.insert(body.flow, { gap = n })
		y = y + n
	end
	local function section(title)
		local h = Theme:SectionHeader(body, title, BODY_W)
		place(h, 20, HEADER_GAP)
		stretchy(function(w) h:SetWidth(w) end)
		return h
	end
	local function fine(fs)
		stretchy(function(w) fs:SetWidth(w) end)
		return fs
	end
	local function note(text)
		local fs = fine(Theme:FinePrint(body, BODY_W))
		fs:SetText(text or "")
		place(fs, function(w) return TextHeight(fs, w) end, 0)
		return fs
	end
	local function wide(dropdown)
		stretchy(function(w) dropdown:SetWidth(w); dropdown.list:SetWidth(w) end)
		return dropdown
	end

	frame.sections = {}
	frame.switches = {}
	-- What the page builders out of this function lay out with (Build).
	frame.subSwitches, frame.lateDropdowns, frame.boxes = {}, {}, {}
	frame.pswitches, frame.psubSwitches = {}, {}
	local kit = { frame = frame, page = page, place = place, space = space, note = note, wide = wide,
		section = function(title) table.insert(frame.sections, section(title)) end,
		body = function() return body end, SECTION_GAP = SECTION_GAP, BODY_W = BODY_W }

	-- Race -----------------------------------------------------------------------
	page("Route")
	table.insert(frame.sections, section("Race"))
	local race = Theme:Dropdown(body, BODY_W, function(route)
		AegisPathfinder:SelectRoute(route)
		AegisPathfinder:RefreshConfigPanel()
	end)
	place(race, 30, SECTION_GAP)
	wide(race)
	frame.race = race

	-- Route pack -------------------------------------------------------------------
	table.insert(frame.sections, section("Route pack"))

	-- One pill per pack this character can use, wrapping if they do not fit.
	local pillRow = CreateFrame("Frame", nil, body)
	pillRow:SetWidth(BODY_W)
	stretchy(function(w) pillRow:SetWidth(w) end)
	frame.packPills = {}
	local px, py = 0, 0
	for _, pack in ipairs(self:GetAvailableRoutePacks()) do
		local pill = Theme:Pill(pillRow, pack.displayName, 60, 26)
		pill:SetWidth(pill.label:GetStringWidth() + 26)
		if px > 0 and px + pill:GetWidth() > BODY_W then
			px, py = 0, py + 32
		end
		pill:SetPoint("TOPLEFT", pillRow, "TOPLEFT", px, -py)
		px = px + pill:GetWidth() + 6
		pill.packName = pack.name
		pill.description = pack.description
		pill:SetScript("OnClick", function()
			AegisPathfinder:SelectRoutePack(this.packName)
			AegisPathfinder:RefreshConfigPanel()
		end)
		pill:SetScript("OnEnter", function()
			Theme:ShowTip(this, "RIGHT", this.description)
		end)
		pill:SetScript("OnLeave", function() Theme:HideTip(this) end)
		table.insert(frame.packPills, pill)
	end
	pillRow:SetHeight(py + 26)
	place(pillRow, py + 26, 9)

	--[[ The route preview: level range and zone, one row per leg of the route
		this race takes under this pack. It takes the room down to the foot of
		the page -- more rows as the window is made taller (FitRoutePreview) --
		and scrolls on the mouse wheel for the rest. ]]
	local preview = CreateFrame("Frame", nil, body)
	preview:SetWidth(BODY_W)
	preview:SetHeight(PREVIEW_H)
	Theme:NineSlice(preview, Theme.texture.tabFill, "BACKGROUND", { 0, 0, 0 }, 0.25)
	Theme:NineSlice(preview, Theme.texture.tabBorder, "BORDER", "border")
	preview.rows, preview.offset, preview.entries = {}, 0, {}
	preview.visibleRows, preview.page = PREVIEW_ROWS, body
	for i = 1, PREVIEW_ROWS do preview.rows[i] = PreviewRow(preview, i) end
	preview:EnableMouseWheel(true)
	preview:SetScript("OnMouseWheel", function()
		local maxOffset = math.max(0, table.getn(this.entries) - this.visibleRows)
		this.offset = math.max(0, math.min(maxOffset, this.offset - (arg1 or 0)))
		AegisPathfinder:DrawRoutePreview()
	end)
	place(preview, function() return preview.fitH or PREVIEW_H end, SECTION_GAP)
	stretchy(function(w) preview:SetWidth(w) end)
	frame.preview = preview

	-- Dungeons ---------------------------------------------------------------------
	page("Dungeons")
	local dungeonHeader = section("Dungeons")
	local hint = dungeonHeader:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(hint, "body", 11)
	hint:SetPoint("LEFT", dungeonHeader.label, "RIGHT", 6, 0)
	hint:SetText("- RestedXP guides")
	Theme:TextColor(hint, "textDim")
	table.insert(frame.sections, dungeonHeader)

	-- A grid of dungeon chips, four across; a chip ticks its dungeon.
	frame.chips = {}
	local function chipGrid(list)
		local grid = CreateFrame("Frame", nil, body)
		grid:SetWidth(BODY_W)
		for idx, d in ipairs(list) do
			local chip = Theme:Chip(grid, d.code, d.name, CHIP_W, CHIP_H)
			local col = math.mod(idx - 1, CHIP_COLS)
			local row = math.floor((idx - 1) / CHIP_COLS)
			chip:SetPoint("TOPLEFT", grid, "TOPLEFT",
				col * (CHIP_W + CHIP_GAP), -(row * (CHIP_H + CHIP_GAP)))
			chip.dungeonCode = d.code
			local code, name = d.code, d.name
			chip:SetScript("OnClick", function()
				if AegisPathfinder.db.char.SelfFound then return end
				local on = not this:IsActive()
				this:SetActive(on)
				AegisPathfinder.db.char.Dungeons[code] = on
				ReloadCurrentGuide()
				AegisPathfinder:RefreshDungeonPanel()
			end)
			chip:SetScript("OnEnter", function()
				Theme:ShowTip(this, "RIGHT", name)
			end)
			chip:SetScript("OnLeave", function() Theme:HideTip(this) end)
			table.insert(frame.chips, chip)
		end
		local gridH = math.ceil(table.getn(list) / CHIP_COLS) * (CHIP_H + CHIP_GAP) - CHIP_GAP
		grid:SetHeight(gridH)
		place(grid, gridH, 6)
	end
	chipGrid(DUNGEONS)

	note("Toggling a dungeon on forces its setup and prerequisite steps to "
		.. "mandatory and reveals them in guides that reference it; toggling "
		.. "off hides them.")
	local wired = fine(Theme:FinePrint(body, BODY_W))
	Theme:TextColor(wired, "blue")
	place(wired, 16, SECTION_GAP)
	frame.wiredHint = wired

	-- Turtle WoW's own: no route steps, a dungeon guide each.
	table.insert(frame.sections, section("Turtle WoW's own"))
	chipGrid(AegisPathfinder.TURTLE_DUNGEON_INFO or {})
	note("No route guide has steps for these. Ticked, their dungeon guides can be "
		.. "offered along the way.")
	space(SECTION_GAP)

	--[[ Dungeons along the way: the ticked dungeons' guides, offered when a
		guide finishes at their level (NextGuideFrame.lua). ]]
	table.insert(frame.sections, section("Along the way"))
	local along = Theme:Switch(body, "Offer dungeon guides along the way", function(on)
		AegisPathfinder.db.char.offerdungeons = on
	end)
	place(along, function(w) return along:Fit(w) end, 6)
	frame.alongSwitch = along
	note("When you finish a guide, each dungeon ticked here that fits your level is offered "
		.. "beside the route: its dungeon guide opens in a tab of its own, takes you round its "
		.. "quests and in, and back to the route after.")

	--[[ At the middle of its levels: a ticked dungeon's guide, offered once
		(NextGuideFrame.lua). ]]
	local midSwitch = Theme:Switch(body, "Offer a dungeon's guide at the middle of its levels", function(on)
		AegisPathfinder.db.char.middungeons = on
	end)
	place(midSwitch, function(w) return midSwitch:Fit(w) end, 6)
	frame.midSwitch = midSwitch
	note("On reaching the middle of a ticked dungeon's levels -- The Deadmines (17-24) at 21 -- "
		.. "its dungeon guide is offered once, to open in a tab of its own. For the dungeons the "
		.. "setup asks about, not Turtle WoW's own.")
	space(SECTION_GAP)

	--[[ Boss notes: whose lines a dungeon guide's boss steps show
		(Parser.lua, GetStepNote). ]]
	table.insert(frame.sections, section("Boss notes"))
	Build.CharDropdown(kit, "dungeonRole", "My role in dungeons", "dungeonrole", DUNGEON_ROLES, function()
		AegisPathfinder:UpdateOHPanel()
	end)
	note("Inside, a dungeon guide has a step for each boss: what it does, and what the tank, the healer "
		.. "and damage dealers should do about it. Pick your role to see only yours. The step ticks "
		.. "itself when the boss dies.")
	space(SECTION_GAP)

	-- Filters ------------------------------------------------------------------------
	page("Filters")
	table.insert(frame.sections, section("Filters"))
	local group = Theme:Switch(body, "Group mode", function(on)
		AegisPathfinder.db.char.PlayStyle = on and "GROUP" or "SOLO"
		ReloadCurrentGuide()
		AegisPathfinder:RefreshConfigPanel()
	end)
	place(group, function(w) return group:Fit(w) end, 8)
	local ah = Theme:Switch(body, "Auction House steps", function(on)
		AegisPathfinder.db.char.UseAH = on
		ReloadCurrentGuide()
		AegisPathfinder:RefreshConfigPanel()
	end)
	place(ah, function(w) return ah:Fit(w) end, 6)
	-- RestedXP's Solo Self-Found mode: alone, no trading, no Auction House.
	-- It holds group mode, the Auction House and the dungeons off while it is
	-- on, and gives them back as they were.
	local ssf = Theme:Switch(body, "Solo Self-Found", function(on)
		AegisPathfinder:SetSelfFound(on)
	end)
	ssf:SetScript("OnEnter", function()
		Theme:ShowTip(this, "RIGHT", "Solo Self-Found",
			{ "Play alone: hides group quests, dungeons, and every step that trades with other players or uses the Auction House. Their switches are held off until you turn this off." })
	end)
	ssf:SetScript("OnLeave", function() Theme:HideTip(this) end)
	place(ssf, function(w) return ssf:Fit(w) end, 6)
	local filterNote = fine(Theme:FinePrint(body, BODY_W))
	place(filterNote, 30, SECTION_GAP)
	frame.groupSwitch, frame.ahSwitch, frame.ssfSwitch, frame.filterNote = group, ah, ssf, filterNote

	--[[ Server theme: the colours of your server, or Day or Night. Colours
		only -- the guides are the same on every server. It took the place of
		the Server dropdown. ]]
	page("Appearance")
	table.insert(frame.sections, section("Server theme"))
	local theme = Theme:Dropdown(body, BODY_W, function(key)
		AegisPathfinder:SetTheme(key)
	end)
	local themeItems = {}
	for _, def in ipairs(Theme.THEMES) do
		table.insert(themeItems, { value = def.key, label = def.label })
	end
	theme:SetItems(themeItems)
	place(theme, 30, 6)
	wide(theme)
	local themeNote = fine(Theme:FinePrint(body, BODY_W))
	place(themeNote, 44, 6)
	local redGreen = Theme:Switch(body, "Red and green switches", function(on)
		AegisPathfinder:SetSwitchColours(on and "redgreen" or "theme")
	end)
	place(redGreen, function(w) return redGreen:Fit(w) end, 6)
	note("Green when on and red when off, whatever the theme. Off, switches "
		.. "take the theme's colours.")
	space(SECTION_GAP)
	frame.theme, frame.themeNote, frame.redGreen = theme, themeNote, redGreen

	--[[ Window scale: every Pathfinder window, bigger or smaller. ]]
	table.insert(frame.sections, section("Window scale"))
	local scale = Theme:Slider(body, "Scale", Theme.SCALE_MIN, Theme.SCALE_MAX, Theme.SCALE_STEP,
		function(v) AegisPathfinder:SetWindowScale(v) end,
		function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end)
	place(scale, function(w) return scale:Fit(w) end, 6)
	note("Makes every Pathfinder window bigger or smaller, the guide and this "
		.. "one included. The guide's text wraps to whatever width you drag it "
		.. "to with the grip in its corner.")
	space(SECTION_GAP)
	frame.scale = scale
	Build.AppearanceGuide(kit)

	-- Zygor's pages, in this style: what used to be Behaviour, spread out.
	Build.StepDisplay(kit)
	Build.Automation(kit)
	Build.ActionButtons(kit)

	page("Navigation")
	table.insert(frame.sections, section("Waypoints"))
	local waypoints = Theme:Dropdown(body, BODY_W, function(name)
		AegisPathfinder:SetWaypointProvider(name)
		AegisPathfinder:RefreshConfigPanel()
	end)
	place(waypoints, 30, SECTION_GAP)
	wide(waypoints)
	frame.waypoints = waypoints

	--[[ Which arrows point at the step: a switch each for ours, TomTom's and
		pfQuest's, so any of them, all or none. They replaced a dropdown of
		ours, the waypoint addon's, both or neither, which could not turn
		pfQuest's arrow off when TomTom took the waypoints, nor have three. An
		addon that is not loaded has its switch held off. ]]
	table.insert(frame.sections, section("Arrows"))
	frame.arrows = {}
	for _, def in ipairs(AegisPathfinder.ARROWS or {}) do
		local key = def.key
		local sw = Theme:Switch(body, def.label, function(on)
			AegisPathfinder:SetArrow(key, on)
			AegisPathfinder:RefreshConfigPanel()
		end)
		sw.arrowKey = key
		place(sw, function(w) return sw:Fit(w) end, 8)
		frame.arrows[key] = sw
	end
	local arrowNote = fine(Theme:FinePrint(body, BODY_W))
	place(arrowNote, 58, SECTION_GAP)
	frame.arrowNote = arrowNote
	Build.Maps(kit)

	--[[ Gear: the item score on tooltips, and the window with its weights. ]]
	page("Gear")
	table.insert(frame.sections, section("Gear"))
	local scoreTips = Theme:Switch(body, "Item score on tooltips", function(on)
		AegisPathfinder.ItemScore.Settings().tooltips = on
	end)
	place(scoreTips, function(w) return scoreTips:Fit(w) end, 6)
	local weights = Theme:Pill(body, "Stat weights", 120, 26)
	weights:SetScript("OnClick", function()
		AegisPathfinder:ShowConfigPage(AegisPathfinder.ITEM_SCORE_PAGE)
	end)
	place(weights, 26, 6)
	note("Each item's tooltip shows what it is worth to your spec and how it "
		.. "compares with what you wear, with weights for leveling and for 60; change "
		.. "them, pick another spec, or score your other specs too, under Item Score.")
	space(10)
	-- The Gear Advisor's switches (GearAdvisor.lua), Zygor's in this style.
	frame.advisor = {}
	local ADVISOR = {
		{ key = "enabled",   label = "Gear Advisor: tell me about upgrades" },
		{ key = "maxlevel",  label = "Turn it off at level 60" },
		{ key = "popups",    label = "Pop up new upgrades as I pick them up" },
		{ key = "autoequip", label = "Equip upgrades for me (never one that binds)" },
		{ key = "questmark", label = "Mark the best quest reward" },
		{ key = "questpick", label = "Pick it for me when quests turn in by themselves" },
		{ key = "bagmark",   label = "Border upgrades in my bags" },
	}
	for _, def in ipairs(ADVISOR) do
		local key = def.key
		local sw = Theme:Switch(body, def.label, function(on)
			AegisPathfinder.GearAdvisor.Settings()[key] = on
			AegisPathfinder.GearAdvisor:Dirty()
			AegisPathfinder:RefreshConfigPanel()
		end)
		place(sw, function(w) return sw:Fit(w) end, 6)
		frame.advisor[key] = sw
	end
	local clearDeclined = Theme:Pill(body, "Clear declined items", 150, 26)
	clearDeclined:SetScript("OnClick", function()
		AegisPathfinder.GearAdvisor:ClearDeclined()
		AegisPathfinder:Print("Declined upgrades cleared: they will be offered again.")
	end)
	place(clearDeclined, 26, 10)
	-- The Gear Finder (GearFinder.lua, the character panel's tab).
	frame.finder = {}
	local function finderSwitch(key, label)
		local sw = Theme:Switch(body, label, function(on)
			AegisPathfinder.GearFinder.Settings()[key] = on
			AegisPathfinder:RefreshConfigPanel()
			AegisPathfinder.GearFinder:SettingsChanged()
		end)
		place(sw, function(w) return sw:Fit(w) end, 6)
		frame.finder[key] = sw
	end
	finderSwitch("enabled", "Gear finder: upgrades waiting for me")
	--[[ Where it looks for upgrades: a box each, two to a row. Dungeons and
		Raids are Zygor's two (1.12 has no difficulties to tick); quest rewards,
		reputation vendors and crafted gear were switches of their own, and
		keep what they were set to. Tick only Dungeons and it looks nowhere
		else. ]]
	local SOURCES = { { "dungeons", "Dungeons" }, { "raids", "Raids" }, { "quests", "Quest rewards" },
		{ "reputation", "Reputation vendors" }, { "crafted", "Crafted gear" } }
	local sources = CreateFrame("Frame", nil, body)
	sources:SetHeight(SOURCES_H)
	sources:SetWidth(BODY_W)
	local sourcesLabel = sources:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(sourcesLabel, "body", 13)
	Theme:TextColor(sourcesLabel, "text")
	sourcesLabel:SetPoint("TOPLEFT", sources, "TOPLEFT", 0, 0)
	sourcesLabel:SetText("Upgrade sources")
	frame.sources = {}
	for i, def in ipairs(SOURCES) do
		local key = def[1]
		local box = Theme:Checkbox(sources, def[2], function(on)
			AegisPathfinder.GearFinder.Settings()[key] = on
			if key == "raids" and on then
				AegisPathfinder:Print("Raids added to the Gear Finder. The first time, their items have to "
					.. "load from the server: it can take a minute or two, and the cells fill in as they arrive.")
			end
			AegisPathfinder:RefreshConfigPanel()
			AegisPathfinder.GearFinder:SettingsChanged()
		end)
		box:Fit()
		box:SetPoint("TOPLEFT", sourcesLabel, "BOTTOMLEFT", math.mod(i - 1, 2) * SOURCE_COL,
			-(4 + math.floor((i - 1) / 2) * SOURCE_ROW))
		frame.sources[key] = box
	end
	place(sources, SOURCES_H, 2)
	note("The first time Raids is ticked, their items load from the server: it can take a "
		.. "minute or two, and the Gear Finder fills in as they arrive.")
	space(6)
	finderSwitch("announce", "Name the upgrades when I walk into a dungeon")
	local openFinder = Theme:Pill(body, "Open the Gear Finder", 150, 26)
	openFinder:SetScript("OnClick", function() AegisPathfinder:ToggleGearFinder() end)
	place(openFinder, 26, 6)
	note("A tab on the character panel. It looks in the dungeons at or a little above your "
		.. "level, Turtle WoW's own included, and in raids at your level; and at quests you have "
		.. "still to do, reputation vendors and crafted gear near your level -- each where it is "
		.. "ticked. Crafted gear that binds on pickup counts only if you have the profession.")
	space(SECTION_GAP)
	frame.scoreTips, frame.weightsButton, frame.clearDeclined = scoreTips, weights, clearDeclined
	frame.openFinder = openFinder

	--[[ Item Score: the weights, as Zygor lists them under Gear. The page is
		GearFrame.lua's; it sets its own height as its list changes. ]]
	page(AegisPathfinder.ITEM_SCORE_PAGE, true)
	table.insert(frame.sections, section("Item score"))
	local scorePage = AegisPathfinder:CreateItemScorePage(body, BODY_W, y, PAD_BOTTOM)
	body.ownHeight = true
	stretchy(function(w) scorePage:Resize(w) end)
	Build.Extras(kit)

	page("Maintenance")
	table.insert(frame.sections, section("Maintenance"))
	local rescan = Theme:Pill(body, "Rescan progress", 140, 26)
	rescan:SetScript("OnClick", function() AegisPathfinder:QueryServerCompletedQuests(true) end)
	local errors = Theme:Pill(body, "Error log", 100, 26)
	errors:SetScript("OnClick", function() AegisPathfinder:ShowErrorLog() end)
	local setup = Theme:Pill(body, "Run setup", 90, 26)
	setup:SetScript("OnClick", function() AegisPathfinder:ShowSetup() end)
	place(rescan, 26, 6)
	errors:SetPoint("LEFT", rescan, "RIGHT", 6, 0)
	setup:SetPoint("LEFT", errors, "RIGHT", 6, 0)
	note("Rescan asks the server which quests this character has completed and "
		.. "re-marks the guide from that. Run setup asks the first-time questions "
		.. "again: your guide, its features and your dungeons.")
	frame.rescan, frame.errorlog, frame.setup = rescan, errors, setup
	space(SECTION_GAP)

	-- Last, where an about box goes: who this addon is built on.
	page("About")
	table.insert(frame.sections, section("About"))
	frame.version = note("Version v" .. (AegisPathfinder.version or "?") .. " -- quote it in bug reports.")
	space(4)
	note("Aegis: Pathfinder is built on other people's work -- TourGuide, "
		.. "VanillaGuide, ClassicAPI, Joana's routes and more.")
	space(6)
	local credits = Theme:Pill(body, "Credits", 90, 26)
	credits:SetScript("OnClick", function() AegisPathfinder:ToggleCredits() end)
	place(credits, 26, 0)
	frame.credits = credits

	-- Each page's height is known now: what the scroll bar ranges over.
	body.contentHeight = y + PAD_BOTTOM
	for _, p in ipairs(frame.pages) do p:SetHeight(p.contentHeight) end
	frame.visible = HEIGHT - CHROME_TOP - PAD_TOP - PAD_BOTTOM
	frame.scroll, frame.holder, frame.scrollbar = scroll, holder, bar
	-- Their lists hang off UIParent, so they are closed by hand when the
	-- page or the window goes.
	frame.dropdowns = { race, theme, waypoints, scorePage.spec }
	for _, d in ipairs(frame.lateDropdowns) do table.insert(frame.dropdowns, d) end

	--[[ The categories, down the left: Zygor's list, in this style -- a
		quieter column than the page, the page shown marked with an accent
		bar and the text brightened. ]]
	local nav = CreateFrame("Frame", nil, frame)
	nav:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -CHROME_TOP)
	nav:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
	nav:SetWidth(NAV_W)
	local navBg = nav:CreateTexture(nil, "BACKGROUND")
	navBg:SetTexture(Theme.texture.solid)
	navBg:SetAllPoints(nav)
	Theme:Tint(navBg, "text", 0.03)
	local navEdge = nav:CreateTexture(nil, "BORDER")
	navEdge:SetTexture(Theme.texture.solid)
	navEdge:SetPoint("TOPRIGHT", nav, "TOPRIGHT", 0, 0)
	navEdge:SetPoint("BOTTOMRIGHT", nav, "BOTTOMRIGHT", 0, 0)
	navEdge:SetWidth(1)
	Theme:Tint(navEdge, "text", 0.08)
	frame.nav, frame.navButtons = nav, {}
	for i, p in ipairs(frame.pages) do
		local b = CreateFrame("Button", nil, nav)
		b:SetHeight(NAV_ROW_H)
		b:SetPoint("TOPLEFT", nav, "TOPLEFT", 0, -(8 + (i - 1) * NAV_ROW_H))
		b:SetPoint("RIGHT", nav, "RIGHT", -1, 0)
		local fill = b:CreateTexture(nil, "BACKGROUND")
		fill:SetTexture(Theme.texture.solid)
		fill:SetAllPoints(b)
		local mark = b:CreateTexture(nil, "ARTWORK")
		mark:SetTexture(Theme.texture.solid)
		mark:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
		mark:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
		mark:SetWidth(3)
		Theme:Tint(mark, "accent")
		local label = b:CreateFontString(nil, "OVERLAY")
		Theme:SetFont(label, "body", 13)
		-- A page that belongs to the one above it sits in under it.
		if p.sub then Theme:SetFont(label, "body", 12) end
		label:SetPoint("LEFT", b, "LEFT", p.sub and 28 or 14, 0)
		label:SetText(p.pageName)
		b.fill, b.mark, b.label, b.pageName = fill, mark, label, p.pageName
		function b:SetActive(on)
			self.active = on
			Theme:Tint(self.fill, "text", on and 0.08 or 0)
			if on then self.mark:Show() else self.mark:Hide() end
			Theme:TextColor(self.label, on and "text" or "textDim")
		end
		b:SetScript("OnClick", function() AegisPathfinder:ShowConfigPage(this.pageName) end)
		b:SetScript("OnEnter", function() if not this.active then Theme:Tint(this.fill, "text", 0.04) end end)
		b:SetScript("OnLeave", function() if not this.active then Theme:Tint(this.fill, "text", 0) end end)
		b:SetActive(false)
		frame.navButtons[i] = b
	end
	--[[ Resize grip, bottom right, as the guide has: drag it to make the
		window wider or taller. It sizes the window itself rather than calling
		StartSizing, for the reason the guide's grip gives (ObjectivesFrame.lua):
		the client's sizing re-anchors the frame as it sees fit. ]]
	local grip = CreateFrame("Frame", nil, frame)
	grip:SetWidth(12)
	grip:SetHeight(12)
	grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
	grip:EnableMouse(true)
	grip:SetFrameLevel(frame:GetFrameLevel() + 6)
	local gripTex = grip:CreateTexture(nil, "OVERLAY")
	gripTex:SetTexture(Theme.texture.grip)
	gripTex:SetAllPoints(grip)
	Theme:Tint(gripTex, "textDim", 0.55)
	local function cursor()
		local scale = frame:GetEffectiveScale()
		local x, y = GetCursorPosition()
		return x / scale, y / scale
	end
	local function stop()
		grip.sizing = nil
		grip:SetScript("OnUpdate", nil)
		Theme:Tint(gripTex, "textDim", 0.55)
	end
	local function sizing()
		local s = grip.sizing
		if not s then return end
		-- A button let go somewhere the grip never heard about still ends it.
		if s.poll and not IsMouseButtonDown("LeftButton") then return stop() end
		local x, y = cursor()
		-- Screen y grows upward: dragging down is a smaller y, a taller window.
		AegisPathfinder:SizeConfigWindow(s.w + x - s.x, s.h + s.y - y, true)
	end
	grip:SetScript("OnMouseDown", function()
		Theme:Tint(gripTex, "accentGlow", 1)
		-- Grow right and down from where the window is, however it was anchored.
		Theme:AnchorTopLeft(frame)
		local x, y = cursor()
		grip.sizing = { x = x, y = y, w = frame:GetWidth(), h = frame:GetHeight(),
			poll = IsMouseButtonDown and IsMouseButtonDown("LeftButton") and true or false }
		grip:SetScript("OnUpdate", sizing)
	end)
	grip:SetScript("OnMouseUp", function()
		sizing()
		stop()
	end)
	grip:SetScript("OnEnter", function()
		Theme:Tint(gripTex, "accent", 1)
		Theme:ShowTip(this, "LEFT", "Drag to resize")
	end)
	grip:SetScript("OnLeave", function()
		if not grip.sizing then Theme:Tint(gripTex, "textDim", 0.55) end
		Theme:HideTip(this)
	end)
	frame.grip, frame.bodyW = grip, BODY_W

	-- The size it was left at.
	self:SizeConfigWindow(self.db.profile.optionswidth, self.db.profile.optionsheight)
	self:ShowConfigPage(frame.pages[1].pageName)

	frame:SetScript("OnShow", function()
		-- Snap beside the guide only while the player has not dragged this
		-- window somewhere of their own.
		if not Theme:RestorePosition(this, "optionsframe") then
			local _, _, hhalf = AegisPathfinder.GetQuadrant(AegisPathfinder.objectiveframe)
			this:ClearAllPoints()
			if hhalf == "LEFT" then
				this:SetPoint("TOPLEFT", AegisPathfinder.objectiveframe, "TOPRIGHT", 8, 0)
			else
				this:SetPoint("TOPRIGHT", AegisPathfinder.objectiveframe, "TOPLEFT", -8, 0)
			end
		end
		AegisPathfinder:RefreshConfigPanel()
		Theme:FadeIn(this, 0.5)
	end)
	frame:SetScript("OnHide", function()
		-- The credits open from here, and close with it.
		if AegisPathfinder.creditsframe then AegisPathfinder.creditsframe:Hide() end
		for _, d in ipairs(this.dropdowns) do d.list:Hide() end
	end)
	table.insert(UISpecialFrames, "AegisPathfinderOptions")
end

--- The options window at `w` by `h` -- no narrower than it opens, no shorter
--- than MIN_HEIGHT, no bigger than the screen -- with every page's contents
--- widened to fit and the scroll range to match. `save` keeps the size.
function AegisPathfinder:SizeConfigWindow(w, h, save)
	local frame = self.optionsframe
	if not frame then return end
	w = math.floor(math.max(WIDTH, math.min(w or WIDTH, UIParent:GetWidth() - 40)) + 0.5)
	h = math.floor(math.max(MIN_HEIGHT, math.min(h or HEIGHT, UIParent:GetHeight() - 40)) + 0.5)
	frame:SetWidth(w)
	frame:SetHeight(h)
	local bodyW = w - NAV_W - PAD_X * 2 - SCROLL_W - 4
	if bodyW ~= frame.bodyW then
		frame.bodyW = bodyW
		frame.holder:SetWidth(bodyW)
		for _, p in ipairs(frame.pages) do p:SetWidth(bodyW) end
		for _, fit in ipairs(frame.stretch) do fit(bodyW) end
		for _, p in ipairs(frame.pages) do Reflow(p, bodyW) end
	end
	frame.visible = h - CHROME_TOP - PAD_TOP - PAD_BOTTOM
	self:FitRoutePreview()
	self:SizeConfigPage(true)
	if save then
		self.db.profile.optionswidth, self.db.profile.optionsheight = w, h
	end
end

--- Show one page of the options panel: its content on the right, its name
--- marked in the list and in the header strip, scrolled to the top.
function AegisPathfinder:ShowConfigPage(name)
	local frame = self.optionsframe
	if not frame then return end
	local shown
	for _, p in ipairs(frame.pages) do
		if p.pageName == name then shown = p end
	end
	shown = shown or frame.pages[1]
	for _, p in ipairs(frame.pages) do
		if p == shown then p:Show() else p:Hide() end
	end
	for _, d in ipairs(frame.dropdowns) do d.list:Hide() end
	frame.page = shown.pageName
	if shown.refresh then shown.refresh() end
	self:SizeConfigPage()
	for _, b in ipairs(frame.navButtons) do b:SetActive(b.pageName == frame.page) end
	frame.subhead.label:SetText("CONFIG \194\183 " .. string.upper(frame.page))
end

--- Fit the scroll range to the page shown: from its top, or, with `keep`,
--- staying where it is (a page whose height just changed under you).
function AegisPathfinder:SizeConfigPage(keep)
	local frame = self.optionsframe
	if not (frame and frame.page) then return end
	local shown
	for _, p in ipairs(frame.pages) do
		if p.pageName == frame.page then shown = p end
	end
	frame.holder:SetHeight(shown.contentHeight)
	frame.scroll:UpdateScrollChildRect()
	local over = math.max(0, shown.contentHeight - frame.visible)
	frame.scrollbar:SetMinMaxValues(0, over)
	local v = keep and math.min(frame.scrollbar:GetValue(), over) or 0
	frame.scrollbar:SetValue(v)
	frame.scroll:SetVerticalScroll(v)
	if over > 0 then frame.scrollbar:Show() else frame.scrollbar:Hide() end
end

--- Open the options panel, or close it if it is open. The header's menu chip
--- and a right-click on the minimap button both land here.
function AegisPathfinder:ToggleConfigPanel()
	if not self.optionsframe then self:CreateConfigPanel() end
	if self.optionsframe:IsShown() then
		self.optionsframe:Hide()
	else
		self.optionsframe:Show()
	end
end

--- The route preview as tall as the Route page has room for: from where it
--- starts down to the foot of the window, never shorter than it opens with.
function AegisPathfinder:FitRoutePreview()
	local frame = self.optionsframe
	local preview = frame and frame.preview
	if not preview or not frame.visible then return end
	local width = frame.bodyW or BODY_W
	local top = 0
	for _, e in ipairs(preview.page.flow) do
		if e.region == preview then break end
		if e.region then top = top + (type(e.height) == "function" and e.height(width) or e.height) end
		top = top + e.gap
	end
	local room = frame.visible - top - SECTION_GAP - PAD_BOTTOM
	local rows = math.max(PREVIEW_ROWS, math.floor((room - 8) / PREVIEW_ROW_H))
	for i = table.getn(preview.rows) + 1, rows do preview.rows[i] = PreviewRow(preview, i) end
	preview.visibleRows = rows
	preview.fitH = rows * PREVIEW_ROW_H + 8
	preview:SetHeight(preview.fitH)
	Reflow(preview.page, width)
	preview.offset = math.max(0, math.min(preview.offset, table.getn(preview.entries) - rows))
	self:DrawRoutePreview()
end

--- Draw the visible slice of the route preview.
function AegisPathfinder:DrawRoutePreview()
	local preview = self.optionsframe and self.optionsframe.preview
	if not preview then return end
	for i, row in ipairs(preview.rows) do
		local entry = i <= preview.visibleRows and preview.entries[i + preview.offset]
		if entry then
			row.lvl:SetText(entry.levels or "")
			row.zone:SetText(entry.zone or entry.guide or "")
			row:Show()
		else
			row:Hide()
		end
	end
end

--- Bring every control into line with the saved settings.
function AegisPathfinder:RefreshConfigPanel()
	local frame = self.optionsframe
	if not frame then return end
	local db = self.db.char

	-- Race: this faction's races, the player's own marked.
	local faction = self.myfaction or "Alliance"
	local mine = self:GetRouteForRace()
	local items = {}
	for _, r in ipairs(RACES[faction] or RACES.Alliance) do
		local label = r.label .. " (" .. faction .. ")"
		if r.route == mine then label = label .. " - yours" end
		table.insert(items, { value = r.route, label = label })
	end
	frame.race:SetItems(items)
	frame.race:SetValue(db.currentroute or mine)

	-- Route pack, and the route it gives this race.
	local current = db.routepack or "VanillaGuide"
	for _, pill in ipairs(frame.packPills) do
		pill:SetActive(pill.packName == current)
	end
	local pack = self.routepacks and self.routepacks[current]
	local route = pack and pack.routes and pack.routes[db.currentroute or mine]
	frame.preview.entries = route or {}
	frame.preview.offset = 0
	self:DrawRoutePreview()

	self:RefreshDungeonPanel()

	-- Filters, and the one-line summary the concept prints under them.
	-- Solo Self-Found holds group mode, the Auction House and the dungeons off.
	local grouped = (db.PlayStyle or "SOLO") == "GROUP" and not db.SelfFound
	frame.groupSwitch:SetOn(grouped)
	frame.groupSwitch:SetLocked(db.SelfFound)
	frame.ahSwitch:SetOn(db.UseAH and not db.SelfFound)
	frame.ahSwitch:SetLocked(db.SelfFound)
	frame.ssfSwitch:SetOn(db.SelfFound)
	frame.scoreTips:SetOn(self.ItemScore.Settings().tooltips)
	self:UpdateItemScorePage()
	local finder = self.GearFinder.Settings()
	for key, sw in pairs(frame.finder) do
		sw:SetOn(finder[key])
		sw:SetLocked(key ~= "enabled" and not finder.enabled)
	end
	for key, box in pairs(frame.sources) do
		box:SetOn(finder[key])
		box:SetLocked(not finder.enabled)
	end
	local advisor = self.GearAdvisor.Settings()
	for key, sw in pairs(frame.advisor) do
		sw:SetOn(advisor[key])
		-- The rest of the advisor's switches mean nothing with it off.
		sw:SetLocked(key ~= "enabled" and not advisor.enabled)
	end
	frame.filterNote:SetText(db.SelfFound
		and "Solo Self-Found \194\183 no group quests, dungeons, trading or Auction House steps"
		or ((grouped and "Group mode" or "Solo mode") .. " \194\183 Auction House steps "
			.. (db.UseAH and "shown" or "hidden")))

	-- The theme, and what it looks like.
	local def = Theme.themeByKey[self:GetTheme()]
	frame.theme:SetValue(def.key)
	frame.themeNote:SetText(def.note)
	frame.redGreen:SetOn(Theme.switchColours == "redgreen")
	frame.scale:SetValue(Theme.windowScale)

	-- The guide's lock and transparency, which its ≡ menu sets too, and the
	-- rest of the Appearance page's guide settings.
	local profile = self.db.profile
	frame.guideLock:SetOn(profile.objframelocked)
	frame.guideTransparent:SetOn(profile.objframetransparent)
	frame.guideOpacity:SetValue(profile.objframeopacity or 0.5)
	Build.Hold(frame.guideOpacity, not profile.objframetransparent)
	frame.browserOpacity:SetValue(profile.browseropacity or 1)
	frame.textSize:SetValue(profile.steptextsize or 1)
	frame.guideProgress:SetOn(profile.showprogress ~= false)
	frame.guideUpward:SetOn(profile.objframeupward)
	for key, sw in pairs(frame.pswitches) do
		if sw.defaultOn then sw:SetOn(profile[key] ~= false) else sw:SetOn(profile[key]) end
	end
	for key, parent in pairs(frame.psubSwitches) do
		frame.pswitches[key]:SetLocked(not profile[parent])
	end
	frame.askShare:SetOn(not db.sharenowarn)
	frame.askShare:SetLocked(db.partysync == false)
	frame.focusSteps:SetValue(db.focussteps or 1)
	frame.dungeonRole:SetValue(db.dungeonrole or "all")
	-- The Talent Advisor's build, held off with the advisor; the menu names
	-- your spec, which the Item Score page can change.
	local TA = self.TalentAdvisor
	if TA then
		frame.talentBuild:SetItems(TA:BuildItems(TA:State()))
		frame.talentBuild:SetValue(db.talentbuild or "auto")
		local on = db.talentadvisor ~= false
		frame.talentBuild:SetAlpha(on and 1 or 0.45)
		frame.talentBuild:EnableMouse(on)
		if not on then frame.talentBuild.list:Hide() end
	end

	-- The addon's own switches; one under another is held off with it.
	for key, sw in pairs(frame.switches) do
		if sw.defaultOn then sw:SetOn(db[key] ~= false) else sw:SetOn(db[key]) end
	end
	for key, parent in pairs(frame.subSwitches) do
		frame.switches[key]:SetLocked(not db[parent])
	end
	frame.repair:SetValue(db.autorepair or "off")
	-- The Action Buttons page.
	frame.itemsGrow:SetValue(db.itemsgrow or "right")
	frame.targetsGrow:SetValue(db.targetsgrow or "right")
	frame.buttonSize:SetValue(db.buttonscale or 1)
	for key, box in pairs(frame.boxes) do
		if box.defaultOff then box:SetOn(db[key]) else box:SetOn(db[key] ~= false) end
	end
	-- The Maps page: its switches are in frame.pswitches, above.
	frame.antStyle.dropdown:SetValue(profile.antstyle or "dots")
	Build.Hold(frame.antStyle, profile.anttrail == false)
	frame.rareSize:SetValue(profile.raresize or 1)
	Build.Hold(frame.rareSize, not profile.maprares)

	-- Waypoint providers actually loaded, plus automatic.
	local wp = { { value = "auto", label = "Automatic" } }
	for _, provider in ipairs(self:GetWaypointProviders()) do
		table.insert(wp, { value = provider.name, label = provider.label })
	end
	frame.waypoints:SetItems(wp)
	frame.waypoints:SetValue(db.waypointprovider or "auto")

	-- The arrows: a switch each, held off for an addon that is not loaded.
	local missing = {}
	for _, def in ipairs(self.ARROWS or {}) do
		local sw, available = frame.arrows[def.key], self:IsArrowAvailable(def.key)
		sw:SetOn(available and self:IsArrowOn(def.key))
		sw:SetLocked(not available)
		if not available and def.addon then table.insert(missing, def.addon) end
	end
	local provider = self:GetWaypointProvider()
	local text
	if provider and provider.arrowIsWaypoint then
		text = provider.label .. "'s waypoint is its arrow, so it points whatever is switched here."
	else
		text = "As many as you like. pfQuest's off is off in pfQuest too, as /db arrow does. "
			.. "The waypoint addon keeps its map pins either way."
	end
	if table.getn(missing) > 0 then
		text = text .. " " .. table.concat(missing, " and ")
			.. (table.getn(missing) > 1 and " are" or " is") .. " not loaded."
	end
	frame.arrowNote:SetText(text)
end

--- Sync the dungeon chips with saved settings and with the loaded guide.
--
-- The blue dot marks a dungeon the current guide actually has |D| steps for,
-- which is the difference between "I could run this" and "this guide knows
-- about it". Without it every chip looks equally relevant no matter which
-- guide you are on.
function AegisPathfinder:RefreshDungeonPanel()
	local frame = self.optionsframe
	if not frame or not frame.chips then return end

	local wired = self:HasNoGuide() and {} or self:GetGuideDungeons()
	local wiredCount = 0

	local ssf = self.db.char.SelfFound
	for _, chip in ipairs(frame.chips) do
		chip:SetActive(self.db.char.Dungeons[chip.dungeonCode] and not ssf)
		chip:SetLocked(ssf)
		local isWired = wired[chip.dungeonCode] and true or false
		chip:SetWired(isWired)
		if isWired then wiredCount = wiredCount + 1 end
	end

	frame.alongSwitch:SetOn(self.db.char.offerdungeons and not ssf)
	frame.alongSwitch:SetLocked(ssf)
	frame.midSwitch:SetOn(self.db.char.middungeons ~= false and not ssf)
	frame.midSwitch:SetLocked(ssf)

	if ssf then
		frame.wiredHint:SetText("Solo Self-Found is on: no dungeons until it is off.")
	elseif wiredCount > 0 then
		frame.wiredHint:SetText(string.format(
			"Dotted: %d referenced by this guide.", wiredCount))
	else
		frame.wiredHint:SetText("This guide has no dungeon steps.")
	end
end
