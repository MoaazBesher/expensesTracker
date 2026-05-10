package expenses.tracker

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class DebtsAlertsWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_debts_alerts)

                views.setTextViewText(R.id.i_owe_amt, "$" + (widgetData.getString("total_i_owe", "0") ?: "0"))
                views.setTextViewText(R.id.owed_me_amt, "$" + (widgetData.getString("total_owed_me", "0") ?: "0"))
                views.setTextViewText(R.id.alerts_count, "${widgetData.getInt("alerts_count", 0)}")

                val alertCount = widgetData.getInt("alerts_count", 0)

                showAlert(views, widgetData, R.id.alert_row_1, R.id.alert_title_1, R.id.alert_date_1, 1, alertCount)
                showAlert(views, widgetData, R.id.alert_row_2, R.id.alert_title_2, R.id.alert_date_2, 2, alertCount)

                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (_: Exception) {
            }
        }
    }

    private fun showAlert(
        views: RemoteViews,
        data: SharedPreferences,
        rowId: Int,
        titleId: Int,
        dateId: Int,
        index: Int,
        count: Int
    ) {
        if (index <= count) {
            views.setViewVisibility(rowId, View.VISIBLE)
            views.setTextViewText(titleId, data.getString("alert_${index}_title", "") ?: "")
            views.setTextViewText(dateId, data.getString("alert_${index}_date", "") ?: "")
        } else {
            views.setViewVisibility(rowId, View.GONE)
        }
    }
}
