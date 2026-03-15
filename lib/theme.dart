// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ──────────────────────────────────────────────
  //   Core Color Palette – soft, warm, low-stimulation
  // ──────────────────────────────────────────────

  // Backgrounds – very gentle warm neutrals
  static const Color background = Color(0xFFFDF8F2);       // pale warm sand
  static const Color surface = Color(0xFFFEF9F4);          // soft ivory/cream
  static const Color surfaceVariant = Color(0xFFF5F0EA);   // slightly deeper warm neutral

  // Primary family – muted peach/terracotta
  static const Color primary = Color(0xFFE0A78A);
  static const Color primaryContainer = Color(0xFFF8E4D9);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Secondary family – gentle sage
  static const Color secondary = Color(0xFFB8CBB8);
  static const Color secondaryContainer = Color(0xFFE8F0E8);
  static const Color onSecondary = Color(0xFF2F3F2F);

  // Text & icons
  static const Color textPrimary = Color(0xFF5C4A38);
  static const Color textSecondary = Color(0xFF8A7665);
  static const Color textDisabled = Color(0xFFB0A08A);

  // Feedback colors
  static const Color success = Color(0xFFA8BFA8);
  static const Color error = Color(0xFFE89A9A);
  static const Color warning = Color(0xFFE8C39A);

  // Activity colors (softened)
  static const Map<String, Color> activityColors = {
    'Shapes': Color(0xFFF4A3A3),        // muted coral rose
    'Counting': Color(0xFFC2D4C2),      // pale olive/sage
    'Basic Math': Color(0xFFD9A78F),    // soft dusty orange
    'Advanced Math': Color(0xFFD9C9B8), // warm taupe/beige
  };

  // ──────────────────────────────────────────────
  //   Typography – clear and readable
  // ──────────────────────────────────────────────

  static const TextTheme textTheme = TextTheme(
    displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -0.5),
    displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
    headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
    headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
    titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, height: 1.5),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, height: 1.5),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
  );

  // ──────────────────────────────────────────────
  //   Light Theme (main one you'll use)
  // ──────────────────────────────────────────────

  static ThemeData lightTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    colorScheme: ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: textPrimary,
      secondary: secondary,
      onSecondary: onSecondary,
      secondaryContainer: secondaryContainer,
      onSecondaryContainer: textPrimary,
      surface: surface,
      onSurface: textPrimary,
      surfaceVariant: surfaceVariant,
      onSurfaceVariant: textSecondary,
      error: error,
      onError: Colors.white,
      outline: Color(0xFFB0A08A),
      shadow: Colors.black.withOpacity(0.08),
      inverseSurface: textPrimary,
      onInverseSurface: surface,
    ),

    scaffoldBackgroundColor: background,
    cardColor: surface,
    dialogBackgroundColor: surface,

    // ──── This is the fixed part ────
    textTheme: GoogleFonts.fredokaTextTheme(
      ThemeData.light().textTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
    ),

    // ... rest of your theme (appBarTheme, elevatedButtonTheme, cardTheme, etc.) ...
  );
}

  // Optional dark theme stub (you can expand later)
  static ThemeData darkTheme() {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF1A1612),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.dark,
      ),
    );
  }

  // Helper to get activity-specific color
  static Color getActivityColor(String activityName) {
    return activityColors[activityName] ?? primary;
  }

  static IconData getActivityIcon(String name) {
  switch (name) {
    case 'Shapes': return Icons.category;
    case 'Counting': return Icons.calculate;
    case 'Basic Math': return Icons.add_circle;
    case 'Advanced Math': return Icons.grid_view;
    default: return Icons.star;
  }
}
}