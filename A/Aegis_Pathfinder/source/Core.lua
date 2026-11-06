local L = AEGISPATHFINDER_LOCALE
AEGISPATHFINDER_LOCALE = nil

AegisPathfinder = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceDB-2.0", "AceDebug-2.0", "AceEvent-2.0", "AceHook-2.1")

--[[ AceConsole's Print runs its first argument through string.format whenever
	it holds a "%" -- so a line such as "Gloves: a +12% upgrade" stopped with
	"invalid option in `format'". Every line here is worded before it is
	printed, so it goes out as it is. ]]
local AcePrint = AegisPathfinder.Print
function AegisPathfinder:Print(msg)
	return AcePrint(self, "%s", msg)
end

AegisPathfinder.guides = {}
AegisPathfinder.guidelist = {}
AegisPathfinder.nextzones = {}
AegisPathfinder.Locale = L
AegisPathfinder.myfaction = UnitFactionGroup("player")

-- Race-based route definitions
AegisPathfinder.routes = {}
AegisPathfinder.manuallyUnchecked = {}

-- Route pack registry (named collections of per-race routes)
AegisPathfinder.routepacks = {}
-- Route packs that were offered once and are not now, and the pack their
-- characters move to.
AegisPathfinder.RETIRED_PACKS = { ["Kamisayo Speedrun"] = "RestedXP" }

-- Turtle WoW custom race support
-- Keyed by the locale-independent ChrRaces.dbc token from UnitRaceBase
-- (ClassicAPI); Turtle's custom races arrive as their DBC filenames, so
-- High Elf is BloodElf (raceID 10)
--
-- Only races with a side: ChrRaces also lists creature races, and ClassicAPI's
-- GetFactionInfo is nil for a race with no faction group. Indexing that nil
-- here stopped Core.lua loading at this line, so nothing after it existed --
-- no OnInitialize, so no saved settings ("ItemScore.lua:72: attempt to index
-- field 'db'"), no GetObjectiveInfo ("QuestTracker.lua:177"). Without
-- ClassicAPI at all the table stays empty and OnEnable says what is missing.
AegisPathfinder.turtleRaces = {}
do
    local info = C_CreatureInfo
    local i = 1
    local raceInfo = info and info.GetRaceInfo and info.GetRaceInfo(i)
    while raceInfo ~= nil do
        local faction = info.GetFactionInfo and info.GetFactionInfo(i)
        if faction and faction.groupTag and raceInfo.clientFileString then
            AegisPathfinder.turtleRaces[raceInfo.clientFileString] = {
                route = string.gsub(raceInfo.raceName or "", "%s+", ""),
                faction = faction.groupTag,
            }
        end
        i = i + 1
        raceInfo = info.GetRaceInfo(i)
    end
end

-- Get the normalized route name for a race token (defaults to the player)
function AegisPathfinder:GetRouteForRace(race)
    race = race or (UnitRaceBase("player"))
    local raceInfo = self.turtleRaces[race]
    if raceInfo then
        return raceInfo.route
    end
    -- Legacy inputs ("Night Elf", "HighElf", "Undead") match a route name
    -- once the spaces are gone
    return race and (string.gsub(race, "%s", "")) or nil
end

--[[ Action glyphs.

    The generated silhouettes from Theme.lua, not Blizzard's icon art. Stock
    quest-log icons carry their own border, palette and 8px bevel, which read as
    a foreign object on the concept's flat panels -- and they were the reason
    every list in the addon still looked like a 2006 UI under a new skin.

    An unknown code falls back to the note glyph rather than a question mark:
    a guide line the parser did not recognise should look like a line to read,
    not like a missing asset.
]]
-- Header plus subhead on the concept's window chrome, which every dialog below
-- now wears; their bodies start beneath it.
local DIALOG_CHROME = 30 + 18

AegisPathfinder.icons = setmetatable({}, {
    __index = function(_, action)
        -- Looked up per call: Core.lua loads before Theme.lua.
        local theme = AegisPathfinder.Theme
        return theme.actionIconByName[action] or theme.actionIcon.N
    end,
})

local defaults = {
    debug = false,
    hearth = UNKNOWN,
    turnins = {},
    stepkeys = {},                -- guide -> 2 once its ticks use Parser's place keys (MigrateStepKeys)
    cachedturnins = {},
    trackquests = true,
    completion = {},
    currentguide = "No Guide",
    currentroute = nil,
    routeselected = false,
    mapquestgivers = true,
    waypointprovider = "auto", -- see Navigation.lua providerorder
    -- Focus mode is the concept's default: the step you are on, and nothing
    -- else. Overview is the whole list, behind the header's expand chip.
    overviewmode = false,
    shownavcallout = true,
    showminimapbutton = true,
    showactiveitems = true,   -- see ActiveFrames.lua
    showactivetargets = true,
    questicons = true,        -- mark quest NPCs and mobs on mouseover/target
    showmacros = true,        -- the Macros window, and the AegisTarget/AegisItem macros
    skipfollowups = true,
    autoquest = true,
    -- The Automation page (QuestTracker.lua, Automation.lua)
    allquests = false,            -- accept and turn in every quest, not only the guide's
    autogossip = true,            -- pick the quest from an NPC's list
    autofly = false,              -- take the step's flight on the flight master's map
    autobuy = true,               -- buy what a buy step names, at its vendor
    sellbutton = true,            -- the "Sell greys" button on the vendor window
    autosell = false,             -- sell greys as a vendor's window opens
    autorepair = "off",           -- "off", or "own": repair with your own money
    -- The Action Buttons page (ActiveFrames.lua)
    itemsgrow = "right",          -- which way Active Items grows: right, left, up or down
    targetsgrow = "right",        -- and Active Targets
    buttonscale = 1,              -- the three small windows' size, over the window scale
    btnitems = true,              -- buttons: quest items
    btntalk = true,               -- talk to (and interact with) NPCs
    btnkill = true,               -- kill (and loot) enemies
    btndelete = true,             -- delete the cheapest item, when the bags are full
    raidmark = true,              -- the target buttons mark whom they target
    -- The Step Display page (ObjectivesFrame.lua, Parser.lua, PartySync.lua)
    focussteps = 1,               -- steps focus mode shows: the one you are on, and up to four after it
    -- The Dungeons page (Parser.lua: GetStepNote)
    dungeonrole = "all",          -- whose lines a dungeon guide's boss steps show: all, tank, heal or dps
    skiphearth = false,           -- leave out steps that set your hearthstone
    skipflightpaths = false,      -- and those that discover a flight path
    partysync = true,             -- the party icon, and invitations to share a guide
    petskills = {},
    completedquests = {},
    completedquestsbyid = {}, -- {[questId] = true} from server
    -- Branching state
    -- Open guides, as the tab bar shows them. Tab 1 is the main route -- the
    -- one auto-advance follows. The rest are guides opened beside it. Empty
    -- when the player has closed them all.
    tabs = nil,          -- built on first use; see EnsureTabs
    activetab = 1,
    -- Derived from the tabs above and kept in step with them by SyncBranchState.
    -- Plenty of code reads these, and a branch is just "the active tab is not
    -- the first one", so they stay rather than being torn out.
    isbranching = false,
    branchsavedguide = nil,
    branchsavedstep = nil,
    setupdone = false,            -- has this character been through the first-time setup?
    offercustomzones = true,      -- offer custom zones when a guide finishes (NextGuideFrame.lua)
    offerdungeons = false,        -- and the ticked dungeons' guides, at your level (NextGuideFrame.lua)
    middungeons = true,           -- offer a ticked dungeon's guide at the middle of its levels, once each (NextGuideFrame.lua)
    classquests = true,           -- offer a class quest's guide at its level, once each (NextGuideFrame.lua)
    craftsellback = true,         -- crafting routes say what a merchant pays for leftovers (CraftPlanner.lua)
    -- The guide browser (GuideListFrame.lua, GuideBrowser.lua)
    browsertab = "home",          -- where it was left: "home", "current", "recent" or a category's key
    browsercolour = true,         -- colour guides by how they suit your level
    browserticks = true,          -- tick the guides you have finished
    browserhidedone = false,      -- hide finished guides, and those you have outlevelled
    browserstars = false,         -- star the guides the Home tab suggests
    browserpanels = {},           -- Home panels hidden: { [key] = true }
    favorites = {},               -- starred guides: { [guide] = true }
    recentguides = {},            -- the guides opened lately, the last first
    leveltime = {},               -- time played at each level, in seconds: { [level] = n }
    gold = {},                    -- gold earned: today and this week, and the day and week they are for
    sharenowarn = false,          -- skip the "share this guide with your party?" question (PartySync.lua)
    routepack = nil,              -- Active route pack name (e.g., "VanillaGuide", "RestedXP")
    PlayStyle = "SOLO",           -- Default playstyle ("SOLO" or "GROUP")
    UseAH = false,                -- Default Auction House setting (true/false)
    SelfFound = false,            -- Solo Self-Found: no trading, no Auction House (overrides UseAH)
    -- Starting zone selection (branch-and-rejoin)
    startingzoneselected = false, -- has player picked a starting zone?
    selectedstartingzone = nil,   -- which starting zone was selected (e.g., "Human", "Dwarf")
    startingzonecomplete = false, -- has player finished their starting zone?
    rejoinlevel = 12,             -- level at which all paths rejoin (default 12)
    Dungeons = {
        ["RFC"] = true,
        ["WC"] = true,
        ["DM"] = true,
        ["SFK"] = true,
        ["BFD"] = true,
        ["STOCKADES"] = true,
        ["GNOMER"] = true,
        ["RFK"] = true,
        ["SM"] = true,
        ["RFD"] = true,
        ["ULDA"] = true,
        ["ZF"] = true,
        ["MARA"] = true,
        ["ST"] = true,
        ["BRD"] = true,
        -- Turtle WoW's own: no route steps, but the Gear finder and the
        -- dungeon guides along the way go by them.
        ["FH"] = true, ["WHC"] = true, ["DMR"] = true, ["SWR"] = true,
        ["CG"] = true, ["GC"] = true, ["HQ"] = true,
    },
}

-- Named rather than left to AceConsole's random key, so the handler it
-- installs in SlashCmdList can be found and wrapped afterwards.
local SLASH_HANDLER = "AEGISPATHFINDER"

local options = {
    type = "group",
    handler = AegisPathfinder,
    args = {
        Materials = {
            name = "Materials",
            desc = "The shopping list: reagents for this craft and the rest of the guide",
            type = "execute",
            func = function() AegisPathfinder:ToggleMaterialsPanel() end,
        },
        Target = {
            name = "Target",
            desc = "Target and mark the nearest of the step's targets, then the next one out each press -- put /apg target in a macro",
            type = "execute",
            func = function() AegisPathfinder:TargetNextActive() end,
        },
        UseItem = {
            name = "Use Item",
            desc = "Use the first active item",
            type = "execute",
            func = function() AegisPathfinder:UseActiveItem(1) end,
        },
        SSF = {
            name = "Solo Self-Found",
            desc = "Solo Self-Found mode: hide every step that trades with other players or uses the Auction House",
            type = "toggle",
            get = function() return AegisPathfinder.db.char.SelfFound end,
            set = function(on) AegisPathfinder:SetSelfFound(on) end,
        },
        Gear = {
            name = "Gear",
            desc = "The stat weights behind the item score on tooltips (options, Item Score)",
            type = "execute",
            func = function() AegisPathfinder:ToggleItemScorePage() end,
        },
        Finder = {
            name = "Finder",
            desc = "The Gear Finder tab on the character panel: upgrades in the dungeons you run",
            type = "execute",
            func = function() AegisPathfinder:ToggleGearFinder() end,
        },
        Talents = {
            name = "Talents",
            desc = "Save your class's talent trees, for checking the Talent Advisor's builds: once on a character of each class",
            type = "execute",
            func = function() AegisPathfinder.Extras:SaveTalentTrees() end,
        },
        Share = {
            name = "Share",
            desc = "Share the guide you are on with your party, or stop sharing (beta)",
            type = "execute",
            func = function() AegisPathfinder:ToggleSharing() end,
        },
        Craft = {
            name = "Craft",
            desc = "The crafting route window: the cheapest way to level a profession at today's prices",
            type = "execute",
            func = function() AegisPathfinder:ToggleCraftRoutePanel() end,
        },
        Exchange = {
            name = "Exchange",
            desc = "Send the guide's remaining crafts to Aegis: Exchange's Crafting tab, or take them back out",
            type = "execute",
            func = function() AegisPathfinder:ToggleExchange() end,
        },
        ResetPanels = {
            name = "Reset Panels",
            desc = "Put every window back where it opens by default, at its default size",
            type = "execute",
            func = function() AegisPathfinder:ResetWindowLayout() end,
        },
        DiagNav = {
            name = "Navigation Diag",
            desc = "Check navigation addon status",
            type = "execute",
            func = function()
                AegisPathfinder:Print("--- Navigation Status ---")
                AegisPathfinder:Print("Setting: " .. (AegisPathfinder.db.char.waypointprovider or "auto"))
                AegisPathfinder:Print("Active: " .. AegisPathfinder:GetWaypointProviderLabel())
                AegisPathfinder:Print("Arrows: " .. AegisPathfinder:DescribeArrows())
                local wp = AegisPathfinder.waypointtarget
                AegisPathfinder:Print(wp and string.format("Waypoint: continent %d zone %d at %.1f, %.1f",
                    wp.continent, wp.zoneindex, wp.x, wp.y) or "Waypoint: none")
                local bearing, yards, why = AegisPathfinder:GetWaypointBearing()
                if bearing then
                    AegisPathfinder:Print(string.format("Pathfinder's arrow: pointing, %s",
                        yards and string.format("%d yd", math.floor(yards + 0.5)) or "no distance"))
                else
                    AegisPathfinder:Print("Pathfinder's arrow: hidden -- " .. tostring(why))
                end
                AegisPathfinder:Print("Astrolabe: " .. ((Astrolabe and Astrolabe.ComputeDistance) and "loaded" or "not loaded"))

                local available = AegisPathfinder:GetWaypointProviders()
                if table.getn(available) == 0 then
                    AegisPathfinder:Print("No waypoint addon found - install TomTom or pfQuest")
                    return
                end
                for _, provider in ipairs(available) do
                    AegisPathfinder:Print("  " .. provider.label .. " (" .. provider.name .. ")")
                end
            end,
        },
        WaypointProvider = {
            name = "Waypoint Provider",
            desc = "Cycle the addon used for waypoints",
            type = "execute",
            func = function()
                AegisPathfinder:CycleWaypointProvider()
                AegisPathfinder:Print("Waypoints: " .. AegisPathfinder:GetWaypointProviderLabel())
            end,
        },
        TestWaypoint = {
            name = "Test Waypoint",
            desc = "Create a test waypoint at the centre of the current zone",
            type = "execute",
            func = function()
                if not AegisPathfinder:GetWaypointProvider() then
                    AegisPathfinder:Print("No waypoint addon found")
                    return
                end

                -- Use SetMapToCurrentZone to get valid data (same as the fix)
                SetMapToCurrentZone()
                local c = GetCurrentMapContinent()
                local z = GetCurrentMapZone()
                AegisPathfinder:Print(string.format("Zone data: c=%s z=%s", tostring(c), tostring(z)))

                if not c or c == 0 or not z or z == 0 then
                    AegisPathfinder:Print("Could not get zone data")
                    return
                end

                local zone = AegisPathfinder.select(z, GetMapZones(c))
                AegisPathfinder:SetWaypoint(50, 50, zone, "Test Waypoint")
                AegisPathfinder:Print("Waypoint sent to " .. AegisPathfinder:GetWaypointProviderLabel())
            end,
        },
        TrackQuests = {
            name = "Auto Track",
            desc = L["Automatically track quests"],
            type = "toggle",
            get = function() return AegisPathfinder.db.char.trackquests end,
            set = function(newValue)
                AegisPathfinder.db.char.trackquests = newValue
                if AegisPathfinder.optionsframe then
                    AegisPathfinder:RefreshConfigPanel()
                end
            end,
            order = 1,
        },
        SkipFollowUps = {
            name = "Auto Skip Followups",
            desc = L["Automatically skip suggested follow-ups"],
            type = "toggle",
            get = function() return AegisPathfinder.db.char.skipfollowups end,
            set = function(newValue)
                AegisPathfinder.db.char.skipfollowups = newValue
                if AegisPathfinder.optionsframe then
                    AegisPathfinder:RefreshConfigPanel()
                end
            end,
            order = 2,
        },
        AutoQuest = {
            name = "Auto Accept/Turnin",
            desc = L["Automatically accept and turn in guide quests (hold SHIFT to suspend)"],
            type = "toggle",
            get = function() return AegisPathfinder.db.char.autoquest end,
            set = function(newValue)
                AegisPathfinder.db.char.autoquest = newValue
            end,
            order = 2.5,
        },
        NavCallout = {
            name = "Navigation Arrow",
            desc = "Show/Hide the arrow pointing at the current objective",
            type = "toggle",
            get = function() return AegisPathfinder.db.char.shownavcallout end,
            set = function() AegisPathfinder:ToggleNavCallout() end,
            order = 2.95,
        },
        MinimapButton = {
            name = "Minimap Button",
            desc = "Show/Hide the button on the minimap",
            type = "toggle",
            get = function() return AegisPathfinder.db.char.showminimapbutton end,
            set = function() AegisPathfinder:ToggleMinimapButton() end,
            order = 2.96,
        },
        Objectives = {
            name = "Objectives",
            desc = "Show/Hide the objectives panel",
            type = "execute",
            func = function() AegisPathfinder:ToggleObjectivePanel() end,
            order = 2.9,
        },
        SelectRoute = {
            name = "Select Route",
            desc = "Choose a different leveling route",
            type = "execute",
            func = function() AegisPathfinder:ShowRouteSelector() end,
            order = 4,
        },
        ShowErrorLog = {
            name = "Error Log",
            desc = "Show captured Lua errors",
            type = "execute",
            func = function() AegisPathfinder:ShowErrorLog() end,
            order = 5,
        },
        NextStep = {
            name = "Next",
            desc = "Skip to next objective",
            type = "execute",
            func = function() AegisPathfinder:SkipToNextObjective() end,
            order = 10,
        },
        PrevStep = {
            name = "Previous",
            desc = "Go back to previous objective",
            type = "execute",
            func = function() AegisPathfinder:GoToPreviousObjective() end,
            order = 11,
        },
        GoToStep = {
            name = "Go To",
            desc = "Jump to step number",
            type = "text",
            usage = "<number>",
            get = false,
            set = function(v) AegisPathfinder:GoToObjective(v) end,
            order = 12,
        },
        Refresh = {
            name = "Refresh",
            desc = "Rescan quest log and update guide progress",
            type = "execute",
            func = function() AegisPathfinder:QueryServerCompletedQuests() end,
            order = 13,
        },
        Branch = {
            name = "Branch",
            desc = "Branch to a different zone guide (saves current progress)",
            type = "execute",
            func = function() AegisPathfinder:ShowGuideList(true) end,
            order = 14,
        },
        ReturnMain = {
            name = "Return to Main",
            desc = "Return to main route from branch",
            type = "execute",
            func = function() AegisPathfinder:ReturnFromBranch() end,
            order = 15,
        },
        Setup = {
            name = "Setup",
            desc = "Run the first-time setup again: your guide, its features and your dungeons",
            type = "execute",
            func = function() AegisPathfinder:ShowSetup() end,
        },
        CustomZones = {
            name = "Custom Zones",
            desc = "When a guide finishes, offer the custom zones that fit your level before moving on",
            type = "toggle",
            get = function() return AegisPathfinder.db.char.offercustomzones ~= false end,
            set = function(v) AegisPathfinder.db.char.offercustomzones = v end,
            order = 16,
        },
        DebugRoute = {
            name = "Debug Route",
            desc = "Show debug info about route and guide selection",
            type = "execute",
            func = function()
                local routeName = AegisPathfinder:GetRouteForRace()
                local route = AegisPathfinder.routes[routeName]
                local level = UnitLevel("player")

                AegisPathfinder:Print("--- Route Debug ---")
                AegisPathfinder:Print("Race token: " .. tostring((UnitRaceBase("player"))))
                AegisPathfinder:Print("Route name: " .. tostring(routeName))
                AegisPathfinder:Print("Route exists: " .. tostring(route ~= nil))
                AegisPathfinder:Print("Player level: " .. tostring(level))
                AegisPathfinder:Print("Current guide: " .. tostring(AegisPathfinder.db.char.currentguide))

                -- Check if specific guides exist
                AegisPathfinder:Print("--- Guide Existence ---")
                AegisPathfinder:Print("'Thalassian Highlands (1-10)': " ..
                    tostring(AegisPathfinder.guides["Thalassian Highlands (1-10)"] ~= nil))
                AegisPathfinder:Print("'Teldrassil (1-12)': " .. tostring(AegisPathfinder.guides["Teldrassil (1-12)"] ~= nil))

                -- Show first few guides in guidelist
                AegisPathfinder:Print("--- First 5 guides in guidelist ---")
                for i = 1, math.min(5, table.getn(AegisPathfinder.guidelist)) do
                    AegisPathfinder:Print(i .. ": " .. tostring(AegisPathfinder.guidelist[i]))
                end

                -- Show what GetNextRouteGuideForLevel would return
                if route then
                    local nextGuide = AegisPathfinder:GetNextRouteGuideForLevel(route, level)
                    AegisPathfinder:Print("GetNextRouteGuideForLevel returns: " .. tostring(nextGuide))
                end
            end,
            order = 17,
        },
        DebugTrain = {
            name = "Debug Train",
            desc = "Debug training detection",
            type = "execute",
            func = function()
                AegisPathfinder:Print("--- Skill Lines ---")
                local numSkills = GetNumSkillLines()
                AegisPathfinder:Print("GetNumSkillLines: " .. tostring(numSkills))
                for i = 1, numSkills do
                    local name, isHeader, isExpanded, rank, maxRank = GetSkillLineInfo(i)
                    AegisPathfinder:Print(string.format("%d: %s (Header=%s, Rank=%s)", i, tostring(name), tostring(isHeader),
                        tostring(rank)))
                end

                AegisPathfinder:Print("--- Spellbook ---")
                local i = 1
                while true do
                    local name, rank = GetSpellName(i, "spell")
                    if not name then break end
                    if string.find(string.lower(name), "blacksmith") or string.find(string.lower(name), "mining") then
                        AegisPathfinder:Print(string.format("Spell %d: %s (%s)", i, tostring(name), tostring(rank)))
                    end
                    i = i + 1
                end

                AegisPathfinder:Print("--- Training Check ---")
                AegisPathfinder:Print("IsProfessionLearned('Blacksmithing'): " ..
                    tostring(AegisPathfinder:IsProfessionLearned("Blacksmithing")))
                AegisPathfinder:Print("IsSpellLearned('Blacksmithing'): " ..
                    tostring(AegisPathfinder:IsSpellLearned("Blacksmithing")))
                AegisPathfinder:Print("IsTrainingCompleted('Train [Blacksmithing]'): " ..
                    tostring(AegisPathfinder:IsTrainingCompleted("Train [Blacksmithing]")))
            end,
            order = 17,
        },
        ListGuides = {
            name = "List Guides",
            desc = "List all loaded guides",
            type = "execute",
            func = function()
                AegisPathfinder:Print("--- All Loaded Guides ---")
                for i, name in ipairs(AegisPathfinder.guidelist) do
                    AegisPathfinder:Print(i .. ": " .. name)
                end
                AegisPathfinder:Print("Total: " .. table.getn(AegisPathfinder.guidelist) .. " guides")
            end,
            order = 18,
        },
        StartingZone = {
            name = "Starting Zone",
            desc = "Choose a different starting zone (branch-and-rejoin)",
            type = "execute",
            func = function() AegisPathfinder:ShowStartingZoneSelector() end,
            order = 19,
        },
        ResetStartingZone = {
            name = "Reset Starting Zone",
            desc = "Reset starting zone selection and start fresh",
            type = "execute",
            func = function()
                AegisPathfinder.db.char.startingzoneselected = false
                AegisPathfinder.db.char.selectedstartingzone = nil
                AegisPathfinder.db.char.startingzonecomplete = false
                AegisPathfinder:ShowStartingZoneSelector()
            end,
            order = 20,
        },
        RoutePack = {
            name = "Route Packs",
            desc = "List available route packs",
            type = "execute",
            func = function()
                local packs = AegisPathfinder:GetAvailableRoutePacks()
                local current = AegisPathfinder.db.char.routepack
                AegisPathfinder:Print("--- Available Route Packs ---")
                for _, pack in ipairs(packs) do
                    local marker = (current == pack.name) and " |cff00ff00(active)|r" or ""
                    AegisPathfinder:Print("  " .. pack.displayName .. marker .. " - " .. pack.description)
                end
                AegisPathfinder:Print("Use |cff00ccff/apg SetRoutePack <name>|r to switch.")
            end,
            order = 21,
        },
        SetRoutePack = {
            name = "Set Route Pack",
            desc = "Switch to a route pack (e.g., /apg SetRoutePack RestedXP)",
            type = "text",
            usage = "<pack name>",
            get = false,
            set = function(v)
                AegisPathfinder:SelectRoutePack(v)
            end,
            order = 22,
        },
    },
}

AegisPathfinder.title = "Aegis: Pathfinder"
-- The version, as the Aegis suite numbers them: MAJOR.MINOR.PATCH, 0.x until
-- the public release. It is written in five places that must agree -- here,
-- the .toc, the README's H1 and its "Something broken?" line, and the newest
-- CHANGELOG.md entry -- and Tools/verify.py checks they do.
AegisPathfinder.version = "0.26.0"

-- Adopt saved data written under the pre-rebrand SavedVariable name. Both
-- globals are declared in the .toc so the old table is still loaded and can be
-- handed over; this runs before RegisterDB so AceDB sees the migrated table.
-- Only fires when there is nothing to lose: an existing, non-empty
-- AegisPathfinderDB always wins.
local function MigrateLegacySavedVariables()
    if type(TurtleGuideDB) ~= "table" then return false end
    if type(AegisPathfinderDB) == "table" and next(AegisPathfinderDB) then return false end
    AegisPathfinderDB = TurtleGuideDB
    return true
end

--[[ Guides renamed between versions, old name to new.

    A guide's name is the key its progress is saved under -- the tabs, how far
    through it you are, the quests it has seen turned in, the browser's stars
    and recent list -- so a renamed guide would otherwise open as one you had
    never started. MigrateGuideNames carries each of those over.
]]
AegisPathfinder.RENAMED_GUIDES = {
    -- 0.26.0: its quests are level 45 to 48 and its boat needs 40, so as
    -- 40-50 "Where next?" offered it at 39.
    ["Icepoint Rock (40-50)"] = "Icepoint Rock (44-47)",
}

function AegisPathfinder:MigrateGuideNames()
    local db = self.db.char
    for old, new in pairs(self.RENAMED_GUIDES) do
        if db.currentguide == old then db.currentguide = new end
        if db.branchsavedguide == old then db.branchsavedguide = new end
        for _, tab in ipairs(db.tabs or {}) do
            if tab.guide == old then tab.guide = new end
        end
        for _, field in ipairs({ "completion", "turnins", "favorites" }) do
            local t = db[field]
            if t and t[old] ~= nil then
                if t[new] == nil then t[new] = t[old] end
                t[old] = nil
            end
        end
        if db.recentguides then
            local list, seen = {}, {}
            for _, name in ipairs(db.recentguides) do
                if name == old then name = new end
                if not seen[name] then
                    seen[name] = true
                    table.insert(list, name)
                end
            end
            db.recentguides = list
        end
    end
end

function AegisPathfinder:OnInitialize()
    local migratedLegacyDB = MigrateLegacySavedVariables()

    self:RegisterDB("AegisPathfinderDB")
    self:RegisterDefaults("char", defaults)
    self:MigrateGuideNames()
    -- The saved theme, before anything else paints: windows built as the
    -- files loaded are re-tinted to it (Theme.lua).
    self.Theme:ApplyTheme(self.db.profile.theme)
    self.Theme:SetWindowScale(self.db.profile.windowscale or 1)
    self.Theme:SetSwitchColours(self.db.profile.switchcolours)

    self.db.char.Dungeons = self.db.char.Dungeons or {}
    for k, v in pairs(defaults.Dungeons) do
        if self.db.char.Dungeons[k] == nil then
            self.db.char.Dungeons[k] = v
        end
    end
    if self.db.char.PlayStyle == nil then
        self.db.char.PlayStyle = defaults.PlayStyle
    end
    if self.db.char.UseAH == nil then
        self.db.char.UseAH = defaults.UseAH
    end
    -- /aegis belongs to another addon in the Aegis suite; registering it
    -- here would collide with it.
    self:RegisterChatCommand({ "/apg", "/pathfinder" }, options, SLASH_HANDLER)

    --[[ A bare /apg opens the objectives panel.

        AceConsole's own handler answers an empty argument with a list of
        subcommands, which is not what anyone typing /apg is looking for -- the
        panel is the addon's main surface. There is no hook for the empty case,
        so wrap the handler AceConsole just installed: subcommands still go to
        it, and the options panel is a right-click on the minimap button away.
    ]]
    local aceHandler = SlashCmdList[SLASH_HANDLER]
    SlashCmdList[SLASH_HANDLER] = function(msg)
        if not msg or self.trim(msg) == "" then
            return self:ToggleObjectivePanel()
        end
        return aceHandler(msg)
    end
    self:SetupErrorCapture()
    self.cachedturnins = self.db.char.cachedturnins
    -- Crafting routes loaded as guides in earlier sessions (CraftRouteFrame.lua),
    -- registered with the rest so the one you were on reopens.
    if self.RestoreCraftGuides then self:RestoreCraftGuides() end
    -- Not on a ClassicAPI too old to run on, which OnEnable stops at: the
    -- login would load the guides regardless, and before v1.3.11 ClassicAPI
    -- hadn't put back the coroutine library the login loads them with.
    if self.myfaction == nil and self:HasClassicAPI() then
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
    end
    self:PositionActiveFrames()
    -- The panel is the addon's only window and the concept has it open, so it
    -- opens with the client unless the player closed it last session.
    if self.db.char.panelopen ~= false then
        self.objectiveframe:Show()
    end
    self:CreateConfigPanel()

    if migratedLegacyDB then
        self:Print(L["Imported your saved progress from TurtleGuide."])
    end
    -- As every Aegis addon says it: the version to quote in a bug report.
    if DEFAULT_CHAT_FRAME and self.db.char.chatmessages ~= false then
        DEFAULT_CHAT_FRAME:AddMessage(self.title .. " v" .. self.version .. " loaded \226\128\148 /apg")
    end
end

-- Hard requirement: ClassicAPI DLL v1.5.9+ (version encodes X*10000 + Y*100 + Z;
-- untagged dev builds report 99999999). Quest tracking is built on its
-- C_QuestLog functions and QUEST_ACCEPTED / QUEST_TURNED_IN events.
function AegisPathfinder:HasClassicAPI()
    return CLASSIC_API_VERSION ~= nil and CLASSIC_API_VERSION >= 10509
end

function AegisPathfinder:OnEnable()
    if not self:HasClassicAPI() then
        -- Which one this client has, so a bug report says.
        local v, found = CLASSIC_API_VERSION, "none"
        if v then
            found = string.format("v%d.%d.%d", math.floor(v / 10000), math.floor(v / 100) - math.floor(v / 10000) * 100,
                v - math.floor(v / 100) * 100)
        end
        self:Print("|cffff3333Aegis: Pathfinder requires ClassicAPI v1.5.9 or newer (https://github.com/brues-code/ClassicAPI); this client has "
            .. found .. ". The addon will not load.|r")
        return
    end

    self:PatchAstrolabe()
    self:RegisterProfessionEvents()
    self.ItemScore:Initialize()
    self.GearAdvisor:Initialize()
    self.GearFinder:Initialize()
    self:UpdateMinimapButton()

    if self.db.char.debug then
        self:SetDebugging(true)
    else
        self:SetDebugging(false)
    end

    if self.myfaction == nil then
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
    else
        self:InitializeRoute()
    end
end

function AegisPathfinder:InitializeRoute()
    self:SyncWithPfQuestHistory()
    -- Migration: set default route pack for existing characters
    if not self.db.char.routepack and self.db.char.routeselected then
        self.db.char.routepack = "VanillaGuide"
    end
    self:MoveOffRetiredPack()

    -- Load active route pack's routes into self.routes
    local activePack = self:GetCurrentRoutePack()
    if activePack then
        for race, route in pairs(activePack.routes) do
            self.routes[race] = route
        end
    end

    -- If no route selected yet, use the new starting zone selection system
    if not self.db.char.routeselected then
        -- Try the new branch-and-rejoin starting zone system first
        if self:InitializeRouteWithStartingZone() then
            -- Starting zone was handled, continue with initialization
        else
            -- Fallback: Auto-detect race and suggest route
            local race = UnitRace("player") -- localized, for the message
            local routeName = self:GetRouteForRace()
            if routeName and self.routes[routeName] then
                self:ApplyRouteSelection(routeName)
                local message = L["You have been assigned the %s leveling route."]
                if not message then
                    message = "You have been assigned the %s leveling route."
                end
                self:Say(string.format(message, tostring(race)))
            else
                -- Fallback to default start guides (including Turtle WoW races)
                local startguides = {
                    Orc = "Durotar (1-12)",
                    Troll = "Durotar (1-12)",
                    Tauren = "Mulgore (1-12)",
                    Undead = "Tirisfal (1-12)",
                    Dwarf = "Dun Morogh (1-12)",
                    Gnome = "Dun Morogh (1-12)",
                    Human = "Elwynn Forest (1-12)",
                    NightElf = "Teldrassil (1-12)",
                    -- Turtle WoW custom races
                    HighElf = "Thalassian Highlands (1-10)", -- High Elf starting zone
                    Goblin = "Blackstone Island (1-10)",     -- Goblin starting zone
                }
                -- Use normalized route name for lookup
                self.db.char.currentguide = startguides[routeName] or startguides[race] or self.guidelist[1]
                self.db.char.routeselected = true
            end
        end
    else
        -- Route already selected - check if we need to transition from starting zone
        if self.db.char.startingzoneselected and not self.db.char.startingzonecomplete then
            self:CheckStartingZoneCompletion()
        end
    end

    --[[ Closing every tab is remembered across a reload. LoadGuide would
        otherwise take "No Guide" as a name it does not know and fall back to
        the first guide in the list, reopening something behind the
        player's back. ]]
    if self:HasNoGuide() and self.db.char.routeselected then
        self:UnloadGuide()
    else
        self.db.char.currentguide = self.db.char.currentguide or self.guidelist[1]
        self:LoadGuide(self.db.char.currentguide)
    end
    self.initializeDone = true
    for _, event in pairs(self.TrackEvents) do self:RegisterEvent(event) end
    -- Level ups: the |LV| steps and the starting zone (QuestTracker.lua)
    self:RegisterEvent("PLAYER_LEVEL_UP")
    self.TrackEvents = nil
    self:QueryServerCompletedQuests()
    self:UpdateStatusFrame()
    -- Force waypoint creation on initial load
    self:ForceWaypointUpdate()
    self.enableDone = true
    -- The first time the addon loads on this character: the three-step
    -- setup (SetupFrame.lua).
    if self.MaybeShowSetup then self:MaybeShowSetup() end
    -- A ticked dungeon whose middle level was reached while logged out, or
    -- before this was here, and a class quest likewise (NextGuideFrame.lua).
    if self.OfferAtLevel then self:OfferAtLevel() end
end

function AegisPathfinder:OnDisable()
    self:UnregisterAllEvents()
end

local REGISTER_BATCH = 25       -- guides registered per resume
local REGISTER_INTERVAL = 0.02  -- seconds between resumes
local INIT_SETTLE_DELAY = 0.5   -- seconds after registration before the guide loads

function AegisPathfinder:GetPlayerFaction()
    local faction = UnitFactionGroup("player")
    if faction and faction ~= "" then return faction end
    local info = C_CreatureInfo.GetFactionInfo(select(2, UnitRaceBase("player")))
    return info and info.groupTag
end

function AegisPathfinder:PLAYER_ENTERING_WORLD()
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    self:PatchAstrolabe()
    self.myfaction = self:GetPlayerFaction()

    local deferred = self.deferguides
    self.deferguides = {}

    local co = coroutine.create(function()
        local n = 0
        for _, t in ipairs(deferred) do
            self:RegisterGuide(t[1], t[2], t[3], t[4])
            n = n + 1
            if n >= REGISTER_BATCH then
                n = 0
                coroutine.yield()
            end
        end
    end)

    local function finishLogin()
        -- deferred Initialize (VARIABLES_LOADED); InitializeRoute also enables
        if not self.initializeDone then
            self:InitializeRoute()
        elseif not self.enableDone then
            -- deferred Enable (PLAYER_LOGIN)
            for _, event in pairs(self.TrackEvents) do self:RegisterEvent(event) end
            self.TrackEvents = nil
            self:UpdateStatusFrame()
        end
        self.initializeDone = true
    end

    local function pump()
        local ok, err = coroutine.resume(co)
        if not ok then
            self:Print("|cffff3333Aegis: Pathfinder load error: " .. tostring(err) .. "|r")
            return
        end
        if coroutine.status(co) == "dead" then
            C_Timer.After(INIT_SETTLE_DELAY, finishLogin)
        else
            C_Timer.After(REGISTER_INTERVAL, pump)
        end
    end
    pump()
end

function AegisPathfinder:RegisterGuide(name, nextzone, faction, sequencefunc)
    if self.myfaction == nil then
        self.deferguides = self.deferguides or {}
        table.insert(self.deferguides, { name, nextzone, faction, sequencefunc })
    else
        if faction ~= "Both" and faction ~= self.myfaction then return end

        local isNew = (self.guides[name] == nil)
        self.guides[name] = sequencefunc
        self.nextzones[name] = nextzone

        if isNew then
            table.insert(self.guidelist, name)
        end
    end
end

-- Register a race-based route
function AegisPathfinder:RegisterRoute(race, route)
    self.routes[race] = route
end

-- Register a named route pack (collection of per-race routes)
function AegisPathfinder:RegisterRoutePack(packName, packInfo)
    self.routepacks[packName] = {
        name = packName,
        displayName = packInfo.displayName or packName,
        description = packInfo.description or "",
        routes = packInfo.routes or {},
        factionRestriction = packInfo.factionRestriction,
        classRestriction = packInfo.classRestriction,
    }
end

-- Check if a guide belongs to a route pack (should be hidden from guide list)
-- Note: we allow RXP guides to be shown as requested by the user
-- Now we also allow Optimized guides to be shown as requested by the user
function AegisPathfinder:IsRoutePackGuide(guideName)
    return false
end

-- A pack that is no longer offered hands its characters on: Kamisayo
-- Speedrun is hidden until its guides are added (Routes/Routes.lua).
function AegisPathfinder:MoveOffRetiredPack()
    local db = self.db.char
    local to = db.routepack and self.RETIRED_PACKS[db.routepack]
    if to and not self.routepacks[db.routepack] then
        db.routepack = to
    end
end

-- Get the currently active route pack (or nil)
function AegisPathfinder:GetCurrentRoutePack()
    local packName = self.db.char.routepack
    if packName and self.routepacks[packName] then
        return self.routepacks[packName]
    end
    return nil
end

-- Get route packs available for the player's faction and class
function AegisPathfinder:GetAvailableRoutePacks()
    local faction = self.myfaction
    local _, playerClass = UnitClass("player")
    local available = {}

    for name, pack in pairs(self.routepacks) do
        local factionOk = not pack.factionRestriction or pack.factionRestriction == faction
        local classOk = not pack.classRestriction or pack.classRestriction == playerClass
        if factionOk and classOk then
            table.insert(available, pack)
        end
    end

    -- Sort by name for consistent display
    table.sort(available, function(a, b) return a.name < b.name end)
    return available
end

--[[ Solo Self-Found: a character that plays alone, never trades and never
    uses the Auction House. While it is on, steps tagged |AH| or |TRADE|, group
    quests and dungeon quests are left out whatever their switches say, and
    those switches are held off. What they were set to is kept, and comes back
    when it goes off. Per character, like the other filters. ]]
function AegisPathfinder:SetSelfFound(on)
    self.db.char.SelfFound = on and true or false
    self:Print(on and "Solo Self-Found on: group quests, dungeons, and steps that trade or use the Auction House are hidden."
        or "Solo Self-Found off.")
    if not self:HasNoGuide() then
        self:LoadGuide(self.db.char.currentguide)
        self:UpdateStatusFrame()
    end
    if self.optionsframe and self.RefreshConfigPanel then self:RefreshConfigPanel() end
end

-- Switch to a route pack, replacing self.routes with the pack's routes
function AegisPathfinder:SelectRoutePack(packName)
    local pack = self.routepacks[packName]
    if not pack then
        self:Print("|cffff0000Unknown route pack: " .. tostring(packName) .. "|r")
        return false
    end

    -- Check faction/class restrictions
    local faction = self.myfaction
    local _, playerClass = UnitClass("player")
    if pack.factionRestriction and pack.factionRestriction ~= faction then
        self:Print("|cffff0000Route pack '" .. packName .. "' is for " .. pack.factionRestriction .. " only.|r")
        return false
    end
    if pack.classRestriction and pack.classRestriction ~= playerClass then
        self:Print("|cffff0000Route pack '" .. packName .. "' requires " .. pack.classRestriction .. " class.|r")
        return false
    end

    -- Save selection
    self.db.char.routepack = packName

    -- Each pack's play style and Auction House use
    if packName == "RestedXP" or packName == "Kamisayo Speedrun" then
        self.db.char.PlayStyle = "GROUP"
        self.db.char.UseAH = true
        if self.guidelistframe and self.guidelistframe:IsVisible() then
            self:UpdateGuideListPanel()
        end
    elseif packName == "RXP Hardcore" then
        self.db.char.PlayStyle = "SOLO"
        self.db.char.UseAH = false
        if self.guidelistframe and self.guidelistframe:IsVisible() then
            self:UpdateGuideListPanel()
        end
    elseif packName == "VanillaGuide" then
        self.db.char.PlayStyle = "SOLO"
        self.db.char.UseAH = false
        if self.guidelistframe and self.guidelistframe:IsVisible() then
            self:UpdateGuideListPanel()
        end
    end

    -- Copy pack routes into self.routes (replacing existing)
    for race, route in pairs(pack.routes) do
        self.routes[race] = route
    end

    -- Apply route for current race
    local routeName = self:GetRouteForRace()
    self:ApplyRouteSelection(routeName)

    self:Print("|cff00ff00Route pack switched to: " .. pack.displayName .. "|r")
    return true
end

function AegisPathfinder:LoadNextGuide()
    local nextname = self:GetRouteSuccessor(self.db.char.currentguide)
        or self.nextzones[self.db.char.currentguide]
    -- End of the route: no next zone, or it points at an unregistered guide
    -- ("No Guide"). Stop instead of letting LoadGuide fall back to guidelist[1],
    -- which would wrap the auto-advance chain around to the start.
    if not nextname or not self.guides[nextname] then return false end

    -- Terminate a runaway chain. UpdateStatusFrame auto-advances (LoadNextGuide
    -- -> re-scan -> LoadNextGuide) whenever a guide has no incomplete step. On a
    -- server whose quests don't match the guide, every step auto-skips, so this
    -- would cascade through the whole route (re-parsing each guide) and exhaust
    -- the client's fixed Lua pool. Cap consecutive auto-advances; the counter is
    -- reset by UpdateStatusFrame once the chain lands on a guide with real work.
    self.autoadvancecount = (self.autoadvancecount or 0) + 1
    if self.autoadvancecount > 20 then
        self:Print("|cffff9900Stopped auto-advancing after 20 completed guides. Pick the guide you want from the guide list.|r")
        return false
    end

    self:LoadGuide(nextname, true)
    self:UpdateGuideListPanel()
    return true
end

--[[ The guide after `guide` on your route: the next leg of the active pack's
    route for your race (or the race whose route the options gave you), when
    `guide` is on it, else nil.

    A guide's own next link names one successor for everyone, but a pack's
    routes part ways -- RestedXP takes the Eastern Kingdoms races through
    Redridge at 19 and Night Elves through Darkshore -- so where you go next is
    the route's to say. Off the route (a custom zone, a guide picked from the
    list) the guide's next link still decides. ]]
function AegisPathfinder:GetRouteSuccessor(guide)
    if not guide or not self.routes then return nil end
    -- The route you follow: your race's, unless the options gave you another.
    local chosen = self.db and self.db.char and self.db.char.currentroute
    local route = (chosen and self.routes[chosen]) or self.routes[self:GetRouteForRace()]
    if not route then return nil end
    for i, leg in ipairs(route) do
        if leg.guide == guide then
            for j = i + 1, table.getn(route) do
                local nextguide = route[j].guide
                if nextguide ~= guide and self.guides[nextguide] then return nextguide end
            end
            return nil
        end
    end
    return nil
end

function AegisPathfinder:IsProfessionLearned(skillName)
    if not skillName then return false end
    for i = 1, GetNumSkillLines() do
        local name, isHeader = GetSkillLineInfo(i)
        if not isHeader and name and string.lower(name) == string.lower(skillName) then
            return true
        end
    end
    return false
end

function AegisPathfinder:IsSpellLearned(spellName)
    if not spellName then return false end
    local i = 1
    while true do
        local name, rank = GetSpellName(i, "spell")
        if not name then break end
        if string.lower(name) == string.lower(spellName) then
            return true
        end
        i = i + 1
    end

    local i = 1
    while true do
        local name, rank = GetSpellName(i, "pet")
        if not name then break end
        if string.lower(name) == string.lower(spellName) then
            return true
        end
        i = i + 1
    end

    return false
end

function AegisPathfinder:IsTrainingCompleted(stepName)
    if not stepName then return false end

    local _, _, name = string.find(stepName, "%[([^%]]+)%]")
    if not name then
        name = stepName
    end

    if name then
        name = string.gsub(name, "@.*@", "")
        name = string.gsub(name, "^Train%s+", "")
        name = string.gsub(name, "^Training%s+", "")
        name = string.gsub(name, "%s*%(Rank%s*%d+%)", "")
        name = string.gsub(name, "%s*%(.*%)", "")
        name = string.gsub(name, "%s*Part%s*%d+", "")
        name = AegisPathfinder.trim(name)

        if string.len(name) > 0 then
            if self:IsProfessionLearned(name) then
                return true
            end

            if self:IsSpellLearned(name) then
                return true
            end
        end
    end

    return false
end

function AegisPathfinder:GetQuestLogIndexByName(name)
    name = name or self.quests[self.current]
    if name then
        name = string.gsub(name, "@.*@", "")
        name = string.gsub(name, L.PART_GSUB, "")
    end
    for i = 1, GetNumQuestLogEntries() do
        local title, _, _, isHeader = GetQuestLogTitle(i)
        title = string.gsub(title, "%[[0-9%+%-]+]%s", "")
        if not isHeader and string.lower(title) == string.lower(name) then return i end
    end
end

function AegisPathfinder:GetQuestLogIndexByQid(qid)
    qid = tonumber(qid)
    if not qid then return end
    for i = 1, GetNumQuestLogEntries() do
        if C_QuestLog.GetQuestIDForLogIndex(i) == qid then return i end
    end
end

function AegisPathfinder:GetQuestDetails(name, oidx, qid)
    local i
    if qid then
        -- QID is authoritative: no name fallback, so a same-named quest from a
        -- different chain part can never satisfy this step
        i = self:GetQuestLogIndexByQid(qid)
    elseif name then
        i = self:GetQuestLogIndexByName(name)
    end
    if not i or i < 1 then return end
    local _, _, _, _, _, isComplete = GetQuestLogTitle(i)
    local complete = i and isComplete and isComplete == 1

    if oidx and not complete then
        -- Check only the specific objective index
        local numObjectives = GetNumQuestLeaderBoards(i)
        if numObjectives and oidx <= numObjectives then
            local text, objType, finished = GetQuestLogLeaderBoard(oidx, i)
            complete = not not finished
        else
            complete = false
        end
    elseif not complete and i then
        -- Fallback: check if all quest objectives are done via leaderboard
        local numObjectives = GetNumQuestLeaderBoards(i)
        if numObjectives and numObjectives > 0 then
            complete = true
            for j = 1, numObjectives do
                local text, objType, finished = GetQuestLogLeaderBoard(j, i)
                if not finished then
                    complete = false
                    break
                end
            end
        end
    end

    return i, complete
end

function AegisPathfinder:FindBagSlot(itemid)
    itemid = tonumber(itemid)
    if not itemid then return false end
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            if C_Container.GetContainerItemID(bag, slot) == itemid then return bag, slot end
        end
    end
    return false
end

function AegisPathfinder:GetItemNameByItemId(itemId)
    if not itemId then return nil end
    itemId = tonumber(itemId)
    if not itemId then return nil end

    -- Try pfQuest localized database
    if pfDB and pfDB["items"] and pfDB["items"]["loc"] then
        local name = pfDB["items"]["loc"][itemId] or pfDB["items"]["loc"][tostring(itemId)]
        if name then return name end
    end

    -- Fall back to the client item cache; a miss fires the server query so a
    -- later call succeeds
    return C_Item.GetItemNameByID(itemId)
end

-- Effective item requirement for a step: the authored |L| tag, or for
-- COMPLETE steps derived from the quest's static objective data
-- (C_QuestLog.GetQuestDetails requirements; cache-warmed at guide load).
-- Returns itemID (number), quantity.
function AegisPathfinder:GetLootRequirement(i)
    i = i or self.current
    local lootitem, lootqty = self:GetObjectiveTag("L", i)
    if lootitem then return tonumber(lootitem), lootqty end

    if not self.actions or self.actions[i] ~= "COMPLETE" then return end
    local qid = tonumber((self:GetObjectiveTag("QID", i)))
    if not qid then return end

    -- GetQuestDetails materializes ~20 table fields plus strings per call, and
    -- the status-frame refresh hits this step twice (via GetObjectiveInfo and
    -- directly). Serve resolved lookups from the per-load cache; false marks a
    -- step with no item requirement so we don't re-materialize on every refresh.
    local cache = self.lootreqcache
    if cache then
        local c = cache[i]
        if c == false then return end
        if c then return c.id, c.count end
    end

    local d = C_QuestLog.GetQuestDetails(qid)
    -- Data not warm yet: don't cache, so a later call retries once it loads
    if not d or not d.requirements then return end

    -- |OIDX| names the objective; without it, only a single-objective
    -- collect quest is unambiguous
    local oidx = tonumber((self:GetObjectiveTag("OIDX", i)))
    local req
    if oidx then
        req = d.requirements[oidx]
    elseif table.getn(d.requirements) == 1 then
        req = d.requirements[1]
    end
    cache = cache or {}
    self.lootreqcache = cache
    if req and req.kind == "item" then
        cache[i] = { id = req.id, count = req.count }
        return req.id, req.count
    end
    cache[i] = false
end

function AegisPathfinder:GetObjectiveInfo(i)
    local i = i or self.current
    -- self.actions only exists once LoadGuide has parsed a guide; event handlers
    -- reach this before that (login, "No Guide", or a targeting event fired by
    -- another addon), so the table itself has to be checked, not just the step.
    if not self.actions or not self.actions[i] then return end

    local action = self.actions[i]
    local name = string.gsub(self.quests[i], "@.*@", "")

    -- Dynamically enrich name for BUY or COMPLETE/collect steps with item names
    if (action == "BUY" or action == "COMPLETE") then
        local lootitem, lootqty = self:GetLootRequirement(i)
        if lootitem then
            local itemName = self:GetItemNameByItemId(lootitem)
            if itemName then
                local lowerName = string.lower(name)
                local lowerItem = string.lower(itemName)
                if not string.find(lowerName, lowerItem, 1, true) then
                    -- If the quest name is generic, replace it completely. Otherwise append it.
                    if name == "Collect item" or name == "Auctioneer Stockton" or name == "Auctioneer Stockton in the Trade Quarter" or string.find(lowerName, "^vendor") or string.find(lowerName, "^talk to") then
                        if action == "BUY" then
                            name = "Buy: " .. itemName .. " (x" .. lootqty .. ")"
                        else
                            name = "Collect: " .. itemName .. " (x" .. lootqty .. ")"
                        end
                    else
                        name = name .. " (" .. itemName .. " x" .. lootqty .. ")"
                    end
                end
            end
        end
    end

    return action, name, self.quests[i] -- Action, display name, full name
end

function AegisPathfinder:GetObjectiveStatus(i)
    local i = i or self.current
    if not self.actions or not self.actions[i] then return end

    local turnedin = self.turnedin[self.quests[i]]
    local oidx_str = self:GetObjectiveTag("OIDX", i)
    local oidx = oidx_str and tonumber(oidx_str) or nil

    local qid = self:GetObjectiveTag("QID", i)
    local qidNum = qid and tonumber(qid) or nil
    local logi, complete = self:GetQuestDetails(self.quests[i], oidx, qidNum)

    -- Auto-complete if the quest is impossible for this player (due to race/class/prereq restrictions)
    if qidNum and not self:IsQuestPossible(qidNum) then
        turnedin = true
    end

    -- Server-side completion check for TURNIN and RUN actions with QID
    if not turnedin then
        local action = self.actions[i]
        if qidNum and self:IsQuestCompletedOnServer(qidNum) then
            turnedin = true
        end
    end

    -- Skip TURNIN step if the quest is not accepted (not in log) and not
    -- completed. Flagged in the fourth return so UpdateStatusFrame can warn
    -- when it passes over such a step: this silent skip is how a missed
    -- accept cascades into the guide jumping ahead. A quest on your quest
    -- list but under a collapsed header is not missing (RevealGuideQuests).
    local skippednotinlog
    if not turnedin and not (self.manuallyUnchecked and self.manuallyUnchecked[self.quests[i]]) then
        local action = self.actions[i]
        local hidden = qidNum and C_QuestLog and C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(qidNum)
        if action == "TURNIN" and not logi and not hidden then
            local cleanQuest = string.gsub(self.quests[i], "@.*@", "")
            cleanQuest = string.gsub(cleanQuest, AegisPathfinder.Locale.PART_GSUB, "")
            local isCompleted = (qidNum and self:IsQuestCompletedOnServer(qidNum)) or (self.db.char.completedquests and self.db.char.completedquests[cleanQuest])
            if not isCompleted then
                turnedin = true
                skippednotinlog = true
            end
        end
    end

    return turnedin, logi, complete, skippednotinlog
end

function AegisPathfinder:SetTurnedIn(i, value, noupdate)
    if not i then
        i = self.current
        value = true
    end
    -- No step to mark: every guide is closed.
    if not i or not self.quests or not self.quests[i] then return end

    local qid = self:GetObjectiveTag("QID", i)
    if qid and not value then
        local qidNum = tonumber(qid)
        if pfQuest_history and (pfQuest_history[qidNum] or pfQuest_history[tostring(qidNum)]) then
            self:UpdateStatusFrame()
            return
        end
    end

    if value then
        value = true
        if self.manuallyUnchecked then
            self.manuallyUnchecked[self.quests[i]] = nil
        end
    else
        value = nil
        if self.manuallyUnchecked then
            self.manuallyUnchecked[self.quests[i]] = true
        end
    end

    local quest = self.quests[i]
    self.turnedin[quest] = value
    self:Debug(string.format("Set turned in %q = %s", quest, tostring(value)))

    -- Mirror manual UNCHECK to clear completion state
    if not value then
        local qid = self:GetObjectiveTag("QID", i)
        local cleanQuest = string.gsub(quest, "@.*@", "")
        cleanQuest = string.gsub(cleanQuest, AegisPathfinder.Locale.PART_GSUB, "")
        if qid then
            self.db.char.completedquestsbyid[tonumber(qid)] = nil
        end
        self.db.char.completedquests[cleanQuest] = nil
    end

    if not noupdate then
        self:UpdateStatusFrame()
    elseif value then
        -- Arm the delayed update only for turn-ins: the gate waits for the
        -- quest to leave the log. An uncheck's quest legitimately stays in
        -- the log and would wedge the gate shut permanently.
        self.updatedelay = i
        self.updatedelaytime = GetTime()
    end
end

function AegisPathfinder:CompleteQuest(name, noupdate)
    if not self.current then
        self:Debug(string.format("Cannot complete %q, no guide loaded", name))
        return
    end

    local action, quest
    for i in ipairs(self.actions) do
        action, quest = self:GetObjectiveInfo(i)
        self:Debug(string.format("Action %q Quest %q", action, quest))
        if action == "TURNIN" and not self:GetObjectiveStatus(i) and name == string.gsub(quest, L.PART_GSUB, "") then
            self:Debug(string.format("Saving quest turnin %q", quest))

            -- Save to completion DB permanently
            local qid = self:GetObjectiveTag("QID", i)
            local cleanQuest = string.gsub(quest, "@.*@", "")
            cleanQuest = string.gsub(cleanQuest, AegisPathfinder.Locale.PART_GSUB, "")
            if qid then
                self.db.char.completedquestsbyid[tonumber(qid)] = true
            end
            self.db.char.completedquests[cleanQuest] = true

            return self:SetTurnedIn(i, true, noupdate)
        end
    end
    self:Debug(string.format("Quest %q not found!", name))
end

function AegisPathfinder:CompleteQuestByQid(questID, noupdate)
    if not self.current then
        self:Debug(string.format("Cannot complete QID %d, no guide loaded", questID))
        return false
    end

    -- Guard on the raw turnedin table, not GetObjectiveStatus: the handler
    -- records the QID in completedquestsbyid before calling here, which makes
    -- GetObjectiveStatus already report the step as turned in and would hide
    -- it from this search
    for i in ipairs(self.actions) do
        if self.actions[i] == "TURNIN" and not self.turnedin[self.quests[i]] then
            local qid = tonumber((self:GetObjectiveTag("QID", i)))
            if qid == questID then
                local cleanQuest = string.gsub(self.quests[i], "@.*@", "")
                cleanQuest = string.gsub(cleanQuest, L.PART_GSUB, "")
                self:Debug(string.format("Saving quest turnin QID %d %q", questID, cleanQuest))

                self.db.char.completedquestsbyid[questID] = true
                self.db.char.completedquests[cleanQuest] = true

                self:SetTurnedIn(i, true, noupdate)
                return true
            end
        end
    end
    self:Debug(string.format("QID %d not found in guide", questID))
    return false
end

---------------------------------
--  Server Quest Query API     --
---------------------------------

function AegisPathfinder:QueryServerCompletedQuests(force)
    self:SyncWithPfQuestHistory(force)
    -- Count locally tracked completed quests
    local localCountByName = 0
    local localCountByQid = 0
    if self.db.char.completedquests then
        for _ in pairs(self.db.char.completedquests) do
            localCountByName = localCountByName + 1
        end
    end
    if self.db.char.completedquestsbyid then
        for _ in pairs(self.db.char.completedquestsbyid) do
            localCountByQid = localCountByQid + 1
        end
    end

    -- Said at every login as routine lines; when Rescan asks, as its answer.
    local say = force and self.Print or self.Say
    -- Check pfQuest availability
    local hasPfQuest = pfDB and pfDB["quests"] and pfDB["quests"]["data"]
    if hasPfQuest then
        say(self, "|cff00ff00pfQuest database detected - using prerequisite chain inference|r")
    else
        say(self, "|cffff9900pfQuest not found - prerequisite inference unavailable|r")
    end

    say(self, string.format("|cff88aaff%d quests tracked by name, %d by QID|r", localCountByName, localCountByQid))

    -- Re-run SmartSkipToStep to re-evaluate guide progress
    if self.actions and self.quests then
        local oldCurrent = self.current or 1
        self:SmartSkipToStep()
        local newCurrent = self.current or 1

        if newCurrent > oldCurrent then
            say(self, string.format("|cff00ff00Skipped to step %d (was %d)|r", newCurrent, oldCurrent))
        else
            say(self, "|cff88ff88Guide progress is up to date|r")
        end
    else
        say(self, "|cffff9900No guide loaded|r")
    end

    self:UpdateStatusFrame()
    return true
end

function AegisPathfinder:IsQuestCompletedOnServer(qid)
    if not qid then return false end
    return self.db.char.completedquestsbyid[tonumber(qid)] == true
end

---------------------------------
--   Quest Tracking            --
---------------------------------

-- Track the quest for the current objective
function AegisPathfinder:TrackCurrentQuest()
    if not self.db.char.trackquests then return end
    if not self.current or not self.actions then return end

    local action, quest = self:GetObjectiveInfo(self.current)
    if not action or not quest then return end

    -- Untrack previously tracked quest from AegisPathfinder
    if self.trackedQuestName and self.trackedQuestName ~= quest then
        local oldIndex = self:GetQuestLogIndexByName(self.trackedQuestName)
        if oldIndex and oldIndex > 0 and IsQuestWatched(oldIndex) then
            RemoveQuestWatch(oldIndex)
        end
        self.trackedQuestName = nil
    end

    -- Only auto-track for COMPLETE actions (quest objectives)
    if action == "COMPLETE" then
        -- QID lookup first: the display name may be enriched with item names
        -- and would not match the quest log title
        local qid = tonumber((self:GetObjectiveTag("QID", self.current)))
        local questLogIndex = qid and self:GetQuestLogIndexByQid(qid) or self:GetQuestLogIndexByName(quest)
        if questLogIndex and questLogIndex > 0 then
            if not IsQuestWatched(questLogIndex) then
                AddQuestWatch(questLogIndex)
                self:Debug("Tracking quest: " .. quest .. " (index " .. questLogIndex .. ")")
            end
            self.trackedQuestName = quest
        end
    end
end

---------------------------------
--   Manual Navigation         --
---------------------------------

function AegisPathfinder:SkipToNextObjective()
    if not self.current then return end
    if self.current >= table.getn(self.actions) then
        if not self:LoadNextGuide() then
            self:Print("Already at the last objective.")
        end
        return
    end

    -- Find next incomplete objective (after current)
    local nextStep = nil
    for i = self.current + 1, table.getn(self.actions) do
        local turnedin = self:GetObjectiveStatus(i)
        if not turnedin then
            nextStep = i
            break
        end
    end

    -- Mark current and all skipped objectives as done
    local endMark = nextStep and (nextStep - 1) or table.getn(self.actions)
    for i = self.current, endMark do
        self.turnedin[self.quests[i]] = true
    end

    if not nextStep then
        -- All remaining objectives are done, try next guide
        if not self:LoadNextGuide() then
            self:Print("All objectives complete.")
        end
        return
    end

    self.current = nextStep
    self:ForceWaypointUpdate()
    self:SetStatusText(self.current)
    self:UpdateOHPanel()
end

function AegisPathfinder:GoToPreviousObjective()
    if not self.current or self.current <= 1 then
        self:Print("Already at the first objective.")
        return
    end

    -- Unmark current objective so we can come back to it
    self:SetTurnedIn(self.current, false, true)

    -- Find previous objective (go back one step, unmark it)
    local prevStep = self.current - 1
    self:SetTurnedIn(prevStep, false, true)

    self.current = prevStep
    self:ForceWaypointUpdate()
    self:SetStatusText(self.current)
    self:UpdateOHPanel()

    -- Flag to re-check completion conditions after rewind
    self.recheckCompletion = true
end

--[[ Your place in the guide, and the right-click back to it.

    The arrows edit progress as they go: the forward arrow marks the steps it
    passes as done, the back arrow unmarks the ones it goes back over (and
    their quests' completion). So once you start clicking round, what is saved
    no longer says where you were. The first arrow click takes a snapshot --
    the step you were on, each step's mark, the completions -- and a
    right-click on the arrow pointing at that step puts it all back, for the
    steps the arrows moved over, and takes you there.

    With no snapshot -- you have not been clicking round -- your place is
    where the guide would open: the step your quest log shows work at, else
    the first step not done. The right-click takes you there if it is that
    way, and changes no marks. ]]

local function ForGuide(self, fn)
    for i, quest in ipairs(self.quests or {}) do
        local qid = tonumber((self:GetObjectiveTag("QID", i)))
        local name = string.gsub(string.gsub(quest, "@.*@", ""), AegisPathfinder.Locale.PART_GSUB, "")
        fn(i, quest, qid, name)
    end
end

--- Before an arrow moves you: remember where you were, once.
function AegisPathfinder:RememberPlace()
    if not self.current or not self.quests then return end
    local place = self.place
    if not place then
        local db = self.db.char
        place = { step = self.current, lo = self.current, hi = self.current,
            marks = {}, unchecked = {}, byid = {}, byname = {} }
        ForGuide(self, function(i, quest, qid, name)
            place.marks[i] = self.turnedin[quest]
            place.unchecked[i] = self.manuallyUnchecked and self.manuallyUnchecked[quest]
            if qid and db.completedquestsbyid[qid] then place.byid[qid] = true end
            if db.completedquests[name] then place.byname[name] = true end
        end)
        self.place = place
    end
    if self.current < place.lo then place.lo = self.current end
    if self.current > place.hi then place.hi = self.current end
end

--- Where the guide would open, without going there.
function AegisPathfinder:FindPlace()
    local was = self.current
    self:SmartSkipToStep(true)
    local found = self.current
    self.current = was
    return found
end

--- Right-click on an arrow: to your place, if it is that way (`direction`
--- -1 for the back arrow, 1 for the forward one).
function AegisPathfinder:ReturnToPlace(direction)
    if not self.current or not self.quests then return end
    local place = self.place
    local target = place and place.step or self:FindPlace()
    if not target or target == self.current then
        self.place = nil
        self:Print("You are at your place in the guide.")
        return
    end
    if (target - self.current) * direction < 0 then
        self:Print(target > self.current
            and "Your place is further on: right-click the forward arrow."
            or "Your place is behind you: right-click the back arrow.")
        return
    end
    if place then
        local db = self.db.char
        local lo = math.min(place.lo, self.current, target)
        local hi = math.max(place.hi, self.current, target)
        for i = lo, hi do
            local quest = self.quests[i]
            if quest then
                self.turnedin[quest] = place.marks[i]
                if self.manuallyUnchecked then self.manuallyUnchecked[quest] = place.unchecked[i] end
            end
        end
        -- Completions only come back: one earned while you looked round stays.
        for qid in pairs(place.byid) do db.completedquestsbyid[qid] = true end
        for name in pairs(place.byname) do db.completedquests[name] = true end
        self.place = nil
    end
    self.current = target
    self:ForceWaypointUpdate()
    self:SetStatusText(self.current)
    self:UpdateOHPanel()
end

function AegisPathfinder:GoToObjective(stepNum)
    stepNum = tonumber(stepNum)
    if not stepNum or stepNum < 1 or stepNum > table.getn(self.actions) then
        self:Print("Invalid step number.")
        return
    end

    -- Mark all objectives before stepNum as done (so progress persists)
    for i = 1, stepNum - 1 do
        if not self.turnedin[self.quests[i]] then
            self.turnedin[self.quests[i]] = true
        end
    end

    -- Unmark the target step and all after it
    for i = stepNum, table.getn(self.actions) do
        if self.turnedin[self.quests[i]] then
            self.turnedin[self.quests[i]] = nil
        end
    end

    self.current = stepNum
    self:ForceWaypointUpdate()
    self:SetStatusText(self.current)
    self:UpdateOHPanel()

    -- Flag to re-check completion conditions after jump
    self.recheckCompletion = true
end

---------------------------------
--      Guide tabs             --
---------------------------------

-- The sentinel the addon has always stored for "no guide loaded". It is not a
-- registered guide, which is what stops LoadNextGuide advancing from it.
AegisPathfinder.NO_GUIDE = "No Guide"
local NO_GUIDE = AegisPathfinder.NO_GUIDE

-- How many guides can be open at once. The tab bar scrolls, so this is not
-- about width: past eight, paging through tabs to find a guide is slower than
-- the guide list it was opened from.
AegisPathfinder.MAX_GUIDE_TABS = 8
local MAX_GUIDE_TABS = AegisPathfinder.MAX_GUIDE_TABS

--[[ The open guides.

    The panel used to hold one guide, plus at most one branch off it. The
    concept's tab bar implies as many as you want open at once, so this is a
    list: tab 1 is the main route -- what auto-advance follows -- and
    anything after it is a guide opened beside it. Any of them can be closed.

    Each tab remembers its own step, so switching back to one puts you where
    you left it rather than at the top.
]]
function AegisPathfinder:EnsureTabs()
    local db = self.db.char
    -- An empty list is a real state -- the player closed every guide -- and
    -- must survive a reload. Only a missing list means "never built".
    if db.tabs then return db.tabs end

    db.tabs = {}
    -- Carry over a one-deep branch saved by an older version: the guide that
    -- was set aside becomes tab 1, the branch becomes tab 2.
    if db.isbranching and db.branchsavedguide then
        table.insert(db.tabs, { guide = db.branchsavedguide, step = db.branchsavedstep or 1 })
        table.insert(db.tabs, { guide = db.currentguide or db.branchsavedguide, step = self.current or 1 })
        db.activetab = 2
    elseif db.currentguide and db.currentguide ~= NO_GUIDE then
        table.insert(db.tabs, { guide = db.currentguide, step = self.current or 1 })
        db.activetab = 1
    end
    return db.tabs
end

--- The tab the player is looking at, or nil with every guide closed.
function AegisPathfinder:GetActiveTab()
    local tabs = self:EnsureTabs()
    if table.getn(tabs) == 0 then return nil, 0 end
    local i = self.db.char.activetab or 1
    if i < 1 or i > table.getn(tabs) then i = 1; self.db.char.activetab = 1 end
    return tabs[i], i
end

--- True when every guide has been closed and the panel is showing its empty
--- state rather than a guide.
function AegisPathfinder:HasNoGuide()
    return table.getn(self:EnsureTabs()) == 0
end

--[[ Put the addon into the no-guide state.

    Nothing loaded, nothing to advance, no waypoint. `currentguide` becomes the
    same "No Guide" sentinel the addon has always used for a fresh character,
    which LoadNextGuide already refuses to advance from -- so closing the last
    tab cannot be undone behind the player's back by the auto-advance chain.
]]
function AegisPathfinder:UnloadGuide()
    self.db.char.currentguide = NO_GUIDE
    self.actions, self.quests, self.tags = {}, {}, {}
    self.turnedin = {}
    self.current = nil
    self.guidechanged = true
    if self.ClearWaypoint then self:ClearWaypoint() end
    if self.navcallout then self.navcallout:Hide() end
end

--[[ Keep the branch fields in step with the tab list.

    Everything that asks "am I on a branch?" is really asking "is the active
    tab something other than the main route?", so the old fields are answered
    from the tabs rather than maintained separately and allowed to disagree.
]]
function AegisPathfinder:SyncBranchState()
    local db = self.db.char
    local tabs = self:EnsureTabs()
    local active = db.activetab or 1

    db.isbranching = active > 1 and tabs[active] ~= nil
    if db.isbranching then
        db.branchsavedguide = tabs[1] and tabs[1].guide
        db.branchsavedstep = tabs[1] and tabs[1].step
    else
        db.branchsavedguide = nil
        db.branchsavedstep = nil
    end
end

--- Remember where the player is in the tab they are leaving.
function AegisPathfinder:StashActiveStep()
    local tab = self:GetActiveTab()
    if tab and self.current then tab.step = self.current end
end

--- Index of the tab showing this guide, or nil.
function AegisPathfinder:FindTab(guideName)
    local tabs = self:EnsureTabs()
    for i, tab in ipairs(tabs) do
        if tab.guide == guideName then return i end
    end
    return nil
end

--[[ Open a guide in a tab, or switch to it if it already has one.

    Opening never replaces what you were reading: the guide you were on keeps
    its tab and its place in it. Past MAX_GUIDE_TABS the bar has nowhere to
    put another, so it says so rather than silently dropping one.
]]
function AegisPathfinder:OpenGuideTab(guideName)
    if not guideName or not self.guides[guideName] then
        self:Print("Invalid guide: " .. tostring(guideName))
        return
    end

    local existing = self:FindTab(guideName)
    if existing then
        self:SwitchToTab(existing)
        return
    end

    local tabs = self:EnsureTabs()
    if table.getn(tabs) >= MAX_GUIDE_TABS then
        self:Print(string.format("%d guides are open -- close one to open %s.",
            MAX_GUIDE_TABS, guideName))
        return
    end

    self:StashActiveStep()
    table.insert(tabs, { guide = guideName, step = 1 })
    self.db.char.activetab = table.getn(tabs)
    self:SyncBranchState()

    self:LoadGuide(guideName)
    self:UpdateStatusFrame()
    self:UpdateGuideListPanel()
end

--- Load a guide into the tab you are on, replacing what it showed. With no
--- tab open this is the same as opening one.
function AegisPathfinder:LoadGuideInTab(guideName)
    if not guideName or not self.guides[guideName] then return end
    if self:HasNoGuide() then return self:OpenGuideTab(guideName) end

    local existing = self:FindTab(guideName)
    if existing then return self:SwitchToTab(existing) end

    local tab = self:GetActiveTab()
    tab.guide, tab.step = guideName, 1
    self:LoadGuide(guideName)
    self:UpdateStatusFrame()
    self:UpdateGuideListPanel()
end

--- Show the guide in tab `index`, resuming where it was left.
function AegisPathfinder:SwitchToTab(index)
    local tabs = self:EnsureTabs()
    local tab = tabs[index]
    if not tab then return end
    if index == (self.db.char.activetab or 1) then return end

    if not self:HasNoGuide() then self:StashActiveStep() end
    self.db.char.activetab = index
    self:SyncBranchState()

    self:LoadGuide(tab.guide)
    if tab.step then self.current = tab.step end
    self:UpdateStatusFrame()
    self:UpdateGuideListPanel()
end

--[[ Close a tab. Every tab can be closed, the first one included.

    Closing the tab you are on returns you to the first tab -- the main route,
    which is what the concept's branch-tab ✕ does -- or, if that was the first
    tab, to whatever became first. Closing the last one leaves the panel empty,
    waiting for a guide to be chosen, rather than quietly loading one.
]]
function AegisPathfinder:CloseTab(index)
    local tabs = self:EnsureTabs()
    if not tabs[index] then return end

    local active = self.db.char.activetab or 1
    local wasActive = active == index
    if not wasActive then self:StashActiveStep() end

    table.remove(tabs, index)

    if table.getn(tabs) == 0 then
        self.db.char.activetab = 1
        self:SyncBranchState()
        self:UnloadGuide()
        self:UpdateOHPanel()
        self:UpdateGuideListPanel()
        return
    end

    if wasActive then
        active = 1
    elseif active > index then
        active = active - 1
    end
    self.db.char.activetab = active
    self:SyncBranchState()

    -- Only reload when the guide on screen actually changed.
    local tab = tabs[active]
    if wasActive then
        self:LoadGuide(tab.guide)
        if tab.step then self.current = tab.step end
    end
    self:UpdateStatusFrame()
    self:UpdateGuideListPanel()
end

---------------------------------
--      Branching Functions    --
---------------------------------

--[[ Go back to the main route, closing the tab you were on.

    Tab 1 keeps the guide you had in it. Only if you have out-levelled it
    while you were away -- your level is past the top of its range -- does it
    move on, along that guide's own way forward, to the first guide you have
    not out-levelled; the route pack's guide for your level is the last
    resort. It used to take the route pack's guide whenever that differed,
    which put a RestedXP Hardcore guide over an Optimized one still at your
    level when a class quest guide finished.
]]
function AegisPathfinder:ReturnFromBranch()
    local tabs = self:EnsureTabs()
    local active = self.db.char.activetab or 1
    if active == 1 then
        self:Print("Already on the main route.")
        return
    end

    table.remove(tabs, active)
    self.db.char.activetab = 1
    self:SyncBranchState()

    local savedGuide = tabs[1] and tabs[1].guide
    local level = UnitLevel("player")
    local guide = savedGuide and self:GuideForLevelFrom(savedGuide, level)
        or self:GetOptimizedGuideForLevel(level)

    if guide and guide ~= savedGuide and self.guides[guide] then
        self:Print("Returning to " .. guide .. ": you have out-leveled " .. tostring(savedGuide) .. ".")
        tabs[1].guide = guide
        tabs[1].step = 1
        self:LoadGuide(guide)
    elseif savedGuide and self.guides[savedGuide] then
        self:Print("Returning to: " .. savedGuide)
        self:LoadGuide(savedGuide)
        -- SmartSkipToStep will handle positioning
    else
        self:Print("No saved guide to return to.")
    end

    self:UpdateStatusFrame()
    self:UpdateGuideListPanel()
end

--- `name`, or if you have out-levelled it, the first guide after it that you
--- have not: its route's next leg, or its own next link, so an Optimized
--- guide goes on to Optimized ones. nil when the way forward runs out.
function AegisPathfinder:GuideForLevelFrom(name, level)
    local seen = {}
    while name and self.guides[name] and not seen[name] do
        local _, hi = self:ParseGuideLevelRange(name)
        if not hi or not level or level <= hi then return name end
        seen[name] = true
        name = self:GetRouteSuccessor(name) or self.nextzones[name]
    end
    return nil
end

-- Get the optimized guide for a given level based on the player's race route
function AegisPathfinder:GetOptimizedGuideForLevel(level)
    local routeName = self:GetRouteForRace()
    local route = self.routes and self.routes[routeName]
    if not route then return nil end

    -- Find the guide entry where level falls within range
    for _, entry in ipairs(route) do
        -- Parse level range like "12-20" or "1-12"
        local _, _, minText, maxText = string.find(entry.levels or "", "(%d+)%-(%d+)")
        local minLevel = tonumber(minText)
        local maxLevel = tonumber(maxText)
        if minLevel and maxLevel and level >= minLevel and level <= maxLevel then
            -- Only return if the guide exists
            if self.guides[entry.guide] then
                return entry.guide
            end
        end
    end

    -- If above all ranges, return the last guide that exists
    for i = table.getn(route), 1, -1 do
        if self.guides[route[i].guide] then
            return route[i].guide
        end
    end
    return nil
end

-- Turtle WoW custom zones for categorization
local TURTLE_ZONES = {
    ["Gilneas"] = true,
    ["Balor"] = true,
    ["Northwind"] = true,
    ["Grim Reaches"] = true,
    ["Icepoint Rock"] = true,
    ["Lapidis Isle"] = true,
    ["Tel'Abim"] = true,
    ["Gillijim's Isle"] = true,
    ["Gillijims Isle"] = true,
    ["Thalassian Highlands"] = true,
    ["Blackstone Island"] = true,
    ["Scarlet Enclave"] = true,
    ["Hyjal"] = true,
    ["Moonwhisper Coast"] = true,
}

-- Categorize a guide by its name
--- True when a guide is a labelled placeholder rather than authored content.
-- Shown as a TPL badge so an unauthored guide is never mistaken for a real one
-- in a list where the two look identical.
function AegisPathfinder:IsTemplateGuide(guideName)
    local qsp = self.qsplusguides and self.qsplusguides[guideName]

    return (qsp and qsp.template) and true or false
end

--- A guide's tab badge: its kind and text. TPL for a placeholder, PF for a
--- profession guide (a crafting route included), DG a dungeon guide, CL a
--- class quest guide, AT an attunement, HC a hardcore one, XP any other.
function AegisPathfinder:GuideBadge(guideName)
    if self:IsTemplateGuide(guideName) then return "tpl", "TPL" end
    local category = self:GetGuideCategory(guideName)
    if category == "profession" then return "pf", "PF" end
    if category == "dungeon" then return "dg", "DG" end
    if category == "class" then return "cl", "CL" end
    if category == "attunement" then return "at", "AT" end
    if category == "rxp_hc" then return "hc", "HC" end
    return "xp", "XP"
end

function AegisPathfinder:GetGuideCategory(guideName)
    -- Profession guides declare their category on the guide table rather than
    -- encoding it in the name, so ask the table first. Matching on the name
    -- would put "Alchemy (1-300)" in with the zone guides.
    local qsp = self.qsplusguides and self.qsplusguides[guideName]
    if qsp and qsp.category == "Profession" then
        return "profession"
    end

    -- Before the custom zones: "Dungeons/Gilneas City" is no zone guide.
    if string.find(guideName, "^Dungeons/") then
        return "dungeon"
    end
    if string.find(guideName, "^Class/") then
        return "class"
    end
    if string.find(guideName, "^Attunement/") then
        return "attunement"
    end
    if string.find(guideName, "^Optimized/") then
        return "optimized"
    end
    if string.find(guideName, "^RXP/") then
        return "rxp"
    end
    if string.find(guideName, "^RXP_Hardcore/") then
        return "rxp_hc"
    end
    -- Check if any turtle zone name appears in guide name
    for zone in pairs(TURTLE_ZONES) do
        if string.find(guideName, zone) then
            return "turtle"
        end
    end
    return "zone"
end

-- Parse level range from guide name (e.g., "(1-12)" or "(12-20)" or "1-6 Name")
function AegisPathfinder:ParseGuideLevelRange(guideName)
    -- Try (1-12) format first
    local _, _, minText, maxText = string.find(guideName, "%((%d+)%-(%d+)%)")
    if not minText then
        -- Try 1-12 format (common in RXP guides)
        _, _, minText, maxText = string.find(guideName, "(%d+)%-(%d+)")
    end
    if not minText then
        -- A class quest guide's one level: "Class/Warlock: Voidwalker (10)".
        _, _, minText = string.find(guideName, "%((%d+)%)$")
        maxText = minText
    end

    if minText and maxText then
        return tonumber(minText), tonumber(maxText)
    end
    return nil, nil
end

---------------------------------
--      Route Functions        --
---------------------------------

--[[ Route selection.

    It was a window of its own -- a stack of pack buttons over a stack of race
    buttons. The concept puts race and route pack at the top of the options
    panel, so that is where this goes now.
]]
function AegisPathfinder:ShowRouteSelector()
    if not self.optionsframe then self:CreateConfigPanel() end
    self.optionsframe:Show()
    self:ShowConfigPage("Route")
end

function AegisPathfinder:SelectRoute(race)
    self:ApplyRouteSelection(race)
    local message = L["You have been assigned the %s leveling route."]
    if not message then
        message = "You have been assigned the %s leveling route."
    end
    self:Print(string.format(message, tostring(race)))
    self:UpdateStatusFrame()
end

-- Get the next guide in the current route based on player level
-- Only returns guides that actually exist in self.guides
-- Finds the best guide for the player's level:
-- 1. First preference: guide where player is within the actual level range
-- 2. Second preference: guide where player is slightly over (within +2 buffer)
-- 3. Fallback: first future guide if player is somehow ahead of all guides
function AegisPathfinder:GetNextRouteGuideForLevel(route, playerLevel)
    if not route then return nil end

    local level = playerLevel or UnitLevel("player")
    local bestGuide
    local bestMinLevel = -1
    local fallbackGuide -- For extended range matches
    local fallbackMinLevel = -1
    local futureGuide   -- First guide ahead of player's level
    local skippedGuides = {}

    for i, zone in ipairs(route) do
        local _, _, minText, maxText = string.find(zone.levels or "", "(%d+)%-(%d+)")
        local minLevel = tonumber(minText) or 1
        local maxLevel = tonumber(maxText) or 60

        if self.guides[zone.guide] then
            -- Priority 1: Player is within actual level range
            if level >= minLevel and level <= maxLevel then
                -- Pick the guide with the highest minLevel that still fits
                if minLevel > bestMinLevel then
                    bestGuide = zone.guide
                    bestMinLevel = minLevel
                end
                -- Priority 2: Player is slightly over (within +2 buffer for overlap)
            elseif level > maxLevel and level <= maxLevel + 2 then
                if minLevel > fallbackMinLevel then
                    fallbackGuide = zone.guide
                    fallbackMinLevel = minLevel
                end
                -- Priority 3: Guide is ahead of player (for fallback)
            elseif level < minLevel and not futureGuide then
                futureGuide = zone.guide
            end
        else
            -- Guide doesn't exist, record it as skipped
            table.insert(skippedGuides, zone.guide)
        end
    end

    -- Warn about skipped guides
    if table.getn(skippedGuides) > 0 then
        self:Print("|cffff9900Warning: Skipped missing guides: " .. table.concat(skippedGuides, ", ") .. "|r")
    end

    -- Return best match in priority order
    return bestGuide or fallbackGuide or futureGuide
end

function AegisPathfinder:ApplyRouteSelection(race)
    self.db.char.currentroute = race
    self.db.char.routeselected = true

    local route = self.routes[race]
    local nextguide = self:GetNextRouteGuideForLevel(route, UnitLevel("player"))
    if not nextguide and route and route[1] and route[1].guide then
        nextguide = route[1].guide
    end
    if nextguide then
        self.db.char.currentguide = nextguide
        self:LoadGuide(self.db.char.currentguide)
    end
end

---------------------------------
--  Starting Zone Selection    --
--  (Branch-and-Rejoin Logic)  --
---------------------------------

-- Define starting zones for each faction
-- These are the "branch" points - race-specific 1-12 zones
AegisPathfinder.startingZones = {
    Alliance = {
        { race = "Human",    zone = "Elwynn Forest",        guide = "Elwynn Forest (1-12)",        levels = "1-12", rejoinLevel = 12 },
        { race = "Dwarf",    zone = "Dun Morogh",           guide = "Dun Morogh (1-12)",           levels = "1-12", rejoinLevel = 12 },
        { race = "NightElf", zone = "Teldrassil",           guide = "Teldrassil (1-12)",           levels = "1-12", rejoinLevel = 12 },
        { race = "Gnome",    zone = "Dun Morogh",           guide = "Dun Morogh (1-12)",           levels = "1-12", rejoinLevel = 12 },
        { race = "HighElf",  zone = "Thalassian Highlands", guide = "Thalassian Highlands (1-10)", levels = "1-10", rejoinLevel = 12 }, -- Turtle WoW
        -- RestedXP Speedleveling Guides
        { race = "Human",    zone = "RXP (Human)",          guide = "RXP/1-6 Northshire",          levels = "1-21", rejoinLevel = 21 },
        { race = "Dwarf",    zone = "RXP (Dwarf)",          guide = "RXP/1-6 Coldridge Valley",    levels = "1-21", rejoinLevel = 21 },
        { race = "Gnome",    zone = "RXP (Gnome)",          guide = "RXP/1-6 Coldridge Valley",    levels = "1-21", rejoinLevel = 21 },
        { race = "NightElf", zone = "RXP (NightElf)",       guide = "RXP/1-6 Shadowglen",          levels = "1-21", rejoinLevel = 21 },
    },
    Horde = {
        { race = "Orc",      zone = "Durotar",           guide = "Durotar (1-12)",             levels = "1-12", rejoinLevel = 12 },
        { race = "Troll",    zone = "Durotar",           guide = "Durotar (1-12)",             levels = "1-12", rejoinLevel = 12 },
        { race = "Tauren",   zone = "Mulgore",           guide = "Mulgore (1-12)",             levels = "1-12", rejoinLevel = 12 },
        { race = "Undead",   zone = "Tirisfal Glades",   guide = "Tirisfal (1-12)",            levels = "1-12", rejoinLevel = 12 },
        { race = "Goblin",   zone = "Blackstone Island", guide = "Blackstone Island (1-10)",   levels = "1-10", rejoinLevel = 10 }, -- Turtle WoW
        -- RestedXP Speedleveling Guides
        { race = "Human",    zone = "RXP (Human)",       guide = "RXP/1-6 Northshire",         levels = "1-21", rejoinLevel = 21 },
        { race = "Dwarf",    zone = "RXP (Dwarf)",       guide = "RXP/1-6 Coldridge Valley",   levels = "1-21", rejoinLevel = 21 },
        { race = "Gnome",    zone = "RXP (Gnome)",       guide = "RXP/1-6 Coldridge Valley",   levels = "1-21", rejoinLevel = 21 },
        { race = "NightElf", zone = "RXP (NightElf)",    guide = "RXP/1-6 Shadowglen",         levels = "1-21", rejoinLevel = 21 },
        { race = "Orc",      zone = "RXP (Orc)",         guide = "RXP/1-6 Orc/Troll",          levels = "1-23", rejoinLevel = 23 },
        { race = "Troll",    zone = "RXP (Troll)",       guide = "RXP/1-6 Orc/Troll",          levels = "1-23", rejoinLevel = 23 },
        { race = "Tauren",   zone = "RXP (Tauren)",      guide = "RXP/1-6 Tauren",             levels = "1-23", rejoinLevel = 23 },
        { race = "Undead",   zone = "RXP (Undead)",      guide = "RXP/1-6 Undead",             levels = "1-23", rejoinLevel = 23 },

        --- Not offered while its guide is missing (the pack is hidden, Routes/Routes.lua).
        { race = "Warrior",  zone = "Kamisayo Speedrun", guide = "RXP/Kamisayo Speedrun 1-13", levels = "1-60", rejoinLevel = 60, class = "Warrior", isSpeedrun = true },
    },
}

-- Get available starting zones for the player's faction
function AegisPathfinder:GetAvailableStartingZones()
    local faction = self.myfaction
    local zones = self.startingZones[faction] or {}
    local available = {}
    local _, playerClass = UnitClass("player")

    -- Filter to only include zones with existing guides and matching class
    for _, zoneInfo in ipairs(zones) do
        if self.guides[zoneInfo.guide] then
            -- Check class filter if present
            if zoneInfo.class then
                if zoneInfo.class == playerClass then
                    table.insert(available, zoneInfo)
                end
            else
                table.insert(available, zoneInfo)
            end
        end
    end

    return available
end

-- Get the player's native starting zone based on their race
function AegisPathfinder:GetNativeStartingZone()
    local routeName = self:GetRouteForRace()
    local faction = self.myfaction
    local zones = self.startingZones[faction] or {}

    for _, zoneInfo in ipairs(zones) do
        if zoneInfo.race == routeName then
            return zoneInfo
        end
    end

    -- Fallback to first zone for faction
    return zones[1]
end

-- Check if the current guide is a starting zone guide
function AegisPathfinder:IsInStartingZone()
    local currentGuide = self.db.char.currentguide
    if not currentGuide then return false end

    local faction = self.myfaction
    local zones = self.startingZones[faction] or {}

    for _, zoneInfo in ipairs(zones) do
        if zoneInfo.guide == currentGuide then
            return true, zoneInfo
        end
    end

    return false
end

-- Get the rejoin point (shared route) based on current starting zone
-- The rejoin point is where all starting zone paths converge
function AegisPathfinder:GetRejoinGuide()
    local faction = self.myfaction
    local playerLevel = UnitLevel("player")

    -- Shared routes after starting zone (level 12+)
    -- Alliance converges to Darkshore/Westfall path
    -- Horde converges to Barrens path
    local rejoinGuides = {
        Alliance = {
            { guide = "Westfall (12-17)",   minLevel = 12, maxLevel = 17 },
            { guide = "Darkshore (12-17)",  minLevel = 12, maxLevel = 17 },
            { guide = "Loch Modan (17-18)", minLevel = 17, maxLevel = 18 },
        },
        Horde = {
            { guide = "The Barrens (12-20)",       minLevel = 12, maxLevel = 20 },
            { guide = "Silverpine Forest (12-20)", minLevel = 12, maxLevel = 20 },
        },
    }

    local guideList = rejoinGuides[faction] or {}

    -- Find the best rejoin guide for player's level
    for _, entry in ipairs(guideList) do
        if self.guides[entry.guide] then
            if playerLevel >= entry.minLevel and playerLevel <= entry.maxLevel + 2 then
                return entry.guide
            end
        end
    end

    -- Fallback to first available rejoin guide
    for _, entry in ipairs(guideList) do
        if self.guides[entry.guide] then
            return entry.guide
        end
    end

    return nil
end

-- Handle starting zone completion and transition to shared path
--- `level` is the level to judge by -- a level up's own; yours when nil.
function AegisPathfinder:CheckStartingZoneCompletion(level)
    local inStartingZone, zoneInfo = self:IsInStartingZone()
    if not inStartingZone then return false end

    local playerLevel = level or UnitLevel("player")
    local rejoinLevel = zoneInfo and zoneInfo.rejoinLevel or 12

    -- Check if player has outleveled the starting zone
    if playerLevel >= rejoinLevel then
        -- Check if current guide is complete (or nearly complete)
        local totalSteps = self.actions and table.getn(self.actions) or 0
        if totalSteps == 0 then return false end

        local completedSteps = 0
        for i, quest in ipairs(self.quests) do
            if self.turnedin[quest] then
                completedSteps = completedSteps + 1
            end
        end

        local completion = completedSteps / totalSteps
        -- Transition when guide is 80%+ complete or player is 2+ levels above rejoin
        if completion >= 0.8 or playerLevel >= rejoinLevel + 2 then
            self:TransitionFromStartingZone()
            return true
        end
    end

    return false
end

-- Transition from starting zone to shared leveling path
function AegisPathfinder:TransitionFromStartingZone()
    local L = self.Locale

    -- Mark starting zone as complete
    self.db.char.startingzonecomplete = true
    self.db.char.completion[self.db.char.currentguide] = 1

    self:Say("|cff00ff00" .. L["Starting zone complete!"] .. "|r")
    self:Say(L["Transitioning to shared leveling path..."])

    -- Get the rejoin guide
    local rejoinGuide = self:GetRejoinGuide()
    if rejoinGuide then
        self.db.char.currentguide = rejoinGuide
        self:LoadGuide(rejoinGuide)
        self:UpdateStatusFrame()
        self:UpdateGuideListPanel()
    else
        -- Fallback to standard LoadNextGuide behavior
        self:LoadNextGuide()
    end
end

-- Show the Starting Zone Selector UI
function AegisPathfinder:ShowStartingZoneSelector()
    if not self.startingZoneSelectorFrame then
        self:CreateStartingZoneSelectorFrame()
    end
    self:UpdateStartingZoneSelectorPanel()
    self.startingZoneSelectorFrame:Show()
end

function AegisPathfinder:CreateStartingZoneSelectorFrame()
    local L = self.Locale
    local f = CreateFrame("Frame", "AegisPathfinderStartingZoneSelectorFrame", UIParent)
    f:SetWidth(380)
    f:SetHeight(320 + DIALOG_CHROME)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
    self.Theme:Panel(f, "panel")
    f:SetFrameStrata("DIALOG")

    local _, sub = self.Theme:Chrome(f, L["Choose Starting Zone"],
        self.Theme:PositionSaver("startzoneframe"))

    -- Description
    local desc = f:CreateFontString(nil, "ARTWORK")
    AegisPathfinder.Theme:SetFont(desc, "body", 12)
    desc:SetPoint("TOP", sub, "BOTTOM", 0, -10)
    desc:SetWidth(340)
    desc:SetText(L["Select which starting zone you want to level through:"])

    -- Native race indicator
    local nativeText = f:CreateFontString(nil, "ARTWORK")
    AegisPathfinder.Theme:SetFont(nativeText, "body", 12)
    nativeText:SetPoint("TOP", desc, "BOTTOM", 0, -15)
    nativeText:SetWidth(340)
    f.nativeText = nativeText

    -- Container for zone buttons
    local buttonContainer = CreateFrame("Frame", nil, f)
    buttonContainer:SetPoint("TOP", nativeText, "BOTTOM", 0, -10)
    buttonContainer:SetWidth(340)
    buttonContainer:SetHeight(180)
    f.buttonContainer = buttonContainer

    -- Zone buttons (will be populated dynamically)
    f.zoneButtons = {}
    for i = 1, 6 do
        local btn = AegisPathfinder.Theme:PanelButton(buttonContainer)
        btn:SetWidth(300)
        btn:SetHeight(28)
        btn:SetPoint("TOP", buttonContainer, "TOP", 0, -(i - 1) * 32)
        btn:Hide()

        btn:SetScript("OnClick", function()
            if this.zoneInfo then
                AegisPathfinder:SelectStartingZone(this.zoneInfo)
                f:Hide()
            end
        end)

        f.zoneButtons[i] = btn
    end

    -- Info text at bottom
    local infoText = f:CreateFontString(nil, "ARTWORK")
    AegisPathfinder.Theme:SetFont(infoText, "body", 11)
    infoText:SetPoint("BOTTOM", f, "BOTTOM", 0, 40)
    infoText:SetWidth(340)
    infoText:SetTextColor(0.7, 0.7, 0.7)
    infoText:SetText(L["You can change starting zones from the Options menu"])

    -- Close button

    self.startingZoneSelectorFrame = f
    table.insert(UISpecialFrames, "AegisPathfinderStartingZoneSelectorFrame")
    f:Hide()
end

function AegisPathfinder:UpdateStartingZoneSelectorPanel()
    local f = self.startingZoneSelectorFrame
    if not f or not f:IsVisible() then return end

    local L = self.Locale
    local nativeZone = self:GetNativeStartingZone()
    local availableZones = self:GetAvailableStartingZones()

    -- Show native race info
    if nativeZone then
        local _, race = UnitRace("player")
        f.nativeText:SetText("|cff00ff00" .. L["Recommended for your race"] .. ":|r " .. race .. " - " .. nativeZone
            .zone)
    else
        f.nativeText:SetText("")
    end

    -- Hide all buttons first
    for i, btn in ipairs(f.zoneButtons) do
        btn:Hide()
        btn.zoneInfo = nil
    end

    -- Populate buttons with available zones
    for i, zoneInfo in ipairs(availableZones) do
        local btn = f.zoneButtons[i]
        if btn then
            local isNative = nativeZone and (zoneInfo.race == nativeZone.race)
            local displayText = zoneInfo.zone .. " (" .. zoneInfo.levels .. ")"

            if zoneInfo.isSpeedrun then
                displayText = "|cffff8800[Speedrun]|r " .. displayText
            elseif zoneInfo.isSurvival then
                displayText = "|cff00ffcc[Survival]|r " .. displayText
            elseif isNative then
                displayText = displayText .. " |cff00ff00*|r"
            end

            btn:SetText(displayText)
            btn.zoneInfo = zoneInfo
            btn:Show()
        end
    end

    -- Adjust frame height based on number of zones
    local numZones = table.getn(availableZones)
    local height = 180 + (numZones * 32)
    f:SetHeight(math.max(220, height))
end

-- Select a starting zone and begin leveling there
function AegisPathfinder:SelectStartingZone(zoneInfo)
    local L = self.Locale

    -- Save the selection
    self.db.char.startingzoneselected = true
    self.db.char.selectedstartingzone = zoneInfo.race
    self.db.char.startingzonecomplete = false
    self.db.char.rejoinlevel = zoneInfo.rejoinLevel or 12

    -- Also set the route to match the starting zone's race
    -- This ensures the shared route after rejoin is appropriate
    self.db.char.currentroute = zoneInfo.race
    self.db.char.routeselected = true

    -- Set route pack based on zone type
    if zoneInfo.isSpeedrun then
        self.db.char.routepack = "Kamisayo Speedrun"
        local pack = self.routepacks["Kamisayo Speedrun"]
        if pack then
            for race, route in pairs(pack.routes) do
                self.routes[race] = route
            end
        end
    elseif zoneInfo.isSurvival then
        self.db.char.routepack = "RestedXP"
        local pack = self.routepacks["RestedXP"]
        if pack then
            for race, route in pairs(pack.routes) do
                self.routes[race] = route
            end
        end
    else
        if not self.db.char.routepack then
            self.db.char.routepack = "VanillaGuide"
        end
    end

    -- Load the starting zone guide
    if self.guides[zoneInfo.guide] then
        self.db.char.currentguide = zoneInfo.guide
        self:LoadGuide(zoneInfo.guide)

        local playerRoute = self:GetRouteForRace()

        if zoneInfo.race ~= playerRoute then
            self:Say(string.format(L["Cross-race start: %s"], zoneInfo.zone))
        end

        self:Say(string.format(L["You have been assigned the %s leveling route."], zoneInfo.zone))
    else
        self:Print("|cffff0000Error: Guide not found: " .. zoneInfo.guide .. "|r")
    end

    self:UpdateStatusFrame()
    self:UpdateGuideListPanel()
end

-- Modified InitializeRoute to show starting zone selector for new characters
function AegisPathfinder:InitializeRouteWithStartingZone()
    local playerLevel = UnitLevel("player")

    -- If player is level 1-10 and hasn't selected a starting zone, show selector
    if playerLevel <= 10 and not self.db.char.startingzoneselected then
        -- Auto-detect race and pre-select the native starting zone
        local nativeZone = self:GetNativeStartingZone()
        if nativeZone and self.guides[nativeZone.guide] then
            -- Silently apply native zone as default
            self:SelectStartingZone(nativeZone)
        else
            -- Show selector if native zone doesn't exist
            self:ShowStartingZoneSelector()
        end
        return true
    end

    -- If player already selected a starting zone but hasn't completed it
    if self.db.char.startingzoneselected and not self.db.char.startingzonecomplete then
        -- Check if they've outleveled the starting zone
        if self:CheckStartingZoneCompletion() then
            return true
        end
    end

    return false
end

function AegisPathfinder:SetupErrorCapture()
    if self.errorCaptured then return end
    self.errorCaptured = true
    self.errorLog = self.errorLog or {}

    local originalHandler = geterrorhandler()
    seterrorhandler(function(errorMessage)
        local timestamp = date("%H:%M:%S")
        local stack = debugstack and debugstack(2, 12, 12) or "(no stack)"
        local entry = string.format("[%s] %s\n%s", timestamp, tostring(errorMessage), tostring(stack))
        table.insert(self.errorLog, 1, entry)
        if table.getn(self.errorLog) > 50 then
            table.remove(self.errorLog)
        end
        if originalHandler then
            originalHandler(errorMessage)
        end
    end)
end

function AegisPathfinder:ShowErrorLog()
    if not self.errorLogFrame then
        self:CreateErrorLogFrame()
    end
    self.errorLogFrame:Show()
end

function AegisPathfinder:CreateErrorLogFrame()
    local f = CreateFrame("Frame", "AegisPathfinderErrorLogFrame", UIParent)
    f:SetWidth(520)
    f:SetHeight(360 + DIALOG_CHROME)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    self.Theme:Panel(f, "panel")
    f:SetFrameStrata("DIALOG")
    f:Hide()

    local _, sub = self.Theme:Chrome(f, "Error Log",
        self.Theme:PositionSaver("errorlogframe"))

    local desc = f:CreateFontString(nil, "ARTWORK")
    AegisPathfinder.Theme:SetFont(desc, "body", 12)
    desc:SetPoint("TOP", sub, "BOTTOM", 0, -8)
    desc:SetWidth(480)
    desc:SetText("Most recent errors are at the top. Use Ctrl+C to copy.")

    local scrollFrame = CreateFrame("ScrollFrame", "AegisPathfinderErrorLogScrollFrame", f)
    scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -(DIALOG_CHROME + 34))
    scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -32, 16)

    -- The theme's scroll bar. UIPanelScrollFrameTemplate brought Blizzard's
    -- gold arrows and knob with it, the last stock art on any window.
    local SCROLL_W, LINE = 10, 40
    local bar = self.Theme:ScrollBar(f, SCROLL_W)
    bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -(DIALOG_CHROME + 34 + SCROLL_W))
    bar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 16 + SCROLL_W)
    bar.step = LINE
    bar:SetMinMaxValues(0, 0)
    bar:SetValue(0)
    bar:SetScript("OnValueChanged", function() scrollFrame:SetVerticalScroll(arg1 or 0) end)
    f.scrollbar = bar

    -- The edit box grows with its text; the range follows it.
    scrollFrame:SetScript("OnScrollRangeChanged", function()
        local range = scrollFrame:GetVerticalScrollRange() or 0
        bar:SetMinMaxValues(0, range)
        if bar:GetValue() > range then bar:SetValue(range) end
    end)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function() bar:Nudge(-(arg1 or 0) * LINE) end)

    local editBox = CreateFrame("EditBox", "AegisPathfinderErrorLogEditBox", scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetWidth(470)
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnEscapePressed", function() f:Hide() end)
    editBox:SetScript("OnEditFocusGained", function()
        editBox:HighlightText(0)
    end)
    -- Keep the cursor in view as it moves, which the template used to do:
    -- arg2 is the cursor's offset down from the top (negative), arg4 its
    -- height.
    editBox:SetScript("OnCursorChanged", function()
        local y, h = -(arg2 or 0), arg4 or 0
        local top, view = scrollFrame:GetVerticalScroll(), scrollFrame:GetHeight()
        if y < top then
            bar:SetValue(y)
        elseif y + h > top + view then
            bar:SetValue(y + h - view)
        end
    end)

    scrollFrame:SetScrollChild(editBox)
    f.editBox = editBox


    f:SetScript("OnShow", function()
        local entries = AegisPathfinder.errorLog or {}
        if table.getn(entries) == 0 then
            f.editBox:SetText("No errors captured yet.")
        else
            f.editBox:SetText(table.concat(entries, "\n\n"))
        end
        if f.editBox.SetCursorPosition then
            f.editBox:SetCursorPosition(0)
        end
        f.editBox:HighlightText(0)
        f.scrollbar:SetValue(0)
    end)

    self.errorLogFrame = f
end

---------------------------------
--      Utility Functions      --
---------------------------------

function AegisPathfinder.select(index, ...)
    assert(tonumber(index) or index == "#", "Invalid argument #1 to select(). Usage: select(\"#\"|int,...)")
    if index == "#" then
        return tonumber(arg.n) or 0
    end
    for i = 1, index - 1 do
        table.remove(arg, 1)
    end
    return unpack(arg)
end

function AegisPathfinder.join(delimiter, list)
    assert(type(delimiter) == "string" and type(list) == "table",
        "Invalid arguments to join(). Usage: string.join(delimiter, list)")
    local len = getn(list)
    if len == 0 then
        return ""
    end
    local s = list[1]
    for i = 2, len do
        s = string.format("%s%s%s", s, delimiter, list[i])
    end
    return s
end

function AegisPathfinder.trim(s)
    return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

function AegisPathfinder.split(...)
    assert(arg.n > 0 and type(arg[1]) == "string",
        "Invalid arguments to split(). Usage: string.split([separator], subject)")
    local sep, s = arg[1], arg[2]
    if s == nil then
        s, sep = sep, ":"
    end
    local fields = {}
    local pattern = string.format("([^%s]+)", sep)
    string.gsub(s, pattern, function(c) fields[table.getn(fields) + 1] = c end)
    return fields
end

function AegisPathfinder.GetQuadrant(frame)
    local x, y = frame:GetCenter()
    if not x or not y then return "BOTTOMLEFT", "BOTTOM", "LEFT" end
    local hhalf = (x > UIParent:GetWidth() / 2) and "RIGHT" or "LEFT"
    local vhalf = (y > UIParent:GetHeight() / 2) and "TOP" or "BOTTOM"
    return vhalf .. hhalf, vhalf, hhalf
end

function AegisPathfinder:SyncWithPfQuestHistory(force)
    if not pfQuest_history then return end

    if force then
        self.db.char.completedquestsbyid = {}
        self.db.char.completedquests = {}
        if self.db.char.turnins then
            for k in pairs(self.db.char.turnins) do
                self.db.char.turnins[k] = nil
            end
        end
        if self.turnedin then
            for k in pairs(self.turnedin) do
                self.turnedin[k] = nil
            end
        end
        if self.db.char.currentguide then
            self.db.char.turnins[self.db.char.currentguide] = self.turnedin or {}
        end
    end

    local imported = 0

    -- pfQuest_history is a SavedVariablesPerCharacter flat table:
    -- pfQuest_history[qid] = { [1] = timestamp, [2] = level }
    for qid, data in pairs(pfQuest_history) do
        local qidNum = tonumber(qid)
        if qidNum and type(data) == "table" then
            if not self.db.char.completedquestsbyid[qidNum] then
                self.db.char.completedquestsbyid[qidNum] = true
                imported = imported + 1
            end

            -- Also populate the name-based completion table if we can find the name in pfQuest
            if pfDB and pfDB.quests and pfDB.quests.loc and pfDB.quests.loc[qidNum] then
                local questName = pfDB.quests.loc[qidNum]["T"]
                if questName then
                    local cleanQuest = string.gsub(questName, "%[[0-9%+%-]+]%s", "")
                    cleanQuest = string.gsub(cleanQuest, AegisPathfinder.Locale.PART_GSUB, "")
                    self.db.char.completedquests[cleanQuest] = true
                end
            end
        end
    end

    if imported > 0 then
        self:Debug(string.format("Imported %d completed quests from pfQuest history.", imported))
    end
end
