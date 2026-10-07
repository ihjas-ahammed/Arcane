# ⚡ Arcane System Upgrade // v2026.10.7 (Build #2126100702)

### 🖥️ Desktop & wide-screen layout
- Side rail from 720 px wide (tablets, small windows) and a labelled rail with hover tooltips at 1200 px+. Ctrl+1…6 switch tabs.
- Dialogs and bottom sheets are capped in width instead of stretching across the window; the whole app is capped on very large monitors.
- Missions protocol cards use as many columns as fit; Wallet, Missions and Health get wider, centred content; Linux window has a minimum size.

### 🎯 Floating task button
- Fixed: the radial menu was drawn lower than the button (offset by the status bar). It now centres on the button.
- Stays on screen whenever enabled, and re-checks itself so it never goes missing.
- Fixed: the button kept counting up with no timer running. The running state it shows is now republished every 30 s and can no longer be left stale by a failed update.

### 💾 Data safety & sync
- Edits are saved locally within ~120 ms, failed writes are retried.
- The cloud push no longer overwrites local data (fixes lost goals/checks), is upload-only, retries until everything is uploaded and verifies each chunk.

### 🧭 Task pickers
- "Copy time from workout task" lists any task from any protocol except Routine. Inactive, deleted and archived tasks are hidden from every task picker.

### ⌚ Devices (Utilities)
- New Devices screen: paired/nearby Bluetooth devices, live capture of everything a watch sends, watch companion app selection and keep-alive.

### 🗑️ Removed
- Nutrition tab, stats and reflection food input. Reflection editor is a single input.
