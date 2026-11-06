#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

SPINNER_FRAMES=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
SPINNER_PID=""

spinner_start() {
  local msg="$1" i=0
  (
    while true; do
      printf "\r\033[2K${CYAN}${SPINNER_FRAMES[$i]}${RESET} %s" "$msg" >&2
      i=$(( (i + 1) % ${#SPINNER_FRAMES[@]} ))
      sleep 0.08
    done
  ) &
  SPINNER_PID=$!
}

spinner_stop() {
  if [ -n "$SPINNER_PID" ]; then
    kill "$SPINNER_PID" 2>/dev/null
    wait "$SPINNER_PID" 2>/dev/null || true
    SPINNER_PID=""
    printf "\r\033[2K" >&2
  fi
}

step()  { spinner_start "$1"; }
ok()    { spinner_stop; echo -e "${GREEN}✓${RESET} $1"; }
warn()  { spinner_stop; echo -e "${YELLOW}⚠${RESET} $1"; }
fail()  { spinner_stop; echo -e "${RED}✗${RESET} $1"; exit 1; }
info()  { echo -e "  ${DIM}$1${RESET}"; }

# --- Validate arguments ---

VERSION="$1"
if [ -z "$VERSION" ]; then
  echo "Usage: ./release.sh <version>"
  echo "Example: ./release.sh 1.2.0"
  exit 1
fi

if ! echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  fail "Version must be in semver format (e.g. 1.2.0)"
fi

TAG="v$VERSION"

if git rev-parse "$TAG" >/dev/null 2>&1; then
  fail "Tag $TAG already exists"
fi

# --- Detect remote ---

REMOTE_URL=$(git remote get-url origin)
OWNER=$(echo "$REMOTE_URL" | sed -E 's#.*/([^/]+)/[^/]+\.git$#\1#')
REPO=$(echo "$REMOTE_URL" | sed -E 's#.*/([^/]+)\.git$#\1#')

if echo "$REMOTE_URL" | grep -q "codeberg"; then
  API="https://codeberg.org/api/v1"
  HOST="https://codeberg.org"
else
  fail "Expected Codeberg remote, got: $REMOTE_URL"
fi

TOKEN="${CODEBERG_TOKEN:-$(cat ~/.config/codeberg/token 2>/dev/null)}"
if [ -z "$TOKEN" ]; then
  fail "No API token found. Set CODEBERG_TOKEN or put your token in ~/.config/codeberg/token"
fi

ARTIFACT="PizzaSauce.lua"

cleanup() { spinner_stop; }
trap cleanup EXIT

echo ""
echo -e "${BOLD}🚀 PizzaSauce ${CYAN}$TAG${RESET}"
info " $OWNER/$REPO"
echo ""

# --- Check working tree ---

step "Checking working tree"
if [ -n "$(git status --porcelain)" ]; then
  fail "Uncommitted changes. Commit first."
fi
ok "Working tree clean"

# --- Check remote is up to date ---

BRANCH=$(git rev-parse --abbrev-ref HEAD)

step "Checking remote"
git fetch origin "$BRANCH" --quiet 2>/dev/null || true
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse "origin/$BRANCH" 2>/dev/null || echo "")
if [ -n "$REMOTE" ] && [ "$LOCAL" != "$REMOTE" ]; then
  fail "Local branch '$BRANCH' is not in sync with origin"
fi
ok "Branch in sync"

# --- Update docs version, commit, tag ---

step "Updating version"
sed -i "s/PizzaSauce v[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*/PizzaSauce v$VERSION/" docs/API.md
sed -i "s/lib\.version = \"[^\"]*\"/lib.version = \"$VERSION\"/" src/core.lua
git add docs/API.md src/core.lua
git diff --cached --quiet || git commit -m "🚀🎉 v$VERSION" --quiet
ok "Version updated"

step "Tagging $TAG"
git tag "$TAG"
ok "Created tag $TAG"

# --- Build ---

step "Building $ARTIFACT"
bash build.sh > /dev/null
if [ ! -f "dist/$ARTIFACT" ]; then
  fail "Build did not produce dist/$ARTIFACT"
fi
SIZE=$(du -h "dist/$ARTIFACT" | cut -f1)
ok "Built ${DIM}($SIZE)${RESET}"

# --- Push ---

step "Pushing branch and tag"
git push origin "$BRANCH" --quiet 2>/dev/null
git push origin "$TAG" --quiet 2>/dev/null
ok "Pushed"

# --- Create release ---

step "Creating release"
RESP_FILE=$(mktemp)
create_release() {
  curl -s -X POST \
    "$API/repos/$OWNER/$REPO/releases" \
    -H "Authorization: token $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"tag_name": "'"$TAG"'", "name": "'"$TAG"'", "body": "PizzaSauce '"$VERSION"' — [README]('"$HOST/$OWNER/$REPO/src/tag/$TAG"'/README.md) | [API Reference]('"$HOST/$OWNER/$REPO/src/tag/$TAG"'/docs/API.md)", "hide_archive_links": true}' \
    -o "$RESP_FILE" -w '%{http_code}'
}

HTTP_CODE=$(create_release)
RETRIES=0
while [ "$HTTP_CODE" = "500" ] && [ "$RETRIES" -lt 5 ]; do
  RETRIES=$((RETRIES + 1))
  warn "Server returned 500, retrying in 3s ($RETRIES/5)..."
  sleep 3
  HTTP_CODE=$(create_release)
done
RELEASE_RESPONSE=$(cat "$RESP_FILE")
rm -f "$RESP_FILE"

RELEASE_ID=$(echo "$RELEASE_RESPONSE" | grep -o '"id" *: *[0-9]*' | head -1 | grep -o '[0-9]*' || true)
if [ -z "$RELEASE_ID" ]; then
  fail "Failed to create release (HTTP $HTTP_CODE): $RELEASE_RESPONSE"
fi
ok "Release created"

# --- Upload artifact ---

step "Uploading $ARTIFACT"
curl -s -X POST "$API/repos/$OWNER/$REPO/releases/$RELEASE_ID/assets" \
  -H "Authorization: token $TOKEN" \
  -F "attachment=@dist/$ARTIFACT" \
  -F "name=$ARTIFACT" > /dev/null
ok "Upload complete"

echo ""
echo -e "${GREEN}${BOLD}Done!${RESET} ${DIM}$HOST/$OWNER/$REPO/releases/tag/$TAG${RESET}"
echo ""
