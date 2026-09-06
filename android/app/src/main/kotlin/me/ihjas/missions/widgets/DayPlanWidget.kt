package me.ihjas.missions.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import me.ihjas.missions.R

class DayPlanWidget : HomeWidgetProvider() {

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
        val views = RemoteViews(context.packageName, R.layout.widget_dayplan)
        views.setImageViewResource(R.id.widget_bg_art, R.drawable.widget_bg_art_cyan)

        val capacity = prefs.getString("arcane.task.capacity", "") ?: ""
        views.setTextViewText(R.id.widget_dayplan_capacity, if (capacity.isNotEmpty()) "CAP $capacity" else "")

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
        val openPlanIntent = WidgetCommon.launchIntent(context, "task_open_plan")
        val openTaskIntent = WidgetCommon.launchIntent(context, "task_open")

        var visibleCount = 0
        for (i in 0 until 5) {
            val title = prefs.getString("arcane.task.dp$i.title", "") ?: ""
            if (title.isBlank()) {
                views.setViewVisibility(rowContainers[i], View.GONE)
            } else {
                views.setViewVisibility(rowContainers[i], View.VISIBLE)
                views.setTextViewText(titleIds[i], title.uppercase())
                views.setOnClickPendingIntent(titleIds[i], openPlanIntent)
                views.setOnClickPendingIntent(checkIds[i], WidgetCommon.actionIntent(context, checkActions[i], 110 + i))
                visibleCount++
            }
        }

        if (visibleCount == 0) {
            views.setViewVisibility(R.id.widget_dayplan_empty, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.widget_dayplan_empty, View.GONE)
        }

        views.setOnClickPendingIntent(R.id.widget_dayplan_btn_open, openPlanIntent)
        views.setOnClickPendingIntent(R.id.widget_dayplan_btn_task, openTaskIntent)
        views.setOnClickPendingIntent(R.id.widget_dayplan_status_badge, openPlanIntent)

        mgr.updateAppWidget(widgetId, views)
    }
}
