# ⚡ Arcane Update // v2026.10.9 (Build #2126100902)

### 🛟 Safer local data
- If the saved data on this device can't be read, the app shows the error with a COPY ERROR button. It no longer silently loads an older copy or the cloud.
- Startup uses only this device's data. It no longer loads from the cloud or from .bak backups.
- LOAD JSON INTO DATABASE replaces the stored data from a JSON file (also on Android). The previous data is copied to backups/ first.
- EXPLORE BACKUPS (READ-ONLY) lets you look inside a backup or JSON file without loading it into the app.

### 🗑️ Removed "Call myself before starting AI"
- The option under Advanced AI Settings is gone, since it didn't work reliably.
