# Contributing to Aegis: Pathfinder

## Getting credited

Add yourself to [CONTRIBUTORS.md](CONTRIBUTORS.md) in the same pull request as
your change. Put yourself in the table your work belongs to, or start a new row
if none fits. Nobody will do this for you, and a contribution that goes
uncredited because the list was not updated is a bug in our process, not yours
— so if you forget and notice later, send a PR that just adds you.

The in-game credits window (the **Credits** button on the options window's
**About** page) reads from `Credits.lua`, which mirrors `CONTRIBUTORS.md`.
Update both.

## Branching

Work on a branch and open a pull request against `main`. Every version that
reaches `main` is released by itself: `.github/workflows/release.yml` tags the
`.toc`'s `## Version` as `v<version>` and packages it as a GitHub release, once.
A merge that leaves the version alone releases nothing, so bump the version
(below) when a change ships. There is no need to push a `v*` tag by hand; one
pushed anyway is released too.

## Where things are

| Path | What it is |
|---|---|
| `Aegis_Pathfinder.toc`, `*.lua`, `Bindings.xml` | The addon. The `.toc` lists what loads, in order |
| `Guides/` | The guides: `Optimized/`, `RXP/` and `RXP_Hardcore/` by side; the zone guides in `Alliance/`, `Horde/` and `Both/`; `Dungeons/`, `Class/` and `Professions/`, which are generated |
| `Routes/` | The route packs: which guide follows which, per race |
| `Crafting/` | Recipe and price data for the crafting route planner (generated) |
| `media/` | Textures (generated) and fonts -- see [media/README.md](media/README.md) |
| `libs/` | Ace2 |
| `Tools/run_tests.sh`, `Tools/verify.py` | The checks (below) |
| `Tools/tests/` | The Lua tests, and `wow_stub.lua`, the 1.12 API they run against |
| `Tools/build/` | The generators and importers: dungeon, class quest, zone and profession guides, gear and item-score data, recipes, textures, the filter review, the talent builds, and the RestedXP converter |
| `Tools/data/` | What the generators read and cache, and the filter review's candidates and answers |
| `docs/` | Features, guide authoring, the QuestShell+ format, the UI spec and design concept, and the in-game test pass |

Nothing under `Tools/` or `docs/` ships: `.pkgmeta` leaves them out.

## Running the checks

```sh
sh Tools/run_tests.sh
```

That runs everything that can run without a WoW client:

| Check | What it covers |
|---|---|
| `Tools/verify.py` | Lua syntax, Lua 5.0 compatibility for shipped files, `.toc` paths, `Guides.xml` completeness, TGA validity, no Blizzard chrome, the 32-upvalue ceiling, the class and race names in the guides' class and race tags, that every step with coordinates is on a zone the world map knows, that no step sails between Menethil Harbor and Auberdine (Turtle WoW has no such boat; Auberdine's goes to Stormwind Harbor), that no `AegisPathfinder` method is defined twice (a later definition replaces the first) except as a wrapper |
| `Tools/build/convert_professions.py --check` | The profession source document still parses and is internally consistent; the gathering guides cover 1–300 for each faction with somewhere named in every band; the committed guides are what the generator writes |
| `Tools/build/talent_builds.py --check` | Every talent build for the Talent Advisor against the trees the game has (`Tools/data/turtle_talent_trees.json`, saved by `/apg talents`): talents the class has, their ranks, 5 points a row, prerequisites at full rank, 51 points, and each build learnable point by point in its order; the committed builds -- `Tools/data/talent_builds.json`, the addon's `TalentBuilds.lua` and the tests' `Tools/tests/talent_trees.lua` -- are what it writes |
| `Tools/tests/test_theme.lua` | The theme layer against a stubbed 1.12 API |
| `Tools/tests/test_smartskip.lua` | Where a guide opens: a new character at the top, a quest in progress or ready to hand in at its step, otherwise the first step not done |
| `Tools/tests/test_yourplace.lua` | Right-clicking the step arrows: back or on to your place after clicking round, every mark and completion the arrows changed put back (a completion earned meanwhile kept), only in the arrow's direction, and with no clicking round, to where the guide would open |
| `Tools/tests/test_filtertags.lua` | The filter tags in the Optimized and zone guides through the real parser: group quests and their follow-ups hide in Solo mode, Auction House steps with Auction House steps off, dungeon quests with the dungeon unticked, and all three -- with trading -- under Solo Self-Found; and every approved tag is still in place |
| `Tools/tests/test_professions.lua` | Generated guides through the real parsers: skill bands tile 1–300 for each faction, every rank is reached, and a gathering guide never sends a faction into the other side's starting zones or capitals |
| `Tools/tests/test_dungeons.lua` | Dungeon chips and the guide-reference scan |
| `Tools/tests/test_guidelist.lua` | Guide categorisation, tabs and badges, and a class quest guide's one level |
| `Tools/tests/test_guidebrowser.lua` | The guide browser: Leveling's folders (packs, zone guides by continent, custom zones), a long folder split by level, a guide's zone from its title or its steps, only your class's quests; search, favourites, the recent list; the suggestions; the level and gold trackers; each kind of guide's picture, the map's tiles and overlays cut as the client cuts them and the crop; and the window -- Home's panels and hiding them, the level page, folders and back, pointing at a guide, the clicks, the star, the RestedXP pack switch, the list's four switches, search, Current, Recent, Return to Main, scrolling, the size limits and reopening where it was left |
| `Tools/tests/test_activeframes.lua` | Active Items, Active Targets and Macros: which items and targets each step offers, targeting and raid marks, the generated AegisTarget/AegisItem macros, placement, the key bindings |
| `Tools/tests/test_automation.lua` | The Automation page: the guide's quests or all of them (never a grey one, room left in the log), picking from an NPC's list, the step's flight, buying what the step needs, selling greys, repairing, Shift holding it all back; and making room in full bags, the cheapest item first |
| `Tools/tests/test_maps.lua` | The Maps page: the reveal drawing only what the client doesn't, cut as the client cuts it, and standing down for pfUI, Cartographer and MetaMap; the step's places from pfQuest and its note, on their own zone; the ant trail, dots or dashes, marching, on the waypoint's zone only; the rares near your level, sized and see-through; the minimap trail inside the minimap, with Astrolabe |
| `Tools/tests/test_extras.lua` | The Extras page: routine lines silenced and warnings not, the reputation line (where it stands, to the next rank, Exalted, a faction under a closed header and the header closed again), level-ups to each channel ticked with the time worded right, and nothing to a party or guild you are not in |
| `Tools/tests/test_talentwindow.lua` | The Talent Advisor on Blizzard's talent window, stood in for with Blizzard_TalentUI 1.12.1's names: the window hooked once it loads, opening on the next point's tree; each talent's badge (to take, done, "+N" off the build), the glow and NEXT, the tab's dot; the strip's build, menu, next point and points off the build, over the frame or pfUI's backdrop; the tooltip's lines; nothing with the advisor off; a build that doesn't fit; and in chat the talent on a level up, your spec's build ready at 60 once, and a build that doesn't fit once a session |
| `Tools/tests/test_talentadvisor.lua` | The Talent Advisor's engine against Turtle WoW's trees (`Tools/tests/talent_trees.lua`): every build fits its class's tree and is learnt point by point with the advisor naming each point in turn, the next point at a level, points off the build and carrying on from the closest point, a build that doesn't fit the tree and why, and the build followed (levelling until 60, then your spec's) |
| `Tools/tests/test_setup.lua` | First-time setup: when it opens, which guides and dungeons it offers, Solo Self-Found holding the other features off, and what Finish writes |
| `Tools/tests/test_zoneguide.lua` | The Moonwhisper Coast guides through the real parser: each side's own quests and not the other's; every quest step with an id, a zone and a place to go; picked up, done, handed in in that order, and each quest after the one it follows (the Moro'gai story, the Horde's trips to Azshara and Mulgore and back); the quest log never past 20; the quests you may not have optional; group quests, what follows them and a trip made only for them in Group mode alone; a race's quest shown to that race only |
| `Tools/tests/test_routes.lua` | The route packs against the guides: every leg a guide your faction has, every guide's next link one that exists, where the routes part by race, and DungeonQuests.lua what `Tools/build/build_dungeon_quests.py` makes of them today |
| `Tools/tests/test_nextguide.lua` | Where next?: which custom zones fit a level, and the walk from a route guide to a custom zone and back to the route; a ticked dungeon at the middle of its levels; a class quest at its level (your class and race, not done, not on the route still to come, a group chain only in a group), each window's buttons in their own window, the dungeon's before the class quest's |
| `Tools/tests/test_materials.lua` | Shopping list arithmetic, checked against the source document's own shopping list; bag counts, the scope tabs, and sending to Aegis: Exchange |
| `Tools/tests/test_craftplanner.lua` | The crafting route planner: reading the recipe data, the skill-up chance, the route against brute force, learning fees, make-or-buy, pricing at depth, stock carried between steps, selling back, unpriced reagents; the auction scan against the suite's auction house rules; every profession planned from the real data |
| `Tools/tests/test_itemscore.lua` | The item score: reading 1.12 tooltips (stats, weapon DPS, a ranged weapon's DPS apart, school spell damage, set bonuses and procs ignored, red lines meaning unusable or later), soft caps, the spec from your talents, the leveling and 60 sets (and the tanks' one, the level-up switching at once), your own weights kept per set and sharing them in OctoPawn's string, the old defaults' changes cleared once, comparing by slot (rings, two-handers, dual wield), and the tooltip line |
| `Tools/tests/test_gearadvisor.lua` | The Gear Advisor: upgrades found in the bags, offered biggest first and once a session, Equip into the right slot (waiting out a fight, finding an item that moved), Decline remembered across reloads, equip-for-me never binding an item, off at 60; the best quest reward (upgrade, else sell price, waiting for items to load) marked and picked; upgrades bordered in the bags |
| `Tools/tests/test_gearfinder.lua` | The Gear finder: the dungeons it looks in (level, side, your ticks, raids), the drops it weighs (level, class), Turtle WoW's own items described by the client (and badges, greys and items above you never weighed), quest rewards (not done, your side and class, within reach), reputation gear and crafted gear (bind-on-pickup and Solo Self-Found only with the profession), loading the ones not cached, the best three a slot in the character sheet's order, the window, and naming upgrades on walking into a dungeon; and that the real loot data is there |
| `Tools/tests/test_gearframe.lua` | The Item Score page: the spec picker, which set of weights it says, the weights listed down the left and edited, show all growing the page, export, import and Reset weights beside and under them |
| `Tools/tests/test_craftroute.lua` | The crafting route window and planned guides: rank steps placed where the skill cap runs out, crafts contiguous and parsed as skill steps, saving and restoring, the window's totals, rows, status line, re-planning only on change, and the scan button |
| `Tools/tests/test_partysync.lua` | Sharing a guide with the party: step names that survive different step numbering, holding a finished step for the slowest partner without pulling anyone back, skipping out of a hold, the messages both ways, the throttle and heartbeat, the popups, the members under the step, and the group changing |
| `Tools/tests/test_objectivetabs.lua` | The objectives tab bar and branch state |
| `Tools/tests/test_load.lua` | The whole addon loaded in `.toc` order with the real Ace2: every file to its end, the guides included; starting up (the chat commands, the TurtleGuide progress import); the level-up and arrival handlers; the guide browser over every guide, each category opened and every guide's picture drawn |
| `Tools/tests/test_guideengine.lua` | The guide engine: which steps tick themselves, the step details the panel shows, collect notes ticking on the items in your bags |
| `Tools/tests/test_objectivepanel.lua` | The objectives panel: header, the ≡ menu (its items, Lock window, Transparency), nav row, step rows, the objective bars, resizing |
| `Tools/tests/test_options.lua` | The options window: its pages, and every control driving the setting it shows |
| `Tools/tests/test_stacking.lua` | Windows drawn in front stay in front, wherever they overlap |
| `Tools/tests/test_scrolling.lua` | The theme's scrollbar on the guide browser and the error log: carets, wheel, the ends of the range, the bar clear of the rows |
| `Tools/tests/test_minimap.lua` | The minimap button: drawn from the theme, its clicks, dragging round the edge, and the setting that hides it |
| `Tools/tests/test_navcallout.lua` | The navigation arrow's maths: bearing relative to your facing, distance and time |
| `Tools/tests/test_navigation.lua` | The waypoint addons and arrow switches, continent-map points, trainers found by name, and the zone a step is in |
| `Tools/tests/test_dungeonguides.lua` | The dungeon guides: current with their generator, listed, parsed, an entrance to point at, and no loose ends; a step for each boss after the way in, with a note and a death to tick it, the role lines your role setting picks, and the combat log's death line ticking the step |
| `Tools/tests/test_classguides.lua` | The class quest guides: current with their generator, listed, a milestone for each; parsed as every race of the class sees it -- its own chain and no other race's, no loose ends, ending with the quest the offer takes for its last; and the chains that must come out right (the Voidwalker by home city, the Charger's horse feed before the spirit) |
| `Tools/tests/test_professionsteps.lua` | Profession training: ranks waiting for their level, your side's trainers, tomes and Artisan quests, completing on skill and cap |

Everything must pass before you open a PR. **None of it proves the UI looks
right** — that still needs someone to load the addon on a 1.12 client and look
at it. Say in your PR whether you did. Before a release, the whole in-game pass
is in [docs/TESTING.md](docs/TESTING.md).

## Versions

Numbered as every Aegis addon is: `MAJOR.MINOR.PATCH`, and `0.x` until the
public release, when MAJOR becomes 1.

- **MINOR** for a new capability — something the addon could not do before.
  **PATCH** for a fix, wording, colour, layout, or a corrected calculation.
  **MAJOR** only for a change that breaks an existing setup with no migration.
- **One push, one MINOR**: a body of work that lands in one merge takes a single
  MINOR bump, and each change inside it is a PATCH under that.
- A bump touches **five places**: `Core.lua` (`AegisPathfinder.version`), the
  `.toc`'s `## Version`, the README's H1 and its "Something broken?" line, and a
  new [`CHANGELOG.md`](CHANGELOG.md) entry with its link reference at the
  bottom. `Tools/verify.py` checks they agree.
- Mark a release **restart** in the changelog when it adds or removes a `.lua`
  file in the `.toc`, or a texture in `media/`.
- Nothing under `Tools/` or `docs/` ships, so a change there alone is not a
  release and takes no bump.

## Code rules

**The client runs Lua 5.0.** No `#` length operator (`table.getn`), no
`string.gmatch` (`string.gfind`), no `select()` on varargs — the addon has its
own `AegisPathfinder.select` shim. `Tools/verify.py` enforces this for shipped
files; files excluded by `.pkgmeta` run on desktop Lua and are exempt.

**Match the surrounding code.** This is a long-lived fork with an established
idiom. Do not modernise code you are only passing through.

**No function may read more than 32 file-scope locals.** Lua 5.0 refuses to
load a file that breaks this ("too many upvalues"), taking the whole addon
with it, and the Lua 5.1 the tests run on allows 60, so nothing else notices.
Group constants into a table rather than adding another local beside a large
function -- `ObjectivesFrame.lua` keeps its layout in `G` for this reason.
`Tools/verify.py` checks it with `luac -l`.

**Colours, fonts and textures live in `Theme.lua`**, and nowhere else. If you
need a colour that is not there, add it there.

**Textures are generated.** Do not hand-edit anything in `media/` — change
`Tools/build/make_assets.py` and re-run it. See [media/README.md](media/README.md).

## Writing guides

See [docs/GUIDE_AUTHORING.md](docs/GUIDE_AUTHORING.md) for the step and tag
reference.

Two formats are supported. Hand-written guides use the pipe-delimited DSL.
Generated guides use QuestShell+ structured tables, because a generated corpus
diffs and validates far better that way.

**Profession guides in `Guides/Professions/` are generated.** Editing them by
hand will be overwritten. Change `Tools/build/convert_professions.py` or the source
data in `Tools/data/`, then regenerate. The crafting professions follow
CraftRoute's routes (`Tools/data/craftroute_routes.json`); Mining's route and
the trainers come from the reference document, with the ranks, tomes, Artisan
quests and First Aid's route and bandage colours in
`Tools/data/profession_training.json`. Herbalism, Skinning
and Fishing are built by `Tools/build/gathering_guides.py` from
`Tools/data/gathering.json`, which also gives each step of the Mining route,
per faction, where to mine its ore. They only send players to zones this addon
has a zone guide for:

```sh
python3 Tools/build/convert_professions.py
```

The routes are planned by CraftRoute's own planner, run outside the game on
its sample auction scan; only the routes it prints are kept. To plan them
again from a CraftRoute checkout (needs `lua5.1`), then regenerate the guides:

```sh
python3 Tools/build/import_routes.py <CraftRoute>
```

`Tools/build/craftroute_harness.lua` stands in for the game's API while it
runs. CraftRoute's scan has no listing for most things players gather
themselves, so a raw material with none is costed at three times its merchant
price; the guides that use one say so.

`Tools/data/gathering.json` is extracted from pfQuest (herb and ore nodes,
spawn points, zone names) and the CMaNGOS classic-db dump (the ore each vein
yields, skinnable creatures, fishing skill by zone, trainers, the Expert
fishing book, Nat Pagle's quest).
To refresh it, check both out and run:

```sh
python3 Tools/build/build_gathering.py --pfquest <pfQuest> <pfQuest-turtle> --cmangos <classic-db full dump .sql[.gz]>
```

**The dungeon guides' boss steps** come from `Tools/data/dungeon_bosses.json`,
written by `Tools/build/build_dungeon_bosses.py` from an InstanceJournal
checkout, the CMaNGOS classic-db dump and mangos-classic's ScriptDevAI
scripts; the notes on each fight are written by hand in
`Tools/build/dungeon_tactics.py`. See
[docs/GUIDE_AUTHORING.md](docs/GUIDE_AUTHORING.md#dungeon-guides):

```sh
python3 Tools/build/build_dungeon_bosses.py --instancejournal <InstanceJournal> --cmangos <classic-db full dump .sql[.gz]> --scripts <mangos-classic>/src/game/AI/ScriptDevAI/scripts
python3 Tools/build/build_dungeon_guides.py
```

**`ItemScoreData.lua` is generated** by `Tools/build/build_weights.py`. The
stat weights are this addon's own -- a leveling set and a 60 set for every
class and spec (one for the tanks), worked out from the game's formulas and
calibrated toward Pawn's Classic Era scales -- kept in
`Tools/data/stat_weights.json`. The tooltip patterns, soft caps and labels are
[OctoPawn](https://github.com/iGreed1993/OctoPawn)'s (MIT; its notice is
carried in the file), kept in `Tools/data/octopawn.json` by
`Tools/build/import_octopawn.py`, with its weights, which the stats the model
does not work out start from. With no arguments `build_weights.py` writes the
file from the two JSON files. To work the weights out again it needs a Pawn
checkout to calibrate against -- read where it lies, none of it copied in
(Pawn is CC BY-NC-ND) -- and a newer OctoPawn is picked up by checking it out:

```sh
python3 Tools/build/build_weights.py --pawn <path to Pawn>
python3 Tools/build/import_octopawn.py <path to OctoPawn>
```

**`GearData.lua` is generated** from the CMaNGOS classic-db dump and a
pfQuest-turtle checkout by
`Tools/build/build_gear_data.py --cmangos <dump> --pfquest-turtle <pfQuest-turtle>`:
what each quest reward sells for, which the Gear Advisor falls back on when no
reward is an upgrade; and for the Gear finder, what drops in each dungeon and
raid, which quests reward gear, what reputation vendors sell, and what the
professions make (`other_sources`) -- Turtle WoW's own from pfQuest-turtle, whose zones for them are listed
in `TURTLE_INSTANCES`, and Turtle's changes to the vanilla ones laid over the
CMaNGOS loot (`turtle_vanilla`).

**`MapOverlays.lua` is generated** from [pfUI](https://github.com/shagu/pfUI)'s
map reveal data (MIT; its notice is carried in the file) by
`Tools/build/build_map_overlays.py`: where each area's explored art sits on its
zone's map, for the guide browser's pictures, for the zones `GuideBrowser.lua`
knows. To pick up a newer pfUI, check it out and run:

```sh
python3 Tools/build/build_map_overlays.py <path to pfUI>
```

**Recipe data in `Crafting/` is generated** from
[CraftRoute](https://github.com/Kitymeowmeow-turt/CraftRoute)'s data files, with
its author's permission, by `Tools/build/import_recipes.py`. To pick up a newer
CraftRoute, check it out and run:

```sh
python3 Tools/build/import_recipes.py <path to CraftRoute>
python3 Tools/build/import_routes.py <path to CraftRoute>
python3 Tools/build/convert_professions.py
```

The second plans the profession guides' routes again (see **Writing
guides**), and the third rewrites the guides from them. Only the data is taken, rewritten into this addon's own one-line-per-recipe
format (documented at the top of each generated file); the planner in
`CraftPlanner.lua` is written separately. Reagents CraftRoute gives only by
item id are named from pfQuest's item database, cached in
`Tools/data/recipe_item_names.json`; pass `--pfquest <dir>` to refresh it.

**Filter tags.** The Auction House, Group and Dungeon switches act on `|AH|`,
`|P|GROUP|` and `|D|<code>|` tags. The RestedXP and RXP Hardcore guides always
carried them. The Optimized and zone guides carry the ones the owner approved:
`Tools/build/find_filter_candidates.py` listed the steps that probably wanted one
(`Tools/data/filter_candidates.json`), the answers are in
`Tools/data/filter_decisions.json`, and `Tools/build/apply_filter_tags.py` applies
them. A "yes" on a quest's own step tags every step of that quest; a "yes" on
a note or buy step that merely carries a quest id tags only that step; an
answer changed to "no" takes the tag off again. An Auction House tag belongs on
the step that sends you to the Auction House, not on a quest you can also do by
fishing, farming a drop or finding a vendor -- those are answered "steps", which
tags only the buy steps. Only a quest that needs an item a crafting profession
makes keeps the tag on the quest itself. Quests
you can only reach through a tagged one inherit its tag (worked out from
pfQuest's prerequisites with `--pfquest`, and kept in the decisions file).
When you add a step for a tagged quest, give it the same tag --
`Tools/tests/test_filtertags.lua` runs `apply_filter_tags.py --check`, which fails
if an approved tag has gone missing.

## Guide data and servers

Turtle WoW, OctoWoW, Capybara Paradise and RavenCraft share the quests and
places these guides use, so one set of guides serves all of them. If you find a
quest id or a location that differs on one server, report it with the server
and the step.
