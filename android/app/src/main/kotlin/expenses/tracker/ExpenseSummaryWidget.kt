package expenses.tracker

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class ExpenseSummaryWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_summary)
                views.setTextViewText(R.id.total_balance, "$" + (widgetData.getString("total_balance", "0.00") ?: "0.00"))
                views.setTextViewText(R.id.income_tag, "+$" + (widgetData.getString("income_total", "0") ?: "0"))
                views.setTextViewText(R.id.expense_tag, "-$" + (widgetData.getString("expense_total", "0") ?: "0"))
                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (_: Exception) {
            }
        }
    }
}
