--[[
	Tests for the dungeon chip grid and the "wired" signal behind it.

	The blue dot claims the loaded guide has steps for a dungeon. That claim is
	only useful if it is true, and it is derived by scanning raw guide text --
	the |D| filter runs at parse time, so the parsed guide cannot answer the
	question. These checks pin the scan down.

	Run:  lua5.1 Tools/tests/test_dungeons.lua
]]

package.path = "Tools/tests/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

AegisPathfinder = {
	guides = {}, guidelist = {},
	db = { char = { Dungeons = {}, currentguide = nil }, profile = {} },
}
function AegisPathfinder:Debug() end
function AegisPathfinder:Print() end
function AegisPathfinder.trim(s) return (string.gsub(s or "", "^%s*(.-)%s*$", "%1")) end
function AegisPathfinder.select(index, ...)
	if index == "#" then return table.getn(arg) end
	return arg[index]
end
function AegisPathfinder.split(delim, text)
	local out = {}
	for piece in string.gfind(text, "([^" .. delim .. "]+)") do
		table.insert(out, piece)
	end
	return out
end
function AegisPathfinder:LoadGuide() end
function AegisPathfinder:UpdateStatusFrame() end

dofile("Theme.lua")
dofile("Parser.lua")

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end

-- Wired detection ------------------------------------------------------------

AegisPathfinder.guides["Loch Modan (11-13)"] = function()
	return [[
A Some Quest |QID|307| |N|A quest giver (24.8, 18.4)| |Z|Loch Modan|
T Filthy Paws |QID|307| |N|Dungeon Quest| |R|Human| |D|!DM| |Z|Loch Modan|
A Deadmines Run |QID|1338| |N|Head in| |D|DM| |Z|Westfall|
A Stockade Run |QID|1339| |N|Head in| |D|STOCKADES/SM| |Z|Stormwind|
N Plain note with no dungeon tag |N|Nothing here|
]]
end
AegisPathfinder.guides["Clean Guide"] = function()
	return "N No dungeons at all |N|Just a note|\n"
end
AegisPathfinder.guides["Broken Guide"] = function()
	error("this guide blows up on load")
end

local found = AegisPathfinder:GetGuideDungeons("Loch Modan (11-13)")
check(found.DM == true, "a |D|DM| step should mark DM as referenced")
check(found.STOCKADES == true, "a multi-code tag should mark STOCKADES")
check(found.SM == true, "a multi-code tag should mark SM too")
check(found.BRD == nil, "a dungeon the guide never mentions must not be marked")

-- A negated tag still means the guide knows about that dungeon -- it is the
-- step that is conditional, not the relevance.
check(found.DM == true, "!DM should still count as a reference to DM")

local clean = AegisPathfinder:GetGuideDungeons("Clean Guide")
local n = 0
for _ in pairs(clean) do n = n + 1 end
check(n == 0, "a guide with no dungeon steps should report none, got %d", n)

-- A guide that errors on load must not take the panel down with it.
local ok, result = pcall(function()
	return AegisPathfinder:GetGuideDungeons("Broken Guide")
end)
check(ok, "a guide that errors while loading must not propagate the error")
if ok then
	local m = 0
	for _ in pairs(result) do m = m + 1 end
	check(m == 0, "a guide that failed to load reports no dungeons")
end

check(type(AegisPathfinder:GetGuideDungeons("No Such Guide")) == "table",
	"an unknown guide should return an empty table, not nil")
AegisPathfinder.db.char.currentguide = nil
check(type(AegisPathfinder:GetGuideDungeons()) == "table",
	"no current guide should return an empty table, not nil")

-- The scan walks the whole guide, so results are cached per guide.
AegisPathfinder.db.char.currentguide = "Loch Modan (11-13)"
local calls = 0
local original = AegisPathfinder.guides["Loch Modan (11-13)"]
AegisPathfinder.guides["Loch Modan (11-13)"] = function()
	calls = calls + 1
	return original()
end
AegisPathfinder.guidedungeoncache = nil
AegisPathfinder:GetGuideDungeons("Loch Modan (11-13)")
AegisPathfinder:GetGuideDungeons("Loch Modan (11-13)")
AegisPathfinder:GetGuideDungeons("Loch Modan (11-13)")
check(calls == 1, "the guide scan should be cached, ran %d times", calls)

-- Chip widget ----------------------------------------------------------------

local Theme = AegisPathfinder.Theme
local chip = Theme:Chip(UIParent, "DM", "Deadmines", 78, 34)

check(chip.codeText:GetText() == "DM", "the chip shows its code")
check(chip.nameText:GetText() == "Deadmines", "the chip shows the full name")
check(chip:IsActive() == false, "a new chip starts inactive")
check(not chip.dot:IsShown(), "the wired dot starts hidden")

chip:SetActive(true)
check(chip:IsActive() == true, "SetActive(true) should register")
check(chip.fill.center.__color[2] > 0.78, "an active chip fills with accent")
-- The concept switches to dark text on the accent fill; light text there would
-- be unreadable.
check(chip.codeText.__color[1] < 0.2 and chip.codeText.__color[2] < 0.2,
	"an active chip's code should be dark on the accent fill")
check(chip.nameText.__color[1] < 0.2,
	"an active chip's name should be dark on the accent fill")

chip:SetActive(false)
check(chip.fill.center.__color[1] < 0.2, "an inactive chip returns to the panel colour")
check(chip.codeText.__color[1] > 0.9, "an inactive chip's code returns to light text")

chip:SetWired(true)
check(chip.dot:IsShown(), "SetWired(true) shows the dot")
chip:SetWired(false)
check(not chip.dot:IsShown(), "SetWired(false) hides it")

-- Active and wired are independent: a dungeon can be referenced by the guide
-- without being opted into, and vice versa.
chip:SetWired(true)
chip:SetActive(true)
check(chip.dot:IsShown(), "activating a chip must not clear its wired mark")

-- Report ---------------------------------------------------------------------

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end

print(string.format("Dungeons: %d checks", checks))
if table.getn(failures) == 0 then
	print("All dungeon checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
