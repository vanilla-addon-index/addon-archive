# pandaUI textures (top level)

Theme folders keep their own `ATTRIBUTION.md`. This file covers textures that
sit directly in `media/Textures/`.

- `quest-starter.tga`: small yellow available-quest mark on bag and bank items
  that begin a quest (`M.texture.questStarter`, drawn by `core/itemslot.lua`).
  Copied unchanged on 2026-10-26 from PandaQuest's
  `media/Textures/Map/Pins/questIcon.tga`, where it is the addon-owned
  available-quest icon. It is a 32x32 uncompressed RGBA TGA with a 19x32
  authored crop; PandaUI removes only the transparent right padding at draw time.
- `mousewheel-zoom.tga`: World Map "wheel zooms" hint (`M.texture.mapZoomHint`,
  drawn by `modules/worldmap.lua`). Supplied by the pandaUI author on
  2026-10-20; the author generated it with ChatGPT's image model from a prompt
  written for this addon. Conversion: the 1254x1254 transparent WebP was
  cropped to its visible content, padded to a square, scaled down
  with premultiplied alpha to 64x64 and saved as an uncompressed 32-bit TGA.
  No other change to the art.
- `../icons/pUI_settings-panda.tga`: panda watermark in the bottom-right corner
  of the settings pages (`M.texture.settingsWatermark`, drawn by
  `modules/settings.lua`). Supplied by the pandaUI author on 2026-10-26 as
  `Panda/game-settings.png`, a 256x256 RGBA PNG. Conversion: saved unchanged
  as an uncompressed 32-bit TGA (no resize, no change to the art).
- `settings-panda-icon.tga`: round gold-rimmed panda face used as the minimap
  settings button (`M.texture.settingsIcon`, drawn by `modules/minimap.lua`).
  Supplied by the pandaUI author in chat on 2026-10-21 as a 64x64 RGBA PNG.
  Conversion: saved unchanged as an uncompressed 32-bit TGA (bottom-left
  origin, 8 alpha bits). No change to the art.
