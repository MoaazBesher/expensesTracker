// screens/home_screen.dart
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/storage_service.dart';
import '../models/account_model.dart';
import '../utils/app_theme.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // Current month
  final DateTime _currentMonth = DateTime.now();
  
  // Data
  double _totalBalance = 0.0;
  List<AccountModel> _accounts = [];
  double _monthlyIncome = 0.0;
  double _monthlyExpenses = 0.0;
  double _monthlySavings = 0.0;
  List<Map<String, dynamic>> _recentTransactions = [];
  Map<String, dynamic> _consolidatedDebts = {};
  List<Map<String, dynamic>> _upcomingReminders = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    await _loadAccountsWithOfflineSupport();
    await _loadMonthlySummaryWithOfflineSupport();
    await _loadRecentTransactionsWithOfflineSupport();
    await _loadDebtsSummary();
    await _loadUpcomingReminders();
  }

  Future<void> _loadAccountsWithOfflineSupport() async {
    try {
      FirebaseService().getAccounts().listen((accounts) {
        if (mounted) {
          setState(() {
            _accounts = accounts;
            _totalBalance = accounts.fold(0.0, (sum, acc) => sum + acc.balance);
          });
        }
      });
    } catch (e) {
      final localBalance = await StorageService.getLocalBalance();
      if (mounted) setState(() => _totalBalance = localBalance);
    }
  }

  Future<void> _loadMonthlySummaryWithOfflineSupport() async {
    try {
      FirebaseService().getMonthlyTransactions(_currentMonth).listen((transactions) {
        double income = 0.0;
        double expenses = 0.0;
        for (var t in transactions) {
          final amt = double.tryParse(t['amount']?.toString() ?? '0') ?? 0.0;
          if (t['type'] == 'income') {
            income += amt;
          } else {
            expenses += amt;
          }
        }
        if (mounted) {
          setState(() {
            _monthlyIncome = income;
            _monthlyExpenses = expenses;
            _monthlySavings = income - expenses;
          });
        }
      });
    } catch (e) {
      final localTransactions = await StorageService.getLocalTransactions(_currentMonth);
      double income = 0.0, expenses = 0.0;
      for (var t in localTransactions) {
        final amt = double.tryParse(t['amount']?.toString() ?? '0') ?? 0.0;
        if (t['type'] == 'income') {
          income += amt;
        } else {
          expenses += amt;
        }
      }
      if (mounted) {
        setState(() {
          _monthlyIncome = income;
          _monthlyExpenses = expenses;
          _monthlySavings = income - expenses;
        });
      }
    }
  }

  Future<void> _loadRecentTransactionsWithOfflineSupport() async {
    try {
      FirebaseService().getMonthlyTransactions(_currentMonth).listen((transactions) {
        if (mounted) setState(() => _recentTransactions = transactions.take(5).toList());
      });
    } catch (e) {
      final localTransactions = await StorageService.getLocalTransactions(_currentMonth);
      if (mounted) setState(() => _recentTransactions = localTransactions.take(5).toList());
    }
  }

  Future<void> _loadDebtsSummary() async {
    try {
      final debts = await FirebaseService().getDebts().first;
      if (mounted) {
        double totalIOwe = 0.0, totalOwedToMe = 0.0;
        if (debts['iOwe'] is List) {
          for (var d in debts['iOwe']) {
            totalIOwe += _safeConvertAmount(d['amount']);
          }
        }
        if (debts['owedToMe'] is List) {
          for (var d in debts['owedToMe']) {
            totalOwedToMe += _safeConvertAmount(d['amount']);
          }
        }
        setState(() {
          _consolidatedDebts = {
            'totalIOwe': totalIOwe,
            'totalOwedToMe': totalOwedToMe,
            'netDebt': totalOwedToMe - totalIOwe,
          };
        });
      }
    } catch (e) {
      // Offline or error loading debts
    }
  }

  Future<void> _loadUpcomingReminders() async {
    try {
      final remindersValue = await FirebaseService().getReminders().first;
      final now = DateTime.now();
      final upcoming = remindersValue.where((r) {
        final date = DateTime.parse(r['date']);
        return date.isAfter(now);
      }).toList()..sort((a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));
      
      if (mounted) setState(() => _upcomingReminders = upcoming.take(3).toList());
    } catch (e) {
      // Offline or error loading reminders
    }
  }

  double _safeConvertAmount(dynamic amount) {
    if (amount == null) return 0.0;
    if (amount is int) return amount.toDouble();
    if (amount is double) return amount;
    if (amount is String) return double.tryParse(amount) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.background, Color(0xFF1E1B4B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _loadDashboardData,
          color: AppTheme.primary,
          strokeWidth: 3,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Welcome back,', style: TextStyle(color: AppTheme.textDim, fontSize: 16)),
                          const Text('Premium User', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: AppTheme.glassDecoration(opacity: 0.1),
                        child: const Icon(Icons.notifications_outlined, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),

              // Main Balance Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.3),
                          blurRadius: 32,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -20,
                          top: -20,
                          child: Icon(Icons.account_balance_wallet, size: 200, color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(28.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Total Balance', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 16)),
                              const SizedBox(height: 8),
                              Text('\$${_totalBalance.toStringAsFixed(2)}', 
                                style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _buildMiniTag(Icons.trending_up, '+\$${_monthlyIncome.toStringAsFixed(0)}', AppTheme.income),
                                  const SizedBox(width: 12),
                                  _buildMiniTag(Icons.trending_down, '-\$${_monthlyExpenses.toStringAsFixed(0)}', AppTheme.expense),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Accounts Slider
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Money Sources', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            TextButton(onPressed: () {}, child: const Text('See All', style: TextStyle(color: AppTheme.primary))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _accounts.length,
                          itemBuilder: (context, index) => _buildAccountCard(_accounts[index]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Quick Actions / Stats
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(child: _buildActionCard('Income', _monthlyIncome, Icons.add_circle, AppTheme.income)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildActionCard('Expenses', _monthlyExpenses, Icons.remove_circle, AppTheme.expense)),
                    ],
                  ),
                ),
              ),

              // Recent Transactions Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Recent Activity', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      GestureDetector(
                        onTap: () {},
                        child: Text('View History', style: TextStyle(color: AppTheme.textDim, fontSize: 14)),
                      ),
                    ],
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

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniTag(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildAccountCard(AccountModel account) {
    return Container(
      width: 160,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassDecoration(opacity: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(account.type.toLowerCase().contains('visa') ? Icons.credit_card : Icons.wallet, color: AppTheme.primary, size: 24),
          const SizedBox(height: 12),
          Text(account.name, style: TextStyle(color: AppTheme.textDim, fontSize: 14)),
          Text('\$${account.balance.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildActionCard(String title, double amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassDecoration(opacity: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(color: AppTheme.textDim, fontSize: 14)),
          Text('\$${amount.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> t) {
    final isIncome = t['type'] == 'income';
    final amount = double.tryParse(t['amount']?.toString() ?? '0') ?? 0.0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.glassDecoration(opacity: 0.03, radius: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isIncome ? AppTheme.income : AppTheme.expense).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(isIncome ? Icons.keyboard_double_arrow_up : Icons.keyboard_double_arrow_down, 
                      color: isIncome ? AppTheme.income : AppTheme.expense, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t['category'] ?? 'General', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text(DateFormat('MMM dd, yyyy').format(DateTime.parse(t['date'])), style: TextStyle(color: AppTheme.textDim, fontSize: 12)),
              ],
            ),
          ),
          Text('${isIncome ? '+' : '-'}\$${amount.toStringAsFixed(0)}', 
               style: TextStyle(color: isIncome ? AppTheme.income : AppTheme.expense, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}