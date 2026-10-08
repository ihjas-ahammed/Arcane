# ⚡ Arcane System Upgrade // v2026.10.8 (Build #2126100801)

### 📞 Direct calls
- The launcher search and number taps now place the call directly (no dialer screen). Falls back to the dialer if the call permission is not granted.
- The app asks for phone permissions on start.

### 🤖 External AI (Bluetooth) widget
- The widget moved to the top of Advanced AI Settings.
- New "Call myself before starting AI" option: place a call to your own number, end it after one second, then open the assistant. Intended for watches whose mic only works after a call.

### 🧭 "What the day needed" rebuilt
- New framework of 12 distinct needs, each grounded in psychology and philosophy: Rest, Security (Maslow), Belonging, Self-Worth (Baumeister & Leary, Neff), Autonomy, Competence (Self-Determination Theory, Stoic sphere of choice), Growth (Ryff, Aristotle), Purpose, Integrity (Frankl, virtue ethics), Flow (Csikszentmihalyi), Equanimity (Stoic ataraxia, emotion regulation), Delight (Fredrickson).
- The AI now scores how strongly each need shows up in a reflection (met or frustrated), with clear definitions, and its feedback names the needs and gives one small step. Weekly / monthly reports use the same terms.
- The reflection insight alert is updated to match: "What this reflection needed", with a short meaning for each need. Older reflections are mapped onto the new needs automatically.

### 🧩 Widgets use the launcher colours
- Widgets now take the launcher's palette (accent, panel, text, light / dark), not the protocol colour.

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
