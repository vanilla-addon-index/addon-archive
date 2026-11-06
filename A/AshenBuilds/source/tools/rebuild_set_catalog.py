#!/usr/bin/env python3
"""Rebuild Ashen Builds item-set data from a Tortoise DB SQLite file.

The query shape and tooltip text resolution mirror the current
Xian55/tortoise-db-viewer item-set implementation:
  - visible members ordered by required level, then name
  - representative class mask = smallest positive member class mask
  - bonuses from item_set_bonus joined to spells
  - WoW DBC spell-variable text resolution
"""
from __future__ import annotations

import argparse
import json
import re
import sqlite3
from pathlib import Path
from typing import Any


def lua_string(value: Any) -> str:
    text = str(value or "")
    text = text.replace("\\", "\\\\").replace('"', '\\"')
    text = text.replace("\r", " ").replace("\n", " ")
    return '"' + text + '"'


def num_text(value: Any) -> str:
    if value is None:
        return "0"
    number = float(value)
    if number.is_integer():
        return str(int(number))
    return ("%.4f" % number).rstrip("0").rstrip(".")


def val_str(base: Any, die: Any) -> str:
    base_i = int(base or 0)
    die_i = int(die or 0)
    if die_i > 1:
        return f"{base_i} to {base_i + die_i - 1}"
    return str(base_i)


def resolve_spell_text(row: sqlite3.Row | None) -> str:
    if row is None:
        return ""
    text = str(row["description"] or row["auraDescription"] or row["name"] or "").strip()
    if not text:
        return ""

    try:
        effects = json.loads(row["effects"] or "[]")
    except (TypeError, ValueError, json.JSONDecodeError):
        effects = []
    effect_by_index = {int(e.get("i", 0)): e for e in effects if isinstance(e, dict)}
    duration_ms = int(row["duration_ms"] or 0)

    def own_value(n: int) -> int:
        return int(row[f"s{n}"] or 0)

    def own_die(n: int) -> int:
        return int(row[f"d{n}"] or 0)

    def scaled_div(match: re.Match[str]) -> str:
        divisor = int(match.group(1)) or 1
        n = int(match.group(2))
        return str(round(own_value(n) / divisor))

    def scaled_mul(match: re.Match[str]) -> str:
        multiplier = int(match.group(1))
        n = int(match.group(2))
        return str(round(own_value(n) * multiplier))

    def overtime(match: re.Match[str]) -> str:
        n = int(match.group(1))
        eff = effect_by_index.get(n) or {}
        period = int(eff.get("period") or 0)
        ticks = round(duration_ms / period) if period and duration_ms else 1
        return str(own_value(n) * (ticks or 1))

    def own(match: re.Match[str]) -> str:
        n = int(match.group(1))
        return val_str(own_value(n), own_die(n))

    def tick(match: re.Match[str]) -> str:
        eff = effect_by_index.get(int(match.group(1))) or {}
        period = int(eff.get("period") or 0)
        return num_text(period / 1000) if period else ""

    def radius(match: re.Match[str]) -> str:
        eff = effect_by_index.get(int(match.group(1))) or {}
        radius_value = eff.get("radius")
        return num_text(radius_value) if radius_value is not None else ""

    duration = ""
    if duration_ms:
        seconds = duration_ms / 1000
        duration = f"{num_text(seconds)} sec"

    # This follows src/render.js in the upstream viewer. $h/$h1 proc tokens are
    # intentionally stripped as a complete token, including a trailing %, which
    # yields the website wording (for example, "Gives you a chance...").
    text = re.sub(r"\$/([0-9]+);s([123])", scaled_div, text, flags=re.I)
    text = re.sub(r"\$\*([0-9]+);s([123])", scaled_mul, text, flags=re.I)
    text = re.sub(r"\$o([123])", overtime, text, flags=re.I)
    text = re.sub(r"\$[smM]([123])", own, text)
    text = re.sub(r"\$t([123])", tick, text, flags=re.I)
    text = re.sub(r"\$a([123])", radius, text, flags=re.I)
    text = re.sub(r"\$d(?![A-Za-z0-9])", duration, text, flags=re.I)
    text = re.sub(r"\$h[123]?%?", "", text, flags=re.I)
    text = re.sub(r"\$\{[^}]*\}", "", text)
    text = re.sub(r"\$[gl][^;]*;", "", text, flags=re.I)
    text = re.sub(r"\$[*/]?[0-9]*;?[0-9]*[A-Za-z]*[0-9]*%?", "", text, flags=re.I)
    text = re.sub(r"\s+([.,;:])", r"\1", text)
    text = re.sub(r"\s{2,}", " ", text).strip()
    if text and text[0].islower():
        text = text[0].upper() + text[1:]
    return text


def build_catalog(db_path: Path, out_path: Path, data_version: str) -> tuple[int, int, int]:
    con = sqlite3.connect(str(db_path))
    con.row_factory = sqlite3.Row

    set_rows = list(con.execute("SELECT id, name FROM item_sets WHERE name <> '' ORDER BY id"))
    member_rows = list(
        con.execute(
            """
            SELECT i.set_id, i.entry, i.name, i.quality, i.allowable_class AS ac,
                   i.required_level
            FROM items i
            WHERE i.set_id <> 0 AND COALESCE(i.hidden,0) = 0
            ORDER BY i.set_id, i.required_level, i.name, i.entry
            """
        )
    )
    bonus_rows = list(
        con.execute(
            """
            SELECT b.setid, b.threshold, b.spell, s.*
            FROM item_set_bonus b
            LEFT JOIN spells s ON s.entry = b.spell
            ORDER BY b.setid, b.threshold, b.spell
            """
        )
    )

    members_by_set: dict[int, list[sqlite3.Row]] = {}
    item_to_set: dict[int, int] = {}
    for row in member_rows:
        set_id = int(row["set_id"])
        members_by_set.setdefault(set_id, []).append(row)
        item_to_set[int(row["entry"])] = set_id

    bonuses_by_set: dict[int, list[tuple[int, int, str]]] = {}
    for row in bonus_rows:
        set_id = int(row["setid"])
        text = resolve_spell_text(row)
        if not text:
            text = str(row["name"] or f"Spell {row['spell']}")
        bonuses_by_set.setdefault(set_id, []).append(
            (int(row["threshold"] or 0), int(row["spell"] or 0), text)
        )

    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8", newline="\n") as out:
        out.write("-- Ashen Builds item-set catalog. Generated from Tortoise DB SQLite.\n")
        out.write("-- Tooltip layout and spell-token resolution follow the current upstream viewer.\n")
        out.write("AshenBuilds = AshenBuilds or {}\n")
        out.write("AshenBuilds.SetCatalog = {}\n")
        out.write("AshenBuilds.ItemToSet = {}\n")
        out.write("local C = AshenBuilds.SetCatalog\n")
        out.write("local M = AshenBuilds.ItemToSet\n")
        out.write(
            'AshenBuilds.SetCatalogMeta={dataVersion=%s,schemaRef=%s,setCount=%d,memberCount=%d,bonusCount=%d}\n'
            % (
                lua_string(data_version),
                lua_string("Xian55/tortoise-db-viewer main (2026-07-16)"),
                len(set_rows),
                len(member_rows),
                len(bonus_rows),
            )
        )

        for set_row in set_rows:
            set_id = int(set_row["id"])
            members = members_by_set.get(set_id, [])
            positive_masks = [int(m["ac"]) for m in members if int(m["ac"] or 0) > 0]
            class_mask = min(positive_masks) if positive_masks else 0
            member_lua = "{" + ",".join(
                "{%d,%s,%d,%d}" % (
                    int(m["entry"]),
                    lua_string(m["name"]),
                    int(m["quality"] or 1),
                    int(m["ac"] or -1),
                )
                for m in members
            ) + "}"
            bonus_lua = "{" + ",".join(
                "{%d,%d,%s}" % (threshold, spell_id, lua_string(text))
                for threshold, spell_id, text in bonuses_by_set.get(set_id, [])
            ) + "}"
            out.write(
                "C[%d]={name=%s,classMask=%d,items=%s,bonuses=%s}\n"
                % (set_id, lua_string(set_row["name"]), class_mask, member_lua, bonus_lua)
            )

        for item_id, set_id in sorted(item_to_set.items()):
            out.write(f"M[{item_id}]={set_id}\n")

        out.write("AshenDB = AshenDB or {}\n")
        out.write("AshenDB.ItemSets = C\n")
        out.write("AshenDB.ItemToSet = M\n")
        out.write("AshenDB.SetCatalogMeta = AshenBuilds.SetCatalogMeta\n")

    con.close()
    return len(set_rows), len(member_rows), len(bonus_rows)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("database", type=Path, help="Path to tortoise.sqlite")
    parser.add_argument("output", type=Path, nargs="?", default=Path("../Data/SetCatalog.lua"))
    parser.add_argument("--data-version", default="unknown")
    args = parser.parse_args()
    sets, members, bonuses = build_catalog(args.database, args.output, args.data_version)
    print(f"Exported {sets} sets, {members} visible members, and {bonuses} bonuses to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
