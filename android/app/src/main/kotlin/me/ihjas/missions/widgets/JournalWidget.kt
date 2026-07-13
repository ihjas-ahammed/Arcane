package me.ihjas.missions.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
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

        val count = WidgetCommon.getSafeInt(prefs, "arcane.journal.count", 0)
        views.setTextViewText(
            R.id.widget_journal_count,
            if (count == 1) "1 ENTRY" else "$count ENTRIES",
        )

        setPip(context, views, R.id.widget_journal_pip_wake, WidgetCommon.getSafeBoolean(prefs, "arcane.journal.wake", false))
        setPip(context, views, R.id.widget_journal_pip_morn, WidgetCommon.getSafeBoolean(prefs, "arcane.journal.morn", false))
        setPip(context, views, R.id.widget_journal_pip_aft, WidgetCommon.getSafeBoolean(prefs, "arcane.journal.aft", false))
        setPip(context, views, R.id.widget_journal_pip_eve, WidgetCommon.getSafeBoolean(prefs, "arcane.journal.eve", false))
        setPip(context, views, R.id.widget_journal_pip_night, WidgetCommon.getSafeBoolean(prefs, "arcane.journal.night", false))

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

    private fun setPip(context: Context, views: RemoteViews, id: Int, filled: Boolean) {
        if (filled) {
            views.setInt(id, "setBackgroundResource", R.drawable.widget_pip_on)
            views.setTextColor(id, ContextCompat.getColor(context, R.color.widget_bg_deep))
        } else {
            views.setInt(id, "setBackgroundResource", R.drawable.widget_pip_off)
            views.setTextColor(id, ContextCompat.getColor(context, R.color.widget_text_muted))
        }
    }
}
