package me.ihjas.missions.notifications

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.RemoteInput
import me.ihjas.missions.MainActivity
import org.json.JSONArray
import org.json.JSONObject

/**
 * Android 14 system BroadcastReceiver for direct replies from notifications
 * or wearable auto-replies.
 */
class EnergyReplyReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val remoteInputBundle = RemoteInput.getResultsFromIntent(intent)
        val replyText = remoteInputBundle?.getCharSequence(EnergyNotificationHelper.KEY_TEXT_REPLY)?.toString()
            ?: intent.getStringExtra("reply")
            ?: return

        val notificationId = intent.getIntExtra(EnergyNotificationHelper.EXTRA_NOTIFICATION_ID, 5000)

        // 1. Android 14 instant visual feedback: immediately update notification to acknowledge
        EnergyNotificationHelper.postReplyConfirmationNotification(context, notificationId, replyText)

        // 2. Dispatch to running Flutter isolate if MainActivity is alive
        val dispatched = MainActivity.dispatchEnergyReply(replyText, notificationId)

        // 3. Persist pending log to SharedPreferences so Flutter drains it on resume/launch
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val existingLogsJson = prefs.getString("flutter.pending_energy_logs", "[]") ?: "[]"
        try {
            val array = JSONArray(existingLogsJson)
            val logObj = JSONObject().apply {
                put("reply", replyText)
                put("timestamp", System.currentTimeMillis())
                put("notificationId", notificationId)
            }
            array.put(logObj)
            prefs.edit().putString("flutter.pending_energy_logs", array.toString()).apply()
        } catch (_: Exception) {}

        // 4. Fallback: If app was terminated, post immediate tactical AI advice
        if (!dispatched) {
            val lower = replyText.lowercase().trim()
            val advice = when {
                lower == "yes" || lower.contains("tired") || lower.contains("exhausted") || lower.contains("low") || lower.contains("sleepy") ->
                    "Tactical Alert: Low energy registered ($replyText). Hydrate with 250ml water, stretch, and take a 3-minute visual reset."
                lower == "no" || lower.contains("energetic") || lower.contains("good") || lower.contains("great") || lower.contains("fine") ->
                    "Tactical Status: High energy confirmed ($replyText). Direct maximum focus into your primary mission objective."
                else ->
                    "Energy status \"$replyText\" logged. Calibrating tactical pace and cognitive load."
            }
            EnergyNotificationHelper.postAiResponseNotification(
                context,
                5100,
                "◢ ARCANE // ENERGY ADVISOR",
                advice
            )
        }
    }
}
