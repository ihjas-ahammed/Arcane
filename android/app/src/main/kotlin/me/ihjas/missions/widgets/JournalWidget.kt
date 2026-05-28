package me.ihjas.missions.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import me.ihjas.missions.R
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class JournalWidget : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            render(context, appWidgetManager, id)
        }
    }

    private fun render(context: Context, mgr: AppWidgetManager, widgetId: Int) {
        val prefs = WidgetCommon.prefs(context)
        val views = RemoteViews(context.packageName, R.layout.widget_journal)

        val count = prefs.getInt("arcane.journal.count", 0)
        val latestTrigger = prefs.getString("arcane.journal.latestTrigger", "") ?: ""
        val latestEmotion = prefs.getString("arcane.journal.latestEmotion", "") ?: ""
        val latestTsMs = prefs.getLong("arcane.journal.latestTsMs", 0L)

        views.setTextViewText(
            R.id.widget_journal_count,
            "$count ${if (count == 1) "ENTRY" else "ENTRIES"}",
        )

        if (latestTrigger.isNotEmpty()) {
            views.setTextViewText(R.id.widget_journal_trigger, latestTrigger)
            views.setTextViewText(R.id.widget_journal_emotion, latestEmotion.uppercase())
            if (latestTsMs > 0) {
                val ts = SimpleDateFormat("MMM dd · HH:mm", Locale.getDefault()).format(Date(latestTsMs))
                views.setTextViewText(R.id.widget_journal_ts, ts)
            } else {
                views.setTextViewText(R.id.widget_journal_ts, "")
            }
        } else {
            views.setTextViewText(
                R.id.widget_journal_trigger,
                "No logs yet. Tap + to log your first reflection.",
            )
            views.setTextViewText(R.id.widget_journal_emotion, "")
            views.setTextViewText(R.id.widget_journal_ts, "")
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
