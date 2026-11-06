#!/usr/bin/env python3
"""Read RestedXP's Classic levelling talent guides into talent names in the
order the points go, for the Talent Advisor (Part 4) to start from.

RestedXP's guides (Guides/Talents/classic-*.lua, CC BY-NC-SA 4.0) are written
for the original 1.12 trees: each level's point as `.talent TAB,ROW,COLUMN,
RANK` with the talent's name in the comment before it. This writes, for each
guide, its points in order -- tab, row, column, rank and name -- and checks
what can be checked without the tree itself: five points in a tree for each
row down, no more than 51 points, and one name for each place and one place for each name. Three comments that name a
neighbour's talent are put right (CORRECTIONS). A rank the
file repeats is read as the next one, as its comment has it; a level marked
#optional (one weapon's specialization or another's) is one point with its
choices. Prerequisites, and whether Turtle WoW's trees still have the
talent there, need the trees the game has (`/apg talents`).

  python3 Tools/build/import_rxp_talents.py --rxp DIR [--out FILE]
"""

import argparse
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HOME = os.path.dirname(ROOT)
DEFAULT_RXP = os.path.join(HOME, "restedxp", "rxpguides")
DEFAULT_OUT = os.path.join(ROOT, "Tools", "data", "rxp_classic_talents.json")
CLASSES = ["druid", "hunter", "mage", "paladin", "priest", "rogue", "shaman", "warlock", "warrior"]

# Places whose comment names the wrong talent in RestedXP's files -- the
# place is right, the name is a neighbour's, copied -- by class, tree, row
# and column, with the 1.12 talent that is there.
CORRECTIONS = {
    ("PRIEST", 2, 1, 3): "Holy Specialization",        # "Improved Renew", its neighbour
    ("WARLOCK", 1, 3, 1): "Improved Curse of Agony",   # "Fel Concentration", its neighbour
    ("WARLOCK", 1, 7, 2): "Dark Pact",                 # "Siphon Life", two rows up
}

GUIDE = re.compile(r"RegisterGuide\(\[\[(.*?)\]\]\)", re.S)
TALENT = re.compile(r"\.talent\s+(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)")


def parse_guide(text):
    """One guide: its tags, and its levels, each with its talents. A level
    marked #optional lists choices -- one weapon's specialization or
    another's -- and is still one point."""
    tags, levels = {}, []
    for raw in text.splitlines():
        line = raw.strip()
        if line.startswith("#") and not levels:
            key, _, value = line[1:].partition(" ")
            tags[key.lower()] = value.strip() or True
        elif line.startswith("#optional") and levels:
            levels[-1]["optional"] = True
        elif line.startswith("level"):
            comment = line.partition("--")[2].strip()
            levels.append({"comment": comment, "talents": [], "optional": False})
        else:
            m = TALENT.search(line)
            if m and levels:
                note = line.partition("--")[2].strip()
                levels[-1]["talents"].append((tuple(int(v) for v in m.groups()), note))
    return tags, levels


def talent_name(comment):
    return re.sub(r"\s*\(Rank \d+\)\s*$", "", comment).strip()


def points_of(levels, ranks, cls=None):
    """The guide's points in order. A rank is the one after the last taken
    there: RestedXP's files sometimes repeat a rank (Improved Voidwalker
    "3, 3, 3" for ranks 1 to 3), which its comments get right. Returns the
    points and what was put right."""
    points, fixed = [], []
    for lv in levels:
        if not lv["talents"]:
            continue
        choices = []
        for (tab, row, col, rank), note in lv["talents"]:
            where = (tab, row, col)
            want = ranks.get(where, 0) + 1
            if rank != want:
                fixed.append("%s: rank %d read as %d" % (talent_name(note or lv["comment"]), rank, want))
            name = talent_name(note) if note else talent_name(lv["comment"])
            right = CORRECTIONS.get((cls, tab, row, col))
            if right and right != name:
                fixed.append("%s at tree %d row %d column %d is %s" % (name, tab, row, col, right))
                name = right
            choices.append({"tab": tab, "row": row, "col": col, "rank": want, "name": name})
        first = dict(choices[0])
        if lv["optional"]:
            first["name"] = talent_name(lv["comment"])
            first["choices"] = choices
        for c in choices:
            ranks[(c["tab"], c["row"], c["col"])] = c["rank"]
        points.append(first)
    return points, fixed


def check(points, names, places=None):
    """What is wrong with a build's points, from level 10, as the 1.12 rules
    have them: five points in a tree for each row down, and one name for
    each place. (Ranks are taken one at a time by points_of.)"""
    problems = []
    spent = {}
    for i, p in enumerate(points):
        need = 5 * (p["row"] - 1)
        if spent.get(p["tab"], 0) < need:
            problems.append("point %d (%s): row %d of tree %d needs %d points in it, has %d"
                            % (i + 1, p["name"], p["row"], p["tab"], need, spent.get(p["tab"], 0)))
        for c in p.get("choices", [p]):
            where = (c["tab"], c["row"], c["col"])
            if names.setdefault(where, c["name"]) != c["name"]:
                problems.append("point %d: tree %d row %d column %d is %r here, %r elsewhere"
                                % (i + 1, c["tab"], c["row"], c["col"], c["name"], names[where]))
            if places is not None and places.setdefault(c["name"], where) != where:
                problems.append("point %d: %r is at tree %d row %d column %d here, %r elsewhere"
                                % (i + 1, c["name"], c["tab"], c["row"], c["col"], places[c["name"]]))
        spent[p["tab"]] = spent.get(p["tab"], 0) + 1
    if len(points) > 51:
        problems.append("%d points: more than levels 10 to 60 give" % len(points))
    return problems


def compact(points):
    """The points as talents and ranks, in order: [["Deflection", 5],
    ["Tactical Mastery", 5], ...] -- a run of one talent's ranks as one."""
    out = []
    for p in points:
        if out and out[-1][0] == p["name"]:
            out[-1][1] = p["rank"]
        else:
            out.append([p["name"], p["rank"]])
    return out


def read_class(path, cls=None):
    """Each guide of a class: its points in order, carried on from the guide
    before it unless it starts with a respec (#reset)."""
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    raw = [parse_guide(body) for body in GUIDE.findall(text)]
    by_name = {tags.get("name"): (tags, levels) for tags, levels in raw}
    names, places, guides = {}, {}, []
    for tags, levels in raw:
        # The guides before this one since the last respec.
        chain, prev = [], tags
        while "reset" not in prev:
            before = [t for t, _ in raw if t.get("next") == prev.get("name")]
            if not before:
                break
            prev = before[0]
            chain.insert(0, by_name[prev["name"]][1])
        ranks, carried = {}, []
        for lv in chain:
            pts, _ = points_of(lv, ranks, cls)
            carried += pts
        own, fixed = points_of(levels, ranks, cls)
        build = carried + own
        guides.append({
            "name": tags.get("name"),
            "survival": "hardcore" in tags,
            "respec": "reset" in tags,
            "min_level": int(tags.get("minlevel", 10)),
            "max_level": int(tags.get("maxlevel", 60)),
            "next": tags.get("next"),
            "carried": len(carried),
            "points": own,
            "order": compact(own),
            "fixed": fixed,
            "problems": check(build, names, places),
        })
    return guides


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--rxp", default=DEFAULT_RXP, help="a checkout of RestedXP's rxpguides")
    ap.add_argument("--out", default=DEFAULT_OUT)
    args = ap.parse_args()
    data = {"source": "RestedXP Guides (https://github.com/RestedXP/RXPGuides), Guides/Talents/classic-*.lua, "
                      "CC BY-NC-SA 4.0. Written for the original 1.12 trees.",
            "classes": {}}
    bad = 0
    for cls in CLASSES:
        path = os.path.join(args.rxp, "Guides", "Talents", "classic-%s.lua" % cls)
        if not os.path.exists(path):
            sys.exit("missing: %s" % path)
        guides = read_class(path, cls.upper())
        data["classes"][cls.upper()] = guides
        for g in guides:
            bad += len(g["problems"])
            for p in g["problems"]:
                print("%s / %s: %s" % (cls, g["name"], p))
            for f in g["fixed"]:
                print("%s / %s: put right: %s" % (cls, g["name"], f))
    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with open(args.out, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(data, fh, indent=1)
    n = sum(len(v) for v in data["classes"].values())
    print("wrote %s: %d guides for %d classes, %d problems" % (os.path.relpath(args.out, ROOT), n, len(CLASSES), bad))


if __name__ == "__main__":
    main()
