package me.ihjas.missions

import android.app.KeyguardManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity(), TextToSpeech.OnInitListener {

    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var speechRecognizer: SpeechRecognizer? = null

    companion object {
        const val CHANNEL = "arcane/widget"
        const val TTS_CHANNEL = "arcane/tts"
        const val STT_CHANNEL = "arcane/stt"
        const val ASSISTANT_CHANNEL = "arcane/assistant"

        @Volatile
        private var channel: MethodChannel? = null

        @Volatile
        private var ttsMethodChannel: MethodChannel? = null

        @Volatile
        private var sttMethodChannel: MethodChannel? = null

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
     * Routes incoming and outgoing voice audio to any connected Bluetooth audio
     * device (SCO headset, BLE headset, hearing aid, or A2DP).
     */
    private fun routeAudioToBluetooth(enable: Boolean) {
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
            if (enable) {
                audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
                audioManager.isSpeakerphoneOn = false

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    val devices = audioManager.availableCommunicationDevices
                    val btDevice = devices.firstOrNull {
                        it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
                        it.type == AudioDeviceInfo.TYPE_BLE_HEADSET ||
                        it.type == AudioDeviceInfo.TYPE_HEARING_AID ||
                        it.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP
                    }
                    if (btDevice != null) {
                        audioManager.setCommunicationDevice(btDevice)
                    }
                }
                if (audioManager.isBluetoothScoAvailableOffCall && !audioManager.isBluetoothScoOn) {
                    audioManager.startBluetoothSco()
                    audioManager.isBluetoothScoOn = true
                }
            } else {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    audioManager.clearCommunicationDevice()
                }
                if (audioManager.isBluetoothScoOn) {
                    audioManager.stopBluetoothSco()
                    audioManager.isBluetoothScoOn = false
                }
                audioManager.mode = AudioManager.MODE_NORMAL
            }
        } catch (_: Exception) {
        }
    }

    /**
     * Launches external assistant directly into voice/mic listening mode.
     */
    private fun launchAssistantVoiceMode(targetPackage: String): Boolean {
        routeAudioToBluetooth(true)
        val pm = packageManager

        // 1. Try ACTION_VOICE_ASSIST (Standard Android voice assistant intent)
        val voiceAssistIntent = Intent("android.intent.action.VOICE_ASSIST").apply {
            setPackage(targetPackage)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("android.intent.extra.ASSIST_INPUT_HINT_KEYBOARD", false)
            putExtra("open_voice", true)
        }
        if (pm.queryIntentActivities(voiceAssistIntent, 0).isNotEmpty()) {
            try {
                startActivity(voiceAssistIntent)
                return true
            } catch (_: Exception) {}
        }

        // 2. Specific ChatGPT voice activity / intent
        if (targetPackage == "com.openai.chatgpt") {
            val voiceComponents = listOf(
                ComponentName("com.openai.chatgpt", "com.openai.voice.VoiceActivity"),
                ComponentName("com.openai.chatgpt", "com.openai.chatgpt.MainActivity")
            )
            for (comp in voiceComponents) {
                try {
                    val explicitIntent = Intent("android.intent.action.VOICE_ASSIST").apply {
                        component = comp
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        putExtra("open_voice", true)
                        putExtra("android.intent.extra.ASSIST_INPUT_HINT_KEYBOARD", false)
                    }
                    startActivity(explicitIntent)
                    return true
                } catch (_: Exception) {}
            }
        }

        // 3. Try standard ACTION_ASSIST with voice hint
        val assistIntent = Intent(Intent.ACTION_ASSIST).apply {
            setPackage(targetPackage)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("android.intent.extra.ASSIST_INPUT_HINT_KEYBOARD", false)
            putExtra("open_voice", true)
        }
        if (pm.queryIntentActivities(assistIntent, 0).isNotEmpty()) {
            try {
                startActivity(assistIntent)
                return true
            } catch (_: Exception) {}
        }

        // 4. Try ACTION_VOICE_SEARCH_HANDS_FREE
        val handsFreeIntent = Intent("android.speech.action.VOICE_SEARCH_HANDS_FREE").apply {
            setPackage(targetPackage)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        if (pm.queryIntentActivities(handsFreeIntent, 0).isNotEmpty()) {
            try {
                startActivity(handsFreeIntent)
                return true
            } catch (_: Exception) {}
        }

        // 5. Fallback to package launch intent with voice extras
        val launchIntent = pm.getLaunchIntentForPackage(targetPackage)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra("open_voice", true)
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

        if (redirectTarget != "nora") {
            val targetPackage = when (redirectTarget) {
                "chatgpt" -> "com.openai.chatgpt"
                "gemini" -> "com.google.android.apps.googleassistant"
                "claude" -> "com.anthropic.claude"
                "perplexity" -> "ai.perplexity.app"
                "copilot" -> "com.microsoft.copilot"
                "custom" -> customPkg.trim()
                else -> redirectTarget
            }

            if (redirectTarget == "system_assist") {
                routeAudioToBluetooth(true)
                val assistIntent = Intent("android.intent.action.VOICE_ASSIST").apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    putExtra("android.intent.extra.ASSIST_INPUT_HINT_KEYBOARD", false)
                    putExtra("open_voice", true)
                }
                try {
                    startActivity(assistIntent)
                    finish()
                    return true
                } catch (_: Exception) {
                    val fallbackIntent = Intent(Intent.ACTION_ASSIST).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    }
                    try {
                        startActivity(fallbackIntent)
                        finish()
                        return true
                    } catch (_: Exception) {}
                }
            } else if (targetPackage.isNotEmpty()) {
                val launched = launchAssistantVoiceMode(targetPackage)
                if (launched) {
                    finish()
                    return true
                }
            }
        }

        // Default: Open Nora in Arcane with auto mic start
        pendingAssistantAction = "open_nora_voice"
        dispatchWidgetAction("open_nora_voice")
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
                "startListening" -> {
                    Handler(Looper.getMainLooper()).post {
                        try {
                            routeAudioToBluetooth(true)
                            speechRecognizer?.destroy()
                            speechRecognizer = SpeechRecognizer.createSpeechRecognizer(applicationContext)
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
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
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
                    result.success(SpeechRecognizer.isRecognitionAvailable(applicationContext))
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
                    if (pkg.isNotEmpty()) {
                        val launched = launchAssistantVoiceMode(pkg)
                        result.success(launched)
                    } else {
                        result.success(false)
                    }
                }
                "routeAudioToBluetooth" -> {
                    val enable = call.argument<Boolean>("enable") ?: true
                    routeAudioToBluetooth(enable)
                    result.success(true)
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
        sttMethodChannel = null
        assistantMethodChannel = null
        tts?.stop()
        tts?.shutdown()
        tts = null
        speechRecognizer?.destroy()
        speechRecognizer = null
        routeAudioToBluetooth(false)
        super.onDestroy()
    }
}
