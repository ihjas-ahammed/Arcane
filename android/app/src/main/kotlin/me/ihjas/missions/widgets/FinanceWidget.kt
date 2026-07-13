package me.ihjas.missions.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
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

        val balance = (prefs.getString("arcane.fin.balance", "0") ?: "0").toDoubleOrNull() ?: 0.0
        val today = (prefs.getString("arcane.fin.today", "0") ?: "0").toDoubleOrNull() ?: 0.0
        val mtd = (prefs.getString("arcane.fin.mtd", "0") ?: "0").toDoubleOrNull() ?: 0.0
        val budgetPct = WidgetCommon.getSafeInt(prefs, "arcane.fin.budgetPct", 0)

        views.setTextViewText(R.id.widget_fin_balance, WidgetCommon.fmtMoney(balance))
        views.setTextViewText(R.id.widget_fin_today, "TODAY ${WidgetCommon.fmtMoney(today)}")
        views.setTextViewText(R.id.widget_fin_mtd, "MTD ${WidgetCommon.fmtMoney(mtd)}")
        views.setProgressBar(R.id.widget_fin_budget, 100, budgetPct.coerceIn(0, 100), false)

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
