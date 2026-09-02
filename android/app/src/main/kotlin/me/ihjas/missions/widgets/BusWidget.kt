package me.ihjas.missions.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import me.ihjas.missions.R

class BusWidget : HomeWidgetProvider() {

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
        val views = RemoteViews(context.packageName, R.layout.widget_bus)

        val options = mgr.getAppWidgetOptions(widgetId)
        val minHeight = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT) ?: 0

        val origin = prefs.getString("arcane.bus.origin", "S.S COLLEGE") ?: "S.S COLLEGE"
        val destination = prefs.getString("arcane.bus.destination", "EDAVANNAPPARA") ?: "EDAVANNAPPARA"
        val nextTime = prefs.getString("arcane.bus.nextTime", "08:15 AM") ?: "08:15 AM"
        val nextSubStop = prefs.getString("arcane.bus.nextSubStop", "") ?: ""
        val isOnBus = WidgetCommon.getSafeBoolean(prefs, "arcane.bus.isOnBus", false)
        val speedKmh = WidgetCommon.getSafeInt(prefs, "arcane.bus.speedKmh", 0)
        val minutesRemaining = WidgetCommon.getSafeInt(prefs, "arcane.bus.minutesRemaining", -1)

        val statusBadge = if (isOnBus) "[ ON BUS // TRANSIT ACTIVE ]" else "[ BUS RADAR // STANDBY ]"
        val speedLabel = if (isOnBus && speedKmh > 0) "SPEED: $speedKmh KM/H" else "GPS: ACTIVE"

        views.setTextViewText(R.id.widget_bus_status_badge, statusBadge)
        views.setTextViewText(R.id.widget_bus_speed_label, speedLabel)
        views.setTextViewText(R.id.widget_bus_route, "${origin.uppercase()} → ${destination.uppercase()}")

        val mainTimeText = if (isOnBus && minutesRemaining >= 0) {
            "ETA ~${minutesRemaining}M TO $destination"
        } else {
            nextTime
        }
        views.setTextViewText(R.id.widget_bus_main_time, mainTimeText)

        val subStopInfo = if (nextSubStop.isNotEmpty()) {
            if (isOnBus) "NEXT STOP: ${nextSubStop.uppercase()}" else "VIA: ${nextSubStop.uppercase()}"
        } else {
            if (minutesRemaining >= 0) "DEPARTS IN $minutesRemaining MIN" else "CHECK SCHEDULE"
        }
        views.setTextViewText(R.id.widget_bus_substop_info, subStopInfo)

        if (minHeight > 0 && minHeight < 100) {
            views.setViewVisibility(R.id.widget_bus_buttons_layout, View.GONE)
        } else {
            views.setViewVisibility(R.id.widget_bus_buttons_layout, View.VISIBLE)
        }

        // Taps
        views.setOnClickPendingIntent(
            R.id.widget_bus_root,
            WidgetCommon.launchIntent(context, "bus_open"),
        )
        views.setOnClickPendingIntent(
            R.id.widget_bus_btn_swap,
            WidgetCommon.actionIntent(context, "bus_swap", 301),
        )
        views.setOnClickPendingIntent(
            R.id.widget_bus_btn_open,
            WidgetCommon.launchIntent(context, "bus_open"),
        )

        mgr.updateAppWidget(widgetId, views)
    }
}
