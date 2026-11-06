#!/usr/bin/env python3
"""Rebuild AshenDB item source data in a Vanilla-friendly compact form.

Usage:
  python rebuild_compact_sources.py path/to/tortoise.sqlite path/to/AshenBuilds

Only equippable items are exported. Every crafted, quest, and vendor source is
kept. Creature drops are deduplicated and limited to the eight most useful
named sources per item; a compact summary row records additional sources.
"""
from __future__ import annotations

import shutil
import sqlite3
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any

EQUIP_INVENTORY_TYPES = {
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14,
    15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 28,
}
PROFESSIONS = {
    129: "First Aid", 164: "Blacksmithing", 165: "Leatherworking",
    171: "Alchemy", 182: "Herbalism", 185: "Cooking", 186: "Mining",
    197: "Tailoring", 202: "Engineering", 333: "Enchanting",
    356: "Fishing", 393: "Skinning", 755: "Jewelcrafting",
}
MAX_DROP_SOURCES = 8
ITEMS_PER_SHARD = 400


def esc(value: Any) -> str:
    text = str(value or "")
    text = text.replace("\\", "\\\\").replace('"', '\\"')
    text = text.replace("\r", " ").replace("\n", " ")
    return f'"{text}"'


def number(value: Any) -> str:
    if value is None:
        return "0"
    if isinstance(value, int):
        return str(value)
    value = float(value)
    if value.is_integer():
        return str(int(value))
    return (f"{value:.6f}").rstrip("0").rstrip(".")


def lua(value: Any) -> str:
    if isinstance(value, str):
        return esc(value)
    if isinstance(value, bool):
        return "true" if value else "false"
    if value is None:
        return "nil"
    if isinstance(value, (int, float)):
        return number(value)
    if isinstance(value, (tuple, list)):
        return "{" + ",".join(lua(v) for v in value) + "}"
    raise TypeError(f"Unsupported value: {type(value)!r}")


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("Usage: rebuild_compact_sources.py tortoise.sqlite AshenBuilds-folder")

    db_path = Path(sys.argv[1]).resolve()
    addon_root = Path(sys.argv[2]).resolve()
    data_root = addon_root / "Data" / "AshenDB" / "Data"
    out_dir = data_root / "Sources"

    con = sqlite3.connect(db_path)
    con.row_factory = sqlite3.Row

    items = {row["entry"]: row for row in con.execute("SELECT * FROM items")}
    equip_ids = {
        item_id for item_id, row in items.items()
        if int(row["inventory_type"] or 0) in EQUIP_INVENTORY_TYPES
    }
    item_names = {item_id: str(row["name"] or f"Item {item_id}") for item_id, row in items.items()}

    zones = {row["areaid"]: str(row["name"] or "") for row in con.execute("SELECT areaid,name FROM zones")}
    for row in con.execute("SELECT entry,name FROM areas"):
        zones.setdefault(row["entry"], str(row["name"] or ""))

    creatures = {row["entry"]: row for row in con.execute("SELECT * FROM creatures")}
    spells = {row["entry"]: row for row in con.execute("SELECT entry,name FROM spells")}

    sources: dict[int, list[tuple[Any, ...]]] = defaultdict(list)

    # Crafting sources. Keep every recipe relationship.
    for row in con.execute("SELECT spell,item,skill,skill_min,skill_req FROM spell_creates"):
        item_id = row["item"]
        if item_id not in equip_ids:
            continue
        spell_id = int(row["spell"] or 0)
        spell = spells.get(spell_id)
        recipe_name = str((spell and spell["name"]) or item_names.get(item_id, f"Item {item_id}"))
        reagents = []
        for reagent in con.execute(
            "SELECT item,count FROM spell_reagent WHERE spell=? ORDER BY count DESC,item",
            (spell_id,),
        ):
            reagent_id = int(reagent["item"] or 0)
            if reagent_id <= 0:
                continue
            reagents.append((reagent_id, item_names.get(reagent_id, f"Item {reagent_id}"), int(reagent["count"] or 1)))
        skill_id = int(row["skill"] or 0)
        sources[item_id].append((
            "craft", spell_id, recipe_name,
            PROFESSIONS.get(skill_id, f"Skill {skill_id}" if skill_id else "Profession"),
            int(row["skill_min"] or 0), int(row["skill_req"] or 0), 0, reagents,
        ))

    # Quest rewards. Keep every reward/choice relationship.
    for row in con.execute(
        """
        SELECT qi.quest,qi.item,qi.role,qi.count,q.title,q.zone,q.level
        FROM quest_item qi
        JOIN quests q ON q.entry=qi.quest
        WHERE qi.role IN ('reward','choice') AND qi.item IS NOT NULL
        """
    ):
        item_id = row["item"]
        if item_id not in equip_ids:
            continue
        sources[item_id].append((
            "quest", int(row["quest"] or 0), str(row["title"] or f"Quest {row['quest']}"),
            zones.get(row["zone"], ""), str(row["role"] or "reward"),
            int(row["count"] or 1), int(row["level"] or 0),
        ))

    # Vendors. Keep every named vendor relationship, deduplicated.
    vendor_seen: set[tuple[int, int]] = set()
    for row in con.execute(
        """
        SELECT nv.entry,nv.item,nv.maxcount,c.name,c.zone,c.hidden
        FROM npc_vendor nv
        LEFT JOIN creatures c ON c.entry=nv.entry
        WHERE nv.item IS NOT NULL
        """
    ):
        item_id = row["item"]
        if item_id not in equip_ids or int(row["hidden"] or 0) != 0:
            continue
        key = (item_id, int(row["entry"] or 0))
        if key in vendor_seen:
            continue
        vendor_seen.add(key)
        sources[item_id].append((
            "vendor", key[1], str(row["name"] or f"Vendor {key[1]}"),
            zones.get(row["zone"], ""), int(row["maxcount"] or 0),
        ))

    # Creature drops are the source of nearly all prior memory bloat. Deduplicate
    # by creature, discard hidden/zero-chance records, then keep the most useful
    # direct sources. Bosses are preferred, followed by chance.
    drops_by_item: dict[int, dict[int, sqlite3.Row]] = defaultdict(dict)
    for row in con.execute(
        """
        SELECT d.owner,d.item,d.chance,d.mincount,d.maxcount,
               c.name,c.zone,c.rank,c.hidden
        FROM drops d
        LEFT JOIN creatures c ON c.entry=d.owner
        WHERE d.src='c' AND d.item IS NOT NULL AND d.chance > 0
        """
    ):
        item_id = row["item"]
        owner = int(row["owner"] or 0)
        if item_id not in equip_ids or owner <= 0 or int(row["hidden"] or 0) != 0:
            continue
        current = drops_by_item[item_id].get(owner)
        if current is None or float(row["chance"] or 0) > float(current["chance"] or 0):
            drops_by_item[item_id][owner] = row

    truncated_items = 0
    exported_drop_records = 0
    for item_id, owner_rows in drops_by_item.items():
        rows = list(owner_rows.values())
        rows.sort(key=lambda row: (
            -int(row["rank"] or 0),
            -float(row["chance"] or 0),
            str(row["name"] or ""),
        ))
        kept = rows[:MAX_DROP_SOURCES]
        for row in kept:
            owner = int(row["owner"] or 0)
            sources[item_id].append((
                "drop", owner, str(row["name"] or f"Creature {owner}"),
                zones.get(row["zone"], ""), float(row["chance"] or 0),
                int(row["mincount"] or 1), int(row["maxcount"] or 1),
            ))
            exported_drop_records += 1
        omitted = len(rows) - len(kept)
        if omitted > 0:
            truncated_items += 1
            sources[item_id].append(("more", omitted, "additional creature drop sources"))

    # Stable display priority: crafted, quest, vendor, then direct drops.
    priority = {"craft": 1, "quest": 2, "vendor": 3, "drop": 4, "more": 5}
    for item_id in list(sources):
        sources[item_id].sort(key=lambda row: (
            priority.get(str(row[0]), 99),
            -(float(row[4]) if row[0] == "drop" and len(row) > 4 else 0),
            str(row[2]) if len(row) > 2 else "",
        ))

    if out_dir.exists():
        shutil.rmtree(out_dir)
    out_dir.mkdir(parents=True)

    ids = sorted(sources)
    toc_paths: list[str] = []
    for shard_no, start in enumerate(range(0, len(ids), ITEMS_PER_SHARD), 1):
        filename = f"Sources_{shard_no:03d}.lua"
        toc_paths.append(f"Data\\AshenDB\\Data\\Sources\\{filename}")
        with (out_dir / filename).open("w", encoding="utf-8", newline="\n") as handle:
            handle.write("local T = AshenDB.ItemSources\n")
            for item_id in ids[start:start + ITEMS_PER_SHARD]:
                handle.write(f"T[{item_id}]={lua(sources[item_id])}\n")

    # Rebuild the TOC data order. Set definitions are intentionally loaded
    # before the much larger optional details/source payloads.
    toc = addon_root / "AshenBuilds.toc"
    lines = toc.read_text(encoding="utf-8").splitlines()
    base_lines = [
        line for line in lines
        if "Data\\AshenDB\\Data\\Sources\\" not in line
        and "Data\\AshenDB\\Data\\Sets\\" not in line
    ]
    set_paths = [
        f"Data\\AshenDB\\Data\\Sets\\{path.name}"
        for path in sorted((data_root / "Sets").glob("Sets_*.lua"))
    ]
    rebuilt: list[str] = []
    inserted_sets = False
    inserted_sources = False
    for line in base_lines:
        rebuilt.append(line)
        if line == "Data\\AshenDB\\Data\\Manifest.lua" and not inserted_sets:
            rebuilt.extend(set_paths)
            inserted_sets = True
        if line.endswith("Details\\Details_021.lua") and not inserted_sources:
            rebuilt.extend(toc_paths)
            inserted_sources = True
    if not inserted_sources:
        adapter_index = rebuilt.index("Data\\AshenDBAdapter.lua")
        rebuilt[adapter_index:adapter_index] = toc_paths
    toc.write_text("\n".join(rebuilt) + "\n", encoding="utf-8", newline="\n")

    print(f"Equippable items: {len(equip_ids)}")
    print(f"Items with direct sources: {len(sources)}")
    print(f"Creature drop rows kept: {exported_drop_records}")
    print(f"Items summarized after {MAX_DROP_SOURCES} drops: {truncated_items}")
    print(f"Source shards: {len(toc_paths)}")


if __name__ == "__main__":
    main()
