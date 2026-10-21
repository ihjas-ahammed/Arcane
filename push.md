# Release process

Version: name is `YYYY.MM.DD`, code is `21YYMMDDxx` (xx = build number for that day, starting at 01). Every release gets a new code.
Example, second build on 2026-10-21: `version: 2026.10.21+2126102102`.

Android is built per ABI. The build adds an offset to the code: arm64-v8a = code + 2000, armeabi-v7a = code + 1000. The phone runs arm64, so a new base code must be above the code the phone has installed.

Set these before you start (example values):

```
VER=2026.10.21
BASE=2126102102
TAG=v2026.10.21-b2126102102
REPO=ihjas-ahammed/Arcane
REL=$HOME/arcane-release/$TAG
mkdir -p "$REL"
```

## Steps

1. Set the version in `pubspec.yaml`:
   `version: $VER+$BASE`

2. Build the split APKs:
   ```
   flutter build apk --release --split-per-abi
   cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk   "$REL/missions-v$VER-b$BASE-arm64-v8a.apk"
   cp build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk "$REL/missions-v$VER-b$BASE-armeabi-v7a.apk"
   ```
   Check the codes inside the APKs before publishing. `aapt` is in the Android build-tools folder:
   ```
   aapt dump badging "$REL/missions-v$VER-b$BASE-arm64-v8a.apk" | grep -m1 "^package:"     # versionCode=$((BASE+2000)), versionName=$VER
   aapt dump badging "$REL/missions-v$VER-b$BASE-armeabi-v7a.apk" | grep -m1 "^package:"   # versionCode=$((BASE+1000))
   ```

3. Commit, push, and publish the Android release. Then generate the checksums and signatures (step 4) and commit them. Use `git add` on the files you mean to commit. Never commit `project_snapshot*.txt` or `.release_keys/`.
   ```
   git add -A && git reset -q -- 'project_snapshot*.txt' && git commit -m "release: Missions $VER ($BASE)"
   git push origin HEAD:revive2
   ```

4. Generate the SHA-256 checksums, sizes, and Ed25519 signatures. This writes `builds/update_info.json` and `builds/latest.json` in the repo, and a pointer file in `$REL`. It includes the Linux bundle only if it exists in `$REL` (step 5). Run it again after step 5 to add the Linux bundle. The signing key is `.release_keys/update_signing.pem`; its public key must match the one compiled into the app.
   ```
   python3 - <<'PY'
   import base64, hashlib, json, os, re, subprocess, tempfile, datetime, pathlib
   VER, BASE = re.search(r'^version:\s*([^+\s]+)\+(\d+)', pathlib.Path('pubspec.yaml').read_text(), re.M).groups()
   BASE = int(BASE); TAG = f'v{VER}-b{BASE}'; REPO = 'ihjas-ahammed/Arcane'
   BASEURL = f'https://github.com/{REPO}/releases/download/{TAG}'
   REL = pathlib.Path(os.environ['REL']); KEY = pathlib.Path('.release_keys/update_signing.pem')
   public = subprocess.check_output(['openssl', 'pkey', '-in', str(KEY), '-pubout', '-outform', 'DER'])[-32:]
   expected = re.search(r"const releasePublicKey = '([^']+)'", pathlib.Path('lib/src/services/release_signature.dart').read_text())[1]
   if base64.b64encode(public).decode() != expected: raise SystemExit('Signing key does not match the app')
   arches = {'arm64-v8a': 2000, 'armeabi-v7a': 1000}
   names = {abi: f'missions-v{VER}-b{BASE}-{abi}.apk' for abi in arches}
   linux = f'missions-v{VER}-b{BASE}-linux-x86_64.tar.gz'
   packages = list(names.values()) + ([linux] if (REL / linux).is_file() else [])
   hashes, signatures, sizes = {}, {}, {}
   for name in packages:
       path = REL / name
       if not path.is_file() or path.stat().st_size < 1024 * 1024: raise SystemExit(f'Missing or truncated: {path}')
       digest = hashlib.sha256(path.read_bytes()).hexdigest()
       url = f'{BASEURL}/{name}'
       hashes[url] = digest; sizes[url] = path.stat().st_size
       with tempfile.TemporaryDirectory() as tmp:
           msg = pathlib.Path(tmp) / 'message'; sig = pathlib.Path(tmp) / 'signature'
           msg.write_text(f'arcane-release-v1\n{BASE}\n{digest}\n{url}\n')
           subprocess.run(['openssl', 'pkeyutl', '-sign', '-rawin', '-inkey', str(KEY), '-in', str(msg), '-out', str(sig)], check=True)
           signatures[url] = base64.b64encode(sig.read_bytes()).decode()
   meta = {
       'version_code': BASE, 'version_name': VER,
       'published_at': datetime.datetime.now(datetime.timezone.utc).isoformat().replace('+00:00', 'Z'),
       'min_supported_version_code': 2026010101,
       'apk_filename': names['arm64-v8a'], 'apk_url': f'{BASEURL}/{names["arm64-v8a"]}',
       'apk_arch_urls': {abi: f'{BASEURL}/{n}' for abi, n in names.items()},
       'apk_arch_version_codes': {abi: BASE + off for abi, off in arches.items()},
       'package_sha256': hashes, 'package_signatures': signatures, 'package_sizes': sizes,
       'changelog_url': f'https://raw.githubusercontent.com/{REPO}/revive2/builds/latest.md',
   }
   if linux in packages:
       meta.update({'linux_filename': linux, 'linux_url': f'{BASEURL}/{linux}', 'linux_arch_urls': {'x86_64': f'{BASEURL}/{linux}'}})
   for f in ['builds/update_info.json', 'builds/latest.json']:
       pathlib.Path(f).write_text(json.dumps(meta, indent=2) + '\n')
   # Pointer for Firebase: no checksum or signature maps (RTDB keys cannot hold '.' or '/').
   pointer = {k: v for k, v in meta.items() if k not in ('package_sha256', 'package_signatures', 'package_sizes')}
   (REL / 'pointer.json').write_text(json.dumps(pointer, indent=2) + '\n')
   print(f'Signed metadata for {TAG}: {len(hashes)} packages')
   PY
   ```

5. Build the Linux bundle, package it, and attach it to the release. Then run step 4 again so the metadata includes it, and commit and push (step 3).
   ```
   flutter build linux --release
   tar -czf "$REL/missions-v$VER-b$BASE-linux-x86_64.tar.gz" -C build/linux/x64/release/bundle .
   gh release upload "$TAG" "$REL/missions-v$VER-b$BASE-linux-x86_64.tar.gz" --repo $REPO
   ```

6. Publish the release (once, after step 2 and before step 4 is re-run for Linux):
   ```
   gh release create "$TAG" "$REL"/missions-v$VER-b$BASE-arm64-v8a.apk "$REL"/missions-v$VER-b$BASE-armeabi-v7a.apk \
     --repo $REPO --target revive2 --title "Missions $VER ($BASE)" --notes "What changed in this release."
   ```

7. Update the Firebase pointer. Back up the current one first, then write the new one and read it back:
   ```
   ~/.npm-global/bin/firebase database:get /app_updates/latest --project task-dominion > "$REL/pointer_before.json"
   ~/.npm-global/bin/firebase database:set /app_updates/latest "$REL/pointer.json" --project task-dominion --force
   ~/.npm-global/bin/firebase database:get /app_updates/latest --project task-dominion | grep -o '"version_code":[0-9]*'
   ```
   Run this after step 4 for Android, and again after step 5 for Linux.

8. Verify the published files:
   - Download the arm64 APK from the release and check its SHA-256 against `builds/update_info.json`.
   - Check that `https://raw.githubusercontent.com/$REPO/revive2/builds/update_info.json` shows `"version_code": $BASE`.

## Notes

- The app will not install an update unless `builds/update_info.json` on `revive2` has the SHA-256 and signature for the APK. Step 4 writes them. Push them (step 3) before the pointer changes (step 7).
- `.release_keys/` and `debug.keystore` are not part of the release commit.
- Firebase RTDB keys cannot contain `.`, `$`, `#`, `[`, `]` or `/`. Keep the checksum maps out of `/app_updates/latest`.
- Use `~/.npm-global/bin/firebase`. The Firebase CLI on PATH may be an old npx cache.
- Firebase Storage is not used and will not be enabled.
