package me.ihjas.missions.notifications

import android.app.Notification
import android.content.Context
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.os.Handler
import android.os.Looper
import me.ihjas.missions.DeviceMonitor
import me.ihjas.missions.WatchKeepAlive
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Android NotificationListenerService for Arcane.
 *
 * Captures incoming notifications from user-selected applications (e.g. messaging,
 * email, work apps) to build a daily notification history journal. This data is
 * stored locally and used by both Nora and external AI models to provide rich,
 * contextual daily briefings and reflection summaries.
 */
class ArcaneNotificationListenerService : NotificationListenerService() {

    companion object {
        const val PREFS_NAME = "arcane_notification_journal"
        const val KEY_SELECTED_PACKAGES = "selected_packages"
        const val KEY_NOTIFS_PREFIX = "notifs_"
        private const val MAX_PER_DAY = 300
        private val SUMMARY_REGEX = Regex("""(?i)^\d+\s+(?:new\s+)?messages?(\s+from\s+\d+\s+chats?)?$|^\d+\s+unread\s+messages?$|^\d+\s+messages?$|^\d+\s+new\s+messages?$""")

        var instance: ArcaneNotificationListenerService? = null
            private set

        fun getSelectedPackages(context: Context): Set<String> {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val saved = prefs.getStringSet(KEY_SELECTED_PACKAGES, null)
            if (saved != null) return saved
            // Default recommended journal communication apps
            return setOf(
                "com.whatsapp",
                "org.telegram.messenger",
                "com.google.android.gm",
                "com.google.android.apps.messaging",
                "com.slack",
                "com.discord",
                "com.microsoft.teams"
            )
        }

        fun setSelectedPackages(context: Context, packages: Set<String>) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putStringSet(KEY_SELECTED_PACKAGES, packages).apply()
        }

        fun getNotificationsForDate(context: Context, dateStr: String): List<Map<String, Any?>> {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val jsonStr = prefs.getString(KEY_NOTIFS_PREFIX + dateStr, "[]") ?: "[]"
            val result = mutableListOf<Map<String, Any?>>()
            try {
                val array = JSONArray(jsonStr)
                for (i in 0 until array.length()) {
                    val obj = array.getJSONObject(i)
                    val map = mutableMapOf<String, Any?>()
                    val keys = obj.keys()
                    while (keys.hasNext()) {
                        val key = keys.next()
                        map[key] = obj.opt(key)
                    }
                    result.add(map)
                }
            } catch (_: Exception) {}
            return result
        }

        fun clearNotificationsForDate(context: Context, dateStr: String) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().remove(KEY_NOTIFS_PREFIX + dateStr).apply()
        }

        fun deleteNotification(context: Context, dateStr: String, id: String) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val jsonStr = prefs.getString(KEY_NOTIFS_PREFIX + dateStr, "[]") ?: "[]"
            try {
                val array = JSONArray(jsonStr)
                val newArray = JSONArray()
                for (i in 0 until array.length()) {
                    val obj = array.getJSONObject(i)
                    if (obj.optString("id") != id) {
                        newArray.put(obj)
                    }
                }
                prefs.edit().putString(KEY_NOTIFS_PREFIX + dateStr, newArray.toString()).apply()
            } catch (_: Exception) {}
        }
    }

    private val beat = Handler(Looper.getMainLooper())
    private val beatRunnable = object : Runnable {
        override fun run() {
            try { WatchKeepAlive.heartbeat(this@ArcaneNotificationListenerService, force = false) } catch (_: Exception) {}
            beat.postDelayed(this, WatchKeepAlive.HEARTBEAT_MS)
        }
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        instance = this
        DeviceMonitor.start(applicationContext)
        beat.removeCallbacks(beatRunnable)
        beat.postDelayed(beatRunnable, WatchKeepAlive.HEARTBEAT_MS)
    }

    override fun onListenerDisconnected() {
        if (instance == this) instance = null
        beat.removeCallbacks(beatRunnable)
        super.onListenerDisconnected()
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        super.onNotificationRemoved(sbn)
        if (sbn != null) try { WatchKeepAlive.onRemoved(this, sbn) } catch (_: Exception) {}
    }

    override fun onDestroy() {
        if (instance == this) instance = null
        super.onDestroy()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return
        val pkg = sbn.packageName ?: return

        // Do not record Arcane's own notifications
        if (pkg == packageName) return

        // Watch companion app: remember it is alive and keep what it shows (steps, heart rate, …).
        try { WatchKeepAlive.onPosted(this, sbn) } catch (_: Exception) {}

        // Verify if package is selected for notification journal
        val monitored = getSelectedPackages(applicationContext)
        if (!monitored.contains(pkg)) return

        val notification = sbn.notification ?: return

        // Skip sticky / ongoing / foreground service events (music, active calls, vpn)
        val flags = notification.flags
        if ((flags and Notification.FLAG_ONGOING_EVENT) != 0) return
        if ((flags and Notification.FLAG_FOREGROUND_SERVICE) != 0) return

        val extras = notification.extras ?: return
        var title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim()
            ?: extras.getCharSequence(Notification.EXTRA_TITLE_BIG)?.toString()?.trim() ?: ""
        var text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()?.trim()
            ?: extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()?.trim() ?: ""
        val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString()?.trim() ?: ""

        val isGroupSummary = (flags and Notification.FLAG_GROUP_SUMMARY) != 0
        val isGenericSummary = SUMMARY_REGEX.matches(text) || SUMMARY_REGEX.matches(title)

        // If this is a group summary or generic summary ("X messages from Y chats"), extract actual content or drop
        if (isGroupSummary || isGenericSummary) {
            var extractedText: String? = null
            var extractedSender: String? = null

            // 1. Inspect Notification.EXTRA_MESSAGES (MessagingStyle)
            try {
                val messages = extras.getParcelableArray(Notification.EXTRA_MESSAGES)
                if (messages != null && messages.isNotEmpty()) {
                    for (i in messages.indices.reversed()) {
                        val bundle = messages[i] as? Bundle ?: continue
                        val mText = bundle.getCharSequence("text")?.toString()?.trim()
                        if (!mText.isNullOrEmpty() && !SUMMARY_REGEX.matches(mText)) {
                            extractedText = mText
                            extractedSender = bundle.getCharSequence("sender")?.toString()?.trim()
                            break
                        }
                    }
                }
            } catch (_: Exception) {}

            // 2. Inspect Notification.EXTRA_TEXT_LINES (InboxStyle)
            if (extractedText == null) {
                try {
                    val lines = extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
                    if (lines != null && lines.isNotEmpty()) {
                        for (i in lines.indices.reversed()) {
                            val lineStr = lines[i]?.toString()?.trim() ?: continue
                            if (lineStr.isNotEmpty() && !SUMMARY_REGEX.matches(lineStr)) {
                                if (lineStr.contains(": ")) {
                                    val parts = lineStr.split(": ", limit = 2)
                                    extractedSender = parts[0].trim()
                                    extractedText = parts[1].trim()
                                } else {
                                    extractedText = lineStr
                                }
                                break
                            }
                        }
                    }
                } catch (_: Exception) {}
            }

            if (!extractedText.isNullOrEmpty()) {
                text = extractedText
                if (!extractedSender.isNullOrEmpty()) {
                    title = extractedSender
                }
            } else if (isGroupSummary || isGenericSummary) {
                // Ignore pure overdraw placeholder notifications
                return
            }
        }

        // Skip empty notifications
        if (title.isEmpty() && text.isEmpty()) return

        val postTime = sbn.postTime
        val dateStr = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date(postTime))
        val timeStr = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date(postTime))

        val pm = packageManager
        val appName = try {
            pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
        } catch (_: Exception) {
            pkg
        }

        val id = "${pkg}_${sbn.id}_$postTime"

        val item = JSONObject().apply {
            put("id", id)
            put("packageName", pkg)
            put("appName", appName)
            put("title", title)
            put("text", text)
            put("subText", subText)
            put("timestamp", postTime)
            put("timeStr", timeStr)
            put("dateStr", dateStr)
        }

        saveNotification(dateStr, item)
        NotificationBridge.notifyReceived(item)
    }

    private fun saveNotification(dateStr: String, item: JSONObject) {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val jsonStr = prefs.getString(KEY_NOTIFS_PREFIX + dateStr, "[]") ?: "[]"
        try {
            val array = JSONArray(jsonStr)
            // Deduplicate: check last notification
            if (array.length() > 0) {
                val last = array.getJSONObject(array.length() - 1)
                if (last.optString("packageName") == item.optString("packageName") &&
                    last.optString("title") == item.optString("title") &&
                    last.optString("text") == item.optString("text")
                ) {
                    return // Duplicate update from same app
                }
            }
            array.put(item)
            val trimmedArray = if (array.length() > MAX_PER_DAY) {
                val trimmed = JSONArray()
                val start = array.length() - MAX_PER_DAY
                for (i in start until array.length()) {
                    trimmed.put(array.get(i))
                }
                trimmed
            } else {
                array
            }
            prefs.edit().putString(KEY_NOTIFS_PREFIX + dateStr, trimmedArray.toString()).apply()
        } catch (_: Exception) {}
    }
}
