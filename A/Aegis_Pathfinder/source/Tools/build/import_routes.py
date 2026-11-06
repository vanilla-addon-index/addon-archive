#!/usr/bin/env python3
"""Plan CraftRoute's 1-300 routes and save them for the profession guides.

    python3 Tools/build/import_routes.py <path to a CraftRoute checkout> [--check]

CraftRoute (https://github.com/Kitymeowmeow-turt/CraftRoute, GPLv3, by
Kitymeowmeow) plans the cheapest way to level each crafting profession from
auction prices. Its routes are what the crafting guides in Guides/Professions/
follow, with its author's blessing: this runs CraftRoute's own planner, from
the checkout, outside the game (Tools/build/craftroute_harness.lua stands in
for the game's API), and keeps only the routes it prints -- which recipe, over
which skills, how many crafts. None of CraftRoute's code ships in the addon.

The prices are CraftRoute's sample auction scan (test_scan_data.lua) and its
merchant prices. The scan lists hardly anything players gather for themselves
-- meat, fish, Survival's wood and leaves -- and a reagent with no price keeps
its recipe out of a route (Cooking could not start at all). So a raw material
that has no listing and no merchant selling it is costed at MARKUP times what
a merchant pays for it: the median the scan's own raw materials sell for, over
their merchant price, is about two and a half. Those items are recorded, and
the guides say they were costed that way.

Crafts are CraftRoute's expected counts, rounded up: a route says how many
attempts it takes on average, and a guide should not leave you short.

Writes Tools/data/craftroute_routes.json; Tools/build/convert_professions.py
authors the guides from it. Needs lua5.1. With --check it plans and validates
but writes nothing, and says whether the saved routes are out of date.
"""

import argparse
import datetime
import json
import math
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HARNESS = os.path.join(ROOT, "Tools", "build", "craftroute_harness.lua")
NAME_CACHE = os.path.join(ROOT, "Tools", "data", "recipe_item_names.json")
ROUTES = os.path.join(ROOT, "Tools", "data", "craftroute_routes.json")
RECIPES = os.path.join(ROOT, "Crafting")
MAX_SKILL = 300
MARKUP = 3

# CraftRoute's file key -> the profession's name in game.
TITLES = {
    "alchemy": "Alchemy", "blacksmithing": "Blacksmithing", "cooking": "Cooking",
    "enchanting": "Enchanting", "engineering": "Engineering", "jewelcrafting": "Jewelcrafting",
    "leatherworking": "Leatherworking", "survival": "Survival", "tailoring": "Tailoring",
}


def lua_str(s):
    return '"%s"' % s.replace("\\", "\\\\").replace('"', '\\"')


def names_file():
    """The reagent names CraftRoute gives by item id, as a Lua table."""
    with open(NAME_CACHE, encoding="utf-8") as fh:
        ids = json.load(fh)["ids"]
    fd, path = tempfile.mkstemp(suffix=".lua")
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
        fh.write("return {\n")
        for k in sorted(ids, key=int):
            fh.write("\t[%d] = %s,\n" % (int(k), lua_str(ids[k])))
        fh.write("}\n")
    return path


def plan(checkout):
    names = names_file()
    try:
        out = subprocess.run(["lua5.1", HARNESS, checkout, names, str(MARKUP)],
                             check=True, capture_output=True, text=True).stdout
    finally:
        os.remove(names)
    routes, totals, standins, scan = {}, {}, {}, None
    for line in out.splitlines():
        f = line.split("\t")
        if f[0] == "route":
            title = TITLES[f[1]]
            routes[title], totals[title] = [], {"copper": int(f[2]), "reached": int(f[3]),
                                                "stuck": None if f[4] == "-" else int(f[4])}
        elif f[0] == "step":
            routes[TITLES[f[1]]].append({
                "recipe": f[5], "from": int(f[2]), "to": int(f[3]),
                "crafts": int(math.ceil(float(f[4]) - 1e-6)),
            })
        elif f[0] == "standin":
            standins[f[1]] = int(f[2])
        elif f[0] == "scan":
            scan = datetime.datetime.fromtimestamp(int(f[1]), datetime.timezone.utc).strftime("%Y-%m-%d")
    return routes, totals, standins, scan


def recipe_names(title):
    """The recipes in Crafting/<title>.lua -- what the guides can describe."""
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import convert_professions
    return convert_professions.read_recipes(title)


def validate(routes, totals):
    problems = []
    for title in sorted(TITLES.values()):
        route, t = routes.get(title), totals.get(title)
        if not route:
            problems.append("%s: no route" % title)
            continue
        if t["stuck"] is not None or t["reached"] != MAX_SKILL:
            problems.append("%s: stops at %d" % (title, t["reached"]))
        recipes = recipe_names(title)
        cursor = 1
        for st in route:
            r = recipes.get(st["recipe"])
            if not r:
                problems.append("%s: %s is not in Crafting/%s.lua" % (title, st["recipe"], title))
                continue
            if st["from"] != cursor or st["to"] <= st["from"]:
                problems.append("%s: gap or overlap at %d-%d" % (title, st["from"], st["to"]))
            if st["from"] < r["orange"] or st["to"] > r["grey"]:
                problems.append("%s: %s used %d-%d but is orange at %d and grey at %d"
                                % (title, st["recipe"], st["from"], st["to"], r["orange"], r["grey"]))
            cursor = st["to"]
        if cursor != MAX_SKILL:
            problems.append("%s: route ends at %d" % (title, cursor))
    return problems


def document(routes, totals, standins, scan):
    used = set()
    for title, route in routes.items():
        recipes = recipe_names(title)
        for st in route:
            for g in recipes[st["recipe"]]["reagents"]:
                if g["item"] in standins:
                    used.add(g["item"])
    return {
        "_about": "CraftRoute's 1-300 routes (GPLv3, by Kitymeowmeow), planned by CraftRoute's own "
                  "planner on its sample auction scan. Written by Tools/build/import_routes.py; read "
                  "by Tools/build/convert_professions.py. crafts are its expected counts, rounded up; "
                  "copper is its estimate of the route's cost. standins are reagents the scan had no "
                  "listing for, costed at markup times their merchant sell price; only those the routes "
                  "use are kept.",
        "scan": scan,
        "markup": MARKUP,
        "standins": {k: standins[k] for k in sorted(used, key=str.lower)},
        "copper": {t: totals[t]["copper"] for t in sorted(routes)},
        "routes": {t: routes[t] for t in sorted(routes)},
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("craftroute", help="path to a CraftRoute checkout")
    ap.add_argument("--check", action="store_true", help="validate only; write nothing")
    args = ap.parse_args()

    routes, totals, standins, scan = plan(args.craftroute)
    problems = validate(routes, totals)
    for title in sorted(routes):
        r = routes[title]
        print("%-15s %2d steps  %4d crafts  ~%dg" % (
            title, len(r), sum(s["crafts"] for s in r), totals[title]["copper"] // 10000))
    if problems:
        print("\n%d problem(s):" % len(problems))
        for p in problems:
            print("  ! " + p)
        return 1

    doc = document(routes, totals, standins, scan)
    text = json.dumps(doc, indent=1, ensure_ascii=False) + "\n"
    print("\nscan of %s; %d reagents costed at %dx their merchant price" % (scan, len(doc["standins"]), MARKUP))
    if args.check:
        on_disk = open(ROUTES, encoding="utf-8").read() if os.path.exists(ROUTES) else None
        print("saved routes are " + ("current" if on_disk == text else "OUT OF DATE"))
        return 0 if on_disk == text else 1
    with open(ROUTES, "w", encoding="utf-8") as fh:
        fh.write(text)
    print("wrote " + os.path.relpath(ROUTES, ROOT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
