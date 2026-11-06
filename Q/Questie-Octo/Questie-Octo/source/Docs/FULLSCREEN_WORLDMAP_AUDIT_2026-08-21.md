# Questie-Octo Fullscreen World Map Audit — 2026-08-21

## Scope

This audit is limited to the native Turtle/Octo fullscreen World Map lifecycle and Questie-Octo work required to create, prepare, publish, and refresh World Map quest markers. It intentionally does not change map identity, localization, minimap physical-zone isolation, pin layering, tooltip behavior, or the removed dungeon-entrance/navigation systems.

Authoritative implementation baseline: Questie-Octo 1.0.70.

Native UI authority inspected: current supplied BlizzardInterfaceCode extraction for Interface 11200.

Reference comparisons inspected: Questie 5.2.3, Questie 6.0.0, pfQuest ClassicAPI, and pfUI ClassicAPI. These references were used only to validate lifecycle/parenting patterns; they do not override current native FrameXML.

## Confirmed native fullscreen lifecycle

Current `UIParent.lua` registers `WorldMapFrame` as a `full` UIPanel. `ShowUIPanel()` routes full panels through `SetUIPanel("fullscreen", frame)`, and that path explicitly executes:

```lua
UIParent:Hide()
frame:Show()
```

Current `WorldMapFrame_Maximize()` also restores the map to full-panel behavior and detaches it from UIParent:

```lua
UIPanelWindows["WorldMapFrame"].area = "full"
WorldMapFrame:SetParent(nil)
```

Windowed/minimized mode does the reverse:

```lua
UIPanelWindows["WorldMapFrame"].area = "center"
WorldMapFrame:SetParent(UIParent)
```

The native `WorldFrame.xml` documentation explicitly states that children of `WorldFrame` remain visible even when the UI is turned off. Native `WorldFrame_OnUpdate()` also contains special handling for UI work that must continue while the map/UI visibility suppresses ordinary child OnUpdate execution.

Current `FrameXML.toc` loads `WorldFrame.xml` before `UIParent.xml` and long before `WorldMapFrame.xml`, so the `WorldFrame` global is a foundational native frame already available before Questie-Octo addon files load.

## Questie-Octo choke point

Questie-Octo 1.0.70 creates the global bounded scheduler as a child of UIParent:

```lua
local f=CreateFrame("Frame","QuestieOctoSchedulerFrame",UIParent)
```

Its `OnUpdate` is the only driver for both delayed callbacks and the O(1) FIFO continuation queue:

```lua
RunDelayed(S,delta)
S:Tick()
```

A hidden parent prevents a child's normal `OnUpdate` from executing. Therefore native fullscreen World Map mode can pause the Questie-Octo scheduler for the entire time UIParent is hidden.

This matches the historical player symptom precisely:

```text
open native fullscreen World Map
→ pending quest-map work is queued
→ UIParent is hidden
→ QuestieOctoSchedulerFrame OnUpdate stops
→ queued/delayed map work remains pending
→ minimize/window the map
→ UIParent becomes visible again
→ scheduler resumes
→ pending pins appear
```

Already-created pins remaining visible after maximizing is also consistent with this diagnosis because Questie-Octo World Map pin buttons are already children of `WorldMapButton`, not UIParent.

## Scheduler-dependent World Map path

The audit traced fullscreen-relevant work through the scheduler. Important scheduled stages include:

- `Map/ZoneBootstrap.lua`: first-zone priority scan and delayed zone requests.
- `Map/Nodes.lua`: canonical node sorting/publication and available/item-start/permanent node slices.
- `Map/Prepared.lua`: complete and dirty prepared-map construction.
- `Map/CandidateIndex.lua`: candidate index construction.
- `Map/Map.lua`: continent rendering, prepared-map rendering, first-visit preparation, and every deferred `RequestSync()`.
- `Quest/AvailableQuests.lua`: availability scans and refreshes that can publish changed map relationships.
- `Quest/Objectives.lua`: objective resolution/refresh work.
- `Quest/ItemStarts.lua`: item-start resolution/availability work.
- `Quest/QuestLog.lua` and `Quest/Completion.lua`: quest-state work that can ultimately change published map nodes.

So changing only the final map hook would not be sufficient: the shared scheduler is the upstream lifecycle dependency for both producing and rendering current map state.

## World Map frame/pin parenting audit

Questie-Octo World Map pins are created as:

```lua
CreateFrame("Button",nil,WorldMapButton)
```

They therefore follow the native World Map hierarchy in both fullscreen and windowed modes. No standalone overlay, forced high frame level, WorldMapFrame reparent, or alternate tooltip frame is required.

The existing frame level remains relative to `WorldMapButton` and was not changed.

## World Map event frame audit

`QuestieOctoWorldMapEvents` remains parented to UIParent and was not changed. It is an event receiver, not the scheduler's visibility-driven OnUpdate loop. Registered event dispatch is not the same mechanism as normal visible-frame OnUpdate execution, so broad event-frame reparenting is not justified by this bug.

Its existing `WORLD_MAP_UPDATE` handler, `PREPARED_MAP_READY`, `NODES_CHANGED`, `NODES_READY`, and WorldMapFrame OnShow hook all continue to request synchronization through the scheduler. Once the scheduler remains active during fullscreen, these existing refresh boundaries can complete without adding polling.

## Other Questie-Octo OnUpdate frames

The audit inventoried other OnUpdate users and intentionally left them unchanged:

- Tracker timer-row updater: UI presentation tied to the tracker/UIParent.
- Minimap updater: child of `Minimap`, intentionally tied to minimap visibility/lifecycle.
- Completion timeout/reset checks: not required to render fullscreen World Map pins continuously and should not be broadly reparented as part of this focused fix.
- EventAvailability 60-second policy refresh: unrelated to World Map frame rendering.
- Quest Log enhancement watcher: intentionally useful only while Quest Log is open.
- Zone level-range hover updater: already a child of `WorldMapFrame`, so it follows the visible map directly.
- temporary UI drag/reward/Ace OnUpdates: UI-local behavior only.

No broad frame-tree change was made.

## Reference-addon compatibility notes

The supplied pfUI implementation can convert the native World Map to a center/windowed-style panel and overrides native maximize/minimize behavior. The scheduler parent correction is compatible with that model because it does not depend on WorldMapFrame's parent or frame level; it only removes UIParent visibility as a prerequisite for Questie-Octo background continuations.

No pfUI-specific runtime branch was added.

## Implemented correction for 1.0.71

Only the scheduler frame parent changes:

```text
UIParent -> WorldFrame
```

Scheduler behavior is otherwise unchanged:

- O(1) FIFO head/tail queue retained.
- Maximum 2 jobs per frame retained.
- Approximate 4 ms frame budget retained.
- Due timers still enter the same bounded FIFO.
- No table.remove(queue,1).
- No polling loop added.
- No map frame/pin reparenting.
- No frame-level changes.
- No map identity/localization changes.
- No minimap movement/physical-zone changes.

## Static acceptance

The correction is source-backed and isolated. Static validation can establish that the scheduler no longer inherits UIParent's fullscreen-hidden state and that all existing map refresh pathways still target the same scheduler API.

It does **not** prove live in-game behavior. Live confirmation should specifically check:

1. Open native fullscreen World Map before a zone's prepared map finishes; pending pins should appear without minimizing.
2. Complete/advance a quest objective while fullscreen; affected pins should refresh without minimizing.
3. Accept/turn in a quest while fullscreen where the client allows the map to remain open; availability/turn-in markers should settle without minimizing.
4. Switch zone/continent in fullscreen and allow first-visit preparation to complete.
5. Minimize then maximize repeatedly; no duplicate pins or stale frames.
6. Normal windowed World Map behavior.
7. Close the World Map and verify minimap refresh/physical-zone safeguards remain unchanged.
8. Repeat with pfUI or another UI replacement that keeps the World Map windowed/centered.

Until that live test is completed, describe 1.0.71 as source/static validated rather than player-confirmed.
## Live follow-up: 1.0.72 fullscreen tooltip lifecycle

Live testing of 1.0.71 confirmed the scheduler diagnosis only addressed marker creation/update. The supplied 2026-08-21 recording shows Questie-Octo markers visible on the native fullscreen World Map while marker hover information does not appear.

The remaining lifecycle is independently source-backed:

```text
GameTooltip parent = UIParent
native fullscreen World Map -> UIParent:Hide()
Questie-Octo World Map pin hover -> GameTooltip
therefore tooltip content can be built/shown while its parent hierarchy is hidden
```

Current native FrameXML defines the map-specific tooltip differently:

```text
WorldMapTooltip parent = WorldMapFrame
```

That places `WorldMapTooltip` inside the visible native fullscreen map hierarchy. Blizzard itself uses this tooltip for World Map interaction. The supplied pfQuest ClassicAPI reference also selects `WorldMapTooltip` when a node's parent is `WorldMapButton`, and `GameTooltip` otherwise. The supplied pfUI reference explicitly scales, skins, and uses `WorldMapTooltip`, so this is also a known-compatible path for pfUI.

### 1.0.72 correction

Questie-Octo now selects the tooltip by pin hierarchy:

```text
WorldMapButton child -> native WorldMapTooltip
other pin/hover paths -> existing GameTooltip or pfUI-private tooltip
```

The same selection is used for OnLeave/Hide. No scheduler behavior, pin parent/frame level, map identity, minimap path, native WorldMapFrame parent, or mouse polling is changed. No new tooltip/overlay frame is created. This is therefore distinct from the previously rejected standalone WorldMapTooltip/mouse workaround.

### Live acceptance for 1.0.72

1. Open the native World Map fullscreen and hover newly-created Questie-Octo pins; the tooltip should appear immediately.
2. Hover clustered, Full Nodes, item-start, available, completed, permanent-service, and rare markers where available.
3. Move off the marker; the World Map tooltip should hide cleanly.
4. Minimize/window the map and verify marker tooltips still work.
5. Close the map and verify minimap marker tooltips and normal unit/object/item GameTooltips are unchanged.
6. If using pfUI, verify its normal WorldMapTooltip skin/scale remains intact and minimap-pin tooltips do not recurse.

Live follow-up on 2026-08-21 reported the combined 1.0.71 scheduler correction and 1.0.72 WorldMapTooltip correction working perfectly in the native fullscreen World Map. Questie-Octo 1.0.72 is therefore the accepted live-confirmed fullscreen baseline; the listed scenarios remain useful regression checks for future releases.

