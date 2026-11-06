#!/usr/bin/env python3
"""Write a custom zone's guide from a pfQuest-turtle checkout.

    python3 Tools/build/build_zone_guide.py --pfquest-turtle DIR --pfquest DIR
        [--zone "Moonwhisper Coast"] [--dump] [--check]

Reads the zone's quests out of pfQuest's data -- who gives each one, who takes
it back, what it asks for and where, the quests before it, the levels and the
races -- and writes a guide per side into Guides/<side>/, in the DSL of
docs/GUIDE_AUTHORING.md. --dump prints the quests instead; --check fails when
the committed guides differ from what it would write.

The route is worked out the way the authoring notes order a zone by hand:

  1. A quest's turn-in comes before any quest that needs it (["pre"]); its
     accept before its objectives before its turn-in.
  2. You arrive at the bottom of the range and leave at the top. The level
     climbs as quests are handed in, and a quest's objectives wait until you
     are within AHEAD levels of it.
  3. At a quest giver, everything that can be handed in and picked up there
     is, before moving on; then the nearest thing to do next -- a quest's
     objectives, a hand-in or a quest to pick up -- where a place with more to
     do there counts as nearer.
  4. A quest that sends you out of the zone and back waits until the zone has
     nothing left without it; everything else in that zone is done on the
     same trip. A quest that only ends outside the zone is picked up last and
     handed in on the way out -- or on a trip already going there.

What the data cannot give -- the names of places, which quest follows which
where the data has no ["pre"], where objectives are that it has no spawns
for, which quests want a group -- is in ZONES, under the zone, so that running
this again over a newer checkout keeps it. Anything the route still has no
place for is printed as it writes.

Moonwhisper Coast's data is ryanmr82's pfQuest-turtle fork
(https://github.com/ryanmr82/pfQuest-turtle), built from captures players send
in, and still growing: run this again over a newer checkout now and then.
pfQuest (https://github.com/shagu/pfQuest) is read for the NPCs outside the
zone that send you there and take quests back.
"""

import argparse
import math
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# pfQuest's race masks: each side's playable races, High Elves and Goblins
# included.
ALLIANCE, HORDE = 1 | 4 | 8 | 64 | 512, 2 | 16 | 32 | 128 | 256
SIDES = (("Alliance", ALLIANCE), ("Horde", HORDE))
CLASSES = ((1, "Warrior"), (2, "Paladin"), (4, "Hunter"), (8, "Rogue"),
           (16, "Priest"), (64, "Shaman"), (128, "Mage"), (256, "Warlock"),
           (1024, "Druid"))
ALL_CLASSES = 1 | 2 | 4 | 8 | 16 | 64 | 128 | 256 | 1024
# As UnitRace names them, which is what Parser.lua matches |R| against.
RACES = ((1, "Human"), (2, "Orc"), (4, "Dwarf"), (8, "Night Elf"), (16, "Undead"),
         (32, "Tauren"), (64, "Gnome"), (128, "Troll"), (256, "Goblin"),
         (512, "High Elf"))

HUB = 3.0        # map units (0-100): two NPCs this close stand together
SPOT = 6.0       # spawns this close are one place to go
MAX_SPOTS = 3    # places a C step names at most
PLACE = 5.0      # an NPC this close to a named place is "at" it
AHEAD = 2        # levels above yours a quest's objectives are worth doing

# The first word of a quest's objective text when it asks for more than
# walking to whoever takes it back.
DOING = {"Slay", "Kill", "Collect", "Gather", "Recover", "Retrieve", "Use",
         "Free", "Silence", "Defend", "Hunt", "Investigate", "Behold", "Face",
         "Pursue", "Acquire", "Search", "Enter", "Listen", "Locate", "Travel",
         "Find", "Bring", "Return", "Deliver", "Get", "Obtain", "Destroy"}

# Its first word when all it asks is to go to the one who takes it back.
GOING = {"Deliver", "Bring", "Take", "Return", "Seek", "Report", "Speak",
         "Talk", "Travel", "Find", "Introduce", "Confront"}
# Its first word when what it asks happens where you get it: a talk, a fight.
EVENT = {"Listen", "Behold", "Face", "Defend", "Protect", "Escort", "Watch"}
# Words in an NPC's name that do not name them.
TITLES = {"Elder", "Chief", "Master", "Sentinel", "Commander", "Arch", "Druid",
          "Keeper", "Sister", "Brave", "Farmer", "Huntress", "Cook", "Fisher",
          "Trader", "Herbalist", "Innkeeper", "Matron", "Grovetender",
          "Groundstender", "Riftmaster", "Craftsman", "Arcanist", "Naturalist",
          "Pumpworker", "Defender", "Sage", "Lady", "Lord", "High", "Priestess",
          "Duke", "Bloodhoof", "Younger", "Wise", "Forgotten"}
LOG = 18         # quests in the log at once, of the 20 it holds

ZONES = {
    "Moonwhisper Coast": {
        "levels": (52, 60),
        "file": "52_60_Moonwhisper_Coast",
        "next": "Winterspring (59-60)",
        # Where the route begins: Moro'gai Village, the neutral draenei town
        # the zone's breadcrumb sends you to.
        "start": (62.5, 66.2),
        "intro": ("Moonwhisper Coast, north of Azshara, came with patch 1.18.1. "
                  "Moro'gai Village, the draenei town on Shimmerstar Lake, has "
                  "quests for both sides; {camps}."),
        "camps": {
            "Alliance": "the Alliance camps are Sunsworn Camp, just south-west of it, "
                        "and Narvalis Point in the west",
            "Horde": "the Horde's are Moonhoof Village in the north-east and "
                     "Moonhoof Retreat in the north",
        },
        "arrive": "Travel north through Azshara to Moonwhisper Coast, and on to Moro'gai Village",
        # Named from the quests' own text: the NPCs and mobs a quest places
        # somewhere, and where they stand.
        "places": [
            (62.8, 66.3, "Moro'gai Village"),
            (54.8, 73.8, "Sunsworn Camp"),
            (41.0, 45.9, "Narvalis Point"),
            (66.3, 39.5, "Moonhoof Village"),
            (51.3, 35.8, "Moonhoof Retreat"),
            (68.0, 22.0, "the Grove of the Sun"),
            (37.5, 19.5, "the Ancestral Grounds"),
            (71.0, 56.0, "the Ruins of Nendis"),
            (68.8, 70.0, "Maras'ethil"),
            (51.1, 96.1, "the entrance to Timbermaw Hold"),
            (63.6, 76.0, "Moonsilk Hollow"),
            (55.5, 63.5, "the Grove of the Moon"),
            (44.6, 20.4, "An'she's Respite"),
            (58.0, 43.0, "Foulheart Sanctum"),
            (59.2, 46.8, "Riverhorn Village"),
            (57.5, 28.8, "Zarazar's camp"),
            (65.5, 18.5, "Elun'aran"),
            (67.3, 13.5, "the Temple of Elunaris"),
            (62.4, 23.0, "the Withered Enclave"),
        ],
        # Where the data has no ["pre"], or a wrong one. The Moro'gai story
        # runs 41910 to 41917 -- each quest's text picks up where the last
        # left off, and 41911 and 41915 are given by a script at the end of
        # the one before -- and 42080's recorded ["pre"] closes a loop
        # (42080 > 42075 > 42076 > 42077 > 42080): it follows 42074, whose
        # hand-in is the NPC that gives it. Duke Hydraxis gives In Water,
        # Clarity (42050) to whoever In Need of Water (42049) sent to him.
        "pre": {
            41911: [41910], 41912: [41911], 41913: [41912], 41914: [41913],
            41915: [41914], 41916: [41915], 41917: [41916],
            42050: [42049], 42080: [42074],
        },
        # Where an NPC with more than one spawn stands for its quests.
        "npc": {
            "Ulf Stonetotem": (65.7, 39.7),
            "Arch Druid Renethra Moonwater": (41.0, 45.8),
        },
        # Where objectives are, for quests the data places wrongly or not at
        # all, read from their text and the NPCs around the places it names.
        # Elun'aran is "to the north" of the Grove of the Sun, where "the
        # fallen druids of Elun'aran" -- the Withered and Deranged Druids --
        # stand; the Temple of Elunaris is where Arch Druid Mothshroud stands
        # "atop" it. The Light of Elunaris's relic is recorded as dropping in
        # the Ruins of Nendis, but its text sends you to the temple.
        "spots": {
            42087: [(67.3, 13.5)],
            42096: [(65.5, 18.5)],
            42097: [(65.5, 18.5)],
            42085: [(50.2, 35.7)],                 # the celebration, at Elder Starstrider
            41953: [(51.1, 96.1)],                 # "Enter Timbermaw Hold"
            41921: [(62.5, 66.2)],                 # "the shimmering lake": Shimmerstar Lake
        },
        # Text the data lacks, from rivi-s's pfQuest-turtle-HDB
        # (https://github.com/rivi-s/pfQuest-turtle-HDB).
        "text": {
            42071: {"T": "Father Will Listen",
                    "O": "Report to Cairne Bloodhoof in Elders' Rise, Thunder Bluff, Mulgore."},
        },
        # Quests that want a group: shown in Group mode only, with every
        # quest that follows from them (Route.group). Chosen by the owner:
        # Price of Betrayal's text says to bring friends; Draenethyst
        # Recovery is level 60 and inside Timbermaw Hold; the rest are the
        # zone's bosses.
        "group": {
            42075,      # Price of Betrayal
            41953,      # Draenethyst Recovery
            42077,      # Mothshroud Falls
            42090,      # Serpents Without Heads
            42097,      # Keeper of the Broken Grove
            41994,      # Shade Mother
            42092,      # A Star That Calls Back
        },
        # Quests shown only once they are in your log, and why.
        "optional": {
            41954: "wants leather armour you have crafted",
            41922: "handed in at the Swamp of Sorrows, the far side of the world from Winterspring, next",
            41908: "a hand-in with no text on record: most likely a repeatable one",
            41909: "a hand-in with no text on record: most likely a repeatable one",
        },
        # Quests left out, and why.
        "skip": {
            41969: "wants Ember Worg Fur from the Burning Steppes, a zone the guide does not go to",
            41955: "wants the hides of three rare hydras the data does not place",
        },
    },
}


# --------------------------------------------------------------------------
# Reading pfQuest
# --------------------------------------------------------------------------

SCAN = re.compile(r'"(?:\\.|[^"\\\n])*"|--\[\[.*?\]\]|--[^\n]*|[{}]', re.S)
KEY = re.compile(r'\[\s*(-?\d+)\s*\]\s*=\s*$')
REMOVED = re.compile(r'\n[ \t]*\[(-?\d+)\]\s*=\s*"_"\s*,')
TOKEN = re.compile(r'\s+|--\[\[.*?\]\]|--[^\n]*|("(?:\\.|[^"\\])*")|'
                   r'(-?\d+(?:\.\d+)?)|([{}\[\]=,;])|([A-Za-z_]\w*)', re.S)
COORD = re.compile(r'\{\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*,\s*(\d+)\s*(?:,\s*-?\d+\s*)?\}')


def unescape(s):
    s = re.sub(r"\\(.)", r"\1", s)
    if "â€" in s:                     # UTF-8 read as cp1252, "â€™"
        try:
            s = s.encode("cp1252").decode("utf-8")
        except (UnicodeEncodeError, UnicodeDecodeError):
            pass
    return s


def entries(path):
    """id -> source text of each top-level entry of a pfQuest table, None for
    one Turtle removed ("_"). The files mix layouts -- two spaces, tabs, an
    entry on one line -- so entries are found by their braces."""
    text = open(path, encoding="utf-8", errors="replace").read()
    out, depth, key, start = {}, 0, None, 0
    for m in SCAN.finditer(text):
        tok = m.group(0)
        if tok == "{":
            if depth == 1:
                k = KEY.search(text, max(0, m.start() - 40), m.start())
                key, start = (int(k.group(1)) if k else None), m.start()
            depth += 1
        elif tok == "}":
            depth -= 1
            if depth == 1 and key is not None:
                out[key] = text[start:m.end()]
                key = None
    for m in REMOVED.finditer(text):
        out.setdefault(int(m.group(1)), None)
    return out


def parse(text):
    """A Lua table literal as dicts (positional entries keyed 1, 2, ...)."""
    toks = []
    for m in TOKEN.finditer(text):
        s, n, p, w = m.groups()
        if s is not None:
            toks.append(("s", unescape(s[1:-1])))
        elif n is not None:
            toks.append(("n", float(n) if "." in n else int(n)))
        elif p is not None:
            toks.append(("p", p))
        elif w is not None:
            toks.append(("w", w))
    pos = [0]

    def value():
        kind, v = toks[pos[0]]
        pos[0] += 1
        if (kind, v) != ("p", "{"):
            return v
        out, i = {}, 1
        while toks[pos[0]] != ("p", "}"):
            if toks[pos[0]] == ("p", "["):
                pos[0] += 1
                k = value()
                pos[0] += 2                    # ] =
                out[k] = value()
            elif toks[pos[0]][0] == "w" and toks[pos[0] + 1] == ("p", "="):
                k = toks[pos[0]][1]
                pos[0] += 2
                out[k] = value()
            else:
                out[i] = value()
                i += 1
            if toks[pos[0]] in (("p", ","), ("p", ";")):
                pos[0] += 1
        pos[0] += 1
        return out
    return value() if toks else {}


def seq(t):
    return [t[k] for k in sorted(t)] if isinstance(t, dict) else []


def names(path):
    return {int(a): unescape(b) for a, b in
            re.findall(r'\[(-?\d+)\]\s*=\s*"((?:\\.|[^"\\])*)"', open(path, encoding="utf-8", errors="replace").read())}


class Data:
    """pfQuest-turtle over pfQuest, as the addon merges them: the turtle
    table's entry wins, and "_" removes one."""

    def __init__(self, turtle, base):
        self.dirs = [(base, ""), (turtle, "-turtle")] if base else [(turtle, "-turtle")]
        self.raw = {k: self.merged(k) for k in ("units", "objects", "items")}
        self.quests = {q: parse(t) for q, t in entries(self.path(turtle, "quests", "-turtle")).items() if t}
        self.text = {}
        for q, t in entries(self.path(turtle, "quests", "-turtle", True)).items():
            if t:
                self.text[q] = {k: v for k, v in parse(t).items() if isinstance(v, str)}
        self.names = {k: self.merged(k, True) for k in ("units", "objects", "items", "zones")}
        self.parsed, self.zones = {}, {}

    @staticmethod
    def path(pf, kind, suffix, loc=False):
        p = os.path.join(pf, "db", *(["enUS"] if loc else []) + ["%s%s.lua" % (kind, suffix)])
        if not os.path.exists(p):
            sys.exit("missing pfQuest file: %s" % p)
        return p

    def merged(self, kind, loc=False):
        out = {}
        for pf, suffix in self.dirs:
            table = names(self.path(pf, kind, suffix, True)) if loc else entries(self.path(pf, kind, suffix))
            for k, v in table.items():
                if v is None or v == "_":
                    out.pop(k, None)
                else:
                    out[k] = v
        return out

    def get(self, kind, i):
        key = (kind, i)
        if key not in self.parsed:
            t = self.raw[kind].get(i)
            self.parsed[key] = parse(t) if t else {}
        return self.parsed[key]

    def spawns(self, kind, i):
        """[(x, y, zone)] of a unit or object."""
        table = {"U": "units", "O": "objects"}[kind]
        return [(float(x), float(y), int(z)) for x, y, z in COORD.findall(self.raw[table].get(i) or "")]

    def name(self, kind, i):
        table = {"U": "units", "O": "objects", "I": "items"}[kind]
        return self.names[table].get(i, "")

    def zone(self, z):
        return self.names["zones"].get(z, "")

    def zone_id(self, name):
        ids = [z for z, n in self.names["zones"].items() if n == name]
        if not ids:
            sys.exit("no zone named %r in the data" % name)
        return max(ids)

    def in_zone(self, zone):
        """Every unit and object with a spawn in the zone: {(kind, id)}."""
        if zone not in self.zones:
            self.zones[zone] = {(kind, i) for kind, table in (("U", "units"), ("O", "objects"))
                                for i in self.raw[table]
                                if any(z == zone for _, _, z in self.spawns(kind, i))}
        return self.zones[zone]

    def drops(self, item):
        """Where an item comes from: [(kind, id)]."""
        t = self.get("items", item)
        return [(k, abs(i)) for k in ("U", "O") for i in (t.get(k) or {})]


# --------------------------------------------------------------------------
# The zone's quests
# --------------------------------------------------------------------------

def dist(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


def clusters(points, limit=MAX_SPOTS):
    """The biggest groups of points, biggest first: [(x, y)]."""
    left, out = list(points), []
    while left and len(out) < limit:
        best = max(left, key=lambda p: sum(1 for q in left if dist(p, q) <= SPOT))
        near = [q for q in left if dist(best, q) <= SPOT]
        out.append(((sum(q[0] for q in near) / len(near), sum(q[1] for q in near) / len(near)), len(near)))
        left = [q for q in left if dist(best, q) > SPOT]
    # A stray spawn beside a camp is not worth a trip.
    return [p for p, n in out if n * 5 >= out[0][1]] if out else []


def fmt(p):
    def n(v):
        return ("%.1f" % v).rstrip("0").rstrip(".")
    return "(%s, %s)" % (n(p[0]), n(p[1]))


class Who:
    """A quest giver or taker: name, where, and in which zone."""

    def __init__(self, name, point=None, zone=None, kind="U", ident=0):
        self.name, self.point, self.zone, self.kind, self.id = name, point, zone, kind, ident


class Quest:
    def __init__(self, data, qid, zone, cfg):
        t = data.quests[qid]
        text = data.text.get(qid, {})
        self.id = qid
        fill = cfg["text"].get(qid, {})
        self.title = text.get("T") or fill.get("T") or "Quest %d" % qid
        self.objective = re.sub(r"\$[BbNn]", " ", text.get("O") or fill.get("O", "")).replace("|", "/").strip()
        self.lvl, self.min = t.get("lvl") or 0, t.get("min") or 0
        self.race, self.cls = t.get("race") or 0, t.get("class") or 0
        self.pre = cfg["pre"].get(qid) or [p for p in seq(t.get("pre")) if isinstance(p, int)]
        part = lambda key, kind: [i for i in seq((t.get(key) or {}).get(kind)) if isinstance(i, int)]
        self.starters = [("U", i) for i in part("start", "U")] + [("O", i) for i in part("start", "O")]
        self.start_items = part("start", "I")
        self.enders = [("U", i) for i in part("end", "U")] + [("O", i) for i in part("end", "O")]
        self.obj = {k: part("obj", k) for k in ("U", "O", "I")}
        self.data, self.zone, self.cfg = data, zone, cfg
        self.giver, self.taker = self.who(self.starters), self.who(self.enders)
        self.spots = [tuple(p) for p in cfg["spots"].get(qid, [])] or self.targets()
        self.needs_c = self.doing()
        words = self.objective.split()
        if self.needs_c and not self.spots and words and words[0] in EVENT:
            at = self.taker if self.names_taker() else self.giver
            if at and at.point and not at.zone:
                self.spots = [at.point]

    def who(self, whom):
        """The first of a quest's givers (or takers) placed in the zone, else
        the first placed anywhere, else the first named."""
        for kind, i in whom:
            name = self.data.name(kind, i)
            here = [(x, y) for x, y, z in self.data.spawns(kind, i) if z == self.zone]
            if here:
                point = self.cfg["npc"].get(name) or (here[0] if len(here) == 1 else self.central(here))
                return Who(name, point, None, kind, i)
        for kind, i in whom:
            pts = self.data.spawns(kind, i)
            if pts:
                x, y, z = pts[0]
                return Who(self.data.name(kind, i), (x, y), self.data.zone(z), kind, i)
        if whom:
            kind, i = whom[0]
            return Who(self.data.name(kind, i) or "someone", None, None, kind, i)
        return None

    def central(self, points):
        """Of an NPC's spawns, the one nearest a named place: where it stands
        among others, not where it walks off to."""
        places = self.cfg["places"]
        return min(points, key=lambda p: min(dist(p, (x, y)) for x, y, _ in places))

    def targets(self):
        """Where the objectives are: the data's spawns in the zone for what the
        quest asks for, else the zone's NPCs and objects its text names."""
        pts = []
        for kind in ("U", "O"):
            for i in self.obj[kind]:
                pts += [(x, y) for x, y, z in self.data.spawns(kind, i) if z == self.zone]
        for item in self.obj["I"]:
            for kind, i in self.data.drops(item):
                pts += [(x, y) for x, y, z in self.data.spawns(kind, i) if z == self.zone]
        if pts:
            return clusters(pts)
        return clusters(self.named_in_text())

    def named_in_text(self):
        """Spawns in the zone of whatever the objective text or the items it
        asks for name, other than the quest's own giver and taker."""
        own = {w.name for w in (self.giver, self.taker) if w}
        wanted = [self.objective] + [self.data.name("I", i) for i in self.obj["I"]]
        pts = []
        for (kind, i), name in self.zone_things():
            if name in own or len(name) < 5:
                continue
            pat = r"\b%s(s|es)?\b" % re.escape(name)
            if any(re.search(pat, w, re.I) for w in wanted):
                pts += [(x, y) for x, y, z in self.data.spawns(kind, i) if z == self.zone]
        return pts

    def zone_things(self):
        return [((kind, i), self.data.name(kind, i)) for kind, i in sorted(self.data.in_zone(self.zone))]

    def doing(self):
        """Whether the quest asks for anything but walking to its taker."""
        words = self.objective.split()
        first = words[0] if words else ""
        # An item the quest before asked for is in your bags already: the
        # Heart of Ohanzee, taken on to Thunder Bluff.
        carried = set()
        for p in self.pre:
            carried |= set(seq(((self.data.quests.get(p) or {}).get("obj") or {}).get("I")))
        fresh = [i for i in self.obj["I"] if i not in carried]
        # "Deliver Thobias's Satchel to Heghala", "Find Ireth Moondancer in
        # the Ruins of Nendis": whatever it hands you, to whoever it names.
        if (first in GOING and self.names_taker() and not re.search(r"\d", self.objective)
                and not self.obj["U"] and not self.obj["O"]
                and not any(self.data.drops(i) for i in fresh)):
            return False
        return bool(self.obj["U"] or self.obj["O"] or fresh or first in DOING)

    def names_taker(self):
        if not self.taker:
            return False
        words = [w for w in re.findall(r"[\w'\u2019]+", self.taker.name) if len(w) >= 4 and w not in TITLES]
        return any(re.search(r"\b%s\b" % re.escape(w), self.objective) for w in words)

    def task(self):
        """What a C step says: the objective text, less where to take it."""
        text = self.objective
        items = [self.data.name("I", i) for i in self.obj["I"]]
        if not text:
            parts = []
            if self.obj["U"]:
                parts.append("Kill " + ", ".join(self.data.name("U", i) for i in self.obj["U"]))
            if items:
                parts.append("Get " + ", ".join(items))
            if self.obj["O"]:
                parts.append("Use " + ", ".join(self.data.name("O", i) for i in self.obj["O"]))
            return "; ".join(parts) or "Do what the quest asks"
        name = r"(?:[A-Z][\w'\u2019-]*)(?: (?:[A-Z][\w'\u2019-]*|the|of))*"
        text = re.split(r"[,.]? (?:and |then )*(?:return|report back|come back)\b", text, 1, flags=re.I)[0]
        text = re.sub(r"^Return to .+? with (.+)$", r"Get \1", text)
        text = re.sub(r"^Bring %s (the .+?)(?:,.*)?$" % name, r"Get \1", text)
        text = re.sub(r"^(?:Bring|Return with|Deliver) (.+?) (?:to|for) [A-Z].*$", r"Get \1", text)
        text = re.sub(r" (?:to|for) %s (?:in|at|on|atop|near|by) .*$" % name, "", text)
        text = re.sub(r"[.,]? (?:and |)(?:[Bb]ring|[Dd]eliver|[Tt]ake) (?:it|them)(?: back)?\b.*$", "", text)
        text = re.sub(r" (?:to|for) %s$" % name, "", text)
        text = text.rstrip(" .,!")
        # "Acquire the needed materials": which. An item the text names --
        # "his necklace", "spools of silk" -- is not named again.
        missing = [i for i in items if i and not re.search(r"\b%s" % re.escape(i.split()[-1].rstrip("s").lower()),
                                                           text.lower())]
        if missing:
            text += ": " + ", ".join(missing)
        return text

    def for_side(self, mask):
        return not self.race or bool(self.race & mask)

    def tags(self, mask):
        out = []
        if self.cls and self.cls & ALL_CLASSES != ALL_CLASSES:
            out.append("|C|%s|" % "/".join(n for b, n in CLASSES if self.cls & b))
        if self.race and self.race & mask != mask:
            out.append("|R|%s|" % "/".join(n for b, n in RACES if self.race & b))
        return out


def zone_quests(data, zone, cfg):
    """Quests given, taken or done in the zone, and the steps of their chains
    that lie outside it."""
    here = data.in_zone(zone)

    def ids(t, key):
        part = t.get(key) or {}
        return [(k, i) for k in ("U", "O") for i in seq(part.get(k))]

    def pre(qid):
        return cfg["pre"].get(qid) or seq(data.quests[qid].get("pre"))
    picked = {qid for qid, t in data.quests.items()
              if any(w in here for w in ids(t, "start") + ids(t, "end") + ids(t, "obj"))}
    # A chain that leaves the zone and comes back: the quests between.
    while True:
        more = {qid for qid in data.quests if qid not in picked and
                any(p in picked for p in pre(qid)) and any(qid in pre(o) for o in picked)}
        if not more:
            break
        picked |= more
    return {qid: Quest(data, qid, zone, cfg) for qid in picked if qid not in cfg["skip"]}


# --------------------------------------------------------------------------
# The route
# --------------------------------------------------------------------------

class Route:
    def __init__(self, quests, side, mask, cfg):
        self.cfg, self.side, self.mask = cfg, side, mask
        self.quests = {q.id: q for q in quests.values() if q.for_side(mask)}
        self.lo, self.hi = cfg["levels"]
        self.pos = cfg["start"]
        self.accepted, self.done, self.turned = set(), set(), set()
        self.lines, self.warnings = [], []
        self.final = False
        # Given outside the zone and handed in here: picked up on the way, if
        # you pass.
        self.leadins = [q for q in self.quests.values()
                        if q.giver and q.giver.zone and q.taker and q.taker.point and not q.taker.zone
                        and not any(p in self.quests for p in q.pre)]
        # Quests you may not have -- those, the ones nobody is on record as
        # giving, the ones ZONES says -- and whatever follows only from them.
        self.optional = {q.id for q in self.leadins} | set(cfg["optional"])
        for q in self.quests.values():
            if not q.giver or (q.giver.point is None and not self.trigger(q) and
                               not (q.taker and q.taker.point and not q.taker.zone)):
                self.optional.add(q.id)
        changed = True
        while changed:
            changed = False
            for q in self.quests.values():
                pre = [p for p in q.pre if p in self.quests]
                if q.id not in self.optional and pre and all(p in self.optional for p in pre):
                    self.optional.add(q.id)
                    changed = True
        # Group quests, and whatever follows from them: nobody solo can pick
        # those up either.
        self.group = set(cfg["group"]) & set(self.quests)
        changed = True
        while changed:
            changed = False
            for q in self.quests.values():
                if q.id not in self.group and any(p in self.group for p in q.pre):
                    self.group.add(q.id)
                    changed = True
        # Handed in outside the zone, and nothing here follows from them:
        # picked up last, on the way out -- unless a chain goes to that zone
        # and back anyway, when they go with it.
        away = {q.id for q in self.quests.values() if q.taker and q.taker.zone}
        visited = {w.zone for q in self.quests.values() if q.id in away and self.opens_here(q.id, set())
                   for w in (q.taker, q.giver) if w and w.zone}
        self.leadouts = {qid for qid in away if not self.opens_here(qid, set())
                         and self.quests[qid].taker.zone not in visited}

    def opens_here(self, qid, seen):
        """Whether a quest leads, through its chain, back to the zone."""
        for r in self.quests.values():
            if qid in r.pre and r.id not in seen:
                seen.add(r.id)
                if (r.taker and not r.taker.zone) or self.opens_here(r.id, seen):
                    return True
        return False

    # What a quest's steps need.
    def trigger(self, q):
        return bool(q.giver and q.giver.name.startswith("quest_"))

    def level(self):
        return self.lo + (self.hi - self.lo) * len(self.turned) / max(1, len(self.quests))

    def carried(self):
        return len(self.accepted - self.turned - self.optional)

    def pre_met(self, q):
        return all(p in self.turned or p not in self.quests for p in q.pre)

    def where_accept(self, q):
        """(point, zone) of a quest's pick-up, or None when there is no place."""
        g = q.giver
        if not g:
            return (q.spots[0], None) if q.spots else None
        if self.trigger(q):
            pre = [self.quests[p] for p in q.pre if p in self.quests]
            if pre and pre[0].taker and pre[0].taker.point:
                return pre[0].taker.point, pre[0].taker.zone
            return None
        if g.point:
            return g.point, g.zone
        if q.taker and q.taker.point and not q.taker.zone:
            return q.taker.point, None
        return None

    def can_accept(self, q, loose=False):
        if q.id in self.accepted or not self.pre_met(q) or self.where_accept(q) is None:
            return False
        if q.id in self.leadouts and not self.final and q.id not in self.optional:
            return False
        if self.trigger(q):
            return True                        # given, not asked for
        if self.carried() >= LOG:
            return False
        return loose or (q.min <= self.level() + 1 and q.lvl <= self.level() + AHEAD + 1)

    def ready(self, q):
        return q.id in self.accepted and q.id not in self.turned and (q.id in self.done or not q.needs_c)

    def can_complete(self, q, loose=False):
        return (q.id in self.accepted and q.id not in self.done and q.needs_c and bool(q.spots) and
                (loose or q.lvl <= self.level() + AHEAD))

    # The guide's lines.
    def place(self, p):
        best = min(self.cfg["places"], key=lambda pl: dist(p, (pl[0], pl[1])))
        return best[2] if dist(p, (best[0], best[1])) <= PLACE else None

    def at(self, who, point):
        name = who.name
        if who.kind == "O":
            name = "the WANTED! poster" if "WANTED" in name.upper() else "the %s" % name
        where = self.place(point) if not who.zone else None
        text = "%s%s %s" % (name, " at %s" % where if where and where not in name else "", fmt(point))
        return text[0].upper() + text[1:]

    def emit(self, action, q, note, zone=None, extra=()):
        tags = ["|QID|%d|" % q.id, "|N|%s|" % note] + q.tags(self.mask) + list(extra)
        if q.id in self.group:
            tags.append("|P|GROUP|")
        tags.append("|Z|%s|" % (zone or self.cfg["zone"]))
        if q.id in self.optional:
            tags.append("|O|")
        self.lines.append("%s %s %s" % (action, q.title, " ".join(tags)))

    def accept(self, q):
        point, zone = self.where_accept(q)
        g = q.giver
        if not g:
            note = ("Only if you have it: no one is on record as giving it, so it starts from an item "
                    "or an event, or somewhere else %s" % fmt(point))
        elif self.trigger(q):
            pre = self.quests[[p for p in q.pre if p in self.quests][0]]
            note = "Given as you hand in %s %s" % (pre.title, fmt(point))
        elif g.point:
            note = self.at(g, point) + (", in %s" % g.zone if g.zone else "")
        else:
            label = "The WANTED! poster" if "WANTED" in g.name.upper() else "The %s" % g.name
            note = "%s beside %s" % (label, self.at(q.taker, point))
        extra = []
        pre = [p for p in q.pre if p in self.quests]
        if q.id in self.optional and pre and all(p in self.optional for p in pre):
            extra.append("|PRE|%s|" % self.quests[pre[0]].title)
        self.emit("A", q, note, zone, extra)
        self.accepted.add(q.id)
        if not zone:
            self.pos = point
        # An objective where it is given -- a talk, an event -- is done there.
        if q.needs_c and q.spots and not zone and dist(q.spots[0], point) <= HUB:
            self.complete(q)

    def complete(self, q):
        spots = sorted(q.spots, key=lambda s: dist(s, self.pos))
        note = "%s %s" % (q.task(), " ".join(fmt(s) for s in spots)) if spots else q.task()
        self.emit("C", q, note)
        self.done.add(q.id)
        if spots:
            self.pos = spots[0]

    def turnin(self, q):
        t = q.taker
        if q.id not in self.accepted:
            self.accept(q)                     # one nobody gives: if you have it
        if q.needs_c and q.id not in self.done:
            self.complete(q)
        self.emit("T", q, self.at(t, t.point) + (", in %s" % t.zone if t.zone else ""), t.zone)
        self.turned.add(q.id)
        if not t.zone:
            self.pos = t.point

    def order(self):
        return sorted((q for q in self.quests.values() if q.id not in self.turned), key=lambda q: (q.lvl, q.id))

    def here(self, q):
        """The quest's taker, when it is in the zone."""
        return q.taker if q.taker and q.taker.point and not q.taker.zone else None

    def local(self):
        """Everything that can be handed in and picked up where you stand."""
        changed = True
        while changed:
            changed = False
            for q in self.order():
                if self.ready(q) and self.here(q) and dist(q.taker.point, self.pos) <= HUB:
                    self.turnin(q)
                    changed = True
            for q in self.order():
                if self.can_accept(q) and (q.id not in self.optional or (q.giver and q.giver.point)):
                    point, zone = self.where_accept(q)
                    if not zone and dist(point, self.pos) <= HUB:
                        self.accept(q)
                        changed = True

    def moves(self, loose=False):
        """(point, quest, what) for everything in the zone there is to do next."""
        out = []
        for q in self.order():
            if self.ready(q) and self.here(q):
                out.append((q.taker.point, q, self.turnin))
            elif self.can_complete(q, loose):
                out.append((min(q.spots, key=lambda s: dist(s, self.pos)), q, self.complete))
            elif q.id not in self.optional and self.can_accept(q, loose):
                point, zone = self.where_accept(q)
                if not zone:
                    out.append((point, q, self.accept))
        # One nobody gives, done where its objectives are, if you have it.
        for q in self.order():
            if (q.id in self.optional and not q.giver and q.spots and q.id not in self.accepted and
                    self.pre_met(q) and (loose or q.lvl <= self.level() + AHEAD)):
                out.append((q.spots[0], q, self.accept))
        return out

    def step(self):
        moves = self.moves() or self.moves(True)
        if not moves:
            return False

        # A place with more to do counts as nearer; one only some players
        # have reason to go to, as further.
        def cost(m):
            together = sum(1 for o in moves if dist(o[0], m[0]) <= HUB)
            far = 2 if m[1].id in self.optional else 1
            return far * dist(self.pos, m[0]) / (1 + 0.5 * (together - 1))
        point, q, do = min(moves, key=cost)
        do(q)
        return True

    def trips(self):
        """Out of the zone: the zone whose hand-ins and pick-ups open the most
        back in this one, or, at the end, the rest."""
        away = {}
        for q in self.order():
            if self.ready(q) and q.taker and q.taker.zone and q.id not in self.optional:
                away.setdefault(q.taker.zone, []).append(q)
            elif (q.giver and q.giver.zone and q.id not in self.optional and
                  q not in self.leadins and self.can_accept(q, True)):
                away.setdefault(q.giver.zone, []).append(q)
        if not away:
            return False

        def opens(zone):
            ids = {q.id for q in away[zone]}
            return sum(1 for q in self.quests.values() if q.id not in self.turned and set(q.pre) & ids)
        zone = max(sorted(away), key=opens)
        if not self.final and not opens(zone):
            return False
        self.lines += ["", "R %s |N|Head to %s.| |Z|%s|" % (zone, zone, zone)]
        there, went = len(self.lines) - 1, set()
        changed = True
        while changed:
            changed = False
            for q in self.order():
                if self.ready(q) and q.taker and q.taker.zone == zone:
                    self.turnin(q)
                    went.add(q.id)
                    changed = True
                elif (q.giver and q.giver.zone == zone and q.id not in self.optional and
                      self.can_accept(q, True)):
                    self.accept(q)
                    went.add(q.id)
                    changed = True
        if not self.final:
            z = self.cfg["zone"]
            self.lines += ["R %s |N|Back to %s.| |Z|%s|" % (z, z, z), ""]
        # A trip only for group quests is only for groups: solo, there is
        # nothing there to go for.
        if all(i in self.group or i in self.optional for i in went):
            for i in range(there, len(self.lines)):
                if self.lines[i].startswith("R "):
                    self.lines[i] += " |P|GROUP|"
        return True

    def run(self):
        cfg, side, z = self.cfg, self.side, self.cfg["zone"]
        self.lines += ["N Welcome to %s |N|%s|" % (z, cfg["intro"].format(camps=cfg["camps"][side])), ""]
        if self.leadins:
            self.lines.append("N On the way |N|Quests elsewhere that send you here, if you pass them. "
                              "None is needed: the guide shows their hand-ins only if you have them.|")
            for q in sorted(self.leadins, key=lambda q: q.id):
                self.accept(q)
            self.lines.append("")
        self.lines += ["R %s |N|%s %s.| |Z|%s|" % (z, cfg["arrive"], fmt(cfg["start"]), z), ""]
        self.pos = cfg["start"]
        while True:
            self.local()
            if self.step() or self.trips():
                continue
            if not self.final:
                self.final = True              # the zone is done: the way out
                continue
            break
        # Hand-ins elsewhere for quests only some players have: no trip,
        # just the step, shown to those who have it.
        for q in self.order():
            if q.id in self.optional and self.ready(q) and q.taker and q.taker.zone:
                self.turnin(q)
        for q in self.order():
            if q.id in self.accepted:
                self.warnings.append("%d %s: picked up, never handed in" % (q.id, q.title))
            elif q.id not in self.optional:
                self.warnings.append("%d %s: never picked up" % (q.id, q.title))
        for q in sorted(self.quests.values(), key=lambda q: q.id):
            if q.needs_c and not q.spots:
                self.warnings.append("%d %s: objectives with no place" % (q.id, q.title))
        self.lines += ["", "N Guide complete |N|That is %s done. Carry on with %s.|" % (z, cfg["next"])]
        return self.lines


def write(quests, cfg):
    files = {}
    for side, mask in SIDES:
        r = Route(quests, side, mask, cfg)
        body = "\n".join(r.run())
        body = re.sub(r"\n{3,}", "\n\n", body)
        name = "%s (%d-%d)" % (cfg["zone"], cfg["levels"][0], cfg["levels"][1])
        files[os.path.join(ROOT, "Guides", side, cfg["file"] + ".lua")] = (
            "-- Written by Tools/build/build_zone_guide.py from pfQuest-turtle's data: edit ZONES there,\n"
            "-- not this file, and run it again.\n"
            "AegisPathfinder:RegisterGuide(%s, %s, %s, function()\n\nreturn [[\n\n%s\n\n]]\nend)\n" % (
                lua_str(name), lua_str(cfg["next"]), lua_str(side), body.strip()))
        for w in r.warnings:
            print("%s: %s" % (side, w), file=sys.stderr)
    return files


def lua_str(s):
    return '"%s"' % s.replace("\\", "\\\\").replace('"', '\\"')


def dump(quests):
    for q in sorted(quests.values(), key=lambda q: (q.lvl, q.id)):
        def where(w):
            if not w:
                return "-"
            return "%s %s%s" % (w.name, w.point and fmt(w.point) or "?", w.zone and " in " + w.zone or "")
        print("%5d  %-38s lvl %2d min %2d  race %4d  class %4d  pre %s" % (
            q.id, q.title[:38], q.lvl, q.min, q.race, q.cls, q.pre or "-"))
        print("       from %s%s" % (where(q.giver), q.start_items and "  item %s" % q.start_items or ""))
        print("       to   %s" % where(q.taker))
        print("       do   %s%s" % (" ".join(fmt(p) for p in q.spots) or "-", "" if q.needs_c else "  (talk only)"))
        print("       %s" % q.objective[:150])


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--pfquest-turtle", required=True, help="a pfQuest-turtle checkout")
    ap.add_argument("--pfquest", help="shagu/pfQuest, for the NPCs outside the zone")
    ap.add_argument("--zone", default="Moonwhisper Coast")
    ap.add_argument("--dump", action="store_true", help="print the quests")
    ap.add_argument("--check", action="store_true", help="fail if the guides are not what it would write")
    args = ap.parse_args()
    if args.zone not in ZONES:
        sys.exit("no settings for %r in ZONES" % args.zone)
    cfg = dict(ZONES[args.zone], zone=args.zone)
    data = Data(args.pfquest_turtle, args.pfquest)
    zone = data.zone_id(args.zone)
    quests = zone_quests(data, zone, cfg)
    if args.dump:
        dump(quests)
        return
    files = write(quests, cfg)
    stale = []
    for path, text in files.items():
        old = open(path, encoding="utf-8").read() if os.path.exists(path) else None
        if args.check:
            if old != text:
                stale.append(path)
        elif old != text:
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(text)
            print("wrote %s" % os.path.relpath(path, ROOT))
    if stale:
        sys.exit("out of date: %s" % ", ".join(os.path.relpath(p, ROOT) for p in stale))


if __name__ == "__main__":
    main()
