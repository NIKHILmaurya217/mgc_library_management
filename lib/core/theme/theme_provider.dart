import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'is_dark_mode';
  bool _isDarkMode = true; // Default to dark mode

  ThemeProvider() {
    _loadTheme();
  }

  bool get isDarkMode => _isDarkMode;

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  void toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _isDarkMode);
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    // Use true as default if key doesn't exist
    _isDarkMode = prefs.getBool(_themeKey) ?? true;
    notifyListeners();
  }
}
