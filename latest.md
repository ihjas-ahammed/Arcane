# ⚡ Arcane System Upgrade // v2026.9.16 (Build #2126091604)

### 📊 Real Historical Price Data & Multi-Timeframe Charts
- **Multi-Timeframe Real Charting**: Introduced interactive multi-timeframe price history across `[ 1D | 1W | 1M | 1Y | ALL ]` for every asset. Tapping any timeframe queries real historical market data and generates interactive `fl_chart` line charts with date/time labels and volume-weighted gradient fills.
- **Interactive Touch Crosshairs**: Operators can drag across the historical chart to inspect exact historical price points, calendar dates/timestamps, and cumulative period return percentages ($\pm\%$).
- **Comprehensive Key Historical Metrics**: Each asset detail screen now showcases 52-Week High & Low, Period High & Low, Previous Close, Trading Volume, Exchange, and live Market Status.

### 🇮🇳 Indian Stock Market Universe & Bluechips (NSE / BSE)
- **Extensive Indian Asset Universe**: Tailored for the Indian market context, adding top 30 National Stock Exchange (NSE) bluechips including Reliance Industries, Tata Consultancy Services (TCS), HDFC Bank, Infosys, ICICI Bank, State Bank of India (SBIN), Bharti Airtel, ITC, Larsen & Toubro, Tata Motors, Sun Pharma, Bajaj Finance, and more.
- **Benchmark Indices & Commodities**: Integrated live tracking and historical charts for NIFTY 50, BSE SENSEX, BANK NIFTY, Gold (24K ₹/10g), Silver (₹/kg), and Crude Oil (₹/bbl).
- **Native INR (₹) Paper Trading**: Indian equities and commodities are natively priced and transacted in Indian Rupees (₹) with whole-share quantity calculations, real-time INR wallet balance deductions, and dedicated confirmation modals.
- **700+ Cryptocurrency Universe**: Expanded crypto trading beyond the default trio to encompass the full 700+ Binance pairs universe with real-time live search, category filtering (`ALL`, `NSE STOCKS`, `INDICES`, `CRYPTO`, `COMMODITIES`), and instantaneous USDT-to-INR conversions.

### ⏰ Live Indian Market Status Telemetry & Background Poller
- **Dynamic IST Market Hours Engine**: Automatically tracks Indian Standard Time (UTC+5:30) trading hours (09:15 – 15:30 IST, Monday–Friday).
- **Real-Time HUD Market Status Banner**: High-contrast banner clearly indicates market status: `● NSE LIVE 09:15 - 15:30 IST` during trading hours or `○ NSE CLOSED (OPENS 09:15 IST)` after hours and weekends.
- **15-Second Background Market Poller**: Periodically fetches fresh quotes for all active Indian assets and indices while the terminal is active.

---

# ⚡ Arcane System Upgrade // v2026.9.16 (Build #2126091603)

### 📈 Realtime Paper-Trading Simulator (Binance WebSocket Feed)
- **Zero-Risk Live Paper Trading**: Added a full paper-trading simulator to the "Systems & Utilities" suite enabling risk-free buy-low / sell-high strategy practice with real-time streaming market prices and a virtual balance.
- **Binance Public WebSocket Feed**: Integrated live market streaming from `wss://stream.binance.com:9443` for `BTC/USDT`, `ETH/USDT`, and `SOL/USDT`. Features zero API keys, 1-second ticks, auto-reconnection, REST snapshot bootstrap for instantaneous load, and rolling tick buffers for live sparklines and charts.
- **Watchlist Screen & Live Sparklines**: Displays live USD prices, converted INR equivalents (at configurable USDT/INR exchange rate, default ₹88), 24h percentage changes (color-coded green/red), and animated sparklines updating with incoming ticks.
- **Asset Detail Screen & FlChart Movement**: Centered live price ticker with 24h stats (High, Low, Volume) and a live `fl_chart` price movement line chart with animated gradient shading. Includes active holding card and pending limit orders list.
- **Order Flow & Execution**:
  - Full support for **Market Orders** (instant execution against live ticks) and **Limit Orders** (resting orders that automatically trigger and fill when market prices cross the limit threshold).
  - Dual quantity inputs (Amount in INR vs Crypto Coin quantity) with quick percentage allocation chips (25%, 50%, 75%, 100%).
  - Limit order quick nudges (-2%, -1%, +1%, +2%) for fast order configuration.
  - Confirmation dialog with estimated total costs in INR and USD before execution.
- **Portfolio & Order History Tracking**:
  - Tracks total portfolio value, cash reserves, holdings value, and 24h unrealized P&L in real-time.
  - Interactive Orders tab logging all simulated trades (filled and cancelled) with instant limit order cancellation support.
- **Configurable Simulation Parameters**:
  - Virtual cash balance configuration (₹50k, ₹1L, ₹5L, ₹10L quick presets) and custom USDT-to-INR rate.
  - One-tap simulation reset with state persistence in `SharedPreferences`.
- **Foundational Market Mechanics Guide**:
  - Built-in educational modal with 4 foundational concept cards strictly under 100 words each:
    1. *The Bid-Ask Spread* (Why the price you see isn't always what you get)
    2. *Market vs Limit Orders* (Speed vs Price Guarantee)
    3. *Slippage* (Expected Price vs Filled Price)
    4. *Why Prices Move* (Supply & Demand, featuring the Oct 2012 NSE flash crash & circuit breakers)
- **Dual-Theme Fidelity**: 100% compliant with `JweTheme` dark and light tactical paper/stone palette.

---

# ⚡ Arcane System Upgrade // v2026.9.16 (Build #2126091602)

### 🎯 Pre-Flight Briefing Goal Alerts & Tomorrow Planning Shortcut
- **Tomorrow's Goal Prerequisite in Daily Briefing Lock Alert**: The pre-flight missing daily telemetry alert in Daily Briefing now checks if daily goals for tomorrow have been planned. If missing, it alerts the user with "TOMORROW'S TARGET GOALS" alongside health and financial inputs.
- **Direct "+ CREATE" Action Shortcut**: Operators can tap the `+ CREATE` shortcut directly from the missing telemetry alert card to immediately open `CreateGoalSheet` pre-configured for tomorrow's daily scope, eliminating manual drawer navigation.
- **Direct "+ LOG" Action Shortcut for Finance**: Added a quick `+ LOG` shortcut on the financial missing card to open `AddTransactionDialog` directly.
- **Tomorrow Goals in Daily Briefing AI Context**: Tomorrow's planned goals are automatically injected into the AI context for daily briefings so the AI actively acknowledges next-day targets and aligns forward insights.

### 📅 Weekly Briefing Next-Week Goals Prerequisite (Minimum 2 Goals)
- **Forward Momentum Strategic Enforcement**: Initiating or regenerating a 7-day Weekly Review checks whether at least 2 weekly goals are planned for next week.
- **Tactical Prerequisite Alert**: If fewer than 2 goals exist, presents a high-contrast tactical warning (`WEEKLY BRIEFING: NEXT WEEK GOALS`) showing current progress (e.g. `NEXT WEEK GOALS: 0 OF 2 SET` or `1 OF 2 SET`), displaying any existing goals with status indicators.
- **Instant "+ ADD NEXT WEEK GOAL" Sheet**: Includes a direct button and `ADD GOALS FIRST` option that opens `CreateGoalSheet` pre-configured for next week's weekly scope. Operators can also choose `PROCEED ANYWAY` if they need to bypass.
- **Next Week Planned Goals in Weekly AI Synthesis**: Next week's planned goals are incorporated into the weekly mission briefing context for the AI service.

---

# ⚡ Arcane System Upgrade // v2026.9.15 (Build #2126091501)

### 🎯 Interactive Goal Subchecklist Rearrange Mode
- **Gesture-Activated Reorder Mode**: Double-tapping the subchecklist header or any subchecklist item row activates interactive rearrange mode with light tactical haptic feedback (`HapticFeedback.lightImpact`).
- **Arrow-Based Order Controls**: When in rearrange mode, each subchecklist task exposes dedicated Up (`▲`) and Down (`▼`) arrow controls to shift task priority and sequencing within the goal.
- **Visual Feedback & Index Badging**: Shows numbered badges (`#1`, `#2`, `#3`) for clear sequence tracking, while boundary arrows automatically disable at the list boundaries (top-most item disables Up arrow; bottom-most item disables Down arrow).
- **Responsive Layout & Dual-Theme Parity**: Compact header badge and adaptive text prevent horizontal layout overflow even on compact 320px device screens. Adapts dynamically to `JweTheme` light and dark modes with calibrated cyber hues.
- **Dedicated Completion Control**: Added an independent `[✓ DONE]` header action to seamlessly commit ordering and exit rearrange mode.

---

# ⚡ Arcane System Upgrade // v2026.9.14 (Build #2126091401)

### ⏱️ Proportional Realtime Cluster Time Allocation
- **Eliminated Overcounted Schedule Time**: When multiple tasks overlap or nest within the same schedule window (e.g., a 9:00 AM – 5:00 PM task with intermediate tasks at 10–12, 13–15, 15–17), time is no longer inflated. Overlapping sessions are grouped into connected clusters, measuring the true realtime difference ($\Delta T_{\text{realtime}} = \max(endTime) - \min(startTime)$).
- **Proportional Fractional Allocation**: Each session within an overlapping cluster is allocated its exact proportional fraction of the realtime difference based on its scheduled duration:
  $$\text{effectiveSeconds} = \frac{s.\text{durationSeconds}}{\sum s_j.\text{durationSeconds}} \times \Delta T_{\text{realtime}}$$
  Fractional seconds are distributed using largest-remainder distribution, ensuring the sum of all session times strictly matches the real wall-clock elapsed time down to the integer second.
- **Universal Application Across App Subsystems**:
  - **Missions & Subtasks**: Lifetime duration, today's elapsed time, and 7-day rolling averages reflect proportional real-time allocation.
  - **Session Archives & Drawers**: Individual session cards and log drawers display calibrated effective durations with `SPLIT (Xm)` badge telemetry.
  - **Charts & Analytics**: Subtask progress time charts, weekly bar charts, project analytics, and streaks calculate proportional cluster time.
  - **Health & Reports**: Daily workout sync and AI system report generators derive accurate real-time workloads.

---

# ⚡ Arcane System Upgrade // v2026.9.12 (Build #2126091205)

### 🚀 Timeline & Time Calculation High-Performance Overhaul
- **Eliminated UI Thread Freezes & ANRs**: Identified and completely resolved an $O(K^2)$ quadratic sweep-line recalculation that was running unindexed across the entire database history on UI builds and provider updates.
- **Reference-Based Identity Memoization**: Added instant $O(1)$ memoization to `TaskCalculations.recalculateAllTimeLogs` via `identical(_cachedTasksRef, allTasks)`. Repeated queries during UI layout, continuous animations, scrolling, card dragging, and resizing return immediately with zero recomputation.
- **Localized Per-Day Sweep-Line Partitioning**: Restructured the interval processing to bucket sessions strictly by calendar day. Over 90% of days take a fast path with zero sorting or sweep-line overhead, and multi-session days process only the localized daily subset.
- **RepaintBoundary Timeline Grid**: Isolated the 24-hour hairline divider and background grid in a dedicated `RepaintBoundary`, preventing expensive canvas repaints during card interactions.
- **Selective Handle Rendering & Tap Isolation**: Constrained resize handle widget subtree instantiation strictly to selected cards, and fixed background touch interception to prevent accidental deselection on card taps.

---

# ⚡ Arcane System Upgrade // v2026.9.12 (Build #2126091204)

### 📊 Local Overlap Clustering on Timeline
- **Non-Squishing Isolated Tasks**: Isolated events and tasks with no concurrent overlap retain 100% full-width layout across the timeline sheet rather than dividing the entire page.
- **Local Overlap Partitioning**: Intersecting events are grouped into connected overlap clusters, dynamically assigning side-by-side columns only to concurrent tasks within that specific time window (`totalCols = clusterColumns.length`).
- **Free-Column Expansion**: Non-overlapping segments inside larger clusters automatically expand horizontally across adjacent unoccupied columns using calculated column spans (`colSpan`).

### ⏱️ Strict Wall-Clock Time Averaging (Sweep-Line Time Log Slicing)
- **Zero Double-Counting**: When concurrent missions run or overlap in the schedule timeline, time logs are partitioned into disjoint timestamp slices. For each slice with $N$ concurrent tasks, elapsed duration is allocated evenly ($\Delta t / N$).
- **Conservation of Wall-Clock Time**: Total recorded time across all tasks is strictly guaranteed to never exceed real-world elapsed wall-clock time ($\sum \text{TaskTime} \le \text{ElapsedTime}$).
- **Concurrent Session Validation**: Updated `TimeValidationHelper` to permit concurrent sessions across distinct tasks and subtasks, preventing false collision rejections while maintaining integrity against duplicate sessions for the exact same subtask.

---

# ⚡ Arcane System Upgrade // v2026.9.12 (Build #2126091203)


### ⏱️ 2-Minute Precision Snapping, Drag-Through-Time & Fast Mission Switching
- **Granular 2-Minute Snapping**: Upgraded the timeline precision across all time adjustments from 15-minute steps down to ultra-precise 2-minute increments. Both edge resize handles and whole-card drags automatically snap to the 2-minute timeline grid.
- **Drag Cards Through Time (Google Calendar Paradigm)**: Replaced the previous long-press edit dialog with direct drag-through-time manipulation. Long-pressing an editable event lifts it with elevation and shadow, locks scroll physics, displays top and bottom time guidelines and duration telemetry in real time, and cleanly updates the session bounds upon release.
- **Conflict-Free Drag Coordination**: Intelligent hit testing prevents timeline background range creation when touching or long-pressing existing cards.
- **Double-Tap Mission Selector**: Double-tapping any event card instantly brings up the "SWITCH MISSION" dialog with full protocol hierarchy, allowing seamless instant reassignment of sessions across subtasks while preserving duration and timing without misleading undo snackbars.

---

# ⚡ Arcane System Upgrade // v2026.9.12 (Build #2126091202)

### 📅 Schedule Timeline Drag-to-Resize & Google Calendar Handles
- **Interactive Drag-to-Create Time Blocks**: Enabled drag-to-create gestures across the schedule timeline with real-time start/end time markers, duration badges, and instant task assignment sheet on finger release.
- **Direct Edge Drag-Resizing**: Integrated top-left and bottom-right Google Calendar-style resize handles supporting direct 15-minute snapped drag adjustments with live time indicators and duration feedback chips (`DUR: Xh Ym`).
- **Refined Minimalist Handle Geometry**: Sized handles to a crisp $\times 0.75$ scale ($7\text{px}$ diameter) without drop shadows, featuring $44 \times 44\text{px}$ hit targets and vertically symmetrical seating centered flush on the $2\text{px}$ border strokes.
- **Fluid Animated Transitions**: Added smooth `AnimatedContainer` transitions ($200\text{ms}$, `Curves.easeOutCubic`) for card border, glow, and padding morphing, paired with `AnimatedScale` (`Curves.easeOutBack`) and `AnimatedOpacity` ($180\text{ms}$) on handle appearance and exit. Drag operations seamlessly switch to `Duration.zero` for lag-free 60fps tracking.

---

# ⚡ Arcane System Upgrade // v2026.9.12 (Build #2126091201)

### 🏗️ Codebase Modularization & Architectural Decomposition
- **Monolithic Screen & View Decomposition**: Refactored massive UI monoliths (Today Planner, Bus Schedule, Health Dashboard, Goals Drawer, Journaling Reviews, Settings, and Homescreen Studio) into modular domain-specific component libraries and subpackages.
- **Component Separation & Reusability**: Extracted standalone dialogs, section widgets, and HUD modules (Hextech, NFS, Tactical HUD) into dedicated files, dramatically improving maintainability and readability while preserving all state management and dual-theme fidelity.
- **Full Test Suite & Dual-Theme Parity**: Verified 100% test pass rate across all 70 test suites, with full dual-theme adaptation (`JweTheme`) and zero static analysis errors across all newly modularized components.

---

# ⚡ Arcane System Upgrade // v2026.9.8 (Build #2126090801)

### ⚡ Wearable Auto-Reply & Interactive Energy Check Telemetry
- **Direct Inline RemoteInput**: Replaced static action buttons with an Android 14 `RemoteInput` direct inline reply action featuring predefined quick-reply chips (`yes`, `no`) and freeform voice/keyboard entry.
- **Wear OS / Smartwatch Auto-Reply Parity**: Configured `AndroidNotificationCategory.message`, `NotificationCompat.Action.SEMANTIC_ACTION_REPLY`, and `NotificationCompat.WearableExtender` allowing direct 1-tap quick replies from Wear OS watch notification cards.
- **Android 14 System-Level Architecture**: Created native Kotlin `EnergyNotificationHelper` and `EnergyReplyReceiver` with `FLAG_MUTABLE` PendingIntents, `android:exported="false"`, and instant inline acknowledgement updates to dismiss OS reply loading spinners.
- **AI-Powered Tactical Advisor & Feedback Notification**: User replies ("yes", "no", or custom fatigue notes) are automatically evaluated by AI, logged to Health metrics, and answered with immediate tactical advice via heads-up notification (`◢ ARCANE // ENERGY ADVISOR`).
- **Headless Background Engine**: Replies received when the app process is terminated are processed in a detached background isolate or Kotlin receiver, persisting logs to local storage and dispatching AI advice seamlessly upon launch.

---

# ⚡ Arcane System Upgrade // v2026.9.7 (Build #2126090702)

### 📱 Responsive Mobile Layout & Overflow Elimination
- **AI Model Selection & Rolling Fallback Shield**:
  - Replaced unconstrained priority button rows with `VisualDensity.compact` and bounded constraints (`minWidth: 28, minHeight: 28`) with zero padding, eliminating RenderFlex horizontal overflows on narrow screens (<360px).
  - Added ellipsis truncation (`maxLines: 1`) to model priority slot titles inside `Expanded` blocks.
  - Wrapped custom model prompt menu item inside `Expanded` with text ellipsis to prevent dropdown popup menu overflows.
  - Scaled action button labels (`ADD $prefix FALLBACK` and `REFETCH AVAILABLE GEMINI MODELS`) dynamically with `FittedBox` to guarantee clean rendering on all screen widths.
  - Replaced fixed-width dialog constraints with responsive `maxWidth: 460` and `EdgeInsets.symmetric(horizontal: 16, vertical: 24)` inset paddings in model identifier dialogs.
- **Update Alert Window Responsive Overhaul**:
  - Bound update dialog height dynamically via `(MediaQuery.of(context).size.height * 0.85).clamp(380.0, 640.0)` with responsive inset padding, completely preventing vertical screen clipping and overflows on compact phones or landscape orientations.
  - Implemented responsive 2-tier footer via `LayoutBuilder`: on mobile widths (`< 360px`), primary download/install actions expand to full width while secondary actions (`LATER` and `REDOWNLOAD`) nest gracefully below.
  - Added text overflow shields and ellipsis to header HUD title, subtitle, cached APK status pill, and download percentage indicators.

---

# ⚡ Arcane System Upgrade // v2026.9.7 (Build #2126090701)

### 🎯 Manual-Only Checkpoints & Cleaner Planner Cards
- **Eliminated Automatic Checkpoint Population**: Removed all auto-generation and automatic inheritance of subtask checkpoints when adding missions to the day plan or initializing planner rows. All checkpoints in the planner are now strictly manual.
- **Dynamic Checkpoint View Suppression**: Single plan cards and multitask (2-in-1 / 3-in-1) cards now completely hide the checkpoint dropdown panel and checkpoint ratio indicators when an item has zero checkpoints, eliminating visual clutter.
- **On-Demand Manual Checkpoint Creation**: Operators can still manually attach checkpoints anytime via the `ADD CHECKPOINT` option in the card action menu or checkpoint modal.

### 📐 Tactical Row Merging (Merge to Top & Bottom Rows)
- **Direct Row Merge Controls**: Added `MERGE TO TOP ROW` and `MERGE TO BOTTOM ROW` options directly to the mission card action menu across single, dual, and triple cards.
- **Fluid Multitask Row Assembly**: Move single or multi-column missions directly into adjacent rows with automatic empty row cleanup, bounds checking, and strict 3-mission maximum enforcement (`TACTICAL OVERLOAD`).
- **Seamless State Persistence & Dual-Theme Parity**: Automatically persists merged row layouts to day plan history with theme-adaptive action icons and typography (`JweTheme`).

---

# ⚡ Arcane System Upgrade // v2026.9.6 (Build #2126090604)

### 📋 Day Plan Homescreen Widget Overhaul & Widgets Studio Integration
- **Lightweight Card Architecture**: Replaced the fragile 335-line, 5-row checklist layout in `widget_dayplan.xml` with the proven lightweight single-card tactical architecture (17 elements, depth 5), matching Bus, Finance, and Journal widgets and completely eliminating launcher RemoteViews inflation crashes.
- **Defensive Android Lifecycle & Logging**: Added comprehensive `try/catch` error logging to `DayPlanWidget.kt` and extracted `renderDayPlanLayout` to cleanly bind the active queue, next in line, and quick action intents (`OPEN PLAN`, `CHECK`, `ENGAGE`).
- **Instant Check Feedback**: Wired `task_check_0` and `task_check_` action intents in `WidgetActionReceiver.kt` to trigger immediate visual updates and haptic confirmation on `DayPlanWidget` instances.
- **1:1 Flutter Day Plan Widget**: Introduced `DayPlanHomeWidget` with complete dual-theme compliance (`JweTheme.panel`, `JweTheme.accentCyan`, `JweTheme.textWhite`, etc.), mirroring the native 4x2 tactical card in-app.
- **Widgets Studio Live Preview**: Integrated `DayPlanHomeWidget` into `HomescreenWidgetsPreviewScreen` ("Widgets Studio") in the DAY PLAN tab for real-time state inspection and homescreen pinning.

---

# ⚡ Arcane System Upgrade // v2026.9.6 (Build #2126090603)

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

---

# ⚡ Arcane System Upgrade // v2026.9.6 (Build #2126090602)

### 📋 Lightweight Day Plan Homescreen Widget & Studio Integration
- **Streamlined Native XML Hierarchy**: Re-engineered Day Plan widget layout (`widget_dayplan.xml`) with a flat, lightweight hierarchy (~170 lines) eliminating RemoteViews view tree overflow and launcher inflation crashes.
- **Dedicated Android System Widget Provider**: Registered `Arcane — Day Plan` (`DayPlanWidget`) directly in the Android home screen widget manager (`widget_dayplan_info.xml`), enabling standalone discovery and pinning.
- **Dynamic Inflation Integration**: `RunningTaskWidget` now dynamically inflates `widget_dayplan` when `dayPlannerWidgetCheckable` is active, stripping 70+ lines of redundant XML from `widget_running_task.xml`.
- **In-App Widgets Studio Dedicated Day Plan Tab**: Expanded `HomescreenWidgetsPreviewScreen` with a dedicated 5th tab ("DAY PLAN"), complete with interactive preview, mock task population, state toggles, and direct launcher pinning (`requestPinDayPlan()`).
- **Flutter UI Preservation**: Maintained exact parity and functionality for the in-app Flutter day planner widget (`RunningTaskHomeWidget`).

---

# ⚡ Arcane System Upgrade // v2026.9.6 (Build #2126090601)

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

# ⚡ Arcane System Upgrade // v2026.9.5 (Build #2126090508)

### 🎯 Submission Checkpoint Depth Control & Level-Based Quick-Check
- **Configurable Checkpoint Depth**: Added a `depth` property to Submissions (`SubTask`), defaulting to `MAX` (deepest leaf checkpoint). Operators can configure depth (`MAX`, `L1`, `L2`, `L3`) to target higher-level checkpoints.
- **Hierarchy-Aware Resolution**:
  - `TaskCalculations.nextCheckpoint` and day plan resolution now surface checkpoints matching the configured depth level rather than always descending to the lowest leaf.
  - When `depth` is set (e.g. `L1`), checking off "NEXT STEP" or marking a checkpoint in Today Planner, Schedule Hero, or active timers checks off that checkpoint and cleanly cascades completion to all of its nested child substeps.
- **Instant Depth Switching**:
  - Added a tactical depth selector chip (`MAX`, `L1`, `L2`, `L3`) directly on `SubmissionCard` in the list view for rapid level switching.
  - Added depth selector to `SubmissionDetailScreen` header with quick-access menu.
  - Integrated full tactical depth picker into `SubtaskConfigDialog` with contextual descriptions explaining each level.
- **Dual-Theme Tactical Parity**: Styled all depth selector chips, dropdowns, and popup menus using `JweTheme` dynamic tokens for seamless light and dark mode support.

---

# ⚡ Arcane System Upgrade // v2026.9.5 (Build #2126090507)

### ⚠️ Pre-Flight Daily Telemetry Alert
- **Movement & Financial Verification**: Integrated intelligent pre-flight data integrity validation prior to generating or regenerating Daily Briefings in `DailySummaryView`.
- **Missing Telemetry Intercept**: Checks if movement logs (`walkDistanceKm > 0`), workout records (`workoutMinutes > 0`), or financial transactions (`transactions`) exist for the target date.
- **Tactical Confirmation Modal**: If data is missing, prompts the operator with a high-contrast `MISSING DAILY TELEMETRY` warning detailing what is missing, with options to **"LOG DATA FIRST"** (preventing incomplete summaries) or **"PROCEED ANYWAY"**.
- **Safe Retry Pipeline**: Telemetry verification runs prior to deleting or overriding existing briefings during manual retries, safeguarding generated records from premature deletion.

### ⏱️ 2x Pro Mode AI Timeouts
- **Extended Compute Windows**: Doubled execution timeouts across all deep-reasoning AI generation pipelines to accommodate thorough analysis and comprehensive synthesis without premature truncation:
  - **Daily Briefing & Startup Briefing**: 30s ➔ **60s**
  - **Weekly Performance Review**: 1m ➔ **2m**
  - **Monthly Strategic Review**: 2m ➔ **4m**
- **Synchronized UI Telemetry**: Aligned countdown timers and tactical progress telemetry in `TacticalBriefingIndicator` and AI generation services to reflect the extended compute allowances.

### 🛡️ Debug Build Update-Check Bypass
- **Compile-Time Environment Isolation**: Configured `UpdateService` to detect debug environments via Flutter's runtime flags (`kDebugMode || !kReleaseMode`), reliably distinguishing debug builds without relying on shared signing keystores.
- **Suppressed Dev Update Prompts**: Bypasses background and startup update checks on debug APKs, preventing development environments from inadvertently prompting for or downloading production releases.
- **Tactical Settings Feedback**: Manual "CHECK FOR UPDATES" in Settings cleanly notifies developers that update checks are bypassed in debug builds.

---

# ⚡ Arcane System Upgrade // v2026.9.5 (Build #2126090506)

### 🥗 Structured Nutrition Logging in Daily Reflections
- **Dynamic Structured Food List View**: Replaced the single freeform nutrition textfield in the Daily Reflection editor with a dynamic list view asking for **Item Name** and **(Duration / Amount)** per item.
- **Dynamic Row Management**: Easily add and remove food items dynamically with high-contrast tactical indexing badges (`01`, `02`, etc.) and instant row deletion controls.
- **Dual-Theme Adaptive Styling**: Seamless warm tactical paper/stone palette in light mode and operator midnight contrast in dark mode via `JweTheme` dynamic tokens.

### 🧠 Clinical AI Nutrition Engine & Multi-Metric Breakdown
- **Comprehensive Nutritional Metrics**: Upgraded AI nutrition prompts to compute full clinical nutrient profiles:
  - Macro energy: `Calories` (kcal), `Protein` (g), `Carbohydrates` (g), `Lipids / Fat` (g)
  - Key micro-nutrients: `Fiber` (g), `Sugar` (g), and `Sodium` (mg)
  - Trace micronutrients: dynamic vitamin, mineral, and electrolyte estimates (e.g., Vitamin C, Iron, Potassium, Calcium, Magnesium)
  - Physiological appraisal: Health benefits, clinical dietary warnings/allergens, and concise nutritional description.
- **Portion & Duration Awareness**: The AI model now analyzes nutritional values tailored specifically to the user's portion amount or consumption duration.
- **Offline Fallback Reliability**: Graceful offline fallback logging ensures meals are always logged to Bio and Daily Health logs even without an internet connection or AI key configured.

### 📊 Extended Health Telemetry & Bio Dashboard
- **Nutritional Summary Secondary Row**: Added a dedicated secondary telemetry row in the Health Dashboard Nutrition tab summarizing daily totals for **Fiber**, **Sugar**, and **Sodium**.
- **Meal Protocol Card Overhaul**: Logged meal protocol cards now showcase:
  - Approximate portion amount badge in header.
  - Energy, Protein, Carbs, Fat, Fiber, Sugar, and Sodium breakdown.
  - Cyan `HudChip` badges for identified vitamins, minerals, and micronutrients.
  - Benefit tags and highlighted dietary warning callouts.
- **30-Day Health Stats Averages**: Aggregated 30-day running averages for daily fiber, sugar, and sodium intake in the Health Telemetry & Longevity tab.

### 🔄 Checkpoint Uncomplete Cascading Fix
- **Hierarchical Checkpoint Uncomplete**: Restored cascading uncomplete logic in `TaskActions.uncompleteSubtask` so that unchecking a parent subtask cleanly unchecks all of its descendant checkpoints and nested substeps.

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

### 📱 Native Android Homescreen Tactical HUD Overhaul
- **Native RemoteViews Tactical XML Parity**: Completely overhauled `widget_running_task.xml` and Android vector drawables to mirror the in-app Schedule Hero HUD aesthetics.
- **Chamfered 4-Corner Geometry & Brackets**: Implemented precision-angled vector corner notches and reinforced HUD bracket styling for Cyan (`#00F0FF`), Amber (`#FFB547`), Red (`#FF2A4B`), and Dim Standby modes.
- **Multitask RemoteViews Architecture**: Native layout and binding for 2-in-1 and 3-in-1 concurrent task cards with parent hierarchy, 01/02/03 indexing, and live checkpoint counts.
- **HUD Status Bar & Action Controls**: Added status dot, monospace protocol state indicator, `REC` indicator, `DAY PLAN` quick-access navigation, and high-contrast tactical action buttons (`ENGAGE ALL` / `HALT SESSION`, `CHECK`, `FINISH`).

### 🚫 Phoenix Protocol Deprecation
- **Clean Protocol Architecture**: Fully removed deprecated Phoenix protocol remnants and obsolete triangle corner painters for a streamlined, performance-optimized mission execution pipeline.

### 🌓 Complete Dual-Theme Architecture & Light Mode Parity
- **Warm Tactical Paper / Stone Light Theme**: Fully adapted Today Planner screen, Schedule Hero widget, Tactical Card Border painter, and Homescreen widgets to support both Dark (operator midnight) and Light (tactical warm paper/stone) modes via `JweTheme` dynamic tokens.
- **Dynamic Accent & Border Calibration**: Integrated `JweTheme.calibrate` and dynamic `JweTheme.border` / `JweTheme.onAccent` resolution across all tactical chamfered card borders, status indicators, and action buttons for maximum contrast and readability in light mode.
- **Android RemoteViews Native Dual-Theme Support**: Deployed qualified Android resource directories (`res/values/widget_colors.xml` for light mode and `res/values-night/widget_colors.xml` for dark mode), delivering automatic, system-synchronized dual-theme support across all native homescreen widgets without code regressions.
### 🎯 Mobile Touch Drag Stabilization & Auto-Scroll
- **Zero-Shift Drop Dividers**: Stabilized drop divider geometry to a fixed 18px layout height, completely eliminating the rapid layout-jump oscillation caused by expanding and collapsing drop zones when dragging over card edges on mobile touchscreens.
- **Precision Drop Target Filtering**: Prevented redundant drag hover on the source row itself, preventing flickering and self-highlighting loops during drag gestures.
- **Drag-to-Edge Auto-Scrolling**: Implemented dynamic continuous auto-scrolling when dragging plan cards near the top or bottom edges of the screen, with proportional speed ramping and instant cancellation on drag release.
- **Generous Touch Target Hitboxes**: Expanded drag indicator touch targets to 36x36px padded opaque hitboxes for effortless, accurate grip on mobile screens.

### 🔽 Collapsible Checkpoints Dropdown (Closed by Default)
- **Compact Default Card Heights**: Re-architected the subtasks and checkpoints panel inside full-width plan cards into an expandable dropdown that defaults to collapsed, giving all plan cards a clean, unified height.
- **Tactical Checkpoint Telemetry**: Preserved at-a-glance status in the collapsed header (`CHECKPOINTS (0/X)`, duration, and mini progress bar), with one-tap smooth animated expansion to view and check off items.

### 🚀 Version-Code Aware Updater & Automatic Post-Update Telemetry
- **Automatic Post-Update "What's New" Dialog**: Integrated persistent build number tracking via `SharedPreferences` (`last_seen_build_number`). When the app launches following a version code change, Arcane automatically presents the "SYSTEM UPDATED // WHAT'S NEW" dialog with release notes.
- **Build Number Upgrade Telemetry**: Enhanced update dialogs to explicitly display current and target build numbers (e.g. `v2026.9.5 • Build #2126090504 ➔ #2126090505`), ensuring upgrades with identical date strings are immediately distinguishable.
- **On-Demand Build Notes in Settings**: Added a direct "VIEW WHAT'S NEW (BUILD NOTES)" button in Settings for anytime inspection of build notes.
- **Synchronized Release Metadata**: Aligned `update_info.json` and `latest.json` release manifests to track active build codes across deployments.


