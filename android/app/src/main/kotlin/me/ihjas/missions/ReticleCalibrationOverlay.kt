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
import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * Tactical draggable screen reticle overlay for calibrating the mic button tap.
 *
 * Provides a foolproof, non-intrusive target crosshair that operators can drag directly
 * over the target app's microphone/voice switch.
 *
 * Solves overdraw and touch-filter prevention:
 *  - Doesn't rely on the target app dispatching accessibility click events.
 *  - Works across Flutter, React Native, Jetpack Compose, WebViews, and Native UIs.
 *  - Lets operators visually align the crosshair reticle with 100% pixel precision.
 */
class ReticleCalibrationOverlay(private val service: AccessibilityService) {

    companion object {
        private const val BG_DARK = 0xF2090E17.toInt()
        private const val CYAN_ACCENT = 0xFF00F0FF.toInt()
        private const val GREEN_SUCCESS = 0xFF00E676.toInt()
        private const val RED_CANCEL = 0xFFFF3355.toInt()
        private const val TEXT_WHITE = 0xFFF0F4FA.toInt()
    }

    private val wm = service.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val handler = Handler(Looper.getMainLooper())
    private val density = service.resources.displayMetrics.density
    private fun dp(v: Float) = (v * density).roundToInt()

    private var reticleView: ReticleView? = null
    private var params: WindowManager.LayoutParams? = null

    var onSaved: ((xRatio: Float, yRatio: Float) -> Unit)? = null
    var onCancelled: (() -> Unit)? = null

    var targetPackageName: String = ""
        private set

    fun show(packageName: String) {
        targetPackageName = packageName
        ensureShown()
    }

    fun hide() {
        reticleView?.let {
            try { wm.removeView(it) } catch (_: Exception) {}
        }
        reticleView = null
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
        if (reticleView != null) {
            reticleView?.postInvalidate()
            return
        }

        val dm = service.resources.displayMetrics
        val view = ReticleView(service)
        val p = WindowManager.LayoutParams(
            dp(240f),
            dp(130f),
            overlayType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = ((dm.widthPixels - dp(240f)) / 2).coerceAtLeast(0)
            y = (dm.heightPixels * 0.70f).roundToInt()
        }

        try {
            wm.addView(view, p)
            reticleView = view
            params = p
        } catch (_: Exception) {}
    }

    @SuppressLint("ViewConstructor")
    private inner class ReticleView(ctx: Context) : View(ctx) {

        private val ringPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = dp(2f).toFloat()
            color = CYAN_ACCENT
        }

        private val crosshairPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = dp(1.5f).toFloat()
            color = CYAN_ACCENT
        }

        private val centerDotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = CYAN_ACCENT
        }

        private val cardBgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = BG_DARK
        }

        private val cardBorderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = dp(1.2f).toFloat()
            color = CYAN_ACCENT
        }

        private val btnLockPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = GREEN_SUCCESS
        }

        private val btnCancelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = RED_CANCEL
        }

        private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = Typeface.MONOSPACE
            textSize = dp(10f).toFloat()
            color = TEXT_WHITE
            isFakeBoldText = true
        }

        private val btnTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = Typeface.MONOSPACE
            textSize = dp(9.5f).toFloat()
            color = Color.BLACK
            isFakeBoldText = true
            textAlign = Paint.Align.CENTER
        }

        private var touchStartX = 0f
        private var touchStartY = 0f
        private var initialWindowX = 0
        private var initialWindowY = 0
        private var isDragging = false

        private val lockBtnRect = RectF()
        private val cancelBtnRect = RectF()

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            val w = width.toFloat()
            val h = height.toFloat()

            // 1. Draw draggable top control HUD card
            val cardH = dp(50f).toFloat()
            val cardRect = RectF(0f, 0f, w, cardH)
            canvas.drawRoundRect(cardRect, dp(8f).toFloat(), dp(8f).toFloat(), cardBgPaint)
            canvas.drawRoundRect(cardRect, dp(8f).toFloat(), dp(8f).toFloat(), cardBorderPaint)

            // Header label
            val label = "DRAG TARGET TO MIC"
            canvas.drawText(label, dp(10f).toFloat(), dp(18f).toFloat(), textPaint)

            // Lock Target Button
            val btnW = dp(94f).toFloat()
            val btnH = dp(24f).toFloat()
            val btnY = dp(22f).toFloat()
            lockBtnRect.set(dp(8f).toFloat(), btnY, dp(8f).toFloat() + btnW, btnY + btnH)
            canvas.drawRoundRect(lockBtnRect, dp(4f).toFloat(), dp(4f).toFloat(), btnLockPaint)
            canvas.drawText("✓ LOCK TARGET", lockBtnRect.centerX(), lockBtnRect.centerY() + dp(3.5f), btnTextPaint)

            // Cancel Button
            val cancelW = dp(32f).toFloat()
            val cancelLeft = w - cancelW - dp(8f)
            cancelBtnRect.set(cancelLeft, btnY, cancelLeft + cancelW, btnY + btnH)
            canvas.drawRoundRect(cancelBtnRect, dp(4f).toFloat(), dp(4f).toFloat(), btnCancelPaint)
            btnTextPaint.color = Color.WHITE
            canvas.drawText("✕", cancelBtnRect.centerX(), cancelBtnRect.centerY() + dp(3.5f), btnTextPaint)
            btnTextPaint.color = Color.BLACK

            // 2. Draw Target Crosshair Reticle below the card
            val reticleRadius = dp(26f).toFloat()
            val reticleCenterX = w / 2f
            val reticleCenterY = cardH + dp(8f) + reticleRadius

            // Concentric rings
            canvas.drawCircle(reticleCenterX, reticleCenterY, reticleRadius, ringPaint)
            canvas.drawCircle(reticleCenterX, reticleCenterY, reticleRadius * 0.45f, ringPaint)

            // Cardinal Crosshairs
            val tickLen = dp(8f).toFloat()
            // Top tick
            canvas.drawLine(reticleCenterX, reticleCenterY - reticleRadius - tickLen, reticleCenterX, reticleCenterY - reticleRadius + tickLen, crosshairPaint)
            // Bottom tick
            canvas.drawLine(reticleCenterX, reticleCenterY + reticleRadius - tickLen, reticleCenterX, reticleCenterY + reticleRadius + tickLen, crosshairPaint)
            // Left tick
            canvas.drawLine(reticleCenterX - reticleRadius - tickLen, reticleCenterY, reticleCenterX - reticleRadius + tickLen, reticleCenterY, crosshairPaint)
            // Right tick
            canvas.drawLine(reticleCenterX + reticleRadius - tickLen, reticleCenterY, reticleCenterX + reticleRadius + tickLen, reticleCenterY, crosshairPaint)

            // Center targeting dot
            canvas.drawCircle(reticleCenterX, reticleCenterY, dp(2.5f).toFloat(), centerDotPaint)
        }

        @SuppressLint("ClickableViewAccessibility")
        override fun onTouchEvent(event: MotionEvent): Boolean {
            val x = event.x
            val y = event.y

            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    touchStartX = event.rawX
                    touchStartY = event.rawY
                    val p = params
                    initialWindowX = p?.x ?: 0
                    initialWindowY = p?.y ?: 0
                    isDragging = false

                    if (lockBtnRect.contains(x, y)) {
                        performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                        confirmPosition()
                        return true
                    }
                    if (cancelBtnRect.contains(x, y)) {
                        performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                        onCancelled?.invoke()
                        hide()
                        return true
                    }
                    return true
                }

                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - touchStartX
                    val dy = event.rawY - touchStartY
                    if (abs(dx) > dp(4f) || abs(dy) > dp(4f)) {
                        isDragging = true
                        val p = params ?: return true
                        p.x = (initialWindowX + dx).roundToInt()
                        p.y = (initialWindowY + dy).roundToInt()
                        try {
                            wm.updateViewLayout(this, p)
                        } catch (_: Exception) {}
                    }
                    return true
                }

                MotionEvent.ACTION_UP -> {
                    if (!isDragging) {
                        if (lockBtnRect.contains(x, y)) {
                            performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                            confirmPosition()
                            return true
                        }
                        if (cancelBtnRect.contains(x, y)) {
                            performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                            onCancelled?.invoke()
                            hide()
                            return true
                        }
                    }
                    return true
                }
            }
            return super.onTouchEvent(event)
        }

        private fun confirmPosition() {
            val p = params ?: return
            val dm = service.resources.displayMetrics
            val cardH = dp(50f).toFloat()
            val reticleRadius = dp(26f).toFloat()

            // Calculate absolute screen center of the crosshair reticle
            val screenCenterX = p.x + (width.toFloat() / 2f)
            val screenCenterY = p.y + cardH + dp(8f) + reticleRadius

            val xRatio = if (dm.widthPixels > 0) (screenCenterX / dm.widthPixels).coerceIn(0.01f, 0.99f) else 0.5f
            val yRatio = if (dm.heightPixels > 0) (screenCenterY / dm.heightPixels).coerceIn(0.01f, 0.99f) else 0.85f

            onSaved?.invoke(xRatio, yRatio)
            hide()
        }
    }
}
