#!/usr/bin/env python3
"""
tools/validate_lua50.py
=======================
Strict Lua 5.0 and WoW 1.12.1 compatibility validator.
Enforces all rules specified in AGENTS.md:
  1. No table length operator '#'
  2. No modulo operator '%' (outside string literals/formats)
  3. No integer division operator '//'
  4. No 'goto' statements or '::label::'
  5. No 'string.match' or 'string.gmatch' (use string.find / string.gfind)
  6. No 'table.unpack' or 'table.pack'
  7. No 'math.huge'
  8. No modern 'C_*' namespaces or direct ':HookScript' frame hooks
"""

import os
import re
import sys

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ADDON_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, ".."))

# Addon modules authored for TurtleCalendar (checked for both Lua 5.0 & WoW 1.12 API constraints)
ADDON_FILES = [
    "TurtleCalendar.lua",
    "WorldBosses.lua",
    "WorldBuffs.lua",
    "MinimapIcon.lua",
    "translations/enUS.lua",
    "translations/esES.lua",
    "translations/zhCN.lua",
    "translations/zhTW.lua",
]

# Embedded third-party compatibility libraries (checked for Lua 5.0 VM syntax compatibility)
LIB_FILES = [
    "libs/LibStub/LibStub.lua",
    "libs/AceCore-3.0/AceCore-3.0.lua",
    "libs/AceHook-3.0/AceHook-3.0.lua",
    "libs/CallbackHandler-1.0/CallbackHandler-1.0.lua",
    "libs/LibDataBroker-1-1/LibDataBroker-1.1.lua",
    "libs/LibDBIcon-1.0/LibDBIcon-1.0.lua",
]

SYNTAX_RULES = [
    (r"(?<![a-zA-Z0-9_])#[a-zA-Z0-9_\(\{]", "Table length operator '#' is banned (use getn/table.getn)"),
    (r"(?<![a-zA-Z0-9_])%[ \t]*[a-zA-Z0-9_\(]", "Modulo operator '%' is banned (use math.mod / mod)"),
    (r"//", "Integer division '//' is banned (use math.floor(a / b))"),
    (r"\bgoto\b", "'goto' statement is banned in Lua 5.0"),
    (r"::[a-zA-Z0-9_]+::", "Goto label marker '::label::' is banned in Lua 5.0"),
    (r"string\.match\b", "'string.match' is banned (use string.find with captures)"),
    (r"string\.gmatch\b", "'string.gmatch' is banned (use string.gfind)"),
    (r"table\.unpack\b", "'table.unpack' is banned (use global unpack)"),
    (r"table\.pack\b", "'table.pack' is banned"),
    (r"math\.huge\b", "'math.huge' is banned (use 1/0 or 99999999)"),
]

API_RULES = [
    (r"\bC_[A-Za-z0-9_]+\.", "Modern 'C_*' namespace is banned in WoW 1.12.1"),
    (r"(?<!AceHook):HookScript\b", "Frame ':HookScript' is banned in WoW 1.12.1 (use classic function detour)"),
]

def strip_line(line: str) -> str:
    """Strip comments and string literals from a single line."""
    code = re.sub(r"--.*$", "", line)
    code = re.sub(r'"(\\.|[^"\\])*"', '""', code)
    code = re.sub(r"'(\\.|[^'\\])*'", "''", code)
    return code

def validate_file(rel_path: str, check_api: bool = True) -> list:
    full_path = os.path.join(ADDON_ROOT, rel_path)
    if not os.path.isfile(full_path):
        return [f"File not found: {rel_path}"]

    with open(full_path, "r", encoding="utf-8", errors="replace") as f:
        lines = f.readlines()

    errors = []
    in_block_comment = False

    rules = SYNTAX_RULES + (API_RULES if check_api else [])

    for idx, raw_line in enumerate(lines, 1):
        line = raw_line.strip()

        # Handle multi-line block comments --[[ ... ]]
        if in_block_comment:
            if "]]" in line:
                line = re.sub(r"^.*?\]\]", "", line)
                in_block_comment = False
            else:
                continue

        if "--[[" in line:
            if "]]" in line:
                line = re.sub(r"--\[\[.*?\]\]", "", line)
            else:
                line = re.sub(r"--\[\[.*$", "", line)
                in_block_comment = True

        sanitized = strip_line(line)
        if not sanitized.strip():
            continue

        for pattern, desc in rules:
            if re.search(pattern, sanitized):
                errors.append(f"{rel_path}:{idx}: [FAIL] {desc} -> {raw_line.strip()}")

    return errors

def main():
    print("=" * 70)
    print("TURTLECALENDAR: STRICT LUA 5.0 & WOW 1.12 COMPLIANCE VALIDATOR")
    print("=" * 70)

    total_errors = 0
    checked_count = 0

    print(">>> Checking Addon Core Modules & Locales:")
    for rel in ADDON_FILES:
        errs = validate_file(rel, check_api=True)
        checked_count += 1
        if errs:
            for e in errs:
                print(f"  {e}")
            total_errors += len(errs)
        else:
            print(f"  [PASS] {rel}")

    print("\n>>> Checking Embedded Compatibility Libraries (Lua 5.0 VM Syntax):")
    for rel in LIB_FILES:
        errs = validate_file(rel, check_api=False)
        checked_count += 1
        if errs:
            for e in errs:
                print(f"  {e}")
            total_errors += len(errs)
        else:
            print(f"  [PASS] {rel}")

    print("-" * 70)
    if total_errors == 0:
        print(f"RESULT: ALL {checked_count} FILES STRICTLY COMPLIANT WITH LUA 5.0 / WOW 1.12")
        print("=" * 70)
        sys.exit(0)
    else:
        print(f"RESULT: {total_errors} VIOLATIONS FOUND")
        print("=" * 70)
        sys.exit(1)

if __name__ == "__main__":
    main()
