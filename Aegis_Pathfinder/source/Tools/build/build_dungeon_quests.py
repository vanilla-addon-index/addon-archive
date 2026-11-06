#!/usr/bin/env python3
"""Which dungeon quests each route actually leads you through, and so which
dungeons to recommend.

    python3 Tools/build/build_dungeon_quests.py                 # audit, write DungeonQuests.lua
    python3 Tools/build/build_dungeon_quests.py --report        # and say what fails, and why
    python3 Tools/build/build_dungeon_quests.py --check         # fail if DungeonQuests.lua is stale
    python3 Tools/build/build_dungeon_quests.py --cmangos FILE --pfquest-turtle DIR
                                                          # refresh the quest rules first

The first-time setup recommends dungeons, and says how many quests each adds.
A quest only counts if the guide takes you all the way: for the route pack
you picked and your race's route through it (Routes/Routes.lua -- the guide
after one on your route is the route's next leg), with just that dungeon
ticked, and reading each guide as Parser.lua does (only the first accept and
the first hand-in of a quest in a guide are kept), the guide

  - sends you to pick it up: an ACCEPT step you are shown, and not an
    optional one nothing will ever bring up;
  - has you hand in, first, a quest the server wants done before it -- and
    that one's own, all the way back -- or, where the server wants a quest
    in your log instead, has you pick that one up and keep it;
  - never has you take a quest that locks it out (the server's exclusive
    groups);
  - sends you to hand it in, after picking it up;
  - is for your race, and for every class: a quest that needs a class, or a
    step only one class is shown, is not counted.

"The server" is the quest rules of CMaNGOS classic-db -- quest_template's
PrevQuestId, NextQuestId and ExclusiveGroup, read as the core reads them
(ObjectMgr::LoadQuests and Player::SatisfyQuestPreviousQuest) -- for the
original quests, and pfQuest-turtle's for Turtle WoW's own; a quest Turtle
removed counts as missing. Those rules, for every quest a guide mentions and
the quests before them, are kept in Tools/data/quest_rules.json, so the audit
itself needs neither database; --cmangos and --pfquest-turtle rebuild it.

A quest whose chain runs through another dungeon's quests -- the Stockade's
Onyxia chain starts with the Deadmines' Bazil Thredd -- counts with that one
ticked too, and is written { id, "DM" }. A dungeon is recommended when
ticking it adds RECOMMEND or more quests, those included once the dungeons
they need are recommended as well (SetupFrame.lua).

--report lists every tagged quest that does not count, and why: the place to
start when a guide is to take you through more of a dungeon.
"""

import argparse
import glob
import gzip
import json
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RULES = os.path.join(ROOT, "Tools", "data", "quest_rules.json")
OUT = os.path.join(ROOT, "DungeonQuests.lua")

RECOMMEND = 5

# The dungeons the setup offers (SetupFrame.lua's DUNGEONS), by tag code.
DUNGEONS = ["RFC", "WC", "DM", "SFK", "STOCKADES", "BFD", "GNOMER", "RFK", "SM",
            "RFD", "ULDA", "ZF", "MARA", "ST", "BRD"]

# A route's race key -> what UnitRace calls it (Parser.lua matches |R| on
# that), and its bit in a quest's race mask.
RACES = {
    "Human": ("Human", 1), "Orc": ("Orc", 2), "Dwarf": ("Dwarf", 4),
    "NightElf": ("Night Elf", 8), "Undead": ("Undead", 16), "Tauren": ("Tauren", 32),
    "Gnome": ("Gnome", 64), "Troll": ("Troll", 128), "Goblin": ("Goblin", 256),
    "HighElf": ("High Elf", 512),
}
ALLIANCE = {"Human", "Dwarf", "Gnome", "NightElf", "HighElf"}
VANILLA_ALLIANCE, VANILLA_HORDE = 1 | 4 | 8 | 64, 2 | 16 | 32 | 128


# --------------------------------------------------------------------------
# The quest rules
# --------------------------------------------------------------------------

def read_cmangos(path):
    """quest_template, the columns that decide who can take a quest."""
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from build_gathering import Dump
    db = Dump(path)
    out = {}
    for r in db.rows("quest_template"):
        q = int(r["entry"])
        out[q] = {
            "title": r["Title"], "prev": int(r["PrevQuestId"] or 0), "next": int(r["NextQuestId"] or 0),
            "group": int(r["ExclusiveGroup"] or 0), "races": int(r["RequiredRaces"] or 0),
            "classes": int(r["RequiredClasses"] or 0),
        }
    return out


def read_turtle(pf):
    """pfQuest-turtle's quests: {id: dict} and the ids it removed."""
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from build_zone_guide import entries, parse, seq, names
    quests, removed = {}, set()
    for q, t in entries(os.path.join(pf, "db", "quests-turtle.lua")).items():
        if t is None:
            removed.add(q)
        else:
            quests[q] = parse(t)
    titles = {}
    for q, t in entries(os.path.join(pf, "db", "enUS", "quests-turtle.lua")).items():
        if t:
            m = re.search(r'\["T"\]\s*=\s*"((?:\\.|[^"\\])*)"', t)
            if m:
                titles[q] = re.sub(r"\\(.)", r"\1", m.group(1))
    return quests, removed, titles, seq


def turtle_races(mask):
    """A vanilla race mask with Turtle WoW's races: a quest for every
    Alliance race is for High Elves too, one for every Horde race for
    Goblins."""
    if mask and mask & VANILLA_ALLIANCE == VANILLA_ALLIANCE:
        mask |= 512
    if mask and mask & VANILLA_HORDE == VANILLA_HORDE:
        mask |= 256
    return mask


def build_rules(cmangos, turtle):
    """Every quest's rules as the server reads them: {id: {prev: [signed
    ids, any one will do], group, races, classes, title, removed}}."""
    core = read_cmangos(cmangos)
    tq, removed, titles, seq = read_turtle(turtle)
    rules = {}
    for q, r in core.items():
        rules[q] = {"title": r["title"], "prev": [], "group": r["group"],
                    "races": turtle_races(r["races"]), "classes": r["classes"]}
    # ObjectMgr::LoadQuests: a quest's PrevQuestId, and every quest whose
    # NextQuestId names it (negative: that one must be in your log).
    for q, r in core.items():
        if r["prev"]:
            rules[q]["prev"].append(r["prev"])
        if r["next"] and abs(r["next"]) in rules:
            rules[abs(r["next"])]["prev"].append(q if r["next"] > 0 else -q)
    # Turtle WoW's own quests, from its pfQuest data: any one of ["pre"].
    for q, t in tq.items():
        if q in rules:
            continue
        rules[q] = {"title": titles.get(q, "Quest %d" % q),
                    "prev": [p for p in seq(t.get("pre")) if isinstance(p, int)],
                    "group": 0, "races": t.get("race") or 0, "classes": t.get("class") or 0}
    for q in removed:
        if q in rules:
            rules[q]["removed"] = True
        else:
            rules[q] = {"title": "Quest %d" % q, "prev": [], "group": 0, "races": 0, "classes": 0, "removed": True}
    return rules


def keep_rules(rules, wanted):
    """The rules for the quests the guides mention, the quests before them,
    and their exclusive groups' other quests."""
    keep, todo = set(), [q for q in wanted if q in rules]
    while todo:
        q = todo.pop()
        if q in keep:
            continue
        keep.add(q)
        todo += [abs(p) for p in rules[q]["prev"] if abs(p) in rules]
    groups = {rules[q]["group"] for q in keep if rules[q]["group"]}
    keep |= {q for q, r in rules.items() if r["group"] in groups}
    return {str(q): rules[q] for q in sorted(keep)}


# --------------------------------------------------------------------------
# The guides and routes
# --------------------------------------------------------------------------

STEP = re.compile(r"^(\w) ([^|]*)(.*)$")


def read_guides():
    """(name, faction) -> [step], each step (action, qid, tags), in order."""
    guides = {}
    for path in sorted(glob.glob(os.path.join(ROOT, "Guides", "**", "*.lua"), recursive=True)):
        text = open(path, encoding="utf-8", errors="replace").read()
        m = re.search(r'RegisterGuide\("([^"]+)",\s*(?:nil|"[^"]*"),\s*"(\w+)"', text)
        body = re.search(r"return \[\[(.*?)\]\]", text, re.S)
        if not m or not body:
            continue
        steps = []
        for line in body.group(1).splitlines():
            s = STEP.match(line.strip())
            if not s:
                continue
            tags = s.group(3)
            qid = re.search(r"\|QID\|(\d+)\|", tags)
            steps.append((s.group(1), int(qid.group(1)) if qid else None, tags))
        guides[(m.group(1), m.group(2))] = steps
    return guides


def read_routes():
    """pack -> race -> [guide name], as Routes/Routes.lua registers them."""
    script = r'''
AegisPathfinder = { packs = {} }
function AegisPathfinder:RegisterRoute() end
function AegisPathfinder:RegisterRoutePack(name, pack) self.packs[name] = pack end
dofile("Routes/Routes.lua")
for name, pack in pairs(AegisPathfinder.packs) do
  for race, route in pairs(pack.routes or {}) do
    for i, leg in ipairs(route) do print(name .. "\t" .. race .. "\t" .. i .. "\t" .. leg.guide) end
  end
end
'''
    with tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False) as fh:
        fh.write(script)
    try:
        out = subprocess.run(["lua5.1", fh.name], cwd=ROOT, capture_output=True, text=True, check=True).stdout
    finally:
        os.unlink(fh.name)
    routes = {}
    for line in out.splitlines():
        pack, race, i, guide = line.split("\t")
        routes.setdefault(pack, {}).setdefault(race, []).append((int(i), guide))
    return {p: {r: [g for _, g in sorted(legs)] for r, legs in races.items()} for p, races in routes.items()}


def tag(tags, name):
    m = re.search(r"\|%s\|([^|]*)\|" % name, tags)
    return m.group(1) if m else None


def race_ok(filt, race):
    """Parser.lua's matchFilter."""
    if filt is None:
        return True
    matches = negations = False
    for sp in filt.split("/"):
        if sp.startswith("!"):
            negations = True
            if sp[1:] == race:
                return False
        elif sp == race:
            matches = True
    return matches or negations


def dungeon_ok(filt, ticked):
    """Parser.lua's matchDungeonFilter, with the dungeons in `ticked` ticked
    and no others."""
    if filt is None:
        return True
    matches = negations = False
    for sp in filt.split("/"):
        neg = sp.startswith("!")
        code = (sp[1:] if neg else sp).upper()
        if neg:
            negations = True
            if code in ticked:
                return False
        elif code in ticked:
            matches = True
    return matches or negations


def dungeons_of(tags):
    filt = tag(tags, "D")
    return {sp.upper() for sp in filt.split("/") if not sp.startswith("!")} if filt else set()


def visible(tags, race, ticked):
    """Whether a step is shown to this race, whatever the class, in Group
    mode, with the dungeons in `ticked` ticked."""
    cls = tag(tags, "C")
    if cls and any(not c.startswith("!") for c in cls.split("/")):
        return False
    playstyle = tag(tags, "P")
    if playstyle and playstyle.upper() != "GROUP":
        return False
    return race_ok(tag(tags, "R"), race) and dungeon_ok(tag(tags, "D"), ticked)


def route_steps(guides, names, faction):
    """A route's steps in order, each guide once, as the addon loads them."""
    out, seen = [], set()
    for name in names:
        if name in seen:
            continue
        seen.add(name)
        steps = guides.get((name, faction)) or guides.get((name, "Both")) or []
        out += [dict(action=a, qid=q, tags=t, guide=name) for a, q, t in steps]
    return out


# --------------------------------------------------------------------------
# The audit
# --------------------------------------------------------------------------

class Audit:
    def __init__(self, rules, steps, race):
        self.rules, self.race = rules, race
        self.name, self.bit = RACES[race]
        self.steps = steps

    def tick(self, ticked):
        """Show the steps the guide shows with these dungeons ticked -- and,
        as Parser.lua does, only the first accept and the first hand-in of
        each quest in a guide: a later one is dropped as a duplicate."""
        shown, seen = [], set()
        for s in self.steps:
            if not visible(s["tags"], self.name, ticked):
                continue
            if s["action"] in ("A", "T") and s["qid"] is not None:
                key = (s["guide"], s["action"], s["qid"])
                if key in seen:
                    continue
                seen.add(key)
            shown.append(s)
        self.shown = shown
        self.accepts, self.turnins = {}, {}
        for i, s in enumerate(shown):
            if s["qid"] is None:
                continue
            if s["action"] == "A" and s["qid"] not in self.accepts:
                optional = "|O|" in s["tags"]
                prompted = tag(s["tags"], "PRE") or tag(s["tags"], "U") or tag(s["tags"], "L")
                if not optional or prompted:
                    self.accepts[s["qid"]] = i
            elif s["action"] == "T":
                self.turnins.setdefault(s["qid"], []).append(i)

    def run(self, code):
        """The quests tagged for this dungeon: [(q, needs)] the guide takes
        you through -- `needs` the other dungeons whose steps it takes, which
        must be ticked too -- and [(q, why)] it does not."""
        self.tick({code})
        tagged = []
        for s in self.shown:
            if s["qid"] and code in dungeons_of(s["tags"]) and s["qid"] not in tagged:
                tagged.append(s["qid"])
        good, bad = [], []
        for q in tagged:
            self.tick({code})
            why = self.problem(q)
            if not why:
                good.append((q, ()))
                continue
            # A chain that runs through another dungeon's quests -- the
            # Stockade's, from the Deadmines' Bazil Thredd -- works with that
            # one ticked too. As few others as will do.
            others = sorted(self.chain_codes(q) - {code})
            self.tick({code} | set(others))
            if not others or self.problem(q):
                bad.append((q, why))
                continue
            for o in list(others):
                trial = [c for c in others if c != o]
                self.tick({code} | set(trial))
                if not self.problem(q):
                    others = trial
            good.append((q, tuple(others)))
        return good, bad

    def chain_codes(self, q, seen=None):
        """The dungeons whose tags are on the steps of the quests before q."""
        seen = seen if seen is not None else set()
        codes = set()
        r = self.rule(q)
        for p in (r["prev"] if r else []):
            p = abs(p)
            if p in seen:
                continue
            seen.add(p)
            for s in self.steps:
                if s["qid"] == p:
                    codes |= dungeons_of(s["tags"])
            codes |= self.chain_codes(p, seen)
        return codes

    def rule(self, q):
        return self.rules.get(str(q))

    def title(self, q):
        r = self.rule(q)
        return r["title"] if r else "quest %d" % q

    def problem(self, q, before=None, depth=0):
        """Why the guide does not take you through quest q (picked up before
        step `before`, if given), or None."""
        r = self.rule(q)
        if r is None:
            return "%d is in no quest database" % q
        if r.get("removed"):
            return "%s (%d) is not on Turtle WoW" % (r["title"], q)
        if r["races"] and not r["races"] & self.bit:
            return "%s (%d) is not for %s" % (r["title"], q, self.name)
        if r["classes"]:
            return "%s (%d) is for one class" % (r["title"], q)
        a = self.accepts.get(q)
        if a is None:
            return "%s (%d) is never picked up" % (r["title"], q)
        if before is not None and a >= before:
            return "%s (%d) is picked up too late" % (r["title"], q)
        if depth == 0 and self.handed_in(q, a) is None:
            return "%s (%d) is never handed in" % (r["title"], q)
        if depth > 12:
            return None
        # Locked out by a quest of its exclusive group taken first.
        if r["group"] > 0:
            for other, orule in self.rules.items():
                o = int(other)
                if o != q and orule["group"] == r["group"] and self.accepts.get(o, a) < a:
                    return "%s (%d) is locked out by %s (%d), taken first" % (r["title"], q, orule["title"], o)
        if not r["prev"]:
            return None
        # Any one of its previous quests will do.
        reasons = []
        for p in r["prev"]:
            pq = abs(p)
            if p > 0:
                pa = self.accepts.get(pq)
                t = self.handed_in(pq, pa) if pa is not None else None
                if t is None or t >= a:
                    reasons.append("%s (%d) is not handed in first" % (self.title(pq), pq))
                    continue
                why = self.problem(pq, a, depth + 1)
                if not why:
                    why = self.group_done(pq, a)
                if not why:
                    return None
                reasons.append(why)
            else:
                pa = self.accepts.get(pq)
                pt = self.handed_in(pq, pa) if pa is not None else None
                if pa is None or pa >= a or (pt is not None and pt < a):
                    reasons.append("%s (%d) is not in your log when it is picked up" % (self.title(pq), pq))
                    continue
                why = self.problem(pq, a, depth + 1)
                if not why:
                    return None
                reasons.append(why)
        return "; or ".join(reasons)

    def handed_in(self, q, after):
        """The first hand-in of q after step `after`, or None."""
        for t in self.turnins.get(q, []):
            if t > after:
                return t
        return None

    def group_done(self, q, before):
        """A negative exclusive group wants all of its quests done."""
        g = self.rule(q)["group"]
        if g >= 0:
            return None
        for other, orule in self.rules.items():
            if orule["group"] == g:
                o = int(other)
                oa = self.accepts.get(o)
                t = self.handed_in(o, oa) if oa is not None else None
                if t is None or t >= before:
                    return "%s (%d), in the same set, is not handed in first" % (orule["title"], int(other))
        return None


def audit(rules, guides, routes):
    """pack -> race -> code -> (good [(q, None)], bad [(q, why)])."""
    out = {}
    for pack in sorted(routes):
        for race in sorted(routes[pack]):
            if race not in RACES:
                continue
            faction = "Alliance" if race in ALLIANCE else "Horde"
            a = Audit(rules, route_steps(guides, routes[pack][race], faction), race)
            for code in DUNGEONS:
                good, bad = a.run(code)
                if good or bad:
                    out.setdefault(pack, {}).setdefault(race, {})[code] = (good, bad)
    return out


def lua(results):
    lines = [
        "-- Written by Tools/build/build_dungeon_quests.py: do not edit. For each route",
        "-- pack and race, the dungeon quests the route takes you all the way",
        "-- through with that dungeon ticked -- picked up, what comes before them",
        "-- done first, handed in -- and so the dungeons worth recommending. A",
        "-- quest written { id, CODE, ... } needs those dungeons ticked as well.",
        "AegisPathfinder.DUNGEON_QUESTS = {",
    ]
    for pack in sorted(results):
        lines.append("\t[%s] = {" % json.dumps(pack))
        for race in sorted(results[pack]):
            codes = results[pack][race]
            cells = ["%s = { %s }" % (code, ", ".join(
                        str(q) if not needs else "{ %d, %s }" % (q, ", ".join(json.dumps(n) for n in needs))
                        for q, needs in codes[code][0]))
                     for code in DUNGEONS if code in codes and codes[code][0]]
            lines.append("\t\t%s = { %s }," % (race, ", ".join(cells)))
        lines.append("\t},")
    lines += ["}", "AegisPathfinder.DUNGEON_RECOMMEND = %d" % RECOMMEND, ""]
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--cmangos", help="CMaNGOS classic-db dump (.sql or .sql.gz), to rebuild the quest rules")
    ap.add_argument("--pfquest-turtle", help="a pfQuest-turtle checkout, to rebuild the quest rules")
    ap.add_argument("--report", action="store_true", help="say what fails, and why")
    ap.add_argument("--check", action="store_true", help="fail if DungeonQuests.lua is not what it would write")
    args = ap.parse_args()

    guides = read_guides()
    routes = read_routes()
    if args.cmangos or args.pfquest_turtle:
        if not (args.cmangos and args.pfquest_turtle):
            sys.exit("--cmangos and --pfquest-turtle go together")
        wanted = {q for steps in guides.values() for _, q, _ in steps if q}
        rules = keep_rules(build_rules(args.cmangos, args.pfquest_turtle), wanted)
        with open(RULES, "w") as fh:
            json.dump(rules, fh, indent=0, sort_keys=True)
            fh.write("\n")
        print("wrote %s: %d quests" % (os.path.relpath(RULES, ROOT), len(rules)))
    rules = json.load(open(RULES))

    results = audit(rules, guides, routes)
    if args.report:
        for pack in sorted(results):
            for race in sorted(results[pack]):
                for code in DUNGEONS:
                    good, bad = results[pack][race].get(code, ([], []))
                    if not good and not bad:
                        continue
                    print("%s / %s / %s: %d of %d" % (pack, race, code, len(good), len(good) + len(bad)))
                    for q, needs in good:
                        if needs:
                            print("    + %s (%d) with %s" % (rules[str(q)]["title"], q, "/".join(needs)))
                    for q, why in bad:
                        print("    %s" % why)
    text = lua(results)
    old = open(OUT, encoding="utf-8").read() if os.path.exists(OUT) else None
    if args.check:
        if old != text:
            sys.exit("DungeonQuests.lua is out of date: run python3 Tools/build/build_dungeon_quests.py")
        return
    if old != text:
        with open(OUT, "w", encoding="utf-8") as fh:
            fh.write(text)
        print("wrote DungeonQuests.lua")


if __name__ == "__main__":
    main()
