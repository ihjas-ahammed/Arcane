# Missions 2026.10.16 (build 2126101602)

- People Intel: multi-select, then "generate reports" in the selection bar. In-app AI runs all selected people at once. External AI runs one copy-and-paste for all of them, and each report is saved on the person's dossier. Long-press "Analyze reflections" or "Refresh AI dossier" for a single person's external report.
- Physical activity: the workout time source is limited to tasks in health protocols (class HEALTH). The linked task is remembered.
- Running a task no longer adds it to the day plan. The day plan is predefined.
- The "Continue: <task>" notification is removed.
- Floating timer button: it rebuilds about 1 second after the system detaches it while the screen is on (was 5 seconds).
- Android: arm64-v8a and armeabi-v7a only. x86_64 is no longer published; use the desktop build for x86_64.
- Desktop (Linux x86_64) bundle is published in a second stage after the Android release.

Known risk, carried over from 2026.10.15 (build 2126101502): widget task buttons with Arcane closed are applied in the background, and that path is not yet verified on a device. If a tap does nothing, open the app once and report it.

Firebase Storage is not used for this project. Database backups are kept locally. Hosted release data is on GitHub.
