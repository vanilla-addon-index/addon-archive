# Ashen Builds

An all-class gear and talent planner for **Turtle WoW** (1.12 client), by The Ashen Banner & Claude AI

Plan a character with any class, race and level. Equip items from an embedded database of every
equippable Turtle WoW item, add enchants, spend talents, and see character-sheet totals calculated
the same way the game server does. Share builds with the whole realm and upvote the good ones.

## Install

1. Delete any existing `Interface\AddOns\AshenBuilds` folder.
2. Copy the `AshenBuilds` folder into `Interface\AddOns\`.
3. Fully restart Turtle WoW (don't just `/reload` after replacing files).

Type `/ab` in game, or click the ember icon on the minimap.

## Features

### Planner
- Any class, race (including High Elf and Goblin) and level 1–60.
- A new plan starts as your character (class, race and level) and follows your level until you change
  it or add gear. Each character keeps its own plan open in the planner.
- 19 equipment slots with item tooltips that match the game, including set pieces and set bonuses.
- **Character totals** use the real vanilla base stats for every class, race and level, plus the
  vmangos formulas that BetterCharacterStats reads back from the client: health and mana from stamina
  and intellect, level-scaled crit and dodge per agility, class base crit and dodge, 5% base parry and
  block, defense and weapon-skill bonuses, armor from agility, racials, and measurable talent effects.
- Hover any total for a breakdown of where it comes from (base, gear, talents, racials).
- **Model preview:** switch the center panel to a 3D model wearing the planned gear. Drag to turn,
  scroll to zoom. It uses your own character's race, and only items your game client has cached.
- **Saved builds** save automatically once saved the first time. Rename, delete, or use Save As to make
  a copy. Export and import builds as short codes, including talents.

<img width="990" height="912" alt="image" src="https://github.com/user-attachments/assets/b4555ee9-e21c-49be-8368-4eada29d543b" />


### Item database
- Every equippable item, searchable by name, NPC or zone.
- **Usable at build level** (on by default) hides items above the build level, quest rewards from
  quests above it, and armor or weapons the class can't use yet (plate and mail at 40, dual wield).
- Dropdown filters for slot, armor type (cloth, leather, mail, plate), source (dungeon, raid, quest, world boss, crafted, reputation, PvP, world
  drop, vendor), quality and sort order, plus an item level range and up to four stat filters with
  minimum values.
- Filtering is near-instant: items are indexed in the background right after login.
- Right-click an item for its full sources: drops with chances, vendors, quests and crafting recipes.

<img width="1089" height="863" alt="image" src="https://github.com/user-attachments/assets/a561d749-fc8a-41a9-b3a1-3406a1da6dd8" />


### Enchants
- 263 enchants generated from the Turtle WoW database, including Turtle's custom enchants
  (Invocations, Sigils, spell penetration and vampirism bracers, and more).
- Rings and necklaces take jewelcrafting gemstones; belts take blacksmithing buckles.
- Two-hand, shield and item-level restrictions are enforced.
- Search, filter by stat (sorted by value), and lower ranks hidden unless you ask for them.

<img width="1208" height="881" alt="image" src="https://github.com/user-attachments/assets/8f8c6a89-65ca-47ea-a9e9-11292c322243" />

### Talents
- All 27 Turtle WoW talent trees with full descriptions, rank limits, row requirements and prerequisites.
- Talents that change the character sheet are applied to your totals.

<img width="1318" height="859" alt="image" src="https://github.com/user-attachments/assets/885861ac-17c0-4844-bb14-944953094f61" />

### DPS simulator (Warrior)
- Click **SIM DPS** under the trinket slots. A progress bar fills while the fights run (spread over
  frames, so the game never freezes). Then the average DPS and its 95% confidence range appear.
- Hover the result for the full breakdown: damage by ability, attack table, rage generated, spent and
  wasted, casts, procs and buff uptimes. Shift-click it for one fight's combat log.
- The gear button next to SIM DPS holds the settings for each class: fight length, target level and
  armor, position, number of targets, iterations, reaction time, rotation preset, Heroic Strike rage
  threshold, raid buffs, consumables and target debuffs.
- Every fight uses a fixed seed, so re-simming after a gear change compares the same fights and the
  tooltip shows the exact DPS change.
- Arms, Fury (dual-wield and two-hand) and Protection rotations, including Shield Slam, Revenge
  (with the boss hitting you), Slam and Overpower. Set bonuses and weapon procs are included.
- **Accuracy** is HIGH only when every equipped effect is simulated. Anything that isn't (for example
  on-use trinkets) is listed as *SIM EFFECT NOT IMPLEMENTED* and the result is marked PARTIAL.
- Mechanics come from Turtle's server data where possible and otherwise from the maintained Turtle
  WarriorSim. The combat log window lists the source and status of each one.

<img width="725" height="793" alt="image" src="https://github.com/user-attachments/assets/109cec74-3382-4245-98a1-eb3c46b7f7d0" />

### Community builds
- Publish a saved build and every player on the realm running Ashen Builds can see, load and upvote it.
- Builds and votes are shared player-to-player over a hidden realm channel plus guild, party and raid.
  They persist while the author or voters are offline, and new players catch up when they log in.
- Builds with offensive names are not listed. Right-click a build to hide every build from that
  player (`/ab unhide <player>` shows them again).

**What is shared.** To sync, the addon joins a hidden chat channel called `AshenBuilds` and also
uses guild, party and raid addon messages. When you publish a build, your character name is sent
with it, together with the build's name, gear, enchants and talents, and your upvotes carry your
character name too. Nothing is sent until you publish or vote, apart from short "what do you have?"
sync requests. `/ab sync off` stops using the channel (useful if you are at the ten-channel limit)
and syncs over guild and party only.

<img width="945" height="702" alt="image" src="https://github.com/user-attachments/assets/0703cb20-68dd-491e-b926-4f5fba998cf3" />

## Controls

| Action | How |
|---|---|
| Open or close the planner | `/ab`, or left-click the minimap button |
| Choose an item | Click a gear slot |
| Remove an item | Right-click a gear slot |
| Choose an enchant | Click the enchant line under the item name (or Shift-click the slot) |
| Add or remove a talent point | Left-click or right-click a talent |
| Load a saved or community build | Click it in Saved Builds or Community |
| Upvote a community build | Click the arrow in the Votes column |
| Move the minimap button | Drag it around the minimap |

The top bar has five tabs: Planner, Talents, Community, Saved Builds and Item Database. They all
open inside the main window. Clicking a gear slot opens the Item Database for that slot, and picking
an item (or loading a saved build) takes you back to the Planner.

## Slash commands

| Command | Does |
|---|---|
| `/ab` | Open or close the planner |
| `/ab community` | Open community builds |
| `/ab importgear` | Load the gear you are wearing into the planner |
| `/ab minimap` | Hide or show the minimap button |
| `/ab reset` | Start a fresh build |
| `/ab sim` | Simulate the current build |
| `/ab sim settings` | Open the simulator settings |
| `/ab sim log` | One fight's combat log from the last run |
| `/ab sync on` / `off` | Use the hidden realm channel for community builds, or guild and party only |
| `/ab sync status` | Show whether you are in the realm channel and which Ashen Builds players you have heard from |
| `/ab unhide <player>` | Show community builds from a player you hid |

## For developers

- **Client:** WoW 1.12 runs Lua 5.0. Use `table.getn`, `math.mod` and `string.gfind`, and avoid `#`,
  the `%` operator and `string.match`.
- **Text boxes:** `InputBoxTemplate` edit boxes must be created with a global name, or their border
  textures anchor to the wrong box.
- **Data regeneration.** Every script in `tools/` reads the Tortoise DB snapshot of Turtle's server
  data (`tortoise.sqlite`); downloads and work files go to `tools/work/`, which git ignores.

  | Script | Writes |
  |---|---|
  | `python tools/build_ashendb.py` | Item database in `Data/AshenDB/Data/` (downloads the snapshot; `--database` uses a local copy) |
  | `python tools/rebuild_compact_sources.py tortoise.sqlite .` | Item drop/vendor/quest sources |
  | `python tools/rebuild_set_catalog.py tortoise.sqlite Data/SetCatalog.lua --data-version VERSION` | Item sets and their bonuses |
  | `python tools/build_enchants.py --database tortoise.sqlite` | `Data/Enchants.lua` (IDs 1–90 are frozen because build codes use them; new enchants are 100000 + spell ID) |
  | `python tools/build_set_effects.py tortoise.sqlite` | Set bonus effects for the simulator, in `Sim/SimItems.lua` |

  Run `rebuild_set_catalog.py` before `build_set_effects.py`, since the second reads the catalog.
- **Base stats** in `Data/BaseStats.lua` come from the vanilla `player_levelstats` and
  `player_classlevelstats` tables.

- **Troubleshooting commands:** `/ab debug` (loaded item, set and source counts),
  `/ab debugset <itemID>` (how an item's set is resolved), `/ab model probe [slot]` and
  `/ab model undress` (3D preview diagnostics).
- **Tests:** `python tests/run.py` runs every suite in `tests/` against the addon inside a stub of
  the WoW API (needs `pip install lupa`). CI also compiles every file with Lua 5.0, the client's
  version, so 5.1-only syntax is caught.

### Code layout

| File | Contents |
|---|---|
| `Core.lua` | Builds, saving, import/export, stat engine, slash commands |
| `ItemIndex.lua` | Item database search index |
| `UI.lua`, `Widgets.lua`, `Theme.lua` | Planner windows, dropdowns and dialogs, ember styling |
| `TalentEngine.lua`, `TalentUI.lua` | Talent rules, talent codes, talent window |
| `Community.lua`, `CommunityUI.lua` | Build sharing and voting, community window |
| `Profanity.lua` | Build name filter |
| `Minimap.lua` | Minimap button |
| `Sim/SimCore.lua` | Shared simulation engine: seeded RNG, event queue, auras, results, frame-spread runner |
| `Sim/SimItems.lua` | Chance-on-hit item and enchant effects shared by melee classes |
| `Sim/SimWarrior.lua` | Warrior character bridge, attack table, rage, abilities, rotations |
| `Sim/SimUI.lua` | SIM DPS button, result tooltip, settings and combat log windows |
| `Data/` | Item database, sets, enchants, base stats, talents |

## Changelog

### 1.0.0
- Warrior DPS simulator: SIM DPS button with progress bar, breakdown tooltip, per-class settings
  (boss armor list, buffs, debuffs, rotation, tanking), combat log, set bonuses and item procs from
  Turtle's server data, Protection abilities.
- Talents, Community, Saved Builds and Item Database are tabs inside the main window.
- Talent window redesign with the game's tree art and prerequisite arrows.
- Racial weapon skill bonuses corrected to +3.
- Community: bad messages from other clients are ignored instead of raising errors; much less sync
  traffic; players on older versions are told to update; `/ab sync off`; hide a player's builds;
  builds with offensive names are hidden.
- Race and class are stored in English on non-English clients.
- No longer touches the Talented addon's globals.

### 0.9.7
- Enchants generated from the Turtle WoW database (263, including Turtle customs, ring/neck
  gemstones and belt buckles); old enchant IDs still load.
- Enchant picker search, stat filter and lower-rank hiding.
- Saved builds save automatically; loading over an unsaved build asks first.
- Server-wide community sync: catalog digests, best-informed player answers, periodic resync.
- Profanity filter for community build names.
- Top-bar buttons toggle like tabs; new minimap button.
- Fixed text boxes drawing only their end caps.
- New look: ember window frames, tab strip, game empty-slot art, quality glows on icons, hover-only
  enchant hints, dimmed zero stats, stat breakdown tooltips, collapsing set panel, fade-in windows,
  and a 3D model preview.

### 0.9.6
- Stat engine rebuilt on real vanilla base stats and vmangos formulas (fixes health, crit, dodge,
  parry, block, armor and hunter ranged AP).
- Clickable enchants and a larger enchant list.
- Rename and delete saved builds; saving a loaded build under a new name renames it.
- Item database dropdown filters and a search index for fast filtering.
- Community builds with publishing and voting, talents in build codes (AB3).

### 0.9.2 – 0.9.5
- Six-card Character Totals layout, weapons row and scrolling two-column set bonuses.
- Talent rendering fix and textured talent panels for every specialization.

### 0.8.0
- All 27 Turtle WoW talent trees with rank rules and character-sheet effects.

### 0.7.x
- Planner layout rewrite with gear columns, stat panel and always-visible set bonuses.
- Complete item-set catalog with website-style set tooltips; `/ab debug` and `/ab debugset`.

### 0.6.2
- Full Tortoise DB item data: 16,069 items with tooltips, sources, recipes, drops, quests and vendors.
