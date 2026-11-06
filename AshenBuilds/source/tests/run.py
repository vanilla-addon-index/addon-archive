"""Runs the Ashen Builds test suites.

Each tests/test_*.lua suite gets a fresh Lua state with the WoW API stub
(tests/wowstub.lua) and every file from AshenBuilds.toc loaded in order, as the
client would. A suite may have a tests/<name>.pre.lua that runs before the addon
loads. Suites report with check(label, condition).

usage: python tests/run.py [suite-name-substring]      (needs: pip install lupa)
"""
import glob, os, re, sys

from lupa.lua51 import LuaRuntime

TESTS = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.dirname(TESTS)


def toc_files():
    with open(os.path.join(ADDON, "AshenBuilds.toc"), encoding="utf-8") as f:
        return [l.strip().replace("\\", "/") for l in f if l.strip() and not l.startswith("#")]


def read(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read().replace("\r", "")


def run_suite(path):
    name = os.path.basename(path)[:-4]
    lua = LuaRuntime(unpack_returned_tuples=True)
    results = {"pass": 0, "fail": []}

    def check(label, ok):
        if ok:
            results["pass"] += 1
        else:
            results["fail"].append(str(label))
            print("   FAIL", label)

    lua.globals().check = check
    lua.execute(read(os.path.join(TESTS, "wowstub.lua")))
    pre = path[:-4] + ".pre.lua"
    if os.path.exists(pre):
        lua.execute(read(pre))
    for f in toc_files():
        lua.execute(read(os.path.join(ADDON, f)))
    # The client's load sequence.
    lua.execute('FireEvent("ADDON_LOADED", "AshenBuilds")')
    lua.execute('FireEvent("PLAYER_LOGIN")')
    try:
        lua.execute(read(path))
    except Exception as e:  # a crash fails the suite
        results["fail"].append("crashed: %s" % e)
        print("   CRASH", e)
    print("%-28s %3d passed, %d failed" % (name, results["pass"], len(results["fail"])))
    return len(results["fail"]) == 0


def lint():
    """Lua 5.1+ library calls the 1.12 client (Lua 5.0) does not have. Syntax is
    checked separately by compiling with Lua 5.0 in CI."""
    bad = [(r"\bstring\.match\b", "string.match"), (r"\bstring\.gmatch\b", "string.gmatch"),
           (r"(?<![\w.:])select\s*\(", "select()"), (r"\btable\.unpack\b", "table.unpack"),
           (r"\bstring\.rep\s*\([^)]*,[^)]*,", "string.rep with separator"), (r"\bgoto\b", "goto")]
    problems = []
    for f in toc_files():
        code = read(os.path.join(ADDON, f))
        code = re.sub(r"--\[\[.*?\]\]", "", code, flags=re.S)
        code = re.sub(r'"(?:\\.|[^"\\\n])*"', '""', code)
        code = re.sub(r"'(?:\\.|[^'\\\n])*'", "''", code)
        code = re.sub(r"--[^\n]*", "", code)
        for pat, what in bad:
            for m in re.finditer(pat, code):
                problems.append("%s:%d uses %s" % (f, code[:m.start()].count("\n") + 1, what))
    for p in problems:
        print("   LINT", p)
    print("%-28s %s" % ("lua50 library lint", "ok" if not problems else "%d problems" % len(problems)))
    return not problems


def main():
    only = sys.argv[1] if len(sys.argv) > 1 else ""
    ok = lint()
    for path in sorted(glob.glob(os.path.join(TESTS, "test_*.lua"))):
        if only in os.path.basename(path) and not path.endswith(".pre.lua"):
            ok = run_suite(path) and ok
    print("ALL PASSED" if ok else "FAILURES")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
