# pandaUI class-icon sheets

Optional class-icon portraits for the player and target frames
(`M.classIcon` in `core/media.lua`, drawn by `modules/unitframes.lua`).
The "Blizzard" style reuses `../modern-wow/ui/class-portraits.tga`
(see that folder's `ATTRIBUTION.md`); the four flat styles live here.

| File | Size | Source | Notes |
|---|---|---|---|
| `flat-class-color.tga` | 256x256 | `FLATPLAYERICONS/CLASS_COLOR/Interface/TargetingFrame/UI-CLASSES-CIRCLES.blp` | Flat class icons on class-coloured discs. |
| `flat-dark.tga` | 256x256 | `FLATPLAYERICONS/DARK/Interface/TargetingFrame/UI-CLASSES-CIRCLES.blp` | Flat class icons on dark discs. |
| `flat-light.tga` | 256x256 | `FLATPLAYERICONS/LIGHT/Interface/TargetingFrame/UI-CLASSES-CIRCLES.blp` | Flat class icons on light grey discs. |
| `flat-monochrome.tga` | 256x256 | `FLATPLAYERICONS/MONOCHROME/Interface/TargetingFrame/UI-CLASSES-CIRCLES.blp` | Grey monochrome flat class icons. |

- Origin: the `FLATPLAYERICONS.zip` pack supplied by the pandaUI author in chat
  on 2026-10-25 (file dates 2022-11-24). The pack names no author or licence;
  it is a third-party replacement for Blizzard's `UI-Classes-Circles`. Its
  inclusion is the pandaUI author's decision, not a licence grant.
- Layout: each sheet keeps the Blizzard `UI-Classes-Circles` grid of 64px cells
  in CLASS_ICON_TCOORDS order (WARRIOR, MAGE, ROGUE, DRUID / HUNTER, SHAMAN,
  PRIEST, WARLOCK / PALADIN, DEATHKNIGHT, MONK, DEMONHUNTER / EVOKER), so all
  styles are addressed by `M.modernWow.classCell`.
- Conversion: BLP2 uncompressed BGRA (mip 0 only) to RLE 32-bit TGA with 8
  alpha bits, pixel-verified after writing. No change to the art.
