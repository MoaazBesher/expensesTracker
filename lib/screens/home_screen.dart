import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/storage_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    await _loadAccountsWithOfflineSupport();
    await _loadMonthlySummaryWithOfflineSupport();
    await _loadRecentTransactionsWithOfflineSupport();
  }

  Future<void> _loadAccountsWithOfflineSupport() async {
    try {
      FirebaseService().getAccounts().listen((accounts) {
        if (mounted) setState(() { _accounts = accounts; _totalBalance = accounts.fold(0.0, (s, a) => s + a.balance); });
      });
    } catch (e) {
      final bal = await StorageService.getLocalBalance();
      if (mounted) setState(() => _totalBalance = bal);
    }
  }

  Future<void> _loadMonthlySummaryWithOfflineSupport() async {
    try {
      FirebaseService().getMonthlyTransactions(_currentMonth).listen((txns) {
        double inc = 0, exp = 0;
        for (var t in txns) {
          final a = double.tryParse(t['amount']?.toString() ?? '0') ?? 0;
          if (t['type'] == 'income') { inc += a; } else { exp += a; }
        }
        if (mounted) { setState(() { _monthlyIncome = inc; _monthlyExpenses = exp; }); }
      });
    } catch (e) {
      final txns = await StorageService.getLocalTransactions(_currentMonth);
      double inc = 0, exp = 0;
      for (var t in txns) {
        final a = double.tryParse(t['amount']?.toString() ?? '0') ?? 0;
        if (t['type'] == 'income') { inc += a; } else { exp += a; }
      }
      if (mounted) { setState(() { _monthlyIncome = inc; _monthlyExpenses = exp; }); }
    }
  }

  Future<void> _loadRecentTransactionsWithOfflineSupport() async {
    try {
      FirebaseService().getMonthlyTransactions(_currentMonth).listen((txns) {
        if (mounted) setState(() => _recentTransactions = txns.take(5).toList());
      });
    } catch (e) {
      final txns = await StorageService.getLocalTransactions(_currentMonth);
      if (mounted) setState(() => _recentTransactions = txns.take(5).toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    S.init(context);
    return Scaffold(
      body: Container(
        color: AppTheme.background,
        child: RefreshIndicator(
          onRefresh: _loadDashboardData,
          color: AppTheme.primary,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    constraints: BoxConstraints(minHeight: 140, maxHeight: S.hp(20).clamp(155, 180)),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Balance', style: TextStyle(color: AppTheme.textDim, fontSize: S.fontSmall)),
                          const SizedBox(height: 4),
                          Text('\$${_totalBalance.toStringAsFixed(2)}',
                            style: TextStyle(color: AppTheme.textMain, fontSize: S.sp(28), fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildMiniTag(Icons.trending_up, '+\$${_monthlyIncome.toStringAsFixed(0)}', AppTheme.income),
                              const SizedBox(width: 10),
                              _buildMiniTag(Icons.trending_down, '-\$${_monthlyExpenses.toStringAsFixed(0)}', AppTheme.expense),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(S.sectionPadding, 0, S.sectionPadding, 8),
                  child: SizedBox(
                        height: S.hp(14).clamp(105, 125),
                        child: ListView.builder(
                          padding: const EdgeInsets.only(left: 0),
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _accounts.length,
                          itemBuilder: (context, index) => _buildAccountCard(_accounts[index]),
                        ),
                      ),
                  ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: IntrinsicHeight(
                    child: Row(
                    children: [
                      Expanded(child: _buildActionCard('Income', _monthlyIncome, Icons.add_circle, AppTheme.income)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildActionCard('Expenses', _monthlyExpenses, Icons.remove_circle, AppTheme.expense)),
                    ],
                  ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildTransactionItem(_recentTransactions[index]),
                    childCount: _recentTransactions.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniTag(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildAccountCard(AccountModel account) {
    return Container(
      width: S.wp(36).clamp(110, 150),
      height: double.infinity,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.cardDecoration(radius: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(account.type.toLowerCase().contains('visa') ? Icons.credit_card : Icons.wallet, color: AppTheme.primary, size: 20),
          const SizedBox(height: 8),
          Text(account.name, style: TextStyle(color: AppTheme.textDim, fontSize: S.fontSmall), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text('\$${account.balance.toStringAsFixed(0)}', style: TextStyle(color: AppTheme.textMain, fontSize: S.fontLarge, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildActionCard(String title, double amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration(radius: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(color: AppTheme.textDim, fontSize: S.fontSmall)),
          const SizedBox(height: 4),
          Text('\$${amount.toStringAsFixed(0)}', style: TextStyle(color: AppTheme.textMain, fontSize: S.fontLarge, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> t) {
    final isIncome = t['type'] == 'income';
    final amount = double.tryParse(t['amount']?.toString() ?? '0') ?? 0.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.cardDecoration(radius: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isIncome ? AppTheme.income : AppTheme.expense).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(isIncome ? Icons.keyboard_double_arrow_up : Icons.keyboard_double_arrow_down,
                      color: isIncome ? AppTheme.income : AppTheme.expense, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t['category'] ?? 'General', style: const TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.w600, fontSize: 14)),
                Text(t['date'] != null ? DateFormat('MMM dd, yyyy').format(DateTime.parse(t['date'])) : '', style: TextStyle(color: AppTheme.textDim, fontSize: 11)),
              ],
            ),
          ),
          Text('${isIncome ? '+' : '-'}\$${amount.toStringAsFixed(0)}',
               style: TextStyle(color: isIncome ? AppTheme.income : AppTheme.expense, fontWeight: FontWeight.w600, fontSize: 15)),
        ],
      ),
    );
  }
}
