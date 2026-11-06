"""Generates Data/Enchants.lua from the Tortoise (Turtle WoW) database.

Every permanent item enchant (spell effect 53) that players can actually apply -
enchanting recipes, arcanums/librams/invocations, shoulder signets and sigils,
armor kits, scopes, shield spikes, belt buckles and jewelcrafting gemstones - is
turned into an AshenBuildsEnchants entry with the slots it fits and the stats the
character sheet uses, parsed from the spell's own tooltip text.

Enchant IDs are part of exported build codes, so they must stay stable:
  * IDs 1-90 are the hand-written catalog from v0.9.6 and map to their spells in LEGACY.
  * Everything else uses 100000 + spell ID.

Usage:  python tools/build_enchants.py --database path/to/tortoise.sqlite
(tortoise.sqlite is the file Data/AshenDB/tools/build_ashendb.py downloads.)
"""
import argparse, json, re, sqlite3
from pathlib import Path

LEGACY = {1: 22840, 2: 22846, 3: 22844, 4: 20025, 5: 20011, 6: 20013, 7: 20012, 8: 13890, 9: 20023, 10: 20034,
          11: 23799, 12: 23800, 13: 20017, 14: 16623, 15: 15397, 16: 15402, 17: 15400, 18: 15404, 19: 15406, 20: 15389,
          21: 15340, 22: 15391, 23: 15394, 25: 24149, 26: 24164, 27: 24162, 28: 24161, 29: 24165, 30: 24167, 31: 24168,
          32: 24160, 33: 24163, 34: 24422, 35: 24421, 36: 24420, 37: 29483, 38: 29467, 39: 29475, 40: 29480, 41: 22599,
          42: 20014, 43: 20015, 44: 13882, 45: 25081, 46: 25082, 47: 25086, 48: 25084, 49: 13657, 50: 13941, 51: 20026,
          52: 20028, 53: 13858, 54: 20010, 55: 23802, 56: 23801, 57: 20008, 58: 20009, 59: 13939, 60: 13945, 61: 25080,
          62: 25079, 63: 25078, 64: 25074, 65: 25073, 66: 25072, 67: 13948, 68: 20020, 69: 20024, 70: 13935, 71: 22749,
          72: 22750, 73: 23804, 74: 23803, 75: 20031, 76: 13898, 77: 20032, 78: 20029, 79: 20033, 80: 13915, 81: 27837,
          82: 20036, 83: 20035, 84: 20030, 85: 13933, 86: 13905, 87: 13817, 88: 22779, 89: 12459, 90: 12460}

SKIP_NAME = re.compile(r"QA|Test|Copy of|zzOLD|\[PH\]|Sharpen Blade|Fishing Line|Spurs|Skinning|Mining|Herbalism|Fishing|Riding|Weapon Chain|Stealth", re.I)

# Slot rules: (regex on "name | description", slots, requirement)
SLOT_RULES = [
    (r"^Enchant Cloak", ["BACK"], None),
    (r"^Enchant Chest", ["CHEST"], None),
    (r"^Enchant Bracer", ["WRIST"], None),
    (r"^Enchant Gloves", ["HANDS"], None),
    (r"^Enchant Boots", ["FEET"], None),
    (r"^Enchant Shield", ["OFFHAND"], "shield"),
    (r"^Enchant 2H Weapon", ["MAINHAND"], "twohand"),
    (r"^Enchant Weapon", ["MAINHAND", "OFFHAND"], "weapon"),
    (r"ring or amulet", ["NECK", "FINGER1", "FINGER2"], None),
    (r"to your belt", ["WAIST"], None),
    (r"leg or head slot", ["HEAD", "LEGS"], None),
    (r"shoulder slot", ["SHOULDER"], None),
    (r"to a head slot item", ["HEAD"], None),
    (r"chest, legs, hands or feet", ["CHEST", "LEGS", "HANDS", "FEET"], None),
    (r"bow or gun", ["RANGED"], None),
    (r"to your shield", ["OFFHAND"], "shield"),
    (r"two-handed sword, mace, axe, staff, or polearm", ["MAINHAND"], "twohand"),
]

SCHOOLS = ["fire", "frost", "shadow", "nature", "arcane", "holy"]
PRIMARY = {"strength": "str", "agility": "agi", "stamina": "sta", "intellect": "int", "spirit": "spi"}
N = r"\+?(-?\d+)"


def parse_stats(desc):
    d = desc.lower()
    d = re.sub(r"only usable on items level \d+ and above\.?", "", d)
    d = re.sub(r"does not stack with other enchantments.*", "", d)
    s = {}
    # Proc effects ("often heals and increases Strength by 100 for 15 sec") aren't permanent stats.
    if re.search(r"\boften\b|chance per hit|sometimes|for \d+ sec", d):
        return s

    def add(k, v):
        s[k] = s.get(k, 0) + abs(int(v))

    def take(pattern):
        """Finds pattern, returns the number and blanks the match so it isn't counted twice."""
        nonlocal d
        m = re.search(pattern, d)
        if not m:
            return None
        d = d[:m.start()] + " " + d[m.end():]
        return m.group(1)

    for pat in [r"all stats by " + N, N + r" to all stats", r"all stats by " + N]:
        v = take(pat)
        if v:
            for k in PRIMARY.values(): add(k, v)
    v = take(r"(?:magical resistances of your spell targets|spell penetration) by " + N) or take(N + r" spell penetration")
    if v: add("spellPen", v)
    for pat in [r"all resistances by " + N, r"resistance to all schools of magic by " + N, N + r" to all resistances",
                r"magical resistances by " + N, N + r" resistance to all magic schools", r"all resistances by " + N]:
        v = take(pat)
        if v:
            for sch in SCHOOLS[:5]: add(sch + "Res", v)
    for sch in SCHOOLS:
        for pat in [sch + r" (?:magic )?resistance by " + N, r"resistance to " + sch + r" by " + N, N + r" " + sch + r" resistance"]:
            v = take(pat)
            if v: add(sch + "Res", v)
    v = take(r"ranged attack power by " + N) or take(N + r" ranged attack power")
    if v: add("rap", v)
    v = take(r"attack power by " + N) or take(N + r" attack power")
    if v: add("ap", v)
    v = take(r"critical strike with spells by " + N + "%")
    if v: add("spellCrit", v)
    for sch in SCHOOLS:
        v = take(sch + r" spell damage by (?:up to )?" + N) or take(r"up to " + N + r" additional " + sch + r" damage when casting")
        if v: add(sch + "Power", v)
    # Spell damage + healing (items store "healing" as including +damage and healing).
    for pat in [N + r" healing and damage from spells", r"healing and damage (?:from|to) (?:all )?spells[^\d]*" + N, r"damage and healing done by magical spells and effects up to " + N,
                r"all healing and spell damage by up to " + N, r"spell damage and healing by up to " + N, r"healing and spell damage by up to " + N,
                r"adds " + N + r" to all healing and damage spells", r"spell power (?:value )?(?:of an item[^\d]*)?by " + N, N + r" spell damage",
                r"spell power by " + N, r"add up to " + N + r" damage to spells", r"spell damage by " + N]:
        v = take(pat)
        if v:
            add("spellPower", v); add("healing", v)
    for pat in [r"healing done by (?:magical )?spells and effects (?:up to )?" + N, r"healing (?:spells )?by (?:up to )?" + N,
                r"up to " + N + r" points of healing", r"healing power by " + N, r"healing by " + N, r"healing spells by up to " + N]:
        v = take(pat)
        if v: add("healing", v)
    for sch in SCHOOLS:
        v = take(sch + r" (?:spell )?damage by (?:up to )?" + N)
        if v: add(sch + "Power", v)
    for word, key in PRIMARY.items():
        for pat in [word + r" of the (?:bearer|wearer) by " + N, word + r" by " + N, N + r" " + word, r"add " + N + r" to " + word, r"\+" + N + r" " + word]:
            v = take(pat)
            if v: add(key, v)
    v = take(r"(?:health|hit points)(?: of the wearer)? by " + N) or take(N + r" (?:health|hit points)") or take(r"\+" + N + r" health")
    if v: add("health", v)
    v = take(N + r" mana (?:every|per) 5") or take(r"mana regeneration by " + N)
    if v: add("mp5", v)
    v = take(r"mana(?: of the wearer)? by " + N) or take(N + r" mana") or take(r"\+" + N + r" mana")
    if v: add("mana", v)
    v = take(r"armor penetration by " + N) or take(N + r" armor penetration")
    if v: add("armorPen", v)
    v = take(r"block value by " + N) or take(N + r" shield block value")
    if v: add("blockValue", v)
    v = take(r"block chance by " + N + "%") or take(N + r"% chance to block")
    if v: add("block", v)
    v = take(r"defense (?:skill |value )?(?:of the wearer )?(?:is increased |of an item[^\d]*)?by " + N) or take(N + r" defense")
    if v: add("defense", v)
    v = take(r"armor value of an item[^\d]*by " + N) or take(r"armor by " + N) or take(N + r" (?:additional )?(?:points of )?armor")
    if v: add("armor", v)
    v = take(N + r"% dodge") or take(N + r"% chance to dodge") or take(r"dodge chance by " + N)
    if v: add("dodge", v)
    v = take(N + r"% haste") or take(r"\+" + N + r"% attack and casting speed")
    if v: add("haste", v)
    v = take(r"vampirism by " + N) or take(N + r"% vampirism")
    if v: add("leech", v)
    v = take(N + r"% chance to hit with spells")
    if v: add("spellHit", v)
    v = take(r"chance to hit by " + N + "%")
    if v: add("rangedHit", v)
    v = take(N + r"% chance to hit")
    if v: add("hit", v)
    v = take(r"chance to crit by " + N + "%")
    if v: add("rangedCrit", v)
    v = take(r"critical strike by " + N + "%") or take(r"chance to (?:land a )?critical[^\d]*by " + N + "%")
    if v: add("crit", v)
    return s


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--database", required=True)
    ap.add_argument("--out", default=str(Path(__file__).resolve().parent.parent / "Data" / "Enchants.lua"))
    args = ap.parse_args()
    con = sqlite3.connect(args.database)

    use_items = {}
    for col in range(1, 6):
        for it, name, sp, hidden in con.execute(f"select entry,name,spellid_{col},hidden from items where spellid_{col}>0"):
            if not hidden:
                use_items.setdefault(sp, []).append(name)

    entries = []
    for sid, name, desc, eff, skill in con.execute("select entry,name,description,effects,skill from spells where effects like '%\"effect\":53,%'"):
        desc = (desc or "").strip()
        items = use_items.get(sid, [])
        if skill != 333 and not items:
            continue
        if SKIP_NAME.search(name or "") or not desc:
            continue
        rule = next((r for r in SLOT_RULES if re.search(r[0], name) or re.search(r[0], desc, re.I)), None)
        if not rule:
            continue
        label = re.sub(r"^Enchant (?:Cloak|Chest|Bracer|Gloves|Boots|Shield|2H Weapon|Weapon) - ", "", name)
        if skill == 333 and rule[2] == "twohand":
            label = "2H " + label
        if skill != 333 and items:
            label = items[0]
        label = label.replace("�", "").strip()
        min_ilvl = re.search(r"items level (\d+) and above", desc)
        entries.append({"spell": sid, "name": label, "slots": rule[1], "req": rule[2], "stats": parse_stats(desc), "tip": desc,
                        "minIlvl": int(min_ilvl.group(1)) if min_ilvl else 0})

    # Same item name for different effects (e.g. five "Lesser Arcanum of Voracity"): add the stat.
    counts = {}
    key = lambda e: (e["name"], tuple(e["slots"]))
    for e in entries: counts[key(e)] = counts.get(key(e), 0) + 1
    labels = {"str": "Strength", "agi": "Agility", "sta": "Stamina", "int": "Intellect", "spi": "Spirit"}
    for e in entries:
        if counts[key(e)] > 1 and e["stats"]:
            k = sorted(e["stats"])[0]
            e["name"] += " (" + labels.get(k, k) + ")"

    by_spell = {e["spell"]: e for e in entries}
    legacy_of = {v: k for k, v in LEGACY.items()}
    missing = [k for k, v in LEGACY.items() if v not in by_spell]
    if missing:
        raise SystemExit(f"legacy enchant IDs lost their spell: {missing}")
    for e in entries:
        e["id"] = legacy_of.get(e["spell"], 100000 + e["spell"])

    group = {s: i for i, s in enumerate(["HEAD", "NECK", "SHOULDER", "BACK", "CHEST", "WRIST", "HANDS", "WAIST", "LEGS", "FEET", "FINGER1", "MAINHAND", "OFFHAND", "RANGED"])}
    entries.sort(key=lambda e: (min(group.get(s, 99) for s in e["slots"]), e["req"] or "", -e["spell"]))

    out = ["-- Generated by tools/build_enchants.py from the Tortoise (Turtle WoW) database. Do not edit by hand;",
           "-- change the generator and re-run it. IDs are part of build codes: 1-90 are the original catalog,",
           "-- everything else is 100000 + spell ID.",
           "-- req: \"weapon\" (any weapon), \"twohand\" (two-handed weapon only), \"shield\" (shield only).",
           "AshenBuildsEnchants = {"]
    for e in entries:
        stats = ",".join(f"{k}={v}" for k, v in sorted(e["stats"].items()))
        slots = ",".join(f"{s}=true" for s in e["slots"])
        req = f", req={lua_str(e['req'])}" if e["req"] else ""
        if e["minIlvl"]:
            req += f", minIlvl={e['minIlvl']}"
        out.append(f"  [{e['id']}]={{n={lua_str(e['name'])}, slots={{{slots}}}{req}, stats={{{stats}}}, spell={e['spell']}, tip={lua_str(e['tip'])}}},")
    out.append("}")
    out.append("AshenBuildsEnchantOrder = {" + ",".join(str(e["id"]) for e in entries) + "}")
    out.append("-- Slots that can carry an enchant (Turtle adds rings/amulets via jewelcrafting and belts via buckles).")
    out.append("AshenBuildsEnchantSlots = {HEAD=true,NECK=true,SHOULDER=true,BACK=true,CHEST=true,WRIST=true,HANDS=true,WAIST=true,LEGS=true,FEET=true,FINGER1=true,FINGER2=true,MAINHAND=true,OFFHAND=true,RANGED=true}")
    Path(args.out).write_text("\n".join(out) + "\n", encoding="utf-8", newline="\n")
    unparsed = [e for e in entries if not e["stats"]]
    print(f"wrote {len(entries)} enchants ({len(unparsed)} with effects the sheet can't model) to {args.out}")


if __name__ == "__main__":
    main()
