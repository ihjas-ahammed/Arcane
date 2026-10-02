package me.ihjas.missions

import android.accessibilityservice.AccessibilityService
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
import android.view.WindowManager
import kotlin.math.roundToInt

/**
 * Transparent full-screen touch sensor overlay for one-tap calibration of mic coordinates.
 *
 * Captures direct finger touch down coordinates (X, Y) without requiring the target app
 * to dispatch accessibility events or declare clickable accessibility nodes.
 */
class TouchSensorOverlay(private val service: AccessibilityService) {

    companion object {
        private const val BG_BANNER = 0xEE090E17.toInt()
        private const val CYAN_ACCENT = 0xFF00F0FF.toInt()
        private const val TEXT_WHITE = 0xFFF0F4FA.toInt()
        private const val RED_CANCEL = 0xFFFF3355.toInt()
    }

    private val wm = service.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val density = service.resources.displayMetrics.density
    private fun dp(v: Float) = (v * density).roundToInt()

    private var sensorView: SensorView? = null

    var onTouchCaptured: ((xRatio: Float, yRatio: Float) -> Unit)? = null
    var onCancelled: (() -> Unit)? = null

    var targetPackageName: String = ""
        private set

    fun show(packageName: String) {
        targetPackageName = packageName
        ensureShown()
    }

    fun hide() {
        sensorView?.let {
            try { wm.removeView(it) } catch (_: Exception) {}
        }
        sensorView = null
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
        if (sensorView != null) return

        val view = SensorView(service)
        val p = WindowManager.LayoutParams(
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
            wm.addView(view, p)
            sensorView = view
        } catch (_: Exception) {}
    }

    @SuppressLint("ViewConstructor")
    private inner class SensorView(ctx: Context) : View(ctx) {

        private val bannerBgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = BG_BANNER
        }

        private val bannerBorderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = dp(1.2f).toFloat()
            color = CYAN_ACCENT
        }

        private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = Typeface.MONOSPACE
            textSize = dp(11f).toFloat()
            color = TEXT_WHITE
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

        private val cancelBtnRect = RectF()
        private var initialDownX = -1f
        private var initialDownY = -1f

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            val w = width.toFloat()

            // Tactical instruction banner at the top
            val bannerH = dp(60f).toFloat()
            val bannerTop = dp(40f).toFloat()
            val bannerRect = RectF(dp(16f).toFloat(), bannerTop, w - dp(16f), bannerTop + bannerH)
            canvas.drawRoundRect(bannerRect, dp(8f).toFloat(), dp(8f).toFloat(), bannerBgPaint)
            canvas.drawRoundRect(bannerRect, dp(8f).toFloat(), dp(8f).toFloat(), bannerBorderPaint)

            canvas.drawText("TOUCH SENSOR: TAP MIC BUTTON ONCE", bannerRect.centerX(), bannerTop + dp(24f), textPaint)

            // Cancel button
            val cancelW = dp(80f).toFloat()
            val cancelH = dp(20f).toFloat()
            cancelBtnRect.set(bannerRect.centerX() - cancelW / 2, bannerTop + dp(32f), bannerRect.centerX() + cancelW / 2, bannerTop + dp(32f) + cancelH)
            canvas.drawText("[✕ CANCEL]", cancelBtnRect.centerX(), cancelBtnRect.centerY() + dp(3f), cancelTextPaint)
        }

        @SuppressLint("ClickableViewAccessibility")
        override fun onTouchEvent(event: MotionEvent): Boolean {
            val x = event.x
            val y = event.y

            if (event.action == MotionEvent.ACTION_DOWN) {
                initialDownX = event.rawX
                initialDownY = event.rawY

                // If tapped cancel button
                if (cancelBtnRect.contains(x, y)) {
                    performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                    onCancelled?.invoke()
                    hide()
                    return true
                }
                return true
            }

            if (event.action == MotionEvent.ACTION_UP) {
                // If tapped cancel button
                if (cancelBtnRect.contains(x, y)) {
                    performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                    onCancelled?.invoke()
                    hide()
                    return true
                }

                // Verify it was a direct tap and not a swipe/drag
                val dx = kotlin.math.abs(event.rawX - initialDownX)
                val dy = kotlin.math.abs(event.rawY - initialDownY)
                if (dx > dp(25f) || dy > dp(25f)) {
                    // Finger was dragged/swiped, ignore swipe gesture
                    return true
                }

                performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
                val dm = service.resources.displayMetrics
                val rawX = event.rawX
                val rawY = event.rawY
                val xRatio = if (dm.widthPixels > 0) (rawX / dm.widthPixels).coerceIn(0.01f, 0.99f) else 0.5f
                val yRatio = if (dm.heightPixels > 0) (rawY / dm.heightPixels).coerceIn(0.01f, 0.99f) else 0.85f

                onTouchCaptured?.invoke(xRatio, yRatio)
                hide()
                return true
            }
            return super.onTouchEvent(event)
        }
    }
}
