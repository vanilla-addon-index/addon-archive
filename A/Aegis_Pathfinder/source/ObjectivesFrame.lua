--[[ The objectives panel -- the guide window, and the addon's main surface.

	Laid out as the concept's `#objectives` panel, top to bottom:

	  .panel-header       header strip: ☰ · PATHFINDER · ✕, and the drag handle
	  .tabbar             the guide you are on, the one you branched to, and +
	  .navrow             ← step number → , with the step count on the right
	  .zprogress-track    4px bar of guide completion
	  .steps-list         the steps
	  .panel-footer-hint  the slash commands

	Rows follow the concept's two models. Most steps are a `.zrow`: a dot, an
	action glyph, the step title, and the note beneath it in grey. ACCEPT and
	TURNIN steps become a full-width `.zband` once they are the current step or
	are done -- red while outstanding, green once satisfied -- which is how the
	concept makes "there is a quest to hand in here" impossible to scroll past.
]]

local AegisPathfinder = AegisPathfinder
local L = AegisPathfinder.Locale
local Theme = AegisPathfinder.Theme


-- Layout constants live in one table: a file-scope local per constant cost
-- UpdateObjectivePanel one upvalue each, and Lua 5.0 refuses a function with
-- more than 32 (see CONTRIBUTING.md).
local G = {}

-- Concept geometry. CHROME_TOP is everything above the step list; the list
-- and the footer divide what is left.
G.HEADER_H   = 30
G.TABBAR_H   = 26
G.NAVROW_H   = 26
G.PROGRESS_H = 4
G.FOOTER_H   = 24
G.CHROME_TOP = G.HEADER_H + G.TABBAR_H + G.NAVROW_H + G.PROGRESS_H

G.ROWHEIGHT = 44          -- title over note, as the concept stacks them
G.ROWPAD    = 14          -- .zrow padding-left
G.DOTSIZE   = 14
G.ICONSIZE  = 16

--[[ Size.

	The concept's panel is as tall as what it shows, up to a max-height of
	min(70vh, 600px); its grip sets the width and that cap, never the height
	itself. So a step with a long note makes the panel taller, overview fills
	the cap, and nothing the player drags can leave the panel a size its
	content does not fit.
]]
G.DEFAULT_WIDTH = 396                                      -- .panel{width:396px}
G.OLD_DEFAULT_WIDTH = 630
G.DEFAULT_ANCHOR = { "TOPRIGHT", "TOPRIGHT", -40, -180 }  -- top:180px; right:40px
G.MIN_WIDTH, G.MAX_WIDTH = 320, 1200                         -- makeResizable minWidth
G.DEFAULT_CAP, G.MIN_CAP = 600, 260                          -- max-height, minHeight
G.NOTE_TOP = 31      -- where the note starts in a row: title's top, its line, a gap
G.TITLE_H = 16       -- one line of title
G.TITLE_LINE = 15    -- each line a wrapped title adds
G.NOTE_BOTTOM = 8
G.NOTE_LINE = 14     -- a note line, where the client will not measure one
G.MAX_ROWS = 30
G.MAX_FOCUS = 5      -- the most steps focus mode shows (the Step Display page)
-- The text size's base sizes: Appearance's Step text size scales them.
G.BASE = { ROWHEIGHT = 44, TITLE_H = 16, TITLE_LINE = 15, NOTE_TOP = 31, NOTE_LINE = 14,
	TITLE_FONT = 12, NOTE_FONT = 11, DETAIL_H = 15 }
G.TEXT_SCALE = 1
local NUMROWS = 1


local offset = 0
local rows = {}
local scrollbar, upbutt, downbutt
local navStepNum, navCount, guideProgress
local footerQid, footerCount, meter
local guideTabs = {}

--[[ The meter's lines: an objective's name, its count and its bar, one
	under another. One line is the concept's 38px meter. ]]
G.METER_PAD, G.METER_LINE, G.METER_GAP = 8, 22, 8

local function MeterHeight(n)
	return G.METER_PAD * 2 + n * G.METER_LINE + (n - 1) * G.METER_GAP
end

local function MeterLine(m, i)
	if m.lines[i] then return m.lines[i] end
	local y = -(G.METER_PAD + (i - 1) * (G.METER_LINE + G.METER_GAP))

	local label = m:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(label, "body", 12)
	label:SetPoint("TOPLEFT", m, "TOPLEFT", 11, y)
	label:SetJustifyH("LEFT")
	Theme:TextColor(label, "textDim")

	local count = m:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(count, "body2", 12)
	count:SetPoint("TOPRIGHT", m, "TOPRIGHT", -11, y)
	count:SetJustifyH("RIGHT")
	Theme:TextColor(count, "accent")

	local bar = Theme:ProgressBar(m, 6)
	bar:SetPoint("TOPLEFT", m, "TOPLEFT", 11, y - 16)
	bar:SetPoint("TOPRIGHT", m, "TOPRIGHT", -11, y - 16)

	m.lines[i] = { label = label, count = count, bar = bar }
	return m.lines[i]
end

--[[ Tab sizing.

	The bar shows at most VISIBLE_TABS guides at once -- fewer on a panel too
	narrow to give each TAB_W_MIN -- and a ‹ › pair scrolls through the rest.
	Squeezing every open guide into the bar instead is what reduced five of
	them to "Optim... North... Gilnea...".

	The tabs that are shown share the room, up to the concept's .tab
	max-width; below BADGE_MIN a tab drops its XP/TPL badge so the width goes
	to the name.
]]
G.MAX_TABS = AegisPathfinder.MAX_GUIDE_TABS or 8
G.VISIBLE_TABS = 4
G.TAB_W_MAX = 190      -- .tab{max-width:190px}
G.TAB_W_MIN = 100      -- narrower and the name is mostly ellipsis
G.TAB_GAP = 2
G.BADGE_MIN = 130
G.ADD_W = G.TABBAR_H - 9
G.ARROW_W = 16

-- The first tab in view, and what the bar last showed: the view follows the
-- active tab when that changes, and otherwise stays where the arrows put it.
local tabFirst, shownActive, shownCount = 1, nil, nil


local frame = CreateFrame("Frame", "AegisPathfinderObjectives", UIParent)
AegisPathfinder.objectiveframe = frame
-- Its hints open beside it, not over the steps they are about.
Theme:TipOutside(frame)
-- MEDIUM, the strata of the quest log, bags and character panel: clicking
-- one of them brings it over the guide, and clicking the guide brings the
-- guide back. In DIALOG it stayed in front of them whatever you clicked.
frame:SetFrameStrata("MEDIUM")
frame:SetWidth(G.DEFAULT_WIDTH)
frame:SetHeight(G.CHROME_TOP + G.ROWHEIGHT + G.FOOTER_H)
-- The concept parks it at top:180px; right:40px. There is no status card to
-- hang off any more, so it anchors to the screen.
frame:SetPoint(G.DEFAULT_ANCHOR[1], UIParent, G.DEFAULT_ANCHOR[2], G.DEFAULT_ANCHOR[3], G.DEFAULT_ANCHOR[4])
AegisPathfinder.objectiveskin = Theme:Panel(frame, "panel")
frame:Hide()
frame:SetScript("OnShow", function() AegisPathfinder:UpdateObjectivePanel() end)
--[[ Not in UISpecialFrames: Escape does not close the guide. It is on screen
	while you play, as the quest tracker is, and Escape is what clears a
	target or cancels a spell in a fight -- so the guide kept closing in
	combat. Its close chip closes it; the windows opened from it (options,
	guide list, Gear finder) still close on Escape. ]]
-- Stacks with the other windows rather than interleaving with them.
Theme:RegisterWindow(frame)

--- The tallest the panel may be: what the player set with the grip, or the
--- concept's min(70vh, 600px).
function AegisPathfinder:GetPanelCap()
	local cap = self.db.profile.objframemaxheight
	local screen = UIParent:GetHeight()
	if not cap then cap = math.min(G.DEFAULT_CAP, math.floor(screen * 0.7)) end
	return math.max(G.MIN_CAP, math.min(cap, screen - 20))
end


--[[ Resize grip.

	One generated texture rather than six placed dots: the cluster keeps its
	spacing, and hover is a single tint instead of a loop.

	Dragging it sideways sets the width; dragging it down or up sets the
	panel's height cap, which is the concept's grip exactly -- it writes
	`maxHeight`, not `height`. The panel's actual height is always what its
	content needs, up to that cap.

	It does its own sizing rather than calling StartSizing. The client's
	sizing re-anchors the frame as it sees fit, and a panel left anchored by
	its top and its bottom ignores SetHeight: that is how the panel got stuck
	at the size it had been dragged to, unable to follow the step or be moved.
]]
local grip = CreateFrame("Frame", nil, frame)
grip:SetWidth(14)
grip:SetHeight(14)
grip:SetPoint("BOTTOMRIGHT", -4, 4)
grip:EnableMouse(true)
grip:SetFrameLevel(frame:GetFrameLevel() + 4)
frame.grip = grip

local gripTex = grip:CreateTexture(nil, "OVERLAY")
gripTex:SetTexture(Theme.texture.grip)
gripTex:SetAllPoints(grip)
Theme:Tint(gripTex, "textDim", 0.55)

-- Cursor position in the panel's own units.
local function Cursor()
	local scale = frame:GetEffectiveScale()
	local x, y = GetCursorPosition()
	return x / scale, y / scale
end

local function StopSizing()
	grip.sizing = nil
	grip:SetScript("OnUpdate", nil)
	Theme:Tint(gripTex, "textDim", 0.55)
end

local function Sizing()
	local s = grip.sizing
	if not s then return end
	-- A button released somewhere the grip never heard about still ends it --
	-- where the client can say so (see OnMouseDown).
	if s.poll and not IsMouseButtonDown("LeftButton") then return StopSizing() end
	local x, y = Cursor()
	local db = AegisPathfinder.db.profile
	local w = math.max(G.MIN_WIDTH, math.min(G.MAX_WIDTH, math.floor(s.w + x - s.x + 0.5)))
	-- Screen y grows upward, so dragging down is a smaller y and a taller cap.
	local cap = math.max(G.MIN_CAP, math.min(UIParent:GetHeight() - 20, math.floor(s.cap + s.y - y + 0.5)))
	db.objframemaxheight = cap
	if w ~= frame:GetWidth() then
		db.objframewidth = w
		frame:SetWidth(w)          -- OnSizeChanged repaints
	else
		AegisPathfinder:UpdateOHPanel()
	end
end

grip:SetScript("OnMouseDown", function()
	Theme:Tint(gripTex, "accentGlow", 1)
	-- Grow right and down from where the panel is, whatever it was anchored by.
	Theme:AnchorTopLeft(frame)
	local x, y = Cursor()
	grip.sizing = {
		x = x, y = y, w = frame:GetWidth(), cap = AegisPathfinder:GetPanelCap(),
		-- Only poll the button if the client reports it down now, while it
		-- is: an IsMouseButtonDown that is missing or reads buttons some
		-- other way must not end every drag the moment it starts.
		poll = IsMouseButtonDown and IsMouseButtonDown("LeftButton") and true or false,
	}
	grip:SetScript("OnUpdate", Sizing)
end)
grip:SetScript("OnMouseUp", function()
	Sizing()
	StopSizing()
end)
grip:SetScript("OnEnter", function()
	Theme:Tint(gripTex, "accent", 1)
	Theme:ShowTip(this, "LEFT", "Drag to set the width and the tallest the panel may grow")
end)
grip:SetScript("OnLeave", function()
	if not grip.sizing then Theme:Tint(gripTex, "textDim", 0.55) end
	Theme:HideTip(this)
end)

--[[ Row anchors.

	Rows reach the scrollbar in overview, and the panel's edge in focus mode,
	where there is no scrollbar: anchored to a hidden one they left a strip of
	dead panel down the right-hand side.
]]
local rowsOverview
local function AnchorRows(overview)
	if rowsOverview == overview then return end
	rowsOverview = overview
	for i, row in ipairs(rows) do
		row:ClearAllPoints()
		if i == 1 then
			row:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -G.CHROME_TOP)
		else
			row:SetPoint("TOPLEFT", rows[i - 1], "BOTTOMLEFT", 0, 0)
		end
		if overview then
			row:SetPoint("RIGHT", scrollbar, "LEFT", -4, 0)
		else
			row:SetPoint("RIGHT", frame, "RIGHT", -1, 0)
		end
	end
end

-- The width a focus-mode note wraps to: the row, less the dot, the glyph and
-- the padding either side of the text.
local function NoteWidth()
	return frame:GetWidth() - 2 - (G.ROWPAD + G.DOTSIZE + 9 + G.ICONSIZE + 9) - G.ROWPAD
end

frame:SetScript("OnSizeChanged", function()
	if rows and rows[1] then
		AegisPathfinder:OnObjectiveFrameResized()
	end
end)


local function ResetScrollbar()
	local newval = math.max(0, (AegisPathfinder.current or 0) - NUMROWS / 2 - 1)
	local steps = AegisPathfinder.actions and table.getn(AegisPathfinder.actions) or 0

	scrollbar:SetMinMaxValues(0, math.max(steps - NUMROWS, 1))
	scrollbar:SetValue(newval)

	AegisPathfinder:UpdateOHPanel()
end

local function OnShow(f)
	local f = f or this
	AegisPathfinder.db.char.panelopen = true
	ResetScrollbar()
	Theme:FadeIn(f, 0.5)
	-- The action buttons come and go with the guide (ActiveFrames.lua).
	if AegisPathfinder.RefreshActiveFrames then AegisPathfinder:RefreshActiveFrames() end
end


local function HideTooltip()
	Theme:HideTip(this)
end


--[[ The ≡ menu.

	The header's first chip, as Zygor's: the guide browser, the setup wizard,
	locking the window where it is, a see-through panel, putting the windows
	back, reloading the UI, and the settings. It opens under the chip, above
	every window, and an item closes it.
]]
local GUIDE_MENU = {
	{ label = "Guide menu", glyph = "book", run = function() AegisPathfinder.guidelistframe:Show() end },
	{ label = "Setup wizard", glyph = "wand", run = function() AegisPathfinder:ShowSetup() end },
	"-",
	{ label = "Lock window", glyph = "lock", key = "objframelocked",
		run = function(on) AegisPathfinder:SetGuideLocked(on) end },
	{ label = "Transparency", glyph = "dashed", key = "objframetransparent",
		run = function(on) AegisPathfinder:SetGuideTransparent(on) end },
	"-",
	{ label = "Reset window", glyph = "reset", run = function() AegisPathfinder:ResetWindowLayout() end },
	{ label = "Reload", glyph = "reload", run = function() ReloadUI() end },
	"-",
	{ label = "Settings", glyph = "gear", run = function() AegisPathfinder:ToggleConfigPanel() end },
}
local MENU_W, MENU_ROW = 220, 28

--- Hold the guide where it is: no dragging it, and no grip to size it by.
function AegisPathfinder:SetGuideLocked(on)
	self.db.profile.objframelocked = on and true or nil
	if on then frame.grip:Hide() else frame.grip:Show() end
	-- The options' Appearance page has it too.
	if self.optionsframe and self.optionsframe:IsShown() and self.RefreshConfigPanel then self:RefreshConfigPanel() end
end

--- A see-through panel: its body at the Appearance page's opacity (half to
--- start with), and no shadow.
function AegisPathfinder:SetGuideTransparent(on)
	self.db.profile.objframetransparent = on and true or nil
	local skin = self.objectiveskin
	skin.fill:SetTint("panel", on and (self.db.profile.objframeopacity or 0.5) or 1)
	if skin.shadow then skin.shadow:SetTint({ 0, 0, 0 }, on and 0 or 0.62) end
	if self.optionsframe and self.optionsframe:IsShown() and self.RefreshConfigPanel then self:RefreshConfigPanel() end
end

--- How see-through Transparency makes the guide: 20% to 100%.
function AegisPathfinder:SetGuideOpacity(v)
	v = math.max(0.2, math.min(1, v or 0.5))
	self.db.profile.objframeopacity = v
	if self.db.profile.objframetransparent then self:SetGuideTransparent(true) end
	return v
end

-- A menu row's box, ticked while what it stands for is on.
local function MenuBox(row)
	local edge = row:CreateTexture(nil, "ARTWORK")
	edge:SetTexture(Theme.texture.solid)
	edge:SetWidth(14); edge:SetHeight(14)
	edge:SetPoint("RIGHT", row, "RIGHT", -12, 0)
	Theme:Tint(edge, "textDim")
	local fill = row:CreateTexture(nil, "OVERLAY")
	fill:SetTexture(Theme.texture.solid)
	fill:SetPoint("TOPLEFT", edge, "TOPLEFT", 1, -1)
	fill:SetPoint("BOTTOMRIGHT", edge, "BOTTOMRIGHT", -1, 1)
	local tick = row:CreateTexture(nil, "OVERLAY")
	tick:SetTexture(Theme.glyph.tick)
	tick:SetWidth(12); tick:SetHeight(12)
	tick:SetPoint("CENTER", edge, "CENTER", 0, 0)
	Theme:Tint(tick, "text")
	function row:SetChecked(on)
		self.on = on
		Theme:Tint(fill, on and "accentDeep" or "panel2")
		if on then tick:Show() else tick:Hide() end
	end
end

local function MenuRow(menu, item, y)
	local row = CreateFrame("Button", nil, menu)
	row:SetHeight(MENU_ROW)
	row:SetPoint("TOPLEFT", menu, "TOPLEFT", 1, y)
	row:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -1, y)
	local hl = row:CreateTexture(nil, "HIGHLIGHT")
	hl:SetTexture(Theme.texture.solid)
	hl:SetAllPoints(row)
	Theme:Tint(hl, "text", 0.06)
	local g = row:CreateTexture(nil, "ARTWORK")
	g:SetTexture(Theme.glyph[item.glyph])
	g:SetWidth(14); g:SetHeight(14)
	g:SetPoint("LEFT", row, "LEFT", 12, 0)
	Theme:Tint(g, "textDim")
	local fs = row:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(fs, "body", 13)
	fs:SetPoint("LEFT", row, "LEFT", 36, 0)
	fs:SetText(item.label)
	Theme:TextColor(fs, "text")
	row.item, row.label = item, fs
	if item.key then MenuBox(row) end
	row:SetScript("OnClick", function()
		local it = this.item
		if it.key then
			it.run(not this.on)
			this:SetChecked(AegisPathfinder.db.profile[it.key])
		else
			AegisPathfinder.guidemenu:Hide()
			it.run()
		end
	end)
	return row
end

--- Build the ≡ menu under `chip`.
function AegisPathfinder:BuildGuideMenu(chip)
	local menu = CreateFrame("Frame", "AegisPathfinderGuideMenu", UIParent)
	menu:SetFrameStrata("FULLSCREEN_DIALOG")
	menu:SetWidth(MENU_W)
	menu:SetPoint("TOPLEFT", chip, "BOTTOMLEFT", -2, -4)
	Theme:Panel(menu, "panel2")
	Theme:Scaled(menu)
	menu:EnableMouse(true)
	menu:Hide()
	menu.rows = {}
	local y = -6
	for _, item in ipairs(GUIDE_MENU) do
		if item == "-" then
			local rule = menu:CreateTexture(nil, "ARTWORK")
			rule:SetTexture(Theme.texture.solid)
			rule:SetHeight(1)
			rule:SetPoint("TOPLEFT", menu, "TOPLEFT", 12, y - 4)
			rule:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -12, y - 4)
			Theme:Tint(rule, "tabbg")
			y = y - 9
		else
			table.insert(menu.rows, MenuRow(menu, item, y))
			y = y - MENU_ROW
		end
	end
	menu:SetHeight(6 - y)
	menu:SetScript("OnShow", function()
		for _, row in ipairs(this.rows) do
			if row.item.key then row:SetChecked(AegisPathfinder.db.profile[row.item.key]) end
		end
	end)
	-- The guide closing closes its menu.
	chip:SetScript("OnHide", function() menu:Hide() end)
	table.insert(UISpecialFrames, "AegisPathfinderGuideMenu")
	self.guidemenu = menu
	return menu
end

function AegisPathfinder:UpdateObjectivePanel()
	frame:SetScript("OnShow", nil)

	--[[ Header.

		Every window in the concept wears the same strip, and it is what you
		drag the window by -- which is why the panel could not be moved before:
		it had a floating title above the frame and no handle at all.
	]]
	local header = Theme:Header(frame, G.HEADER_H)
	-- Growing upward, the panel is pinned, and kept, by its bottom edge.
	local savePosition = Theme:PositionSaver("objframe")
	header:MakeDragHandle(frame, function(f)
		if AegisPathfinder.db.profile.objframeupward then AegisPathfinder:AnchorGuideBottom() end
		savePosition(f)
	end)
	frame.savePosition = savePosition
	-- A locked window stays where it is.
	header:SetScript("OnDragStart", function()
		if not AegisPathfinder.db.profile.objframelocked then frame:StartMoving() end
	end)

	-- The ≡ menu. What it opens sits beside the guide, never instead of it.
	local menuChip = Theme:ChipButton(header, "menu")
	menuChip:SetPoint("LEFT", header, "LEFT", 8, 0)
	AegisPathfinder:BuildGuideMenu(menuChip)
	AegisPathfinder:SetGuideLocked(AegisPathfinder.db.profile.objframelocked)
	AegisPathfinder:SetGuideTransparent(AegisPathfinder.db.profile.objframetransparent)
	menuChip:SetScript("OnClick", function()
		local menu = AegisPathfinder.guidemenu
		Theme:HideTip(this)
		if menu:IsShown() then menu:Hide() else menu:Show() end
	end)
	menuChip:SetScript("OnEnter", function()
		this.fill:SetTint("text", 0.10)
		Theme:Tint(this.glyph, "text")
		Theme:ShowTip(this, "BOTTOM", "Menu")
	end)
	menuChip:SetScript("OnLeave", function()
		this.fill:SetTint("text", 0.04)
		Theme:Tint(this.glyph, "textDim")
		Theme:HideTip(this)
	end)

	--[[ Focus / overview.

		The concept's third chip. Focus mode -- the default -- shows the one
		step you are on and nothing else, which is how you follow a guide;
		overview shows the whole list, which is how you look ahead. The chip
		takes the accent fill while overview is on, so the panel says which
		of the two you are looking at.
	]]
	local expandChip = Theme:ChipButton(header, "expand")
	expandChip:SetPoint("LEFT", menuChip, "RIGHT", 6, 0)
	expandChip:SetScript("OnClick", function()
		AegisPathfinder:ToggleOverviewMode()
	end)
	expandChip:SetScript("OnEnter", function()
		if not this.__active then
			this.fill:SetTint("text", 0.10)
			Theme:Tint(this.glyph, "text")
		end
		Theme:ShowTip(this, "BOTTOM", AegisPathfinder.db.char.overviewmode
			and "Show one step at a time" or "Show all steps")
	end)
	expandChip:SetScript("OnLeave", function()
		if not this.__active then
			this.fill:SetTint("text", 0.04)
			Theme:Tint(this.glyph, "textDim")
		end
		Theme:HideTip(this)
	end)
	frame.expandChip = expandChip

	local closeChip = Theme:ChipButton(header, "close")
	closeChip:SetPoint("RIGHT", header, "RIGHT", -8, 0)
	closeChip:SetScript("OnClick", function()
		AegisPathfinder.db.char.panelopen = false
		frame:Hide()
	end)

	frame.header = header

	--[[ Tab bar.

		One tab per open guide. Tab 1 is the main route -- what auto-advance
		follows -- and anything after it is a guide opened beside it. Clicking a tab switches to it, resuming where
		you left it; the ✕ closes it; the + opens another.

		Tabs are built once as a pool, one per possible guide, and the bar
		shows a window onto them -- as many as fit at a readable width, four
		at most -- with ‹ › to scroll the rest into view. Switching guides
		never creates a frame.

		The badge says what the guide is (GuideBadge): XP for leveling, PF a
		profession, DG a dungeon, HC hardcore, TPL a placeholder -- in the one
		place you are looking while you follow it.
	]]
	local tabbar = CreateFrame("Frame", nil, frame)
	tabbar:SetHeight(G.TABBAR_H)
	tabbar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
	tabbar:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, 0)
	Theme:Strip(tabbar, "tabbg")
	Theme:Divider(tabbar, tabbar, "BOTTOMLEFT", 0, 0)

	local function MakeTab(index)
		local t = CreateFrame("Button", nil, tabbar)
		t:SetHeight(G.TABBAR_H - 5)
		t:SetWidth(G.TAB_W_MAX)
		t.index = index
		t.fill = Theme:NineSlice(t, Theme.texture.tabFill, "BACKGROUND", "tabbg")

		t.badge = Theme:Badge(t, "XP", "xp")
		t.badge:SetPoint("LEFT", t, "LEFT", 7, 0)

		t.label = t:CreateFontString(nil, "OVERLAY")
		Theme:SetFont(t.label, "body", 11)
		t.label:SetJustifyH("LEFT")
		Theme:TextColor(t.label, "textDim")

		--- Show or drop the badge, and let the name take the room either way.
		function t:SetBadgeShown(shown)
			self.label:ClearAllPoints()
			if shown then
				self.badge:Show()
				self.label:SetPoint("LEFT", self.badge, "RIGHT", 6, 0)
			else
				self.badge:Hide()
				self.label:SetPoint("LEFT", self, "LEFT", 8, 0)
			end
			self.label:SetPoint("RIGHT", self, "RIGHT", -18, 0)
		end
		t:SetBadgeShown(true)

		-- Every tab closes, the first included. Closing the last leaves the
		-- panel empty, waiting for a guide to be chosen.
		t.close = Theme:GlyphButton(t, "close", 8, 14)
		t.close:SetPoint("RIGHT", t, "RIGHT", -4, 0)
		t.close.index = index
		t.close:SetScript("OnClick", function()
			AegisPathfinder:CloseTab(this.index)
			AegisPathfinder:UpdateObjectiveTabs()
		end)
		t.close:SetScript("OnEnter", function()
			Theme:Tint(this.glyph, "text")
			Theme:ShowTip(this, "BOTTOM", "Close this guide")
		end)
		t.close:SetScript("OnLeave", function()
			Theme:Tint(this.glyph, "textDim")
			Theme:HideTip(this)
		end)

		function t:SetActive(active)
			if active then
				self.fill:SetTint("panel")
				Theme:TextColor(self.label, "text")
			else
				self.fill:SetTint("tabbg")
				Theme:TextColor(self.label, "textDim")
			end
		end

		t:SetScript("OnClick", function()
			AegisPathfinder:SwitchToTab(this.index)
			AegisPathfinder:UpdateObjectiveTabs()
		end)
		t:SetScript("OnEnter", function()
			local tab = AegisPathfinder.db.char.tabs and AegisPathfinder.db.char.tabs[this.index]
			if not tab then return end
			Theme:ShowTip(this, "BOTTOM", this.index == 1
				and ("Main route: " .. tab.guide)
				or ("Switch to " .. tab.guide))
		end)
		t:SetScript("OnLeave", function() Theme:HideTip(this) end)

		t:Hide()
		return t
	end

	-- Anchored as they are shown, by UpdateObjectiveTabs: which tab sits
	-- first depends on where the bar is scrolled to.
	for i = 1, G.MAX_TABS do
		guideTabs[i] = MakeTab(i)
	end

	--[[ Scrolling the bar.

		‹ at the left edge, › after the last tab in view, both only while
		there are more guides open than the bar shows. Each moves the view by
		one tab and dims at its end. The wheel over the bar does the same.
	]]
	local function TabArrow(glyphName, delta, tip)
		local b = Theme:GlyphButton(tabbar, glyphName, 9, G.ARROW_W)
		b:SetScript("OnClick", function()
			if this.__disabled then return end
			AegisPathfinder:ScrollObjectiveTabs(delta)
		end)
		b:SetScript("OnEnter", function()
			if this.__disabled then return end
			Theme:Tint(this.glyph, "accent")
			Theme:ShowTip(this, "BOTTOM", tip)
		end)
		b:SetScript("OnLeave", function()
			Theme:Tint(this.glyph, this.__disabled and "subtle" or "textDim")
			Theme:HideTip(this)
		end)
		function b:SetEnabled(on)
			self.__disabled = not on
			Theme:Tint(self.glyph, on and "textDim" or "subtle")
		end
		function b:IsEnabled() return not self.__disabled end
		b:Hide()
		return b
	end
	local tabLeft = TabArrow("chevronLeft", -1, "Earlier guides")
	local tabRight = TabArrow("chevronRight", 1, "Later guides")
	-- Centred on the tabs, which sit on the bar's bottom edge.
	tabLeft:SetPoint("LEFT", tabbar, "BOTTOMLEFT", 8, (G.TABBAR_H - 5) / 2)

	tabbar:EnableMouseWheel(true)
	tabbar:SetScript("OnMouseWheel", function()
		AegisPathfinder:ScrollObjectiveTabs(-(arg1 or 0))
	end)

	local addTab = Theme:GlyphButton(tabbar, "plus", 10, G.TABBAR_H - 9)
	Theme:NineSlice(addTab, Theme.texture.tabBorder, "BORDER", "subtle")
	addTab:SetScript("OnClick", function()
		-- Opens beside the guide, not instead of it.
		AegisPathfinder.guidelistframe:Show()
	end)
	addTab:SetScript("OnEnter", function()
		Theme:Tint(this.glyph, "accent")
		Theme:ShowTip(this, "BOTTOM", "Open another guide")
	end)
	addTab:SetScript("OnLeave", function()
		Theme:Tint(this.glyph, "textDim")
		Theme:HideTip(this)
	end)

	frame.tabbar = tabbar
	frame.guideTabs, frame.addTab = guideTabs, addTab
	frame.tabLeft, frame.tabRight = tabLeft, tabRight
	-- The first tab is the main route; plenty of older code still reaches for
	-- it by this name.
	frame.mainTab = guideTabs[1]

	--[[ Nav row: ← N → , with the count on the right.

		This replaces the 50px "current objective" block the panel used to
		carry. That block repeated the status card underneath it -- the same
		icon, title and note, twice on screen -- where the concept spends the
		row on moving through the guide instead.
	]]
	local navrow = CreateFrame("Frame", nil, frame)
	navrow:SetHeight(G.NAVROW_H)
	navrow:SetPoint("TOPLEFT", tabbar, "BOTTOMLEFT", 0, 0)
	navrow:SetPoint("TOPRIGHT", tabbar, "BOTTOMRIGHT", 0, 0)
	Theme:Strip(navrow, "tabbg")
	Theme:Divider(navrow, navrow, "BOTTOMLEFT", 0, 0)

	--[[ The arrows: a step back or on with a click; a right-click takes you
		back or on to your place in the guide (Core.lua's ReturnToPlace). ]]
	local function StepArrow(glyph, direction, move)
		local b = Theme:GlyphButton(navrow, glyph, 11, 20)
		b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		b:SetScript("OnClick", function()
			if arg1 == "RightButton" then
				AegisPathfinder:ReturnToPlace(direction)
			else
				AegisPathfinder:RememberPlace()
				move()
			end
		end)
		return b
	end

	local prevArrow = StepArrow("arrowLeft", -1, function() AegisPathfinder:GoToPreviousObjective() end)
	prevArrow:SetPoint("LEFT", navrow, "LEFT", G.ROWPAD - 4, 0)

	navStepNum = navrow:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(navStepNum, "display", 15)
	navStepNum:SetPoint("LEFT", prevArrow, "RIGHT", 6, 0)
	navStepNum:SetJustifyH("CENTER")
	navStepNum:SetWidth(44)
	Theme:TextColor(navStepNum, "text")

	local nextArrow = StepArrow("arrowRight", 1, function() AegisPathfinder:SkipToNextObjective() end)
	nextArrow:SetPoint("LEFT", navStepNum, "RIGHT", 6, 0)

	-- Marking the step done and moving on is a third action, and one the
	-- concept reaches by ticking the step. Kept here as well because the panel
	-- is where you go when a step will not complete itself.
	local doneArrow = Theme:GlyphButton(navrow, "tick", 11, 20)
	doneArrow:SetPoint("LEFT", nextArrow, "RIGHT", 2, 0)
	doneArrow:SetScript("OnClick", function()
		AegisPathfinder:SetTurnedIn()
		AegisPathfinder:UpdateStatusFrame()
	end)

	local function ArrowTip(btn, tip, detail)
		btn:SetScript("OnEnter", function()
			Theme:Tint(this.glyph, "text")
			Theme:ShowTip(this, "BOTTOM", tip, detail)
		end)
		btn:SetScript("OnLeave", function()
			Theme:Tint(this.glyph, "textDim")
			Theme:HideTip(this)
		end)
	end
	ArrowTip(prevArrow, "Previous objective", { "Right-click: back to your place in the guide" })
	ArrowTip(nextArrow, "Skip to next objective", { "Right-click: on to your place in the guide" })
	ArrowTip(doneArrow, "Mark complete and advance")
	navrow.stepControls = { prevArrow, nextArrow, doneArrow }

	navCount = navrow:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(navCount, "body", 10)
	navCount:SetPoint("RIGHT", navrow, "RIGHT", -G.ROWPAD, 0)
	navCount:SetJustifyH("RIGHT")
	Theme:TextColor(navCount, "textDim")

	frame.navrow = navrow
	navrow.count = navCount
	-- The party icon, for sharing the guide (PartySync.lua).
	if self.AttachShareButton then self:AttachShareButton(navrow) end

	-- Guide completion, as a 4px rule across the full width.
	guideProgress = Theme:ProgressBar(frame, G.PROGRESS_H)
	guideProgress:SetPoint("TOPLEFT", navrow, "BOTTOMLEFT", 0, 0)
	guideProgress:SetPoint("TOPRIGHT", navrow, "BOTTOMRIGHT", 0, 0)
	frame.guideProgress = guideProgress

	--[[ Footer.

		The concept replaced its slash-command hint with live state: the
		current step's quest id on the left, and how far through the guide you
		are on the right. Materials has no concept equivalent and is a view
		rather than a setting, so it keeps its button here; everything else the
		old button row carried lives where the concept puts it -- Config and
		Route behind the header's ☰, Guides behind the tab bar's +, and
		returning from a branch on the branch tab itself.
	]]
	local footer = CreateFrame("Frame", nil, frame)
	footer:SetHeight(G.FOOTER_H)
	footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
	footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
	Theme:CapStrip(footer, "panel2", "bottom")

	local footerRule = footer:CreateTexture(nil, "OVERLAY")
	footerRule:SetTexture(Theme.texture.solid)
	footerRule:SetHeight(1)
	footerRule:SetPoint("TOPLEFT", footer, "TOPLEFT", 0, 0)
	footerRule:SetPoint("TOPRIGHT", footer, "TOPRIGHT", 0, 0)
	Theme:Tint(footerRule, "border")

	footerCount = footer:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(footerCount, "body", 10)
	footerCount:SetPoint("RIGHT", footer, "RIGHT", -G.ROWPAD, 0)
	footerCount:SetJustifyH("RIGHT")
	Theme:TextColor(footerCount, "textDim")

	-- Up to the count and no further, on one line: a warning can be longer
	-- than a 396px footer has room for beside the count, and the whole of it
	-- is on the footer's tooltip.
	footerQid = footer:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(footerQid, "body", 10)
	footerQid:SetPoint("LEFT", footer, "LEFT", G.ROWPAD, 0)
	footerQid:SetPoint("RIGHT", footerCount, "LEFT", -8, 0)
	footerQid:SetHeight(12)
	footerQid:SetJustifyH("LEFT")
	Theme:TextColor(footerQid, "accent")

	footer:EnableMouse(true)
	footer:SetScript("OnEnter", function()
		if not this.warning then return end
		Theme:ShowTip(this, "TOP", this.warning, nil, "danger")
	end)
	footer:SetScript("OnLeave", function() Theme:HideTip(this) end)

	--[[ The shopping list opens from here, on a guide that has one. It says
		so in words: a bare icon in a footer is easy to miss, and on a craft
		step there is no quest id beside it to crowd. ]]
	local materials = Theme:GlyphButton(footer, Theme.actionIcon.B, 11, 18)
	materials:SetPoint("LEFT", footer, "LEFT", G.ROWPAD - 4, 0)
	materials.glyph:ClearAllPoints()
	materials.glyph:SetPoint("LEFT", materials, "LEFT", 4, 0)
	local matsLabel = materials:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(matsLabel, "display", 10)
	matsLabel:SetPoint("LEFT", materials.glyph, "RIGHT", 4, 0)
	matsLabel:SetText("SHOPPING LIST")
	Theme:TextColor(matsLabel, "textDim")
	materials.label = matsLabel
	materials:SetWidth(4 + 11 + 4 + math.ceil(matsLabel:GetStringWidth()) + 4)
	materials:SetScript("OnClick", function() AegisPathfinder:ToggleMaterialsPanel() end)
	materials:SetScript("OnEnter", function()
		Theme:Tint(this.glyph, "accent")
		Theme:TextColor(this.label, "accent")
		Theme:ShowTip(this, "TOP", "Reagents for this craft and the rest of the guide")
	end)
	materials:SetScript("OnLeave", function()
		Theme:Tint(this.glyph, "textDim")
		Theme:TextColor(this.label, "textDim")
		Theme:HideTip(this)
	end)
	materials:Hide()
	footer.materials = materials

	frame.footer = footer

	scrollbar, upbutt, downbutt = Theme:ScrollBar(frame)
	scrollbar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -7, -(G.CHROME_TOP + 14))
	scrollbar:SetPoint("BOTTOM", frame, "BOTTOM", 0, G.FOOTER_H + 18)
	scrollbar:SetScript("OnValueChanged", function() local val = arg1 self:UpdateOHPanel(val) end)

	upbutt:SetScript("OnClick", function()
		scrollbar:SetValue(offset - NUMROWS + 1)
		PlaySound("UChatScrollButton")
	end)

	downbutt:SetScript("OnClick", function()
		scrollbar:SetValue(offset + NUMROWS - 1)
		PlaySound("UChatScrollButton")
	end)

	--[[ Step rows.

		Each slot carries both of the concept's row models and shows one of
		them. A `.zrow` dot/glyph/title/note, or -- for an ACCEPT or TURNIN
		that is current or done -- the coloured band laid over the whole slot.
	]]
	for i = 1, G.MAX_ROWS do
		local row = CreateFrame("Button", nil, frame)
		row:SetHeight(G.ROWHEIGHT)

		-- Faint wash on the active step, plus the left accent bar. Both
		-- reach down over the objective meter when it shows (ReachActiveRow).
		row.bg = row:CreateTexture(nil, "BACKGROUND")
		row.bg:SetTexture(Theme.texture.solid)
		row.bg:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
		row.bg:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
		row.bg:SetVertexColor(1, 1, 1, 0.035)
		row.bg:Hide()

		row.activebar = row:CreateTexture(nil, "BORDER")
		row.activebar:SetTexture(Theme.texture.solid)
		row.activebar:SetWidth(2)
		row.activebar:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
		row.activebar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
		Theme:Tint(row.activebar, "accent")
		row.activebar:Hide()

		-- Top-aligned, as the concept's flex-start row is: a row that grows
		-- for a long note keeps its dot, glyph and title where they were.
		local check = Theme:StepCheck(row, G.DOTSIZE)
		check:SetPoint("TOPLEFT", row, "TOPLEFT", G.ROWPAD, -(G.ROWHEIGHT - G.DOTSIZE) / 2)

		local icon = row:CreateTexture(nil, "ARTWORK")
		icon:SetWidth(G.ICONSIZE); icon:SetHeight(G.ICONSIZE)
		icon:SetPoint("LEFT", check, "RIGHT", 9, 0)

		-- Title over note. In the list both are clipped to one line: the
		-- concept stacks them, and a fixed row height is what lets a 268-step
		-- guide scroll. Focus mode gives the title the lines it needs.
		local text = row:CreateFontString(nil, "OVERLAY")
		Theme:SetFont(text, "body", 12)
		text:SetPoint("TOPLEFT", icon, "TOPRIGHT", 9, 1)
		text:SetPoint("RIGHT", row, "RIGHT", -G.ROWPAD, 0)
		text:SetJustifyH("LEFT")
		text:SetJustifyV("TOP")
		text:SetHeight(G.TITLE_H)
		Theme:TextColor(text, "text")

		local detail = row:CreateFontString(nil, "OVERLAY")
		Theme:SetFont(detail, "body", 11)
		detail:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -2)
		detail:SetPoint("RIGHT", row, "RIGHT", -G.ROWPAD, 0)
		detail:SetJustifyH("LEFT")
		detail:SetHeight(15)
		-- #8f8f86 in the concept: dimmer than --text-dim, so the note reads as
		-- support for the title rather than competing with it.
		detail:SetTextColor(0.56, 0.56, 0.52)

		--[[ The same note, in full. Focus mode shows one step, so it has the
			room to show all of it and grows to fit; the one-line version
			above is for the list, where a fixed row height is what lets a
			268-step guide scroll. Anchored by one corner and given a width,
			so its height is the wrapped text's and can be read back. ]]
		local note = row:CreateFontString(nil, "OVERLAY")
		Theme:SetFont(note, "body", 11)
		note:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -2)
		note:SetJustifyH("LEFT")
		note:SetJustifyV("TOP")
		note:SetTextColor(0.56, 0.56, 0.52)
		note:Hide()

		--[[ The band, covering the slot when this step is an ACCEPT or TURNIN
			that is current or done. Its own button so a click anywhere on it
			toggles the step, as the concept has it. ]]
		local band = Theme:Band(row, G.ROWHEIGHT)
		band:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
		band:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
		band:Hide()

		local bandTag = band:CreateFontString(nil, "OVERLAY")
		Theme:SetFont(bandTag, "body", 9)
		bandTag:SetPoint("RIGHT", band, "RIGHT", -10, 0)
		bandTag:SetTextColor(1, 1, 1)
		band.tag = bandTag

		check:SetScript("OnClick", function()
			self:SetTurnedIn(row.i, this:GetChecked())
		end)

		row:SetScript("OnClick", function() AegisPathfinder:GoToObjective(row.i) end)
		band:SetScript("OnClick", function() AegisPathfinder:GoToObjective(row.i) end)

		row:SetScript("OnEnter", function()
			if this.__tip then
				Theme:ShowTip(this, "RIGHT", this.__tip)
			end
		end)
		row:SetScript("OnLeave", HideTooltip)

		row.text = text
		row.detail = detail
		row.note = note
		row.check = check
		row.icon = icon
		row.band = band
		rows[i] = row
	end
	AnchorRows(self.db.char.overviewmode and true or false)

	--[[ The objective meter.

		The concept shows it under the single step in focus mode: what the
		quest wants, how much of it you have, and a bar. This is quest-log
		leaderboard text -- "Kobold Vermin slain: 3/8" -- which the panel used
		to flatten into the step's note line, where the numbers were easy to
		miss. Overview mode still does that, as the concept does.

		A line for each objective with a count, so Crocolisk Hunting's meat
		and skins get a bar each (PaintMeter).
	]]
	meter = CreateFrame("Frame", nil, frame)
	meter:SetPoint("TOPLEFT", rows[1], "BOTTOMLEFT", G.ROWPAD, -2)
	meter:SetPoint("RIGHT", frame, "RIGHT", -G.ROWPAD, 0)
	Theme:NineSlice(meter, Theme.texture.tabFill, "BACKGROUND", "text", 0.04)
	Theme:NineSlice(meter, Theme.texture.tabBorder, "BORDER", "border")
	meter:Hide()
	meter.lines = {}
	local first = MeterLine(meter, 1)
	meter:SetHeight(MeterHeight(1))
	meter.label, meter.count, meter.bar = first.label, first.count, first.bar
	frame.meter = meter

	local empty = CreateFrame("Button", nil, frame)
	empty:SetHeight(G.ROWHEIGHT)
	empty:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -G.CHROME_TOP)
	empty:SetPoint("RIGHT", frame, "RIGHT", -1, 0)
	local emptyText = empty:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(emptyText, "body", 12)
	emptyText:SetPoint("CENTER", empty, "CENTER", 0, 0)
	emptyText:SetText("Click here to load a guide")
	Theme:TextColor(emptyText, "textDim")
	empty:SetScript("OnClick", function() AegisPathfinder.guidelistframe:Show() end)
	empty:SetScript("OnEnter", function() Theme:TextColor(emptyText, "accent") end)
	empty:SetScript("OnLeave", function() Theme:TextColor(emptyText, "textDim") end)
	empty.text = emptyText
	empty:Hide()
	frame.emptyState = empty

	frame:EnableMouseWheel()
	frame:SetScript("OnMouseWheel", function()
		scrollbar:SetValue(offset - arg1)
	end)

	-- Restore saved width and position. The height is never restored: it is
	-- whatever the content needs. A height saved by an older version was the
	-- overview height the player dragged to, which is what the cap now is.
	local profile = self.db.profile
	if profile.objframeheight then
		profile.objframemaxheight = profile.objframemaxheight or profile.objframeheight
		profile.objframeheight = nil
	end
	-- Earlier versions saved the width on every resize, the first layout
	-- included, so the old 630px default is stored for nearly everyone
	-- whether or not they chose it. Only a width set with the grip is kept.
	if profile.objframewidth == G.OLD_DEFAULT_WIDTH then profile.objframewidth = nil end
	if profile.objframewidth then
		frame:SetWidth(math.max(G.MIN_WIDTH, math.min(G.MAX_WIDTH, profile.objframewidth)))
	end
	Theme:RestorePosition(frame, "objframe")
	frame.expandChip:SetActive(self.db.char.overviewmode)
	-- The Appearance page's step text size and progress bar.
	self:SetStepTextSize(self.db.profile.steptextsize, true)
	self:SetGuideProgressShown(self.db.profile.showprogress ~= false, true)

	self:OnObjectiveFrameResized()

	frame:SetScript("OnShow", OnShow)
	frame:SetScript("OnHide", function()
		if AegisPathfinder.RefreshActiveFrames then AegisPathfinder:RefreshActiveFrames() end
	end)
	OnShow(frame)
	return frame
end


--- Redraw the tab bar from the list of open guides.
function AegisPathfinder:UpdateObjectiveTabs()
	if not frame.guideTabs or not frame.guideTabs[1] then return end

	local tabs = self:EnsureTabs()
	local count = math.min(table.getn(tabs), G.MAX_TABS)
	local active = self.db.char.activetab or 1

	-- How many tabs fit at a readable width: 8px in from the left, the + and
	-- its gap on the right, and room for the arrows once they are needed.
	local function fit(room)
		local n = math.floor((room + G.TAB_GAP) / (G.TAB_W_MIN + G.TAB_GAP))
		return math.max(1, math.min(G.VISIBLE_TABS, n))
	end
	local room = frame:GetWidth() - 2 - 8 - (G.ADD_W + 4) - 8
	local overflow = count > fit(room)
	if overflow then room = room - 2 * (G.ARROW_W + 2) end
	local visible = math.min(count, fit(room))

	-- Follow the active tab when it changes -- a switch, an open, a close --
	-- and otherwise leave the view where the arrows put it, so a repaint does
	-- not yank it back.
	if active ~= shownActive or count ~= shownCount then
		if active < tabFirst then
			tabFirst = active
		elseif active > tabFirst + visible - 1 then
			tabFirst = active - visible + 1
		end
		shownActive, shownCount = active, count
	end
	tabFirst = math.max(1, math.min(tabFirst, count - visible + 1))
	local lastShown = tabFirst + visible - 1

	local width = G.TAB_W_MAX
	if visible > 0 then
		width = math.floor((room - (visible - 1) * G.TAB_GAP) / visible)
		if width > G.TAB_W_MAX then width = G.TAB_W_MAX end
	end

	local prev
	for i = 1, G.MAX_TABS do
		local button = frame.guideTabs[i]
		local tab = tabs[i]
		if not tab or i < tabFirst or i > lastShown then
			button:Hide()
		else
			button:ClearAllPoints()
			if prev then
				button:SetPoint("BOTTOMLEFT", prev, "BOTTOMRIGHT", G.TAB_GAP, 0)
			else
				button:SetPoint("BOTTOMLEFT", frame.tabbar, "BOTTOMLEFT",
					overflow and (8 + G.ARROW_W + 2) or 8, 0)
			end
			button:Show()
			button:SetWidth(width)
			button:SetBadgeShown(width >= G.BADGE_MIN)
			-- The pack prefix ("Optimized/") is the same on every tab and
			-- costs a third of a narrow one; the tooltip keeps the full name.
			button.label:SetText((string.gsub(tab.guide, "^.*/", "")))
			button.badge:SetKind(self:GuideBadge(tab.guide))
			button:SetActive(i == active)
			prev = button
		end
	end

	if overflow then
		frame.tabLeft:Show()
		frame.tabRight:Show()
		frame.tabLeft:SetEnabled(tabFirst > 1)
		frame.tabRight:SetEnabled(lastShown < count)
		frame.tabRight:ClearAllPoints()
		frame.tabRight:SetPoint("LEFT", prev, "RIGHT", 2, 0)
	else
		frame.tabLeft:Hide()
		frame.tabRight:Hide()
	end

	-- The + follows whatever is last, rather than floating where a closed
	-- tab used to be.
	frame.addTab:ClearAllPoints()
	if overflow then
		frame.addTab:SetPoint("LEFT", frame.tabRight, "RIGHT", 4, 0)
	elseif prev then
		frame.addTab:SetPoint("LEFT", prev, "RIGHT", 4, 0)
	else
		frame.addTab:SetPoint("LEFT", frame.tabbar, "LEFT", 8, 0)
	end

	-- Past MAX_TABS there is nowhere to put another tab, so stop offering.
	if table.getn(tabs) >= G.MAX_TABS then frame.addTab:Hide() else frame.addTab:Show() end
end

--- Move the tab bar's view by `delta` tabs. Only the view: the guide you are
--- reading stays the one you are reading until you click a tab.
function AegisPathfinder:ScrollObjectiveTabs(delta)
	tabFirst = tabFirst + (delta or 0)
	self:UpdateObjectiveTabs()
end

--[[ The panel with every guide closed.

	The rows, the meter and the counts all describe a guide, so they go, and
	the list area becomes one line inviting the player to pick one. It is a
	button: clicking it opens the guide list, which is where a guide comes
	from.
]]
function AegisPathfinder:ShowEmptyState(empty)
	if not frame.emptyState then return end
	if empty then
		for _, row in ipairs(rows) do row:Hide() end
		meter:Hide()
		scrollbar:Hide()
		navStepNum:SetText("")
		navCount:SetText("")
		guideProgress:SetProgress(0)
		footerQid:SetText("")
		footerCount:SetText("")
		frame.footer.materials:Hide()
		frame.emptyState:Show()
	else
		frame.emptyState:Hide()
	end
	-- Stepping through a guide needs a guide.
	for _, b in ipairs(frame.navrow.stepControls) do
		if empty then b:Hide() else b:Show() end
	end
end

--[[ Size the panel to what it shows.

	The concept's panel is height:auto under a max-height: focus mode is as
	tall as the one step (its note in full) and the meter under it; overview
	is as tall as the list, which for any real guide means the cap. Nothing
	here is saved -- the cap is the player's, the height is the content's.

	The panel is pinned by a top corner before its height changes, so it
	grows and shrinks from the bottom edge rather than moving its header.
]]
function AegisPathfinder:PanelContentHeight()
	if self:HasNoGuide() then return G.ROWHEIGHT + 6 end
	if self.db.char.overviewmode then
		local total = self.actions and table.getn(self.actions) or 0
		return math.max(1, math.min(total, G.MAX_ROWS)) * G.ROWHEIGHT + 2
	end
	local h = rows[1] and rows[1]:GetHeight() or G.ROWHEIGHT
	if frame.meter and frame.meter:IsShown() then
		h = h + 2 + frame.meter:GetHeight()
	end
	if frame.partyblock and frame.partyblock:IsShown() then
		h = h + 2 + frame.partyblock:GetHeight()
	end
	-- The steps after it that the Step Display page asks for.
	local n = self:VisibleRowCount()
	if n > 1 then h = h + 2 end
	for i = 2, n do
		if rows[i] and rows[i]:IsShown() then h = h + rows[i]:GetHeight() end
	end
	return h + 8
end

function AegisPathfinder:LayoutPanelHeight()
	if not frame.footer then return end
	-- SetHeight fires OnSizeChanged, which resizes, which repaints, which
	-- lands back here; without this guard the first layout never returns.
	if frame.layoutlock then return end

	local h = G.CHROME_TOP + self:PanelContentHeight() + G.FOOTER_H
	h = math.min(h, self:GetPanelCap())

	frame.layoutlock = true
	local point = frame:GetPoint(1)
	-- Growing upward (the Appearance page), from the bottom edge; else down
	-- from the top.
	local edge = self.db.profile.objframeupward and "^BOTTOM" or "^TOP"
	if frame:GetNumPoints() ~= 1 or not point or not string.find(point, edge) then
		if edge == "^BOTTOM" then self:AnchorGuideBottom() else Theme:AnchorTopLeft(frame) end
	end
	frame:SetHeight(h)
	frame.layoutlock = nil
end

--[[ How many step rows to draw right now.

	Focus mode draws exactly one whatever the panel's height. Overview draws
	as many as fit. Derived from the panel's current size on every call rather
	than cached, because the mode and the height both change and a cached count
	left the list a paint behind whichever changed last.
]]
function AegisPathfinder:VisibleRowCount()
	if not self.db.char.overviewmode then
		-- The step you are on, and as many after it as the Step Display page
		-- asks for, where the guide has them.
		local want = math.max(1, math.min(G.MAX_FOCUS, self.db.char.focussteps or 1))
		local left = (self.actions and self.current) and (table.getn(self.actions) - self.current + 1) or 1
		return math.max(1, math.min(want, left))
	end
	local fits = math.floor((frame:GetHeight() - G.CHROME_TOP - G.FOOTER_H) / G.ROWHEIGHT)
	return math.max(1, math.min(fits, G.MAX_ROWS))
end

function AegisPathfinder:OnObjectiveFrameResized()
	-- Mid-layout the panel is already being told what size to be.
	if frame.layoutlock then return end
	-- The width is saved by the grip, which is the player choosing it; a
	-- resize for any other reason is not a choice worth remembering.

	NUMROWS = self:VisibleRowCount()
	for i, row in ipairs(rows) do
		if i > NUMROWS then row:Hide() end
	end
	-- Tabs share the bar's width, so a narrower panel narrows them.
	self:UpdateObjectiveTabs()

	if scrollbar and self.actions then
		scrollbar:SetMinMaxValues(0, math.max(table.getn(self.actions) - NUMROWS, 1))
	end

	if frame:IsVisible() and self.current then
		self:UpdateOHPanel()
	end
end


--[[ Which steps the concept renders as a coloured band rather than a row.

	Quest hand-offs, and only those: they are the steps where standing in the
	right place is not enough, and the band is what stops one being scrolled
	past. Everything else is a plain row.
]]
local BANDABLE = { ACCEPT = true, TURNIN = true }

local VERB = {
	ACCEPT = { "Accept", "Accepted" },
	TURNIN = { "Turn in", "Turned in" },
}


--- Flip between showing the one step you are on and showing the whole guide.
function AegisPathfinder:ToggleOverviewMode()
	self.db.char.overviewmode = not self.db.char.overviewmode
	if frame.expandChip then frame.expandChip:SetActive(self.db.char.overviewmode) end
	-- The panel's height, the row count and the scrollbar all follow the mode.
	self:LayoutPanelHeight()
	self:OnObjectiveFrameResized()
	self:UpdateOHPanel()
end

--[[ Put every window back where it opens by default, at its default size.

	The way out when a window has ended up somewhere unusable. Positions and
	the panel's width and cap are forgotten; the guide goes back to the
	concept's top-right spot, the arrow to the top of the screen, and the
	panels that snap beside the guide do so again when next opened.
]]
local WINDOW_KEYS = {
	"objframe", "optionsframe", "guidelistframe", "materialsframe", "craftframe",
	"errorlogframe", "startzoneframe", "navcallout", "creditsframe",
}

function AegisPathfinder:ResetWindowLayout()
	for _, key in ipairs(WINDOW_KEYS) do Theme:ForgetPosition(key) end
	local profile = self.db.profile
	profile.objframewidth, profile.objframemaxheight, profile.objframeheight = nil, nil, nil
	profile.optionswidth, profile.optionsheight = nil, nil
	if self.optionsframe and self.SizeConfigWindow then self:SizeConfigWindow() end
	profile.guidelistwidth, profile.guidelistheight = nil, nil
	if self.SizeGuideBrowser then self:SizeGuideBrowser() end

	frame:ClearAllPoints()
	frame:SetPoint(G.DEFAULT_ANCHOR[1], UIParent, G.DEFAULT_ANCHOR[2], G.DEFAULT_ANCHOR[3], G.DEFAULT_ANCHOR[4])
	frame:SetWidth(G.DEFAULT_WIDTH)
	self:LayoutPanelHeight()
	self:UpdateOHPanel()

	if self.navcallout then
		self.navcallout:ClearAllPoints()
		self.navcallout:SetPoint("TOP", UIParent, "TOP", 0, -120)
	end
	if self.ResetActiveFrames then self:ResetActiveFrames() end
	-- By name: any of these may not have been built yet.
	for _, key in ipairs({ "errorLogFrame", "startingZoneSelectorFrame", "creditsframe" }) do
		local w = self[key]
		if w then
			w:ClearAllPoints()
			w:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		end
	end
	-- These place themselves beside the guide as they open.
	for _, key in ipairs({ "optionsframe", "guidelistframe", "materialsframe", "craftframe" }) do
		local w = self[key]
		if w and w:IsShown() then w:Hide(); w:Show() end
	end
	-- Resizing the panel above saves its width as it goes; forget it again.
	profile.objframewidth = nil
	self:Print("Windows reset to where they open by default.")
end

--[[ A step's quest-log objective, as label and counts.

	The leaderboard text is "Kobold Vermin slain: 3/8"; the meter wants the
	three parts separately. Anything that does not parse is handed back whole
	as the label, with no counts, because a guide can carry objectives that are
	not countable ("Speak to Marshal Dughan").
]]
local function ReadLeaderboard(logi)
	if not logi then return nil end
	for j = 1, GetNumQuestLeaderBoards(logi) do
		local text, _, done = GetQuestLogLeaderBoard(j, logi)
		if text and not done then
			local _, _, label, have, need = string.find(text, "^(.-):%s*(%d+)%s*/%s*(%d+)%s*$")
			if label then
				return label, tonumber(have), tonumber(need)
			end
			return text, nil, nil
		end
	end
	return nil
end
AegisPathfinder.ReadLeaderboard = ReadLeaderboard

--[[ The step's accent bar and wash reach down over the meter under it, so its
	objectives read as part of the step, to the footer (the panel's 8px below
	its content) or, with the party block under the meter, to the meter's
	edge. Without a meter they fit the row again. ]]
function AegisPathfinder:ReachActiveRow(toMeter)
	local row = rows[1]
	if not row then return end
	local to, x, y = row, 0, 0
	if toMeter then
		local party = frame.partyblock and frame.partyblock:IsShown()
		to, x, y = meter, -G.ROWPAD, party and 0 or -8
	end
	row.activebar:ClearAllPoints()
	row.activebar:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	row.activebar:SetPoint("BOTTOMLEFT", to, "BOTTOMLEFT", x, y)
	row.bg:ClearAllPoints()
	row.bg:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
	row.bg:SetPoint("BOTTOMLEFT", to, "BOTTOMLEFT", x, y)
end

--- Fill the meter from quest log entry `logi`: a line for each objective
--- with a count, finished ones full. Returns whether there was anything to
--- count; the meter is as tall as its lines.
function AegisPathfinder:PaintMeter(logi)
	local n = 0
	for j = 1, GetNumQuestLeaderBoards(logi) do
		local text = GetQuestLogLeaderBoard(j, logi)
		local _, _, label, have, need = string.find(text or "", "^(.-):%s*(%d+)%s*/%s*(%d+)%s*$")
		have, need = tonumber(have), tonumber(need)
		if label and need and need > 0 then
			n = n + 1
			local line = MeterLine(meter, n)
			line.label:SetText(label)
			line.count:SetText(string.format("%d / %d", have, need))
			line.bar:SetProgress(have / need)
			line.label:Show(); line.count:Show(); line.bar:Show()
		end
	end
	for k = n + 1, table.getn(meter.lines) do
		local line = meter.lines[k]
		line.label:Hide(); line.count:Hide(); line.bar:Hide()
	end
	if n > 0 then meter:SetHeight(MeterHeight(n)) end
	return n > 0
end

local accepted = {}
local acceptedDirty = true
function AegisPathfinder:UpdateOHPanel(value)
	if not frame or not frame:IsVisible() then return end

	self:UpdateObjectiveTabs()

	local empty = self:HasNoGuide()
	self:ShowEmptyState(empty)
	if empty then
		self:LayoutPanelHeight()
		return
	end

	-- The panel can be opened before any guide is parsed; everything below reads
	-- the step list and the current step directly.
	if not self.actions or not self.current then return end

	local total = table.getn(self.actions)
	--[[ Focus mode shows exactly one row: the step you are on.

		Everything below still walks the fixed row slots, so the two modes are
		the same code with a different window onto the step list -- one slot
		starting at the current step, or NUMROWS slots starting at the scroll
		offset. ]]
	local overview = self.db.char.overviewmode and true or false
	AnchorRows(overview)

	--[[ The meter, then the height, then the row count -- in that order.

		Focus mode's height depends on whether the meter is showing, and how
		many rows fit depends on the height, so settling them in any other
		order leaves the list a paint behind whichever changed last.

		The meter is only for a step whose quest is in the log with countable
		objectives left; a step with nothing to count gets no meter rather
		than an empty one.
	]]
	local showMeter = false
	if not overview then
		local curAction = self:GetObjectiveInfo(self.current)
		local _, curLogi, curComplete = self:GetObjectiveStatus(self.current)
		if curAction == "COMPLETE" and curLogi and not curComplete then
			showMeter = self:PaintMeter(curLogi)
		end
	end
	if showMeter then meter:Show() else meter:Hide() end
	-- Party members sharing the guide, under the meter or the step
	-- (PartySync.lua); the panel's height counts them.
	if self.PaintPartyBlock then
		if showMeter then self:PaintPartyBlock(frame, meter, 0) else self:PaintPartyBlock(frame, rows[1], G.ROWPAD) end
	end
	self:ReachActiveRow(showMeter)
	if self.PaintShareButton then self:PaintShareButton() end
	self:LayoutPanelHeight()

	local shown = self:VisibleRowCount()
	NUMROWS = shown

	if self.guidechanged then
		self.guidechanged = nil
		acceptedDirty = true
		ResetScrollbar()
	end

	if overview then
		if value then offset = math.floor(value) end
		if (offset + NUMROWS) > total then offset = total - NUMROWS end
		if offset < 0 then offset = 0 end

		if offset == 0 then upbutt:Disable() else upbutt:Enable() end
		if offset == (total - NUMROWS) then downbutt:Disable() else downbutt:Enable() end
		scrollbar:Show()
	else
		-- One step, so there is nothing to scroll past.
		offset = self.current - 1
		scrollbar:Hide()
	end

	if not value or acceptedDirty then
		for i in pairs(accepted) do accepted[i] = nil end

		if self.actions then
			for i in pairs(self.actions) do
				local action, name = self:GetObjectiveInfo(i)
				local _, _, quest = string.find(name, L.PART_FIND)
				if quest and not accepted[quest] and not self:GetObjectiveStatus(i) then accepted[quest] = name end
			end
		end
		acceptedDirty = false
	end

	local doneCount = 0

	for i, row in ipairs(rows) do
		if i > shown then row:Hide()
		else
		row.i = i + offset
		local idx = i + offset
		local action, name = self:GetObjectiveInfo(idx)
		if not name then row:Hide()
		else
			local turnedin, logi, complete, skipped = self:GetObjectiveStatus(idx)
			-- A hand-in for a quest you have not picked up is passed over when
			-- the guide reaches it, not before: further down it is not done.
			if skipped and idx > (self.current or 1) then turnedin = false end
			local optional, intown = self:GetObjectiveTag("O", idx), self:GetObjectiveTag("T", idx)
			local isActive = (idx == self.current)
			row:Show()

			local shortname = string.gsub(name, L.PART_GSUB, "")
			logi = not turnedin and (not accepted[shortname] or (accepted[shortname] == name)) and logi
			complete = not turnedin and (not accepted[shortname] or (accepted[shortname] == name)) and complete
			local checked = turnedin or action == "ACCEPT" and logi or action == "COMPLETE" and complete

			local note = self:GetObjectiveTag("N", idx)
			-- A boss step's lines for your role, under its note: shown in
			-- full in focus mode, and in the overview row's tooltip.
			local fullnote = self.GetStepNote and self:GetStepNote(idx) or note

			-- In overview the objective folds into the note line, which is
			-- what the concept does with it there. In focus mode the meter
			-- below carries it instead, so the note stays the note.
			if overview and action == "COMPLETE" and logi and not complete then
				local label, have, need = ReadLeaderboard(logi)
				if label then
					note = need and string.format("%s - %d/%d", label, have, need) or label
				end
			end

			local qid = self:GetObjectiveTag("QID", idx)
			row.__tip = (qid and ("QID " .. qid .. (fullnote and " \194\183 " or "")) or "") .. (fullnote or "")
			if row.__tip == "" then row.__tip = nil end

			--[[ Band or row.

				A quest hand-off you are standing on, or have done, is a band;
				the same step further down the list is an ordinary row, so the
				list does not turn into a wall of colour.
			]]
			if BANDABLE[action] and (checked or isActive) then
				row:SetHeight(G.ROWHEIGHT)
				row.note:Hide()
				row.bg:Hide()
				row.activebar:Hide()
				row.check:Hide()
				row.icon:Hide()
				row.text:Hide()
				row.detail:Hide()

				local verb = VERB[action][checked and 2 or 1]
				row.band:Show()
				row.band:SetDone(checked)
				row.band.icon:SetTexture(checked and Theme.glyph.tick or Theme.glyph.bang)
				row.band.icon:SetVertexColor(1, 1, 1, 1)
				row.band.label:SetText(string.format("[%d] %s '%s'", idx, verb, name))
				row.band.tag:SetText(optional and "OPTIONAL" or "")
			else
				row.band:Hide()
				row.check:Show()
				row.icon:Show()
				row.text:Show()
				row.detail:Show()

				row.bg:Hide()
				row.activebar:Hide()

				if isActive then
					row.bg:SetVertexColor(1, 1, 1, 0.035)
					row.bg:Show()
					row.activebar:Show()
					Theme:TextColor(row.text, "text")
				elseif checked then
					-- The concept dims a done step rather than hiding it.
					Theme:TextColor(row.text, "subtle")
				elseif intown then
					-- |T| in-town steps keep a hint of accent.
					row.bg:SetVertexColor(Theme.color.accent[1], Theme.color.accent[2],
						Theme.color.accent[3], 0.06)
					row.bg:Show()
					Theme:TextColor(row.text, "accentGlow")
				else
					Theme:TextColor(row.text, "textDim")
				end

				row.check:SetAutoEligible(self:IsAutoDetectable(action, idx))
				row.check:SetChecked(checked)

				row.icon:SetTexture(self.icons[action])
				Theme:Tint(row.icon, checked and "subtle" or "textDim")

				row.text:SetText(string.format("[%d] %s", idx, name)
					.. (optional and L[" |cff808080(Optional)"] or ""))
				row.detail:SetText(note or "")

				-- The list keeps every row one height; the one step in focus
				-- mode shows its whole note and grows to fit it.
				if overview then
					row.note:Hide()
					row.detail:Show()
					row.text:SetHeight(G.TITLE_H)
					row:SetHeight(G.ROWHEIGHT)
				else
					--[[ The title wraps to the panel's width, so a narrow panel
						shows all of it rather than "This has 4 different possible
						spawn...". The lines are counted from its unwrapped width,
						with a little slack for where the words break, as a switch
						label's are: a wrapped font string's own height is not to
						be trusted on 1.12. ]]
					local room = NoteWidth()
					local sw = row.text:GetStringWidth() or 0
					local lines = sw <= room and 1 or math.ceil(sw / (room * 0.95))
					local titleH = G.TITLE_H + (lines - 1) * G.TITLE_LINE
					row.text:SetHeight(titleH)
					row.detail:Hide()
					row.note:SetWidth(NoteWidth())
					row.note:SetText(fullnote or "")
					row.note:Show()
					local noteH = 0
					if fullnote and fullnote ~= "" then
						noteH = row.note:GetHeight() or 0
						-- A client that will not measure wrapped text: estimate
						-- the lines from the unwrapped width, and a line more
						-- for each role line under the note.
						if noteH < 1 then
							local _, breaks = string.gsub(fullnote, "\n", "")
							noteH = (math.ceil(row.note:GetStringWidth() / NoteWidth()) + breaks) * G.NOTE_LINE
						end
					end
					row:SetHeight(math.max(G.ROWHEIGHT, G.NOTE_TOP + (titleH - G.TITLE_H) + noteH + G.NOTE_BOTTOM))
				end

				if (self.current > idx) and optional and not checked then
					row.text:SetTextColor(0.5, 0.5, 0.5)
					row.check:Disable()
				else
					row.check:Enable()
				end

				if self.db.char.currentguide == "No Guide" then row.check:Disable() end
			end
		end
		end -- i > NUMROWS
	end

	-- Focus mode's height is the step's, which is only known once it is
	-- painted; the steps after it go under its meter.
	if not overview then
		self:PlaceFocusRows()
		self:LayoutPanelHeight()
	end

	--[[ Nav row and the progress rule.

		Steps behind the current one are the done ones: the addon advances
		past a step only once it is satisfied, which is the same measure the
		panel reported as "% complete" before. Counting them for real would
		mean a GetObjectiveStatus call per step on every scroll tick, and
		these guides run to a few hundred steps.
	]]
	doneCount = self.current - 1

	navStepNum:SetText(tostring(self.current))
	navCount:SetText(string.format("%d of %d \194\183 %d done", self.current, total, doneCount))
	guideProgress:SetProgress(total > 0 and (doneCount / total) or 0)

	--[[ Footer: the current step's quest id, and progress through the guide.

		A warning from GetStepMeta outranks the id: it takes the slot and
		turns red. (Nothing raises one at present -- the guide-data-by-server
		warning that did went when it was clear the servers share the guides'
		quests and places.) ]]
	local qid, meta, isWarning = self:GetStepMeta(self.current)
	frame.footer.warning = isWarning and meta or nil

	local materials = frame.footer.materials
	footerQid:ClearAllPoints()
	if self:GuideHasMaterials() then
		materials:Show()
		footerQid:SetPoint("LEFT", materials, "RIGHT", 6, 0)
	else
		materials:Hide()
		footerQid:SetPoint("LEFT", frame.footer, "LEFT", G.ROWPAD, 0)
	end
	footerQid:SetPoint("RIGHT", footerCount, "LEFT", -8, 0)
	if isWarning then
		footerQid:SetText(meta)
		Theme:TextColor(footerQid, "danger")
	elseif qid then
		footerQid:SetText("QID " .. qid)
		Theme:TextColor(footerQid, "accent")
	else
		footerQid:SetText("")
	end
	footerCount:SetText(string.format("%d of %d steps completed", doneCount, total))
end

--[[ The Appearance and Step Display pages' settings for this window. ]]

--- Pin the panel by its bottom-left corner, where that is now: growing
--- upward keeps its bottom edge where you left it.
function AegisPathfinder:AnchorGuideBottom()
	local left, bottom = frame:GetLeft(), frame:GetBottom()
	if not left or not bottom then return false end
	frame:ClearAllPoints()
	frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
	return true
end

--- Grow upward from where the panel is (for a guide at the bottom of the
--- screen), or down from its top as it did. Kept where it is either way.
function AegisPathfinder:SetGuideUpward(on)
	self.db.profile.objframeupward = on and true or nil
	if on then self:AnchorGuideBottom() else Theme:AnchorTopLeft(frame) end
	if frame.savePosition then frame.savePosition(frame) end
	self:LayoutPanelHeight()
end

--- Focus mode with more than one step: the steps after the one you are on go
--- under its meter and the party block, not under the step itself.
function AegisPathfinder:PlaceFocusRows()
	local second = rows[2]
	if not second or not rows[1] then return end
	local y = G.CHROME_TOP + rows[1]:GetHeight()
	if meter and meter:IsShown() then y = y + 2 + meter:GetHeight() end
	if frame.partyblock and frame.partyblock:IsShown() then y = y + 2 + frame.partyblock:GetHeight() end
	second:ClearAllPoints()
	second:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -(y + 2))
	second:SetPoint("RIGHT", frame, "RIGHT", -1, 0)
end

--- The steps' text size, 80% to 140%: titles and notes, and the rows that
--- hold them, scale together. `quiet`: no repaint (the panel is building).
function AegisPathfinder:SetStepTextSize(v, quiet)
	v = math.max(0.8, math.min(1.4, v or 1))
	self.db.profile.steptextsize = v ~= 1 and v or nil
	local function at(n) return math.floor(n * v + 0.5) end
	local b = G.BASE
	G.TEXT_SCALE = v
	G.ROWHEIGHT, G.TITLE_H, G.TITLE_LINE = at(b.ROWHEIGHT), at(b.TITLE_H), at(b.TITLE_LINE)
	G.NOTE_TOP, G.NOTE_LINE = at(b.NOTE_TOP), at(b.NOTE_LINE)
	for _, row in ipairs(rows) do
		Theme:SetFont(row.text, "body", at(b.TITLE_FONT))
		Theme:SetFont(row.detail, "body", at(b.NOTE_FONT))
		Theme:SetFont(row.note, "body", at(b.NOTE_FONT))
		Theme:SetFont(row.band.label, "body", at(b.TITLE_FONT))
		row.detail:SetHeight(at(b.DETAIL_H))
		row.check:ClearAllPoints()
		row.check:SetPoint("TOPLEFT", row, "TOPLEFT", G.ROWPAD, -(G.ROWHEIGHT - G.DOTSIZE) / 2)
	end
	if frame.emptyState then frame.emptyState:SetHeight(G.ROWHEIGHT) end
	if not quiet then
		self:LayoutPanelHeight()
		self:OnObjectiveFrameResized()
		self:UpdateOHPanel()
	end
	return v
end

--- The 4px rule of guide completion under the step row, on or off; off, the
--- steps move up into its place.
function AegisPathfinder:SetGuideProgressShown(on, quiet)
	-- Off is saved as false; on, the default, as nothing.
	if on then self.db.profile.showprogress = nil else self.db.profile.showprogress = false end
	G.CHROME_TOP = G.HEADER_H + G.TABBAR_H + G.NAVROW_H + (on and G.PROGRESS_H or 0)
	if guideProgress then
		if on then guideProgress:Show() else guideProgress:Hide() end
	end
	-- Everything hung from the top of the list, hung again.
	rowsOverview = nil
	if rows[1] then AnchorRows(self.db.char.overviewmode and true or false) end
	if scrollbar then scrollbar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -7, -(G.CHROME_TOP + 14)) end
	if frame.emptyState then frame.emptyState:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -G.CHROME_TOP) end
	if not quiet and frame.footer then
		self:LayoutPanelHeight()
		self:OnObjectiveFrameResized()
		self:UpdateOHPanel()
	end
end

--[[ Hiding the guide, from the Appearance page: in dungeons and raids,
	showing it again as you leave if you ask; in combat, and the action
	buttons with it if you ask. Hidden so, the guide still counts as open --
	it comes back at login, and its own ✕ is what closes it. ]]
function AegisPathfinder:OnGuideHideEvent(ev)
	local p = self.db and self.db.profile
	if not p then return end
	if ev == "PLAYER_REGEN_DISABLED" then
		if not p.hideincombat then return end
		if frame:IsShown() then
			frame:Hide()
			self.hiddenForCombat = true
		end
		if p.hidebuttonscombat then
			self.buttonsHidden = true
			if self.PaintActiveFrames then self:PaintActiveFrames() end
		end
	elseif ev == "PLAYER_REGEN_ENABLED" then
		if self.hiddenForCombat then
			self.hiddenForCombat = nil
			if not self.hiddenForInstance then frame:Show() end
		end
		if self.buttonsHidden then
			self.buttonsHidden = nil
			if self.PaintActiveFrames then self:PaintActiveFrames() end
		end
	else
		local inside, kind = false, nil
		if IsInInstance then inside, kind = IsInInstance() end
		local dungeon = inside and (kind == "party" or kind == "raid")
		if dungeon and p.hideininstance then
			if frame:IsShown() then
				frame:Hide()
				self.hiddenForInstance = true
			end
		elseif not dungeon and self.hiddenForInstance then
			self.hiddenForInstance = nil
			if p.showafterinstance ~= false and not self.hiddenForCombat then frame:Show() end
		end
	end
end

local hider = CreateFrame("Frame")
hider:RegisterEvent("PLAYER_ENTERING_WORLD")
hider:RegisterEvent("ZONE_CHANGED_NEW_AREA")
hider:RegisterEvent("PLAYER_REGEN_DISABLED")
hider:RegisterEvent("PLAYER_REGEN_ENABLED")
hider:SetScript("OnEvent", function() AegisPathfinder:OnGuideHideEvent(event) end)
AegisPathfinder.guideHider = hider
