--[[
	Tests for the objectives panel's structure and step rows.

	The panel is the addon's main surface and the one the concept specifies in
	most detail, so this drives the real file against the stub API and checks
	the things that are invisible until someone loads a client: that the header
	exists and is wired as the drag handle, that the nav row counts the guide
	correctly, and that quest hand-offs become coloured bands while ordinary
	steps stay rows.

	Run:  lua5.1 Tools/tests/test_objectivepanel.lua
]]

package.path = "Tools/tests/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

UISpecialFrames = {}
HideUIPanel = function(f) if f and f.Hide then f:Hide() end end
ShowUIPanel = function(f) if f and f.Show then f:Show() end end
PlaySound = function() end
GetNumQuestLeaderBoards = function() return 0 end
GetQuestLogLeaderBoard = function() return nil end

local L = setmetatable({ PART_FIND = "^(.-)@", PART_GSUB = "@.*$" },
	{ __index = function(_, k) return k end })

AegisPathfinder = {
	Locale = L,
	guides = {}, guidelist = {}, qsplusguides = {},
	actions = {}, quests = {}, tags = {}, turnedin = {},
	current = 1, myfaction = "Alliance",
	db = { char = { currentguide = "Elwynn Forest (1-12)" }, profile = {} },
}
function AegisPathfinder:Debug() end
function AegisPathfinder:Print() end
function AegisPathfinder.trim(s) return (string.gsub(s or "", "^%s*(.-)%s*$", "%1")) end
function AegisPathfinder.select(index, ...)
	if index == "#" then return table.getn(arg) end
	return arg[index]
end
function AegisPathfinder:IsTemplateGuide() return false end
function AegisPathfinder:GuideBadge() return "xp", "XP" end
function AegisPathfinder:ReturnFromBranch() end
function AegisPathfinder:GoToObjective(i) self.__wentTo = i end
function AegisPathfinder:GoToPreviousObjective() end
function AegisPathfinder:SkipToNextObjective() end
function AegisPathfinder:SetTurnedIn() end
function AegisPathfinder:UpdateStatusFrame() end
function AegisPathfinder:ToggleMaterialsPanel() self.__matsOpened = (self.__matsOpened or 0) + 1 end
function AegisPathfinder:GuideHasMaterials() return self.__hasMats end
function AegisPathfinder:OnObjectiveFrameResized2() end
function AegisPathfinder:IsAutoDetectable() return false end
function AegisPathfinder:GetObjectiveInfo(i)
	return self.actions[i], self.quests[i], self.quests[i]
end
function AegisPathfinder:GetObjectiveStatus(i) return self.turnedin[i] end
function AegisPathfinder:GetObjectiveTag(tag, i)
	local t = self.tags[i or self.current]
	if not t then return nil end
	return t[tag]
end
-- The engine supplies these; the panel only renders what they return.
function AegisPathfinder:GetStepMeta(i)
	local qid = self:GetObjectiveTag("QID", i)
	if self.__dataWarning then return nil, self.__dataWarning, true end
	return qid, qid and ("QID " .. qid) or nil, false
end
-- The tab model lives in Core.lua; this suite is about the rows, so one tab
-- is enough for it.
function AegisPathfinder:EnsureTabs()
	self.db.char.tabs = self.db.char.tabs
		or { { guide = self.db.char.currentguide, step = 1 } }
	self.db.char.activetab = self.db.char.activetab or 1
	return self.db.char.tabs
end
function AegisPathfinder:HasNoGuide() return table.getn(self:EnsureTabs()) == 0 end
function AegisPathfinder:SwitchToTab() end
-- OptionsFrame.lua's, which this suite does not load.
function AegisPathfinder:ToggleConfigPanel()
	if self.optionsframe:IsShown() then self.optionsframe:Hide() else self.optionsframe:Show() end
end
function AegisPathfinder:CloseTab() end
function AegisPathfinder:ToggleOverviewMode()
	self.db.char.overviewmode = not self.db.char.overviewmode
	if self.objectiveframe.expandChip then
		self.objectiveframe.expandChip:SetActive(self.db.char.overviewmode)
	end
	self:OnObjectiveFrameResized()
	self:UpdateOHPanel()
end

AegisPathfinder.statusframe = CreateFrame("Frame", nil, UIParent)
AegisPathfinder.optionsframe = CreateFrame("Frame", nil, UIParent)
AegisPathfinder.guidelistframe = CreateFrame("Frame", nil, UIParent)

dofile("Theme.lua")
dofile("ObjectivesFrame.lua")
-- Sharing adds the party icon and the members under the step.
AegisPathfinder.SkipToNextObjective = AegisPathfinder.SkipToNextObjective or function() end
GetNumPartyMembers = function() return 1 end
GetNumRaidMembers = function() return 0 end
dofile("PartySync.lua")

local Theme = AegisPathfinder.Theme

-- The real Core.lua publishes the generated glyphs under this name; the panel
-- reads it per row, so the test needs the same mapping rather than a stub.
AegisPathfinder.icons = setmetatable({}, {
	__index = function(_, action)
		return Theme.actionIconByName[action] or Theme.actionIcon.N
	end,
})

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end

local frame = AegisPathfinder.objectiveframe
-- A player coming from the version where the grip set the height directly.
AegisPathfinder.db.profile.objframeheight = 500
-- And the old default width, which every earlier version saved on its own.
AegisPathfinder.db.profile.objframewidth = 630
AegisPathfinder:UpdateObjectivePanel()

check(AegisPathfinder.db.profile.objframewidth == nil and frame:GetWidth() == 396,
	"the old default width is dropped for the concept's 396px, got %s saved, %s wide",
	tostring(AegisPathfinder.db.profile.objframewidth), frame:GetWidth())
frame:SetWidth(450)
AegisPathfinder:OnObjectiveFrameResized()
check(AegisPathfinder.db.profile.objframewidth == nil,
	"a resize the player did not make is not saved as their choice")
frame:SetWidth(396)

check(AegisPathfinder.db.profile.objframemaxheight == 500
	and AegisPathfinder.db.profile.objframeheight == nil,
	"an old saved height becomes the cap, not the height, got cap %s height %s",
	tostring(AegisPathfinder.db.profile.objframemaxheight),
	tostring(AegisPathfinder.db.profile.objframeheight))

-- Header ---------------------------------------------------------------------

check(frame.header ~= nil, "the panel has no header")
check(frame.header.wordmark ~= nil, "the header is missing the PATHFINDER wordmark")
check(frame.header.wordmark:GetTexture() == Theme.texture.wordmark,
	"the wordmark should be the pre-rendered texture, not a font string")

-- The bug the user hit: no header meant nothing to drag the window by.
check(frame:IsMovable(), "the panel must be movable")
check(frame.header.__dragButton == "LeftButton",
	"the header must be registered for left-button drag, got %s",
	tostring(frame.header.__dragButton))
local dragStart = frame.header:GetScript("OnDragStart")
local dragStop = frame.header:GetScript("OnDragStop")
check(dragStart ~= nil, "the header has no OnDragStart")
check(dragStop ~= nil, "the header has no OnDragStop")

if dragStart and dragStop then
	dragStart()
	check(frame.__moving == true, "dragging the header should move the panel")
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 120, -80)
	dragStop()
	check(frame.__moving == false, "releasing should stop the move")

	-- Pinned by its top-left, where it was dropped, and by nothing else:
	-- the client's own choice of anchor is what can leave a window growing
	-- upward, or with two anchors and a height it cannot change.
	local p, rel, relP, x, y = frame:GetPoint(1)
	check(frame:GetNumPoints() == 1 and p == "TOPLEFT" and rel == UIParent and relP == "BOTTOMLEFT",
		"a dropped panel is anchored by its top-left alone, got %d point(s), %s to %s",
		frame:GetNumPoints(), tostring(p), tostring(relP))
	check(frame:GetLeft() == 120 and frame:GetTop() == 768 - 80,
		"where it was dropped, got %s,%s", tostring(frame:GetLeft()), tostring(frame:GetTop()))

	local db = AegisPathfinder.db.profile
	check(db.objframepoint == "TOPLEFT" and db.objframerel == "BOTTOMLEFT"
		and db.objframex == 120 and db.objframey == 688,
		"where the panel was dropped must be saved, got %s/%s %s,%s",
		tostring(db.objframepoint), tostring(db.objframerel),
		tostring(db.objframex), tostring(db.objframey))

	-- And put back there, against the corner it was measured from.
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	AegisPathfinder.Theme:RestorePosition(frame, "objframe")
	check(frame:GetLeft() == 120 and frame:GetTop() == 688,
		"restoring puts it back where it was dropped, got %s,%s",
		tostring(frame:GetLeft()), tostring(frame:GetTop()))

	-- A position saved before the relative point was kept reads as it was
	-- written: the point against the same point.
	db.objframepoint, db.objframerel, db.objframex, db.objframey = "TOPRIGHT", nil, -40, -180
	AegisPathfinder.Theme:RestorePosition(frame, "objframe")
	check(frame:GetRight() == 1024 - 40 and frame:GetTop() == 768 - 180,
		"an older save still restores, got right %s top %s",
		tostring(frame:GetRight()), tostring(frame:GetTop()))
end

-- Chrome ---------------------------------------------------------------------

check(frame.navrow ~= nil, "the nav row was not built")
check(frame.guideProgress ~= nil, "the guide progress bar was not built")
check(frame.footer ~= nil, "the footer was not built")

-- Steps ----------------------------------------------------------------------

AegisPathfinder.actions = { "NOTE", "ACCEPT", "RUN", "TURNIN", "COMPLETE" }
AegisPathfinder.quests = {
	"Welcome to Elwynn@1@", "Down in the Ridge@1@", "Goldshire@1@",
	"Down in the Ridge@2@", "Kill the boars@1@",
}
AegisPathfinder.tags = {
	[1] = { N = "Read this first" },
	[2] = { N = "Marshal McBride in Northshire Abbey", QID = "26" },
	[3] = { N = "Travel to Goldshire" },
	[4] = { N = "Marshal Dughan in Goldshire", QID = "26" },
	[5] = { N = "Kill 8 boars" },
}
AegisPathfinder.turnedin = {}
AegisPathfinder.current = 3
frame:Show()
-- The row assertions below describe overview mode, which is what the panel
-- used to do unconditionally.
AegisPathfinder.db.char.overviewmode = true
AegisPathfinder:UpdateOHPanel(0)

-- Rows are fixed slots: slot n shows step n + offset, and offset is 0 here.
-- They are reachable as the panel's children that carry a band.
local built = {}
for _, child in ipairs(frame.__children) do
	if child.band then table.insert(built, child) end
end
check(table.getn(built) == 30, "expected 30 row slots, got %d", table.getn(built))

-- A NOTE step is an ordinary row, never a band.
local r1 = built[1]
check(not r1.band:IsShown(), "a NOTE step is a row, not a band")
check(r1.text:GetText() == "[1] Welcome to Elwynn@1@",
	"the row title carries the step number, got '%s'", tostring(r1.text:GetText()))
check(r1.detail:GetText() == "Read this first",
	"the note sits under the title, got '%s'", tostring(r1.detail:GetText()))
check(r1.icon:GetTexture() == Theme.actionIcon.N,
	"a NOTE row should draw the generated note glyph, got '%s'",
	tostring(r1.icon:GetTexture()))

-- An ACCEPT that is neither current nor done stays an ordinary row, so the
-- list does not become a wall of colour.
local r2 = built[2]
check(not r2.band:IsShown(),
	"an ACCEPT that is not the current step and not done stays a row")

-- The current step gets the wash and the left accent bar.
local r3 = built[3]
check(r3.bg:IsShown() and r3.activebar:IsShown(),
	"the current step should show the wash and the accent bar")

-- A TURNIN that IS the current step becomes a red band.
AegisPathfinder.current = 4
AegisPathfinder:UpdateOHPanel(0)
local r4 = built[4]
check(r4.band:IsShown(), "the current TURNIN step should render as a band")
check(not r4.text:IsShown(), "the band replaces the row, it does not overlap it")
check(r4.band.label:GetText() == "[4] Turn in 'Down in the Ridge@2@'",
	"the band reads as an instruction, got '%s'", tostring(r4.band.label:GetText()))
check(r4.band.icon:GetTexture() == Theme.glyph.bang,
	"an outstanding band carries the bang glyph")

-- Once done it turns green and the verb goes past tense.
AegisPathfinder.turnedin[4] = true
AegisPathfinder:UpdateOHPanel(0)
check(r4.band:IsShown(), "a completed TURNIN stays a band")
check(r4.band.label:GetText() == "[4] Turned in 'Down in the Ridge@2@'",
	"a satisfied band reads in the past tense, got '%s'",
	tostring(r4.band.label:GetText()))
check(r4.band.icon:GetTexture() == Theme.glyph.tick,
	"a satisfied band carries the tick glyph")

-- Moving off it leaves it a band, because it is done.
AegisPathfinder.current = 5
AegisPathfinder:UpdateOHPanel(0)
check(r4.band:IsShown(), "a done hand-off stays a band after you move past it")

-- Switching a slot from band back to row must restore every piece of the row.
AegisPathfinder.turnedin[4] = nil
AegisPathfinder:UpdateOHPanel(0)
check(not r4.band:IsShown(), "an untouched TURNIN two steps back is a row again")
check(r4.text:IsShown() and r4.icon:IsShown() and r4.check:IsShown(),
	"coming back from a band must restore the row's own parts")

-- No Blizzard art anywhere in the rows -----------------------------------------

for i, row in ipairs(built) do
	if row.icon:IsShown() and row.icon:GetTexture() then
		check(string.find(row.icon:GetTexture(), "Aegis_Pathfinder", 1, true) ~= nil,
			"row %d draws a texture from outside the addon: %s",
			i, tostring(row.icon:GetTexture()))
	end
end

-- Panels open beside the guide, not instead of it ------------------------------

--[[ The ≡ chip opens the guide window's menu, as Zygor's does: the guide
	browser, the setup wizard, Lock window, Transparency, Reset window,
	Reload and Settings. What it opens sits beside the guide -- it used to
	hide the panel before showing Config, so opening settings closed the
	guide you were reading. ]]
local menuChip
for _, child in ipairs(frame.header.__children) do
	if child.glyph and child.glyph:GetTexture() == Theme.glyph.menu then menuChip = child end
end
check(menuChip ~= nil, "the header has no menu chip")

local menu = AegisPathfinder.guidemenu
local function item(label)
	for _, row in ipairs(menu.rows) do
		if row.label:GetText() == label then return row end
	end
end
local labels = {}
for _, row in ipairs(menu.rows) do table.insert(labels, row.label:GetText()) end
check(table.concat(labels, ", ") == "Guide menu, Setup wizard, Lock window, Transparency, Reset window, Reload, Settings",
	"the menu's items, got %s", table.concat(labels, ", "))

frame:Show()
AegisPathfinder.optionsframe:Hide()
this = menuChip
menuChip:GetScript("OnClick")()
check(menu:IsShown(), "the chip opens the menu")
this = item("Settings")
item("Settings"):GetScript("OnClick")()
check(not menu:IsShown(), "an item closes the menu")
check(frame:IsShown(), "opening Config must not close the guide")
check(AegisPathfinder.optionsframe:IsShown(), "and Config should be open")
this = item("Settings")
item("Settings"):GetScript("OnClick")()
check(frame:IsShown(), "closing Config leaves the guide alone")
check(not AegisPathfinder.optionsframe:IsShown(), "and Config is shut")

AegisPathfinder.guidelistframe:Hide()
this = item("Guide menu")
item("Guide menu"):GetScript("OnClick")()
check(AegisPathfinder.guidelistframe:IsShown() and frame:IsShown(), "Guide menu opens the browser beside the guide")
AegisPathfinder.guidelistframe:Hide()

local setup = 0
function AegisPathfinder:ShowSetup() setup = setup + 1 end
this = item("Setup wizard")
item("Setup wizard"):GetScript("OnClick")()
check(setup == 1, "Setup wizard opens the setup")
local reloads = 0
ReloadUI = function() reloads = reloads + 1 end
this = item("Reload")
item("Reload"):GetScript("OnClick")()
check(reloads == 1, "Reload reloads the UI")

-- Lock window: no drag, no grip; and it is remembered.
menu:Show()
this = item("Lock window")
item("Lock window"):GetScript("OnClick")()
check(AegisPathfinder.db.profile.objframelocked and item("Lock window").on, "Lock window ticks")
check(menu:IsShown(), "and a switch leaves the menu open")
check(not frame.grip:IsShown(), "a locked window has no grip")
frame.__moving = false
frame.header:GetScript("OnDragStart")()
check(not frame.__moving, "and does not move")
item("Lock window"):GetScript("OnClick")()
check(not AegisPathfinder.db.profile.objframelocked and frame.grip:IsShown(), "unlocked, the grip is back")
frame.header:GetScript("OnDragStart")()
check(frame.__moving, "and it moves")
frame:StopMovingOrSizing()

-- Transparency: the panel's body at half strength.
local fillPiece = AegisPathfinder.objectiveskin.fill.center
this = item("Transparency")
item("Transparency"):GetScript("OnClick")()
check(AegisPathfinder.db.profile.objframetransparent and fillPiece.__color[4] == 0.5, "Transparency, got %s",
	tostring(fillPiece.__color[4]))
item("Transparency"):GetScript("OnClick")()
check(fillPiece.__color[4] == 1, "and solid again")
menu:Hide()

-- Same for the + that opens the guide list.
local addTab = frame.addTab
AegisPathfinder.guidelistframe:Hide()
addTab:GetScript("OnClick")()
check(frame:IsShown(), "opening the guide list must not close the guide")
check(AegisPathfinder.guidelistframe:IsShown(), "and the guide list should be open")
AegisPathfinder.guidelistframe:Hide()

-- Focus mode and overview -------------------------------------------------------

--[[ The concept's two modes. Focus -- the default -- shows the one step you
	are on; overview shows the list. The chip in the header says which. ]]
check(frame.expandChip ~= nil, "the overview chip was not built")

AegisPathfinder.db.char.overviewmode = false
AegisPathfinder.current = 2
AegisPathfinder:UpdateOHPanel()

check(built[1]:IsShown(), "focus mode shows the current step")
check(not built[2]:IsShown(), "and nothing else")
check(built[1].i == 2,
	"the single row should be the step you are on, got %s", tostring(built[1].i))
check(built[1].band:IsShown(),
	"the step it shows is still styled by its own rules -- an active ACCEPT is a band")

--[[ The concept gives .steps-list flex:0 0 auto in focus mode, so the window
	is only as tall as the step it shows; overview gets flex:1 1 auto and fills
	its max-height. Without this focus mode is a mostly-empty box. ]]
local focusHeight = frame:GetHeight()

AegisPathfinder.db.char.overviewmode = true
AegisPathfinder:UpdateOHPanel(0)
check(built[2]:IsShown(), "overview mode brings the rest of the list back")

local overviewHeight = frame:GetHeight()
check(focusHeight < overviewHeight,
	"focus mode should shrink the panel to its one step (%s) rather than leaving it at the overview height (%s)",
	tostring(focusHeight), tostring(overviewHeight))
check(focusHeight <= 86 + 44 + 24 + 12,
	"and that height is chrome plus one row, got %s", tostring(focusHeight))

-- Toggling flips the mode and the chip's state together.
AegisPathfinder.db.char.overviewmode = false
frame.expandChip:SetActive(false)
AegisPathfinder:ToggleOverviewMode()
check(AegisPathfinder.db.char.overviewmode == true, "toggling turns overview on")
check(frame.expandChip:IsActive() == true,
	"and the chip takes the accent so the panel says which mode it is in")
AegisPathfinder:ToggleOverviewMode()
check(AegisPathfinder.db.char.overviewmode == false, "toggling again returns to focus")
check(frame.expandChip:IsActive() == false, "and the chip goes back to plain")

-- The panel is as tall as what it shows -------------------------------------------

--[[ The concept's panel is height:auto under a max-height. A step with a
	long note shows all of it and the panel grows to fit; a short one shrinks
	it back. Nothing the grip does can leave the panel a size its content
	does not fit, which is how it got stuck. ]]
local CHROME, FOOTER = 86, 24
AegisPathfinder.db.char.overviewmode = false
AegisPathfinder.current = 3            -- a RUN step: a row, not a band
AegisPathfinder.tags[3].N = "Travel to Goldshire"
AegisPathfinder:UpdateOHPanel()
local shortRow, shortPanel = built[1]:GetHeight(), frame:GetHeight()
-- Anchored by its bottom, as the client can leave a window moved in the lower
-- half of the screen: growing must still leave the header where it is.
local bottomNow = frame:GetBottom()
frame:ClearAllPoints()
frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 100, bottomNow)
local top = frame:GetTop()

local long = string.rep("Follow the road south past the farms and the river. ", 12)
AegisPathfinder.tags[3].N = long
AegisPathfinder:UpdateOHPanel()
check(built[1].note:IsShown() and built[1].note:GetText() == long,
	"focus mode shows the whole note, not one clipped line")
check(not built[1].detail:IsShown(), "and not the one-line version")
check(built[1]:GetHeight() > shortRow,
	"the row grows for a long note (%s, was %s)", built[1]:GetHeight(), shortRow)
check(frame:GetHeight() == CHROME + built[1]:GetHeight() + 8 + FOOTER,
	"and the panel is exactly chrome, the row and the footer, got %s", frame:GetHeight())
check(frame:GetTop() == top, "it grows downward: the header does not move (%s, was %s)",
	tostring(frame:GetTop()), tostring(top))

AegisPathfinder.tags[3].N = "Travel to Goldshire"
AegisPathfinder:UpdateOHPanel()
check(frame:GetHeight() == shortPanel, "and shrinks back for a short one, got %s (was %s)",
	frame:GetHeight(), shortPanel)

-- A long title wraps to the panel in focus mode, instead of ending in "...",
-- and the row grows for it; the list keeps one line a step.
do
	local name = AegisPathfinder.quests[3]
	AegisPathfinder.quests[3] = "This has 4 different possible spawn points in the dungeon: check each of them"
	frame:SetWidth(320)
	AegisPathfinder:UpdateOHPanel()
	check(built[1].text:GetHeight() > 16, "a long title gets more than one line, got %s", built[1].text:GetHeight())
	check(built[1]:GetHeight() > shortRow, "and the row grows for it (%s, was %s)", built[1]:GetHeight(), shortRow)
	frame:SetWidth(900)
	AegisPathfinder:UpdateOHPanel()
	check(built[1].text:GetHeight() == 16, "a wide panel holds it on one line, got %s", built[1].text:GetHeight())
	frame:SetWidth(320)
	AegisPathfinder.db.char.overviewmode = true
	AegisPathfinder:UpdateOHPanel()
	check(built[1].text:GetHeight() == 16, "the list keeps one line a step, got %s", built[1].text:GetHeight())
	AegisPathfinder.db.char.overviewmode = false
	AegisPathfinder.quests[3] = name
	frame:SetWidth(396)
	AegisPathfinder:UpdateOHPanel()
end

-- In focus mode the row runs to the panel's edge; there is no scrollbar
-- beside it to stop at.
local function rightTarget(row)
	for _, pt in ipairs(row.__points) do
		if pt[1] == "RIGHT" then return pt[2] end
	end
end
check(rightTarget(built[1]) == frame, "a focus-mode row reaches the panel's edge")

-- Overview is as tall as the list, up to the cap.
AegisPathfinder.db.char.overviewmode = true
AegisPathfinder:UpdateOHPanel(0)
check(rightTarget(built[1]) ~= frame, "an overview row stops at the scrollbar")
check(frame:GetHeight() == CHROME + 5 * 44 + 2 + FOOTER,
	"five steps fit under the cap, so the panel is as tall as five rows, got %s",
	frame:GetHeight())
for i = 1, 5 do check(built[i]:IsShown(), "overview row %d shows", i) end
AegisPathfinder.db.profile.objframemaxheight = 260
AegisPathfinder:UpdateOHPanel(0)
check(frame:GetHeight() == 260, "a lower cap stops it there, got %s", frame:GetHeight())
check(built[3]:IsShown() and not built[4]:IsShown(),
	"showing as many rows as fit, and a scrollbar for the rest")
AegisPathfinder.db.char.overviewmode = false

-- The grip ----------------------------------------------------------------------------

--[[ Sideways sets the width, down sets the cap -- the concept's grip -- and it
	never hands the frame to the client's StartSizing, whose re-anchoring is
	what left the panel stuck. ]]
local startedSizing = false
frame.StartSizing = function() startedSizing = true end
local grip = frame.grip
local w0 = frame:GetWidth()
local cap0 = AegisPathfinder:GetPanelCap()
stub.mouseDown = true
stub.cursor = { 500, 300 }
grip:GetScript("OnMouseDown")()
local p1, _, r1 = frame:GetPoint(1)
check(p1 == "TOPLEFT" and r1 == "BOTTOMLEFT" and frame:GetNumPoints() == 1,
	"grabbing the grip pins the panel by its top-left, so it grows right and down")
stub.cursor = { 560, 200 }
grip:GetScript("OnUpdate")()
check(frame:GetWidth() == w0 + 60, "dragging right widens it, got %s (was %s)", frame:GetWidth(), w0)
check(AegisPathfinder:GetPanelCap() == cap0 + 100,
	"dragging down raises the cap, got %s (was %s)", AegisPathfinder:GetPanelCap(), cap0)
check(AegisPathfinder.db.profile.objframewidth == w0 + 60, "the width is saved")
check(frame:GetHeight() < AegisPathfinder:GetPanelCap(),
	"but the panel stays the height of its step, not the cap (%s)", frame:GetHeight())
stub.cursor = { -2000, 300 }
grip:GetScript("OnUpdate")()
check(frame:GetWidth() == 320, "no narrower than the concept's 320, got %s", frame:GetWidth())
-- The button comes up somewhere the grip does not hear about.
stub.mouseDown = false
grip:GetScript("OnUpdate")()
check(grip:GetScript("OnUpdate") == nil, "letting go ends the drag even off the grip")
check(not startedSizing, "and the client's StartSizing was never involved")

-- A client whose IsMouseButtonDown does not read "LeftButton" as held, even
-- mid-drag, must not have every drag end the moment it starts.
stub.mouseDown = false
stub.cursor = { 500, 300 }
local wBefore = frame:GetWidth()
grip:GetScript("OnMouseDown")()
stub.cursor = { 540, 300 }
grip:GetScript("OnUpdate")()
check(frame:GetWidth() == wBefore + 40,
	"the grip still sizes when the button cannot be polled, got %s (was %s)",
	frame:GetWidth(), wBefore)
grip:GetScript("OnMouseUp")()
check(grip:GetScript("OnUpdate") == nil, "and letting go on the grip ends it")

-- Resetting -----------------------------------------------------------------------------

local profile = AegisPathfinder.db.profile
profile.objframepoint, profile.objframerel, profile.objframex, profile.objframey = "TOPLEFT", "BOTTOMLEFT", 5, 5
profile.guidelistframepoint = "CENTER"
AegisPathfinder:ResetWindowLayout()
check(profile.objframepoint == nil and profile.guidelistframepoint == nil,
	"/apg resetpanels forgets every saved position")
check(profile.objframewidth == nil and profile.objframemaxheight == nil,
	"and the panel's size")
check(frame:GetWidth() == 396 and frame:GetRight() == 1024 - 40 and frame:GetTop() == 768 - 180,
	"putting the guide back at the concept's top-right, 396 wide, got %s wide at right %s top %s",
	frame:GetWidth(), tostring(frame:GetRight()), tostring(frame:GetTop()))

-- The objective meter -------------------------------------------------------

check(frame.meter ~= nil, "the objective meter was not built")

-- No quest-log objective means no meter, rather than an empty one.
AegisPathfinder.current = 1
AegisPathfinder:UpdateOHPanel()
check(not frame.meter:IsShown(), "a NOTE step has nothing to count, so no meter")

-- A COMPLETE step whose quest is in the log with countable objectives left.
AegisPathfinder.actions[5] = "COMPLETE"
function AegisPathfinder:GetObjectiveStatus(i)
	if i == 5 then return nil, 7, false end   -- in the log, not complete
	return self.turnedin[i]
end
GetNumQuestLeaderBoards = function() return 1 end
GetQuestLogLeaderBoard = function() return "Kobold Vermin slain: 3/8", "monster", nil end

AegisPathfinder.current = 5
AegisPathfinder:UpdateOHPanel()
check(frame.meter:IsShown(), "a countable objective gets the meter")
check(frame.meter.label:GetText() == "Kobold Vermin slain",
	"the label is the objective without its counts, got '%s'",
	tostring(frame.meter.label:GetText()))
check(frame.meter.count:GetText() == "3 / 8",
	"the count reads as the concept prints it, got '%s'",
	tostring(frame.meter.count:GetText()))
check(frame.meter.bar:GetValue() == 3 / 8,
	"the bar is filled to three eighths, got %s", tostring(frame.meter.bar:GetValue()))

local oneHigh = frame.meter:GetHeight()
check(oneHigh == 38, "one objective is the concept's 38px meter, got %s", tostring(oneHigh))

-- Two things to gather: a line and a bar for each, the finished one full.
GetNumQuestLeaderBoards = function() return 2 end
GetQuestLogLeaderBoard = function(j)
	if j == 1 then return "Crocolisk Meat: 5/5", "item", 1 end
	return "Crocolisk Skin: 3/6", "item", nil
end
AegisPathfinder:UpdateOHPanel()
local lines = frame.meter.lines
check(frame.meter:IsShown() and lines[2] and lines[2].bar:IsShown(), "Crocolisk Hunting gets two bars")
check(lines[1].label:GetText() == "Crocolisk Meat" and lines[1].count:GetText() == "5 / 5"
	and lines[2].label:GetText() == "Crocolisk Skin" and lines[2].count:GetText() == "3 / 6",
	"meat, then skins, got %s %s, %s %s", tostring(lines[1].label:GetText()), tostring(lines[1].count:GetText()),
	tostring(lines[2].label:GetText()), tostring(lines[2].count:GetText()))
check(lines[1].bar.ratio == 1 and lines[2].bar.ratio == 0.5, "the meat's bar full, the skins' half, got %s and %s",
	tostring(lines[1].bar.ratio), tostring(lines[2].bar.ratio))
check(frame.meter:GetHeight() == 68, "and the meter grows a line, got %s", tostring(frame.meter:GetHeight()))
local _, anchor = lines[2].bar:GetPoint(1)
check(anchor == frame.meter, "each bar sits in the meter")
-- The step's accent bar and wash reach down over the meter, to the footer.
local stepRow = built[1]
local p2, to2, _, x2, y2 = stepRow.activebar:GetPoint(2)
check(p2 == "BOTTOMLEFT" and to2 == frame.meter and x2 == -14 and y2 == -8,
	"the accent bar reaches the meter's foot and on to the footer, got %s %s %s", tostring(p2), tostring(x2), tostring(y2))
local _, bgTo = stepRow.bg:GetPoint(2)
check(bgTo == frame.meter, "and so does the wash")

-- Back to one: the second line goes, and the meter shrinks.
GetNumQuestLeaderBoards = function() return 1 end
GetQuestLogLeaderBoard = function() return "Kobold Vermin slain: 4/5", "monster", nil end
AegisPathfinder:UpdateOHPanel()
check(not lines[2].bar:IsShown() and not lines[2].label:IsShown(), "one objective, one line")
check(frame.meter:GetHeight() == oneHigh, "and the meter one line high again")
check(lines[1].bar.ratio == 0.8, "4 of 5 is 80%%, got %s", tostring(lines[1].bar.ratio))

-- An objective with no numbers in it is not a meter.
GetQuestLogLeaderBoard = function() return "Speak to Marshal Dughan", "event", nil end
AegisPathfinder:UpdateOHPanel()
check(not frame.meter:IsShown(),
	"an objective with nothing to count gets no meter rather than a broken one")
local _, backTo = stepRow.activebar:GetPoint(2)
check(backTo == stepRow, "with no meter the accent bar fits the step again")

-- Overview mode folds the objective into the note line instead, as the
-- concept does, and hides the meter.
GetQuestLogLeaderBoard = function() return "Kobold Vermin slain: 3/8", "monster", nil end
AegisPathfinder.db.char.overviewmode = true
AegisPathfinder:UpdateOHPanel(0)
check(not frame.meter:IsShown(), "overview mode has no meter")
check(built[5].detail:GetText() == "Kobold Vermin slain - 3/8",
	"overview folds the objective into the note, got '%s'",
	tostring(built[5].detail:GetText()))
AegisPathfinder.db.char.overviewmode = false

-- Escape --------------------------------------------------------------------------

-- Escape clears a target or cancels a spell in a fight, and closed the guide
-- with it: the guide kept closing in combat. It is not Escape's to close.
local escapable = false
for _, name in ipairs(UISpecialFrames) do
	if name == "AegisPathfinderObjectives" then escapable = true end
end
check(not escapable, "Escape does not close the guide")

-- The footer ------------------------------------------------------------------

-- The concept replaced its slash-command hint with live state.
local footerStrings = {}
for _, r in ipairs(frame.footer.__regions) do
	if r.__kind == "FontString" then table.insert(footerStrings, r) end
end
check(table.getn(footerStrings) == 2,
	"the footer carries a quest id and a count, got %d strings", table.getn(footerStrings))

AegisPathfinder.current = 2       -- step 2 has QID 26
AegisPathfinder:UpdateOHPanel()
local qidText, countText
for _, fs in ipairs(footerStrings) do
	if string.find(fs:GetText() or "", "QID", 1, true) then qidText = fs:GetText() end
	if string.find(fs:GetText() or "", "completed", 1, true) then countText = fs:GetText() end
end
check(qidText == "QID 26", "the footer names the current step's quest id, got '%s'",
	tostring(qidText))
check(countText == "1 of 5 steps completed",
	"the footer counts the guide, got '%s'", tostring(countText))

-- A warning from GetStepMeta outranks the quest id. Nothing raises one at
-- present, but the footer keeps the slot for one.
AegisPathfinder.__dataWarning = "Guide data authored for OctoWoW"
AegisPathfinder:UpdateOHPanel()
local warned = false
for _, fs in ipairs(footerStrings) do
	if fs:GetText() == "Guide data authored for OctoWoW" then warned = true end
end
check(warned, "a data-source warning should take the footer's left slot")

-- At 396px a warning and the count do not both fit, so the warning stops at
-- the count on one line, and the footer's tooltip has all of it.
local warnString
for _, fs in ipairs(footerStrings) do
	if fs:GetText() == "Guide data authored for OctoWoW" then warnString = fs end
end
local stopsAtCount = false
for _, pt in ipairs(warnString.__points) do
	if pt[1] == "RIGHT" and pt[2] ~= frame.footer then stopsAtCount = true end
end
check(stopsAtCount and warnString:GetHeight() == 12,
	"the warning is held to one line short of the count")
check(frame.footer.warning == "Guide data authored for OctoWoW",
	"and the footer keeps the whole warning for its tooltip")
AegisPathfinder.__dataWarning = nil
AegisPathfinder:UpdateOHPanel()
check(frame.footer.warning == nil, "which goes when the warning does")

--[[ The shopping list's button. It used to be an 18px glyph pointing at a
	texture that did not exist -- "use" is not one of the theme's glyphs -- so
	it drew nothing. It carries the buy icon and says what it is now, and only
	on a guide that has a shopping list. ]]
local mats = frame.footer.materials
check(mats ~= nil, "the footer has a shopping list button")
local tex = mats.glyph:GetTexture()
check(tex == Theme.actionIcon.B,
	"its icon is the theme's buy glyph, got '%s'", tostring(tex))
check(string.find(tex or "", "Interface\\AddOns\\", 1, true) == 1,
	"which is a real texture path, not a bare glyph name, got '%s'", tostring(tex))
check(mats.label and mats.label:GetText() == "SHOPPING LIST", "and it says what it opens")

AegisPathfinder.__hasMats = false
AegisPathfinder:UpdateOHPanel()
check(not mats:IsShown(), "a quest guide has no shopping list, so no button")
local function qidString()
	for _, fs in ipairs(footerStrings) do
		for _, pt in ipairs(fs.__points) do if pt[1] == "LEFT" then return fs, pt end end
	end
end
local _, qpt = qidString()
check(qpt and qpt[2] == frame.footer, "and the quest id starts at the footer's edge")

AegisPathfinder.__hasMats = true
AegisPathfinder:UpdateOHPanel()
check(mats:IsShown(), "a craft guide shows it")
_, qpt = qidString()
check(qpt and qpt[2] == mats, "with the quest id moved along beside it")
this = mats
mats:GetScript("OnClick")()
check(AegisPathfinder.__matsOpened == 1, "clicking it opens the shopping list")
mats:GetScript("OnEnter")()
check(Theme.tip and Theme.tip:IsShown(), "and hovering it says what it is")
mats:GetScript("OnLeave")()
AegisPathfinder.__hasMats = false
AegisPathfinder:UpdateOHPanel()

-- Sharing the guide (PartySync.lua) ------------------------------------------

do
	local share = AegisPathfinder.shareState
	local b = AegisPathfinder.sharebutton
	check(b ~= nil and b:GetParent() == frame.navrow, "the step row carries the party icon")
	AegisPathfinder.db.char.overviewmode = nil
	AegisPathfinder:UpdateOHPanel()
	local before = AegisPathfinder:PanelContentHeight()
	share.active, share.guide = true, AegisPathfinder.db.char.currentguide
	share.members = { Ghanndraine = { key = AegisPathfinder:ShareStepKey(AegisPathfinder.current) } }
	AegisPathfinder:UpdateOHPanel()
	check(frame.partyblock and frame.partyblock:IsShown(), "sharing, the members show under the step")
	check(AegisPathfinder:PanelContentHeight() == before + 2 + frame.partyblock:GetHeight(),
		"and the panel grows to fit them (%s from %s)", AegisPathfinder:PanelContentHeight(), before)
	share.active, share.guide, share.members = false, nil, {}
	AegisPathfinder:UpdateOHPanel()
	check(not frame.partyblock:IsShown() and AegisPathfinder:PanelContentHeight() == before, "and they go when sharing stops")
end

-- The step arrows: a click moves a step, remembering your place first; a
-- right-click goes back or on to it. ------------------------------------------

do
	local calls = {}
	local A = AegisPathfinder
	local keep = { A.GoToPreviousObjective, A.SkipToNextObjective, A.RememberPlace, A.ReturnToPlace }
	function A:GoToPreviousObjective() table.insert(calls, "back") end
	function A:SkipToNextObjective() table.insert(calls, "on") end
	function A:RememberPlace() table.insert(calls, "remember") end
	function A:ReturnToPlace(d) table.insert(calls, "place " .. d) end
	local prev, nextArrow = frame.navrow.stepControls[1], frame.navrow.stepControls[2]
	local function press(b, button)
		local oldThis, oldArg = this, arg1
		this, arg1 = b, button
		b:GetScript("OnClick")()
		this, arg1 = oldThis, oldArg
	end
	check(prev.__clicks and prev.__clicks[2] == "RightButtonUp" and nextArrow.__clicks[2] == "RightButtonUp",
		"the step arrows hear a right-click")
	press(prev, "LeftButton"); press(nextArrow, "LeftButton")
	press(prev, "RightButton"); press(nextArrow, "RightButton")
	check(table.concat(calls, ", ") == "remember, back, remember, on, place -1, place 1",
		"a click remembers your place and moves; a right-click goes to it, got %s", table.concat(calls, ", "))
	local oldThis = this
	this = prev
	prev:GetScript("OnEnter")()
	this = oldThis
	local tip = {}
	for _, fs in ipairs(Theme.tip.lines) do if fs:IsShown() then table.insert(tip, fs:GetText()) end end
	check(string.find(table.concat(tip, " / "), "Right-click: back to your place", 1, true),
		"its tooltip says so, got %s", table.concat(tip, " / "))
	A.GoToPreviousObjective, A.SkipToNextObjective, A.RememberPlace, A.ReturnToPlace = keep[1], keep[2], keep[3], keep[4]
end

-- The Appearance and Step Display pages ------------------------------------------------

do
	local A = AegisPathfinder
	local profile, char = A.db.profile, A.db.char
	char.overviewmode = false
	A.current = 3
	A.tags[3].N = "Travel to Goldshire"
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 100, 650)
	frame:Show()
	A:OnObjectiveFrameResized()
	A:UpdateOHPanel()
	local one = frame:GetHeight()

	-- Steps shown in focus mode: the step you are on, and the ones after it.
	A.current = 1
	char.focussteps = 3
	A:OnObjectiveFrameResized()
	A:UpdateOHPanel()
	check(built[1]:IsShown() and built[2]:IsShown() and built[3]:IsShown() and not built[4]:IsShown(),
		"three steps shown in focus mode")
	check(built[1].i == 1 and built[2].i == 2 and built[3].i == 3, "the one you are on and the two after it")
	local _, _, _, _, y2 = built[2]:GetPoint()
	check(math.abs(-y2 - (86 + built[1]:GetHeight() + 2)) < 0.01, "the next starts under the first, got %s", tostring(y2))
	check(frame:GetHeight() == 86 + built[1]:GetHeight() + 2 + built[2]:GetHeight() + built[3]:GetHeight() + 8 + 24,
		"and the panel holds all three, got %s", tostring(frame:GetHeight()))
	A.current = 4
	A:OnObjectiveFrameResized()
	A:UpdateOHPanel()
	check(built[2]:IsShown() and not built[3]:IsShown(), "near the end, only the steps the guide has left")
	char.focussteps = nil
	A.current = 3
	A:OnObjectiveFrameResized()
	A:UpdateOHPanel()
	check(not built[2]:IsShown() and frame:GetHeight() == one, "back to one, the step alone")

	-- Step text size: the text and the rows that hold it.
	A:SetStepTextSize(1.25)
	check(profile.steptextsize == 1.25 and built[1].text.__size == 15 and built[1].note.__size == 14,
		"bigger step text, got %s and %s", tostring(built[1].text.__size), tostring(built[1].note.__size))
	char.overviewmode = true
	A:OnObjectiveFrameResized()
	A:UpdateOHPanel(0)
	check(built[2]:GetHeight() == 55, "the list's rows grow with it, got %s", tostring(built[2]:GetHeight()))
	A:SetStepTextSize(1)
	A:UpdateOHPanel(0)
	check(profile.steptextsize == nil and built[2]:GetHeight() == 44 and built[1].text.__size == 12, "and back")
	check(A:SetStepTextSize(3) == 1.4, "no bigger than 140%%")
	A:SetStepTextSize(1)

	-- The progress bar: off, the steps move up into its place.
	A:SetGuideProgressShown(false)
	local _, _, _, _, y1 = built[1]:GetPoint()
	check(not frame.guideProgress:IsShown() and profile.showprogress == false and y1 == -82,
		"progress bar off: gone, and the list starts 4px higher, got %s", tostring(y1))
	A:SetGuideProgressShown(true)
	_, _, _, _, y1 = built[1]:GetPoint()
	check(frame.guideProgress:IsShown() and profile.showprogress == nil and y1 == -86, "and back")
	char.overviewmode = false
	A:OnObjectiveFrameResized()
	A:UpdateOHPanel()

	-- Growing upward: the bottom edge stays where it is.
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 100, 650)
	A:UpdateOHPanel()
	local bottom = frame:GetBottom()
	A:SetGuideUpward(true)
	check(profile.objframeupward and frame:GetPoint() == "BOTTOMLEFT" and profile.objframepoint == "BOTTOMLEFT",
		"growing upward, the panel is pinned and kept by its bottom")
	A.tags[3].N = string.rep("Follow the road south past the farms and the river. ", 12)
	A:UpdateOHPanel()
	check(math.abs(frame:GetBottom() - bottom) < 0.01 and frame:GetHeight() > one, "a long step grows it upward, its bottom where it was")
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 100, 650)
	A:UpdateOHPanel()
	check(frame:GetPoint() == "BOTTOMLEFT", "and it goes back to its bottom edge after anything moves it by the top")
	A:SetGuideUpward(false)
	check(not profile.objframeupward and frame:GetPoint() == "TOPLEFT", "off, it grows down from its top again")
	A.tags[3].N = "Travel to Goldshire"
	A:UpdateOHPanel()

	-- Opacity: what Transparency makes the panel.
	A:SetGuideTransparent(true)
	check(fillPiece.__color[4] == 0.5, "Transparency, at half to start with")
	A:SetGuideOpacity(0.3)
	check(profile.objframeopacity == 0.3 and fillPiece.__color[4] == 0.3, "the opacity slider sets how see-through")
	A:SetGuideTransparent(false)
	A:SetGuideOpacity(0.7)
	check(fillPiece.__color[4] == 1, "with Transparency off, solid whatever the slider says")
	profile.objframeopacity = nil

	-- Hiding the guide: in dungeons and raids, and in combat.
	local inside, kind = false, "none"
	IsInInstance = function() return inside, kind end
	local paints = 0
	local keepPaint = A.PaintActiveFrames
	A.PaintActiveFrames = function() paints = paints + 1 end
	frame:Show()
	inside, kind = true, "party"
	A:OnGuideHideEvent("ZONE_CHANGED_NEW_AREA")
	check(frame:IsShown(), "switched off: a dungeon leaves the guide alone")
	profile.hideininstance = true
	A:OnGuideHideEvent("ZONE_CHANGED_NEW_AREA")
	check(not frame:IsShown() and char.panelopen ~= false, "on: hidden in a dungeon, still counted as open")
	inside, kind = false, "none"
	A:OnGuideHideEvent("ZONE_CHANGED_NEW_AREA")
	check(frame:IsShown(), "and shown again as you leave")
	profile.showafterinstance = false
	inside, kind = true, "raid"
	A:OnGuideHideEvent("PLAYER_ENTERING_WORLD")
	check(not frame:IsShown(), "a raid too")
	inside, kind = false, "none"
	A:OnGuideHideEvent("ZONE_CHANGED_NEW_AREA")
	check(not frame:IsShown(), "not shown again when asked not to")
	frame:Show()
	inside, kind = true, "pvp"
	A:OnGuideHideEvent("ZONE_CHANGED_NEW_AREA")
	check(frame:IsShown(), "a battleground is not a dungeon")
	inside, kind = false, "none"
	A:OnGuideHideEvent("ZONE_CHANGED_NEW_AREA")
	profile.hideininstance, profile.showafterinstance = nil, nil

	A:OnGuideHideEvent("PLAYER_REGEN_DISABLED")
	check(frame:IsShown(), "switched off: a fight leaves the guide alone")
	profile.hideincombat = true
	A:OnGuideHideEvent("PLAYER_REGEN_DISABLED")
	check(not frame:IsShown() and not A.buttonsHidden, "on: hidden in combat; the buttons stay unless asked")
	A:OnGuideHideEvent("PLAYER_REGEN_ENABLED")
	check(frame:IsShown(), "and back when the fight ends")
	profile.hidebuttonscombat = true
	A:OnGuideHideEvent("PLAYER_REGEN_DISABLED")
	check(A.buttonsHidden and paints == 1, "asked, the action buttons go too")
	A:OnGuideHideEvent("PLAYER_REGEN_ENABLED")
	check(A.buttonsHidden == nil and paints == 2, "and come back with it")
	frame:Hide()                                   -- closed before the fight
	A:OnGuideHideEvent("PLAYER_REGEN_DISABLED")
	A:OnGuideHideEvent("PLAYER_REGEN_ENABLED")
	check(not frame:IsShown(), "a guide you had closed stays closed after a fight")
	frame:Show()
	profile.hideininstance = true
	inside, kind = true, "party"
	A:OnGuideHideEvent("ZONE_CHANGED_NEW_AREA")
	A:OnGuideHideEvent("PLAYER_REGEN_DISABLED")
	A:OnGuideHideEvent("PLAYER_REGEN_ENABLED")
	check(not frame:IsShown(), "a fight in a dungeon ends with the guide still hidden for the dungeon")
	inside, kind = false, "none"
	A:OnGuideHideEvent("ZONE_CHANGED_NEW_AREA")
	check(frame:IsShown(), "until you leave it")
	profile.hideininstance, profile.hideincombat, profile.hidebuttonscombat = nil, nil, nil
	A.PaintActiveFrames = keepPaint
	IsInInstance = nil
end

-- Hints over the guide open beside it ------------------------------------------

-- The step arrows' hint covered the steps; now every hint inside the guide
-- opens outside it (Theme:TipOutside), here on its right, since it sits on
-- the left of the screen.
frame:ClearAllPoints()
frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -100)
local hovered = CreateFrame("Button", nil, frame)
hovered:SetWidth(20); hovered:SetHeight(20)
hovered:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -40)
Theme:ShowTip(hovered, "BOTTOM", "Skip to next objective", "Right-click: on to your place in the guide")
local tp, trel, trelP, tx = Theme.tip:GetPoint(1)
check(tp == "TOPLEFT" and trel == UIParent and trelP == "BOTTOMLEFT"
	and tx and tx >= frame:GetRight(),
	"a hint inside the guide opens beside it, got %s at %s", tostring(tp), tostring(tx))
Theme:HideTip()

-- Report ---------------------------------------------------------------------

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end

print(string.format("ObjectivePanel: %d checks", checks))
if table.getn(failures) == 0 then
	print("All objective panel checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
