package me.ihjas.missions

import android.accessibilityservice.AccessibilityService
import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Typeface
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * Tactical floating HUD controller for device-wide input recording and replaying.
 * Drawn by [LauncherTakeoverService] as an accessibility overlay (TYPE_ACCESSIBILITY_OVERLAY).
 *
 * Supports two dynamic modes:
 *  1. RECORDING: Glowing pulsating red disc with live step counter and [■ STOP] trigger.
 *  2. REPLAYING: Tactical cyan HUD indicator showing active step execution and emergency [■ STOP] abort.
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
    private var params: WindowManager.LayoutParams? = null

    var onStopClicked: (() -> Unit)? = null

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
        ensureShown()
    }

    fun showReplaying(current: Int, total: Int, name: String) {
        currentMode = Mode.REPLAYING
        replayStep = current
        replayTotalSteps = total
        activePackageLabel = name
        ensureShown()
    }

    fun hide() {
        currentMode = Mode.IDLE
        pillView?.let {
            try { wm.removeView(it) } catch (_: Exception) {}
        }
        pillView = null
        params = null
    }

    private fun overlayType(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

    private fun ensureShown() {
        if (pillView != null) {
            pillView?.postInvalidate()
            return
        }

        val view = ControllerView(service)
        val p = WindowManager.LayoutParams(
            dp(220f),
            dp(48f),
            overlayType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            y = dp(32f)
        }

        try {
            wm.addView(view, p)
            pillView = view
            params = p
        } catch (_: Exception) {}
    }

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
        }

        private val subTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = Typeface.MONOSPACE
            textSize = dp(9f).toFloat()
            color = TEXT_MUTED
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
            val r = h / 2f
            val rect = RectF(borderPaint.strokeWidth / 2f, borderPaint.strokeWidth / 2f, w - borderPaint.strokeWidth / 2f, h - borderPaint.strokeWidth / 2f)

            // Draw background pill
            canvas.drawRoundRect(rect, r, r, bgPaint)

            // Dynamic accent border
            val accent = if (currentMode == Mode.RECORDING) RED_REC else CYAN_ACCENT
            borderPaint.color = accent
            canvas.drawRoundRect(rect, r, r, borderPaint)

            // Draw status indicator
            if (currentMode == Mode.RECORDING) {
                // Pulsating red recording dot
                val alpha = ((0.5f + pulsePhase * 0.5f) * 255).toInt().coerceIn(100, 255)
                dotPaint.color = (RED_REC and 0x00FFFFFF) or (alpha shl 24)
                canvas.drawCircle(dp(16f).toFloat(), h / 2f, dp(5f).toFloat(), dotPaint)

                // Recording label
                textPaint.color = RED_REC
                canvas.drawText("REC", dp(28f).toFloat(), h / 2f - dp(1f), textPaint)

                // Step count telemetry
                subTextPaint.color = TEXT_WHITE
                val stepLabel = "$stepCount step${if (stepCount == 1) "" else "s"}"
                canvas.drawText(stepLabel, dp(58f).toFloat(), h / 2f - dp(1f), subTextPaint)

                // Subtitle / target
                val displayTarget = if (activePackageLabel.isNotEmpty()) activePackageLabel else "DEVICE"
                val truncatedTarget = if (displayTarget.length > 12) displayTarget.take(10) + ".." else displayTarget
                subTextPaint.color = TEXT_MUTED
                canvas.drawText("[$truncatedTarget]", dp(28f).toFloat(), h / 2f + dp(12f), subTextPaint)
            } else if (currentMode == Mode.REPLAYING) {
                // Cyan playback dot
                dotPaint.color = CYAN_ACCENT
                canvas.drawCircle(dp(16f).toFloat(), h / 2f, dp(5f).toFloat(), dotPaint)

                textPaint.color = CYAN_ACCENT
                canvas.drawText("PLAY", dp(28f).toFloat(), h / 2f - dp(1f), textPaint)

                subTextPaint.color = TEXT_WHITE
                val stepLabel = "$replayStep/$replayTotalSteps"
                canvas.drawText(stepLabel, dp(64f).toFloat(), h / 2f - dp(1f), subTextPaint)

                subTextPaint.color = TEXT_MUTED
                canvas.drawText("[REPLAYING]", dp(28f).toFloat(), h / 2f + dp(12f), subTextPaint)
            }

            // Draw [■ STOP] button on right side
            val btnW = dp(62f).toFloat()
            val btnH = dp(30f).toFloat()
            val btnLeft = w - btnW - dp(10f)
            val btnTop = (h - btnH) / 2f
            stopBtnRect.set(btnLeft, btnTop, btnLeft + btnW, btnTop + btnH)

            stopBtnPaint.color = if (currentMode == Mode.RECORDING) RED_REC else AMBER_WARN
            canvas.drawRoundRect(stopBtnRect, dp(6f).toFloat(), dp(6f).toFloat(), stopBtnPaint)
            canvas.drawText("■ STOP", stopBtnRect.centerX(), stopBtnRect.centerY() + dp(3.5f), stopTextPaint)
        }

        @SuppressLint("ClickableViewAccessibility")
        override fun onTouchEvent(event: MotionEvent): Boolean {
            val p = params ?: return super.onTouchEvent(event)

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
