# Questie-Octo — Quest-bound AreaTrigger Objective Audit

**Date:** 2026-08-21  
**Implementation target:** 1.0.64  
**Scope:** active-quest `obj["A"]` AreaTrigger markers only

## Result

Questie-Octo 1.0.63 restored quest-bound AreaTrigger locations but deliberately kept them until the quest as a whole completed because live objective ordering was not considered trustworthy. The current runtime has 39 quests with AreaTrigger objective data; nine contain multiple AreaTrigger IDs.

The current Turtle/MaNGOS quest implementation stores `QUEST_SPECIAL_FLAG_EXPLORATION_OR_EVENT` completion in one `m_explored` state per quest. `Player::AreaExploredOrEventHappens(questId)` sets that one state and then asks whether all other quest requirements are complete. Therefore multiple AreaTrigger rows associated with one exploration requirement are alternative/OR-equivalent physical locations, not separately ordered completion counters.

Vanilla's live Quest Log exposes exploration/event requirements as an `event` objective type. Questie 5/6 likewise carries explicit event objectives. Questie-Octo can therefore attach the AreaTrigger group to live completion without assuming that the first DB AreaTrigger corresponds to the first Quest Log row.

## 1.0.64 mapping rule

For a quest containing `obj["A"]`:

1. Prefer one exact live leaderboard objective ID that equals one of the quest's AreaTrigger IDs, if ClassicAPI ever exposes that identity.
2. Otherwise accept exactly one live objective row whose type is `event`, `exploration`, `areatrigger`, or `area`.
3. Attach every AreaTrigger location for the quest to that same live row.
4. When the row is complete, every equivalent AreaTrigger pin is complete and the existing node builder stops publishing them immediately.
5. If no unique row can be proven, do not infer from array position, text order, or trigger count. Keep the old marker behavior until whole-quest completion.

This rule is localization-safe because normal matching does not depend on English objective text. It also preserves custom-script presentation entries whose live completion may be represented by a creature/object credit rather than a native event row: if Questie cannot prove the relationship, it does not hide the marker early.

## Runtime inventory

- Quests with `obj["A"]`: **39**
- Quests with multiple AreaTrigger locations: **9**
- Multi-trigger quests in the current runtime: `62`, `76`, `984`, `5156`, `9260`, `9261`, `9262`, `41802`, `41848`.

## Regression boundaries

- Generic fog/exploration markers remain disabled.
- AreaTrigger coordinates and current client geometry are unchanged.
- No quest database rows are modified.
- No polling loop is added; existing Quest Log/map invalidation drives refreshes.
- Objective order is never assumed.
- Ambiguity fails safe by keeping the marker, not by hiding it.
