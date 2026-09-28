package me.ihjas.missions

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import es.antonborri.home_widget.HomeWidgetLaunchIntent

/**
 * Keeps Arcane alive in the background while a task/reading session is running,
 * preventing Android or OEM battery killers (MIUI/HyperOS) from killing the process.
 */
class TaskForegroundService : Service() {

    companion object {
        private const val CHANNEL_ID = "arcane_task_foreground"
        private const val NOTIF_ID = 4001
        private const val EXTRA_TITLE = "task_title"
        private const val EXTRA_SUBTITLE = "task_subtitle"

        fun start(context: Context, title: String? = null, subtitle: String? = null) {
            val intent = Intent(context, TaskForegroundService::class.java).apply {
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_SUBTITLE, subtitle)
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (_: Exception) {
            }
        }

        fun stop(context: Context) {
            try {
                context.stopService(Intent(context, TaskForegroundService::class.java))
            } catch (_: Exception) {
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createChannel()
        val title = intent?.getStringExtra(EXTRA_TITLE)?.takeIf { it.isNotEmpty() } ?: "Arcane Task Running"
        val subtitle = intent?.getStringExtra(EXTRA_SUBTITLE)?.takeIf { it.isNotEmpty() } ?: "Active session in progress"

        val openIntent = Intent(this, MainActivity::class.java).apply {
            action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
            this.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingOpen = PendingIntent.getActivity(
            this,
            0,
            openIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(subtitle)
            .setOngoing(true)
            .setAutoCancel(false)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(pendingOpen)
            .setColor(0xFF00F0FF.toInt())
            .build()

        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIF_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIF_ID, notification)
        }

        return START_STICKY
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Arcane Active Task",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps Arcane active in background while a task or reading timer is running"
                setShowBadge(false)
            }
            nm.createNotificationChannel(channel)
        }
    }
}
