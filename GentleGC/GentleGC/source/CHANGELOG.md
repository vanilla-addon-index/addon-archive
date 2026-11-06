# Changelog

All notable changes to this OctoWoW edition of Gentle GC. Versions follow
`GentleGC.toc`. Dates are the commit dates (UTC).

## 2.8.2 - 2026-11-02

### Fixed
- The weirdperformance cycle counter in `/ggc` also counted heap drops of a few KB
  (40 "cycles" freeing 1.3 MB in all). Drops under 64 KB are no longer counted or
  printed; they are still not blamed on an unknown addon.

## 2.8.1 - 2026-11-02

### Fixed
- With weirdperformance, "collection by unknown addon" lines that were its own cycles.
  Checked against its source: a minor cycle resets the threshold by the normal
  rule, and a cycle can start when an allocation burst crosses the threshold
  between two frames. A heap drop that leaves the threshold at the normal rule is
  now counted as a weirdperformance cycle (debug line, and a count in `/ggc`),
  not as an unknown addon's collection, and it no longer disturbs the combat threshold.

### Added
- Collections that really are unattributed now print the heap and threshold
  before and after, for example `[heap 105.0 -> 99.0mb, threshold 141.0 -> 62.1mb]`,
  to help find the cause.
- `tests/test_wp_minor.lua`.

## 2.8.0 - 2026-11-02

### Added
- With ClassicAPI, `/ggc addons` reads each addon's memory live from the client
  (`UpdateAddOnMemoryUsage` / `GetAddOnMemoryUsage`): no companion, no extra
  collections at the loading screen, current numbers at any time, and a note on
  addons that grew by 100 KB or more since the last check. The
  `!!!!GentleGC_Memory` companion is now only needed without ClassicAPI, and is
  still used when the client returns nothing.
- `/ggc` shows the client's `scriptMemory` limit and warns when `scriptProfile`
  (CPU profiling) is on, since profiling slows every Lua call.
- `tests/test_native_memory.lua`.

### Repository
- README shows client-mod badges (ClassicAPI and weirdperformance, both optional).

## 2.7.1 - 2026-10-31

### Added
- Collections and threshold changes that can't be tied to an addon now name the
  game event just before them, for example
  `collection by unknown addon (after PLAYER_ENTERING_WORLD)`, or
  `(no recent event)` after 5 seconds. `/ggc` lists them under
  "unknown addon collections came" and "unknown addon threshold changes came".
  It only labels; when GentleGC collects is unchanged.
- `tests/test_unknown_context.lua`, `tests/run_all.sh` and `tests/README.md`.

### Repository
- `.gitattributes` keeps LF line endings; `.gitignore` for editor and OS files.
- README restructured with headings; the weirdperformance note moved under
  "Client mods".

## 2.7 - 2026-10-31

### Added
- weirdperformance (WeirdUtils) support. Its collector does one full mark per
  cycle and then frees memory in small chunks. GentleGC detects it through
  `GetWeirdUtilsVersion`, doesn't count or log the chunks, never starts a
  collection in the middle of a cycle, lets the chunks keep running in combat,
  and uses the combat headroom only to keep the next cycle's full mark out of
  the fight. `/ggc` shows its cycles and chunks.
- `tests/test_weirdperf.lua`.

### Notes
- Don't run weirdperformance together with wow_turbo: both replace the same
  part of the game's collector.

## 2.6 - 2026-10-31

### Added
- Detection of addons that wrap `collectgarbage` and turn GentleGC's
  collections into something else (for example, only moving the threshold to
  just above the memory in use). GentleGC says so once, names the addon when it
  can find it, and stops retrying.
- Threshold changes made by other addons (set without collecting) are listed in
  `/ggc` and logged at `/ggc debug 2`.
- `/ggc` estimates how a collection's pause splits into a fixed part and a part
  per MB freed, from GentleGC's own collections this session.

### Changed
- Pressure collections are skipped when there would be almost nothing to free.

### Tests
- `tests/test_threshold.lua`.

## 2.5 - 2026-10-30

First version in this repository: the unified edition, combining the original
by MarcelineVQ (Weird Vibes) with the event-driven collection from
jrc13245's fork and the separate report timer from TheRealFayz's fork.

- Schedules Lua garbage collection for quiet moments: loading screens, death,
  flight masters, vendor, bank, mail, auction house and trainer windows, AFK,
  and after combat.
- Never collects in combat; raises the automatic-GC threshold on entering combat.
- Careful mode when collections average 100 ms or more.
- Time and attribution of other addons' collections; garbage creation rate.
- Optional ClassicAPI support (stand-still collection, `C_Timer`).
- Freeze detector (`/ggc hitch`).
- Optional per-addon memory companion `!!!!GentleGC_Memory` (`/ggc addons`).
- Test suite in `tests/`.
