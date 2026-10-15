# Missions 2026.10.15 (build 2126101503)

- Daily briefing export and prompt now include notifications from the journal, even if the journal screen was not opened that day.
- Briefing prompt: finance income, expense and net are bare numbers. Explanations go in a separate finance note, and values shown on small cards carry no units or descriptions.
- Android: arm64-v8a and armeabi-v7a only. x86 builds are no longer published.
- Known risk, unchanged from 2026.10.15 (build 2126101502): widget task buttons with Arcane closed are applied in the background, and that path is not yet verified on a device. If a tap does nothing, open the app once and report it.

Firebase Storage is not used for this project. Database backups are kept locally. Hosted release data is on GitHub.
