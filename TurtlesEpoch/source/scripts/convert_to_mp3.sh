#!/usr/bin/env bash
# convert_to_mp3.sh — Convert all .wav/.ogg files in a folder (recursively) to .mp3
# Usage: ./scripts/convert_to_mp3.sh [directory]
# Default directory: sounds/
# Deletes the original file after successful conversion.

set -uo pipefail

TARGET="${1:-sounds}"

if [[ ! -d "$TARGET" ]]; then
    echo "ERROR: Directory not found: $TARGET"
    exit 1
fi

# Count both wav and ogg files
FILE_COUNT=$(find "$TARGET" -type f \( -name "*.wav" -o -name "*.ogg" \) | wc -l)
if [[ $FILE_COUNT -eq 0 ]]; then
    echo "No .wav or .ogg files found in $TARGET"
    exit 0
fi

echo "Converting $FILE_COUNT audio files in '$TARGET' to MP3 @ 64kbps mono..."

CONVERTED=0
FAILED=0

while IFS= read -r -d '' src; do
    # Skip if already gone (resuming a previous partial run)
    [[ -f "$src" ]] || { echo "SKIP (already gone): $src"; continue; }
    mp3="${src%.*}.mp3"
    echo "Converting: $src"
    if ffmpeg -y -i "$src" -c:a libmp3lame -b:a 64k -ac 1 "$mp3" -loglevel error; then
        rm -f "$src"
        CONVERTED=$((CONVERTED + 1))
        echo "  OK -> $mp3"
    else
        echo "  FAILED: $src"
        FAILED=$((FAILED + 1))
    fi
done < <(find "$TARGET" -type f \( -name "*.wav" -o -name "*.ogg" \) -print0)

echo "Done. Converted: $CONVERTED  Failed: $FAILED"
