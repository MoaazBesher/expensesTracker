import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_navigator.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import '../utils/screen_utils.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  DateTime? _lastExitPromptAt;

  void _handleAndroidBack() {
    if (!mounted) return;
    final root = appRootNavigatorKey.currentState;
    if (root != null && root.canPop()) {
      root.pop();
      _lastExitPromptAt = null;
      return;
    }
    if (FocusManager.instance.primaryFocus?.hasFocus == true) {
      FocusManager.instance.primaryFocus?.unfocus();
      _lastExitPromptAt = null;
      return;
    }
    final now = DateTime.now();
    if (_lastExitPromptAt != null &&
        now.difference(_lastExitPromptAt!) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastExitPromptAt = now;
    ScaffoldMessenger.maybeOf(context)
      ?..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: const Icon(Icons.exit_to_app_rounded, color: AppTheme.accent, size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'Press back again to exit',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textMain),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(40, 0, 40, 24),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
            side: BorderSide(color: AppTheme.accent.withValues(alpha: 0.3), width: 1),
          ),
          backgroundColor: AppTheme.surface.withValues(alpha: 0.95),
          elevation: 8,
        ),
      );
  }

  void _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final userCredential = await _authService.signInWithGoogle();
      if (userCredential == null) setState(() => _isLoading = false);
    } catch (e) {
      String errorMessage = e.toString();
      if (e is PlatformException) errorMessage = 'Error [${e.code}]: ${e.message}';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign in failed: $errorMessage', style: const TextStyle(fontSize: 13)),
            backgroundColor: AppTheme.accent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    S.init(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _handleAndroidBack();
      },
      child: Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_balance_wallet, size: 36, color: AppTheme.primary),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Welcome',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppTheme.textMain),
                ),
                const SizedBox(height: 8),
                Text(
                  'Track your finances.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppTheme.textDim),
                ),
                const SizedBox(height: 48),
                _isLoading
                    ? const CircularProgressIndicator(color: AppTheme.primary)
                    : SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _signInWithGoogle,
                          icon: Image.network(
                            'https://cdn-icons-png.flaticon.com/512/2991/2991148.png',
                            height: 20,
                          ),
                          label: const Text('Continue with Google'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textMain,
                            side: const BorderSide(color: AppTheme.border),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}
