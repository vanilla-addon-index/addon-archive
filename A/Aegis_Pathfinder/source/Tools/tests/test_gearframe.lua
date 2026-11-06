--[[
	Tests for the Item Score page (GearFrame.lua): the stat weights behind the
	item score, through the real scorer (ItemScore.lua) and its data. The page
	is built here into a bare frame, as the options window would build it;
	test_options.lua checks it in the window.

	Run:  lua5.1 Tools/tests/test_gearframe.lua
]]

package.path = "Tools/tests/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

UISpecialFrames = {}
AegisPathfinder = { db = { char = {}, profile = {} } }
function AegisPathfinder:Print() end
UnitClass = function() return "Paladin", "PALADIN" end
local talents = { { "Holy", 0 }, { "Protection", 0 }, { "Retribution", 0 } }
GetTalentTabInfo = function(tab) return talents[tab][1], "icon", talents[tab][2] end

dofile("Theme.lua")
dofile("ItemScoreData.lua")
dofile("ItemScore.lua")
dofile("GearFrame.lua")
local A, IS, Data = AegisPathfinder, AegisPathfinder.ItemScore, AegisPathfinder.ItemScoreData

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end
local function run(f, script)
	local h = f:GetScript(script)
	assert(h, "no " .. script .. " script")
	local old = this
	this = f
	h()
	this = old
end

-- The options window's page: 354 wide, the section header above it, 16 under it.
local WIDTH, TOP, BOTTOM = 354, 27, 16
local body = CreateFrame("Frame", nil, UIParent)
body:SetWidth(WIDTH)
local sized = 0
function A:SizeConfigPage(keep) sized = sized + 1; self.__keep = keep end
local page = A:CreateItemScorePage(body, WIDTH, TOP, BOTTOM)
check(A.gearframe == nil and A.ToggleGearPanel == nil and A.CreateGearPanel == nil,
	"there is no Gear window any more")
check(page == A.itemscorepage and A.ITEM_SCORE_PAGE == "Item Score", "the page, and its name in the list")
check(type(body.refresh) == "function", "the window can ask it to draw itself")
body:Show()
body.refresh()

-- The spec picker: Auto, naming what it is now, then every spec.
local items = page.spec.items
check(items[1].value == "auto" and items[1].label == "Auto (Retribution)",
	"Auto first, naming the levelling spec, got %s", tostring(items[1].label))
check(table.getn(items) == 4, "then the three Paladin specs, got %d", table.getn(items))
check(page.spec:GetValue() == "auto", "Auto chosen until you pick")
check(page.class:GetText() == "Paladin", "the class beside it")
local _, _, _, _, specY = page.spec:GetPoint()
check(specY == -TOP, "under the section header, got %s", tostring(specY))
check(string.find(page.note:GetText(), "leveling spec", 1, true), "the note says where the spec came from")
check(string.find(page.note:GetText(), "Leveling weights, until level 60: the defaults.", 1, true),
	"and that they are the default leveling weights, got %s", page.note:GetText())

-- The weights listed, one to a row down the left: the spec's, then all of them.
local function listed()
	local out = {}
	for stat, cell in pairs(page.cells) do if cell:IsShown() then out[stat] = cell end end
	return out
end
local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
local weighted = 0
for _, w in pairs(Data.leveling.PALADIN.Retribution) do if w ~= 0 then weighted = weighted + 1 end end
check(count(listed()) == weighted, "the stats Retribution weighs are listed (%d of %d)", count(listed()), weighted)
local xs, ys = {}, {}
for _, cell in pairs(listed()) do
	local _, _, _, x, y = cell:GetPoint()
	xs[x] = true
	ys[y] = true
end
check(count(xs) == 1 and xs[0], "in one column, at the left")
check(count(ys) == weighted, "a row each")
local _, _, _, shareX = page.share:GetPoint()
local cellW = page.cells.STRENGTH:GetWidth()
check(shareX > cellW and shareX + page.share:GetWidth() == WIDTH,
	"the import box beside the list, to the right edge (x %s, list %s wide)", tostring(shareX), tostring(cellW))
local _, rel = page.import:GetPoint()
local _, rel2 = page.export:GetPoint()
check(rel == page.share and rel2 == page.import, "Import under the box, Export under Import")

local shortH = body.contentHeight
local _, _, _, _, resetY = page.reset:GetPoint()
check(shortH == -resetY + page.reset:GetHeight() + BOTTOM, "the page ends under Reset, got %s", tostring(shortH))
check(sized > 0 and A.__keep == true, "and the window is told its height, keeping its place")

run(page.showAll, "OnClick")
check(count(listed()) == table.getn(Data.stats), "Show all stats lists every one, got %d", count(listed()))
local _, _, _, _, resetY2 = page.reset:GetPoint()
local lowest = 0
for _, cell in pairs(listed()) do
	local _, _, _, _, y = cell:GetPoint()
	if y < lowest then lowest = y end
end
check(resetY2 < lowest, "Reset under the last row")
local more = (table.getn(Data.stats) - weighted) * page.cells.STRENGTH:GetHeight()
check(more > 0 and body.contentHeight == shortH + more,
	"and the page grows a row a stat, so the window scrolls it (%s from %s)", tostring(body.contentHeight), tostring(shortH))
run(page.showAll, "OnClick")
check(body.contentHeight == shortH, "and shrinks back")

-- Editing a weight.
local str = A:ItemScoreCell("STRENGTH")
check(str.label:GetText() == "Strength", "stats named for people, got %s", tostring(str.label:GetText()))
check(str.label:GetWidth() >= 130, "the name column holds the long names on a line, got %s", tostring(str.label:GetWidth()))
check(A:ItemScoreCell("DPS").label:GetText() == "Weapon DPS", "DPS stays DPS")
local default = Data.leveling.PALADIN.Retribution.STRENGTH
check(tonumber(str.box:GetText()) == default, "the box shows the weight, got %s", tostring(str.box:GetText()))
str.box:SetText("3.5")
run(str.box, "OnEnterPressed")
check(IS:Weights().STRENGTH == 3.5, "Enter puts the new weight into effect")
check(string.find(page.note:GetText(), "with your own changes", 1, true), "and the note says they are yours now")
str.box:SetText("lots")
run(str.box, "OnEditFocusLost")
check(IS:Weights().STRENGTH == 3.5 and str.box:GetText() == "3.5", "text that is not a number is put back")
str.box:SetText("9")
run(str.box, "OnEscapePressed")
check(IS:Weights().STRENGTH == 3.5 and str.box:GetText() == "3.5", "Escape puts back the weight it had")
str.box:SetFocus()
run(str.box, "OnHide")
check(not str.box:HasFocus(), "a box hidden with the page lets go of the keyboard")

-- Export, import, reset.
run(page.export, "OnClick")
check(string.find(page.share:GetText(), "^OPW1:PALADIN:Retribution:%*") and string.find(page.share:GetText(), "|STRENGTH:3.5", 1, true),
	"export fills the box, got %s", tostring(page.share:GetText()))
check(string.find(page.status:GetText(), "Ctrl+C", 1, true), "and says how to copy it, under the buttons")
check(page.reset:GetText() == "RESET WEIGHTS", "the button says Reset weights, got %s", tostring(page.reset:GetText()))
run(page.reset, "OnClick")
check(IS:Weights().STRENGTH == default and tonumber(str.box:GetText()) == default, "reset goes back to the defaults")
check(page.status:GetText() == "Back to the default weights.", "and says so")
check(string.find(page.note:GetText(), ": the defaults.", 1, true), "and the note says so too")
run(page.import, "OnClick")
check(IS:Weights().STRENGTH == 3.5, "import brings the exported weights back")
check(page.status:GetText() == "Imported.", "and says so")
page.share:SetText("OPW1:MAGE:Frost:*")
run(page.import, "OnClick")
check(string.find(page.status:GetText(), "MAGE", 1, true), "a refused import says why, got %s", page.status:GetText())
body.refresh()
check(page.status:GetText() == "", "turning back to the page clears what it last said")

-- Picking a spec.
local protRow
for _, row in ipairs(page.spec.rows) do if row.value == "Protection" then protRow = row end end
run(protRow, "OnClick")
check(IS:Spec() == "Protection", "picking a spec scores as it")
check(page.spec:GetValue() == "Protection", "and the picker shows it")
check(string.find(page.note:GetText(), "the spec you picked", 1, true), "and the note says you picked it")
check(tonumber(str.box:GetText()) == Data.weights.PALADIN.Protection.STRENGTH, "the boxes show that spec's weights, got %s",
	tostring(str.box:GetText()))
check(string.find(page.note:GetText(), "Tank weights, the same at every level", 1, true), "a tank's are the same at every level")

-- At 60, the 60 set.
UnitLevel = function() return 60 end
IS:SetSpec("Retribution")
check(string.find(page.note:GetText(), "Level 60 weights: the defaults.", 1, true), "at 60 the note says the 60 set, got %s",
	page.note:GetText())
check(tonumber(str.box:GetText()) == Data.weights.PALADIN.Retribution.STRENGTH, "and the boxes show it")
UnitLevel = function() return 1 end
IS:SetSpec("Protection")

-- Talents change what Auto means; the page follows while it is on screen.
IS:SetSpec(nil)
talents[1][2] = 21
IS:Changed()
check(page.spec.items[1].label == "Auto (Holy)", "Auto follows your talents, got %s", page.spec.items[1].label)
body:Hide()
talents[1][2], talents[2][2] = 0, 21
IS:Changed()
check(page.spec.items[1].label == "Auto (Holy)", "not while another page is shown")
body:Show()
body.refresh()
check(page.spec.items[1].label == "Auto (Protection)", "until it is turned to")

-- Pawn's specs: a switch for each, yours locked on ----------------------------------------

do
	GetInventoryItemLink = function() return nil end
	talents[1][2], talents[2][2], talents[3][2] = 0, 0, 0     -- the levelling spec: Retribution
	IS:SetSpec(nil)
	body.refresh()
	local byspec = {}
	for _, sw in ipairs(page.specSwitches) do byspec[sw.spec] = sw end
	check(table.getn(page.specSwitches) == 3 and byspec.Holy and byspec.Protection and byspec.Retribution,
		"a switch for each Paladin spec")
	check(byspec.Retribution:IsOn() and not byspec.Retribution:IsEnabled(), "your spec is on, and cannot be switched off")
	check(string.find(byspec.Retribution.label:GetText(), "your spec", 1, true), "and says it is yours")
	check(not byspec.Protection:IsOn() and byspec.Protection:IsEnabled(), "another spec starts off, and can be switched on")
	run(byspec.Protection, "OnClick")
	check(IS:IsSpecActive("Protection") and table.concat(IS:ActiveSpecs(), ",") == "Retribution,Protection",
		"switching it on scores Protection too")
	check(byspec.Protection:IsOn(), "and the page shows it on")
	check(page.notify:IsOn(), "the drop notice starts on")
	run(page.notify, "OnClick")
	check(IS.Settings().notify == false, "and can be switched off")
	run(page.forget, "OnClick")
	check(string.find(page.status:GetText(), "Forgotten", 1, true), "forgetting says so")
	IS:SetSpec("Protection")
	check(byspec.Protection:IsOn() and not byspec.Protection:IsEnabled(), "a spec picked as yours is locked on")
	IS:SetSpec(nil)
	run(byspec.Protection, "OnClick")
	check(not IS:IsSpecActive("Protection"), "and off again")
end

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end
print(string.format("ItemScorePage: %d checks", checks))
if table.getn(failures) == 0 then
	print("All item score page checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
