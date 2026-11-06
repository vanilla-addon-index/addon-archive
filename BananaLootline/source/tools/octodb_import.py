#!/usr/bin/env python3
"""
octodb_import.py - Itemdaten aus der OctoWoW-Datenbank nach Data/ItemDB.lua

Warum es diesen Import ueberhaupt braucht
-----------------------------------------
pfQuest liefert QUELLEN (wer droppt was), aber keine Itemwerte. Der
1.12-Client liefert ueber GetItemInfo() kein Itemlevel. Beides zusammen
fehlt also - und genau das holt dieses Skript aus octowow.st/db.

Die Seite laeuft auf AoWoW. AoWoW-Listenseiten betten ihre Ergebnisse als
JavaScript-Array ein:

    new Listview({template: 'item', id: 'items', data: [{"id":1234,...}]});

Das ist deutlich robuster zu parsen als HTML - wir schneiden das Array
heraus und lesen es als JSON.

WICHTIG: DIREKTER ABRUF FUNKTIONIERT NICHT
-----------------------------------------
octowow.st/db liegt hinter einer Blazingfast-Browserpruefung. Ein Skript
mit requests bekommt dort nur die Challenge-Seite, niemals die Daten.
--probe und --all sind deshalb nur noch fuer Tests drin und werden
scheitern, solange der Schutz aktiv ist.

DER WEG, DER FUNKTIONIERT
-------------------------
Dein Browser hat die Pruefung bestanden - also extrahieren wir dort.

  1. tools/octodb_extract.js in die Browserkonsole auf der Item-Liste
     einfuegen. Es laedt eine JSON-Datei herunter.
  2. Pro Slot wiederholen, alle Dateien in einen Ordner legen.
  3. Hier einlesen:

       python3 octodb_import.py --from-json ./exports -o ../Data/ItemData.lua

Der Importer meldet dabei, welche Felder er nicht kennt - die gehoeren
dann in KEYMAP weiter unten.
"""

import argparse
import json
import os
import re
import sys
import time

try:
    import requests
except ImportError:
    sys.exit("Bitte zuerst: pip install requests")

BASE = "https://octowow.st/db"

# ---------------------------------------------------------------------------
# KONFIGURATION - hier anpassen, falls --probe etwas anderes zeigt
# ---------------------------------------------------------------------------

# {slot} = InventoryType, {minq} = Mindestqualitaet
# AoWoW-Filtersyntax: filter=sl=<slot>;qu=<quality>;
FILTER_URL = BASE + "/?items&filter=sl={slot};qu={minq}"

# Slots, die uns interessieren (InventoryType laut Server)
SLOTS = {
    1:  "Head",        2:  "Neck",       3:  "Shoulder",  16: "Back",
    5:  "Chest",       20: "Robe",       9:  "Wrist",     10: "Hands",
    6:  "Waist",       7:  "Legs",       8:  "Feet",      11: "Finger",
    12: "Trinket",     13: "OneHand",    17: "TwoHand",   21: "MainHand",
    22: "OffHand",     14: "Shield",     15: "Ranged",    23: "Held",
    25: "Thrown",      26: "RangedRight", 4: "Shirt",
}

# Qualitaetsschwelle: 2 = gruen aufwaerts. Auf 0 setzen fuer wirklich alles
# (macht die Datei deutlich groesser, ohne viel Nutzen fuer einen BiS-Planer).
MIN_QUALITY = 2

# JSON-Key der Seite -> unser interner Statname.
# Alles, was hier nicht steht, wird verworfen.
KEYMAP = {
    "str":        "STR",
    "agi":        "AGI",
    "sta":        "STA",
    "int":        "INT",
    "spi":        "SPI",
    "armor":      "ARMOR",
    "dps":        "WEAPON_DPS",
    "speed":      "WEAPON_SPEED",
    "mledps":     "WEAPON_DPS",
    "atkpwr":     "AP",
    "mleatkpwr":  "AP",
    "rgdatkpwr":  "RAP",
    "spldmg":     "SPELLPOWER",
    "splheal":    "HEALPOWER",
    "splcritstrkrtng": "SPELLCRIT",
    "critstrkrtng":    "CRIT",
    "hitrtng":    "HIT",
    "defrtng":    "DEFENSE",
    "dodgertng":  "DODGE",
    "parryrtng":  "PARRY",
    "blockrtng":  "BLOCK",
    "manargn":    "MP5",
    "healthrgn":  "HP5",
    "fireres":    "RES_FIRE",
    "frostres":   "RES_FROST",
    "natres":     "RES_NATURE",
    "shadowres":  "RES_SHADOW",
    "arcres":     "RES_ARCANE",
}

# Metafelder (nicht Stats)
META_KEYS = {
    "name":      "name",
    "level":     "ilvl",
    "quality":   "quality",
    "slot":      "slot",
    "reqlevel":  "reqlevel",
    "classs":    "itemclass",
    "subclass":  "subclass",
}

HEADERS = {
    "User-Agent": "BananaLootline-Import/0.1 (Addon-Datenimport; bitte bei Problemen melden)"
}

RAW_DIR = "raw"


# ---------------------------------------------------------------------------
# Parsing
# ---------------------------------------------------------------------------

def extract_listview_data(html):
    """Schneidet das data:[...]-Array aus einem AoWoW-Listview heraus.

    Klammerzaehlung statt Regex, weil verschachtelte Arrays sonst zu frueh
    abschneiden.
    """
    results = []
    for m in re.finditer(r"data\s*:\s*\[", html):
        start = m.end() - 1
        depth, i, in_str, esc = 0, start, False, False
        while i < len(html):
            c = html[i]
            if in_str:
                if esc:
                    esc = False
                elif c == "\\":
                    esc = True
                elif c == '"':
                    in_str = False
            else:
                if c == '"':
                    in_str = True
                elif c == "[":
                    depth += 1
                elif c == "]":
                    depth -= 1
                    if depth == 0:
                        results.append(html[start:i + 1])
                        break
            i += 1
    return results


def repair_json(blob):
    """AoWoW schreibt teilweise unquotierte Keys und einfache Quotes."""
    # unquotierte Keys quoten:  {id:123,  ->  {"id":123,
    blob = re.sub(r"([{,]\s*)([A-Za-z_][A-Za-z0-9_]*)\s*:", r'\1"\2":', blob)

    # einfach gequotete Werte auf doppelte umstellen:  :'X'  ->  :"X"
    def single_to_double(m):
        inner = m.group(1).replace('\\"', '"').replace('"', '\\"')
        return ':"%s"' % inner
    blob = re.sub(r":\s*'((?:[^'\\]|\\.)*)'", single_to_double, blob)

    # trailing commas entfernen
    blob = re.sub(r",\s*([\]}])", r"\1", blob)
    return blob


def parse_items(html):
    out = []
    for blob in extract_listview_data(html):
        try:
            rows = json.loads(blob)
        except json.JSONDecodeError:
            try:
                rows = json.loads(repair_json(blob))
            except json.JSONDecodeError as e:
                print("  ! Konnte ein data-Array nicht lesen: %s" % e)
                continue
        if isinstance(rows, list):
            out.extend(r for r in rows if isinstance(r, dict) and "id" in r)
    return out


# AoWoW klebt die Qualitaet als Ziffer vor den Itemnamen: "2Bloody Gladiator's
# Headband". Die Skala ist invertiert - 1 ist legendaer, 6 ist Schrott.
PREFIX_QUALITY = { "1": 5, "2": 4, "3": 3, "4": 2, "5": 1, "6": 0 }


def split_name(raw):
    """Gibt (Name ohne Praefix, abgeleitete Qualitaet oder None) zurueck."""
    if not isinstance(raw, str) or not raw:
        return raw, None
    first = raw[0]
    if first in PREFIX_QUALITY:
        return raw[1:], PREFIX_QUALITY[first]
    return raw, None


def normalise(row):
    """Rohe Zeile -> unser kompaktes Format.

    Zwei Eingangsformate:
      - Listenexport (octodb_extract.js): Statfelder heissen wie bei AoWoW
        ("sta", "int"), muessen also ueber KEYMAP uebersetzt werden.
      - Detailexport (octodb_details.js): bringt bereits ein fertiges
        "stats"-Objekt mit unseren eigenen Schluesseln mit. Das wird
        unveraendert uebernommen.
    """
    entry = {}

    prebuilt = row.get("stats")
    if isinstance(prebuilt, dict) and prebuilt:
        entry["stats"] = dict(prebuilt)
    for src, dst in META_KEYS.items():
        if src in row and row[src] not in (None, ""):
            entry[dst] = row[src]

    if "stats" not in entry:
        stats = {}
        for src, dst in KEYMAP.items():
            val = row.get(src)
            if isinstance(val, (int, float)) and val != 0:
                stats[dst] = val
        if stats:
            entry["stats"] = stats
    else:
        # Ruestung steht beim Detailexport in der Liste, nicht auf der
        # Itemseite - falls sie dort fehlt, hier nachtragen.
        armor = row.get("armor")
        if isinstance(armor, (int, float)) and armor and "ARMOR" not in entry["stats"]:
            entry["stats"]["ARMOR"] = armor

    # Namenspraefix abtrennen. Eine explizite quality-Spalte der Seite
    # hat Vorrang, das Praefix ist nur der Rueckfall.
    clean, derived = split_name(entry.get("name"))
    if clean is not None:
        entry["name"] = clean
    if "quality" not in entry and derived is not None:
        entry["quality"] = derived

    for maskkey in ("classmask", "reqclass", "classs_mask"):
        if maskkey in row:
            entry["classmask"] = row[maskkey]
            break
    for maskkey in ("racemask", "reqrace"):
        if maskkey in row:
            entry["racemask"] = row[maskkey]
            break

    return entry


# ---------------------------------------------------------------------------
# Abruf
# ---------------------------------------------------------------------------

def fetch(url, cache_name=None, delay=1.5):
    os.makedirs(RAW_DIR, exist_ok=True)
    path = os.path.join(RAW_DIR, cache_name) if cache_name else None

    if path and os.path.exists(path):
        print("  (aus Cache: %s)" % path)
        with open(path, encoding="utf-8", errors="replace") as fh:
            return fh.read()

    print("  GET %s" % url)
    resp = requests.get(url, headers=HEADERS, timeout=30)
    resp.raise_for_status()
    html = resp.text

    if path:
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(html)

    time.sleep(delay)   # freundlich bleiben, das ist ein Hobbyserver
    return html


# ---------------------------------------------------------------------------
# Lua-Ausgabe
# ---------------------------------------------------------------------------

def lua_value(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        if isinstance(v, float) and v == int(v):
            return str(int(v))
        return str(v)
    return '"%s"' % str(v).replace("\\", "\\\\").replace('"', '\\"')


def write_lua(items, path):
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("-- Automatisch erzeugt von tools/octodb_import.py\n")
        fh.write("-- Quelle: OctoWoW-Datenbank (octowow.st/db)\n")
        fh.write("-- Erzeugt: %s\n" % time.strftime("%Y-%m-%d %H:%M:%S"))
        fh.write("-- Eintraege: %d\n" % len(items))
        fh.write("-- NICHT von Hand bearbeiten.\n")
        fh.write("-- Gehoert nach Data/ItemData.lua - NICHT nach ItemDB.lua,\n")
        fh.write("-- das ist die Lesefunktion und wuerde dabei geloescht.\n\n")
        fh.write("BananaLootlineItemData = {\n")

        for item_id in sorted(items):
            e = items[item_id]
            parts = []
            for key in ("name", "ilvl", "quality", "slot", "reqlevel",
                        "itemclass", "subclass", "classmask", "racemask"):
                if key in e:
                    parts.append("%s=%s" % (key, lua_value(e[key])))
            if e.get("stats"):
                inner = ",".join("%s=%s" % (k, lua_value(v))
                                 for k, v in sorted(e["stats"].items()))
                parts.append("stats={%s}" % inner)
            fh.write("[%d]={%s},\n" % (item_id, ",".join(parts)))

        fh.write("}\n")

    size = os.path.getsize(path) / 1024.0
    print("\nGeschrieben: %s  (%d Items, %.0f KB)" % (path, len(items), size))
    if size > 3000:
        print("Hinweis: ueber 3 MB. Fuer den Client besser nach Slot aufteilen")
        print("und als LoadOnDemand-Module nachladen.")


# ---------------------------------------------------------------------------
# Modi
# ---------------------------------------------------------------------------

def probe():
    print("Probelauf: eine Seite laden und Struktur zeigen.\n")
    url = FILTER_URL.format(slot=1, minq=MIN_QUALITY)
    html = fetch(url, "probe.html")

    blobs = extract_listview_data(html)
    print("\n  data-Arrays gefunden: %d" % len(blobs))
    if not blobs:
        print("  Keine gefunden. Moegliche Ursachen:")
        print("   - Die Seite baut die Liste per XHR nach (dann im Browser")
        print("     das Netzwerk-Tab oeffnen und die echte Datenroute suchen)")
        print("   - Die Filtersyntax stimmt nicht -> FILTER_URL anpassen")
        print("  Roh-HTML liegt unter raw/probe.html.")
        return

    rows = parse_items(html)
    print("  Zeilen geparst: %d" % len(rows))
    if not rows:
        return

    keys = set()
    for r in rows:
        keys.update(r.keys())

    known = sorted(k for k in keys if k in KEYMAP or k in META_KEYS)
    unknown = sorted(k for k in keys if k not in KEYMAP and k not in META_KEYS)

    print("\n  Bekannte Keys (%d): %s" % (len(known), ", ".join(known)))
    print("\n  UNBEKANNTE Keys (%d):" % len(unknown))
    print("  %s" % ", ".join(unknown))
    print("\n  Beispielzeile:")
    print("  " + json.dumps(rows[0], indent=2, ensure_ascii=False)[:1200])
    print("\n  -> Was davon ein Stat ist, in KEYMAP eintragen. Dann --all.")


def run_all(outpath):
    items = {}
    for slot, name in sorted(SLOTS.items()):
        print("\nSlot %d (%s):" % (slot, name))
        url = FILTER_URL.format(slot=slot, minq=MIN_QUALITY)
        try:
            html = fetch(url, "items_sl%d.html" % slot)
        except Exception as e:
            print("  ! Fehlgeschlagen: %s" % e)
            continue

        rows = parse_items(html)
        print("  %d Zeilen" % len(rows))

        if len(rows) >= 500:
            print("  ! Vermutlich am Seitenlimit abgeschnitten.")
            print("    Diesen Slot zusaetzlich nach Qualitaet oder Stufe splitten.")

        for r in rows:
            try:
                item_id = int(r["id"])
            except (KeyError, ValueError, TypeError):
                continue
            entry = normalise(r)
            if "slot" not in entry:
                entry["slot"] = slot
            items[item_id] = entry

    if not items:
        sys.exit("\nNichts importiert. Erst --probe laufen lassen.")

    write_lua(items, outpath)


def from_file(path, outpath):
    with open(path, encoding="utf-8", errors="replace") as fh:
        html = fh.read()
    rows = parse_items(html)
    print("%d Zeilen aus %s" % (len(rows), path))
    items = {}
    for r in rows:
        try:
            items[int(r["id"])] = normalise(r)
        except (KeyError, ValueError, TypeError):
            continue
    write_lua(items, outpath)


def from_json(path, outpath):
    """Verarbeitet die JSON-Dateien aus octodb_extract.js.

    Akzeptiert eine einzelne Datei oder einen Ordner voller Exporte.
    """
    files = []
    if os.path.isdir(path):
        for name in sorted(os.listdir(path)):
            if name.lower().endswith(".json"):
                files.append(os.path.join(path, name))
    else:
        files.append(path)

    if not files:
        sys.exit("Keine .json-Dateien unter %s gefunden." % path)

    items = {}
    all_keys = {}

    for f in files:
        with open(f, encoding="utf-8") as fh:
            payload = json.load(fh)

        # Sowohl das Format aus octodb_extract.js als auch ein blankes
        # Array akzeptieren, falls jemand von Hand kopiert hat.
        rows = payload.get("items") if isinstance(payload, dict) else payload
        if not isinstance(rows, list):
            print("  ! %s enthaelt keine Itemliste, uebersprungen" % f)
            continue

        is_detail = isinstance(payload, dict) and payload.get("source") == "item-detail-pages"
        if not is_detail and not any(isinstance(r, dict) and "slot" in r for r in rows[:50]):
            print("  ! %s enthaelt KEINE Slotangaben - vermutlich ein Export"
                  % os.path.basename(f))
            print("    von einer Suchergebnisseite. Uebersprungen.")
            continue

        added = 0
        for r in rows:
            if not isinstance(r, dict) or "id" not in r:
                continue
            try:
                item_id = int(r["id"])
            except (ValueError, TypeError):
                continue
            for k in r:
                all_keys[k] = all_keys.get(k, 0) + 1
            items[item_id] = normalise(r)
            added += 1

        print("  %-40s %5d Items" % (os.path.basename(f), added))

    if not items:
        sys.exit("Nichts brauchbares gefunden.")

    unknown = sorted(k for k in all_keys
                     if k not in KEYMAP and k not in META_KEYS
                     and k not in ("id", "name"))
    if unknown:
        print("\nUnbekannte Felder (evtl. Stats, die in KEYMAP fehlen):")
        print("  " + ", ".join(unknown))

    with_stats = sum(1 for e in items.values() if e.get("stats"))
    print("\n%d Items gesamt, davon %d mit erkannten Werten." % (len(items), with_stats))
    if with_stats < len(items) * 0.3:
        print("Auffaellig wenige mit Werten - vermutlich fehlen Eintraege in KEYMAP.")

    write_lua(items, outpath)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--from-json", metavar="PFAD",
                    help="JSON-Export(e) aus octodb_extract.js verarbeiten - "
                         "einzelne Datei oder Ordner. DER EMPFOHLENE WEG.")
    ap.add_argument("--probe", action="store_true",
                    help="eine Seite direkt laden und analysieren "
                         "(scheitert am DDoS-Schutz, nur fuer Tests)")
    ap.add_argument("--all", action="store_true",
                    help="alle Slots direkt abrufen "
                         "(scheitert am DDoS-Schutz, nur fuer Tests)")
    ap.add_argument("--from-file", metavar="HTML",
                    help="lokal gespeichertes HTML parsen")
    ap.add_argument("-o", "--out", default="../Data/ItemData.lua",
                    help="Zieldatei (Standard: ../Data/ItemData.lua)")
    args = ap.parse_args()

    if args.from_json:
        from_json(args.from_json, args.out)
    elif args.probe:
        probe()
    elif args.from_file:
        from_file(args.from_file, args.out)
    elif args.all:
        run_all(args.out)
    else:
        ap.print_help()


if __name__ == "__main__":
    main()
