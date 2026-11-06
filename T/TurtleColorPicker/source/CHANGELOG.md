# Changelog

All notable changes to this project are documented in this file.

## [1.0.0] - 2026-02-17

Initial public release: a standalone HSV color picker library for TurtleWoW
(WoW 1.12) addon developers.

### Added
- HSV saturation/value square with vertical hue bar.
- Optional hex color input (`#RRGGBB`).
- Old/new color preview swatches.
- Compact, draggable popup window (closable with ESC).
- Lazy initialization — no overhead until the picker is first opened.
- Public API with `onChange`, `onOk`, and `onCancel` callbacks.
- `opts.anchorFrame` option to position the picker next to a caller-supplied
  frame (e.g. a color swatch button), with smart left/right and vertical
  clamping so the popup stays fully on-screen.
- Frame strata raised to `FULLSCREEN_DIALOG` so the picker renders above
  other addons' options panels.
- README with installation instructions, API reference, and integration
  examples, including an in-game screenshot.

### Fixed
- Removed the alpha slider (not needed for pure color picking, simplified the UI).
- Worked around the Lua 5.0 32-upvalue limit by packing shared state into a
  single table.
- Removed use of `HasFocus()` / `IsMouseButtonDown()`, which are not
  available in the WoW 1.12 client API; switched the saturation/value and
  hue controls to `Button` frames with `OnMouseDown`/`OnMouseUp` instead.
- Added a guard so the picker frame is only shown after its UI has been
  created.
