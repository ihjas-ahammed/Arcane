package me.ihjas.missions

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/** Debug builds only. Results are logged under the tag "DebugReplay". */
class DebugReplayReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val mgr = InputReplyManager.instance
        if (mgr == null) {
            Log.e(TAG, "NO_MANAGER accessibility service not running")
            return
        }
        when (intent.action) {
            "me.ihjas.missions.DEBUG_RECORD_START" -> {
                val ok = mgr.startRecording(
                    intent.getStringExtra("name") ?: "dbg",
                    intent.getStringExtra("pkg"),
                    intent.getStringExtra("mode") ?: "hybrid",
                )
                Log.i(TAG, "RECORD_START ok=$ok")
            }
            "me.ihjas.missions.DEBUG_RECORD_STOP" -> {
                val macro = mgr.stopRecording()
                Log.i(TAG, "RECORD_STOP " + (macro?.let { InputReplyManager.mapToJson(it).toString() } ?: "null"))
            }
            "me.ihjas.missions.DEBUG_PLAY" -> {
                val name = intent.getStringExtra("name") ?: ""
                val macro = mgr.getMacro(name)
                if (macro == null) {
                    Log.e(TAG, "PLAY NOT_FOUND $name")
                    return
                }
                val params = intent.getStringExtra("params")?.split(",")?.mapNotNull {
                    val i = it.indexOf('=')
                    if (i > 0) it.substring(0, i) to it.substring(i + 1) else null
                }?.toMap()
                val started = mgr.playMacro(
                    macro,
                    params,
                    intent.getFloatExtra("speed", 1f).toDouble(),
                    intent.getIntExtra("repeat", 1),
                    intent.getStringExtra("mode"),
                )
                Log.i(TAG, "PLAY started=$started name=$name")
            }
            "me.ihjas.missions.DEBUG_STATUS" ->
                Log.i(TAG, "STATUS recording=${mgr.isRecordingActive()} replaying=${mgr.isReplayingActive()}")
        }
    }

    companion object {
        private const val TAG = "DebugReplay"
    }
}
