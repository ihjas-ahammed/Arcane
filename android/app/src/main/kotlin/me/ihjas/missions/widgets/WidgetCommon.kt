package me.ihjas.missions.widgets

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import es.antonborri.home_widget.HomeWidgetLaunchIntent

/**
 * Shared utilities for all Arcane home-screen widgets.
 *
 * Widget data is published to SharedPreferences by the Dart side
 * (HomeWidgetService) under the prefs name "HomeWidgetPreferences" — which is
 * what the `home_widget` plugin uses on Android.
 */
object WidgetCommon {
    const val PREFS_NAME = "HomeWidgetPreferences"

    fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun getSafeLong(prefs: SharedPreferences, key: String, defaultVal: Long): Long {
        val value = prefs.all[key] ?: return defaultVal
        return when (value) {
            is Long -> value
            is Int -> value.toLong()
            is Number -> value.toLong()
            is String -> value.toLongOrNull() ?: defaultVal
            else -> defaultVal
        }
    }

    fun getSafeInt(prefs: SharedPreferences, key: String, defaultVal: Int): Int {
        val value = prefs.all[key] ?: return defaultVal
        return when (value) {
            is Int -> value
            is Long -> value.toInt()
            is Number -> value.toInt()
            is String -> value.toIntOrNull() ?: defaultVal
            else -> defaultVal
        }
    }

    fun getSafeDouble(prefs: SharedPreferences, key: String, defaultVal: Double): Double {
        val value = prefs.all[key] ?: return defaultVal
        return when (value) {
            is Double -> value
            is Float -> value.toDouble()
            is Number -> value.toDouble()
            is String -> value.toDoubleOrNull() ?: defaultVal
            else -> defaultVal
        }
    }

    fun getSafeBoolean(prefs: SharedPreferences, key: String, defaultVal: Boolean): Boolean {
        val value = prefs.all[key] ?: return defaultVal
        return when (value) {
            is Boolean -> value
            is String -> value.toBoolean()
            is Number -> value.toInt() != 0
            else -> defaultVal
        }
    }

    /**
     * Build a PendingIntent that launches MainActivity with an arcane://widget
     * deep-link URI. Flutter side observes these via HomeWidget.widgetClicked
     * and dispatches the action to AppProvider.
     */
    fun launchIntent(context: Context, action: String): PendingIntent {
        val uri = Uri.parse("arcane://widget?action=$action")
        return HomeWidgetLaunchIntent.getActivity(
            context,
            me.ihjas.missions.MainActivity::class.java,
            uri,
        )
    }

    fun fmtMoney(amount: Double): String {
        val abs = kotlin.math.abs(amount)
        val sign = if (amount < 0) "-" else ""
        return when {
            abs >= 1_00_00_000 -> "$sign₹%.2fCr".format(abs / 1_00_00_000.0)
            abs >= 1_00_000 -> "$sign₹%.2fL".format(abs / 1_00_000.0)
            abs >= 1_000 -> "$sign₹%.1fK".format(abs / 1_000.0)
            else -> "$sign₹%.0f".format(abs)
        }
    }

    fun fmtSeconds(sec: Long): String {
        if (sec < 3600) {
            val m = sec / 60
            val s = sec % 60
            return "%02d:%02d".format(m, s)
        }
        val h = sec / 3600
        val m = (sec % 3600) / 60
        return "%dh %02dm".format(h, m)
    }
}
