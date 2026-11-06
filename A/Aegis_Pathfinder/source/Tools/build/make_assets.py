#!/usr/bin/env python3
"""Generate AEGIS: Pathfinder's texture assets.

Every file under media/ that this script names is generated -- do not hand-edit
them, edit this and re-run:

    pip install Pillow
    python3 Tools/build/make_assets.py

Output is in a format known to load on the 1.12 client: 32-bit RLE truecolor
TGA, bottom-left origin, 8 alpha bits, no colour map and no ID field. PIL's own
TGA writer does not pin all of that down, so the encoder here is explicit.

Shapes are written as white masks wherever the colour is applied at runtime
with SetVertexColor -- Theme.lua owns the palette, so a colour change is a Lua
edit and never a re-render. Only genuinely multi-colour art (the navigation
arrow, the progress gradient) bakes colour in.

Geometry is drawn at 4x and downsampled, which is how the rounded corners and
circles get their antialiasing; the 1.12 client does no filtering of its own.
"""

import os
import struct

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MEDIA = os.path.join(ROOT, "media")
FONTS = os.path.join(MEDIA, "fonts")

SS = 4  # supersampling factor

# Concept palette. Only the entries baked into art are used here; the full set
# lives in Theme.lua.
ACCENT_DEEP = (46, 133, 14)
ACCENT_GLOW = (143, 224, 102)
# The navigation arrow's three gradient stops, straight from the concept's
# <linearGradient id="arrowGrad">.
ARROW_TOP = (168, 255, 143)
ARROW_MID = (111, 217, 79)
ARROW_BOT = (74, 156, 48)

WHITE = (255, 255, 255)


# --------------------------------------------------------------------------
# TGA encoding
# --------------------------------------------------------------------------

def _rle_scanline(pixels):
    """Encode one scanline as TGA RLE packets (max 128 pixels per packet)."""
    out = bytearray()
    i, n = 0, len(pixels)
    while i < n:
        run = 1
        while run < 128 and i + run < n and pixels[i + run] == pixels[i]:
            run += 1
        if run > 1:
            out.append(0x80 | (run - 1))
            b, g, r, a = pixels[i][2], pixels[i][1], pixels[i][0], pixels[i][3]
            out += bytes((b, g, r, a))
            i += run
            continue
        # Raw packet: pixels up to the next run of 2+ identical pixels.
        start = i
        while (i < n and i - start < 128 and
               not (i + 1 < n and pixels[i] == pixels[i + 1])):
            i += 1
        chunk = pixels[start:i]
        out.append(len(chunk) - 1)
        for r, g, b, a in chunk:
            out += bytes((b, g, r, a))
    return out


def write_tga(img, path):
    """Write RGBA image as 32-bit RLE TGA, bottom-left origin."""
    img = img.convert("RGBA")
    w, h = img.size
    for label, value in (("width", w), ("height", h)):
        if value == 0 or value & (value - 1):
            raise ValueError("%s: %s %d is not a power of two" % (path, label, value))
    header = struct.pack(
        "<BBBHHBHHHHBB",
        0,      # ID length
        0,      # no colour map
        10,     # RLE truecolor
        0, 0, 0,  # colour map spec
        0, 0,   # x/y origin
        w, h,
        32,     # bits per pixel
        0x08,   # 8 alpha bits, bottom-left origin
    )
    px = img.load()
    body = bytearray()
    for y in range(h - 1, -1, -1):  # bottom-left origin: last row first
        body += _rle_scanline([px[x, y] for x in range(w)])
    with open(path, "wb") as fh:
        fh.write(header)
        fh.write(body)
    return os.path.getsize(path)


def canvas(size):
    return Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))


def finish(img, size, path):
    img = img.resize((size, size), Image.LANCZOS)
    return write_tga(img, os.path.join(MEDIA, path))


# --------------------------------------------------------------------------
# Panel / widget shapes (white masks, tinted in Lua)
# --------------------------------------------------------------------------

def solid():
    img = Image.new("RGBA", (8, 8), (255, 255, 255, 255))
    return write_tga(img, os.path.join(MEDIA, "solid.tga"))


def rounded(size, radius, width=None, path=None):
    """Rounded rectangle, filled or outlined, as a white mask."""
    img = canvas(size)
    d = ImageDraw.Draw(img)
    box = [0, 0, size * SS - 1, size * SS - 1]
    if width:
        inset = width * SS / 2.0
        d.rounded_rectangle([box[0] + inset, box[1] + inset, box[2] - inset, box[3] - inset],
                            radius=radius * SS, outline=WHITE + (255,), width=width * SS)
    else:
        d.rounded_rectangle(box, radius=radius * SS, fill=WHITE + (255,))
    return finish(img, size, path)


def capped(size, radius, edge, path):
    """Rectangle rounded on one edge only, square on the other.

    The concept clips its header and footer strips to the window's corner with
    overflow:hidden. The 1.12 client cannot clip, so a strip that meets the
    top or bottom of a panel needs its own mask: rounded where it touches the
    panel edge, square where it meets the body.
    """
    img = canvas(size)
    d = ImageDraw.Draw(img)
    s = size * SS
    r = radius * SS
    d.rounded_rectangle([0, 0, s - 1, s - 1], radius=r, fill=WHITE + (255,))
    # Square off the far edge by painting the outer half of it flat.
    if edge == "top":
        d.rectangle([0, s - r - 1, s - 1, s - 1], fill=WHITE + (255,))
    else:
        d.rectangle([0, 0, s - 1, r], fill=WHITE + (255,))
    return finish(img, size, path)


def circle(size, width=None, path=None, pad=1):
    img = canvas(size)
    d = ImageDraw.Draw(img)
    p = pad * SS
    box = [p, p, size * SS - 1 - p, size * SS - 1 - p]
    if width:
        d.ellipse(box, outline=WHITE + (255,), width=width * SS)
    else:
        d.ellipse(box, fill=WHITE + (255,))
    return finish(img, size, path)


def shadow(size=64, outset=7, radius=10):
    """Soft drop shadow behind floating panels, as a ring.

    The panel's rounded edge sits `outset` px in from every side of the
    texture; the shadow is darkest there and falls to nothing at the
    texture's edge. Inside the panel it is transparent: Theme:Panel draws it
    in the same layer as the fill, and 1.12 does not promise which of the two
    draws first, so anything here could land on top of the panel.

    Nine-sliced by Theme.SHADOW_GEOM (18px corners, 7px outset), which is
    what keeps the falloff 7px wide however large the panel is. The corners
    must hold the whole of the panel's corner arc: outset + radius <= 18.
    """
    assert outset + radius <= 18
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    lo, hi = outset, size - outset          # the panel's edges, in texture px
    for y in range(size):
        for x in range(size):
            cx, cy = x + 0.5, y + 0.5
            # Distance outside the panel's rounded rect (negative inside).
            qx = max(lo + radius - cx, 0, cx - (hi - radius))
            qy = max(lo + radius - cy, 0, cy - (hi - radius))
            d = (qx * qx + qy * qy) ** 0.5 - radius
            if d < -1.0:
                a = 0.0                      # under the panel
            elif d <= 0.0:
                a = 1.0                      # the panel's antialiased rim
            else:
                a = max(0.0, 1.0 - d / outset) ** 1.6
            px[x, y] = (0, 0, 0, int(210 * a))
    return write_tga(img, os.path.join(MEDIA, "shadow.tga"))


# --------------------------------------------------------------------------
# Baked-colour art
# --------------------------------------------------------------------------

def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def progress_fill(w=64, h=8):
    """accent-deep -> accent-glow, matching the concept's progress gradient."""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for x in range(w):
        col = lerp(ACCENT_DEEP, ACCENT_GLOW, x / float(w - 1))
        for y in range(h):
            px[x, y] = col + (255,)
    return write_tga(img, os.path.join(MEDIA, "progress-fill.tga"))


def _shade(col):
    return sum(col) / float(sum(ARROW_TOP))


def progress_mask(w=64, h=8):
    """progress_fill's ramp in grey, for themes other than the concept's:
    tinted with the theme's accent glow, it runs from dark to bright the way
    the green one does (Theme:Skin)."""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    lo = sum(ACCENT_DEEP) / float(sum(ACCENT_GLOW))
    for x in range(w):
        v = int(round(255 * (lo + (1 - lo) * x / float(w - 1))))
        for y in range(h):
            px[x, y] = (v, v, v, 255)
    return write_tga(img, os.path.join(MEDIA, "progress-mask.tga"))


# --------------------------------------------------------------------------
# Action icons
# --------------------------------------------------------------------------
# One 32x32 white glyph per action code in the guide DSL. They are silhouettes
# rather than line art because they render at roughly 14px in the status bar,
# where strokes thinner than ~2px disappear. Tinted in Lua.

def _icon(draw_fn, name, size=32):
    img = canvas(size)
    d = ImageDraw.Draw(img)
    draw_fn(d, size * SS)
    return finish(img, size, os.path.join("icons", name + ".tga"))


W = WHITE + (255,)


def _scroll(d, s):           # A / T -- quest scroll
    d.rounded_rectangle([s * .22, s * .14, s * .78, s * .86], radius=s * .06, fill=W)
    d.rectangle([s * .30, s * .30, s * .70, s * .36], fill=(0, 0, 0, 0))
    d.rectangle([s * .30, s * .46, s * .70, s * .52], fill=(0, 0, 0, 0))
    d.rectangle([s * .30, s * .62, s * .58, s * .68], fill=(0, 0, 0, 0))


def _swords(d, s):           # C -- complete objectives
    d.line([s * .18, s * .82, s * .82, s * .18], fill=W, width=int(s * .13))
    d.line([s * .18, s * .18, s * .82, s * .82], fill=W, width=int(s * .13))


def _note(d, s):             # N -- note
    d.rounded_rectangle([s * .20, s * .16, s * .80, s * .84], radius=s * .08, fill=W)
    for i, frac in enumerate((.34, .50, .66)):
        right = .68 if i < 2 else .56
        d.rectangle([s * .30, s * frac, s * right, s * (frac + .07)], fill=(0, 0, 0, 0))


def _run(d, s):              # R -- travel on foot
    for off in (-.18, .10):
        d.polygon([(s * (.42 + off), s * .18), (s * (.78 + off), s * .50),
                   (s * (.42 + off), s * .82), (s * (.42 + off), s * .62),
                   (s * (.58 + off), s * .50), (s * (.42 + off), s * .38)], fill=W)


def _house(d, s, dot=False):  # H / h -- hearth
    d.polygon([(s * .50, s * .14), (s * .88, s * .48), (s * .12, s * .48)], fill=W)
    d.rectangle([s * .24, s * .48, s * .76, s * .84], fill=W)
    if dot:
        d.ellipse([s * .42, s * .58, s * .58, s * .74], fill=(0, 0, 0, 0))


def _wing(d, s, outline=False):  # F / f -- flight
    # Gull silhouette: two swept wings meeting at a low centre. Reads as
    # "bird" at icon size where a feather or a detailed wing turns to mush.
    left = [(s * .06, s * .34), (s * .30, s * .30), (s * .50, s * .62),
            (s * .50, s * .74), (s * .26, s * .48)]
    right = [(s * .94, s * .34), (s * .70, s * .30), (s * .50, s * .62),
             (s * .50, s * .74), (s * .74, s * .48)]
    if outline:                  # f -- flight point not yet discovered
        d.polygon(left, outline=W, width=max(1, int(s * .05)))
        d.polygon(right, outline=W, width=max(1, int(s * .05)))
    else:                        # F -- take a known flight path
        d.polygon(left, fill=W)
        d.polygon(right, fill=W)


def _coin(d, s):             # B -- buy. Stacked coins read better at 14px
    for i, top in enumerate((.56, .38, .20)):   # back to front
        d.ellipse([s * .16, s * top, s * .84, s * (top + .24)], fill=W)
        if i < 2:                                # separate the stacked discs
            d.ellipse([s * .16, s * (top + .17), s * .84, s * (top + .28)], fill=(0, 0, 0, 0))


def _boat(d, s):             # b -- boat
    d.polygon([(s * .12, s * .58), (s * .88, s * .58), (s * .72, s * .84), (s * .28, s * .84)], fill=W)
    d.polygon([(s * .46, s * .12), (s * .74, s * .52), (s * .46, s * .52)], fill=W)
    d.rectangle([s * .42, s * .12, s * .50, s * .52], fill=W)


def _skull(d, s, bones=False):
    """K / G -- kill and grind share a glyph, as they do in the concept.

    D (die) adds crossbones so a death step is never mistaken for a kill step.
    """
    if bones:
        for a, b in (((.10, .52), (.90, .94)), ((.90, .52), (.10, .94))):
            d.line([s * a[0], s * a[1], s * b[0], s * b[1]], fill=W, width=int(s * .10))
            for end in (a, b):
                d.ellipse([s * (end[0] - .07), s * (end[1] - .07),
                           s * (end[0] + .07), s * (end[1] + .07)], fill=W)
    d.ellipse([s * .20, s * .10, s * .80, s * .64], fill=W)
    d.rectangle([s * .36, s * .54, s * .64, s * .78], fill=W)
    eye = (0, 0, 0, 0)
    d.ellipse([s * .31, s * .30, s * .45, s * .46], fill=eye)
    d.ellipse([s * .55, s * .30, s * .69, s * .46], fill=eye)
    d.rectangle([s * .46, s * .56, s * .54, s * .74], fill=eye)


def _box(d, s):              # U -- use item
    d.polygon([(s * .50, s * .12), (s * .88, s * .32), (s * .50, s * .52), (s * .12, s * .32)], fill=W)
    d.polygon([(s * .12, s * .34), (s * .50, s * .54), (s * .50, s * .88), (s * .12, s * .68)], fill=W)
    d.polygon([(s * .88, s * .34), (s * .88, s * .68), (s * .50, s * .88), (s * .50, s * .54)], fill=W)


def _book(d, s):             # t -- trainer. Open book, splayed pages
    d.polygon([(s * .08, s * .26), (s * .46, s * .36), (s * .46, s * .84),
               (s * .08, s * .74)], fill=W)
    d.polygon([(s * .92, s * .26), (s * .54, s * .36), (s * .54, s * .84),
               (s * .92, s * .74)], fill=W)
    d.rectangle([s * .46, s * .34, s * .54, s * .86], fill=W)   # spine


def _paw(d, s):              # P -- pet
    d.ellipse([s * .30, s * .44, s * .70, s * .82], fill=W)
    for cx in (.22, .40, .60, .78):
        d.ellipse([s * (cx - .09), s * .18, s * (cx + .09), s * .40], fill=W)


ICONS = {
    "accept": _scroll,
    "turnin": _scroll,
    "complete": _swords,
    "note": _note,
    "run": _run,
    "hearth": lambda d, s: _house(d, s, dot=False),
    "sethearth": lambda d, s: _house(d, s, dot=True),
    "fly": lambda d, s: _wing(d, s, outline=False),
    "getflightpoint": lambda d, s: _wing(d, s, outline=True),
    "buy": _coin,
    "boat": _boat,
    "kill": lambda d, s: _skull(d, s, bones=False),
    "grind": lambda d, s: _skull(d, s, bones=False),
    "use": _box,
    "train": _book,
    "die": lambda d, s: _skull(d, s, bones=True),
    "pet": _paw,
}


# --------------------------------------------------------------------------
# UI chrome glyphs
# --------------------------------------------------------------------------
# The concept draws its chrome with characters the 1.12 font cannot render:
# the header's hamburger and close chips, the nav row's arrows, the status
# bar's chevrons, the band ticks, and the resize grip's dot cluster. Each
# becomes a white mask, tinted in Lua like every other shape.

def _menu(d, s):             # header -- hamburger, the concept's opener
    for y in (.28, .48, .68):
        d.rounded_rectangle([s * .16, s * y, s * .84, s * (y + .08)],
                            radius=s * .04, fill=W)


def _close(d, s):            # header / branch tab -- close
    w = int(s * .10)
    d.line([s * .24, s * .24, s * .76, s * .76], fill=W, width=w)
    d.line([s * .76, s * .24, s * .24, s * .76], fill=W, width=w)


def _plus(d, s):             # tab bar -- branch to another guide
    d.rounded_rectangle([s * .44, s * .18, s * .56, s * .82], radius=s * .06, fill=W)
    d.rounded_rectangle([s * .18, s * .44, s * .82, s * .56], radius=s * .06, fill=W)


def _triangle(d, s, facing):
    """Solid triangle. facing is 'left' or 'right'."""
    if facing == "left":
        d.polygon([(s * .30, s * .50), (s * .68, s * .18), (s * .68, s * .82)], fill=W)
    else:
        d.polygon([(s * .70, s * .50), (s * .32, s * .18), (s * .32, s * .82)], fill=W)


def _chevron(d, s, facing):
    """Open chevron -- the status bar's small step arrows."""
    w = int(s * .11)
    if facing == "left":
        d.line([s * .62, s * .20, s * .34, s * .50], fill=W, width=w)
        d.line([s * .34, s * .50, s * .62, s * .80], fill=W, width=w)
    else:
        d.line([s * .38, s * .20, s * .66, s * .50], fill=W, width=w)
        d.line([s * .66, s * .50, s * .38, s * .80], fill=W, width=w)


def _tick(d, s):             # green band -- step satisfied
    w = int(s * .13)
    d.line([s * .20, s * .52, s * .42, s * .74], fill=W, width=w)
    d.line([s * .42, s * .74, s * .80, s * .26], fill=W, width=w)


def _bang(d, s):             # red band -- step outstanding
    d.rounded_rectangle([s * .42, s * .14, s * .58, s * .60], radius=s * .07, fill=W)
    d.ellipse([s * .40, s * .70, s * .60, s * .90], fill=W)


def _expand(d, s):           # header -- switch between one step and all of them
    """Diagonal double-headed arrow, per the concept's #obj-expand-btn SVG.

    The concept strokes it at 2.2 of 24 units; at the 10px this renders to,
    that is thinner than a pixel, so it is drawn heavier and the arrowheads
    are filled rather than stroked.
    """
    w = int(s * .085)
    d.line([s * .28, s * .72, s * .72, s * .28], fill=W, width=w)
    # Upper-right head
    d.polygon([(s * .76, s * .24), (s * .76, s * .52), (s * .48, s * .24)], fill=W)
    # Lower-left head
    d.polygon([(s * .24, s * .76), (s * .52, s * .76), (s * .24, s * .48)], fill=W)


def _caret(d, s, facing):
    """Small solid triangle for a scrollbar's step buttons."""
    if facing == "up":
        d.polygon([(s * .50, s * .30), (s * .76, s * .66), (s * .24, s * .66)], fill=W)
    else:
        d.polygon([(s * .50, s * .70), (s * .24, s * .34), (s * .76, s * .34)], fill=W)


def _pin(d, s):              # map pin -- prefixes a coordinate pair
    d.ellipse([s * .22, s * .10, s * .78, s * .66], fill=W)
    d.polygon([(s * .34, s * .56), (s * .66, s * .56), (s * .50, s * .92)], fill=W)
    d.ellipse([s * .40, s * .28, s * .60, s * .48], fill=(0, 0, 0, 0))


def _party(d, s):            # nav row -- share the guide with your party
    """Two people, the nearer one in front: a head and shoulders each. The
    one behind is cut away where the nearer overlaps it, so the pair still
    reads as two at 12px."""
    # Behind, up and to the right.
    d.ellipse([s * .52, s * .14, s * .80, s * .42], fill=W)
    d.pieslice([s * .40, s * .46, s * .92, s * .98], 180, 360, fill=W)
    # A gap around the nearer figure, then the nearer figure itself.
    clear = (0, 0, 0, 0)
    d.ellipse([s * .12, s * .22, s * .52, s * .62], fill=clear)
    d.pieslice([s * .00, s * .56, s * .66, s * 1.22], 180, 360, fill=clear)
    d.ellipse([s * .18, s * .28, s * .46, s * .56], fill=W)
    d.pieslice([s * .06, s * .62, s * .60, s * 1.16], 180, 360, fill=W)


def _auto(d, s):             # step check -- the addon ticks this one itself
    """A clockwise open-circle arrow, the ⟳ the 1.12 font cannot draw. It sits
    inside the step's ring at about 9px, so the stroke is heavy and the head
    is a filled triangle, not a stroked one."""
    import math
    cx = cy = s * .5
    r = s * .30
    w = int(s * .15)
    start, end = -20, 225          # degrees, clockwise from three o'clock
    d.arc([cx - r, cy - r, cx + r, cy + r], start, end, fill=W, width=w)
    # The head at the arc's end, pointing the way it turns.
    t = math.radians(end)
    px, py = cx + (r - w / 2) * math.cos(t), cy + (r - w / 2) * math.sin(t)
    tx, ty = -math.sin(t), math.cos(t)          # clockwise tangent
    nx, ny = math.cos(t), math.sin(t)           # outward normal
    head, half = s * .24, s * .21
    d.polygon([(px + tx * head, py + ty * head),
               (px + nx * half, py + ny * half),
               (px - nx * half, py - ny * half)], fill=W)


def _star(d, s):             # guide browser -- a favourite, or a suggestion
    import math
    pts = []
    for i in range(10):
        r = s * (.42 if i % 2 == 0 else .18)
        t = math.radians(-90 + i * 36)
        pts.append((s * .5 + r * math.cos(t), s * .53 + r * math.sin(t)))
    d.polygon(pts, fill=W)


def _search(d, s):           # guide browser -- the search box's magnifier
    w = int(s * .11)
    d.ellipse([s * .14, s * .14, s * .64, s * .64], outline=W, width=w)
    d.line([s * .58, s * .58, s * .86, s * .86], fill=W, width=int(s * .14))


def _gear(d, s):             # guide browser -- Options; the menu's Settings
    import math
    for i in range(8):
        t = math.radians(i * 45)
        cx, cy = s * .5 + s * .32 * math.cos(t), s * .5 + s * .32 * math.sin(t)
        d.ellipse([cx - s * .09, cy - s * .09, cx + s * .09, cy + s * .09], fill=W)
    d.ellipse([s * .20, s * .20, s * .80, s * .80], fill=W)
    d.ellipse([s * .38, s * .38, s * .62, s * .62], fill=(0, 0, 0, 0))


def _folder(d, s):           # guide browser -- a folder of guides
    d.rounded_rectangle([s * .10, s * .20, s * .46, s * .36], radius=s * .05, fill=W)
    d.rounded_rectangle([s * .10, s * .28, s * .90, s * .80], radius=s * .07, fill=W)


def _heart(d, s):            # guide browser -- Reputations
    d.ellipse([s * .12, s * .18, s * .52, s * .58], fill=W)
    d.ellipse([s * .48, s * .18, s * .88, s * .58], fill=W)
    d.polygon([(s * .14, s * .46), (s * .86, s * .46), (s * .50, s * .86)], fill=W)


def _calendar(d, s):         # guide browser -- Events
    d.rounded_rectangle([s * .14, s * .20, s * .86, s * .84], radius=s * .08, fill=W)
    clear = (0, 0, 0, 0)
    d.rectangle([s * .22, s * .40, s * .78, s * .76], fill=clear)
    for x in (.32, .52):
        d.rectangle([s * x, s * .48, s * (x + .12), s * .58], fill=W)
    d.rectangle([s * .32, s * .62, s * .44, s * .70], fill=W)
    for x in (.30, .62):
        d.rounded_rectangle([s * x, s * .10, s * (x + .08), s * .28], radius=s * .03, fill=W)


def _medal(d, s):            # guide browser -- Titles
    d.polygon([(s * .26, s * .10), (s * .42, s * .10), (s * .56, s * .46), (s * .44, s * .50)], fill=W)
    d.polygon([(s * .74, s * .10), (s * .58, s * .10), (s * .44, s * .46), (s * .56, s * .50)], fill=W)
    d.ellipse([s * .26, s * .42, s * .74, s * .90], fill=W)
    d.ellipse([s * .38, s * .54, s * .62, s * .78], fill=(0, 0, 0, 0))


def _dots(d, s):             # guide browser -- the list's options, a vertical ellipsis
    for y in (.22, .50, .78):
        d.ellipse([s * .40, s * (y - .10), s * .60, s * (y + .10)], fill=W)


def _lock(d, s):             # guide window menu -- Lock window
    d.arc([s * .28, s * .12, s * .72, s * .60], 180, 360, fill=W, width=int(s * .10))
    d.rectangle([s * .28, s * .34, s * .37, s * .48], fill=W)
    d.rectangle([s * .63, s * .34, s * .72, s * .48], fill=W)
    d.rounded_rectangle([s * .18, s * .44, s * .82, s * .88], radius=s * .07, fill=W)


def _dashed(d, s):           # guide window menu -- Transparency, a see-through square
    w = int(s * .09)
    for a, b in ((.16, .36), (.44, .56), (.64, .84)):
        d.line([s * a, s * .16, s * b, s * .16], fill=W, width=w)
        d.line([s * a, s * .84, s * b, s * .84], fill=W, width=w)
        d.line([s * .16, s * a, s * .16, s * b], fill=W, width=w)
        d.line([s * .84, s * a, s * .84, s * b], fill=W, width=w)


def _wand(d, s):             # guide window menu -- the Setup wizard
    d.line([s * .16, s * .84, s * .60, s * .40], fill=W, width=int(s * .11))
    import math
    cx, cy = s * .70, s * .30
    pts = []
    for i in range(8):
        r = s * (.20 if i % 2 == 0 else .07)
        t = math.radians(-90 + i * 45)
        pts.append((cx + r * math.cos(t), cy + r * math.sin(t)))
    d.polygon(pts, fill=W)


CHROME = {
    "auto": _auto,
    "menu": _menu,
    "close": _close,
    "plus": _plus,
    "arrow-left": lambda d, s: _triangle(d, s, "left"),
    "arrow-right": lambda d, s: _triangle(d, s, "right"),
    "chevron-left": lambda d, s: _chevron(d, s, "left"),
    "chevron-right": lambda d, s: _chevron(d, s, "right"),
    "tick": _tick,
    "bang": _bang,
    "pin": _pin,
    "expand": _expand,
    "party": _party,
    "caret-up": lambda d, s: _caret(d, s, "up"),
    "caret-down": lambda d, s: _caret(d, s, "down"),
    "star": _star,
    "search": _search,
    "gear": _gear,
    "folder": _folder,
    "heart": _heart,
    "calendar": _calendar,
    "medal": _medal,
    "dots": _dots,
    "lock": _lock,
    "dashed": _dashed,
    "wand": _wand,
}


def scroll_thumb(size=32):
    """The scrollbar's knob: a stadium, rounded at both ends.

    A scrollbar is 8px wide and its knob is drawn at whatever height the
    content asks for, so this is nine-sliced rather than stretched -- hence a
    full-width radius, which keeps the caps circular at any length.
    """
    return rounded(size, size // 2, path="scroll-thumb.tga")


def switch_track(w=64, h=32):
    """The concept's .switch: a 36x20 stadium with an 11px radius.

    Drawn at 2:1 with a radius of half its height, so the ends stay round
    when it is shown at 36x20. A single stretched texture rather than a
    nine-slice, because a toggle never changes size.
    """
    img = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, w * SS - 1, h * SS - 1], radius=h * SS // 2, fill=W)
    img = img.resize((w, h), Image.LANCZOS)
    return write_tga(img, os.path.join(MEDIA, "switch-track.tga"))


def nav_arrow(size=64):
    """The signature navigation arrow.

    Same silhouette as the concept's SVG path (M50,10 L90,66 L50,52 L10,66 Z)
    mapped into the texture, with its three-stop vertical gradient. Colour is
    baked in rather than tinted, because it is a gradient and 1.12 has none.

    It points straight up. Bearing comes from rotating it at runtime, which on
    this client means mapping it onto a rotated quad with the eight-argument
    form of SetTexCoord -- so the art must stay centred in its square or it
    will wobble as it turns.
    """
    img = canvas(size)
    d = ImageDraw.Draw(img)
    s = size * SS

    def pt(x, y):
        return (x / 100.0 * s, y / 80.0 * s)

    d.polygon([pt(50, 8), pt(92, 68), pt(50, 53), pt(8, 68)], fill=WHITE + (255,))

    img = img.resize((size, size), Image.LANCZOS)
    px = img.load()
    for y in range(size):
        t = y / float(size - 1)
        col = lerp(ARROW_TOP, ARROW_MID, t / 0.55) if t < 0.55 else \
            lerp(ARROW_MID, ARROW_BOT, (t - 0.55) / 0.45)
        for x in range(size):
            a = px[x, y][3]
            if a:
                px[x, y] = col + (a,)
    return write_tga(img, os.path.join(MEDIA, "nav-arrow.tga"))


def nav_arrow_mask(size=64):
    """nav_arrow in grey, its gradient kept as shade, for themes other than
    the concept's: tinted with the theme's accent glow it keeps the arrow's
    lit-from-above look in the theme's colour (Theme:Skin)."""
    img = canvas(size)
    d = ImageDraw.Draw(img)
    s = size * SS

    def pt(x, y):
        return (x / 100.0 * s, y / 80.0 * s)

    d.polygon([pt(50, 8), pt(92, 68), pt(50, 53), pt(8, 68)], fill=WHITE + (255,))
    img = img.resize((size, size), Image.LANCZOS)
    px = img.load()
    top, mid, bot = 1.0, _shade(ARROW_MID), _shade(ARROW_BOT)
    for y in range(size):
        t = y / float(size - 1)
        v = top + (mid - top) * t / 0.55 if t < 0.55 else mid + (bot - mid) * (t - 0.55) / 0.45
        g = int(round(255 * v))
        for x in range(size):
            a = px[x, y][3]
            if a:
                px[x, y] = (g, g, g, a)
    return write_tga(img, os.path.join(MEDIA, "nav-arrow-mask.tga"))


def grip(size=16):
    """The concept's resize grip: six dots stepped into the bottom-right.

    One texture rather than six placed regions, so the cluster keeps its
    spacing at any frame size and tints in a single call.
    """
    img = canvas(size)
    d = ImageDraw.Draw(img)
    s = size * SS
    r = s * .055
    for col in range(3):
        for row in range(3 - col):
            cx = s * (.86 - col * .26)
            cy = s * (.86 - row * .26)
            d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=W)
    return finish(img, size, "grip.tga")


# --------------------------------------------------------------------------
# Branding
# --------------------------------------------------------------------------

# The Aegis: Pathfinder logo, drawn by the owner. The source art lives in
# Tools/data (it does not ship); only the textures made from it do.
LOGO_SOURCE = os.path.join(ROOT, "Tools", "data", "aegis-pathfinder-logo.webp")


def minimap_logo(size=64):
    """Minimap button: the full-colour logo, a disc with its own ring.

    Colour is baked in -- it is the owner's art, not a mask the theme tints.
    Halved step by step rather than in one go, so the fine detail (the runes,
    the wing feathers) averages out instead of aliasing at 64px.
    """
    img = Image.open(LOGO_SOURCE).convert("RGBA")
    side = min(img.size)
    img = img.crop(((img.size[0] - side) // 2, (img.size[1] - side) // 2,
                    (img.size[0] + side) // 2, (img.size[1] + side) // 2))
    while img.size[0] >= size * 4:
        img = img.resize((img.size[0] // 2, img.size[1] // 2), Image.LANCZOS)
    img = img.resize((size, size), Image.LANCZOS)
    return write_tga(img, os.path.join(MEDIA, "minimap-logo.tga"))


def logo(size=128):
    """The guide browser's empty right pane: the logo, as on the minimap but
    larger. Full colour, made the same way."""
    img = Image.open(LOGO_SOURCE).convert("RGBA")
    side = min(img.size)
    img = img.crop(((img.size[0] - side) // 2, (img.size[1] - side) // 2,
                    (img.size[0] + side) // 2, (img.size[1] + side) // 2))
    while img.size[0] >= size * 4:
        img = img.resize((img.size[0] // 2, img.size[1] // 2), Image.LANCZOS)
    img = img.resize((size, size), Image.LANCZOS)
    return write_tga(img, os.path.join(MEDIA, "logo.tga"))


# Turtle WoW's dungeon loading screens and the maps of its zones the client
# cannot draw for the browser, for the guide browser's pictures. The sources
# are under Tools/data (they do not ship): loading screens as the client
# shows them, 4:3 with the logo bars, or a 16:9 painting; maps as the world
# map draws them, 1002x668 or near it.
LOADSCREENS = os.path.join(ROOT, "Tools", "data", "loadscreens")
ZONEMAPS = os.path.join(ROOT, "Tools", "data", "maps")
PICTURE_W, PICTURE_H = 256, 128      # 16:9 squeezed into 2:1; stretched back when shown
# A 4:3 loading screen's art, at 800x600: between the bars, and below the
# logo's ribbon, which reaches down to row 155.
SCREEN_ART = (114, 160, 686, 482)


def _sources(folder):
    return sorted(f for f in os.listdir(folder) if os.path.splitext(f)[1] in (".webp", ".jpg", ".png"))


def _picture(img, path):
    """A 16:9 picture as a 256x128 texture."""
    img = img.convert("RGBA")
    while img.size[0] >= PICTURE_W * 4:
        img = img.resize((img.size[0] // 2, img.size[1] // 2), Image.LANCZOS)
    return write_tga(img.resize((PICTURE_W, PICTURE_H), Image.LANCZOS), path)


def loadscreen(name):
    """A dungeon's loading screen: the art between its bars, below the logo,
    or a 16:9 painting whole."""
    src = next(f for f in _sources(LOADSCREENS) if os.path.splitext(f)[0] == name)
    img = Image.open(os.path.join(LOADSCREENS, src))
    w, h = img.size
    if abs(w / h - 4 / 3) < 0.05:
        k = w / 800.0
        img = img.crop(tuple(int(round(v * k)) for v in SCREEN_ART))
    elif abs(w / h - 16 / 9) > 0.05:
        raise ValueError("%s is %dx%d: neither a 4:3 loading screen nor 16:9" % (src, w, h))
    return _picture(img, os.path.join(MEDIA, "loadscreens", name + ".tga"))


def zonemap(name):
    """A zone's world map, explored: its middle at 16:9, the whole width."""
    src = next(f for f in _sources(ZONEMAPS) if os.path.splitext(f)[0] == name)
    img = Image.open(os.path.join(ZONEMAPS, src))
    w, h = img.size
    ch = int(round(w * 9 / 16))
    top = (h - ch) // 2
    return _picture(img.crop((0, top, w, top + ch)), os.path.join(MEDIA, "maps", name + ".tga"))


def wordmark(w=256, h=32):
    """PATHFINDER wordmark, pre-rendered in the display face.

    Pre-rendering keeps the concept's letterforms and tracking exact, and keeps
    the header readable even if the bundled TTF fails to load on a client.
    """
    img = Image.new("RGBA", (w * 2, h * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    path = os.path.join(FONTS, "Rajdhani-Bold.ttf")
    if not os.path.exists(path):
        print("  ! %s missing; skipping wordmark" % path)
        return 0
    text = "PATHFINDER"
    tracking = int(h * 2 * 0.18)   # the concept sets letter-spacing .18em
    font = ImageFont.truetype(path, int(h * 2 * 0.86))
    widths = [d.textlength(c, font=font) for c in text]
    total = sum(widths) + tracking * (len(text) - 1)
    x = (w * 2 - total) / 2.0
    for c, cw in zip(text, widths):
        d.text((x, h), c, font=font, fill=W, anchor="lm")
        x += cw + tracking
    img = img.resize((w, h), Image.LANCZOS)
    return write_tga(img, os.path.join(MEDIA, "wordmark.tga"))


# --------------------------------------------------------------------------

def main():
    os.makedirs(os.path.join(MEDIA, "icons"), exist_ok=True)
    os.makedirs(os.path.join(MEDIA, "loadscreens"), exist_ok=True)
    os.makedirs(os.path.join(MEDIA, "maps"), exist_ok=True)
    total = 0
    made = []

    def record(name, nbytes):
        nonlocal total
        total += nbytes
        made.append((name, nbytes))

    record("solid.tga", solid())
    # 10px corner radius at a 32px slice, matching the concept's --radius:10px.
    record("panel-fill.tga", rounded(32, 10, path="panel-fill.tga"))
    record("panel-border.tga", rounded(32, 10, width=1, path="panel-border.tga"))
    record("pill-fill.tga", rounded(32, 16, path="pill-fill.tga"))
    record("pill-border.tga", rounded(32, 16, width=1, path="pill-border.tga"))
    record("cap-top.tga", capped(32, 10, "top", "cap-top.tga"))
    record("cap-bottom.tga", capped(32, 10, "bottom", "cap-bottom.tga"))
    record("tab-fill.tga", rounded(32, 6, path="tab-fill.tga"))
    record("tab-border.tga", rounded(32, 6, width=1, path="tab-border.tga"))
    record("circle-fill.tga", circle(32, path="circle-fill.tga"))
    record("circle-border.tga", circle(32, width=2, path="circle-border.tga"))
    record("shadow.tga", shadow())
    record("progress-fill.tga", progress_fill())
    record("progress-mask.tga", progress_mask())
    record("minimap-logo.tga", minimap_logo())
    record("logo.tga", logo())
    for f in _sources(LOADSCREENS):
        name = os.path.splitext(f)[0]
        record("loadscreens/%s.tga" % name, loadscreen(name))
    for f in _sources(ZONEMAPS):
        name = os.path.splitext(f)[0]
        record("maps/%s.tga" % name, zonemap(name))
    record("wordmark.tga", wordmark())
    record("scroll-thumb.tga", scroll_thumb())
    record("switch-track.tga", switch_track())
    record("nav-arrow.tga", nav_arrow())
    record("nav-arrow-mask.tga", nav_arrow_mask())
    record("grip.tga", grip())

    for name, fn in sorted(ICONS.items()):
        record("icons/%s.tga" % name, _icon(fn, name))

    for name, fn in sorted(CHROME.items()):
        record("icons/%s.tga" % name, _icon(fn, name))

    for name, nbytes in made:
        print("  %-28s %6d bytes" % (name, nbytes))
    print("\n%d files, %.1f KiB total" % (len(made), total / 1024.0))


if __name__ == "__main__":
    main()
