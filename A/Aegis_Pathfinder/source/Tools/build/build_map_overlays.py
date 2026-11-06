#!/usr/bin/env python3
"""Write MapOverlays.lua: where each area's art sits on its zone's map.

    python3 Tools/build/build_map_overlays.py <path to a pfUI checkout>

The guide browser shows a zone guide's zone as its map with every area
explored (GuidePictures.lua). The client draws an explored area as an overlay
on the map's twelve tiles, but only tells you where an area's overlay goes
once you have been there -- GetMapOverlayInfo knows nothing of the rest. So
where they all go is taken from pfUI's map reveal, which has them for every
1.12 zone and for Turtle WoW's own ("pfMapOverlayData", in
modules/turtle-wow.lua). pfUI is Shagu's (https://github.com/shagu/pfUI),
MIT; its licence is copied into the file written.

Only the zones the browser knows are kept: the map folders named in
GuideBrowser.lua's Browser.ZONES, but for the custom zones with a map of
their own (Theme.zonemap) -- built from Turtle WoW's tiles and these
overlays, they came out wrong in game. Each overlay is the string pfUI has,
"TEXTURE:width:height:offsetX:offsetY", in map pixels from the top left of
the 1002x668 map.
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "MapOverlays.lua")
BROWSER = os.path.join(ROOT, "GuideBrowser.lua")
THEME = os.path.join(ROOT, "Theme.lua")


def block(text, start):
    """The {...} that opens at or after `start`, braces matched."""
    i = text.index("{", start)
    depth = 0
    for j in range(i, len(text)):
        if text[j] == "{":
            depth += 1
        elif text[j] == "}":
            depth -= 1
            if depth == 0:
                return text[i:j + 1]
    raise ValueError("unbalanced braces")


def overlays(pfui):
    src = open(os.path.join(pfui, "modules", "turtle-wow.lua"), encoding="utf-8").read()
    at = src.find("pfMapOverlayData = {")
    if at < 0:
        sys.exit("pfMapOverlayData not found in modules/turtle-wow.lua")
    data = block(src, at)
    out = {}
    for name, body in re.findall(r'\["([^"]+)"\]\s*=\s*(\{[^{}]*\})', data):
        entries = re.findall(r'"([A-Za-z0-9_]+:\d+:\d+:\d+:\d+)"', body)
        if entries:
            out[name] = entries
    return out


def wanted():
    """The map folders GuideBrowser.lua's zones name, but those of the zones
    with a map of their own (Theme.zonemap), which need no overlays."""
    src = open(BROWSER, encoding="utf-8").read()
    zones = block(src, src.index("Browser.ZONES = {"))
    theme = open(THEME, encoding="utf-8").read()
    own = set(re.findall(r'\["([^"]+)"\]', block(theme, theme.index("Theme.zonemap = {"))))
    return set(folder for zone, folder in re.findall(r'\["([^"]+)"\]\s*=\s*\{\s*"([A-Za-z]+)"', zones)
               if zone not in own)


def licence(pfui):
    for name in ("LICENSE", "LICENSE.md", "LICENSE.txt"):
        path = os.path.join(pfui, name)
        if os.path.exists(path):
            return open(path, encoding="utf-8").read().strip().splitlines()
    sys.exit("pfUI's licence file not found")


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    pfui = sys.argv[1]
    data, want = overlays(pfui), wanted()
    missing = sorted(want - set(data))
    lines = [
        "-- MapOverlays.lua",
        "--",
        "-- GENERATED FILE -- do not edit by hand.",
        "-- Source:    pfUI's map reveal data, pfMapOverlayData in modules/turtle-wow.lua",
        "--            (https://github.com/shagu/pfUI)",
        "-- Generator: Tools/build/build_map_overlays.py",
        "--",
        "-- Where each area's explored art sits on its zone's map, for the guide",
        "-- browser's pictures (GuidePictures.lua): \"TEXTURE:width:height:x:y\", in",
        "-- pixels from the top left of the 1002x668 map.",
        "--",
        "-- pfUI's licence, which covers this data:",
        "--",
    ]
    lines += [("-- " + l).rstrip() for l in licence(pfui)]
    lines += ["", "AegisPathfinder.MAP_OVERLAYS = {"]
    for name in sorted(want & set(data)):
        lines.append('\t["%s"] = {' % name)
        for e in data[name]:
            lines.append('\t\t"%s",' % e)
        lines.append("\t},")
    lines.append("}")
    open(OUT, "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")
    print("MapOverlays.lua: %d maps" % len(want & set(data)))
    if missing:
        print("No overlay data for: " + ", ".join(missing))


if __name__ == "__main__":
    main()
