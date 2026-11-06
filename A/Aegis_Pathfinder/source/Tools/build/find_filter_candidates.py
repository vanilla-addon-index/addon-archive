#!/usr/bin/env python3
"""Find steps in the default guides that the filter switches should cover.

The Auction House, Group and Dungeon switches hide or show steps by their tags
-- |AH|, |P|GROUP|, |D|<code>| -- and only the RestedXP and RXP Hardcore guides
carry those tags. The Optimized and zone guides never did, so on them the
switches change nothing.

This lists the steps there that probably should be tagged, for a person to
review before anything changes. Two kinds of evidence:

  * The RestedXP guides tag by quest id. When every one of a quest's steps
    there carries the same tag, the same quest in the default guides is a
    strong candidate for it. Every step, because their |D| tags mostly mark
    route variants -- "Fruit of the Sea" is tagged |D|WC| on the steps of the
    route taken if you run Wailing Caverns, and untagged or |D|!WC| on the
    rest -- which says nothing about the quest itself.
  * The RXP Hardcore guides, the same way, for dungeons and the Auction House
    only: their |P|GROUP| marks sections a Hardcore player should not do
    alone, and sits on quests like "Neeru Fireblade" that anyone can solo.
  * The default guides' own words: a note that says "group", "elite",
    "Auction House", or names a dungeon.

Quests are reviewed once each, by quest id, because a tag has to go on every
step of a quest -- accept, complete and turn in -- or a solo player accepts a
group quest they can never finish. Steps with no quest id (notes like "ZF
Option") are reviewed one by one.

    python3 Tools/build/find_filter_candidates.py            # writes the JSON below
    python3 Tools/build/find_filter_candidates.py --summary  # counts only

Output: Tools/data/filter_candidates.json
"""

import json
import os
import re
import sys
from collections import OrderedDict, defaultdict

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.path.join(ROOT, "Tools", "data", "filter_candidates.json")

TARGETS = ["Guides/Optimized/Alliance", "Guides/Optimized/Horde",
           "Guides/Alliance", "Guides/Horde", "Guides/Both"]
EVIDENCE = {"RestedXP": ["Guides/RXP/Alliance", "Guides/RXP/Horde"],
            "RXP Hardcore": ["Guides/RXP_Hardcore/Alliance", "Guides/RXP_Hardcore/Horde"]}

# The addon's dungeon switches (OptionsFrame.lua DUNGEONS), and the names a
# note might use for each. Only these can be filtered; other dungeons have no
# switch.
DUNGEONS = OrderedDict([
    ("RFC", ["Ragefire Chasm", "Ragefire"]),
    ("WC", ["Wailing Caverns"]),
    ("DM", ["Deadmines", "Deadmine", "VanCleef"]),
    ("SFK", ["Shadowfang Keep", "Shadowfang"]),
    ("BFD", ["Blackfathom Deeps", "Blackfathom"]),
    ("STOCKADES", ["Stockade", "Stockades"]),
    ("GNOMER", ["Gnomeregan"]),
    ("RFK", ["Razorfen Kraul"]),
    ("SM", ["Scarlet Monastery"]),
    ("RFD", ["Razorfen Downs"]),
    ("ULDA", ["Uldaman"]),
    ("ZF", ["Zul'Farrak", "Zul Farrak", "Zulfarrak"]),
    ("MARA", ["Maraudon"]),
    ("ST", ["Sunken Temple", "Temple of Atal'Hakkar", "Atal'Hakkar"]),
    ("BRD", ["Blackrock Depths"]),
])
DUNGEON_NAME = {"RFC": "Ragefire Chasm", "WC": "Wailing Caverns", "DM": "Deadmines",
                "SFK": "Shadowfang Keep", "BFD": "Blackfathom Deeps", "STOCKADES": "The Stockade",
                "GNOMER": "Gnomeregan", "RFK": "Razorfen Kraul", "SM": "Scarlet Monastery",
                "RFD": "Razorfen Downs", "ULDA": "Uldaman", "ZF": "Zul'Farrak",
                "MARA": "Maraudon", "ST": "Sunken Temple", "BRD": "Blackrock Depths"}
# Dungeons the options panel has no switch for (Dire Maul, Stratholme,
# Scholomance, the raids) are not listed: there is no tag to give them, and
# most notes naming them only mean a place nearby -- "the ogres south of Dire
# Maul".

GROUP_WORDS = re.compile(r"\b(group|elite|party|[2-5][ -]?man|dungeon group)\b|\[G\]", re.I)
# "a group of", "grouped" as in spawns -- the word, not the play style.
GROUP_NOT = re.compile(r"\bgroups? of\b|\bin groups\b|\bgrouped together\b", re.I)
AH_WORDS = re.compile(r"auction house|\bauction(eer)?\b", re.I)
AH_SHORT = re.compile(r"\bAH\b")   # case matters: "Mai'ah" is a name

STEP = re.compile(r"^([A-Za-z]) (.*?)(\s*\|.*)?$")
TAG = re.compile(r"\|([A-Z]+)\|([^|]*)\|")
BLOCK = re.compile(r"RegisterGuide\(\"([^\"]+)\"\s*,\s*\"([^\"]*)\"\s*,\s*\"([A-Za-z]+)\"")

ACTIONS = {"A": "Accept", "C": "Complete", "T": "Turn in", "N": "Note", "R": "Run", "K": "Kill",
           "B": "Buy", "U": "Use", "F": "Fly", "H": "Hearth", "h": "Set hearth", "G": "Grind",
           "b": "Boat", "f": "Flight path", "t": "Train", "D": "Die", "P": "Pet", "L": "Level"}


def guide_files(dirs):
    for d in dirs:
        full = os.path.join(ROOT, d)
        for name in sorted(os.listdir(full)):
            if name.endswith(".lua"):
                yield os.path.join(d, name)


def steps(path):
    """(guide name, faction, line number, action, title, tags dict, raw tag text)."""
    text = open(os.path.join(ROOT, path), encoding="utf-8").read()
    m = BLOCK.search(text)
    if not m:
        return
    guide, faction = m.group(1), m.group(3)
    for lineno, line in enumerate(text.splitlines(), 1):
        s = STEP.match(line.strip())
        if not s or (s.group(3) is None and s.group(1) not in ACTIONS):
            continue
        action, title, tagtext = s.group(1), s.group(2).strip(), s.group(3) or ""
        if action not in ACTIONS:
            continue
        tags = defaultdict(list)
        for k, v in TAG.findall(tagtext):
            tags[k].append(v)
        if "|AH|" in tagtext:
            tags["AH"].append("")
        yield guide, faction, lineno, action, title, tags, tagtext


def rxp_evidence():
    """quest id -> {pack: {"D": set, "P": set, "AH": bool}}: the tags every
    step of that quest carries in that pack."""
    seen = defaultdict(lambda: defaultdict(list))   # qid -> pack -> [tag sets]
    for pack, dirs in EVIDENCE.items():
        for path in guide_files(dirs):
            for guide, faction, lineno, action, title, tags, raw in steps(path) or []:
                qid = (tags.get("QID") or [None])[0]
                if not qid:
                    continue
                d = set()
                for v in tags.get("D", []):
                    for code in v.split("/"):
                        code = code.strip().upper()
                        if code and not code.startswith("!"):
                            d.add(code)
                p = {v.strip().upper() for v in tags.get("P", [])}
                seen[qid][pack].append({"D": d, "P": p, "AH": "AH" in tags})
    ev = defaultdict(dict)
    for qid, packs in seen.items():
        for pack, occ in packs.items():
            ev[qid][pack] = {
                "D": set.intersection(*[o["D"] for o in occ]),
                "P": set.intersection(*[o["P"] for o in occ]),
                "AH": all(o["AH"] for o in occ),
                "steps": len(occ),
            }
    return ev


def dungeons_named(text):
    found = []
    for code, names in DUNGEONS.items():
        for n in names:
            if re.search(r"(?<![A-Za-z])" + re.escape(n) + r"(?![A-Za-z])", text, re.I):
                found.append(code)
                break
    return found


def main():
    ev = rxp_evidence()
    quests = OrderedDict()   # qid -> item
    notes = []               # steps without a quest id

    for path in guide_files(TARGETS):
        pack = "Optimized" if "/Optimized/" in path else "Zone guides"
        for guide, faction, lineno, action, title, tags, raw in steps(path) or []:
            note = " ".join(tags.get("N", []))
            words = title + " " + note
            already = {"AH": "AH" in tags, "GROUP": any(p.upper() == "GROUP" for p in tags.get("P", [])),
                       "D": bool(tags.get("D"))}
            where = {"guide": guide, "pack": pack, "faction": faction, "file": path, "line": lineno,
                     "action": ACTIONS.get(action, action), "title": title, "note": note,
                     "optional": "O" in tags}
            qid = (tags.get("QID") or [None])[0]

            reasons = []   # (kind, suggestion, confidence, why)
            e = ev.get(qid, {}) if qid else {}
            for evpack, conf in (("RestedXP", "high"), ("RXP Hardcore", "medium")):
                x = e.get(evpack)
                if not x:
                    continue
                every = "all %d of its steps" % x["steps"] if x["steps"] > 1 else "its one step"
                for code in sorted(x["D"]):
                    if code in DUNGEON_NAME and not already["D"]:
                        reasons.append(("dungeon", code, conf, "%s tags %s %s (%s)"
                                        % (evpack, every, code, DUNGEON_NAME[code])))
                if evpack == "RestedXP" and "GROUP" in x["P"] and not already["GROUP"]:
                    reasons.append(("group", "GROUP", conf, "%s tags %s as a group quest" % (evpack, every)))
                if x["AH"] and not already["AH"]:
                    reasons.append(("ah", "AH", conf, "%s tags %s as an Auction House step" % (evpack, every)))

            if GROUP_WORDS.search(words) and not GROUP_NOT.search(words) and not already["GROUP"]:
                m = GROUP_WORDS.search(words)
                reasons.append(("group", "GROUP", "medium", "the guide's own text says \"%s\"" % m.group(0)))
            if (AH_WORDS.search(words) or AH_SHORT.search(words)) and not already["AH"]:
                m = AH_WORDS.search(words) or AH_SHORT.search(words)
                reasons.append(("ah", "AH", "medium", "the guide's own text says \"%s\"" % m.group(0)))
            if not already["D"]:
                for code in dungeons_named(words):
                    reasons.append(("dungeon", code, "medium",
                                    "the guide's own text names %s" % DUNGEON_NAME[code]))
            if not reasons:
                continue

            if qid:
                item = quests.get(qid)
                if not item:
                    item = quests[qid] = {"id": "q" + qid, "qid": int(qid), "title": re.sub(r"\s*\(Part \d+\)", "", title),
                                          "steps": [], "reasons": []}
                item["steps"].append(where)
                for r in reasons:
                    if list(r) not in item["reasons"]:
                        item["reasons"].append(list(r))
            else:
                # Letters, digits, - and _ only: the id is a storage key.
                nid = "n-" + re.sub(r"[^A-Za-z0-9]+", "-", path.replace("Guides/", "").replace(".lua", "")) + "-%d" % lineno
                notes.append({"id": nid, "qid": None, "title": title, "steps": [where],
                              "reasons": [list(r) for r in reasons]})

    items = list(quests.values()) + notes
    # One suggestion per kind per item: the strongest.
    rank = {"high": 3, "medium": 2, "low": 1}
    for it in items:
        best = OrderedDict()
        for kind, sugg, conf, why in it["reasons"]:
            key = (kind, sugg)
            if key not in best or rank[conf] > rank[best[key]["confidence"]]:
                best[key] = {"kind": kind, "tag": sugg, "confidence": conf, "why": []}
            best[key]["why"].append(why)
        # Strongest evidence first: another guide set's tag, then the text.
        order = lambda w: (0 if w.startswith("RestedXP") else 1 if w.startswith("RXP") else 2, w)
        it["suggestions"] = [dict(v, why=sorted(set(v["why"]), key=order)) for v in best.values()]
        del it["reasons"]
        it["factions"] = sorted({s["faction"] for s in it["steps"]})
        it["packs"] = sorted({s["pack"] for s in it["steps"]})

    items = [it for it in items if it["suggestions"]]

    summary = defaultdict(lambda: defaultdict(int))
    for it in items:
        for s in it["suggestions"]:
            summary[s["kind"]][s["confidence"]] += 1
    if "--summary" in sys.argv:
        for kind in ("group", "dungeon", "ah"):
            print(kind, dict(summary[kind]))
        print("quests", len(quests), "notes", len(notes), "items", len(items))
        return

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as fh:
        json.dump({"generated_by": "Tools/build/find_filter_candidates.py",
                   "dungeons": DUNGEON_NAME, "items": items}, fh, indent=1, ensure_ascii=False)
    print("wrote %s: %d items" % (os.path.relpath(OUT, ROOT), len(items)))


if __name__ == "__main__":
    main()
