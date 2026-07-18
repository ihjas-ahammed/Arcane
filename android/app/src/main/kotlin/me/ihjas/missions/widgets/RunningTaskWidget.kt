package me.ihjas.missions.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import es.antonborri.home_widget.HomeWidgetProvider
import me.ihjas.missions.R

class RunningTaskWidget : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            render(context, appWidgetManager, id, widgetData)
        }
    }

    private fun render(context: Context, mgr: AppWidgetManager, widgetId: Int, prefs: SharedPreferences) {
        val views = RemoteViews(context.packageName, R.layout.widget_running_task)

        val options = mgr.getAppWidgetOptions(widgetId)
        val minHeight = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT) ?: 0
        val dayPlannerWidgetCheckable = WidgetCommon.getSafeBoolean(prefs, "arcane.task.dayPlannerWidgetCheckable", false)

        if (minHeight >= 220) {
            // Expanded: Show both stacked vertically
            views.setViewVisibility(R.id.widget_running_layout, View.VISIBLE)
            views.setViewVisibility(R.id.widget_dayplan_layout, View.VISIBLE)
            renderRunning(context, views, prefs)
            renderDayPlan(context, views, prefs)
        } else {
            // Standard: Show either one depending on preferences
            if (dayPlannerWidgetCheckable) {
                views.setViewVisibility(R.id.widget_running_layout, View.GONE)
                views.setViewVisibility(R.id.widget_dayplan_layout, View.VISIBLE)
                renderDayPlan(context, views, prefs)
            } else {
                views.setViewVisibility(R.id.widget_running_layout, View.VISIBLE)
                views.setViewVisibility(R.id.widget_dayplan_layout, View.GONE)
                renderRunning(context, views, prefs)
            }
        }

        mgr.updateAppWidget(widgetId, views)
    }

    private fun renderRunning(context: Context, views: RemoteViews, prefs: SharedPreferences) {
        val hasTask = WidgetCommon.getSafeBoolean(prefs, "arcane.task.hasTask", false)
        val isRunning = WidgetCommon.getSafeBoolean(prefs, "arcane.task.isRunning", false)
        val accumulatedSec = WidgetCommon.getSafeLong(prefs, "arcane.task.accumulatedSec", 0L)
        val sessionStartMs = WidgetCommon.getSafeLong(prefs, "arcane.task.sessionStartMs", 0L)
        val progressPct = WidgetCommon.getSafeInt(prefs, "arcane.task.progressPct", 0)

        val title = prefs.getString("arcane.task.title", "") ?: ""
        val subtitle = prefs.getString("arcane.task.subtitle", "") ?: ""
        val capacity = prefs.getString("arcane.task.capacity", "") ?: ""
        val isCheckpoint = WidgetCommon.getSafeBoolean(prefs, "arcane.task.isCheckpoint", false)

        val statusLabel = when {
            !hasTask -> "[ STANDBY ]"
            isCheckpoint && isRunning -> "[ CHECKPOINT // ENGAGED ]"
            isCheckpoint -> "[ CHECKPOINT // STANDBY ]"
            isRunning -> "[ MISSION // ENGAGED ]"
            else -> "[ MISSION // STANDBY ]"
        }
        views.setTextViewText(R.id.widget_status_label, statusLabel)
        views.setTextViewText(R.id.widget_capacity, capacity)

        if (hasTask) {
            views.setTextViewText(R.id.widget_task_title, title.uppercase())
            views.setTextViewText(R.id.widget_task_subtitle, subtitle.uppercase())
        } else {
            views.setTextViewText(R.id.widget_task_title, "NO PLAN SET")
            views.setTextViewText(R.id.widget_task_subtitle, "QUEUE STANDBY")
        }

        // Time: live chronometer while running, static accumulated total otherwise.
        if (isRunning && sessionStartMs > 0L) {
            views.setViewVisibility(R.id.widget_task_today, View.GONE)
            views.setViewVisibility(R.id.widget_task_chronometer, View.VISIBLE)
            val elapsedSinceSession = System.currentTimeMillis() - sessionStartMs
            val base = SystemClock.elapsedRealtime() - elapsedSinceSession - (accumulatedSec * 1000L)
            views.setChronometer(R.id.widget_task_chronometer, base, null, true)
        } else {
            views.setViewVisibility(R.id.widget_task_chronometer, View.GONE)
            views.setViewVisibility(R.id.widget_task_today, View.VISIBLE)
            views.setTextViewText(R.id.widget_task_today, WidgetCommon.fmtSeconds(accumulatedSec))
        }

        // Progress bar reflects the subtask's completion; hidden with no task.
        views.setViewVisibility(R.id.widget_task_progress, if (hasTask) View.VISIBLE else View.INVISIBLE)
        views.setProgressBar(R.id.widget_task_progress, 100, progressPct.coerceIn(0, 100), false)

        if (hasTask) {
            views.setViewVisibility(R.id.widget_btn_check, View.VISIBLE)
            views.setViewVisibility(R.id.widget_btn_finish, View.VISIBLE)

            // ENGAGE toggles to HALT (red) while running.
            if (isRunning) {
                views.setTextViewText(R.id.widget_btn_engage, "HALT")
                views.setInt(R.id.widget_btn_engage, "setBackgroundResource", R.drawable.widget_btn_primary_red)
                views.setTextColor(R.id.widget_btn_engage, ContextCompat.getColor(context, R.color.widget_text_white))
            } else {
                views.setTextViewText(R.id.widget_btn_engage, "ENGAGE")
                views.setInt(R.id.widget_btn_engage, "setBackgroundResource", R.drawable.widget_btn_primary_amber)
                views.setTextColor(R.id.widget_btn_engage, ContextCompat.getColor(context, R.color.widget_bg_deep))
            }
            views.setTextViewText(R.id.widget_btn_check, "CHECK")
            views.setTextViewText(R.id.widget_btn_finish, "FINISH")

            views.setOnClickPendingIntent(R.id.widget_btn_engage, WidgetCommon.actionIntent(context, "task_toggle", 101))
            views.setOnClickPendingIntent(R.id.widget_btn_check, WidgetCommon.actionIntent(context, "task_check_next", 102))
            views.setOnClickPendingIntent(R.id.widget_btn_finish, WidgetCommon.actionIntent(context, "task_finish", 103))
        } else {
            // No task: ENGAGE becomes OPEN PLAN, hide CHECK, FINISH becomes REFRESH.
            views.setViewVisibility(R.id.widget_btn_check, View.GONE)
            views.setViewVisibility(R.id.widget_btn_finish, View.VISIBLE)
            views.setTextViewText(R.id.widget_btn_engage, "OPEN PLAN")
            views.setInt(R.id.widget_btn_engage, "setBackgroundResource", R.drawable.widget_btn_primary_amber)
            views.setTextColor(R.id.widget_btn_engage, ContextCompat.getColor(context, R.color.widget_bg_deep))
            views.setTextViewText(R.id.widget_btn_finish, "OPEN")

            views.setOnClickPendingIntent(R.id.widget_btn_engage, WidgetCommon.launchIntent(context, "task_open_plan"))
            views.setOnClickPendingIntent(R.id.widget_btn_finish, WidgetCommon.launchIntent(context, "task_open"))
        }

        views.setOnClickPendingIntent(R.id.widget_task_title, WidgetCommon.launchIntent(context, "task_open"))
    }

    private fun renderDayPlan(context: Context, views: RemoteViews, prefs: SharedPreferences) {
        val rowContainers = intArrayOf(
            R.id.widget_dayplan_row_0, R.id.widget_dayplan_row_1, R.id.widget_dayplan_row_2,
            R.id.widget_dayplan_row_3, R.id.widget_dayplan_row_4,
        )
        val titleIds = intArrayOf(
            R.id.widget_dayplan_row_title_0, R.id.widget_dayplan_row_title_1, R.id.widget_dayplan_row_title_2,
            R.id.widget_dayplan_row_title_3, R.id.widget_dayplan_row_title_4,
        )
        val checkIds = intArrayOf(
            R.id.widget_dayplan_btn_check_0, R.id.widget_dayplan_btn_check_1, R.id.widget_dayplan_btn_check_2,
            R.id.widget_dayplan_btn_check_3, R.id.widget_dayplan_btn_check_4,
        )
        val checkActions = arrayOf("task_check_0", "task_check_1", "task_check_2", "task_check_3", "task_check_4")
        val openPlanIntent = WidgetCommon.launchIntent(context, "task_open")

        for (i in 0 until 5) {
            val title = prefs.getString("arcane.task.dp$i.title", "") ?: ""
            if (title.isBlank()) {
                views.setViewVisibility(rowContainers[i], View.GONE)
                continue
            }
            views.setViewVisibility(rowContainers[i], View.VISIBLE)
            views.setTextViewText(titleIds[i], title.uppercase())
            views.setOnClickPendingIntent(titleIds[i], openPlanIntent)
            views.setOnClickPendingIntent(checkIds[i], WidgetCommon.actionIntent(context, checkActions[i], 110 + i))
        }
    }
}
