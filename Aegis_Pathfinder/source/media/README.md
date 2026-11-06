# media/

Every texture here is **generated**. Do not edit the `.tga` files by hand —
change `Tools/build/make_assets.py` and re-run it:

```sh
pip install Pillow
python3 Tools/build/make_assets.py
```

## Format

All textures are written in a format known to load on the 1.12 client:

| Property | Value |
|---|---|
| Type | 10 — RLE-compressed truecolor |
| Depth | 32-bit |
| Origin | bottom-left (descriptor byte `0x08`, 8 alpha bits) |
| Colour map | none |
| ID field | none |
| Dimensions | powers of two |

`Tools/verify.py` enforces all of this, so a texture that would fail to load
is caught before it is committed.

Colour is **not** baked into most files. Shapes are white masks that
`Theme.lua` tints with `SetVertexColor`, which is why a single 32×32
rounded-rectangle serves every panel, tab, pill and band. Only genuinely
multi-colour art bakes colour in: `nav-arrow.tga`, `progress-fill.tga`, and
`minimap-logo.tga` and `logo.tga`, which are the owner's logo art scaled down,
and the pictures in `loadscreens/` and `maps/`.

## Contents

| File | Size | Purpose |
|---|---|---|
| `solid.tga` | 8×8 | Flat fills, dividers, progress tracks |
| `panel-fill.tga` | 32×32 | Nine-slice window body, 10px corner radius |
| `panel-border.tga` | 32×32 | Nine-slice 1px border |
| `pill-fill.tga` / `pill-border.tga` | 32×32 | Route-pack selector pills |
| `tab-fill.tga` / `tab-border.tga` | 32×32 | Tab bar and dungeon chips, 6px radius |
| `circle-fill.tga` / `circle-border.tga` | 32×32 | Step checkbox |
| `shadow.tga` | 64×64 | Panel drop shadow: a ring, clear inside the panel's edge, nine-sliced 7px outside it |
| `progress-fill.tga` | 64×8 | accent-deep → accent-glow gradient |
| `cap-top.tga` / `cap-bottom.tga` | 32×32 | Header and footer strips: rounded on the panel edge, square on the body edge |
| `grip.tga` | 16×16 | Resize grip, six dots |
| `nav-arrow.tga` | 64×64 | Navigation arrow, three-stop gradient, colour baked in |
| `scroll-thumb.tga` | 32×32 | Scrollbar knob, stadium |
| `switch-track.tga` | 64×32 | Options toggle track, stadium |
| `minimap-logo.tga` | 64×64 | The minimap button: the Aegis: Pathfinder logo in full colour, from `Tools/data/aegis-pathfinder-logo.webp` |
| `logo.tga` | 128×128 | The same logo, larger: the guide browser's right pane before you point at a guide |
| `wordmark.tga` | 256×32 | PATHFINDER wordmark, pre-rendered |
| `icons/*.tga` | 32×32 | One glyph per guide action code (17) |
| `icons/{menu,close,plus,tick,bang,pin,expand}.tga` | 32×32 | Chrome glyphs the 1.12 font cannot render |
| `icons/caret-{up,down}.tga` | 32×32 | Scrollbar step buttons |
| `icons/{arrow,chevron}-{left,right}.tga` | 32×32 | Nav row arrows and status bar chevrons |
| `icons/{star,search,gear,folder,heart,calendar,medal,dots}.tga` | 32×32 | The guide browser: favourites, search, Options, folders, the coming-soon categories, the list's ⋮ |
| `icons/{lock,dashed,wand}.tga` | 32×32 | The guide window's ≡ menu: Lock window, Transparency, Setup wizard |
| `loadscreens/*.tga` | 256×128 | Turtle WoW's dungeon loading screens, for the guide browser's pictures: from the originals in `Tools/data/loadscreens/` -- a 4:3 screen as the client shows it is cropped to its art between the bars and below the logo, a 16:9 painting kept whole -- squeezed from 16:9 to 2:1 and stretched back when shown. To add one, put it there under the dungeon's slug (`.webp`, `.jpg` or `.png`), re-run `make_assets.py`, and name it in `Theme.loadscreen` |
| `maps/*.tga` | 256×128 | Turtle WoW's explored world maps of its custom zones, which built from the client's tiles and pfUI's overlays came out wrong in game: the middle 16:9 of the originals in `Tools/data/maps/`, named in `Theme.zonemap` |

The nine-slice masks are 32×32 with a 10px corner, so the slice boundaries sit
at 10/32 and 22/32. `Theme.CORNER` and the `S0`/`S1` constants in `Theme.lua`
must stay in step with the radius used in `make_assets.py`.

## Fonts

`fonts/` holds the two faces the design concept specifies.

| File | Family | Author |
|---|---|---|
| `Rajdhani-Bold.ttf`, `Rajdhani-SemiBold.ttf` | Rajdhani | Indian Type Foundry (info@indiantypefoundry.com) |
| `Inter-Regular.ttf`, `Inter-SemiBold.ttf` | Inter | The Inter Project Authors (https://github.com/rsms/inter) |

Both are licensed under the SIL Open Font License 1.1. Author lines are taken
from each font's own name table. These are the Latin subsets served by Google
Fonts, verified to cover ASCII plus the punctuation the UI uses.

`Theme:SetFont` falls back to the client's own font if a bundled face fails to
load, so a missing or rejected TTF degrades to readable text rather than an
empty UI.
