package me.ihjas.missions.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.os.SystemClock
import android.widget.RemoteViews
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
            render(context, appWidgetManager, id)
        }
    }

    private fun render(context: Context, mgr: AppWidgetManager, widgetId: Int) {
        val prefs = WidgetCommon.prefs(context)
        val views = RemoteViews(context.packageName, R.layout.widget_running_task)

        val hasTask = prefs.getBoolean("arcane.task.hasTask", false)
        val title = prefs.getString("arcane.task.title", "NO PLAN SET") ?: "NO PLAN SET"
        val subtitle = prefs.getString("arcane.task.subtitle", "QUEUE STANDBY") ?: "QUEUE STANDBY"
        val isRunning = prefs.getBoolean("arcane.task.isRunning", false)
        val isCheckpoint = prefs.getBoolean("arcane.task.isCheckpoint", false)
        val accumulatedSec = prefs.getLong("arcane.task.accumulatedSec", 0L)
        val sessionStartMs = prefs.getLong("arcane.task.sessionStartMs", 0L)
        val updatedAtMs = prefs.getLong("arcane.task.updatedAtMs", 0L)

        views.setTextViewText(R.id.widget_task_title, title.uppercase())
        views.setTextViewText(R.id.widget_task_subtitle, subtitle.uppercase())

        val statusLabel = when {
            !hasTask -> "QUEUE EMPTY"
            isCheckpoint && isRunning -> "CHECKPOINT · ENGAGED"
            isCheckpoint -> "CHECKPOINT · STANDBY"
            isRunning -> "ACTIVE · ENGAGED"
            else -> "ACTIVE · STANDBY"
        }
        views.setTextViewText(R.id.widget_status_label, statusLabel)

        if (updatedAtMs > 0) {
            val ageSec = (System.currentTimeMillis() - updatedAtMs) / 1000
            views.setTextViewText(
                R.id.widget_status_clock,
                if (ageSec < 60) "LIVE" else "${ageSec / 60}m AGO",
            )
        } else {
            views.setTextViewText(R.id.widget_status_clock, "")
        }

        // Time display: when running, use Chronometer (ticks natively in the
        // RemoteViews context). Otherwise show static accumulated total.
        if (isRunning && sessionStartMs > 0L) {
            views.setViewVisibility(R.id.widget_task_today, android.view.View.GONE)
            views.setViewVisibility(R.id.widget_task_chronometer, android.view.View.VISIBLE)
            // Chronometer base is on the elapsedRealtime clock. Convert wall
            // session start to that timeline; account for time already on the
            // pre-session accumulated total.
            val elapsedSinceSession = System.currentTimeMillis() - sessionStartMs
            val base = SystemClock.elapsedRealtime() - elapsedSinceSession - (accumulatedSec * 1000L)
            views.setChronometer(R.id.widget_task_chronometer, base, null, true)
        } else {
            views.setViewVisibility(R.id.widget_task_chronometer, android.view.View.GONE)
            views.setViewVisibility(R.id.widget_task_today, android.view.View.VISIBLE)
            views.setTextViewText(R.id.widget_task_today, WidgetCommon.fmtSeconds(accumulatedSec))
        }

        // Buttons
        if (hasTask) {
            views.setTextViewText(R.id.widget_btn_engage, if (isRunning) "HALT SESSION" else "ENGAGE")
            views.setInt(
                R.id.widget_btn_engage,
                "setBackgroundResource",
                if (isRunning) R.drawable.widget_btn_primary_red else R.drawable.widget_btn_primary_amber,
            )
            views.setTextViewText(R.id.widget_btn_finish, "FINISH")
            views.setOnClickPendingIntent(
                R.id.widget_btn_engage,
                WidgetCommon.launchIntent(context, "task_toggle"),
            )
            views.setOnClickPendingIntent(
                R.id.widget_btn_finish,
                WidgetCommon.launchIntent(context, "task_finish"),
            )
        } else {
            views.setTextViewText(R.id.widget_btn_engage, "OPEN PLAN")
            views.setInt(
                R.id.widget_btn_engage,
                "setBackgroundResource",
                R.drawable.widget_btn_primary_amber,
            )
            views.setTextViewText(R.id.widget_btn_finish, "REFRESH")
            views.setOnClickPendingIntent(
                R.id.widget_btn_engage,
                WidgetCommon.launchIntent(context, "task_open_plan"),
            )
            views.setOnClickPendingIntent(
                R.id.widget_btn_finish,
                WidgetCommon.launchIntent(context, "task_open"),
            )
        }

        views.setOnClickPendingIntent(
            R.id.widget_task_title,
            WidgetCommon.launchIntent(context, "task_open"),
        )

        mgr.updateAppWidget(widgetId, views)
    }
}
