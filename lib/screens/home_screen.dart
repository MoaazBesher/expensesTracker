// screens/home_screen.dart
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/storage_service.dart';
import 'package:flutter/animation.dart';
import 'dart:math' as math;
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // Animation Controllers
  late AnimationController _statsAnimationController;
  late AnimationController _chartAnimationController;
  late AnimationController _balancePulseController;
  
  // Current month
  DateTime _currentMonth = DateTime.now();
  
  // Data
  double _totalBalance = 0.0;
  double _monthlyIncome = 0.0;
  double _monthlyExpenses = 0.0;
  double _monthlySavings = 0.0;
  List<Map<String, dynamic>> _recentTransactions = [];
  Map<String, dynamic> _userStats = {};
  Map<String, dynamic> _consolidatedDebts = {};
  List<Map<String, dynamic>> _upcomingReminders = [];

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _statsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _chartAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _balancePulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    // Start animations
    _statsAnimationController.forward();
    _chartAnimationController.forward();
    
    // Load data with offline support
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    // Load all data with offline support
    await _loadBalanceWithOfflineSupport();
    await _loadMonthlySummaryWithOfflineSupport();
    await _loadRecentTransactionsWithOfflineSupport();
    await _loadUserStats();
    await _loadDebtsSummary();
    await _loadUpcomingReminders();
  }

  Future<void> _loadBalanceWithOfflineSupport() async {
    // Try online first
    try {
      FirebaseService().getBalance().listen((balance) {
        if (mounted) {
          setState(() {
            _totalBalance = balance;
          });
          // Update local balance cache
          StorageService.saveLocalBalance(balance);
        }
      });
    } catch (e) {
      print('Online balance load failed: $e');
      // Fallback to local balance
      final localBalance = await StorageService.getLocalBalance();
      if (mounted) {
        setState(() {
          _totalBalance = localBalance;
        });
      }
    }
  }

  Future<void> _loadMonthlySummaryWithOfflineSupport() async {
    // Try online first
    try {
      final summary = await FirebaseService().getMonthlySummary(_currentMonth);
      if (mounted) {
        setState(() {
          _monthlyIncome = summary['income'] ?? 0.0;
          _monthlyExpenses = summary['expenses'] ?? 0.0;
          _monthlySavings = summary['savings'] ?? 0.0;
        });
      }
    } catch (e) {
      print('Online summary load failed: $e');
      // Fallback to local calculation
      await _calculateLocalSummary();
    }
  }

  Future<void> _calculateLocalSummary() async {
    final localTransactions = await StorageService.getLocalTransactions(_currentMonth);
    double income = 0.0;
    double expenses = 0.0;
    
    for (final transaction in localTransactions) {
      final amount = double.tryParse(transaction['amount']?.toString() ?? '0') ?? 0.0;
      if (transaction['type'] == 'income') {
        income += amount;
      } else {
        expenses += amount;
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

  Future<void> _loadRecentTransactionsWithOfflineSupport() async {
    // Try online first
    try {
      FirebaseService().getMonthlyTransactions(_currentMonth).listen((transactions) {
        if (mounted) {
          setState(() {
            _recentTransactions = transactions.take(5).toList();
          });
        }
      });
    } catch (e) {
      print('Online transactions load failed: $e');
      // Fallback to local transactions
      final localTransactions = await StorageService.getLocalTransactions(_currentMonth);
      if (mounted) {
        setState(() {
          _recentTransactions = localTransactions.take(5).toList();
        });
      }
    }
  }

  Future<void> _loadUserStats() async {
    try {
      final stats = await FirebaseService().getUserStats();
      if (mounted) {
        setState(() {
          _userStats = stats;
        });
      }
    } catch (e) {
      print('Error loading user stats: $e');
    }
  }

  Future<void> _loadDebtsSummary() async {
    try {
      final debts = await FirebaseService().getDebts().first;
      if (mounted) {
        _processDebtsForDashboard(debts);
      }
    } catch (e) {
      print('Error loading debts summary: $e');
    }
  }

  void _processDebtsForDashboard(Map<String, dynamic> debts) {
    try {
      double totalIOwe = 0.0;
      double totalOwedToMe = 0.0;

      // Handle iOwe data
      final iOweData = debts['iOwe'];
      if (iOweData is List) {
        for (final debt in iOweData) {
          final amount = _safeConvertAmount(debt['amount']);
          totalIOwe += amount;
        }
      }

      // Handle owedToMe data
      final owedToMeData = debts['owedToMe'];
      if (owedToMeData is List) {
        for (final debt in owedToMeData) {
          final amount = _safeConvertAmount(debt['amount']);
          totalOwedToMe += amount;
        }
      }

      setState(() {
        _consolidatedDebts = {
          'totalIOwe': totalIOwe,
          'totalOwedToMe': totalOwedToMe,
          'netDebt': totalOwedToMe - totalIOwe,
        };
      });
    } catch (e) {
      print('Error processing debts for dashboard: $e');
    }
  }

  Future<void> _loadUpcomingReminders() async {
    try {
      final reminders = await FirebaseService().getReminders().first;
      final now = DateTime.now();
      final upcoming = reminders.where((reminder) {
        final date = DateTime.parse(reminder['date']);
        return date.isAfter(now);
      }).toList()
        ..sort((a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));
      
      if (mounted) {
        setState(() {
          _upcomingReminders = upcoming.take(3).toList();
        });
      }
    } catch (e) {
      print('Error loading upcoming reminders: $e');
    }
  }

  double _safeConvertAmount(dynamic amount) {
    try {
      if (amount == null) return 0.0;
      if (amount is int) return amount.toDouble();
      if (amount is double) return amount;
      if (amount is String) return double.tryParse(amount) ?? 0.0;
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  Future<void> _refreshData() async {
    await _loadDashboardData();
    
    // Show refresh indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.autorenew, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Data Updated Successfully'),
          ],
        ),
        backgroundColor: Color(0xFF6C63FF),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _statsAnimationController.dispose();
    _chartAnimationController.dispose();
    _balancePulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F172A),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        backgroundColor: Color(0xFF1E293B),
        color: Color(0xFF6C63FF),
        child: CustomScrollView(
          slivers: [
            // Stats Grid
            SliverToBoxAdapter(
              child: AnimatedBuilder(
                animation: _statsAnimationController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, 50 * (1 - _statsAnimationController.value)),
                    child: Opacity(
                      opacity: _statsAnimationController.value,
                      child: child,
                    ),
                  );
                },
                child: _buildStatsGrid(),
              ),
            ),

            // Quick Overview Section
            SliverToBoxAdapter(
              child: _buildQuickOverview(),
            ),

            // Chart Section
            SliverToBoxAdapter(
              child: AnimatedBuilder(
                animation: _chartAnimationController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, 30 * (1 - _chartAnimationController.value)),
                    child: Opacity(
                      opacity: _chartAnimationController.value,
                      child: child,
                    ),
                  );
                },
                child: _buildChartSection(),
              ),
            ),

            // Recent Transactions Header
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 30, 20, 10),
                child: Row(
                  children: [
                    Icon(Icons.history, color: Color(0xFF6C63FF), size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Recent Transactions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Spacer(),
                    Text(
                      '${_recentTransactions.length} items',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Recent Transactions List
            _recentTransactions.isEmpty
                ? SliverToBoxAdapter(child: _buildEmptyTransactionsState())
                : _buildTransactionsList(),

            // Upcoming Reminders Header
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 30, 20, 10),
                child: Row(
                  children: [
                    Icon(Icons.notifications, color: Color(0xFF6C63FF), size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Upcoming Reminders',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Spacer(),
                    Text(
                      '${_upcomingReminders.length} items',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Upcoming Reminders List
            _upcomingReminders.isEmpty
                ? SliverToBoxAdapter(child: _buildEmptyRemindersState())
                : _buildRemindersList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min, // مهم علشان مايسببش overflow
        children: [
          // Total Balance Card (Special Design)
          _buildBalanceCard(),
          SizedBox(height: 20),
          
          // Other Stats Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.0, // تغيير النسبة علشان تكون مربعة
            children: [
              _buildStatCard(
                'Monthly Income',
                _monthlyIncome,
                Icons.trending_up,
                Color(0xFF2DD4BF),
                true,
              ),
              _buildStatCard(
                'Monthly Expenses',
                _monthlyExpenses,
                Icons.trending_down,
                Color(0xFFF87171),
                false,
              ),
              _buildStatCard(
                'Monthly Savings',
                _monthlySavings,
                Icons.savings,
                Color(0xFFFBBF24),
                _monthlySavings >= 0,
              ),
              _buildOverviewCard(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickOverview() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min, // مهم
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Debts Overview',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Container(
            height: 70, // تقليل الارتفاع
            child: Row(
              children: [
                Expanded(
                  child: _buildOverviewItem(
                    'Net Balance',
                    _consolidatedDebts['netDebt'] ?? 0.0,
                    _consolidatedDebts['netDebt'] != null && (_consolidatedDebts['netDebt'] as double) > 0 
                        ? Color(0xFF2DD4BF) 
                        : Color(0xFFF87171),
                    Icons.account_balance,
                  ),
                ),
                SizedBox(width: 6), // تقليل المسافة
                Expanded(
                  child: _buildOverviewItem(
                    'You Owe',
                    _consolidatedDebts['totalIOwe'] ?? 0.0,
                    Color(0xFFF87171),
                    Icons.arrow_upward,
                  ),
                ),
                SizedBox(width: 8), // تقليل المسافة
                Expanded(
                  child: _buildOverviewItem(
                    'Owed to You',
                    _consolidatedDebts['totalOwedToMe'] ?? 0.0,
                    Color(0xFF2DD4BF),
                    Icons.arrow_downward,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewItem(String title, double value, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(3), // تقليل البادنج
      decoration: BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 24, // تصغير الأيقونة
                height: 24,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 14),
              ),
              Spacer(),
            ],
          ),
          SizedBox(height: 6), // تقليل المسافة
          Text(
            title,
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 10, // تصغير الخط
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 2), // تقليل المسافة
          Text(
            '\$${value.toStringAsFixed(2)}',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12, // تصغير الخط
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return AnimatedBuilder(
      animation: _balancePulseController,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + 0.02 * _balancePulseController.value,
          child: child,
        );
      },
      child: Container(
        height: 120, // إرجاع الارتفاع الطبيعي
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF6C63FF),
              Color(0xFF5A52D5),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF6C63FF).withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: 5,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            _buildBackgroundPattern(),
            
            Padding(
              padding: EdgeInsets.all(16), // تقليل البادنج
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 50, // تصغير الحاوية
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.account_balance_wallet,
                      color: Colors.white,
                      size: 24, // تصغير الأيقونة
                    ),
                  ),
                  SizedBox(width: 12), // تقليل المسافة
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Total Balance',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12, // تصغير الخط
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2), // تقليل المسافة
                        Text(
                          '\$${_totalBalance.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22, // تصغير الخط
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0, // تقليل التباعد
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildBalanceTrendIndicator(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundPattern() {
    return Positioned(
      right: -40, // تقليل الحجم
      top: -40,
      child: Transform.rotate(
        angle: math.pi / 4,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(25),
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceTrendIndicator() {
    final isPositive = _monthlySavings >= 0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4), // تقليل البادنج
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.arrow_upward : Icons.arrow_downward,
            color: Colors.white,
            size: 14, // تصغير الأيقونة
          ),
          SizedBox(width: 2), // تقليل المسافة
          Text(
            '${isPositive ? '+' : ''}\$${_monthlySavings.abs().toStringAsFixed(2)}',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10, // تصغير الخط
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, double value, IconData icon, Color color, bool isPositive) {
    return Container(
      height: 110, // تقليل الارتفاع
      decoration: BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16), // تقليل الزوايا
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(12), // تقليل البادنج
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 36, // تصغير الحاوية
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18), // تصغير الأيقونة
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2), // تقليل البادنج
                  decoration: BoxDecoration(
                    color: isPositive ? Color(0xFF2DD4BF).withOpacity(0.2) : Color(0xFFF87171).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isPositive ? 'Good' : 'Alert',
                    style: TextStyle(
                      color: isPositive ? Color(0xFF2DD4BF) : Color(0xFFF87171),
                      fontSize: 8, // تصغير الخط
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8), // تقليل المسافة
            Text(
              title,
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11, // تصغير الخط
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 2), // تقليل المسافة
            Text(
              '\$${value.toStringAsFixed(2)}',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16, // تصغير الخط
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard() {
    return Container(
      height: 110, // نفس ارتفاع البطاقات الأخرى
      decoration: BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Color(0xFF6C63FF).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.analytics, color: Color(0xFF6C63FF), size: 18),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Financial Health',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 2),
            Text(
              _getFinancialStatus(),
              style: TextStyle(
                color: _getFinancialStatusColor(),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Savings: \$${_monthlySavings.toStringAsFixed(2)}',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFinancialStatus() {
    if (_monthlySavings > 0) return 'Healthy';
    if (_monthlySavings == 0) return 'Stable';
    return 'Needs Attention';
  }

  Color _getFinancialStatusColor() {
    if (_monthlySavings > 0) return Color(0xFF2DD4BF);
    if (_monthlySavings == 0) return Color(0xFFFBBF24);
    return Color(0xFFF87171);
  }

  Widget _buildChartSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        height: 200, // تقليل الارتفاع
        decoration: BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20), // تقليل الزوايا
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(16), // تقليل البادنج
          child: Column(
            mainAxisSize: MainAxisSize.min, // مهم
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.analytics, color: Color(0xFF6C63FF), size: 18), // تصغير الأيقونة
                  SizedBox(width: 6), // تقليل المسافة
                  Text(
                    'Cash Flow Analysis',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16, // تصغير الخط
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Spacer(),
                  Text(
                    'This Month',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11, // تصغير الخط
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16), // تقليل المسافة
              Expanded(
                child: _buildSimpleChart(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleChart() {
    final maxValue = math.max(_monthlyIncome, math.max(_monthlyExpenses, _monthlySavings.abs()));
    final double scale = maxValue > 0 ? 80.0 / maxValue : 1.0; // تقليل السكيل علشان الارتفاع الجديد

    return Column(
      mainAxisSize: MainAxisSize.min, // مهم
      children: [
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildChartBar('Income', _monthlyIncome, Color(0xFF2DD4BF), scale),
              _buildChartBar('Expenses', _monthlyExpenses, Color(0xFFF87171), scale),
              _buildChartBar('Savings', _monthlySavings.abs(), 
                  _monthlySavings >= 0 ? Color(0xFFFBBF24) : Color(0xFFF87171), scale),
            ],
          ),
        ),
        SizedBox(height: 8), // تقليل المسافة
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['Income', 'Expenses', 'Savings'].map((label) {
            return Text(
              label,
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11, // تصغير الخط
                fontWeight: FontWeight.w600,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildChartBar(String label, double value, Color color, double scale) {
    final double barHeight = value * scale;
    
    return Column(
      mainAxisSize: MainAxisSize.min, // مهم
      children: [
        Container(
          width: 25, // تصغير العرض
          height: barHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.7)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(6), // تقليل الزوايا
          ),
        ),
        SizedBox(height: 6), // تقليل المسافة
        Text(
          '\$${value.toStringAsFixed(0)}',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10, // تصغير الخط
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final transaction = _recentTransactions[index];
          return _buildTransactionItem(transaction, index);
        },
        childCount: _recentTransactions.length,
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction, int index) {
    final isIncome = transaction['type'] == 'income';
    final amount = double.tryParse(transaction['amount']?.toString() ?? '0') ?? 0.0;
    final date = DateTime.parse(transaction['date']);
    
    return AnimatedBuilder(
      animation: _statsAnimationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(20 * (1 - _statsAnimationController.value), 0),
          child: Opacity(
            opacity: _statsAnimationController.value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 20, vertical: 4), // تقليل المسافة
        decoration: BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12), // تقليل الزوايا
        ),
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4), // تقليل البادنج
          leading: Container(
            width: 40, // تصغير الحاوية
            height: 40,
            decoration: BoxDecoration(
              color: isIncome 
                  ? Color(0xFF2DD4BF).withOpacity(0.2)
                  : Color(0xFFF87171).withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isIncome ? Icons.arrow_upward : Icons.arrow_downward,
              color: isIncome ? Color(0xFF2DD4BF) : Color(0xFFF87171),
              size: 18, // تصغير الأيقونة
            ),
          ),
          title: Text(
            transaction['category'] ?? 'Unknown',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14, // تصغير الخط
            ),
          ),
          subtitle: Text(
            '${_formatDate(date)} • ${transaction['note'] ?? 'No description'}',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11, // تصغير الخط
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isIncome ? '+' : '-'}\$${amount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: isIncome ? Color(0xFF2DD4BF) : Color(0xFFF87171),
                  fontWeight: FontWeight.w700,
                  fontSize: 14, // تصغير الخط
                ),
              ),
              SizedBox(height: 1), // تقليل المسافة
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1), // تقليل البادنج
                decoration: BoxDecoration(
                  color: isIncome 
                      ? Color(0xFF2DD4BF).withOpacity(0.2)
                      : Color(0xFFF87171).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isIncome ? 'INCOME' : 'EXPENSE',
                  style: TextStyle(
                    color: isIncome ? Color(0xFF2DD4BF) : Color(0xFFF87171),
                    fontSize: 7, // تصغير الخط
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5, // تقليل التباعد
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRemindersList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final reminder = _upcomingReminders[index];
          return _buildReminderItem(reminder);
        },
        childCount: _upcomingReminders.length,
      ),
    );
  }

  Widget _buildReminderItem(Map<String, dynamic> reminder) {
    final date = DateTime.parse(reminder['date']);
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Color(0xFF6C63FF).withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.notifications,
            color: Color(0xFF6C63FF),
            size: 18,
          ),
        ),
        title: Text(
          reminder['title'],
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          '${_formatDate(date)} • ${_formatTime(date)}',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 11,
          ),
        ),
        trailing: Text(
          _getDaysUntilReminder(date),
          style: TextStyle(
            color: Color(0xFF6C63FF),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  String _getDaysUntilReminder(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);
    
    if (difference.inDays > 0) {
      return 'in ${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return 'in ${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return 'in ${difference.inMinutes}m';
    } else {
      return 'Now';
    }
  }

  Widget _buildEmptyTransactionsState() {
    return Container(
      height: 100, // تقليل الارتفاع
      margin: EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 40, // تصغير الأيقونة
            color: Color(0xFF6C63FF).withOpacity(0.5),
          ),
          SizedBox(height: 12), // تقليل المسافة
          Text(
            'No Transactions Yet',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 14, // تصغير الخط
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRemindersState() {
    return Container(
      height: 100,
      margin: EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 40,
            color: Color(0xFF6C63FF).withOpacity(0.5),
          ),
          SizedBox(height: 12),
          Text(
            'No Upcoming Reminders',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd').format(date);
  }

  String _formatTime(DateTime date) {
    return DateFormat('hh:mm a').format(date);
  }
}