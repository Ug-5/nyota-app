import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  // Default to system settings for better accessibility
  ThemeMode _themeMode = ThemeMode.light; 
  static const String _themeKey = 'theme_mode';

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
      return brightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_themeKey);

      if (saved != null) {
        _themeMode = ThemeMode.values.firstWhere(
          (e) => e.toString() == saved,
          orElse: () => ThemeMode.system,
        );
      }
    } catch (e) {
      _themeMode = ThemeMode.system;
    } finally {
      notifyListeners();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, mode.toString());
    } catch (e) {
      debugPrint('Error saving theme: $e');
    }
  }

  void toggleDarkMode(bool value) {
    setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
  }
}