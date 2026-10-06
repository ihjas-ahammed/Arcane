# ⚡ Arcane System Upgrade // v2026.10.6 (Build #2126100603)

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

### 🤖 Input-Reply Fixes (tested on an Android 14 emulator)
- **Stopped working after the accessibility service restarted.** The engine kept a reference to the dead service, so overlays had no window token and every tap was rejected until the whole app was killed. It now rebinds on reconnect and releases cleanly on disconnect.
- **A macro with no steps locked replay forever.** The "replaying" flag is now set only after the macro validates.
- **Recorded clicks matched nothing on replay.** A row's text was recorded as every child label glued together; it now records the element's own label and replay prefers visible, exact matches.
- **Wrong fallback targets.** When a tap navigated away before it could be recorded, the engine grabbed the next screen's title bar. It now keeps only the label, and replay skips a click it cannot locate instead of tapping the navigation bar.
- **"Postal code", "Compost" and similar were treated as Send buttons**, hijacking replay clicks. Send detection is now whole-word.
- Long-press steps now scale across screen sizes and find their element live.
- Verified end to end: opening Settings pages, typing into search, runtime parameters, scrolling, and switching Clock tabs.

### 🧠 Smarter Briefings
- Built-in and external-AI briefings now receive tracked work sessions, completed steps, health (sleep, meals, water, activity, energy), spending by category and grouped communications.

### 🗑️ XP, Levels & Wellbeing Drawer Removed
- The XP system is fully gone: no points, no cumulative scoring, no skill levels, no "LVL" badge in the header and no right-hand wellbeing drawer.
- Reflection scans now feed a per-day **"What the day needed"** pie chart in the daily summary. It shows only the share of each well-being area for that one day and is never accumulated.
- Weekly and monthly AI reports describe well-being focus as percentages instead of points. The "Well-being growth" trend chart is removed.
- Goals carry no XP.
