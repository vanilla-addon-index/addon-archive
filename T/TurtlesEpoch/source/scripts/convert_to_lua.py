#!/usr/bin/env python3
"""
Convert npc_database.json → data/npc_data.lua for the TurtleTongue addon.

Reads NPC entries, normalizes race via analyze_quest_races.RACE_NORMALIZATION,
and writes a Lua table keyed by NPC name with race + sex fields.

Duplicate NPC names: keeps the entry with the most info (known race > unknown,
known sex > unknown).

Usage:
    python scripts/convert_to_lua.py
    python scripts/convert_to_lua.py --dry-run   # preview without writing
    python scripts/convert_to_lua.py --stats      # print race/sex distribution
"""

import json
import argparse
from pathlib import Path
from collections import Counter

# Import normalization from the analysis script
from analyze_quest_races import normalize_race, BASE_RACES

DATA_DIR = Path(__file__).parent.parent / "data"
NPC_DB_PATH = DATA_DIR / "npc_database.json"
OUTPUT_PATH = DATA_DIR / "npc_data.lua"

# Tier 3 named NPCs get special voice profiles (not their race voice)
TIER3_NPCS = {
    "Thrall", "Archmage Ansirem Runeweaver", "Tirion Fordring",
    "Varimathras", "Chromie", "Nathanos Blightcaller",
    "Highlord Bolvar Fordragon", "Cairne Bloodhoof",
    "King Magni Bronzebeard", "Gazlowe", "Vereesa Windrunner",
    "Tyrande Whisperwind", "Lady Sylvanas Windrunner",
    "Vol'jin", "Rexxar", "Lady Jaina Proudmoore",
}


def escape_lua_string(s):
    """Escape a string for use inside Lua double-brackets or quotes."""
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def choose_best_entry(existing, new, existing_norm_race, new_norm_race):
    """Pick the better NPC entry when names collide.
    
    Prefers: known race over unknown, known sex over unknown.
    """
    # Score: +2 for known race, +1 for known sex
    def score(entry, norm_race):
        s = 0
        if norm_race is not None:
            s += 2
        if entry.get("sex", "unknown") != "unknown":
            s += 1
        return s

    if score(new, new_norm_race) > score(existing, existing_norm_race):
        return new, new_norm_race
    return existing, existing_norm_race


def main():
    parser = argparse.ArgumentParser(description="Convert npc_database.json → npc_data.lua")
    parser.add_argument("--dry-run", action="store_true", help="Preview without writing")
    parser.add_argument("--stats", action="store_true", help="Print distribution stats")
    args = parser.parse_args()

    with open(NPC_DB_PATH) as f:
        db = json.load(f)

    entries = db["entries"]
    print(f"Loaded {len(entries)} NPCs from npc_database.json")

    # Build name → (entry, normalized_race) map, resolving duplicates
    npc_map = {}  # name → (entry_dict, normalized_race_string)
    dup_count = 0

    for entry_id, entry in entries.items():
        name = entry.get("name", "").strip()
        if not name:
            continue

        raw_race = entry.get("race", "")
        norm_race = normalize_race(raw_race) if raw_race else None

        if name in npc_map:
            dup_count += 1
            existing_entry, existing_race = npc_map[name]
            npc_map[name] = choose_best_entry(
                existing_entry, entry, existing_race, norm_race
            )
        else:
            npc_map[name] = (entry, norm_race)

    print(f"Unique NPC names: {len(npc_map)} ({dup_count} duplicates resolved)")

    # Stats
    race_counter = Counter()
    sex_counter = Counter()
    for name, (entry, norm_race) in npc_map.items():
        race_label = norm_race if norm_race else "Narrator"
        race_counter[race_label] += 1
        sex_counter[entry.get("sex", "unknown")] += 1

    if args.stats:
        print("\nRace distribution (normalized):")
        for race, count in race_counter.most_common():
            print(f"  {race}: {count}")
        print(f"\nSex distribution:")
        for sex, count in sex_counter.most_common():
            print(f"  {sex}: {count}")

    # Generate Lua
    lines = []
    lines.append("-- Auto-generated NPC database for TurtleTongue")
    lines.append("-- Maps NPC name → race + sex for voice profile selection")
    lines.append(f"-- {len(npc_map)} unique NPCs from npc_database.json")
    lines.append("-- DO NOT EDIT MANUALLY — regenerate with: python scripts/convert_to_lua.py")
    lines.append("")
    lines.append("TT_NPC_DATA = {")

    # Sort by name for deterministic output
    for name in sorted(npc_map.keys()):
        entry, norm_race = npc_map[name]
        sex = entry.get("sex", "unknown")
        race_lua = norm_race if norm_race else "Narrator"
        escaped_name = escape_lua_string(name)
        lines.append(f'  ["{escaped_name}"] = {{ race = "{race_lua}", sex = "{sex}" }},')

    lines.append("}")
    lines.append("")

    lua_content = "\n".join(lines)

    if args.dry_run:
        # Show first 20 entries
        preview = "\n".join(lines[:26])
        print(f"\nPreview (first 20 entries):\n{preview}\n...")
        print(f"\nTotal lines: {len(lines)}")
        print(f"Total size: {len(lua_content) / 1024:.1f} KB")
    else:
        with open(OUTPUT_PATH, "w") as f:
            f.write(lua_content)
        print(f"Written to {OUTPUT_PATH}")
        print(f"  Size: {len(lua_content) / 1024:.1f} KB")

    # Summary
    print(f"\nSummary:")
    print(f"  Unique NPCs:     {len(npc_map)}")
    print(f"  Known race:      {sum(1 for _, (_, r) in npc_map.items() if r)} ({sum(1 for _, (_, r) in npc_map.items() if r) * 100 // len(npc_map)}%)")
    print(f"  Narrator fallback: {sum(1 for _, (_, r) in npc_map.items() if not r)}")
    print(f"  Male: {sex_counter.get('male', 0)}, Female: {sex_counter.get('female', 0)}, Unknown: {sex_counter.get('unknown', 0)}")


if __name__ == "__main__":
    main()
