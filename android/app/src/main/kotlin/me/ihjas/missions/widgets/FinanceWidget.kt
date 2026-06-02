package me.ihjas.missions.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import me.ihjas.missions.R

class FinanceWidget : HomeWidgetProvider() {

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
        val views = RemoteViews(context.packageName, R.layout.widget_finance)

        // Load background image
        val imagePath = prefs.getString("arcane.fin.image", null)
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

        views.setOnClickPendingIntent(
            R.id.widget_finance_root,
            WidgetCommon.launchIntent(context, "finance_open"),
        )
        views.setOnClickPendingIntent(
            R.id.widget_finance_btn_income,
            WidgetCommon.launchIntent(context, "finance_add_income"),
        )
        views.setOnClickPendingIntent(
            R.id.widget_finance_btn_expense,
            WidgetCommon.launchIntent(context, "finance_add_expense"),
        )

        mgr.updateAppWidget(widgetId, views)
    }
}
