#!/usr/bin/env python3
"""Validate pandaUI talent-advisor codes against Talented-turtle ClassData."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


CLASS_ORDER = (
    "WARRIOR", "DRUID", "HUNTER", "MAGE", "PALADIN",
    "PRIEST", "ROGUE", "SHAMAN", "WARLOCK",
)


def parse_class_data(path: Path):
    text = path.read_text(encoding="utf-8")
    start = text.index("  local spelldata = {")
    end = text.index("\n  }\n\n  _G.TalentedTooltipData", start)
    lines = text[start:end].splitlines()[1:]
    trees = []
    current_tree = None
    current_talent = None
    in_ranks = False

    for line in lines:
        if line == "    {":
            current_tree = []
            trees.append(current_tree)
        elif line == "      {":
            current_talent = {"ranks": 0}
            current_tree.append(current_talent)
        elif current_talent is not None:
            match = re.search(r'\["name"\] = "(.*)",$', line)
            if match:
                current_talent["name"] = match.group(1)
            match = re.search(r'\["row"\] = (\d+),$', line)
            if match:
                current_talent["row"] = int(match.group(1))
            match = re.search(r'\["req"\] = (\d+),$', line)
            if match:
                current_talent["req"] = int(match.group(1))
            if line == '        ["ranks"] = {':
                in_ranks = True
            elif in_ranks and re.match(r"^          \d+,$", line):
                current_talent["ranks"] += 1
            elif in_ranks and line == "        },":
                in_ranks = False
            elif not in_ranks and line == "      },":
                current_talent = None
    return trees


def parse_database(path: Path):
    text = path.read_text(encoding="utf-8")
    tree_counts = {}
    builds = {}
    in_builds = False
    current_class = None

    for line in text.splitlines():
        tree_match = re.match(r'^    ([A-Z]+) = \{ (.*) \},$', line)
        if tree_match and not in_builds:
            counts = [int(value) for value in re.findall(r'\{ "[^"]+", (\d+) \}', tree_match.group(2))]
            if counts:
                tree_counts[tree_match.group(1)] = counts
        if line == "  builds = {":
            in_builds = True
            continue
        if line == "  catalog = {":
            break
        if not in_builds:
            continue
        class_match = re.match(r"^    ([A-Z]+) = \{$", line)
        if class_match:
            current_class = class_match.group(1)
            builds[current_class] = {}
            continue
        build_match = re.match(
            r'^      ([A-Z0-9_]+) = \{ label = "[^"]+", split = "([0-9/]+)", primary = \d, codes = \{ (.*?) \}(?:, sequence = \{.*\})? \},$',
            line,
        )
        if build_match and current_class:
            codes = re.findall(r'"([0-9]*)"', build_match.group(3))
            builds[current_class][build_match.group(1)] = (build_match.group(2), codes)
    return tree_counts, builds


def validate(database: Path, class_data: Path):
    stored_counts, builds = parse_database(database)
    errors = []

    for class_name in CLASS_ORDER:
        trees = parse_class_data(class_data / (class_name + ".lua"))
        actual_counts = [len(tree) for tree in trees]
        if stored_counts.get(class_name) != actual_counts:
            errors.append(f"{class_name}: stored tree counts {stored_counts.get(class_name)} != {actual_counts}")

        for build_name, (split, codes) in builds.get(class_name, {}).items():
            if len(codes) != 3:
                errors.append(f"{class_name}/{build_name}: expected 3 tree codes, got {len(codes)}")
                continue
            totals = []
            for tree_index, (tree, code) in enumerate(zip(trees, codes), 1):
                if len(code) != len(tree):
                    errors.append(
                        f"{class_name}/{build_name}/tree{tree_index}: code length {len(code)} != {len(tree)}"
                    )
                    continue
                ranks = [int(value) for value in code]
                totals.append(sum(ranks))
                for talent_index, (talent, rank) in enumerate(zip(tree, ranks), 1):
                    if rank > talent["ranks"]:
                        errors.append(
                            f"{class_name}/{build_name}/tree{tree_index}/{talent_index} {talent['name']}: "
                            f"rank {rank} > {talent['ranks']}"
                        )
                    if rank:
                        earlier_points = sum(
                            other_rank
                            for other, other_rank in zip(tree, ranks)
                            if other["row"] < talent["row"]
                        )
                        required_points = (talent["row"] - 1) * 5
                        if earlier_points < required_points:
                            errors.append(
                                f"{class_name}/{build_name}/tree{tree_index}/{talent_index} {talent['name']}: "
                                f"needs {required_points} earlier-tier points, has {earlier_points}"
                            )
                        prerequisite = talent.get("req")
                        if prerequisite and ranks[prerequisite - 1] != tree[prerequisite - 1]["ranks"]:
                            errors.append(
                                f"{class_name}/{build_name}/tree{tree_index}/{talent_index} {talent['name']}: "
                                f"prerequisite {tree[prerequisite - 1]['name']} is not maxed"
                            )
            expected_split = "/".join(str(total) for total in totals)
            if split != expected_split:
                errors.append(f"{class_name}/{build_name}: split {split} != {expected_split}")
            if sum(totals) != 51:
                errors.append(f"{class_name}/{build_name}: total points {sum(totals)} != 51")
    return errors


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("class_data", type=Path, help="Talented-turtle ClassData directory")
    parser.add_argument("--dump", action="store_true", help="print parsed talent indexes and stop")
    parser.add_argument(
        "--database",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "Database" / "talent_advisor.lua",
    )
    args = parser.parse_args()
    if args.dump:
        for class_name in CLASS_ORDER:
            print(class_name)
            for tree_index, tree in enumerate(parse_class_data(args.class_data / (class_name + ".lua")), 1):
                print(f"  Tree {tree_index}")
                for talent_index, talent in enumerate(tree, 1):
                    requirement = f" req={talent['req']}" if talent.get("req") else ""
                    print(
                        f"    {talent_index:02d} r{talent['row']} max{talent['ranks']}"
                        f"{requirement}: {talent['name']}"
                    )
        return 0
    errors = validate(args.database, args.class_data)
    if errors:
        print("\n".join(errors))
        return 1
    print("Talent advisor catalog is valid for all 9 classes and 32 builds.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
