#!/usr/bin/env python3
"""Write a guide for each attunement and key: the quests that open a raid or
a dungeon -- Molten Core, Onyxia's Lair, Blackwing Lair, Naxxramas, Turtle
WoW's Emerald Sanctum and both of its Karazhans, and the keys to Upper
Blackrock Spire, Scholomance, Blackrock Depths' inner city and Karazhan's
crypts -- one guide each, per side.

    python3 Tools/build/build_attunement_guides.py              # write Guides/Attunements/
    python3 Tools/build/build_attunement_guides.py --check      # fail if they are stale
    python3 Tools/build/build_attunement_guides.py --list       # each side's chains
    python3 Tools/build/build_attunement_guides.py --pfquest DIR --pfquest-turtle DIR --cmangos FILE
                                                     # read the quest data again first

Each attunement is named below by the quest that finishes it, per side. Its
chain is found from the data: the quests before it (pfQuest's "quests
before", CMaNGOS' PrevQuestId), going back, keeping a quest only if the
side can get it -- someone gives it, the side's races may take it, and the
same holds for a quest before it. So Karazhan's key takes each side's own
parts III to V (and not the Alliance's first IV and V, which nobody gives
any more), and Onyxia's Horde chain all three Tests of Skulls.

The guide is written the way the class quest guides are
(build_class_guides.ClassGuide): each quest picked up, done and handed in,
doing first what can be done where you are, with the way into the dungeon
or raid a quest is done in. At the end of each side's file,
RegisterAttunements tells the guide browser what each guide opens, its
level, and the quests whose hand-in means you are attuned.

The data is pfQuest's (https://github.com/shagu/pfQuest), with The Kludge
Bureau's pfQuest-turtle (https://github.com/The-Kludge-Bureau/pfQuest-turtle)
over it for Turtle WoW's quests, and CMaNGOS classic-db's quest_template for
the chains. What the guides are written from is kept in
Tools/data/attunements.json, so --check needs none of them.
"""

import argparse
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_class_guides as cg  # noqa: E402

CACHE = os.path.join(ROOT, "Tools", "data", "attunements.json")
OUT = os.path.join(ROOT, "Guides", "Attunements")
SIDES = cg.SIDES

# What opens what: the instance, raid or dungeon, the chain's name, the quest
# that finishes it on each side, and what else the first step says. `attuned`
# lists other quests whose hand-in counts the same.
ATTUNEMENTS = [
    {"instance": "Molten Core", "kind": "raid", "name": "Attunement to the Core",
     "final": {"Alliance": 7848, "Horde": 7487},
     "note": "Lothos Riftwaker, on the ledge inside Blackrock Mountain, asks for a Core Fragment from "
             "Blackrock Depths; with it he can port you into Molten Core"},
    {"instance": "Onyxia's Lair", "kind": "raid", "name": "Drakefire Amulet", "final": {"Alliance": 6502},
     "note": "The Drakefire Amulet opens Onyxia's Lair. Parts of it need a group for Blackrock Depths "
             "and a raid for Upper Blackrock Spire"},
    {"instance": "Onyxia's Lair", "kind": "raid", "name": "Blood of the Black Dragon Champion",
     "final": {"Horde": 6602},
     "note": "The Drakefire Amulet opens Onyxia's Lair. Parts of it need a group for the Tests of Skulls "
             "and a raid for Upper Blackrock Spire"},
    {"instance": "Blackwing Lair", "kind": "raid", "name": "Blackhand's Command",
     "final": {"Alliance": 7761, "Horde": 7761},
     "note": "Blackhand's Command starts from an item the Scarshield Quartermaster drops in Lower "
             "Blackrock Spire; read it to be let into Blackwing Lair"},
    {"instance": "Naxxramas", "kind": "raid", "name": "The Dread Citadel",
     "final": {"Alliance": 9121, "Horde": 9121}, "attuned": [9122, 9123],
     "note": "Needs Honored with the Argent Dawn. Archmage Angela Dosantos asks less at Revered and "
             "nothing at Exalted: take whichever she offers"},
    {"instance": "Emerald Sanctum", "kind": "raid", "name": "Into the Dream",
     "final": {"Alliance": 40962, "Horde": 40962},
     "note": "Turtle WoW's raid in Hyjal. The Gemstone of Ysera it ends with lets you in"},
    {"instance": "Lower Karazhan Halls", "kind": "raid", "name": "The Key to Karazhan",
     "final": {"Alliance": 40829, "Horde": 40829},
     "note": "Turtle WoW's Karazhan, its lower halls and the way up"},
    {"instance": "Tower of Karazhan", "kind": "raid", "name": "The Scepter of Medivh",
     "final": {"Alliance": 41371, "Horde": 41371},
     "note": "The Otherwordly Scepter of Medivh opens Karazhan's upper tower"},
    {"instance": "Upper Blackrock Spire", "kind": "dungeon", "name": "Seal of Ascension",
     "final": {"Alliance": 4743, "Horde": 4743},
     "note": "Vaelan, in Lower Blackrock Spire, wants a gem from three of its bosses; the forged Seal of "
             "Ascension opens Upper Blackrock Spire"},
    {"instance": "Scholomance", "kind": "dungeon", "name": "The Key to Scholomance",
     "final": {"Alliance": 5505, "Horde": 5511},
     "note": "The Skeleton Key opens Scholomance"},
    {"instance": "Blackrock Depths", "kind": "dungeon", "name": "Shadowforge Key",
     "final": {"Alliance": 3802, "Horde": 3802},
     "note": "The Shadowforge Key opens the doors to Blackrock Depths' inner city"},
    {"instance": "Karazhan Crypts", "kind": "dungeon", "name": "The Mystery of Karazhan",
     "final": {"Alliance": 40317},
     "note": "Turtle WoW's crypts beneath Karazhan: the Karazhan Crypt Key lets you in"},
    {"instance": "Karazhan Crypts", "kind": "dungeon", "name": "The Depths of Karazhan",
     "final": {"Horde": 40310},
     "note": "Turtle WoW's crypts beneath Karazhan: the Karazhan Crypt Key lets you in"},
]

# Each side's cities: where its chains are taken up from.
CAPITALS = {"Alliance": ["Stormwind City", "Ironforge", "Darnassus"],
            "Horde": ["Orgrimmar", "Undercity", "Thunder Bluff"]}

# The ways into Turtle WoW's own raids and dungeons the dungeon guides do not
# give: the zone its door is in, where, and what the step says.
DOORS = {
    "Emerald Sanctum": ("Hyjal", None, "The sanctum in Hyjal"),
    "Lower Karazhan Halls": ("Deadwind Pass", None, "Karazhan, the tower in Deadwind Pass"),
    "Karazhan": ("Deadwind Pass", None, "Karazhan, the tower in Deadwind Pass"),
    "Karazhan Crypts": ("Deadwind Pass", None, "The crypts beneath Karazhan, in Deadwind Pass"),
}


# Where the data puts someone wrong, or nowhere: pfQuest-turtle has Stormwind
# Keep on Northwind's map, and Reginald Windsor only appears for his walk to
# the Keep, from the gates of Stormwind.
SPOTS = {
    "Highlord Bolvar Fordragon": ("Stormwind City", [78.2, 18.0]),
    "Reginald Windsor": ("Stormwind City", [69.7, 86.1]),
}


# --------------------------------------------------------------------------
# Reading the data
# --------------------------------------------------------------------------

def collect(pfquest, turtle, cmangos):
    """Each attunement's chain per side, and what the guides need of each
    quest in them."""
    from build_zone_guide import Data, Quest, entries, parse, seq, clusters
    from build_gathering import Dump
    data = Data(turtle, pfquest)
    tq = entries(Data.path(turtle, "quests", "-turtle"))
    removed = {q for q, t in tq.items() if t is None}
    for q, t in entries(Data.path(pfquest, "quests", "")).items():
        if t and q not in removed:
            data.quests[q] = dict(parse(t), **data.quests.get(q, {}))
    tt = entries(Data.path(turtle, "quests", "-turtle", True))
    for q, t in entries(Data.path(pfquest, "quests", "", True)).items():
        if t and q not in tt:
            data.text[q] = {k: v for k, v in parse(t).items() if isinstance(v, str)}

    db = Dump(cmangos)
    cm = {int(r["entry"]): r for r in db.rows("quest_template")}
    items = {int(r["entry"]): (r["name"], int(r["Quality"])) for r in db.rows("item_template")}

    def cmi(q, key):
        r = cm.get(q)
        return int(r.get(key) or 0) if r else 0

    cfg = {"text": {}, "pre": {}, "spots": {}, "npc": {}, "places": [], "skip": set()}
    objs = {}

    def quest(q):
        if q not in objs:
            objs[q] = Quest(data, q, 0, cfg) if q in data.quests and q not in removed else None
        return objs[q]

    def before(q):
        t = data.quests.get(q) or {}
        out = [p for p in seq(t.get("pre")) if isinstance(p, int)]
        prev = abs(cmi(q, "PrevQuestId"))
        if prev and prev not in out:
            out.append(prev)
        return [p for p in out if p != q]

    can = {}

    def gettable(q, mask):
        """Whether a side can get quest q: someone or something starts it,
        its races allow the side, and a quest before it is gettable."""
        key = (q, mask)
        if key in can:
            return can[key]
        can[key] = False      # a loop in the data is not gettable
        qo = quest(q)
        ok = bool(qo) and bool(qo.starters or qo.start_items)
        race = (data.quests.get(q) or {}).get("race") or 0
        if ok and race and not race & mask:
            ok = False
        pres = before(q)
        if ok and pres and not any(gettable(p, mask) for p in pres):
            ok = False
        can[key] = ok
        return ok

    def one_of(pres, side):
        """Quests of which only one can be done (a CMaNGOS exclusive group:
        "A Call to Arms" from each city) as the one given in the side's
        first city."""
        out, groups = [], {}
        for p in pres:
            g = cmi(p, "ExclusiveGroup")
            if g > 0:
                groups.setdefault(g, []).append(p)
            else:
                out.append(p)
        caps = CAPITALS[side]

        def rank(p):
            zones = [z for k, i in quest(p).starters for z in cg.place(data, k, i)["at"]]
            return (min([caps.index(z) for z in zones if z in caps] or [len(caps)]), p)
        return out + [min(ps, key=rank) for ps in groups.values()]

    model = {"quests": {}, "chains": {}}
    for a in ATTUNEMENTS:
        for side, mask in SIDES:
            final = a["final"].get(side)
            if not final:
                continue
            if not gettable(final, mask):
                sys.exit("%s (%s): quest %d cannot be got" % (a["name"], side, final))
            chain, todo = set(), [final]
            while todo:
                q = todo.pop()
                if q in chain:
                    continue
                chain.add(q)
                todo += one_of([p for p in before(q) if gettable(p, mask)], side)
            model["chains"].setdefault(key_of(a), {})[side] = sorted(chain)
            for q in chain:
                if str(q) in model["quests"]:
                    continue
                qo, t = quest(q), data.quests[q]
                rewards = [cmi(q, "RewItemId%d" % i) for i in range(1, 5)] + \
                          [cmi(q, "RewChoiceItemId%d" % i) for i in range(1, 7)]
                src = cmi(q, "SrcItemId")
                need = {cmi(q, "ReqItemId%d" % i) for i in range(1, 5)} | set(qo.obj["I"])
                model["quests"][str(q)] = {
                    "gives": [i for i in rewards if i], "need": sorted(i for i in need if i),
                    "src": src if src and re.match(r"(Use|Using)\b", qo.objective or "") else 0,
                    "title": qo.title, "min": qo.min, "lvl": qo.lvl, "race": qo.race,
                    "pre": before(q),
                    "prev": cmi(q, "PrevQuestId"), "next": cmi(q, "NextQuestInChain"),
                    "type": cmi(q, "Type"), "turtle": q not in cm,
                    "rewards": [items[i][0] for i in rewards if i and items.get(i, ("", 0))[1] >= 3],
                    "doing": qo.needs_c, "task": qo.task() if qo.needs_c else "", "text": qo.objective,
                    "givers": [cg.place(data, k, i) for k, i in qo.starters],
                    "items": [{"id": i, "name": data.name("I", i),
                               "from": [cg.place(data, k, j) for k, j in data.drops(i)[:6]]}
                              for i in qo.start_items],
                    "takers": [cg.place(data, k, i) for k, i in qo.enders],
                    "obj": cg.objective_spots(data, qo, clusters),
                }
    return model


def key_of(a):
    return "%s: %s" % (a["instance"], a["name"])


def load(path=CACHE):
    with open(path, encoding="utf-8") as f:
        raw = json.load(f)
    raw["quests"] = {int(q): t for q, t in raw["quests"].items()}
    return raw


# --------------------------------------------------------------------------
# Writing the guides
# --------------------------------------------------------------------------

class AttunementGuide(cg.ClassGuide):
    """One attunement's guide for one side: the class quest guides' steps,
    with no class, taken up from the side's cities."""

    def __init__(self, quests, after, before, side, doors):
        super().__init__(quests, after, before, {"side": side, "class": None, "races": {}}, doors)

    def home(self, races):
        return CAPITALS[self.m["side"]]


def chain_links(quests, chain):
    """q -> the quests of the chain straight after it, and straight before."""
    inside = set(chain)
    after, before = {}, {}
    for q in chain:
        t = quests[q]
        for p in set(t["pre"]) | ({abs(t["prev"])} if t["prev"] else set()):
            if p in inside and p != q:
                after.setdefault(p, set()).add(q)
                before.setdefault(q, set()).add(p)
    return after, before


def in_order(quests, chain, before):
    """The chain's quests, each after those before it: the lowest level, then
    the lowest id, first."""
    left, done, out = set(chain), set(), []
    while left:
        ready = [q for q in left if before.get(q, set()) <= done] or list(left)
        q = min(ready, key=lambda x: (quests[x]["min"], x))
        out.append(q)
        done.add(q)
        left.remove(q)
    return out


def guide_name(a, level):
    return "Attunement/%s: %s (%d)" % (a["instance"], a["name"], level)


def describe(a, quests, seq):
    n = len(seq)
    text = "Opens %s. %d quest%s" % (a["instance"], n, "" if n == 1 else "s")
    text += ", from level %d" % min(quests[q]["min"] for q in seq)
    return text + ". " + a["note"] + "."


def side_file(side, quests, chains, doors):
    body = ["-- Attunement guides: %s" % side,
            "-- Written by Tools/build/build_attunement_guides.py from pfQuest, pfQuest-turtle and CMaNGOS: "
            "do not edit it here.", ""]
    register = []
    for a in ATTUNEMENTS:
        chain = chains.get(key_of(a), {}).get(side)
        if not chain:
            continue
        after, before = chain_links(quests, chain)
        seq = in_order(quests, chain, before)
        level = min(quests[q]["min"] for q in seq)
        name = guide_name(a, level)
        guide = AttunementGuide(quests, after, before, side, doors)
        lines = guide.plan(seq, [])
        body += ['AegisPathfinder:RegisterGuide("%s", nil, "%s", function()' % (name, side), "",
                 "return [[", "",
                 # Read, not ticked: the guide opens at its first quest.
                 "N %s |N|%s| |O|" % (a["name"], describe(a, quests, seq)), ""]
        body += lines
        body += ["", "]]", "end)", ""]
        attuned = [a["final"][side]] + a.get("attuned", [])
        register.append('\t{ guide = "%s", instance = "%s", kind = "%s", level = %d, attuned = { %s } },' % (
            name, a["instance"], a["kind"], level, ", ".join(str(q) for q in attuned)))
    body.append('AegisPathfinder:RegisterAttunements("%s", {' % side)
    body += register
    body += ["})", ""]
    return "\n".join(body)


def corrected(quests):
    """The quests with SPOTS' people where SPOTS puts them."""
    out = {}
    for q, t in quests.items():
        t = dict(t)
        for key in ("givers", "takers"):
            t[key] = [dict(p, at={SPOTS[p["name"]][0]: SPOTS[p["name"]][1]}) if p["name"] in SPOTS else p
                      for p in t[key]]
        out[q] = t
    return out


def write_all(model, check=False):
    quests, chains = corrected(model["quests"]), model["chains"]
    chains = {k: {s: [int(q) for q in v] for s, v in sides.items()} for k, sides in chains.items()}
    doors = cg.entrances()
    doors.update(DOORS)
    files = {}
    for side, _ in SIDES:
        files[os.path.join(OUT, side, "Attunements.lua")] = side_file(side, quests, chains, doors)
        xml = ['<Ui xmlns="http://www.blizzard.com/wow/ui/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
               'xsi:schemaLocation="http://www.blizzard.com/wow/ui/\n..\\FrameXML\\UI.xsd">',
               "\t<!-- %s attunement guides: written by Tools/build/build_attunement_guides.py -->" % side,
               '\t<Script file="Attunements.lua"/>', "</Ui>", ""]
        files[os.path.join(OUT, side, "Guides.xml")] = "\n".join(xml)
    stale = []
    for path, text in sorted(files.items()):
        old = open(path, encoding="utf-8").read() if os.path.exists(path) else None
        if old == text:
            continue
        if check:
            stale.append(os.path.relpath(path, ROOT))
        else:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(text)
            print("wrote %s" % os.path.relpath(path, ROOT))
    for side, _ in SIDES:
        for path in glob.glob(os.path.join(OUT, side, "*")):
            if path not in files:
                stale.append(os.path.relpath(path, ROOT) + " (not written any more)")
    if stale:
        sys.exit("out of date: %s -- run python3 Tools/build/build_attunement_guides.py" % ", ".join(stale))


def listing(model):
    quests = model["quests"]
    for a in ATTUNEMENTS:
        for side, chain in sorted(model["chains"].get(key_of(a), {}).items()):
            chain = [int(q) for q in chain]
            _, before = chain_links(quests, chain)
            seq = in_order(quests, chain, before)
            print("%-48s %-8s %2d  %s" % (key_of(a), side, min(quests[q]["min"] for q in seq),
                                         ", ".join("%d %s" % (q, quests[q]["title"]) for q in seq)))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--pfquest")
    ap.add_argument("--pfquest-turtle")
    ap.add_argument("--cmangos")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--list", action="store_true")
    a = ap.parse_args()
    if a.pfquest or a.pfquest_turtle or a.cmangos:
        if not (a.pfquest and a.pfquest_turtle and a.cmangos):
            sys.exit("--pfquest, --pfquest-turtle and --cmangos go together")
        model = collect(a.pfquest, a.pfquest_turtle, a.cmangos)
        with open(CACHE, "w", encoding="utf-8") as f:
            json.dump(model, f, indent=1, sort_keys=True, ensure_ascii=False)
            f.write("\n")
        print("wrote %s: %d quests in %d chains" % (os.path.relpath(CACHE, ROOT), len(model["quests"]),
                                                     sum(len(v) for v in model["chains"].values())))
    model = load()
    if a.list:
        listing(model)
    else:
        write_all(model, a.check)


if __name__ == "__main__":
    main()
