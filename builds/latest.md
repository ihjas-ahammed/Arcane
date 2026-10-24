# Missions 2026.10.24 (build 2126102401)

- Quick Settings tile "Grayscale": a status bar toggle that switches the display to grayscale (Android colour correction: grayscale).
- The tile needs a one-time permission. Tap it without the permission to open the setup guide, which lists the adb steps and has a copy button for the grant command.
- Setup command (one time, from a computer with adb): `adb shell pm grant me.ihjas.missions android.permission.WRITE_SECURE_SETTINGS`
- Android: arm64-v8a and armeabi-v7a only.
- Desktop (Linux x86_64) bundle is published in a second stage after the Android release.

Firebase Storage is not used for this project. Database backups are kept locally. Hosted release data is on GitHub.
