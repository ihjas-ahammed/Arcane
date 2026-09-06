# ⚡ Arcane System Changelog & Release Notes

## [v2026.9.6] — 2026-09-06
### 🗂️ Smooth Reorderable Planner & Drag Glitch Elimination
- **Submission-Engine Reordering**: Migrated `TodayPlannerScreen` task and mission reordering to Flutter's native `ReorderableListView.builder` paired with `ReorderableDragStartListener` and `ReorderableDelayedDragStartListener`, mirroring the rock-solid submission reordering in `task_details_view.dart`.
- **Zero Jitter & Auto-Adjust Elimination**: Removed oscillating hover-expand drop dividers and custom manual scroll listeners that previously triggered rapid 10x/sec layout fighting during drag gestures.
- **Fluid Floating Proxy**: Added tactical elevated `proxyDecorator` and grab cursor feedback during dragging with seamless integration into day plan persistence.

### 🎯 Task Hero Homescreen Widget Architecture & Launcher Fix
- **Lightweight Flat Hierarchy**: Redesigned `widget_running_task.xml` using the exact same proven architecture as `widget_bus.xml`, `widget_finance.xml`, and `widget_journal.xml`. Reduced view count from 55 elements (depth 8) to 21 elements (depth 5), eliminating launcher inflation crashes and `RemoteViews` IPC overflow.
- **Dual-Tree Removal**: Eliminated redundant full-screen `widget_multitask_layout` and `widget_running_layout` sibling trees in favor of a single unified layout.
- **Unified RemoteViews Binding**: `RunningTaskWidget.kt` binds running tasks, multitask summaries, and bus transit into the flat layout seamlessly.
- **Defensive Error Handling**: Wrapped widget updates in `try/catch` with system log reporting, preventing launcher process crashes.
- **Instant Visual Feedback**: Aligned button IDs (`widget_btn_engage`, `widget_btn_check`, `widget_btn_finish`) with `WidgetActionReceiver.kt` for instant visual response upon tapping.

### 🤖 Dynamic AI Model Selection & Rolling Fallback Ladder
- **Arbitrary Model Capacity**: Removed the 3-model limitation for Lite and Pro tiers, enabling operators to configure any number of models.
- **Custom Model Management**: Added ability to enter custom Gemini model names, pick from quick chips, reorder priorities, and delete models.
- **Three-Model Defaults**: Out-of-the-box defaults remain 3 models each (`gemini-2.5-flash`, `gemini-2.5-flash-lite`, `gemini-2.0-flash` for Lite; `gemini-2.5-pro`, `gemini-1.5-pro`, `gemini-2.0-pro-exp-02-05` for Pro).
- **Rolling Execution Engine**: `AIService` rolls dynamically across all configured models in ladder order if a rate-limit or error is encountered.

### 📋 Lightweight Day Plan Homescreen Widget & Studio Integration
- **Streamlined Native XML Hierarchy**: Re-engineered Day Plan widget layout (`widget_dayplan.xml`) with a flat, lightweight hierarchy (~170 lines) eliminating RemoteViews view tree overflow and launcher inflation crashes.
- **Dedicated Android System Widget Provider**: Registered `Arcane — Day Plan` (`DayPlanWidget`) directly in the Android home screen widget manager (`widget_dayplan_info.xml`), enabling standalone discovery and pinning.
- **Dynamic Inflation Integration**: `RunningTaskWidget` now dynamically inflates `widget_dayplan` when `dayPlannerWidgetCheckable` is active, stripping 70+ lines of redundant XML from `widget_running_task.xml`.
- **In-App Widgets Studio Dedicated Day Plan Tab**: Expanded `HomescreenWidgetsPreviewScreen` with a dedicated 5th tab ("DAY PLAN"), complete with interactive preview, mock task population, state toggles, and direct launcher pinning (`requestPinDayPlan()`).
- **Flutter UI Preservation**: Maintained exact parity and functionality for the in-app Flutter day planner widget (`RunningTaskHomeWidget`).

### 🚌 "In The Bus" Transit Telemetry & Commute System
- **Interactive Departure Selection**: Routine bus schedule departure times are now interactive selection chips in `BusScheduleGrid` with tactical cyan highlight indicators.
- **Dedicated "In The Bus" Launchers**: Added `[ 🚌 IN THE BUS ]` action chips directly to the Next Bus card and departure details bottom sheets for instantaneous commute initiation.
- **Intelligent Distance Calibration**: Prompts for route distance (`_askDistanceDialog`) if unconfigured, featuring quick-select presets (10km, 15km, 25km, 30km, 45km) and precision input.
- **Standardized 20 km/h Commute Velocity**: Transit ETA and travel progress calculations strictly enforce the assumed 20 km/h velocity model ($\text{duration} = \frac{\text{distance}}{20} \times 60$).
- **Live Travel HUD Card**: Dynamic progress bar, completion percentage, remaining ETA countdown, covered distance vs total distance, speed badge (`20 KM/H ASSUMED`), and one-tap `END TRIP` / `DISTANCE` controls.
- **Ongoing Silent Notification**: Low-priority pinned Android notification channel with live progress bar, route header, and quick-action "END TRIP" button.
- **Home Screen Widget Transit Focus**: `BusWidget` and `RunningTaskWidget` automatically prioritize active transit, dedicating telemetry, progress bars, and controls to the live journey.

### 😴 Science-Backed Sleep & Circadian Nap Advisor
- **Ultradian & Homeostatic Sleep Algorithm**: Dynamic sleep scheduling powered by two-process sleep regulation (Process C circadian rhythm + Process S homeostatic sleep pressure) and 90-minute sleep cycles.
- **Real-Time Past Window Recovery**: Expired or missed sleep windows are cleanly cleared; instantly calculates and predicts the next optimal sleep or nap window without stale timestamps.
- **Dedicated Nap Architecture**: Full support for logging and analyzing power naps (20m stage-2 restorative) and full-cycle naps (90m slow-wave + REM).
- **Dual-Theme Circadian Telemetry**: High-contrast sleep panels and dashboard metrics honoring warm tactical paper in light mode and midnight tactical in dark mode.

### 📱 Android Home Screen Widgets Visual & Stability Overhaul
- **Launcher Crash & Freeze Prevention**: Streamlined XML RemoteViews drawables, stripping fragile multi-stroke layers to ensure smooth loading across third-party Android launchers.
- **Uniform Rounded Corners**: Standardized all widget backgrounds and tactical cards to modern `20dp` rounded corners.
- **Background Art Integration**: Added lightweight background art drawables with day and night mode parity (`res/drawable-night/`).

---

## [v2026.9.5] — 2026-09-05
### 📐 Tactical Multi-Plan Height Consistency & Dynamic Layout
- **Multi-Task Row Height Parity**: Wrapped multi-task rows (2-in-1 and 3-in-1 planner & hero cards) with `IntrinsicHeight` and vertical cross-axis stretch, guaranteeing consistent card heights between tasks with and without subtasks or checkpoints.
- **Checkpoint Badges for Multitask Cards**: Standardized active checkpoint status indicators (`Icons.checklist_rounded`) on multitask cards displaying active `${completedCps}/${totalCps}` ratios with instant one-tap dialogs to inspect and toggle checkpoints.
- **Responsive Overflow Shielding**: Dynamic typography scaling and flex constraints preventing horizontal or vertical text overflow in multi-task configurations.

### 🛡️ Unified Tactical HUD Chamfered Border Styling
- **Tactical HUD Card Geometry**: Introduced `TacticalCardBorderPainter` and `Chamfer4CornerClipper` delivering authentic sci-fi angled corner notches and cyan border lines.
- **Cross-Component Border Parity**: Unified tactical border styling across Today Planner cards, Schedule Hero widget, and Android Homescreen preview widgets.
- **Clean Iconography**: Purged decorative emojis in favor of crisp, high-contrast Material and Lucide vector icons.

### 🔄 In-App Updater Version Superiority & Stability
- **Strict Version Superiority Enforcement**: Re-engineered update availability resolution to guarantee older or equal releases (e.g. v2026.9.1) are never offered as available updates, even during forced manual checks.
- **Dual-Tier Version Resolution**: Built-in Android `versionCode` validation backed by semantic version string parsing (`isVersionStringNewer`).
- **Real-Time Latest Build Confirmation**: Clear feedback confirming the active installation is on the latest build.

### 🚫 Phoenix Protocol Deprecation
- **Clean Protocol Architecture**: Fully removed deprecated Phoenix protocol remnants and obsolete triangle corner painters for a streamlined, performance-optimized mission execution pipeline.

---

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
