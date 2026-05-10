import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/firebase_service.dart';
import '../services/storage_service.dart';
import '../services/widget_service.dart';
import '../models/account_model.dart';
import '../utils/app_theme.dart';
import '../utils/screen_utils.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DateTime _currentMonth = DateTime.now();
  double _totalBalance = 0.0;
  List<AccountModel> _accounts = [];
  double _monthlyIncome = 0.0;
  double _monthlyExpenses = 0.0;
  List<Map<String, dynamic>> _recentTransactions = [];
  double _totalIOwe = 0.0;
  double _totalOwedMe = 0.0;
  int _alertsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    await _syncPendingTransactions();
    await _loadAccountsWithOfflineSupport();
    await _loadMonthlySummaryWithOfflineSupport();
    await _loadRecentTransactionsWithOfflineSupport();
    _loadStatsForWidgets();
  }

  static bool _isSyncing = false;

  /// Sync any pending transactions saved from the native Quick Add dialog
  Future<void> _syncPendingTransactions() async {
    if (_isSyncing) return; // Prevent duplicate runs
    _isSyncing = true;

    try {
      const channel = MethodChannel('expenses.tracker/pending');
      final result = await channel.invokeMethod<Map>('getPending');
      if (result == null) { _isSyncing = false; return; }

      final prefs = Map<String, dynamic>.from(result);
      final count = prefs['count'] as int? ?? 0;
      if (count == 0) { _isSyncing = false; return; }

      // Clear FIRST to prevent duplicates on re-entry
      await channel.invokeMethod('clearPending');

      // Now sync to Firebase
      final firebaseService = FirebaseService();
      for (int i = 1; i <= count; i++) {
        final type = prefs['txn_${i}_type'] as String? ?? 'expense';
        final amount = double.tryParse(prefs['txn_${i}_amount']?.toString() ?? '0') ?? 0;
        final category = prefs['txn_${i}_category'] as String? ?? 'Other';
        final note = prefs['txn_${i}_note'] as String? ?? '';

        if (amount > 0) {
          await firebaseService.addTransaction(
            type: type,
            amount: amount,
            category: category,
            date: DateTime.now(),
            accountId: '',
            note: note,
          );
        }
      }
    } catch (_) {}

    _isSyncing = false;
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
        setState(() => _alertsCount = reminders.length);
        _updateHomeWidget();
      }
    });
  }

  Future<void> _loadMonthlySummaryWithOfflineSupport() async {
    try {
      FirebaseService().getMonthlyTransactions(_currentMonth).listen((txns) {
        double inc = 0, exp = 0;
        for (var t in txns) {
          final a = double.tryParse(t['amount']?.toString() ?? '0') ?? 0;
          if (t['type'] == 'income') { inc += a; } else { exp += a; }
        }
        if (mounted) {
          setState(() { _monthlyIncome = inc; _monthlyExpenses = exp; });
          _updateHomeWidget();
        }
      });
    } catch (e) {
      final txns = await StorageService.getLocalTransactions(_currentMonth);
      double inc = 0, exp = 0;
      for (var t in txns) {
        final a = double.tryParse(t['amount']?.toString() ?? '0') ?? 0;
        if (t['type'] == 'income') { inc += a; } else { exp += a; }
      }
      if (mounted) setState(() { _monthlyIncome = inc; _monthlyExpenses = exp; });
    }
  }

  Future<void> _loadRecentTransactionsWithOfflineSupport() async {
    try {
      FirebaseService().getMonthlyTransactions(_currentMonth).listen((txns) {
        if (mounted) {
          setState(() => _recentTransactions = txns.take(5).toList());
          _updateHomeWidget();
        }
      });
    } catch (e) {
      final txns = await StorageService.getLocalTransactions(_currentMonth);
      if (mounted) {
        setState(() => _recentTransactions = txns.take(5).toList());
        _updateHomeWidget();
      }
    }
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
            // ── Total Balance Card ──────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primary.withValues(alpha: 0.15),
                        AppTheme.primary.withValues(alpha: 0.04),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Total Balance',
                            style: TextStyle(color: AppTheme.textDim, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              monthLabel,
                              style: const TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '\$${_totalBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppTheme.textMain,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _buildMiniTag(Icons.trending_up_rounded, '+\$${_monthlyIncome.toStringAsFixed(0)}', AppTheme.income),
                          const SizedBox(width: 10),
                          _buildMiniTag(Icons.trending_down_rounded, '-\$${_monthlyExpenses.toStringAsFixed(0)}', AppTheme.expense),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Accounts section label ──────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: _sectionHeader('Accounts'),
              ),
            ),

            // ── Accounts horizontal list ────────────────────────────────
            SliverToBoxAdapter(
              child: SizedBox(
                height: 110,
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

            // ── Monthly Summary ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: _sectionHeader('Finance Summary'),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(child: _buildSummaryCard('Income', _monthlyIncome, Icons.add_circle_rounded, AppTheme.income)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildSummaryCard('Expenses', _monthlyExpenses, Icons.remove_circle_rounded, AppTheme.expense)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildSummaryCard(
                      'Saved',
                      _monthlyIncome - _monthlyExpenses,
                      Icons.savings_rounded,
                      AppTheme.primary,
                    )),
                  ],
                ),
              ),
            ),

            // ── Recent Transactions header ──────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: _sectionHeader('Recent Activity'),
              ),
            ),

            // ── Recent Transactions list ────────────────────────────────
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

            // ── Debts & Alerts ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: _sectionHeader('Debts & Alerts'),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(child: _buildSummaryCard('I Owe', _totalIOwe, Icons.arrow_upward_rounded, AppTheme.expense)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildSummaryCard('Owed to Me', _totalOwedMe, Icons.arrow_downward_rounded, AppTheme.income)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildSummaryCard('Alerts', _alertsCount.toDouble(), Icons.notifications_rounded, AppTheme.accent, isCurrency: false)),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.textMain,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
    );
  }

  Widget _buildMiniTag(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildAccountCard(AccountModel account) {
    final isVisa = account.type.toLowerCase().contains('visa');
    return Container(
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
    );
  }

  Widget _buildSummaryCard(String title, double amount, IconData icon, Color color, {bool isCurrency = true}) {
    final isNegative = amount < 0;
    return Container(
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
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> t) {
    final isIncome = t['type'] == 'income';
    final amount = double.tryParse(t['amount']?.toString() ?? '0') ?? 0.0;
    final color = isIncome ? AppTheme.income : AppTheme.expense;
    return Container(
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
          Text(
            '${isIncome ? '+' : '-'}\$${amount.toStringAsFixed(0)}',
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ],
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
