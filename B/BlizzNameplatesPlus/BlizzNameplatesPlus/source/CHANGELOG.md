# Changelog

## 2.0.2-oevg.7 (2026-11-07)
- Apply the retail texture to nameplate castbars when Modern Class Colors is enabled. Existing castbars update immediately and keep their cast colors.

## 2.0.2-oevg.6 (2026-11-06)
- Add Level Number Scale under Nameplates > Names & Level: 50–150% in 5% steps, default 100%. Applies immediately and to newly shown/recycled plates, preserving font and outline. Independent of nameplate scale and name font size.
- Local Lua 5.0 parse and scale/restoration checks pass; in-game testing remains required.

## 2.0.2-oevg.5 (2026-11-06)
- Replace the rectangular level fill with an alpha-masked 128x32 atlas sharing the exact bounds and all eight UV coordinates of the nameplate border. Pixels outside the level inset are transparent.
- Use a fixed dark olive-black level background inspired by the supplied WoW Forever reference, replacing health-texture/color matching at OEVG's request.
- Local Lua and atlas-mask checks pass; in-game visual confirmation required.

## 2.0.2-oevg.4 (2026-11-06)
- Fix level-fill placement to account for the native border texture's cropped UV coordinates. The previous geometry incorrectly assumed the whole 128x32 atlas was displayed, causing misplaced fills and spill outside the level inset.
- Recompute geometry when the border crop or size changes. Add Lua 5.0 regression checks for cropped and resized borders.
- Local checks pass; corrected placement still needs in-game visual confirmation.

## 2.0.2-oevg.3 (2026-11-06)
- Level backgrounds now use the health bar texture and current color on target and non-target nameplates, including modern textures, player class colors, NPC reaction colors and BNP color overrides. Border tint remains independent.
- Reuse the existing visual guard and cache texture, color and geometry writes. Original personal-plate artwork remains intact.
- Local Lua 5.0 checks only; requires in-game testing.

## 2.0.2-oevg.2 (2026-11-06)
- Recolored Border also themes the baked-in rims of debuff and crowd-control icons. Darkened UI and Golden UI use ShaguTweaks' configured colors; spell artwork and timer/stack text retain their colors.
- Refresh pooled icons when their spell or size changes, and restore their original rims immediately when Recolored Border is disabled. No additional update loop.
- Lua 5.0 parse and mocked appearance checks pass; in-game visual testing remains required.

## 2.0.2-oevg.1 (2026-11-06)
- Rename Dark Border to Recolored Border; follow the active ShaguTweaks Darkened UI or Golden UI texture tint, including configured colors.
- Keep the level-number background neutral when target border color is enabled, including bold borders.
- Add an independent Modern Class Colors toggle: retail health textures for all nameplates, modern colors for every player class, and native NPC reaction colors. Personal health bars follow the same toggle.
- Retain existing saved border settings and BNP class-color, tank-mode, and foreign-tag controls.
- Local Lua 5.0 checks only; requires in-game visual testing.
