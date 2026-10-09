# ⚡ Arcane Update // v2026.10.9 (Build #2126100904)

### 🔀 Merge and restore
- Merging a backup no longer re-checks checkpoints or subtasks you unchecked. Items are matched by ID only. An incoming item with no ID match is added unchecked.
- Unchecking a checkpoint now clears its completion time.

### 🧾 Data Recovery
- The action ledger list is collapsed by default. Tap "SHOW N ENTRIES" to open it.

### 🤖 AI settings
- Lite, Pro, and Live model lists are collapsed by default. Tap a section header to open it.

### 🎛️ Floating HUD
- Pause and start are explicit. A stale tap can no longer reverse a stop.
- A task stopped from the HUD or the widget is not offered as "Continue" until you start it again.

### 🐕 Watch app keep-alive
- Every 10 minutes Arcane checks the running processes and starts the watch app only if it is not running.
- On most phones Android hides other apps' processes, so the check reports "unknown" and does not restart the app.

### 🔐 Usage access
- Devices screen shows Usage access, with an ALLOW button that opens the Settings page.

### 🛟 Safer local data
- If the saved data on this device can't be read, the app shows the error with a COPY ERROR button. It no longer loads older copies or the cloud.
- LOAD JSON INTO DATABASE replaces the stored data from a JSON file, on Android too. The previous data is copied to backups/ first.
- EXPLORE BACKUPS (READ-ONLY) previews a backup or JSON file without loading it.

### 🗑️ Removed "Call myself before starting AI"
- The option under Advanced AI Settings is gone, since it didn't work reliably.
