package me.ihjas.missions

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.app.ActivityOptions
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.graphics.Path
import android.graphics.Rect
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

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
        private const val TAG = "LauncherTakeoverService"
        private const val PREFS = "arcane_launcher"
        private const val PREFS_AUTO_TAP = "arcane_auto_tap"
        private const val KEY_ENABLED = "takeover_enabled"
        const val EXTRA_TAKEOVER = "arcane_takeover"
        private const val DEBOUNCE_MS = 350L
        private const val HOME_CACHE_MS = 30_000L

        @Volatile
        var activeInstance: LauncherTakeoverService? = null
            private set

        @Volatile
        var recordingTapPackage: String? = null

        @Volatile
        var autoTapPendingPackage: String? = null

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

        /** Starts tap recording session for an external assistant package with floating HUD bar. */
        fun startRecordingTap(context: Context, targetPackage: String) {
            recordingTapPackage = targetPackage
            val instance = activeInstance
            if (instance != null) {
                instance.startMicTapRecording(targetPackage)
            } else {
                Handler(Looper.getMainLooper()).post {
                    android.widget.Toast.makeText(
                        context.applicationContext,
                        "Tap the voice/mic button in $targetPackage to record it...",
                        android.widget.Toast.LENGTH_LONG
                    ).show()
                }
            }
        }

        fun hasRecordedTap(context: Context, targetPackage: String): Boolean {
            val prefs = context.getSharedPreferences(PREFS_AUTO_TAP, Context.MODE_PRIVATE)
            return prefs.contains("tap_x_${targetPackage}") || prefs.contains("tap_id_${targetPackage}")
        }

        fun clearRecordedTap(context: Context, targetPackage: String) {
            val prefs = context.getSharedPreferences(PREFS_AUTO_TAP, Context.MODE_PRIVATE)
            prefs.edit()
                .remove("tap_id_${targetPackage}")
                .remove("tap_desc_${targetPackage}")
                .remove("tap_text_${targetPackage}")
                .remove("tap_x_${targetPackage}")
                .remove("tap_y_${targetPackage}")
                .apply()
        }

        fun getRecordedTapInfo(context: Context, targetPackage: String): Map<String, Any?>? {
            val prefs = context.getSharedPreferences(PREFS_AUTO_TAP, Context.MODE_PRIVATE)
            if (!prefs.contains("tap_x_${targetPackage}") && !prefs.contains("tap_id_${targetPackage}")) return null
            return mapOf(
                "package" to targetPackage,
                "viewId" to prefs.getString("tap_id_${targetPackage}", null),
                "desc" to prefs.getString("tap_desc_${targetPackage}", null),
                "text" to prefs.getString("tap_text_${targetPackage}", null),
                "xRatio" to prefs.getFloat("tap_x_${targetPackage}", 0.5f),
                "yRatio" to prefs.getFloat("tap_y_${targetPackage}", 0.5f),
            )
        }

        fun armAutoTap(context: Context, targetPackage: String) {
            if (hasRecordedTap(context, targetPackage)) {
                autoTapPendingPackage = targetPackage
                activeInstance?.updateEventFilter()
            }
        }
    }

    private var homePackages: Set<String> = emptySet()
    private var homeResolvedAt = 0L
    private var lastLaunchAt = 0L
    private var taskBubble: TaskBubbleOverlay? = null
    private var noraBubble: NoraBubbleOverlay? = null
    private var micTapOverlay: ExternalMicTapOverlay? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onServiceConnected() {
        super.onServiceConnected()
        activeInstance = this
        refreshHomePackages()
        taskBubble = TaskBubbleOverlay(this).also { it.start() }
        noraBubble = NoraBubbleOverlay(this).also { it.start() }
        micTapOverlay = ExternalMicTapOverlay(this)
        InputReplyManager.initialize(this)
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        taskBubble?.onConfigurationChanged()
        noraBubble?.onConfigurationChanged()
    }

    override fun onUnbind(intent: Intent?): Boolean {
        if (activeInstance == this) activeInstance = null
        taskBubble?.stop()
        taskBubble = null
        noraBubble?.stop()
        noraBubble = null
        micTapOverlay?.hide()
        micTapOverlay = null
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        if (activeInstance == this) activeInstance = null
        taskBubble?.stop()
        taskBubble = null
        noraBubble?.stop()
        noraBubble = null
        micTapOverlay?.hide()
        micTapOverlay = null
        super.onDestroy()
    }

    fun updateEventFilter() {
        try {
            val info = serviceInfo ?: return
            val inputReplyRecording = InputReplyManager.instance?.isRecordingActive() == true
            val rec = recordingTapPackage
            val auto = autoTapPendingPackage
            if (inputReplyRecording) {
                // Whole-device recording mode: receive events from all packages
                info.packageNames = null
            } else if (rec != null || auto != null) {
                // When recording or auto-tapping, allow events from the target package
                val extraPkgs = listOfNotNull(rec, auto)
                info.packageNames = (homePackages + extraPkgs).toTypedArray()
            } else if (homePackages.isNotEmpty()) {
                info.packageNames = homePackages.toTypedArray()
            } else {
                info.packageNames = null
            }
            serviceInfo = info
        } catch (_: Exception) {}
    }

    private fun refreshHomePackages() {
        homePackages = try { otherHomePackages(this) } catch (_: Exception) { emptySet() }
        homeResolvedAt = SystemClock.elapsedRealtime()
        updateEventFilter()
    }

    fun startMicTapRecording(targetPackage: String) {
        recordingTapPackage = targetPackage
        updateEventFilter()
        mainHandler.post {
            if (micTapOverlay == null) {
                micTapOverlay = ExternalMicTapOverlay(this)
            }
            micTapOverlay?.onSave = {
                saveRecordedMicTap(targetPackage)
            }
            micTapOverlay?.onCancel = {
                cancelMicTapRecording()
            }
            micTapOverlay?.show(targetPackage)
        }
    }

    fun saveRecordedMicTap(targetPackage: String) {
        val overlay = micTapOverlay ?: return
        if (!overlay.hasCandidate) {
            mainHandler.post {
                android.widget.Toast.makeText(
                    applicationContext,
                    "Tap the voice/mic button in $targetPackage first, then tap SAVE.",
                    android.widget.Toast.LENGTH_SHORT
                ).show()
            }
            return
        }

        val prefs = getSharedPreferences(PREFS_AUTO_TAP, Context.MODE_PRIVATE)
        prefs.edit()
            .putString("tap_id_${targetPackage}", overlay.candidateId)
            .putString("tap_desc_${targetPackage}", overlay.candidateDesc)
            .putString("tap_text_${targetPackage}", overlay.candidateText)
            .putFloat("tap_x_${targetPackage}", overlay.candidateXRatio)
            .putFloat("tap_y_${targetPackage}", overlay.candidateYRatio)
            .apply()

        recordingTapPackage = null
        updateEventFilter()
        mainHandler.post {
            overlay.hide()
            android.widget.Toast.makeText(
                applicationContext,
                "✓ Voice switch recorded! Arcane will auto-click this on launch.",
                android.widget.Toast.LENGTH_LONG
            ).show()
        }
    }

    fun cancelMicTapRecording() {
        recordingTapPackage = null
        updateEventFilter()
        mainHandler.post {
            micTapOverlay?.hide()
            android.widget.Toast.makeText(
                applicationContext,
                "Mic tap calibration cancelled.",
                android.widget.Toast.LENGTH_SHORT
            ).show()
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        // ── 0. Whole-Device Input Reply Recording ──────────────────────────
        InputReplyManager.instance?.handleAccessibilityEvent(event)

        val pkg = event.packageName?.toString() ?: return

        // ── 1. Recording First-Time Tap for External Assistant ─────────────
        val recPkg = recordingTapPackage
        if (recPkg != null && pkg == recPkg && event.eventType == AccessibilityEvent.TYPE_VIEW_CLICKED) {
            var node = event.source
            if (node == null && event.recordCount > 0) {
                node = event.getRecord(0)?.source
            }
            val dm = resources.displayMetrics
            val rect = Rect()
            var xRatio = 0.5f
            var yRatio = 0.85f
            var viewId: String? = null
            var desc: String? = event.contentDescription?.toString()
            var text: String? = if (event.text.isNotEmpty()) event.text.joinToString("") else null

            if (node != null) {
                node.getBoundsInScreen(rect)
                // If container spans large screen area and has children, drill down to specific clickable child
                if (rect.width() > (dm.widthPixels * 0.7f) && rect.height() > (dm.heightPixels * 0.35f) && node.childCount > 0) {
                    val leaf = findSmallestClickableNode(node, dm)
                    if (leaf != null) {
                        leaf.getBoundsInScreen(rect)
                        if (leaf.viewIdResourceName != null) viewId = leaf.viewIdResourceName
                        if (leaf.contentDescription != null) desc = leaf.contentDescription.toString()
                        if (leaf.text != null) text = leaf.text.toString()
                    }
                }
                if (rect.width() > 0 && rect.height() > 0) {
                    xRatio = if (dm.widthPixels > 0) (rect.centerX().toFloat() / dm.widthPixels).coerceIn(0.01f, 0.99f) else 0.5f
                    yRatio = if (dm.heightPixels > 0) (rect.centerY().toFloat() / dm.heightPixels).coerceIn(0.01f, 0.99f) else 0.85f
                }
                if (viewId == null) viewId = node.viewIdResourceName
                if (desc.isNullOrEmpty()) desc = node.contentDescription?.toString()
                if (text.isNullOrEmpty()) text = node.text?.toString()
            }

            mainHandler.post {
                micTapOverlay?.updateCandidate(desc, viewId, text, xRatio, yRatio)
            }
            return
        }

        // ── 2. Auto-Clicking Recorded Switch for External Assistant ────────
        val pendingAuto = autoTapPendingPackage
        if (pendingAuto != null && pkg == pendingAuto && event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            autoTapPendingPackage = null
            updateEventFilter()
            mainHandler.postDelayed({
                executeRecordedTap(pendingAuto)
            }, 650)
            return
        }

        // ── 3. Home Launcher Takeover (MIUI / HyperOS guard) ────────────────
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
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
            .setClass(this, LauncherActivity::class.java)
            .putExtra(EXTRA_TAKEOVER, true)
            .addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                    Intent.FLAG_ACTIVITY_NO_ANIMATION or
                    Intent.FLAG_ACTIVITY_NO_USER_ACTION
            )
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

    private fun findSmallestClickableNode(parent: AccessibilityNodeInfo, dm: android.util.DisplayMetrics): AccessibilityNodeInfo? {
        var smallest: AccessibilityNodeInfo? = null
        var minArea = Long.MAX_VALUE
        val r = Rect()

        fun search(node: AccessibilityNodeInfo) {
            node.getBoundsInScreen(r)
            val w = r.width()
            val h = r.height()
            if (w > 0 && h > 0 && w < (dm.widthPixels * 0.8f) && h < (dm.heightPixels * 0.4f)) {
                val area = w.toLong() * h.toLong()
                val isMicMatch = node.contentDescription?.contains("mic", ignoreCase = true) == true ||
                                 node.contentDescription?.contains("voice", ignoreCase = true) == true ||
                                 node.viewIdResourceName?.contains("mic", ignoreCase = true) == true ||
                                 node.viewIdResourceName?.contains("voice", ignoreCase = true) == true
                if (area < minArea && (node.isClickable || isMicMatch)) {
                    minArea = area
                    smallest = node
                }
            }
            for (i in 0 until node.childCount) {
                val child = node.getChild(i) ?: continue
                search(child)
            }
        }
        search(parent)
        return smallest
    }

    private fun executeRecordedTap(pkg: String) {
        try {
            val prefs = getSharedPreferences(PREFS_AUTO_TAP, Context.MODE_PRIVATE)
            val viewId = prefs.getString("tap_id_${pkg}", null)
            val desc = prefs.getString("tap_desc_${pkg}", null)
            val text = prefs.getString("tap_text_${pkg}", null)
            val xRatio = prefs.getFloat("tap_x_${pkg}", 0.5f)
            val yRatio = prefs.getFloat("tap_y_${pkg}", 0.5f)

            var clicked = false

            // 1. Primary execution: Accurate touch coordinate tap!
            // Directly dispatches physical tap gesture to the calibrated touch coordinates.
            // Works reliably across Flutter, Jetpack Compose, Web, and Native layouts.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && xRatio in 0.01f..0.99f && yRatio in 0.01f..0.99f) {
                val dm = resources.displayMetrics
                val targetX = xRatio * dm.widthPixels
                val targetY = yRatio * dm.heightPixels
                val path = Path().apply { moveTo(targetX, targetY) }
                val stroke = GestureDescription.StrokeDescription(path, 0, 50L)
                val gesture = GestureDescription.Builder().addStroke(stroke).build()
                clicked = dispatchGesture(gesture, null, null)
                Log.i(TAG, "executeRecordedTap dispatched direct touch tap at ($targetX, $targetY) - result=$clicked")
            }

            // 2. Secondary fallback: Look for button nodes only if gesture dispatch failed
            if (!clicked) {
                val root = rootInActiveWindow
                if (root != null) {
                    // Try finding by view ID
                    if (!viewId.isNullOrEmpty()) {
                        val nodes = root.findAccessibilityNodeInfosByViewId(viewId)
                        for (node in nodes) {
                            if (node.isClickable && node.performAction(AccessibilityNodeInfo.ACTION_CLICK)) {
                                clicked = true
                                break
                            }
                        }
                    }
                    // Try finding by content description
                    if (!clicked && !desc.isNullOrEmpty()) {
                        val nodes = root.findAccessibilityNodeInfosByText(desc)
                        for (node in nodes) {
                            if (node.isClickable && node.performAction(AccessibilityNodeInfo.ACTION_CLICK)) {
                                clicked = true
                                break
                            }
                        }
                    }
                    // Try finding by text
                    if (!clicked && !text.isNullOrEmpty()) {
                        val nodes = root.findAccessibilityNodeInfosByText(text)
                        for (node in nodes) {
                            if (node.isClickable && node.performAction(AccessibilityNodeInfo.ACTION_CLICK)) {
                                clicked = true
                                break
                            }
                        }
                    }
                }
            }

            if (clicked) {
                mainHandler.post {
                    android.widget.Toast.makeText(
                        applicationContext,
                        "Auto-engaged voice mode via touch tap",
                        android.widget.Toast.LENGTH_SHORT
                    ).show()
                }
            }
        } catch (_: Exception) {}
    }

    override fun onInterrupt() {}
}
