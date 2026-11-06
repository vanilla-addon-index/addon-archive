#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

rm -rf dist
mkdir -p dist

# Compute version: tagged release (1.2.0) or dev build (dev-a3f9b2c)
TAG=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || true)
HASH=$(git rev-parse --short HEAD 2>/dev/null || true)
DIRTY=$(git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null || echo "-dirty")

if [ -n "$TAG" ] && [ "$(git describe --tags --exact-match 2>/dev/null || true)" ]; then
  VERSION="$TAG$DIRTY"
elif [ -n "$HASH" ]; then
  VERSION="dev-$HASH$DIRTY"
else
  VERSION="dev"
fi

OUT="dist/PizzaSauce.lua"

cat \
  src/core.lua \
  src/easing.lua \
  src/types.lua \
  src/tween.lua \
  src/sequence.lua \
  src/group.lua \
  src/helpers.lua \
  > "$OUT"

sed -i "s/lib.version = \"dev\"/lib.version = \"$VERSION\"/" "$OUT"

echo "Built $OUT ($VERSION)"

# Copy to test addon if it exists
TEST_DIR="$SCRIPT_DIR/../PizzaSauceDemos"
if [ -d "$TEST_DIR" ]; then
  mkdir -p "$TEST_DIR/lib"
  cp "$OUT" "$TEST_DIR/lib/PizzaSauce.lua"
  echo "Copied to PizzaSauceDemos/"
fi
