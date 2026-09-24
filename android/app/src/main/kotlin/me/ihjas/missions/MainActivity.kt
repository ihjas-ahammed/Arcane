package me.ihjas.missions

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity(), TextToSpeech.OnInitListener {

    private var tts: TextToSpeech? = null
    private var ttsReady = false

    companion object {
        const val CHANNEL = "arcane/widget"
        const val TTS_CHANNEL = "arcane/tts"
        const val ASSISTANT_CHANNEL = "arcane/assistant"

        @Volatile
        private var channel: MethodChannel? = null

        @Volatile
        private var ttsMethodChannel: MethodChannel? = null

        @Volatile
        private var assistantMethodChannel: MethodChannel? = null

        @Volatile
        private var engineAlive = false

        @Volatile
        private var pendingAssistantAction: String? = null

        /**
         * Deliver a widget action to the running Flutter isolate. Returns false
         * when the app process/engine isn't alive, so the caller can fall back
         * to launching the app.
         */
        fun dispatchWidgetAction(action: String): Boolean {
            val ch = channel
            if (!engineAlive || ch == null) {
                pendingAssistantAction = action
                return false
            }
            Handler(Looper.getMainLooper()).post {
                try {
                    ch.invokeMethod("widgetAction", action)
                } catch (_: Exception) {
                }
            }
            return true
        }

        /**
         * Deliver an energy reply from notification or wearable to Flutter isolate.
         */
        fun dispatchEnergyReply(reply: String, notificationId: Int): Boolean {
            val ch = channel
            if (!engineAlive || ch == null) return false
            Handler(Looper.getMainLooper()).post {
                try {
                    ch.invokeMethod(
                        "energyReply",
                        mapOf("reply" to reply, "notificationId" to notificationId)
                    )
                } catch (_: Exception) {
                }
            }
            return true
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableLockScreenDisplay()
        initTts()
        handleAssistantIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        enableLockScreenDisplay()
        handleAssistantIntent(intent)
    }

    /**
     * Enables displaying activity over the Android lock screen when triggered
     * by Bluetooth voice commands, system assistant, or widget interactions.
     */
    private fun enableLockScreenDisplay() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(true)
                setTurnScreenOn(true)
                val km = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
                km?.requestDismissKeyguard(this, null)
            } else {
                @Suppress("DEPRECATION")
                window.addFlags(
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
                )
            }
        } catch (_: Exception) {
        }
    }

    /**
     * Handles incoming Bluetooth voice command (ACTION_VOICE_COMMAND), system
     * assist (ACTION_ASSIST), and voice assist intents.
     *
     * If user configured a redirector in Settings (e.g. ChatGPT, Gemini, Claude,
     * Perplexity, Copilot, or custom app), it seamlessly launches that assistant.
     * Otherwise (or if external app is missing), it opens Nora in Arcane!
     */
    private fun handleAssistantIntent(intent: Intent?): Boolean {
        if (intent == null) return false
        val action = intent.action ?: return false
        val isVoiceCommand = action == Intent.ACTION_VOICE_COMMAND ||
                action == "android.intent.action.VOICE_COMMAND" ||
                action == Intent.ACTION_ASSIST ||
                action == "android.intent.action.VOICE_ASSIST"
        if (!isVoiceCommand) return false

        enableLockScreenDisplay()

        // Read user's redirect preference from SharedPreferences
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val redirectTarget = prefs.getString("flutter.bluetooth_assistant_redirect_target", "nora") ?: "nora"
        val customPkg = prefs.getString("flutter.bluetooth_assistant_custom_package", "") ?: ""

        if (redirectTarget != "nora") {
            val targetPackage = when (redirectTarget) {
                "chatgpt" -> "com.openai.chatgpt"
                "gemini" -> "com.google.android.apps.googleassistant"
                "claude" -> "com.anthropic.claude"
                "perplexity" -> "ai.perplexity.app"
                "copilot" -> "com.microsoft.copilot"
                "custom" -> customPkg.trim()
                else -> null
            }

            if (!targetPackage.isNullOrEmpty()) {
                val launchIntent = packageManager.getLaunchIntentForPackage(targetPackage)
                if (launchIntent != null) {
                    launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    try {
                        startActivity(launchIntent)
                        finish()
                        return true
                    } catch (_: Exception) {
                    }
                }
            } else if (redirectTarget == "system_assist") {
                val assistIntent = Intent(Intent.ACTION_ASSIST).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                try {
                    startActivity(assistIntent)
                    finish()
                    return true
                } catch (_: Exception) {
                }
            }
        }

        // Default or fallback: Open Nora in Arcane
        pendingAssistantAction = "open_nora"
        dispatchWidgetAction("open_nora")
        return true
    }

    private fun initTts() {
        if (tts == null) {
            tts = TextToSpeech(applicationContext, this)
        }
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            ttsReady = true
            tts?.language = Locale.getDefault()
        } else {
            ttsReady = false
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        ttsMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TTS_CHANNEL)
        assistantMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ASSISTANT_CHANNEL)
        engineAlive = true

        // TTS method channel handler
        ttsMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "speak" -> {
                    val text = call.argument<String>("text") ?: ""
                    val pitch = call.argument<Double>("pitch")?.toFloat() ?: 1.0f
                    val rate = call.argument<Double>("rate")?.toFloat() ?: 1.0f
                    if (ttsReady && text.isNotEmpty()) {
                        tts?.setPitch(pitch)
                        tts?.setSpeechRate(rate)
                        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "arcane_nora_tts")
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "stop" -> {
                    tts?.stop()
                    result.success(true)
                }
                "isSpeaking" -> {
                    result.success(tts?.isSpeaking == true)
                }
                else -> result.notImplemented()
            }
        }

        // Assistant channel handler
        assistantMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPendingAction" -> {
                    val pending = pendingAssistantAction
                    pendingAssistantAction = null
                    result.success(pending)
                }
                "launchAssistantPackage" -> {
                    val pkg = call.argument<String>("package") ?: ""
                    if (pkg.isNotEmpty()) {
                        val launchIntent = packageManager.getLaunchIntentForPackage(pkg)
                        if (launchIntent != null) {
                            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(launchIntent)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Flush any pending cold-start assistant action
        val pending = pendingAssistantAction
        if (pending != null) {
            Handler(Looper.getMainLooper()).postDelayed({
                dispatchWidgetAction(pending)
                pendingAssistantAction = null
            }, 300)
        }
    }

    override fun onDestroy() {
        engineAlive = false
        channel = null
        ttsMethodChannel = null
        assistantMethodChannel = null
        tts?.stop()
        tts?.shutdown()
        tts = null
        super.onDestroy()
    }
}

