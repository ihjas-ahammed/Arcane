0: pull latest changes with git pull --rebase origin <branch> (sync upstream changes)
0b: backup current firebase db json to backups/:
    `mkdir -p backups && curl -s "https://task-dominion-default-rtdb.asia-southeast1.firebasedatabase.app/.json" -o "backups/firebase_db_$(date +%Y%m%d_%H%M%S).json"`
1: update version name to today (YYYY.M.D) in pubspec.yaml
2: update version code (increment, also today: 21YYMMDDxx) in pubspec.yaml
3: update latest.md with release notes
4: clean and build release APKs locally:
   - remove old APKs from builds/ (`rm -f builds/*.apk`)
   - build split APKs: `flutter build apk --release --split-per-abi`
   - copy APKs: copy each `build/app/outputs/flutter-apk/app-<abi>-release.apk` to `builds/missions-v${VERSION}-b${VCODE}-${ABI}.apk`
5: update builds/update_info.json and builds/latest.json with version name, version code, published_at, and APK URLs
   - sync latest update metadata to Firebase Realtime Database for instant delivery:
     `curl -s -X PUT -H "Content-Type: application/json" -d @builds/update_info.json "https://task-dominion-default-rtdb.asia-southeast1.firebasedatabase.app/app_updates/latest.json"`
6: copy latest.md to builds/latest.md (`cp latest.md builds/latest.md`)
7: commit all changes and push (`git commit` and `git push origin HEAD:<branch>`)
