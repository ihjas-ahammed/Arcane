#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
MODE=${1:-prepare}
BRANCH=$(git branch --show-current)
VERSION=$(sed -n 's/^version: \([^+]*\)+.*/\1/p' pubspec.yaml)
VCODE=$(sed -n 's/^version: .*+\([0-9]*\)/\1/p' pubspec.yaml)
TAG="v${VERSION}-b${VCODE}"
REPO=ihjas-ahammed/Arcane
publish_github() {
  python3 scripts/verify_release_assets.py
  gh release create "$TAG" builds/missions-v"${VERSION}"-b"${VCODE}"-*.apk "builds/missions-v${VERSION}-b${VCODE}-linux-x86_64.tar.gz" --repo "$REPO" --target "$(git rev-parse HEAD)" --title "Missions ${VERSION} (#${VCODE})" --notes-file latest.md
  python3 scripts/verify_release_assets.py --remote
}
case "$MODE" in
  prepare)
    flutter clean
    flutter pub get
    flutter analyze --no-fatal-infos --no-fatal-warnings
    flutter test
    # Existing tracked assets may still be referenced by deployed Firebase
    # metadata. Keep those until its authenticated cutover is verified.
    for APK in builds/*.apk; do
      [[ -f $APK ]] || continue
      if ! git ls-files --error-unmatch -- "$APK" >/dev/null 2>&1; then
        rm -f -- "$APK"
      fi
    done
    flutter build apk --release --split-per-abi
    for ABI in arm64-v8a armeabi-v7a x86_64; do
      cp "build/app/outputs/flutter-apk/app-${ABI}-release.apk" "builds/missions-v${VERSION}-b${VCODE}-${ABI}.apk"
    done
    flutter build linux --release
    strip --strip-unneeded build/linux/x64/release/bundle/missions build/linux/x64/release/bundle/lib/*.so
    cp linux/arcane.desktop build/linux/x64/release/bundle/
    tar -I 'gzip -9' -cf "builds/missions-v${VERSION}-b${VCODE}-linux-x86_64.tar.gz" -C build/linux/x64/release/bundle .
    cp latest.md builds/latest.md
    python3 scripts/generate_release_metadata.py --branch "$BRANCH"
    python3 scripts/verify_release_assets.py
    ;;
  publish-github)
    publish_github
    ;;
  publish)
    # This mode requires administrator access to task-dominion.
    # Secure and deploy the reviewed rules before publishing update metadata.
    umask 077
    if [[ -z ${ARCANE_BACKUP_DESTINATION:-} || ! -d $ARCANE_BACKUP_DESTINATION ]]; then
      echo 'Set ARCANE_BACKUP_DESTINATION to an available off-device backup directory before publishing.' >&2
      exit 1
    fi
    mkdir -p backups
    STAMP=$(date -u +%Y%m%d_%H%M%S)
    firebase database:get / --project task-dominion --output "backups/firebase_db_${STAMP}.json"
    python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "backups/firebase_db_${STAMP}.json"
    gzip -9 "backups/firebase_db_${STAMP}.json"
    cp "backups/firebase_db_${STAMP}.json.gz" "$ARCANE_BACKUP_DESTINATION/"
    python3 - "backups/firebase_db_${STAMP}.json.gz" "$ARCANE_BACKUP_DESTINATION" <<'PY'
import hashlib, sys
from pathlib import Path
source, destination = Path(sys.argv[1]), Path(sys.argv[2])
def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()
if digest(source) != digest(destination / source.name):
    raise SystemExit('The external backup copy failed checksum verification.')
for folder in (source.parent, destination):
    snapshots = sorted(folder.glob('firebase_db_*.json.gz'), reverse=True)
    for snapshot in snapshots[30:]:
        snapshot.unlink()
PY
    if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
      python3 scripts/verify_release_assets.py --remote
    else
      publish_github
    fi
    firebase database:set /app_updates/latest builds/update_info.json --project task-dominion --force
    ;;
  *) echo 'Usage: scripts/release.sh prepare|publish-github|publish' >&2; exit 2;;
esac
