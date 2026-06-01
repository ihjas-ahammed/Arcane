package me.ihjas.missions.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import me.ihjas.missions.R
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import es.antonborri.home_widget.HomeWidgetProvider

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

        val balance = WidgetCommon.getSafeDouble(prefs, "arcane.fin.balance", 0.0)
        val today = WidgetCommon.getSafeDouble(prefs, "arcane.fin.today", 0.0)
        val mtd = WidgetCommon.getSafeDouble(prefs, "arcane.fin.mtd", 0.0)
        val budgetPct = WidgetCommon.getSafeInt(prefs, "arcane.fin.budgetPct", 0)
        val updatedAtMs = WidgetCommon.getSafeLong(prefs, "arcane.fin.updatedAtMs", 0L)

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
