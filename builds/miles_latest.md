# Miles 2026.11.19 (2126111902)

- Goals: "+ N more" opens the rest of the list in place, with "Show less".
- Startup opens expanded.
- Screen time: no overflow, and a new By device block shows each phone's total and top apps.
- People in Startup and the Briefing: name, relation and type no longer overflow or hide names.

# Miles 2026.11.19 (2126111901)

- New look: a wallpaper behind the whole app (dark and light pictures, kept in the database so they can be changed without an update) and frosted-glass panels, bar and top bar.
- Goals is now the tab the app opens on.

# Miles 2026.11.18 (2126111803)

- Goals banner follows the time of day: View startup from 04:00 to 20:00, View briefing from 20:00 to 04:00. A startup report made today but saved under yesterday's date now shows too.
- Startup header no longer overflows.

# Miles 2026.11.18 (2126111802)

- Goals tab redesigned: a welcome banner, then Daily, Weekly and Monthly cards with progress and the first goals. View all opens the full list; tapping a goal opens it in its own window.
- Daily briefing and Startup report: Arcane's own Tactical Briefing and System Startup cards. Generate them with an external AI: the prompt is copied for you, share the data file, then paste the reply to apply it.
- Screen time and insights in the briefing: total, 7-day chart, top apps, groups, and plain-language insights from your phones' usage.
- Accent colours: set the light and dark theme colour with an RGB picker under Utilities.
- Health: workouts now load from the Workouts task, Stats lists every day, and the suggested sleep also gives next bedtime and a nap window.

# Miles 2026.11.18 (2126111801)

- New Health tab: sleep and activity for the last 7 days with charts, a sleep suggestion based on 90-minute cycles and your recent sleep debt, quick Add Sleep / Log Manually / Add Walk / Add Workout, and a Stats view with a log you can delete from. It reads and writes the same health logs as Arcane.
- Utilities is now a tab on the right of the bar (balancing Health on the left); the top-bar shortcut is gone.
- Bottom tabs show icons only.

# Miles 2026.11.17 (2126111701)

- Code sessions: the PC with the older gateway (optima-26-lite) now opens its session detail; the app reads both reply shapes.
- Code sessions: a message box on each running session. Type to the agent and attach files (10 MB each, saved in the session folder under miles-uploads/).
- Code sessions: running and finished sessions are listed apart, and finished ones load 10 at a time.
- Code sessions: a New session button. Choose the PC, the agent (Claude, Codex or Antigravity), a model, a folder (suggested from every folder used before) and the first prompt.
- Tasks: one malformed record no longer hides a whole protocol (Routine disappeared because of eight sub-steps without an id); the bad record is skipped and the rest loads.

# Miles 2026.11.16 (2126111602)

- Finances: the daily and weekly limits now split what is left of the month over the days to go (even split once the month is used up).
- File access: Utilities → This device has an All files row. An agent on your Wi-Fi or Tailscale can use the database commands list_dir, stat, search, mkdir, copy, move, delete, checksum, disk_info, pull_file (file, folder or zip) and push_file (upload).
- Code sessions (Utilities → Tools): Claude, Antigravity and Codex sessions on your PCs, read through the MCP gateways over Tailscale. Filters, detail view with latest output, offline handling per PC. Gateway URLs and tokens are set in the screen's settings and kept in secure storage.
- Plain HTTP is allowed so the app can reach the Tailscale gateway addresses.

# Miles 2026.11.16 (2126111601)

- Finances: spending limits for today, this week and this month, shown like usage meters. Set a monthly budget and the daily and weekly limits follow; edit this week or today on its own, or reset to auto.
- Add transaction: the chosen account and type now show clearly (tinted card, border and check mark).
- Progress bars show their full track.
- Updates: the app now reads update information and downloads the APK from the public Arcane repo (the Miles repo is private, so downloads failed).

# Miles 2026.11.14 (2126111403)

- Reflections: tap a card to show its full text and feedback; tap again to fold it.
- Reflections: swipe a card left to delete it. An UNDO bar appears for a few seconds and restores the entry.
- Multi-device: each phone has its own id and name (Utilities → This device). Remote commands go to `triggers/<deviceId>`, so an app opens on the phone it was sent to. Utilities → Devices lists every phone with its online state.
- Phone sync (Android, with access you grant): notifications are sent to the database as they arrive, and app usage (time in the foreground and opens per app) every 15 minutes. Allow each under Utilities → This device.
- Remote commands (Android): Miles listens on `triggers/<deviceId>` and can open an app when a command with the shared token arrives.
- New look: route-map task list (protocols as lines, tasks as stations), redesigned task and checkpoint screens.
- Light theme. Choose System, Light or Dark under Utilities; the setting syncs across devices.
- Offline cache for faster start; the task list and schedule share one live data listener.
- Device time zone again: the IST offset from 2126111301 is removed.
- Task screens copied from Arcane: submission view, checkpoints and sub-stops at every level.
