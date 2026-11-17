-- pfQuest xpGuide: the words of the Usage page (how to use it, and what it works with) and of the Features page (what it does, and what
-- changed in each version). They are tabs of the settings window (Settings.lua), opened with /xpg help (Usage), /xpg features, the page
-- buttons of Settings, or Shift-clicking the minimap icon.

local ER = pfQuest_xpGuide

local GOLD, GREEN, GREY, WHITE, END = "|cffffd100", "|cff40ff40", "|cff9d9d9d", "|cffffffff", "|r"

local function B(s) return WHITE .. s .. END end

local USAGE_TEXT = table.concat({
  GOLD .. "Start" .. END,
  "- A new character starts the " .. B("Casual route") .. " by itself. " .. B("/xpg") .. " shows or hides the guide window.",
  "- Do what the step box says; the arrow shows where. Steps tick off by themselves.",
  " ",
  GOLD .. "The guide window" .. END,
  "- " .. B("Skip step") .. " skips the step you are on. " .. B("Unskip previous") .. " brings back the one you just skipped, with its chain. A finished quest cannot be skipped.",
  "- Each step in the list has a box (a tick when completed, a skip mark when skipped): tick a later step to skip it, untick one behind you to go back to it.",
  "- Under the list: " .. B("cog") .. " Settings, " .. B("arrow") .. " pfQuest's arrow / the guide's own arrow / no arrow, " ..
    B("padlock") .. " lock the window, " .. B("x") .. " hide it, " .. B("corner") .. " resize it.",
  "- Hold " .. B("Shift") .. " when you talk to an NPC to do it yourself instead of " .. B("Auto mode") .. ".",
  " ",
  GOLD .. "Commands" .. END,
  B("/xpg") .. "   " .. B("/xpg settings") .. "   " .. B("/xpg next") .. "   " .. B("/xpg stop") .. "   " .. B("/xpg unskip") ..
    "   " .. B("/xpg selftest") .. "   " .. B("/xpg features"),
  " ",
  GOLD .. "Dependencies" .. END,
  "- Needs nothing else to run. These are optional and picked up when installed:",
  "- " .. B("pfQuest") .. ": quest objectives, map markers and its arrow. Recommended.",
  "- " .. B("pfQuest SmartArrow") .. ": plans the way to each step in pfQuest's arrow.",
  "- " .. B("pfUI") .. ": the windows, fonts and mob markers follow pfUI's look.",
  "- Installed but not found? Check the folder names: pfQuest, pfQuest-SmartArrow, pfUI.",
}, "\n")

local FEATURES_TEXT = table.concat({
  GOLD .. "Features" .. END,
  "- " .. B("Casual route") .. ": one zone at a time at an easy pace, for every race. " .. B("Fast route") .. ": RestedXP's leveling order.",
  "- " .. B("Bethink's Guide") .. ": Bethink's zone guides 1-60 in Bethink's own words (GPLv3; see LICENSE-Bethink.txt), on the Guides page after the fast routes.",
  "- " .. B("VanillaGuide") .. ": Joana's and Brian Kopps' guides 1-60 from VanillaGuide, last on the Guides page.",
  "- " .. B("Difficulty") .. ": Casual, Medium or Hard decides which quests stay in the route.",
  "- " .. B("Guide window") .. ": the step you are on with tick boxes and icons, steps on the way, every step in a list.",
  "- " .. B("Arrow") .. ": its own, or pfQuest's arrow, routed by pfQuest SmartArrow when it is installed.",
  "- " .. B("Auto mode") .. ": takes and hands in the route's quests, flights, hearthstone, selling and repairs.",
  "- " .. B("Helpers") .. ": grind spots, warnings for dangerous mobs and caves, quest chains, enemy difficulty on tooltips.",
  "- " .. B("Mob markers") .. ": left of the level on nameplates, a skull (kill), a sack (drops what you need), ! (gives the step's quest), ? (takes it back); a chain quest's shape sits behind.",
  "- " .. B("Picking a guide") .. ": the Guides page of Settings; at a guide's top level the tips box asks whether to move on to the next one.",
  "- " .. B("Settings") .. ": one window with seven tabs: Guides, Configuration, Character, Auto mode, Helpers, Usage (this) and Features.",
  " ",
  GOLD .. "Change history" .. END,
  B("1.1.2") .. GREY .. " - arrow fix" .. END,
  "- A quest to finish that pfQuest has no objective spot for (a talk quest like A Good Friend) now points the arrow at where it is handed in. Before, the step had no place and pfQuest's own arrow went to another quest's objective.",
  " ",
  B("1.1.1") .. GREY .. " - real experience for 2x" .. END,
  "- On 2x the Fast guides keep the quests that give the most experience (from real 1.12 quest values), enough for half of a visit's quest experience, instead of ranking by quest level.",
  " ",
  B("1.1.0") .. GREY .. " - xpGuide Fast guides" .. END,
  "- " .. B("xpGuide Fast") .. ": a fast 1-60 route for each faction, by class, professions and race.",
  "- Picking one asks for 1x or 2x experience (1x is the default) and your professions: the class's suggestions are ticked, the ones you have show their skill. The window's heading shows the rate.",
  "- Settings has a Character tab (rate and professions); /xpg xp 1|2 and /xpg prof <name> on|off.",
  "- Difficulty works on the Fast guides: Casual and Medium leave out elite quests, Hard keeps them.",
  " ",
  B("1.0.0") .. GREY .. " - pfQuest xpGuide (formerly Easy Route)" .. END,
  "- Usage and Features are tabs of Settings, not windows of their own.",
  "- New guide window laid out like RestedXP Guides; skip and unskip in one click; tick boxes in the step list.",
  "- Footer icons: settings, arrow, lock, hide, resize. Text follows pfQuest's font; Settings has a size picker.",
  "- Each quest chain has its own coloured line beside the steps, with its shape on the line at each of its steps; pointing at a step lights its chain.",
  "- The zone heading counts quests handed in, also ones handed in by other addons or before xpGuide was installed.",
  "- Step list: completed steps are ticked, skipped ones show a skip mark. Finish steps point at the objective, not the hand-in.",
  "- Finish and hand-in steps without instructions show the quest's own short hint.",
  "- Abandoned or skipped a quest? It becomes a button in the list (the footer counts them): click to go back. Grey or no longer offered: skipped for good.",
  "- The step list stays put when you tick or skip, and keeps the last few done steps in view as you go.",
  "- pfUI's look (OctoPad style), pfQuest SmartArrow routing, one arrow with pfQuest, High Elf and Goblin routes.",
  "- Feedback and welcome windows removed. " .. B("/xpg") .. " is the only command.",
  B("0.9.9") .. GREY .. " - Easy Route" .. END,
  "- Fixed \"attempt to call a number value\" on the Casual route (Lua 5.0's ipairs).",
}, "\n")

local PAGES = { usage = USAGE_TEXT, features = FEATURES_TEXT }

-- The words of a page ("usage" or "features"); the Usage and Features pages of the settings window show them (Settings.lua).
function ER.HelpText(page)
  return PAGES[page] or ""
end

-- /xpg help (the Usage page) or /xpg features: the settings window on that page.
function ER.ShowHelp(page)
  if ER.ShowSettings then ER.ShowSettings(page == "features" and "Features" or "Usage") end
end

-- Shift-clicking the minimap icon: the Usage page, or away with the window when it is open there.
function ER.ToggleHelp()
  if ER.SettingsShown and ER.SettingsShown() then
    ER.ToggleSettings()
  else
    ER.ShowHelp()
  end
end

-- For the quick checks: the words of each page.
function ER._testHelpText(page)
  return PAGES[page] or ""
end

ER.Loaded("Help.lua")
