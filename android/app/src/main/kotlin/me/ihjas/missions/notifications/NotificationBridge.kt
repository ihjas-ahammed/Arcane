package me.ihjas.missions.notifications

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/**
 * MethodChannel bridge for the Notification Journal system (`arcane/notifications`).
 *
 * Handles permission status checks, opening notification listener settings,
 * querying/saving monitored apps, and reading/clearing notification logs per date.
 */
class NotificationBridge(private val activity: Activity, messenger: BinaryMessenger) {

    companion object {
        const val CHANNEL = "arcane/notifications"
        private val activeChannels = mutableListOf<MethodChannel>()
        private val mainHandler = Handler(Looper.getMainLooper())

        fun notifyReceived(item: JSONObject) {
            val map = mutableMapOf<String, Any?>()
            val keys = item.keys()
            while (keys.hasNext()) {
                val k = keys.next()
                map[k] = item.opt(k)
            }
            mainHandler.post {
                for (ch in activeChannels) {
                    try {
                        ch.invokeMethod("onNotificationReceived", map)
                    } catch (_: Exception) {}
                }
            }
        }
    }

    private val channel = MethodChannel(messenger, CHANNEL)

    init {
        activeChannels.add(channel)
        channel.setMethodCallHandler { call, result ->
            val context = activity.applicationContext
            when (call.method) {
                "isPermissionGranted" -> {
                    result.success(isNotificationListenerGranted(context))
                }
                "openPermissionSettings" -> {
                    result.success(openNotificationListenerSettings(activity))
                }
                "getSelectedApps" -> {
                    val apps = ArcaneNotificationListenerService.getSelectedPackages(context).toList()
                    result.success(apps)
                }
                "setSelectedApps" -> {
                    val apps = call.argument<List<String>>("packages") ?: emptyList()
                    ArcaneNotificationListenerService.setSelectedPackages(context, apps.toSet())
                    result.success(true)
                }
                "getNotifications" -> {
                    val dateStr = call.argument<String>("date") ?: ""
                    val notifs = ArcaneNotificationListenerService.getNotificationsForDate(context, dateStr)
                    result.success(notifs)
                }
                "deleteNotification" -> {
                    val dateStr = call.argument<String>("date") ?: ""
                    val id = call.argument<String>("id") ?: ""
                    ArcaneNotificationListenerService.deleteNotification(context, dateStr, id)
                    result.success(true)
                }
                "clearNotifications" -> {
                    val dateStr = call.argument<String>("date") ?: ""
                    ArcaneNotificationListenerService.clearNotificationsForDate(context, dateStr)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    fun dispose() {
        activeChannels.remove(channel)
        channel.setMethodCallHandler(null)
    }

    private fun isNotificationListenerGranted(context: Context): Boolean {
        return try {
            val packages = NotificationManagerCompat.getEnabledListenerPackages(context)
            packages.contains(context.packageName)
        } catch (_: Exception) {
            val flat = Settings.Secure.getString(context.contentResolver, "enabled_notification_listeners") ?: ""
            flat.contains(context.packageName)
        }
    }

    private fun openNotificationListenerSettings(activity: Activity): Boolean {
        return try {
            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
            } else {
                Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS")
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            activity.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }
}
