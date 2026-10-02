# ⚡ Arcane System Upgrade // v2026.10.2 (Build #2126100211)

### 🎙️ Configurable Mic Tap Delay & Calibration for External Assistants
- **Watch Mic Sync Latency Calibration**: Resolved an issue where external assistants (ChatGPT, Gemini, etc.) bound prematurely to the phone's built-in microphone and speaker when launched from external wearables or Bluetooth triggers. Wearables and headsets often require a brief interval (800ms–1500ms) to initialize their Bluetooth SCO audio channels.
- **Configurable Delay Controls**: Added a customizable mic-tap delay setting in both the Custom Assistant Picker and Advanced AI Settings:
  - Preset quick-select chips (`500ms`, `800ms`, `1000ms`, `1200ms`, `1500ms`, `2000ms`, `3000ms`).
  - Fine-grained slider allowing adjustments from `200ms` up to `4000ms`.
- **Intelligent Dispatch**: `LauncherTakeoverService` honors the configured delay when auto-tapping the external assistant's microphone button upon window transition or warm foreground activation.

### 📞 Experimental Bluetooth Call SCO Audio Simulation
- **Force Audio/Mic to Call-Only Smartwatches**: Added an optional tactical switch (`[EXPERIMENTAL · CALL-ONLY WATCHES]`) in Settings designed for smartwatches and Bluetooth accessories that only support phone call protocols (HFP/SCO) rather than standard media streaming.
- **Bi-directional In-Call Audio Routing**: When enabled, Arcane simulates an active communication state (`MODE_IN_COMMUNICATION`), engages the Bluetooth SCO link, and directs both voice playback and microphone input to the connected Bluetooth wearable.
- **Silent PCM Keep-Alive & Safety Watchdog**: Features a low-level silent PCM keep-alive audio track to prevent Android's audio server from tearing down the SCO link while waiting for the assistant app to bind, along with an automated 60-second safety watchdog timeout to prevent accidental permanent in-call audio locks.
- **Optional & OEM-Guarded**: Marked clearly as experimental since behavior varies across Android OEM audio stacks; disabled by default to ensure maximum stability.

---

# ⚡ Arcane System Upgrade // v2026.10.2 (Build #2126100210)

### 🎯 Input-Reply Calibration, Keyboard Interception & Send Button Accuracy
- **Precision Touch Pointer Centering**: Eliminated the vertical offset in `TouchSensorLayer` caused by window insets / status bar heights. The touch pointer, tactile ripples, and center reticle now render exactly at the physical touch point. Added real-time tactical reticle indicators on screen during macro replay.
- **Hardware & Navigation Back Key Interception**: Integrated `flagRequestFilterKeyEvents` and `onKeyEvent` into the Accessibility takeover service to capture hardware Back and navigation bar Back taps as `type: "key", key: "BACK"`. Replaying a Back key dismisses virtual keyboards with an automated 350ms transition delay before executing subsequent steps.
- **Messaging App 'Send' vs 'v' Fixed**: Identified and resolved the root cause where missing node lookups defaulted to screen center bottom coordinates $(0.5, 0.85)$, which coincided with the virtual keyboard's 'v' key. Send actions are now guarded against keyboard center coordinates, shifting automatically to the right-hand send area $(0.92, 0.58 / 0.94)$ and scanning all interactive windows via `clickSmartSendButton()`.

### 🚀 Update Detection Fix Across Split-per-ABI Builds
- **Normalized Version Codes**: Resolved false negative update checks where Flutter's `--split-per-abi` offsets (`arm64-v8a: +2000`, `armeabi-v7a: +1000`, `x86_64: +4000`) caused local build numbers (e.g. 2126102209) to appear larger than base remote build numbers (e.g. 2126100210).
- **Architecture Code Matching**: Added `apk_arch_version_codes` mapping to `update_info.json` and `UpdateModel`, and implemented `normalizeVersionCode` to strip ABI offsets, with fallback to semantic version string comparisons.

---

# ⚡ Arcane System Upgrade // v2026.10.2 (Build #2126100209)

### 🔓 Automated Lock Screen Unlock Sequence for External AI Assistants
- **Two-Step Automated Movement**: When launching an external AI assistant (ChatGPT, Gemini, Claude, Perplexity, Copilot, or custom app) while the device is locked (e.g. from smartwatch or Bluetooth voice triggers), Arcane automatically executes:
  1. **Movement 1**: Dispatches the recorded screen unlock gesture (e.g., swipe up) to dismiss the keyguard.
  2. **Movement 2**: Launches the external assistant directly into voice mode and auto-clicks the microphone button using the calibrated coordinates.
- **Lock Screen Unlock Gesture Calibration**: Added dedicated calibration flow:
  - Arcane locks the device via accessibility command (`GLOBAL_ACTION_LOCK_SCREEN`).
  - Automatically wakes up the screen with high-priority wake lock and mounts `UnlockSensorOverlay` directly over the Keyguard.
  - Intercepts and traces operator's natural unlock movement (swipe up) while passing the stroke through to the system lock screen.
  - Automatically commits and locks in the gesture coordinates upon device unlock (`ACTION_USER_PRESENT` / keyguard dismissal).
- **Tactical Lock Screen Calibration HUD**: Features crosshair drag trail, coordinate vector readout, cancel controls, and clear haptic confirmation.
- **Unlock Testing & Management Controls**: Operators can test the recorded unlock gesture, view saved normalized coordinates and percentages, tweak or recalibrate, and clear the gesture at any time in Custom Assistant Settings and Advanced AI Settings.

---

# ⚡ Arcane System Upgrade // v2026.10.2 (Build #2126100208)

### 🛡️ Ironclad Data Saving & Offline-First Cloud Sync Fix
- **Zero Local Data Loss**: Eliminated the critical bug where local uncommitted changes were overwritten by background cloud sync. The sync engine strictly enforces that whenever local unsaved changes exist (`_hasUnsavedChanges == true` or `_dirtyCollections.isNotEmpty`), local data always takes precedence and is uploaded rather than wiped.
- **Timestamp Desync Loop Eradicated**: Synchronized the timestamp source of truth (`settings.lastModified` and `users/$userId/lastModified`) across all collection chunks and RTDB nodes before serialization. `_manuallyLoadFromCloudInternal` guarantees local timestamp matches or exceeds remote RTDB timestamp, preventing the recurring desync loop.
- **Forced Collection Persistence**: `autoSyncWithCloud()` and `performManualSync()` execute saves with `force: true` to ensure all state categories (tasks, history, reflections, finance, health, trading, settings) are written to RTDB even if collection dirty flags were reset.
- **Network Hang Protection & Sanitization**: Added 15-second timeouts (`_rtdbTimeout`) to all Realtime Database calls and sanitized RTDB node keys, preventing socket stalls from locking background sync indefinitely.
- **Automatic State Restoration**: `_manuallyLoadFromCloudInternal` and `_performActualSaveInternal` safely persist local snapshots atomically, guaranteeing 100% offline-first reliability.

### 👆 Touch-Sensor Macro Automation & Keyboard Interception
- **Full-Screen Physical Touch Sensor**: Replaced inaccurate bounding box guesses with a physical full-screen `TouchSensorLayer` capturing exact tap and swipe `(rawX, rawY)` coordinates with tactical visual reticle animations and haptic feedback.
- **Automatic Soft-Keyboard Pass-Through**: The touch sensor layer automatically yields (`FLAG_NOT_TOUCHABLE`) when the virtual keyboard opens, enabling completely unobstructed typing in search bars and forms.
- **Tactical Keyboard Guidance**: HUD controller dynamically displays `⌨ KEYBOARD OPEN · CLOSE KEYBOARD TO SUBMIT` when typing, and Macro recording setup sheets advise operators to close the virtual keyboard before tapping submit buttons so the physical tap is captured precisely.

---

# ⚡ Arcane System Upgrade // v2026.10.2 (Build #2126100207)

### 🔋 Unified Notch Status Bar & Real Hardware Telemetry
- **Hardware Telemetry Readout**: Upgraded `LauncherBridge` to query hardware `BatteryManager.BATTERY_PROPERTY_CAPACITY` and direct `isCharging` state alongside receiver updates. Added signal strength calculation fallbacks.
- **Notch / Cutout Alignment**: Mounted tactical status bar directly in the top notch zone (`max(viewPadding.top, 28.0)`) with content vertically centered.
- **Unified Screen Architecture**: Single persistent status bar in `LauncherScreen` body across all screens (Widgets, Home, Drawer), dynamically padded in child views so content does not overlap. Automatically concealed when Arcane Mission views are focused.
- **Dual-Theme High Contrast**: Status bar text, clock, signal bars, and battery gauge render in crisp pure white (`#FFFFFF`) on dark mode, transitioning to tactical charcoal (`#1B2028`) on light theme.
- **Real-Time Digital Clock**: Integrated live-updating digital clock (`HH:mm`) with seconds-aligned tick updates.

### 🚀 Instant Auto-Update Delivery & Background Reliability
- **Unrestricted Update Detection**: Removed development/debug environment blockers in `UpdateService` and Settings manual checks.
- **Instant Cloud Update Prompting**: Wired Firebase Realtime Database stream (`watchAppUpdates`) directly to in-app update prompts (`promptUpdateIfAvailable`) for immediate notification delivery.
- **Background & Startup Update Sweeps**: Added 15-minute periodic update checks, connectivity-recovery update triggers, and an automated 4s post-boot update check in `LauncherScreen`.
- **HTTP Redirect & Download Reliability**: Relaxed `_isDownloadable` header checks to accept all 2xx and 3xx responses from GitHub raw releases.

---

# ⚡ Arcane System Upgrade // v2026.10.2 (Build #2126100206)

### 🔋 Tactical Status Bar (Battery & Range Bars)
- **Native Battery & Network Telemetry**: Integrated real-time hardware telemetry (`LauncherBridge.getBatteryAndNetworkStatus`) fetching battery percentage, charging state, active transport (`WIFI`, `CELLULAR`), network generation (`5G`, `4G`, etc.), and signal strength ($0\dots4$).
- **Fullscreen Tactical Status Bar**: Mounted `TacticalStatusBar` at the top of the launcher when running in fullscreen mode.
- **Stepped Range Indicator**: Displays 4 stepped signal strength bars styled in Valorant teal with offline/alert fail-safes.
- **Dynamic Battery Gauge**: Features battery percentage readout, charging lightning icon, and tactical dual-tone battery bar with alert thresholds (Teal $>30\%$, Amber $15\text{--}30\%$, Red $<15\%$).
- **Tactical Shade Expansion**: Tapping the status bar expands the system notification shade via native accessibility commands; long-pressing forces instant telemetry sync with haptic feedback.

### 🛡️ Valorant Tactical Styling Across All Launcher & Home Widgets
- **Hosted Android AppWidget Enclosure**: Encased non-adaptive native Android `AndroidView` widgets (`LauncherAppWidget`) into a chamfered tactical HUD frame with corner brackets (`Chamfer4CornerClipper`, `TacticalCardBorderPainter`), title headers (`// APP_WIDGET: [NAME]`), and dual-theme adaptation.
- **Adaptive Home Widgets**: Upgraded `DayPlanHomeWidget`, `FinanceHomeWidget`, `JournalHomeWidget`, and `BusHomeWidget` with chamfered geometry and tactical borders supporting light and dark themes.
- **Launcher Widget Deck Alignment**: Polished responsive card frames, tactical clock, focus gauge, system telemetry matrix, and quick notes pad.

---

# ⚡ Arcane System Upgrade // v2026.10.2 (Build #2126100205)

### 🔄 Background & Realtime Cloud Sync Engine
- **Non-blocking Realtime Sync**: Integrated reactive `watchLastModified` listener from storage service. Whenever remote data updates occur, Arcane silently compares timestamps and pulls fresh data in the background without UI interruption.
- **Auto-Sync on Connectivity Recovery**: Attached real-time `Connectivity` monitor that initiates instant data synchronization whenever device network connectivity is restored.
- **Background Periodic Syncing**: Configured a reliable 10-minute background periodic synchronization timer.
- **Lifecycle-Aware State Preservation**: Ensures state saves and background synchronization execute cleanly across all app lifecycle transitions (`paused`, `hidden`, `inactive`, `resumed`).

### 🛡️ Automated Daily Local Backups with 7-Day Retention
- **Automated Daily Snapshots**: Creates daily local snapshots (`backups/daily_backup_${userId}_YYYY-MM-DD.json`) during saves and daily reset events.
- **Strict 7-Day Retention Policy**: Prunes backups older than 7 days (`_pruneDailyBackups`), keeping local storage lean while ensuring a full week of disaster recovery points.
- **Multi-Tier Disaster Recovery**: In the event of primary cache and `.bak` cache corruption or deletion, `LocalStorageService` seamlessly falls back to the most recent daily backup snapshot.
- **Cross-Platform Data Recovery**: Enabled backup file discovery, inspection, and one-tap restore across Linux, macOS, iOS, Windows, and Android.

### ⚡ System Performance, Memory & Battery Optimizations
- **Image Cache Tuning**: Capped Flutter image cache to 40MB and 100 entries to prevent memory bloat during prolonged media and session browsing.
- **OS Memory Pressure Handling**: Implemented `didHaveMemoryPressure()` hook to purge image caches, analytics caches, calculations caches, and icon memory caches on OS memory warning signals.
- **Date Calculation Acceleration**: Replaced heavy `DateFormat` instantiation in tight recalculation loops with ultra-fast numerical date formatting (`_formatDateYmd`).
- **Duplicate Computation Elimination**: Streamlined task progress and submission card recalculations to eliminate duplicate time calculations.
- **Battery-Saving Background Suspension**: Automatically pauses 1s launcher clock ticks and 30s Binance market polling timers whenever the app is hidden or backgrounded.

---

# ⚡ Arcane System Upgrade // v2026.10.2 (Build #2126100204)

### 🎯 Multi-Method Voice-Tap Calibration & Touch Tracking
- **Multi-Method Input Tracking in Settings**: Upgraded External Voice-Tap Calibration with 4 selectable calibration methods:
  - 🎯 **Reticle / Crosshair (`reticle`)**: Tactical draggable screen reticle overlay (`ReticleCalibrationOverlay`). Operators can drag the crosshair directly over the voice switch in any third-party app and tap `[✓ LOCK TARGET]`. Completely bypasses accessibility limits and works even when apps block touch overdraw.
  - 👆 **Touch Sensor (`touch_sensor`)**: Full-screen transparent touch interceptor (`TouchSensorOverlay`). Tap the microphone button once on screen to capture exact physical touch coordinates, vibrate, and automatically lock coordinates.
  - 🔍 **Auto-Detect HUD (`auto_detect`)**: Tactical floating bar (`ExternalMicTapOverlay`) with real-time candidate detection and leaf-node drilldown.
  - 📐 **Manual Coordinates (`manual_coords`)**: Interactive normalized X% and Y% sliders with immediate `[APPLY COORDS]` and `[TEST TAP]` actions.
- **Overlay Permissions & Overdraw Protection**: Declared `SYSTEM_ALERT_WINDOW`, added `canDrawOverlays` permission check banner with direct `[GRANT]` shortcut in Settings, and added window type toggle (`Auto` / `System Alert Window` / `Accessibility Overlay`). Added `FLAG_NOT_TOUCH_MODAL` to prevent Android from filtering touches on obscured windows.

### 👆 Precision Touch Coordinate Interception for Input-Reply
- **Direct Physical Touch Coordinate Tracking**: Upgraded `InputReplyOverlay` with `FLAG_WATCH_OUTSIDE_TOUCH` and `FLAG_NOT_TOUCH_MODAL` to capture the exact physical screen coordinates `(rawX, rawY)` where the finger lands.
- **Child-Node & Point Resolution**: `InputReplyManager` maps observed touch points directly to the leaf button or clickable element (`findNodeAtPoint`), eliminating misclicks on large parent containers and chat list rows.
- **Removed Restrictive Size Gates**: Drill-down logic now inspects leaf buttons and action keys even in low-height bars or message input containers.

---

# ⚡ Arcane System Upgrade // v2026.10.2 (Build #2126100203)

### 🔀 Activity Splitting & Dedicated Task Affinities
- **Complete Activity Independence**: `MainActivity` and `LauncherActivity` are now strictly separate Android activities running in independent task affinities (`me.ihjas.missions.app` vs `me.ihjas.missions.launcher`).
- **Permanently Visible in Android Recents**: `MainActivity` runs as a standard app (`CATEGORY_LAUNCHER` without `excludeFromRecents`), ensuring it always stays visible in Android Overview / Recent Tasks, while `LauncherActivity` exclusively powers the home screen (`CATEGORY_HOME`, `excludeFromRecents="true"`).
- **Direct Route Binding**: `MainActivity` initiates directly on `/app` to launch Arcane (`HomeScreen`), while `LauncherActivity` initiates `/launcher`. Tapping Arcane from the launcher docks launches `MainActivity` directly as an independent task.
- **Shared Native Method Channels & Platform Views**: Both activities share native channels (`UpdateBridge`, `LauncherBridge`, AppWidgetHostView platform view factory) without interfering with each other's lifecycle.

### 📐 Navigation Bar Clearance & Non-Fullscreen Screen Layout
- **Dynamic Inset Calibration**: All views, tabs, and modals now strictly adapt to system navigation bar heights (`MediaQuery.of(context).padding.bottom`) and bottom navigation bar offsets (`64.0 + padding.bottom + 24.0`).
- **Zero Input Obscurity**: `TaskDetailsView`, `ScheduleTimeline`, `DailySummaryView`, `HealthDashboardView`, `ProjectsView`, `FinanceLedgerTab`, `FinanceBudgetTab`, `FinanceAnalyticsTab`, `WellbeingDrawer`, `NoraAiScreen`, and `CreateGoalSheet` now position all action buttons, input fields, and lists comfortably above the system bar.

---

# ⚡ Arcane System Upgrade // v2026.10.2 (Build #2126100202)

### 🚀 Instant App Updates via Firebase Realtime Database
- **Zero-Cache Update Delivery**: Added direct synchronization with Firebase Realtime Database (`app_updates/latest`), completely eliminating the 5-minute GitHub CDN / Fastly caching delay.
- **Real-Time Update Stream**: Operators receive instantaneous update notifications across active sessions via `watchAppUpdates()` stream, matching the speed of real-time task restoration.
- **Robust Multi-Tier Fallback**: Queries Firebase RTDB SDK, falls back to direct Firebase REST endpoint, and retains GitHub raw URLs with HTTP Range validation to prevent false 404 suppression on freshly pushed builds.

### 🎯 Input Reply & External Mic Calibration Precision (FIX 2 NORA)
- **Direct Physical Touch Replay**: Upgraded the input-reply macro engine from accessibility action dispatching to high-precision physical touch coordinate gestures (`dispatchTapGesture`), ensuring 100% reliable clicks on buttons in messaging and third-party apps.
- **Calibrated Touch Recording**: External AI mic-tap calibration records and triggers precise touch coordinates across custom UIs.
- **Smallest Clickable Leaf Node Targeting**: Improved node resolution to identify exact target elements without accidental container clicks.

### 🎙️ Nora Live AI Responsiveness & Performance
- **Fixed Tactical Data Analysis Stall**: Resolved live AI hang at "ANALYZING TACTICAL DATA..." by prioritizing stable Gemini 2.0 Flash production models over outdated preview endpoints.
- **Fast Voice Rendering**: Live voice interaction sessions now bypass artificial typing animations for immediate response playback.

---

# ⚡ Arcane System Upgrade // v2026.10.2 (Build #2126100201)

### 🌅 Tomorrow's Start-Up Sequence Advance Synthesis
- **Advance Morning Preparation**: Daily tactical briefings now automatically synthesize tomorrow morning's System Start-Up Sequence (`tomorrow_startup_report`) in advance to save critical time each morning.
- **Unified Engine Parity**: Both in-app Gemini synthesis and external AI manual briefing protocols generate and persist tomorrow's startup briefing databanks (`saveStartDayReport`), including motivational quotes, morning directives, obstacles & contingency plans, and reconnect recommendations.
- **Automatic Contact Sync**: Suggested reconnects and follow-up contacts synthesized in the advance morning report are immediately logged into the interaction registry for tomorrow.

### 📦 Robust File Sharing Intent for External AI Datasets
- **Intent Transaction Limits Solved**: Replaced raw string clipboard/binder intents (`Share.share`) with native file sharing (`Share.shareXFiles`) via temporary `.json` datasets. Prevents binder IPC payload crashes and transaction exceptions across all external AI features.
- **Universal App Compatibility**: Exported JSON datasets share cleanly to ChatGPT, Claude, Gemini, notes apps, and desktop sync targets with proper MIME types.

### 📋 Lightweight Schema-Only Prompts
- **Context-Free Clipboard Content**: The "Copy Prompt" action now generates a lightweight, schema-focused prompt without duplicative 30-day logs or raw task text.
- **Strict Separation of Concerns**: All activity telemetry, uncompleted plans, and reflection history reside exclusively in the exported JSON file, keeping prompt tokens small and within LLM clipboard buffers.

### 🔮 Future Schedule Predictor & Start-Time Calibration
- **Future Date Shadow Planning**: Unlocked schedule predictions for tomorrow and any future dates, eliminating the restriction to today only.
- **Interactive Start-Time Selection**: Configurable reference start time (defaulting to 08:00 AM for future dates) selectable via AppBar action chips, telemetry badges, and interactive time pickers.
- **Explicit 24h Output Formatting**: Both internal and external AI engines now generate explicit `"startTime": "HH:mm"` and `"endTime": "HH:mm"` sessions anchored strictly to the target inspection date.

---

# ⚡ Arcane System Upgrade // v2026.10.1 (Build #2126100105)

### 🔮 External AI Schedule Predictor & Non-Editable Blueprint Overlay ("OVY")
- **Zero-Latency External Day Planning**: Integrated an external AI schedule synthesis pipeline allowing operators to leverage frontier LLMs (ChatGPT, Claude, Gemini, Perplexity) to predict and structure their daily missions.
- **Dedicated Telemetry Dataset & Prompt Generator**: Long-press on the timeline crystal ball control icon or choose from the options menu to open the dedicated External AI Schedule screen. Generates rich contextual telemetry (uncompleted day plan, 14-day timeline history, 30-day reflection logs, task registry, today's goals, and reference time) alongside a strict JSON schema prompt with 1-tap clipboard copy and Android share sheet (`Share.share`).
- **Persistent Non-Editable Blueprint Overlay**: Parsed external AI schedule predictions render as ghost blueprint background cards (`isPredicted: true`, `isEditable: false`) stored persistently in `SharedPreferences` across app restarts.
- **Physical Overdraw Architecture**: Predicted overlay blocks render underneath real sessions at full timeline width. Operators can seamlessly plan their day and drag-to-create or log real missions directly over and through predicted blocks without column squishing or overlap interference.
- **Interactive Overlay Management**: Tap any predicted overlay card to convert it directly into a real session or dismiss it. Active overlays trigger an amber indicator on the timeline crystal ball with clear overlay shortcuts.
- **RAM Footprint & Daemon Optimization**: Cleared dangling build daemons and bounded background execution memory.
- **Dual-Theme Tactical Parity**: Styled adhering strictly to `JweTheme` dual-theme guidelines in both dark and light modes.

---

# ⚡ Arcane System Upgrade // v2026.10.1 (Build #2126100104)

### 🎯 Input-Reply Macro Engine & Touch Precision Polish
- **Interactive Searchable App Selector**: Replaced raw package name entry with an interactive, searchable app picker querying `LauncherService.instance.apps` with instant filtering by name or package, native app icon rendering, and dual-theme tactical styling.
- **Robust Touch & Gesture Replay**: Resolved missed clicks (such as "Send" and submit buttons in messaging apps like WhatsApp/Telegram). Queries live on-screen element bounds and dispatches actual pointer gesture taps (`dispatchTapGesture`) in addition to accessibility click actions.
- **IME & Soft-Keyboard Action Interception**: Accurately captures IME soft-keyboard actions (Send, Done, Enter, Search, Go) during recording and executes them via `ACTION_IME_ENTER` on replay with coordinate fallbacks.
- **Smart Submit Button Fallback**: Added active-window inspection fallback (`clickSmartSendButton()`) to detect and trigger message submission buttons even across keyboard dismiss transitions.

### 🎙️ External AI Mic-Tap Calibration Floating HUD
- **Draggable Floating HUD Bar**: Summoned via Accessibility overlay (`TYPE_ACCESSIBILITY_OVERLAY`) over any external AI app (ChatGPT, Claude, Gemini, Perplexity, Copilot, etc.).
- **Live Candidate Inspection**: Dynamically tracks and displays live captured tap metadata (candidate view ID, description, or screen ratio coordinates) with a pulsating status indicator.
- **Explicit Save & Cancel Controls**: Interactive `[■ SAVE]` button securely commits calibrated mic-tap coordinates and metadata to `PREFS_AUTO_TAP` only when the user confirms the tap.
- **Emergency Abort `[✕]`**: Instant cancellation hides the overlay and preserves previous calibrations.

---

# ⚡ Arcane System Upgrade // v2026.10.1 (Build #2126100103)

### 🧠 External AI Briefing Synthesis Protocol
- **Zero-Latency External Synthesis**: Added a dedicated External AI Briefing tool to bypass slow in-app API response times via external frontier LLMs.
- **Hidden Gesture Trigger**: Long-press on any tactical briefing card, briefing indicator, "+ GENERATE BRIEFING" button, or archived briefing entry to launch the dedicated synthesis interface.
- **Comprehensive Context Export**: One-tap export compiling historical briefs (30 days of weekly briefs, 1 year of monthly briefs, 7 days of daily briefs) and dynamic activity telemetry (7 days for daily/weekly, 30 days for monthly: reflections, goals, transactions, time tracked per task, and known people).
- **Prompt & Schema Clipboard Generator**: One-click copying of custom briefing system prompts and strict JSON schemas tailored to Daily, Weekly, or Monthly reviews.
- **Native Android Share Sheet**: Dedicated "SHARE DATASET (JSON)" button enabling direct data sharing to external AI mobile clients or desktop sync targets.
- **Live Output Ingestion & Validation**: Automatic markdown code fence stripping, format validation, realtime persistence to AppProvider databanks, gratitude asset syncing, and seamless transition to post-briefing review screens.

### 📍 Tactical Goal Places & Contemplation Time Enhancements
- **Multi-Time Contemplation Windows**: Operators can set multiple contemplation times for daily goals with integrated reminder notifications and quick-snooze actions.
- **Dedicated Goal Places**: Tag goals with specific contextual locations (Home, Work, College, or custom places) rendered with distinct tactical color tokens and badges on goal cards.

---

# ⚡ Arcane System Upgrade // v2026.10.1 (Build #2126100102)

### 🧩 Input Reply Macro Parameters & Variable Resolution
- **Desktop `input-reply` Engine Parity**: Implemented variable parameterization matching the desktop python standard (`PARAM_RE` validation, substring matching, step splitting, and default fallbacks).
- **Template Placeholder Interpolation**: Supported `$param` and `${param}` template interpolation across Android native touch execution and Dart service resolvers.
- **Interactive Variable Manager**: Added a dedicated parameter management dialog with real-time validation, duplicate prevention, and substring selection directly from recorded typing blocks.
- **Inline Step Parameterization**: Quick-action `[+ VAR]` chips on typing steps in the timeline view to parameterize text directly, along with 1-tap variable unlinking (`Icons.link_off`).
- **Dynamic Replay Configuration**: Replay dialog now prompts for runtime variable substitutions pre-populated with defaults.

### 🚀 "START IN APP" Recording Mode with Instant Launcher Cache
- **Direct Launcher Cache Integration**: Instant app list population pulling directly from Arcane's `LauncherService.instance.apps` cache without IPC delay.
- **Real-Time App Filter Search**: In-modal filter search bar with clear action, native app icon rendering (`LauncherAppIcon`), and package identification tags.
- **Auto-Generated Macro Naming**: Automatically suggests macro names based on selected applications (`${appName}_Macro`).
- **One-Tap App Launch & Record**: Directly launches the target app and arms the floating HUD controller overlay in a single tap.
- **Recorder Hero Card Upgrades**: Added direct `[WHOLE DEVICE]` and `[START IN APP]` dual quick-action buttons on the Input Reply hero card.

---

# ⚡ Arcane System Upgrade // v2026.10.1 (Build #2126100101)

### 🎯 Period-Bound Goal Time Calculation & 12:00 AM Threshold
- **12:00 AM Goal Date Baseline**: Time-based goals (`GoalMetricType.timeCounter`) now calculate time spent starting strictly from 12:00:00 AM on the day of the goal (`startDateTime ?? parseDateFromPeriodKey(dateKey, scope)`), clipping task sessions to the goal's period window instead of pulling historical lifetime durations.
- **Dual Tracking Modes**: Added an explicit toggle option `"INCLUDE ALL-TIME TASK DURATION"` (`countAllTime`) for operators who want cumulative all-time history.
- **Goal Start Date Picker**: Integrated an interactive goal start date selector in `CreateGoalSheet` with 12:00 AM threshold badge and full dual-theme adaptation.
- **Tactical Briefing & Snapshot Sync**: Updated startup snapshot metrics, `GoalBriefingHelper`, and briefing UI widgets (`TacticalGoalsBriefingSection`, `StartDayGoalsSection`) to evaluate effective completion and progress ratios using dynamic period-clipped minutes.

### ⌨️ Universal Soft-Keyboard Input Interception
- **Dynamic Text Commit Tracking**: Enhanced `InputReplyManager.kt` and `launcher_takeover_service.xml` with `TYPE_VIEW_TEXT_CHANGED` accessibility event handling, ensuring text inputted via virtual/software keyboards is captured accurately during macro recording.

### 🛡️ Firebase Sync Memory Optimization & OOM Protection
- **Bounded Sync Buffering**: Optimized `SyncMixin` and `StorageService` to prevent OutOfMemory (OOM) crashes during large dataset migrations and periodic cloud syncs by bounding concurrent stream transformations and memory buffers.

### 🎙️ External AI Voice-Tap Calibration & Testing
- **HUD Capture Toast**: Displays immediate visual feedback via an Android HUD toast as soon as an external voice-switch touch coordinate or view ID is captured.
- **On-Device Trigger Test**: Added an interactive `"TEST"` action in Custom Assistant settings, enabling immediate verification and replay of recorded accessibility taps without triggering external wearables.

---

# ⚡ Arcane System Upgrade // v2026.9.30 (Build #2126093002)

### 🎬 Universal Whole-Device Input Reply & Macro Engine
- **Full-Device Interaction Recording**: Introduced `Input Reply`, a comprehensive device-wide macro recording and replay tool integrated directly into System & Utilities (`MoreScreen` under `TOOLS`).
- **Floating Tactical HUD Controller**: Summoned over all Android apps via Accessibility overlay (`TYPE_ACCESSIBILITY_OVERLAY`). Features live step counter, active application package badge, pulsing red recording indicator, and one-tap emergency stop (`[■ STOP]`).
- **Zero Special Overlay Permissions**: Seamlessly rendered via Arcane's Accessibility Service without requiring Android's intrusive `SYSTEM_ALERT_WINDOW` permission.
- **Deep Action Interception**: Automatically records user clicks, long presses, typing blocks, directional swipes/scrolls, launch intents, global keys (`BACK`, `HOME`, `RECENTS`), and inter-action delay timings.
- **`input-reply-agent-v1` Standard Parity**: 100% compatible with the desktop `input-reply` agent macro format. Macros can be shared between Android Arcane and the Linux desktop terminal (`~/.local/share/input-reply/recordings/`).
- **Dynamic Parameterization**: Transform any recorded typing block into a named variable parameter (e.g. `$query`, `$message`, `$recipient`) with custom descriptions and default values.
- **Configurable Replay Controller**: Replay macros with dynamic parameter substitutions, custom execution speed multipliers (`0.5x` to `2.0x`), and repeat loops (`1x` to `10x`).
- **Step Timeline Inspector**: Dedicated modal inspection sheet with step-by-step visual timeline, target descriptions, package tags, and one-click JSON clipboard export.
- **Dual-Theme Tactical Parity**: Styled strictly adhering to `JweTheme` dual-theme guidelines in both dark and light modes.

---

# ⚡ Arcane System Upgrade // v2026.9.30 (Build #2126093001)

### 🛸 Floating NORA Tactical AI & Hands-Free Wearable Companion
- **Floating NORA HUD Overlay**: Tactical floating companion drawn over all applications as an accessibility overlay (requires zero special overlay permissions). Features audio-reactive RMS pulsation, monospace telemetry (`[NORA]` / `[● REC]`), and automatic side-docking against the bezel when idle.
- **Interactive Transcript & Response Card**: Displays live speech transcription and streaming AI responses with single-tap fullscreen expansion (`[⤢ EXPAND]`), manual stop, and close actions.
- **Hands-Free Watch & Headset Auto-Mic**: Voice commands triggered via smartwatch or Bluetooth (`ACTION_VOICE_COMMAND`, `ACTION_ASSIST`) instantly route audio to Bluetooth and engage microphone listening immediately without requiring the operator to touch their phone.
- **Wearable Launch Mode Toggle**: Choose between launching full-screen Arcane or summoning the lightweight floating NORA HUD when initiating voice from your smartwatch.

### 🎯 Accessibility Voice-Tap Recording for 3rd-Party AIs
- **Record First-Time Voice Tap**: When using external AI providers (ChatGPT, Claude, Gemini, etc.) whose Android apps fail to auto-start microphone listening on launch, operators can record the voice switch click once in Settings.
- **Automated Replay**: Arcane captures the target view ID, description, or screen-ratio coordinates via Accessibility and automatically replays the tap every time the external AI is triggered from a smartwatch or headset.
- **Management Controls**: Test, view saved trigger tags, re-record, or clear recorded taps directly from the Custom Assistant Picker screen.

### 🛡️ Anti-Kill Shield & MIUI / HyperOS Home Persistence
- **MIUI Home Launcher Persistence**: Ensures Arcane remains the default home launcher on aggressive ROMs using Android 10+ `RoleManager.ROLE_HOME`, MIUI Preferred Apps Intent, and fallback settings.
- **Background Protection Checklist**: Comprehensive status checks for Accessibility Service, Battery Optimization exemption, MIUI Autostart, and Background Pop-up permissions.
- **Lock in Recents Visual Guide**: Guided walkthrough to lock Arcane in recent tasks memory, preventing MIUI from terminating background services.
- **System Shutdown & Crash Log Inspector**: Live diagnostic viewer for `CrashGuard` caught errors and unhandled exceptions with one-tap clipboard copy and log clearing.

### 🎨 Dual-Theme & Responsive Layout Polish
- **Dual-Theme Conformance**: Calibrated all new overlay and settings components with `JweTheme` design tokens, ensuring seamless transitions between midnight tactical dark mode and warm paper/stone light mode.
- **Narrow-Screen Optimization**: Resolved horizontal row overflows in header bars and dialog titles on compact device form factors.

---

# ⚡ Arcane System Upgrade // v2026.9.29 (Build #2126092901)

### 🤖 NORA Tactical AI: Gemini 3.8 Reasoning & Autonomous Database Actions
- **Gemini 3.8 & Flash-Live Reasoning**: Full support for next-gen `gemini-3.8-flash` and `gemini-3.8-flash-live-preview` thinking models. NORA uses step-by-step reasoning (`<think>` and `<thought>` scratchpads) to analyze objectives before orchestrating operations.
- **Robust Reasoning Parser**: Isolated thought extraction guarantees chain-of-thought scratchpads and markdown code blocks never disrupt structured JSON actions or crash parsing.
- **Direct Database Commands**: NORA can now autonomously create, schedule, complete, and remove tasks on your behalf:
  - `add_task`: Creates new missions, subtasks, or checkpoints under any objective with auto-generated compound IDs.
  - `add_to_plan`: Schedules tasks into Today's Plan with custom time estimates, automatically linking to newly created tasks.
  - `check_task`: Checks off tasks or checkpoints by compound ID or fuzzy title matching without requiring prior stopwatch run-time.
  - `remove_from_plan`: Removes items from the daily schedule queue.
- **Model Presets & Auto-Migration**: Added Gemini 3.8 tiers to NORA session parameters, settings view, and quick model picker. Existing user configurations automatically merge newly supported models on startup.
- **Dual-Theme & Narrow Screen Polish**: Adapted session controls to `JweTheme` warm paper/stone palette in light mode and resolved layout overflow in the session initialization header on compact screens.

---

# ⚡ Arcane System Upgrade // v2026.9.28 (Build #2126092804)

### 🛸 Floating Task Button: Redesign, AssistiveTouch Side-Settle & Keep-Alive
- **AssistiveTouch Side-Settle**: After 2.5s of idle time, the floating task button smoothly glides to the screen edge, tucks ~38% into the bezel, and dims to 38% opacity so it never obstructs your reading or apps. Tapping or touching instantly wakes it up to full opacity and brings it onto the screen.
- **Tactical HUD Visual Redesign**: Multi-gradient glassmorphic disc, ambient holographic glow halo, high-contrast concentric progress ring with rounded caps, cardinal reticle notches (0°, 90°, 180°, 270°), and tactile press response.
- **Reading & Paused Session Life**: When you pause your task/reading session, the button stays accessible in amber standby (play glyph ▶ and elapsed time) so you can resume anytime with a single tap instead of vanishing.
- **Background Keep-Alive**: Added native `TaskForegroundService` to ensure Android and aggressive OEM battery optimizers (MIUI/HyperOS) never kill Arcane during long reading and focus sessions.
- **Battery Optimization & Autostart Quick Steps**: Added in Settings → Home Launcher → *Floating task button* to easily grant background execution and autostart permissions.

---

# ⚡ Arcane System Upgrade // v2026.9.28 (Build #2126092803)

### 🛡️ Launcher Stability & Data Safety
- **Arcane stays your home app**: Android forgets the default home app whenever a launcher crashes, which is why it kept asking you to pick one. Arcane now catches crashes, restarts quietly and stays the default.
- **Crash log**: caught crashes are listed under More → Home Launcher → *Crash log* (copy / clear), so the real causes can be tracked down.
- **Fewer crashes**: loading the app list, app icons and icon packs no longer takes the launcher down on errors or low memory.
- **No goals sheet over the home screen**: the startup goals window now waits until you actually open Arcane, instead of popping up over the launcher after every restart.
- **Data-loss fix**: during startup the app could save its blank default state (or re-stamp old data as new) and then sync it over your real cloud data. Saving now pauses until your data has loaded, defaults can never look newer than real data, and sync compares the timestamp of the data as loaded.
- **Local save fix**: overlapping saves no longer collide ("Cannot rename file" errors).

---

# ⚡ Arcane System Upgrade // v2026.9.28 (Build #2126092802)

### 🎯 Floating Task Button
- **AssistiveTouch-style bubble**: a small floating button over every app, shown only while a task is running. It shows a pause icon, the elapsed time and a progress ring.
- **Tap** halts the running task (the bubble then hides until you start a task again).
- **Double-tap** checks off the current checkpoint and pops up a box to type the next one. The new checkpoint lands on the same level, right after the one you just finished, so it becomes the next one up — perfect for logging the next chapter or page while reading. Leave the box empty to just check off.
- **Long-press** opens a quick menu: Halt, Check next, Add checkpoint, Finish, Open plan, and **Turn off**.
- **Drag** it anywhere; it snaps to the nearest side and remembers its spot.
- **On by default**: turn it off from the long-press menu or under More → Home Launcher → *Floating task button*. It's drawn by the "Arcane Launcher" accessibility service, so that service needs to be on — the setting links to it.

---

# ⚡ Arcane System Upgrade // v2026.9.28 (Build #2126092801)

### 🖥️ Fullscreen Launcher
- **Home screen goes fullscreen**: the status bar and navigation bar are hidden while you're on the launcher, so the wallpaper, clock and dock use the whole screen. Swipe in from the top or bottom edge to show the bars for a moment; swiping down on the home screen still opens notifications.
- **Bars come back inside Arcane**: opening Arcane from the dock or drawer shows the system bars again, and they hide once you return home.
- **On by default, optional**: turn it off under More → Home Launcher → *Fullscreen launcher*, or from the launcher's long-press menu → Launcher settings.
- **Launcher settings sheet scrolls**: it no longer gets cut off at the bottom on small screens.

---

# ⚡ Arcane System Upgrade // v2026.9.27 (Build #2126092709)

### 📈 Realtime Trading: Smart Money Protocol
Inspired by Adam Sarhan's *Psychological Analysis* — trading is mostly psychology, and the mechanics that matter are entry, exit and risk, decided before the trade.

- **Defense first, on every buy**: set a protective stop and a risk budget (0.25–1% of your portfolio) and tap **SIZE BY RISK**; the sheet shows what you lose if stopped, the stop distance, the position size and the gain needed to recover. A strict guard refuses buys above your max risk, and a daily buy cap stops machine-gun trading.
- **Stops that actually fire**: a stop executes automatically when price hits it (logged as a STOP order, with a notification). You can raise it, move it to breakeven, or trail it — **never widen it**. At +5% the app nudges you to move to breakeven.
- **Pre-trade gate**: five checks (best idea? early, not chasing? aligned with the trend — auto-hinted from the market regime; exit defined; edge in one line), Me / Crowd / Against notes, and a mood pick. FOMO, revenge, boredom and overconfidence get called out before you tap Execute.
- **Journal**: every exit becomes a record with its R-multiple, holding period, exit reason and original plan. Review each one: did you follow the plan, process grade A/B/C, lesson learned — judge the decision, not the outcome.
- **Stats that matter**: expectancy per trade (₹ and R), average win vs average loss, profit factor, streak and drawdown, plus an equity sparkline. Win rate is shown small on purpose. In a drawdown the suggested risk steps down (1% → 0.75 → 0.5 → 0.25).
- **Risk rules** live in the trading settings; the guide sheet gains a "Smart Money Protocol" section with 8 cards.
- Existing portfolios, holdings and orders load unchanged.

---

# ⚡ Arcane System Upgrade // v2026.9.27 (Build #2126092708)

### 🧹 Code Health
- **Analyzer at zero**: 0 errors, 0 warnings (was 17 warnings: unused imports, locals, a field and a helper), and deprecation notices cut from 242 to 42 by moving every `Color.withOpacity` call to the precise `withValues(alpha:)` API. No visual change intended; this removes the precision-loss warnings and keeps the codebase ready for the next Flutter upgrade.

---

# ⚡ Arcane System Upgrade // v2026.9.27 (Build #2126092707)

### 🧭 Main Menu & Settings Refresh
- **Menu regrouped** into Daily Ops, Journal & Mind, Tools, Device & Launcher and System, with accurate one-line descriptions and the app version at the bottom.
- **Previously hidden features are now one tap away**: Nora AI (was long-press only), Skills, People & Relationships, Reflections Archive, Archived Reports, Advanced Protocols (simulators), Scheduled Reminders and a dedicated Home Launcher page (default-home + MIUI takeover + customization sheet).
- **Settings reordered** Account & Sync → Launcher → Notifications → AI → UI → Updates → Security → Diagnostics → Danger Zone.
- The 5th tab is now called **LOGBOOK** everywhere (it was INTEL on the nav bar and ANALYTICS in the header). Header no longer overflows on narrow phones. Energy-reminder text fields no longer lose what you're typing.

### 🚀 Performance
- **Autosave does half the work**: the app state was being serialized twice per save cycle (local + cloud); it's now built once and reused.
- **Home-screen widgets** are updated once per burst of changes instead of on every single provider notification.
- Projects, Finance (tracker, savings) and the session/well-being drawers now rebuild only when the data they show changes, not on every timer tick or sync flag.

### 🏠 Launcher Fixes
- Dragging an app onto the edge of a **full** dock/area no longer makes it vanish; it stays where it was if there's no room.
- A folder you just created with one app is no longer silently dissolved on the next refresh; only folders that actually lost an app (uninstall) dissolve.
- Pinned web-app/shortcut icons refresh when their app updates. Fixed two leaked text controllers in the launcher sheets.

---

# ⚡ Arcane System Upgrade // v2026.9.27 (Build #2126092706)

### 📋 Briefing Refresh (Start Day + Tactical Briefing)
- **No more crashes on old reports**: every field the AI returns is now parsed defensively, so an older or malformed saved Start Day report or Tactical Briefing renders with fallbacks instead of taking the whole card down.
- **Goals at risk**: weekly and monthly goals that are trailing the pace needed to finish on time get a red `AT RISK · Nd LEFT` badge, and the AI is told about them so the day's highlight, obstacle plan and directives target them first.
- **Contingency for tomorrow**: the end-of-day briefing now ends with one likely obstacle and an if-then plan, matching what Start Day already had.
- **Less filler, more specifics**: prompts now demand plain second-person prose (no markdown inside the briefing), fewer gratitude items, shorter summaries, and finance feedback only when money actually moved. Recommended tasks show their *why*.
- **Small fixes**: long names no longer overflow on narrow phones; the finance panel hides when the day had no income or expense; switching the inspected date clears a stale generation error.

### 🛡️ Stability
- Fixed 8 `BuildContext`-after-async crash risks (archived reports, task details, edit-log dialog, data recovery, database editor) and a batch of analyzer nits.

---

# ⚡ Arcane System Upgrade // v2026.9.27 (Build #2126092705)

### 🛠️ Build Fix
- **Fixed the Android release build**: build #2126092704 failed in `compileReleaseKotlin` with `Unresolved reference: getDefaultApps` (`LauncherBridge.kt:261`). The launcher rewrite kept the method-channel handler but dropped the function it calls. This restores the default-app lookup (dialer, SMS, browser, camera, email) used to build the initial dock, so #2126092704's launcher, update and Arcane Deck changes actually ship.

---

# ⚡ Arcane System Upgrade // v2026.9.27 (Build #2126092704)

### ⚡ Instant Launcher Takeover (MIUI / HyperOS)
- **No stock launcher flash**: the takeover now starts Arcane with a zero-duration transition, skips window animations, and lands directly on the home page in the first frame (no slide or pager animation). The window backdrop matches the launcher colors, so nothing flashes while Flutter draws.
- **Faster detection**: the accessibility service only listens to the stock launcher's windows, and the debounce dropped from 700 ms to 350 ms.

### 📲 In-App Updates Fixed
- **Root cause**: every build from the same day shared one APK URL, and the update metadata was committed before CI finished building. The app could download the previous APK (from the CDN or its own cache), which Android then refused to install, or the update prompt kept coming back.
- **Unique per-build APKs** (`missions-v<version>-b<build>-<abi>.apk`), cache-busted downloads, and the device's ABI-specific APK picked automatically.
- **Update is only announced once its APK actually exists.** The downloaded APK's version code is verified before installing, and a stale cached APK is re-downloaded.
- **Clear install guidance**: if "Install unknown apps" isn't allowed, Arcane opens that setting and tells you what to do, instead of failing silently.
- CI now rebases before pushing its build commit (no lost build metadata) and publishes only the current build's APKs.

### 🗂️ Launcher: Every App, Folders, Drag & Drop
- **All apps, from every profile**: MIUI Dual Apps / Second Space and work-profile apps now appear, with the system badge.
- **Chrome web apps**: installed web apps (WebAPKs) appear as apps. Pinned web-app shortcuts are read and launched when Arcane is the default home app, and Chrome's "Install app" / "Add to Home screen" now pins straight onto Arcane's home. **Add web app** lets you add any site as an icon (it opens the installed web app if there is one).
- **Folders everywhere**: drop an app onto another app (home, dock or quick apps) to make a folder, or use **Add to folder…** (home or drawer folders). You can rename, add, move out, remove or delete. Folders work in the dock too.
- **Drag & drop**: long-press any app in the drawer and drag it. The drawer drops away to reveal home, where you can place it on the home grid, onto the dock, or into a folder. Hover the screen edge to flip to the widgets page and drop it in Quick Apps. Dragging from home or the dock shows a **Remove** zone, and dropping at an icon's edge reorders.
- **App shortcuts** in the long-press menu (as the default home app), plus "Add to home screen" and "Remove shortcut / web app" actions.

### 🎛️ Arcane Deck (Widget Space Redesign)
- **Daily Pulse**: a time-aware greeting and a dual ring (day elapsed plus live mission progress), with time left today and the next mission.
- **Command row**: one-tap Focus/Pause, Journal, Expense, Nora and Bus, through the same router as the Android home widgets.
- **Quick Apps shelf**: drag apps here for one-tap access next to your live Arcane widgets.

---

# ⚡ Arcane System Upgrade // v2026.9.27 (Build #2126092703)

### 🛠️ Build Fix
- **Fixed the Android release build**: a Kotlin parsing error in the launcher's MIUI detection (`as? String` followed by a line starting with `!`) was read as the type `String!` and stopped `compileReleaseKotlin`. This build ships the launcher rebuild and the MIUI/HyperOS takeover mode from builds #2126092701 and #2126092702.

---

# ⚡ Arcane System Upgrade // v2026.9.27 (Build #2126092702)

### 🏠 MIUI / HyperOS Launcher Takeover
- **"Open Arcane over default launcher" mode**: for phones that force their stock home app (MIUI / HyperOS). When it's on, Arcane opens on top every time the stock home screen comes up (HOME button, closing an app, unlocking), so it works just like being the default home app.
- **One switch in Settings → Home Launcher** (also in the launcher's own settings sheet), with a guided setup: turn on the "Arcane Launcher" accessibility service, plus MIUI **Autostart** and **"Display pop-up windows while running in background"** shortcuts, each with a live status check.
- **Privacy-minimal service**: it only listens for window-state changes (which app came to the front). It never reads screen content or typing. The stock launcher's recents and pop-ups are ignored, and repeat triggers are debounced.
- **Home-screen back behavior**: with takeover active, Back on Arcane's home screen does nothing (like a real home app) instead of exiting.

---

# ⚡ Arcane System Upgrade // v2026.9.27 (Build #2126092701)

### 🏠 Launcher Rebuilt as a Real Android Home App
- **New Pixel-style flow**: one home surface. **Swipe up** for the app drawer (search on top), **swipe down** for the real notification shade, **swipe right** for the Arcane widgets page. Arcane itself slides over the launcher from its dock/drawer icon and stays alive underneath, and the **HOME button always returns** to the home page (closing Arcane, the drawer and any open screens).
- **No fake system chrome**: removed the drawn status bar, gesture pill and "Launching…" toasts. The launcher is edge-to-edge under the real Android status and navigation bars.
- **Real app icons everywhere**: every app shows its own original icon (rendered natively, batched and disk-cached for instant boots), with a glyph only while an icon is still loading.
- **Customizable dock**: up to 6 slots, defaulting to your system phone, messages, Arcane, browser and camera apps. Long-press a dock icon to replace the app or change its icon; long-press the dock to reorder, add or remove slots.
- **Custom icons + icon packs**: pick any app's original icon (including its own), any drawable from an installed ADW/Nova-compatible icon pack, or a tactical glyph, per app. You can also apply an icon pack globally with automatic per-app matching from its `appfilter.xml`.
- **Real Android widgets**: add any installed app widget to the home screen with the full bind-permission and configure flow, then resize, reorder, reconfigure or remove it. Arcane now also accepts `requestPinAppWidget` as the default launcher, so "Pin to home" buttons (including Arcane's own) place widgets directly.
- **App drawer**: suggested apps (frecency), fast search with web-search fallback, and long-press actions: add to dock, change icon, hide, app info and uninstall. It refreshes live when apps are installed, updated or removed.
- **Arcane widgets page**: the fake Wi-Fi/Bluetooth/airplane/GPS/torch toggles now show real device state. The torch toggles for real, and the others open the matching system panels. The fake "widget library" was replaced with real Android widget placement.

### 🔐 Home-App Correctness
- **Back works again inside Arcane**: removed the native back override that swallowed every back press, so in-app screens pop normally while the home screen itself never exits.
- **Launcher no longer shows over the lock screen**: only assistant and voice intents may appear over the keyguard now. It used to be a static manifest flag on the home activity.
- Manifest: pin-widget intent filter, `EXPAND_STATUS_BAR`, `REQUEST_DELETE_PACKAGES`.

### 🚀 Performance Audit
- **App shell no longer rebuilds on every state change**: `MaterialApp` and `HomeScreen` now select only the fields they render (theme mode, task color, auth/tour state, active project) instead of watching all of `AppProvider`.
- **Market engine pauses in the background**: the 1s micro-tick and 4s quote polls stop while Arcane isn't visible, which matters now that the launcher process is always alive.
- **Launcher rendering**: minute-aligned home clock (no per-second rebuilds), per-second widget-page clock isolated to its text, provider-scoped status chip, launcher surface fully offstage (no layout, paint or tickers) while Arcane is open, and debounced notes and launch-stat writes.

---

# ⚡ Arcane System Upgrade // v2026.9.24 (Build #2126092405)

### 🔄 Universal Cloud & Realtime Database Synchronization Engine
- **End-to-End Realtime Database (RTDB) & Firestore Paper Trading Sync**: Added direct persistence and synchronization for paper trading portfolio data (`users/$userId/data/trading`), including virtual cash balance, exchange rates, asset holdings, filled/pending orders, trailing peak prices, and triggered alerts across both mobile (FlutterFire) and desktop (Linux) platforms.
- **Automated Debounced Cloud Database Sync**: Eliminated the requirement to manually navigate to settings and tap "Force Cloud Sync". When `autoSaveEnabled` is active, any modification across any feature state (tasks, day planner, habits, reflections, finance, health, settings, and trading) automatically schedules a debounced (2.5s) sync to the cloud database.
- **Two-Way Startup & Login Synchronization**: Connected `autoSyncWithCloud()` to auth state changes and app launches, comparing local and remote `lastModified` timestamps to download fresh cloud changes or push newer local edits.
- **Lifecycle Flush Protection**: App lifecycle state changes (`paused`, `inactive`, backgrounding) immediately flush any pending debounced changes to both local disaster-proof storage and remote cloud database, safeguarding against data loss.
- **Unified Global Provider Integration**: Registered `PaperTradingProvider.instance` in root `MultiProvider` and wired its state notifications to `AppProvider` to seamlessly include trading data in `getFullAppState()` snapshots and restore them in `loadStateFromMap()`.

---

# ⚡ Arcane System Upgrade // v2026.9.24 (Build #2126092404)

### 🛡️ App State Preservation & Anti-Reset Architecture
- **Eliminated Destructive Activity Lifecycle**: Removed destructive `finish()` calls on `MainActivity` during assistant and voice intent handling. Arcane now preserves running state, journal entries, active timers, and in-memory caches undisturbed in the background when redirecting to external or native voice assistants.
- **SingleTask Launch Architecture & Task Affinity Unification**: Configured `MainActivity` with `android:launchMode="singleTask"` and unified application task affinity. Incoming Bluetooth voice triggers (`ACTION_VOICE_COMMAND`, `ACTION_ASSIST`, `ACTION_VOICE_ASSIST`) seamlessly route to the existing task's `onNewIntent` without spawning duplicate engine instances or restarting Flutter.
- **Disaster-Proof Atomic Local Storage**: Hardened `LocalStorageService` with atomic file transactions (`.tmp` write followed by atomic filesystem rename), automated `.bak` backup rotation on every save, and intelligent corrupt-JSON recovery to ensure 2+ years of journal data and missions remain safe against unexpected OS process terminations.

### 🎙️ Bulletproof Instant Mic Auto-Start Engine
- **Automated Runtime Permission Orchestration**: Added native `RECORD_AUDIO` and `BLUETOOTH_CONNECT` runtime permission negotiation in `MainActivity.kt` and `SttService`. Speech recognition automatically prompts for permissions if missing and immediately engages listening upon grant without requiring extra user taps.
- **Race-Condition-Proof Initial Greeting**: Resolved TTS initialization race condition in `NoraAiScreen` where delayed TTS engine initialization prevented auto-listening. Implemented safety timeout fallbacks and instant listening activation.
- **One-Tap Waveform Orb Reactivation**: Enhanced the audio-reactive Live Link orb with gesture detection, allowing operators to instantly tap the orb at any time to re-engage speech recognition if paused or completed.
- **Universal External Voice Mode Engagement**: Enhanced external assistant dispatch (ChatGPT, Google Assistant / Gemini, Claude, etc.) with verified voice intent extras (`open_voice`, `voice_mode`, `start_voice`) without clearing caller tasks.

---

# ⚡ Arcane System Upgrade // v2026.9.24 (Build #2126092403)

### 🎯 Custom Assistant Application & Activity Picker Screen
- **Dedicated Installed App & Activity Browser**: Introduced a high-speed, dual-step picker screen (`CustomAssistantPickerScreen`) allowing operators to explore all applications physically installed on the host device and select exact declared Activities as custom Bluetooth voice command targets.
- **Real-Time App & Activity Search**: Instantaneous live search filtering across 200+ installed packages by application label or package name, alongside secondary activity search inside the selected application.
- **Smart Category Filtering**: Quick filter chips to toggle between `ALL APPS`, `USER APPS` (non-system user-installed packages), and `ASSISTANTS / AI` (apps declaring voice/assistant intents).
- **Deep Activity Inspection & Voice Badging**: Scans and parses `PackageManager` declared activities for the selected app, highlighting voice/assist components with cyan `[VOICE]` tags and public entrypoints with green `[EXPORTED]` badges.
- **Default Auto-Voice Option**: Allows choosing either a specific declared Activity component or using "Default Launch & Voice Auto-Detect" to let Arcane automatically trigger voice mode with voice extras.
- **Instant Test Launch & Preview Bar**: Bottom HUD card with live target preview, confirmed target saving to `SharedPreferences`, and an immediate `[TEST LAUNCH]` rocket trigger to verify target execution with Bluetooth audio routing.
- **Dual-Theme Tactical Compliance**: 100% compliant with `JweTheme` dynamic tokens (warm tactical paper in light mode, midnight tactical HUD in dark mode).

---

# ⚡ Arcane System Upgrade // v2026.9.24 (Build #2126092402)

### 🎙️ Hands-Free Voice Assistant Auto-Listening & Continuous Conversational Loop
- **Instant Hands-Free Microphone Activation**: Opening Nora via Bluetooth headset button (`ACTION_VOICE_COMMAND`), lock screen assist, or live comms button automatically routes audio to Bluetooth and starts microphone listening immediately without requiring manual screen taps.
- **Continuous Conversational Loop**: Nora's voice engine seamlessly chains conversational turns: listens to user speech $\rightarrow$ generates AI response $\rightarrow$ synthesizes voice response via native Text-to-Speech $\rightarrow$ automatically resumes microphone listening for continuous hands-free dialogue.
- **Dynamic Speech Recognition Engine (STT)**: Added high-performance native Android SpeechRecognizer bridge via `arcane/stt` MethodChannel with real-time speech transcription, error-recovery callbacks, and audio-reactive decibel RMS level tracking.
- **Interactive Audio-Reactive Live HUD**: Redesigned Nora Live Link overlay with responsive glowing wave orb dynamically scaling on voice RMS volume, real-time transcription cards, dual-theme adaptation (`JweTheme.isLight`), and one-touch mute/hangup controls.

### 🎧 Universal Bluetooth Audio Routing for All Platforms
- **Hardware-Level Bluetooth Routing**: Native communication device configuration routes all voice output (TTS synthesis) and audio input (microphone STT) to connected Bluetooth headsets, SCO ear-pieces, BLE audio, and hearing aids by default before falling back to device hardware.
- **External Assistant Voice Mode Launch**: When redirecting to external assistants (e.g. ChatGPT, Gemini, Claude, Perplexity, Copilot, or custom assistants), Arcane routes audio to Bluetooth and triggers dedicated voice listening activities (`VoiceActivity` with `ASSIST_INPUT_HINT_KEYBOARD = false` and `open_voice = true`) to engage hands-free voice mode directly.

### 🔍 Dynamic Installed Assistant Discovery & Package Manifest Filter
- **Dynamic Installed Apps Query**: Settings assistant redirector dynamically filters and displays only apps physically installed on the user's device that declare voice/assistant capabilities (`ACTION_ASSIST`, `VOICE_ASSIST`, `VOICE_COMMAND`, `VOICE_SEARCH_HANDS_FREE`, `ACTION_WEB_SEARCH`, and `VoiceInteractionService`).
- **Discovery Counter & Manual Refresh**: Displays live installed assistant count (e.g., `1 installed assistant app(s) discovered`) with a one-tap refresh button, System Default Assistant fallback, and custom Android package name override.

---

# ⚡ Arcane System Upgrade // v2026.9.24 (Build #2126092401)

### 🎧 Bluetooth AI Assistant & Lock Screen Voice Launch
- **Bluetooth Headset Voice Activation**: Added native support for Bluetooth device assistant buttons and voice triggers (`android.intent.action.VOICE_COMMAND`, `android.intent.action.ASSIST`, and `android.intent.action.VOICE_ASSIST`) via dedicated `BluetoothAssistantActivity` alias.
- **Lock Screen Wake & Keyguard Bypass**: Configured `showWhenLocked`, `turnScreenOn`, and native Keyguard dismiss routines so voice queries and Nora assistant sessions can be engaged directly over the Android lock screen without manual device unlocking.
- **Dedicated Permissions**: Declared `BLUETOOTH`, `BLUETOOTH_CONNECT`, `WAKE_LOCK`, and `DISABLE_KEYGUARD` for reliable headset communication and device wakeups.

### 🔀 Third-Party Assistant Redirector & Bridge
- **Universal Assistant Bridge**: Many third-party AI assistants support standard assist intents but omit Bluetooth voice command manifest filters. Arcane now acts as a bridge, capturing the Bluetooth headset button and redirecting directly to the user's preferred assistant app.
- **Configurable Redirect Targets**: Easily route Bluetooth triggers in **Advanced AI Settings** to:
  - Nora (Arcane Tactical Assistant)
  - ChatGPT (`com.openai.chatgpt`)
  - Google Gemini (`com.google.android.apps.bard` / Google Assistant)
  - Anthropic Claude (`com.anthropic.claude`)
  - Perplexity AI (`ai.perplexity.app`)
  - Microsoft Copilot (`com.microsoft.copilot`)
  - System Default Assistant
  - Custom Android Package Name

### 🧠 Gemini Live API Upgrades & Latest Model Suite
- **Next-Gen Gemini Models**: Updated model registry with `gemini-2.0-flash-exp`, `gemini-2.0-flash`, `gemini-2.0-flash-realtime-exp`, and `gemini-2.5-pro` across Live, Lite, and Heavy tiers.
- **Multi-Key Secret Pool Rotation**: Live WebSocket queries now rotate across all user-configured Gemini API keys in `SecretsService` alongside primary settings keys.
- **Zero-Hang Error Frame Handling**: The Live WebSocket listener immediately intercepts and parses API error JSON frames, triggering instant failover instead of hanging on socket timeouts.

### 🗣️ Native Text-to-Speech (TTS) & Resilient Fallback Engine
- **Native Android TTS Bridge**: Implemented high-performance native Android Text-To-Speech engine via `arcane/tts` MethodChannel and singleton `TtsService` with automatic Markdown stripping and speech sanitization.
- **Resilient Voice Fallback**: If Gemini Live API encounters network drops, quota exhaustion, or WebSocket handshake failures, Nora seamlessly falls back to standard `generateContent` and synthesizes responses out loud with TTS.
- **Hands-Free Voice Mode**: Added auto-speak TTS toggle in Advanced AI Settings, initial voice greeting, and real-time audio controls with dual-theme HUD indicators.

### 📊 Multi-Timeframe Trend Alert Dialog (1H, 24H, 7D, 30D)
- **Long-Click Multi-Timeframe Telemetry Alert**: Long-pressing or tapping the 1H AVG badge in the trading header or holding cards opens an alert dialog displaying market trajectory across 4 distinct time horizons:
  - **1H**: Hourly Momentum ($\pm\%$)
  - **24H**: Daily Trend ($\pm\%$)
  - **7D**: Weekly Direction ($\pm\%$)
  - **30D**: Monthly Macro Cycle ($\pm\%$)
- **Macro Market Regime Classification**: Computes aggregate market regime telemetry (`STRONG BULL EXPANSION`, `CORRECTIVE RETRACEMENT`, `BEAR CONTAGION`, `SIDEWAYS COMPRESSION`).
- **Tactical Dual-Theme HUD**: Styled with calibrated cyber accents, high-contrast badges, and adaptive palette conforming to `JweTheme` in both Dark and Light modes.

---

# ⚡ Arcane System Upgrade // v2026.9.22 (Build #2126092201)

### 🛡️ Mandatory Real-Time Feed Guard & Guaranteed Holdings Pinning
- **Strict Real-Time Buy Gatekeeper**: Prevents buying any stock or cryptocurrency unless an active, verified real-time price feed is established (`isRealtimeActive`). Market and limit buy orders are blocked if the asset ticker is offline or unverified.
- **Hardware-Lock Buy Button UI**: The order sheet buy button instantly renders a disabled, high-contrast `BUY LOCKED (FEED OFFLINE)` state with lock icon and amber warning banner whenever an asset feed is offline.
- **Guaranteed Real-Time Pinned Holdings**: Every owned asset in the user's portfolio is automatically and permanently pinned for continuous real-time market updates (Binance WebSocket subscriptions for crypto, parallel Yahoo quotes with 1,000ms micro-spread pulse for Indian equities and indices).
- **Auto Lifecycle Subscriptions**: Purchasing an asset automatically registers it to the pinned subscription list; liquidating the asset safely unpins it without disturbing other active feeds.

### 🔔 Trailing Peak Reversal Alerts & Loss Notifications
- **High-Water Peak Price Telemetry**: Each open holding tracks its historical high-water peak price (`peakPrice`) and flags when a position moves into net profit (`hasReachedHigher`).
- **Immediate Trailing Loss Notifications**: When an asset retraces from a higher peak and crosses below the purchase price into a loss (`isLosingMoneyAfterHigher`), an urgent system alert is dispatched via `NotificationService` (`REVERSAL ALERT // CAPITAL AT RISK`).
- **Dedicated High-Priority Alert Channel**: Alerts arrive via a dedicated `trading_alerts` notification channel configured with high importance and high-visibility alert LEDs.
- **Anti-Spam Latch Architecture**: Notifications trigger once upon breach and latch until the asset recovers back into profit or is liquidated, preventing ticker spamming.
- **In-App HUD Reversal Warnings**: Holding cards dynamically display high-contrast danger badges with exact drawdown from peak when a position enters drawdown after reaching higher highs.

### 📊 Dashboard Hourly Change & Aggregate Market Trend
- **Hourly Trend Telemetry**: The trading dashboard header now displays a real-time 1-hour aggregate market trend badge (`1H AVG: ±X.XX% · GOING UP / GOING DOWN / SIDEWAYS`).
- **Dynamic 1H Metric Calculations**: Continuously computes average 1H return across active holdings and watchlist assets using Binance 1h kline opens and Yahoo 5m reference intervals.
- **Per-Asset 1H Indicators**: Watchlist asset tiles and portfolio holding cards now feature dedicated 1H delta indicators alongside standard 24H performance.

---

# ⚡ Arcane System Upgrade // v2026.9.18 (Build #2126091802)

### ⚡ Real-Time Dynamic List & Viewport Ticks
- **Real-Time Viewport Engine**: Guaranteed live price updates, 24h % delta fluctuations, and rolling sparklines for every asset visible on screen across all market categories (`NSE STOCKS`, `INDICES`, `CRYPTO`, `COMMODITIES`).
- **All-Items Real-Time Update for Compact Lists**: For lists with $\le 25$ assets (such as curated Indian equities, indices, commodities, and search results), all items in that specific list are automatically registered and updated in real time.
- **Dynamic Binance WebSocket Subscriptions**: Dynamically registers runtime subscriptions (`@ticker`) over the active WebSocket channel as new crypto pairs scroll into view, supporting all 700+ pairs on the fly without socket reconnection.
- **Micro-Tick Pulse Engine for Indian Equities**: Injects 1,000ms micro-spread ticks ($\approx 1.5$ bps) alongside fast parallel Yahoo Finance quote refreshes (4-second interval) so Indian bluechips and indices exhibit authentic live exchange action.
- **Portfolio & Active Screen Pinning**: Permanently pins open asset detail views and all user portfolio holdings to ensure uninterrupted live valuation.

### 🛠️ GitHub Actions Workflow Fix
- **Workflow YAML Syntax Resolution**: Corrected block scalar indentation in `.github/workflows/android-release.yml` for the release metadata generator heredoc, resolving GitHub Actions pipeline parsing errors.

---

# ⚡ Arcane System Upgrade // v2026.9.18 (Build #2126091801)

### 📈 Multi-Timeframe Shadow Graphs & Comparative Historical Overlay
- **Interactive Shadow Comparison Curves**: Introduced toggleable shadow reference curves plotted directly behind the primary price line in `fl_chart`, enabling immediate visual comparison of active market trends against past cycles.
- **4 Contextual Shadow Modes Across All Timeframes (`1D`, `1W`, `1M`, `1Y`, `ALL`)**:
  1. *Previous Period*: Yesterday on 1D, Last Week on 1W, Last Month on 1M, Last Year on 1Y.
  2. *Last Week Day*: Exact same weekday from 7 days ago (`LAST WEEK DAY`, `PRIOR 7D CYCLE`).
  3. *Last Month Day*: Exact same calendar date from 30 days ago (`LAST MONTH DAY`, `PRIOR MONTH`).
  4. *1 Year Ago*: Exact same date and historical trajectory from 365 days ago (`1 YEAR AGO`, `PRIOR YEAR`).
- **Financial Rebased Indexing ($P_{\text{overlay}}$)**: Employs standard financial normalization ($P_{\text{overlay}}(i) = P_{\text{start}} \times (1 + \Delta P_{\text{shadow}} / P_{\text{shadowStart}})$), seamlessly aligning both trajectories onto a shared visual scale without distorting the primary Y-axis.
- **Comparative Touch Crosshairs & Legend Telemetry**: Dragging across the chart reveals both the live quote and the shadow curve's comparative percentage delta, with high-contrast amber badges in the chart HUD.
- **High-Resilience Dual Data Engine**: Backed by real Binance Kline API queries for crypto pairs and Yahoo Finance multi-session charts for Indian equities (NSE/BSE), benchmark indices, and commodities, with resilient fallback synthesis.
- **Dual-Theme Tactical Parity**: Styled with theme-calibrated amber dashed strokes (`[5, 4]`), high-contrast badges, and adaptive tooltips respecting both dark and light modes (`JweTheme`).

---

# ⚡ Arcane System Upgrade // v2026.9.16 (Build #2126091605)

### 🚀 Auto-Updater Sync & Downgrade Bug Elimination
- **Eliminated False Downgrade Prompts**: Resolved a critical logic error where `forceCheck` permitted older remote builds to be recognized as available updates (`remoteCode != localCode`), which caused installed builds to be erroneously prompted to downgrade to older releases. An update is now strictly offered only when the remote version code or semantic version string is strictly newer.
- **Synchronized Release Metadata**: Updated `builds/update_info.json` and `builds/latest.json` to reflect current `2026.9.16` APK artifacts and active build number `#2126091605`, ensuring in-app updater immediately serves the latest v2026.9.16 builds rather than stale v2026.9.15 metadata.
- **Automated Workflow Metadata Generation**: Enhanced `.github/workflows/android-release.yml` to automatically generate and commit `builds/update_info.json`, `builds/latest.json`, and `builds/latest.md` alongside release APKs on every release build, permanently preventing metadata desynchronization.
- **Synchronized Changelog Pipeline**: Fully synchronized `latest.md` and `builds/latest.md` so that the in-app "What's New" and build notes dialogs accurately reflect all current upgrades.

---

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


