package me.ihjas.missions

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.app.ActivityOptions
import android.app.KeyguardManager
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
import android.os.PowerManager
import android.media.AudioManager
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import android.view.KeyEvent
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

        // A repeat assistant press while the external AI is still in its session must not
        // replay the tap: the recorded tap is a toggle (call/mic button) and would end it.
        private const val AUTO_TAP_SESSION_WINDOW_MS = 10 * 60 * 1000L
        private val lastAutoTapAt = HashMap<String, Long>()

        // Recent tap alone is not enough (the user may have ended the session since); the
        // external AI must also be holding the mic right now. Arcane is not recording at
        // the moment an assistant press arrives, so any active recording is the AI's.
        private fun sessionLikelyActive(context: Context, pkg: String): Boolean {
            val last = lastAutoTapAt[pkg] ?: return false
            if (SystemClock.elapsedRealtime() - last >= AUTO_TAP_SESSION_WINDOW_MS) return false
            val am = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return false
            return try { am.activeRecordingConfigurations.isNotEmpty() } catch (_: Exception) { false }
        }

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

        /** Starts tap recording session for an external assistant package with floating HUD bar or reticle. */
        fun startRecordingTap(context: Context, targetPackage: String, method: String? = null) {
            recordingTapPackage = targetPackage
            val instance = activeInstance
            if (instance != null) {
                instance.startMicTapRecording(targetPackage, method)
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

        fun saveManualCoordinates(context: Context, targetPackage: String, xRatio: Float, yRatio: Float) {
            val prefs = context.getSharedPreferences(PREFS_AUTO_TAP, Context.MODE_PRIVATE)
            prefs.edit()
                .remove("tap_id_${targetPackage}")
                .remove("tap_desc_${targetPackage}")
                .remove("tap_text_${targetPackage}")
                .putFloat("tap_x_${targetPackage}", xRatio)
                .putFloat("tap_y_${targetPackage}", yRatio)
                .apply()
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

        fun getMicClickDelay(context: Context): Long {
            val prefs = context.getSharedPreferences(PREFS_AUTO_TAP, Context.MODE_PRIVATE)
            return try {
                prefs.getLong("mic_click_delay_ms", 1000L)
            } catch (_: Exception) {
                prefs.getInt("mic_click_delay_ms", 1000).toLong()
            }
        }

        fun setMicClickDelay(context: Context, delayMs: Long) {
            val prefs = context.getSharedPreferences(PREFS_AUTO_TAP, Context.MODE_PRIVATE)
            prefs.edit().putLong("mic_click_delay_ms", delayMs.coerceIn(100L, 10000L)).apply()
        }

        fun armAutoTap(context: Context, targetPackage: String) {
            if (hasRecordedTap(context, targetPackage)) {
                if (sessionLikelyActive(context, targetPackage)) {
                    Log.i(TAG, "armAutoTap skipped for $targetPackage: session already active, not toggling it off")
                    return
                }
                autoTapPendingPackage = targetPackage
                activeInstance?.updateEventFilter()

                // If package is already the active window (e.g. testing in foreground), execute with delay directly
                val currentPkg = activeInstance?.rootInActiveWindow?.packageName?.toString()
                if (currentPkg == targetPackage) {
                    val delay = getMicClickDelay(context)
                    activeInstance?.mainHandler?.postDelayed({
                        if (autoTapPendingPackage == targetPackage) {
                            autoTapPendingPackage = null
                            activeInstance?.updateEventFilter()
                            activeInstance?.executeRecordedTap(targetPackage)
                        }
                    }, delay)
                }
            }
        }

        fun hasUnlockGesture(context: Context): Boolean {
            val prefs = context.getSharedPreferences(PREFS_AUTO_TAP, Context.MODE_PRIVATE)
            return prefs.getBoolean("unlock_has_gesture", false)
        }

        fun saveUnlockGesture(
            context: Context,
            startX: Float,
            startY: Float,
            endX: Float,
            endY: Float,
            durationMs: Long
        ) {
            val prefs = context.getSharedPreferences(PREFS_AUTO_TAP, Context.MODE_PRIVATE)
            prefs.edit()
                .putBoolean("unlock_has_gesture", true)
                .putFloat("unlock_start_x", startX)
                .putFloat("unlock_start_y", startY)
                .putFloat("unlock_end_x", endX)
                .putFloat("unlock_end_y", endY)
                .putLong("unlock_duration_ms", durationMs)
                .apply()
        }

        fun clearUnlockGesture(context: Context) {
            val prefs = context.getSharedPreferences(PREFS_AUTO_TAP, Context.MODE_PRIVATE)
            prefs.edit()
                .remove("unlock_has_gesture")
                .remove("unlock_start_x")
                .remove("unlock_start_y")
                .remove("unlock_end_x")
                .remove("unlock_end_y")
                .remove("unlock_duration_ms")
                .apply()
        }

        fun getUnlockGestureInfo(context: Context): Map<String, Any?>? {
            val prefs = context.getSharedPreferences(PREFS_AUTO_TAP, Context.MODE_PRIVATE)
            if (!prefs.getBoolean("unlock_has_gesture", false)) return null
            return mapOf(
                "hasGesture" to true,
                "startX" to prefs.getFloat("unlock_start_x", 0.5f),
                "startY" to prefs.getFloat("unlock_start_y", 0.85f),
                "endX" to prefs.getFloat("unlock_end_x", 0.5f),
                "endY" to prefs.getFloat("unlock_end_y", 0.20f),
                "durationMs" to prefs.getLong("unlock_duration_ms", 300L)
            )
        }

        fun startRecordingUnlockGesture(context: Context): Boolean {
            val instance = activeInstance
            if (instance != null) {
                instance.startUnlockCalibration()
                return true
            } else {
                Handler(Looper.getMainLooper()).post {
                    android.widget.Toast.makeText(
                        context.applicationContext,
                        "Please enable Arcane in Accessibility Settings first.",
                        android.widget.Toast.LENGTH_LONG
                    ).show()
                }
                return false
            }
        }

        fun testUnlockGesture(context: Context): Boolean {
            val instance = activeInstance
            if (instance != null) {
                instance.testUnlockSequence()
                return true
            } else {
                Handler(Looper.getMainLooper()).post {
                    android.widget.Toast.makeText(
                        context.applicationContext,
                        "Please enable Arcane in Accessibility Settings first.",
                        android.widget.Toast.LENGTH_LONG
                    ).show()
                }
                return false
            }
        }
    }

    private var homePackages: Set<String> = emptySet()
    private var homeResolvedAt = 0L
    private var lastLaunchAt = 0L
    private var taskBubble: TaskBubbleOverlay? = null
    private var noraBubble: NoraBubbleOverlay? = null
    private var micTapOverlay: ExternalMicTapOverlay? = null
    private var reticleOverlay: ReticleCalibrationOverlay? = null
    private var touchSensorOverlay: TouchSensorOverlay? = null
    private var unlockOverlay: UnlockSensorOverlay? = null
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
        reticleOverlay?.hide()
        reticleOverlay = null
        touchSensorOverlay?.hide()
        touchSensorOverlay = null
        unlockOverlay?.hide()
        unlockOverlay = null
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
        reticleOverlay?.hide()
        reticleOverlay = null
        touchSensorOverlay?.hide()
        touchSensorOverlay = null
        unlockOverlay?.hide()
        unlockOverlay = null
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

    fun startMicTapRecording(targetPackage: String, method: String? = null) {
        recordingTapPackage = targetPackage
        updateEventFilter()
        val prefs = getSharedPreferences(PREFS_AUTO_TAP, Context.MODE_PRIVATE)
        val chosenMethod = method ?: prefs.getString("mic_calibration_method", "reticle") ?: "reticle"

        mainHandler.post {
            micTapOverlay?.hide()
            reticleOverlay?.hide()
            touchSensorOverlay?.hide()

            when (chosenMethod) {
                "reticle" -> {
                    if (reticleOverlay == null) {
                        reticleOverlay = ReticleCalibrationOverlay(this)
                    }
                    reticleOverlay?.onSaved = { xRatio, yRatio ->
                        saveManualCoordinates(targetPackage, xRatio, yRatio)
                    }
                    reticleOverlay?.onCancelled = {
                        cancelMicTapRecording()
                    }
                    reticleOverlay?.show(targetPackage)
                }
                "touch_sensor" -> {
                    if (touchSensorOverlay == null) {
                        touchSensorOverlay = TouchSensorOverlay(this)
                    }
                    touchSensorOverlay?.onTouchCaptured = { xRatio, yRatio ->
                        saveManualCoordinates(targetPackage, xRatio, yRatio)
                    }
                    touchSensorOverlay?.onCancelled = {
                        cancelMicTapRecording()
                    }
                    touchSensorOverlay?.show(targetPackage)
                }
                else -> {
                    // auto_detect
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
        }
    }

    fun saveManualCoordinates(targetPackage: String, xRatio: Float, yRatio: Float) {
        val prefs = getSharedPreferences(PREFS_AUTO_TAP, Context.MODE_PRIVATE)
        prefs.edit()
            .remove("tap_id_${targetPackage}")
            .remove("tap_desc_${targetPackage}")
            .remove("tap_text_${targetPackage}")
            .putFloat("tap_x_${targetPackage}", xRatio)
            .putFloat("tap_y_${targetPackage}", yRatio)
            .apply()

        recordingTapPackage = null
        updateEventFilter()
        mainHandler.post {
            reticleOverlay?.hide()
            touchSensorOverlay?.hide()
            micTapOverlay?.hide()
            android.widget.Toast.makeText(
                applicationContext,
                "✓ Voice switch locked at ${(xRatio * 100).toInt()}%, ${(yRatio * 100).toInt()}%!",
                android.widget.Toast.LENGTH_LONG
            ).show()
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
            reticleOverlay?.hide()
            touchSensorOverlay?.hide()
            android.widget.Toast.makeText(
                applicationContext,
                "Mic tap calibration cancelled.",
                android.widget.Toast.LENGTH_SHORT
            ).show()
        }
    }

    fun wakeScreen() {
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return
            @Suppress("DEPRECATION")
            val wakeLock = pm.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                    PowerManager.ACQUIRE_CAUSES_WAKEUP or
                    PowerManager.ON_AFTER_RELEASE,
                "Arcane:UnlockCalibrationWake"
            )
            wakeLock.acquire(6000L)
        } catch (e: Exception) {
            Log.e(TAG, "Error acquiring wake lock", e)
        }
    }

    fun startUnlockCalibration() {
        mainHandler.post {
            // Step 1: Lock the screen programmatically
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                performGlobalAction(GLOBAL_ACTION_LOCK_SCREEN)
            } else {
                android.widget.Toast.makeText(
                    applicationContext,
                    "Lock the screen manually and turn it back on to record unlock gesture.",
                    android.widget.Toast.LENGTH_LONG
                ).show()
            }

            // Step 2: Wake up the screen after delay and show unlock calibration overlay
            mainHandler.postDelayed({
                wakeScreen()
                if (unlockOverlay == null) {
                    unlockOverlay = UnlockSensorOverlay(this)
                }
                unlockOverlay?.onUnlockSaved = { _, _, _, _, _ ->
                    unlockOverlay?.hide()
                    unlockOverlay = null
                    bringArcaneToFront()
                }
                unlockOverlay?.onCancelled = {
                    unlockOverlay?.hide()
                    unlockOverlay = null
                }
                unlockOverlay?.show()
            }, 850L)
        }
    }

    fun cancelUnlockCalibration() {
        mainHandler.post {
            unlockOverlay?.hide()
            unlockOverlay = null
        }
    }

    fun executeUnlockSequence(onCompleted: () -> Unit) {
        if (!hasUnlockGesture(this)) {
            onCompleted()
            return
        }

        val prefs = getSharedPreferences(PREFS_AUTO_TAP, Context.MODE_PRIVATE)
        val startXRatio = prefs.getFloat("unlock_start_x", 0.5f)
        val startYRatio = prefs.getFloat("unlock_start_y", 0.85f)
        val endXRatio = prefs.getFloat("unlock_end_x", 0.5f)
        val endYRatio = prefs.getFloat("unlock_end_y", 0.20f)
        val duration = prefs.getLong("unlock_duration_ms", 300L).coerceIn(100L, 800L)

        val dm = resources.displayMetrics
        val startX = startXRatio * dm.widthPixels
        val startY = startYRatio * dm.heightPixels
        val endX = endXRatio * dm.widthPixels
        val endY = endYRatio * dm.heightPixels

        val path = Path().apply {
            moveTo(startX, startY)
            lineTo(endX, endY)
        }
        val stroke = GestureDescription.StrokeDescription(path, 0L, duration)
        val gesture = GestureDescription.Builder().addStroke(stroke).build()

        wakeScreen()

        dispatchGesture(
            gesture,
            object : GestureResultCallback() {
                override fun onCompleted(gestureDescription: GestureDescription?) {
                    Log.i(TAG, "Screen unlock swipe gesture executed successfully")
                    mainHandler.postDelayed({
                        onCompleted()
                    }, 450L)
                }

                override fun onCancelled(gestureDescription: GestureDescription?) {
                    Log.w(TAG, "Screen unlock swipe gesture cancelled by system")
                    mainHandler.postDelayed({
                        onCompleted()
                    }, 250L)
                }
            },
            mainHandler
        )
    }

    fun testUnlockSequence() {
        mainHandler.post {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                performGlobalAction(GLOBAL_ACTION_LOCK_SCREEN)
            }
            mainHandler.postDelayed({
                wakeScreen()
                mainHandler.postDelayed({
                    executeUnlockSequence {
                        android.widget.Toast.makeText(
                            applicationContext,
                            "✓ Unlock test complete!",
                            android.widget.Toast.LENGTH_SHORT
                        ).show()
                        bringArcaneToFront()
                    }
                }, 600L)
            }, 1000L)
        }
    }

    fun bringArcaneToFront() {
        try {
            val intent = Intent(this, MainActivity::class.java).apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
                )
            }
            startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to bring Arcane to front", e)
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
                if (node.childCount > 0 && (rect.width() > (dm.widthPixels * 0.4f) || rect.height() > (dm.heightPixels * 0.15f))) {
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
            val delayMs = getMicClickDelay(this)
            Log.i(TAG, "Window changed for $pendingAuto. Waiting $delayMs ms for watch/Bluetooth mic ready before auto-tap...")
            mainHandler.postDelayed({
                executeRecordedTap(pendingAuto)
            }, delayMs)
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
            if (w > 0 && h > 0 && w < (dm.widthPixels * 0.95f) && h < (dm.heightPixels * 0.7f)) {
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
        val am = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        val alreadyRecording = try { am?.activeRecordingConfigurations?.isNotEmpty() == true } catch (_: Exception) { false }
        if (alreadyRecording) {
            Log.i(TAG, "executeRecordedTap skipped for $pkg: app is already actively recording audio!")
            lastAutoTapAt[pkg] = SystemClock.elapsedRealtime()
            return
        }

        lastAutoTapAt[pkg] = SystemClock.elapsedRealtime()
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

    override fun onKeyEvent(event: KeyEvent): Boolean {
        if (InputReplyManager.instance?.isRecordingActive() == true) {
            InputReplyManager.instance?.handleKeyEvent(event)
        }
        return super.onKeyEvent(event)
    }

    override fun onInterrupt() {}
}
