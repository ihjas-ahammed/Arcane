package me.ihjas.missions.notifications

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.RemoteInput
import me.ihjas.missions.R

/**
 * Android 14 (API 34) system-level notification helper for Energy Checks.
 * Configures RemoteInput direct reply, predefined wearable quick-reply choices,
 * NotificationCompat.WearableExtender, and Android 14 PendingIntent mutability flags.
 */
object EnergyNotificationHelper {
    const val CHANNEL_ID = "reminders"
    const val CHANNEL_NAME = "Reminders"
    const val KEY_TEXT_REPLY = "key_energy_reply"
    const val ACTION_ENERGY_REPLY = "me.ihjas.missions.ENERGY_REPLY"
    const val EXTRA_NOTIFICATION_ID = "extra_notification_id"

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            if (manager != null && manager.getNotificationChannel(CHANNEL_ID) == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Submission, reflection, and energy reminders"
                    enableLights(true)
                    lightColor = Color.parseColor("#FFB547") // Tactical Amber
                    enableVibration(true)
                }
                manager.createNotificationChannel(channel)
            }
        }
    }

    /**
     * Builds an Android 14 system-compliant Energy Check notification with RemoteInput.
     */
    fun buildEnergyCheckNotification(
        context: Context,
        notificationId: Int,
        title: String,
        body: String
    ): Notification {
        ensureChannel(context)

        // 1. Define RemoteInput with predefined choices ("yes", "no") for Wear OS auto-reply
        val remoteInput = RemoteInput.Builder(KEY_TEXT_REPLY)
            .setLabel("Reply (yes / no)...")
            .setChoices(arrayOf("yes", "no"))
            .setAllowFreeFormInput(true)
            .build()

        // 2. PendingIntent targeting EnergyReplyReceiver with Android 14 FLAG_MUTABLE
        val replyIntent = Intent(context, EnergyReplyReceiver::class.java).apply {
            action = ACTION_ENERGY_REPLY
            putExtra(EXTRA_NOTIFICATION_ID, notificationId)
        }

        val replyPendingIntent = PendingIntent.getBroadcast(
            context,
            notificationId,
            replyIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )

        // 3. NotificationCompat.Action with SEMANTIC_ACTION_REPLY & smart replies
        val replyAction = NotificationCompat.Action.Builder(
            R.mipmap.ic_launcher,
            "Reply",
            replyPendingIntent
        )
            .addRemoteInput(remoteInput)
            .setSemanticAction(NotificationCompat.Action.SEMANTIC_ACTION_REPLY)
            .setAllowGeneratedReplies(true)
            .setShowsUserInterface(false)
            .build()

        // 4. WearableExtender ensuring direct auto-reply on Wear OS smartwatches
        val wearableExtender = NotificationCompat.WearableExtender()
            .addAction(replyAction)

        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setColor(Color.parseColor("#FFB547"))
            .setAutoCancel(false)
            .addAction(replyAction)
            .extend(wearableExtender)
            .build()
    }

    /**
     * Android 14 requirement: Immediately update notification upon inline reply
     * to acknowledge input receipt and dismiss system/wearable loading spinners.
     */
    fun postReplyConfirmationNotification(
        context: Context,
        notificationId: Int,
        userReply: String
    ) {
        ensureChannel(context)
        val ackNotification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("ENERGY CHECK // LOGGED")
            .setContentText("Recorded: \"$userReply\" • AI analyzing...")
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setColor(Color.parseColor("#FFB547"))
            .setAutoCancel(true)
            .setTimeoutAfter(8000)
            .build()

        try {
            NotificationManagerCompat.from(context).notify(notificationId, ackNotification)
        } catch (_: SecurityException) {
        }
    }

    /**
     * Posts the AI response notification after processing the user's reply.
     */
    fun postAiResponseNotification(
        context: Context,
        notificationId: Int,
        title: String,
        aiResponse: String
    ) {
        ensureChannel(context)
        val responseNotification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(aiResponse)
            .setStyle(NotificationCompat.BigTextStyle().bigText(aiResponse))
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setColor(Color.parseColor("#FFB547"))
            .setAutoCancel(true)
            .build()

        try {
            NotificationManagerCompat.from(context).notify(notificationId, responseNotification)
        } catch (_: SecurityException) {
        }
    }
}
