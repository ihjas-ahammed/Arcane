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
            if (runningIds.isNotEmpty()) {
                val views = RemoteViews(context.packageName, R.layout.widget_running_task)
                when (action) {
                    "task_toggle" -> {
                        val prefs = context.getSharedPreferences("HomeWidgetPrefs", Context.MODE_PRIVATE)
                        val isRunning = WidgetCommon.getSafeBoolean(prefs, "arcane.task.isRunning", false)
                        views.setTextViewText(R.id.widget_btn_engage, if (isRunning) "HALTING..." else "ENGAGING...")
                    }
                    "task_check_next" -> views.setTextViewText(R.id.widget_btn_check, "CHECKING...")
                    "task_finish" -> views.setTextViewText(R.id.widget_btn_finish, "FINISHING...")
                }
                for (id in runningIds) {
                    appWidgetManager.partiallyUpdateAppWidget(id, views)
                }
            }

            if (action.startsWith("task_check_") || action == "task_check_0") {
                val dayPlanIds = appWidgetManager.getAppWidgetIds(
                    android.content.ComponentName(context, DayPlanWidget::class.java)
                )
                if (dayPlanIds.isNotEmpty()) {
                    val viewsDp = RemoteViews(context.packageName, R.layout.widget_dayplan)
                    viewsDp.setTextViewText(R.id.widget_dayplan_btn_check, "CHECKING...")
                    for (id in dayPlanIds) {
                        appWidgetManager.partiallyUpdateAppWidget(id, viewsDp)
                    }
                }
            }

            if (action.startsWith("goal_toggle_")) {
                val goalIds = appWidgetManager.getAppWidgetIds(
                    android.content.ComponentName(context, GoalsWidget::class.java)
                )
                if (goalIds.isNotEmpty()) {
                    val slot = action.removePrefix("goal_toggle_").toIntOrNull() ?: 0
                    val viewsGoals = RemoteViews(context.packageName, R.layout.widget_goals)
                    val checkId = when (slot) {
                        0 -> R.id.widget_goal_0_check
                        1 -> R.id.widget_goal_1_check
                        else -> R.id.widget_goal_2_check
                    }
                    viewsGoals.setTextViewText(checkId, "…")
                    for (id in goalIds) {
                        appWidgetManager.partiallyUpdateAppWidget(id, viewsGoals)
                    }
                }
            }
        } catch (_: Exception) {
            // Safe fallback if update fails
        }
    }
}
