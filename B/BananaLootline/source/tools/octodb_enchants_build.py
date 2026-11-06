#!/usr/bin/env python3
"""
octodb_enchants_build.py - Verzauberungsexport in Addon-Daten umwandeln

Nutzung:
    python3 octodb_enchants_build.py ./exports -o ../Data/EnchantData.lua

Nimmt die JSON-Dateien aus tools/octodb_enchants.js und erzeugt
Data/EnchantData.lua.

Die bisherige EnchantData.lua war von Hand geschrieben und ungeprueft.
Diese hier stammt aus der Datenbank des Servers - inklusive
serverspezifischer Verzauberungen, die in der Handliste fehlten.

Was nicht zugeordnet werden konnte, landet NICHT in der Ausgabe, wird
aber am Ende aufgezaehlt. So sieht man, welche Formulierungen dem
Parser im Browserskript noch fehlen, statt stillschweigend Luecken zu
haben.
"""

import argparse
import json
import os
import re
import sys
import time

# ---------------------------------------------------------------------------
# Beschreibungen neu auswerten
#
# Das Browserskript erkennt nur einen Teil der Formulierungen. Weil es die
# Beschreibung mitspeichert, laesst sich der Rest hier nachholen - ohne
# erneut zu sammeln. Die Datenbank formuliert denselben Effekt auf viele
# Arten: "increase Agility by 7", "grant +7 Agility", "increase the
# wearer's Agility by 7", "add 7 to Agility".
# ---------------------------------------------------------------------------

STAT_WORDS = {
    "strength": "STR", "agility": "AGI", "stamina": "STA",
    "intellect": "INT", "intelligence": "INT", "spirit": "SPI",
}

def _num(m):
    for g in m.groups():
        if g and g.isdigit():
            return int(g)
    return None

def parse_desc(desc):
    """Beschreibung -> (stats, dmg). Leer heisst: nicht auswertbar."""
    if not desc:
        return {}, None

    # NICHT bei "Reagents" abschneiden: auf der Seite steht die
    # Beschreibung HINTER Zutaten und Werkzeug. Genau dieser Schnitt hat
    # im ersten Anlauf 310 Beschreibungen vernichtet. Sicheres Ende ist
    # die Detailtabelle.
    t = re.split(r"Details on spell|Related|Comments|See also", desc)[0]
    # Zutaten und Zauberzeit entfernen, damit ihre Zahlen nicht als
    # Werte gelesen werden ("5 sec cast" waere sonst eine 5).
    t = re.sub(r"\b\d+\s*(?:sec|second|min|minute)s?\s+cast\b", " ", t, flags=re.I)
    t = re.sub(r"\bReagents?\s*:.{0,120}?(?=Tools?\s*:|Permanently|Attaches|Enchants|$)",
               " ", t, flags=re.I)
    t = re.sub(r"\bTools?\s*:.{0,120}?(?=Permanently|Attaches|Enchants|Reagents|$)",
               " ", t, flags=re.I)
    stats, dmg = {}, None

    # Alle Grundwerte auf einmal
    m = re.search(r"(?:\+)?(\d+)\s+to all stats|all stats\s+by\s+(\d+)|"
                  r"grant \+?(\d+) to all stats", t, re.I)
    if m:
        v = _num(m)
        for k in ("STR", "AGI", "STA", "INT", "SPI"):
            stats[k] = v

    # Einzelne Grundwerte, vier Formulierungen
    for word, key in STAT_WORDS.items():
        if key in stats:
            continue
        pats = [
            r"increase[sd]?\s+(?:the\s+)?(?:wearer's\s+)?" + word + r"\s+by\s+(\d+)",
            r"increase[sd]?\s+" + word + r"\s+by\s+(\d+)",
            r"(?:grant|give)s?\s+\+?(\d+)\s+" + word,
            r"add\s+(\d+)\s+to\s+" + word,
            r"\+(\d+)\s+" + word,
            word + r"\s+of the (?:wearer|bearer)\s+by\s+(\d+)",
            r"(?:(?:wearer|bearer)[\u2019\u02bc']s\s+)?" + word + r"\s+by\s+(\d+)",
        ]
        for p in pats:
            mm = re.search(p, t, re.I)
            if mm:
                stats[key] = int(mm.group(1))
                break

    simple = [
        ("ARMOR",      [r"increase[sd]?\s+(?:its\s+)?armor\s+by\s+(\d+)",
                        r"(?:grant|give|provide)s?\s+\+?(\d+)\s+(?:additional points? of\s+)?armor",
                        r"(\d+)\s+additional points? of armor",
                        r"(?:give|grant|provide)s?\s+(\d+)\s+additional armor",
                        r"(?:grant|give)s?\s+\+?(\d+)\s+armor",
                        r"\+(\d+)\s+armor"]),
        ("DEFENSE",    [r"defense skill of the wearer is increased by\s+(\d+)",
                        r"(?:grant|give)s?\s+\+?(\d+)\s+defense",
                        r"increase[sd]?\s+defense\s+by\s+(\d+)"]),
        ("HEALTH",     [r"increase[sd]?\s+the health of the wearer by\s+(\d+)",
                        r"(?:grant|give)s?\s+\+?(\d+)\s+health"]),
        ("MANA",       [r"increase[sd]?\s+the mana of the wearer by\s+(\d+)",
                        r"(?:grant|give)s?\s+\+?(\d+)\s+mana"]),
        ("AP",         [r"attack power by\s+(\d+)", r"\+(\d+)\s+attack power"]),
        ("SPELLPOWER", [r"damage(?: and healing)? done by (?:magical )?spells.{0,40}?by(?: up to)?\s+(\d+)",
                        r"\+(\d+)\s+spell damage"]),
        ("HEALPOWER",  [r"healing done by spells.{0,40}?by(?: up to)?\s+(\d+)"]),
        ("MP5",        [r"(\d+)\s+mana per 5", r"(\d+)\s+mana every 5"]),
        ("BLOCKVALUE", [r"amount blocked by\s+(\d+)", r"\+(\d+)\s+block"]),
        ("CRIT",       [r"critical strike.{0,25}?by\s+(\d+)"]),
        ("HIT",        [r"chance to hit by\s+(\d+)"]),
        ("DODGE",      [r"dodge.{0,25}?by\s+(\d+)"]),
    ]
    for key, pats in simple:
        if key in stats:
            continue
        for p in pats:
            mm = re.search(p, t, re.I)
            if mm:
                stats[key] = int(mm.group(1))
                break

    # Alle Widerstaende
    m = re.search(r"(\d+)\s+to all resistances|all resistances by\s+(\d+)|"
                  r"resistance to all schools of magic by\s+(\d+)", t, re.I)
    if m:
        v = _num(m)
        for k in ("RES_FIRE", "RES_FROST", "RES_NATURE", "RES_SHADOW", "RES_ARCANE"):
            stats[k] = v

    # Einzelne Widerstaende. "resistance to fire by 5" ist die Form,
    # die am haeufigsten vorkommt - und die zuerst gefehlt hat.
    for school, key in (("fire","RES_FIRE"), ("frost","RES_FROST"),
                        ("nature","RES_NATURE"), ("shadow","RES_SHADOW"),
                        ("arcane","RES_ARCANE")):
        if key in stats:
            continue
        mm = re.search(r"resistance to " + school + r" by\s+(\d+)|"
                       + school + r" resistance by\s+(\d+)|"
                       r"\+?(\d+)\s+" + school + r" resistance", t, re.I)
        if mm:
            stats[key] = _num(mm)

    # Schulgebundener Zauberschaden: zaehlt nur fuer eine Schule und
    # wird im Addon entsprechend halb gewichtet.
    for school in ("fire", "frost", "shadow", "arcane", "nature", "holy"):
        key = "SPELLPOWER_" + school.upper()
        if key in stats:
            continue
        mm = re.search(r"increase[sd]?\s+" + school
                       + r" damage by(?: up to)?\s+(\d+)", t, re.I)
        if mm:
            stats[key] = int(mm.group(1))

    # Prozentuale Blockchance
    if "BLOCK" not in stats:
        mm = re.search(r"\+?(\d+)%\s+chance to block", t, re.I)
        if mm:
            stats["BLOCK"] = int(mm.group(1))

    # Flacher Waffenschaden
    for p in (r"(\d+)\s+additional points? of damage",
              r"increase[sd]?\s+(?:\w+\s+){0,2}damage\s+by\s+(\d+)",
              r"do\s+\+?(\d+)\s+damage",
              r"adds?\s+(\d+)\s+damage"):
        mm = re.search(p, t, re.I)
        if mm:
            dmg = int(mm.group(1))
            break

    return stats, dmg


# Berufsverzauberungen: nuetzlich, aber nicht kampfrelevant. Sie wuerden
# in der Empfehlungsliste nur Platz wegnehmen.
PROFESSION_RE = re.compile(
    r"(mining|herbalism|skinning|fishing|riding|engineering) skill", re.I)

# Procs: ohne bekannte Ausloesewahrscheinlichkeit nicht seriös zu
# beziffern. Sie werden bewusst weggelassen, statt geraten zu werden.
PROC_RE = re.compile(
    r"chance (?:per hit|on hit|of)|often (?:strike|chill|heal)|sometimes", re.I)

# Slots in der Reihenfolge, in der sie im Addon erscheinen
SLOT_ORDER = [
    "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot",
    "WristSlot", "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot",
    "Finger0Slot", "Trinket0Slot", "MainHandSlot", "SecondaryHandSlot",
    "RangedSlot",
]

# Beruf aus der Filternummer
GROUP_NAME = {
    "11.333": "Verzauberkunst",
    "11.202": "Ingenieurskunst",
    "11.165": "Lederverarbeitung",
    "11.164": "Schmiedekunst",
    "11.197": "Schneiderei",
}


def lua_str(v):
    return '"%s"' % str(v).replace("\\", "\\\\").replace('"', '\\"')


# Zielfernrohre sind herstellbare Gegenstaende. Ihre Zauberseite ist ein
# Baurezept und nennt den Effekt nicht - der steht am Gegenstand. Weil
# sie fuer Jaeger und Schuetzen wichtig sind, werden sie hier ergaenzt.
# Werte aus dem Spiel, nicht aus dem Export.
SCOPE_FALLBACK = [
    {"n": "Sniper Scope",   "dmg": 7, "req": 40, "src": "Ingenieurskunst"},
    {"n": "Accurate Scope", "dmg": 5, "req": 30, "src": "Ingenieurskunst"},
    {"n": "Standard Scope", "dmg": 3, "req": 20, "src": "Ingenieurskunst"},
    {"n": "Crude Scope",    "dmg": 2, "req": 10, "src": "Ingenieurskunst"},
]


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("source", help="Ordner mit den JSON-Exporten oder eine Datei")
    ap.add_argument("-o", "--out", default="../Data/EnchantData.lua")
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

    by_id = {}
    for f in files:
        with open(f, encoding="utf-8") as fh:
            payload = json.load(fh)
        rows = payload.get("enchants") if isinstance(payload, dict) else payload
        if not isinstance(rows, list):
            print("  ! %s enthaelt keine Verzauberungen" % os.path.basename(f))
            continue
        for r in rows:
            if isinstance(r, dict) and r.get("id") is not None:
                by_id[int(r["id"])] = r
        print("  %-40s %5d Eintraege" % (os.path.basename(f), len(rows)))

    slots = {}
    unresolved = []
    duplicates = 0

    skipped_prof = 0
    skipped_recipe = 0
    skipped_proc = 0
    for e in by_id.values():
        # Der Name traegt ein Qualitaetszeichen vorweg ("@")
        name = re.sub(r"^[^A-Za-z0-9]+", "", (e.get("name") or "").strip())
        slot = e.get("slot")
        stats = e.get("stats") or {}
        dmg = e.get("dmg")

        # Kein Slot heisst: keine Verzauberung, sondern eine
        # Berufsfertigkeit, ein Zauberstab oder Entzaubern. Still
        # ueberspringen, das ist kein Fehler.
        if not slot:
            continue

        # Baurezepte aussortieren. "Goblin Rocket Boots" ist ein
        # herstellbarer Gegenstand, keine Verzauberung - der Name allein
        # reicht zur Unterscheidung nicht. Nur pruefen, wenn das Feld
        # vorhanden ist, damit aeltere Exporte weiter funktionieren.
        if "isEnchant" in e and not e.get("isEnchant"):
            skipped_recipe += 1
            continue

        if PROFESSION_RE.search(e.get("desc") or "") or PROFESSION_RE.search(name):
            skipped_prof += 1
            continue

        if PROC_RE.search(e.get("desc") or ""):
            skipped_proc += 1
            continue

        # Nachauswertung aus der Beschreibung, wo das Browserskript
        # nichts erkannt hat
        if not stats and dmg is None:
            stats, dmg = parse_desc(e.get("desc"))
        # Der breitere Rohausschnitt als zweiter Versuch - genau dafuer
        # speichert das Browserskript ihn mit.
        if not stats and dmg is None and e.get("raw"):
            stats, dmg = parse_desc(e.get("raw"))

        if not stats and dmg is None:
            unresolved.append(name or ("Zauber %s" % e.get("id")))
            continue

        entry = {
            "id": int(e["id"]) if e.get("id") is not None else None,
            "n": name,
            "st": {k: v for k, v in stats.items() if v},
            "dmg": dmg,
            "req": e.get("req"),
            "src": GROUP_NAME.get(e.get("group"), e.get("group")),
        }

        bucket = slots.setdefault(slot, [])
        # Gleichnamige Eintraege kommen vor, wenn ein Rezept mehrfach
        # gelistet ist. Der mit mehr Angaben gewinnt.
        existing = None
        for i, b in enumerate(bucket):
            if b["n"] == entry["n"]:
                existing = i
                break
        if existing is not None:
            duplicates += 1
            old = bucket[existing]
            if len(entry["st"]) > len(old["st"]):
                bucket[existing] = entry
        else:
            bucket.append(entry)

    # Zielfernrohre ergaenzen, sofern der Export sie nicht selbst liefert
    ranged = slots.setdefault("RangedSlot", [])
    vorhanden = set(x["n"] for x in ranged)
    nachgetragen = 0
    for sc in SCOPE_FALLBACK:
        if sc["n"] not in vorhanden:
            ranged.append({"n": sc["n"], "st": {}, "dmg": sc["dmg"],
                           "req": sc["req"], "src": sc["src"]})
            nachgetragen += 1

    if not slots:
        sys.exit("Nichts zugeordnet - bitte den Export pruefen.")

    # Innerhalb eines Slots die staerksten zuerst, damit die Datei
    # auch von Hand lesbar bleibt
    def strength(e):
        return sum(e["st"].values()) + (e.get("dmg") or 0) * 3
    for bucket in slots.values():
        bucket.sort(key=strength, reverse=True)

    lines = [
        "--[[----------------------------------------------------------------------",
        "  BananaLootline - Data/EnchantData.lua",
        "",
        "  ERZEUGT von tools/octodb_enchants_build.py aus der",
        "  OctoWoW-Datenbank. Nicht von Hand bearbeiten - der naechste",
        "  Lauf ueberschreibt die Datei.",
        "",
        "  Felder:",
        "    n    Name",
        "    st   Werte, gleiche Schluessel wie bei Items",
        "    dmg  flacher Waffenschaden. Wird beim Bewerten mit dem Tempo",
        "         der angelegten Waffe in DPS umgerechnet.",
        "    req  benoetigte Itemstufe",
        "    src  Beruf",
        "",
        "  Erzeugt: " + time.strftime("%Y-%m-%d %H:%M"),
        "------------------------------------------------------------------------]]",
        "",
        "BananaLootlineEnchantData = {",
    ]

    total = 0
    for slot in SLOT_ORDER:
        bucket = slots.get(slot)
        if not bucket:
            continue
        lines.append("")
        lines.append("  %s = {" % slot)
        for e in bucket:
            parts = ["n = " + lua_str(e["n"])]
            if e.get("id"):
                parts.append("id = %d" % e["id"])
            if e["st"]:
                inner = ", ".join("%s = %s" % (k, v) for k, v in sorted(e["st"].items()))
                parts.append("st = { %s }" % inner)
            if e.get("dmg"):
                parts.append("dmg = %s" % e["dmg"])
            if e.get("req"):
                parts.append("req = %s" % e["req"])
            if e.get("src"):
                parts.append("src = " + lua_str(e["src"]))
            lines.append("    { %s }," % ", ".join(parts))
            total += 1
        lines.append("  },")

    lines.append("}")
    lines.append("")

    out = os.path.abspath(args.out)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))

    print()
    print("Geschrieben: %s" % out)
    print("%d Verzauberungen in %d Slots" % (total, len([s for s in slots if slots[s]])))
    for slot in SLOT_ORDER:
        if slots.get(slot):
            print("   %-20s %d" % (slot, len(slots[slot])))
    if duplicates:
        print("\n%d gleichnamige Eintraege zusammengefasst." % duplicates)
    if skipped_prof:
        print("%d Berufsverzauberungen uebersprungen (Bergbau, Kraeuterkunde, ...)."
              % skipped_prof)
    if skipped_proc:
        print("%d Procs uebersprungen (ohne Ausloesewahrscheinlichkeit nicht "
              "bewertbar)." % skipped_proc)
    if skipped_recipe:
        print("%d Baurezepte uebersprungen (herstellbare Gegenstaende, "
              "keine Verzauberungen)." % skipped_recipe)
    if nachgetragen:
        print("%d Zielfernrohre ergaenzt (ihre Wirkung steht am Gegenstand, "
              "nicht am Zauber)." % nachgetragen)
    if unresolved:
        print("\n%d nicht zugeordnet - dem Browserskript fehlen die Muster:" % len(unresolved))
        for u in unresolved[:25]:
            print("   " + u)
        if len(unresolved) > 25:
            print("   ... und %d weitere" % (len(unresolved) - 25))
        print("\nDiese Liste bitte melden, dann ergaenze ich die Muster.")

    print("\nDanach im Spiel: /reload")


if __name__ == "__main__":
    main()
