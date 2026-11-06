# Questie-Octo — Tracker Objective Refresh Audit

**Audit date:** 2026-08-23  
**Source audited:** Questie-Octo 1.0.74  
**Rejected version:** 1.0.75 (not used)  
**Correction build:** 1.0.76

## Live report

The player reported that the custom tracker could show three generic objective rows for quest 255, **Mercenaries**:

```text
- slain: 0/4
- slain: 0/4
- slain: 0/4
```

The player then clicked the tracker `-` button and `+` button. The rows immediately populated with the mob names.

Questie-Octo's current database for quest 255 is correct and contains the three unit objectives 1178, 1179 and 1180: Mo'grosh Ogre, Mo'grosh Enforcer and Mo'grosh Brute.

## Decisive code trace

`TrackerFrame:ToggleExpanded()` changes only the saved expanded flag and calls `TrackerFrame:Render()`. It does **not** call `QuestLog:Refresh()` or `TrackerDriver:Rebuild()`.

Therefore, if `-` -> `+` immediately repairs the displayed objective text, `TrackerDriver.ordered` already contains the newer objective objects before the click. The failure is downstream of data acquisition and tracker-state rebuilding.

`TrackerDriver:Rebuild()` always replaces `self.tracked` and `self.ordered`, then emits `TRACKER_STATE_CHANGED` only when its compact snapshot changes. Before 1.0.76, the objective portion of that snapshot contained:

```text
text
complete
current
required
```

But `TrackerFrame` does not render from only those fields. `ObjectiveTextForDisplay()` preferentially renders `rawText` when it is considered settled, and branches on `rawTextIncomplete`.

This creates a valid state transition that the old snapshot cannot see:

```text
first native rawText:  slain: 0/4
normalized text:       Mo'grosh Ogre: 0/4
current/required:      0 / 4

later native rawText:  Mo'grosh Ogre slain: 0/4
normalized text:       Mo'grosh Ogre: 0/4
current/required:      0 / 4
```

QuestLog's own snapshot includes the native objective text, so it notices the settlement and sends `QUEST_LOG_CHANGED`. TrackerDriver rebuilds and stores the newer objective object, but its old display snapshot remains byte-equivalent because `text/current/required/complete` did not change. It therefore suppresses `TRACKER_STATE_CHANGED`. The visible FontString remains stale until some unrelated action calls `TrackerFrame:Render()` directly. The player's `-` -> `+` action is exactly such a direct render.

## Relation to 1.0.52

1.0.52 addressed Turtle/ClassicAPI's objective-label settlement race by preserving a complete prior/native label, distinguishing incomplete raw labels, and performing bounded settled Quest Log reads after login. That logic remains present and valid in 1.0.74.

The current report exposes a separate invalidation gap around the same dual-text model: the Quest Log and TrackerDriver can already hold repaired data while TrackerFrame is not notified because the driver's equality key omitted fields that the renderer actually uses.

## Reference comparison

### Native Blizzard FrameXML

The supplied current `FrameXML/QuestLogFrame.lua` registers `QUEST_LOG_UPDATE`, `QUEST_WATCH_UPDATE`, and `UNIT_QUEST_LOG_CHANGED`. On `QUEST_LOG_UPDATE` or player `UNIT_QUEST_LOG_CHANGED`, it calls `QuestWatch_Update()`, which rereads `GetQuestLogLeaderBoard()` and writes the current objective text directly into the watch FontStrings. There is no separate cached display hash that can omit native objective text.

### pfQuest ClassicAPI

pfQuest's tracker `ButtonEvent()` rereads `GetQuestLogLeaderBoard()` and uses that text directly for objective rows. Its quest subsystem also maintains independent refresh safety work. Again, the current displayed native text is read during tracker updates rather than filtered through a display hash that omits it.

### Questie 5.2.3 / 6.0.0

Both references explicitly account for delayed/strange objective text. Their `GetQuestObjectives` helper retries transient nil/empty/`: 0/1`-like objective rows, and their quest-log event handling buckets `QUEST_LOG_UPDATE` to allow Blizzard API state to propagate.

These references support keeping Questie-Octo's settlement protection. They do not justify polling or replacing Questie-Octo's current cache architecture.

## Rejected hypotheses / changes

### Missing `OBJECTIVES_CHANGED` listener

Rejected as the primary fix. Questie-Octo's `Quest/Objectives.lua` is the physical objective-source/map resolver. It refreshes from `QUEST_MAP_STATE_CHANGED`, whose QuestLog signature deliberately excludes simple numeric progress changes to avoid rebuilding map nodes for every 3/10 -> 4/10 transition. `OBJECTIVES_CHANGED` is therefore not the general tracker-progress signal.

### Periodic tracker/quest polling

Rejected. The live reproduction can be explained entirely by a missing renderer invalidation field. Polling would add permanent work and hide the actual bug.

### Rebuilding the tracker on every frame/event

Rejected. The existing snapshot optimization is valid; it simply needs to represent the fields that the renderer consumes.

### Changing native objective wording to database wording globally

Rejected. Questie-Octo intentionally preserves complete native Turtle wording because scripted objectives can be more actionable than a bare database entity name.

## 1.0.76 correction

The TrackerDriver objective snapshot now also includes:

```text
rawText
rawTextIncomplete
```

No other tracker architecture changes were made.

This makes `TRACKER_STATE_CHANGED` fire when native objective wording settles even if the normalized text and numeric progress are already identical.

## Performance / Lua memory

No new frame, OnUpdate, timer, polling loop, event registration, database scan, or persistent table is added. Two fields are appended to the existing temporary snapshot parts for each currently tracked objective, and the concatenated snapshot retains those extra characters until the next rebuild. On Vanilla's 25-quest log this is at most a small number of kilobytes in pathological objective-heavy cases and normally far less.

## Static regression checks

- QuestLog event/scheduler logic unchanged.
- 1.0.52 bounded objective-settlement logic unchanged.
- Tracker sorting/tracking/collapse state unchanged.
- Tracker `-` / `+` behavior unchanged.
- Fullscreen scheduler and WorldMapTooltip fixes unchanged.
- Map/minimap objective invalidation unchanged.
- Runtime database unchanged.
- No ClassicAPI.dll bundled.

## Live acceptance test

The source diagnosis is strong, but in-game confirmation remains required. Test an objective whose tracker initially shows generic or late-settling wording and leave the tracker expanded. The objective name/progress should repaint by itself once the native Quest Log data settles; `-` -> `+`, zone change, Quest Log opening, or `/reload` should no longer be required.
