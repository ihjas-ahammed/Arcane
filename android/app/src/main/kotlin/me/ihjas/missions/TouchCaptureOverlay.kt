package me.ihjas.missions

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.PointF
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import kotlin.math.hypot

/**
 * Records where the user REALLY pressed.
 *
 * Accessibility click events carry no coordinates, and Android does not let an accessibility
 * service passively observe touchscreen events, so while a macro is being recorded this transparent
 * layer sits over the screen, notes each finger gesture (exact start/end points, timing, path) and
 * immediately plays the same gesture into the app underneath so the app still behaves normally.
 *
 * While the soft keyboard is open the layer is shortened to end where the keyboard starts, so
 * typing is never intercepted (typed text is recorded as text instead).
 */
class TouchCaptureOverlay(
    private val service: AccessibilityService,
    private val onGesture: (CapturedGesture) -> Unit,
) {
    enum class Kind { TAP, LONG_PRESS, SWIPE }

    class CapturedGesture(
        val kind: Kind,
        val x1: Float,
        val y1: Float,
        val x2: Float,
        val y2: Float,
        val durationMs: Long,
        val path: List<PointF>,
    )

    companion object {
        private const val TAG = "TouchCapture"
        private const val LONG_PRESS_MS = 450L
        private const val MAX_PATH_POINTS = 24
        private const val MAX_SWIPE_MS = 4000L
    }

    private val wm = service.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val handler = Handler(Looper.getMainLooper())
    private val slopPx = service.resources.displayMetrics.density * 10f

    private var view: CaptureView? = null
    private var params: WindowManager.LayoutParams? = null
    private var keyboardTop = -1
    private var passThrough = false

    val isShown: Boolean get() = view != null

    fun show(): Boolean {
        if (view != null) return true
        val v = CaptureView(service)
        val p = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        ).apply { gravity = Gravity.TOP or Gravity.START }
        return try {
            wm.addView(v, p)
            view = v
            params = p
            applyGeometry()
            true
        } catch (e: Exception) {
            Log.w(TAG, "Could not attach touch capture layer", e)
            false
        }
    }

    fun hide() {
        handler.removeCallbacksAndMessages(null)
        if (!detached) view?.let { try { wm.removeView(it) } catch (_: Exception) {} }
        detached = false
        view = null
        params = null
        passThrough = false
    }

    /** Top edge of the soft keyboard in screen pixels, or -1 when it is closed. */
    fun setKeyboardTop(top: Int) {
        if (top == keyboardTop) return
        keyboardTop = top
        applyGeometry()
    }

    private fun applyGeometry() {
        val v = view ?: return
        val p = params ?: return
        p.height = if (keyboardTop > 0) keyboardTop else WindowManager.LayoutParams.MATCH_PARENT
        p.flags = if (passThrough) {
            p.flags or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
        } else {
            p.flags and WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE.inv()
        }
        try { wm.updateViewLayout(v, p) } catch (_: Exception) {}
    }

    private var detached = false
    private fun detachTemporarily() {
        val v = view ?: return
        if (detached) return
        detached = true
        try { wm.removeView(v) } catch (_: Exception) {}
    }

    private fun reattach() {
        val v = view ?: return
        val p = params ?: return
        if (!detached) return
        detached = false
        try { wm.addView(v, p) } catch (e: Exception) { Log.w(TAG, "reattach failed", e) }
    }

    private fun setPassThrough(on: Boolean) {
        if (passThrough == on) return
        passThrough = on
        if (!on) replaying = false
        applyGeometry()
    }

    /** Plays the user's own gesture into the app below, with the layer out of the way. */
    private var replaying = false

    private fun replayIntoApp(g: CapturedGesture) {
        replaying = true
        val path = Path()
        if (g.kind == Kind.SWIPE && g.path.size >= 2) {
            path.moveTo(g.path.first().x, g.path.first().y)
            for (i in 1 until g.path.size) path.lineTo(g.path[i].x, g.path[i].y)
        } else {
            path.moveTo(g.x1, g.y1)
        }
        val duration = when (g.kind) {
            Kind.TAP -> 40L
            Kind.LONG_PRESS -> g.durationMs.coerceAtLeast(LONG_PRESS_MS)
            Kind.SWIPE -> g.durationMs.coerceIn(60L, MAX_SWIPE_MS)
        }
        val removeMode = false
        val delayMs = 150L
        if (removeMode) detachTemporarily() else setPassThrough(true)
        // Safety net: never leave the screen un-touchable if the gesture callback is lost.
        handler.removeCallbacksAndMessages(null)
        handler.postDelayed({ if (removeMode) reattach() else setPassThrough(false) }, duration + 1500L)
        // The window-flag change reaches the input system asynchronously; give it a moment so the
        // replayed press goes to the app and not back into this layer.
        handler.postDelayed({
            val ok = try {
                service.dispatchGesture(
                    GestureDescription.Builder()
                        .addStroke(GestureDescription.StrokeDescription(path, 0, duration))
                        .build(),
                    object : AccessibilityService.GestureResultCallback() {
                        override fun onCompleted(gestureDescription: GestureDescription?) {
                            Log.d(TAG, "gesture replayed into app (${g.kind})")
                            handler.postDelayed({ if (removeMode) reattach() else setPassThrough(false) }, 60L)
                        }
                        override fun onCancelled(gestureDescription: GestureDescription?) {
                            Log.w(TAG, "gesture into app was cancelled (${g.kind})")
                            if (removeMode) reattach() else setPassThrough(false)
                        }
                    },
                    handler,
                )
            } catch (e: Exception) { Log.w(TAG, "dispatch failed", e); false }
            if (!ok) { Log.w(TAG, "dispatchGesture refused (${g.kind})"); if (removeMode) reattach() else setPassThrough(false) }
        }, delayMs)
    }

    @SuppressLint("ViewConstructor", "ClickableViewAccessibility")
    private inner class CaptureView(context: Context) : View(context) {
        private val samples = ArrayList<PointF>()
        private var downTime = 0L
        private var multiTouch = false

        override fun onTouchEvent(e: MotionEvent): Boolean {
            when (e.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    samples.clear()
                    samples.add(PointF(e.rawX, e.rawY))
                    downTime = e.eventTime
                    multiTouch = false
                }
                MotionEvent.ACTION_POINTER_DOWN -> multiTouch = true
                MotionEvent.ACTION_MOVE -> {
                    // Include the batched intermediate points so fast swipes keep their real shape.
                    for (h in 0 until e.historySize) {
                        samples.add(PointF(e.getHistoricalX(0, h) + (e.rawX - e.x), e.getHistoricalY(0, h) + (e.rawY - e.y)))
                    }
                    samples.add(PointF(e.rawX, e.rawY))
                }
                MotionEvent.ACTION_UP -> {
                    samples.add(PointF(e.rawX, e.rawY))
                    finish(e.eventTime - downTime)
                }
                MotionEvent.ACTION_CANCEL -> samples.clear()
            }
            return true
        }

        private fun finish(durationMs: Long) {
            if (samples.isEmpty() || multiTouch) { samples.clear(); return }
            val start = samples.first()
            val end = samples.last()
            val maxFromStart = samples.maxOf { hypot((it.x - start.x).toDouble(), (it.y - start.y).toDouble()) }
            val gesture = when {
                maxFromStart < slopPx && durationMs >= LONG_PRESS_MS ->
                    CapturedGesture(Kind.LONG_PRESS, start.x, start.y, start.x, start.y, durationMs, listOf(start))
                maxFromStart < slopPx ->
                    CapturedGesture(Kind.TAP, start.x, start.y, start.x, start.y, durationMs, listOf(start))
                else -> {
                    val step = (samples.size / MAX_PATH_POINTS).coerceAtLeast(1)
                    val thinned = samples.filterIndexed { i, _ -> i % step == 0 }.toMutableList()
                    if (thinned.last() !== end) thinned.add(end)
                    CapturedGesture(Kind.SWIPE, start.x, start.y, end.x, end.y, durationMs, thinned)
                }
            }
            samples.clear()
            if (replaying) {
                // Our own replayed press raced the window change and landed here: it is not the user's
                // gesture, so don't record it, just play it again now that the layer is out of the way.
                replayIntoApp(gesture)
                return
            }
            onGesture(gesture)
            replayIntoApp(gesture)
        }
    }
}
