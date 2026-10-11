#!/usr/bin/env bash
# =============================================================================
# Arcane release build + publish (everything in push.md that needs the big PC).
#
#   ./build.sh                 full run: sync, firebase backup, rules, build, publish
#   ./build.sh --skip-firebase GitHub-only run (no backup / rules / update pointer)
#   ./build.sh --no-push       build and verify only; no tag, release, push or pointer
#   ./build.sh --yes           do not ask before the publishing stages
#   ./build.sh --help
#
# Environment:
#   ARCANE_BACKUP_DESTINATION  off-device directory for Firebase backups (required unless
#                              --skip-firebase)
#   ARCANE_RULES_REVIEWED=1    you merged the other apps' rules into the repository rule
#                              files and want them deployed
#
# The whole run is verbose and also logged to backups/build_<UTC stamp>.log (git-ignored).
# =============================================================================
set -Eeuo pipefail
cd "$(dirname "$0")"

SKIP_FIREBASE=0
NO_PUSH=0
ASSUME_YES=0
for arg in "$@"; do
  case "$arg" in
    --skip-firebase) SKIP_FIREBASE=1 ;;
    --no-push) NO_PUSH=1 ;;
    --yes|-y) ASSUME_YES=1 ;;
    --help|-h) sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $arg (see --help)" >&2; exit 2 ;;
  esac
done

mkdir -p backups
LOG="backups/build_$(date -u +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1

# ── Pretty, verbose logging ──────────────────────────────────────────────────
T0=$SECONDS
STEP=0
TOTAL=11
c() { [[ -t 1 ]] && printf '\033[%sm' "$1" || true; }
stamp() { printf '%02d:%02d' $(((SECONDS - T0) / 60)) $(((SECONDS - T0) % 60)); }
step() { STEP=$((STEP + 1)); printf '\n'; c '1;36'; printf '━━ [%d/%d] +%s  %s\n' "$STEP" "$TOTAL" "$(stamp)" "$*"; c 0; }
info() { c 32; printf '   ✔ %s\n' "$*"; c 0; }
warn() { c 33; printf '   ⚠ %s\n' "$*"; c 0; }
note() { printf '   · %s\n' "$*"; }
die()  { c 31; printf '   ✘ %s\n' "$*" >&2; c 0; exit 1; }
# Echo every command before running it, so a long build never looks stuck.
run()  { c 2; printf '   $ %s\n' "$*"; c 0; "$@"; }
trap 'c 31; printf "\n✘ Failed at line %s (exit %s) after %s: %s\n   Log: %s\n" "$LINENO" "$?" "$(stamp)" "$BASH_COMMAND" "$LOG" >&2; c 0' ERR
confirm() {
  [[ $ASSUME_YES == 1 ]] && return 0
  read -r -p "   ? $1 [y/N] " answer
  [[ $answer == y || $answer == Y ]] || die 'Aborted.'
}

BRANCH=$(git branch --show-current)
VERSION=$(sed -n 's/^version: \([^+]*\)+.*/\1/p' pubspec.yaml)
VCODE=$(sed -n 's/^version: .*+\([0-9]*\)/\1/p' pubspec.yaml)
TAG="v${VERSION}-b${VCODE}"
REPO=ihjas-ahammed/Arcane

c '1;35'; printf '\nArcane release run: %s  (branch %s)\nLog: %s\n' "$TAG" "$BRANCH" "$LOG"; c 0
note "firebase: $([[ $SKIP_FIREBASE == 1 ]] && echo skipped || echo enabled), push: $([[ $NO_PUSH == 1 ]] && echo no || echo yes)"

# ── 1. Preflight ─────────────────────────────────────────────────────────────
step 'Preflight: tools, keys, versions'
missing=()
needed=(git flutter dart java python3 openssl tar gzip strip gh curl)
[[ $SKIP_FIREBASE == 1 ]] || needed+=(firebase)
for tool in "${needed[@]}"; do
  if path=$(command -v "$tool"); then note "$tool → $path"; else missing+=("$tool"); fi
done
((${#missing[@]} == 0)) || die "Missing tools: ${missing[*]}"
run flutter --version
[[ -f .release_keys/update_signing.pem ]] || die '.release_keys/update_signing.pem is missing (copy it from your off-device backup).'
info 'update signing key present'
[[ -f "$HOME/.android/debug.keystore" ]] \
  || warn 'No ~/.android/debug.keystore: APKs would be signed with a NEW certificate and users could not upgrade.'
[[ -f lib/firebase_options.dart && -f android/app/google-services.json ]] \
  || warn 'lib/firebase_options.dart or android/app/google-services.json is missing; the build may fail.'
today=$(date +%Y.%-m.%-d)
[[ $VERSION == "$today" ]] || warn "pubspec version $VERSION is not today's $today (push.md step 1)."
[[ -s latest.md ]] || die 'latest.md (release notes) is empty.'
info "version $VERSION+$VCODE, tag $TAG"
if [[ $NO_PUSH == 0 ]]; then
  run gh auth status
  if [[ $SKIP_FIREBASE == 0 ]]; then
    : "${ARCANE_BACKUP_DESTINATION:?Set ARCANE_BACKUP_DESTINATION to the off-device backup directory}"
    [[ -d $ARCANE_BACKUP_DESTINATION ]] || die "$ARCANE_BACKUP_DESTINATION is not a directory"
    run firebase projects:list
  fi
fi

# ── 2. Sync ──────────────────────────────────────────────────────────────────
step "Sync $BRANCH with origin (push.md step 0)"
run git fetch origin "$BRANCH"
run git pull --rebase --autostash origin "$BRANCH"
run git log --oneline -5

# ── 3. Static guard from the audit ───────────────────────────────────────────
step 'Guard: row-returning PRAGMAs must use rawQuery on Android'
if grep -rnE "execute\(\s*'PRAGMA (journal_mode|quick_check|integrity_check|wal_checkpoint)" lib; then
  die 'A row-returning PRAGMA goes through execute(); Android sqflite rejects it. Use rawQuery.'
fi
info 'no offending PRAGMA statements'

# ── 4. Firebase backup ───────────────────────────────────────────────────────
step 'Firebase database backup (push.md step 0b)'
if [[ $SKIP_FIREBASE == 1 || $NO_PUSH == 1 ]]; then
  warn 'skipped'
else
  run scripts/release.sh backup
  info 'backup written, verified, copied off-device'
fi

# ── 5. Rules ─────────────────────────────────────────────────────────────────
step 'Preserve and deploy Firebase rules (push.md step 0c)'
if [[ $SKIP_FIREBASE == 1 || $NO_PUSH == 1 ]]; then
  warn 'skipped'
else
  confirm 'Deploy database.rules.json, firestore.rules and storage.rules to task-dominion?'
  run scripts/release.sh rules
  info 'rules deployed; anonymous root read denied'
fi

# ── 6. Build ─────────────────────────────────────────────────────────────────
step 'Clean, analyze, test and build: 3 APKs + Linux bundle (push.md step 3)'
note 'This is the long part: flutter output follows in full.'
run scripts/release.sh prepare
info 'all packages built, signed metadata generated and verified'
ls -lh builds/missions-v"${VERSION}"-b"${VCODE}"-* 2>/dev/null | sed 's/^/   /'
sha256sum builds/missions-v"${VERSION}"-b"${VCODE}"-* | sed 's/^/   /'

# ── 7. Commit ────────────────────────────────────────────────────────────────
step 'Commit source and metadata (push.md step 4)'
run git add -A -- . ':!backups' ':!.release_keys' ':!*.apk' ':!*.tar.gz'
if git diff --cached --quiet; then
  note 'nothing to commit'
else
  run git status --short
  run git commit -m "release: Missions ${VERSION} (${VCODE})" \
    -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
fi

if [[ $NO_PUSH == 1 ]]; then
  warn '--no-push: stopping after the commit. Nothing was tagged, published or pushed.'
  note "Finished in $(stamp). Log: $LOG"
  exit 0
fi

# ── 8. Tag + GitHub release ──────────────────────────────────────────────────
step 'Tag, publish and verify the GitHub release (push.md step 4)'
confirm "Create tag $TAG and publish the GitHub release?"
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  note "tag $TAG already exists locally"
else
  run git tag -a "$TAG" -m "Missions ${VERSION} (${VCODE})"
fi
run git push origin "refs/tags/$TAG"
run scripts/release.sh publish-github
info 'GitHub assets published and re-downloaded for SHA-256/Ed25519 verification'

# ── 9. Push branch ───────────────────────────────────────────────────────────
step "Push $BRANCH (updater metadata now points at live assets)"
run git push origin "HEAD:$BRANCH"

# ── 10. Firebase update pointer ──────────────────────────────────────────────
step 'Switch the Firebase update pointer (push.md step 5)'
if [[ $SKIP_FIREBASE == 1 ]]; then
  warn 'skipped (--skip-firebase): record this as blocked in the release notes'
else
  confirm 'Publish builds/update_info.json to /app_updates/latest?'
  run scripts/release.sh pointer
  info 'update pointer switched'
fi

# ── 11. Verify and record ────────────────────────────────────────────────────
step 'Verify published packages and record the result (push.md step 6)'
run python3 scripts/verify_release_assets.py --remote
if [[ $SKIP_FIREBASE == 0 ]]; then
  live=$(firebase database:get /app_updates/latest/version_code --project task-dominion || true)
  note "live Firebase version_code: ${live:-unknown} (expected $VCODE)"
  [[ $live == "$VCODE" ]] || warn 'Firebase pointer does not show this build.'
fi
{
  printf '\n\n## Release run: %s+%s\n\n' "$VERSION" "$VCODE"
  printf 'Built and published with `build.sh` on %s (UTC). Tag: [%s](https://github.com/%s/releases/tag/%s).\n\n' \
    "$(date -u +%F\ %T)" "$TAG" "$REPO" "$TAG"
  printf '| Verified downloadable package | SHA-256 |\n| --- | --- |\n'
  python3 -I - <<'PY'
import json
meta = json.load(open('builds/update_info.json'))
for url, digest in meta['package_sha256'].items():
    print(f"| `{url.rsplit('/', 1)[-1]}` | `{digest}` |")
PY
  printf '\nFirebase update pointer: %s.\n' "$([[ $SKIP_FIREBASE == 1 ]] && echo 'not switched (blocked)' || echo "switched to $VCODE")"
} >> docs/data-hazard-implementation.md
run git add docs/data-hazard-implementation.md
run git commit -m "docs(release): record published ${VERSION} (${VCODE})" \
  -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
run git push origin "HEAD:$BRANCH"
note 'Monthly: perform the restore drill in docs/data-hazard-implementation.md.'
note 'Keep a private off-device copy of .release_keys/update_signing.pem.'

c '1;32'; printf '\n✔ Done: %s published in %s. Log: %s\n' "$TAG" "$(stamp)" "$LOG"; c 0
