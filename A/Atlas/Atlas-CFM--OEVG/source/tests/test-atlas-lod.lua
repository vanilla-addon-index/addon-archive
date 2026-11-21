local root = arg[1]
local mode = arg[2]
local function front(path) dofile(root .. "/Atlas-CFM/" .. path) end
local function core(path) dofile(root .. "/Atlas-CFM_Core/" .. path) end
local function noop() end
local function send(frame, ev, value)
    this, event, arg1 = frame, ev, value
    frame:GetScript("OnEvent")()
end

function CreateFrame(_, name)
    local f = {scripts = {}, events = {}}
    function f:RegisterEvent(ev) self.events[ev] = true end
    function f:UnregisterEvent(ev) self.events[ev] = nil end
    function f:UnregisterAllEvents() self.events = {} end
    function f:SetScript(ev, fn) self.scripts[ev] = fn end
    function f:GetScript(ev) return self.scripts[ev] end
    function f:Show() self.visible = true end
    function f:Hide() self.visible = false end
    if name then _G[name] = f end
    return f
end
local originalCreateFrame = CreateFrame
local errors = {}
function geterrorhandler()
    return function(err) table.insert(errors, err) end
end
GetAddOnMetadata = function() return "1.89.1" end
GetLocale = function() return "enUS" end
SlashCmdList = {}
ERR_QUEST_COMPLETE_S = "%s completed."
AtlasCFMOptions = {TooltipShowDropRate = false}
AtlasCFMCharDB = {WishList = {22339}, FirstTime = false}
if mode == "preload" then AtlasCFMStubOptions = {preload = true} end
front("CFMAtlas/AtlasConfig.lua")
front("Locales/LocalizationFramework.lua")
front("Locales/enUS/Core.lua")
front("Stub/Persistence.lua")
front("Stub/Loader.lua")
local stub = AtlasCFMStubFrame
send(stub, "ADDON_LOADED", "Atlas-CFM")
assert(not AtlasCFM.IsCoreLoaded())
assert(AtlasCFMOptions.TooltipShowDropRate == false)
assert(AtlasCFMCharDB.WishList[1] == 22339 and AtlasCFMCharDB.FirstTime == false)
send(stub, "CHAT_MSG_SYSTEM", "Test Quest completed.")
this, event, arg1, arg2 = stub, "CHAT_MSG_ADDON", "TWQUEST", "12345"
stub:GetScript("OnEvent")()
assert(AtlasCFMStubCharDB.questIDs[12345] and AtlasCFMStubCharDB.questNames["Test Quest"])

local events, loads, toggles, indexRuns, marked = {}, 0, 0, 0, 0
local recorded
function LoadAddOn(name)
    assert(name == "Atlas-CFM_Core")
    loads = loads + 1
    if mode == "disabled" and loads == 1 then return nil, "DISABLED" end
    core("Replay/Begin.lua")
    recorded = CreateFrame("Frame")
    for _, ev in ipairs({"ADDON_LOADED", "VARIABLES_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "TRADE_SKILL_SHOW", "CRAFT_SHOW"}) do
        recorded:RegisterEvent(ev)
    end
    recorded:RegisterEvent("INVALIDATED")
    recorded:UnregisterEvent("INVALIDATED")
    recorded:SetScript("OnEvent", function()
        assert(this == recorded)
        if event == "ADDON_LOADED" then assert(arg1 == "Atlas-CFM") end
        table.insert(events, event)
    end)
    AtlasCFM.ToggleAtlas = function() toggles = toggles + 1 end
    AtlasCFM.DataIndex = {CheckAndBuildIndex = function() indexRuns = indexRuns + 1 end}
    AtlasCFM.Quest = {
        DataBase = {Example = {Horde = {{Id = 12345}}}},
        MarkQuestComplete = function(name)
            assert(name == "Test Quest")
            marked = marked + 1
        end
    }
    core("Replay/End.lua")
    -- Client reports the core's ADDON_LOADED before LoadAddOn returns.
    local oldThis, oldEvent, oldArg = this, event, arg1
    send(stub, "ADDON_LOADED", name)
    this, event, arg1 = oldThis, oldEvent, oldArg
    return true
end

send(stub, "PLAYER_ENTERING_WORLD")
assert(loads == 0, "Login must not load the core inside the event handler")
if mode == "preload" then
    assert(stub:GetScript("OnUpdate"))
    stub:GetScript("OnUpdate")()
elseif mode == "profession" then
    send(stub, "TRADE_SKILL_SHOW")
elseif mode == "craft" then
    send(stub, "CRAFT_SHOW")
elseif mode == "disabled" then
    assert(not AtlasCFM.LoadCore())
    assert(not AtlasCFM.IsCoreLoaded())
    AtlasCFM.ToggleAtlas()
    assert(toggles == 1)
else
    assert(not stub:GetScript("OnUpdate"))
    AtlasCFM.ToggleAtlas()
    assert(toggles == 1)
end
assert(AtlasCFM.IsCoreLoaded() and loads == (mode == "disabled" and 2 or 1))
assert(CreateFrame == originalCreateFrame and AtlasCFM._Replay == nil)
assert(table.concat(events, ",") ==
    "ADDON_LOADED,VARIABLES_LOADED,PLAYER_LOGIN,PLAYER_ENTERING_WORLD" ..
    (mode == "profession" and ",TRADE_SKILL_SHOW" or mode == "craft" and ",CRAFT_SHOW" or ""))
assert(indexRuns == 1 and marked == 1 and AtlasCFMCharDB.Completed_Example_Quest_1_Horde == 1)
assert(next(AtlasCFMStubCharDB.questIDs) == nil)
assert(AtlasCFM.LoadCore() and loads == (mode == "disabled" and 2 or 1))
assert(table.getn(errors) == 0, errors[1])

local callbacks, queries, shown, predictions = {}, {}, 0, 0
PrintA = noop
AtlasCFMLoot_InvalidateCategorizedList = noop
AtlasCFM.DataIndex = {
    WhenReady = function(fn) table.insert(callbacks, fn) end,
    FindItems = function(query) table.insert(queries, query); return {} end
}
core("CFMLoot/Core/Search.lua")
AtlasCFM.SearchLib.ShowResult = function() shown = shown + 1 end
local search = AtlasCFM.SearchLib.Search
local function prediction() predictions = predictions + 1 end
search("Prediction before", prediction)
search("First submitted")
search("Prediction after", prediction)
search("Second submitted")
AtlasCFM.DataIndex.isIndexed = true
for _, fn in ipairs(callbacks) do fn() end
assert(table.getn(queries) == 1 and queries[1] == "Second submitted")
assert(shown == 1 and predictions == 0)
search("Prediction after ready", prediction)
assert(predictions == 1 and table.getn(queries) == 2)
callbacks = {}
AtlasCFM.DataIndex.isIndexed = false
search("Earlier prediction", prediction)
search("Latest prediction", prediction)
AtlasCFM.DataIndex.isIndexed = true
for _, fn in ipairs(callbacks) do fn() end
assert(predictions == 2 and queries[3] == "Latest prediction")

local time, fired = 0, {}
GetTime = function() return time end
core("CFMLoot/Core/Utils.lua")
AtlasCFM.Timer.Start(1, function()
    table.insert(fired, "first")
    AtlasCFM.Timer.Start(1, function() table.insert(fired, "new") end)
end)
AtlasCFM.Timer.Start(3, function() table.insert(fired, "last") end)
local timer = AtlasCFMTimerFrame
for n = 1, 3 do
    time = n
    timer:GetScript("OnUpdate")()
end
assert(table.concat(fired, ",") == "first,new,last" and not timer.visible)
print("PASS " .. mode .. ": loader, lifecycle, saved options, quest queue, and search priority")
