## 1.0.1 first patch release

- Turtle quest `42045` (Tainted Rune) now carries `class = 256` in `Data/pfDB/quests-turtle.lua`, matching Tortoise WoW's Warlock-only requirement while preserving its Dwarf race mask and prerequisite 179.
- First-time quest acceptance keeps the native quest-log priming/fast-poll path validated during post-1.0 testing.
- World-map objective glow defaults OFF with the existing one-time migration from the former default ON state.
- World Map density refresh prioritizes the currently displayed map zone, then the player's minimap zone, before background prepared-map work.
- Official release metadata is version `1.0.1`; future patch releases follow `1.0.2`, `1.0.3`, and so on.

## 1.0 final quest-option and branding pass

- Added character option `showPvPRelatedQuests` (default ON), matching Questie 6's PvP quest visibility semantics for map/minimap markers. OFF hides available PvP starts, active PvP objectives, and PvP turn-ins.
- Reordered Quest Options so Event follows Repeatable and added the requested `Show PVP Related Quests` toggle.
- Final release metadata is version 1.0 and the startup chat message no longer includes a Beta suffix.

## Beta 1.6 world-map visibility scope correction

- `showAvailableQuestsWorldMap`, `showCompletedQuestsWorldMap`, and `showSpecialQuestsWorldMap` are continent/world-overview filters only.
- `showAvailableQuestsWorldMap` is the broad available/item-start role gate; `showCompletedQuestsWorldMap` is the broad turn-in role gate. Special markers additionally require `showSpecialQuestsWorldMap`.
- Selected zone and city maps do not apply those overview filters to available/item-start/turn-in quest markers.
- Zone/city quest marker visibility remains governed by the ordinary available/completed/item-start controls.
- `showSpecialQuestsWorldMap` remains default OFF.

## Beta 1.3 world-map special markers / tracker defaults / scrollable rewards

- `showSpecialQuestsWorldMap` defaults OFF and controls special blue/red/green quest pickup/turn-in markers independently from ordinary yellow quest markers.
- Tracker defaults are font size 11, 30 visible rows, background opacity 0.
- Rewards are children of the quest-detail scroll content and scroll naturally after Turn In.

- Internal addon folder is permanently `Questie-Octo` and the TOC is permanently `Questie-Octo.toc`; ZIP filenames carry the version instead.
- Version metadata: `Beta 1.3`.
- Quest 7946 (`Spawn of Jubjub`) is a conditional world-interaction offer and is not advertised as a static Morja pickup.
- Unavailable-reason strings were shortened for player readability.
- Rewards are rendered inside the scrollable quest-detail content with money and native item hyperlink buttons.

## Beta 1.1 post-package corrections

- Darkmoon event IDs 4 and 5 are treated as one logical active Faire for quest
  eligibility/presentation during the six active days. The DB assigns shared
  Faire quests to both IDs even though those NPCs exist at both locations.
- Auctioneer, Banker, and Mailbox markers use a hidden 0.90 intrinsic multiplier; global scale 1 remains
  the user-facing default.
- General options expose direct World Map Visibility controls for
  Show Quests on the World Map, Show Special Quests on the World Map, and Show Flight Master on the World Map.

# Quest system infrastructure audit — Beta 1.1

## Full Beta 1.1 regression audit (2026-08-14)

- 100 Lua files syntax-load cleanly under the supplied Lua compatibility checker.
- TOC/XML/file references resolve; addon identity is `Questie-Octo`, author `Questie-Octo`, version `Beta 1.1`.
- No unrelated generated data, code or assets are present in the addon package.
- pfDB access remains confined to the Database/Data boundary.
- `pfquest_node.tga` and Questie 6 `repeatable.blp` still match the supplied authoritative assets byte-for-byte.
- PvP Type-41 enrichment and the verified Blood Ring Type-0 corrections are present; marker priority remains PvP > Repeatable > Event > Normal.
- Quests browser search no longer depends on the shared scheduler. It performs a bounded direct scan of the already-cached lowercase title index and caps visible results at 100.
- General-tab World Map controls are flat AceConfig entries rather than an inline nested group for Ace3v/Vanilla compatibility.
- Seasonal event presentation is emitted only for a currently scheduled/active seasonal quest; repeatable and PvP presentation still take priority.

## Reference sources used

This pass was checked against the user-supplied reference archives rather than
an online mirror:

- current `pfQuest.zip` base source/database;
- current `pfQuest-turtle.zip` Turtle overlay/database;
- `Questie-v6.0.0.zip` for Questie presentation behavior/artwork;
- the supplied Turtle server source/database snapshot for quest requirements,
  rewards and game-event scheduling.

The normal pfQuest/Turtle entity and coordinate database remains the primary
static data source. Questie-Octo layers its own normalization/enrichment after
that data instead of maintaining a second independent quest database.

`UI/Icons/pfquest_node.tga` is byte-for-byte identical to pfQuest's `img/node.tga`.
`UI/Icons/repeatable.blp` is byte-for-byte identical to Questie 6.0.0's
`Icons/repeatable.blp`.

## Authority chain

1. pfQuest + Turtle + Octo static data — quest/entity/source truth.
2. `DatabaseAPI` — raw-data boundary for the rest of the addon.
3. `QuestModel` — normalized quest semantics (`lvl`, `min`, restrictions,
   prerequisites, repeatability and event membership).
4. Runtime truth:
   - `QuestLog` — active/objective/failure state;
   - `Completion` — rewarded/completed history;
   - `EventAvailability` — current server event state.
5. `AvailableQuests` — transactional availability snapshot.
6. `Objectives` / `ItemStarts` — source relationships.
7. `Nodes` — normalized map-node snapshot.
8. `PreparedMap` — shared immutable render plan.
9. World Map / Minimap / Tracker / Quests — presentation only.

No first-party runtime module outside `Database/` reads raw `pfDB` directly.

## Availability invariants

- `lvl` is display/difficulty information only.
- `min` is the minimum-level acceptance gate.
- The old user-facing Level Above Player option is gone.
- Active/completed state, chain prerequisites, exclusivity, race, class,
  Hardcore, skill/profession, reputation, event activity, level bounds,
  repeatability and valid starters are evaluated before publication.
- `Show Low-Level Quests`, `Show Event Quests` and `Show Repeatable Quests` are
  display/availability preferences, not replacements for server truth.
- Repeatability and event membership are independent properties.

`AvailableQuests:GetUnavailableReason()` exposes the first authoritative failing
condition to the Quests browser. It can identify disabled/not-currently-
obtainable quests, active/completed state, chain/exclusive prerequisites, race,
class, Hardcore, skill, reputation, inactive event, level bounds, hidden
repeatables, timed-quest conflicts and quests with no valid starter/source.
Unknown server-only conditions are reported as unknown instead of guessed.

## Completion and repeatables

Completion initialization runs the server completed-quest query protocol before
reading completed history, with the Turtle quest-status path retained as a
fallback.

Repeatable flags come from the server-derived enrichment or trustworthy live
observation. One-and-done repeatables can opt into `hideAfterFirstCompletion`;
`CLUCK!` uses that rule.

`CLUCK!` (3861) is also a scripted/conditional offer rather than a normal static
Chicken pickup: `/chicken` temporarily exposes the quest. To keep the quest
discoverable without covering every Chicken spawn, Questie-Octo deliberately uses
one representative Westfall Chicken at 55.6,30.9 as the static pickup/turn-in map
marker. The tooltip explains that `/chicken` is required. This does not change
server truth: other Chickens can still trigger/complete the scripted interaction.
The server repeatable flag remains intact for completion logic, but the representative
marker uses ordinary yellow quest presentation instead of blue repeatable artwork.
After the first completion, `hideAfterFirstCompletion` removes the discovery marker.

The cloth donation chain is intentionally not flattened into one repeatable
category: Wool/Silk/Mageweave/Runecloth donation steps are one-time quests, while
the `Additional Runecloth` follow-ups carry the repeatable flag.

Questie 6 presentation is used for repeatables: available repeatable starters
use the authentic blue `repeatable.blp`; repeatable turn-ins use Questie's
ordinary completion question-mark artwork. If a quest is both repeatable and an
event quest, PvP presentation wins first; otherwise repeatable presentation wins instead of turning the marker green.

## Event activity and presentation

The pfQuest quest `event` field means membership in a server game-event group.
It does **not** by itself mean either “active now” or “draw this quest green.”
Questie-Octo now resolves those concepts separately.

`Data/EventSchedule.lua` is a compact projection of the supplied Turtle
`game_event` table. Ordinary scheduled events are evaluated against realm wall
clock. Continuous release/content gates (`length >= occurrence`) remain usable
for availability but do not receive seasonal-event presentation. This prevents
permanent content such as event 159 (`DM Release : Cloth turning NPC`) from
making normal cloth donation quests green.

Darkmoon Faire uses the manually verified Turtle 14-day cycle, anchored at
2026-08-13:

- six days Elwynn (Thursday through Tuesday);
- one Wednesday construction day;
- six days Mulgore (Thursday through Tuesday);
- one Wednesday construction day;
- repeat indefinitely.

Major annual festivals use `Data/CalendarEventRules.lua`, transcribed from the
2026 in-game Turtle calendar. Only visible event text counts. Raid Reset,
roadmap/release announcements and graphic-only calendar cells are ignored.
Known calendar windows are authoritative for quest visibility; clicking a
festival NPC outside its verified window cannot reactivate that festival.
Unknown/custom event IDs still require runtime evidence.

A few quest event IDs exist in the current pfQuest/Turtle quest data without a
matching row in the supplied `game_event` table. Event 172 is explicitly
handled as a persistent compatibility gate because the authoritative quest data
uses it for Molten Core attunement. Missing true-event IDs 26, 99, 166 and 171
retain event presentation but require runtime observation rather than being
assumed active globally.

## Map/node invariants

- Availability, node and prepared-map rebuilds publish transactionally; the
  previous complete snapshot remains visible until its replacement is ready.
- Full Nodes use pfQuest's exact `node.tga` and **native 14 px pfQuest baseline
  at global scale 1.0**.
- Full Nodes keep the requested additional 15% transparency and subdued color.
- There is no separate Full Node or category scale setting. Only global World
  Map and global Minimap scale remain.
- Global scaling changes frame dimensions only; it cannot replace Full Node
  artwork with Questie objective artwork.
- Full-node semantic state survives visual refreshes/rescaling.
- World map and minimap retain a hidden 1000-node emergency cap.
- General -> Show All Quests on World Map defaults enabled. It controls available pickup/item-start presentation on the World Map only; active objectives/turn-ins, minimap, and tracker are unaffected.
- Distance fading is absent.
- Object-ID display is absent; Quest, NPC and Item IDs remain optional.

## Quests browser

The browser remains a fixed native frame rather than a large AceGUI result tree:

- 18 recycled result rows;
- no full-database scan merely for opening the browser;
- Options-to-Quests handoff is deferred until after AceConfig's execute refresh,
  then Questie Options and the Game Menu are explicitly hidden;
- searches only run on Enter/Search;
- search titles are lowercased/cached during the existing incremental database
  index build;
- full text/ID searches run in 33-quest scheduler slices (about 32% more work per
  frame than the previous 25-row search while remaining frame-sliced);
- visible results remain capped at 100;
- Available/Active/Completed no-query views use their state tables directly;
- closing the browser invalidates an outstanding search generation.

Unavailable rows explain *why* the quest cannot currently be taken in the right
pane.

`Data/QuestRewards.lua` is a compact projection of the supplied authoritative
Turtle `quest_template` reward fields. The right pane shows positive money
rewards in gold/silver/copper text, guaranteed reward items as native clickable
item hyperlinks, and choice rewards under `Choose one:`. No reward icons are
created. Item links use the same Vanilla `SetItemRef` / `GameTooltip:SetHyperlink`
pattern as pfQuest's item browser.

## Static audit completed for Beta 1.1

- 99 bundled Lua files pass a Lua parser syntax-load check.
- Every TOC file reference exists.
- Every XML Include/Script reference exists.
- All literal settings reads/writes resolve to defined defaults.
- No first-party runtime module outside `Database/` directly reads `pfDB`.
- No runtime distance-fading option/path remains.
- No user-facing Level Above Player setting/path remains.
- No Completion tracker-sort mode remains.
- No Object-ID option/render path remains (only stale SavedVariable cleanup).
- Only global Map and Minimap scale sliders remain.
- Full-node 1000-pin safety caps remain in both renderers.
- pfQuest Full Node and Questie repeatable assets match their supplied reference
  files byte-for-byte.
- 33 of the 34 raw loaded pfQuest/Turtle DB files are byte-identical to their
  supplied source files; the remaining Turtle `patchtable.lua` is the existing
  Questie-Octo compatibility adaptation that applies the overlay without
  loading pfQuest's addon UI/runtime.

## Recommended in-game regression pass

1. Open **Quests** from Questie Options and confirm Options/Game Menu disappear.
2. Search `defias`; compare response time and inspect several Unavailable rows.
3. Select quests with money, fixed-item and choice-item rewards; hover/click the
   hyperlink text.
4. Compare a normal cloth donation with an `Additional Runecloth` follow-up.
5. Verify `Give Gerard a Drink` uses the authentic blue repeatable pickup icon.
6. Verify Darkmoon immediately after `/reload` and again across its Wednesday
   installation transition.
7. Move global Map/Minimap scale repeatedly while Full Nodes are visible.
8. Recheck failed timed quests, reputation gates and multi-step prerequisites.


## 0.3.6 corrective notes

- Event availability now mirrors pfQuest: a quest's `event` membership does not
  locally gate availability. The Show Event Quests toggle is the display gate.
  The separate presentation classifier still prevents permanent Turtle content
  gates such as event 159 from being painted as festival quests.
- Quests search uses the database's already-cached lowercase titles in 768-ID
  bounded slices (roughly nine frames for the entire current DB) and exact numeric
  quest IDs bypass the scan entirely.
- Authoritative donation verification: 80374 (Additional Runecloth: Silvermoon
  Remnants) and 80379 (Additional Runecloth: Revantusk Tribe) are repeatable.
  80374 has server minimum level 50; it is correctly unavailable to a level-34
  character. Goblin donation quests 41115 (Cartel Gold Donations, min 30) and
  41123 (Donations to Vizlow, min 1) are repeatable and level-eligible at 34.


## 0.3.7 conservative event beta notes

- Fresh installs default `showEventQuests=false`; existing character choices are
  not overwritten.
- `IsPresentationEvent` separates true festival presentation from permanent
  game_event release/content gates.
- Available festival markers require both the user toggle and
  `EventAvailability:IsActiveForQuest()`. Scheduled/hardcoded event truth is
  preferred; unknown schedules require runtime observation.
- Runtime observation triggers a bounded availability refresh only on the first
  inactive-to-active transition.
- Active quests already in the quest log bypass available-quest filtering and
  therefore retain objectives/turn-ins even if event display is disabled.


## 0.3.8 curated Turtle calendar notes

The manually verified annual windows are:

- Love is in the Air: February 1-16
- Lunar Festival: February 16-March 4
- Noblegarden: April 17-May 8
- Midsummer Fire Festival: June 21-July 12
- Brewfest: September 20-October 6
- Harvest Festival: October 1-8
- Hallow's End: October 20-November 2
- Feast of Winter Veil: December 3-January 14

Darkmoon Faire is intentionally separate from the annual calendar and uses the
anchored alternating 14-day rule described above. Roadmap names such as
Frostmane Hollow, Windhorn Canyon, Dragonmaw Retreat, Northwind, Stormwrought
Ruins, Moonwhisper Coast, Phase 1/2 and similar release notices never affect
quest availability.

## Beta 1.1 event standby policy

Event membership is not itself proof of a seasonal event. Beta 1.1 uses an
explicit three-way classification:

- verified non-seasonal/content gates: ordinary quest availability/presentation;
- verified seasonal events: gated by the curated annual calendar, the anchored
  Darkmoon cycle, or a separately verified narrow timer;
- unknown/unverified event IDs: standby and therefore not published as available
  quest markers. Active quests already accepted by the player remain visible.

Event 159 is explicitly verified as the cloth-turn-in content/release gate and
is not seasonal. Repeatability remains independent of event classification.

## Beta 1.1 package identity

- Install folder: `Questie-Octo`
- TOC file: `Questie-Octo.toc`
- Display title: `Questie-Octo`
- Author: `Questie-Octo`
- Version: `Beta 1.1`

The versioned install folder is intentional for this beta package. First-party
texture paths were updated to the same folder name and validated before packaging.

## PvP quest classification

Questie-Octo preserves the authoritative Turtle quest `Type` for PvP quests.
`Type == 41` is the canonical PvP classification used by Questie 6.

Presentation priority for quest pickup/turn-in markers is:

1. PvP (red)
2. Repeatable (blue)
3. verified Event (green)
4. Normal (yellow)

The supplied Turtle source currently reports Blood Ring quests 41107-41110 as
Type 0 even though their objectives/rewards explicitly identify them as PvP.
Questie-Octo corrects only those verified rows locally to Type 41; Type 0 is
not broadly reinterpreted.

## Beta 1.1 Darkmoon live-offer correction

Live Elwynn Faire cross-checks on 2026-08-14 confirmed that Turtle reuses the
same Darkmoon hand-in NPCs/quests across Elwynn and Mulgore while pfQuest splits
those shared rows between event IDs 4 and 5. The verified starter set is Silas
Darkmoon (14823), Gelvas Grimegate (14828), Yebb Neblegear (14829), Kerri Hicks
(14832), Chronos (14833), and Rinling (14841).

For quests tagged event 4/5 and started by those NPCs, Questie-Octo treats the
Faire as one logical active event. During an active Faire it keeps completion,
race/class, level, max-level, timed and repeatable-option checks, but does not
let stale pfQuest Darkmoon reputation/chain metadata suppress an offer that the
live Turtle quest dialog exposes. Silas's one-time Torta's Egg remains hidden
once historical completion says it was rewarded.

### Darkmoon logical event alias

Turtle/pfQuest quest rows use both `event = 4` and `event = 5` for quest offers that are shared by the same Darkmoon Faire NPCs in both Elwynn and Mulgore. Questie-Octo preserves the authoritative value as `rawEventID`, but normalizes runtime `eventID` 5 to logical event 4. Availability and presentation therefore see one `DARKMOON_FAIRE` event; the anchored 14-day schedule and NPC coordinates determine the physical location. Construction events 23/24 remain distinct.

## Restless / custom Dun Morogh map note

`Restless` (41640) must be interpreted against Turtle/Octo's custom Dun Morogh, not
the stock Vanilla artwork/boundary assumptions. The current Dun Morogh map visibly
includes custom southeastern terrain such as Rugford's Mountain Rest. Durmir Rugford
(62199) has map representations in both Dun Morogh (1) and Grim Reaches (5602).
Hurl Cinderfist (62200), the 100% source for Durmir's Belongings (41686), now also
has both representations: Dun Morogh 83.2/70.8 and Grim Reaches 4.1/92.0. Both are
the same live world spawn transformed through the two overlapping WorldMapArea
bounds. Keep both so the active objective is visible on Turtle's expanded Dun
Morogh map as well as Grim Reaches; do not collapse these coordinates based on
stock Vanilla Dun Morogh assumptions.

## Turtle low-level gray available marker

Questie-Octo 1.0.77 adds a gray available `!` presentation for ordinary
available quests and ordinary item-start quests using the Turtle-specific
accepted boundary:

- player level <= quest level + 25: normal yellow available marker;
- player level >= quest level + 26: gray available marker.

The boundary is strict: exactly +25 remains yellow and +26 becomes gray.

The source basis is Turtle's custom quest XP rule in Tortoise
`src/game/QuestDef.cpp`, which retains full quest XP through `qLevel + 25`
before reducing it at +26 and beyond. That server function computes XP, not
client icon color directly, so the project does not claim it is itself the
native marker-color implementation. It was adopted because it matches the
observed Turtle native quest behavior and replaces the stock Questie
`GetQuestGreenRange()` assumption that was contradicted in-game.

Special presentation remains higher priority than gray: PvP stays red,
repeatable stays blue, and verified event/seasonal stays green. CLUCK! (3861)
is the deliberate exception already chosen by the project: its single
representative discovery marker stays ordinary yellow rather than repeatable
blue or low-level gray. Turn-in `?` markers are unchanged.

This gray classification is presentation-only and remains independent from the
`Levels Below` visibility slider. Level-up refreshes rebind visible Map and
Minimap marker textures without rebuilding quest data or map geometry.


## 1.0.78 zone-wide rare item-start tooltip compaction

The representative-marker rule for item-start sources below 0.50% must remain
representative in the tooltip as well as on the map. Previously the map correctly
collapsed those sources to one marker per quest/item/zone, but hovering that marker
still printed every represented creature type and spawn count. For large world-drop
items such as Pendant of Myzrael this could create a tooltip taller than the screen
and hide the actual quest/item information.

Zone-wide representative tooltips now show only a compact aggregate source count,
the quest, and the actual represented minimum/maximum drop-rate range. The underlying
source list remains unchanged. Ordinary non-zone-wide clustered item-start tooltips
still list their nearby source creatures normally.

## 1.0.79 representative-tooltip wording cleanup

Removed the redundant `One zone marker represents item-start sources below 0.50%.`
line from zone-wide rare item-start tooltips. The representative threshold and all
source/drop data remain unchanged; this is tooltip presentation only.

## 1.0.80 native Quest Log tracked check + empty tracker hiding

The newest direct in-game Turtle/Octo `QuestLogFrame.xml` and
`QuestLogFrame.lua` confirm that the small `UI-CheckBox-Check` beside a quest
title is native Quest Log presentation. Native `QuestLog_Update()` shows the
`QuestLogTitleNCheck` region when `IsQuestWatched(questIndex)` is true.

Questie-Octo intentionally keeps its own tracker state instead of relying on
Blizzard's limited native watch list. The Quest Log enhancement layer therefore
post-processes the existing native check region after Blizzard updates the row:
tracked Questie-Octo quests show the native check artwork, untracked quests do
not. The check position is recomputed after the `[level]` title prefix so it
does not overlap the modified title. This is presentation synchronization only;
Questie-Octo does not replace the Quest Log skin or invent a new tracked icon.

The custom tracker now hides its entire frame when its ordered tracked-quest
list is empty. The previous `No tracked quests.` placeholder row is removed.
When a quest becomes tracked again, the normal `TRACKER_STATE_CHANGED` render
path shows the tracker automatically.


## 1.0.81 shared CallbackHandler isolation / Spy compatibility

A supplied Spy 4.5.0 test exposed an inter-addon Ace3 collision when Spy and
Questie-Octo were loaded together.  Both addons shipped a LibStub library named
`CallbackHandler-1.0` at minor 6.  Because Questie-Octo normally loads first,
Spy's own CallbackHandler file was skipped by LibStub and Spy inherited
Questie-Octo's private Lua-5.0 translation instead.

That translation did not preserve the Ace3v/Turtle explicit-argc callback ABI
used by the surrounding Vanilla Ace libraries (`Fire(eventName, argc, ...)`).
Spy's later `Spy.MainWindow` nil error was therefore a downstream initialization
symptom, not a `MainWindow` global-name collision with Questie-Octo.

Questie-Octo now registers its compatibility handler as the private
`QuestieOcto-CallbackHandler-1.0` library and AceConfigRegistry consumes that
private name.  The private handler also restores the explicit-argc Ace3v ABI.
Questie-Octo therefore no longer publishes/replaces the shared global
`CallbackHandler-1.0`; addons such as Spy are free to load their own compatible
copy regardless of addon load order.

The other overlapping Ace components were checked against the supplied Spy
snapshot: Questie-Octo's AceCore and AceGUI files are byte-identical to Spy's
same-minor copies. AceConfigRegistry is the same Ace3v implementation except
for its deliberate private CallbackHandler dependency above. Spy carries a
newer AceConfigDialog and therefore upgrades that library normally through
LibStub.

## 1.0.82 optional native Quest Log tracked checkmarks

The 1.0.80 restoration of Turtle/Vanilla's native `UI-CheckBox-Check` beside
Questie-Octo-tracked Quest Log rows is now opt-in. The Tracker options expose
`Show Quest Log Checkmarks` directly between `Auto Track Quests` and
`Show Completed Quests`, and the new setting defaults OFF.

Disabling the option hides only the Quest Log row check artwork; it does not
untrack quests, alter auto-tracking, or change the custom tracker. Enabling it
reuses the same native Blizzard/Turtle check region and the existing
Questie-Octo tracking state. Changing the option refreshes an open Quest Log
immediately through the tracker-setting message path.

## 1.0.83 updated pfQuest reference audit — safe server-truth integration

The current pfQuest references were replaced by newer user-supplied snapshots:

- `pfQuest-classicAPI-octo(5).zip`
  SHA-256 `6f516c3d899bade909de1e79ddd55bd6f3eade9017541fdf3e5bb5c58c723d34`
- `pfQuest-octo-master(4).zip`
  SHA-256 `91a663eaed749a5a2bbe8404381d4a897fe5583b9f05a765a8d42c2bcdcdec19`

`pfQuest-octo-master(4)` is now the primary Octo database reference. Its
generated Turtle DB files are byte-identical to the previous supplied master;
the meaningful new database knowledge is in `overwrites.lua`, covering
1.0.11-1.0.13.

### Safe corrections integrated now

The following changes are additive or direct eligibility truth and were
cross-checked against the current supplied Turtle `quest_template` rather than
copied blindly from pfQuest.

**35 stale class/race restrictions removed after the final merge**

The server reports the corresponding field as unrestricted (`0`). The updated
pfQuest master tries to remove these fields before its base/Turtle merge using
`entry[field] = nil`; that does not delete the inherited base field. Questie-Octo
therefore clears them explicitly in the post-merge enrichment layer.

- class clear: `792`
- race clear:
  `1386, 6963, 8302, 8314, 8732, 8915, 8931, 8932, 8933, 8934, 8935,
  8937, 8938, 8940, 8941, 8942, 8944, 8948, 8949, 8962, 8964, 8965,
  8966, 8967, 8968, 8969, 8985, 8988, 8989, 8990, 8991, 8992, 9014,
  9378`

This is a server-eligibility correction only; no objectives, prerequisites, or
presentation priority are changed by the field clear itself.

**9 missing objective items appended**

Current Turtle `quest_template` directly contains these required items. They are
added through `objectiveExtra` with append-unique semantics so existing
objective data is retained:

- `3962` -> item `11522`
- `8966` -> `22049`
- `8967` -> `22050`
- `8968` -> `22051`
- `8969` -> `22052`
- `8989` -> `22049`
- `8990` -> `22050`
- `8991` -> `22051`
- `8992` -> `22052`

This also avoids the updated pfQuest master's edge case where quest 3962 has no
Turtle-side `obj` table at the point its append loop runs.

**Poisoned Water (6804) actionable-source guidance**

The authoritative live item objective remains `Discordant Bracers` (17309).
Those bracers belong to temporary `Discordant Surge` (13279), whose database
entry has no natural world spawn. The quest text instructs the player to use
Aspect of Neptulon on poisoned elementals; the updated Octo audit identifies
`Blighted Surge` (8519), which has the real Eastern Plaguelands spawns.

Questie-Octo does not invent a second live kill objective. Instead,
`ResolveItemSources(questID,itemID)` adds creature 8519 as **presentation-only
source guidance** for quest 6804 / item 17309 while preserving the actual item
objective and progress mapping.

### Deliberately deferred — FULL CHECK REQUIRED

The updated Octo master contains a non-additive 1.0.12 replacement table for 38
quests. Those entries can remove existing targets as well as add/replace them,
so they are **not** imported as part of this safe pass.

Deferred IDs:

`974, 1435, 3520, 5163, 5206, 5441, 5561, 5581, 6661, 6681, 7029, 7041,
7629, 8249, 8746, 8762, 9015, 9165, 9257, 9269, 9270, 9271, 40056, 40099,
40124, 40141, 40174, 40179, 40713, 41243, 41312, 41383, 41659, 41684,
41694, 80207, 80703, 80722`

Known reasons this batch must be handled semantically rather than copied:

- the replacements are destructive/non-additive and can remove useful pins;
- `5163` and `8762` are absent from the updated master's Turtle patch table at
  the point its replacement loop executes, so those advertised replacements do
  not actually apply there;
- later blocks supersede some 1.0.12 rows (notably `40124`, `40713`, and
  `80207` needs final-state review);
- current server/base evidence for some custom quests is split across base dumps
  and later database updates;
- every replacement should be checked for final quest objective IDs, required
  item/source semantics, actual spawn/source availability, and later
  Questie-Octo-specific corrections before removing an existing target.

**Mandatory reminder rule:** whenever Sandrea next asks for a **full check**,
**full database check**, **full audit**, or similar broad data verification,
surface this deferred 38-quest replacement batch first and explicitly ask/confirm
that it is included in that audit. Do not let a future general audit forget this
pending work.

### Updated classicAPI diagnostic lesson

The updated `pfQuest-classicAPI-octo(5)` changes `/db checkdb` so a quest with no
`obj` table but a valid end relation is recognized as a delivery/talk-to quest
whose turn-in pin is legitimate guidance. Questie-Octo audit rule: **no `obj`
does not by itself prove a quest is broken**. Check quest text, start/end
relations, and live/server objective truth before inventing an objective.


## 1.0.84 Spy config-library isolation and source-faction availability

### Spy follow-up: CallbackHandler isolation alone was not sufficient

The supplied Spy 4.5.0 retest still produced downstream errors when
Questie-Octo was loaded, including:

- `Spy.lua:2228` — `Spy.MainWindow` nil;
- `Colors.lua:224` — nil frame;
- `Spy.lua:1862` — `InterfaceOptionsFrame_OpenToCategory` nil.

The second source audit found another equal-version LibStub collision left by
1.0.81: both addons publish `AceConfigRegistry-3.0` minor 16, but
Questie-Octo's copy had been deliberately modified to consume the private
`QuestieOcto-CallbackHandler-1.0`. When Questie-Octo loads first, Spy's own
minor-16 registry is skipped. Spy's newer AceConfigDialog (minor 65) then runs
against Questie-Octo's project-specific shared registry rather than the registry
shipped with Spy. This can abort Spy's option/initialization path before
`Spy:CreateMainWindow()` completes; the later MainWindow/Colors errors are
therefore downstream symptoms rather than proof of a global `MainWindow` name
collision.

Questie-Octo now keeps all project-modified AceConfig state private:

- `QuestieOcto-AceConfigRegistry-3.0` minor 16;
- `QuestieOcto-AceConfigDialog-3.0` minor 63;
- `QuestieOcto-CallbackHandler-1.0` minor 6.

`UI/Options.lua` uses only those private registry/dialog majors. Questie-Octo no
longer registers either standard `AceConfigRegistry-3.0` or standard
`AceConfigDialog-3.0`, so Spy can load both of its own copies independently of
addon load order. As an additional shared-library hygiene check, Questie-Octo's
LibStub and equal-version AceGUI Slider are now byte-identical to the supplied
Spy copies. AceCore and the AceGUI core were already byte-identical; every other
shared AceGUI widget for which Questie-Octo could prevent Spy's version from
loading is also byte-identical after this pass. Spy itself is not modified.

The remaining verification is an in-client Spy + Questie-Octo login test; the
WoW runtime cannot be executed in the build environment.

### Quest-giver faction is effective quest availability

A Horde tester on Moonwhisper Coast reported Alliance Sunsworn Camp quests as
`(Available)` on both map and world-hover tooltips even though the NPCs were
hostile and would not offer them. The raw Turtle quest rows for examples such as
42064/42065/42068 have `RequiredRaces=0`, so quest-level race filtering alone
cannot solve this.

The pfQuest unit data already contains the missing effective restriction:

- Andanil Sunsworn (63119) — `fac = "A"`;
- Rhys Dawnbreeze (63122) — `fac = "A"`;
- the surrounding Sunsworn quest givers in that camp likewise carry Alliance
  source-faction metadata.

The updated `pfQuest-classicAPI-octo(5)` reference explicitly uses starter
creature/object `fac` (`A`, `H`, `AH`) as an inferred quest race/faction mask
when the quest itself has no race mask, and filters starter nodes against the
player faction. Questie-Octo had the faction data and already used it for town
service markers, but did not apply it to ordinary available quest starters.

1.0.84 therefore adds a general source-faction eligibility layer:

1. explicit quest race/class masks remain authoritative and are checked first;
2. an item starter remains a valid faction-neutral alternate pickup path;
3. creature/object starters with missing faction metadata fail open;
4. when direct starter faction metadata is known, the quest is unavailable if
   every direct starter excludes the player's faction;
5. individual available creature/object nodes are also filtered, so a quest
   with mixed-faction alternate starters shows only the usable starter(s);
6. the same individual filtering is applied to the immediate zone-bootstrap
   path, preventing a stale wrong-faction pin before the full node rebuild;
7. active quest objectives/turn-ins are not rewritten by this availability
   correction.

This is a presentation/eligibility correction using existing pfQuest source
truth; it does not invent race masks in the generated quest database.

## 1.0.85 long rare respawn time formatting

Static rare respawn metadata is still sourced from the existing creature DB and
is not inferred from live kills. The tooltip formatter now keeps values through
60 minutes in the existing minute form, but converts values **above** 60 minutes
to compact hour/minute text. This applies to the same shared rare-source display
path used by dedicated Rare Monster nodes and rare sources shown inside
item-start quest tooltips.

Boundary/examples:

- 60 minutes -> `~60 min`
- 61 minutes -> `~1h1m`
- 90 minutes -> `~1h30m`
- 320 minutes -> `~5h20m`

If the underlying static respawn contains a non-zero seconds remainder, that
remainder is retained after the hour/minute portion. No respawn data, rare-node
eligibility, or item-start source logic is changed.

## 1.0.86 short-respawn seconds formatting

Rare/static respawn display now includes seconds only when the full recorded
respawn is **strictly below 300 seconds (5 minutes)**. At 300 seconds or above,
the seconds remainder is intentionally omitted. Long timers continue using the
1.0.85 hour/minute conversion.

Boundary/examples:

- 25 seconds -> `~25s`
- 2 minutes -> `~2 min`
- 2 minutes 30 seconds -> `~2m30s`
- 5 minutes -> `~5 min`
- 5 minutes 20 seconds -> `~5 min`
- 60 minutes -> `~60 min`
- 61 minutes 45 seconds -> `~1h1m`
- 90 minutes 15 seconds -> `~1h30m`
- 10h33m20s -> `~10h33m`

This remains presentation-only. A recorded respawn of `0` is still treated as
unknown/unavailable static timing and produces no tooltip line. The current
pfQuest Turtle data records `0` for the nearby Silithus rare-elites Xil'xix
(15286), Aluntir (15288), and Arakis (15290). The supplied current Tortoise
server source contains their creature templates but no ordinary static creature
spawn rows for those IDs, so Questie-Octo must not fabricate a respawn timer.

### 1.0.87 — centered tooltip tilde markers

User-facing tooltip tildes use the centered `∼` glyph rather than the raised ASCII `~`. This applies to rare/static respawn approximation text and item-start drop-rate ranges such as `0.02%∼0.08%`. No respawn data, timing thresholds, drop-rate data, or item-start rules changed. Seconds remain visible only below five minutes.


### 1.0.88 — tooltip font-safe range and respawn formatting

The current in-game tooltip font does not render the mathematical `∼` glyph used in 1.0.87. That made the approximation prefix disappear and, more importantly, made item-start ranges run together. 1.0.88 therefore avoids that unsupported glyph entirely. Rare/static respawn text is shown directly (`15h`, `2h30m`, etc.), while item-start drop-rate ranges use a plain ` - ` separator (`0.007% - 0.20%`). The existing timing rules remain unchanged: seconds are shown only below five minutes, and hour formatting is used above sixty minutes. No respawn or drop-rate data changed.


### 1.0.89 — font-safe approximation and range wording

Do not use ASCII `~` or Unicode approximation/tilde glyphs in user-facing
tooltips. The ASCII glyph sits too high in the current game font, while the
mathematical `∼` glyph is not rendered at all. Rare/static respawn tooltips
therefore use the explicit ASCII-only wording `Respawn: approx. <time>` (and
`[Rare] Respawn: approx. <time>` for rare item-start sources). Item-start
drop-rate ranges use `<minimum>% to <maximum>%`. Single-value drop rates remain
unchanged. This rule is presentation-only and must not alter respawn/drop data
or threshold semantics.


### 1.0.90 — true middle ASCII tilde overlay

User-facing rare respawn approximation and item-start drop-rate ranges return
to compact `~` notation. Do **not** use the unsupported Unicode mathematical
tilde and do not use the 1.0.89 `approx.`/`to` wording. Instead, the runtime
line reserves two normal spaces and Questie-Octo overlays the guaranteed ASCII
`~` at that character position using the same tooltip font, shifted downward
by two pixels. This gives the requested visually centered/middle tilde without
changing the font globally or depending on an unavailable glyph.

The overlay pool must be hidden/reset whenever Questie-Octo clears and rebuilds
a tooltip. This rule is presentation-only; timing/drop-rate data and all rare
or item-start eligibility rules remain unchanged.


## 1.0.91 tooltip tilde presentation
The stock FRIZQT ASCII `~` sits visibly high and the mathematical tilde glyph is unavailable in the current client font. Questie-Octo therefore renders a tiny addon-owned tilde texture in the marker slot, vertically centered on the tooltip line. The surrounding text reserves only the marker width; this is presentation-only and applies to rare respawn approximation markers and item-start drop-rate ranges.

### 1.0.92 — tooltip tilde rollback to accepted 1.0.86 behavior

The attempted centered-tilde implementations from 1.0.87 through 1.0.91 are
**rejected experiments**, not current design rules. In-game testing showed the
Unicode mathematical tilde missing, the separate-font overlay still visually
unsatisfactory, and the texture-marker approach leaving a blank reserved slot.

The current Turtle 1.12 UI source also documents that FontStrings do not render
inline `|T...|t` textures, so do not substitute that modern-client technique.
The project therefore falls back to the last accepted and reliable 1.0.86
presentation: use the ordinary supported ASCII `~` directly in the tooltip.
Its stock-font vertical position is accepted as the compatibility fallback.

Current timing presentation remains:

- `< 5 minutes`: seconds may be shown;
- `>= 5 minutes`: seconds are omitted;
- `> 60 minutes`: compact hours/minutes are used;
- positive approximate timers are prefixed with the ASCII `~`;
- item-start min/max drop-rate ranges use the ASCII `~` separator.

Do not re-add `tilde_mid.tga` or the 1.0.90/1.0.91 overlay/texture machinery
unless a future client-side method is first demonstrated to render correctly in
Octo/Turtle 1.12.

### 1.0.93 — native ARIALN font for the middle tilde

The latest direct Turtle/Octo `FrameXML/Fonts.xml` establishes two relevant
native font facts: `GameTooltipText` uses `Fonts\\FRIZQT__.TTF` at 12px, while
`Fonts\\ARIALN.TTF` is shipped and used by native NumberFont/ChatFont families.
The stock FRIZQT ASCII `~` is still the compatibility fallback, but 1.0.93 tests
a narrower presentation-only solution: only the tilde is rendered in ARIALN.

Implementation constraints:

- surrounding tooltip text remains in the existing GameTooltip font;
- one normal space reserves the inline marker width;
- a child FontString draws the guaranteed ASCII `~` in native ARIALN over that
  slot, centered on the line and nudged down one pixel;
- overlays are reset whenever Questie-Octo rebuilds the relevant tooltip;
- no Unicode approximation glyph and no inline/addon tilde texture are used;
- rare respawn timing and item-start drop-rate data/thresholds are unchanged.

This requires an in-client visual check. If ARIALN still does not give the
requested middle tilde, roll this presentation path back to the accepted
1.0.92/1.0.86 direct ASCII `~` rather than adding more speculative mechanisms.

### 1.0.94 — wrapped-line ARIALN tilde alignment

In-game testing accepted the ARIALN `~` position on normal single-line rare
respawn rows, but showed that item-start drop-rate lines that wrap can place the
separate tilde between visual rows. A wrapped GameTooltip line is one tall
FontString, so its `LEFT` anchor is vertically centered across the whole wrapped
region. Questie-Octo must preserve the 1.0.93 single-line placement while using
`TOPLEFT` plus a first-row vertical offset for wrapped lines. This changes only
the tilde's visual anchor and must not alter tooltip text, drop rates, respawn
values, or item-start rules.


### 1.0.95 — finalize centered tilde after GameTooltip wrapping

The 1.0.94 wrapped-line branch was evaluated too early: WoW 1.12 does not
necessarily finalize an AddLine FontString's wrapped height until the tooltip
is shown. A long item-start drop-rate row could therefore be classified as a
single line before `Show()`, then wrap afterward and drag the tilde into the
vertical center between rows. Questie-Octo now records the marker's tooltip line
and prefix, calls `Show()`, and then repositions every active ARIALN tilde from
the finalized FontString geometry. Single-line respawn rows retain the accepted
1.0.93 position; finalized wrapped rows target the first visual row. This is
presentation-only.


1.0.96 — spaced drop-rate range separator
- Item-start drop-rate ranges that compare min/max now display as `0.01% ~ 0.20%`.
- Rare respawn lines remain `~15h` / `~2h30m` with no added spaces.
