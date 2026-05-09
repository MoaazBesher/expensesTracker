package expenses.tracker

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
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
            val views = RemoteViews(context.packageName, R.layout.widget_summary)

            val balance = widgetData.getString("total_balance", "0.00") ?: "0.00"
            views.setTextViewText(R.id.total_balance, "$$balance")

            val accCount = widgetData.getInt("acc_count", 0)
            for (i in 1..4) {
                val rowId = context.resources.getIdentifier("acc_row_$i", "id", context.packageName)
                val nameId = context.resources.getIdentifier("acc_name_$i", "id", context.packageName)
                val balId = context.resources.getIdentifier("acc_bal_$i", "id", context.packageName)

                if (i <= accCount) {
                    val name = widgetData.getString("acc_${i}_name", "") ?: ""
                    val bal = widgetData.getString("acc_${i}_bal", "0") ?: "0"
                    views.setViewVisibility(rowId, View.VISIBLE)
                    views.setTextViewText(nameId, name)
                    views.setTextViewText(balId, "$$bal")
                } else {
                    views.setViewVisibility(rowId, View.GONE)
                }
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
