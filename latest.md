# ⚡ Arcane System Upgrade // v2026.9.1

### 🔄 Archived Logs Regeneration Subsystem
- **In-Place Historical Regeneration**: Added seamless regeneration for past 7-Day Reviews, 30-Day Monthly Briefings, and Daily Tactical Briefings from either the active view screen or the Archived Reports screen.
- **Strict Historical Boundaries**: When regenerating past logs, all data (transactions, completed mission checkpoints, habits, health telemetry, reflection history, and prior monthly context) is strictly bounded by that specific historical target date, guaranteeing zero future data leakage.
- **Live State & Archive Overwrites**: Regenerating past reviews automatically overwrites the stored archive record and immediately updates the live UI.

### ⏱️ Pro AI Model Timeouts & Automatic Fast Fallback
- **Tiered AI Execution Timeouts**: Configured strict per-briefing timeouts (30 seconds for Daily Briefing & Startup Report, 1 minute for Weekly Review, 2 minutes for Monthly Briefing) to prevent hanging during API traffic spikes.
- **Zero-Drop Fast Model Fallback**: Catches network/timeout exceptions, logs diagnostics, and instantly re-routes generation through fast-tier models (`gemini-2.0-flash`) without user intervention.
- **Real-Time Telemetry Callbacks**: Real-time status reporting streamed directly into UI status banners throughout multi-step AI synthesis.

### 🛡️ Cyber-Tactical Briefing Indicator HUD
- **Advanced Tactical UI**: Introduced a rotating radar HUD widget with angular corner chamfers, pulsing progress sweep, elapsed timer telemetry, and dynamic active engine badges (`PRO-TIER ENGINE` vs `LITE MODEL FALLBACK ACTIVE`).
- **Comprehensive Error Trapping**: Embedded retry workflows and error banners with actionable recovery options.

### 🎨 Goals Drawer & Tactical HUD Refinements
- **Streamlined Goals Header**: Decluttered top metadata bar in the Goals bottom drawer for maximum focus and visual clarity.
- **Emoji-Free Military Aesthetics**: Purged decorative emojis from HUD status badges and XP toasts in favor of clean iconography and monospace typography.
