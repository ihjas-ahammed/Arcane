# Phoenix Planner Makeover — Design

Date: 2026-06-03

## Goal

Evolve the day planner from a flat ordered checklist into a priority-anchored,
capacity-honest daily plan, and give the two task surfaces (schedule hero card +
Android home-screen widget) a full makeover around it.

Grounded in planning literature:
- **Daily highlight / one most-important task** — *Make Time* (Knapp &
  Zeratsky), *Eat That Frog* (Tracy). Here: the **Phoenix**.
- **Planning-fallacy buffer** — we over-plan; reserve slack. Here: the **60%
  rule** (plan to ~60% of remaining wake-time).
- (*Time-blocking / Eisenhower were considered and deferred — out of scope.*)

## Decisions (locked)

- Phoenix is **manually anointed**, **one per day**.
- Capacity uses the **60% rule on the remaining window** (single lever; no
  per-estimate padding, to avoid double-counting).
- Both widgets **headline the Phoenix** when nothing is actively running.

## Current state (for reference)

- A day plan is an ordered `List<String>` of compound IDs (`task|sub` or
  `task|sub|checkpoint`) stored at `completedByDay[date]['dailyPlan']`, with
  per-item estimates at `['dailyPlanEstimates']`.
- `resolveDayWindow` (`day_budget_helper.dart`) derives wake/sleep from sleep
  history (median, ≥3 samples) or falls back to 07:00–22:00; `minutesRemaining`
  gives time left today.
- Hero resolution (in `schedule_view.dart` and mirrored in
  `home_widget_publisher.dart`): running session → first uncompleted plan item.
- Android widgets live in `android/.../widgets/*.kt` +
  `res/layout/widget_running_task.xml`, fed via `HomeWidgetService`.

## Changes

### 1. Data & logic

**`lib/src/providers/actions/task_actions.dart`**
- `String? getPhoenixId(String dateStr)` → reads `completedByDay[date]['phoenixId']`.
- `void setPhoenix(String dateStr, String? compoundId)` → writes it (null clears);
  follows the existing `updateDayPlan` write pattern (`setProviderState`).
- In `completeSubtask` / `completeSubSubtask` / `removeFromDayPlan` paths: if the
  affected compoundId equals the day's `phoenixId`, clear it.
- In `carryOverUnfinished`: if the source `phoenixId` is still actionable and not
  already set on the destination day, carry it over.

**`lib/src/utils/day_budget_helper.dart`**
- `const double kCapacityBufferRatio = 0.6;`
- `int DayWindow.realisticMinutes(DateTime now)` → `(minutesRemaining(now) * kCapacityBufferRatio).round()`.

### 2. Today Planner screen — `today_planner_screen.dart`

- Load `phoenixId` in `didChangeDependencies`; track locally like `_plan`.
- **Phoenix card** pinned above the queue: renders the anointed item with amber
  accent + 🔥 glyph; the anointed id is excluded from the queue list below.
  Empty → a subtle "Anoint your Phoenix" prompt.
- Each `_PlanRow` gets a phoenix toggle icon (amber/filled when anointed) calling
  `provider.taskActions.setPhoenix(date, id)` (tapping the current Phoenix clears).
- `_BudgetBar` → buffer-aware: compares `plannedMinutes` to
  `window.realisticMinutes(now)`; label "X planned / Y realistic"; raw
  "X LEFT" retained; over/threshold colors computed against realistic.

### 3. Schedule hero card

**`schedule_view.dart`** — resolution priority becomes **running → Phoenix (if
actionable) → next queue item**. Pass an `isPhoenix` bool to the hero.

**`schedule_hero_widget.dart`** — when `isPhoenix`, status line reads
`🔥 PHOENIX · ENGAGED/STANDBY`, amber accent, phoenix glyph. Add a small capacity
readout ("2h40 planned / 4h30 realistic") sourced from the day window.

### 4. Android home-screen widget

**`lib/src/services/home_widget_publisher.dart`** — `_resolveActiveTask` priority
becomes running → Phoenix → next; compute `isPhoenix` + a capacity summary
string ("2h40 / 4h30"); include both in the publish key + payload.

**`lib/src/services/home_widget_service.dart`** — extend `publishTask` with
`isPhoenix` and `capacity` fields (saved for the native side).

**`android/.../widgets/RunningTaskWidget.kt`** + **`res/layout/widget_running_task.xml`**
- Add a 🔥 PHOENIX badge (shown when `isPhoenix`) and a capacity line; restyle to
  match the mockup (amber accent, rounded). Running task still overrides the
  headline when a timer is live.

## Out of scope

Time-blocking (assigning items to clock times), Eisenhower priority tags,
morning-planning nudge. May revisit later.
