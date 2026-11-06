# Changelog

All notable changes to Vampify are documented here.

## 0.4.0 — 2026-08-30

### Added
- Options window controls for two settings that were already live but had no UI: a "Fade duration"
  slider (0.5-4.0s) and a "Text shadow" checkbox for the scrolling combat text, next to the outline
  cycle button. Both are also reachable from the command line: `/vf sct duration <seconds>` and
  `/vf sct shadow on|off`.
- The glass-bar textures the 0.3.0 upload left out (`textures/hps_orb_*` and
  `textures/pill_*_cap`). Without them the bars drew without their fill, shading and gloss.

### Changed
- The per-hit export carries three more fields for the offline analysis: each source's own
  percentage, the zone, and whether the hit followed a cast of the same spell (item and enchant
  procs never do). All three are optional, so an older reader still parses the line.

## 0.3.0 — 2026-08-22

### Changed
- **The healing model now matches the server.** Each equipped source is evaluated as its own
  integer contribution instead of one summed float, which is what the server actually does. The
  displayed numbers changed accordingly.
- A damaging hit of 1 or less returns nothing at all — the proc does not fire there, and no
  per-source floor applies.
- The damage-over-time channel is measured rather than estimated; the display no longer hedges it.
- AoE damping is applied only where a hit is proven to have struck two or more distinct targets,
  rather than inferred from the spell.
- The display bar is compact: the prefix and the session ratio are gone, and it shows the equipped
  loadout percentage together with the number of sources it found.
- The per-hit export records maximum health per hit, so an offline analysis can tell overheal apart
  from healing that never arrived.

### Added
- Per-hit debug export for measuring the per-source factor, with a persisted toggle and an options
  checkbox.
- Spell exclusions: a spell can be stopped from counting as a Vampirism trigger, and the exclusion
  survives a reload.
- MIT license, this changelog, and a README written for players rather than for the author.

### Fixed
- The raw per-hit capture no longer depends on the watch-mode group guard.
- The persisted session breakdown survives a `/reload`.
- The "damage events appear to be missing" verdict is bounded to a single fight and to silence it
  can actually trust, instead of firing on a quiet moment.
- An AoE correction removes the integers it actually credited rather than reconstructing them.
- A mid-fight gear swap is only checked for while a fight is running.
- Long lines in a row's detail panel are wrapped instead of being drawn over the lines below them.
- Tooltips raised while the breakdown panel is open now appear above it rather than behind it.
- The whole bar can be dragged when it is unlocked. Several parts of it — the leftmost number, the
  ratio pill, the three small buttons — used to swallow the drag and act as dead spots. The resize
  grip still resizes.
- Bar fills, their shading and their gloss are each drawn on their own layer. They previously shared
  one, where this client leaves the order between them undefined and re-decides it on every reload,
  so a bar could render flat, or in one reported case not at all.

## 0.2.0 — 2026-08-10

### Added
- Minimap button, options window, and overheal reporting.
- Per-ability mouseover breakdown with real columns, plus a reset icon on the bar.
- Vampify's own scrolling combat text, selectable alongside Blizzard's, with a colour picker,
  font-size and rise-height sliders, and an SCT demo.
- The addon reports its own errors instead of waiting to be told about them.
- A watchdog that checks the running totals against the accumulator and surfaces findings.

### Changed
- An AoE cast is coalesced into one number instead of one per hit.
- The display was raised out of the action bars and given a backdrop so it can be found.
- Damage shields are excluded from the calculation.

### Fixed
- Reusing a list buffer needs `table.setn` under Lua 5.0 — without it the options window threw.
- Colour-picker layering and dragging, and a scoping bug that broke the breakdown panel.

## 0.1.0 — 2026-08-10

- First working version: detects equipped Vampirism sources, computes the returned healing from
  your own outgoing damage, and displays a running total.
