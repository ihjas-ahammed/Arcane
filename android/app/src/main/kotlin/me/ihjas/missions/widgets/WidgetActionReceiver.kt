package me.ihjas.missions.widgets

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import me.ihjas.missions.MainActivity
import me.ihjas.missions.R

/**
 * Receives taps from the active-mission widget's quick-action buttons
 * (ENGAGE / CHECK / FINISH).
 *
 * If the app is already alive, the action is applied silently in the running
 * Flutter isolate — the app is NOT brought to the foreground. Only when the
 * process is dead do we launch the app (via the same deep link the plugin
 * observes) so the action still applies. Buttons that need UI (OPEN PLAN,
 * title tap) keep using a normal launch intent instead of this receiver.
 */
class WidgetActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.data?.getQueryParameter("action") ?: return

        // Update the widget UI instantly to provide visual feedback.
        applyInstantFeedback(context, action)

        if (MainActivity.dispatchWidgetAction(action)) return

        // App not running — open it with the launch deep link so the existing
        // cold-start handler applies the action.
        val launch = Intent(context, MainActivity::class.java).apply {
            data = intent.data
            this.action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        context.startActivity(launch)
    }

    private fun applyInstantFeedback(context: Context, action: String) {
        try {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val runningIds = appWidgetManager.getAppWidgetIds(
                android.content.ComponentName(context, RunningTaskWidget::class.java)
            )
            if (runningIds.isEmpty()) return

            val views = RemoteViews(context.packageName, R.layout.widget_running_task)

            when {
                action == "task_toggle" -> {
                    val prefs = context.getSharedPreferences("HomeWidgetPrefs", Context.MODE_PRIVATE)
                    val isRunning = WidgetCommon.getSafeBoolean(prefs, "arcane.task.isRunning", false)
                    if (isRunning) {
                        views.setTextViewText(R.id.widget_btn_engage, "HALTING...")
                    } else {
                        views.setTextViewText(R.id.widget_btn_engage, "ENGAGING...")
                    }
                }
                action == "task_check_next" -> {
                    views.setTextViewText(R.id.widget_btn_check, "CHECKING...")
                }
                action == "task_finish" -> {
                    views.setTextViewText(R.id.widget_btn_finish, "FINISHING...")
                }
                action.startsWith("task_check_") -> {
                    val idx = action.split("_").last().toIntOrNull() ?: return
                    val checkIds = intArrayOf(
                        R.id.widget_dayplan_btn_check_0, R.id.widget_dayplan_btn_check_1, R.id.widget_dayplan_btn_check_2,
                        R.id.widget_dayplan_btn_check_3, R.id.widget_dayplan_btn_check_4
                    )
                    val titleIds = intArrayOf(
                        R.id.widget_dayplan_row_title_0, R.id.widget_dayplan_row_title_1, R.id.widget_dayplan_row_title_2,
                        R.id.widget_dayplan_row_title_3, R.id.widget_dayplan_row_title_4
                    )
                    if (idx in 0..4) {
                        views.setTextViewText(checkIds[idx], "✓")
                        views.setTextColor(checkIds[idx], ContextCompat.getColor(context, R.color.widget_text_muted))
                        views.setTextColor(titleIds[idx], ContextCompat.getColor(context, R.color.widget_text_muted))
                    }
                }
                else -> return
            }

            for (id in runningIds) {
                appWidgetManager.partiallyUpdateAppWidget(id, views)
            }
        } catch (_: Exception) {
            // Safe fallback if update fails
        }
    }
}
