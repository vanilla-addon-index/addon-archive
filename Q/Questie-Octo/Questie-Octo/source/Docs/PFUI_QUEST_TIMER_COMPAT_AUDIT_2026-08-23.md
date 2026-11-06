# Questie-Octo pfUI / Native Quest Timer Compatibility Audit

**Audit date:** 2026-08-23  
**Implementation baseline:** Questie-Octo 1.0.74  
**Correction build:** Questie-Octo 1.0.77  

## Player report

With pfUI active, the Blizzard Quest Timer frame appeared at the bottom-left of the screen and could not be moved normally through pfUI Unlock Mode while Questie-Octo's tracker was enabled.

## Source findings

### Questie-Octo 1.0.74

`Tracker/TrackerFrame.lua` suppressed Blizzard's native `QuestTimerFrame` by moving it to `-10000,-10000`. It then saved and replaced `SetPoint`, `ClearAllPoints`, and `SetAllPoints` with no-op functions while the Questie-Octo tracker was enabled.

### pfUI-classicAPI-octo

The supplied pfUI skin registers `QuestTimerFrame` as a movable through `UpdateMovable(QuestTimerFrame, true)`. pfUI's default `global.offscreen = "0"` causes `UpdateMovable` to call `SetClampedToScreen(true)`. pfUI also wraps `QuestTimerFrame.SetPoint` so native MinimapCluster positioning cannot overwrite the user's movable position.

This makes Questie-Octo's old suppression incompatible with pfUI: an intentionally far-offscreen anchor may be clamped back to the visible screen, while Questie-Octo's no-op positioning methods prevent pfUI Unlock Mode from moving the frame normally.

### BlizzardInterfaceCode

Blizzard's `QuestTimerFrame` is a normal `UIParent` child. `QuestTimerFrame_Update(GetQuestTimers())` maintains `numTimers`, shows the frame when timers exist, and hides it when none exist. Its `OnUpdate` only runs while `numTimers > 0` and updates the countdown. `QUEST_LOG_UPDATE` and `PLAYER_ENTERING_WORLD` continue updating timer state independently of whether the frame was previously hidden.

## Correction

Questie-Octo 1.0.77 keeps the existing suppression hooks but changes suppression to ordinary `QuestTimerFrame:Hide()` only. It no longer:

- moves the frame offscreen;
- changes its anchors;
- replaces `SetPoint`;
- replaces `ClearAllPoints`;
- replaces `SetAllPoints`.

When the Questie-Octo tracker is disabled, the native frame is shown again only when its existing `numTimers` state is greater than zero. The native frame then resumes its own countdown update.

## Scope / performance

Questie-Octo's internal timed-quest rows are unchanged. No new polling, `OnUpdate`, timer, database scan, map refresh, frame allocation, or persistent cache is introduced.

The correction is intentionally isolated from the generated 1.0.76 tracker-objective test candidate. 1.0.77 starts from the accepted 1.0.74 baseline and contains only this timer compatibility correction plus version/documentation changes.

## Separate FloatingChatFrame error

The supplied screenshot also contains repeated `FloatingChatFrame.lua:1019` arithmetic-on-nil errors. No current Questie-Octo source path modifies FloatingChatFrame geometry or `FCF_UpdateButtonSide`, so this audit does not attribute that separate error to Questie-Octo.

## Live acceptance test

1. Use pfUI with its Quest Timer skin/movable enabled.
2. Accept or use a quest with an active timer.
3. Keep the Questie-Octo tracker enabled: the duplicate Blizzard/pfUI timer must stay hidden; Questie-Octo's timer row must continue counting down.
4. Enter pfUI Unlock Mode: no stuck `QuestTimerFrame` dragger should appear at bottom-left because Questie-Octo no longer forces an offscreen anchor.
5. Disable the Questie-Octo tracker while the timed quest is still active: the native/pfUI Quest Timer should appear at pfUI's own saved position and continue counting down.
6. Re-enable the Questie-Octo tracker: the native/pfUI timer should hide again without its position being changed.
