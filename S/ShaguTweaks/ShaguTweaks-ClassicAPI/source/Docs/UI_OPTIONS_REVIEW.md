# UI option hotfix review — 2026-11-03

Scope: the 3.7.3 mail, trade, Golden UI/Darkened UI, aux/AuxCraft and Bagshui
compatibility changes. This is a focused review, not an audit of every module.

## Changes from the user-tested build

- Coalesce full outgoing-mail refreshes into one pending callback. Use the
  existing feature-detected `API.Defer` bridge to ClassicAPI's native
  `C_Timer.After(0, callback)`; retain the addon queue on older builds.
  Skip the callback's work if the mail window has closed. Individual TurtleMail
  attachments still update synchronously when their textures change.
- Remove the redundant full trade-update hook. Blizzard's full update already
  calls both individually hooked slot-update functions for all seven slots.
- Preserve marked rarity colors and alpha when another addon reapplies a
  backdrop; common-white rarity borders remain white under either palette.
- Keep the slot-art matcher limited to string texture paths.
- Remove a redundant boolean expression and expand a compressed refresh block.
  The temporary diagnostic slash command was already removed.

## Performance assessment

The reviewed paths add no continuous OnUpdate driver. Work runs on item changes,
window shows, frame creation, or one-shot callbacks. The native timer is used for
scheduling, not recurring polling. New callbacks reuse their functions.

The palettes still traverse the frame tree at initialization and wrap frame
creation and border setters for compatible windows. This has a real startup and
UI-creation cost. Rarity updates also perform item lookups and border operations.
Four narrow texture strips are allocated once per slot background that needs
recoloring and then reused. The inbox also uses four parchment crops. Extra
regions consume memory and rendering work even though they need no Lua polling.

Removing the redundant trade hook avoids a second 14-slot rarity pass during a
full trade refresh. Coalescing mail refresh requests avoids duplicate work within
a scheduling interval. Neither improvement is an in-game benchmark.

No FPS, memory, GC or CPU measurements were taken in game. Lua mocks do not model
client rendering or DLL behavior. Use ClassicAPI's per-addon CPU/memory counters
with script profiling enabled for comparable fixed-duration scenarios if a
slowdown is suspected; do not use GetFrameCPUUsage for this comparison.

## Validation and remaining limits

Lua 5.0 checks are documented in `tests/README.md`. They cover qualities 0–5,
mail add/remove ordering, different items on each trade side, cleared slots,
option independence, slot reuse, palette persistence and timer fallback.

OEVG confirmed the preceding build's UI behavior in game. These cleanup changes
still need a short in-game smoke test: mail attachment add/remove, both trade
columns, Bagshui empty slots, and reopening aux/AuxCraft under each palette.
Keep version 3.7.3; no live game files were modified.
