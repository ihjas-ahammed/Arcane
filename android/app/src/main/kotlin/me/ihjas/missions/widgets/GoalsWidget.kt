package me.ihjas.missions.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import es.antonborri.home_widget.HomeWidgetProvider
import me.ihjas.missions.R

class GoalsWidget : HomeWidgetProvider() {

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
                Log.e("GoalsWidget", "Failed to render widget ID $id", e)
            }
        }
    }

    companion object {
        fun renderGoalsLayout(context: Context, views: RemoteViews, prefs: SharedPreferences) {
            val scope = prefs.getString("arcane.goals.scope", "daily") ?: "daily"
            val isWeekly = scope.equals("weekly", ignoreCase = true)
            val scopeTag = if (isWeekly) "WEEKLY DIRECTIVES" else "DIRECTIVES"

            val totalCount = WidgetCommon.getSafeInt(prefs, "arcane.goals.totalCount", 0)
            val completedCount = WidgetCommon.getSafeInt(prefs, "arcane.goals.completedCount", 0)
            val progressPct = WidgetCommon.getSafeInt(prefs, "arcane.goals.progressPct", 0)

            // Header status badge
            if (totalCount > 0) {
                val compPad = if (completedCount < 10) "0$completedCount" else "$completedCount"
                val totPad = if (totalCount < 10) "0$totalCount" else "$totalCount"
                views.setTextViewText(R.id.widget_goals_status_badge, "[ $scopeTag // $compPad/$totPad COMPLETED ]")
            } else {
                views.setTextViewText(R.id.widget_goals_status_badge, "[ $scopeTag // STANDBY ]")
            }

            views.setTextViewText(R.id.widget_goals_xp_badge, "$completedCount / $totalCount DONE")

            // Progress bar
            views.setProgressBar(R.id.widget_goals_progress, 100, progressPct.coerceIn(0, 100), false)
            views.setTextViewText(R.id.widget_goals_progress_pct, "$progressPct%")

            // Slots or empty state
            if (totalCount == 0) {
                views.setViewVisibility(R.id.widget_goals_list_container, View.GONE)
                views.setViewVisibility(R.id.widget_goals_empty_container, View.VISIBLE)
                views.setTextViewText(
                    R.id.widget_goals_empty_title,
                    if (isWeekly) "NO DIRECTIVES LOGGED FOR THIS WEEK" else "NO DIRECTIVES LOGGED FOR TODAY"
                )
            } else {
                views.setViewVisibility(R.id.widget_goals_list_container, View.VISIBLE)
                views.setViewVisibility(R.id.widget_goals_empty_container, View.GONE)

                val containers = intArrayOf(
                    R.id.widget_goal_0_container,
                    R.id.widget_goal_1_container,
                    R.id.widget_goal_2_container
                )
                val checks = intArrayOf(
                    R.id.widget_goal_0_check,
                    R.id.widget_goal_1_check,
                    R.id.widget_goal_2_check
                )
                val titles = intArrayOf(
                    R.id.widget_goal_0_title,
                    R.id.widget_goal_1_title,
                    R.id.widget_goal_2_title
                )
                val tags = intArrayOf(
                    R.id.widget_goal_0_tag,
                    R.id.widget_goal_1_tag,
                    R.id.widget_goal_2_tag
                )

                for (i in 0..2) {
                    val gTitle = prefs.getString("arcane.goals.g$i.title", "") ?: ""
                    val isCompleted = WidgetCommon.getSafeBoolean(prefs, "arcane.goals.g$i.isCompleted", false)
                    val gTag = prefs.getString("arcane.goals.g$i.tag", "") ?: ""

                    if (gTitle.isNotEmpty()) {
                        views.setViewVisibility(containers[i], View.VISIBLE)
                        views.setTextViewText(titles[i], gTitle)
                        views.setTextViewText(tags[i], gTag)

                        if (isCompleted) {
                            views.setInt(checks[i], "setBackgroundResource", R.drawable.widget_check_on_amber)
                            views.setTextViewText(checks[i], "✓")
                            views.setTextColor(titles[i], WidgetTheme.color(context, R.color.widget_text_muted))
                        } else {
                            views.setInt(checks[i], "setBackgroundResource", R.drawable.widget_check_off_amber)
                            views.setTextViewText(checks[i], "")
                            views.setTextColor(titles[i], WidgetTheme.color(context, R.color.widget_text_white))
                        }

                        // Checkbox tap toggles goal check via action intent
                        views.setOnClickPendingIntent(
                            checks[i],
                            WidgetCommon.actionIntent(context, "goal_toggle_$i", 200 + i)
                        )
                        views.setOnClickPendingIntent(
                            containers[i],
                            WidgetCommon.actionIntent(context, "goal_toggle_$i", 200 + i)
                        )
                    } else {
                        views.setViewVisibility(containers[i], View.GONE)
                    }
                }
            }

            // Clicking widget background or header opens Arcane Directives
            val openIntent = WidgetCommon.launchIntent(context, "goals_open")
            views.setOnClickPendingIntent(R.id.widget_goals_card, openIntent)
            views.setOnClickPendingIntent(R.id.widget_goals_status_badge, openIntent)
            views.setOnClickPendingIntent(R.id.widget_goals_empty_container, openIntent)
        }
    }

    private fun render(context: Context, mgr: AppWidgetManager, widgetId: Int, prefs: SharedPreferences) {
        val views = WidgetTheme.views(context, R.layout.widget_goals)
        renderGoalsLayout(context, views, prefs)
        mgr.updateAppWidget(widgetId, views)
    }
}
