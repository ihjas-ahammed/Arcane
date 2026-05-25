package me.ihjas.missions.widgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import me.ihjas.missions.R
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class FinanceWidget : AppWidgetProvider() {

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
        val views = RemoteViews(context.packageName, R.layout.widget_finance)

        val balance = prefs.getString("arcane.fin.balance", "0")?.toDoubleOrNull() ?: 0.0
        val today = prefs.getString("arcane.fin.today", "0")?.toDoubleOrNull() ?: 0.0
        val mtd = prefs.getString("arcane.fin.mtd", "0")?.toDoubleOrNull() ?: 0.0
        val budgetPct = prefs.getInt("arcane.fin.budgetPct", 0)
        val updatedAtMs = prefs.getLong("arcane.fin.updatedAtMs", 0L)

        views.setTextViewText(R.id.widget_finance_balance, WidgetCommon.fmtMoney(balance))
        views.setTextViewText(R.id.widget_finance_today, WidgetCommon.fmtMoney(today))
        views.setTextViewText(R.id.widget_finance_mtd, WidgetCommon.fmtMoney(mtd))
        views.setTextViewText(R.id.widget_finance_budget_pct, "$budgetPct%")

        val clampedPct = budgetPct.coerceIn(0, 100)
        views.setProgressBar(R.id.widget_finance_progress, 100, clampedPct, false)

        if (updatedAtMs > 0) {
            val time = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date(updatedAtMs))
            views.setTextViewText(R.id.widget_finance_ts, time)
        } else {
            views.setTextViewText(R.id.widget_finance_ts, "")
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
