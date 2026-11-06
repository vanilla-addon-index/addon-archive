#!/usr/bin/env python3
"""
tools/run_tests.py
==================
BigWigs Unified Test & Verification Suite Runner.
Modeled after HolyPriest unified verification runner.

Executes all core static analysis, syntax audits, and combat replay test harnesses:
1. tools/validate_lua50.py              (Strict Lua 5.0 compliance across all modules)
2. tools/check_lua_syntax_problems.py   (Syntax and duplicate key checks)
3. tools/test_ebonroc_sparks.py         (Ebonroc Shadowflame Sparks harness & combat log replay)

Returns exit code 0 if all checks pass, 1 if any check fails.
"""

import os
import subprocess
import sys
import time

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ADDON_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, ".."))

CHECKS = [
    ("Native Lua 5.0.3 Compiler (check_lua50_syntax.py)", [sys.executable, os.path.join(SCRIPT_DIR, "check_lua50_syntax.py")]),
    ("Lua 5.0 Compliance (validate_lua50.py)", [sys.executable, os.path.join(SCRIPT_DIR, "validate_lua50.py")]),
    ("Lua Syntax Audits (check_lua_syntax_problems.py)", [sys.executable, os.path.join(SCRIPT_DIR, "check_lua_syntax_problems.py")]),
    ("Ebonroc Sparks Harness (test_ebonroc_sparks.py)", [sys.executable, os.path.join(SCRIPT_DIR, "test_ebonroc_sparks.py")]),
    ("Axelus Encounter Harness (test_axelus.py)", [sys.executable, os.path.join(SCRIPT_DIR, "test_axelus.py")]),
    ("Ragnaros Encounter Harness (test_ragnaros.py)", [sys.executable, os.path.join(SCRIPT_DIR, "test_ragnaros.py")]),
]

def main():
    print("=" * 80)
    print("BIGWIGS 30147 AUTOMATED VERIFICATION SUITE")
    print("=" * 80)
    
    total_start = time.time()
    all_passed = True
    results = []

    for name, cmd in CHECKS:
        print(f"\n>>> Running {name}...")
        start_t = time.time()
        res = subprocess.run(cmd, cwd=ADDON_ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace", check=False)
        duration = time.time() - start_t
        
        output = (res.stdout or "") + (res.stderr or "")
        lines = [l for l in output.strip().splitlines() if l.strip()]
        for l in lines[-6:]:
            print(f"    {l}")
            
        passed = (res.returncode == 0)
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
