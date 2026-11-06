#!/usr/bin/env python3
"""Run the portable mock-Lua regression suite from the repository root."""
from pathlib import Path
import shutil
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
candidates = [sys.argv[1]] if len(sys.argv) > 1 else ["lua", "lua5.1", "lua5.4", "texlua"]
lua = next((shutil.which(c) for c in candidates if shutil.which(c)), None)
if not lua:
    print("Lua interpreter not found (try: python tests/run_tests.py /path/to/lua)")
    sys.exit(2)
files = sorted((root / "tests").glob("*.lua"))
failures = []
for file in files:
    res = subprocess.run([lua, str(file)], cwd=root, capture_output=True, text=True)
    status = "PASS" if res.returncode == 0 else "FAIL"
    print(status, file.name)
    if res.returncode:
        failures.append(file.name)
        print((res.stdout + res.stderr).strip())
print(f"Passed: {len(files)-len(failures)}/{len(files)}")
sys.exit(1 if failures else 0)
