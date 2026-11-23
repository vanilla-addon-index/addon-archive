-- pfQuest xpGuide: the words of the Usage page (how to use it, and what it works with) and of the Features page (what it does, and what
-- changed in each version). They are tabs of the settings window (Settings.lua), opened with /xpg help (Usage), /xpg features, the page
-- buttons of Settings, or Shift-clicking the minimap icon.

local ER = pfQuest_xpGuide

local GOLD, GREEN, GREY, WHITE, END = "|cffffd100", "|cff40ff40", "|cff9d9d9d", "|cffffffff", "|r"

local function B(s) return WHITE .. s .. END end

local USAGE_TEXT = table.concat({
  GOLD .. "Start" .. END,
  "- A new character starts the " .. B("xpGuide Fast route") .. " by itself. " .. B("/xpg") .. " shows or hides the guide window.",
  "- Something wrong with it? " .. B("/xpg fallback") .. " switches to RestedXP's original guide, and back. " .. B("/xpg report") .. " prints what the addon sees, for a bug report.",
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
    "   " .. B("/xpg fallback") .. "   " .. B("/xpg report") .. "   " .. B("/xpg moveon") .. "   " .. B("/xpg selftest") .. "   " .. B("/xpg features"),
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
  "- " .. B("xpGuide Fast route") .. ": RestedXP's leveling order with 1x or 2x quests and your professions, and starting guides for High Elves and Goblins.",
  "- " .. B("Fallback") .. ": RestedXP's original Fast route, in its own folder of the guide list; " .. B("/xpg fallback") .. " switches. It starts by itself if a guide cannot be loaded.",
  "- " .. B("Difficulty") .. ": Casual, Medium or Hard decides which quests stay in the route.",
  "- " .. B("Guide window") .. ": the step you are on with tick boxes and icons, steps on the way, every step in a list.",
  "- " .. B("Arrow") .. ": its own, or pfQuest's arrow, routed by pfQuest SmartArrow when it is installed.",
  "- " .. B("Auto mode") .. ": takes and hands in the route's quests, flights, hearthstone, selling and repairs.",
  "- " .. B("Helpers") .. ": warnings for dangerous mobs and caves, quest chains, enemy difficulty on tooltips.",
  "- " .. B("Mob markers") .. ": left of the level on nameplates, a skull (kill), a sack (drops what you need), ! (gives the step's quest), ? (takes it back); a chain quest's shape sits behind.",
  "- " .. B("Picking a guide") .. ": the Guides page of Settings; at a guide's top level the tips box asks whether to move on to the next one.",
  "- " .. B("Settings") .. ": one window with eight tabs: Guides, Configuration, Character, Auto mode, Helpers, Advanced, Usage and Features (this).",
  " ",
  GOLD .. "Change history" .. END,
  B("2.1.0") .. GREY .. " - pfQuest-xpGuide, settings per character, pfQuest's markers, starting where you are" .. END,
  "- Renamed: the folder is pfQuest-xpGuide. Delete the old pfQuest_xpGuide folder; rename its settings file (WTF\\Account\\<account>\\SavedVariables\\pfQuest_xpGuide.lua to pfQuest-xpGuide.lua) to keep your settings.",
  "- Changed: settings are per character; each character's first login copies the account's once.",
  "- Changed: pfQuest's markers by default; Settings -> Helpers -> Use xpGuide's own markers for the guide's.",
  "- Changed: a guide started on a character that has played starts where it is (quests recorded as handed in, or your level), and says why.",
  "- New: each guide begins with what it needs from the guides before it (done ones pass by themselves), so starting part-way never leaves a quest unoffered.",
  "- Changed: the High Elf and Goblin starting guides are in their side's 1-20 folder, and each folder's guides are listed by level.",
  "- Changed: the High Elf guides are 1-6 Quel'Thalas Gate (level 6 before Veloren Brightstar) and 6-11 Alah'Thalas.",
  "- Fixed: the starting guides no longer give quests more than 1 level above you (a reach-level step comes first).",
  "- Fixed: a class trainer visit when a guide starts at an even level, and a trip to a trainer that stands off the route.",
  "- Fixed: a quest too hard for you no longer drops out on its own: the step waits (take it anyway, or Skip step).",
  " ",
  B("2.0.3") .. GREY .. " - starting guides in rounds, auto pick-ups, first start, arrow" .. END,
  "- Changed: the High Elf and Goblin starting guides go in rounds, as RestedXP's: pick up everything at a hub (and the hubs close by), do all the objectives in one step, then hand them all in.",
  "- Changed: Take and hand in quests takes only the step's quests (the next steps' only from the step's own NPC), not those of a quest giver standing beside it.",
  "- New: a character's first start asks your experience rate and professions before the guide starts.",
  "- Changed: pfQuest's arrow is the default when your pfQuest has one and it is on; otherwise the guide's own.",
  "- Fixed: Hand in, then move on also keeps the quests the next guide needs first (Message for the Windrunner before The Silver Covenant); a quest started by a dropped item points the arrow at the creature.",
  "- New: /xpg moveon asks the move-on question now, to try it without playing to the guide's top level.",
  "- Changed: Move on now also keeps what the next guide needs first (not your other finished quests), then starts it by itself.",
  "- Fixed: a quest the Alah'Thalas guide offered at level 5 could be skipped when you came in at level 4.",
  " ",
  B("2.0.2") .. GREY .. " - trainers, vendors, hand-ins before moving on, hearthstone fix" .. END,
  "- New: a step at your class trainer every 4 levels and at a vendor (sell junk, food and water, repair from 10) every 3 levels, where the route passes one; the arrow points at them.",
  "- Changed: the move-on question lists the finished quests to hand in first; Hand in, then move on takes you to each, then starts the next guide.",
  "- Changed: profession training is only suggested where the route passes a trainer of your side, with the trainer's name and place (the arrow points at it), for the rank you can learn now. No more \"learn it\" without saying where.",
  "- Changed: a skill-up no longer reads the guide again unless it reaches the skill for the next rank.",
  "- Fixed: after a hearthstone the guide could skip a hand-in and its follow-up (a quest missed from the log for a moment was taken for handed in).",
  "- Changed: pfQuest-turtle's sword and bag on nameplates sit next to the level, where ours would be (unless you set their position).",
  " ",
  B("2.0.1") .. GREY .. " - High Elf start, move-on question, map markers" .. END,
  "- Fixed: the High Elf start missed A Letter from the Royalty (from the Feltouched Letter), so the next quests were not offered yet.",
  "- Fixed: the move-on question waits until this guide's hand-ins of quests you carry are done.",
  "- Fixed: with pfQuest-turtle's own nameplate icons on, ours leave kill and loot to them (no two markers on one mob).",
  "- Fixed: no second marker on pfQuest's map where pfQuest already marks the spot.",
  " ",
  B("2.0.0") .. GREY .. " - one route, with a fallback" .. END,
  "- The xpGuide Fast route is the addon's guide, made whole offline. RestedXP's original stays as the fallback (/xpg fallback).",
  "- Retired: the Casual route, xpGuide Fast, Bethink's Guide and VanillaGuide. A character saved on one moves on to the xpGuide Fast route.",
  "- New: /xpg report, and an Advanced page in Settings (the rarely used switches, the fallback switch, the report).",
  "- Fixed: abandoning a quest whose chain goes on in the next guide; going back by hand to a step you walked away from.",
  " ",
  B("1.2.0") .. GREY .. " - Fast route default, Experimental Guides" .. END,
  "- The Fast route is the default guide: a new character starts it, and it is the first suggestion.",
  "- xpGuide Fast, Bethink's Guide and VanillaGuide moved into the Experimental Guides folder of the guide list.",
  "- New, under Experimental Guides: the xpGuide Fast route, RestedXP's Fast route with the xpGuide Fast options (1x or 2x quests, professions).",
  "- The xpGuide Fast route has starting guides for High Elves (Quel'Thalas, Alah'Thalas) and Goblins (Blackstone Island).",
  "- A guide whose next guide is not for you goes on to the next one of the same route that fits your level.",
  " ",
  B("1.1.4") .. GREY .. " - crash and arrow fix" .. END,
  "- Fixed: the game crashed (no Lua error) when you picked a guide since 1.1.3. The Features page grew past 4096 bytes, more than the game's font string can hold; the page is now set in several parts.",
  "- The Fast guide question (rate and professions) now opens a moment after you click the guide, and the guide starts a moment after you click Start, not inside the clicks (the game crashed there on one client). /xpg fastsetup opens it directly.",
  "- Picking a Fast guide no longer opens and folds the skill window's headers to read your professions (it could crash the game); professions come from the skill list and the spellbook.",
  "- The sack marker on nameplates now covers up to 12 creatures that drop a quest item (not 3), so Young Wolves are marked too.",
  "- The guide's own arrow is now the default. pfQuest's arrow is opt-in: Settings -> Helpers -> Use pfQuest's arrow, the arrow button under the guide window, or /xpg pfarrow.",
  "- The arrow for a quest to finish points at the target nearest to you in the zone the guide has you in, not at the middle of all of them.",
  "- The arrow for a quest to finish now stays in the zone the guide has you in: a quest whose data names its targets only in another zone (Finish Wolves Across the Border used to point to Dun Morogh) points at its hand-in instead.",
  " ",
  B("1.1.3") .. GREY .. " - pfQuest arrow fix" .. END,
  "- pfQuest's arrow now follows the guide on a step whose place is also a quest's own hand-in or giver spot (Finish Wolves Across the Border used to point to Dun Morogh).",
  " ",
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
