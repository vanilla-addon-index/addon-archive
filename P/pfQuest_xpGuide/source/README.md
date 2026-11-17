# pfQuest xpGuide

A leveling guide for World of Warcraft 1.12 (Turtle WoW, OctoWoW and other vanilla servers), made for pfQuest players. It
shows the step you are on, every step of the guide and an arrow.

There are two routes:

- **Casual route:** one zone at a time, at an easy pace.
- **Fast route:** RestedXP's leveling order.

pfQuest xpGuide is based on Easy Route (see Credits), renamed and reworked. See `CHANGES.md` for what changed.

## Install

Put the `pfQuest_xpGuide` folder in `Interface\AddOns` and restart the game. The folder name has to stay `pfQuest_xpGuide`.

- **From a release:** download the zip of the latest release and extract it into `Interface\AddOns`. The zip already holds a
  `pfQuest_xpGuide` folder.
- **From git:** `git clone <this repository's URL> pfQuest_xpGuide` inside `Interface\AddOns`, and `git pull` to update. If an
  update adds a file, close the game completely and start it again.

**Coming from Easy Route?** Remove the `EasyRoute` folder. pfQuest xpGuide keeps its settings separately and starts fresh
(your settings, ratings and progress from Easy Route do not carry over).

## The guide window

The window is laid out the way RestedXP Guides lays out its own. From the top:

- **The step box.** The step you are on.
  - **At the top:** the guide's name (on the Casual route, the zone and how far you are in it), its route and difficulty,
    and the **Skip step** button, which skips the step in one click. On steps you tick yourself it reads **Mark done**.
  - **Under that:** one line per thing to do, each with a tick box (ticked when it is done) and an icon for what it is:
    pick up, hand in, kill, talk, fly, and so on.
  - **Unskip previous** appears beside Skip step right after you skip, and takes you back to the step you skipped,
    along with the chain quests and steps that were left out with it.
  - A step whose quest is finished (complete in your log, waiting to be handed in) cannot be skipped: its button reads
    **Finished**.
  - **Hints:** a "Finish" or "Hand in" step with no instructions of its own shows the quest's short hint from your
    quest log ("Bring the Partially Filled Vessel to Corithras Moonrage in Dolanaar.").
  - **Helpers:** the guide's warnings and helpers sit under the lines: the hearthstone button, how hard the quest is,
    and the next guide when this one is finished.
- **On the way.** Steps you can do on the way, in a second box.
- **The step list.** Every step of the guide, each with a tick box.
  - The step you are on is marked. Steps behind you that were completed are ticked with a grey title; steps that were
    skipped (by you, or passed over by the guide) show a » skip mark and an amber title.
  - A quest you abandon has its steps passed over (skip mark), and so do the later quests of its chain. Its pick-up step
    becomes a button in the list ("Click to go back and pick it up again"): one click goes back there, with the arrow on
    the quest giver. Pick it up again and the guide goes back to its steps and its chain by itself. A quest you skip
    gets a button too ("Click to go back and do it"), at the top of a skipped chain only. The list keeps the newest button
    in view, and the footer says how many there are ("2 steps to go back to"; click it to show them). A quest that the
    game would no longer offer, or that has gone grey, is skipped for good instead.
  - Each quest chain has its own line, shape and colour (colour-blind friendly). The line runs in a narrow lane between
    the tick boxes and the step text, unbroken from the chain's first step to its last, with the chain's shape on it at
    each of its steps, so chains the guide goes back and forth between stay easy to follow, in the guide's own order.
    Point at a step and the other steps of its chain light up, along with its whole line. The tooltip names the chain,
    its shape and the part.
  - As the guide moves on, the list follows, keeping the last 3 done steps in view above the current one. When you tick
    or skip a step yourself, the list stays where it is.
  - Tick a later step to skip it (untick it to do it after all), and untick a step behind you to go back to it.
  - Scroll with the mouse wheel.
  - Right-click or double-click a step for its menu: go to it, or skip its quest.
- **The footer.**
  - Small, smooth line icons with no borders, set a few pixels in from the window's edges and below the list's border;
    each lights up in the accent colour under the mouse.
  - Left: the **cog** opens Settings (the Guides page is where you pick a guide). The **arrow** switches between pfQuest's arrow, the guide's
    own arrow and no arrow; it is dimmed when the arrow is off.
  - Right: **x** hides the window (`/xpg` brings it back), the **padlock** locks it in place and size, and the
    **corner grip** resizes it. Make it wider for longer lines, or taller to list more steps.

Drag the step boxes, the list or the footer to move the window. Its place and size are saved.

**Text size.** The guide's text uses pfQuest's font at the size of pfQuest's quest tracker ("Quest Tracker Font Size"),
so it reads like pfQuest's own lists. Change it in **Settings → Configuration → Text size**: a left arrow, the size, and a right
arrow, as when splitting a stack in your bags. Click the number to follow pfQuest again. `/xpg font 14` and
`/xpg font pfquest` do the same from chat. List rows grow with the text.

## xpGuide Fast guides

A fast 1-60 route of my own for each faction, listed as "xpGuide Fast Alliance" or "xpGuide Fast Horde". It follows your class (class trainer every ten
levels, class-only quests), your professions (First Aid, Cooking, Fishing, Survival and the nine primary ones) and your race.
When you pick one from the guide list a small window asks for **1x or 2x experience** (1x is the default) and your professions: the
two primary professions suggested for your class are ticked, and the ones you have show your skill. 2x keeps the quests that give the most experience, about half of each
zone's quest experience, 1x keeps them all. The window's heading shows the rate. The same answers are on Settings -> Character, and
`/xpg xp 1` / `/xpg xp 2` and `/xpg prof Cooking on` set them from chat. Difficulty works on these guides too (Casual and Medium
leave out elite quests, Hard keeps them). Survival has no trainer data, so its steps are generic. Built by `tools/build_fast.py`.

## Commands

`/xpg` shows or hides the guide window. `/xpg help` opens the Usage tab of Settings, which lists the rest, for example:

| Command | What it does |
|---|---|
| `/xpg arrow` | Show or hide the arrow. |
| `/xpg pfarrow` | Use pfQuest's arrow or the guide's own. |
| `/xpg font <size>` | Text size; `/xpg font pfquest` follows pfQuest's. |
| `/xpg xp [1\|2]` | Experience rate for the xpGuide Fast guides (1x is the default). |
| `/xpg prof [name on\|off]` | Professions the Fast guides plan for. |
| `/xpg features` | The Features tab of Settings: main features and change history. |
| `/xpg theme` | Use pfUI's look or pfQuest xpGuide's own (after `/reload`). |
| `/xpg selftest` | Check that everything is in order. |

## Dependencies

None are required. These are optional and picked up when installed:

- **pfQuest** (lightblade's, brues-code's, pfQuest-turtle): quests, map markers and pfQuest's arrow.
- **pfQuest SmartArrow**: when it is on, it plans the way to each step (zone exits, flight paths, boats, roads), in
  pfQuest's arrow.
- **pfUI**: the windows take pfUI's colours, font and borders, and the quest mob markers on nameplates become small
  smooth accent skulls (bright for the current step's mobs, softer for the rest of the quest log). Without pfUI they are gold skulls.
  Either way the markers sit left of the level: a skull on mobs to kill, a sack on mobs that drop what a quest needs,
  ! on who gives the step's quest and ? on who takes it back. For a chain quest the chain's shape from the step list
  sits behind the marker in the chain's colour (the marker keeps a thin dark border; neither covers the level).

## Credits and licence

- **The addon's code** is MIT licensed (`LICENSE`), as Easy Route's is. The guide data below has its own licences.
- **Easy Route**, the addon pfQuest xpGuide is built on, was made by
  **[stealthzi](https://octowow.st/git/stealthzi)**: https://octowow.st/git/stealthzi/EasyRoute
- **Quest experience.** The Fast guides' 2x choice uses the 1.12 quest experience from classicdb.ch (`tools/classicdb_quest_xp.json`).
Quest data.** The Casual route's quests, places and travel come from the pfQuest, pfQuest-turtle and pfExtend data
  and from CMaNGOS classic-db.
- **Testing.** Thanks to Nonnally for helping test Easy Route.
- **Guide data.** The Fast route guides, the Casual route's quest order and the Survival Guide notes come from RestedXP
  Guides (https://github.com/RestedXP/RXPGuides). They are used under the Creative Commons Attribution-NonCommercial-ShareAlike
  4.0 licence, and those data files are shared under the same licence.
- **Bethink's Guide.** The "Bethink's Guide" groups are Bethink's Guidelime guides (Guidelime_Bethink 1.0.8,
  Copyright (c) 2026 Bethink), licensed under the GNU General Public License version 3: see `LICENSE-Bethink.txt`.
  Changed from the original: converted from Guidelime's format into this addon's (one step per line, Bethink's words
  kept, quest tags turned into names), steps for primary professions left out. The data file is `Data/Bethink.lua`;
  the converter (`tools/build_bethink.py`) is in the repository. Bethink's guides were written with QuestieDB reference data
  (thanks to the QuestieDB and Questie contributors).
- **VanillaGuide.** The "VanillaGuide" groups are the guides from VanillaGuide (VanillaGuide Enhanced): Joana's
  (Joana/Mancow) and Brian Kopps' leveling guides, as written up for the VanillaGuide addon by rsheep, mrmr and Lanjelin.
  Changed from VanillaGuide's tables: one step per stop (a line that sends you on, "turn in A, then run up the tree and
  hand in B", is a step per stop, and what is taken after a hand-in is a step of its own), each step a short action line
  ("Hand in X", "Accept Y", "Finish Z"; a step with no quest is named by its first clause) with the guide's words
  (colour tags turned into colours) as a tip under it, left out where they only repeat the action line, and quest names
  matched to quest numbers so the steps follow your quest log. Steps the guide's authors had commented out are left out. The data file is `Data/VanillaGuide.lua`; the
  converter (`tools/build_vanillaguide.py`) is in the repository. No licence came with VanillaGuide.
- **The guide window's layout** follows RestedXP Guides. No RestedXP code, textures or logos are used. The icons in
  `Media` are drawn for this addon (`tools/icons.py`), and the nameplate skull is the game's own raid icon.

## Development

The headless tests (`tests/`, run under `texlua` from TeX Live) and the data converters (`tools/`) are in the repository, not in the
release zip. From the repository folder: `texlua tests/run.lua . Human WARRIOR 1 casual`. `tests/README.md` lists the tests;
`tools/` has the converters for the Bethink and VanillaGuide data and the generator for the textures in `Media`.
