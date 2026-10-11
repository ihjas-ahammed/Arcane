# Arcane: Floating HUD (Floating Timer) Audit

**Date:** 2026-10-11
**Branch / version scanned:** `revive2` @ `521a4c1` (v2026.10.11+2126101102)
**Reported symptoms:**
1. The floating timer **hides and shows like a glitch**.
2. It **never settles** into low transparency after a few idle seconds, so it always sits at full brightness over other apps.

**Scope:** every piece that drives the floating timer:

| Layer | File |
|---|---|
| Android floating button | `android/.../TaskBubbleOverlay.kt` |
| Host (accessibility service) | `android/.../LauncherTakeoverService.kt` |
| Keep-alive notification | `android/.../TaskForegroundService.kt` |
| Action bridge | `android/.../widgets/WidgetActionReceiver.kt`, `MainActivity.dispatchWidgetAction` |
| Dart feed (what the bubble reads) | `lib/src/services/home_widget_publisher.dart`, `lib/src/services/home_widget_service.dart` |
| Dart actions (what a bubble tap does) | `lib/src/services/widget_action_router.dart`, `lib/src/providers/actions/timer_actions.dart` |
| Other writers of the same keys | `lib/src/screens/settings/widgets_studio/widgets_studio_sync.dart` |
| Desktop "Focus Clock" | `lib/src/widgets/ui/desktop_floating_timer.dart`, `lib/src/screens/home_screen.dart` |

The old Data Hazard audit that was in this file is still in git history (`git show 521a4c1:report.md`). Its implementation notes are in `docs/data-hazard-implementation.md`.

---

## 0. TL;DR

| # | Severity | Problem | Where |
|---|---|---|---|
| **A1** | 🔴 Root cause | `IDLE_ALPHA = 1f`. The "dim when idle" animation runs, but it animates to 100% opacity, so it can never get transparent | `TaskBubbleOverlay.kt:77` (changed in `bc56dd8`) |
| **A2** | 🔴 | Once the checkpoint dialog opens (double-tap or ADD +), the idle timer is never re-armed. The bubble stays awake until you touch it again | `TaskBubbleOverlay.kt:390-391, 817-825, 1112` |
| **A3** | 🟠 | Every hide→show rebuild starts the bubble awake and un-docked, so each glitch from section B also "pops it out" again | `TaskBubbleOverlay.kt:290-323` |
| **B1** | 🔴 Root cause | By design, the bubble **is deleted whenever the timer isn't running**. A single tap = HALT = the bubble vanishes, and ENGAGE from the notification brings it back | `TaskBubbleOverlay.kt:190-217` (`bc56dd8`) |
| **B2** | 🔴 Root cause | The Dart side writes ~30 keys **one at a time**, and the bubble re-syncs 60 ms after *any* key changes, so it reads half-written state | `home_widget_service.dart:280-288`, `TaskBubbleOverlay.kt:129-134` |
| **B3** | 🔴 Root cause | Up to 4 publishers write the same keys **concurrently** with no lock. An older snapshot can overwrite a newer `isRunning`, so the bubble shows after HALT or hides while running, until the next 30 s heartbeat | `home_widget_publisher.dart:30-36, 43, 67-74, 86`; `widget_action_router.dart:316, 328` |
| **B4** | 🟠 | Widgets Studio "sync" pushes *preview* data into the live keys (no `sessionStartMs`, editor `isRunning`), which hides the bubble or freezes the clock | `widgets_studio_sync.dart:55-71, 173-184` |
| **B5** | 🟠 | Bubble taps are queued while Arcane is loading, syncing or in a load error. The tap seems to do nothing, then gets replayed minutes later, so the bubble suddenly vanishes or appears | `widget_action_router.dart:111-115` |
| **B6** | 🟠 | The "window dropped" self-heal does `hide(); show()` and rebuilds the bubble awake | `TaskBubbleOverlay.kt:196-200` |
| **B7** | 🟡 | `onServiceConnected` can run twice without `onUnbind`, which leaves two bubbles and two heartbeats fighting each other | `LauncherTakeoverService.kt:297-305` |
| **B8** | 🟡 | Drag-to-hide: the "hidden until next task" flag clears itself at once, and a "Continue" notification appears right after you dismissed it | `TaskBubbleOverlay.kt:182-188, 651-659` |
| C1-C8 | 🟡/🔵 | Foreground service restarted on every sync, two "running" notifications, docked tab cuts off the time readout, rotation mid-animation, battery wakeups, and more | §4 |
| D1-D6 | 🟠/🟡 | Desktop Focus Clock: disappears when the window crosses the rail breakpoint, loses its position, has no idle fade, can be dragged off-screen, and is not a real always-on-top window | §5 |
| ✅ | Fixed now | `PRAGMA journal_mode=WAL` via `execute()` crashes Android sqflite with "The local database could not be read" | §6 |

**Recommended order:** A1 + A2 (≈30 min, fixes "never settles") → B1 decision → B2 + B3 (fixes most of the flicker) → B5 → A3 + B6 + B7 → B4, B8 → C → D.

---

## 1. How the floating timer is fed today

```
AppProvider ──notify──► HomeWidgetPublisher
                          ├─ debounced 400 ms ─────────► _publishTask()
                          ├─ Timer.periodic 30 s (force) ► _publishTask(force)      ← heartbeat
                          └─ republishNow() (after bubble HALT/ENGAGE) ► publishAll()
WidgetsStudioSync.pushTask/pushAll ────────────────────► publishTask(preview data)
                                │
                                ▼
        HomeWidgetService.publishTask → _setAll(): for each of ~30 keys:
               await HomeWidget.saveWidgetData(key, value)   ← one platform call + prefs apply EACH
                                │  (each changed key fires OnSharedPreferenceChangeListener)
                                ▼
   TaskBubbleOverlay.widgetListener: any "arcane.task.*" → postDelayed(syncRunnable, 60 ms)
   TaskBubbleOverlay.heartbeat 20 s ─────────────────────► syncRunnable
                                │
                                ▼
   syncRunnable: running ? show() + refreshState() + TaskForegroundService.start()
                         : hide() + TaskForegroundService.stop() + maybe "Continue" notification

   Bubble tap ─► WidgetActionReceiver ─► MainActivity.dispatchWidgetAction ─► Flutter router
            (queued in _pending if the app is loading / errored / attaching cloud)
```

Every flicker in section B comes from one of these: the bubble is **removed** whenever `isRunning` reads false (B1), `isRunning` can read false **for a moment** (B2, B3, B4), or it is rebuilt by self-heal code (B6, B7).

---

## 2. Symptom A: it never settles into low transparency

### A1. 🔴 `IDLE_ALPHA` is `1f`, so the dim is a no-op
**Where:** `TaskBubbleOverlay.kt:77`
```kotlin
private const val IDLE_ALPHA = 1f // stays opaque so wallpaper lines never show through it
```
History: `0.55f` (`ccbb3ed`) → `0.38f` (`ba8712b`) → **`1f`** (`bc56dd8`). The class doc (lines 59-61) still promises "dims to 38% opacity". `settleToSide()` still docks it (it tucks 38% into the edge), but `b.alpha` animates from 1 to 1, so to the eye it "never settles."

**Why it was set to 1:** `View.alpha` fades the *whole* view, including the dark disc fill. At 38% you could see wallpaper lines and text through the disc, which looked broken.

**Solutions (pick 1; option 1 is recommended):**
1. **Dim the contents, keep the body opaque (recommended).** Leave `View.alpha` at 1. Add a `dim` value (0 to 1) to `BubbleView` that `settleToSide()` and `wake()` animate, and use it in `onDraw` to fade only the glow, arc, reticle, glyph and text. The disc stays solid, so nothing shows through, but it still clearly "goes quiet":
   ```kotlin
   // BubbleView
   var dim = 0f; set(v) { field = v; invalidate() }
   private fun fade(c: Int, minA: Float = 0.35f): Int {
       val a = (Color.alpha(c) * (1f - (1f - minA) * dim)).roundToInt()
       return (c and 0x00FFFFFF) or (a shl 24)
   }
   // in onDraw: glowPaint.color = fade(accent and 0x24FFFFFF, 0f); arcPaint.color = fade(accent)
   //            glyphPaint.color = fade(...); timePaint.color = fade(...)
   // settleToSide(): animate b.dim 0→1 ; wake(): animate b.dim →0
   ```
   You can also darken the fill slightly when docked (for example `0xFF04070D` solid) so the tab reads as "parked."
2. **Bring back real transparency, but draw an opaque backing.** Set `IDLE_ALPHA = 0.45f` and change the fill gradient to fully opaque colours (the `LinearGradient` colours are already `0xFF…`, but the glow halo and anti-aliased rim are not). This is the cheapest fix, but you will still see some bleed-through at the rim.
3. **Make it a setting.** Add an "Idle opacity" slider (30-100%, default 45%) and an "Idle delay" slider (1.5-10 s) to `launcher_task_bubble_settings.dart`. Store them in the `arcane_launcher` prefs (`task_bubble_idle_alpha`, `task_bubble_idle_ms`) and read them in `settleToSide()`. That way you won't need to change the code again the next time the opacity bothers you.

### A2. 🔴 The idle timer dies after the checkpoint dialog or a blocked settle
**Where:** `settleToSide()` `TaskBubbleOverlay.kt:390-391`, `dismissDialog()` `:817-825`, `ACTION_UP` `:1112`.

**Scenario (double-tap):**
1. `ACTION_UP` → `showCheckpointDialog()`, then `if (radialMenu == null) scheduleIdle()` arms the 2.5 s timer.
2. 2.5 s later `settleToSide()` sees `dialog != null` and **returns without rescheduling**.
3. You close the dialog. `dismissDialog()` **does not call `scheduleIdle()`**.
4. The bubble now stays awake and full-size until you touch it again.

The same thing happens with radial menu → ADD + (`dismissRadialMenu()` arms idle, then the dialog blocks it), and whenever the idle timer fires while the drag-to-hide target is still fading out.

**Solutions:**
- In `settleToSide()`, when it's blocked, **reschedule instead of giving up**:
  ```kotlin
  if (radialMenu != null || dismissTarget != null || dialog != null) { scheduleIdle(); return }
  if (bubble == null) return
  ```
- Call `scheduleIdle()` at the end of `dismissDialog()`.
- Simplest invariant: every path that ends an interaction (`dismissDialog`, `dismissRadialMenu`, `ACTION_UP`, `ACTION_CANCEL`, `snapToEdge` end) calls `scheduleIdle()`, and `settleToSide()` never drops the timer.

### A3. 🟠 Every rebuild comes back awake and pops out of the edge
**Where:** `hide()` sets `isDocked = false` (`:322`). `show()` then places it with `placeFromPrefs()` (un-docked x) and full alpha (`:300-308`).

Because of B1-B7 the bubble is rebuilt often, and each rebuild shows it full-size at the normal position for 2.5 s, then animates it back to the edge. That looks like "it jumped out at me again."

**Solutions:**
- Keep a `lastDocked` flag that survives `hide()`. In `show()`, if the previous instance was docked and the rebuild wasn't caused by a touch, place it straight at `dockedX()` with `dim = 1` (or `IDLE_ALPHA`) and skip the wake.
- Better still, fix B1/B2/B3/B6 so rebuilds become rare. Then A3 hardly matters.

### A4. 🔵 The docked tab cuts off the time readout
`tuckPx = size * 0.38` (`:107`) hides 38% of a 54 dp disc. The centred `MM:SS` text (`:1026-1029`) is cut in half when docked. Once it does dim (A1), it should still be useful at a glance. **Solution:** when `isDockedState`, draw a compact layout: the progress arc plus the glyph shifted toward the visible half (offset `cx` by `±tuckPx/2`), and drop or shorten the time text.

---

## 3. Symptom B: it hides and shows like a glitch

### B1. 🔴 The bubble is deleted whenever the timer is paused (by design since `bc56dd8`)
**Where:** `syncRunnable` `TaskBubbleOverlay.kt:190-217`:
```kotlin
// The floating button exists only while a timer is running.
if (started && enabled && !temporarilyHidden && running) { show() … } else { hide() … postContinueNotification(…) }
```
**What you see:**
- A **single tap** on the bubble = HALT (`onTap` → `task_pause`). About 300-700 ms later the bubble **disappears**, and a "Continue: …" notification appears.
- ENGAGE from that notification or the widget → the bubble **reappears**.
- Checking a checkpoint, finishing, or anything that stops the timer for a moment does the same.
- The paused-state drawing (amber ▶ glyph, frozen time, lines 1010-1022) can never be seen, because the view doesn't exist when paused.

That "now you see it, now you don't" is the main thing that feels like a glitch, even before the races below.

**Solutions (choose a behaviour):**
1. **Recommended: keep it while a session is open.** Show the bubble while `hasTask && (running || pausedWithinGrace)`. In the paused state it shows the amber ▶ (already drawn) and settles/dims the same way. It is removed only when (a) the task is finished, (b) there is no task, (c) it has been paused for longer than a grace period (for example 10 min, configurable), or (d) you drag it to ✕. To do this:
   - Dart: publish `arcane.task.pausedAtMs` in `publishTask` (set in `pauseTimer`, cleared in `startTimer`).
   - Kotlin: `val showBubble = running || (hasTask && now - pausedAtMs < GRACE_MS)`, and post a delayed `sync()` at `pausedAtMs + GRACE_MS` so it leaves on time.
2. **Keep the current rule, but make the exit look intentional:** fade or scale out over 200 ms with a toast "Halted. Tap the notification to resume." Make tap-to-HALT ask for a second tap, or move HALT to long-press/radial only, so a casual tap doesn't make it vanish.
3. **Debounce the hide:** never remove the bubble until `isRunning` has been false for 1.5 s continuously. This alone hides every sub-second flip from B2-B4. It's a good safety net even with option 1:
   ```kotlin
   private var notRunningSince = 0L
   // in syncRunnable, else-branch:
   if (notRunningSince == 0L) notRunningSince = SystemClock.uptimeMillis()
   if (SystemClock.uptimeMillis() - notRunningSince < 1500) { handler.postDelayed(syncRunnable, 1600); return@Runnable }
   // in the running branch: notRunningSince = 0L
   ```

### B2. 🔴 Non-atomic publish: the bubble reads half-written state
**Where:** `HomeWidgetService._setAll()` `home_widget_service.dart:280-288` awaits `HomeWidget.saveWidgetData` **once per key**: about 30 platform-channel round trips, each its own `SharedPreferences` commit. `TaskBubbleOverlay.widgetListener` (`:129-134`) re-syncs **60 ms** after any `arcane.task.*` key changes. One publish often takes longer than 60 ms, so `syncRunnable` runs mid-publish and sees, for example:
- the new `isRunning=true` with the old `sessionStartMs` → the clock jumps back, then forward;
- a new `title` with the old `isRunning` → the "Continue" notification flashes, or `temporarilyHidden` clears too early (B8);
- `updatedAtMs` sits in the *middle* of the map, so even "wait for updatedAtMs" wouldn't help today.

**Solutions (best first):**
1. **Single atomic snapshot.** Publish one key, `arcane.task.snapshot` (a JSON string of all task fields), plus `arcane.task.rev` (an int). In Kotlin, react only to `arcane.task.rev` and parse the snapshot. One write means no torn reads. Widgets can read the same snapshot, or keep the old keys for compatibility. Write the old keys first and `rev` **last**.
2. **One native commit.** Add a `LauncherBridge` method `putTaskState(Map)` that does a single `prefs.edit().putX(...)...apply()` on the Kotlin side. The listener then fires in one burst, and all values are already in memory when `syncRunnable` runs.
3. **Minimum quick fix:** move `'arcane.task.updatedAtMs'` to be the **last** key written (Dart map literals keep insertion order). Make `widgetListener` react only to `key == "arcane.task.updatedAtMs"` and to `KEY_ENABLED`. Raise the debounce to ~150 ms.

### B3. 🔴 Concurrent publishers race each other
**Where:** the same `_setAll` loop is entered at the same time by:
- the debounced provider listener (`home_widget_publisher.dart:86`, 400 ms);
- `republishNow()` → `publishAll()`, called from `_taskPause`/`_taskStart` **right away** (`widget_action_router.dart:316, 328`). It runs `_publishTheme(force)` first (6 widget refreshes) and only then the task;
- the 30 s heartbeat `_publishTask(force: true)` (`:30-36`);
- Widgets Studio pushes (B4).

There is no lock or "latest wins" rule. Example: the heartbeat starts writing snapshot **S1 (running)**, you HALT, and the router publishes **S2 (paused)**. Both loops are `await`ing, so S1's later writes land after S2's. Any field S1 writes after S2 wins, and `hasTask`/`title`/`isRunning`/`sessionStartMs` can end up mixed. The result is that the bubble **comes back after HALT** or **disappears while running**, and stays wrong until the next heartbeat 30 s later.

**Solutions:**
1. **Serialize and coalesce in `HomeWidgetService.publishTask`** (latest wins, never interleaved):
   ```dart
   Map<String, Object>? _queuedTask;
   Future<void>? _taskWriter;
   Future<void> publishTask({...}) async {
     _queuedTask = data;                      // newest snapshot replaces any queued one
     return _taskWriter ??= () async {
       try {
         while (_queuedTask != null) {
           final next = _queuedTask!; _queuedTask = null;
           await _setAll(next);
           await _refresh(_providerRunning); await _refresh(_providerDayPlan);
         }
       } finally { _taskWriter = null; }
     }();
   }
   ```
2. In `republishNow()`, call `_publishTask(force: true)` **first** (or only), not the whole `publishAll()` that starts with the theme.
3. Let the heartbeat skip writing when nothing changed. Compare the key the way the non-force path does, and only force-rewrite every ~5 min. Otherwise every 30 s it rewrites `updatedAtMs` and wakes the bubble, all widgets and `TaskForegroundService` (see C1/C7).

### B4. 🟠 Widgets Studio writes preview data into the live keys
**Where:** `WidgetsStudioSync.pushTaskToAndroid` / `pushAllToAndroid` (`widgets_studio_sync.dart:55-71, 173-184`). These are called from the Studio tabs and `launcher_widget_view.dart:177`. They call the same `publishTask` **without `sessionStart`** and with editor-provided `isRunning`.
- If the preview says not running → the bubble **hides** while your real timer runs.
- If it says running with `sessionStartMs = 0` → the bubble shows a **frozen** clock.
- `HomeWidgetPublisher._lastTaskKey` hasn't changed, so the normal path won't correct it. Only the 30 s heartbeat will.

**Solutions:** after any Studio push, call `HomeWidgetPublisher.republishNow()` straight away. Better, have Studio "sync" only re-render widgets from live data (`_publishTask(force: true)`) and keep preview-only values in separate `arcane.preview.*` keys that the bubble ignores.

### B5. 🟠 Taps are queued while the app is busy, then replayed later
**Where:** `WidgetActionRouter._dispatch` `widget_action_router.dart:111-115`. If `authLoading || dataLoadInProgress || currentUser == null || localLoadError != null || cloudAttachRequired`, the action goes into `_pending` and is replayed by `flushPending()` (`app.dart:58`, `app_provider.dart:979`).
- The bubble shows "pending" for 1.2 s (`onTap`, `:478-481`), then nothing happens.
- Minutes later the queued `task_pause`/`task_start` runs → the bubble suddenly disappears or appears. Several queued taps can replay as start → pause → start, which flickers.
- `MainActivity.dispatchWidgetAction` also keeps a `pendingAssistantAction` when the engine is dead, so the same action can arrive twice: once via the launch intent and once via the pending field.
- While the SQLite error in §6 was happening, **every** bubble tap was queued this way.

**Solutions:**
- Stamp bubble actions with a time (`task_pause@<epochMs>`) and **drop** any older than ~10 s when flushing. Show a toast: "Arcane was loading — tap again."
- Never queue toggle actions. Queue only idempotent ones like `task_open_plan`.
- On the Kotlin side, only clear `pending` when Flutter acknowledges the action (`invokeMethod` result), and de-duplicate by action + timestamp.

### B6. 🟠 Window-drop self-heal rebuilds the bubble
**Where:** `syncRunnable` `:196-200`:
```kotlin
if (b != null && !b.isAttachedToWindow && System.currentTimeMillis() - shownAtMs > 3000) { hide(); show() }
```
This runs on every sync: the 20 s Kotlin heartbeat, every prefs change, and the 30 s Dart heartbeat. During screen-off/on, keyguard, or an accessibility service rebind, the view can be detached for a moment. The heal then rebuilds it awake and un-docked (A3), which is a visible pop.

**Solutions:**
- Require two checks in a row (for example `detachedSince` older than 5 s) before rebuilding.
- Restore the docked/dim state on rebuild (A3).
- Use `b.windowToken == null && !b.isAttachedToWindow`, and skip when the screen is off (`PowerManager.isInteractive == false`). Rebuild on `ACTION_SCREEN_ON` instead.

### B7. 🟡 Two bubbles after a service reconnect
**Where:** `LauncherTakeoverService.onServiceConnected` `:297-305` always creates a new `TaskBubbleOverlay` without stopping the old one. Some ROMs (MIUI/HyperOS, and Samsung after an update) call `onServiceConnected` again without `onUnbind`. The old instance keeps its prefs listeners and 20 s heartbeat, so two bubbles are drawn, or each one's `hide()`/`show()` fights the other.

**Solution:** `taskBubble?.stop(); taskBubble = TaskBubbleOverlay(this).also { it.start() }`. Do the same for `noraBubble`.

### B8. 🟡 Drag-to-hide doesn't stay hidden in spirit
**Where:** `temporarilyHideBubble()` `:651-659` and the auto-unhide rule `:182-188`.
1. It sends `task_pause`. The router sets `StoppedTaskMemory.subTaskId`, so the publisher picks the **next** plan item and `arcane.task.title` changes.
2. On the next sync, `currentTitle != lastHiddenTaskTitle` → `temporarilyHidden = false` right away.
3. It isn't running, so the bubble stays hidden. But `postContinueNotification` is no longer blocked, so a **"Continue: <next task>" notification appears right after you threw the bubble away.**

**Solutions:** clear `temporarilyHidden` only on a real **ENGAGE** (`isRunning` going false→true), not on a title change. Also suppress the "Continue" notification for e.g. 15 min after a drag-to-hide.

### B9. 🔵 The clock starts 1 s in the future
`TimerActions.startTimer` sets `startTime = now + 1 s` (`timer_actions.dart:49-50`). The bubble clamps live time at ≥ 0 (`:918`), so for the first second after ENGAGE the readout is frozen. Combined with B2 it can show `00:00`, then jump. **Solution:** use `now` for the published `sessionStartMs`, and keep the +1 s offset only where it prevents session overlap (in `_commitSessionAndPause`).

---

## 4. Other floating-button issues

| # | Issue | Where | Solution |
|---|---|---|---|
| C1 | `TaskForegroundService.start()` is called on **every** sync while running (20 s heartbeat + every prefs change). Each call re-posts the foreground notification and calls `startForegroundService`. On Android 12+ that can throw from the background (it is caught silently) | `TaskBubbleOverlay.kt:204, 208` | Call start/stop only on a running↔stopped **transition**, or when the title/subtitle actually changed |
| C2 | Two "task running" notifications: Dart's `showTimerNotification` and `TaskForegroundService` (id 4001) | `timer_actions.dart:62`, `TaskForegroundService.kt` | Use one: let the foreground service own the notification and have Dart update it via the bridge |
| C3 | `refreshState()` on every sync clears `pending` and restarts the 1 s tick, so the tick can drift or double up for a frame | `:905-913` | Only restart the tick if `running` changed; leave `pending` to its own timeout |
| C4 | Rotation or fold during a dock animation: `onConfigurationChanged` doesn't cancel `dockAnim`/`snapAnim`, so the animation finishes at the old screen's x | `:168-175` | `snapAnim?.cancel(); dockAnim?.cancel()` first, then `placeFromPrefs`, then `scheduleIdle()` |
| C5 | `snapToEdge()` saves `KEY_Y` with `apply()` on every drag end, and the settings listener only watches `KEY_ENABLED`. Fine today, but the Nora bubble uses the **same edge/height defaults** (`0.55f`), so both buttons can stack on top of each other | `:340`, `NoraBubbleOverlay.kt:66-67` | Give the two buttons different default heights, or nudge one away when they overlap |
| C6 | Battery: the Kotlin heartbeat runs every 20 s and the Dart heartbeat every 30 s, and each rewrites `updatedAtMs` → wakes every widget provider and the bubble, even with nothing running | `:83`, `home_widget_publisher.dart:30` | Make the Kotlin heartbeat 60 s and only while the bubble is visible; see B3.3 for the Dart side |
| C7 | The radial menu's "DISABLE" turns the feature off with only a toast, and there is no undo | `:515-522` | Add an "UNDO" action (a snackbar-style overlay for 4 s), or confirm with a second tap |
| C8 | Accessibility: the view has a static `contentDescription` and no `AccessibilityAction`s, so TalkBack users can't halt or engage it | `:901-903` | Add `ViewCompat.addAccessibilityAction` for Halt/Engage/Check/Open plan |

---

## 5. Desktop "Focus Clock" (`DesktopFloatingTimer`)

This is the floating timer on Linux and Windows. It has the same two complaints, from different causes.

| # | Issue | Where | Solution |
|---|---|---|---|
| **D1** | 🟠 **Hides and shows on resize.** It renders only `if (_showDesktopTimer && isLargeScreen)`. `isLargeScreen` = `Responsive.hasRailWidth(width)`, so on a tiling WM, while snapping the window, or near the breakpoint, it vanishes and comes back. Each time it is **disposed**, so its position and minimised state reset to `(80,80)` | `home_screen.dart:259, 368-371`; `desktop_floating_timer.dart:23-24` | Show it based on `_showDesktopTimer` only (allow it on narrow windows too). Lift `_position`/`_isMinimized` into `HomeScreen` state or prefs, or use `Offstage` instead of removing it |
| **D2** | 🟠 **No idle fade at all.** Nothing reduces opacity when it isn't being used | whole widget | Wrap it in `MouseRegion` plus a 3 s `Timer`. Use `AnimatedOpacity(opacity: _idle ? 0.35 : 1)` and restore on hover or drag. Keep the panel background opaque and fade the contents, as in A1 |
| D3 | 🟡 It can be dragged fully off-screen and lost (no clamping) | `:66-70` | Clamp `_position` to `MediaQuery.sizeOf(context)` minus the widget size, on drag and on window resize |
| D4 | 🟡 `context.watch<AppProvider>()` rebuilds it on **every** provider notify (finance, sync flags…) | `:28` | Use `Selector` on `(activeTimers, mainTasks, dayPlan)` |
| D5 | 🟡 It lives inside Arcane's window, so it disappears when Arcane is minimised or covered. It isn't a real "floating" timer | design | Open a small always-on-top frameless window (`window_manager` / `desktop_multi_window`) when Arcane loses focus |
| D6 | 🔵 Whether it is shown isn't remembered across restarts | `home_screen.dart:47` | Persist `_showDesktopTimer` in settings |

---

## 6. ✅ Fixed in this pass: "The local database could not be read"

**Error:** `DatabaseException(unknown error (code 0 SQLITE_OK): Queries can be performed using SQLiteDatabase query or rawQuery methods only.) sql 'PRAGMA journal_mode=WAL'` at `StateDatabase._open` → `readCollections` → `LocalStorageService.loadState` → `AppProvider._loadLocalState`.

**Cause:** `PRAGMA journal_mode=WAL` **returns a row** (the new mode). On Android, sqflite runs `execute()` through `SQLiteDatabase.execSQL`, which refuses any statement that returns rows. The Linux and test driver (`sqflite_common_ffi`) allows it, so tests and the desktop build never caught it. The line came in with `5da8f25`.

**Fix (applied):** `lib/src/services/state_database.dart`, in `onConfigure`:
```dart
// journal_mode returns a row; Android sqflite rejects row-returning statements in execute().
await db.rawQuery('PRAGMA journal_mode=WAL');
```
`PRAGMA synchronous=FULL` returns nothing, so it stays as `execute`.

**Data safety:** the load error set `localLoadError`, which blocks saves and cloud pushes, so no data was overwritten while it was failing. Bubble and widget actions taken in that window were queued (B5).

**Follow-ups:**
- Add a lint or grep check in CI: `execute('PRAGMA` is only allowed for pragmas that return no rows (`synchronous`, `foreign_keys`, `busy_timeout` are fine; `journal_mode`, `quick_check`, `integrity_check`, `wal_checkpoint` need `rawQuery`).
- Add a smoke test that opens `StateDatabase` on a real Android device or emulator (an `integration_test`), because the FFI driver can't reproduce this class of bug.

---

## 7. Fix plan and test checklist

**Phase 1: "it never settles" (small and safe)**
1. A1, option 1 (dim the contents, opaque body) or option 2 (`IDLE_ALPHA = 0.45f`). Also add the A1.3 setting if you want it adjustable.
2. A2: reschedule in `settleToSide()` and add `scheduleIdle()` in `dismissDialog()`.

**Phase 2: "it flickers"**
3. Decide on B1 (recommended: keep it while paused, with a grace period) and add the B1.3 1.5 s hide debounce either way.
4. B3: serialize `publishTask` (latest wins). B2: atomic snapshot, or at minimum write `updatedAtMs` last and listen only to it.
5. B5: drop stale queued bubble actions.

**Phase 3: polish**
6. A3 + B6 (restore docked state, safer self-heal), B7 (stop the old instance), B4, B8, B9.
7. C1-C8, then D1-D6 for desktop.

**Manual test checklist (Android)**
- [ ] Start a task, leave it alone 3 s → it docks **and** visibly dims; it never shows wallpaper lines through the body.
- [ ] Double-tap → dialog → cancel → after 3 s it docks and dims again (A2).
- [ ] Long-press → ADD + → submit → it docks and dims again.
- [ ] Single tap (HALT) → it behaves as decided in B1; no flash/reappear within 30 s.
- [ ] HALT, then ENGAGE from the notification 5× quickly → exactly one bubble, the clock never jumps backwards.
- [ ] Leave it running 5 min with the screen on and off 3× → no pop-out on unlock unless touched.
- [ ] Widgets Studio "sync" while a timer runs → the bubble stays and the clock keeps ticking (B4).
- [ ] Kill Arcane, tap the bubble → the action applies once, not twice (B5).
- [ ] Rotate during the dock animation → it ends on the correct edge (C4).
- [ ] Drag to ✕ → hidden, and **no** "Continue" notification right after (B8).
- [ ] Cold start on Android after the §6 fix → no "local database could not be read" screen.

**Desktop**
- [ ] Resize the window across the rail breakpoint → the Focus Clock stays and keeps its position (D1).
- [ ] No hover for 3 s → it fades; hover → full (D2).
- [ ] Drag toward any edge → it can't leave the window (D3).

---

## 8. Implementation status (2026.10.11+2126101103)

Implemented: A1 (option 1, contents dim, disc stays opaque), A2, A3, A4, B1 (option 1 with a 10 min grace, plus the 1.5 s hide debounce), B2 (minimum fix: `updatedAtMs` is written last and is the only key the bubble reacts to), B3 (serialised, latest-wins writer; `republishNow` publishes the task only; the heartbeat forces a rewrite only every 5 min), B4 (a Studio push restores the live timer keys), B5 (stale taps dropped after 15 s, queued halt/engage collapsed to the last one; Kotlin no longer dispatches an already-consumed pending action), B6, B7, B8, B9, C1, C3, C4, C5, C6, C7 (second pick within 6 s instead of an undo), C8, D1, D2, D3, D6, §6.

Not done: B2 option 1/2 (single snapshot key or native bulk commit), C2 (one running notification), D4 (`Selector`; unsafe while provider collections may be mutated in place), D5 (real always-on-top window needs a new dependency). The manual checklist above still needs a device run: this pass could not compile or run Flutter on the authoring machine, so `./build.sh` (analyze, tests, builds) is the first full verification.

