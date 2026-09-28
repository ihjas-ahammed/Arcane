package me.ihjas.missions

import android.accessibilityservice.AccessibilityService
import android.app.ActivityOptions
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.content.pm.PackageManager
import android.os.SystemClock
import android.provider.Settings
import android.view.accessibility.AccessibilityEvent

/**
 * "Open Arcane over the default launcher" mode, for ROMs such as MIUI/HyperOS that keep
 * forcing their own home app.
 *
 * When enabled (and this accessibility service is switched on), every time the system home
 * screen comes to the front we immediately bring Arcane's launcher up on top of it with a HOME
 * intent, so it behaves as if Arcane were the default home app. Apps with a bound accessibility
 * service are exempt from Android's background-activity-start limits, which is what makes this
 * work reliably.
 *
 * The same service also hosts the floating task button ([TaskBubbleOverlay]), which it draws as
 * an accessibility overlay.
 */
class LauncherTakeoverService : AccessibilityService() {

    companion object {
        private const val PREFS = "arcane_launcher"
        private const val KEY_ENABLED = "takeover_enabled"
        const val EXTRA_TAKEOVER = "arcane_takeover"
        private const val DEBOUNCE_MS = 350L
        private const val HOME_CACHE_MS = 30_000L

        fun isEnabled(context: Context): Boolean =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_ENABLED, false)

        fun setEnabled(context: Context, enabled: Boolean) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(KEY_ENABLED, enabled).apply()
        }

        /** Whether the user has switched this service on in Android's accessibility settings. */
        fun isServiceEnabled(context: Context): Boolean {
            val flat = ComponentName(context, LauncherTakeoverService::class.java).flattenToString()
            val short = ComponentName(context, LauncherTakeoverService::class.java).flattenToShortString()
            val enabled = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
            ) ?: return false
            return enabled.split(':').any { it.equals(flat, true) || it.equals(short, true) }
        }

        /** Packages of the other launchers on the device (the one the system shows on HOME). */
        fun otherHomePackages(context: Context): Set<String> {
            val pm = context.packageManager
            val home = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
            val out = LinkedHashSet<String>()
            pm.resolveActivity(home, PackageManager.MATCH_DEFAULT_ONLY)?.activityInfo?.packageName?.let { out.add(it) }
            for (ri in pm.queryIntentActivities(home, 0)) out.add(ri.activityInfo.packageName)
            // Never react to ourselves, the chooser, or the boot-time Settings fallback home.
            out.remove(context.packageName)
            out.remove("android")
            out.remove("com.android.settings")
            return out
        }
    }

    private var homePackages: Set<String> = emptySet()
    private var homeResolvedAt = 0L
    private var lastLaunchAt = 0L
    private var taskBubble: TaskBubbleOverlay? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        refreshHomePackages()
        taskBubble = TaskBubbleOverlay(this).also { it.start() }
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        taskBubble?.onConfigurationChanged()
    }

    override fun onUnbind(intent: Intent?): Boolean {
        taskBubble?.stop()
        taskBubble = null
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        taskBubble?.stop()
        taskBubble = null
        super.onDestroy()
    }

    private fun refreshHomePackages() {
        homePackages = try { otherHomePackages(this) } catch (_: Exception) { emptySet() }
        homeResolvedAt = SystemClock.elapsedRealtime()
        // Only get woken for the stock launcher's windows: less event traffic, faster reaction.
        try {
            val info = serviceInfo
            if (info != null && homePackages.isNotEmpty()) {
                info.packageNames = homePackages.toTypedArray()
                info.notificationTimeout = 0
                serviceInfo = info
            }
        } catch (_: Exception) {
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return
        if (pkg == packageName) return
        if (!isEnabled(this)) return

        val now = SystemClock.elapsedRealtime()
        if (now - homeResolvedAt > HOME_CACHE_MS) refreshHomePackages()
        if (pkg !in homePackages) return

        // The stock launcher also hosts recents / its own overlays (MIUI keeps recents inside
        // com.miui.home). Only take over for the actual home screen, never for those.
        val cls = event.className?.toString().orEmpty()
        if (cls.contains("recent", ignoreCase = true) ||
            cls.contains("Dialog", ignoreCase = false) ||
            cls.contains("PopupWindow") ||
            cls.startsWith("android.widget.") ||
            cls.startsWith("android.view.")
        ) return

        if (now - lastLaunchAt < DEBOUNCE_MS) return
        lastLaunchAt = now

        val intent = Intent(Intent.ACTION_MAIN)
            .addCategory(Intent.CATEGORY_HOME)
            .setClass(this, MainActivity::class.java)
            .putExtra(EXTRA_TAKEOVER, true)
            .addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                    Intent.FLAG_ACTIVITY_NO_ANIMATION or
                    Intent.FLAG_ACTIVITY_NO_USER_ACTION
            )
        // Zero-duration custom animation: the stock launcher is replaced in the same frame
        // instead of Arcane sliding/fading in over it.
        val options = try {
            ActivityOptions.makeCustomAnimation(this, 0, 0).toBundle()
        } catch (_: Exception) {
            null
        }
        try {
            startActivity(intent, options)
        } catch (_: Exception) {
            try { startActivity(intent) } catch (_: Exception) {}
        }
    }

    override fun onInterrupt() {}
}
