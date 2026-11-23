# pfQuest xpGuide

A leveling guide for World of Warcraft 1.12 (Turtle WoW, OctoWoW and other vanilla servers), made for pfQuest players. It
shows the step you are on, every step of the guide and an arrow.

It has one route, the **xpGuide Fast route**: RestedXP's leveling order with options of its own (1x or 2x experience, your
professions), and starting guides for High Elves and Goblins. **RestedXP's original Fast route** stays in the addon as the
fallback, for when something goes wrong with the xpGuide Fast route.

Version 2.0.0 retired the other guides (the Casual route, xpGuide Fast, Bethink's Guide and VanillaGuide). They are kept in the
repository's history: tag `v1.2.0`.

pfQuest xpGuide is based on Easy Route (see Credits), renamed and reworked. See `CHANGES.md` for what changed.

## Install

Put the `pfQuest-xpGuide` folder in `Interface\AddOns` and restart the game. The folder name has to stay `pfQuest-xpGuide`
(the same naming as pfQuest's other extensions, such as pfQuest-turtle).

- **From a release:** download the zip of the latest release and extract it into `Interface\AddOns`. The zip already holds a
  `pfQuest-xpGuide` folder.
- **From git:** `git clone <this repository's URL> pfQuest-xpGuide` inside `Interface\AddOns`, and `git pull` to update. If an
  update adds a file, close the game completely and start it again.
- **Coming from a version before 2.1.0** (folder `pfQuest_xpGuide`): delete the old `pfQuest_xpGuide` folder. To keep your
  settings, rename `WTF\Account\<account>\SavedVariables\pfQuest_xpGuide.lua` to `pfQuest-xpGuide.lua` with the game closed.
  Each character then takes a copy of those settings on its first login: from 2.1.0 settings are per character.

**Coming from Easy Route?** Remove the `EasyRoute` folder. pfQuest xpGuide keeps its settings separately and starts fresh
(your settings, ratings and progress from Easy Route do not carry over).

## The guide window

The window is laid out the way RestedXP Guides lays out its own. From the top:

- **The step box.** The step you are on.
  - **At the top:** the guide's name, its group and the experience rate (or the difficulty on RestedXP's original),
    and the **Skip step** button, which skips the step in one click. On steps you tick yourself it reads **Mark done**.
  - **Under that:** one line per thing to do, each with a tick box (ticked when it is done) and an icon for what it is:
    pick up, hand in, kill, talk, fly, and so on.
  - **Unskip previous** appears beside Skip step right after you skip, and takes you back to the step you skipped,
    along with the chain quests and steps that were left out with it.
  - A step whose quest is finished (complete in your log, waiting to be handed in) cannot be skipped: its button reads
    **Finished**.
  - **Hints:** a "Finish" or "Hand in" step with no instructions of its own shows the quest's short hint from your
    quest log ("Bring the Partially Filled Vessel to Corithras Moonrage in Dolanaar.").
  - **Needs level N:** a step that picks up a quest above your level says so in red, so you grind nearby first.
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

## The xpGuide Fast route

RestedXP's Fast route (1-60, both factions), with these options:

- **A character's first start** asks the same before the guide starts (Skip starts it with the settings as they are).
- **Picking a guide** (Settings -> Guides) asks for **1x or 2x experience** (1x is the default) and your professions: the two
  primary professions suggested for your class are ticked, and the ones you have show your skill. The same answers are on
  Settings -> Character, and `/xpg xp 1` / `/xpg xp 2` and `/xpg prof Cooking on` set them from chat. The window's heading
  shows the rate.
- **2x** keeps, in each guide, the quests of the highest level until about half of its quest experience, with the quests
  before them in their chain (about two thirds of the pick-ups). 1x keeps all of RestedXP's quests.
- **Professions:** a step at a profession trainer only where the route passes one of your side, with the trainer's name and
  place (the trainers come from the Tortoise-WoW database, `tools/trainers.json`). It shows for the professions you have or
  ticked, while the rank that trainer teaches is the one for you to learn now (Apprentice, then Journeyman, Expert and Artisan
  once your skill is high enough), and goes away once you have learned it. RestedXP's route already sends you to your class
  trainer.
- **Trainers and vendors:** a step at your class trainer every 4 levels and a vendor stop (sell your junk, buy food and water,
  repair from level 10) every 3 levels, where the route passes one of your side, with the arrow on them (from the Tortoise-WoW
  database, `tools/services.json`).
- **What a guide needs from the ones before:** a guide begins with the steps of the quests its own quests need from earlier
  guides (the game's prerequisites); done ones pass by themselves, so it matters only when you start part-way.
- **Moving on:** at a guide's top level the tips box asks whether to move on, and lists the finished quests the guide still hands
  in; "Hand in, then move on" takes you to each of them, then starts the next guide.
- **Difficulty:** Casual and Medium leave out elite quests, Hard keeps them.
- **High Elves and Goblins** (Turtle WoW) get starting guides of their own, which RestedXP has none for: "1-6 Quel'Thalas Gate"
  and "6-11 Alah'Thalas" (then RestedXP's route from Darkshore), and "1-11 Blackstone Island" (then the Barrens). A new High
  Elf or Goblin starts its own guide; the places come from pfQuest-turtle's data. They go in rounds, as RestedXP's guides do:
  pick up everything at a hub and the hubs close by, do all the objectives in one step, then hand them all in. A quest comes
  when you are at most 1 level below it, with a "reach level" step before it where needed. They are listed in the Alliance 1-20 and Horde 1-22 folders, by level.
- Each guide goes on to the next guide of the route by itself.

The whole route is made offline by `tools/build_fastroute.py` into `Data/FastRoute.lua` (see Development).

### The fallback: RestedXP's original

RestedXP's Fast route as RestedXP made it is in the guide list too, in the folder **RestedXP's original (fallback)** at the
end of the group list. Every xpGuide Fast route guide has its original there, under the same name.

- `/xpg fallback` (or **Switch to fallback** on Settings -> Advanced) switches the guide you follow to its RestedXP original,
  and back. It starts part-way: what your quest log shows as done is ticked off.
- When an xpGuide Fast route guide cannot be loaded, its RestedXP original starts by itself, with a chat line.
- When errors keep coming while you follow the xpGuide Fast route (three in a session), the addon offers the fallback in
  chat, and RestedXP's originals become the first suggestion.
- A character saved on a retired guide (the Casual route, xpGuide Fast, Bethink's Guide, VanillaGuide) moves on to the
  xpGuide Fast route guide for its level at login, with one chat line.

## Commands

`/xpg` shows or hides the guide window. `/xpg help` opens the Usage tab of Settings, which lists the rest, for example:

| Command | What it does |
|---|---|
| `/xpg arrow` | Show or hide the arrow. |
| `/xpg pfarrow` | Use pfQuest's arrow or the guide's own (pfQuest's when it has one and it is on, by default). |
| `/xpg font <size>` | Text size; `/xpg font pfquest` follows pfQuest's. |
| `/xpg xp [1\|2]` | Experience rate for the xpGuide Fast route (1x is the default). |
| `/xpg prof [name on\|off]` | Professions the guide plans for. |
| `/xpg fallback` | Switch between the xpGuide Fast route guide and RestedXP's original. |
| `/xpg report` | What the addon sees (race, zone, guide, addons), for a bug report; also kept in the saved file. |
| `/xpg moveon` | Asks the move-on question now (a test: it does not wait for the guide's top level). |
| `/xpg features` | The Features tab of Settings: main features and change history. |
| `/xpg theme` | Use pfUI's look or pfQuest xpGuide's own (after `/reload`). |
| `/xpg selftest` | Check that everything is in order. |

## Dependencies

None are required. These are optional and picked up when installed:

- **pfQuest** (lightblade's, brues-code's, pfQuest-turtle): quests, map markers and pfQuest's arrow.
- **pfQuest SmartArrow**: when it is on, it plans the way to each step (zone exits, flight paths, boats, roads), in
  pfQuest's arrow.
- **pfQuest-turtle**: its markers are the ones shown by default (pfQuest's on the map, its sword and bag on nameplates, moved
  next to the level). The guide's own markers, described below, come with Settings -> Helpers -> "Use xpGuide's own markers".
- **pfUI**: the windows take pfUI's colours, font and borders, and the guide's own quest mob markers on nameplates become small
  smooth accent skulls (bright for the current step's mobs, softer for the rest of the quest log). Without pfUI they are gold skulls.
  Either way the markers sit left of the level: a skull on mobs to kill, a sack on mobs that drop what a quest needs,
  ! on who gives the step's quest and ? on who takes it back. For a chain quest the chain's shape from the step list
  sits behind the marker in the chain's colour (the marker keeps a thin dark border; neither covers the level). With
  lightblade's pfQuest-turtle and its "Show Quest Icons on Nameplates" on, its sword and bag mark the kill and loot mobs and
  ours keep only ! and ?.

## Credits and licence

- **The addon's code** is MIT licensed (`LICENSE`), as Easy Route's is. The guide data below has its own licences.
- **Easy Route**, the addon pfQuest xpGuide is built on, was made by
  **[stealthzi](https://octowow.st/git/stealthzi)**: https://octowow.st/git/stealthzi/EasyRoute
- **Quest experience.** The 2x choice uses the 1.12 quest experience from classicdb.ch (`tools/classicdb_quest_xp.json`).
- **Quest data.** Quest levels, chains and the danger marks (`Data/Zones.lua`, `Data/Danger.lua`) come from the pfQuest,
  pfQuest-turtle and pfExtend data and from CMaNGOS classic-db. The High Elf and Goblin starting guides are built from
  pfQuest-turtle's quest and NPC data (MIT License, Copyright (c) 2021 Eric Mauser (Shagu)).
- **Testing.** Thanks to Nonnally for helping test Easy Route.
- **Guide data.** The Fast route guides (RestedXP's original and the xpGuide Fast route made from it), the danger marks' quest
  order and the Survival Guide notes come from RestedXP Guides (https://github.com/RestedXP/RXPGuides). They are used under the Creative Commons Attribution-NonCommercial-ShareAlike
  4.0 licence, and those data files are shared under the same licence.
- **Retired guides.** Versions up to 1.2.0 also had Bethink's Guide (GPLv3) and VanillaGuide's guides; they are not in 2.0.0
  (see tag `v1.2.0` for them and their credits).
- **The guide window's layout** follows RestedXP Guides. No RestedXP code, textures or logos are used. The icons in
  `Media` are drawn for this addon (`tools/icons.py`), and the nameplate skull is the game's own raid icon.

## Development

The headless tests (`tests/`, run under `texlua` from TeX Live), the data tools (`tools/`) and the release workflow (`.gitea/`)
are in the repository, not in the release zip.

- **Tests:** from the repository folder, `texlua tests/run.lua . Human WARRIOR 1 casual`. `tests/README.md` lists them.
  The harness fails on what crashes the real client: a text of more than 4096 bytes, and (in `tests/limits.lua`) frames or
  textures built inside the clicks that pick or start a guide.
- **Data:** `tools/rebuild.sh` rebuilds `Data/FastRoute.lua` from what is checked in; `tools/rebuild.sh --fetch` first fetches
  pfQuest and pfQuest-turtle at the commits pinned in `tools/sources.txt` and dumps the starting guides' quests again. The same
  inputs give the same files, byte for byte.
- **Release zip:** `tools/make_zip.sh [tag]` builds `dist/pfQuest-xpGuide-<version>.zip` from a commit with `git archive`
  (tests, tools and `.gitea` are left out). `.gitea/workflows/release.yml` does the same when a release is published and
  attaches the zip to it; it needs a Gitea Actions runner and a repository secret `RELEASE_TOKEN` (see the file).
