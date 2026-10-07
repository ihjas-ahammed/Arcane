# ⚡ Arcane System Upgrade // v2026.10.7 (Build #2126100704)

### ✅ No more surprise checking
- Stopping a timer never checks a task or takes it off the day plan any more.
- The tick in the planner (and on the plan widget) only checks a recurring daily task. For any other task it just takes it off today's plan and leaves it open. Checkpoint ticks are unchanged.

### 🎯 Floating task button
- It now exists only while a timer is running; no more permanent play button. When nothing is running, a notification offers "Continue: <plan task>" with an ENGAGE action.
- The button is opaque, so the wallpaper lines no longer show through it. Its radial menu is centred on the button, and the clock no longer keeps counting when nothing runs.

### 🧩 Home-screen widgets
- Widgets follow the app: light / dark theme and the accent colour of the selected protocol (Android 12+).
- In the launcher, widgets are shown on their own: no frame, border or title bar, just like any other launcher.

### ⚡ Performance & data
- Local saves are coalesced (one encode at a time) and flushed reliably when the app pauses.
- Market data (websocket + polling) now starts only when you hold positions / pending orders, or open Trading.
- Earlier in this release: realtime local saves, one-way retried cloud sync, desktop layout, Devices screen, nutrition removal, picker filters.
