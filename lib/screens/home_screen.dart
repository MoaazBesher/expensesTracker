import 'dart:async';

import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/native_pending_sync.dart';
import '../services/storage_service.dart';
import '../services/widget_service.dart';
import '../models/account_model.dart';
import '../utils/app_theme.dart';
import '../utils/screen_utils.dart';
import '../utils/offline_transactions_merge.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;
  const HomeScreen({super.key, this.onNavigateTab});
  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final DateTime _currentMonth = DateTime.now();
  double _totalBalance = 0.0;
  List<AccountModel> _accounts = [];
  double _monthlyIncome = 0.0;
  double _monthlyExpenses = 0.0;
  List<Map<String, dynamic>> _recentTransactions = [];
  List<Map<String, dynamic>> _recentAlerts = [];
  double _totalIOwe = 0.0;
  double _totalOwedMe = 0.0;
  int _alertsCount = 0;
  StreamSubscription<List<Map<String, dynamic>>>? _mergedTxSub;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _mergedTxSub?.cancel();
    super.dispose();
  }

  /// Reserved for nested UI (filters, sheets); shell handles most back cases.
  bool tryHandleAndroidBack() => false;

  Future<void> _loadDashboardData() async {
    await NativePendingSync.syncQuickAddQueue();
    if (await FirebaseService().isConnected) {
      await StorageService.syncAllLocalData();
    }
    await _loadAccountsWithOfflineSupport();
    _loadMonthlyAndRecentMerged();
    _loadStatsForWidgets();
  }

  /// Re-subscribe merged month stream (e.g. after Quick Add → SQLite + cloud sync).
  void refreshMergedTransactions() {
    if (!mounted) return;
    _loadMonthlyAndRecentMerged();
  }

  Future<void> _loadAccountsWithOfflineSupport() async {
    try {
      FirebaseService().getAccounts().listen((accounts) {
        if (mounted) {
          setState(() { 
            _accounts = accounts; 
            _totalBalance = accounts.fold(0.0, (s, a) => s + a.balance); 
          });
          _updateHomeWidget();
        }
      });
    } catch (e) {
      final bal = await StorageService.getLocalBalance();
      if (mounted) setState(() => _totalBalance = bal);
    }
  }

  void _updateHomeWidget() {
    WidgetService.updateSummaryWidget(
      totalBalance: _totalBalance,
      incomeTotal: _monthlyIncome,
      expenseTotal: _monthlyExpenses,
      accounts: _accounts,
    );
    WidgetService.updateRecentWidget(_recentTransactions);
    WidgetService.updateDebtsAlertsWidget(
      totalIOwe: _totalIOwe,
      totalOwedMe: _totalOwedMe,
      alertsCount: _alertsCount,
      recentAlerts: _recentAlerts,
    );
  }

  void _loadStatsForWidgets() {
    FirebaseService().getUserStats().listen((stats) {
      if (mounted) {
        setState(() {
          _totalIOwe = stats['totalIOwe'] ?? 0.0;
          _totalOwedMe = stats['totalOwedMe'] ?? 0.0;
        });
        _updateHomeWidget();
      }
    });
    FirebaseService().getReminders().listen((reminders) {
      if (mounted) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final upcoming = reminders.where((r) {
          final d = DateTime.parse(r['date']);
          final rd = DateTime(d.year, d.month, d.day);
          return rd.isAfter(today) || rd == today;
        }).toList()..sort((a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));

        setState(() {
          _alertsCount = reminders.length;
          _recentAlerts = upcoming.take(1).toList();
        });
        _updateHomeWidget();
      }
    });
  }

  void _loadMonthlyAndRecentMerged() {
    _mergedTxSub?.cancel();
    _mergedTxSub =
        FirebaseService().getMonthlyTransactions(_currentMonth).listen((txns) async {
      final merged =
          await mergeFirebaseMonthWithPendingLocal(txns, _currentMonth);
      double inc = 0, exp = 0;
      for (var t in merged) {
        final a = double.tryParse(t['amount']?.toString() ?? '0') ?? 0;
        if (t['type'] == 'income') {
          inc += a;
        } else {
          exp += a;
        }
      }
      if (mounted) {
        setState(() {
          _monthlyIncome = inc;
          _monthlyExpenses = exp;
          _recentTransactions = merged.take(5).toList();
        });
        _updateHomeWidget();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    S.init(context);
    final monthLabel = DateFormat('MMMM yyyy').format(_currentMonth);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: AppTheme.primary,
        backgroundColor: AppTheme.surface,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            // ── Premium Hero Card (Balance & Monthly Summary) ───────────
            SliverToBoxAdapter(
              child: GestureDetector(
                onTap: () => widget.onNavigateTab?.call(4), // Tap hero to go to Reports
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primary,
                          AppTheme.primary.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Balance',
                              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                monthLabel,
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '\$${_totalBalance.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
                                        child: const Icon(Icons.arrow_downward_rounded, size: 12, color: Colors.greenAccent),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text('Income', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text('\$${_monthlyIncome.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 35, color: Colors.white.withValues(alpha: 0.2)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
                                        child: const Icon(Icons.arrow_upward_rounded, size: 12, color: Colors.redAccent),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text('Expenses', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text('\$${_monthlyExpenses.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Upcoming Alert ──────────────────────────────────────────
            if (_recentAlerts.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: _buildUpcomingAlertCard(_recentAlerts.first),
                ),
              ),

            // ── My Accounts ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: _sectionHeader('My Accounts', onTap: () => widget.onNavigateTab?.call(2)),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 120,
                child: _accounts.isEmpty
                    ? _buildAccountsEmpty()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _accounts.length,
                        itemBuilder: (context, index) => _buildAccountCard(_accounts[index]),
                      ),
              ),
            ),

            // ── Debts Overview ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: _sectionHeader('Debts Overview', onTap: () => widget.onNavigateTab?.call(3)),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(child: _buildSummaryCard('I Owe', _totalIOwe, Icons.upload_rounded, AppTheme.expense, onTap: () => widget.onNavigateTab?.call(3))),
                    const SizedBox(width: 12),
                    Expanded(child: _buildSummaryCard('Owed to Me', _totalOwedMe, Icons.download_rounded, AppTheme.income, onTap: () => widget.onNavigateTab?.call(3))),
                  ],
                ),
              ),
            ),

            // ── Recent Activity ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: _sectionHeader('Recent Activity', onTap: () => widget.onNavigateTab?.call(1)),
              ),
            ),
            _recentTransactions.isEmpty
                ? SliverToBoxAdapter(child: _buildTransactionsEmpty())
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildTransactionItem(_recentTransactions[index]),
                        childCount: _recentTransactions.length,
                      ),
                    ),
                  ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _buildUpcomingAlertCard(Map<String, dynamic> r) {
    final date = DateTime.parse(r['date']);
    final isToday = DateTime(date.year, date.month, date.day) == DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    
    return GestureDetector(
      onTap: () => widget.onNavigateTab?.call(5),
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: const Icon(Icons.notifications_active_rounded, color: AppTheme.accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isToday ? 'Today' : 'Upcoming Alert',
                  style: const TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  r['title'] ?? 'Alert',
                  style: const TextStyle(color: AppTheme.textMain, fontSize: 15, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('EEE, MMM dd • hh:mm a').format(date),
                  style: const TextStyle(color: AppTheme.textDim, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _sectionHeader(String title, {VoidCallback? onTap}) {
    final header = Text(
      title,
      style: const TextStyle(
        color: AppTheme.textMain,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
    );

    if (onTap == null) return header;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        header,
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('See All', style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppTheme.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }



  Widget _buildAccountCard(AccountModel account) {
    final isVisa = account.type.toLowerCase().contains('visa');
    return GestureDetector(
      onTap: () => widget.onNavigateTab?.call(2),
      child: Container(
      width: 130,
      height: double.infinity,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isVisa ? Icons.credit_card_rounded : Icons.account_balance_wallet_rounded,
              color: AppTheme.primary,
              size: 16,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                account.name,
                style: const TextStyle(color: AppTheme.textDim, fontSize: 11, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '\$${account.balance.toStringAsFixed(0)}',
                style: const TextStyle(color: AppTheme.textMain, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildSummaryCard(String title, double amount, IconData icon, Color color, {bool isCurrency = true, VoidCallback? onTap}) {
    final isNegative = amount < 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(color: AppTheme.textDim, fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 3),
          Text(
            isCurrency ? '\$${amount.abs().toStringAsFixed(0)}' : amount.toStringAsFixed(0),
            style: TextStyle(
              color: isNegative ? AppTheme.expense : color,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> t) {
    final isIncome = t['type'] == 'income';
    final amount = double.tryParse(t['amount']?.toString() ?? '0') ?? 0.0;
    final color = isIncome ? AppTheme.income : AppTheme.expense;
    return GestureDetector(
      onTap: () => widget.onNavigateTab?.call(1),
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: AppTheme.cardDecoration(radius: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isIncome ? Icons.keyboard_double_arrow_up_rounded : Icons.keyboard_double_arrow_down_rounded,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t['category'] ?? 'General',
                  style: const TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  t['date'] != null
                      ? DateFormat('MMM dd, yyyy').format(DateTime.parse(t['date']))
                      : '',
                  style: const TextStyle(color: AppTheme.textDim, fontSize: 11),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (t['pendingSync'] == true) ...[
                Tooltip(
                  message: 'Pending upload',
                  child: Icon(Icons.cloud_queue_rounded, size: 15, color: AppTheme.textDim.withValues(alpha: 0.85)),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                '${isIncome ? '+' : '-'}\$${amount.toStringAsFixed(0)}',
                style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildAccountsEmpty() {
    return Center(
      child: Text(
        'No accounts added yet',
        style: TextStyle(color: AppTheme.textDim, fontSize: 13),
      ),
    );
  }

  Widget _buildTransactionsEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          'No recent transactions',
          style: TextStyle(color: AppTheme.textDim, fontSize: 13),
        ),
      ),
    );
  }
}
