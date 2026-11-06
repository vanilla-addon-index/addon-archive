#!/usr/bin/env python3
"""Write Rares.lua: where the rare creatures can spawn, for the Maps page's
points of interest (Maps.lua).

From pfQuest-turtle's database, as Turtle WoW has them, with vanilla
pfQuest's for anything pfQuest-turtle does not list: every creature ranked
rare (4) or rare elite (2), its level and the points it can spawn at, by the
zone's name. Where a rare is up right now, nothing in 1.12 can say.

  python3 Tools/build/build_rares.py --pfquest DIR --pfquest-turtle DIR
"""

import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_gathering import lua_names  # noqa: E402
from build_gear_data import lua_entries  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "Rares.lua")
HOME = os.path.dirname(ROOT)
RANKS = {"4": "rare", "2": "elite"}


def parse(body):
    """rank, (lo, hi) and spawn points of one pfQuest unit entry."""
    rank = re.search(r'\["rnk"\] = "(\d)"', body)
    lvl = re.search(r'\["lvl"\] = "([\d-]+)"', body)
    points = re.findall(r"\{ ([\d.]+), ([\d.]+), (\d+), \d+ \}", body)
    lo = hi = None
    if lvl:
        parts = [int(p) for p in lvl.group(1).split("-") if p]
        lo, hi = parts[0], parts[-1]
    return rank and rank.group(1), lo, hi, [(float(x), float(y), int(z)) for x, y, z in points]


def rares(pf, pft):
    def p(base, *parts):
        path = os.path.join(base, "db", *parts)
        if not os.path.exists(path):
            sys.exit("missing pfQuest file: %s" % path)
        return path
    units = lua_entries(p(pf, "units.lua"))
    units.update(lua_entries(p(pft, "units-turtle.lua")))
    names = lua_names(p(pf, "enUS", "units.lua"))
    names.update(lua_names(p(pft, "enUS", "units-turtle.lua")))
    zones = lua_names(p(pf, "enUS", "zones.lua"))
    zones.update(lua_names(p(pft, "enUS", "zones-turtle.lua")))
    out = {}
    for uid, body in units.items():
        if not body:
            continue                       # none, or removed by Turtle
        rank, lo, hi, points = parse(body)
        if rank not in RANKS or not lo or not names.get(uid):
            continue
        byzone = {}
        for x, y, z in points:
            if zones.get(z):
                byzone.setdefault(zones[z], []).append((x, y))
        for zone, pts in byzone.items():
            out.setdefault(zone, []).append((names[uid], lo, hi, RANKS[rank], pts))
    return out


def lua_str(s):
    return '"%s"' % s.replace("\\", "\\\\").replace('"', '\\"')


def write(data):
    count = sum(len(v) for v in data.values())
    lua = [
        "-- Rares.lua",
        "--",
        "-- GENERATED FILE -- do not edit by hand.",
        "-- Source:    pfQuest-turtle (https://github.com/shagu/pfQuest-turtle) and pfQuest",
        "--            (https://github.com/shagu/pfQuest): db/units, db/enUS/units, db/enUS/zones",
        "-- Generator: Tools/build/build_rares.py",
        "--",
        "-- The rare and rare elite creatures by zone, for the Maps page's points of",
        "-- interest: { name, lowest level, highest level, \"rare\" or \"elite\",",
        "-- { x, y, x, y, ... } } -- where they can spawn, in percent of the zone's map.",
        "",
        "AegisPathfinder.RARES = {",
    ]
    for zone in sorted(data):
        lua.append("\t[%s] = {" % lua_str(zone))
        for name, lo, hi, rank, pts in sorted(data[zone]):
            flat = ", ".join("%g, %g" % (x, y) for x, y in pts)
            lua.append("\t\t{ %s, %d, %d, \"%s\", { %s } }," % (lua_str(name), lo, hi, rank, flat))
        lua.append("\t},")
    lua.append("}")
    with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lua) + "\n")
    return count


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--pfquest", default=os.path.join(HOME, "shagu", "pfQuest"))
    ap.add_argument("--pfquest-turtle", default=os.path.join(HOME, "shagu", "pfQuest-turtle"))
    args = ap.parse_args()
    data = rares(args.pfquest, args.pfquest_turtle)
    n = write(data)
    print("wrote %s: %d rares in %d zones" % (os.path.relpath(OUT, ROOT), n, len(data)))


if __name__ == "__main__":
    main()
