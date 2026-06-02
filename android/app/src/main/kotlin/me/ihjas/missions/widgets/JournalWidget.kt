package me.ihjas.missions.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import me.ihjas.missions.R

class JournalWidget : HomeWidgetProvider() {

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
        val views = RemoteViews(context.packageName, R.layout.widget_journal)

        // Load background image
        val imagePath = prefs.getString("arcane.journal.image", null)
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
            R.id.widget_journal_root,
            WidgetCommon.launchIntent(context, "journal_open_latest"),
        )
        views.setOnClickPendingIntent(
            R.id.widget_journal_btn_new,
            WidgetCommon.launchIntent(context, "journal_new"),
        )
        views.setOnClickPendingIntent(
            R.id.widget_journal_btn_open,
            WidgetCommon.launchIntent(context, "journal_archive"),
        )

        mgr.updateAppWidget(widgetId, views)
    }
}
