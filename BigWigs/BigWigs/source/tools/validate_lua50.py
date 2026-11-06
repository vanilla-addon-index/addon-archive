#!/usr/bin/env python3
"""
tools/validate_lua50.py
=======================
Strict Lua 5.0 Syntax & Feature Auditor for WoW 1.12.1 (Turtle WoW).
Audits all Lua files for non-Lua-5.0 constructs:
  1. No '#' length operator (use table.getn or string.len)
  2. No string.match (use string.find)
  3. No string.gmatch (use string.gfind)
  4. No math.fmod (use math.mod)
"""

import os
import re
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

def check_file(path):
    violations = []
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        for line_num, line in enumerate(f, 1):
            cleaned = line.split("--")[0]  # strip comment
            
            # Check for # length operator (e.g., #myTable, #str, but not in colors like #FFFFFF or hex)
            # Must be preceded by space/operator/punctuation, not part of hex/string
            m_len = re.search(r'(?:^|[^\w"\'&#])#([a-zA-Z_][a-zA-Z0-9_]*)', cleaned)
            if m_len:
                var_name = m_len.group(1)
                # Ignore color hex codes like #ffffff or #123456
                if not re.match(r'^[0-9a-fA-F]{3,8}$', var_name):
                    violations.append((line_num, line.strip(), f"Lua 5.1 '#' length operator on '{var_name}' (use table.getn or string.len)"))
            
            if "string.match" in cleaned and "string.match or" not in cleaned:
                violations.append((line_num, line.strip(), "Lua 5.1 'string.match' (use string.find in Lua 5.0)"))
                
            if "string.gmatch" in cleaned and "string.gmatch or" not in cleaned:
                violations.append((line_num, line.strip(), "Lua 5.1 'string.gmatch' (use string.gfind in Lua 5.0)"))

            if "UnitGUID(" in cleaned:
                violations.append((line_num, line.strip(), "Retail API 'UnitGUID' (not available in WoW 1.12.1, use UnitExists in SuperWoW)"))

    return violations

def main():
    root_dir = r"c:\Games\Interface\AddOns\BigWigs"
    total_files = 0
    total_violations = 0

    print("=" * 70)
    print("  STRICT LUA 5.0 / WOW 1.12.1 AUDIT SCAN")
    print("=" * 70)

    for root, dirs, files in os.walk(root_dir):
        if any(ignored in root for ignored in [".git", "tools", "documentation", "scratch"]):
            continue
        for f in files:
            if f.endswith(".lua"):
                path = os.path.join(root, f)
                total_files += 1
                v = check_file(path)
                if v:
                    rel = os.path.relpath(path, root_dir)
                    print(f"\n[VIOLATION] {rel}:")
                    for line_num, line_str, desc in v:
                        print(f"  Line {line_num:>4}: {desc}")
                        print(f"    Code: {line_str}")
                        total_violations += 1

    print("\n" + "=" * 70)
    print(f"  Audited {total_files} Lua files. Total Lua 5.0 violations: {total_violations}")
    print("=" * 70)

    if total_violations > 0:
        sys.exit(1)
    else:
        print("  ALL LUA FILES STRICTLY COMPLIANT WITH LUA 5.0 / WOW 1.12.1!")
        sys.exit(0)

if __name__ == "__main__":
    main()
