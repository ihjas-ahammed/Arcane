package me.ihjas.missions

import android.app.KeyguardManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.media.AudioAttributes
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.AlarmClock
import android.provider.MediaStore
import android.provider.Settings
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.Locale

class MainActivity : FlutterActivity(), TextToSpeech.OnInitListener {

    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var speechRecognizer: SpeechRecognizer? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingStartListening = false
    private val PERMISSION_REQUEST_CODE = 2001
    private var launcherBridge: LauncherBridge? = null
    private var updateBridge: UpdateBridge? = null

    companion object {
        const val CHANNEL = "arcane/widget"
        const val TTS_CHANNEL = "arcane/tts"
        const val STT_CHANNEL = "arcane/stt"
        const val ASSISTANT_CHANNEL = "arcane/assistant"
        const val INPUT_REPLY_CHANNEL = "me.ihjas.arcane/input_reply"

        @Volatile
        private var channel: MethodChannel? = null

        @Volatile
        private var ttsMethodChannel: MethodChannel? = null

        @Volatile
        private var sttMethodChannel: MethodChannel? = null

        @Volatile
        private var assistantMethodChannel: MethodChannel? = null

        @Volatile
        private var inputReplyMethodChannel: MethodChannel? = null

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

    override fun getInitialRoute(): String = "/app"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (intent?.getBooleanExtra(LauncherTakeoverService.EXTRA_TAKEOVER, false) == true) suppressTransition()
        initTts()
        if (!handleAssistantIntent(intent)) disableLockScreenDisplay()
        launcherBridge?.handlePinRequest(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // Only assistant / voice intents may surface over the keyguard. As the HOME
        // activity, showing over the lock screen would expose the launcher and user data.
        if (intent.getBooleanExtra(LauncherTakeoverService.EXTRA_TAKEOVER, false)) suppressTransition()
        if (!handleAssistantIntent(intent)) disableLockScreenDisplay()
        launcherBridge?.onNewIntent(intent)
    }

    /** No open/close animation when the takeover service swaps the stock launcher for us. */
    private fun suppressTransition() {
        try {
            if (Build.VERSION.SDK_INT >= 34) {
                overrideActivityTransition(android.app.Activity.OVERRIDE_TRANSITION_OPEN, 0, 0)
            } else {
                @Suppress("DEPRECATION")
                overridePendingTransition(0, 0)
            }
        } catch (_: Exception) {
        }
    }

    // Back is handled by Flutter (root PopScope in LauncherScreen), so in-app routes
    // pop normally and the home screen itself never finishes.

    override fun onStart() {
        super.onStart()
        launcherBridge?.onStart()
    }

    override fun onStop() {
        launcherBridge?.onStop()
        super.onStop()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (launcherBridge?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun disableLockScreenDisplay() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(false)
                setTurnScreenOn(false)
            } else {
                @Suppress("DEPRECATION")
                window.clearFlags(
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
                )
            }
        } catch (_: Exception) {
        }
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

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val audioIdx = permissions.indexOf(android.Manifest.permission.RECORD_AUDIO)
            val audioGranted = audioIdx != -1 && grantResults.isNotEmpty() && grantResults[audioIdx] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(audioGranted)
            pendingPermissionResult = null

            if (audioGranted && pendingStartListening) {
                pendingStartListening = false
                startSpeechRecognitionInternal()
            } else if (!audioGranted && pendingStartListening) {
                pendingStartListening = false
                sttMethodChannel?.invokeMethod("onError", "Microphone permission denied")
                sttMethodChannel?.invokeMethod("onListening", false)
            }
        }
    }

    private fun startSpeechRecognitionInternal() {
        Handler(Looper.getMainLooper()).post {
            try {
                routeAudioToBluetooth(true)
                speechRecognizer?.destroy()
                speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this)
                speechRecognizer?.setRecognitionListener(object : RecognitionListener {
                    override fun onReadyForSpeech(params: Bundle?) {
                        sttMethodChannel?.invokeMethod("onListening", true)
                    }
                    override fun onBeginningOfSpeech() {
                        sttMethodChannel?.invokeMethod("onSpeechStart", null)
                    }
                    override fun onRmsChanged(rmsdB: Float) {
                        sttMethodChannel?.invokeMethod("onRmsChanged", rmsdB.toDouble())
                    }
                    override fun onBufferReceived(buffer: ByteArray?) {}
                    override fun onEndOfSpeech() {
                        sttMethodChannel?.invokeMethod("onSpeechEnd", null)
                    }
                    override fun onError(error: Int) {
                        sttMethodChannel?.invokeMethod("onError", "Error code $error")
                        sttMethodChannel?.invokeMethod("onListening", false)
                    }
                    override fun onResults(results: Bundle?) {
                        sttMethodChannel?.invokeMethod("onListening", false)
                        val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        val text = matches?.firstOrNull() ?: ""
                        sttMethodChannel?.invokeMethod("onResult", text)
                    }
                    override fun onPartialResults(partialResults: Bundle?) {
                        val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        val text = matches?.firstOrNull() ?: ""
                        sttMethodChannel?.invokeMethod("onPartialResult", text)
                    }
                    override fun onEvent(eventType: Int, params: Bundle?) {}
                })

                val sttIntent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault().toLanguageTag())
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                    putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
                    putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, packageName)
                }
                speechRecognizer?.startListening(sttIntent)
            } catch (e: Exception) {
                sttMethodChannel?.invokeMethod("onError", e.message ?: "Failed to start speech recognition")
                sttMethodChannel?.invokeMethod("onListening", false)
            }
        }
    }

    /**
     * Routes incoming and outgoing voice audio to any connected Bluetooth audio
     * device (SCO headset, BLE headset, hearing aid).
     */
    private fun routeAudioToBluetooth(enable: Boolean) {
        try {
            BluetoothAudioRouter.routeAudio(this, enable)
        } catch (_: Exception) {}
    }

    /**
     * Launches external assistant directly into voice/mic listening mode.
     * Never calls finish() to keep Arcane running and protect user session & data!
     */
    private fun launchAssistantVoiceMode(target: String): Boolean {
        routeAudioToBluetooth(true)
        val pm = packageManager

        var targetPackage = target
        var targetActivity: String? = null
        if (target.contains("/")) {
            val parts = target.split("/", limit = 2)
            targetPackage = parts[0]
            targetActivity = parts[1].trim()
            if (targetActivity.startsWith(".")) {
                targetActivity = targetPackage + targetActivity
            }
        }

        // Arm auto-tap replay if a first-time tap was recorded for this external AI!
        if (LauncherTakeoverService.hasRecordedTap(this, targetPackage)) {
            LauncherTakeoverService.armAutoTap(this, targetPackage)
        }

        // 0. If explicit activity is specified, try launching it directly with voice extras
        if (!targetActivity.isNullOrEmpty()) {
            val comp = ComponentName(targetPackage, targetActivity)
            val explicitVoiceIntent = Intent("android.intent.action.VOICE_ASSIST").apply {
                component = comp
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                putExtra("open_voice", true)
                putExtra("voice_mode", true)
                putExtra("start_voice", true)
                putExtra("android.intent.extra.ASSIST_INPUT_HINT_KEYBOARD", false)
            }
            try {
                startActivity(explicitVoiceIntent)
                return true
            } catch (_: Exception) {}

            val explicitCmdIntent = Intent(Intent.ACTION_VOICE_COMMAND).apply {
                component = comp
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                putExtra("open_voice", true)
                putExtra("voice_mode", true)
                putExtra("start_voice", true)
                putExtra("android.intent.extra.ASSIST_INPUT_HINT_KEYBOARD", false)
            }
            try {
                startActivity(explicitCmdIntent)
                return true
            } catch (_: Exception) {}

            val directIntent = Intent().apply {
                component = comp
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                putExtra("open_voice", true)
                putExtra("voice_mode", true)
                putExtra("start_voice", true)
                putExtra("android.intent.extra.ASSIST_INPUT_HINT_KEYBOARD", false)
            }
            try {
                startActivity(directIntent)
                return true
            } catch (_: Exception) {}
        }

        // 1. Specific ChatGPT voice activity / assist intent candidates
        if (targetPackage == "com.openai.chatgpt") {
            val voiceComponents = listOf(
                ComponentName("com.openai.chatgpt", "com.openai.voice.assistant.AssistantActivity"),
                ComponentName("com.openai.chatgpt", "com.openai.voice.VoiceActivity"),
                ComponentName("com.openai.chatgpt", "com.openai.chatgpt.MainActivity")
            )
            for (comp in voiceComponents) {
                try {
                    val explicitIntent = Intent("android.intent.action.VOICE_ASSIST").apply {
                        component = comp
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        putExtra("open_voice", true)
                        putExtra("voice_mode", true)
                        putExtra("start_voice", true)
                        putExtra("android.intent.extra.ASSIST_INPUT_HINT_KEYBOARD", false)
                    }
                    startActivity(explicitIntent)
                    return true
                } catch (_: Exception) {}

                try {
                    val cmdIntent = Intent(Intent.ACTION_VOICE_COMMAND).apply {
                        component = comp
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        putExtra("open_voice", true)
                        putExtra("voice_mode", true)
                        putExtra("start_voice", true)
                        putExtra("android.intent.extra.ASSIST_INPUT_HINT_KEYBOARD", false)
                    }
                    startActivity(cmdIntent)
                    return true
                } catch (_: Exception) {}
            }
        }

        // 2. Try ACTION_VOICE_ASSIST (Standard Android voice assistant intent)
        val voiceAssistIntent = Intent("android.intent.action.VOICE_ASSIST").apply {
            setPackage(targetPackage)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
            putExtra("android.intent.extra.ASSIST_INPUT_HINT_KEYBOARD", false)
            putExtra("open_voice", true)
            putExtra("voice_mode", true)
            putExtra("start_voice", true)
        }
        if (pm.queryIntentActivities(voiceAssistIntent, 0).isNotEmpty()) {
            try {
                startActivity(voiceAssistIntent)
                return true
            } catch (_: Exception) {}
        }

        // 3. Try ACTION_VOICE_COMMAND (Direct Bluetooth headset voice button intent)
        val voiceCmdIntent = Intent(Intent.ACTION_VOICE_COMMAND).apply {
            setPackage(targetPackage)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
            putExtra("android.intent.extra.ASSIST_INPUT_HINT_KEYBOARD", false)
            putExtra("open_voice", true)
            putExtra("voice_mode", true)
            putExtra("start_voice", true)
        }
        if (pm.queryIntentActivities(voiceCmdIntent, 0).isNotEmpty()) {
            try {
                startActivity(voiceCmdIntent)
                return true
            } catch (_: Exception) {}
        }

        // 4. Try ACTION_VOICE_SEARCH_HANDS_FREE
        val handsFreeIntent = Intent("android.speech.action.VOICE_SEARCH_HANDS_FREE").apply {
            setPackage(targetPackage)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
            putExtra("android.intent.extra.ASSIST_INPUT_HINT_KEYBOARD", false)
            putExtra("open_voice", true)
        }
        if (pm.queryIntentActivities(handsFreeIntent, 0).isNotEmpty()) {
            try {
                startActivity(handsFreeIntent)
                return true
            } catch (_: Exception) {}
        }

        // 5. Try standard ACTION_ASSIST with voice hint
        val assistIntent = Intent(Intent.ACTION_ASSIST).apply {
            setPackage(targetPackage)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
            putExtra("android.intent.extra.ASSIST_INPUT_HINT_KEYBOARD", false)
            putExtra("open_voice", true)
        }
        if (pm.queryIntentActivities(assistIntent, 0).isNotEmpty()) {
            try {
                startActivity(assistIntent)
                return true
            } catch (_: Exception) {}
        }

        // 6. Fallback to package launch intent with voice extras
        val launchIntent = pm.getLaunchIntentForPackage(targetPackage)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            putExtra("open_voice", true)
            putExtra("voice_mode", true)
            putExtra("start_voice", true)
            putExtra("android.intent.extra.ASSIST_INPUT_HINT_KEYBOARD", false)
        }
        if (launchIntent != null) {
            try {
                startActivity(launchIntent)
                return true
            } catch (_: Exception) {}
        }

        return false
    }

    /**
     * Handles incoming Bluetooth voice command (ACTION_VOICE_COMMAND), system
     * assist (ACTION_ASSIST), and voice assist intents.
     *
     * Never calls finish() to keep Arcane completely intact in the background.
     * If user configured a redirector in Settings (e.g. ChatGPT, Gemini, Claude,
     * Perplexity, Copilot, or custom app), it seamlessly launches that assistant
     * in active voice/mic mode. Otherwise, it opens Nora in active voice mode!
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
        val customActivity = prefs.getString("flutter.bluetooth_assistant_custom_activity", "") ?: ""

        val km = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
        val isLocked = km?.isKeyguardLocked == true || km?.isDeviceLocked == true

        val proceedWithLaunch = {
            if (redirectTarget != "nora") {
                val targetPackage = when (redirectTarget) {
                    "chatgpt" -> "com.openai.chatgpt"
                    "gemini" -> "com.google.android.apps.googleassistant"
                    "claude" -> "com.anthropic.claude"
                    "perplexity" -> "ai.perplexity.app"
                    "copilot" -> "com.microsoft.copilot"
                    "custom" -> {
                        val pkg = customPkg.trim()
                        val act = customActivity.trim()
                        if (pkg.isNotEmpty() && act.isNotEmpty() && !pkg.contains("/")) {
                            "$pkg/$act"
                        } else {
                            pkg
                        }
                    }
                    else -> redirectTarget
                }

                if (redirectTarget == "system_assist") {
                    routeAudioToBluetooth(true)
                    val assistIntent = Intent("android.intent.action.VOICE_ASSIST").apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        putExtra("android.intent.extra.ASSIST_INPUT_HINT_KEYBOARD", false)
                        putExtra("open_voice", true)
                    }
                    try {
                        startActivity(assistIntent)
                    } catch (_: Exception) {
                        val fallbackIntent = Intent(Intent.ACTION_ASSIST).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        try {
                            startActivity(fallbackIntent)
                        } catch (_: Exception) {}
                    }
                } else if (targetPackage.isNotEmpty()) {
                    launchAssistantVoiceMode(targetPackage)
                }
            } else {
                // Default: Open Nora with auto mic start (floating HUD or full screen)
                if (NoraBubbleOverlay.isFloatingForWatch(this) && LauncherTakeoverService.isServiceEnabled(this)) {
                    NoraBubbleOverlay.summonAndListen(this)
                } else {
                    pendingAssistantAction = "open_nora_voice"
                    dispatchWidgetAction("open_nora_voice")
                }
            }
        }

        if (isLocked && LauncherTakeoverService.hasUnlockGesture(this) && LauncherTakeoverService.activeInstance != null) {
            android.util.Log.i("MainActivity", "Lock screen active: executing Movement 1 (Unlock screen) before Movement 2 (Assistant launch + mic tap)")
            LauncherTakeoverService.activeInstance?.executeUnlockSequence {
                proceedWithLaunch()
            }
        } else {
            proceedWithLaunch()
        }
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
            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ASSISTANT)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .build()
            tts?.setAudioAttributes(audioAttributes)
            tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String?) {
                    Handler(Looper.getMainLooper()).post {
                        ttsMethodChannel?.invokeMethod("onStart", utteranceId)
                    }
                }
                override fun onDone(utteranceId: String?) {
                    Handler(Looper.getMainLooper()).post {
                        ttsMethodChannel?.invokeMethod("onDone", utteranceId)
                    }
                }
                override fun onError(utteranceId: String?) {
                    Handler(Looper.getMainLooper()).post {
                        ttsMethodChannel?.invokeMethod("onError", utteranceId)
                    }
                }
            })
        } else {
            ttsReady = false
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        ttsMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TTS_CHANNEL)
        sttMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STT_CHANNEL)
        assistantMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ASSISTANT_CHANNEL)
        updateBridge?.dispose()
        updateBridge = UpdateBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        launcherBridge?.dispose()
        launcherBridge = LauncherBridge(this, flutterEngine.dartExecutor.binaryMessenger).also { bridge ->
            flutterEngine.platformViewsController.registry
                .registerViewFactory(LauncherBridge.VIEW_TYPE, bridge.WidgetViewFactory())
        }
        engineAlive = true

        // TTS method channel handler
        ttsMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "speak" -> {
                    val text = call.argument<String>("text") ?: ""
                    val pitch = call.argument<Double>("pitch")?.toFloat() ?: 1.0f
                    val rate = call.argument<Double>("rate")?.toFloat() ?: 1.0f
                    if (ttsReady && text.isNotEmpty()) {
                        routeAudioToBluetooth(true)
                        tts?.setPitch(pitch)
                        tts?.setSpeechRate(rate)
                        val utteranceId = "arcane_nora_tts_${System.currentTimeMillis()}"
                        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, utteranceId)
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
                "routeBluetooth" -> {
                    val enable = call.argument<Boolean>("enable") ?: true
                    routeAudioToBluetooth(enable)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // STT (Speech Recognizer) method channel handler
        sttMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> {
                    val hasRecordAudio = checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
                    result.success(hasRecordAudio)
                }
                "requestPermission" -> {
                    if (checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
                        result.success(true)
                    } else {
                        pendingPermissionResult = result
                        val permsToRequest = mutableListOf(android.Manifest.permission.RECORD_AUDIO)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            if (checkSelfPermission(android.Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
                                permsToRequest.add(android.Manifest.permission.BLUETOOTH_CONNECT)
                            }
                        }
                        requestPermissions(permsToRequest.toTypedArray(), PERMISSION_REQUEST_CODE)
                    }
                }
                "startListening" -> {
                    if (checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                        pendingStartListening = true
                        val permsToRequest = mutableListOf(android.Manifest.permission.RECORD_AUDIO)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            if (checkSelfPermission(android.Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
                                permsToRequest.add(android.Manifest.permission.BLUETOOTH_CONNECT)
                            }
                        }
                        requestPermissions(permsToRequest.toTypedArray(), PERMISSION_REQUEST_CODE)
                        result.success(true)
                    } else {
                        startSpeechRecognitionInternal()
                        result.success(true)
                    }
                }
                "stopListening" -> {
                    Handler(Looper.getMainLooper()).post {
                        speechRecognizer?.stopListening()
                        sttMethodChannel?.invokeMethod("onListening", false)
                        result.success(true)
                    }
                }
                "isAvailable" -> {
                    result.success(SpeechRecognizer.isRecognitionAvailable(this))
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
                "getInstalledAssistants" -> {
                    val pm = packageManager
                    val resultList = mutableListOf<Map<String, String>>()
                    val seenPackages = mutableSetOf<String>()

                    // 1. Query activities that declare assist / voice intents
                    val activityQueries = listOf(
                        Intent(Intent.ACTION_ASSIST),
                        Intent("android.intent.action.VOICE_ASSIST"),
                        Intent(Intent.ACTION_VOICE_COMMAND),
                        Intent("android.speech.action.VOICE_SEARCH_HANDS_FREE"),
                        Intent(RecognizerIntent.ACTION_WEB_SEARCH)
                    )

                    for (queryIntent in activityQueries) {
                        val resolved = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            pm.queryIntentActivities(queryIntent, PackageManager.ResolveInfoFlags.of(0))
                        } else {
                            @Suppress("DEPRECATION")
                            pm.queryIntentActivities(queryIntent, 0)
                        }
                        for (info in resolved) {
                            val pkg = info.activityInfo?.packageName ?: continue
                            if (pkg == packageName || seenPackages.contains(pkg)) continue
                            seenPackages.add(pkg)
                            val label = info.loadLabel(pm).toString().ifEmpty { pkg }
                            resultList.add(mapOf("package" to pkg, "label" to label))
                        }
                    }

                    // 2. Query services that declare VoiceInteractionService (e.g. Google Assistant, Bixby)
                    val serviceIntent = Intent("android.service.voice.VoiceInteractionService")
                    val serviceResolved = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        pm.queryIntentServices(serviceIntent, PackageManager.ResolveInfoFlags.of(0))
                    } else {
                        @Suppress("DEPRECATION")
                        pm.queryIntentServices(serviceIntent, 0)
                    }
                    for (info in serviceResolved) {
                        val pkg = info.serviceInfo?.packageName ?: continue
                        if (pkg == packageName || seenPackages.contains(pkg)) continue
                        seenPackages.add(pkg)
                        val label = info.loadLabel(pm).toString().ifEmpty { pkg }
                        resultList.add(mapOf("package" to pkg, "label" to label))
                    }

                    // 3. Also check popular AI assistants ONLY if actually installed on device
                    val popularPkgs = listOf(
                        "com.openai.chatgpt" to "ChatGPT",
                        "com.google.android.apps.bard" to "Google Gemini",
                        "com.google.android.apps.googleassistant" to "Google Assistant",
                        "com.google.android.googlequicksearchbox" to "Google",
                        "com.anthropic.claude" to "Anthropic Claude",
                        "ai.perplexity.app" to "Perplexity AI",
                        "com.microsoft.copilot" to "Microsoft Copilot",
                        "com.samsung.android.bixby.agent" to "Samsung Bixby"
                    )
                    for ((pkg, defaultLabel) in popularPkgs) {
                        if (seenPackages.contains(pkg)) continue
                        try {
                            val appInfo = pm.getApplicationInfo(pkg, 0)
                            val label = pm.getApplicationLabel(appInfo).toString().ifEmpty { defaultLabel }
                            seenPackages.add(pkg)
                            resultList.add(mapOf("package" to pkg, "label" to label))
                        } catch (_: Exception) {}
                    }

                    result.success(resultList)
                }
                "launchAssistantPackage" -> {
                    val pkg = call.argument<String>("package") ?: ""
                    val act = call.argument<String>("activity") ?: ""
                    val target = if (act.isNotEmpty() && !pkg.contains("/")) "$pkg/$act" else pkg
                    if (target.isNotEmpty()) {
                        val km = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
                        val isLocked = km?.isKeyguardLocked == true || km?.isDeviceLocked == true
                        if (isLocked && LauncherTakeoverService.hasUnlockGesture(this) && LauncherTakeoverService.activeInstance != null) {
                            LauncherTakeoverService.activeInstance?.executeUnlockSequence {
                                val launched = launchAssistantVoiceMode(target)
                                result.success(launched)
                            }
                        } else {
                            val launched = launchAssistantVoiceMode(target)
                            result.success(launched)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "getAllInstalledApps" -> {
                    Thread {
                      try {
                        val pm = packageManager
                        val apps = pm.getInstalledApplications(PackageManager.GET_META_DATA)
                        val list = mutableListOf<Map<String, Any?>>()
                        for (app in apps) {
                            if (app.packageName == packageName) continue
                            val label = pm.getApplicationLabel(app).toString().ifEmpty { app.packageName }
                            val isSystem = (app.flags and ApplicationInfo.FLAG_SYSTEM) != 0
                            val launchIntent = pm.getLaunchIntentForPackage(app.packageName)
                            list.add(mapOf(
                                "package" to app.packageName,
                                "label" to label,
                                "isSystem" to isSystem,
                                "isLaunchable" to (launchIntent != null)
                            ))
                        }
                        list.sortWith(compareBy<Map<String, Any?>> { it["isSystem"] as Boolean }
                            .thenBy { (it["label"] as? String)?.lowercase() ?: "" })
                        Handler(Looper.getMainLooper()).post {
                            result.success(list)
                        }
                      } catch (_: Throwable) {
                        // e.g. the package manager dying mid-query with many apps installed.
                        Handler(Looper.getMainLooper()).post { result.success(emptyList<Map<String, Any?>>()) }
                      }
                    }.start()
                }
                "getAppActivities" -> {
                    val pkg = call.argument<String>("package") ?: ""
                    if (pkg.isEmpty()) {
                        result.success(emptyList<Map<String, Any?>>())
                        return@setMethodCallHandler
                    }
                    Thread {
                        val pm = packageManager
                        try {
                            val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                pm.getPackageInfo(pkg, PackageManager.PackageInfoFlags.of(PackageManager.GET_ACTIVITIES.toLong()))
                            } else {
                                @Suppress("DEPRECATION")
                                pm.getPackageInfo(pkg, PackageManager.GET_ACTIVITIES)
                            }
                            val activities = packageInfo.activities ?: emptyArray()
                            val list = mutableListOf<Map<String, Any?>>()
                            for (act in activities) {
                                val name = act.name
                                val label = act.loadLabel(pm).toString().ifEmpty { name.substringAfterLast('.') }
                                val exported = act.exported
                                val isVoiceOrAssist = name.contains("voice", ignoreCase = true) ||
                                                      name.contains("assist", ignoreCase = true) ||
                                                      name.contains("audio", ignoreCase = true) ||
                                                      name.contains("mic", ignoreCase = true) ||
                                                      name.contains("talk", ignoreCase = true) ||
                                                      name.contains("live", ignoreCase = true)
                                list.add(mapOf(
                                    "name" to name,
                                    "label" to label,
                                    "exported" to exported,
                                    "isVoiceOrAssist" to isVoiceOrAssist
                                ))
                            }
                            list.sortWith(compareByDescending<Map<String, Any?>> { it["isVoiceOrAssist"] as Boolean }
                                .thenByDescending { it["exported"] as Boolean }
                                .thenBy { it["label"] as String })
                            Handler(Looper.getMainLooper()).post {
                                result.success(list)
                            }
                        } catch (_: Throwable) {
                            Handler(Looper.getMainLooper()).post {
                                result.success(emptyList<Map<String, Any?>>())
                            }
                        }
                    }.start()
                }
                "routeAudioToBluetooth" -> {
                    val enable = call.argument<Boolean>("enable") ?: true
                    routeAudioToBluetooth(enable)
                    result.success(true)
                }
                "launchPackage" -> {
                    val pkg = call.argument<String>("package") ?: ""
                    if (pkg.isNotEmpty()) {
                        val pm = packageManager
                        val intent = pm.getLaunchIntentForPackage(pkg)
                        if (intent != null) {
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            try {
                                startActivity(intent)
                                result.success(true)
                            } catch (_: Exception) {
                                result.success(false)
                            }
                        } else {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "launchIntentAction" -> {
                    val action = call.argument<String>("action") ?: ""
                    val intent = when (action.lowercase()) {
                        "phone" -> Intent(Intent.ACTION_DIAL)
                        "messages" -> Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_APP_MESSAGING)
                        "camera" -> Intent(MediaStore.INTENT_ACTION_STILL_IMAGE_CAMERA)
                        "settings" -> Intent(Settings.ACTION_SETTINGS)
                        "clock" -> Intent(AlarmClock.ACTION_SHOW_ALARMS)
                        "gallery" -> Intent(Intent.ACTION_VIEW).apply { type = "image/*" }
                        "home_settings" -> Intent(Settings.ACTION_HOME_SETTINGS)
                        else -> null
                    }
                    if (intent != null) {
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        try {
                            startActivity(intent)
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "getAppIcon" -> {
                    val pkg = call.argument<String>("package") ?: ""
                    if (pkg.isEmpty()) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        try {
                            val pm = packageManager
                            val iconDrawable = pm.getApplicationIcon(pkg)
                            val bitmap = drawableToBitmap(iconDrawable)
                            val stream = ByteArrayOutputStream()
                            bitmap.compress(Bitmap.CompressFormat.PNG, 85, stream)
                            val byteArray = stream.toByteArray()
                            Handler(Looper.getMainLooper()).post {
                                result.success(byteArray)
                            }
                        } catch (_: Throwable) {
                            Handler(Looper.getMainLooper()).post {
                                result.success(null)
                            }
                        }
                    }.start()
                }
                "canDrawOverlays" -> {
                    val canDraw = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        Settings.canDrawOverlays(this)
                    } else {
                        true
                    }
                    result.success(canDraw)
                }
                "openOverlaySettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        try {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                android.net.Uri.parse("package:$packageName")
                            ).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (_: Exception) {
                            try {
                                val fallback = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(fallback)
                                result.success(true)
                            } catch (_: Exception) {
                                result.success(false)
                            }
                        }
                    } else {
                        result.success(true)
                    }
                }
                "getCalibrationMethod" -> {
                    val prefs = getSharedPreferences("arcane_auto_tap", Context.MODE_PRIVATE)
                    result.success(prefs.getString("mic_calibration_method", "reticle") ?: "reticle")
                }
                "setCalibrationMethod" -> {
                    val method = call.argument<String>("method") ?: "reticle"
                    val prefs = getSharedPreferences("arcane_auto_tap", Context.MODE_PRIVATE)
                    prefs.edit().putString("mic_calibration_method", method).apply()
                    result.success(true)
                }
                "getOverlayWindowType" -> {
                    val prefs = getSharedPreferences("arcane_auto_tap", Context.MODE_PRIVATE)
                    result.success(prefs.getString("overlay_window_type", "auto") ?: "auto")
                }
                "setOverlayWindowType" -> {
                    val type = call.argument<String>("type") ?: "auto"
                    val prefs = getSharedPreferences("arcane_auto_tap", Context.MODE_PRIVATE)
                    prefs.edit().putString("overlay_window_type", type).apply()
                    result.success(true)
                }
                "getMicClickDelay" -> {
                    result.success(LauncherTakeoverService.getMicClickDelay(this).toInt())
                }
                "setMicClickDelay" -> {
                    val delay = call.argument<Int>("delay") ?: 1000
                    LauncherTakeoverService.setMicClickDelay(this, delay.toLong())
                    result.success(true)
                }
                "isForceBluetoothScoCallEnabled" -> {
                    result.success(BluetoothAudioRouter.isForceBluetoothScoCallEnabled(this))
                }
                "setForceBluetoothScoCallEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    BluetoothAudioRouter.setForceBluetoothScoCallEnabled(this, enabled)
                    result.success(true)
                }
                "setManualCoordinates" -> {
                    val pkg = call.argument<String>("package") ?: ""
                    val xRatio = (call.argument<Double>("xRatio") ?: 0.5).toFloat()
                    val yRatio = (call.argument<Double>("yRatio") ?: 0.85).toFloat()
                    if (pkg.isNotEmpty()) {
                        LauncherTakeoverService.saveManualCoordinates(this, pkg, xRatio, yRatio)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "startRecordingTap" -> {
                    val pkg = call.argument<String>("package") ?: ""
                    val method = call.argument<String>("method")
                    if (pkg.isNotEmpty()) {
                        LauncherTakeoverService.startRecordingTap(this, pkg, method)
                        val pm = packageManager
                        val launchIntent = pm.getLaunchIntentForPackage(pkg)?.apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        if (launchIntent != null) {
                            startActivity(launchIntent)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "hasRecordedTap" -> {
                    val pkg = call.argument<String>("package") ?: ""
                    result.success(LauncherTakeoverService.hasRecordedTap(this, pkg))
                }
                "clearRecordedTap" -> {
                    val pkg = call.argument<String>("package") ?: ""
                    LauncherTakeoverService.clearRecordedTap(this, pkg)
                    result.success(true)
                }
                "getRecordedTapInfo" -> {
                    val pkg = call.argument<String>("package") ?: ""
                    result.success(LauncherTakeoverService.getRecordedTapInfo(this, pkg))
                }
                "getNoraBubbleStatus" -> {
                    result.success(mapOf(
                        "enabled" to NoraBubbleOverlay.isEnabled(this),
                        "watchFloating" to NoraBubbleOverlay.isFloatingForWatch(this),
                        "serviceEnabled" to LauncherTakeoverService.isServiceEnabled(this)
                    ))
                }
                "setNoraBubbleEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    NoraBubbleOverlay.setEnabled(this, enabled)
                    result.success(true)
                }
                "setNoraWatchFloating" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    NoraBubbleOverlay.setFloatingForWatch(this, enabled)
                    result.success(true)
                }
                "summonFloatingNora" -> {
                    NoraBubbleOverlay.summonAndListen(this)
                    result.success(true)
                }
                "startRecordingUnlockGesture" -> {
                    result.success(LauncherTakeoverService.startRecordingUnlockGesture(this))
                }
                "testUnlockGesture" -> {
                    result.success(LauncherTakeoverService.testUnlockGesture(this))
                }
                "clearUnlockGesture" -> {
                    LauncherTakeoverService.clearUnlockGesture(this)
                    result.success(true)
                }
                "getUnlockGestureInfo" -> {
                    result.success(LauncherTakeoverService.getUnlockGestureInfo(this))
                }
                "hasUnlockGesture" -> {
                    result.success(LauncherTakeoverService.hasUnlockGesture(this))
                }
                else -> result.notImplemented()
            }
        }

        // Input Reply whole-device macro engine method channel handler
        inputReplyMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INPUT_REPLY_CHANNEL)
        inputReplyMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkAccessibility" -> {
                    result.success(LauncherTakeoverService.isServiceEnabled(this))
                }
                "openAccessibilitySettings" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    startActivity(intent)
                    result.success(true)
                }
                "startRecording" -> {
                    val name = call.argument<String>("name") ?: ""
                    val targetPackage = call.argument<String>("targetPackage")
                    val mgr = InputReplyManager.instance
                    if (mgr != null) {
                        result.success(mgr.startRecording(name, targetPackage))
                    } else {
                        result.error("SERVICE_UNAVAILABLE", "Accessibility service is not active", null)
                    }
                }
                "stopRecording" -> {
                    val mgr = InputReplyManager.instance
                    if (mgr != null) {
                        result.success(mgr.stopRecording())
                    } else {
                        result.success(null)
                    }
                }
                "cancelRecording" -> {
                    InputReplyManager.instance?.cancelRecording()
                    result.success(true)
                }
                "isRecording" -> {
                    result.success(InputReplyManager.instance?.isRecordingActive() == true)
                }
                "isReplaying" -> {
                    result.success(InputReplyManager.instance?.isReplayingActive() == true)
                }
                "playMacro" -> {
                    val mgr = InputReplyManager.instance
                    if (mgr == null) {
                        result.error("SERVICE_UNAVAILABLE", "Accessibility service is not active", null)
                        return@setMethodCallHandler
                    }
                    val macroData = call.argument<Map<String, Any?>>("macro")
                    val params = call.argument<Map<String, Any?>>("params")
                    val speed = call.argument<Double>("speed") ?: 1.0
                    val repeatCount = call.argument<Int>("repeatCount") ?: 1
                    if (macroData != null) {
                        result.success(mgr.playMacro(macroData, params, speed, repeatCount))
                    } else {
                        val name = call.argument<String>("name") ?: ""
                        val loaded = mgr.getMacro(name)
                        if (loaded != null) {
                            result.success(mgr.playMacro(loaded, params, speed, repeatCount))
                        } else {
                            result.error("NOT_FOUND", "Macro not found", null)
                        }
                    }
                }
                "stopReplay" -> {
                    InputReplyManager.instance?.stopReplay()
                    result.success(true)
                }
                "listRecordings" -> {
                    val mgr = InputReplyManager.instance
                    if (mgr != null) {
                        result.success(mgr.listSavedMacros())
                    } else {
                        val dir = File(filesDir, "input_reply/recordings")
                        val files = dir.listFiles { f -> f.extension == "json" } ?: emptyArray()
                        val list = mutableListOf<Map<String, Any?>>()
                        for (file in files) {
                            try {
                                val json = JSONObject(file.readText())
                                val map = mutableMapOf<String, Any?>()
                                val keys = json.keys()
                                while (keys.hasNext()) {
                                    val k = keys.next()
                                    map[k] = json.opt(k)
                                }
                                list.add(map)
                            } catch (_: Exception) {}
                        }
                        result.success(list)
                    }
                }
                "getRecording" -> {
                    val name = call.argument<String>("name") ?: ""
                    val mgr = InputReplyManager.instance
                    val macro = mgr?.getMacro(name)
                    if (macro != null) {
                        result.success(macro)
                    } else {
                        result.success(null)
                    }
                }
                "saveRecording" -> {
                    val name = call.argument<String>("name") ?: ""
                    val macroData = call.argument<Map<String, Any?>>("macro")
                    val mgr = InputReplyManager.instance
                    if (mgr != null && macroData != null) {
                        result.success(mgr.saveMacroToFile(name, macroData))
                    } else if (macroData != null) {
                        try {
                            val dir = File(filesDir, "input_reply/recordings")
                            if (!dir.exists()) dir.mkdirs()
                            val file = File(dir, if (name.endsWith(".json")) name else "$name.json")
                            file.writeText(JSONObject(macroData).toString(2))
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "deleteRecording" -> {
                    val name = call.argument<String>("name") ?: ""
                    val mgr = InputReplyManager.instance
                    if (mgr != null) {
                        result.success(mgr.deleteMacro(name))
                    } else {
                        val file = File(File(filesDir, "input_reply/recordings"), if (name.endsWith(".json")) name else "$name.json")
                        result.success(file.delete())
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

    private fun drawableToBitmap(drawable: Drawable): Bitmap {
        if (drawable is BitmapDrawable) {
            return drawable.bitmap
        }
        val width = drawable.intrinsicWidth.coerceAtLeast(48).coerceAtMost(192)
        val height = drawable.intrinsicHeight.coerceAtLeast(48).coerceAtMost(192)
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bitmap
    }

    override fun onDestroy() {
        engineAlive = false
        launcherBridge?.dispose()
        launcherBridge = null
        updateBridge?.dispose()
        updateBridge = null
        channel = null
        ttsMethodChannel = null
        sttMethodChannel = null
        assistantMethodChannel = null
        inputReplyMethodChannel = null
        tts?.stop()
        tts?.shutdown()
        tts = null
        speechRecognizer?.destroy()
        speechRecognizer = null
        routeAudioToBluetooth(false)
        super.onDestroy()
    }
}
