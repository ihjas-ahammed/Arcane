#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
MODE=${1:-prepare}
BRANCH=$(git branch --show-current)
VERSION=$(sed -n 's/^version: \([^+]*\)+.*/\1/p' pubspec.yaml)
VCODE=$(sed -n 's/^version: .*+\([0-9]*\)/\1/p' pubspec.yaml)
TAG="v${VERSION}-b${VCODE}"
REPO=ihjas-ahammed/Arcane
PROJECT=task-dominion
log() { printf '\n[%s] ==> %s\n' "$(date +%H:%M:%S)" "$*"; }
publish_github() {
  python3 scripts/verify_release_assets.py
  if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
    log "GitHub release $TAG already exists; verifying remote assets"
  else
    gh release create "$TAG" builds/missions-v"${VERSION}"-b"${VCODE}"-*.apk "builds/missions-v${VERSION}-b${VCODE}-linux-x86_64.tar.gz" --repo "$REPO" --target "$(git rev-parse HEAD)" --title "Missions ${VERSION} (#${VCODE})" --notes-file latest.md
  fi
  python3 scripts/verify_release_assets.py --remote
}
# Dated, verified, gzip'd Firebase database backup, copied off-device and pruned to 30.
backup_firebase() {
  umask 077
  if [[ -z ${ARCANE_BACKUP_DESTINATION:-} || ! -d $ARCANE_BACKUP_DESTINATION ]]; then
    echo 'Set ARCANE_BACKUP_DESTINATION to an available off-device backup directory before publishing.' >&2
    exit 1
  fi
  mkdir -p backups
  STAMP=$(date -u +%Y%m%d_%H%M%S)
  log "Downloading the production database to backups/firebase_db_${STAMP}.json"
  firebase database:get / --project "$PROJECT" --output "backups/firebase_db_${STAMP}.json"
  log 'Verifying the backup is valid JSON'
  python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "backups/firebase_db_${STAMP}.json"
  log 'Compressing the backup'
  gzip -9 "backups/firebase_db_${STAMP}.json"
  log "Copying the backup to $ARCANE_BACKUP_DESTINATION"
  if [[ $(realpath "backups") != $(realpath "$ARCANE_BACKUP_DESTINATION") ]]; then
    cp "backups/firebase_db_${STAMP}.json.gz" "$ARCANE_BACKUP_DESTINATION/"
  fi
  python3 - "backups/firebase_db_${STAMP}.json.gz" "$ARCANE_BACKUP_DESTINATION" <<'PY'
import hashlib, sys
from pathlib import Path
source, destination = Path(sys.argv[1]), Path(sys.argv[2])
def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()
if digest(source) != digest(destination / source.name):
    raise SystemExit('The external backup copy failed checksum verification.')
print('External copy verified:', destination / source.name)
folders = {source.parent.resolve(), destination.resolve()}
for folder in folders:
    snapshots = sorted(folder.glob('firebase_db_*.json.gz'), reverse=True)
    for snapshot in snapshots[30:]:
        print('Pruning old backup', snapshot)
        snapshot.unlink()
PY
}

# Preserve what is deployed, then deploy the reviewed rules. The project hosts other
# applications, so the deployed rules must be merged by an administrator, never overwritten blindly.
deploy_rules() {
  mkdir -p backups
  STAMP=$(date -u +%Y%m%d_%H%M%S)
  log "Saving the currently deployed RTDB rules to backups/rtdb_rules_${STAMP}.json"
  firebase database:get /.settings/rules --project "$PROJECT" --output "backups/rtdb_rules_${STAMP}.json"
  if [[ ${ARCANE_RULES_REVIEWED:-} != 1 ]]; then
    echo 'Repository rules: database.rules.json, firestore.rules, storage.rules.' >&2
    echo 'They replace the deployed rules. Confirm that the other applications in this project' >&2
    echo 'keep their access (merge them into the files first), then re-run with ARCANE_RULES_REVIEWED=1.' >&2
    exit 1
  fi
  log 'Deploying database, firestore and storage rules'
  firebase deploy --only database,firestore:rules,storage --project "$PROJECT"
  verify_rules
}

verify_rules() {
  local db='https://task-dominion-default-rtdb.asia-southeast1.firebasedatabase.app'
  log 'Verifying anonymous root reads are denied'
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' "$db/.json?shallow=true")
  echo "Anonymous root read returned HTTP $code"
  [[ $code == 401 || $code == 403 ]] || { echo 'Anonymous root read is NOT denied.' >&2; exit 1; }
  # No anonymous write probe on purpose: if the rules were still open it would succeed and
  # modify production. Verify client write denial with a test account instead.
  echo 'Rules verified for anonymous reads. Check app_updates write denial with a signed-in test account.'
}

case "$MODE" in
  prepare)
    log "Preparing $TAG on $BRANCH"
    log 'flutter clean'
    flutter clean
    log 'flutter pub get'
    flutter pub get
    log 'flutter analyze'
    flutter analyze --no-fatal-infos --no-fatal-warnings
    log 'flutter test'
    flutter test --reporter expanded
    # Existing tracked assets may still be referenced by deployed Firebase
    # metadata. Keep those until its authenticated cutover is verified.
    for APK in builds/*.apk; do
      [[ -f $APK ]] || continue
      if ! git ls-files --error-unmatch -- "$APK" >/dev/null 2>&1; then
        rm -f -- "$APK"
      fi
    done
    log 'Building split release APKs (arm64-v8a, armeabi-v7a, x86_64)'
    flutter build apk --release --split-per-abi
    for ABI in arm64-v8a armeabi-v7a x86_64; do
      log "Copying the $ABI APK"
      cp -v "build/app/outputs/flutter-apk/app-${ABI}-release.apk" "builds/missions-v${VERSION}-b${VCODE}-${ABI}.apk"
    done
    log 'Building the Linux x86_64 release bundle'
    flutter build linux --release
    log 'Stripping the Linux binaries'
    strip --strip-unneeded build/linux/x64/release/bundle/missions build/linux/x64/release/bundle/lib/*.so
    cp -v linux/arcane.desktop build/linux/x64/release/bundle/
    log 'Packaging the Linux tarball'
    tar -I 'gzip -9' -cvf "builds/missions-v${VERSION}-b${VCODE}-linux-x86_64.tar.gz" -C build/linux/x64/release/bundle .
    cp -v latest.md builds/latest.md
    log 'Generating signed metadata'
    python3 scripts/generate_release_metadata.py --branch "$BRANCH"
    log 'Verifying local packages (SHA-256, size, Ed25519)'
    python3 scripts/verify_release_assets.py
    ;;
  backup)
    backup_firebase
    ;;
  rules)
    deploy_rules
    ;;
  verify-rules)
    verify_rules
    ;;
  pointer)
    # Switches the live Firebase update pointer. Needs administrator access to task-dominion.
    python3 scripts/verify_release_assets.py --remote
    log 'Publishing the update pointer to /app_updates/latest'
    firebase database:set /app_updates/latest builds/update_info.json --project "$PROJECT" --force
    ;;
  publish-github)
    publish_github
    ;;
  publish)
    # This mode requires administrator access to task-dominion.
    # Secure and deploy the reviewed rules (mode: rules) before publishing update metadata.
    backup_firebase
    if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
      python3 scripts/verify_release_assets.py --remote
    else
      publish_github
    fi
    log 'Publishing the update pointer to /app_updates/latest'
    firebase database:set /app_updates/latest builds/update_info.json --project "$PROJECT" --force
    ;;
  *) echo 'Usage: scripts/release.sh prepare|publish-github|backup|rules|verify-rules|pointer|publish' >&2; exit 2;;
esac
