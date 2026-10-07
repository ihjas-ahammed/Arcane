# ⚡ Arcane System Upgrade // v2026.10.7 (Build #2126100701)

### 💾 Your data is saved the moment you change it
- Every edit is written to the on-device cache within ~120 ms (it used to wait a full second), and a failed write is retried until it lands.
- Fixed: goals you added and the checks you made could vanish overnight. The end-of-day cloud push used to write its minutes-old snapshot back over your local data when it finished; it no longer touches the local cache at all.
- Edits made while a cloud push is running now stay marked as unsynced and are pushed right after.

### ☁️ Cloud sync is one-way and does not give up
- Upload never replaces local data. The manual sync buttons are upload-only; restoring from the cloud is only in Settings, and it saves a copy of what is on the device first.
- The end-of-day push keeps retrying (backoff up to 5 min) until every collection (tasks, history, reflections, finance, health, trading, launcher, settings) is in the cloud. If the app is closed mid-push it resumes on the next start or when you are back online.
- Each uploaded chunk is read back from the cloud and checked before it replaces the old copy; more retries per part.

### 🎯 Floating task button
- It no longer disappears. The 3-hour paused auto-hide and the "no task, so hide" rule are gone; the button stays on screen whenever it is enabled (tap it with no task to open the plan) and re-checks itself every 20 s, so it comes back on its own instead of only when the Plan view is opened.
