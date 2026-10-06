# ⚡ Arcane System Upgrade // v2026.10.6 (Build #2126100604)

### 🐧 Linux Desktop (x86_64) Release & Auto-Update
- Official Linux x86_64 optimized release bundle now published in `builds/` and accessible via GitHub raw links.
- Single-command direct terminal installer added (`curl -sSL https://raw.githubusercontent.com/ihjas-ahammed/Arcane/revive2/scripts/install-linux.sh | bash`).
- Fully automated in-app updater: Arcane checks for Linux updates, downloads the optimized release, and restarts automatically with zero downtime.
- Desktop menu entry and high-res tactical icon support added.

### 🖐️ Input-Reply: Exact Touch
- Recording now captures your real taps, long-presses and swipes at the exact pixel you pressed, and replay presses those same coordinates. The small left/up drift is gone.
- Hybrid mode is removed; Touch is the default. Elements mode is still available.
- The soft keyboard is left alone: the capture layer stays off the keyboard, so typing is still recorded as text.
- Fixed duplicate click steps appearing for each recorded tap.

### 🗓️ Sessions
- The DELETE and SAVE buttons in the Session Archives screen did nothing. Both work now, and deleting shows the usual undo snackbar.
