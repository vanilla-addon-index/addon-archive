#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
octo_import.py - baut Data/ItemData.lua, Data/SourceData.lua und
Data/ZoneNames.lua aus dem OctoWoW-Export.

Aufruf:
    python3 tools/octo_import.py <exportverzeichnis> \\
        --out BananaLootline \\
        --zones <zones.lua> --units <units.lua> \\
        --coords <units.lua> --quests <quests.lua>

    --zones   pfQuests enUS-Zonennamen
    --units   pfQuests enUS-NPC-Namen
    --coords  pfQuests Koordinatendateien (Ort je NPC)
    --quests  pfQuests Questdateien (Geber je Quest)
    --objects pfQuests Objektdateien (Ort je Truhe)
    Jede Option mehrfach angeben; spaetere Dateien ueberschreiben, also
    die serverspezifische zuletzt nennen.

Erwartet im Exportverzeichnis:
    octowow_items_teil*.jsonl   je eine Zeile pro Item
    octowow_meta.json           Kopfdaten des Scrapes (nur informativ)

Der Export liefert Werte strukturiert. Primaerattribute, Widerstaende,
Ruestung, Waffenschaden und Sockelplatz stehen als Zahlen da, nicht mehr
als Tooltipzeile. Nur die Zweitwerte - Angriffskraft, Trefferwertung,
Zaubermacht - stehen weiter als Satz in "equip". Fuer die gibt es unten
PATTERNS. Vorlage ist der Wortlaut des englischen Clients; der Scrape ist
immer englisch, deshalb genuegt ein Satz Muster.

Was der Vorgaenger nicht konnte:
  - Procs erkennen. "chanceOnHit" ist ein eigenes Feld, die Schaetzwerte
    UNSCORED_FLAT und UNSCORED_SHARE in Candidates.lua werden damit
    ueberfluessig.
  - Questbelohnungen. pfQuest hat unter ["Q"] keinen einzigen Eintrag,
    der Zweig im Addon war toter Code.
  - Rufanforderungen vom Server statt aus AtlasLoot, dessen Tabelle fuer
    diesen Server falsche Angaben enthaelt.
  - Mobstufen, Elitekennung und Fraktion pro Quelle.
"""

import os
import re
import sys
import json
import glob
import time
import collections

# ---------------------------------------------------------------------
# Sockelplaetze
#
# Der Export liefert die Zahl nur fuer Ruestung. Waffen tragen dort None
# und nennen den Platz im Text. Die Zahlen sind der InventoryType des
# 1.12-Servers, dieselben Werte, die SLOTNUM_INVTYPE in Candidates.lua
# erwartet.
# ---------------------------------------------------------------------

SLOT_BY_NAME = {
    "Head": 1, "Neck": 2, "Shoulder": 3, "Shirt": 4, "Chest": 5,
    "Waist": 6, "Legs": 7, "Feet": 8, "Wrist": 9, "Hands": 10,
    "Finger": 11, "Trinket": 12, "Back": 16, "Tabard": 19,
    "Relic": 28, "Held In Off-Hand": 23, "Thrown": 25,
    "One-hand": 13, "Two-hand": 17, "Main Hand": 21,
}

# Projectile ist Munition. Traegt keine Werte und belegt keinen Platz,
# den das Addon plant.
SLOT_SKIP = set(["Projectile"])

RANGED_RIGHT = set(["Wand"])      # Zauberstaebe -> 26
SHIELD_TYPES = set(["Shield"])    # Schilde -> 14, andere Offhand -> 22


def slot_number(item):
    """Sockelplatz als Zahl. None heisst: nicht anlegbar."""
    st = item.get("stats") or {}
    name = st.get("slot")
    if not name or name in SLOT_SKIP:
        return None

    # Die Zahl aus dem Export gewinnt, wo es eine gibt. Sie
    # unterscheidet Robe (20) von Brust (5), was der Text nicht kann,
    # und Schild (14) von Offhandwaffe (22).
    num = item.get("slot")
    if isinstance(num, int) and num > 0:
        return num

    if name == "Ranged":
        return 26 if (st.get("type") in RANGED_RIGHT) else 15
    if name == "Off Hand":
        return 14 if (st.get("type") in SHIELD_TYPES) else 22
    return SLOT_BY_NAME.get(name)


# ---------------------------------------------------------------------
# Itemklassen
# ---------------------------------------------------------------------

ITEMCLASS = {
    "Consumable": 0, "Container": 1, "Weapon": 2, "Gem": 3, "Armor": 4,
    "Reagent": 5, "Projectile": 6, "Trade Goods": 7, "Recipe": 9,
    "Quiver": 11, "Quest": 12, "Key": 13, "Miscellaneous": 15,
}

ARMOR_SUBCLASS = {
    "Miscellaneous": 0, "Cloth": 1, "Leather": 2, "Mail": 3,
    "Plate": 4, "Shield": 6, "Libram": 7, "Idol": 8, "Totem": 9,
}

WEAPON_SUBCLASS = {
    "Axe": 0, "Two-Handed Axe": 1, "Bow": 2, "Gun": 3, "Mace": 4,
    "Two-Handed Mace": 5, "Polearm": 6, "Sword": 7,
    "Two-Handed Sword": 8, "Staff": 10, "Fist Weapon": 13,
    "Miscellaneous": 14, "Dagger": 15, "Thrown": 16, "Spear": 17,
    "Crossbow": 18, "Wand": 19, "Fishing Pole": 20,
}

CLASS_BITS = {
    "Warrior": 1, "Paladin": 2, "Hunter": 4, "Rogue": 8,
    "Priest": 16, "Shaman": 64, "Mage": 128, "Warlock": 256,
    "Druid": 1024,
}


# ---------------------------------------------------------------------
# Zweitwerte aus den Textzeilen
#
# Reihenfolge zaehlt: die spezifischen Muster stehen vor den
# allgemeinen, sonst schluckt "Increases damage ... by up to N" auch die
# Schulenvarianten, und "to hit by" auch "to hit with spells by".
# ---------------------------------------------------------------------

RAW_PATTERNS = [
    ("SPELLPOWER_ARCANE",
     r"^Increases damage done by Arcane spells and effects by up to (\d+)"),
    ("SPELLPOWER_FIRE",
     r"^Increases damage done by Fire spells and effects by up to (\d+)"),
    ("SPELLPOWER_FROST",
     r"^Increases damage done by Frost spells and effects by up to (\d+)"),
    ("SPELLPOWER_HOLY",
     r"^Increases damage done by Holy spells and effects by up to (\d+)"),
    ("SPELLPOWER_NATURE",
     r"^Increases damage done by Nature spells and effects by up to (\d+)"),
    ("SPELLPOWER_SHADOW",
     r"^Increases damage done by Shadow spells and effects by up to (\d+)"),

    # "Increases damage AND HEALING done by ..." gibt beides. Bis 0.22.6
    # trug der Importer nur SPELLPOWER ein, und damit fehlte 1443 Teilen
    # ihr Heilwert komplett - darunter jedem Teil mit dieser Zeile, das
    # ein Heiler anlegt. Bei 49 Teilen kommt eine zweite Zeile mit
    # zusaetzlicher Heilung dazu; die addieren sich, weil stats[key]
    # aufaddiert. Circlet of Prophecy heisst also 12 Zauberschaden und
    # 12 + 11 = 23 Heilung, nicht 11.
    (("SPELLPOWER", "HEALPOWER"),
     r"^Increases damage and healing done by magical spells and effects"
     r" by up to (\d+)"),
    ("HEALPOWER",
     r"^Increases healing done by spells and effects by up to (\d+)"),
    # Reiner Zauberschaden ohne Heilung. Nur ein Teil im Bestand fuehrt
    # das - The Scythe of Elune mit 40 -, und ohne dieses Muster fiel der
    # Wert ganz weg. Muss nach den Schulenvarianten stehen.
    ("SPELLPOWER",
     r"^Increases damage done by magical spells and effects by up to (\d+)"),

    ("SPELLCRIT",
     r"^Improves your chance to get a critical strike with spells by"
     r" ([\d.]+)%"),
    ("SPELLHIT",
     r"^Improves your chance to hit with spells by ([\d.]+)%"),
    ("CRIT",
     r"^Improves your chance to get a critical strike by ([\d.]+)%"),
    ("HIT",
     r"^Improves your chance to hit by ([\d.]+)%"),

    ("RAP", r"^\+(\d+) ranged Attack Power\b"),
    ("AP",  r"^\+(\d+) Attack Power\."),
    ("MP5", r"^Restores (\d+) mana per 5 sec"),
    ("HP5", r"^Restores (\d+) health per 5 sec"),

    ("DEFENSE",    r"^Increased Defense \+(\d+)"),
    ("DODGE",      r"^Increases your chance to dodge an attack by ([\d.]+)%"),
    ("PARRY",      r"^Increases your chance to parry an attack by ([\d.]+)%"),
    ("BLOCK",
     r"^Increases your chance to block attacks with a shield by ([\d.]+)%"),
    ("BLOCKVALUE", r"^Increases the block value of your shield by (\d+)"),
]

PATTERNS = [(k, re.compile(p)) for k, p in RAW_PATTERNS]

# "+N All Resistances" schlaegt auf alle fuenf Schulen durch.
ALL_RES = re.compile(r"^\+(\d+) All Resistances")

# ---------------------------------------------------------------------
# Werte, die der Export nicht fuehrt
#
# Zwei Teile tragen im Spiel einen Nachteil, der im Export fehlt - weder
# in attributes noch in den equip-Zeilen steht er. Ohne ihn sieht ein
# verfluchtes Teil besser aus, als es ist.
#
# HERKUNFT: aus einem Abgleich mit turtlelootline.com, nicht aus dem
# Export und nicht von der OctoWoW-Datenbank nachgeprueft. Die Seite
# rendert ihre Itemseiten per Javascript, ein Abruf liefert nichts. Wer
# die Zahlen im Spiel am Tooltip sieht, kann sie hier bestaetigen oder
# korrigieren.
#
# Hier statt von Hand in ItemData.lua, weil diese Datei bei jedem Import
# neu geschrieben wird und eine Handkorrektur darin verloren geht.
# ---------------------------------------------------------------------

STAT_OVERRIDES = {
    2944:  {"STA": -3},   # Cursed Eye of Paleth
    81016: {"STA": -5},   # Bleeding Heart Talisman
}

ATTR_KEY = {
    "Strength": "STR", "Agility": "AGI", "Stamina": "STA",
    "Intellect": "INT", "Spirit": "SPI",
}

RES_KEY = {
    "Arcane": "RES_ARCANE", "Fire": "RES_FIRE", "Frost": "RES_FROST",
    "Nature": "RES_NATURE", "Shadow": "RES_SHADOW",
}


def parse_effects(lines, stats):
    """Zweitwerte aus den equip-Zeilen nachtragen. Rueckgabe sind die
    Zeilen ohne Treffer - die sind unbewertet und gehen in die Zaehlung
    fuer Punkt 7 ein."""
    rest = []
    for raw in lines or []:
        line = str(raw).strip()
        if not line:
            continue

        m = ALL_RES.match(line)
        if m:
            v = int(m.group(1))
            for key in RES_KEY.values():
                stats[key] = stats.get(key, 0) + v
            continue

        hit = False
        for key, pat in PATTERNS:
            m = pat.match(line)
            if not m:
                continue
            val = float(m.group(1))
            if val == int(val):
                val = int(val)
            # Eine Zeile kann auf mehrere Werte durchschlagen.
            for k in (key if isinstance(key, tuple) else (key,)):
                stats[k] = stats.get(k, 0) + val
            hit = True
            break

        if not hit:
            rest.append(line)
    return rest


# ---------------------------------------------------------------------
# Rufanforderung
#
# stats.requires enthaelt Berufe und Ruf gemischt. Ruf erkennt man am
# Bindestrich mit Standing dahinter. Bei 35 Items hat der Scrape den
# Fraktionsnamen verloren und nur "- Exalted" behalten; fuer die faellt
# der Importer auf die Tooltipzeile zurueck.
# ---------------------------------------------------------------------

STANDINGS = ("Exalted", "Revered", "Honored", "Friendly", "Neutral")
REP_LINE = re.compile(r"^Requires (.+?) - (%s)$" % "|".join(STANDINGS))


def reputation(item):
    st = item.get("stats") or {}
    req = st.get("requires")
    if isinstance(req, str):
        req = [req]
    for entry in (req or []):
        text = str(entry).strip()
        for standing in STANDINGS:
            if text.endswith(" - " + standing):
                faction = text[:-(len(standing) + 3)].strip()
                if faction:
                    return faction + " - " + standing
                break

    # Fallback: die vollstaendige Zeile steht im Tooltip
    tip = item.get("tooltip") or []
    if not isinstance(tip, list):
        tip = [tip]
    for raw in tip:
        m = REP_LINE.match(str(raw).strip())
        if m:
            return m.group(1) + " - " + m.group(2)
    return None


# ---------------------------------------------------------------------
# Item
# ---------------------------------------------------------------------

def build_item(item):
    """Ein Eintrag fuer ItemData.lua, oder None wenn nicht anlegbar."""
    slot = slot_number(item)
    if not slot:
        return None

    st = item.get("stats") or {}
    stats = {}

    for name, key in ATTR_KEY.items():
        v = (st.get("attributes") or {}).get(name)
        if v:
            stats[key] = v

    for name, key in RES_KEY.items():
        v = (st.get("resistances") or {}).get(name)
        if v:
            stats[key] = v

    if st.get("armor"):
        stats["ARMOR"] = st["armor"]
    if st.get("block"):
        stats["BLOCKVALUE"] = st["block"]

    if st.get("dps"):
        stats["WEAPON_DPS"] = st["dps"]
    if st.get("speed"):
        stats["WEAPON_SPEED"] = st["speed"]
    if st.get("dmgMin"):
        stats["WEAPON_MIN"] = st["dmgMin"]
    if st.get("dmgMax"):
        stats["WEAPON_MAX"] = st["dmgMax"]

    unscored = parse_effects(st.get("equip"), stats)

    # Klassenmaske: erst die Fakten des Servers, dann die Liste aus dem
    # Tooltip. Die Fakten sind verlaesslicher, die Liste ist Rueckfall.
    facts = item.get("facts") or {}
    try:
        classmask = int(str(facts.get("Class Mask", "-1")).strip() or "-1")
    except ValueError:
        classmask = -1
    if classmask in (0, -1) and st.get("classes"):
        bits = 0
        for name in st["classes"]:
            bits = bits + CLASS_BITS.get(name, 0)
        if bits:
            classmask = bits

    # 2047 und 32767 sind Masken, in denen jedes Bit gesetzt ist,
    # einschliesslich der in 1.12 unbenutzten 32 und 512. Sie bedeuten
    # "keine Beschraenkung" und werden zu -1, damit MaskAllows nicht
    # rechnen muss und die Datei kuerzer wird.
    if classmask > 0:
        allbits = 0
        for bit in CLASS_BITS.values():
            allbits = allbits + bit
        if classmask & allbits == allbits:
            classmask = -1

    try:
        racemask = int(str(facts.get("Race Mask", "-1")).strip() or "-1")
    except ValueError:
        racemask = -1

    itemclass = ITEMCLASS.get(item.get("classs"))
    if itemclass is None:
        itemclass = 2 if st.get("dps") else 4
    subclass = item.get("subclass")
    if not isinstance(subclass, int):
        table = WEAPON_SUBCLASS if itemclass == 2 else ARMOR_SUBCLASS
        subclass = table.get(st.get("type"), 0)

    out = {
        "name": item.get("name") or "",
        "ilvl": item.get("level") or 0,
        "quality": item.get("quality"),
        "slot": slot,
        "reqlevel": item.get("reqlevel") or st.get("requiresLevel") or None,
        # reqest wird unten gesetzt, wenn die Stufe geschaetzt ist.
        "reqest": None,
        "itemclass": itemclass,
        "subclass": subclass,
        "classmask": classmask,
        "racemask": racemask,
        "stats": stats,
    }

    # Fehlende Anforderungsstufe schaetzen.
    #
    # 3057 anlegbare Teile fuehren im Export keine. Ohne Stufe kann das
    # Addon nicht entscheiden, ob ein Teil jetzt tragbar ist oder erst
    # spaeter - und ein harter Filter auf die Anforderungsstufe, wie ihn
    # die Vergleichsseite benutzt, wuerde sie alle wegwerfen.
    #
    # Der Abstand zwischen Itemstufe und Anforderungsstufe liegt im
    # Bestand im Median bei genau 5. Nach oben begrenzt 60, weil es in
    # Vanilla keine hoehere Anforderung gibt - ein Teil auf Itemstufe 92
    # fordert 60, nicht 87.
    #
    # reqest=1 merkt sich, dass die Zahl geschaetzt ist. Eine Schaetzung,
    # die wie eine Messung aussieht, ist schlimmer als eine fehlende
    # Angabe: niemand kann sie spaeter noch nachpruefen.
    if out["reqlevel"] is None and slot:
        est = (out["ilvl"] or 1) - 5
        if est < 1:
            est = 1
        if est > 60:
            est = 60
        out["reqlevel"] = est
        out["reqest"] = 1

    over = STAT_OVERRIDES.get(item.get("id") or item.get("entry"))
    if over:
        for k, v in over.items():
            stats[k] = v

    # Proc und Benutzeffekt. 1 = Chance bei Treffer, 2 = Benutzen,
    # 3 = beides. Candidates.lua braucht das, damit ein Gegenstand mit
    # Sondereffekt nicht gegen einen mit reinen Werten verliert.
    proc = 0
    if st.get("chanceOnHit"):
        proc = proc + 1
    if st.get("use"):
        proc = proc + 2
    if proc:
        out["proc"] = proc

    if st.get("extraDamage"):
        out["xdmg"] = 1

    rep = reputation(item)
    if rep:
        out["rep"] = rep

    if unscored:
        out["unscored"] = len(unscored)

    if st.get("unique"):
        out["unique"] = 1
    if st.get("setName"):
        out["setname"] = st["setName"]

    # Das Symbol. GetItemInfo liefert es nur fuer Gegenstaende, die der
    # Client schon einmal gesehen hat - alles andere stand im Fenster als
    # Fragezeichen. Der Export fuehrt den Namen der Textur bei 99,4 % der
    # Eintraege; der Pfad davor ist immer derselbe und wird im Addon
    # angehaengt, statt ihn 14000 Mal mitzuschreiben.
    if item.get("icon"):
        out["icon"] = item["icon"]

    return out


# ---------------------------------------------------------------------
# Quellen
#
# Pro Item bleiben die besten MAX_PER_TYPE Quellen je Art. Die 2,1
# Millionen Dropzeilen des Exports schrumpfen damit auf eine
# Groessenordnung, die als Lua-Datei ladbar bleibt, ohne dass die
# Aussage verloren geht: wer ein Teil sucht, braucht nicht alle 473
# Mobs, sondern die drei mit der besten Chance.
# ---------------------------------------------------------------------

MAX_PER_TYPE = 3

# Entwicklereintraege. Der Serverdatenbestand fuehrt Gegner, die im Spiel
# nicht vorkommen. Sie standen als Quelle in den Daten und verdraengten
# dort echte Quellen aus den besten drei: "Windreaper" und "Archlight
# Talisman" hingen beide an "[UNUSED] Henria Derth".
UNUSED_MARKERS = (
    "[UNUSED]", "[DEPRECATED]", "[OLD]", "[PH]", "[TEST]", "[NYI]",
    "(OLD)", "(unused)",
)


def is_unused(name):
    text = str(name or "")
    if not text:
        return False
    for marker in UNUSED_MARKERS:
        if marker in text:
            return True
    return text.startswith("UNUSED") or "Test Mob" in text


def faction_of(entry):
    """react = [Allianz, Horde]. 1 freundlich, -1 feindlich.
    Rueckgabe: 1 nur Allianz, 2 nur Horde, None beide oder unbekannt."""
    react = entry.get("react")
    if not isinstance(react, list) or len(react) < 2:
        return None
    a, h = react[0], react[1]
    if a == 1 and h != 1:
        return 1
    if h == 1 and a != 1:
        return 2
    return None


def build_sources(item, geo, zones_used, npcs_used):
    """geo = (unit_zones, unit_names, quest_givers, object_zones,
    zone_names, loc_zones). Gegner und Truhen verortet pfQuest, Quests
    verorten sich selbst ueber ihr Feld "category". Kennt pfQuest einen
    Gegner nicht, hilft sein Feld "location" ueber loc_zones."""
    unit_zones, unit_names, quest_givers, object_zones, zone_names, \
        loc_zones = geo
    src = item.get("sources") or {}
    out = {}

    def note(row, npcid, name, entry=None):
        npcs_used[npcid] = name or unit_names.get(npcid) or ""
        z = unit_zones.get(npcid)
        if not z and entry is not None:
            z = loc_zones.get(first_location(entry))
        if not z:
            z = BOSS_ZONES.get(npcid)
        if z:
            row["z"] = z
            zones_used[z] = True

    # Gegner
    rows = []
    for e in src.get("dropped-by") or []:
        if not isinstance(e, dict) or not e.get("id"):
            continue
        if is_unused(e.get("name")):
            continue
        row = {"n": e["id"]}
        lvl = e.get("maxlevel") or e.get("minlevel")
        if lvl:
            row["l"] = lvl
        if e.get("percent"):
            row["p"] = round(float(e["percent"]), 4)
        if e.get("classification"):
            row["e"] = e["classification"]
        f = faction_of(e)
        if f:
            row["f"] = f
        note(row, e["id"], e.get("name"), e)
        rows.append(row)
    rows.sort(key=lambda r: -(r.get("p") or 0))
    if rows:
        keep = rows[:MAX_PER_TYPE]
        # Eine Quelle mit Ort muss dabei sein, sonst faellt der
        # Gegenstand aus dem Wegplan - die Liste gruppiert nach Zone.
        # Betrifft 27 Gegenstaende, deren drei beste Gegner pfQuest nicht
        # kennt, ein schlechterer aber schon.
        located = None
        for row in keep:
            if row.get("z"):
                located = row
                break
        if located is None:
            for row in rows[MAX_PER_TYPE:]:
                if row.get("z"):
                    keep.append(row)
                    break
        out["d"] = keep

    # Haendler. Die Chance ist hier immer 100 Prozent, dafuer zaehlen
    # Preis und die Marke des Quartiermeisters.
    vend = []
    for e in src.get("sold-by") or []:
        if not isinstance(e, dict) or not e.get("id"):
            continue
        if is_unused(e.get("name")):
            continue
        row = {"n": e["id"]}
        cost = e.get("cost")
        if isinstance(cost, list) and cost and isinstance(cost[0], int):
            row["c"] = cost[0]
        f = faction_of(e)
        if f:
            row["f"] = f
        if e.get("tag"):
            row["t"] = e["tag"]
        note(row, e["id"], e.get("name"), e)
        vend.append(row)
    if vend:
        out["v"] = vend[:MAX_PER_TYPE]

    # Questbelohnungen. pfQuest kennt keine einzige.
    quests = []
    for e in src.get("reward-of") or []:
        if not isinstance(e, dict) or not e.get("id"):
            continue
        try:
            qid = int(e["id"])
        except (TypeError, ValueError):
            continue
        row = {"q": qid, "t": e.get("name") or ""}
        lvl = e.get("reqlevel") or e.get("level")
        if lvl:
            try:
                row["l"] = int(lvl)
            except (TypeError, ValueError):
                pass
        side = e.get("side")
        if side in ("1", 1):
            row["f"] = 1
        elif side in ("2", 2):
            row["f"] = 2
        # Auswahlbelohnung: das Item ist eines von mehreren
        ch = e.get("itemchoices")
        if isinstance(ch, list) and len(ch) > 1:
            row["x"] = len(ch)
        # Wo die Quest stattfindet.
        #
        # Der Export fuehrt das selbst: "category" ist die AreaTable-ID
        # der Quest, und anders als bei den Gegnern ist dieser
        # Nummernkreis eindeutig - 3456 Naxxramas, 3428 Ahn'Qiraj,
        # 1977 Zul'Gurub, 25 Blackrock Mountain. pfQuest benennt 91,3 %
        # davon. Negative Werte sind Berufs- und Klassenquests ohne Ort.
        #
        # Das ist besser als der Standort des Questgebers: "The Defias
        # Brotherhood" faengt in Westfall an, spielt aber in den
        # Todesminen - und dahin muss man fuer das Teil.
        z = None
        cat = e.get("category")
        if isinstance(cat, int) and cat > 0 and cat in zone_names:
            z = cat
        giver = quest_givers.get(qid)
        if giver:
            row["g"] = giver
            npcs_used[giver] = unit_names.get(giver) or ""
            if z is None:
                z = unit_zones.get(giver)
        if z:
            row["z"] = z
            zones_used[z] = True
        quests.append(row)
    if quests:
        out["q"] = quests[:MAX_PER_TYPE]

    # Behaelter und Objekte in der Welt. Die stehen in pfQuests
    # Objekttabelle, nicht bei den Gegnern - hier bleibt es beim Namen.
    objs = []
    for key in ("contained-in-object", "contained-in-item"):
        for e in src.get(key) or []:
            if not isinstance(e, dict) or not e.get("id"):
                continue
            row = {"n": e["id"], "t": e.get("name") or ""}
            if e.get("percent"):
                row["p"] = round(float(e["percent"]), 4)
            # Truhen stehen in pfQuests Objekttabelle, im selben Format
            # wie die Gegner. Ohne Ort faellt ein Gegenstand, dessen
            # einzige Quelle eine Truhe ist, aus dem Wegplan - das sind
            # 131 Stueck.
            if key == "contained-in-object":
                z = object_zones.get(e["id"])
                if z:
                    row["z"] = z
                    zones_used[z] = True
            objs.append(row)
    objs.sort(key=lambda r: -(r.get("p") or 0))
    if objs:
        out["o"] = objs[:MAX_PER_TYPE]

    # Herstellung
    for e in src.get("created-by") or []:
        if isinstance(e, dict) and e.get("id"):
            out["c"] = [{"s": e["id"], "t": e.get("name") or ""}]
            break

    return out


# ---------------------------------------------------------------------
# Geografie
#
# Das Feld "location" des Exports ist NICHT benutzbar. Es mischt zwei
# Nummernkreise: Freilandzonen tragen die AreaTable-ID (47 Hinterland,
# 33 Schlingendorntal), Instanzen die Map-ID (209 Zul'Farrak,
# 229 Blackrock Spire, 349 Maraudon). Beide Kreise ueberschneiden sich -
# 47 ist als Map-ID Razorfen Kraul, 209 als AreaTable Shadowfang Keep.
# Aus der Zahl allein laesst sich die Zone also nicht bestimmen.
#
# Nachgewiesen an den Gegnernamen: unter 209 stehen Sandfury-Mobs
# (Zul'Farrak), unter 229 Blackhand Iron Guard (Blackrock Spire), unter
# 43 Druid of the Fang (Wailing Caverns). pfQuest nennt dieselben IDs
# "Shadowfang Keep", "Olsen's Farthing" und "Wild Shore".
#
# Deshalb kommt der Ort aus pfQuest, und zwar aus den Koordinaten der
# Gegner. Dieser Nummernkreis ist in sich geschlossen: alle 113
# Koordinatenzonen haben einen Namen, und die Namen stimmen. pfQuests
# Geografie ist verlaesslich - falsch sind dort die Dropchancen, und die
# kommen jetzt aus dem Export.
#
# Rollenteilung:
#   OctoWoW-Export -> Items, Werte, Dropchance, Mobstufe, Elite,
#                     Fraktion, Haendlerpreis, Questbelohnung
#   pfQuest        -> wo ein Gegner steht und wie die Zone heisst
# ---------------------------------------------------------------------

# ---------------------------------------------------------------------
# Ortsnummer des Exports als Rueckfall
#
# Fuer 704 von 5790 Gegnern mit Beute hat pfQuest keine Koordinaten:
# OctoWoW-eigene Gegner wie Hailar the Frigid, aber auch viele
# Instanzbosse, deren Eintrag in pfQuest "coords = {}" lautet. Ohne Ort
# fiel ihre Beute aus dem Wegplan - 1737 Gegenstaende hatten Quellen,
# aber keine davon mit Ort.
#
# Das Feld "location" ist allein nicht zu deuten (siehe unten), aber
# es laesst sich eichen: alle Gegner mit derselben Ortsnummer, die
# pfQuest verortet, stimmen ab. Unter 229 stehen 70 von 73 in
# Blackrock Spire, unter 2557 alle 15 in Dire Maul, unter 209 alle 26
# in Zul'Farrak - obwohl pfQuest die 209 "Shadowfang Keep" nennt. Damit
# ist die Ortsnummer eines unbekannten Gegners so gut wie die seiner
# Nachbarn.
#
# Gezaehlt wird jeder Gegner einmal, nicht jede Dropzeile, sonst
# entschiede ein einzelner Boss mit 200 Teilen die Wahl.
#
# Nummern, unter denen pfQuest keinen einzigen Gegner kennt, sind
# OctoWoW-eigene Gebiete. Sie stehen mit ihrer eigenen Nummer im
# Datenbestand; ohne Namen zeigt das Addon "Zone 822", und
# /bll zone benennt sie. Bekannte Namen stehen in LOCATION_NAMES.
#
# Bleibt die Ortsnummer 0 - so bei Ragnaros, Nefarian und den meisten
# Instanzbossen -, hilft nur BOSS_ZONES: wo ein Boss steht, ist eine
# Sachangabe zum Spiel. Die Zonennummern sind die, unter denen pfQuest
# die uebrigen Gegner derselben Instanz fuehrt.
# ---------------------------------------------------------------------

VOTE_MIN = 3        # mindestens so viele verortete Gegner
VOTE_SHARE = 0.8    # und so viele davon in derselben Zone

# Namen fuer Ortsnummern, die pfQuest nicht kennt.
#   822  Frostmane Hollow - Hailar the Frigid, Battlemaster Ubukaz,
#        Frostmane Oracle; Stufe 13-20. Name laut turtlelootline.com,
#        die denselben OctoWoW-Bestand anzeigt.
LOCATION_NAMES = {
    822: "Frostmane Hollow",
}


MC, BWL, SCHOLO, ST, AV, AQ40 = 2717, 2677, 2057, 1477, 2597, 3428
STRAT, BRS, WC, GNOME, BRD, DM = 2017, 1583, 718, 721, 1584, 2557
SILITHUS, VC, RFD, ZG = 1377, 5138, 722, 1977

BOSS_ZONES = {
    11502: MC,      # Ragnaros
    11583: BWL,     # Nefarian
    1853: SCHOLO,   # Darkmaster Gandling
    10506: SCHOLO,  # Kirtonos the Herald
    8443: ST,       # Avatar of Hakkar
    13256: AV,      # Lokholar the Ice Lord
    13419: AV,      # Ivus the Forest Lord
    15517: AQ40,    # Ouro
    10439: STRAT,   # Ramstein the Gorger
    11143: STRAT,   # Postmaster Malown
    10808: STRAT,   # Timmy the Cruel
    10516: STRAT,   # The Unforgiven
    10264: BRS,     # Solakar Flamewreath
    10339: BRS,     # Gyth
    10584: BRS,     # Urok Doomhowl
    10268: BRS,     # Gizrul the Slavener
    9596: BRS,      # Bannok Grimaxe
    10263: BRS,     # Burning Felguard
    3654: WC,       # Mutanus the Devourer
    7361: GNOME,    # Grubbis
    9027: BRD, 9028: BRD, 9029: BRD,   # Ring des Gesetzes
    9030: BRD, 9031: BRD, 9032: BRD,
    9537: BRD,      # Hurley Blackbreath
    14506: DM,      # Lord Hel'nurath
    15203: SILITHUS, 15204: SILITHUS, 15205: SILITHUS,  # Abyssische Rat
    15305: SILITHUS, 15206: SILITHUS, 15207: SILITHUS,
    15208: SILITHUS, 15220: SILITHUS, 15209: SILITHUS,
    15211: SILITHUS, 15212: SILITHUS, 15307: SILITHUS,
    643: VC,        # Sneed
    7355: RFD,      # Tuten'kash
    7356: RFD,      # Plaguemaw the Rotting
    15082: ZG, 15083: ZG, 15084: ZG, 15085: ZG,  # Rand des Wahnsinns
}


def first_location(entry):
    loc = entry.get("location")
    if isinstance(loc, list) and loc and isinstance(loc[0], int):
        return loc[0]
    if isinstance(loc, int):
        return loc
    return 0


def vote_locations(files, unit_zones, zone_names):
    """Ortsnummer -> Zone, geeicht an den Gegnern, die pfQuest kennt."""
    votes = collections.defaultdict(collections.Counter)
    unknown = collections.Counter()
    seen = set()
    for path in files:
        for line in open(path, encoding="utf-8"):
            try:
                raw = json.loads(line)
            except ValueError:
                continue
            src = raw.get("sources") or {}
            for key in ("dropped-by", "sold-by"):
                for e in src.get(key) or []:
                    if not isinstance(e, dict) or not e.get("id"):
                        continue
                    if e["id"] in seen:
                        continue
                    seen.add(e["id"])
                    loc = first_location(e)
                    if not loc:
                        continue
                    z = unit_zones.get(e["id"])
                    if z:
                        votes[loc][z] += 1
                    else:
                        unknown[loc] += 1

    out, stats = {}, collections.Counter()
    for loc in unknown:
        v = votes.get(loc)
        if v:
            z, n = v.most_common(1)[0]
            total = sum(v.values())
            if total >= VOTE_MIN and n >= VOTE_SHARE * total:
                out[loc] = z
                stats["abgestimmt"] += 1
            else:
                stats["uneindeutig"] += 1
        else:
            # Kein einziger Gegner dieser Nummer ist in pfQuest verortet:
            # ein Gebiet, das es nur auf diesem Server gibt. Die
            # Verwechslung zwischen Karten- und Gebietsnummer betrifft
            # die alten Instanzen, und die haben alle Stimmen. Hier
            # bleibt die Nummer selbst - mit pfQuests Namen, falls
            # vorhanden (820 "The Golden Plains"), sonst ohne.
            out[loc] = loc
            stats["eigene Nummer"] += 1
            sys.stdout.write("  Ortsnummer %d ohne Stimmen -> %s (%d Gegner)\n"
                             % (loc, zone_names.get(loc, "ohne Namen"),
                                unknown[loc]))
    return out, stats


ZONE_NAME = re.compile(r"\[(\d+)\]\s*=\s*\"(.*?)\"")
UNIT_NAME = re.compile(r"\[(\d+)\]\s*=\s*\"(.*?)\"")
COORD = re.compile(r"\{\s*[\d.]+\s*,\s*[\d.]+\s*,\s*(\d+)\s*,")
ENTRY_HEAD = re.compile(r"^\s{2}\[(\d+)\]\s*=\s*\{", re.M)


def unescape(text):
    """pfQuest schreibt Lua-Strings mit \\' und \\\\."""
    return text.replace("\\'", "'").replace('\\"', '"').replace("\\\\", "\\")


def load_zone_names(paths):
    """Zonennamen aus den enUS-Dateien. Spaeter uebergebene Dateien
    ueberschreiben, deshalb die serverspezifische zuletzt nennen."""
    names = {}
    for path in paths:
        if not os.path.isfile(path):
            sys.stderr.write("Zonendatei fehlt: %s\n" % path)
            continue
        text = open(path, encoding="utf-8", errors="replace").read()
        for m in ZONE_NAME.finditer(text):
            zid, name = int(m.group(1)), unescape(m.group(2))
            # "_" und "???" sind pfQuests Platzhalter fuer Zonen ohne
            # Namen. Sie als Namen zu uebernehmen hiesse, im Wegplan
            # eine Gruppe namens "???" zu zeigen - das sieht nach einem
            # kaputten Addon aus, obwohl die Daten stimmen. Betrifft
            # Zone 5557 mit 37 Gegenstaenden: vier Bosse auf Stufe 63,
            # Beute mit Itemlevel 92 bis 96. Welche Instanz das ist,
            # laesst sich aus den Daten nicht belegen - "Karazhan Crypt"
            # und "Tower of Karazhan" sind bereits eigene Zonen.
            #
            # Ohne Namen faellt die Zone hier raus; das Addon zeigt
            # stattdessen "Zone 5557" und laesst sie mit
            # "/bll zone 5557 <Name>" benennen.
            if name and name != "_" and name != "???":
                names[zid] = name
    return names


def load_unit_names(paths):
    """NPC-Namen aus den enUS-Dateien."""
    names = {}
    for path in paths:
        if not os.path.isfile(path):
            sys.stderr.write("Namensdatei fehlt: %s\n" % path)
            continue
        text = open(path, encoding="utf-8", errors="replace").read()
        for m in UNIT_NAME.finditer(text):
            names[int(m.group(1))] = unescape(m.group(2))
    return names


QUEST_START = re.compile(r"\[\"start\"\] = \{\s*\[\"U\"\] = \{\s*(\d+)")


def load_quest_givers(paths):
    """Questgeber je Quest. Der Export nennt die Quest, aber nicht, wo
    sie anfaengt - und eine Questbelohnung ohne Ort beantwortet die Frage
    "wohin als naechstes" nicht. pfQuest fuehrt den Geber unter
    ["start"]["U"] und deckt 87,5 Prozent der gebrauchten Quests ab."""
    givers = {}
    for path in paths:
        if not os.path.isfile(path):
            sys.stderr.write("Questdatei fehlt: %s\n" % path)
            continue
        text = open(path, encoding="utf-8", errors="replace").read()
        heads = list(ENTRY_HEAD.finditer(text))
        for i in range(len(heads)):
            start = heads[i].end()
            end = heads[i + 1].start() if i + 1 < len(heads) else len(text)
            m = QUEST_START.search(text[start:end])
            if m:
                givers[int(heads[i].group(1))] = int(m.group(1))
    return givers


def load_unit_zones(paths):
    """Zone je NPC aus den Koordinaten. Steht ein Gegner in mehreren
    Zonen, gewinnt die mit den meisten Punkten - das ist die, in der ihn
    ein Spieler am ehesten findet."""
    zones = {}
    for path in paths:
        if not os.path.isfile(path):
            sys.stderr.write("Koordinatendatei fehlt: %s\n" % path)
            continue
        text = open(path, encoding="utf-8", errors="replace").read()
        heads = list(ENTRY_HEAD.finditer(text))
        for i in range(len(heads)):
            start = heads[i].end()
            end = heads[i + 1].start() if i + 1 < len(heads) else len(text)
            block = text[start:end]
            tally = {}
            for m in COORD.finditer(block):
                z = int(m.group(1))
                tally[z] = tally.get(z, 0) + 1
            if not tally:
                continue
            best = None
            for z in tally:
                if best is None or tally[z] > tally[best]:
                    best = z
            zones[int(heads[i].group(1))] = best
    return zones


# ---------------------------------------------------------------------
# Schreiben
# ---------------------------------------------------------------------

def lua_string(text):
    out = str(text).replace("\\", "\\\\").replace('"', '\\"')
    return '"' + out.replace("\r", "").replace("\n", " ") + '"'


def lua_number(v):
    if isinstance(v, float):
        if v == int(v):
            return str(int(v))
        return ("%.4f" % v).rstrip("0").rstrip(".")
    return str(v)


def lua_value(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, str):
        return lua_string(v)
    if isinstance(v, (int, float)):
        return lua_number(v)
    if isinstance(v, dict):
        parts = []
        for k in sorted(v.keys()):
            parts.append("%s=%s" % (k, lua_value(v[k])))
        return "{" + ",".join(parts) + "}"
    if isinstance(v, list):
        return "{" + ",".join(lua_value(x) for x in v) + "}"
    return "nil"


ITEM_ORDER = ["name", "ilvl", "quality", "slot", "reqlevel", "reqest", "itemclass",
              "subclass", "classmask", "racemask", "proc", "xdmg",
              "unique", "unscored", "rep", "setname", "icon", "stats"]


def header(count, extra=""):
    return (
        "-- Automatisch erzeugt von tools/octo_import.py\n"
        "-- Quelle: OctoWoW-Export (octowow.st/db)\n"
        "-- Erzeugt: %s\n"
        "-- Eintraege: %d\n"
        "%s"
        "-- REINE DATEN. Nicht von Hand bearbeiten.\n\n"
        % (time.strftime("%Y-%m-%d %H:%M:%S"), count, extra)
    )


def write_items(path, items):
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(header(len(items),
                 "-- Werte strukturiert aus dem Export, nicht aus Tooltips.\n"
                 "-- proc: 1 Chance bei Treffer, 2 Benutzen, 3 beides.\n"))
        fh.write("BananaLootlineItemData = {\n")
        for itemid in sorted(items.keys()):
            e = items[itemid]
            parts = []
            for key in ITEM_ORDER:
                if key not in e:
                    continue
                val = e[key]
                if val is None or val == "":
                    continue
                if val == 0 and key != "quality":
                    continue
                if key == "stats" and not val:
                    continue
                parts.append("%s=%s" % (key, lua_value(val)))
            fh.write("[%d]={%s},\n" % (itemid, ",".join(parts)))
        fh.write("}\n")


def write_sources(path, sources):
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(header(len(sources),
                 "-- d Gegner, v Haendler, q Quest, o Objekt, c Herstellung.\n"
                 "-- n NPC/Objekt, l Stufe, z Zone, p Chance, e Elite,\n"
                 "-- f Fraktion (1 Allianz, 2 Horde), c Preis, t Text,\n"
                 "-- q Quest-ID, x Anzahl Auswahlbelohnungen,\n"
                 "-- g Questgeber.\n"
                 "-- Je Art bleiben die %d besten Quellen.\n" % MAX_PER_TYPE))
        fh.write("BananaLootlineSourceData = {\n")
        for itemid in sorted(sources.keys()):
            fh.write("[%d]=%s,\n" % (itemid, lua_value(sources[itemid])))
        fh.write("}\n")


def write_zones(path, names, used):
    keep = {}
    missing = []
    for zid in used:
        if zid in names:
            keep[zid] = names[zid]
        else:
            missing.append(zid)
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(header(len(keep),
                 "-- Zonennamen zu den IDs aus SourceData.lua.\n"
                 "-- Herkunft: pfQuest. Der Nummernkreis des OctoWoW-\n"
                 "-- Exports ist nicht eindeutig, siehe octo_import.py.\n"))
        fh.write("BananaLootlineZoneNames = {\n")
        for zid in sorted(keep.keys()):
            fh.write("[%d]=%s,\n" % (zid, lua_string(keep[zid])))
        fh.write("}\n")
    return missing


def write_npcs(path, npcs):
    keep = {}
    for npcid in npcs:
        if npcs[npcid]:
            keep[npcid] = npcs[npcid]
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(header(len(keep),
                 "-- Namen der Gegner und Haendler aus SourceData.lua.\n"
                 "-- Damit funktioniert die Quellenanzeige auch ohne\n"
                 "-- pfQuest; pfQuest liefert nur noch die Karte.\n"))
        fh.write("BananaLootlineNpcNames = {\n")
        for npcid in sorted(keep.keys()):
            fh.write("[%d]=%s,\n" % (npcid, lua_string(keep[npcid])))
        fh.write("}\n")
    return len(keep)


# ---------------------------------------------------------------------
# Hauptlauf
# ---------------------------------------------------------------------

def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2

    export = argv[1]
    outdir = os.path.join("BananaLootline", "Data")
    zonepaths, namepaths, coordpaths = [], [], []
    questpaths, objectpaths = [], []
    i = 2
    while i < len(argv):
        if argv[i] == "--out" and i + 1 < len(argv):
            outdir = os.path.join(argv[i + 1], "Data")
            i = i + 2
        elif argv[i] == "--zones" and i + 1 < len(argv):
            zonepaths.append(argv[i + 1])
            i = i + 2
        elif argv[i] == "--units" and i + 1 < len(argv):
            namepaths.append(argv[i + 1])
            i = i + 2
        elif argv[i] == "--coords" and i + 1 < len(argv):
            coordpaths.append(argv[i + 1])
            i = i + 2
        elif argv[i] == "--quests" and i + 1 < len(argv):
            questpaths.append(argv[i + 1])
            i = i + 2
        elif argv[i] == "--objects" and i + 1 < len(argv):
            objectpaths.append(argv[i + 1])
            i = i + 2
        else:
            sys.stderr.write("Unbekanntes Argument: %s\n" % argv[i])
            return 2

    if not os.path.isdir(outdir):
        os.makedirs(outdir)

    files = sorted(glob.glob(os.path.join(export,
                                          "octowow_items_teil*.jsonl")))
    if not files:
        files = sorted(glob.glob(os.path.join(export, "*.jsonl")))
    if not files:
        sys.stderr.write("Keine JSONL-Dateien in %s\n" % export)
        return 1

    zone_names   = load_zone_names(zonepaths)
    unit_names   = load_unit_names(namepaths)
    unit_zones   = load_unit_zones(coordpaths)
    quest_givers = load_quest_givers(questpaths)
    object_zones = load_unit_zones(objectpaths)
    print("pfQuest: %d Zonennamen, %d NPC-Namen, %d NPCs mit Ort, "
          "%d Questgeber, %d Objekte mit Ort"
          % (len(zone_names), len(unit_names), len(unit_zones),
             len(quest_givers), len(object_zones)))
    for loc, name in LOCATION_NAMES.items():
        if loc in zone_names and zone_names[loc] != name:
            sys.stderr.write("LOCATION_NAMES %d kollidiert mit %s\n"
                             % (loc, zone_names[loc]))
        else:
            zone_names[loc] = name
    loc_zones, loc_stats = vote_locations(files, unit_zones, zone_names)
    print("Ortsnummern: %s" % ", ".join("%d %s" % (n, k) for k, n
                                         in sorted(loc_stats.items())))
    geo = (unit_zones, unit_names, quest_givers, object_zones, zone_names,
           loc_zones)

    items, sources, zones_used, npcs_used = {}, {}, {}, {}
    total, skipped = 0, 0
    unscored_lines = collections.Counter()
    stat_use = collections.Counter()
    srctypes = collections.Counter()

    for path in files:
        for line in open(path, encoding="utf-8"):
            line = line.strip()
            if not line:
                continue
            try:
                raw = json.loads(line)
            except ValueError:
                continue
            total = total + 1
            itemid = raw.get("id")
            if not isinstance(itemid, int):
                continue

            entry = build_item(raw)
            if entry is None:
                skipped = skipped + 1
                continue

            items[itemid] = entry
            for key in entry["stats"]:
                stat_use[key] += 1
            st = raw.get("stats") or {}
            for rest in parse_effects(list(st.get("equip") or []), {}):
                unscored_lines[re.sub(r"\d+", "N", rest)] += 1

            src = build_sources(raw, geo, zones_used, npcs_used)
            if src:
                sources[itemid] = src
                for key in src:
                    srctypes[key] += 1

    write_items(os.path.join(outdir, "ItemData.lua"), items)
    write_sources(os.path.join(outdir, "SourceData.lua"), sources)
    missing = write_zones(os.path.join(outdir, "ZoneNames.lua"),
                          zone_names, zones_used)
    named = write_npcs(os.path.join(outdir, "NpcData.lua"), npcs_used)

    # Wie viele Quellen haben am Ende einen Ort? Das ist die Zahl, an der
    # sich die Wegplanung messen laesst.
    located, total_rows = 0, 0
    for itemid in sources:
        for key in ("d", "v", "q", "o"):
            for row in sources[itemid].get(key) or []:
                total_rows = total_rows + 1
                if row.get("z"):
                    located = located + 1

    print("Gelesen: %d Items, anlegbar: %d, uebersprungen: %d"
          % (total, len(items), skipped))
    print("Mit Quelle: %d  ohne: %d" % (len(sources), len(items) - len(sources)))
    print("Quellenarten: %s" % dict(srctypes))
    print("NPCs: %d gebraucht, %d mit Namen" % (len(npcs_used), named))
    print("Quellenzeilen: %d, davon mit Ort: %d (%.1f%%)"
          % (total_rows, located,
             100.0 * located / total_rows if total_rows else 0))
    print("Zonen benutzt: %d, ohne Namen: %d" % (len(zones_used), len(missing)))
    if missing:
        print("  ohne Namen: %s" % sorted(missing)[:20])

    for name in ("ItemData.lua", "SourceData.lua", "ZoneNames.lua",
                 "NpcData.lua"):
        p = os.path.join(outdir, name)
        print("  %-16s %8.1f KB" % (name, os.path.getsize(p) / 1024.0))

    print("\nBelegte Wertschluessel:")
    for key, n in stat_use.most_common(40):
        print("  %-20s %6d" % (key, n))

    if unscored_lines:
        print("\nHaeufigste unbewertete Effektzeilen:")
        for text, n in unscored_lines.most_common(15):
            print("  %5d  %s" % (n, text[:76]))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
