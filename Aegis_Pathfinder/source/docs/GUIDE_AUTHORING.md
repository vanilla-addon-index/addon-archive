# Aegis: Pathfinder - Guide Authoring Documentation

This document explains how to write leveling guides for Aegis: Pathfinder.

## Core Principles: How to Order Quests

Guides must be organized using THREE factors:

### 1. Prerequisites (Quest Chains)
Quests that require completing other quests first MUST come after their prerequisites.
- Check pfQuest database `["pre"]` field for prerequisite QIDs
- Example: If Quest B requires Quest A, then A's TURNIN must come before B's ACCEPT

### 2. Level Requirements
Order quests by their minimum level requirements.
- Lower level quests come before higher level quests
- Check pfQuest database `["min"]` field for minimum level
- Group quests of similar level together

### 3. Geographic Proximity
Minimize travel time by grouping nearby quests together.
- Pick up all quests in a hub before leaving
- Complete objectives in the same area together
- Turn in quests when passing through, not via special trips
- Use coordinates to plan efficient routes

### Balancing the Three Factors

```
PRIORITY ORDER:
1. Prerequisites - MUST be respected (game enforced)
2. Level requirements - SHOULD be respected (difficulty)
3. Proximity - OPTIMIZE within above constraints (efficiency)
```

**Example workflow:**
1. List all quests in the zone with their QIDs
2. Look up prerequisites and minimum levels in pfQuest
3. Build dependency graph (what requires what)
4. Group by geographic area
5. Order groups by level, respecting prerequisites within each group

## File Structure

Guides are Lua files located in:
- `Guides/Alliance/` - Alliance faction guides
- `Guides/Horde/` - Horde faction guides

Files should be named with the pattern: `{startLevel}_{endLevel}_{ZoneName}.lua`

Example: `01_10_Thalassian_Highlands.lua`

## Basic Guide Template

```lua
AegisPathfinder:RegisterGuide("Zone Name (Level-Range)", "Next Zone (Level-Range)", "Faction", function()

return [[

-- Guide steps go here

]]
end)
```

### Parameters:
1. **Guide Name**: Display name with level range, e.g., "Darkshore (12-17)"
2. **Next Zone**: The guide that follows this one, e.g., "Loch Modan (17-18)"
3. **Faction**: "Alliance", "Horde", or "Both"
4. **Function**: Returns the guide text as a multi-line string

## Action Types

Each line starts with a single-letter action code:

| Code | Action | Description |
|------|--------|-------------|
| `A` | ACCEPT | Accept a quest |
| `C` | COMPLETE | Complete quest objectives |
| `T` | TURNIN | Turn in a quest |
| `N` | NOTE | Information/instruction note |
| `R` | RUN | Travel to a location |
| `H` | HEARTH | Use hearthstone |
| `h` | SETHEARTH | Set hearthstone location |
| `F` | FLY | Take a flight path |
| `f` | GETFLIGHTPOINT | Discover a flight point |
| `B` | BUY | Purchase an item |
| `b` | BOAT | Take a boat |
| `K` | KILL | Kill mobs (non-quest) |
| `G` | GRIND | Grind mobs for XP |
| `U` | USE | Use an item |
| `t` | TRAIN | Train at a trainer |
| `D` | DIE | Die (spirit rez) |
| `P` | PET | Pet-related action |

## Tag System

Tags provide metadata and are enclosed in `|TAG|value|` format.

### Essential Tags

| Tag | Description | Example |
|-----|-------------|---------|
| `QID` | Quest ID from database (integers only) | `\|QID\|41187\|` |
| `OIDX` | Quest log objective index — a `C` step completes when this objective's leaderboard line reports finished | `\|QID\|771\| \|OIDX\|2\|` |
| `N` | Note/instruction text | `\|N\|Talk to the NPC at (45, 50)\|` |
| `Z` | Zone name override | `\|Z\|Thalassian Highlands\|` |

**Do not write fractional QIDs** like `\|QID\|771.2\|` to mean "quest 771,
objective 2" — the parser only accepts integer QIDs, so the whole tag is
silently dropped and the step becomes untrackable. Use `\|QID\|771\| \|OIDX\|2\|`
on a `C` step instead, or an `\|L\|itemid qty\|` tag for item collects.

### Conditional Tags

| Tag | Description | Example |
|-----|-------------|---------|
| `C` | Class restriction | `\|C\|Warrior\|` or `\|C\|Mage/Warlock\|` |
| `R` | Race restriction, as `UnitRace` names it (`Night Elf`, `High Elf`); `!` for "not" | `\|R\|Human\|`, `\|R\|Dwarf/Gnome\|` or `\|R\|!Undead\|` |
| `O` | Optional quest | `\|O\|` |
| `T` | In-town objective | `\|T\|` |
| `P` | Play style: shown only in that mode | `\|P\|GROUP\|` |
| `D` | Dungeon: shown only while that dungeon is ticked (`!` for "not ticked", `/` for either) | `\|D\|DM\|`, `\|D\|!WC\|` |
| `AH` | Auction House step: shown only with Auction House steps on and Solo Self-Found off | `\|AH\|` |
| `TRADE` | Needs another player (a trade, a mage's water, a crafter): hidden in Solo Self-Found | `\|TRADE\|` |

### Item Tags

| Tag | Description | Example |
|-----|-------------|---------|
| `L` | Loot item ID and quantity | `\|L\|12345 10\|` |
| `U` | Use item ID | `\|U\|6948\|` |

### Special Tags

| Tag | Description | Example |
|-----|-------------|---------|
| `LV` | Level requirement | `\|LV\|10\|` |
| `PRE` | Prerequisite quest name | `\|PRE\|Previous Quest\|` |
| `S` | Skip follow-up flag | `\|S\|` |
| `SZ` | Subzone name | `\|SZ\|Brinthilien\|` |
| `OBJ` | Object ID | `\|OBJ\|12345\|` |
| `AYG` | "As You Go" reference | `\|AYG\|41190\|` |

### Travel steps

An `R`, `F`, `b` or `H` step is done when you arrive. That can mean:

- within about 15 yards of its first coordinates, in its `Z` zone;
- in the zone or subzone its title names: `R Westfall` in Westfall, `R the Westfall Lighthouse` at the lighthouse;
- the same with a leading "Travel to", "Travel towards", "Run to", "Go to", "Head to", "Return to", "Fly to" or "Enter" dropped: `R Travel to Westfall` anywhere in Westfall;
- in its `SZ` subzone or zone.

A travel step marked `|O|` with no `|PRE|` is a *way there*, not a stop. RestedXP's `#sticky` and `#completewith` steps convert to these. A way there is also behind you, and ticked, when either:

- you are in the next step's zone, and that is not its own `Z`; or
- the next step is done, such as its quest already in your log.

RestedXP's 13-15 Westfall opens on `R Travel to Elwynn Forest |N|(19.0, 81.0)| |O| |Z|Elwynn Forest|`: walk through Elwynn and it ticks there; fly to Sentinel Hill and it ticks on landing in Westfall.

A travel step without `|O|` is a stop and waits for one of the first four. One with a `|QID|` is also done once that quest is in your log. Teldrassil (1-12)'s `R Gnarlpine Hold |QID|930|` is done once The Glowing Fruit is taken. A change to the quest log rechecks any travel step. The quest automation looks past any travel step to the next step's NPC or object: talking to them means you got there.

### Profession Tags

Profession guides do not advance on quest events -- there is no quest to accept
or turn in, only a skill number that climbs while you craft. These tags drive
that, and are handled in `Professions.lua`.

| Tag | Description | Example |
|-----|-------------|---------|
| `SKILL` | Profession and skill range. The step completes when the player's skill reaches the upper bound. | `\|SKILL\|Alchemy 1 63\|` |
| `CRAFT` | What to make, and roughly how many the route expects | `\|CRAFT\|40 Minor Healing Potion\|` |
| `MATS` | Reagents for a *single* craft; the shopping list multiplies by the craft count | `\|MATS\|1x Peacebloom, 1x Silverleaf, 1x Empty Vial\|` |
| `SRC` | Where the recipe comes from | `\|SRC\|Trainer\|` |
| `ALT` | Equally viable recipes for the same range | `\|ALT\|Elixir of Minor Defense, Swiftness Potion\|` |
| `RANK` | Profession and skill cap. The step completes when the cap reaches it: training a rank, reading a secondary profession's tome and its Artisan quest all raise the cap, whatever the step's action. | `\|RANK\|Alchemy 225\|` |
| `NPC` | Whom the step sends you to, `;`-separated. With no coordinates in the note, the waypoint goes to the nearest of them, looked up by name in pfQuest's unit database; spots the world map cannot show (inside a dungeon) are skipped. | `\|NPC\|Ainethil;Kylanna Windwhisper\|` |

A profession name may contain a space, so `SKILL` is parsed by matching the two
trailing numbers and taking everything before them as the name --
`\|SKILL\|First Aid 1 45\|` works.

A range with no craftable recipe (open-world gathering, for instance) uses a
`G` step with a `SKILL` tag and no `CRAFT`; it waits for the skill. A `G` step
with an `LV` tag and no `SKILL` is a level gate: it holds the guide until the
character reaches that level, and clears itself at once for anyone already
there. A grind to a level ("Grind to level 10") is the same: give it `LV`.
One marked `|O|` does not hold the guide, and still ticks at the level. Every step with a `SKILL` or `RANK` completes as soon as the player's
skill or cap is there, so someone opening a guide part-way through moves
straight to where they are.

**Profession guides in `Guides/Professions/` are generated** from
CraftRoute's routes for the crafting professions
(`Tools/data/craftroute_routes.json`, planned by `Tools/build/import_routes.py`),
`Tools/data/Professions_Reference.docx` (Mining's route,
trainers) and
`Tools/data/profession_training.json` (rank levels and costs, the secondary
professions' tomes and Artisan quests, trainers the reference lacks -- taken
from the owner-supplied FAQ in `Tools/data/Profession_FAQ.md` -- and First
Aid's route and its bandages' skill colours) by
`Tools/build/convert_professions.py`. Editing them by hand will be overwritten, and
`python3 Tools/build/convert_professions.py --check` -- part of `Tools/run_tests.sh`
-- fails when the committed guides differ from what it would write. They are written in QuestShell+
structured tables rather than this DSL -- see `docs/QUESTSHELL_PLUS.md` -- and
the converter emits these tags through `QuestShellPlusParser.lua`.

## Coordinates

Include coordinates in the note text using the format `(X, Y)` or `(X.X, Y.Y)`:

```
A Quest Name |QID|12345| |N|NPC Name in Town (45.5, 32.8)| |Z|Zone Name|
```

Multiple coordinates for mob grinding areas:
```
C Kill Quest |QID|12345| |N|Kill 10 mobs in this area (45, 50) (48, 52) (42, 48)| |Z|Zone Name|
```

## Quest Chains and Prerequisites

### Correct Ordering

Quests must be ordered so prerequisites come BEFORE the quests that require them:

```lua
-- CORRECT: Quest A turnin before Quest B accept
A Quest A |QID|100|
C Quest A |QID|100|
T Quest A |QID|100|
A Quest B |QID|101|  -- Quest B requires Quest A

-- WRONG: Quest B accept before Quest A turnin
A Quest B |QID|101|  -- ERROR: Prerequisites not met!
A Quest A |QID|100|
```

### Finding Prerequisites

Use the pfQuest database to find quest prerequisites:
1. Look up the quest in pfQuest-turtle's `db/quests-turtle.lua`
2. Check the `["pre"]` field for prerequisite QIDs
3. Ensure those quests appear earlier in your guide

Example from pfQuest database:
```lua
[41215] = {
    ["pre"] = { 41214 },  -- Requires quest 41214 first
    ...
}
```

### Cross-Zone Prerequisites

If a quest requires completing something in another zone:
1. Note it clearly in the guide
2. The addon will warn players automatically (if pfQuest is installed)

## Complete Example

From `01_10_Thalassian_Highlands.lua`:

```lua
AegisPathfinder:RegisterGuide("Thalassian Highlands (1-10)", "Darkshore (12-17)", "Alliance", function()

return [[

N Welcome to Thalassian Highlands |N|This is the High Elf starting zone.|

A Refugees no More |QID|41187| |N|Aerthand Skyshield in Brinthilien (48.3, 84.3)| |Z|Thalassian Highlands|
T Refugees no More |QID|41187| |N|Commander Anarileth in Brinthilien (48.6, 83.6)| |Z|Thalassian Highlands|
A Provisions for Refugees |QID|41188| |N|Commander Anarileth in Brinthilien (48.6, 83.6)| |Z|Thalassian Highlands|

A Plain Letter |QID|41230| |N|Brinthilien trainer area| |C|Warrior| |Z|Thalassian Highlands|
A Feathered Letter |QID|41231| |N|Brinthilien trainer area| |C|Hunter| |Z|Thalassian Highlands|

C Provisions for Refugees |QID|41188| |N|Kill Young Thalassian Boars (46, 82) (50, 78)| |Z|Thalassian Highlands|
T Provisions for Refugees |QID|41188| |N|Commander Anarileth (48.6, 83.6)| |Z|Thalassian Highlands|

H Alah'Thalas |N|Set your hearthstone at Tiriel's inn| |Z|Thalassian Highlands|

R Alah'Thalas Docks |N|Travel to the docks (62, 17.9)| |Z|Thalassian Highlands|
B Boat to Auberdine |N|Take the boat to Darkshore|

N Guide Complete |N|Continue to Darkshore (12-17).|

]]
end)
```

## Generated Zone Guides

A custom zone whose quests are in a pfQuest-turtle checkout can be written
from that data instead of by hand. `Tools/build/build_zone_guide.py` reads the
zone's quests -- givers, takers, objectives and where they are, the quests
before each, levels and races -- and orders them by the rules above:
prerequisites first, then level, then the nearest thing to do next, picking up
and handing in everything at a quest giver before moving on, with trips out of
the zone only where a chain goes out and comes back. It writes one guide per
side.

```sh
python3 Tools/build/build_zone_guide.py --pfquest-turtle ../pfQuest-turtle --pfquest ../pfQuest
```

What the data cannot give -- the names of places, a quest chain it has no
`["pre"]` for, objectives it has no spawns for, which quests want a group --
goes in the zone's entry in `ZONES` at the top of the script, never into the
guide, so running it again over a newer checkout keeps it. Anything it still
cannot place is printed as it writes. Moonwhisper Coast is written this way,
from [ryanmr82's fork](https://github.com/ryanmr82/pfQuest-turtle); its data
grows as players send in captures, so run it again now and then.
`Tools/tests/test_zoneguide.lua` checks what it writes.

## Dungeon Guides

`Guides/Dungeons/` is written by `Tools/build/build_dungeon_guides.py`: do not edit
the guides there, change the script. Each dungeon's entry in its `DUNGEONS`
table says where the entrance is and, per side, which towns to go round and in
what order -- a town can come twice, for a chain that goes there and back.
Which quests are the dungeon's comes from InstanceJournal's lists; the quests
before and after them are pulled in from their chains. `SKIP`, `ADD`, `FIX`,
`TASK` and `FAR` correct what the data gets wrong: a repeatable quest, a quest
it does not list, a giver or taker it lacks, an objective it has no spawns
for, a quest that needs another dungeon first.

```sh
python3 Tools/build/build_dungeon_guides.py --dump ULDA      # one dungeon, and what it left out
python3 Tools/build/build_dungeon_guides.py                  # write the guides
python3 Tools/build/build_dungeon_guides.py --pfquest ../pfQuest --pfquest-turtle ../kludge-pfQuest-turtle \
    --instancejournal ../InstanceJournal               # read the data again first
```

What it reads is kept in `Tools/data/dungeon_guides.json`, so it runs without
the checkouts. `--dump` lists the quests given where the guide does not go,
those it thinks need no more than a word with someone (check them: the data
may lack their objectives), and any it picks up and never hands in.
`Tools/tests/test_dungeonguides.lua` fails if the guides are stale, or a quest is
handed in before it is picked up, or picked up and never handed in.

**Trips.** A trip to a town carries the class or race tags every quest there
shares (Darnassus, for Shadowfang Keep, is one Priest, Mage, Warlock and Druid
quest), so nobody else is sent; and when every quest there is optional and
waits on the same quest first, the trip carries that |O| |PRE| too, and the
engine passes it over until the first quest is done, as it does the accept.

**Boss steps.** Each boss's step is `K <boss> |N|<note>| |TANK|..| |HEAL|..|
|DPS|..| |BOSS|<name>;<name>|`. `|TANK|`, `|HEAL|` and `|DPS|` are the role
lines Options -> Dungeons -> *My role in dungeons* picks from (Parser.lua's
`GetStepNote`); `|BOSS|` names who must die to tick it, from the combat log
(QuestTracker.lua's `CHAT_MSG_COMBAT_HOSTILE_DEATH`). A rare boss's step is
`|O|`. The bosses, in order, are in `Tools/data/dungeon_bosses.json`, written
by `Tools/build/build_dungeon_bosses.py` from InstanceJournal (the list, the
rares, Turtle WoW's abilities), the CMaNGOS classic-db dump (each boss's
spells, its scripted health points, what he summons) and mangos-classic's
ScriptDevAI scripts:

```sh
python3 Tools/build/build_dungeon_bosses.py --instancejournal ../InstanceJournal \
    --cmangos ../classic-db/Full_DB/ClassicDB_1_12_1_z2815.sql.gz \
    --scripts ../mangos-classic/src/game/AI/ScriptDevAI/scripts
python3 Tools/build/build_dungeon_guides.py                  # then write the guides
```

The notes are written by hand in `Tools/build/dungeon_tactics.py`: `TACTICS`,
keyed by InstanceJournal's boss id, holds each boss's note and role lines
(`T(note, tank=, heal=, dps=)`), and `WATCH` the names whose deaths tick a
step when it is not the boss's own (a group fight, a boss Turtle renamed), or
`None` for a step ticked by hand. Say which classes can dispel what with
`MAGIC`, `CURSE`, `POISON` and `DISEASE`. A boss with no entry gets "No special
abilities known." when the data has him and nothing he casts, and
"Pathfinder has no notes on this fight yet." when it does not have him at all.

## Class Quest Guides

`Guides/Class/` is written by `Tools/build/build_class_guides.py`: do not edit
the guides there, change the script. One file per class and side holds a
guide per milestone -- a chain of class quests that ends in something the
class keeps -- and, at its end, `RegisterClassMilestones` with what the offer
needs of each: per race, the level to offer it at, the quests that say a
route does it already, and the quest the guide ends handing in.

The chains are found from the data: pfQuest's quests before, CMaNGOS'
`PrevQuestId` and `NextQuestInChain`, and quests that only send you to a
chain's first giver (Turtle WoW's Dabbling In Darkness), which become `|O|`
steps. Chains that end in the same thing are one milestone; each race gets the
one that starts at home. Its steps are merged across the races, `|R|` on the
ones not everyone takes. What the data gets wrong goes in the script's tables:

- `CHAIN_NAMES`, `SPELL_NAMES`, `TITLE_NAMES`, `RACIAL_TITLES`: what a milestone
  is called, where the spell it teaches or its last quest's title does not say;
- `EXCHANGE_NPCS`: the raid tiers' armour exchanges, which are left out;
- `SKIP`: quests that are not steps of a chain (the Charger's fight again);
- `PLACES`: NPCs pfQuest has no spawns for (the Ancients in Felwood);
- `MORE_ENTRANCES`: an instance's door the dungeon guides do not give.

```sh
python3 Tools/build/build_class_guides.py --list       # the milestones, and each race's chain
python3 Tools/build/build_class_guides.py              # write the guides
python3 Tools/build/build_class_guides.py --pfquest ../pfQuest --pfquest-turtle ../kludge-pfQuest-turtle \
    --cmangos ../classic-db/full.sql                   # read the data again first
```

What it reads is kept in `Tools/data/class_quests.json`. `Tools/tests/test_classguides.lua`
parses every guide as each race of its class sees it, and fails if the guides
are stale, a race's chain is missing a quest or has another race's, a quest is
handed in before it is picked up or never handed in, or a guide does not end
with the quest the offer takes for its last.

## Attunement Guides

`Guides/Attunements/` is written by `Tools/build/build_attunement_guides.py`:
do not edit the guides there, change the script. Its `ATTUNEMENTS` table names
each attunement by the quest that finishes it, per side; the chain is found
from the data, going back through the quests before each, keeping only those
the side can get (someone gives it, its races allow the side). Of quests only
one of which can be done -- "A Call to Arms" from each city -- it keeps the one
given in the side's first city. The steps are written by the class quest
guides' `ClassGuide`, with no class and the side's cities as home. `SPOTS`
corrects where the data puts someone (Stormwind Keep is on Northwind's map in
pfQuest-turtle), and `DOORS` gives the ways into Turtle WoW's own instances.
At the end of each side's file, `RegisterAttunements` gives the browser each
guide's instance, raid or dungeon, level, and the quests that mean you are
attuned.

```sh
python3 Tools/build/build_attunement_guides.py --list       # each side's chains
python3 Tools/build/build_attunement_guides.py              # write the guides
python3 Tools/build/build_attunement_guides.py --pfquest ../pfQuest --pfquest-turtle ../kludge-pfQuest-turtle \
    --cmangos ../classic-db/full.sql                        # read the data again first
```

What it reads is kept in `Tools/data/attunements.json`.
`Tools/tests/test_attunements.lua` fails if the guides are stale, a side lacks
one, a quest is handed in before it is picked up, or a guide does not hand in
the quest that attunes.

## Routes and Dungeon Quests

A route pack's route (`Routes/Routes.lua`) decides what comes after a guide on
it: the next leg for the character's pack and race. A guide's own next guide
(`RegisterGuide`'s second argument) is only the way on for a guide picked off
the route, so keep the two in step; `Tools/tests/test_routes.lua` fails on a leg or
a next guide that does not exist.

The first-time setup counts each dungeon's quests along a route, and a quest
counts only if the guide takes you all the way through it.
`python3 Tools/build/build_dungeon_quests.py --report` says which dungeon-tagged
quests do not count and why -- never picked up, handed in before it is
picked up, what the server wants done before it missing -- and without
`--report` it writes `DungeonQuests.lua`, which `Tools/tests/test_routes.lua` checks
is up to date. After editing a guide's dungeon steps or a route, run it.
(Remember that Parser.lua keeps only the first accept and the first hand-in
of a quest in a guide: a later duplicate is dropped.)

## Registering Your Guide

After creating the guide file, add it to the appropriate `Guides.xml`:

```xml
<Ui xmlns="http://www.blizzard.com/wow/ui/">
    <Script file="01_10_Thalassian_Highlands.lua"/>
    <Script file="12_17_Darkshore.lua"/>
    <!-- Add your new guide here -->
</Ui>
```

### Where it shows in the guide browser

The browser files a guide by its name (`GetGuideCategory`): `Optimized/`,
`RXP/` and `RXP_Hardcore/` under Leveling's packs, `Dungeons/` under Dungeons,
`Class/` under Class Quests, a profession's table under Professions, a custom
zone's name (`TURTLE_ZONES` in `Core.lua`) under Custom zones, and anything
else under Zone guides. Put the levels in the name -- `Darkshore (12-17)`,
`RXP/12-14 Loch Modan` -- because that is what the browser sorts by, colours by
and shows.

A zone guide goes under its continent, and its picture is its zone's map, by
the zone its name says (`Browser.ZONES` in `GuideBrowser.lua`, which also knows
places such as "Coldridge Valley"); a name with no zone in it is filed by the
zone most of its `|Z|` tags name. A route leg named for a dungeon
(`Optimized/Uldaman (45-46)`) is listed under Dungeons, in **On the routes**,
rather than in its pack, and shows the dungeon's loading screen. A pack's
chain that opens a dungeon or raid -- a title with the word "Attunement" or
"Key" (`Browser.ACCESS_WORDS`), such as `RXP/Onyxia Attunement (A)` -- is
listed under Dungeons in **Attunements and keys**. A new custom
zone wants a line in `Browser.ZONES`, its explored world map in
`Tools/data/maps/` and a line in `Theme.zonemap` (see `media/README.md`):
custom zones' maps built from the client's tiles and pfUI's overlays came
out wrong in game. A
new dungeon's loading screen goes in `Tools/data/loadscreens/` and
`Theme.loadscreen` the same way.

## Research Resources

When creating guides for Turtle WoW custom zones:

> **Note on sources.** Turtle WoW itself is offline, and its database and wiki
> may be stale or unreachable. The successor servers each reconstructed content
> past roughly patch 1.17 independently, so **quest IDs and coordinates are not
> guaranteed to match between them**. Prefer the database of the server you are
> authoring for, and record which server you verified against.
>
> (Reachability of the two Turtle WoW links below could not be checked from the
> environment these docs were updated in -- they are blocked there by an egress
> proxy, which is not evidence either way.)

1. **Your server's own database** -- the authoritative source
   - OctoWoW: https://octowow.st/db
   - Capybara Paradise, RavenCraft: use each server's own database

2. **Turtle WoW Database** (legacy): https://database.turtle-wow.org/
   - Historical reference; verify anything taken from it

3. **Turtle WoW Wiki** (legacy): https://turtle-wow.fandom.com/
   - Zone overviews and lore

3. **pfQuest-turtle Database**: `/Interface/AddOns/pfQuest-turtle/db/`
   - `quests-turtle.lua` - Quest data with prerequisites
   - `units-turtle.lua` - NPC locations
   - Quest IDs in 40000+ range are Turtle WoW custom

4. **In-Game Exploration**:
   - Use `/way` commands with TomTom
   - Use pfQuest to show available quests on map

## pfQuest Database Structure

The pfQuest database files contain all quest data you need for guide creation.

### File Locations
```
/Interface/AddOns/pfQuest-turtle/db/
├── quests-turtle.lua      # Quest data (prereqs, levels, objectives)
├── units-turtle.lua       # NPC data (locations, coordinates)
├── objects-turtle.lua     # Object data (quest objects)
├── items-turtle.lua       # Item data
└── enUS/                  # Localized quest/NPC names
    └── quests.lua
```

### Quest Data Structure (`quests-turtle.lua`)
```lua
pfDB["quests"]["data"] = {
  [41187] = {                    -- Quest ID
    ["min"] = 1,                 -- Minimum level required
    ["lvl"] = 5,                 -- Quest level (difficulty)
    ["pre"] = { 41186 },         -- Prerequisite quest IDs (array)
    ["race"] = 255,              -- Race bitmask (255 = all)
    ["class"] = 255,             -- Class bitmask (255 = all)
    ["start"] = {
      ["U"] = { 12345 },         -- Unit (NPC) IDs that give quest
      ["O"] = { 67890 },         -- Object IDs that give quest
      ["I"] = { 11111 },         -- Item IDs that start quest
    },
    ["end"] = {
      ["U"] = { 12346 },         -- Unit (NPC) IDs to turn in
    },
    ["obj"] = {
      ["U"] = { 54321, 54322 },  -- Units to kill
      ["I"] = { 22222 },         -- Items to collect
      ["O"] = { 33333 },         -- Objects to interact with
    },
  },
}
```

### Key Fields for Guide Creation
| Field | Description | Use |
|-------|-------------|-----|
| `["min"]` | Minimum player level | Order quests by level |
| `["pre"]` | Array of prerequisite QIDs | Ensure prereqs come first |
| `["start"]["U"]` | NPC IDs that give quest | Look up NPC location |
| `["end"]["U"]` | NPC IDs for turn-in | Look up NPC location |
| `["obj"]` | Objective targets | Describe what to kill/collect |

### Unit/NPC Data Structure (`units-turtle.lua`)
```lua
pfDB["units"]["data"] = {
  [12345] = {                    -- Unit (NPC) ID
    ["coords"] = {
      [1] = { 45.5, 32.8, 0 },   -- x, y, zone_index
      [2] = { 46.2, 33.1, 0 },   -- multiple spawn points
    },
  },
}
```

### Quest Names (`enUS/quests.lua`)
```lua
pfDB["quests"]["loc"] = {
  [41187] = "Refugees no More",  -- QID -> Quest Name
  [41188] = "Provisions for Refugees",
}
```

### Example: Looking Up Quest Data
To create a guide entry for quest 41188:

1. Find quest in `quests-turtle.lua`:
   ```lua
   [41188] = {
     ["min"] = 1,
     ["pre"] = { 41187 },  -- Requires 41187 first!
     ["start"] = { ["U"] = { 50001 } },
     ["end"] = { ["U"] = { 50001 } },
   }
   ```

2. Find NPC location in `units-turtle.lua`:
   ```lua
   [50001] = {
     ["coords"] = { [1] = { 48.6, 83.6, 42 } },  -- Zone 42
   }
   ```

3. Find quest name in `enUS/quests.lua`:
   ```lua
   [41188] = "Provisions for Refugees",
   ```

4. Create guide entry:
   ```
   A Provisions for Refugees |QID|41188| |N|Commander Anarileth (48.6, 83.6)| |Z|Thalassian Highlands|
   ```

## Best Practices

1. **Always include QIDs** - Enables smart skip and prerequisite checking
2. **Use precise coordinates** - Helps TomTom navigation
3. **Specify zone with |Z|** - Prevents wrong-zone waypoints
4. **Group nearby quests** - Minimize travel time
5. **Note class/race restrictions** - Use |C| and |R| tags. `|C|` takes class
   names and `|R|` race names exactly as the client gives them ("Night Elf",
   "High Elf", "Undead" -- not "NightElf" or "Scourge"), separated by `/`:
   `|C|Warrior/Rogue|` is either class, `|C|!Mage/!Warlock|` any class but
   those two. A step shows when its class tag and its race tag both match, so
   one step can't say "a Warrior, or any Undead": write two steps that don't
   overlap (`|C|!Warrior| |R|!Undead|` and `|R|Undead|`) -- an accept or hand-in
   written twice is kept once. `python3 Tools/verify.py` rejects a name the
   client never gives.
6. **Mark optional quests** - Use |O| tag. An optional accept is offered only
   when it has something to go on: a `|U|` item in your bags, a `|L|` item,
   or a `|PRE|` quest handed in. Without one it is never shown, so a dungeon
   chain gated by `|D|` should not also be `|O|`, or nobody picks it up.
   `|PRE|` takes the prerequisite's quest id (`|PRE|2766|`), or several that
   are all needed (`|PRE|836, 2767, 648|`); the server's record of the quest,
   or this guide's ticked turn-in step for it, counts. A quest name works
   too, matched against the steps of the loaded guide.
7. **Test your guide** - Play through it on a character

## Troubleshooting

- **Guide not loading**: Check Guides.xml includes your file
- **Quest not auto-completing**: Verify QID is correct
- **Wrong coordinates**: Use /way in-game to verify
- **Prerequisites warning**: Check pfQuest database for quest chains
