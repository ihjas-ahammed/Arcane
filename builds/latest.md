# ⚡ Arcane System Upgrade // v2026.10.6 (Build #2126100601)

### 🔄 Data Sync Overhaul
- Realtime and debounced Firebase syncing removed. Data now syncs once, when you generate the daily briefing, via a progress notification.
- Every push is read back and verified, so nothing is silently lost.

### 🛠️ Stability & Performance
- Fixes for lost goal checks, auto-completed projects and duplicate sessions.
- Launcher CPU and widget-reload fixes; launcher status bar now respects notched displays.

### ☁️ Low-Memory Cloud Sync
- Each collection is now uploaded as many small (~24 KB) parts with short pauses and automatic retries, instead of one multi-MB write, which removes the out-of-memory failures. A pointer is only switched once every part is uploaded, so an interrupted sync never damages the cloud copy.
- Restore reassembles the parts one at a time; old single-blob backups still restore. Manual FORCE CLOUD SYNC and RESTORE / MERGE remain in Settings.

### ⚡ Responsiveness
- Typing a checkpoint title no longer rebuilds the whole app and queues a save on every keystroke.
- Checking a task no longer serializes every task for the activity ledger.
- Day-plan widget taps are verified against what the widget showed, so a stale widget can't tick a different task.

### 🗓️ Sessions
- Long-press a session in the schedule to delete it (drag still moves it).
- Timer sessions shorter than one minute are no longer logged.

### 🫧 Floating Button
- The task bubble no longer disappears on a half-written task-state update, and the paused auto-hide is now 3 hours instead of 20 minutes.

### 🧠 Smarter Briefings
- Built-in and external-AI briefings now receive tracked work sessions, completed steps, health (sleep, meals, water, activity, energy), spending by category and grouped communications.

### 🗑️ Removed
- The XP system has been removed from the app, widgets, charts and AI prompts.
