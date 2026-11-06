#!/usr/bin/env python3
"""Read the talent trees `/apg talents` saved into Tools/data/turtle_talent_trees.json.

`/apg talents` (Extras.lua) saves a character's class trees, as the game has
them, into the account's saved settings: each talent's tier, column, ranks,
prerequisites and tooltip. Run once on a character of each class, the file
holds all nine. This takes them out of that file -- WTF/Account/<account>/
SavedVariables/Aegis_Pathfinder.lua -- with lua5.1, and writes them as JSON
for the talent builds to be checked against (talent_builds.py).

The game writes a tooltip's line break as a bare carriage return before an
escaped newline, which Lua reads as an unfinished string; carriage returns are
dropped before it is read.

  python3 Tools/build/read_talent_trees.py PATH/TO/Aegis_Pathfinder.lua
"""

import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "Tools", "data", "turtle_talent_trees.json")

# Lua that prints AegisPathfinderDB.account.talenttrees as JSON.
DUMP = r"""
dofile(arg[1])
local trees = AegisPathfinderDB and AegisPathfinderDB.account and AegisPathfinderDB.account.talenttrees
if not trees then io.stderr:write("no talent trees in the file: run /apg talents first\n") os.exit(1) end
local function str(s)
	s = string.gsub(s, "\\", "\\\\")
	s = string.gsub(s, '"', '\\"')
	s = string.gsub(s, "\n", "\\n")
	s = string.gsub(s, "\t", " ")
	return '"' .. s .. '"'
end
local function enc(v)
	local t = type(v)
	if t == "string" then return str(v) end
	if t ~= "table" then return tostring(v) end
	local n, count = #v, 0
	for _ in pairs(v) do count = count + 1 end
	local parts = {}
	if count == n then
		for _, x in ipairs(v) do table.insert(parts, enc(x)) end
		return "[" .. table.concat(parts, ",") .. "]"
	end
	local keys = {}
	for k in pairs(v) do table.insert(keys, k) end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	for _, k in ipairs(keys) do table.insert(parts, str(tostring(k)) .. ":" .. enc(v[k])) end
	return "{" .. table.concat(parts, ",") .. "}"
end
io.write(enc(trees))
"""


def read(path):
    with open(path, "rb") as fh:
        raw = fh.read().replace(b"\r\n", b"\n").replace(b"\r", b"")
    with tempfile.TemporaryDirectory() as tmp:
        clean = os.path.join(tmp, "saved.lua")
        script = os.path.join(tmp, "dump.lua")
        with open(clean, "wb") as fh:
            fh.write(raw)
        with open(script, "w") as fh:
            fh.write(DUMP)
        out = subprocess.run(["lua5.1", script, clean], capture_output=True, text=True)
    if out.returncode != 0:
        sys.exit(out.stderr.strip() or "lua5.1 could not read %s" % path)
    return json.loads(out.stdout)


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    trees = read(sys.argv[1])
    with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(trees, fh, indent=1, sort_keys=True)
    for cls in sorted(trees):
        t = trees[cls]
        print("%-8s %s: %s" % (cls, t.get("saved"), ", ".join(
            "%s %d" % (tree["name"], len(tree["talents"])) for tree in t["trees"])))
    print("wrote %s: %d classes" % (os.path.relpath(OUT, ROOT), len(trees)))


if __name__ == "__main__":
    main()
