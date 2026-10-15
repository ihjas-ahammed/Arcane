# Missions 2026.10.15 (build 2126101502)

- Widget and floating timer buttons (ENGAGE / HALT, CHECK NEXT, FINISH) now use the same task code as the app. When Arcane is closed, they are applied in the background without opening the app.
- Known risk in this build: the background path has not been verified on a device yet. If a button tap does nothing with Arcane closed, open the app once and report it.
- Floating timer readout stays centred in the disc.
- Weekly offline backup is written to the Realtime Database (Firebase Storage is no longer used) and keeps the newest 8 weeks.
- Task logic moved out of the main app state into its own module, so the background path and the app share one implementation.

Firebase Storage is not used for this project. Database backups are kept locally. Hosted release data is on GitHub.
