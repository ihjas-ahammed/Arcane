# Arcane: Data Hazard Audit

**Date:** 2026-10-11
**Branch / version scanned:** `revive2` @ `2e2a62f` (v2026.10.9+2126100904)
**Scope:** every path that saves, loads, merges, restores, backs up, or deletes user data: local SQLite, JSON caches, SharedPreferences, file backups, Firebase RTDB, Firestore, the self-updater, the widget and notification bridges, and the release process (`push.md`).

**Goal:** zero data loss. Saves and syncs must also stay fast as the data grows.

---

## 0. TL;DR

| # | Severity | Hazard | Where |
|---|---|---|---|
| C1 | 🔴 Critical | A fresh or empty install starts from defaults, and the next end-of-day push **overwrites the cloud** with them | `app_provider.dart:870-889`, `sync_mixin.dart:212-277` |
| C2 | 🔴 Critical | One malformed record makes a whole section fail to load. The error is swallowed, and the default or partial state is then **saved over the good data** | `app_provider.dart:1042-1062`, `task_models.dart:359+` |
| C3 | 🔴 Critical | `importStateIntoDatabase` **deletes all local rows** on any error, including a failed pre-import backup write | `local_storage_service.dart:291-314` |
| C4 | 🔴 Critical | The SQLite part splitter can cut an emoji or other surrogate pair in half. This silently corrupts text, and during an import it triggers C3 | `state_database.dart:94-105` |
| C5 | 🔴 Critical | "Purge all data" deletes the **cloud first**, makes no final backup, and isn't awaited | `account_and_data_settings_section.dart:255`, `app_provider.dart:1817` |
| C6 | 🔴 Critical | The cloud keeps **one live copy only**. The previous version is deleted right after each push, so a bad push can't be undone | `storage_service.dart:405-409, 826-830` |
| C7 | 🔴 Critical (verify) | The release script reads `/.json` and writes `app_updates` on RTDB **without auth**. If that works, every user's data is public, and anyone can push a fake update | `push.md` steps 0b and 5 |
| H1 | 🟠 High | The cloud backup runs only once a day, and only when the briefing is generated. RPO is 24 h or more, and can be days | `sync_mixin.dart:87-90` |
| H2 | 🟠 High | `autoSaveEnabled = false` also silently disables **manual** cloud sync | `sync_mixin.dart:214, 348` |
| H3 | 🟠 High | Multiple devices: last writer wins on whole collections, with no conflict detection | `sync_mixin.dart:375-513` |
| H4 | 🟠 High | "Replace All" restore doesn't actually replace, and no snapshot is taken before a restore or merge | `app_provider.dart:1845-1910`, `finance_mixin.dart:51-59`, `user_mixin.dart:410-434` |
| H5 | 🟠 High | The DB editor and NORA `custom_db_edit` write raw state, with merge semantics and an immediate cloud push | `database_editor_screen.dart:32-41`, `app_provider.dart:3890-3903` |
| H6 | 🟠 High | Linux Firestore read-modify-write wipes sibling fields when the read fails | `storage_service.dart:981-991, 1033-1042, 1086-1095` |
| H7 | 🟠 High | The self-updater calls `exit(0)` without flushing pending saves | `update_service.dart:794, 813` |
| H8 | 🟠 High | Pending energy logs are drained before user data loads, so they're lost | `app_provider.dart:842, 483-535` |
| H9 | 🟠 High | `getUserData()` returns `null` both for "no data" and for "network error" | `storage_service.dart:306-309, 724-727` |
| H10 | 🟠 High | A partial cloud push leaves the cloud holding collections from different times | `sync_mixin.dart:432-475` |
| H11 | 🟠 High | Sign-out doesn't reset all state, so SOPs, tracked skills, goals and health data leak into the next account | `app_provider.dart:994-1018` |
| M1-M16 | 🟡 Medium | Performance (whole state serialized on every `notifyListeners`), full re-uploads, unbounded growth, backups kept on the same device, Linux storage in `~/Documents`, web quota, ledger races, and more | §4–§5 |
| L1-L7 | 🔵 Low | Repo bloat (2.3 GB `.git`), device clock trust, widget action slot, and others | §7 |

**Recommended order:** C7 (verify the rules today) → C3, C4, C2 → C1 → H7, H8 → C6 → C5 → H1, H2 → H4, H5, H6, H9, H10, H11 → performance.

---

## 1. How data flows today (map)

```
             ┌──────────── UI / actions / NORA / widgets / notifications ───────────┐
             │                                                                      │
             ▼                                                                      │
  AppProvider (in-memory)  ── markDirty() / notifyListeners() ──►  _saveLocalSnapshot()
             │                                                     │  getFullAppState() (UI isolate)
             │                                                     ▼
             │                                   LocalStorageService.saveState (queued)
             │                                     ├─ compute(jsonEncode per collection)
             │                                     ├─ diff vs _lastWritten
             │                                     ├─ StateDatabase.writeCollections (SQLite, 256K parts)
             │                                     └─ daily_backup_<uid>_<date>.json (7 kept, same dir)
             │
             └─ syncEndOfDay() ← daily briefing / manual button / retry timer
                   └─ StorageService (RTDB)
                        ├─ tasks/settings/finance/health/trading/launcher → chunks/<name>/<ver>/pNNNNN + pointer
                        ├─ history → data/history/<date>  (update, additive)
                        ├─ reflections → data/reflections/<id> (update, additive)
                        └─ lastModified (verified read-back)
                   Firestore: users/<uid>/daily|weekly|monthly (briefings, reports)
```

**Strengths already in place:** saves are queued and serialized, collections are diffed, SQLite transactions are used, the cloud pointer flips only after the parts are written, the edit-generation counter protects edits made during a push, a load error blocks writes (`localLoadError`), the daily-backup shrink guard exists, the 24 h action ledger exists, and tests exist for load guards and merges. The hazards below are the gaps that are left.

---

## 2. 🔴 Critical: direct data-loss paths

### C1. An empty local DB plus the end-of-day push overwrites the cloud
**Where:** `lib/src/providers/app_provider.dart:870-889` (`_loadLocalState` → `_resetToInitialState()` when `loadState` returns `null`), then `lib/src/providers/mixins/sync_mixin.dart:212-277, 437-475` (`syncEndOfDay`, `force: true`).

**Scenario:** new phone, reinstall, Android "Clear storage", first run on Linux, a migration that fails, or C3 wiping the rows. Then:
1. `loadState()` returns `null`. The app silently starts from the templates (`lastModified: 0`).
2. The user adds one task. The daily briefing runs `syncEndOfDay()`.
3. The **force** push replaces `tasks`, `settings`, `finance`, `health`, `trading` and `launcher` in the cloud with near-empty data. Only `history` and `reflections` survive, because they're written additively.
4. Because of C6, the previous cloud version has already been deleted.

**Solutions (do all of them):**
1. **Cloud-attach gate.** When local is empty, call `getLastModified(uid)` before entering normal mode. If it's `> 0`, show a blocking screen: *"Cloud data found (last saved X). RESTORE (recommended) / START FRESH (type DELETE)"*. Until the user picks one, set `localLoadError`-style read-only mode so nothing is pushed.
2. **Persist a cloud baseline.** Store `cloudBaselineVer` / `cloudBaselineTs` (SharedPreferences and the SQLite meta table) when the device pulls or explicitly starts fresh. `syncEndOfDay` refuses to push if the cloud `lastModified` is newer than the baseline and this device never merged it.
3. **Shrink guard on cloud push.** Keep a small manifest in the cloud (`users/<uid>/manifest`) with counts: tasks, subtasks, transactions, reflections, history days. Abort the push and notify the user if any count drops by more than 30% (or to 0 from more than 0) without an explicit "I deleted this" confirmation.
4. Fix C6 so that even a bad push can be rolled back.

### C2. Swallowed partial-load errors, then an overwrite
**Where:** `lib/src/providers/app_provider.dart:1042-1062` wraps each section in `try { … } catch { debugPrint }`. The models use strict casts: `SubTask.fromJson` uses `json['id'] as String`, `json['name'] as String`, `as int?` (which fails on `12.0`), and `DateTime.parse` (which fails on a bad string) (`lib/src/models/task_models.dart:359-400`). Other models behave the same way: `app_state_models.dart:173`, `chatbot_models.dart:53`.

**Scenario:** one subtask has `"currentTimeSpent": 12.0`, a bad date, or a missing name. This can come from a NORA `custom_db_edit`, the DB editor, an old backup import, or a JS-generated JSON. Then:
- `loadTaskState` throws on the first line, so **`mainTasks`, `completedByDay`, `projects`, `routineLists`, `goals` and `goalPlaces` are all skipped**.
- `localLoadError` stays `null`. `endDataLoad()` and `notifyListeners()` run, and the save writes the in-memory defaults over the `mainTasks` and `completedByDay` rows. **All history is lost locally.**
- If it's the first save of the day, the shrunken state also becomes today's daily backup.

**Solutions:**
1. **Per-item tolerance:** parse lists item by item (`for (e in list) try { … } catch { quarantine.add(e) }`). Keep the bad raw items in a `_quarantine` collection that is saved and shown in Data Recovery. Never drop them.
2. **Never write a collection that failed to load:** keep `Set<String> _failedCollections`. `LocalStorageService.saveState` and the cloud push skip those keys, and the UI shows a "Some data could not be read" banner with COPY ERROR (reuse `LocalDataErrorScreen`).
3. **Lenient casts:** use `(json['x'] as num?)?.toInt()`, `DateTime.tryParse`, and `json['name']?.toString() ?? ''` everywhere in `fromJson`.
4. **Test:** load a state with one corrupted subtask and assert that the other tasks and the full history survive a save/load round trip.

### C3. Import deletes all local rows on failure
**Where:** `lib/src/services/local_storage_service.dart:291-314`.
```dart
} catch (e, stack) {
  await StateDatabase.instance.deleteUser(userId);   // ← wipes everything
```
**Scenario:** the disk is full while writing `before_import_*.json`, `readCollections` throws, or the verification fails (see C4). The catch block deletes **all** rows, including the ones that were never replaced. On the next start, `loadState()` returns `null`, which leads to C1.

**Solutions:**
- Do the whole replace inside **one SQLite transaction**: delete, insert, and verify (read back inside the transaction, or compare a hash). If verification fails, throw inside the transaction so SQLite rolls back. **Never call `deleteUser` in the catch.**
- Write the `before_import` backup with `tmp` + `flush` + `rename`. If it fails, **abort the import** before touching the DB.
- Legacy-JSON migration path (`loadState` → `importStateIntoDatabase`): keep the legacy `.json` file until the DB has been verified, and rename it to `.migrated` afterwards rather than deleting it.

### C4. SQLite chunking splits surrogate pairs (emoji corruption)
**Where:** `lib/src/services/state_database.dart:94-105`. The code splits every `256 * 1024` UTF-16 code units with no surrogate check. (The cloud splitter in `storage_service.dart:40` already does this check.)

**Why it corrupts:** both sqflite (platform channel) and `sqlite3` FFI encode strings to UTF-8. A lone high or low surrogate is replaced by `U+FFFD`. Reading the parts back gives `"…�" + "�…"` instead of the emoji. The JSON stays valid, so the **corruption is silent** on normal writes. During an import, `mapEquals` fails, which triggers C3 and wipes the DB.

**Solutions:**
- Copy the cloud guard: `if (isHighSurrogate(json.codeUnitAt(end - 1))) end -= 1;`.
- Better: store each part as a **BLOB of UTF-8 bytes** (split the bytes, not the string), and add a `sha256` column per collection that is verified on read.
- **Test:** build a collection where an emoji sits at index 262143, then write, read and compare.
- **Repair:** scan existing rows for `�` pairs at part boundaries, and tell the user which collections were affected (they can restore those records from cloud history or backups).

### C5. "Purge all data" deletes the cloud first, without a backup or await
**Where:** `lib/src/widgets/settings/sections/account_and_data_settings_section.dart:255` (not awaited, so the "purged" snackbar shows before anything has happened), and `lib/src/providers/app_provider.dart:1817-1823` (cloud delete, then local clear).

**Solutions:**
1. Automatically write a final export to `backups/before_purge_<ts>.json` **and** open the share sheet first.
2. Ask the user to type `PURGE` to confirm, `await` the operation, and show the real result.
3. **Soft-delete the cloud:** move `users/<uid>/data` to `users/<uid>/trash/<ts>` (keep it 30 days) instead of calling `remove()`.
4. Also delete or trash the Firestore `daily`, `weekly` and `monthly` collections. Today they survive the purge, and `fetchDailyReportsFromCloud` writes old briefings back into the "empty" history (`app_provider.dart:970`).

### C6. The cloud holds a single copy, and the old version is deleted on every push
**Where:** `lib/src/services/storage_service.dart:405-409` and `826-830` (`partsRef.child('$oldVer').remove()`).

The versioned chunk layout (`chunks/<name>/<ver>/pNNNNN`) already exists. The code just throws the old version away. Any bad push (C1, C2, H5, an AI edit, a bug) is **permanent** in the cloud.

**Solutions:**
1. **Keep the last N versions per chunk** (for example 14 daily plus 8 weekly). Instead of deleting `oldVer`, append it to `users/<uid>/versions/<ts> = {tasks: ver, settings: ver, …, lastModified}`, then run a pruner that deletes chunk versions no manifest references any more (this also fixes the M7 orphans).
2. Add a **"Restore from date…"** list in Cloud Sync settings, built from `versions/`.
3. **Weekly offsite snapshot:** gzip the full JSON and upload it to Firebase Storage `backups/<uid>/<yyyy-ww>.json.gz`. It's cheap and independent of RTDB.
4. Optional: client-side encrypt snapshots with a user passphrase (journals and finance are sensitive).

### C7. RTDB root and `app_updates` may be world-readable and writable (verify now)
**Where:** `push.md`
- Step 0b: `curl -s "https://task-dominion-default-rtdb…/.json" -o backups/…` (no auth token).
- Step 5: `curl -X PUT … /app_updates/latest.json` (no auth token).

If these commands succeed, the database rules allow public read of the **whole tree** (every user's reflections, finance and journals) and public write to at least `app_updates`. The DB URL is in the repo (`lib/firebase_options.dart`, `android/app/google-services.json` are tracked). Anyone could then:
- download all user data, or
- publish a fake update. The updater checks only that the file is larger than 1 MB (`update_service.dart:654`), with no signature or hash, and on Linux it runs `cp -rf` over the app and relaunches it. That is code execution, which can wipe or exfiltrate data.

**Solutions:**
1. **Check today** (should print `Permission denied`): `curl -s "https://task-dominion-default-rtdb.asia-southeast1.firebasedatabase.app/.json?shallow=true"`
2. Rules:
   ```json
   { "rules": {
       "users": { "$uid": { ".read": "$uid === auth.uid", ".write": "$uid === auth.uid" } },
       "app_updates": { ".read": true, ".write": false }
   } }
   ```
   Keep the rules in the repo as `database.rules.json` and `firestore.rules`, and deploy them with `firebase deploy --only database,firestore:rules` so they can't drift.
3. Release script: use authenticated CLI calls, `firebase database:get / --project task-dominion > backups/…` and `firebase database:set /app_updates/latest.json builds/update_info.json`.
4. Updater: publish a `sha256` (and ideally an Ed25519 signature) in `update_info.json` and verify it before installing. Android already checks the version code. Add the hash check on both platforms.

---

## 3. 🟠 High

### H1. Cloud backup runs once a day at most (RPO of 24 h or more)
**Where:** `sync_mixin.dart:87-90`. The only automatic push is `syncEndOfDay()`, triggered by the daily briefing (`app_provider.dart:2275, 2796`). If no briefing is generated (a skipped day, an AI error), **nothing is backed up for days**. Losing the device loses everything since the last briefing.

**Solutions:**
- Add a **time-based push**: if `now - lastSuccessfulCloudPush > 6 h` and there are unsaved changes, push on app pause or resume (debounced by 10 min) and from an Android WorkManager job (unmetered network and charging constraints). Use a `Timer` on Linux.
- Persist `lastSuccessfulCloudPush` (it's in memory only today: `_lastSuccessfulSaveTimestamp`).
- In the UI, show *"Last cloud backup: 3 h ago"* in the HUD or Settings, turning amber after 24 h and red after 72 h, with a notification after 48 h.
- Make pushes incremental (see M3) so frequent pushes stay cheap.

### H2. Turning off auto-save also turns off manual sync
**Where:** `sync_mixin.dart:214` returns `false` when `!settings.autoSaveEnabled`. `manuallySaveToCloud()` (`:348`) goes through the same function, so the user sees *"Cloud unreachable…"* and the data never leaves the device.

**Solution:** add a `manual: true` parameter that bypasses the flag. Report "Auto-backup is OFF" accurately, and show a persistent warning while it's off.

### H3. Multiple devices: whole-collection last-writer-wins
**Where:** `sync_mixin.dart:375-513` (force push of full collections). `watchLastModified` exists but is never used.

With a phone and the Linux desktop on the same account, each nightly push overwrites the other device's `tasks`, `finance`, `health` and `settings`.

**Solutions:**
- Before pushing, read the cloud `lastModified` and `lastPushedBy` (add a device id). If the cloud is newer than this device's baseline, **pull and merge first** (`mergeAppStateFromMap`), then push. Use an RTDB transaction on `lastModified` for optimistic concurrency.
- Long term: merge per entity with `updatedAt` (newest wins) and tombstones (`isDeleted`, `deletedAt`) instead of whole collections.
- Show *"Another device (Linux) pushed newer data 2 h ago, merge now?"*.

### H4. "Replace All" isn't a replace, and there's no pre-restore snapshot
**Where:** `app_provider.dart:1845-1910` → `loadStateFromMap`. That function **merges** in several places: reflections, SOPs and tracked skills use `putIfAbsent` (`user_mixin.dart:410-434`), and transactions and categories do too (`finance_mixin.dart:51-59`). So:
- local versions win over the cloud for edited records,
- deleted local records stay, and
- no snapshot is taken before a cloud or local restore runs.

Merge mode also uses `putIfAbsent`, so the older local version always wins over a newer incoming edit.

**Solutions:**
- Always write `backups/before_restore_<ts>.json` first (reuse the preserve logic in `importStateIntoDatabase`).
- Implement Replace as `importStateIntoDatabase(uid, normalized)` (atomic, verified), then `_loadLocalState(uid)`.
- Merge should compare `updatedAt` and keep the newest, not use `putIfAbsent`. Add `updatedAt` to models that lack it (transactions, reflections).

### H5. Raw state editing (DB editor and NORA `custom_db_edit`)
**Where:**
- `lib/src/screens/database_editor_screen.dart:32-41`: `loadAppStateFromMap` (merge semantics, so edits to existing transactions or reflections are **silently ignored** and deletions don't stick), then an immediate `manuallySaveToCloud()` with no snapshot.
- `app_provider.dart:3890-3903`: the AI can write **any JSON path** of the whole state, which is then re-loaded through `loadStateFromMap` and is open to C2.

**Solutions:**
- Snapshot first. Apply the edit with `importStateIntoDatabase` (a true replace) and reload. Validate by parsing every model before committing (and refuse to commit if any item fails).
- NORA: keep an **allowlist** of paths, show a diff preview that needs a user tap, record it in `AppActionLedgerService` so it can be undone, and forbid replacing or removing top-level collections.
- Don't auto-push to the cloud from the editor. Let the normal push cycle carry it.

### H6. Linux Firestore read-modify-write wipes sibling fields
**Where:** `storage_service.dart:981-991` (daily), `1033-1042` (weekly), `1086-1095` (monthly).
```dart
try { existing = …(await docRef.get()).map; } catch (_) {}   // failure → {}
existing[type] = data;
await docRef.set(existing);                                   // overwrites the doc
```
A transient read error is treated as "empty", so the `briefing` and `report` siblings are erased.

**Solution:** use firedart `docRef.update({...})` (merge). If you must read first, only treat *NOT_FOUND* as empty and rethrow anything else.

### H7. The self-updater exits without flushing saves
**Where:** `update_service.dart:794, 813` call `exit(0)` immediately after spawning the updater script.

**Solution:** before `exit(0)`, run `await provider.forceLocalBackup()`, wait for `LocalStorageService._saveQueue`, `await StateDatabase.instance.close()`, and optionally run `syncEndOfDay(maxAttempts: 1)` with a short timeout. Also make the updater script wait until the PID is really gone (it gives up after 5 s and copies anyway).

### H8. Energy logs are drained before user data loads
**Where:** `app_provider.dart:842` (`_initialize`, before auth and the local load) and `483-535`. The keys are **removed from SharedPreferences first**, and the logs are added to the default in-memory state. Then `_loadLocalState` replaces that state, so the logs are lost. Every log is also filed under *today*, whatever its timestamp says.

**Solutions:** drain only after `_loadLocalState` succeeds (in `_onAuthStateChanged`, after the load). Remove the prefs key only after the local save completes. Use the date from each log's own timestamp. Native Android and Dart both read-modify-write `pending_energy_logs`, so move that key to an append-only file or give each side its own key.

### H9. `getUserData()` returns `null` for both "no data" and "error"
**Where:** `storage_service.dart:306-309, 724-727`. The restore screen reports *"No cloud backup found"* on a network error or a missing chunk part. Any future automatic logic that treats `null` as "new user" would be destructive.

**Solution:** return a result type `{status: found | empty | error, data, error}` (or throw on error), and update the callers in `sync_mixin.dart:305` and `app_provider.dart:1853`.

### H10. A partial push leaves the cloud inconsistent
**Where:** `sync_mixin.dart:432-475`. Each chunk's pointer flips independently. If `tasks` fails but `history` and `finance` succeed, the cloud now mixes collections from different times (history says a task was done, but the tasks chunk is older).

**Solution:** two-phase commit. Upload the parts for all chunks first, then flip **all** pointers plus `lastModified` plus the manifest in **one multi-path `update()`**, which is atomic in RTDB. This also gives C6 its manifest entry for free.

### H11. Sign-out doesn't clear all in-memory state, so data leaks between accounts
**Where:** `_resetToInitialState` (`app_provider.dart:994-1018`) resets tasks, finance and reflections, but **not** `sops`, `trackedSkills`, `goals`, `routineLists`, `goalPlaces`, `foodItems`/`healthLogs`, or the launcher (the trading book is reset). `loadUserState` then **merges** the incoming SOPs and skills into whatever is in memory (`user_mixin.dart:377-434`). Account B ends up with account A's SOPs and skills, and saves them.

**Solution:** add a single `resetAll()` that rebuilds every mixin's fields from their constructors, and assert in a test that sign-out followed by sign-in with an empty account leaves no data from the previous account.

---

## 4. 🟡 Medium: save integrity and backups

### M1. Backups live on the same device as the data
`backups/`, `ledger/` and `arcane_state.db` all sit in the app documents directory (`local_storage_service.dart:48-55`). Uninstalling, clearing data, or losing the phone removes **all** of them. Only 7 daily backups are kept.

**Solution:** keep 7 daily, 4 weekly and 6 monthly backups (grandfather-father-son). Copy the weekly one to a user-visible location (Android SAF folder such as `Download/Arcane/`, Linux `~/.local/share/arcane/backups`, or a user-picked folder). Add an optional weekly gzip upload to Firebase Storage (see C6).

### M2. Daily backups go stale, and the shrink guard drops legitimate changes
A daily backup is written only on the first save of each process each day (`_lastDailyBackupDay`), so it's usually a morning snapshot. The 70% guard skips the write instead of preserving both copies.

**Solution:** refresh the backup on pause if more than 2 h have passed. When the guard trips, write `daily_backup_<date>_shrunk.json` alongside the old file instead of skipping, and show a notice.

### M3. Manual and NORA backups are never pruned, and aren't atomic
`data_recovery_screen.dart:58-77` and `app_provider.dart:1916-1930` use `jsonEncode` on the UI isolate and `writeAsString` with no `flush` and no tmp-then-rename. Old files are never pruned.

**Solution:** encode with `compute`, write to a tmp file with flush, rename, and apply the same retention as M1.

### M4. Deletions never reach cloud history or reflections
`saveHistory` and `saveReflections` only `update()` (add) (`storage_service.dart:442-497`). Deleted days and reflections come back on the next cloud merge or restore. If `deleteReflection` fails while offline, the reflection comes back too.

**Solution:** use tombstones (`isDeleted`, `deletedAt`) that sync, and write `null` for removed keys during the push.

### M5. Cloud verification is shallow
Only the first and last parts plus `lastModified` are checked (`storage_service.dart:397-401, 487-493`). A bad middle part flips the pointer, and a later restore fails with "Missing cloud part", which is reported as "no backup" (H9).

**Solution:** store the `sha256` of the full JSON and the byte count in the pointer, verify them on restore, and verify the part count with a `?shallow=true` read after the upload.

### M6. Orphaned cloud chunks pile up
If reading `oldVer` fails, or the cleanup fails, the old parts stay forever. That costs storage and eats into the RTDB free tier. **Solution:** the manifest-based GC from C6.

### M7. Flat-map key collisions when cloud chunks are collapsed
`_parseRtdbData` (`storage_service.dart:113-253`) merges settings, tasks, finance and health into one flat map with `addAll`. Its catch-all decodes unknown nodes and also `addAll`s their keys at the top level. A future node can silently overwrite real keys.

**Solution:** keep each chunk namespaced, merge only known keys, and log collisions.

### M8. SQLite hardening
The DB has no WAL, no `synchronous` pragma, no integrity check, and schema version 1 with no migrations (`state_database.dart:28-47`).

**Solution:** set `PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL` (or `NORMAL` with WAL), run `PRAGMA quick_check` at startup (on failure, show the recovery screen with the latest backups), add a `meta` table (schema version, per-collection hash, `cloudBaseline`), and add `onUpgrade` migrations.

### M9. Linux and Windows store data in `~/Documents`
`getApplicationDocumentsDirectory()` returns `~/Documents` on Linux, so `arcane_state.db`, `backups/` and `ledger/` land in the user's Documents folder. They're easy to delete, and sync clients (Nextcloud, Dropbox, OneDrive) syncing a live SQLite file can corrupt it.

**Solution:** switch to `getApplicationSupportDirectory()` (`~/.local/share/me.ihjas.missions`) with a one-time migration: copy, verify, then leave the old files as a backup.

### M10. Web stores everything in localStorage
The whole state plus 7 daily backups go into localStorage (`local_storage_service.dart:65-69, 169-200`), which has a quota of about 5 MB. When the quota is hit, saves throw, and the code retries every 2 s forever.

**Solution:** use IndexedDB (`sqflite_common_ffi_web` or `idb_shim`), skip daily backups on web (or keep 1), and surface a quota error.

### M11. Action ledger (undo) races and silent resets
`app_action_ledger_service.dart:141-191`: flushes aren't serialized (concurrent actions share one `.tmp`), every action rewrites the full JSON including full before/after maps, and a corrupt file is replaced by an empty list and then overwritten.

**Solution:** queue the writes (like `LocalStorageService._saveQueue`), use an append-only JSONL file with daily rotation, and rename a corrupt file to `.corrupt-<ts>` instead of overwriting it.

### M12. The skill migration silently replaces the skill list
`initializeSkills()` (`user_mixin.dart:130-140`) replaces any skill list that doesn't match `WellbeingTheme.needNames`. Renaming one need wipes all skill XP.

**Solution:** map old names to new ones, keep the old list in `settings.legacySkills`, and cover it with a test.

---

## 5. 🟡 Medium: performance hazards

### M13. Every `notifyListeners()` serializes the whole state on the UI isolate
`SyncMixin.notifyListeners` (`sync_mixin.dart:133-144`) → `_saveLocalSnapshot()` → `getFullAppState()`, which calls `toJson` on every task, history day and transaction on the **main isolate**. Then `compute()` deep-copies that whole map into an isolate. There are about 130 call sites, and UI-only changes (`setAuthLoading`, `isSyncing`, HUD state) also trigger a full save. The result is jank and battery drain that grow with the data.

**Solutions:**
- Separate "UI changed" from "data changed": save only on `markDirty`, not on every `notifyListeners`.
- Serialize **only the dirty collections** (the dirty set already exists) and cache each collection's JSON.
- Debounce saves by 300–500 ms and flush on `paused`/`inactive`. That's already wired: `forceLocalBackup` in `app_provider.dart:259-275`.

### M14. Big collections are rewritten whole
`completedByDay` (marked "5MB+" in code comments) and `reflectionLogs` are each a single collection, so toggling one checkbox today re-encodes and rewrites years of history to SQLite.

**Solution:** store per-day rows (`history:<yyyy-mm-dd>`) and per-reflection rows, which makes the diff granular. This also makes M4 and M15 straightforward.

### M15. The cloud push re-uploads everything every night
`saveHistory` and `saveReflections` (`storage_service.dart:442-497`) send **every** day and **every** reflection, in batches of 5 or 8 with 60 ms pauses: thousands of requests per push, a long window for failures, and growing bandwidth and cost. On Linux, these paths also lack `_withRetry` (`storage_service.dart:867-926`).

**Solution:** keep a local hash per day or reflection of what was last pushed (in the SQLite meta table) and upload only what changed, using one multi-path `update()` per batch of about 200 KB. Add retries on Linux.

### M16. Every startup downloads the entire Firestore `daily` collection
`fetchRecentDailyData` (`storage_service.dart:560-582, 1000-1022`) calls `.get()` on the whole collection and takes the last 60 in memory. The same goes for weekly and monthly reports. It's also a **cloud-to-local overwrite** of `aiBriefing` and `startDayReport` (`app_provider.dart:970-994`), which contradicts the "local is authoritative" policy and can replace a newer local briefing with a stale cloud one.

**Solution:** query with `orderBy(FieldPath.documentId).limitToLast(60)` (or filter `date >= cutoff`), only fill fields that are missing locally, or compare `updatedAt`.

---

## 6. Operations and release process

| Item | Hazard | Solution |
|---|---|---|
| `push.md` 0b | The backup uses an unauthenticated curl (see C7), keeps no history, and is stored only in the gitignored `backups/` folder on one laptop | Use `firebase database:get` with auth, gzip and date-stamp the file, copy it to a second location (external drive or cloud bucket), and keep 30 copies |
| Rules not in the repo | No `database.rules.json` or `firestore.rules` is tracked, so rule changes in the console are invisible and can't be reviewed | Commit both and deploy them through the CLI |
| `builds/` in git | APKs and tarballs are committed, making `.git` **2.3 GB**. Pushes are slow and can fail, and GitHub rejects files over 100 MB | Publish builds as GitHub Releases or put them on Firebase Hosting; stop tracking `builds/*.apk` and `*.tar.gz`; optionally purge history with `git filter-repo` (coordinate first, because it rewrites history) |
| Restore drills | No regular test that a cloud restore actually works | Monthly: restore the latest cloud version into a test account and compare counts against the manifest |

---

## 7. 🔵 Low

- **L1. Device-clock trust:** `lastModified` and chunk `ver` come from the device clock, so a wrong clock breaks ordering. Use `ServerValue.timestamp` for `lastModified`.
- **L2. Widget cold-start queue holds one action:** `widget_action_router.dart:52` keeps only the last cold-start action, so earlier taps are dropped. Use a list.
- **L3. Native crash path:** `CrashGuard` kills the process (`ArcaneApplication.kt:58`). Local saves are near-immediate, so the risk is small, but M13's debounce must still flush on `paused`.
- **L4. Tracked client config:** `lib/firebase_options.dart`, `google-services.json` and `debug.keystore` are tracked. Client config is meant to be public, but combined with C7 it exposes the DB. The keystore should be untracked.
- **L5. Shared AI keys:** `secrets/apikeys` in Firestore can be read by any signed-in user, so the keys can be scraped and the quota abused. Proxy the calls through a Cloud Function, or rate-limit them.
- **L6. History key sanitizing:** `.`, `#`, `$`, `[`, `]` and `/` become `_` in history and reflection keys (`storage_service.dart:448, 477`). This is safe for dates and UUIDs, but non-UUID ids could collide. Keep the id inside the value (already done) and add a collision check.
- **L7. `_parseRtdbData` fallback** (`storage_service.dart:128-130`) decodes the same string again inside the `catch`, so it throws again. It's harmless but dead code.

---

## 8. Invariants to enforce (the no-data-loss contract)

1. **Never write a collection that wasn't successfully loaded** (C2).
2. **Never delete before the replacement is verified, and never delete in a `catch`** (C3, C6).
3. **Every destructive operation snapshots first:** restore, replace, import, purge, the DB editor, NORA edits (C5, H4, H5).
4. **The cloud is never a single copy:** keep N versions plus a weekly offsite snapshot (C6).
5. **A device may push only after it is attached to the cloud baseline** (C1, H3).
6. **At least one backup lives off the device** (M1).
7. **Errors are typed, never `null`** (H9).
8. **Byte-safe chunking with per-collection hashes** in both SQLite and the cloud (C4, M5).
9. **Load-bearing writes are awaited before exit or sign-out** (H7, C5).

---

## 9. Implementation roadmap

**Phase 0: this week (stop the bleeding)**
1. C7: run the curl check, lock the rules, commit the rules files, switch `push.md` to authenticated CLI calls.
2. C3: transactional import, no delete in the catch.
3. C4: surrogate-safe split (or BLOB parts) plus a test.
4. C2: per-item parsing, `_failedCollections` write-block, lenient casts.
5. C1: cloud-attach gate when local is empty, plus the cloud shrink guard.
6. H7 and H8: flush before exit, drain energy logs after load.
7. C5: backup before purge, await, soft-delete in the cloud.

**Phase 1: next 2 weeks (real backups)**
8. C6 and H10: version manifest, atomic multi-path pointer flip, N-version retention, "Restore from date…".
9. H1 and H2: time-based incremental pushes, a "last backup" indicator, and manual sync that ignores the auto-save flag.
10. H4, H5 and H11: snapshot before restore, true replace, guarded NORA edits, full reset on sign-out.
11. H6 and H9: Linux Firestore `update()`, typed cloud results.
12. M1: grandfather-father-son retention plus an off-device weekly export.

**Phase 2: performance and scale**
13. M13 and M14: dirty-only, debounced saves; per-day and per-reflection rows.
14. M15 and M16: incremental cloud uploads, bounded Firestore queries.
15. M8 and M9: WAL, integrity check, meta table; move Linux data to the app-support directory.
16. H3: multi-device merge before push (`updatedAt` and tombstones).
17. M10 and M11: IndexedDB on web, append-only ledger.

---

## 10. Tests to add (`test/`)

| Test | Covers |
|---|---|
| Emoji at the 256K boundary survives a write and read in `StateDatabase` | C4 |
| Import failure (simulated disk-full on the backup write) leaves the existing rows untouched | C3 |
| One corrupt subtask: the other tasks and the full history survive a load, save and reload cycle | C2 |
| Empty local DB with cloud `lastModified > 0`: `syncEndOfDay` refuses to push | C1 |
| A push whose counts shrink by more than 30% is blocked without confirmation | C1 |
| A failed tasks chunk upload leaves every cloud pointer unchanged (atomic flip) | H10 |
| The previous N cloud versions remain after a push, and restoring version N-1 works | C6 |
| Manual sync works with `autoSaveEnabled = false` | H2 |
| Energy logs queued before login appear after login, on their own dates | H8 |
| Sign-out, then sign-in as an empty account: no SOPs, skills or goals from the previous account | H11 |
| "Replace All" really removes local-only records, and a `before_restore` file exists | H4 |
| Linux daily-doc save with a failing read doesn't erase sibling fields | H6 |
| `getUserData` returns an error status (not "empty") on timeout | H9 |
| Save throughput: 3 years of synthetic history, and a single checkbox toggle stays under 16 ms on the UI isolate | M13, M14 |

---

*Method: I read the storage, sync, load, merge, restore, backup, ledger, updater and release code directly (`storage_service`, `local_storage_service`, `state_database`, `sync_mixin`, `user_mixin`, `task_mixin`, `finance_mixin`, `app_provider`, `app_action_ledger_service`, `update_service`, the data recovery, DB editor and settings screens, `push.md`, `.gitignore`, and the Android crash guard). I did not run anything: there is no Flutter SDK on this machine, and I made no network calls against the live database. C4 follows from how both sqflite and sqlite3 encode strings to UTF-8, and C7 depends on the live rules. Confirm both with the test or the curl check listed above.*

---

## 11. Implementation follow-up (2026-10-11)

The working-tree fixes, verification results, and remaining operational limits are recorded in [docs/data-hazard-implementation.md](docs/data-hazard-implementation.md). The original findings above describe the audited version, not the updated implementation.

The live anonymous shallow root check confirmed C7: HTTP 200 with 28 root nodes. Firebase project access is unavailable to the configured CLI account, so production rule deployment is still blocked. Do not consider the server-side exposure resolved merely because rule files now exist in this repository.
