# Release process

Version: name is `YYYY.MM.DD`, code is `21YYMMDDxx` (xx = build number for that day, starting at 01).
Example for 2026-10-21: `version: 2026.10.21+2126102101`.

Set `VER`, `CODE` and `TAG` before you start, for example `VER=2026.10.21`, `CODE=2126102101`, `TAG=v2026.10.21-b2126102101`.

## Steps

1. Update the version code in `pubspec.yaml`:
   `version: $VER+$CODE`

2. Build the APK:
   ```
   flutter build apk --release
   ```
   Output: `build/app/outputs/flutter-apk/app-release.apk`

3. Commit, push, and create the GitHub release with the APK:
   ```
   git add -A && git commit -m "release: Missions $VER ($CODE)"
   git push origin HEAD:revive2
   gh release create "$TAG" build/app/outputs/flutter-apk/app-release.apk \
     --repo ihjas-ahammed/Arcane --target revive2 \
     --title "Missions $VER ($CODE)" --notes-file latest.md
   ```

4. Tell Firebase about the new release. Copy the current pointer, edit it, and write it back:
   ```
   ~/.npm-global/bin/firebase database:get /app_updates/latest --project task-dominion > /tmp/pointer.json
   ```
   Edit `/tmp/pointer.json`: set `version_code`, `version_name`, `published_at`, `apk_url` and `apk_filename` to the new release. Keep the other fields. Then:
   ```
   ~/.npm-global/bin/firebase database:set /app_updates/latest /tmp/pointer.json --project task-dominion --force
   ```
   Read it back and check `version_code`.

5. Build the Linux bundle and package it:
   ```
   flutter build linux --release
   tar -czf "missions-v$VER-b$CODE-linux-x86_64.tar.gz" -C build/linux/x64/release/bundle .
   ```

6. Attach the Linux bundle to the release, and commit any changes:
   ```
   gh release upload "$TAG" "missions-v$VER-b$CODE-linux-x86_64.tar.gz" --repo ihjas-ahammed/Arcane
   git add -A && git commit -m "release: Linux bundle $VER ($CODE)" && git push origin HEAD:revive2
   ```
   Then set `linux_url` and `linux_filename` in the Firebase pointer (step 4).

## Known gap

The app does not install an update unless it finds a SHA-256 hash for the APK. Hashes and signatures come from `builds/update_info.json` on `revive2`, and the pointer does not carry them. These steps do not write that file, so installs are blocked until it is added to the process.

## Firebase rules

- RTDB keys cannot contain `.`, `$`, `#`, `[`, `]` or `/`. Do not put checksum or signature maps under `/app_updates/latest`.
- The Firebase CLI on PATH may be an old npx cache. Use `~/.npm-global/bin/firebase`.
- Firebase Storage is not used and will not be enabled.
