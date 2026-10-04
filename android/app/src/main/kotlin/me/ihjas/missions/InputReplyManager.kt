package me.ihjas.missions

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Path
import android.graphics.Rect
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityWindowInfo
import android.view.inputmethod.InputMethodManager
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import kotlin.math.roundToInt

/**
 * Universal whole-device input recording and replay engine for Arcane.
 * Compatible with the input-reply macro format (input-reply-agent-v1).
 *
 * Records user actions across ANY app on Android via [LauncherTakeoverService]:
 *  - Clicks, long-presses, and taps
 *  - Text typing blocks and parameter candidates
 *  - Scrolling and directional gestures
 *  - Application switching and launch intents
 *  - Global system keys (Back, Home, Recents)
 *  - Inter-action timing and realistic delays
 *
 * Replays macros on device with runtime parameter substitution, loops, and speed adjustments.
 */
class InputReplyManager private constructor(private val service: LauncherTakeoverService) {

    companion object {
        private const val TAG = "InputReplyManager"
        private const val FORMAT_AGENT = "input-reply-agent-v1"

        @Volatile
        var instance: InputReplyManager? = null
            private set

        fun initialize(service: LauncherTakeoverService): InputReplyManager {
            return instance ?: synchronized(this) {
                instance ?: InputReplyManager(service).also { instance = it }
            }
        }

        fun mapToJson(map: Map<*, *>): JSONObject {
            val obj = JSONObject()
            for ((key, value) in map) {
                if (key == null) continue
                obj.put(key.toString(), wrapJsonValue(value))
            }
            return obj
        }

        fun listToJson(list: List<*>): JSONArray {
            val arr = JSONArray()
            for (item in list) {
                arr.put(wrapJsonValue(item))
            }
            return arr
        }

        private fun wrapJsonValue(value: Any?): Any {
            return when (value) {
                null -> JSONObject.NULL
                is Map<*, *> -> mapToJson(value)
                is List<*> -> listToJson(value)
                is Array<*> -> listToJson(value.toList())
                is Number, is Boolean, is String -> value
                else -> value.toString()
            }
        }

        fun jsonToMap(json: JSONObject): Map<String, Any?> {
            val map = mutableMapOf<String, Any?>()
            val keys = json.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                val value = json.get(key)
                map[key] = when (value) {
                    is JSONObject -> jsonToMap(value)
                    is JSONArray -> jsonToList(value)
                    JSONObject.NULL -> null
                    else -> value
                }
            }
            return map
        }

        fun jsonToList(array: JSONArray): List<Any?> {
            val list = mutableListOf<Any?>()
            for (i in 0 until array.length()) {
                val value = array.get(i)
                list.add(
                    when (value) {
                        is JSONObject -> jsonToMap(value)
                        is JSONArray -> jsonToList(value)
                        JSONObject.NULL -> null
                        else -> value
                    }
                )
            }
            return list
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    private val overlay = InputReplyOverlay(service)

    // ── Recording State ──────────────────────────────────────────────────────
    private var isRecording = false
    private var activeRecordingName = ""
    private var activeRecordingMode = "hybrid"
    private var recordingStartTime = 0L
    private var lastActionTime = 0L
    private var activePackageName = ""
    private val recordedSteps = mutableListOf<Map<String, Any?>>()
    private val recordedParameters = mutableListOf<Map<String, Any?>>()
    private var lastTextEditNodeId: String? = null
    private var lastTextEditStepIndex = -1
    private var lastActionWasType = false

    // ── Replay State ────────────────────────────────────────────────────────
    private var isReplaying = false
    private var shouldAbortReplay = false

    // ── Touch Sensor & Keyboard State ──────────────────────────────────────
    private var lastRecordedTapTime = 0L
    private var lastRecordedSwipeTime = 0L
    private var lastRecordedViewId: String? = null
    private var lastRecordedX: Int = -1
    private var lastRecordedY: Int = -1
    private var isKeyboardActive = false
    private var activeImePackageVisible = false

    private val keyboardCheckRunnable = object : Runnable {
        override fun run() {
            if (!isRecording) return
            checkKeyboardState()
            mainHandler.postDelayed(this, 350L)
        }
    }

    init {
        overlay.onStopClicked = {
            if (isRecording) {
                stopRecording()
            } else if (isReplaying) {
                stopReplay()
            }
        }
    }

    fun isKeyboardShowing(): Boolean {
        // 1. AccessibilityWindowInfo check for TYPE_INPUT_METHOD
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val windows = service.windows
                if (!windows.isNullOrEmpty()) {
                    val dm = service.resources.displayMetrics
                    val imeWindow = windows.firstOrNull { it.type == AccessibilityWindowInfo.TYPE_INPUT_METHOD }
                    if (imeWindow != null) {
                        val rect = Rect()
                        imeWindow.getBoundsInScreen(rect)
                        // A visible soft keyboard occupies substantial vertical screen space
                        if (rect.height() > (dm.heightPixels * 0.15f)) {
                            return true
                        }
                    }
                }
            }
        } catch (_: Exception) {}

        // 2. Focused editable node with IME package active
        try {
            val root = service.rootInActiveWindow
            if (root != null) {
                val focused = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
                if (focused != null && focused.isEditable && activeImePackageVisible) {
                    return true
                }
            }
        } catch (_: Exception) {}

        return false
    }

    fun checkKeyboardState() {
        if (!isRecording) return
        val showing = isKeyboardShowing()
        if (showing != isKeyboardActive) {
            isKeyboardActive = showing
            mainHandler.post {
                overlay.setKeyboardOpen(showing)
            }
            Log.i(TAG, "Soft keyboard state changed: isOpen=$showing (sensor touchable=${!showing})")
        }
    }

    fun handleKeyEvent(event: KeyEvent): Boolean {
        if (!isRecording) return false
        if (event.action != KeyEvent.ACTION_UP) return false

        when (event.keyCode) {
            KeyEvent.KEYCODE_BACK -> {
                recordKeyAction("BACK", "Hardware/Nav Back key")
                return true
            }
            KeyEvent.KEYCODE_ENTER, KeyEvent.KEYCODE_NUMPAD_ENTER -> {
                recordKeyAction("ENTER", "Keyboard Enter key")
                return true
            }
        }
        return false
    }

    fun recordKeyAction(key: String, desc: String? = null) {
        if (!isRecording) return
        val now = SystemClock.elapsedRealtime()
        val deltaSec = ((now - lastActionTime) / 1000f).coerceIn(0.2f, 4.0f)
        addWaitStep(deltaSec)
        val step = mapOf(
            "type" to "key",
            "key" to key,
            "desc" to (desc ?: key),
            "package" to activePackageName
        )
        recordedSteps.add(step)
        lastActionTime = now
        lastTextEditNodeId = null
        lastTextEditStepIndex = -1
        updateOverlay()
        Log.i(TAG, "Recorded key action: $key ($desc)")

        if (key == "BACK") {
            mainHandler.postDelayed({ checkKeyboardState() }, 120L)
            mainHandler.postDelayed({ checkKeyboardState() }, 350L)
        }
    }

    private fun getRecordingsDir(): File {
        val dir = File(service.filesDir, "input_reply/recordings")
        if (!dir.exists()) dir.mkdirs()
        return dir
    }

    // ── Public API ──────────────────────────────────────────────────────────

    fun isRecordingActive(): Boolean = isRecording
    fun isReplayingActive(): Boolean = isReplaying

    fun startRecording(name: String, targetPackage: String? = null, mode: String = "hybrid"): Boolean {
        if (isRecording) return true
        isRecording = true
        activeRecordingMode = when (mode.lowercase()) {
            "touch_sensor", "touch" -> "touch_sensor"
            "elements", "element" -> "elements"
            else -> "hybrid"
        }
        activeRecordingName = if (name.isNotBlank()) name.trim() else "macro_${System.currentTimeMillis()}"
        recordingStartTime = SystemClock.elapsedRealtime()
        lastActionTime = recordingStartTime
        activePackageName = targetPackage ?: ""
        recordedSteps.clear()
        recordedParameters.clear()
        lastTextEditNodeId = null
        lastTextEditStepIndex = -1
        lastActionWasType = false

        // If target package is supplied, record initial launch step
        if (!targetPackage.isNullOrBlank()) {
            recordedSteps.add(
                mapOf(
                    "type" to "launch",
                    "app" to targetPackage
                )
            )
        }

        // Show floating HUD controller over all apps
        isKeyboardActive = false
        activeImePackageVisible = false
        mainHandler.post {
            overlay.showRecording(activeRecordingName, activeRecordingMode)
            service.updateEventFilter()
            mainHandler.postDelayed(keyboardCheckRunnable, 350L)
        }

        // Launch target app if provided
        if (!targetPackage.isNullOrBlank()) {
            val launchIntent = service.packageManager.getLaunchIntentForPackage(targetPackage)
            if (launchIntent != null) {
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                try { service.startActivity(launchIntent) } catch (_: Exception) {}
            }
        }

        Log.i(TAG, "Started recording whole-device macro: $activeRecordingName (mode: $activeRecordingMode)")
        return true
    }

    fun stopRecording(): Map<String, Any?>? {
        if (!isRecording) return null

        mainHandler.removeCallbacks(keyboardCheckRunnable)
        isKeyboardActive = false
        activeImePackageVisible = false
        isRecording = false
        lastActionWasType = false

        mainHandler.post {
            overlay.hide()
            service.updateEventFilter()
        }

        // Build macro JSON
        val dm = service.resources.displayMetrics
        val macro = mutableMapOf<String, Any?>(
            "format" to FORMAT_AGENT,
            "name" to activeRecordingName,
            "mode" to activeRecordingMode,
            "created_at" to SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).format(Date()),
            "screen" to listOf(dm.widthPixels, dm.heightPixels),
            "target_package" to activePackageName,
            "parameters" to recordedParameters.toList(),
            "steps" to recordedSteps.toList()
        )

        // Save to storage
        saveMacroToFile(activeRecordingName, macro)
        Log.i(TAG, "Finished recording macro: $activeRecordingName ($activeRecordingMode) with ${recordedSteps.size} steps")
        return macro
    }

    fun cancelRecording() {
        if (!isRecording) return
        mainHandler.removeCallbacks(keyboardCheckRunnable)
        isKeyboardActive = false
        activeImePackageVisible = false
        isRecording = false
        lastActionWasType = false
        recordedSteps.clear()
        recordedParameters.clear()
        mainHandler.post {
            overlay.hide()
            service.updateEventFilter()
        }
        Log.i(TAG, "Cancelled recording")
    }

    private fun isImePackage(pkg: String): Boolean {
        if (pkg.contains("inputmethod", ignoreCase = true) ||
            pkg.contains("keyboard", ignoreCase = true) ||
            pkg.contains("honeyboard", ignoreCase = true) ||
            pkg.contains("swiftkey", ignoreCase = true)
        ) {
            return true
        }
        return try {
            val imm = service.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
            imm?.enabledInputMethodList?.any { it.packageName == pkg } ?: false
        } catch (_: Exception) {
            false
        }
    }

    // ── Accessibility Event Capturing ────────────────────────────────────────

    fun handleAccessibilityEvent(event: AccessibilityEvent) {
        if (!isRecording) return

        val pkg = event.packageName?.toString() ?: return
        // Ignore events from our own application package while recording unless it's the intended target
        if (pkg == service.packageName && activePackageName.isNotEmpty() && activePackageName != service.packageName) {
            return
        }

        val now = SystemClock.elapsedRealtime()
        val deltaSec = ((now - lastActionTime) / 1000f).coerceIn(0.2f, 4.0f)

        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOWS_CHANGED -> {
                checkKeyboardState()
            }

            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                // Soft keyboard popups should not trigger app-launch step
                if (isImePackage(pkg)) {
                    activeImePackageVisible = true
                    checkKeyboardState()
                    return
                }

                if (pkg != activePackageName && pkg != service.packageName) {
                    // App changed
                    activeImePackageVisible = false
                    checkKeyboardState()
                    addWaitStep(deltaSec)
                    recordedSteps.add(
                        mapOf(
                            "type" to "launch",
                            "app" to pkg
                        )
                    )
                    activePackageName = pkg
                    lastActionTime = now
                    updateOverlay()
                }
            }

            AccessibilityEvent.TYPE_VIEW_CLICKED -> {
                // Filter out immediate double-fire from Android view hierarchy (e.g. child & parent within 60ms)
                val rawNode = event.source
                val rawViewId = rawNode?.viewIdResourceName
                if (now - lastRecordedTapTime < 60L && rawViewId != null && rawViewId == lastRecordedViewId) {
                    return
                }

                // If this is an IME soft keyboard package, check if user tapped the Action/Send/Done/Enter key
                if (isImePackage(pkg)) {
                    val imeDesc = (event.contentDescription?.toString() ?: "").lowercase()
                    val imeText = event.text.joinToString("").lowercase()
                    val isActionKey = imeDesc.contains("send") || imeDesc.contains("done") ||
                                      imeDesc.contains("enter") || imeDesc.contains("go") ||
                                      imeDesc.contains("search") || imeDesc.contains("return") ||
                                      imeText.contains("send") || imeText.contains("done") ||
                                      imeText.contains("enter")
                    if (isActionKey) {
                        addWaitStep(deltaSec)
                        recordedSteps.add(
                            mapOf(
                                "type" to "key",
                                "key" to "ENTER",
                                "desc" to "IME_ACTION"
                            )
                        )
                        lastActionTime = now
                        lastTextEditNodeId = null
                        lastTextEditStepIndex = -1
                        updateOverlay()
                    }
                    return
                }

                // 1. Check if user tapped a navigation or system Back button to close keyboard or navigate
                val eventNode = event.source
                val eventViewId = eventNode?.viewIdResourceName ?: ""
                val eventDesc = event.contentDescription?.toString() ?: ""
                val isNavBack = (pkg.contains("systemui", ignoreCase = true) && (eventViewId.contains("back", ignoreCase = true) || eventDesc.contains("back", ignoreCase = true))) ||
                                eventDesc.equals("back", ignoreCase = true) ||
                                eventDesc.equals("navigate up", ignoreCase = true) ||
                                eventViewId.endsWith(":id/back")
                if (isNavBack) {
                    recordKeyAction("BACK", "Navigation Back")
                    checkKeyboardState()
                    return
                }

                // Resolve clicked node or fallback bounds gracefully so taps are NEVER dropped
                var node = eventNode
                if (node == null && event.recordCount > 0) {
                    node = event.getRecord(0)?.source
                }
                if (node == null) {
                    val root = service.rootInActiveWindow
                    val d = event.contentDescription?.toString()
                    val t = if (event.text.isNotEmpty()) event.text.joinToString("") else null
                    if (root != null) {
                        if (!d.isNullOrEmpty()) {
                            node = root.findAccessibilityNodeInfosByText(d).firstOrNull()
                        }
                        if (node == null && !t.isNullOrEmpty()) {
                            node = root.findAccessibilityNodeInfosByText(t).firstOrNull()
                        }
                    }
                }

                val dm = service.resources.displayMetrics
                val rect = Rect()
                val wasAfterType = lastActionWasType
                lastActionWasType = false

                var viewId: String? = node?.viewIdResourceName ?: event.source?.viewIdResourceName
                var desc: String? = event.contentDescription?.toString() ?: node?.contentDescription?.toString()
                var text: String? = if (event.text.isNotEmpty()) event.text.joinToString("") else node?.text?.toString()

                val sKeywords = listOf("send", "submit", "post", "reply", "compose_send", "send_button", "send_message", "btn_send", "action_send")
                val isSendEvent = sKeywords.any { k ->
                    (desc?.contains(k, ignoreCase = true) == true) ||
                    (viewId?.contains(k, ignoreCase = true) == true) ||
                    (text?.contains(k, ignoreCase = true) == true)
                }

                // If node is not found and it's a send action or tap right after typing, search other windows for send button
                if (node == null && (isSendEvent || wasAfterType)) {
                    try {
                        val windows = service.windows
                        if (!windows.isNullOrEmpty()) {
                            for (w in windows) {
                                val r = w.root ?: continue
                                val candidate = findSmartSendNode(r)
                                if (candidate != null) {
                                    node = candidate
                                    break
                                }
                            }
                        }
                    } catch (_: Exception) {}
                }

                if (node != null) {
                    node.getBoundsInScreen(rect)
                    // If node is a huge container (width > 40% screen and height > 20% screen),
                    // drill down to find the specific clickable leaf child so center doesn't hit keyboard center
                    if (node.childCount > 0 && (rect.width() > (dm.widthPixels * 0.4f) || rect.height() > (dm.heightPixels * 0.2f))) {
                        val leaf = findSmallestClickableNode(node, dm)
                        if (leaf != null) {
                            leaf.getBoundsInScreen(rect)
                            if (leaf.viewIdResourceName != null) viewId = leaf.viewIdResourceName
                            if (leaf.contentDescription != null) desc = leaf.contentDescription.toString()
                            if (leaf.text != null) text = leaf.text.toString()
                        }
                    }
                    if (viewId == null) viewId = node.viewIdResourceName
                    if (desc.isNullOrEmpty()) desc = node.contentDescription?.toString()
                    if (text.isNullOrEmpty()) text = node.text?.toString()
                }

                // Prevent defaulting to center screen ('v' key zone):
                val finalCenterX = if (rect.width() > 0) {
                    rect.centerX().coerceAtLeast(0)
                } else if (isSendEvent) {
                    (dm.widthPixels * 0.92f).roundToInt()
                } else {
                    dm.widthPixels / 2
                }

                val finalCenterY = if (rect.height() > 0) {
                    rect.centerY().coerceAtLeast(0)
                } else if (isSendEvent) {
                    if (isKeyboardActive) (dm.heightPixels * 0.58f).roundToInt() else (dm.heightPixels * 0.94f).roundToInt()
                } else {
                    dm.heightPixels - 100
                }

                val xRatio = if (dm.widthPixels > 0) (finalCenterX.toFloat() / dm.widthPixels).coerceIn(0.01f, 0.99f) else 0.5f
                val yRatio = if (dm.heightPixels > 0) (finalCenterY.toFloat() / dm.heightPixels).coerceIn(0.01f, 0.99f) else 0.85f

                addWaitStep(deltaSec)
                val step = mutableMapOf<String, Any?>(
                    "type" to "click",
                    "x" to finalCenterX,
                    "y" to finalCenterY,
                    "xRatio" to xRatio,
                    "yRatio" to yRatio,
                    "count" to 1,
                    "viewId" to viewId,
                    "desc" to desc,
                    "text" to text,
                    "package" to pkg,
                    "isSend" to isSendEvent,
                    "isAfterType" to wasAfterType
                )
                recordedSteps.add(step)
                lastActionTime = now
                lastRecordedTapTime = now
                lastRecordedViewId = viewId
                lastRecordedX = finalCenterX
                lastRecordedY = finalCenterY
                lastTextEditNodeId = null
                lastTextEditStepIndex = -1
                overlay.showTapIndicator(finalCenterX.toFloat(), finalCenterY.toFloat())
                updateOverlay()
                checkKeyboardState()
            }

            AccessibilityEvent.TYPE_VIEW_LONG_CLICKED -> {
                if (isImePackage(pkg)) return

                val node = event.source ?: return
                val rect = Rect()
                node.getBoundsInScreen(rect)
                val dm = service.resources.displayMetrics

                addWaitStep(deltaSec)
                val step = mutableMapOf<String, Any?>(
                    "type" to "long_click",
                    "x" to rect.centerX(),
                    "y" to rect.centerY(),
                    "duration" to 600,
                    "viewId" to node.viewIdResourceName,
                    "desc" to node.contentDescription?.toString(),
                    "package" to pkg
                )
                recordedSteps.add(step)
                lastActionTime = now
                lastRecordedTapTime = now
                lastRecordedViewId = node.viewIdResourceName
                lastRecordedX = rect.centerX()
                lastRecordedY = rect.centerY()
                lastTextEditNodeId = null
                lastTextEditStepIndex = -1
                overlay.showTapIndicator(rect.centerX().toFloat(), rect.centerY().toFloat())
                updateOverlay()
            }

            AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED -> {
                activeImePackageVisible = true
                lastActionWasType = true
                checkKeyboardState()

                val node = event.source
                val eventText = if (event.text.isNotEmpty()) event.text.joinToString("") else ""
                val nodeText = node?.text?.toString() ?: ""
                val text = if (nodeText.isNotEmpty()) nodeText else eventText
                if (text.isEmpty()) return

                val targetPkg = if (isImePackage(pkg)) activePackageName.ifEmpty { pkg } else pkg
                val nodeId = node?.viewIdResourceName 
                    ?: (if (node != null) "${node.className}_${node.hashCode()}" else "${event.className}_${targetPkg}")

                if (lastTextEditNodeId == nodeId && lastTextEditStepIndex >= 0 && lastTextEditStepIndex < recordedSteps.size) {
                    // Update existing typing block in-place
                    val existing = recordedSteps[lastTextEditStepIndex].toMutableMap()
                    existing["text"] = text
                    recordedSteps[lastTextEditStepIndex] = existing
                } else {
                    // New typing block
                    addWaitStep(deltaSec)
                    val step = mutableMapOf<String, Any?>(
                        "type" to "type",
                        "text" to text,
                        "viewId" to node?.viewIdResourceName,
                        "desc" to node?.contentDescription?.toString(),
                        "package" to targetPkg
                    )
                    recordedSteps.add(step)
                    lastTextEditNodeId = nodeId
                    lastTextEditStepIndex = recordedSteps.size - 1
                    updateOverlay()
                }
                lastActionTime = now
            }

            AccessibilityEvent.TYPE_VIEW_SCROLLED -> {
                // Ignore scroll events generated by or immediately following direct touch taps or swipes
                if (now - lastRecordedSwipeTime < 800L || now - lastRecordedTapTime < 500L) {
                    return
                }
                val deltaX = event.scrollDeltaX
                val deltaY = event.scrollDeltaY
                val absDeltaX = kotlin.math.abs(deltaX)
                val absDeltaY = kotlin.math.abs(deltaY)

                // Ignore sub-threshold micro-scroll jitter from finger tapping/releasing
                if (absDeltaX < 25 && absDeltaY < 25) {
                    return
                }

                addWaitStep(deltaSec)
                val direction = when {
                    deltaY > 0 -> "down"
                    deltaY < 0 -> "up"
                    deltaX > 0 -> "right"
                    else -> "left"
                }
                recordedSteps.add(
                    mapOf(
                        "type" to "scroll",
                        "direction" to direction,
                        "dx" to deltaX,
                        "dy" to deltaY,
                        "package" to pkg
                    )
                )
                lastActionTime = now
                updateOverlay()
            }
        }
    }

    private fun addWaitStep(seconds: Float) {
        if (seconds >= 0.35f && recordedSteps.isNotEmpty()) {
            val rounded = (seconds * 10f).roundToInt() / 10f
            recordedSteps.add(
                mapOf(
                    "type" to "wait",
                    "seconds" to rounded
                )
            )
        }
    }

    private fun updateOverlay() {
        mainHandler.post {
            overlay.stepCount = recordedSteps.filter { it["type"] != "wait" }.size
            overlay.activePackageLabel = activePackageName
        }
    }

    // ── Replay Execution ─────────────────────────────────────────────────────

    fun playMacro(
        macroData: Map<String, Any?>,
        runtimeParams: Map<String, Any?>? = null,
        speedMultiplier: Double = 1.0,
        repeatCount: Int = 1,
        modeOverride: String? = null
    ): Boolean {
        if (isReplaying) return false
        isReplaying = true
        shouldAbortReplay = false

        val steps = (macroData["steps"] as? List<*>)?.filterIsInstance<Map<String, Any?>>() ?: return false
        val macroName = macroData["name"] as? String ?: "Macro"
        val effectiveMode = when ((modeOverride ?: macroData["mode"] as? String ?: "hybrid").lowercase()) {
            "touch_sensor", "touch" -> "touch_sensor"
            "elements", "element" -> "elements"
            else -> "hybrid"
        }
        val params = runtimeParams ?: emptyMap()

        executor.execute {
            try {
                val nonWaitSteps = steps.filter { it["type"] != "wait" }
                val totalSteps = nonWaitSteps.size

                for (loop in 1..repeatCount.coerceAtLeast(1)) {
                    if (shouldAbortReplay) break

                    var currentStepIdx = 0
                    var replayLastStepWasType = false
                    for (step in steps) {
                        if (shouldAbortReplay) break

                        val type = step["type"] as? String ?: continue
                        if (type != "wait") {
                            currentStepIdx++
                            mainHandler.post {
                                overlay.showReplaying(currentStepIdx, totalSteps, macroName, effectiveMode)
                            }
                        }

                        executeSingleStep(step, params, speedMultiplier, effectiveMode, replayLastStepWasType)
                        if (type == "type") {
                            replayLastStepWasType = true
                        } else if (type != "wait") {
                            replayLastStepWasType = false
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error during macro replay", e)
            } finally {
                isReplaying = false
                shouldAbortReplay = false
                mainHandler.post {
                    overlay.hide()
                }
            }
        }
        return true
    }

    fun stopReplay() {
        if (!isReplaying) return
        shouldAbortReplay = true
        mainHandler.post {
            overlay.hide()
        }
        Log.i(TAG, "Replay aborted by user")
    }

    private fun executeSingleStep(
        step: Map<String, Any?>,
        params: Map<String, Any?>,
        speed: Double,
        mode: String = "hybrid",
        wasAfterType: Boolean = false
    ) {
        val type = step["type"] as? String ?: return

        when (type) {
            "wait" -> {
                val sec = (step["seconds"] as? Number)?.toDouble() ?: 0.5
                val sleepMs = ((sec / speed.coerceAtLeast(0.1)) * 1000).toLong().coerceAtLeast(50L)
                SystemClock.sleep(sleepMs)
            }

            "launch" -> {
                val app = step["app"] as? String ?: return
                val intent = service.packageManager.getLaunchIntentForPackage(app)
                if (intent != null) {
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    service.startActivity(intent)
                    SystemClock.sleep((600 / speed).toLong().coerceAtLeast(200L))
                }
            }

            "click" -> {
                val dm = service.resources.displayMetrics
                val xRatio = (step["xRatio"] as? Number)?.toFloat()
                val yRatio = (step["yRatio"] as? Number)?.toFloat()
                var targetX = if (xRatio != null && xRatio in 0.0f..1.0f) {
                    xRatio * dm.widthPixels
                } else {
                    (step["x"] as? Number)?.toFloat() ?: (dm.widthPixels / 2f)
                }
                var targetY = if (yRatio != null && yRatio in 0.0f..1.0f) {
                    yRatio * dm.heightPixels
                } else {
                    (step["y"] as? Number)?.toFloat() ?: (dm.heightPixels / 2f)
                }

                val viewId = step["viewId"] as? String
                val text = step["text"] as? String
                val desc = step["desc"] as? String
                val isSendExplicit = (step["isSend"] as? Boolean) == true
                val isAfterTypeExplicit = (step["isAfterType"] as? Boolean) == true || wasAfterType

                val sKeywords = listOf("send", "submit", "post", "reply", "compose_send", "send_button", "send_message", "btn_send", "action_send")
                val isSendAction = isSendExplicit || sKeywords.any { k ->
                    (desc?.contains(k, ignoreCase = true) == true) ||
                    (viewId?.contains(k, ignoreCase = true) == true) ||
                    (text?.contains(k, ignoreCase = true) == true)
                }

                // If this action occurs after typing, or is a send/submit action, wait for target app UI to update
                if (isAfterTypeExplicit || isSendAction) {
                    SystemClock.sleep((240 / speed.coerceAtLeast(0.5)).toLong().coerceIn(120L, 400L))
                }

                // If keyboard was closed during replay, adjust coordinates away from keyboard center ('v' key zone) to send area
                if (isSendAction || isAfterTypeExplicit) {
                    val keyboardOpenNow = isKeyboardShowing()
                    if (!keyboardOpenNow) {
                        val isCenterHorizontal = targetX > (dm.widthPixels * 0.30f) && targetX < (dm.widthPixels * 0.70f)
                        val isKeyboardHeight = targetY > (dm.heightPixels * 0.50f) && targetY < (dm.heightPixels * 0.75f)
                        if (isSendAction && (isCenterHorizontal || isKeyboardHeight)) {
                            Log.w(TAG, "Replay: correcting send action coordinates away from keyboard center to send area")
                            targetX = dm.widthPixels * 0.92f
                            targetY = dm.heightPixels * 0.94f
                        }
                    }
                }

                var handled = false

                // 1. ELEMENTS or HYBRID MODE: Search live UI elements first to avoid layout/keyboard shift issues
                if (mode == "elements" || mode == "hybrid") {
                    if (isSendAction) {
                        handled = clickSmartSendButton()
                        if (handled) Log.i(TAG, "Replayed send action via clickSmartSendButton ($mode)")
                    }
                    if (!handled && !viewId.isNullOrEmpty()) {
                        handled = clickNodeByViewId(viewId)
                        if (handled) Log.i(TAG, "Replayed click via viewId '$viewId' ($mode)")
                    }
                    if (!handled && !text.isNullOrEmpty()) {
                        handled = clickNodeByText(text)
                        if (handled) Log.i(TAG, "Replayed click via text '$text' ($mode)")
                    }
                    if (!handled && !desc.isNullOrEmpty()) {
                        handled = clickNodeByDesc(desc)
                        if (handled) Log.i(TAG, "Replayed click via desc '$desc' ($mode)")
                    }
                    if (!handled && isAfterTypeExplicit) {
                        handled = clickSmartSendButton()
                        if (handled) Log.i(TAG, "Replayed after-type click via clickSmartSendButton fallback")
                    }
                }

                // 2. TOUCH_SENSOR or HYBRID fallback: Real physical touch coordinate injection
                if (!handled) {
                    mainHandler.post {
                        overlay.showReplayTapIndicator(targetX, targetY)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        handled = dispatchTapGestureSync(targetX, targetY, 45L)
                        Log.i(TAG, "Replayed step 'click' via touch tap at ($targetX, $targetY) - result=$handled ($mode)")
                    }
                }

                // 3. TOUCH_SENSOR fallback: If touch tap failed, try nodes as secondary fallback
                if (!handled && mode == "touch_sensor") {
                    if (isSendAction) handled = clickSmartSendButton()
                    if (!handled && !viewId.isNullOrEmpty()) handled = clickNodeByViewId(viewId)
                    if (!handled && !text.isNullOrEmpty()) handled = clickNodeByText(text)
                    if (!handled && !desc.isNullOrEmpty()) handled = clickNodeByDesc(desc)
                }

                SystemClock.sleep((100 / speed).toLong().coerceAtLeast(30L))
            }

            "long_click" -> {
                val dm = service.resources.displayMetrics
                val x = (step["x"] as? Number)?.toFloat() ?: (dm.widthPixels / 2f)
                val y = (step["y"] as? Number)?.toFloat() ?: (dm.heightPixels / 2f)
                val duration = (step["duration"] as? Number)?.toLong() ?: 600L

                dispatchTapGesture(x, y, duration)
                SystemClock.sleep((300 / speed).toLong().coerceAtLeast(100L))
            }

            "type" -> {
                val paramKey = step["param"] as? String
                var textToType = if (!paramKey.isNullOrEmpty() && params.containsKey(paramKey)) {
                    params[paramKey]?.toString() ?: ""
                } else {
                    step["text"]?.toString() ?: ""
                }
                if (params.isNotEmpty()) {
                    for ((k, v) in params) {
                        if (k.isNotBlank() && v != null) {
                            textToType = textToType.replace("\$$k", v.toString())
                                                   .replace("\${$k}", v.toString())
                        }
                    }
                }

                val viewId = step["viewId"] as? String
                var typed = false
                if (!viewId.isNullOrEmpty()) {
                    typed = setNodeTextByViewId(viewId, textToType)
                }
                if (!typed) {
                    typed = setFocusedNodeText(textToType)
                }
                if (!typed) {
                    // Clipboard paste fallback
                    val cm = service.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                    cm.setPrimaryClip(ClipData.newPlainText("macro_text", textToType))
                    var pasted = false
                    for (root in getAllRoots()) {
                        val focused = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
                        if (focused != null && focused.isEditable) {
                            pasted = focused.performAction(AccessibilityNodeInfo.ACTION_PASTE)
                            if (pasted) break
                        }
                    }
                    if (!pasted) {
                        service.rootInActiveWindow?.performAction(AccessibilityNodeInfo.ACTION_PASTE)
                    }
                }
                SystemClock.sleep((250 / speed).toLong().coerceAtLeast(100L))
            }

            "scroll" -> {
                val direction = step["direction"] as? String ?: "down"
                val dm = service.resources.displayMetrics
                val midX = dm.widthPixels / 2f
                val startY = dm.heightPixels * 0.7f
                val endY = dm.heightPixels * 0.3f

                val path = Path()
                if (direction == "down") {
                    path.moveTo(midX, startY)
                    path.lineTo(midX, endY)
                } else if (direction == "up") {
                    path.moveTo(midX, endY)
                    path.lineTo(midX, startY)
                } else if (direction == "right") {
                    path.moveTo(dm.widthPixels * 0.2f, dm.heightPixels / 2f)
                    path.lineTo(dm.widthPixels * 0.8f, dm.heightPixels / 2f)
                } else {
                    path.moveTo(dm.widthPixels * 0.8f, dm.heightPixels / 2f)
                    path.lineTo(dm.widthPixels * 0.2f, dm.heightPixels / 2f)
                }

                dispatchSwipeGesture(path, 300L)
                SystemClock.sleep((400 / speed).toLong().coerceAtLeast(150L))
            }

            "key" -> {
                val key = step["keys"] as? String ?: step["key"] as? String ?: ""
                when (key.uppercase()) {
                    "BACK" -> {
                        service.performGlobalAction(AccessibilityService.GLOBAL_ACTION_BACK)
                        // Give system and soft keyboard time to complete dismissal transition
                        SystemClock.sleep((350 / speed).toLong().coerceAtLeast(150L))
                    }
                    "HOME" -> service.performGlobalAction(AccessibilityService.GLOBAL_ACTION_HOME)
                    "RECENTS" -> service.performGlobalAction(AccessibilityService.GLOBAL_ACTION_RECENTS)
                    "NOTIFICATIONS" -> service.performGlobalAction(AccessibilityService.GLOBAL_ACTION_NOTIFICATIONS)
                    "ENTER", "SEND", "DONE" -> {
                        val dm = service.resources.displayMetrics
                        val sendX = dm.widthPixels * 0.9f
                        val sendY = if (isKeyboardActive) dm.heightPixels * 0.58f else dm.heightPixels * 0.92f
                        mainHandler.post {
                            overlay.showReplayTapIndicator(sendX, sendY)
                        }
                        var handled = false
                        for (root in getAllRoots()) {
                            val focused = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
                            if (focused != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                                handled = focused.performAction(AccessibilityNodeInfo.AccessibilityAction.ACTION_IME_ENTER.id)
                                if (handled) break
                            }
                        }
                        if (!handled) {
                            handled = clickSmartSendButton()
                        }
                        if (!handled && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                            dispatchTapGesture(sendX, sendY, 50L)
                        }
                    }
                }
                SystemClock.sleep((300 / speed).toLong().coerceAtLeast(100L))
            }
        }
    }

    private fun findNodeAtPoint(parent: AccessibilityNodeInfo, px: Int, py: Int): AccessibilityNodeInfo? {
        val temp = Rect()
        var bestMatch: AccessibilityNodeInfo? = null
        var minArea = Long.MAX_VALUE

        fun walk(n: AccessibilityNodeInfo) {
            n.getBoundsInScreen(temp)
            if (temp.contains(px, py)) {
                val area = temp.width().toLong() * temp.height().toLong()
                if (area in 1 until minArea) {
                    minArea = area
                    bestMatch = n
                }
            }
            for (i in 0 until n.childCount) {
                val c = n.getChild(i) ?: continue
                walk(c)
            }
        }
        walk(parent)
        return bestMatch
    }

    private fun findSmallestClickableNode(parent: AccessibilityNodeInfo, dm: android.util.DisplayMetrics): AccessibilityNodeInfo? {
        var smallest: AccessibilityNodeInfo? = null
        var minArea = Long.MAX_VALUE
        val r = Rect()

        fun search(node: AccessibilityNodeInfo) {
            node.getBoundsInScreen(r)
            val w = r.width()
            val h = r.height()
            if (w > 0 && h > 0 && w < (dm.widthPixels * 0.95f) && h < (dm.heightPixels * 0.7f)) {
                val area = w.toLong() * h.toLong()
                val isInteractive = node.isClickable ||
                                    node.actionList.any { it.id == AccessibilityNodeInfo.ACTION_CLICK } ||
                                    node.contentDescription?.contains("send", ignoreCase = true) == true ||
                                    node.viewIdResourceName?.contains("send", ignoreCase = true) == true
                if (area < minArea && isInteractive) {
                    minArea = area
                    smallest = node
                }
            }
            for (i in 0 until node.childCount) {
                val child = node.getChild(i) ?: continue
                search(child)
            }
        }
        search(parent)
        return smallest
    }

    private fun dispatchTapGesture(x: Float, y: Float, durationMs: Long): Boolean {
        return dispatchTapGestureSync(x, y, durationMs)
    }

    private fun dispatchTapGestureSync(x: Float, y: Float, durationMs: Long): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return false
        val path = Path().apply {
            moveTo(x, y)
            lineTo(x, y)
        }
        val stroke = GestureDescription.StrokeDescription(path, 0, durationMs)
        val gesture = GestureDescription.Builder().addStroke(stroke).build()
        val latch = CountDownLatch(1)
        var completed = false
        val dispatched = service.dispatchGesture(gesture, object : AccessibilityService.GestureResultCallback() {
            override fun onCompleted(gestureDescription: GestureDescription?) {
                completed = true
                latch.countDown()
            }
            override fun onCancelled(gestureDescription: GestureDescription?) {
                completed = false
                latch.countDown()
            }
        }, mainHandler)

        if (dispatched) {
            try {
                latch.await(durationMs + 600L, TimeUnit.MILLISECONDS)
            } catch (_: InterruptedException) {}
            return completed
        }
        return false
    }

    private fun dispatchSwipeGesture(path: Path, durationMs: Long) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return
        val stroke = GestureDescription.StrokeDescription(path, 0, durationMs)
        val gesture = GestureDescription.Builder().addStroke(stroke).build()
        val latch = CountDownLatch(1)
        val dispatched = service.dispatchGesture(gesture, object : AccessibilityService.GestureResultCallback() {
            override fun onCompleted(gestureDescription: GestureDescription?) {
                latch.countDown()
            }
            override fun onCancelled(gestureDescription: GestureDescription?) {
                latch.countDown()
            }
        }, mainHandler)
        if (dispatched) {
            try {
                latch.await(durationMs + 600L, TimeUnit.MILLISECONDS)
            } catch (_: InterruptedException) {}
        }
    }

    private fun clickNodeRobustly(node: AccessibilityNodeInfo): Boolean {
        val rect = Rect()
        node.getBoundsInScreen(rect)
        val hasValidBounds = rect.width() > 0 && rect.height() > 0

        // 1. Dispatch real touch gesture at CURRENT screen position
        if (hasValidBounds && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val gestureSuccess = dispatchTapGestureSync(rect.centerX().toFloat(), rect.centerY().toFloat(), 40L)
            if (gestureSuccess) {
                // Real touch gesture dispatched directly to current element coordinates
                return true
            }
        }

        // 2. Perform accessibility click action ONLY if gesture was unavailable or cancelled
        try {
            if (node.isClickable) {
                return node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            }
            var p = node.parent
            while (p != null) {
                if (p.isClickable) {
                    return p.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                }
                p = p.parent
            }
        } catch (_: Exception) {}

        return false
    }

    private fun findSmartSendNode(root: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        var bestNode: AccessibilityNodeInfo? = null
        val sKeywords = listOf("send", "submit", "post", "reply", "compose_send", "send_button", "send_message", "btn_send", "action_send")

        fun scan(node: AccessibilityNodeInfo) {
            val d = node.contentDescription?.toString() ?: ""
            val id = node.viewIdResourceName ?: ""
            val t = node.text?.toString() ?: ""
            val isSend = sKeywords.any { k ->
                d.contains(k, ignoreCase = true) ||
                id.contains(k, ignoreCase = true) ||
                t.equals(k, ignoreCase = true)
            }
            if (isSend) {
                val isClickable = node.isClickable || node.actionList.any { it.id == AccessibilityNodeInfo.ACTION_CLICK }
                if (bestNode == null || isClickable) {
                    bestNode = node
                    if (isClickable) return
                }
            }
            for (i in 0 until node.childCount) {
                val c = node.getChild(i) ?: continue
                scan(c)
                if (bestNode != null && (bestNode!!.isClickable || bestNode!!.actionList.any { it.id == AccessibilityNodeInfo.ACTION_CLICK })) {
                    return
                }
            }
        }
        scan(root)
        return bestNode
    }

    private fun getAllRoots(): List<AccessibilityNodeInfo> {
        val list = mutableListOf<AccessibilityNodeInfo>()
        service.rootInActiveWindow?.let { list.add(it) }
        try {
            val windows = service.windows
            if (!windows.isNullOrEmpty()) {
                for (w in windows) {
                    val r = w.root ?: continue
                    if (!list.contains(r)) {
                        list.add(r)
                    }
                }
            }
        } catch (_: Exception) {}
        return list
    }

    private fun clickSmartSendButton(): Boolean {
        for (root in getAllRoots()) {
            val candidate = findSmartSendNode(root)
            if (candidate != null && clickNodeRobustly(candidate)) return true
        }
        try {
            val imeAction = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                AccessibilityNodeInfo.AccessibilityAction.ACTION_IME_ENTER.id
            } else -1
            if (imeAction != -1) {
                for (root in getAllRoots()) {
                    val focused = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
                    if (focused != null && focused.performAction(imeAction)) return true
                }
            }
        } catch (_: Exception) {}
        return false
    }

    private fun clickNodeByViewId(viewId: String): Boolean {
        for (root in getAllRoots()) {
            val nodes = root.findAccessibilityNodeInfosByViewId(viewId)
            for (node in nodes) {
                if (clickNodeRobustly(node)) return true
            }
        }
        return false
    }

    private fun clickNodeByText(text: String): Boolean {
        for (root in getAllRoots()) {
            val nodes = root.findAccessibilityNodeInfosByText(text)
            for (node in nodes) {
                if (clickNodeRobustly(node)) return true
            }
        }
        return false
    }

    private fun clickNodeByDesc(desc: String): Boolean {
        for (root in getAllRoots()) {
            fun search(node: AccessibilityNodeInfo): Boolean {
                if (node.contentDescription?.toString() == desc) {
                    if (clickNodeRobustly(node)) return true
                }
                for (i in 0 until node.childCount) {
                    val child = node.getChild(i) ?: continue
                    if (search(child)) return true
                }
                return false
            }
            if (search(root)) return true
        }
        return false
    }

    private fun setNodeTextByViewId(viewId: String, text: String): Boolean {
        for (root in getAllRoots()) {
            val nodes = root.findAccessibilityNodeInfosByViewId(viewId)
            for (node in nodes) {
                if (node.isEditable) {
                    node.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
                    val args = Bundle().apply {
                        putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
                    }
                    if (node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)) return true
                }
            }
        }
        return false
    }

    private fun setFocusedNodeText(text: String): Boolean {
        for (root in getAllRoots()) {
            var focused = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
            if (focused == null) {
                fun findEditable(n: AccessibilityNodeInfo): AccessibilityNodeInfo? {
                    if (n.isEditable) return n
                    for (i in 0 until n.childCount) {
                        val c = n.getChild(i) ?: continue
                        val res = findEditable(c)
                        if (res != null) return res
                    }
                    return null
                }
                focused = findEditable(root)
            }
            if (focused != null && focused.isEditable) {
                focused.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
                val args = Bundle().apply {
                    putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
                }
                if (focused.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)) return true
            }
        }
        return false
    }

    // ── Macro File I/O ───────────────────────────────────────────────────────

    fun listSavedMacros(): List<Map<String, Any?>> {
        val dir = getRecordingsDir()
        val files = dir.listFiles { f -> f.extension == "json" } ?: return emptyList()
        val list = mutableListOf<Map<String, Any?>>()
        for (file in files) {
            try {
                val content = file.readText()
                val json = JSONObject(content)
                list.add(jsonToMap(json))
            } catch (_: Exception) {}
        }
        return list.sortedByDescending { it["created_at"]?.toString() ?: "" }
    }

    fun getMacro(name: String): Map<String, Any?>? {
        val file = File(getRecordingsDir(), if (name.endsWith(".json")) name else "$name.json")
        if (!file.exists()) return null
        return try {
            jsonToMap(JSONObject(file.readText()))
        } catch (_: Exception) { null }
    }

    fun saveMacroToFile(name: String, macroData: Map<String, Any?>): Boolean {
        val fileName = if (name.endsWith(".json")) name else "$name.json"
        val file = File(getRecordingsDir(), fileName)
        return try {
            val json = mapToJson(macroData)
            file.writeText(json.toString(2))
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save macro $name", e)
            false
        }
    }

    fun deleteMacro(name: String): Boolean {
        val fileName = if (name.endsWith(".json")) name else "$name.json"
        val file = File(getRecordingsDir(), fileName)
        return file.delete()
    }
}
