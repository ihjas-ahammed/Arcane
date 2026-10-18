# Missions 2026.10.18 (build 2126101801)

- Home widgets: the day plan widget shows the top five plan items even before the first publish of the day (it no longer waits for a cache).
- Running task widget: a paused task is resumed from the widget when nothing is running. The paused state is kept when the app writes from the background, so the pause grace period is not overwritten.
- Widget task buttons: queued actions wait until the app has finished loading and signing in, then run in order.
- Schedule: opening the app on another day switches the schedule to today. Checking a day-plan item updates the home widgets immediately.
- Android: arm64-v8a and armeabi-v7a only. x86_64 is no longer published; use the desktop build for x86_64.
- Desktop (Linux x86_64) bundle is published in a second stage after the Android release.

Known risk, carried over from 2026.10.15 (build 2126101502): widget task buttons with Arcane closed are applied in the background, and that path is not yet verified on a device. If a tap does nothing, open the app once and report it.

Firebase Storage is not used for this project. Database backups are kept locally. Hosted release data is on GitHub.
