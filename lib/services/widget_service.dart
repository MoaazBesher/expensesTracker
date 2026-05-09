import 'package:home_widget/home_widget.dart';
import 'firebase_service.dart';
import '../models/account_model.dart';

/// Updates Android home screen widget data.
/// Call after balance/transaction changes.
class WidgetService {
  static const _androidWidgetName = 'ExpenseSummaryWidget';
  static const _androidQuickActionsName = 'QuickActionsWidget';
  static const _androidRecentName = 'RecentTransactionsWidget';
  static const _androidDebtsAlertsName = 'DebtsAlertsWidget';

  /// Push summary data + all accounts to the summary widget
  static Future<void> updateSummaryWidget({
    required double totalBalance,
    required List<AccountModel> accounts,
  }) async {
    try {
      await HomeWidget.saveWidgetData('total_balance', totalBalance.toStringAsFixed(2));

      // Save each account (up to 4)
      final limited = accounts.take(4).toList();
      await HomeWidget.saveWidgetData('acc_count', limited.length);
      for (int i = 0; i < limited.length; i++) {
        final idx = i + 1;
        await HomeWidget.saveWidgetData('acc_${idx}_name', limited[i].name);
        await HomeWidget.saveWidgetData('acc_${idx}_bal', limited[i].balance.toStringAsFixed(2));
      }

      await HomeWidget.updateWidget(androidName: _androidWidgetName);
    } catch (_) {
      // Widget may not be placed on home screen — ignore
    }
  }

  /// Push recent transactions to the recent widget
  static Future<void> updateRecentWidget(List<Map<String, dynamic>> txns) async {
    try {
      final limited = txns.take(3).toList();
      await HomeWidget.saveWidgetData('txn_count', limited.length);
      for (int i = 0; i < limited.length; i++) {
        final t = limited[i];
        final idx = i + 1;
        await HomeWidget.saveWidgetData('txn_${idx}_title', t['category'] ?? 'General');
        await HomeWidget.saveWidgetData('txn_${idx}_amt', t['amount']?.toString() ?? '0');
        await HomeWidget.saveWidgetData('txn_${idx}_is_income', t['type'] == 'income');
      }
      await HomeWidget.updateWidget(androidName: _androidRecentName);
    } catch (_) {}
  }

  /// Push debts and alerts data to the widget
  static Future<void> updateDebtsAlertsWidget({
    required double totalIOwe,
    required double totalOwedMe,
    required int alertsCount,
  }) async {
    try {
      await HomeWidget.saveWidgetData('total_i_owe', totalIOwe.toStringAsFixed(0));
      await HomeWidget.saveWidgetData('total_owed_me', totalOwedMe.toStringAsFixed(0));
      await HomeWidget.saveWidgetData('alerts_count', alertsCount);
      await HomeWidget.updateWidget(androidName: _androidDebtsAlertsName);
    } catch (_) {}
  }

  /// Trigger quick-actions widget refresh (no dynamic data, just ensure it's alive)
  static Future<void> updateQuickActionsWidget() async {
    try {
      await HomeWidget.updateWidget(androidName: _androidQuickActionsName);
    } catch (_) {}
  }

  /// Register background callback for widget tap interactions
  static Future<void> registerInteractivity() async {
    await HomeWidget.registerInteractivityCallback(backgroundCallback);
  }
}

/// Top-level function called when the widget is tapped (must be top-level)
@pragma('vm:entry-point')
Future<void> backgroundCallback(Uri? uri) async {
  // The actual navigation happens when the app opens via the deep link URI
  // This callback just ensures the widget interaction is processed
}
