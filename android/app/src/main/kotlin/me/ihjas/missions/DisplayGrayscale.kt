package me.ihjas.missions

import android.content.ContentResolver
import android.content.Context
import android.content.pm.PackageManager
import android.provider.Settings

/**
 * Display grayscale through Android's colour-correction setting
 * (Settings › Accessibility › Colour correction › Grayscale).
 *
 * Writing these secure settings needs WRITE_SECURE_SETTINGS, which the user grants once over adb:
 *   adb shell pm grant me.ihjas.missions android.permission.WRITE_SECURE_SETTINGS
 */
object DisplayGrayscale {
    private const val ENABLED_KEY = "accessibility_display_daltonizer_enabled"
    private const val MODE_KEY = "accessibility_display_daltonizer"

    /** Daltonizer mode 0 is monochromacy, which is the grayscale option. */
    private const val MODE_MONOCHROMACY = 0

    fun hasPermission(context: Context): Boolean =
        context.checkSelfPermission(android.Manifest.permission.WRITE_SECURE_SETTINGS) ==
            PackageManager.PERMISSION_GRANTED

    fun isOn(resolver: ContentResolver): Boolean =
        Settings.Secure.getInt(resolver, ENABLED_KEY, 0) == 1 &&
            Settings.Secure.getInt(resolver, MODE_KEY, -1) == MODE_MONOCHROMACY

    /** Returns false when the permission is missing or the write is refused. */
    fun set(context: Context, on: Boolean): Boolean {
        if (!hasPermission(context)) return false
        return try {
            val resolver = context.contentResolver
            Settings.Secure.putInt(resolver, MODE_KEY, MODE_MONOCHROMACY) &&
                Settings.Secure.putInt(resolver, ENABLED_KEY, if (on) 1 else 0)
        } catch (_: SecurityException) {
            false
        }
    }
}
