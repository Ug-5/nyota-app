// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ──────────────────────────────────────────────
  //   Core Seed Color – A soft, buttery, non-triggering yellow
  // ──────────────────────────────────────────────
  static const Color seedColor = Color(0xFFEBC351); // Muted gold/star yellow

  // ──────────────────────────────────────────────
  //   Custom fixed colors (Softened for sensory safety)
  // ──────────────────────────────────────────────
  static const Color success = Color(0xFF98AF98); // Muted sage green
  static const Color error = Color(0xFFD68A8A);   // Dusty rose red
  static const Color warning = Color(0xFFD9B382); // Soft sand orange

  // Activity-specific accent colors (Calm, predictable, earthy tones)
  static const Map<String, Color> activityColors = {
    'Shapes': Color(0xFFB5C9D5),        // Pale sky blue
    'Counting': Color(0xFFC9D6B8),      // Soft meadow green
    'Basic Math': Color(0xFFE8D4A2),    // Warm pale yellow
    'Advanced Math': Color(0xFFD2B4DE), // Muted lavender
  };

  // ──────────────────────────────────────────────
  //   Light Theme – Warm and "Paper-like"
  // ──────────────────────────────────────────────
  static ThemeData lightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
      // Overriding primary to ensure it's not too bright
      primary: const Color(0xFFD4A72C), 
      surface: const Color(0xFFFFFDF5), // Off-white cream
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      // Very pale cream/yellow background to reduce glare
      scaffoldBackgroundColor: const Color(0xFFFDF9E7), 
      cardColor: colorScheme.surface,

      textTheme: GoogleFonts.fredokaTextTheme(
        ThemeData.light().textTheme.apply(
          bodyColor: const Color(0xFF43413B), // Soft charcoal-brown (better than pure black)
          displayColor: const Color(0xFF33312C),
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFFFDF9E7),
        foregroundColor: const Color(0xFF43413B),
        elevation: 0,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF2D382), // Soft, clickable yellow
          foregroundColor: const Color(0xFF5C4B20), // High contrast but soft text
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      dialogTheme: const DialogThemeData(backgroundColor: Color(0xFFFFFDF5)),
    );
  }

  // ──────────────────────────────────────────────
  //   Dark Theme – Midnight Blue & Soft Gold
  // ──────────────────────────────────────────────
  static ThemeData darkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
      surface: const Color(0xFF1E1C16),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      // Deep navy-brown background (less harsh than pure black)
      scaffoldBackgroundColor: const Color(0xFF14130F), 
      cardColor: colorScheme.surfaceContainerLowest,

      textTheme: GoogleFonts.fredokaTextTheme(
        ThemeData.dark().textTheme.apply(
          bodyColor: const Color(0xFFEBE6D8), // Warm off-white
          displayColor: const Color(0xFFF7F3E9),
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF1E1C16),
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD4A72C),
          foregroundColor: Colors.black87,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ), 
      dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF1E1C16)),
    );
  }

  // ──────────────────────────────────────────────
  //   Helpers
  // ──────────────────────────────────────────────
  static Color getActivityColor(String activityName) {
    return activityColors[activityName] ?? seedColor;
  }

  static IconData getActivityIcon(String name) {
    switch (name) {
      case 'Shapes':
        return Icons.category_rounded;
      case 'Counting':
        return Icons.pin_outlined;
      case 'Basic Math':
        return Icons.add_circle_outline_rounded;
      case 'Advanced Math':
        return Icons.grid_view_rounded;
      default:
        return Icons.star_rounded;
    }
  }
}