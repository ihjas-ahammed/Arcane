# Missions 2026.10.16 (build 2126101601)

- People Intel: hold "Initiate Tactical Scans" to run the scan in an external AI. The prompt and data match the in-app scan, but cover the whole reflection archive (all time). Paste the JSON reply back to resolve people the same way as the in-app scan.
- Physical activity: the workout time source is limited to tasks in health protocols (class HEALTH). The task you link is remembered and pre-selected next time.
- Running a task no longer adds it to the day plan. The day plan is predefined.
- The "Continue: <task>" notification is removed.

Known risk, carried over from 2026.10.15 (build 2126101502): widget task buttons with Arcane closed are applied in the background, and that path is not yet verified on a device. If a tap does nothing, open the app once and report it.

Firebase Storage is not used for this project. Database backups are kept locally. Hosted release data is on GitHub.
