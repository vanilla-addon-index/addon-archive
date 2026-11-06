# Changelog

All notable changes to BulwarkFrame are documented here.

## v0.3.1 — 2026-08-31

### Fixed
- **Aura-id edit boxes no longer accept 0.** A QA pass on the options panel
  found that `tonumber("0")` is truthy, so typing `0` into the pool or time
  aura spell-id field was accepted as a valid id and silently written --
  spell ids never start at 0, so this was a silent no-op buffer. `0` (and
  negative values) are now rejected exactly like any unparsable entry: the
  field reverts to the currently stored id.
- **Pool/expiry red and yellow thresholds can no longer cross.** The four
  threshold sliders had no cross-validation, so dragging the red slider
  past yellow (or yellow past red) inverted the colour chain in
  `core/calc.lua`'s bucket logic. The slider being moved now pulls its
  partner along with it instead of letting the pair invert, and the panel
  display re-syncs immediately.

## v0.3.0 — 2026-08-30

### Added
- **Options panel controls for every setting that had none.** An audit of
  `core/config.lua` found ten saved settings with no way to change them
  short of hand-editing the SavedVariables file. The options panel now has:
  a slider for the gap between the three bars (**Bar spacing**); a checkbox
  for the attack-speed number on the expiry bar (**Attack speed text**); a
  slider for the expiry bar's opacity (**Expiry bar opacity**); a colour
  swatch plus opacity slider for the frame's background (**Background** /
  **Background opacity**); sliders for the four colour-bucket thresholds
  (**Pool red/yellow threshold**, **Expiry red/yellow threshold**); a
  slider for the set-bonus percentage (**Set bonus value**); a slider for
  how much of your latency shifts the swing marker (**Latency share**);
  and, under a new **Aura IDs** heading, numeric edit boxes for the pool
  and time buff spell ids, in case TurtleWoW renumbers the custom spell in
  a future patch. Every control applies immediately, refreshes when the
  panel reopens, and is covered by the Reset button, the same as every
  pre-existing option.

## v0.2.0 — 2026-08-15

### Fixed
- **Max health readout stays accurate through stamina buffs and level-ups.**
  It was previously only re-read on zone-in and gear changes, so a Fortitude,
  Gift of the Wild, food buff, or world buff picked up mid-raid left every
  number on the readout roughly 10% low until the next zone change. It now
  refreshes on any player max-health change and on level-up.
- **"Combat only" no longer gets stuck off after a mid-fight reload.** The
  combat flag was only ever set by entering or leaving combat, so a `/reload`
  taken during a fight left it false for the rest of the encounter and hid the
  frame outright for anyone using the "Combat only" option. It is now seeded
  from the live combat state on login and on entering the world.
- **The frame can no longer get stranded off-screen.** `/bulwark reset` and
  the options panel's Reset button wrote the default position into the saved
  settings but never moved the on-screen frame, so a frame dragged to the
  edge stayed there until the next login. Reset now actually re-anchors the
  frame, which is also clamped so it cannot be dragged off-screen in the
  first place.
- **Right-clicking the minimap button now reliably hides the "SuperWoW
  required" hint.** The manual-hide flag was checked after that hint, so
  without SuperWoW installed the hint frame could never be dismissed, even
  though the minimap toggle reported it as hidden.
- **`/bulwark show` and `/bulwark demo` now actually bring the frame back.**
  Both commands cleared "hide when idle" and "combat only" but left a manual
  minimap-toggle hide in place, so the frame stayed off-screen and demo mode
  ran invisibly. Both commands now clear the manual hide as well, and say so
  in their chat confirmation.
- **The options panel no longer shows stale values after a slash command.**
  `/bulwark reset`, `/bulwark lock`, `/bulwark show`, and `/bulwark demo`
  changed settings without refreshing an already-open options panel, so its
  checkboxes, sliders, and buttons kept showing the pre-command state —
  nudging a stale slider could even silently undo what the command had just
  done. The panel now re-syncs itself after every one of these commands.
- **The absorb-rate readout no longer shows a number for an unlearned
  talent.** A talent rank of zero was treated as "no value set" rather than
  "rank 0", so an additive set-bonus reading could produce a plausible-looking
  absorb rate for a talent the character never trained. It now correctly
  shows `--` in that case.

### Changed
- **Lower CPU usage while the buffer is inactive.** The update loop now
  detaches itself once there is nothing left to animate — no active buffer,
  no swing in progress — instead of redrawing five times a second regardless,
  and re-attaches automatically the moment a swing lands or the buffer
  refills.
- **Removed the addon's remaining per-tick and per-swing memory
  allocation.** The colour-threshold lookup and the aura scan that runs on
  every incoming swing no longer build and discard temporary tables and
  closures, avoiding needless garbage-collector churn during combat.
