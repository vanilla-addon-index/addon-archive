#!/usr/bin/env python3
"""
Analyze quest giver races and identify voice profile needs.

Cross-references quest_database.json with npc_database.json to determine:
1. Which races actually give quests (need voice profiles)
2. CamelCase → base race normalization map
3. Creature types that need voice profiles
4. Named NPCs with most dialogue lines (Tier 3 candidates)

Usage:
    python scripts/analyze_quest_races.py
    python scripts/analyze_quest_races.py --show-unmapped   # show NPCs with no race match
    python scripts/analyze_quest_races.py --named-top 50    # top N named NPC candidates
"""

import json
import re
import argparse
from collections import Counter, defaultdict
from pathlib import Path

DATA_DIR = Path(__file__).parent.parent / "data"

# ─── Base races (10 playable + narrator) ──────────────────────────────────
BASE_RACES = {
    "Human", "Dwarf", "Night Elf", "Gnome", "High Elf",  # Alliance
    "Orc", "Troll", "Undead", "Tauren", "Goblin",        # Horde
}

# ─── CamelCase race value → normalized base race ─────────────────────────
# Built from inspecting npc_database.json race values.
# Keys are raw race strings from the crawler; values are the base race or
# creature type they map to.
RACE_NORMALIZATION = {
    # ── Human variants ───────────────────────────────────────────────
    "Human":                "Human",
    "HumanMale":            "Human",
    "HumanFemale":          "Human",
    "HumanMaleKid":         "Human",
    "HumanFemaleKid":       "Human",
    "HumanMale_Fat":        "Human",
    "HumanMale_Thin":       "Human",
    "HumanMale_Captain":    "Human",
    "Human_Farmer":         "Human",
    "Human_Kid":            "Human",
    "HumanMale_Warlock":    "Human",
    "HumanFemale_Mage":     "Human",
    "HumanMale_Mage":       "Human",
    "HumanFemale_Warlock":  "Human",
    "HumanMale_DeathKnight":"Human",
    "HumanMale_Necromancer":"Human",
    "HumanMale_Pirate":     "Human",
    "HumanFemale_Pirate":   "Human",
    "HumanMale_TownGuard":  "Human",

    # ── Dwarf variants ───────────────────────────────────────────────
    "Dwarf":                "Dwarf",
    "DwarfMale":            "Dwarf",
    "DwarfFemale":          "Dwarf",
    "DwarfMale_Wildhammer": "Dwarf",
    "DwarfFemale_Wildhammer":"Dwarf",
    "DwarfMale_DarkIron":   "Dwarf",
    "DwarfFemale_DarkIron": "Dwarf",

    # ── Night Elf variants ───────────────────────────────────────────
    "NightElf":             "Night Elf",
    "NightElfMale":         "Night Elf",
    "NightElfFemale":       "Night Elf",
    "NightElfMale_Druid":   "Night Elf",
    "NightElfFemale_Druid": "Night Elf",
    "NightElfMale_DemonHunter": "Night Elf",
    "NightElfFemale_DemonHunter": "Night Elf",

    # ── Gnome variants ───────────────────────────────────────────────
    "Gnome":                "Gnome",
    "GnomeMale":            "Gnome",
    "GnomeFemale":          "Gnome",

    # ── High Elf variants ────────────────────────────────────────────
    "HighElf":              "High Elf",
    "HighElfMale":          "High Elf",
    "HighElfFemale":        "High Elf",
    "HighElfMale_Mage":     "High Elf",
    "HighElfFemale_Mage":   "High Elf",
    "HighElfMale_Ranger":   "High Elf",
    "HighElfFemale_Ranger": "High Elf",

    # ── Orc variants ────────────────────────────────────────────────
    "Orc":                  "Orc",
    "OrcMale":              "Orc",
    "OrcFemale":            "Orc",
    "OrcMaleKid":           "Orc",
    "OrcFemaleKid":         "Orc",
    "OrcMale_Warlock":      "Orc",
    "OrcMale_Shaman":       "Orc",
    "OrcMale_Grunt":        "Orc",
    "OrcFemale_Shaman":     "Orc",

    # ── Troll variants ──────────────────────────────────────────────
    "Troll":                "Troll",
    "TrollMale":            "Troll",
    "TrollFemale":          "Troll",
    "TrollDire":            "Troll",
    "TrollForest":          "Troll",
    "TrollIce":             "Troll",
    "TrollSand":            "Troll",
    "TrollMaleWitch":       "Troll",

    # ── Undead variants ─────────────────────────────────────────────
    "Undead":               "Undead",
    "UndeadMale":           "Undead",
    "UndeadFemale":         "Undead",
    "Scourge":              "Undead",
    "ScourgeMale":          "Undead",
    "ScourgeFemale":        "Undead",

    # ── Tauren variants ─────────────────────────────────────────────
    "Tauren":               "Tauren",
    "TaurenMale":           "Tauren",
    "TaurenFemale":         "Tauren",

    # ── Goblin variants ─────────────────────────────────────────────
    "Goblin":               "Goblin",
    "GoblinMale":           "Goblin",
    "GoblinFemale":         "Goblin",
    "GoblinMale_Alchemist": "Goblin",

    # ── Creature types (non-playable races) ─────────────────────────
    # These get their own voice profiles or fall back to narrator
    "Ogre":                 "Ogre",
    "OgreMage":             "Ogre",
    "OgreLord":             "Ogre",
    "Ogre2Headed":          "Ogre",
    "Ogrelord":             "Ogre",
    "Ogreold":              "Ogre",
    "Naga":                 "Naga",
    "NagaMale":             "Naga",
    "NagaFemale":           "Naga",
    "NagaSiren":            "Naga",
    "Siren":                "Naga",
    "Gnoll":                "Gnoll",
    "GnollCaster":          "Gnoll",
    "gnoll":                "Gnoll",
    "Centaur":              "Centaur",
    "CentaurKhan":          "Centaur",
    "CentaurFemale":        "Centaur",
    "CentaurCaster":        "Centaur",
    "Centaurrior":          "Centaur",
    "Satyr":                "Satyr",
    "Murloc":               "Murloc",
    "BabyMurloc":           "Murloc",
    "Furbolg":              "Furbolg",
    "FurbolgShaman":        "Furbolg",
    "FurbolgElderShaman":   "Furbolg",
    "furbolg_caster01":     "Furbolg",
    "furbolg_caster02":     "Furbolg",
    "furbolg_boss01":       "Furbolg",
    "furbolg_boss02":       "Furbolg",
    "Harpy":                "Harpy",
    "Ghoul":                "Ghoul",
    "FleshGolem":           "Ghoul",
    "Ghost":                "Ghost",
    "Wolf_ghost":           "Ghost",
    "Skeleton":             "Skeleton",
    "Skeleton_Mage":        "Skeleton",
    "Banshee":              "Banshee",
    "Wraith":               "Wraith",
    "Dragon":               "Dragon",
    "Drake":                "Dragon",
    "DragonWhelp":          "Dragon",
    "DragonAzurgoz":        "Dragon",
    "NorthrendDrake":       "Dragon",
    "DragonSpawn":          "Dragonspawn",
    "DragonSpawnMage":      "Dragonspawn",
    "DragonSpawnCaster":    "Dragonspawn",
    "DragonFootSoldier":    "Dragonspawn",
    "Dragonkin":            "Dragonspawn",
    "Worgen":               "Worgen",
    "WorgenDemonMage":      "Worgen",
    "Wisp":                 "Wisp",
    "Treant":               "Treant",
    "Ent":                  "Treant",
    "AncientofLore":        "Treant",
    "AncientProtector":     "Treant",
    "Ancientof":            "Treant",
    "Dryad":                "Dryad",
    "KeeperOfTheGrove":     "Keeper of the Grove",
    # ── Dreadlord (demon category — deep menacing voice) ────────────
    "DreadLord":            "Dreadlord",
    "DreadLordboss":        "Dreadlord",
    "Demon":                "Dreadlord",
    "FelGuard":             "Dreadlord",
    "FelHound":             "Dreadlord",
    "FelHoundmount":        "Dreadlord",
    "Felhound3_shadow_mount": "Dreadlord",
    "DoomGuard":            "Dreadlord",
    "Infernal":             "Dreadlord",
    "InfernalMount":        "Dreadlord",
    "VoidWalker":           "Dreadlord",
    "VoidWalker_Outland":   "Dreadlord",
    "creature_demoncrystal_02": "Dreadlord",
    # ── Imp (mischievous small demon voice) ──────────────────────────
    "Imp":                  "Imp",
    "FireImp":              "Imp",
    "Impoutland":           "Imp",
    # ── Succubus (seductive female demon voice) ──────────────────────
    "Succubus":             "Succubus",
    "Succubusold":          "Succubus",
    "Eredar":               "Eredar",
    "Draenei":              "Draenei",
    "DraeneiMale":          "Draenei",
    "DraeneiFemale":        "Draenei",
    "BrokenDraenei":        "Draenei",
    "LostOne":              "Draenei",
    "Lich":                 "Lich",
    "Abomination":          "Abomination",
    "Elemental":            "Elemental",
    "EarthElemental":       "Elemental",
    "ElementalEarth":       "Elemental",
    "FireElemental":        "Elemental",
    "WaterElemental":       "Elemental",
    "AirElemental":         "Elemental",
    "StoneKeeper":          "Elemental",
    "MountainGiant":        "Elemental",
    "Arakkoa":              "Arakkoa",
    "Nerubian":             "Nerubian",
    "Ethereal":             "Ethereal",

    # ── Misc creature types that give quests ─────────────────────────
    "QuillBoar":            "Quilboar",
    "Tuskarrmale":          "Tuskarr",
    "Watcher":              "Night Elf",     # Wardens are Night Elf
    "Forsakenmage":         "Undead",        # Forsaken are Undead
    "HUMLMerchant":         "Human",         # Human male merchant model
    "HumanMalePirateCaptain": "Human",
    "HumanMalePirateSwashbuckler": "Human",
    "HumanThief":           "Human",
    "DwarfMaleriorLight":   "Dwarf",
    "GnomeBot":             "Gnome",
    "GoblinShredder":       "Goblin",
    "HighElfMale_Hunter":   "High Elf",
    "BloodelfFemaleKid":    "High Elf",      # Blood/High Elf child model
    "CrackElfMale":         "High Elf",      # Wretched/withered elf variant
    "Kilrogg":              "Orc",           # Kilrogg Deadeye is an Orc
    "rexxar":               "Orc",           # Rexxar uses unique model, half-ogre but Horde
    "Pandarenmonk":         "Pandaren",
    "SnowMan":              "Narrator",      # Snowman NPCs — novelty
    "Cupid":                "Narrator",      # Kwee Q. Peddlefeet — novelty
    "Chicken":              "Narrator",      # Chicken/joke NPCs
    "BogBeast":             "Narrator",      # Bog beasts — deep growl, narrator fallback
    "SeaTurtle":            "Narrator",      # Turtles
    "SeaGiant":             "Narrator",      # Sea giants
    "Gorilla":              "Narrator",      # Animals
    "Tiger":                "Narrator",      # Animals
    "Monkey":               "Narrator",      # Animals
    "Duck":                 "Narrator",      # Animals
    "Sheep":                "Narrator",      # Animals
    "Horse":                "Narrator",      # Animals
    "Deer":                 "Narrator",      # Animals
    "Bear":                 "Narrator",      # Animals
    "Frog":                 "Narrator",      # Animals
    "KodoBeastPack":        "Narrator",      # Animals
    "Troglodyte":           "Narrator",      # Troggs
    "Wendigo":              "Narrator",      # Wendigos
    "Kobold":               "Kobold",        # Kobolds — own creature voice
    "Creature_ScourgeCrystalDamaged": "Narrator",  # Inanimate objects
}


def load_json(filename):
    path = DATA_DIR / filename
    with open(path) as f:
        return json.load(f)


def normalize_race(raw_race):
    """Try to normalize a raw CamelCase race string to a base race.
    
    First checks the explicit map. If not found, tries heuristic matching
    against base race names.
    """
    if raw_race in RACE_NORMALIZATION:
        return RACE_NORMALIZATION[raw_race]
    
    # Heuristic: check if any base race name appears at start of the raw value
    raw_lower = raw_race.lower().replace("_", "").replace(" ", "")
    for base in BASE_RACES:
        base_lower = base.lower().replace(" ", "")
        if raw_lower.startswith(base_lower):
            return base
    
    return None


def count_dialogue_lines(quest):
    """Count the number of non-empty text fields in a quest entry."""
    count = 0
    for field in ("description", "progress", "completion"):
        text = quest.get(field, "")
        if text and text.strip():
            count += 1
    return count


def count_giver_lines(quest):
    """Count dialogue lines spoken by the quest GIVER (description only)."""
    text = quest.get("description", "")
    return 1 if text and text.strip() else 0


def count_ender_lines(quest):
    """Count dialogue lines spoken by the quest ENDER (progress + completion)."""
    count = 0
    for field in ("progress", "completion"):
        text = quest.get(field, "")
        if text and text.strip():
            count += 1
    return count


def main():
    parser = argparse.ArgumentParser(description="Analyze quest giver races")
    parser.add_argument("--show-unmapped", action="store_true",
                        help="Show quest givers with no race mapping")
    parser.add_argument("--named-top", type=int, default=30,
                        help="Number of top named NPC candidates to show (default: 30)")
    parser.add_argument("--all-races", action="store_true",
                        help="Show ALL raw race values (not just quest-giving)")
    args = parser.parse_args()

    quests = load_json("quest_database.json")
    npcs = load_json("npc_database.json")

    # Build NPC lookup by entry ID and by name
    npc_by_id = npcs["entries"]
    npc_by_name = defaultdict(list)
    for nid, npc in npc_by_id.items():
        npc_by_name[npc["name"]].append((nid, npc))

    # ─── Analyze quest givers AND enders ──────────────────────────────
    # In WoW, quest_giver speaks the description text, while quest_ender
    # speaks progress + completion text. When they differ (28% of quests),
    # we must attribute dialogue to the correct NPC.
    quest_npc_races = Counter()          # normalized race → count of quests (any role)
    quest_giver_raw_races = Counter()    # raw race → count of quests
    unmapped_givers = Counter()          # raw race → count (when no mapping)
    no_npc_match = Counter()             # NPC name → count (not in NPC DB)
    npc_dialogue_lines = Counter()       # (npc_name, npc_id) → dialogue line count
    npc_race_map = {}                    # (npc_name, npc_id) → normalized race
    npc_quests = defaultdict(list)       # (npc_name, npc_id) → [quest_titles]

    total_quests = len(quests["entries"])
    matched_by_id = 0
    matched_by_name = 0
    unmatched = 0

    def resolve_npc(name, npc_id=""):
        """Find NPC in database, return (npc_dict, match_type) or (None, None)."""
        if npc_id and npc_id in npc_by_id:
            return npc_by_id[npc_id], "id"
        if name in npc_by_name:
            return npc_by_name[name][0][1], "name"
        return None, None

    def attribute_lines(npc_name, npc_id, line_count, quest_title):
        """Attribute dialogue lines to an NPC, tracking race and quest."""
        if line_count == 0:
            return
        npc, match_type = resolve_npc(npc_name, npc_id)
        if npc:
            raw_race = npc.get("race", "Unknown")
            normalized = normalize_race(raw_race)
            key = (npc_name, npc_id or "?")
            if normalized:
                npc_dialogue_lines[key] += line_count
                npc_race_map[key] = normalized
                if quest_title not in npc_quests.get(key, []):
                    npc_quests[key].append(quest_title)
            else:
                npc_dialogue_lines[key] += line_count
                npc_race_map[key] = f"UNMAPPED:{raw_race}"
                if quest_title not in npc_quests.get(key, []):
                    npc_quests[key].append(quest_title)

    for qid, quest in quests["entries"].items():
        giver_name = quest.get("quest_giver", "")
        giver_id = quest.get("quest_giver_id", "")
        ender_name = quest.get("quest_ender", "")
        ender_id = quest.get("quest_ender_id", "")
        title = quest.get("title", "?")

        g_lines = count_giver_lines(quest)   # description → giver
        e_lines = count_ender_lines(quest)   # progress + completion → ender

        # Track giver matching stats
        if giver_name:
            npc, match_type = resolve_npc(giver_name, giver_id)
            if npc:
                if match_type == "id":
                    matched_by_id += 1
                else:
                    matched_by_name += 1
                raw_race = npc.get("race", "Unknown")
                quest_giver_raw_races[raw_race] += 1
                normalized = normalize_race(raw_race)
                if normalized:
                    quest_npc_races[normalized] += 1
                else:
                    unmapped_givers[raw_race] += 1
            else:
                no_npc_match[giver_name] += 1
                unmatched += 1

        # Attribute description lines to quest_giver
        if giver_name:
            attribute_lines(giver_name, giver_id, g_lines, title)

        # Attribute progress + completion lines to quest_ender
        # If no explicit ender, these go to the giver (same NPC)
        if ender_name and ender_name != giver_name:
            attribute_lines(ender_name, ender_id, e_lines, title)
            # Track ender NPC race too
            npc, _ = resolve_npc(ender_name, ender_id)
            if not npc and ender_name not in no_npc_match:
                no_npc_match[ender_name] += 0  # just register it
        elif giver_name:
            # Same NPC or no explicit ender — giver gets all lines
            attribute_lines(giver_name, giver_id, e_lines, title)

    # ─── Print Results ───────────────────────────────────────────────
    print("=" * 70)
    print("QUEST GIVER RACE ANALYSIS")
    print("=" * 70)
    print(f"\nTotal quests: {total_quests}")
    print(f"Matched by NPC ID: {matched_by_id}")
    print(f"Matched by name:   {matched_by_name}")
    print(f"No NPC match:      {unmatched}")

    # ── Normalized race distribution ─────────────────────────────────
    print(f"\n{'─' * 70}")
    print("NORMALIZED RACES (quest givers + enders)")
    print(f"{'─' * 70}")
    print(f"{'Race':<25} {'Quests':>8}  {'Tier'}")
    print(f"{'─' * 25} {'─' * 8}  {'─' * 15}")
    for race, count in sorted(quest_npc_races.items(), key=lambda x: -x[1]):
        tier = "Base" if race in BASE_RACES else "Creature"
        print(f"{race:<25} {count:>8}  {tier}")

    # ── Unmapped races that give quests ──────────────────────────────
    if unmapped_givers:
        print(f"\n{'─' * 70}")
        print("UNMAPPED RACES (quest givers with no normalization rule)")
        print(f"{'─' * 70}")
        for race, count in sorted(unmapped_givers.items(), key=lambda x: -x[1]):
            # Find example NPC names for this race
            examples = []
            for nid, npc in npc_by_id.items():
                if npc.get("race") == race and len(examples) < 3:
                    examples.append(npc["name"])
            ex_str = ", ".join(examples) if examples else "?"
            print(f"  {race:<35} {count:>4} quests  (e.g. {ex_str})")

    # ── Raw race values for quest givers ─────────────────────────────
    if args.all_races:
        print(f"\n{'─' * 70}")
        print("ALL RAW RACE VALUES (quest givers)")
        print(f"{'─' * 70}")
        for race, count in sorted(quest_giver_raw_races.items(), key=lambda x: -x[1]):
            norm = normalize_race(race) or "??? UNMAPPED"
            print(f"  {race:<40} {count:>4} → {norm}")

    # ── Quest givers not in NPC database ─────────────────────────────
    if no_npc_match and args.show_unmapped:
        print(f"\n{'─' * 70}")
        print(f"QUEST GIVERS NOT IN NPC DATABASE ({len(no_npc_match)} unique)")
        print(f"{'─' * 70}")
        for name, count in sorted(no_npc_match.items(), key=lambda x: -x[1]):
            print(f"  {name:<40} {count:>4} quests")

    # ── Top named NPCs by dialogue lines (Tier 3 candidates) ────────
    print(f"\n{'─' * 70}")
    print(f"TOP {args.named_top} NAMED NPCs BY DIALOGUE LINES (Tier 3 candidates)")
    print(f"{'─' * 70}")
    print(f"{'NPC Name':<35} {'ID':>6} {'Lines':>6} {'Race':<20} {'Sample Quests'}")
    print(f"{'─' * 35} {'─' * 6} {'─' * 6} {'─' * 20} {'─' * 30}")
    for (name, nid), lines in npc_dialogue_lines.most_common(args.named_top):
        race = npc_race_map.get((name, nid), "?")
        quest_titles = npc_quests.get((name, nid), [])
        sample = "; ".join(quest_titles[:3])
        if len(quest_titles) > 3:
            sample += f" (+{len(quest_titles) - 3} more)"
        print(f"{name:<35} {nid:>6} {lines:>6} {race:<20} {sample[:60]}")

    # ── Summary for voice profile planning ───────────────────────────
    print(f"\n{'=' * 70}")
    print("VOICE PROFILE SUMMARY")
    print(f"{'=' * 70}")
    
    base_count = sum(1 for r in quest_npc_races if r in BASE_RACES)
    creature_count = sum(1 for r in quest_npc_races if r not in BASE_RACES)
    
    print(f"\nTier 1 (Base races giving quests): {base_count}")
    for r in sorted(BASE_RACES):
        count = quest_npc_races.get(r, 0)
        if count > 0:
            print(f"  {r}: {count} quests")
    
    print(f"\nTier 2 (Creature types giving quests): {creature_count}")
    for race, count in sorted(
        ((r, c) for r, c in quest_npc_races.items() if r not in BASE_RACES),
        key=lambda x: -x[1]
    ):
        print(f"  {race}: {count} quests")
    
    unmapped_total = sum(unmapped_givers.values())
    if unmapped_total:
        print(f"\nUnmapped (need normalization rules): {len(unmapped_givers)} race values, {unmapped_total} quests")


if __name__ == "__main__":
    main()
