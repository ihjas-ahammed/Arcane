package me.ihjas.missions.notifications

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.RemoteInput
import me.ihjas.missions.MainActivity
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

        // Persist before dispatch so both paths acknowledge the same durable record.
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val id = java.util.UUID.randomUUID().toString()
        val saved = try {
            val log = JSONObject().apply {
                put("id", id)
                put("reply", replyText)
                put("userId", prefs.getString("flutter.active_energy_user", null))
                put("timestamp", System.currentTimeMillis())
            }
            prefs.edit().putString("flutter.pending_energy_log_$id", log.toString()).commit()
        } catch (_: Exception) { false }
        val dispatched = MainActivity.dispatchEnergyReply(replyText, notificationId, if (saved) id else null)

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
