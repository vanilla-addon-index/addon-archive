#!/usr/bin/env python3
"""
Generate comprehensive voice_profile_report.json from quest + NPC databases.

Correctly attributes dialogue lines:
- description → quest_giver
- progress + completion → quest_ender (or quest_giver if no separate ender)

EVERY quest NPC gets voiced. The tier system only determines which voice
PROFILE is used, not whether an NPC gets voiced.
"""

import json
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from analyze_quest_races import (
    RACE_NORMALIZATION, BASE_RACES, normalize_race,
    count_giver_lines, count_ender_lines,
)

DATA_DIR = Path(__file__).parent.parent / "data"

# ─── Tier 3: User-curated named NPCs with custom unique voice profiles ──
TIER3_NAMED_NPCS = [
    "Thrall",
    "Lady Sylvanas Windrunner",
    "Cairne Bloodhoof",
    "Vol'jin",
    "Highlord Bolvar Fordragon",
    "King Magni Bronzebeard",
    "Tyrande Whisperwind",
    "Lady Jaina Proudmoore",
    "Gazlowe",
    "Vereesa Windrunner",
    "Archmage Ansirem Runeweaver",
    "Tirion Fordring",
    "Varimathras",
    "Chromie",
    "Nathanos Blightcaller",
    "Rexxar",
]

TIER3_SET = set(TIER3_NAMED_NPCS)

# ─── Faction leaders (one per playable race) ─────────────────────────────
FACTION_LEADERS = {
    "Orc":       "Thrall",
    "Undead":    "Lady Sylvanas Windrunner",
    "Tauren":    "Cairne Bloodhoof",
    "Troll":     "Vol'jin",
    "Goblin":    "Gazlowe",
    "Human":     "Highlord Bolvar Fordragon",
    "Dwarf":     "King Magni Bronzebeard",
    "Night Elf": "Tyrande Whisperwind",
    "Gnome":     "High Tinker Mekkatorque",
    "High Elf":  "Vereesa Windrunner",
}


def load_json(name):
    with open(DATA_DIR / name) as f:
        return json.load(f)


def main():
    quests = load_json("quest_database.json")["entries"]
    npcs = load_json("npc_database.json")["entries"]

    # Build NPC lookups
    npc_by_name = defaultdict(list)
    for eid, npc in npcs.items():
        npc_by_name[npc["name"]].append((eid, npc))

    def resolve_npc(name, npc_id=""):
        if npc_id and npc_id in npcs:
            return npcs[npc_id], npc_id
        if name in npc_by_name:
            return npc_by_name[name][0][1], npc_by_name[name][0][0]
        return None, None

    # ─── Attribute dialogue lines to the correct NPC ─────────────────
    npc_stats = defaultdict(lambda: {
        "quests_as_giver": [],
        "quests_as_ender": [],
        "giver_lines": 0,
        "ender_lines": 0,
        "entry_id": None,
        "raw_race": "",
        "normalized_race": None,
    })

    def ensure_npc_meta(name, npc_id):
        """Ensure NPC stats entry has metadata (entry_id, race). Returns (npc, eid)."""
        npc, eid = resolve_npc(name, npc_id)
        if npc:
            s = npc_stats[name]
            if not s["entry_id"]:
                s["entry_id"] = eid
                s["raw_race"] = npc.get("race", "")
                s["normalized_race"] = normalize_race(s["raw_race"]) if s["raw_race"] else None
        return npc, eid

    for qid, q in quests.items():
        giver = q.get("quest_giver", "")
        giver_id = q.get("quest_giver_id", "")
        ender = q.get("quest_ender", "")
        ender_id = q.get("quest_ender_id", "")
        title = q.get("title", "?")

        g_lines = count_giver_lines(q)   # description → giver
        e_lines = count_ender_lines(q)   # progress + completion → ender

        # Resolve and attribute to giver
        if giver:
            npc, eid = ensure_npc_meta(giver, giver_id)
            if npc and g_lines:
                s = npc_stats[giver]
                s["giver_lines"] += g_lines
                s["quests_as_giver"].append({"quest_id": qid, "title": title})

        # Resolve and attribute to ender (or giver if same)
        if e_lines:
            if ender and ender != giver:
                npc, eid = ensure_npc_meta(ender, ender_id)
                if npc:
                    s = npc_stats[ender]
                    s["ender_lines"] += e_lines
                    s["quests_as_ender"].append({"quest_id": qid, "title": title})
            elif giver:
                npc, eid = resolve_npc(giver, giver_id)
                if npc:
                    s = npc_stats[giver]
                    s["ender_lines"] += e_lines
                    # Don't add to quests_as_ender — same NPC is giver+ender

    # ─── Build sorted NPC list ───────────────────────────────────────
    all_npcs = []
    for name, s in npc_stats.items():
        total_lines = s["giver_lines"] + s["ender_lines"]
        if total_lines == 0:
            continue

        # Determine voice tier
        if name in TIER3_SET:
            voice_tier = "tier3_custom"
        elif s["normalized_race"] in BASE_RACES:
            voice_tier = "tier1_race"
        elif s["normalized_race"] == "Narrator":
            voice_tier = "narrator"
        elif s["normalized_race"]:
            voice_tier = "tier2_creature"
        else:
            # NPC in database but race couldn't be determined from DBC files.
            # At runtime: try UnitRace("npc"), fall back to narrator voice.
            voice_tier = "narrator_fallback"

        all_npcs.append({
            "name": name,
            "entry_id": s["entry_id"],
            "total_lines": total_lines,
            "giver_lines": s["giver_lines"],
            "ender_lines": s["ender_lines"],
            "quest_count": len(s["quests_as_giver"]) + len(s["quests_as_ender"]),
            "normalized_race": s["normalized_race"],
            "raw_race": s["raw_race"],
            "voice_tier": voice_tier,
        })
    all_npcs.sort(key=lambda x: -x["total_lines"])

    # ─── Tier 1: Base Races ──────────────────────────────────────────
    tier1 = {}
    for race in sorted(BASE_RACES):
        race_npcs = [n for n in all_npcs if n["normalized_race"] == race]
        if not race_npcs:
            continue
        tier1[race] = {
            "total_npcs": len(race_npcs),
            "total_dialogue_lines": sum(n["total_lines"] for n in race_npcs),
            "top_npcs": [
                {
                    "name": n["name"],
                    "entry_id": n["entry_id"],
                    "total_lines": n["total_lines"],
                    "giver_lines": n["giver_lines"],
                    "ender_lines": n["ender_lines"],
                    "quest_count": n["quest_count"],
                }
                for n in race_npcs[:30]
            ],
        }

    # ─── Tier 2: Creature Types ──────────────────────────────────────
    creature_races = sorted(set(
        n["normalized_race"] for n in all_npcs
        if n["normalized_race"] and n["normalized_race"] not in BASE_RACES
        and n["normalized_race"] != "Narrator"
    ))
    tier2 = {}
    for ctype in creature_races:
        ct_npcs = [n for n in all_npcs if n["normalized_race"] == ctype]
        if not ct_npcs:
            continue
        tier2[ctype] = {
            "total_npcs": len(ct_npcs),
            "total_dialogue_lines": sum(n["total_lines"] for n in ct_npcs),
            "npcs": [
                {
                    "name": n["name"],
                    "entry_id": n["entry_id"],
                    "total_lines": n["total_lines"],
                    "giver_lines": n["giver_lines"],
                    "ender_lines": n["ender_lines"],
                    "quest_count": n["quest_count"],
                }
                for n in ct_npcs
            ],
        }

    # ─── Tier 3: Named NPCs (user-curated) ──────────────────────────
    tier3 = []
    for npc_name in TIER3_NAMED_NPCS:
        matches = [n for n in all_npcs if n["name"] == npc_name]
        if matches:
            n = matches[0]
            s = npc_stats[npc_name]
            tier3.append({
                "name": npc_name,
                "entry_id": n["entry_id"],
                "total_lines": n["total_lines"],
                "giver_lines": n["giver_lines"],
                "ender_lines": n["ender_lines"],
                "normalized_race": n["normalized_race"],
                "raw_race": n["raw_race"],
                "quests_as_giver": [q["title"] for q in s["quests_as_giver"]],
                "quests_as_ender": [q["title"] for q in s["quests_as_ender"]],
                "status": "found",
            })
        else:
            # Check NPC DB even if no quest lines
            npc, eid = resolve_npc(npc_name)
            if npc:
                raw = npc.get("race", "")
                tier3.append({
                    "name": npc_name,
                    "entry_id": eid,
                    "total_lines": 0,
                    "giver_lines": 0,
                    "ender_lines": 0,
                    "normalized_race": normalize_race(raw),
                    "raw_race": raw,
                    "quests_as_giver": [],
                    "quests_as_ender": [],
                    "status": "in_npc_db_but_no_quest_lines",
                })
            else:
                tier3.append({
                    "name": npc_name,
                    "entry_id": None,
                    "total_lines": 0,
                    "normalized_race": None,
                    "raw_race": None,
                    "quests_as_giver": [],
                    "quests_as_ender": [],
                    "status": "NOT_FOUND_IN_DATABASE",
                })

    # ─── Faction Leaders ─────────────────────────────────────────────
    faction_leaders = []
    for race in ["Orc", "Undead", "Tauren", "Troll", "Goblin",
                  "Human", "Dwarf", "Night Elf", "Gnome", "High Elf"]:
        leader_name = FACTION_LEADERS[race]
        matches = [n for n in all_npcs if n["name"] == leader_name]
        if matches:
            n = matches[0]
            faction_leaders.append({
                "race": race,
                "name": leader_name,
                "entry_id": n["entry_id"],
                "total_lines": n["total_lines"],
                "giver_lines": n["giver_lines"],
                "ender_lines": n["ender_lines"],
                "normalized_race": n["normalized_race"],
                "in_tier3_custom": leader_name in TIER3_SET,
                "status": "found",
            })
        else:
            npc, eid = resolve_npc(leader_name)
            if npc:
                raw = npc.get("race", "")
                faction_leaders.append({
                    "race": race,
                    "name": leader_name,
                    "entry_id": eid,
                    "total_lines": 0,
                    "giver_lines": 0,
                    "ender_lines": 0,
                    "normalized_race": normalize_race(raw),
                    "in_tier3_custom": leader_name in TIER3_SET,
                    "status": "in_npc_db_but_no_quest_lines",
                })
            else:
                faction_leaders.append({
                    "race": race,
                    "name": leader_name,
                    "total_lines": 0,
                    "normalized_race": None,
                    "in_tier3_custom": leader_name in TIER3_SET,
                    "status": "NOT_FOUND_IN_DATABASE",
                })

    # ─── Narrator NPCs ──────────────────────────────────────────────
    narrator_npcs = [n for n in all_npcs if n["normalized_race"] == "Narrator"]

    # ─── Quest giver/ender split stats ───────────────────────────────
    total_quests = len(quests)
    total_voice_files = sum(n["total_lines"] for n in all_npcs)
    no_giver = sum(1 for q in quests.values() if not q.get("quest_giver"))
    same_npc = sum(1 for q in quests.values()
                   if q.get("quest_giver") and q.get("quest_ender") and q["quest_giver"] == q["quest_ender"])
    diff_npc = sum(1 for q in quests.values()
                   if q.get("quest_giver") and q.get("quest_ender") and q["quest_giver"] != q["quest_ender"])

    giver_set = set(q.get("quest_giver", "") for q in quests.values() if q.get("quest_giver"))
    ender_set = set(q.get("quest_ender", "") for q in quests.values() if q.get("quest_ender"))
    pure_enders = ender_set - giver_set - {""}

    # Coverage stats
    npcs_resolved = sum(1 for n in all_npcs if n["voice_tier"] != "narrator_fallback")
    npcs_fallback = sum(1 for n in all_npcs if n["voice_tier"] == "narrator_fallback")

    # ─── Normalization Map ───────────────────────────────────────────
    norm_map = {}
    for raw, target in sorted(RACE_NORMALIZATION.items()):
        norm_map.setdefault(target, []).append(raw)

    # ─── Raw Race Quest Counts ───────────────────────────────────────
    raw_counts = defaultdict(int)
    for n in all_npcs:
        raw = n["raw_race"] or "UNKNOWN"
        raw_counts[raw] += n["quest_count"]
    raw_sorted = dict(sorted(raw_counts.items(), key=lambda x: -x[1]))

    # ─── Assemble Report ─────────────────────────────────────────────
    report = {
        "report_description": (
            "TurtleTongue Voice Profile Report. "
            "EVERY quest NPC gets voiced — no exceptions. "
            "The tier system determines which voice PROFILE is used: "
            "Tier 1 = race voice, Tier 2 = creature voice, "
            "Tier 3 = custom unique voice, Narrator = books/objects/animals. "
            "Description text → quest_giver. "
            "Progress + completion text → quest_ender."
        ),
        "summary": {
            "total_quests": total_quests,
            "total_voice_files_needed": total_voice_files,
            "unique_npcs_with_dialogue": len(all_npcs),
            "npcs_with_voice_assignment": npcs_resolved,
            "npcs_narrator_fallback": npcs_fallback,
            "coverage_percent": round(npcs_resolved / max(len(all_npcs), 1) * 100, 1),
            "dialogue_attribution": {
                "note": "description→quest_giver, progress+completion→quest_ender",
                "quests_no_giver": no_giver,
                "quests_same_giver_ender": same_npc,
                "quests_different_giver_ender": diff_npc,
                "pure_ender_npcs_count": len(pure_enders),
                "pure_ender_npcs": sorted(pure_enders),
            },
            "tier_breakdown": {
                "tier1_base_race_profiles": f"{len(tier1)} races x 2 genders = {len(tier1) * 2} voice profiles",
                "tier2_creature_profiles": len(tier2),
                "tier3_custom_voice_npcs": len(TIER3_NAMED_NPCS),
                "narrator": 1,
            },
        },
        "tier1_base_races": tier1,
        "tier2_creature_types": tier2,
        "tier3_named_npcs": {
            "description": (
                f"These {len(TIER3_NAMED_NPCS)} iconic characters get unique custom voice profiles. "
                "All other NPCs use their race/creature type voice profile. "
                "Custom voice profiles require dedicated voice samples."
            ),
            "npcs": tier3,
        },
        "faction_leaders": {
            "description": (
                "One per playable race. Most are also in Tier 3. "
                "High Tinker Mekkatorque is the Gnome faction leader; "
                "he is NOT in Tier 3 custom voice list — uses generic Gnome voice."
            ),
            "leaders": faction_leaders,
        },
        "narrator_and_unknown": {
            "description": "NPCs whose race normalizes to Narrator (animals, novelty, inanimate objects)",
            "npcs": [
                {"name": n["name"], "entry_id": n["entry_id"],
                 "total_lines": n["total_lines"], "raw_race": n["raw_race"]}
                for n in narrator_npcs
            ],
        },
        "narrator_fallback": {
            "description": (
                "NPCs in the NPC database but whose race could not be determined from DBC files. "
                "These will use narrator voice by default. At runtime, UnitRace('npc') may resolve some. "
                "Total: still voiced, not excluded."
            ),
            "count": npcs_fallback,
            "npcs": [
                {"name": n["name"], "entry_id": n["entry_id"],
                 "total_lines": n["total_lines"], "raw_race": n["raw_race"]}
                for n in all_npcs if n["voice_tier"] == "narrator_fallback"
            ],
        },
        "complete_npc_roster": {
            "description": (
                "EVERY NPC that speaks any quest text, sorted by total dialogue lines. "
                "voice_tier shows which voice profile they use. "
                "NO NPC IS EXCLUDED. This is the exhaustive list."
            ),
            "total_count": len(all_npcs),
            "npcs": all_npcs,
        },
        "normalization_map": norm_map,
        "raw_race_quest_counts": raw_sorted,
    }

    out_path = DATA_DIR / "voice_profile_report.json"
    with open(out_path, "w") as f:
        json.dump(report, f, indent=2, ensure_ascii=False)

    print(f"Report written to {out_path}")
    print(f"  Total quests: {total_quests}")
    print(f"  Total voice files needed: {total_voice_files}")
    print(f"  Unique voiced NPCs: {len(all_npcs)}")
    print(f"  Race coverage: {report['summary']['coverage_percent']}%")
    print(f"  Quests with different giver/ender: {diff_npc}")
    print(f"  Pure ender NPCs (never givers): {len(pure_enders)}")
    print()

    print(f"Tier 3 Named NPCs ({len(TIER3_NAMED_NPCS)}):")
    for entry in tier3:
        status = "OK" if entry["status"] == "found" else entry["status"]
        lines = entry["total_lines"]
        race = entry.get("normalized_race") or "?"
        gl = entry.get("giver_lines", 0)
        el = entry.get("ender_lines", 0)
        print(f"  {entry['name']:<35} {lines:>3} lines ({gl}g+{el}e)  [{race}]  {status}")

    print()
    print("Faction Leaders:")
    for fl in faction_leaders:
        t3 = " [TIER3]" if fl["in_tier3_custom"] else " [race voice]"
        print(f"  {fl['race']:<12} {fl['name']:<35} {fl['total_lines']:>3} lines{t3}")

    # Narrator fallback NPCs (race unknown from DBC)
    fallback = [n for n in all_npcs if n["voice_tier"] == "narrator_fallback"]
    if fallback:
        print(f"\nNarrator fallback (race unknown, {len(fallback)} NPCs):")
        for n in fallback[:10]:
            print(f"  {n['name']}: {n['total_lines']} lines")
        if len(fallback) > 10:
            print(f"  ... and {len(fallback) - 10} more")


if __name__ == "__main__":
    main()
