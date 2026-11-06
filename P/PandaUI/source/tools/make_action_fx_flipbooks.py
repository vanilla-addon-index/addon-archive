"""Bake Retail 12.1 action-button spell FX into flipbooks this client can draw.

Retail (Blizzard_ActionBar/Shared/ActionButtonComponentTemplate.xml:136-311,
12.1.0.69933) animates these pieces with AnimationGroups under MaskTextures.
OctoWoW has neither, so every masked, moving layer is pre-rendered here, one
cell per animation step, with the mask multiplied into the alpha:

  fx-cast.tga   512x512, 8x8 cells of 64: rows 0-3 cast fill (32 steps of
                fill progress), rows 4-7 channel fill (32 steps).
  fx-burst.tga  512x512: rows 0-3 cast-complete ring burst (32 steps of the
                0.5 s animation), rows 4-7 interrupt highlight sweep (32 steps
                of its 0.5 s animation).
  fx-static.tga 256x256, 4x4 cells of 64: cell 0 cast inner glow, 1 channel
                inner glow, 2 interrupt base. Not masked; alpha is animated in
                Lua.

A cell is 64 Retail units square, centred on the button; the Retail action
button is 45 units, so Lua draws a cell at button * 64 / 45. Members are the
build's own atlas rectangles (RetailFrameXML `query.py atlasmap --exact`) on
the 2x sheet FileDataID 4624242 (`uiactionbarfxx2`); masks are 1x 64x64 sheets
(4626072 icon-frame mask, 5199409 cast-end mask, 5199418 interrupt mask).
Source PNGs are the Forever bundle's extracted copies of those FileDataIDs.
Rendering is at 2 px per unit, then halved with premultiplied alpha.

Output contract: 32-bit RLE TGA, type 10, descriptor 0x08
(knowledge.json / textures.uncompressed_512_tga_atlas_corrupts), square
power-of-two sheets like M.playerArrow.

Run from the pandaUI addon folder:

    python -B tools/make_action_fx_flipbooks.py
"""

import os
import sys

from PIL import Image, ImageChops

ART = os.path.join(
    "C:\\", "Games", "Wow-Octo", "#Addons-dev", "diagnostics",
    "foreverframeXML-index", "wowdata-art-ui", "interface", "unlisted")
DEST = os.path.join("media", "Textures", "modern-wow", "actionbar")

SHEET_2X = "4624242"
MEMBERS = {  # 2x pixel rectangles L, R, T, B
    "castFill": (189, 287, 1647, 1739),
    "castGlow": (189, 275, 1919, 2005),
    "burst": (1, 187, 1533, 1719),
    "chanFill": (189, 287, 1741, 1833),
    "chanGlow": (303, 389, 1533, 1619),
    "intBase": (303, 389, 1621, 1707),
    "intHighlight": (189, 283, 1835, 1917),
}
MASK_FILL = "4626072"
MASK_END = "5199409"
MASK_INTERRUPT = "5199418"

UNITS = 64          # cell size in Retail units
SCALE = 2           # render px per unit
RENDER = UNITS * SCALE
CELL = 64           # shipped px per cell
STEPS = 32


def write_rle_tga(image, path):
    image.save(path, format="TGA", compression="tga_rle")
    with open(path, "rb") as handle:
        header = handle.read(18)
    if (len(header) != 18 or header[2] != 10 or header[16] != 32
            or header[17] != 8):
        raise ValueError("RLE TGA writer did not produce type 10: " + path)


def load(fid):
    return Image.open(os.path.join(ART, fid + ".png")).convert("RGBA")


def member(sheet, name):
    left, right, top, bottom = MEMBERS[name]
    return sheet.crop((left, top, right, bottom))


def mask_alpha(fid, dx=0.0, dy=0.0):
    """The 1x mask at 2x render size, offset in units (y up)."""
    mask = load(fid).split()[3].resize((RENDER, RENDER), Image.BILINEAR)
    if dx or dy:
        canvas = Image.new("L", (RENDER, RENDER), 0)
        canvas.paste(mask, (int(round(dx * SCALE)), int(round(-dy * SCALE))))
        mask = canvas
    return mask


def place(image, width_units, height_units, cx_units, cy_units):
    """Draw image at a size and centre given in units (y up) on a cell."""
    canvas = Image.new("RGBA", (RENDER, RENDER), (0, 0, 0, 0))
    w = int(round(width_units * SCALE))
    h = int(round(height_units * SCALE))
    if w < 1 or h < 1:
        return canvas
    scaled = image.resize((w, h), Image.BICUBIC)
    x = int(round(RENDER / 2.0 + cx_units * SCALE - w / 2.0))
    y = int(round(RENDER / 2.0 - cy_units * SCALE - h / 2.0))
    layer = Image.new("RGBA", (RENDER, RENDER), (0, 0, 0, 0))
    layer.paste(scaled, (x, y))
    canvas.alpha_composite(layer)
    return canvas


def apply_mask(cell, mask):
    r, g, b, a = cell.split()
    return Image.merge("RGBA", (r, g, b, ImageChops.multiply(a, mask)))


def shrink(cell):
    return cell.convert("RGBa").resize((CELL, CELL), Image.LANCZOS).convert("RGBA")


def ease_out(t):
    return 1.0 - (1.0 - t) * (1.0 - t)


def put(sheet, cell, index, columns):
    sheet.paste(cell, ((index % columns) * CELL, (index // columns) * CELL))


def main():
    for fid in (SHEET_2X, MASK_FILL, MASK_END, MASK_INTERRUPT):
        if not os.path.isfile(os.path.join(ART, fid + ".png")):
            sys.stderr.write("missing source %s.png in %s\n" % (fid, ART))
            return 1
    if not os.path.isdir(DEST):
        sys.stderr.write("run from the pandaUI folder\n")
        return 1

    src = load(SHEET_2X)
    fill_mask = mask_alpha(MASK_FILL)
    end_mask = mask_alpha(MASK_END)
    # ActionButtonComponentTemplate.xml:269 anchors the mask at x=2, y=-1.
    int_mask = mask_alpha(MASK_INTERRUPT, 2, -1)

    cast = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    burst = Image.new("RGBA", (512, 512), (0, 0, 0, 0))

    cast_fill = member(src, "castFill")
    chan_fill = member(src, "chanFill")
    ring = member(src, "burst")
    highlight = member(src, "intHighlight")

    for i in range(STEPS):
        t = i / float(STEPS - 1)
        # xml:154-171 cast fill centre x -45 -> -2; ActionButton.lua:1758
        # channel fill centre x 45 -> 2. Member size is half the 2x pixels.
        cell = place(cast_fill, 49, 46, -45 + 43 * t, 0)
        put(cast, shrink(apply_mask(cell, fill_mask)), i, 8)
        cell = place(chan_fill, 49, 46, 45 - 43 * t, 0)
        put(cast, shrink(apply_mask(cell, fill_mask)), 32 + i, 8)

        # xml:187-204 ring: 93 units at scale 0.25, Scale 0 -> 5, smoothing OUT.
        size = 93 * 0.25 * 5 * ease_out(t)
        cell = place(ring, size, size, 0, 0)
        put(burst, shrink(apply_mask(cell, end_mask)), i, 8)

        # xml:262-279 highlight at y=50, Translation y -150 over 0.5 s.
        cell = place(highlight, 47, 41, 0, 50 - 150 * t)
        put(burst, shrink(apply_mask(cell, int_mask)), 32 + i, 8)

    static = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    for index, name in enumerate(("castGlow", "chanGlow", "intBase")):
        put(static, shrink(place(member(src, name), 43, 43, 0, 0)), index, 4)

    write_rle_tga(cast, os.path.join(DEST, "fx-cast.tga"))
    write_rle_tga(burst, os.path.join(DEST, "fx-burst.tga"))
    write_rle_tga(static, os.path.join(DEST, "fx-static.tga"))
    print("wrote fx-cast, fx-burst, fx-static to " + DEST)
    return 0


if __name__ == "__main__":
    sys.exit(main())
