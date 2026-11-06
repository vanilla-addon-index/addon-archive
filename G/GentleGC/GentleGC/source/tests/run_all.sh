#!/bin/sh
# Runs every test against GentleGC.lua. Usage: tests/run_all.sh [lua-binary]
# Run from the repository root. Default interpreter is lua5.0.
LUA="${1:-lua5.0}"
fail=0
for t in tests/test_*.lua; do
  echo "== $t"
  case "$t" in
    *test_memory.lua) "$LUA" "$t" GentleGC.lua "!!!!GentleGC_Memory/GentleGC_Memory.lua" || fail=1 ;;
    *) "$LUA" "$t" GentleGC.lua || fail=1 ;;
  esac
done
exit $fail
