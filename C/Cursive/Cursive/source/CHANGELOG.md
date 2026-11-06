# Changelog

## 1.6 — 2026-11-03

First OEVG release, based on Wayoff333/Cursive 1.5.

### Tracking
- Add optional ClassicAPI harmful-slot reconciliation for confirmed player effects, refreshes and removals, retaining Nampower casting/GUID tracking.
- Use ClassicAPI harmful aura indices for target ghost icons and Shadow Vulnerability when available.
- Preserve pending casts while discovering confirmed auras; do not erase optimistic casts before their first confirmation.

### Appearance
- Add a Classic WoW settings style with a centered title plaque, ShaguTweaks dark/gold tinting, and an opacity slider with an opaque 100% background.
- Keep the original menu's neutral border when Classic style is off.
- Bundle a Modern Blizzard health-bar texture.
- Add independent tooltip-border options for health bars and aura icons, matching the active ShaguTweaks palette.
- Add a trimmed elite dragon above the bar's upper-right corner for elites, rare elites and world bosses; desaturate rare elites and leave normal mobs/ordinary rares unmarked.
- Add space before aura icons when the dragon option is enabled in the normal layout.
- Add session-only Test Mode using the real row geometry, sample health, raid markers, timers and GCD.
- Reduce the row-rebuild debounce from three seconds to 0.1 seconds, snap sliders to configured steps, and reflect selected text sizes in the preview.
- Fix health-border anchors that referenced a nonexistent healthBar.bar, and clear retired icons from the flash registry.

### Maintenance and validation
- Add Lua 5.0 mocked tests for ClassicAPI reconciliation, menu styling/opacity, elite classification and test-mode layout.
- Add LF checkout attributes and ignore compiled Lua files.
- OEVG tested the appearance changes in game. Broader ClassicAPI combat validation and in-game CPU/memory measurements remain outstanding.

## 1.5 — upstream

Fonts and settings preview. Earlier releases and command behavior are documented in the [upstream repository](https://github.com/Wayoff333/Cursive).