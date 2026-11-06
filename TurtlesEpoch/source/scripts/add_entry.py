#!/usr/bin/env python3
"""
TurtleTongue Manual Entry CLI

Add uncrawlable voice entries (gossip, quest greetings, item text) to
data/manual_entries.json for later voice generation.

Race/sex is auto-resolved from npc_database.json when not explicitly provided.

Usage:
    # Add a gossip line (auto race/sex from NPC database)
    python scripts/add_entry.py --type gossip --npc "Guard Thomas" \\
      --text "The Defias are causing trouble in the area."

    # Add a gossip line (explicit race/sex override)
    python scripts/add_entry.py --type gossip --npc "Guard Thomas" --race Human --sex male \\
      --text "The Defias are causing trouble in the area."

    # Add a quest greeting
    python scripts/add_entry.py --type quest_greeting --npc "Marshal McBride" \\
      --text "Ah, another newcomer to Northshire."

    # Add an inventory item text (always narrator voice)
    python scripts/add_entry.py --type item_text --name "Weathered Letter" \\
      --text "Dear adventurer, if you are reading this..."

    # Add multi-page item text
    python scripts/add_entry.py --type item_text --name "Weathered Letter" --page 2 \\
      --text "...then I have already departed this world."

    # List all entries
    python scripts/add_entry.py --list

    # Remove an entry by ID
    python scripts/add_entry.py --remove 3
"""

import argparse
import json
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent
DATA_DIR = PROJECT_ROOT / "data"
MANUAL_PATH = DATA_DIR / "manual_entries.json"

sys.path.insert(0, str(PROJECT_ROOT / "scripts"))
from analyze_quest_races import normalize_race


def load_manual_db():
    """Load or initialize the manual entries database."""
    if MANUAL_PATH.exists():
        with open(MANUAL_PATH, encoding="utf-8") as f:
            return json.load(f)
    return {"entries": [], "next_id": 1}


def save_manual_db(db):
    """Save the manual entries database."""
    with open(MANUAL_PATH, "w", encoding="utf-8") as f:
        json.dump(db, f, indent=2, ensure_ascii=False)
    print(f"Saved to {MANUAL_PATH}")


def load_npc_lookup():
    """Load NPC database for race/sex auto-resolution."""
    npc_path = DATA_DIR / "npc_database.json"
    if not npc_path.exists():
        return {}
    with open(npc_path, encoding="utf-8") as f:
        data = json.load(f)
    lookup = {}
    for entry_id, entry in data["entries"].items():
        name = entry.get("name", "").strip()
        if not name:
            continue
        raw_race = entry.get("race", "")
        norm = normalize_race(raw_race) if raw_race else None
        sex = entry.get("sex", "unknown")
        race = norm if norm else "Narrator"
        if name not in lookup or (race != "Narrator" and lookup[name][0] == "Narrator"):
            lookup[name] = (race, sex)
    return lookup


def add_gossip(args, db, npc_lookup):
    """Add a gossip entry."""
    if not args.npc:
        print("Error: --npc required for gossip entries")
        return False
    if not args.text:
        print("Error: --text required")
        return False

    race = args.race
    sex = args.sex
    if not race and args.npc in npc_lookup:
        race, auto_sex = npc_lookup[args.npc]
        if not sex:
            sex = auto_sex
        print(f"  Auto-resolved: {args.npc} → {race}/{sex}")
    elif not race:
        race = "Narrator"
        sex = sex or "unknown"
        print(f"  Warning: NPC '{args.npc}' not in database, using Narrator voice")

    entry = {
        "id": db["next_id"],
        "type": "gossip",
        "npc": args.npc,
        "race": race,
        "sex": sex or "unknown",
        "text": args.text,
    }
    db["entries"].append(entry)
    db["next_id"] += 1
    print(f"  Added gossip #{entry['id']}: {args.npc} ({race}/{sex})")
    return True


def add_quest_greeting(args, db, npc_lookup):
    """Add a quest greeting entry."""
    if not args.npc:
        print("Error: --npc required for quest_greeting entries")
        return False
    if not args.text:
        print("Error: --text required")
        return False

    race = args.race
    sex = args.sex
    if not race and args.npc in npc_lookup:
        race, auto_sex = npc_lookup[args.npc]
        if not sex:
            sex = auto_sex
        print(f"  Auto-resolved: {args.npc} → {race}/{sex}")
    elif not race:
        race = "Narrator"
        sex = sex or "unknown"
        print(f"  Warning: NPC '{args.npc}' not in database, using Narrator voice")

    entry = {
        "id": db["next_id"],
        "type": "quest_greeting",
        "npc": args.npc,
        "race": race,
        "sex": sex or "unknown",
        "text": args.text,
    }
    db["entries"].append(entry)
    db["next_id"] += 1
    print(f"  Added quest_greeting #{entry['id']}: {args.npc} ({race}/{sex})")
    return True


def add_item_text(args, db):
    """Add an item text entry (always narrator voice)."""
    if not args.name:
        print("Error: --name required for item_text entries")
        return False
    if not args.text:
        print("Error: --text required")
        return False

    page = args.page or 1
    entry = {
        "id": db["next_id"],
        "type": "item_text",
        "name": args.name,
        "page": page,
        "text": args.text,
    }
    db["entries"].append(entry)
    db["next_id"] += 1
    print(f"  Added item_text #{entry['id']}: \"{args.name}\" page {page}")
    return True


def list_entries(db):
    """List all manual entries."""
    entries = db.get("entries", [])
    if not entries:
        print("No manual entries.")
        return

    print(f"{len(entries)} manual entries:\n")
    for entry in entries:
        eid = entry.get("id", "?")
        etype = entry.get("type", "?")
        text_preview = entry.get("text", "")[:60]

        if etype == "gossip":
            npc = entry.get("npc", "?")
            race = entry.get("race", "?")
            sex = entry.get("sex", "?")
            print(f"  #{eid} [{etype}] {npc} ({race}/{sex}): {text_preview}...")
        elif etype == "quest_greeting":
            npc = entry.get("npc", "?")
            race = entry.get("race", "?")
            sex = entry.get("sex", "?")
            print(f"  #{eid} [{etype}] {npc} ({race}/{sex}): {text_preview}...")
        elif etype == "item_text":
            name = entry.get("name", "?")
            page = entry.get("page", 1)
            print(f"  #{eid} [{etype}] \"{name}\" p{page}: {text_preview}...")
        else:
            print(f"  #{eid} [{etype}]: {text_preview}...")


def remove_entry(db, entry_id):
    """Remove an entry by ID."""
    entries = db.get("entries", [])
    for i, entry in enumerate(entries):
        if entry.get("id") == entry_id:
            removed = entries.pop(i)
            print(f"  Removed #{entry_id}: {removed.get('type', '?')}")
            return True
    print(f"  Entry #{entry_id} not found")
    return False


def main():
    parser = argparse.ArgumentParser(description="TurtleTongue manual entry CLI")
    parser.add_argument(
        "--type", choices=["gossip", "quest_greeting", "item_text"],
        help="Entry type"
    )
    parser.add_argument("--npc", help="NPC name (for gossip/quest_greeting)")
    parser.add_argument("--name", help="Item/object name (for item_text)")
    parser.add_argument("--text", help="The text content to voice")
    parser.add_argument("--race", help="Override race (auto-resolved if omitted)")
    parser.add_argument("--sex", help="Override sex (auto-resolved if omitted)")
    parser.add_argument("--page", type=int, help="Page number for item_text (default: 1)")
    parser.add_argument("--list", action="store_true", help="List all entries")
    parser.add_argument("--remove", type=int, help="Remove entry by ID")
    args = parser.parse_args()

    db = load_manual_db()

    if args.list:
        list_entries(db)
        return

    if args.remove is not None:
        if remove_entry(db, args.remove):
            save_manual_db(db)
        return

    if not args.type:
        parser.print_help()
        return

    npc_lookup = load_npc_lookup()

    success = False
    if args.type == "gossip":
        success = add_gossip(args, db, npc_lookup)
    elif args.type == "quest_greeting":
        success = add_quest_greeting(args, db, npc_lookup)
    elif args.type == "item_text":
        success = add_item_text(args, db)

    if success:
        save_manual_db(db)


if __name__ == "__main__":
    main()
