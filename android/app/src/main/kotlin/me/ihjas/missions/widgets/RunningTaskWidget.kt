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
        val dayPlannerWidgetCheckable = WidgetCommon.getSafeBoolean(prefs, "arcane.task.dayPlannerWidgetCheckable", false)
        val multitaskCount = WidgetCommon.getSafeInt(prefs, "arcane.task.multitaskCount", 0)
        val isOnBus = WidgetCommon.getSafeBoolean(prefs, "arcane.bus.isOnBus", false)
        val isTaskRunning = WidgetCommon.getSafeBoolean(prefs, "arcane.task.isRunning", false)

        val views: RemoteViews
        if (isOnBus && !isTaskRunning) {
            views = RemoteViews(context.packageName, R.layout.widget_running_task)
            views.setViewVisibility(R.id.widget_running_layout, View.VISIBLE)
            views.setViewVisibility(R.id.widget_multitask_layout, View.GONE)
            renderBusTransit(context, views, prefs)
        } else if (dayPlannerWidgetCheckable) {
            views = RemoteViews(context.packageName, R.layout.widget_dayplan)
            renderDayPlan(context, views, prefs)
        } else if (multitaskCount > 1) {
            views = RemoteViews(context.packageName, R.layout.widget_running_task)
            views.setViewVisibility(R.id.widget_running_layout, View.GONE)
            views.setViewVisibility(R.id.widget_multitask_layout, View.VISIBLE)
            val isRunning = WidgetCommon.getSafeBoolean(prefs, "arcane.task.isRunning", false)
            val artRes = if (isRunning) R.drawable.widget_bg_art_red else R.drawable.widget_bg_art_cyan
            views.setImageViewResource(R.id.widget_bg_art, artRes)
            renderMultitask(context, views, prefs, multitaskCount)
        } else {
            views = RemoteViews(context.packageName, R.layout.widget_running_task)
            views.setViewVisibility(R.id.widget_running_layout, View.VISIBLE)
            views.setViewVisibility(R.id.widget_multitask_layout, View.GONE)
            renderRunning(context, views, prefs)
        }

        mgr.updateAppWidget(widgetId, views)
    }

    private fun renderMultitask(context: Context, views: RemoteViews, prefs: SharedPreferences, count: Int) {
        val isRunning = WidgetCommon.getSafeBoolean(prefs, "arcane.task.isRunning", false)
        val artRes = if (isRunning) R.drawable.widget_bg_art_red else R.drawable.widget_bg_art_cyan
        views.setImageViewResource(R.id.widget_bg_art, artRes)

        val statusLabel = "MULTITASK PROTOCOL · [0${count.coerceIn(2, 3)} ACTIVE]"
        views.setTextViewText(R.id.widget_mt_status_label, statusLabel)
        views.setViewVisibility(R.id.widget_mt_rec_label, if (isRunning) View.VISIBLE else View.GONE)

        val cardIds = intArrayOf(R.id.widget_mt_card_0, R.id.widget_mt_card_1, R.id.widget_mt_card_2)
        val titleIds = intArrayOf(R.id.widget_mt_title_0, R.id.widget_mt_title_1, R.id.widget_mt_title_2)
        val parentIds = intArrayOf(R.id.widget_mt_parent_0, R.id.widget_mt_parent_1, R.id.widget_mt_parent_2)
        val cpsIds = intArrayOf(R.id.widget_mt_cps_0, R.id.widget_mt_cps_1, R.id.widget_mt_cps_2)

        val openIntent = WidgetCommon.launchIntent(context, "task_open")
        val openPlanIntent = WidgetCommon.launchIntent(context, "task_open_plan")

        views.setOnClickPendingIntent(R.id.widget_mt_btn_dayplan, openPlanIntent)

        val effectiveCount = count.coerceAtMost(3)
        for (i in 0 until 3) {
            if (i < effectiveCount) {
                views.setViewVisibility(cardIds[i], View.VISIBLE)
                val title = prefs.getString("arcane.task.mt$i.title", "") ?: ""
                val parent = prefs.getString("arcane.task.mt$i.parent", "") ?: ""
                val cps = prefs.getString("arcane.task.mt$i.checkpoints", "") ?: ""

                views.setTextViewText(titleIds[i], title.uppercase())
                views.setTextViewText(parentIds[i], parent.uppercase())
                views.setTextViewText(cpsIds[i], if (cps.isNotEmpty()) "✓ $cps" else "0/0")
                views.setOnClickPendingIntent(cardIds[i], openIntent)
            } else {
                views.setViewVisibility(cardIds[i], View.GONE)
            }
        }

        if (isRunning) {
            views.setTextViewText(R.id.widget_mt_btn_engage, "HALT SESSION")
            views.setInt(R.id.widget_mt_btn_engage, "setBackgroundResource", R.drawable.widget_btn_primary_red)
            views.setTextColor(R.id.widget_mt_btn_engage, ContextCompat.getColor(context, R.color.widget_text_white))
        } else {
            views.setTextViewText(R.id.widget_mt_btn_engage, "ENGAGE ALL")
            views.setInt(R.id.widget_mt_btn_engage, "setBackgroundResource", R.drawable.widget_btn_primary_amber)
            views.setTextColor(R.id.widget_mt_btn_engage, ContextCompat.getColor(context, R.color.widget_bg_deep))
        }

        views.setOnClickPendingIntent(R.id.widget_mt_btn_engage, WidgetCommon.actionIntent(context, "task_toggle", 101))
        views.setOnClickPendingIntent(R.id.widget_mt_btn_check, WidgetCommon.actionIntent(context, "task_check_next", 102))
        views.setOnClickPendingIntent(R.id.widget_mt_btn_finish, WidgetCommon.actionIntent(context, "task_finish", 103))
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
        val accentColor = when {
            !hasTask -> ContextCompat.getColor(context, R.color.widget_text_muted)
            isRunning -> ContextCompat.getColor(context, R.color.widget_accent_red)
            isCheckpoint -> ContextCompat.getColor(context, R.color.widget_accent_cyan)
            else -> ContextCompat.getColor(context, R.color.widget_accent_amber)
        }

        val artRes = when {
            !hasTask -> R.drawable.widget_bg_art_dim
            isRunning -> R.drawable.widget_bg_art_red
            isCheckpoint -> R.drawable.widget_bg_art_cyan
            else -> R.drawable.widget_bg_art_amber
        }
        views.setImageViewResource(R.id.widget_bg_art, artRes)

        views.setTextViewText(R.id.widget_status_label, statusLabel)
        views.setTextColor(R.id.widget_status_label, accentColor)
        views.setViewVisibility(R.id.widget_rec_label, if (isRunning) View.VISIBLE else View.GONE)
        views.setTextViewText(R.id.widget_capacity, if (capacity.isNotEmpty()) "CAP $capacity" else "")

        if (hasTask) {
            views.setTextViewText(R.id.widget_task_title, title.uppercase())
            views.setTextViewText(R.id.widget_task_subtitle, subtitle.uppercase())
            views.setViewVisibility(R.id.widget_subtitle_container, if (subtitle.isNotEmpty()) View.VISIBLE else View.GONE)
        } else {
            views.setTextViewText(R.id.widget_task_title, "NO PLAN SET")
            views.setTextViewText(R.id.widget_task_subtitle, "QUEUE STANDBY")
            views.setViewVisibility(R.id.widget_subtitle_container, View.VISIBLE)
        }

        // Time mode label
        views.setTextViewText(R.id.widget_time_mode_label, if (isRunning) "SESSION" else "TODAY")

        // Time: live chronometer while running, static accumulated total otherwise.
        if (isRunning && sessionStartMs > 0L) {
            views.setViewVisibility(R.id.widget_task_today, View.GONE)
            views.setViewVisibility(R.id.widget_task_chronometer, View.VISIBLE)
            views.setTextColor(R.id.widget_task_chronometer, accentColor)
            val elapsedSinceSession = System.currentTimeMillis() - sessionStartMs
            val base = SystemClock.elapsedRealtime() - elapsedSinceSession - (accumulatedSec * 1000L)
            views.setChronometer(R.id.widget_task_chronometer, base, null, true)
        } else {
            views.setViewVisibility(R.id.widget_task_chronometer, View.GONE)
            views.setViewVisibility(R.id.widget_task_today, View.VISIBLE)
            views.setTextColor(R.id.widget_task_today, accentColor)
            views.setTextViewText(R.id.widget_task_today, WidgetCommon.fmtSeconds(accumulatedSec))
        }

        // Progress bar reflects the subtask's completion; hidden with no task.
        views.setViewVisibility(R.id.widget_task_progress, if (hasTask) View.VISIBLE else View.INVISIBLE)
        views.setProgressBar(R.id.widget_task_progress, 100, progressPct.coerceIn(0, 100), false)

        val openPlanIntent = WidgetCommon.launchIntent(context, "task_open_plan")
        val openTaskIntent = WidgetCommon.launchIntent(context, "task_open")

        views.setOnClickPendingIntent(R.id.widget_btn_dayplan, openPlanIntent)
        views.setOnClickPendingIntent(R.id.widget_task_title, openTaskIntent)

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
            views.setViewVisibility(R.id.widget_btn_check, View.GONE)
            views.setViewVisibility(R.id.widget_btn_finish, View.VISIBLE)
            views.setTextViewText(R.id.widget_btn_engage, "OPEN PLAN")
            views.setInt(R.id.widget_btn_engage, "setBackgroundResource", R.drawable.widget_btn_primary_amber)
            views.setTextColor(R.id.widget_btn_engage, ContextCompat.getColor(context, R.color.widget_bg_deep))
            views.setTextViewText(R.id.widget_btn_finish, "OPEN")

            views.setOnClickPendingIntent(R.id.widget_btn_engage, openPlanIntent)
            views.setOnClickPendingIntent(R.id.widget_btn_finish, openTaskIntent)
        }
    }

    private fun renderBusTransit(context: Context, views: RemoteViews, prefs: SharedPreferences) {
        val busOrigin = prefs.getString("arcane.bus.origin", "S.S COLLEGE") ?: "S.S COLLEGE"
        val busDestination = prefs.getString("arcane.bus.destination", "EDAVANNAPPARA") ?: "EDAVANNAPPARA"
        val busProgressPct = WidgetCommon.getSafeInt(prefs, "arcane.bus.progressPct", 0)
        val busMinutesRemaining = WidgetCommon.getSafeInt(prefs, "arcane.bus.minutesRemaining", -1)
        val speedKmh = WidgetCommon.getSafeInt(prefs, "arcane.bus.speedKmh", 20)
        val displaySpeed = if (speedKmh > 0) speedKmh else 20

        val accentColor = ContextCompat.getColor(context, R.color.widget_accent_amber)
        views.setImageViewResource(R.id.widget_bg_art, R.drawable.widget_bg_art_amber)

        views.setTextViewText(R.id.widget_status_label, "[ IN THE BUS // TRANSIT ACTIVE ]")
        views.setTextColor(R.id.widget_status_label, accentColor)
        views.setViewVisibility(R.id.widget_rec_label, View.VISIBLE)
        views.setTextViewText(R.id.widget_rec_label, "● $displaySpeed KM/H")
        views.setTextColor(R.id.widget_rec_label, accentColor)
        views.setTextViewText(R.id.widget_capacity, if (busMinutesRemaining >= 0) "ETA ~${busMinutesRemaining}M" else "$displaySpeed KM/H")

        views.setTextViewText(R.id.widget_task_title, "${busOrigin.uppercase()} → ${busDestination.uppercase()}")
        views.setTextViewText(R.id.widget_task_subtitle, "IN TRANSIT @ $displaySpeed KM/H · $busProgressPct%")
        views.setViewVisibility(R.id.widget_subtitle_container, View.VISIBLE)

        views.setTextViewText(R.id.widget_time_mode_label, "REMAINING")
        views.setViewVisibility(R.id.widget_task_chronometer, View.GONE)
        views.setViewVisibility(R.id.widget_task_today, View.VISIBLE)
        views.setTextColor(R.id.widget_task_today, accentColor)
        views.setTextViewText(R.id.widget_task_today, if (busMinutesRemaining >= 0) "~$busMinutesRemaining MIN" else "$busProgressPct%")

        views.setViewVisibility(R.id.widget_task_progress, View.VISIBLE)
        views.setProgressBar(R.id.widget_task_progress, 100, busProgressPct.coerceIn(0, 100), false)

        val busOpenIntent = WidgetCommon.launchIntent(context, "bus_open")
        views.setOnClickPendingIntent(R.id.widget_btn_dayplan, busOpenIntent)
        views.setOnClickPendingIntent(R.id.widget_task_title, busOpenIntent)

        views.setViewVisibility(R.id.widget_btn_check, View.VISIBLE)
        views.setViewVisibility(R.id.widget_btn_finish, View.VISIBLE)

        views.setTextViewText(R.id.widget_btn_engage, "END TRIP")
        views.setInt(R.id.widget_btn_engage, "setBackgroundResource", R.drawable.widget_btn_primary_red)
        views.setTextColor(R.id.widget_btn_engage, ContextCompat.getColor(context, R.color.widget_text_white))
        views.setOnClickPendingIntent(R.id.widget_btn_engage, WidgetCommon.actionIntent(context, "bus_end_trip", 201))

        views.setTextViewText(R.id.widget_btn_check, "RADAR")
        views.setOnClickPendingIntent(R.id.widget_btn_check, busOpenIntent)

        views.setTextViewText(R.id.widget_btn_finish, "ROUTE")
        views.setOnClickPendingIntent(R.id.widget_btn_finish, busOpenIntent)
    }

    private fun renderDayPlan(context: Context, views: RemoteViews, prefs: SharedPreferences) {
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
        val openPlanIntent = WidgetCommon.launchIntent(context, "task_open")

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

        views.setViewVisibility(R.id.widget_dayplan_empty, if (visibleCount == 0) View.VISIBLE else View.GONE)
        views.setOnClickPendingIntent(R.id.widget_dayplan_btn_open, openPlanIntent)
        views.setOnClickPendingIntent(R.id.widget_dayplan_btn_task, WidgetCommon.launchIntent(context, "task_open"))
        views.setOnClickPendingIntent(R.id.widget_dayplan_status_badge, openPlanIntent)
    }
}
