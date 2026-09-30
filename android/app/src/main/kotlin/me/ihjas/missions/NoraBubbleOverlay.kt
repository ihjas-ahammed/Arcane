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
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.text.TextUtils
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import me.ihjas.missions.widgets.WidgetCommon
import java.util.Locale
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sin

/**
 * Tactical floating NORA AI assistant HUD overlay, drawn by [LauncherTakeoverService]
 * as an accessibility overlay (requires zero special overlay permissions).
 *
 * Designed for hands-free smartwatch / Bluetooth headset interactions:
 *  - High-tech Cyberpunk HUD disc with audio-reactive ambient halo glow (RMS dB).
 *  - Auto-starts microphone immediately on trigger with Bluetooth SCO audio routing.
 *  - Real-time live transcript and streaming AI response display in attached floating card.
 *  - Idle side docking: tucks neatly against the screen bezel after inactivity.
 *  - Tap to toggle voice listening, tap expand [⤢] to open full-screen NoraAiScreen in Arcane.
 */
class NoraBubbleOverlay(private val context: Context) {

    companion object {
        private const val PREFS = "arcane_launcher"
        private const val KEY_ENABLED = "floating_nora_enabled"
        private const val KEY_WATCH_FLOATING = "floating_nora_watch_enabled"
        private const val KEY_RIGHT = "nora_bubble_right"
        private const val KEY_Y = "nora_bubble_y"

        private const val IDLE_ALPHA = 0.42f
        private const val IDLE_DELAY_MS = 3500L

        private const val BG_DARK = 0xF6080B14.toInt()
        private const val PURPLE = 0xFFBD00FF.toInt()
        private const val CYAN = 0xFF00F0FF.toInt()
        private const val GREEN = 0xFF00FFA3.toInt()
        private const val MUTED = 0xFF8A99AD.toInt()

        @Volatile
        var instance: NoraBubbleOverlay? = null
            private set

        fun isEnabled(context: Context): Boolean =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_ENABLED, true)

        fun setEnabled(context: Context, enabled: Boolean) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(KEY_ENABLED, enabled).apply()
            instance?.sync()
        }

        fun isFloatingForWatch(context: Context): Boolean =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_WATCH_FLOATING, true)

        fun setFloatingForWatch(context: Context, enabled: Boolean) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(KEY_WATCH_FLOATING, enabled).apply()
        }

        /** Summon floating Nora overlay and immediately begin hands-free listening. */
        fun summonAndListen(context: Context) {
            val inst = instance
            if (inst != null) {
                inst.showAndListen()
            } else {
                // If accessibility service is not yet running or inst null, trigger via launch intent
                val intent = Intent(context, MainActivity::class.java).apply {
                    action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
                    data = Uri.Builder().scheme("arcane").authority("widget").appendQueryParameter("action", "open_nora_voice").build()
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                }
                try { context.startActivity(intent) } catch (_: Exception) {}
            }
        }
    }

    private val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
    private val handler = Handler(Looper.getMainLooper())
    private val density = context.resources.displayMetrics.density
    private fun dp(v: Float) = (v * density).roundToInt()

    private val size = dp(56f)
    private val edgeMargin = dp(6f)
    private val tuckPx = (size * 0.36f).roundToInt()

    private val settingsPrefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private val widgetPrefs = WidgetCommon.prefs(context)

    private var bubble: NoraView? = null
    private var params: WindowManager.LayoutParams? = null
    private var cardView: View? = null
    private var cardParams: WindowManager.LayoutParams? = null

    private var snapAnim: ValueAnimator? = null
    private var dockAnim: ValueAnimator? = null
    private var pulseAnim: ValueAnimator? = null
    private var isDocked = false
    private var started = false

    private var speechRecognizer: SpeechRecognizer? = null
    private var isListening = false
    private var isThinking = false
    private var currentRms: Float = 0f
    private var liveTranscript = ""
    private var noraResponse = ""

    private val settingsListener = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
        if (key == KEY_ENABLED || key == KEY_WATCH_FLOATING) sync()
    }

    private val widgetListener = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
        if (key != null && key.startsWith("arcane.nora.")) {
            handler.post {
                val state = widgetPrefs.getString("arcane.nora.state", "idle") ?: "idle"
                val resp = widgetPrefs.getString("arcane.nora.response", "") ?: ""
                isThinking = state == "thinking"
                if (resp.isNotEmpty() && resp != noraResponse) {
                    noraResponse = resp
                    updateCardContent()
                }
                bubble?.invalidate()
            }
        }
    }

    fun start() {
        if (started) return
        started = true
        instance = this
        settingsPrefs.registerOnSharedPreferenceChangeListener(settingsListener)
        widgetPrefs.registerOnSharedPreferenceChangeListener(widgetListener)
        sync()
    }

    fun stop() {
        if (!started) return
        started = false
        if (instance == this) instance = null
        settingsPrefs.unregisterOnSharedPreferenceChangeListener(settingsListener)
        widgetPrefs.unregisterOnSharedPreferenceChangeListener(widgetListener)
        stopListening()
        hide()
        dismissCard()
    }

    fun onConfigurationChanged() {
        dismissCard()
        val p = params ?: return
        val b = bubble ?: return
        placeFromPrefs(p)
        try { wm.updateViewLayout(b, p) } catch (_: Exception) {}
    }

    private fun sync() {
        if (started && isEnabled(context)) {
            show()
        } else {
            hide()
        }
    }

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
        val view = NoraView(context)
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
            isDocked = false
            scheduleIdle()
        } catch (_: Exception) {}
    }

    private fun hide() {
        dismissCard()
        stopListening()
        snapAnim?.cancel()
        dockAnim?.cancel()
        pulseAnim?.cancel()
        handler.removeCallbacks(idleRunnable)
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
        val yFrac = settingsPrefs.getFloat(KEY_Y, 0.40f).coerceIn(0f, 1f)
        p.x = if (isDocked) dockedX() else normalRestingX()
        p.y = (yFrac * (s.height() - size)).roundToInt()
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
                p.x = it.animatedValue as Int
                try { wm.updateViewLayout(bubble, p) } catch (_: Exception) {}
                updateCardPosition()
            }
            start()
        }
    }

    private fun scheduleIdle() {
        handler.removeCallbacks(idleRunnable)
        if (!isListening && cardView == null) {
            handler.postDelayed(idleRunnable, IDLE_DELAY_MS)
        }
    }

    private val idleRunnable = Runnable { settleToSide() }

    private fun settleToSide() {
        if (cardView != null || bubble == null || isListening) return
        val p = params ?: return
        val b = bubble ?: return
        val targetX = dockedX()

        snapAnim?.cancel()
        dockAnim?.cancel()

        val startX = p.x
        val startAlpha = b.alpha

        dockAnim = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 300
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

    // ── Speech Recognition & Audio Routing ─────────────────────

    fun showAndListen() {
        handler.post {
            show()
            wake(animateOut = true)
            showCard()
            startListening()
        }
    }

    private fun routeBluetoothAudio(enable: Boolean) {
        try {
            val am = audioManager ?: return
            if (enable) {
                am.mode = AudioManager.MODE_IN_COMMUNICATION
                am.isSpeakerphoneOn = false
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    val devices = am.availableCommunicationDevices
                    val btDevice = devices.firstOrNull {
                        it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
                        it.type == AudioDeviceInfo.TYPE_BLE_HEADSET ||
                        it.type == AudioDeviceInfo.TYPE_HEARING_AID
                    }
                    if (btDevice != null) am.setCommunicationDevice(btDevice)
                } else {
                    if (am.isBluetoothScoAvailableOffCall && !am.isBluetoothScoOn) {
                        am.startBluetoothSco()
                        am.isBluetoothScoOn = true
                    }
                }
            } else {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    am.clearCommunicationDevice()
                }
                if (am.isBluetoothScoOn) {
                    am.stopBluetoothSco()
                    am.isBluetoothScoOn = false
                }
                am.mode = AudioManager.MODE_NORMAL
            }
        } catch (_: Exception) {}
    }

    private fun startListening() {
        if (isListening) return
        wake(animateOut = true)
        showCard()
        routeBluetoothAudio(true)

        liveTranscript = ""
        noraResponse = ""
        isListening = true
        isThinking = false
        updateCardContent()
        bubble?.invalidate()

        try {
            speechRecognizer?.destroy()
            speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context).apply {
                setRecognitionListener(object : RecognitionListener {
                    override fun onReadyForSpeech(params: Bundle?) {
                        isListening = true
                        bubble?.invalidate()
                        updateCardContent()
                    }
                    override fun onBeginningOfSpeech() {}
                    override fun onRmsChanged(rmsdB: Float) {
                        currentRms = rmsdB.coerceAtLeast(0f)
                        bubble?.invalidate()
                    }
                    override fun onBufferReceived(buffer: ByteArray?) {}
                    override fun onEndOfSpeech() {
                        isListening = false
                        isThinking = true
                        currentRms = 0f
                        bubble?.invalidate()
                        updateCardContent()
                    }
                    override fun onError(error: Int) {
                        isListening = false
                        isThinking = false
                        currentRms = 0f
                        routeBluetoothAudio(false)
                        bubble?.invalidate()
                        updateCardContent()
                        scheduleIdle()
                    }
                    override fun onResults(results: Bundle?) {
                        isListening = false
                        isThinking = true
                        currentRms = 0f
                        val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        val text = matches?.firstOrNull() ?: ""
                        if (text.isNotBlank()) {
                            liveTranscript = text
                            updateCardContent()
                            sendPromptToNora(text)
                        } else {
                            isThinking = false
                            updateCardContent()
                        }
                        routeBluetoothAudio(false)
                        bubble?.invalidate()
                    }
                    override fun onPartialResults(partialResults: Bundle?) {
                        val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        val text = matches?.firstOrNull() ?: ""
                        if (text.isNotBlank()) {
                            liveTranscript = text
                            updateCardContent()
                        }
                    }
                    override fun onEvent(eventType: Int, params: Bundle?) {}
                })
            }

            val sttIntent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault().toLanguageTag())
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
                putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, context.packageName)
            }
            speechRecognizer?.startListening(sttIntent)
        } catch (_: Exception) {
            isListening = false
            bubble?.invalidate()
            routeBluetoothAudio(false)
        }
    }

    private fun stopListening() {
        isListening = false
        isThinking = false
        currentRms = 0f
        try { speechRecognizer?.stopListening() } catch (_: Exception) {}
        routeBluetoothAudio(false)
        bubble?.invalidate()
        updateCardContent()
        scheduleIdle()
    }

    private fun sendPromptToNora(text: String) {
        isThinking = true
        updateCardContent()
        widgetPrefs.edit()
            .putString("arcane.nora.prompt", text)
            .putString("arcane.nora.state", "thinking")
            .apply()

        // Dispatch action to Flutter isolate or open app if engine cold
        val dispatched = MainActivity.dispatchWidgetAction("nora_prompt:$text")
        if (!dispatched) {
            // Cold start Arcane with Nora voice action
            val intent = Intent(context, MainActivity::class.java).apply {
                action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
                data = Uri.Builder().scheme("arcane").authority("widget").appendQueryParameter("action", "nora_prompt:$text").build()
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }
            try { context.startActivity(intent) } catch (_: Exception) {}
        }
    }

    private fun openFullNoraScreen() {
        dismissCard()
        val intent = Intent(context, MainActivity::class.java).apply {
            action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
            data = Uri.Builder().scheme("arcane").authority("widget").appendQueryParameter("action", "open_nora").build()
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        try { context.startActivity(intent) } catch (_: Exception) {}
    }

    // ── Floating Tactical HUD Card ─────────────────────────────

    private var cardStatusLabel: TextView? = null
    private var cardTranscriptLabel: TextView? = null
    private var cardResponseLabel: TextView? = null
    private var cardMicButton: TextView? = null

    @SuppressLint("ClickableViewAccessibility")
    private fun showCard() {
        if (cardView != null) return
        val p = params ?: return
        val s = screen()
        val onRight = p.x + size / 2 > s.width() / 2

        val root = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(14f), dp(12f), dp(14f), dp(12f))
            background = GradientDrawable().apply {
                setColor(BG_DARK)
                cornerRadius = dp(16f).toFloat()
                setStroke(dp(1.2f), PURPLE and 0x77FFFFFF)
            }
            elevation = dp(12f).toFloat()
        }

        // Header: Badge + [ ⤢ FULLSCREEN ] + [ ✕ CLOSE ]
        val header = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        val badge = TextView(context).apply {
            text = "● NORA AI"
            setTextColor(CYAN)
            textSize = 11.5f
            letterSpacing = 0.14f
            typeface = Typeface.DEFAULT_BOLD
        }
        cardStatusLabel = badge
        header.addView(badge, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))

        val btnExpand = TextView(context).apply {
            text = "⤢ EXPAND"
            setTextColor(MUTED)
            textSize = 11f
            letterSpacing = 0.1f
            typeface = Typeface.DEFAULT_BOLD
            setPadding(dp(8f), dp(4f), dp(8f), dp(4f))
            setOnClickListener { openFullNoraScreen() }
        }
        header.addView(btnExpand)

        val btnClose = TextView(context).apply {
            text = "✕"
            setTextColor(MUTED)
            textSize = 13f
            typeface = Typeface.DEFAULT_BOLD
            setPadding(dp(8f), dp(4f), dp(8f), dp(4f))
            setOnClickListener {
                stopListening()
                dismissCard()
            }
        }
        header.addView(btnClose)
        root.addView(header)

        // Transcript / Query preview
        val transcript = TextView(context).apply {
            text = "Listening for voice command..."
            setTextColor(Color.WHITE)
            textSize = 13.5f
            setPadding(0, dp(8f), 0, dp(4f))
            maxLines = 2
            ellipsize = TextUtils.TruncateAt.END
        }
        cardTranscriptLabel = transcript
        root.addView(transcript)

        // Nora response scroll view
        val scrollView = ScrollView(context).apply {
            isFillViewport = true
        }
        val response = TextView(context).apply {
            text = ""
            setTextColor(GREEN)
            textSize = 13f
            setPadding(0, dp(4f), 0, dp(8f))
            visibility = View.GONE
        }
        cardResponseLabel = response
        scrollView.addView(response)
        root.addView(scrollView, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(70f)))

        // Actions row: [ 🎙 TALK / STOP ]
        val actions = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.END
        }

        val micBtn = TextView(context).apply {
            text = "■ STOP"
            setTextColor(PURPLE)
            textSize = 12.5f
            letterSpacing = 0.1f
            typeface = Typeface.DEFAULT_BOLD
            setPadding(dp(12f), dp(6f), dp(12f), dp(6f))
            background = GradientDrawable().apply {
                setColor(0x22BD00FF.toInt())
                cornerRadius = dp(8f).toFloat()
                setStroke(dp(1f), PURPLE)
            }
            setOnClickListener {
                if (isListening) stopListening() else startListening()
            }
        }
        cardMicButton = micBtn
        actions.addView(micBtn)
        root.addView(actions)

        val cardWidth = dp(260f)
        val cardHeight = dp(180f)
        val gap = dp(8f)

        val cp = WindowManager.LayoutParams(
            cardWidth,
            cardHeight,
            overlayType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = if (onRight) (p.x - cardWidth - gap).coerceAtLeast(0) else (p.x + size + gap).coerceAtMost(s.width() - cardWidth)
            y = (p.y + size / 2 - cardHeight / 2).coerceIn(0, (s.height() - cardHeight).coerceAtLeast(0))
        }

        try {
            wm.addView(root, cp)
            cardView = root
            cardParams = cp
            updateCardContent()
        } catch (_: Exception) {}
    }

    private fun updateCardPosition() {
        val cp = cardParams ?: return
        val cv = cardView ?: return
        val p = params ?: return
        val s = screen()
        val onRight = p.x + size / 2 > s.width() / 2
        val gap = dp(8f)

        cp.x = if (onRight) (p.x - cp.width - gap).coerceAtLeast(0) else (p.x + size + gap).coerceAtMost(s.width() - cp.width)
        cp.y = (p.y + size / 2 - cp.height / 2).coerceIn(0, (s.height() - cp.height).coerceAtLeast(0))
        try { wm.updateViewLayout(cv, cp) } catch (_: Exception) {}
    }

    private fun updateCardContent() {
        handler.post {
            cardStatusLabel?.apply {
                when {
                    isListening -> {
                        text = "● LISTENING..."
                        setTextColor(CYAN)
                    }
                    isThinking -> {
                        text = "◐ THINKING..."
                        setTextColor(PURPLE)
                    }
                    noraResponse.isNotEmpty() -> {
                        text = "✓ NORA ONLINE"
                        setTextColor(GREEN)
                    }
                    else -> {
                        text = "● NORA READY"
                        setTextColor(MUTED)
                    }
                }
            }

            cardTranscriptLabel?.apply {
                text = when {
                    liveTranscript.isNotEmpty() -> "\"$liveTranscript\""
                    isListening -> "Listening to your voice..."
                    isThinking -> "Processing with Gemini Flash-Live..."
                    else -> "Tap talk to speak with Nora"
                }
            }

            cardResponseLabel?.apply {
                if (noraResponse.isNotEmpty()) {
                    text = noraResponse
                    visibility = View.VISIBLE
                } else {
                    visibility = View.GONE
                }
            }

            cardMicButton?.apply {
                if (isListening) {
                    text = "■ STOP"
                    setTextColor(Color.RED)
                } else {
                    text = "🎙 TALK"
                    setTextColor(PURPLE)
                }
            }
        }
    }

    private fun dismissCard() {
        cardView?.let { try { wm.removeView(it) } catch (_: Exception) {} }
        cardView = null
        cardParams = null
        cardStatusLabel = null
        cardTranscriptLabel = null
        cardResponseLabel = null
        cardMicButton = null
        scheduleIdle()
    }

    // ── Tactical Bubble View ────────────────────────────────────

    @SuppressLint("ViewConstructor")
    private inner class NoraView(ctx: Context) : View(ctx) {
        private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        private val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = dp(3.5f).toFloat()
        }
        private val ringPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = dp(1.8f).toFloat()
        }
        private val reticlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = dp(1.2f).toFloat()
        }
        private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textAlign = Paint.Align.CENTER
            textSize = dp(9f).toFloat()
            typeface = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD)
        }

        var isPressedState = false
        var isDockedState = false

        private val touchSlop = ViewConfiguration.get(ctx).scaledTouchSlop
        private var downRawX = 0f
        private var downRawY = 0f
        private var startX = 0
        private var startY = 0
        private var dragging = false
        private var longPressed = false

        private val longPressRunnable = Runnable {
            longPressed = true
            performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
            openFullNoraScreen()
        }

        init {
            contentDescription = "Nora Voice Assistant"
        }

        override fun onDraw(canvas: Canvas) {
            val w = width.toFloat()
            val h = height.toFloat()
            val cx = w / 2f
            val cy = h / 2f
            val baseR = (w / 2f) - dp(4f)

            if (isPressedState) {
                canvas.scale(0.92f, 0.92f, cx, cy)
            }

            val accent = when {
                isListening -> CYAN
                isThinking -> PURPLE
                else -> if (isDockedState) MUTED else PURPLE
            }

            // 1. Halo Glow (scales with RMS dB when listening!)
            val rmsScale = if (isListening) (currentRms / 10f).coerceIn(0f, 1f) * dp(5f) else 0f
            glowPaint.color = accent and 0x33FFFFFF
            glowPaint.strokeWidth = dp(3.5f).toFloat() + rmsScale
            canvas.drawCircle(cx, cy, baseR + dp(1f), glowPaint)

            // 2. Tactical Glass Background
            fillPaint.shader = LinearGradient(
                cx, cy - baseR, cx, cy + baseR,
                BG_DARK, 0xF6030508.toInt(),
                Shader.TileMode.CLAMP
            )
            fillPaint.style = Paint.Style.FILL
            canvas.drawCircle(cx, cy, baseR, fillPaint)

            // 3. Glowing Outer Reticle Ring
            ringPaint.color = accent
            canvas.drawCircle(cx, cy, baseR, ringPaint)

            // 4. Subtle Compass Reticle Ticks
            reticlePaint.color = accent and 0x88FFFFFF.toInt()
            for (i in 0 until 4) {
                val angle = Math.toRadians((i * 90).toDouble())
                val x1 = cx + (baseR - dp(4f)) * cos(angle).toFloat()
                val y1 = cy + (baseR - dp(4f)) * sin(angle).toFloat()
                val x2 = cx + baseR * cos(angle).toFloat()
                val y2 = cy + baseR * sin(angle).toFloat()
                canvas.drawLine(x1, y1, x2, y2, reticlePaint)
            }

            // 5. Center Monospace Label or Mic Indicator
            textPaint.color = if (isListening) CYAN else Color.WHITE
            val label = when {
                isListening -> "● REC"
                isThinking -> "WAIT"
                else -> "NORA"
            }
            val textY = cy - (textPaint.descent() + textPaint.ascent()) / 2f
            canvas.drawText(label, cx, textY, textPaint)
        }

        @SuppressLint("ClickableViewAccessibility")
        override fun onTouchEvent(event: MotionEvent): Boolean {
            val p = params ?: return false
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    wake(animateOut = false)
                    downRawX = event.rawX
                    downRawY = event.rawY
                    startX = p.x
                    startY = p.y
                    dragging = false
                    longPressed = false
                    isPressedState = true
                    invalidate()
                    handler.postDelayed(longPressRunnable, 600)
                    return true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - downRawX
                    val dy = event.rawY - downRawY
                    if (!dragging && (Math.abs(dx) > touchSlop || Math.abs(dy) > touchSlop)) {
                        dragging = true
                        handler.removeCallbacks(longPressRunnable)
                        dismissCard()
                    }
                    if (dragging) {
                        val s = screen()
                        p.x = (startX + dx).roundToInt().coerceIn(-tuckPx, s.width() - size + tuckPx)
                        p.y = (startY + dy).roundToInt().coerceIn(0, s.height() - size)
                        try { wm.updateViewLayout(this, p) } catch (_: Exception) {}
                        updateCardPosition()
                    }
                    return true
                }
                MotionEvent.ACTION_UP -> {
                    handler.removeCallbacks(longPressRunnable)
                    isPressedState = false
                    invalidate()
                    if (dragging) {
                        snapToEdge()
                    } else if (!longPressed) {
                        performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
                        if (cardView == null) {
                            showCard()
                            startListening()
                        } else {
                            if (isListening) stopListening() else startListening()
                        }
                    }
                    scheduleIdle()
                    return true
                }
                MotionEvent.ACTION_CANCEL -> {
                    handler.removeCallbacks(longPressRunnable)
                    isPressedState = false
                    invalidate()
                    if (dragging) snapToEdge()
                    scheduleIdle()
                    return true
                }
            }
            return super.onTouchEvent(event)
        }
    }
}
