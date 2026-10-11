# Missions 2026.10.11

- Imports and replacements verify SQLite data before committing; failed backups or imports preserve the previous database.
- Emoji and large collections survive storage boundaries, with checksums and recovery guards for unreadable records.
- Existing cloud data must be restored or merged before a new device can upload. Snapshot commits are atomic, older versions remain recoverable, and large deletions need confirmation.
- Cloud Sync now offers dated restores, conflict review, manual backup while auto-backup is disabled, and six-hour automatic backups, including Android background jobs when charging on unmetered networks.
- Local backups retain daily, weekly, and monthly snapshots. Weekly offsite backups are uploaded and verified in Firebase Storage, with a visible error if unavailable.
- Restores, database edits, NORA edits, and purge operations preserve recovery snapshots. Purge exports a final backup and retains cloud recovery trash for 30 days.
- Account switching clears account-specific state. Pending energy replies are saved on their original dates before their queue entries are removed.
- Local saves are debounced and limited to changed collections; history and reflections use individual records. Desktop data migrates to the application support directory; browser data migrates to IndexedDB.
- Update packages require SHA-256 checksums and trusted Ed25519 signatures, and pending saves are flushed before installation. Shared AI keys are no longer distributed; configure personal provider keys in Settings.

Administrator deployment of Firebase privacy and Storage rules, plus authenticated publication of instant-update metadata, requires access to the task-dominion project. The configured Firebase CLI account cannot access this project. The anonymous shallow root check confirmed public database reads; this exposure remains unresolved until the reviewed rules are deployed. See docs/data-hazard-implementation.md for verification results and remaining operational work.
