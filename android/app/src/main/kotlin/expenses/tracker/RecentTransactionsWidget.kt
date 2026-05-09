package expenses.tracker

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class RecentTransactionsWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_recent)

            // We expect data like "txn_1_title", "txn_1_amt", "txn_1_type"
            val count = widgetData.getInt("txn_count", 0)

            if (count == 0) {
                views.setViewVisibility(R.id.empty_msg, View.VISIBLE)
                views.setViewVisibility(R.id.transactions_container, View.GONE)
            } else {
                views.setViewVisibility(R.id.empty_msg, View.GONE)
                views.setViewVisibility(R.id.transactions_container, View.VISIBLE)

                // Populate up to 3 items
                for (i in 1..3) {
                    val titleId = context.resources.getIdentifier("title_$i", "id", context.packageName)
                    val amtId = context.resources.getIdentifier("amt_$i", "id", context.packageName)
                    val layoutId = context.resources.getIdentifier("txn_$i", "id", context.packageName)

                    if (i <= count) {
                        val title = widgetData.getString("txn_${i}_title", "")
                        val amt = widgetData.getString("txn_${i}_amt", "")
                        val isIncome = widgetData.getBoolean("txn_${i}_is_income", false)

                        views.setViewVisibility(layoutId, View.VISIBLE)
                        views.setTextViewText(titleId, title)
                        views.setTextViewText(amtId, (if (isIncome) "+" else "-") + "$" + amt)
                        views.setTextColor(amtId, if (isIncome) 0xFF3FB950.toInt() else 0xFFF85149.toInt())
                    } else {
                        views.setViewVisibility(layoutId, View.GONE)
                    }
                }
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
