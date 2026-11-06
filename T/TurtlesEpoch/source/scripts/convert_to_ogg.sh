#!/usr/bin/env bash
# convert_to_ogg.sh — Convert all .wav files in a folder (recursively) to .ogg
# Usage: ./scripts/convert_to_ogg.sh [directory]
# Default directory: sounds/
# Deletes the original .wav after successful conversion.

set -uo pipefail

TARGET="${1:-sounds}"

if [[ ! -d "$TARGET" ]]; then
    echo "ERROR: Directory not found: $TARGET"
    exit 1
fi

FILE_COUNT=$(find "$TARGET" -type f -name "*.wav" | wc -l)
if [[ $FILE_COUNT -eq 0 ]]; then
    echo "No .wav files found in $TARGET"
    exit 0
fi

echo "Converting $FILE_COUNT .wav files in '$TARGET' to OGG Vorbis..."

CONVERTED=0
FAILED=0

while IFS= read -r -d '' src; do
    [[ -f "$src" ]] || { echo "SKIP (already gone): $src"; continue; }
    ogg="${src%.*}.ogg"
    tmp="${src%.*}.tmp.ogg"
    echo "Converting: $src"
    # Two-pass encode (wav -> ogg -> ogg) to normalize Vorbis packet layout
    # for cross-platform compatibility (WINE + WoW 3.3.5). -q:a 2 (~96 kbps)
    # is empirically required — higher bitrates intermittently produce files
    # with non-monotonic granulepos that play silent in-game. See AGENTS.md.
    if ffmpeg -y -i "$src" -c:a libvorbis -q:a 2 -ar 44100 -ac 1 -f ogg "$tmp" -loglevel error \
        && ffmpeg -y -i "$tmp" -c:a libvorbis -q:a 2 -ar 44100 -ac 1 -f ogg "$ogg" -loglevel error; then
        rm -f "$tmp" "$src"
        CONVERTED=$((CONVERTED + 1))
        echo "  OK -> $ogg"
    else
        rm -f "$tmp"
        echo "  FAILED: $src"
        FAILED=$((FAILED + 1))
    fi
done < <(find "$TARGET" -type f -name "*.wav" -print0)

echo "Done. Converted: $CONVERTED  Failed: $FAILED"
