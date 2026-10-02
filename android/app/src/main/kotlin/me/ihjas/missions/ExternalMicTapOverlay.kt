package me.ihjas.missions

import android.accessibilityservice.AccessibilityService
import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
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
 * Floating HUD bar for recording and calibrating the voice/mic button tap in external AI applications.
 *
 * Drawn by [LauncherTakeoverService] as an accessibility overlay (TYPE_ACCESSIBILITY_OVERLAY).
 * Floats draggable over any app (ChatGPT, Claude, Copilot, Perplexity, Gemini, etc.).
 *
 * Features:
 *  - Displays live calibration status and target package.
 *  - Dynamically updates as the user taps inside the app, displaying the captured candidate.
 *  - Explicit [■ SAVE] button to store the calibrated mic button.
 *  - [✕] Cancel button to abort without saving.
 */
class ExternalMicTapOverlay(private val service: AccessibilityService) {

    companion object {
        private const val BG_DARK = 0xF2090E17.toInt()
        private const val AMBER_WARN = 0xFFFFB547.toInt()
        private const val GREEN_SUCCESS = 0xFF00E676.toInt()
        private const val CYAN_ACCENT = 0xFF00F0FF.toInt()
        private const val TEXT_WHITE = 0xFFF0F4FA.toInt()
        private const val TEXT_MUTED = 0xFF8A99AD.toInt()
    }

    private val wm = service.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val handler = Handler(Looper.getMainLooper())
    private val density = service.resources.displayMetrics.density
    private fun dp(v: Float) = (v * density).roundToInt()

    private var pillView: ControllerView? = null
    private var params: WindowManager.LayoutParams? = null

    var onSave: (() -> Unit)? = null
    var onCancel: (() -> Unit)? = null

    var targetPackageName: String = ""
        private set

    var candidateDesc: String? = null
        private set
    var candidateId: String? = null
        private set
    var candidateText: String? = null
        private set
    var candidateXRatio: Float = 0.5f
        private set
    var candidateYRatio: Float = 0.5f
        private set
    var hasCandidate: Boolean = false
        private set

    fun show(packageName: String) {
        targetPackageName = packageName
        hasCandidate = false
        candidateDesc = null
        candidateId = null
        candidateText = null
        candidateXRatio = 0.5f
        candidateYRatio = 0.5f
        ensureShown()
    }

    fun updateCandidate(desc: String?, viewId: String?, text: String?, xRatio: Float, yRatio: Float) {
        hasCandidate = true
        candidateDesc = desc
        candidateId = viewId
        candidateText = text
        candidateXRatio = xRatio
        candidateYRatio = yRatio
        pillView?.postInvalidate()
    }

    fun hide() {
        pillView?.let {
            try { wm.removeView(it) } catch (_: Exception) {}
        }
        pillView = null
        params = null
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
        if (pillView != null) {
            pillView?.postInvalidate()
            return
        }

        val view = ControllerView(service)
        val p = WindowManager.LayoutParams(
            dp(270f),
            dp(52f),
            overlayType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            y = dp(40f)
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
            textSize = dp(10.5f).toFloat()
            color = TEXT_WHITE
        }

        private val subTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = Typeface.MONOSPACE
            textSize = dp(9f).toFloat()
            color = TEXT_MUTED
        }

        private val saveBtnPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
        }

        private val saveBtnTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = Typeface.MONOSPACE
            textSize = dp(10f).toFloat()
            color = Color.BLACK
            textAlign = Paint.Align.CENTER
            isFakeBoldText = true
        }

        private val cancelBtnPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = 0x33FFFFFF
        }

        private val cancelTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = Typeface.MONOSPACE
            textSize = dp(11f).toFloat()
            color = Color.WHITE
            textAlign = Paint.Align.CENTER
        }

        private var pulsePhase = 0f
        private var pulseAnim: ValueAnimator? = null
        private val saveBtnRect = RectF()
        private val cancelBtnRect = RectF()

        private var initialX = 0
        private var initialY = 0
        private var initialTouchX = 0f
        private var initialTouchY = 0f
        private var isDragging = false
        private val touchSlop = ViewConfiguration.get(ctx).scaledTouchSlop

        init {
            pulseAnim = ValueAnimator.ofFloat(0f, 1f).apply {
                duration = 900L
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
            val rect = RectF(
                borderPaint.strokeWidth / 2f,
                borderPaint.strokeWidth / 2f,
                w - borderPaint.strokeWidth / 2f,
                h - borderPaint.strokeWidth / 2f
            )

            // Draw background pill
            canvas.drawRoundRect(rect, r, r, bgPaint)

            // Border color: Green if candidate captured, Amber otherwise
            val activeAccent = if (hasCandidate) GREEN_SUCCESS else AMBER_WARN
            borderPaint.color = activeAccent
            canvas.drawRoundRect(rect, r, r, borderPaint)

            // Pulsating indicator dot
            val dotAlpha = ((0.4f + pulsePhase * 0.6f) * 255).toInt().coerceIn(100, 255)
            dotPaint.color = (activeAccent and 0x00FFFFFF) or (dotAlpha shl 24)
            canvas.drawCircle(dp(16f).toFloat(), h / 2f, dp(5f).toFloat(), dotPaint)

            // Title: MIC-TAP CALIBRATION
            textPaint.color = activeAccent
            canvas.drawText("MIC CALIBRATION", dp(28f).toFloat(), h / 2f - dp(3f), textPaint)

            // Subtitle: Tap Candidate or Prompt
            if (hasCandidate) {
                val tag = candidateDesc ?: candidateText ?: candidateId?.substringAfterLast('/')
                val candidateLabel = if (!tag.isNullOrEmpty()) {
                    "✓ Touch ${(candidateXRatio * 100).toInt()}%,${(candidateYRatio * 100).toInt()}% ($tag)"
                } else {
                    "✓ Touch (${(candidateXRatio * 100).toInt()}%, ${(candidateYRatio * 100).toInt()}%)"
                }
                val truncated = if (candidateLabel.length > 22) candidateLabel.take(20) + ".." else candidateLabel
                subTextPaint.color = TEXT_WHITE
                canvas.drawText(truncated, dp(28f).toFloat(), h / 2f + dp(11f), subTextPaint)
            } else {
                subTextPaint.color = TEXT_MUTED
                canvas.drawText("Tap mic on screen...", dp(28f).toFloat(), h / 2f + dp(11f), subTextPaint)
            }

            // Buttons layout on right side
            val btnH = dp(32f).toFloat()
            val saveBtnW = dp(58f).toFloat()
            val cancelBtnW = dp(28f).toFloat()
            val rightMargin = dp(8f).toFloat()

            // [✕] Cancel button
            val cancelLeft = w - rightMargin - cancelBtnW
            val cancelTop = (h - btnH) / 2f
            cancelBtnRect.set(cancelLeft, cancelTop, cancelLeft + cancelBtnW, cancelTop + btnH)
            canvas.drawRoundRect(cancelBtnRect, dp(6f).toFloat(), dp(6f).toFloat(), cancelBtnPaint)
            canvas.drawText("✕", cancelBtnRect.centerX(), cancelBtnRect.centerY() + dp(4f), cancelTextPaint)

            // [■ SAVE] button
            val saveLeft = cancelLeft - saveBtnW - dp(6f)
            val saveTop = (h - btnH) / 2f
            saveBtnRect.set(saveLeft, saveTop, saveLeft + saveBtnW, saveTop + btnH)

            saveBtnPaint.color = if (hasCandidate) GREEN_SUCCESS else AMBER_WARN
            canvas.drawRoundRect(saveBtnRect, dp(6f).toFloat(), dp(6f).toFloat(), saveBtnPaint)
            canvas.drawText("SAVE", saveBtnRect.centerX(), saveBtnRect.centerY() + dp(3.5f), saveBtnTextPaint)
        }

        @SuppressLint("ClickableViewAccessibility")
        override fun onTouchEvent(event: MotionEvent): Boolean {
            val p = params ?: return super.onTouchEvent(event)

            when (event.action) {
                MotionEvent.ACTION_OUTSIDE -> {
                    val rx = event.rawX
                    val ry = event.rawY
                    if (rx > 0 && ry > 0) {
                        val dm = service.resources.displayMetrics
                        val xr = (rx / dm.widthPixels).coerceIn(0.01f, 0.99f)
                        val yr = (ry / dm.heightPixels).coerceIn(0.01f, 0.99f)
                        updateCandidate(null, null, null, xr, yr)
                    }
                    return false
                }
                MotionEvent.ACTION_DOWN -> {
                    initialX = p.x
                    initialY = p.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    isDragging = false

                    if (saveBtnRect.contains(event.x, event.y)) {
                        performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                        onSave?.invoke()
                        return true
                    }
                    if (cancelBtnRect.contains(event.x, event.y)) {
                        performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                        onCancel?.invoke()
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
                    if (!isDragging) {
                        if (saveBtnRect.contains(event.x, event.y)) {
                            performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                            onSave?.invoke()
                        } else if (cancelBtnRect.contains(event.x, event.y)) {
                            performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                            onCancel?.invoke()
                        }
                    }
                    isDragging = false
                    return true
                }
            }
            return super.onTouchEvent(event)
        }
    }
}
