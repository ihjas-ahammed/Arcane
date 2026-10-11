# Data hazard implementation record

Updated: 2026-10-11. Source audit: [report.md](../report.md).

## Current state

The local integrity, guarded restore, cloud snapshot, backup, and signed-update changes are implemented in the working tree. Production Firebase rule deployment remains blocked. This record distinguishes implemented protections from checks that still need project access or physical devices.

| Audit items | Implemented protection |
| --- | --- |
| C1, H3 | Devices persist a cloud timestamp and version baseline in preferences and SQLite. Restores attach to the immutable snapshot actually read; equal timestamps cannot hide a different committed version. An empty database rechecks the cloud even when an old baseline survives. Existing cloud data requires restore or explicit `DELETE` confirmation. Newer cloud data blocks uploads; head transactions reject concurrent commits. Collection-count shrink guards require explicit deletion confirmation. |
| C2 | Item recovery preserves readable task siblings and malformed raw records. Failed collections and raw quarantine records remain available in recovery state. Recovery errors block automatic local writes and cloud uploads. Trading and launcher state are validated and protected too. Retrying a repaired database clears old recovery guards. Import normalization rejects unreadable records instead of discarding them. |
| C3, C4, M8 | Replacement and read-back verification run in one SQLite transaction. Pre-import backup failure aborts before mutation. Unicode chunk boundaries preserve surrogate pairs; collection SHA-256 checksums detect corruption. SQLite uses WAL, full synchronous writes, a metadata table, and an opening integrity check. Legacy JSON survives as a dated migrated file. |
| C5 | Purge is awaited, requires `PURGE`, writes a final local recovery snapshot, and opens the export flow. Cloud recovery trash contains the live pointers and Firestore reports for 30 days. Every archived field is verified before live data is removed. Firestore report values are serialized so timestamps and document keys can be archived safely. |
| C6, H10, M4–M7 | Immutable content-addressed cloud parts are read back and verified. One head transaction commits all collection pointers and a server timestamp together. The latest 22 committed versions are listed for dated restore. Deleted history and reflections disappear from the new manifest; earlier versions remain recoverable. Encoded entity keys avoid sanitization collisions. The pruner preserves chunks referenced by retained manifests or recovery trash and protects staged uploads. |
| H1, H2 | Foreground lifecycle checks and a ten-minute timer attempt backups when dirty data has gone six hours without a successful push. Android WorkManager supplies a six-hour job on charging, unmetered connections. Successful-push time and unsynced edits survive restarts. Manual sync bypasses the automatic-backup switch. Settings show backup age and stale-backup colors. |
| H4, H5 | Replacement resets account state and uses a verified database import. Default categories cannot override restored categories. The JSON import screen and database editor use this path. Restore, merge, NORA edit, and replacement flows preserve recovery snapshots. Health merges retain records from both devices. Ambiguous record edits retain conflict copies for explicit review. |
| H6, H9, M16 | Linux Firestore updates patch individual fields without a failing read overwriting siblings. Cloud reads throw errors; `null` denotes absent data. Report queries are bounded, and cloud daily reports only fill missing local fields. |
| H7 | Installation flushes provider saves and the shared storage queue before replacement or exit. Recovery errors block installation. |
| H8, L2 | Energy replies use durable individual queue records. They drain after account load, keep their original dates, and are acknowledged only after local persistence. Android and Flutter share the same reply id to avoid duplicate logs; queued records carrying another account id remain untouched. Widget actions queue while account data is unavailable. |
| H11 | Account transitions are serialized. User, task, finance, health, trading, launcher, and report state are reset. The action ledger detaches on sign-out. A delayed legacy trading-cache read cannot repopulate state after an account reset. |
| M1–M3, M9–M12 | Local backups retain seven daily, four weekly, and six monthly snapshots. Guarded shrink snapshots and manual/import snapshots have bounded retention. Weekly gzip snapshots upload to Firebase Storage and are read back for verification. Desktop data migrates to the app support directory using a verified SQLite snapshot and checksum-checked file copies; original files remain. Browser storage uses IndexedDB. Native ledger writes are queued, append JSONL records, rotate by date, and preserve corrupted sources. Skill initialization retains legacy names and XP. |
| M13–M15 | UI notifications no longer trigger serialization. Data edits debounce for 350 ms, persist changed collections, and flush on lifecycle transitions. History and reflections occupy separate local entity rows and cloud entities. Unchanged cloud entities reuse their checksum pointers. |
| C7, L4, L5 | Owner-scoped RTDB, Firestore, and Storage rules are prepared in the repository. Shared provider credentials are no longer distributed to clients. Packages require SHA-256 and trusted Ed25519 signatures binding version, URL, and content. The release workflow uses authenticated publication; private keys and binary artifacts are excluded from new Git commits. Existing Git history is preserved. |

## Production security finding and deployment block

The anonymous request to the database root with `shallow=true` returned HTTP 200 and a map containing 28 root nodes on 2026-10-11. C7's root-read exposure is confirmed. Only the shallow access check was performed; user record contents were not downloaded and no anonymous write was attempted.

The Firebase CLI has a configured account, but `firebase database:get /.settings/rules --project task-dominion` fails with `Failed to get details for project: task-dominion`. Current deployed rules could not be fetched or changed. Computer-use inventory also reported no available browser sessions, so a signed-in Firebase Console session was unavailable as a fallback. Repository rule files are **not deployed**. Client changes cannot close this server-side exposure.

This project hosts other applications. An administrator must first preserve the existing RTDB, Firestore, and Storage rules, merge this application's restrictions with the other applications' rules, and deploy the reviewed result. Deny anonymous root access, restrict `users/$uid` to its owner, deny client writes to `app_updates`, and deny shared-provider-secret access. Use the authenticated procedure in [push.md](../push.md), then repeat the anonymous shallow root check and verify owner/cross-account access with test accounts. Never replace the unavailable administrator step with a public database write.

## Verification

- Regression tests cover rollback after failed backup/insertion, boundary emoji, malformed children, raw quarantine preservation, recovery retries, empty local data with a surviving baseline, timestamp collisions, captured restore versions and newer legacy cloud data, true replacement and recovery files, malformed import rejection, account isolation, unsynced edits after restart, energy reply dates and acknowledgment, health merges, restored categories, cloud atomicity, conflicts, shrink confirmation, retained-version restoration, checksum errors, incremental entities, full purge-archive verification, and signed packages.
- The final complete suite passed **282 tests** (`flutter test --no-pub --reporter expanded`). The targeted integrity/sync/reply run passed 31 tests. Static analysis completes with zero errors (`flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings`).
- Final Linux release compilation succeeded (`flutter build linux --release --no-pub`). The final Android release build succeeded for armeabi-v7a, arm64-v8a, and x86_64 (`flutter build apk --release --split-per-abi --no-pub`).
- The repository has no web application scaffold, so `flutter build web` cannot run. The IndexedDB backend passed a separate JavaScript compilation check; a browser quota/migration drill remains necessary.
- Static analysis completes with zero errors; five pre-existing unused-import warnings and informational diagnostics remain. The actual private release signing key matches the compiled public key; an OpenSSL-signed sample verified successfully in Dart and a tampered version was rejected. Shell syntax and Python compilation checks pass for the release scripts. Release publication requires an external backup destination and verifies the dated gzip copy before pruning either location to 30 snapshots. `git diff --check` passes.

## Practical limits and remaining validation

The conservative device-conflict behavior is to block a stale upload and require an explicit merge. Models without reliable edit timestamps retain both versions for conflict review; the implementation does not infer which edit is newer from a creation date. Entity-wide automatic last-edit merging and comprehensive tombstones beyond the covered task/transaction/reflection paths remain follow-up work.

Cloud retention currently keeps the latest 22 commits, rather than selecting 14 distinct daily and eight distinct weekly commits. Frequent manual pushes can shorten the retained time window; the separate local weekly/monthly and weekly offsite snapshots provide longer recovery windows.

Local entity partitioning reduces rewritten rows, but building/sending a history snapshot still visits the collection. The audit's 16 ms UI-isolate target has not been demonstrated with three years of data. Further performance changes should be driven by a profile-mode device measurement.

Android WorkManager scheduling, notification/native reply behavior, update installation/relaunch, browser IndexedDB quota handling, Firestore/RTDB restore interoperability, Storage permissions, and offsite restore need device or authorized-project integration drills. The current unit tests and successful compilation do not substitute for those checks. Firestore purge and RTDB purge are separate operations; a mid-purge failure preserves the verified recovery archive and surfaces an error.

During the report implementation pass, no release was published and no deployed cloud rules were changed. The subsequent release run is recorded below. The signing private key is stored only in `.release_keys/update_signing.pem`; its off-device custody must be maintained by the release operator. The already-published updater on older clients does not gain signature verification until those clients install the updated application.

## Monthly restore drill

1. Use an isolated test account/device and export its current state before the drill.
2. Restore the newest retained cloud version, then its predecessor. Compare task, subtask, transaction, reflection, and history-day counts against their manifests, and inspect representative Unicode text, notes, and timer records.
3. Download a weekly Storage gzip snapshot, decompress its JSON, validate it, and import it through the verified replacement flow. Confirm original dates and values survive. Keep this offsite restore independent of RTDB.
4. Verify pre-restore recovery files exist and restore one of them. Interrupt one staged cloud upload and confirm the previous head remains readable.
5. Record the versions, manifest counts, device/build, duration, and any error here. Avoid using a production account for destructive drills.


## Release run: 2026.10.11+2126101102

The `revive2` branch was synchronized with `git pull --rebase --autostash origin revive2`; the remote was already up to date. The version code was incremented from the prepared `2126101101` to `2126101102`, with version name `2026.10.11`.

The requested clean `scripts/release.sh prepare` run completed successfully: all 282 tests passed, static analysis reported zero errors, all three release APKs and the stripped Linux x86_64 bundle built, and all four packages passed local SHA-256 and Ed25519 verification. APK version codes match the metadata and every APK retains the previously published Android signing certificate. No signing keys are included in any package. GitHub publication completed, and all four assets were downloaded again and passed SHA-256, size, and Ed25519 checks. Anonymous requests to all four public package URLs returned HTTP 200.

An authenticated Firebase database backup attempt and the attempt to retrieve deployed rules both failed with `Failed to get details for project: task-dominion`. Neither a verified production database backup nor a deployable preserved copy of the existing rules could be obtained. `ARCANE_BACKUP_DESTINATION` is unset, so the external-copy step is also blocked. The private release key remains local and ignored by Git; off-device key custody remains an operator requirement.

GitHub artifact publication is separated from the administrator-only Firebase publication step. Release assets are published and downloaded for hash/signature verification before the branch exposes their updater metadata. The release notes disclose the unresolved production privacy rules. Firebase update metadata will be published only through an authenticated administrator after the backup and reviewed-rule deployment prerequisites succeed.


Published release: [Missions 2026.10.11, build 2126101102](https://github.com/ihjas-ahammed/Arcane/releases/tag/v2026.10.11-b2126101102). The annotated release tag points to application source commit `5da8f25471064701199c3241ff6847f4909903cd`. The APK signing certificate matches the previously published build.

| Verified downloadable package | SHA-256 |
| --- | --- |
| `missions-v2026.10.11-b2126101102-arm64-v8a.apk` | `98ff12598b48c1954eee332b19504e07a201f26088af8f18dfb6457f5590a4dd` |
| `missions-v2026.10.11-b2126101102-armeabi-v7a.apk` | `b0b22b9551ef24f59e99324235a8297911871b52f6da3ef93d4556b123cf564e` |
| `missions-v2026.10.11-b2126101102-x86_64.apk` | `8e5b08fb764ac41202a914a2aa17672bb5f6f480441b7d9fd872100272a78324` |
| `missions-v2026.10.11-b2126101102-linux-x86_64.tar.gz` | `465a99a3e68736dc5f0d5ad0502c01a51f66a1a5ac4b6ccb2ab1a0ff3d6ec8f6` |

The live Firebase pointer still advertises version `2026.10.9+2126100904` and raw branch URLs for its three APKs and Linux archive. Those four existing Git blobs have been retained unchanged from commit `2e2a62f` so pushing this branch cannot break the downloads advertised by that pointer. This introduces no new binary objects into Git history. New release binaries are distributed through GitHub Releases and remain ignored. Preparation preserves tracked compatibility APKs; these four files can be untracked once an authenticated administrator switches the Firebase pointer to verified GitHub URLs.

The production backup, external backup copy, reviewed rule deployment, Firebase update publication, and administrator-backed restore drill remain blocked. No unauthenticated database write was used as a workaround.


The branch was pushed successfully through release/compatibility commit `07632403587faaf1f86d4504e0eff2d23386cf87`. The public `revive2/builds/update_info.json` matches the signed local manifest exactly. All four new GitHub download URLs and all four legacy URLs advertised by Firebase returned HTTP 200 after the push. Firebase metadata was compared before and after publication and remained unchanged at `2026.10.9+2126100904`.

[GitHub verification run 38117111025](https://github.com/ihjas-ahammed/Arcane/actions/runs/38117111025) completed successfully for the pushed release/compatibility commit, including dependency resolution, static analysis, and tests. The final documentation commit records these results; the working tree is clean.
