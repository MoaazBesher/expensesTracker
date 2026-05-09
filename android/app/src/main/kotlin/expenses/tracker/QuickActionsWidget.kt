package expenses.tracker

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class QuickActionsWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_quick_actions)

            val incomeIntent = HomeWidgetLaunchIntent.getActivity(
                context, MainActivity::class.java,
                android.net.Uri.parse("expensestracker://action/add_income"))
            views.setOnClickPendingIntent(R.id.btn_add_income, incomeIntent)

            val expenseIntent = HomeWidgetLaunchIntent.getActivity(
                context, MainActivity::class.java,
                android.net.Uri.parse("expensestracker://action/add_expense"))
            views.setOnClickPendingIntent(R.id.btn_add_expense, expenseIntent)

            val alertIntent = HomeWidgetLaunchIntent.getActivity(
                context, MainActivity::class.java,
                android.net.Uri.parse("expensestracker://action/add_alert"))
            views.setOnClickPendingIntent(R.id.btn_add_alert, alertIntent)

            val debtIntent = HomeWidgetLaunchIntent.getActivity(
                context, MainActivity::class.java,
                android.net.Uri.parse("expensestracker://action/add_debt"))
            views.setOnClickPendingIntent(R.id.btn_add_debt, debtIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
