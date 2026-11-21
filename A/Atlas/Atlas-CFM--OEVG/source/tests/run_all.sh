#!/bin/sh
set -eu

# Run from the repository root with a Lua 5.0 executable on PATH or as argument 1.
lua=${1:-lua5.0}
for mode in default preload profession craft disabled; do
  "$lua" tests/test-atlas-lod.lua . "$mode"
done
"$lua" tests/tooltip_drop_rate.lua
"$lua" tests/test-atlas-dock-timers.lua .
