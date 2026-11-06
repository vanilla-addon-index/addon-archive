#!/usr/bin/env python3
"""
TurtleTongue Sex Enrichment Script

Adds or verifies the "sex" field for every NPC in npc_database.json.

Three-pass sex detection:
  1. DBC chain: DisplayID → CreatureDisplayInfo → CreatureDisplayInfoExtra → sex
     Works for humanoid NPCs with ExtendedDisplayInfoID > 0.
  2. Race-name inference: if DBC gives "unknown", check the raw race string for
     explicit gender keywords ("female"/"male"). This catches creature types with
     gendered model variants (e.g. CentaurFemale, NagaMale, FemaleSatyr) and
     base-race NPCs with non-standard models (e.g. HumanMaleKid).
  3. Model-based rules: hardcoded sex for specific creature model variants where
     the 3D model is always gendered but the race name doesn't contain keywords.
     E.g. base Centaur model = always male, CentaurCaster = always female.

Usage:
    python scripts/enrich_sex.py             # Enrich and save
    python scripts/enrich_sex.py --dry-run   # Report only, don't modify
"""

import argparse
import json
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent
DATA_PATH = PROJECT_ROOT / "data"
NPC_DB_PATH = DATA_PATH / "npc_database.json"


def load_dbc_files():
    """Load DBC CSV files for sex lookup. Same logic as crawler.py."""
    # CreatureDisplayInfo: DisplayID → [all columns]
    display_info = {}
    with open(DATA_PATH / "CreatureDisplayInfo.csv", "r", encoding="utf-8") as f:
        for line in f.readlines()[1:]:
            parts = line.strip().split(",")
            if len(parts) >= 4:
                display_id = parts[0].strip('"')
                display_info[display_id] = [p.strip('"') for p in parts]

    # CreatureDisplayInfoExtra: ExtendedID → (DisplayRaceID, DisplaySexID)
    display_extra = {}
    with open(DATA_PATH / "CreatureDisplayInfoExtra.csv", "r", encoding="utf-8") as f:
        for line in f.readlines()[1:]:
            parts = line.strip().split(",")
            if len(parts) >= 3:
                ext_id = parts[0].strip('"')
                sex_id = parts[2].strip('"')
                display_extra[ext_id] = sex_id

    print(f"Loaded {len(display_info)} display entries, {len(display_extra)} extra entries")
    return display_info, display_extra


def lookup_sex(display_id, display_info, display_extra):
    """Look up sex for a DisplayID via the DBC chain.

    Returns "male", "female", or "unknown".
    """
    SEX_MAP = {"0": "male", "1": "female"}

    if not display_id or display_id == "0":
        return "unknown"

    display_row = display_info.get(display_id)
    if not display_row or len(display_row) < 4:
        return "unknown"

    extended_id = display_row[3]
    if extended_id and extended_id != "0":
        sex_id = display_extra.get(extended_id)
        if sex_id is not None:
            return SEX_MAP.get(sex_id, "unknown")

    return "unknown"


def infer_sex_from_race(race):
    """Infer sex from the raw race string when DBC gives unknown.

    Checks for explicit gender keywords in model-derived race names.
    E.g. CentaurFemale → female, NagaMale → male, FemaleSatyr → female.
    """
    if not race:
        return "unknown"
    rl = race.lower()
    if "female" in rl:
        return "female"
    if "male" in rl:
        return "male"
    return "unknown"


# Hardcoded sex for creature model variants where the 3D model is always
# gendered but the race name doesn't contain "male"/"female" keywords.
# Based on WoW creature model conventions confirmed via game inspection.
MODEL_SEX_RULES = {
    # Centaur: base model and warrior/khan variants are male, caster is female
    "Centaur": "male",
    "CentaurCaster": "female",
    "CentaurKhan": "male",
    "Centaurrior": "male",
    # Naga: base model is male, caster variant is female
    "Naga": "male",
    "NagaCaster": "female",
    # Siren: female naga variant (sea witches / mermaids in WoW lore)
    "Siren": "female",
    "NagaSiren": "female",
}


def main():
    parser = argparse.ArgumentParser(description="Enrich NPC database with sex from DBC files")
    parser.add_argument("--dry-run", action="store_true", help="Report only, don't save")
    args = parser.parse_args()

    # Load data
    with open(NPC_DB_PATH, "r", encoding="utf-8") as f:
        db = json.load(f)
    entries = db["entries"]
    print(f"Loaded {len(entries)} NPCs from {NPC_DB_PATH.name}")

    display_info, display_extra = load_dbc_files()

    # Enrich
    added_dbc = 0
    added_race = 0
    added_model = 0
    verified = 0
    corrected = 0
    already_unknown = 0

    for entry_id, entry in entries.items():
        display_id = entry.get("display_id", "0")
        dbc_sex = lookup_sex(display_id, display_info, display_extra)
        race = entry.get("race", "")

        # Three-pass: DBC first, then race-name inference, then model rules
        if dbc_sex != "unknown":
            resolved_sex = dbc_sex
            source = "dbc"
        else:
            race_sex = infer_sex_from_race(race)
            if race_sex != "unknown":
                resolved_sex = race_sex
                source = "race"
            elif race in MODEL_SEX_RULES:
                resolved_sex = MODEL_SEX_RULES[race]
                source = "model"
            else:
                resolved_sex = "unknown"
                source = "none"

        existing_sex = entry.get("sex")

        if existing_sex is None:
            # No sex field yet
            entry["sex"] = resolved_sex
            if source == "dbc":
                added_dbc += 1
            elif source == "race":
                added_race += 1
            elif source == "model":
                added_model += 1
            else:
                already_unknown += 1
        elif existing_sex == resolved_sex:
            verified += 1
        else:
            # Mismatch — resolved takes precedence
            print(f"  Corrected {entry_id} ({entry['name']}): {existing_sex} → {resolved_sex}")
            entry["sex"] = resolved_sex
            corrected += 1

    # Stats
    total = len(entries)
    male = sum(1 for e in entries.values() if e.get("sex") == "male")
    female = sum(1 for e in entries.values() if e.get("sex") == "female")
    unknown = sum(1 for e in entries.values() if e.get("sex") == "unknown")

    print(f"\nResults:")
    print(f"  Total NPCs:       {total}")
    print(f"  Already correct:   {verified}")
    print(f"  Added (DBC):       {added_dbc}")
    print(f"  Added (race name): {added_race}")
    print(f"  Added (model rule):{added_model}")
    print(f"  Added (unknown):   {already_unknown}")
    print(f"  Corrected:         {corrected}")
    print(f"\nFinal distribution:")
    print(f"  Male:    {male}")
    print(f"  Female:  {female}")
    print(f"  Unknown: {unknown}")

    if args.dry_run:
        print("\n[DRY RUN] No changes saved.")
        return

    # Save
    with open(NPC_DB_PATH, "w", encoding="utf-8") as f:
        json.dump(db, f, indent=2, ensure_ascii=False)
    print(f"\nSaved to {NPC_DB_PATH.name}")


if __name__ == "__main__":
    main()
