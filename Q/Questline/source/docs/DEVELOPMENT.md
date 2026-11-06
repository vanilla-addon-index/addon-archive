# Questline development notes

Standalone quest tracker and selected-quest map areas for the English OctoWoW / Vanilla 1.12 client. This is the first questing proof of concept, not a leveling route guide yet.

Current version: **0.1.77**. The addon title and chat prefix use `#8cccff`, matching the tracker mode buttons. Player-facing documentation belongs in the root README; this file preserves implementation details and verification guidance.

Starter faction filtering (2026-10-18): Dark Iron Aggression (41905), No Mercy
For The Wicked (41906), and The Gemstone of Naraz (41850) have no quest race
mask, but their shared-data starters 1155, 1156, and 62414 are Alliance-only.
Questline previously discarded that faction when compiling pickup indexes.
Retain individual giver factions for both maps, and per-quest faction unions
for same-name NPC tooltip predictions. Race/class/level checks still apply;
observed server offers keep their existing precedence. No shared data
correction is needed for these reports. Regression checks cover the three
reported offers for Horde and Alliance, objects, neutral/unknown factions,
same-name variants, and observed server offers. In game, reload as Horde and
browse Loch Modan and Grim Reaches; confirm these pickups are absent, then
check that an Alliance character retains them when otherwise eligible.

Completed quest tooltip sorting: mob, world-object, and vendor progress groups
retain their position in the level-sorted quest list independently of badge
numbers. Completed quests intentionally have no badge number; comparing those
numbers caused a nil comparison when multiple matching quests included a
completed quest awaiting turn-in. Runtime checks cover unfinished, mixed,
fully completed, and single completed groups across all three tooltip sources,
preserving live counters and compact badge numbers. In game, hover a source
shared by a completed quest and an unfinished quest before turning either in.

City minimap scale (0.1.77): invalidate the cached diameter on
`MINIMAP_UPDATE_ZOOM` and `MINIMAP_ZONE_CHANGED`, in addition to physical zone
events. Native minimap mode changes can preserve both saved zoom values and
the physical zone, leaving the old diameter cached. The active minimap zoom
CVar selects the scale, regardless of an extended client's physical
`IsIndoors` result. Equal saved zooms use the existing temporary zoom probe;
its own synchronous/queued zoom events are suppressed for 0.25 seconds to
avoid repeated probing and native marker blinking. Minimap zone and physical
zone events still invalidate during that interval. Both objective spawns and
questgivers use this shared projection. A stale 466.67-yard outdoor diameter
on a 300-yard city minimap compresses offsets toward the player by about 36%,
so the error changes as the player moves. This is consistent with the reported
Undercity screenshot; live reproduction is still required to confirm the report.
Runtime checks cover Undercity movement in both axes at all six zoom levels,
both map modes, equal/unequal saved zooms, physical indoor disagreement, mode
changes without physical zone changes, probe-event suppression, zoom restoration,
and matching giver/objective positions. In game, reload, walk toward and past
a known stationary NPC in Undercity with the map open and closed, change zoom,
then enter/leave buildings and travel through a city entrance. Confirm the
marker stays over its terrain location and native markers do not blink.

HUD window layering (0.1.76): the HUD tracker uses BACKGROUND strata and frame
level zero so ordinary overlapping windows take rendering and mouse priority.
Rows, badges, header controls, pagination, and the resize grip inherit that strata;
the grip's local frame-level offset stays within BACKGROUND. The world-map
tracker retains FULLSCREEN strata and its map-relative frame level. Runtime
checks cover all HUD click surfaces after interaction, resize, collapse, and
reset, and preserve map layering. In game, overlap Bagshui and other windows
with the HUD and click items, empty bag space, and window controls over quest
rows, badges, and the grip; verify exposed tracker controls still work.

pfUI nameplate badges (0.1.75): discover the replacement through the native
parent's `nameplate` overlay and preserved original health/name/level references.
Parent badges to that overlay and anchor five pixels to the right of its visible
health bar, inheriting scaling and following bar resizing, target zoom, and
vertical offsets. The hidden native health bar no longer determines placement.
Periodic discovery adopts overlays initialized after the native plate and hides
the old badge set. GudaPlates retains registry priority and its existing placement;
default and BlizzNameplatesPlus native anchors retain their level/skull spacing.
Runtime checks cover late initialization with blank native artwork, multiple
badges, visibility, reuse, removal, and switching between pfUI and GudaPlates.
In game, reload and check pfUI badges beside quest mobs at normal and target-zoom
sizes, with vertical offsets and multiple quests, then check GudaPlates separately.

Compact numbering in both modes (0.1.74): the world-map badges and filtered map
tracker now follow the HUD's selected mode. World mode counts all unfinished
quests from one, including dungeon and unmapped quests, skipping completed
question marks. These unique numbers are shared by the HUD, map, map tracker,
and nameplates, fixing conflicting labels when dungeon and ordinary quests
share the log. Zone mode retains compact zone numbers. Switching modes
invalidates and immediately refreshes map badges and nameplates, including an
otherwise cached open map. Tests cover mixed quest tags, off-zone entries,
turn-ins, pagination, both mode transitions, and matching map/list numbers.

Zone quest numbers (0.1.73): each zone counts its unfinished quests from one
in level order, skipping completed question-mark entries. In Zone mode, the map and its
tracker use the browsed zone; the HUD in Zone mode and nameplate badges use
the physical zone. As of 0.1.74, World mode also skips completed question marks. Zone display numbers do
not mutate entries or selection keys and remain stable across pagination and
highlight prioritization. Removing or finishing an objective compacts the
affected zone's sequence. In game, check matching map/list numbers, turn-ins,
travel, and browsing another zone while the HUD remains in Zone mode.

Dungeon quest labels: type 81 and live Dungeon tags append `D` inside the
difficulty-colored level bracket, such as `[16D]`. Live tags take precedence
over database types, including unresolved quests and active tooltip groups.
Dungeon quests without a known level use `(Dungeon)`. Elite labels retain `+`.

Elite quest labels (0.1.72): the compiler retains the shared quest `type` as
runtime `questType`. Type 1 produces a plus inside the difficulty-colored
level bracket, such as `[15+] Arugal's Folly` (quest 99). Live quest-log tags
are retained and take precedence when nonempty; unresolved live Elite quests
also receive the suffix. An elite quest without a known level uses `(Elite)`.
The common formatter resolves active tooltip groups through their live key,
and available quests through their database ID. Raw titles, quest matching,
level sorting, and chat links are unchanged. Raid tags retain their
ordinary level labels. Tests cover the tracker, map tooltip, available and
completed NPC labels, same-title ordinary steps, unknown quests, and live tag
precedence. Run both Questline and ClassicBestiary tests for shared tooltips.

Horde Warbringer maps (0.1.71): the shared unit 15350 record contained outdoor
aliases of its Undercity and Thunder Bluff spawns. Existing WorldMapArea bounds
in Questie-Octo/Map/ContinentProjection.lua place Silverpine 74.7/14.8 and
Undercity 58.3/97.9 at world positions about 1252/313 and 1251/314; Mulgore
41.6/32.4 and Thunder Bluff 57.8/76.3 similarly match within three yards.
OctoQuestDatabase removes those two outdoor coordinates, retaining the city
coordinates and all other recorded spawns. Both consumers are rebuilt.
Questline already filters pickups, turn-ins, and objective locations by exact
zone ID; it does not project city markers onto neighboring zone maps. Compiler
checks cover excluded outdoor pickups and retained city destinations. No
generic removal of overlapping-zone spawns is inferred from this correction.

Resize triangle (0.1.70): replace the two corner strokes with a seven-pixel
gold triangle, matching the previous inner stroke's size, and a thin dark
edge. Solid one-pixel rows keep the artwork independent of client assets.
The 16-pixel hit area and hover/drag behavior are retained.

Resize anchor artwork (0.1.69): a live report shows no visible grabber after
the hover change. Replace the external ChatIM texture with two gold corner
strokes drawn from solid textures, with opaque dark outlines. The grip sits
above row controls and retains the 16-pixel hit area and hover/drag behavior.
This removes dependence on client-specific artwork; runtime tests cannot
verify textures bundled in the game archives. Check the bottom-right corner
over light and dark terrain in game after reloading.

Resize grip discovery (0.1.68): the existing 16-pixel bottom-right anchor
appears whenever the cursor is within an expanded tracker's bounds, including
over child controls and transparent space. A native Lua 5.0-compatible
`MouseIsOver` check on the visible panel updates only changed texture state;
child tooltip scripts are preserved. The grip stays visible while resizing,
then follows tracker hover on release. Collapsed and hidden panels suppress
the anchor. Runtime checks cover hover, leaving, release inside/outside,
collapse, and hiding during resize. In game, hover header, rows, badges, and
empty space, then resize and move the cursor off the tracker.

Object turn-ins (0.1.66): completed, non-failed live quests include object
finishers in the shared questgiver markers on both maps. Objects use negative
IDs, matching object pickups, so equal creature IDs cannot collide. Corpse
Laden Boat for The Decrepit Ferry uses the gold completion question mark at
its recorded Silverpine coordinates. Object destinations say `Interact with`
in tracker details and quest tooltips. Runtime checks cover both maps, tooltip
wording, pickup merging, ID collisions, and failed/removed quests. In game,
check the boat within minimap range and after rewarding the quest.

Generated data files omit boilerplate headers and per-file source revision
comments. Source locks, manifests, and runtime initialization retain the shared
SHA-256 revision; unchanged data tables stay unchanged when that revision advances.

Thwarting Kolkar Aggression (2026-10-06): the live Octo offer from Lar Prowltusk
confirms quest 786 is available. OctoQuestDatabase removes its stale prerequisite
on absent quest 785; both addons are rebuilt from the updated shared revision.
Starter, finisher, restrictions, and all three attack-plan coordinates are retained.
Runtime checks cover Lar's predicted pickup on both maps without completion history.

Map marker tooltips use the native `ANCHOR_CURSOR`, matching Questie-Octo,
for quest selectors, objectives, spawns, and questgivers on both maps. Tracker
rows retain `ANCHOR_LEFT`. Party progress refreshes keep the same anchor by
identifying map pins from their parent. In game, hover each marker type and
move within its hit area to check cursor positioning, including a zoomed map.

Quest marker artwork (0.1.64): pickup exclamations and completed turn-in question
marks use the installed Questie-Octo's unchanged 32x32 BLP artwork, bundled as
Textures/quest-available.blp and quest-complete.blp. Both maps render these at
16 pixels, matching Questie-Octo's default size; world-map zoom compensation,
the selected turn-in's blue halo, and pooled marker state resets are retained.
Standalone turn-in destinations use the same texture and size. Provenance and
source hashes are recorded in Textures/README.md and the retained asset audit
in licenses/. No runtime dependency on Questie-Octo is introduced. In game,
compare both marks on both maps and zoom the world map to check the outlines.

Absent quest correction (2026-10-04): a live player report identifies A Tusken
Affair (80300) as nonexistent on Octo. Questie-Octo's compiler and compiled
snapshot disable its predicted availability; importing and rebuilding Questline
removes the stale Revantusk Watcher offer in Undercity and other starter zones.
The quest record and relations remain available for identification.

Active quest prerequisites (2026-10-04): the compiler preserves upstream
`preActive` as `activePrerequisites`. These IDs require a quest in the live log,
including one awaiting its reward; completing that quest cannot satisfy the
same ID in the ordinary prerequisite list. Other completed predecessors remain
alternatives. Candles of Beckoning and The Dormant Shade are available during
Proving Allegiance, then disappear after it is rewarded, including while the
completed The Prodigal Lich Returns is awaiting its Undercity turn-in. Runtime
tests cover the helper lifecycle, both maps, and the retained Bethor turn-in.

Summoned objectives: the import includes Questie-Octo's compiled scripted
encounter presentation metadata. Role-scoped guidance supplies map positions
only when canonical creature coordinates are absent. Object anchors use the
recorded upstream object coordinates. Proving Allegiance maps Lillith Nefara
at Lillith's Dinner Table and explains the Candle of Beckoning interaction
in the map tooltip. Canonical NPC coordinates and live objective progress
remain authoritative; completion maps the ordinary quest finisher.

Questgiver pickup markers include object starters, such as Wanted! (object
711, quest 398 / Wanted: Maggot Eye), on both maps. Names, coordinates, and
quest relations come from the upstream snapshot. Object giver keys are negative
IDs so they cannot collide with unit IDs. Objects use the usual eligibility,
active-log, and completion filters, but ignore name-based NPC offer observations
because unrelated posters can share the same name. These are map markers only.

Quest map destinations (0.1.60): the compiler omits vendor locations for items
with at least ten unlimited-stock vendors, while retaining their quest
objectives and any actual drop sources. Specialty and limited-stock vendors
remain mapped. This shared display policy removes Coarse Thread's scattered
bags without changing the Questie-Octo snapshot. Numbered badges prefer the
remaining area target with the most spawns over point objectives, using its
existing central spawn anchor. Point-only quests and turn-ins retain their
destination order. Runtime tests cover area selection and exact turn-ins;
compiler checks cover common supplies, specialty and limited stock.

Completion-history reset (0.1.59): Completed Quests has a Restore All button
beside Import from Server. It clears all saved completion records and their
provenance, invalidates predicted availability, refreshes questgiver markers
and the open list, and reports the number restored. A subsequent server import
repopulates history from current server truth, which supports clean database
refresh testing.

Questie-Octo database import (0.1.58): `tools/import-questie.js` reads the
neighboring addon's private compiled runtime snapshot without evaluating
arbitrary Lua, records exact input hashes, converts it to Questline's owned
JSON schema. Questie-Octo is the sole authority: the old local override file
and pfQuest import pipeline have been removed. Imported JSON is disposable
build output; corrections belong upstream. Questline remains standalone in
game. The generated runtime retains all 6,704 upstream quests. Relevant upstream
MIT, GPL metadata, scope, and third-party notices are preserved in `licenses/`.

Deterministic turn-in recording (0.1.57): a matching completion system message now confirms the pending reward snapshot without immediately writing completion history. Questline keeps that snapshot through intermediate quest-log scans and records completion only after the quest disappears from the live log. This removes the event-order race where an early completion message unlocked a successor, then live-state reconciliation erased the predecessor's new completion record because the server had not removed it from the log yet.

Tracker appearance (0.1.56, updated): Options has a separate Appearance section with a Bordered tracker checkbox. Checking it enables the HUD background and border. Transparent mode removes the HUD backdrop and border, adds a translucent dark header strip with fading gold edges using native quest-highlight artwork, replaces the selected row's solid blue fill with a faint soft-edged blue glow behind the row, and retains the selected yellow badge. Tracker text has an opaque black shadow offset one pixel right and down; unfinished objectives and fallback detail text use pure white. Completed objectives retain their green color. The header strip follows resizing and remains visible when collapsed. The world-map tracker always keeps its bordered backdrop and blue selected-row fill for readability over map artwork. Transparent HUD appearance is the default for new settings; existing saved appearance preferences are preserved. A zero-percent opacity value saved by the short-lived slider implementation migrates to transparent mode; other slider values return to the bordered style.

Crown of the Earth correction (0.1.56): the incomplete duplicate quest 934 is removed by a durable database override. Octo uses quest 7383 for the level-11 Amethyst Phial step; it has the same title and quest text as 934 but includes the real objectives and prerequisite from quest 933. Keeping both made clients without a usable quest-link ID report an ambiguous database match.

Options navigation (0.1.56): `/ql` opens a fixed two-column Blizzard-style pane with persistent General, Appearance, and Completed Quests categories in the left sidebar. Visibility, map-marker, history-filter, and transparent-HUD preferences use native checkboxes with explanatory text. One-shot operations such as layout reset, server import, and restoring a quest use native action buttons. The import control and manual-only filter share the Restore-button right edge, while the narrower search field uses the remaining header width. The selected sidebar category is retained while the pane is closed and reopened. Addon status remains available through `/ql status` without occupying the player-facing pane.

Clustered tooltip colors (0.1.55): available and complete quest rows use the same tracker-gold base color. Their bracketed level numbers retain the standard difficulty color.

Clustered quest NPC tooltips (0.1.54, updated): world-map NPC markers use the same combined availability and completed-turn-in entries as minimap markers. Hover clusters now use a 10-pixel center-distance radius (previously 22), adjusted for map zoom. Individual and clustered tooltips start with NPC names, sorted alphabetically, with nonempty `Available` and `Complete` subheaders under each NPC. Level-formatted quest titles are deduplicated within each NPC's section; shared quests remain listed under every eligible NPC. An NPC with both states displays a question mark. Standalone completed-quest map pins are omitted so turn-ins are represented once at their exact NPC coordinate; the selected turn-in retains the highest marker level and blue glow.

World-map turn-ins (0.1.53): completed-quest question marks stay at their exact finisher coordinates. They no longer enter the numbered-marker collision fan, which could move a busy-hub turn-in far away from its NPC while the minimap remained correct. Turn-ins at the same NPC stack at that shared coordinate, and the selected quest receives the highest frame level so its blue glow remains visible.

Contradictory completion repair (0.1.52): when a non-repeatable quest is present in the live quest log, Questline removes any local completion record and its provenance for that same ID. Live server state overrides legacy, imported, server-query, automatic, and manual records. The repair persists after the quest is abandoned or removed, so stale history cannot resume unlocking its successor.

Prerequisite evidence (0.1.51): successor prediction requires a predecessor completed through a Questline-observed turn-in (`Automatic`), an explicit map skip (`Manual`), or the current Octo completion query (`Server`). The one-time pfQuest migration now records `Legacy`; legacy and older ambiguous `Imported` records can still suppress their own completed quest markers but cannot unlock successors. Running the server completion import upgrades every returned record to `Server`, including IDs already present locally. This prevents an unpicked prerequisite with stale imported history from exposing its follow-up.

Active prerequisites (0.1.50): a prerequisite currently present in the quest log cannot satisfy a successor, even if local or imported completion history also contains that prerequisite ID. Alternative prerequisite lists still use OR semantics: any other completed predecessor that is not active can unlock the successor. This prevents follow-up questgiver pins from appearing while the player is still working on the preceding quest.

Observed NPC availability (0.1.49): opening gossip or a quest greeting stores the server's exact available quest list, including an empty list, for the rest of the relevant session state. It no longer expires after 60 seconds and revives a false database prediction. Quest-log changes, level changes, and profession skill changes clear the observation so newly eligible offers can appear.

Vanilla compatibility (0.1.48): the server completion response parser walks numeric IDs with the Lua 5.0 `string.find` API. It does not use `string.gmatch`, which is absent from the game client.

Predicted availability corrections (0.1.47): quest 4641, Your Place In The World, is retained for quest-log/history resolution but has no predicted starter because Octo uses the starterless replacement quest 787, The New Horde. Cutting Teeth continues to accept either predecessor in the imported chain. Quests whose source title begins with `[DEPRECATED]` remain resolvable if observed live but are never predicted as available, preventing stale questgiver records from creating map pins.

Objective action corrections (0.1.46): normalized quest objectives may carry an optional `icon` override which the compiler preserves. The classic priest Garments quests mark their heal-and-fortify unit as `interact`, including Deathguard Kel in Garments of Darkness (5650), so precise and spawn markers use the gear on both maps. The world-map friendly-unit fallback changes only targets still classified as `kill`; it cannot overwrite explicit interaction icons.

Server completion import (0.1.41): the Completed quests page sends `.queststatus` to the GUILD channel, listens for `CHAT_MSG_ADDON` messages with prefix `TWQUEST`, and collects returned numeric quest IDs for three seconds, matching pfQuest-octo patchtable.lua. It imports only IDs present in QuestlineDB, marks every returned record as server-confirmed, then invalidates availability and refreshes map questgivers. The import link sits beside the Completed quests heading; the Options section returns to 300 pixels tall. While a request is active, the link is disabled and dimmed. When replies finish, the completion list updates and the link returns to blue without a separate Done state. Chat reports only newly added completion records; if there are none, it says completed quests are up to date. Missing API or no response does not alter history. This server-specific request works without pfQuest installed and is user-triggered; it is not run automatically.

Completed quest rows (0.1.45): the list sorts by displayed quest level from highest to lowest, with unlevelled entries last and title order for ties. It shows the same difficulty-colored level number and gold quest title as the tracker, with no visible completion-source label. Source metadata remains saved for the manually skipped only filter and compatibility. The explanatory Restore sentence was removed; search, filter, and the twelve compact rows use the available space. The former Show manually skipped / Show all link became a native Manually skipped only checkbox in 0.1.56. Hovering a row or its Restore button shades the whole row. The row tooltip retains only the quest ID. When the active All or manually skipped filter returns no matches, a centered grey "No entries to show" empty state replaces the blank row area.

Minimap movement (0.1.33): marker projection runs every frame using cached questgiver and selected-objective lists. Quest scans, eligibility checks, list rebuilds, and optional rotation-CVar reads retain the slower refresh schedule. An unchanged position/zoom/facing/size/shape skips redundant marker updates. Existing cross-zone map-browsing coordinate limitations still apply. Tests verify successive movement frames update both giver and objective positions without scanning or rebuilding their lists.

World-object tooltips (0.1.33): the compiler adds objectObjectives to Data/MobObjectives.lua for direct object objectives and object sources of quest items, including reference loot. Vanilla world objects have no mouseover unit; match their normalized tooltip title only when GetMouseFocus is WorldFrame and there is no mouseover unit. Inventory/UI tooltips with the same title must not match. Use the existing grouped objective and party-progress rendering, preserving other addons' lines and native fading. Object sources omit mob drop percentages. Regression cases use Fields of Grief / Tirisfal Pumpkin, Gordo's Task / Gloom Weed, and Doom Weed, including lingering fades, repeated refreshes, and same-name inventory tooltips.

Minimap rotation is optional: `GetPlayerFacing` does not imply the client has a `rotateMinimap` CVar. Read that setting with `pcall`, because unknown CVars can throw. Missing or disabled rotation uses north-up positioning without requiring a client extension or another addon. Runtime tests cover a throwing lookup, nil results, absent facing API, and rotation becoming available again.

The renamed addon uses a new per-character saved-settings file. Existing settings from before the rename are not automatically loaded. To preserve them, fully exit WoW, copy the previous addon's per-character file from `WTF/Account/<account>/<realm>/<character>/SavedVariables/` to `Questline.lua`, and change its top-level settings variable to `QuestlineSettings`. Otherwise Questline starts with default preferences and records completion history normally; the previous saved file remains untouched.

Menu styling uses Blizzard's UI-Panel-MinimizeButton textures with Bagshui's 18-pixel size and texture crop, without requiring Bagshui. The completion count is centered; filter, Restore links, and next-page arrow share an 18-pixel right inset. The previous-page arrow mirrors the inset on the left.

Unmodified left double-click on a tracker row or badge (HUD or map tracker) selects the quest and opens a zone with remaining objectives, or its turn-in zone when completed. Resolve through the client's actual continent/zone names, preferring the physical zone, then the currently visible map, then the first supported zone. Show the map before SetMapZoom because opening can reset its zone. No mapped target leaves the current map unchanged and prints a short message. Shift/Ctrl double-click does not navigate; right-click still opens the quest log.

Map action markers (0.1.26) use the shipped pfQuest bag/sword/gear cluster artwork at 18 pixels, maintaining screen size under map zoom. Loot uses the bag, kill uses swords, interact/explore uses the gear, and friendly talk targets use the native GossipGossipIcon. Copies are maintained in Textures/action-*.tga; provenance is in Textures/README.md and the existing pfQuest MIT notice is retained. No runtime pfQuest dependency. The old generated action symbols are no longer used for these markers.

Map tracker visibility is saved per character in `QuestlineSettings.mapTracker`, defaulting to false only when unset (0.1.67). Existing saved preferences are preserved. Options and `/ql maptracker on|off` change it independently of the HUD, map markers, and highlighted areas. Refreshes and layout reset preserve the visibility preference. The pfQuest pin switch is no longer on the Options page; `/ql legacy on|off` retains the compatibility override.

Availability fixes (0.1.28): Known NPC offers now obey class/race/level restrictions and exclude live/completed entries before resolving same-title candidates; unavailable class identity cannot allow a restricted mask. Quest identification prefers GetQuestLinkForLogIndex over generic GetQuestLink and validates linked titles/restrictions. Reward handling snapshots a uniquely identified completed live quest before GetQuestReward, then records it only after removal from the log or a matching completion message. Pending snapshots expire after 30 seconds; AbandonQuest clears them. Opening the reward dialog alone does not mark completion. Since 0.1.52, every completion record contradicted by a live non-repeatable quest is removed together with its source metadata. Automatic is retained as an internal source value for saved-data compatibility. Tests include a real rogue-only quest, observed-offer filtering, same-title chain transitions, delayed completion messages, incorrect legacy live history, and failed reward followed by abandonment. Historical entries cannot be broadly corrected without evidence or user-supplied quest IDs.

World-map turn-ins use the bundled Questie-Octo question mark at 16 pixels, matching minimap turn-ins. Highlighted quests show a soft blue 26-pixel halo generated as Textures/turnin-glow.tga by tools/contour-assets.js. Unselected turn-ins have no halo. Both sizes compensate for map zoom. Pooled markers restore their numbered text and gold halo texture when reused for unfinished quests. Tracker badges retain their existing appearance.

Selected-quest spawn markers (0.1.30): unit, object, item-source and item-use positions are compiled into location.spawnPoints as deduplicated sorted four-character coordinate pairs (base64-pairs, percent times 40). They supplement the precomputed areas; no clustering happens in game. Only highlighted quests' unfinished targets are decoded, cached for the physical/displayed zones, and displayed using 14-pixel bag/sword/gear icons (talk uses the native conversation icon). Shared targets are deduplicated across selected quests. Frame pools reuse markers and reset their textures. The world-map option worldMapSpawns defaults off (since 0.1.34; existing saved choices are preserved) and is exposed in Options; it controls only world-map spawn markers, independently of the blue areas and precise objective markers. Nearby minimap markers are always enabled for highlighted quests, using the existing zoom/rotation/indoor-scale/clipping and same-zone position sampling. Turn-ins and finished objectives have no spawn markers. Positions are database locations, not live mob tracking. Tests cover coordinate bounds/deduplication, selection, shared objectives, completion, map browsing, minimap clipping, pooling, texture changes, and the independent world-map toggle.

Item-source icons (0.1.31): world objects that provide quest items use gears rather than bags, including Doom Weed (5482 / item 13702). The compiler retains source kind through loot references and emits per-position spawnKinds for mixed-source items. Both maps choose the icon per spawn. Exclusively object-sourced item targets also use gears for precise objective markers. Mob item drops remain bags. Tests cover the real Doom Weed record and mixed object/mob sources on both maps.

World-map layering (0.1.36): area shading is on a lower canvas child layer (+4). Number badges and objective icons share the foreground pin layer; badges use +9, objective icons +12, and turn-in icons +13 relative to the map canvas. RefreshMap reapplies these levels after map addon changes. Tests assert both parentage and ordering. Small turn-in question marks retain their foreground layer. RefreshMap reasserts selector/area/pin layer levels even on cached renders so map-frame changes do not leave numbers raised above objectives.

## First test

Completion management (0.1.21): `/ql` toggles a movable options/history panel; `/ql help` retains command help. Options exposes independent HUD and map tracker visibility, layout reset, and status output; World/Zone stays only on the tracker. Completed quests contains title/ID search, a manual-only filter, and paginated Restore actions. Since 0.1.56, General, Appearance, and Completed Quests use persistent sidebar navigation instead of the original Home links. The map context menu uses FULLSCREEN strata and WorldMapFrame level +60, following the map tracker approach so its backdrop and title render above map artwork; child buttons explicitly use FULLSCREEN strata above the pane, including its close button. An invisible click catcher one level below dismisses the menu on an outside click and consumes that click. The catcher hides with the pane. Quest-name-only rows determine the compact pane height, and pagination appears only for multiple pages. Pane titles use tracker gold. Minimap markers have no completion click action. Right-clicking world-map NPC markers opens a paginated context menu of individual available quests from the nearby marker cluster. Selecting one records manual completion; active quests and offers without an unambiguous database ID cannot be marked. The menu changes only Questline history, never the real quest log or pfQuest's saved data. Existing completion booleans remain in `completedQuests`; `completionSources` distinguishes observed turn-ins, server confirmation, manual skips, legacy pfQuest migration, and older unknown records. Confirmed completion messages continue recording automatically, including messages arriving just after log removal; abandonment never counts. Legacy history stays a one-time migration, so restoring an imported entry survives reinitialization. Both prediction and uniquely identified observed NPC offers respect completed records. Repeatables remain eligible after automatic completion but a manual mark hides them until restored. Restoring also removes source metadata and invalidates availability caches; prerequisites and all other eligibility rules still apply, so Restore is not a forced offer. The separate, user-triggered server-completion query is described above and has no required addon. Regression coverage includes history persistence, manual/automatic distinction, repeatables, observed offers, search/filter/pagination, active and ambiguous quests, menu actions, and the Restore button.

Both trackers can be resized from the bottom-right corner. The 16-pixel handle is invisible until hovered and stays visible during a drag. Width reflows titles/objectives; height determines page capacity, keeping each quest together. Before any manual resize, the original five-entry automatic-height layout remains. A quest taller than the requested height expands its page to avoid clipping details. HUD and map sizes are saved independently in `trackerSize`/`mapSize`; collapsing preserves the expanded size, and `/ql reset` clears both sizes and positions. Dragging uses native Vanilla `StartSizing`, minimum 258x140 and maximum requested 700x900, with layout guarded against recursive size-change callbacks. The page arrows leave room for the handle. Tests cover hover/drag/release, reflow, pagination reachability, independent sizes, refresh persistence, collapse/expand, oversized objectives, hiding mid-drag, and reset. In game, check live resizing and release outside the handle, plus the map tracker with a windowed map.

1. Fully restart WoW so the new `Questline` addon folder is discovered. Enable **Questline** in the character selection AddOns menu.
2. Log in with quests in your quest log and open their zone map, such as the Barrens.
3. Click a numbered circle on the map or in the tracker to highlight its unfinished objectives in blue. Ctrl-click additional quests to highlight them together.
4. Single locations use precise bag / interaction markers. Completed quests show `?` at their turn-in locations.
5. Hover a gold **!** to see an NPC's available quests, then approach it to see the nearby minimap marker.

New characters start in **Quests - <current zone>**, showing quests with unfinished objectives or turn-ins in the physical zone, for example **Quests - Mulgore**. An existing saved World or Zone preference is preserved. Click **Show World** to return to all quests. Zone mode follows you as you travel, independently of the map you browse. Long zone names shorten to **Quests - Zone**; hover over the header for the full name. Unmapped quests are always available in World mode. Your mode choice is saved per character.

Quest labels include a **[level]** prefix in both trackers, quest tooltips, NPC sections, and questgiver marker tooltips. Only the number changes difficulty color (gray, green, yellow, orange, or red); quest names keep their existing color. In Ctrl-selection mode, both trackers show highlighted quests first, then the remaining quests. Normal single selection keeps the full level order and the current page. Each group sorts from lowest level to highest, preserving quest-log order for ties. World quest numbers follow the global level order; zone numbers follow the filtered level order and skip turn-ins. Moving a highlight does not renumber the map. Unknown levels have no prefix and sort last within their group. The actual Blizzard quest log is not rearranged. Colors refresh as you level up.

**Ctrl-left-click** a map circle, map action icon, tracker row, or tracker badge to add or remove that quest from the highlighted group. Each Ctrl-selection change returns both trackers to page one; more than five highlighted quests continue onto subsequent pages before the other quests. A normal left-click replaces the entire group with that one quest, exits selected-first sorting, and preserves the current tracker pages (clamped only if the filtered list shrinks). Ctrl-clicking the last highlighted quest leaves no highlights. Selections are saved per character, survive completion and zone changes, and are removed when their quests leave the log. Each tracker's zone filter still applies, so an off-zone highlight stays selected without appearing in that zone's list. All selected areas share the blue shading; overlaps are merged to avoid darker patches. Selected single-point objectives retain their action icons.

The map panel lists quests with mapped objectives in the displayed zone. Selection is shared across both trackers and modes. Each zone has its own compact numbering, shared by its map and zone tracker; World mode uses full-log numbers. Normal circles have a shaded burgundy center and beveled gold rim; each selected circle has a yellow fill, dark numeral, and soft gold halo. Drag either panel's header to move it; `-` collapses it. Use the arrows or mouse wheel for additional pages; the scroll hint appears when there is more than one page. Positions and selection are saved per character.

In either tracker, **Shift-left-click** a quest row or its numbered circle while chat is open to insert its quest link at the cursor. **Right-click** to open that quest in the Blizzard quest log, expanding its category and scrolling it into view. Linking and opening the log preserve the highlighted map quest. Ordinary left-click still highlights the quest. Links use Octo's native quest-link API, with standard `GetQuestLink`, pfQuest's configured format, or a bracketed quest title as fallbacks. Nothing is sent until you submit the chat message.

Hover over a mob to see relevant kill and item-collection progress grouped under gold quest names, with each objective slightly indented. For example, Rattlecage Soldier shows **[8] The Mills Overrun** followed by **Notched Rib (40%) - 0/5**. Adult Plainstrider shows **Leg Meat (10%) - 1/2** using its own recorded drop rate. Percentages round to the nearest whole number and come from the owned database; unknown, invalid, or conflicting rates are omitted. Kill objectives have no drop percentage. Mobs shared by several quests show each quest separately, even when their counters are identical. Quests follow level order; objectives retain their live quest-log order. Counters update while hovering and turn green when complete. When the cursor leaves the unit, its quest details stay with the tooltip through its normal fade, until it hides or shows different content. They work in both tracker modes, including quests that are not selected. Existing tooltip details are retained; a complete matching quest group already supplied by pfQuest is not repeated. Updating to 0.1.12 requires one full restart to load the new party synchronization file.

When a party member shares a quest, its tooltip objectives expand to show **You: 1/2**, **Alice: 0/2**, and each other member's progress beneath the objective name. Mob-specific drop percentages stay beside the item name. Completed counts turn green; turn-in tooltips show each member's overall quest status. The main tracker rows keep their compact layout. Party members without synchronized data are omitted; the native shared-quest indicator does not produce a placeholder row. Names with usable data use `RAID_CLASS_COLORS` from the live party unit, with a plain-name fallback if the class is unknown. Questline cannot obtain their counters without a compatible sender, and does not read pfQuest's protocol.

Synchronization starts automatically in a normal party, including while the tracker is disabled. Updates are throttled and periodic snapshots repair missed messages. Disconnected members and counters older than 90 seconds are omitted. If no party member has usable data for an objective, retain the compact local objective instead of adding a redundant You row. Remote data stays in memory and is discarded when a member leaves or reconnects. This first version supports parties, not raids, and aligns identified quests by ID and objectives by normalized English text, type, and required count. Ambiguous or mismatched objectives are omitted rather than guessed. See [the party protocol](PARTY_PROTOCOL.md) for maintenance details.

NPC tooltips now group quests under **Available**, **In Progress**, and **Complete**, omitting empty sections. In-progress quests show indented objectives with live counts. Complete lists only quests that can be turned in to that NPC. Explicit talk-to objectives identify the conversation and its progress without treating that NPC as the questgiver. Tracker quest tooltips retain quest details without the blue click instructions.

Gold **!** markers show NPCs offering eligible quests on zone maps and, when nearby, on the minimap. Icons are 14 pixels instead of 20. Hovering a marker lists the names and available quests of all visible givers within 22 screen-scaled pixels, so overlapping NPCs can be inspected together. Each NPC gets one marker even if it offers several quests; moving NPCs use a recorded position on the world map and the nearest recorded position on the minimap. Minimap markers follow movement, zoom, and indoor/outdoor scale, clipping at the map edge. Continent views, object/item quest starters, and dungeon floors are outside this first implementation.

The normal tracker stays visible when the world map opens, alongside the map's own quest list. Minimap markers also remain visible and update normally when the map shows your current zone. While browsing another zone or a continent, Vanilla cannot provide fresh player coordinates for your physical zone: markers retain the last valid position until the current-zone map is restored or the world map closes. No position is borrowed from a different physical zone, and Questline never changes the map you are browsing to obtain coordinates.

Availability uses level, race, class, profession, recorded prerequisites, mutually exclusive quests, and completion history. Recently observed NPC dialogue takes precedence for one minute, including offers missing from the database; seasonal quests require an actual offer. Completion history is saved per character, initially copied from pfQuest if present. Subsequent confirmed completion messages record turn-ins; abandoning a quest does not mark it completed. Without previous history, older quest chains cannot be reliably predicted. The imported data does not cover every reputation or custom server condition, so **!** markers are previews of eligibility, not a server guarantee.

pfQuest is optional. If it is enabled, Questline hides its world-map pins and route lines for this session so they do not cover the new map. Its minimap behavior is retained. The original quest trackers are hidden while Questline's tracker is enabled. No pfQuest files, saved settings, or databases are changed.

| Command | Action |
| --- | --- |
| `/ql` | Options and completed quests |
| `/ql help` | Help |
| `/ql tracker on` / `/ql tracker off` | Enable / disable the normal tracker and restore the old tracker |
| `/ql legacy on` / `/ql legacy off` | Restore / hide pfQuest world-map pins and route lines |
| `/ql reset` | Reset both panels' positions and expand them |
| `/ql status` | Version, database build, and identified quest count |

## Shared database

OctoQuestDatabase owns the resolved quest source tables. Its source schema and
provenance retain the effective Questie-Octo 1.44 data that originally supplied
Questline. `tools/import-database.js` is Questline's adapter into the existing
JSON schema; `tools/build.js` compiles geometry and presentation indexes.
`database/*.json`, `Data/`, and reports are generated and committed. Data
corrections belong in OctoQuestDatabase; presentation policies belong here.

`database-source.json` pins an exact SHA-256 content revision of the shared
source files plus LICENSE/NOTICE.md. The importer accepts a checkout path or the
`OCTO_QUEST_DATABASE` environment variable, defaulting to a sibling
OctoQuestDatabase directory. It computes input hashes directly from the data-only checkout and refuses a
revision mismatch unless `--update-lock` is explicitly provided. The imported
manifest records the revision, repository, input hashes, and counts. Generated
Lua headers, `QuestlineDB.sourceRevision`, and the build report retain the pin.
The build verifies the snapshot pin and needs no shared checkout once imported.

Questline remains self-contained in game. Players need neither Questie-Octo nor
OctoQuestDatabase. No local overrides, deletions, remapping, or fallback source
layers are applied. The old `tools/import-questie.js` and `import:questie`
commands are compatibility aliases to the shared importer and never read the
other addon's runtime database. Imported notices are retained automatically in
`licenses/OctoQuestDatabase/` alongside Questline's existing notices.

The import report records duplicate zone names and missing references; the
build report records geometry coverage. Missing locations are never invented.
Existing vendor icons/tooltips, GudaPlates badges, remaining-objective areas,
and green completed objectives retain their baseline data and presentation.

Coordinates use `[xPercent, yPercent, zoneId, optionalRespawnSeconds]`. Quest targets use `{ "kind": "unit|object|item|event|use|zone", "id": 123 }`. See [database/SCHEMA.md](../database/SCHEMA.md).

## Build and validation

Node.js is only for development. From `Interface/AddOns`:

```powershell
# Refresh the snapshot from the pinned neighboring shared checkout.
node Questline/tools/import-database.js
# To deliberately adopt a changed shared revision, add --update-lock.
node Questline/tools/build.js
node Questline/tools/assets.js
node Questline/tests/run.js

# Optional interactive coordinate preview; open the resulting HTML in a browser.
node Questline/tools/preview.js
```

The tools use `luaparse` and the tests use `fengari`. This workspace's `.test-tools/node_modules` is supported; on another machine run `npm install` inside Questline using its `package.json`. The addon itself needs no Node packages. To distribute just the game addon, include the TOC, all root Lua files, `Data/`, `Textures/`, and `licenses/`.

Spawn groups, item drops (including reference loot), vendors, item-use targets, and turn-ins are resolved offline. Nearby points are clustered with map aspect ratio taken into account. Dense groups become padded hulls with gently rounded corners; separated groups remain separate. Small groups and turn-ins become precise markers. Hulls are rasterized into 1,280-row scanlines, packed into six-byte ASCII triples instead of thousands of Lua number slots. The client unions the highlighted quests' unfinished scanlines and draws their boundary using filtered, rounded contour tiles. Large interiors and straight edges are merged into rectangles, and textures are pooled. Numerals and halos retain their screen size when the map is zoomed. Spawn positions use compact packed strings and are decoded only for selected targets; no spawn clustering happens while playing; a small, separate index retains questgiver positions for map/minimap pins. The blue areas are approximate coverage, not terrain-aware or navigation boundaries.

The automated suite validates normalized coordinates, priority and deletion rules, manual source corrections, geometry separation, all generated Lua syntax, and runtime behavior against a simulated 1.12 API. It exercises collapsed headers, restoring selection, title ambiguity, objective completion, failed quests, map/continent changes, turn-ins, point markers, shared selection, World/Zone filtering and pagination, travel independently of map browsing, pooling, and reversible pfQuest suppression. It also rejects Lua syntax introduced after 5.0. Fengari is a newer Lua VM, so this simulation does **not** replace an in-game smoke test.

The runtime harness also emulates [Lua 5.0's `ipairs` behavior](https://www.lua.org/source/5.0/lbaselib.c.html#luaB_ipairs), including its handling of extra return values. Map-click selection is exercised in both tracker modes and with an unknown physical zone.

Multi-selection tests cover Ctrl-click through map circles, action icons, both tracker rows and badges, selected-first level order, stable numbers, page overflow, simultaneous areas and points, zone filtering, saved selections, completion, removal, clearing all highlights, and normal-click replacement. They also check modifier precedence and clearing stale row tooltips after reordering.

Tracker-click tests cover native chat links and their fallbacks, preserving the draft cursor and log selection, right-clicking rows and circles, revealing collapsed categories, scrolling to the chosen quest, map-panel navigation, and stale, unknown, or ambiguous entries.

Mob-tooltip tests use the imported Rattlecage Soldier / Notched Rib and Night Web Spider records, exercising live item and kill counts, quest grouping, multiple objectives, shared items with independent counters, completion, failed/removed quests, tooltip reuse, and existing pfQuest groups. Fade tests run without `GetOwner`, verifying that mob and NPC quest lines persist after mouse leave without restarting the fade, and clear on hiding or content replacement (including identical titles). A separate check covers owner changes on clients with that optional method. The compiler's source lookup also covers reference-loot cycles, quest-only drops, and exclusion of vendor-only sources.

Level/rate tests verify stable ascending order, unchanged log contents and selection, matching map numbers, native/fallback difficulty colors, recoloring on level-up, and unknown levels. Drop-rate tests cover actual Leg Meat sources, direct and reference loot, conflicting names and reference paths, per-mob isolation, nearest-whole-percent rounding (including half-percent boundaries and tiny chances), and omission of unknown chances without removing objective counters.

NPC and pickup-marker tests exercise Deathguard Dillinger's quest chain, server offer lists, saved completion history, abandonment versus turn-in, race/class/profession restrictions, repeatable and seasonal quests, and Octo's Magistrix Ishalah conversation objective. Map tests use Sergra Darkthorn's imported position, checking zone browsing, map zoom, minimap distance/rotation/clipping, indoor detection, and marker changes after acceptance and turn-in. They also cover simultaneous tracker visibility, minimap movement with the world map open, retaining only same-zone position samples while browsing elsewhere, and nearby-giver tooltips on both maps (including zoom, duplicate, hidden and distant pins). Completion message parsing uses the client's format from [Vanilla GlobalStrings](https://github.com/MOUZU/Blizzard-WoW-Interface/blob/master/1.12.1/FrameXML/GlobalStrings.lua).

The API implementation was checked against the original [1.12 QuestLogFrame](https://github.com/MOUZU/Blizzard-WoW-Interface/blob/master/1.12.1/FrameXML/QuestLogFrame.lua) and [WorldMapFrame](https://github.com/MOUZU/Blizzard-WoW-Interface/blob/master/1.12.1/FrameXML/WorldMapFrame.xml), plus the installed addons' actual usage.

## Current limits and in-game checks

Instant class/delivery turn-ins refresh the live quest log when capturing the
reward dialogue and again before GetQuestReward. Exact IDs from Octo's optional
C_QuestLog.GetQuestIDForLogIndex are validated against title and restrictions,
with existing Vanilla link/text fallbacks when unavailable. This identifies
same-title, empty-text priest quests such as Touch of Weakness (5658). Completion
messages without a reward snapshot also stay pending while the quest remains
active; history is committed after log removal so live-state repair cannot erase
the completion. Regression tests cover the real priest quest, automation before
the periodic scan, preserved collapsed headers/selection, and ID fallbacks.

Item-vendor map pins carry names compiled from their exact recorded source
coordinates. Hovering a vendor bag shows its NPC name first, then the quest
title and live objective/party counts for the supplied item only, matched by
normalized objective name rather than position. Party refresh retains that source name.
Markers without known source names retain their quest-first tooltip. All loot
and vendor bags use native VendorGossipIcon at 14 pixels for precise map pins
and 12 pixels for spawn pins, with world-map zoom compensation.

The source-first tooltip also applies to known drop NPCs and interaction objects,
including item sources reached through reference loot. Compact per-source packed
coordinates are compiled into locations and cached by coordinate at runtime.
Direct kill/object targets use their own recorded names. Only the hovered target's
matching live objective and party counts appear; an unmatched live objective uses
the known target name without inventing progress. Quest overview tooltips remain
complete. Quest 408 / Dargol's Skull resolves to Captain Dargol from item drops.

Unmapped objectives use "No known map location for this objective" in tracker,
tooltip, and map-navigation feedback. An unfinished item objective whose live
or imported quest summary explicitly says "You can make ... with the ... skill
or buy ... from someone with the skill" instead shows the named craft-or-player
hint. Quest 60140 supplies this instruction for Linen Bandages / First Aid.
No source records or recipe data are invented. Completed quests use their
finisher locations; an unmapped finisher reports a missing turn-in location.

Nameplate badges (0.1.65) use GudaPlates' registry when available; otherwise
Questline discovers Blizzard's default Vanilla plates among WorldFrame children
by the native Nameplate-Border texture, third (name) region, and StatusBar child.
Child-count changes trigger immediate discovery, and the 0.2-second repaint
also retries late region initialization and same-count child replacements.
Cached plates are checked every frame for newly visible plates and changed
names, painting those immediately. Unchanged visible plates
retain the 0.2-second quest-progress/selection repaint interval. Hidden plates
clear their badge state so reuse cannot retain another creature's badges.
Native badges leave space beside the health bar for Blizzard's level/skull and
preserve the plate's scripts, name, health bar, and click handling. Switching
registries hides the previous badges so GudaPlates never gets a duplicate set.
This does not bypass GudaPlates' own discovery or fresh-data show delay.
General's Show nameplate badges checkbox defaults on and saves the per-character
`nameplateBadges` preference. Turning it off immediately hides existing badges
and skips the frame updater; turning it back on immediately repaints visible plates.
In game, disable GudaPlates and reload, show enemy nameplates, and check a quest
mob, an unrelated mob, selection changes, completed objectives, and hide/show
or distance-based plate reuse. Check the Options toggle and Blizzard's level
and skull placement, then re-enable GudaPlates and reload to verify its badges.

- English quest identification uses quest links if the client supplies them; otherwise exact title, level, faction/class restrictions, and quest text. Ambiguous matches stay unmapped. Live objectives still appear in the tracker.
- Completed objective names are matched to target names, never assumed to share the database's order. Unmatched custom objective text remains visible until the quest completes.
- The imported data can still contain obsolete or server-specific records. Octo wins collisions, while Turtle-only additions are retained; retaining a record does not prove that quest is available on Octo.
- Only zone maps have areas. This POC does not project them onto continent maps, add minimap areas, select the best leveling route, or handle terrain/floors inside dungeons.
- The map list is a movable panel over the existing map, not a replacement for Blizzard's entire world-map layout.
- Test map zoom/pan with Magnify, finish an objective, turn in/abandon a quest, collapse quest-log categories, and reload. Actual rendering and the server's quest text still need confirmation in WoW.
- Open a zone map and hover a gold **!**, then close the map and approach that NPC. Check the minimap at different zoom levels. Pick up a quest, inspect its NPC progress, and turn it in to verify the next offer appears. Hover a conversation target separately from the giver/finisher. Move the cursor away from a quest mob and confirm its progress stays visible until the tooltip fades away.

## Credits

Native minimap turn-in dots are hidden with `Minimap:SetBlipTexture` when that method exists. Compatibility setup applies `Textures/minimap-blips.blp` once per session; it does not hook the method or repeatedly override other addons' atlases. Disabling Questline and reloading restores the client's normal atlas. Clients without the method retain native dots. The included atlas preserves native resource, creature, and party blips; only the top-right turn-in cell's alpha is cleared. Rebuild with `node tools/minimap-blips.js` or the normal asset build. Source provenance is in `tools/sources/README.md`. Tests check every sprite's alpha, preservation of all other bytes, deterministic output, missing API support, and one-time application. In game, check a ready turn-in, resource tracking, and party blips at each minimap zoom; other addons that replace the atlas later can restore the native dot.

Database material comes from the installed copies of pfQuest (Shagu / contributors), pfQuest-turtle, and pfQuest-octo (Gurky / contributors). Their MIT notices are retained verbatim in `licenses/`. Questline's runtime, importer, geometry builder, and generated circle/action symbols are new. No RestedXP code or guide content is included.

Completion history is recorded from confirmed turn-ins and imported once from local pfQuest history. No server completion API is called; /ql sync has been removed.

Minimap turn-ins (0.1.17): GetMinimapQuestNPCs merges available NPCs with unit finishers from completed, non-failed live quests. Finisher positions come from DB.locations, so NPCs absent from the pickup index still appear without a database rebuild. One pin per NPC uses GossipFrame/ActiveQuestIcon when any turn-in is ready and AvailableQuestIcon otherwise; tooltip sections retain both types of quest. The world map keeps its existing numbered turn-in selectors. Marker textures reset on reuse, and the same distance, zoom, rotation and clipping rules apply to both minimap marker types.
