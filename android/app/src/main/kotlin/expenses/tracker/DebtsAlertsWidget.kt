package expenses.tracker

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
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
            // Use R.layout directly for stability
            val views = RemoteViews(context.packageName, R.layout.widget_debts_alerts)

            val iOwe = widgetData.getString("total_i_owe", "0") ?: "0"
            val owedMe = widgetData.getString("total_owed_me", "0") ?: "0"
            val alerts = widgetData.getInt("alerts_count", 0)

            views.setTextViewText(R.id.i_owe_amt, "$$iOwe")
            views.setTextViewText(R.id.owed_me_amt, "$$owedMe")
            views.setTextViewText(R.id.alerts_count, "$alerts")

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
