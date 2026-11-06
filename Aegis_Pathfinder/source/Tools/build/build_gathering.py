#!/usr/bin/env python3
"""Extract the data behind the gathering guides into Tools/data/gathering.json.

    python3 Tools/build/build_gathering.py --pfquest DIR [DIR ...] --cmangos FILE

Herbalism, Skinning and Fishing level by gathering, not crafting, so their
guides say where to go at each skill band rather than what to make; Mining's
guide, a smelting route, says where to mine the ore for it. That needs facts
about the world, and none of them are typed in by hand here:

  pfQuest (https://github.com/shagu/pfQuest, and pfQuest-turtle for the
  Turtle-lineage servers): every herb and ore node with the skill it needs
  and where it spawns (db/meta.lua, db/objects.lua), every creature's spawn points
  (db/units.lua), and zone names (db/enUS/zones.lua). Each DIR is a checkout
  -- pass pfQuest's and pfQuest-turtle's -- or one folder holding the files
  with "/" in their paths replaced by "_" (db_objects.lua, ...).

  CMaNGOS classic-db (https://github.com/cmangos/classic-db): the ore each
  vein always yields (gameobject_template, gameobject_loot_template), which
  creatures can be skinned and their levels (creature_template), the fishing skill each
  zone needs (skill_fishing_base_level), which trainer teaches which rank
  (npc_trainer), the Expert fishing book and who sells it (item_template,
  npc_vendor), and the Artisan fishing quest (quest_template and its giver),
  with where its fish are caught (fishing_loot_template). FILE is the full
  dump, .sql or .sql.gz.

The result is committed, so Tools/build/convert_professions.py builds the guides
from it with no network and no database; run this again to refresh it.
"""

import argparse
import collections
import gzip
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "Tools", "data", "gathering.json")

SKILL_LINE = {"Herbalism": 182, "Skinning": 393, "Fishing": 356}
TRAINER_TITLE = {"Herbalism": "Herbalis", "Skinning": "Skinn", "Fishing": "Fishing"}
RANK_SKILL = {"Apprentice": 0, "Journeyman": 50, "Expert": 125, "Artisan": 200}
EXPERT_FISHING_BOOK = "Expert Fishing - The Bass and You"
ARTISAN_FISHING_QUEST = "Nat Pagle, Angler Extreme"


# --------------------------------------------------------------------------
# pfQuest
# --------------------------------------------------------------------------

def read(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        return fh.read()


def lua_names(path):
    return {int(a): re.sub(r"\\(.)", r"\1", b)
            for a, b in re.findall(r'\[(\d+)\] = "((?:\\.|[^"\\])*)"', read(path))}


def lua_meta(path, key):
    m = re.search(r'\["%s"\] = \{(.*?)\n  \},' % key, read(path), re.S)
    if not m:
        return {}
    return {-int(a): int(b) for a, b in re.findall(r"\[(-\d+)\] = (\d+),", m.group(1))}


def lua_spawns(path, wanted=None):
    """id -> ([zone ids of each spawn], faction) from a pfQuest data file."""
    out = {}
    for m in re.finditer(r"\n  \[(\d+)\] = \{(.*?)\n  \},", read(path), re.S):
        i = int(m.group(1))
        if wanted is not None and i not in wanted:
            continue
        body = m.group(2)
        zones = [int(z) for z in re.findall(r"\{ [\d.]+, [\d.]+, (\d+), \d+ \}", body)]
        fac = re.search(r'\["fac"\] = "(\w+)"', body)
        out[i] = (zones, fac.group(1) if fac else None)
    return out


class PfQuest:
    def __init__(self, directories):
        def path(name):
            for d in directories:
                for p in (os.path.join(d, name), os.path.join(d, *name.split("_"))):
                    if os.path.exists(p):
                        return p
            sys.exit("missing pfQuest file: %s (looked in %s)" % (name.replace("_", "/"), ", ".join(directories)))
        self.path = path
        self.zones = lua_names(path("db_enUS_zones.lua"))
        self.zones.update(lua_names(path("db_enUS_zones-turtle.lua")))
        self.objects = lua_names(path("db_enUS_objects.lua"))
        self.objects.update(lua_names(path("db_enUS_objects-turtle.lua")))

    def spawns(self, kind, wanted):
        # The Turtle file is read second: where the server moved or added
        # something, its version is the one players meet.
        base = lua_spawns(self.path("db_%s.lua" % kind), wanted)
        base.update(lua_spawns(self.path("db_%s-turtle.lua" % kind), wanted))
        return base

    def zone(self, zid):
        return self.zones.get(zid)


# --------------------------------------------------------------------------
# CMaNGOS
# --------------------------------------------------------------------------

class Dump:
    def __init__(self, path):
        opener = gzip.open if path.endswith(".gz") else open
        with opener(path, "rt", encoding="utf-8", errors="replace") as fh:
            self.sql = fh.read()

    def columns(self, table):
        m = re.search(r"CREATE TABLE `%s` \((.*?)\n\) ENGINE" % table, self.sql, re.S)
        return re.findall(r"^\s+`(\w+)`", m.group(1), re.M)

    def rows(self, table):
        cols = self.columns(table)
        for m in re.finditer(r"INSERT INTO `%s` (?:\([^)]*\) )?VALUES\s*(.*?);\n" % table, self.sql, re.S):
            body, i, n = m.group(1), 0, len(m.group(1))
            while i < n:
                if body[i] != "(":
                    i += 1
                    continue
                i += 1
                vals, cur, quoted = [], "", False
                while i < n:
                    c = body[i]
                    if quoted:
                        if c == "\\":
                            cur += body[i + 1]
                            i += 2
                            continue
                        if c == "'":
                            quoted = False
                        else:
                            cur += c
                    elif c == "'":
                        quoted, cur = True, ""
                    elif c == ",":
                        vals.append(cur)
                        cur = ""
                    elif c == ")":
                        vals.append(cur)
                        break
                    else:
                        cur += c
                    i += 1
                i += 1
                yield dict(zip(cols, vals))


def num(v):
    try:
        return int(v)
    except (TypeError, ValueError):
        return 0


# --------------------------------------------------------------------------
# Extraction
# --------------------------------------------------------------------------

def herbs(pf):
    meta = lua_meta(pf.path("db_meta.lua"), "herbs")
    spawns = pf.spawns("objects", set(meta))
    merged = {}
    for oid, skill in meta.items():
        name = pf.objects.get(oid)
        if not name:
            continue
        entry = merged.setdefault(name, {"name": name, "skill": max(1, skill), "zones": collections.Counter()})
        entry["skill"] = min(entry["skill"], max(1, skill))
        for z in spawns.get(oid, ([], None))[0]:
            if pf.zone(z):
                entry["zones"][pf.zone(z)] += 1
    out = []
    for e in sorted(merged.values(), key=lambda e: (e["skill"], e["name"])):
        if sum(e["zones"].values()):
            out.append({"name": e["name"], "skill": e["skill"], "zones": dict(sorted(e["zones"].items()))})
    return out


def mines(pf, db):
    """Ore nodes, one entry per ore and skill: the vein's name (the commonest,
    so not "Ooze Covered ..."), the ore it always yields, the skill it
    needs, and its spawns per zone. A node whose sure drop is a quest item
    (Lesser Bloodstone) is left out."""
    meta = lua_meta(pf.path("db_meta.lua"), "mines")
    spawns = pf.spawns("objects", set(meta))
    loot_id = {num(r["entry"]): num(r["data1"]) for r in db.rows("gameobject_template") if num(r["entry"]) in meta}
    items = {num(r["entry"]): (r["name"], num(r["class"])) for r in db.rows("item_template")}
    sure = {}
    for r in db.rows("gameobject_loot_template"):
        if num(r["mincountOrRef"]) > 0 and num(r["ChanceOrQuestChance"]) >= 100:
            sure[num(r["entry"])] = items.get(num(r["item"]))
    TRADE_GOODS = 7
    merged = {}
    for oid, skill in meta.items():
        name, ore = pf.objects.get(oid), sure.get(loot_id.get(oid))
        if not name or not ore or ore[1] != TRADE_GOODS:
            continue
        entry = merged.setdefault((ore[0], max(1, skill)), {
            "ore": ore[0], "skill": max(1, skill), "names": collections.Counter(), "zones": collections.Counter()})
        for z in spawns.get(oid, ([], None))[0]:
            if pf.zone(z):
                entry["zones"][pf.zone(z)] += 1
                entry["names"][name] += 1
    out = []
    for e in sorted(merged.values(), key=lambda e: (e["skill"], e["ore"])):
        if e["names"]:
            name = sorted(e["names"].items(), key=lambda kv: (-kv[1], kv[0]))[0][0]
            out.append({"name": name, "ore": e["ore"], "skill": e["skill"], "zones": dict(sorted(e["zones"].items()))})
    return out


def skinning(pf, db):
    """zone -> { level: spawns } of the normal-rank creatures that can be
    skinned. Elites are left out: a gathering guide should not send anyone
    to fight them."""
    mobs = {}
    for r in db.rows("creature_template"):
        if num(r.get("SkinningLootId")) > 0 and num(r.get("Rank")) == 0:
            lo, hi = num(r.get("MinLevel")), num(r.get("MaxLevel"))
            mobs[num(r["Entry"])] = (lo + hi) // 2
    spawns = pf.spawns("units", set(mobs))
    out = collections.defaultdict(collections.Counter)
    for uid, level in mobs.items():
        for z in spawns.get(uid, ([], None))[0]:
            if pf.zone(z):
                out[pf.zone(z)][level] += 1
    return {zone: {str(l): n for l, n in sorted(c.items())} for zone, c in sorted(out.items())}


def fishing(pf, db):
    out = {}
    for r in db.rows("skill_fishing_base_level"):
        name = pf.zone(num(r["entry"]))
        if name:
            out[name] = num(r["skill"])
    return dict(sorted(out.items()))


def who(pf, entries, names):
    """Split NPCs by the faction pfQuest gives them, with the zone they
    stand in: { "Alliance": [ {name, zone} ], "Horde": [ ... ] }."""
    spawns = pf.spawns("units", set(entries))
    sides = {"Alliance": [], "Horde": []}
    for e in sorted(entries, key=lambda e: names.get(e, "")):
        zones, fac = spawns.get(e, ([], None))
        zone = next((pf.zone(z) for z in zones if pf.zone(z)), None)
        if not zone or e not in names:
            continue
        person = {"name": names[e], "zone": zone}
        if fac in (None, "AH", "A"):
            sides["Alliance"].append(person)
        if fac in (None, "AH", "H"):
            sides["Horde"].append(person)
    return sides


def trainers(pf, db):
    names, titles = {}, {}
    for r in db.rows("creature_template"):
        names[num(r["Entry"])] = r["Name"]
        titles[num(r["Entry"])] = r.get("SubName") or ""
    taught = []
    for table in ("npc_trainer", "npc_trainer_template"):
        for r in db.rows(table):
            taught.append(r)

    out = {}
    for prof, line in SKILL_LINE.items():
        ranks = {}
        # The rank spells: taught at skill 50/125/200 of this profession,
        # and at 0 by NPCs titled for it.
        for r in taught:
            e, rv = num(r["entry"]), num(r["reqskillvalue"])
            rank = None
            if num(r["reqskill"]) == line and rv in (50, 125, 200):
                rank = {50: "Journeyman", 125: "Expert", 200: "Artisan"}[rv]
            elif rv == 0 and num(r["reqskill"]) == 0 and TRAINER_TITLE[prof] in titles.get(e, "") \
                    and num(r["spellcost"]) <= 100:
                rank = "Apprentice"
            if rank:
                info = ranks.setdefault(rank, {"spell": num(r["spell"]), "cost": num(r["spellcost"]),
                                               "level": num(r["reqlevel"]), "skill": RANK_SKILL[rank],
                                               "entries": set()})
                if num(r["spell"]) == info["spell"]:
                    info["entries"].add(e)
        # Everyone who teaches each rank's spell, whatever their title.
        for r in taught:
            for info in ranks.values():
                if num(r["spell"]) == info["spell"]:
                    info["entries"].add(num(r["entry"]))
        out[prof] = {}
        for rank in ("Apprentice", "Journeyman", "Expert", "Artisan"):
            if rank in ranks:
                info = ranks[rank]
                sides = who(pf, info["entries"], names)
                out[prof][rank] = {"spell": info["spell"], "level": info["level"], "cost": info["cost"],
                                   "skill": info["skill"],
                                   "Alliance": sides["Alliance"], "Horde": sides["Horde"]}
    return out, names


def fishing_book(pf, db, names):
    item = next((r for r in db.rows("item_template") if r.get("name") == EXPERT_FISHING_BOOK), None)
    if not item:
        return None
    sellers = {num(r["entry"]) for r in db.rows("npc_vendor") if num(r["item"]) == num(item["entry"])}
    sides = who(pf, sellers, names)
    return {"name": EXPERT_FISHING_BOOK, "cost": num(item.get("BuyPrice")),
            "skill": num(item.get("RequiredSkillRank")), "Alliance": sides["Alliance"], "Horde": sides["Horde"]}


def fishing_quest(pf, db, names):
    quest = next((r for r in db.rows("quest_template") if r.get("Title") == ARTISAN_FISHING_QUEST), None)
    if not quest:
        return None
    qid = num(quest["entry"])
    items = {}
    for k in range(1, 5):
        iid = num(quest.get("ReqItemId%d" % k))
        if iid:
            items[iid] = None
    for r in db.rows("item_template"):
        if num(r["entry"]) in items:
            items[num(r["entry"])] = r["name"]
    where = collections.defaultdict(set)
    for r in db.rows("fishing_loot_template"):
        if num(r["item"]) in items and pf.zone(num(r["entry"])):
            where[num(r["item"])].add(pf.zone(num(r["entry"])))
    givers = [num(r["id"]) for r in db.rows("creature_questrelation") if num(r["quest"]) == qid]
    giver = who(pf, givers, names)
    person = (giver["Alliance"] or giver["Horde"] or [None])[0]

    def zone_of(fish):
        # The loot table gives subzones only; the quest text says whose:
        # "Feralas Ahi from the Verdantis River of Feralas."
        m = re.search(re.escape(fish) + r" from the .+? (?:in|of) (?:the )?(.+?)\.", quest.get("Objectives") or "")
        return m and m.group(1)

    return {"title": ARTISAN_FISHING_QUEST, "level": num(quest.get("MinLevel")),
            "skill": num(quest.get("RequiredSkillValue")), "giver": person,
            "fish": [{"name": items[i], "zone": zone_of(items[i]), "where": sorted(where[i])}
                     for i in sorted(items, key=lambda i: items[i])]}


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--pfquest", required=True, nargs="+",
                    help="pfQuest and pfQuest-turtle checkouts (or one folder of their db files)")
    ap.add_argument("--cmangos", required=True, help="CMaNGOS classic-db full dump (.sql or .sql.gz)")
    ap.add_argument("--check", action="store_true", help="extract and report; write nothing")
    args = ap.parse_args()

    pf = PfQuest(args.pfquest)
    db = Dump(args.cmangos)
    training, names = trainers(pf, db)
    data = {
        "_about": "Facts behind the Herbalism, Skinning and Fishing guides and Mining's ore, extracted by "
                  "Tools/build/build_gathering.py from pfQuest (with pfQuest-turtle) and CMaNGOS "
                  "classic-db. Read by Tools/build/convert_professions.py.",
        "herbs": herbs(pf),
        "mines": mines(pf, db),
        "skinning": skinning(pf, db),
        "fishing": fishing(pf, db),
        "trainers": training,
        "fishingBook": fishing_book(pf, db, names),
        "fishingQuest": fishing_quest(pf, db, names),
    }
    print("herbs: %d kinds; ores: %d kinds; skinnable mobs in %d zones; fishing skill for %d zones" % (
        len(data["herbs"]), len(data["mines"]), len(data["skinning"]), len(data["fishing"])))
    for prof, ranks in data["trainers"].items():
        print("  %-10s %s" % (prof, ", ".join("%s %d/%d" % (r, len(v["Alliance"]), len(v["Horde"]))
                                             for r, v in ranks.items())))
    print("  Expert fishing book: %s" % (data["fishingBook"] and ", ".join(
        p["name"] for p in data["fishingBook"]["Alliance"] + data["fishingBook"]["Horde"])))
    print("  Artisan fishing quest: %s" % (data["fishingQuest"] and data["fishingQuest"]["giver"]))
    if not args.check:
        with open(OUT, "w", encoding="utf-8") as fh:
            json.dump(data, fh, indent=1, ensure_ascii=False, sort_keys=False)
            fh.write("\n")
        print("wrote %s" % os.path.relpath(OUT, ROOT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
