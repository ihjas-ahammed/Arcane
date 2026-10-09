# ⚡ Arcane Update // v2026.10.9 (Build #2126100903)

### 🎛️ Floating HUD
- Pause and start are now explicit. A stale tap can no longer flip a running task into a start, or the reverse.
- The widget refreshes right after each HUD or widget action.
- A task you stopped from the HUD or the widget is not offered as "Continue" or as the next task until you start it again.

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
