import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:home_widget/home_widget.dart';
import 'dart:async';
import 'screens/home_screen.dart';
import 'screens/transactions_screen.dart';
import 'screens/reminders_screen.dart';
import 'screens/debts_screen.dart';
import 'screens/login_screen.dart';
import 'screens/accounts_screen.dart';
import 'screens/monthly_bills_screen.dart';
import 'services/auth_service.dart';
import 'services/firebase_service.dart';
import 'services/widget_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'utils/app_theme.dart';
import 'utils/screen_utils.dart';
import 'utils/firebase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: FirebaseConfig.options);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    S.init(context);
    return MaterialApp(
      title: 'Expenses Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const AuthWrapper(),
          transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.primary.withValues(alpha: 0.2), AppTheme.primary.withValues(alpha: 0.05)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3), width: 1),
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded, size: 44, color: AppTheme.primary),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Expenses Tracker',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppTheme.textMain, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Track yourself',
                      style: TextStyle(fontSize: 14, color: AppTheme.textDim),
                    ),
                    const SizedBox(height: 56),
                    SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary.withValues(alpha: 0.5)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().user,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final User? user = snapshot.data;
          if (user == null) {
            return const LoginScreen();
          } else {
            return const MainNavigation();
          }
        }
        return const Scaffold(
          backgroundColor: AppTheme.background,
          body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        );
      },
    );
  }
}

// ─── Tab descriptor ─────────────────────────────────────────────────────────
class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _NavItem({required this.label, required this.icon, required this.activeIcon});
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _isOnline = true;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  // GlobalKeys to control child screens
  final GlobalKey<TransactionsScreenState> _transactionsKey = GlobalKey<TransactionsScreenState>();
  final GlobalKey<RemindersScreenState> _remindersKey = GlobalKey<RemindersScreenState>();
  final GlobalKey<DebtsScreenState> _debtsKey = GlobalKey<DebtsScreenState>();

  // ── Screens list (order matches _navItems) ──────────────────────────────
  late final List<Widget> _screens = [
    const HomeScreen(),
    const AccountsScreen(),
    TransactionsScreen(key: _transactionsKey),
    const MonthlyBillsScreen(),
    RemindersScreen(key: _remindersKey),
    DebtsScreen(key: _debtsKey),
  ];

  static const List<_NavItem> _navItems = [
    _NavItem(label: 'Home',     icon: Icons.dashboard_outlined,              activeIcon: Icons.dashboard_rounded),
    _NavItem(label: 'Sources',  icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet_rounded),
    _NavItem(label: 'Activity', icon: Icons.swap_vert_circle_outlined,       activeIcon: Icons.swap_vert_circle_rounded),
    _NavItem(label: 'Reports',  icon: Icons.bar_chart_outlined,              activeIcon: Icons.bar_chart_rounded),
    _NavItem(label: 'Alerts',   icon: Icons.notifications_outlined,          activeIcon: Icons.notifications_active_rounded),
    _NavItem(label: 'Debts',    icon: Icons.savings_outlined,                activeIcon: Icons.savings_rounded),
  ];

  // page titles matching _navItems order
  static const List<String> _pageTitles = [
    'Dashboard',
    'Money Sources',
    'Transactions',
    'Monthly Report',
    'Reminders',
    'Debts',
  ];

  static const _deepLinkChannel = MethodChannel('expenses.tracker/deeplink');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initConnectivity();
    FirebaseService().ensureDefaultAccountExists();
    WidgetService.registerInteractivity();
    _handleInitialDeepLink();
    HomeWidget.widgetClicked.listen(_handleWidgetUri);

    // Listen for deep links from native side (Quick Settings Tile, etc.)
    _deepLinkChannel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink') {
        final uriString = call.arguments as String?;
        if (uriString != null) {
          _handleWidgetUri(Uri.parse(uriString));
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handleInitialDeepLink(); // Re-check on resume
    }
  }

  Future<void> _handleInitialDeepLink() async {
    final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    if (uri != null) _handleWidgetUri(uri);
  }

  void _handleWidgetUri(Uri? uri) {
    if (uri == null) return;
    final uriString = uri.toString();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (uriString.contains('add_income')) {
        setState(() => _currentIndex = 2);
        _triggerAction(() => _transactionsKey.currentState?.showAddSheet(true));
      } else if (uriString.contains('add_expense')) {
        setState(() => _currentIndex = 2);
        _triggerAction(() => _transactionsKey.currentState?.showAddSheet(false));
      } else if (uriString.contains('add_alert')) {
        setState(() => _currentIndex = 4);
        _triggerAction(() => _remindersKey.currentState?.showAddSheet());
      } else if (uriString.contains('add_debt')) {
        setState(() => _currentIndex = 5);
        _triggerAction(() => _debtsKey.currentState?.showAddSheet());
      } else if (uriString.contains('quick_add')) {
        _triggerAction(() => _showQuickAddOverlay());
      }
    });
  }

  void _showQuickAddOverlay() {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    bool isIncome = false;
    String selectedCategory = 'Food';

    final incomeCategories = ['Salary', 'Freelance', 'Gift', 'Investment', 'Other'];
    final expenseCategories = ['Food', 'Transport', 'Shopping', 'Bills', 'Entertainment', 'Health', 'Education', 'Other'];

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final categories = isIncome ? incomeCategories : expenseCategories;
          if (!categories.contains(selectedCategory)) {
            selectedCategory = categories.first;
          }

          return AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bolt_rounded, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 10),
                const Text('Quick Add', style: TextStyle(color: AppTheme.textMain, fontSize: 17, fontWeight: FontWeight.w700)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Type Toggle
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setDialogState(() => isIncome = false),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !isIncome ? AppTheme.expense.withValues(alpha: 0.15) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: !isIncome ? Border.all(color: AppTheme.expense.withValues(alpha: 0.3)) : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.arrow_downward_rounded, size: 16, color: !isIncome ? AppTheme.expense : AppTheme.textDim),
                                  const SizedBox(width: 4),
                                  Text('Expense', style: TextStyle(color: !isIncome ? AppTheme.expense : AppTheme.textDim, fontWeight: FontWeight.w600, fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setDialogState(() => isIncome = true),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isIncome ? AppTheme.income.withValues(alpha: 0.15) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: isIncome ? Border.all(color: AppTheme.income.withValues(alpha: 0.3)) : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.arrow_upward_rounded, size: 16, color: isIncome ? AppTheme.income : AppTheme.textDim),
                                  const SizedBox(width: 4),
                                  Text('Income', style: TextStyle(color: isIncome ? AppTheme.income : AppTheme.textDim, fontWeight: FontWeight.w600, fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Amount
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    style: const TextStyle(color: AppTheme.textMain, fontSize: 22, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      prefixText: '\$ ',
                      prefixStyle: TextStyle(color: AppTheme.textDim, fontSize: 22, fontWeight: FontWeight.w700),
                      hintText: '0.00',
                      hintStyle: TextStyle(color: AppTheme.textDim.withValues(alpha: 0.3)),
                      filled: true,
                      fillColor: AppTheme.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Category
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    dropdownColor: AppTheme.surfaceLight,
                    style: const TextStyle(color: AppTheme.textMain, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Category',
                      labelStyle: const TextStyle(color: AppTheme.textDim, fontSize: 12),
                      filled: true,
                      fillColor: AppTheme.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setDialogState(() => selectedCategory = v!),
                  ),
                  const SizedBox(height: 10),

                  // Note
                  TextField(
                    controller: noteController,
                    style: const TextStyle(color: AppTheme.textMain, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Note (optional)',
                      labelStyle: const TextStyle(color: AppTheme.textDim, fontSize: 12),
                      filled: true,
                      fillColor: AppTheme.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textDim,
                        side: const BorderSide(color: AppTheme.border),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        final amount = double.tryParse(amountController.text) ?? 0;
                        if (amount <= 0) return;
                        Navigator.pop(ctx);
                        try {
                          await FirebaseService().addTransaction(
                            type: isIncome ? 'income' : 'expense',
                            amount: amount,
                            category: selectedCategory,
                            date: DateTime.now(),
                            accountId: '',
                            note: noteController.text,
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${isIncome ? 'Income' : 'Expense'} added!', style: const TextStyle(fontSize: 12)),
                                backgroundColor: isIncome ? AppTheme.income : AppTheme.expense,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.accent),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isIncome ? AppTheme.income : AppTheme.expense,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(isIncome ? 'Add Income' : 'Add Expense', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _triggerAction(VoidCallback action) {
    // Wait a bit for the tab to switch and the state to be ready
    Future.delayed(const Duration(milliseconds: 500), action);
  }

  void _initConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        setState(() {
          _isOnline = results.isNotEmpty && results.any((r) => r != ConnectivityResult.none);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    S.init(context);
    return Scaffold(
      backgroundColor: AppTheme.background,
      // ── App Bar ────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        toolbarHeight: 56,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primary.withValues(alpha: 0.25), AppTheme.primary.withValues(alpha: 0.08)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3), width: 0.8),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _pageTitles[_currentIndex],
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textMain, height: 1.1),
                ),
                Text(
                  'Expenses Tracker',
                  style: TextStyle(fontSize: 11, color: AppTheme.textDim, fontWeight: FontWeight.w400, height: 1.1),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (!_isOnline)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.accent.withValues(alpha: 0.35)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off_rounded, size: 13, color: AppTheme.accent),
                  SizedBox(width: 4),
                  Text('Offline', style: TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 0.5, color: AppTheme.border),
        ),
      ),
      // ── Body: IndexedStack keeps each tab alive without swipe ──────────
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      // ── Bottom Navigation Bar ──────────────────────────────────────────
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(_navItems.length, (index) {
              return Expanded(child: _buildNavItem(index));
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final isSelected = _currentIndex == index;
    final item = _navItems[index];
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary.withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isSelected ? item.activeIcon : item.icon,
                size: 22,
                color: isSelected ? AppTheme.primary : AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppTheme.primary : AppTheme.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
