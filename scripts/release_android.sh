#!/usr/bin/env bash
# =============================================================================
# Android-only release: build, verify, publish GitHub assets, push, switch the Firebase pointer.
#
#   scripts/release_android.sh                 full release (asks before publishing)
#   scripts/release_android.sh --prepare-only  build, verify and sign locally; publish nothing
#   scripts/release_android.sh --yes           do not ask before publishing
#   scripts/release_android.sh --arm64-only    build and publish only the arm64-v8a APK
#
# Steps (each one stops the run on failure):
#   1. Check pubspec version, clean tree, tag not yet used.
#   2. flutter build apk --release --split-per-abi
#   3. Check the version INSIDE each APK (aapt), not just the file name or build time.
#   4. Copy APKs into builds/, generate and verify signed metadata (--android-only).
#   5. Commit metadata, create tag, publish GitHub release assets, push tag, push branch.
#   6. Verify the published assets, then switch /app_updates/latest.
# =============================================================================
set -Eeuo pipefail
cd "$(dirname "$0")/.."

PREPARE_ONLY=0
ASSUME_YES=0
ARM64_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --prepare-only) PREPARE_ONLY=1 ;;
    --yes|-y) ASSUME_YES=1 ;;
    --arm64-only) ARM64_ONLY=1 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

REPO=ihjas-ahammed/Arcane
PROJECT=task-dominion
DB_URL=https://task-dominion-default-rtdb.asia-southeast1.firebasedatabase.app
AAPT=$(ls -d "$HOME"/Android/Sdk/build-tools/*/aapt 2>/dev/null | sort -V | tail -1)
FIREBASE=$(command -v "$HOME/.npm-global/bin/firebase" || command -v firebase)
export PATH="$PATH:$HOME/development/flutter/bin"

log() { printf '\n== %s\n' "$*"; }
fail() { echo "STOPPED: $*" >&2; exit 1; }
retry() { local n; for n in 1 2 3 4 5; do "$@" && return 0; echo "  retry $n: $*" >&2; sleep $((2 ** n)); done; return 1; }

# --- 1. Preconditions --------------------------------------------------------
log "1. Preconditions"
BRANCH=$(git branch --show-current)
[[ $BRANCH == revive2 ]] || fail "release from revive2 (current: $BRANCH)"
if [[ -n $(git status --porcelain | grep -v -E '^.. (builds/|push.md|latest.md|pubspec.yaml|docs/)' || true) ]]; then
  git status --short; fail "uncommitted source changes; commit or stash them first"
fi
VERSION=$(sed -n 's/^version: \([^+]*\)+.*/\1/p' pubspec.yaml)
VCODE=$(sed -n 's/^version: .*+\([0-9]*\)/\1/p' pubspec.yaml)
TAG="v${VERSION}-b${VCODE}"
[[ -n $VERSION && -n $VCODE ]] || fail "could not read version from pubspec.yaml"
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then fail "tag $TAG already exists; bump the version in pubspec.yaml"; fi
[[ -x $AAPT ]] || fail "aapt not found under the Android SDK build-tools"
echo "Release $TAG (versionName $VERSION, versionCode $VCODE)"

# --- 2. Build ----------------------------------------------------------------
log "2. Build split release APKs"
flutter pub get
if [[ $ARM64_ONLY == 1 ]]; then
  flutter build apk --release --target-platform android-arm64
else
  flutter build apk --release --split-per-abi
fi

# --- 3. Verify the version inside each APK -----------------------------------
log "3. Verify version inside each APK"
declare -A OFFSET=([arm64-v8a]=2000 [armeabi-v7a]=1000 [x86_64]=4000)
ABIS=(arm64-v8a armeabi-v7a x86_64)
[[ $ARM64_ONLY == 1 ]] && ABIS=(arm64-v8a)
for ABI in "${ABIS[@]}"; do
  if [[ $ARM64_ONLY == 1 ]]; then SRC=build/app/outputs/flutter-apk/app-release.apk; else SRC=build/app/outputs/flutter-apk/app-${ABI}-release.apk; fi
  [[ -f $SRC ]] || fail "missing $SRC"
  # Capture first: grep -m1 closing the pipe would make aapt fail under pipefail.
  BADGING=$("$AAPT" dump badging "$SRC")
  BADGING=$(printf '%s\n' "$BADGING" | grep -m1 "^package:" || true)
  GOT_NAME=$(echo "$BADGING" | sed -n "s/.*versionName='\([^']*\)'.*/\1/p")
  GOT_CODE=$(echo "$BADGING" | sed -n "s/.*versionCode='\([0-9]*\)'.*/\1/p")
  EXPECT_CODE=$((VCODE + OFFSET[$ABI]))
  # A single-ABI build is not split, so it carries the base version code.
  [[ $ARM64_ONLY == 1 ]] && EXPECT_CODE=$VCODE
  if [[ $GOT_NAME != "$VERSION" || $GOT_CODE != "$EXPECT_CODE" ]]; then
    fail "$ABI APK reports $GOT_NAME/$GOT_CODE, expected $VERSION/$EXPECT_CODE"
  fi
  echo "  $ABI: versionName $GOT_NAME, versionCode $GOT_CODE"
  cp "$SRC" "builds/missions-v${VERSION}-b${VCODE}-${ABI}.apk"
done

# --- 4. Metadata -------------------------------------------------------------
log "4. Signed metadata (Android only)"
cp latest.md builds/latest.md
EXTRA=(); [[ $ARM64_ONLY == 1 ]] && EXTRA=(--arm64-only)
python3 scripts/generate_release_metadata.py --branch "$BRANCH" --android-only "${EXTRA[@]}"
python3 scripts/verify_release_assets.py --android-only "${EXTRA[@]}" | tail -1

if [[ $PREPARE_ONLY == 1 ]]; then
  echo; echo "Prepare-only: nothing published. Assets are in builds/ for $TAG."
  exit 0
fi

# --- confirmation before anything public -------------------------------------
if [[ $ASSUME_YES != 1 ]]; then
  read -r -p "Publish $TAG to GitHub, push $BRANCH and switch the live update pointer? [y/N] " ANSWER
  [[ $ANSWER == y || $ANSWER == Y ]] || fail "not published"
fi

# --- 5. Commit, tag, GitHub release, push ------------------------------------
log "5. Commit, tag, GitHub release, push"
git add builds/update_info.json builds/latest.json builds/latest.md
if ! git diff --cached --quiet; then
  git commit -q -m "release: Missions ${VERSION} (${VCODE}) update metadata" -m "Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>"
fi
git tag -a "$TAG" -m "Missions ${VERSION} (${VCODE})"
retry git push origin "$TAG"
APKS=(); for ABI in "${ABIS[@]}"; do APKS+=("builds/missions-v${VERSION}-b${VCODE}-${ABI}.apk"); done
retry gh release create "$TAG" "${APKS[@]}" --repo "$REPO" --target "$(git rev-parse HEAD)" \
  --title "Missions ${VERSION} (#${VCODE})" --notes-file latest.md
retry git push -u origin "$BRANCH"

# --- 6. Verify published assets, switch the pointer ---------------------------
log "6. Verify published assets"
for ABI in "${ABIS[@]}"; do
  NAME=missions-v${VERSION}-b${VCODE}-${ABI}.apk
  TMP=$(mktemp -d)
  retry gh release download "$TAG" --repo "$REPO" --pattern "$NAME" --dir "$TMP" >/dev/null
  python3 - "$TMP/$NAME" "$NAME" <<'EOF'
import hashlib, json, os, sys
path, name = sys.argv[1], sys.argv[2]
meta = json.load(open('builds/update_info.json'))
url = [u for u in meta['package_sha256'] if u.endswith('/' + name)][0]
digest = hashlib.sha256(open(path, 'rb').read()).hexdigest()
if digest != meta['package_sha256'][url] or os.path.getsize(path) != meta['package_sizes'][url]:
    sys.exit(f'published {name} does not match the signed metadata')
print(f'  {name}: matches signed metadata')
EOF
  rm -rf "$TMP"
done

log "6b. Switch the live update pointer"
python3 -c "import json; meta = json.load(open('builds/update_info.json')); open('builds/firebase_update_info.json', 'w').write(json.dumps({k: v for k, v in meta.items() if k not in ('package_sha256', 'package_signatures', 'package_sizes')}, indent=2) + '\n')"
retry "$FIREBASE" database:set /app_updates/latest builds/firebase_update_info.json --project "$PROJECT" --force >/dev/null
LIVE=$(curl -s --max-time 60 "$DB_URL/app_updates/latest/version_code.json")
[[ $LIVE == "$VCODE" ]] || fail "live pointer is $LIVE, expected $VCODE"
echo "  live pointer: $LIVE"

echo; echo "Released $TAG. Next: wait a few minutes for the GitHub raw copy to refresh, then update on the phone."
