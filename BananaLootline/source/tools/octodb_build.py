#!/usr/bin/env python3
"""
octodb_build.py - Exportdateien in Addon-Daten umwandeln

Nutzung:
    python3 octodb_build.py ./exports -o ../Data

Nimmt alle JSON-Dateien im Ordner und erzeugt:
    Data/ItemData.lua   Items: Slot, Qualitaet, Masken, Werte, Effekte
    Data/SetData.lua    Sets: Mitglieder und Boni

Erkennt automatisch, ob eine Datei Items ("items") oder Sets ("sets")
enthaelt. Liegen mehrere Dateien zum selben Item vor, gewinnt die
reichhaltigere - so ueberschreibt ein spaeterer, vollstaendigerer Lauf
einen frueheren, ohne dass man aufraeumen muss.

WICHTIG ZUM DOPPELZAEHLEN
Equip-Effekte stehen bereits in den Werten: "Equip: Increases attack power
by 40" landet als AP=40 in stats UND als Effekt in effects. Beim Bauen
werden Equip-Effekte deshalb NICHT in eigene Werte umgerechnet - sonst
zaehlte das Addon sie doppelt. Nur Use-Effekte sind zusaetzlich, weil der
Exporter sie bewusst aus den Werten heraushaelt.
"""

import argparse
import json
import os
import re
import sys
import time

# ---------------------------------------------------------------------------
# Bonustexte in Werte uebersetzen
#
# Setboni stehen nur als Text da. Was sich sauber in eine Zahl aufloesen
# laesst, wird uebersetzt; der Rest bleibt Text und fliesst nicht in die
# Bewertung ein. Lieber nicht bewerten als raten.
# ---------------------------------------------------------------------------

BONUS_PATTERNS = [
    ("STR",        r"\+(\d+)\s+Strength"),
    ("AGI",        r"\+(\d+)\s+Agility"),
    ("STA",        r"\+(\d+)\s+Stamina"),
    ("INT",        r"\+(\d+)\s+Intellect"),
    ("SPI",        r"\+(\d+)\s+Spirit"),
    ("ARMOR",      r"\+(\d+)\s+Armor"),
    ("AP",         r"\+(\d+)\s+Attack Power"),
    ("AP",         r"[Aa]ttack [Pp]ower by (\d+)"),
    ("RAP",        r"[Rr]anged [Aa]ttack [Pp]ower by (\d+)"),
    ("SPELLPOWER", r"damage and healing done by magical spells.{0,40}?by up to (\d+)"),
    ("SPELLPOWER", r"\+(\d+)\s+Spell Damage"),
    ("HEALPOWER",  r"healing done by spells.{0,40}?by up to (\d+)"),
    ("CRIT",       r"chance to get a critical strike by (\d+)"),
    ("SPELLCRIT",  r"critical strike with spells by (\d+)"),
    ("HIT",        r"chance to hit by (\d+)"),
    ("SPELLHIT",   r"chance to hit with spells by (\d+)"),
    ("DEFENSE",    r"[Dd]efense(?: rating)? by (\d+)"),
    ("DODGE",      r"chance to dodge.{0,20}?by (\d+)"),
    ("PARRY",      r"chance to parry.{0,20}?by (\d+)"),
    ("BLOCK",      r"chance to block.{0,20}?by (\d+)"),
    ("MP5",        r"(\d+) mana per 5"),
    ("MP5",        r"(\d+) mana every 5"),
    ("HP5",        r"(\d+) health every 5"),
    ("RES_FIRE",   r"\+(\d+)\s+Fire Resistance"),
    ("RES_FROST",  r"\+(\d+)\s+Frost Resistance"),
    ("RES_NATURE", r"\+(\d+)\s+Nature Resistance"),
    ("RES_SHADOW", r"\+(\d+)\s+Shadow Resistance"),
    ("RES_ARCANE", r"\+(\d+)\s+Arcane Resistance"),
]

ALL_RES = ["RES_FIRE", "RES_FROST", "RES_NATURE", "RES_SHADOW", "RES_ARCANE"]


def bonus_to_stats(text):
    """Bonustext -> Werte. Leeres Ergebnis heisst: nicht bezifferbar."""
    stats = {}

    m = re.search(r"\+(\d+)\s+All Resistances", text, re.I)
    if m:
        for r in ALL_RES:
            stats[r] = int(m.group(1))

    for key, pat in BONUS_PATTERNS:
        if key in stats:
            continue
        m = re.search(pat, text, re.I)
        if m:
            stats[key] = int(m.group(1))

    return stats


# ---------------------------------------------------------------------------
# Lua schreiben
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Equip-Effekte nachtragen
#
# Der Browserexport uebernimmt Equip-Effekte nur in der Langform in die
# Werte ("Increases attack power by 40"). Die Kurzform ("+14 Attack Power.",
# "Increased Defense +4.") blieb reiner Effekttext. Folge: 696 Items ohne
# Angriffskraft, 360 ohne Verteidigung. Nachgetragen wird NUR, was in stats
# noch fehlt - sonst zaehlte die Langform doppelt.
# ---------------------------------------------------------------------------

EQUIP_PATTERNS = [
    ("RAP",        r"\+(\d+) ranged attack power|ranged attack power by (\d+)"),
    ("AP",         r"\+(\d+) attack power|(?<!ranged )attack power by (\d+)"),
    ("DEFENSE",    r"defense \+(\d+)|defense by (\d+)"),
    ("BLOCK",      r"chance to block attacks with a shield by (\d+)%"),
    ("BLOCKVALUE", r"block value of your shield by (\d+)"),
    ("HP5",        r"(\d+) health per 5|(\d+) health every 5"),
    ("MP5",        r"(\d+) mana per 5|(\d+) mana every 5"),
    ("CRIT",       r"chance to get a critical strike by (\d+)%"),
    ("HIT",        r"chance to hit by (\d+)%"),
    ("DODGE",      r"chance to dodge an attack by (\d+)%"),
    ("PARRY",      r"chance to parry an attack by (\d+)%"),
]

# Saetze mit Bedingung sind keine dauerhaften Werte:
#   "+72 Attack Power when fighting Beasts."           nur gegen Wildtiere
#   "+406 Attack Power in Cat, Bear ... forms only."   nur Druiden in Gestalt
#   "... increasing Defense by 10 for 10 sec."         Proc, kein Dauerwert
# Als Dauerwert gezaehlt, bekam jeder Krieger einen Druidenkolben mit
# 406 Angriffskraft vorgeschlagen. Solche Saetze werden uebersprungen.
CONDITIONAL = re.compile(
    r"when fighting|forms? only|versus|bonus against|against (?:undead|demons|beasts)"
    r"|for \d+ sec|\d+% chance|chance when|chance on|when struck|stacks|successfully|blocking an attack"
    r"|melee attacks against you",
    re.I)

def unconditional(text):
    """Nur die Saetze eines Effekts, die ohne Bedingung gelten."""
    parts = re.split(r"(?<=\.)\s+", text)
    return " ".join(p for p in parts if not CONDITIONAL.search(p))

def equip_to_stats(text):
    """Equip-Effekttext -> Werte. Mehrere Saetze pro Effekt moeglich."""
    out = {}
    t = unconditional(text).lower()
    # Sonderfall: ein Satz, zwei Werte
    m = re.search(r"chance to hit and get a critical strike with spells by (\d+)%", t)
    if m:
        out["SPELLHIT"] = out["SPELLCRIT"] = int(m.group(1))
    for key, pat in EQUIP_PATTERNS:
        m = re.search(pat, t)
        if m:
            val = next(g for g in m.groups() if g is not None)
            out[key] = out.get(key, 0) + int(val)
    return out


def merged_stats(e):
    """Werte des Exports plus fehlende Equip-Werte."""
    stats = dict(e.get("stats") or {})

    # Angriffskraft ohne zugehoerigen Effekttext stammt aus einem Setbonus,
    # den der Browserexport jedem Teil einzeln zugeschrieben hat (T3-Jaeger:
    # AP 50 auf allen neun Teilen). Der Bonus kommt ueber SetData.lua;
    # hier gezaehlt, landete er doppelt und pro Teil.
    effect_text = " ".join(x.get("text", "") for x in e.get("effects") or []).lower()
    for key in ("AP", "RAP"):
        if key in stats and "attack power" not in effect_text:
            del stats[key]

    extra = {}
    for x in e.get("effects") or []:
        if x.get("kind") != "equip":
            continue
        for k, v in equip_to_stats(x.get("text", "")).items():
            if k not in stats:
                extra[k] = extra.get(k, 0) + v
    stats.update(extra)
    return stats, extra


def lua_str(v):
    return '"%s"' % str(v).replace("\\", "\\\\").replace('"', '\\"')


def lua_num(v):
    if isinstance(v, float) and v == int(v):
        return str(int(v))
    return str(v)


def stats_to_lua(stats):
    return "{" + ",".join("%s=%s" % (k, lua_num(v))
                          for k, v in sorted(stats.items())) + "}"


def write_items(items, path):
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("-- Automatisch erzeugt von tools/octodb_build.py\n")
        fh.write("-- Quelle: OctoWoW-Datenbank (octowow.st/db)\n")
        fh.write("-- Erzeugt: %s\n" % time.strftime("%Y-%m-%d %H:%M:%S"))
        fh.write("-- Eintraege: %d\n" % len(items))
        fh.write("-- REINE DATEN. Nicht von Hand bearbeiten, nicht nach\n")
        fh.write("-- ItemDB.lua kopieren - das ist die Lesefunktion.\n\n")
        fh.write("BananaLootlineItemData = {\n")

        for item_id in sorted(items):
            e = items[item_id]
            parts = []
            if e.get("name"):
                parts.append("name=" + lua_str(e["name"]))
            for key, src in (("ilvl", "level"), ("quality", "quality"),
                             ("slot", "slot"), ("reqlevel", "reqlevel"),
                             ("itemclass", "classs"), ("subclass", "subclass"),
                             ("classmask", "classmask"), ("racemask", "racemask")):
                if e.get(src) is not None:
                    parts.append("%s=%s" % (key, lua_num(e[src])))

            stats, _ = merged_stats(e)
            if stats:
                parts.append("stats=" + stats_to_lua(stats))

            # Nur Use-Effekte mitnehmen. Equip steckt schon in den Werten,
            # Chance-on-hit ist ohne Ausloesewahrscheinlichkeit nicht
            # bewertbar und wuerde nur Platz kosten.
            uses = [x for x in e.get("effects", []) if x.get("kind") == "use"]
            if uses:
                chunks = []
                for u in uses:
                    f = []
                    if u.get("value") is not None:
                        f.append("v=" + lua_num(u["value"]))
                    if u.get("duration") is not None:
                        f.append("d=" + lua_num(u["duration"]))
                    if u.get("cooldown") is not None:
                        f.append("cd=" + lua_num(u["cooldown"]))
                    f.append("t=" + lua_str(u.get("text", "")[:120]))
                    chunks.append("{" + ",".join(f) + "}")
                parts.append("use={" + ",".join(chunks) + "}")

            fh.write("[%d]={%s},\n" % (item_id, ",".join(parts)))

        fh.write("}\n")

    return os.path.getsize(path)


def write_sets(sets, path):
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("-- Automatisch erzeugt von tools/octodb_build.py\n")
        fh.write("-- Itemsets und ihre Boni. Erzeugt: %s\n"
                 % time.strftime("%Y-%m-%d %H:%M:%S"))
        fh.write("-- Eintraege: %d\n\n" % len(sets))
        fh.write("BananaLootlineSetData = {\n")

        for set_id in sorted(sets):
            s = sets[set_id]
            items = ",".join(str(i) for i in s.get("items", []))

            bonuses = []
            for b in s.get("bonuses", []):
                st = bonus_to_stats(b.get("text", ""))
                f = ["p=%d" % b["pieces"]]
                if st:
                    f.append("stats=" + stats_to_lua(st))
                f.append("t=" + lua_str(b.get("text", "")[:110]))
                bonuses.append("{" + ",".join(f) + "}")

            fh.write('[%d]={name=%s,items={%s},bonuses={%s}},\n'
                     % (set_id, lua_str(s.get("name", "")), items,
                        ",".join(bonuses)))

        fh.write("}\n")

    return os.path.getsize(path)


# ---------------------------------------------------------------------------
# Einlesen
# ---------------------------------------------------------------------------

def richness(item):
    """Wie vollstaendig ist ein Eintrag? Entscheidet bei Doppelungen."""
    return (len(item.get("stats") or {})
            + 3 * len(item.get("effects") or [])
            + (1 if item.get("classmask") is not None else 0))


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("source", help="Ordner mit den JSON-Exporten")
    ap.add_argument("-o", "--out", default="../Data", help="Zielordner (Standard: ../Data)")
    args = ap.parse_args()

    files = []
    if os.path.isdir(args.source):
        for n in sorted(os.listdir(args.source)):
            if n.lower().endswith(".json"):
                files.append(os.path.join(args.source, n))
    else:
        files = [args.source]

    if not files:
        sys.exit("Keine JSON-Dateien gefunden.")

    items, sets = {}, {}

    for f in files:
        with open(f, encoding="utf-8") as fh:
            try:
                payload = json.load(fh)
            except json.JSONDecodeError as e:
                print("  ! %s ist kein gueltiges JSON: %s" % (os.path.basename(f), e))
                continue

        if isinstance(payload, dict) and payload.get("sets"):
            n = 0
            for s in payload["sets"]:
                if s.get("id") is None:
                    continue
                sets[int(s["id"])] = s
                n += 1
            print("  %-42s %5d Sets" % (os.path.basename(f), n))
            continue

        rows = payload.get("items") if isinstance(payload, dict) else payload
        if not isinstance(rows, list):
            print("  ! %s: weder Items noch Sets" % os.path.basename(f))
            continue

        added = replaced = 0
        for r in rows:
            if not isinstance(r, dict) or r.get("id") is None:
                continue
            iid = int(r["id"])
            if iid in items:
                if richness(r) > richness(items[iid]):
                    items[iid] = r
                    replaced += 1
            else:
                items[iid] = r
                added += 1
        print("  %-42s %5d neu, %d ersetzt" % (os.path.basename(f), added, replaced))

    if not items and not sets:
        sys.exit("Nichts einzulesen.")

    os.makedirs(args.out, exist_ok=True)

    print()
    if items:
        size = write_items(items, os.path.join(args.out, "ItemData.lua"))
        with_stats = sum(1 for e in items.values() if e.get("stats"))
        with_use = sum(1 for e in items.values()
                       if any(x.get("kind") == "use" for x in e.get("effects", [])))
        print("ItemData.lua: %d Items (%.0f KB), %d mit Werten, %d mit Use-Effekt"
              % (len(items), size / 1024.0, with_stats, with_use))
        added = {}
        for e in items.values():
            for k in merged_stats(e)[1]:
                added[k] = added.get(k, 0) + 1
        if added:
            print("  aus Equip-Effekten nachgetragen: "
                  + ", ".join("%s %d" % (k, n) for k, n in sorted(added.items())))

    if sets:
        size = write_sets(sets, os.path.join(args.out, "SetData.lua"))
        nb = sum(len(s.get("bonuses", [])) for s in sets.values())
        scored = sum(1 for s in sets.values() for b in s.get("bonuses", [])
                     if bonus_to_stats(b.get("text", "")))
        print("SetData.lua:  %d Sets (%.0f KB), %d Boni, davon %d bezifferbar"
              % (len(sets), size / 1024.0, nb, scored))

    print("\nDanach im Spiel: /reload, dann /bll info")


if __name__ == "__main__":
    main()
