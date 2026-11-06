# Changelog

All notable changes to OctoLatency are documented in this file.

## [Unreleased]

## [1.3]
### Added
- FPS display next to latency in the main frame and tooltip, color-coded (green ≥30, yellow 15-30, red <15), via `GetFramerate()`.
- `/octolat worldlatency` slash command to opt in to world latency display.

### Changed
- World latency is now hidden by default (tooltip shows `N/A`, status text always uses home latency) since many private-server cores (including OctoWoW) never populate it. Enable it with `/octolat worldlatency` on servers that do report it.
- Widened the frame (90px → 150px) and status text (80px → 140px) to fit the added FPS text.

## [1.2]
### Fixed
- Drag could get permanently stuck following the cursor: `OnMouseUp` only fires while the mouse is still over the frame at the instant the button is released, which a quick flick of this small (90x24) frame easily misses. `OnUpdate` now polls `IsMouseButtonDown("LeftButton")` every frame and stops the drag as soon as the button is released, regardless of where the cursor ends up.

## [1.1]
### Added
- `/octolat copyerrors`, opening a copy-errors window: a multi-line `EditBox` pre-filled with the error log and auto-highlighted, so the text can be selected and copied with Ctrl+C (vanilla WoW's chat frame doesn't support text selection).
- Colored addon title in the character-select AddOns list: `OctoLatency` now renders as a per-letter gradient from dark to light green (`## Title:` in `OctoLatency.toc`).

### Fixed
- Tooltip (`OnEnter`) no longer errors with `attempt to concatenate local 'worldLatency' (a nil value)`. `GetNetStats()` can return `nil` for latency/bandwidth briefly after login or a loading screen; the tooltip now falls back to `0` for `bandwidth`, `homeLatency`, and `worldLatency`, matching the fallback already used by the status text update.
- Status text no longer gets stuck at `0 ms` on servers whose `GetNetStats()` never populates world latency: `0` is truthy in Lua, so the old `worldLatency or homeLatency` fallback never triggered. World latency is now only used when it's greater than `0`, otherwise home latency is shown.
- Frame's `OnLoad`/`OnUpdate`/`OnMouseUp`/`OnHide` scripts in `OctoLatency.xml` now check that the corresponding global function exists before calling it. Previously, if `OctoLatency.lua` failed to load for any reason, `OnUpdate` would throw `attempt to call global 'OctoLatency_OnUpdate' (a nil value)` on every single frame, flooding the chat frame badly enough to block Enter/chat input.

## [1.0]
### Added
- Core addon: draggable frame showing world latency (falling back to home latency) with color-coded text (green < 150ms, yellow 150–350ms, red > 350ms), updated every 2 seconds.
- Tooltip on hover showing home latency, world latency, and bandwidth.
- `/octolat errors` slash command to view the last 20 logged errors in-game.
- `/octolat clearerrors` slash command to clear the error log.
- Error logging: tooltip/update/login handlers run through `pcall`, with failures recorded to `OctoLatencyDB.errorLog` (persisted in SavedVariables) and echoed to the chat frame instead of raising a Lua error popup.

### Fixed
- Stuck drag state when the mouse button is released off-frame: dragging now also stops on `OnHide`, not just `OnMouseUp`.

### Removed
- Dead `VARIABLES_LOADED` event registration (no handler was ever attached to it).
