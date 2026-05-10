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
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_summary)

                val balance = widgetData.getString("total_balance", "0.00") ?: "0.00"
                views.setTextViewText(R.id.total_balance, "$$balance")

                val accCount = widgetData.getInt("acc_count", 0)

                val rowIds = intArrayOf(R.id.acc_row_1, R.id.acc_row_2, R.id.acc_row_3, R.id.acc_row_4)
                val nameIds = intArrayOf(R.id.acc_name_1, R.id.acc_name_2, R.id.acc_name_3, R.id.acc_name_4)
                val balIds = intArrayOf(R.id.acc_bal_1, R.id.acc_bal_2, R.id.acc_bal_3, R.id.acc_bal_4)

                for (i in 0..3) {
                    if (i < accCount) {
                        views.setViewVisibility(rowIds[i], View.VISIBLE)
                        views.setTextViewText(nameIds[i], widgetData.getString("acc_${i + 1}_name", "") ?: "")
                        views.setTextViewText(balIds[i], "$" + (widgetData.getString("acc_${i + 1}_bal", "0") ?: "0"))
                    } else {
                        views.setViewVisibility(rowIds[i], View.GONE)
                    }
                }

                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (_: Exception) {
            }
        }
    }
}
