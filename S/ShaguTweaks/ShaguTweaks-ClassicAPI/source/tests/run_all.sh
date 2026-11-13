#!/bin/sh
# Run from the addon root: sh tests/run_all.sh [lua5.0-binary]
LUA="${1:-lua5.0}"
if [ ! -f ShaguTweaks.toc ] || [ ! -f tests/test_classicapi_runtime.lua ]; then
  printf '%s\n' 'Run this script from the ShaguTweaks addon root.' >&2
  exit 2
fi
if ! command -v "$LUA" >/dev/null 2>&1; then
  printf 'Lua interpreter not found: %s\n' "$LUA" >&2
  exit 127
fi
total=0
failed=0
for test in tests/test_*.lua; do
  [ -f "$test" ] || continue
  total=$((total + 1))
  printf '\n== %s\n' "$test"
  if ! "$LUA" "$test" .; then
    failed=$((failed + 1))
    printf 'FAILED: %s\n' "$test" >&2
  fi
done
printf '\nSuites: %s; passed: %s; failed: %s\n' "$total" "$((total - failed))" "$failed"
[ "$total" -gt 0 ] && [ "$failed" -eq 0 ]
