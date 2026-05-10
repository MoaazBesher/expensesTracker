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

                views.setTextViewText(R.id.total_balance, "$" + (widgetData.getString("total_balance", "0.00") ?: "0.00"))

                val accCount = widgetData.getInt("acc_count", 0)

                showRow(views, widgetData, R.id.acc_row_1, R.id.acc_name_1, R.id.acc_bal_1, 1, accCount)
                showRow(views, widgetData, R.id.acc_row_2, R.id.acc_name_2, R.id.acc_bal_2, 2, accCount)
                showRow(views, widgetData, R.id.acc_row_3, R.id.acc_name_3, R.id.acc_bal_3, 3, accCount)
                showRow(views, widgetData, R.id.acc_row_4, R.id.acc_name_4, R.id.acc_bal_4, 4, accCount)

                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (_: Exception) {
            }
        }
    }

    private fun showRow(
        views: RemoteViews,
        data: SharedPreferences,
        rowId: Int,
        nameId: Int,
        balId: Int,
        index: Int,
        count: Int
    ) {
        if (index <= count) {
            views.setViewVisibility(rowId, View.VISIBLE)
            views.setTextViewText(nameId, data.getString("acc_${index}_name", "") ?: "")
            views.setTextViewText(balId, "$" + (data.getString("acc_${index}_bal", "0") ?: "0"))
        } else {
            views.setViewVisibility(rowId, View.GONE)
        }
    }
}
