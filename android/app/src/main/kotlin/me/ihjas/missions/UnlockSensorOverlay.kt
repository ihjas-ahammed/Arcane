package me.ihjas.missions

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.annotation.SuppressLint
import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.RectF
import android.graphics.Typeface
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * Transparent lock screen touch sensor and gesture calibration overlay for Arcane.
 * Drawn by [LauncherTakeoverService] with FLAG_SHOW_WHEN_LOCKED over the system Keyguard.
 *
 * Calibration Workflow:
 * 1. Screen is locked programmatically via [AccessibilityService.GLOBAL_ACTION_LOCK_SCREEN].
 * 2. Screen is awakened with a wake lock.
 * 3. This overlay intercepts the operator's unlock motion (e.g. swipe up) and dispatches it
 *    directly through to the underlying keyguard so the device responds and unlocks.
 * 4. Listens for [Intent.ACTION_USER_PRESENT] and Keyguard dismissal.
 * 5. As soon as the screen is unlocked, saves the recorded unlock gesture to SharedPreferences.
 */
class UnlockSensorOverlay(private val service: AccessibilityService) {

    companion object {
        private const val TAG = "UnlockSensorOverlay"
        private const val BG_BANNER = 0xEE090E17.toInt()
        private const val CYAN_ACCENT = 0xFF00F0FF.toInt()
        private const val GREEN_SUCCESS = 0xFF00FF88.toInt()
        private const val TEXT_WHITE = 0xFFF0F4FA.toInt()
        private const val TEXT_MUTED = 0xFF8A99AD.toInt()
        private const val RED_CANCEL = 0xFFFF3355.toInt()
    }

    private val wm = service.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val km = service.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
    private val handler = Handler(Looper.getMainLooper())
    private val density = service.resources.displayMetrics.density
    private fun dp(v: Float) = (v * density).roundToInt()

    private var sensorView: SensorView? = null
    private var windowParams: WindowManager.LayoutParams? = null
    private var isReceiverRegistered = false
    private var isPolling = false

    // Candidate gesture variables (normalized 0.0 .. 1.0 ratios)
    var candidateStartX: Float = 0.5f
    var candidateStartY: Float = 0.85f
    var candidateEndX: Float = 0.5f
    var candidateEndY: Float = 0.20f
    var candidateDuration: Long = 300L
    private var hasRecordedMotion: Boolean = false

    var onUnlockSaved: ((startX: Float, startY: Float, endX: Float, endY: Float, duration: Long) -> Unit)? = null
    var onCancelled: (() -> Unit)? = null

    private val userPresentReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == Intent.ACTION_USER_PRESENT) {
                Log.i(TAG, "ACTION_USER_PRESENT received during calibration!")
                handleUnlockDetected()
            }
        }
    }

    private val keyguardPoller = object : Runnable {
        override fun run() {
            if (!isPolling) return
            val locked = km?.isKeyguardLocked == true || km?.isDeviceLocked == true
            if (!locked) {
                Log.i(TAG, "Keyguard unlocked detected via polling!")
                handleUnlockDetected()
                return
            }
            handler.postDelayed(this, 350L)
        }
    }

    private val timeoutRunnable = Runnable {
        if (sensorView != null) {
            Log.w(TAG, "Unlock calibration timed out after 45 seconds")
            cancelCalibration("Calibration timed out.")
        }
    }

    fun show() {
        handler.post {
            ensureShown()
            registerReceiver()
            startPolling()
            handler.removeCallbacks(timeoutRunnable)
            handler.postDelayed(timeoutRunnable, 45_000L)
        }
    }

    fun hide() {
        handler.removeCallbacks(timeoutRunnable)
        stopPolling()
        unregisterReceiver()
        sensorView?.let {
            try { wm.removeView(it) } catch (_: Exception) {}
        }
        sensorView = null
        windowParams = null
    }

    private fun registerReceiver() {
        if (!isReceiverRegistered) {
            try {
                val filter = IntentFilter(Intent.ACTION_USER_PRESENT)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    service.registerReceiver(userPresentReceiver, filter, Context.RECEIVER_EXPORTED)
                } else {
                    service.registerReceiver(userPresentReceiver, filter)
                }
                isReceiverRegistered = true
            } catch (e: Exception) {
                Log.e(TAG, "Error registering userPresentReceiver", e)
            }
        }
    }

    private fun unregisterReceiver() {
        if (isReceiverRegistered) {
            try {
                service.unregisterReceiver(userPresentReceiver)
            } catch (_: Exception) {}
            isReceiverRegistered = false
        }
    }

    private fun startPolling() {
        isPolling = true
        handler.postDelayed(keyguardPoller, 500L)
    }

    private fun stopPolling() {
        isPolling = false
        handler.removeCallbacks(keyguardPoller)
    }

    private fun overlayType(): Int {
        val prefs = service.getSharedPreferences("arcane_auto_tap", Context.MODE_PRIVATE)
        val preferred = prefs.getString("overlay_window_type", "auto") ?: "auto"
        if (preferred == "application" && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && Settings.canDrawOverlays(service)) {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }
        }
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
    }

    @Suppress("DEPRECATION")
    private fun ensureShown() {
        if (sensorView != null) return

        val view = SensorView(service)
        val p = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            overlayType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
        }

        try {
            wm.addView(view, p)
            sensorView = view
            windowParams = p
        } catch (e: Exception) {
            Log.e(TAG, "Error adding UnlockSensorOverlay", e)
        }
    }

    fun setTouchable(touchable: Boolean) {
        val view = sensorView ?: return
        val p = windowParams ?: return
        if (touchable) {
            p.flags = p.flags and WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE.inv()
        } else {
            p.flags = p.flags or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
        }
        try {
            wm.updateViewLayout(view, p)
        } catch (_: Exception) {}
    }

    private fun cancelCalibration(reason: String = "Calibration cancelled") {
        hide()
        onCancelled?.invoke()
        handler.post {
            android.widget.Toast.makeText(service.applicationContext, reason, android.widget.Toast.LENGTH_SHORT).show()
        }
    }

    private fun handleUnlockDetected() {
        hide()
        // Save recorded unlock gesture to SharedPreferences
        LauncherTakeoverService.saveUnlockGesture(
            service,
            candidateStartX,
            candidateStartY,
            candidateEndX,
            candidateEndY,
            candidateDuration
        )

        val fromPct = (candidateStartY * 100).toInt()
        val toPct = (candidateEndY * 100).toInt()
        handler.post {
            try {
                android.widget.Toast.makeText(
                    service.applicationContext,
                    "✓ Screen unlock gesture recorded ($fromPct% → $toPct%)!",
                    android.widget.Toast.LENGTH_LONG
                ).show()
            } catch (_: Exception) {}
        }

        onUnlockSaved?.invoke(candidateStartX, candidateStartY, candidateEndX, candidateEndY, candidateDuration)
    }

    @SuppressLint("ViewConstructor")
    private inner class SensorView(ctx: Context) : View(ctx) {

        private val bannerBgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = BG_BANNER
        }

        private val bannerBorderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = dp(1.4f).toFloat()
            color = CYAN_ACCENT
        }

        private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = Typeface.MONOSPACE
            textSize = dp(11f).toFloat()
            color = TEXT_WHITE
            isFakeBoldText = true
            textAlign = Paint.Align.CENTER
        }

        private val subTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = Typeface.MONOSPACE
            textSize = dp(9.5f).toFloat()
            color = TEXT_MUTED
            isFakeBoldText = true
            textAlign = Paint.Align.CENTER
        }

        private val cancelTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = Typeface.MONOSPACE
            textSize = dp(10f).toFloat()
            color = RED_CANCEL
            isFakeBoldText = true
            textAlign = Paint.Align.CENTER
        }

        private val gestureTrailPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = dp(3.5f).toFloat()
            color = CYAN_ACCENT
            strokeCap = Paint.Cap.ROUND
        }

        private val arrowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL_AND_STROKE
            strokeWidth = dp(2f).toFloat()
            color = GREEN_SUCCESS
        }

        private val cancelBtnRect = RectF()
        private var initialDownX = -1f
        private var initialDownY = -1f
        private var currentX = -1f
        private var currentY = -1f
        private var startTime = 0L
        private var isDragging = false

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            val w = width.toFloat()

            // Tactical instruction banner at the top
            val bannerH = dp(76f).toFloat()
            val bannerTop = dp(42f).toFloat()
            val bannerRect = RectF(dp(16f).toFloat(), bannerTop, w - dp(16f), bannerTop + bannerH)
            canvas.drawRoundRect(bannerRect, dp(8f).toFloat(), dp(8f).toFloat(), bannerBgPaint)
            canvas.drawRoundRect(bannerRect, dp(8f).toFloat(), dp(8f).toFloat(), bannerBorderPaint)

            canvas.drawText(
                "ARCANE // UNLOCK GESTURE CALIBRATION",
                bannerRect.centerX(),
                bannerTop + dp(22f),
                textPaint
            )

            canvas.drawText(
                "SWIPE UP TO UNLOCK SCREEN NORMALLY",
                bannerRect.centerX(),
                bannerTop + dp(38f),
                subTextPaint
            )

            // Cancel button
            val cancelW = dp(84f).toFloat()
            val cancelH = dp(22f).toFloat()
            cancelBtnRect.set(
                bannerRect.centerX() - cancelW / 2,
                bannerTop + dp(46f),
                bannerRect.centerX() + cancelW / 2,
                bannerTop + dp(46f) + cancelH
            )
            canvas.drawText("[✕ CANCEL]", cancelBtnRect.centerX(), cancelBtnRect.centerY() + dp(3f), cancelTextPaint)

            // Live gesture drag trail
            if (isDragging && initialDownX > 0 && initialDownY > 0 && currentX > 0 && currentY > 0) {
                canvas.drawLine(initialDownX, initialDownY, currentX, currentY, gestureTrailPaint)
                canvas.drawCircle(initialDownX, initialDownY, dp(6f).toFloat(), gestureTrailPaint)
                canvas.drawCircle(currentX, currentY, dp(8f).toFloat(), arrowPaint)
            }
        }

        @SuppressLint("ClickableViewAccessibility")
        override fun onTouchEvent(event: MotionEvent): Boolean {
            val x = event.x
            val y = event.y

            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    if (cancelBtnRect.contains(x, y)) {
                        performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                        cancelCalibration()
                        return true
                    }
                    initialDownX = event.rawX
                    initialDownY = event.rawY
                    currentX = event.rawX
                    currentY = event.rawY
                    startTime = SystemClock.uptimeMillis()
                    isDragging = true
                    invalidate()
                    return true
                }
                MotionEvent.ACTION_MOVE -> {
                    currentX = event.rawX
                    currentY = event.rawY
                    invalidate()
                    return true
                }
                MotionEvent.ACTION_UP -> {
                    if (cancelBtnRect.contains(x, y)) {
                        performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                        cancelCalibration()
                        return true
                    }
                    val finalX = event.rawX
                    val finalY = event.rawY
                    val duration = (SystemClock.uptimeMillis() - startTime).coerceIn(150L, 800L)
                    isDragging = false
                    invalidate()

                    val dm = service.resources.displayMetrics
                    val startXRatio = if (dm.widthPixels > 0) (initialDownX / dm.widthPixels).coerceIn(0.01f, 0.99f) else 0.5f
                    val startYRatio = if (dm.heightPixels > 0) (initialDownY / dm.heightPixels).coerceIn(0.01f, 0.99f) else 0.85f
                    val endXRatio = if (dm.widthPixels > 0) (finalX / dm.widthPixels).coerceIn(0.01f, 0.99f) else 0.5f
                    val endYRatio = if (dm.heightPixels > 0) (finalY / dm.heightPixels).coerceIn(0.01f, 0.99f) else 0.20f

                    val dy = abs(finalY - initialDownY)
                    val dx = abs(finalX - initialDownX)

                    // If valid directional movement (at least 8% of screen height or width)
                    if (dy > (dm.heightPixels * 0.08f) || dx > (dm.widthPixels * 0.08f)) {
                        candidateStartX = startXRatio
                        candidateStartY = startYRatio
                        candidateEndX = endXRatio
                        candidateEndY = endYRatio
                        candidateDuration = duration
                        hasRecordedMotion = true

                        performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)

                        // Dispatch this gesture to the lock screen so the phone actually executes the unlock!
                        dispatchSwipeToLockScreen(initialDownX, initialDownY, finalX, finalY, duration)
                    }
                    return true
                }
                MotionEvent.ACTION_CANCEL -> {
                    isDragging = false
                    invalidate()
                    return true
                }
            }
            return super.onTouchEvent(event)
        }

        private fun dispatchSwipeToLockScreen(startX: Float, startY: Float, endX: Float, endY: Float, duration: Long) {
            // Temporarily step down touch interceptor so the lock screen receives the dispatched gesture cleanly
            setTouchable(false)
            val path = Path().apply {
                moveTo(startX, startY)
                lineTo(endX, endY)
            }
            val stroke = GestureDescription.StrokeDescription(path, 0L, duration)
            val gesture = GestureDescription.Builder().addStroke(stroke).build()

            try {
                service.dispatchGesture(
                    gesture,
                    object : AccessibilityService.GestureResultCallback() {
                        override fun onCompleted(gestureDescription: GestureDescription?) {
                            Log.i(TAG, "Dispatched unlock swipe to lock screen")
                            handler.postDelayed({
                                // Check if unlocked immediately
                                val locked = km?.isKeyguardLocked == true || km?.isDeviceLocked == true
                                if (!locked) {
                                    handleUnlockDetected()
                                } else {
                                    setTouchable(true)
                                }
                            }, 350L)
                        }

                        override fun onCancelled(gestureDescription: GestureDescription?) {
                            Log.w(TAG, "Dispatched unlock swipe cancelled by system")
                            handler.postDelayed({ setTouchable(true) }, 200L)
                        }
                    },
                    handler
                )
            } catch (e: Exception) {
                Log.e(TAG, "Error dispatching gesture to lock screen", e)
                setTouchable(true)
            }
        }
    }
}
