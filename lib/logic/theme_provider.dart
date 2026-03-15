import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/theme_settings.dart';

class ThemeProvider with ChangeNotifier {
  AppTheme _currentTheme = AppTheme.midnight;
  bool _initialized = false;

  AppTheme get currentTheme => _currentTheme;
  ThemeData get themeData => ThemeSettings.getTheme(_currentTheme);

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('app_theme') ?? 0;
    _currentTheme = AppTheme.values[themeIndex];
    _initialized = true;
    notifyListeners();
  }

  Future<void> setTheme(AppTheme theme) async {
    _currentTheme = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_theme', theme.index);
    notifyListeners();
  }
}
