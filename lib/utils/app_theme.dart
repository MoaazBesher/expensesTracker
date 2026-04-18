import 'package:flutter/material.dart';

class AppTheme {
  // Colors - Premium Neural Palette
  static const Color background = Color(0xFF020617); // Deepest slate
  static const Color surface = Color(0xFF0F172A);    // Card base
  static const Color surfaceLight = Color(0xFF1E293B);
  
  static const Color primary = Color(0xFF6366F1);    // Indigo
  static const Color secondary = Color(0xFF06B6D4);  // Cyan
  static const Color accent = Color(0xFFF43F5E);     // Rose
  
  static const Color income = Color(0xFF10B981);    // Emerald
  static const Color expense = Color(0xFFEF4444);   // Red
  
  static const Color textMain = Colors.white;
  static const Color textDim = Color(0xFF94A3B8);
  static const Color textDark = Color(0xFF64748B);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Decorations
  static BoxDecoration glassDecoration({Color? color, double opacity = 0.7, double radius = 24}) {
    return BoxDecoration(
      color: (color ?? surface).withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
    );
  }

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    primaryColor: primary,
    colorScheme: ColorScheme.dark(
      primary: primary,
      secondary: secondary,
      surface: surface,
      onSurface: textMain,
      error: accent,
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: textMain,
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textMain),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textMain),
      bodyLarge: TextStyle(fontSize: 16, color: textMain),
      bodyMedium: TextStyle(fontSize: 14, color: textDim),
    ),
  );
}
