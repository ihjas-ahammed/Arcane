package me.ihjas.missions.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
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
            render(context, appWidgetManager, id, widgetData)
        }
    }

    private fun render(context: Context, mgr: AppWidgetManager, widgetId: Int, prefs: SharedPreferences) {
        val views = RemoteViews(context.packageName, R.layout.widget_running_task)

        // Load background image
        val imagePath = prefs.getString("arcane.task.image", null)
        if (imagePath != null) {
            val bitmap = BitmapFactory.decodeFile(imagePath)
            if (bitmap != null) {
                views.setImageViewBitmap(R.id.widget_image, bitmap)
                views.setViewVisibility(R.id.widget_image, android.view.View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.widget_image, android.view.View.GONE)
            }
        } else {
            views.setViewVisibility(R.id.widget_image, android.view.View.GONE)
        }

        val hasTask = WidgetCommon.getSafeBoolean(prefs, "arcane.task.hasTask", false)
        val isRunning = WidgetCommon.getSafeBoolean(prefs, "arcane.task.isRunning", false)
        val accumulatedSec = WidgetCommon.getSafeLong(prefs, "arcane.task.accumulatedSec", 0L)
        val sessionStartMs = WidgetCommon.getSafeLong(prefs, "arcane.task.sessionStartMs", 0L)

        val title = prefs.getString("arcane.task.title", "") ?: ""
        val subtitle = prefs.getString("arcane.task.subtitle", "") ?: ""
        val isCheckpoint = WidgetCommon.getSafeBoolean(prefs, "arcane.task.isCheckpoint", false)

        val statusLabel = if (!hasTask) {
            "QUEUE EMPTY"
        } else if (isCheckpoint) {
            if (isRunning) "CHECKPOINT · ENGAGED" else "CHECKPOINT · STANDBY"
        } else {
            if (isRunning) "ACTIVE · ENGAGED" else "ACTIVE · STANDBY"
        }

        views.setTextViewText(R.id.widget_status_label, statusLabel)

        if (hasTask) {
            views.setTextViewText(R.id.widget_task_title, title.uppercase())
            views.setTextViewText(R.id.widget_task_subtitle, subtitle.uppercase())
        } else {
            views.setTextViewText(R.id.widget_task_title, "NO PLAN SET")
            views.setTextViewText(R.id.widget_task_subtitle, "QUEUE STANDBY")
        }

        // Time display: when running, use Chronometer. Otherwise show static accumulated total.
        if (isRunning && sessionStartMs > 0L) {
            views.setViewVisibility(R.id.widget_task_today, android.view.View.GONE)
            views.setViewVisibility(R.id.widget_task_chronometer, android.view.View.VISIBLE)
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
            views.setOnClickPendingIntent(
                R.id.widget_btn_engage,
                WidgetCommon.launchIntent(context, "task_toggle"),
            )
            views.setOnClickPendingIntent(
                R.id.widget_btn_finish,
                WidgetCommon.launchIntent(context, "task_finish"),
            )
        } else {
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
