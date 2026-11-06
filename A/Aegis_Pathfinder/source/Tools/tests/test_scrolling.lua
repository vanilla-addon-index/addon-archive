--[[
	Tests for the scrolling lists that used Blizzard's scroll templates.

	The guide list and the error log were the last windows still built on
	UIPanelScrollBarTemplate and UIPanelScrollFrameTemplate, which drew
	Blizzard's gold arrows and knob on the concept's flat panels. Both use the
	theme's bar now, so this checks the bar is wired to what it scrolls:
	carets, wheel, the ends of the range, and -- for the error log, whose text
	can be any length -- that the range follows the text.

	Run:  lua5.1 Tools/tests/test_scrolling.lua
]]

package.path = "Tools/tests/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

UISpecialFrames = {}
UnitLevel = function() return 10 end
UnitClass = function() return "Warrior", "WARRIOR" end
IsShiftKeyDown = function() return false end

AegisPathfinder = {
	guides = {}, guidelist = {}, qsplusguides = {},
	db = { char = { completion = {}, turnins = {}, browsertab = "zone", browserpanels = {} }, profile = {} },
}
function AegisPathfinder:Debug() end
function AegisPathfinder:Print() end
function AegisPathfinder.GetQuadrant() return "TOPRIGHT", "TOP", "RIGHT" end
function AegisPathfinder:IsRoutePackGuide() return false end
function AegisPathfinder:GetGuideCategory() return "dungeon" end
function AegisPathfinder:ParseGuideLevelRange() return nil, nil end
function AegisPathfinder:IsTemplateGuide() return false end
function AegisPathfinder:GuideBadge() return "dg", "DG" end
function AegisPathfinder:GuideZone() return nil end
function AegisPathfinder:ReturnFromBranch() end
function AegisPathfinder:EnsureTabs() return {} end

-- Far more guides than the list shows at once.
for i = 1, 80 do
	local name = string.format("Dungeons/Guide %02d", i)
	AegisPathfinder.guides[name] = function() return "" end
	table.insert(AegisPathfinder.guidelist, name)
end

AegisPathfinder.objectiveframe = CreateFrame("Frame", nil, UIParent)

dofile("Theme.lua")
dofile("GuideBrowser.lua")
dofile("MapOverlays.lua")
dofile("GuidePictures.lua")
dofile("GuideListFrame.lua")

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end

-- Guide browser ----------------------------------------------------------------------

local list = AegisPathfinder.guidelistframe
local ui = AegisPathfinder.browserui
AegisPathfinder.db.char.browsertab = "dungeons"
list:Show()
list:GetScript("OnShow")()
local bar = list.slider

check(bar.track ~= nil and bar.up ~= nil and bar.down ~= nil,
	"the guide browser scrolls with the theme's bar")
check(bar:IsShown(), "which shows once there are more guides than rows")

local shown = 0
for _, r in ipairs(ui.rows) do if r:IsShown() then shown = shown + 1 end end
local _, hi = bar:GetMinMaxValues()
check(hi == 80 - shown, "the range is what does not fit, got %s for %d rows", tostring(hi), shown)

local function firstGuide()
	return ui.rows[1].guide
end
check(firstGuide() == "Dungeons/Guide 01", "the list starts at the top, got %s", tostring(firstGuide()))

-- The carets move a few rows, as the wheel does.
bar.down:GetScript("OnClick")()
check(bar:GetValue() == 3, "the down caret moves three rows, got %s", tostring(bar:GetValue()))
check(firstGuide() == "Dungeons/Guide 04", "and the list follows, got %s", tostring(firstGuide()))
bar.up:GetScript("OnClick")()
check(bar:GetValue() == 0, "the up caret moves back, got %s", tostring(bar:GetValue()))
for _ = 1, 40 do bar.down:GetScript("OnClick")() end
check(bar:GetValue() == hi, "and neither runs past the end, got %s", tostring(bar:GetValue()))
check(ui.rows[shown].guide == "Dungeons/Guide 80", "the last guide is reachable")
for _ = 1, 40 do bar.up:GetScript("OnClick")() end
check(bar:GetValue() == 0, "or past the top, got %s", tostring(bar:GetValue()))

-- The bar keeps clear of the rows.
local _, _, _, barX = bar:GetPoint(1)
local _, _, _, listX = ui.list:GetPoint(2)
check(-barX + bar:GetWidth() <= -listX, "the bar must not sit over the rows (%d vs %d)",
	-barX + bar:GetWidth(), -listX)

-- Error log --------------------------------------------------------------------------

--[[ Core.lua is too large to load under the stub; lift the one function. It
	reads DIALOG_CHROME, a local there, so the lifted copy is given the same. ]]
local core = io.open("Core.lua"):read("*a")
local from = string.find(core, "function AegisPathfinder:CreateErrorLogFrame", 1, true)
local to = from and string.find(core, "\n---------------------------------", from, true)
assert(from and to, "could not find CreateErrorLogFrame in Core.lua")
local dc = string.match(core, "local DIALOG_CHROME = ([^\n]+)")
assert(dc, "could not find DIALOG_CHROME in Core.lua")
assert(loadstring("local DIALOG_CHROME = " .. dc .. "\n" .. string.sub(core, from, to)))()

AegisPathfinder.errorLog = {}
for i = 1, 30 do table.insert(AegisPathfinder.errorLog, "error " .. i) end
AegisPathfinder:CreateErrorLogFrame()
local log = AegisPathfinder.errorLogFrame
local logbar = log.scrollbar
local scroll = AegisPathfinderErrorLogScrollFrame

check(logbar ~= nil and logbar.track ~= nil, "the error log scrolls with the theme's bar")
check(AegisPathfinder.Theme:IsWindow(log), "and stacks with the other windows")

log:Show()
log:GetScript("OnShow")()
check(string.find(log.editBox:GetText() or "", "error 30", 1, true) ~= nil,
	"it shows the captured errors")

-- The client measures the text and reports the overhang.
scroll.__vrange = 300
scroll:GetScript("OnScrollRangeChanged")()
local _, loghi = logbar:GetMinMaxValues()
check(loghi == 300, "the range follows the text, got %s", tostring(loghi))

arg1 = -1; scroll:GetScript("OnMouseWheel")()
check(scroll:GetVerticalScroll() == 40, "the wheel scrolls the text, got %s",
	tostring(scroll:GetVerticalScroll()))
logbar.down:GetScript("OnClick")()
check(scroll:GetVerticalScroll() == 80, "and so does the caret, got %s",
	tostring(scroll:GetVerticalScroll()))

-- Moving the cursor below the view scrolls it into view.
scroll:SetHeight(200)
logbar:SetValue(0)
arg1, arg2, arg3, arg4 = 0, -260, 0, 14
log.editBox:GetScript("OnCursorChanged")()
check(scroll:GetVerticalScroll() == 260 + 14 - 200,
	"a cursor below the view is scrolled to, got %s", tostring(scroll:GetVerticalScroll()))
arg2 = -10
log.editBox:GetScript("OnCursorChanged")()
check(scroll:GetVerticalScroll() == 10,
	"and one above it too, got %s", tostring(scroll:GetVerticalScroll()))

-- Less text than before: the bar comes back inside the new range.
scroll.__vrange = 5
scroll:GetScript("OnScrollRangeChanged")()
check(logbar:GetValue() == 5, "a shrinking range pulls the bar back in, got %s",
	tostring(logbar:GetValue()))

-- Reopening starts from the top.
log:GetScript("OnShow")()
check(logbar:GetValue() == 0, "reopening the log starts at the top")

-- Report ---------------------------------------------------------------------

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end

print(string.format("Scrolling: %d checks", checks))
if table.getn(failures) == 0 then
	print("All scrolling checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
