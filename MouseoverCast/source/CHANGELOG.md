# Changelog

## 1.0.15-beta5 (Warlock immediate-restore test)
- Fix visible target bouncing: Warlock PetAttack no longer holds a temporary target open across multiple frames.
- Select the Cursive Raid GUID, issue exactly one PetAttack / pet-bar attack, and restore the original target synchronously.
- Remove delayed Warlock target restoration and automatic repeat commands from this path.
- Keep Hunter logic, Cursive GUID detection and mouseover healing/damage behavior unchanged.
- **Experimental:** on some 1.12 pet implementations, immediate target restoration may happen too quickly for the demon to take the new target. If so, stop testing and report the trace. No reliable no-target-switch Warlock API has been confirmed yet.

# Changelog

## 1.0.15-beta4 (Warlock pet-action dispatch test)
- Fix a confirmed implementation mismatch: delayed pet-bar commands now actually invoke the original `CastPetAction(attackSlot)` instead of invoking `PetAttack()` again.
- Keep the existing temporary-target transaction, single-command safety and bounded target restoration from beta3.
- Record the actual command method/slot and hovered Cursive frame in `/moc pettrace` to separate GUID detection from pet-command issues.
- Hunter and spell casting paths unchanged.
- **Not verified in the live client**; the Warlock retargeting issue may still depend on server/client pet behavior.

## 1.0.15-beta3 (Warlock target-switch test)
- Correct Warlock attack dispatch: vanilla `PetAttack()` does not accept a targeted GUID; the conditional handler could silently attack the player’s old target.
- Use the GUID of the actually hovered Cursive Raid entry, temporarily target that unit, issue one pet attack, and safely restore the player’s selection.
- Avoid automatic Warlock re-attack loops; restore as soon as the correct pet target is confirmed, with a bounded safety timeout.
- Extend `/moc pettrace` diagnostics to show Warlock command dispatch and restoration.
- Leave Hunter handling, mouseover healing and offensive casting unchanged.
- **Known client constraint:** this compatibility path may briefly change the visible player target. Actual Warlock pet behavior must be tested in game.

# Changelog

## 1.0.15-beta2 (diagnostic test only)
- Prefer ClassicAPI's direct conditional /petattack handler when available.
- Avoid automatic temporary-target fallback for Warlocks; it can send demons back to their previous target.
- Allow one explicitly triggered reissue after a short quiet interval, without overlapping commands.
- Do not silently attack the previously selected enemy when Cursive hover is valid but no direct handler exists.
- Add `/moc pettrace` history to diagnose delayed or rejected pet orders.
- Hunter path and normal mouseover spells remain unchanged.

## 1.0.15-beta1 (previous test, unsuccessful for Warlock)
- Avoid conflicting double Pet Attack commands on Warlock demons.
- Wait for stable pet-target confirmation before restoring the original player target.
- Prevent repeated key presses from overlapping pending pet commands; allow switching to a different enemy safely.
- Add a single bounded retry when the pet does not acknowledge the selected enemy.
- Keep Cursive Raid GUID detection, Hunter support and existing mouseover spells unchanged.

## 1.0.14 — Cursive Raid Compatibility

### Added / Improved
- Improved GUID-based mouseover targeting for hostile entries in **Cursive Raid** and compatible addon frames.
- Prioritize the unit identified by the hovered addon row instead of an unrelated or stale world-mouseover target.
- Support mouseover Pet Attack through regular keybinds and the pet action bar's Attack button.

### Fixed
- Improved restoration of the original player target when a compatibility fallback temporarily selects an enemy.
- Fixed a delayed Pet Attack path introduced in 1.0.13 that could leave the enemy selected.
- Avoid overriding a manual target change while an attack is being processed.

### Compatibility
- Normal mouseover healing and offensive casting remain supported.
- Requires **SuperWoW** and **ClassicAPI** for Vanilla 1.12 / OctoWoW / Turtle WoW.
