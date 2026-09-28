package me.ihjas.missions

import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.text.Editable
import android.text.InputType
import android.text.TextUtils
import android.text.TextWatcher
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import me.ihjas.missions.widgets.WidgetActionReceiver
import me.ihjas.missions.widgets.WidgetCommon
import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * AssistiveTouch-style floating task button, drawn by [LauncherTakeoverService] as an
 * accessibility overlay (no "draw over other apps" permission needed).
 *
 * Only shown while a task is running (engaged).
 *
 *  - Tap: halt the running task (same action as the home-screen widget's button).
 *  - Double-tap: tick the current checkpoint and type the next one, added on the same level
 *    right after it (e.g. the next chapter while reading).
 *  - Long-press: quick menu (halt, check next, add checkpoint, finish, open plan, turn off).
 *  - Drag: move anywhere; on release it snaps to the nearest side and remembers the spot.
 *
 * Task state is read from the data Arcane already publishes for its home-screen widgets.
 */
class TaskBubbleOverlay(private val context: Context) {

    companion object {
        private const val PREFS = "arcane_launcher"
        private const val KEY_ENABLED = "task_bubble_enabled"
        private const val KEY_RIGHT = "task_bubble_right"
        private const val KEY_Y = "task_bubble_y" // fraction of the usable height

        private const val IDLE_ALPHA = 0.55f
        private const val IDLE_DELAY_MS = 2500L

        private const val BG = 0xF205080C.toInt()
        private const val CYAN = 0xFF00F0FF.toInt()
        private const val AMBER = 0xFFFFB547.toInt()
        private const val RED = 0xFFFF2A4B.toInt()
        private const val MUTED = 0xFF7A8A99.toInt()

        /** On by default; only shows while the accessibility service is switched on. */
        fun isEnabled(context: Context): Boolean =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_ENABLED, true)

        fun setEnabled(context: Context, enabled: Boolean) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(KEY_ENABLED, enabled).apply()
        }
    }

    private val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val handler = Handler(Looper.getMainLooper())
    private val density = context.resources.displayMetrics.density
    private fun dp(v: Float) = (v * density).roundToInt()

    private val size = dp(52f)
    private val edgeMargin = dp(4f)

    private val settingsPrefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private val widgetPrefs = WidgetCommon.prefs(context)

    private var bubble: BubbleView? = null
    private var params: WindowManager.LayoutParams? = null
    private var menu: View? = null
    private var dialog: View? = null
    private var snapAnim: ValueAnimator? = null
    private var started = false

    // Strong references: SharedPreferences only keeps listeners weakly.
    private val settingsListener = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
        if (key == KEY_ENABLED) sync()
    }
    private val widgetListener = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
        // Several keys land per publish; coalesce into one update.
        if (key != null && key.startsWith("arcane.task.")) {
            handler.removeCallbacks(syncRunnable)
            handler.postDelayed(syncRunnable, 60)
        }
    }

    fun start() {
        if (started) return
        started = true
        settingsPrefs.registerOnSharedPreferenceChangeListener(settingsListener)
        widgetPrefs.registerOnSharedPreferenceChangeListener(widgetListener)
        sync()
    }

    fun stop() {
        if (!started) return
        started = false
        settingsPrefs.unregisterOnSharedPreferenceChangeListener(settingsListener)
        widgetPrefs.unregisterOnSharedPreferenceChangeListener(widgetListener)
        hide()
        dismissDialog()
    }

    /** Screen size changed (rotation, fold): keep the bubble on its side and on screen. */
    fun onConfigurationChanged() {
        dismissMenu()
        val p = params ?: return
        val b = bubble ?: return
        placeFromPrefs(p)
        try { wm.updateViewLayout(b, p) } catch (_: Exception) {}
    }

    private val syncRunnable = Runnable {
        if (started && isEnabled(context) && isRunning()) {
            show()
            bubble?.refreshState()
        } else {
            hide()
        }
    }

    private fun sync() {
        handler.removeCallbacks(syncRunnable)
        handler.post(syncRunnable)
    }

    // ── Window ──────────────────────────────────────────────────

    private fun overlayType() =
        if (Build.VERSION.SDK_INT >= 22) WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
        else @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_SYSTEM_OVERLAY

    private fun screen(): Rect {
        return if (Build.VERSION.SDK_INT >= 30) {
            wm.currentWindowMetrics.bounds
        } else {
            val dm = context.resources.displayMetrics
            Rect(0, 0, dm.widthPixels, dm.heightPixels)
        }
    }

    private fun show() {
        if (bubble != null) return
        val view = BubbleView(context)
        val p = WindowManager.LayoutParams(
            size,
            size,
            overlayType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply { gravity = Gravity.TOP or Gravity.START }
        placeFromPrefs(p)
        try {
            wm.addView(view, p)
            bubble = view
            params = p
            view.refreshState()
            scheduleIdle()
        } catch (_: Exception) {
        }
    }

    private fun hide() {
        dismissMenu()
        snapAnim?.cancel()
        handler.removeCallbacks(idleRunnable)
        bubble?.let { try { wm.removeView(it) } catch (_: Exception) {} }
        bubble = null
        params = null
    }

    private fun placeFromPrefs(p: WindowManager.LayoutParams) {
        val s = screen()
        val right = settingsPrefs.getBoolean(KEY_RIGHT, true)
        val yFrac = settingsPrefs.getFloat(KEY_Y, 0.55f).coerceIn(0f, 1f)
        p.x = if (right) s.width() - size - edgeMargin else edgeMargin
        p.y = (yFrac * (s.height() - size)).roundToInt()
    }

    private fun move(x: Int, y: Int) {
        val p = params ?: return
        val b = bubble ?: return
        val s = screen()
        p.x = x.coerceIn(0, s.width() - size)
        p.y = y.coerceIn(0, s.height() - size)
        try { wm.updateViewLayout(b, p) } catch (_: Exception) {}
    }

    private fun snapToEdge() {
        val p = params ?: return
        val s = screen()
        val right = p.x + size / 2 > s.width() / 2
        val target = if (right) s.width() - size - edgeMargin else edgeMargin
        settingsPrefs.edit()
            .putBoolean(KEY_RIGHT, right)
            .putFloat(KEY_Y, p.y.toFloat() / (s.height() - size).coerceAtLeast(1))
            .apply()
        snapAnim?.cancel()
        snapAnim = ValueAnimator.ofInt(p.x, target).apply {
            duration = 220
            interpolator = DecelerateInterpolator()
            addUpdateListener { move(it.animatedValue as Int, p.y) }
            start()
        }
    }

    private fun scheduleIdle() {
        handler.removeCallbacks(idleRunnable)
        handler.postDelayed(idleRunnable, IDLE_DELAY_MS)
    }

    private val idleRunnable = Runnable {
        if (menu == null) bubble?.animate()?.alpha(IDLE_ALPHA)?.setDuration(300)?.start()
    }

    private fun wake() {
        handler.removeCallbacks(idleRunnable)
        bubble?.animate()?.cancel()
        bubble?.alpha = 1f
    }

    // ── Actions ─────────────────────────────────────────────────

    private fun hasTask() = WidgetCommon.getSafeBoolean(widgetPrefs, "arcane.task.hasTask", false)
    private fun isRunning() = WidgetCommon.getSafeBoolean(widgetPrefs, "arcane.task.isRunning", false)

    /** Same path as the widget's quick buttons: applied silently when Arcane is alive. */
    private fun sendAction(action: String) {
        val intent = Intent(context, WidgetActionReceiver::class.java).apply {
            this.action = "me.ihjas.missions.WIDGET_ACTION"
            data = actionUri(action)
        }
        context.sendBroadcast(intent)
    }

    /** Opens Arcane on the given screen (like tapping the widget's title). */
    private fun openApp(action: String) {
        val intent = Intent(context, MainActivity::class.java).apply {
            this.action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
            data = actionUri(action)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        try { context.startActivity(intent) } catch (_: Exception) {}
    }

    private fun actionUri(action: String): Uri =
        Uri.Builder().scheme("arcane").authority("widget").appendQueryParameter("action", action).build()

    private fun onTap() {
        if (hasTask()) {
            // Instant feedback; the real state arrives when Arcane republishes the widget data.
            bubble?.pending = true
            bubble?.invalidate()
            sendAction("task_toggle")
            handler.postDelayed({ bubble?.pending = false; bubble?.invalidate() }, 1500)
        } else {
            openApp("task_open_plan")
        }
    }

    // ── Long-press menu ─────────────────────────────────────────

    @SuppressLint("ClickableViewAccessibility")
    private fun showMenu() {
        dismissMenu()
        val p = params ?: return
        val s = screen()
        val onRight = p.x + size / 2 > s.width() / 2

        val panel = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(6f), dp(6f), dp(6f), dp(6f))
            background = GradientDrawable().apply {
                setColor(BG)
                cornerRadius = dp(14f).toFloat()
                setStroke(dp(1f), CYAN and 0x66FFFFFF)
            }
            elevation = dp(6f).toFloat()
        }

        val title = widgetPrefs.getString("arcane.task.title", "") ?: ""
        panel.addView(TextView(context).apply {
            text = if (hasTask() && title.isNotEmpty()) title.uppercase() else "NO TASK QUEUED"
            setTextColor(MUTED)
            textSize = 11f
            letterSpacing = 0.1f
            typeface = Typeface.DEFAULT_BOLD
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
            maxWidth = dp(200f)
            setPadding(dp(10f), dp(4f), dp(10f), dp(6f))
        })

        fun item(label: String, color: Int, run: () -> Unit) {
            panel.addView(TextView(context).apply {
                text = label
                setTextColor(color)
                textSize = 14f
                letterSpacing = 0.08f
                typeface = Typeface.DEFAULT_BOLD
                setPadding(dp(12f), dp(10f), dp(12f), dp(10f))
                minWidth = dp(150f)
                background = GradientDrawable().apply {
                    cornerRadius = dp(10f).toFloat()
                    setColor(Color.TRANSPARENT)
                }
                setOnClickListener {
                    it.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
                    dismissMenu()
                    run()
                }
            })
        }

        if (hasTask()) {
            if (isRunning()) item("❚❚  HALT", RED) { sendAction("task_toggle") }
            else item("▶  ENGAGE", AMBER) { sendAction("task_toggle") }
            item("✓  CHECK NEXT", CYAN) { sendAction("task_check_next") }
            item("＋  ADD CHECKPOINT", CYAN) { showCheckpointDialog() }
            item("⚑  FINISH", CYAN) { sendAction("task_finish") }
        }
        item("☰  OPEN PLAN", Color.WHITE) { openApp("task_open_plan") }
        item("✕  TURN OFF", MUTED) {
            setEnabled(context, false) // the settings listener hides the bubble
            Toast.makeText(
                context,
                "Floating task button off. Turn it back on in Settings › Home Launcher.",
                Toast.LENGTH_LONG,
            ).show()
        }

        // Close when tapping anywhere else.
        panel.setOnTouchListener { _, e ->
            if (e.action == MotionEvent.ACTION_OUTSIDE) { dismissMenu(); true } else false
        }

        panel.measure(
            View.MeasureSpec.makeMeasureSpec(s.width(), View.MeasureSpec.AT_MOST),
            View.MeasureSpec.makeMeasureSpec(s.height(), View.MeasureSpec.AT_MOST),
        )
        val w = panel.measuredWidth
        val h = panel.measuredHeight
        val gap = dp(8f)
        val mp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = if (onRight) (p.x - w - gap).coerceAtLeast(0) else (p.x + size + gap).coerceAtMost(s.width() - w)
            y = (p.y + size / 2 - h / 2).coerceIn(0, (s.height() - h).coerceAtLeast(0))
        }
        try {
            wm.addView(panel, mp)
            menu = panel
            wake()
            handler.postDelayed(menuTimeout, 6000)
        } catch (_: Exception) {
        }
    }

    private val menuTimeout = Runnable { dismissMenu() }

    private fun dismissMenu() {
        handler.removeCallbacks(menuTimeout)
        menu?.let { try { wm.removeView(it) } catch (_: Exception) {} }
        if (menu != null) scheduleIdle()
        menu = null
    }

    // ── Double-tap: check + add checkpoint ──────────────────────

    /**
     * Floating input: ticks the current checkpoint and adds the typed one on the same level,
     * right after it. Focusable (unlike the bubble) so the keyboard can open over any app.
     */
    @SuppressLint("ClickableViewAccessibility")
    private fun showCheckpointDialog() {
        dismissMenu()
        if (dialog != null) return
        val current = widgetPrefs.getString("arcane.task.nextCheckpoint", "") ?: ""
        val task = widgetPrefs.getString("arcane.task.title", "") ?: ""

        val root = object : FrameLayout(context) {
            override fun dispatchKeyEvent(event: KeyEvent): Boolean {
                if (event.keyCode == KeyEvent.KEYCODE_BACK) {
                    if (event.action == KeyEvent.ACTION_UP) dismissDialog()
                    return true
                }
                return super.dispatchKeyEvent(event)
            }
        }
        root.setBackgroundColor(0x99000000.toInt())
        root.setOnClickListener { dismissDialog() }

        val card = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(18f), dp(16f), dp(18f), dp(12f))
            isClickable = true // taps inside the card don't close it
            background = GradientDrawable().apply {
                setColor(BG)
                cornerRadius = dp(16f).toFloat()
                setStroke(dp(1f), CYAN and 0x66FFFFFF)
            }
            elevation = dp(8f).toFloat()
        }

        fun label(text: String, color: Int, size: Float, bold: Boolean = false) = TextView(context).apply {
            this.text = text
            setTextColor(color)
            textSize = size
            if (bold) typeface = Typeface.DEFAULT_BOLD
        }

        card.addView(label("CHECKPOINT", CYAN, 11f, bold = true).apply { letterSpacing = 0.18f })
        if (current.isNotEmpty()) {
            card.addView(label("✓  $current", Color.WHITE, 16f, bold = true).apply {
                setPadding(0, dp(8f), 0, 0)
                maxLines = 2
                ellipsize = TextUtils.TruncateAt.END
            })
            card.addView(label("will be checked off", MUTED, 12f))
        } else {
            card.addView(label(
                if (task.isNotEmpty()) "No open checkpoint in ${task.uppercase()}. The new one is added to the task."
                else "No open checkpoint. The new one is added to the task.",
                MUTED, 13f,
            ).apply { setPadding(0, dp(8f), 0, 0) })
        }

        val input = EditText(context).apply {
            hint = "Next checkpoint on this level"
            setHintTextColor(MUTED)
            setTextColor(Color.WHITE)
            textSize = 15f
            isSingleLine = true
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
            imeOptions = EditorInfo.IME_ACTION_DONE
            setPadding(dp(12f), dp(10f), dp(12f), dp(10f))
            background = GradientDrawable().apply {
                setColor(0x22FFFFFF)
                cornerRadius = dp(10f).toFloat()
                setStroke(dp(1f), CYAN and 0x55FFFFFF)
            }
        }
        card.addView(input, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT,
        ).apply { topMargin = dp(14f) })

        fun button(text: String, color: Int) = TextView(context).apply {
            this.text = text
            setTextColor(color)
            textSize = 14f
            letterSpacing = 0.08f
            typeface = Typeface.DEFAULT_BOLD
            setPadding(dp(14f), dp(12f), dp(14f), dp(12f))
        }
        val cancel = button("CANCEL", MUTED)
        val confirm = button("", CYAN)
        fun primaryLabel(): String {
            val typed = input.text.toString().isNotBlank()
            return when {
                current.isEmpty() -> "ADD"
                typed -> "CHECK + ADD"
                else -> "CHECK"
            }
        }
        fun refreshConfirm() {
            confirm.text = primaryLabel()
            val enabled = current.isNotEmpty() || input.text.toString().isNotBlank()
            confirm.alpha = if (enabled) 1f else 0.4f
            confirm.isEnabled = enabled
        }
        fun submit() {
            val name = input.text.toString().trim()
            if (current.isEmpty() && name.isEmpty()) return
            input.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
            sendAction("task_check_add:$name")
            dismissDialog()
        }
        refreshConfirm()
        input.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
            override fun afterTextChanged(s: Editable?) = refreshConfirm()
        })
        input.setOnEditorActionListener { _, id, _ ->
            if (id == EditorInfo.IME_ACTION_DONE) { submit(); true } else false
        }
        cancel.setOnClickListener { dismissDialog() }
        confirm.setOnClickListener { submit() }

        card.addView(LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.END
            addView(cancel)
            addView(confirm)
        }, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT,
        ).apply { topMargin = dp(8f) })

        // Upper part of the screen, so the keyboard never covers it.
        root.addView(card, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.WRAP_CONTENT,
            Gravity.TOP or Gravity.CENTER_HORIZONTAL,
        ).apply { setMargins(dp(20f), (screen().height() * 0.14f).roundToInt(), dp(20f), dp(20f)) })

        val p = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            overlayType(),
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            softInputMode = WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE or
                WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_VISIBLE
        }
        try {
            wm.addView(root, p)
            dialog = root
            input.requestFocus()
            input.postDelayed({
                val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
                imm.showSoftInput(input, InputMethodManager.SHOW_IMPLICIT)
            }, 150)
        } catch (_: Exception) {
        }
    }

    private fun dismissDialog() {
        val d = dialog ?: return
        dialog = null
        try {
            val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
            imm.hideSoftInputFromWindow(d.windowToken, 0)
        } catch (_: Exception) {}
        try { wm.removeView(d) } catch (_: Exception) {}
    }

    // ── Bubble view ─────────────────────────────────────────────

    @SuppressLint("ViewConstructor")
    private inner class BubbleView(ctx: Context) : View(ctx) {
        private val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = BG }
        private val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeWidth = dp(2.5f).toFloat() }
        private val glyph = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
        private val time = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textAlign = Paint.Align.CENTER
            textSize = dp(9f).toFloat()
            typeface = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD)
        }
        private val path = Path()
        private val arc = RectF()

        var pending = false
        private var hasTask = false
        private var running = false
        private var progress = 0

        private val touchSlop = ViewConfiguration.get(ctx).scaledTouchSlop
        private var downRawX = 0f
        private var downRawY = 0f
        private var startX = 0
        private var startY = 0
        private var dragging = false
        private var longPressed = false
        private var awaitingSecondTap = false
        private val singleTap = Runnable {
            awaitingSecondTap = false
            onTap()
        }
        private val longPress = Runnable {
            longPressed = true
            performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
            showMenu()
        }
        private val tick = object : Runnable {
            override fun run() {
                invalidate()
                if (running) postDelayed(this, 1000)
            }
        }

        init {
            contentDescription = "Arcane task button"
        }

        fun refreshState() {
            hasTask = WidgetCommon.getSafeBoolean(widgetPrefs, "arcane.task.hasTask", false)
            running = WidgetCommon.getSafeBoolean(widgetPrefs, "arcane.task.isRunning", false)
            progress = WidgetCommon.getSafeInt(widgetPrefs, "arcane.task.progressPct", 0).coerceIn(0, 100)
            pending = false
            removeCallbacks(tick)
            if (running) post(tick)
            invalidate()
        }

        private fun elapsedLabel(): String {
            val acc = WidgetCommon.getSafeLong(widgetPrefs, "arcane.task.accumulatedSec", 0L)
            val start = WidgetCommon.getSafeLong(widgetPrefs, "arcane.task.sessionStartMs", 0L)
            val live = if (start > 0L) ((System.currentTimeMillis() - start) / 1000L).coerceAtLeast(0L) else 0L
            val sec = acc + live
            return if (sec < 3600) "%02d:%02d".format(sec / 60, sec % 60) else "%d:%02d".format(sec / 3600, (sec % 3600) / 60)
        }

        override fun onDetachedFromWindow() {
            removeCallbacks(tick)
            removeCallbacks(longPress)
            removeCallbacks(singleTap)
            awaitingSecondTap = false
            super.onDetachedFromWindow()
        }

        override fun onDraw(canvas: Canvas) {
            val w = width.toFloat()
            val cx = w / 2
            val cy = height / 2f
            val r = w / 2 - ring.strokeWidth
            val accent = when {
                !hasTask -> MUTED
                running -> RED
                else -> AMBER
            }

            canvas.drawCircle(cx, cy, r, fill)
            ring.color = accent and 0x44FFFFFF
            canvas.drawCircle(cx, cy, r, ring)
            if (hasTask && progress > 0) {
                ring.color = accent
                arc.set(cx - r, cy - r, cx + r, cy + r)
                canvas.drawArc(arc, -90f, 360f * progress / 100f, false, ring)
            }

            glyph.color = if (pending) Color.WHITE else accent
            val g = w * 0.15f
            val gy = if (running) cy - dp(4f) else cy
            path.reset()
            when {
                !hasTask -> {
                    // Three list lines: "open plan".
                    val lh = dp(2f).toFloat()
                    for (i in -1..1) canvas.drawRoundRect(cx - g, gy + i * g * 0.7f - lh / 2, cx + g, gy + i * g * 0.7f + lh / 2, lh, lh, glyph)
                }
                running -> {
                    val bw = g * 0.55f
                    canvas.drawRoundRect(cx - g * 0.8f, gy - g, cx - g * 0.8f + bw, gy + g, 3f, 3f, glyph)
                    canvas.drawRoundRect(cx + g * 0.8f - bw, gy - g, cx + g * 0.8f, gy + g, 3f, 3f, glyph)
                }
                else -> {
                    path.moveTo(cx - g * 0.7f, gy - g)
                    path.lineTo(cx + g, gy)
                    path.lineTo(cx - g * 0.7f, gy + g)
                    path.close()
                    canvas.drawPath(path, glyph)
                }
            }
            if (running) {
                time.color = accent
                canvas.drawText(elapsedLabel(), cx, cy + g + dp(8f), time)
            }
        }

        @SuppressLint("ClickableViewAccessibility")
        override fun onTouchEvent(e: MotionEvent): Boolean {
            val p = params ?: return false
            when (e.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    snapAnim?.cancel()
                    wake()
                    downRawX = e.rawX
                    downRawY = e.rawY
                    startX = p.x
                    startY = p.y
                    dragging = false
                    longPressed = false
                    postDelayed(longPress, ViewConfiguration.getLongPressTimeout().toLong())
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = e.rawX - downRawX
                    val dy = e.rawY - downRawY
                    if (!dragging && (abs(dx) > touchSlop || abs(dy) > touchSlop)) {
                        dragging = true
                        removeCallbacks(longPress)
                        dismissMenu()
                    }
                    if (dragging) move(startX + dx.roundToInt(), startY + dy.roundToInt())
                }
                MotionEvent.ACTION_UP -> {
                    removeCallbacks(longPress)
                    when {
                        dragging -> snapToEdge()
                        !longPressed -> {
                            dismissMenu()
                            if (awaitingSecondTap) {
                                // Double-tap: check the current checkpoint + add the next one.
                                removeCallbacks(singleTap)
                                awaitingSecondTap = false
                                performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
                                showCheckpointDialog()
                            } else {
                                // Wait out the double-tap window before acting on a single tap.
                                performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
                                awaitingSecondTap = true
                                postDelayed(singleTap, ViewConfiguration.getDoubleTapTimeout().toLong())
                            }
                        }
                    }
                    if (menu == null) scheduleIdle()
                }
                MotionEvent.ACTION_CANCEL -> {
                    removeCallbacks(longPress)
                    if (dragging) snapToEdge()
                    scheduleIdle()
                }
            }
            return true
        }
    }
}
