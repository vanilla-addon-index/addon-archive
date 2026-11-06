#!/usr/bin/env python3
"""
TurtleTongue Player Configuration

Interactive script to set character details used for personalizing
quest voice lines. Run this before voice generation.

Usage:
    python player_config.py              # Interactive setup
    python player_config.py --show       # Show current config
    python player_config.py --reset      # Reset to defaults

Output: data/player_config.json
"""

import argparse
import json
import os
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent
CONFIG_PATH = PROJECT_ROOT / "data" / "player_config.json"

# WoW 1.12 classes and races
ALLIANCE_RACES = ["Human", "Dwarf", "Night Elf", "Gnome", "High Elf"]
HORDE_RACES = ["Orc", "Troll", "Undead", "Tauren", "Goblin"]
ALL_RACES = ALLIANCE_RACES + HORDE_RACES

CLASSES = [
    "Warrior", "Paladin", "Hunter", "Rogue", "Priest",
    "Shaman", "Mage", "Warlock", "Druid",
]

GENDERS = ["male", "female"]

DEFAULTS = {
    "name": "adventurer",
    "class": "hero",
    "race": "traveler",
    "gender": "male",
}


def load_config():
    """Load existing config or return defaults."""
    if CONFIG_PATH.exists():
        with open(CONFIG_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    return dict(DEFAULTS)


def save_config(config):
    """Save config to JSON file."""
    with open(CONFIG_PATH, "w", encoding="utf-8") as f:
        json.dump(config, f, indent=2, ensure_ascii=False)
    print(f"\nSaved to: {CONFIG_PATH}")


def show_config(config):
    """Display current config."""
    print("\n  Current player configuration:")
    print(f"    Name:   {config.get('name', DEFAULTS['name'])}")
    print(f"    Class:  {config.get('class', DEFAULTS['class'])}")
    print(f"    Race:   {config.get('race', DEFAULTS['race'])}")
    print(f"    Gender: {config.get('gender', DEFAULTS['gender'])}")


def _pick(prompt, options, current=None):
    """Interactive picker with numbered options."""
    print(f"\n  {prompt}")
    for i, opt in enumerate(options, 1):
        marker = " ←" if opt == current else ""
        print(f"    {i}. {opt}{marker}")

    while True:
        try:
            raw = input("  Choice (number or type it): ").strip()
            if not raw:
                return current  # keep current
            # Try as number
            idx = int(raw)
            if 1 <= idx <= len(options):
                return options[idx - 1]
            print(f"  Pick 1-{len(options)}")
        except ValueError:
            # Accept typed value if it's in the list (case-insensitive)
            for opt in options:
                if opt.lower() == raw.lower():
                    return opt
            # Accept freeform for name
            if prompt.startswith("Character name"):
                return raw
            print(f"  Not recognized. Pick a number or type the exact name.")


def interactive_setup():
    """Run interactive character setup."""
    config = load_config()

    print("=" * 50)
    print("  TurtleTongue — Player Character Setup")
    print("=" * 50)
    print("\n  NPC dialogue will use these details when")
    print("  addressing your character by name, class, or race.")
    print("  Press Enter to keep current value.\n")

    show_config(config)

    # Name — freeform input
    print(f"\n  Character name (current: {config.get('name', DEFAULTS['name'])})")
    raw = input("  Name: ").strip()
    if raw:
        config["name"] = raw

    # Gender
    config["gender"] = _pick(
        "Gender:",
        GENDERS,
        config.get("gender", DEFAULTS["gender"]),
    )

    # Race
    print("\n  --- Alliance ---")
    for i, r in enumerate(ALLIANCE_RACES, 1):
        print(f"    {i}. {r}")
    print("  --- Horde ---")
    for i, r in enumerate(HORDE_RACES, len(ALLIANCE_RACES) + 1):
        print(f"    {i}. {r}")
    current_race = config.get("race", DEFAULTS["race"])
    while True:
        raw = input(f"  Race (current: {current_race}): ").strip()
        if not raw:
            break
        try:
            idx = int(raw)
            if 1 <= idx <= len(ALL_RACES):
                config["race"] = ALL_RACES[idx - 1]
                break
            print(f"  Pick 1-{len(ALL_RACES)}")
        except ValueError:
            for r in ALL_RACES:
                if r.lower() == raw.lower():
                    config["race"] = r
                    break
            else:
                print("  Not recognized.")
                continue
            break

    # Class
    config["class"] = _pick(
        "Class:",
        CLASSES,
        config.get("class", DEFAULTS["class"]),
    )

    show_config(config)
    save_config(config)

    print("\n  Voice lines will now address your character as:")
    sample = f'  "Welcome, {config["name"]}! A brave {config["race"]} {config["class"]}."'
    print(f"  {sample}\n")


def main():
    parser = argparse.ArgumentParser(
        description="Configure player character details for TTS voice generation"
    )
    parser.add_argument("--show", action="store_true", help="Show current config")
    parser.add_argument("--reset", action="store_true", help="Reset to defaults")
    args = parser.parse_args()

    if args.reset:
        save_config(DEFAULTS)
        show_config(DEFAULTS)
        return

    if args.show:
        config = load_config()
        show_config(config)
        return

    interactive_setup()


if __name__ == "__main__":
    main()
