"""Make PandaUI's runtime TGA files safe for the OctoWoW renderer.

The conversion is lossless with respect to the authored pixels: non-power-of-
two images are copied onto a transparent power-of-two canvas without scaling,
and large or renderer-sensitive atlases are repacked from exact pixel
rectangles.  The matching texture coordinates live in core/media.lua.

Run from the addon folder:

    python -B tools/make_client_safe_textures.py
"""

import os
import re
import struct
import sys

from PIL import Image


MAX_SIDE = 512
MODERN = os.path.join("media", "Textures", "modern-wow")
FOREVER = os.path.join("media", "Textures", "forever-wow")


def next_power_of_two(value):
    result = 1
    while result < value:
        result *= 2
    return result


def write_rle_tga(image, path):
    image = image.convert("RGBA")
    image.save(path, format="TGA", compression="tga_rle")
    with open(path, "rb") as handle:
        header = handle.read(18)
    if (len(header) != 18 or header[2] != 10 or header[16] != 32
            or header[17] != 8):
        raise ValueError("unexpected TGA encoding: " + path)


def write_if_changed(image, path):
    current = None
    if os.path.isfile(path):
        with Image.open(path) as opened:
            current = opened.convert("RGBA")
    matches = (current is not None and current.size == image.size and
               current.tobytes() == image.tobytes())
    if current is not None:
        current.close()
    if matches:
        return False
    write_rle_tga(image, path)
    with Image.open(path) as opened:
        verified = opened.convert("RGBA")
    if verified.size != image.size or verified.tobytes() != image.tobytes():
        verified.close()
        raise ValueError("pixel verification failed: " + path)
    verified.close()
    return True


def remove_source(path, changed):
    if os.path.isfile(path):
        os.remove(path)
        changed.append(path)


def write_piece_sheet(source, output_path, output_size, pieces):
    output = Image.new("RGBA", output_size, (0, 0, 0, 0))
    for label, source_box, output_xy in pieces:
        piece = source.crop(source_box)
        output.paste(piece, output_xy)
        piece.close()
        assert_region_equal(source, source_box, output, output_xy, label)
    changed = write_if_changed(output, output_path)
    output.close()
    return changed


def split_visible(source, output_base, width, height, changed):
    for row in range((height + MAX_SIDE - 1) // MAX_SIDE):
        for column in range((width + MAX_SIDE - 1) // MAX_SIDE):
            left, top = column * MAX_SIDE, row * MAX_SIDE
            right, bottom = min(width, left + MAX_SIDE), min(height, top + MAX_SIDE)
            output = Image.new("RGBA", (MAX_SIDE, MAX_SIDE), (0, 0, 0, 0))
            piece = source.crop((left, top, right, bottom))
            output.paste(piece, (0, 0))
            piece.close()
            path = "%s-%d-%d.tga" % (output_base, column, row)
            if write_if_changed(output, path):
                changed.append(path)
            output.close()


def repack_flipbook(path, output_base, cell, changed):
    if not os.path.isfile(path):
        return
    with Image.open(path) as opened:
        source = opened.convert("RGBA")
    for part in range(2):
        pieces = []
        for local_index in range(16):
            frame = part * 16 + local_index
            if frame >= 30:
                break
            source_column = frame % 5
            source_row = frame // 5
            output_column = local_index % 4
            output_row = local_index // 4
            pieces.append(("frame %d" % (frame + 1),
                           (source_column * cell, source_row * cell,
                            (source_column + 1) * cell,
                            (source_row + 1) * cell),
                           (output_column * cell, output_row * cell)))
        output_path = "%s-%d.tga" % (output_base, part)
        if write_piece_sheet(source, output_path, (512, 512), pieces):
            changed.append(output_path)
    source.close()
    remove_source(path, changed)


def assert_region_equal(source, source_box, output, output_xy, label):
    expected = source.crop(source_box).tobytes()
    width = source_box[2] - source_box[0]
    height = source_box[3] - source_box[1]
    actual = output.crop((output_xy[0], output_xy[1],
                          output_xy[0] + width,
                          output_xy[1] + height)).tobytes()
    if expected != actual:
        raise ValueError("pixel verification failed: " + label)


def repack(path, expected_size, output_size, pieces):
    with Image.open(path) as opened:
        source = opened.convert("RGBA")
    if source.size == output_size:
        source.close()
        return False
    if source.size != expected_size:
        raise ValueError("unexpected atlas size %s for %s" %
                         (source.size, path))

    output = Image.new("RGBA", output_size, (0, 0, 0, 0))
    for label, source_box, output_xy in pieces:
        piece = source.crop(source_box)
        output.paste(piece, output_xy)
        piece.close()
        assert_region_equal(source, source_box, output, output_xy, label)

    write_rle_tga(output, path)
    with Image.open(path) as verified_open:
        verified = verified_open.convert("RGBA")
    for label, source_box, output_xy in pieces:
        assert_region_equal(source, source_box, verified, output_xy, label)
    verified.close()
    output.close()
    source.close()
    return True


def repack_oversized(addon_root):
    modern = os.path.join(addon_root, MODERN)
    changed = []

    path = os.path.join(modern, "buttons", "128RedButton.tga")
    pieces = [
        ("normal bar", (1, 523, 292, 648), (0, 0)),
        ("normal cap", (392, 913, 432, 1038), (300, 0)),
        ("hover bar", (1, 783, 292, 908), (0, 128)),
        ("hover cap", (378, 1043, 418, 1168), (300, 128)),
        ("disabled bar", (1, 653, 292, 778), (0, 256)),
        ("disabled cap", (262, 1043, 302, 1168), (300, 256)),
        ("glow", (15, 418, 424, 490), (0, 384)),
    ]
    if repack(path, (512, 2048), (512, 512), pieces):
        changed.append(path)

    path = os.path.join(modern, "ui", "character-create-diamond-metal.tga")
    if os.path.isfile(path):
        with Image.open(path) as opened:
            source = opened.convert("RGBA")
        if source.size == (512, 2048):
            corners = [
                ("top-left corner", (16, 1052, 252, 1288), (0, 0)),
                ("top-right corner", (5, 1310, 241, 1546), (256, 0)),
                ("bottom-left corner", (16, 517, 252, 753), (0, 256)),
                ("bottom-right corner", (5, 775, 241, 1011), (256, 256)),
            ]
            rails = [
                ("top rail", (64, 304, 448, 356), (0, 0)),
                ("bottom rail", (64, 159, 448, 211), (0, 64)),
            ]
        elif source.size == (512, 1024):
            corners = [
                ("top-left corner", (0, 0, 236, 236), (0, 0)),
                ("top-right corner", (256, 0, 492, 236), (256, 0)),
                ("bottom-left corner", (0, 256, 236, 492), (0, 256)),
                ("bottom-right corner", (256, 256, 492, 492), (256, 256)),
            ]
            rails = [
                ("top rail", (0, 512, 384, 564), (0, 0)),
                ("bottom rail", (0, 576, 384, 628), (0, 64)),
            ]
        elif source.size == (512, 512):
            corners = rails = None
        else:
            source.close()
            raise ValueError("unexpected atlas size %s for %s" %
                             (source.size, path))
        if corners:
            if write_piece_sheet(source, path, (512, 512), corners):
                changed.append(path)
            rail_path = os.path.join(
                modern, "ui", "character-create-diamond-metal-rails.tga")
            if write_piece_sheet(source, rail_path, (512, 128), rails):
                changed.append(rail_path)
        source.close()

    path = os.path.join(modern, "buttons", "128GoldRedButton.tga")
    pieces = [
        ("normal bar", (1, 523, 292, 648), (0, 0)),
        ("normal cap", (296, 523, 409, 648), (300, 0)),
        ("disabled bar", (1, 653, 292, 778), (0, 128)),
        ("disabled cap", (296, 653, 409, 778), (300, 128)),
        ("pressed bar", (1, 783, 292, 908), (0, 256)),
        ("pressed cap", (296, 783, 409, 908), (300, 256)),
        ("glow", (15, 418, 424, 490), (0, 384)),
    ]
    if os.path.isfile(path) and repack(path, (512, 1024), (512, 512), pieces):
        changed.append(path)

    path = os.path.join(modern, "ui", "profession", "professions.tga")
    if os.path.isfile(path):
        with Image.open(path) as opened:
            source = opened.convert("RGBA")
        if source.size == (2048, 1024):
            boxes = {
                "list": (1, 79, 269, 651),
                "rank background": (611, 769, 1062, 798),
                "rank border": (1359, 133, 1810, 162),
                "selected": (1614, 39, 1881, 58),
                "highlight": (1276, 40, 1543, 59),
                "slot": (272, 420, 370, 518),
                "header left": (885, 28, 899, 54),
                "header middle": (709, 43, 710, 69),
                "header right": (932, 46, 946, 72),
                "collapsed": (619, 55, 641, 71),
                "expanded": (554, 55, 576, 71),
                "skill easy": (524, 55, 537, 70),
                "skill medium": (604, 55, 617, 70),
                "skill optimal": (539, 55, 552, 70),
                "loot card": (0, 834, 188, 916),
            }
        elif source.size == (1024, 1024):
            boxes = {
                "list": (0, 0, 268, 572),
                "rank background": (272, 0, 723, 29),
                "rank border": (272, 32, 723, 61),
                "selected": (272, 64, 539, 83),
                "highlight": (272, 88, 539, 107),
                "slot": (272, 112, 370, 210),
                "header left": (384, 112, 398, 138),
                "header middle": (400, 112, 401, 138),
                "header right": (408, 112, 422, 138),
                "collapsed": (424, 112, 446, 128),
                "expanded": (448, 112, 470, 128),
                "skill easy": (472, 112, 485, 127),
                "skill medium": (488, 112, 501, 127),
                "skill optimal": (504, 112, 517, 127),
            }
        elif source.size == (512, 256):
            boxes = None
        else:
            source.close()
            raise ValueError("unexpected atlas size %s for %s" %
                             (source.size, path))
        if boxes:
            list_image = source.crop(boxes["list"])
            for index, box in enumerate(((0, 0, 268, 512), (0, 512, 268, 572))):
                tile = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
                piece = list_image.crop(box)
                tile.paste(piece, (0, 0))
                piece.close()
                output_path = os.path.join(
                    modern, "ui", "profession", "professions-list-%d.tga" % index)
                if write_if_changed(tile, output_path):
                    changed.append(output_path)
                tile.close()
            list_image.close()
            placements = {
                "rank background": (0, 0), "rank border": (0, 32),
                "selected": (0, 64), "highlight": (0, 88),
                "slot": (272, 64), "header left": (0, 128),
                "header middle": (16, 128), "header right": (24, 128),
                "collapsed": (40, 128), "expanded": (64, 128),
                "skill easy": (88, 128), "skill medium": (104, 128),
                "skill optimal": (120, 128),
                "loot card": (0, 168),
            }
            pieces = [(label, boxes[label], output_xy)
                      for label, output_xy in placements.items()]
            if write_piece_sheet(source, path, (512, 256), pieces):
                changed.append(path)
        source.close()

    path = os.path.join(modern, "microbar", "micromenu.tga")
    source_cells = [
        ("plate up", (67, 253)),
        ("plate down", (67, 169)),
        ("Achievements normal", (1, 253)),
        ("Achievements pushed", (1, 85)),
        ("Achievements highlight", (1, 169)),
        ("Achievements disabled", (1, 1)),
        ("SpellbookAbilities normal", (595, 169)),
        ("SpellbookAbilities pushed", (595, 1)),
        ("SpellbookAbilities highlight", (595, 85)),
        ("SpellbookAbilities disabled", (529, 421)),
        ("Professions normal", (397, 337)),
        ("Professions pushed", (397, 169)),
        ("Professions highlight", (397, 253)),
        ("Professions disabled", (397, 85)),
        ("SpecTalents normal", (529, 337)),
        ("SpecTalents pushed", (529, 169)),
        ("SpecTalents highlight", (529, 253)),
        ("SpecTalents disabled", (529, 85)),
        ("Questlog normal", (463, 169)),
        ("Questlog pushed", (463, 1)),
        ("Questlog highlight", (463, 85)),
        ("Questlog disabled", (397, 421)),
        ("GuildCommunities normal", (265, 421)),
        ("GuildCommunities pushed", (199, 421)),
        ("GuildCommunities highlight", (265, 337)),
        ("GuildCommunities disabled", (199, 337)),
        ("Groupfinder normal", (199, 253)),
        ("Groupfinder pushed", (199, 85)),
        ("Groupfinder highlight", (199, 169)),
        ("Groupfinder disabled", (199, 1)),
        ("AdventureGuide normal", (67, 85)),
        ("AdventureGuide pushed", (1, 421)),
        ("AdventureGuide highlight", (67, 1)),
        ("AdventureGuide disabled", (1, 337)),
        ("Shop normal", (529, 1)),
        ("Shop pushed", (463, 421)),
        ("Shop highlight", (463, 337)),
        ("Shop disabled", (463, 253)),
        ("GameMenu normal", (133, 421)),
        ("GameMenu pushed", (133, 253)),
        ("GameMenu highlight", (133, 337)),
        ("GameMenu disabled", (133, 169)),
    ]
    pieces = []
    for index, item in enumerate(source_cells):
        label, source_xy = item
        source_box = (source_xy[0], source_xy[1],
                      source_xy[0] + 64, source_xy[1] + 82)
        output_xy = ((index % 7) * 64, (index // 7) * 84)
        pieces.append((label, source_box, output_xy))
    if repack(path, (1024, 512), (512, 512), pieces):
        changed.append(path)

    path = os.path.join(modern, "ui", "questbackgroundparchment.tga")
    if os.path.isfile(path) and repack(
            path, (1024, 1024), (512, 512),
            [("top-left parchment", (0, 0, 512, 512), (0, 0))]):
        changed.append(path)

    path = os.path.join(modern, "ui", "frame", "dialog-diamond-metal.tga")
    dialog_pieces = [
        ("bottom", (0, 1, 128, 129), (0, 0)),
        ("top", (0, 131, 128, 259), (128, 0)),
        ("bottom-left", (1, 261, 129, 389), (0, 128)),
        ("bottom-right", (1, 391, 129, 519), (128, 128)),
        ("top-left", (1, 521, 129, 649), (0, 256)),
        ("top-right", (1, 651, 129, 779), (128, 256)),
    ]
    if os.path.isfile(path) and repack(
            path, (256, 1024), (256, 512), dialog_pieces):
        changed.append(path)

    ui = os.path.join(modern, "ui")
    quest_left = os.path.join(ui, "questlog-left-large-v2.tga")
    if os.path.isfile(quest_left):
        with Image.open(quest_left) as opened:
            source = opened.convert("RGBA")
        if source.size != (1024, 1024):
            source.close()
            raise ValueError("unexpected quest log atlas size: " + quest_left)
        split_visible(source, os.path.splitext(quest_left)[0], 896, 823, changed)
        source.close()
        remove_source(quest_left, changed)

    quest_right = os.path.join(ui, "questlog-right-large.tga")
    if os.path.isfile(quest_right):
        with Image.open(quest_right) as opened:
            source = opened.convert("RGBA")
        if source.size != (512, 1024):
            source.close()
            raise ValueError("unexpected quest log atlas size: " + quest_right)
        split_visible(source, os.path.splitext(quest_right)[0], 298, 823, changed)
        source.close()
        remove_source(quest_right, changed)

    profession = os.path.join(ui, "profession")
    for name in ("background-art", "background-art-alchemy",
                 "background-art-blacksmithing", "background-art-cooking",
                 "background-art-enchanting", "background-art-engineering",
                 "background-art-leatherworking", "background-art-mining",
                 "background-art-tailoring"):
        source_path = os.path.join(profession, name + ".tga")
        if not os.path.isfile(source_path):
            continue
        with Image.open(source_path) as opened:
            source = opened.convert("RGBA")
        if source.size != (1024, 1024):
            source.close()
            raise ValueError("unexpected profession art size: " + source_path)
        art = source.crop((1, 1, 676, 549))
        split_visible(art, os.path.splitext(source_path)[0], 675, 548, changed)
        art.close()
        source.close()
        remove_source(source_path, changed)

    for name in ("fx-alchemy", "fx-blacksmithing", "fx-cooking",
                 "fx-enchanting", "fx-engineering", "fx-leatherworking",
                 "fx-mining", "fx-skinning", "fx-tailoring"):
        source_path = os.path.join(profession, name + ".tga")
        if not os.path.isfile(source_path):
            continue
        with Image.open(source_path) as opened:
            source = opened.convert("RGBA")
        if source.size != (1024, 64):
            source.close()
            raise ValueError("unexpected profession fill size: " + source_path)
        for index in range(2):
            tile = source.crop((index * 512, 0, (index + 1) * 512, 64))
            output_path = os.path.join(profession, "%s-%d.tga" % (name, index))
            if write_if_changed(tile, output_path):
                changed.append(output_path)
            tile.close()
        source.close()
        remove_source(source_path, changed)

    repack_flipbook(os.path.join(ui, "spell-alert-start.tga"),
                    os.path.join(ui, "spell-alert-start"), 128, changed)
    repack_flipbook(os.path.join(ui, "spell-alert-loop.tga"),
                    os.path.join(ui, "spell-alert-loop"), 101, changed)

    return changed


def split_forever_options(addon_root):
    """Split the renderer-sensitive 1024-square options atlas losslessly.

    Runtime code reconstructs requested atlas members from four exact 512
    tiles. The import source is removed so an oversized file cannot enter a
    release accidentally.
    """
    root = os.path.join(addon_root, FOREVER, "settings")
    source_path = os.path.join(root, "options.tga")
    if not os.path.isfile(source_path):
        return []
    with Image.open(source_path) as opened:
        source = opened.convert("RGBA")
    if source.size != (1024, 1024):
        source.close()
        raise ValueError("unexpected atlas size %s for %s" %
                         (source.size, source_path))

    changed = []
    for row in range(2):
        for column in range(2):
            left, top = column * 512, row * 512
            tile = source.crop((left, top, left + 512, top + 512))
            output_path = os.path.join(
                root, "options-%d-%d.tga" % (column, row))
            if write_if_changed(tile, output_path):
                changed.append(output_path)
            tile.close()
    source.close()
    remove_source(source_path, changed)
    return changed


def split_modern_scrollbar(addon_root):
    """Split the 64x1024 scrollbar and remove the import-only source."""
    root = os.path.join(addon_root, MODERN, "ui")
    source_path = os.path.join(root, "minimal-scrollbar-vertical.tga")
    if not os.path.isfile(source_path):
        return []
    with Image.open(source_path) as opened:
        source = opened.convert("RGBA")
    if source.size != (64, 1024):
        source.close()
        raise ValueError("unexpected atlas size %s for %s" %
                         (source.size, source_path))

    changed = []
    for index in range(2):
        tile = source.crop((0, index * 512, 64, (index + 1) * 512))
        output_path = os.path.join(
            root, "minimal-scrollbar-vertical-%d.tga" % index)
        if write_if_changed(tile, output_path):
            changed.append(output_path)
        tile.close()
    source.close()
    remove_source(source_path, changed)
    return changed


def remove_import_sources(addon_root):
    modern = os.path.join(addon_root, MODERN)
    changed = []
    paths = [
        os.path.join(modern, "minimap", "uiminimap2x.tga"),
        os.path.join(modern, "ui", "questlog-left-large.tga"),
        os.path.join(modern, "ui", "character", "PaperDollInfoPart1.BLP"),
        os.path.join(modern, "ui", "character", "PaperDollInfoPart2.BLP"),
        os.path.join(modern, "unitframes", "UIUnitFrame2x.BLP"),
        os.path.join(addon_root, FOREVER, "ui", "frame-metal-corners.tga"),
        os.path.join(addon_root, FOREVER, "ui", "minimal-scrollbar-middle.tga"),
        os.path.join(addon_root, FOREVER, "ui", "minimal-scrollbar-small-middle.tga"),
    ]
    for path in paths:
        remove_source(path, changed)
    return changed


def pad_tga(path):
    with Image.open(path) as opened:
        source = opened.convert("RGBA")
    width, height = source.size
    target = (next_power_of_two(width), next_power_of_two(height))
    if width > MAX_SIDE or height > MAX_SIDE:
        source.close()
        raise ValueError("unhandled texture exceeds %d: %s" % (MAX_SIDE, path))
    if target == source.size:
        source.close()
        return False, source.size, target
    if target[0] > MAX_SIDE or target[1] > MAX_SIDE:
        source.close()
        raise ValueError("texture still exceeds %d: %s" % (MAX_SIDE, path))

    output = Image.new("RGBA", target, (0, 0, 0, 0))
    output.paste(source, (0, 0))
    if output.crop((0, 0, width, height)).tobytes() != source.tobytes():
        raise ValueError("pixel verification failed: " + path)
    write_rle_tga(output, path)
    with Image.open(path) as verified_open:
        verified = verified_open.convert("RGBA")
    if verified.crop((0, 0, width, height)).tobytes() != source.tobytes():
        raise ValueError("saved pixel verification failed: " + path)
    verified.close()
    output.close()
    source.close()
    return True, (width, height), target


def audit_runtime_textures(addon_root):
    failures = []
    count = 0
    for root, _, files in os.walk(os.path.join(addon_root, "media")):
        for name in files:
            extension = os.path.splitext(name)[1].lower()
            if extension not in (".tga", ".blp"):
                continue
            path = os.path.join(root, name)
            if extension == ".tga":
                with Image.open(path) as image:
                    width, height = image.size
            else:
                with open(path, "rb") as handle:
                    header = handle.read(20)
                if len(header) < 20 or header[:4] not in (b"BLP1", b"BLP2"):
                    failures.append("unreadable BLP header: " + path)
                    continue
                width, height = struct.unpack("<II", header[12:20])
            count += 1
            if (width > MAX_SIDE or height > MAX_SIDE or
                    next_power_of_two(width) != width or
                    next_power_of_two(height) != height):
                failures.append("%dx%d %s" % (width, height, path))
    if failures:
        raise ValueError("unsafe runtime textures:\n" + "\n".join(failures))
    return count


def update_attribution(addon_root):
    root = os.path.join(addon_root, MODERN)
    path = os.path.join(root, "ATTRIBUTION.md")
    if not os.path.isfile(path):
        return
    with open(path, "r", encoding="utf-8") as handle:
        lines = handle.read().splitlines()

    row_pattern = re.compile(r"^(\| `([^`]+\.tga)` \| )([^|]+)( \|.*)$")
    removed_sources = {
        "minimap/uiminimap2x.tga",
        "ui/minimal-scrollbar-vertical.tga",
        "ui/questlog-left-large-v2.tga",
        "ui/questlog-left-large.tga",
        "ui/questlog-right-large.tga",
        "ui/spell-alert-start.tga",
        "ui/spell-alert-loop.tga",
    }
    for name in ("background-art", "background-art-alchemy",
                 "background-art-blacksmithing", "background-art-cooking",
                 "background-art-enchanting", "background-art-engineering",
                 "background-art-leatherworking", "background-art-mining",
                 "background-art-tailoring", "fx-alchemy",
                 "fx-blacksmithing", "fx-cooking", "fx-enchanting",
                 "fx-engineering", "fx-leatherworking", "fx-mining",
                 "fx-skinning", "fx-tailoring"):
        removed_sources.add("ui/profession/" + name + ".tga")

    marker = "## OctoWoW client-safe canvases"
    if marker in lines:
        lines = lines[:lines.index(marker)]

    updated = []
    for line in lines:
        match = row_pattern.match(line)
        if match:
            relative = match.group(2)
            texture_path = os.path.join(root, relative.replace("/", os.sep))
            if os.path.isfile(texture_path):
                with Image.open(texture_path) as image:
                    size = "%dx%d" % image.size
                line = match.group(1) + size + match.group(4)
            elif relative in removed_sources:
                line = ("| import source `%s` (not shipped) | %s%s" %
                        (relative, match.group(3), match.group(4)))
        updated.append(line)

    updated.extend([
        "",
        marker,
        "",
        "Every shipped TGA is power-of-two and at most 512 px per dimension. "
        "Rows labelled `import source` document upstream inputs that the import "
        "tool removes after deriving runtime files; those paths are not shipped.",
        "",
        "Compatibility conversion never scales, resamples, quantizes, or uses "
        "lossy recompression. Exact source pixels are transparently padded, "
        "cropped to already-addressed atlas members, or split among these "
        "runtime files:",
        "",
        "- `questlog-left-large-v2-{0,1}-{0,1}.tga` and "
        "`questlog-right-large-0-{0,1}.tga`;",
        "- `profession/background-art*-{0,1}-{0,1}.tga`, "
        "`profession/fx-*-{0,1}.tga`, and `professions-list-{0,1}.tga`;",
        "- `spell-alert-start-{0,1}.tga` and "
        "`spell-alert-loop-{0,1}.tga`;",
        "- `character-create-diamond-metal-rails.tga`, the companion to the "
        "512-square corner atlas;",
        "- `minimal-scrollbar-vertical-{0,1}.tga`, the exact source halves.",
    ])
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(updated) + "\n")


def convert_client_textures(addon_root):
    addon_root = os.path.abspath(addon_root)
    repacked = repack_oversized(addon_root)
    repacked.extend(split_forever_options(addon_root))
    repacked.extend(split_modern_scrollbar(addon_root))
    repacked.extend(remove_import_sources(addon_root))
    padded = []
    for root, _, files in os.walk(addon_root):
        if os.path.basename(root).lower() == ".git":
            continue
        for name in files:
            if not name.lower().endswith(".tga"):
                continue
            path = os.path.join(root, name)
            changed, before, after = pad_tga(path)
            if changed:
                padded.append((path, before, after))

    update_attribution(addon_root)
    audit_runtime_textures(addon_root)
    return repacked, padded


def main():
    addon_root = os.getcwd()
    if not os.path.isfile(os.path.join(addon_root, "pandaUI.toc")):
        sys.stderr.write("run from the pandaUI addon folder\n")
        return 1
    repacked, padded = convert_client_textures(addon_root)
    for path in repacked:
        print("repacked  " + os.path.relpath(path, addon_root))
    for path, before, after in padded:
        print("padded    %s %dx%d -> %dx%d" %
              (os.path.relpath(path, addon_root), before[0], before[1],
               after[0], after[1]))
    print("%d atlases repacked; %d textures padded" %
          (len(repacked), len(padded)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
