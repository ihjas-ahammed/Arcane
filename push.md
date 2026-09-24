0: pull latest changes with git pull --rebase origin <branch> (sync automated CI build commits)
1: update version name to today in pubspec.yaml
2: update version code (increment, also today) in pubspec.yaml
3: update latest.md with release notes
4: update builds/update_info.json and builds/latest.json with version name, version code, and APK URLs
5: copy latest.md to builds/latest.md
6: commit and push
