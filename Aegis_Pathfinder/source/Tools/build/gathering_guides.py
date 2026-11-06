"""The Herbalism, Skinning and Fishing guides, and where Mining's ore is,
from Tools/data/gathering.json.

Used by Tools/build/convert_professions.py. A gathering profession levels by going
somewhere, not by making something, so each skill band is one step naming
the best places for it -- worked out from the data, never typed in:

  Herbalism  zones scored by how many nodes of each herb they hold, weighted
             by how likely that herb is to raise your skill in the band.
  Skinning   the levels of beast worth skinning in the band, and the zones
             with most of them (normal creatures only; no elites).
  Fishing    the zones where nothing gets away at the band's skill -- a zone
             is fished clean at 95 over its base skill -- highest first.
  Mining     not a guide of its own: the smelting route comes from the
             professions document, and each of its steps is given, per
             faction, where the ore it smelts is mined -- or, for a step that
             levels by mining, the zones scored as Herbalism's are.

Where a zone is on your side of the map comes from this repository's own zone
guides: a zone with a guide only in Guides/Alliance/ is Alliance ground, one
in both is contested, and the level range shown is the one those guides spend
there. So only zones the addon already guides players to are recommended,
which also keeps dungeons and battlegrounds out. The capital cities have no
zone guides, and are placed by hand (CITIES), for fishing.
"""

import collections
import glob
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DATA = os.path.join(ROOT, "Tools", "data", "gathering.json")
GATHERED = ["Herbalism", "Skinning", "Fishing"]
FACTIONS = ("Alliance", "Horde")
MAX_SKILL = 300

# Zone guide names that the databases spell out in full.
ALIAS = {"Stranglethorn": "Stranglethorn Vale", "Tirisfal": "Tirisfal Glades", "Un'goro": "Un'Goro Crater"}
CITIES = {
    "Stormwind City": "Alliance", "Ironforge": "Alliance", "Darnassus": "Alliance", "Alah'Thalas": "Alliance",
    "Orgrimmar": "Horde", "Thunder Bluff": "Horde", "Undercity": "Horde",
}

# How likely a gathering node is to raise the skill, by how far past its
# requirement you are: orange, yellow, green, grey.
def gather_weight(over):
    if over < 0:
        return 0.0
    if over < 25:
        return 1.0
    if over < 50:
        return 0.6
    if over < 100:
        return 0.15
    return 0.0


def skin_requirement(level):
    """The skinning skill a creature of `level` needs."""
    if level <= 10:
        return 1
    if level <= 20:
        return (level - 10) * 10
    return level * 5


# --------------------------------------------------------------------------
# Zones
# --------------------------------------------------------------------------

def zone_table(root=ROOT):
    """zone -> { side: "Alliance"/"Horde"/"Both", levels: {faction: (lo, hi)} }."""
    seen = collections.defaultdict(lambda: {"folders": set(), "levels": {}})
    for folder in ("Alliance", "Horde", "Both"):
        for path in sorted(glob.glob(os.path.join(root, "Guides", folder, "*.lua"))):
            with open(path, encoding="utf-8") as fh:
                src = fh.read()
            for name in re.findall(r'Register(?:QuestShellPlus)?Guide\("([^"]+)"', src):
                m = re.match(r"^(.*?) \((\d+)-(\d+)\)$", name)
                if not m:
                    continue
                zone = ALIAS.get(m.group(1), m.group(1))
                lo, hi = int(m.group(2)), int(m.group(3))
                entry = seen[zone]
                entry["folders"].add(folder)
                for fac in (FACTIONS if folder == "Both" else (folder,)):
                    old = entry["levels"].get(fac)
                    entry["levels"][fac] = (min(lo, old[0]), max(hi, old[1])) if old else (lo, hi)
    zones = {}
    for zone, e in seen.items():
        f = e["folders"]
        side = "Both" if ("Both" in f or ("Alliance" in f and "Horde" in f)) else next(iter(f))
        zones[zone] = {"side": side, "levels": e["levels"]}
    for city, side in CITIES.items():
        zones.setdefault(city, {"side": side, "levels": {}, "city": True})
    return zones


def open_to(zones, zone, faction):
    z = zones.get(zone)
    return z is not None and z["side"] in (faction, "Both")


def label(zones, zone, faction):
    lv = zones[zone]["levels"].get(faction)
    return "%s (%d-%d)" % (zone, lv[0], lv[1]) if lv else zone


def join(items):
    items = list(items)
    if len(items) <= 1:
        return "".join(items)
    return ", ".join(items[:-1]) + " and " + items[-1]


# --------------------------------------------------------------------------
# Ranks
# --------------------------------------------------------------------------

def money(copper):
    if copper >= 10000 and copper % 10000 == 0:
        return "%d gold" % (copper // 10000)
    if copper >= 100 and copper % 100 == 0:
        return "%d silver" % (copper // 100)
    return "%d copper" % copper


def where(p):
    return "%s (%s)" % (p["name"], p["zone"])


def trainers(people):
    """Capital-city trainers first: that is where most players are."""
    return sorted(people, key=lambda p: (p["zone"] not in CITIES, p["name"]))


CAP = {"Apprentice": 75, "Journeyman": 150, "Expert": 225, "Artisan": 300}


def rank_steps(prof, rank, info):
    """A level gate where the rank has one, then each faction's trainers."""
    out = []
    title = ("Learn %s (Apprentice)" % prof) if rank == "Apprentice" else \
        "Train %s %s (Cap %d)" % (rank, prof, CAP[rank])
    if info["level"] > 0:
        out.append({"type": "GRIND", "title": "Reach level %d" % info["level"], "level": info["level"],
                    "note": "%s %s needs character level %d. This step clears itself when you get there."
                            % (rank, prof, info["level"])})
    needs = []
    if info["skill"]:
        needs.append("skill %d" % info["skill"])
    if info["level"]:
        needs.append("level %d" % info["level"])
    head = ("Needs %s; costs %s." % (" and ".join(needs), money(info["cost"]))) if needs \
        else "Costs %s." % money(info["cost"])
    for fac in FACTIONS:
        people = trainers(info.get(fac) or [])
        if not people:
            continue
        out.append({"type": "TRAIN", "title": title, "faction": fac,
                    "note": head + " Trainers: " + ", ".join(where(p) for p in people) + ".",
                    "rank": {"profession": prof, "cap": CAP[rank]},
                    "npcs": [p["name"] for p in people]})
    return out


def band_step(prof, fac, lo, hi, title, note):
    return {"type": "GRIND", "title": title, "faction": fac, "note": note,
            "skill": {"profession": prof, "from": lo, "to": hi}}


# --------------------------------------------------------------------------
# Herbalism
# --------------------------------------------------------------------------

def herb_bands(herbs):
    """Band edges: where a widely-found herb comes into reach, at least 15
    points apart, and always at the skill each rank is trained (50, 125, 200)."""
    edges = sorted({h["skill"] for h in herbs if sum(h["zones"].values()) >= 150} | {50, 125, 200})
    out, start = [], 1
    for e in edges:
        if e <= start:
            continue
        if e < MAX_SKILL and (e - start >= 15 or e in (50, 125, 200)):
            out.append((start, e))
            start = e
    out.append((start, MAX_SKILL))
    return out


def herb_zones(herbs, zones, faction, skill, top=3):
    score, what = collections.Counter(), collections.defaultdict(collections.Counter)
    for h in herbs:
        w = gather_weight(skill - h["skill"])
        if not w:
            continue
        for zone, n in h["zones"].items():
            if open_to(zones, zone, faction) and not zones[zone].get("city"):
                score[zone] += w * n
                what[zone][h["name"]] += w * n
    return [(zone, [name for name, _ in what[zone].most_common(3)]) for zone, _ in score.most_common(top)]


def herbalism(data, zones):
    herbs, ranks = data["herbs"], data["trainers"]["Herbalism"]
    steps = []
    gates = {50: "Journeyman", 125: "Expert", 200: "Artisan"}
    steps += rank_steps("Herbalism", "Apprentice", ranks["Apprentice"])
    for lo, hi in herb_bands(herbs):
        if lo in gates:
            steps += rank_steps("Herbalism", gates[lo], ranks[gates[lo]])
        at = lo + (hi - lo) // 3
        for fac in FACTIONS:
            best = herb_zones(herbs, zones, fac, at)
            if not best:
                continue
            names = []
            for _, hs in best:
                for n in hs:
                    if n not in names:
                        names.append(n)
            note = "Takes you from %d to %d. Best: %s." % (lo, hi, "; ".join(
                "%s: %s" % (label(zones, z, fac), ", ".join(hs)) for z, hs in best))
            steps.append(band_step("Herbalism", fac, lo, hi, "Gather to %d: %s" % (hi, join(names[:3])), note))
    return steps


# --------------------------------------------------------------------------
# Skinning
# --------------------------------------------------------------------------

def skin_levels(lo, hi):
    """The creature levels worth skinning from `lo` to `hi`: skinnable at
    `lo`, and not yet green by `hi`."""
    top = max(L for L in range(1, 64) if skin_requirement(L) <= lo)
    low = min((L for L in range(1, 64) if skin_requirement(L) > hi - 50), default=top)
    return min(low, top), top


def skin_zones(skinning, zones, faction, levels, top=3):
    """The zones with most of those beasts, among zones whose guides are
    within 5 levels of them -- the databases put a few low beasts in some
    high zones, and a level-15 skinner is not sent to a level-35 zone."""
    score = collections.Counter()
    for zone, by_level in skinning.items():
        lv = zones.get(zone, {}).get("levels", {}).get(faction)
        if not open_to(zones, zone, faction) or not lv:
            continue
        if lv[1] < levels[0] - 5 or lv[0] > levels[1] + 5:
            continue
        n = sum(c for L, c in by_level.items() if levels[0] <= int(L) <= levels[1])
        if n:
            score[zone] = n
    return [zone for zone, _ in score.most_common(top)]


def skinning(data, zones):
    ranks = data["trainers"]["Skinning"]
    gates = {50: "Journeyman", 125: "Expert", 200: "Artisan"}
    steps = rank_steps("Skinning", "Apprentice", ranks["Apprentice"])
    bands =[(1, 25)] + [(e, e + 25) for e in range(25, MAX_SKILL, 25)]
    for lo, hi in bands:
        if lo in gates:
            steps += rank_steps("Skinning", gates[lo], ranks[gates[lo]])
        levels = skin_levels(lo, hi)
        span = ("level %d" % levels[0]) if levels[0] == levels[1] else "levels %d-%d" % levels
        for fac in FACTIONS:
            best = skin_zones(data["skinning"], zones, fac, levels)
            if not best:
                continue
            note = "Takes you from %d to %d. Skin beasts of %s. Best: %s." % (
                lo, hi, span, ", ".join(label(zones, z, fac) for z in best))
            steps.append(band_step("Skinning", fac, lo, hi, "Skin to %d: %s beasts" % (hi, span), note))
    return steps


# --------------------------------------------------------------------------
# Fishing
# --------------------------------------------------------------------------

def fish_zones(fishing, zones, faction, skill, top=5):
    """The zones where nothing gets away at `skill` (base + 95 <= skill),
    the highest-skill ones first; cities after the open zones."""
    ok = [(base, z) for z, base in fishing.items() if base + 95 <= skill and open_to(zones, z, faction)]
    if not ok:
        return [], None
    best = max(b for b, _ in ok)
    picks = sorted((z for b, z in ok if b == best),
                   key=lambda z: (zones[z].get("city", False), zones[z]["levels"].get(faction, (0, 0))[0], z))
    return picks[:top], best


def fishing(data, zones):
    ranks, book, quest = data["trainers"]["Fishing"], data["fishingBook"], data["fishingQuest"]
    steps = [{"type": "NOTE", "title": "Buy a Fishing Pole",
              "note": "Fishing trainers and fishing suppliers sell one. Equip it and cast from the spell book."}]
    steps += rank_steps("Fishing", "Apprentice", ranks["Apprentice"])
    for lo, hi in ((1, 75), (75, 150), (150, 225), (225, 300)):
        if lo == 75:
            steps += rank_steps("Fishing", "Journeyman", ranks["Journeyman"])
        elif lo == 150 and book:
            for fac in FACTIONS:
                if book.get(fac):
                    steps.append({"type": "BUY", "title": "Buy %s" % book["name"], "faction": fac,
                                  "note": "%s sells it for %s. Read it to raise your Fishing cap to 225; "
                                          "it needs skill %d." % (" or ".join(where(p) for p in book[fac]),
                                                                  money(book["cost"]), book["skill"]),
                                  "rank": {"profession": "Fishing", "cap": 225},
                                  "npcs": [p["name"] for p in book[fac]]})
        elif lo == 225:
            steps += artisan_fishing(ranks.get("Artisan"), quest)
        for fac in FACTIONS:
            picks, base = fish_zones(data["fishing"], zones, fac, max(lo, 25))
            if not picks:
                continue
            note = ("Takes you from %d to %d. Fish anywhere with water in %s: nothing gets away there "
                    "at your skill. Every catch can raise it, wherever you fish." % (
                        lo, hi, join(label(zones, z, fac) for z in picks)))
            steps.append(band_step("Fishing", fac, lo, hi, "Fish to %d" % hi, note))
    return steps


def artisan_fishing(trainer, quest):
    """Artisan Fishing: Nat Pagle's quest, or -- for the Horde -- a trainer."""
    out = []
    if not quest:
        return out
    out.append({"type": "GRIND", "title": "Reach level %d" % quest["level"], "level": quest["level"],
                "note": "Artisan Fishing needs character level %d. This step clears itself when you get there."
                        % quest["level"]})
    horde_trainer = trainer and trainer.get("Horde")
    if horde_trainer:
        out.append({"type": "TRAIN", "title": "Train Artisan Fishing (Cap 300)", "faction": "Horde",
                    "note": "Needs skill %d and level %d; costs %s. Trainer: %s. Or do %s's quest, as the "
                            "Alliance does." % (trainer["skill"], trainer["level"], money(trainer["cost"]),
                                                ", ".join(where(p) for p in horde_trainer),
                                                quest["giver"]["name"]),
                    "rank": {"profession": "Fishing", "cap": 300},
                    "npcs": [p["name"] for p in horde_trainer]})
    giver = quest["giver"]
    fish = [{"item": f["name"], "qty": 1} for f in quest["fish"]]
    spots = "; ".join("%s at %s" % (f["name"], join(f["where"])) + (" (%s)" % f["zone"] if f.get("zone") else "")
                      for f in quest["fish"])
    for step in (
        {"type": "NOTE", "title": "Start %s" % quest["title"],
         "note": "%s in %s starts it. Needs level %d and Fishing %d." % (giver["name"], giver["zone"],
                                                                        quest["level"], quest["skill"]),
         "npcs": [giver["name"]]},
        {"type": "NOTE", "title": "Catch the four fish", "note": "One each: %s." % spots, "reagents": fish},
        {"type": "NOTE", "title": "Hand in to %s" % giver["name"],
         "note": "%s, %s. Handing in raises your Fishing cap to 300." % (giver["name"], giver["zone"]),
         "rank": {"profession": "Fishing", "cap": 300}, "npcs": [giver["name"]]},
    ):
        # With a trainer on their side, the Horde have trained already, and the
        # rank step clears the hand-in; the other quest steps are Alliance's.
        if horde_trainer and "rank" not in step:
            step["faction"] = "Alliance"
        out.append(step)
    return out


# --------------------------------------------------------------------------
# Mining
# --------------------------------------------------------------------------

def ores_for(step, mines):
    """The ores a step's reagents come from: an ore a vein yields, or a bar
    named for one ("Tin Bar" from "Tin Ore"), checked against the veins."""
    mined = {m["ore"] for m in mines}
    out = []
    for r in step.get("reagents") or []:
        item = r["item"]
        ore = item if item in mined else (item[:-4] + " Ore" if item.endswith(" Bar") else None)
        if ore in mined and ore not in out:
            out.append(ore)
    return out


def near_level(zones, faction, skill):
    """Zones a character at `skill` is likely to be levelling in: ones this
    addon's guides start by level skill / 5 + 15. Loose on purpose -- skill
    and level are only loosely tied -- it keeps the copper miner out of a
    level-35 zone that happens to be full of copper, and little else."""
    return lambda z: zones[z]["levels"].get(faction, (0, 0))[0] <= skill // 5 + 15


def pick(score, keep, top):
    """The top zones among those `keep` allows -- or among all of them, when
    it allows too few."""
    kept = [z for z, _ in score.most_common() if keep(z)]
    return (kept if len(kept) >= top else [z for z, _ in score.most_common()])[:top]


def ore_zones(mines, zones, faction, ore, top=3):
    """The zones with most veins yielding `ore`, the lowest-skill veins
    first -- the ones you can mine soonest."""
    veins = sorted((m for m in mines if m["ore"] == ore), key=lambda m: m["skill"])
    score = collections.Counter()
    for zone, n in veins[0]["zones"].items():
        if open_to(zones, zone, faction) and not zones[zone].get("city"):
            score[zone] += n
    return veins[0]["name"], pick(score, near_level(zones, faction, veins[0]["skill"]), top)


def mine_zones(mines, zones, faction, skill, top=3):
    """Herbalism's scoring, for veins: nodes that can still raise `skill`."""
    score, what = collections.Counter(), collections.defaultdict(collections.Counter)
    for m in mines:
        w = gather_weight(skill - m["skill"])
        if not w:
            continue
        for zone, n in m["zones"].items():
            if open_to(zones, zone, faction) and not zones[zone].get("city"):
                score[zone] += w * n
                what[zone][m["name"]] += w * n
    return [(zone, [name for name, _ in what[zone].most_common(2)])
            for zone in pick(score, near_level(zones, faction, skill), top)]


def mining_places(step, data, zones):
    """One copy of a Mining route step per faction, its note saying where to
    mine: for the ore a smelting step uses, or -- for a step that levels by
    mining -- the best zones for the band."""
    out, lo, hi = [], step["skill"]["from"], step["skill"]["to"]
    ores = ores_for(step, data["mines"])
    for fac in FACTIONS:
        if ores:
            parts = []
            for ore in ores:
                vein, where_ = ore_zones(data["mines"], zones, fac, ore)
                if where_:
                    parts.append("%s: mine %ss, most in %s" % (ore, vein, join(label(zones, z, fac) for z in where_)))
            extra = (" %s. Or buy %s." % ("; ".join(parts), "it" if len(parts) == 1 else "them")) if parts else ""
        else:
            best = mine_zones(data["mines"], zones, fac, lo + (hi - lo) // 3)
            extra = " Best: %s." % "; ".join("%s: %s" % (label(zones, z, fac), ", ".join(v)) for z, v in best) \
                if best else ""
        copy = dict(step)
        copy["faction"] = fac
        copy["note"] = step["note"] + extra
        out.append(copy)
    return out


# --------------------------------------------------------------------------

BUILDERS = {"Herbalism": herbalism, "Skinning": skinning, "Fishing": fishing}

INTRO = {
    "Herbalism": "Where to gather at each skill band: the zones with most of the herbs that can raise your "
                 "skill there, from pfQuest's node counts. Zones show the levels this addon's guides spend "
                 "there; pick one your level suits.",
    "Skinning": "Where to skin at each skill band: the beasts that can raise your skill there, and the zones "
                "with most of them (normal creatures only). Zones show the levels this addon's guides spend "
                "there.",
    "Fishing": "Where to fish at each skill band. Every catch can raise your skill wherever you fish; these "
               "zones are the ones where nothing gets away at your skill.",
}


def load(path=DATA):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


_context = {}


def context():
    """The data and zone table, read once."""
    if not _context:
        _context["data"], _context["zones"] = load(), zone_table()
    return _context["data"], _context["zones"]


def build(prof, data=None, zones=None):
    """The QuestShell+ steps for one gathering profession."""
    data = data or load()
    zones = zones or zone_table()
    steps = [{"type": "NOTE", "title": "%s (1-300)" % prof, "note": INTRO[prof]}]
    steps += BUILDERS[prof](data, zones)
    steps.append({"type": "NOTE", "title": "Guide Complete", "note": "%s is maxed at %d." % (prof, MAX_SKILL)})
    return steps


def validate(prof, steps):
    """Each faction's bands tile 1-300, and each band says where to go."""
    problems = []
    for fac in FACTIONS:
        cursor = 1
        for s in steps:
            if s.get("skill") and s.get("faction") in (None, fac):
                if s["skill"]["from"] != cursor:
                    problems.append("%s (%s): gap at %d" % (prof, fac, cursor))
                cursor = s["skill"]["to"]
                if "Best:" not in s["note"] and "Fish anywhere" not in s["note"]:
                    problems.append("%s (%s): %d-%d names no place" % (prof, fac, s["skill"]["from"], cursor))
        if cursor != MAX_SKILL:
            problems.append("%s (%s): bands end at %d" % (prof, fac, cursor))
    return problems
