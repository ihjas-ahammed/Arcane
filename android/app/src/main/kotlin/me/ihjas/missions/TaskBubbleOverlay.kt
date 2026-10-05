package me.ihjas.missions

import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.CornerPathEffect
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Shader
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
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.roundToInt
import kotlin.math.sin

/**
 * Redesigned AssistiveTouch-style tactical floating task button, drawn by
 * [LauncherTakeoverService] as an accessibility overlay (no "draw over other apps" permission needed).
 *
 *  - Visual: High-tech Arcane tactical HUD disc with ambient halo glow, concentric progress track,
 *    subtle reticle notches, glassmorphic gradient fill, and crisp monospace telemetry.
 *  - Idle Side Settle: After 2.5s of no interaction, smoothly docks against the screen edge
 *    (tucking ~38% into the bezel, leaving a rounded tactile thumb-tab peeking out) and dims
 *    to 38% opacity. Instantly springs out to full size and 100% opacity on touch.
 *  - Stay Alive: Supported by [TaskForegroundService] while running so Android / MIUI battery
 *    savers never kill the process during long reading or focus sessions.
 *  - Tap: Halts running session or resumes paused session.
 *  - Double-tap: Ticks current checkpoint and types next checkpoint on same level.
 *  - Long-press: Quick menu (Engage/Halt, Check Next, Add Checkpoint, Finish, Open Plan, Turn Off).
 *  - Drag: Moves anywhere; snaps to nearest edge and remembers vertical position.
 */
class TaskBubbleOverlay(private val context: Context) {

    companion object {
        private const val PREFS = "arcane_launcher"
        private const val KEY_ENABLED = "task_bubble_enabled"
        private const val KEY_RIGHT = "task_bubble_right"
        private const val KEY_Y = "task_bubble_y" // fraction of usable height

        private const val IDLE_ALPHA = 0.38f
        private const val IDLE_DELAY_MS = 2500L
        private const val PAUSED_AUTO_HIDE_MS = 20 * 60 * 1000L // 20 minutes paused timeout

        private const val BG_DARK = 0xF605080E.toInt()
        private const val CYAN = 0xFF00F0FF.toInt()
        private const val AMBER = 0xFFFFB547.toInt()
        private const val RED = 0xFFFF3B5C.toInt()
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

    private val size = dp(54f)
    private val edgeMargin = dp(6f)
    private val tuckPx = (size * 0.38f).roundToInt()

    private val settingsPrefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private val widgetPrefs = WidgetCommon.prefs(context)

    private var bubble: BubbleView? = null
    private var params: WindowManager.LayoutParams? = null
    private var radialMenu: RadialMenuView? = null
    private var dismissTarget: DismissTargetView? = null
    private var dialog: View? = null
    private var snapAnim: ValueAnimator? = null
    private var dockAnim: ValueAnimator? = null
    private var isDocked = false
    private var started = false
    private var temporarilyHidden = false
    private var lastHiddenTaskTitle: String? = null

    // Strong references: SharedPreferences only keeps listeners weakly.
    private val settingsListener = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
        if (key == KEY_ENABLED) sync()
    }
    private val widgetListener = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
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
        temporarilyHidden = false
        lastHiddenTaskTitle = null
        settingsPrefs.unregisterOnSharedPreferenceChangeListener(settingsListener)
        widgetPrefs.unregisterOnSharedPreferenceChangeListener(widgetListener)
        TaskForegroundService.stop(context)
        hide()
        dismissDialog()
    }

    /** Screen size changed (rotation, fold): keep the bubble on its side and on screen. */
    fun onConfigurationChanged() {
        dismissRadialMenu()
        dismissDismissTarget()
        val p = params ?: return
        val b = bubble ?: return
        placeFromPrefs(p)
        try { wm.updateViewLayout(b, p) } catch (_: Exception) {}
    }

    private val syncRunnable = Runnable {
        val enabled = isEnabled(context)
        val running = isRunning()
        val has = hasTask()
        val currentTitle = widgetPrefs.getString("arcane.task.title", "") ?: ""

        if (temporarilyHidden) {
            // Automatically unhide when a new task is started or session becomes running
            if (running || (currentTitle.isNotEmpty() && currentTitle != lastHiddenTaskTitle)) {
                temporarilyHidden = false
                lastHiddenTaskTitle = null
            }
        }

        if (started && enabled && !temporarilyHidden && (running || has)) {
            show()
            bubble?.refreshState()
            if (running) {
                handler.removeCallbacks(pausedAutoHideRunnable)
                val title = widgetPrefs.getString("arcane.task.title", "") ?: "Arcane Task"
                val subtitle = widgetPrefs.getString("arcane.task.subtitle", "") ?: "Reading / Task In Progress"
                TaskForegroundService.start(context, title, subtitle)
            } else {
                TaskForegroundService.stop(context)
                // Schedule auto-hide if paused and untouched for a long period
                handler.removeCallbacks(pausedAutoHideRunnable)
                handler.postDelayed(pausedAutoHideRunnable, PAUSED_AUTO_HIDE_MS)
            }
        } else {
            TaskForegroundService.stop(context)
            hide()
        }
    }

    private val pausedAutoHideRunnable = Runnable {
        if (!isRunning()) {
            hide()
        }
    }

    private fun sync() {
        handler.removeCallbacks(syncRunnable)
        handler.post(syncRunnable)
    }

    // ── Window Placement & Layout ───────────────────────────────

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
            isDocked = false
            scheduleIdle()
        } catch (_: Exception) {
        }
    }

    private fun hide() {
        dismissRadialMenu()
        dismissDismissTarget()
        snapAnim?.cancel()
        dockAnim?.cancel()
        handler.removeCallbacks(idleRunnable)
        handler.removeCallbacks(pausedAutoHideRunnable)
        bubble?.let { try { wm.removeView(it) } catch (_: Exception) {} }
        bubble = null
        params = null
        isDocked = false
    }

    private fun normalRestingX(): Int {
        val s = screen()
        val right = settingsPrefs.getBoolean(KEY_RIGHT, true)
        return if (right) s.width() - size - edgeMargin else edgeMargin
    }

    private fun dockedX(): Int {
        val s = screen()
        val right = settingsPrefs.getBoolean(KEY_RIGHT, true)
        return if (right) s.width() - size + tuckPx else -tuckPx
    }

    private fun placeFromPrefs(p: WindowManager.LayoutParams) {
        val s = screen()
        val right = settingsPrefs.getBoolean(KEY_RIGHT, true)
        val yFrac = settingsPrefs.getFloat(KEY_Y, 0.55f).coerceIn(0f, 1f)
        p.x = if (isDocked) dockedX() else normalRestingX()
        p.y = (yFrac * (s.height() - size)).roundToInt()
    }

    private fun move(x: Int, y: Int) {
        val p = params ?: return
        val b = bubble ?: return
        val s = screen()
        p.x = x.coerceIn(-tuckPx, s.width() - size + tuckPx)
        p.y = y.coerceIn(0, s.height() - size)
        try { wm.updateViewLayout(b, p) } catch (_: Exception) {}
    }

    private fun snapToEdge() {
        val p = params ?: return
        val s = screen()
        val right = p.x + size / 2 > s.width() / 2
        val targetX = if (right) s.width() - size - edgeMargin else edgeMargin

        settingsPrefs.edit()
            .putBoolean(KEY_RIGHT, right)
            .putFloat(KEY_Y, p.y.toFloat() / (s.height() - size).coerceAtLeast(1))
            .apply()

        snapAnim?.cancel()
        val startX = p.x
        snapAnim = ValueAnimator.ofInt(startX, targetX).apply {
            duration = 220
            interpolator = DecelerateInterpolator()
            addUpdateListener {
                val curX = it.animatedValue as Int
                p.x = curX
                try { wm.updateViewLayout(bubble, p) } catch (_: Exception) {}
            }
            start()
        }
    }

    // ── AssistiveTouch Side-Settle & Wake ────────────────────────

    private fun scheduleIdle() {
        handler.removeCallbacks(idleRunnable)
        handler.postDelayed(idleRunnable, IDLE_DELAY_MS)
    }

    private val idleRunnable = Runnable {
        settleToSide()
    }

    private fun settleToSide() {
        if (radialMenu != null || dismissTarget != null || dialog != null || bubble == null) return
        val p = params ?: return
        val b = bubble ?: return
        val targetX = dockedX()

        snapAnim?.cancel()
        dockAnim?.cancel()

        val startX = p.x
        val startAlpha = b.alpha

        dockAnim = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 320
            interpolator = DecelerateInterpolator()
            addUpdateListener { va ->
                val f = va.animatedFraction
                p.x = (startX + (targetX - startX) * f).roundToInt()
                try { wm.updateViewLayout(b, p) } catch (_: Exception) {}
                b.alpha = startAlpha + (IDLE_ALPHA - startAlpha) * f
            }
            start()
        }
        isDocked = true
        b.isDockedState = true
        b.invalidate()
    }

    private fun wake(animateOut: Boolean = true) {
        handler.removeCallbacks(idleRunnable)
        dockAnim?.cancel()
        val p = params ?: return
        val b = bubble ?: return
        val targetX = normalRestingX()

        if (isDocked && animateOut) {
            isDocked = false
            b.isDockedState = false
            val startX = p.x
            val startAlpha = b.alpha

            dockAnim = ValueAnimator.ofFloat(0f, 1f).apply {
                duration = 160
                interpolator = DecelerateInterpolator()
                addUpdateListener { va ->
                    val f = va.animatedFraction
                    p.x = (startX + (targetX - startX) * f).roundToInt()
                    try { wm.updateViewLayout(b, p) } catch (_: Exception) {}
                    b.alpha = startAlpha + (1f - startAlpha) * f
                }
                start()
            }
        } else {
            isDocked = false
            b.isDockedState = false
            b.alpha = 1f
        }
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
            bubble?.pending = true
            bubble?.invalidate()
            sendAction("task_toggle")
            handler.postDelayed({ bubble?.pending = false; bubble?.invalidate() }, 1200)
        } else {
            openApp("task_open_plan")
        }
    }

    // ── Radial Emote Menu & Dismiss Target ──────────────────────

    private data class RadialItem(
        val id: String,
        val label: String,
        val glyph: String,
        val color: Int,
        var angleDeg: Float = 0f,
        val action: () -> Unit,
    )

    private fun angularDiff(a: Float, b: Float): Float {
        val diff = abs(a - b) % 360f
        return if (diff > 180f) 360f - diff else diff
    }

    private fun buildRadialItems(): List<RadialItem> {
        val items = mutableListOf<RadialItem>()
        if (hasTask()) {
            if (isRunning()) {
                items.add(RadialItem("toggle", "HALT", "❚❚", RED) { sendAction("task_toggle") })
            } else {
                items.add(RadialItem("toggle", "ENGAGE", "▶", AMBER) { sendAction("task_toggle") })
            }
            items.add(RadialItem("check", "CHECK", "✓", CYAN) { sendAction("task_check_next") })
            items.add(RadialItem("add", "ADD +", "＋", CYAN) { showCheckpointDialog() })
            items.add(RadialItem("finish", "FINISH", "⚑", CYAN) { sendAction("task_finish") })
            items.add(RadialItem("plan", "PLAN", "☰", Color.WHITE) { openApp("task_open_plan") })
            items.add(RadialItem("off", "DISABLE", "✕", MUTED) {
                setEnabled(context, false)
                Toast.makeText(
                    context,
                    "Floating task button off. Turn back on in Settings › Home Launcher.",
                    Toast.LENGTH_LONG,
                ).show()
            })
        } else {
            items.add(RadialItem("plan", "PLAN", "☰", Color.WHITE) { openApp("task_open_plan") })
            items.add(RadialItem("off", "DISABLE", "✕", MUTED) {
                setEnabled(context, false)
                Toast.makeText(
                    context,
                    "Floating task button off. Turn back on in Settings › Home Launcher.",
                    Toast.LENGTH_LONG,
                ).show()
            })
        }
        return items
    }

    private fun assignAngles(items: List<RadialItem>, cx: Float, screenWidth: Float) {
        val rightEdge = cx > screenWidth - dp(70f)
        val leftEdge = cx < dp(70f)
        val n = items.size
        if (n == 2) {
            when {
                rightEdge -> {
                    items[0].angleDeg = 210f
                    items[1].angleDeg = 150f
                }
                leftEdge -> {
                    items[0].angleDeg = 330f
                    items[1].angleDeg = 30f
                }
                else -> {
                    items[0].angleDeg = 270f
                    items[1].angleDeg = 90f
                }
            }
            return
        }
        when {
            rightEdge -> {
                val step = 180f / (n - 1).coerceAtLeast(1)
                for (i in 0 until n) {
                    items[i].angleDeg = (270f - i * step + 360f) % 360f
                }
            }
            leftEdge -> {
                val step = 180f / (n - 1).coerceAtLeast(1)
                for (i in 0 until n) {
                    items[i].angleDeg = (270f + i * step) % 360f
                }
            }
            else -> {
                val step = 360f / n
                for (i in 0 until n) {
                    items[i].angleDeg = (270f + i * step) % 360f
                }
            }
        }
    }

    private fun showRadialMenu() {
        dismissRadialMenu()
        val p = params ?: return
        val s = screen()
        val cx = (p.x + size / 2).toFloat()
        val cy = (p.y + size / 2).toFloat()
        val items = buildRadialItems()
        assignAngles(items, cx, s.width().toFloat())

        val view = RadialMenuView(context, cx, cy, items)
        val mp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            overlayType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 0
            y = 0
        }
        try {
            wm.addView(view, mp)
            radialMenu = view
            wake(animateOut = false)
        } catch (_: Exception) {}
    }

    private fun dismissRadialMenu() {
        val rm = radialMenu ?: return
        radialMenu = null
        rm.animate().alpha(0f).setDuration(120).withEndAction {
            try { wm.removeView(rm) } catch (_: Exception) {}
        }.start()
        scheduleIdle()
    }

    private fun showDismissTarget() {
        if (dismissTarget != null) return
        val view = DismissTargetView(context)
        val p = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            overlayType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 0
            y = 0
        }
        try {
            wm.addView(view, p)
            dismissTarget = view
            view.alpha = 0f
            view.animate().alpha(1f).setDuration(160).start()
        } catch (_: Exception) {}
    }

    private fun dismissDismissTarget() {
        val dt = dismissTarget ?: return
        dismissTarget = null
        dt.animate().alpha(0f).setDuration(140).withEndAction {
            try { wm.removeView(dt) } catch (_: Exception) {}
        }.start()
    }

    private fun temporarilyHideBubble() {
        if (isRunning()) {
            sendAction("task_toggle")
        }
        temporarilyHidden = true
        lastHiddenTaskTitle = widgetPrefs.getString("arcane.task.title", "") ?: ""
        hide()
        Toast.makeText(context, "Task paused. Floating button hidden until next task.", Toast.LENGTH_SHORT).show()
    }

    // ── Double-tap: Check + Add Checkpoint ──────────────────────

    @SuppressLint("ClickableViewAccessibility")
    private fun showCheckpointDialog() {
        dismissRadialMenu()
        dismissDismissTarget()
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
            setPadding(dp(20f), dp(18f), dp(20f), dp(14f))
            isClickable = true
            background = GradientDrawable().apply {
                setColor(BG_DARK)
                cornerRadius = dp(18f).toFloat()
                setStroke(dp(1.2f), CYAN and 0x66FFFFFF)
            }
            elevation = dp(12f).toFloat()
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
            setPadding(dp(14f), dp(12f), dp(14f), dp(12f))
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
        ).apply { topMargin = dp(10f) })

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

    // ── Tactical Bubble View ────────────────────────────────────

    @SuppressLint("ViewConstructor")
    private inner class BubbleView(ctx: Context) : View(ctx) {
        private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        private val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = dp(3.5f).toFloat()
        }
        private val outerHairlinePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = dp(1f).toFloat()
        }
        private val trackPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = dp(2.6f).toFloat()
            color = 0x1AFFFFFF
        }
        private val arcPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = dp(2.8f).toFloat()
            strokeCap = Paint.Cap.ROUND
        }
        private val reticlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = dp(1.2f).toFloat()
        }
        private val glyphPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
        }
        private val timePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textAlign = Paint.Align.CENTER
            textSize = dp(8.4f).toFloat()
            typeface = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD)
            setShadowLayer(dp(1.2f).toFloat(), 0f, dp(1f).toFloat(), 0xAA000000.toInt())
        }

        private val playPath = Path()
        private val playCornerEffect = CornerPathEffect(dp(2.2f).toFloat())
        private val arcRect = RectF()

        var isPressedState = false
        var isDockedState = false
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
            if (dragging) return@Runnable
            longPressed = true
            performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
            showRadialMenu()
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

        private fun elapsedSeconds(): Long {
            val acc = WidgetCommon.getSafeLong(widgetPrefs, "arcane.task.accumulatedSec", 0L)
            val start = WidgetCommon.getSafeLong(widgetPrefs, "arcane.task.sessionStartMs", 0L)
            val live = if (running && start > 0L) ((System.currentTimeMillis() - start) / 1000L).coerceAtLeast(0L) else 0L
            return acc + live
        }

        private fun elapsedLabel(): String {
            val sec = elapsedSeconds()
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
            val h = height.toFloat()
            val cx = w / 2f
            val cy = h / 2f
            val r = (w / 2f) - dp(3.5f)

            if (isPressedState) {
                canvas.scale(0.94f, 0.94f, cx, cy)
            }

            val accent = when {
                !hasTask -> MUTED
                running -> CYAN
                else -> AMBER
            }

            // 1. Outer ambient glow halo
            glowPaint.color = accent and 0x24FFFFFF
            canvas.drawCircle(cx, cy, r, glowPaint)

            // 2. Multi-gradient dark glass disc
            val shader = LinearGradient(
                0f, 0f, w, h,
                0xF20F1D30.toInt(), 0xF804070D.toInt(),
                Shader.TileMode.CLAMP,
            )
            fillPaint.shader = shader
            canvas.drawCircle(cx, cy, r - dp(1.2f), fillPaint)

            // 3. Inner specular rim highlight
            outerHairlinePaint.color = 0x22FFFFFF
            canvas.drawCircle(cx, cy, r - dp(1.2f), outerHairlinePaint)

            // 4. Progress track & glowing arc
            val arcR = r - dp(3.2f)
            arcRect.set(cx - arcR, cy - arcR, cx + arcR, cy + arcR)
            canvas.drawCircle(cx, cy, arcR, trackPaint)
            if (hasTask && progress > 0) {
                arcPaint.color = accent
                canvas.drawArc(arcRect, -90f, 360f * progress / 100f, false, arcPaint)
            }

            // 5. Tactical Reticle Crosshairs at cardinal points (0°, 90°, 180°, 270°)
            reticlePaint.color = accent and 0x66FFFFFF
            val tickLen = dp(3.2f).toFloat()
            canvas.drawLine(cx, cy - r + dp(1.5f), cx, cy - r + dp(1.5f) + tickLen, reticlePaint)
            canvas.drawLine(cx, cy + r - dp(1.5f) - tickLen, cx, cy + r - dp(1.5f), reticlePaint)
            canvas.drawLine(cx - r + dp(1.5f), cy, cx - r + dp(1.5f) + tickLen, cy, reticlePaint)
            canvas.drawLine(cx + r - dp(1.5f) - tickLen, cy, cx + r - dp(1.5f), cy, reticlePaint)

            // 6. Glyph
            glyphPaint.color = if (pending) Color.WHITE else accent
            val hasTime = running || (hasTask && elapsedSeconds() > 0)
            val gy = if (hasTime) cy - dp(4.5f) else cy

            when {
                !hasTask -> {
                    // 3 tactical rounded horizontal lines: open plan
                    val lh = dp(2f).toFloat()
                    val lw = dp(11f).toFloat()
                    for (i in -1..1) {
                        val y = gy + i * dp(3.8f)
                        canvas.drawRoundRect(cx - lw / 2, y - lh / 2, cx + lw / 2, y + lh / 2, lh, lh, glyphPaint)
                    }
                }
                running -> {
                    // Two sleek vertical pause bars
                    val barW = dp(3.2f).toFloat()
                    val barH = dp(11f).toFloat()
                    val gap = dp(4.6f).toFloat()
                    val rx = dp(1.6f).toFloat()
                    canvas.drawRoundRect(cx - gap / 2 - barW, gy - barH / 2, cx - gap / 2, gy + barH / 2, rx, rx, glyphPaint)
                    canvas.drawRoundRect(cx + gap / 2, gy - barH / 2, cx + gap / 2 + barW, gy + barH / 2, rx, rx, glyphPaint)
                }
                else -> {
                    // Play triangle with rounded corners
                    val triH = dp(11f).toFloat()
                    val triW = dp(9.5f).toFloat()
                    playPath.reset()
                    playPath.moveTo(cx - triW * 0.45f, gy - triH * 0.5f)
                    playPath.lineTo(cx + triW * 0.55f, gy)
                    playPath.lineTo(cx - triW * 0.45f, gy + triH * 0.5f)
                    playPath.close()
                    glyphPaint.pathEffect = playCornerEffect
                    canvas.drawPath(playPath, glyphPaint)
                    glyphPaint.pathEffect = null
                }
            }

            // 7. Telemetry readout (MM:SS)
            if (hasTime) {
                timePaint.color = if (running) Color.WHITE else (accent and 0xCCFFFFFF.toInt())
                canvas.drawText(elapsedLabel(), cx, cy + dp(10.5f), timePaint)
            }
        }

        @SuppressLint("ClickableViewAccessibility")
        override fun onTouchEvent(e: MotionEvent): Boolean {
            val p = params ?: return false
            when (e.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    snapAnim?.cancel()
                    dockAnim?.cancel()
                    isPressedState = true
                    invalidate()
                    wake(animateOut = true)
                    performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)

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
                    if (longPressed) {
                        radialMenu?.onDrag(dx, dy)
                    } else {
                        if (!dragging && (abs(dx) > touchSlop || abs(dy) > touchSlop)) {
                            dragging = true
                            removeCallbacks(longPress)
                            dismissRadialMenu()
                            showDismissTarget()
                        }
                        if (dragging) {
                            move(startX + dx.roundToInt(), startY + dy.roundToInt())
                            dismissTarget?.updateBubble(p.x + size / 2, p.y + size / 2)
                        }
                    }
                }
                MotionEvent.ACTION_UP -> {
                    isPressedState = false
                    invalidate()
                    removeCallbacks(longPress)
                    when {
                        longPressed -> {
                            longPressed = false
                            val action = radialMenu?.getSelectedAction()
                            if (action != null) {
                                performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
                                dismissRadialMenu()
                                action()
                            } else {
                                radialMenu?.enableDirectTouch()
                            }
                            snapToEdge()
                        }
                        dragging -> {
                            val hovered = dismissTarget?.isTargetHovered == true
                            dismissDismissTarget()
                            if (hovered) {
                                temporarilyHideBubble()
                            } else {
                                snapToEdge()
                            }
                        }
                        else -> {
                            dismissRadialMenu()
                            if (awaitingSecondTap) {
                                // Double-tap: check checkpoint + add next one
                                removeCallbacks(singleTap)
                                awaitingSecondTap = false
                                performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
                                showCheckpointDialog()
                            } else {
                                // Wait double-tap timeout before firing single-tap
                                performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
                                awaitingSecondTap = true
                                postDelayed(singleTap, ViewConfiguration.getDoubleTapTimeout().toLong())
                            }
                        }
                    }
                    if (radialMenu == null) scheduleIdle()
                }
                MotionEvent.ACTION_CANCEL -> {
                    isPressedState = false
                    invalidate()
                    removeCallbacks(longPress)
                    if (longPressed) {
                        longPressed = false
                        dismissRadialMenu()
                        snapToEdge()
                    }
                    if (dragging) {
                        dismissDismissTarget()
                        snapToEdge()
                    }
                    scheduleIdle()
                }
            }
            return true
        }
    }

    // ── Radial Emote Menu View ──────────────────────────────────

    @SuppressLint("ViewConstructor")
    private inner class RadialMenuView(
        ctx: Context,
        private val cx: Float,
        private val cy: Float,
        private val items: List<RadialItem>,
    ) : View(ctx) {
        private val orbitRadius = dp(84f).toFloat()
        private val nodeRadius = dp(21f).toFloat()
        private val deadZone = dp(24f).toFloat()
        private var selectedIndex = -1
        private var isDirectTouchEnabled = false

        private val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        private val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
        }
        private val haloPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
        }
        private val laserPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeCap = Paint.Cap.ROUND
        }
        private val reticlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
        }
        private val glyphPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textAlign = Paint.Align.CENTER
            typeface = Typeface.DEFAULT_BOLD
        }
        private val labelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textAlign = Paint.Align.CENTER
            textSize = dp(9.5f).toFloat()
            typeface = Typeface.DEFAULT_BOLD
            letterSpacing = 0.08f
        }
        private val badgePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textAlign = Paint.Align.CENTER
            textSize = dp(12.5f).toFloat()
            typeface = Typeface.DEFAULT_BOLD
            letterSpacing = 0.12f
        }
        private val pillBounds = RectF()

        private val autoDismissRunnable = Runnable { dismissRadialMenu() }

        init {
            postDelayed(autoDismissRunnable, 6000)
        }

        fun onDrag(dragDx: Float, dragDy: Float) {
            val dist = hypot(dragDx, dragDy)
            if (dist >= deadZone) {
                val rad = atan2(dragDy.toDouble(), dragDx.toDouble())
                var deg = Math.toDegrees(rad).toFloat()
                if (deg < 0f) deg += 360f
                val newIndex = items.indices.minByOrNull { angularDiff(items[it].angleDeg, deg) } ?: -1
                if (newIndex != selectedIndex) {
                    selectedIndex = newIndex
                    performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                    invalidate()
                }
            } else {
                if (selectedIndex != -1) {
                    selectedIndex = -1
                    invalidate()
                }
            }
        }

        fun getSelectedAction(): (() -> Unit)? =
            if (selectedIndex in items.indices) items[selectedIndex].action else null

        fun enableDirectTouch() {
            isDirectTouchEnabled = true
            val p = layoutParams as? WindowManager.LayoutParams ?: return
            p.flags = p.flags and WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE.inv()
            try { wm.updateViewLayout(this, p) } catch (_: Exception) {}
            removeCallbacks(autoDismissRunnable)
            postDelayed(autoDismissRunnable, 5000)
        }

        override fun onDetachedFromWindow() {
            removeCallbacks(autoDismissRunnable)
            super.onDetachedFromWindow()
        }

        @SuppressLint("ClickableViewAccessibility")
        override fun onTouchEvent(e: MotionEvent): Boolean {
            if (!isDirectTouchEnabled) return false
            if (e.actionMasked == MotionEvent.ACTION_DOWN) {
                val touched = items.indices.firstOrNull { i ->
                    val rad = Math.toRadians(items[i].angleDeg.toDouble())
                    val nx = cx + cos(rad).toFloat() * orbitRadius
                    val ny = cy + sin(rad).toFloat() * orbitRadius
                    hypot(e.x - nx, e.y - ny) <= nodeRadius + dp(14f)
                }
                if (touched != null && touched >= 0) {
                    performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
                    val action = items[touched].action
                    dismissRadialMenu()
                    action()
                } else {
                    dismissRadialMenu()
                }
                return true
            }
            return super.onTouchEvent(e)
        }

        override fun onDraw(canvas: Canvas) {
            val w = width.toFloat()
            val h = height.toFloat()
            if (w <= 0f || h <= 0f) return

            // Scrim
            bgPaint.color = 0x66000000
            canvas.drawRect(0f, 0f, w, h, bgPaint)

            // Concentric orbit track
            reticlePaint.color = 0x1A00F0FF
            reticlePaint.strokeWidth = dp(1f).toFloat()
            canvas.drawCircle(cx, cy, orbitRadius, reticlePaint)
            canvas.drawCircle(cx, cy, dp(18f).toFloat(), reticlePaint)

            val selIndex = selectedIndex
            val selItem = if (selIndex in items.indices) items[selIndex] else null

            // Laser beam to selected item
            if (selItem != null) {
                val selRad = Math.toRadians(selItem.angleDeg.toDouble())
                val snx = cx + cos(selRad).toFloat() * orbitRadius
                val sny = cy + sin(selRad).toFloat() * orbitRadius

                laserPaint.color = selItem.color and 0x33FFFFFF
                laserPaint.strokeWidth = dp(6f).toFloat()
                canvas.drawLine(cx, cy, snx, sny, laserPaint)

                laserPaint.color = selItem.color
                laserPaint.strokeWidth = dp(2.4f).toFloat()
                canvas.drawLine(cx, cy, snx, sny, laserPaint)
            }

            // Option circles
            for (i in items.indices) {
                val item = items[i]
                val rad = Math.toRadians(item.angleDeg.toDouble())
                val nx = cx + cos(rad).toFloat() * orbitRadius
                val ny = cy + sin(rad).toFloat() * orbitRadius
                val isSelected = (i == selIndex)
                val r = if (isSelected) dp(25f).toFloat() else nodeRadius

                // Ambient Halo
                if (isSelected) {
                    haloPaint.color = item.color and 0x44FFFFFF
                    haloPaint.strokeWidth = dp(6f).toFloat()
                    canvas.drawCircle(nx, ny, r + dp(2.5f), haloPaint)
                }

                // Fill
                fillPaint.color = if (isSelected) 0xF2121F2F.toInt() else 0xF206090E.toInt()
                canvas.drawCircle(nx, ny, r, fillPaint)

                // Border
                strokePaint.color = if (isSelected) item.color else 0x44FFFFFF
                strokePaint.strokeWidth = if (isSelected) dp(2.2f).toFloat() else dp(1.2f).toFloat()
                canvas.drawCircle(nx, ny, r, strokePaint)

                // Glyph
                glyphPaint.color = if (isSelected) item.color else Color.WHITE
                glyphPaint.textSize = if (isSelected) dp(16f).toFloat() else dp(14f).toFloat()
                canvas.drawText(item.glyph, nx, ny + dp(5f), glyphPaint)

                // Label
                labelPaint.color = if (isSelected) item.color else MUTED
                val labelY = if (sin(rad) < -0.7) ny - r - dp(6f) else ny + r + dp(12f)
                canvas.drawText(item.label, nx, labelY, labelPaint)
            }

            // Center HUD pill badge
            val badgeText = if (selItem != null) "${selItem.glyph}  ${selItem.label}" else "DRAG TO CHOOSE"
            val badgeColor = selItem?.color ?: MUTED
            val badgeW = badgePaint.measureText(badgeText) + dp(28f)
            val badgeH = dp(28f).toFloat()
            val badgeX = cx.coerceIn(badgeW / 2f + dp(12f), w - badgeW / 2f - dp(12f))
            val badgeY = if (cy > h * 0.55f) (cy - orbitRadius - dp(38f)).coerceAtLeast(badgeH)
                         else (cy + orbitRadius + dp(38f)).coerceAtMost(h - badgeH)

            pillBounds.set(badgeX - badgeW / 2f, badgeY - badgeH / 2f, badgeX + badgeW / 2f, badgeY + badgeH / 2f)
            fillPaint.color = 0xEE080E16.toInt()
            canvas.drawRoundRect(pillBounds, dp(14f).toFloat(), dp(14f).toFloat(), fillPaint)

            strokePaint.color = badgeColor and 0x88FFFFFF.toInt()
            strokePaint.strokeWidth = dp(1.2f).toFloat()
            canvas.drawRoundRect(pillBounds, dp(14f).toFloat(), dp(14f).toFloat(), strokePaint)

            badgePaint.color = badgeColor
            canvas.drawText(badgeText, badgeX, badgeY + dp(4.5f), badgePaint)
        }
    }

    // ── Bottom Dismiss Target View ──────────────────────────────

    @SuppressLint("ViewConstructor")
    private inner class DismissTargetView(ctx: Context) : View(ctx) {
        private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        private val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
        }
        private val haloPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
        }
        private val crossPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeCap = Paint.Cap.ROUND
        }
        private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textAlign = Paint.Align.CENTER
            textSize = dp(10f).toFloat()
            typeface = Typeface.DEFAULT_BOLD
            letterSpacing = 0.12f
        }

        var isTargetHovered = false
            private set

        fun updateBubble(bx: Int, by: Int) {
            val tcx = width / 2f
            val tcy = height - dp(75f).toFloat()
            val dist = hypot(bx - tcx, by - tcy)
            val hovered = dist <= dp(68f)
            if (hovered != isTargetHovered) {
                isTargetHovered = hovered
                if (isTargetHovered) {
                    performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                }
                invalidate()
            }
        }

        override fun onDraw(canvas: Canvas) {
            val w = width.toFloat()
            val h = height.toFloat()
            if (w <= 0f || h <= 0f) return

            val tcx = w / 2f
            val tcy = h - dp(75f).toFloat()
            val r = if (isTargetHovered) dp(32f).toFloat() else dp(26f).toFloat()

            // Bottom subtle gradient scrim
            val scrimShader = LinearGradient(
                0f, h - dp(140f).toFloat(), 0f, h,
                0x00000000, 0x88000000.toInt(),
                Shader.TileMode.CLAMP,
            )
            fillPaint.shader = scrimShader
            canvas.drawRect(0f, h - dp(140f).toFloat(), w, h, fillPaint)
            fillPaint.shader = null

            // Glow halo when hovered
            if (isTargetHovered) {
                haloPaint.color = 0x55FF3B5C.toInt()
                haloPaint.strokeWidth = dp(7f).toFloat()
                canvas.drawCircle(tcx, tcy, r + dp(3f), haloPaint)
            }

            // Disc
            fillPaint.color = if (isTargetHovered) 0xCCFF3B5C.toInt() else 0xD9080E16.toInt()
            canvas.drawCircle(tcx, tcy, r, fillPaint)

            // Border
            strokePaint.color = if (isTargetHovered) 0xFFFF3B5C.toInt() else 0x55FFFFFF
            strokePaint.strokeWidth = if (isTargetHovered) dp(2.4f).toFloat() else dp(1.2f).toFloat()
            canvas.drawCircle(tcx, tcy, r, strokePaint)

            // '✕' icon
            val crossHalf = if (isTargetHovered) dp(8.5f).toFloat() else dp(7f).toFloat()
            crossPaint.color = Color.WHITE
            crossPaint.strokeWidth = if (isTargetHovered) dp(2.8f).toFloat() else dp(2.2f).toFloat()
            canvas.drawLine(tcx - crossHalf, tcy - crossHalf, tcx + crossHalf, tcy + crossHalf, crossPaint)
            canvas.drawLine(tcx + crossHalf, tcy - crossHalf, tcx - crossHalf, tcy + crossHalf, crossPaint)

            // Label below target
            textPaint.color = if (isTargetHovered) 0xFFFF3B5C.toInt() else 0x88FFFFFF.toInt()
            canvas.drawText(if (isTargetHovered) "RELEASE TO HIDE" else "DRAG TO HIDE", tcx, tcy + r + dp(14f), textPaint)
        }
    }
}
