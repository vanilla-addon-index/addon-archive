local root = arg[1] .. "/Atlas-CFM/"
local function noop() end
tinsert, tremove = table.insert, table.remove
STANDARD_TEXT_FONT = "Test font"
local pins, updater, labels = {}, nil, 0
local function frame(parent)
    local f = { parent = parent, shown = true, scripts = {}, level = 0, width = 1000, height = 668 }
    function f:SetScript(event, fn) self.scripts[event] = fn end
    function f:GetParent() return self.parent end
    function f:SetParent(value) self.parent = value end
    function f:GetFrameLevel() return self.level end
    function f:SetFrameLevel(value) self.level = value end
    function f:GetWidth() return self.width end
    function f:SetWidth(value) self.width = value end
    function f:GetHeight() return self.height end
    function f:SetHeight(value) self.height = value end
    function f:IsShown() return self.shown end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:SetPoint(point, relative, anchor, x, y)
        self.point, self.relative, self.anchor, self.x, self.y = point, relative, anchor, x, y
    end
    f.ClearAllPoints, f.RegisterEvent = noop, noop
    function f:CreateTexture() return {SetAllPoints = noop, SetTexture = noop} end
    function f:CreateFontString()
        labels = labels + 1
        local label = frame(self)
        function label:SetFont(_, size, outline) self.fontSize, self.outline = size, outline end
        label.SetTextColor = noop
        function label:SetText(text) self.text = text end
        return label
    end
    return f
end
WorldMapFrame = frame()
WorldMapDetailFrame = frame(WorldMapFrame)
WorldMapTooltip = frame()
WorldMapTooltip.SetOwner, WorldMapTooltip.SetText, WorldMapTooltip.AddLine = noop, noop, noop
function CreateFrame(kind, _, parent)
    local new = frame(parent)
    if kind == "Button" then
        table.insert(pins, new)
    elseif parent == WorldMapFrame then
        assert(not updater, "must reuse the updater")
        updater = new
    end
    return new
end

GetLocale = function() return "enUS" end
local continent, zone = 1, "Durotar"
GetCurrentMapContinent = function() return continent end
GetCurrentMapZone = function() return 1 end
GetMapZones = function() return zone end
AtlasCFMOptions = { ShowMapMarkers = true, AtlasServer = "Turtle WoW" }
dofile(root .. "CFMAtlas/AtlasConfig.lua")
dofile(root .. "CFMAtlas/AtlasServer.lua")
dofile(root .. "Locales/LocalizationFramework.lua")
dofile(root .. "Locales/enUS/Core.lua")
dofile(root .. "CFMAtlas/AtlasMapMarkers.lua")
local update = AtlasCFM.MapMarkers.UpdateMarkers

local function visible()
    local count = 0
    for _, pin in ipairs(pins) do
        if pin.timerLabel and pin.timerLabel.shown then
            assert(pin.shown)
            count = count + 1
        end
    end
    return count
end
local function tick(elapsed)
    assert(updater.shown)
    arg1 = elapsed
    updater.scripts.OnUpdate()
end
local function pinAt(x, y)
    for _, pin in ipairs(pins) do
        if pin.shown and math.abs(pin.x - x * 1000) < 0.001 and math.abs(pin.y + y * 668) < 0.001 then
            return pin
        end
    end
    error("Missing marker")
end
update()
assert(updater.shown and labels == 0)
OctoBus = { GetDockTimer = true } -- Older or incompatible API
tick(1)
assert(labels == 0)
local calls = {}
local state, seconds, mark = "wait", 59.5, "~"
OctoBus.GetDockTimer = function(entry, otherEnd)
    assert(type(entry) == "number" and type(otherEnd) == "boolean")
    calls[entry .. ":" .. tostring(otherEnd)] = true
    return state, seconds, mark
end
tick(.5)
assert(labels == 0)
tick(.5)
assert(visible() == 5 and labels == 5)
update()
assert(visible() == 5 and labels == 5, "rebuilding Durotar must reuse the existing labels")
local expected = {
    {1, "Durotar", .51, .145, 164871, false},
    {1, "Durotar", .51, .115, 175080, false, "BOTTOM", "TOP", 2},
    {1, "Durotar", .41, .165, 190552, false, "BOTTOM", "TOP", 2},
    {1, "Durotar", .41, .195, 190549, false},
    {1, "Durotar", .598, .236, 190550, false},
    {1, "Thunder Bluff", .165, .230, 190549, true},
    {1, "The Barrens", .636, .389, 20808, false},
    {2, "The Hinterlands", .812, .794, 190550, true},
    {2, "Stranglethorn Vale", .257, .730, 20808, true},
    {2, "Tirisfal Glades", .61, .58, 164871, true, "TOPRIGHT"},
    {2, "Tirisfal Glades", .63, .58, 176495, true, "TOPLEFT"},
    {2, "Stranglethorn Vale", .31, .265, 176495, false, "BOTTOM", "TOP", 2},
    {2, "Stranglethorn Vale", .31, .29, 175080, true},
    {2, "Badlands", .050, .470, 190552, true},
}
for _, row in ipairs(expected) do
    continent, zone = row[1], row[2]
    calls = {}
    update()
    local pin = pinAt(row[3], row[4])
    assert(pin.timerEntry == row[5] and pin.timerOtherEnd == row[6], zone)
    assert(calls[row[5] .. ":" .. tostring(row[6])], zone)
    assert(pin.timerLabel.text == "Docks ~1:00" and pin.timerLabel.shown)
    assert(pin.timerLabel.fontSize == 9 and pin.timerLabel.outline == "OUTLINE")
    assert(pin.timerLabel.point == (row[7] or "TOP"))
    assert(pin.timerLabel.anchor == (row[8] or "BOTTOM") and pin.timerLabel.y == (row[9] or -2))
end
assert(labels <= table.getn(pins), "each pooled pin should create at most one label")
local pin = pinAt(.050, .470)
pin.scripts.OnEnter()
pin.scripts.OnLeave()
assert(pin.timerEntry == 190552 and pin.timerLabel.shown)
state, seconds, mark = "docked", 17.6, "?"
tick(1)
assert(pin.timerLabel.text == "Leaves ?0:18")
state, seconds, mark = "departing", nil, nil
tick(1)
assert(pin.timerLabel.text == "Departing")
state = "wait"
tick(1)
assert(pin.timerLabel.text == "Arriving…")
state = "docked"
tick(1)
assert(pin.timerLabel.text == "Here now")
state = nil
tick(1)
assert(visible() == 0)
OctoBus = nil
tick(1)
assert(visible() == 0)

OctoBus = {GetDockTimer = function() return "wait", 42 end}
AtlasCFMOptions.AtlasServer = "Vanilla Plus"
continent, zone = 1, "The Barrens"
update()
assert(not pinAt(.636, .389).timerEntry and visible() == 0 and not updater.shown)
continent, zone = 2, "Stranglethorn Vale"
update()
assert(not pinAt(.257, .730).timerEntry and not pinAt(.31, .29).timerEntry and visible() == 1)
continent, zone = 1, "Durotar"
update()
assert(not pinAt(.51, .115).timerEntry and visible() == 1)
AtlasCFMOptions.ShowMapMarkers = false
update()
assert(visible() == 0 and not updater.shown)
AtlasCFMOptions.ShowMapMarkers = true
update()
assert(visible() == 1 and updater.shown)
WorldMapFrame:Hide()
assert(visible() == 0 and not updater.shown)
for _, recycled in ipairs(pins) do
    assert(not recycled.timerEntry and recycled.timerOtherEnd == nil and recycled.timerSide == nil)
end
WorldMapFrame:Show()
update()
assert(visible() == 1 and updater.shown)
local opened = false
AtlasCFM.LoadCore = function() opened = true; return false end
pinAt(.51, .145).scripts.OnClick()
assert(opened, "clicking a timed pin must still ask Atlas to open its page")
OctoBus = nil
tick(1)
assert(visible() == 0, "a disappearing API must hide visible labels")
print("PASS: 14 dock mappings, server variants, late/absent OctoBus, text and rounding, hover, pooling, and map lifecycle")
