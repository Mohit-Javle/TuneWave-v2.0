import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  String? _currentUserEmail;

  ThemeMode get getThemeMode => _themeMode;

  Future<void> loadTheme(String userEmail) async {
    _currentUserEmail = userEmail;
    final prefs = await SharedPreferences.getInstance();
    final key = 'theme_$userEmail';
    final themeIndex = prefs.getInt(key);
    
    if (themeIndex != null) {
      _themeMode = ThemeMode.values[themeIndex];
    } else {
      _themeMode = ThemeMode.light; // Default
    }
    notifyListeners();
  }

  void setTheme(ThemeMode themeMode) {
    _themeMode = themeMode;
    notifyListeners();
    _saveTheme();
  }

  Future<void> _saveTheme() async {
    if (_currentUserEmail == null) return;
    final prefs = await SharedPreferences.getInstance();
    final key = 'theme_$_currentUserEmail';
    await prefs.setInt(key, _themeMode.index);
  }
}
