# Changelog

All notable changes to this project are documented here.

---

## [1.4.5] - 2026-04-09 — Realm Support & Stability Release

### Added
- **Realm-specific timer storage**  
  Timers are now saved per realm (`RallyHelperDB[realmName]`). Switching realms no longer carries over timers from previous realms.

- Improved `EnsureDB()` with safe realm handling and one-time migration from old account-wide data.

### Changed / Improved
- Updated `RH_ServerRestartDetector` with more reliable detection patterns (including "server restarted", "just restarted", etc.).
- `PrintStatus()` now shows the current realm name for easier debugging.
- Minor code cleanups and consistency improvements.

### Fixed
- Cross-realm timer leakage issue.
- Potential issues with server restart detection on different Turtle WoW realms.

---

## [1.4.4] - 2026-04-29 — Restart Detection & Timer Robustness

### Added
- Significantly improved server restart detection with multiple message patterns.
- Extra tolerance for fresh clients and right after server restarts in `IsSuspicious()`.

### Changed
- Timer verification now prefers the timestamp closest to `now` from `TIMER_*` responses.
- Sound playback hardened with better fallback logic.

### Fixed
- Rare cases where bad client clocks could cause large timer jumps.
- Various small stability issues in timer acceptance.

---

## [1.4.0] - 2026-03-28 — Major UI & Features Update

### New
- Completely redesigned, modern, and scalable UI with icons and faction-colored sections.
- New **Settings Window** (`/rally settings`):
  - Faction filter (Horde / Alliance / Both)
  - UI width, height, and scale sliders
  - UI lock option
- New **Unconfirmed Buffs Window** with filters and scrollable list.
- Improved minimap button with more actions (Alt-click, Shift-click, Middle-click).
- Customizable buff sounds with volume control and per-event sound files.
- Toast system (`/rallytoast chat|ui|none`).
- Ignore list (`/rallyignore add|remove|list <name>`).

### Improved
- Much cleaner and more responsive synchronization.
- Better pfUI compatibility.
- Hover fade effect on the main UI.

---

## [1.3.7] - 2026-03-24 — Stability & Robustness Release

### Fixed
- Robust timer selection from `TIMER_*` responses (prevents outliers from breaking correct timers).
- Timestamp sanity checks in `AcceptEvent`.
- Table length safety (replaced `#` with safe checks).
- Sound handling improvements and better error protection.

### Changed
- Added ignore list and toast mode configuration.
- Message versioning support.

---

## [1.3.6] - 2026-03-22 — UI Stability Update

### Fixed
- Critical `SetVerticalScroll` errors in Unconfirmed window.
- Syntax and initialization issues in UI creation.
- Vanilla/Turtle WoW compatibility with `SetPoint`.
- ScrollFrame safety when list is empty.

---

## Older Versions
- **1.3.0** — Unconfirmed UI rework
- **1.2.0** — Sync stabilization and `RHGlobal` improvements

---

## ⚠️ Known Incompatibility
**LazyPig** can interfere with chat handling and timer synchronization. If you experience issues, try disabling LazyPig.

---

## Contributing
Feel free to open issues or pull requests on GitHub.  
When reporting sync or timer problems, enable debug mode (`/rally debug`) and include relevant logs.

---
