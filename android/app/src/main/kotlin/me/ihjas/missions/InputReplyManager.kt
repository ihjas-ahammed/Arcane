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
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.view.inputmethod.InputMethodManager
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.Executors
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
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    private val overlay = InputReplyOverlay(service)

    // ── Recording State ──────────────────────────────────────────────────────
    private var isRecording = false
    private var activeRecordingName = ""
    private var recordingStartTime = 0L
    private var lastActionTime = 0L
    private var activePackageName = ""
    private val recordedSteps = mutableListOf<Map<String, Any?>>()
    private val recordedParameters = mutableListOf<Map<String, Any?>>()
    private var lastTextEditNodeId: String? = null
    private var lastTextEditStepIndex = -1

    // ── Replay State ────────────────────────────────────────────────────────
    private var isReplaying = false
    private var shouldAbortReplay = false

    init {
        overlay.onStopClicked = {
            if (isRecording) {
                stopRecording()
            } else if (isReplaying) {
                stopReplay()
            }
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

    fun startRecording(name: String, targetPackage: String? = null): Boolean {
        if (isRecording) return true
        isRecording = true
        activeRecordingName = if (name.isNotBlank()) name.trim() else "macro_${System.currentTimeMillis()}"
        recordingStartTime = SystemClock.elapsedRealtime()
        lastActionTime = recordingStartTime
        activePackageName = targetPackage ?: ""
        recordedSteps.clear()
        recordedParameters.clear()
        lastTextEditNodeId = null
        lastTextEditStepIndex = -1

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
        mainHandler.post {
            overlay.showRecording(activeRecordingName)
            service.updateEventFilter()
        }

        // Launch target app if provided
        if (!targetPackage.isNullOrBlank()) {
            val launchIntent = service.packageManager.getLaunchIntentForPackage(targetPackage)
            if (launchIntent != null) {
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                try { service.startActivity(launchIntent) } catch (_: Exception) {}
            }
        }

        Log.i(TAG, "Started recording whole-device macro: $activeRecordingName")
        return true
    }

    fun stopRecording(): Map<String, Any?>? {
        if (!isRecording) return null
        isRecording = false

        mainHandler.post {
            overlay.hide()
            service.updateEventFilter()
        }

        // Build macro JSON
        val dm = service.resources.displayMetrics
        val macro = mutableMapOf<String, Any?>(
            "format" to FORMAT_AGENT,
            "name" to activeRecordingName,
            "created_at" to SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).format(Date()),
            "screen" to listOf(dm.widthPixels, dm.heightPixels),
            "target_package" to activePackageName,
            "parameters" to recordedParameters.toList(),
            "steps" to recordedSteps.toList()
        )

        // Save to storage
        saveMacroToFile(activeRecordingName, macro)
        Log.i(TAG, "Finished recording macro: $activeRecordingName with ${recordedSteps.size} steps")
        return macro
    }

    fun cancelRecording() {
        if (!isRecording) return
        isRecording = false
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
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                // Soft keyboard popups should not trigger app-launch step
                if (isImePackage(pkg)) return

                if (pkg != activePackageName && pkg != service.packageName) {
                    // App changed
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

                // Resolve clicked node or fallback bounds gracefully so taps are NEVER dropped
                var node = event.source
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

                val rect = Rect()
                var viewId: String? = null
                var desc: String? = event.contentDescription?.toString()
                var text: String? = if (event.text.isNotEmpty()) event.text.joinToString("") else null

                val dm = service.resources.displayMetrics
                if (node != null) {
                    node.getBoundsInScreen(rect)
                    // If container spans large screen area and has children, drill down to specific clickable child
                    if (rect.width() > (dm.widthPixels * 0.7f) && rect.height() > (dm.heightPixels * 0.35f) && node.childCount > 0) {
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

                val centerX = if (rect.width() > 0) rect.centerX().coerceAtLeast(0) else (dm.widthPixels / 2)
                val centerY = if (rect.height() > 0) rect.centerY().coerceAtLeast(0) else (dm.heightPixels - 100)
                val xRatio = if (dm.widthPixels > 0) (centerX.toFloat() / dm.widthPixels).coerceIn(0.01f, 0.99f) else 0.5f
                val yRatio = if (dm.heightPixels > 0) (centerY.toFloat() / dm.heightPixels).coerceIn(0.01f, 0.99f) else 0.85f

                addWaitStep(deltaSec)
                val step = mutableMapOf<String, Any?>(
                    "type" to "click",
                    "x" to centerX,
                    "y" to centerY,
                    "xRatio" to xRatio,
                    "yRatio" to yRatio,
                    "count" to 1,
                    "viewId" to viewId,
                    "desc" to desc,
                    "text" to text,
                    "package" to pkg
                )
                recordedSteps.add(step)
                lastActionTime = now
                lastTextEditNodeId = null
                lastTextEditStepIndex = -1
                updateOverlay()
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
                lastTextEditNodeId = null
                lastTextEditStepIndex = -1
                updateOverlay()
            }

            AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED -> {
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
                val deltaX = event.scrollDeltaX
                val deltaY = event.scrollDeltaY
                if (deltaX != 0 || deltaY != 0) {
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
        repeatCount: Int = 1
    ): Boolean {
        if (isReplaying) return false
        isReplaying = true
        shouldAbortReplay = false

        val steps = (macroData["steps"] as? List<*>)?.filterIsInstance<Map<String, Any?>>() ?: return false
        val macroName = macroData["name"] as? String ?: "Macro"
        val params = runtimeParams ?: emptyMap()

        executor.execute {
            try {
                val nonWaitSteps = steps.filter { it["type"] != "wait" }
                val totalSteps = nonWaitSteps.size

                for (loop in 1..repeatCount.coerceAtLeast(1)) {
                    if (shouldAbortReplay) break

                    var currentStepIdx = 0
                    for (step in steps) {
                        if (shouldAbortReplay) break

                        val type = step["type"] as? String ?: continue
                        if (type != "wait") {
                            currentStepIdx++
                            mainHandler.post {
                                overlay.showReplaying(currentStepIdx, totalSteps, macroName)
                            }
                        }

                        executeSingleStep(step, params, speedMultiplier)
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

    private fun executeSingleStep(step: Map<String, Any?>, params: Map<String, Any?>, speed: Double) {
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
                val targetX = if (xRatio != null && xRatio in 0.0f..1.0f) {
                    xRatio * dm.widthPixels
                } else {
                    (step["x"] as? Number)?.toFloat() ?: (dm.widthPixels / 2f)
                }
                val targetY = if (yRatio != null && yRatio in 0.0f..1.0f) {
                    yRatio * dm.heightPixels
                } else {
                    (step["y"] as? Number)?.toFloat() ?: (dm.heightPixels / 2f)
                }

                // 1. Primary execution: Accurate touch coordinate tap!
                // Directly dispatches physical tap gesture to the exact touch coordinates recorded.
                var tapped = false
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    tapped = dispatchTapGesture(targetX, targetY, 50L)
                    Log.i(TAG, "Replayed step 'click' via touch tap at ($targetX, $targetY) - result=$tapped")
                }

                // 2. Secondary fallback: Look for button nodes only if gesture dispatch failed
                if (!tapped) {
                    val viewId = step["viewId"] as? String
                    val text = step["text"] as? String
                    val desc = step["desc"] as? String

                    var clicked = false
                    if (!viewId.isNullOrEmpty()) {
                        clicked = clickNodeByViewId(viewId)
                    }
                    if (!clicked && !text.isNullOrEmpty()) {
                        clicked = clickNodeByText(text)
                    }
                    if (!clicked && !desc.isNullOrEmpty()) {
                        clicked = clickNodeByDesc(desc)
                    }
                    if (!clicked) {
                        val isSendAction = (desc?.contains("send", ignoreCase = true) == true) ||
                                           (viewId?.contains("send", ignoreCase = true) == true) ||
                                           (text?.contains("send", ignoreCase = true) == true)
                        if (isSendAction) {
                            clickSmartSendButton()
                        }
                    }
                }
                SystemClock.sleep((300 / speed).toLong().coerceAtLeast(100L))
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
                    service.rootInActiveWindow?.performAction(AccessibilityNodeInfo.ACTION_PASTE)
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
                    "BACK" -> service.performGlobalAction(AccessibilityService.GLOBAL_ACTION_BACK)
                    "HOME" -> service.performGlobalAction(AccessibilityService.GLOBAL_ACTION_HOME)
                    "RECENTS" -> service.performGlobalAction(AccessibilityService.GLOBAL_ACTION_RECENTS)
                    "NOTIFICATIONS" -> service.performGlobalAction(AccessibilityService.GLOBAL_ACTION_NOTIFICATIONS)
                    "ENTER", "SEND", "DONE" -> {
                        val root = service.rootInActiveWindow
                        var handled = false
                        if (root != null) {
                            val focused = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
                            if (focused != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                                handled = focused.performAction(AccessibilityNodeInfo.AccessibilityAction.ACTION_IME_ENTER.id)
                            }
                            if (!handled) {
                                handled = clickSmartSendButton()
                            }
                        }
                        if (!handled && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                            val dm = service.resources.displayMetrics
                            dispatchTapGesture(dm.widthPixels * 0.9f, dm.heightPixels * 0.92f, 50L)
                        }
                    }
                }
                SystemClock.sleep((300 / speed).toLong().coerceAtLeast(100L))
            }
        }
    }

    private fun findSmallestClickableNode(parent: AccessibilityNodeInfo, dm: android.util.DisplayMetrics): AccessibilityNodeInfo? {
        var smallest: AccessibilityNodeInfo? = null
        var minArea = Long.MAX_VALUE
        val r = Rect()

        fun search(node: AccessibilityNodeInfo) {
            node.getBoundsInScreen(r)
            val w = r.width()
            val h = r.height()
            if (w > 0 && h > 0 && w < (dm.widthPixels * 0.8f) && h < (dm.heightPixels * 0.4f)) {
                val area = w.toLong() * h.toLong()
                val isInteractive = node.isClickable ||
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
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return false
        val path = Path().apply {
            moveTo(x, y)
        }
        val stroke = GestureDescription.StrokeDescription(path, 0, durationMs)
        val gesture = GestureDescription.Builder().addStroke(stroke).build()
        return service.dispatchGesture(gesture, null, null)
    }

    private fun dispatchSwipeGesture(path: Path, durationMs: Long) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return
        val stroke = GestureDescription.StrokeDescription(path, 0, durationMs)
        val gesture = GestureDescription.Builder().addStroke(stroke).build()
        service.dispatchGesture(gesture, null, null)
    }

    private fun clickNodeRobustly(node: AccessibilityNodeInfo): Boolean {
        val rect = Rect()
        node.getBoundsInScreen(rect)
        val hasValidBounds = rect.width() > 0 && rect.height() > 0

        // 1. Dispatch real touch gesture at current screen position (for WhatsApp/Telegram ImageButtons and Compose)
        var gestureSuccess = false
        if (hasValidBounds && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            dispatchTapGesture(rect.centerX().toFloat(), rect.centerY().toFloat(), 50L)
            gestureSuccess = true
        }

        // 2. Perform accessibility click action
        var actionSuccess = false
        try {
            if (node.isClickable) {
                actionSuccess = node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            } else {
                var p = node.parent
                while (p != null) {
                    if (p.isClickable) {
                        actionSuccess = p.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                        break
                    }
                    p = p.parent
                }
            }
        } catch (_: Exception) {}

        return gestureSuccess || actionSuccess
    }

    private fun clickSmartSendButton(): Boolean {
        val root = service.rootInActiveWindow ?: return false
        val candidates = mutableListOf<AccessibilityNodeInfo>()
        fun scan(node: AccessibilityNodeInfo) {
            val d = node.contentDescription?.toString() ?: ""
            val id = node.viewIdResourceName ?: ""
            val t = node.text?.toString() ?: ""
            if (d.contains("send", ignoreCase = true) || id.contains("send", ignoreCase = true) || t.equals("send", ignoreCase = true)) {
                candidates.add(node)
            }
            for (i in 0 until node.childCount) {
                val c = node.getChild(i) ?: continue
                scan(c)
            }
        }
        scan(root)
        for (candidate in candidates) {
            if (clickNodeRobustly(candidate)) return true
        }
        return false
    }

    private fun clickNodeByViewId(viewId: String): Boolean {
        val root = service.rootInActiveWindow ?: return false
        val nodes = root.findAccessibilityNodeInfosByViewId(viewId)
        for (node in nodes) {
            if (clickNodeRobustly(node)) return true
        }
        return false
    }

    private fun clickNodeByText(text: String): Boolean {
        val root = service.rootInActiveWindow ?: return false
        val nodes = root.findAccessibilityNodeInfosByText(text)
        for (node in nodes) {
            if (clickNodeRobustly(node)) return true
        }
        return false
    }

    private fun clickNodeByDesc(desc: String): Boolean {
        val root = service.rootInActiveWindow ?: return false
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
        return search(root)
    }

    private fun setNodeTextByViewId(viewId: String, text: String): Boolean {
        val root = service.rootInActiveWindow ?: return false
        val nodes = root.findAccessibilityNodeInfosByViewId(viewId)
        for (node in nodes) {
            if (node.isEditable) {
                val args = Bundle().apply {
                    putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
                }
                return node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
            }
        }
        return false
    }

    private fun setFocusedNodeText(text: String): Boolean {
        val root = service.rootInActiveWindow ?: return false
        val focused = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT) ?: return false
        if (focused.isEditable) {
            val args = Bundle().apply {
                putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
            }
            return focused.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
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
            val json = JSONObject(macroData)
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

    private fun jsonToMap(json: JSONObject): Map<String, Any?> {
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

    private fun jsonToList(array: JSONArray): List<Any?> {
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
