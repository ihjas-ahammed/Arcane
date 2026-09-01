# ⚡ Arcane System Changelog & Release Notes

## [v2026.9.1] — 2026-09-01
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

### 📦 Seamless In-App APK Package Installation
- **Permission & Directory Calibration**: Updated update storage resolution to external files / application support directories to bypass erroneous Android 11+ `MANAGE_EXTERNAL_STORAGE` permission checks, allowing the native Android Package Installer to trigger smoothly with standard unknown app install privileges.

### 🎨 Goals Drawer & Tactical HUD Refinements
- **Streamlined Goals Header**: Decluttered top metadata bar in the Goals bottom drawer for maximum focus and visual clarity.
- **Emoji-Free Military Aesthetics**: Purged decorative emojis from HUD status badges and XP toasts in favor of clean iconography and monospace typography.

---

## [v2026.8.28] — 2026-08-28
### 🛡️ Classified Skills Matrix & Telemetry Subsystem
- **Tactical Sci-Fi HUD Experience**: Full implementation of the tactical HUD design system featuring 8-corner chamfer polygon cuts, top notches, glowing red corner brackets, and 58×58 tech icon boxes.
- **Custom Silhouette Graphics**: Built-in SVG vector silhouettes for Chess Knights, 729 Odometer digit spans, Push-Up figures, and Pull-Up bar rigs.
- **Custom Skill Benchmarks**: Create, edit, and categorize skills (Chess ELO, Memory Digits, Breath Hold, Push-Ups, Pull-Ups, etc.) with custom targets, units, descriptions, and searchable icon pickers across Lucide and Material design icons.
- **Comprehensive Analytics & Line Charts**: Progress-over-time canvas charts with dashed grid lines, smooth trajectory curves with gradient area fills, pulsating data nodes, and 4-metric stat grids (Best Rating, Sessions, Win Rate, Time Spent).
- **Training Logs & Trials vs Outcome Bar Charts**: Interactive training logger with delta badges (`+18` teal, `-8` red) and stacked/grouped bar charts for Wins, Losses, and Draws.
- **Dual Light & Dark Theme Calibration**: Full theme adaptability using warm tactical paper surfaces and high-contrast crimson accents for daylight operations.

### 📈 Reflection XP Formatting & Aggregation
- **Compact XP Telemetry**: Automatically formats large XP quantities (`1.1K`, `1.2M`) when exceeding 9,999 while accurately calculating total cumulative XP across reflection logs.

### 🎨 Border & Aesthetic Fidelity
- **Restored Tactical Card Styling**: Restored authentic card border geometry and styling across all protocol screens while maintaining seamless light mode integration.

---

## [v2026.8.26] — 2026-08-26
### 📊 Tactical Weekly & Monthly Debrief Overhaul
- **Logbook Day Context**: Weekly and Monthly briefings now evaluate and archive for the opened logbook day instead of today, enabling accurate retrospective debriefs on demand.
- **Collapsible People Dossier**: Replaced expansive contact lists with an overarching collapsible dropdown featuring master `EXPAND ALL` and `COLLAPSE ALL` controls to keep debriefs sleek and bloat-free.
- **Health & Vitality Debrief**: Dedicated AI health trajectory section analyzing sleep consistency, recovery index, activity coaching tips, and 7-day health telemetry metrics.
- **Day-by-Day Gratitude Intelligence**: Expanded daily gratitude tracking (10+ notes/day) organized day-by-day with category icons, weekly highlights, and master expand/collapse controls.

### 🔄 In-App Updater Caching & Re-Download Overhaul
- **Version-Specific APK Caching**: APKs are now uniquely version-tagged (`Arcane_v2026.8.26_b2126082601.apk`) to eliminate stale APK installation bugs across releases.
- **App Cache Directory Storage**: APKs are downloaded directly into the app's cache directory and auto-cleaned on updates.
- **One-Tap Re-Download**: Added an interactive `REDOWNLOAD` action button directly in the update dialog to force fresh build downloads when needed.

---

## [v2026.8.21] — 2026-08-21
### 🤖 NORA Agent Engine & Autonomous Reasoning Loop
- **Inbuilt Tool Execution Framework**: Nora is now a real autonomous agent querying app database records on demand (`find_reflections`, `read_reflections`, `find_tasks`, `read_task`, `get_day_plan`, `find_people`, `read_person`) via multi-turn reasoning steps.
- **Isolated Character Memory Space**: Dedicated long-term memory node per persona supporting `memory_add`, `memory_read`, `memory_find`, `memory_delete`, and `memory_list` with a dedicated HUD viewer sheet.
- **Character Forge (Pro AI)**: Summon cinematic characters (Tony Stark, Harvey Specter, TARS, etc.), clone WhatsApp speaking styles from exported chat logs, or build custom personalities with Gemini Pro.
- **Rich Markdown in Nora Chat**: Complete markdown support for headings, bold/italics, quotes, code blocks, lists, and tables in message bubbles.
- **Fast Nora Access**: Long-press on the bottom/desktop Goals button to instantly open Nora.

### 🎯 Startup & Navigation Refinements
- **Goals Operator Startup Auto-Open**: Goals drawer automatically opens upon app startup.
- **Removed PIN Lock**: Instant, seamless access across all screens without lock barriers.
- **Startup & Weekly Briefing Uniqueness**: Guaranteed non-repeating inspirational quotes, authors, and historical stories across daily and weekly briefings.

---

## [v2026.8.15] — 2026-08-15
### 🎯 Tactical Goals Subsystem Overhaul
- **Multi-Scope Protocol**: Full support for Daily, Weekly, Monthly, and Milestone mission scopes with chamfered HUD chassis styling.
- **Infinite Checkpoints & Subchecklists**: Add and organize nested checkpoints with automated progress calculations.
- **Keyboard Auto-Scroll**: Fixed input focus occlusion so checkpoint entries automatically scroll into view above the software keyboard.
- **Undo Actions**: Full undo snackbars for goal deletions and subchecklist item removals with list state restoration.
- **Dynamic Accent Transformation**: Clean inline darken color transforms for completed mission cards, progress bars, and borders.

### 🧠 Intelligence & Briefing System
- **Daily Startup Briefings**: Energizing morning briefings with non-repeating motivational quotes and prioritized contact suggestions.
- **Tactical End-of-Day Briefings**: Uplifting daily retrospectives with unique quote reflections, sensory moment logging, and finance insights.
- **7-Day System Debrief**: Standardized default relationship categorization (`Family & Partner`, `Friends`, `Professional & Mentors`, `Acquaintances & Others`) and unique parallel journey historical stories.
- **30-Day Monthly Review**: Deep relationship audit, wellbeing delta tracking, and non-repeating historical wisdom stories.
- **Persona Writing-Style Synchronization**: Automatic grammatical correction and persona-aligned voice matching.

### 🔄 Auto-Update & Distribution
- **OTA Update Checker**: In-app automated update checking directly from the GitHub repository `builds/` directory.
- **What's New HUD Alert**: In-app rich markdown release notes preview.
- **Direct APK Download & Local Cache**: Download APK in the background with live progress, local caching, and single-tap install.

---

## [v2026.8.5] — 2026-08-05
- **Interactive Gestures**: Long-press to edit goal parameters, swipe-to-complete, and swipe-to-delete.
- **Sensory Moments**: Micro-sensory gratitude reflection logging and daily small win highlighting.
- **UI Refinements**: Refactored HUD metrics and period progress banners.

---

## [v2026.8.3] — 2026-08-03
- **Date Clean Sheets**: Quick date navigation and inspection for all goals and tasks.
- **Manual Input & Sliders**: Dual numeric input support for counter and time-based goals.
- **Logbook HUD Theme**: Refined monospace typography and Cyberpunk-inspired UI elements.

---

## [v2026.8.1] — 2026-08-01
- **Energy Wave Matrix**: Biometric energy tracking comparing morning vs evening focus states.
- **Telemetry Dashboards**: Multi-dimensional activity logging with sleep, hydration, and movement tracking.

---

## [v2026.7.22 - v2026.7.26] — Late July 2026
- **Nested Briefing Dropdowns**: Infinitely expandable mission progress logs and checkpoint breakdowns.
- **Interactive Energy Map**: Visual energizers vs drainers classification.
- **Home Screen Widgets**: Android home screen widget updates for active missions, finance balance, and quick journaling.

---

## [v2026.7.13 - v2026.7.18] — Mid July 2026
- **Multiselect Checkpoints**: Batch operations and bulk status toggling for tasks and checkpoints.
- **Task-Biometric Routing**: Biometric intelligence engine linking focus sessions to emotional states.
- **Atomic Habits & GTD Framework**: Identity vote tracking, habit friction identification, and Next Action extraction.
