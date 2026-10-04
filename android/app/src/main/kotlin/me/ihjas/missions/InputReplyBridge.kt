package me.ihjas.missions

import android.content.Context
import android.content.Intent
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File

class InputReplyBridge(private val context: Context, messenger: BinaryMessenger) {

    companion object {
        const val CHANNEL = "me.ihjas.arcane/input_reply"
    }

    private val channel = MethodChannel(messenger, CHANNEL)

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkAccessibility" -> {
                    result.success(LauncherTakeoverService.isServiceEnabled(context))
                }
                "openAccessibilitySettings" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    context.startActivity(intent)
                    result.success(true)
                }
                "startRecording" -> {
                    val name = call.argument<String>("name") ?: ""
                    val targetPackage = call.argument<String>("targetPackage")
                    val mode = call.argument<String>("mode") ?: "hybrid"
                    val mgr = InputReplyManager.instance
                    if (mgr != null) {
                        result.success(mgr.startRecording(name, targetPackage, mode))
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
                    val mode = call.argument<String>("mode")
                    if (macroData != null) {
                        result.success(mgr.playMacro(macroData, params, speed, repeatCount, mode))
                    } else {
                        val name = call.argument<String>("name") ?: ""
                        val loaded = mgr.getMacro(name)
                        if (loaded != null) {
                            result.success(mgr.playMacro(loaded, params, speed, repeatCount, mode))
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
                        val dir = File(context.filesDir, "input_reply/recordings")
                        val files = dir.listFiles { f -> f.extension == "json" } ?: emptyArray()
                        val list = mutableListOf<Map<String, Any?>>()
                        for (file in files) {
                            try {
                                val json = JSONObject(file.readText())
                                list.add(InputReplyManager.jsonToMap(json))
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
                        val file = File(File(context.filesDir, "input_reply/recordings"), if (name.endsWith(".json")) name else "$name.json")
                        if (file.exists()) {
                            try {
                                result.success(InputReplyManager.jsonToMap(JSONObject(file.readText())))
                            } catch (_: Exception) {
                                result.success(null)
                            }
                        } else {
                            result.success(null)
                        }
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
                            val dir = File(context.filesDir, "input_reply/recordings")
                            if (!dir.exists()) dir.mkdirs()
                            val file = File(dir, if (name.endsWith(".json")) name else "$name.json")
                            file.writeText(InputReplyManager.mapToJson(macroData).toString(2))
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
                        val file = File(File(context.filesDir, "input_reply/recordings"), if (name.endsWith(".json")) name else "$name.json")
                        result.success(file.delete())
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }
}
