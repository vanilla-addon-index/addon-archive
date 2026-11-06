#!/usr/bin/env python3
"""Generate PandaUI's compact NPC cast lookup from the local Turtle database."""

from __future__ import annotations

import argparse
import sqlite3
from collections import Counter, defaultdict
from pathlib import Path


DEFAULT_DB = Path(r"C:\Users\User\AppData\Local\Temp\tortoise.sqlite.br")
DEFAULT_OUTPUT = Path(__file__).resolve().parents[1] / "Database" / "cast_spells.lua"
SOURCE_PRIORITY = {"l": 0, "e": 1, "c": 2, "t": 3}


def lua_string(value: str) -> str:
    escaped: list[str] = []
    for char in value:
        code = ord(char)
        if char == "\\":
            escaped.append("\\\\")
        elif char == '"':
            escaped.append('\\"')
        elif code < 32 or code == 127:
            escaped.append(f"\\{code:03d}")
        else:
            escaped.append(char)
    return '"' + "".join(escaped) + '"'


def row_value(row: sqlite3.Row) -> tuple[int, str, int]:
    channel = 1 if row["channeled"] else 0
    milliseconds = row["duration_ms"] if channel and row["duration_ms"] else row["cast_ms"]
    return int(milliseconds), row["icon"] or "", channel


def preferred(rows: list[sqlite3.Row]) -> sqlite3.Row:
    counts = Counter(row_value(row) for row in rows)
    return min(
        rows,
        key=lambda row: (
            -counts[row_value(row)],
            SOURCE_PRIORITY.get(row["src"], 9),
            -(row["prob"] or 0),
            row["ord"] if row["ord"] is not None else 99,
            -row["spell_id"],
        ),
    )


def render(db_path: Path) -> tuple[str, dict[str, int]]:
    with db_path.open("rb") as source:
        magic = source.read(16)
    if magic != b"SQLite format 3\x00":
        raise SystemExit(f"not an uncompressed SQLite database: {db_path}")

    connection = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    connection.row_factory = sqlite3.Row
    rows = connection.execute(
        """
        SELECT c.entry AS creature_id, c.name AS caster, c.custom,
               s.entry AS spell_id, s.name AS spell, s.cast_ms,
               s.duration_ms, s.channeled, COALESCE(s.icon, '') AS icon,
               a.src, a.prob, a.ord
          FROM creature_ability a
          JOIN creatures c ON c.entry = a.creature
          JOIN spells s ON s.entry = a.spell
         WHERE a.src <> 'a'
           AND s.name <> '' AND c.name <> ''
           AND (s.cast_ms > 0 OR (s.channeled <> 0 AND s.duration_ms > 0))
        """
    ).fetchall()
    connection.close()

    candidates: dict[tuple[str, str], list[sqlite3.Row]] = defaultdict(list)
    by_id: dict[int, sqlite3.Row] = {}
    vanilla_rows = 0
    custom_rows = 0
    for row in rows:
        candidates[(row["caster"], row["spell"])].append(row)
        by_id[row["spell_id"]] = row
        if row["custom"]:
            custom_rows += 1
        else:
            vanilla_rows += 1

    exact = {key: preferred(values) for key, values in candidates.items()}
    variants: dict[str, Counter[tuple[int, str, int]]] = defaultdict(Counter)
    for row in exact.values():
        variants[row["spell"]][row_value(row)] += 1

    generic: dict[str, tuple[int, str, int]] = {}
    for spell, counts in variants.items():
        generic[spell] = min(
            counts,
            key=lambda value: (-counts[value], value[0], value[1], value[2]),
        )

    overrides: dict[str, dict[str, tuple[int, str, int]]] = defaultdict(dict)
    for (caster, spell), row in exact.items():
        value = row_value(row)
        if value != generic[spell]:
            overrides[caster][spell] = value

    lines = [
        "PandaUI.castSpellData = {",
        f"  spellCount = {len(generic)},",
        f"  spellIdCount = {len(by_id)},",
        f"  casterOverrideCount = {sum(len(values) for values in overrides.values())},",
        f"  vanillaAbilityRows = {vanilla_rows},",
        f"  customAbilityRows = {custom_rows},",
        "  bySpell = {",
    ]
    for spell in sorted(generic, key=lambda value: (value.casefold(), value)):
        ms, icon, channel = generic[spell]
        lines.append(f"    [{lua_string(spell)}] = {{ {ms}, {lua_string(icon)}, {channel} }},")
    lines.extend(("  },", "  byCaster = {"))
    for caster in sorted(overrides, key=lambda value: (value.casefold(), value)):
        lines.append(f"    [{lua_string(caster)}] = {{")
        for spell in sorted(overrides[caster], key=lambda value: (value.casefold(), value)):
            ms, icon, channel = overrides[caster][spell]
            lines.append(f"      [{lua_string(spell)}] = {{ {ms}, {lua_string(icon)}, {channel} }},")
        lines.append("    },")
    lines.extend(("  },", "  byId = {"))
    for spell_id in sorted(by_id):
        row = by_id[spell_id]
        ms, icon, channel = row_value(row)
        lines.append(
            f"    [{spell_id}] = {{ {lua_string(row['spell'])}, {ms}, "
            f"{lua_string(icon)}, {channel} }},"
        )
    lines.extend(("  },", "}", ""))

    def resolved(caster: str, spell: str) -> tuple[int, str, int] | None:
        return overrides.get(caster, {}).get(spell) or generic.get(spell)

    pillager = by_id.get(20793)
    if (
        not pillager
        or row_value(pillager)[:2] != (3000, "spell_fire_flamebolt")
        or resolved("Defias Pillager", "Fireball")[:2]
        != (3000, "spell_fire_flamebolt")
    ):
        raise SystemExit("verification failed: Defias Pillager Fireball 20793 is not 3000 ms")
    custom_checks = (
        ("Twilight-Watcher Crendus", "Fireball", 1000, "spell_fire_flamebolt"),
        ("Lady Janira", "Frostbolt", 3000, "spell_frost_frostbolt02"),
        ("Totem of Corruption", "Shadow Nova", 3000, "spell_shadow_shadetruesight"),
    )
    for caster, spell, milliseconds, icon in custom_checks:
        value = resolved(caster, spell)
        if not value or value[:2] != (milliseconds, icon):
            raise SystemExit(f"verification failed: custom cast {caster} / {spell}")
    if custom_rows == 0 or vanilla_rows == 0:
        raise SystemExit("verification failed: Vanilla or Turtle-custom abilities are missing")

    stats = {
        "spells": len(generic),
        "spell_ids": len(by_id),
        "overrides": sum(len(values) for values in overrides.values()),
        "vanilla_rows": vanilla_rows,
        "custom_rows": custom_rows,
    }
    return "\n".join(lines), stats


def generate(db_path: Path, output_path: Path, check: bool) -> None:
    content, stats = render(db_path)
    encoded = content.encode("utf-8")
    if check:
        if not output_path.exists() or output_path.read_bytes() != encoded:
            raise SystemExit(f"generated cast database is stale: {output_path}")
        action = "verified"
    else:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_bytes(encoded)
        action = "wrote"
    print(
        f"{action} {output_path}: {stats['spells']} spell names, "
        f"{stats['spell_ids']} spell ids, {stats['overrides']} caster overrides, "
        f"{stats['vanilla_rows']} Vanilla rows, {stats['custom_rows']} custom rows"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    generate(args.db, args.output, args.check)


if __name__ == "__main__":
    main()
