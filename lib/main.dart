import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'package:flutter/animation.dart';

// Import the actual screens
import 'screens/home_screen.dart';
import 'screens/transactions_screen.dart';
import 'screens/reminders_screen.dart';
import 'screens/debts_screen.dart';
import 'screens/monthly_bills_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with elegance
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyDJg-mULJuZUbK5Si4-0GLs611b15RYKfQ",
      appId: "1:1038707025145:web:7f56741b8b7b4c57196e28", 
      messagingSenderId: "1038707025145",
      projectId: "expenses-tracker-53924",
      databaseURL: "https://expenses-tracker-53924-default-rtdb.firebaseio.com",
    ),
  );
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expenses Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF6C63FF),
        primaryColorDark: const Color(0xFF5A52D5),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardColor: const Color(0xFF1E293B),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Color(0xFFF1F5F9),
            letterSpacing: 1.2,
          ),
          bodyLarge: TextStyle(
            color: Color(0xFFF1F5F9),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          bodyMedium: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 14,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1E293B),
          selectedItemColor: Color(0xFF6C63FF),
          unselectedItemColor: Color(0xFF64748B),
          elevation: 20,
          type: BottomNavigationBarType.fixed,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFFF1F5F9),
            letterSpacing: 1.5,
          ),
        ),
      ),
      home: SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutQuart),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _controller.forward();

    // Navigate to main app after splash
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => MainNavigation(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 1000),
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
      backgroundColor: const Color(0xFF0F172A),
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
                    // Animated Logo
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFF5A52D5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6C63FF).withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 5,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 30),
                    // App Name with Gradient
                    ShaderMask(
                      shaderCallback: (bounds) {
                        return const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFF2DD4BF)],
                        ).createShader(bounds);
                      },
                      child: const Text(
                        'Expenses Tracker',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Track Yourself',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.7),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 50),
                    // Loading Indicator
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF6C63FF)),
                        backgroundColor: Colors.white.withOpacity(0.2),
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

class MainNavigation extends StatefulWidget {
  @override
  _MainNavigationState createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> with TickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isOnline = true;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  
  // Animation controllers for page transitions
  late AnimationController _pageAnimationController;
  late Animation<double> _pageFadeAnimation;

  // Use actual screens instead of placeholders
  final List<Widget> _screens = [
    HomeScreen(), // Actual HomeScreen
    TransactionsScreen(),
    RemindersScreen(),
    DebtsScreen(),
    MonthlyBillsScreen(),
  ];

  static Widget _buildPlaceholderScreen(String title, IconData icon, String subtitle) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0F172A),
            const Color(0xFF1E293B).withOpacity(0.8),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Icon Container
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF2DD4BF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C63FF).withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  size: 50,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 30),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFF1F5F9),
                  letterSpacing: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 16,
                  color: const Color(0xFF94A3B8).withOpacity(0.8),
                  letterSpacing: 1.1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              // Floating Action Elements
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildFloatingElement('AI Powered', Icons.psychology),
                  const SizedBox(width: 20),
                  _buildFloatingElement('Secure', Icons.security),
                  const SizedBox(width: 20),
                  _buildFloatingElement('Real-time', Icons.flash_on),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildFloatingElement(String text, IconData icon) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: const Color(0xFF6C63FF),
            size: 30,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          text,
          style: TextStyle(
            color: const Color(0xFF94A3B8),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    
    // Initialize page animation
    _pageAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _pageFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pageAnimationController, curve: Curves.easeInOut),
    );
    
    _pageAnimationController.forward();
    _initConnectivity();
  }

  void _initConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        setState(() {
          _isOnline = results.isNotEmpty && results.any((result) => result != ConnectivityResult.none);
        });
        
        if (_isOnline) {
          _syncLocalData();
        }
      },
    );
  }

  Future<void> _syncLocalData() async {
    if (_isOnline) {
      print('Syncing elite data to Firebase...');
      // TODO: Add premium sync logic
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
      _pageAnimationController.reset();
      _pageAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _pageAnimationController.dispose();
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Row(
          children: [
            // Animated Logo
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF5A52D5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C63FF).withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(
                Icons.account_balance_wallet,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Expenses Tracker'),
            const Spacer(),
            if (!_isOnline)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange, Colors.orange.shade700],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: const [
                    Icon(Icons.wifi_off, size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Offline Mode',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: AnimatedBuilder(
        animation: _pageAnimationController,
        builder: (context, child) {
          return FadeTransition(
            opacity: _pageFadeAnimation,
            child: _screens[_currentIndex],
          );
        },
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 5,
              offset: const Offset(0, 5),
            ),
          ],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _onTabTapped,
            type: BottomNavigationBarType.fixed,
            backgroundColor: const Color(0xFF1E293B),
            selectedItemColor: const Color(0xFF6C63FF),
            unselectedItemColor: const Color(0xFF64748B),
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.analytics, size: 26),
                label: 'Dashboard',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.auto_graph, size: 26),
                label: 'Transactions',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.notifications_active, size: 26),
                label: 'Reminders',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.credit_card, size: 26),  // أو Icons.money_off
                label: 'Debts',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long, size: 26),  // أو Icons.description
                label: 'Bills',
              ),
            ],
          ),
        ),
      ),
    );
  }
}