#!/usr/bin/env python3
"""
tools/run_tests.py
==================
TurtleCalendar Automated Verification Suite Runner.

Executes static analysis, strict Lua 5.0 compatibility, and AST global scope leak detection:
  1. tools/validate_lua50.py    (Strict Lua 5.0 syntax & operator compliance)
  2. tools/scan_global_leaks.py (AST lexical scope and global variable leak detection)

Returns exit code 0 if all checks pass, 1 if any check fails.
"""

import os
import sys
import subprocess
import time

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ADDON_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, ".."))

LUA50_BIN = os.path.join(SCRIPT_DIR, "bin", "lua50", "lua50.exe")

CHECKS = [
    ("Native Lua 5.0.3 Compiler (check_lua50_syntax.py)", [sys.executable, os.path.join(SCRIPT_DIR, "check_lua50_syntax.py")]),
    ("Lua 5.0 Compliance (validate_lua50.py)", [sys.executable, os.path.join(SCRIPT_DIR, "validate_lua50.py")]),
    ("Global Scope Leaks (scan_global_leaks.py)", [sys.executable, os.path.join(SCRIPT_DIR, "scan_global_leaks.py")]),
    ("World Bosses Live Runtime (test_world_bosses.lua)", [LUA50_BIN, os.path.join(SCRIPT_DIR, "test_world_bosses.lua")]),
]

GLOBAL_AUDITOR = os.path.expanduser("~/.gemini/config/skills/wow-addon-auditor/scripts/audit_addon.py")
if os.path.exists(GLOBAL_AUDITOR):
    CHECKS.append(("AddOn Auditor & Engine Resilience (global wow-addon-auditor)", [sys.executable, GLOBAL_AUDITOR, ADDON_ROOT]))

def main():
    print("=" * 80)
    print("TURTLECALENDAR AUTOMATED VERIFICATION SUITE")
    print("=" * 80)

    total_start = time.time()
    all_passed = True
    results = []

    for name, cmd in CHECKS:
        print(f"\n>>> Running {name}...")
        start_t = time.time()
        res = subprocess.run(cmd, cwd=ADDON_ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
        duration = time.time() - start_t

        output = (res.stdout or "") + (res.stderr or "")
        lines = [l for l in output.strip().splitlines() if l.strip()]
        for l in lines[-6:]:
            print(f"    {l}")

        passed = (res.returncode == 0) and ("VIOLATIONS FOUND" not in output) and ("SCOPE LEAKS FOUND" not in output)
        if not passed:
            all_passed = False
            results.append((name, "FAIL", duration))
            print(f"    --> [FAIL] Exit code: {res.returncode}")
        else:
            results.append((name, "PASS", duration))
            print(f"    --> [PASS] ({duration:.2f}s)")

    print("\n" + "=" * 80)
    print("SUITE EXECUTION SUMMARY")
    print("=" * 80)
    for name, status, duration in results:
        indicator = "[PASS]" if status == "PASS" else "[FAIL]"
        print(f"  {indicator:<8} {name:<48} ({duration:.2f}s)")

    total_time = time.time() - total_start
    print("-" * 80)
    if all_passed:
        print(f"OVERALL RESULT: ALL {len(CHECKS)} CHECKS PASSED (Total time: {total_time:.2f}s)")
        print("=" * 80)
        sys.exit(0)
    else:
        print(f"OVERALL RESULT: VERIFICATION FAILED (Total time: {total_time:.2f}s)")
        print("=" * 80)
        sys.exit(1)

if __name__ == "__main__":
    main()
