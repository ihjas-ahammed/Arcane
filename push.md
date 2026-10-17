Project facts (confirmed by the owner):
- The `task-dominion` Firebase project hosts only Arcane. No other application shares its RTDB, Firestore or Storage rules, so the "retain other apps' rules" requirement does not apply.
- The owner is the only user of this app. Firebase security rules are not part of the release. The Firebase CLI account in use is the owner's account for this product, so administrator access is available to the release run.
- The off-device backup directory is `backups/` inside this repository (git-ignored). Backups and rules are not part of the current release process (see steps 0b and 0c below, skipped).
- Android releases are signed with the repository's `debug.keystore`, the same as previous releases, so installed users can upgrade.
- Android ships arm64-v8a and armeabi-v7a only. x86_64 is not published (emulators only). The desktop build is the Linux x86_64 bundle.

## Release process (two stages)

Stage 1 is Android. It is published first and the update pointer is switched right away, so users get the update quickly. Stage 2 is the Linux bundle. It is built afterwards and added to the same GitHub release, then the pointer is switched again with the Linux download included.

0. Sync the branch: `git pull --rebase origin revive2`.
0b. Firebase backup: SKIPPED (not part of the release process).
0c. Firebase rules: SKIPPED (not part of the release process).
1. Set the version in `pubspec.yaml`: the name is today's YYYY.M.D, and the code is 21YYMMDDxx (increment xx for each build on the same day). Previous builds on the same day: 2126101601 is published, so the next is 2126101602.
2. Write release notes in `latest.md`.

### Stage 1: Android (fast)
3. `scripts/release.sh prepare-android`. It cleans, analyzes, tests, builds the arm64-v8a and armeabi-v7a APKs, copies the changelog, and generates Android-only signed metadata. It verifies the local APKs.
   - Check the versions inside the APKs before publishing: `aapt dump badging builds/<apk> | grep -m1 "^package:"` must show the pubspec `versionName` and the expected `versionCode` (base code + 2000 for arm64-v8a, + 1000 for armeabi-v7a).
   - The private signing key lives at `.release_keys/update_signing.pem`. Keep a private off-device copy. Never commit or publish it.
4. Commit source and metadata (`git add -A`, one commit). Create the tag for that commit, then `scripts/release.sh publish-github` (creates the GitHub release with the Android APKs and verifies them from GitHub). Then `git push origin HEAD:revive2`.
5. Update pointer: `scripts/release.sh pointer` (uses the authenticated Firebase CLI, the administrator account). Read it back with `firebase database:get /app_updates/latest --project task-dominion` and check `version_code`.

### Stage 2: Linux (slower)
6. `scripts/release.sh prepare-linux`. It builds the Linux x86_64 bundle, strips it, packages it, and regenerates the signed metadata to include it. It verifies all local packages.
7. Commit the metadata (one commit). Then `scripts/release.sh publish-linux`: it uploads the tarball to the existing GitHub release and verifies every asset from GitHub. Then `git push origin HEAD:revive2`.
8. Update pointer again: `scripts/release.sh pointer`. Read it back and check that `linux_url` is set.

### Verify
9. Check the published package hashes and the Firebase metadata. Record the result in docs/data-hazard-implementation.md.

Notes:
- `scripts/release.sh prepare` runs both stages in one go. `build.sh` still works, but its backup, rules and pointer steps are the old ones.
- `publish` (the old combined mode) runs the backup first. Do not use it while backups are skipped.

Update pointer findings (2026.10.15 release):
- Firebase RTDB keys cannot contain `.`, `$`, `#`, `[`, `]` or `/`. The checksum and signature maps are keyed by download URL, so they cannot be stored under `/app_updates/latest`. The pointer must omit `package_sha256`, `package_signatures` and `package_sizes`. Do not remove that stripping in `scripts/release.sh`; a write with the maps fails with HTTP 400.
- The app fills in the checksums and signatures itself: when the pointer lacks them, `lib/src/services/update_service.dart` reads `builds/update_info.json` from `raw.githubusercontent.com` on `revive2` and needs its `version_code` to match the pointer. Installation is blocked if no valid SHA-256 is found.
- Before switching the pointer, check that the `revive2` raw copy has the new `version_code` and all three hashes, signatures and sizes. The app also tries the `main` raw copy, which was not updated and did not return JSON; do not rely on it.
- Android-only releases: use `scripts/generate_release_metadata.py --android-only` and `scripts/verify_release_assets.py --android-only`. They omit the Linux bundle and its URLs, which the app treats as optional.
- Firebase Storage is not used for this project and will not be enabled. Database backups are kept on this machine in `backups/` (git-ignored). Hosted release data lives on GitHub: the signed metadata in `builds/` on `revive2`, and the APKs on the GitHub release. The Firebase pointer `/app_updates/latest` holds only version fields. `storage.rules` is not deployed.

Release safety check (added after the 2026.10.15 mistake, where the published APKs contained the 2026.10.11 build):
- Before copying or publishing any APK, confirm the version inside it, not just the file name: `aapt dump badging <apk> | grep -m1 "^package:"` must show `versionName='<pubspec version>'` and the expected `versionCode` (the base code, plus 2000 for arm64-v8a, 1000 for armeabi-v7a).
- Check the source APK's build time against the build run before copying it. Stale files in `build/` look valid.
- `scripts/verify_release_assets.py` checks signatures and hashes, but it does not check the version inside each APK. Run the `aapt` check above in addition.
