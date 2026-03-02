import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color primary = Color(0xFFFF7043);
  static const Color primaryLight = Color(0xFFFF8A65);
  static const Color primaryDark = Color(0xFFE64A19);
  static const Color secondary = Color(0xFF26C6DA);
  static const Color secondaryLight = Color(0xFF80DEEA);
  static const Color accent = Color(0xFFFFCA28);
  static const Color background = Color(0xFFFFF8F0);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBg = Color(0xFFFFF3E0);
  static const Color textDark = Color(0xFF2D2D2D);
  static const Color textMedium = Color(0xFF6D6D6D);
  static const Color textLight = Color(0xFF9E9E9E);
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
  static const Color border = Color(0xFFE0E0E0);
  static const Color inputBg = Color(0xFFFAFAFA);

  static const LinearGradient landingGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFF8A65),
      Color(0xFFFF7043),
      Color(0xFFFF5722),
    ],
  );

  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFF7043),
      Color(0xFFFF5722),
    ],
  );

  static const LinearGradient tealGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF26C6DA),
      Color(0xFF0097A7),
    ],
  );
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: GoogleFonts.nunitoTextTheme(
        const TextTheme(
          displayLarge: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w900,
            color: AppColors.textDark,
            letterSpacing: -1.5,
          ),
          displayMedium: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
            letterSpacing: -1.0,
          ),
          displaySmall: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
          headlineLarge: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
          headlineMedium: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
          titleLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: AppColors.textMedium,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.textMedium,
          ),
          labelLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        hintStyle: const TextStyle(
          color: AppColors.textLight,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: const TextStyle(
          color: AppColors.textMedium,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
