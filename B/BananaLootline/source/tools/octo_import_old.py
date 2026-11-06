#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Importer fuer den OctoWoW-Datenbankauszug.

Verarbeitet die JSON-Dateien, die das Browserskript auf octowow.st/db
erzeugt, und schreibt daraus zwei Lua-Datendateien:

    Data/ItemData.lua     Werte je Gegenstand (wie bisher)
    Data/SourceData.lua   Fundorte, Haendler, Questbelohnungen, Sperren

Warum ueberhaupt:
pfQuest liefert Fundorte aus dem Vanilla-Datenstand. Von 17712 dort
verzeichneten Gegenstaenden hat pfQuest-octo nur 3292 ueberschrieben -
fuer den Rest gelten Angaben, die dieser Server geaendert hat. Beispiel
"Feet of the Lynx": pfQuest nennt einen einzigen Gegner jenseits von
Stufe 60 mit 1,92 %, die Serverdatenbank kennt 473 Gegner zwischen
Stufe 15 und 35, keinen ueber 0,0045 %.

Aufruf:
    python3 tools/octo_import.py exports/*.json -o Data/
    python3 tools/octo_import.py exports/ --csv drops.csv -o Data/
"""

import argparse, csv, glob, json, os, re, sys
from collections import defaultdict

# ---------------------------------------------------------------- Werte

# Dieselben Muster, die Scanner.lua zur Laufzeit benutzt - hier aber
# einmal beim Import statt tausendfach im Spiel. Reihenfolge zaehlt:
# das erste passende Muster je Zeile gewinnt.
PATTERNS = [
    ("STR",   r"^\+(\d+) Strength"),
    ("AGI",   r"^\+(\d+) Agility"),
    ("STA",   r"^\+(\d+) Stamina"),
    ("INT",   r"^\+(\d+) Intellect"),
    ("SPI",   r"^\+(\d+) Spirit"),
    ("STR",   r"^\-(\d+) Strength",   -1),
    ("AGI",   r"^\-(\d+) Agility",    -1),
    ("STA",   r"^\-(\d+) Stamina",    -1),
    ("INT",   r"^\-(\d+) Intellect",  -1),
    ("SPI",   r"^\-(\d+) Spirit",     -1),
    ("ARMOR", r"^(\d+) Armor"),
    ("BLOCKVALUE", r"^(\d+) Block"),
    ("RES_FIRE",   r"^\+(\d+) Fire Resistance"),
    ("RES_FROST",  r"^\+(\d+) Frost Resistance"),
    ("RES_NATURE", r"^\+(\d+) Nature Resistance"),
    ("RES_SHADOW", r"^\+(\d+) Shadow Resistance"),
    ("RES_ARCANE", r"^\+(\d+) Arcane Resistance"),
    # Distanz vor Nahkampf: "ranged attack power by 24" passt sonst auf
    # das AP-Muster und zaehlte als Nahkampfkraft.
    ("RAP",   r"[Rr]anged [Aa]ttack [Pp]ower by (\d+)"),
    ("AP",    r"[Aa]ttack [Pp]ower by (\d+)"),
    ("SPELLPOWER",        r"damage and healing done by magical spells.{0,40}?(\d+)"),
    ("SPELLPOWER_ARCANE", r"Arcane spells and effects by up to (\d+)"),
    ("SPELLPOWER_FIRE",   r"Fire spells and effects by up to (\d+)"),
    ("SPELLPOWER_FROST",  r"Frost spells and effects by up to (\d+)"),
    ("SPELLPOWER_HOLY",   r"Holy spells and effects by up to (\d+)"),
    ("SPELLPOWER_NATURE", r"Nature spells and effects by up to (\d+)"),
    ("SPELLPOWER_SHADOW", r"Shadow spells and effects by up to (\d+)"),
    ("HEALPOWER", r"healing done by spells and effects.{0,40}?(\d+)"),
    ("SPELLCRIT", r"chance to get a critical strike with spells by (\d+)"),
    ("CRIT",      r"chance to get a critical strike by (\d+)"),
    ("SPELLHIT",  r"chance to hit with spells by (\d+)"),
    ("HIT",       r"chance to hit by (\d+)"),
    ("DEFENSE",   r"[Dd]efense.{0,20}?\+?(\d+)"),
    ("DODGE",     r"chance to dodge.{0,20}?(\d+)"),
    ("PARRY",     r"chance to parry.{0,20}?(\d+)"),
    ("BLOCK",     r"chance to block.{0,20}?(\d+)"),
    ("MP5",       r"(\d+) mana per 5"),
    ("MP5",       r"(\d+) mana every 5"),
    ("HP5",       r"(\d+) health every 5"),
    ("WEAPON_SPEED", r"^Speed (\d+\.\d+)"),
    ("WEAPON_DPS",   r"\((\d+\.\d+) damage per second\)"),
]
DMG = re.compile(r"^(\d+) - (\d+) Damage")

# Zeilen, die gar nicht erst geprueft werden
SKIP = ("Requires Level", "Soulbound", "Binds when", "Unique", "Durability")

# Rufstufen und Rangbegriffe: was hier steht, ist eine Zugangsbedingung
# und keine Fundortangabe.
STANDINGS = ("Hated", "Hostile", "Unfriendly", "Neutral", "Friendly",
             "Honored", "Revered", "Exalted")


def _is_rep(line):
    """Nennt die Zeile eine Ruf- oder Rangstufe?"""
    return bool(line) and (any(s in line for s in STANDINGS) or "Rank" in line)


def parse_tooltip(lines):
    """Werte, Zugangsbedingung und unbezifferte Effekte aus dem Tooltip."""
    stats, lock, unscored = {}, None, []
    for raw in lines or []:
        line = (raw or "").strip()
        if not line or line.startswith('"'):
            continue
        if any(line.startswith(s) for s in SKIP):
            continue

        m = DMG.match(line)
        if m:
            stats["WEAPON_MIN"] = int(m.group(1))
            stats["WEAPON_MAX"] = int(m.group(2))
            continue

        hit = False
        for entry in PATTERNS:
            key, pat = entry[0], entry[1]
            sign = entry[2] if len(entry) > 2 else 1
            m = re.search(pat, line)
            if m:
                val = float(m.group(1))
                val = int(val) if val == int(val) else val
                stats[key] = stats.get(key, 0) + val * sign
                hit = True
                break
        if hit:
            continue

        # Bedingung? "Requires <etwas anderes als eine Stufe>"
        #
        # Ein Gegenstand kann mehrere tragen, etwa
        #   Requires Leatherworking (300)
        #   Requires Elemental Leatherworking
        #   Requires Wildhammer Clan - Exalted
        # Ruf und Rang wiegen schwerer als ein Beruf: einen Beruf kann
        # ein Mitspieler beisteuern, Ruf muss man selbst erarbeiten.
        # Deshalb ueberschreibt eine Rufzeile eine bereits gefundene
        # Berufszeile, umgekehrt nicht.
        is_rep = any(s in line for s in STANDINGS) or "Rank" in line
        if line.startswith("Requires") or (is_rep and " - " in line):
            if lock is None or (is_rep and not _is_rep(lock)):
                lock = line
            continue
        if "chance" in line.lower() or line.startswith("Use:"):
            unscored.append(line)

    return stats, lock, unscored


# ---------------------------------------------------------------- Lua

def lua_str(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"') + '"'


def lua_num(v):
    if isinstance(v, float):
        return ("%.4f" % v).rstrip("0").rstrip(".")
    return str(v)


def write_items(items, path):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("-- Automatisch erzeugt von tools/octo_import.py\n")
        f.write("-- Quelle: OctoWoW-Datenbank (octowow.st/db)\n")
        f.write("-- Eintraege: %d\n" % len(items))
        f.write("-- REINE DATEN. Nicht von Hand bearbeiten.\n\n")
        f.write("BananaLootlineItemData = {\n")
        for iid in sorted(items):
            it = items[iid]
            parts = ["name=" + lua_str(it["name"])]
            for key in ("ilvl", "quality", "slot", "reqlevel",
                        "itemclass", "subclass", "classmask", "racemask"):
                if it.get(key) is not None:
                    parts.append("%s=%s" % (key, lua_num(it[key])))
            if it.get("stats"):
                inner = ",".join("%s=%s" % (k, lua_num(v))
                                 for k, v in sorted(it["stats"].items()))
                parts.append("stats={%s}" % inner)
            f.write("[%d]={%s},\n" % (iid, ",".join(parts)))
        f.write("}\n")


def write_sources(src, npcs, path):
    """
    Fundorte, Haendler, Questbelohnungen und Sperren.

    Aufbau je Gegenstand:
        d = { {n=NpcID, l=Stufe, z=Zone, p=Chance}, ... }   Drops
        v = { {n=NpcID, l=Stufe, z=Zone, r=Fraktion}, ... } Haendler
        q = { {i=QuestID, l=Stufe, s=Seite}, ... }          Quest
        k = "Zugangsbedingung"
    """
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("-- Automatisch erzeugt von tools/octo_import.py\n")
        f.write("-- Fundorte aus der OctoWoW-Datenbank\n")
        f.write("-- Eintraege: %d\n\n" % len(src))

        f.write("BananaLootlineNpcNames = {\n")
        for nid in sorted(npcs):
            f.write("[%d]=%s,\n" % (nid, lua_str(npcs[nid])))
        f.write("}\n\n")

        f.write("BananaLootlineSourceData = {\n")
        for iid in sorted(src):
            e = src[iid]
            parts = []
            if e.get("d"):
                rows = ",".join(
                    "{n=%d,l=%s,z=%s,p=%s}" % (r["n"], lua_num(r["l"]),
                                               lua_num(r["z"]), lua_num(r["p"]))
                    for r in e["d"])
                parts.append("d={%s}" % rows)
            if e.get("v"):
                rows = ",".join(
                    "{n=%d,l=%s,z=%s,r=%s}" % (r["n"], lua_num(r["l"]),
                                               lua_num(r["z"]), lua_num(r["r"]))
                    for r in e["v"])
                parts.append("v={%s}" % rows)
            if e.get("q"):
                rows = ",".join(
                    "{i=%d,l=%s,s=%s}" % (r["i"], lua_num(r["l"]), lua_num(r["s"]))
                    for r in e["q"])
                parts.append("q={%s}" % rows)
            if e.get("k"):
                parts.append("k=" + lua_str(e["k"]))
            if parts:
                f.write("[%d]={%s},\n" % (iid, ",".join(parts)))
        f.write("}\n")


# ---------------------------------------------------------------- Lauf

def load_json_files(paths):
    out = []
    for p in paths:
        if os.path.isdir(p):
            out.extend(sorted(glob.glob(os.path.join(p, "*.json"))))
        else:
            out.extend(sorted(glob.glob(p)))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("inputs", nargs="+", help="JSON-Dateien oder ein Ordner")
    ap.add_argument("--csv", help="zusaetzliche Dropliste als CSV")
    ap.add_argument("-o", "--out", default="Data", help="Zielordner")
    args = ap.parse_args()

    items, src, npcs = {}, defaultdict(dict), {}
    seen_files = 0

    for path in load_json_files(args.inputs):
        seen_files += 1
        data = json.load(open(path, encoding="utf-8"))
        for it in data.get("items", []):
            iid = int(it["id"])
            stats, lock, _ = parse_tooltip(it.get("tooltip"))

            # Der Ruestungswert steht als eigenes Feld und im Tooltip.
            # Das Feld ist verlaesslicher.
            if it.get("armor"):
                stats["ARMOR"] = it["armor"]

            cm = it.get("facts", {}).get("Class Mask")
            rm = it.get("facts", {}).get("Race Mask")
            items[iid] = {
                "name": it.get("name") or ("Item %d" % iid),
                "ilvl": it.get("level"),
                "reqlevel": it.get("reqlevel") or 0,
                "quality": it.get("quality"),
                "slot": it.get("slot"),
                "itemclass": it.get("classs"),
                "subclass": it.get("subclass"),
                "classmask": int(cm) if cm not in (None, "") else None,
                "racemask": int(rm) if rm not in (None, "") else None,
                "stats": stats,
            }

            e = src[iid]
            if lock:
                e["k"] = lock

            for row in it.get("droppedBy") or []:
                npcs[int(row["npcId"])] = row.get("npc") or "?"
                e.setdefault("d", []).append({
                    "n": int(row["npcId"]),
                    "l": row.get("maxlevel") or row.get("minlevel") or 0,
                    "z": (row.get("location") or [0])[0],
                    "p": row.get("percent") or 0,
                })

            for row in (it.get("sources") or {}).get("sold-by", []):
                npcs[int(row["id"])] = row.get("name") or "?"
                react = row.get("react") or [0, 0]
                # react[0] Allianz, react[1] Horde: 1 = freundlich
                side = 3 if (react[0] > 0 and react[1] > 0) else (
                       1 if react[0] > 0 else 2)
                e.setdefault("v", []).append({
                    "n": int(row["id"]),
                    "l": row.get("maxlevel") or row.get("minlevel") or 0,
                    "z": (row.get("location") or [0])[0],
                    "r": side,
                })

            for row in (it.get("sources") or {}).get("reward-of", []):
                e.setdefault("q", []).append({
                    "i": int(row["id"]),
                    "l": int(row.get("level") or 0),
                    "s": int(row.get("side") or 0),
                })

    # CSV ergaenzt nur Drops
    if args.csv:
        with open(args.csv, encoding="utf-8-sig") as fh:
            for row in csv.DictReader(fh, delimiter=";"):
                iid = int(row["itemId"])
                nid = int(row["npcId"])
                npcs[nid] = row.get("npcName") or "?"
                have = src[iid].setdefault("d", [])
                if not any(r["n"] == nid for r in have):
                    have.append({
                        "n": nid,
                        "l": int(row.get("npcMaxLevel") or row.get("npcMinLevel") or 0),
                        "z": int((row.get("zones") or "0").split(",")[0] or 0),
                        "p": float(row.get("dropPercent") or 0),
                    })

    src = {k: v for k, v in src.items() if v}

    if not os.path.isdir(args.out):
        os.makedirs(args.out)
    write_items(items, os.path.join(args.out, "ItemData.lua"))
    write_sources(src, npcs, os.path.join(args.out, "SourceData.lua"))

    drops = sum(len(v.get("d", [])) for v in src.values())
    vend  = sum(len(v.get("v", [])) for v in src.values())
    quest = sum(len(v.get("q", [])) for v in src.values())
    locks = sum(1 for v in src.values() if v.get("k"))
    withstats = sum(1 for i in items.values() if i["stats"])

    print("Dateien gelesen      : %d" % seen_files)
    print("Gegenstaende         : %d  (%d mit Werten)" % (len(items), withstats))
    print("mit Quellenangabe    : %d" % len(src))
    print("   Drops             : %d" % drops)
    print("   Haendler          : %d" % vend)
    print("   Questbelohnungen  : %d" % quest)
    print("   Zugangsbedingungen: %d" % locks)
    print("Gegner mit Namen     : %d" % len(npcs))
    print()
    print("geschrieben: %s/ItemData.lua und %s/SourceData.lua" % (args.out, args.out))


if __name__ == "__main__":
    main()
