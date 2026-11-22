# Gimmetbarbie Addon Manager changelog

## 1.3.0 (2026-11-21)

- Added four named addon profile slots beside **Reload UI**. Save with Shift+click, load with a click, or load and reload with Ctrl+click. Profiles preserve the manager and leave newly installed addons alone.
- Swapped the manager button actions. Left-click toggles the drawer and right-click toggles the addon list. Finishing a Ctrl+left-drag leaves both windows in their current state.
- Made the manager button movable across the screen with a saved position. Added `/am resetbutton` and kept the button sized to match the minimap's scale.
- Updated the drawer to open toward the center of the screen from the button's position. The grid uses the icon count and the largest scaled button to size its cells and leave room for icon borders.

## Upstream base

Based on Salahaja's [v1.2.0](https://github.com/Salahaja/GimmetbarbieAddonManager/tree/v1.2.0). That release already included persistent button release, drag-to-release, and configurable drawer auto-close.
