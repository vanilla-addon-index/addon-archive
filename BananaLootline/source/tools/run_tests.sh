#!/usr/bin/env bash
# Alle Tests vom Addon-Stamm aus ausfuehren. Exit-Code 1 bei Fehler.
# Nutzung:  bash tools/run_tests.sh
set -u
cd "$(dirname "$0")/.."

LUA="${LUA:-lua5.1}"
fail=0

# 1. Syntax aller Addon-Dateien
for f in *.lua Data/*.lua; do
  if ! luac5.1 -p "$f"; then echo "SYNTAXFEHLER: $f"; fail=1; fi
done

# 2. Leere oder abgeschnittene Dateien: luac meldet die nicht
for f in *.lua; do
  if [ "$(wc -c < "$f")" -lt 50 ]; then echo "VERDAECHTIG KLEIN: $f"; fail=1; fi
done

# 3. Funktionstests
for t in tools/test_*.lua; do
  out="$("$LUA" "$t" 2>&1)"
  if echo "$out" | tail -1 | grep -q "ALLE TESTS OK"; then
    printf "ok    %s\n" "$t"
  else
    printf "FEHLER %s\n%s\n" "$t" "$out"; fail=1
  fi
done

# 4. Konvertertests
for t in tools/test_build.py tools/test_locvote.py; do
  if python3 "$t" | tail -1 | grep -q "ALLE TESTS OK"; then
    echo "ok    $t"
  else
    echo "FEHLER $t"; python3 "$t"; fail=1
  fi
done

exit $fail
