package me.ihjas.missions.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.util.Log
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
            try {
                render(context, appWidgetManager, id, widgetData)
            } catch (e: Throwable) {
                Log.e("DayPlanWidget", "Failed to render widget ID $id", e)
            }
        }
    }

    companion object {
        fun renderDayPlanLayout(context: Context, views: RemoteViews, prefs: SharedPreferences) {
            views.setImageViewResource(R.id.widget_bg_art, R.drawable.widget_bg_art_cyan)

            val capacity = prefs.getString("arcane.task.capacity", "") ?: ""
            views.setTextViewText(R.id.widget_dayplan_capacity, if (capacity.isNotEmpty()) "CAP $capacity" else "")

            val p0 = prefs.getString("arcane.task.dp0.title", "")?.trim() ?: ""
            val p1 = prefs.getString("arcane.task.dp1.title", "")?.trim() ?: ""
            val p2 = prefs.getString("arcane.task.dp2.title", "")?.trim() ?: ""
            val p3 = prefs.getString("arcane.task.dp3.title", "")?.trim() ?: ""
            val p4 = prefs.getString("arcane.task.dp4.title", "")?.trim() ?: ""

            val titles = listOf(p0, p1, p2, p3, p4).filter { it.isNotEmpty() }
            val count = titles.size
            val progressPct = WidgetCommon.getSafeInt(prefs, "arcane.task.progressPct", 0)

            if (count > 0) {
                views.setTextViewText(R.id.widget_dayplan_status_badge, "[ DAY PLAN // 0$count ACTIVE ]")
                views.setTextViewText(R.id.widget_dayplan_primary_title, titles[0].uppercase())

                if (count > 1) {
                    val remaining = count - 1
                    val remainingText = if (remaining > 1) " (+${remaining - 1} MORE)" else ""
                    views.setTextViewText(R.id.widget_dayplan_next_title, "${titles[1].uppercase()}$remainingText")
                    views.setTextViewText(R.id.widget_dayplan_items_count, "$count MISSIONS")
                    views.setViewVisibility(R.id.widget_dayplan_next_label, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_dayplan_next_title, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_dayplan_items_count, View.VISIBLE)
                } else {
                    views.setTextViewText(R.id.widget_dayplan_next_title, "FINAL MISSION IN QUEUE")
                    views.setTextViewText(R.id.widget_dayplan_items_count, "1 MISSION")
                    views.setViewVisibility(R.id.widget_dayplan_next_label, View.GONE)
                    views.setViewVisibility(R.id.widget_dayplan_next_title, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_dayplan_items_count, View.VISIBLE)
                }

                views.setViewVisibility(R.id.widget_dayplan_btn_check, View.VISIBLE)
                views.setViewVisibility(R.id.widget_dayplan_btn_task, View.VISIBLE)
                views.setProgressBar(R.id.widget_dayplan_progress, 100, progressPct.coerceIn(0, 100), false)
                views.setViewVisibility(R.id.widget_dayplan_progress, View.VISIBLE)
            } else {
                views.setTextViewText(R.id.widget_dayplan_status_badge, "[ DAY PLAN // STANDBY ]")
                views.setTextViewText(R.id.widget_dayplan_primary_title, "NO MISSIONS PLANNED")
                views.setTextViewText(R.id.widget_dayplan_next_title, "QUEUE MISSIONS IN TODAY PLANNER")
                views.setViewVisibility(R.id.widget_dayplan_next_label, View.GONE)
                views.setViewVisibility(R.id.widget_dayplan_items_count, View.GONE)
                views.setViewVisibility(R.id.widget_dayplan_btn_check, View.GONE)
                views.setViewVisibility(R.id.widget_dayplan_btn_task, View.GONE)
                views.setProgressBar(R.id.widget_dayplan_progress, 100, 0, false)
                views.setViewVisibility(R.id.widget_dayplan_progress, View.INVISIBLE)
            }

            val openPlanIntent = WidgetCommon.launchIntent(context, "task_open_plan")
            val openTaskIntent = WidgetCommon.launchIntent(context, "task_open")

            views.setOnClickPendingIntent(R.id.widget_dayplan_btn_open, openPlanIntent)
            views.setOnClickPendingIntent(R.id.widget_dayplan_primary_title, openPlanIntent)
            views.setOnClickPendingIntent(R.id.widget_dayplan_status_badge, openPlanIntent)
            views.setOnClickPendingIntent(R.id.widget_dayplan_btn_task, openTaskIntent)
            views.setOnClickPendingIntent(R.id.widget_dayplan_btn_check, WidgetCommon.actionIntent(context, "task_check_0", 110))
        }
    }

    private fun render(context: Context, mgr: AppWidgetManager, widgetId: Int, prefs: SharedPreferences) {
        val views = RemoteViews(context.packageName, R.layout.widget_dayplan)
        renderDayPlanLayout(context, views, prefs)
        mgr.updateAppWidget(widgetId, views)
    }
}
