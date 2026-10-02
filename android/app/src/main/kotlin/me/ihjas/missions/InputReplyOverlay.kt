package me.ihjas.missions

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.content.Context
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
import android.provider.Settings
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * Tactical floating HUD controller and full-screen touch sensor layer for Arcane.
 * Drawn by [LauncherTakeoverService] as an accessibility overlay (TYPE_ACCESSIBILITY_OVERLAY).
 *
 * Architecture:
 *  1. TouchSensorLayer: Full-screen transparent touch interceptor that captures exact physical
 *     tap coordinates (X, Y) and directional swipes, dispatches gestures through to underlying apps,
 *     and automatically steps down (FLAG_NOT_TOUCHABLE) when the soft keyboard is open so typing
 *     is completely unimpeded.
 *  2. ControllerView: Floating HUD pill positioned over the touch sensor displaying live status,
 *     step counts, keyboard guidance suggestions ("CLOSE KEYBOARD BEFORE SUBMITTING"), and the [■ STOP] button.
 */
class InputReplyOverlay(private val service: AccessibilityService) {

    enum class Mode {
        IDLE,
        RECORDING,
        REPLAYING
    }

    companion object {
        private const val BG_DARK = 0xF2090E17.toInt()
        private const val RED_REC = 0xFFFF3355.toInt()
        private const val CYAN_ACCENT = 0xFF00F0FF.toInt()
        private const val AMBER_WARN = 0xFFFFB547.toInt()
        private const val TEXT_WHITE = 0xFFF0F4FA.toInt()
        private const val TEXT_MUTED = 0xFF8A99AD.toInt()
    }

    private val wm = service.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val handler = Handler(Looper.getMainLooper())
    private val density = service.resources.displayMetrics.density
    private fun dp(v: Float) = (v * density).roundToInt()

    private var currentMode = Mode.IDLE
    private var pillView: ControllerView? = null
    private var pillParams: WindowManager.LayoutParams? = null

    private var sensorView: TouchSensorLayer? = null
    private var sensorParams: WindowManager.LayoutParams? = null

    private var replayIndicatorView: ReplayIndicatorLayer? = null
    private var replayIndicatorParams: WindowManager.LayoutParams? = null

    var isKeyboardOpen: Boolean = false
        private set

    var onStopClicked: (() -> Unit)? = null
    var onTapCaptured: ((rawX: Float, rawY: Float) -> Unit)? = null
    var onSwipeCaptured: ((startX: Float, startY: Float, endX: Float, endY: Float) -> Unit)? = null

    var stepCount: Int = 0
        set(value) {
            field = value
            pillView?.postInvalidate()
        }

    var replayStep: Int = 0
        set(value) {
            field = value
            pillView?.postInvalidate()
        }

    var replayTotalSteps: Int = 0
        set(value) {
            field = value
            pillView?.postInvalidate()
        }

    var activePackageLabel: String = ""
        set(value) {
            field = value
            pillView?.postInvalidate()
        }

    fun showRecording(macroName: String) {
        currentMode = Mode.RECORDING
        stepCount = 0
        activePackageLabel = macroName
        isKeyboardOpen = false
        removeReplayIndicatorLayer()
        ensureShown()
    }

    fun showReplaying(current: Int, total: Int, name: String) {
        currentMode = Mode.REPLAYING
        replayStep = current
        replayTotalSteps = total
        activePackageLabel = name
        // Hide sensor during replay
        removeSensorLayer()
        ensureShown()
    }

    fun showReplayTapIndicator(x: Float, y: Float) {
        handler.post {
            replayIndicatorView?.showTap(x, y)
        }
    }

    fun setKeyboardOpen(open: Boolean) {
        if (isKeyboardOpen == open) return
        isKeyboardOpen = open
        setSensorTouchable(!open)
        pillView?.postInvalidate()
    }

    fun hide() {
        currentMode = Mode.IDLE
        isKeyboardOpen = false
        removeSensorLayer()
        removeReplayIndicatorLayer()
        pillView?.let {
            try { wm.removeView(it) } catch (_: Exception) {}
        }
        pillView = null
        pillParams = null
    }

    private fun removeSensorLayer() {
        sensorView?.let {
            try { wm.removeView(it) } catch (_: Exception) {}
        }
        sensorView = null
        sensorParams = null
    }

    private fun removeReplayIndicatorLayer() {
        replayIndicatorView?.let {
            try { wm.removeView(it) } catch (_: Exception) {}
        }
        replayIndicatorView = null
        replayIndicatorParams = null
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

    private fun ensureShown() {
        // 1. In RECORDING mode, add full-screen touch sensor layer FIRST (below pill in z-order)
        if (currentMode == Mode.RECORDING && sensorView == null) {
            val sView = TouchSensorLayer(service)
            val sParams = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                overlayType(),
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.TOP or Gravity.START
            }
            try {
                wm.addView(sView, sParams)
                sensorView = sView
                sensorParams = sParams
            } catch (_: Exception) {}
        } else if (currentMode == Mode.REPLAYING && replayIndicatorView == null) {
            val iView = ReplayIndicatorLayer(service)
            val iParams = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                overlayType(),
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.TOP or Gravity.START
            }
            try {
                wm.addView(iView, iParams)
                replayIndicatorView = iView
                replayIndicatorParams = iParams
            } catch (_: Exception) {}
        }

        // 2. Add floating HUD controller pill ON TOP of sensor layer
        if (pillView == null) {
            val view = ControllerView(service)
            val p = WindowManager.LayoutParams(
                dp(295f),
                dp(52f),
                overlayType(),
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
                y = dp(32f)
            }
            try {
                wm.addView(view, p)
                pillView = view
                pillParams = p
            } catch (_: Exception) {}
        } else {
            pillView?.postInvalidate()
        }
    }

    private fun setSensorTouchable(touchable: Boolean) {
        val sv = sensorView ?: return
        val p = sensorParams ?: return
        val currentFlags = p.flags
        val newFlags = if (touchable && !isKeyboardOpen) {
            currentFlags and WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE.inv()
        } else {
            currentFlags or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
        }
        if (currentFlags != newFlags) {
            p.flags = newFlags
            try {
                wm.updateViewLayout(sv, p)
            } catch (_: Exception) {}
        }
    }

    private fun passTapToApp(x: Float, y: Float) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return

        setSensorTouchable(false)
        val path = Path().apply { moveTo(x, y) }
        val stroke = GestureDescription.StrokeDescription(path, 0, 40L)
        val gesture = GestureDescription.Builder().addStroke(stroke).build()

        var restored = false
        val restoreTouch = {
            if (!restored) {
                restored = true
                if (!isKeyboardOpen && currentMode == Mode.RECORDING) {
                    setSensorTouchable(true)
                }
            }
        }

        handler.postDelayed({ restoreTouch() }, 220L)

        try {
            service.dispatchGesture(
                gesture,
                object : AccessibilityService.GestureResultCallback() {
                    override fun onCompleted(gestureDescription: GestureDescription?) {
                        restoreTouch()
                    }
                    override fun onCancelled(gestureDescription: GestureDescription?) {
                        restoreTouch()
                    }
                },
                handler
            )
        } catch (_: Exception) {
            restoreTouch()
        }
    }

    private fun passSwipeToApp(startX: Float, startY: Float, endX: Float, endY: Float) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return

        setSensorTouchable(false)
        val path = Path().apply {
            moveTo(startX, startY)
            lineTo(endX, endY)
        }
        val stroke = GestureDescription.StrokeDescription(path, 0, 200L)
        val gesture = GestureDescription.Builder().addStroke(stroke).build()

        var restored = false
        val restoreTouch = {
            if (!restored) {
                restored = true
                if (!isKeyboardOpen && currentMode == Mode.RECORDING) {
                    setSensorTouchable(true)
                }
            }
        }

        handler.postDelayed({ restoreTouch() }, 320L)

        try {
            service.dispatchGesture(
                gesture,
                object : AccessibilityService.GestureResultCallback() {
                    override fun onCompleted(gestureDescription: GestureDescription?) {
                        restoreTouch()
                    }
                    override fun onCancelled(gestureDescription: GestureDescription?) {
                        restoreTouch()
                    }
                },
                handler
            )
        } catch (_: Exception) {
            restoreTouch()
        }
    }

    // ── Full-Screen Touch Sensor Layer ───────────────────────────────────────
    @SuppressLint("ViewConstructor")
    private inner class TouchSensorLayer(ctx: Context) : View(ctx) {
        private var initialDownX = -1f
        private var initialDownY = -1f
        private var isDraggingOrSwiping = false
        private val touchSlop = ViewConfiguration.get(ctx).scaledTouchSlop

        // Tactical ripple feedback
        private var rippleX = -1f
        private var rippleY = -1f
        private var rippleRadius = 0f
        private var rippleAlpha = 0
        private var rippleAnimator: ValueAnimator? = null

        private val dotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = CYAN_ACCENT
        }

        private val ripplePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = dp(2f).toFloat()
            color = CYAN_ACCENT
        }

        private val reticlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = dp(1.5f).toFloat()
            color = CYAN_ACCENT
        }

        fun triggerTapFeedback(x: Float, y: Float) {
            rippleX = x
            rippleY = y
            rippleAnimator?.cancel()
            rippleAnimator = ValueAnimator.ofFloat(dp(4f).toFloat(), dp(26f).toFloat()).apply {
                duration = 200L
                addUpdateListener {
                    rippleRadius = it.animatedValue as Float
                    rippleAlpha = ((1f - it.animatedFraction) * 255).toInt().coerceIn(0, 255)
                    invalidate()
                }
                start()
            }
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            if (rippleAlpha > 0 && rippleX > 0 && rippleY > 0) {
                ripplePaint.alpha = rippleAlpha
                reticlePaint.alpha = rippleAlpha
                dotPaint.alpha = rippleAlpha

                // Tactical center dot right at touch point
                canvas.drawCircle(rippleX, rippleY, dp(2.5f).toFloat(), dotPaint)

                // Expanding ripple
                canvas.drawCircle(rippleX, rippleY, rippleRadius, ripplePaint)

                val notch = dp(5f).toFloat()
                canvas.drawLine(rippleX - rippleRadius - notch, rippleY, rippleX - rippleRadius, rippleY, reticlePaint)
                canvas.drawLine(rippleX + rippleRadius, rippleY, rippleX + rippleRadius + notch, rippleY, reticlePaint)
                canvas.drawLine(rippleX, rippleY - rippleRadius - notch, rippleX, rippleY - rippleRadius, reticlePaint)
                canvas.drawLine(rippleX, rippleY + rippleRadius, rippleX, rippleY + rippleRadius + notch, reticlePaint)
            }
        }

        @SuppressLint("ClickableViewAccessibility")
        override fun onTouchEvent(event: MotionEvent): Boolean {
            if (isKeyboardOpen || currentMode != Mode.RECORDING) {
                return false
            }

            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialDownX = event.rawX
                    initialDownY = event.rawY
                    isDraggingOrSwiping = false
                    return true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = abs(event.rawX - initialDownX)
                    val dy = abs(event.rawY - initialDownY)
                    if (dx > touchSlop || dy > touchSlop) {
                        isDraggingOrSwiping = true
                    }
                    return true
                }
                MotionEvent.ACTION_UP -> {
                    val finalX = event.rawX
                    val finalY = event.rawY
                    val dx = abs(finalX - initialDownX)
                    val dy = abs(finalY - initialDownY)

                    if (!isDraggingOrSwiping && dx <= touchSlop && dy <= touchSlop) {
                        // Direct physical tap captured via touch sensor!
                        performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                        // Trigger visual feedback in local View coordinates so it's perfectly centered on touch
                        triggerTapFeedback(event.x, event.y)
                        onTapCaptured?.invoke(finalX, finalY)
                        passTapToApp(finalX, finalY)
                    } else {
                        // Swipe / scroll captured
                        onSwipeCaptured?.invoke(initialDownX, initialDownY, finalX, finalY)
                        passSwipeToApp(initialDownX, initialDownY, finalX, finalY)
                    }
                    isDraggingOrSwiping = false
                    return true
                }
                MotionEvent.ACTION_CANCEL -> {
                    isDraggingOrSwiping = false
                    return true
                }
            }
            return super.onTouchEvent(event)
        }
    }

    // ── Full-Screen Replay Indicator Layer ──────────────────────────────────
    @SuppressLint("ViewConstructor")
    private inner class ReplayIndicatorLayer(ctx: Context) : View(ctx) {
        private var tapX = -1f
        private var tapY = -1f
        private var tapRadius = 0f
        private var tapAlpha = 0
        private var tapAnimator: ValueAnimator? = null

        private val ripplePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = dp(2.2f).toFloat()
            color = CYAN_ACCENT
        }

        private val reticlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = dp(1.8f).toFloat()
            color = CYAN_ACCENT
        }

        private val dotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = CYAN_ACCENT
        }

        fun showTap(screenX: Float, screenY: Float) {
            val loc = IntArray(2)
            getLocationOnScreen(loc)
            tapX = screenX - loc[0]
            tapY = screenY - loc[1]

            tapAnimator?.cancel()
            tapAnimator = ValueAnimator.ofFloat(dp(4f).toFloat(), dp(28f).toFloat()).apply {
                duration = 260L
                addUpdateListener {
                    tapRadius = it.animatedValue as Float
                    tapAlpha = ((1f - it.animatedFraction) * 255).toInt().coerceIn(0, 255)
                    invalidate()
                }
                start()
            }
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            if (tapAlpha > 0 && tapX > 0 && tapY > 0) {
                ripplePaint.alpha = tapAlpha
                reticlePaint.alpha = tapAlpha
                dotPaint.alpha = tapAlpha

                // Center dot at exact tap location
                canvas.drawCircle(tapX, tapY, dp(3f).toFloat(), dotPaint)

                // Expanding ripple ring
                canvas.drawCircle(tapX, tapY, tapRadius, ripplePaint)

                // Tactical crosshair notches
                val notch = dp(6f).toFloat()
                canvas.drawLine(tapX - tapRadius - notch, tapY, tapX - tapRadius, tapY, reticlePaint)
                canvas.drawLine(tapX + tapRadius, tapY, tapX + tapRadius + notch, tapY, reticlePaint)
                canvas.drawLine(tapX, tapY - tapRadius - notch, tapX, tapY - tapRadius, reticlePaint)
                canvas.drawLine(tapX, tapY + tapRadius, tapX, tapY + tapRadius + notch, reticlePaint)
            }
        }
    }

    // ── Floating HUD Controller Pill ─────────────────────────────────────────
    @SuppressLint("ViewConstructor")
    private inner class ControllerView(ctx: Context) : View(ctx) {

        private val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = BG_DARK
            style = Paint.Style.FILL
        }

        private val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = dp(1.2f).toFloat()
        }

        private val dotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
        }

        private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = Typeface.MONOSPACE
            textSize = dp(11f).toFloat()
            color = TEXT_WHITE
            isFakeBoldText = true
        }

        private val subTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = Typeface.MONOSPACE
            textSize = dp(9.5f).toFloat()
            color = TEXT_MUTED
            isFakeBoldText = true
        }

        private val tipTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = Typeface.MONOSPACE
            textSize = dp(9.5f).toFloat()
            color = AMBER_WARN
            isFakeBoldText = true
        }

        private val stopBtnPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = RED_REC
        }

        private val stopTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = Typeface.MONOSPACE
            textSize = dp(10f).toFloat()
            color = Color.WHITE
            textAlign = Paint.Align.CENTER
            isFakeBoldText = true
        }

        private var pulsePhase = 0f
        private var pulseAnim: ValueAnimator? = null
        private val stopBtnRect = RectF()

        private var initialX = 0
        private var initialY = 0
        private var initialTouchX = 0f
        private var initialTouchY = 0f
        private var isDragging = false
        private val touchSlop = ViewConfiguration.get(ctx).scaledTouchSlop

        init {
            pulseAnim = ValueAnimator.ofFloat(0f, 1f).apply {
                duration = 1000L
                repeatCount = ValueAnimator.INFINITE
                repeatMode = ValueAnimator.REVERSE
                addUpdateListener {
                    pulsePhase = it.animatedValue as Float
                    invalidate()
                }
                start()
            }
        }

        override fun onDetachedFromWindow() {
            pulseAnim?.cancel()
            super.onDetachedFromWindow()
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            val w = width.toFloat()
            val h = height.toFloat()
            val r = dp(8f).toFloat()
            val rect = RectF(
                borderPaint.strokeWidth / 2f,
                borderPaint.strokeWidth / 2f,
                w - borderPaint.strokeWidth / 2f,
                h - borderPaint.strokeWidth / 2f
            )

            // Draw background pill
            canvas.drawRoundRect(rect, r, r, bgPaint)

            // Dynamic accent border
            val accent = when {
                isKeyboardOpen -> AMBER_WARN
                currentMode == Mode.RECORDING -> RED_REC
                else -> CYAN_ACCENT
            }
            borderPaint.color = accent
            canvas.drawRoundRect(rect, r, r, borderPaint)

            // Status indicator and text
            if (currentMode == Mode.RECORDING) {
                if (isKeyboardOpen) {
                    // Soft keyboard open state: highlight tip to close keyboard before submitting
                    val alpha = ((0.5f + pulsePhase * 0.5f) * 255).toInt().coerceIn(120, 255)
                    dotPaint.color = (AMBER_WARN and 0x00FFFFFF) or (alpha shl 24)
                    canvas.drawCircle(dp(14f).toFloat(), h / 2f, dp(5f).toFloat(), dotPaint)

                    textPaint.color = AMBER_WARN
                    canvas.drawText("⌨ KEYBOARD OPEN", dp(24f).toFloat(), h / 2f - dp(2f), textPaint)

                    canvas.drawText("▼ CLOSE KEYBOARD TO SUBMIT", dp(24f).toFloat(), h / 2f + dp(12f), tipTextPaint)
                } else {
                    // Normal touch sensor active recording state
                    val alpha = ((0.5f + pulsePhase * 0.5f) * 255).toInt().coerceIn(100, 255)
                    dotPaint.color = (RED_REC and 0x00FFFFFF) or (alpha shl 24)
                    canvas.drawCircle(dp(14f).toFloat(), h / 2f, dp(5f).toFloat(), dotPaint)

                    textPaint.color = RED_REC
                    canvas.drawText("REC", dp(24f).toFloat(), h / 2f - dp(2f), textPaint)

                    subTextPaint.color = TEXT_WHITE
                    val stepLabel = "$stepCount step${if (stepCount == 1) "" else "s"}"
                    canvas.drawText(stepLabel, dp(52f).toFloat(), h / 2f - dp(2f), subTextPaint)

                    subTextPaint.color = CYAN_ACCENT
                    val displayTarget = if (activePackageLabel.isNotEmpty()) activePackageLabel else "TOUCH SENSOR"
                    val truncatedTarget = if (displayTarget.length > 18) displayTarget.take(16) + ".." else displayTarget
                    canvas.drawText("[$truncatedTarget]", dp(24f).toFloat(), h / 2f + dp(12f), subTextPaint)
                }
            } else if (currentMode == Mode.REPLAYING) {
                dotPaint.color = CYAN_ACCENT
                canvas.drawCircle(dp(14f).toFloat(), h / 2f, dp(5f).toFloat(), dotPaint)

                textPaint.color = CYAN_ACCENT
                canvas.drawText("PLAY", dp(24f).toFloat(), h / 2f - dp(2f), textPaint)

                subTextPaint.color = TEXT_WHITE
                val stepLabel = "$replayStep/$replayTotalSteps"
                canvas.drawText(stepLabel, dp(60f).toFloat(), h / 2f - dp(2f), subTextPaint)

                subTextPaint.color = TEXT_MUTED
                canvas.drawText("[REPLAYING]", dp(24f).toFloat(), h / 2f + dp(12f), subTextPaint)
            }

            // Draw [■ STOP] button on right side
            val btnW = dp(62f).toFloat()
            val btnH = dp(32f).toFloat()
            val btnLeft = w - btnW - dp(10f)
            val btnTop = (h - btnH) / 2f
            stopBtnRect.set(btnLeft, btnTop, btnLeft + btnW, btnTop + btnH)

            stopBtnPaint.color = if (currentMode == Mode.RECORDING) RED_REC else AMBER_WARN
            canvas.drawRoundRect(stopBtnRect, dp(6f).toFloat(), dp(6f).toFloat(), stopBtnPaint)
            canvas.drawText("■ STOP", stopBtnRect.centerX(), stopBtnRect.centerY() + dp(3.5f), stopTextPaint)
        }

        @SuppressLint("ClickableViewAccessibility")
        override fun onTouchEvent(event: MotionEvent): Boolean {
            val p = pillParams ?: return super.onTouchEvent(event)

            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = p.x
                    initialY = p.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    isDragging = false

                    if (stopBtnRect.contains(event.x, event.y)) {
                        performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                        onStopClicked?.invoke()
                        return true
                    }
                    return true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - initialTouchX).toInt()
                    val dy = (event.rawY - initialTouchY).toInt()

                    if (!isDragging && (abs(dx) > touchSlop || abs(dy) > touchSlop)) {
                        isDragging = true
                    }

                    if (isDragging) {
                        p.x = initialX + dx
                        p.y = initialY + dy
                        try { wm.updateViewLayout(this, p) } catch (_: Exception) {}
                    }
                    return true
                }
                MotionEvent.ACTION_UP -> {
                    if (!isDragging && stopBtnRect.contains(event.x, event.y)) {
                        performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                        onStopClicked?.invoke()
                    }
                    isDragging = false
                    return true
                }
            }
            return super.onTouchEvent(event)
        }
    }
}
