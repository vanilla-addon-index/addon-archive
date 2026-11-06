#!/usr/bin/env python3
"""Take OctoPawn's stat patterns, soft caps, labels and weights into
Tools/data/octopawn.json, and write ItemScoreData.lua from it.

    python3 Tools/build/import_octopawn.py <path to an OctoPawn checkout>

OctoPawn (https://github.com/iGreed1993/OctoPawn, MIT, (c) 2026 iGreed) scores
1.12 items from their tooltips, with weights for every class and spec. Its
defaults are Lua built by a few helpers (OctoPawn_MeleeDPS, OctoPawn_Tank,
...), so they are evaluated with lua5.1 rather than parsed, and written out
as plain tables: the weights (zeros dropped), the tooltip patterns in
OctoPawn's order -- the order matters, the first match on a line wins over
the general ones after it -- its soft caps, and its stat labels.

Only the data is taken. The scoring in ItemScore.lua is this addon's own, and
so are the weights it scores with (build_weights.py): OctoPawn's are kept as
the starting point for the stats that model does not work out -- Turtle
WoW's own, resistances, speed.

Weapon skills (+Swords, +Daggers, ...) are left out, on the owner's call: the
item score is Zygor's shape, which has none, and they were rows of near-zero
weights for most specs.
"""

import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CACHE = os.path.join(ROOT, "Tools", "data", "octopawn.json")

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_weights  # noqa: E402

DUMP = r"""
local dir = arg[1]
defaultWeights = {}
print = function() end
-- OctoPawn's files touch the WoW API as they load; anything missing is a
-- do-nothing function here, since only their tables are wanted.
local noop = function() return nil end
setmetatable(_G, { __index = function() return noop end })
dofile(dir .. "/Defaults/Helpers.lua")
local toc = io.open(dir .. "/OctoPawn.toc"):read("*a")
for path in string.gfind(toc, "Defaults\\([%w\\]+)%.lua") do
	if path ~= "Helpers" then dofile(dir .. "/Defaults/" .. string.gsub(path, "\\", "/") .. ".lua") end
end
dofile(dir .. "/Scoring/ScoringStats.lua")
local function q(s) return string.format("%q", s) end
local out = {}
-- weights
table.insert(out, "W")
for class, specs in pairs(defaultWeights) do
	for spec, w in pairs(specs) do
		if type(w) == "table" then
			for stat, v in pairs(w) do
				table.insert(out, "w\t" .. class .. "\t" .. spec .. "\t" .. stat .. "\t" .. string.format("%.4f", v))
			end
		end
	end
end
for i, e in ipairs(OctoPawn_StatPatterns) do
	table.insert(out, "p\t" .. i .. "\t" .. e.pattern .. "\t" .. e.stat)
end
local stats = {}
for stat in pairs(defaultWeights.WARRIOR.Arms) do table.insert(stats, stat) end
for _, stat in ipairs(stats) do
	table.insert(out, "l\t" .. stat .. "\t" .. OctoPawn_StatLabel(stat))
end
io.write(table.concat(out, "\n"))
"""

# Left out of the item score: the weapon skills.
EXCLUDED = {"SWORDS", "AXES", "MACES", "DAGGERS", "FIST WEAPONS", "POLEARMS", "STAVES",
            "BOWS", "GUNS", "CROSSBOWS", "THROWN", "WANDS"}


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        return 1
    src = sys.argv[1]
    with open(os.path.join(ROOT, "Tools", ".octopawn_dump.lua"), "w") as fh:
        fh.write(DUMP)
    try:
        raw = subprocess.run(["lua5.1", os.path.join(ROOT, "Tools", ".octopawn_dump.lua"), src],
                             check=True, capture_output=True, text=True).stdout
    finally:
        os.remove(os.path.join(ROOT, "Tools", ".octopawn_dump.lua"))

    weights, patterns, caps, labels = {}, [], {}, {}
    for line in raw.split("\n"):
        f = line.split("\t")
        if (f[0] in ("w",) and f[3] in EXCLUDED) or (f[0] == "p" and f[3] in EXCLUDED) \
                or (f[0] == "l" and f[1] in EXCLUDED):
            continue
        if f[0] == "w" and float(f[4]) != 0:
            weights.setdefault(f[1], {}).setdefault(f[2], {})[f[3]] = f[4]
        elif f[0] == "p":
            patterns.append((int(f[1]), f[2], f[3]))
        elif f[0] == "d":
            caps[f[1]] = (f[2], f[3])
        elif f[0] == "l":
            labels[f[1]] = f[2]
    patterns.sort()
    # The soft caps are a local table in ScoringCore.lua, which does too much
    # at load to run here; the table itself is plain.
    with open(os.path.join(src, "Scoring", "ScoringCore.lua"), encoding="utf-8") as fh:
        core = fh.read()
    block = re.search(r"local DEFAULT_DR = \{(.*?)\n\}", core, re.S).group(1)
    for m in re.finditer(r'(?:\["([^"]+)"\]|(\w+))\s*=\s*\{\s*softCap\s*=\s*([\d.]+),\s*postScale\s*=\s*([\d.]+)\s*\}', block):
        caps[m.group(1) or m.group(2)] = (m.group(3), m.group(4))
    with open(os.path.join(src, "LICENSE"), encoding="utf-8") as fh:
        licence = fh.read().strip()

    data = {
        "licence": licence,
        "weights": {c: {s: {k: float(v) for k, v in w.items()} for s, w in specs.items()}
                    for c, specs in weights.items()},
        "patterns": [[pat, stat] for _, pat, stat in patterns],
        "softcaps": {k: [float(a), float(b)] for k, (a, b) in caps.items()},
        "labels": labels,
    }
    with open(CACHE, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=1, sort_keys=True)
        fh.write("\n")
    n = sum(len(v) for v in weights.values())
    print("wrote %s: %d classes, %d specs, %d stats, %d patterns, %d soft caps"
          % (os.path.relpath(CACHE, ROOT), len(weights), n, len(labels), len(patterns), len(caps)))
    # ItemScoreData.lua is written from it, with this addon's weights.
    build_weights.write_data()
    return 0


if __name__ == "__main__":
    sys.exit(main())
