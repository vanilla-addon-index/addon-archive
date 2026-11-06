#!/usr/bin/env python3
"""Regenerate PandaUI's static item sort data from Tortoise DB Viewer SQLite.

The committed VMaNGOS data remains the baseline for unmodified Vanilla items.
Rows marked ``custom`` by Tortoise DB Viewer are classified from the current
Turtle WoW fields and profession graph, then replace any stale baseline row.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sqlite3
import sys
from collections import Counter, defaultdict
from pathlib import Path


CATEGORY_SPAN = 67_108_864
FAMILY_SPAN = 262_144
SUBGROUP_SPAN = 1_024

CATEGORY_NAMES = {
    1: "gear",
    2: "quest",
    3: "consumable",
    4: "food",
    5: "potion",
    6: "buff",
    7: "bandage",
    8: "explosive",
    9: "reagent",
    10: "tradegoods",
    11: "recipe",
    12: "ammo",
    13: "container",
    14: "key",
    15: "junk",
    16: "misc",
    31: "unknown",
}

# Trade-family ids are consumed by core/itemcategory.lua. Values outside this
# table deliberately remain in the broad Trade Goods section.
TRADE_FAMILY = {
    "leather": 1,
    "cloth": 2,
    "herb": 3,
    "ore": 4,
    "gem": 5,
    "enchanting": 6,
    "engineering": 7,
    "meat": 8,
    "alchemy": 9,
    "poison": 10,
    "general": 11,
}

SKILL_FAMILY = {
    164: TRADE_FAMILY["ore"],          # Blacksmithing
    165: TRADE_FAMILY["leather"],      # Leatherworking
    171: TRADE_FAMILY["herb"],         # Alchemy
    182: TRADE_FAMILY["herb"],         # Herbalism
    185: TRADE_FAMILY["meat"],         # Cooking
    186: TRADE_FAMILY["ore"],          # Mining
    197: TRADE_FAMILY["cloth"],        # Tailoring
    202: TRADE_FAMILY["engineering"],  # Engineering
    333: TRADE_FAMILY["enchanting"],   # Enchanting
    755: TRADE_FAMILY["gem"],          # Jewelcrafting
}

ITEM_ROW_RE = re.compile(r"^\s*\[(\d+)\]\s*=\s*(\d+),\s*$", re.MULTILINE)

HERB_NAMES = {
    "silverleaf", "mageroyal", "peacebloom", "earthroot", "briarthorn",
    "swiftthistle", "bruiseweed", "wild steelbloom", "kingsblood", "liferoot",
    "khadgar's whisker", "grave moss", "fadeleaf", "wintersbite",
    "stranglekelp", "goldthorn", "firebloom", "wildvine", "purple lotus",
    "arthas' tears", "sungrass", "blindweed", "ghost mushroom", "gromsblood",
    "dreamfoil", "golden sansam", "mountain silversage", "plaguebloom",
    "icecap", "black lotus",
}


def parse_args() -> argparse.Namespace:
    repo = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("sqlite", type=Path, help="Tortoise DB Viewer SQLite file")
    parser.add_argument(
        "--output",
        type=Path,
        default=repo / "Database" / "item_sort.lua",
        help="generated Lua file",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="verify that the output is current without writing it",
    )
    return parser.parse_args()


def read_existing(path: Path) -> dict[int, int]:
    if not path.exists():
        return {}
    return {int(item): int(code) for item, code in ITEM_ROW_RE.findall(path.read_text(encoding="utf-8"))}


def connect_read_only(path: Path) -> sqlite3.Connection:
    if not path.is_file():
        raise SystemExit(f"SQLite file not found: {path}")
    connection = sqlite3.connect(f"file:{path.resolve().as_posix()}?mode=ro", uri=True)
    connection.row_factory = sqlite3.Row
    columns = {row[1] for row in connection.execute("PRAGMA table_info(items)")}
    required = {
        "entry", "class", "subclass", "name", "quality", "inventory_type",
        "item_level", "bonding", "start_quest", "food_type", "custom",
    }
    missing = sorted(required - columns)
    if missing:
        raise SystemExit("items table is missing columns: " + ", ".join(missing))
    return connection


def load_item_graph(connection: sqlite3.Connection) -> tuple[set[int], dict[int, set[int]], dict[int, set[int]]]:
    recipe_items = {
        int(row[0])
        for row in connection.execute(
            "SELECT DISTINCT recipe_item FROM craft_source WHERE recipe_item > 0"
        )
    }
    created_skills: dict[int, set[int]] = defaultdict(set)
    for item, skill in connection.execute(
        "SELECT item, skill FROM spell_creates WHERE item > 0 AND skill > 0"
    ):
        created_skills[int(item)].add(int(skill))

    reagent_skills: dict[int, set[int]] = defaultdict(set)
    for item, skill in connection.execute(
        """
        SELECT DISTINCT sr.item, sc.skill
        FROM spell_reagent sr
        JOIN spell_creates sc ON sc.spell = sr.spell
        WHERE sr.item > 0 AND sc.skill > 0
        """
    ):
        reagent_skills[int(item)].add(int(skill))
    return recipe_items, created_skills, reagent_skills


def load_spell_effects(connection: sqlite3.Connection) -> dict[int, list[dict[str, object]]]:
    effects: dict[int, list[dict[str, object]]] = {}
    for spell, payload in connection.execute("SELECT entry, effects FROM spells"):
        try:
            decoded = json.loads(payload or "[]")
        except (TypeError, json.JSONDecodeError):
            decoded = []
        effects[int(spell)] = decoded if isinstance(decoded, list) else []
    return effects


def spell_ids(item: sqlite3.Row) -> list[int]:
    result = []
    for index in range(1, 6):
        value = int(item[f"spellid_{index}"] or 0)
        if value > 0:
            result.append(value)
    return result


def build_spell_category_seed(items: list[sqlite3.Row], existing: dict[int, int]) -> dict[int, int]:
    candidates: dict[int, set[int]] = defaultdict(set)
    for item in items:
        entry = int(item["entry"])
        if int(item["custom"] or 0) or entry not in existing:
            continue
        category = existing[entry] // CATEGORY_SPAN
        if category not in {3, 4, 5, 6, 7}:
            continue
        for spell in spell_ids(item):
            candidates[spell].add(category)
    return {spell: next(iter(values)) for spell, values in candidates.items() if len(values) == 1}


def contains_word(name: str, words: tuple[str, ...]) -> bool:
    return any(re.search(r"(?:^|[^a-z])" + re.escape(word) + r"(?:$|[^a-z])", name) for word in words)


def consumable_category(
    item: sqlite3.Row,
    effects: dict[int, list[dict[str, object]]],
    spell_seed: dict[int, int],
    created_skills: dict[int, set[int]],
) -> int:
    name = str(item["name"] or "").lower()
    ids = spell_ids(item)

    # Explicit item identities beat reused spell effects. Turtle potions and
    # salves sometimes reuse a periodic aura also used by food or bandages.
    if "bandage" in name:
        return 7
    if contains_word(
        name,
        ("potion", "salve", "remedy", "tonic", "serum", "antidote", "draught"),
    ):
        return 5
    if contains_word(
        name,
        (
            "elixir", "flask", "scroll", "armor kit", "armour kit", "oil",
            "poison", "sharpening stone", "weightstone", "juju", "concoction",
        ),
    ):
        return 6
    if contains_word(
        name,
        (
            "food", "drink", "bread", "cookie", "cake", "pie", "stew",
            "soup", "cheese", "water", "juice", "milk", "ale", "beer",
            "wine", "grog", "rum", "tea", "coffee", "ration", "rations",
            "fruit", "berries", "grapes", "yam", "carrot", "skewer",
            "delight", "pizza", "donut", "muffin", "chowder", "gumbo",
            "burger", "pudding",
        ),
    ):
        return 4

    seeded = {spell_seed[spell] for spell in ids if spell in spell_seed}
    if len(seeded) == 1:
        return next(iter(seeded))

    aura_ids = {
        int(effect.get("aura") or 0)
        for spell in ids
        for effect in effects.get(spell, [])
        if isinstance(effect, dict)
    }
    if 8 in aura_ids:
        return 7
    if int(item["food_type"] or 0) > 0 or aura_ids.intersection({23, 84, 85}):
        return 4
    if 185 in created_skills.get(int(item["entry"]), set()):
        return 4
    return 3


def family_from_name(name: str) -> int | None:
    if name in HERB_NAMES:
        return TRADE_FAMILY["herb"]
    if contains_word(name, ("alchemists' stone", "philosopher's stone")):
        return TRADE_FAMILY["alchemy"]
    if contains_word(
        name,
        ("belt buckle", "spurs", "paper", "wood", "leaves", "sticks", "rope", "string", "net"),
    ):
        return TRADE_FAMILY["general"]
    if contains_word(name, ("leather", "hide", "pelt", "scale", "shell")):
        return TRADE_FAMILY["leather"]
    if contains_word(name, ("cloth", "thread", "silk", "weave", "dye")):
        return TRADE_FAMILY["cloth"]
    if contains_word(name, ("herb", "bloom", "lotus", "moss", "mushroom")):
        return TRADE_FAMILY["herb"]
    if contains_word(
        name,
        ("ore", "bar", "ingot", "coal", "grinding stone", "sharpening stone", "weightstone"),
    ):
        return TRADE_FAMILY["ore"]
    if contains_word(
        name,
        (
            "gem", "gemstone", "ruby", "sapphire", "emerald", "diamond",
            "opal", "topaz", "quartz", "pearl", "citrine", "aquamarine",
            "malachite", "tigerseye", "jade", "moonstone", "crystal",
        ),
    ):
        return TRADE_FAMILY["gem"]
    if contains_word(name, ("dust", "shard", "essence", "enchanting")):
        return TRADE_FAMILY["enchanting"]
    if contains_word(
        name,
        (
            "blasting powder", "bolts", "tube", "gizmo", "casing", "framework",
            "wiring", "modulator", "trigger", "scope", "lens", "battery", "gyro",
        ),
    ):
        return TRADE_FAMILY["engineering"]
    if contains_word(
        name,
        ("meat", "flesh", "rib", "wing", "egg", "clam", "spice", "flour", "chocolate", "sugar"),
    ):
        return TRADE_FAMILY["meat"]
    return None


def trade_family(
    item: sqlite3.Row,
    created_skills: dict[int, set[int]],
    reagent_skills: dict[int, set[int]],
) -> int:
    subclass = int(item["subclass"] or 0)
    if subclass in {1, 3}:
        return TRADE_FAMILY["engineering"]
    if subclass == 7:
        return TRADE_FAMILY["gem"]

    name_family = family_from_name(str(item["name"] or "").lower())
    if name_family:
        return name_family

    entry = int(item["entry"])
    skills = created_skills.get(entry, set()) | reagent_skills.get(entry, set())
    families = {
        SKILL_FAMILY[skill]
        for skill in skills
        if skill in SKILL_FAMILY
    }
    # Turtle's Survival skill (142) shares some wood/paper components with
    # professions. Do not let the known half of a mixed use mislabel them.
    if len(families) == 1 and all(skill in SKILL_FAMILY for skill in skills):
        return next(iter(families))
    return TRADE_FAMILY["general"]


def classify(
    item: sqlite3.Row,
    recipe_items: set[int],
    created_skills: dict[int, set[int]],
    reagent_skills: dict[int, set[int]],
    effects: dict[int, list[dict[str, object]]],
    spell_seed: dict[int, int],
) -> tuple[int, int]:
    entry = int(item["entry"])
    item_class = int(item["class"] or 0)
    subclass = int(item["subclass"] or 0)
    bonding = int(item["bonding"] or 0)
    starts_quest = int(item["start_quest"] or 0)
    name = str(item["name"] or "").lower()

    if item_class == 12 or bonding == 4 or starts_quest > 0:
        return 2, 0
    recipe_prefixes = (
        "recipe:", "pattern:", "plans:", "schematic:", "formula:",
        "design:", "outline:",
    )
    if item_class == 9 or entry in recipe_items or name.startswith(recipe_prefixes):
        return 11, 0
    if item_class in {1, 11}:
        return 13, 0
    if item_class in {2, 4}:
        return 1, 0
    if item_class == 6:
        return 12, 0
    if item_class == 5:
        return 9, 0
    if item_class == 13:
        return 14, 0
    if item_class == 7:
        if subclass == 2:
            return 8, 0
        return 10, trade_family(item, created_skills, reagent_skills)
    if item_class == 0:
        return consumable_category(item, effects, spell_seed, created_skills), 0
    if item_class == 15 and int(item["quality"] or 0) == 0:
        return 15, 0
    return 16, 0


def pack(category: int, family: int, item: sqlite3.Row) -> int:
    item_class = int(item["class"] or 0)
    subclass = int(item["subclass"] or 0)
    inventory_type = int(item["inventory_type"] or 0)
    tier = max(0, min(1_023, int(item["item_level"] or 0)))

    if category == 10:
        primary = family
        secondary = subclass
    elif category == 1:
        primary = min(255, item_class * 32 + subclass)
        secondary = min(255, inventory_type)
    elif category == 13:
        primary = min(255, item_class * 16 + subclass)
        secondary = min(255, inventory_type)
    else:
        primary = min(255, subclass)
        secondary = min(255, item_class)
    detail = primary * FAMILY_SPAN + secondary * SUBGROUP_SPAN + tier
    if detail >= CATEGORY_SPAN:
        raise ValueError(f"packed detail overflow for item {item['entry']}")
    return category * CATEGORY_SPAN + detail


def render(rows: dict[int, int], source_hash: str, custom_count: int) -> str:
    lines = [
        "-- Generated by tools/generate_item_sort.py from Tortoise DB Viewer SQLite.",
        f"-- Source SHA-256: {source_hash}",
        f"-- Positive templates: {len(rows)}; Turtle custom templates: {custom_count}.",
        "PandaUIItemSortDB = {",
        "  version = 2,",
        "",
        "  items = {",
    ]
    lines.extend(f"    [{entry}] = {rows[entry]}," for entry in sorted(rows))
    lines.extend(["  },", "}", ""])
    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    connection = connect_read_only(args.sqlite)
    existing = read_existing(args.output)
    items = list(connection.execute("SELECT * FROM items WHERE entry > 0 ORDER BY entry"))
    recipe_items, created_skills, reagent_skills = load_item_graph(connection)
    effects = load_spell_effects(connection)
    spell_seed = build_spell_category_seed(items, existing)

    generated: dict[int, int] = {}
    categories: Counter[int] = Counter()
    custom_count = 0
    preserved = 0
    for item in items:
        entry = int(item["entry"])
        custom = bool(item["custom"])
        if not custom and entry in existing:
            generated[entry] = existing[entry]
            preserved += 1
            continue

        category, family = classify(
            item,
            recipe_items,
            created_skills,
            reagent_skills,
            effects,
            spell_seed,
        )
        generated[entry] = pack(category, family, item)
        categories[category] += 1
        if custom:
            custom_count += 1

    positive_custom = {
        int(row[0])
        for row in connection.execute("SELECT entry FROM items WHERE custom = 1 AND entry > 0")
    }
    missing = positive_custom - generated.keys()
    if missing:
        raise SystemExit(f"generator omitted {len(missing)} custom item templates")

    source_hash = hashlib.sha256(args.sqlite.read_bytes()).hexdigest()
    output = render(generated, source_hash, custom_count)
    current = args.output.read_text(encoding="utf-8") if args.output.exists() else ""
    if args.check:
        if current != output:
            print(f"stale: {args.output}", file=sys.stderr)
            return 1
    else:
        args.output.write_text(output, encoding="utf-8", newline="\n")

    summary = ", ".join(
        f"{CATEGORY_NAMES[category]}={count}" for category, count in sorted(categories.items())
    )
    print(
        f"items={len(generated)} custom={custom_count} preserved={preserved} "
        f"sha256={source_hash[:12]}"
    )
    print("classified: " + summary)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
