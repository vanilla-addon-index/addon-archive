#!/usr/bin/env python3
"""
tools/analyze_mc_logs.py
========================
Extracts and analyzes Molten Core encounter ability timings from real WoW 1.12.1 combat logs.
Compares real combat intervals with BigWigs Raids/MC/*.lua timer definitions.
"""
import os
import re
import sys
from datetime import datetime

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

LOG_FILES = [
    r"C:\Games\Old Logs\Logs 270826\WoWCombatLog.txt",
    r"C:\Games\Old Logs\Logs\WoWCombatLog.txt",
    r"C:\Games\Old Logs\Logs 190826\WoWCombatLog.txt",
    r"C:\Games\Logs\WoWCombatLog.txt",
]

def parse_time(ts_str):
    # Format: "8/26 21:15:30.123"
    # Assume arbitrary year 2026
    parts = ts_str.split()
    date_part = parts[0]
    time_part = parts[1]
    m, d = [int(x) for x in date_part.split("/")]
    h, mn, s_ms = time_part.split(":")
    s, ms = s_ms.split(".")
    return datetime(2026, m, d, int(h), int(mn), int(s), int(ms) * 1000)

def analyze_boss(log_file, boss_name, ability_patterns):
    """
    ability_patterns: dict of ability_name -> list of regex/substring patterns
    """
    events = {ab: [] for ab in ability_patterns}
    
    with open(log_file, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            m_time = re.match(r"^(\d+/\d+\s+\d+:\d+:\d+\.\d+)\s+(.*)$", line)
            if not m_time:
                continue
            ts_str = m_time.group(1)
            text = m_time.group(2)
            
            for ab, patterns in ability_patterns.items():
                for pat in patterns:
                    if pat in text:
                        t = parse_time(ts_str)
                        events[ab].append((t, ts_str, text))
                        break

    return events

def calc_intervals(events_list, max_gap=120):
    """
    Calculates intervals between unique casts.
    Groups events occurring within 1.5s as a single cast (e.g. AoE hitting multiple raid members).
    max_gap: ignore intervals larger than max_gap (wipe/reset/trash gap)
    """
    if not events_list:
        return []

    # Group close events into unique casts
    unique_casts = []
    for t, ts_str, text in events_list:
        if not unique_casts or (t - unique_casts[-1][0]).total_seconds() > 2.0:
            unique_casts.append((t, ts_str, text))

    intervals = []
    for i in range(1, len(unique_casts)):
        dt = (unique_casts[i][0] - unique_casts[i-1][0]).total_seconds()
        if dt <= max_gap:
            intervals.append((dt, unique_casts[i-1][1], unique_casts[i][1], unique_casts[i][2]))
        else:
            intervals.append((None, unique_casts[i-1][1], unique_casts[i][1], f"--- RESET / PULL GAP ({dt:.1f}s) ---"))
    return unique_casts, intervals

def main():
    print("=" * 76)
    print("  MOLTEN CORE HISTORICAL COMBAT LOG ANALYSIS & TIMER AUDIT")
    print("=" * 76)

    # 1. MAGMADAR: Panic (Fear) & Frenzy
    print("\n" + "#" * 60)
    print("  [1] MAGMADAR: Panic (AoE Fear) & Frenzy")
    print("#" * 60)
    mag_patterns = {
        "Panic": ["afflicted by Panic", "Panic was resisted", "Panic fails", "casts Panic", "begins to cast Panic"],
        "Frenzy": ["Magmadar gains Frenzy", "Magmadar is afflicted by Frenzy"],
        "Lava Bomb": ["afflicted by Lava Bomb"],
    }
    for lf in LOG_FILES:
        if not os.path.exists(lf):
            continue
        events = analyze_boss(lf, "Magmadar", mag_patterns)
        if events["Panic"]:
            print(f"\nLog File: {os.path.basename(os.path.dirname(lf))}\\{os.path.basename(lf)}")
            casts, intervals = calc_intervals(events["Panic"], max_gap=90)
            print(f"  Total Panic Casts Detected: {len(casts)}")
            valid_dts = [iv[0] for iv in intervals if iv[0] is not None]
            for iv in intervals:
                if iv[0] is not None:
                    print(f"    Interval: {iv[0]:>5.2f}s | {iv[1]} -> {iv[2]}")
                else:
                    print(f"    {iv[3]}")
            if valid_dts:
                print(f"  >> Panic Interval Stats: Min={min(valid_dts):.2f}s, Max={max(valid_dts):.2f}s, Mean={sum(valid_dts)/len(valid_dts):.2f}s")
                print(f"  >> BigWigs Magmadar.lua timer: panicCd = 30s")

            frenzy_casts, frenzy_intervals = calc_intervals(events["Frenzy"], max_gap=60)
            print(f"\n  Total Frenzy Casts Detected: {len(frenzy_casts)}")
            f_dts = [iv[0] for iv in frenzy_intervals if iv[0] is not None]
            for iv in frenzy_intervals:
                if iv[0] is not None:
                    print(f"    Interval: {iv[0]:>5.2f}s | {iv[1]} -> {iv[2]}")
                else:
                    print(f"    {iv[3]}")
            if f_dts:
                print(f"  >> Frenzy Interval Stats: Min={min(f_dts):.2f}s, Max={max(f_dts):.2f}s, Mean={sum(f_dts)/len(f_dts):.2f}s")
                print(f"  >> BigWigs Magmadar.lua timer: frenzyCd = {{15, 20}}")

    # 2. LUCIFRON: Curse & Impending Doom
    print("\n" + "#" * 60)
    print("  [2] LUCIFRON: Lucifron's Curse & Impending Doom")
    print("#" * 60)
    luci_patterns = {
        "Curse": ["Lucifron's Curse"],
        "Doom": ["Impending Doom"],
    }
    for lf in LOG_FILES:
        if not os.path.exists(lf):
            continue
        events = analyze_boss(lf, "Lucifron", luci_patterns)
        if events["Curse"]:
            print(f"\nLog File: {os.path.basename(os.path.dirname(lf))}\\{os.path.basename(lf)}")
            casts, intervals = calc_intervals(events["Curse"], max_gap=60)
            print(f"  Total Lucifron's Curse Casts Detected: {len(casts)}")
            valid_dts = [iv[0] for iv in intervals if iv[0] is not None]
            for iv in intervals:
                if iv[0] is not None:
                    print(f"    Interval: {iv[0]:>5.2f}s | {iv[1]} -> {iv[2]}")
                else:
                    print(f"    {iv[3]}")
            if valid_dts:
                print(f"  >> Curse Interval Stats: Min={min(valid_dts):.2f}s, Max={max(valid_dts):.2f}s, Mean={sum(valid_dts)/len(valid_dts):.2f}s")
                print(f"  >> BigWigs Lucifron.lua timer: curseCd = 15s")

            d_casts, d_intervals = calc_intervals(events["Doom"], max_gap=60)
            print(f"\n  Total Impending Doom Casts Detected: {len(d_casts)}")
            valid_d = [iv[0] for iv in d_intervals if iv[0] is not None]
            for iv in d_intervals:
                if iv[0] is not None:
                    print(f"    Interval: {iv[0]:>5.2f}s | {iv[1]} -> {iv[2]}")
                else:
                    print(f"    {iv[3]}")
            if valid_d:
                print(f"  >> Doom Interval Stats: Min={min(valid_d):.2f}s, Max={max(valid_d):.2f}s, Mean={sum(valid_d)/len(valid_d):.2f}s")
                print(f"  >> BigWigs Lucifron.lua timer: impendingDoomCd = 10s")

    # 3. BARON GEDDON: Inferno & Ignite Mana
    print("\n" + "#" * 60)
    print("  [3] BARON GEDDON: Inferno & Living Bomb & Ignite Mana")
    print("#" * 60)
    geddon_patterns = {
        "Inferno": ["Baron Geddon gains Inferno", "Baron Geddon's Inferno"],
        "Bomb": ["afflicted by Living Bomb"],
        "Ignite Mana": ["afflicted by Ignite Mana"],
    }
    for lf in LOG_FILES:
        if not os.path.exists(lf):
            continue
        events = analyze_boss(lf, "Geddon", geddon_patterns)
        if events["Inferno"]:
            print(f"\nLog File: {os.path.basename(os.path.dirname(lf))}\\{os.path.basename(lf)}")
            casts, intervals = calc_intervals(events["Inferno"], max_gap=90)
            print(f"  Total Inferno Casts Detected: {len(casts)}")
            valid_dts = [iv[0] for iv in intervals if iv[0] is not None]
            for iv in intervals:
                if iv[0] is not None:
                    print(f"    Interval: {iv[0]:>5.2f}s | {iv[1]} -> {iv[2]}")
                else:
                    print(f"    {iv[3]}")
            if valid_dts:
                print(f"  >> Inferno Interval Stats: Min={min(valid_dts):.2f}s, Max={max(valid_dts):.2f}s, Mean={sum(valid_dts)/len(valid_dts):.2f}s")
                print(f"  >> BigWigs BaronGeddon.lua timer: infernoFirstCd = 18s")

            b_casts, b_intervals = calc_intervals(events["Bomb"], max_gap=60)
            print(f"\n  Total Living Bomb Casts Detected: {len(b_casts)}")
            valid_b = [iv[0] for iv in b_intervals if iv[0] is not None]
            for iv in b_intervals:
                if iv[0] is not None:
                    print(f"    Interval: {iv[0]:>5.2f}s | {iv[1]} -> {iv[2]}")
            if valid_b:
                print(f"  >> Living Bomb Interval Stats: Min={min(valid_b):.2f}s, Max={max(valid_b):.2f}s, Mean={sum(valid_b)/len(valid_b):.2f}s")

            im_casts, im_intervals = calc_intervals(events["Ignite Mana"], max_gap=60)
            print(f"\n  Total Ignite Mana Casts Detected: {len(im_casts)}")
            valid_im = [iv[0] for iv in im_intervals if iv[0] is not None]
            for iv in im_intervals:
                if iv[0] is not None:
                    print(f"    Interval: {iv[0]:>5.2f}s | {iv[1]} -> {iv[2]}")
            if valid_im:
                print(f"  >> Ignite Mana Interval Stats: Min={min(valid_im):.2f}s, Max={max(valid_im):.2f}s, Mean={sum(valid_im)/len(valid_im):.2f}s")

    # 4. SHAZZRAH: Blink (Gate of Shazzrah), Counterspell, Curse, Deaden Magic
    print("\n" + "#" * 60)
    print("  [4] SHAZZRAH: Gate of Shazzrah (Blink), Counterspell, Curse")
    print("#" * 60)
    shazz_patterns = {
        "Blink": ["Gate of Shazzrah", "casts Blink"],
        "Counterspell": ["Shazzrah's Counterspell"],
        "Curse": ["Shazzrah's Curse"],
        "Deaden": ["Deaden Magic"],
    }
    for lf in LOG_FILES:
        if not os.path.exists(lf):
            continue
        events = analyze_boss(lf, "Shazzrah", shazz_patterns)
        if events["Counterspell"] or events["Blink"]:
            print(f"\nLog File: {os.path.basename(os.path.dirname(lf))}\\{os.path.basename(lf)}")
            for ab_name in ["Blink", "Counterspell", "Curse", "Deaden"]:
                c_list, iv_list = calc_intervals(events[ab_name], max_gap=60)
                print(f"\n  Total {ab_name} Casts Detected: {len(c_list)}")
                valid_dt = [iv[0] for iv in iv_list if iv[0] is not None]
                for iv in iv_list:
                    if iv[0] is not None:
                        print(f"    Interval: {iv[0]:>5.2f}s | {iv[1]} -> {iv[2]}")
                    else:
                        print(f"    {iv[3]}")
                if valid_dt:
                    print(f"  >> {ab_name} Stats: Min={min(valid_dt):.2f}s, Max={max(valid_dt):.2f}s, Mean={sum(valid_dt)/len(valid_dt):.2f}s")

    # 5. MAJORDOMO EXECUTUS: Reflection / Damage Shield
    print("\n" + "#" * 60)
    print("  [5] MAJORDOMO EXECUTUS: Damage Shield & Magic Reflection")
    print("#" * 60)
    domo_patterns = {
        "Shield": ["gains Damage Shield", "afflicted by Damage Shield"],
        "Reflect": ["gains Magic Reflection", "afflicted by Magic Reflection"],
    }
    for lf in LOG_FILES:
        if not os.path.exists(lf):
            continue
        events = analyze_boss(lf, "Majordomo", domo_patterns)
        if events["Shield"] or events["Reflect"]:
            print(f"\nLog File: {os.path.basename(os.path.dirname(lf))}\\{os.path.basename(lf)}")
            all_shields = events["Shield"] + events["Reflect"]
            all_shields.sort(key=lambda x: x[0])
            c_list, iv_list = calc_intervals(all_shields, max_gap=60)
            print(f"  Total Shield / Reflection Rotations: {len(c_list)}")
            valid_dt = [iv[0] for iv in iv_list if iv[0] is not None]
            for iv in iv_list:
                if iv[0] is not None:
                    print(f"    Interval: {iv[0]:>5.2f}s | {iv[1]} -> {iv[2]}")
                else:
                    print(f"    {iv[3]}")
            if valid_dt:
                print(f"  >> Shield/Reflect Interval Stats: Min={min(valid_dt):.2f}s, Max={max(valid_dt):.2f}s, Mean={sum(valid_dt)/len(valid_dt):.2f}s")
                print(f"  >> BigWigs Majordomo.lua timer: reflectCd = 20s, reflectDur = 10s")

    # 6. RAGNAROS: Wrath of Ragnaros (Knockback) & Submerge
    print("\n" + "#" * 60)
    print("  [6] RAGNAROS: Wrath of Ragnaros (Knockback)")
    print("#" * 60)
    rag_patterns = {
        "Knockback": ["Wrath of Ragnaros", "TASTE THE FLAMES OF SULFURON"],
        "Submerge": ["COME FORTH, MY SERVANTS", "Submerge"],
    }
    for lf in LOG_FILES:
        if not os.path.exists(lf):
            continue
        events = analyze_boss(lf, "Ragnaros", rag_patterns)
        if events["Knockback"]:
            print(f"\nLog File: {os.path.basename(os.path.dirname(lf))}\\{os.path.basename(lf)}")
            c_list, iv_list = calc_intervals(events["Knockback"], max_gap=60)
            print(f"  Total Wrath of Ragnaros Casts: {len(c_list)}")
            valid_dt = [iv[0] for iv in iv_list if iv[0] is not None]
            for iv in iv_list:
                if iv[0] is not None:
                    print(f"    Interval: {iv[0]:>5.2f}s | {iv[1]} -> {iv[2]}")
                else:
                    print(f"    {iv[3]}")
            if valid_dt:
                print(f"  >> Knockback Stats: Min={min(valid_dt):.2f}s, Max={max(valid_dt):.2f}s, Mean={sum(valid_dt)/len(valid_dt):.2f}s")
                print(f"  >> BigWigs Ragnaros.lua timer: knockbackCd = 25s")

    # 7. GARR: Antimagic Pulse
    print("\n" + "#" * 60)
    print("  [7] GARR: Antimagic Pulse")
    print("#" * 60)
    garr_patterns = {
        "Pulse": ["casts Antimagic Pulse", "Antimagic Pulse was resisted", "afflicted by Antimagic Pulse"],
    }
    for lf in LOG_FILES:
        if not os.path.exists(lf):
            continue
        events = analyze_boss(lf, "Garr", garr_patterns)
        if events["Pulse"]:
            print(f"\nLog File: {os.path.basename(os.path.dirname(lf))}\\{os.path.basename(lf)}")
            c_list, iv_list = calc_intervals(events["Pulse"], max_gap=45)
            print(f"  Total Antimagic Pulse Casts: {len(c_list)}")
            valid_dt = [iv[0] for iv in iv_list if iv[0] is not None]
            for iv in iv_list:
                if iv[0] is not None:
                    print(f"    Interval: {iv[0]:>5.2f}s | {iv[1]} -> {iv[2]}")
                else:
                    print(f"    {iv[3]}")
            if valid_dt:
                print(f"  >> Pulse Stats: Min={min(valid_dt):.2f}s, Max={max(valid_dt):.2f}s, Mean={sum(valid_dt)/len(valid_dt):.2f}s")
                print(f"  >> BigWigs Garr.lua timer: antimagicPulse = 20s")

    # 8. SULFURON HARBINGER: Hand of Ragnaros & Inspire
    print("\n" + "#" * 60)
    print("  [8] SULFURON HARBINGER: Hand of Ragnaros & Inspire")
    print("#" * 60)
    sulf_patterns = {
        "Hand of Ragnaros": ["Hand of Ragnaros"],
        "Inspire": ["gains Inspire", "afflicted by Inspire"],
        "Dark Mending": ["Dark Mending"],
    }
    for lf in LOG_FILES:
        if not os.path.exists(lf):
            continue
        events = analyze_boss(lf, "Sulfuron", sulf_patterns)
        if events["Hand of Ragnaros"]:
            print(f"\nLog File: {os.path.basename(os.path.dirname(lf))}\\{os.path.basename(lf)}")
            c_list, iv_list = calc_intervals(events["Hand of Ragnaros"], max_gap=45)
            print(f"  Total Hand of Ragnaros Casts: {len(c_list)}")
            valid_dt = [iv[0] for iv in iv_list if iv[0] is not None]
            for iv in iv_list:
                if iv[0] is not None:
                    print(f"    Interval: {iv[0]:>5.2f}s | {iv[1]} -> {iv[2]}")
                else:
                    print(f"    {iv[3]}")
            if valid_dt:
                print(f"  >> Hand of Ragnaros Stats: Min={min(valid_dt):.2f}s, Max={max(valid_dt):.2f}s, Mean={sum(valid_dt)/len(valid_dt):.2f}s")
                print(f"  >> BigWigs Sulfuron.lua timer: handOfRagnarosDur = 2s, handOfRagnarosCd = 10s (Base cycle 12s)")

    # 9. INCINDIS (Turtle WoW Custom MC Boss)
    print("\n" + "#" * 60)
    print("  [9] INCINDIS: Quaking Stomp -> Fire Nova")
    print("#" * 60)
    incindis_patterns = {
        "Quaking Stomp": ["Quaking Stomp"],
        "Fire Nova": ["Incindis's Fire Nova", "Fire Nova"],
    }
    for lf in LOG_FILES:
        if not os.path.exists(lf):
            continue
        events = analyze_boss(lf, "Incindis", incindis_patterns)
        if events["Quaking Stomp"]:
            print(f"\nLog File: {os.path.basename(os.path.dirname(lf))}\\{os.path.basename(lf)}")
            qs_casts, _ = calc_intervals(events["Quaking Stomp"], max_gap=60)
            fn_casts, _ = calc_intervals(events["Fire Nova"], max_gap=60)
            print(f"  Quaking Stomp events: {len(qs_casts)}, Fire Nova events: {len(fn_casts)}")
            # Correlate Quaking Stomp -> Next Fire Nova
            for qs_t, qs_ts, _ in qs_casts:
                for fn_t, fn_ts, _ in fn_casts:
                    diff = (fn_t - qs_t).total_seconds()
                    if 0 < diff < 15:
                        print(f"    Stomp at {qs_ts} -> Fire Nova at {fn_ts} (Delay: {diff:.3f}s)")
                        break
            print(f"  >> BigWigs Incindis.lua timer: timer.fireNova = 5.5s")

    # 10. TWIN GOLEMS (Turtle WoW Custom MC Boss)
    print("\n" + "#" * 60)
    print("  [10] TWIN GOLEMS: Molten Bulwark")
    print("#" * 60)
    twin_patterns = {
        "Bulwark Gain": ["gains Molten Bulwark"],
        "Bulwark Fade": ["Molten Bulwark fades"],
    }
    for lf in LOG_FILES:
        if not os.path.exists(lf):
            continue
        events = analyze_boss(lf, "Twin Golems", twin_patterns)
        if events["Bulwark Gain"]:
            print(f"\nLog File: {os.path.basename(os.path.dirname(lf))}\\{os.path.basename(lf)}")
            gains, _ = calc_intervals(events["Bulwark Gain"], max_gap=60)
            fades, _ = calc_intervals(events["Bulwark Fade"], max_gap=60)
            for g_t, g_ts, _ in gains:
                for f_t, f_ts, _ in fades:
                    diff = (f_t - g_t).total_seconds()
                    if 0 < diff < 30:
                        print(f"    Bulwark Gained: {g_ts} -> Faded: {f_ts} (Duration: {diff:.3f}s)")
                        break
            print(f"  >> BigWigs TwinGolems.lua timer: timer.bulwark = 15s")

    # 11. SORCERER-THANE THAURISSAN (Turtle WoW Custom MC Boss)
    print("\n" + "#" * 60)
    print("  [11] SORCERER-THANE THAURISSAN: Rune of Combustion")
    print("#" * 60)
    thaur_patterns = {
        "Rune Gain": ["afflicted by Rune of Combustion"],
        "Rune Fade": ["Rune of Combustion fades"],
    }
    for lf in LOG_FILES:
        if not os.path.exists(lf):
            continue
        events = analyze_boss(lf, "Thaurissan", thaur_patterns)
        if events["Rune Gain"]:
            print(f"\nLog File: {os.path.basename(os.path.dirname(lf))}\\{os.path.basename(lf)}")
            gains, _ = calc_intervals(events["Rune Gain"], max_gap=60)
            fades, _ = calc_intervals(events["Rune Fade"], max_gap=60)
            for g_t, g_ts, _ in gains:
                for f_t, f_ts, _ in fades:
                    diff = (f_t - g_t).total_seconds()
                    if 0 < diff < 20:
                        print(f"    Rune Afflicted: {g_ts} -> Faded: {f_ts} (Duration: {diff:.3f}s)")
                        break
            print(f"  >> BigWigs Thaurissan.lua timer: timer.runeDuration = 6s")

if __name__ == "__main__":
    main()
