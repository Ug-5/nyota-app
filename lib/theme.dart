import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // 🌿 Primary Seed: Muted Slate Blue (Calming and professional)
  static const Color seedColor = Color(0xFF6C8EAD); 

  // ✅ Functional Colors (Muted to prevent sensory overload)
  static const Color success = Color(0xFF8DAA91); // Sage Green
  static const Color error = Color(0xFFC78383);   // Muted Terracotta
  static const Color warning = Color(0xFFD4B483); // Soft Sand

  // 🎨 Activity colors (Differentiated by hue, but unified by softness)
  static const Map<String, Color> activityColors = {
    'Shapes': Color(0xFF9FB1BC),        // Cool Grey-Blue
    'Counting': Color(0xFFA5B99F),      // Pale Leaf Green
    'Basic Math': Color(0xFFD1B29E),    // Warm Dusty Rose
    'Advanced Math': Color(0xFFB3A5BE), // Soft Lavender
  };

  // 🌞 LIGHT THEME (Low Contrast / Anti-Glare)
  static ThemeData lightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
      surface: const Color(0xFFF7F9FB), 
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF7F9FB),
      cardColor: Colors.white,

      // Rounded fonts like Fredoka are easier to read and less "sharp"
      textTheme: GoogleFonts.fredokaTextTheme(
        ThemeData.light().textTheme.apply(
          bodyColor: const Color(0xFF2D3436), // Soft grey instead of pure black
          displayColor: const Color(0xFF2D3436),
        ),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF7F9FB),
        foregroundColor: Color(0xFF2D3436),
        elevation: 0,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
          elevation: 0, // Flat design reduces visual complexity
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), 
          ),
        ),
      ),
      
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  // 🌙 DARK THEME (Low Blue Light)
  static ThemeData darkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
      surface: const Color(0xFF242B2E),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF1B2022),
      cardColor: const Color(0xFF242B2E),

      textTheme: GoogleFonts.fredokaTextTheme(
        ThemeData.dark().textTheme.apply(
          bodyColor: const Color(0xFFE0E0E0),
          displayColor: const Color(0xFFE0E0E0),
        ),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1B2022),
        elevation: 0,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  static Color getActivityColor(String activityName) {
    return activityColors[activityName] ?? seedColor;
  }

  static IconData getActivityIcon(String name) {
    switch (name) {
      case 'Shapes': return Icons.interests_rounded; 
      case 'Counting': return Icons.exposure_plus_1_rounded;
      case 'Basic Math': return Icons.add_rounded;
      case 'Advanced Math': return Icons.functions_rounded;
      default: return Icons.auto_awesome_rounded;
    }
  }
}