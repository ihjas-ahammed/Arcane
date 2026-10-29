# Missions 2026.10.29 (build 2126102901)

- Goal reminders: an incomplete goal from a previous day no longer sends reminders. Reminders now belong to the day the goal was made for.
- One-day daily goals remind once, on their own day, and do not repeat. Recurring goals keep their daily reminder.
- Goal reminders are re-armed at the daily rollover, so yesterday's reminders stop without opening the goals screen.
- Android: arm64-v8a and armeabi-v7a only.
- Desktop (Linux x86_64) bundle is published in a second stage after the Android release.

Firebase Storage is not used for this project. Database backups are kept locally. Hosted release data is on GitHub.
