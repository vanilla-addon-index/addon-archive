---
--- Loader.lua - [Atlas-CFM split] always-loaded loader for Atlas-CFM_Core.
---
--- Atlas-CFM is split into this small stub (always loaded) and Atlas-CFM_Core
--- (## LoadOnDemand: 1), which holds the maps UI, loot browser, quest panel and
--- all of the large data tables. The core is loaded the first time it is needed:
---   * Atlas window / options: minimap button, /atlascfm, key bindings,
---     clicking a World Map marker
---   * opening a trade skill or craft window (TRADE_SKILL_SHOW / CRAFT_SHOW)
---   * at login, only when "/atlascfm preload" is switched on
---
--- After LoadAddOn the startup events the core missed are replayed to the
--- frames it created (see Atlas-CFM_Core\Replay\Begin.lua), so the upstream
--- code initialises exactly as it would have at login.
---
--- While the core is not loaded, quest-completion messages are queued in
--- AtlasCFMStubCharDB and applied when it loads, so completion tracking is not
--- lost on sessions where Atlas is never opened.
---
--- @compatible World of Warcraft 1.12 (Lua 5.0)
---

local _G = getfenv()
local AtlasCFM = _G.AtlasCFM

local CORE = "Atlas-CFM_Core"
local PREFIX = "|cffFFd200Atlas-CFM:|r "

local coreLoaded = false
local coreLoading = false
local finished = false
local pendingTrigger = nil -- event that caused LoadCore (replayed after startup events)

local function Print(msg)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg) end
end

local function ReportError(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then
        handler(err)
    else
        Print("|cffff3333" .. tostring(err) .. "|r")
    end
end

-- Same 1.12 polyfill ProfessionHooks.lua installs; kept here so the global is
-- present at login exactly as it was when everything loaded at startup.
if not hooksecurefunc then
    function hooksecurefunc(name, func)
        local original = _G[name]
        _G[name] = function(...)
            if original then original(unpack(arg)) end
            func(unpack(arg))
        end
    end
end

-----------------------------------------------------------------------------
-- Startup event replay
-----------------------------------------------------------------------------

local ARGS = { "arg1", "arg2", "arg3", "arg4", "arg5", "arg6", "arg7", "arg8", "arg9" }

local function FireRecorded(R, ev, a1)
    -- Snapshot: frames created by a handler during this pass do not receive it.
    local n = table.getn(R.list)
    for i = 1, n do
        local rec = R.list[i]
        if rec.events[ev] then
            local handler = rec.frame:GetScript("OnEvent")
            if handler then
                this = rec.frame
                event = ev
                arg1 = a1
                for k = 2, 9 do _G[ARGS[k]] = nil end
                local ok, err = pcall(handler)
                if not ok then ReportError(err) end
            end
        end
    end
end

local function FlushQueuedQuests()
    local db = AtlasCFMStubCharDB
    if type(db) ~= "table" then return end
    local Quest = AtlasCFM.Quest
    if not Quest or not Quest.DataBase or type(AtlasCFMCharDB) ~= "table" then return end
    AtlasCFM.Q = AtlasCFM.Q or {}

    -- Quest names from "<quest> completed." system messages.
    if type(db.questNames) == "table" and Quest.MarkQuestComplete then
        for name in pairs(db.questNames) do
            local ok, err = pcall(Quest.MarkQuestComplete, name)
            if not ok then ReportError(err) end
        end
    end

    -- Quest IDs from TWQUEST addon messages: one pass over the database
    -- (same effect as Quest.MarkQuestCompleteByID for each ID).
    if type(db.questIDs) == "table" and next(db.questIDs) then
        local ids = db.questIDs
        for instanceName, instanceData in pairs(Quest.DataBase) do
            for _, factionName in ipairs({ "Alliance", "Horde" }) do
                local quests = instanceData[factionName]
                if quests then
                    for i, quest in ipairs(quests) do
                        if quest.Id and ids[quest.Id] then
                            local questKey = "Completed_" .. instanceName .. "_Quest_" .. i .. "_" .. factionName
                            AtlasCFMCharDB[questKey] = 1
                            AtlasCFM.Q[questKey] = 1
                        end
                    end
                end
            end
        end
    end

    db.questNames = {}
    db.questIDs = {}
end

-- Runs once, after Atlas-CFM_Core has finished loading (from LoadCore or from
-- its ADDON_LOADED, whichever comes first).
local function FinishCoreLoad()
    if finished then return end
    finished = true
    coreLoaded = true
    local triggerEvent = pendingTrigger
    pendingTrigger = nil

    local R = AtlasCFM._Replay
    if R then
        -- Safety net in case Replay\End.lua did not run.
        if R.origCreateFrame then CreateFrame = R.origCreateFrame end

        local saved = { this = this, event = event }
        for k = 1, 9 do saved[k] = _G[ARGS[k]] end

        FireRecorded(R, "ADDON_LOADED", AtlasCFM.Name)
        FireRecorded(R, "VARIABLES_LOADED")
        FireRecorded(R, "PLAYER_LOGIN")
        FireRecorded(R, "PLAYER_ENTERING_WORLD")
        if triggerEvent then
            FireRecorded(R, triggerEvent)
            -- The window was already drawn before the hooks existed: redraw it.
            local redraw
            if triggerEvent == "TRADE_SKILL_SHOW" and TradeSkillFrame and TradeSkillFrame:IsVisible() then
                redraw = TradeSkillFrame_Update
            elseif triggerEvent == "CRAFT_SHOW" and CraftFrame and CraftFrame:IsVisible() then
                redraw = CraftFrame_Update
            end
            if redraw then
                local ok, err = pcall(redraw)
                if not ok then ReportError(err) end
            end
        end

        this = saved.this
        event = saved.event
        for k = 1, 9 do _G[ARGS[k]] = saved[k] end

        -- Drop the per-frame wrappers; frames fall back to their normal methods.
        for _, rec in ipairs(R.list) do
            rec.frame.RegisterEvent = nil
            rec.frame.UnregisterEvent = nil
            rec.frame.UnregisterAllEvents = nil
        end
        AtlasCFM._Replay = nil
    end

    FlushQueuedQuests()

    -- Start building the search/tooltip index right away instead of waiting for
    -- the window's OnShow or the 6 s post-login warm-up.
    local DataIndex = AtlasCFM.DataIndex
    if DataIndex and DataIndex.CheckAndBuildIndex then
        local ok, err = pcall(DataIndex.CheckAndBuildIndex)
        if not ok then ReportError(err) end
    end

    -- AtlasUI.lua points /atlascfm at the core handler; keep the stub's handler
    -- in front so "preload"/"status" keep working (everything else forwards).
    SlashCmdList["AtlasCFM"] = AtlasCFM.StubSlashCommand
end

---
--- Loads Atlas-CFM_Core if needed.
--- @param triggerEvent string|nil event to replay to the core after startup events
--- @return boolean true when the core is loaded
---
function AtlasCFM.LoadCore(triggerEvent)
    if coreLoaded then return true end
    if coreLoading then return false end

    coreLoading = true
    pendingTrigger = triggerEvent
    local loaded, reason = LoadAddOn(CORE)
    coreLoading = false

    if not loaded then
        pendingTrigger = nil
        local why = reason and (_G["ADDON_" .. reason] or reason) or "unknown"
        Print("|cffff3333could not load " .. CORE .. " (" .. why .. ").|r Check that the "
            .. CORE .. " folder exists and is enabled in the AddOns list.")
        return false
    end

    FinishCoreLoad()
    return true
end

function AtlasCFM.IsCoreLoaded()
    return coreLoaded
end

-----------------------------------------------------------------------------
-- Entry points (replaced by the real functions when the core loads)
-----------------------------------------------------------------------------

-- Each stub loads the core, then calls whatever the core installed under the
-- same name. If the name still points at the stub the call is dropped, which
-- prevents a loop if loading failed.
local function Forwarder(name)
    local stub
    stub = function(a1, a2, a3)
        if not AtlasCFM.LoadCore() then return end
        local real = AtlasCFM[name]
        if real and real ~= stub then
            return real(a1, a2, a3)
        end
    end
    return stub
end

AtlasCFM.ToggleAtlas = Forwarder("ToggleAtlas")
AtlasCFM.OptionsOnClick = Forwarder("OptionsOnClick")
AtlasCFM.SlashCommand = Forwarder("SlashCommand")

function AtlasCFM.StubSlashCommand(msg)
    local cmd = string.lower(msg or "")
    if cmd == "preload" then
        AtlasCFMStubOptions.preload = not AtlasCFMStubOptions.preload
        if AtlasCFMStubOptions.preload then
            Print("preload ON: the full addon loads at login (item source tooltips are enabled at login).")
        else
            Print("preload OFF: the full addon loads the first time you use it (fast /reload).")
        end
        return
    elseif cmd == "status" then
        Print("core " .. (coreLoaded and "|cff00ff00loaded|r" or "|cffffff00not loaded yet|r")
            .. ", preload " .. (AtlasCFMStubOptions.preload and "on" or "off") .. ".")
        return
    end
    AtlasCFM.SlashCommand(msg)
end

SLASH_AtlasCFM1 = "/AtlasCFM"
SlashCmdList["AtlasCFM"] = AtlasCFM.StubSlashCommand

-----------------------------------------------------------------------------
-- Events
-----------------------------------------------------------------------------

local questPattern = ERR_QUEST_COMPLETE_S and string.gsub(ERR_QUEST_COMPLETE_S, "%%s", "(.+)")

local frame = CreateFrame("Frame", "AtlasCFMStubFrame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("TRADE_SKILL_SHOW")
frame:RegisterEvent("CRAFT_SHOW")
frame:RegisterEvent("CHAT_MSG_SYSTEM")
frame:RegisterEvent("CHAT_MSG_ADDON")

frame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" then
        if arg1 == AtlasCFM.Name then
            -- Same saved-variable setup the full addon did at startup
            -- (Atlas_Init and AtlasCFMLoot_InitializeCharacterDatabase).
            AtlasCFM.EnsureSavedOptions()
            if not AtlasCFMCharDB["WishList"] then AtlasCFMCharDB["WishList"] = {} end
            if not AtlasCFMCharDB["QuickLooks"] then AtlasCFMCharDB["QuickLooks"] = {} end
            if not AtlasCFMCharDB["SearchResult"] then AtlasCFMCharDB["SearchResult"] = {} end
            if not AtlasCFMCharDB["WishListSortMode"] then AtlasCFMCharDB["WishListSortMode"] = "Default" end

            if type(AtlasCFMStubOptions) ~= "table" then AtlasCFMStubOptions = {} end
            if type(AtlasCFMStubCharDB) ~= "table" then AtlasCFMStubCharDB = {} end
            if type(AtlasCFMStubCharDB.questNames) ~= "table" then AtlasCFMStubCharDB.questNames = {} end
            if type(AtlasCFMStubCharDB.questIDs) ~= "table" then AtlasCFMStubCharDB.questIDs = {} end
        elseif arg1 == CORE then
            FinishCoreLoad()
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        this:UnregisterEvent("PLAYER_ENTERING_WORLD")
        if AtlasCFMStubOptions and AtlasCFMStubOptions.preload then
            -- One frame later, so the core does not also receive this live
            -- PLAYER_ENTERING_WORLD on top of the replayed one.
            this:SetScript("OnUpdate", function()
                this:SetScript("OnUpdate", nil)
                AtlasCFM.LoadCore()
            end)
        end

    elseif event == "TRADE_SKILL_SHOW" or event == "CRAFT_SHOW" then
        -- Profession window extras (search, filters, Atlas button) need the core.
        if not coreLoaded then
            AtlasCFM.LoadCore(event)
        end

    elseif not coreLoaded and type(AtlasCFMStubCharDB) == "table" then
        -- Queue quest completions until the quest database is loaded.
        if event == "CHAT_MSG_SYSTEM" then
            if questPattern and arg1 then
                local _, _, questName = string.find(arg1, questPattern)
                if questName then AtlasCFMStubCharDB.questNames[questName] = true end
            end
        elseif event == "CHAT_MSG_ADDON" and arg1 == "TWQUEST" and arg2 then
            for id in string.gfind(arg2, "%S+") do
                local questID = tonumber(id)
                if questID then AtlasCFMStubCharDB.questIDs[questID] = true end
            end
        end
    end
end)
